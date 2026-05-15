// Response - HTTP 响应对象
// 对应 Bun: src/runtime/webcore/Response.zig
// 严格翻译自: src/runtime/webcore/Response.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// ResponseInit - Response 初始化参数
// 对应 Bun: Response.Init
// ============================================================================

/// Response 初始化参数
/// 对应 Bun: Response.Init
public class ResponseInit {
    /// 响应头
    public var headers: Headers
    /// 状态码
    public var statusCode: Int64
    /// 状态文本
    public var statusText: String
    /// HTTP 方法
    public var method: HttpMethod

    public init() {
        headers = Headers()
        statusCode = 200
        statusText = "OK"
        method = HttpMethod.GET
    }

    public init(statusCode: Int64) {
        headers = Headers()
        this.statusCode = statusCode
        statusText = statusCodeToText(statusCode)
        method = HttpMethod.GET
    }

    public init(statusCode: Int64, statusText: String) {
        headers = Headers()
        this.statusCode = statusCode
        this.statusText = statusText
        method = HttpMethod.GET
    }

    public init(statusCode: Int64, statusText: String, headers: Headers) {
        this.headers = headers
        this.statusCode = statusCode
        this.statusText = statusText
        method = HttpMethod.GET
    }

    /// 克隆
    /// 对应 Bun: Response.Init.clone()
    public func clone(): ResponseInit {
        let cloned = ResponseInit(statusCode, statusText)
        // 克隆 headers
        for ((key, val) in headers.entries()) {
            cloned.headers.append(key, val)
        }
        cloned.method = method
        return cloned
    }

    /// 释放资源
    /// 对应 Bun: Response.Init.deinit()
    public func deinit(): Unit {
        // 释放 headers 资源
    }

    /// 根据 HTTP 状态码获取默认文本
    public static func statusCodeToText(code: Int64): String {
        match (code) {
            case 100 => "Continue"
            case 101 => "Switching Protocols"
            case 200 => "OK"
            case 201 => "Created"
            case 202 => "Accepted"
            case 204 => "No Content"
            case 206 => "Partial Content"
            case 301 => "Moved Permanently"
            case 302 => "Found"
            case 303 => "See Other"
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
            case 415 => "Unsupported Media Type"
            case 418 => "I'm a Teapot"
            case 429 => "Too Many Requests"
            case 500 => "Internal Server Error"
            case 501 => "Not Implemented"
            case 502 => "Bad Gateway"
            case 503 => "Service Unavailable"
            case 504 => "Gateway Timeout"
            case _ => ""
        }
    }
}

// ============================================================================
// Response - HTTP 响应
// 对应 Bun: src/runtime/webcore/Response.zig Response
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Response
// ============================================================================

/// HTTP Response — 对应 Web Response API
/// 对应 Bun: src/runtime/webcore/Response.zig Response
public class Response {
    /// 响应体
    /// 对应 Bun: Response.#body
    public var body: Body
    /// 初始化参数
    /// 对应 Bun: Response.#init
    public var init: ResponseInit
    /// 响应 URL
    /// 对应 Bun: Response.#url
    public var url: String
    /// 是否经过重定向
    /// 对应 Bun: Response.#redirected
    public var redirected: Bool
    /// 引用计数
    /// 对应 Bun: Response.ref_count
    public var refCount: Int64
    /// 已报告的估算大小
    /// 对应 Bun: Response.#reported_estimated_size
    public var reportedEstimatedSize: Int64

    public init() {
        body = Body()
        init = ResponseInit()
        url = ""
        redirected = false
        refCount = 1
        reportedEstimatedSize = 0
    }

    public init(init: ResponseInit, body: Body, url: String, redirected: Bool) {
        this.body = body
        this.init = init
        this.url = url
        this.redirected = redirected
        refCount = 1
        reportedEstimatedSize = 0
    }

    /// 获取状态码
    /// 对应 Web API: response.status
    /// 对应 Bun: Response.statusCode()
    public func statusCode(): Int64 {
        return init.statusCode
    }

    /// 获取状态文本
    /// 对应 Web API: response.statusText
    /// 对应 Bun: Response.getStatusText()
    public func statusText(): String {
        return init.statusText
    }

    /// 状态码是否在 200-299 范围
    /// 对应 Web API: response.ok
    /// 对应 Bun: Response.isOK()
    public func isOK(): Bool {
        return init.statusCode >= 200 && init.statusCode <= 299
    }

    /// 获取响应头
    /// 对应 Web API: response.headers
    /// 对应 Bun: Response.getHeaders()
    public func getHeaders(): Headers {
        return init.headers
    }

    /// 获取响应类型
    /// 对应 Web API: response.type
    /// 对应 Bun: Response.getResponseType()
    public func getResponseType(): String {
        if (init.statusCode < 200) {
            return "error"
        }
        return "default"
    }

    /// 获取重定向位置
    /// 对应 Bun: Response.redirectLocation()
    public func redirectLocation(): ?String {
        return init.headers.get("location")
    }

    /// 获取指定响应头
    /// 对应 Bun: Response.header()
    public func header(name: String): ?String {
        return init.headers.get(name.toLowerCase())
    }

    /// 获取 Content-Type
    /// 对应 Bun: Response.getContentType()
    public func getContentType(): ?String {
        let ct = init.headers.get("content-type")
        match (ct) {
            case Some(v) => return Some(v)
            case None => ()
        }
        if (body.value.tag == BodyValueTag.Blob) {
            match (body.value.blob) {
                case Some(b) => {
                    if (b.contentType.length > 0) {
                        return Some(b.contentType)
                    }
                }
                case None => ()
            }
        }
        return None
    }

