// bao_http - HTTP 服务和客户端
// 对应 Bun: src/http/, src/uws/, src/api/fetch.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_event_loop.*

// ============================================================================
// HTTP 类型
// 对应 Bun: src/http_types/
// ============================================================================

/// HTTP 方法
public enum HttpMethod {
    | GET
    | POST
    | PUT
    | DELETE
    | PATCH
    | HEAD
    | OPTIONS
    | CONNECT
    | TRACE

    public func toString(): String {
        match (this) {
            case GET => "GET"
            case POST => "POST"
            case PUT => "PUT"
            case DELETE => "DELETE"
            case PATCH => "PATCH"
            case HEAD => "HEAD"
            case OPTIONS => "OPTIONS"
            case CONNECT => "CONNECT"
            case TRACE => "TRACE"
        }
    }

    public static func fromString(s: String): HttpMethod {
        match (packageUpper(s)) {
            case "GET" => GET
            case "POST" => POST
            case "PUT" => PUT
            case "DELETE" => DELETE
            case "PATCH" => PATCH
            case "HEAD" => HEAD
            case "OPTIONS" => OPTIONS
            case "CONNECT" => CONNECT
            case "TRACE" => TRACE
            case _ => GET
        }
    }
}

/// HTTP 请求头
/// 对应 Bun: src/http_types/Headers.zig
public class Headers {
    private var headers: HashMap<String, String>

    public init() {
        headers = HashMap<String, String>()
    }

    /// 从数组初始化 [[key, val], ...]
    public init(entries: ArrayList<ArrayList<String>>) {
        headers = HashMap<String, String>()
        for (entry in entries) {
            if (entry.size >= 2) {
                headers.put(packageLower(entry[0]), entry[1])
            }
        }
    }

    /// 从对象初始化
    public init(obj: HashMap<String, String>) {
        headers = HashMap<String, String>()
        for (key in obj.keys()) {
            match (obj.get(key)) {
                case Some(v) => headers.put(packageLower(key), v)
                case None => ()
            }
        }
    }

    public func get(name: String): ?String {
        return headers.get(packageLower(name))
    }

    public func set(name: String, value: String): Unit {
        headers.put(packageLower(name), value)
    }

    public func has(name: String): Bool {
        return headers.contains(packageLower(name))
    }

    public func remove(name: String): Unit {
        headers.remove(packageLower(name))
    }

    /// 追加值 (同一 header 多值)
    public func append(name: String, value: String): Unit {
        let key = packageLower(name)
        match (headers.get(key)) {
            case Some(existing) => headers.put(key, "${existing}, ${value}")
            case None => headers.put(key, value)
        }
    }

    /// 获取所有键
    public func keys(): ArrayList<String> {
        return headers.keys()
    }

    /// 获取所有值
    public func values(): ArrayList<String> {
        return headers.values()
    }

    /// 键值对数量
    public func size(): Int64 {
        return headers.keys().size
    }

    /// 遍历
    public func forEach(fn: (String, String) -> Unit): Unit {
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => fn(key, v)
                case None => ()
            }
        }
    }

    /// 序列化为 HTTP 头字符串
    public func toString(): String {
        let sb = StringBuilder()
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) =>
                    sb.append(key)
                    sb.append(": ")
                    sb.append(v)
                    sb.append("\r\n")
                case None => ()
            }
        }
        return sb.toString()
    }

    /// 克隆
    public func clone(): Headers {
        let h = Headers()
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => h.set(key, v)
                case None => ()
            }
        }
        return h
    }
}

private func packageLowerByte(c: UInt8): UInt8 {
    if (c >= UInt8(65) && c <= UInt8(90)) {
        return c + UInt8(32)
    }
    return c
}

private func packageUpperByte(c: UInt8): UInt8 {
    if (c >= UInt8(97) && c <= UInt8(122)) {
        return c - UInt8(32)
    }
    return c
}

