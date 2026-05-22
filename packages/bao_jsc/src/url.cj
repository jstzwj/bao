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
    public func toString(): String {
        var result = scheme + "://"
        if (!username.size == 0) {
            result += username
            if (!password.size == 0) {
                result += ":" + password
            }
            result += "@"
        }
        result += host
        if (!port.size == 0) {
            result += ":" + port
        }
        result += path
        if (!query.size == 0) {
            result += "?" + query
        }
        if (!fragment.size == 0) {
            result += "#" + fragment
        }
        result
    }

    // 获取 origin
    public func origin(): String {
        scheme + "://" + host + (if (!port.size == 0) { ":" + port } else { "" })
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
        let schemeEndOpt = remaining.indexOf("://")
        if (schemeEndOpt.isSome()) {
            let schemeEnd = Int64(schemeEndOpt.getOrThrow())
            protocol = remaining[0..schemeEnd]
            remaining = remaining[schemeEnd + 3..]
        }

        // hash
        let hashIdxOpt = remaining.indexOf("#")
        if (hashIdxOpt.isSome()) {
            let hashIdx = Int64(hashIdxOpt.getOrThrow())
            hash = remaining[hashIdx..]
            remaining = remaining[0..hashIdx]
        }

        // query
        let queryIdxOpt = remaining.indexOf("?")
        if (queryIdxOpt.isSome()) {
            let queryIdx = Int64(queryIdxOpt.getOrThrow())
            search = remaining[queryIdx..]
            searchParams = URLSearchParams()
            remaining = remaining[0..queryIdx]
        }

        // auth
        let atIdxOpt = remaining.indexOf("@")
        if (atIdxOpt.isSome()) {
            let atIdx = Int64(atIdxOpt.getOrThrow())
            let auth = remaining[0..atIdx]
            let colonIdxOpt = auth.indexOf(":")
            if (colonIdxOpt.isSome()) {
                let colonIdx = Int64(colonIdxOpt.getOrThrow())
                username = auth[0..colonIdx]
                password = auth[colonIdx + 1..]
            } else {
                username = auth
            }
            remaining = remaining[atIdx + 1..]
        }

        // host:port
        let slashIdxOpt = remaining.indexOf("/")
        if (slashIdxOpt.isSome()) {
            let slashIdx = Int64(slashIdxOpt.getOrThrow())
            let hostPart = remaining[0..slashIdx]
            pathname = remaining[slashIdx..]
            parseHostPort(hostPart)
        } else {
            parseHostPort(remaining)
            pathname = "/"
        }

        origin = protocol + "://" + hostname + (if (port.size > 0) { ":" + port } else { "" })
    }

    func parseHostPort(hostPort: String) {
        let bracketEndOpt = hostPort.indexOf("]")
        if (bracketEndOpt.isSome()) {
            let bracketEnd = Int64(bracketEndOpt.getOrThrow())
            // IPv6
            hostname = hostPort[0..bracketEnd + 1]
            if (bracketEnd + 2 < hostPort.size && hostPort[bracketEnd + 1] == UInt8(58)) {  // ':'
                port = hostPort[bracketEnd + 2..]
            }
        } else {
            let colonIdxOpt = hostPort.lastIndexOf(":")
            if (colonIdxOpt.isSome()) {
                let colonIdx = Int64(colonIdxOpt.getOrThrow())
                hostname = hostPort[0..colonIdx]
                port = hostPort[colonIdx + 1..]
            } else {
                hostname = hostPort
            }
        }
    }

    // URL.canParse
    public static func canParse(url: String): Bool {
        url.indexOf("://").isSome() || url.startsWith("/") || url.startsWith("./") || url.startsWith("../")
    }

    // 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject.make()
        obj.className = "URL"
        obj.set("href", JsValue(href))
        obj.set("protocol", JsValue(protocol))
        obj.set("username", JsValue(username))
        obj.set("password", JsValue(password))
        obj.set("hostname", JsValue(hostname))
        obj.set("port", JsValue(port))
        obj.set("pathname", JsValue(pathname))
        obj.set("search", JsValue(search))
        obj.set("hash", JsValue(hash))
        obj.set("origin", JsValue(origin))
        JsValue(obj)
    }
}

// 注意: URLSearchParams 已移至 url_search_params.cj
// 注意: DOMURL 已移至 domurl.cj
// 注意: DOMFormData 已移至 dom_form_data.cj
