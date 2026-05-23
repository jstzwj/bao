// RangeRequest - HTTP Range 请求头解析
// 严格翻译自: Bun src/runtime/server/RangeRequest.zig
// 对应: 解析 HTTP Range: bytes=... 请求头
package bao_runtime.server

import bao_collections.*

// ============================================================================
// RangeRequest - HTTP Range 请求解析
// 严格翻译自: src/runtime/server/RangeRequest.zig
// Bun: 解析 Range: bytes=start-end / bytes=start- / bytes=-suffix
// ============================================================================

/// Range 请求解析结果
/// 对应 Bun: pub const Result = union(enum) { none, satisfiable, unsatisfiable }
public enum RangeResult {
    | Absent
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
    | Absent
    | Suffix(Int64)                    // bytes=-N
    | Bounded(RangeBounded)            // bytes=N-[M]

    public operator func ==(right: RangeRaw): Bool {
        match (this) {
            case RangeRaw.Absent => match (right) { case RangeRaw.Absent => true case _ => false }
            case RangeRaw.Suffix(s1) => match (right) { case RangeRaw.Suffix(s2) => s1 == s2 case _ => false }
            case RangeRaw.Bounded(b1) => match (right) { case RangeRaw.Bounded(b2) => b1.start == b2.start case _ => false }
        }
    }

    public operator func !=(right: RangeRaw): Bool { !(this == right) }
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
    /// 对应 Bun: pub fn resolve(`this`: Raw, total: u64) Result
    public static func resolve(raw: RangeRaw, total: Int64): RangeResult {
        match (raw) {
            case RangeRaw.Absent => RangeResult.Absent
            case RangeRaw.Suffix(n) =>
                if (n == 0) {
                    return RangeResult.Unsatisfiable
                }
                if (total == Int64(0)) {
                    return RangeResult.Absent
                }
                let start = total - n
                if (start < 0) {
                    return RangeResult.Satisfiable(RangeSatisfiable(0, total - 1))
                }
                return RangeResult.Satisfiable(RangeSatisfiable(start, total - 1))
            case RangeRaw.Bounded(b) =>
                if (b.start >= total) {
                    return RangeResult.Unsatisfiable
                }
                var end: Int64 = match (b.end) {
                    case Some(e) => e
                    case None => total - 1
                }
                if (end < b.start) {
                    return RangeResult.Absent
                }
                if (end >= total) {
                    end = total - 1
                }
                return RangeResult.Satisfiable(RangeSatisfiable(b.start, end))
        }
    }

    /// 解析 Range 头值为 Raw 格式
    /// 对应 Bun: pub fn parseRaw(header: []const u8) Raw
    public static func parseRaw(header: String): RangeRaw {
        var rest = header

        // 检查 "bytes" 前缀，至少需要 5 个字符
        if (rest.size < 5 || !eqlCaseInsensitiveASCII(rest.subString(0, 5), "bytes")) {
            return RangeRaw.Absent
        }
        rest = rest.subString(5)
        rest = trimWhiteSpace(rest)

        if (rest.size == 0) {
            return RangeRaw.Absent
        }
        let runes = rest.toRuneArray()
        if (runes[0] != '=') {
            return RangeRaw.Absent
        }
        rest = rest.subString(1)

        // 多范围 - 不支持，返回完整 body
        if (rest.contains(",")) {
            return RangeRaw.Absent
        }

        let dashIdxOpt = rest.indexOf("-")
        if (dashIdxOpt.isNone()) {
            return RangeRaw.Absent
        }
        let dashIdx = dashIdxOpt.getOrThrow()

        let startS = trimWhiteSpace(rest.subString(0, dashIdx))
        let endS = trimWhiteSpace(rest.subString(dashIdx + 1))

        // bytes=-N (后缀范围)
        if (startS.size == 0) {
            let n = parseUnsigned(endS)
            match (n) {
                case Some(v) => return RangeRaw.Suffix(v)
                case None => return RangeRaw.Absent
            }
        }

        // bytes=N-[M]
        let start = parseUnsigned(startS)
        match (start) {
            case Some(s) =>
                let endParsed: ?Int64 = if (endS.size == 0) {
                    None
                } else {
                    parseUnsigned(endS)
                }
                // 如果 end 解析失败且不为空，返回 Absent
                if (endS.size > 0) {
                    match (endParsed) {
                        case None => return RangeRaw.Absent
                        case _ => ()
                    }
                }
                return RangeRaw.Bounded(RangeBounded(s, endParsed))
            case None => return RangeRaw.Absent
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
            case None => RangeRaw.Absent
        }
    }

    /// 从请求头解析 Range 为 Result
    /// 对应 Bun: pub fn fromRequest(req: uws.AnyRequest, total: u64) Result
    public static func fromRequest(headers: HashMap<String, String>, total: Int64): RangeResult {
        match (headers.get("range")) {
            case Some(h) => parse(h, total)
            case None => RangeResult.Absent
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 大小写不敏感 ASCII 比较
    private static func eqlCaseInsensitiveASCII(a: String, b: String): Bool {
        if (a.size != b.size) {
            return false
        }
        let aRunes = a.toRuneArray()
        let bRunes = b.toRuneArray()
        for (i in 0..a.size) {
            let ca = aRunes[Int64(i)]
            let cb = bRunes[Int64(i)]
            if (toLowerASCIIRune(ca) != toLowerASCIIRune(cb)) {
                return false
            }
        }
        return true
    }

    /// ASCII 字符转小写
    private static func toLowerASCIIRune(c: Rune): Rune {
        let v = Int64(c)
        if (v >= 65 && v <= 90) {
            return Rune(v + 32)
        }
        return c
    }

    /// 去除两端空白字符
    private static func trimWhiteSpace(s: String): String {
        var start = 0
        var end = s.size
        let runes = s.toRuneArray()
        while (start < end) {
            let r = runes[Int64(start)]
            if (r != ' ' && r != '\t') {
                break
            }
            start++
        }
        while (end > start) {
            let r = runes[Int64(end - 1)]
            if (r != ' ' && r != '\t') {
                break
            }
            end--
        }
        if (start == 0 && end == s.size) {
            return s
        }
        return s.subString(start, end - start)
    }

    /// 解析无符号整数
    private static func parseUnsigned(s: String): ?Int64 {
        if (s.size == 0) {
            return None
        }
        var result: Int64 = 0
        for (c in s) {
            let v = Int64(c)
            if (v < 48 || v > 57) {
                return None
            }
            let digit = Int64(v - 48)
            result = result * 10 + digit
        }
        return Some(result)
    }
}
