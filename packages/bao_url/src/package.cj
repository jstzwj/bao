// bao_url - URL 解析与处理
// 严格翻译自: src/url/url.zig, src/url/lib.rs
// WHATWG URL Standard 近似实现
//   - URL: 解析 URL 文本为结构化字段
//   - URLSearchParams: 查询字符串解析与操作
//   - PercentEncoding: URL 百分比编码/解码
//   - URL resolution: 相对 URL 解析
//   - URLPattern (简化版): URL 模式匹配
//   - Punycode: RFC 3492 Punycode 编码/解码
//   - IDNA: RFC 3490 国际化域名处理
package bao_url

import bao_core.*
import bao_collections.*
import bao_hash.*

// ============================================================================
// URL - URL 解析结构体
// 严格翻译自: src/url/url.zig - URL struct
//   pub const URL = struct {
//       hash: string = "",
//       host: string = "",
//       hostname: string = "",
//       href: string = "",
//       origin: string = "",
//       password: string = "",
//       pathname: string = "/",
//       path: string = "/",
//       port: string = "",
//       protocol: string = "",
//       search: string = "",
//       searchParams: ?QueryStringMap = null,
//       username: string = "",
//       port_was_automatically_set: bool = false,
//   };
// ============================================================================

/// WHATWG URL 近似解析结果
/// 对应 Bun URL struct - 纯视图结构，所有字段为输入文本的子串
/// Bun 使用 []const u8 借用调用者的 base 缓冲区
/// 仓颉使用 String 值拷贝（仓颉字符串为不可变值类型，零拷贝语义）
public class URL {
    /// 片段标识符 (包含前导 '#')
    public var hash: String = ""
    /// 主机名 + 端口 (例如 "localhost:3000")
    public var host: String = ""
    /// 主机名 (不含端口)
    public var hostname: String = ""
    /// 完整 URL 文本
    public var href: String = ""
    /// 源 (协议 + 主机 + 端口)
    public var origin: String = ""
    /// 密码
    public var password: String = ""
    /// 路径名
    public var pathname: String = "/"
    /// 路径 (内部使用)
    public var path: String = "/"
    /// 端口号字符串
    public var port: String = ""
    /// 协议 (例如 "http", "https", "file")
    public var protocol: String = ""
    /// 查询字符串 (包含前导 '?')
    public var search: String = ""
    /// 查询参数映射
    public var searchParams: ?URLSearchParams = None
    /// 用户名
    public var username: String = ""
    /// 端口是否自动设置
    public var portWasAutomaticallySet: Bool = false

    public init() {}

    // ============================================================================
    // 解析方法 - 对应 Bun URL.parse(base)
    // 严格翻译自: src/url/url.zig - URL.parse
    // ============================================================================

    /// 解析 URL 文本
    /// 对应 Bun: pub fn parse(base: string) URL
    /// Zig: 纯字符串扫描，无分配；Rust: 借用视图
    /// 仓颉: 值拷贝，自包含
    public static func parse(text: String): URL {
        if (text.isEmpty) {
            return URL()
        }
        let url = URL()
        url.href = text
        var offset = 0

        let bytes = text.toUtf8()
        if (bytes.size == 0) {
            return url
        }

        let firstChar = bytes[0]

        if (firstChar == UInt8('@')) {
            offset += url.parsePassword(bytes, offset)
            offset += url.parseHost(bytes, offset)
        } else if (isAlphaNum(firstChar) || firstChar == UInt8('/') ||
                   firstChar == UInt8('-') || firstChar == UInt8('_') ||
                   firstChar == UInt8(':')) {
            // 检查是否为协议相对 URL (以 // 开头)
            let isProtocolRelative = bytes.size > 1 && bytes[1] == UInt8('/')

            if (isProtocolRelative) {
                offset += 1
            } else {
                offset += url.parseProtocol(bytes, offset)
            }

            let isRelativePath = !isProtocolRelative && firstChar == UInt8('/')

            if (!isRelativePath) {
                // 如果存在协议或 @，冒号是端口还是用户名有歧义
                // 参考: https://github.com/oven-sh/bun/issues/1390
                if (offset > 0) {
                    let firstAt = indexOfChar(bytes, offset, UInt8('@'))
                    let firstColon = indexOfChar(bytes, offset, UInt8(':'))
                    let firstSlash = indexOfChar(bytes, offset, UInt8('/'))

                    if (firstAt > firstColon && firstAt < firstSlash) {
                        offset += url.parseUsername(bytes, offset)
                        offset += url.parsePassword(bytes, offset)
                    }
                }

                offset += url.parseHost(bytes, offset)
            }
        }

        url.origin = utf8Slice(bytes, 0, offset)
        var hashOffset = Int64.MAX_VALUE

        if (offset > bytes.size) {
            return url
        }

        let pathOffset = offset
        var canUpdatePath = true

        if (bytes.size > offset + 1 && bytes[offset] == UInt8('/') && offset < bytes.size) {
            url.path = utf8Slice(bytes, offset, bytes.size)
            url.pathname = url.path
        }

        // 查找 '?' 查询字符串开始位置
        let queryPos = indexOfChar(bytes, offset, UInt8('?'))
        if (queryPos < bytes.size) {
            let q = queryPos - offset
            url.path = utf8Slice(bytes, pathOffset, queryPos)
            canUpdatePath = false
            url.search = utf8Slice(bytes, queryPos, bytes.size)

            offset = queryPos
        }

        // 查找 '#' 片段标识符开始位置
        let hashPos = indexOfChar(bytes, offset, UInt8('#'))
        if (hashPos < bytes.size) {
            let h = hashPos - offset
            hashOffset = hashPos

            if (canUpdatePath) {
                url.path = utf8Slice(bytes, pathOffset, hashPos)
            }
            url.hash = utf8Slice(bytes, hashPos, bytes.size)

            if (!url.search.isEmpty) {
                url.search = utf8Slice(bytes, queryPos, hashPos)
            }

            offset = hashPos
        }

        // 提取 pathname
        if (bytes.size > pathOffset && pathOffset < bytes.size &&
            bytes[pathOffset] == UInt8('/') && offset > 0) {
            if (!url.search.isEmpty) {
                let searchEnd = (offset + url.search.toUtf8().size).min(bytes.size).min(hashOffset)
                url.pathname = utf8Slice(bytes, pathOffset, searchEnd)
            } else if (hashOffset < Int64.MAX_VALUE) {
                url.pathname = utf8Slice(bytes, pathOffset, hashOffset)
            }

            url.origin = utf8Slice(bytes, 0, pathOffset)
        }

        // 路径规范化
        if (url.path.toUtf8().size > 1) {
            let trimmed = url.path.trim("/ \t\n\r")
            if (trimmed.size > 1) {
                // 简化: 保持原路径
            } else {
                url.path = "/"
            }
        } else {
            url.path = "/"
        }

        if (url.pathname.isEmpty) {
            url.pathname = "/"
        }

        // 去除前导双斜杠
        while (url.pathname.size > 1 && url.pathname.startsWith("//")) {
            url.pathname = url.pathname.substring(1)
        }

        // 规范化 origin
        url.origin = url.origin.trim("/ ?#")

        // 如果有查询字符串，解析 searchParams
        if (!url.search.isEmpty) {
            url.searchParams = URLSearchParams.parse(url.search)
        }

        return url
    }