private func packageLower(s: String): String {
    let sb = StringBuilder()
    for (c in s) {
        sb.append(packageLowerByte(c))
    }
    return sb.toString()
}

private func packageUpper(s: String): String {
    let sb = StringBuilder()
    for (c in s) {
        sb.append(packageUpperByte(c))
    }
    return sb.toString()
}

private func packageBytesToString(bytes: Array<UInt8>): String {
    let sb = StringBuilder()
    for (b in bytes) {
        sb.append(Rune(UInt32(b)))
    }
    return sb.toString()
}

private func packageStringToBytes(s: String): Array<UInt8> {
    let bytes = ArrayList<UInt8>()
    for (c in s) {
        bytes.append(c)
    }
    return bytes.toOwnedSlice()
}

/// HTTP 状态码映射
/// 对应 Bun: src/http_types/status.zig
public class HttpStatus {
    public static let Continue = 100
    public static let SwitchingProtocols = 101
    public static let OK = 200
    public static let Created = 201
    public static let Accepted = 202
    public static let NoContent = 204
    public static let MovedPermanently = 301
    public static let Found = 302
    public static let NotModified = 304
    public static let TemporaryRedirect = 307
    public static let PermanentRedirect = 308
    public static let BadRequest = 400
    public static let Unauthorized = 401
    public static let Forbidden = 403
    public static let NotFound = 404
    public static let MethodNotAllowed = 405
    public static let RequestTimeout = 408
    public static let Conflict = 409
    public static let Gone = 410
    public static let PayloadTooLarge = 413
    public static let UnprocessableEntity = 422
    public static let TooManyRequests = 429
    public static let InternalServerError = 500
    public static let NotImplemented = 501
    public static let BadGateway = 502
    public static let ServiceUnavailable = 503
    public static let GatewayTimeout = 504

    public static func text(code: Int64): String {
        match (code) {
            case 100 => "Continue"
            case 101 => "Switching Protocols"
            case 200 => "OK"
            case 201 => "Created"
            case 202 => "Accepted"
            case 204 => "No Content"
            case 301 => "Moved Permanently"
            case 302 => "Found"
            case 304 => "Not Modified"
            case 307 => "Temporary Redirect"
            case 308 => "Permanent Redirect"
            case 400 => "Bad Request"
            case 401 => "Unauthorized"
            case 403 => "Forbidden"
            case 404 => "Not Found"
            case 405 => "Method Not Allowed"
            case 408 => "Request Timeout"
            case 409 => "Conflict"
            case 410 => "Gone"
            case 413 => "Payload Too Large"
            case 422 => "Unprocessable Entity"
            case 429 => "Too Many Requests"
            case 500 => "Internal Server Error"
            case 501 => "Not Implemented"
            case 502 => "Bad Gateway"
            case 503 => "Service Unavailable"
            case 504 => "Gateway Timeout"
            case _ => "Unknown"
        }
    }
}

/// URL 解析结果
public class ParsedUrl {
    public var protocol: String
    public var hostname: String
    public var port: Int64
    public var path: String
    public var pathname: String
    public var href: String
    public var host: String
    public var origin: String
    public var search: String
    public var hash: String

    public init() {
        protocol = "http"
        hostname = "localhost"
        port = 0
        path = "/"
        pathname = "/"
        href = ""
        host = "localhost"
        origin = "http://localhost"
        search = ""
        hash = ""
    }

    public func isHTTPS(): Bool {
        return protocol == "https"
    }

    public func getPortAuto(): UInt16 {
        if (port != 0) {
            return UInt16(port)
        }
        return if (isHTTPS()) { UInt16(443) } else { UInt16(80) }
    }

