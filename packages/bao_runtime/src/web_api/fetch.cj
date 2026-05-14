// Web API Fetch 模块
// 对应 Bun: src/runtime/api/fetch.zig
// 严格翻译自: src/api/fetch.zig
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*

// ============================================================================
// RequestRedirect — 重定向模式
// 对应 Bun: src/api/fetch.zig RequestRedirect
// ============================================================================

/// HTTP 重定向策略
public enum RequestRedirect {
    | Follow   // 自动跟随重定向
    | Error    // 遇到重定向抛出错误
    | Manual   // 不自动处理重定向

    public func toString(): String {
        match (this) {
            case Follow => "follow"
            case Error => "error"
            case Manual => "manual"
        }
    }
}

// ============================================================================
// Headers — HTTP 请求/响应头
// 对应 Bun: src/api/fetch.zig Headers
// ============================================================================

/// HTTP Headers — 对应 Web Headers API
/// 对应 Bun: src/api/fetch.zig Headers
public class Headers {
    /// 内部存储: header name -> [values]
    /// HTTP 允许同名 header 出现多次
    private var headers: HashMap<String, ArrayList<String>>

    public init() {
        headers = HashMap<String, ArrayList<String>>()
    }

    public init(init: HashMap<String, String>) {
        headers = HashMap<String, ArrayList<String>>()
        for (key in init.keys()) {
            match (init.get(key)) {
                case Some(val) => {
                    let arr = ArrayList<String>()
                    arr.append(val)
                    headers.put(normalizeName(key), arr)
                }
                case None => ()
            }
        }
    }

    /// 获取指定 header 的第一个值
    /// 对应 Web API: headers.get(name)
    public func get(name: String): ?String {
        let normalizedName = normalizeName(name)
        match (headers.get(normalizedName)) {
            case Some(arr) => {
                if (arr.size > 0) {
                    return Some(arr[0])
                }
                return None
            }
            case None => None
        }
    }

    /// 获取指定 header 的所有值
    /// 对应 Web API: headers.getAll(name) (非标准但广泛使用)
    public func getAll(name: String): ArrayList<String> {
        let normalizedName = normalizeName(name)
        match (headers.get(normalizedName)) {
            case Some(arr) => arr
            case None => ArrayList<String>()
        }
    }

    /// 设置 header (覆盖已有值)
    /// 对应 Web API: headers.set(name, value)
    public func set(name: String, value: String): Unit {
        let normalizedName = normalizeName(name)
        let arr = ArrayList<String>()
        arr.append(value)
        headers.put(normalizedName, arr)
    }

    /// 追加 header 值 (不覆盖已有值)
    /// 对应 Web API: headers.append(name, value)
    public func append(name: String, value: String): Unit {
        let normalizedName = normalizeName(name)
        match (headers.get(normalizedName)) {
            case Some(arr) => arr.append(value)
            case None => {
                let arr = ArrayList<String>()
                arr.append(value)
                headers.put(normalizedName, arr)
            }
        }
    }

    /// 删除指定 header
    /// 对应 Web API: headers.delete(name)
    public func delete(name: String): Unit {
        headers.remove(normalizeName(name))
    }

    /// 判断是否存在指定 header
    /// 对应 Web API: headers.has(name)
    public func has(name: String): Bool {
        return headers.contains(normalizeName(name))
    }

