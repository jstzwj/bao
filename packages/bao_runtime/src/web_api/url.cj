// Web API URL 模块
// 对应 Bun: src/runtime/api/URL.zig
// 严格翻译 Bun 的 URL API
package bao_runtime.web_api

import bao_core.BaoString
import bao_core.IntFormatter
import bao_collections.*
import bao_runtime.*

// ============================================================================
// URL 模块 — Web URL API
// 对应 Bun: src/runtime/api/URL.zig + URLSearchParams.zig
// ============================================================================

/// URL 解析器 — 对应 Web URL API
/// 对应 Bun: src/runtime/api/URL.zig
public class BaoUrl {
    public var href: String
    public var protocol: String
    public var username: String
    public var password: String
    public var hostname: String
    public var port: String
    public var pathname: String
    public var search: String
    public var hash: String
    public var origin: String

    public init(url: String) {
        href = url
        protocol = ""
        username = ""
        password = ""
        hostname = ""
        port = ""
        pathname = ""
        search = ""
        hash = ""
        origin = ""
        parseUrl(url)
    }

    public init(url: String, base: String) {
        // 简化: 如果 url 是相对路径，与 base 拼接
        if (url.startsWith("/")) {
            let baseUrl = BaoUrl(base)
            href = baseUrl.protocol + "//" + baseUrl.hostname +
                   (if (baseUrl.port.size > 0) { ":" + baseUrl.port } else { "" }) + url
        } else if (!url.contains("://")) {
            href = base + (if (base.endsWith("/")) { "" } else { "/" }) + url
        } else {
            href = url
        }
        protocol = ""
        username = ""
        password = ""
        hostname = ""
        port = ""
        pathname = ""
        search = ""
        hash = ""
        origin = ""
        parseUrl(href)
    }

    /// 解析 URL 字符串
    /// 对应 Bun: URL 解析逻辑
    private func parseUrl(url: String): Unit {
        var remaining = url

        // 解析 protocol
        if (let Some(protoIdx) <- remaining.indexOf("://")) {
            protocol = remaining[0..(protoIdx + 1)]
            remaining = remaining[(protoIdx + 3)..]
        }

        // 解析 hash
        if (let Some(hashIdx) <- remaining.indexOf("#")) {
            hash = remaining[hashIdx..]
            remaining = remaining[0..hashIdx]
        }

        // 解析 search
        if (let Some(searchIdx) <- remaining.indexOf("?")) {
            search = remaining[searchIdx..]
            remaining = remaining[0..searchIdx]
        }

        // 解析 pathname
        if (let Some(pathIdx) <- remaining.indexOf("/")) {
            pathname = remaining[pathIdx..]
            remaining = remaining[0..pathIdx]
        } else {
            pathname = "/"
        }

        // 解析 host (username:password@hostname:port)
        if (let Some(atIdx) <- remaining.indexOf("@")) {
            let userInfo = remaining[0..atIdx]
            remaining = remaining[(atIdx + 1)..]
            if (let Some(colIdx) <- userInfo.indexOf(":")) {
                username = userInfo[0..colIdx]
                password = userInfo[(colIdx + 1)..]
            } else {
                username = userInfo
            }
        }

        // 解析 hostname:port
        if (let Some(colIdx) <- remaining.lastIndexOf(":")) {
            hostname = remaining[0..colIdx]
            port = remaining[(colIdx + 1)..]
        } else {
            hostname = remaining
        }

        // 构建 origin
        origin = protocol + "//" + hostname
        if (port.size > 0) {
            origin = origin + ":" + port
        }

        // 更新 href
        href = url
    }

    /// 获取 searchParams
    public func searchParams(): URLSearchParams {
        return URLSearchParams(search)
    }

    /// 转为字符串
    public func toString(): String {
        return href
    }

    /// 转为 JSON
    public func toJSON(): String {
        return href
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("href", JsValue(BaoString(href)))
        obj.set("protocol", JsValue(BaoString(protocol)))
        obj.set("username", JsValue(BaoString(username)))
        obj.set("password", JsValue(BaoString(password)))
        obj.set("hostname", JsValue(BaoString(hostname)))
        obj.set("port", JsValue(BaoString(port)))
        obj.set("pathname", JsValue(BaoString(pathname)))
        obj.set("search", JsValue(BaoString(search)))
        obj.set("hash", JsValue(BaoString(hash)))
        obj.set("origin", JsValue(BaoString(origin)))
        obj.set("toString", JsValue.nativeFunction(JsNativeFunction("toString") { _ =>
            JsValue(BaoString(href))
        }))
        obj.set("toJSON", JsValue.nativeFunction(JsNativeFunction("toJSON") { _ =>
            JsValue(BaoString(href))
        }))
        return JsValue(obj)
    }
}

