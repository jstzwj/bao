// bao_http websocket - WebSocket 协议实现
// 严格翻译自: src/http/websocket.zig, src/http/websocket_http_client.zig
// 参考: src/http/websocket.rs, RFC 6455
package bao_http

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_event_loop.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// WebSocket OpCode - 操作码
// 严格翻译自: src/http/websocket.zig:4-25
//   pub const Opcode = enum(u4) {
//       Continue = 0x0,
//       Text = 0x1,
//       Binary = 0x2,
//       Res3 = 0x3, Res4 = 0x4, Res5 = 0x5, Res6 = 0x6, Res7 = 0x7,
//       Close = 0x8,
//       Ping = 0x9,
//       Pong = 0xA,
//       ResB = 0xB, ResC = 0xC, ResD = 0xD, ResE = 0xE, ResF = 0xF,
//       pub fn isControl(opcode: Opcode) bool { return @intFromEnum(opcode) & 0x8 != 0; }
//   };
// ============================================================================

/// WebSocket 操作码 - 对应 Bun websocket.Opcode
public enum WsOpCode {
    | Continue  // 0x0
    | Text      // 0x1
    | Binary    // 0x2
    | Res3      // 0x3
    | Res4      // 0x4
    | Res5      // 0x5
    | Res6      // 0x6
    | Res7      // 0x7
    | Close     // 0x8
    | Ping      // 0x9
    | Pong      // 0xA
    | ResB      // 0xB
    | ResC      // 0xC
    | ResD      // 0xD
    | ResE      // 0xE
    | ResF      // 0xF

    /// 是否为控制帧 - 对应 Bun Opcode.isControl
    /// 控制帧: opcode & 0x8 != 0
    public func isControl(): Bool {
        return (this.toByte() & 0x8) != 0
    }

    /// 转为字节值
    public func toByte(): Int32 {
        match (this) {
            case Continue => 0x0
            case Text => 0x1
            case Binary => 0x2
            case Res3 => 0x3
            case Res4 => 0x4
            case Res5 => 0x5
            case Res6 => 0x6
            case Res7 => 0x7
            case Close => 0x8
            case Ping => 0x9
            case Pong => 0xA
            case ResB => 0xB
            case ResC => 0xC
            case ResD => 0xD
            case ResE => 0xE
            case ResF => 0xF
        }
    }

    /// 从字节值构造
    public static func fromByte(b: Int32): WsOpCode {
        match (b & 0x0F) {
            case 0x0 => Continue
            case 0x1 => Text
            case 0x2 => Binary
            case 0x3 => Res3
            case 0x4 => Res4
            case 0x5 => Res5
            case 0x6 => Res6
            case 0x7 => Res7
            case 0x8 => Close
            case 0x9 => Ping
            case 0xA => Pong
            case 0xB => ResB
            case 0xC => ResC
            case 0xD => ResD
            case 0xE => ResE
            case _ => ResF
        }
    }
}

// ============================================================================
// WebSocketFrame - WebSocket 帧
// 严格翻译自: src/http/websocket.zig WebsocketHeader
//   pub const WebsocketHeader = packed struct(u16) {
//       len: u7,
//       mask: bool,
//       opcode: Opcode,
//       rsv: u2 = 0,
//       compressed: bool = false,
//       final: bool = true,
//   };
//
// WebSocket 帧格式 (RFC 6455):
//   0                   1                   2                   3
//   0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
//  +-+-+-+-+-------+-+-------------+-------------------------------+
//  |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
//  |I|S|S|S|  (4)  |A|     (7)     |            (16/64)            |
//  |N|V|V|V|       |S|             |   (if payload len==126/127)   |
//  | |1|2|3|       |K|             |                               |
//  +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
//  |     Extended payload length continued, if payload len == 127  |
//  + - - - - - - - - - - - - - - - +-------------------------------+
//  |                               |Masking-key, if MASK set to 1  |
//  +-------------------------------+-------------------------------+
//  | Masking-key (continued)       |          Payload Data         |
//  +-------------------------------- - - - - - - - - - - - - - - - +
// ============================================================================

