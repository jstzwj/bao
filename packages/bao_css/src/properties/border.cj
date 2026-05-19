// bao_css - CSS Properties: Border
// 严格翻译自: bun/src/css/properties/border.zig
//   对应: LineStyle, BorderSideWidth, GenericBorder
//   对应: BorderColor, BorderStyle, BorderWidth (Rect shorthand)
//   对应: BorderBlockColor/Style/Width, BorderInlineColor/Style/Width (Size shorthand)
//   对应: BorderProperty (bitflags), BorderShorthand
//   对应: BorderHandler, FlushContext
//   对应: ImplFallbacks, isBorderProperty
// ============================================================================

package bao_css.properties

import bao_core.*
import bao_collections.*

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

    public operator func ==(rhs: LineStyle): Bool {
        this.toCss() == rhs.toCss()
    }

    public operator func !=(rhs: LineStyle): Bool {
        !(this == rhs)
    }

    public static func default(): LineStyle {
        LineStyle.None
    }

    /// 严格翻译自 LineStyle.isCompatible - 始终兼容
    public func isCompatible(): Bool {
        true
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

    public operator func ==(rhs: BorderSideWidth): Bool {
        this.toCss() == rhs.toCss()
    }

    public operator func !=(rhs: BorderSideWidth): Bool {
        !(this == rhs)
    }

    public static func default(): BorderSideWidth {
        BorderSideWidth.Medium
    }

    /// 严格翻译自 BorderSideWidth.isCompatible
    public func isCompatible(): Bool {
        true
    }

    /// 严格翻译自 BorderSideWidth.deepClone
    public func deepClone(): BorderSideWidth {
        match (this) {
            case Length(l) => BorderSideWidth.Length(l)
            case _ => this
        }
    }
}

// ============================================================================
// GenericBorder
// 严格翻译自 GenericBorder<S, P>
//   注: Zig 使用 comptime P 区分不同边框方向别名
//   Cangjie 简化为不带 const generics 的类，用字符串标识方向
// ============================================================================

/// 通用边框简写属性值
/// 严格翻译自 GenericBorder
public class GenericBorder {
    public var width: BorderSideWidth   // 边框宽度
    public var style: LineStyle         // 边框样式
    public var color: String            // 边框颜色

    public init(width!: BorderSideWidth, style!: LineStyle, color!: String) {
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

    /// 严格翻译自 GenericBorder.eql
    public func eql(other: GenericBorder): Bool {
        width == other.width && style == other.style && color == other.color
    }

    /// 严格翻译自 GenericBorder.deepClone
    public func deepClone(): GenericBorder {
        GenericBorder(
            width: width.deepClone(),
            style: style,
            color: color
        )
    }

    /// 严格翻译自 GenericBorder.toCss
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
        var partArr = Array<String>(parts.size, repeat: "")
        var pi: Int64 = 0
        for (p in parts) { partArr[pi] = p; pi += 1 }
        return String.join(partArr, delimiter: " ")
    }
}

/// border-top 简写属性别名
public type BorderTop = GenericBorder
/// border-right 简写属性别名
public type BorderRight = GenericBorder
/// border-bottom 简写属性别名
public type BorderBottom = GenericBorder
/// border-left 简写属性别名
public type BorderLeft = GenericBorder
/// border-block-start 简写属性别名
public type BorderBlockStart = GenericBorder
/// border-block-end 简写属性别名
public type BorderBlockEnd = GenericBorder
/// border-inline-start 简写属性别名
public type BorderInlineStart = GenericBorder
/// border-inline-end 简写属性别名
public type BorderInlineEnd = GenericBorder
/// border-block 简写属性别名
public type BorderBlock = GenericBorder
/// border-inline 简写属性别名
public type BorderInline = GenericBorder
/// border 简写属性别名
public type Border = GenericBorder

// ============================================================================
// BorderColor (Rect shorthand: top/right/bottom/left)
// 严格翻译自 BorderColor (DefineRectShorthand)
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

    /// 严格翻译自 BorderColor.eql
    public func eql(other: BorderColor): Bool {
        top == other.top && right == other.right && bottom == other.bottom && left == other.left
    }

    /// 严格翻译自 BorderColor.deepClone
    public func deepClone(): BorderColor {
        BorderColor(top, right, bottom, left)
    }

    public func toCss(): String {
        return serializeRect(top, right, bottom, left)
    }
}

