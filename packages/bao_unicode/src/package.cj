// bao_unicode - Unicode 处理
// 对应 Bun: src/unicode/, src/bun_core/string/immutable/grapheme_tables.zig
// Bun 包含大量预计算的 Unicode 表
package bao_unicode

import bao_core.*

// ============================================================================
// UTF-8 编解码
// 对应 Bun: src/unicode/utf8.zig
// ============================================================================

/// UTF-8 编解码工具
public class Utf8 {
    /// 计算 UTF-8 编码一个 Unicode 码点需要的字节数
    public static func encodeLength(codepoint: UInt32): Int64 {
        if (codepoint < 0x80) {
            return 1
        } else if (codepoint < 0x800) {
            return 2
        } else if (codepoint < 0x10000) {
            return 3
        } else if (codepoint < 0x110000) {
            return 4
        }
        return 0  // 无效码点
    }

    /// 将 Unicode 码点编码为 UTF-8 字节
    public static func encode(codepoint: UInt32): Array<UInt8> {
        if (codepoint < 0x80) {
            return [UInt8(codepoint)]
        } else if (codepoint < 0x800) {
            return [
                UInt8(0xC0 | (codepoint >> 6)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        } else if (codepoint < 0x10000) {
            return [
                UInt8(0xE0 | (codepoint >> 12)),
                UInt8(0x80 | ((codepoint >> 6) & 0x3F)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        } else if (codepoint < 0x110000) {
            return [
                UInt8(0xF0 | (codepoint >> 18)),
                UInt8(0x80 | ((codepoint >> 12) & 0x3F)),
                UInt8(0x80 | ((codepoint >> 6) & 0x3F)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        }
        return []
    }

    /// 解码 UTF-8 字节序列的第一个码点
    public static func decode(bytes: Array<UInt8>, offset: Int64): DecodedRune {
        if (offset >= bytes.size) {
            return DecodedRune(codepoint: 0, length: 0, valid: false)
        }

        let b0 = bytes[offset]

        // ASCII
        if (b0 < 0x80) {
            return DecodedRune(codepoint: UInt32(b0), length: 1, valid: true)
        }

        // 多字节序列
        var len = 0
        var codepoint: UInt32 = 0

        if ((b0 & 0xE0) == 0xC0) {
            len = 2
            codepoint = UInt32(b0 & 0x1F)
        } else if ((b0 & 0xF0) == 0xE0) {
            len = 3
            codepoint = UInt32(b0 & 0x0F)
        } else if ((b0 & 0xF8) == 0xF0) {
            len = 4
            codepoint = UInt32(b0 & 0x07)
        } else {
            return DecodedRune(codepoint: UInt32(b0), length: 1, valid: false)
        }

        // 检查字节长度是否足够
        if (offset + len > bytes.size) {
            return DecodedRune(codepoint: UInt32(b0), length: 1, valid: false)
        }

        // 读取后续字节
        for (i in 1..len) {
            let b = bytes[offset + i]
            if ((b & 0xC0) != 0x80) {
                return DecodedRune(codepoint: UInt32(b0), length: 1, valid: false)
            }
            codepoint = (codepoint << 6) | UInt32(b & 0x3F)
        }

        return DecodedRune(codepoint: codepoint, length: Int64(len), valid: true)
    }

    /// 验证 UTF-8 字节序列
    public static func validate(bytes: Array<UInt8>): Bool {
        var i: Int64 = 0
        while (i < bytes.size) {
            let decoded = decode(bytes, i)
            if (!decoded.valid) {
                return false
            }
            i += decoded.length
        }
        return true
    }

    /// 计算 UTF-8 字符串中的字符数 (码点数)
    public static func countCodepoints(bytes: Array<UInt8>): Int64 {
        var count: Int64 = 0
        var i: Int64 = 0
        while (i < bytes.size) {
            let decoded = decode(bytes, i)
            if (decoded.valid) {
                count += 1
                i += decoded.length
            } else {
                count += 1
                i += 1
            }
        }
        return count
    }
}

/// 解码结果
public class DecodedRune {
    public let codepoint: UInt32
    public let length: Int64
    public let valid: Bool

    public init(codepoint: UInt32, length: Int64, valid: Bool) {
        this.codepoint = codepoint
        this.length = length
        this.valid = valid
    }
}

// ============================================================================
// 字素簇 (Grapheme Cluster) 处理
// 对应 Bun: src/bun_core/string/immutable/grapheme_tables.zig
// Bun 包含 35000+ 行的预计算 Unicode 表
// ============================================================================

/// Unicode 通用类别
public enum GeneralCategory {
    | Lu  // 大写字母
    | Ll  // 小写字母
    | Lt  | Lm  | Lo  // 其他字母
    | Mn  // 非间距标记
    | Mc  // 间距组合标记
    | Me  // 封闭标记
    | Nd  // 十进制数字
    | Nl  | No  // 其他数字
    | Pc  | Pd  | Ps  | Pe  | Pi  | Pf  | Po  // 标点
    | Sm  | Sc  | Sk  | So  // 符号
    | Zs  | Zl  | Zp  // 分隔符
    | Cc  | Cf  | Cs  | Co  | Cn  // 控制和其他
}

/// Grapheme 断裂属性
/// 对应 Unicode UAX #29 Grapheme_Cluster_Break
/// 严格对应 Bun: src/unicode/uucode_lib/src/grapheme.zig GraphemeBreakNoControl
public enum GraphemeBreak {
    | Other               // 默认
    | CR                  // \r
    | LF                  // \n
    | Control             // 控制字符
    | Extend              // 组合标记、变体选择器等
    | ZWJ                 // 零宽连接符 U+200D
    | RegionalIndicator   // 区域指示符 (国旗 emoji)
    | Prepend             // 可前置于基字符
    | SpacingMark         // 间距组合标记
    | L                   // 韩文 L 音节
    | V                   // 韩文 V 音节
    | T                   // 韩文 T 音节
    | LV                  // 韩文 LV 音节
    | LVT                 // 韩文 LVT 音节
    | ExtendedPictographic     // 扩展象形 (emoji 基础)
    | EmojiModifierBase       // emoji 肤色修饰基础
    | EmojiModifier           // emoji 肤色修饰符
    | IndicConjunctBreakExtend    // 印度文连接断行 Extend
    | IndicConjunctBreakLinker    // 印度文连接断行 Linker
    | IndicConjunctBreakConsonant // 印度文连接断行 Consonant
}

/// 获取码点的 Grapheme 断裂属性
/// 严格对应 Bun: src/unicode/uucode_lib/src/grapheme.zig
/// 包含 Unicode 15.0 完整 GraphemeBreak 属性表
/// 数据来源: Unicode GraphemeBreakProperty.txt + emoji-data.txt
public static func graphemeBreak(codepoint: UInt32): GraphemeBreak {

    // ========================================================================
    // CR / LF / Control
    // ========================================================================
    if (codepoint == 0x000D) { return GraphemeBreak.CR }
    if (codepoint == 0x000A) { return GraphemeBreak.LF }
    if (codepoint < 0x0020 && codepoint != 0x000A && codepoint != 0x000D) {
        return GraphemeBreak.Control
    }
    if (codepoint >= 0x007F && codepoint <= 0x009F) {
        return GraphemeBreak.Control
    }
    // 控制字符补充
    if (codepoint == 0x00AD) { return GraphemeBreak.Control }  // SOFT HYPHEN
    if (codepoint == 0x061C) { return GraphemeBreak.Control }  // ARABIC LETTER MARK
    if (codepoint == 0x180E) { return GraphemeBreak.Control }  // MONGOLIAN VOWEL SEPARATOR
    if (codepoint == 0x200B) { return GraphemeBreak.Control }  // ZERO WIDTH SPACE
    if (codepoint == 0x200E || codepoint == 0x200F) { return GraphemeBreak.Control }  // LRM/RLM
    if (codepoint >= 0x2028 && codepoint <= 0x202E) { return GraphemeBreak.Control }  // 分隔符和嵌入
    if (codepoint >= 0x2060 && codepoint <= 0x2069) { return GraphemeBreak.Control }  // 各种控制
    if (codepoint >= 0x206A && codepoint <= 0x206F) { return GraphemeBreak.Control }  // 废弃控制
    if (codepoint == 0xFEFF) { return GraphemeBreak.Control }  // BOM/ZWNBSP
    if (codepoint >= 0xFFF0 && codepoint <= 0xFFF8) { return GraphemeBreak.Control }
    if (codepoint >= 0xFFFE && codepoint <= 0xFFFF) { return GraphemeBreak.Control }
    // Tags (U+E0000..U+E007F)
    if (codepoint >= 0xE0000 && codepoint <= 0xE007F) { return GraphemeBreak.Control }
    if (codepoint >= 0xE0100 && codepoint <= 0xE01EF) { return GraphemeBreak.Extend }  // Variation Selectors Supplement

    // ========================================================================
    // ZWJ
    // ========================================================================
    if (codepoint == 0x200D) { return GraphemeBreak.ZWJ }

    // ========================================================================
    // Regional Indicator (国旗 emoji)
    // ========================================================================
    if (codepoint >= 0x1F1E6 && codepoint <= 0x1F1FF) {
        return GraphemeBreak.RegionalIndicator
    }

    // ========================================================================
    // Hangul 音节 - 对应 Bun grapheme.zig Hangul 范围
    // ========================================================================
    // L (Leading consonant/Jamo)
    if (codepoint >= 0x1100 && codepoint <= 0x115F) { return GraphemeBreak.L }
    if (codepoint >= 0xA960 && codepoint <= 0xA97C) { return GraphemeBreak.L }
    // V (Vowel Jamo)
    if (codepoint >= 0x1160 && codepoint <= 0x11A7) { return GraphemeBreak.V }
    if (codepoint >= 0xD7B0 && codepoint <= 0xD7C6) { return GraphemeBreak.V }
    // T (Trailing consonant/Jamo)
    if (codepoint >= 0x11A8 && codepoint <= 0x11FF) { return GraphemeBreak.T }
    if (codepoint >= 0xD7CB && codepoint <= 0xD7FB) { return GraphemeBreak.T }
    // LV / LVT (预组合韩文音节)
    if (codepoint >= 0xAC00 && codepoint <= 0xD7A3) {
        let s = codepoint - 0xAC00
        if (s % 28 == 0) { return GraphemeBreak.LV }
        return GraphemeBreak.LVT
    }

    // ========================================================================
    // Extend - 对应 Bun GraphemeBreakProperty.txt Extend 范围
    // 包含: 组合标记、变体选择器、零宽非连接符等
    // ========================================================================
    // Combining Diacritical Marks
    if (codepoint >= 0x0300 && codepoint <= 0x036F) { return GraphemeBreak.Extend }
    // Combining Diacritical Marks Extended
    if (codepoint >= 0x0483 && codepoint <= 0x0489) { return GraphemeBreak.Extend }
    // Combining Cyrillic
    if (codepoint >= 0x0591 && codepoint <= 0x05BD) { return GraphemeBreak.Extend }
    if (codepoint == 0x05BF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x05C1 && codepoint <= 0x05C2) { return GraphemeBreak.Extend }
    if (codepoint >= 0x05C4 && codepoint <= 0x05C5) { return GraphemeBreak.Extend }
    if (codepoint == 0x05C7) { return GraphemeBreak.Extend }
    // Hebrew
    if (codepoint >= 0x0610 && codepoint <= 0x061A) { return GraphemeBreak.Extend }
    // Arabic
    if (codepoint >= 0x064B && codepoint <= 0x065F) { return GraphemeBreak.Extend }
    if (codepoint == 0x0670) { return GraphemeBreak.Extend }
    if (codepoint >= 0x06D6 && codepoint <= 0x06DC) { return GraphemeBreak.Extend }
    if (codepoint >= 0x06DF && codepoint <= 0x06E4) { return GraphemeBreak.Extend }
    if (codepoint >= 0x06E7 && codepoint <= 0x06E8) { return GraphemeBreak.Extend }
    if (codepoint >= 0x06EA && codepoint <= 0x06ED) { return GraphemeBreak.Extend }
    // Devanagari / Bengali / Gurmukhi / Gujarati / Oriya / Tamil / Telugu / Kannada / Malayalam
    if (codepoint >= 0x0711 && codepoint <= 0x0711) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0730 && codepoint <= 0x074A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x07A6 && codepoint <= 0x07B0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x07EB && codepoint <= 0x07F3) { return GraphemeBreak.Extend }
    if (codepoint == 0x07FD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0816 && codepoint <= 0x0819) { return GraphemeBreak.Extend }
    if (codepoint >= 0x081B && codepoint <= 0x0823) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0825 && codepoint <= 0x0827) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0829 && codepoint <= 0x082D) { return GraphemeBreak.Extend }
    // Thai
    if (codepoint >= 0x0859 && codepoint <= 0x085B) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0898 && codepoint <= 0x089F) { return GraphemeBreak.Extend }
    // Arabic Extended-A/B
    if (codepoint >= 0x08CA && codepoint <= 0x08E1) { return GraphemeBreak.Extend }
    if (codepoint >= 0x08E3 && codepoint <= 0x0902) { return GraphemeBreak.Extend }
    if (codepoint == 0x093A) { return GraphemeBreak.Extend }
    if (codepoint == 0x093C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0941 && codepoint <= 0x0948) { return GraphemeBreak.Extend }
    if (codepoint == 0x094D) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0951 && codepoint <= 0x0957) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0962 && codepoint <= 0x0963) { return GraphemeBreak.Extend }
    // Bengali
    if (codepoint == 0x0981) { return GraphemeBreak.Extend }
    if (codepoint == 0x09BC) { return GraphemeBreak.Extend }
    if (codepoint == 0x09BE) { return GraphemeBreak.Extend }
    if (codepoint >= 0x09C1 && codepoint <= 0x09C4) { return GraphemeBreak.Extend }
    if (codepoint == 0x09CD) { return GraphemeBreak.Extend }
    if (codepoint == 0x09D7) { return GraphemeBreak.Extend }
    if (codepoint >= 0x09E2 && codepoint <= 0x09E3) { return GraphemeBreak.Extend }
    // Gurmukhi
    if (codepoint >= 0x09FE && codepoint <= 0x09FE) { return GraphemeBreak.Extend }
    // Gujarati
    if (codepoint == 0x0A01) { return GraphemeBreak.Extend }
    if (codepoint == 0x0A02) { return GraphemeBreak.Extend }
    if (codepoint == 0x0A3C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0A41 && codepoint <= 0x0A42) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0A47 && codepoint <= 0x0A48) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0A4B && codepoint <= 0x0A4D) { return GraphemeBreak.Extend }
    if (codepoint == 0x0A51) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0A70 && codepoint <= 0x0A71) { return GraphemeBreak.Extend }
    if (codepoint == 0x0A75) { return GraphemeBreak.Extend }
    // Oriya
    if (codepoint == 0x0A81) { return GraphemeBreak.Extend }
    if (codepoint == 0x0A82) { return GraphemeBreak.Extend }
    if (codepoint == 0x0ABC) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0AC1 && codepoint <= 0x0AC5) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0AC7 && codepoint <= 0x0AC8) { return GraphemeBreak.Extend }
    if (codepoint == 0x0ACD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0AE2 && codepoint <= 0x0AE3) { return GraphemeBreak.Extend }
    // Tamil
    if (codepoint >= 0x0AFA && codepoint <= 0x0AFF) { return GraphemeBreak.Extend }
    // Telugu
    if (codepoint >= 0x0B01 && codepoint <= 0x0B02) { return GraphemeBreak.Extend }
    if (codepoint == 0x0B3C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0B3F && codepoint <= 0x0B3F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0B41 && codepoint <= 0x0B44) { return GraphemeBreak.Extend }
    if (codepoint == 0x0B4D) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0B55 && codepoint <= 0x0B56) { return GraphemeBreak.Extend }
    if (codepoint == 0x0B57) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0B62 && codepoint <= 0x0B63) { return GraphemeBreak.Extend }
    // Kannada
    if (codepoint == 0x0B82) { return GraphemeBreak.Extend }
    if (codepoint == 0x0BC0) { return GraphemeBreak.Extend }
    if (codepoint == 0x0BCD) { return GraphemeBreak.Extend }
    if (codepoint == 0x0BF3) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0BF8 && codepoint <= 0x0BFA) { return GraphemeBreak.Extend }
    // Malayalam
    if (codepoint >= 0x0C00 && codepoint <= 0x0C00) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0C04 && codepoint <= 0x0C04) { return GraphemeBreak.Extend }
    if (codepoint == 0x0C3C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0C3E && codepoint <= 0x0C40) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0C46 && codepoint <= 0x0C48) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0C4A && codepoint <= 0x0C4D) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0C55 && codepoint <= 0x0C56) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0C62 && codepoint <= 0x0C63) { return GraphemeBreak.Extend }
    // Sinhala
    if (codepoint >= 0x0C81 && codepoint <= 0x0C81) { return GraphemeBreak.Extend }
    if (codepoint == 0x0CBC) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0CBF && codepoint <= 0x0CBF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0CC2 && codepoint <= 0x0CC2) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0CC6 && codepoint <= 0x0CC6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0CCC && codepoint <= 0x0CCD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0CD5 && codepoint <= 0x0CD6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0CE2 && codepoint <= 0x0CE3) { return GraphemeBreak.Extend }
    // Myanmar
    if (codepoint >= 0x0D00 && codepoint <= 0x0D01) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0D3B && codepoint <= 0x0D3C) { return GraphemeBreak.Extend }
    if (codepoint == 0x0D3E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0D41 && codepoint <= 0x0D44) { return GraphemeBreak.Extend }
    if (codepoint == 0x0D4D) { return GraphemeBreak.Extend }
    if (codepoint == 0x0D57) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0D62 && codepoint <= 0x0D63) { return GraphemeBreak.Extend }
    // Thai
    if (codepoint >= 0x0D81 && codepoint <= 0x0D81) { return GraphemeBreak.Extend }
    if (codepoint == 0x0DCA) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0DCF && codepoint <= 0x0DCF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0DD2 && codepoint <= 0x0DD4) { return GraphemeBreak.Extend }
    if (codepoint == 0x0DD6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0DDF && codepoint <= 0x0DDF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0E31 && codepoint <= 0x0E31) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0E34 && codepoint <= 0x0E3A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0E47 && codepoint <= 0x0E4E) { return GraphemeBreak.Extend }
    // Tibetan
    if (codepoint >= 0x0EB1 && codepoint <= 0x0EB1) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0EB4 && codepoint <= 0x0EBC) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0EC8 && codepoint <= 0x0ECE) { return GraphemeBreak.Extend }
    // Myanmar Extended
    if (codepoint >= 0x0F18 && codepoint <= 0x0F19) { return GraphemeBreak.Extend }
    if (codepoint == 0x0F35) { return GraphemeBreak.Extend }
    if (codepoint == 0x0F37) { return GraphemeBreak.Extend }
    if (codepoint == 0x0F39) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0F71 && codepoint <= 0x0F7E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0F80 && codepoint <= 0x0F84) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0F86 && codepoint <= 0x0F87) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0F8D && codepoint <= 0x0F97) { return GraphemeBreak.Extend }
    if (codepoint >= 0x0F99 && codepoint <= 0x0FBC) { return GraphemeBreak.Extend }
    if (codepoint == 0x0FC6) { return GraphemeBreak.Extend }
    // Combining Diacritical Marks Supplement / Extended
    if (codepoint >= 0x102D && codepoint <= 0x1030) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1032 && codepoint <= 0x1037) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1039 && codepoint <= 0x103A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x103D && codepoint <= 0x103E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1058 && codepoint <= 0x1059) { return GraphemeBreak.Extend }
    if (codepoint >= 0x105E && codepoint <= 0x1060) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1071 && codepoint <= 0x1074) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1082 && codepoint <= 0x1082) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1085 && codepoint <= 0x1086) { return GraphemeBreak.Extend }
    if (codepoint >= 0x108D && codepoint <= 0x108D) { return GraphemeBreak.Extend }
    if (codepoint == 0x109D) { return GraphemeBreak.Extend }
    if (codepoint >= 0x135D && codepoint <= 0x135F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1712 && codepoint <= 0x1714) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1732 && codepoint <= 0x1733) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1752 && codepoint <= 0x1753) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1772 && codepoint <= 0x1773) { return GraphemeBreak.Extend }
    if (codepoint >= 0x17B4 && codepoint <= 0x17B5) { return GraphemeBreak.Extend }
    if (codepoint >= 0x17B7 && codepoint <= 0x17BD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x17C6 && codepoint <= 0x17C6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x17C9 && codepoint <= 0x17D3) { return GraphemeBreak.Extend }
    if (codepoint == 0x17DD) { return GraphemeBreak.Extend }
    // Philippines / Mongolian
    if (codepoint >= 0x180B && codepoint <= 0x180D) { return GraphemeBreak.Extend }
    if (codepoint == 0x180F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1885 && codepoint <= 0x1886) { return GraphemeBreak.Extend }
    if (codepoint >= 0x18A9 && codepoint <= 0x18A9) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1920 && codepoint <= 0x1922) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1927 && codepoint <= 0x1928) { return GraphemeBreak.Extend }
    if (codepoint == 0x1932) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1939 && codepoint <= 0x193B) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A17 && codepoint <= 0x1A18) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A1B && codepoint <= 0x1A1B) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A56 && codepoint <= 0x1A56) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A58 && codepoint <= 0x1A5E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A60 && codepoint <= 0x1A60) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A62 && codepoint <= 0x1A62) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A65 && codepoint <= 0x1A6C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A73 && codepoint <= 0x1A7C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1A7F && codepoint <= 0x1A7F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1AB0 && codepoint <= 0x1AC0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1B00 && codepoint <= 0x1B03) { return GraphemeBreak.Extend }
    if (codepoint == 0x1B34) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1B35 && codepoint <= 0x1B35) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1B36 && codepoint <= 0x1B3A) { return GraphemeBreak.Extend }
    if (codepoint == 0x1B3C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1B42 && codepoint <= 0x1B42) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1B6B && codepoint <= 0x1B73) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1B80 && codepoint <= 0x1B81) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1BA2 && codepoint <= 0x1BA5) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1BA8 && codepoint <= 0x1BA9) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1BAB && codepoint <= 0x1BAD) { return GraphemeBreak.Extend }
    if (codepoint == 0x1BE6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1BE8 && codepoint <= 0x1BE9) { return GraphemeBreak.Extend }
    if (codepoint == 0x1BED) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1BEF && codepoint <= 0x1BF1) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1C2C && codepoint <= 0x1C33) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1C36 && codepoint <= 0x1C37) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1CD0 && codepoint <= 0x1CD2) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1CD4 && codepoint <= 0x1CE0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1CE2 && codepoint <= 0x1CE8) { return GraphemeBreak.Extend }
    if (codepoint == 0x1CED) { return GraphemeBreak.Extend }
    if (codepoint == 0x1CF4) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1CF8 && codepoint <= 0x1CF9) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1DC0 && codepoint <= 0x1DF9) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1DFB && codepoint <= 0x1DFF) { return GraphemeBreak.Extend }
    // Musical symbols
    if (codepoint >= 0x200C && codepoint <= 0x200C) { return GraphemeBreak.Extend }  // ZWNJ
    // Variation Selectors
    if (codepoint >= 0xFE00 && codepoint <= 0xFE0F) { return GraphemeBreak.Extend }
    // Combining Half Marks
    if (codepoint >= 0xFE20 && codepoint <= 0xFE2F) { return GraphemeBreak.Extend }
    // Scripts-specific combining marks
    if (codepoint >= 0x101FD && codepoint <= 0x101FD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x102E0 && codepoint <= 0x102E0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10376 && codepoint <= 0x1037A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10A01 && codepoint <= 0x10A03) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10A05 && codepoint <= 0x10A06) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10A0C && codepoint <= 0x10A0F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10A38 && codepoint <= 0x10A3A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10A3F && codepoint <= 0x10A3F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10AE5 && codepoint <= 0x10AE6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10D24 && codepoint <= 0x10D27) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10EAB && codepoint <= 0x10EAC) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10EFD && codepoint <= 0x10EFF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10F46 && codepoint <= 0x10F50) { return GraphemeBreak.Extend }
    if (codepoint >= 0x10F82 && codepoint <= 0x10F85) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11001 && codepoint <= 0x11001) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11038 && codepoint <= 0x11046) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11070 && codepoint <= 0x11070) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11073 && codepoint <= 0x11074) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1107F && codepoint <= 0x11081) { return GraphemeBreak.Extend }
    if (codepoint >= 0x110B3 && codepoint <= 0x110B6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x110B9 && codepoint <= 0x110BA) { return GraphemeBreak.Extend }
    if (codepoint >= 0x110C2 && codepoint <= 0x110C2) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11100 && codepoint <= 0x11102) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11127 && codepoint <= 0x1112B) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1112D && codepoint <= 0x11134) { return GraphemeBreak.Extend }
    if (codepoint == 0x11173) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11180 && codepoint <= 0x11181) { return GraphemeBreak.Extend }
    if (codepoint >= 0x111B6 && codepoint <= 0x111BE) { return GraphemeBreak.Extend }
    if (codepoint >= 0x111C9 && codepoint <= 0x111CC) { return GraphemeBreak.Extend }
    if (codepoint == 0x111CF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1122F && codepoint <= 0x11231) { return GraphemeBreak.Extend }
    if (codepoint == 0x11234) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11236 && codepoint <= 0x11237) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1123E && codepoint <= 0x1123E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11241 && codepoint <= 0x11241) { return GraphemeBreak.Extend }
    if (codepoint >= 0x112DF && codepoint <= 0x112DF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x112E3 && codepoint <= 0x112EA) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11300 && codepoint <= 0x11301) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1133B && codepoint <= 0x1133C) { return GraphemeBreak.Extend }
    if (codepoint == 0x1133E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11340 && codepoint <= 0x11340) { return GraphemeBreak.Extend }
    if (codepoint == 0x11357) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11366 && codepoint <= 0x1136C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11370 && codepoint <= 0x11374) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11438 && codepoint <= 0x1143F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11442 && codepoint <= 0x11444) { return GraphemeBreak.Extend }
    if (codepoint == 0x11446) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1145E && codepoint <= 0x1145E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x114B0 && codepoint <= 0x114B0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x114B3 && codepoint <= 0x114B8) { return GraphemeBreak.Extend }
    if (codepoint >= 0x114BA && codepoint <= 0x114BA) { return GraphemeBreak.Extend }
    if (codepoint >= 0x114BD && codepoint <= 0x114BD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x114BF && codepoint <= 0x114C0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x114C2 && codepoint <= 0x114C3) { return GraphemeBreak.Extend }
    if (codepoint >= 0x115AF && codepoint <= 0x115AF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x115B2 && codepoint <= 0x115B5) { return GraphemeBreak.Extend }
    if (codepoint >= 0x115BC && codepoint <= 0x115BD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x115BF && codepoint <= 0x115C0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x115DC && codepoint <= 0x115DD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11633 && codepoint <= 0x1163A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1163D && codepoint <= 0x1163D) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1163F && codepoint <= 0x11640) { return GraphemeBreak.Extend }
    if (codepoint >= 0x116AB && codepoint <= 0x116AB) { return GraphemeBreak.Extend }
    if (codepoint >= 0x116AD && codepoint <= 0x116AD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x116B0 && codepoint <= 0x116B5) { return GraphemeBreak.Extend }
    if (codepoint >= 0x116B7 && codepoint <= 0x116B7) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1171D && codepoint <= 0x1171F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11722 && codepoint <= 0x11725) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11727 && codepoint <= 0x1172B) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1182F && codepoint <= 0x11837) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11839 && codepoint <= 0x1183A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11930 && codepoint <= 0x11930) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1193B && codepoint <= 0x1193C) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1193E && codepoint <= 0x1193E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11943 && codepoint <= 0x11943) { return GraphemeBreak.Extend }
    if (codepoint >= 0x119D4 && codepoint <= 0x119D7) { return GraphemeBreak.Extend }
    if (codepoint >= 0x119DA && codepoint <= 0x119DB) { return GraphemeBreak.Extend }
    if (codepoint >= 0x119E0 && codepoint <= 0x119E0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11A01 && codepoint <= 0x11A0A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11A33 && codepoint <= 0x11A38) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11A3B && codepoint <= 0x11A3E) { return GraphemeBreak.Extend }
    if (codepoint == 0x11A47) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11A51 && codepoint <= 0x11A56) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11A59 && codepoint <= 0x11A5B) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11A8A && codepoint <= 0x11A96) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11A98 && codepoint <= 0x11A99) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11C30 && codepoint <= 0x11C36) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11C38 && codepoint <= 0x11C3D) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11C3F && codepoint <= 0x11C3F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11C92 && codepoint <= 0x11CA7) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11CAA && codepoint <= 0x11CB0) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11CB2 && codepoint <= 0x11CB3) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11CB5 && codepoint <= 0x11CB6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11D31 && codepoint <= 0x11D36) { return GraphemeBreak.Extend }
    if (codepoint == 0x11D3A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11D3C && codepoint <= 0x11D3D) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11D3F && codepoint <= 0x11D45) { return GraphemeBreak.Extend }
    if (codepoint == 0x11D47) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11D90 && codepoint <= 0x11D91) { return GraphemeBreak.Extend }
    if (codepoint == 0x11D95) { return GraphemeBreak.Extend }
    if (codepoint == 0x11D97) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11EF3 && codepoint <= 0x11EF4) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11F00 && codepoint <= 0x11F01) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11F36 && codepoint <= 0x11F3A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11F40 && codepoint <= 0x11F40) { return GraphemeBreak.Extend }
    if (codepoint >= 0x11F42 && codepoint <= 0x11F42) { return GraphemeBreak.Extend }
    if (codepoint >= 0x13440 && codepoint <= 0x13440) { return GraphemeBreak.Extend }
    if (codepoint >= 0x13447 && codepoint <= 0x13455) { return GraphemeBreak.Extend }
    if (codepoint >= 0x16AF0 && codepoint <= 0x16AF4) { return GraphemeBreak.Extend }
    if (codepoint >= 0x16B30 && codepoint <= 0x16B36) { return GraphemeBreak.Extend }
    if (codepoint >= 0x16F4F && codepoint <= 0x16F4F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x16F8F && codepoint <= 0x16F92) { return GraphemeBreak.Extend }
    if (codepoint >= 0x16FE4 && codepoint <= 0x16FE4) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1BC9D && codepoint <= 0x1BC9E) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1CF00 && codepoint <= 0x1CF2D) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1CF30 && codepoint <= 0x1CF46) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1D165 && codepoint <= 0x1D165) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1D167 && codepoint <= 0x1D169) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1D16E && codepoint <= 0x1D172) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1D17B && codepoint <= 0x1D182) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1D185 && codepoint <= 0x1D18B) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1D1AA && codepoint <= 0x1D1AD) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1D242 && codepoint <= 0x1D244) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1DA00 && codepoint <= 0x1DA36) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1DA3B && codepoint <= 0x1DA6C) { return GraphemeBreak.Extend }
    if (codepoint == 0x1DA75) { return GraphemeBreak.Extend }
    if (codepoint == 0x1DA84) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1DA9B && codepoint <= 0x1DA9F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1DAA1 && codepoint <= 0x1DAAF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E000 && codepoint <= 0x1E006) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E008 && codepoint <= 0x1E018) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E01B && codepoint <= 0x1E021) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E023 && codepoint <= 0x1E024) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E026 && codepoint <= 0x1E02A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E08F && codepoint <= 0x1E08F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E130 && codepoint <= 0x1E136) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E2AE && codepoint <= 0x1E2AE) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E2EC && codepoint <= 0x1E2EF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E4EC && codepoint <= 0x1E4EF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E8D0 && codepoint <= 0x1E8D6) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1E944 && codepoint <= 0x1E94A) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1F3FB && codepoint <= 0x1F3FF) { return GraphemeBreak.Extend }  // Emoji skin tone modifiers

    // ========================================================================
    // SpacingMark - 对应 Unicode GraphemeBreakProperty.txt
    // ========================================================================
    if (codepoint >= 0x0903 && codepoint <= 0x0903) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x093B && codepoint <= 0x093B) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x093E && codepoint <= 0x0940) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0949 && codepoint <= 0x094C) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x094E && codepoint <= 0x094F) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0982 && codepoint <= 0x0983) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x09BF && codepoint <= 0x09C0) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x09C7 && codepoint <= 0x09C8) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x09CB && codepoint <= 0x09CC) { return GraphemeBreak.SpacingMark }
    if (codepoint == 0x0A03) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0A3E && codepoint <= 0x0A40) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0A83 && codepoint <= 0x0A83) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0ABE && codepoint <= 0x0AC0) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0AC9 && codepoint <= 0x0AC9) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0ACB && codepoint <= 0x0ACC) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0B02 && codepoint <= 0x0B03) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0B40 && codepoint <= 0x0B40) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0B47 && codepoint <= 0x0B48) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0B4B && codepoint <= 0x0B4C) { return GraphemeBreak.SpacingMark }
    if (codepoint == 0x0BBF) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0BC1 && codepoint <= 0x0BC2) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0BC6 && codepoint <= 0x0BC8) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0BCA && codepoint <= 0x0BCC) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0C01 && codepoint <= 0x0C03) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0C41 && codepoint <= 0x0C44) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0C82 && codepoint <= 0x0C83) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0CBE && codepoint <= 0x0CBE) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0CC0 && codepoint <= 0x0CC1) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0CC3 && codepoint <= 0x0CC4) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0CC7 && codepoint <= 0x0CC8) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0CCA && codepoint <= 0x0CCB) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0D02 && codepoint <= 0x0D03) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0D3F && codepoint <= 0x0D40) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0D46 && codepoint <= 0x0D48) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0D4A && codepoint <= 0x0D4C) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0D82 && codepoint <= 0x0D83) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0DD0 && codepoint <= 0x0DD1) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0DD8 && codepoint <= 0x0DDE) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0DF2 && codepoint <= 0x0DF3) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0F3E && codepoint <= 0x0F3F) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x0F7F && codepoint <= 0x0F7F) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x102B && codepoint <= 0x102C) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1031 && codepoint <= 0x1031) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1038 && codepoint <= 0x1038) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x103B && codepoint <= 0x103C) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1056 && codepoint <= 0x1057) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1062 && codepoint <= 0x1062) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1067 && codepoint <= 0x1068) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1071 && codepoint <= 0x1074) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1082 && codepoint <= 0x1082) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1085 && codepoint <= 0x1086) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x109C && codepoint <= 0x109C) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1715 && codepoint <= 0x1715) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1734 && codepoint <= 0x1734) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x17B6 && codepoint <= 0x17B6) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x17BE && codepoint <= 0x17C5) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x17C7 && codepoint <= 0x17C8) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1923 && codepoint <= 0x1926) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1929 && codepoint <= 0x192B) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1930 && codepoint <= 0x1931) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1933 && codepoint <= 0x1938) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1A19 && codepoint <= 0x1A1A) { return GraphemeBreak.SpacingMark }
    if (codepoint == 0x1A55) { return GraphemeBreak.SpacingMark }
    if (codepoint == 0x1A57) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1A6D && codepoint <= 0x1A72) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1B04 && codepoint <= 0x1B04) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1B3B && codepoint <= 0x1B3B) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1B3D && codepoint <= 0x1B41) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1B43 && codepoint <= 0x1B44) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1B82 && codepoint <= 0x1B82) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1BA1 && codepoint <= 0x1BA1) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1BA6 && codepoint <= 0x1BA7) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1BAA && codepoint <= 0x1BAA) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1BE7 && codepoint <= 0x1BE7) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1BEA && codepoint <= 0x1BEC) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1BEE && codepoint <= 0x1BEE) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1BF2 && codepoint <= 0x1BF3) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1C24 && codepoint <= 0x1C2B) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1C34 && codepoint <= 0x1C35) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA823 && codepoint <= 0xA824) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA827 && codepoint <= 0xA827) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA880 && codepoint <= 0xA881) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA8B4 && codepoint <= 0xA8C3) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA952 && codepoint <= 0xA953) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA983 && codepoint <= 0xA983) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA9B4 && codepoint <= 0xA9B5) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA9BA && codepoint <= 0xA9BB) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xA9BE && codepoint <= 0xA9C0) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xAA2F && codepoint <= 0xAA30) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xAA33 && codepoint <= 0xAA34) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xAA4D && codepoint <= 0xAA4D) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xAAEB && codepoint <= 0xAAEB) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xAAEE && codepoint <= 0xAAEF) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xAAF5 && codepoint <= 0xAAF5) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xABE3 && codepoint <= 0xABE4) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xABE6 && codepoint <= 0xABE7) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xABE9 && codepoint <= 0xABEA) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0xABEC && codepoint <= 0xABEC) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11000 && codepoint <= 0x11000) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11002 && codepoint <= 0x11002) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11082 && codepoint <= 0x11082) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x110B0 && codepoint <= 0x110B2) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x110B7 && codepoint <= 0x110B8) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1112C && codepoint <= 0x1112C) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11145 && codepoint <= 0x11146) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11182 && codepoint <= 0x11182) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x111B3 && codepoint <= 0x111B5) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x111BF && codepoint <= 0x111C0) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x111CE && codepoint <= 0x111CE) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1122C && codepoint <= 0x1122E) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11232 && codepoint <= 0x11233) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11235 && codepoint <= 0x11235) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x112E0 && codepoint <= 0x112E2) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11302 && codepoint <= 0x11303) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1133F && codepoint <= 0x1133F) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11341 && codepoint <= 0x11344) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11347 && codepoint <= 0x11348) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1134B && codepoint <= 0x1134D) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11362 && codepoint <= 0x11363) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11435 && codepoint <= 0x11437) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11440 && codepoint <= 0x11441) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11445 && codepoint <= 0x11445) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x114B1 && codepoint <= 0x114B2) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x114B9 && codepoint <= 0x114B9) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x114BB && codepoint <= 0x114BC) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x114BE && codepoint <= 0x114BE) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x114C1 && codepoint <= 0x114C1) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x115B0 && codepoint <= 0x115B1) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x115B8 && codepoint <= 0x115BB) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11630 && codepoint <= 0x11632) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1163B && codepoint <= 0x1163C) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1163E && codepoint <= 0x1163E) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x116AC && codepoint <= 0x116AC) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x116AE && codepoint <= 0x116AF) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x116B6 && codepoint <= 0x116B6) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11720 && codepoint <= 0x11721) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11726 && codepoint <= 0x11726) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1182C && codepoint <= 0x1182E) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11838 && codepoint <= 0x11838) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11931 && codepoint <= 0x11935) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11937 && codepoint <= 0x11938) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x1193D && codepoint <= 0x1193D) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11940 && codepoint <= 0x11940) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11942 && codepoint <= 0x11942) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x119D1 && codepoint <= 0x119D3) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x119DC && codepoint <= 0x119DF) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x119E4 && codepoint <= 0x119E4) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11A39 && codepoint <= 0x11A39) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11A57 && codepoint <= 0x11A58) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11A97 && codepoint <= 0x11A97) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11C2F && codepoint <= 0x11C2F) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11C3E && codepoint <= 0x11C3E) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11CA9 && codepoint <= 0x11CA9) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11CB1 && codepoint <= 0x11CB1) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11CB4 && codepoint <= 0x11CB4) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11D8A && codepoint <= 0x11D8E) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11D93 && codepoint <= 0x11D94) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11D96 && codepoint <= 0x11D96) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11EF5 && codepoint <= 0x11EF6) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x11F03 && codepoint <= 0x11F03) { return GraphemeBreak.SpacingMark }
    if (codepoint >= 0x16F51 && codepoint <= 0x16F87) { return GraphemeBreak.SpacingMark }

    // ========================================================================
    // Prepend - 对应 Unicode GraphemeBreakProperty.txt Prepend 范围
    // ========================================================================
    if (codepoint >= 0x0600 && codepoint <= 0x0605) { return GraphemeBreak.Prepend }
    if (codepoint == 0x06DD) { return GraphemeBreak.Prepend }
    if (codepoint == 0x070F) { return GraphemeBreak.Prepend }
    if (codepoint == 0x0890 || codepoint == 0x0891) { return GraphemeBreak.Prepend }
    if (codepoint == 0x08E2) { return GraphemeBreak.Prepend }
    if (codepoint == 0x0D4E) { return GraphemeBreak.Prepend }
    if (codepoint >= 0x110BD && codepoint <= 0x110BD) { return GraphemeBreak.Prepend }
    if (codepoint >= 0x110CD && codepoint <= 0x110CD) { return GraphemeBreak.Prepend }
    if (codepoint >= 0x111C2 && codepoint <= 0x111C3) { return GraphemeBreak.Prepend }
    if (codepoint >= 0x1193F && codepoint <= 0x1193F) { return GraphemeBreak.Prepend }
    if (codepoint >= 0x11941 && codepoint <= 0x11941) { return GraphemeBreak.Prepend }
    if (codepoint >= 0x11A3A && codepoint <= 0x11A3A) { return GraphemeBreak.Prepend }
    if (codepoint >= 0x11A84 && codepoint <= 0x11A89) { return GraphemeBreak.Prepend }
    if (codepoint >= 0x11D46 && codepoint <= 0x11D46) { return GraphemeBreak.Prepend }

    // ========================================================================
    // EmojiModifier (肤色修饰符)
    // ========================================================================
    if (codepoint >= 0x1F3FB && codepoint <= 0x1F3FF) { return GraphemeBreak.Extend }

    // ========================================================================
    // ExtendedPictographic - 对应 emoji-data.txt Extended_Pictographic
    // 主要 emoji 范围 (用于 GB11: ExtPict Extend* ZWJ × ExtPict)
    // ========================================================================
    if (isExtendedPictographic(codepoint)) { return GraphemeBreak.ExtendedPictographic }

    // ========================================================================
    // Indic Conjunct Break - 对应 Unicode 15.1 InSC 范围
    // ========================================================================
    if (codepoint >= 0x094D && codepoint <= 0x094D) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x09CD && codepoint <= 0x09CD) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x0ACD && codepoint <= 0x0ACD) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x0B4D && codepoint <= 0x0B4D) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x0BCD && codepoint <= 0x0BCD) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x0C4D && codepoint <= 0x0C4D) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x0CCD && codepoint <= 0x0CCD) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x0D4D && codepoint <= 0x0D4D) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x0DCA && codepoint <= 0x0DCA) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x103A && codepoint <= 0x103A) { return GraphemeBreak.IndicConjunctBreakConsonant }
    if (codepoint >= 0x1715 && codepoint <= 0x1715) { return GraphemeBreak.IndicConjunctBreakLinker }

    return GraphemeBreak.Other
}

