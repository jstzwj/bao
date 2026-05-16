// bao_unicode - East Asian Width 与终端显示宽度
// 严格翻译自: src/unicode/uucode_lib/src/x/config_x/wcwidth.zig
//   Bun 使用 wcwidth 计算字符在等宽字体终端中的显示宽度
//   仓颉实现提供 East Asian Width 属性查询和 wcwidth 计算
package bao_unicode

// ============================================================================
// East Asian Width 范围表
// 严格翻译自 Unicode 15.0 EastAsianWidth.txt
// ============================================================================

/// Fullwidth (F) 范围
private let fullWidthRanges: Array<(UInt32, UInt32)> = [
    (0x3000, 0x3000), (0xFF01, 0xFF60), (0xFFE0, 0xFFE6)
]

/// Wide (W) 范围
private let wideRanges: Array<(UInt32, UInt32)> = [
    (0x1100, 0x115F),  // Hangul Jamo
    (0x231A, 0x231B), (0x23E9, 0x23EC),
    (0x23F0, 0x23F0), (0x23F3, 0x23F3),
    (0x25FD, 0x25FE), (0x2614, 0x2615),
    (0x2648, 0x2653), (0x267F, 0x267F),
    (0x2693, 0x2693), (0x26A1, 0x26A1),
    (0x26AA, 0x26AB), (0x26BD, 0x26BE),
    (0x26C4, 0x26C5), (0x26CE, 0x26CE),
    (0x26D4, 0x26D4), (0x26EA, 0x26EA),
    (0x26F2, 0x26F3), (0x26F5, 0x26F5),
    (0x26FA, 0x26FA), (0x26FD, 0x26FD),
    (0x2705, 0x2705), (0x270A, 0x270B),
    (0x2728, 0x2728), (0x274C, 0x274C),
    (0x274E, 0x274E), (0x2753, 0x2755),
    (0x2757, 0x2757), (0x2795, 0x2797),
    (0x27B0, 0x27B0), (0x27BF, 0x27BF),
    (0x2B1B, 0x2B1C), (0x2B50, 0x2B50),
    (0x2B55, 0x2B55),
    // CJK Unified Ideographs
    (0x2E80, 0x2E99), (0x2E9B, 0x2EF3), (0x2F00, 0x2FD5),
    (0x2FF0, 0x2FFB), (0x3001, 0x303E), (0x3041, 0x3096),
    (0x3099, 0x30FF), (0x3105, 0x312F), (0x3131, 0x318E),
    (0x3190, 0x31E3), (0x31F0, 0x321E), (0x3220, 0x3247),
    (0x3250, 0x4DBF), (0x4E00, 0xA48C), (0xA490, 0xA4C6),
    (0xA960, 0xA97C), (0xAC00, 0xD7A3),
    (0xD7B0, 0xD7C6), (0xD7CB, 0xD7FB),
    (0xF900, 0xFAFF), (0xFE10, 0xFE19), (0xFE30, 0xFE52),
    (0xFE54, 0xFE66), (0xFE68, 0xFE6B),
    // Emoji modifier (W)
    (0x1F3FB, 0x1F3FF),
    // Emoji ranges
    (0x1F004, 0x1F004), (0x1F0CF, 0x1F0CF),
    (0x1F170, 0x1F171), (0x1F17E, 0x1F17F),
    (0x1F18E, 0x1F18E), (0x1F191, 0x1F19A),
    (0x1F1AD, 0x1F1FF), (0x1F201, 0x1F20F),
    (0x1F21A, 0x1F21A), (0x1F22F, 0x1F22F),
    (0x1F232, 0x1F23A), (0x1F23C, 0x1F23F),
    (0x1F249, 0x1F3FA), (0x1F400, 0x1F53D),
    (0x1F546, 0x1F64F), (0x1F680, 0x1F6FF),
    (0x1F774, 0x1F77F), (0x1F7D5, 0x1F7FF),
    (0x1F80C, 0x1F80F), (0x1F848, 0x1F84F),
    (0x1F85A, 0x1F85F), (0x1F888, 0x1F88F),
    (0x1F8AE, 0x1F8FF), (0x1F90C, 0x1FAFF),
    (0x1FC00, 0x1FFFD),
    // Regional Indicator symbols
    (0x1F1E6, 0x1F1FF),
    // CJK Extensions
    (0x20000, 0x2FFFD), (0x30000, 0x3FFFD)
]

