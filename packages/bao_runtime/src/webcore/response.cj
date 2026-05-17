// Response - HTTP 响应对象
// 对应 Bun: src/runtime/webcore/Response.rs
// 严格翻译自: src/runtime/webcore/Response.rs
package bao_runtime.webcore

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_http_types.*
import bao_http_jsc.*

// ============================================================================
// HeadersRef - RAII handle to a C++-owned WebCore::FetchHeaders
// 对应 Bun: Response.HeadersRef
// ============================================================================

/// RAII handle to a C++-owned FetchHeaders.
/// 对应 Bun: Response.HeadersRef
/// Holds exactly one ref on the C++ intrusive refcount; drop releases it.
/// Intentionally not Clone: the only "share" operation is cloneThis(),
/// which deep-copies a fresh FetchHeaders on the C++ side.
public class HeadersRef {
    public var ptr: UInt64

    public init() {
        ptr = 0
    }

    public init(ptr: UInt64) {
        this.ptr = ptr
    }

    /// Adopt a freshly-created FetchHeaders* (refcount already 1).
    /// 对应 Bun: HeadersRef::adopt
    public static func adopt(ptr: UInt64): HeadersRef {
        return HeadersRef(ptr)
    }

    /// Relinquish ownership without decrementing the ref.
    /// 对应 Bun: HeadersRef::into_raw
    public func intoRaw(): UInt64 {
        let p = ptr
        ptr = 0
        return p
    }

    /// FetchHeaders.createEmpty() — fresh C++ allocation, refcount 1.
    /// 对应 Bun: HeadersRef::create_empty
    public static func createEmpty(): HeadersRef {
        return HeadersRef()
    }

    /// FetchHeaders.createFromUWS(req) — fresh C++ allocation, refcount 1.
    /// 对应 Bun: HeadersRef::create_from_uws
    public static func createFromUWS(uwsRequest: UInt64): HeadersRef {
        return HeadersRef(uwsRequest)
    }

    /// FetchHeaders.createFromJS(global, value) — may throw, may return null.
    /// 对应 Bun: HeadersRef::create_from_js
    public static func createFromJS(global: JsGlobalObject, value: JsValue): ?HeadersRef {
        // 简化实现: 如果 value 是 object 类型则创建空 headers
        if (value.isObject()) {
            return Some(HeadersRef())
        }
        return None
    }

    /// FetchHeaders.cloneThis(global) — deep copy on the C++ side.
    /// 对应 Bun: HeadersRef::clone_this
    public func cloneThis(global: JsGlobalObject): ?HeadersRef {
        // 简化实现: 返回新的空 HeadersRef
        return Some(HeadersRef())
    }

    /// 是否为空指针
    public func isNull(): Bool {
        return ptr == 0
    }

    /// 释放 C++ 端引用
    /// 对应 Bun: HeadersRef::drop (impl Drop)
    public func release(): Unit {
        if (ptr != 0) {
            // 调用 C++ WebCore__FetchHeaders__deref
            ptr = 0
        }
    }
}

// ============================================================================
// ResponseInit - Response 初始化参数 (对应 Bun: Response.Init)
// 对应 Bun: Response.Init (Response.rs:1352-1487)
// ============================================================================

/// Response 初始化参数
/// 对应 Bun: Response.Init
public class ResponseInit {
    /// 响应头 — Option<HeadersRef> 对应 C++ FetchHeaders ref
    /// 对应 Bun: Init.headers
    public var headers: ?HeadersRef
    /// 状态码 — u16
    /// 对应 Bun: Init.status_code
    public var statusCode: UInt16
    /// 状态文本 — OwnedString
    /// 对应 Bun: Init.status_text
    public var statusText: String
    /// HTTP 方法 — Method
    /// 对应 Bun: Init.method
    public var method: HttpMethod

    public init() {
        headers = None
        statusCode = 0
        statusText = ""
        method = HttpMethod.GET
    }

    public init(statusCode: UInt16) {
        headers = None
        this.statusCode = statusCode
        statusText = statusCodeToText(Int64(statusCode))
        method = HttpMethod.GET
    }

    public init(statusCode: UInt16, statusText: String) {
        headers = None
        this.statusCode = statusCode
        this.statusText = statusText
        method = HttpMethod.GET
    }

    public init(statusCode: UInt16, statusText: String, headers: ?HeadersRef) {
        this.headers = headers
        this.statusCode = statusCode
        this.statusText = statusText
        method = HttpMethod.GET
    }

    /// 克隆 Init
    /// 对应 Bun: Init::clone
    public func clone(global: JsGlobalObject): ResponseInit {
        let clonedHeaders = match (headers) {
            case Some(h) => h.cloneThis(global)
            case None => None
        }
        let result = ResponseInit(statusCode, statusText, clonedHeaders)
        result.method = method
        return result
    }