// ============================================================================
// BorderStyle (Rect shorthand: top/right/bottom/left)
// 严格翻译自 BorderStyle (DefineRectShorthand)
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

    /// 严格翻译自 BorderStyle.eql
    public func eql(other: BorderStyle): Bool {
        top == other.top && right == other.right && bottom == other.bottom && left == other.left
    }

    /// 严格翻译自 BorderStyle.deepClone
    public func deepClone(): BorderStyle {
        BorderStyle(top, right, bottom, left)
    }

    public func toCss(): String {
        return serializeLineStyleRect(top, right, bottom, left)
    }
}

// ============================================================================
// BorderWidth (Rect shorthand: top/right/bottom/left)
// 严格翻译自 BorderWidth (DefineRectShorthand)
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

    /// 严格翻译自 BorderWidth.eql
    public func eql(other: BorderWidth): Bool {
        top == other.top && right == other.right && bottom == other.bottom && left == other.left
    }

    /// 严格翻译自 BorderWidth.deepClone
    public func deepClone(): BorderWidth {
        BorderWidth(top.deepClone(), right.deepClone(), bottom.deepClone(), left.deepClone())
    }

    public func toCss(): String {
        return serializeBorderSideWidthRect(top, right, bottom, left)
    }
}

// ============================================================================
// BorderBlockColor (Size shorthand: start/end)
// 严格翻译自 BorderBlockColor (DefineSizeShorthand)
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

    /// 严格翻译自 BorderBlockColor.eql
    public func eql(other: BorderBlockColor): Bool {
        start == other.start && end == other.end
    }

    /// 严格翻译自 BorderBlockColor.deepClone
    public func deepClone(): BorderBlockColor {
        BorderBlockColor(start, end)
    }

    public func toCss(): String {
        return serializeSize(start, end)
    }
}

// ============================================================================
// BorderBlockStyle (Size shorthand: start/end)
// 严格翻译自 BorderBlockStyle (DefineSizeShorthand)
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

    /// 严格翻译自 BorderBlockStyle.eql
    public func eql(other: BorderBlockStyle): Bool {
        start == other.start && end == other.end
    }

    /// 严格翻译自 BorderBlockStyle.deepClone
    public func deepClone(): BorderBlockStyle {
        BorderBlockStyle(start, end)
    }

    public func toCss(): String {
        return serializeSize(start.toCss(), end.toCss())
    }
}

// ============================================================================
// BorderBlockWidth (Size shorthand: start/end)
// 严格翻译自 BorderBlockWidth (DefineSizeShorthand)
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

    /// 严格翻译自 BorderBlockWidth.eql
    public func eql(other: BorderBlockWidth): Bool {
        start == other.start && end == other.end
    }

    /// 严格翻译自 BorderBlockWidth.deepClone
    public func deepClone(): BorderBlockWidth {
        BorderBlockWidth(start.deepClone(), end.deepClone())
    }

    public func toCss(): String {
        return serializeSize(start.toCss(), end.toCss())
    }
}

// ============================================================================
// BorderInlineColor (Size shorthand: start/end)
// 严格翻译自 BorderInlineColor (DefineSizeShorthand)
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

    /// 严格翻译自 BorderInlineColor.eql
    public func eql(other: BorderInlineColor): Bool {
        start == other.start && end == other.end
    }

    /// 严格翻译自 BorderInlineColor.deepClone
    public func deepClone(): BorderInlineColor {
        BorderInlineColor(start, end)
    }

    public func toCss(): String {
        return serializeSize(start, end)
    }
}

// ============================================================================
// BorderInlineStyle (Size shorthand: start/end)
// 严格翻译自 BorderInlineStyle (DefineSizeShorthand)
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

    /// 严格翻译自 BorderInlineStyle.eql
    public func eql(other: BorderInlineStyle): Bool {
        start == other.start && end == other.end
    }

    /// 严格翻译自 BorderInlineStyle.deepClone
    public func deepClone(): BorderInlineStyle {
        BorderInlineStyle(start, end)
    }

    public func toCss(): String {
        return serializeSize(start.toCss(), end.toCss())
    }
}

// ============================================================================
// BorderInlineWidth (Size shorthand: start/end)
// 严格翻译自 BorderInlineWidth (DefineSizeShorthand)
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

    /// 严格翻译自 BorderInlineWidth.eql
    public func eql(other: BorderInlineWidth): Bool {
        start == other.start && end == other.end
    }

    /// 严格翻译自 BorderInlineWidth.deepClone
    public func deepClone(): BorderInlineWidth {
        BorderInlineWidth(start.deepClone(), end.deepClone())
    }

    public func toCss(): String {
        return serializeSize(start.toCss(), end.toCss())
    }
}

// ============================================================================
// BorderProperty (bitflags)
// 严格翻译自 BorderProperty packed struct(u32)
// ============================================================================

