// bao_core - JavaScript 标识符检测
// 严格翻译自: src/bun_core/string/identifier.rs
//   pub fn is_identifier_start(codepoint: i32) -> bool
//   pub fn is_identifier_part(codepoint: i32) -> bool
//   pub fn is_identifier(text: &[u8]) -> bool
//   pub fn is_identifier_utf16(text: &[u16]) -> bool
// Bun: ES 标识符检测 (ECMAScript IdentifierStart/IdentifierPart)
//   使用两级 Unicode 查找表 (自动生成)
//   ASCII 快速路径: a-z A-Z _ $ (start), 加 0-9 (part)
// 仓颉: 提供 ES 标识符检测, 使用范围检查代替查找表
package bao_core

import std.collection.*

// ============================================================================
// ES 标识符检测 - 严格翻译自: src/bun_core/string/identifier.rs
//   is_identifier_start / is_identifier_part
//   对应 Zig js_lexer.isIdentifierStart / isIdentifierPart
// ============================================================================

/// JavaScript 标识符检测器 - 对应 Bun identifier 模块
/// Bun:
///   pub fn is_identifier_start(codepoint: i32) -> bool
///   pub fn is_identifier_part(codepoint: i32) -> bool
///   pub fn is_identifier(text: &[u8]) -> bool
///   pub fn is_identifier_utf16(text: &[u16]) -> bool
public class Identifier {
    /// 检查码点是否可作为标识符起始字符
    /// 对应 Bun is_identifier_start
    /// ES 规范: UnicodeIDStart | $ | _
    public static func isIdentifierStart(codepoint: Int32): Bool {
        // ASCII 快速路径: a-z, A-Z, _, $
        if (codepoint >= 0x61 && codepoint <= 0x7A) { return true }  // a-z
        if (codepoint >= 0x41 && codepoint <= 0x5A) { return true }  // A-Z
        if (codepoint == 0x5F) { return true }  // _
        if (codepoint == 0x24) { return true }  // $
        // 无效范围
        if (codepoint <= 0 || codepoint > 0x10FFFF) { return false }
        // Unicode 查找
        return isIdStartEsNext(UInt32(codepoint))
    }

    /// 检查码点是否可作为标识符部分字符
    /// 对应 Bun is_identifier_part
    /// ES 规范: UnicodeIDContinue | $ | ZWNJ | ZWJ
    public static func isIdentifierPart(codepoint: Int32): Bool {
        // ASCII 快速路径: a-z, A-Z, 0-9, _, $
        if (codepoint >= 0x61 && codepoint <= 0x7A) { return true }  // a-z
        if (codepoint >= 0x41 && codepoint <= 0x5A) { return true }  // A-Z
        if (codepoint >= 0x30 && codepoint <= 0x39) { return true }  // 0-9
        if (codepoint == 0x5F) { return true }  // _
        if (codepoint == 0x24) { return true }  // $
        // ZWNJ (U+200C) 和 ZWJ (U+200D)
        if (codepoint == 0x200C) { return true }
        if (codepoint == 0x200D) { return true }
        // 无效范围
        if (codepoint <= 0 || codepoint > 0x10FFFF) { return false }
        // Unicode 查找
        return isIdContinueEsNext(UInt32(codepoint))
    }

    /// 检查整个字符串是否为有效的 ES 标识符 (WTF-8 字节)
    /// 对应 Bun is_identifier
    /// Port of js_lexer.isIdentifier (src/js_parser/lexer.zig:3058)
    public static func isIdentifier(text: Array<UInt8>): Bool {
        if (text.size == 0) {
            return false
        }
        var pos = 0
        // 第一个字符必须是 IdentifierStart
        var firstResult = UnicodeHelpers.decodeWtf8Rune(text, pos)
        pos += firstResult.length
        if (!isIdentifierStart(firstResult.codepoint)) {
            return false
        }
        // 后续字符必须是 IdentifierPart
        while (pos < text.size) {
            let result = UnicodeHelpers.decodeWtf8Rune(text, pos)
            pos += result.length
            if (!isIdentifierPart(result.codepoint)) {
                return false
            }
        }
        return true
    }