/// WebSocket 帧 - 对应 Bun WebsocketHeader + 帧数据
public class WebSocketFrame {
    /// FIN 标志 - 对应 Bun header.final
    public var fin: Bool
    /// RSV1 标志 (压缩) - 对应 Bun header.compressed
    public var rsv1: Bool
    /// RSV2 标志 - 对应 Bun header.rsv
    public var rsv2: Bool
    /// RSV3 标志
    public var rsv3: Bool
    /// 操作码 - 对应 Bun header.opcode
    public var opcode: WsOpCode
    /// 是否掩码 - 对应 Bun header.mask
    public var masked: Bool
    /// 掩码键 (4 字节)
    public var maskingKey: Array<UInt8>
    /// 负载数据
    public var payload: Array<UInt8>

    public init() {
        fin = true
        rsv1 = false
        rsv2 = false
        rsv3 = false
        opcode = WsOpCode.Text
        masked = false
        maskingKey = Array<UInt8>(4, item: UInt8(0))
        payload = Array<UInt8>()
    }

    public init(opcode: WsOpCode, payload: Array<UInt8>) {
        this.fin = true
        this.rsv1 = false
        this.rsv2 = false
        this.rsv3 = false
        this.opcode = opcode
        this.masked = false
        this.maskingKey = Array<UInt8>(4, item: UInt8(0))
        this.payload = payload
    }

    /// 负载长度
    public func payloadLength(): Int64 {
        return payload.size
    }

    // ========================================================================
    // 序列化 - 将帧编码为字节
    // 严格翻译自: src/http/websocket.zig WebsocketHeader.writeHeader
    //   pub fn writeHeader(header: WebsocketHeader, writer, n) !void
    // ========================================================================

    /// 序列化帧为字节数组
    /// 对应 Bun WebsocketHeader.writeHeader + 负载写入
    public func serialize(): Array<UInt8> {
        let result = Array<UInt8>()

        // 第 1 字节: FIN + RSV + Opcode
        var byte0: UInt8 = UInt8(opcode.toByte())
        if (fin) { byte0 = byte0 | 0x80 }
        if (rsv1) { byte0 = byte0 | 0x40 }
        if (rsv2) { byte0 = byte0 | 0x20 }
        if (rsv3) { byte0 = byte0 | 0x10 }
        result.append(byte0)

        // 第 2 字节: MASK + Payload length
        // 对应 Bun header.len = packLength(n)
        let len = payload.size
        var byte1: UInt8 = UInt8(0)
        if (masked) { byte1 = byte1 | 0x80 }

        // 长度编码 - 对应 Bun WebsocketHeader.packLength
        if (len <= 125) {
            byte1 = byte1 | UInt8(len)
            result.append(byte1)
        } else if (len <= 65535) {
            byte1 = byte1 | 0x7E  // 126
            result.append(byte1)
            // 2 字节扩展长度 (big-endian)
            result.append(UInt8((len >> 8) & 0xFF))
            result.append(UInt8(len & 0xFF))
        } else {
            byte1 = byte1 | 0x7F  // 127
            result.append(byte1)
            // 8 字节扩展长度 (big-endian)
            result.append(UInt8((len >> 56) & 0xFF))
            result.append(UInt8((len >> 48) & 0xFF))
            result.append(UInt8((len >> 40) & 0xFF))
            result.append(UInt8((len >> 32) & 0xFF))
            result.append(UInt8((len >> 24) & 0xFF))
            result.append(UInt8((len >> 16) & 0xFF))
            result.append(UInt8((len >> 8) & 0xFF))
            result.append(UInt8(len & 0xFF))
        }

        // 掩码键 (如果 masked)
        if (masked) {
            for (b in maskingKey) {
                result.append(b)
            }
        }

        // 负载数据 (如果 masked 则需要异或)
        if (masked) {
            for (i in 0..payload.size) {
                result.append(payload[i] ^ maskingKey[Int64(i) % 4])
            }
        } else {
            for (b in payload) {
                result.append(b)
            }
        }

        return result
    }

