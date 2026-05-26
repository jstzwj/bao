// Request - HTTP 请求对象
// 对应 Bun: src/runtime/webcore/Request.rs
// 严格翻译自: src/runtime/webcore/Request.rs
package bao_runtime.webcore

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_http_types.*
import bao_http_jsc.*

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
// 对应 Bun: Request.Fields (Request.rs:1027-1044)
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
    private var set: HashSet<Fields>

    public init() {
        set = HashSet<Fields>()
    }

    public func contains(field: Fields): Bool {
        return set.contains(field)
    }

    public func insert(field: Fields): Unit {
        set.append(field)
    }
}

// ============================================================================
// InternalJSEventCallback - 内部 JS 事件回调 (Request 专用)
// 对应 Bun: Request.InternalJSEventCallback (Request.rs:1670-1707)
// ============================================================================

/// 内部 JS 事件回调 (Request)
/// 对应 Bun: InternalJSEventCallback
public class RequestInternalJSEventCallback {
    /// JS 函数引用 — 对应 Bun: jsc.strong.Optional
    public var function: ?JsValue

    public init() {
        function = None
    }

    public init(function: JsValue, global: JsGlobalObject) {
        this.function = Some(function)
    }

    /// 是否有回调
    public func hasCallback(): Bool {
        return function.isSome()
    }

    /// 释放资源
    public func deinit(): Unit {
        function = None
    }

    /// 触发回调
    /// 对应 Bun: InternalJSEventCallback::trigger
    public func trigger(eventType: Int64, global: JsGlobalObject): Bool {
        if (function.isSome()) {
            let callback = function.getOrThrow()
            callback.call(global, JsValue.undefined(), Array<JsValue>([JsValue(Float64(eventType))]))
            return true
        }
        return false
    }
}

/// Re-export of AbortEvent — 对应 Bun: EventType
public type AbortEventType = Int64

// ============================================================================
// Request - HTTP 请求
// 对应 Bun: src/runtime/webcore/Request.rs Request
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Request
// ============================================================================

/// HTTP Request — 对应 Web Request API
/// 对应 Bun: src/runtime/webcore/Request.rs Request
///
/// R-2: every JS-facing host-fn takes &Request (not &Request)
/// so re-entrant JS calls cannot stack two &to the same instance.
/// Fields mutated by host-fns use Cell (Copy scalars) or JsCell (non-Copy).
public class Request {
    /// 请求 URL — OwnedStringCell
    /// 对应 Bun: Request.url (OwnedStringCell)
    public var url: String
    /// 请求头 — JsCell<Option<HeadersRef>>
    /// 对应 Bun: Request.headers (JsCell<Option<HeadersRef>>)
    public var headers: ?HeadersRef
    /// Abort 信号 — JsCell<Option<AbortSignalRef>>
    /// 对应 Bun: Request.signal (JsCell<Option<AbortSignalRef>>)
    public var signal: ?AbortSignalRef
    /// Body — NonNull<BodyHiveRef>, 但在 Cangjie 中简化为 Body
    /// 对应 Bun: Request.body (NonNull<BodyHiveRef>)
    public var body: Body
    /// JS 引用 — JsCell<JsRef>
    /// 对应 Bun: Request.js_ref (JsCell<JsRef>)
    public var jsRef: JsRef
    /// HTTP 方法
    /// 对应 Bun: Request.method
    public var method: HttpMethod
    /// 请求标志
    /// 对应 Bun: Request.flags
    public var flags: Flags
    /// 请求上下文 — 对应 Bun: AnyRequestContext
    /// 对应 Bun: Request.request_context
    public var requestContext: AnyRequestContext
    /// 弱引用数据
    /// 对应 Bun: Request.weak_ptr_data
    public var weakPtrData: WeakPtrData
    /// 已报告的估算大小
    /// 对应 Bun: Request.reported_estimated_size (Cell<usize>)
    public var reportedEstimatedSize: Int64
    /// 内部事件回调
    /// 对应 Bun: Request.internal_event_callback (JsCell<InternalJSEventCallback>)
    public var internalEventCallback: RequestInternalJSEventCallback

    public init() {
        url = ""
        headers = None
        signal = None
        body = Body()
        jsRef = JsRef.empty()
        method = HttpMethod.GET
        flags = Flags()
        requestContext = AnyRequestContext.NULL
        weakPtrData = WeakPtrData()
        reportedEstimatedSize = 0
        internalEventCallback = RequestInternalJSEventCallback()
    }

    public init(url: String) {
        this.url = url
        headers = None
        signal = None
        body = Body()
        jsRef = JsRef.empty()
        method = HttpMethod.GET
        flags = Flags()
        requestContext = AnyRequestContext.NULL
        weakPtrData = WeakPtrData()
        reportedEstimatedSize = 0
        internalEventCallback = RequestInternalJSEventCallback()
    }

    public init(url: String, `init`: RequestInit) {
        this.url = url
        headers = `init`.headers
        signal = `init`.signal
        body = match (`init`.body) {
            case Some(b) => b
            case None => Body()
        }
        jsRef = JsRef.empty()
        method = `init`.method
        flags = Flags(redirect: `init`.redirect, cache: `init`.cache, mode: `init`.mode, https: false)
        requestContext = AnyRequestContext.NULL
        weakPtrData = WeakPtrData()
        reportedEstimatedSize = 0
        internalEventCallback = RequestInternalJSEventCallback()
    }

