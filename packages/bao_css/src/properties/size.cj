// bao_css - CSS Properties: Size
// 严格翻译自: bun/src/css/properties/size.rs
//   对应: size.zig - CSS 尺寸属性
//   对应: BoxSizing, Size, MaxSize, AspectRatio
//   对应: SizeProperty (bitflags), SizeHandler
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// BoxSizing
// 严格翻译自 BoxSizing (DefineEnumProperty)
// ============================================================================

/// box-sizing 属性值
/// 严格翻译自 BoxSizing
public enum BoxSizing {
    | ContentBox  // width/height 不包含 border/padding
    | BorderBox   // width/height 包含 border/padding

    public func toCss(): String {
        match (this) {
            case ContentBox => "content-box"
            case BorderBox => "border-box"
        }
    }
}

// ============================================================================
// Size
// 严格翻译自 Size
// ============================================================================

/// width/height 等 CSS 尺寸属性值
/// 严格翻译自 Size
public enum Size {
    | Auto                          // auto
    | LengthPercentage(String)      // 显式长度/百分比
    | MinContent(String)            // min-content (带供应商前缀)
    | MaxContent(String)            // max-content (带供应商前缀)
    | FitContent(String)            // fit-content (带供应商前缀)
    | FitContentFunction(String)    // fit-content() 函数
    | Stretch(String)               // stretch / -webkit-fill-available / -moz-available
    | Contain                       // contain

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Contain => "contain"
            case LengthPercentage(l) => l
            case MinContent(prefix) => prefix + "min-content"
            case MaxContent(prefix) => prefix + "max-content"
            case FitContent(prefix) => prefix + "fit-content"
            case Stretch(vp) => {
                if (vp == "") {
                    "stretch"
                } else if (vp == "-webkit-") {
                    "-webkit-fill-available"
                } else if (vp == "-moz-") {
                    "-moz-available"
                } else {
                    vp + "stretch"
                }
            }
            case FitContentFunction(l) => "fit-content(" + l + ")"
        }
    }
}

// ============================================================================
// MaxSize
// 严格翻译自 MaxSize
// ============================================================================

/// min-width/max-width 等 CSS 尺寸属性值
/// 严格翻译自 MaxSize
public enum MaxSize {
    | None                          // none
    | LengthPercentage(String)      // 显式长度/百分比
    | MinContent(String)            // min-content (带供应商前缀)
    | MaxContent(String)            // max-content (带供应商前缀)
    | FitContent(String)            // fit-content (带供应商前缀)
    | FitContentFunction(String)    // fit-content() 函数
    | Stretch(String)               // stretch / -webkit-fill-available / -moz-available
    | Contain                       // contain

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Contain => "contain"
            case LengthPercentage(l) => l
            case MinContent(prefix) => prefix + "min-content"
            case MaxContent(prefix) => prefix + "max-content"
            case FitContent(prefix) => prefix + "fit-content"
            case Stretch(vp) => {
                if (vp == "") {
                    "stretch"
                } else if (vp == "-webkit-") {
                    "-webkit-fill-available"
                } else if (vp == "-moz-") {
                    "-moz-available"
                } else {
                    vp + "stretch"
                }
            }
            case FitContentFunction(l) => "fit-content(" + l + ")"
        }
    }
}

// ============================================================================
// AspectRatio
// 严格翻译自 AspectRatio
// ============================================================================

/// aspect-ratio 属性值
/// 严格翻译自 AspectRatio
public class AspectRatio {
    public var auto: Bool        // auto 关键字
    public var ratio: Option<String>  // 宽高比字符串表示（如 "16/9"）

    public init(auto: Bool, ratio: Option<String>) {
        this.auto = auto
        this.ratio = ratio
    }

    public static func default(): AspectRatio {
        AspectRatio(auto: false, ratio: None)
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        if (auto) {
            parts.append("auto")
        }
        match (ratio) {
            case Some(r) => parts.append(r)
            case None => {}
        }
        if (parts.isEmpty()) {
            return "auto"
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// SizeProperty (bitflags)
// 严格翻译自 SizeProperty
// ============================================================================

/// 尺寸属性位标志
/// 严格翻译自 SizeProperty
public enum SizePropertyFlag {
    | Width
    | Height
    | MinWidth
    | MinHeight
    | MaxWidth
    | MaxHeight
    | BlockSize
    | InlineSize
    | MinBlockSize
    | MinInlineSize
    | MaxBlockSize
    | MaxInlineSize
}
