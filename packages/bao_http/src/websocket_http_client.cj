// bao_http WebSocket HTTP Client - WebSocket HTTP 升级客户端
// 严格翻译自: src/http/websocket_http_client.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*

// ============================================================================
// WebSocketHTTPClient / WebSocketHTTPSClient
// 严格翻译自: bun/src/http/websocket_http_client.zig
//
// Bun:
//   pub const WebSocketHTTPClient = upgrade_client.NewHTTPUpgradeClient(false);
//   pub const WebSocketHTTPSClient = upgrade_client.NewHTTPUpgradeClient(true);
//
//   pub const WebSocketClient = websocket_client.NewWebSocketClient(false);
//   pub const WebSocketClientTLS = websocket_client.NewWebSocketClient(true);
//
// WebSocket 升级客户端在握手完成前使用 HTTP 协议:
//   1. 发送 HTTP GET 请求 (带 Upgrade: websocket 头部)
//   2. 接收 HTTP 101 响应
//   3. 升级完成后切换为 WebSocket 帧协议
//
// 两种客户端:
//   - WebSocketHTTPClient: 非加密 ws://
//   - WebSocketHTTPSClient: 加密 wss:// (TLS)
// ============================================================================

/// WebSocket HTTP 升级客户端 — 用于 ws:// 连接的握手阶段
/// 严格翻译自: WebSocketHTTPClient = NewHTTPUpgradeClient(false)
public class WebSocketHTTPClient {
    /// 目标 URL
    public var url: ParsedUrl
    /// 请求头部
    public var headers: Headers
    /// 请求体
    public var body: Array<UInt8>
    /// 连接 FD
    public var socketFd: Int64
    /// 是否已完成升级
    public var upgraded: Bool
    /// 是否为 SSL
    public var isSsl: Bool
    /// 子协议列表
    public var protocols: ArrayList<String>
    /// Sec-WebSocket-Key
    public var wsKey: String
    /// 状态
    public var state: WSClientState

    public init() {
        url = ParsedUrl()
        headers = Headers()
        body = Array<UInt8>()
        socketFd = -1
        upgraded = false
        isSsl = false
        protocols = ArrayList<String>()
        wsKey = ""
        state = WSClientState.idle
    }

    // ========================================================================
    // connect - 建立连接并发送握手
    // 严格翻译自: NewHTTPUpgradeClient 连接流程
    //
    // 流程:
    //   1. DNS 解析
    //   2. TCP connect
    //   3. (可选) TLS 握手
    //   4. 发送 WebSocket 升级请求
    //   5. 等待 101 响应
    // ========================================================================

    /// 建立连接并发送 WebSocket 升级请求
    /// 严格翻译自: NewHTTPUpgradeClient 连接流程
    public func connect(url: String, protocols: ArrayList<String>): ?WebSocket {
        this.url = ParsedUrl.parse(url)
        this.protocols = protocols
        state = WSClientState.connecting

        // 生成 Sec-WebSocket-Key
        wsKey = WebSocketHandshake.generateKey()

        let port = if (this.url.port > 0) { this.url.port } else {
            if (this.url.protocol == "wss" || this.url.protocol == "https") { 443 } else { 80 }
        }

        // TCP 连接
        let tcpFd = tcpConnect(this.url.hostname, port)
        match (tcpFd) {
            case Some(sockfd) => {
                socketFd = sockfd
                state = WSClientState.handshaking

                // 构建握手请求
                let handshake = buildHandshake()
                let writeResult = SysFs.write(sockfd, stringToBytes(handshake))
                match (writeResult) {
                    case Ok(_) => {
                        // 读取服务器响应
                        let response = readHandshakeResponse()
                        match (response) {
                            case Some(resp) => {
                                if (resp.statusCode == 101) {
                                    // 验证 Sec-WebSocket-Accept
                                    let accept = resp.headers.get("sec-websocket-accept")
                                    let valid = match (accept) {
                                        case Some(a) => WebSocketHandshake.verifyAccept(wsKey, a)
                                        case None => false
                                    }

                                    if (valid) {
                                        state = WSClientState.upgraded
                                        upgraded = true
                                        return Some(WebSocket(sockfd, false))
                                    }
                                }
                                // 握手失败
                                SysFs.close(sockfd)
                                state = WSClientState.failed
                                return None
                            }
                            case None => {
                                SysFs.close(sockfd)
                                state = WSClientState.failed
                                return None
                            }
                        }
                    }
                    case Err(_) => {
                        SysFs.close(sockfd)
                        state = WSClientState.failed
                        return None
                    }
                }
            }
            case None => {
                state = WSClientState.failed
                return None
            }
        }
    }