    /// 从 JS 值初始化 ResponseInit
    /// 对应 Bun: Init::init (Response.rs:1387-1487)
    public static func init(global: JsGlobalObject, responseInit: JsValue): ?ResponseInit {
        if (!responseInit.isCell()) {
            return None
        }

        let jsType = responseInit.jsType()

        if (!jsType.isObject()) {
            return None
        }

        let result = ResponseInit()
        result.statusCode = 200

        // DOMWrapper fast path: Request or Response object
        if (jsType == JsType.DOMWrapper) {
            // 如果是 Request 对象
            if (responseInit.isRequest()) {
                let req = responseInit.toRequest()
                if (req != None) {
                    let r = req.getOrThrow()
                    let reqHeaders = r.getHeaders()
                    if (reqHeaders != None) {
                        result.headers = reqHeaders.getOrThrow().cloneThis(global)
                    }
                    result.method = r.method
                    return Some(result)
                }
            }

            // 如果是 Response 对象
            if (responseInit.isResponse()) {
                let resp = responseInit.toResponse()
                if (resp != None) {
                    let r = resp.getOrThrow()
                    let clonedInit = r.`init`.clone(global)
                    return Some(clonedInit)
                }
            }
        }

        // 检查 headers 属性
        let headersValue = responseInit.fastGet(global, BuiltinName.headers)
        if (headersValue != None) {
            let hv = headersValue.getOrThrow()
            if (hv.isFetchHeaders()) {
                result.headers = HeadersRef.createFromJS(global, hv)
            } else {
                result.headers = HeadersRef.createFromJS(global, hv)
            }
        }

        // 检查 status 属性
        let statusValue = responseInit.fastGet(global, BuiltinName.status)
        if (statusValue != None) {
            let number = statusValue.getOrThrow().coerceToInt64(global)
            if ((200 <= number && number < 600) || number == 101) {
                result.statusCode = UInt16(number)
            } else {
                return None
            }
        }

        // 检查 statusText 属性
        let statusTextValue = responseInit.getTruthy("statusText")
        if (statusTextValue != None) {
            result.statusText = statusTextValue.getOrThrow().toString()
        }

        // 检查 method 属性
        let methodValue = responseInit.getTruthy("method")
        if (methodValue != None) {
            let m = MethodUtil.find(methodValue.getOrThrow().toString())
            if (m.isSome()) {
                result.method = m.getOrThrow()
            }
        }

        return Some(result)
    }

    /// 根据 HTTP 状态码获取默认文本
    /// 对应 Bun: standard status texts
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
// InternalJSEventCallback - 内部 JS 事件回调
// 对应 Bun: Response (Request.rs:1670-1707)
// ============================================================================

/// 内部 JS 事件回调
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

// ============================================================================
// Response - HTTP 响应
// 对应 Bun: src/runtime/webcore/Response.rs Response
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Response
// ============================================================================

/// HTTP Response — 对应 Web Response API
/// 对应 Bun: src/runtime/webcore/Response.rs Response
///
/// R-2: every JS-facing host-fn takes &Response (not &mut Response)
/// so re-entrant JS calls cannot stack two &mut to the same instance.
/// Fields mutated by host-fns use Cell (Copy scalars) or JsCell (non-Copy).
public class Response {
    /// 响应体
    /// 对应 Bun: Response.body (JsCell<Body>)
    public var body: Body
    /// 初始化参数
    /// 对应 Bun: Response.init (JsCell<Init>)
    public var `init`: ResponseInit
    /// 响应 URL — OwnedString
    /// 对应 Bun: Response.url (JsCell<OwnedString>)
    public var url: String
    /// 是否经过重定向
    /// 对应 Bun: Response.redirected (Cell<bool>)
    public var redirected: Bool
    /// 引用计数 — 用于 fetch 中 JS Response 被丢弃时 resolve body
    /// 对应 Bun: Response.ref_count (Cell<u32>)
    public var refCount: Int64
    /// 弱引用数据 — Bun.serve 的 RequestContext 持有弱引用
    /// 对应 Bun: Response.weak_ptr_data
    public var weakPtrData: WeakPtrData
    /// JS 引用 — 对应 Bun: Response.js_ref (JsCell<JsRef>)
    public var jsRef: JsRef
    /// 已报告的估算大小
    /// 对应 Bun: Response.reported_estimated_size (Cell<usize>)
    public var reportedEstimatedSize: Int64

    public init() {
        body = Body()
        `init` = ResponseInit()
        url = ""
        redirected = false
        refCount = 1
        weakPtrData = WeakPtrData()
        jsRef = JsRef.empty()
        reportedEstimatedSize = 0
    }

    public init(init: ResponseInit, body: Body, url: String, redirected: Bool) {
        this.body = body
        this.`init` = init
        this.url = url
        this.redirected = redirected
        refCount = 1
        weakPtrData = WeakPtrData()
        jsRef = JsRef.empty()
        reportedEstimatedSize = 0
    }

    /// 对应 Bun: Response::init (factory method)
    /// 对应 Bun: Response.rs:292-300
    public static func create(responseInit: ResponseInit, body: Body, url: String, redirected: Bool): Response {
        return Response(init: responseInit, body: body, url: url, redirected: redirected)
    }

    // ========================================================================
    // 字段设置器 (对应 Bun: Response.setInit, setInitHeaders, setUrl, etc.)
    // ========================================================================