    // ============================================================================
    // 子解析方法 - 对应 Bun URL 内部解析函数
    // 严格翻译自: src/url/url.zig - parseProtocol/parseUsername/parsePassword/parseHost
    // ============================================================================

    /// 解析协议 - 对应 Bun: pub fn parseProtocol(url: *URL, str: string) ?u31
    private func parseProtocol(bytes: Array<UInt8>, start: Int64): Int64 {
        if (bytes.size - start < 3) {
            return 0
        }
        var i = start
        while (i < bytes.size) {
            let c = bytes[i]
            if (c == UInt8('/') || c == UInt8('?') || c == UInt8('%')) {
                return 0
            }
            if (c == UInt8(':')) {
                if (i + 3 <= bytes.size &&
                    bytes[i + 1] == UInt8('/') &&
                    bytes[i + 2] == UInt8('/')) {
                    protocol = utf8Slice(bytes, start, i)
                    return i + 3 - start
                }
            }
            i += 1
        }
        return 0
    }

    /// 解析用户名 - 对应 Bun: pub fn parseUsername(url: *URL, str: string) ?u31
    private func parseUsername(bytes: Array<UInt8>, start: Int64): Int64 {
        username = ""
        if (bytes.size - start < 1) {
            return 0
        }
        var i = start
        while (i < bytes.size) {
            let c = bytes[i]
            if (c == UInt8(':') || c == UInt8('@')) {
                username = utf8Slice(bytes, start, i)
                return i + 1 - start
            }
            if (c == UInt8('?') || c == UInt8('/')) {
                return 0
            }
            i += 1
        }
        return 0
    }

    /// 解析密码 - 对应 Bun: pub fn parsePassword(url: *URL, str: string) ?u31
    private func parsePassword(bytes: Array<UInt8>, start: Int64): Int64 {
        password = ""
        if (bytes.size - start < 1) {
            return 0
        }
        var i = start
        while (i < bytes.size) {
            let c = bytes[i]
            if (c == UInt8('@')) {
                password = utf8Slice(bytes, start, i)
                return i + 1 - start
            }
            if (c == UInt8('?') || c == UInt8('/')) {
                return 0
            }
            i += 1
        }
        return 0
    }

    /// 解析主机 - 对应 Bun: pub fn parseHost(url: *URL, str: string) ?u31
    /// 支持 IPv6 [::1] 和常规 hostname:port 格式
    private func parseHost(bytes: Array<UInt8>, start: Int64): Int64 {
        var i = start

        host = ""
        hostname = ""
        port = ""

        if (i >= bytes.size) {
            return 0
        }

        // IPv6 地址以 '[' 开头
        if (bytes[i] == UInt8('[')) {
            i += 1
            var ipv6End: Int64 = -1
            var colonPos: Int64 = -1

            while (i < bytes.size) {
                if (ipv6End < 0 && bytes[i] == UInt8(']')) {
                    ipv6End = i
                }
                if (ipv6End >= 0 && colonPos < 0 && bytes[i] == UInt8(':')) {
                    colonPos = i
                }
                if (bytes[i] == UInt8('?') || bytes[i] == UInt8('/')) {
                    break
                }
                i += 1
            }

            host = utf8Slice(bytes, start, i)
            if (ipv6End >= 0) {
                // hostname 包含 '[' 和 ']'
                hostname = utf8Slice(bytes, start, ipv6End + 1)
            }
            if (colonPos >= 0) {
                port = utf8Slice(bytes, colonPos + 1, i)
            }
        } else {
            // 常规主机名
            var colonPos: Int64 = -1

            while (i < bytes.size) {
                if (colonPos < 0 && bytes[i] == UInt8(':')) {
                    colonPos = i
                }
                if (bytes[i] == UInt8('?') || bytes[i] == UInt8('/')) {
                    break
                }
                i += 1
            }

            host = utf8Slice(bytes, start, i)
            if (colonPos >= 0) {
                hostname = utf8Slice(bytes, start, colonPos)
                port = utf8Slice(bytes, colonPos + 1, i)
            } else {
                hostname = utf8Slice(bytes, start, i)
            }
        }

        return i - start
    }

    // ============================================================================
    // 查询方法 - 对应 Bun URL 查询方法
    // ============================================================================

    /// 是否为 file:// 协议
    /// 对应 Bun: pub fn isFile(this: *const URL) bool
    public func isFile(): Bool {
        return protocol == "file"
    }

    /// 是否为 blob: URL
    /// 对应 Bun: pub fn isBlob(this: *const URL) bool
    public func isBlob(): Bool {
        return href.size == 41 && href.startsWith("blob:")
    }

    /// 是否为 localhost
    /// 对应 Bun: pub fn isLocalhost(this: *const URL) bool
    public func isLocalhost(): Bool {
        return hostname.isEmpty || hostname == "localhost" || hostname == "0.0.0.0"
    }

    /// 是否为 Unix 域套接字
    /// 对应 Bun: pub inline fn isUnix(this: *const URL) bool
    public func isUnix(): Bool {
        return protocol.startsWith("unix")
    }

    /// 是否为 HTTPS
    /// 对应 Bun: pub inline fn isHTTPS(this: *const URL) bool
    public func isHTTPS(): Bool {
        return protocol == "https"
    }

    /// 是否为 HTTP
    /// 对应 Bun: pub inline fn isHTTP(this: *const URL) bool
    public func isHTTP(): Bool {
        return protocol == "http"
    }

    /// 是否为类 HTTP 协议
    /// 对应 Bun: pub fn hasHTTPLikeProtocol(this: *const URL) bool
    public func hasHTTPLikeProtocol(): Bool {
        return protocol == "http" || protocol == "https"
    }

    /// 显示协议 (推断默认)
    /// 对应 Bun: pub fn displayProtocol(this: *const URL) string
    public func displayProtocol(): String {
        if (!protocol.isEmpty) {
            return protocol
        }
        let portVal = getPort()
        if (portVal != None) {
            if (portVal.getOrThrow() == UInt16(443)) {
                return "https"
            }
        }
        return "http"
    }

    /// 显示主机名 (推断默认)
    /// 对应 Bun: pub fn displayHostname(this: *const URL) string
    public func displayHostname(): String {
        if (!hostname.isEmpty) {
            return hostname
        }
        return "localhost"
    }

    /// 获取端口号
    /// 对应 Bun: pub fn getPort(this: *const URL) ?u16
    public func getPort(): ?UInt16 {
        if (port.isEmpty) {
            return None
        }
        return UInt16(port)
    }

    /// 获取自动端口号
    /// 对应 Bun: pub fn getPortAuto(this: *const URL) u16
    public func getPortAuto(): UInt16 {
        let p = getPort()
        if (p != None) {
            return p.getOrThrow()
        }
        return getDefaultPort()
    }

