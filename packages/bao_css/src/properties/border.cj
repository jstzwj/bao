// bao_css - CSS Properties: Border
// 严格翻译自: bun/src/css/properties/border.rs
//   对应: border.zig - CSS 边框属性
//   对应: LineStyle, BorderSideWidth, GenericBorder
//   对应: BorderColor, BorderStyle, BorderWidth (Rect shorthand)
//   对应: BorderBlockColor/Style/Width, BorderInlineColor/Style/Width (Size shorthand)
//   对应: BorderProperty (bitflags), BorderHandler
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// LineStyle
// 严格翻译自 LineStyle (DefineEnumProperty)
// ============================================================================

/// <line-style> 值
/// 严格翻译自 LineStyle
public enum LineStyle {
    | None      // 无边框
    | Hidden    // 隐藏
    | Inset     // 凹陷
    | Groove    // 凹槽
    | Outset    // 凸起
    | Ridge     // 山脊
    | Dotted    // 点状
    | Dashed    // 虚线
    | Solid     // 实线
    | Double    // 双线

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Hidden => "hidden"
            case Inset => "inset"
            case Groove => "groove"
            case Outset => "outset"
            case Ridge => "ridge"
            case Dotted => "dotted"
            case Dashed => "dashed"
            case Solid => "solid"
            case Double => "double"
        }
    }

    public static func default(): LineStyle {
        LineStyle.None
    }
}

// ============================================================================
// BorderSideWidth
// 严格翻译自 BorderSideWidth
// ============================================================================

/// border-width 属性值
/// 严格翻译自 BorderSideWidth
public enum BorderSideWidth {
    | Thin           // UA 定义的细值
    | Medium         // UA 定义的中值
    | Thick          // UA 定义的粗值
    | Length(String) // 显式宽度

    public func toCss(): String {
        match (this) {
            case Thin => "thin"
            case Medium => "medium"
            case Thick => "thick"
            case Length(l) => l
        }
    }

    public static func default(): BorderSideWidth {
        BorderSideWidth.Medium
    }
}

// ============================================================================
// GenericBorder
// 严格翻译自 GenericBorder<S, P>
//   注: Rust 使用 const generics P 区分不同边框方向别名
//   Cangjie 简化为不带 const generics 的类，用字符串标识方向
// ============================================================================

/// 通用边框简写属性值
/// 严格翻译自 GenericBorder
public class GenericBorder {
    public var width: BorderSideWidth   // 边框宽度
    public var style: LineStyle         // 边框样式
    public var color: String            // 边框颜色

    public init(width: BorderSideWidth, style: LineStyle, color: String) {
        this.width = width
        this.style = style
        this.color = color
    }

    public static func default(): GenericBorder {
        GenericBorder(
            width: BorderSideWidth.Medium,
            style: LineStyle.None,
            color: "currentcolor"
        )
    }

    public func toCss(): String {
        let defaultStyle = LineStyle.None
        if (width == BorderSideWidth.Medium &&
            style == defaultStyle &&
            color == "currentcolor") {
            return style.toCss()
        }

        var parts = ArrayList<String>()
        if (width != BorderSideWidth.default()) {
            parts.append(width.toCss())
        }
        if (style != defaultStyle) {
            parts.append(style.toCss())
        }
        if (color != "currentcolor") {
            parts.append(color)
        }
        if (parts.isEmpty()) {
            return style.toCss()
        }
        return String.join(" ", parts)
    }
}

/// border-top 简写属性别名
public typealias BorderTop = GenericBorder
/// border-right 简写属性别名
public typealias BorderRight = GenericBorder
/// border-bottom 简写属性别名
public typealias BorderBottom = GenericBorder
/// border-left 简写属性别名
public typealias BorderLeft = GenericBorder
/// border-block-start 简写属性别名
public typealias BorderBlockStart = GenericBorder
/// border-block-end 简写属性别名
public typealias BorderBlockEnd = GenericBorder
/// border-inline-start 简写属性别名
public typealias BorderInlineStart = GenericBorder
/// border-inline-end 简写属性别名
public typealias BorderInlineEnd = GenericBorder
/// border-block 简写属性别名
public typealias BorderBlock = GenericBorder
/// border-inline 简写属性别名
public typealias BorderInline = GenericBorder
/// border 简写属性别名
public typealias Border = GenericBorder

