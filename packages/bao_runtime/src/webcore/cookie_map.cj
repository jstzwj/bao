// CookieMap - Cookie 映射
// 严格翻译自: src/runtime/webcore/CookieMap.zig (17 lines) + CookieMap.rs (108 lines)
// 对应 Bun: src/runtime/webcore/CookieMap.zig
//   Bun 的 CookieMap 模块:
//   - CookieMap: opaque struct (C++ refcounted object, FFI handle)
//   - CookieMap__write: 写入 Set-Cookie 头到 HTTP 响应
//   - CookieMap__deref: 递减引用计数
//   - CookieMap__ref: 递增引用计数
//   - CookieMapRef: RAII 智能指针 (intrusive refcount)
//     - new_ref: 创建新引用 (+1)
//     - clone: 复制引用 (+1)
//     - drop: 释放引用 (-1)
//     - deref/deref_mut: 访问内部 CookieMap
// 仓颉: 提供兼容的 Cookie 映射
package bao_runtime.webcore

import bao_core.*
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_jsc.JsFunction
import bao_jsc.JsGlobalObject
import bao_collections.HashMap
import bao_collections.ArrayList

// ============================================================================
// CookieMap - Cookie 映射
// 对应 Bun: src/runtime/webcore/CookieMap.zig CookieMap (opaque)
//   Bun 的 CookieMap 是一个 opaque struct，指向 C++ 实现的引用计数对象。
//   所有操作通过 FFI 调用 C++ 实现:
//     - CookieMap__write: 写入 Set-Cookie 头
//     - CookieMap__deref: 递减引用计数
//     - CookieMap__ref: 递增引用计数
//
//   Rust 版本使用 bun_opaque::opaque_ffi! 宏生成 FFI handle，
//   以及 CookieMapRef RAII 智能指针管理生命周期。
//
//   仓颉翻译: 使用 class 实现引用计数语义，不需要 unsafe 指针操作。
// ============================================================================

/// HTTP 响应类型 — 对应 Bun: bun.uws.ResponseKind
public enum ResponseKind {
    | HttpResponse
    | HttpResponseLite
}

/// CookieMap — HTTP Cookie 映射
/// 对应 Bun: CookieMap (opaque) + CookieMapRef (RAII smart pointer)
///
/// Bun 的 CookieMap 是一个 C++ 引用计数的 opaque 对象:
///   - extern fn CookieMap__write(cookie_map, global_this, kind, uws_http_response)
///   - extern fn CookieMap__deref(cookie_map)
///   - extern fn CookieMap__ref(cookie_map)
///
/// Rust 的 CookieMapRef 是 RAII 包装:
///   - new_ref(&CookieMap): +1 引用
///   - clone(): +1 引用
///   - drop(): -1 引用
///   - deref/deref_mut: 访问内部对象
public class CookieMap {
    /// Cookie 存储: name -> CookieEntry
    private var cookies: HashMap<String, CookieEntry>
    /// 引用计数 (对应 C++ intrusive refcount)
    private var refCount: Int64

    public init() {
        cookies = HashMap<String, CookieEntry>()
        refCount = 1
    }

    // ========================================================================
    // 引用计数管理
    // 对应 Bun: CookieMap__ref / CookieMap__deref
    // ========================================================================

    /// 增加引用
    /// 对应 Bun: CookieMap__ref(cookie_map) / CookieMap.ref
    /// Rust: pub fn new_ref(cookie_map: &CookieMap) -> Self { CookieMap__ref(cookie_map); ... }
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 对应 Bun: CookieMap__deref(cookie_map) / CookieMap.deref
    /// Rust: impl Drop for CookieMapRef { fn drop() { CookieMap__deref(self) } }
    public func deref(): Unit {
        refCount -= 1
    }

    /// 获取当前引用计数
    public func getRefCount(): Int64 {
        refCount
    }

    // ========================================================================
    // Cookie 操作
    // ========================================================================

    /// 设置 Cookie
    /// 对应 Web API: cookieStore.set()
    public func set(name: String, value: String): Unit {
        cookies.put(name, CookieEntry(name, value))
    }

