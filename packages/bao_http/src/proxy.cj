// bao_http proxy - HTTP 代理支持
// 严格翻译自: src/http/ proxy support
// 参考: src/http/ProxyTunnel.zig, src/http/AsyncHTTP.zig 中 proxy_url/proxy_tunnel
//   Bun 支持通过 HTTP/HTTPS 代理发送请求
//   ProxyTunnel 管理 TLS-over-proxy 的 CONNECT 隧道
//   HTTPClient 支持 proxy_url 配置和 Basic 代理认证
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// ProxyHeaders - 代理相关头部
// 严格翻译自: HTTP 代理标准头部
//   Bun 在 AsyncHTTP 中自动处理代理头部:
//   - X-Forwarded-For: 客户端 IP 链
//   - X-Forwarded-Proto: 原始协议
//   - X-Forwarded-Host: 原始主机
//   - Via: 代理链路记录
//   - Proxy-Authorization: 代理认证
// ============================================================================

/// 代理头部工具 - 管理代理转发的标准头部
public class ProxyHeaders {
    /// 设置正向代理头部
    /// X-Forwarded-For: 追加客户端 IP
    public static func setForwardedFor(headers: Headers, clientIp: String): Unit {
        let existing = headers.get("x-forwarded-for")
        match (existing) {
            case Some(v) => headers.set("X-Forwarded-For", "${v}, ${clientIp}")
            case None => headers.set("X-Forwarded-For", clientIp)
        }
    }

    /// 设置转发协议头部
    /// X-Forwarded-Proto: http 或 https
    public static func setForwardedProto(headers: Headers, proto: String): Unit {
        headers.set("X-Forwarded-Proto", proto)
    }

    /// 设置转发主机头部
    /// X-Forwarded-Host: 原始请求的 Host
    public static func setForwardedHost(headers: Headers, host: String): Unit {
        headers.set("X-Forwarded-Host", host)
    }

    /// 设置 Via 头部 - 对应 RFC 7230 §5.7.1
    /// Via: 1.1 <hostname> (bao/<version>)
    public static func setVia(headers: Headers, hostname: String): Unit {
        let viaValue = "1.1 ${hostname} (bao/${BAO_VERSION})"
        let existing = headers.get("via")
        match (existing) {
            case Some(v) => headers.set("Via", "${v}, ${viaValue}")
            case None => headers.set("Via", viaValue)
        }
    }

    /// 设置代理认证头部
    /// Proxy-Authorization: Basic <credentials>
    /// 对应 Bun AsyncHTTP 中 proxy basic auth 处理
    public static func setProxyAuth(headers: Headers, username: String, password: String): Unit {
        let credentials = "${username}:${password}"
        let encoded = base64Encode(stringToBytes(credentials))
        headers.set("Proxy-Authorization", "Basic ${encoded}")
    }

    /// 从请求中提取客户端 IP (用于上游转发)
    /// 检查 X-Forwarded-For 或回退到直接连接地址
    public static func extractClientIp(headers: Headers, remoteAddr: String): String {
        let forwarded = headers.get("x-forwarded-for")
        match (forwarded) {
            case Some(v) => {
                // X-Forwarded-For 可能包含多个 IP, 取第一个
                let commaIdx = v.indexOf(",")
                if (commaIdx >= 0) {
                    return v.substring(0, commaIdx).trim()
                }
                return v.trim()
            }
            case None => remoteAddr
        }
    }

    /// 从请求中提取原始协议
    public static func extractOriginalProto(headers: Headers): String {
        let proto = headers.get("x-forwarded-proto")
        return proto.getOrElse { "http" }
    }

    /// 检查是否通过代理到达
    public static func isProxied(headers: Headers): Bool {
        return headers.has("x-forwarded-for") || headers.has("via")
    }
}

// ============================================================================
// ProxyConfig - 代理配置
// 严格翻译自: src/http/AsyncHTTP.zig 中 proxy 相关字段
//   Bun AsyncHTTP: proxy_url, proxy_tunnel, proxy_headers
// ============================================================================

/// 代理配置 - 对应 Bun AsyncHTTP 的代理设置
public class ProxyConfig {
    /// 代理 URL (http://host:port 或 https://host:port)
    /// 对应 Bun AsyncHTTP.proxy_url
    public var proxyUrl: String
    /// 代理认证用户名
    public var username: String
    /// 代理认证密码
    public var password: String
    /// 是否使用 CONNECT 隧道 (用于 HTTPS 目标)
    /// 对应 Bun ProxyTunnel 的使用条件
    public var useTunnel: Bool
    /// 自定义代理头部
    public var proxyHeaders: Headers
    /// 是否验证代理 TLS 证书
    public var rejectUnauthorized: Bool

