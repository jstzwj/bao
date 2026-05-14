// bao_http client - HTTP/1.1 客户端
// 严格翻译自: src/http/AsyncHTTP.zig, src/http/http.zig
// 参考: src/http/HTTPThread.zig, src/http/HeaderBuilder.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_event_loop.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// HttpClientState - 客户端请求状态
// 严格翻译自: src/http/AsyncHTTP.zig:85-91
//   pub const State = enum(u32) {
//       pending = 0,
//       scheduled = 1,
//       sending = 2,
//       success = 3,
//       fail = 4,
//   };
// ============================================================================

/// HTTP 客户端状态 - 对应 Bun AsyncHTTP.State
public enum HttpClientState {
    | Pending    // 0 - 初始状态
    | Scheduled  // 1 - 已调度
    | Sending    // 2 - 正在发送
    | Success    // 3 - 成功
    | Fail       // 4 - 失败

    public func isComplete(): Bool {
        match (this) {
            case Success => true
            case Fail => true
            case _ => false
        }
    }
}

// ============================================================================
// HttpRequestBuilder - HTTP 请求构建器
// 严格翻译自: src/http/HeaderBuilder.zig
// Bun: HeaderBuilder { content, header_count, entries }
// 用于构建 HTTP/1.1 请求的头部和 body
// ============================================================================

/// HTTP 请求构建器 - 对应 Bun HeaderBuilder
public class HttpRequestBuilder {
    /// HTTP 方法
    private var method: HttpMethod
    /// URL
    private var url: String
    /// 请求头
    private var headers: Headers
    /// 请求体
    private var body: ?Array<UInt8>
    /// 解析后的 URL
    private var parsedUrl: ?ParsedUrl

    public init() {
        method = HttpMethod.GET
        url = ""
        headers = Headers()
        body = None
        parsedUrl = None
    }

    public init(method: HttpMethod, url: String) {
        this.method = method
        this.url = url
        this.headers = Headers()
        this.body = None
        this.parsedUrl = Some(ParsedUrl.parse(url))
    }

    /// 设置方法
    public func method(m: HttpMethod): HttpRequestBuilder {
        this.method = m
        return this
    }

    /// 设置 URL
    public func url(u: String): HttpRequestBuilder {
        this.url = u
        this.parsedUrl = Some(ParsedUrl.parse(u))
        return this
    }

    /// 设置请求头
    public func header(name: String, value: String): HttpRequestBuilder {
        headers.set(name, value)
        return this
    }

    /// 追加请求头
    public func appendHeader(name: String, value: String): HttpRequestBuilder {
        headers.append(name, value)
        return this
    }

    /// 设置请求体 (字符串)
    public func body(data: String): HttpRequestBuilder {
        this.body = Some(stringToBytes(data))
        return this
    }

    /// 设置请求体 (字节数组)
    public func bodyBytes(data: Array<UInt8>): HttpRequestBuilder {
        this.body = Some(data)
        return this
    }

    /// 设置 Content-Type
    public func contentType(ct: String): HttpRequestBuilder {
        headers.set("Content-Type", ct)
        return this
    }

    /// 设置 Authorization
    public func auth(token: String): HttpRequestBuilder {
        headers.set("Authorization", token)
        return this
    }

    /// 设置 Basic Auth
    public func basicAuth(user: String, pass: String): HttpRequestBuilder {
        // 对应 Bun AsyncHTTP.init 中的 Basic 认证编码
        let credentials = "${user}:${pass}"
        let encoded = base64Encode(stringToBytes(credentials))
        headers.set("Authorization", "Basic ${encoded}")
        return this
    }

    /// 设置 Bearer Token
    public func bearerToken(token: String): HttpRequestBuilder {
        headers.set("Authorization", "Bearer ${token}")
        return this
    }

    /// 设置超时 (毫秒)
    public func timeout(ms: Int64): HttpRequestBuilder {
        headers.set("X-Timeout", ms.toString())
        return this
    }

    /// 构建 Request 对象
    public func build(): Request {
        let req = Request(method, url, headers.clone())
        match (body) {
            case Some(b) => req.body = Some(b)
            case None => ()
        }
        return req
    }

