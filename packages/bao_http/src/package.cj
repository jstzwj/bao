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
        match (s.toUpper()) {
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
                headers.put(entry[0].toLower(), entry[1])
            }
        }
    }

    /// 从对象初始化
    public init(obj: HashMap<String, String>) {
        headers = HashMap<String, String>()
        for (key in obj.keys()) {
            match (obj.get(key)) {
                case Some(v) => headers.put(key.toLower(), v)
                case None => ()
            }
        }
    }

    public func get(name: String): ?String {
        return headers.get(name.toLower())
    }

    public func set(name: String, value: String): Unit {
        headers.put(name.toLower(), value)
    }

    public func has(name: String): Bool {
        return headers.contains(name.toLower())
    }

    public func remove(name: String): Unit {
        headers.remove(name.toLower())
    }

    /// 追加值 (同一 header 多值)
    public func append(name: String, value: String): Unit {
        let key = name.toLower()
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
                case Some(v) => {
                    sb.append(key)
                    sb.append(": ")
                    sb.append(v)
                    sb.append("\r\n")
                }
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
    public var search: String
    public var hash: String

    public init() {
        protocol = "http"
        hostname = "localhost"
        port = 80
        path = "/"
        search = ""
        hash = ""
    }

    /// 从字符串解析 URL
    public static func parse(url: String): ParsedUrl {
        let result = ParsedUrl()
        var remaining = url

        // protocol
        let protoIdx = remaining.indexOf("://")
        if (protoIdx >= 0) {
            result.protocol = remaining.substring(0, protoIdx)
            remaining = remaining.substring(protoIdx + 3)
        }

        // hash
        let hashIdx = remaining.indexOf("#")
        if (hashIdx >= 0) {
            result.hash = remaining.substring(hashIdx + 1)
            remaining = remaining.substring(0, hashIdx)
        }

        // search
        let searchIdx = remaining.indexOf("?")
        if (searchIdx >= 0) {
            result.search = remaining.substring(searchIdx + 1)
            remaining = remaining.substring(0, searchIdx)
        }

        // path
        let pathIdx = remaining.indexOf("/")
        if (pathIdx >= 0) {
            result.path = remaining.substring(pathIdx)
            remaining = remaining.substring(0, pathIdx)
        } else {
            result.path = "/"
        }

        // host:port
        let colonIdx = remaining.lastIndexOf(":")
        if (colonIdx >= 0) {
            result.hostname = remaining.substring(0, colonIdx)
            try {
                result.port = Int64.parse(remaining.substring(colonIdx + 1))
            } catch (_: Exception) {
                result.port = 80
            }
        } else {
            result.hostname = remaining
            result.port = if (result.protocol == "https") { 443 } else { 80 }
        }

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
        match (body) {
            case Some(bytes) => {
                let sb = StringBuilder()
                for (b in bytes) {
                    sb.append(Char(Int32(b)))
                }
                return sb.toString()
            }
            case None => ""
        }
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
        match (body) {
            case Some(bytes) => {
                let sb = StringBuilder()
                for (b in bytes) {
                    sb.append(Char(Int32(b)))
                }
                return sb.toString()
            }
            case None => ""
        }
    }

    /// 获取响应体为 JSON 字符串
    public func json(): String {
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
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return bytes
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
public class HttpServer {
    private var handler: ?RequestHandler
    private var eventLoop: EventLoop
    private var listening: Bool
    private var port: Int64
    private var host: String

    public init() {
        handler = None
        eventLoop = EventLoop()
        listening = false
        port = 3000
        host = "0.0.0.0"
    }

    /// 设置请求处理函数
    public func setHandler(handler: RequestHandler): HttpServer {
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
        let bodyStr = match (request.body) {
            case Some(bytes) => {
                let sb = StringBuilder()
                for (b in bytes) { sb.append(Char(Int32(b))) }
                Some(sb.toString())
            }
            case None => None
        }
        return executeRequest(request.method, parsed, request.headers, bodyStr)
    }

    /// 执行 HTTP 请求
    /// 当前为简化实现，需要 C FFI socket 支持才能真正工作
    private static func executeRequest(method: HttpMethod, url: ParsedUrl,
                                        headers: Headers, body: ?String): Response {
        // 构建原始 HTTP 请求
        let sb = StringBuilder()
        sb.append(method.toString())
        sb.append(" ")
        sb.append(url.path)
        if (url.search.length > 0) {
            sb.append("?")
            sb.append(url.search)
        }
        sb.append(" HTTP/1.1\r\n")
        sb.append("Host: ${url.hostname}\r\n")

        // 添加请求头
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => sb.append("${key}: ${v}\r\n")
                case None => ()
            }
        }

        // 添加 body
        match (body) {
            case Some(b) => {
                sb.append("Content-Length: ${b.length}\r\n")
                sb.append("\r\n")
                sb.append(b)
            }
            case None => sb.append("\r\n")
        }

        // TODO: 通过 C FFI socket 发送请求并解析响应
        // 当前返回模拟响应
        return Response(501, "HTTP client not yet implemented - requires C FFI socket")
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
        let sb = StringBuilder()
        for (b in data) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    public static func fromString(s: String, type_: String): Blob {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return Blob(bytes, type_)
    }
}

/// BAO_VERSION
public let BAO_VERSION = "0.1.0"
