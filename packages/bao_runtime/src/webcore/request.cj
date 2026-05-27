// Request - HTTP 请求对象
// 对应 Bun: src/runtime/webcore/Request.rs
// 严格翻译自: src/runtime/webcore/Request.rs
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_http_types.*
import bao_http_jsc.*
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_jsc.JsGlobalObject

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
            callback.call(global.globalThis, JsValue.undefined(), [JsValue(Float64(eventType))])
            return true
        }
        return false
    }
}

/// Re-export of AbortEvent — 对应 Bun: EventType
public type AbortEventType = Int64

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
        obj.set("address", JsValue(ip))
        obj.set("port", JsValue(Float64(Int64(port))))
        obj.set("family", JsValue(if (isIPv6) { "IPv6" } else { "IPv4" }))
        return JsValue(obj)
    }
}

// ============================================================================
// JsValue 扩展方法 — 用于 Request/Response 构造
// ========================================================================

/// JsValue 辅助扩展
public class JsValueHelper {
    /// 快速获取属性
    public static func fastGet(value: JsValue, global: JsGlobalObject, name: BuiltinName): ?JsValue {
        let propName = builtinNameToString(name)
        let result = value.get(global.globalThis, propName)
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
        }
    }
}

// ported from: src/runtime/webcore/Request.rs