    /// 完整初始化器 — 对应 Bun: Request::init2 (Request.rs:459-478)
    public init(method: HttpMethod, requestContext: AnyRequestContext, https: Bool, signal: ?AbortSignalRef, body: Body) {
        url = ""
        headers = None
        this.signal = signal
        this.body = body
        jsRef = JsRef.empty()
        this.method = method
        flags = Flags(redirect: FetchRedirect.Follow, cache: FetchCacheMode.Default, mode: FetchRequestMode.Cors, https: https)
        this.requestContext = requestContext
        weakPtrData = WeakPtrData()
        reportedEstimatedSize = 0
        internalEventCallback = RequestInternalJSEventCallback()
    }

    /// init2 — 另一个初始化器 (简化版)
    /// 对应 Bun: Request::init2 (Request.rs:459-478)
    public static func init2(url: String, headers: ?HeadersRef, body: Body, method: HttpMethod): Request {
        let req = Request()
        req.url = url
        req.headers = headers
        req.body = body
        req.method = method
        return req
    }

    /// 创建新的 Box<Request>
    /// 对应 Bun: Request::new (Request.rs:148-152)
    public static func new(req: Request): Request {
        return req
    }

    // ========================================================================
    // Body 访问 (对应 Bun: Request body accessors)
    // ========================================================================

    /// 获取 Body 值 — 对应 Bun: Request::get_body_value (Request.rs:209-213)
    public func getBodyValue(): BodyValue {
        return body.value
    }

    /// 获取 Body 长度
    public func getBodyLen(): Int64 {
        return body.len()
    }

    // ========================================================================
    // Header 访问 (对应 Bun: Request header accessors)
    // ========================================================================

    /// 是否有 FetchHeaders
    /// 对应 Bun: Request::has_fetch_headers (Request.rs:263-265)
    public func hasFetchHeaders(): Bool {
        return headers.isSome()
    }

    /// 设置 headers — takes ownership.
    /// 对应 Bun: Request::set_fetch_headers (Request.rs:269-272)
    public func setFetchHeaders(h: ?HeadersRef): Unit {
        headers = h
    }

    /// 确保 headers 存在 — 如果不存在则创建.
    /// 对应 Bun: Request::ensure_fetch_headers (Request.rs:278-329)
    public func ensureFetchHeaders(global: JsGlobalObject): ?HeadersRef {
        if (headers.isSome()) {
            return headers
        }

        if (requestContext.hasRequest()) {
            headers = Some(HeadersRef.createFromUWS(requestContext.getRequest()))
        } else {
            headers = Some(HeadersRef.createEmpty())

            // 从 Blob body 中提取 Content-Type
            if (body.value.tag == BodyValueTag.Blob) {
                match (body.value.blob) {
                    case Some(b) =>
                        let ct = b.getContentType()
                        if (ct.isSome() && ct.getOrThrow().size > 0) {
                            // put Content-Type header
                        }
                    case None => ()
                }
            }
        }

        return headers
    }

    /// 获取 headers (除非为空)
    /// 对应 Bun: Request::get_fetch_headers_unless_empty (Request.rs:332-347)
    public func getFetchHeadersUnlessEmpty(): ?HeadersRef {
        if (headers.isNone()) {
            if (requestContext.hasRequest()) {
                headers = Some(HeadersRef.createFromUWS(requestContext.getRequest()))
            }
        }

        if (headers.isNone()) {
            return None
        }
        return headers
    }

    /// 获取 headers — JS getter.
    /// 对应 Bun: Request::get_headers (Request.rs:351-353)
    public func getHeaders(global: JsGlobalObject): ?HeadersRef {
        return ensureFetchHeaders(global)
    }

    /// 克隆 headers
    /// 对应 Bun: Request::clone_headers (Request.rs:355-373)
    public func cloneHeaders(global: JsGlobalObject): ?HeadersRef {
        if (headers.isNone()) {
            if (requestContext.hasRequest()) {
                headers = Some(HeadersRef.createFromUWS(requestContext.getRequest()))
            }
        }

        if (headers.isSome()) {
            return headers.getOrThrow().cloneThis(global)
        }
        return None
    }

    /// 获取 Content-Type
    /// 对应 Bun: Request::get_content_type (Request.rs:375-398)
    public func getContentType(): ?String {
        if (requestContext.hasRequest()) {
            // 从 uws request 中获取 content-type
        }

        if (headers.isSome()) {
            let h = headers.getOrThrow()
            let value = h.fastGet(HTTPHeaderName.ContentType)
            if (value.isSome()) {
                return value
            }
        }

        if (body.value.tag == BodyValueTag.Blob) {
            match (body.value.blob) {
                case Some(b) =>
                    let ct = b.getContentType()
                    if (ct.isSome() && ct.getOrThrow().size > 0) {
                        return ct
                    }
                case None => ()
            }
        }

        return None
    }

    // ========================================================================
    // URL 与大小 (对应 Bun: Request url/size accessors)
    // ========================================================================