    /// 设置带属性的 Cookie
    public func set(name: String, value: String, path: String, domain: String, secure: Bool, httpOnly: Bool, sameSite: String, maxAge: Int64): Unit {
        let entry = CookieEntry(name, value)
        entry.path = path
        entry.domain = domain
        entry.secure = secure
        entry.httpOnly = httpOnly
        entry.sameSite = sameSite
        entry.maxAge = maxAge
        cookies.put(name, entry)
    }

    /// 获取 Cookie 值
    /// 对应 Web API: cookieStore.get()
    public func get(name: String): ?String {
        match (cookies.get(name)) {
            case Some(entry) => Some(entry.value)
            case None => None
        }
    }

    /// 删除 Cookie
    /// 对应 Web API: cookieStore.delete()
    public func delete(name: String): Unit {
        cookies.remove(name)
    }

    /// 判断是否存在 Cookie
    public func has(name: String): Bool {
        return cookies.contains(name)
    }

    /// 获取所有 Cookie 名称
    public func keys(): ArrayList<String> {
        return cookies.keys()
    }

    // ========================================================================
    // write — 写入 Set-Cookie 头到 HTTP 响应
    // 对应 Bun: CookieMap__write / CookieMap.write
    // ========================================================================

    /// 写入 Set-Cookie 头到 HTTP 响应
    /// 对应 Bun: CookieMap__write(cookie_map, global_this, kind, uws_http_response)
    ///
    /// Bun 的 write 方法:
    ///   extern fn CookieMap__write(cookie_map: *CookieMap, global_this: *JSGlobalObject,
    ///                              kind: ResponseKind, uws_http_response: *anyopaque) void
    ///   通过 bun.jsc.fromJSHostCallGeneric 包装调用
    ///
    /// 在实际 Bao 实现中, 这会调用 uWebSockets 的 C++ 响应对象来写入 Set-Cookie 头。
    public func write(globalThis: JsGlobalObject, kind: ResponseKind, httpResponse: UIntPtr): Unit {
        // 对应 Bun: CookieMap__write FFI call
        // 实际实现需要通过 FFI 调用 C++ uWebSockets 响应对象
        let headers = toSetCookieHeaders()
        // TODO: FFI write to httpResponse
    }

    /// 转为 Set-Cookie 头列表
    public func toSetCookieHeaders(): ArrayList<String> {
        let result = ArrayList<String>()
        for (key in cookies.keys()) {
            match (cookies.get(key)) {
                case Some(entry) =>
                    var cookieStr = "${entry.name}=${entry.value}"
                    if (entry.path.size > 0) {
                        cookieStr += "; Path=${entry.path}"
                    }
                    if (entry.domain.size > 0) {
                        cookieStr += "; Domain=${entry.domain}"
                    }
                    if (entry.secure) {
                        cookieStr += "; Secure"
                    }
                    if (entry.httpOnly) {
                        cookieStr += "; HttpOnly"
                    }
                    if (entry.sameSite.size > 0) {
                        cookieStr += "; SameSite=${entry.sameSite}"
                    }
                    if (entry.maxAge >= 0) {
                        cookieStr += "; Max-Age=${entry.maxAge}"
                    }
                    result.append(cookieStr)
                case None => ()
            }
        }
        return result
    }

    // ========================================================================
    // 解析
    // ========================================================================

    /// 从 Cookie 头字符串解析
    public static func fromCookieHeader(header: String): CookieMap {
        let map = CookieMap()
        let pairs = header.split(";")
        for (pair in pairs) {
            let trimmed = pair.trimAscii()
            let eqIdxOpt = trimmed.indexOf("=")
            if (let Some(eqIdx) <- eqIdxOpt) {
                let name = trimmed[0..eqIdx].trimAscii()
                let value = trimmed[eqIdx + 1..].trimAscii()
                map.set(name, value)
            }
        }
        return map
    }

    // ========================================================================
    // toJsValue — 转为 JS 对象
    // ========================================================================

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("get", JsValue(JsFunction.create("get", { thisObj: JsObject, args: Array<JsValue> =>
            if (args.size == 0) { return JsValue.UNDEFINED }
            let name = args[0].toString()
            match (self.get(name)) {
                case Some(v) => JsValue(v)
                case None => JsValue.UNDEFINED
            }
        })))

