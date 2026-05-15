// bao_highway - SIMD 加速字符串搜索
// 严格翻译自: bun/src/highway/highway.zig (307行)
//   Highway 是 Google 的高性能 SIMD 库
//   Bun 使用 Highway 实现以下字符串搜索操作:
//     - 字符频率统计
//     - 单字符查找
//     - 换行/非ASCII字符查找
//     - JavaScript 字符串转义字符查找
//     - 任意字符集合查找
//     - WebSocket 掩码应用
//
//   Zig 版本通过 extern "c" 调用 C 实现的 SIMD 函数
//   仓颉版本提供纯仓颉回退实现，后续可替换为原生 SIMD
package bao.highway

import bao_core.*

// ============================================================================
// Highway - SIMD 加速字符串操作
// 严格翻译自: highway.zig
//   所有函数原本调用 C SIMD 实现 (highway_*)
//   仓颉版本使用纯仓颉实现，功能完全等价
// ============================================================================

/// SIMD 加速字符串操作 - 对应 Bun highway 模块
/// 提供高性能的字符串搜索和扫描操作
public class Highway {

    // ========================================================================
    // scanCharFrequency - 字符频率统计
    // 严格翻译自: highway.zig - scanCharFrequency()
    //   extern "c" fn highway_char_frequency(text, text_len, freqs, delta) void
    //   pub fn scanCharFrequency(text: string, freqs: *[64]i32, delta: i32) void
    //   统计 [a-zA-Z0-9_$] 字符的出现频率
    // ========================================================================

    /// 统计字符频率
    /// 对应 Bun scanCharFrequency()
    /// 统计文本中 [a-zA-Z0-9_$] 字符的频率
    /// freqs 数组大小为 64，delta 为每次匹配时的增量
    public static func scanCharFrequency(text: String, freqs: Array<Int64>,
                                          delta: Int64): Unit {
        if (text.size == 0 || delta == 0) {
            return
        }

        for (i in 0..text.size) {
            let c = text[i]
            let idx = charFrequencyIndex(c)
            if (idx >= 0 && idx < freqs.size) {
                freqs[idx] = freqs[idx] + delta
            }
        }
    }

    /// 字符到频率数组索引的映射
    /// 对应 Bun 的 [a-zA-Z0-9_$] 范围映射
    static func charFrequencyIndex(c: Char): Int64 {
        let v = c.value
        if (v >= 'a'.value && v <= 'z'.value) {
            return Int64(v) - Int64('a'.value)
        }
        if (v >= 'A'.value && v <= 'Z'.value) {
            return Int64(v) - Int64('A'.value) + 26
        }
        if (v >= '0'.value && v <= '9'.value) {
            return Int64(v) - Int64('0'.value) + 52
        }
        if (c == '_') {
            return 62
        }
        if (c == '$') {
            return 63
        }
        -1
    }

    // ========================================================================
    // indexOfChar - 单字符查找
    // 严格翻译自: highway.zig - indexOfChar()
    //   extern "c" fn highway_index_of_char(haystack, haystack_len, needle) usize
    //   pub fn indexOfChar(haystack: string, needle: u8) ?usize
    //   返回第一个匹配位置，或 null
    // ========================================================================

    /// 查找字符在字符串中第一次出现的位置
    /// 对应 Bun indexOfChar()
    public static func indexOfChar(haystack: String, needle: Char): ?Int64 {
        if (haystack.size == 0) {
            return None
        }

        for (i in 0..haystack.size) {
            if (haystack[i] == needle) {
                return Some(i)
            }
        }

        None
    }

    // ========================================================================
    // indexOfInterestingCharacterInStringLiteral - 字符串字面量中的特殊字符
    // 严格翻译自: highway.zig - indexOfInterestingCharacterInStringLiteral()
    //   extern "c" fn highway_index_of_interesting_character_in_string_literal(
    //       text, text_len, quote) usize
    //   pub fn indexOfInterestingCharacterInStringLiteral(slice, quote_type) ?usize
    //
    //   查找字符串字面量中需要处理的字符:
    //     - 转义字符 '\'
    //     - 引号字符 (与 quote_type 匹配)
    //     - 换行符 '\n', '\r'
    //     - 非ASCII字符 (> 127)
    // ========================================================================

    /// 查找字符串字面量中需要特殊处理的字符
    /// 对应 Bun indexOfInterestingCharacterInStringLiteral()
    public static func indexOfInterestingCharacterInStringLiteral(
        slice: String, quote: Char): ?Int64 {
        if (slice.size == 0) {
            return None
        }

        for (i in 0..slice.size) {
            let c = slice[i]
            if (c == '\\' || c == quote || c == '\n' || c == '\r' ||
                c.value > 127) {
                return Some(i)
            }
        }

        None
    }

