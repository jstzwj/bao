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
