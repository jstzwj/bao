// bao_unicode - uucode 扩展模块根
// 严格翻译自: src/unicode/uucode_lib/src/x/root.zig
//   扩展模块包含:
//     - grapheme_break_no_control: 无控制字符的 Grapheme Break
//     - wcwidth: 字符宽度计算
//   仓颉实现提供等价的扩展功能
package bao_unicode.uucode_lib.x

/// GraphemeBreakNoControl 扩展
/// 翻译自: pub const grapheme_break_no_control = @import("./config_x/grapheme_break.zig").grapheme_break_no_control
///   将 control/CR/LF 映射为 other 的 GraphemeBreak 变体
public func graphemeBreakNoControl(gb: GraphemeBreakProperty): GraphemeBreakNoControl {
    match (gb) {
        case Control | CR | LF => return GraphemeBreakNoControl.Other
        case Other => return GraphemeBreakNoControl.Other
        case Prepend => return GraphemeBreakNoControl.Prepend
        case RegionalIndicator => return GraphemeBreakNoControl.RegionalIndicator
        case SpacingMark => return GraphemeBreakNoControl.SpacingMark
        case L => return GraphemeBreakNoControl.L
        case V => return GraphemeBreakNoControl.V
        case T => return GraphemeBreakNoControl.T
        case LV => return GraphemeBreakNoControl.LV
        case LVT => return GraphemeBreakNoControl.LVT
        case ZWJ => return GraphemeBreakNoControl.ZWJ
        case Extend => return GraphemeBreakNoControl.IndicConjunctBreakExtend
        case ExtendedPictographic => return GraphemeBreakNoControl.ExtendedPictographic
        case EmojiModifierBase => return GraphemeBreakNoControl.EmojiModifierBase
        case EmojiModifier => return GraphemeBreakNoControl.EmojiModifier
    }
    return GraphemeBreakNoControl.Other
}

/// GraphemeBreakNoControl 枚举
/// 翻译自: x/types.x.zig GraphemeBreakNoControl
///   与 GraphemeBreakProperty 类似但移除了 Control/CR/LF
public enum GraphemeBreakNoControl {
    | Other
    | Prepend
    | RegionalIndicator
    | SpacingMark
    | L
    | V
    | T
    | LV
    | LVT
    | ZWJ
    | Extend  // ZWNJ + Indic extend + Indic linker
    | ExtendedPictographic
    | EmojiModifierBase
    | EmojiModifier
    | IndicConjunctBreakExtend
    | IndicConjunctBreakLinker
    | IndicConjunctBreakConsonant
}

/// wcwidth 计算函数
/// 翻译自: pub const wcwidth = @import("./config_x/wcwidth.zig").wcwidth
///   计算码点在等宽字体中的预期宽度
///   wcwidth_standalone: 单独码点的宽度
///   wcwidth_zero_in_grapheme: 在字素簇中是否零宽度

/// 计算单独码点的宽度
/// 翻译自: wcwidth 扩展的 wcwidth_standalone
///   control/surrogate/line_separator/paragraph_separator: 0
///   soft_hyphen: 1
///   default_ignorable: 0
///   two-em dash: 2, three-em dash: 3
///   wide/fullwidth: 2
///   regional_indicator: 2
///   其他: 1
public func wcwidthStandalone(cp: UInt32, generalCategory: GeneralCategory,
                               eastAsianWidth: EastAsianWidthType,
                               isDefaultIgnorable: Bool,
                               isEmojiModifier: Bool,
                               graphemeBreak: GraphemeBreakProperty): UInt8 {
    // Control / Surrogate / Line/Paragraph separator -> 0
    if (generalCategory == GeneralCategory.OtherControl ||
        generalCategory == GeneralCategory.OtherSurrogate ||
        generalCategory == GeneralCategory.SeparatorLine ||
        generalCategory == GeneralCategory.SeparatorParagraph) {
        return 0
    }

    // Soft hyphen exception -> 1
    if (cp == 0x00AD) {
        return 1
    }

    // Default ignorable -> 0
    if (isDefaultIgnorable) {
        return 0
    }

    // Special widths
    if (cp == 0x2E3A) { return 2 } // Two-em dash
    if (cp == 0x2E3B) { return 3 } // Three-em dash

    // East Asian Wide/Fullwidth -> 2
    if (eastAsianWidth == EastAsianWidthType.Wide ||
        eastAsianWidth == EastAsianWidthType.Fullwidth) {
        return 2
    }

    // Regional indicator -> 2
    if (graphemeBreak == GraphemeBreakProperty.RegionalIndicator) {
        return 2
    }

    // Combining enclosing keycap -> 2
    if (cp == 0x20E3) {
        return 2
    }

    // Default -> 1
    return 1
}

/// 计算在字素簇中是否零宽度
/// 翻译自: wcwidth 扩展的 wcwidth_zero_in_grapheme
public func wcwidthZeroInGrapheme(cp: UInt32, generalCategory: GeneralCategory,
                                   graphemeBreak: GraphemeBreakProperty,
                                   isEmojiModifier: Bool,
                                   isDefaultIgnorable: Bool): Bool {
    // Default ignorable (including ZWJ, VS) -> zero
    if (isDefaultIgnorable) { return true }

    // Emoji modifier -> zero in grapheme
    if (isEmojiModifier) { return true }

    // Nonspacing mark (Mn) -> zero
    if (generalCategory == GeneralCategory.MarkNonspacing) { return true }

    // Enclosing mark (Me) -> zero (including keycap)
    if (generalCategory == GeneralCategory.MarkEnclosing) { return true }

    // Hangul Jamo V and T -> zero
    if (graphemeBreak == GraphemeBreakProperty.V ||
        graphemeBreak == GraphemeBreakProperty.T) { return true }

    return false
}