    /// 获取默认端口
    /// 对应 Bun: pub fn getDefaultPort(this: *const URL) u16
    public func getDefaultPort(): UInt16 {
        if (isHTTPS()) {
            return UInt16(443)
        }
        return UInt16(80)
    }

    /// 是否为 IP 地址
    /// 对应 Bun: pub fn isIPAddress(this: *const URL) bool
    public func isIPAddress(): Bool {
        // IPv6
        if (hostname.startsWith("[")) {
            return true
        }
        // IPv4 简化检测
        let parts = hostname.split(".")
        if (parts.size == 4) {
            var allDigits = true
            for (part in parts) {
                if (part.isEmpty) {
                    allDigits = false
                    break
                }
                for (c in part) {
                    if (!c.isAsciiDigit()) {
                        allDigits = false
                        break
                    }
                }
            }
            if (allDigits) {
                return true
            }
        }
        return false
    }

    /// 是否有有效端口
    /// 对应 Bun: pub fn hasValidPort(this: *const URL) bool
    public func hasValidPort(): Bool {
        let p = getPort()
        if (p == None) { return false }
        return p.getOrThrow() > UInt16(0)
    }

    /// 是否为空 URL
    /// 对应 Bun: pub fn isEmpty(this: *const URL) bool
    public func isEmpty(): Bool {
        return href.isEmpty
    }

    /// 是否为绝对 URL
    /// 对应 Bun: pub fn isAbsolute(this: *const URL) bool
    public func isAbsolute(): Bool {
        return !hostname.isEmpty && !pathname.isEmpty
    }

    /// URL 验证
    /// Bun 的 URL 解析器较为宽松 (不产生验证错误)
    /// 此方法进行基本 WHATWG 有效性检查
    public func isValid(): Bool {
        if (href.isEmpty) {
            return false
        }
        // 必须有协议或者主机
        if (protocol.isEmpty && host.isEmpty) {
            return false
        }
        // 协议必须为合法字符
        for (c in protocol) {
            if (!c.isAsciiAlpha() && !c.isAsciiDigit() && c != '+' && c != '-' && c != '.') {
                return false
            }
        }
        return true
    }

    /// S3 路径 (去除协议和查询/片段)
    /// 对应 Bun: pub fn s3Path(this: *const URL) string
    public func s3Path(): String {
        var h = href
        if (!protocol.isEmpty && h.size > protocol.size + 2) {
            h = h.substring(protocol.size + 2)
        }
        let searchSize = search.toUtf8().size
        let hashSize = hash.toUtf8().size
        return h.substring(0, h.size - searchSize - hashSize)
    }

    /// 主机 + 路径 (去除尾部斜杠、协议、查询参数和片段)
    /// 对应 Bun: pub fn hostWithPath(this: *const URL) []const u8
    public func hostWithPath(): String {
        if (!host.isEmpty) {
            var p = path
            if (p.endsWith("/") && p.size > 1) {
                p = p.substring(0, p.size - 1)
            }
            return host + p
        }
        return ""
    }

    /// 生成不带认证信息的 href
    /// 对应 Bun: pub fn hrefWithoutAuth
    public func hrefWithoutAuth(): String {
        let proto = displayProtocol()
        let trimmedPath = pathname.trim("/")
        return "${proto}://${displayHostname()}/${trimmedPath}/"
    }

    /// 字符串表示
    public func toString(): String {
        return href
    }
}

// ============================================================================
// URLSearchParams - 查询字符串解析与操作
// 严格翻译自: src/url/url.zig - QueryStringMap, Scanner
//   pub const QueryStringMap = struct {
//       allocator: std.mem.Allocator,
//       slice: string,
//       buffer: []u8,
//       list: Param.List,
//       name_count: ?usize = null,
//   };
// ============================================================================

/// URL 查询参数条目
/// 对应 Bun: pub const Param = struct { name, name_hash, value }
public class QueryParam {
    public var name: String
    public var value: String
    public var nameHash: UInt64

    public init(name: String, value: String) {
        this.name = name
        this.value = value
        this.nameHash = WyHash.hash(name)
    }
}

/// URL 查询字符串参数映射
/// 对应 Bun QueryStringMap - 保持插入顺序，使用哈希加速查找
public class URLSearchParams {
    /// 参数列表 - 对应 Bun list: Param.List
    private var params: ArrayList<QueryParam>

    public init() {
        params = ArrayList<QueryParam>()
    }

    /// 从查询字符串解析
    /// 对应 Bun: pub fn init(allocator, query_string) OOM!?QueryStringMap
    /// 以及 Scanner 逐个扫描 name=value 对
    public static func parse(queryString: String): URLSearchParams {
        let result = URLSearchParams()
        var input = queryString

        // 去除前导 '?'
        if (input.startsWith("?")) {
            input = input.substring(1)
        }

        if (input.isEmpty) {
            return result
        }

        // 按 '&' 分割参数对
        var i = 0
        var start = 0
        while (i <= input.size) {
            if (i == input.size || input[i] == '&') {
                if (i > start) {
                    let pair = input.substring(start, i)
                    result.parsePair(pair)
                }
                start = i + 1
            }
            i += 1
        }

        return result
    }

    /// 解析单个 name=value 对
    /// 对应 Bun Scanner.next() 中的 '=' 分隔逻辑
    private func parsePair(pair: String): Unit {
        let eqIdx = pair.indexOf('=')
        if (eqIdx < 0) {
            // 只有键没有值: key&
            let name = PercentEncoding.decodeComponent(pair)
            if (!name.isEmpty) {
                params.append(QueryParam(name, ""))
            }
        } else {
            let name = PercentEncoding.decodeComponent(pair.substring(0, eqIdx))
            let value = PercentEncoding.decodeComponent(pair.substring(eqIdx + 1))
            if (!name.isEmpty) {
                params.append(QueryParam(name, value))
            }
        }
    }

    /// 获取参数值 (第一个匹配)
    /// 对应 Bun: pub fn get(this: *const QueryStringMap, input: string) ?string
    public func get(name: String): ?String {
        let h = WyHash.hash(name)
        for (p in params) {
            if (p.nameHash == h && p.name == name) {
                return p.value
            }
        }
        return None
    }

    /// 获取所有匹配值
    /// 对应 Bun: pub fn getAll(this: *const QueryStringMap, input: string, target: []string) usize
    public func getAll(name: String): ArrayList<String> {
        let result = ArrayList<String>()
        let h = WyHash.hash(name)
        for (p in params) {
            if (p.nameHash == h && p.name == name) {
                result.append(p.value)
            }
        }
        return result
    }

    /// 是否包含参数
    /// 对应 Bun: pub fn has(this: *const QueryStringMap, input: string) bool
    public func has(name: String): Bool {
        let h = WyHash.hash(name)
        for (p in params) {
            if (p.nameHash == h && p.name == name) {
                return true
            }
        }
        return false
    }

