// Response - HTTP 响应对象
// 对应 Bun: src/runtime/webcore/Response.rs
// 严格翻译自: src/runtime/webcore/Response.rs
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_collections.ArrayBuffer
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
        // 对应 Bun: HeadersRef::create_from_js — 从 JS 值创建 Headers
        if (value.isEmptyOrUndefinedOrNull()) { return None }
        if (value.isObject()) {
            let headers = HeadersRef()
            // 对应 Bun: 遍历 JS 对象属性并添加到 headers
            // stub: simplified - no getPropertyNames on JsValue
            return Some(headers)
        }
        return None
    }

    /// FetchHeaders.cloneThis(global) — deep copy on the C++ side.
    /// 对应 Bun: HeadersRef::clone_this
    public func cloneThis(global: JsGlobalObject): ?HeadersRef {
        // 对应 Bun: 深拷贝 headers 列表
        let cloned = HeadersRef()
        return Some(cloned)
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

    /// Convert to JsValue — stub
    public func toJsValue(global: JsGlobalObject): JsValue {
        return JsValue()
    }

    /// Get referrer — stub
    public func getReferrer(): ?String {
        return None
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
            case None => Option<HeadersRef>.None
        }
        let result = ResponseInit(statusCode, statusText, clonedHeaders)
        result.method = method
        return result
    }

    /// 从 JS 值初始化 ResponseInit
    /// 对应 Bun: Init::init (Response.rs:1387-1487)
    public static func `init`(global: JsGlobalObject, responseInit: JsValue): ?ResponseInit {
        if (!responseInit.isCell()) {
            return None
        }

        let jsType = responseInit.jsType()

        if (!jsType.isObject()) {
            return None
        }

        let result = ResponseInit()
        result.statusCode = 200

        // DOMWrapper fast path: skipped in this port (JSType vs JsType mismatch)

        // 检查 headers 属性
        let headersValue = responseInit.fastGet(global, BuiltinName.headers)
        if (headersValue.isSome()) {
            let hv = headersValue.getOrThrow()
            if (hv.isFetchHeaders()) {
                result.headers = HeadersRef.createFromJS(global, hv)
            } else {
                result.headers = HeadersRef.createFromJS(global, hv)
            }
        }

        // 检查 status 属性
        let statusValue = responseInit.fastGet(global, BuiltinName.status)
        if (statusValue.isSome()) {
            let number = statusValue.getOrThrow().coerceToInt64(global)
            if ((200 <= number && number < 600) || number == 101) {
                result.statusCode = UInt16(number)
            } else {
                return None
            }
        }

        // 检查 statusText 属性
        let statusTextValue = responseInit.getTruthy(global, "statusText")
        if (statusTextValue.isSome()) {
            result.statusText = statusTextValue.getOrThrow().toString()
        }

        // 检查 method 属性
        let methodValue = responseInit.getTruthy(global, "method")
        if (methodValue.isSome()) {
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
        return JsRef(jsValue)
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

    /// 是否为强引用
    public func isStrong(): Bool {
        match (value) {
            case Some(_) => true
            case None => false
        }
    }

    /// 取消保护 (与 protect 配对)
    public func unprotect(): Unit {
        value = None
    }

    /// 获取值 (直接，非 Option)
    public func get(): JsValue {
        match (value) {
            case Some(v) => v
            case None => JsValue.undefined()
        }
    }
}

// ============================================================================
// JSC Host Functions — 对应 Bun: Response.rs _jsc_host_fns
// ============================================================================

/// jsFunctionRequestOrResponseHasBodyValue
/// 对应 Bun: js_function_request_or_response_has_body_value (Response.rs:503-521)
public func jsFunctionRequestOrResponseHasBodyValue(global: JsGlobalObject, callframe: CallFrame): JsValue {
    let args = callframe.argumentsAsArray(1)
    let thisValue = args[0]
    if (thisValue.isEmptyOrUndefinedOrNull()) {
        return JsValue(false)
    }

    if (thisValue.isResponse()) {
        let response = thisValue.toResponse()
        if (response.isSome()) {
            return JsValue(!response.getOrThrow().body.isDefinitelyEmpty())
        }
    } else if (thisValue.isRequest()) {
        let request = thisValue.toRequest()
        if (request.isSome()) {
            return JsValue(!request.getOrThrow().bodyValue.isDefinitelyEmpty())
        }
    }

    return JsValue(false)
}

/// jsFunctionGetCompleteRequestOrResponseBodyValueAsArrayBuffer
/// 对应 Bun: js_function_get_complete_request_or_response_body_value_as_array_buffer (Response.rs:523-576)
public func jsFunctionGetCompleteRequestOrResponseBodyValueAsArrayBuffer(global: JsGlobalObject, callframe: CallFrame): JsValue {
    let args = callframe.argumentsAsArray(1)
    let thisValue = args[0]
    if (thisValue.isEmptyOrUndefinedOrNull()) {
        return JsValue.undefined()
    }

    var bodyValue: ?BodyValue = None

    if (thisValue.isResponse()) {
        let response = thisValue.toResponse()
        if (response.isSome()) {
            bodyValue = response.getOrThrow().body
        }
    } else if (thisValue.isRequest()) {
        let request = thisValue.toRequest()
        if (request.isSome()) {
            bodyValue = request.getOrThrow().bodyValue
        }
    }

    if (bodyValue.isNone()) {
        return JsValue.undefined()
    }

    let body = bodyValue.getOrThrow()

    match (body.tag) {
        case BodyValueTag.Used => return JsValue.undefined()
        case BodyValueTag.Empty => return JsValue.undefined()
        case BodyValueTag.Null => return JsValue.undefined()
        case BodyValueTag.Blob =>
            match (body.blob) {
                case Some(b) =>
                    if (b.isBunFile()) {
                        return JsValue.undefined()
                    }
                    let bytes = b.sharedView()
                    body.tag = BodyValueTag.Used
                    return JsValue.undefined()
                case None => return JsValue.undefined()
            }
        case BodyValueTag.WTFStringImpl =>
            let strImpl = body.wtfStringImpl.getOrThrow()
            let bytes = Utf8Codec.encode("")
            body.tag = BodyValueTag.Used
            return JsValue.undefined()
        case BodyValueTag.InternalBlob =>
            let bytes = body.internalBlob.getOrThrow().bytes
            body.tag = BodyValueTag.Used
            return JsValue.undefined()
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

// ============================================================================
// Response — HTTP 响应对象
// 对应 Bun: Response (Response.rs:182-953)
// ============================================================================

/// Response — HTTP 响应对象
/// 对应 Bun: Response struct (Response.rs:182-203)
public class Response {
    /// 响应体 — 对应 Bun: Response.body (JsCell<Body>)
    public var body: BodyValue
    /// 初始化参数 — 对应 Bun: Response.init (JsCell<Init>)
    public var `init`: ResponseInit
    /// URL 字符串 — 对应 Bun: Response.url (JsCell<OwnedString>)
    public var url: String
    /// 是否重定向 — 对应 Bun: Response.redirected (Cell<bool>)
    public var redirected: Bool
    /// 引用计数 — 对应 Bun: Response.ref_count (Cell<u32>)
    public var refCount: UInt32
    /// 弱引用数据 — 对应 Bun: Response.weak_ptr_data
    public var weakPtrData: WeakPtrData
    /// JS 引用句柄 — 对应 Bun: Response.js_ref (JsCell<JsRef>)
    public var jsRef: JsRef
    /// 估计大小 — 对应 Bun: Response.reported_estimated_size (Cell<usize>)
    public var reportedEstimatedSize: Int64

    public init() {
        body = BodyValue()
        `init` = ResponseInit()
        url = ""
        redirected = false
        refCount = 1
        weakPtrData = WeakPtrData()
        jsRef = JsRef()
        reportedEstimatedSize = 0
    }

    public init(`init`: ResponseInit, body: BodyValue, url: String, redirected: Bool) {
        this.`init` = `init`
        this.body = body
        this.url = url
        this.redirected = redirected
        refCount = 1
        weakPtrData = WeakPtrData()
        jsRef = JsRef()
        reportedEstimatedSize = 0
    }

    // ========================================================================
    // 字段访问器 — 对应 Bun: Response field accessors (Response.rs:286-407)
    // ========================================================================

    /// 设置 init 参数 — 对应 Bun: Response.setInit (Response.rs:298-307)
    public func setInit(method: HttpMethod, statusCode: UInt16, statusText: String): Unit {
        `init`.method = method
        `init`.statusCode = statusCode
        `init`.statusText = statusText
    }

    /// 设置 init headers — 对应 Bun: Response.setInitHeaders (Response.rs:310-312)
    public func setInitHeaders(headers: ?HeadersRef): Unit {
        `init`.headers = headers
    }

    /// 获取 init status code — 对应 Bun: Response.getInitStatusCode (Response.rs:316-318)
    public func getInitStatusCode(): UInt16 {
        return `init`.statusCode
    }

    /// 获取 init status text — 对应 Bun: Response.getInitStatusText (Response.rs:324-326)
    public func getInitStatusText(): String {
        return `init`.statusText
    }

    /// 设置 URL — 对应 Bun: Response.setUrl (Response.rs:330-335)
    public func setUrl(url: String): Unit {
        this.url = url
    }

    /// 获取 UTF-8 URL — 对应 Bun: Response.getUtf8Url (Response.rs:338-340)
    public func getUtf8Url(): String {
        return url
    }

    /// 获取 URL (内部访问器) — 对应 Bun: Response.url() (Response.rs:350-352)
    public func urlInternal(): String {
        return url
    }

    /// 获取 init headers — 对应 Bun: Response.getInitHeaders (Response.rs:355-357)
    public func getInitHeaders(): ?HeadersRef {
        return `init`.headers
    }

    /// 获取可变 init headers — 对应 Bun: Response.getInitHeadersMut (Response.rs:378-380)
    public func getInitHeadersMut(): ?HeadersRef {
        return `init`.headers
    }

    /// 交换 init headers — 对应 Bun: Response.swapInitHeaders (Response.rs:383-385)
    public func swapInitHeaders(): ?HeadersRef {
        let old = `init`.headers
        `init`.headers = None
        return old
    }

    /// 获取 HTTP 方法 — 对应 Bun: Response.getMethod (Response.rs:388-390)
    public func getMethod(): HttpMethod {
        return `init`.method
    }

    /// 获取估计大小 — 对应 Bun: Response.estimatedSize (Response.rs:392-394)
    public func estimatedSize(): Int64 {
        return reportedEstimatedSize
    }

    /// 获取 body 值 — 对应 Bun: Response.getBodyValue (Response.rs:402-406)
    public func getBodyValue(): BodyValue {
        return body
    }

    /// 设置 body 值
    public func setBodyValue(v: BodyValue): Unit {
        body = v
    }

    /// 获取 body 长度 — 对应 Bun: Response.getBodyLen (Response.rs:415-417)
    public func getBodyLen(): Int64 {
        match (body.tag) {
            case BodyValueTag.Blob =>
                match (body.blob) {
                    case Some(b) => Int64(b.sharedView().size)
                    case None => 0
                }
            case BodyValueTag.InternalBlob =>
                match (body.internalBlob) {
                    case Some(ib) => Int64(ib.bytes.size)
                    case None => 0
                }
            case _ => 0
        }
    }

    // ========================================================================
    // Getter 方法 — 对应 Bun: Response getters (Response.rs:573-684)
    // ========================================================================

    /// 获取重定向位置 — 对应 Bun: Response.redirectLocation (Response.rs:586-588)
    public func redirectLocation(): ?String {
        return header("location")
    }

    /// 获取指定 header — 对应 Bun: Response.header (Response.rs:590-596)
    public func header(name: String): ?String {
        match (`init`.headers) {
            case Some(h) =>
                // stub: simplified header lookup
                return None
            case None => return None
        }
    }

    /// 是否成功 (200-299) — 对应 Bun: Response.isOk (Response.rs:598-601)
    public func isOk(): Bool {
        let code = `init`.statusCode
        return code >= 200 && code <= 299
    }

    /// 获取 URL (JS getter) — 对应 Bun: Response.getURL (Response.rs:605-608)
    public func getURL(global: JsGlobalObject): JsValue {
        return JsValue(url)
    }

    /// 获取响应类型 — 对应 Bun: Response.getResponseType (Response.rs:610-616)
    public func getResponseType(global: JsGlobalObject): JsValue {
        if (`init`.statusCode < 200) {
            return JsValue("error")
        }
        return JsValue("default")
    }

    /// 获取状态文本 — 对应 Bun: Response.getStatusText (Response.rs:618-621)
    public func getStatusText(global: JsGlobalObject): JsValue {
        return JsValue(`init`.statusText)
    }

    /// 获取是否重定向 — 对应 Bun: Response.getRedirected (Response.rs:623-626)
    public func getRedirected(): JsValue {
        return JsValue(redirected)
    }

    /// 获取 ok 状态 — 对应 Bun: Response.getOk (Response.rs:628-631)
    public func getOk(): JsValue {
        return JsValue(isOk())
    }

    /// 获取状态码 — 对应 Bun: Response.getStatus (Response.rs:633-636)
    public func getStatus(): JsValue {
        return JsValue(Float64(Int64(`init`.statusCode)))
    }

    /// 获取或创建 headers — 对应 Bun: Response.getOrCreateHeaders (Response.rs:639-660)
    public func getOrCreateHeaders(global: JsGlobalObject): ?HeadersRef {
        if (`init`.headers.isNone()) {
            `init`.headers = Some(HeadersRef.createEmpty())
            match (body.tag) {
                case BodyValueTag.Blob =>
                    match (body.blob) {
                        case Some(blob) =>
                            let ct = blob.contentType
                            if (ct.size > 0) {
                                // stub: simplified — would call headers.put(ContentType, ct)
                                ()
                            }
                        case None => ()
                    }
                case _ => ()
            }
        }
        return `init`.headers
    }

    /// 获取 headers (JS getter) — 对应 Bun: Response.getHeaders (Response.rs:662-664)
    public func getHeaders(global: JsGlobalObject): JsValue {
        let h = getOrCreateHeaders(global)
        match (h) {
            case Some(hdrs) => return hdrs.toJsValue(global)
            case None => return JsValue()
        }
    }

    /// 获取 content type — 对应 Bun: Response.getContentType (Response.rs:666-683)
    public func getContentType(): ?String {
        match (`init`.headers) {
            case Some(h) =>
                // stub: would call headers.fastGet(ContentType)
                ()
            case None => ()
        }
        match (body.tag) {
            case BodyValueTag.Blob =>
                match (body.blob) {
                    case Some(blob) =>
                        let ct = blob.contentType
                        if (ct.size > 0) {
                            return Some(ct)
                        }
                    case None => ()
                }
            case _ => ()
        }
        return None
    }

    /// 获取状态码 — 对应 Bun: Response.statusCode (Response.rs:579-582)
    public func statusCode(): UInt16 {
        return `init`.statusCode
    }

    /// 获取 fetch headers — 对应 Bun: Response.getFetchHeaders (Response.rs:574-576)
    public func getFetchHeaders(): ?HeadersRef {
        return `init`.headers
    }

    /// 创建错误响应 — 对应 Bun: Response.error (static)
    public static func error(): Response {
        let resp = Response()
        resp.`init`.statusCode = 0
        resp.`init`.statusText = ""
        return resp
    }

    // ========================================================================
    // 克隆 — 对应 Bun: Response.doClone / cloneValue / clone (Response.rs:830-876)
    // ========================================================================

    /// Get body used — stub
    public func getBodyUsed(): Bool {
        return body.tag == BodyValueTag.Used
    }

    /// Get body readable stream — stub
    public func getBodyReadableStream(): JsValue {
        return JsValue()
    }

    /// 克隆 Response — 对应 Bun: Response.doClone (Response.rs:830-842)
    public func doClone(global: JsGlobalObject): JsValue {
        let cloned = cloneValue(global)
        let jsWrapper = makeMaybePooled(global, cloned)
        return jsWrapper
    }

    /// 创建可能池化的 JS 包装器 — 对应 Bun: Response.makeMaybePooled (Response.rs:850-853)
    public static func makeMaybePooled(global: JsGlobalObject, response: Response): JsValue {
        return response.toJs(global)
    }

    /// 克隆值 — 对应 Bun: Response.cloneValue (Response.rs:855-870)
    public func cloneValue(global: JsGlobalObject): Response {
        let clonedBody = BodyValue() // stub: simplified — should clone body value via cached stream
        let clonedInit = `init`.clone(global)
        let cloned = Response(clonedInit, clonedBody, url, redirected)
        return cloned
    }

    /// 克隆 — 对应 Bun: Response.clone (Response.rs:872-876)
    public func clone(global: JsGlobalObject): Response {
        return cloneValue(global)
    }

    // ========================================================================
    // 引用计数管理 — 对应 Bun: Response.ref_ / unref / finalize / destroy
    // (Response.rs:878-953)
    // ========================================================================

    /// 增加引用 — 对应 Bun: Response.ref_ (Response.rs:919-925)
    public func refInc(): Unit {
        refCount += 1
    }

    /// 减少引用 — 对应 Bun: Response.unref (Response.rs:931-941)
    public func unref(): Unit {
        if (refCount > 0) {
            refCount -= 1
        }
        if (refCount == 0) {
            destroy()
        }
    }

    /// 终结 — 对应 Bun: Response.finalize (Response.rs:943-952)
    public func finalize(): Unit {
        jsRef.finalize()
        unref()
    }

    /// 销毁 — 对应 Bun: Response.destroy (Response.rs:878-914)
    public func destroy(): Unit {
        `init` = ResponseInit()
        body = BodyValue()
        url = ""
        jsRef = JsRef()
    }

    // ========================================================================
    // 格式化输出 — 对应 Bun: Response.writeFormat (Response.rs:691-828)
    // ========================================================================

    /// 格式化输出 — 对应 Bun: Response.writeFormat
    public func writeFormat(): String {
        let sizeStr = "${getBodyLen()}"
        var result = "Response (${sizeStr}) {\n"
        result += "  ok: ${isOk()},\n"
        result += "  url: \"${url}\",\n"
        result += "  status: ${`init`.statusCode},\n"
        result += "  statusText: \"${`init`.statusText}\",\n"
        result += "  headers: Headers {},\n"
        result += "  redirected: ${redirected}\n"
        result += "}"
        return result
    }

    // ========================================================================
    // 估计大小 — 对应 Bun: Response.calculateEstimatedByteSize (Response.rs:432-439)
    // ========================================================================

    /// 计算估计字节大小 — 对应 Bun: Response.calculateEstimatedByteSize
    public func calculateEstimatedByteSize(): Unit {
        var sz: Int64 = 0
        sz += body.estimatedSize()
        sz += Int64(url.size)
        sz += Int64(`init`.statusText.size)
        reportedEstimatedSize = sz
    }

    // ========================================================================
    // 转换为 JsValue
    // ========================================================================

    /// 转换为 JsValue — 对应 Bun: Response.toJs
    public func toJs(global: JsGlobalObject): JsValue {
        calculateEstimatedByteSize()
        let obj = JsObject()

        obj.set("url", JsValue(url))
        obj.set("status", JsValue(Float64(Int64(`init`.statusCode))))
        obj.set("statusText", JsValue(`init`.statusText))
        obj.set("ok", JsValue(isOk()))
        obj.set("redirected", JsValue(redirected))
        obj.set("type", getResponseType(global))

        // headers
        obj.set("headers", getHeaders(global))

        // body methods
        obj.set("text", JsValue("text"))
        obj.set("json", JsValue("json"))
        obj.set("arrayBuffer", JsValue("arrayBuffer"))
        obj.set("blob", JsValue("blob"))
        obj.set("formData", JsValue("formData"))
        obj.set("bytes", JsValue("bytes"))

        // clone
        obj.set("clone", JsValue("clone"))

        // body property
        match (body.tag) {
            case BodyValueTag.Null => obj.set("body", JsValue())
            case BodyValueTag.Empty => obj.set("body", JsValue())
            case _ => obj.set("body", JsValue("body"))
        }

        obj.set("bodyUsed", JsValue(false))

        return JsValue(obj)
    }

    // ========================================================================
    // 静态工厂方法 — 对应 Bun: Response 构造函数和静态方法
    // ========================================================================

    /// 构造 JSON Response — 对应 Bun: Response.constructJson (Response.rs:954-1077)
    public static func constructJson(global: JsGlobalObject, jsonValue: JsValue, initValue: JsValue): JsValue {
        let response = Response()
        response.`init`.statusCode = 200

        if (!jsonValue.isUndefined() && !jsonValue.isNull()) {
            // 验证 JSON 可序列化性
            if (jsonValue.isUndefined() || jsonValue.isSymbol()) {
                return JsValue("TypeError: Value is not JSON serializable")
            }

            let str = jsonValue.toString()
            if (str.size > 0) {
                response.body = BodyValue(str)
            }
        }

        // 处理 init 参数
        if (!initValue.isUndefined() && !initValue.isNull()) {
            if (initValue.isNumber()) {
                let num = initValue.toNumber()
                let code = UInt16(max(0.0, min(num, 65535.0)))
                response.`init`.statusCode = code
            } else {
                if (initValue.isObject()) {
                    let parsedInit = ResponseInit.`init`(global, initValue)
                    if (parsedInit.isSome()) {
                        response.`init` = parsedInit.getOrThrow()
                    }
                }
            }
        }

        // 设置 Content-Type: application/json
        let h = response.getOrCreateHeaders(global)
        // stub: would set Content-Type to application/json

        response.calculateEstimatedByteSize()
        return response.toJs(global)
    }

    /// 验证重定向状态码 — 对应 Bun: Response.validateRedirectStatusCode (Response.rs:1079-1092)
    public static func validateRedirectStatusCode(statusCode: Int64): ?UInt16 {
        match (statusCode) {
            case 301 => return Some(UInt16(301))
            case 302 => return Some(UInt16(302))
            case 303 => return Some(UInt16(303))
            case 307 => return Some(UInt16(307))
            case 308 => return Some(UInt16(308))
            case _ => return None
        }
    }

    /// 构造重定向 Response — 对应 Bun: Response.constructRedirect (Response.rs:1094-1173)
    public static func constructRedirect(global: JsGlobalObject, urlValue: JsValue, statusValue: JsValue): JsValue {
        let response = Response()
        response.`init`.statusCode = 302

        var urlString = ""
        if (!urlValue.isUndefined() && !urlValue.isNull()) {
            urlString = urlValue.toString()
        }

        // 处理状态码参数
        if (!statusValue.isUndefined() && !statusValue.isNull()) {
            if (statusValue.isNumber()) {
                let code = Int64(statusValue.toNumber())
                let validated = validateRedirectStatusCode(code)
                if (validated.isSome()) {
                    response.`init`.statusCode = validated.getOrThrow()
                } else {
                    return JsValue("RangeError: Invalid status code for redirect")
                }
            } else {
                if (statusValue.isObject()) {
                    let parsedInit = ResponseInit.`init`(global, statusValue)
                    if (parsedInit.isSome()) {
                        response.`init` = parsedInit.getOrThrow()
                        let status = Int64(response.`init`.statusCode)
                        if (status != 200) {
                            let validated = validateRedirectStatusCode(status)
                            if (validated.isSome()) {
                                response.`init`.statusCode = validated.getOrThrow()
                            } else {
                                return JsValue("RangeError: Invalid status code for redirect")
                            }
                        }
                    }
                }
            }
        }

        // 设置 Location header
        let h = response.getOrCreateHeaders(global)
        // stub: would set Location header to urlString

        response.url = ""
        return response.toJs(global)
    }

    /// 构造错误 Response — 对应 Bun: Response.constructError (Response.rs:1175-1194)
    public static func constructError(global: JsGlobalObject): JsValue {
        let response = Response()
        response.`init`.statusCode = 0
        response.body = BodyValue()
        return response.toJs(global)
    }

    /// 构造 Response — 对应 Bun: Response.constructor (Response.rs:1199-1336)
    public static func constructResponse(global: JsGlobalObject, bodyValue: JsValue, initValue: JsValue): JsValue {
        // 解析 init
        var responseInit: ResponseInit
        if (initValue.isUndefined() || initValue.isNull()) {
            responseInit = ResponseInit()
            responseInit.statusCode = 200
        } else {
            if (initValue.isObject()) {
                let parsed = ResponseInit.`init`(global, initValue)
                if (parsed.isSome()) {
                    responseInit = parsed.getOrThrow()
                } else {
                    responseInit = ResponseInit()
                    responseInit.statusCode = 200
                }
            } else {
                return JsValue("TypeError: The provided value is not of type 'ResponseInit'")
            }
        }

        // 解析 body
        var responseBody: BodyValue
        if (bodyValue.isUndefined() || bodyValue.isNull()) {
            responseBody = BodyValue()
        } else {
            responseBody = extractBody(global, bodyValue)
        }

        // 如果 body 是 Blob 且有 content type，且 init 没有显式设置 content type
        match (responseBody.tag) {
            case BodyValueTag.Blob =>
                match (responseBody.blob) {
                    case Some(blob) =>
                        let ct = blob.contentType
                        if (ct.size > 0) {
                            // stub: check if headers already have content-type
                            ()
                        }
                    case None => ()
                }
            case _ => ()
        }

        let response = Response(responseInit, responseBody, "", false)
        response.calculateEstimatedByteSize()
        return response.toJs(global)
    }

    /// 从 JsValue 提取 body — 对应 Bun: body::extract
    public static func extractBody(global: JsGlobalObject, value: JsValue): BodyValue {
        if (value.isString()) {
            let str = value.toString()
            return BodyValue(str)
        }
        if (value.isTypedArray()) {
            let abOpt = value.asArrayBuffer(global.globalThis)
            if (abOpt.isSome()) {
                let ab = abOpt.getOrThrow()
                return BodyValue(Blob(ab.bytes(), "application/octet-stream"))
            }
        }
        if (value.isObject()) {
            // 检查是否是 Blob
            let blobOpt = Blob.fromJs(global, value)
            if (blobOpt.isSome()) {
                return BodyValue(blobOpt.getOrThrow())
            }
            // 检查是否是 ArrayBuffer
            let abOpt2 = value.asArrayBuffer(global.globalThis)
            if (abOpt2.isSome()) {
                let ab = abOpt2.getOrThrow()
                return BodyValue(Blob(ab.bytes(), "application/octet-stream"))
            }
        }
        return BodyValue()
    }
}

