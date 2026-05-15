// Request - HTTP 请求对象
// 对应 Bun: src/runtime/webcore/Request.zig
// 严格翻译自: src/runtime/webcore/Request.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// HttpMethod - HTTP 方法
// 对应 Bun: Method (src/http_types/Method.zig)
// ============================================================================

/// HTTP 请求方法
/// 对应 Bun: Method
public enum HttpMethod {
    | GET
    | HEAD
    | POST
    | PUT
    | DELETE
    | PATCH
    | OPTIONS
    | TRACE
    | CONNECT

    public func toString(): String {
        match (this) {
            case GET => "GET"
            case HEAD => "HEAD"
            case POST => "POST"
            case PUT => "PUT"
            case DELETE => "DELETE"
            case PATCH => "PATCH"
            case OPTIONS => "OPTIONS"
            case TRACE => "TRACE"
            case CONNECT => "CONNECT"
        }
    }

    /// 从字符串解析 HTTP 方法
    public static func fromString(method: String): HttpMethod {
        let upper = method.toUpperCase()
        if (upper == "GET") { return HttpMethod.GET }
        if (upper == "HEAD") { return HttpMethod.HEAD }
        if (upper == "POST") { return HttpMethod.POST }
        if (upper == "PUT") { return HttpMethod.PUT }
        if (upper == "DELETE") { return HttpMethod.DELETE }
        if (upper == "PATCH") { return HttpMethod.PATCH }
        if (upper == "OPTIONS") { return HttpMethod.OPTIONS }
        if (upper == "TRACE") { return HttpMethod.TRACE }
        if (upper == "CONNECT") { return HttpMethod.CONNECT }
        return HttpMethod.GET
    }
}

// ============================================================================
// RequestRedirect - 重定向模式
// 对应 Bun: FetchRedirect
// ============================================================================

/// HTTP 重定向策略
/// 对应 Bun: FetchRedirect
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

    /// 从字符串解析
    public static func fromString(value: String): ?RequestRedirect {
        let lower = value.toLowerCase()
        if (lower == "follow") { return Some(RequestRedirect.Follow) }
        if (lower == "error") { return Some(RequestRedirect.Error) }
        if (lower == "manual") { return Some(RequestRedirect.Manual) }
        return None
    }
}

// ============================================================================
// RequestCacheMode - 缓存模式
// 对应 Bun: FetchCacheMode
// ============================================================================

/// 请求缓存模式
/// 对应 Bun: FetchCacheMode
public enum RequestCacheMode {
    | Default
    | NoStore
    | Reload
    | NoCache
    | ForceCache
    | OnlyIfCached

    public func toString(): String {
        match (this) {
            case Default => "default"
            case NoStore => "no-store"
            case Reload => "reload"
            case NoCache => "no-cache"
            case ForceCache => "force-cache"
            case OnlyIfCached => "only-if-cached"
        }
    }
}

// ============================================================================
// RequestMode - 请求模式
// 对应 Bun: FetchRequestMode
// ============================================================================

/// 请求模式
/// 对应 Bun: FetchRequestMode
public enum RequestMode {
    | Cors
    | NoCors
    | SameOrigin
    | Navigate

    public func toString(): String {
        match (this) {
            case Cors => "cors"
            case NoCors => "no-cors"
            case SameOrigin => "same-origin"
            case Navigate => "navigate"
        }
    }
}

// ============================================================================
// RequestFlags - 请求标志位
// 对应 Bun: Request.Flags
// ============================================================================

/// 请求标志位
/// 对应 Bun: Request.Flags (packed struct)
public class RequestFlags {
    /// 重定向策略
    public var redirect: RequestRedirect
    /// 缓存模式
    public var cache: RequestCacheMode
    /// 请求模式
    public var mode: RequestMode
    /// 是否为 HTTPS
    public var https: Bool

    public init() {
        redirect = RequestRedirect.Follow
        cache = RequestCacheMode.Default
        mode = RequestMode.Cors
        https = false
    }
}

// ============================================================================
// RequestInit - Request 构造参数
// 对应 Bun: RequestInit / Response.Init
// ============================================================================

/// Request 初始化参数
/// 对应 Bun: RequestInit
public class RequestInit {
    /// HTTP 方法
    public var method: String
    /// 请求头
    public var headers: Headers
    /// 请求体
    public var body: ?Body
    /// 重定向策略
    public var redirect: RequestRedirect
    /// 缓存模式
    public var cache: RequestCacheMode
    /// 请求模式
    public var mode: RequestMode
    /// AbortSignal
    public var signal: ?AbortSignal

    public init() {
        method = "GET"
        headers = Headers()
        body = None
        redirect = RequestRedirect.Follow
        cache = RequestCacheMode.Default
        mode = RequestMode.Cors
        signal = None
    }
}

// ============================================================================
// Request - HTTP 请求
// 对应 Bun: src/runtime/webcore/Request.zig Request
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Request
// ============================================================================

/// HTTP Request — 对应 Web Request API
/// 对应 Bun: src/runtime/webcore/Request.zig Request
public class Request {
    /// 请求 URL
    /// 对应 Bun: Request.url
    public var url: String
    /// HTTP 方法
    /// 对应 Bun: Request.method
    public var method: HttpMethod
    /// 请求头
    /// 对应 Bun: Request.#headers
    public var headers: Headers
    /// 请求体
    /// 对应 Bun: Request.#body
    public var body: Body
    /// 请求标志
    /// 对应 Bun: Request.flags
    public var flags: RequestFlags
    /// Abort 信号
    /// 对应 Bun: Request.signal
    public var signal: ?AbortSignal
    /// 已报告的估算大小
    /// 对应 Bun: Request.reported_estimated_size
    public var reportedEstimatedSize: Int64

