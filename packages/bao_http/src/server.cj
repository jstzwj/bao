// bao_http server - HTTP/1.1 TCP 服务器
// 严格翻译自: src/http/http.zig, src/http/HTTPContext.zig, src/http/HTTPThread.zig
// 参考: src/http/Headers.zig, src/http/HeaderBuilder.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_event_loop.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// ServerConfig - 服务器配置
// 严格翻译自: src/http/HTTPContext.zig 中 uws.App 的配置
// Bun: uws.App(options) 中 ssl, maxConnections 等参数
// ============================================================================

/// HTTP 服务器配置
/// 对应 Bun uws.App 以及 HTTPThread 中的配置参数
public class ServerConfig {
    /// 监听端口 - 对应 Bun Bun.serve({ port })
    public var port: Int64
    /// 监听主机名
    public var hostname: String
    /// 最大连接数 - 对应 Bun max_simultaneous_requests
    public var maxConnections: Int64
    /// Keep-Alive 超时 (秒) - 对应 Bun idle_timeout_seconds
    public var keepAliveTimeout: Int64
    /// 请求头最大大小 - 对应 Bun max_http_header_size (16KB)
    public var maxHeaderSize: Int64
    /// 请求体最大大小
    public var maxBodySize: Int64
    /// 是否启用 TCP_NODELAY
    public var tcpNoDelay: Bool
    /// 是否启用 SO_REUSEPORT
    public var reusePort: Bool
    /// 是否为开发模式 (详细错误)
    public var development: Bool

    public init() {
        port = 3000
        hostname = "0.0.0.0"
        maxConnections = 256
        keepAliveTimeout = 5
        maxHeaderSize = 16384  // 16KB - 对应 Bun BUN_DEFAULT_MAX_HTTP_HEADER_SIZE
        maxBodySize = 104857600  // 100MB
        tcpNoDelay = true
        reusePort = false
        development = false
    }

    public init(port: Int64, hostname: String) {
        this.port = port
        this.hostname = hostname
        this.maxConnections = 256
        this.keepAliveTimeout = 5
        this.maxHeaderSize = 16384
        this.maxBodySize = 104857600
        this.tcpNoDelay = true
        this.reusePort = false
        this.development = false
    }
}

// ============================================================================
// RawRequest - 原始 HTTP 请求解析结果
// 严格翻译自: src/http/http.zig 中 picohttp.Request 的使用
// Bun 使用 picohttp 库解析 HTTP/1.1 请求行和头部
// picohttp.Request { method, path, minor_version, headers }
// ============================================================================

/// 原始 HTTP 请求 - 对应 picohttp.Request
public class RawRequest {
    /// HTTP 方法 - 对应 picohttp.Request.method
    public var method: String
    /// 请求路径 - 对应 picohttp.Request.path
    public var path: String
    /// HTTP 次版本号 - 对应 picohttp.Request.minor_version
    public var minorVersion: Int64
    /// 请求头列表
    public var headers: ArrayList<HeaderPair>
    /// 请求体字节
    public var body: Array<UInt8>
    /// 是否解析完整
    public var complete: Bool

    public init() {
        method = "GET"
        path = "/"
        minorVersion = 1
        headers = ArrayList<HeaderPair>()
        body = Array<UInt8>()
        complete = false
    }
}

