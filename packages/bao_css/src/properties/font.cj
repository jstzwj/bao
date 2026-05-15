// bao_css - CSS Properties: Font
// 严格翻译自: bun/src/css/properties/font.rs
//   对应: font.zig - CSS 字体属性
//   对应: FontWeight, AbsoluteFontWeight, FontSize, AbsoluteFontSize, RelativeFontSize
//   对应: FontStretch, FontStretchKeyword, FontFamily, GenericFontFamily
//   对应: FontStyle, FontVariantCaps, LineHeight, Font, VerticalAlign
//   对应: FontProperty (bitflags), FontHandler
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// FontWeight
// 严格翻译自 FontWeight
// ============================================================================

/// font-weight 属性值
/// 严格翻译自 FontWeight
public enum FontWeight {
    | Absolute(AbsoluteFontWeight) // 绝对字重
    | Bolder                       // 更粗
    | Lighter                      // 更细

    public func toCss(): String {
        match (this) {
            case Absolute(a) => a.toCss()
            case Bolder => "bolder"
            case Lighter => "lighter"
        }
    }

    public static func default(): FontWeight {
        FontWeight.Absolute(AbsoluteFontWeight.default())
    }
}

// ============================================================================
// AbsoluteFontWeight
// 严格翻译自 AbsoluteFontWeight
// ============================================================================

/// 绝对字重值
/// 严格翻译自 AbsoluteFontWeight
public enum AbsoluteFontWeight {
    | Weight(Float64) // 显式字重 (100-900)
    | Normal          // 400
    | Bold            // 700

    public func toCss(): String {
        match (this) {
            case Weight(w) => w.toString()
            case Normal => "normal"
            case Bold => "bold"
        }
    }

    public static func default(): AbsoluteFontWeight {
        AbsoluteFontWeight.Normal
    }
}

// ============================================================================
// FontSize
// 严格翻译自 FontSize
// ============================================================================

/// font-size 属性值
/// 严格翻译自 FontSize
public enum FontSize {
    | Length(String)               // 显式长度
    | Absolute(AbsoluteFontSize)   // 绝对字号关键字
    | Relative(RelativeFontSize)   // 相对字号关键字

    public func toCss(): String {
        match (this) {
            case Length(l) => l
            case Absolute(a) => a.toCss()
            case Relative(r) => r.toCss()
        }
    }
}

// ============================================================================
// AbsoluteFontSize
// 严格翻译自 AbsoluteFontSize (DefineEnumProperty)
// ============================================================================

/// 绝对字号关键字
/// 严格翻译自 AbsoluteFontSize
public enum AbsoluteFontSize {
    | XxSmall   // "xx-small"
    | XSmall    // "x-small"
    | Small     // "small"
    | Medium    // "medium"
    | Large     // "large"
    | XLarge    // "x-large"
    | XxLarge   // "xx-large"
    | XxxLarge  // "xxx-large"

    public func toCss(): String {
        match (this) {
            case XxSmall => "xx-small"
            case XSmall => "x-small"
            case Small => "small"
            case Medium => "medium"
            case Large => "large"
            case XLarge => "x-large"
            case XxLarge => "xx-large"
            case XxxLarge => "xxx-large"
        }
    }
}

// ============================================================================
// RelativeFontSize
// 严格翻译自 RelativeFontSize (DefineEnumProperty)
// ============================================================================

/// 相对字号关键字
/// 严格翻译自 RelativeFontSize
public enum RelativeFontSize {
    | Smaller  // 更小
    | Larger   // 更大

    public func toCss(): String {
        match (this) {
            case Smaller => "smaller"
            case Larger => "larger"
        }
    }
}

// ============================================================================
// FontStretch
// 严格翻译自 FontStretch
// ============================================================================

/// font-stretch 属性值
/// 严格翻译自 FontStretch
public enum FontStretch {
    | Keyword(FontStretchKeyword) // 关键字
    | Percentage(String)           // 百分比

    public func toCss(): String {
        match (this) {
            case Keyword(kw) => kw.toCss()
            case Percentage(p) => p
        }
    }

    public static func default(): FontStretch {
        FontStretch.Keyword(FontStretchKeyword.default())
    }
}

// ============================================================================
// FontStretchKeyword
// 严格翻译自 FontStretchKeyword (DefineEnumProperty)
// ============================================================================