/// URLSearchParams — 对应 Web URLSearchParams API
/// 对应 Bun: src/runtime/api/URLSearchParams.zig
public class URLSearchParams {
    private var params: ArrayList<Pair<String, String>>

    public init() {
        params = ArrayList<Pair<String, String>>()
    }

    public init(search: String) {
        params = ArrayList<Pair<String, String>>()
        parse(search)
    }

    /// 解析查询字符串
    private func parse(search: String): Unit {
        var s = search
        if (s.startsWith("?")) {
            s = s[1..]
        }
        if (s.size == 0) { return }
        let pairs = s.split("&")
        for (pair in pairs) {
            if (let Some(idx) <- pair.indexOf("=")) {
                let key = decodeComponent(pair[0..idx])
                let val = decodeComponent(pair[(idx + 1)..])
                params.append(Pair<String, String>(key, val))
            } else {
                params.append(Pair<String, String>(decodeComponent(pair), ""))
            }
        }
    }

    /// append(name, value)
    public func append(name: String, value: String): Unit {
        params.append(Pair<String, String>(name, value))
    }

    /// delete(name)
    public func delete(name: String): Unit {
        let newArr = ArrayList<Pair<String, String>>()
        for (p in params) {
            if (p.first != name) {
                newArr.append(p)
            }
        }
        params = newArr
    }

    /// get(name) — 获取第一个值
    public func get(name: String): ?String {
        for (p in params) {
            if (p.first == name) {
                return Some(p.second)
            }
        }
        return None
    }

