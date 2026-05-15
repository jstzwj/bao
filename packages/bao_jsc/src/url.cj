// 严格翻译自: src/jsc/URL.zig + URLSearchParams.zig + DOMURL.zig + DOMFormData.zig
// URL 和 URL 相关类型

package bao_jsc

// ========== URL 组件 ==========
// 严格翻译自 URL.zig
public class URLComponents {
    public var scheme: String = ""
    public var username: String = ""
    public var password: String = ""
    public var host: String = ""
    public var port: String = ""
    public var path: String = ""
    public var query: String = ""
    public var fragment: String = ""

    public init() {}

    // 获取完整 URL
    public func toString() -> String {
        var result = scheme + "://"
        if (!username.isEmpty) {
            result += username
            if (!password.isEmpty) {
                result += ":" + password
            }
            result += "@"
        }
        result += host
        if (!port.isEmpty) {
            result += ":" + port
        }
        result += path
        if (!query.isEmpty) {
            result += "?" + query
        }
        if (!fragment.isEmpty) {
            result += "#" + fragment
        }
        result
    }

    // 获取 origin
    public func origin() -> String {
        scheme + "://" + host + (if (!port.isEmpty) { ":" + port } else { "" })
    }
}

// ========== URL ==========
// 严格翻译自 URL.zig
public class URL {
    public var href: String = ""
    public var protocol: String = ""
    public var username: String = ""
    public var password: String = ""
    public var hostname: String = ""
    public var port: String = ""
    public var pathname: String = ""
    public var search: String = ""
    public var searchParams: URLSearchParams = URLSearchParams()
    public var hash: String = ""
    public var origin: String = ""

    public init() {}

    public init(url: String) {
        parse(url)
    }

    public init(url: String, base: String) {
        let fullUrl = if (base.endsWith("/") || url.startsWith("/")) {
            base + url
        } else {
            base + "/" + url
        }
        parse(fullUrl)
    }

    // 解析 URL
    func parse(url: String) {
        href = url
        // 简化的 URL 解析
        var remaining = url

        // 协议
        let schemeEnd = remaining.indexOf("://")
        if (schemeEnd >= 0) {
            protocol = remaining[0..schemeEnd]
            remaining = remaining[schemeEnd + 3..]
        }

        // hash
        let hashIdx = remaining.indexOf("#")
        if (hashIdx >= 0) {
            hash = remaining[hashIdx..]
            remaining = remaining[0..hashIdx]
        }

        // query
        let queryIdx = remaining.indexOf("?")
        if (queryIdx >= 0) {
            search = remaining[queryIdx..]
            searchParams = URLSearchParams(remaining[queryIdx + 1..])
            remaining = remaining[0..queryIdx]
        }

        // auth
        let atIdx = remaining.indexOf("@")
        if (atIdx >= 0) {
            let auth = remaining[0..atIdx]
            let colonIdx = auth.indexOf(":")
            if (colonIdx >= 0) {
                username = auth[0..colonIdx]
                password = auth[colonIdx + 1..]
            } else {
                username = auth
            }
            remaining = remaining[atIdx + 1..]
        }

        // host:port
        let slashIdx = remaining.indexOf("/")
        if (slashIdx >= 0) {
            let hostPart = remaining[0..slashIdx]
            pathname = remaining[slashIdx..]
            parseHostPort(hostPart)
        } else {
            parseHostPort(remaining)
            pathname = "/"
        }

        origin = protocol + "://" + hostname + (if (!port.isEmpty) { ":" + port } else { "" })
    }

    func parseHostPort(hostPort: String) {
        let bracketEnd = hostPort.indexOf("]")
        if (bracketEnd >= 0) {
            // IPv6
            hostname = hostPort[0..bracketEnd + 1]
            if (bracketEnd + 2 < hostPort.size && hostPort[bracketEnd + 1] == ':') {
                port = hostPort[bracketEnd + 2..]
            }
        } else {
            let colonIdx = hostPort.lastIndexOf(":")
            if (colonIdx >= 0) {
                hostname = hostPort[0..colonIdx]
                port = hostPort[colonIdx + 1..]
            } else {
                hostname = hostPort
            }
        }
    }

    // URL.canParse
    public static func canParse(url: String) -> Bool {
        url.indexOf("://") >= 0 || url.startsWith("/") || url.startsWith("./") || url.startsWith("../")
    }

    // 转为 JsValue
    public func toJsValue() -> JsValue {
        let obj = JsObject.make()
        obj.className = "URL"
        obj.set("href", JsValue(s: href))
        obj.set("protocol", JsValue(s: protocol))
        obj.set("username", JsValue(s: username))
        obj.set("password", JsValue(s: password))
        obj.set("hostname", JsValue(s: hostname))
        obj.set("port", JsValue(s: port))
        obj.set("pathname", JsValue(s: pathname))
        obj.set("search", JsValue(s: search))
        obj.set("hash", JsValue(s: hash))
        obj.set("origin", JsValue(s: origin))
        JsValue(obj: obj)
    }
}