/// HTTP 头部键值对 - 对应 picohttp.Header
/// Bun: picohttp.Header { name: []const u8, value: []const u8 }
public class HeaderPair {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

// ============================================================================
// HttpServer - HTTP/1.1 TCP 服务器
// 严格翻译自: src/http/HTTPContext.zig (NewHTTPContext)
// 参考: src/http/HTTPThread.zig, src/http/http.zig
//
// Bun 使用 uws (micro WebSockets) 库实现高性能 HTTP 服务器
// HTTPContext 管理 TCP socket 池、keep-alive 连接、请求/响应处理
// 仓颉通过 C FFI 直接调用 POSIX socket API 实现等价功能
// ============================================================================

/// HTTP/1.1 TCP 服务器
/// 对应 Bun HTTPContext + HTTPThread 的服务端功能
public class HttpServer {
    /// 服务器配置
    private var config: ServerConfig
    /// 请求处理器 - 对应 Bun fetch handler
    private var handler: ?RequestHandler
    /// 监听 socket FD
    private var listenFd: Int64
    /// 是否正在监听
    private var listening: Bool
    /// 活跃连接数
    private var activeConnections: Int64
    /// 事件循环 - 对应 Bun HTTPThread.loop
    private var eventLoop: EventLoop

    public init() {
        config = ServerConfig()
        handler = None
        listenFd = INVALID_FD
        listening = false
        activeConnections = 0
        eventLoop = EventLoop()
    }

    public init(config: ServerConfig) {
        this.config = config
        handler = None
        listenFd = INVALID_FD
        listening = false
        activeConnections = 0
        eventLoop = EventLoop()
    }

    /// 设置请求处理函数
    /// 对应 Bun: Bun.serve({ fetch(req) { ... } })
    public func setHandler(handler: RequestHandler): HttpServer {
        this.handler = Some(handler)
        return this
    }

    // ========================================================================
    // listen - 开始监听
    // 严格翻译自: src/http/HTTPContext.zig 中的 listen_socket 创建
    // 以及 uws 内部的 socket/bind/listen 调用链
    // ========================================================================

    /// 开始监听 - 对应 Bun Bun.serve() 启动流程
    /// 创建 TCP socket -> bind -> listen -> accept loop
    public func listen(port: Int64, hostname: String): Unit {
        config.port = port
        config.hostname = hostname
        listening = true

        unsafe {
            // 创建 TCP socket
            // 对应 uws 内部: socket(AF_INET, SOCK_STREAM | SOCK_NONBLOCK, 0)
            let sockfd = socket(Int32(AF_INET()), Int32(SOCK_STREAM() | SOCK_NONBLOCK()), 0)
            if (sockfd < 0) {
                throw BaoError(OS.errno(), "Failed to create socket")
            }
            listenFd = Int64(sockfd)

            // SO_REUSEADDR - 允许端口复用
            let optval: Int32 = 1
            setsockopt(sockfd, Int32(SOL_SOCKET()), Int32(SO_REUSEADDR()), &optval, UIntNative(4))

            if (config.reusePort) {
                // SO_REUSEPORT - 对应 Bun uws 配置
                setsockopt(sockfd, Int32(SOL_SOCKET()), Int32(SO_REUSEPORT()), &optval, UIntNative(4))
            }

            // TCP_NODELAY - 禁用 Nagle 算法
            if (config.tcpNoDelay) {
                setsockopt(sockfd, Int32(IPPROTO_TCP()), Int32(TCP_NODELAY()), &optval, UIntNative(4))
            }

            // bind - 对应 uws us_listen_socket_create
            var addr = SockAddrIn()
            addr.family = UInt16(AF_INET())
            addr.port = htons(UInt16(port))
            addr.addr = inetAddr(config.hostname)

            let bindResult = bind(sockfd, addr.ptr(), addr.size())
            if (bindResult != 0) {
                close(sockfd)
                throw BaoError(OS.errno(), "Failed to bind to ${hostname}:${port}")
            }

            // listen - backlog = 128 (对应 Bun uws 默认 SOMAXCONN)
            let listenResult = bao_sys.listen(sockfd, 128)
            if (listenResult != 0) {
                close(sockfd)
                throw BaoError(OS.errno(), "Failed to listen on ${hostname}:${port}")
            }
        }
    }

    /// 开始监听 (默认 hostname)
    public func listen(port: Int64): Unit {
        listen(port, "0.0.0.0")
    }