/// 边框属性位标志
/// 严格翻译自 BorderProperty
/// 使用 Set<String> 模拟 Zig 中的 packed struct 位操作
public class BorderProperty {
    public var flags: HashSet<String>

    public init() {
        this.flags = HashSet<String>()
    }

    /// 设置某个属性标志
    public func set(flag: String): Unit {
        flags.put(flag)
    }

    /// 检查是否包含某个属性标志
    public func contains(flag: String): Bool {
        flags.contains(flag)
    }

    /// 按位或
    public func or(other: BorderProperty): BorderProperty {
        let result = BorderProperty()
        for (f in flags) { result.flags.put(f) }
        for (f in other.flags) { result.flags.put(f) }
        return result
    }

    /// 插入 (合并另一个标志集)
    public func insert(other: BorderProperty): Unit {
        for (f in other.flags) { flags.put(f) }
    }

    // ========================================================================
    // 预定义的边框属性常量
    // 严格翻译自 BorderProperty 中的 const 声明
    // ========================================================================

    /// border-top-color
    public static func borderTopColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("top-color")
        return bp
    }

    /// border-bottom-color
    public static func borderBottomColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("bottom-color")
        return bp
    }

    /// border-left-color
    public static func borderLeftColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("left-color")
        return bp
    }

    /// border-right-color
    public static func borderRightColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("right-color")
        return bp
    }

    /// border-block-start-color
    public static func borderBlockStartColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-start-color")
        return bp
    }

    /// border-block-end-color
    public static func borderBlockEndColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-end-color")
        return bp
    }

    /// border-inline-start-color
    public static func borderInlineStartColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-start-color")
        return bp
    }

    /// border-inline-end-color
    public static func borderInlineEndColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-end-color")
        return bp
    }

    /// border-top-width
    public static func borderTopWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("top-width")
        return bp
    }

    /// border-bottom-width
    public static func borderBottomWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("bottom-width")
        return bp
    }

    /// border-left-width
    public static func borderLeftWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("left-width")
        return bp
    }

    /// border-right-width
    public static func borderRightWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("right-width")
        return bp
    }

    /// border-block-start-width
    public static func borderBlockStartWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-start-width")
        return bp
    }

    /// border-block-end-width
    public static func borderBlockEndWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-end-width")
        return bp
    }

    /// border-inline-start-width
    public static func borderInlineStartWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-start-width")
        return bp
    }

    /// border-inline-end-width
    public static func borderInlineEndWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-end-width")
        return bp
    }

    /// border-top-style
    public static func borderTopStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("top-style")
        return bp
    }

    /// border-bottom-style
    public static func borderBottomStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("bottom-style")
        return bp
    }

    /// border-left-style
    public static func borderLeftStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("left-style")
        return bp
    }

    /// border-right-style
    public static func borderRightStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("right-style")
        return bp
    }

    /// border-block-start-style
    public static func borderBlockStartStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-start-style")
        return bp
    }

    /// border-block-end-style
    public static func borderBlockEndStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-end-style")
        return bp
    }

    /// border-inline-start-style
    public static func borderInlineStartStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-start-style")
        return bp
    }

    /// border-inline-end-style
    public static func borderInlineEndStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-end-style")
        return bp
    }

    // ========================================================================
    // 组合属性常量
    // ========================================================================

    /// border-block-color (block-start-color + block-end-color)
    public static func borderBlockColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-start-color")
        bp.set("block-end-color")
        return bp
    }

    /// border-inline-color (inline-start-color + inline-end-color)
    public static func borderInlineColor(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-start-color")
        bp.set("inline-end-color")
        return bp
    }

    /// border-block-width
    public static func borderBlockWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-start-width")
        bp.set("block-end-width")
        return bp
    }

    /// border-inline-width
    public static func borderInlineWidth(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-start-width")
        bp.set("inline-end-width")
        return bp
    }

    /// border-block-style
    public static func borderBlockStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-start-style")
        bp.set("block-end-style")
        return bp
    }

    /// border-inline-style
    public static func borderInlineStyle(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-start-style")
        bp.set("inline-end-style")
        return bp
    }

    /// border-top (top-color + top-width + top-style)
    public static func borderTop(): BorderProperty {
        let bp = BorderProperty()
        bp.set("top-color")
        bp.set("top-width")
        bp.set("top-style")
        return bp
    }

    /// border-bottom
    public static func borderBottom(): BorderProperty {
        let bp = BorderProperty()
        bp.set("bottom-color")
        bp.set("bottom-width")
        bp.set("bottom-style")
        return bp
    }

    /// border-left
    public static func borderLeft(): BorderProperty {
        let bp = BorderProperty()
        bp.set("left-color")
        bp.set("left-width")
        bp.set("left-style")
        return bp
    }

    /// border-right
    public static func borderRight(): BorderProperty {
        let bp = BorderProperty()
        bp.set("right-color")
        bp.set("right-width")
        bp.set("right-style")
        return bp
    }

    /// border-block-start
    public static func borderBlockStart(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-start-color")
        bp.set("block-start-width")
        bp.set("block-start-style")
        return bp
    }

    /// border-block-end
    public static func borderBlockEnd(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-end-color")
        bp.set("block-end-width")
        bp.set("block-end-style")
        return bp
    }

    /// border-inline-start
    public static func borderInlineStart(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-start-color")
        bp.set("inline-start-width")
        bp.set("inline-start-style")
        return bp
    }

    /// border-inline-end
    public static func borderInlineEnd(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-end-color")
        bp.set("inline-end-width")
        bp.set("inline-end-style")
        return bp
    }

    /// border-block (全部 block 方向)
    public static func borderBlockAll(): BorderProperty {
        let bp = BorderProperty()
        bp.set("block-start-color")
        bp.set("block-end-color")
        bp.set("block-start-width")
        bp.set("block-end-width")
        bp.set("block-start-style")
        bp.set("block-end-style")
        return bp
    }

    /// border-inline (全部 inline 方向)
    public static func borderInlineAll(): BorderProperty {
        let bp = BorderProperty()
        bp.set("inline-start-color")
        bp.set("inline-end-color")
        bp.set("inline-start-width")
        bp.set("inline-end-width")
        bp.set("inline-start-style")
        bp.set("inline-end-style")
        return bp
    }

    /// border-width (四方向宽度)
    public static func borderWidthAll(): BorderProperty {
        let bp = BorderProperty()
        bp.set("left-width")
        bp.set("right-width")
        bp.set("top-width")
        bp.set("bottom-width")
        return bp
    }

    /// border-style (四方向样式)
    public static func borderStyleAll(): BorderProperty {
        let bp = BorderProperty()
        bp.set("left-style")
        bp.set("right-style")
        bp.set("top-style")
        bp.set("bottom-style")
        return bp
    }

    /// border-color (四方向颜色)
    public static func borderColorAll(): BorderProperty {
        let bp = BorderProperty()
        bp.set("left-color")
        bp.set("right-color")
        bp.set("top-color")
        bp.set("bottom-color")
        return bp
    }

    /// border (所有边框属性)
    public static func borderAll(): BorderProperty {
        let bp = BorderProperty()
        bp.set("left-width")
        bp.set("right-width")
        bp.set("top-width")
        bp.set("bottom-width")
        bp.set("left-style")
        bp.set("right-style")
        bp.set("top-style")
        bp.set("bottom-style")
        bp.set("left-color")
        bp.set("right-color")
        bp.set("top-color")
        bp.set("bottom-color")
        return bp
    }
}

