// bao_unicode - Unicode 字符属性查找表
// 严格翻译自: src/unicode/uucode_lib/src/config.zig, src/unicode/uucode_lib/src/types.zig
//   Bun 使用 3 级查找表 (stage1/stage2/stage3) 映射码点到属性
//   仓颉实现使用范围对 (Range Pair) 数组进行二分查找
package bao_unicode

// ============================================================================
// Unicode 常量
// 严格翻译自 src/unicode/uucode_lib/src/config.zig
// ============================================================================

/// Unicode 最大码点
public let MAX_CODE_POINT: UInt32 = 0x10FFFF

/// 零宽非连接符
public let ZERO_WIDTH_NON_JOINER: UInt32 = 0x200C

/// 零宽连接符
public let ZERO_WIDTH_JOINER: UInt32 = 0x200D

/// 替换字符
public let REPLACEMENT_CHARACTER: UInt32 = 0xFFFD

// ============================================================================
// Unicode 通用类别枚举
// 严格翻译自 src/unicode/uucode_lib/src/types.zig GeneralCategory
// ============================================================================

/// Unicode General_Category 属性
public enum GeneralCategory {
    | Lu  // Letter, Uppercase
    | Ll  // Letter, Lowercase
    | Lt  // Letter, Titlecase
    | Lm  // Letter, Modifier
    | Lo  // Letter, Other
    | Mn  // Mark, Nonspacing
    | Mc  // Mark, Spacing Combining
    | Me  // Mark, Enclosing
    | Nd  // Number, Decimal Digit
    | Nl  // Number, Letter
    | No  // Number, Other
    | Pc  // Punctuation, Connector
    | Pd  // Punctuation, Dash
    | Ps  // Punctuation, Open
    | Pe  // Punctuation, Close
    | Pi  // Punctuation, Initial quote
    | Pf  // Punctuation, Final quote
    | Po  // Punctuation, Other
    | Sm  // Symbol, Math
    | Sc  // Symbol, Currency
    | Sk  // Symbol, Modifier
    | So  // Symbol, Other
    | Zs  // Separator, Space
    | Zl  // Separator, Line
    | Zp  // Separator, Paragraph
    | Cc  // Other, Control
    | Cf  // Other, Format
    | Cs  // Other, Surrogate
    | Co  // Other, Private Use
    | Cn  // Other, Not Assigned

    public operator func ==(other: GeneralCategory): Bool {
        match (this) {
            case Lu => match (other) { case Lu => true case _ => false }
            case Ll => match (other) { case Ll => true case _ => false }
            case Lt => match (other) { case Lt => true case _ => false }
            case Lm => match (other) { case Lm => true case _ => false }
            case Lo => match (other) { case Lo => true case _ => false }
            case Mn => match (other) { case Mn => true case _ => false }
            case Mc => match (other) { case Mc => true case _ => false }
            case Me => match (other) { case Me => true case _ => false }
            case Nd => match (other) { case Nd => true case _ => false }
            case Nl => match (other) { case Nl => true case _ => false }
            case No => match (other) { case No => true case _ => false }
            case Pc => match (other) { case Pc => true case _ => false }
            case Pd => match (other) { case Pd => true case _ => false }
            case Ps => match (other) { case Ps => true case _ => false }
            case Pe => match (other) { case Pe => true case _ => false }
            case Pi => match (other) { case Pi => true case _ => false }
            case Pf => match (other) { case Pf => true case _ => false }
            case Po => match (other) { case Po => true case _ => false }
            case Sm => match (other) { case Sm => true case _ => false }
            case Sc => match (other) { case Sc => true case _ => false }
            case Sk => match (other) { case Sk => true case _ => false }
            case So => match (other) { case So => true case _ => false }
            case Zs => match (other) { case Zs => true case _ => false }
            case Zl => match (other) { case Zl => true case _ => false }
            case Zp => match (other) { case Zp => true case _ => false }
            case Cc => match (other) { case Cc => true case _ => false }
            case Cf => match (other) { case Cf => true case _ => false }
            case Cs => match (other) { case Cs => true case _ => false }
            case Co => match (other) { case Co => true case _ => false }
            case Cn => match (other) { case Cn => true case _ => false }
        }
    }
}