// ============================================================================
// BorderColor (Rect shorthand: top/right/bottom/left)
// 严格翻译自 BorderColor (define_rect_shorthand!)
// ============================================================================

/// border-color 简写属性值
/// 严格翻译自 BorderColor
public class BorderColor {
    public var top: String        // 上边框颜色
    public var right: String      // 右边框颜色
    public var bottom: String     // 下边框颜色
    public var left: String       // 左边框颜色

    public init(top: String, right: String, bottom: String, left: String) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public func toCss(): String {
        return serializeRect(top, right, bottom, left)
    }
}

// ============================================================================
// BorderStyle (Rect shorthand: top/right/bottom/left)
// 严格翻译自 BorderStyle (define_rect_shorthand!)
// ============================================================================

/// border-style 简写属性值
/// 严格翻译自 BorderStyle
public class BorderStyle {
    public var top: LineStyle        // 上边框样式
    public var right: LineStyle      // 右边框样式
    public var bottom: LineStyle     // 下边框样式
    public var left: LineStyle       // 左边框样式

    public init(top: LineStyle, right: LineStyle, bottom: LineStyle, left: LineStyle) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public func toCss(): String {
        return serializeLineStyleRect(top, right, bottom, left)
    }
}

// ============================================================================
// BorderWidth (Rect shorthand: top/right/bottom/left)
// 严格翻译自 BorderWidth (define_rect_shorthand!)
// ============================================================================

/// border-width 简写属性值
/// 严格翻译自 BorderWidth
public class BorderWidth {
    public var top: BorderSideWidth        // 上边框宽度
    public var right: BorderSideWidth      // 右边框宽度
    public var bottom: BorderSideWidth     // 下边框宽度
    public var left: BorderSideWidth       // 左边框宽度

    public init(top: BorderSideWidth, right: BorderSideWidth, bottom: BorderSideWidth, left: BorderSideWidth) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public func toCss(): String {
        return serializeBorderSideWidthRect(top, right, bottom, left)
    }
}

// ============================================================================
// BorderBlockColor (Size shorthand: start/end)
// 严格翻译自 BorderBlockColor (define_size_shorthand!)
// ============================================================================

/// border-block-color 简写属性值
/// 严格翻译自 BorderBlockColor
public class BorderBlockColor {
    public var start: String   // 块轴起始颜色
    public var end: String     // 块轴结束颜色

    public init(start: String, end: String) {
        this.start = start
        this.end = end
    }

    public func toCss(): String {
        return serializeSize(start, end)
    }
}

// ============================================================================
// BorderBlockStyle (Size shorthand: start/end)
// 严格翻译自 BorderBlockStyle (define_size_shorthand!)
// ============================================================================

/// border-block-style 简写属性值
/// 严格翻译自 BorderBlockStyle
public class BorderBlockStyle {
    public var start: LineStyle   // 块轴起始样式
    public var end: LineStyle     // 块轴结束样式

    public init(start: LineStyle, end: LineStyle) {
        this.start = start
        this.end = end
    }

    public func toCss(): String {
        return serializeSize(start.toCss(), end.toCss())
    }
}

// ============================================================================
// BorderBlockWidth (Size shorthand: start/end)
// 严格翻译自 BorderBlockWidth (define_size_shorthand!)
// ============================================================================

/// border-block-width 简写属性值
/// 严格翻译自 BorderBlockWidth
public class BorderBlockWidth {
    public var start: BorderSideWidth   // 块轴起始宽度
    public var end: BorderSideWidth     // 块轴结束宽度

    public init(start: BorderSideWidth, end: BorderSideWidth) {
        this.start = start
        this.end = end
    }