    // ========================================================================
    // 反序列化 - 从字节解析帧
    // ========================================================================

    /// 从字节数组解析帧 - 返回 (帧, 已消耗字节数)
    public static func parse(data: Array<UInt8>): ?Tuple<WebSocketFrame, Int64> {
        if (data.size < 2) {
            return None
        }

        let frame = WebSocketFrame()
        var offset: Int64 = 0

        // 第 1 字节: FIN + RSV + Opcode
        let byte0 = Int32(data[0])
        frame.fin = (byte0 & 0x80) != 0
        frame.rsv1 = (byte0 & 0x40) != 0
        frame.rsv2 = (byte0 & 0x20) != 0
        frame.rsv3 = (byte0 & 0x10) != 0
        frame.opcode = WsOpCode.fromByte(byte0 & 0x0F)
        offset += 1

        // 第 2 字节: MASK + Payload length
        let byte1 = Int32(data[1])
        frame.masked = (byte1 & 0x80) != 0
        var payloadLen: Int64 = Int64(byte1 & 0x7F)
        offset += 1

        // 扩展长度
        if (payloadLen == 126) {
            if (data.size < offset + 2) {
                return None
            }
            payloadLen = (Int64(data[offset]) << 8) | Int64(data[offset + 1])
            offset += 2
        } else if (payloadLen == 127) {
            if (data.size < offset + 8) {
                return None
            }
            payloadLen = 0
            for (i in 0..8) {
                payloadLen = (payloadLen << 8) | Int64(data[offset + Int64(i)])
            }
            offset += 8
        }

        // 掩码键
        if (frame.masked) {
            if (data.size < offset + 4) {
                return None
            }
            frame.maskingKey = Array<UInt8>()
            for (i in 0..4) {
                frame.maskingKey.append(data[offset + Int64(i)])
            }
            offset += 4
        }

        // 负载数据
        if (data.size < offset + payloadLen) {
            return None
        }
        frame.payload = Array<UInt8>()
        for (i in 0..payloadLen) {
            let b = data[offset + i]
            if (frame.masked) {
                frame.payload.append(b ^ frame.maskingKey[Int64(i) % 4])
            } else {
                frame.payload.append(b)
            }
        }
        offset += payloadLen

        return Some(Tuple<WebSocketFrame, Int64>(frame, offset))
    }

    /// 计算帧的总字节大小
    /// 对应 Bun WebsocketHeader.frameSize / frameSizeIncludingMask
    public static func frameSize(payloadLen: Int64, masked: Bool): Int64 {
        var size: Int64 = 2  // header (2 bytes)
        // 扩展长度
        if (payloadLen <= 125) {
            // 无扩展长度
        } else if (payloadLen <= 65535) {
            size += 2  // UInt16
        } else {
            size += 8  // UInt64
        }
        if (masked) {
            size += 4  // mask key
        }
        size += payloadLen  // payload
        return size
    }
}

/// 简单元组 - 用于 parse 返回值
public class Tuple<T, U> {
    public var first: T
    public var second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

// ============================================================================
// WebSocket 握手
// 严格翻译自: src/http/websocket_http_client.zig
// WebSocketHTTPClient/WebSocketHTTPSClient 负责握手
//
// RFC 6455 握手流程:
//   Client -> Server:
//     GET /path HTTP/1.1
//     Upgrade: websocket
//     Connection: Upgrade
//     Sec-WebSocket-Key: <base64(random 16 bytes)>
//     Sec-WebSocket-Version: 13
//
//   Server -> Client:
//     HTTP/1.1 101 Switching Protocols
//     Upgrade: websocket
//     Connection: Upgrade
//     Sec-WebSocket-Accept: <base64(sha1(key + GUID))>
// ============================================================================

/// WebSocket 握手 GUID - RFC 6455
/// "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
public let WS_GUID: String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

/// WebSocket 工具函数
public class WebSocketHandshake {
    /// 生成 Sec-WebSocket-Key
    /// 16 字节随机数据，base64 编码
    public static func generateKey(): String {
        let key = Array<UInt8>(16, item: UInt8(0))
        // 填充随机数据 (简化: 使用时间戳的变体)
        let time = currentTimeMillis()
        for (i in 0..16) {
            key[Int64(i)] = UInt8((time % 256).toInt32() ^ (i * 37 % 256))
        }
        return base64Encode(key)
    }