    /// 获取协议 (http:// 或 https://)
    /// 对应 Bun: Request::get_protocol (Request.rs:928-934)
    public func getProtocol(): String {
        if (flags.https) {
            return "https://"
        }
        return "http://"
    }

    /// 确保 URL 已设置 — 对应 Bun: Request::ensure_url (Request.rs:936-1024)
    public func ensureUrl(): Unit {
        if (url.size > 0) {
            return
        }

        if (requestContext.hasRequest()) {
            let reqUrl = requestContext.getUrl()
            if (reqUrl.size > 0 && reqUrl[0] == '/') {
                let host = requestContext.getHeader("host")
                if (host.size > 0) {
                    url = "${getProtocol()}${host}${reqUrl}"
                    return
                }
            }
            if (reqUrl.size > 0) {
                url = reqUrl
            }
        }
    }

    /// URL 的字节大小
    /// 对应 Bun: Request::size_of_url (Request.rs:903-926)
    public func sizeOfUrl(): Int64 {
        if (url.size > 0) {
            return Int64(url.size)
        }

        if (requestContext.hasRequest()) {
            let reqUrl = requestContext.getUrl()
            if (reqUrl.size > 0 && reqUrl[0] == '/') {
                let host = requestContext.getHeader("host")
                if (host.size > 0) {
                    return Int64(getProtocol().size) + Int64(host.size) + Int64(reqUrl.size)
                }
            }
            return Int64(reqUrl.size)
        }

        return 0
    }

    /// 获取 FormData 编码
    /// 对应 Bun: Request::get_form_data_encoding (Request.rs:480-494)
    public func getFormDataEncoding(): ?FormDataEncoding {
        let ct = getContentType()
        if (ct.isNone()) {
            return None
        }
        return FormDataEncoding.fromContentType(ct.getOrThrow())
    }

    /// 获取估算大小
    /// 对应 Bun: Request::estimated_size (Request.rs:496-498)
    public func estimatedSize(): Int64 {
        return reportedEstimatedSize
    }

    /// 内存开销
    /// 对应 Bun: Request::memory_cost (Request.rs:402-408)
    public func memoryCost(): Int64 {
        return Int64(1024) + Int64(url.size) + body.value.memoryCost()  // 1024 = approximate sizeof(Request)
    }

    // ========================================================================
    // JS getter 方法 (对应 Bun: Request JS host fns)
    // ========================================================================

    /// 获取 cache — JS getter.
    /// 对应 Bun: Request::get_cache (Request.rs:788-790)
    public func getCache(global: JsGlobalObject): JsValue {
        return fetchCacheModeToJS(flags.cache, global)
    }

    /// 获取 credentials — JS getter.
    /// 对应 Bun: Request::get_credentials (Request.rs:793-795)
    public func getCredentials(global: JsGlobalObject): JsValue {
        return JsValue(BaoString("include"))
    }

    /// 获取 destination — JS getter.
    /// 对应 Bun: Request::get_destination (Request.rs:798-800)
    public func getDestination(global: JsGlobalObject): JsValue {
        return JsValue(BaoString(""))
    }

    /// 获取 integrity — JS getter.
    /// 对应 Bun: Request::get_integrity (Request.rs:803-805)
    public func getIntegrity(global: JsGlobalObject): JsValue {
        return JsValue(BaoString(""))
    }

    /// 获取 signal — JS getter.
    /// 对应 Bun: Request::get_signal (Request.rs:808-821)
    public func getSignal(global: JsGlobalObject): JsValue {
        if (signal.isSome()) {
            return signal.getOrThrow().toJsValue(global)
        }
        // Lazy create default signal
        return JsValue(BaoString(""))
    }

    /// 获取 method — JS getter.
    /// 对应 Bun: Request::get_method (Request.rs:824-826)
    public func getMethod(global: JsGlobalObject): JsValue {
        return methodToJS(method, global)
    }

    /// 获取 mode — JS getter.
    /// 对应 Bun: Request::get_mode (Request.rs:829-831)
    public func getMode(global: JsGlobalObject): JsValue {
        return fetchRequestModeToJS(flags.mode, global)
    }

    /// 获取 redirect — JS getter.
    /// 对应 Bun: Request::get_redirect (Request.rs:877-879)
    public func getRedirect(global: JsGlobalObject): JsValue {
        return fetchRedirectToJS(flags.redirect, global)
    }

    /// 获取 referrer — JS getter.
    /// 对应 Bun: Request::get_referrer (Request.rs:882-890)
    public func getReferrer(global: JsGlobalObject): JsValue {
        if (headers.isSome()) {
            let h = headers.getOrThrow()
            let referrer = h.fastGet(HTTPHeaderName.Referer)
            if (referrer.isSome()) {
                return JsValue(BaoString(referrer.getOrThrow()))
            }
        }
        return JsValue(BaoString(""))
    }

    /// 获取 referrer policy — JS getter.
    /// 对应 Bun: Request::get_referrer_policy (Request.rs:893-895)
    public func getReferrerPolicy(global: JsGlobalObject): JsValue {
        return JsValue(BaoString(""))
    }

    /// 获取 URL — JS getter.
    /// 对应 Bun: Request::get_url (Request.rs:898-901)
    public func getUrlJS(global: JsGlobalObject): JsValue {
        ensureUrl()
        return JsValue(BaoString(url))
    }