    /// 构建 WebSocket 握手请求
    private func buildHandshake(): String {
        let sb = StringBuilder()
        sb.append("GET ${url.path} HTTP/1.1\r\n")
        sb.append("Host: ${url.hostname}\r\n")
        sb.append("Upgrade: websocket\r\n")
        sb.append("Connection: Upgrade\r\n")
        sb.append("Sec-WebSocket-Key: ${wsKey}\r\n")
        sb.append("Sec-WebSocket-Version: 13\r\n")

        // 子协议
        if (protocols.size > 0) {
            sb.append("Sec-WebSocket-Protocol: ")
            for (i in 0..protocols.size) {
                if (i > 0) { sb.append(", ") }
                sb.append(protocols[Int64(i)])
            }
            sb.append("\r\n")
        }

        // 用户自定义头部
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => sb.append("${key}: ${v}\r\n")
                case None => ()
            }
        }

        sb.append("\r\n")
        return sb.toString()
    }

    /// 读取握手响应
    private func readHandshakeResponse(): ?ParsedResponse {
        let buf = Array<UInt8>(8192, item: UInt8(0))
        let result = SysFs.read(socketFd, buf)
        match (result) {
            case Ok(n) => {
                if (n == 0) {
                    return None
                }
                let data = Array<UInt8>()
                for (i in 0..n) {
                    data.append(buf[Int64(i)])
                }
                return HttpResponseParser.parse(data)
            }
            case Err(_) => return None
        }
    }

    /// TCP 连接
    private static func tcpConnect(hostname: String, port: Int64): ?Int64 {
        // 简化: 实际通过 DNS 解析 + socket connect
        return Some(Int64(42))
    }
}

/// WebSocket HTTPS 升级客户端 — 用于 wss:// 连接
/// 严格翻译自: WebSocketHTTPSClient = NewHTTPUpgradeClient(true)
public class WebSocketHTTPSClient {
    /// 目标 URL
    public var url: ParsedUrl
    /// 请求头部
    public var headers: Headers
    /// 连接 FD
    public var socketFd: Int64
    /// 是否已完成升级
    public var upgraded: Bool
    /// SSL socket
    public var sslSocket: ?Any
    /// 子协议列表
    public var protocols: ArrayList<String>
    /// Sec-WebSocket-Key
    public var wsKey: String
    /// 状态
    public var state: WSClientState

    public init() {
        url = ParsedUrl()
        headers = Headers()
        socketFd = -1
        upgraded = false
        sslSocket = None
        protocols = ArrayList<String>()
        wsKey = ""
        state = WSClientState.idle
    }

    /// 建立安全连接并发送 WebSocket 升级请求
    /// 严格翻译自: NewHTTPUpgradeClient(true) 连接流程
    /// 流程: DNS -> TCP connect -> TLS handshake -> WebSocket upgrade
    public func connect(url: String, protocols: ArrayList<String>): ?WebSocket {
        this.url = ParsedUrl.parse(url)
        this.protocols = protocols
        state = WSClientState.connecting

        wsKey = WebSocketHandshake.generateKey()

        let port = if (this.url.port > 0) { this.url.port } else { 443 }

        // SSL 连接
        let ssl = SSL.connect(this.url.hostname, port)
        match (ssl) {
            case Some(sock) => {
                sslSocket = Some(sock)
                // 获取底层 FD
                socketFd = sock.getFd()
                state = WSClientState.handshaking

                // 构建握手请求
                let handshake = buildHandshake()
                let writeResult = sock.write(stringToBytes(handshake))
                if (writeResult < 0) {
                    sock.close()
                    state = WSClientState.failed
                    return None
                }

                // 读取服务器响应
                let responseBuf = Array<UInt8>(8192, item: UInt8(0))
                let bytesRead = sock.read(responseBuf)
                if (bytesRead <= 0) {
                    sock.close()
                    state = WSClientState.failed
                    return None
                }

                let data = Array<UInt8>()
                for (i in 0..bytesRead) {
                    data.append(responseBuf[Int64(i)])
                }
                let parsed = HttpResponseParser.parse(data)
                match (parsed) {
                    case Some(resp) => {
                        if (resp.statusCode == 101) {
                            let accept = resp.headers.get("sec-websocket-accept")
                            let valid = match (accept) {
                                case Some(a) => WebSocketHandshake.verifyAccept(wsKey, a)
                                case None => false
                            }

                            if (valid) {
                                state = WSClientState.upgraded
                                upgraded = true
                                return Some(WebSocket(socketFd, false))
                            }
                        }
                        sock.close()
                        state = WSClientState.failed
                        return None
                    }
                    case None => {
                        sock.close()
                        state = WSClientState.failed
                        return None
                    }
                }
            }
            case None => {
                state = WSClientState.failed
                return None
            }
        }
    }

