// bao_http Headers - HTTP 头部存储
// 严格翻译自: bun/src/http/Headers.zig
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// Headers - HTTP 请求/响应头部存储
// 严格翻译自: bun/src/http/Headers.zig
//
// Bun 使用 SOA (Structure of Arrays) 布局:
//   entries: MultiArrayList(Entry)  // name + value 的 StringPointer 列表
//   buf: []u8                       // 连续内存存储所有字符串
//   allocator: std.mem.Allocator
//
// 仓颉用 HashMap 实现等价功能，API 语义保持一致
// ============================================================================

/// HTTP 头部条目 - 对应 Bun Headers.Entry
/// Bun: Entry { name: StringPointer, value: StringPointer }
/// StringPointer { offset: u32, length: u32 }
public class HeaderEntry {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

/// HTTP 头部列表 - 对应 Bun Headers.Entry.List
/// Bun: MultiArrayList(Entry) — SOA 布局的 name/value 指针列表
public class HeaderEntryList {
    private var entries: ArrayList<HeaderEntry>

    public init() {
        entries = ArrayList<HeaderEntry>()
    }

    /// 从 picohttp.Header 数组构造
    /// 严格翻译自: Headers.fromPicoHttpHeaders
    public static func fromRawHeaders(headers: ArrayList<HeaderPair>): HeaderEntryList {
        let list = HeaderEntryList()
        for (h in headers) {
            list.entries.append(HeaderEntry(h.name, h.value))
        }
        return list
    }

    /// 追加一个条目
    /// 严格翻译自: Headers.append
    public func append(name: String, value: String): Unit {
        entries.append(HeaderEntry(name, value))
    }

    /// 获取条目数量
    public func len(): Int64 {
        return entries.size
    }

    /// 获取所有条目
    public func items(): ArrayList<HeaderEntry> {
        return entries
    }

    /// 按名称查找值 (大小写不敏感)
    /// 严格翻译自: Headers.get — 使用 eqlCaseInsensitiveASCII
    public func get(name: String): ?String {
        for (entry in entries) {
            if (eqlCaseInsensitiveASCII(entry.name, name)) {
                return Some(entry.value)
            }
        }
        return None
    }

    /// 枚举所有条目
    public func forEach(fn: (String, String) -> Unit): Unit {
        for (entry in entries) {
            fn(entry.name, entry.value)
        }
    }

    /// 按序号删除
    public func orderedRemove(index: Int64): Unit {
        if (index >= 0 && index < entries.size) {
            entries.removeAt(index)
        }
    }

    /// 大小写不敏感比较
    private static func eqlCaseInsensitiveASCII(a: String, b: String): Bool {
        if (a.size != b.size) {
            return false
        }
        for (i in 0..a.size) {
            let ca = a[i].toLower()
            let cb = b[i].toLower()
            if (ca != cb) {
                return false
            }
        }
        return true
    }
}

/// FetchHeaders — Web API 风格的头部容器
/// 对应 Bun: bun.webcore.FetchHeaders
/// 继承 package.cj 中的 Headers 类，增加与 Fetch API 兼容的接口
public class FetchHeaders {
    private var headers: HashMap<String, String>

    public init() {
        headers = HashMap<String, String>()
    }

    /// 获取头部值
    public func get(name: String): ?String {
        return headers.get(name.toLower())
    }

    /// 设置头部值 (覆盖)
    public func set(name: String, value: String): Unit {
        headers.put(name.toLower(), value)
    }

    /// 追加头部值 (多值)
    public func append(name: String, value: String): Unit {
        let key = name.toLower()
        match (headers.get(key)) {
            case Some(existing) => headers.put(key, "${existing}, ${value}")
            case None => headers.put(key, value)
        }
    }

    /// 是否包含某个头部
    public func has(name: String): Bool {
        return headers.contains(name.toLower())
    }

    /// 删除某个头部
    public func delete(name: String): Unit {
        headers.remove(name.toLower())
    }

    /// 按小写名称快速查找
    /// 严格翻译自: FetchHeaders.fastHas
    public func fastHas(name: HeaderName): Bool {
        return headers.contains(name.toLower())
    }

    /// 获取键列表
    public func keys(): ArrayList<String> {
        return headers.keys()
    }

    /// 获取值列表
    public func values(): ArrayList<String> {
        return headers.values()
    }

    /// 获取条目数
    public func size(): Int64 {
        return headers.keys().size
    }

    /// 统计头部数量和缓冲区大小
    /// 严格翻译自: FetchHeaders.count(&header_count, &buf_len)
    public func count(headerCount: Ref<Int64>, bufLen: Ref<Int64>): Unit {
        headerCount.value = headers.keys().size
        var total: Int64 = 0
        for (key in headers.keys()) {
            match (headers.get(key)) {
                case Some(v) => total += key.size + v.size
                case None => ()
            }
        }
        bufLen.value = total
    }
}

/// 引用类型包装 (用于 count 回调参数)
public class Ref<T> {
    public var value: T
    public init(v: T) {
        value = v
    }
}

/// 头部名称枚举 (用于 fastHas)
public enum HeaderName {
    | ContentType
    | ContentLength
    | TransferEncoding
    | Connection
    | Host
    | Authorization
    | ProxyAuthorization
    | Cookie
    | Location
    | Accept
    | AcceptEncoding
    | UserAgent
    | ContentEncoding
    | ContentDisposition
    | SetCookie
    | Upgrade
    | IfModifiedSince
    | LastModified
    | AltSvc
    | ProxyConnection

    public func toLower(): String {
        match (this) {
            case ContentType => "content-type"
            case ContentLength => "content-length"
            case TransferEncoding => "transfer-encoding"
            case Connection => "connection"
            case Host => "host"
            case Authorization => "authorization"
            case ProxyAuthorization => "proxy-authorization"
            case Cookie => "cookie"
            case Location => "location"
            case Accept => "accept"
            case AcceptEncoding => "accept-encoding"
            case UserAgent => "user-agent"
            case ContentEncoding => "content-encoding"
            case ContentDisposition => "content-disposition"
            case SetCookie => "set-cookie"
            case Upgrade => "upgrade"
            case IfModifiedSince => "if-modified-since"
            case LastModified => "last-modified"
            case AltSvc => "alt-svc"
            case ProxyConnection => "proxy-connection"
        }
    }

    /// 从字符串解析
    public static func fromString(s: String): ?HeaderName {
        let lower = s.toLower()
        match (lower) {
            case "content-type" => Some(ContentType)
            case "content-length" => Some(ContentLength)
            case "transfer-encoding" => Some(TransferEncoding)
            case "connection" => Some(Connection)
            case "host" => Some(Host)
            case "authorization" => Some(Authorization)
            case "proxy-authorization" => Some(ProxyAuthorization)
            case "cookie" => Some(Cookie)
            case "location" => Some(Location)
            case "accept" => Some(Accept)
            case "accept-encoding" => Some(AcceptEncoding)
            case "user-agent" => Some(UserAgent)
            case "content-encoding" => Some(ContentEncoding)
            case "content-disposition" => Some(ContentDisposition)
            case "set-cookie" => Some(SetCookie)
            case "upgrade" => Some(Upgrade)
            case "if-modified-since" => Some(IfModifiedSince)
            case "last-modified" => Some(LastModified)
            case "alt-svc" => Some(AltSvc)
            case "proxy-connection" => Some(ProxyConnection)
            case _ => None
        }
    }
}