    /// 使用配置对象监听
    public func listen(): Unit {
        listen(config.port, config.hostname)
    }

    // ========================================================================
    // accept - 接受新连接
    // 严格翻译自: src/http/HTTPContext.zig 中的 onOpen callback
    // Bun: HTTPContext 通过 uws 回调管理连接生命周期
    // ========================================================================

    /// 接受新连接 - 返回客户端 FD
    /// 对应 Bun uws 内部 accept 调用
    public func accept(): ?ClientConnection {
        if (activeConnections >= config.maxConnections) {
            return None  // 对应 Bun max_simultaneous_requests 限制
        }

        unsafe {
            var clientAddr = SockAddrIn()
            var clientLen: UInt32 = UInt32(clientAddr.size())
            let clientFd = bao_sys.accept(Int32(listenFd), clientAddr.ptr(), &clientLen)
            if (clientFd < 0) {
                return None
            }

            activeConnections += 1
            return Some(ClientConnection(
                Int64(clientFd),
                this,
                config.keepAliveTimeout
            ))
        }
    }

    // ========================================================================
    // parseRequest - 解析 HTTP 请求
    // 严格翻译自: src/http/http.zig 中 picohttp 解析流程
    // Bun 使用 picohttp_request_parse C 库解析 HTTP/1.1 请求
    // picohttp 底层是有限状态机(FSM)解析器
    // ========================================================================

    /// 解析 HTTP 请求 - 对应 picohttp_request_parse
    /// 解析请求行 (method + path + version) + 头部 + body
    public static func parseRequest(data: Array<UInt8>): ?RawRequest {
        let str = bytesToString(data)
        return parseRequestFromString(str)
    }

    /// 从字符串解析 HTTP 请求
    /// 对应 picohttp 请求解析器状态机
    public static func parseRequestFromString(raw: String): ?RawRequest {
        let request = RawRequest()

        // 查找头部结束位置 \r\n\r\n
        let headerEnd = raw.indexOf("\r\n\r\n")
        if (headerEnd < 0) {
            return None  // 头部不完整
        }

        let headerSection = raw.substring(0, headerEnd)
        var lines = headerEnd > 0 ? splitLines(headerSection) : ArrayList<String>()

        // 解析请求行: METHOD /path HTTP/1.x
        // 对应 picohttp 解析 method, path, minor_version
        if (lines.size == 0) {
            return None
        }

        let requestLine = lines[0]
        let parts = split(requestLine, " ")
        if (parts.size < 3) {
            return None
        }

        request.method = parts[0]
        request.path = parts[1]

        // 解析 HTTP 版本: HTTP/1.x
        let versionStr = parts[2]
        if (versionStr.startsWith("HTTP/1.")) {
            let minorStr = versionStr.substring(7)
            try {
                request.minorVersion = Int64.parse(minorStr)
            } catch (_: Exception) {
                request.minorVersion = 1
            }
        }

        // 解析头部 - 对应 picohttp 逐行解析 headers
        for (i in 1..lines.size) {
            let line = lines[Int64(i)]
            let colonIdx = line.indexOf(":")
            if (colonIdx >= 0) {
                let name = line.substring(0, colonIdx).trim()
                let value = line.substring(colonIdx + 1).trim()
                request.headers.append(HeaderPair(name, value))
            }
        }

        // 解析 body - Content-Length 决定
        let bodyStart = headerEnd + 4
        if (bodyStart < raw.size) {
            let bodyStr = raw.substring(bodyStart)
            request.body = stringToBytes(bodyStr)
        }

        request.complete = true
        return Some(request)
    }

    // ========================================================================
    // writeResponse - 写入 HTTP 响应
    // 严格翻译自: src/http/http.zig 中响应写入流程
    // Bun 通过 uws/c-ares 写入响应，支持 chunked 和 content-length
    // ========================================================================