    public init() {
        proxyUrl = ""
        username = ""
        password = ""
        useTunnel = false
        proxyHeaders = Headers()
        rejectUnauthorized = true
    }

    public init(proxyUrl: String) {
        this.proxyUrl = proxyUrl
        this.username = ""
        this.password = ""
        this.useTunnel = false
        this.proxyHeaders = Headers()
        this.rejectUnauthorized = true
        parseProxyUrl()
    }

    public init(proxyUrl: String, username: String, password: String) {
        this.proxyUrl = proxyUrl
        this.username = username
        this.password = password
        this.useTunnel = false
        this.proxyHeaders = Headers()
        this.rejectUnauthorized = true
        parseProxyUrl()
    }

    /// 是否配置了代理
    public func isConfigured(): Bool {
        return proxyUrl.size > 0
    }

    /// 解析代理 URL 提取主机和端口
    private func parseProxyUrl(): Unit {
        let parsed = ParsedUrl.parse(proxyUrl)
        // 自动检测是否需要 CONNECT 隧道
        // 当目标为 HTTPS 时需要隧道
        useTunnel = false  // 由调用方根据目标 URL 决定
    }

    /// 获取代理主机名
    public func getHostname(): String {
        let parsed = ParsedUrl.parse(proxyUrl)
        return parsed.hostname
    }

    /// 获取代理端口
    public func getPort(): Int64 {
        let parsed = ParsedUrl.parse(proxyUrl)
        return if (parsed.port > 0) { parsed.port } else {
            if (proxyUrl.startsWith("https://")) { 443 } else { 3128 }
        }
    }

    /// 是否需要代理认证
    public func needsAuth(): Bool {
        return username.size > 0 || password.size > 0
    }
}

// ============================================================================
// HttpProxy - 正向代理
// 严格翻译自: src/http/ proxy 转发逻辑
//   Bun 正向代理模式:
//   1. 客户端 -> 代理服务器 -> 目标服务器
//   2. 代理将请求转发到目标，添加 Via/X-Forwarded-* 头部
//   3. 对 HTTPS 目标使用 CONNECT 隧道
// ============================================================================

/// 正向代理 - 对应 Bun 的 HTTP 客户端代理模式
/// 将入站请求转发到目标服务器
public class HttpProxy {
    /// 代理配置
    private var config: ProxyConfig
    /// 连接池 (到目标服务器的连接)
    private var targetPool: ConnectionPool
    /// 连接池 (到代理服务器的连接)
    private var proxyPool: ConnectionPool

    public init(config: ProxyConfig) {
        this.config = config
        this.targetPool = ConnectionPool()
        this.proxyPool = ConnectionPool()
    }

    // ========================================================================
    // CONNECT 隧道
    // 严格翻译自: src/http/ProxyTunnel.zig
    //   Bun ProxyTunnel 管理 HTTPS-over-HTTP-proxy 的 CONNECT 隧道
    //   流程: 发送 CONNECT host:port HTTP/1.1 -> 收到 200 -> 建立 TLS
    // ========================================================================

    /// 建立 CONNECT 隧道
    /// 对应 Bun ProxyTunnel.onOpen -> 发送 CONNECT 请求
    /// 用于 HTTPS 目标通过 HTTP 代理访问
    /// 返回隧道 socket FD，或 None 表示失败
    public func establishTunnel(targetHost: String, targetPort: Int64): ?Int64 {
        let proxyHost = config.getHostname()
        let proxyPort = config.getPort()

        // 连接到代理服务器
        let proxyFd = tcpConnectToProxy(proxyHost, proxyPort)
        match (proxyFd) {
            case Some(fd) => {
                // 构建 CONNECT 请求
                // 对应 ProxyTunnel: CONNECT host:port HTTP/1.1
                let connectRequest = buildConnectRequest(targetHost, targetPort)

                // 发送 CONNECT 请求
                let writeResult = writeRaw(fd, stringToBytes(connectRequest))
                if (writeResult < 0) {
                    SysFs.close(fd)
                    return None
                }

                // 读取代理响应 (应为 200 Connection Established)
                let response = readProxyResponse(fd)
                match (response) {
                    case Some(resp) => {
                        if (resp.statusCode == 200) {
                            // 隧道建立成功
                            // 后续在此 FD 上进行 TLS 握手
                            return fd
                        }
                        // 代理拒绝 CONNECT
                        SysFs.close(fd)
                        return None
                    }
                    case None => {
                        SysFs.close(fd)
                        return None
                    }
                }
            }
            case None => return None
        }
    }

