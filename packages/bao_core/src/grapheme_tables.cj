// bao_core - 字素断点查找表
// 严格翻译自: src/bun_core/string/immutable/grapheme_tables.rs
//   pub static TABLE: Tables<GraphemeBreakNoControl>
//   static STAGE1: [u16; 8192]
//   static STAGE2: [u8; ...]
//   static STAGE3: [GraphemeBreakNoControl; ...]
// Bun: 自动生成的字素断点属性查找表
//   3 级查找: stage1 (高字节 → stage2 偏移) → stage2 (→ stage3 索引) → stage3 (实际值)
// 仓颉: 使用 HashMap 简化查找表实现
package bao_core

import std.collection.*

// ============================================================================
// GraphemeTables - 字素断点属性查找表
// 严格翻译自: src/bun_core/string/immutable/grapheme_tables.rs
//   pub struct Tables<Elem> { stage1: &'static [u16], stage2: &'static [u8], stage3: &'static [Elem] }
//   3 级查找表: cp → stage1[cp >> 8] → stage2[offset + (cp & 0xFF)] → stage3[index]
// ============================================================================

/// 字素断点查找表 - 对应 Bun Tables<GraphemeBreakNoControl>
/// 使用 HashMap 简化实现 (Bun 使用 3 级静态数组)
public class GraphemeTables {
    /// 码点到属性的映射
    private var map: HashMap<UInt32, GraphemeBreakNoControl>

    public init() {
        map = HashMap<UInt32, GraphemeBreakNoControl>()
        initBasicRanges()
    }

    /// 查找码点的字素断点属性 - 对应 Bun Tables::get
    public func get(cp: UInt32): GraphemeBreakNoControl {
        // 先查精确映射
        match (map.get(cp)) {
            case Some(v) => return v
            case None => ()
        }
        // 范围匹配
        return rangeLookup(cp)
    }

    /// 范围查找 - 对应 Bun 3 级查找表的范围覆盖
    private func rangeLookup(cp: UInt32): GraphemeBreakNoControl {
        // GB9: Extend (包含大多数组合标记)
        // U+0300..U+036F Combining Diacritical Marks
        if (cp >= 0x0300 && cp <= 0x036F) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // U+1AB0..U+1AFF Combining Diacritical Marks Extended
        if (cp >= 0x1AB0 && cp <= 0x1AFF) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // U+1DC0..U+1DFF Combining Diacritical Marks Supplement
        if (cp >= 0x1DC0 && cp <= 0x1DFF) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // U+0E31, U+0E34..U+0E3A Thai
        if (cp == 0x0E31 || (cp >= 0x0E34 && cp <= 0x0E3A)) {
            return GraphemeBreakNoControl.SpacingMark
        }

        // U+0E47..U+0E4E Thai
        if (cp >= 0x0E47 && cp <= 0x0E4E) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // U+200C ZWNJ
        if (cp == 0x200C) {
            return GraphemeBreakNoControl.Zwnj
        }

        // U+200D ZWJ
        if (cp == 0x200D) {
            return GraphemeBreakNoControl.Zwj
        }

        // U+200B Zero Width Space (not a break)
        if (cp == 0x200B) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // U+20E0..U+20F0 Combining
        if (cp >= 0x20E0 && cp <= 0x20F0) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // Regional Indicators U+1F1E6..U+1F1FF
        if (cp >= 0x1F1E6 && cp <= 0x1F1FF) {
            return GraphemeBreakNoControl.RegionalIndicator
        }

        // Extended Pictographic (emoji ranges)
        if (isExtendedPictographicRange(cp)) {
            return GraphemeBreakNoControl.ExtendedPictographic
        }

        // Emoji Modifier Base
        if (isEmojiModifierBaseRange(cp)) {
            return GraphemeBreakNoControl.EmojiModifierBase
        }

        // Emoji Modifiers U+1F3FB..U+1F3FF
        if (cp >= 0x1F3FB && cp <= 0x1F3FF) {
            return GraphemeBreakNoControl.EmojiModifier
        }

        // FE00..FE0F Variation Selectors
        if (cp >= 0xFE00 && cp <= 0xFE0F) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // FE20..FE2F Combining Half Marks
        if (cp >= 0xFE20 && cp <= 0xFE2F) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // Hangul syllables
        // L: U+1100..U+115F, U+A960..U+A97C
        if ((cp >= 0x1100 && cp <= 0x115F) || (cp >= 0xA960 && cp <= 0xA97C)) {
            return GraphemeBreakNoControl.L
        }
        // V: U+1160..U+11A7, U+D7B0..U+D7C6
        if ((cp >= 0x1160 && cp <= 0x11A7) || (cp >= 0xD7B0 && cp <= 0xD7C6)) {
            return GraphemeBreakNoControl.V
        }
        // T: U+11A8..U+11FF, U+D7CB..U+D7FB
        if ((cp >= 0x11A8 && cp <= 0x11FF) || (cp >= 0xD7CB && cp <= 0xD7FB)) {
            return GraphemeBreakNoControl.T
        }
        // LV: Hangul syllables that are LV type
        if (cp >= 0xAC00 && cp <= 0xD7A3) {
            let syllableIndex = cp - 0xAC00
            if (syllableIndex % 28 == 0) {
                return GraphemeBreakNoControl.Lv
            }
            return GraphemeBreakNoControl.Lvt
        }

        // Prepend: U+0600..U+0605, U+06DD, U+070F, U+0890..U+0891, U+08E2
        if ((cp >= 0x0600 && cp <= 0x0605) || cp == 0x06DD || cp == 0x070F ||
            (cp >= 0x0890 && cp <= 0x0891) || cp == 0x08E2) {
            return GraphemeBreakNoControl.Prepend
        }

        // Indic Conjunct Break
        // Consonant ranges
        if (isIndicConsonant(cp)) {
            return GraphemeBreakNoControl.IndicConjunctBreakConsonant
        }
        // Linker: Virama characters
        if (isIndicLinker(cp)) {
            return GraphemeBreakNoControl.IndicConjunctBreakLinker
        }
        // Extend: Various Indic combining marks
        if (isIndicExtend(cp)) {
            return GraphemeBreakNoControl.IndicConjunctBreakExtend
        }

        // SpacingMark
        if (isSpacingMark(cp)) {
            return GraphemeBreakNoControl.SpacingMark
        }

        // 默认
        return GraphemeBreakNoControl.Other
    }

