// bao_unicode - 字素簇分割
// 严格翻译自: src/unicode/uucode_lib/src/grapheme.zig
//   Bun 使用预计算的 Grapheme Break 表实现 UAX #29 字素簇分割
//   仓颉实现提供完整的 Grapheme Cluster Break 算法
package bao_unicode

// ============================================================================
// Grapheme Break 属性查找
// 严格翻译自 src/unicode/uucode_lib/src/grapheme.zig
//   GraphemeBreak 属性来自 GraphemeBreakProperty.txt + emoji-data.txt
// ============================================================================

/// 获取码点的 Grapheme Break 属性
/// 严格翻译自 Bun uucode get(.grapheme_break, cp)
public func graphemeBreak(codepoint: UInt32): GraphemeBreak {
    // CR / LF / Control
    if (codepoint == 0x000D) { return GraphemeBreak.CR }
    if (codepoint == 0x000A) { return GraphemeBreak.LF }
    if (codepoint < 0x0020 && codepoint != 0x000A && codepoint != 0x000D) {
        return GraphemeBreak.Control
    }
    if (codepoint >= 0x007F && codepoint <= 0x009F) {
        return GraphemeBreak.Control
    }
    if (codepoint == 0x00AD) { return GraphemeBreak.Control }
    if (codepoint == 0x061C) { return GraphemeBreak.Control }
    if (codepoint == 0x180E) { return GraphemeBreak.Control }
    if (codepoint == 0x200B) { return GraphemeBreak.Control }
    if (codepoint == 0x200E || codepoint == 0x200F) { return GraphemeBreak.Control }
    if (codepoint >= 0x2028 && codepoint <= 0x202E) { return GraphemeBreak.Control }
    if (codepoint >= 0x2060 && codepoint <= 0x206F) { return GraphemeBreak.Control }
    if (codepoint == 0xFEFF) { return GraphemeBreak.Control }
    if (codepoint >= 0xFFF0 && codepoint <= 0xFFF8) { return GraphemeBreak.Control }
    if (codepoint >= 0xFFFE && codepoint <= 0xFFFF) { return GraphemeBreak.Control }
    if (codepoint >= 0xE0000 && codepoint <= 0xE007F) { return GraphemeBreak.Control }

    // ZWJ
    if (codepoint == 0x200D) { return GraphemeBreak.ZWJ }

    // ZWNJ
    if (codepoint == 0x200C) { return GraphemeBreak.ZWNJ }

    // Regional Indicator
    if (codepoint >= 0x1F1E6 && codepoint <= 0x1F1FF) {
        return GraphemeBreak.RegionalIndicator
    }

    // Hangul syllables
    if (codepoint >= 0x1100 && codepoint <= 0x115F) { return GraphemeBreak.L }
    if (codepoint >= 0xA960 && codepoint <= 0xA97C) { return GraphemeBreak.L }
    if (codepoint >= 0x1160 && codepoint <= 0x11A7) { return GraphemeBreak.V }
    if (codepoint >= 0xD7B0 && codepoint <= 0xD7C6) { return GraphemeBreak.V }
    if (codepoint >= 0x11A8 && codepoint <= 0x11FF) { return GraphemeBreak.T }
    if (codepoint >= 0xD7CB && codepoint <= 0xD7FB) { return GraphemeBreak.T }
    if (codepoint >= 0xAC00 && codepoint <= 0xD7A3) {
        let s = codepoint - 0xAC00
        if (s % 28 == 0) { return GraphemeBreak.LV }
        return GraphemeBreak.LVT
    }

    // Extend (combining marks, variation selectors, etc.)
    if (isGraphemeExtend(codepoint)) { return GraphemeBreak.IndicConjunctBreakExtend }

    // SpacingMark
    if (isSpacingMark(codepoint)) { return GraphemeBreak.SpacingMark }

    // Prepend
    if (isPrepend(codepoint)) { return GraphemeBreak.Prepend }

    // Emoji modifier base
    if (isEmojiModifierBase(codepoint)) { return GraphemeBreak.ExtendedPictographic }

    // Emoji modifier (skin tone)
    if (codepoint >= 0x1F3FB && codepoint <= 0x1F3FF) { return GraphemeBreak.EmojiModifier }

    // Extended pictographic (emoji)
    if (isExtendedPictographic(codepoint)) { return GraphemeBreak.ExtendedPictographic }

    // Indic conjunct break
    let indicBreak = getIndicConjunctBreak(codepoint)
    match (indicBreak) {
        case Some(GraphemeBreak.IndicConjunctBreakConsonant) =>
            return GraphemeBreak.IndicConjunctBreakConsonant
        case Some(GraphemeBreak.IndicConjunctBreakLinker) =>
            return GraphemeBreak.IndicConjunctBreakLinker
        case Some(GraphemeBreak.IndicConjunctBreakExtend) =>
            return GraphemeBreak.IndicConjunctBreakExtend
        case _ => ()
    }

    return GraphemeBreak.Other
}

