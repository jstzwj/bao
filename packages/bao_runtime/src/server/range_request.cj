// RangeRequest - HTTP Range 请求头解析
// 严格翻译自: Bun src/runtime/server/RangeRequest.zig
// 对应: 解析 HTTP Range: bytes=... 请求头
package bao_runtime

// ============================================================================
// RangeRequest - HTTP Range 请求解析
// 严格翻译自: src/runtime/server/RangeRequest.zig
// Bun: 解析 Range: bytes=start-end / bytes=start- / bytes=-suffix
// ============================================================================

/// Range 请求解析结果
/// 对应 Bun: pub const Result = union(enum) { none, satisfiable, unsatisfiable }
public enum RangeResult {
    | None
    | Satisfiable(RangeSatisfiable)
    | Unsatisfiable
}

/// 满足条件的 Range 范围
/// 对应 Bun: satisfiable: struct { start: u64, end: u64 }
/// end 是包含的 (inclusive)
public class RangeSatisfiable {
    public var start: Int64
    public var end: Int64

    public init(start: Int64, end: Int64) {
        this.start = start
        this.end = end
    }
}

/// 解析前的原始 Range 数据
/// 对应 Bun: pub const Raw = union(enum) { none, suffix, bounded }
public enum RangeRaw {
    | None
    | Suffix(Int64)                    // bytes=-N
    | Bounded(RangeBounded)            // bytes=N-[M]
}

/// 有界的 Range 范围
/// 对应 Bun: bounded: struct { start: u64, end: ?u64 }
public class RangeBounded {
    public var start: Int64
    public var end: ?Int64

    public init(start: Int64, end: ?Int64) {
        this.start = start
        this.end = end
    }
}

/// RangeRequest - Range 请求解析器
/// 严格翻译自: src/runtime/server/RangeRequest.zig
/// Bun: 只支持单范围 bytes=start-end / bytes=start- / bytes=-suffix
/// 多范围和非 bytes 单元回退到 .none (返回完整 body)
public class RangeRequest {

    /// 将 Raw Range 解析为 Result，给定总大小
    /// 对应 Bun: pub fn resolve(this: Raw, total: u64) Result
    public static func resolve(raw: RangeRaw, total: Int64): RangeResult {
        match (raw) {
            case RangeRaw.None => RangeResult.None
            case RangeRaw.Suffix(let n) => {
                if (n == 0) {
                    return RangeResult.Unsatisfiable
                }
                // RFC 9110 §14.1.3: 正的 suffix-length 是可满足的
                // 对于空表示体，返回完整 (0-byte) body
                if (total == 0) {
                    return RangeResult.None
                }
                let start = total - n
                if (start < 0) {
                    return RangeResult.Satisfiable(RangeSatisfiable(0, total - 1))
                }
                return RangeResult.Satisfiable(RangeSatisfiable(start, total - 1))
            }
            case RangeRaw.Bounded(let b) => {
                if (b.start >= total) {
                    return RangeResult.Unsatisfiable
                }
                var end: Int64 = match (b.end) {
                    case Some(e) => e
                    case None => total - 1
                }
                if (end < b.start) {
                    return RangeResult.None
                }
                if (end >= total) {
                    end = total - 1
                }
                return RangeResult.Satisfiable(RangeSatisfiable(b.start, end))
            }
        }
    }

    /// 解析 Range 头值为 Raw 格式
    /// 对应 Bun: pub fn parseRaw(header: []const u8) Raw
    /// 匹配 WebKit 的 parseRange (HTTPParsers.cpp): 大小写不敏感 "bytes"
    public static func parseRaw(header: String): RangeRaw {
        var rest = header

        // 检查 "bytes" 前缀，至少需要 5 个字符
        if (rest.size < 5 || !eqlCaseInsensitiveASCII(rest.substring(0, 5), "bytes")) {
            return RangeRaw.None
        }
        rest = rest.substring(5)
        rest = trim(rest, " \t")

        if (rest.size == 0 || rest[0] != '=') {
            return RangeRaw.None
        }
        rest = rest.substring(1)

        // 多范围 - 不支持，返回完整 body
        if (rest.indexOf(",") >= 0) {
            return RangeRaw.None
        }

        let dashIdx = rest.indexOf("-")
        if (dashIdx < 0) {
            return RangeRaw.None
        }

        let startS = trim(rest.substring(0, dashIdx), " \t")
        let endS = trim(rest.substring(dashIdx + 1), " \t")

        // bytes=-N (后缀范围)
        if (startS.size == 0) {
            let n = parseUnsigned(endS)
            match (n) {
                case Some(v) => return RangeRaw.Suffix(v)
                case None => return RangeRaw.None
            }
        }

        // bytes=N-[M]
        let start = parseUnsigned(startS)
        match (start) {
            case Some(s) => {
                let end: ?Int64 = if (endS.size == 0) {
                    None
                } else {
                    parseUnsigned(endS)
                }
                // 如果 end 解析失败且不为空，返回 None
                if (endS.size > 0) {
                    match (end) {
                        case None => return RangeRaw.None
                        case _ => ()
                    }
                }
                return RangeRaw.Bounded(RangeBounded(s, end))
            }
            case None => return RangeRaw.None
        }
    }

    /// 解析 Range 头并立即解析为 Result
    /// 对应 Bun: pub fn parse(header: []const u8, total: u64) Result
    public static func parse(header: String, total: Int64): RangeResult {
        return resolve(parseRaw(header), total)
    }

    /// 从请求头解析原始 Range
    /// 对应 Bun: pub fn rawFromRequest(req: uws.AnyRequest) Raw
    public static func rawFromRequest(headers: HashMap<String, String>): RangeRaw {
        match (headers.get("range")) {
            case Some(h) => parseRaw(h)
            case None => RangeRaw.None
        }
    }

    /// 从请求头解析 Range 为 Result
    /// 对应 Bun: pub fn fromRequest(req: uws.AnyRequest, total: u64) Result
    public static func fromRequest(headers: HashMap<String, String>, total: Int64): RangeResult {
        match (headers.get("range")) {
            case Some(h) => parse(h, total)
            case None => RangeResult.None
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 大小写不敏感 ASCII 比较
    /// 对应 Bun: bun.strings.eqlCaseInsensitiveASCII
    private static func eqlCaseInsensitiveASCII(a: String, b: String): Bool {
        if (a.size != b.size) {
            return false
        }
        for (i in 0..a.size) {
            let ca = a[Int64(i)]
            let cb = b[Int64(i)]
            if (toLowerASCII(ca) != toLowerASCII(cb)) {
                return false
            }
        }
        return true
    }

    /// ASCII 字符转小写
    private static func toLowerASCII(c: Char): Char {
        let v = c.value
        if (v >= 65 && v <= 90) { // A-Z
            return Char(v + 32)
        }
        return c
    }

    /// 去除两端空白
    private static func trim(s: String, chars: String): String {
        var start = 0
        var end = s.size
        while (start < end && chars.contains(s[start].toString())) {
            start++
        }
        while (end > start && chars.contains(s[end - 1].toString())) {
            end--
        }
        return s.substring(start, end)
    }

    /// 解析无符号整数
    /// 对应 Bun: std.fmt.parseUnsigned(u64, end_s, 10)
    private static func parseUnsigned(s: String): ?Int64 {
        if (s.size == 0) {
            return None
        }
        var result: Int64 = 0
        for (c in s) {
            let v = c.value
            if (v < 48 || v > 57) { // 非数字
                return None
            }
            let digit = Int64(v - 48)
            result = result * 10 + digit
        }
        return Some(result)
    }
}
