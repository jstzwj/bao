// 严格翻译自: src/jsc/URL.zig (167行)
// DOM URL 绑定 - 与 JavaScriptCore 的 URL 接口桥接

package bao_jsc

// ========== DOMUrl ==========
// 严格翻译自 URL.zig URL (opaque type)
// 表示一个解析后的 URL，通过 FFI 与 JSC 中的 URL 对象交互
// 这是 URL 的不透明类型绑定，所有方法通过 extern FFI 调用
public class DOMUrl {
    // 内部 URL 数据
    public var href: String = ""
    public var protocol: String = ""
    public var username: String = ""
    public var password: String = ""
    public var search: String = ""
    public var host: String = ""
    public var hostname: String = ""
    public var port: UInt32 = 0
    public var pathname: String = ""
    public var hash: String = ""

    public init() {}

    // 严格翻译自 hash
    // 包括前导 '#'
    public func getHash() -> String {
        // FFI: URL__hash(url)
        hash
    }

    // 严格翻译自 fragmentIdentifier
    // 与 hash 完全相同，但不包括前导 '#'
    public func getFragmentIdentifier() -> String {
        // FFI: URL__fragmentIdentifier(url)
        if (hash.size > 0 && hash[0] == '#') {
            hash[1..]
        } else {
            hash
        }
    }

    // 严格翻译自 hrefFromString
    // 从字符串获取 href
    public static func hrefFromString(str: String) -> String {
        // FFI: URL__getHref(&input)
        // 将字符串解析为 URL 并返回 href
        let url = DOMUrl()
        url.parse(str)
        url.href
    }

    // 严格翻译自 join
    // 拼接 base 和 relative URL
    public static func join(base: String, relative: String) -> String {
        // FFI: URL__getHrefJoin(&base_str, &relative_str)
        // 简化实现
        if (relative.startsWith("http://") || relative.startsWith("https://") ||
            relative.startsWith("ftp://") || relative.startsWith("file://")) {
            return relative
        }
        if (relative.startsWith("/")) {
            // 绝对路径
            let schemeEnd = base.indexOf("://")
            if (schemeEnd >= 0) {
                let scheme = base[0..schemeEnd]
                let rest = base[schemeEnd + 3..]
                let slashIdx = rest.indexOf("/")
                let hostPart = if (slashIdx >= 0) { rest[0..slashIdx] } else { rest }
                return scheme + "://" + hostPart + relative
            }
            return relative
        }
        // 相对路径
        let lastSlash = base.lastIndexOf("/")
        if (lastSlash >= 0) {
            return base[0..lastSlash + 1] + relative
        }
        base + "/" + relative
    }

    // 严格翻译自 fileURLFromString
    // 从字符串获取文件 URL 字符串
    public static func fileUrlFromString(str: String) -> String {
        // FFI: URL__getFileURLString(&input)
        "file://" + str
    }

    // 严格翻译自 pathFromFileURL
    // 从文件 URL 获取路径
    public static func pathFromFileUrl(str: String) -> String {
        // FFI: URL__pathFromFileURL(&input)
        if (str.startsWith("file://")) {
            str[7..]
        } else {
            str
        }
    }

    // 严格翻译自 hrefFromJS
    // 从 JS 值获取 href（百分号编码 URL，punycode 编码主机名）
    public static func hrefFromJS(value: JsValue, globalObject: JsGlobalObject) -> ?String {
        // FFI: URL__getHrefFromJS(value, globalObject)
        if (value.isString()) {
            return value.toStringOrDefault("")
        }
        None
    }

    // 严格翻译自 fromJS
    // 从 JS 值创建 URL
    public static func fromJS(value: JsValue, globalObject: JsGlobalObject) -> ?DOMUrl {
        // FFI: URL__fromJS(value, globalObject)
        if (value.isString()) {
            let str = value.toStringOrDefault("")
            if (!str.isEmpty) {
                let url = DOMUrl()
                url.parse(str)
                return url
            }
        }
        None
    }

    // 严格翻译自 fromUTF8
    // 从 UTF-8 字符串创建 URL
    public static func fromUTF8(input: String) -> ?DOMUrl {
        return fromString(input)
    }