// ============================================================================
// BorderShorthand
// 严格翻译自 BorderShorthand struct
// ============================================================================

/// 边框简写中间状态
/// 严格翻译自 BorderShorthand
public class BorderShorthand {
    public var width: ?BorderSideWidth   // 宽度
    public var style: ?LineStyle         // 样式
    public var color: ?String            // 颜色

    public init() {
        this.width = None
        this.style = None
        this.color = None
    }

    public init(width!: ?BorderSideWidth, style!: ?LineStyle, color!: ?String) {
        this.width = width
        this.style = style
        this.color = color
    }

    /// 严格翻译自 BorderShorthand.eql
    public func eql(other: BorderShorthand): Bool {
        let wEq = match (width) {
            case Some(a) => match (other.width) { case Some(b) => a == b case None => false }
            case None => match (other.width) { case Some(_) => false case None => true }
        }
        let sEq = match (style) {
            case Some(a) => match (other.style) { case Some(b) => a == b case None => false }
            case None => match (other.style) { case Some(_) => false case None => true }
        }
        let cEq = match (color) {
            case Some(a) => match (other.color) { case Some(b) => a == b case None => false }
            case None => match (other.color) { case Some(_) => false case None => true }
        }
        wEq && sEq && cEq
    }

    /// 设置边框值
    /// 严格翻译自 BorderShorthand.setBorder
    public func setBorder(border: GenericBorder): Unit {
        this.width = Some(border.width.deepClone())
        this.style = Some(border.style)
        this.color = Some(border.color)
    }

    /// 重置为空
    /// 严格翻译自 BorderShorthand.reset
    public func reset(): Unit {
        this.width = None
        this.style = None
        this.color = None
    }