    public init() {
        url = ""
        method = HttpMethod.GET
        headers = Headers()
        body = Body()
        flags = RequestFlags()
        signal = None
        reportedEstimatedSize = 0
    }

    public init(url: String) {
        this.url = url
        method = HttpMethod.GET
        headers = Headers()
        body = Body()
        flags = RequestFlags()
        signal = None
        reportedEstimatedSize = 0
    }

    public init(url: String, init: RequestInit) {
        this.url = url
        method = HttpMethod.fromString(init.method)
        headers = init.headers
        body = match (init.body) {
            case Some(b) => b
            case None => Body()
        }
        flags = RequestFlags()
        flags.redirect = init.redirect
        flags.cache = init.cache
        flags.mode = init.mode
        signal = init.signal
        reportedEstimatedSize = 0
    }

    /// 获取 Content-Type
    /// 对应 Bun: Request.getContentType()
    public func getContentType(): ?String {
        // 从 headers 中查找
        let ct = headers.get("content-type")
        match (ct) {
            case Some(v) => return Some(v)
            case None => ()
        }
        // 从 body 中获取
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

    /// 获取 MIME 类型
    /// 对应 Bun: Request.mimeType()
    public func mimeType(): String {
        let ct = getContentType()
        match (ct) {
            case Some(v) => return v
            case None => ()
        }
        match (body.value.tag) {
            case BodyValueTag.Blob => {
                match (body.value.blob) {
                    case Some(b) => {
                        if (b.contentType.length > 0) {
                            return b.contentType
                        }
                    }
                    case None => ()
                }
            }
            case BodyValueTag.WTFStringImpl => return "text/plain"
            case _ => ()
        }
        return "application/octet-stream"
    }

    /// 解析响应体为 JSON
    /// 对应 Web API: request.json()
    public func json(): JsValue {
        return body.json()
    }

    /// 解析响应体为文本
    /// 对应 Web API: request.text()
    public func text(): String {
        return body.text()
    }

    /// 获取响应体的原始字节数组
    /// 对应 Web API: request.arrayBuffer()
    public func arrayBuffer(): Array<UInt8> {
        return body.arrayBuffer()
    }

    /// 获取协议 (http:// 或 https://)
    /// 对应 Bun: Request.getProtocol()
    public func getProtocol(): String {
        if (flags.https) { return "https://" }
        return "http://"
    }

    /// 获取重定向策略
    /// 对应 Bun: Request.getRedirect()
    public func getRedirect(): RequestRedirect {
        return flags.redirect
    }

    /// 获取缓存模式
    /// 对应 Bun: Request.getCache()
    public func getCache(): RequestCacheMode {
        return flags.cache
    }

    /// 获取请求模式
    /// 对应 Bun: Request.getMode()
    public func getMode(): RequestMode {
        return flags.mode
    }

    /// 计算估算字节大小
    /// 对应 Bun: Request.calculateEstimatedByteSize()
    public func calculateEstimatedByteSize(): Unit {
        reportedEstimatedSize = body.value.size() + url.length
    }

    /// 是否有 FetchHeaders
    /// 对应 Bun: Request.hasFetchHeaders()
    public func hasFetchHeaders(): Bool {
        return true  // 在 bao 中 headers 始终存在
    }

    /// 克隆请求
    /// 对应 Bun: Request.clone()
    public func clone(): Request {
        let req = Request()
        req.url = url
        req.method = method
        req.headers = Headers()
        // 克隆 headers
        for ((key, val) in headers.entries()) {
            req.headers.append(key, val)
        }
        // 克隆 body
        req.body = body.clone()
        req.flags = RequestFlags()
        req.flags.redirect = flags.redirect
        req.flags.cache = flags.cache
        req.flags.mode = flags.mode
        req.flags.https = flags.https
        return req
    }

    /// 从另一个 Request 克隆到目标
    /// 对应 Bun: Request.cloneInto()
    public func cloneInto(target: Request): Unit {
        target.url = url
        target.method = method
        target.flags.redirect = flags.redirect
        target.flags.cache = flags.cache
        target.flags.mode = flags.mode
        target.flags.https = flags.https
        target.body = body.clone()
        // 克隆 headers
        target.headers = Headers()
        for ((key, val) in headers.entries()) {
            target.headers.append(key, val)
        }
    }

    /// 释放资源
    /// 对应 Bun: Request.finalize()
    public func finalize(): Unit {
        body.deinit()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("url", JsValue(BaoString(url)))
        obj.set("method", JsValue(BaoString(method.toString())))
        obj.set("headers", headers.toJsValue())
        obj.set("redirect", JsValue(BaoString(flags.redirect.toString())))
        obj.set("cache", JsValue(BaoString(flags.cache.toString())))
        obj.set("mode", JsValue(BaoString(flags.mode.toString())))

        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            json()
        }))

        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(text()))
        }))

        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            let bytes = arrayBuffer()
            let arr = ArrayList<JsValue>()
            for (b in bytes) {
                arr.append(JsValue(Float64(Int64(b))))
            }
            JsValue.array(arr)
        }))

        obj.set("clone", JsValue.nativeFunction(JsNativeFunction("clone") { _ =>
            clone().toJsValue()
        }))

        return JsValue(obj)
    }
}