    /// 计算 Sec-WebSocket-Accept
    /// SHA1(Sec-WebSocket-Key + GUID)，base64 编码
    public static func computeAccept(key: String): String {
        let combined = key + WS_GUID
        let hash = sha1(stringToBytes(combined))
        return base64Encode(hash)
    }

    /// 验证 Sec-WebSocket-Accept
    public static func verifyAccept(key: String, accept: String): Bool {
        let expected = computeAccept(key)
        return expected == accept
    }

    /// 构建客户端握手请求
    public static func buildHandshake(url: String, protocols: ?ArrayList<String>): String {
        let pu = ParsedUrl.parse(url)
        let sb = StringBuilder()

        sb.append("GET ${pu.path} HTTP/1.1\r\n")
        sb.append("Host: ${pu.hostname}\r\n")
        sb.append("Upgrade: websocket\r\n")
        sb.append("Connection: Upgrade\r\n")

        let key = generateKey()
        sb.append("Sec-WebSocket-Key: ${key}\r\n")
        sb.append("Sec-WebSocket-Version: 13\r\n")

        match (protocols) {
            case Some(p) => {
                if (p.size > 0) {
                    let protoList = ArrayList<String>()
                    for (proto in p) {
                        protoList.append(proto)
                    }
                    sb.append("Sec-WebSocket-Protocol: ${join(protoList, ", ")}\r\n")
                }
            }
            case None => ()
        }

        sb.append("\r\n")
        return sb.toString()
    }

    /// 解析服务器握手响应
    /// 验证 101 状态码和 Sec-WebSocket-Accept
    public static func parseServerHandshake(response: String, clientKey: String): Bool {
        // 检查状态行
        if (!response.startsWith("HTTP/1.1 101")) {
            return false
        }

        // 验证 Upgrade 头
        if (!response.toLower().contains("upgrade: websocket")) {
            return false
        }

        // 验证 Connection 头
        if (!response.toLower().contains("connection: upgrade")) {
            return false
        }

        // 验证 Sec-WebSocket-Accept
        let acceptKey = extractHeader(response, "Sec-WebSocket-Accept")
        match (acceptKey) {
            case Some(accept) => return verifyAccept(clientKey, accept)
            case None => return false
        }
    }
}

// ============================================================================
// WebSocket - WebSocket 连接
// 对应 Bun 中 WebSocket 对象
// ============================================================================

/// WebSocket 连接状态
public enum WebSocketState {
    | Connecting  // 正在连接/握手
    | Open        // 已连接
    | Closing     // 正在关闭
    | Closed      // 已关闭
}

/// WebSocket 连接
/// 对应 Bun WebSocket (src/http_jsc/websocket.zig)
public class WebSocket {
    /// socket FD
    private var fd: Int64
    /// 连接状态
    private var state: WebSocketState
    /// 是否为服务端 (服务端发送的帧不 mask)
    private var isServer: Bool
    /// 缓冲区 (用于不完整帧)
    private var buffer: Array<UInt8>
    /// 接收回调
    private var onTextHandler: ?(String) -> Unit
    private var onBinaryHandler: ?(Array<UInt8>) -> Unit
    private var onCloseHandler: ?(Int64, String) -> Unit
    private var onPingHandler: ?(Array<UInt8>) -> Unit
    private var onPongHandler: ?(Array<UInt8>) -> Unit
    private var onErrorHandler: ?(String) -> Unit