    /// 从字符串解析 URL
    public static func parse(url: String): ParsedUrl {
        let result = ParsedUrl()
        var remaining = url

        // protocol
        let protoIdxOpt = remaining.indexOf("://")
        if (protoIdxOpt.isSome()) {
            let protoIdx = protoIdxOpt.getOrThrow()
            result.protocol = remaining[0..protoIdx]
            remaining = remaining[(protoIdx + 3)..]
        }

        // hash
        let hashIdxOpt = remaining.indexOf("#")
        if (hashIdxOpt.isSome()) {
            let hashIdx = hashIdxOpt.getOrThrow()
            result.hash = remaining[(hashIdx + 1)..]
            remaining = remaining[0..hashIdx]
        }

        // search
        let searchIdxOpt = remaining.indexOf("?")
        if (searchIdxOpt.isSome()) {
            let searchIdx = searchIdxOpt.getOrThrow()
            result.search = remaining[(searchIdx + 1)..]
            remaining = remaining[0..searchIdx]
        }

        // path
        let pathIdxOpt = remaining.indexOf("/")
        if (pathIdxOpt.isSome()) {
            let pathIdx = pathIdxOpt.getOrThrow()
            result.path = remaining[pathIdx..]
            result.pathname = result.path
            remaining = remaining[0..pathIdx]
        } else {
            result.path = "/"
            result.pathname = "/"
        }

        // host:port
        let colonIdxOpt = remaining.lastIndexOf(":")
        if (colonIdxOpt.isSome()) {
            let colonIdx = colonIdxOpt.getOrThrow()
            result.hostname = remaining[0..colonIdx]
            result.port = parseInt64(remaining[(colonIdx + 1)..])
            result.host = remaining
        } else {
            result.hostname = remaining
            result.port = if (result.protocol == "https") { 443 } else { 80 }
            result.host = remaining
        }
        result.origin = "${result.protocol}://${result.host}"
        result.href = url

        return result
    }
}

/// HTTP 请求
/// 对应 Bun: src/http_types/Request.zig + Web API Request
public class Request {
    public let method: HttpMethod
    public let url: String
    public let headers: Headers
    public var body: ?Array<UInt8>
    public var parsedUrl: ?ParsedUrl

    public init(method: HttpMethod, url: String) {
        this.method = method
        this.url = url
        this.headers = Headers()
        this.body = None
        this.parsedUrl = Some(ParsedUrl.parse(url))
    }

    public init(method: HttpMethod, url: String, headers: Headers) {
        this.method = method
        this.url = url
        this.headers = headers
        this.body = None
        this.parsedUrl = Some(ParsedUrl.parse(url))
    }

    /// 获取请求体为字符串
    public func text(): String {
        if (body.isSome()) {
            return packageBytesToString(body.getOrThrow())
        }
        return ""
    }

    /// 获取请求体为 JSON (返回字符串形式)
    public func json(): String {
        return text()
    }

    /// 获取 Content-Type
    public func contentType(): ?String {
        return headers.get("content-type")
    }

    /// 获取 URL 路径
    public func path(): String {
        match (parsedUrl) {
            case Some(u) => u.path
            case None => "/"
        }
    }

    /// 获取查询参数字符串
    public func search(): String {
        match (parsedUrl) {
            case Some(u) => u.search
            case None => ""
        }
    }

    /// 是否为 JSON 请求
    public func isJson(): Bool {
        match (headers.get("content-type")) {
            case Some(ct) => ct.contains("application/json")
            case None => false
        }
    }
}

/// HTTP 响应
/// 对应 Bun: src/http_types/Response.zig + Web API Response
public class Response {
    public var status: Int64
    public var statusText: String
    public let headers: Headers
    public var body: ?Array<UInt8>
    public var url: String
    public var redirected: Bool
    public var ok: Bool

    public init(status: Int64) {
        this.status = status
        this.statusText = HttpStatus.text(status)
        this.headers = Headers()
        this.body = None
        this.url = ""
        this.redirected = false
        this.ok = status >= 200 && status < 300
    }

    public init(status: Int64, body: String) {
        this.status = status
        this.statusText = HttpStatus.text(status)
        this.headers = Headers()
        this.headers.set("Content-Type", "text/plain; charset=utf-8")
        this.body = Some(stringToBytes(body))
        this.url = ""
        this.redirected = false
        this.ok = status >= 200 && status < 300
    }