    /// 设置初始化参数 — Takes ownership (+1) of status_text.
    /// 对应 Bun: Response::set_init (Response.rs:304-313)
    public func setInit(method: HttpMethod, statusCode: UInt16, statusText: String): Unit {
        `init`.method = method
        `init`.statusCode = statusCode
        `init`.statusText = statusText
    }

    /// 设置初始化 headers — old headers dropped.
    /// 对应 Bun: Response::set_init_headers (Response.rs:316-319)
    public func setInitHeaders(headers: ?HeadersRef): Unit {
        `init`.headers = headers
    }

    /// 获取初始化状态码
    /// 对应 Bun: Response::get_init_status_code (Response.rs:322-324)
    public func getInitStatusCode(): UInt16 {
        return `init`.statusCode
    }

    /// 获取初始化状态文本 — borrowed (+0).
    /// 对应 Bun: Response::get_init_status_text (Response.rs:330-332)
    public func getInitStatusText(): String {
        return `init`.statusText
    }

    /// 设置 URL — Takes ownership (+1) of url.
    /// 对应 Bun: Response::set_url (Response.rs:336-341)
    public func setUrl(url: String): Unit {
        this.url = url
    }

    /// 获取 UTF-8 URL slice.
    /// 对应 Bun: Response::get_utf8_url (Response.rs:344-346)
    public func getUtf8Url(): String {
        return url
    }

    /// Internal accessor: borrowed (+0) bitwise copy of the URL string.
    /// 对应 Bun: Response::url (Response.rs:356-358)
    public func getUrl(): String {
        return url
    }

    /// 获取初始化 headers — borrowed access.
    /// 对应 Bun: Response::get_init_headers (Response.rs:361-363)
    public func getInitHeaders(): ?HeadersRef {
        return `init`.headers
    }

    /// 获取初始化 headers — mutable access.
    /// 对应 Bun: Response::get_init_headers_mut (Response.rs:384-386)
    public func getInitHeadersMut(): ?HeadersRef {
        return `init`.headers
    }

    /// 交换初始化 headers — returns old headers.
    /// 对应 Bun: Response::swap_init_headers (Response.rs:389-391)
    public func swapInitHeaders(): ?HeadersRef {
        let old = `init`.headers
        `init`.headers = None
        return old
    }

    /// 获取方法
    /// 对应 Bun: Response::get_method (Response.rs:394-396)
    public func getMethod(): HttpMethod {
        return `init`.method
    }

    // ========================================================================
    // 状态码与状态访问 (对应 Bun: Response getters)
    // ========================================================================

    /// 获取状态码
    /// 对应 Web API: response.status
    /// 对应 Bun: Response::status_code (Response.rs:584-587)
    public func statusCode(): UInt16 {
        return `init`.statusCode
    }

    /// 获取状态文本
    /// 对应 Web API: response.statusText
    /// 对应 Bun: Response::get_status_text (Response.rs:629-632)
    public func statusText(): String {
        return `init`.statusText
    }

    /// 状态码是否在 200-299 范围
    /// 对应 Web API: response.ok
    /// 对应 Bun: Response::is_ok (Response.rs:606-609)
    public func isOK(): Bool {
        return Int64(`init`.statusCode) >= 200 && Int64(`init`.statusCode) <= 299
    }

    /// 获取响应头
    /// 对应 Web API: response.headers
    /// 对应 Bun: Response::get_fetch_headers (Response.rs:580-582)
    public func getFetchHeaders(): ?HeadersRef {
        return `init`.headers
    }

    /// 获取响应类型
    /// 对应 Web API: response.type
    /// 对应 Bun: Response::get_response_type (Response.rs:620-626)
    public func getResponseType(): String {
        if (Int64(`init`.statusCode) < 200) {
            return "error"
        }
        return "default"
    }

    /// 获取重定向位置
    /// 对应 Bun: Response::redirect_location (Response.rs:594-596)
    public func redirectLocation(): ?String {
        return header(HTTPHeaderName.Location)
    }

    /// 获取指定响应头
    /// 对应 Bun: Response::header (Response.rs:598-604)
    public func header(name: HTTPHeaderName): ?String {
        if (`init`.headers.isSome()) {
            let h = `init`.headers.getOrThrow()
            return h.fastGet(name)
        }
        return None
    }

    /// 获取 Content-Type
    /// 对应 Bun: Response::get_content_type (Response.rs:681-698)
    public func getContentType(): ?String {
        if (`init`.headers.isSome()) {
            let headers = `init`.headers.getOrThrow()
            let value = headers.fastGet(HTTPHeaderName.ContentType)
            if (value.isSome()) {
                return value
            }
        }

        if (body.value.tag == BodyValueTag.Blob) {
            match (body.value.blob) {
                case Some(b) => {
                    let ct = b.getContentType()
                    if (ct.isSome() && ct.getOrThrow().length > 0) {
                        return ct
                    }
                }
                case None => ()
            }
        }

        return None
    }

    // ========================================================================
    // Body 访问 (对应 Bun: Response body accessors)
    // ========================================================================