// ============================================================================
// East Asian Width 枚举
// 严格翻译自 src/unicode/uucode_lib/src/types.zig EastAsianWidth
// ============================================================================

/// Unicode East_Asian_Width 属性
public enum EastAsianWidth {
    | Na  // Neutral (Narrow)
    | N   // Neutral
    | A   // Ambiguous
    | W   // Wide
    | H   // Halfwidth
    | F   // Fullwidth

    public operator func ==(other: EastAsianWidth): Bool {
        match (this) {
            case Na => match (other) { case Na => true case _ => false }
            case N => match (other) { case N => true case _ => false }
            case A => match (other) { case A => true case _ => false }
            case W => match (other) { case W => true case _ => false }
            case H => match (other) { case H => true case _ => false }
            case F => match (other) { case F => true case _ => false }
        }
    }
}

// ============================================================================
// Grapheme Break 属性枚举
// 严格翻译自 src/unicode/uucode_lib/src/types.zig GraphemeBreak
// ============================================================================

/// Unicode Grapheme_Cluster_Break 属性
/// 严格对应 Bun uucode GraphemeBreak
public enum GraphemeBreak {
    | Other
    | Control
    | Prepend
    | CR
    | LF
    | RegionalIndicator
    | SpacingMark
    | L
    | V
    | T
    | LV
    | LVT
    | ZWJ
    | ZWNJ
    | ExtendedPictographic
    | EmojiModifierBase
    | EmojiModifier
    | IndicConjunctBreakExtend
    | IndicConjunctBreakLinker
    | IndicConjunctBreakConsonant

    public operator func ==(other: GraphemeBreak): Bool {
        match (this) {
            case Other => match (other) { case Other => true case _ => false }
            case Control => match (other) { case Control => true case _ => false }
            case Prepend => match (other) { case Prepend => true case _ => false }
            case CR => match (other) { case CR => true case _ => false }
            case LF => match (other) { case LF => true case _ => false }
            case RegionalIndicator => match (other) { case RegionalIndicator => true case _ => false }
            case SpacingMark => match (other) { case SpacingMark => true case _ => false }
            case L => match (other) { case L => true case _ => false }
            case V => match (other) { case V => true case _ => false }
            case T => match (other) { case T => true case _ => false }
            case LV => match (other) { case LV => true case _ => false }
            case LVT => match (other) { case LVT => true case _ => false }
            case ZWJ => match (other) { case ZWJ => true case _ => false }
            case ZWNJ => match (other) { case ZWNJ => true case _ => false }
            case ExtendedPictographic => match (other) { case ExtendedPictographic => true case _ => false }
            case EmojiModifierBase => match (other) { case EmojiModifierBase => true case _ => false }
            case EmojiModifier => match (other) { case EmojiModifier => true case _ => false }
            case IndicConjunctBreakExtend => match (other) { case IndicConjunctBreakExtend => true case _ => false }
            case IndicConjunctBreakLinker => match (other) { case IndicConjunctBreakLinker => true case _ => false }
            case IndicConjunctBreakConsonant => match (other) { case IndicConjunctBreakConsonant => true case _ => false }
        }
    }

    public operator func !=(other: GraphemeBreak): Bool {
        return !(this == other)
    }
}

// ============================================================================
// Grapheme Break 状态枚举
// 严格翻译自 src/unicode/uucode_lib/src/grapheme.zig BreakState
// ============================================================================

/// Grapheme break 算法状态
public enum BreakState {
    | Default
    | RegionalIndicator
    | ExtendedPictographic
    | IndicConjunctBreakConsonant
    | IndicConjunctBreakLinker