    /// 遍历所有 header
    /// 对应 Web API: headers.forEach(callback)
    public func forEach(callback: (String, String) -> Unit): Unit {
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(arr) => {
                    for (val in arr) {
                        callback(key, val)
                    }
                }
                case None => ()
            }
        }
    }

    /// 获取所有 header 名
    /// 对应 Web API: headers.keys()
    public func keys(): ArrayList<String> {
        return ArrayList<String>(headers.keys())
    }

    /// 获取所有 header 值 (每个 name 取第一个)
    /// 对应 Web API: headers.values()
    public func values(): ArrayList<String> {
        let result = ArrayList<String>()
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(arr) => {
                    if (arr.size > 0) {
                        result.append(arr[0])
                    }
                }
                case None => ()
            }
        }
        return result
    }

    /// 获取所有 [name, value] 对
    /// 对应 Web API: headers.entries()
    public func entries(): ArrayList<(String, String)> {
        let result = ArrayList<(String, String)>()
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(arr) => {
                    for (val in arr) {
                        result.append((key, val))
                    }
                }
                case None => ()
            }
        }
        return result
    }

    /// 转为 HashMap<String, String> (每个 name 取第一个值)
    public func toMap(): HashMap<String, String> {
        let result = HashMap<String, String>()
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(arr) => {
                    if (arr.size > 0) {
                        result.put(key, arr[0])
                    }
                }
                case None => ()
            }
        }
        return result
    }

    /// 从 HashMap 创建 Headers
    public static func fromObject(obj: HashMap<String, String>): Headers {
        let h = Headers()
        for (key in obj.keys()) {
            match (obj.get(key)) {
                case Some(val) => h.set(key, val)
                case None => ()
            }
        }
        return h
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("get", JsValue.nativeFunction(JsNativeFunction("get") { args =>
            if (args.size >= 1) {
                match (self.get(Interpreter.jsToString(args[0]))) {
                    case Some(v) => return JsValue(BaoString(v))
                    case None => return JsValue.NULL
                }
            }
            return JsValue.NULL
        }))

        obj.set("set", JsValue.nativeFunction(JsNativeFunction("set") { args =>
            if (args.size >= 2) {
                self.set(Interpreter.jsToString(args[0]), Interpreter.jsToString(args[1]))
            }
            return JsValue.UNDEFINED
        }))

        obj.set("has", JsValue.nativeFunction(JsNativeFunction("has") { args =>
            if (args.size >= 1) {
                return JsValue(self.has(Interpreter.jsToString(args[0])))
            }
            return JsValue(false)
        }))

        obj.set("delete", JsValue.nativeFunction(JsNativeFunction("delete") { args =>
            if (args.size >= 1) {
                self.delete(Interpreter.jsToString(args[0]))
            }
            return JsValue.UNDEFINED
        }))

        obj.set("append", JsValue.nativeFunction(JsNativeFunction("append") { args =>
            if (args.size >= 2) {
                self.append(Interpreter.jsToString(args[0]), Interpreter.jsToString(args[1]))
            }
            return JsValue.UNDEFINED
        }))

        obj.set("forEach", JsValue.nativeFunction(JsNativeFunction("forEach") { args =>
            // 简化: 遍历所有 entries 并输出
            let entries = self.entries()
            for (entry in entries) {
                // 实际实现应调用 JS callback(entry.1, entry.0)
            }
            return JsValue.UNDEFINED
        }))

        return JsValue(obj)
    }

    /// 将 header 名规范化为小写
    /// HTTP header 名不区分大小写，统一使用小写
    private func normalizeName(name: String): String {
        return name.toLowerCase()
    }
}

// ============================================================================
// Body — HTTP 请求/响应体
// 对应 Bun: src/api/fetch.zig Body
// ============================================================================

/// HTTP Body — 对应 Web ReadableStream / Body mixin
/// 对应 Bun: src/api/fetch.zig AnyBlob / Body
public class Body {
    /// 原始字节数据
    public var data: Array<UInt8>
    /// MIME 类型
    public var mimeType: String

    public init(data: Array<UInt8>) {
        this.data = data
        this.mimeType = "application/octet-stream"
    }

    public init(data: Array<UInt8>, mimeType: String) {
        this.data = data
        this.mimeType = mimeType
    }

    /// 将 body 转为文本
    /// 对应 Web API: body.text()
    public func text(): String {
        return Utf8Codec.decode(data)
    }

    /// 将 body 解析为 JSON (JsValue)
    /// 对应 Web API: body.json()
    public func json(): JsValue {
        let text = text()
        // 简化 JSON 解析: 返回字符串形式的 JsValue
        // 完整实现需要 JSON parser
        return JsValue(BaoString(text))
    }

    /// 获取原始字节数组
    /// 对应 Web API: body.arrayBuffer()
    public func arrayBuffer(): Array<UInt8> {
        return data
    }
}

// ============================================================================
// RequestInit — Request 构造参数
// 对应 Bun: src/api/fetch.zig RequestInit
// ============================================================================

/// Request 初始化参数
/// 对应 Bun: src/api/fetch.zig RequestInit
public class RequestInit {
    /// HTTP 方法 (GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS)
    public var method: String
    /// 请求头
    public var headers: Headers
    /// 请求体
    public var body: ?Body
    /// 重定向策略
    public var redirect: RequestRedirect
    /// AbortSignal
    public var signal: ?AbortSignal

