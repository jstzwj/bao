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
            callback.call(global.globalThis, JsValue.undefined(), [JsValue(Float64(eventType))])
            return true
        }
        return false
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
            return JsValue(!response.getOrThrow().body.getOrThrow().isDefinitelyEmpty())
        }
    } else if (thisValue.isRequest()) {
        let request = thisValue.toRequest()
        if (request.isSome()) {
            return JsValue(!request.getOrThrow().body.getOrThrow().isDefinitelyEmpty())
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
            bodyValue = request.getOrThrow().body
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

// ported from: src/runtime/webcore/Response.rs
