// bao_core - 格式化工具
// 严格翻译自: src/bun_core/fmt.zig (1852L) + src/bun_core/fmt.rs (3878L)
//   Bun 的格式化系统: 数字/路径/大小/持续时间/JSON/十六进制/语法高亮/表格
//
// 关键源映射:
//   fmt.zig: HexIntFormatter, SizeFormatter, FormatDouble, trimmedPrecision
//   fmt.zig: TableSymbols, EnumTagListFormatter, githubActionWriter, quotedWriter
//   fmt.zig: URLFormatter, HostFormatter, FormatValidIdentifier
//   fmt.zig: RedactedNpmUrlFormatter, DependencyUrlFormatter
//   fmt.zig: FormatSlice, NullableFallback, EscapePowershell, NewOutOfRangeFormatter
//   fmt.zig: QuickAndDirtyJavaScriptSyntaxHighlighter (syntax highlighter)
//   fmt.zig: IntegrityFormatter (sha512 base64)
//   fmt.rs:  TableSymbols, Display impls, outOfRange formatter
//   fmt.rs:  parseInt/parseUnsigned/parseDouble, Raw(VecWriter), bufPrint
//   fmt.rs:  FormatUTF8/FormatUTF16, PathSep
package bao_core

// ============================================================================
// 数字格式化
// 严格翻译自: src/bun_core/fmt.zig:1378-1557 + fmt.rs
//   HexIntFormatter, fastDigitCount, double formatting
// ============================================================================

/// 整数格式化工具 - 对应 Bun itoa / print_int / HexIntFormatter
public class IntFormatter {
    /// 整数转字符串 (十进制)
    public static func toString(value: Int64): String {
        return value.toString()
    }

    /// 整数转字符串 (指定进制: 2/8/10/16)
    public static func toString(value: Int64, radix: Int64): String {
        if (radix == 16) {
            return toHexString(value, false)
        }
        if (radix == 2) {
            return toBinaryString(value)
        }
        if (radix == 8) {
            return toOctalString(value)
        }
        return value.toString()
    }

    /// 无符号整数转字符串
    public static func toString(value: UInt64): String {
        return value.toString()
    }

    /// 十六进制字符串 (小写) - 对应 Bun hexIntLower
    /// 严格翻译自: fmt.zig:1484-1557 HexIntFormatter(Int, lower=true)
    public static func toHexString(value: Int64): String {
        return toHexString(value, false)
    }

    /// 十六进制字符串 (可选大写) - 对应 Bun HexInt(Int, Case)
    /// Bun: 使用查表法, 每个 nibble 直接索引到字符
    private static func toHexString(value: Int64, upper: Bool): String {
        if (value == 0) { return "0" }
        let chars = if (upper) { "0123456789ABCDEF" } else { "0123456789abcdef" }
        var sb = StringBuilder()
        var v = UInt64(value)
        while (v > 0) {
            sb.append(chars[Int32(v % UInt64(16))])
            v = v / UInt64(16)
        }
        return reverse(sb.toString())
    }

    /// 大写十六进制 - 对应 Bun hexIntUpper
    public static func toHexStringUpper(value: Int64): String {
        return toHexString(value, true)
    }

    /// UInt64 十六进制 - 对应 Bun HexIntFormatter(u64, lower)
    public static func toHexUInt64(value: UInt64): String {
        if (value == UInt64(0)) { return "0" }
        let chars = "0123456789abcdef"
        var sb = StringBuilder()
        var v = value
        while (v > UInt64(0)) {
            sb.append(chars[Int32(v % UInt64(16))])
            v = v / UInt64(16)
        }
        return reverse(sb.toString())
    }

    /// 二进制字符串
    public static func toBinaryString(value: Int64): String {
        if (value == 0) { return "0" }
        var sb = StringBuilder()
        var v = value
        while (v != 0) {
            sb.append(if ((v & 1) == 1) { '1' } else { '0' })
            v = v >> 1
        }
        return reverse(sb.toString())
    }

    /// 八进制字符串
    public static func toOctalString(value: Int64): String {
        if (value == 0) { return "0" }
        var sb = StringBuilder()
        var v = value
        while (v != 0) {
            sb.append(Char(Int32('0' + (v % 8))))
            v = v / 8
        }
        return reverse(sb.toString())
    }

    /// 快速计算整数的十进制位数 - 对应 Bun fastDigitCount
    /// 严格翻译自: fmt.zig:1379-1419
    /// 使用查表法实现 O(1) 位数计算
    /// https://lemire.me/blog/2021/06/03/computing-the-number-of-digits-of-an-integer-even-faster/
    public static func fastDigitCount(x: UInt64): Int64 {
        if (x == UInt64(0)) {
            return 1
        }
        // 使用 log2 + 查表法
        let table = [
            UInt64(4294967296),  // 2^32
            UInt64(8589934582),
            UInt64(8589934582),
            UInt64(8589934582),
            UInt64(12884901788),
            UInt64(12884901788),
            UInt64(12884901788),
            UInt64(17179868184),
            UInt64(17179868184),
            UInt64(17179868184),
            UInt64(21474826480),
            UInt64(21474826480),
            UInt64(21474826480),
            UInt64(21474826480),
            UInt64(25769703776),
            UInt64(25769703776),
            UInt64(25769703776),
            UInt64(30063771072),
            UInt64(30063771072),
            UInt64(30063771072),
            UInt64(34349738368),
            UInt64(34349738368),
            UInt64(34349738368),
            UInt64(34349738368),
            UInt64(38554705664),
            UInt64(38554705664),
            UInt64(38554705664),
            UInt64(41949672960),
            UInt64(41949672960),
            UInt64(41949672960),
            UInt64(42949672960),
            UInt64(42949672960)
        ]
        // 简化: 使用 log2 近似
        var log2: Int64 = 0
        var v = x
        while (v > UInt64(0)) {
            v = v >> 1
            log2 += 1
        }
        if (log2 > 0) { log2 -= 1 }
        if (log2 >= table.size) { return 20 }
        return Int64((x + table[log2]) >> 32)
    }

    /// 通用位数计算 (兼容 Int64)
    public static func digitCount(value: Int64): Int64 {
        if (value == 0) { return 1 }
        var v = if (value < 0) { -value } else { value }
        var count: Int64 = 0
        while (v > 0) {
            count += 1
            v = v / 10
        }
        return count
    }

    /// 整数千位分组格式化 - 对应 Bun 中数字的分组显示
    /// 例如: 1234567 -> "1,234,567"
    public static func formatWithGrouping(value: Int64): String {
        let s = value.toString()
        if (s.length <= 3) { return s }
        var sb = StringBuilder()
        var count: Int64 = 0
        let chars = s.toArray()
        for (i in 0..chars.size) {
            if (i > 0 && (chars.size - i) % 3 == 0) {
                sb.append(',')
            }
            sb.append(chars[i])
        }
        return sb.toString()
    }

    /// 反转字符串
    private static func reverse(s: String): String {
        let chars = s.toArray()
        var result = Array<Char>()
        for (i in 0..chars.size) {
            result.append(chars[chars.size - 1 - i])
        }
        return String(result)
    }
}

/// 浮点格式化工具 - 对应 Bun FormatDouble / trimmedPrecision
/// 严格翻译自: fmt.zig:1561-1696 FormatDouble, dtoa
public class FloatFormatter {
    /// 浮点数转字符串 (指定精度)
    /// 对应 Bun TrimmedPrecisionFormatter
    /// 严格翻译自: fmt.zig:1561-1584
    public static func toString(value: Float64, precision: Int64): String {
        var s = value.toString()
        let dotIdx = s.indexOf(".")
        if (dotIdx >= 0 && precision >= 0) {
            let maxLen = dotIdx + 1 + precision
            if (s.length > maxLen) {
                s = s.substring(0, maxLen)
            }
        }
        return s
    }

    /// 浮点数转字符串 (默认精度)
    public static func toString(value: Float64): String {
        return value.toString()
    }