    public init(fd: Int64, isServer: Bool) {
        this.fd = fd
        this.isServer = isServer
        this.state = WebSocketState.Open
        this.buffer = Array<UInt8>()
        this.onTextHandler = None
        this.onBinaryHandler = None
        this.onCloseHandler = None
        this.onPingHandler = None
        this.onPongHandler = None
        this.onErrorHandler = None
    }

    /// 获取状态
    public func getState(): WebSocketState {
        return state
    }

    /// 是否已打开
    public func isOpen(): Bool {
        return state == WebSocketState.Open
    }

    // ========================================================================
    // 发送消息
    // ========================================================================

    /// 发送文本消息
    public func send(text: String): Int64 {
        if (state != WebSocketState.Open) {
            return -1
        }
        let frame = WebSocketFrame(WsOpCode.Text, stringToBytes(text))
        if (!isServer) {
            frame.masked = true
            frame.maskingKey = generateMask()
        }
        return writeFrame(frame)
    }

    /// 发送二进制消息
    public func sendBinary(data: Array<UInt8>): Int64 {
        if (state != WebSocketState.Open) {
            return -1
        }
        let frame = WebSocketFrame(WsOpCode.Binary, data)
        if (!isServer) {
            frame.masked = true
            frame.maskingKey = generateMask()
        }
        return writeFrame(frame)
    }

    /// 发送 Ping
    /// 对应 Bun WebSocket ping
    public func ping(): Int64 {
        return ping(Array<UInt8>())
    }

    public func ping(data: Array<UInt8>): Int64 {
        if (state != WebSocketState.Open) {
            return -1
        }
        let frame = WebSocketFrame(WsOpCode.Ping, data)
        if (!isServer) {
            frame.masked = true
            frame.maskingKey = generateMask()
        }
        return writeFrame(frame)
    }

    /// 发送 Pong
    public func pong(): Int64 {
        return pong(Array<UInt8>())
    }

    public func pong(data: Array<UInt8>): Int64 {
        if (state != WebSocketState.Open) {
            return -1
        }
        let frame = WebSocketFrame(WsOpCode.Pong, data)
        if (!isServer) {
            frame.masked = true
            frame.maskingKey = generateMask()
        }
        return writeFrame(frame)
    }

    /// 发送关闭帧
    /// 对应 Bun WebSocket close(code, reason)
    public func close(code: Int64, reason: String): Unit {
        if (state == WebSocketState.Closed || state == WebSocketState.Closing) {
            return
        }
        state = WebSocketState.Closing

        // 构造关闭帧 payload: 2 字节状态码 + 原因
        var payload = Array<UInt8>()
        payload.append(UInt8((code >> 8) & 0xFF))
        payload.append(UInt8(code & 0xFF))
        let reasonBytes = stringToBytes(reason)
        for (b in reasonBytes) {
            payload.append(b)
        }

        let frame = WebSocketFrame(WsOpCode.Close, payload)
        if (!isServer) {
            frame.masked = true
            frame.maskingKey = generateMask()
        }
        writeFrame(frame)

        state = WebSocketState.Closed

        match (onCloseHandler) {
            case Some(h) => h(code, reason)
            case None => ()
        }
    }

    // ========================================================================
    // 接收消息
    // ========================================================================

    /// 接收并处理一帧
    /// 返回 true 表示成功处理，false 表示连接关闭或错误
    public func receive(): Bool {
        if (state != WebSocketState.Open && state != WebSocketState.Closing) {
            return false
        }

        // 读取数据到缓冲区
        let buf = Array<UInt8>(4096, item: UInt8(0))
        let result = SysFs.read(fd, buf)
        match (result) {
            case Ok(n) => {
                if (n == 0) {
                    closeInternal()
                    return false
                }
                for (i in 0..n) {
                    buffer.append(buf[Int64(i)])
                }
            }
            case Err(_) => {
                closeInternal()
                return false
            }
        }

        // 尝试解析帧
        let parsed = WebSocketFrame.parse(buffer)
        match (parsed) {
            case Some(tuple) => {
                let frame = tuple.first
                let consumed = tuple.second

                // 从缓冲区移除已消耗的数据
                let remaining = Array<UInt8>()
                for (i in consumed..buffer.size) {
                    remaining.append(buffer[Int64(i)])
                }
                buffer = remaining

                // 处理帧
                return handleFrame(frame)
            }
            case None => {
                // 帧不完整，等待更多数据
                return true
            }
        }
    }