    /// 序列化为 HTTP/1.1 请求文本
    /// 对应 Bun HeaderBuilder + HTTP 请求行构建
    public func serialize(): String {
        let sb = StringBuilder()
        let pu = match (parsedUrl) {
            case Some(u) => u
            case None => ParsedUrl.parse(url)
        }

        // 请求行: METHOD /path?query HTTP/1.1\r\n
        // 对应 picohttp 请求行格式
        sb.append(method.toString())
        sb.append(" ")
        sb.append(pu.path)
        if (pu.search.size > 0) {
            sb.append("?")
            sb.append(pu.search)
        }
        sb.append(" HTTP/1.1\r\n")

        // Host 头 (必须) - 对应 Bun 自动添加 Host
        sb.append("Host: ${pu.hostname}")
        let defaultPort = pu.protocol == "https" ? 443 : 80
        if (pu.port != defaultPort) {
            sb.append(":${pu.port}")
        }
        sb.append("\r\n")

        // User-Agent - 对应 Bun overridden_default_user_agent
        if (!headers.has("user-agent")) {
            sb.append("User-Agent: bao/${BAO_VERSION}\r\n")
        }

        // Accept
        if (!headers.has("accept")) {
            sb.append("Accept: */*\r\n")
        }

        // Accept-Encoding
        if (!headers.has("accept-encoding")) {
            sb.append("Accept-Encoding: gzip, deflate\r\n")
        }

        // Connection
        if (!headers.has("connection")) {
            sb.append("Connection: keep-alive\r\n")
        }

        // Content-Length
        match (body) {
            case Some(b) => {
                if (!headers.has("content-length")) {
                    sb.append("Content-Length: ${b.size}\r\n")
                }
            }
            case None => ()
        }

        // 用户自定义头部
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => sb.append("${key}: ${v}\r\n")
                case None => ()
            }
        }

        // 空行
        sb.append("\r\n")

        // Body
        match (body) {
            case Some(b) => sb.append(bytesToString(b))
            case None => ()
        }

        return sb.toString()
    }
}

// ============================================================================
// HttpResponseParser - HTTP 响应解析器
// 严格翻译自: src/http/http.zig 中 picohttp 响应解析
// Bun 使用 picohttp_response_parse 解析 HTTP/1.1 响应
// ============================================================================

/// HTTP 响应解析结果
public class ParsedResponse {
    /// HTTP 版本号
    public var httpVersion: String
    /// 状态码
    public var statusCode: Int64
    /// 状态文本
    public var statusText: String
    /// 响应头
    public var headers: ArrayList<HeaderPair>
    /// 响应体
    public var body: Array<UInt8>
    /// 是否 chunked 编码
    public var chunked: Bool
    /// Content-Length (-1 表示未知)
    public var contentLength: Int64

    public init() {
        httpVersion = "HTTP/1.1"
        statusCode = 200
        statusText = "OK"
        headers = ArrayList<HeaderPair>()
        body = Array<UInt8>()
        chunked = false
        contentLength = -1
    }
}

/// HTTP 响应解析器
/// 对应 picohttp_response_parse 状态机
public class HttpResponseParser {
    /// 解析原始响应数据
    public static func parse(data: Array<UInt8>): ?ParsedResponse {
        let str = bytesToString(data)
        return parseFromString(str)
    }

    /// 从字符串解析响应
    /// 对应 picohttp 响应解析: HTTP/1.x STATUS REASON\r\nHeaders\r\n\r\nBody
    public static func parseFromString(raw: String): ?ParsedResponse {
        let response = ParsedResponse()

        // 查找头部结束
        let headerEnd = raw.indexOf("\r\n\r\n")
        if (headerEnd < 0) {
            return None
        }

        let headerSection = raw.substring(0, headerEnd)
        let lines = splitLines(headerSection)

        if (lines.size == 0) {
            return None
        }

        // 解析状态行: HTTP/1.x STATUS_CODE REASON
        // 对应 picohttp 解析 phr_parse_response
        let statusLine = lines[0]
        let statusParts = split(statusLine, " ", 3)
        if (statusParts.size < 2) {
            return None
        }

        response.httpVersion = statusParts[0]
        try {
            response.statusCode = Int64.parse(statusParts[1])
        } catch (_: Exception) {
            return None
        }
        response.statusText = if (statusParts.size >= 3) { statusParts[2] } else { "" }

        // 解析头部
        for (i in 1..lines.size) {
            let line = lines[Int64(i)]
            let colonIdx = line.indexOf(":")
            if (colonIdx >= 0) {
                let name = line.substring(0, colonIdx).trim()
                let value = line.substring(colonIdx + 1).trim()
                response.headers.append(HeaderPair(name, value))

                // 检查 Transfer-Encoding: chunked
                if (name.toLower() == "transfer-encoding" && value.toLower().contains("chunked")) {
                    response.chunked = true
                }

                // 检查 Content-Length
                if (name.toLower() == "content-length") {
                    try {
                        response.contentLength = Int64.parse(value.trim())
                    } catch (_: Exception) {
                        response.contentLength = -1
                    }
                }
            }
        }

        // 解析 body
        let bodyStart = headerEnd + 4
        if (bodyStart < raw.size) {
            if (response.chunked) {
                response.body = decodeChunkedBody(raw.substring(bodyStart))
            } else {
                let bodyStr = raw.substring(bodyStart)
                response.body = stringToBytes(bodyStr)
            }
        }

        return Some(response)
    }
}