    /// JSON 响应
    public static func json(status: Int64, body: String): Response {
        let resp = Response(status)
        resp.headers.set("Content-Type", "application/json; charset=utf-8")
        resp.body = Some(stringToBytes(body))
        return resp
    }

    /// HTML 响应
    public static func html(status: Int64, body: String): Response {
        let resp = Response(status)
        resp.headers.set("Content-Type", "text/html; charset=utf-8")
        resp.body = Some(stringToBytes(body))
        return resp
    }

    /// 重定向响应
    public static func redirect(url: String, status: Int64): Response {
        let resp = Response(status)
        resp.headers.set("Location", url)
        resp.redirected = true
        return resp
    }

    /// 获取响应体为字符串
    public func text(): String {
        if (body.isSome()) {
            return packageBytesToString(body.getOrThrow())
        }
        return ""
    }

    /// 获取响应体为 JSON 字符串
    public func jsonText(): String {
        return text()
    }

    /// 设置 body
    public func setBody(data: String): Unit {
        body = Some(stringToBytes(data))
    }

    /// 设置 body (字节数组)
    public func setBodyBytes(data: Array<UInt8>): Unit {
        body = Some(data)
    }

    private static func stringToBytes(s: String): Array<UInt8> {
        return packageStringToBytes(s)
    }
}

/// HTTP 请求处理器
public type RequestHandler = (Request) -> Response

// ============================================================================
// HTTP 服务器
// 对应 Bun: src/http/server.zig
// ============================================================================

/// HTTP 服务器
/// 对应 Bun: src/http/server.zig Server
public class PackageHttpServer {
    private var handler: ?RequestHandler
    private var eventLoop: EventLoopHandle
    private var listening: Bool
    private var port: Int64
    private var host: String

    public init() {
        handler = None
        eventLoop = EventLoopHandle(MiniEventLoop())
        listening = false
        port = 3000
        host = "0.0.0.0"
    }

    /// 设置请求处理函数
    public func setHandler(handler: RequestHandler): PackageHttpServer {
        this.handler = Some(handler)
        return this
    }

    /// 监听端口
    public func listen(port: Int64, host: String): Unit {
        this.port = port
        this.host = host
        listening = true
        // 仓颉中没有原生 TCP socket 库
        // 实际实现需要通过 C FFI 调用 socket/bind/listen/accept
        // 当前为骨架实现
    }

    /// 监听端口 (默认 host)
    public func listen(port: Int64): Unit {
        listen(port, "0.0.0.0")
    }

    /// 处理单个请求 (用于测试和嵌入场景)
    public func handleRequest(request: Request): Response {
        match (handler) {
            case Some(h) => h(request)
            case None => Response(500, "No handler registered")
        }
    }

    /// 关闭服务器
    public func close(): Unit {
        listening = false
    }

    /// 是否在监听
    public func isListening(): Bool {
        return listening
    }

    /// 获取监听端口
    public func getPort(): Int64 {
        return port
    }

    /// 获取地址
    public func getAddress(): String {
        return "${host}:${port}"
    }
}

// ============================================================================
// HTTP 客户端 (Fetch API)
// 对应 Bun: src/runtime/api/fetch.zig
// ============================================================================

/// Fetch 请求选项
/// 对应 Web API RequestInit
public class FetchOptions {
    public var method: String
    public var headers: Headers
    public var body: ?String
    public var redirect: String  // "follow" | "error" | "manual"

    public init() {
        method = "GET"
        headers = Headers()
        body = None
        redirect = "follow"
    }
}

/// HTTP 客户端
/// 对应 Bun: src/runtime/api/fetch.zig
public class HttpClient {
    /// 发起 GET 请求
    public static func fetch(url: String): Response {
        let parsed = ParsedUrl.parse(url)
        return executeRequest(HttpMethod.GET, parsed, Headers(), None)
    }