    /// 设置参数值 (替换所有同名参数为单个值)
    /// WHATWG URL Standard: set 删除所有同名，然后添加一个
    public func set(name: String, value: String): Unit {
        let h = WyHash.hash(name)
        var found = false
        var i = 0
        while (i < params.size) {
            if (params[i].nameHash == h && params[i].name == name) {
                if (!found) {
                    params[i].value = value
                    found = true
                    i += 1
                } else {
                    params.removeAt(i)
                }
            } else {
                i += 1
            }
        }
        if (!found) {
            params.append(QueryParam(name, value))
        }
    }

    /// 追加参数 (允许重复)
    /// WHATWG URL Standard: append 总是添加
    public func append(name: String, value: String): Unit {
        params.append(QueryParam(name, value))
    }

    /// 删除参数
    /// WHATWG URL Standard: delete 删除所有同名
    public func delete(name: String): Unit {
        let h = WyHash.hash(name)
        var i = 0
        while (i < params.size) {
            if (params[i].nameHash == h && params[i].name == name) {
                params.removeAt(i)
            } else {
                i += 1
            }
        }
    }

    /// 参数数量
    public func size(): Int64 {
        return params.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return params.size == 0
    }

    /// 排序参数 (按名称字母序)
    /// WHATWG URL Standard: sort
    public func sort(): Unit {
        // 简单冒泡排序 (参数列表通常很小)
        for (i in 0..params.size) {
            for (j in 0..(params.size - 1 - i)) {
                if (params[j].name > params[j + 1].name) {
                    let tmp = params[j]
                    params[j] = params[j + 1]
                    params[j + 1] = tmp
                }
            }
        }
    }

    /// 获取所有条目
    /// WHATWG URL Standard: entries()
    public func entries(): ArrayList<(String, String)> {
        let result = ArrayList<(String, String)>()
        for (p in params) {
            result.append((p.name, p.value))
        }
        return result
    }

    /// 获取所有键
    /// WHATWG URL Standard: keys()
    public func keys(): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) {
            result.append(p.name)
        }
        return result
    }

    /// 获取所有值
    /// WHATWG URL Standard: values()
    public func values(): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) {
            result.append(p.value)
        }
        return result
    }

    /// 序列化为查询字符串
    /// WHATWG URL Standard: toString()
    public func toString(): String {
        if (params.size == 0) {
            return ""
        }
        var parts = ArrayList<String>()
        for (p in params) {
            let encName = PercentEncoding.encodeComponent(p.name)
            let encValue = PercentEncoding.encodeComponent(p.value)
            if (p.value.isEmpty) {
                parts.append(encName)
            } else {
                parts.append("${encName}=${encValue}")
            }
        }
        return parts.iterator().reduce({ a, b => "${a}&${b}" })
    }

    /// 清空所有参数
    public func clear(): Unit {
        params.clear()
    }
}

// ============================================================================
// PercentEncoding - URL 百分比编码/解码
// 严格翻译自: src/url/url.zig - PercentEncoding
//   pub const PercentEncoding = struct {
//       pub fn decode(comptime Writer, writer, input) !u32 { ... }
//       pub fn decodeAlloc(allocator, input) ![]u8 { ... }
//   };
// ============================================================================

/// URL 百分比编码/解码工具
/// 对应 Bun PercentEncoding - WHATWG URL percent-encode set
public class PercentEncoding {

    /// 解码百分比编码字符串
    /// 对应 Bun: pub fn decodeAlloc(allocator, input) ![]u8
    /// 例如: "hello%20world" -> "hello world"
    public static func decodeComponent(input: String): String {
        if (input.isEmpty) {
            return ""
        }
        let bytes = input.toUtf8()
        if (bytes.size == 0) {
            return input
        }
        var result = StringBuilder()
        var i = 0
        while (i < bytes.size) {
            if (bytes[i] == UInt8('%')) {
                if (i + 2 < bytes.size) {
                    let hi = hexValue(bytes[i + 1])
                    let lo = hexValue(bytes[i + 2])
                    if (hi >= 0 && lo >= 0) {
                        result.append(String.fromUtf8(Array<UInt8>([UInt8(hi * 16 + lo)])))
                        i += 3
                        continue
                    }
                }
                result.append("%")
                i += 1
            } else if (bytes[i] == UInt8('+')) {
                // application/x-www-form-urlencoded: '+' -> ' '
                result.append(" ")
                i += 1
            } else {
                result.append(String.fromUtf8(Array<UInt8>([bytes[i]])))
                i += 1
            }
        }
        return result.toString()
    }

    /// 编码字符串为百分比编码
    /// 对应 Bun 编码逻辑 (WHATWG URL Standard percent-encode sets)
    /// 保留字符: A-Z a-z 0-9 - _ . ~
    public static func encodeComponent(input: String): String {
        if (input.isEmpty) {
            return ""
        }
        let bytes = input.toUtf8()
        if (bytes.size == 0) {
            return input
        }
        var result = StringBuilder()
        for (b in bytes) {
            if (isUnreserved(b)) {
                result.append(String.fromUtf8(Array<UInt8>([b])))
            } else {
                result.append("%")
                result.append(hexDigit((b >> 4) & 0x0F))
                result.append(hexDigit(b & 0x0F))
            }
        }
        return result.toString()
    }

    /// 解码到缓冲区
    /// 对应 Bun: pub fn decode(Writer, writer, input) !u32
    /// 返回写入的字节数
    public static func decodeInto(output: Array<UInt8>, input: Array<UInt8>): Int64 {
        var written = 0
        var i = 0
        while (i < input.size) {
            if (input[i] == UInt8('%')) {
                if (i + 2 < input.size && isAsciiHexDigit(input[i + 1]) && isAsciiHexDigit(input[i + 2])) {
                    if (written < output.size) {
                        output[written] = UInt8(toAsciiHexValue(input[i + 1]) * 16 + toAsciiHexValue(input[i + 2]))
                    }
                    written += 1
                    i += 3
                    continue
                }
                if (written < output.size) {
                    output[written] = input[i]
                }
                written += 1
                i += 1
            } else {
                if (written < output.size) {
                    output[written] = input[i]
                }
                written += 1
                i += 1
            }
        }
        return written
    }

    /// 是否为非保留字符 (不需编码)
    /// WHATWG URL Standard: unreserved = ALPHA / DIGIT / "-" / "." / "_" / "~"
    private static func isUnreserved(b: UInt8): Bool {
        return (b >= UInt8('a') && b <= UInt8('z')) ||
               (b >= UInt8('A') && b <= UInt8('Z')) ||
               (b >= UInt8('0') && b <= UInt8('9')) ||
               b == UInt8('-') || b == UInt8('.') ||
               b == UInt8('_') || b == UInt8('~')
    }

    /// 十六进制数字值
    /// 对应 Bun: strings.toASCIIHexValue
    private static func toAsciiHexValue(b: UInt8): Int64 {
        if (b >= UInt8('0') && b <= UInt8('9')) {
            return Int64(b) - Int64(UInt8('0'))
        }
        if (b >= UInt8('a') && b <= UInt8('f')) {
            return Int64(b) - Int64(UInt8('a')) + 10
        }
        if (b >= UInt8('A') && b <= UInt8('F')) {
            return Int64(b) - Int64(UInt8('A')) + 10
        }
        return 0
    }