// ============================================================================
// ConnectionPool - TCP 连接池
// 严格翻译自: src/http/HTTPContext.zig PooledSocket 池
// Bun: HTTPContext 维护 pool_size=64 的 keep-alive socket 池
//   PooledSocket { http_socket, hostname_buf, port, ... }
// ============================================================================

/// 连接池条目 - 对应 Bun PooledSocket
class PooledConnection {
    var fd: Int64
    var hostname: String
    var port: Int64
    var lastUsed: Int64
    var active: Bool

    init(fd: Int64, hostname: String, port: Int64) {
        this.fd = fd
        this.hostname = hostname
        this.port = port
        this.lastUsed = currentTimeMillis()
        this.active = true
    }
}

/// TCP 连接池 - 对应 Bun HTTPContext 中的连接池
/// Bun: pool_size = 64, 空闲超时 5 分钟
public class ConnectionPool {
    /// 最大池大小 - 对应 Bun pool_size = 64
    private let maxPoolSize: Int64
    /// 空闲连接超时 (毫秒) - 对应 Bun idle_timeout_seconds * 1000
    private let idleTimeout: Int64
    /// 连接池 - hostname:port -> 连接列表
    private var pool: HashMap<String, ArrayList<PooledConnection>>
    /// 互斥锁
    private var mutex: Mutex

    public init() {
        maxPoolSize = 64
        idleTimeout = 300000  // 5 分钟
        pool = HashMap<String, ArrayList<PooledConnection>>()
        mutex = Mutex()
    }

    public init(maxPoolSize: Int64, idleTimeout: Int64) {
        this.maxPoolSize = maxPoolSize
        this.idleTimeout = idleTimeout
        pool = HashMap<String, ArrayList<PooledConnection>>()
        mutex = Mutex()
    }

    /// 获取连接 - 对应 Bun 从池中取 PooledSocket
    public func getConnection(hostname: String, port: Int64): ?Int64 {
        mutex.lock()
        let key = "${hostname}:${port}"
        match (pool.get(key)) {
            case Some(connections) => {
                // 查找活跃连接
                var i = connections.size - 1
                while (i >= 0) {
                    let conn = connections[Int64(i)]
                    if (conn.active) {
                        let now = currentTimeMillis()
                        if (now - conn.lastUsed > idleTimeout) {
                            // 连接空闲超时，关闭并移除
                            SysFs.close(conn.fd)
                            conn.active = false
                            connections.removeAt(Int64(i))
                        } else {
                            conn.active = false
                            connections.removeAt(Int64(i))
                            mutex.unlock()
                            return Some(conn.fd)
                        }
                    }
                    i -= 1
                }
            }
            case None => ()
        }
        mutex.unlock()
        return None
    }

    /// 归还连接到池中 - 对应 Bun 将 socket 放回 PooledSocket 池
    public func returnConnection(hostname: String, port: Int64, fd: Int64): Unit {
        mutex.lock()
        let key = "${hostname}:${port}"

        match (pool.get(key)) {
            case Some(connections) => {
                if (connections.size < maxPoolSize) {
                    connections.append(PooledConnection(fd, hostname, port))
                } else {
                    // 池满，关闭连接
                    SysFs.close(fd)
                }
            }
            case None => {
                let connections = ArrayList<PooledConnection>()
                connections.append(PooledConnection(fd, hostname, port))
                pool.put(key, connections)
            }
        }
        mutex.unlock()
    }