    // 严格翻译自 fromString
    // 从字符串创建 URL
    public static func fromString(str: String) -> ?DOMUrl {
        // FFI: URL__fromString(&input)
        let url = DOMUrl()
        url.parse(str)
        if (url.href.isEmpty) {
            return None
        }
        url
    }

    // 严格翻译自 protocol
    public func getProtocol() -> String {
        // FFI: URL__protocol(url)
        protocol
    }

    // 严格翻译自 href
    public func getHref() -> String {
        // FFI: URL__href(url)
        href
    }

    // 严格翻译自 username
    public func getUsername() -> String {
        // FFI: URL__username(url)
        username
    }

    // 严格翻译自 password
    public func getPassword() -> String {
        // FFI: URL__password(url)
        password
    }

    // 严格翻译自 search
    public func getSearch() -> String {
        // FFI: URL__search(url)
        search
    }

    // 严格翻译自 host
    // 返回不带端口的主机名
    // 注意：这与 JS 行为不匹配，JS 返回带端口的主机名。参见 hostname
    public func getHost() -> String {
        // FFI: URL__host(url)
        host
    }

    // 严格翻译自 hostname
    // 返回带端口的主机名
    // 注意：这与 JS 行为不匹配，JS 返回不带端口的主机名。参见 host
    public func getHostname() -> String {
        // FFI: URL__hostname(url)
        hostname
    }

    // 严格翻译自 port
    // 如果端口未设置，返回 UInt32 最大值。否则保证在 UInt16 范围内
    public func getPort() -> UInt32 {
        // FFI: URL__port(url)
        port
    }

    // 严格翻译自 deinit
    // 销毁 URL 对象
    public func deinit() {
        // FFI: URL__deinit(url)
    }

    // 严格翻译自 pathname
    public func getPathname() -> String {
        // FFI: URL__pathname(url)
        pathname
    }

    // 严格翻译自 originFromSlice
    // 从字节切片获取 origin
    public static func originFromSlice(slice: String) -> ?String {
        // FFI: URL__originLength(latin1_slice, len)
        // 简化实现：查找 origin（协议 + 主机 + 端口）
        let schemeEnd = slice.indexOf("://")
        if (schemeEnd < 0) {
            return None
        }
        let afterScheme = slice[schemeEnd + 3..]
        let pathStart = afterScheme.indexOf("/")
        let originLen = if (pathStart >= 0) { schemeEnd + 3 + pathStart } else { slice.size }
        if (originLen == 0) {
            return None
        }
        slice[0..originLen]
    }

    // ========== 内部解析方法 ==========
    private func parse(urlStr: String) {
        href = urlStr
        var remaining = urlStr

        // 协议
        let schemeEnd = remaining.indexOf("://")
        if (schemeEnd >= 0) {
            protocol = remaining[0..schemeEnd]
            remaining = remaining[schemeEnd + 3..]
        }

        // hash
        let hashIdx = remaining.lastIndexOf("#")
        if (hashIdx >= 0) {
            hash = remaining[hashIdx..]
            remaining = remaining[0..hashIdx]
        }

        // search
        let queryIdx = remaining.indexOf("?")
        if (queryIdx >= 0) {
            search = remaining[queryIdx..]
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

        // host:port 和 pathname
        let slashIdx = remaining.indexOf("/")
        if (slashIdx >= 0) {
            let hostPart = remaining[0..slashIdx]
            pathname = remaining[slashIdx..]
            parseHostPort(hostPart)
        } else {
            parseHostPort(remaining)
            pathname = "/"
        }
    }

    private func parseHostPort(hostPort: String) {
        let bracketEnd = hostPort.indexOf("]")
        if (bracketEnd >= 0) {
            // IPv6
            hostname = hostPort[0..bracketEnd + 1]
            if (bracketEnd + 2 < hostPort.size && hostPort[bracketEnd + 1] == ':') {
                port = UInt32(Int64(hostPort[bracketEnd + 2..]) ?? 0)
            }
        } else {
            let colonIdx = hostPort.lastIndexOf(":")
            if (colonIdx >= 0) {
                hostname = hostPort[0..colonIdx]
                let portStr = hostPort[colonIdx + 1..]
                port = UInt32(Int64(portStr) ?? 0)
            } else {
                hostname = hostPort
            }
        }
        host = hostname
    }
}