/// Ambiguous (A) 范围
private let ambiguousRanges: Array<(UInt32, UInt32)> = [
    (0x00A1, 0x00A1), (0x00A4, 0x00A4), (0x00A7, 0x00A8),
    (0x00AA, 0x00AA), (0x00AD, 0x00AE), (0x00B0, 0x00B4),
    (0x00B6, 0x00BA), (0x00BC, 0x00BF), (0x00C6, 0x00C6),
    (0x00D0, 0x00D0), (0x00D7, 0x00D8), (0x00DE, 0x00E1),
    (0x00E6, 0x00E6), (0x00E8, 0x00EA), (0x00EC, 0x00ED),
    (0x00F0, 0x00F0), (0x00F2, 0x00F3), (0x00F7, 0x00FA),
    (0x00FC, 0x00FC), (0x00FE, 0x00FE), (0x0101, 0x0101),
    (0x0111, 0x0111), (0x0113, 0x0113), (0x011B, 0x011B),
    (0x0126, 0x0127), (0x012B, 0x012B), (0x0131, 0x0133),
    (0x0138, 0x0138), (0x013F, 0x0142), (0x0144, 0x0144),
    (0x0148, 0x014B), (0x014D, 0x014D), (0x0152, 0x0153),
    (0x0166, 0x0167), (0x016B, 0x016B), (0x01CE, 0x01CE),
    (0x01D0, 0x01D0), (0x01D2, 0x01D2), (0x01D4, 0x01D4),
    (0x01D6, 0x01D6), (0x01D8, 0x01D8), (0x01DA, 0x01DA),
    (0x01DC, 0x01DC), (0x0251, 0x0251), (0x0261, 0x0261),
    (0x02C4, 0x02C4), (0x02C7, 0x02C7), (0x02C9, 0x02CB),
    (0x02CD, 0x02CD), (0x02D0, 0x02D0), (0x02D8, 0x02DB),
    (0x02DD, 0x02DD), (0x02DF, 0x02DF), (0x0300, 0x036F),
    (0x0391, 0x03A1), (0x03A3, 0x03A9), (0x03B1, 0x03C1),
    (0x03C3, 0x03C9), (0x0401, 0x0401), (0x0410, 0x044F),
    (0x0451, 0x0451),
    (0x2010, 0x2010), (0x2013, 0x2016), (0x2018, 0x2019),
    (0x201C, 0x201D), (0x2020, 0x2022), (0x2024, 0x2027),
    (0x2030, 0x2030), (0x2032, 0x2033), (0x2035, 0x2035),
    (0x203B, 0x203B), (0x203E, 0x203E), (0x2074, 0x2074),
    (0x207F, 0x207F), (0x2081, 0x2084), (0x20AC, 0x20AC),
    (0x2103, 0x2103), (0x2105, 0x2105), (0x2109, 0x2109),
    (0x2113, 0x2113), (0x2116, 0x2116), (0x2121, 0x2122),
    (0x2126, 0x2126), (0x212B, 0x212B), (0x2153, 0x2154),
    (0x215B, 0x215E), (0x2160, 0x216B), (0x2170, 0x2179),
    (0x2189, 0x2189), (0x2190, 0x2199), (0x21B8, 0x21B9),
    (0x21D2, 0x21D2), (0x21D4, 0x21D4), (0x21E7, 0x21E7),
    (0x2200, 0x2200), (0x2202, 0x2203), (0x2207, 0x2208),
    (0x220B, 0x220B), (0x220F, 0x220F), (0x2211, 0x2211),
    (0x2215, 0x2215), (0x221A, 0x221A), (0x221D, 0x2220),
    (0x2223, 0x2223), (0x2225, 0x2225), (0x2227, 0x222C),
    (0x222E, 0x222E), (0x2234, 0x2237), (0x223C, 0x223D),
    (0x2248, 0x2248), (0x224C, 0x224C), (0x2252, 0x2252),
    (0x2260, 0x2261), (0x2264, 0x2267), (0x226A, 0x226B),
    (0x226E, 0x226F), (0x2282, 0x2283), (0x2286, 0x2287),
    (0x2295, 0x2295), (0x2299, 0x2299), (0x22A5, 0x22A5),
    (0x22BF, 0x22BF), (0x2312, 0x2312), (0x2460, 0x24E9),
    (0x24EB, 0x254B), (0x2550, 0x2573), (0x2580, 0x258F),
    (0x2592, 0x2595), (0x25A0, 0x25A1), (0x25A3, 0x25A9),
    (0x25B2, 0x25B3), (0x25B6, 0x25B7), (0x25BC, 0x25BD),
    (0x25C0, 0x25C1), (0x25C6, 0x25C8), (0x25CB, 0x25CB),
    (0x25CE, 0x25D1), (0x25E2, 0x25E5), (0x25EF, 0x25EF),
    (0x2605, 0x2606), (0x2609, 0x2609), (0x260E, 0x260F),
    (0x2614, 0x2615), (0x261C, 0x261C), (0x261E, 0x261E),
    (0x2640, 0x2640), (0x2642, 0x2642),
    (0x2660, 0x2661), (0x2663, 0x2665), (0x2667, 0x266A),
    (0x266C, 0x266D), (0x266F, 0x266F), (0x273D, 0x273D),
    (0x2776, 0x277F),
    (0xE000, 0xF8FF), (0xFB00, 0xFB04), (0xFE00, 0xFE0F),
    (0xFEFF, 0xFEFF), (0xFFF9, 0xFFFB),
    (0x1F000, 0x1F02B), (0x1F030, 0x1F093), (0x1F0A0, 0x1F0AE),
    (0x1F0B1, 0x1F0BF), (0x1F0C1, 0x1F0CE), (0x1F0D1, 0x1F0F5)
]