    /// 清理空闲连接
    public func cleanup(): Unit {
        mutex.lock()
        let now = currentTimeMillis()
        for (key in pool.keys()) {
            match (pool.get(key)) {
                case Some(connections) => {
                    var i = connections.size - 1
                    while (i >= 0) {
                        let conn = connections[Int64(i)]
                        if (now - conn.lastUsed > idleTimeout) {
                            SysFs.close(conn.fd)
                            conn.active = false
                            connections.removeAt(Int64(i))
                        }
                        i -= 1
                    }
                }
                case None => ()
            }
        }
        mutex.unlock()
    }

    /// 关闭所有连接
    public func closeAll(): Unit {
        mutex.lock()
        for (key in pool.keys()) {
            match (pool.get(key)) {
                case Some(connections) => {
                    for (conn in connections) {
                        if (conn.active) {
                            SysFs.close(conn.fd)
                            conn.active = false
                        }
                    }
                }
                case None => ()
            }
        }
        pool = HashMap<String, ArrayList<PooledConnection>>()
        mutex.unlock()
    }
}

// ============================================================================
// HttpClient - HTTP/1.1 客户端
// 严格翻译自: src/http/AsyncHTTP.zig, src/http/http.zig HTTPClient
// Bun HTTPClient: DNS -> TCP connect -> TLS handshake -> send -> receive
// AsyncHTTP 是异步封装，HTTPClient 是核心实现
// ============================================================================

/// HTTP 客户端配置 - 对应 Bun AsyncHTTP.Options
public class HttpClientConfig {
    /// 请求超时 (毫秒)
    public var timeout: Int64
    /// 连接超时 (毫秒)
    public var connectTimeout: Int64
    /// 最大重定向次数
    public var maxRedirects: Int64
    /// 是否禁用 keep-alive
    public var disableKeepalive: Bool
    /// 是否禁用压缩
    public var disableDecompression: Bool
    /// 是否验证 SSL 证书
    public var rejectUnauthorized: Bool
    /// HTTP 代理 URL
    public var proxyUrl: ?String
    /// 用户代理
    public var userAgent: String

    public init() {
        timeout = 30000          // 30 秒
        connectTimeout = 10000   // 10 秒
        maxRedirects = 10
        disableKeepalive = false
        disableDecompression = false
        rejectUnauthorized = true
        proxyUrl = None
        userAgent = "bao/${BAO_VERSION}"
    }
}

/// HTTP 客户端 - 对应 Bun AsyncHTTP + HTTPClient
/// 支持 DNS 解析、TCP 连接、请求发送、响应解析
/// 支持 keep-alive 连接池、重定向跟随、超时处理
public class HttpClient2 {
    /// 连接池 - 对应 Bun HTTPContext.PooledSocket
    private var pool: ConnectionPool
    /// 配置
    private var config: HttpClientConfig
    /// 状态
    private var state: HttpClientState

    public init() {
        pool = ConnectionPool()
        config = HttpClientConfig()
        state = HttpClientState.Pending
    }

    public init(config: HttpClientConfig) {
        pool = ConnectionPool()
        this.config = config
        state = HttpClientState.Pending
    }

    /// 获取连接池
    public func getPool(): ConnectionPool {
        return pool
    }

    // ========================================================================
    // DNS 解析 + TCP 连接
    // 严格翻译自: src/http/http.zig 中 DNS 解析和 connect 调用
    // Bun 通过 c-ares 做异步 DNS 解析，通过 uws socket 连接
    // ========================================================================