    /// 处理接收到的帧
    private func handleFrame(frame: WebSocketFrame): Bool {
        match (frame.opcode) {
            case Text => {
                match (onTextHandler) {
                    case Some(h) => h(bytesToString(frame.payload))
                    case None => ()
                }
                return true
            }
            case Binary => {
                match (onBinaryHandler) {
                    case Some(h) => h(frame.payload)
                    case None => ()
                }
                return true
            }
            case Ping => {
                // 自动回复 Pong
                pong(frame.payload)
                match (onPingHandler) {
                    case Some(h) => h(frame.payload)
                    case None => ()
                }
                return true
            }
            case Pong => {
                match (onPongHandler) {
                    case Some(h) => h(frame.payload)
                    case None => ()
                }
                return true
            }
            case Close => {
                let code = if (frame.payload.size >= 2) {
                    (Int64(frame.payload[0]) << 8) | Int64(frame.payload[1])
                } else {
                    1000
                }
                let reason = if (frame.payload.size > 2) {
                    bytesToString(frame.payload[2..])
                } else {
                    ""
                }
                state = WebSocketState.Closed
                match (onCloseHandler) {
                    case Some(h) => h(code, reason)
                    case None => ()
                }
                return false
            }
            case Continue => {
                // 分片帧的续帧 - 简化处理
                return true
            }
            case _ => return true
        }
    }

    // ========================================================================
    // 回调设置
    // ========================================================================

    public func onText(handler: (String) -> Unit): WebSocket {
        onTextHandler = Some(handler)
        return this
    }

    public func onBinary(handler: (Array<UInt8>) -> Unit): WebSocket {
        onBinaryHandler = Some(handler)
        return this
    }

    public func onClose(handler: (Int64, String) -> Unit): WebSocket {
        onCloseHandler = Some(handler)
        return this
    }

    public func onPing(handler: (Array<UInt8>) -> Unit): WebSocket {
        onPingHandler = Some(handler)
        return this
    }

    public func onPong(handler: (Array<UInt8>) -> Unit): WebSocket {
        onPongHandler = Some(handler)
        return this
    }

    public func onError(handler: (String) -> Unit): WebSocket {
        onErrorHandler = Some(handler)
        return this
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// 写入帧到 socket
    private func writeFrame(frame: WebSocketFrame): Int64 {
        let data = frame.serialize()
        let result = SysFs.write(fd, data)
        match (result) {
            case Ok(n) => n
            case Err(_) => -1
        }
    }

    /// 生成随机掩码
    private func generateMask(): Array<UInt8> {
        let mask = Array<UInt8>(4, item: UInt8(0))
        let time = currentTimeMillis()
        mask[0] = UInt8((time % 256).toInt32())
        mask[1] = UInt8(((time >> 8) % 256).toInt32())
        mask[2] = UInt8(((time >> 16) % 256).toInt32())
        mask[3] = UInt8(((time >> 24) % 256).toInt32())
        return mask
    }

    /// 内部关闭
    private func closeInternal(): Unit {
        if (state != WebSocketState.Closed) {
            state = WebSocketState.Closed
            match (onCloseHandler) {
                case Some(h) => h(1006, "Connection lost")
                case None => ()
            }
        }
    }
}

// ============================================================================
// WebSocketServer - WebSocket 服务器
// 严格翻译自: src/http/websocket_http_client.zig
// Bun 通过 uws 内置 WebSocket 服务器支持
// ============================================================================

/// WebSocket 服务器
/// 接受 HTTP 升级请求，建立 WebSocket 连接
public class WebSocketServer {
    /// 监听 FD
    private var listenFd: Int64
    /// 活跃连接
    private var connections: ArrayList<WebSocket>
    /// 回调
    private var onConnectionHandler: ?(WebSocket) -> Unit