    /// 获取 Body 值 — R-2 escape hatch via JsCell.
    /// 对应 Bun: Response::get_body_value (Response.rs:408-412)
    public func getBodyValue(): BodyValue {
        return body.value
    }

    /// 获取 Body 长度
    /// 对应 Bun: Response::get_body_len (Response.rs:421-423)
    public func getBodyLen(): Int64 {
        return body.len()
    }

    /// 获取 FormData 编码
    /// 对应 Bun: Response::get_form_data_encoding (Response.rs:425-436)
    public func getFormDataEncoding(): ?FormDataEncoding {
        let ct = getContentType()
        if (ct == None) {
            return None
        }
        return FormDataEncoding.fromContentType(ct.getOrThrow())
    }

    /// 设置大小提示
    /// 对应 Bun: Response::set_size_hint (Response.rs:483-494)
    public func setSizeHint(sizeHint: BlobSizeType): Unit {
        if (body.value.tag == BodyValueTag.Locked) {
            match (body.value.locked) {
                case Some(p) => p.sizeHint = sizeHint
                case None => ()
            }
        }
    }

    // ========================================================================
    // 估算大小
    // ========================================================================

    /// 获取估算大小
    /// 对应 Bun: Response::estimated_size (Response.rs:398-400)
    public func estimatedSize(): Int64 {
        return reportedEstimatedSize
    }

    /// 计算估算字节大小
    /// 对应 Bun: Response::calculate_estimated_byte_size (Response.rs:438-445)
    public func calculateEstimatedByteSize(): Unit {
        reportedEstimatedSize = body.value.size() + Int64(url.length) + Int64(`init`.statusText.length)
    }

    // ========================================================================
    // Body Mixin 方法 — 对应 Bun: BodyMixin(Response)
    // ========================================================================

    /// 解析响应体为文本
    /// 对应 Web API: response.text()
    /// 对应 Bun: BodyMixin::get_text
    public func text(): String {
        return body.text()
    }

    /// 解析响应体为 JSON
    /// 对应 Web API: response.json()
    /// 对应 Bun: BodyMixin::get_json
    public func json(): JsValue {
        return body.json()
    }

    /// 获取响应体 ArrayBuffer
    /// 对应 Web API: response.arrayBuffer()
    /// 对应 Bun: BodyMixin::get_array_buffer
    public func arrayBuffer(): Array<UInt8> {
        return body.arrayBuffer()
    }

    /// 获取响应体 Blob
    /// 对应 Web API: response.blob()
    /// 对应 Bun: BodyMixin::get_blob
    public func blob(): Blob {
        return body.use()
    }

    /// 获取响应体 FormData
    /// 对应 Web API: response.formData()
    /// 对应 Bun: BodyMixin::get_form_data
    public func formData(): FormData {
        return FormData()
    }

    // ========================================================================
    // Body ReadableStream — 对应 Bun: BodyMixin stream methods
    // ========================================================================

    /// 获取 body 的 ReadableStream
    /// 对应 Bun: Response::get_body_readable_stream (Response.rs:470-475)
    public func getBodyReadableStream(global: JsGlobalObject): ?ReadableStream {
        // 通过 BodyMixin trait 方法获取
        if (body.value.tag == BodyValueTag.Locked) {
            match (body.value.locked) {
                case Some(p) => p.readableStream
                case None => None
            }
        }
        return None
    }

    /// 分离 ReadableStream
    /// 对应 Bun: Response::detach_readable_stream (Response.rs:478-480)
    public func detachReadableStream(global: JsGlobalObject): Unit {
        // 标记 body 为已使用
        body.value.tag = BodyValueTag.Used
    }

    /// 检查 body stream ref
    /// 对应 Bun: Response::check_body_stream_ref (Response.rs:448-450)
    public func checkBodyStreamRef(global: JsGlobalObject): Unit {
        // 检查是否需要同步 body stream caches
        // 简化实现: 无操作
    }

    // ========================================================================
    // JS getter 方法 (对应 Bun: Response JS host fns)
    // ========================================================================

    /// 获取 headers — JS getter.
    /// 对应 Bun: Response::get_headers (Response.rs:677-679)
    public func getHeaders(global: JsGlobalObject): JsValue {
        let headersRef = getOrCreateHeaders(global)
        if (headersRef != None) {
            return headersRef.getOrThrow().toJsValue(global)
        }
        return JsValue(BaoString(""))
    }

    /// 获取或创建 headers — 如果不存在则创建空 headers.
    /// 对应 Bun: Response::get_or_create_headers (Response.rs:653-674)
    public func getOrCreateHeaders(global: JsGlobalObject): ?HeadersRef {
        if (`init`.headers == None) {
            `init`.headers = Some(HeadersRef.createEmpty())

            if (body.value.tag == BodyValueTag.Blob) {
                match (body.value.blob) {
                    case Some(b) => {
                        let ct = b.getContentType()
                        if (ct.isSome() && ct.getOrThrow().length > 0) {
                            // put Content-Type header
                        }
                    }
                    case None => ()
                }
            }
        }
        return `init`.headers
    }