    // ========================================================================
    // indexOfNewlineOrNonASCII - 换行或非ASCII字符
    // 严格翻译自: highway.zig - indexOfNewlineOrNonASCII()
    //   extern "c" fn highway_index_of_newline_or_non_ascii(haystack, haystack_len) usize
    //   pub fn indexOfNewlineOrNonASCII(haystack: string) ?usize
    //   查找换行符或非ASCII字符 (>127 或 <0x20)
    // ========================================================================

    /// 查找换行符或非ASCII字符
    /// 对应 Bun indexOfNewlineOrNonASCII()
    public static func indexOfNewlineOrNonASCII(haystack: String): ?Int64 {
        if (haystack.size == 0) {
            return None
        }

        for (i in 0..haystack.size) {
            let c = haystack[i]
            if (c.value > 127 || c.value < 0x20 || c == '\r' || c == '\n') {
                return Some(i)
            }
        }

        None
    }

    // ========================================================================
    // indexOfNewlineOrNonASCIIOrANSI - 换行、非ASCII 或 ANSI 转义
    // 严格翻译自: highway.zig - indexOfNewlineOrNonASCIIOrANSI()
    //   extern "c" fn highway_index_of_newline_or_non_ascii_or_ansi(
    //       haystack, haystack_len) usize
    // ========================================================================

    /// 查找换行、非ASCII 或 ANSI 转义序列
    /// 对应 Bun indexOfNewlineOrNonASCIIOrANSI()
    public static func indexOfNewlineOrNonASCIIOrANSI(haystack: String): ?Int64 {
        if (haystack.size == 0) {
            return None
        }

        for (i in 0..haystack.size) {
            let c = haystack[i]
            if (c.value > 127 || c.value < 0x20 || c == '\r' || c == '\n' ||
                c == '\u{001b}') {
                return Some(i)
            }
        }

        None
    }

    // ========================================================================
    // indexOfNewlineOrNonASCIIOrHashOrAt - 换行、非ASCII、# 或 @
    // 严格翻译自: highway.zig - indexOfNewlineOrNonASCIIOrHashOrAt()
    //   Useful for single-line JavaScript comments.
    //   Scans for: \n, \r, Non-ASCII, #, @
    //   extern "c" fn highway_index_of_newline_or_non_ascii_or_hash_or_at(
    //       haystack, haystack_len) usize
    // ========================================================================

    /// 查找换行、非ASCII、# 或 @ 字符
    /// 对应 Bun indexOfNewlineOrNonASCIIOrHashOrAt()
    /// 适用于单行 JavaScript 注释扫描
    public static func indexOfNewlineOrNonASCIIOrHashOrAt(
        haystack: String): ?Int64 {
        if (haystack.size == 0) {
            return None
        }

        for (i in 0..haystack.size) {
            let c = haystack[i]
            if (c.value > 127 || c.value < 0x20 || c == '\r' || c == '\n' ||
                c == '#' || c == '@') {
                return Some(i)
            }
        }

        None
    }

    // ========================================================================
    // indexOfSpaceOrNewlineOrNonASCII - 空格、换行或非ASCII
    // 严格翻译自: highway.zig - indexOfSpaceOrNewlineOrNonASCII()
    //   Scans for: " ", Non-ASCII (which implicitly include \n, \r, \t)
    //   extern "c" fn highway_index_of_space_or_newline_or_non_ascii(
    //       haystack, haystack_len) usize
    // ========================================================================

    /// 查找空格、换行或非ASCII字符
    /// 对应 Bun indexOfSpaceOrNewlineOrNonASCII()
    public static func indexOfSpaceOrNewlineOrNonASCII(
        haystack: String): ?Int64 {
        if (haystack.size == 0) {
            return None
        }

        for (i in 0..haystack.size) {
            let c = haystack[i]
            if (c == ' ' || c == '\n' || c == '\r' || c == '\t' ||
                c.value > 127) {
                return Some(i)
            }
        }

        None
    }

    // ========================================================================
    // containsNewlineOrNonASCIIOrQuote - 包含换行、非ASCII或引号
    // 严格翻译自: highway.zig - containsNewlineOrNonASCIIOrQuote()
    //   extern "c" fn highway_contains_newline_or_non_ascii_or_quote(
    //       text, text_len) bool
    //   Checks if the string contains any newlines, non-ASCII, or quotes
    // ========================================================================