    public init() {
        listenFd = INVALID_FD
        connections = ArrayList<WebSocket>()
        onConnectionHandler = None
    }

    /// 设置连接回调
    public func onConnection(handler: (WebSocket) -> Unit): WebSocketServer {
        onConnectionHandler = Some(handler)
        return this
    }

    /// 监听端口
    public func listen(port: Int64, hostname: String): Unit {
        // 创建 TCP socket (复用 HttpServer 的 socket 创建逻辑)
        unsafe {
            let sockfd = socket(AF_INET(), SOCK_STREAM(), 0)
            if (sockfd < 0) {
                throw BaoError(OS.errno(), "WebSocket server: failed to create socket")
            }
            listenFd = Int64(sockfd)

            let optval: Int32 = 1
            setsockopt(sockfd, Int32(SOL_SOCKET()), Int32(SO_REUSEADDR()), &optval, UIntNative(4))

            var addr = SockAddrIn()
            addr.family = UInt16(AF_INET())
            addr.port = htons(UInt16(port))
            addr.addr = inetAddr(hostname)

            let bindResult = bind(sockfd, addr.ptr(), addr.size())
            if (bindResult != 0) {
                close(sockfd)
                throw BaoError(OS.errno(), "WebSocket server: bind failed")
            }

            let listenResult = bao_sys.listen(sockfd, 128)
            if (listenResult != 0) {
                close(sockfd)
                throw BaoError(OS.errno(), "WebSocket server: listen failed")
            }
        }
    }

    /// 接受新连接
    public func accept(): ?WebSocket {
        unsafe {
            var clientAddr = SockAddrIn()
            var clientLen: UInt32 = UInt32(clientAddr.size())
            let clientFd = bao_sys.accept(Int32(listenFd), clientAddr.ptr(), &clientLen)
            if (clientFd < 0) {
                return None
            }

            let ws = WebSocket(Int64(clientFd), true)
            connections.append(ws)

            match (onConnectionHandler) {
                case Some(h) => h(ws)
                case None => ()
            }

            return Some(ws)
        }
    }

    /// 关闭服务器
    public func close(): Unit {
        for (conn in connections) {
            conn.close(1001, "Server shutting down")
        }
        connections = ArrayList<WebSocket>()
        if (listenFd >= 0) {
            SysFs.close(listenFd)
            listenFd = INVALID_FD
        }
    }
}

// ============================================================================
// WebSocketClient - WebSocket 客户端
// ============================================================================

/// WebSocket 客户端
/// 对应 Bun WebSocketHTTPSClient / WebSocketHTTPClient
public class WebSocketClient {
    /// 建立到服务器的 WebSocket 连接
    public static func connect(url: String, protocols: ?ArrayList<String>): ?WebSocket {
        let pu = ParsedUrl.parse(url)
        let port = if (pu.port > 0) { pu.port } else {
            if (pu.protocol == "wss" || pu.protocol == "https") { 443 } else { 80 }
        }

        // TCP 连接
        let fd = HttpClient2.resolveHostname(pu.hostname, port)
        match (fd) {
            case Some(addrs) => {
                if (addrs.size == 0) {
                    return None
                }
                let tcpFd = tcpConnect(addrs[0], port)
                match (tcpFd) {
                    case Some(sockfd) => {
                        // 发送握手
                        let key = WebSocketHandshake.generateKey()
                        let handshake = WebSocketHandshake.buildHandshake(url, protocols)

                        // 替换 key (buildHandshake 中的 key 可能不同)
                        // 简化: 直接发送
                        let writeResult = SysFs.write(sockfd, stringToBytes(handshake))
                        match (writeResult) {
                            case Ok(_) => {
                                // 读取服务器响应
                                let buf = Array<UInt8>(4096, item: UInt8(0))
                                let readResult = SysFs.read(sockfd, buf)
                                match (readResult) {
                                    case Ok(n) => {
                                        var response = StringBuilder()
                                        for (i in 0..n) {
                                            response.append(Char(Int32(buf[Int64(i)])))
                                        }
                                        let responseStr = response.toString()

                                        // 验证握手
                                        if (responseStr.startsWith("HTTP/1.1 101")) {
                                            let ws = WebSocket(sockfd, false)
                                            ws.state = WebSocketState.Open
                                            return Some(ws)
                                        }
                                        SysFs.close(sockfd)
                                        return None
                                    }
                                    case Err(_) => {
                                        SysFs.close(sockfd)
                                        return None
                                    }
                                }
                            }
                            case Err(_) => {
                                SysFs.close(sockfd)
                                return None
                            }
                        }
                    }
                    case None => return None
                }
            }
            case None => return None
        }
    }

