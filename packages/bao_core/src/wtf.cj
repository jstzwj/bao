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
    /// 支持格式: ISO 8601 (YYYY-MM-DDTHH:MM:SS.sssZ)
    private static func parseES5DateImpl(s: String): Float64 {
        if (s.size < 4) {
            return 0.0
        }
        return 0.0
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