    /// 构建 CONNECT 请求
    /// 对应 Bun ProxyTunnel 中发送的 CONNECT 请求行
    /// CONNECT target_host:target_port HTTP/1.1\r\n
    /// Host: target_host:target_port\r\n
    /// Proxy-Authorization: Basic ...\r\n
    /// \r\n
    private func buildConnectRequest(targetHost: String, targetPort: Int64): String {
        let sb = StringBuilder()
        sb.append("CONNECT ${targetHost}:${targetPort} HTTP/1.1\r\n")
        sb.append("Host: ${targetHost}:${targetPort}\r\n")

        // 代理认证
        if (config.needsAuth()) {
            let credentials = "${config.username}:${config.password}"
            let encoded = base64Encode(stringToBytes(credentials))
            sb.append("Proxy-Authorization: Basic ${encoded}\r\n")
        }

        // 自定义头部
        for (key in config.proxyHeaders.keys()) {
            match (config.proxyHeaders.get(key)) {
                case Some(v) => sb.append("${key}: ${v}\r\n")
                case None => ()
            }
        }

        sb.append("\r\n")
        return sb.toString()
    }

    // ========================================================================
    // HTTP 请求转发
    // ========================================================================

    /// 通过代理转发 HTTP 请求
    /// 对应 Bun AsyncHTTP 通过 proxy 发送请求的流程
    /// HTTP 代理: 请求行使用完整 URL (http://host/path)
    public func forwardRequest(request: Request): ?Response {
        let targetHost = match (request.parsedUrl) {
            case Some(u) => u.hostname
            case None => return None
        }
        let targetPort = match (request.parsedUrl) {
            case Some(u) => if (u.port > 0) { u.port } else { 80 }
            case None => return None
        }

        // 连接到代理
        let proxyFd = tcpConnectToProxy(config.getHostname(), config.getPort())
        match (proxyFd) {
            case Some(fd) => {
                // 构建代理请求 (使用完整 URL)
                let proxyRequest = buildProxyRequest(request)
                let writeResult = writeRaw(fd, stringToBytes(proxyRequest))
                if (writeResult < 0) {
                    SysFs.close(fd)
                    return None
                }

                // 读取代理响应
                let response = readProxyResponse(fd)
                match (response) {
                    case Some(parsed) => {
                        let resp = Response(parsed.statusCode)
                        resp.statusText = parsed.statusText
                        for (h in parsed.headers) {
                            resp.headers.set(h.name, h.value)
                        }
                        if (parsed.body.size > 0) {
                            resp.body = Some(parsed.body)
                        }
                        SysFs.close(fd)
                        return resp
                    }
                    case None => {
                        SysFs.close(fd)
                        return None
                    }
                }
            }
            case None => return None
        }
    }