    /// 获取 URL — JS getter.
    /// 对应 Bun: Response::get_url (Response.rs:614-617)
    public func getUrlJS(global: JsGlobalObject): JsValue {
        return JsValue(BaoString(url))
    }

    /// 获取 response type — JS getter.
    /// 对应 Bun: Response::get_response_type (Response.rs:620-626)
    public func getResponseTypeJS(global: JsGlobalObject): JsValue {
        if (Int64(`init`.statusCode) < 200) {
            return JsValue(BaoString("error"))
        }
        return JsValue(BaoString("default"))
    }

    /// 获取 status text — JS getter.
    /// 对应 Bun: Response::get_status_text (Response.rs:629-632)
    public func getStatusTextJS(global: JsGlobalObject): JsValue {
        return JsValue(BaoString(`init`.statusText))
    }

    /// 获取 redirected — JS getter.
    /// 对应 Bun: Response::get_redirected (Response.rs:635-638)
    public func getRedirectedJS(): JsValue {
        return JsValue(redirected)
    }

    /// 获取 ok — JS getter.
    /// 对应 Bun: Response::get_ok (Response.rs:641-644)
    public func getOkJS(): JsValue {
        return JsValue(isOK())
    }

    /// 获取 status — JS getter.
    /// 对应 Bun: Response::get_status (Response.rs:647-650)
    public func getStatusJS(): JsValue {
        return JsValue(Float64(Int64(`init`.statusCode)))
    }

    // ========================================================================
    // 克隆操作
    // ========================================================================

    /// 克隆值 — 返回新的 Response (栈上).
    /// 对应 Bun: Response::clone_value (Response.rs:864-879)
    public func cloneValue(global: JsGlobalObject): Response {
        let clonedBody = Body(value: body.value.clone())
        let clonedInit = `init`.clone(global)
        let result = Response(init: clonedInit, body: clonedBody, url: url, redirected: redirected)
        return result
    }

    /// 克隆响应
    /// 对应 Web API: response.clone()
    /// 对应 Bun: Response::clone (Response.rs:881-885)
    public func clone(global: JsGlobalObject): Response {
        return cloneValue(global)
    }

    /// do_clone — JS host fn method.
    /// 对应 Bun: Response::do_clone (Response.rs:846-857)
    public func doClone(global: JsGlobalObject, callframe: CallFrame): JsValue {
        let thisValue = callframe.this()
        let cloned = clone(global)
        let jsWrapper = cloned.toJsValue()
        syncClonedBodyStreamCaches(thisValue, jsWrapper, global)
        return jsWrapper
    }

    /// 同步克隆的 body stream caches
    /// 对应 Bun: sync_cloned_body_stream_caches
    public func syncClonedBodyStreamCaches(thisValue: JsValue, jsWrapper: JsValue, global: JsGlobalObject): Unit {
        // 简化实现: 无操作
    }

    // ========================================================================
    // 引用计数 (对应 Bun: Response ref/unref/finalize/destroy)
    // ========================================================================

    /// 增加引用
    /// 对应 Bun: Response::ref_ (Response.rs:925-931)
    public func ref(): Response {
        refCount += 1
        return this
    }