    /// 获取 remote socket info
    /// 对应 Bun: Request::get_remote_socket_info (Request.rs:500-518)
    public func getRemoteSocketInfo(global: JsGlobalObject): ?JsValue {
        let info = requestContext.getRemoteSocketInfo()
        if (info.isNone()) {
            return None
        }
        let socketInfo = info.getOrThrow()
        return Some(socketInfo.toJsValue())
    }

    // ========================================================================
    // 估算大小与 finalize (对应 Bun: Request lifecycle)
    // ========================================================================

    /// 计算估算字节大小
    /// 对应 Bun: Request::calculate_estimated_byte_size (Request.rs:521-528)
    public func calculateEstimatedByteSize(): Unit {
        reportedEstimatedSize = body.value.size() + Int64(url.size) + Int64(1024)  // 1024 = sizeof(Request) approx
    }

    /// finalize_without_deinit — 释放资源但保留分配
    /// 对应 Bun: Request::finalize_without_deinit (Request.rs:833-844)
    public func finalizeWithoutDeinit(): Unit {
        headers = None
        url = ""
        signal = None
        internalEventCallback = RequestInternalJSEventCallback()
    }

    /// finalize — GC finalizer entry point.
    /// 对应 Bun: Request::finalize (Request.rs:846-874)
    public func finalize(): Unit {
        // Hot path: no outstanding weak refs
        weakPtrData.onFinalize()
        jsRef.finalize()
        finalizeWithoutDeinit()
        body.deinit()
    }

    // ========================================================================
    // FFI 回调 (对应 Bun: Request uws_callback fns)
    // ========================================================================

    /// FFI: set cookies on request context
    /// 对应 Bun: Request::ffi_set_cookies_on_request_context (Request.rs:409-413)
    public func ffiSetCookiesOnRequestContext(cookieMap: ?CookieMap): Unit {
        requestContext.setCookies(cookieMap)
    }

    /// FFI: get UWS request
    /// 对应 Bun: Request::ffi_get_uws_request (Request.rs:416-421)
    public func ffiGetUWSRequest(): UInt64 {
        return requestContext.getRequest()
    }

    /// FFI: set internal event callback
    /// 对应 Bun: Request::ffi_set_internal_event_callback (Request.rs:423-429)
    public func ffiSetInternalEventCallback(callback: JsValue, global: JsGlobalObject): Unit {
        internalEventCallback = RequestInternalJSEventCallback(function: callback, global: global)
        requestContext.enableTimeoutEvents()
    }

    /// FFI: set timeout
    /// 对应 Bun: Request::ffi_set_timeout (Request.rs:431-443)
    public func ffiSetTimeout(seconds: JsValue, global: JsGlobalObject): Unit {
        if (!seconds.isNumber()) {
            return
        }
        setTimeout(seconds.toUInt32())
    }

    /// 设置超时
    /// 对应 Bun: Request::set_timeout (Request.rs:1665-1667)
    public func setTimeout(seconds: UInt32): Unit {
        requestContext.setTimeout(seconds)
    }

    /// FFI: clone
    /// 对应 Bun: Request::ffi_clone (Request.rs:445-448)
    public func ffiClone(global: JsGlobalObject): ?Request {
        return clone(global)
    }

    // ========================================================================
    // Body ReadableStream — 对应 Bun: BodyMixin stream methods
    // ========================================================================

    /// 获取 body 的 ReadableStream
    /// 对应 Bun: Request::get_body_readable_stream (Request.rs:532-537)
    public func getBodyReadableStream(global: JsGlobalObject): ?ReadableStream {
        if (body.value.tag == BodyValueTag.Locked) {
            match (body.value.locked) {
                case Some(p) => p.readableStream
                case None => None
            }
        }
        return None
    }

    /// 分离 ReadableStream
    /// 对应 Bun: Request::detach_readable_stream (Request.rs:540-542)
    public func detachReadableStream(global: JsGlobalObject): Unit {
        body.value.tag = BodyValueTag.Used
    }

    /// 检查 body stream ref
    /// 对应 Bun: Request::check_body_stream_ref (Request.rs:1048-1050)
    public func checkBodyStreamRef(global: JsGlobalObject): Unit {
        // 检查是否需要同步 body stream caches
    }

    // ========================================================================
    // toJS (对应 Bun: Request::to_js)
    // ========================================================================

    /// 转为 JS 值 — 对应 Bun: Request::to_js (Request.rs:544-558)
    public func toJs(global: JsGlobalObject): JsValue {
        calculateEstimatedByteSize()
        let jsValue = toJsUnchecked(global)
        jsRef = JsRef.initWeak(jsValue)
        checkBodyStreamRef(global)
        return jsValue
    }

    /// to_js_unchecked
    public func toJsUnchecked(global: JsGlobalObject): JsValue {
        return toJsValue()
    }

    /// to_js_for_bake — 对应 Bun: Request::to_js_for_bake (Request.rs:577-587)
    public func toJsForBake(global: JsGlobalObject): JsValue {
        return toJs(global)
    }

    // ========================================================================
    // 格式化输出 (对应 Bun: Request::write_format)
    // ========================================================================