    /// 是否为 ASCII 十六进制数字
    private static func isAsciiHexDigit(b: UInt8): Bool {
        return (b >= UInt8('0') && b <= UInt8('9')) ||
               (b >= UInt8('a') && b <= UInt8('f')) ||
               (b >= UInt8('A') && b <= UInt8('F'))
    }
}

// ============================================================================
// URL Resolution - 相对 URL 解析
// 对应 Bun: URL.join / URL.getHrefJoin / WHATWG URL resolver
// ============================================================================

/// URL 解析工具
/// 对应 Bun URL resolution: resolve relative URLs against base
public class URLResolver {

    /// 解析相对 URL
    /// 对应 Bun: URL__getHrefJoin(base, relative)
    /// 简化的 WHATWG URL 解析器: 基于 base URL 和相对引用构建绝对 URL
    public static func resolve(base: String, relative: String): String {
        // 相对 URL 为空，返回 base
        if (relative.isEmpty) {
            return base
        }

        // 如果 relative 是绝对 URL (包含协议)
        let relBytes = relative.toUtf8()
        if (relBytes.size > 0) {
            let hasProtocol = hasProtocolPrefix(relative)
            if (hasProtocol) {
                return relative
            }

            // 协议相对 URL: //host/path
            if (relBytes.size > 1 && relBytes[0] == UInt8('/') && relBytes[1] == UInt8('/')) {
                let baseUrl = URL.parse(base)
                if (baseUrl.protocol.isEmpty) {
                    return relative
                }
                return "${baseUrl.protocol}:${relative}"
            }
        }

        let baseUrl = URL.parse(base)
        if (baseUrl.protocol.isEmpty) {
            return relative
        }

        // 绝对路径: /path
        if (relBytes.size > 0 && relBytes[0] == UInt8('/')) {
            return "${baseUrl.origin}${relative}"
        }

        // 查询字符串: ?query
        if (relBytes.size > 0 && relBytes[0] == UInt8('?')) {
            return "${baseUrl.origin}${baseUrl.pathname}${relative}"
        }

        // 片段标识符: #fragment
        if (relBytes.size > 0 && relBytes[0] == UInt8('#')) {
            let searchPart = if (baseUrl.search.isEmpty) { "" } else { baseUrl.search }
            return "${baseUrl.origin}${baseUrl.pathname}${searchPart}${relative}"
        }

        // 相对路径: path/to/resource
        let basePath = baseUrl.pathname
        let lastSlash = basePath.lastIndexOf('/')
        let dir = if (lastSlash >= 0) { basePath.substring(0, lastSlash + 1) } else { "/" }
        let raw = "${dir}${relative}"
        let normalized = PathNormalizer.normalize(raw)
        return "${baseUrl.origin}${normalized}"
    }

    /// 检查是否包含协议前缀
    private static func hasProtocolPrefix(s: String): Bool {
        let bytes = s.toUtf8()
        for (i in 0..bytes.size) {
            let c = bytes[i]
            if (c == UInt8(':')) {
                return i > 0
            }
            if (c == UInt8('/') || c == UInt8('?') || c == UInt8('#')) {
                return false
            }
            // 协议字符: ALPHA DIGIT + - .
            if (!((c >= UInt8('a') && c <= UInt8('z')) ||
                  (c >= UInt8('A') && c <= UInt8('Z')) ||
                  (c >= UInt8('0') && c <= UInt8('9')) ||
                  c == UInt8('+') || c == UInt8('-') || c == UInt8('.'))) {
                return false
            }
        }
        return false
    }
}

// ============================================================================
// PathNormalizer - 路径规范化
// 对应 Bun: resolve_path.normalizeStringBuf
// 处理 . (当前目录) 和 .. (上级目录) 以及重复斜杠
// ============================================================================

/// URL 路径规范化器
/// 对应 Bun resolve_path - 处理 . 和 .. 引用
public class PathNormalizer {

    /// 规范化路径
    /// 对应 Bun: resolve_path.normalizeStringBuf
    /// 例如: "/a/b/../c/./d" -> "/a/c/d"
    public static func normalize(path: String): String {
        if (path.isEmpty) {
            return "/"
        }

        let bytes = path.toUtf8()
        var segments = ArrayList<String>()
        var current = StringBuilder()
        var isAbsolute = bytes.size > 0 && bytes[0] == UInt8('/')

        // 按 '/' 分割
        for (b in bytes) {
            if (b == UInt8('/')) {
                let seg = current.toString()
                if (!seg.isEmpty) {
                    segments.append(seg)
                }
                current = StringBuilder()
            } else {
                current.append(String.fromUtf8(Array<UInt8>([b])))
            }
        }
        let lastSeg = current.toString()
        if (!lastSeg.isEmpty) {
            segments.append(lastSeg)
        }

        // 处理 . 和 .. 段
        var result = ArrayList<String>()
        for (seg in segments) {
            if (seg == ".") {
                // 跳过当前目录引用
                continue
            } else if (seg == "..") {
                // 返回上级目录
                if (result.size > 0) {
                    result.removeAt(result.size - 1)
                }
            } else {
                result.append(seg)
            }
        }

        // 重组路径
        var out = StringBuilder()
        if (isAbsolute) {
            out.append("/")
        }
        for (i in 0..result.size) {
            out.append(result[i])
            if (i < result.size - 1) {
                out.append("/")
            }
        }
        let s = out.toString()
        if (s.isEmpty) {
            return "/"
        }
        return s
    }
}

// ============================================================================
// URLPattern (简化版) - URL 模式匹配
// 翻译自 WHATWG URLPattern Standard (Bun 未直接实现，作为扩展)
// 提供简化的路径模式匹配: :param, *, 正则表达式
// ============================================================================

/// URL 模式匹配规则
public class URLPattern {
    /// 协议模式
    public var protocol: String = "*"
    /// 主机名模式
    public var hostname: String = "*"
    /// 端口模式
    public var port: String = "*"
    /// 路径名模式 (支持 :param 和 * 通配符)
    public var pathname: String = "/*"
    /// 查询字符串模式
    public var search: String = "*"
    /// 片段标识符模式
    public var hash: String = "*"
    /// 基础 URL
    public var baseURL: ?String = None

    public init() {}

    /// 从模式字符串创建 URLPattern
    public init(pattern: String) {
        // 简化: 将整个模式视为 pathname 模式
        pathname = pattern
    }

    /// 从完整模式定义创建
    public init(protocol: String, hostname: String, port: String,
                pathname: String, search: String, hash: String) {
        this.protocol = protocol
        this.hostname = hostname
        this.port = port
        this.pathname = pathname
        this.search = search
        this.hash = hash
    }

    /// 测试 URL 是否匹配模式
    /// WHATWG URLPattern Standard: test(input)
    public func test(url: URL): Bool {
        // 协议匹配
        if (!matchPattern(protocol, url.protocol)) {
            return false
        }
        // 主机名匹配
        if (!matchPattern(hostname, url.hostname)) {
            return false
        }
        // 路径名匹配
        if (!matchPathname(pathname, url.pathname)) {
            return false
        }
        return true
    }

