// bao_core - WTF (WebKit) 工具函数封装
// 严格翻译自: src/bun_core/wtf.rs
//   unsafe extern "C" { fn WTF__parseES5Date(bytes: *const u8, length: usize) -> f64; }
//   pub fn parse_es5_date_raw(s: &[u8]) -> f64
//   pub fn parse_es5_date(buf: &[u8]) -> Result<f64, InvalidDate>
// Bun: thin FFI wrappers over linked WTF (WebKit) utilities
//   tier-0 调用者直接声明 C 符号, 无需 bun_jsc crate 依赖
// 仓颉: 提供等价的日期解析接口
package bao_core

// ============================================================================
// InvalidDate - 无效日期错误
// 严格翻译自: src/bun_core/wtf.rs InvalidDate
//   #[derive(Debug, Clone, Copy, PartialEq, Eq)]
//   pub struct InvalidDate;
// ============================================================================

/// 无效日期错误 - 对应 Bun InvalidDate
public class InvalidDate <: Exception {
    public init() {
        super("InvalidDate")
    }
}

// ============================================================================
// WTF 日期解析 - 严格翻译自: src/bun_core/wtf.rs
//   WTF__parseES5Date 指向 vendor/WebKit Source/WTF/wtf/DateMath.cpp
//   返回 NaN 表示解析失败
// ============================================================================

/// WTF 日期解析工具 - 对应 Bun wtf 模块
/// Bun:
///   pub fn parse_es5_date_raw(s: &[u8]) -> f64
///   pub fn parse_es5_date(buf: &[u8]) -> Result<f64, InvalidDate>
public class WtfDateParser {
    private static func minInt(a: Int64, b: Int64): Int64 {
        if (a < b) { return a }
        return b
    }

    /// 直接调用 WTF::parseES5Date - 对应 Bun parse_es5_date_raw
    /// 返回 NaN 表示 WTF 解析器拒绝输入
    /// 输入被视为 Latin-1
    public static func parseES5DateRaw(s: Array<UInt8>): Float64 {
        // 仓颉没有 WTF FFI 绑定, 使用简化的 ES5 日期解析
        let str = bytesToString(s)
        return parseES5DateImpl(str)
    }

    /// 从字符串解析 ES5 日期 - 对应 Bun parse_es5_date_raw
    public static func parseES5DateRaw(s: String): Float64 {
        return parseES5DateImpl(s)
    }

    /// ES5 日期解析 (带错误检查) - 对应 Bun parse_es5_date
    /// "2000-01-01T00:00:00.000Z" → Ok(946684800000.0)
    /// 空输入或非有限结果 → Err(InvalidDate)
    public static func parseES5Date(s: Array<UInt8>): ?Float64 {
        if (s.size == 0) {
            return None
        }
        let ms = parseES5DateRaw(s)
        if (ms.isNaN() || ms.isInf()) {
            return None
        }
        return Some(ms)
    }

    /// ES5 日期解析 (字符串输入)
    public static func parseES5Date(s: String): ?Float64 {
        if (s.size == 0) {
            return None
        }
        let ms = parseES5DateRaw(s)
        if (ms.isNaN() || ms.isInf()) {
            return None
        }
        return Some(ms)
    }

    // ========================================================================
    // 内部实现
    // ========================================================================

    /// 简化的 ES5 日期解析实现
    /// 对应 WTF::parseES5Date 的核心功能
    /// 支持格式: ISO 8601 (YYYY-MM-DDTHH:MM:SS.sssZ) 和 HTTP-date (RFC1123)
    private static func parseES5DateImpl(s: String): Float64 {
        let httpDate = parseHTTPDate(s)
        if (httpDate.isSome()) {
            return httpDate.getOrThrow()
        }

        if (s.size < 20) {
            return Float64.NaN
        }
        let year = parseFixedDigits(s, 0, 4)
        let month = parseFixedDigits(s, 5, 2)
        let day = parseFixedDigits(s, 8, 2)
        let hour = parseFixedDigits(s, 11, 2)
        let minute = parseFixedDigits(s, 14, 2)
        let second = parseFixedDigits(s, 17, 2)
        if (!isValidDateTime(year, month, day, hour, minute, second)) {
            return Float64.NaN
        }

        var millis: Int32 = 0
        if (s.size > 19 && s[19] == UInt8(46)) {
            var factor: Int32 = 100
            var idx: Int64 = 20
            while (idx < s.size && factor > 0) {
                let ch = s[idx]
                if (ch < UInt8(48) || ch > UInt8(57)) { break }
                millis += Int32(ch - UInt8(48)) * factor
                factor = factor / 10
                idx += 1
            }
        }
        return dateToTimestamp(Int32(year), Int32(month), Int32(day), Int32(hour), Int32(minute), Int32(second), millis)
    }