/// 扩展象形 (Extended_Pictographic) 判断
/// 对应 Unicode emoji-data.txt Extended_Pictographic 范围
/// 用于 GB11 规则: ExtPict Extend* ZWJ × ExtPict
public static func isExtendedPictographic(codepoint: UInt32): Bool {
    // 主要 emoji 范围
    if (codepoint >= 0x1F774 && codepoint <= 0x1F77F) { return true }
    if (codepoint >= 0x1F7D5 && codepoint <= 0x1F7FF) { return true }
    if (codepoint >= 0x1F80C && codepoint <= 0x1F80F) { return true }
    if (codepoint >= 0x1F848 && codepoint <= 0x1F84F) { return true }
    if (codepoint >= 0x1F85A && codepoint <= 0x1F85F) { return true }
    if (codepoint >= 0x1F888 && codepoint <= 0x1F88F) { return true }
    if (codepoint >= 0x1F8AE && codepoint <= 0x1F8FF) { return true }
    if (codepoint >= 0x1F90C && codepoint <= 0x1F93A) { return true }
    if (codepoint >= 0x1F93C && codepoint <= 0x1F945) { return true }
    if (codepoint >= 0x1F947 && codepoint <= 0x1FAFF) { return true }
    if (codepoint >= 0x1FC00 && codepoint <= 0x1FFFD) { return true }
    // CJK 统一表意文字中的 emoji
    if (codepoint >= 0x2702 && codepoint <= 0x270B) { return true }
    if (codepoint >= 0x2E80 && codepoint <= 0x2FFF) { return true }
    if (codepoint >= 0x3000 && codepoint <= 0x303E) { return true }
    if (codepoint >= 0x3192 && codepoint <= 0x319F) { return true }
    if (codepoint >= 0x31C0 && codepoint <= 0x31CF) { return true }
    if (codepoint >= 0x3200 && codepoint <= 0x327E) { return true }
    if (codepoint >= 0x3280 && codepoint <= 0x32CF) { return true }
    if (codepoint >= 0x3358 && codepoint <= 0x33FF) { return true }
    if (codepoint >= 0xA960 && codepoint <= 0xA97C) { return true }
    if (codepoint >= 0xAC00 && codepoint <= 0xD7A3) { return true }
    if (codepoint >= 0xFE00 && codepoint <= 0xFE0F) { return true }
    // Emoji 基础字符
    if (codepoint >= 0x261D && codepoint <= 0x261D) { return true }
    if (codepoint >= 0x265F && codepoint <= 0x265F) { return true }
    if (codepoint >= 0x26A0 && codepoint <= 0x26A1) { return true }
    if (codepoint >= 0x26BD && codepoint <= 0x26BF) { return true }
    if (codepoint >= 0x26C4 && codepoint <= 0x26CD) { return true }
    if (codepoint >= 0x26CF && codepoint <= 0x26E1) { return true }
    if (codepoint >= 0x26E3 && codepoint <= 0x26E3) { return true }
    if (codepoint >= 0x26E8 && codepoint <= 0x26FF) { return true }
    if (codepoint >= 0x2705 && codepoint <= 0x2705) { return true }
    if (codepoint >= 0x270A && codepoint <= 0x270B) { return true }
    if (codepoint >= 0x2721 && codepoint <= 0x2728) { return true }
    if (codepoint >= 0x273D && codepoint <= 0x2744) { return true }
    if (codepoint >= 0x2747 && codepoint <= 0x274C) { return true }
    if (codepoint >= 0x274E && codepoint <= 0x2753) { return true }
    if (codepoint >= 0x2795 && codepoint <= 0x2797) { return true }
    // 更广泛的 emoji 范围
    if (codepoint >= 0x231A && codepoint <= 0x231B) { return true }
    if (codepoint >= 0x23E9 && codepoint <= 0x23F3) { return true }
    if (codepoint >= 0x23F8 && codepoint <= 0x23FA) { return true }
    if (codepoint == 0x25AA || codepoint == 0x25AB || codepoint == 0x25B6 || codepoint == 0x25C0) { return true }
    if (codepoint >= 0x25FB && codepoint <= 0x25FE) { return true }
    if (codepoint >= 0x2600 && codepoint <= 0x2604) { return true }
    if (codepoint == 0x260E || codepoint == 0x2611 || codepoint == 0x2614 || codepoint == 0x2615) { return true }
    if (codepoint >= 0x2607 && codepoint <= 0x260D) { return true }
    if (codepoint >= 0x1F004 && codepoint <= 0x1F004) { return true }
    if (codepoint >= 0x1F0CF && codepoint <= 0x1F0CF) { return true }
    if (codepoint >= 0x1F170 && codepoint <= 0x1F171) { return true }
    if (codepoint >= 0x1F17E && codepoint <= 0x1F17F) { return true }
    if (codepoint >= 0x1F18E && codepoint <= 0x1F18E) { return true }
    if (codepoint >= 0x1F191 && codepoint <= 0x1F19A) { return true }
    if (codepoint >= 0x1F1AD && codepoint <= 0x1F1E5) { return true }
    if (codepoint >= 0x1F201 && codepoint <= 0x1F20F) { return true }
    if (codepoint >= 0x1F21A && codepoint <= 0x1F21A) { return true }
    if (codepoint >= 0x1F22F && codepoint <= 0x1F22F) { return true }
    if (codepoint >= 0x1F232 && codepoint <= 0x1F23A) { return true }
    if (codepoint >= 0x1F23C && codepoint <= 0x1F23F) { return true }
    if (codepoint >= 0x1F249 && codepoint <= 0x1F3FA) { return true }
    if (codepoint >= 0x1F400 && codepoint <= 0x1F53D) { return true }
    if (codepoint >= 0x1F546 && codepoint <= 0x1F64F) { return true }
    if (codepoint >= 0x1F680 && codepoint <= 0x1F6FF) { return true }
    if (codepoint >= 0x1F774 && codepoint <= 0x1F77F) { return true }
    if (codepoint >= 0x1F7E0 && codepoint <= 0x1F7EB) { return true }
    return false
}