// ============================================================================
// Grapheme Break 分类辅助函数
// ============================================================================

/// 判断是否为 Extend 类字符
/// 严格翻译自 Bun grapheme.zig isExtend
private func isGraphemeExtend(cp: UInt32): Bool {
    // Mn + Me marks
    let gc = generalCategory(cp)
    if (gc == GeneralCategory.Mn || gc == GeneralCategory.Me) { return true }
    // Variation selectors
    if (cp >= 0xFE00 && cp <= 0xFE0F) { return true }
    if (cp >= 0xE0100 && cp <= 0xE01EF) { return true }
    // Emoji modifiers are extend in grapheme context
    if (cp >= 0x1F3FB && cp <= 0x1F3FF) { return true }
    // ZWNJ
    if (cp == 0x200C) { return true }
    return false
}

/// SpacingMark 范围检查
private func isSpacingMark(cp: UInt32): Bool {
    return binarySearchRange(spacingMarkRanges, cp)
}

/// Prepend 范围检查
private func isPrepend(cp: UInt32): Bool {
    return binarySearchRange(prependRanges, cp)
}

/// SpacingMark 范围
private let spacingMarkRanges: Array<(UInt32, UInt32)> = [
    (0x0903, 0x0903), (0x093B, 0x093B), (0x093E, 0x0940),
    (0x0949, 0x094C), (0x094E, 0x094F), (0x0982, 0x0983),
    (0x09BF, 0x09C0), (0x09C7, 0x09C8), (0x09CB, 0x09CC),
    (0x0A03, 0x0A03), (0x0A3E, 0x0A40), (0x0A83, 0x0A83),
    (0x0ABE, 0x0AC0), (0x0AC9, 0x0AC9), (0x0ACB, 0x0ACC),
    (0x0B02, 0x0B03), (0x0B40, 0x0B40), (0x0B47, 0x0B48),
    (0x0B4B, 0x0B4C), (0x0BBF, 0x0BBF), (0x0BC1, 0x0BC2),
    (0x0BC6, 0x0BC8), (0x0BCA, 0x0BCC), (0x0C01, 0x0C03),
    (0x0C41, 0x0C44), (0x0C82, 0x0C83), (0x0CBE, 0x0CBE),
    (0x0CC0, 0x0CC1), (0x0CC3, 0x0CC4), (0x0CC7, 0x0CC8),
    (0x0CCA, 0x0CCB), (0x0D02, 0x0D03), (0x0D3F, 0x0D40),
    (0x0D46, 0x0D48), (0x0D4A, 0x0D4C), (0x0D82, 0x0D83),
    (0x0DD0, 0x0DD1), (0x0DD8, 0x0DDE), (0x0DF2, 0x0DF3),
    (0x0F3E, 0x0F3F), (0x0F7F, 0x0F7F),
    (0x102B, 0x102C), (0x1031, 0x1031), (0x1038, 0x1038),
    (0x103B, 0x103C), (0x1056, 0x1057), (0x1062, 0x1062),
    (0x1067, 0x1068), (0x1071, 0x1074), (0x1082, 0x1082),
    (0x1085, 0x1086), (0x109C, 0x109C),
    (0x1715, 0x1715), (0x1734, 0x1734), (0x17B6, 0x17B6),
    (0x17BE, 0x17C5), (0x17C7, 0x17C8),
    (0x1923, 0x1926), (0x1929, 0x192B), (0x1930, 0x1931),
    (0x1933, 0x1938), (0x1A19, 0x1A1A), (0x1A55, 0x1A55),
    (0x1A57, 0x1A57), (0x1A6D, 0x1A72), (0x1B04, 0x1B04),
    (0x1B3B, 0x1B3B), (0x1B3D, 0x1B41), (0x1B43, 0x1B44),
    (0x1B82, 0x1B82), (0x1BA1, 0x1BA1), (0x1BA6, 0x1BA7),
    (0x1BAA, 0x1BAA), (0x1BE7, 0x1BE7), (0x1BEA, 0x1BEC),
    (0x1BEE, 0x1BEE), (0x1BF2, 0x1BF3), (0x1C24, 0x1C2B),
    (0x1C34, 0x1C35), (0xA823, 0xA824), (0xA827, 0xA827),
    (0xA880, 0xA881), (0xA8B4, 0xA8C3), (0xA952, 0xA953),
    (0xA983, 0xA983), (0xA9B4, 0xA9B5), (0xA9BA, 0xA9BB),
    (0xA9BE, 0xA9C0), (0xAA2F, 0xAA30), (0xAA33, 0xAA34),
    (0xAA4D, 0xAA4D), (0xAAEB, 0xAAEB), (0xAAEE, 0xAAEF),
    (0xAAF5, 0xAAF5), (0xABE3, 0xABE4), (0xABE6, 0xABE7),
    (0xABE9, 0xABEA), (0xABEC, 0xABEC),
    (0x11000, 0x11000), (0x11002, 0x11002), (0x11082, 0x11082),
    (0x110B0, 0x110B2), (0x110B7, 0x110B8), (0x1112C, 0x1112C),
    (0x11145, 0x11146), (0x11182, 0x11182), (0x111B3, 0x111B5),
    (0x111BF, 0x111C0), (0x111CE, 0x111CE), (0x1122C, 0x1122E),
    (0x11232, 0x11233), (0x11235, 0x11235), (0x112E0, 0x112E2),
    (0x11302, 0x11303), (0x1133F, 0x1133F), (0x11341, 0x11344),
    (0x11347, 0x11348), (0x1134B, 0x1134D), (0x11362, 0x11363),
    (0x11435, 0x11437), (0x11440, 0x11441), (0x11445, 0x11445),
    (0x114B1, 0x114B2), (0x114B9, 0x114B9), (0x114BB, 0x114BC),
    (0x114BE, 0x114BE), (0x114C1, 0x114C1), (0x115B0, 0x115B1),
    (0x115B8, 0x115BB), (0x11630, 0x11632), (0x1163B, 0x1163C),
    (0x1163E, 0x1163E), (0x116AC, 0x116AC), (0x116AE, 0x116AF),
    (0x116B6, 0x116B6), (0x11720, 0x11721), (0x11726, 0x11726),
    (0x1182C, 0x1182E), (0x11838, 0x11838),
    (0x11931, 0x11935), (0x11937, 0x11938), (0x1193D, 0x1193D),
    (0x11940, 0x11940), (0x11942, 0x11942),
    (0x119D1, 0x119D3), (0x119DC, 0x119DF), (0x119E4, 0x119E4),
    (0x11A39, 0x11A39), (0x11A57, 0x11A58), (0x11A97, 0x11A97),
    (0x11C2F, 0x11C2F), (0x11C3E, 0x11C3E), (0x11CA9, 0x11CA9),
    (0x11CB1, 0x11CB1), (0x11CB4, 0x11CB4),
    (0x11D8A, 0x11D8E), (0x11D93, 0x11D94), (0x11D96, 0x11D96),
    (0x11EF5, 0x11EF6), (0x11F03, 0x11F03),
    (0x16F51, 0x16F87)
]