    private static func parseHTTPDate(s: String): ?Float64 {
        // RFC1123: "Mon, 06 Jan 2025 22:40:57 GMT"
        let comma = s.indexOf(",")
        if (!comma.isSome()) { return None }
        let start = comma.getOrThrow() + 1
        let rest = trimAsciiWhitespace(s[start..])
        if (rest.size < 20) { return None }

        let day = parseFixedDigits(rest, 0, 2)
        if (rest.size < 16) { return None }
        let month = parseHTTPMonth(rest[3..6])
        let year = parseFixedDigits(rest, 7, 4)
        let hour = parseFixedDigits(rest, 12, 2)
        let minute = parseFixedDigits(rest, 15, 2)
        let second = parseFixedDigits(rest, 18, 2)
        if (!isValidDateTime(year, month, day, hour, minute, second)) {
            return None
        }
        return Some(dateToTimestamp(Int32(year), Int32(month), Int32(day), Int32(hour), Int32(minute), Int32(second), 0))
    }

    private static func parseHTTPMonth(month: String): Int64 {
        match (month) {
            case "Jan" => return 1
            case "Feb" => return 2
            case "Mar" => return 3
            case "Apr" => return 4
            case "May" => return 5
            case "Jun" => return 6
            case "Jul" => return 7
            case "Aug" => return 8
            case "Sep" => return 9
            case "Oct" => return 10
            case "Nov" => return 11
            case "Dec" => return 12
            case _ => return -1
        }
    }

    private static func parseFixedDigits(s: String, start: Int64, len: Int64): Int64 {
        if (start < 0 || len <= 0 || start + len > s.size) { return -1 }
        var value: Int64 = 0
        var i: Int64 = 0
        while (i < len) {
            let ch = s[start + i]
            if (ch < UInt8(48) || ch > UInt8(57)) { return -1 }
            value = value * 10 + Int64(ch - UInt8(48))
            i += 1
        }
        return value
    }

    private static func isValidDateTime(year: Int64, month: Int64, day: Int64, hour: Int64, minute: Int64, second: Int64): Bool {
        if (year < 1970 || month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
            return false
        }
        return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 60
    }

    private static func daysInMonth(year: Int64, month: Int64): Int64 {
        let days = [31,28,31,30,31,30,31,31,30,31,30,31]
        if (month == 2 && isLeapYear(Int32(year))) { return 29 }
        return Int64(days[month - 1])
    }

    private static func trimAsciiWhitespace(s: String): String {
        var start: Int64 = 0
        var end = s.size
        while (start < end && isAsciiWhitespace(s[start])) { start += 1 }
        while (end > start && isAsciiWhitespace(s[end - 1])) { end -= 1 }
        return s[start..end]
    }

    private static func isAsciiWhitespace(c: UInt8): Bool {
        return c == UInt8(32) || c == UInt8(9) || c == UInt8(10) || c == UInt8(13)
    }

    private static func isLeapYear(year: Int32): Bool {
        let y = Int64(year)
        return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
    }

    /// 简化的日期到时间戳转换
    private static func dateToTimestamp(year: Int32, month: Int32, day: Int32, hour: Int32, minute: Int32, second: Int32, ms: Int32): Float64 {
        // 简化: 使用固定基准
        var y = Int64(year)
        var m = Int64(month)
        var d = Int64(day)

        // 算法: 将日期转为 Unix 时间戳 (毫秒)
        if (m <= 2) {
            y -= 1
            m += 12
        }
        let a = y / 100
        let b = 2 - a + a / 4
        let julianDay = (36525 * (y + 4716)) / 100 + (306 * (m + 1)) / 10 + d + b - 1524
        let unixDays = julianDay - 2440588  // Julian day of Unix epoch
        var result = unixDays * 86400000
        result += Int64(hour) * 3600000
        result += Int64(minute) * 60000
        result += Int64(second) * 1000
        result += Int64(ms)
        return Float64(result)
    }

    /// 字节数组转字符串
    private static func bytesToString(bytes: Array<UInt8>): String {
        var sb = StringBuilder()
        for (b in bytes) {
            sb.append(Rune(Int32(b)))
        }
        return sb.toString()
    }
}
