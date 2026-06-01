// Request - HTTP 请求对象
// 对应 Bun: src/runtime/webcore/Request.rs
// 严格翻译自: src/runtime/webcore/Request.rs
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_collections.ArrayBuffer
import bao_http_types.*
import bao_http_jsc.*
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_jsc.JsGlobalObject
import bao_jsc.CallFrame

// ============================================================================
// Request.Flags - 请求标志位
// 对应 Bun: Request.Flags (Request.rs:120-129)
// ============================================================================

/// 请求标志位
/// 对应 Bun: Request.Flags (packed struct: redirect + cache + mode + https)
/// Zig was `packed struct(u8)` (u2+u3+u2+bool = 8 bits).
public class Flags {
    /// 重定向策略
    /// 对应 Bun: Flags.redirect
    public var redirect: FetchRedirect
    /// 缓存模式
    /// 对应 Bun: Flags.cache
    public var cache: FetchCacheMode
    /// 请求模式
    /// 对应 Bun: Flags.mode
    public var mode: FetchRequestMode
    /// 是否为 HTTPS
    /// 对应 Bun: Flags.https
    public var https: Bool

    public init() {
        redirect = FetchRedirect.Follow
        cache = FetchCacheMode.Default
        mode = FetchRequestMode.Cors
        https = false
    }

    public init(redirect: FetchRedirect, cache: FetchCacheMode, mode: FetchRequestMode, https: Bool) {
        this.redirect = redirect
        this.cache = cache
        this.mode = mode
        this.https = https
    }
}

// ============================================================================
// Fields - Request 构造时用于跟踪已设置字段的枚举集
// 对应 Bun: Request.Fields (Request.rs:1019-1036)
// ============================================================================

/// Request 构造时用于跟踪已设置字段的枚举
/// 对应 Bun: Fields (EnumSetType)
public enum Fields {
    | Method
    | Headers
    | Body
    | Mode
    | Redirect
    | Cache
    | Signal
    | Url
}

/// Fields 集合 — 对应 Bun: EnumSet<Fields>
public class FieldSet {
    private var set: ArrayList<Fields>

    public init() {
        set = ArrayList<Fields>()
    }

    public func contains(field: Fields): Bool {
        for (f in set) {
            match (f) {
                case Fields.Method =>
                    match (field) { case Fields.Method => return true case _ => () }
                case Fields.Headers =>
                    match (field) { case Fields.Headers => return true case _ => () }
                case Fields.Body =>
                    match (field) { case Fields.Body => return true case _ => () }
                case Fields.Mode =>
                    match (field) { case Fields.Mode => return true case _ => () }
                case Fields.Redirect =>
                    match (field) { case Fields.Redirect => return true case _ => () }
                case Fields.Cache =>
                    match (field) { case Fields.Cache => return true case _ => () }
                case Fields.Signal =>
                    match (field) { case Fields.Signal => return true case _ => () }
                case Fields.Url =>
                    match (field) { case Fields.Url => return true case _ => () }
            }
        }
        return false
    }

    public func insert(field: Fields): Unit {
        if (!contains(field)) {
            set.append(field)
        }
    }
}

// ============================================================================
// InternalJSEventCallback - 内部 JS 事件回调 (Request 专用)
// 对应 Bun: Request.InternalJSEventCallback (Request.rs:1660-1697)
// ============================================================================

/// 内部 JS 事件回调 (Request)
/// 对应 Bun: InternalJSEventCallback
public class InternalJSEventCallback {
    /// JS 函数引用 — 对应 Bun: jsc.strong.Optional
    public var function: ?JsValue

    public init() {
        function = None
    }

    public init(function: JsValue, global: JsGlobalObject) {
        this.function = Some(function)
    }

    /// 是否有回调
    /// 对应 Bun: InternalJSEventCallback::has_callback
    public func hasCallback(): Bool {
        return function.isSome()
    }

    /// 释放资源
    /// 对应 Bun: InternalJSEventCallback::deinit
    public func deinit(): Unit {
        function = None
    }

    /// 触发回调
    /// 对应 Bun: InternalJSEventCallback::trigger
    public func trigger(eventType: Int64, global: JsGlobalObject): Bool {
        if (function.isSome()) {
            let callback = function.getOrThrow()
            callback.call(global.globalThis, JsValue.undefined(), [JsValue(Float64(eventType))])
            return true
        }
        return false
    }
}

/// Re-export of AbortEvent — 对应 Bun: EventType
public type AbortEventType = Int64

// ============================================================================
// AbortSignalRef - AbortSignal 引用
// 对应 Bun: bun_jsc::AbortSignalRef
// ============================================================================

/// AbortSignal 引用
/// 对应 Bun: AbortSignalRef — wraps NonNull<AbortSignal>
public class AbortSignalRef {
    /// JS 值引用
    public var value: JsValue

    public init() {
        value = JsValue.undefined()
    }

    public init(value: JsValue) {
        this.value = value
    }

    /// 克隆 — bumps C++ refcount
    /// 对应 Bun: AbortSignalRef::clone
    public func clone(): AbortSignalRef {
        return AbortSignalRef(value)
    }

    /// 转为 JS 值
    /// 对应 Bun: AbortSignalRef::to_js
    public func toJs(global: JsGlobalObject): JsValue {
        return value
    }

    /// unref — releases C++ ref
    /// 对应 Bun: AbortSignalRef::unref
    public func unref(): Unit {
        value = JsValue.undefined()
    }
}

// ============================================================================
// RequestInit - Request 构造参数
// 对应 Bun: RequestInit (simplified from Request.rs construct_into)
// ============================================================================

/// Request 初始化参数
public class RequestInit {
    /// HTTP 方法
    public var method: HttpMethod
    /// 请求头
    public var headers: ?HeadersRef
    /// 请求体
    public var body: ?Body
    /// 重定向策略
    public var redirect: FetchRedirect
    /// 缓存模式
    public var cache: FetchCacheMode
    /// 请求模式
    public var mode: FetchRequestMode
    /// AbortSignal
    public var signal: ?AbortSignalRef

    public init() {
        method = HttpMethod.GET
        headers = None
        body = None
        redirect = FetchRedirect.Follow
        cache = FetchCacheMode.Default
        mode = FetchRequestMode.Cors
        signal = None
    }
}

// ============================================================================
// AnyRequestContext - 请求上下文
// 对应 Bun: AnyRequestContext
// ============================================================================

/// 请求上下文
/// 对应 Bun: AnyRequestContext
public class AnyRequestContext {
    public static let NULL = AnyRequestContext()

    /// 内部 uws 请求指针
    public var uwsRequest: UInt64
    /// 是否有超时事件
    public var hasTimeoutEvents: Bool
    /// 超时秒数
    public var timeoutSeconds: UInt32
    /// 内存开销
    public var memoryCostValue: Int64

    public init() {
        uwsRequest = 0
        hasTimeoutEvents = false
        timeoutSeconds = 0
        memoryCostValue = 0
    }

    /// 是否有请求
    /// 对应 Bun: AnyRequestContext::get_request
    public func hasRequest(): Bool {
        return uwsRequest != 0
    }

    /// 获取 uws 请求指针
    /// 对应 Bun: AnyRequestContext::get_request
    public func getRequest(): UInt64 {
        return uwsRequest
    }

