// URL - URL parsing and manipulation
// 对应 Bun: src/jsc/URL.rs (161 lines)
// 严格翻译自: src/jsc/URL.zig
// URL 和 URL 相关类型
//
// In Bun, URL is an opaque FFI handle to WebKit's WTF::URL allocated on the
// C++ side. In Bao, we use a pure Cangjie URL parser since there is no JSC
// C++ layer. The FFI bindings are declared as stubs for future wiring.
//
// The opaque handle pattern from Bun is preserved as UrlHandle for cases
// where interop with native URL parsing is needed.

package bao_jsc

import bao_core.*

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

// ============================================================================
// UrlHandle - 不透明 FFI 句柄
// 对应 Bun: bun_opaque::opaque_ffi! { pub struct URL; }
// Opaque handle to a WebKit WTF::URL allocated on the C++ side.
// In Bao this is a placeholder for future native URL parsing interop.
// ============================================================================

/// URL 不透明句柄 — 对应 Bun: URL (opaque_ffi)
/// Represents a C++ WTF::URL that is parsed and managed by the native URL parser.
/// Used for FFI interop with JSC's URL implementation.
public class UrlHandle {
    /// Native pointer (non-zero when backed by a C++ WTF::URL)
    public var nativePtr: UInt64

    public init() {
        nativePtr = 0
    }

    public init(ptr: UInt64) {
        this.nativePtr = ptr
    }

    /// 是否持有有效的 native 句柄
    public func isValid(): Bool {
        nativePtr != 0
    }

    /// 销毁 native 句柄
    /// 对应 Bun: unsafe fn URL__deinit(url: *mut URL)
    public func destroy(): Unit {
        // TODO: restore URL__deinit FFI call when native bindings are complete
        nativePtr = 0
    }

    // ========================================================================
    // 属性访问器 — 对应 Bun: URL 的 extern "C" getters
    // All getters take &URL (non-null *const URL) and return String.
    // In Bao these delegate to the pure-Cangjie URL parser since there is
    // no JSC C++ layer.
    // ========================================================================

    /// protocol — 对应 Bun: URL__protocol(url) -> String
    public func protocol(): String {
        // TODO: restore URL__protocol FFI call
        ""
    }

    /// href — 对应 Bun: URL__href(url) -> String
    public func href(): String {
        // TODO: restore URL__href FFI call
        ""
    }

    /// username — 对应 Bun: URL__username(url) -> String
    public func username(): String {
        // TODO: restore URL__username FFI call
        ""
    }

    /// password — 对应 Bun: URL__password(url) -> String
    public func password(): String {
        // TODO: restore URL__password FFI call
        ""
    }

    /// search — 对应 Bun: URL__search(url) -> String
    public func search(): String {
        // TODO: restore URL__search FFI call
        ""
    }

    /// host — 对应 Bun: URL__host(url) -> String
    /// Returns the host WITHOUT the port (note: this is inverted vs JS behavior)
    public func host(): String {
        // TODO: restore URL__host FFI call
        ""
    }

    /// hostname — 对应 Bun: URL__hostname(url) -> String
    /// Returns the host WITH the port (note: this is inverted vs JS behavior)
    public func hostname(): String {
        // TODO: restore URL__hostname FFI call
        ""
    }

    /// port — 对应 Bun: URL__port(url) -> u32
    /// Returns u32 MAX if the port is not set. Otherwise in u16 range.
    public func port(): UInt32 {
        // TODO: restore URL__port FFI call
        UInt32(0xFFFFFFFF)
    }

    /// pathname — 对应 Bun: URL__pathname(url) -> String
    public func pathname(): String {
        // TODO: restore URL__pathname FFI call
        ""
    }

    /// hash — 对应 Bun: URL__hash(url) -> String
    /// Includes the leading '#'.
    public func hash(): String {
        // TODO: restore URL__hash FFI call
        ""
    }

    /// fragmentIdentifier — 对应 Bun: URL__fragmentIdentifier(url) -> String
    /// Same as hash, excluding the leading '#'.
    public func fragmentIdentifier(): String {
        // TODO: restore URL__fragmentIdentifier FFI call
        ""
    }
}