    /// 检查整个字符串是否为有效的 ES 标识符 (String)
    public static func isIdentifier(text: String): Bool {
        if (text.size == 0) {
            return false
        }
        var bytes = ArrayList<UInt8>()
        for (c in text) {
            bytes.add(c)
        }
        return isIdentifier(bytes.toArray())
    }

    /// 检查整个字符串是否为有效的 ES 标识符 (UTF-16)
    /// 对应 Bun is_identifier_utf16
    /// Port of src/js_parser/lexer.zig:isIdentifierUTF16
    public static func isIdentifierUtf16(text: Array<UInt16>): Bool {
        let n = text.size
        if (n == 0) {
            return false
        }
        var i = 0
        while (i < n) {
            let isStart = i == 0
            // 解码 UTF-16 码点 (带孤立代理处理)
            let codepoint = decodeWtf16Codepoint(text, i)
            let advance = utf16Advance(text, i)
            i += advance
            if (isStart) {
                if (!isIdentifierStart(codepoint)) {
                    return false
                }
            } else if (!isIdentifierPart(codepoint)) {
                return false
            }
        }
        return true
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// 解码 WTF-16 码点 - 对应 Bun decode_wtf16_raw
    /// 孤立高代理也当作码点 (与 Bun/Zig 行为一致)
    private static func decodeWtf16Codepoint(text: Array<UInt16>, offset: Int64): Int32 {
        if (offset >= text.size) {
            return -1
        }
        let ch = UInt32(text[offset])
        // 高代理
        if (ch >= 0xD800 && ch <= 0xDBFF) {
            if (offset + 1 < text.size) {
                let low = UInt32(text[offset + 1])
                if (low >= 0xDC00 && low <= 0xDFFF) {
                    let cp = ((ch - 0xD800) << 10) + (low - 0xDC00) + 0x10000
                    return Int32(cp)
                }
            }
            // 孤立高代理 → 原样返回
            return Int32(ch)
        }
        return Int32(ch)
    }

    /// UTF-16 前进字节数
    private static func utf16Advance(text: Array<UInt16>, offset: Int64): Int64 {
        if (offset >= text.size) { return 0 }
        let ch = text[offset]
        if (ch >= 0xD800 && ch <= 0xDBFF && offset + 1 < text.size) {
            let low = text[offset + 1]
            if (low >= 0xDC00 && low <= 0xDFFF) {
                return 2
            }
        }
        return 1
    }

    // ========================================================================
    // Unicode ID_Start / ID_Continue 范围检查
    // 对应 Bun 的两级查找表 (这里使用范围检查简化)
    // ========================================================================

    /// 检查是否为 ES Next ID_Start - 对应 Bun is_id_start_es_next
    /// 使用 Unicode 范围 (UAX #31)
    private static func isIdStartEsNext(cp: UInt32): Bool {
        // 主要 Unicode 字母范围
        // Latin
        if (cp >= 0x00C0 && cp <= 0x00D6) { return true }
        if (cp >= 0x00D8 && cp <= 0x00F6) { return true }
        if (cp >= 0x00F8 && cp <= 0x02FF) { return true }
        if (cp >= 0x0370 && cp <= 0x037D) { return true }
        if (cp >= 0x037F && cp <= 0x037F) { return true }
        if (cp >= 0x0386 && cp <= 0x0386) { return true }
        if (cp >= 0x0388 && cp <= 0x038A) { return true }
        if (cp >= 0x038C && cp <= 0x038C) { return true }
        if (cp >= 0x038E && cp <= 0x03A1) { return true }
        if (cp >= 0x03A3 && cp <= 0x03F5) { return true }
        if (cp >= 0x03F7 && cp <= 0x0481) { return true }
        if (cp >= 0x048A && cp <= 0x052F) { return true }
        if (cp >= 0x0531 && cp <= 0x0556) { return true }
        if (cp >= 0x0559 && cp <= 0x0559) { return true }
        if (cp >= 0x0561 && cp <= 0x0587) { return true }
        // Cyrillic
        if (cp >= 0x0410 && cp <= 0x044F) { return true }
        // Armenian
        if (cp >= 0x0531 && cp <= 0x0556) { return true }
        if (cp >= 0x0561 && cp <= 0x0587) { return true }
        // Hebrew
        if (cp >= 0x05B0 && cp <= 0x05BD) { return true }
        if (cp >= 0x05D0 && cp <= 0x05EA) { return true }
        // Arabic
        if (cp >= 0x0621 && cp <= 0x0657) { return true }
        if (cp >= 0x066E && cp <= 0x06D3) { return true }
        // Devanagari
        if (cp >= 0x0901 && cp <= 0x0939) { return true }
        // CJK
        if (cp >= 0x4E00 && cp <= 0x9FFF) { return true }
        // Hiragana
        if (cp >= 0x3041 && cp <= 0x3096) { return true }
        // Katakana
        if (cp >= 0x30A1 && cp <= 0x30FA) { return true }
        // Hangul
        if (cp >= 0xAC00 && cp <= 0xD7A3) { return true }
        // CJK Extension A
        if (cp >= 0x3400 && cp <= 0x4DBF) { return true }
        // CJK Extensions B..I
        if (cp >= 0x20000 && cp <= 0x2A6DF) { return true }
        if (cp >= 0x2A700 && cp <= 0x2B73F) { return true }
        if (cp >= 0x2B740 && cp <= 0x2B81F) { return true }
        if (cp >= 0x2B820 && cp <= 0x2CEAF) { return true }
        // 其他 Unicode 字母
        if (cp >= 0x1F00 && cp <= 0x1F15) { return true }
        if (cp >= 0x1F18 && cp <= 0x1F1D) { return true }
        if (cp >= 0x1F20 && cp <= 0x1F45) { return true }
        if (cp >= 0x1F48 && cp <= 0x1F4D) { return true }
        if (cp >= 0x1F50 && cp <= 0x1F57) { return true }
        if (cp >= 0x1F59 && cp <= 0x1F59) { return true }
        if (cp >= 0x1F5B && cp <= 0x1F5B) { return true }
        if (cp >= 0x1F5D && cp <= 0x1F5D) { return true }
        if (cp >= 0x1F5F && cp <= 0x1F7D) { return true }
        if (cp >= 0x1F80 && cp <= 0x1FB4) { return true }
        if (cp >= 0x1FB6 && cp <= 0x1FBC) { return true }
        // Superscripts
        if (cp >= 0x207F && cp <= 0x207F) { return true }
        // Subscripts
        if (cp >= 0x2090 && cp <= 0x209C) { return true }
        // Letterlike Symbols
        if (cp >= 0x2102 && cp <= 0x2102) { return true }
        if (cp >= 0x2107 && cp <= 0x2107) { return true }
        if (cp >= 0x210A && cp <= 0x2113) { return true }
        if (cp >= 0x2115 && cp <= 0x2115) { return true }
        if (cp >= 0x2119 && cp <= 0x211D) { return true }
        if (cp >= 0x2124 && cp <= 0x2124) { return true }
        if (cp >= 0x2126 && cp <= 0x2126) { return true }
        if (cp >= 0x2128 && cp <= 0x2128) { return true }
        if (cp >= 0x212A && cp <= 0x212D) { return true }
        if (cp >= 0x212F && cp <= 0x2139) { return true }
        if (cp >= 0x213C && cp <= 0x213F) { return true }
        if (cp >= 0x2145 && cp <= 0x2149) { return true }
        if (cp >= 0x214E && cp <= 0x214E) { return true }
        // Other ID_Start
        if (cp >= 0x1885 && cp <= 0x1886) { return true }
        if (cp >= 0x2118 && cp <= 0x2118) { return true }
        if (cp >= 0x212E && cp <= 0x212E) { return true }
        if (cp >= 0x309B && cp <= 0x309C) { return true }
        // Pattern Syntax excluded characters that are ID_Start
        if (cp == 0x00AA) { return true }
        if (cp == 0x00B5) { return true }
        if (cp == 0x00B7) { return true }
        if (cp == 0x00BA) { return true }
        return false
    }

    /// 检查是否为 ES Next ID_Continue - 对应 Bun is_id_continue_es_next
    /// ID_Continue = ID_Start + Mn + Mc + Nd + Pc + 其他
    private static func isIdContinueEsNext(cp: UInt32): Bool {
        // 先检查 ID_Start
        if (isIdStartEsNext(cp)) { return true }
        // 数字 0-9 (Nd)
        if (cp >= 0x0030 && cp <= 0x0039) { return true }
        // 组合标记 (Mn, Mc)
        if (cp >= 0x0300 && cp <= 0x036F) { return true }
        if (cp >= 0x0483 && cp <= 0x0487) { return true }
        if (cp >= 0x0591 && cp <= 0x05BD) { return true }
        if (cp >= 0x05BF && cp <= 0x05BF) { return true }
        if (cp >= 0x05C1 && cp <= 0x05C2) { return true }
        if (cp >= 0x05C4 && cp <= 0x05C5) { return true }
        if (cp >= 0x05C7 && cp <= 0x05C7) { return true }
        if (cp >= 0x0610 && cp <= 0x061A) { return true }
        if (cp >= 0x064B && cp <= 0x065F) { return true }
        if (cp >= 0x0670 && cp <= 0x0670) { return true }
        if (cp >= 0x06D6 && cp <= 0x06DC) { return true }
        if (cp >= 0x06DF && cp <= 0x06E4) { return true }
        if (cp >= 0x06E7 && cp <= 0x06E8) { return true }
        if (cp >= 0x06EA && cp <= 0x06ED) { return true }
        // 连接标点 (Pc)
        if (cp == 0x005F) { return true }   // _
        if (cp == 0x203F) { return true }   // ‿
        if (cp == 0x2040) { return true }   // ⁀
        if (cp == 0x2054) { return true }   // ⁔
        if (cp == 0xFE33) { return true }   // ︳
        if (cp == 0xFE34) { return true }   // ︴
        if (cp == 0xFE4D) { return true }   // ﹍
        if (cp == 0xFE4E) { return true }   // ﹎
        if (cp == 0xFE4F) { return true }   // ﹏
        if (cp == 0xFF3F) { return true }   // ＿
        // 阿拉伯-印度数字
        if (cp >= 0x0660 && cp <= 0x0669) { return true }
        // Devanagari 数字
        if (cp >= 0x0966 && cp <= 0x096F) { return true }
        // 全角数字
        if (cp >= 0xFF10 && cp <= 0xFF19) { return true }
        // ZWNJ and ZWJ
        if (cp == 0x200C) { return true }
        if (cp == 0x200D) { return true }
        // 其他数字
        if (cp >= 0x06F0 && cp <= 0x06F9) { return true }
        if (cp >= 0x07C0 && cp <= 0x07C9) { return true }
        if (cp >= 0x09E6 && cp <= 0x09EF) { return true }
        if (cp >= 0x0A66 && cp <= 0x0A6F) { return true }
        if (cp >= 0x0AE6 && cp <= 0x0AEF) { return true }
        if (cp >= 0x0B66 && cp <= 0x0B6F) { return true }
        if (cp >= 0x0BE6 && cp <= 0x0BEF) { return true }
        if (cp >= 0x0C66 && cp <= 0x0C6F) { return true }
        if (cp >= 0x0CE6 && cp <= 0x0CEF) { return true }
        if (cp >= 0x0D66 && cp <= 0x0D6F) { return true }
        if (cp >= 0x0DE6 && cp <= 0x0DEF) { return true }
        if (cp >= 0x0E50 && cp <= 0x0E59) { return true }
        if (cp >= 0x0ED0 && cp <= 0x0ED9) { return true }
        if (cp >= 0x0F20 && cp <= 0x0F29) { return true }
        return false
    }
}