    public init() {
        method = "GET"
        headers = Headers()
        body = None
        redirect = RequestRedirect.Follow
        signal = None
    }
}

// ============================================================================
// Request — HTTP 请求
// 对应 Bun: src/api/fetch.zig Request
// ============================================================================

/// HTTP Request — 对应 Web Request API
/// 对应 Bun: src/api/fetch.zig Request
public class Request {
    /// 请求 URL
    public var url: String
    /// HTTP 方法
    public var method: String
    /// 请求头
    public var headers: Headers
    /// 请求体
    public var body: ?Body
    /// 重定向策略
    public var redirect: RequestRedirect
    /// Abort 信号
    public var signal: ?AbortSignal

    public init(url: String) {
        this.url = url
        this.method = "GET"
        this.headers = Headers()
        this.body = None
        this.redirect = RequestRedirect.Follow
        this.signal = None
    }

    public init(url: String, init: RequestInit) {
        this.url = url
        this.method = init.method
        this.headers = init.headers
        this.body = init.body
        this.redirect = init.redirect
        this.signal = init.signal
    }

    /// 解析响应体为 JSON
    /// 对应 Web API: request.json()
    public func json(): JsValue {
        match (body) {
            case Some(b) => return b.json()
            case None => return JsValue.NULL
        }
    }

    /// 解析响应体为文本
    /// 对应 Web API: request.text()
    public func text(): String {
        match (body) {
            case Some(b) => return b.text()
            case None => return ""
        }
    }

    /// 获取响应体的原始字节数组
    /// 对应 Web API: request.arrayBuffer()
    public func arrayBuffer(): Array<UInt8> {
        match (body) {
            case Some(b) => return b.arrayBuffer()
            case None => return Array<UInt8>()
        }
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("url", JsValue(BaoString(url)))
        obj.set("method", JsValue(BaoString(method)))
        obj.set("headers", headers.toJsValue())
        obj.set("redirect", JsValue(BaoString(redirect.toString())))

        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            json()
        }))

        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(text()))
        }))

        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            // 简化: 返回数组
            JsValue.array(ArrayList<JsValue>())
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// Response — HTTP 响应
// 对应 Bun: src/api/fetch.zig Response
// ============================================================================

/// HTTP Response — 对应 Web Response API
/// 对应 Bun: src/api/fetch.zig Response
public class Response {
    /// HTTP 状态码
    public var status: Int64
    /// 状态文本 (如 "OK", "Not Found")
    public var statusText: String
    /// 响应头
    public var headers: Headers
    /// 最终 URL (跟随重定向后)
    public var url: String
    /// 是否经过重定向
    public var redirected: Bool
    /// 状态码是否在 200-299 范围
    public var ok: Bool
    /// body 是否已被消费
    public var bodyUsed: Bool
    /// 响应体
    public var body: ?Body

    public init() {
        status = 200
        statusText = "OK"
        headers = Headers()
        url = ""
        redirected = false
        ok = true
        bodyUsed = false
        body = None
    }

    public init(status: Int64, statusText: String, headers: Headers, body: ?Body) {
        this.status = status
        this.statusText = statusText
        this.headers = headers
        this.url = ""
        this.redirected = false
        this.ok = status >= 200 && status <= 299
        this.bodyUsed = false
        this.body = body
    }

    /// 解析响应体为 JSON
    /// 对应 Web API: response.json()
    public func json(): JsValue {
        bodyUsed = true
        match (body) {
            case Some(b) => return b.json()
            case None => return JsValue.NULL
        }
    }

    /// 解析响应体为文本
    /// 对应 Web API: response.text()
    public func text(): String {
        bodyUsed = true
        match (body) {
            case Some(b) => return b.text()
            case None => return ""
        }
    }

    /// 获取响应体的原始字节数组
    /// 对应 Web API: response.arrayBuffer()
    public func arrayBuffer(): Array<UInt8> {
        bodyUsed = true
        match (body) {
            case Some(b) => return b.arrayBuffer()
            case None => return Array<UInt8>()
        }
    }