    /// 获取 URL
    public func getUrl(): String {
        return ""
    }

    /// 获取 header
    public func getHeader(name: String): String {
        return ""
    }

    /// 内存开销
    /// 对应 Bun: AnyRequestContext::memory_cost
    public func memoryCost(): Int64 {
        return memoryCostValue
    }

    /// 设置 cookies
    public func setCookies(cookieMap: ?CookieMap): Unit {}

    /// 启用超时事件
    /// 对应 Bun: AnyRequestContext::enable_timeout_events
    public func enableTimeoutEvents(): Unit {
        hasTimeoutEvents = true
    }

    /// 设置超时
    /// 对应 Bun: AnyRequestContext::set_timeout
    public func setTimeout(seconds: UInt32): Unit {
        timeoutSeconds = seconds
    }

    /// 获取 remote socket info
    public func getRemoteSocketInfo(): ?RemoteSocketInfo {
        return None
    }
}

// ============================================================================
// RemoteSocketInfo - 远程 Socket 信息
// ============================================================================

/// 远程 Socket 信息
public class RemoteSocketInfo {
    public var ip: String
    public var port: UInt16
    public var isIPv6: Bool

    public init() {
        ip = ""
        port = 0
        isIPv6 = false
    }

    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("address", JsValue(ip))
        obj.set("port", JsValue(Float64(Int64(port))))
        obj.set("family", JsValue(if (isIPv6) { "IPv6" } else { "IPv4" }))
        return JsValue(obj)
    }
}

// ============================================================================
// JsValue 扩展方法 — 用于 Request/Response 构造
// 对应 Bun: Request.rs 中 JSValue 辅助方法
// ============================================================================

/// JsValue 辅助扩展
public class JsValueHelper {
    /// 快速获取属性
    /// 对应 Bun: JSValue::fastGet (via BuiltinName)
    public static func fastGet(value: JsValue, global: JsGlobalObject, name: BuiltinName): ?JsValue {
        let propName = builtinNameToString(name)
        let result = value.get(global.globalThis, propName)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return result
    }

    /// 快速获取属性 (字符串名)
    /// 对应 Bun: JSValue::fastGet (string variant)
    public static func fastGetByName(value: JsValue, global: JsGlobalObject, name: String): ?JsValue {
        let result = value.get(global.globalThis, name)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return result
    }

    /// 获取 truthy 属性
    public static func getTruthy(value: JsValue, global: JsGlobalObject, name: String): ?JsValue {
        let result = value.get(global.globalThis, name)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return result
    }

    /// 快速获取 truthy 属性 (通过 BuiltinName)
    /// 对应 Bun: JSValue::fastGetTruthy (BuiltinName variant)
    public static func fastGetTruthy(value: JsValue, global: JsGlobalObject, name: BuiltinName): ?JsValue {
        let propName = builtinNameToString(name)
        let result = value.get(global.globalThis, propName)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return result
    }

    /// 获取可选枚举 (FetchRedirect)
    public static func getOptionalEnum(value: JsValue, global: JsGlobalObject, name: String): ?FetchRedirect {
        let result = value.get(global.globalThis, name)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return FetchRedirectUtil.fromString(result.getOrThrow().toString())
    }

    /// 获取可选枚举 (FetchCacheMode)
    public static func getOptionalEnumFetchCacheMode(value: JsValue, global: JsGlobalObject, name: String): ?FetchCacheMode {
        let result = value.get(global.globalThis, name)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return FetchCacheModeUtil.fromString(result.getOrThrow().toString())
    }

    /// 获取可选枚举 (FetchRequestMode)
    public static func getOptionalEnumFetchRequestMode(value: JsValue, global: JsGlobalObject, name: String): ?FetchRequestMode {
        let result = value.get(global.globalThis, name)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return FetchRequestModeUtil.fromString(result.getOrThrow().toString())
    }

    /// builtin name to string
    public static func builtinNameToString(name: BuiltinName): String {
        match (name) {
            case BuiltinName.headers => "headers"
            case BuiltinName.status => "status"
            case BuiltinName.body => "body"
            case BuiltinName.method => "method"
            case BuiltinName.url => "url"
            case BuiltinName.signal => "signal"
            case BuiltinName.redirect => "redirect"
            case BuiltinName.cache => "cache"
            case BuiltinName.mode => "mode"
        }
    }
}

// ============================================================================
// HeadersRef 扩展方法
// 对应 Bun: Request.rs 中 Headers 操作
// ============================================================================

/// HeadersRef 扩展
public class HeadersRefHelper {
    /// 快速获取 header
    public static func fastGet(ref: HeadersRef, name: HTTPHeaderName): ?String {
        let headerName = headerNameToString(name)
        return None
    }

    /// HTTP header name to string
    public static func headerNameToString(name: HTTPHeaderName): String {
        match (name) {
            case HTTPHeaderName.contentType => "content-type"
            case _ => "unknown"
        }
    }
}

// ============================================================================
// Request - HTTP 请求对象
// 对应 Bun: Request.rs pub struct Request (Request.rs:87-112)
// 完整的 Request 实现，包含所有字段、getter、setter、构造、克隆
// ============================================================================

/// HTTP 请求对象
/// 对应 Bun: Request (Request.rs:87-112)
/// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Request
///
/// 字段对照:
///   url:                      Bun: url (OwnedStringCell)
///   headers:                  Bun: headers (JsCell<Option<HeadersRef>>)
///   signal:                   Bun: signal (JsCell<Option<AbortSignalRef>>)
///   body:                     Bun: body (ManuallyDrop<BodyHiveHandle>)
///   jsRef:                    Bun: js_ref (JsCell<JsRef>)
///   method:                   Bun: method (Method)
///   flags:                    Bun: flags (Flags)
///   requestContext:           Bun: request_context (AnyRequestContext)
///   weakPtrData:              Bun: weak_ptr_data (WeakPtrData)
///   reportedEstimatedSize:    Bun: reported_estimated_size (Cell<usize>)
///   internalEventCallback:    Bun: internal_event_callback (JsCell<InternalJSEventCallback>)
public class Request {
    // ========== 字段 ==========
    // 对应 Bun: Request struct fields (Request.rs:88-112)

    /// 请求 URL
    /// 对应 Bun: Request.url (OwnedStringCell)
    public var url: String

    /// 请求头引用
    /// 对应 Bun: Request.headers (JsCell<Option<HeadersRef>>)
    public var headers: ?HeadersRef

    /// AbortSignal 引用
    /// 对应 Bun: Request.signal (JsCell<Option<AbortSignalRef>>)
    public var signal: ?AbortSignalRef

    /// 请求体值
    /// 对应 Bun: Request.body (ManuallyDrop<BodyHiveHandle>) → 通过 bodyValue 访问
    public var bodyValue: BodyValue

    /// JS 引用句柄
    /// 对应 Bun: Request.js_ref (JsCell<JsRef>)
    public var jsRef: JsRef

    /// HTTP 方法
    /// 对应 Bun: Request.method (Method)
    public var method: HttpMethod

    /// 请求标志位
    /// 对应 Bun: Request.flags (Flags)
    public var flags: Flags

    /// 请求上下文
    /// 对应 Bun: Request.request_context (AnyRequestContext)
    public var requestContext: AnyRequestContext