    /// 测试 URL 字符串是否匹配
    public func test(urlString: String): Bool {
        let url = URL.parse(urlString)
        return test(url)
    }

    /// 执行匹配并提取参数
    /// WHATWG URLPattern Standard: exec(input)
    public func exec(url: URL): ?HashMap<String, String> {
        let result = HashMap<String, String>()

        // 从路径中提取命名参数
        let patternParts = splitPattern(pathname)
        let pathParts = splitPath(url.pathname)

        let len = if (patternParts.size < pathParts.size) { patternParts.size } else { pathParts.size }
        for (i in 0..len) {
            let pat = patternParts[i]
            let val = pathParts[i]
            if (pat.startsWith(":")) {
                let name = pat.substring(1)
                result.put(name, val)
            }
        }

        return Some(result)
    }

    /// 模式匹配 - 支持 * 通配符
    private func matchPattern(pattern: String, value: String): Bool {
        if (pattern == "*" || pattern == "") {
            return true
        }
        if (pattern == value) {
            return true
        }
        // 简单通配符匹配
        if (pattern.contains("*")) {
            return globMatch(pattern, value)
        }
        return pattern == value
    }

    /// 路径名模式匹配
    private func matchPathname(pattern: String, value: String): Bool {
        if (pattern == "/*") {
            return true
        }
        if (pattern == value) {
            return true
        }
        // 检查命名参数匹配
        let patternParts = splitPattern(pattern)
        let pathParts = splitPath(value)

        if (patternParts.size != pathParts.size) {
            return false
        }

        for (i in 0..patternParts.size) {
            let pat = patternParts[i]
            let val = pathParts[i]
            if (pat.startsWith(":")) {
                // 命名参数匹配任意非空值
                if (val.isEmpty) {
                    return false
                }
            } else if (pat == "*") {
                // 通配符匹配
                continue
            } else if (pat != val) {
                return false
            }
        }
        return true
    }

    /// 简单 glob 匹配
    private func globMatch(pattern: String, text: String): Bool {
        // 简化实现: 只支持单个 *
        if (!pattern.contains("*")) {
            return pattern == text
        }
        let parts = pattern.split("*")
        if (parts.size == 2) {
            return text.startsWith(parts[0]) && text.endsWith(parts[1])
        }
        return true
    }

    /// 按路径分隔符分割模式
    private func splitPattern(pattern: String): ArrayList<String> {
        let result = ArrayList<String>()
        var current = StringBuilder()
        for (c in pattern) {
            if (c == '/') {
                let s = current.toString()
                if (!s.isEmpty) {
                    result.append(s)
                }
                current = StringBuilder()
            } else {
                current.append(c.toString())
            }
        }
        let last = current.toString()
        if (!last.isEmpty) {
            result.append(last)
        }
        return result
    }

    /// 按路径分隔符分割路径
    private func splitPath(path: String): ArrayList<String> {
        let result = ArrayList<String>()
        var current = StringBuilder()
        for (c in path) {
            if (c == '/') {
                let s = current.toString()
                if (!s.isEmpty) {
                    result.append(s)
                }
                current = StringBuilder()
            } else {
                current.append(c.toString())
            }
        }
        let last = current.toString()
        if (!last.isEmpty) {
            result.append(last)
        }
        return result
    }
}

// ============================================================================
// Punycode 编码/解码 (RFC 3492)
// 翻译自: src/node-fallbacks/punycode.js (Node.js punycode module)
// Bun 通过 node-fallbacks/punycode.js 提供完整的 RFC 3492 Punycode 实现
// 仓颉版本: 完整实现 Punycode 编解码 + IDNA 域名处理
// ============================================================================

/// Punycode 编码/解码工具
/// 完整翻译自 Bun: src/node-fallbacks/punycode.js
/// 实现 RFC 3492 Bootstring 编码算法
public class Punycode {

    // RFC 3492 Bootstring 参数
    private static let BASE: Int64 = 36
    private static let TMIN: Int64 = 1
    private static let TMAX: Int64 = 26
    private static let SKEW: Int64 = 38
    private static let DAMP: Int64 = 700
    private static let INITIAL_BIAS: Int64 = 72
    private static let INITIAL_N: Int64 = 128  // 0x80
    private static let DELIMITER: String = "-"  // '\x2D'
    private static let MAX_INT: Int64 = 2147483647  // 2^31 - 1
    private static let BASE_MINUS_TMIN: Int64 = 35  // BASE - TMIN

    /// 将基本码点转换为数字 (digit)
    /// '0'-'9' -> 26-35, 'A'-'Z' -> 0-25, 'a'-'z' -> 0-25
    /// 对应 Bun punycode.js: basicToDigit
    private static func basicToDigit(codePoint: Int64): Int64 {
        if (codePoint >= 0x30 && codePoint < 0x3A) {
            return 26 + (codePoint - 0x30)
        }
        if (codePoint >= 0x41 && codePoint < 0x5B) {
            return codePoint - 0x41
        }
        if (codePoint >= 0x61 && codePoint < 0x7B) {
            return codePoint - 0x61
        }
        return BASE
    }

    /// 将数字转换为基本码点 (digit)
    /// 0-25 -> 'a'-'z' (或 'A'-'Z' 当 flag != 0), 26-35 -> '0'-'9'
    /// 对应 Bun punycode.js: digitToBasic
    private static func digitToBasic(digit: Int64, flag: Bool): Char {
        // 0..25 map to ASCII a..z or A..Z
        // 26..35 map to ASCII 0..9
        let code = digit + 22
        if (digit < 26) {
            // 75 = 0x4B; digit < 26 时加上 75 (但 flag 非零时减 32)
            if (flag) {
                return Char(code + 75 - 32)
            }
            return Char(code + 75)
        }
        return Char(code)
    }

    /// RFC 3492 Section 3.4 偏差自适应函数
    /// 对应 Bun punycode.js: adapt
    private static func adapt(delta: Int64, numPoints: Int64, firstTime: Bool): Int64 {
        var delta = delta
        delta = if (firstTime) { delta / DAMP } else { delta >> 1 }
        delta += delta / numPoints
        var k: Int64 = 0
        while (delta > (BASE_MINUS_TMIN * TMAX) >> 1) {
            delta = delta / BASE_MINUS_TMIN
            k += BASE
        }
        return k + (BASE_MINUS_TMIN + 1) * delta / (delta + SKEW)
    }