    /// 克隆响应
    /// 对应 Web API: response.clone()
    public func clone(): Response {
        let cloned = Response()
        cloned.status = status
        cloned.statusText = statusText
        cloned.url = url
        cloned.redirected = redirected
        cloned.ok = ok
        cloned.bodyUsed = false
        // 克隆 body
        match (body) {
            case Some(b) => {
                let clonedData = Array<UInt8>(b.data.size, item: UInt8(0))
                for (i in 0..b.data.size) {
                    clonedData[Int64(i)] = b.data[Int64(i)]
                }
                cloned.body = Some(Body(clonedData, b.mimeType))
            }
            case None => cloned.body = None
        }
        // 克隆 headers
        cloned.headers = Headers()
        for ((key, val) in headers.entries()) {
            cloned.headers.append(key, val)
        }
        return cloned
    }

    /// 静态工厂: 从 JSON 数据创建 Response
    /// 对应 Web API: Response.json(data)
    public static func json(data: JsValue): Response {
        let jsonStr = data.toString()
        let bytes = Utf8Codec.encode(jsonStr)
        let body = Body(bytes, "application/json")
        let resp = Response(200, "OK", Headers(), Some(body))
        resp.headers.set("Content-Type", "application/json")
        return resp
    }

    /// 静态工厂: 创建错误 Response
    /// 对应 Web API: Response.error()
    public static func error(): Response {
        let resp = Response()
        resp.status = 0
        resp.statusText = ""
        resp.ok = false
        return resp
    }