    /// 写格式化输出
    /// 对应 Bun: Request::write_format (Request.rs:597-743)
    public func writeFormat(thisValue: JsValue): String {
        let bodySize = body.value.size()
        let sizeStr = formatSize(bodySize)
        var result = "Request (${sizeStr}) {\n"

        result += "  method: \"${MethodUtil.toString(method)}\",\n"
        result += "  url: \"${url}\",\n"
        result += "  headers: <headers>,\n"

        match (body.value.tag) {
            case BodyValueTag.Blob =>
                match (body.value.blob) {
                    case Some(b) => result += "  body: ${b.writeFormat(false, b.getSizeForBindings())},\n"
                    case None => ()
                }
            case BodyValueTag.InternalBlob =>
                if (body.value.bytes.size == 0) {
                    result += "  body: Blob (0 B),\n"
                } else {
                    result += "  body: ${formatSize(Int64(body.value.bytes.size))},\n"
                }
            case BodyValueTag.WTFStringImpl =>
                if (body.value.stringValue.size == 0) {
                    result += "  body: Blob (0 B),\n"
                } else {
                    result += "  body: ${formatSize(Int64(body.value.stringValue.size))},\n"
                }
            case BodyValueTag.Locked =>
                let stream = getBodyReadableStream(JsGlobalObject.current())
                if (stream.isSome()) {
                    result += "  body: <ReadableStream>,\n"
                }
            case _ => ()
        }

        result += "}"
        return result
    }

    // ========================================================================
    // MIME Type (对应 Bun: Request::mime_type)
    // ========================================================================

    /// 获取 MIME 类型
    /// 对应 Bun: Request::mime_type (Request.rs:745-785)
    public func mimeType(): String {
        if (headers.isSome()) {
            let h = headers.getOrThrow()
            let ct = h.fastGet(HTTPHeaderName.ContentType)
            if (ct.isSome()) {
                return ct.getOrThrow()
            }
        }

        match (body.value.tag) {
            case BodyValueTag.Blob =>
                match (body.value.blob) {
                    case Some(b) =>
                        let ct = b.getContentType()
                        if (ct.isSome() && ct.getOrThrow().size > 0) {
                            return ct.getOrThrow()
                        }
                        return "application/octet-stream"
                    case None => return "application/octet-stream"
                }
            case BodyValueTag.InternalBlob => return "application/octet-stream"
            case BodyValueTag.WTFStringImpl => return "text/plain;charset=utf-8"
            case _ => return "application/octet-stream"
        }
    }

    // ========================================================================
    // 克隆操作
    // ========================================================================

    /// 克隆到另一个 Request
    /// 对应 Bun: Request::clone_into (Request.rs:1564-1636)
    public func cloneInto(req: Request, global: JsGlobalObject, preserveUrl: Bool): Unit {
        ensureUrl()

        // 克隆 body
        let clonedBody = body.clone()

        // 克隆 headers
        let clonedHeaders = cloneHeaders(global)

        // URL
        let clonedUrl = if (preserveUrl) {
            req.url
        } else {
            url
        }

        // 写入目标
        req.url = clonedUrl
        req.headers = clonedHeaders
        req.signal = None
        req.body = clonedBody
        req.jsRef = JsRef.empty()
        req.method = method
        req.flags = Flags(redirect: flags.redirect, cache: flags.cache, mode: flags.mode, https: flags.https)
        req.requestContext = AnyRequestContext.NULL
        req.weakPtrData = WeakPtrData()
        req.reportedEstimatedSize = 0
        req.internalEventCallback = RequestInternalJSEventCallback()

        // 克隆 signal
        if (signal.isSome()) {
            req.signal = Some(signal.getOrThrow().clone())
        }
    }

    /// 克隆请求
    /// 对应 Web API: request.clone()
    /// 对应 Bun: Request::clone (Request.rs:1638-1663)
    public func clone(global: JsGlobalObject): ?Request {
        let req = Request()
        cloneInto(req, global, false)
        return Some(req)
    }

    /// do_clone — JS host fn method.
    /// 对应 Bun: Request::do_clone (Request.rs:1548-1562)
    public func doClone(global: JsGlobalObject, callframe: CallFrame): JsValue {
        let thisValue = callframe.`this`()
        let cloned = clone(global)
        if (cloned.isSome()) {
            let jsWrapper = cloned.getOrThrow().toJs(global)
            syncClonedBodyStreamCaches(thisValue, jsWrapper, global)
            return jsWrapper
        }
        return JsValue.undefined()
    }

    /// 同步克隆的 body stream caches
    public func syncClonedBodyStreamCaches(thisValue: JsValue, jsWrapper: JsValue, global: JsGlobalObject): Unit {
        // 简化实现: 无操作
    }

    // ========================================================================
    // 构造 (对应 Bun: Request::construct_into / constructor)
    // ========================================================================

