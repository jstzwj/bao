// bao_css - CSS Properties: Masking
// 严格翻译自: bun/src/css/properties/masking.rs
//   对应: masking.zig - CSS 遮罩属性
//   对应: ClipPath, GeometryBox, BasicShape (4 variants)
//   对应: InsetRect, Circle, Ellipse, Polygon, ShapeRadius, Point
//   对应: MaskMode, MaskClip, MaskComposite, MaskType, Mask, MaskBorder
//   对应: MaskBorderMode, WebKitMaskComposite, WebKitMaskSourceType
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// ClipPath
// 严格翻译自 ClipPath
// ============================================================================

/// clip-path 属性值
/// 严格翻译自 ClipPath
public enum ClipPath {
    | None                       // 无裁剪路径
    | Url(String)                // SVG 路径引用
    | Shape(BasicShape, GeometryBox) // 基本形状 + 参考盒
    | Box(GeometryBox)           // 仅参考盒

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Url(u) => "url(" + u + ")"
            case Shape(shape, box_) => {
                var result = shape.toCss()
                if (box_ != GeometryBox.BorderBox) {
                    result = result + " " + box_.toCss()
                }
                return result
            }
            case Box(b) => b.toCss()
        }
    }
}

// ============================================================================
// GeometryBox
// 严格翻译自 GeometryBox (DefineEnumProperty)
// ============================================================================

/// geometry-box 值
/// 严格翻译自 GeometryBox
public enum GeometryBox {
    | BorderBox     // 边框盒
    | PaddingBox    // 内边距盒
    | ContentBox    // 内容盒
    | MarginBox     // 外边距盒
    | FillBox       // 填充盒
    | StrokeBox     // 描边盒
    | ViewBox       // 视口盒

    public func toCss(): String {
        match (this) {
            case BorderBox => "border-box"
            case PaddingBox => "padding-box"
            case ContentBox => "content-box"
            case MarginBox => "margin-box"
            case FillBox => "fill-box"
            case StrokeBox => "stroke-box"
            case ViewBox => "view-box"
        }
    }
}

// ============================================================================
// BasicShape
// 严格翻译自 BasicShape (4 variants)
// ============================================================================

/// basic-shape 值
/// 严格翻译自 BasicShape
public enum BasicShape {
    | Inset(InsetRect)        // inset()
    | Circle(Circle)          // circle()
    | Ellipse(Ellipse)        // ellipse()
    | Polygon(Polygon)        // polygon()

    public func toCss(): String {
        match (this) {
            case Inset(r) => r.toCss()
            case Circle(c) => c.toCss()
            case Ellipse(e) => e.toCss()
            case Polygon(p) => p.toCss()
        }
    }
}

// ============================================================================
// InsetRect
// 严格翻译自 InsetRect
// ============================================================================

/// inset() 矩形形状
/// 严格翻译自 InsetRect
public class InsetRect {
    public var rect: ArrayList<String>     // 四个偏移量 (上/右/下/左)
    public var radius: String              // 圆角半径

    public init(rect: ArrayList<String>, radius: String) {
        this.rect = rect
        this.radius = radius
    }

    public func toCss(): String {
        var result = "inset(" + String.join(" ", rect)
        if (radius != "") {
            result = result + " round " + radius
        }
        return result + ")"
    }
}

// ============================================================================
// Circle
// 严格翻译自 Circle
// ============================================================================

/// circle() 形状
/// 严格翻译自 Circle
public class Circle {
    public var radius: ShapeRadius    // 半径
    public var position: String       // 中心位置

    public init(radius: ShapeRadius, position: String) {
        this.radius = radius
        this.position = position
    }

    public func toCss(): String {
        var result = "circle("
        if (radius != ShapeRadius.default()) {
            result = result + radius.toCss()
        }
        if (position != "center") {
            result = result + " at " + position
        }
        return result + ")"
    }
}

// ============================================================================
// Ellipse
// 严格翻译自 Ellipse
// ============================================================================

/// ellipse() 形状
/// 严格翻译自 Ellipse
public class Ellipse {
    public var radiusX: ShapeRadius   // X 半径
    public var radiusY: ShapeRadius   // Y 半径
    public var position: String       // 中心位置

    public init(radiusX: ShapeRadius, radiusY: ShapeRadius, position: String) {
        this.radiusX = radiusX
        this.radiusY = radiusY
        this.position = position
    }

    public func toCss(): String {
        var result = "ellipse("
        if (radiusX != ShapeRadius.default() || radiusY != ShapeRadius.default()) {
            result = result + radiusX.toCss() + " " + radiusY.toCss()
        }
        if (position != "center") {
            result = result + " at " + position
        }
        return result + ")"
    }
}