    /// 获取 Body 值
    /// 对应 Bun: Response.getBodyValue()
    public func getBodyValue(): BodyValue {
        return body.value
    }

    /// 获取 Body 长度
    /// 对应 Bun: Response.getBodyLen()
    public func getBodyLen(): Int64 {
        return body.len()
    }

    /// 获取方法
    /// 对应 Bun: Response.getMethod()
    public func getMethod(): HttpMethod {
        return init.method
    }

    /// 设置大小提示
    /// 对应 Bun: Response.setSizeHint()
    public func setSizeHint(sizeHint: BlobSizeType): Unit {
        if (body.value.tag == BodyValueTag.Locked) {
            match (body.value.locked) {
                case Some(p) => p.sizeHint = sizeHint
                case None => ()
            }
        }
    }

    /// 克隆响应
    /// 对应 Web API: response.clone()
    /// 对应 Bun: Response.clone()
    public func clone(): Response {
        let clonedBody = body.clone()
        let clonedInit = init.clone()
        let response = Response(init: clonedInit, body: clonedBody, url: url, redirected: redirected)
        return response
    }

    /// 增加引用
    /// 对应 Bun: Response.ref()
    public func ref(): Response {
        refCount += 1
        return this
    }

    /// 减少引用
    /// 对应 Bun: Response.unref()
    public func unref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            destroy()
        }
    }

    /// 释放资源
    /// 对应 Bun: Response.destroy()
    public func destroy(): Unit {
        init.deinit()
        body.deinit()
    }

    /// 计算估算字节大小
    /// 对应 Bun: Response.calculateEstimatedByteSize()
    public func calculateEstimatedByteSize(): Unit {
        reportedEstimatedSize = body.value.size() + url.length + init.statusText.length
    }

    // ========================================================================
    // Body Mixin 方法 — 对应 Bun: ResponseMixin (BodyMixin(Response))
    // ========================================================================

    /// 解析响应体为文本
    /// 对应 Web API: response.text()
    public func text(): String {
        return body.text()
    }

    /// 解析响应体为 JSON
    /// 对应 Web API: response.json()
    public func json(): JsValue {
        return body.json()
    }

    /// 获取响应体 ArrayBuffer
    /// 对应 Web API: response.arrayBuffer()
    public func arrayBuffer(): Array<UInt8> {
        return body.arrayBuffer()
    }

    /// 获取响应体 Blob
    /// 对应 Web API: response.blob()
    public func blob(): Blob {
        return body.use()
    }

    /// 获取响应体 FormData
    /// 对应 Web API: response.formData()
    public func formData(): FormData {
        return FormData()
    }

    // ========================================================================
    // 静态工厂方法
    // ========================================================================

    /// 静态工厂: 从 JSON 数据创建 Response
    /// 对应 Web API: Response.json(data)
    /// 对应 Bun: Response.constructJSON()
    public static func json(data: JsValue): Response {
        let jsonStr = data.toString()
        let bytes = Utf8Codec.encode(jsonStr)
        let bodyValue = BodyValue(bytes)
        bodyValue.wasString = true
        let body = Body(value: bodyValue)
        let init = ResponseInit(200, "OK")
        init.headers.set("Content-Type", "application/json")
        return Response(init: init, body: body, url: "", redirected: false)
    }

    /// 静态工厂: 创建错误 Response
    /// 对应 Web API: Response.error()
    /// 对应 Bun: Response.constructError()
    public static func error(): Response {
        let init = ResponseInit()
        init.statusCode = 0
        init.statusText = ""
        return Response(init: init, body: Body(), url: "", redirected: false)
    }

    /// 静态工厂: 创建重定向 Response
    /// 对应 Web API: Response.redirect(url, status)
    /// 对应 Bun: Response.constructRedirect()
    public static func redirect(url: String, status: Int64): Response {
        let init = ResponseInit(status)
        init.headers.set("Location", url)
        return Response(init: init, body: Body(), url: "", redirected: true)
    }

    /// 创建 404 响应
    /// 对应 Bun: Response.@"404"()
    public static func notFound(): Response {
        return emptyWithStatus(404)
    }

    /// 创建 200 响应
    /// 对应 Bun: Response.@"200"()
    public static func ok(): Response {
        return emptyWithStatus(200)
    }

    /// 创建指定状态码的空响应
    /// 对应 Bun: Response.emptyWithStatus()
    public static func emptyWithStatus(status: Int64): Response {
        let init = ResponseInit(status)
        return Response(init: init, body: Body(), url: "", redirected: false)
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("status", JsValue(Float64(self.statusCode())))
        obj.set("statusText", JsValue(BaoString(self.statusText())))
        obj.set("url", JsValue(BaoString(self.url)))
        obj.set("redirected", JsValue(self.redirected))
        obj.set("ok", JsValue(self.isOK()))
        obj.set("type", JsValue(BaoString(self.getResponseType())))
        obj.set("headers", self.getHeaders().toJsValue())

        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(self.text()))
        }))

        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.json()
        }))

        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            let bytes = self.arrayBuffer()
            let arr = ArrayList<JsValue>()
            for (b in bytes) {
                arr.append(JsValue(Float64(Int64(b))))
            }
            JsValue.array(arr)
        }))

        obj.set("blob", JsValue.nativeFunction(JsNativeFunction("blob") { _ =>
            self.blob().toJsValue()
        }))

        obj.set("clone", JsValue.nativeFunction(JsNativeFunction("clone") { _ =>
            self.clone().toJsValue()
        }))

        return JsValue(obj)
    }
}