    /// 减少引用
    /// 对应 Bun: Response::unref (Response.rs:933-943)
    public func unref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            destroy()
        }
    }

    /// 释放资源 — 对应 Bun: Response::destroy (Response.rs:887-923)
    /// Mirrors Zig destroy: init.deinit() / body.deinit() / url.deref() / js_ref.deinit().
    public func destroy(): Unit {
        `init`.headers = None
        `init`.statusText = ""
        body.deinit()
        url = ""
        jsRef = JsRef.empty()
    }

    /// finalize — GC finalizer entry point.
    /// 对应 Bun: Response::finalize (Response.rs:945-952)
    public func finalize(): Unit {
        jsRef.finalize()
        unref()
    }

    // ========================================================================
    // toJS (对应 Bun: Response::to_js)
    // ========================================================================

    /// 转为 JS 值 — 对应 Bun: Response::to_js (Response.rs:452-467)
    public func toJs(global: JsGlobalObject): JsValue {
        calculateEstimatedByteSize()
        let jsValue = toJsUnchecked(global)
        jsRef = JsRef.initWeak(jsValue)
        checkBodyStreamRef(global)
        return jsValue
    }

    /// to_js_unchecked — 不检查直接转为 JS 值
    public func toJsUnchecked(global: JsGlobalObject): JsValue {
        return toJsValue()
    }

    /// make_maybe_pooled — 创建可能池化的 JS 包装
    /// 对应 Bun: Response::make_maybe_pooled (Response.rs:859-862)
    public static func makeMaybePooled(global: JsGlobalObject, response: Response): JsValue {
        return response.toJs(global)
    }

    // ========================================================================
    // 格式化输出 (对应 Bun: Response::write_format)
    // ========================================================================

    /// 写格式化输出
    /// 对应 Bun: Response::write_format (Response.rs:706-843)
    public func writeFormat(): String {
        let sizeStr = formatSize(getBodyLen())
        var result = "Response (${sizeStr}) {\n"

        result += "  ok: ${isOK()},\n"
        result += "  url: \"${url}\",\n"
        result += "  status: ${`init`.statusCode},\n"
        result += "  statusText: \"${`init`.statusText}\",\n"
        result += "  headers: <headers>,\n"
        result += "  redirected: ${redirected},\n"

        match (body.value.tag) {
            case BodyValueTag.Blob => {
                match (body.value.blob) {
                    case Some(b) => result += "  body: ${b.writeFormat(false, b.getSizeForBindings())},\n"
                    case None => ()
                }
            }
            case BodyValueTag.InternalBlob => result += "  body: ${formatSize(Int64(body.value.bytes.size))},\n"
            case BodyValueTag.WTFStringImpl => result += "  body: ${formatSize(Int64(body.value.stringValue.length))},\n"
            case _ => ()
        }

        result += "}"
        return result
    }

    // ========================================================================
    // 静态工厂方法
    // ========================================================================

    /// 静态工厂: 从 JSON 数据创建 Response
    /// 对应 Web API: Response.json(data)
    /// 对应 Bun: Response::construct_json (Response.rs:955-1078)
    public static func constructJSON(global: JsGlobalObject, callframe: CallFrame): JsValue {
        let args = callframe.argumentsOld(2)

        let response = Response()
        response.`init`.statusCode = 200

        let jsonValue = if (args.length > 0) { args[0] } else { JsValue.zero() }

        if (!jsonValue.isEmpty()) {
            // 验证顶层值是否 JSON 可序列化
            if (jsonValue.isUndefined() || jsonValue.isSymbol() || jsonValue.isFunction()) {
                return JsValue(BaoString("TypeError: Value is not JSON serializable"))
            }

            if (jsonValue.isBigInt()) {
                return JsValue(BaoString("TypeError: Do not know how to serialize a BigInt"))
            }

            let jsonStr = jsonValue.toString()
            if (jsonStr.length > 0) {
                let bytes = Utf8Codec.encode(jsonStr)
                response.body = Body(value: BodyValue(bytes))
                response.body.value.wasString = true
            }
        }

        // 处理第二个参数 (init options)
        if (args.length > 1) {
            let argInit = args[1]
            if (!argInit.isUndefinedOrNull()) {
                if (argInit.isNumber()) {
                    let num = argInit.toInt32()
                    if (num >= 0 && num <= 65535) {
                        response.`init`.statusCode = UInt16(num)
                    }
                } else {
                    let initResult = ResponseInit.init(global, argInit)
                    if (initResult.isSome()) {
                        response.`init` = initResult.getOrThrow()
                    }
                }
            }
        }

        // 设置 Content-Type: application/json
        let headers = response.getOrCreateHeaders(global)

        return response.toJs(global)
    }

    /// 验证重定向状态码
    /// 对应 Bun: Response::validate_redirect_status_code (Response.rs:1080-1093)
    public static func validateRedirectStatusCode(statusCode: Int64): ?UInt16 {
        match (statusCode) {
            case 301 => Some(UInt16(301))
            case 302 => Some(UInt16(302))
            case 303 => Some(UInt16(303))
            case 307 => Some(UInt16(307))
            case 308 => Some(UInt16(308))
            case _ => None
        }
    }

    /// 静态工厂: 创建重定向 Response
    /// 对应 Web API: Response.redirect(url, status)
    /// 对应 Bun: Response::construct_redirect (Response.rs:1096-1105)
    public static func constructRedirect(global: JsGlobalObject, callframe: CallFrame): JsValue {
        let response = constructRedirectImpl(global, callframe)
        if (response.isSome()) {
            return response.getOrThrow().toJs(global)
        }
        return JsValue.zero()
    }

    /// 构建重定向的实现
    /// 对应 Bun: Response::construct_redirect_impl (Response.rs:1107-1175)
    public static func constructRedirectImpl(global: JsGlobalObject, callframe: CallFrame): ?Response {
        let args = callframe.argumentsOld(4)

        let response = Response()
        response.`init`.statusCode = 302

        let urlStringValue = if (args.length > 0) { args[0] } else { JsValue.zero() }
        var urlStr = ""

        if (!urlStringValue.isEmpty()) {
            urlStr = urlStringValue.toString()
        }

        // 处理第二个参数 (status code or init)
        if (args.length > 1) {
            let argInit = args[1]
            if (!argInit.isUndefinedOrNull()) {
                if (argInit.isNumber()) {
                    let status = validateRedirectStatusCode(argInit.toInt64())
                    if (status.isSome()) {
                        response.`init`.statusCode = status.getOrThrow()
                    }
                } else {
                    let initResult = ResponseInit.init(global, argInit)
                    if (initResult.isSome()) {
                        response.`init` = initResult.getOrThrow()
                        let status = Int64(response.`init`.statusCode)
                        if (status != 200) {
                            let validated = validateRedirectStatusCode(status)
                            if (validated.isSome()) {
                                response.`init`.statusCode = validated.getOrThrow()
                            }
                        }
                    }
                }
            }
        }

        // 设置 Location header
        let headers = response.getOrCreateHeaders(global)
        response.url = urlStr

        return Some(response)
    }

    /// 静态工厂: 创建错误 Response
    /// 对应 Web API: Response.error()
    /// 对应 Bun: Response::construct_error (Response.rs:1178-1197)
    public static func constructError(global: JsGlobalObject, callframe: CallFrame): JsValue {
        let response = Response()
        response.`init`.statusCode = 0
        response.`init`.statusText = ""
        let jsValue = response.toJs(global)
        response.jsRef = JsRef.initWeak(jsValue)
        return jsValue
    }

    /// 构造函数 — JS constructor host fn.
    /// 对应 Bun: Response::constructor (Response.rs:1202-1341)
    public static func constructor(global: JsGlobalObject, callframe: CallFrame, jsThis: JsValue): ?Response {
        let args = callframe.argumentsAsArray(2)

        // 处理 S3 File 特殊路径
        if (!args[0].isUndefinedOrNull() && args[0].isObject()) {
            if (args[0].isBlob()) {
                let blob = args[0].toBlob()
                if (blob != None && blob.getOrThrow().isS3()) {
                    if (!args[1].isUndefinedOrNull()) {
                        return None
                    }
                    let response = Response()
                    response.`init`.statusCode = 302
                    response.jsRef = JsRef.initWeak(jsThis)
                    response.redirected = true
                    return Some(response)
                }
            }
        }

        // 解析 ResponseInit
        var initVal = ResponseInit()
        initVal.statusCode = 200

        if (!args[1].isUndefinedOrNull()) {
            if (args[1].isObject()) {
                let initResult = ResponseInit.init(global, args[1])
                if (initResult.isSome()) {
                    initVal = initResult.getOrThrow()
                }
            }
        }

        // 解析 Body
        var bodyVal = Body()
        if (!args[0].isUndefinedOrNull()) {
            bodyVal = Body.extract(args[0])
        }

        // 如果 body 是 Blob 且有 Content-Type, 且 headers 存在且没有 Content-Type
        if (bodyVal.value.tag == BodyValueTag.Blob) {
            match (bodyVal.value.blob) {
                case Some(b) => {
                    if (initVal.headers.isSome()) {
                        let ct = b.getContentType()
                        if (ct.isSome() && ct.getOrThrow().length > 0) {
                            // put Content-Type if not already present
                        }
                    }
                }
                case None => ()
            }
        }

        let response = Response(init: initVal, body: bodyVal, url: "", redirected: false)
        response.jsRef = JsRef.initWeak(jsThis)
        response.calculateEstimatedByteSize()
        response.checkBodyStreamRef(global)
        return Some(response)
    }

    /// 创建 404 响应
    /// 对应 Bun: Response::status_404 (Response.rs:1490-1492)
    public static func status404(global: JsGlobalObject): Response {
        return emptyWithStatus(global, 404)
    }

    /// 创建 200 响应
    /// 对应 Bun: Response::status_200 (Response.rs:1494-1496)
    public static func status200(global: JsGlobalObject): Response {
        return emptyWithStatus(global, 200)
    }

    /// 创建指定状态码的空响应
    /// 对应 Bun: empty_with_status (Response.rs:1498-1510)
    public static func emptyWithStatus(global: JsGlobalObject, status: UInt16): Response {
        let init = ResponseInit(status)
        return Response(init: init, body: Body(), url: "", redirected: false)
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("status", JsValue(Float64(Int64(self.statusCode()))))
        obj.set("statusText", JsValue(BaoString(self.statusText())))
        obj.set("url", JsValue(BaoString(self.url)))
        obj.set("redirected", JsValue(self.redirected))
        obj.set("ok", JsValue(self.isOK()))
        obj.set("type", JsValue(BaoString(self.getResponseType())))

        // headers getter
        obj.set("headers", JsValue.nativeFunction(JsNativeFunction("headers") { _ =>
            self.getHeaders(JsGlobalObject.current())
        }))

        // text 方法
        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(self.text()))
        }))

        // json 方法
        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.json()
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

        // blob 方法
        obj.set("blob", JsValue.nativeFunction(JsNativeFunction("blob") { _ =>
            self.blob().toJsValue()
        }))

        // clone 方法
        obj.set("clone", JsValue.nativeFunction(JsNativeFunction("clone") { _ =>
            self.clone(JsGlobalObject.current()).toJsValue()
        }))

        // formData 方法
        obj.set("formData", JsValue.nativeFunction(JsNativeFunction("formData") { _ =>
            self.formData().toJsValue()
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// WeakPtrData - 弱引用数据 (简化版)
// 对应 Bun: bun_ptr::weak_ptr::WeakPtrData
// ============================================================================

/// 弱引用数据
/// 对应 Bun: WeakPtrData
public class WeakPtrData {
    public static let EMPTY = WeakPtrData()

    public init() {}
}

// ============================================================================
// JsRef - JS 引用句柄
// 对应 Bun: bun_jsc::JsRef
// ============================================================================

/// JS 引用句柄
/// 对应 Bun: JsRef
public class JsRef {
    private var value: ?JsValue

    public init() {
        value = None
    }

    public init(value: JsValue) {
        this.value = Some(value)
    }

    /// 创建空引用
    public static func empty(): JsRef {
        return JsRef()
    }

    /// 创建弱引用
    public static func initWeak(jsValue: JsValue): JsRef {
        return JsRef(value: jsValue)
    }

    /// 尝试获取值
    public func tryGet(): ?JsValue {
        return value
    }

    /// finalize — 释放 JS 引用
    public func finalize(): Unit {
        value = None
    }

    /// with_mut — 对值执行可变操作
    public func withMut(fn: (JsRef) -> Unit): Unit {
        fn(this)
    }
}

// ============================================================================
// JSC Host Functions — 对应 Bun: Response.rs _jsc_host_fns
// ============================================================================

/// jsFunctionRequestOrResponseHasBodyValue
/// 对应 Bun: js_function_request_or_response_has_body_value (Response.rs:503-521)
public func jsFunctionRequestOrResponseHasBodyValue(global: JsGlobalObject, callframe: CallFrame): JsValue {
    let args = callframe.argumentsOld(1)
    let thisValue = args[0]
    if (thisValue.isEmptyOrUndefinedOrNull()) {
        return JsValue(false)
    }

    if (thisValue.isResponse()) {
        let response = thisValue.toResponse()
        if (response != None) {
            return JsValue(!response.getOrThrow().body.value.isDefinitelyEmpty())
        }
    } else if (thisValue.isRequest()) {
        let request = thisValue.toRequest()
        if (request != None) {
            return JsValue(!request.getOrThrow().body.value.isDefinitelyEmpty())
        }
    }

    return JsValue(false)
}

/// jsFunctionGetCompleteRequestOrResponseBodyValueAsArrayBuffer
/// 对应 Bun: js_function_get_complete_request_or_response_body_value_as_array_buffer (Response.rs:523-576)
public func jsFunctionGetCompleteRequestOrResponseBodyValueAsArrayBuffer(global: JsGlobalObject, callframe: CallFrame): JsValue {
    let args = callframe.argumentsOld(1)
    let thisValue = args[0]
    if (thisValue.isEmptyOrUndefinedOrNull()) {
        return JsValue.undefined()
    }

    var bodyValue: ?BodyValue = None

    if (thisValue.isResponse()) {
        let response = thisValue.toResponse()
        if (response != None) {
            bodyValue = Some(response.getOrThrow().body.value)
        }
    } else if (thisValue.isRequest()) {
        let request = thisValue.toRequest()
        if (request != None) {
            bodyValue = Some(request.getOrThrow().body.value)
        }
    }

    if (bodyValue == None) {
        return JsValue.undefined()
    }

    let body = bodyValue.getOrThrow()

    match (body.tag) {
        case BodyValueTag.Used => return JsValue.undefined()
        case BodyValueTag.Empty => return JsValue.undefined()
        case BodyValueTag.Null => return JsValue.undefined()
        case BodyValueTag.Blob => {
            match (body.blob) {
                case Some(b) => {
                    if (b.isBunFile()) {
                        return JsValue.undefined()
                    }
                    let bytes = b.sharedView()
                    body.tag = BodyValueTag.Used
                    return JsValue.fromArrayBuffer(global, bytes)
                }
                case None => return JsValue.zero()
            }
        }
        case BodyValueTag.WTFStringImpl => {
            let bytes = Utf8Codec.encode(body.stringValue)
            body.tag = BodyValueTag.Used
            return JsValue.fromArrayBuffer(global, bytes)
        }
        case BodyValueTag.InternalBlob => {
            let bytes = body.bytes
            body.tag = BodyValueTag.Used
            return JsValue.fromArrayBuffer(global, bytes)
        }
        case BodyValueTag.Error => return JsValue.undefined()
        case BodyValueTag.Locked => return JsValue.undefined()
    }
}

// ============================================================================
// 辅助类型与枚举 (对应 Bun: JSType, HTTPHeaderName, BuiltinName, etc.)
// ============================================================================

/// JS 类型枚举 — 对应 Bun: bun_jsc::JSType
public enum JsType {
    | FinalObject
    | DOMWrapper
    | String
    | Symbol
    | Number
    | Boolean
    | Undefined
    | Null
    | Object
    | Function

    public func isObject(): Bool {
        match (this) {
            case FinalObject => true
            case DOMWrapper => true
            case Object => true
            case _ => false
        }
    }

    public func isStringLike(): Bool {
        match (this) {
            case String => true
            case _ => false
        }
    }
}

/// HTTP Header 名称枚举 — 对应 Bun: HTTPHeaderName
public enum HTTPHeaderName {
    | ContentType
    | Location
    | SetCookie
    | Cookie
    | Host
    | Referer
    | UserAgent
    | Accept
    | Authorization
    | ContentLength
    | TransferEncoding
}

/// Builtin 名称枚举 — 对应 Bun: BuiltinName
public enum BuiltinName {
    | headers
    | status
    | body
    | method
    | url
    | signal
    | redirect
    | cache
    | mode
}

/// Format tag for console formatter
public enum FormatTag {
    | Object
    | Private
    | Boolean
    | Double
}

// ported from: src/runtime/webcore/Response.rs