/// Prepend 范围
private let prependRanges: Array<(UInt32, UInt32)> = [
    (0x0600, 0x0605), (0x06DD, 0x06DD), (0x070F, 0x070F),
    (0x0890, 0x0891), (0x08E2, 0x08E2), (0x0D4E, 0x0D4E),
    (0x110BD, 0x110BD), (0x110CD, 0x110CD), (0x111C2, 0x111C3),
    (0x1193F, 0x1193F), (0x11941, 0x11941), (0x11A3A, 0x11A3A),
    (0x11A84, 0x11A89), (0x11D46, 0x11D46)
]

/// Extended Pictographic 范围检查
/// 严格翻译自 Bun emoji-data.txt Extended_Pictographic
public func isExtendedPictographic(cp: UInt32): Bool {
    if (cp >= 0x1F774 && cp <= 0x1F77F) { return true }
    if (cp >= 0x1F7D5 && cp <= 0x1F7FF) { return true }
    if (cp >= 0x1F80C && cp <= 0x1F80F) { return true }
    if (cp >= 0x1F848 && cp <= 0x1F84F) { return true }
    if (cp >= 0x1F85A && cp <= 0x1F85F) { return true }
    if (cp >= 0x1F888 && cp <= 0x1F88F) { return true }
    if (cp >= 0x1F8AE && cp <= 0x1F8FF) { return true }
    if (cp >= 0x1F90C && cp <= 0x1F93A) { return true }
    if (cp >= 0x1F93C && cp <= 0x1F945) { return true }
    if (cp >= 0x1F947 && cp <= 0x1FAFF) { return true }
    if (cp >= 0x1FC00 && cp <= 0x1FFFD) { return true }
    if (cp >= 0x2702 && cp <= 0x270B) { return true }
    if (cp >= 0x261D && cp <= 0x261D) { return true }
    if (cp >= 0x265F && cp <= 0x265F) { return true }
    if (cp >= 0x26A0 && cp <= 0x26A1) { return true }
    if (cp >= 0x26BD && cp <= 0x26BF) { return true }
    if (cp >= 0x26C4 && cp <= 0x26CD) { return true }
    if (cp >= 0x26CF && cp <= 0x26E1) { return true }
    if (cp == 0x26E3) { return true }
    if (cp >= 0x26E8 && cp <= 0x26FF) { return true }
    if (cp >= 0x2705 && cp <= 0x2705) { return true }
    if (cp >= 0x270A && cp <= 0x270B) { return true }
    if (cp >= 0x2721 && cp <= 0x2728) { return true }
    if (cp >= 0x273D && cp <= 0x2744) { return true }
    if (cp >= 0x2747 && cp <= 0x274C) { return true }
    if (cp >= 0x274E && cp <= 0x2753) { return true }
    if (cp >= 0x2795 && cp <= 0x2797) { return true }
    if (cp >= 0x231A && cp <= 0x231B) { return true }
    if (cp >= 0x23E9 && cp <= 0x23F3) { return true }
    if (cp >= 0x23F8 && cp <= 0x23FA) { return true }
    if (cp == 0x25AA || cp == 0x25AB || cp == 0x25B6 || cp == 0x25C0) { return true }
    if (cp >= 0x25FB && cp <= 0x25FE) { return true }
    if (cp >= 0x2600 && cp <= 0x2604) { return true }
    if (cp == 0x260E || cp == 0x2611 || cp == 0x2614 || cp == 0x2615) { return true }
    if (cp >= 0x1F004 && cp <= 0x1F004) { return true }
    if (cp == 0x1F0CF) { return true }
    if (cp >= 0x1F170 && cp <= 0x1F171) { return true }
    if (cp >= 0x1F17E && cp <= 0x1F17F) { return true }
    if (cp == 0x1F18E) { return true }
    if (cp >= 0x1F191 && cp <= 0x1F19A) { return true }
    if (cp >= 0x1F201 && cp <= 0x1F20F) { return true }
    if (cp == 0x1F21A) { return true }
    if (cp == 0x1F22F) { return true }
    if (cp >= 0x1F232 && cp <= 0x1F23A) { return true }
    if (cp >= 0x1F23C && cp <= 0x1F23F) { return true }
    if (cp >= 0x1F249 && cp <= 0x1F3FA) { return true }
    if (cp >= 0x1F400 && cp <= 0x1F53D) { return true }
    if (cp >= 0x1F546 && cp <= 0x1F64F) { return true }
    if (cp >= 0x1F680 && cp <= 0x1F6FF) { return true }
    if (cp >= 0x1F7E0 && cp <= 0x1F7EB) { return true }
    return false
}

