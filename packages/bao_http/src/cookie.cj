// bao_http cookie - HTTP Cookie 解析和序列化
// 严格翻译自: src/http/Headers.zig 中 Set-Cookie/Cookie 头处理
// 参考: RFC 6265 (HTTP State Management Mechanism)
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// SameSite - Cookie SameSite 属性
// RFC 6265bis: Strict, Lax, None
// ============================================================================

/// Cookie SameSite 属性
public enum SameSite {
    | Default  // 未指定 (浏览器默认 Lax)
    | Strict   // Strict - 仅同站请求发送
    | Lax      // Lax - 导航到目标网站时发送 (默认)
    | None     // None - 跨站请求也发送 (需要 Secure)

    public func toString(): String {
        match (this) {
            case Default => ""
            case Strict => "Strict"
            case Lax => "Lax"
            case None => "None"
        }
    }

    public static func fromString(s: String): SameSite {
        match (s.toLower()) {
            case "strict" => Strict
            case "lax" => Lax
            case "none" => None
            case _ => Default
        }
    }
}

// ============================================================================
// Cookie - HTTP Cookie
// 对应 Bun Headers 中 Set-Cookie 头的解析
// Cookie 格式: name=value; Expires=...; Path=...; Domain=...; Secure; HttpOnly; SameSite=...
// ============================================================================

/// HTTP Cookie - 对应 Web API Cookie
public class Cookie {
    /// Cookie 名称
    public var name: String
    /// Cookie 值
    public var value: String
    /// 过期时间 - 对应 Set-Cookie: Expires=...
    public var expires: ?String
    /// 最大存活时间 (秒) - 对应 Set-Cookie: Max-Age=...
    public var maxAge: ?Int64
    /// 路径 - 对应 Set-Cookie: Path=...
    public var path: ?String
    /// 域名 - 对应 Set-Cookie: Domain=...
    public var domain: ?String
    /// 是否仅 HTTPS - 对应 Set-Cookie: Secure
    public var secure: Bool
    /// 是否仅 HTTP (不可 JS 访问) - 对应 Set-Cookie: HttpOnly
    public var httpOnly: Bool
    /// SameSite 策略 - 对应 Set-Cookie: SameSite=...
    public var sameSite: SameSite

    public init(name: String, value: String) {
        this.name = name
        this.value = value
        this.expires = None
        this.maxAge = None
        this.path = None
        this.domain = None
        this.secure = false
        this.httpOnly = false
        this.sameSite = SameSite.Default
    }

    // ========================================================================
    // parse - 从 Set-Cookie 或 Cookie 头解析
    // ========================================================================

    /// 从 Set-Cookie 头值解析 Cookie
    /// 格式: name=value; Expires=...; Path=...; Domain=...; Secure; HttpOnly; SameSite=...
    public static func parse(headerValue: String): ?Cookie {
        let parts = splitSemicolon(headerValue)
        if (parts.size == 0) {
            return None
        }

        // 第一部分是 name=value
        let first = parts[0].trim()
        let eqIdx = first.indexOf("=")
        if (eqIdx < 0) {
            return None
        }

        let name = first.substring(0, eqIdx).trim()
        let value = first.substring(eqIdx + 1).trim()
        let cookie = Cookie(name, value)

        // 解析属性
        for (i in 1..parts.size) {
            let part = parts[Int64(i)].trim()
            let attrEqIdx = part.indexOf("=")
            if (attrEqIdx >= 0) {
                let attrName = part.substring(0, attrEqIdx).trim().toLower()
                let attrValue = part.substring(attrEqIdx + 1).trim()
                match (attrName) {
                    case "expires" => cookie.expires = Some(attrValue)
                    case "max-age" => {
                        try {
                            cookie.maxAge = Some(Int64.parse(attrValue))
                        } catch (_: Exception) {
                            cookie.maxAge = None
                        }
                    }
                    case "domain" => cookie.domain = Some(attrValue)
                    case "path" => cookie.path = Some(attrValue)
                    case "samesite" => cookie.sameSite = SameSite.fromString(attrValue)
                    case _ => ()  // 忽略未知属性
                }
            } else {
                // 无值属性: Secure, HttpOnly
                let lower = part.toLower()
                if (lower == "secure") {
                    cookie.secure = true
                } else if (lower == "httponly") {
                    cookie.httpOnly = true
                }
            }
        }

        return Some(cookie)
    }

    /// 从 Cookie 请求头解析多个 Cookie
    /// 格式: name1=value1; name2=value2; ...
    public static func parseMany(cookieHeader: String): ArrayList<Cookie> {
        let cookies = ArrayList<Cookie>()
        let parts = splitSemicolon(cookieHeader)
        for (part in parts) {
            let trimmed = part.trim()
            let eqIdx = trimmed.indexOf("=")
            if (eqIdx >= 0) {
                let name = trimmed.substring(0, eqIdx).trim()
                let value = trimmed.substring(eqIdx + 1).trim()
                cookies.append(Cookie(name, value))
            }
        }
        return cookies
    }

    // ========================================================================
    // serialize - 序列化为 Set-Cookie 头值
    // ========================================================================