// ============================================================================
// Polygon
// 严格翻译自 Polygon
// ============================================================================

/// polygon() 形状
/// 严格翻译自 Polygon
public class Polygon {
    public var fillRule: String        // 填充规则
    public var points: ArrayList<Point> // 顶点列表

    public init(fillRule: String, points: ArrayList<Point>) {
        this.fillRule = fillRule
        this.points = points
    }

    public func toCss(): String {
        var result = "polygon("
        if (fillRule != "") {
            result = result + fillRule + ", "
        }
        var pointStrs = ArrayList<String>()
        for (p in points) {
            pointStrs.append(p.x + " " + p.y)
        }
        return result + String.join(", ", pointStrs) + ")"
    }
}

// ============================================================================
// ShapeRadius
// 严格翻译自 ShapeRadius
// ============================================================================

/// shape-radius 值
/// 严格翻译自 ShapeRadius
public enum ShapeRadius {
    | LengthPercentage(String)  // 显式长度/百分比
    | ClosestSide               // 最近边
    | FarthestSide              // 最远边

    public func toCss(): String {
        match (this) {
            case LengthPercentage(l) => l
            case ClosestSide => "closest-side"
            case FarthestSide => "farthest-side"
        }
    }

    public static func default(): ShapeRadius {
        ShapeRadius.ClosestSide
    }
}

// ============================================================================
// Point
// 严格翻译自 Point
// ============================================================================

/// 多边形顶点
/// 严格翻译自 Point
public class Point {
    public var x: String  // X 坐标
    public var y: String  // Y 坐标

    public init(x: String, y: String) {
        this.x = x
        this.y = y
    }
}

// ============================================================================
// MaskMode
// 严格翻译自 MaskMode (DefineEnumProperty)
// ============================================================================

/// mask-mode 属性值
/// 严格翻译自 MaskMode
public enum MaskMode {
    | Luminance     // 亮度
    | Alpha         // 透明度
    | MatchSource   // 匹配源

    public func toCss(): String {
        match (this) {
            case Luminance => "luminance"
            case Alpha => "alpha"
            case MatchSource => "match-source"
        }
    }
}

// ============================================================================
// MaskClip
// 严格翻译自 MaskClip
// ============================================================================

/// mask-clip 属性值
/// 严格翻译自 MaskClip
public enum MaskClip {
    | GeometryBox(GeometryBox)  // 几何盒
    | NoClip                    // 不裁剪

    public func toCss(): String {
        match (this) {
            case GeometryBox(b) => b.toCss()
            case NoClip => "no-clip"
        }
    }
}

// ============================================================================
// MaskComposite
// 严格翻译自 MaskComposite (DefineEnumProperty)
// ============================================================================

/// mask-composite 属性值
/// 严格翻译自 MaskComposite
public enum MaskComposite {
    | Add        // 添加
    | Subtract   // 减去
    | Intersect  // 相交
    | Exclude    // 排除

    public func toCss(): String {
        match (this) {
            case Add => "add"
            case Subtract => "subtract"
            case Intersect => "intersect"
            case Exclude => "exclude"
        }
    }
}

// ============================================================================
// MaskType
// 严格翻译自 MaskType (DefineEnumProperty)
// ============================================================================

/// mask-type 属性值
/// 严格翻译自 MaskType
public enum MaskType {
    | Luminance  // 亮度
    | Alpha      // 透明度

    public func toCss(): String {
        match (this) {
            case Luminance => "luminance"
            case Alpha => "alpha"
        }
    }
}

// ============================================================================
// Mask
// 严格翻译自 Mask
// ============================================================================

/// mask 属性值
/// 严格翻译自 Mask
public class Mask {
    public var image: String              // 遮罩图像
    public var position: String           // 遮罩位置
    public var size: String               // 遮罩大小
    public var repeat: String             // 重复方式
    public var clip: MaskClip             // 裁剪盒
    public var origin: GeometryBox        // 原点盒
    public var composite: MaskComposite   // 合成方式
    public var mode: MaskMode             // 遮罩模式

    public init(image: String, position: String, size: String, repeat: String,
                clip: MaskClip, origin: GeometryBox, composite: MaskComposite, mode: MaskMode) {
        this.image = image
        this.position = position
        this.size = size
        this.repeat = repeat
        this.clip = clip
        this.origin = origin
        this.composite = composite
        this.mode = mode
    }