    /// 写入 HTTP 响应到 socket
    /// 对应 Bun HTTPClient 中的响应写入流程
    public static func writeResponse(clientFd: Int64, response: Response): Int64 {
        let raw = serializeResponse(response)
        return writeRaw(clientFd, stringToBytes(raw))
    }

    /// 序列化 HTTP 响应 - 对应 picohttp 响应序列化
    /// HTTP/1.1 STATUS_CODE REASON\r\n
    /// Header: Value\r\n
    /// \r\n
    /// body
    public static func serializeResponse(response: Response): String {
        let sb = StringBuilder()

        // 状态行: HTTP/1.1 <status> <reason>
        // 对应 picohttp.Response: "HTTP/1.1 " + status + " " + reason
        sb.append("HTTP/1.1 ")
        sb.append(response.status.toString())
        sb.append(" ")
        sb.append(response.statusText)
        sb.append("\r\n")

        // 写入 Server 头
        sb.append("Server: bao/${BAO_VERSION}\r\n")

        // 写入 Date 头
        sb.append("Date: ")
        sb.append(formatHttpDate())
        sb.append("\r\n")

        // Connection: keep-alive 或 close
        let connectionVal = response.headers.get("connection")
        match (connectionVal) {
            case Some(v) => sb.append("Connection: ${v}\r\n")
            case None => sb.append("Connection: keep-alive\r\n")
        }

        // Content-Length / Transfer-Encoding
        let hasContentLength = response.headers.has("content-length")
        let hasTransferEncoding = response.headers.has("transfer-encoding")
        match (response.body) {
            case Some(body) => {
                if (!hasContentLength && !hasTransferEncoding) {
                    sb.append("Content-Length: ${body.size}\r\n")
                }
            }
            case None => {
                if (!hasContentLength) {
                    sb.append("Content-Length: 0\r\n")
                }
            }
        }

        // 写入响应头
        for (key in response.headers.keys()) {
            match (response.headers.get(key)) {
                case Some(v) => sb.append("${key}: ${v}\r\n")
                case None => ()
            }
        }

        // 空行分隔头部和 body
        sb.append("\r\n")

        // 写入 body
        match (response.body) {
            case Some(body) => sb.append(bytesToString(body))
            case None => ()
        }

        return sb.toString()
    }

    /// 写入 chunked 编码的响应分块
    /// 对应 HTTP/1.1 Transfer-Encoding: chunked
    /// chunk 格式: <hex-size>\r\n<data>\r\n
    /// 终止块: 0\r\n\r\n
    public static func writeChunk(clientFd: Int64, data: Array<UInt8>): Int64 {
        let sb = StringBuilder()
        // hex 长度 + \r\n + data + \r\n
        sb.append(toHexString(data.size))
        sb.append("\r\n")
        sb.append(bytesToString(data))
        sb.append("\r\n")
        return writeRaw(clientFd, stringToBytes(sb.toString()))
    }

    /// 写入 chunked 终止块
    /// 对应 Bun end_of_chunked_http1_1_encoding_response_body: "0\r\n\r\n"
    public static func writeChunkEnd(clientFd: Int64): Int64 {
        return writeRaw(clientFd, stringToBytes("0\r\n\r\n"))
    }

    // ========================================================================
    // 连接处理 - Keep-Alive 循环
    // 严格翻译自: src/http/HTTPContext.zig 中 socket 复用逻辑
    // Bun: PooledSocket 管理 keep-alive socket 池
    // HTTPContext 维护 pool_size=64 的连接池
    // ========================================================================

