// HTTP 方法枚举与工具
// 严格翻译自: src/http_types/Method.zig
//   Bun 支持全部 36 种标准及扩展 HTTP 方法
//   包含方法查找 (大小写不敏感)、幂等性判断、请求体/响应体判断
package bao_http_types

import bao_core.*
import std.collection.*

// ============================================================================
// HttpMethod - HTTP 方法枚举
// 严格翻译自: Method.zig Method enum(u8)
// Bun 使用 ComptimeStringMap 实现大小写不敏感查找
// ============================================================================

/// HTTP 方法枚举 - 对应 Bun Method enum
/// 包含所有标准及 WebDAV 扩展方法
public enum HttpMethod {
    | ACL
    | BIND
    | CHECKOUT
    | CONNECT
    | COPY
    | DELETE
    | GET
    | HEAD
    | LINK
    | LOCK
    | M_SEARCH    // M-SEARCH (SSDP)
    | MERGE
    | MKACTIVITY
    | MKADDRESSBOOK
    | MKCALENDAR
    | MKCOL
    | MOVE
    | NOTIFY
    | OPTIONS
    | PATCH
    | POST
    | PROPFIND
    | PROPPATCH
    | PURGE
    | PUT
    | QUERY       // https://httpwg.org/http-extensions/draft-ietf-httpbis-safe-method-w-body.html
    | REBIND
    | REPORT
    | SEARCH
    | SOURCE
    | SUBSCRIBE
    | TRACE
    | UNBIND
    | UNLINK
    | UNLOCK
    | UNSUBSCRIBE
}

// ============================================================================
// HttpMethodExtensions - HttpMethod 扩展方法
// 严格翻译自: Method.zig 中 hasBody/hasRequestBody/isIdempotent/find/which
// ============================================================================

/// HttpMethod 扩展工具函数
public class MethodUtil {
    /// 没有响应体的方法集合 - 对应 Bun with_body (移除 HEAD, TRACE)
    /// Bun: with_body = initFull() - {HEAD, TRACE}
    private static let NO_BODY_METHODS: HashSet<String> = buildNoBodySet()

    /// 没有请求体的方法集合 - 对应 Bun with_request_body
    /// Bun: with_request_body = initFull() - {GET, HEAD, OPTIONS, TRACE}
    private static let NO_REQUEST_BODY_METHODS: HashSet<String> = buildNoRequestBodySet()

    /// 幂等方法集合 - 对应 Bun idempotent set
    /// Per RFC 7231 §4.2.2: GET, HEAD, PUT, DELETE, OPTIONS, TRACE, QUERY
    private static let IDEMPOTENT_METHODS: HashSet<String> = buildIdempotentSet()

    /// 大小写不敏感查找表 - 对应 Bun ComptimeStringMap
    private static let METHOD_MAP: HashMap<String, HttpMethod> = buildMethodMap()

    private static func buildNoBodySet(): HashSet<String> {
        let s = HashSet<String>()
        s.add("HEAD")
        s.add("TRACE")
        return s
    }

    private static func buildNoRequestBodySet(): HashSet<String> {
        let s = HashSet<String>()
        s.add("GET")
        s.add("HEAD")
        s.add("OPTIONS")
        s.add("TRACE")
        return s
    }

    private static func buildIdempotentSet(): HashSet<String> {
        let s = HashSet<String>()
        s.add("GET")
        s.add("HEAD")
        s.add("PUT")
        s.add("DELETE")
        s.add("OPTIONS")
        s.add("TRACE")
        s.add("QUERY")
        return s
    }