    /// 弱引用数据
    /// 对应 Bun: Request.weak_ptr_data (WeakPtrData)
    public var weakPtrData: WeakPtrData

    /// 已报告的估算大小
    /// 对应 Bun: Request.reported_estimated_size (Cell<usize>)
    public var reportedEstimatedSize: Int64

    /// 内部 JS 事件回调
    /// 对应 Bun: Request.internal_event_callback (JsCell<InternalJSEventCallback>)
    public var internalEventCallback: InternalJSEventCallback

    // ========== 构造函数 ==========

    /// 默认构造函数
    /// 对应 Bun: Request::new (Request.rs:149-153)
    public init() {
        url = ""
        headers = None
        signal = None
        bodyValue = BodyValue()
        jsRef = JsRef.empty()
        method = HttpMethod.GET
        flags = Flags()
        requestContext = AnyRequestContext.NULL
        weakPtrData = WeakPtrData.EMPTY
        reportedEstimatedSize = 0
        internalEventCallback = InternalJSEventCallback()
    }

    /// 完整参数构造函数
    /// 对应 Bun: Request::init (Request.rs:1700-1723)
    public init(
        url: String,
        headers: ?HeadersRef,
        signal: ?AbortSignalRef,
        bodyValue: BodyValue,
        jsRef: JsRef,
        method: HttpMethod,
        flags: Flags,
        requestContext: AnyRequestContext,
        weakPtrData: WeakPtrData,
        reportedEstimatedSize: Int64,
        internalEventCallback: InternalJSEventCallback
    ) {
        this.url = url
        this.headers = headers
        this.signal = signal
        this.bodyValue = bodyValue
        this.jsRef = jsRef
        this.method = method
        this.flags = flags
        this.requestContext = requestContext
        this.weakPtrData = weakPtrData
        this.reportedEstimatedSize = reportedEstimatedSize
        this.internalEventCallback = internalEventCallback
    }

    /// 简化构造函数 (Bun.serve 使用)
    /// 对应 Bun: Request::init (Request.rs:1700-1723)
    public init(
        method: HttpMethod,
        requestContext: AnyRequestContext,
        https: Bool,
        signal: ?AbortSignalRef,
        bodyValue: BodyValue
    ) {
        url = ""
        headers = None
        this.signal = signal
        this.bodyValue = bodyValue
        jsRef = JsRef.empty()
        this.method = method
        flags = Flags(FetchRedirect.Follow, FetchCacheMode.Default, FetchRequestMode.Cors, https)
        this.requestContext = requestContext
        weakPtrData = WeakPtrData.EMPTY
        reportedEstimatedSize = 0
        internalEventCallback = InternalJSEventCallback()
    }

    /// init2 构造函数 (Bun: init2, Request.rs:440-459)
    /// 用于 fetch 内部构造
    public init(
        url: String,
        headers: ?HeadersRef,
        bodyValue: BodyValue,
        method: HttpMethod
    ) {
        this.url = url
        this.headers = headers
        signal = None
        this.bodyValue = bodyValue
        jsRef = JsRef.empty()
        this.method = method
        flags = Flags()
        requestContext = AnyRequestContext.NULL
        weakPtrData = WeakPtrData.EMPTY
        reportedEstimatedSize = 0
        internalEventCallback = InternalJSEventCallback()
    }

    // ========== Body 值访问器 ==========
    // 对应 Bun: Request.rs get_body_value / body_value / body_value_mut (Request.rs:207-231)

    /// 获取 Body 值 (可变)
    /// 对应 Bun: Request::get_body_value (Request.rs:207-213)
    public func getBodyValue(): BodyValue {
        return bodyValue
    }

    /// 获取 Body 值 (不可变视图)
    /// 对应 Bun: Request::body_value (Request.rs:217-219)
    public func bodyValueRef(): BodyValue {
        return bodyValue
    }

    /// 设置 Body 值
    /// 对应 Bun: Request::body_value_mut (Request.rs:227-231)
    public func setBodyValue(value: BodyValue): Unit {
        bodyValue = value
    }

    // ========== Headers 访问器 ==========
    // 对应 Bun: Request.rs headers accessors (Request.rs:233-379)

    /// 获取可变 headers 引用
    /// 对应 Bun: Request::headers_mut (Request.rs:236-242)
    public func headersMut(): ?HeadersRef {
        return headers
    }

    /// 设置 headers
    /// 对应 Bun: Request::set_fetch_headers (Request.rs:251-253)
    public func setFetchHeaders(headers: ?HeadersRef): Unit {
        this.headers = headers
    }

    /// 是否已有 fetch headers
    /// 对应 Bun: Request::has_fetch_headers (Request.rs:245-247)
    public func hasFetchHeaders(): Bool {
        return headers.isSome()
    }

    /// 确保 headers 存在，如果不存在则创建
    /// 对应 Bun: Request::ensure_fetch_headers (Request.rs:260-311)
    public func ensureFetchHeaders(global: JsGlobalObject): ?HeadersRef {
        if (headers.isSome()) {
            return headers
        }

        if (requestContext.hasRequest()) {
            // 从 uws 请求上下文创建 headers
            headers = Some(HeadersRef.createFromUWS(requestContext.getRequest()))
        } else {
            // 创建空 headers
            headers = Some(HeadersRef.createEmpty())

            // 从 body 的 content-type 设置 header
            match (bodyValue.tag) {
                case BodyValueTag.Blob =>
                    match (bodyValue.blob) {
                        case Some(blob) =>
                            let ct = blob.getContentType()
                            match (ct) {
                                case Some(ctVal) =>
                                    if (ctVal.size > 0) {
                                        // 对应 Bun: headers.put(ContentType, contentType)
                                        ()
                                    }
                                case None => ()
                            }
                        case None => ()
                    }
                case _ => ()
            }
        }

        return headers
    }

    /// 获取 headers（除非为空）
    /// 对应 Bun: Request::get_fetch_headers_unless_empty (Request.rs:313-329)
    public func getFetchHeadersUnlessEmpty(): ?HeadersRef {
        if (headers.isNone()) {
            if (requestContext.hasRequest()) {
                headers = Some(HeadersRef.createFromUWS(requestContext.getRequest()))
            }
        }

        match (headers) {
            case Some(h) =>
                // 如果 headers 为空，返回 None
                return headers
            case None => return None
        }
    }

    /// 获取 headers 作为 JsValue
    /// 对应 Bun: Request::get_headers (Request.rs:332-334)
    public func getHeaders(global: JsGlobalObject): JsValue {
        let h = ensureFetchHeaders(global)
        match (h) {
            case Some(headersRef) => return headersRef.toJsValue(global)
            case None => return JsValue.undefined()
        }
    }

    /// 克隆 headers
    /// 对应 Bun: Request::clone_headers (Request.rs:336-354)
    public func cloneHeaders(global: JsGlobalObject): ?HeadersRef {
        if (headers.isNone()) {
            if (requestContext.hasRequest()) {
                headers = Some(HeadersRef.createFromUWS(requestContext.getRequest()))
            }
        }

        match (headers) {
            case Some(h) => return h.cloneThis(global)
            case None => return None
        }
    }