    /// DNS 解析 - 对应 Bun c-ares DNS 解析
    /// 返回 IP 地址列表
    public static func resolveHostname(hostname: String, port: Int64): ?ArrayList<String> {
        let addresses = ArrayList<String>()

        unsafe {
            // 使用 getaddrinfo 进行 DNS 解析
            // 对应 Bun 通过 c-ares 或 getaddrinfo 解析
            var hints = AddrInfo()
            hints.family = AF_INET()
            hints.socktype = SOCK_STREAM()
            hints.protocol = IPPROTO_TCP()

            let portStr = port.toString()
            let hostnamePtr = unsafeNewCString(hostname)
            let portPtr = unsafeNewCString(portStr)
            var result: CPointer<Unit> = CPointer<Unit>()

            let rc = getaddrinfo(hostnamePtr, portPtr, hints.ptr(), &result)
            if (rc != 0) {
                return None
            }

            // 遍历结果
            var addr = result
            while (!addr.isNull()) {
                let ai = AddrInfo.fromPtr(addr)
                if (ai.family == AF_INET()) {
                    // 提取 IPv4 地址
                    let ipStr = extractIpFromSockaddr(addr)
                    if (ipStr.size > 0) {
                        addresses.append(ipStr)
                    }
                }
                let next = ai.next
                if (next.isNull()) {
                    break
                }
                addr = next
            }

            freeaddrinfo(result)
        }

        if (addresses.size == 0) {
            return None
        }
        return Some(addresses)
    }

    /// TCP 连接 - 对应 Bun HTTPClient 连接流程
    public func connect(hostname: String, port: Int64): ?Int64 {
        // 先尝试从连接池获取
        if (!config.disableKeepalive) {
            let pooled = pool.getConnection(hostname, port)
            match (pooled) {
                case Some(fd) => return Some(fd)
                case None => ()
            }
        }

        // DNS 解析
        let addresses = resolveHostname(hostname, port)
        match (addresses) {
            case Some(addrs) => {
                // 尝试每个地址连接
                for (addr in addrs) {
                    let fd = tcpConnect(addr, port)
                    match (fd) {
                        case Some(f) => return Some(f)
                        case None => ()
                    }
                }
            }
            case None => ()
        }
        return None
    }

    /// TCP socket 连接 - 对应 POSIX connect()
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

    // ========================================================================
    // 发送请求 + 读取响应
    // 严格翻译自: src/http/AsyncHTTP.zig onStart, onAsyncHTTPCallback
    // 以及 src/http/http.zig HTTPClient.start
    // ========================================================================

    /// 发送 HTTP 请求
    /// 对应 Bun AsyncHTTP.onStart -> HTTPClient.start
    public func send(request: HttpRequestBuilder): ?Response {
        state = HttpClientState.Sending

        let pu = match (request.parsedUrl) {
            case Some(u) => u
            case None => ParsedUrl.parse(request.url)
        }

        // 建立连接
        let port = if (pu.port > 0) { pu.port } else {
            if (pu.protocol == "https") { 443 } else { 80 }
        }
        let fd = connect(pu.hostname, port)
        match (fd) {
            case Some(sockfd) => {
                // 发送原始请求
                let rawData = stringToBytes(request.serialize())
                let writeResult = SysFs.write(sockfd, rawData)
                match (writeResult) {
                    case Ok(_) => {
                        // 读取响应
                        let response = readResponse(sockfd)

                        // 归还连接到池中
                        if (!config.disableKeepalive) {
                            pool.returnConnection(pu.hostname, port, sockfd)
                        } else {
                            SysFs.close(sockfd)
                        }

                        state = HttpClientState.Success
                        return response
                    }
                    case Err(_) => {
                        SysFs.close(sockfd)
                        state = HttpClientState.Fail
                        return None
                    }
                }
            }
            case None => {
                state = HttpClientState.Fail
                return None
            }
        }
    }

    /// 读取 HTTP 响应
    /// 对应 Bun HTTPClient 响应读取 + picohttp_response_parse
    private static func readResponse(fd: Int64): ?Response {
        var allData = Array<UInt8>()
        let buf = Array<UInt8>(8192, item: UInt8(0))
        var headerComplete = false

        // 读取直到头部完整
        while (!headerComplete) {
            let result = SysFs.read(fd, buf)
            match (result) {
                case Ok(n) => {
                    if (n == 0) {
                        break
                    }
                    for (i in 0..n) {
                        allData.append(buf[Int64(i)])
                    }
                    headerComplete = containsHeaderEnd(allData)
                }
                case Err(_) => break
            }
        }

        if (allData.size == 0) {
            return None
        }

        // 解析响应
        let parsed = HttpResponseParser.parse(allData)
        match (parsed) {
            case Some(pr) => {
                let response = Response(pr.statusCode)
                response.statusText = pr.statusText
                for (h in pr.headers) {
                    response.headers.set(h.name, h.value)
                }
                if (pr.body.size > 0) {
                    response.body = Some(pr.body)
                }
                return response
            }
            case None => None
        }
    }