    private static func buildMethodMap(): HashMap<String, HttpMethod> {
        let m = HashMap<String, HttpMethod>()
        // 大写映射
        m.add("ACL", HttpMethod.ACL)
        m.add("BIND", HttpMethod.BIND)
        m.add("CHECKOUT", HttpMethod.CHECKOUT)
        m.add("CONNECT", HttpMethod.CONNECT)
        m.add("COPY", HttpMethod.COPY)
        m.add("DELETE", HttpMethod.DELETE)
        m.add("GET", HttpMethod.GET)
        m.add("HEAD", HttpMethod.HEAD)
        m.add("LINK", HttpMethod.LINK)
        m.add("LOCK", HttpMethod.LOCK)
        m.add("M-SEARCH", HttpMethod.M_SEARCH)
        m.add("MERGE", HttpMethod.MERGE)
        m.add("MKACTIVITY", HttpMethod.MKACTIVITY)
        m.add("MKADDRESSBOOK", HttpMethod.MKADDRESSBOOK)
        m.add("MKCALENDAR", HttpMethod.MKCALENDAR)
        m.add("MKCOL", HttpMethod.MKCOL)
        m.add("MOVE", HttpMethod.MOVE)
        m.add("NOTIFY", HttpMethod.NOTIFY)
        m.add("OPTIONS", HttpMethod.OPTIONS)
        m.add("PATCH", HttpMethod.PATCH)
        m.add("POST", HttpMethod.POST)
        m.add("PROPFIND", HttpMethod.PROPFIND)
        m.add("PROPPATCH", HttpMethod.PROPPATCH)
        m.add("PURGE", HttpMethod.PURGE)
        m.add("PUT", HttpMethod.PUT)
        m.add("QUERY", HttpMethod.QUERY)
        m.add("REBIND", HttpMethod.REBIND)
        m.add("REPORT", HttpMethod.REPORT)
        m.add("SEARCH", HttpMethod.SEARCH)
        m.add("SOURCE", HttpMethod.SOURCE)
        m.add("SUBSCRIBE", HttpMethod.SUBSCRIBE)
        m.add("TRACE", HttpMethod.TRACE)
        m.add("UNBIND", HttpMethod.UNBIND)
        m.add("UNLINK", HttpMethod.UNLINK)
        m.add("UNLOCK", HttpMethod.UNLOCK)
        m.add("UNSUBSCRIBE", HttpMethod.UNSUBSCRIBE)

        // 小写映射
        m.add("acl", HttpMethod.ACL)
        m.add("bind", HttpMethod.BIND)
        m.add("checkout", HttpMethod.CHECKOUT)
        m.add("connect", HttpMethod.CONNECT)
        m.add("copy", HttpMethod.COPY)
        m.add("delete", HttpMethod.DELETE)
        m.add("get", HttpMethod.GET)
        m.add("head", HttpMethod.HEAD)
        m.add("link", HttpMethod.LINK)
        m.add("lock", HttpMethod.LOCK)
        m.add("m-search", HttpMethod.M_SEARCH)
        m.add("merge", HttpMethod.MERGE)
        m.add("mkactivity", HttpMethod.MKACTIVITY)
        m.add("mkaddressbook", HttpMethod.MKADDRESSBOOK)
        m.add("mkcalendar", HttpMethod.MKCALENDAR)
        m.add("mkcol", HttpMethod.MKCOL)
        m.add("move", HttpMethod.MOVE)
        m.add("notify", HttpMethod.NOTIFY)
        m.add("options", HttpMethod.OPTIONS)
        m.add("patch", HttpMethod.PATCH)
        m.add("post", HttpMethod.POST)
        m.add("propfind", HttpMethod.PROPFIND)
        m.add("proppatch", HttpMethod.PROPPATCH)
        m.add("purge", HttpMethod.PURGE)
        m.add("put", HttpMethod.PUT)
        m.add("query", HttpMethod.QUERY)
        m.add("rebind", HttpMethod.REBIND)
        m.add("report", HttpMethod.REPORT)
        m.add("search", HttpMethod.SEARCH)
        m.add("source", HttpMethod.SOURCE)
        m.add("subscribe", HttpMethod.SUBSCRIBE)
        m.add("trace", HttpMethod.TRACE)
        m.add("unbind", HttpMethod.UNBIND)
        m.add("unlink", HttpMethod.UNLINK)
        m.add("unlock", HttpMethod.UNLOCK)
        m.add("unsubscribe", HttpMethod.UNSUBSCRIBE)
        return m
    }

    /// 从字符串查找 HTTP 方法 - 对应 Bun Method.find(str)
    /// 支持大小写不敏感匹配
    public static func find(str: String): ?HttpMethod {
        return METHOD_MAP.get(str)
    }

    /// 从字符串查找 HTTP 方法 (find 的别名) - 对应 Bun Method.which(str)
    public static func which(str: String): ?HttpMethod {
        return METHOD_MAP.get(str)
    }

    /// HTTP 方法是否有响应体 - 对应 Bun Method.hasBody()
    /// Bun: with_body = 全部 - {HEAD, TRACE}
    public static func hasBody(method: HttpMethod): Bool {
        let name = toString(method)
        return !NO_BODY_METHODS.contains(name)
    }

    /// HTTP 方法是否有请求体 - 对应 Bun Method.hasRequestBody()
    /// Bun: with_request_body = 全部 - {GET, HEAD, OPTIONS, TRACE}
    public static func hasRequestBody(method: HttpMethod): Bool {
        let name = toString(method)
        return !NO_REQUEST_BODY_METHODS.contains(name)
    }

    /// HTTP 方法是否幂等 - 对应 Bun Method.isIdempotent()
    /// Per RFC 7231 §4.2.2, POST 和 PATCH 不幂等
    public static func isIdempotent(method: HttpMethod): Bool {
        let name = toString(method)
        return IDEMPOTENT_METHODS.contains(name)
    }