    /// 处理连接 - keep-alive 请求循环
    /// 对应 Bun HTTPContext 中的 onData 回调
    /// 在 keep-alive 超时前持续读取并处理请求
    public func handleConnection(conn: ClientConnection): Unit {
        var keepAlive = true

        while (keepAlive && conn.isOpen()) {
            // 读取请求数据
            let data = conn.readRequest()
            match (data) {
                case Some(rawData) => {
                    // 解析请求
                    let parsed = parseRequest(rawData)
                    match (parsed) {
                        case Some(rawReq) => {
                            // 构造 Request 对象
                            let request = buildRequest(rawReq, conn)

                            // 调用用户 handler
                            let response = match (handler) {
                                case Some(h) => h(request)
                                case None => Response(500, "No handler registered")
                            }

                            // 检查 Connection 头决定是否 keep-alive
                            let connHeader = rawReq.headers
                            keepAlive = shouldKeepAlive(rawReq)

                            // 设置响应 Connection 头
                            if (!keepAlive) {
                                response.headers.set("Connection", "close")
                            }

                            // 写入响应
                            writeResponse(conn.fd, response)
                        }
                        case None => {
                            // 解析失败 - 返回 400
                            let errResp = Response(400, "Bad Request")
                            errResp.headers.set("Connection", "close")
                            writeResponse(conn.fd, errResp)
                            keepAlive = false
                        }
                    }
                }
                case None => {
                    keepAlive = false  // 读取失败或连接关闭
                }
            }
        }

        conn.close()
        activeConnections -= 1
    }

    /// 判断是否应该 keep-alive
    /// HTTP/1.1 默认 keep-alive，显式 Connection: close 时关闭
    private static func shouldKeepAlive(rawReq: RawRequest): Bool {
        for (h in rawReq.headers) {
            if (h.name.toLower() == "connection") {
                return h.value.toLower() != "close"
            }
        }
        // HTTP/1.1 默认 keep-alive
        return rawReq.minorVersion >= 1
    }

    /// 从 RawRequest 构建 Request 对象
    private static func buildRequest(rawReq: RawRequest, conn: ClientConnection): Request {
        let method = HttpMethod.fromString(rawReq.method)
        let request = Request(method, rawReq.path)

        // 设置头部
        for (h in rawReq.headers) {
            request.headers.set(h.name, h.value)
        }

        // 设置 body
        if (rawReq.body.size > 0) {
            request.body = Some(rawReq.body)
        }

        return request
    }

    /// 处理单个请求 (不经过网络，用于测试)
    public func handleRequest(request: Request): Response {
        match (handler) {
            case Some(h) => h(request)
            case None => Response(500, "No handler registered")
        }
    }

    /// 关闭服务器
    public func close(): Unit {
        listening = false
        if (listenFd >= 0) {
            SysFs.close(listenFd)
            listenFd = INVALID_FD
        }
    }

    public func isListening(): Bool {
        return listening
    }

    public func getPort(): Int64 {
        return config.port
    }

    public func getAddress(): String {
        return "${config.hostname}:${config.port}"
    }

    public func getActiveConnections(): Int64 {
        return activeConnections
    }
}

// ============================================================================
// ClientConnection - 客户端 TCP 连接
// 严格翻译自: src/http/HTTPContext.zig PooledSocket
// Bun: PooledSocket { http_socket, hostname_buf, port, ... }
// ============================================================================

/// 客户端连接封装 - 对应 Bun PooledSocket
public class ClientConnection {
    /// socket 文件描述符
    public let fd: Int64
    /// 关联的服务器引用
    private var server: ?HttpServer
    /// keep-alive 超时 (秒)
    private var keepAliveTimeout: Int64
    /// 是否已打开
    private var open: Bool
    /// 读取缓冲区
    private var readBuffer: Array<UInt8>
    /// 远端地址
    public var remoteAddress: String
    /// 远端端口
    public var remotePort: Int64

    public init(fd: Int64, server: HttpServer, keepAliveTimeout: Int64) {
        this.fd = fd
        this.server = Some(server)
        this.keepAliveTimeout = keepAliveTimeout
        this.open = true
        this.readBuffer = Array<UInt8>(4096, item: UInt8(0))
        this.remoteAddress = ""
        this.remotePort = 0
    }

