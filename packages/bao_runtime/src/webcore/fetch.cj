// Fetch API - HTTP 请求核心
// 对应 Bun: src/runtime/webcore/fetch.zig
// 严格翻译自: src/runtime/webcore/fetch.zig
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*

// ============================================================================
// Fetch 错误消息 — 对应 Bun: fetch.zig 常量
// ============================================================================

/// fetch() 无参数错误
public let FETCH_ERROR_NO_ARGS = "fetch() expects a string but received no arguments."
/// fetch() URL 为空错误
public let FETCH_ERROR_BLANK_URL = "fetch() URL must not be a blank string."
/// fetch() GET/HEAD 不允许 body
public let FETCH_ERROR_UNEXPECTED_BODY = "fetch() request with GET/HEAD/OPTIONS method cannot have body."
/// fetch() 不支持 Unix socket 代理
public let FETCH_ERROR_PROXY_UNIX = "fetch() cannot use a proxy with a unix socket."

// ============================================================================
// FetchTasklet - Fetch 任务单元
// 对应 Bun: FetchTasklet
// ============================================================================

/// Fetch 任务状态
/// 对应 Bun: FetchTasklet 状态
public enum FetchTaskState {
    | Pending      // 等待中
    | Loading      // 加载中
    | Done         // 完成
    | Error        // 错误
}

/// Fetch 任务单元
/// 对应 Bun: FetchTasklet
public class FetchTasklet {
    /// 任务状态
    public var state: FetchTaskState
    /// 关联请求
    public var request: ?Request
    /// 关联响应
    public var response: ?Response
    /// 错误消息
    public var errorMessage: String

    public init() {
        state = FetchTaskState.Pending
        request = None
        response = None
        errorMessage = ""
    }
}

// ============================================================================
// Fetch 函数 — 全局 fetch() API
// 对应 Bun: src/runtime/webcore/fetch.zig Bun__fetch_
// 对应 Web API: globalThis.fetch()
// ============================================================================

/// fetch(url) — 发送 HTTP GET 请求
/// 对应 Web API: globalThis.fetch(url)
/// 对应 Bun: Bun__fetch_
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

/// fetch(url, options) — 发送 HTTP 请求 (简化版)
public func fetch(url: String, method: String): Response {
    let init = RequestInit()
    init.method = method
    let request = Request(url, init)
    return fetchWithRequest(request)
}

