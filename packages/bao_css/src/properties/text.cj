// bao_css - CSS Properties: Text
// 严格翻译自: bun/src/css/properties/text.rs
//   对应: text.zig - CSS 文本属性
//   对应: TextTransform, TextTransformCase, TextTransformOther
//   对应: Spacing, TextIndent, TextDecorationLine, TextDecorationThickness
//   对应: TextShadow, TextSizeAdjust, Direction
//   对应: WhiteSpace, WordBreak, LineBreak, Hyphens, OverflowWrap
//   对应: TextAlign, TextAlignLast, TextJustify
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// TextTransform
// 严格翻译自 TextTransform
// ============================================================================

/// text-transform 属性值
/// 严格翻译自 TextTransform
public class TextTransform {
    public var case_: TextTransformCase  // 大小写转换
    public var other: TextTransformOther // 其他转换

    public init(case_: TextTransformCase, other: TextTransformOther) {
        this.case_ = case_
        this.other = other
    }

    public static func default(): TextTransform {
        TextTransform(case_: TextTransformCase.None, other: TextTransformOther.None)
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        match (case_) {
            case TextTransformCase.None => {}
            case _ => parts.append(case_.toCss())
        }
        if (other != TextTransformOther.None) {
            parts.append(other.toCss())
        }
        if (parts.isEmpty()) {
            return "none"
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// TextTransformCase
// 严格翻译自 TextTransformCase (占位)
// ============================================================================

/// text-transform 大小写转换
/// 严格翻译自 TextTransformCase
public enum TextTransformCase {
    | None
    | Uppercase
    | Lowercase
    | Capitalize

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Uppercase => "uppercase"
            case Lowercase => "lowercase"
            case Capitalize => "capitalize"
        }
    }
}

// ============================================================================
// TextTransformOther
// 严格翻译自 TextTransformOther (bitflags)
// ============================================================================

/// text-transform 附加转换
/// 严格翻译自 TextTransformOther
public enum TextTransformOther {
    | None
    | FullWidth
    | FullSizeKana
    | FullWidthAndFullSizeKana

    public func toCss(): String {
        match (this) {
            case None => ""
            case FullWidth => "full-width"
            case FullSizeKana => "full-size-kana"
            case FullWidthAndFullSizeKana => "full-width full-size-kana"
        }
    }
}

// ============================================================================
// Spacing
// 严格翻译自 Spacing
// ============================================================================

/// word-spacing / letter-spacing 属性值
/// 严格翻译自 Spacing
public enum Spacing {
    | Normal       // 正常间距
    | Length(String) // 显式长度

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Length(l) => l
        }
    }
}

// ============================================================================
// TextIndent
// 严格翻译自 TextIndent
// ============================================================================

/// text-indent 属性值
/// 严格翻译自 TextIndent
public class TextIndent {
    public var value: String   // 缩进量
    public var hanging: Bool   // 是否反转受影响的行
    public var eachLine: Bool  // 是否影响硬换行后的首行

    public init(value: String, hanging: Bool, eachLine: Bool) {
        this.value = value
        this.hanging = hanging
        this.eachLine = eachLine
    }

    public static func default(): TextIndent {
        TextIndent(value: "0", hanging: false, eachLine: false)
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        if (hanging) {
            parts.append("hanging")
        }
        if (eachLine) {
            parts.append("each-line")
        }
        parts.append(value)
        return String.join(" ", parts)
    }
}

// ============================================================================
// TextDecorationLine
// 严格翻译自 TextDecorationLine (bitflags)
// ============================================================================

/// text-decoration-line 属性值
/// 严格翻译自 TextDecorationLine
public enum TextDecorationLine {
    | None
    | Underline
    | Overline
    | LineThrough
    | Blink
    | SpellingError
    | GrammarError
    | UnderlineOverline
    | UnderlineLineThrough
    | OverlineLineThrough
    | UnderlineOverlineLineThrough

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Underline => "underline"
            case Overline => "overline"
            case LineThrough => "line-through"
            case Blink => "blink"
            case SpellingError => "spelling-error"
            case GrammarError => "grammar-error"
            case UnderlineOverline => "underline overline"
            case UnderlineLineThrough => "underline line-through"
            case OverlineLineThrough => "overline line-through"
            case UnderlineOverlineLineThrough => "underline overline line-through"
        }
    }
}

// ============================================================================
// TextDecorationThickness
// 严格翻译自 TextDecorationThickness
// ============================================================================

/// text-decoration-thickness 属性值
/// 严格翻译自 TextDecorationThickness
public enum TextDecorationThickness {
    | Auto                // UA 自动选择
    | FromFont            // 使用字体定义的厚度
    | LengthPercentage(String) // 显式长度/百分比

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case FromFont => "from-font"
            case LengthPercentage(l) => l
        }
    }
}