    /// 是否打开
    public func isOpen(): Bool {
        return open
    }

    /// 读取完整 HTTP 请求
    /// 对应 Bun HTTPThread 中从 socket 读取直到 header 完整
    public func readRequest(): ?Array<UInt8> {
        var allData = Array<UInt8>()
        var headerComplete = false
        var contentLength: Int64 = -1

        // 循环读取直到获取完整头部
        while (!headerComplete) {
            let bytesRead = readChunk()
            if (bytesRead.size == 0) {
                if (allData.size == 0) {
                    return None  // 连接已关闭
                }
                break  // 没有更多数据可用
            }
            for (b in bytesRead) {
                allData.append(b)
            }

            // 检查头部是否完整 (\r\n\r\n)
            headerComplete = containsHeaderEnd(allData)
        }

        // 解析 Content-Length
        contentLength = extractContentLength(allData)

        // 如果有 body，继续读取直到 body 完整
        if (contentLength > 0) {
            let headerEndIdx = findHeaderEnd(allData)
            if (headerEndIdx >= 0) {
                let bodyStart = Int64(headerEndIdx) + 4
                let bodyReceived = allData.size - bodyStart
                let remaining = contentLength - bodyReceived

                while (remaining > 0) {
                    let chunk = readChunk()
                    if (chunk.size == 0) {
                        break
                    }
                    for (b in chunk) {
                        allData.append(b)
                    }
                }
            }
        }

        return Some(allData)
    }

    /// 读取一块数据
    private func readChunk(): Array<UInt8> {
        let result = SysFs.read(fd, readBuffer)
        match (result) {
            case Ok(n) => {
                if (n == 0) {
                    return Array<UInt8>()
                }
                var data = Array<UInt8>()
                for (i in 0..n) {
                    data.append(readBuffer[Int64(i)])
                }
                return data
            }
            case Err(_) => return Array<UInt8>()
        }
    }

    /// 写入数据
    public func write(data: Array<UInt8>): Int64 {
        let result = SysFs.write(fd, data)
        match (result) {
            case Ok(n) => n
            case Err(_) => -1
        }
    }

    /// 关闭连接
    public func close(): Unit {
        if (open) {
            open = false
            SysFs.close(fd)
        }
    }

    /// 设置 TCP_NODELAY
    public func setTcpNoDelay(enabled: Bool): Unit {
        unsafe {
            let val: Int32 = if (enabled) { 1 } else { 0 }
            setsockopt(Int32(fd), Int32(IPPROTO_TCP()), Int32(TCP_NODELAY()), &val, UIntNative(4))
        }
    }
}

// ============================================================================
// SockAddrIn - sockaddr_in 封装
// 严格翻译自: POSIX sockaddr_in 结构体
// ============================================================================

/// IPv4 地址结构 - 对应 POSIX struct sockaddr_in
public class SockAddrIn {
    /// 地址族 (AF_INET = 2)
    public var family: UInt16
    /// 端口 (网络字节序)
    public var port: UInt16
    /// IP 地址 (网络字节序)
    public var addr: UInt32
    /// 填充
    private var padding: Array<UInt8>

    public init() {
        family = 2  // AF_INET
        port = 0
        addr = 0
        padding = Array<UInt8>(8, item: UInt8(0))
    }