    /// 是否所有属性都已设置
    /// 严格翻译自 BorderShorthand.isValid
    public func isValid(): Bool {
        width.isSome() && style.isSome() && color.isSome()
    }

    /// 转为 GenericBorder
    /// 严格翻译自 BorderShorthand.toBorder
    public func toBorder(): GenericBorder {
        GenericBorder(
            width: match (width) { case Some(w) => w case None => BorderSideWidth.Medium },
            style: match (style) { case Some(s) => s case None => LineStyle.None },
            color: match (color) { case Some(c) => c case None => "currentcolor" }
        )
    }
}

// ============================================================================
// PropertyCategory
// 严格翻译自 PropertyCategory
// ============================================================================

/// 属性类别（物理/逻辑）
/// 严格翻译自 PropertyCategory
public enum PropertyCategory {
    | Physical  // 物理方向
    | Logical   // 逻辑方向

    public static func default(): PropertyCategory {
        PropertyCategory.Physical
    }
}

// ============================================================================
// BorderHandler
// 严格翻译自 BorderHandler struct
// ============================================================================

/// 边框属性处理器
/// 严格翻译自 BorderHandler
/// 管理 8 个方向的边框状态，合并/输出边框简写属性
public class BorderHandler {
    // 八个方向的边框简写状态
    public var borderTop: BorderShorthand
    public var borderBottom: BorderShorthand
    public var borderLeft: BorderShorthand
    public var borderRight: BorderShorthand
    public var borderBlockStart: BorderShorthand
    public var borderBlockEnd: BorderShorthand
    public var borderInlineStart: BorderShorthand
    public var borderInlineEnd: BorderShorthand

    /// 当前属性类别
    public var category: PropertyCategory
    /// 已刷新的属性位集
    public var flushedProperties: BorderProperty
    /// 是否有任一属性被设置
    public var hasAny: Bool

    public init() {
        this.borderTop = BorderShorthand()
        this.borderBottom = BorderShorthand()
        this.borderLeft = BorderShorthand()
        this.borderRight = BorderShorthand()
        this.borderBlockStart = BorderShorthand()
        this.borderBlockEnd = BorderShorthand()
        this.borderInlineStart = BorderShorthand()
        this.borderInlineEnd = BorderShorthand()
        this.category = PropertyCategory.Physical
        this.flushedProperties = BorderProperty()
        this.hasAny = false
    }

    // ========================================================================
    // 辅助: propertyHelper
    // 严格翻译自 BorderHandler.handleProperty 中的 propertyHelper 闭包
    // ========================================================================

    /// 设置指定方向和子属性
    private func propertyHelper(key: String, prop: String, val: Any, cat: PropertyCategory): Unit {
        let border = getBorder(key)
        match (prop) {
            case "color" => border.color = Some(val.toString())
            case "width" => match (val) {
                case w: BorderSideWidth => border.width = Some(w.deepClone())
                case _ => ()
            }
            case "style" => match (val) {
                case s: LineStyle => border.style = Some(s)
                case _ => ()
            }
            case _ => ()
        }
        this.category = cat
        this.hasAny = true
    }

    /// 设置整个边框
    private func setBorderHelper(key: String, val: GenericBorder, cat: PropertyCategory): Unit {
        let border = getBorder(key)
        border.setBorder(val)
        this.category = cat
        this.hasAny = true
    }

    /// 获取指定方向名称的 BorderShorthand
    private func getBorder(key: String): BorderShorthand {
        match (key) {
            case "border_top" => borderTop
            case "border_bottom" => borderBottom
            case "border_left" => borderLeft
            case "border_right" => borderRight
            case "border_block_start" => borderBlockStart
            case "border_block_end" => borderBlockEnd
            case "border_inline_start" => borderInlineStart
            case "border_inline_end" => borderInlineEnd
            case _ => borderTop
        }
    }

    // ========================================================================
    // handleProperty
    // 严格翻译自 BorderHandler.handleProperty
    // ========================================================================