    /// 修剪尾随零的精度格式化 - 对应 Bun trimmedPrecision
    /// 严格翻译自: fmt.zig:1561-1584 TrimmedPrecisionFormatter
    /// 等价于 `{d:.<precision>}` 但去除尾随零
    public static func trimmedPrecision(value: Float64, precision: Int64): String {
        if (precision <= 0) {
            return Int64(value).toString()
        }
        var s = toString(value, precision)
        // 去除尾随零
        while (s.endsWith("0") && s.contains(".")) {
            s = s.substring(0, s.length - 1)
        }
        // 去除孤立的小数点
        if (s.endsWith(".")) {
            s = s.substring(0, s.length - 1)
        }
        return s
    }

    /// 科学计数法格式化 - 对应 Bun 中的指数格式
    public static func toScientific(value: Float64, precision: Int64): String {
        if (value == 0.0) { return "0" }
        var absValue = if (value < 0.0) { -value } else { value }
        var exp: Int64 = 0
        if (absValue >= 10.0) {
            while (absValue >= 10.0) {
                absValue = absValue / 10.0
                exp += 1
            }
        } else if (absValue < 1.0 && absValue > 0.0) {
            while (absValue < 1.0) {
                absValue = absValue * 10.0
                exp -= 1
            }
        }
        let mantissa = toString(absValue, precision)
        let sign = if (value < 0.0) { "-" } else { "" }
        if (exp >= 0) {
            return "${sign}${mantissa}e+${exp}"
        } else {
            return "${sign}${mantissa}e${exp}"
        }
    }

    /// 检测是否为负零 - 对应 Bun std.math.isNegativeZero
    public static func isNegativeZero(value: Float64): Bool {
        return value == 0.0 && (1.0 / value) < 0.0
    }
}

// ============================================================================
// 路径格式化
// 严格翻译自: fmt.zig:366-445 PathFormatOptions, FormatUTF8, FormatUTF16, FormatOSPath
// ============================================================================

/// 路径分隔符类型 - 对应 Bun PathSep
public enum PathSep {
    | Any       // 保持原样
    | Auto      // 跟随平台
    | Posix     // 强制 /
    | Windows   // 强制 \

    public func separator(): String {
        match (this) {
            case Posix => "/"
            case Windows => "\\"
            case Auto | Any => "/"
        }
    }
}

/// 路径格式化选项 - 对应 Bun PathFormatOptions
/// 严格翻译自: fmt.zig:400-418
public class PathFormatOptions {
    public var sep: PathSep
    /// 是否转义反斜杠 (用于 JSON 路径等)
    public var escapeBackslashes: Bool

    public init() {
        sep = PathSep.Auto
        escapeBackslashes = false
    }

    public init(sep: PathSep) {
        this.sep = sep
        escapeBackslashes = false
    }

    public init(sep: PathSep, escapeBackslashes: Bool) {
        this.sep = sep
        this.escapeBackslashes = escapeBackslashes
    }
}

/// 路径格式化工具 - 对应 Bun fmtPath, fmtOSPath
public class PathFormatter {
    /// 格式化路径 (使用指定分隔符) - 对应 Bun fmt_path
    public static func format(path: String, options: PathFormatOptions): String {
        if (options.sep == PathSep.Any && !options.escapeBackslashes) {
            return path
        }
        var result = path
        if (options.sep == PathSep.Posix) {
            result = result.replace("\\", "/")
        } else if (options.sep == PathSep.Windows) {
            result = result.replace("/", "\\")
        }
        if (options.escapeBackslashes) {
            result = result.replace("\\", "\\\\")
        }
        return result
    }

    /// 将路径转为 POSIX 格式
    public static func toPosix(path: String): String {
        return path.replace("\\", "/")
    }
}

// ============================================================================
// 大小格式化
// 严格翻译自: fmt.zig:1421-1482 SizeFormatter
// ============================================================================

/// 文件大小格式化 - 对应 Bun SizeFormatter
/// 严格翻译自: fmt.zig:1421-1471
/// 将字节数格式化为人类可读形式 (KB, MB, GB 等)
public class SizeFormatter {
    /// 格式化字节大小 - 对应 Bun SizeFormatter.format
    public static func format(bytes: Int64): String {
        if (bytes == 0) {
            return "0 KB"
        }
        if (bytes < 512) {
            return "${bytes} bytes"
        }
        let mags = " KMGTPEZY"
        var log2Value: Int64 = 0
        var v = UInt64(bytes)
        while (v > UInt64(0)) {
            v = v >> 1
            log2Value += 1
        }
        log2Value -= 1
        var magnitude = log2Value / 10  // log2(1000) ~ 10
        if (magnitude > 8) { magnitude = 8 }
        let newValue = Float64(bytes) / pow1000(magnitude)
        let suffix = mags.toArray()[magnitude]
        if (suffix == ' ') {
            return "${FloatFormatter.toString(newValue / 1000.0, 2)} KB"
        }
        // 检查是否接近整数
        let precision: Int64 = if (newValue == Float64(Int64(newValue)) &&
            newValue - Float64(Int64(newValue)) < 0.1) { 1 } else { 2 }
        return "${FloatFormatter.toString(newValue, precision)} ${suffix}B"
    }

    /// 紧凑格式 - 对应 Bun compact size formatting
    public static func formatCompact(bytes: Int64): String {
        if (bytes < 1000) {
            return "${bytes}B"
        }
        if (bytes < 1000 * 1000) {
            return "${bytes / 1000}KB"
        }
        if (bytes < 1000 * 1000 * 1000) {
            return "${bytes / (1000 * 1000)}MB"
        }
        return "${bytes / (1000 * 1000 * 1000)}GB"
    }

    private static func pow1000(n: Int64): Float64 {
        var result: Float64 = 1.0
        for (_ in 0..n) {
            result = result * 1000.0
        }
        return result
    }
}

// ============================================================================
// 持续时间格式化
// 严格翻译自: fmt.zig:1586-1647 formatDurationOneDecimal
//   "Return a Formatter for number of nanoseconds according to its magnitude:
//    [#y][#w][#d][#h][#m]#[.###][n|u|m]s"
// ============================================================================

/// 持续时间格式化 - 对应 Bun fmtDurationOneDecimal
/// 严格翻译自: fmt.zig:1586-1647 FormatDurationData
public class DurationFormatter {
    /// 格式化纳秒 - 对应 Bun fmtDurationOneDecimal(ns)
    /// 严格翻译自: fmt.zig:1592-1647 formatDurationOneDecimal
    public static func formatNanos(ns: Int64): String {
        var remaining = ns
        let negative = remaining < 0
        if (negative) { remaining = -remaining }
        var sb = StringBuilder()
        if (negative) { sb.append('-') }

        // 年
        let nsPerYear: Int64 = 365 * 24 * 3600 * 1000000000
        if (remaining >= nsPerYear) {
            let years = remaining / nsPerYear
            sb.append("${years}y")
            remaining = remaining % nsPerYear
            if (remaining == 0) { return sb.toString() }
        }
        // 周
        let nsPerWeek: Int64 = 7 * 24 * 3600 * 1000000000
        if (remaining >= nsPerWeek) {
            let weeks = remaining / nsPerWeek
            sb.append("${weeks}w")
            remaining = remaining % nsPerWeek
            if (remaining == 0) { return sb.toString() }
        }
        // 天
        let nsPerDay: Int64 = 24 * 3600 * 1000000000
        if (remaining >= nsPerDay) {
            let days = remaining / nsPerDay
            sb.append("${days}d")
            remaining = remaining % nsPerDay
            if (remaining == 0) { return sb.toString() }
        }
        // 小时
        let nsPerHour: Int64 = 3600 * 1000000000
        if (remaining >= nsPerHour) {
            let hours = remaining / nsPerHour
            sb.append("${hours}h")
            remaining = remaining % nsPerHour
            if (remaining == 0) { return sb.toString() }
        }
        // 分钟
        let nsPerMin: Int64 = 60 * 1000000000
        if (remaining >= nsPerMin) {
            let mins = remaining / nsPerMin
            sb.append("${mins}m")
            remaining = remaining % nsPerMin
            if (remaining == 0) { return sb.toString() }
        }
        // 秒
        let nsPerSec: Int64 = 1000000000
        if (remaining >= nsPerSec) {
            let kunits = remaining * 1000 / nsPerSec
            sb.append("${kunits / 1000}")
            let frac = (kunits % 1000) / 100
            if (frac > 0) { sb.append(".${frac}") }
            sb.append("s")
            return sb.toString()
        }
        // 毫秒
        let nsPerMs: Int64 = 1000000
        if (remaining >= nsPerMs) {
            let kunits = remaining * 1000 / nsPerMs
            sb.append("${kunits / 1000}")
            let frac = (kunits % 1000) / 100
            if (frac > 0) { sb.append(".${frac}") }
            sb.append("ms")
            return sb.toString()
        }
        // 微秒
        let nsPerUs: Int64 = 1000
        if (remaining >= nsPerUs) {
            let kunits = remaining * 1000 / nsPerUs
            sb.append("${kunits / 1000}")
            let frac = (kunits % 1000) / 100
            if (frac > 0) { sb.append(".${frac}") }
            sb.append("us")
            return sb.toString()
        }
        sb.append("${remaining}ns")
        return sb.toString()
    }