    public func toCss(): String {
        return serializeSize(start.toCss(), end.toCss())
    }
}

// ============================================================================
// BorderInlineColor (Size shorthand: start/end)
// 严格翻译自 BorderInlineColor (define_size_shorthand!)
// ============================================================================

/// border-inline-color 简写属性值
/// 严格翻译自 BorderInlineColor
public class BorderInlineColor {
    public var start: String   // 内联轴起始颜色
    public var end: String     // 内联轴结束颜色

    public init(start: String, end: String) {
        this.start = start
        this.end = end
    }

    public func toCss(): String {
        return serializeSize(start, end)
    }
}

// ============================================================================
// BorderInlineStyle (Size shorthand: start/end)
// 严格翻译自 BorderInlineStyle (define_size_shorthand!)
// ============================================================================

/// border-inline-style 简写属性值
/// 严格翻译自 BorderInlineStyle
public class BorderInlineStyle {
    public var start: LineStyle   // 内联轴起始样式
    public var end: LineStyle     // 内联轴结束样式

    public init(start: LineStyle, end: LineStyle) {
        this.start = start
        this.end = end
    }

    public func toCss(): String {
        return serializeSize(start.toCss(), end.toCss())
    }
}

// ============================================================================
// BorderInlineWidth (Size shorthand: start/end)
// 严格翻译自 BorderInlineWidth (define_size_shorthand!)
// ============================================================================

/// border-inline-width 简写属性值
/// 严格翻译自 BorderInlineWidth
public class BorderInlineWidth {
    public var start: BorderSideWidth   // 内联轴起始宽度
    public var end: BorderSideWidth     // 内联轴结束宽度

    public init(start: BorderSideWidth, end: BorderSideWidth) {
        this.start = start
        this.end = end
    }

    public func toCss(): String {
        return serializeSize(start.toCss(), end.toCss())
    }
}

// ============================================================================
// BorderProperty (bitflags)
// 严格翻译自 BorderProperty (bitflags)
// ============================================================================

/// 边框属性位标志
/// 严格翻译自 BorderProperty
public enum BorderPropertyFlag {
    | TopColor
    | BottomColor
    | LeftColor
    | RightColor
    | BlockStartColor
    | BlockEndColor
    | InlineStartColor
    | InlineEndColor
    | TopWidth
    | BottomWidth
    | LeftWidth
    | RightWidth
    | BlockStartWidth
    | BlockEndWidth
    | InlineStartWidth
    | InlineEndWidth
    | TopStyle
    | BottomStyle
    | LeftStyle
    | RightStyle
    | BlockStartStyle
    | BlockEndStyle
    | InlineStartStyle
    | InlineEndStyle
}

// ============================================================================
// Rect/Size 序列化辅助函数
// ============================================================================

/// 序列化四个值为 Rect 格式 (top right bottom left)
func serializeRect(top: String, right: String, bottom: String, left: String): String {
    let sameVertical = top == bottom
    let sameHorizontal = right == left
    if (sameVertical && sameHorizontal && top == right) {
        return top
    }
    if (sameVertical && sameHorizontal) {
        return top + " " + right
    }
    if (sameHorizontal) {
        return top + " " + right + " " + bottom
    }
    return top + " " + right + " " + bottom + " " + left
}

/// 序列化 LineStyle Rect
func serializeLineStyleRect(top: LineStyle, right: LineStyle, bottom: LineStyle, left: LineStyle): String {
    return serializeRect(top.toCss(), right.toCss(), bottom.toCss(), left.toCss())
}

/// 序列化 BorderSideWidth Rect
func serializeBorderSideWidthRect(top: BorderSideWidth, right: BorderSideWidth, bottom: BorderSideWidth, left: BorderSideWidth): String {
    return serializeRect(top.toCss(), right.toCss(), bottom.toCss(), left.toCss())
}

/// 序列化两个值为 Size 格式 (start end)
func serializeSize(start: String, end: String): String {
    if (start == end) {
        return start
    }
    return start + " " + end
}