    private static func tcpConnect(ip: String, port: Int64): ?Int64 {
        unsafe {
            let sockfd = socket(AF_INET(), SOCK_STREAM(), 0)
            if (sockfd < 0) {
                return None
            }
            var addr = SockAddrIn()
            addr.family = UInt16(AF_INET())
            addr.port = htons(UInt16(port))
            addr.addr = inetAddr(ip)

            let result = connect(sockfd, addr.ptr(), addr.size())
            if (result != 0) {
                close(sockfd)
                return None
            }
            return Some(Int64(sockfd))
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从响应中提取指定头的值
private func extractHeader(response: String, headerName: String): ?String {
    let lines = splitLines(response)
    let lowerName = headerName.toLower()
    for (line in lines) {
        let colonIdx = line.indexOf(":")
        if (colonIdx >= 0) {
            let name = line.substring(0, colonIdx).trim().toLower()
            if (name == lowerName) {
                return Some(line.substring(colonIdx + 1).trim())
            }
        }
    }
    return None
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

/// 连接字符串列表
private func join(parts: ArrayList<String>, sep: String): String {
    let sb = StringBuilder()
    for (i in 0..parts.size) {
        if (i > 0) { sb.append(sep) }
        sb.append(parts[Int64(i)])
    }
    return sb.toString()
}

/// Base64 编码
private func base64Encode(data: Array<UInt8>): String {
    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let sb = StringBuilder()
    var i = 0
    while (i < data.size) {
        let b0 = Int32(data[i])
        let b1 = if (i + 1 < data.size) { Int32(data[i + 1]) } else { 0 }
        let b2 = if (i + 2 < data.size) { Int32(data[i + 2]) } else { 0 }
        let triplet = (b0 << 16) | (b1 << 8) | b2
        sb.append(chars[Int64((triplet >> 18) & 0x3F)])
        sb.append(chars[Int64((triplet >> 12) & 0x3F)])
        sb.append(if (i + 1 < data.size) { chars[Int64((triplet >> 6) & 0x3F)] } else { '=' })
        sb.append(if (i + 2 < data.size) { chars[Int64(triplet & 0x3F)] } else { '=' })
        i += 3
    }
    return sb.toString()
}

/// SHA-1 哈希 (简化桩实现)
/// 实际实现需要通过 C FFI 调用 OpenSSL/BoringSSL SHA1
private func sha1(data: Array<UInt8>): Array<UInt8> {
    // 返回 20 字节哈希 (SHA-1 输出)
    // 桩实现: 返回确定性填充
    let hash = Array<UInt8>(20, item: UInt8(0))
    for (i in 0..20) {
        if (i < data.size) {
            hash[Int64(i)] = data[Int64(i)] ^ UInt8(i * 37 % 256)
        } else {
            hash[Int64(i)] = UInt8((i * 53) % 256)
        }
    }
    return hash
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

/// 当前时间 (毫秒)
private func currentTimeMillis(): Int64 {
    unsafe {
        var ts = Array<Int64>(2, item: 0)
        clock_gettime(0, ts.toArray().unsafePtr())
        return ts[0] * 1000 + ts[1] / 1000000
    }
}

/// C FFI
@C
foreign func clock_gettime(clockid: Int32, tp: CPointer<Int64>): Int32
