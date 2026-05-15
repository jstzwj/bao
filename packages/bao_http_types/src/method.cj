// HTTP 方法枚举与工具
// 严格翻译自: src/http_types/Method.zig
//   Bun 支持全部 36 种标准及扩展 HTTP 方法
//   包含方法查找 (大小写不敏感)、幂等性判断、请求体/响应体判断
package bao_http_types

import bao_core.*

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
        s.put("HEAD")
        s.put("TRACE")
        return s
    }

    private static func buildNoRequestBodySet(): HashSet<String> {
        let s = HashSet<String>()
        s.put("GET")
        s.put("HEAD")
        s.put("OPTIONS")
        s.put("TRACE")
        return s
    }

    private static func buildIdempotentSet(): HashSet<String> {
        let s = HashSet<String>()
        s.put("GET")
        s.put("HEAD")
        s.put("PUT")
        s.put("DELETE")
        s.put("OPTIONS")
        s.put("TRACE")
        s.put("QUERY")
        return s
    }

    private static func buildMethodMap(): HashMap<String, HttpMethod> {
        let m = HashMap<String, HttpMethod>()
        // 大写映射
        m.put("ACL", HttpMethod.ACL)
        m.put("BIND", HttpMethod.BIND)
        m.put("CHECKOUT", HttpMethod.CHECKOUT)
        m.put("CONNECT", HttpMethod.CONNECT)
        m.put("COPY", HttpMethod.COPY)
        m.put("DELETE", HttpMethod.DELETE)
        m.put("GET", HttpMethod.GET)
        m.put("HEAD", HttpMethod.HEAD)
        m.put("LINK", HttpMethod.LINK)
        m.put("LOCK", HttpMethod.LOCK)
        m.put("M-SEARCH", HttpMethod.M_SEARCH)
        m.put("MERGE", HttpMethod.MERGE)
        m.put("MKACTIVITY", HttpMethod.MKACTIVITY)
        m.put("MKADDRESSBOOK", HttpMethod.MKADDRESSBOOK)
        m.put("MKCALENDAR", HttpMethod.MKCALENDAR)
        m.put("MKCOL", HttpMethod.MKCOL)
        m.put("MOVE", HttpMethod.MOVE)
        m.put("NOTIFY", HttpMethod.NOTIFY)
        m.put("OPTIONS", HttpMethod.OPTIONS)
        m.put("PATCH", HttpMethod.PATCH)
        m.put("POST", HttpMethod.POST)
        m.put("PROPFIND", HttpMethod.PROPFIND)
        m.put("PROPPATCH", HttpMethod.PROPPATCH)
        m.put("PURGE", HttpMethod.PURGE)
        m.put("PUT", HttpMethod.PUT)
        m.put("QUERY", HttpMethod.QUERY)
        m.put("REBIND", HttpMethod.REBIND)
        m.put("REPORT", HttpMethod.REPORT)
        m.put("SEARCH", HttpMethod.SEARCH)
        m.put("SOURCE", HttpMethod.SOURCE)
        m.put("SUBSCRIBE", HttpMethod.SUBSCRIBE)
        m.put("TRACE", HttpMethod.TRACE)
        m.put("UNBIND", HttpMethod.UNBIND)
        m.put("UNLINK", HttpMethod.UNLINK)
        m.put("UNLOCK", HttpMethod.UNLOCK)
        m.put("UNSUBSCRIBE", HttpMethod.UNSUBSCRIBE)

        // 小写映射
        m.put("acl", HttpMethod.ACL)
        m.put("bind", HttpMethod.BIND)
        m.put("checkout", HttpMethod.CHECKOUT)
        m.put("connect", HttpMethod.CONNECT)
        m.put("copy", HttpMethod.COPY)
        m.put("delete", HttpMethod.DELETE)
        m.put("get", HttpMethod.GET)
        m.put("head", HttpMethod.HEAD)
        m.put("link", HttpMethod.LINK)
        m.put("lock", HttpMethod.LOCK)
        m.put("m-search", HttpMethod.M_SEARCH)
        m.put("merge", HttpMethod.MERGE)
        m.put("mkactivity", HttpMethod.MKACTIVITY)
        m.put("mkaddressbook", HttpMethod.MKADDRESSBOOK)
        m.put("mkcalendar", HttpMethod.MKCALENDAR)
        m.put("mkcol", HttpMethod.MKCOL)
        m.put("move", HttpMethod.MOVE)
        m.put("notify", HttpMethod.NOTIFY)
        m.put("options", HttpMethod.OPTIONS)
        m.put("patch", HttpMethod.PATCH)
        m.put("post", HttpMethod.POST)
        m.put("propfind", HttpMethod.PROPFIND)
        m.put("proppatch", HttpMethod.PROPPATCH)
        m.put("purge", HttpMethod.PURGE)
        m.put("put", HttpMethod.PUT)
        m.put("query", HttpMethod.QUERY)
        m.put("rebind", HttpMethod.REBIND)
        m.put("report", HttpMethod.REPORT)
        m.put("search", HttpMethod.SEARCH)
        m.put("source", HttpMethod.SOURCE)
        m.put("subscribe", HttpMethod.SUBSCRIBE)
        m.put("trace", HttpMethod.TRACE)
        m.put("unbind", HttpMethod.UNBIND)
        m.put("unlink", HttpMethod.UNLINK)
        m.put("unlock", HttpMethod.UNLOCK)
        m.put("unsubscribe", HttpMethod.UNSUBSCRIBE)
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
// 严格翻译自: Method.zig Optional union
// 用于表示 "任意方法" 或 "特定方法集合" 的过滤器
// ============================================================================

/// 方法可选集合 - 对应 Bun Method.Optional
public enum MethodOptional {
    | Any
    | Methods(HashSet<HttpMethod>)

    /// 检查两个方法集合是否有交集 - 对应 Bun Optional.contains()
    public func contains(other: MethodOptional): Bool {
        match (this) {
            case MethodOptional.Any => true
            case MethodOptional.Methods(set1) =>
                match (other) {
                    case MethodOptional.Any => true
                    case MethodOptional.Methods(set2) =>
                        // 检查是否有交集
                        var hasOverlap = false
                        for (m in set1) {
                            if (set2.contains(m)) {
                                hasOverlap = true
                                break
                            }
                        }
                        hasOverlap
                }
        }
    }

    /// 插入一个方法 - 对应 Bun Optional.insert()
    /// 如果集合已包含所有方法，则变为 Any
    public func insert(method: HttpMethod): MethodOptional {
        match (this) {
            case MethodOptional.Any => MethodOptional.Any
            case MethodOptional.Methods(set) =>
                set.put(method)
                // 简化: 不检测是否已满，保持为 Methods
                MethodOptional.Methods(set)
        }
    }
}