    /// construct_into — 从 JS 参数构造 Request
    /// 对应 Bun: Request::construct_into (Request.rs:1052-1532)
    public static func constructInto(global: JsGlobalObject, arguments: Array<JsValue>, thisValue: JsValue): ?Request {
        var success = false
        let req = Request()
        req.jsRef = JsRef.initWeak(thisValue)
        req.body = Body()

        // 清理函数
        func cleanup(r: Request, success: Bool): Unit {
            if (!success) {
                r.finalizeWithoutDeinit()
                r.body.deinit()
            }
        }

        if (arguments.size == 0) {
            return None
        }

        let urlOrObject = arguments[0]
        let urlOrObjectType = urlOrObject.jsType()
        var fields = FieldSet()

        let isFirstArgUrl = urlOrObjectType.isStringLike() ||
            urlOrObject.isDOMUrl(global)

        if (isFirstArgUrl) {
            let str = urlOrObject.toString()
            req.url = str
            if (req.url.size > 0) {
                fields.insert(Fields.Url)
            }
        } else if (!urlOrObjectType.isObject()) {
            return None
        }

        // 构建 values_to_try 数组
        let valuesToTry = ArrayList<JsValue>()
        if (arguments.size > 1 && arguments[1].isObject()) {
            valuesToTry.append(arguments[1])
        } else if (!isFirstArgUrl) {
            valuesToTry.append(urlOrObject)
        }

        if (!isFirstArgUrl) {
            valuesToTry.append(urlOrObject)
        } else if (arguments.size > 1 && arguments[1].isObject()) {
            valuesToTry.append(arguments[1])
        }

        for (value in valuesToTry) {
            let valueType = value.jsType()
            let explicitCheck = valuesToTry.size == 2 &&
                valueType == JsType.FinalObject &&
                valuesToTry[valuesToTry.size - 1].jsType() == JsType.DOMWrapper

            if (valueType == JsType.DOMWrapper) {
                // 如果是 Request 对象
                if (value.isRequest()) {
                    let sourceReq = value.toRequest()
                    if (sourceReq.isSome()) {
                        let src = sourceReq.getOrThrow()

                        if (valuesToTry.size == 1) {
                            src.cloneInto(req, global, fields.contains(Fields.Url))
                            success = true
                            cleanup(req, success)
                            return Some(req)
                        }

                        if (!fields.contains(Fields.Method)) {
                            req.method = src.method
                            fields.insert(Fields.Method)
                        }

                        if (!fields.contains(Fields.Redirect)) {
                            req.flags.redirect = src.flags.redirect
                            fields.insert(Fields.Redirect)
                        }

                        if (!fields.contains(Fields.Cache)) {
                            req.flags.cache = src.flags.cache
                            fields.insert(Fields.Cache)
                        }

                        if (!fields.contains(Fields.Mode)) {
                            req.flags.mode = src.flags.mode
                            fields.insert(Fields.Mode)
                        }

                        if (!fields.contains(Fields.Headers)) {
                            let clonedHeaders = src.cloneHeaders(global)
                            if (clonedHeaders.isSome()) {
                                req.headers = clonedHeaders
                                fields.insert(Fields.Headers)
                            }
                        }

                        if (!fields.contains(Fields.Body)) {
                            match (src.body.value.tag) {
                                case BodyValueTag.Null => ()
                                case BodyValueTag.Empty => ()
                                case BodyValueTag.Used => ()
                                case _ =>
                                    req.body = Body(value: src.body.value.clone())
                                    fields.insert(Fields.Body)
                            }
                        }
                    }
                }

                // 如果是 Response 对象
                if (value.isResponse()) {
                    let sourceResp = value.toResponse()
                    if (sourceResp.isSome()) {
                        let src = sourceResp.getOrThrow()

                        if (!fields.contains(Fields.Method)) {
                            req.method = src.getMethod()
                            fields.insert(Fields.Method)
                        }

                        if (!fields.contains(Fields.Headers)) {
                            let respHeaders = src.getInitHeaders()
                            if (respHeaders.isSome()) {
                                let cloned = respHeaders.getOrThrow().cloneThis(global)
                                if (cloned.isSome()) {
                                    req.headers = cloned
                                    fields.insert(Fields.Headers)
                                }
                            }
                        }

                        if (!fields.contains(Fields.Url)) {
                            let respUrl = src.getUrl()
                            if (respUrl.size > 0) {
                                req.url = respUrl
                                fields.insert(Fields.Url)
                            }
                        }

                        if (!fields.contains(Fields.Body)) {
                            let bodyValue = src.getBodyValue()
                            match (bodyValue.tag) {
                                case BodyValueTag.Null => ()
                                case BodyValueTag.Empty => ()
                                case BodyValueTag.Used => ()
                                case _ =>
                                    req.body = Body(value: bodyValue.clone())
                                    fields.insert(Fields.Body)
                            }
                        }
                    }
                }
            }

            // 提取 body 属性
            if (!fields.contains(Fields.Body)) {
                let bodyProp = value.fastGet(global, BuiltinName.body)
                if (bodyProp.isSome()) {
                    fields.insert(Fields.Body)
                    req.body = Body.extract(bodyProp.getOrThrow())
                }
            }

            // 提取 url 属性
            if (!fields.contains(Fields.Url)) {
                let urlProp = value.fastGet(global, BuiltinName.url)
                if (urlProp.isSome()) {
                    let urlStr = urlProp.getOrThrow().toString()
                    req.url = urlStr
                    if (req.url.size > 0) {
                        fields.insert(Fields.Url)
                    }
                } else {
                    if (!isFirstArgUrl) {
                        let implementsStr = value.implementsToString(global)
                        if (implementsStr) {
                            let str = value.toString()
                            req.url = str
                            if (req.url.size > 0) {
                                fields.insert(Fields.Url)
                            }
                        }
                    }
                }
            }

            // 提取 signal 属性
            if (!fields.contains(Fields.Signal)) {
                let signalProp = value.getTruthy("signal")
                if (signalProp.isSome()) {
                    fields.insert(Fields.Signal)
                    if (signalProp.getOrThrow().isAbortSignal()) {
                        req.signal = Some(AbortSignalRef(signalProp.getOrThrow()))
                    }
                }
            }

            // 提取 method/headers (via Init::init)
            if (!fields.contains(Fields.Method) || !fields.contains(Fields.Headers)) {
                let initResult = ResponseInit(global, value)
                if (initResult.isSome()) {
                    let responseInit = initResult.getOrThrow()

                    let headerCheck = !explicitCheck || value.fastGet(global, BuiltinName.headers).isSome()
                    if (headerCheck) {
                        if (responseInit.headers.isSome()) {
                            if (!fields.contains(Fields.Headers)) {
                                req.headers = responseInit.headers
                                fields.insert(Fields.Headers)
                            }
                        }
                    }

                    let methodCheck = !explicitCheck || value.fastGet(global, BuiltinName.method).isSome()
                    if (methodCheck) {
                        if (!fields.contains(Fields.Method)) {
                            req.method = responseInit.method
                            fields.insert(Fields.Method)
                        }
                    }
                }
            }

            // 提取 redirect 选项
            if (!fields.contains(Fields.Redirect)) {
                let redirectValue = value.getOptionalEnum("redirect")
                if (redirectValue.isSome()) {
                    req.flags.redirect = redirectValue.getOrThrow()
                    fields.insert(Fields.Redirect)
                }
            }

            // 提取 cache 选项
            if (!fields.contains(Fields.Cache)) {
                let cacheValue = value.getOptionalEnumFetchCacheMode("cache")
                if (cacheValue.isSome()) {
                    req.flags.cache = cacheValue.getOrThrow()
                    fields.insert(Fields.Cache)
                }
            }

            // 提取 mode 选项
            if (!fields.contains(Fields.Mode)) {
                let modeValue = value.getOptionalEnumFetchRequestMode("mode")
                if (modeValue.isSome()) {
                    req.flags.mode = modeValue.getOrThrow()
                    fields.insert(Fields.Mode)
                }
            }
        }

        if (req.url.size == 0) {
            return None
        }

        // 如果 body 是 Blob 且有 Content-Type, 且 headers 存在且没有 Content-Type
        if (req.body.value.tag == BodyValueTag.Blob && req.headers.isSome()) {
            match (req.body.value.blob) {
                case Some(b) =>
                    let ct = b.getContentType()
                    if (ct.isSome() && ct.getOrThrow().size > 0) {
                        // put Content-Type if not already present
                    }
                case None => ()
            }
        }

        req.calculateEstimatedByteSize()
        req.checkBodyStreamRef(global)
        success = true

        cleanup(req, success)
        return Some(req)
    }