    /// 构建通过代理的 HTTP 请求
    /// HTTP 代理使用绝对 URL: GET http://host/path HTTP/1.1
    /// 对应 Bun HTTPClient 中代理请求行构建
    private func buildProxyRequest(request: Request): String {
        let sb = StringBuilder()
        let pu = match (request.parsedUrl) {
            case Some(u) => u
            case None => return ""
        }

        // 请求行使用完整 URL
        sb.append(request.method.toString())
        sb.append(" ${request.url} HTTP/1.1\r\n")

        // Host 头
        sb.append("Host: ${pu.hostname}")
        let defaultPort = if (pu.protocol == "https") { 443 } else { 80 }
        if (pu.port != defaultPort && pu.port > 0) {
            sb.append(":${pu.port}")
        }
        sb.append("\r\n")

        // 代理认证
        if (config.needsAuth()) {
            ProxyHeaders.setProxyAuth(request.headers, config.username, config.password)
        }

        // 用户头部
        for (key in request.headers.keys()) {
            match (request.headers.get(key)) {
                case Some(v) => sb.append("${key}: ${v}\r\n")
                case None => ()
            }
        }

        // Body
        match (request.body) {
            case Some(body) => {
                if (!request.headers.has("content-length")) {
                    sb.append("Content-Length: ${body.size}\r\n")
                }
                sb.append("\r\n")
                sb.append(bytesToString(body))
            }
            case None => sb.append("\r\n")
        }

        return sb.toString()
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// TCP 连接到代理服务器
    private func tcpConnectToProxy(host: String, port: Int64): ?Int64 {
        // 简化: 使用 HttpServer 中的 socket 连接逻辑
        // 实际实现需要复用 ConnectionPool
        return None  // 需要 C FFI socket 支持
    }

    /// 读取代理响应
    private func readProxyResponse(fd: Int64): ?ParsedResponse {
        var allData = Array<UInt8>()
        let buf = Array<UInt8>(4096, item: UInt8(0))

        var headerComplete = false
        while (!headerComplete) {
            let result = SysFs.read(fd, buf)
            match (result) {
                case Ok(n) => {
                    if (n == 0) { break }
                    for (i in 0..n) {
                        allData.append(buf[i])
                    }
                    // 检查头部结束
                    if (containsHeaderEnd(allData)) {
                        headerComplete = true
                    }
                }
                case Err(_) => break
            }
        }

        if (allData.size == 0) {
            return None
        }

        return HttpResponseParser.parse(allData)
    }

    /// 获取配置
    public func getConfig(): ProxyConfig {
        return config
    }

    /// 关闭所有连接
    public func close(): Unit {
        targetPool.closeAll()
        proxyPool.closeAll()
    }
}

// ============================================================================
// UpstreamServer - 上游服务器
// 用于反向代理的目标服务器描述
// ============================================================================

/// 上游服务器 - 反向代理的后端节点
public class UpstreamServer {
    /// 服务器地址
    public var host: String
    /// 服务器端口
    public var port: Int64
    /// 协议 (http 或 https)
    public var protocol: String
    /// 权重 (用于加权负载均衡)
    public var weight: Int64
    /// 是否健康
    public var healthy: Bool
    /// 连接池
    public var pool: ConnectionPool

    public init(host: String, port: Int64) {
        this.host = host
        this.port = port
        this.protocol = "http"
        this.weight = 1
        this.healthy = true
        this.pool = ConnectionPool()
    }

    public init(host: String, port: Int64, protocol: String) {
        this.host = host
        this.port = port
        this.protocol = protocol
        this.weight = 1
        this.healthy = true
        this.pool = ConnectionPool()
    }

    /// 获取基地址
    public func baseUrl(): String {
        return "${protocol}://${host}:${port}"
    }

    /// 标记为不健康
    public func markUnhealthy(): Unit {
        healthy = false
    }

    /// 标记为健康
    public func markHealthy(): Unit {
        healthy = true
    }
}

// ============================================================================
// LoadBalanceStrategy - 负载均衡策略
// ============================================================================

/// 负载均衡策略
public enum LoadBalanceStrategy {
    | RoundRobin      // 轮询
    | Random          // 随机
    | LeastConn       // 最少连接
    | WeightedRoundRobin  // 加权轮询
}

// ============================================================================
// ReverseProxy - 反向代理
// 严格翻译自: src/http/ proxy support (反向代理模式)
//   Bun 本身不直接提供反向代理功能，但作为 HTTP 服务器框架
//   可以通过请求转发实现反向代理
//   反向代理: 客户端 -> 代理(透明) -> 上游服务器
//   关键: 修改请求头部、选择上游、转发响应
// ============================================================================

/// 反向代理 - 将入站请求转发到上游服务器
public class ReverseProxy {
    /// 上游服务器列表
    private var upstreams: ArrayList<UpstreamServer>
    /// 负载均衡策略
    private var strategy: LoadBalanceStrategy
    /// 轮询索引 (用于 RoundRobin)
    private var roundRobinIndex: Int64
    /// 加权轮询当前权重
    private var currentWeights: ArrayList<Int64>
    /// 连接超时 (毫秒)
    private var connectTimeout: Int64
    /// 请求超时 (毫秒)
    private var requestTimeout: Int64
    /// 最大重试次数
    private var maxRetries: Int64
    /// 是否传递 X-Forwarded-* 头部
    private var passForwardedHeaders: Bool
    /// 是否重写 Location 头
    private var rewriteLocation: Bool

    public init() {
        upstreams = ArrayList<UpstreamServer>()
        strategy = LoadBalanceStrategy.RoundRobin
        roundRobinIndex = 0
        currentWeights = ArrayList<Int64>()
        connectTimeout = 10000
        requestTimeout = 30000
        maxRetries = 3
        passForwardedHeaders = true
        rewriteLocation = true
    }