        obj.set("set", JsValue(JsFunction.create("set", { thisObj: JsObject, args: Array<JsValue> =>
            if (args.size < 2) { return JsValue.UNDEFINED }
            let name = args[0].toString()
            let value = args[1].toString()
            self.set(name, value)
            JsValue.UNDEFINED
        })))

        obj.set("delete", JsValue(JsFunction.create("delete", { thisObj: JsObject, args: Array<JsValue> =>
            if (args.size == 0) { return JsValue.UNDEFINED }
            let name = args[0].toString()
            self.delete(name)
            JsValue.UNDEFINED
        })))

        obj.set("has", JsValue(JsFunction.create("has", { thisObj: JsObject, args: Array<JsValue> =>
            if (args.size == 0) { return JsValue(false) }
            let name = args[0].toString()
            JsValue(self.has(name))
        })))

        return JsValue(obj)
    }
}

// ============================================================================
// CookieMapRef - RAII 智能指针
// 对应 Bun (Rust): CookieMapRef (#[repr(transparent)] NonNull<CookieMap>)
//   Bun 的 CookieMapRef 是一个 RAII 包装器:
//     - new_ref(&CookieMap): CookieMap__ref() +1
//     - clone(): CookieMap__ref() +1
//     - drop(): CookieMap__deref() -1
//     - deref/deref_mut: 访问内部 CookieMap
// ============================================================================

/// CookieMap 的 RAII 智能指针
/// 对应 Bun (Rust): CookieMapRef
///
/// Intrusive smart pointer over a C++-refcounted CookieMap.
/// Owns exactly one strong ref: new_ref bumps it (for a borrowed handle)
/// and Drop releases it. Mirrors AbortSignalRef.
public class CookieMapRef {
    /// 持有的 CookieMap 引用
    private var cookieMap: ?CookieMap

    public init() {
        cookieMap = None
    }

    /// 从已有的 CookieMap 创建引用 (+1)
    /// 对应 Rust: pub fn new_ref(cookie_map: &CookieMap) -> Self
    ///   CookieMap__ref(cookie_map);
    ///   Self(NonNull::from(cookie_map))
    public init(cookieMap: CookieMap) {
        cookieMap.ref()
        this.cookieMap = Some(cookieMap)
    }

    /// 获取内部 CookieMap 的指针
    /// 对应 Rust: pub fn as_ptr(&self) -> *mut CookieMap
    public func asPtr(): ?CookieMap {
        cookieMap
    }

    /// 获取内部 CookieMap (不可变)
    /// 对应 Rust: impl Deref for CookieMapRef
    public func get(): ?CookieMap {
        cookieMap
    }

    /// 获取内部 CookieMap (可变)
    /// 对应 Rust: impl DerefMut for CookieMapRef
    public func getMut(): ?CookieMap {
        cookieMap
    }

    /// 克隆引用 (+1)
    /// 对应 Rust: impl Clone for CookieMapRef { fn clone(&self) -> Self { Self::new_ref(self) } }
    public func clone(): CookieMapRef {
        match (cookieMap) {
            case Some(cm) => CookieMapRef(cm)
            case None => CookieMapRef()
        }
    }

    /// 释放引用 (-1)
    /// 对应 Rust: impl Drop for CookieMapRef { fn drop(&mut self) { CookieMap__deref(self) } }
    public func release(): Unit {
        match (cookieMap) {
            case Some(cm) =>
                cm.deref()
                cookieMap = None
            case None => ()
        }
    }
}

// ============================================================================
// CookieEntry - Cookie 条目
// ============================================================================

/// Cookie 条目
public class CookieEntry {
    /// Cookie 名称
    public var name: String
    /// Cookie 值
    public var value: String
    /// 路径
    public var path: String
    /// 域名
    public var domain: String
    /// 是否仅 HTTPS
    public var secure: Bool
    /// 是否仅 HTTP
    public var httpOnly: Bool
    /// SameSite 属性
    public var sameSite: String
    /// 最大存活时间 (秒)
    public var maxAge: Int64

    public init(name: String, value: String) {
        this.name = name
        this.value = value
        path = "/"
        domain = ""
        secure = false
        httpOnly = false
        sameSite = "Lax"
        maxAge = -1
    }
}

// ported from: src/runtime/webcore/CookieMap.zig + CookieMap.rs