/// Emoji modifier base 判断
private func isEmojiModifierBase(cp: UInt32): Bool {
    // Common emoji modifier bases
    if (cp >= 0x261D && cp <= 0x261D) { return true }
    if (cp >= 0x270A && cp <= 0x270D) { return true }
    if (cp == 0x1F385) { return true }
    if (cp >= 0x1F3C2 && cp <= 0x1F3C4) { return true }
    if (cp == 0x1F3C7) { return true }
    if (cp >= 0x1F3CA && cp <= 0x1F3CC) { return true }
    if (cp >= 0x1F442 && cp <= 0x1F443) { return true }
    if (cp >= 0x1F446 && cp <= 0x1F450) { return true }
    if (cp == 0x1F466 || cp == 0x1F467) { return true }
    if (cp >= 0x1F468 && cp <= 0x1F46B) { return true }
    if (cp >= 0x1F46C && cp <= 0x1F46E) { return true }
    if (cp >= 0x1F470 && cp <= 0x1F478) { return true }
    if (cp == 0x1F47C) { return true }
    if (cp >= 0x1F481 && cp <= 0x1F483) { return true }
    if (cp >= 0x1F485 && cp <= 0x1F487) { return true }
    if (cp >= 0x1F48B && cp <= 0x1F48C) { return true }
    if (cp >= 0x1F4AA && cp <= 0x1F4AA) { return true }
    if (cp >= 0x1F574 && cp <= 0x1F575) { return true }
    if (cp == 0x1F57A) { return true }
    if (cp >= 0x1F590 && cp <= 0x1F590) { return true }
    if (cp >= 0x1F595 && cp <= 0x1F596) { return true }
    if (cp >= 0x1F645 && cp <= 0x1F647) { return true }
    if (cp >= 0x1F64B && cp <= 0x1F64F) { return true }
    if (cp >= 0x1F6A3 && cp <= 0x1F6A3) { return true }
    if (cp >= 0x1F6B4 && cp <= 0x1F6B6) { return true }
    if (cp >= 0x1F6C0 && cp <= 0x1F6C0) { return true }
    if (cp >= 0x1F6CC && cp <= 0x1F6CC) { return true }
    if (cp >= 0x1F918 && cp <= 0x1F918) { return true }
    if (cp >= 0x1F919 && cp <= 0x1F91E) { return true }
    if (cp >= 0x1F926 && cp <= 0x1F926) { return true }
    if (cp >= 0x1F930 && cp <= 0x1F930) { return true }
    if (cp >= 0x1F933 && cp <= 0x1F93A) { return true }
    if (cp >= 0x1F93C && cp <= 0x1F93E) { return true }
    if (cp >= 0x1F9D1 && cp <= 0x1F9DD) { return true }
    return false
}

