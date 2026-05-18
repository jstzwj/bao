// bao_core - 不可变字符串工具集
// 严格翻译自: src/bun_core/string/immutable.rs
//   pub fn eqlComptimeIgnoreLen(comptime, input) -> bool
//   pub fn indexOfAny(input, bytes) -> ?usize
//   pub fn indexOfChar(input, char) -> ?usize
//   pub fn countASCII(input) -> usize
//   pub fn clone(input) -> []const u8
//   pub fn concat(a, b) -> []const u8
//   pub fn hasPrefixComptime(input, prefix) -> bool
//   pub fn hasSuffixComptime(input, suffix) -> bool
// Bun: SIMD-accelerated immutable string utilities operating on &[u8]
//   核心 bun.strings 命名空间
// 仓颉: 标量实现, 保持相同的 API 语义
package bao_core

import std.collection.*

// ============================================================================
// ImmutableStrings - 不可变字符串工具
// 严格翻译自: src/bun_core/string/immutable.rs
//   SIMD-accelerated immutable string utilities operating on &[u8] (NOT &str)
//   Bun 使用 AsciiVector (SIMD) 加速, B-2 降级为 ScalarVec
//   仓颉: 纯标量实现
// ============================================================================

/// 不可变字符串工具 - 对应 Bun strings 命名空间
public class ImmutableStrings {
    /// 是否启用 SIMD - 对应 Bun ENABLE_SIMD
    public static let ENABLE_SIMD: Bool = false

    // ========================================================================
    // 比较函数
    // ========================================================================

    /// 比较相等 (忽略长度前缀) - 对应 Bun eqlComptimeIgnoreLen
    /// 比较内容是否相等, 不比较长度
    public static func eqlComptimeIgnoreLen(a: Array<UInt8>, b: Array<UInt8>): Bool {
        let aLen = a.size
        let bLen = b.size
        // 查找较短的长度进行比较
        let minLen = if (aLen < bLen) { aLen } else { bLen }
        for (i in 0..minLen) {
            if (a[i] != b[i]) {
                return false
            }
        }
        return true
    }

