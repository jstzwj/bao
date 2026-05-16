// bao_unicode - uucode Unicode 类型定义
// 严格翻译自: src/unicode/uucode_lib/src/types.zig
//   定义 Unicode 数据库中使用的所有枚举类型
//   GeneralCategory, BidiClass, DecompositionType, NumericType 等
//   仓颉实现提供等价的类型定义
package bao_unicode.uucode_lib

// ============================================================================
// Unicode 类型定义
// 严格翻译自: src/unicode/uucode_lib/src/types.zig
//   完整的 Unicode 属性枚举类型
// ============================================================================

/// Bidi Class (双向文本类别)
/// 翻译自: pub const BidiClass = enum(u5)
public enum BidiClass {
    | LeftToRight           // L
    | LeftToRightEmbedding  // LRE
    | LeftToRightOverride   // LRO
    | RightToLeft           // R
    | RightToLeftArabic     // AL
    | RightToLeftEmbedding  // RLE
    | RightToLeftOverride   // RLO
    | PopDirectionalFormat  // PDF
    | EuropeanNumber        // EN
    | EuropeanNumberSeparator   // ES
    | EuropeanNumberTerminator  // ET
    | ArabicNumber          // AN
    | CommonNumberSeparator // CS
    | NonspacingMark        // NSM
    | BoundaryNeutral       // BN
    | ParagraphSeparator    // B
    | SegmentSeparator      // S
    | Whitespace            // WS
    | OtherNeutrals         // ON
    | LeftToRightIsolate    // LRI
    | RightToLeftIsolate    // RLI
    | FirstStrongIsolate    // FSI
    | PopDirectionalIsolate // PDI
}

/// Decomposition Type (分解类型)
/// 翻译自: pub const DecompositionType = enum(u5)
public enum DecompositionType {
    | Default
    | Canonical
    | Font
    | NoBreak
    | Initial
    | Medial
    | Final
    | Isolated
    | Circle
    | Super
    | Sub
    | Vertical
    | Wide
    | Narrow
    | Small
    | Square
    | Fraction
    | Compat
}

/// Numeric Type (数字类型)
/// 翻译自: pub const NumericType = enum(u2)
public enum NumericType {
    | NotNumeric
    | Decimal
    | Digit
    | Numeric
}

/// Indic Conjunct Break (印度语连接断点)
/// 翻译自: pub const IndicConjunctBreak = enum(u2)
public enum IndicConjunctBreak {
    | NoBreak
    | Consonant
    | Extend
    | Linker
}

/// Original Grapheme Break (原始字素断点)
/// 翻译自: pub const OriginalGraphemeBreak = enum(u5)
public enum OriginalGraphemeBreak {
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

/// East Asian Width (东亚宽度)
/// 翻译自: pub const EastAsianWidth = enum(u3)
public enum EastAsianWidthType {
    | Neutral   // N
    | Ambiguous // A
    | Halfwidth // H
    | Wide      // W
    | Narrow    // Na
    | Fullwidth // F
}

/// Special Casing Condition (特殊大小写条件)
/// 翻译自: pub const SpecialCasingCondition = enum
public enum SpecialCasingCondition {
    | FinalSigma
    | AfterSoftDotted
    | MoreAbove
    | BeforeDot
    | LanguageTurkish
    | LanguageAzerbaijani
    | LanguageLithuanian
    | LanguageGerman
}

/// Bidi Paired Bracket (双向配对括号)
/// 翻译自: pub const BidiPairedBracket = union(enum)
public enum BidiPairedBracket {
    | NoBracket
    | Open(UInt32)
    | Close(UInt32)
}

/// Emoji Odd or Even (扩展字段)
/// 翻译自: 测试扩展字段
public enum EmojiOddOrEven {
    | OddEmoji
    | EvenEmoji
}

/// Block (Unicode 块)
/// 翻译自: pub const Block = enum(u8)
///   简化版本, 完整版有 300+ 值
public enum UnicodeBlock {
    | BasicLatin
    | Latin1Supplement
    | LatinExtendedA
    | LatinExtendedB
    | IpaExtensions
    | CjkUnifiedIdeographs
    | HangulSyllables
    | Other
}

/// Shift 字段类型
/// 翻译自: types.zig Shift struct
public class ShiftField {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    /// 反移位: 将存储值还原为实际值
    /// 翻译自: pub fn unshift(self: @This(), cp: u21) ?u21
    public func unshift(cp: UInt32): ?UInt32 {
        let shifted = value + cp
        if (shifted == 0) {
            return None
        }
        return shifted
    }
}

/// Slice 字段类型
/// 翻译自: types.zig Slice struct
public class SliceField {
    public var offset: UInt32
    public var len: UInt32

    public init(offset: UInt32, len: UInt32) {
        this.offset = offset
        this.len = len
    }
}
