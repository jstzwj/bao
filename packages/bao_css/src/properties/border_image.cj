// bao_css - CSS Properties: Border Image
// 严格翻译自: bun/src/css/properties/border_image.rs
//   对应: border_image.zig - CSS 边框图像属性
//   对应: BorderImage, BorderImageRepeat, BorderImageSideWidth
//   对应: BorderImageSlice, BorderImageRepeatKeyword
//   对应: BorderImageProperty (bitflags)
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// BorderImage
// 严格翻译自 BorderImage
// ============================================================================

/// border-image 属性值
/// 严格翻译自 BorderImage
public class BorderImage {
    public var source: String                    // 边框图像源
    public var slice: BorderImageSlice           // 图像切片
    public var width: ArrayList<BorderImageSideWidth>   // 边框图像宽度 (4 值)
    public var outset: ArrayList<String>         // 图像外扩距离 (4 值)
    public var repeat: BorderImageRepeat         // 图像重复方式

    public init(source: String, slice: BorderImageSlice, width: ArrayList<BorderImageSideWidth>,
                outset: ArrayList<String>, repeat: BorderImageRepeat) {
        this.source = source
        this.slice = slice
        this.width = width
        this.outset = outset
        this.repeat = repeat
    }

    public static func default(): BorderImage {
        BorderImage(
            source: "none",
            slice: BorderImageSlice.default(),
            width: ArrayList<BorderImageSideWidth>(),
            outset: ArrayList<String>(),
            repeat: BorderImageRepeat.default()
        )
    }

    public func toCss(): String {
        var parts = ArrayList<String>()

        // 源
        if (source != "none") {
            parts.append(source)
        }

        // 切片
        var hasSlice = !slice.isDefault()
        var hasWidth = !isWidthDefault()
        var hasOutset = !isOutsetDefault()

        if (hasSlice || hasWidth || hasOutset) {
            parts.append(slice.toCss())
            if (hasWidth || hasOutset) {
                parts.append("/")
            }
            if (hasWidth) {
                parts.append(serializeSideWidthRect(width))
            }
            if (hasOutset) {
                parts.append("/")
                parts.append(serializeStringRect(outset))
            }
        }

        // 重复
        if (!repeat.isDefault()) {
            parts.append(repeat.toCss())
        }

        if (parts.isEmpty()) {
            return "none"
        }
        return String.join(" ", parts)
    }

    private func isWidthDefault(): Bool {
        if (width.size != 4) {
            return width.isEmpty()
        }
        return width[0] == BorderImageSideWidth.Number("1") &&
               width[1] == BorderImageSideWidth.Number("1") &&
               width[2] == BorderImageSideWidth.Number("1") &&
               width[3] == BorderImageSideWidth.Number("1")
    }

    private func isOutsetDefault(): Bool {
        if (outset.size != 4) {
            return outset.isEmpty()
        }
        return outset[0] == "0" && outset[1] == "0" && outset[2] == "0" && outset[3] == "0"
    }
}

// ============================================================================
// BorderImageRepeat
// 严格翻译自 BorderImageRepeat
// ============================================================================

/// border-image-repeat 属性值
/// 严格翻译自 BorderImageRepeat
public class BorderImageRepeat {
    public var horizontal: BorderImageRepeatKeyword  // 水平重复
    public var vertical: BorderImageRepeatKeyword    // 垂直重复

    public init(horizontal: BorderImageRepeatKeyword, vertical: BorderImageRepeatKeyword) {
        this.horizontal = horizontal
        this.vertical = vertical
    }

    public static func default(): BorderImageRepeat {
        BorderImageRepeat(horizontal: BorderImageRepeatKeyword.Stretch, vertical: BorderImageRepeatKeyword.Stretch)
    }

    public func isDefault(): Bool {
        horizontal == BorderImageRepeatKeyword.Stretch && vertical == BorderImageRepeatKeyword.Stretch
    }

    public func toCss(): String {
        if (horizontal == vertical) {
            return horizontal.toCss()
        }
        return horizontal.toCss() + " " + vertical.toCss()
    }
}

