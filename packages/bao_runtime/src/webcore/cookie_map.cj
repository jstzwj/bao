// CookieMap - Cookie 映射
// 对应 Bun: src/runtime/webcore/CookieMap.zig
// 严格翻译自: src/runtime/webcore/CookieMap.zig
package bao_runtime.webcore

import bao_core.*
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_jsc.JsFunction
import bao_collections.HashMap
import bao_collections.ArrayList

// ============================================================================
// CookieMap - Cookie 映射
// 对应 Bun: src/runtime/webcore/CookieMap.zig CookieMap
// ============================================================================

/// CookieMap — HTTP Cookie 映射
/// 对应 Bun: src/runtime/webcore/CookieMap.zig CookieMap
public class CookieMap {
    /// Cookie 存储: name -> (value, attributes)
    private var cookies: HashMap<String, CookieEntry>
    /// 引用计数
    private var refCount: Int64

    public init() {
        cookies = HashMap<String, CookieEntry>()
        refCount = 1
    }

    /// 增加引用
    /// 对应 Bun: CookieMap.ref
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 对应 Bun: CookieMap.deref
    public func deref(): Unit {
        refCount -= 1
    }

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

    /// 转为 Set-Cookie 头列表
    /// 对应 Bun: CookieMap.write
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

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("get", JsValue("get"))
        obj.set("set", JsValue("set"))
        obj.set("delete", JsValue("delete"))
        obj.set("has", JsValue("has"))

        return JsValue(obj)
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