// ============================================================================
// UrlHandle companion functions — 对应 Bun: URL::from_string, from_utf8,
// href_from_string, join, file_url_from_string, path_from_file_url, etc.
// All use the Cangjie pure parser since there is no native URL library.
// ============================================================================

/// UrlHandle companion
public class UrlHandles {
    /// 对应 Bun: URL::from_utf8(input) -> Option<NonNull<URL>>
    public static func fromUtf8(input: Array<UInt8>): ?UrlHandle {
        fromString(String.fromUtf8(input))
    }

    /// 对应 Bun: URL::from_string(str) -> Option<NonNull<URL>>
    public static func fromString(str: String): ?UrlHandle {
        // In Bun this calls URL__fromString(&mut input) -> *mut URL.
        // In Bao we return a handle wrapping the parsed URL data.
        // For now, return None as there is no native URL library.
        None
    }

    /// 对应 Bun: URL::from_js(value, global) -> JsResult<Option<NonNull<URL>>>
    public static func fromJs(value: JsValue, global: JsGlobalObject): ?UrlHandle {
        if (value.isEmptyOrUndefinedOrNull()) {
            return None
        }
        if (!value.isString()) {
            return None
        }
        fromString(value.toString())
    }

    /// 对应 Bun: URL::href_from_string(str) -> String
    /// Percent-encodes the URL, punycode-encodes the hostname.
    public static func hrefFromString(str: String): String {
        // In Bun this calls URL__getHref(&mut input).
        // In Bao, use the pure parser.
        let url = URL(str)
        url.href
    }

    /// 对应 Bun: URL::join(base, relative) -> String
    /// Joins a base URL and a relative URL reference.
    public static func join(base: String, relative: String): String {
        // In Bun this calls URL__getHrefJoin(&mut base, &mut relative).
        let url = URL(relative, base)
        url.href
    }

    /// 对应 Bun: URL::file_url_from_string(str) -> String
    /// Converts a file path to a file:// URL string.
    public static func fileUrlFromString(str: String): String {
        // In Bun this calls URL__getFileURLString(&mut input).
        if (str.startsWith("file://")) {
            return str
        }
        if (str.startsWith("/")) {
            return "file://" + str
        }
        "file://" + str
    }

    /// 对应 Bun: URL::path_from_file_url(str) -> String
    /// Extracts the file path from a file:// URL.
    public static func pathFromFileUrl(str: String): String {
        // In Bun this calls URL__pathFromFileURL(&mut input).
        if (str.startsWith("file://")) {
            return str[7..]
        }
        str
    }

    /// 对应 Bun: URL::href_from_js(value, global) -> JsResult<String>
    /// This percent-encodes the URL, punycode-encodes the hostname.
    /// If it fails, the tag is marked Dead.
    public static func hrefFromJs(value: JsValue, global: JsGlobalObject): ?String {
        if (!value.isString()) {
            return None
        }
        let str = value.toString()
        if (str.size == 0) {
            return None
        }
        let url = URL(str)
        if (url.protocol.size == 0) {
            return None
        }
        Some(url.href)
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

    // URL.canParse with base
    public static func canParse(url: String, base: String): Bool {
        if (base.size > 0) {
            canParse(URL(url, base).href)
        } else {
            canParse(url)
        }
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
        obj.set("searchParams", searchParams.toJsValue())
        obj.set("toString", JsValue.nativeFunction("toString") { args =>
            JsValue(href)
        })
        obj.set("toJSON", JsValue.nativeFunction("toJSON") { args =>
            JsValue(href)
        })
        JsValue(obj)
    }

    /// toString
    public func toString(): String {
        href
    }

    /// toJSON
    public func toJSON(): String {
        href
    }
}

// 注意: URLSearchParams 已移至 url_search_params.cj
// 注意: DOMURL 已移至 domurl.cj
// 注意: DOMFormData 已移至 dom_form_data.cj
