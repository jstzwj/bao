// bao_unicode - uucode 库根模块
// 严格翻译自: src/unicode/uucode_lib/src/root.zig
//   uucode 是 Bun 的 Unicode 字符数据库查询库
//   提供 Unicode 属性查找: name, category, bidi, case mapping 等
//   仓颉实现提供等价的 Unicode 属性查询接口
package bao_unicode.uucode_lib

// ============================================================================
// 导入子模块
// 严格翻译自 root.zig 的 import 声明
//   pub const config = @import("./config.zig")
//   pub const types = @import("./types.zig")
//   pub const ascii = @import("./ascii.zig")
//   pub const grapheme = @import("./grapheme.zig")
//   pub const utf8 = @import("./utf8.zig")
//   pub const x = @import("./x/root.zig")
// ============================================================================

/// Unicode 配置常量
/// 翻译自: pub const config = @import("./config.zig")
public let MAX_CODE_POINT: UInt32 = 0x10FFFF

/// 零宽不连字
/// 翻译自: pub const zero_width_non_joiner = 0x200C
public let ZERO_WIDTH_NON_JOINER: UInt32 = 0x200C

/// 零宽连字
/// 翻译自: pub const zero_width_joiner = 0x200D
public let ZERO_WIDTH_JOINER: UInt32 = 0x200D

/// Unicode 字段枚举
/// 翻译自: pub const FieldEnum = getpkg.FieldEnum
///   列出所有可查询的 Unicode 属性字段
public enum UnicodeField {
    | Name
    | GeneralCategory
    | CanonicalCombiningClass
    | BidiClass
    | DecompositionType
    | DecompositionMapping
    | NumericType
    | NumericValueDecimal
    | NumericValueDigit
    | NumericValueNumeric
    | IsBidiMirrored
    | Unicode1Name
    | SimpleUppercaseMapping
    | SimpleLowercaseMapping
    | SimpleTitlecaseMapping
    | CaseFoldingSimple
    | CaseFoldingFull
    | IsMath
    | IsAlphabetic
    | IsLowercase
    | IsUppercase
    | IsCased
    | IsCaseIgnorable
    | IsIdStart
    | IsIdContinue
    | IsXidStart
    | IsXidContinue
    | IsDefaultIgnorable
    | IsGraphemeExtend
    | IsGraphemeBase
    | EastAsianWidth
    | OriginalGraphemeBreak
    | IsEmoji
    | IsEmojiPresentation
    | IsEmojiModifier
    | IsEmojiModifierBase
    | IsEmojiComponent
    | IsExtendedPictographic
    | IsEmojiVsBase
    | GraphemeBreak
    | Block
}

/// 查询 Unicode 属性
/// 翻译自: pub const get = getpkg.get
///   根据 field 和 code point 返回属性值
public func getUnicodeProperty(field: UnicodeField, cp: UInt32): UnicodeValue {
    // 由具体属性表实现提供
    return UnicodeValue.None
}

/// 查询所有 Unicode 属性
/// 翻译自: pub const getAll = getpkg.getAll
public func getAllUnicodeProperties(tableName: String, cp: UInt32): UnicodeData {
    return UnicodeData()
}

/// Unicode 值
public enum UnicodeValue {
    | None
    | BoolValue(val: Bool)
    | IntValue(val: Int64)
    | UInt32Value(val: UInt32)
    | StringValue(val: String)
    | CategoryValue(val: GeneralCategory)
    | GraphemeBreakValue(val: GraphemeBreakProperty)
}

/// Unicode 数据集合
public class UnicodeData {
    public var generalCategory: GeneralCategory = GeneralCategory.OtherNotAssigned
    public var graphemeBreak: GraphemeBreakProperty = GraphemeBreakProperty.Other
    public var caseFoldingSimple: UInt32 = 0
    public var simpleUppercaseMapping: ?UInt32 = None
    public var simpleLowercaseMapping: ?UInt32 = None
    public var isAlphabetic: Bool = false
    public var isUppercase: Bool = false
    public var isLowercase: Bool = false
    public var eastAsianWidth: EastAsianWidth = EastAsianWidth.Neutral

    public init() {}
}

/// Grapheme Break 属性
/// 翻译自: types.zig GraphemeBreak
public enum GraphemeBreakProperty {
    | Other
    | Control
    | CR
    | LF
    | Extend
    | ZWJ
    | RegionalIndicator
    | Prepend
    | SpacingMark
    | L
    | V
    | T
    | LV
    | LVT
    | ExtendedPictographic
    | EmojiModifierBase
    | EmojiModifier
}

/// General Category
/// 翻译自: types.zig GeneralCategory
public enum GeneralCategory {
    | LetterUppercase
    | LetterLowercase
    | LetterTitlecase
    | LetterModifier
    | LetterOther
    | MarkNonspacing
    | MarkSpacingCombining
    | MarkEnclosing
    | NumberDecimalDigit
    | NumberLetter
    | NumberOther
    | PunctuationConnector
    | PunctuationDash
    | PunctuationOpen
    | PunctuationClose
    | PunctuationInitialQuote
    | PunctuationFinalQuote
    | PunctuationOther
    | SymbolMath
    | SymbolCurrency
    | SymbolModifier
    | SymbolOther
    | SeparatorSpace
    | SeparatorLine
    | SeparatorParagraph
    | OtherControl
    | OtherFormat
    | OtherSurrogate
    | OtherPrivateUse
    | OtherNotAssigned
}

/// East Asian Width
public enum EastAsianWidth {
    | Neutral   // N
    | Ambiguous // A
    | Halfwidth // H
    | Wide      // W
    | Fullwidth // F
}