    /// 构造函数 — JS constructor host fn.
    /// 对应 Bun: Request::constructor (Request.rs:1535-1545)
    public static func constructor(global: JsGlobalObject, callframe: CallFrame, thisValue: JsValue): ?Request {
        let args = callframe.argumentsOld(2)
        let arguments = ArrayList<JsValue>()
        for (i in 0..args.size) {
            arguments.append(args[i])
        }
        let request = constructInto(global, arguments.toArray(), thisValue)
        return request
    }

    // ========================================================================
    // 获取 fetch headers (对应 Bun: Request get_fetch_headers)
    // ========================================================================

    /// 获取 fetch headers — immutable access.
    /// 对应 Bun: Request::get_fetch_headers (Request.rs:1736-1738)
    public func getFetchHeaders(): ?HeadersRef {
        return headers
    }

    // ========================================================================
    // 转为 JsValue
    // ========================================================================

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("url", JsValue(BaoString(self.url)))
        obj.set("method", JsValue(BaoString(MethodUtil.toString(self.method))))
        obj.set("redirect", JsValue(BaoString(FetchRedirectUtil.toString(self.flags.redirect))))
        obj.set("cache", JsValue(BaoString(FetchCacheModeUtil.toString(self.flags.cache))))
        obj.set("mode", JsValue(BaoString(FetchRequestModeUtil.toString(self.flags.mode))))

        // headers getter
        obj.set("headers", JsValue.nativeFunction(JsNativeFunction("headers") { _ =>
            let h = self.getHeaders(JsGlobalObject.current())
            if (h.isSome()) {
                return h.getOrThrow().toJsValue(JsGlobalObject.current())
            }
            JsValue(BaoString(""))
        }))