    /// getAll(name) — 获取所有值
    public func getAll(name: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) {
            if (p.first == name) {
                result.append(p.second)
            }
        }
        return result
    }

    /// has(name)
    public func has(name: String): Bool {
        for (p in params) {
            if (p.first == name) { return true }
        }
        return false
    }

    /// set(name, value)
    public func set(name: String, value: String): Unit {
        var found = false
        let newArr = ArrayList<Pair<String, String>>()
        for (p in params) {
            if (p.first == name) {
                if (!found) {
                    newArr.append(Pair<String, String>(name, value))
                    found = true
                }
                // 跳过后续同名的
            } else {
                newArr.append(p)
            }
        }
        if (!found) {
            newArr.append(Pair<String, String>(name, value))
        }
        params = newArr
    }

    /// sort() — 按键名排序
    public func sort(): Unit {
        // 简化的冒泡排序
        for (i in 0..params.size) {
            for (j in (i + 1)..params.size) {
                if (params[i].first > params[j].first) {
                    let tmp = params[i]
                    params[i] = params[j]
                    params[j] = tmp
                }
            }
        }
    }

    /// toString() — 序列化为查询字符串
    public func toString(): String {
        let sb = StringBuilder()
        for (i in 0..params.size) {
            if (i > 0) { sb.append("&") }
            sb.append(encodeComponent(params[i].first))
            sb.append("=")
            sb.append(encodeComponent(params[i].second))
        }
        return sb.toString()
    }

    /// 获取所有键
    public func keys(): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) {
            result.append(p.first)
        }
        return result
    }

    /// 获取所有值
    public func values(): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) {
            result.append(p.second)
        }
        return result
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let sp = this

        obj.set("append", JsValue.nativeFunction(JsNativeFunction("append") { args =>
            if (args.size >= 2) {
                sp.append(Interpreter.jsToString(args[0]), Interpreter.jsToString(args[1]))
            }
            return JsValue.UNDEFINED
        }))

        obj.set("delete", JsValue.nativeFunction(JsNativeFunction("delete") { args =>
            if (args.size >= 1) { sp.delete(Interpreter.jsToString(args[0])) }
            return JsValue.UNDEFINED
        }))

        obj.set("get", JsValue.nativeFunction(JsNativeFunction("get") { args =>
            if (args.size >= 1) {
                match (sp.get(Interpreter.jsToString(args[0]))) {
                    case Some(v) => return JsValue(BaoString(v))
                    case None => return JsValue.NULL
                }
            }
            return JsValue.NULL
        }))

        obj.set("getAll", JsValue.nativeFunction(JsNativeFunction("getAll") { args =>
            if (args.size >= 1) {
                let vals = sp.getAll(Interpreter.jsToString(args[0]))
                let arr = ArrayList<JsValue>()
                for (v in vals) { arr.append(JsValue(BaoString(v))) }
                return JsValue.array(arr)
            }
            return JsValue.array(ArrayList<JsValue>())
        }))

        obj.set("has", JsValue.nativeFunction(JsNativeFunction("has") { args =>
            if (args.size >= 1) {
                return JsValue(sp.has(Interpreter.jsToString(args[0])))
            }
            return JsValue(false)
        }))

        obj.set("set", JsValue.nativeFunction(JsNativeFunction("set") { args =>
            if (args.size >= 2) {
                sp.set(Interpreter.jsToString(args[0]), Interpreter.jsToString(args[1]))
            }
            return JsValue.UNDEFINED
        }))

        obj.set("sort", JsValue.nativeFunction(JsNativeFunction("sort") { _ =>
            sp.sort()
            return JsValue.UNDEFINED
        }))

        obj.set("toString", JsValue.nativeFunction(JsNativeFunction("toString") { _ =>
            JsValue(BaoString(sp.toString()))
        }))

        return JsValue(obj)
    }

    /// 简化的 URL 编码
    private static func encodeComponent(s: String): String {
        // 简化: 只编码特殊字符
        let sb = StringBuilder()
        for (c in s) {
            let v = Int64(c)
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                (v >= 48 && v <= 57) || v == 45 || v == 95 || v == 46 || v == 126) {
                sb.append(String(Rune(Int32(c))))
            } else {
                sb.append("%")
                if (v < 16) { sb.append("0") }
                sb.append(IntFormatter.toHexString(v).toAsciiUpper())
            }
        }
        return sb.toString()
    }

    /// 简化的 URL 解码
    private static func decodeComponent(s: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        let len = Int64(s.size)
        while (i < len) {
            let c = s[i]
            if (c == UInt8(37) && i + 2 < len) { // '%'
                let hex = s[(i + 1)..(i + 3)]
                try {
                    let code = parseHexInt(hex)
                    sb.append(String(Rune(Int32(code))))
                    i += 3
                } catch (_: Exception) {
                    sb.append(String(Rune(Int32(c))))
                    i += 1
                }
            } else if (c == UInt8(43)) { // '+'
                sb.append(" ")
                i += 1
            } else {
                sb.append(String(Rune(Int32(c))))
                i += 1
            }
        }
        return sb.toString()
    }
}

/// 解析十六进制字符串为整数
private func parseHexInt(hex: String): Int64 {
    var result: Int64 = 0
    for (i in 0..hex.size) {
        let c = hex[Int64(i)]
        result = result * 16
        if (c >= UInt8(48) && c <= UInt8(57)) {
            result += Int64(c) - 48
        } else if (c >= UInt8(65) && c <= UInt8(70)) {
            result += Int64(c) - 55
        } else if (c >= UInt8(97) && c <= UInt8(102)) {
            result += Int64(c) - 87
        }
    }
    return result
}

/// URL 模块辅助 — Pair 类
public class Pair<T, U> {
    public var first: T
    public var second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

/// URL 模块导出
public class UrlModule {
    /// 将 URL 构造函数导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        // URL 构造函数
        obj.set("URL", JsValue.nativeFunction(JsNativeFunction("URL") { args =>
            if (args.size >= 1) {
                let urlStr = Interpreter.jsToString(args[0])
                let url = if (args.size >= 2) {
                    BaoUrl(urlStr, Interpreter.jsToString(args[1]))
                } else {
                    BaoUrl(urlStr)
                }
                return url.toJsValue()
            }
            return JsValue.NULL
        }))

        // URLSearchParams 构造函数
        obj.set("URLSearchParams", JsValue.nativeFunction(JsNativeFunction("URLSearchParams") { args =>
            let search = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            let sp = URLSearchParams(search)
            return sp.toJsValue()
        }))

        return JsValue(obj)
    }
}