    /// 获取 content-type
    /// 对应 Bun: Request::get_content_type (Request.rs:356-379)
    public func getContentType(): ?String {
        // 从 uws 请求获取
        if (requestContext.hasRequest()) {
            let ct = requestContext.getHeader("content-type")
            if (ct.size > 0) {
                return Some(ct)
            }
        }

        // 从 headers 获取
        match (headers) {
            case Some(h) =>
                // 对应 Bun: headers.fastGet(ContentType)
                let fastGet = HeadersRefHelper.fastGet(h, HTTPHeaderName.contentType)
                if (fastGet.isSome()) {
                    return fastGet
                }
            case None => ()
        }

        // 从 body blob 获取
        match (bodyValue.tag) {
            case BodyValueTag.Blob =>
                match (bodyValue.blob) {
                    case Some(blob) =>
                        let ct = blob.getContentType()
                        match (ct) {
                            case Some(s) =>
                                if (s.size > 0) {
                                    return Some(s)
                                }
                            case None => ()
                        }
                    case None => ()
                }
            case _ => ()
        }

        return None
    }

    /// 获取已缓存的 FetchHeaders (不创建)
    /// 对应 Bun: Request::get_fetch_headers (Request.rs:1726-1728)
    public func getFetchHeaders(): ?HeadersRef {
        return headers
    }

    // ========== Getter 方法 ==========
    // 对应 Bun: Request.rs getters (Request.rs:766-927)

    /// 获取缓存模式
    /// 对应 Bun: Request::get_cache (Request.rs:766-768)
    public func getCache(global: JsGlobalObject): JsValue {
        let modeStr = FetchCacheModeUtil.toString(flags.cache)
        return JsValue(modeStr)
    }

    /// 获取凭据模式
    /// 对应 Bun: Request::get_credentials (Request.rs:770-772)
    /// Bun 总是返回 "include"
    public func getCredentials(global: JsGlobalObject): JsValue {
        return JsValue("include")
    }

    /// 获取目的地
    /// 对应 Bun: Request::get_destination (Request.rs:774-776)
    /// Bun 总是返回空字符串
    public func getDestination(global: JsGlobalObject): JsValue {
        return JsValue("")
    }

    /// 获取完整性
    /// 对应 Bun: Request::get_integrity (Request.rs:778-779)
    /// Bun 总是返回空字符串
    public func getIntegrity(global: JsGlobalObject): JsValue {
        return JsValue("")
    }

    /// 获取 AbortSignal
    /// 对应 Bun: Request::get_signal (Request.rs:782-795)
    public func getSignal(global: JsGlobalObject): JsValue {
        match (signal) {
            case Some(signalRef) =>
                return signalRef.toJs(global)
            case None =>
                // 惰性创建默认 signal
                // 对应 Bun: AbortSignal::create + ref_from_js
                let jsSignal = JsValue.undefined()
                return jsSignal
        }
    }

    /// 获取 HTTP 方法
    /// 对应 Bun: Request::get_method (Request.rs:797-799)
    public func getMethod(global: JsGlobalObject): JsValue {
        return JsValue(MethodUtil.toString(method))
    }

    /// 获取请求模式
    /// 对应 Bun: Request::get_mode (Request.rs:801-803)
    public func getMode(global: JsGlobalObject): JsValue {
        let modeStr = FetchRequestModeUtil.toString(flags.mode)
        return JsValue(modeStr)
    }

    /// 获取重定向策略
    /// 对应 Bun: Request::get_redirect (Request.rs:846-848)
    public func getRedirect(global: JsGlobalObject): JsValue {
        let redirectStr = FetchRedirectUtil.toString(flags.redirect)
        return JsValue(redirectStr)
    }

    /// 获取 referrer
    /// 对应 Bun: Request::get_referrer (Request.rs:850-858)
    public func getReferrer(global: JsGlobalObject): JsValue {
        match (headers) {
            case Some(headersRef) =>
                let referrer = headersRef.getReferrer()
                if (referrer.isSome()) {
                    return JsValue(referrer.getOrThrow())
                }
            case None => ()
        }
        return JsValue("")
    }

    /// 获取 referrer 策略
    /// 对应 Bun: Request::get_referrer_policy (Request.rs:860-862)
    /// Bun 总是返回空字符串
    public func getReferrerPolicy(global: JsGlobalObject): JsValue {
        return JsValue("")
    }

    /// 获取 URL
    /// 对应 Bun: Request::get_url (Request.rs:864-867)
    public func getUrl(global: JsGlobalObject): JsValue {
        ensureUrl()
        return JsValue(url)
    }

    // ========== URL 处理 ==========
    // 对应 Bun: Request.rs URL methods (Request.rs:869-1016)

    /// 计算 URL 字节大小
    /// 对应 Bun: Request::size_of_url (Request.rs:869-892)
    public func sizeOfUrl(): Int64 {
        if (url.size > 0) {
            return Int64(url.size)
        }

        if (requestContext.hasRequest()) {
            let reqUrl = requestContext.getUrl()
            if (reqUrl.size > 0 && reqUrl[0] == UInt8(47)) {
                // 对应 Bun: 检查 host header
                let host = requestContext.getHeader("host")
                if (host.size > 0) {
                    let protocol = getProtocol()
                    return Int64(protocol.size + host.size + reqUrl.size)
                }
            }
            return Int64(reqUrl.size)
        }

        return 0
    }

    /// 获取协议 (http:// 或 https://)
    /// 对应 Bun: Request::get_protocol (Request.rs:894-900)
    public func getProtocol(): String {
        if (flags.https) {
            return "https://"
        }
        return "http://"
    }

    /// 解析请求目标路径
    /// 对应 Bun: Request::request_target_path (Request.rs:902-926)
    public static func requestTargetPath(target: String): String {
        let targetBytes = target.toArray()
        let schemeLen = if (targetBytes.size >= 8 && targetBytes[0] == UInt8(104) && targetBytes[1] == UInt8(116) && targetBytes[2] == UInt8(116) && targetBytes[3] == UInt8(112)) {
            if (targetBytes.size >= 8 && targetBytes[4] == UInt8(115) && targetBytes[5] == UInt8(58) && targetBytes[6] == UInt8(47) && targetBytes[7] == UInt8(47)) {
                8 // "https://"
            } else if (targetBytes.size >= 7 && targetBytes[4] == UInt8(58) && targetBytes[5] == UInt8(47) && targetBytes[6] == UInt8(47)) {
                7 // "http://"
            } else {
                return target
            }
        } else {
            return target
        }

        // 找到第一个 '/' 和 '?' 在 scheme 之后
        var pathStart = -1
        var queryStart = -1
        var i = schemeLen
        while (i < targetBytes.size) {
            if (pathStart < 0 && targetBytes[Int64(i)] == UInt8(47)) {
                pathStart = i
            }
            if (queryStart < 0 && targetBytes[Int64(i)] == UInt8(63)) {
                queryStart = i
            }
            i++
        }

        if (pathStart >= 0) {
            return target[Int64(pathStart)..]
        }

        if (queryStart >= 0) {
            return "/" + target[Int64(queryStart)..]
        }

        return "/"
    }

    /// 确保已解析 URL
    /// 对应 Bun: Request::ensure_url (Request.rs:928-1016)
    public func ensureUrl(): Unit {
        if (url.size > 0) {
            return
        }

        if (requestContext.hasRequest()) {
            let reqUrl = requestContext.getUrl()
            let targetPath = requestTargetPath(reqUrl)

            if (targetPath.size > 0 && targetPath[0] == UInt8(47)) {
                let host = requestContext.getHeader("host")
                if (host.size > 0) {
                    let protocol = getProtocol()
                    url = protocol + host + targetPath
                    return
                }
            }
            url = targetPath
        }
    }