    /// 将字符串转换为 Unicode 码点数组 (UCS-2 解码)
    /// 对应 Bun punycode.js: ucs2decode
    /// JavaScript 使用 UCS-2 内部表示，需要处理代理对
    public static func ucs2Decode(input: String): Array<Int64> {
        let output = ArrayList<Int64>()
        var counter = 0
        while (counter < input.size) {
            let value = Int64(input[counter].value)
            counter += 1
            if (value >= 0xD800 && value <= 0xDBFF && counter < input.size) {
                // 高代理项，检查下一个字符是否为低代理项
                let extra = Int64(input[counter].value)
                if ((extra & 0xFC00) == 0xDC00) {
                    // 有效的代理对
                    counter += 1
                    output.append(((value & 0x3FF) << 10) + (extra & 0x3FF) + 0x10000)
                } else {
                    // 未匹配的高代理项
                    output.append(value)
                    counter -= 1
                }
            } else {
                output.append(value)
            }
        }
        return output.toArray()
    }

    /// 将 Unicode 码点数组转换为字符串 (UCS-2 编码)
    /// 对应 Bun punycode.js: ucs2encode = codePoints => String.fromCodePoint(...codePoints)
    public static func ucs2Encode(codePoints: Array<Int64>): String {
        var sb = StringBuilder()
        for (cp in codePoints) {
            sb.append(charFromCodePoint(cp))
        }
        return sb.toString()
    }

    /// 从码点创建字符 (支持补充平面)
    private static func charFromCodePoint(cp: Int64): String {
        if (cp <= 0xFFFF) {
            return String(Char(cp))
        }
        // 补充平面: 需要代理对
        let hi = ((cp - 0x10000) >> 10) + 0xD800
        let lo = ((cp - 0x10000) & 0x3FF) + 0xDC00
        return String(Char(hi)) + String(Char(lo))
    }

    /// Punycode 解码: 将 ASCII Punycode 字符串转换为 Unicode 字符串
    /// 对应 Bun punycode.js: decode
    /// RFC 3492 Section 6.2: Decoding procedure
    public static func decode(input: String): String {
        let output = ArrayList<Int64>()
        let inputLength = input.size
        var i: Int64 = 0
        var n: Int64 = INITIAL_N
        var bias: Int64 = INITIAL_BIAS

        // 处理基本码点: 找到最后一个分隔符的位置
        let basicIdx = input.lastIndexOf(DELIMITER)
        let basic = if (basicIdx >= 0) { basicIdx } else { 0 }

        // 复制基本码点到输出
        var j = 0
        while (j < basic) {
            let cp = Int64(input[j].value)
            if (cp >= 0x80) {
                // 非基本码点 - 非法输入
                return input
            }
            output.append(cp)
            j += 1
        }

        // 主解码循环
        var index = if (basic > 0) { basic + 1 } else { 0 }
        while (index < inputLength) {
            let oldi = i
            var w: Int64 = 1
            var k = BASE
            while (true) {
                if (index >= inputLength) {
                    return input  // 无效输入，返回原字符串
                }
                let digit = basicToDigit(Int64(input[index].value))
                index += 1
                if (digit >= BASE) {
                    return input  // 无效输入
                }
                if (digit > (MAX_INT - i) / w) {
                    return input  // 溢出，返回原字符串
                }
                i += digit * w
                let t = if (k <= bias) { TMIN } else if (k >= bias + TMAX) { TMAX } else { k - bias }
                if (digit < t) {
                    break
                }
                let baseMinusT = BASE - t
                if (w > MAX_INT / baseMinusT) {
                    return input  // 溢出
                }
                w *= baseMinusT
                k += BASE
            }

            let out = output.size + 1
            bias = adapt(i - oldi, out, oldi == 0)

            if (i / out > MAX_INT - n) {
                return input  // 溢出
            }
            n += i / out
            i = i % out

            // 在位置 i 处插入码点 n
            output.insert(Int64(i), n)
            i += 1
        }

        // 将码点数组转换为字符串
        var sb = StringBuilder()
        for (cp in output) {
            sb.append(charFromCodePoint(cp))
        }
        return sb.toString()
    }

    /// Punycode 编码: 将 Unicode 字符串转换为 ASCII Punycode 字符串
    /// 对应 Bun punycode.js: encode
    /// RFC 3492 Section 6.3: Encoding procedure
    public static func encode(input: String): String {
        // 将输入转换为码点数组
        let codePoints = ucs2Decode(input)
        let inputLength = codePoints.size

        let output = ArrayList<Char>()
        var n: Int64 = INITIAL_N
        var delta: Int64 = 0
        var bias: Int64 = INITIAL_BIAS

        // 处理基本码点 (ASCII < 0x80)
        for (cp in codePoints) {
            if (cp < 0x80) {
                output.append(Char(cp))
            }
        }

        let basicLength = output.size
        var handledCPCount = basicLength

        // 如果有基本码点，在末尾添加分隔符
        if (basicLength > 0) {
            output.append(Char('-'))  // DELIMITER
        }

        // 主编码循环
        while (handledCPCount < inputLength) {
            // 找到下一个最小的未处理码点
            var m: Int64 = MAX_INT
            for (cp in codePoints) {
                if (cp >= n && cp < m) {
                    m = cp
                }
            }

            // 增加 delta 以推进解码器状态
            let handledCPCountPlusOne = handledCPCount + 1
            if (m - n > (MAX_INT - delta) / handledCPCountPlusOne) {
                return input  // 溢出
            }
            delta += (m - n) * handledCPCountPlusOne
            n = m

            for (cp in codePoints) {
                if (cp < n) {
                    delta += 1
                    if (delta > MAX_INT) {
                        return input  // 溢出
                    }
                }
                if (cp == n) {
                    // 将 delta 表示为广义变长整数
                    var q = delta
                    var k = BASE
                    while (true) {
                        let t = if (k <= bias) { TMIN } else if (k >= bias + TMAX) { TMAX } else { k - bias }
                        if (q < t) {
                            break
                        }
                        let qMinusT = q - t
                        let baseMinusT = BASE - t
                        output.append(digitToBasic(t + (qMinusT % baseMinusT), false))
                        q = qMinusT / baseMinusT
                        k += BASE
                    }
                    output.append(digitToBasic(q, false))
                    bias = adapt(delta, handledCPCountPlusOne, handledCPCount == basicLength)
                    delta = 0
                    handledCPCount += 1
                }
            }
            delta += 1
            n += 1
        }

        var sb = StringBuilder()
        for (c in output) {
            sb.append(c.toString())
        }
        return sb.toString()
    }
}

// ============================================================================
// IDNA 域名处理
// Bun 使用 WTF::URL 的 IDNA 支持 (通过 C++ FFI)
// 也提供 Node.js punycode 模块的域名转换 (toASCII/toUnicode)
// 仓颉版本: 完整实现 Punycode + IDNA 域名编码/解码
// ============================================================================

/// IDNA 域名处理工具
/// 对应 Bun 通过 WHATWG URL C++ 层的 IDNA 处理
/// 以及 Node.js punycode 模块的 toASCII/toUnicode
/// 基于 RFC 3490 (IDNA) + RFC 3492 (Punycode Bootstring)
public class IDNA {

    /// RFC 3490 域名分隔符: U+002E (.), U+3002 (。), U+FF0E (．), U+FF61 (｡)
    private static func isSeparator(c: Char): Bool {
        let v = c.value
        return v == 0x002E || v == 0x3002 || v == 0xFF0E || v == 0xFF61
    }