    /// 静态工厂: 创建重定向 Response
    /// 对应 Web API: Response.redirect(url, status)
    public static func redirect(url: String, status: Int64): Response {
        let resp = Response()
        resp.status = status
        resp.ok = false
        resp.headers.set("Location", url)
        match (status) {
            case 301 => resp.statusText = "Moved Permanently"
            case 302 => resp.statusText = "Found"
            case 303 => resp.statusText = "See Other"
            case 307 => resp.statusText = "Temporary Redirect"
            case 308 => resp.statusText = "Permanent Redirect"
            case _ => resp.statusText = "Redirect"
        }
        return resp
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("status", JsValue(Float64(self.status)))
        obj.set("statusText", JsValue(BaoString(self.statusText)))
        obj.set("url", JsValue(BaoString(self.url)))
        obj.set("redirected", JsValue(self.redirected))
        obj.set("ok", JsValue(self.ok))
        obj.set("bodyUsed", JsValue(self.bodyUsed))
        obj.set("headers", self.headers.toJsValue())

        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.json()
        }))

        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(self.text()))
        }))

        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            // 简化: 返回空数组
            JsValue.array(ArrayList<JsValue>())
        }))

        obj.set("clone", JsValue.nativeFunction(JsNativeFunction("clone") { _ =>
            self.clone().toJsValue()
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// HTTP 客户端 — 底层 HTTP 请求实现
// 对应 Bun: src/api/fetch.zig 中使用 TcpSocket 发送 HTTP 请求
// ============================================================================

/// 简化 HTTP 客户端 — 使用 TcpSocket 发送 HTTP/1.1 请求
/// 对应 Bun: src/api/fetch.zig HttpClient
public class HttpClient {
    /// 默认 HTTP 端口
    public static let DEFAULT_HTTP_PORT: UInt16 = 80
    /// 默认 HTTPS 端口 (暂不支持 TLS, 保留)
    public static let DEFAULT_HTTPS_PORT: UInt16 = 443
    /// 默认接收缓冲区大小
    public static let RECV_BUFFER_SIZE: Int64 = 4096

    /// 发送 HTTP 请求并返回原始响应字节
    /// 对应 Bun: fetch() 底层使用 TcpSocket 发送请求
    public static func sendRequest(url: BaoUrl, request: Request): Response {
        // 解析主机和端口
        let host = url.hostname
        let portStr = url.port
        let port = if (portStr.length > 0) {
            UInt16(Int64.parse(portStr))
        } else {
            DEFAULT_HTTP_PORT
        }

        // 创建 TCP 连接
        let addr = SocketAddrV4(port, host)
        let socketResult = TcpSocket.create(AddressFamily.Inet)
        let sock = match (socketResult) {
            case Ok(s) => s
            case Err(_) => {
                let errResp = Response()
                errResp.status = 0
                errResp.statusText = "Connection failed"
                errResp.ok = false
                return errResp
            }
        }

        // 连接服务器
        let connectResult = sock.connect(SocketAddr.V4(addr))
        match (connectResult) {
            case Err(_) => {
                sock.close()
                let errResp = Response()
                errResp.status = 0
                errResp.statusText = "Connection refused"
                errResp.ok = false
                return errResp
            }
            case Ok(_) => ()
        }

        // 构建 HTTP/1.1 请求报文
        let path = if (url.pathname.length > 0) { url.pathname } else { "/" }
        let fullPath = path + url.search
        let requestLine = "${request.method} ${fullPath} HTTP/1.1\r\n"
        let hostHeader = "Host: ${host}\r\n"
        let connectionHeader = "Connection: close\r\n"

        var httpReq = StringBuilder()
        httpReq.append(requestLine)
        httpReq.append(hostHeader)
        httpReq.append(connectionHeader)

        // 添加自定义 headers
        request.headers.forEach({ name, value =>
            httpReq.append("${name}: ${value}\r\n")
        })

        // 添加 body (如果有)
        match (request.body) {
            case Some(b) => {
                let bodyBytes = b.arrayBuffer()
                httpReq.append("Content-Length: ${bodyBytes.size}\r\n")
                httpReq.append("\r\n")
                // 发送 headers
                let headerBytes = Utf8Codec.encode(httpReq.toString())
                sock.send(headerBytes)
                // 发送 body
                sock.send(bodyBytes)
            }
            case None => {
                httpReq.append("\r\n")
                let headerBytes = Utf8Codec.encode(httpReq.toString())
                sock.send(headerBytes)
            }
        }

        // 接收响应
        let recvBuf = Array<UInt8>(RECV_BUFFER_SIZE, item: UInt8(0))
        let totalData = ArrayList<UInt8>()
        var done = false
        while (!done) {
            let recvResult = sock.recv(recvBuf)
            match (recvResult) {
                case Ok(bytesRead) => {
                    if (bytesRead == 0) {
                        done = true
                    } else {
                        for (i in 0..bytesRead) {
                            totalData.append(recvBuf[Int64(i)])
                        }
                    }
                }
                case Err(_) => done = true
            }
        }

        sock.close()

        // 解析 HTTP 响应
        return parseHttpResponse(totalData.toArray())
    }

    /// 解析原始 HTTP 响应字节为 Response 对象
    /// 对应 Bun: src/api/fetch.zig HTTP 响应解析
    private static func parseHttpResponse(data: Array<UInt8>): Response {
        let text = Utf8Codec.decode(data)
        let resp = Response()

        // 查找 header 与 body 的分隔符 \r\n\r\n
        let headerEndIdx = text.indexOf("\r\n\r\n")
        if (headerEndIdx < 0) {
            resp.status = 0
            resp.statusText = "Invalid HTTP response"
            resp.ok = false
            return resp
        }

        let headerSection = text.substring(0, headerEndIdx)
        let bodyStart = headerEndIdx + 4

        // 解析状态行: HTTP/1.1 200 OK
        let lines = headerSection.split("\r\n")
        if (lines.size > 0) {
            let statusLine = lines[0]
            let statusParts = statusLine.split(" ")
            if (statusParts.size >= 2) {
                try {
                    resp.status = Int64.parse(statusParts[1])
                } catch (_: Exception) {
                    resp.status = 0
                }
                resp.ok = resp.status >= 200 && resp.status <= 299
                // 状态文本: 取状态码之后的部分
                if (statusParts.size >= 3) {
                    let sb = StringBuilder()
                    for (i in 2..statusParts.size) {
                        if (i > 2) { sb.append(" ") }
                        sb.append(statusParts[Int64(i)])
                    }
                    resp.statusText = sb.toString()
                }
            }
        }

        // 解析响应头
        for (i in 1..lines.size) {
            let line = lines[Int64(i)]
            let colonIdx = line.indexOf(":")
            if (colonIdx >= 0) {
                let name = line.substring(0, colonIdx).trim()
                let value = line.substring(colonIdx + 1).trim()
                resp.headers.append(name, value)
            }
        }

        // 提取 body
        if (bodyStart < text.length) {
            let bodyText = text.substring(bodyStart)
            let bodyBytes = Utf8Codec.encode(bodyText)
            resp.body = Some(Body(bodyBytes))
        }

        return resp
    }
}

// ============================================================================
// Fetch 函数 — 全局 fetch() API
// 对应 Bun: src/api/fetch.zig fetch
// ============================================================================

/// fetch(url) — 发送 HTTP GET 请求
/// 对应 Web API: globalThis.fetch(url)
/// 对应 Bun: src/api/fetch.zig fetch
public func fetch(url: String): Response {
    let request = Request(url)
    return fetchWithRequest(request)
}

/// fetch(url, init) — 发送 HTTP 请求
/// 对应 Web API: globalThis.fetch(url, init)
public func fetch(url: String, init: RequestInit): Response {
    let request = Request(url, init)
    return fetchWithRequest(request)
}

/// 内部 fetch 实现
/// 对应 Bun: src/api/fetch.zig fetchImpl
private func fetchWithRequest(request: Request): Response {
    // 检查 abort signal
    match (request.signal) {
        case Some(signal) => {
            if (signal.aborted) {
                let errResp = Response()
                errResp.status = 0
                errResp.statusText = "Aborted"
                errResp.ok = false
                return errResp
            }
        }
        case None => ()
    }

    // 解析 URL
    let parsedUrl = BaoUrl(request.url)

    // 只支持 http 协议
    if (parsedUrl.protocol != "http:" && parsedUrl.protocol != "https:") {
        let errResp = Response()
        errResp.status = 0
        errResp.statusText = "Unsupported protocol: ${parsedUrl.protocol}"
        errResp.ok = false
        return errResp
    }

    // 发送请求
    var response = HttpClient.sendRequest(parsedUrl, request)
    response.url = request.url

    // 处理重定向
    var redirectCount = 0
    let maxRedirects = 20
    while (response.status >= 300 && response.status < 400 && redirectCount < maxRedirects) {
        match (request.redirect) {
            case RequestRedirect.Error => {
                let errResp = Response()
                errResp.status = 0
                errResp.statusText = "Redirect encountered"
                errResp.ok = false
                return errResp
            }
            case RequestRedirect.Manual => {
                return response
            }
            case RequestRedirect.Follow => {
                // 获取 Location 头
                let location = response.headers.get("location")
                match (location) {
                    case Some(loc) => {
                        redirectCount++
                        response.redirected = true
                        let redirectUrl = if (loc.startsWith("http://") || loc.startsWith("https://")) {
                            loc
                        } else {
                            // 相对路径: 拼接
                            parsedUrl.protocol + "//" + parsedUrl.hostname + loc
                        }
                        let redirectRequest = Request(redirectUrl)
                        response = HttpClient.sendRequest(BaoUrl(redirectUrl), redirectRequest)
                        response.url = redirectUrl
                    }
                    case None => return response
                }
            }
        }
    }

    return response
}

// ============================================================================
// FetchModule — fetch 模块导出
// ============================================================================

/// Fetch 模块导出 — 将 fetch/Request/Response/Headers 注册到全局
public class FetchModule {
    /// 将 fetch 相关 API 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        // fetch 函数
        env.define("fetch", Interpreter.makeNativeFn("fetch") { args =>
            if (args.size < 1) { return JsValue.NULL }
            let url = Interpreter.jsToString(args[0])

            let response = if (args.size >= 2) {
                // 简化: 第二个参数为 init 对象
                let init = RequestInit()
                match (args[1].objectData) {
                    case Some(obj) => {
                        // method
                        let method = obj.get("method")
                        if (method.valueType == JsValueType.String) {
                            init.method = method.stringValue.toString()
                        }
                    }
                    case None => ()
                }
                fetch(url, init)
            } else {
                fetch(url)
            }
            return response.toJsValue()
        }, false)

        // Request 构造函数
        env.define("Request", Interpreter.makeNativeFn("Request") { args =>
            if (args.size >= 1) {
                let url = Interpreter.jsToString(args[0])
                let req = Request(url)
                return req.toJsValue()
            }
            return JsValue.NULL
        }, false)

        // Response 构造函数
        env.define("Response", Interpreter.makeNativeFn("Response") { args =>
            let resp = Response()
            return resp.toJsValue()
        }, false)

        // Headers 构造函数
        env.define("Headers", Interpreter.makeNativeFn("Headers") { args =>
            let headers = Headers()
            if (args.size >= 1) {
                match (args[0].objectData) {
                    case Some(obj) => {
                        for (key in obj.keys()) {
                            let val = obj.get(key)
                            headers.set(key, val.toString())
                        }
                    }
                    case None => ()
                }
            }
            return headers.toJsValue()
        }, false)
    }
}