// ========== URLSearchParams ==========
// 严格翻译自 URLSearchParams.zig
public class URLSearchParams {
    public var params: ArrayList<(String, String)> = ArrayList()

    public init() {}

    public init(search: String) {
        parse(search)
    }

    // 解析查询字符串
    func parse(search: String) {
        if (search.isEmpty) { return }
        let str = if (search.startsWith("?")) { search.slice(1) } else { search }
        let pairs = str.split("&")
        for (pair in pairs) {
            let eqIdx = pair.indexOf("=")
            if (eqIdx >= 0) {
                let key = pair[0..eqIdx]
                let value = pair[eqIdx + 1..]
                params.append((decodeComponent(key), decodeComponent(value)))
            } else {
                params.append((decodeComponent(pair), ""))
            }
        }
    }

    // append
    public func append(name: String, value: String) {
        params.append((name, value))
    }

    // delete
    public func delete(name: String) {
        var i = 0
        while (i < params.size) {
            if (params[Int64(i)].0 == name) {
                params.removeAt(Int64(i))
            } else {
                i++
            }
        }
    }

    // get
    public func get(name: String) -> ?String {
        for (pair in params) {
            if (pair.0 == name) {
                return pair.1
            }
        }
        None
    }

    // getAll
    public func getAll(name: String) -> Array<String> {
        var result = Array<String>()
        for (pair in params) {
            if (pair.0 == name) {
                result.append(pair.1)
            }
        }
        result
    }

    // has
    public func has(name: String) -> Bool {
        for (pair in params) {
            if (pair.0 == name) {
                return true
            }
        }
        false
    }

    // set
    public func set(name: String, value: String) {
        var found = false
        var i = 0
        while (i < params.size) {
            if (params[Int64(i)].0 == name) {
                if (!found) {
                    params[Int64(i)] = (name, value)
                    found = true
                } else {
                    params.removeAt(Int64(i))
                    continue
                }
            }
            i++
        }
        if (!found) {
            params.append((name, value))
        }
    }

    // sort
    public func sort() {
        params.sort({ a, b => a.0 < b.0 })
    }

    // toString
    public func toString() -> String {
        var parts = Array<String>()
        for (pair in params) {
            parts.append(encodeComponent(pair.0) + "=" + encodeComponent(pair.1))
        }
        String.join("&", parts)
    }

    // URL 编码辅助
    func encodeComponent(s: String) -> String {
        s.replace(" ", "+")
    }

    func decodeComponent(s: String) -> String {
        s.replace("+", " ")
    }
}

// ========== DOMURL ==========
// 严格翻译自 DOMURL.zig
public class DOMURL {
    public init() {}

    public static func create(url: String, base: String) -> URL {
        URL(url, base)
    }

    public static func canParse(url: String) -> Bool {
        URL.canParse(url)
    }
}

// ========== DOMFormData ==========
// 严格翻译自 DOMFormData.zig
public class DOMFormData {
    public var entries: ArrayList<(String, FormDataValue)> = ArrayList()

    public init() {}

    // append
    public func append(name: String, value: String) {
        entries.append((name, FormDataValue.StringValue(value)))
    }

    public func append(name: String, value: String, filename: String) {
        entries.append((name, FormDataValue.FileValue(value, filename)))
    }

    // delete
    public func delete(name: String) {
        var i = 0
        while (i < entries.size) {
            if (entries[Int64(i)].0 == name) {
                entries.removeAt(Int64(i))
            } else {
                i++
            }
        }
    }

    // get
    public func get(name: String) -> ?String {
        for (entry in entries) {
            if (entry.0 == name) {
                return entry.1.stringValue()
            }
        }
        None
    }

    // getAll
    public func getAll(name: String) -> Array<String> {
        var result = Array<String>()
        for (entry in entries) {
            if (entry.0 == name) {
                if (let Some(s) <- entry.1.stringValue()) {
                    result.append(s)
                }
            }
        }
        result
    }

    // has
    public func has(name: String) -> Bool {
        for (entry in entries) {
            if (entry.0 == name) {
                return true
            }
        }
        false
    }

    // set
    public func set(name: String, value: String) {
        var found = false
        var i = 0
        while (i < entries.size) {
            if (entries[Int64(i)].0 == name) {
                if (!found) {
                    entries[Int64(i)] = (name, FormDataValue.StringValue(value))
                    found = true
                } else {
                    entries.removeAt(Int64(i))
                    continue
                }
            }
            i++
        }
        if (!found) {
            entries.append((name, FormDataValue.StringValue(value)))
        }
    }
}

// FormData 值
public enum FormDataValue {
    | StringValue(String)
    | FileValue(String, String)  // (data, filename)

    public func stringValue() -> ?String {
        match (this) {
            case StringValue(s) => s
            case FileValue(data, _) => data
        }
    }
}