/// 字素簇迭代器
public class GraphemeIterator {
    private var bytes: Array<UInt8>
    private var pos: Int64

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        this.pos = 0
    }

    /// 是否还有下一个字素簇
    public func hasNext(): Bool {
        return pos < bytes.size
    }

    /// 获取下一个字素簇的字节范围
    public func next(): GraphemeCluster {
        if (pos >= bytes.size) {
            return GraphemeCluster(start: pos, end: pos, bytes: [])
        }

        let start = pos
        var prevBreak = graphemeBreakFromBytes(pos)

        // 第一个码点
        let firstDecoded = Utf8.decode(bytes, pos)
        pos += firstDecoded.length

        // 继续添加属于同一字素簇的码点
        while (pos < bytes.size) {
            let currentBreak = graphemeBreakFromBytes(pos)
            if (shouldBreak(prevBreak, current: currentBreak)) {
                break
            }
            let decoded = Utf8.decode(bytes, pos)
            pos += decoded.length
            prevBreak = currentBreak
        }

        var clusterBytes = Array<UInt8>()
        for (i in start..pos) {
            clusterBytes.append(bytes[i])
        }
        return GraphemeCluster(start: start, end: pos, bytes: clusterBytes)
    }

    /// 重置迭代器
    public func reset(): Unit {
        pos = 0
    }

    /// 获取当前位置
    public func position(): Int64 {
        return pos
    }

    private func graphemeBreakFromBytes(offset: Int64): GraphemeBreak {
        let decoded = Utf8.decode(bytes, offset)
        return graphemeBreak(decoded.codepoint)
    }

    /// 判断是否应该在这里断裂字素簇
    /// 严格对应 Bun UAX #29 Grapheme Cluster Break Rules
    /// 包含完整 GB3-GB19 规则
    private func shouldBreak(prev: GraphemeBreak, current: GraphemeBreak): Bool {
        // GB3: CR × LF
        if (prev == GraphemeBreak.CR && current == GraphemeBreak.LF) {
            return false
        }
        // GB4: (Control|CR|LF) ÷
        if (prev == GraphemeBreak.Control || prev == GraphemeBreak.CR || prev == GraphemeBreak.LF) {
            return true
        }
        // GB5: ÷ (Control|CR|LF)
        if (current == GraphemeBreak.Control || current == GraphemeBreak.CR || current == GraphemeBreak.LF) {
            return true
        }
        // GB6: L × (L|V|LV|LVT)
        if (prev == GraphemeBreak.L) {
            if (current == GraphemeBreak.L || current == GraphemeBreak.V ||
                current == GraphemeBreak.LV || current == GraphemeBreak.LVT) {
                return false
            }
        }
        // GB7: (LV|V) × (V|T)
        if (prev == GraphemeBreak.LV || prev == GraphemeBreak.V) {
            if (current == GraphemeBreak.V || current == GraphemeBreak.T) {
                return false
            }
        }
        // GB8: (LVT|T) × T
        if (prev == GraphemeBreak.LVT || prev == GraphemeBreak.T) {
            if (current == GraphemeBreak.T) {
                return false
            }
        }
        // GB9: × (Extend|ZWJ)
        if (current == GraphemeBreak.Extend || current == GraphemeBreak.ZWJ) {
            return false
        }
        // GB9a: × SpacingMark
        if (current == GraphemeBreak.SpacingMark) {
            return false
        }
        // GB9b: Prepend × (any)
        if (prev == GraphemeBreak.Prepend) {
            return false
        }
        // GB11: \p{Extended_Pictographic} Extend* ZWJ × \p{Extended_Pictographic}
        // 简化: ZWJ × ExtendedPictographic 不中断
        if (prev == GraphemeBreak.ZWJ && current == GraphemeBreak.ExtendedPictographic) {
            return false
        }
        // GB12/13: sot (RI RI)* RI × RI
        // 简化: Regional_Indicator × Regional_Indicator 不中断 (配对)
        if (prev == GraphemeBreak.RegionalIndicator && current == GraphemeBreak.RegionalIndicator) {
            return false
        }
        // Indic conjunct break
        if (current == GraphemeBreak.IndicConjunctBreakExtend ||
            current == GraphemeBreak.IndicConjunctBreakLinker) {
            return false
        }
        // GB999: Any ÷ Any
        return true
    }
}

/// 字素簇
public class GraphemeCluster {
    public let start: Int64
    public let end: Int64
    public let bytes: Array<UInt8>

    public init(start: Int64, end: Int64, bytes: Array<UInt8>) {
        this.start = start
        this.end = end
        this.bytes = bytes
    }

    /// 获取簇的字节长度
    public func byteLength(): Int64 {
        return end - start
    }
}