    // ========================================================================
    // 重定向跟随
    // 严格翻译自: src/http/http.zig HTTPClient 中重定向处理
    // Bun: FetchRedirect { manual, follow, error }
    // ============================================================================

    /// 发送请求并跟随重定向
    /// 对应 Bun AsyncHTTP 中 redirect_type = .follow
    public func sendWithRedirects(request: HttpRequestBuilder): ?Response {
        var currentRequest = request
        var redirectCount: Int64 = 0

        while (redirectCount < config.maxRedirects) {
            let response = send(currentRequest)
            match (response) {
                case Some(resp) => {
                    // 检查是否为重定向 (301, 302, 307, 308)
                    if (resp.status >= 300 && resp.status < 400) {
                        let location = resp.headers.get("location")
                        match (location) {
                            case Some(loc) => {
                                redirectCount += 1
                                resp.redirected = true

                                // 构建新请求
                                let redirectUrl = resolveRedirectUrl(currentRequest.url, loc)
                                let method = if (resp.status == 301 || resp.status == 302 || resp.status == 303) {
                                    HttpMethod.GET  // 301/302/303 将方法改为 GET
                                } else {
                                    currentRequest.method
                                }

                                currentRequest = HttpRequestBuilder(method, redirectUrl)

                                // 保留部分头部
                                let contentType = request.build().headers.get("content-type")
                                match (contentType) {
                                    case Some(ct) => currentRequest.contentType(ct)
                                    case None => ()
                                }

                                // 继续跟随重定向
                            }
                            case None => return Some(resp)  // 无 Location 头，停止
                        }
                    } else {
                        return Some(resp)  // 非重定向响应
                    }
                }
                case None => return None  // 请求失败
            }
        }

        // 超过最大重定向次数
        return None
    }

    /// 解析重定向 URL
    /// 将相对 URL 解析为绝对 URL
    private static func resolveRedirectUrl(baseUrl: String, location: String): String {
        // 如果已经是绝对 URL
        if (location.startsWith("http://") || location.startsWith("https://")) {
            return location
        }

        // 相对路径解析
        let base = ParsedUrl.parse(baseUrl)
        if (location.startsWith("/")) {
            return "${base.protocol}://${base.hostname}:${base.port}${location}"
        }
        return "${base.protocol}://${base.hostname}:${base.port}${base.path}/${location}"
    }

    /// 获取状态
    public func getState(): HttpClientState {
        return state
    }
}

// ============================================================================
// AddrInfo - addrinfo 结构封装
// 严格翻译自: POSIX struct addrinfo
// ============================================================================

/// DNS 解析提示 - 对应 POSIX struct addrinfo
class AddrInfo {
    var family: Int32       // ai_family
    var socktype: Int32     // ai_socktype
    var protocol: Int32     // ai_protocol
    var addrlen: UInt32     // ai_addrlen
    var next: CPointer<Unit> // ai_next

    init() {
        family = 0
        socktype = 0
        protocol = 0
        addrlen = 0
        next = CPointer<Unit>()
    }

    /// 获取 hints 指针
    func ptr(): CPointer<Unit> {
        unsafe {
            let ptr = malloc(UIntNative(48))  // sizeof(struct addrinfo) ~ 48
            let bytes = CPointer<Int32>(ptr)
            (bytes + IntNative(0)).write(family)      // ai_family
            (bytes + IntNative(1)).write(socktype)     // ai_socktype
            (bytes + IntNative(2)).write(protocol)     // ai_protocol
            (bytes + IntNative(3)).write(0)            // ai_flags
            return ptr
        }
    }