    /// 处理属性
    /// 严格翻译自 BorderHandler.handleProperty
    /// 返回 true 表示已处理该属性
    public func handleProperty(propertyName: String, propertyValue: Any, dest: ArrayList<String>): Bool {
        match (propertyName) {
            // 单边颜色
            case "border-top-color" =>
                propertyHelper("border_top", "color", propertyValue, PropertyCategory.Physical)
            case "border-bottom-color" =>
                propertyHelper("border_bottom", "color", propertyValue, PropertyCategory.Physical)
            case "border-left-color" =>
                propertyHelper("border_left", "color", propertyValue, PropertyCategory.Physical)
            case "border-right-color" =>
                propertyHelper("border_right", "color", propertyValue, PropertyCategory.Physical)
            case "border-block-start-color" =>
                propertyHelper("border_block_start", "color", propertyValue, PropertyCategory.Logical)
            case "border-block-end-color" =>
                propertyHelper("border_block_end", "color", propertyValue, PropertyCategory.Logical)
            case "border-inline-start-color" =>
                propertyHelper("border_inline_start", "color", propertyValue, PropertyCategory.Logical)
            case "border-inline-end-color" =>
                propertyHelper("border_inline_end", "color", propertyValue, PropertyCategory.Logical)
            // 单边宽度
            case "border-top-width" =>
                propertyHelper("border_top", "width", propertyValue, PropertyCategory.Physical)
            case "border-bottom-width" =>
                propertyHelper("border_bottom", "width", propertyValue, PropertyCategory.Physical)
            case "border-left-width" =>
                propertyHelper("border_left", "width", propertyValue, PropertyCategory.Physical)
            case "border-right-width" =>
                propertyHelper("border_right", "width", propertyValue, PropertyCategory.Physical)
            case "border-block-start-width" =>
                propertyHelper("border_block_start", "width", propertyValue, PropertyCategory.Logical)
            case "border-block-end-width" =>
                propertyHelper("border_block_end", "width", propertyValue, PropertyCategory.Logical)
            case "border-inline-start-width" =>
                propertyHelper("border_inline_start", "width", propertyValue, PropertyCategory.Logical)
            case "border-inline-end-width" =>
                propertyHelper("border_inline_end", "width", propertyValue, PropertyCategory.Logical)
            // 单边样式
            case "border-top-style" =>
                propertyHelper("border_top", "style", propertyValue, PropertyCategory.Physical)
            case "border-bottom-style" =>
                propertyHelper("border_bottom", "style", propertyValue, PropertyCategory.Physical)
            case "border-left-style" =>
                propertyHelper("border_left", "style", propertyValue, PropertyCategory.Physical)
            case "border-right-style" =>
                propertyHelper("border_right", "style", propertyValue, PropertyCategory.Physical)
            case "border-block-start-style" =>
                propertyHelper("border_block_start", "style", propertyValue, PropertyCategory.Logical)
            case "border-block-end-style" =>
                propertyHelper("border_block_end", "style", propertyValue, PropertyCategory.Logical)
            case "border-inline-start-style" =>
                propertyHelper("border_inline_start", "style", propertyValue, PropertyCategory.Logical)
            case "border-inline-end-style" =>
                propertyHelper("border_inline_end", "style", propertyValue, PropertyCategory.Logical)
            // 单边简写
            case "border-top" =>
                match (propertyValue) {
                    case v: GenericBorder => setBorderHelper("border_top", v, PropertyCategory.Physical)
                    case _ => ()
                }
            case "border-bottom" =>
                match (propertyValue) {
                    case v: GenericBorder => setBorderHelper("border_bottom", v, PropertyCategory.Physical)
                    case _ => ()
                }
            case "border-left" =>
                match (propertyValue) {
                    case v: GenericBorder => setBorderHelper("border_left", v, PropertyCategory.Physical)
                    case _ => ()
                }
            case "border-right" =>
                match (propertyValue) {
                    case v: GenericBorder => setBorderHelper("border_right", v, PropertyCategory.Physical)
                    case _ => ()
                }
            case "border-block-start" =>
                match (propertyValue) {
                    case v: GenericBorder => setBorderHelper("border_block_start", v, PropertyCategory.Logical)
                    case _ => ()
                }
            case "border-block-end" =>
                match (propertyValue) {
                    case v: GenericBorder => setBorderHelper("border_block_end", v, PropertyCategory.Logical)
                    case _ => ()
                }
            case "border-inline-start" =>
                match (propertyValue) {
                    case v: GenericBorder => setBorderHelper("border_inline_start", v, PropertyCategory.Logical)
                    case _ => ()
                }
            case "border-inline-end" =>
                match (propertyValue) {
                    case v: GenericBorder => setBorderHelper("border_inline_end", v, PropertyCategory.Logical)
                    case _ => ()
                }
            // 四方向 width/style/color
            case "border-width" =>
                match (propertyValue) {
                    case v: BorderWidth =>
                        propertyHelper("border_top", "width", v.top, PropertyCategory.Physical)
                        propertyHelper("border_right", "width", v.right, PropertyCategory.Physical)
                        propertyHelper("border_bottom", "width", v.bottom, PropertyCategory.Physical)
                        propertyHelper("border_left", "width", v.left, PropertyCategory.Physical)
                        borderBlockStart.width = None
                        borderBlockEnd.width = None
                        borderInlineStart.width = None
                        borderInlineEnd.width = None
                        hasAny = true
                    case _ => ()
                }
            case "border-style" =>
                match (propertyValue) {
                    case v: BorderStyle =>
                        propertyHelper("border_top", "style", v.top, PropertyCategory.Physical)
                        propertyHelper("border_right", "style", v.right, PropertyCategory.Physical)
                        propertyHelper("border_bottom", "style", v.bottom, PropertyCategory.Physical)
                        propertyHelper("border_left", "style", v.left, PropertyCategory.Physical)
                        borderBlockStart.style = None
                        borderBlockEnd.style = None
                        borderInlineStart.style = None
                        borderInlineEnd.style = None
                        hasAny = true
                    case _ => ()
                }
            case "border-color" =>
                match (propertyValue) {
                    case v: BorderColor =>
                        propertyHelper("border_top", "color", v.top, PropertyCategory.Physical)
                        propertyHelper("border_right", "color", v.right, PropertyCategory.Physical)
                        propertyHelper("border_bottom", "color", v.bottom, PropertyCategory.Physical)
                        propertyHelper("border_left", "color", v.left, PropertyCategory.Physical)
                        borderBlockStart.color = None
                        borderBlockEnd.color = None
                        borderInlineStart.color = None
                        borderInlineEnd.color = None
                        hasAny = true
                    case _ => ()
                }
            // 全方向 border
            case "border" =>
                match (propertyValue) {
                    case v: GenericBorder =>
                        borderTop.setBorder(v)
                        borderBottom.setBorder(v)
                        borderLeft.setBorder(v)
                        borderRight.setBorder(v)
                        borderBlockStart.reset()
                        borderBlockEnd.reset()
                        borderInlineStart.reset()
                        borderInlineEnd.reset()
                        hasAny = true
                    case _ => ()
                }
            case _ => return false
        }
        return true
    }

