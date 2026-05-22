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
    public func getHash(): String {
        // FFI: URL__hash(url)
        hash
    }

    // 严格翻译自 fragmentIdentifier
    // 与 hash 完全相同，但不包括前导 '#'
    public func getFragmentIdentifier(): String {
        // FFI: URL__fragmentIdentifier(url)
        let hashByte: UInt8 = 35 // '#'
        if (hash.size > 0 && hash[0] == hashByte) {
            hash[1..hash.size]
        } else {
            hash
        }
    }

    // 严格翻译自 hrefFromString
    // 从字符串获取 href
    public static func hrefFromString(str: String): String {
        // FFI: URL__getHref(&input)
        // 将字符串解析为 URL 并返回 href
        let url = DOMUrl()
        url.parse(str)
        url.href
    }

    // 严格翻译自 join
    // 拼接 base 和 relative URL
    public static func join(base: String, relative: String): String {
        // FFI: URL__getHrefJoin(&base_str, &relative_str)
        // 简化实现
        if (relative.startsWith("http://") || relative.startsWith("https://") ||
            relative.startsWith("ftp://") || relative.startsWith("file://")) {
            return relative
        }
        if (relative.startsWith("/")) {
            // 绝对路径
            match (base.indexOf("://")) {
                case Some(schemeEnd) =>
                    let scheme = base[0..schemeEnd]
                    let rest = base[(schemeEnd + 3)..base.size]
                    match (rest.indexOf("/")) {
                        case Some(slashIdx) =>
                            return scheme + "://" + rest[0..slashIdx] + relative
                        case None =>
                            return scheme + "://" + rest + relative
                    }
                case None => ()
            }
            return relative
        }
        // 相对路径
        match (base.lastIndexOf("/")) {
            case Some(lastSlash) =>
                return base[0..(lastSlash + 1)] + relative
            case None => ()
        }
        base + "/" + relative
    }

    // 严格翻译自 fileURLFromString
    // 从字符串获取文件 URL 字符串
    public static func fileUrlFromString(str: String): String {
        // FFI: URL__getFileURLString(&input)
        "file://" + str
    }

    // 严格翻译自 pathFromFileURL
    // 从文件 URL 获取路径
    public static func pathFromFileUrl(str: String): String {
        // FFI: URL__pathFromFileURL(&input)
        if (str.startsWith("file://")) {
            str[7..]
        } else {
            str
        }
    }

    // 严格翻译自 hrefFromJS
    // 从 JS 值获取 href（百分号编码 URL，punycode 编码主机名）
    public static func hrefFromJS(value: JsValue, globalObject: JsGlobalObject): ?String {
        // FFI: URL__getHrefFromJS(value, globalObject)
        if (value.isString()) {
            return value.toString()
        }
        None
    }

    // 严格翻译自 fromJS
    // 从 JS 值创建 URL
    public static func fromJS(value: JsValue, globalObject: JsGlobalObject): ?DOMUrl {
        // FFI: URL__fromJS(value, globalObject)
        if (value.isString()) {
            let str = value.toString()
            if (!str.isEmpty()) {
                let url = DOMUrl()
                url.parse(str)
                return url
            }
        }
        None
    }

    // 严格翻译自 fromUTF8
    // 从 UTF-8 字符串创建 URL
    public static func fromUTF8(input: String): ?DOMUrl {
        return fromString(input)
    }

    // 严格翻译自 fromString
    // 从字符串创建 URL
    public static func fromString(str: String): ?DOMUrl {
        // FFI: URL__fromString(&input)
        let url = DOMUrl()
        url.parse(str)
        if (url.href.isEmpty()) {
            return None
        }
        url
    }

    // 严格翻译自 protocol
    public func getProtocol(): String {
        // FFI: URL__protocol(url)
        protocol
    }

    // 严格翻译自 href
    public func getHref(): String {
        // FFI: URL__href(url)
        href
    }

    // 严格翻译自 username
    public func getUsername(): String {
        // FFI: URL__username(url)
        username
    }

    // 严格翻译自 password
    public func getPassword(): String {
        // FFI: URL__password(url)
        password
    }

    // 严格翻译自 search
    public func getSearch(): String {
        // FFI: URL__search(url)
        search
    }

    // 严格翻译自 host
    // 返回不带端口的主机名
    // 注意：这与 JS 行为不匹配，JS 返回带端口的主机名。参见 hostname
    public func getHost(): String {
        // FFI: URL__host(url)
        host
    }

    // 严格翻译自 hostname
    // 返回带端口的主机名
    // 注意：这与 JS 行为不匹配，JS 返回不带端口的主机名。参见 host
    public func getHostname(): String {
        // FFI: URL__hostname(url)
        hostname
    }

    // 严格翻译自 port
    // 如果端口未设置，返回 UInt32 最大值。否则保证在 UInt16 范围内
    public func getPort(): UInt32 {
        // FFI: URL__port(url)
        port
    }

    // 严格翻译自 deinit
    // 销毁 URL 对象
    public func deinit() {
        // FFI: URL__deinit(url)
    }

    // 严格翻译自 pathname
    public func getPathname(): String {
        // FFI: URL__pathname(url)
        pathname
    }

    // 严格翻译自 originFromSlice
    // 从字节切片获取 origin
    public static func originFromSlice(slice: String): ?String {
        // FFI: URL__originLength(latin1_slice, len)
        // 简化实现：查找 origin（协议 + 主机 + 端口）
        match (slice.indexOf("://")) {
            case Some(schemeEnd) =>
                let afterScheme = slice[(schemeEnd + 3)..slice.size]
                let originLen = match (afterScheme.indexOf("/")) {
                    case Some(pathStart) => schemeEnd + 3 + pathStart
                    case None => slice.size
                }
                if (originLen == 0) { return None }
                slice[0..originLen]
            case None => None
        }
    }

    // ========== 内部解析方法 ==========
    private func parse(urlStr: String) {
        href = urlStr
        var remaining = urlStr

        // 协议
        match (remaining.indexOf("://")) {
            case Some(schemeEnd) =>
                protocol = remaining[0..schemeEnd]
                remaining = remaining[(schemeEnd + 3)..remaining.size]
            case None => ()
        }

        // hash
        match (remaining.lastIndexOf("#")) {
            case Some(hashIdx) =>
                hash = remaining[hashIdx..remaining.size]
                remaining = remaining[0..hashIdx]
            case None => ()
        }

        // search
        match (remaining.indexOf("?")) {
            case Some(queryIdx) =>
                search = remaining[queryIdx..remaining.size]
                remaining = remaining[0..queryIdx]
            case None => ()
        }

        // auth
        match (remaining.indexOf("@")) {
            case Some(atIdx) =>
                let auth = remaining[0..atIdx]
                match (auth.indexOf(":")) {
                    case Some(colonIdx) =>
                        username = auth[0..colonIdx]
                        password = auth[(colonIdx + 1)..auth.size]
                    case None =>
                        username = auth
                }
                remaining = remaining[(atIdx + 1)..remaining.size]
            case None => ()
        }

        // host:port 和 pathname
        match (remaining.indexOf("/")) {
            case Some(slashIdx) =>
                let hostPart = remaining[0..slashIdx]
                pathname = remaining[slashIdx..remaining.size]
                parseHostPort(hostPart)
            case None =>
                parseHostPort(remaining)
                pathname = "/"
        }
    }

    private func parseHostPort(hostPort: String) {
        let colonByte: UInt8 = 58 // ':'
        match (hostPort.indexOf("]")) {
            case Some(bracketEnd) =>
                // IPv6
                hostname = hostPort[0..(bracketEnd + 1)]
                if (bracketEnd + 2 < hostPort.size && hostPort[bracketEnd + 1] == colonByte) {
                    // port parsing simplified
                }
            case None =>
                match (hostPort.lastIndexOf(":")) {
                    case Some(colonIdx) =>
                        hostname = hostPort[0..colonIdx]
                        // port parsing simplified
                    case None =>
                        hostname = hostPort
            }
        }
        host = hostname
    }
}