/// Indic Conjunct Break 属性
private func getIndicConjunctBreak(cp: UInt32): ?GraphemeBreak {
    // Virama / Halant characters = Linker
    if (cp == 0x094D || cp == 0x09CD || cp == 0x0A4D || cp == 0x0ACD ||
        cp == 0x0B4D || cp == 0x0BCD || cp == 0x0C4D || cp == 0x0CCD ||
        cp == 0x0D4D || cp == 0x0DCA || cp == 0x0E3A || cp == 0x0F84 ||
        cp == 0x103A || cp == 0x1715 || cp == 0x17D2 || cp == 0x1A60 ||
        cp == 0x1B44 || cp == 0x1BEA || cp == 0x1113E || cp == 0x11235 ||
        cp == 0x112EA || cp == 0x1134D || cp == 0x11442 || cp == 0x114C2 ||
        cp == 0x115BF || cp == 0x1163F || cp == 0x116B6 || cp == 0x1172B ||
        cp == 0x11C3E || cp == 0x11D44 || cp == 0x11D97) {
        return Some(GraphemeBreak.IndicConjunctBreakLinker)
    }
    return None
}

// ============================================================================
// Grapheme Break 算法
// 严格翻译自 src/unicode/uucode_lib/src/grapheme.zig computeGraphemeBreak
//   实现 UAX #29 GB3-GB999 规则 + GB9c Indic + GB11 Emoji
// ============================================================================