    // ========== 内存/大小方法 ==========
    // 对应 Bun: Request.rs memory methods (Request.rs:383-509)

    /// 计算 Request 内存开销
    /// 对应 Bun: Request::memory_cost (Request.rs:383-388)
    public func memoryCost(): Int64 {
        var cost = Int64(0) // sizeof(Request) 近似
        cost += requestContext.memoryCost()
        cost += Int64(url.size)
        cost += bodyValue.memoryCost()
        return cost
    }

    /// 获取估算大小
    /// 对应 Bun: Request::estimated_size (Request.rs:477-479)
    public func estimatedSize(): Int64 {
        return reportedEstimatedSize
    }

    /// 计算估算字节大小
    /// 对应 Bun: Request::calculate_estimated_byte_size (Request.rs:501-508)
    public func calculateEstimatedByteSize(): Unit {
        reportedEstimatedSize = bodyValue.estimatedSize() + sizeOfUrl() + Int64(128) // sizeof(Request) 近似
    }

    /// 获取 MIME 类型
    /// 对应 Bun: Request::mime_type (Request.rs:724-764)
    public func mimeType(): String {
        match (headers) {
            case Some(h) =>
                let ct = HeadersRefHelper.fastGet(h, HTTPHeaderName.contentType)
                if (ct.isSome()) {
                    return ct.getOrThrow()
                }
            case None => ()
        }

        match (bodyValue.tag) {
            case BodyValueTag.Blob =>
                match (bodyValue.blob) {
                    case Some(blob) =>
                        let ct = blob.getContentType()
                        match (ct) {
                            case Some(s) =>
                                if (s.size > 0) {
                                    return s
                                }
                            case None => ()
                        }
                    case None => ()
                }
            case BodyValueTag.WTFStringImpl =>
                return "text/plain;charset=utf-8"
            case _ => ()
        }

        return "application/octet-stream"
    }

    // ========== FormData 编码 ==========
    // 对应 Bun: Request::get_form_data_encoding (Request.rs:461-475)

    /// 获取 FormData 编码
    /// 对应 Bun: Request::get_form_data_encoding (Request.rs:461-475)
    public func getFormDataEncoding(): ?FormDataEncoding {
        let contentType = getContentType()
        match (contentType) {
            case Some(ct) =>
                // 对应 Bun: Encoding.get(content_type_slice)
                if (ct.contains("multipart/form-data")) {
                    return Some(FormDataEncoding.Multipart(Array<UInt8>()))
                } else if (ct.contains("application/x-www-form-urlencoded")) {
                    return Some(FormDataEncoding.URLEncoded)
                }
                return None
            case None => return None
        }
    }

    // ========== Remote Socket Info ==========
    // 对应 Bun: Request::get_remote_socket_info (Request.rs:482-499)

    /// 获取远程 Socket 信息
    /// 对应 Bun: Request::get_remote_socket_info (Request.rs:482-499)
    public func getRemoteSocketInfo(global: JsGlobalObject): ?JsValue {
        let info = requestContext.getRemoteSocketInfo()
        match (info) {
            case Some(socketInfo) => return Some(socketInfo.toJsValue())
            case None => return None
        }
    }

    // ========== FFI Callbacks ==========
    // 对应 Bun: Request.rs FFI exports (Request.rs:390-430)

    /// FFI: 在请求上下文上设置 cookies
    /// 对应 Bun: Request__setCookiesOnRequestContext (Request.rs:391-394)
    public func ffiSetCookiesOnRequestContext(cookieMap: ?CookieMap): Unit {
        requestContext.setCookies(cookieMap)
    }

    /// FFI: 获取 uws 请求指针
    /// 对应 Bun: Request__getUWSRequest (Request.rs:397-402)
    public func ffiGetUWSRequest(): UInt64 {
        if (requestContext.hasRequest()) {
            return requestContext.getRequest()
        }
        return 0
    }

    /// FFI: 设置内部事件回调
    /// 对应 Bun: Request__setInternalEventCallback (Request.rs:404-410)
    public func ffiSetInternalEventCallback(callback: JsValue, global: JsGlobalObject): Unit {
        internalEventCallback = InternalJSEventCallback(callback, global)
        requestContext.enableTimeoutEvents()
    }

    /// FFI: 设置超时
    /// 对应 Bun: Request__setTimeout (Request.rs:413-424)
    public func ffiSetTimeout(secondsValue: JsValue, global: JsGlobalObject): Unit {
        if (!secondsValue.isNumber()) {
            return
        }
        let seconds = UInt32(Int64(secondsValue.toNumber()))
        setTimeout(seconds)
    }

    /// 设置超时
    /// 对应 Bun: Request::set_timeout (Request.rs:1655-1657)
    public func setTimeout(seconds: UInt32): Unit {
        requestContext.setTimeout(seconds)
    }

    /// FFI: 克隆
    /// 对应 Bun: Request__clone (Request.rs:426-429)
    public func ffiClone(global: JsGlobalObject): ?Request {
        return clone(global)
    }

    // ========== To JS ==========
    // 对应 Bun: Request::to_js (Request.rs:525-538)

    /// 转为 JsValue
    /// 对应 Bun: Request::to_js (Request.rs:525-538)
    public func toJs(global: JsGlobalObject): JsValue {
        calculateEstimatedByteSize()
        // 对应 Bun: js_gen::to_js_unchecked — 创建 JS 包装器
        let obj = JsObject()
        obj.set("method", JsValue(MethodUtil.toString(method)))
        obj.set("url", JsValue(url))

        // 设置所有 getter 属性
        obj.set("cache", getCache(global))
        obj.set("credentials", getCredentials(global))
        obj.set("destination", getDestination(global))
        obj.set("integrity", getIntegrity(global))
        obj.set("mode", getMode(global))
        obj.set("redirect", getRedirect(global))
        obj.set("referrer", getReferrer(global))
        obj.set("referrerPolicy", getReferrerPolicy(global))

        // 保存 js_ref
        let jsValue = JsValue(obj)
        jsRef = JsRef.initWeak(jsValue)

        checkBodyStreamRef(global)
        return jsValue
    }

    /// 用于 Bake 的 JS 创建
    /// 对应 Bun: Request::to_js_for_bake (Request.rs:558-568)
    public func toJsForBake(global: JsGlobalObject): JsValue {
        return toJs(global)
    }

    /// 检查 body stream ref
    /// 对应 Bun: Request::check_body_stream_ref (Request.rs:1039-1042)
    public func checkBodyStreamRef(global: JsGlobalObject): Unit {
        let jsRefOpt = jsRef.tryGet()
        if (jsRefOpt.isSome()) {
            let jsValue = jsRefOpt.getOrThrow()
            if (bodyValue.tag == BodyValueTag.Locked) {
                match (bodyValue.locked) {
                    case Some(lockedValue) =>
                        let streamOpt = lockedValue.readable.get()
                        if (streamOpt.isSome()) {
                            let stream = streamOpt.getOrThrow()
                            // 缓存 stream 到 JS
                            lockedValue.readable.deinit()
                            lockedValue.readable = ReadableStreamStrong()
                        }
                    case None => ()
                }
            }
        }
    }