    /// 序列化为 Set-Cookie 头值
    public func serialize(): String {
        let sb = StringBuilder()
        sb.append("${name}=${value}")

        match (expires) {
            case Some(exp) => sb.append("; Expires=${exp}")
            case None => ()
        }

        match (maxAge) {
            case Some(age) => sb.append("; Max-Age=${age}")
            case None => ()
        }

        match (path) {
            case Some(p) => sb.append("; Path=${p}")
            case None => ()
        }

        match (domain) {
            case Some(d) => sb.append("; Domain=${d}")
            case None => ()
        }

        if (secure) {
            sb.append("; Secure")
        }

        if (httpOnly) {
            sb.append("; HttpOnly")
        }

        if (sameSite != SameSite.Default) {
            sb.append("; SameSite=${sameSite.toString()}")
        }

        return sb.toString()
    }

    /// 序列化为 Cookie 请求头值 (仅 name=value)
    public func toHeaderValue(): String {
        return "${name}=${value}"
    }

    override public func toString(): String {
        return serialize()
    }

    /// 是否已过期
    public func isExpired(): Bool {
        match (maxAge) {
            case Some(age) => age <= 0
            case None => ()
        }
        match (expires) {
            case Some(exp) => false  // 简化: 需要解析日期
            case None => ()
        }
        return false
    }
}

// ============================================================================
// CookieJar - Cookie 容器
// 对应浏览器 Cookie 存储或 Bun 中的 cookie 管理
// ============================================================================

/// Cookie 容器
public class CookieJar {
    /// Cookie 存储: domain:path:name -> Cookie
    private var cookies: HashMap<String, Cookie>

    public init() {
        cookies = HashMap<String, Cookie>()
    }

    /// 设置 Cookie
    public func set(cookie: Cookie): Unit {
        let key = cookieKey(cookie)
        cookies.put(key, cookie)
    }

    /// 从 Set-Cookie 头设置
    public func setFromHeader(headerValue: String): Unit {
        let parsed = Cookie.parse(headerValue)
        match (parsed) {
            case Some(cookie) => set(cookie)
            case None => ()
        }
    }

    /// 获取指定名称的 Cookie
    public func get(name: String): ?Cookie {
        for (key in cookies.keys()) {
            match (cookies.get(key)) {
                case Some(cookie) => {
                    if (cookie.name == name) {
                        return Some(cookie)
                    }
                }
                case None => ()
            }
        }
        return None
    }

    /// 获取指定域名和路径下的 Cookie
    public func get(name: String, domain: String, path: String): ?Cookie {
        let key = "${domain}:${path}:${name}"
        return cookies.get(key)
    }

    /// 获取所有匹配的 Cookie
    public func getAll(name: String): ArrayList<Cookie> {
        let result = ArrayList<Cookie>()
        for (key in cookies.keys()) {
            match (cookies.get(key)) {
                case Some(cookie) => {
                    if (cookie.name == name) {
                        result.append(cookie)
                    }
                }
                case None => ()
            }
        }
        return result
    }

    /// 获取所有 Cookie
    public func getAll(): ArrayList<Cookie> {
        let result = ArrayList<Cookie>()
        for (key in cookies.keys()) {
            match (cookies.get(key)) {
                case Some(cookie) => result.append(cookie)
                case None => ()
            }
        }
        return result
    }

    /// 移除 Cookie
    public func remove(name: String): Unit {
        let toRemove = ArrayList<String>()
        for (key in cookies.keys()) {
            match (cookies.get(key)) {
                case Some(cookie) => {
                    if (cookie.name == name) {
                        toRemove.append(key)
                    }
                }
                case None => ()
            }
        }
        for (key in toRemove) {
            cookies.remove(key)
        }
    }

    /// Cookie 数量
    public func size(): Int64 {
        return cookies.keys().size
    }

    /// 构建 Cookie 请求头
    /// 将所有匹配的 Cookie 序列化为 "name1=value1; name2=value2"
    public func toCookieHeader(domain: String, path: String): String {
        let parts = ArrayList<String>()
        for (key in cookies.keys()) {
            match (cookies.get(key)) {
                case Some(cookie) => {
                    // 简化匹配: 只检查域名和路径前缀
                    let domainMatch = match (cookie.domain) {
                        case Some(d) => domain.endsWith(d) || domain == d
                        case None => true
                    }
                    let pathMatch = match (cookie.path) {
                        case Some(p) => path.startsWith(p)
                        case None => true
                    }
                    if (domainMatch && pathMatch) {
                        parts.append(cookie.toHeaderValue())
                    }
                }
                case None => ()
            }
        }
        let sb = StringBuilder()
        for (i in 0..parts.size) {
            if (i > 0) { sb.append("; ") }
            sb.append(parts[Int64(i)])
        }
        return sb.toString()
    }

    /// 清除所有 Cookie
    public func clear(): Unit {
        cookies = HashMap<String, Cookie>()
    }

    /// 生成 Cookie 存储 key
    private func cookieKey(cookie: Cookie): String {
        let d = match (cookie.domain) {
            case Some(d) => d
            case None => ""
        }
        let p = match (cookie.path) {
            case Some(p) => p
            case None => "/"
        }
        return "${d}:${p}:${cookie.name}"
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 按分号分割
private func splitSemicolon(s: String): ArrayList<String> {
    let parts = ArrayList<String>()
    var current = StringBuilder()
    for (c in s) {
        if (c == ';') {
            parts.append(current.toString())
            current = StringBuilder()
        } else {
            current.append(c)
        }
    }
    if (current.toString().size > 0) {
        parts.append(current.toString())
    }
    return parts
}