    public operator func ==(other: BreakState): Bool {
        match (this) {
            case Default => match (other) { case Default => true case _ => false }
            case RegionalIndicator => match (other) { case RegionalIndicator => true case _ => false }
            case ExtendedPictographic => match (other) { case ExtendedPictographic => true case _ => false }
            case IndicConjunctBreakConsonant => match (other) { case IndicConjunctBreakConsonant => true case _ => false }
            case IndicConjunctBreakLinker => match (other) { case IndicConjunctBreakLinker => true case _ => false }
        }
    }
}

// ============================================================================
// 空白字符判断
// 严格翻译自 ECMAScript WhiteSpace + Unicode Zs 类别
// ============================================================================

/// Unicode 空白字符范围表
/// 包含 ECMAScript 定义的空白字符 + Unicode Zs 类别
private let whiteSpaceRanges: Array<(UInt32, UInt32)> = [
    (0x0009, 0x000D),  // TAB..CR
    (0x0020, 0x0020),  // SPACE
    (0x0085, 0x0085),  // NEL
    (0x00A0, 0x00A0),  // NO-BREAK SPACE
    (0x1680, 0x1680),  // OGHAM SPACE MARK
    (0x2000, 0x200A),  // EN QUAD..HAIR SPACE
    (0x2028, 0x2028),  // LINE SEPARATOR
    (0x2029, 0x2029),  // PARAGRAPH SEPARATOR
    (0x202F, 0x202F),  // NARROW NO-BREAK SPACE
    (0x205F, 0x205F),  // MEDIUM MATHEMATICAL SPACE
    (0x3000, 0x3000),  // IDEOGRAPHIC SPACE
    (0xFEFF, 0xFEFF)   // ZERO WIDTH NO-BREAK SPACE (BOM)
]

/// 判断码点是否为空白字符
/// 对应 Unicode White_Space 属性
public func isWhiteSpace(cp: UInt32): Bool {
    return binarySearchRange(whiteSpaceRanges, cp)
}

// ============================================================================
// 行终止符判断
// 严格翻译自 ECMAScript LineTerminator
// ============================================================================

/// ECMAScript 行终止符
private let lineTerminatorRanges: Array<(UInt32, UInt32)> = [
    (0x000A, 0x000A),  // LINE FEED (LF)
    (0x000D, 0x000D),  // CARRIAGE RETURN (CR)
    (0x2028, 0x2028),  // LINE SEPARATOR
    (0x2029, 0x2029)   // PARAGRAPH SEPARATOR
]

/// 判断码点是否为行终止符
/// 对应 ECMAScript LineTerminator
public func isLineTerminator(cp: UInt32): Bool {
    return binarySearchRange(lineTerminatorRanges, cp)
}

// ============================================================================
// 二分查找工具
// ============================================================================

/// 在范围对数组中二分查找码点
/// 范围表格式: Array<(start, end)>，已排序
public func binarySearchRange(ranges: Array<(UInt32, UInt32)>, cp: UInt32): Bool {
    var lo: Int64 = 0
    var hi: Int64 = ranges.size - 1
    while (lo <= hi) {
        let mid = lo + (hi - lo) / 2
        let (start, end) = ranges[mid]
        if (cp < start) {
            hi = mid - 1
        } else if (cp > end) {
            lo = mid + 1
        } else {
            return true
        }
    }
    return false
}

/// 在 (start, end, value) 三元组数组中查找码点对应的值
/// 返回 -1 表示未找到
public func binarySearchLookup(table: Array<(UInt32, UInt32, Int32)>, cp: UInt32): Int32 {
    var lo: Int64 = 0
    var hi: Int64 = table.size - 1
    while (lo <= hi) {
        let mid = lo + (hi - lo) / 2
        let (start, end, value) = table[mid]
        if (cp < start) {
            hi = mid - 1
        } else if (cp > end) {
            lo = mid + 1
        } else {
            return value
        }
    }
    return -1
}