    /// 获取 sockaddr 指针 - C FFI 用
    public func ptr(): CPointer<Unit> {
        unsafe {
            // 分配 16 字节用于 sockaddr_in
            let ptr = malloc(UIntNative(16))
            let bytes = CPointer<UInt8>(ptr)
            // sin_family (2 bytes)
            (bytes + IntNative(0)).write(UInt8(family & 0xFF))
            (bytes + IntNative(1)).write(UInt8((family >> 8) & 0xFF))
            // sin_port (2 bytes, network byte order)
            (bytes + IntNative(2)).write(UInt8(port & 0xFF))
            (bytes + IntNative(3)).write(UInt8((port >> 8) & 0xFF))
            // sin_addr (4 bytes, network byte order)
            (bytes + IntNative(4)).write(UInt8(addr & 0xFF))
            (bytes + IntNative(5)).write(UInt8((addr >> 8) & 0xFF))
            (bytes + IntNative(6)).write(UInt8((addr >> 16) & 0xFF))
            (bytes + IntNative(7)).write(UInt8((addr >> 24) & 0xFF))
            // sin_zero (8 bytes, zeroed)
            for (i in 8..16) {
                (bytes + IntNative(i)).write(UInt8(0))
            }
            return ptr
        }
    }

    /// 结构体大小
    public func size(): UInt32 {
        return UInt32(16)
    }
}

// ============================================================================
// 网络 C FFI 绑定
// 严格翻译自: POSIX socket API
// 对应 Bun 通过 uws 使用底层 C socket API
// ============================================================================

// POSIX socket 常量
@C
foreign func socket(domain: Int32, type_: Int32, protocol: Int32): Int32
@C
foreign func bind(sockfd: Int32, addr: CPointer<Unit>, addrlen: UInt32): Int32
@C
foreign func listen(sockfd: Int32, backlog: Int32): Int32
@C
foreign func accept(sockfd: Int32, addr: CPointer<Unit>, addrlen: CPointer<UInt32>): Int32
@C
foreign func connect(sockfd: Int32, addr: CPointer<Unit>, addrlen: UInt32): Int32
@C
foreign func setsockopt(sockfd: Int32, level: Int32, optname: Int32, optval: CPointer<Unit>, optlen: UIntNative): Int32
@C
foreign func getsockopt(sockfd: Int32, level: Int32, optname: Int32, optval: CPointer<Unit>, optlen: CPointer<UIntNative>): Int32
@C
foreign func recv(sockfd: Int32, buf: CPointer<Unit>, len: UIntNative, flags: Int32): UIntNative
@C
foreign func send(sockfd: Int32, buf: CPointer<Unit>, len: UIntNative, flags: Int32): UIntNative
@C
foreign func shutdown(sockfd: Int32, how: Int32): Int32
@C
foreign func inet_pton(af: Int32, src: CPointer<Int8>, dst: CPointer<Unit)): Int32
@C
foreign func htons(hostshort: UInt16): UInt16
@C
foreign func ntohs(netshort: UInt16): UInt16
@C
foreign func htonl(hostlong: UInt32): UInt32
@C
foreign func ntohl(netlong: UInt32): UInt32
@C
foreign func getaddrinfo(name: CPointer<Int8>, service: CPointer<Int8>, hints: CPointer<Unit>, result: CPointer<CPointer<Unit>>): Int32
@C
foreign func freeaddrinfo(addr: CPointer<Unit>): Unit
@C
foreign func getpeername(sockfd: Int32, addr: CPointer<Unit>, addrlen: CPointer<UInt32>): Int32
@C
foreign func getsockname(sockfd: Int32, addr: CPointer<Unit>, addrlen: CPointer<UInt32>): Int32
@C
foreign func poll(fds: CPointer<Unit>, nfds: UIntNative, timeout: Int32): Int32

/// Socket 常量 - 对应 Linux x86_64 值
public func AF_INET(): Int32 { 2 }
public func AF_INET6(): Int32 { 10 }
public func AF_UNSPEC(): Int32 { 0 }
public func SOCK_STREAM(): Int32 { 1 }
public func SOCK_DGRAM(): Int32 { 2 }
public func SOCK_NONBLOCK(): Int32 { 2048 }  // O_NONBLOCK on Linux
public func SOL_SOCKET(): Int32 { 1 }
public func SO_REUSEADDR(): Int32 { 2 }
public func SO_REUSEPORT(): Int32 { 15 }
public func SO_KEEPALIVE(): Int32 { 9 }
public func SO_RCVTIMEO(): Int32 { 20 }
public func SO_SNDTIMEO(): Int32 { 21 }
public func IPPROTO_TCP(): Int32 { 6 }
public func TCP_NODELAY(): Int32 { 1 }