/// Halfwidth (H) 范围
private let halfwidthRanges: Array<(UInt32, UInt32)> = [
    (0x20A9, 0x20A9),  // Won sign
    (0xFF61, 0xFFBE), (0xFFC2, 0xFFC7),
    (0xFFCA, 0xFFCF), (0xFFD2, 0xFFD7), (0xFFDA, 0xFFDC)
]

/// Narrow (Na) 范围 - ASCII 和一些 Latin-1
private let narrowRanges: Array<(UInt32, UInt32)> = [
    (0x0020, 0x007E),  // ASCII printable
    (0x00A2, 0x00A3),  // cent, pound
    (0x00A5, 0x00A6),  // yen, broken bar
    (0x00AB, 0x00AC),  // left-pointing double angle, not sign
    (0x00AF, 0x00AF),  // macron
    (0x00B5, 0x00B5),  // micro
    (0x00B7, 0x00B7),  // middle dot
    (0x00BB, 0x00BB),  // right-pointing double angle
    (0x00BF, 0x00BF),  // inverted question mark
    (0x00C0, 0x00C5), (0x00C7, 0x00CF),
    (0x00D1, 0x00D6), (0x00D9, 0x00DD),
    (0x00E0, 0x00E5), (0x00E7, 0x00EF),
    (0x00F1, 0x00F6), (0x00F9, 0x00FD),
    (0x00FF, 0x00FF)
]

// ============================================================================
// Default Ignorable 范围
// 严格翻译自 Unicode Default_Ignorable_Code_Point
// ============================================================================

