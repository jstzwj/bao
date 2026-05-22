// bao_css - CSS Properties: Outline
// 严格翻译自: bun/src/css/properties/outline.rs
//   对应: outline.zig - CSS 轮廓属性
//   对应: Outline (type alias for GenericBorder<OutlineStyle, 11>)
//   对应: OutlineStyle
// ============================================================================

package bao_css.properties

import bao_core.*
import bao_collections.*

// ============================================================================
// OutlineStyle
// 严格翻译自 OutlineStyle
// ============================================================================

/// outline-style 属性值
/// 严格翻译自 OutlineStyle
public enum OutlineStyle {
    | Auto                // 自动
    | LineStyleVal(LineStyle) // 等同于 border-style

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case LineStyleVal(ls) => ls.toCss()
        }
    }

    public static func default(): OutlineStyle {
        OutlineStyle.LineStyleVal(LineStyle.NoneValue)
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
            BorderSideWidth.Length("medium"),
            OutlineStyle.LineStyleVal(LineStyle.NoneValue),
            "currentcolor"
        )
    }

    private func widthCss(): String {
        match (width) {
            case BorderSideWidth.Length(l) => if (l != "medium") { l } else { "" }
            case _ => width.toCss()
        }
    }

    public func toCss(): String {
        var parts = ArrayList<String>()

        // 宽度
        let w = widthCss()
        if (w != "") { parts.append(w) }

        // 样式
        match (style) {
            case OutlineStyle.LineStyleVal(LineStyle.NoneValue) => ()
            case _ => parts.append(style.toCss())
        }

        // 颜色
        if (color != "currentcolor") {
            parts.append(color)
        }

        if (parts.isEmpty()) {
            return "none"
        }
        var result = ""
        for (i in 0..parts.size) {
            if (i > 0) { result += " " }
            result += parts[i]
        }
        return result
    }
}