    // ========================================================================
    // finalize
    // 严格翻译自 BorderHandler.finalize
    // ========================================================================

    /// 最终化输出
    /// 严格翻译自 BorderHandler.finalize
    public func finalize(dest: ArrayList<String>): Unit {
        flush(dest)
        flushedProperties = BorderProperty()
    }

    // ========================================================================
    // flush
    // 严格翻译自 BorderHandler.flush
    // ========================================================================

    /// 将边框状态输出为 CSS 声明
    /// 严格翻译自 BorderHandler.flush
    public func flush(dest: ArrayList<String>): Unit {
        if (!hasAny) { return }
        hasAny = false

        // 输出物理方向的四个边框
        flushCategory(
            dest,
            "border-top", "border-top-width", "border-top-style", "border-top-color", borderTop,
            "border-bottom", "border-bottom-width", "border-bottom-style", "border-bottom-color", borderBottom,
            "border-left", "border-left-width", "border-left-style", "border-left-color", borderLeft,
            "border-right", "border-right-width", "border-right-style", "border-right-color", borderRight,
            false
        )

        // 输出逻辑方向的四个边框
        flushCategory(
            dest,
            "border-block-start", "border-block-start-width", "border-block-start-style", "border-block-start-color", borderBlockStart,
            "border-block-end", "border-block-end-width", "border-block-end-style", "border-block-end-color", borderBlockEnd,
            "border-inline-start", "border-inline-start-width", "border-inline-start-style", "border-inline-start-color", borderInlineStart,
            "border-inline-end", "border-inline-end-width", "border-inline-end-style", "border-inline-end-color", borderInlineEnd,
            true
        )

        // 重置所有方向
        borderTop.reset()
        borderBottom.reset()
        borderLeft.reset()
        borderRight.reset()
        borderBlockStart.reset()
        borderBlockEnd.reset()
        borderInlineStart.reset()
        borderInlineEnd.reset()
    }

    // ========================================================================
    // flushCategory
    // 严格翻译自 FlushContext.flushCategory
    // ========================================================================