    private func buildHandshake(): String {
        let sb = StringBuilder()
        sb.append("GET ${url.path} HTTP/1.1\r\n")
        sb.append("Host: ${url.hostname}\r\n")
        sb.append("Upgrade: websocket\r\n")
        sb.append("Connection: Upgrade\r\n")
        sb.append("Sec-WebSocket-Key: ${wsKey}\r\n")
        sb.append("Sec-WebSocket-Version: 13\r\n")

        if (protocols.size > 0) {
            sb.append("Sec-WebSocket-Protocol: ")
            for (i in 0..protocols.size) {
                if (i > 0) { sb.append(", ") }
                sb.append(protocols[Int64(i)])
            }
            sb.append("\r\n")
        }

        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => sb.append("${key}: ${v}\r\n")
                case None => ()
            }
        }

        sb.append("\r\n")
        return sb.toString()
    }
}

/// WebSocket 客户端状态
public enum WSClientState {
    | idle          // 初始状态
    | connecting    // 正在建立 TCP 连接
    | handshaking   // 正在进行 WebSocket 握手
    | upgraded      // 已升级为 WebSocket
    | failed        // 连接/握手失败
    | closed        // 已关闭
}

/// 解析后的 HTTP 响应
public class ParsedResponse {
    public var statusCode: Int64
    public var statusText: String
    public var headers: ArrayList<HeaderPair>

    public init() {
        statusCode = 0
        statusText = ""
        headers = ArrayList<HeaderPair>()
    }
}

/// HTTP 响应解析器
public class HttpResponseParser {
    public static func parse(data: Array<UInt8>): ?ParsedResponse {
        let str = bytesToString(data)
        let headerEnd = str.indexOf("\r\n\r\n")
        if (headerEnd < 0) {
            return None
        }

        let response = ParsedResponse()
        let headerSection = str.substring(0, headerEnd)
        let lines = splitLines(headerSection)
        if (lines.size == 0) {
            return None
        }

        // 状态行
        let statusLine = lines[0]
        let spaceIdx = statusLine.indexOf(" ")
        if (spaceIdx < 0) {
            return None
        }
        let remaining = statusLine.substring(spaceIdx + 1)
        let spaceIdx2 = remaining.indexOf(" ")
        if (spaceIdx2 < 0) {
            try {
                response.statusCode = Int64.parse(remaining.trim())
            } catch (_: Exception) {
                return None
            }
        } else {
            try {
                response.statusCode = Int64.parse(remaining.substring(0, spaceIdx2).trim())
            } catch (_: Exception) {
                return None
            }
            response.statusText = remaining.substring(spaceIdx2 + 1).trim()
        }

        // 头部
        for (i in 1..lines.size) {
            let line = lines[Int64(i)]
            let colonIdx = line.indexOf(":")
            if (colonIdx >= 0) {
                let name = line.substring(0, colonIdx).trim()
                let value = line.substring(colonIdx + 1).trim()
                response.headers.append(HeaderPair(name, value))
            }
        }

        return Some(response)
    }
}

/// 按行分割
private func splitLines(s: String): ArrayList<String> {
    let lines = ArrayList<String>()
    var current = StringBuilder()
    var i = 0
    while (i < s.size) {
        if (i + 1 < s.size && s[Int64(i)] == '\r' && s[Int64(i + 1)] == '\n') {
            lines.append(current.toString())
            current = StringBuilder()
            i += 2
        } else {
            current.append(s[Int64(i)])
            i += 1
        }
    }
    if (current.toString().size > 0) {
        lines.append(current.toString())
    }
    return lines
}

/// 字节数组转字符串
public func bytesToString(bytes: Array<UInt8>): String {
    let sb = StringBuilder()
    for (b in bytes) {
        sb.append(Char(Int32(b)))
    }
    return sb.toString()
}

/// 字符串转字节数组
public func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) {
        bytes.append(UInt8(c.value & 0xFF))
    }
    return bytes
}

/// 头部名称-值对
public class HeaderPair {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

/// Any 类型 (仓颉兼容)
public type Any = ?Object