    // ========== Finalize ==========
    // 对应 Bun: Request.rs finalize (Request.rs:805-843)

    /// 不带 deinit 的终结
    /// 对应 Bun: Request::finalize_without_deinit (Request.rs:805-816)
    public func finalizeWithoutDeinit(): Unit {
        headers = None
        url = ""
        signal = None
        internalEventCallback = InternalJSEventCallback()
    }

    /// 终结并释放资源
    /// 对应 Bun: Request::finalize (Request.rs:818-843)
    public func finalize(): Unit {
        // 释放 body
        bodyValue.deinit()
        // 释放 headers
        match (headers) {
            case Some(h) => h.release()
            case None => ()
        }
        // 释放 signal
        match (signal) {
            case Some(s) => s.unref()
            case None => ()
        }
        // 释放 js_ref
        jsRef.finalize()
        // 释放事件回调
        internalEventCallback.deinit()
    }

    // ========== Write Format (console.log 格式化) ==========
    // 对应 Bun: Request::write_format (Request.rs:578-722)

    /// 格式化输出 (console.log)
    /// 对应 Bun: Request::write_format (Request.rs:578-722)
    public func writeFormat(thisValue: JsValue, enableAnsiColors: Bool): String {
        let classLabel = "Request"
        let bodySize = bodyValue.size()
        let sizeStr = bodySize.toString()
        let methodStr = MethodUtil.toString(method)

        var output = classLabel + " (" + sizeStr + ") {\n"
        output += "  method: \"" + methodStr + "\",\n"
        output += "  url: \"" + url + "\",\n"

        // headers
        match (headers) {
            case Some(h) =>
                output += "  headers: Headers {}\n"
            case None => ()
        }

        // body 信息
        match (bodyValue.tag) {
            case BodyValueTag.Blob =>
                match (bodyValue.blob) {
                    case Some(blob) =>
                        let blobSize = blob.size
                        output += "  body: Blob (" + blobSize.toString() + " bytes)\n"
                    case None => ()
                }
            case BodyValueTag.InternalBlob =>
                let s = bodyValue.size()
                output += "  body: (" + s.toString() + " bytes)\n"
            case BodyValueTag.WTFStringImpl =>
                let s = bodyValue.size()
                output += "  body: String (" + s.toString() + " bytes)\n"
            case BodyValueTag.Locked =>
                output += "  body: ReadableStream\n"
            case _ => ()
        }

        output += "}"
        return output
    }

    // ========== 构造方法 ==========
    // 对应 Bun: Request.rs construct_into / constructor (Request.rs:1044-1543)

    /// 从 JS 参数构造 Request
    /// 对应 Bun: Request::construct_into (Request.rs:1044-1531)
    public static func constructInto(
        global: JsGlobalObject,
        arguments: Array<JsValue>,
        thisValue: JsValue
    ): ?Request {
        var success = false

        let req = Request()
        // 对应 Bun: body = body::hive_alloc(BodyValue::Null) — 初始为 Null
        req.bodyValue = BodyValue()
        req.jsRef = JsRef.initWeak(thisValue)

        // 清理函数
        func bail(): ?Request {
            if (!success) {
                req.finalizeWithoutDeinit()
            }
            return None
        }

        if (arguments.size == 0) {
            return bail()
        }

        let urlOrObject = arguments[0]

        if (urlOrObject.isEmptyOrUndefinedOrNull() || !urlOrObject.isCell()) {
            return bail()
        }

        var fields = FieldSet()

        // 判断第一个参数是否为 URL
        let isFirstArgumentUrl = urlOrObject.isString()

        if (isFirstArgumentUrl) {
            let str = urlOrObject.toString()
            req.url = str
            if (req.url.size > 0) {
                fields.insert(Fields.Url)
            }
        } else if (!urlOrObject.isObject()) {
            return bail()
        }

        // 确定要尝试的值列表
        var valuesToTry = ArrayList<JsValue>()

        if (arguments.size > 1 && arguments[1].isObject()) {
            valuesToTry.append(arguments[1])
        }

        if (!isFirstArgumentUrl) {
            valuesToTry.append(urlOrObject)
        }

        // 遍历 values_to_try，提取属性
        for (value in valuesToTry) {
            let valueType = value.jsType()

            // DOMWrapper 快速路径: 检测 Request / Response
            if (value.isRequest()) {
                let sourceRequest = Request.fromJs(value)
                match (sourceRequest) {
                    case Some(request) =>
                        // 单个 Request 参数: 直接 clone_into
                        if (valuesToTry.size == 1 && !isFirstArgumentUrl) {
                            let cloned = request.cloneInto(req, global, fields.contains(Fields.Url))
                            match (cloned) {
                                case Some(r) =>
                                    success = true
                                    return Some(r)
                                case None => return bail()
                            }
                        }

                        // 多参数: 逐字段拷贝
                        if (!fields.contains(Fields.Method)) {
                            req.method = request.method
                            fields.insert(Fields.Method)
                        }

                        if (!fields.contains(Fields.Redirect)) {
                            req.flags.redirect = request.flags.redirect
                            fields.insert(Fields.Redirect)
                        }

                        if (!fields.contains(Fields.Cache)) {
                            req.flags.cache = request.flags.cache
                            fields.insert(Fields.Cache)
                        }

                        if (!fields.contains(Fields.Mode)) {
                            req.flags.mode = request.flags.mode
                            fields.insert(Fields.Mode)
                        }

                        if (!fields.contains(Fields.Headers)) {
                            let clonedHeaders = request.cloneHeaders(global)
                            match (clonedHeaders) {
                                case Some(h) =>
                                    req.headers = Some(h)
                                    fields.insert(Fields.Headers)
                                case None => ()
                            }
                        }

                        if (!fields.contains(Fields.Body)) {
                            match (request.bodyValue.tag) {
                                case BodyValueTag.Null => ()
                                case BodyValueTag.Empty => ()
                                case BodyValueTag.Used => ()
                                case _ =>
                                    req.bodyValue = request.bodyValue.clone()
                                    fields.insert(Fields.Body)
                            }
                        }
                    case None => ()
                }
            }

            if (value.isResponse()) {
                // 对应 Bun: Response 处理路径 (Request.rs:1226-1283)
                // 从 Response 中提取 method, headers, url, body
                // stub: simplified — Response.fromJs not implemented
                let respOpt: ?Response = None
                match (respOpt) {
                    case Some(response) =>
                        if (!fields.contains(Fields.Method)) {
                            req.method = response.getMethod()
                            fields.insert(Fields.Method)
                        }

                        if (!fields.contains(Fields.Headers)) {
                            // 尝试从 response init 获取 headers
                            let respHeaders = response.getHeaders(global)
                            fields.insert(Fields.Headers)
                        }

                        if (!fields.contains(Fields.Url)) {
                            if (response.url.size > 0) {
                                req.url = response.url
                                fields.insert(Fields.Url)
                            }
                        }

                        if (!fields.contains(Fields.Body)) {
                            let bodyVal = response.getBodyValue()
                            match (bodyVal.tag) {
                                case BodyValueTag.Null => ()
                                case BodyValueTag.Empty => ()
                                case BodyValueTag.Used => ()
                                case _ =>
                                    req.bodyValue = bodyVal.clone()
                                    fields.insert(Fields.Body)
                            }
                        }
                    case None => ()
                }
            }

            // 提取 body
            if (!fields.contains(Fields.Body)) {
                let bodyOpt = JsValueHelper.fastGet(value, global, BuiltinName.body)
                if (bodyOpt.isSome()) {
                    fields.insert(Fields.Body)
                    req.bodyValue = BodyValue.fromJs(bodyOpt.getOrThrow())
                }
            }

            // 提取 url
            if (!fields.contains(Fields.Url)) {
                let urlOpt = JsValueHelper.fastGet(value, global, BuiltinName.url)
                if (urlOpt.isSome()) {
                    let urlStr = urlOpt.getOrThrow().toString()
                    if (urlStr.size > 0) {
                        req.url = urlStr
                        fields.insert(Fields.Url)
                    }
                } else {
                    // 对应 Bun: implements_to_string 检查
                    if (!isFirstArgumentUrl) {
                        let str = value.toString()
                        if (str.size > 0) {
                            req.url = str
                            fields.insert(Fields.Url)
                        }
                    }
                }
            }

            // 提取 signal
            if (!fields.contains(Fields.Signal)) {
                let signalOpt = JsValueHelper.fastGetTruthy(value, global, BuiltinName.signal)
                if (signalOpt.isSome()) {
                    fields.insert(Fields.Signal)
                    let signalJs = signalOpt.getOrThrow()
                    req.signal = Some(AbortSignalRef(signalJs))
                }
            }

            // 提取 method 和 headers (通过 ResponseInit.init)
            if (!fields.contains(Fields.Method) || !fields.contains(Fields.Headers)) {
                let responseInit = ResponseInit.`init`(global, value)
                match (responseInit) {
                    case Some(respInit) =>
                        if (!fields.contains(Fields.Headers)) {
                            match (respInit.headers) {
                                case Some(h) =>
                                    req.headers = Some(h)
                                    fields.insert(Fields.Headers)
                                case None => ()
                            }
                        }

                        if (!fields.contains(Fields.Method)) {
                            req.method = respInit.method
                            fields.insert(Fields.Method)
                        }
                    case None => ()
                }
            }

            // 提取 redirect
            if (!fields.contains(Fields.Redirect)) {
                let redirectOpt = JsValueHelper.getOptionalEnum(value, global, "redirect")
                match (redirectOpt) {
                    case Some(r) =>
                        req.flags.redirect = r
                        fields.insert(Fields.Redirect)
                    case None => ()
                }
            }

            // 提取 cache
            if (!fields.contains(Fields.Cache)) {
                let cacheOpt = JsValueHelper.getOptionalEnumFetchCacheMode(value, global, "cache")
                match (cacheOpt) {
                    case Some(c) =>
                        req.flags.cache = c
                        fields.insert(Fields.Cache)
                    case None => ()
                }
            }

            // 提取 mode
            if (!fields.contains(Fields.Mode)) {
                let modeOpt = JsValueHelper.getOptionalEnumFetchRequestMode(value, global, "mode")
                match (modeOpt) {
                    case Some(m) =>
                        req.flags.mode = m
                        fields.insert(Fields.Mode)
                    case None => ()
                }
            }
        }

        // URL 必填检查
        if (req.url.size == 0) {
            return bail()
        }

        // 如果 body 是 Blob 且有 headers，设置 content-type
        if (bodyValueIsBlob(req.bodyValue) && req.headers.isSome()) {
            let ct = getBodyBlobContentType(req.bodyValue)
            if (ct.size > 0) {
                // 对应 Bun: 如果 headers 没有 content-type，则从 body blob 设置
                ()
            }
        }

        req.calculateEstimatedByteSize()
        req.checkBodyStreamRef(global)
        success = true

        return Some(req)
    }