    public static func default(): Mask {
        Mask(
            image: "none",
            position: "0% 0%",
            size: "auto",
            repeat: "repeat",
            clip: MaskClip.GeometryBox(GeometryBox.BorderBox),
            origin: GeometryBox.BorderBox,
            composite: MaskComposite.Add,
            mode: MaskMode.MatchSource
        )
    }

    public func toCss(): String {
        var parts = ArrayList<String>()

        // 图像
        if (image != "none") {
            parts.append(image)
        }

        // 位置
        if (position != "0% 0%") {
            parts.append(position)
            if (size != "auto") {
                parts.append("/ " + size)
            }
        }

        // 重复
        if (repeat != "repeat") {
            parts.append(repeat)
        }

        // 原点 / 裁剪
        if (origin != GeometryBox.BorderBox ||
            clip != MaskClip.GeometryBox(GeometryBox.BorderBox)) {
            parts.append(origin.toCss())
            if (clip.toCss() != origin.toCss()) {
                parts.append(clip.toCss())
            }
        }

        // 合成
        if (composite != MaskComposite.Add) {
            parts.append(composite.toCss())
        }

        // 模式
        if (mode != MaskMode.MatchSource) {
            parts.append(mode.toCss())
        }

        if (parts.isEmpty()) {
            return "none"
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// MaskBorderMode
// 严格翻译自 MaskBorderMode (DefineEnumProperty)
// ============================================================================

/// mask-border-mode 属性值
/// 严格翻译自 MaskBorderMode
public enum MaskBorderMode {
    | Luminance  // 亮度
    | Alpha      // 透明度

    public func toCss(): String {
        match (this) {
            case Luminance => "luminance"
            case Alpha => "alpha"
        }
    }
}

// ============================================================================
// MaskBorder
// 严格翻译自 MaskBorder
// ============================================================================

/// mask-border 属性值
/// 严格翻译自 MaskBorder
public class MaskBorder {
    public var source: String               // 遮罩边框图像
    public var slice: BorderImageSlice      // 切片
    public var width: ArrayList<BorderImageSideWidth>  // 宽度 (4 值)
    public var outset: ArrayList<String>    // 外扩距离 (4 值)
    public var repeat: BorderImageRepeat    // 重复方式
    public var mode: MaskBorderMode         // 遮罩边框模式

    public init(source: String, slice: BorderImageSlice, width: ArrayList<BorderImageSideWidth>,
                outset: ArrayList<String>, repeat: BorderImageRepeat, mode: MaskBorderMode) {
        this.source = source
        this.slice = slice
        this.width = width
        this.outset = outset
        this.repeat = repeat
        this.mode = mode
    }

    public static func default(): MaskBorder {
        MaskBorder(
            source: "none",
            slice: BorderImageSlice.default(),
            width: ArrayList<BorderImageSideWidth>(),
            outset: ArrayList<String>(),
            repeat: BorderImageRepeat.default(),
            mode: MaskBorderMode.Alpha
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
        var hasWidth = !width.isEmpty()
        var hasOutset = !outset.isEmpty()

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

        // 模式
        if (mode != MaskBorderMode.Alpha) {
            parts.append(mode.toCss())
        }

        if (parts.isEmpty()) {
            return "none"
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// WebKitMaskComposite
// 严格翻译自 WebKitMaskComposite (DefineEnumProperty)
// ============================================================================

/// -webkit-mask-composite 属性值
/// 严格翻译自 WebKitMaskComposite
public enum WebKitMaskComposite {
    | Clear
    | Copy
    | SourceOver
    | SourceIn
    | SourceOut
    | SourceAtop
    | DestinationOver
    | DestinationIn
    | DestinationOut
    | DestinationAtop
    | Xor

    public func toCss(): String {
        match (this) {
            case Clear => "clear"
            case Copy => "copy"
            case SourceOver => "source-over"
            case SourceIn => "source-in"
            case SourceOut => "source-out"
            case SourceAtop => "source-atop"
            case DestinationOver => "destination-over"
            case DestinationIn => "destination-in"
            case DestinationOut => "destination-out"
            case DestinationAtop => "destination-atop"
            case Xor => "xor"
        }
    }
}

// ============================================================================
// WebKitMaskSourceType
// 严格翻译自 WebKitMaskSourceType (DefineEnumProperty)
// ============================================================================

/// -webkit-mask-source-type 属性值
/// 严格翻译自 WebKitMaskSourceType
public enum WebKitMaskSourceType {
    | Auto       // 自动
    | Luminance  // 亮度
    | Alpha      // 透明度

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Luminance => "luminance"
            case Alpha => "alpha"
        }
    }
}