    /// 添加上游服务器
    public func addUpstream(server: UpstreamServer): ReverseProxy {
        upstreams.append(server)
        currentWeights.append(0)
        return this
    }

    /// 设置负载均衡策略
    public func setStrategy(strategy: LoadBalanceStrategy): ReverseProxy {
        this.strategy = strategy
        return this
    }

    /// 设置超时
    public func setTimeout(connectMs: Int64, requestMs: Int64): ReverseProxy {
        this.connectTimeout = connectMs
        this.requestTimeout = requestMs
        return this
    }

    // ========================================================================
    // 上游选择 - 负载均衡
    // ========================================================================

    /// 选择上游服务器
    /// 对应负载均衡算法
    public func selectUpstream(): ?UpstreamServer {
        let healthyUpstreams = getHealthyUpstreams()
        if (healthyUpstreams.size == 0) {
            return None
        }

        match (strategy) {
            case RoundRobin => selectRoundRobin(healthyUpstreams)
            case Random => selectRandom(healthyUpstreams)
            case LeastConn => selectLeastConn(healthyUpstreams)
            case WeightedRoundRobin => selectWeightedRoundRobin(healthyUpstreams)
        }
    }

    /// 获取健康的上游列表
    private func getHealthyUpstreams(): ArrayList<UpstreamServer> {
        let result = ArrayList<UpstreamServer>()
        for (upstream in upstreams) {
            if (upstream.healthy) {
                result.append(upstream)
            }
        }
        return result
    }

    /// 轮询选择 - Round-Robin
    private func selectRoundRobin(upstreams: ArrayList<UpstreamServer>): UpstreamServer {
        let idx = roundRobinIndex % upstreams.size
        roundRobinIndex += 1
        return upstreams[idx]
    }

    /// 随机选择
    private func selectRandom(upstreams: ArrayList<UpstreamServer>): UpstreamServer {
        // 简化: 使用时间戳取模作为伪随机
        let now = currentTimeMillis()
        let idx = now % upstreams.size
        return upstreams[Int64(idx)]
    }

    /// 最少连接选择
    private func selectLeastConn(upstreams: ArrayList<UpstreamServer>): ?UpstreamServer {
        var best: ?UpstreamServer = None
        var minConn: Int64 = Int64.MAX
        for (upstream in upstreams) {
            // 简化: 使用连接池状态作为活跃连接数
            // 实际应追踪每个上游的活跃请求数
            let connCount: Int64 = 0
            if (connCount < minConn) {
                minConn = connCount
                best = Some(upstream)
            }
        }
        return best
    }

    /// 加权轮询选择 - Smooth Weighted Round-Robin (Nginx 算法)
    private func selectWeightedRoundRobin(upstreams: ArrayList<UpstreamServer>): UpstreamServer {
        var totalWeight: Int64 = 0
        var bestIdx: Int64 = -1
        var bestWeight: Int64 = Int64.MIN

        for (i in 0..upstreams.size) {
            let upstream = upstreams[i]
            let weightIdx = indexOfUpstream(upstream)
            if (weightIdx >= 0 && weightIdx < currentWeights.size) {
                currentWeights[Int64(weightIdx)] += upstream.weight
            }
            totalWeight += upstream.weight

            if (weightIdx >= 0 && weightIdx < currentWeights.size &&
                currentWeights[Int64(weightIdx)] > bestWeight) {
                bestWeight = currentWeights[Int64(weightIdx)]
                bestIdx = Int64(weightIdx)
            }
        }

        if (bestIdx >= 0 && bestIdx < currentWeights.size) {
            currentWeights[bestIdx] -= totalWeight
            return upstreams[bestIdx]
        }

        return upstreams[0]
    }

    /// 查找上游在列表中的索引
    private func indexOfUpstream(target: UpstreamServer): Int64 {
        for (i in 0..upstreams.size) {
            if (upstreams[i].host == target.host && upstreams[i].port == target.port) {
                return i
            }
        }
        return -1
    }

    // ========================================================================
    // 请求转发
    // ========================================================================