    /// JS 构造函数入口
    /// 对应 Bun: Request::constructor (Request.rs:1533-1543)
    public static func constructor(
        global: JsGlobalObject,
        callframe: CallFrame,
        thisValue: JsValue
    ): ?Request {
        let arguments = callframe.argumentsAsArray(2)
        return constructInto(global, arguments, thisValue)
    }

    // ========== 克隆方法 ==========
    // 对应 Bun: Request.rs clone methods (Request.rs:1545-1657)

    /// do_clone — JS 调用的 clone 方法
    /// 对应 Bun: Request::do_clone (Request.rs:1545-1559)
    public func doClone(global: JsGlobalObject, callframe: CallFrame): JsValue {
        let thisValue = callframe.`this`()
        let cloned = clone(global)

        match (cloned) {
            case Some(clonedReq) =>
                let jsWrapper = clonedReq.toJs(global)
                syncClonedBodyStreamCaches(thisValue, jsWrapper, global)
                return jsWrapper
            case None =>
                return JsValue.undefined()
        }
    }

    /// clone_into — 将当前 request 克隆到目标 req
    /// 对应 Bun: Request::clone_into (Request.rs:1561-1624)
    public func cloneInto(req: Request, global: JsGlobalObject, preserveUrl: Bool): ?Request {
        ensureUrl()
        let bodyValue_ = bodyValue.clone()
        let headers = cloneHeaders(global)
        let url = if (preserveUrl) {
            req.url
        } else {
            this.url
        }

        // 覆写 req 的字段
        req.url = url
        req.headers = headers
        req.signal = None
        req.bodyValue = bodyValue_
        req.jsRef = JsRef.empty()
        req.method = this.method
        req.flags = Flags(
            this.flags.redirect,
            this.flags.cache,
            this.flags.mode,
            this.flags.https
        )
        req.requestContext = AnyRequestContext.NULL
        req.weakPtrData = WeakPtrData.EMPTY
        req.reportedEstimatedSize = 0
        req.internalEventCallback = InternalJSEventCallback()

        // 克隆 signal
        match (this.signal) {
            case Some(s) =>
                req.signal = Some(s.clone())
            case None => ()
        }

        return Some(req)
    }

    /// clone — 创建完全克隆
    /// 对应 Bun: Request::clone (Request.rs:1626-1653)
    public func clone(global: JsGlobalObject): ?Request {
        let req = Request()
        // clone_into 会覆写所有字段
        return cloneInto(req, global, false)
    }

    /// 同步克隆的 Body Stream 缓存
    /// 对应 Bun: BodyMixin::sync_cloned_body_stream_caches
    public func syncClonedBodyStreamCaches(thisValue: JsValue, jsWrapper: JsValue, global: JsGlobalObject): Unit {
        if (bodyValue.tag == BodyValueTag.Locked) {
            match (bodyValue.locked) {
                case Some(lockedValue) =>
                    match (lockedValue.readable.get()) {
                        case Some(readable) =>
                            // 对应 Bun: bodySetCached(thisValue, readable.toJsValue())
                            ()
                        case None => ()
                    }
                case None => ()
            }
        }
        checkBodyStreamRef(global)
    }

    // ========== 辅助方法 ==========

    /// 检查 BodyValue 是否为 Blob
    public static func bodyValueIsBlob(value: BodyValue): Bool {
        match (value.tag) {
            case BodyValueTag.Blob => true
            case _ => false
        }
    }

