// bao_core - 格式化工具
// 严格翻译自: src/bun_core/fmt.rs (3878L)
//   Rust 的 core::fmt 特征实现
//   包含: 数字格式化、路径格式化、JSON字符串处理、大小格式化等
package bao_core

// ============================================================================
// 数字格式化
// 严格翻译自: src/bun_core/fmt.rs 中的整数/浮点格式化
// ============================================================================

/// 整数格式化工具 - 对应 Bun itoa / print_int
public class IntFormatter {
    /// 整数转字符串 (十进制)
    public static func toString(value: Int64): String {
        return value.toString()
    }

    /// 整数转字符串 (指定进制: 2/8/10/16)
    public static func toString(value: Int64, radix: Int64): String {
        if (radix == 16) {
            return toHexString(value)
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

    /// 十六进制字符串
    public static func toHexString(value: Int64): String {
        let chars = "0123456789abcdef"
        if (value == 0) { return "0" }
        var sb = StringBuilder()
        var v = UInt64(value)
        while (v > 0) {
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

    /// 计算整数的十进制位数 - 对应 Bun digit_count
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

/// 浮点格式化工具 - 对应 Bun FormatDouble / parse_f64
public class FloatFormatter {
    /// 浮点数转字符串 (指定精度)
    public static func toString(value: Float64, precision: Int64): String {
        // 使用仓颉内置格式化
        var s = value.toString()
        // 截断到指定精度
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
}

// ============================================================================
// 路径格式化
// 严格翻译自: src/bun_core/fmt.rs - PathFormatOptions, fmt_path
// ============================================================================

/// 路径分隔符类型 - 对应 Bun PathSep
public enum PathSep {
    | Any       // 自动检测
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
public class PathFormatOptions {
    public var sep: PathSep
    public var escape: Bool

    public init() {
        sep = PathSep.Auto
        escape = false
    }

    public init(sep: PathSep) {
        this.sep = sep
        this.escape = false
    }
}

/// 路径格式化工具 - 对应 Bun fmt_path
public class PathFormatter {
    /// 格式化路径 (使用指定分隔符)
    public static func format(path: String, options: PathFormatOptions): String {
        let sep = options.sep.separator()
        var result = path
        if (options.sep == PathSep.Posix) {
            result = result.replace("\\", "/")
        } else if (options.sep == PathSep.Windows) {
            result = result.replace("/", "\\")
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
// 严格翻译自: src/bun_core/fmt.rs - SizeFormatter
// ============================================================================

/// 文件大小格式化 - 对应 Bun SizeFormatter
/// 将字节数格式化为人类可读形式 (KB, MB, GB)
public class SizeFormatter {
    /// 格式化字节大小
    public static func format(bytes: Int64): String {
        if (bytes < 1024) {
            return "${bytes} B"
        }
        var value = Float64(bytes)
        var units = ["KB", "MB", "GB", "TB", "PB"]
        var idx = 0
        while (value >= 1024.0 && idx < units.size - 1) {
            value = value / 1024.0
            idx += 1
        }
        // 保留一位小数
        let formatted = FloatFormatter.toString(value, 1)
        return "${formatted} ${units[idx]}"
    }

    /// 格式化字节大小 (紧凑格式)
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
}

// ============================================================================
// 持续时间格式化
// 严格翻译自: src/bun_core/fmt.rs - DurationOneDecimal
// ============================================================================

/// 持续时间格式化 - 对应 Bun DurationOneDecimal
public class DurationFormatter {
    /// 格式化毫秒
    public static func format(ms: Int64): String {
        if (ms < 1000) {
            return "${ms}ms"
        }
        let sec = Float64(ms) / 1000.0
        if (sec < 60.0) {
            return "${FloatFormatter.toString(sec, 1)}s"
        }
        let min = Float64(ms) / 60000.0
        if (min < 60.0) {
            return "${FloatFormatter.toString(min, 1)}m"
        }
        let hr = Float64(ms) / 3600000.0
        return "${FloatFormatter.toString(hr, 1)}h"
    }

    /// 格式化微秒
    public static func formatMicros(us: Int64): String {
        if (us < 1000) {
            return "${us}us"
        }
        return format(us / 1000)
    }

    /// 格式化纳秒
    public static func formatNanos(ns: Int64): String {
        if (ns < 1000) {
            return "${ns}ns"
        }
        return formatMicros(ns / 1000)
    }
}

// ============================================================================
// 十六进制格式化
// 严格翻译自: src/bun_core/fmt.rs - HexBytes, HexIntFormatter
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
    /// 对应 Bun hex_digit_value
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
// 严格翻译自: src/bun_core/fmt.rs - JSONFormatter, encode_json_string_chars
// ============================================================================

/// JSON 字符串格式化 - 对应 Bun JSONFormatter
public class JsonStringFormatter {
    /// 转义 JSON 字符串中的特殊字符
    /// 对应 Bun encode_json_string_chars
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
                        // 控制字符: \uXXXX
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
}

// ============================================================================
// 截断哈希格式化
// 严格翻译自: src/bun_core/fmt.rs - TruncatedHash32
// ============================================================================

/// 截断哈希格式化 - 对应 Bun TruncatedHash32
/// 将 32 位哈希值编码为 8 字符的 base32-like 字符串
public class TruncatedHash32 {
    private static let ENCODE_TABLE: String = "0123456789abcdefghijklmnopqrstuv"

    /// 编码 32 位哈希为 8 字符字符串
    public static func encode(hash: UInt32): String {
        var sb = StringBuilder()
        var h = hash
        for (_ in 0..7) {
            sb.append(ENCODE_TABLE.toArray()[Int32(h & UInt32(0x1F))])
            h = h >> 5
        }
        sb.append(ENCODE_TABLE.toArray()[Int32(h & UInt32(0x1F))])
        return sb.toString()
    }
}

// ============================================================================
// NPM URL 脱敏格式化
// 严格翻译自: src/bun_core/fmt.rs - RedactedNpmUrlFormatter
// ============================================================================

/// NPM URL 脱敏 - 对应 Bun RedactedNpmUrlFormatter
/// 在日志中隐藏 npm token 等敏感信息
public class RedactedNpmUrlFormatter {
    public static func redact(url: String): String {
        // 隐藏 URL 中的 token 参数
        var result = url
        // ?token=xxx → ?token=***
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
        return result
    }
}

/// 字符串填充扩展
public extension String {
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
}