    /// 发起 HTTP 请求 (带选项)
    public static func fetch(url: String, options: FetchOptions): Response {
        let parsed = ParsedUrl.parse(url)
        let method = HttpMethod.fromString(options.method)
        return executeRequest(method, parsed, options.headers, options.body)
    }

    /// 发起 HTTP 请求 (Request 对象)
    public static func fetch(request: Request): Response {
        let parsed = match (request.parsedUrl) {
            case Some(u) => u
            case None => ParsedUrl.parse(request.url)
        }
        let bodyStr: ?String = if (request.body.isSome()) {
            Some(packageBytesToString(request.body.getOrThrow()))
        } else {
            None
        }
        return executeRequest(request.method, parsed, request.headers, bodyStr)
    }

    /// 执行 HTTP 请求
    /// 对应 Bun: AsyncHTTP.init + HTTPClient.start
    private static func executeRequest(method: HttpMethod, url: ParsedUrl,
                                        headers: Headers, body: ?String): Response {
        let requestUrl = buildUrl(url)
        var builder = HttpRequestBuilder(method, requestUrl)
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => builder.header(key, v)
                case None => ()
            }
        }
        match (body) {
            case Some(b) => builder.body(b)
            case None => ()
        }

        let client = HttpClient2()
        let response = client.sendWithRedirects(builder)
        match (response) {
            case Some(r) => r
            case None => Response(500, "HTTP request failed")
        }
    }

    private static func buildUrl(url: ParsedUrl): String {
        let sb = StringBuilder()
        sb.append(url.protocol)
        sb.append("://")
        sb.append(url.hostname)
        if ((url.protocol == "http" && url.port != 80) || (url.protocol == "https" && url.port != 443)) {
            sb.append(":")
            sb.append(url.port.toString())
        }
        sb.append(url.path)
        if (url.search.size > 0) {
            sb.append("?")
            sb.append(url.search)
        }
        return sb.toString()
    }
}

// ============================================================================
// FormData 和 Blob (简化)
// 对应 Bun: src/runtime/api/FormData.zig, Blob.zig
// ============================================================================

/// FormData 条目
public class FormDataEntry {
    public var name: String
    public var value: String
    public var filename: ?String
    public var contentType: ?String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
        this.filename = None
        this.contentType = None
    }
}

/// FormData — 简化实现
/// 对应 Bun: src/runtime/api/FormData.zig
public class FormData {
    private var entries: ArrayList<FormDataEntry>

    public init() {
        entries = ArrayList<FormDataEntry>()
    }

    public func append(name: String, value: String): Unit {
        entries.append(FormDataEntry(name, value))
    }

    public func get(name: String): ?String {
        for (entry in entries) {
            if (entry.name == name) { return Some(entry.value) }
        }
        return None
    }

    public func getAll(name: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (entry in entries) {
            if (entry.name == name) { result.append(entry.value) }
        }
        return result
    }

    public func has(name: String): Bool {
        for (entry in entries) {
            if (entry.name == name) { return true }
        }
        return false
    }

    public func delete(name: String): Unit {
        let newArr = ArrayList<FormDataEntry>()
        for (entry in entries) {
            if (entry.name != name) { newArr.append(entry) }
        }
        entries = newArr
    }
}

/// Blob — 简化实现
/// 对应 Bun: src/runtime/api/Blob.zig
public class Blob {
    public var data: Array<UInt8>
    public var type_: String

    public init() {
        data = Array<UInt8>()
        type_ = ""
    }

    public init(data: Array<UInt8>, type_: String) {
        this.data = data
        this.type_ = type_
    }

    public func size(): Int64 {
        return data.size
    }

    public func text(): String {
        return packageBytesToString(data)
    }

    public static func fromString(s: String, type_: String): Blob {
        return Blob(packageStringToBytes(s), type_)
    }
}

/// BAO_VERSION
public let BAO_VERSION = "0.1.0"