// ============================================================================
// 网络辅助函数
// ============================================================================

/// 将 IP 地址字符串转为网络字节序整数
/// 对应 inet_pton(AF_INET, ...)
public func inetAddr(ip: String): UInt32 {
    unsafe {
        let ipPtr = unsafeNewCString(ip)
        var addr: UInt32 = 0
        let result = inet_pton(AF_INET(), ipPtr, &addr)
        if (result != 1) {
            return 0  // INADDR_ANY
        }
        return addr
    }
}

/// 原始写入到 FD
public func writeRaw(fd: Int64, data: Array<UInt8>): Int64 {
    let result = SysFs.write(fd, data)
    match (result) {
        case Ok(n) => n
        case Err(_) => -1
    }
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

/// 按行分割 (处理 \r\n)
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

/// 按分隔符分割字符串
private func split(s: String, sep: String): ArrayList<String> {
    let parts = ArrayList<String>()
    var remaining = s
    while (true) {
        let idx = remaining.indexOf(sep)
        if (idx < 0) {
            parts.append(remaining)
            break
        }
        parts.append(remaining.substring(0, idx))
        remaining = remaining.substring(idx + sep.size)
    }
    return parts
}

/// 检查字节数组是否包含 \r\n\r\n (头部结束)
private func containsHeaderEnd(data: Array<UInt8>): Bool {
    return findHeaderEnd(data) >= 0
}

/// 查找 \r\n\r\n 位置
private func findHeaderEnd(data: Array<UInt8>): Int64 {
    if (data.size < 4) {
        return -1
    }
    for (i in 0..(data.size - 3)) {
        if (data[i] == UInt8(13) && data[Int64(i) + 1] == UInt8(10) &&
            data[Int64(i) + 2] == UInt8(13) && data[Int64(i) + 3] == UInt8(10)) {
            return i
        }
    }
    return -1
}

/// 从原始请求头中提取 Content-Length
private func extractContentLength(data: Array<UInt8>): Int64 {
    let str = bytesToString(data)
    let headerEnd = str.indexOf("\r\n\r\n")
    if (headerEnd < 0) {
        return -1
    }
    let headerSection = str.substring(0, headerEnd)
    let lines = splitLines(headerSection)
    for (line in lines) {
        let lower = line.toLower()
        if (lower.startsWith("content-length:")) {
            let value = line.substring(15).trim()
            try {
                return Int64.parse(value)
            } catch (_: Exception) {
                return -1
            }
        }
    }
    return 0
}

/// 整数转十六进制字符串
private func toHexString(n: Int64): String {
    if (n == 0) {
        return "0"
    }
    let hexChars = "0123456789abcdef"
    var result = StringBuilder()
    var v = n
    while (v > 0) {
        let digit = Int32(v % 16)
        result.append(hexChars[Int64(digit)])
        v = v / 16
    }
    // 反转
    let s = result.toString()
    let sb = StringBuilder()
    for (i in 0..s.size) {
        sb.append(s[s.size - 1 - i])
    }
    return sb.toString()
}

/// 格式化 HTTP 日期 - RFC 7231
/// 示例: "Fri, 15 May 2026 00:00:00 GMT"
private func formatHttpDate(): String {
    // 简化实现，返回静态日期
    // 实际实现需要 C FFI gmtime_r
    return "Fri, 15 May 2026 00:00:00 GMT"
}

/// C 字符串工具 - 从 bao_sys 包
internal func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + IntNative(i)).write(Int8(s[Int64(i)].value))
        }
        (bytesPtr + IntNative(len)).write(Int8(0))
        return bytesPtr
    }
}