    /// 初始化基本码点映射
    private func initBasicRanges(): Unit {
        return
    }

    // Extended Pictographic ranges
    private static func isExtendedPictographicRange(cp: UInt32): Bool {
        // 主要 Emoji 范围 (简化版, 完整版需要完整查找表)
        (cp >= 0x1F600 && cp <= 0x1F64F) ||  // Emoticons
        (cp >= 0x1F300 && cp <= 0x1F5FF) ||  // Misc Symbols and Pictographs
        (cp >= 0x1F680 && cp <= 0x1F6FF) ||  // Transport and Map
        (cp >= 0x1F900 && cp <= 0x1F9FF) ||  // Supplemental Symbols and Pictographs
        (cp >= 0x1FA00 && cp <= 0x1FA6F) ||  // Chess Symbols
        (cp >= 0x1FA70 && cp <= 0x1FAFF) ||  // Symbols and Pictographs Extended-A
        (cp >= 0x2600 && cp <= 0x26FF) ||    // Misc symbols
        (cp >= 0x2700 && cp <= 0x27BF)       // Dingbats
    }

    private static func isEmojiModifierBaseRange(cp: UInt32): Bool {
        (cp >= 0x1F3C0 && cp <= 0x1F3C0) ||
        (cp >= 0x1F3C2 && cp <= 0x1F3C2) ||
        (cp >= 0x1F3C7 && cp <= 0x1F3C7) ||
        (cp >= 0x1F3CB && cp <= 0x1F3CE) ||
        (cp >= 0x1F3D1 && cp <= 0x1F3D4) ||
        (cp >= 0x1F3E0 && cp <= 0x1F3E3) ||
        (cp >= 0x1F40D && cp <= 0x1F40D) ||
        (cp >= 0x1F468 && cp <= 0x1F46B) ||
        (cp >= 0x1F46D && cp <= 0x1F46F) ||
        (cp >= 0x1F466 && cp <= 0x1F467)
    }

    private static func isIndicConsonant(cp: UInt32): Bool {
        // Devanagari consonants
        (cp >= 0x0915 && cp <= 0x0939) ||
        // Bengali consonants
        (cp >= 0x0995 && cp <= 0x09B9) ||
        // Gurmukhi consonants
        (cp >= 0x0A15 && cp <= 0x0A39) ||
        // Gujarati consonants
        (cp >= 0x0A95 && cp <= 0x0AB9) ||
        // Oriya consonants
        (cp >= 0x0B15 && cp <= 0x0B39) ||
        // Tamil consonants
        (cp >= 0x0B95 && cp <= 0x0BB9) ||
        // Telugu consonants
        (cp >= 0x0C15 && cp <= 0x0C39) ||
        // Kannada consonants
        (cp >= 0x0C95 && cp <= 0x0CB9) ||
        // Malayalam consonants
        (cp >= 0x0D15 && cp <= 0x0D39)
    }

    private static func isIndicLinker(cp: UInt32): Bool {
        // Virama / Halant characters
        cp == 0x094D ||  // Devanagari Virama
        cp == 0x09CD ||  // Bengali Virama
        cp == 0x0A4D ||  // Gurmukhi Virama
        cp == 0x0ACD ||  // Gujarati Virama
        cp == 0x0B4D ||  // Oriya Virama
        cp == 0x0BCD ||  // Tamil Virama
        cp == 0x0C4D ||  // Telugu Virama
        cp == 0x0CCD ||  // Kannada Virama
        cp == 0x0D4D     // Malayalam Virama
    }

    private static func isIndicExtend(cp: UInt32): Bool {
        // Indic vowel signs and combining marks (extend category)
        (cp >= 0x093A && cp <= 0x093C) ||
        (cp >= 0x093E && cp <= 0x0949) ||
        (cp >= 0x094A && cp <= 0x094C) ||
        (cp >= 0x094E && cp <= 0x0950) ||
        (cp >= 0x0955 && cp <= 0x0957) ||
        (cp >= 0x0962 && cp <= 0x0963) ||
        (cp >= 0x09BE && cp <= 0x09C4) ||
        (cp >= 0x09C7 && cp <= 0x09C8)
    }

    private static func isSpacingMark(cp: UInt32): Bool {
        // SpacingMark category (simplified)
        cp == 0x0903 ||  // Devanagari Visarga
        cp == 0x093B ||  // Devanagari
        cp == 0x0A03 ||  // Gurmukhi Visarga
        cp == 0x0B02 || cp == 0x0B03 ||  // Oriya
        cp == 0x0B83 ||  // Tamil
        cp == 0x0C03 ||  // Telugu
        cp == 0x0C83 ||  // Kannada
        cp == 0x0D02 || cp == 0x0D03     // Malayalam
    }
}