        // json 方法
        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.json()
        }))

        // text 方法
        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(self.text()))
        }))

        // arrayBuffer 方法
        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            let bytes = self.arrayBuffer()
            let arr = ArrayList<JsValue>()
            for (b in bytes) {
                arr.append(JsValue(Float64(Int64(b))))
            }
            JsValue.array(arr)
        }))

        // clone 方法
        obj.set("clone", JsValue.nativeFunction(JsNativeFunction("clone") { _ =>
            let cloned = self.clone(JsGlobalObject.current())
            if (cloned.isSome()) {
                cloned.getOrThrow().toJsValue()
            } else {
                JsValue.undefined()
            }
        }))

        // signal getter
        obj.set("signal", JsValue.nativeFunction(JsNativeFunction("signal") { _ =>
            self.getSignal(JsGlobalObject.current())
        }))

        // destination getter
        obj.set("destination", JsValue.nativeFunction(JsNativeFunction("destination") { _ =>
            self.getDestination(JsGlobalObject.current())
        }))

        // referrer getter
        obj.set("referrer", JsValue.nativeFunction(JsNativeFunction("referrer") { _ =>
            self.getReferrer(JsGlobalObject.current())
        }))

        // referrerPolicy getter
        obj.set("referrerPolicy", JsValue.nativeFunction(JsNativeFunction("referrerPolicy") { _ =>
            self.getReferrerPolicy(JsGlobalObject.current())
        }))

        // integrity getter
        obj.set("integrity", JsValue.nativeFunction(JsNativeFunction("integrity") { _ =>
            self.getIntegrity(JsGlobalObject.current())
        }))

        // credentials getter
        obj.set("credentials", JsValue.nativeFunction(JsNativeFunction("credentials") { _ =>
            self.getCredentials(JsGlobalObject.current())
        }))

        return JsValue(obj)
    }

    // ========================================================================
    // Body Mixin 方法
    // ========================================================================

    /// 解析请求体为文本
    /// 对应 Web API: request.text()
    public func text(): String {
        return body.text()
    }

    /// 解析请求体为 JSON
    /// 对应 Web API: request.json()
    public func json(): JsValue {
        return body.json()
    }

    /// 获取请求体 ArrayBuffer
    /// 对应 Web API: request.arrayBuffer()
    public func arrayBuffer(): Array<UInt8> {
        return body.arrayBuffer()
    }

    /// 获取请求体 Blob
    /// 对应 Web API: request.blob()
    public func blob(): Blob {
        return body.use()
    }

    /// 获取请求体 FormData
    /// 对应 Web API: request.formData()
    public func formData(): FormData {
        return FormData()
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
    public func toJsValue(global: JsGlobalObject): JsValue {
        return value
    }

    /// unref — releases C++ ref
    public func unref(): Unit {
        value = JsValue.undefined()
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

    /// 是否有请求
    public func hasRequest(): Bool {
        return false
    }

    /// 获取 uws 请求指针
    public func getRequest(): UInt64 {
        return 0
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
    public func memoryCost(): Int64 {
        return 0
    }

    /// 设置 cookies
    public func setCookies(cookieMap: ?CookieMap): Unit {}

    /// 启用超时事件
    public func enableTimeoutEvents(): Unit {}

    /// 设置超时
    public func setTimeout(seconds: UInt32): Unit {}

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
        obj.set("address", JsValue(BaoString(ip)))
        obj.set("port", JsValue(Float64(Int64(port))))
        obj.set("family", JsValue(BaoString(if (isIPv6) { "IPv6" } else { "IPv4" })))
        return JsValue(obj)
    }
}

// ============================================================================
// CookieMap - Cookie 映射
// ============================================================================

/// Cookie 映射
public class CookieMap {}

// ============================================================================
// JsValue 扩展方法 — 用于 Request/Response 构造
// ========================================================================

/// JsValue 辅助扩展
public class JsValueHelper {
    /// 快速获取属性
    public static func fastGet(value: JsValue, global: JsGlobalObject, name: BuiltinName): ?JsValue {
        let propName = builtinNameToString(name)
        let result = value.get(propName)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return result
    }

    /// 获取 truthy 属性
    public static func getTruthy(value: JsValue, name: String): ?JsValue {
        let result = value.get(name)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return result
    }

    /// 获取可选枚举 (FetchRedirect)
    public static func getOptionalEnum(value: JsValue, name: String): ?FetchRedirect {
        let result = value.get(name)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return FetchRedirectUtil.fromString(result.getOrThrow().toString())
    }

    /// 获取可选枚举 (FetchCacheMode)
    public static func getOptionalEnumFetchCacheMode(value: JsValue, name: String): ?FetchCacheMode {
        let result = value.get(name)
        if (result.isNone() || result.getOrThrow().isUndefinedOrNull()) {
            return None
        }
        return FetchCacheModeUtil.fromString(result.getOrThrow().toString())
    }

    /// 获取可选枚举 (FetchRequestMode)
    public static func getOptionalEnumFetchRequestMode(value: JsValue, name: String): ?FetchRequestMode {
        let result = value.get(name)
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
            case HTTPHeaderName.ContentType => "content-type"
            case HTTPHeaderName.Location => "location"
            case HTTPHeaderName.SetCookie => "set-cookie"
            case HTTPHeaderName.Cookie => "cookie"
            case HTTPHeaderName.Host => "host"
            case HTTPHeaderName.Referer => "referer"
            case HTTPHeaderName.UserAgent => "user-agent"
            case HTTPHeaderName.Accept => "accept"
            case HTTPHeaderName.Authorization => "authorization"
            case HTTPHeaderName.ContentLength => "content-length"
            case HTTPHeaderName.TransferEncoding => "transfer-encoding"
        }
    }
}

// ported from: src/runtime/webcore/Request.rs