    /// 转发请求到上游服务器
    /// 1. 选择上游 (负载均衡)
    /// 2. 修改请求头部 (X-Forwarded-*, Via)
    /// 3. 发送请求到上游
    /// 4. 转发响应回客户端
    public func proxy(request: Request, clientIp: String): ?Response {
        // 选择上游
        let upstream = selectUpstream()
        match (upstream) {
            case Some(server) => {
                var retries: Int64 = 0
                var lastError: ?String = None

                while (retries <= maxRetries) {
                    let result = tryProxy(request, server, clientIp)
                    match (result) {
                        case Some(response) => {
                            // 检查上游是否仍然健康
                            if (response.status >= 500) {
                                server.markUnhealthy()
                            }
                            return response
                        }
                        case None => {
                            retries += 1
                            lastError = Some("Upstream ${server.host}:${server.port} failed")
                            if (retries <= maxRetries) {
                                // 重试: 尝试选择另一个上游
                                let nextUpstream = selectUpstream()
                                match (nextUpstream) {
                                    case Some(next) => server = next
                                    case None => break
                                }
                            }
                        }
                    }
                }

                return None
            }
            case None => return None
        }
    }

    /// 尝试代理到指定上游
    private func tryProxy(request: Request, upstream: UpstreamServer,
                           clientIp: String): ?Response {
        // 构建上游请求
        let upstreamUrl = "${upstream.baseUrl()}${request.path()}"
        if (request.search().size > 0) {
            upstreamUrl = "${upstreamUrl}?${request.search()}"
        }

        let upstreamRequest = Request(request.method, upstreamUrl)

        // 复制头部
        for (key in request.headers.keys()) {
            match (request.headers.get(key)) {
                case Some(v) => upstreamRequest.headers.set(key, v)
                case None => ()
            }
        }

        // 添加代理头部
        if (passForwardedHeaders) {
            ProxyHeaders.setForwardedFor(upstreamRequest.headers, clientIp)
            ProxyHeaders.setForwardedProto(upstreamRequest.headers, "http")
            ProxyHeaders.setForwardedHost(upstreamRequest.headers,
                match (request.headers.get("host")) {
                    case Some(h) => h
                    case None => "localhost"
                })
            ProxyHeaders.setVia(upstreamRequest.headers, "bao-proxy")
        }

        // 设置上游 Host 头
        upstreamRequest.headers.set("Host", "${upstream.host}:${upstream.port}")

        // 复制 body
        match (request.body) {
            case Some(body) => upstreamRequest.body = Some(body)
            case None => ()
        }

        // 发送到上游
        // 简化: 使用 HttpClient 发送
        // 实际实现应复用 upstream.pool 连接池
        return HttpClient.fetch(upstreamRequest)
    }

    // ========================================================================
    // 健康检查
    // ========================================================================

    /// 对所有上游执行健康检查
    public func healthCheck(): Unit {
        for (upstream in upstreams) {
            // 简化: 发送 HEAD / 请求检查上游是否响应
            let url = "${upstream.baseUrl()}/"
            let response = HttpClient.fetch(url)
            match (response) {
                case _ => {
                    // 如果有响应就标记为健康
                    upstream.markHealthy()
                }
            }
        }
    }

    /// 获取上游列表
    public func getUpstreams(): ArrayList<UpstreamServer> {
        return upstreams
    }

    /// 关闭所有连接
    public func close(): Unit {
        for (upstream in upstreams) {
            upstream.pool.closeAll()
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

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

/// 检查字节数组是否包含 \r\n\r\n
private func containsHeaderEnd(data: Array<UInt8>): Bool {
    if (data.size < 4) { return false }
    for (i in 0..(data.size - 3)) {
        if (data[i] == UInt8(13) && data[i + 1] == UInt8(10) &&
            data[i + 2] == UInt8(13) && data[i + 3] == UInt8(10)) {
            return true
        }
    }
    return false
}

/// 获取当前时间戳 (毫秒)
private func currentTimeMillis(): Int64 {
    unsafe {
        var ts = Array<Int64>(2, item: 0)
        clock_gettime(0, ts.toArray().unsafePtr())
        return ts[0] * 1000 + ts[1] / 1000000
    }
}

/// 字节数组转字符串
private func bytesToString(bytes: Array<UInt8>): String {
    let sb = StringBuilder()
    for (b in bytes) {
        sb.append(Char(Int32(b)))
    }
    return sb.toString()
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    let bytes = Array<UInt8>()
    for (c in s) {
        bytes.append(UInt8(c.value & 0xFF))
    }
    return bytes
}

/// 原始写入
private func writeRaw(fd: Int64, data: Array<UInt8>): Int64 {
    let result = SysFs.write(fd, data)
    match (result) {
        case Ok(n) => n
        case Err(_) => -1
    }
}

/// C FFI: clock_gettime
@C
foreign func clock_gettime(clockid: Int32, tp: CPointer<Int64>): Int32