// ============================================================================
// TextShadow
// 严格翻译自 TextShadow
// ============================================================================

/// text-shadow 属性值
/// 严格翻译自 TextShadow
public class TextShadow {
    public var color: String    // 阴影颜色
    public var xOffset: String  // X 偏移
    public var yOffset: String  // Y 偏移
    public var blur: String     // 模糊半径
    public var spread: String   // 扩展距离

    public init(color: String, xOffset: String, yOffset: String, blur: String, spread: String) {
        this.color = color
        this.xOffset = xOffset
        this.yOffset = yOffset
        this.blur = blur
        this.spread = spread
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        parts.append(xOffset)
        parts.append(yOffset)

        if (blur != "0" || spread != "0") {
            parts.append(blur)
            if (spread != "0") {
                parts.append(spread)
            }
        }

        if (color != "currentcolor") {
            parts.append(color)
        }

        return String.join(" ", parts)
    }
}

// ============================================================================
// TextSizeAdjust
// 严格翻译自 TextSizeAdjust
// ============================================================================

/// text-size-adjust 属性值
/// 严格翻译自 TextSizeAdjust
public enum TextSizeAdjust {
    | Auto             // 使用默认大小调整
    | None             // 不进行大小调整
    | Percentage(String) // 百分比调整

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case None => "none"
            case Percentage(p) => p
        }
    }
}

// ============================================================================
// Direction
// 严格翻译自 Direction (DefineEnumProperty)
// ============================================================================

/// direction 属性值
/// 严格翻译自 Direction
public enum Direction {
    | Ltr  // 从左到右
    | Rtl  // 从右到左

    public func toCss(): String {
        match (this) {
            case Ltr => "ltr"
            case Rtl => "rtl"
        }
    }
}

// ============================================================================
// 占位类型 (Zig 源码中为 DefineEnumProperty(@compileError(...)) 占位)
// ============================================================================

/// white-space 属性值（占位）
public enum WhiteSpace {
    | Normal
    | Pre
    | Nowrap
    | PreWrap
    | PreLine
    | BreakSpaces

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Pre => "pre"
            case Nowrap => "nowrap"
            case PreWrap => "pre-wrap"
            case PreLine => "pre-line"
            case BreakSpaces => "break-spaces"
        }
    }
}

/// word-break 属性值（占位）
public enum WordBreak {
    | Normal
    | BreakAll
    | KeepAll
    | BreakWord

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case BreakAll => "break-all"
            case KeepAll => "keep-all"
            case BreakWord => "break-word"
        }
    }
}

/// line-break 属性值（占位）
public enum LineBreak {
    | Auto
    | Loose
    | Normal
    | Strict
    | Anywhere

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Loose => "loose"
            case Normal => "normal"
            case Strict => "strict"
            case Anywhere => "anywhere"
        }
    }
}

/// hyphens 属性值（占位）
public enum Hyphens {
    | None
    | Manual
    | Auto

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Manual => "manual"
            case Auto => "auto"
        }
    }
}

/// overflow-wrap 属性值（占位）
public enum OverflowWrap {
    | Normal
    | BreakWord
    | Anywhere

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case BreakWord => "break-word"
            case Anywhere => "anywhere"
        }
    }
}

/// text-align 属性值（占位）
public enum TextAlign {
    | Start
    | End
    | Left
    | Right
    | Center
    | Justify
    | MatchParent
    | JustifyAll

    public func toCss(): String {
        match (this) {
            case Start => "start"
            case End => "end"
            case Left => "left"
            case Right => "right"
            case Center => "center"
            case Justify => "justify"
            case MatchParent => "match-parent"
            case JustifyAll => "justify-all"
        }
    }
}

/// text-align-last 属性值（占位）
public enum TextAlignLast {
    | Auto
    | Start
    | End
    | Left
    | Right
    | Center
    | Justify

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Start => "start"
            case End => "end"
            case Left => "left"
            case Right => "right"
            case Center => "center"
            case Justify => "justify"
        }
    }
}

/// text-justify 属性值（占位）
public enum TextJustify {
    | Auto
    | None
    | InterWord
    | InterCharacter

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case None => "none"
            case InterWord => "inter-word"
            case InterCharacter => "inter-character"
        }
    }
}

/// unicode-bidi 属性值（占位）
public enum UnicodeBidi {
    | Normal
    | Embed
    | Isolate
    | BidiOverride
    | IsolateOverride
    | Plaintext

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Embed => "embed"
            case Isolate => "isolate"
            case BidiOverride => "bidi-override"
            case IsolateOverride => "isolate-override"
            case Plaintext => "plaintext"
        }
    }
}

/// box-decoration-break 属性值（占位）
public enum BoxDecorationBreak {
    | Slice
    | Clone

    public func toCss(): String {
        match (this) {
            case Slice => "slice"
            case Clone => "clone"
        }
    }
}