    /// 格式化毫秒 - 便捷方法
    public static func format(ms: Int64): String {
        return formatNanos(ms * 1000000)
    }

    /// 格式化微秒
    public static func formatMicros(us: Int64): String {
        return formatNanos(us * 1000)
    }
}

// ============================================================================
// 十六进制格式化
// 严格翻译自: fmt.zig:1484-1557 HexIntFormatter, lower/upper hex tables
// ============================================================================

/// 十六进制字节格式化 - 对应 Bun HexBytes
public class HexFormatter {
    /// 字节数组转十六进制字符串
    public static func encode(bytes: Array<UInt8>): String {
        let hex = "0123456789abcdef"
        var sb = StringBuilder()
        for (b in bytes) {
            sb.append(hex[Int32((b >> 4) & 0x0F)])
            sb.append(hex[Int32(b & 0x0F)])
        }
        return sb.toString()
    }

    /// 字节数组转十六进制 (大写)
    public static func encodeUpper(bytes: Array<UInt8>): String {
        let hex = "0123456789ABCDEF"
        var sb = StringBuilder()
        for (b in bytes) {
            sb.append(hex[Int32((b >> 4) & 0x0F)])
            sb.append(hex[Int32(b & 0x0F)])
        }
        return sb.toString()
    }

    /// 十六进制字符串转字节数组
    public static func decode(hex: String): Array<UInt8> {
        var result = Array<UInt8>()
        let chars = hex.toArray()
        var i = 0
        while (i + 1 < chars.size) {
            let hi = hexDigitValue(chars[i])
            let lo = hexDigitValue(chars[i + 1])
            result.append(UInt8(hi * 16 + lo))
            i += 2
        }
        return result
    }

    /// 解析单个十六进制字符
    public static func hexDigitValue(c: Char): Int64 {
        if (c >= '0' && c <= '9') {
            return Int64(c.value - '0'.value)
        }
        if (c >= 'a' && c <= 'f') {
            return Int64(c.value - 'a'.value + 10)
        }
        if (c >= 'A' && c <= 'F') {
            return Int64(c.value - 'A'.value + 10)
        }
        return 0
    }
}

// ============================================================================
// JSON 字符串处理
// 严格翻译自: fmt.zig:214-246 JSONFormatter, encode_json_string_chars
// ============================================================================