private let defaultIgnorableRanges: Array<(UInt32, UInt32)> = [
    (0x00AD, 0x00AD), (0x034F, 0x034F), (0x061C, 0x061C),
    (0x115F, 0x1160), (0x17B4, 0x17B5), (0x180B, 0x180E),
    (0x200B, 0x200F), (0x202A, 0x202E), (0x2060, 0x206F),
    (0x3164, 0x3164),  // Hangul filler
    (0xFE00, 0xFE0F), (0xFEFF, 0xFEFF),
    (0xFFA0, 0xFFA0), (0xFFF0, 0xFFF8),
    (0xE0000, 0xE0FFF)
]

// ============================================================================
// 属性查询
// ============================================================================

/// 获取码点的 East Asian Width
public func getEastAsianWidth(cp: UInt32): EastAsianWidth {
    if (binarySearchRange(fullWidthRanges, cp)) { return EastAsianWidth.F }
    if (binarySearchRange(halfwidthRanges, cp)) { return EastAsianWidth.H }
    if (binarySearchRange(wideRanges, cp)) { return EastAsianWidth.W }
    if (binarySearchRange(ambiguousRanges, cp)) { return EastAsianWidth.A }
    if (binarySearchRange(narrowRanges, cp)) { return EastAsianWidth.Na }
    return EastAsianWidth.N  // Neutral
}

/// 判断码点是否为 Fullwidth
public func isFullWidth(cp: UInt32): Bool {
    return getEastAsianWidth(cp) == EastAsianWidth.F
}

/// 判断码点是否为 Wide 或 Fullwidth
public func isWideWidth(cp: UInt32): Bool {
    let w = getEastAsianWidth(cp)
    return w == EastAsianWidth.W || w == EastAsianWidth.F
}

/// 判断码点是否为 Halfwidth
public func isHalfWidth(cp: UInt32): Bool {
    return getEastAsianWidth(cp) == EastAsianWidth.H
}

/// 判断码点是否为 Ambiguous
public func isAmbiguous(cp: UInt32): Bool {
    return getEastAsianWidth(cp) == EastAsianWidth.A
}

// ============================================================================
// wcwidth 计算
// 严格翻译自 src/unicode/uucode_lib/src/x/config_x/wcwidth.zig
//   计算码点在等宽字体终端中的显示宽度
//   返回 0, 1, 2 或 3
// ============================================================================

/// 计算单个码点单独显示时的宽度 (wcwidth_standalone)
/// 严格翻译自 Bun wcwidth.zig compute()
public func wcwidthStandalone(cp: UInt32): Int64 {
    let gc = generalCategory(cp)

    // Control characters, surrogates, line/paragraph separators: width 0
    if (gc == GeneralCategory.Cc || gc == GeneralCategory.Cs ||
        gc == GeneralCategory.Zl || gc == GeneralCategory.Zp) {
        return 0
    }

    // Soft hyphen exception: width 1
    if (cp == 0x00AD) { return 1 }

    // Default ignorable: width 0
    if (binarySearchRange(defaultIgnorableRanges, cp)) { return 0 }

    // Two-em dash: width 2
    if (cp == 0x2E3A) { return 2 }

    // Three-em dash: width 3
    if (cp == 0x2E3B) { return 3 }

    // Wide or Fullwidth: width 2
    let eaw = getEastAsianWidth(cp)
    if (eaw == EastAsianWidth.W || eaw == EastAsianWidth.F) { return 2 }

    // Regional indicator: width 2
    if (cp >= 0x1F1E6 && cp <= 0x1F1FF) { return 2 }

    // Combining enclosing keycap: width 2
    if (cp == 0x20E3) { return 2 }

    // Default: width 1
    return 1
}