// ============================================================================
// BorderImageRepeatKeyword
// 严格翻译自 BorderImageRepeatKeyword (DefineEnumProperty)
// ============================================================================

/// border-image-repeat 关键字
/// 严格翻译自 BorderImageRepeatKeyword
public enum BorderImageRepeatKeyword {
    | Stretch  // 拉伸
    | Repeat   // 平铺
    | Round    // 缩放平铺
    | Space    // 间距平铺

    public func toCss(): String {
        match (this) {
            case Stretch => "stretch"
            case Repeat => "repeat"
            case Round => "round"
            case Space => "space"
        }
    }
}

// ============================================================================
// BorderImageSideWidth
// 严格翻译自 BorderImageSideWidth
// ============================================================================

/// border-image-width 单侧值
/// 严格翻译自 BorderImageSideWidth
public enum BorderImageSideWidth {
    | Number(String)            // 数值（边框宽度的倍数）
    | LengthPercentage(String)  // 长度或百分比
    | Auto                      // 自动

    public func toCss(): String {
        match (this) {
            case Number(n) => n
            case LengthPercentage(l) => l
            case Auto => "auto"
        }
    }

    public static func default(): BorderImageSideWidth {
        BorderImageSideWidth.Number("1")
    }
}

// ============================================================================
// BorderImageSlice
// 严格翻译自 BorderImageSlice
// ============================================================================

/// border-image-slice 属性值
/// 严格翻译自 BorderImageSlice
public class BorderImageSlice {
    public var offsets: ArrayList<String>  // 四个切片偏移量（上/右/下/左）
    public var fill: Bool                  // 是否保留中心区域

    public init(offsets: ArrayList<String>, fill: Bool) {
        this.offsets = offsets
        this.fill = fill
    }

    public static func default(): BorderImageSlice {
        var offsets = ArrayList<String>()
        offsets.append("100%")
        offsets.append("100%")
        offsets.append("100%")
        offsets.append("100%")
        return BorderImageSlice(offsets: offsets, fill: false)
    }

    public func isDefault(): Bool {
        if (fill) {
            return false
        }
        if (offsets.size != 4) {
            return offsets.isEmpty()
        }
        return offsets[0] == "100%" && offsets[1] == "100%" &&
               offsets[2] == "100%" && offsets[3] == "100%"
    }

    public func toCss(): String {
        var result = serializeStringRect(offsets)
        if (fill) {
            result = result + " fill"
        }
        return result
    }
}

// ============================================================================
// BorderImageProperty (bitflags)
// 严格翻译自 BorderImageProperty
// ============================================================================

/// border-image 属性位标志
/// 严格翻译自 BorderImageProperty
public enum BorderImagePropertyFlag {
    | Source   // border-image-source
    | Slice    // border-image-slice
    | Width    // border-image-width
    | Outset   // border-image-outset
    | Repeat   // border-image-repeat
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 序列化 SideWidth 矩形
public func serializeSideWidthRect(values: ArrayList<BorderImageSideWidth>): String {
    if (values.isEmpty()) {
        return ""
    }
    if (values.size == 1) {
        return values[0].toCss()
    }
    if (values.size == 2) {
        return values[0].toCss() + " " + values[1].toCss()
    }
    if (values.size == 3) {
        return values[0].toCss() + " " + values[1].toCss() + " " + values[2].toCss()
    }
    return values[0].toCss() + " " + values[1].toCss() + " " + values[2].toCss() + " " + values[3].toCss()
}

/// 序列化字符串矩形
public func serializeStringRect(values: ArrayList<String>): String {
    if (values.isEmpty()) {
        return ""
    }
    if (values.size == 1) {
        return values[0]
    }
    if (values.size == 2) {
        return values[0] + " " + values[1]
    }
    if (values.size == 3) {
        return values[0] + " " + values[1] + " " + values[2]
    }
    return values[0] + " " + values[1] + " " + values[2] + " " + values[3]
}