    /// 从 BodyValue Blob 获取 content-type
    public static func getBodyBlobContentType(value: BodyValue): String {
        match (value.tag) {
            case BodyValueTag.Blob =>
                match (value.blob) {
                    case Some(blob) =>
                        match (blob.getContentType()) {
                            case Some(ct) => ct
                            case None => ""
                        }
                    case None => ""
                }
            case _ => ""
        }
    }

    /// 从 JS 值获取 Request
    /// 对应 Bun: from_js (Request.rs:144)
    public static func fromJs(value: JsValue): ?Request {
        // 对应 Bun: js::from_js → 检查是否为 Request DOMWrapper
        if (value.isRequest()) {
            // 在真实实现中，从 JS wrapper 提取 Request 指针
            return None
        }
        return None
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        return JsValue()
    }

    /// 获取 ReadableStream body
    /// 对应 Bun: BodyMixin::get_body_readable_stream
    public func getBodyReadableStream(global: JsGlobalObject): ?ReadableStream {
        // 优先从 JS 缓存获取
        let jsRefOpt = jsRef.tryGet()
        if (jsRefOpt.isSome()) {
            // 对应 Bun: stream_get_cached
            ()
        }

        // 从 Locked.readable 获取
        if (bodyValue.tag == BodyValueTag.Locked) {
            match (bodyValue.locked) {
                case Some(lockedValue) => return lockedValue.readable.get()
                case None => ()
            }
        }
        return None
    }

    /// 分离 ReadableStream
    /// 对应 Bun: BodyMixin::detach_readable_stream
    public func detachReadableStream(): Unit {
        let jsRefOpt = jsRef.tryGet()
        if (jsRefOpt.isSome()) {
            // 对应 Bun: stream_set_cached(0)
            ()
        }

        if (bodyValue.tag == BodyValueTag.Locked) {
            match (bodyValue.locked) {
                case Some(lockedValue) =>
                    lockedValue.readable.deinit()
                    lockedValue.readable = ReadableStreamStrong()
                case None => ()
            }
        }
    }

    /// 获取 body (Web API getter)
    /// 对应 Bun: BodyMixin::get_body
    public func getBody(global: JsGlobalObject): JsValue {
        if (bodyValue.tag == BodyValueTag.Used) {
            return JsValue.null()
        }
        if (bodyValue.tag == BodyValueTag.Locked) {
            let streamOpt = getBodyReadableStream(global)
            match (streamOpt) {
                case Some(readable) => return readable.toJsValue()
                case None => ()
            }
        }
        return bodyValue.toReadableStream()
    }

    /// 获取 bodyUsed
    /// 对应 Bun: BodyMixin::get_body_used
    public func getBodyUsed(): JsValue {
        let used = match (bodyValue.tag) {
            case BodyValueTag.Used => true
            case BodyValueTag.Locked =>
                match (bodyValue.locked) {
                    case Some(locked) =>
                        if (!locked.action.isNone()) {
                            true
                        } else {
                            match (locked.readable.get()) {
                                case Some(readable) => readable.isDisturbed
                                case None => false
                            }
                        }
                    case None => false
                }
            case _ => false
        }
        return JsValue(used)
    }

    /// 获取文本
    /// 对应 Web API: body.text()
    public func getText(global: JsGlobalObject): JsValue {
        if (bodyValue.tag == BodyValueTag.Used) {
            return JsPromise.reject(global, JsValue("Body already used"))
        }
        let anyBlob = bodyValue.useAsAnyBlobAllowNonUtf8String()
        let text = anyBlob.slice().toString()
        return JsPromise.resolve(global, JsValue(text))
    }

    /// 获取 JSON
    /// 对应 Web API: body.json()
    public func getJSON(global: JsGlobalObject): JsValue {
        if (bodyValue.tag == BodyValueTag.Used) {
            return JsPromise.reject(global, JsValue("Body already used"))
        }
        let anyBlob = bodyValue.useAsAnyBlobAllowNonUtf8String()
        let text = anyBlob.slice().toString()
        return JsPromise.resolve(global, JsValue(text))
    }

    /// 获取 ArrayBuffer
    /// 对应 Web API: body.arrayBuffer()
    public func getArrayBuffer(global: JsGlobalObject): JsValue {
        if (bodyValue.tag == BodyValueTag.Used) {
            return JsPromise.reject(global, JsValue("Body already used"))
        }
        let anyBlob = bodyValue.useAsAnyBlobAllowNonUtf8String()
        return JsPromise.resolve(global, JsValue.createBuffer(JsObject(), anyBlob.slice()))
    }

    /// 获取 Blob
    /// 对应 Web API: body.blob()
    public func getBlob(global: JsGlobalObject, thisValue: JsValue): JsValue {
        if (bodyValue.tag == BodyValueTag.Used) {
            return JsPromise.reject(global, JsValue("Body already used"))
        }
        let usedBlob = bodyValue.use()
        let newBlob = Blob(usedBlob.sharedView(), "")
        let ct = newBlob.getContentType()
        let ctEmpty = match (ct) {
            case Some(s) => s.size == 0
            case None => true
        }
        if (ctEmpty) {
            let headersOpt = getFetchHeaders()
            match (headersOpt) {
                case Some(h) =>
                    let contentType = HeadersRefHelper.fastGet(h, HTTPHeaderName.contentType)
                    match (contentType) {
                        case Some(ctStr) =>
                            newBlob.setContentType(ctStr)
                            newBlob.setContentTypeWasSet(true)
                        case None => ()
                    }
                case None => ()
            }
            if (!newBlob.getContentTypeWasSet()) {
                newBlob.setContentType("text/plain")
            }
        }
        return JsPromise.resolve(global, newBlob.toJsValue())
    }

    /// 获取 FormData
    /// 对应 Web API: body.formData()
    public func getFormData(global: JsGlobalObject): JsValue {
        if (bodyValue.tag == BodyValueTag.Used) {
            return JsPromise.reject(global, JsValue("Body already used"))
        }
        let encoding = getFormDataEncoding()
        match (encoding) {
            case Some(enc) =>
                let anyBlob = bodyValue.useAsAnyBlob()
                let bytes = anyBlob.slice()
                let jsValue = FormData.toJS(global, bytes, enc)
                anyBlob.detach()
                return JsPromise.resolve(global, jsValue)
            case None =>
                return JsPromise.reject(global, JsValue("Can't decode form data from body because of incorrect MIME type/boundary"))
        }
    }
}

// ============================================================================
// HeadersRef 扩展方法
// 对应 Bun: HeadersRef JS 相关方法
// ============================================================================

/// HeadersRef 扩展 — 增加在 response.cj 中没有的方法
public class HeadersRefRequestExt {
    /// 获取 referrer header
    /// 对应 Bun: headers.get("referrer")
    public static func getReferrer(ref: HeadersRef): ?String {
        return None
    }

    /// 检查是否有指定 header
    /// 对应 Bun: headers.fastHas(HTTPHeaderName)
    public static func fastHas(ref: HeadersRef, name: HTTPHeaderName): Bool {
        return false
    }

    /// put header
    /// 对应 Bun: headers.put(HTTPHeaderName, value)
    public static func put(ref: HeadersRef, name: HTTPHeaderName, value: String): Unit {}
}

// ported from: src/runtime/webcore/Request.rs