/// 字体拉伸关键字
/// 严格翻译自 FontStretchKeyword
public enum FontStretchKeyword {
    | Normal          // 100%
    | UltraCondensed  // 50%
    | ExtraCondensed  // 62.5%
    | Condensed       // 75%
    | SemiCondensed   // 87.5%
    | SemiExpanded    // 112.5%
    | Expanded        // 125%
    | ExtraExpanded   // 150%
    | UltraExpanded   // 200%

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case UltraCondensed => "ultra-condensed"
            case ExtraCondensed => "extra-condensed"
            case Condensed => "condensed"
            case SemiCondensed => "semi-condensed"
            case SemiExpanded => "semi-expanded"
            case Expanded => "expanded"
            case ExtraExpanded => "extra-expanded"
            case UltraExpanded => "ultra-expanded"
        }
    }

    public static func default(): FontStretchKeyword {
        FontStretchKeyword.Normal
    }

    /// 转换为百分比值
    public func toPercentage(): Float64 {
        match (this) {
            case UltraCondensed => 50.0
            case ExtraCondensed => 62.5
            case Condensed => 75.0
            case SemiCondensed => 87.5
            case Normal => 100.0
            case SemiExpanded => 112.5
            case Expanded => 125.0
            case ExtraExpanded => 150.0
            case UltraExpanded => 200.0
        }
    }
}

// ============================================================================
// FontFamily
// 严格翻译自 FontFamily
// ============================================================================

/// font-family 属性值
/// 严格翻译自 FontFamily
public enum FontFamily {
    | Generic(GenericFontFamily)  // 通用字体族
    | FamilyName(String)          // 自定义字体名称

    public func toCss(): String {
        match (this) {
            case Generic(g) => g.toCss()
            case FamilyName(name) => name
        }
    }
}

// ============================================================================
// GenericFontFamily
// 严格翻译自 GenericFontFamily (DefineEnumProperty)
// ============================================================================

/// 通用字体族
/// 严格翻译自 GenericFontFamily
public enum GenericFontFamily {
    | Serif
    | SansSerif
    | Cursive
    | Fantasy
    | Monospace
    | SystemUi
    | Emoji
    | Math
    | Fangsong
    | UiSerif
    | UiSansSerif
    | UiMonospace
    | UiRounded

    // CSS 宽关键字
    | Initial
    | Inherit
    | Unset
    | Default
    | Revert
    | RevertLayer

    public func toCss(): String {
        match (this) {
            case Serif => "serif"
            case SansSerif => "sans-serif"
            case Cursive => "cursive"
            case Fantasy => "fantasy"
            case Monospace => "monospace"
            case SystemUi => "system-ui"
            case Emoji => "emoji"
            case Math => "math"
            case Fangsong => "fangsong"
            case UiSerif => "ui-serif"
            case UiSansSerif => "ui-sans-serif"
            case UiMonospace => "ui-monospace"
            case UiRounded => "ui-rounded"
            case Initial => "initial"
            case Inherit => "inherit"
            case Unset => "unset"
            case Default => "default"
            case Revert => "revert"
            case RevertLayer => "revert-layer"
        }
    }
}

// ============================================================================
// FontStyle
// 严格翻译自 FontStyle
// ============================================================================

/// font-style 属性值
/// 严格翻译自 FontStyle
public enum FontStyle {
    | Normal           // 正常
    | Italic           // 斜体
    | Oblique(String)  // 倾斜角度（字符串表示）

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Italic => "italic"
            case Oblique(angle) => {
                if (angle == "14deg") {
                    "oblique"
                } else {
                    "oblique " + angle
                }
            }
        }
    }

    public static func default(): FontStyle {
        FontStyle.Normal
    }
}

// ============================================================================
// FontVariantCaps
// 严格翻译自 FontVariantCaps (DefineEnumProperty)
// ============================================================================

/// font-variant-caps 属性值
/// 严格翻译自 FontVariantCaps
public enum FontVariantCaps {
    | Normal       // 正常
    | SmallCaps    // 小型大写字母
    | AllSmallCaps // 全部小型大写字母
    | PetiteCaps   // 微型大写字母
    | AllPetiteCaps // 全部微型大写字母
    | Unicase      // 混合大小写
    | TitlingCaps  // 标题大写字母

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case SmallCaps => "small-caps"
            case AllSmallCaps => "all-small-caps"
            case PetiteCaps => "petite-caps"
            case AllPetiteCaps => "all-petite-caps"
            case Unicase => "unicase"
            case TitlingCaps => "titling-caps"
        }
    }

    public static func default(): FontVariantCaps {
        FontVariantCaps.Normal
    }

    /// 是否为 CSS 2.1 值
    public func isCss2(): Bool {
        match (this) {
            case Normal => true
            case SmallCaps => true
            case _ => false
        }
    }
}