    /// 将域名的分隔符统一替换为 ASCII 点 '.'
    /// 对应 Bun punycode.js: domain.replace(regexSeparators, "\x2E")
    private static func normalizeSeparators(domain: String): String {
        var sb = StringBuilder()
        for (c in domain) {
            if (isSeparator(c)) {
                sb.append(".")
            } else {
                sb.append(c.toString())
            }
        }
        return sb.toString()
    }

    /// 将域名按点分割为标签列表
    private static func splitLabels(domain: String): ArrayList<String> {
        let normalized = normalizeSeparators(domain)
        let result = ArrayList<String>()
        var current = StringBuilder()
        for (c in normalized) {
            if (c == '.') {
                result.append(current.toString())
                current = StringBuilder()
            } else {
                current.append(c.toString())
            }
        }
        let last = current.toString()
        result.append(last)
        return result
    }

    /// 检查字符串是否包含非 ASCII 字符
    private static func hasNonASCII(s: String): Bool {
        for (c in s) {
            if (c.value > 0x7F) {
                return true
            }
        }
        return false
    }

    /// 将 Unicode 域名编码为 ASCII (Punycode)
    /// 对应 Bun URL 解析器的自动 Punycode 编码
    /// 以及 Node.js punycode.toASCII
    /// 例如: "例子.中国" -> "xn--fsq.xn--fiqs8s"
    ///       "münchen.de" -> "xn--mnchen-3ya.de"
    public static func toASCII(domain: String): String {
        if (domain.isEmpty) {
            return domain
        }

        // 处理邮件地址: 只编码 @ 后面的域名部分
        let atIdx = domain.lastIndexOf('@')
        var prefix = ""
        var domainPart = domain
        if (atIdx >= 0) {
            prefix = domain.substring(0, atIdx + 1)
            domainPart = domain.substring(atIdx + 1)
        }

        // 分割标签并逐个编码
        let labels = splitLabels(domainPart)
        let encoded = ArrayList<String>()
        for (label in labels) {
            if (label.isEmpty) {
                encoded.append("")
            } else if (hasNonASCII(label)) {
                encoded.append("xn--" + Punycode.encode(label))
            } else {
                encoded.append(label.toLowerCase())
            }
        }

        var sb = StringBuilder()
        sb.append(prefix)
        for (i in 0..encoded.size) {
            if (i > 0) {
                sb.append(".")
            }
            sb.append(encoded[i])
        }
        return sb.toString()
    }

    /// 将 Punycode 域名解码为 Unicode
    /// 对应 Bun URL 解析器的自动 Punycode 解码
    /// 以及 Node.js punycode.toUnicode
    /// 例如: "xn--fsq.xn--fiqs8s" -> "例子.中国"
    ///       "xn--mnchen-3ya.de" -> "münchen.de"
    public static func toUnicode(domain: String): String {
        if (domain.isEmpty) {
            return domain
        }

        // 处理邮件地址: 只解码 @ 后面的域名部分
        let atIdx = domain.lastIndexOf('@')
        var prefix = ""
        var domainPart = domain
        if (atIdx >= 0) {
            prefix = domain.substring(0, atIdx + 1)
            domainPart = domain.substring(atIdx + 1)
        }

        // 分割标签并逐个解码
        let labels = splitLabels(domainPart)
        let decoded = ArrayList<String>()
        for (label in labels) {
            if (label.startsWith("xn--") || label.startsWith("XN--")) {
                // 去除 "xn--" 前缀，解码剩余部分
                let punycodePart = label.substring(4).toLowerCase()
                decoded.append(Punycode.decode(punycodePart))
            } else {
                decoded.append(label)
            }
        }

        var sb = StringBuilder()
        sb.append(prefix)
        for (i in 0..decoded.size) {
            if (i > 0) {
                sb.append(".")
            }
            sb.append(decoded[i])
        }
        return sb.toString()
    }

    /// 验证域名的有效性
    /// 包含标签长度、域名总长度的检查
    public static func isValidDomain(domain: String): Bool {
        if (domain.isEmpty) {
            return false
        }
        // 域名总长度不超过 253 字符
        if (domain.size > 253) {
            return false
        }
        let labels = splitLabels(domain)
        for (label in labels) {
            if (label.isEmpty || label.size > 63) {
                return false
            }
        }
        return true
    }

    /// 检查域名是否包含 Punycode 编码的标签 (以 "xn--" 开头)
    public static func hasPunycode(domain: String): Bool {
        let labels = splitLabels(domain)
        for (label in labels) {
            if (label.startsWith("xn--") || label.startsWith("XN--")) {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从字节数组切片构造 UTF-8 字符串
private func utf8Slice(bytes: Array<UInt8>, start: Int64, end: Int64): String {
    let e = if (end > bytes.size) { bytes.size } else { end }
    if (start >= e || start < 0) {
        return ""
    }
    return String.fromUtf8(Array<UInt8>(bytes[start..e]))
}

/// 在字节数组中查找字符位置
/// 对应 Bun: strings.indexOfChar
private func indexOfChar(bytes: Array<UInt8>, start: Int64, ch: UInt8): Int64 {
    var i = start
    while (i < bytes.size) {
        if (bytes[i] == ch) {
            return i
        }
        i += 1
    }
    return bytes.size  // 未找到返回 size (大于任何有效位置)
}

/// 是否为字母或数字
private func isAlphaNum(b: UInt8): Bool {
    return (b >= UInt8('a') && b <= UInt8('z')) ||
           (b >= UInt8('A') && b <= UInt8('Z')) ||
           (b >= UInt8('0') && b <= UInt8('9'))
}

/// 十六进制字符值
private func hexValue(b: UInt8): Int64 {
    if (b >= UInt8('0') && b <= UInt8('9')) {
        return Int64(b) - Int64(UInt8('0'))
    }
    if (b >= UInt8('a') && b <= UInt8('f')) {
        return Int64(b) - Int64(UInt8('a')) + 10
    }
    if (b >= UInt8('A') && b <= UInt8('F')) {
        return Int64(b) - Int64(UInt8('A')) + 10
    }
    return -1
}

/// 整数转十六进制字符
private func hexDigit(v: UInt8): String {
    let nibble = Int64(v) & 0x0F
    if (nibble < 10) {
        return "${nibble}"
    }
    return String(Char(nibble - 10 + Int64(Char('a').value)))
}

/// StringBuilder - 字符串构建器
/// 仓颉标准库 StringBuilder 的简化包装
private class StringBuilder {
    private var parts: ArrayList<String>

    init() {
        parts = ArrayList<String>()
    }

    func append(s: String): Unit {
        parts.append(s)
    }

    func toString(): String {
        // 连接所有部分
        var totalSize = 0
        for (p in parts) {
            totalSize += p.size
        }
        if (totalSize == 0) {
            return ""
        }
        var arr = Array<Char>(totalSize, item: '\0')
        var pos = 0
        for (p in parts) {
            for (c in p) {
                arr[pos] = c
                pos += 1
            }
        }
        return String(arr)
    }
}
