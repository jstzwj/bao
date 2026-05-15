// bao_css - CSS Properties: Outline
// 严格翻译自: bun/src/css/properties/outline.rs
//   对应: outline.zig - CSS 轮廓属性
//   对应: Outline (type alias for GenericBorder<OutlineStyle, 11>)
//   对应: OutlineStyle
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// OutlineStyle
// 严格翻译自 OutlineStyle
// ============================================================================

/// outline-style 属性值
/// 严格翻译自 OutlineStyle
public enum OutlineStyle {
    | Auto                // 自动
    | LineStyle(LineStyle) // 等同于 border-style

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case LineStyle(ls) => ls.toCss()
        }
    }

    public static func default(): OutlineStyle {
        OutlineStyle.LineStyle(LineStyle.None)
    }
}

// ============================================================================
// Outline
// 严格翻译自 Outline (GenericBorder<OutlineStyle, 11>)
// ============================================================================

/// outline 属性值（泛型边框特化）
/// 严格翻译自 Outline (GenericBorder<OutlineStyle, 11>)
public class Outline {
    public var width: BorderSideWidth     // 轮廓宽度
    public var style: OutlineStyle        // 轮廓样式
    public var color: String              // 轮廓颜色

    public init(width: BorderSideWidth, style: OutlineStyle, color: String) {
        this.width = width
        this.style = style
        this.color = color
    }

    public static func default(): Outline {
        Outline(
            width: BorderSideWidth.Length("medium"),
            style: OutlineStyle.LineStyle(LineStyle.None),
            color: "currentcolor"
        )
    }

    public func toCss(): String {
        var parts = ArrayList<String>()

        // 宽度
        match (width) {
            case BorderSideWidth.Length(l) => {
                if (l != "medium") {
                    parts.append(l)
                }
            }
            case _ => parts.append(width.toCss())
        }

        // 样式
        match (style) {
            case OutlineStyle.LineStyle(LineStyle.None) => {}
            case _ => parts.append(style.toCss())
        }

        // 颜色
        if (color != "currentcolor") {
            parts.append(color)
        }

        if (parts.isEmpty()) {
            return "none"
        }
        return String.join(" ", parts)
    }
}