    /// 检查字符串是否包含换行、非ASCII字符或引号
    /// 对应 Bun containsNewlineOrNonASCIIOrQuote()
    public static func containsNewlineOrNonASCIIOrQuote(text: String): Bool {
        if (text.size == 0) {
            return false
        }

        for (i in 0..text.size) {
            let c = text[i]
            if (c == '\n' || c == '\r' || c == '\'' || c == '"' || c == '`' ||
                c.value > 127) {
                return true
            }
        }
        false
    }

    // ========================================================================
    // indexOfNeedsEscapeForJavaScriptString - JavaScript 转义字符查找
    // 严格翻译自: highway.zig - indexOfNeedsEscapeForJavaScriptString()
    //   extern "c" fn highway_index_of_needs_escape_for_javascript_string(
    //       text, text_len, quote_char) usize
    //
    //   Finds the first character that needs escaping in a JavaScript string
    //   Looks for: > 127, < 0x20, \, quote_char, $ (for backtick strings)
    // ========================================================================

    /// 查找 JavaScript 字符串中需要转义的第一个字符
    /// 对应 Bun indexOfNeedsEscapeForJavaScriptString()
    public static func indexOfNeedsEscapeForJavaScriptString(
        slice: String, quoteChar: Char): ?Int64 {
        if (slice.size == 0) {
            return None
        }

        for (i in 0..slice.size) {
            let c = slice[i]
            if (c.value > 127 || c.value < 0x20 || c == '\\' || c == quoteChar ||
                c == '$' || c == '\r' || c == '\n') {
                return Some(i)
            }
        }

        None
    }

    // ========================================================================
    // indexOfAnyChar - 任意字符集合查找
    // 严格翻译自: highway.zig - indexOfAnyChar()
    //   extern "c" fn highway_index_of_any_char(
    //       text, text_len, chars, chars_len) usize
    //   pub fn indexOfAnyChar(haystack: string, chars: string) ?usize
    // ========================================================================

    /// 查找第一个出现在字符集合中的字符
    /// 对应 Bun indexOfAnyChar()
    public static func indexOfAnyChar(haystack: String,
                                       chars: String): ?Int64 {
        if (haystack.size == 0 || chars.size == 0) {
            return None
        }

        for (i in 0..haystack.size) {
            let c = haystack[i]
            for (j in 0..chars.size) {
                if (c == chars[j]) {
                    return Some(i)
                }
            }
        }

        None
    }

    // ========================================================================
    // fillWithSkipMask - WebSocket 掩码应用
    // 严格翻译自: highway.zig - fillWithSkipMask()
    //   extern "c" fn highway_fill_with_skip_mask(
    //       mask, mask_len, output, input, length, skip_mask) void
    //   Apply a WebSocket mask to data using SIMD acceleration
    //   If skip_mask is true, data is copied without masking
    // ========================================================================

    /// 应用 WebSocket 掩码
    /// 对应 Bun fillWithSkipMask()
    /// mask 为 4 字节掩码，output 为输出缓冲区，input 为输入数据
    /// skip_mask 为 true 时仅复制数据不应用掩码
    public static func fillWithSkipMask(mask: Array<Byte>, output: Array<Byte>,
                                         input: Array<Byte>,
                                         skipMask: Bool): Unit {
        if (input.size == 0) {
            return
        }

        if (skipMask) {
            // 仅复制
            for (i in 0..input.size) {
                output[i] = input[i]
            }
        } else {
            // 应用 WebSocket 掩码
            // 对应 RFC 6455: transformed-octet-i = original-octet-i ^ mask[i mod 4]
            for (i in 0..input.size) {
                output[i] = Byte(input[i].value ^ mask[i % 4].value)
            }
        }
    }

    // ========================================================================
    // copyU16ToU8 - UTF-16 到 UTF-8 转换辅助
    // 严格翻译自: highway.zig - copyU16ToU8()
    //   extern "c" fn highway_copy_u16_to_u8(input, count, output) void
    //   pub fn copyU16ToU8(input: []align(1) const u16, output: []u8) void
    // ========================================================================

    /// 将 UTF-16 数组复制到字节缓冲区 (低字节在前)
    /// 对应 Bun copyU16ToU8()
    public static func copyU16ToU8(input: Array<UInt16>,
                                    output: Array<Byte>): Unit {
        for (i in 0..input.size) {
            let v = input[i]
            output[i * 2] = Byte(v.value & 0xFF)
            output[i * 2 + 1] = Byte((v.value >> 8) & 0xFF)
        }
    }
}