    /// 刷新一个边框类别 (物理或逻辑方向)
    /// 严格翻译自 FlushContext.flushCategory
    private func flushCategory(
        dest: ArrayList<String>,
        bsProp: String, bsWidth: String, bsStyle: String, bsColor: String, bs: BorderShorthand,
        beProp: String, beWidth: String, beStyle: String, beColor: String, be: BorderShorthand,
        isProp: String, isWidth: String, isStyle: String, isColor: String, is_: BorderShorthand,
        ieProp: String, ieWidth: String, ieStyle: String, ieColor: String, ie: BorderShorthand,
        isLogical: Bool
    ): Unit {
        // 如果所有方向都有效，尝试合并输出
        if (bs.isValid() && be.isValid() && is_.isValid() && ie.isValid()) {
            let topEqBottom = bs.eql(be)
            let leftEqRight = is_.eql(ie)
            let topEqLeft = bs.eql(is_)

            if (topEqBottom && topEqLeft && bs.eql(ie)) {
                // 所有四边相同 -> border
                dest.append("border: ${bs.toBorder().toCss()}")
            } else if (topEqBottom && topEqLeft) {
                dest.append("border: ${bs.toBorder().toCss()}")
                dest.append("${ieProp}: ${ie.toBorder().toCss()}")
            } else if (topEqBottom && bs.eql(ie)) {
                dest.append("border: ${bs.toBorder().toCss()}")
                dest.append("${isProp}: ${is_.toBorder().toCss()}")
            } else if (leftEqRight && be.eql(is_)) {
                dest.append("border: ${is_.toBorder().toCss()}")
                dest.append("${bsProp}: ${bs.toBorder().toCss()}")
            } else if (leftEqRight && topEqLeft) {
                dest.append("border: ${is_.toBorder().toCss()}")
                dest.append("${beProp}: ${be.toBorder().toCss()}")
            } else if (topEqBottom) {
                dest.append("${bsProp}: ${bs.toBorder().toCss()}")
                dest.append("${isProp}: ${is_.toBorder().toCss()}")
                dest.append("${ieProp}: ${ie.toBorder().toCss()}")
            } else if (leftEqRight) {
                dest.append("${isProp}: ${is_.toBorder().toCss()}")
                dest.append("${bsProp}: ${bs.toBorder().toCss()}")
                dest.append("${beProp}: ${be.toBorder().toCss()}")
            } else {
                // 四边都不同
                dest.append("${bsProp}: ${bs.toBorder().toCss()}")
                dest.append("${beProp}: ${be.toBorder().toCss()}")
                dest.append("${isProp}: ${is_.toBorder().toCss()}")
                dest.append("${ieProp}: ${ie.toBorder().toCss()}")
            }
        } else {
            // 部分有效 - 输出各边单独的子属性
            flushSide(dest, bsProp, bsWidth, bsStyle, bsColor, bs)
            flushSide(dest, beProp, beWidth, beStyle, beColor, be)
            flushSide(dest, isProp, isWidth, isStyle, isColor, is_)
            flushSide(dest, ieProp, ieWidth, ieStyle, ieColor, ie)
        }
    }

    /// 输出单边的子属性
    /// 严格翻译自 FlushContext.State.side
    private func flushSide(
        dest: ArrayList<String>,
        prop: String, widthProp: String, styleProp: String, colorProp: String,
        side: BorderShorthand
    ): Unit {
        if (side.isValid()) {
            dest.append("${prop}: ${side.toBorder().toCss()}")
        } else {
            match (side.style) {
                case Some(s) => dest.append("${styleProp}: ${s.toCss()}")
                case None => ()
            }
            match (side.width) {
                case Some(w) => dest.append("${widthProp}: ${w.toCss()}")
                case None => ()
            }
            match (side.color) {
                case Some(c) => dest.append("${colorProp}: ${c}")
                case None => ()
            }
        }
    }
}

// ============================================================================
// isBorderProperty
// 严格翻译自 isBorderProperty 函数
// ============================================================================

/// 判断属性名是否为边框相关属性
/// 严格翻译自 isBorderProperty
public func isBorderProperty(propertyName: String): Bool {
    match (propertyName) {
        case "border-top-color" | "border-bottom-color" |
             "border-left-color" | "border-right-color" |
             "border-block-start-color" | "border-block-end-color" |
             "border-block-color" |
             "border-inline-start-color" | "border-inline-end-color" |
             "border-inline-color" |
             "border-top-width" | "border-bottom-width" |
             "border-left-width" | "border-right-width" |
             "border-block-start-width" | "border-block-end-width" |
             "border-block-width" |
             "border-inline-start-width" | "border-inline-end-width" |
             "border-inline-width" |
             "border-top-style" | "border-bottom-style" |
             "border-left-style" | "border-right-style" |
             "border-block-start-style" | "border-block-end-style" |
             "border-block-style" |
             "border-inline-start-style" | "border-inline-end-style" |
             "border-inline-style" |
             "border-top" | "border-bottom" |
             "border-left" | "border-right" |
             "border-block-start" | "border-block-end" |
             "border-inline-start" | "border-inline-end" |
             "border-block" | "border-inline" |
             "border-width" | "border-style" |
             "border-color" | "border" => true
        case _ => false
    }
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