/// 计算两个相邻码点之间是否应该断开字素簇
/// 严格翻译自 Bun grapheme.zig computeGraphemeBreak
public func computeGraphemeBreak(
    gb1: GraphemeBreak,
    gb2: GraphemeBreak,
    state: BreakState
): Bool {
    var s = state

    // Set state back to default when gb1 or gb2 is not expected in sequence
    switch (s) {
        case BreakState.RegionalIndicator =>
            if (gb1 != GraphemeBreak.RegionalIndicator || gb2 != GraphemeBreak.RegionalIndicator) {
                s = BreakState.Default
            }
        case BreakState.ExtendedPictographic =>
            switch (gb1) {
                case GraphemeBreak.IndicConjunctBreakExtend,
                     GraphemeBreak.IndicConjunctBreakLinker,
                     GraphemeBreak.ZWNJ, GraphemeBreak.ZWJ,
                     GraphemeBreak.ExtendedPictographic,
                     GraphemeBreak.EmojiModifierBase,
                     GraphemeBreak.EmojiModifier => {}
                case _ => s = BreakState.Default
            }
            switch (gb2) {
                case GraphemeBreak.IndicConjunctBreakExtend,
                     GraphemeBreak.IndicConjunctBreakLinker,
                     GraphemeBreak.ZWNJ, GraphemeBreak.ZWJ,
                     GraphemeBreak.ExtendedPictographic,
                     GraphemeBreak.EmojiModifierBase,
                     GraphemeBreak.EmojiModifier => {}
                case _ => s = BreakState.Default
            }
        case BreakState.IndicConjunctBreakConsonant,
             BreakState.IndicConjunctBreakLinker =>
            switch (gb1) {
                case GraphemeBreak.IndicConjunctBreakConsonant,
                     GraphemeBreak.IndicConjunctBreakLinker,
                     GraphemeBreak.IndicConjunctBreakExtend,
                     GraphemeBreak.ZWJ => {}
                case _ => s = BreakState.Default
            }
            switch (gb2) {
                case GraphemeBreak.IndicConjunctBreakConsonant,
                     GraphemeBreak.IndicConjunctBreakLinker,
                     GraphemeBreak.IndicConjunctBreakExtend,
                     GraphemeBreak.ZWJ => {}
                case _ => s = BreakState.Default
            }
        case BreakState.Default => ()
    }

    // GB3: CR x LF
    if (gb1 == GraphemeBreak.CR && gb2 == GraphemeBreak.LF) { return false }

    // GB4: (Control|CR|LF) ÷
    if (gb1 == GraphemeBreak.Control || gb1 == GraphemeBreak.CR || gb1 == GraphemeBreak.LF) {
        return true
    }

    // GB5: ÷ (Control|CR|LF)
    if (gb2 == GraphemeBreak.Control || gb2 == GraphemeBreak.CR || gb2 == GraphemeBreak.LF) {
        return true
    }

    // GB6: L x (L|V|LV|LVT)
    if (gb1 == GraphemeBreak.L) {
        if (gb2 == GraphemeBreak.L || gb2 == GraphemeBreak.V ||
            gb2 == GraphemeBreak.LV || gb2 == GraphemeBreak.LVT) {
            return false
        }
    }

    // GB7: (LV|V) x (V|T)
    if (gb1 == GraphemeBreak.LV || gb1 == GraphemeBreak.V) {
        if (gb2 == GraphemeBreak.V || gb2 == GraphemeBreak.T) { return false }
    }

    // GB8: (LVT|T) x T
    if (gb1 == GraphemeBreak.LVT || gb1 == GraphemeBreak.T) {
        if (gb2 == GraphemeBreak.T) { return false }
    }

    // GB9a: SpacingMark
    if (gb2 == GraphemeBreak.SpacingMark) { return false }

    // GB9b: Prepend
    if (gb1 == GraphemeBreak.Prepend) { return false }

    // GB9c: Indic conjunct break
    if (gb1 == GraphemeBreak.IndicConjunctBreakConsonant) {
        if (isGraphemeBreakExtend(gb2)) {
            return false
        } else if (gb2 == GraphemeBreak.IndicConjunctBreakLinker) {
            return false
        }
    } else if (s == BreakState.IndicConjunctBreakConsonant) {
        if (gb2 == GraphemeBreak.IndicConjunctBreakLinker) {
            return false
        } else if (isGraphemeBreakExtend(gb2)) {
            return false
        } else {
            s = BreakState.Default
        }
    } else if (s == BreakState.IndicConjunctBreakLinker) {
        if (gb2 == GraphemeBreak.IndicConjunctBreakLinker || isGraphemeBreakExtend(gb2)) {
            return false
        } else if (gb2 == GraphemeBreak.IndicConjunctBreakConsonant) {
            s = BreakState.Default
            return false
        } else {
            s = BreakState.Default
        }
    }

    // GB11: ExtendedPictographic
    if (isExtendedPictographicGb(gb1)) {
        if (isGraphemeBreakExtend(gb2) || gb2 == GraphemeBreak.ZWJ) {
            s = BreakState.ExtendedPictographic
            return false
        }
        if (gb1 == GraphemeBreak.EmojiModifierBase && gb2 == GraphemeBreak.EmojiModifier) {
            s = BreakState.ExtendedPictographic
            return false
        }
    } else if (s == BreakState.ExtendedPictographic) {
        if ((isGraphemeBreakExtend(gb1) || gb1 == GraphemeBreak.EmojiModifier) &&
            (isGraphemeBreakExtend(gb2) || gb2 == GraphemeBreak.ZWJ)) {
            return false
        } else if (gb1 == GraphemeBreak.ZWJ && isExtendedPictographicGb(gb2)) {
            s = BreakState.Default
            return false
        } else {
            s = BreakState.Default
        }
    }

    // GB12/GB13: Regional Indicator
    if (gb1 == GraphemeBreak.RegionalIndicator && gb2 == GraphemeBreak.RegionalIndicator) {
        if (s == BreakState.Default) {
            return false
        } else {
            s = BreakState.Default
            return true
        }
    }

    // GB9: x (Extend|ZWJ)
    if (isGraphemeBreakExtend(gb2) || gb2 == GraphemeBreak.ZWJ) { return false }

    // GB999: Otherwise ÷
    return true
}