    /// 从指针读取 AddrInfo
    static func fromPtr(ptr: CPointer<Unit>): AddrInfo {
        let ai = AddrInfo()
        unsafe {
            let bytes = CPointer<Int32>(ptr)
            ai.family = (bytes + IntNative(0)).read()
            ai.socktype = (bytes + IntNative(1)).read()
            ai.protocol = (bytes + IntNative(2)).read()
            // ai_addrlen at offset 4 * 4 = 16 (asUInt32)
            let addrBytes = CPointer<UInt32>(ptr)
            ai.addrlen = (addrBytes + IntNative(4)).read()
            // ai_addr at offset 5 * 4 = 20
            // ai_canonname at offset 6 * 4 = 24 (pointer)
            // ai_next at offset 7 * 4 = 28 (pointer)
            // 读取 ai_next 指针 (偏移取决于平台，简化处理)
            let nextBytes = CPointer<CPointer<Unit>>(ptr)
            ai.next = (nextBytes + IntNative(7)).read()
        }
        return ai
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从 sockaddr 提取 IP 地址字符串
private func extractIpFromSockaddr(addrPtr: CPointer<Unit>): String {
    unsafe {
        let bytes = CPointer<UInt8>(addrPtr)
        // sockaddr_in 中 IP 地址在偏移 4 处 (4 字节)
        let b0 = Int32((bytes + IntNative(4)).read())
        let b1 = Int32((bytes + IntNative(5)).read())
        let b2 = Int32((bytes + IntNative(6)).read())
        let b3 = Int32((bytes + IntNative(7)).read())
        return "${b0}.${b1}.${b2}.${b3}"
    }
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

/// 按分隔符分割 (带最大分割数)
private func split(s: String, sep: String, maxParts: Int64): ArrayList<String> {
    let parts = ArrayList<String>()
    var remaining = s
    while (parts.size < maxParts - 1) {
        let idx = remaining.indexOf(sep)
        if (idx < 0) {
            parts.append(remaining)
            return parts
        }
        parts.append(remaining.substring(0, idx))
        remaining = remaining.substring(idx + sep.size)
    }
    parts.append(remaining)
    return parts
}

/// 按分隔符分割
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

/// 检查是否包含头部结束标记
private func containsHeaderEnd(data: Array<UInt8>): Bool {
    return findHeaderEnd(data) >= 0
}

/// Base64 编码 - 对应 Bun Basic Auth 编码
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

/// 解码 chunked 传输编码的 body
/// HTTP/1.1 chunked: <hex-size>\r\n<data>\r\n...0\r\n\r\n
private func decodeChunkedBody(chunkedData: String): Array<UInt8> {
    let result = Array<UInt8>()
    var pos = 0

    while (pos < chunkedData.size) {
        // 读取 chunk 大小 (hex)
        let lineEnd = chunkedData.indexOfFrom("\r\n", pos)
        if (lineEnd < 0) {
            break
        }

        let sizeStr = chunkedData.substring(pos, lineEnd).trim()
        // 跳过分块扩展 (分号后的部分)
        let semiIdx = sizeStr.indexOf(";")
        let hexStr = if (semiIdx >= 0) { sizeStr.substring(0, semiIdx).trim() } else { sizeStr }

        let chunkSize = hexToInt(hexStr)
        if (chunkSize == 0) {
            break  // 终止块
        }

        // 读取 chunk 数据
        let dataStart = lineEnd + 2
        let dataEnd = dataStart + chunkSize
        if (dataEnd > chunkedData.size) {
            break
        }

        for (i in dataStart..dataEnd) {
            result.append(UInt8(Int32(chunkedData[Int64(i)].value) & 0xFF))
        }

        pos = dataEnd + 2  // 跳过 \r\n
    }

    return result
}

/// 十六进制字符串转整数
private func hexToInt(hex: String): Int64 {
    var result: Int64 = 0
    for (c in hex) {
        result = result * 16
        let v = Int64(c.value)
        if (c >= '0' && c <= '9') {
            result += v - 48
        } else if (c >= 'a' && c <= 'f') {
            result += v - 87
        } else if (c >= 'A' && c <= 'F') {
            result += v - 55
        }
    }
    return result
}

/// 获取当前时间戳 (毫秒)
private func currentTimeMillis(): Int64 {
    unsafe {
        var ts = Array<Int64>(2, item: 0)
        clock_gettime(0, ts.toArray().unsafePtr())  // CLOCK_REALTIME = 0
        return ts[0] * 1000 + ts[1] / 1000000
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

/// C 字符串工具
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

/// indexOf 从指定位置开始
private func indexOfFrom(s: String, target: String, fromIndex: Int64): Int64 {
    let sub = s.substring(fromIndex)
    let idx = sub.indexOf(target)
    if (idx < 0) {
        return -1
    }
    return fromIndex + idx
}

// C FFI: clock_gettime
@C
foreign func clock_gettime(clockid: Int32, tp: CPointer<Int64>): Int32