    /// HttpMethod 枚举转字符串 - 对应 Bun Method tag name
    public static func toString(method: HttpMethod): String {
        match (method) {
            case HttpMethod.ACL => "ACL"
            case HttpMethod.BIND => "BIND"
            case HttpMethod.CHECKOUT => "CHECKOUT"
            case HttpMethod.CONNECT => "CONNECT"
            case HttpMethod.COPY => "COPY"
            case HttpMethod.DELETE => "DELETE"
            case HttpMethod.GET => "GET"
            case HttpMethod.HEAD => "HEAD"
            case HttpMethod.LINK => "LINK"
            case HttpMethod.LOCK => "LOCK"
            case HttpMethod.M_SEARCH => "M-SEARCH"
            case HttpMethod.MERGE => "MERGE"
            case HttpMethod.MKACTIVITY => "MKACTIVITY"
            case HttpMethod.MKADDRESSBOOK => "MKADDRESSBOOK"
            case HttpMethod.MKCALENDAR => "MKCALENDAR"
            case HttpMethod.MKCOL => "MKCOL"
            case HttpMethod.MOVE => "MOVE"
            case HttpMethod.NOTIFY => "NOTIFY"
            case HttpMethod.OPTIONS => "OPTIONS"
            case HttpMethod.PATCH => "PATCH"
            case HttpMethod.POST => "POST"
            case HttpMethod.PROPFIND => "PROPFIND"
            case HttpMethod.PROPPATCH => "PROPPATCH"
            case HttpMethod.PURGE => "PURGE"
            case HttpMethod.PUT => "PUT"
            case HttpMethod.QUERY => "QUERY"
            case HttpMethod.REBIND => "REBIND"
            case HttpMethod.REPORT => "REPORT"
            case HttpMethod.SEARCH => "SEARCH"
            case HttpMethod.SOURCE => "SOURCE"
            case HttpMethod.SUBSCRIBE => "SUBSCRIBE"
            case HttpMethod.TRACE => "TRACE"
            case HttpMethod.UNBIND => "UNBIND"
            case HttpMethod.UNLINK => "UNLINK"
            case HttpMethod.UNLOCK => "UNLOCK"
            case HttpMethod.UNSUBSCRIBE => "UNSUBSCRIBE"
        }
    }

    /// 从字符串解析方法，找不到返回 -1 - 对应 Bun Bun__HTTPMethod__from
    public static func fromString(str: String): Int16 {
        let m = find(str)
        if (m.isSome()) {
            return Int16(ordinal(m.getOrThrow()))
        }
        return Int16(-1)
    }

    /// 获取枚举序号
    public static func ordinal(method: HttpMethod): Int64 {
        match (method) {
            case HttpMethod.ACL => 0
            case HttpMethod.BIND => 1
            case HttpMethod.CHECKOUT => 2
            case HttpMethod.CONNECT => 3
            case HttpMethod.COPY => 4
            case HttpMethod.DELETE => 5
            case HttpMethod.GET => 6
            case HttpMethod.HEAD => 7
            case HttpMethod.LINK => 8
            case HttpMethod.LOCK => 9
            case HttpMethod.M_SEARCH => 10
            case HttpMethod.MERGE => 11
            case HttpMethod.MKACTIVITY => 12
            case HttpMethod.MKADDRESSBOOK => 13
            case HttpMethod.MKCALENDAR => 14
            case HttpMethod.MKCOL => 15
            case HttpMethod.MOVE => 16
            case HttpMethod.NOTIFY => 17
            case HttpMethod.OPTIONS => 18
            case HttpMethod.PATCH => 19
            case HttpMethod.POST => 20
            case HttpMethod.PROPFIND => 21
            case HttpMethod.PROPPATCH => 22
            case HttpMethod.PURGE => 23
            case HttpMethod.PUT => 24
            case HttpMethod.QUERY => 25
            case HttpMethod.REBIND => 26
            case HttpMethod.REPORT => 27
            case HttpMethod.SEARCH => 28
            case HttpMethod.SOURCE => 29
            case HttpMethod.SUBSCRIBE => 30
            case HttpMethod.TRACE => 31
            case HttpMethod.UNBIND => 32
            case HttpMethod.UNLINK => 33
            case HttpMethod.UNLOCK => 34
            case HttpMethod.UNSUBSCRIBE => 35
        }
    }
}

// ============================================================================
// MethodOptional - 方法可选集
// ============================================================================

/// 方法可选集合 - 简化占位
public enum MethodOptional {
    | Any
    | Methods
}