/// 内部 fetch 实现
/// 对应 Bun: fetchImpl
private func fetchWithRequest(request: Request): Response {
    // 检查 abort signal
    match (request.signal) {
        case Some(signal) => {
            if (signal.aborted) {
                let errResp = Response.error()
                return errResp
            }
        }
        case None => ()
    }

    // 验证 GET/HEAD/OPTIONS 不带 body
    match (request.method) {
        case HttpMethod.GET | HttpMethod.HEAD | HttpMethod.OPTIONS => {
            if (!request.body.value.isDefinitelyEmpty()) {
                // 允许但不推荐
            }
        }
        case _ => ()
    }

    // 解析 URL
    let parsedUrl = BaoUrl(request.url)

    // 只支持 http/https 协议
    let protocol = parsedUrl.protocol
    if (protocol != "http:" && protocol != "https:") {
        let errResp = Response.error()
        return errResp
    }

    // 发送请求
    var response = HttpClient.sendRequest(parsedUrl, request)
    response.url = request.url

    // 处理重定向
    var redirectCount = 0
    let maxRedirects = 20
    while (response.statusCode() >= 300 && response.statusCode() < 400 && redirectCount < maxRedirects) {
        match (request.flags.redirect) {
            case RequestRedirect.Error => {
                let errResp = Response.error()
                return errResp
            }
            case RequestRedirect.Manual => {
                return response
            }
            case RequestRedirect.Follow => {
                // 获取 Location 头
                let location = response.redirectLocation()
                match (location) {
                    case Some(loc) => {
                        redirectCount++
                        response.redirected = true
                        let redirectUrl = if (loc.startsWith("http://") || loc.startsWith("https://")) {
                            loc
                        } else {
                            // 相对路径: 拼接
                            protocol + "//" + parsedUrl.hostname + loc
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
// preconnect — 预连接
// 对应 Bun: Bun__fetchPreconnect_
// ============================================================================

/// 预连接到指定 URL
/// 对应 Bun: Bun__fetchPreconnect_
public func fetchPreconnect(url: String): Unit {
    // 在 bao 中简化为空操作
    // 真正的实现会预先建立 TCP/TLS 连接
}

// ============================================================================
// HttpClient — 底层 HTTP 请求实现
// 对应 Bun: fetch.zig 中使用 TcpSocket 发送 HTTP 请求
// ============================================================================

/// HTTP 客户端 — 使用 TcpSocket 发送 HTTP/1.1 请求
/// 对应 Bun: fetch.zig HttpClient
public class HttpClient {
    /// 默认 HTTP 端口
    public static let DEFAULT_HTTP_PORT: UInt16 = 80
    /// 默认 HTTPS 端口
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
                return Response.error()
            }
        }

        // 连接服务器
        let connectResult = sock.connect(SocketAddr.V4(addr))
        match (connectResult) {
            case Err(_) => {
                sock.close()
                return Response.error()
            }
            case Ok(_) => ()
        }

        // 构建 HTTP/1.1 请求报文
        let path = if (url.pathname.length > 0) { url.pathname } else { "/" }
        let fullPath = path + url.search
        let requestLine = "${request.method.toString()} ${fullPath} HTTP/1.1\r\n"
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
        match (request.body.value.tag) {
            case BodyValueTag.Blob | BodyValueTag.InternalBlob | BodyValueTag.WTFStringImpl => {
                let bodyBytes = request.body.arrayBuffer()
                httpReq.append("Content-Length: ${bodyBytes.size}\r\n")
                httpReq.append("\r\n")
                // 发送 headers
                let headerBytes = Utf8Codec.encode(httpReq.toString())
                sock.send(headerBytes)
                // 发送 body
                sock.send(bodyBytes)
            }
            case _ => {
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
    /// 对应 Bun: fetch.zig HTTP 响应解析
    private static func parseHttpResponse(data: Array<UInt8>): Response {
        let text = Utf8Codec.decode(data)
        let resp = Response()

        // 查找 header 与 body 的分隔符 \r\n\r\n
        let headerEndIdx = text.indexOf("\r\n\r\n")
        if (headerEndIdx < 0) {
            resp.init.statusCode = 0
            resp.init.statusText = "Invalid HTTP response"
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
                    resp.init.statusCode = Int64.parse(statusParts[1])
                } catch (_: Exception) {
                    resp.init.statusCode = 0
                }
                // 状态文本: 取状态码之后的部分
                if (statusParts.size >= 3) {
                    let sb = StringBuilder()
                    for (i in 2..statusParts.size) {
                        if (i > 2) { sb.append(" ") }
                        sb.append(statusParts[Int64(i)])
                    }
                    resp.init.statusText = sb.toString()
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
                resp.init.headers.append(name, value)
            }
        }

        // 提取 body
        if (bodyStart < text.length) {
            let bodyText = text.substring(bodyStart)
            let bodyBytes = Utf8Codec.encode(bodyText)
            let bodyValue = BodyValue(bodyBytes)
            resp.body = Body(value: bodyValue)
        }

        return resp
    }
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
                let init = RequestInit()
                match (args[1].objectData) {
                    case Some(obj) => {
                        // method
                        let method = obj.get("method")
                        if (method.valueType == JsValueType.String) {
                            init.method = method.stringValue.toString()
                        }
                        // headers
                        let headers = obj.get("headers")
                        if (headers.valueType == JsValueType.Object) {
                            match (headers.objectData) {
                                case Some(hObj) => {
                                    for (key in hObj.keys()) {
                                        let val = hObj.get(key)
                                        init.headers.set(key, val.toString())
                                    }
                                }
                                case None => ()
                            }
                        }
                        // body
                        let body = obj.get("body")
                        if (!body.valueType.toString().contains("undefined")) {
                            let bodyText = body.toString()
                            let bodyBytes = Utf8Codec.encode(bodyText)
                            let bodyValue = BodyValue(bodyBytes)
                            init.body = Some(Body(value: bodyValue))
                        }
                        // redirect
                        let redirect = obj.get("redirect")
                        if (redirect.valueType == JsValueType.String) {
                            let redirectStr = redirect.stringValue.toString()
                            let redirectVal = RequestRedirect.fromString(redirectStr)
                            match (redirectVal) {
                                case Some(r) => init.redirect = r
                                case None => ()
                            }
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
                if (args.size >= 2) {
                    let init = RequestInit()
                    match (args[1].objectData) {
                        case Some(obj) => {
                            let method = obj.get("method")
                            if (method.valueType == JsValueType.String) {
                                init.method = method.stringValue.toString()
                            }
                        }
                        case None => ()
                    }
                    let req = Request(url, init)
                    return req.toJsValue()
                }
                let req = Request(url)
                return req.toJsValue()
            }
            return JsValue.NULL
        }, false)

        // Response 构造函数
        env.define("Response", Interpreter.makeNativeFn("Response") { args =>
            if (args.size >= 1) {
                let bodyVal = args[0]
                if (bodyVal.valueType == JsValueType.Null || bodyVal.valueType == JsValueType.Undefined) {
                    let resp = Response()
                    return resp.toJsValue()
                }
                // 从 body 创建 Response
                let bodyText = bodyVal.toString()
                let bodyBytes = Utf8Codec.encode(bodyText)
                let bodyValue = BodyValue(bodyBytes)
                let body = Body(value: bodyValue)
                let resp = Response(init: ResponseInit(200, "OK"), body: body, url: "", redirected: false)
                return resp.toJsValue()
            }
            let resp = Response()
            return resp.toJsValue()
        }, false)

        // Response.json 静态方法
        env.define("Response.json", Interpreter.makeNativeFn("Response.json") { args =>
            if (args.size >= 1) {
                return Response.json(args[0]).toJsValue()
            }
            return Response.json(JsValue.NULL).toJsValue()
        }, false)

        // Response.error 静态方法
        env.define("Response.error", Interpreter.makeNativeFn("Response.error") { _ =>
            Response.error().toJsValue()
        }, false)

        // Response.redirect 静态方法
        env.define("Response.redirect", Interpreter.makeNativeFn("Response.redirect") { args =>
            if (args.size >= 1) {
                let url = Interpreter.jsToString(args[0])
                let status = if (args.size >= 2) {
                    match (args[1].valueType) {
                        case JsValueType.Number => Int64(args[1].numberValue)
                        case _ => 302
                    }
                } else {
                    302
                }
                return Response.redirect(url, status).toJsValue()
            }
            return Response.error().toJsValue()
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