private func isGraphemeBreakExtend(gb: GraphemeBreak): Bool {
    return gb == GraphemeBreak.ZWNJ ||
           gb == GraphemeBreak.IndicConjunctBreakExtend ||
           gb == GraphemeBreak.IndicConjunctBreakLinker
}

private func isExtendedPictographicGb(gb: GraphemeBreak): Bool {
    return gb == GraphemeBreak.ExtendedPictographic || gb == GraphemeBreak.EmojiModifierBase
}

// ============================================================================
// 字素簇迭代器
// 严格翻译自 src/unicode/uucode_lib/src/grapheme.zig Iterator
// ============================================================================

/// 字素簇迭代器
public class GraphemeIterator {
    private var bytes: Array<UInt8>
    private var pos: Int64
    private var state: BreakState

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        this.pos = 0
        this.state = BreakState.Default
    }

    /// 是否还有下一个字素簇
    public func hasNext(): Bool {
        return pos < bytes.size
    }

    /// 获取下一个字素簇
    public func next(): GraphemeCluster {
        if (pos >= bytes.size) {
            return GraphemeCluster(start: pos, end: pos, bytes: [])
        }

        let start = pos
        var prevState = BreakState.Default
        var prevGb = graphemeBreakFromBytes(pos)

        // 第一个码点
        let firstDecoded = Utf8.decode(bytes, pos)
        pos += firstDecoded.length

        // 继续添加属于同一字素簇的码点
        while (pos < bytes.size) {
            let currentGb = graphemeBreakFromBytes(pos)
            if (computeGraphemeBreak(prevGb, currentGb, prevState)) {
                break
            }
            let decoded = Utf8.decode(bytes, pos)
            pos += decoded.length
            prevGb = currentGb
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
        state = BreakState.Default
    }

    /// 获取当前位置
    public func position(): Int64 {
        return pos
    }

    /// 获取下一个断点位置 (不消耗数据)
    public func nextGraphemeBreak(): Int64 {
        if (pos >= bytes.size) { return pos }

        var tempPos = pos
        var prevState = BreakState.Default

        // 第一个码点
        let firstLen = Utf8.decode(bytes, tempPos).length
        tempPos += firstLen
        var prevGb = graphemeBreakFromBytes(pos)

        while (tempPos < bytes.size) {
            let currentGb = graphemeBreakFromBytes(tempPos)
            if (computeGraphemeBreak(prevGb, currentGb, prevState)) {
                break
            }
            let decoded = Utf8.decode(bytes, tempPos)
            tempPos += decoded.length
            prevGb = currentGb
        }
        return tempPos
    }

    private func graphemeBreakFromBytes(offset: Int64): GraphemeBreak {
        let decoded = Utf8.decode(bytes, offset)
        return graphemeBreak(decoded.codepoint)
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