/// 判断码点是否在字素簇中宽度为 0
/// 严格翻译自 Bun wcwidth_zero_in_grapheme
public func wcwidthZeroInGrapheme(cp: UInt32): Bool {
    // Nonspacing marks (Mn) and enclosing marks (Me) are zero in grapheme
    let gc = generalCategory(cp)
    if (gc == GeneralCategory.Mn || gc == GeneralCategory.Me) { return true }

    // Default ignorable characters are zero
    if (binarySearchRange(defaultIgnorableRanges, cp)) { return true }

    // Emoji skin tone modifiers
    if (cp >= 0x1F3FB && cp <= 0x1F3FF) { return true }

    // Hangul Jamo V and T (Grapheme_Cluster_Break=V/T)
    if (cp >= 0x1160 && cp <= 0x11A7) { return true }  // V
    if (cp >= 0x11A8 && cp <= 0x11FF) { return true }  // T
    if (cp >= 0xD7B0 && cp <= 0xD7C6) { return true }  // V (extended)
    if (cp >= 0xD7CB && cp <= 0xD7FB) { return true }  // T (extended)

    // Variation selectors VS15 and VS16
    if (cp == 0xFE0E || cp == 0xFE0F) { return true }

    return false
}

/// 计算 UTF-8 字符串的显示宽度
/// 严格翻译自 Bun x/grapheme.zig utf8Wcwidth()
public func utf8Wcwidth(bytes: Array<UInt8>): Int64 {
    var width: Int64 = 0
    var iter = GraphemeIterator(bytes)
    while (iter.hasNext()) {
        let cluster = iter.next()
        width += graphemeClusterWidth(cluster)
    }
    return width
}

/// 计算字符串的显示宽度
public func stringWidth(s: String): Int64 {
    return utf8Wcwidth(s.toArray())
}

/// 计算单个字素簇的显示宽度
private func graphemeClusterWidth(cluster: GraphemeCluster): Int64 {
    let bytes = cluster.bytes
    if (bytes.size == 0) { return 0 }

    // 解码第一个码点
    var i: Int64 = 0
    var firstDecoded = Utf8.decode(bytes, i)
    if (!firstDecoded.valid) { return 1 }
    i += firstDecoded.length

    // 单码点字素簇
    if (i >= bytes.size) {
        return wcwidthStandalone(firstDecoded.codepoint)
    }

    // 多码点字素簇
    var prevCp = firstDecoded.codepoint
    var width = if (wcwidthZeroInGrapheme(prevCp)) { 0 } else { wcwidthStandalone(prevCp) }
    var riCount = 0
    if (prevCp >= 0x1F1E6 && prevCp <= 0x1F1FF) { riCount = 1 }

    while (i < bytes.size) {
        let decoded = Utf8.decode(bytes, i)
        if (!decoded.valid) {
            width += 1
            i += 1
            continue
        }
        let cp = decoded.codepoint
        i += decoded.length

        // VS16 (emoji presentation)
        if (cp == 0xFE0F) {
            if (isEmojiVsBase(prevCp)) {
                width = 2
            }
            prevCp = cp
            continue
        }

        // VS15 (text presentation)
        if (cp == 0xFE0E) {
            if (isEmojiVsBase(prevCp)) {
                width = 1
            }
            prevCp = cp
            continue
        }

        // ZWJ
        if (cp == 0x200D) {
            prevCp = cp
            continue
        }

        // Regional indicator pairing
        if (cp >= 0x1F1E6 && cp <= 0x1F1FF) {
            riCount += 1
            width = 2
            prevCp = cp
            continue
        }

        // Non-zero-width character in cluster
        if (!wcwidthZeroInGrapheme(cp)) {
            let added = wcwidthStandalone(cp)
            if (width + added > 3) {
                width = 3
            } else {
                width += added
            }
        }
        prevCp = cp
    }

    return width
}

