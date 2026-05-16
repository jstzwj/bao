// bao_unicode - uucode 扩展模块根
// 严格翻译自: src/unicode/uucode_lib/src/x/root.zig
//   扩展模块包含:
//     - grapheme_break_no_control: 无控制字符的 Grapheme Break
//     - wcwidth: 字符宽度计算
//   仓颉实现提供等价的扩展功能
package bao_unicode.uucode_lib.x

import bao_unicode.uucode_lib.*

/// GraphemeBreakNoControl 扩展
/// 翻译自: pub const grapheme_break_no_control = @import("./config_x/grapheme_break.zig").grapheme_break_no_control
///   将 control/CR/LF 映射为 other 的 GraphemeBreak 变体
public func graphemeBreakNoControl(gb: GraphemeBreakProperty): GraphemeBreakNoControl {
    match (gb) {
        case GraphemeBreakProperty.Control => return GraphemeBreakNoControl.Other
        case GraphemeBreakProperty.CR => return GraphemeBreakNoControl.Other
        case GraphemeBreakProperty.LF => return GraphemeBreakNoControl.Other
        case GraphemeBreakProperty.Other => return GraphemeBreakNoControl.Other
        case GraphemeBreakProperty.Prepend => return GraphemeBreakNoControl.Prepend
        case GraphemeBreakProperty.RegionalIndicator => return GraphemeBreakNoControl.RegionalIndicator
        case GraphemeBreakProperty.SpacingMark => return GraphemeBreakNoControl.SpacingMark
        case GraphemeBreakProperty.L => return GraphemeBreakNoControl.L
        case GraphemeBreakProperty.V => return GraphemeBreakNoControl.V
        case GraphemeBreakProperty.T => return GraphemeBreakNoControl.T
        case GraphemeBreakProperty.LV => return GraphemeBreakNoControl.LV
        case GraphemeBreakProperty.LVT => return GraphemeBreakNoControl.LVT
        case GraphemeBreakProperty.ZWJ => return GraphemeBreakNoControl.ZWJ
        case GraphemeBreakProperty.Extend => return GraphemeBreakNoControl.IndicConjunctBreakExtend
        case GraphemeBreakProperty.ExtendedPictographic => return GraphemeBreakNoControl.ExtendedPictographic
        case GraphemeBreakProperty.EmojiModifierBase => return GraphemeBreakNoControl.EmojiModifierBase
        case GraphemeBreakProperty.EmojiModifier => return GraphemeBreakNoControl.EmojiModifier
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

    public operator func ==(other: GraphemeBreakNoControl): Bool {
        match (this) {
            case Other => match (other) { case Other => true case _ => false }
            case Prepend => match (other) { case Prepend => true case _ => false }
            case RegionalIndicator => match (other) { case RegionalIndicator => true case _ => false }
            case SpacingMark => match (other) { case SpacingMark => true case _ => false }
            case L => match (other) { case L => true case _ => false }
            case V => match (other) { case V => true case _ => false }
            case T => match (other) { case T => true case _ => false }
            case LV => match (other) { case LV => true case _ => false }
            case LVT => match (other) { case LVT => true case _ => false }
            case ZWJ => match (other) { case ZWJ => true case _ => false }
            case Extend => match (other) { case Extend => true case _ => false }
            case ExtendedPictographic => match (other) { case ExtendedPictographic => true case _ => false }
            case EmojiModifierBase => match (other) { case EmojiModifierBase => true case _ => false }
            case EmojiModifier => match (other) { case EmojiModifier => true case _ => false }
            case IndicConjunctBreakExtend => match (other) { case IndicConjunctBreakExtend => true case _ => false }
            case IndicConjunctBreakLinker => match (other) { case IndicConjunctBreakLinker => true case _ => false }
            case IndicConjunctBreakConsonant => match (other) { case IndicConjunctBreakConsonant => true case _ => false }
        }
    }
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
    match (generalCategory) {
        case GeneralCategory.OtherControl => return 0
        case GeneralCategory.OtherSurrogate => return 0
        case GeneralCategory.SeparatorLine => return 0
        case GeneralCategory.SeparatorParagraph => return 0
        case _ => ()
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
    match (eastAsianWidth) {
        case EastAsianWidthType.Wide => return 2
        case EastAsianWidthType.Fullwidth => return 2
        case _ => ()
    }

    // Regional indicator -> 2
    match (graphemeBreak) {
        case GraphemeBreakProperty.RegionalIndicator => return 2
        case _ => ()
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
    match (generalCategory) {
        case GeneralCategory.MarkNonspacing => return true
        case _ => ()
    }

    // Enclosing mark (Me) -> zero (including keycap)
    match (generalCategory) {
        case GeneralCategory.MarkEnclosing => return true
        case _ => ()
    }

    // Hangul Jamo V and T -> zero
    match (graphemeBreak) {
        case GraphemeBreakProperty.V => return true
        case GraphemeBreakProperty.T => return true
        case _ => ()
    }

    return false
}