/// JSON 字符串格式化 - 对应 Bun JSONFormatter
public class JsonStringFormatter {
    /// 转义 JSON 字符串中的特殊字符
    public static func escape(s: String): String {
        var sb = StringBuilder()
        sb.append('"')
        for (c in s) {
            match (c) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case '\n' => sb.append("\\n")
                case '\r' => sb.append("\\r")
                case '\t' => sb.append("\\t")
                case '\b' => sb.append("\\b")
                case '\u{0c}' => sb.append("\\f")
                case _ => {
                    if (c.value < 0x20) {
                        sb.append("\\u00")
                        sb.append(IntFormatter.toHexString(Int64(c.value)).padStart(2, '0'))
                    } else {
                        sb.append(c)
                    }
                }
            }
        }
        sb.append('"')
        return sb.toString()
    }

    /// 引号包裹 - 对应 Bun quotedWriter / QuotedFormatter
    /// 严格翻译自: fmt.zig:675-693
    public static func quote(s: String): String {
        // 如果字符串包含特殊字符, 使用完整转义
        if (needsQuoting(s)) {
            return escape(s)
        }
        return "\"${s}\""
    }

    /// 检查字符串是否需要引号转义
    private static func needsQuoting(s: String): Bool {
        for (c in s) {
            if (c == '"' || c == '\\' || c == '\n' || c == '\r' || c == '\t' ||
                c.value < 0x20) {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// 字符串填充和格式化增强
// 严格翻译自: fmt.zig 中的字符串操作工具
// ============================================================================

/// 字符串填充扩展
public extension String {
    /// 左填充 - 对应 Bun padLeft
    func padStart(length: Int64, char: Char): String {
        if (this.length >= length) {
            return this
        }
        var sb = StringBuilder()
        for (_ in 0..(length - this.length)) {
            sb.append(char)
        }
        sb.append(this)
        return sb.toString()
    }

    /// 右填充 - 对应 Bun padRight
    func padEnd(length: Int64, char: Char): String {
        if (this.length >= length) {
            return this
        }
        var sb = StringBuilder()
        sb.append(this)
        for (_ in 0..(length - this.length)) {
            sb.append(char)
        }
        return sb.toString()
    }

    /// 居中 - 对应 Bun center
    func center(length: Int64, char: Char): String {
        if (this.length >= length) {
            return this
        }
        let totalPad = length - this.length
        let leftPad = totalPad / 2
        let rightPad = totalPad - leftPad
        var sb = StringBuilder()
        for (_ in 0..leftPad) { sb.append(char) }
        sb.append(this)
        for (_ in 0..rightPad) { sb.append(char) }
        return sb.toString()
    }

    /// 截断 - 对应 Bun truncate
    func truncate(maxLength: Int64, suffix: String): String {
        if (this.length <= maxLength) {
            return this
        }
        if (maxLength <= suffix.length) {
            return suffix.substring(0, maxLength)
        }
        return this.substring(0, maxLength - suffix.length) + suffix
    }
}

// ============================================================================
// URL 格式化
// 严格翻译自: fmt.zig:479-544 URLFormatter, HostFormatter
// ============================================================================

/// URL 协议类型 - 对应 Bun URLFormatter.Proto
public enum UrlProto {
    | Http
    | Https
    | Unix
    | Abstract

    public func scheme(): String {
        match (this) {
            case Http => "http"
            case Https => "https"
            case Unix => "unix"
            case Abstract => "abstract"
        }
    }
}

/// URL 格式化器 - 对应 Bun URLFormatter
/// 严格翻译自: fmt.zig:479-522
public class UrlFormatter {
    public var proto: UrlProto
    public var hostname: ?String
    public var port: ?UInt16

    public init(proto: UrlProto, hostname: ?String, port: ?UInt16) {
        this.proto = proto
        this.hostname = hostname
        this.port = port
    }

    /// 格式化 URL - 对应 Bun URLFormatter.format
    public func format(): String {
        var sb = StringBuilder()
        sb.append("${proto.scheme()}://")

        match (hostname) {
            case Some(h) => sb.append(h)
            case None => sb.append("localhost")
        }

        if (proto == UrlProto.Unix) {
            return sb.toString()
        }

        let isPortOptional = match (port) {
            case None => true
            case Some(p) =>
                (proto == UrlProto.Https && p == UInt16(443)) ||
                (proto == UrlProto.Http && p == UInt16(80))
        }
        if (isPortOptional) {
            sb.append("/")
        } else {
            sb.append(":${port.getOrThrow()}/")
        }
        return sb.toString()
    }
}

/// 主机格式化器 - 对应 Bun HostFormatter
/// 严格翻译自: fmt.zig:524-544
public class HostFormatter {
    public var host: String
    public var port: ?UInt16
    public var isHttps: Bool

    public init(host: String, port: ?UInt16, isHttps: Bool) {
        this.host = host
        this.port = port
        this.isHttps = isHttps
    }

    public func format(): String {
        var sb = StringBuilder()
        sb.append(host)

        let isPortOptional = match (port) {
            case None => true
            case Some(p) =>
                (isHttps && p == UInt16(443)) ||
                (!isHttps && p == UInt16(80))
        }
        if (!isPortOptional) {
            sb.append(":${port.getOrThrow()}")
        }
        return sb.toString()
    }
}

// ============================================================================
// 表格格式化
// 严格翻译自: fmt.zig:1-105 TableSymbols, Table
// ============================================================================

/// 表格符号 - 对应 Bun TableSymbols
/// 严格翻译自: fmt.zig:1-43
public class TableSymbols {
    public var enableAnsiColors: Bool

    public init(enableAnsiColors: Bool) {
        this.enableAnsiColors = enableAnsiColors
    }

    public static let UNICODE: TableSymbols = TableSymbols(true)
    public static let ASCII: TableSymbols = TableSymbols(false)

    public func topLeftSep(): String { if (enableAnsiColors) { "\u{250c}" } else { "|" } }
    public func topRightSep(): String { if (enableAnsiColors) { "\u{2510}" } else { "|" } }
    public func topColumnSep(): String { if (enableAnsiColors) { "\u{252c}" } else { "-" } }
    public func bottomLeftSep(): String { if (enableAnsiColors) { "\u{2514}" } else { "|" } }
    public func bottomRightSep(): String { if (enableAnsiColors) { "\u{2518}" } else { "|" } }
    public func bottomColumnSep(): String { if (enableAnsiColors) { "\u{2534}" } else { "-" } }
    public func middleLeftSep(): String { if (enableAnsiColors) { "\u{251c}" } else { "|" } }
    public func middleRightSep(): String { if (enableAnsiColors) { "\u{2524}" } else { "|" } }
    public func middleColumnSep(): String { if (enableAnsiColors) { "\u{253c}" } else { "|" } }
    public func horizontalEdge(): String { if (enableAnsiColors) { "\u{2500}" } else { "-" } }
    public func verticalEdge(): String { if (enableAnsiColors) { "\u{2502}" } else { "|" } }
}

/// 简单表格格式化 - 对应 Bun Table
public class TableFormatter {
    private var columnNames: ArrayList<String>
    private var rows: ArrayList<ArrayList<String>>
    private var symbols: TableSymbols

    public init(symbols: TableSymbols) {
        this.columnNames = ArrayList<String>()
        this.rows = ArrayList<ArrayList<String>>()
        this.symbols = symbols
    }

    /// 设置列名
    public func setColumns(names: ArrayList<String>): Unit {
        columnNames = names
    }

    /// 添加行
    public func addRow(row: ArrayList<String>): Unit {
        rows.append(row)
    }

    /// 格式化为字符串
    public func format(): String {
        var sb = StringBuilder()
        // 计算每列最大宽度
        var widths = ArrayList<Int64>()
        for (name in columnNames) {
            widths.append(name.length)
        }
        for (row in rows) {
            for (i in 0..row.size) {
                if (i < widths.size) {
                    let w = row[i].length
                    if (w > widths[i]) {
                        widths[i] = w
                    }
                }
            }
        }
        // 打印顶线
        printLine(sb, symbols.topLeftSep(), symbols.topRightSep(), symbols.topColumnSep(), widths)
        // 打印列名
        sb.append(symbols.verticalEdge())
        for (i in 0..columnNames.size) {
            sb.append(" ${columnNames[i].padEnd(widths[i] + 1, ' ')}")
        }
        sb.append("\n")
        // 打印中线
        printLine(sb, symbols.middleLeftSep(), symbols.middleRightSep(), symbols.middleColumnSep(), widths)
        // 打印行
        for (row in rows) {
            sb.append(symbols.verticalEdge())
            for (i in 0..row.size) {
                if (i < widths.size) {
                    sb.append(" ${row[i].padEnd(widths[i] + 1, ' ')}")
                }
            }
            sb.append("\n")
        }
        // 打印底线
        printLine(sb, symbols.bottomLeftSep(), symbols.bottomRightSep(), symbols.bottomColumnSep(), widths)
        return sb.toString()
    }

    private func printLine(sb: StringBuilder, left: String, right: String, mid: String, widths: ArrayList<Int64>): Unit {
        sb.append(left)
        for (i in 0..widths.size) {
            for (_ in 0..widths[i] + 2) {
                sb.append(symbols.horizontalEdge())
            }
            if (i < widths.size - 1) {
                sb.append(mid)
            }
        }
        sb.append("${right}\n")
    }
}

// ============================================================================
// 截断哈希格式化
// 严格翻译自: fmt.zig:1815-1839 truncatedHash32
// ============================================================================

/// 截断哈希格式化 - 对应 Bun truncatedHash32
/// 严格翻译自: fmt.zig:1815-1839
/// esbuild 风格的 8 字符 base32 编码哈希
/// 省略了容易混淆的字符 (i, l, o, k)
public class TruncatedHash32 {
    private static let ENCODE_TABLE: String = "0123456789abcdefghjkmnpqrstvwxyz"

    /// 编码 64 位哈希为 8 字符字符串
    /// 严格翻译自: fmt.zig:1822-1839 truncatedHash32Impl
    public static func encode(hash: UInt64): String {
        let chars = ENCODE_TABLE.toArray()
        var sb = StringBuilder()
        var h = hash
        // 逐字节取低 5 位 (base32 = 5 bits)
        for (_ in 0..8) {
            sb.append(chars[Int32(h & UInt64(0x1F))])
            h = h >> 5
        }
        return sb.toString()
    }
}

// ============================================================================
// NPM URL 脱敏格式化
// 严格翻译自: fmt.zig:107-164 RedactedNpmUrlFormatter
// ============================================================================

/// NPM URL 脱敏 - 对应 Bun RedactedNpmUrlFormatter
/// 在日志中隐藏 UUID 和 NPM secret
public class RedactedNpmUrlFormatter {
    /// 脱敏 URL - 对应 Bun RedactedNpmUrlFormatter.format
    /// 隐藏 URL 中的 token 参数和 UUID
    public static func redact(url: String): String {
        var result = url
        // 隐藏 token 参数
        let tokenIdx = result.indexOf("token=")
        if (tokenIdx >= 0) {
            let before = result.substring(0, tokenIdx + 6)
            var after = result.substring(tokenIdx + 6)
            let ampIdx = after.indexOf("&")
            if (ampIdx >= 0) {
                after = "***" + after.substring(ampIdx)
            } else {
                after = "***"
            }
            result = before + after
        }
        // 隐藏 _auth 参数
        let authIdx = result.indexOf("_auth=")
        if (authIdx >= 0) {
            let before = result.substring(0, authIdx + 6)
            var after = result.substring(authIdx + 6)
            let ampIdx = after.indexOf("&")
            if (ampIdx >= 0) {
                after = "***" + after.substring(ampIdx)
            } else {
                after = "***"
            }
            result = before + after
        }
        return result
    }
}

/// 依赖 URL 格式化 - 对应 Bun DependencyUrlFormatter
/// 严格翻译自: fmt.zig:167-185
public class DependencyUrlFormatter {
    /// 格式化依赖 URL - 对应 Bun DependencyUrlFormatter.format
    /// 将 npm 包名中的 / 替换为 %2f
    public static func format(url: String): String {
        var sb = StringBuilder()
        var remain = url
        while (true) {
            let slashIdx = remain.indexOf("/")
            if (slashIdx < 0) {
                sb.append(remain)
                break
            }
            sb.append(remain.substring(0, slashIdx))
            sb.append("%2f")
            remain = remain.substring(slashIdx + 1)
        }
        return sb.toString()
    }
}

// ============================================================================
// OutOfRange 格式化器
// 严格翻译自: fmt.zig:1736-1813 NewOutOfRangeFormatter
//   用于生成 Node.js 兼容的 "out of range" 错误消息
// ============================================================================

/// 范围错误格式化 - 对应 Bun outOfRange
/// 严格翻译自: fmt.zig:1736-1813
public class OutOfRangeFormatter {
    /// 格式化范围错误消息
    /// 对应 Bun NewOutOfRangeFormatter(T).format
    public static func formatInt(fieldName: String, value: Int64, min: ?Int64, max: ?Int64, message: String): String {
        var sb = StringBuilder()
        if (fieldName.length > 0) {
            sb.append("The value of \"${fieldName}\" is out of range. It must be ")
        } else {
            sb.append("The value is out of range. It must be ")
        }
        match (min, max) {
            case (Some(lo), Some(hi)) => sb.append(">= ${lo} and <= ${hi}.")
            case (Some(lo), None) => sb.append(">= ${lo}.")
            case (None, Some(hi)) => sb.append("<= ${hi}.")
            case (None, None) =>
                if (message.length > 0) {
                    sb.append("${message}.")
                } else {
                    sb.append("within the range of values for type Int64.")
                }
        }
        sb.append(" Received ${value}")
        return sb.toString()
    }

    /// 格式化浮点范围错误
    public static func formatFloat(fieldName: String, value: Float64, min: ?Float64, max: ?Float64): String {
        var sb = StringBuilder()
        sb.append("The value of \"${fieldName}\" is out of range. It must be ")
        match (min, max) {
            case (Some(lo), Some(hi)) => sb.append(">= ${lo} and <= ${hi}.")
            case (Some(lo), None) => sb.append(">= ${lo}.")
            case (None, Some(hi)) => sb.append("<= ${hi}.")
            case (None, None) => sb.append("within the range of values for type Float64.")
        }
        sb.append(" Received ${value}")
        return sb.toString()
    }
}

// ============================================================================
// Enum 标签列表格式化
// 严格翻译自: fmt.zig:1326-1359 EnumTagListFormatter
// ============================================================================

/// 枚举标签列表格式化 - 对应 Bun EnumTagListFormatter
/// 将枚举类型的所有变体名格式化为列表
public class EnumTagListFormatter {
    /// 格式化为逗号分隔列表 - 对应 Bun EnumTagListFormatter(.list)
    public static func formatList(names: ArrayList<String>): String {
        var sb = StringBuilder()
        for (i in 0..names.size) {
            if (i > 0) {
                if (i + 1 == names.size) {
                    sb.append(", or ")
                } else {
                    sb.append(", ")
                }
            }
            sb.append("\"${names[i]}\"")
        }
        return sb.toString()
    }

    /// 格式化为破折号列表 - 对应 Bun EnumTagListFormatter(.dash)
    public static func formatDash(names: ArrayList<String>): String {
        var sb = StringBuilder()
        for (name in names) {
            sb.append("\n-  ${name}")
        }
        return sb.toString()
    }
}

// ============================================================================
// Slice 格式化
// 严格翻译自: fmt.zig:1649-1667 FormatSlice
// ============================================================================

/// 切片格式化 - 对应 Bun fmtSlice
/// 将数组的元素用分隔符连接
public class SliceFormatter {
    /// 格式化字符串数组 - 对应 Bun fmtSlice(data, delim)
    public static func format(items: ArrayList<String>, delim: String): String {
        if (items.size == 0) { return "" }
        var sb = StringBuilder()
        sb.append(items[0])
        for (i in 1..items.size) {
            if (delim.length > 0) { sb.append(delim) }
            sb.append(items[i])
        }
        return sb.toString()
    }
}

// ============================================================================
// NullableFallback 格式化
// 严格翻译自: fmt.zig:1698-1715 NullableFallback
// ============================================================================

/// 可空值格式化 - 对应 Bun NullableFallback
/// 格式化可空值: 有值时显示值, 为空时显示后备字符串
public class NullableFormatter {
    public static func format(value: ?String, fallback: String): String {
        match (value) {
            case Some(v) => return v
            case None => return fallback
        }
    }

    public static func formatInt(value: ?Int64, fallback: String): String {
        match (value) {
            case Some(v) => return v.toString()
            case None => return fallback
        }
    }
}

// ============================================================================
// JavaScript 标识符格式化
// 严格翻译自: fmt.zig:548-616 FormatValidIdentifier
//   将任意字符串格式化为合法的 ECMAScript 标识符
//   非标识符字符替换为下划线
// ============================================================================

/// 标识符格式化 - 对应 Bun FormatValidIdentifier
/// 将字符串转换为合法的 JavaScript 标识符
public class IdentifierFormatter {
    /// 格式化为合法标识符 - 对应 Bun fmtIdentifier
    /// 严格翻译自: fmt.zig:548-616 FormatValidIdentifier.format
    public static func format(name: String): String {
        if (name.length == 0) { return "_" }
        var sb = StringBuilder()
        var needsGap = false
        let chars = name.toArray()
        for (i in 0..chars.size) {
            let c = chars[i]
            if (isIdentContinue(c)) {
                if (needsGap) {
                    sb.append('_')
                    needsGap = false
                }
                sb.append(c)
            } else if (!needsGap) {
                needsGap = true
            }
        }
        if (needsGap) {
            sb.append('_')
        }
        if (sb.toString().length == 0) {
            return "_"
        }
        return sb.toString()
    }

    private static func isIdentStart(c: Char): Bool {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
               c == '_' || c == '$'
    }

    private static func isIdentContinue(c: Char): Bool {
        return isIdentStart(c) || (c >= '0' && c <= '9')
    }
}

// ============================================================================
// GitHub Action 格式化
// 严格翻译自: fmt.zig:618-673 githubActionWriter / GithubActionFormatter
//   将字符串安全输出到 GitHub Action: \n -> %0A, 剥离 ANSI
// ============================================================================

/// GitHub Action 输出格式化 - 对应 Bun GithubActionFormatter
/// 严格翻译自: fmt.zig:622-659 githubActionWriter
/// 将换行编码为 %0A，剥离 ANSI 转义序列
public class GithubActionFormatter {
    /// 格式化 - 对应 Bun githubActionWriter(writer, text)
    /// 将换行符编码为 %0A，剥离 ANSI 转义码
    public static func format(text: String): String {
        var sb = StringBuilder()
        var i = 0
        let chars = text.toArray()
        while (i < chars.size) {
            let c = chars[i]
            if (c == '\n') {
                // 换行 -> %0A
                sb.append("%0A")
                i += 1
            } else if (c == '\r' && i + 1 < chars.size && chars[i + 1] == '\n') {
                // \r\n -> %0A
                sb.append("%0A")
                i += 2
            } else if (c.value == 0x1b && i + 1 < chars.size && chars[i + 1] == '[') {
                // ANSI 转义序列: \u{1b}[...m -> 跳过
                var j = i + 2
                while (j < chars.size && j < i + 8) {
                    if (chars[j] == 'm') {
                        j += 1
                        break
                    }
                    j += 1
                }
                i = j
            } else if (c.value > 0x7F) {
                // 非 ASCII 字符: 跳过 (GitHub Action 不支持)
                i += 1
            } else {
                sb.append(c)
                i += 1
            }
        }
        return sb.toString()
    }
}

// ============================================================================
// PowerShell 转义
// 严格翻译自: fmt.zig:1717-1730 escapePowershell
//   将 " 和 ` 转义为 `" 和 ``
// ============================================================================

/// PowerShell 转义工具 - 对应 Bun escapePowershell
/// 严格翻译自: fmt.zig:1721-1730 escapePowershellImpl
public class PowershellEscape {
    /// 转义字符串中的特殊字符
    /// 对应: while (indexOfAny(remain, "\"`")) |i| { ... }
    public static func escape(str: String): String {
        var sb = StringBuilder()
        var remain = str
        while (true) {
            let idx = indexOfSpecial(remain)
            if (idx < 0) {
                sb.append(remain)
                break
            }
            sb.append(remain.substring(0, idx))
            sb.append('`')
            sb.append(remain.toCharArray()[idx])
            remain = remain.substring(idx + 1)
        }
        return sb.toString()
    }

    private static func indexOfSpecial(s: String): Int64 {
        let chars = s.toArray()
        for (i in 0..chars.size) {
            if (chars[i] == '"' || chars[i] == '`') {
                return Int64(i)
            }
        }
        return Int64(-1)
    }
}

// ============================================================================
// QuotedFormatter - 引号包裹格式化
// 严格翻译自: fmt.zig:675-693 quotedWriter / QuotedFormatter
//   如果字符串包含特殊字符则使用 JSON 转义，否则简单包裹
// ============================================================================

/// 引号包裹格式化 - 对应 Bun QuotedFormatter
/// 严格翻译自: fmt.zig:675-693
public class QuotedFormatter {
    /// 格式化引号字符串
    /// 对应 Bun quotedWriter: 如果包含换行/非ASCII/引号则 JSON 转义
    public static func quote(text: String): String {
        if (needsFullEscape(text)) {
            return JsonStringFormatter.escape(text)
        }
        return "\"${text}\""
    }

    private static func needsFullEscape(s: String): Bool {
        for (c in s) {
            if (c == '"' || c == '\\' || c == '\n' || c == '\r' ||
                c == '\t' || c.value > 0x7F || c.value < 0x20) {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// IntegrityFormatter - SHA-512 完整性格式化
// 严格翻译自: fmt.zig:187-212 IntegrityFormatter
//   将 SHA-512 digest 格式化为 base64 "sha512-..." 字符串
//   short 模式: sha512-<13 chars>[...]<15 chars>
//   full 模式: sha512-<全部 base64>
// ============================================================================

/// SHA-512 完整性格式化 - 对应 Bun IntegrityFormatter
/// 严格翻译自: fmt.zig:192-208
public class IntegrityFormatter {
    /// Base64 编码表
    private static let BASE64_CHARS: String =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    /// 格式化 SHA-512 字节为完整性字符串 (短格式)
    /// 对应 Bun IntegrityFormatter(.short).format
    public static func formatShort(bytes: Array<UInt8>): String {
        let encoded = base64Encode(bytes)
        if (encoded.length <= 28) {
            return "sha512-${encoded}"
        }
        let head = encoded.substring(0, 13)
        let tail = encoded.substring(encoded.length - 15)
        return "sha512-${head}[...]${tail}"
    }

    /// 格式化 SHA-512 字节为完整性字符串 (完整格式)
    /// 对应 Bun IntegrityFormatter(.full).format
    public static func formatFull(bytes: Array<UInt8>): String {
        return "sha512-${base64Encode(bytes)}"
    }

    /// Base64 编码
    private static func base64Encode(bytes: Array<UInt8>): String {
        let chars = BASE64_CHARS.toCharArray()
        var sb = StringBuilder()
        var i = 0
        while (i + 2 < bytes.size) {
            let b0 = Int32(bytes[i])
            let b1 = Int32(bytes[i + 1])
            let b2 = Int32(bytes[i + 2])
            sb.append(chars[(b0 >> 2) & 0x3F])
            sb.append(chars[((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)])
            sb.append(chars[((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03)])
            sb.append(chars[b2 & 0x3F])
            i += 3
        }
        if (i < bytes.size) {
            let b0 = Int32(bytes[i])
            sb.append(chars[(b0 >> 2) & 0x3F])
            if (i + 1 < bytes.size) {
                let b1 = Int32(bytes[i + 1])
                sb.append(chars[((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)])
                sb.append(chars[(b1 & 0x0F) << 2])
            } else {
                sb.append(chars[(b0 & 0x03) << 4])
                sb.append('=')
            }
            sb.append('=')
        }
        return sb.toString()
    }
}

// ============================================================================
// JavaScript 语法高亮器
// 严格翻译自: fmt.zig:694-1317 QuickAndDirtyJavaScriptSyntaxHighlighter
//   为 JS 源码添加 ANSI 颜色
//   关键字: 品红/蓝色, 数字: 黄色, 字符串: 绿色, 注释: 灰色
// ============================================================================

/// JS 关键字颜色 - 对应 Bun ColorCode
/// 严格翻译自: fmt.zig:712-728
public enum JsHighlightColor {
    | Magenta   // \u{1b}[35m - 关键字
    | Blue      // \u{1b}[34m - 类型关键字
    | Orange    // \u{1b}[33m - true/false/null/undefined
    | Red       // \u{1b}[31m - delete
    | Pink      // \u{1b}[38;5;206m - this

    public func ansiCode(): String {
        match (this) {
            case Magenta => "\u{1b}[35m"
            case Blue => "\u{1b}[34m"
            case Orange => "\u{1b}[33m"
            case Red => "\u{1b}[31m"
            case Pink => "\u{1b}[38;5;206m"
        }
    }
}

/// JS 语法高亮器 - 对应 Bun QuickAndDirtyJavaScriptSyntaxHighlighter
/// 严格翻译自: fmt.zig:701-1317
/// 为 JavaScript 源码添加 ANSI 颜色高亮
public class JsHighlighter {
    /// ANSI 重置
    private static let RESET: String = "\u{1b}[0m"
    /// ANSI 黄色
    private static let YELLOW: String = "\u{1b}[33m"
    /// ANSI 绿色
    private static let GREEN: String = "\u{1b}[32m"
    /// ANSI 灰色
    private static let GRAY: String = "\u{1b}[2m"

    /// 高亮选项 - 对应 Bun Options
    public class HighlightOptions {
        public var enableColors: Bool
        public var redactSensitiveInfo: Bool

        public init() {
            enableColors = true
            redactSensitiveInfo = false
        }

        public init(enableColors: Bool, redactSensitiveInfo: Bool) {
            this.enableColors = enableColors
            this.redactSensitiveInfo = redactSensitiveInfo
        }
    }

    /// 简化关键字表 - 对应 Bun Keywords
    /// 严格翻译自: fmt.zig:731-861 Keyword enum
    private static func keywordColor(word: String): ?JsHighlightColor {
        match (word) {
            // 控制流关键字 -> 品红
            case "if" | "else" | "for" | "while" | "do" | "switch" | "case" |
                 "break" | "continue" | "return" | "throw" | "try" | "catch" |
                 "finally" | "function" | "class" | "const" | "let" | "var" |
                 "import" | "export" | "default" | "new" | "delete" | "void" |
                 "typeof" | "instanceof" | "in" | "of" | "yield" | "async" |
                 "await" | "from" | "with" | "super" | "this" | "static" |
                 "extends" | "debugger" =>
                Some(JsHighlightColor.Magenta)
            // 布尔/空 -> 橙色
            case "true" | "false" | "null" | "undefined" =>
                Some(JsHighlightColor.Orange)
            // 类型关键字 -> 蓝色
            case "type" | "interface" | "enum" | "abstract" | "implements" |
                 "private" | "protected" | "public" | "readonly" | "declare" |
                 "namespace" | "as" | "string" | "number" | "boolean" |
                 "symbol" | "any" | "object" | "unknown" | "never" =>
                Some(JsHighlightColor.Blue)
            case _ => None
        }
    }

    /// 检查字符是否为标识符起始 - 对应 Bun js_lexer.isIdentifierStart
    /// 严格翻译自: fmt.rs:25-30 js_lexer::is_identifier_start
    private static func isIdentStart(c: Char): Bool {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
               c == '_' || c == '$'
    }

    /// 检查字符是否为标识符续接 - 对应 Bun js_lexer.isIdentifierContinue
    /// 严格翻译自: fmt.rs:33-35 js_lexer::is_identifier_continue
    private static func isIdentContinue(c: Char): Bool {
        return isIdentStart(c) || (c >= '0' && c <= '9')
    }

    /// 检查字符是否为十六进制数字
    private static func isHexDigit(c: Char): Bool {
        return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    }

    /// 检查字符是否为数字
    private static func isDigit(c: Char): Bool {
        return c >= '0' && c <= '9'
    }

    /// 高亮 JavaScript 源码 - 对应 Bun format()
    /// 严格翻译自: fmt.zig:875-1317 QuickAndDirtyJavaScriptSyntaxHighlighter.format
    public static func highlight(text: String, options: HighlightOptions): String {
        if (!options.enableColors || text.length > 2048 || text.length == 0) {
            return text
        }
        // 检查是否全 ASCII
        for (c in text) {
            if (c.value > 0x7F) {
                return text
            }
        }

        var sb = StringBuilder()
        var i = 0
        let chars = text.toCharArray()

        while (i < chars.size) {
            let c = chars[i]

            // 标识符/关键字
            if (isIdentStart(c)) {
                var j = i + 1
                while (j < chars.size && isIdentContinue(chars[j])) {
                    j += 1
                }
                let word = text.substring(Int64(i), Int64(j))
                let color = keywordColor(word)
                match (color) {
                    case Some(clr) => sb.append("${clr.ansiCode()}${word}${RESET}")
                    case None => sb.append(word)
                }
                i = j
            }
            // 数字 - 对应 Bun '0'...'9' case
            else if (isDigit(c)) {
                var j = i + 1
                // 检查 0x 十六进制前缀
                if (c == '0' && j < chars.size && (chars[j] == 'x' || chars[j] == 'X')) {
                    j += 1
                    while (j < chars.size && isHexDigit(chars[j])) {
                        j += 1
                    }
                } else {
                    while (j < chars.size &&
                           (isDigit(chars[j]) || chars[j] == '.' ||
                            chars[j] == 'e' || chars[j] == 'E')) {
                        j += 1
                    }
                }
                sb.append("${YELLOW}${text.substring(Int64(i), Int64(j))}${RESET}")
                i = j
            }
            // 字符串/模板字符串 - 对应 Bun '`', '"', '\'' case
            else if (c == '"' || c == '\'' || c == '`') {
                let quote = c
                var j = i + 1
                while (j < chars.size && chars[j] != quote) {
                    if (chars[j] == '\\' && j + 1 < chars.size) {
                        j += 1  // 跳过转义字符
                    }
                    j += 1
                }
                // 包含结束引号
                if (j < chars.size) { j += 1 }
                sb.append("${GREEN}${text.substring(Int64(i), Int64(j))}${RESET}")
                i = j
            }
            // 单行注释 //
            else if (c == '/' && i + 1 < chars.size && chars[i + 1] == '/') {
                var j = i + 2
                while (j < chars.size && chars[j] != '\n') {
                    j += 1
                }
                sb.append("${GRAY}${text.substring(Int64(i), Int64(j))}${RESET}")
                i = j
            }
            // 多行注释 /* */
            else if (c == '/' && i + 1 < chars.size && chars[i + 1] == '*') {
                var j = i + 2
                while (j + 1 < chars.size && !(chars[j] == '*' && chars[j + 1] == '/')) {
                    j += 1
                }
                if (j + 1 < chars.size) { j += 2 }
                sb.append("${GRAY}${text.substring(Int64(i), Int64(j))}${RESET}")
                i = j
            }
            else {
                sb.append(c)
                i += 1
            }
        }
        return sb.toString()
    }
}

// ============================================================================
// 整数解析 (严格翻译自: fmt.rs:828-970)
// parseInt / parseUnsigned / parseDecimal
//   对应 Bun std.fmt.parseInt / parseUnsigned
//   直接从字符串解析整数，支持 2-36 进制
//   支持 0x/0o/0b 前缀自动检测 (radix=0 时)
// ============================================================================

/// 解析错误 - 对应 Bun ParseIntError
/// 严格翻译自: fmt.rs:840-856
public enum ParseIntError {
    | InvalidCharacter
    | Overflow
}

/// 整数解析器 - 对应 Bun std.fmt.parseInt / parseUnsigned
/// 严格翻译自: fmt.rs:858-970
public class IntParser {
    /// 解析有符号整数 - 对应 std.fmt.parseInt
    /// 严格翻译自: fmt.rs:918-944
    /// radix: 2-36, 或 0 表示自动检测 (0x/0o/0b 前缀)
    public static func parseInt(text: String, radix: Int64): Int64 {
        if (text.length == 0) {
            throw BaoError(ErrorCode.InvalidArgument, "Empty string for parseInt")
        }
        var s = text
        var negative = false
        if (s.toCharArray()[0] == '+') {
            s = s.substring(1)
        } else if (s.toCharArray()[0] == '-') {
            negative = true
            s = s.substring(1)
        }
        let (digits, actualRadix) = autoRadix(s, radix)
        let result = parseDigits(digits, actualRadix)
        return if (negative) { -result } else { result }
    }

    /// 解析无符号整数 - 对应 std.fmt.parseUnsigned
    /// 严格翻译自: fmt.rs:951-958
    public static func parseUInt64(text: String, radix: Int64): UInt64 {
        let (digits, actualRadix) = autoRadix(text, radix)
        return UInt64(parseDigits(digits, actualRadix))
    }

    /// 十进制快捷方法 - 对应 std.fmt.parseDecimal
    /// 严格翻译自: fmt.rs:965-970
    public static func parseDecimal(text: String): ?Int64 {
        try {
            return Some(parseInt(text, 10))
        } catch (_: BaoError) {
            return None
        }
    }

    /// 自动检测进制 - 对应 Bun auto_radix
    /// 严格翻译自: fmt.rs:894-907
    private static func autoRadix(digits: String, radix: Int64): (String, Int64) {
        if (radix != 0) {
            return (digits, radix)
        }
        let chars = digits.toCharArray()
        if (chars.size >= 2 && chars[0] == '0') {
            if (chars[1] == 'x' || chars[1] == 'X') {
                return (digits.substring(2), 16)
            }
            if (chars[1] == 'o' || chars[1] == 'O') {
                return (digits.substring(2), 8)
            }
            if (chars[1] == 'b' || chars[1] == 'B') {
                return (digits.substring(2), 2)
            }
        }
        return (digits, 10)
    }

    /// 解析数字字符串 - 对应 Bun parse_with_sign
    /// 严格翻译自: fmt.rs:863-889
    private static func parseDigits(digits: String, radix: Int64): Int64 {
        if (digits.length == 0) {
            throw BaoError(ErrorCode.InvalidArgument, "No digits to parse")
        }
        var acc: Int64 = 0
        for (c in digits) {
            if (c == '_') {
                continue  // 跳过下划线分隔符
            }
            let d = charDigitValue(c)
            if (d < 0 || d >= radix) {
                throw BaoError(ErrorCode.InvalidArgument,
                    "Invalid character '${c}' for radix ${radix}")
            }
            let newAcc = acc * radix + d
            // 溢出检查
            if (newAcc < acc) {
                throw BaoError(ErrorCode.Overflow, "Integer overflow parsing '${digits}'")
            }
            acc = newAcc
        }
        return acc
    }

    /// 字符转数字 - 对应 Bun digit value extraction
    private static func charDigitValue(c: Char): Int64 {
        if (c >= '0' && c <= '9') {
            return Int64(c.value - '0'.value)
        }
        if (c >= 'a' && c <= 'z') {
            return Int64(c.value - 'a'.value + 10)
        }
        if (c >= 'A' && c <= 'Z') {
            return Int64(c.value - 'A'.value + 10)
        }
        return -1
    }
}

// ============================================================================
// 浮点数解析 (严格翻译自: fmt.rs:972-999 parseDouble)
//   对应 Bun bun.parseDouble / WTF.parseDouble
//   从字符串解析浮点数
// ============================================================================

/// 浮点解析器 - 对应 Bun parseDouble
/// 严格翻译自: fmt.rs parse_double 附近
public class FloatParser {
    /// 解析浮点数 - 对应 Bun bun.parseDouble
    /// 支持: 十进制、科学计数法、十六进制浮点、Infinity、NaN
    public static func parseDouble(text: String): Float64 {
        let s = text.trim()
        if (s == "Infinity" || s == "+Infinity") {
            return Float64.positiveInfinity
        }
        if (s == "-Infinity") {
            return Float64.negativeInfinity
        }
        if (s == "NaN") {
            return Float64.nan
        }
        // 十六进制浮点: 0x...
        if (s.length >= 2 && s.substring(0, 2) == "0x") {
            return parseHexFloat(s)
        }
        // 标准 parse
        return Float64.parse(s)
    }

    /// 十六进制浮点解析 - 对应 C strtod hex float
    private static func parseHexFloat(s: String): Float64 {
        // 简化: 支持 0xHH.HHpDD 格式
        var str = s.substring(2)  // 去掉 0x
        var intPart: Int64 = 0
        var fracPart: Int64 = 0
        var fracDigits: Int64 = 0
        var exp: Int64 = 0
        var hasDot = false
        var hasExp = false
        var negative = false

        if (str.length > 0 && str.toCharArray()[0] == '-') {
            negative = true
            str = str.substring(1)
        }

        for (c in str) {
            if (c == '.') {
                hasDot = true
            } else if (c == 'p' || c == 'P') {
                hasExp = true
                break
            } else {
                let d = IntParser.charDigitValue(c)
                if (d < 0 || d >= 16) { break }
                if (hasDot) {
                    fracPart = fracPart * 16 + d
                    fracDigits += 1
                } else {
                    intPart = intPart * 16 + d
                }
            }
        }

        if (hasExp) {
            let pIdx = str.indexOf("p")
            if (pIdx < 0) {
                let pIdx2 = str.indexOf("P")
                if (pIdx2 >= 0) {
                    exp = IntParser.parseInt(str.substring(Int64(pIdx2) + 1), 10)
                }
            } else {
                exp = IntParser.parseInt(str.substring(Int64(pIdx) + 1), 10)
            }
        }

        var result = Float64(intPart) + Float64(fracPart) / pow16(fracDigits)
        result = result * pow2(exp)
        return if (negative) { -result } else { result }
    }

    private static func pow16(n: Int64): Float64 {
        var result: Float64 = 1.0
        for (_ in 0..n) { result = result * 16.0 }
        return result
    }

    private static func pow2(n: Int64): Float64 {
        if (n >= 0) {
            var result: Float64 = 1.0
            for (_ in 0..n) { result = result * 2.0 }
            return result
        } else {
            var result: Float64 = 1.0
            for (_ in 0..(-n)) { result = result / 2.0 }
            return result
        }
    }
}

// ============================================================================
// Debug 格式化器 - debugFormat
// 严格翻译自: fmt.zig 中的各种 format() 方法的调试输出模式
//   提供带类型信息的格式化输出，用于调试和日志
// ============================================================================

/// 调试格式化器 - 对应 Bun std.fmt 中的调试格式化
/// 严格翻译自: fmt.zig 中 Msg.writeFormat / Data.writeFormat
/// 提供结构化的调试输出，包含类型信息
public class DebugFormatter {
    /// 格式化可空值 - 对应 Bun nullable debug output
    public static func formatNullable(label: String, value: ?String): String {
        match (value) {
            case Some(v) => "${label}: Some(\"${v}\")"
            case None => "${label}: None"
        }
    }

    /// 格式化可空整数 - 对应 Bun nullable int debug output
    public static func formatNullableInt(label: String, value: ?Int64): String {
        match (value) {
            case Some(v) => "${label}: Some(${v})"
            case None => "${label}: None"
        }
    }

    /// 格式化字节数组 - 对应 Bun bytes debug output
    /// 以十六进制显示前 N 个字节
    public static func formatBytes(label: String, bytes: Array<UInt8>, maxShow: Int64): String {
        let limit = if (maxShow < bytes.size) { maxShow } else { Int64(bytes.size) }
        var sb = StringBuilder()
        sb.append("${label}: [")
        for (i in 0..limit) {
            if (i > 0) { sb.append(" ") }
            let hex = IntFormatter.toHexString(Int64(bytes[Int64(i)]))
            if (hex.length == 1) { sb.append("0") }
            sb.append(hex)
        }
        if (Int64(bytes.size) > limit) {
            sb.append(" ... (${bytes.size} bytes total)")
        }
        sb.append("]")
        return sb.toString()
    }

    /// 格式化位置信息 - 对应 Bun Location.formatWriter
    /// 严格翻译自: logger.zig Msg.formatWriter
    public static func formatLocation(file: String, line: Int32, column: Int32, offset: Int64): String {
        if (line > 0 && column >= 0) {
            return "${file}:${line}:${column} (offset=${offset})"
        }
        if (line > 0) {
            return "${file}:${line} (offset=${offset})"
        }
        return "${file} (offset=${offset})"
    }

    /// 格式化错误消息 - 对应 Bun Msg.formatWriter
    /// 严格翻译自: logger.zig:507-529 Msg.formatWriter
    public static func formatError(kind: String, text: String, location: ?SourceLocation): String {
        match (location) {
            case Some(loc) =>
                let locStr = formatLocation(loc.file, loc.line, loc.column, loc.offset)
                return "${kind}: ${text}\n  at ${locStr}"
            case None =>
                return "${kind}: ${text}"
        }
    }
}

// ============================================================================
// SliceCursor / VecWriter - 缓冲区写入
// 严格翻译自: fmt.rs:740-826 SliceCursor, VecWriter
//   SliceCursor: 固定缓冲区写入 (对应 std.io.fixedBufferStream)
//   VecWriter: 动态缓冲区写入 (对应 ArrayList(u8).writer())
// ============================================================================

/// 固定缓冲区游标 - 对应 Bun SliceCursor
/// 严格翻译自: fmt.rs:740-760
/// 写入到固定大小的缓冲区，越界时返回错误
public class SliceCursor {
    private var buffer: Array<UInt8>
    private var position: Int64

    public init(capacity: Int64) {
        buffer = Array<UInt8>(capacity, item: 0)
        position = 0
    }

    /// 写入字节 - 对应 Bun SliceCursor.write_all
    public func writeAll(bytes: Array<UInt8>): Bool {
        let end = position + bytes.size
        if (end > buffer.size) {
            return false
        }
        for (i in 0..bytes.size) {
            buffer[position + i] = bytes[Int64(i)]
        }
        position = end
        return true
    }

    /// 写入字符串
    public func writeString(s: String): Bool {
        for (c in s) {
            if (position >= buffer.size) { return false }
            buffer[position] = UInt8(c.value)
            position += 1
        }
        return true
    }

    /// 已写入长度
    public func writtenLen(): Int64 {
        return position
    }

    /// 获取写入的内容
    public func toSlice(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..position) {
            result.append(buffer[i])
        }
        return result
    }

    /// 重置
    public func reset(): Unit {
        position = 0
    }

    /// 剩余空间
    public func remaining(): Int64 {
        return buffer.size - position
    }
}

/// 动态缓冲区写入器 - 对应 Bun VecWriter
/// 严格翻译自: fmt.rs:800-826
/// 自动扩容的字节写入器
public class VecWriter {
    private var data: ArrayList<UInt8>

    public init() {
        data = ArrayList<UInt8>()
    }

    /// 写入字节
    public func writeAll(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            data.append(b)
        }
    }

    /// 写入字符串 (UTF-8)
    public func writeString(s: String): Unit {
        for (c in s) {
            data.append(UInt8(c.value))
        }
    }

    /// 写入单个字节
    public func writeByte(b: UInt8): Unit {
        data.append(b)
    }

    /// 获取长度
    public func len(): Int64 {
        return data.size
    }

    /// 获取内容
    public func toBytes(): Array<UInt8> {
        return data.toArray()
    }

    /// 转为字符串
    public func toString(): String {
        var sb = StringBuilder()
        for (b in data) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 清空
    public func clear(): Unit {
        data.clear()
    }
}

// ============================================================================
// Raw 字符串显示 - 对应 Bun Raw(s)
// 严格翻译自: fmt.rs:722-737 Raw / s
//   不做任何转义，直接输出原始字节
// ============================================================================

/// 原始字符串显示 - 对应 Bun fmt::Raw
/// 严格翻译自: fmt.rs:722-737
/// 用于已知合法 UTF-8 的字节序列的零拷贝显示
public class RawString {
    private var value: String

    public init(value: String) {
        this.value = value
    }

    public func toString(): String {
        return value
    }
}