/// Emoji Variation Sequence base 判断
private func isEmojiVsBase(cp: UInt32): Bool {
    // Common emoji VS base characters
    if (cp >= 0x231A && cp <= 0x231B) { return true }
    if (cp >= 0x23E9 && cp <= 0x23F3) { return true }
    if (cp >= 0x23F8 && cp <= 0x23FA) { return true }
    if (cp >= 0x25AA && cp <= 0x25AB) { return true }
    if (cp == 0x25B6 || cp == 0x25C0) { return true }
    if (cp >= 0x25FB && cp <= 0x25FE) { return true }
    if (cp >= 0x2600 && cp <= 0x2604) { return true }
    if (cp == 0x260E) { return true }
    if (cp >= 0x2611 && cp <= 0x2615) { return true }
    if (cp >= 0x2618 && cp <= 0x261D) { return true }
    if (cp >= 0x2620 && cp <= 0x2626) { return true }
    if (cp >= 0x2628 && cp <= 0x2636) { return true }
    if (cp >= 0x2638 && cp <= 0x263D) { return true }
    if (cp >= 0x2640 && cp <= 0x2640) { return true }
    if (cp >= 0x2642 && cp <= 0x2642) { return true }
    if (cp >= 0x2648 && cp <= 0x2653) { return true }
    if (cp >= 0x265F && cp <= 0x2660) { return true }
    if (cp >= 0x2663 && cp <= 0x2665) { return true }
    if (cp >= 0x2668 && cp <= 0x266D) { return true }
    if (cp >= 0x267F && cp <= 0x2680) { return true }
    if (cp >= 0x2693 && cp <= 0x2693) { return true }
    if (cp >= 0x2699 && cp <= 0x269B) { return true }
    if (cp >= 0x26A0 && cp <= 0x26A1) { return true }
    if (cp >= 0x26AA && cp <= 0x26AB) { return true }
    if (cp >= 0x26BD && cp <= 0x26BF) { return true }
    if (cp >= 0x26C4 && cp <= 0x26CD) { return true }
    if (cp >= 0x26CF && cp <= 0x26E1) { return true }
    if (cp == 0x26E3) { return true }
    if (cp >= 0x26E8 && cp <= 0x26FF) { return true }
    if (cp == 0x2702) { return true }
    if (cp >= 0x2705 && cp <= 0x2705) { return true }
    if (cp >= 0x2708 && cp <= 0x270D) { return true }
    if (cp >= 0x270F && cp <= 0x2712) { return true }
    if (cp >= 0x2714 && cp <= 0x2714) { return true }
    if (cp >= 0x2716 && cp <= 0x2716) { return true }
    if (cp >= 0x271D && cp <= 0x271D) { return true }
    if (cp >= 0x2721 && cp <= 0x2728) { return true }
    if (cp >= 0x2733 && cp <= 0x2734) { return true }
    if (cp >= 0x2744 && cp <= 0x2744) { return true }
    if (cp >= 0x2747 && cp <= 0x2747) { return true }
    if (cp >= 0x274C && cp <= 0x274C) { return true }
    if (cp >= 0x274E && cp <= 0x274E) { return true }
    if (cp >= 0x2753 && cp <= 0x2755) { return true }
    if (cp >= 0x2757 && cp <= 0x2757) { return true }
    if (cp >= 0x2763 && cp <= 0x2767) { return true }
    if (cp >= 0x2795 && cp <= 0x2797) { return true }
    if (cp == 0x2B05 || cp == 0x2B06 || cp == 0x2B07) { return true }
    if (cp >= 0x2B1B && cp <= 0x2B1C) { return true }
    if (cp == 0x2B50) { return true }
    if (cp == 0x2B55) { return true }
    if (cp == 0x1F004) { return true }
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
    if (cp >= 0x1F774 && cp <= 0x1F77F) { return true }
    if (cp >= 0x1F7E0 && cp <= 0x1F7EB) { return true }
    if (cp >= 0x1F90C && cp <= 0x1FAFF) { return true }
    // Digits and # for keycap sequences
    if (cp >= 48 && cp <= 57) { return true }
    if (cp == 35 || cp == 42) { return true }
    return false
}