// ============================================================================
// LineHeight
// 严格翻译自 LineHeight
// ============================================================================

/// line-height 属性值
/// 严格翻译自 LineHeight
public enum LineHeight {
    | Normal          // 由 UA 根据字体设置
    | Number(Float64) // 字体大小的倍数
    | Length(String)  // 显式高度

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Number(n) => n.toString()
            case Length(l) => l
        }
    }

    public static func default(): LineHeight {
        LineHeight.Normal
    }
}

// ============================================================================
// Font
// 严格翻译自 Font (简写属性)
// ============================================================================

/// font 简写属性值
/// 严格翻译自 Font
public class Font {
    public var family: ArrayList<FontFamily>  // 字体族列表
    public var size: FontSize                  // 字号
    public var style: FontStyle                // 字体样式
    public var weight: FontWeight              // 字重
    public var stretch: FontStretch            // 字体拉伸
    public var lineHeight: LineHeight          // 行高
    public var variantCaps: FontVariantCaps    // 字体变体大写

    public init() {
        this.family = ArrayList<FontFamily>()
        this.size = FontSize.Length("medium")
        this.style = FontStyle.default()
        this.weight = FontWeight.default()
        this.stretch = FontStretch.default()
        this.lineHeight = LineHeight.default()
        this.variantCaps = FontVariantCaps.default()
    }

    public init(family: ArrayList<FontFamily>, size: FontSize, style: FontStyle,
                weight: FontWeight, stretch: FontStretch, lineHeight: LineHeight,
                variantCaps: FontVariantCaps) {
        this.family = family
        this.size = size
        this.style = style
        this.weight = weight
        this.stretch = stretch
        this.lineHeight = lineHeight
        this.variantCaps = variantCaps
    }

    public func toCss(): String {
        var parts = ArrayList<String>()

        if (style != FontStyle.default()) {
            parts.append(style.toCss())
        }

        if (variantCaps != FontVariantCaps.default()) {
            parts.append(variantCaps.toCss())
        }

        if (weight != FontWeight.default()) {
            parts.append(weight.toCss())
        }

        if (stretch != FontStretch.default()) {
            parts.append(stretch.toCss())
        }

        parts.append(size.toCss())

        if (lineHeight != LineHeight.default()) {
            let last = parts[parts.size - 1]
            parts[parts.size - 1] = last + "/" + lineHeight.toCss()
        }

        // 字体族列表
        var familyParts = ArrayList<String>()
        for (f in family) {
            familyParts.append(f.toCss())
        }
        if (!familyParts.isEmpty()) {
            parts.append(String.join(", ", familyParts))
        }

        return String.join(" ", parts)
    }
}

// ============================================================================
// VerticalAlign
// 严格翻译自 VerticalAlign
// ============================================================================

/// vertical-align 属性值
/// 严格翻译自 VerticalAlign
public enum VerticalAlign {
    | Keyword(VerticalAlignKeyword) // 关键字
    | Length(String)                 // 显式长度

    public func toCss(): String {
        match (this) {
            case Keyword(kw) => kw.toCss()
            case Length(l) => l
        }
    }
}

// ============================================================================
// VerticalAlignKeyword
// 严格翻译自 VerticalAlignKeyword (DefineEnumProperty)
// ============================================================================

/// vertical-align 关键字
/// 严格翻译自 VerticalAlignKeyword
public enum VerticalAlignKeyword {
    | Baseline  // 基线对齐
    | Sub       // 下标位置
    | Super     // 上标位置
    | Top       // 顶部对齐
    | TextTop   // 文本顶部对齐
    | Middle    // 居中对齐
    | Bottom    // 底部对齐
    | TextBottom // 文本底部对齐

    public func toCss(): String {
        match (this) {
            case Baseline => "baseline"
            case Sub => "sub"
            case Super => "super"
            case Top => "top"
            case TextTop => "text-top"
            case Middle => "middle"
            case Bottom => "bottom"
            case TextBottom => "text-bottom"
        }
    }
}

// ============================================================================
// FontProperty (bitflags)
// 严格翻译自 FontProperty
// ============================================================================

/// 字体属性位标志
/// 严格翻译自 FontProperty
public enum FontPropertyFlag {
    | FontFamily
    | FontSize
    | FontStyle
    | FontWeight
    | FontStretch
    | LineHeight
    | FontVariantCaps
    | Font
}