    /// 比较相等 (大小写不敏感) - 对应 Bun eqlCaseInsensitiveASCII
    public static func eqlCaseInsensitiveAscii(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) {
            return false
        }
        for (i in 0..a.size) {
            let ac = if (a[i] >= 65 && a[i] <= 90) { a[i] + 32 } else { a[i] }
            let bc = if (b[i] >= 65 && b[i] <= 90) { b[i] + 32 } else { b[i] }
            if (ac != bc) {
                return false
            }
        }
        return true
    }

    /// 与任意值进行大小写不敏感比较 - 对应 Bun eql_any_case_insensitive_ascii
    public static func eqlAnyCaseInsensitiveAscii(input: Array<UInt8>, candidates: Array<Array<UInt8>>): Bool {
        for (candidate in candidates) {
            if (eqlCaseInsensitiveAscii(input, candidate)) {
                return true
            }
        }
        return false
    }

    // ========================================================================
    // 查找函数
    // ========================================================================

    /// 查找任意字符的位置 - 对应 Bun indexOfAny
    public static func indexOfAny(input: Array<UInt8>, chars: Array<UInt8>): ?Int64 {
        for (i in 0..input.size) {
            for (c in chars) {
                if (input[i] == c) {
                    return Some(i)
                }
            }
        }
        return None
    }

    /// 查找字符位置 - 对应 Bun indexOfChar
    public static func indexOfChar(input: Array<UInt8>, ch: UInt8): ?Int64 {
        for (i in 0..input.size) {
            if (input[i] == ch) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找字符位置 (usize) - 对应 Bun index_of_char_usize
    public static func indexOfCharUsize(input: Array<UInt8>, ch: UInt8): ?Int64 {
        return indexOfChar(input, ch)
    }

    /// 查找 UTF-16 中字符位置 - 对应 Bun index_of_char16_usize
    public static func indexOfChar16Usize(input: Array<UInt16>, ch: UInt16): ?Int64 {
        for (i in 0..input.size) {
            if (input[i] == ch) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找子字符串 - 对应 Bun indexOf
    public static func indexOf(input: Array<UInt8>, needle: Array<UInt8>): ?Int64 {
        if (needle.size == 0) { return Some(0) }
        if (needle.size > input.size) { return None }
        var i = 0
        while (i <= input.size - needle.size) {
            var found = true
            for (j in 0..needle.size) {
                if (input[i + j] != needle[j]) {
                    found = false
                    break
                }
            }
            if (found) {
                return Some(i)
            }
            i += 1
        }
        return None
    }

    // ========================================================================
    // 前缀/后缀
    // ========================================================================

    /// 是否有前缀 - 对应 Bun hasPrefixComptime
    public static func hasPrefix(input: Array<UInt8>, prefix: Array<UInt8>): Bool {
        if (prefix.size > input.size) { return false }
        for (i in 0..prefix.size) {
            if (input[i] != prefix[i]) {
                return false
            }
        }
        return true
    }

    /// 是否有后缀 - 对应 Bun hasSuffixComptime
    public static func hasSuffix(input: Array<UInt8>, suffix: Array<UInt8>): Bool {
        if (suffix.size > input.size) { return false }
        let start = input.size - suffix.size
        for (i in 0..suffix.size) {
            if (input[start + i] != suffix[i]) {
                return false
            }
        }
        return true
    }

    // ========================================================================
    // 复制/拼接
    // ========================================================================

    /// 克隆 - 对应 Bun clone
    public static func clone(input: Array<UInt8>): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (b in input) {
            result.add(b)
        }
        return result.toArray()
    }

    /// 拼接两个字节数组 - 对应 Bun concat / append
    public static func append(a: Array<UInt8>, b: Array<UInt8>): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (byte in a) { result.add(byte) }
        for (byte in b) { result.add(byte) }
        return result.toArray()
    }

    /// 拼接多个字节数组 - 对应 Bun addConcat
    public static func concat(slices: Array<Array<UInt8>>): Array<UInt8> {
        var totalSize = 0
        for (s in slices) { totalSize += s.size }
        var result = ArrayList<UInt8>(totalSize)
        for (s in slices) {
            for (b in s) { result.add(b) }
        }
        return result.toArray()
    }

    /// 复制小写 - 对应 Bun copy_lowercase
    public static func copyLowercase(src: Array<UInt8>): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (b in src) {
            if (b >= 65 && b <= 90) {
                result.add(b + 32)
            } else {
                result.add(b)
            }
        }
        return result.toArray()
    }

    // ========================================================================
    // ASCII 检测
    // ========================================================================

    /// 统计 ASCII 字符数 - 对应 Bun countASCII
    public static func countAscii(input: Array<UInt8>): Int64 {
        var count = 0
        for (b in input) {
            if (b < 0x80) {
                count += 1
            }
        }
        return count
    }

    /// 是否全部为 ASCII - 对应 Bun is_all_ascii
    public static func isAllAscii(input: Array<UInt8>): Bool {
        for (b in input) {
            if (b >= 0x80) {
                return false
            }
        }
        return true
    }

    /// 查找第一个非 ASCII 字节 - 对应 Bun first_non_ascii
    public static func firstNonAscii(input: Array<UInt8>): ?Int64 {
        for (i in 0..input.size) {
            if (input[i] >= 0x80) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找第一个非 ASCII UTF-16 单元 - 对应 Bun first_non_ascii16
    public static func firstNonAscii16(input: Array<UInt16>): ?Int64 {
        for (i in 0..input.size) {
            if (input[i] >= 0x80) {
                return Some(i)
            }
        }
        return None
    }

    // ========================================================================
    // 编码转换
    // ========================================================================

    /// Latin1 转码点字节 - 对应 Bun latin1_to_codepoint_bytes_assume_not_ascii
    public static func latin1ToCodepointBytes(b: UInt8): Array<UInt8> {
        if (b < 0x80) {
            return [b]
        }
        return [
            UInt8(0xC0 | (b >> 6)),
            UInt8(0x80 | (b & 0x3F))
        ]
    }

    /// 复制 u8 到 u16 - 对应 Bun copy_u8_into_u16
    public static func copyU8IntoU16(dst: Array<UInt16>, src: Array<UInt8>): Unit {
        for (i in 0..src.size) {
            if (i < dst.size) {
                dst[i] = UInt16(src[i])
            }
        }
    }

    /// 复制 u16 到 u8 - 对应 Bun copy_u16_into_u8
    public static func copyU16IntoU8(dst: Array<UInt8>, src: Array<UInt16>): Unit {
        for (i in 0..src.size) {
            if (i < dst.size) {
                dst[i] = UInt8(src[i] & 0xFF)
            }
        }
    }

    // ========================================================================
    // UTF-16 辅助
    // ========================================================================

    /// UTF-16 码点 - 对应 Bun utf16_codepoint
    public static func utf16Codepoint(chars: Array<UInt16>, offset: Int64): Utf16CodepointInfo {
        if (offset >= chars.size) {
            return Utf16CodepointInfo(UInt32(0), 0)
        }
        let ch = UInt32(chars[offset])
        if (ch >= 0xD800 && ch <= 0xDBFF && offset + 1 < chars.size) {
            let low = UInt32(chars[offset + 1])
            if (low >= 0xDC00 && low <= 0xDFFF) {
                let cp = ((ch - 0xD800) << 10) + (low - 0xDC00) + 0x10000
                return Utf16CodepointInfo(cp, 2)
            }
        }
        return Utf16CodepointInfo(ch, 1)
    }

    /// UTF-16 码点 (带 FFFD) - 对应 Bun utf16_codepoint_with_fffd
    public static func utf16CodepointWithFffd(chars: Array<UInt16>, offset: Int64): Utf16CodepointInfo {
        let result = utf16Codepoint(chars, offset)
        if (result.codepoint >= 0xD800 && result.codepoint <= 0xDFFF) {
            return Utf16CodepointInfo(UInt32(0xFFFD), result.length)
        }
        return result
    }

    /// UTF-8 到 UTF-16 元素长度 - 对应 Bun element_length_utf8_into_utf16
    public static func elementLengthUtf8IntoUtf16(utf8: Array<UInt8>): Int64 {
        var length = 0
        var i = 0
        while (i < utf8.size) {
            let b = utf8[i]
            let cpSize = UnicodeHelpers.codepointSize(b)
            let cp = if (cpSize == 1) { Int32(b) } else {
                let r = UnicodeHelpers.decodeWtf8Rune(utf8, i)
                r.codepoint
            }
            if (cp > 0xFFFF) {
                length += 2  // 代理对
            } else {
                length += 1
            }
            i += cpSize
        }
        return length
    }

    // ========================================================================
    // 其他工具
    // ========================================================================

    /// U3 快速查找 - 对应 Bun U3Fast
    /// 3 字节字符串比较的快速路径
    public static func u3Fast(input: Array<UInt8>, offset: Int64, a: UInt8, b: UInt8, c: UInt8): Bool {
        if (offset + 2 >= input.size) { return false }
        return input[offset] == a && input[offset + 1] == b && input[offset + 2] == c
    }

    /// 转义正则表达式 - 对应 Bun escape_reg_exp
    public static func escapeRegExp(input: Array<UInt8>): Array<UInt8> {
        return RegexEscape.escape(bytesToString(input)).toArray()
    }

    private static func bytesToString(bytes: Array<UInt8>): String {
        var sb = StringBuilder()
        for (b in bytes) {
            sb.append(Rune(Int32(b)))
        }
        return sb.toString()
    }
}

/// UTF-16 码点信息 - 对应 Bun utf16_codepoint 返回值
public class Utf16CodepointInfo {
    public let codepoint: UInt32
    public let length: Int64

    public init(codepoint: UInt32, length: Int64) {
        this.codepoint = codepoint
        this.length = length
    }
}
