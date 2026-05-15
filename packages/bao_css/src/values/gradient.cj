// 严格翻译自: src/css/values/gradient.zig
// CSS 渐变值类型
// 包含: Gradient, LinearGradient, RadialGradient, ConicGradient, WebKitGradient,
//        LineDirection, EndingShape, Ellipse, Circle, ShapeExtent,
//        GradientItem, ColorStop, WebKitGradientPoint, WebKitGradientPointComponent,
//        WebKitColorStop, HorizontalPositionKeyword, VerticalPositionKeyword

package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 水平位置关键字
// 严格翻译自 HorizontalPositionKeyword enum
// ============================================================================

/// CSS 水平位置关键字 (left / right)
/// 严格翻译自 HorizontalPositionKeyword
public enum CssHorizontalPositionKeyword {
    | Left    // left
    | Right   // right

    public func toCss(): String {
        match (this) {
            case Left => "left"
            case Right => "right"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 垂直位置关键字
// 严格翻译自 VerticalPositionKeyword enum
// ============================================================================

/// CSS 垂直位置关键字 (top / bottom)
/// 严格翻译自 VerticalPositionKeyword
public enum CssVerticalPositionKeyword {
    | Top     // top
    | Bottom  // bottom

    public func toCss(): String {
        match (this) {
            case Top => "top"
            case Bottom => "bottom"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// ShapeExtent - 径向渐变形状范围关键字
// 严格翻译自 ShapeExtent enum
// ============================================================================

/// 径向渐变形状范围关键字
/// 严格翻译自 ShapeExtent enum
public enum CssShapeExtent {
    | ClosestSide     // closest-side
    | FarthestSide    // farthest-side
    | ClosestCorner   // closest-corner
    | FarthestCorner  // farthest-corner

    public func toCss(): String {
        match (this) {
            case ClosestSide => "closest-side"
            case FarthestSide => "farthest-side"
            case ClosestCorner => "closest-corner"
            case FarthestCorner => "farthest-corner"
        }
    }

    public func toString(): String {
        toCss()
    }

    public func eql(other: CssShapeExtent): Bool {
        this == other
    }

    public static func fromCssName(name: String): ?CssShapeExtent {
        match (name) {
            case "closest-side" => Some(ClosestSide)
            case "farthest-side" => Some(FarthestSide)
            case "closest-corner" => Some(ClosestCorner)
            case "farthest-corner" => Some(FarthestCorner)
            case _ => None
        }
    }
}

// ============================================================================
// LineDirection - 线性渐变方向
// 严格翻译自 LineDirection union(enum)
// ============================================================================

/// CSS 线性渐变方向
/// 严格翻译自 LineDirection union(enum) { angle, horizontal, vertical, corner }
public class CssLineDirection {
    public enum CssLineDirectionKind {
        | Angle       // 角度
        | Horizontal  // 水平关键字 (left / right)
        | Vertical    // 垂直关键字 (top / bottom)
        | Corner      // 角 (如 top left, bottom right)
    }

    public var kind: CssLineDirectionKind
    /// 角度值 (kind == Angle)
    public var angle: CssAngle
    /// 水平关键字 (kind == Horizontal 或 Corner)
    public var horizontal: CssHorizontalPositionKeyword
    /// 垂直关键字 (kind == Vertical 或 Corner)
    public var vertical: CssVerticalPositionKeyword

    public init() {
        this.kind = CssLineDirectionKind.Vertical
        this.angle = CssAngle(0.0, CssAngleUnit.Deg)
        this.horizontal = CssHorizontalPositionKeyword.Left
        this.vertical = CssVerticalPositionKeyword.Bottom
    }

    public init(angle: CssAngle) {
        this.kind = CssLineDirectionKind.Angle
        this.angle = angle
        this.horizontal = CssHorizontalPositionKeyword.Left
        this.vertical = CssVerticalPositionKeyword.Top
    }

    public init(horizontal: CssHorizontalPositionKeyword) {
        this.kind = CssLineDirectionKind.Horizontal
        this.angle = CssAngle(0.0, CssAngleUnit.Deg)
        this.horizontal = horizontal
        this.vertical = CssVerticalPositionKeyword.Top
    }

    public init(vertical: CssVerticalPositionKeyword) {
        this.kind = CssLineDirectionKind.Vertical
        this.angle = CssAngle(0.0, CssAngleUnit.Deg)
        this.horizontal = CssHorizontalPositionKeyword.Left
        this.vertical = vertical
    }

    public init(horizontal: CssHorizontalPositionKeyword, vertical: CssVerticalPositionKeyword) {
        this.kind = CssLineDirectionKind.Corner
        this.angle = CssAngle(0.0, CssAngleUnit.Deg)
        this.horizontal = horizontal
        this.vertical = vertical
    }

    /// 转为 CSS 文本
    /// 严格翻译自 LineDirection.toCss
    public func toCss(isPrefixed: Bool): String {
        match (kind) {
            case Angle => angle.toCss()
            case Horizontal => {
                if (isPrefixed) {
                    horizontal.toCss()
                } else {
                    "to ${horizontal.toCss()}"
                }
            }
            case Vertical => {
                if (isPrefixed) {
                    vertical.toCss()
                } else {
                    "to ${vertical.toCss()}"
                }
            }
            case Corner => {
                let prefix = if (isPrefixed) { "" } else { "to " }
                "${prefix}${vertical.toCss()} ${horizontal.toCss()}"
            }
        }
    }

    public func toCss(): String {
        toCss(false)
    }

    /// 转为角度值
    /// 严格翻译自 LinearGradient.toCss 中的角度提取逻辑
    public func toDegrees(): Float64 {
        match (kind) {
            case Angle => angle.toDegrees()
            case Horizontal => {
                match (horizontal) {
                    case Left => 270.0
                    case Right => 90.0
                }
            }
            case Vertical => {
                match (vertical) {
                    case Top => 0.0
                    case Bottom => 180.0
                }
            }
            case Corner => {
                // 角方向的角度计算
                let vAngle: Float64 = match (vertical) {
                    case Top => 0.0
                    case Bottom => 180.0
                }
                let hAngle: Float64 = match (horizontal) {
                    case Left => 270.0
                    case Right => 90.0
                }
                (vAngle + hAngle) / 2.0
            }
        }
    }

    /// 是否为默认方向 (to bottom)
    public func isDefault(): Bool {
        match (kind) {
            case Vertical => vertical == CssVerticalPositionKeyword.Bottom
            case Angle => angle.toDegrees() == 180.0
            case _ => false
        }
    }

    /// 是否为 180 度
    public func isBottom(): Bool {
        match (kind) {
            case Vertical => vertical == CssVerticalPositionKeyword.Bottom
            case Angle => angle.toDegrees() == 180.0
            case _ => false
        }
    }

    /// 相等比较
    public func eql(other: CssLineDirection): Bool {
        if (kind != other.kind) {
            return false
        }
        match (kind) {
            case Angle => angle.eql(other.angle)
            case Horizontal => horizontal == other.horizontal
            case Vertical => vertical == other.vertical
            case Corner => horizontal == other.horizontal && vertical == other.vertical
        }
    }

    /// 深拷贝
    public func deepClone(): CssLineDirection {
        match (kind) {
            case Angle => CssLineDirection(angle.deepClone())
            case Horizontal => CssLineDirection(horizontal)
            case Vertical => CssLineDirection(vertical)
            case Corner => CssLineDirection(horizontal, vertical)
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// ColorStop - 渐变颜色停止点
// 严格翻译自 ColorStop(D) struct
// ============================================================================

/// CSS 渐变颜色停止点
/// 严格翻译自 ColorStop(D) struct { color, position }
public class CssColorStop {
    /// 颜色
    public var color: CssColor
    /// 位置 (可选)
    public var position: ?CssLengthPercentage

    public init(color: CssColor) {
        this.color = color
        this.position = None
    }

    public init(color: CssColor, position: CssLengthPercentage) {
        this.color = color
        this.position = Some(position)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ColorStop.toCss
    public func toCss(): String {
        match (position) {
            case Some(p) => "${color.toCss()} ${p.toCss()}"
            case None => color.toCss()
        }
    }

    /// 相等比较
    public func eql(other: CssColorStop): Bool {
        if (!color.eql(other.color)) {
            return false
        }
        match (position) {
            case None => match (other.position) {
                case None => true
                case Some(_) => false
            }
            case Some(p) => match (other.position) {
                case None => false
                case Some(op) => p.eql(op)
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssColorStop {
        match (position) {
            case Some(p) => CssColorStop(color.deepClone(), p.deepClone())
            case None => CssColorStop(color.deepClone())
        }
    }

    /// 获取颜色后备
    public func getFallback(kind: CssColorFallbackKind): CssColorStop {
        match (position) {
            case Some(p) => CssColorStop(color.getFallback(kind), p.deepClone())
            case None => CssColorStop(color.getFallback(kind))
        }
    }

    /// 获取必要的颜色后备类型
    public func getNecessaryFallbacks(targets: Targets): CssColorFallbackKind {
        color.getNecessaryFallbacks(targets)
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// GradientItem - 渐变项 (颜色停止点或插值提示)
// 严格翻译自 GradientItem(D) union(enum)
// ============================================================================

/// CSS 渐变项
/// 严格翻译自 GradientItem(D) union(enum) { color_stop, hint }
public class CssGradientItem {
    public enum CssGradientItemKind {
        | ColorStop   // 颜色停止点
        | Hint        // 插值提示
    }

    public var kind: CssGradientItemKind
    /// 颜色停止点 (kind == ColorStop)
    public var colorStop: CssColorStop
    /// 插值提示值 (kind == Hint)
    public var hint: ?CssLengthPercentage

    public init(colorStop: CssColorStop) {
        this.kind = CssGradientItemKind.ColorStop
        this.colorStop = colorStop
        this.hint = None
    }

    public init(hint: CssLengthPercentage) {
        this.kind = CssGradientItemKind.Hint
        this.colorStop = CssColorStop(CssColor.defaultColor())
        this.hint = Some(hint)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 GradientItem.toCss
    public func toCss(): String {
        match (kind) {
            case ColorStop => colorStop.toCss()
            case Hint => {
                match (hint) {
                    case Some(h) => h.toCss()
                    case None => ""
                }
            }
        }
    }

    /// 是否为无用的提示 (50% 的插值提示可省略)
    /// 严格翻译自 serializeItems 中的跳过逻辑
    public func isUselessHint(): Bool {
        match (kind) {
            case Hint => {
                match (hint) {
                    case Some(h) => {
                        h.kind == CssLengthPercentageKind.Percentage &&
                            match (h.percentage) {
                                case Some(p) => p.value == 0.5
                                case None => false
                            }
                    }
                    case None => true
                }
            }
            case _ => false
        }
    }

    /// 相等比较
    public func eql(other: CssGradientItem): Bool {
        if (kind != other.kind) {
            return false
        }
        match (kind) {
            case ColorStop => colorStop.eql(other.colorStop)
            case Hint => {
                match (hint) {
                    case Some(h) => {
                        match (other.hint) {
                            case Some(oh) => h.eql(oh)
                            case None => false
                        }
                    }
                    case None => match (other.hint) {
                        case None => true
                        case Some(_) => false
                    }
                }
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssGradientItem {
        match (kind) {
            case ColorStop => CssGradientItem(colorStop.deepClone())
            case Hint => {
                match (hint) {
                    case Some(h) => CssGradientItem(h.deepClone())
                    case None => CssGradientItem(CssLengthPercentage.zero())
                }
            }
        }
    }

    /// 获取颜色后备
    /// 严格翻译自 GradientItem.getFallback
    public func getFallback(kind: CssColorFallbackKind): CssGradientItem {
        match (this.kind) {
            case ColorStop => CssGradientItem(colorStop.getFallback(kind))
            case Hint => deepClone()
        }
    }

    /// 获取必要的颜色后备类型
    /// 严格翻译自 GradientItem.getNecessaryFallbacks
    public func getNecessaryFallbacks(targets: Targets): CssColorFallbackKind {
        match (kind) {
            case ColorStop => colorStop.getNecessaryFallbacks(targets)
            case Hint => CssColorFallbackKind()
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// Ellipse - 椭圆结束形状
// 严格翻译自 Ellipse union(enum)
// ============================================================================

/// CSS 椭圆结束形状
/// 严格翻译自 Ellipse union(enum) { size, extent }
public class CssEllipse {
    public enum CssEllipseKind {
        | Size    // 指定 x/y 半径
        | Extent  // 形状范围关键字
    }

    public var kind: CssEllipseKind
    /// 指定半径 (kind == Size)
    public var xRadius: CssLengthPercentage
    public var yRadius: CssLengthPercentage
    /// 形状范围关键字 (kind == Extent)
    public var extent: CssShapeExtent

    public init(xRadius: CssLengthPercentage, yRadius: CssLengthPercentage) {
        this.kind = CssEllipseKind.Size
        this.xRadius = xRadius
        this.yRadius = yRadius
        this.extent = CssShapeExtent.FarthestCorner
    }

    public init(extent: CssShapeExtent) {
        this.kind = CssEllipseKind.Extent
        this.xRadius = CssLengthPercentage.zero()
        this.yRadius = CssLengthPercentage.zero()
        this.extent = extent
    }

    /// 默认椭圆 (farthest-corner)
    /// 严格翻译自 EndingShape.default
    public static func defaultEllipse(): CssEllipse {
        CssEllipse(CssShapeExtent.FarthestCorner)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Ellipse.toCss (不输出 ellipse 关键字)
    public func toCss(): String {
        match (kind) {
            case Size => "${xRadius.toCss()} ${yRadius.toCss()}"
            case Extent => extent.toCss()
        }
    }

    /// 相等比较
    public func eql(other: CssEllipse): Bool {
        if (kind != other.kind) {
            return false
        }
        match (kind) {
            case Size => xRadius.eql(other.xRadius) && yRadius.eql(other.yRadius)
            case Extent => extent == other.extent
        }
    }

    /// 深拷贝
    public func deepClone(): CssEllipse {
        match (kind) {
            case Size => CssEllipse(xRadius.deepClone(), yRadius.deepClone())
            case Extent => CssEllipse(extent)
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// Circle - 圆形结束形状
// 严格翻译自 Circle union(enum)
// ============================================================================

/// CSS 圆形结束形状
/// 严格翻译自 Circle union(enum) { radius, extent }
public class CssCircle {
    public enum CssCircleKind {
        | Radius   // 指定半径
        | Extent   // 形状范围关键字
    }

    public var kind: CssCircleKind
    /// 指定半径 (kind == Radius)
    public var radius: CssLengthValue
    /// 形状范围关键字 (kind == Extent)
    public var extent: CssShapeExtent

    public init(radius: CssLengthValue) {
        this.kind = CssCircleKind.Radius
        this.radius = radius
        this.extent = CssShapeExtent.FarthestCorner
    }

    public init(extent: CssShapeExtent) {
        this.kind = CssCircleKind.Extent
        this.radius = CssLengthValue.zero()
        this.extent = extent
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Circle.toCss
    public func toCss(): String {
        match (kind) {
            case Radius => radius.toCss()
            case Extent => {
                if (extent == CssShapeExtent.FarthestCorner) {
                    "circle"
                } else {
                    "circle ${extent.toCss()}"
                }
            }
        }
    }

    /// 相等比较
    public func eql(other: CssCircle): Bool {
        if (kind != other.kind) {
            return false
        }
        match (kind) {
            case Radius => radius.eql(other.radius)
            case Extent => extent == other.extent
        }
    }

    /// 深拷贝
    public func deepClone(): CssCircle {
        match (kind) {
            case Radius => CssCircle(radius.deepClone())
            case Extent => CssCircle(extent)
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// EndingShape - 径向渐变结束形状
// 严格翻译自 EndingShape union(enum)
// ============================================================================

/// CSS 径向渐变结束形状
/// 严格翻译自 EndingShape union(enum) { ellipse, circle }
public class CssEndingShape {
    public enum CssEndingShapeKind {
        | Ellipse  // 椭圆
        | Circle   // 圆
    }

    public var kind: CssEndingShapeKind
    public var ellipse: CssEllipse
    public var circle: CssCircle

    public init(ellipse: CssEllipse) {
        this.kind = CssEndingShapeKind.Ellipse
        this.ellipse = ellipse
        this.circle = CssCircle(CssShapeExtent.FarthestCorner)
    }

    public init(circle: CssCircle) {
        this.kind = CssEndingShapeKind.Circle
        this.ellipse = CssEllipse.defaultEllipse()
        this.circle = circle
    }

    /// 默认形状 (椭圆 farthest-corner)
    /// 严格翻译自 EndingShape.default
    public static func default(): CssEndingShape {
        CssEndingShape(CssEllipse.defaultEllipse())
    }

    /// 是否为默认形状
    public func isDefault(): Bool {
        match (kind) {
            case Ellipse => ellipse.kind == CssEllipseKind.Extent &&
                ellipse.extent == CssShapeExtent.FarthestCorner
            case Circle => false
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Ellipse => ellipse.toCss()
            case Circle => circle.toCss()
        }
    }

    /// 相等比较
    public func eql(other: CssEndingShape): Bool {
        if (kind != other.kind) {
            return false
        }
        match (kind) {
            case Ellipse => ellipse.eql(other.ellipse)
            case Circle => circle.eql(other.circle)
        }
    }

    /// 深拷贝
    public func deepClone(): CssEndingShape {
        match (kind) {
            case Ellipse => CssEndingShape(ellipse.deepClone())
            case Circle => CssEndingShape(circle.deepClone())
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// WebKitGradientPointComponent - WebKit 渐变点分量
// 严格翻译自 WebKitGradientPointComponent(S) union(enum)
// ============================================================================

/// WebKit 渐变点分量
/// 严格翻译自 WebKitGradientPointComponent(S) union(enum) { center, number, side }
public class CssWebKitGradientPointComponent {
    public enum CssWebkitPointComponentKind {
        | Center  // center 关键字
        | Number  // 数字或百分比
        | Side    // 侧边关键字
    }

    public var kind: CssWebkitPointComponentKind
    /// 数字或百分比 (kind == Number)
    public var number: CssNumberOrPercentage
    /// 侧边关键字 (kind == Side): "left", "right", "top", "bottom"
    public var side: String

    public init() {
        this.kind = CssWebkitPointComponentKind.Center
        this.number = CssNumberOrPercentage.fromNumber(0.0)
        this.side = ""
    }

    public init(number: CssNumberOrPercentage) {
        this.kind = CssWebkitPointComponentKind.Number
        this.number = number
        this.side = ""
    }

    public init(side: String) {
        this.kind = CssWebkitPointComponentKind.Side
        this.number = CssNumberOrPercentage.fromNumber(0.0)
        this.side = side
    }

    public static func center(): CssWebKitGradientPointComponent {
        CssWebKitGradientPointComponent()
    }

    /// 转为 CSS 文本
    /// 严格翻译自 WebKitGradientPointComponent.toCss
    public func toCss(): String {
        match (kind) {
            case Center => "center"
            case Number => number.toCss()
            case Side => side
        }
    }

    /// 相等比较
    public func eql(other: CssWebKitGradientPointComponent): Bool {
        if (kind != other.kind) {
            return false
        }
        match (kind) {
            case Center => true
            case Number => number.eql(other.number)
            case Side => side == other.side
        }
    }

    /// 深拷贝
    public func deepClone(): CssWebKitGradientPointComponent {
        match (kind) {
            case Center => CssWebKitGradientPointComponent()
            case Number => CssWebKitGradientPointComponent(number.deepClone())
            case Side => CssWebKitGradientPointComponent(side)
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// WebKitGradientPoint - WebKit 渐变点
// 严格翻译自 WebKitGradientPoint struct
// ============================================================================

/// WebKit 渐变点 (x, y)
/// 严格翻译自 WebKitGradientPoint struct { x, y }
public class CssWebKitGradientPoint {
    public var x: CssWebKitGradientPointComponent
    public var y: CssWebKitGradientPointComponent

    public init(x: CssWebKitGradientPointComponent, y: CssWebKitGradientPointComponent) {
        this.x = x
        this.y = y
    }

    public init() {
        this.x = CssWebKitGradientPointComponent()
        this.y = CssWebKitGradientPointComponent()
    }

    /// 转为 CSS 文本
    /// 严格翻译自 WebKitGradientPoint.toCss
    public func toCss(): String {
        "${x.toCss()} ${y.toCss()}"
    }

    /// 相等比较
    public func eql(other: CssWebKitGradientPoint): Bool {
        x.eql(other.x) && y.eql(other.y)
    }

    /// 深拷贝
    public func deepClone(): CssWebKitGradientPoint {
        CssWebKitGradientPoint(x.deepClone(), y.deepClone())
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// WebKitColorStop - WebKit 颜色停止点
// 严格翻译自 WebKitColorStop struct
// ============================================================================

/// WebKit 颜色停止点
/// 严格翻译自 WebKitColorStop struct { color, position }
public class CssWebKitColorStop {
    /// 颜色
    public var color: CssColor
    /// 位置 (0.0-1.0)
    public var position: Float64

    public init(color: CssColor, position: Float64) {
        this.color = color
        this.position = position
    }

    /// 转为 CSS 文本
    /// 严格翻译自 WebKitColorStop.toCss
    public func toCss(): String {
        if (position == 0.0) {
            "from(${color.toCss()})"
        } else if (position == 1.0) {
            "to(${color.toCss()})"
        } else {
            "color-stop(${position}, ${color.toCss()})"
        }
    }

    /// 获取颜色后备
    public func getFallback(kind: CssColorFallbackKind): CssWebKitColorStop {
        CssWebKitColorStop(color.getFallback(kind), position)
    }

    /// 相等比较
    public func eql(other: CssWebKitColorStop): Bool {
        color.eql(other.color) && position == other.position
    }

    /// 深拷贝
    public func deepClone(): CssWebKitColorStop {
        CssWebKitColorStop(color.deepClone(), position)
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// CssNumberOrPercentage - 数字或百分比
// ============================================================================

/// CSS 数字或百分比
/// 严格翻译自 NumberOrPercentage union(enum)
public class CssNumberOrPercentage {
    public enum CssNumOrPercKind {
        | Number
        | Percentage
    }

    public var kind: CssNumOrPercKind
    public var value: Float64

    public init(kind: CssNumOrPercKind, value: Float64) {
        this.kind = kind
        this.value = value
    }

    public static func fromNumber(v: Float64): CssNumberOrPercentage {
        CssNumberOrPercentage(CssNumOrPercKind.Number, v)
    }

    public static func fromPercentage(v: Float64): CssNumberOrPercentage {
        CssNumberOrPercentage(CssNumOrPercKind.Percentage, v)
    }

    /// 转为 f32
    public func toFloat(): Float64 {
        match (kind) {
            case Number => value
            case Percentage => value
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Number => "${value}"
            case Percentage => "${value * 100.0}%"
        }
    }

    /// 相等比较
    public func eql(other: CssNumberOrPercentage): Bool {
        kind == other.kind && value == other.value
    }

    /// 深拷贝
    public func deepClone(): CssNumberOrPercentage {
        CssNumberOrPercentage(kind, value)
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// LinearGradient - 线性渐变
// 严格翻译自 LinearGradient struct
// ============================================================================

/// CSS 线性渐变
/// 严格翻译自 LinearGradient struct { vendor_prefix, direction, items }
public class CssLinearGradient {
    /// 供应商前缀
    public var vendorPrefix: VendorPrefix
    /// 方向
    public var direction: CssLineDirection
    /// 渐变项列表
    public var items: ArrayList<CssGradientItem>

    public init(direction: CssLineDirection, items: ArrayList<CssGradientItem>) {
        this.direction = direction
        this.items = items
        this.vendorPrefix = VendorPrefix()
    }

    public init(direction: CssLineDirection, items: ArrayList<CssGradientItem>, vendorPrefix: VendorPrefix) {
        this.direction = direction
        this.items = items
        this.vendorPrefix = vendorPrefix
    }

    /// 转为 CSS 文本
    /// 严格翻译自 LinearGradient.toCss
    public func toCss(funcName: String): String {
        let sb = StringBuilder()

        // 前缀
        let prefixStr = vendorPrefix.toString()
        if (prefixStr.length > 0) {
            sb.append(prefixStr)
        }

        sb.append("${funcName}(")

        // 如果方向是默认方向 (to bottom / 180deg) 则省略
        let angle = direction.toDegrees()
        if (angle != 180.0) {
            // 如果不是默认方向, 输出方向
            let isPrefixed = vendorPrefix.toString().length > 0
            sb.append(direction.toCss(isPrefixed))
            sb.append(", ")
        }

        // 序列化渐变项
        let itemsStr = serializeItems()
        if (angle == 180.0 && itemsStr.length > 0) {
            sb.append(itemsStr)
        } else if (angle != 180.0 && itemsStr.length > 0) {
            sb.append(itemsStr)
        }

        sb.append(")")
        return sb.toString()
    }

    /// 序列化渐变项列表
    /// 严格翻译自 serializeItems 函数
    public func serializeItems(): String {
        let sb = StringBuilder()
        var first = true

        for (item in items) {
            // 跳过无用的提示 (50% 的插值提示)
            if (item.isUselessHint()) {
                continue
            }

            if (first) {
                first = false
            } else {
                sb.append(", ")
            }
            sb.append(item.toCss())
        }
        return sb.toString()
    }

    /// 相等比较
    public func eql(other: CssLinearGradient): Bool {
        if (!vendorPrefix.eql(other.vendorPrefix)) {
            return false
        }
        if (!direction.eql(other.direction)) {
            return false
        }
        if (items.size != other.items.size) {
            return false
        }
        var i = 0
        for (item in items) {
            if (!item.eql(other.items.get(i))) {
                return false
            }
            i++
        }
        return true
    }

    /// 深拷贝
    public func deepClone(): CssLinearGradient {
        let clonedItems = ArrayList<CssGradientItem>()
        for (item in items) {
            clonedItems.append(item.deepClone())
        }
        CssLinearGradient(direction.deepClone(), clonedItems, vendorPrefix.deepClone())
    }

    /// 获取颜色后备
    /// 严格翻译自 LinearGradient.getFallback
    public func getFallback(kind: CssColorFallbackKind): CssLinearGradient {
        let fallbackItems = ArrayList<CssGradientItem>()
        for (item in items) {
            fallbackItems.append(item.getFallback(kind))
        }
        CssLinearGradient(direction.deepClone(), fallbackItems, vendorPrefix.deepClone())
    }

    public func toString(): String {
        toCss("linear-gradient")
    }
}

// ============================================================================
// RadialGradient - 径向渐变
// 严格翻译自 RadialGradient struct
// ============================================================================

/// CSS 径向渐变
/// 严格翻译自 RadialGradient struct { vendor_prefix, shape, position, items }
public class CssRadialGradient {
    /// 供应商前缀
    public var vendorPrefix: VendorPrefix
    /// 形状
    public var shape: CssEndingShape
    /// 位置
    public var position: CssPosition
    /// 渐变项列表
    public var items: ArrayList<CssGradientItem>

    public init(shape: CssEndingShape, position: CssPosition, items: ArrayList<CssGradientItem>) {
        this.shape = shape
        this.position = position
        this.items = items
        this.vendorPrefix = VendorPrefix()
    }

    public init(shape: CssEndingShape, position: CssPosition, items: ArrayList<CssGradientItem>, vendorPrefix: VendorPrefix) {
        this.shape = shape
        this.position = position
        this.items = items
        this.vendorPrefix = vendorPrefix
    }

    /// 转为 CSS 文本
    /// 严格翻译自 RadialGradient.toCss
    public func toCss(funcName: String): String {
        let sb = StringBuilder()

        // 前缀
        let prefixStr = vendorPrefix.toString()
        if (prefixStr.length > 0) {
            sb.append(prefixStr)
        }

        sb.append("${funcName}(")

        // 输出形状 (如果不是默认)
        if (!shape.isDefault()) {
            sb.append(shape.toCss())
            if (position.isCenter()) {
                sb.append(", ")
            } else {
                sb.append(" ")
            }
        }

        // 输出位置 (如果不是中心)
        if (!position.isCenter()) {
            sb.append("at ")
            sb.append(position.toCss())
            sb.append(", ")
        }

        // 序列化渐变项
        let itemsStr = serializeItems()
        sb.append(itemsStr)

        sb.append(")")
        return sb.toString()
    }

    /// 序列化渐变项列表
    public func serializeItems(): String {
        let sb = StringBuilder()
        var first = true

        for (item in items) {
            if (item.isUselessHint()) {
                continue
            }
            if (first) {
                first = false
            } else {
                sb.append(", ")
            }
            sb.append(item.toCss())
        }
        return sb.toString()
    }

    /// 相等比较
    public func eql(other: CssRadialGradient): Bool {
        if (!vendorPrefix.eql(other.vendorPrefix)) {
            return false
        }
        if (!shape.eql(other.shape)) {
            return false
        }
        if (!position.eql(other.position)) {
            return false
        }
        if (items.size != other.items.size) {
            return false
        }
        var i = 0
        for (item in items) {
            if (!item.eql(other.items.get(i))) {
                return false
            }
            i++
        }
        return true
    }

    /// 深拷贝
    public func deepClone(): CssRadialGradient {
        let clonedItems = ArrayList<CssGradientItem>()
        for (item in items) {
            clonedItems.append(item.deepClone())
        }
        CssRadialGradient(shape.deepClone(), position.deepClone(), clonedItems, vendorPrefix.deepClone())
    }

    /// 获取颜色后备
    /// 严格翻译自 RadialGradient.getFallback
    public func getFallback(kind: CssColorFallbackKind): CssRadialGradient {
        let fallbackItems = ArrayList<CssGradientItem>()
        for (item in items) {
            fallbackItems.append(item.getFallback(kind))
        }
        CssRadialGradient(shape.deepClone(), position.deepClone(), fallbackItems, vendorPrefix.deepClone())
    }

    public func toString(): String {
        toCss("radial-gradient")
    }
}

// ============================================================================
// ConicGradient - conic 渐变
// 严格翻译自 ConicGradient struct
// ============================================================================

/// CSS conic 渐变
/// 严格翻译自 ConicGradient struct { angle, position, items }
public class CssConicGradient {
    /// 起始角度
    public var angle: CssAngle
    /// 位置
    public var position: CssPosition
    /// 渐变项列表
    public var items: ArrayList<CssGradientItem>

    public init(angle: CssAngle, position: CssPosition, items: ArrayList<CssGradientItem>) {
        this.angle = angle
        this.position = position
        this.items = items
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ConicGradient.toCss
    public func toCss(funcName: String): String {
        let sb = StringBuilder()
        sb.append("${funcName}(")

        // 输出 from-angle (如果不是零)
        if (!angle.isZero()) {
            sb.append("from ")
            sb.append(angle.toCss())
            if (position.isCenter()) {
                sb.append(", ")
            } else {
                sb.append(" ")
            }
        }

        // 输出位置 (如果不是中心)
        if (!position.isCenter()) {
            sb.append("at ")
            sb.append(position.toCss())
            sb.append(", ")
        }

        // 序列化渐变项
        var first = true
        for (item in items) {
            if (item.isUselessHint()) {
                continue
            }
            if (first) {
                first = false
            } else {
                sb.append(", ")
            }
            sb.append(item.toCss())
        }

        sb.append(")")
        return sb.toString()
    }

    /// 相等比较
    public func eql(other: CssConicGradient): Bool {
        if (!angle.eql(other.angle)) {
            return false
        }
        if (!position.eql(other.position)) {
            return false
        }
        if (items.size != other.items.size) {
            return false
        }
        var i = 0
        for (item in items) {
            if (!item.eql(other.items.get(i))) {
                return false
            }
            i++
        }
        return true
    }

    /// 深拷贝
    public func deepClone(): CssConicGradient {
        let clonedItems = ArrayList<CssGradientItem>()
        for (item in items) {
            clonedItems.append(item.deepClone())
        }
        CssConicGradient(angle.deepClone(), position.deepClone(), clonedItems)
    }

    /// 获取颜色后备
    /// 严格翻译自 ConicGradient.getFallback
    public func getFallback(kind: CssColorFallbackKind): CssConicGradient {
        let fallbackItems = ArrayList<CssGradientItem>()
        for (item in items) {
            fallbackItems.append(item.getFallback(kind))
        }
        CssConicGradient(angle.deepClone(), position.deepClone(), fallbackItems)
    }

    public func toString(): String {
        toCss("conic-gradient")
    }
}

// ============================================================================
// WebKitGradient - 旧式 -webkit-gradient
// 严格翻译自 WebKitGradient union(enum)
// ============================================================================

/// 旧式 -webkit-gradient
/// 严格翻译自 WebKitGradient union(enum) { linear, radial }
public class CssWebKitGradient {
    public enum CssWebkitGradientKind {
        | Linear   // 线性
        | Radial   // 径向
    }

    public var kind: CssWebkitGradientKind
    /// 线性渐变
    public var linearFrom: CssWebKitGradientPoint
    public var linearTo: CssWebKitGradientPoint
    public var linearStops: ArrayList<CssWebKitColorStop>
    /// 径向渐变
    public var radialFrom: CssWebKitGradientPoint
    public var radialTo: CssWebKitGradientPoint
    public var radialR0: Float64
    public var radialR1: Float64
    public var radialStops: ArrayList<CssWebKitColorStop>

    /// 线性 WebKit 渐变
    public init(from: CssWebKitGradientPoint, to: CssWebKitGradientPoint, stops: ArrayList<CssWebKitColorStop>) {
        this.kind = CssWebkitGradientKind.Linear
        this.linearFrom = from
        this.linearTo = to
        this.linearStops = stops
        this.radialFrom = CssWebKitGradientPoint()
        this.radialTo = CssWebKitGradientPoint()
        this.radialR0 = 0.0
        this.radialR1 = 0.0
        this.radialStops = ArrayList<CssWebKitColorStop>()
    }

    /// 径向 WebKit 渐变
    public init(from: CssWebKitGradientPoint, r0: Float64, to: CssWebKitGradientPoint, r1: Float64, stops: ArrayList<CssWebKitColorStop>) {
        this.kind = CssWebkitGradientKind.Radial
        this.linearFrom = CssWebKitGradientPoint()
        this.linearTo = CssWebKitGradientPoint()
        this.linearStops = ArrayList<CssWebKitColorStop>()
        this.radialFrom = from
        this.radialTo = to
        this.radialR0 = r0
        this.radialR1 = r1
        this.radialStops = stops
    }

    /// 转为 CSS 文本
    /// 严格翻译自 WebKitGradient.toCss
    public func toCss(): String {
        let sb = StringBuilder()
        sb.append("-webkit-gradient(")

        match (kind) {
            case Linear => {
                sb.append("linear, ")
                sb.append(linearFrom.toCss())
                sb.append(", ")
                sb.append(linearTo.toCss())
                for (stop in linearStops) {
                    sb.append(", ")
                    sb.append(stop.toCss())
                }
            }
            case Radial => {
                sb.append("radial, ")
                sb.append(radialFrom.toCss())
                sb.append(", ")
                sb.append("${radialR0}")
                sb.append(", ")
                sb.append(radialTo.toCss())
                sb.append(", ")
                sb.append("${radialR1}")
                for (stop in radialStops) {
                    sb.append(", ")
                    sb.append(stop.toCss())
                }
            }
        }

        sb.append(")")
        return sb.toString()
    }

    /// 获取颜色后备
    /// 严格翻译自 WebKitGradient.getFallback
    public func getFallback(kind: CssColorFallbackKind): CssWebKitGradient {
        match (this.kind) {
            case Linear => {
                let stops = ArrayList<CssWebKitColorStop>()
                for (stop in linearStops) {
                    stops.append(stop.getFallback(kind))
                }
                CssWebKitGradient(linearFrom.deepClone(), linearTo.deepClone(), stops)
            }
            case Radial => {
                let stops = ArrayList<CssWebKitColorStop>()
                for (stop in radialStops) {
                    stops.append(stop.getFallback(kind))
                }
                CssWebKitGradient(radialFrom.deepClone(), radialR0, radialTo.deepClone(), radialR1, stops)
            }
        }
    }

    /// 相等比较
    public func eql(other: CssWebKitGradient): Bool {
        if (kind != other.kind) {
            return false
        }
        match (kind) {
            case Linear => {
                if (!linearFrom.eql(other.linearFrom)) { return false }
                if (!linearTo.eql(other.linearTo)) { return false }
                if (linearStops.size != other.linearStops.size) { return false }
                var i = 0
                for (stop in linearStops) {
                    if (!stop.eql(other.linearStops.get(i))) { return false }
                    i++
                }
                return true
            }
            case Radial => {
                if (!radialFrom.eql(other.radialFrom)) { return false }
                if (!radialTo.eql(other.radialTo)) { return false }
                if (radialR0 != other.radialR0) { return false }
                if (radialR1 != other.radialR1) { return false }
                if (radialStops.size != other.radialStops.size) { return false }
                var i = 0
                for (stop in radialStops) {
                    if (!stop.eql(other.radialStops.get(i))) { return false }
                    i++
                }
                return true
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssWebKitGradient {
        match (kind) {
            case Linear => {
                let stops = ArrayList<CssWebKitColorStop>()
                for (stop in linearStops) {
                    stops.append(stop.deepClone())
                }
                CssWebKitGradient(linearFrom.deepClone(), linearTo.deepClone(), stops)
            }
            case Radial => {
                let stops = ArrayList<CssWebKitColorStop>()
                for (stop in radialStops) {
                    stops.append(stop.deepClone())
                }
                CssWebKitGradient(radialFrom.deepClone(), radialR0, radialTo.deepClone(), radialR1, stops)
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// Gradient - CSS <gradient> 值
// 严格翻译自 Gradient union(enum)
// ============================================================================

/// CSS <gradient>
/// 严格翻译自 Gradient union(enum) { Linear, RepeatingLinear, Radial, RepeatingRadial, Conic, RepeatingConic, WebkitGradient }
public class CssGradient {
    public enum CssGradientKind {
        | Linear           // linear-gradient
        | RepeatingLinear  // repeating-linear-gradient
        | Radial           // radial-gradient
        | RepeatingRadial  // repeating-radial-gradient
        | Conic            // conic-gradient
        | RepeatingConic   // repeating-conic-gradient
        | WebkitGradient   // -webkit-gradient
    }

    public var kind: CssGradientKind
    /// 线性渐变 (kind == Linear / RepeatingLinear)
    public var linear: ?CssLinearGradient
    /// 径向渐变 (kind == Radial / RepeatingRadial)
    public var radial: ?CssRadialGradient
    /// conic 渐变 (kind == Conic / RepeatingConic)
    public var conic: ?CssConicGradient
    /// webkit 渐变 (kind == WebkitGradient)
    public var webkitGradient: ?CssWebKitGradient

    public init(linear: CssLinearGradient, kind: CssGradientKind) {
        this.kind = kind
        this.linear = Some(linear)
        this.radial = None
        this.conic = None
        this.webkitGradient = None
    }

    public init(radial: CssRadialGradient, kind: CssGradientKind) {
        this.kind = kind
        this.linear = None
        this.radial = Some(radial)
        this.conic = None
        this.webkitGradient = None
    }

    public init(conic: CssConicGradient, kind: CssGradientKind) {
        this.kind = kind
        this.linear = None
        this.radial = None
        this.conic = Some(conic)
        this.webkitGradient = None
    }

    public init(webkitGradient: CssWebKitGradient) {
        this.kind = CssGradientKind.WebkitGradient
        this.linear = None
        this.radial = None
        this.conic = None
        this.webkitGradient = Some(webkitGradient)
    }

    /// 获取渐变函数名
    /// 严格翻译自 Gradient.toCss 中的函数名提取
    public func funcName(): String {
        match (kind) {
            case Linear => "linear-gradient"
            case RepeatingLinear => "repeating-linear-gradient"
            case Radial => "radial-gradient"
            case RepeatingRadial => "repeating-radial-gradient"
            case Conic => "conic-gradient"
            case RepeatingConic => "repeating-conic-gradient"
            case WebkitGradient => "-webkit-gradient"
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Gradient.toCss
    public func toCss(): String {
        match (kind) {
            case Linear => {
                match (linear) {
                    case Some(g) => g.toCss("linear-gradient")
                    case None => ""
                }
            }
            case RepeatingLinear => {
                match (linear) {
                    case Some(g) => g.toCss("repeating-linear-gradient")
                    case None => ""
                }
            }
            case Radial => {
                match (radial) {
                    case Some(g) => g.toCss("radial-gradient")
                    case None => ""
                }
            }
            case RepeatingRadial => {
                match (radial) {
                    case Some(g) => g.toCss("repeating-radial-gradient")
                    case None => ""
                }
            }
            case Conic => {
                match (conic) {
                    case Some(g) => g.toCss("conic-gradient")
                    case None => ""
                }
            }
            case RepeatingConic => {
                match (conic) {
                    case Some(g) => g.toCss("repeating-conic-gradient")
                    case None => ""
                }
            }
            case WebkitGradient => {
                match (webkitGradient) {
                    case Some(g) => g.toCss()
                    case None => ""
                }
            }
        }
    }

    /// 尝试转换为旧式 -webkit-gradient
    /// 严格翻译自 Gradient.getLegacyWebkit
    public func getLegacyWebkit(): ?CssGradient {
        match (kind) {
            case Linear => {
                match (linear) {
                    case Some(lg) => {
                        let webkit = CssGradientHelper.fromStandardToWebkit(this)
                        match (webkit) {
                            case Some(wk) => Some(CssGradient(wk))
                            case None => None
                        }
                    }
                    case None => None
                }
            }
            case Radial => {
                match (radial) {
                    case Some(rg) => {
                        let webkit = CssGradientHelper.fromStandardToWebkit(this)
                        match (webkit) {
                            case Some(wk) => Some(CssGradient(wk))
                            case None => None
                        }
                    }
                    case None => None
                }
            }
            case _ => None
        }
    }

    /// 获取供应商前缀
    /// 严格翻译自 Gradient.getVendorPrefix
    public func getVendorPrefix(): VendorPrefix {
        match (kind) {
            case Linear => {
                match (linear) {
                    case Some(g) => g.vendorPrefix
                    case None => VendorPrefix()
                }
            }
            case RepeatingLinear => {
                match (linear) {
                    case Some(g) => g.vendorPrefix
                    case None => VendorPrefix()
                }
            }
            case Radial => {
                match (radial) {
                    case Some(g) => g.vendorPrefix
                    case None => VendorPrefix()
                }
            }
            case RepeatingRadial => {
                match (radial) {
                    case Some(g) => g.vendorPrefix
                    case None => VendorPrefix()
                }
            }
            case WebkitGradient => VendorPrefix.webkitPrefix()
            case _ => VendorPrefix()
        }
    }

    /// 获取给定浏览器目标所需的供应商前缀
    /// 严格翻译自 Gradient.getNecessaryPrefixes
    public func getNecessaryPrefixes(targets: Targets): VendorPrefix {
        // 简化版本: 根据渐变类型返回相应前缀
        let prefix = getVendorPrefix()
        match (kind) {
            case Linear => targets.prefixes(prefix, Feature.None)
            case RepeatingLinear => targets.prefixes(prefix, Feature.None)
            case Radial => targets.prefixes(prefix, Feature.None)
            case RepeatingRadial => targets.prefixes(prefix, Feature.None)
            case _ => VendorPrefix()
        }
    }

    /// 返回带有给定前缀的渐变副本
    /// 严格翻译自 Gradient.getPrefixed
    public func getPrefixed(prefix: VendorPrefix): CssGradient {
        match (kind) {
            case Linear => {
                match (linear) {
                    case Some(g) => {
                        let cloned = g.deepClone()
                        cloned.vendorPrefix = prefix
                        CssGradient(cloned, kind)
                    }
                    case None => deepClone()
                }
            }
            case RepeatingLinear => {
                match (linear) {
                    case Some(g) => {
                        let cloned = g.deepClone()
                        cloned.vendorPrefix = prefix
                        CssGradient(cloned, kind)
                    }
                    case None => deepClone()
                }
            }
            case Radial => {
                match (radial) {
                    case Some(g) => {
                        let cloned = g.deepClone()
                        cloned.vendorPrefix = prefix
                        CssGradient(cloned, kind)
                    }
                    case None => deepClone()
                }
            }
            case RepeatingRadial => {
                match (radial) {
                    case Some(g) => {
                        let cloned = g.deepClone()
                        cloned.vendorPrefix = prefix
                        CssGradient(cloned, kind)
                    }
                    case None => deepClone()
                }
            }
            case _ => deepClone()
        }
    }

    /// 获取颜色后备渐变
    /// 严格翻译自 Gradient.getFallback
    public func getFallback(kind: CssColorFallbackKind): CssGradient {
        match (this.kind) {
            case Linear => {
                match (linear) {
                    case Some(g) => CssGradient(g.getFallback(kind), this.kind)
                    case None => deepClone()
                }
            }
            case RepeatingLinear => {
                match (linear) {
                    case Some(g) => CssGradient(g.getFallback(kind), this.kind)
                    case None => deepClone()
                }
            }
            case Radial => {
                match (radial) {
                    case Some(g) => CssGradient(g.getFallback(kind), this.kind)
                    case None => deepClone()
                }
            }
            case RepeatingRadial => {
                match (radial) {
                    case Some(g) => CssGradient(g.getFallback(kind), this.kind)
                    case None => deepClone()
                }
            }
            case Conic => {
                match (conic) {
                    case Some(g) => CssGradient(g.getFallback(kind), this.kind)
                    case None => deepClone()
                }
            }
            case RepeatingConic => {
                match (conic) {
                    case Some(g) => CssGradient(g.getFallback(kind), this.kind)
                    case None => deepClone()
                }
            }
            case WebkitGradient => {
                match (webkitGradient) {
                    case Some(g) => CssGradient(g.getFallback(kind))
                    case None => deepClone()
                }
            }
        }
    }

    /// 获取给定浏览器目标所需的颜色后备类型
    /// 严格翻译自 Gradient.getNecessaryFallbacks
    public func getNecessaryFallbacks(targets: Targets): CssColorFallbackKind {
        let fallbacks = CssColorFallbackKind()
        match (kind) {
            case Linear | RepeatingLinear => {
                match (linear) {
                    case Some(g) => {
                        for (item in g.items) {
                            fallbacks.merge(item.getNecessaryFallbacks(targets))
                        }
                    }
                    case None => {}
                }
            }
            case Radial | RepeatingRadial => {
                match (radial) {
                    case Some(g) => {
                        for (item in g.items) {
                            fallbacks.merge(item.getNecessaryFallbacks(targets))
                        }
                    }
                    case None => {}
                }
            }
            case Conic | RepeatingConic => {
                match (conic) {
                    case Some(g) => {
                        for (item in g.items) {
                            fallbacks.merge(item.getNecessaryFallbacks(targets))
                        }
                    }
                    case None => {}
                }
            }
            case WebkitGradient => {} // webkit 不需要
        }
        return fallbacks
    }

    /// 相等比较
    /// 严格翻译自 Gradient.eql
    public func eql(other: CssGradient): Bool {
        if (kind != other.kind) {
            return false
        }
        match (kind) {
            case Linear | RepeatingLinear => {
                match (linear) {
                    case Some(g) => {
                        match (other.linear) {
                            case Some(og) => g.eql(og)
                            case None => false
                        }
                    }
                    case None => match (other.linear) {
                        case None => true
                        case Some(_) => false
                    }
                }
            }
            case Radial | RepeatingRadial => {
                match (radial) {
                    case Some(g) => {
                        match (other.radial) {
                            case Some(og) => g.eql(og)
                            case None => false
                        }
                    }
                    case None => match (other.radial) {
                        case None => true
                        case Some(_) => false
                    }
                }
            }
            case Conic | RepeatingConic => {
                match (conic) {
                    case Some(g) => {
                        match (other.conic) {
                            case Some(og) => g.eql(og)
                            case None => false
                        }
                    }
                    case None => match (other.conic) {
                        case None => true
                        case Some(_) => false
                    }
                }
            }
            case WebkitGradient => {
                match (webkitGradient) {
                    case Some(g) => {
                        match (other.webkitGradient) {
                            case Some(og) => g.eql(og)
                            case None => false
                        }
                    }
                    case None => match (other.webkitGradient) {
                        case None => true
                        case Some(_) => false
                    }
                }
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssGradient {
        match (kind) {
            case Linear | RepeatingLinear => {
                match (linear) {
                    case Some(g) => CssGradient(g.deepClone(), kind)
                    case None => CssGradient(CssLinearGradient(CssLineDirection(), ArrayList<CssGradientItem>()), kind)
                }
            }
            case Radial | RepeatingRadial => {
                match (radial) {
                    case Some(g) => CssGradient(g.deepClone(), kind)
                    case None => CssGradient(CssRadialGradient(CssEndingShape.default(), CssPosition.center(), ArrayList<CssGradientItem>()), kind)
                }
            }
            case Conic | RepeatingConic => {
                match (conic) {
                    case Some(g) => CssGradient(g.deepClone(), kind)
                    case None => CssGradient(CssConicGradient(CssAngle(0.0, CssAngleUnit.Deg), CssPosition.center(), ArrayList<CssGradientItem>()), kind)
                }
            }
            case WebkitGradient => {
                match (webkitGradient) {
                    case Some(g) => CssGradient(g.deepClone())
                    case None => CssGradient(CssWebKitGradient(CssWebKitGradientPoint(), CssWebKitGradientPoint(), ArrayList<CssWebKitColorStop>()))
                }
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// GradientHelper - 渐变辅助工具
// ============================================================================

/// 渐变辅助工具
/// 包含从标准渐变转换为 WebKit 渐变、解析等辅助方法
public class CssGradientHelper {

    /// 从标准渐变转换为旧式 -webkit-gradient
    /// 严格翻译自 WebKitGradient.fromStandard
    public static func fromStandardToWebkit(gradient: CssGradient): ?CssWebKitGradient {
        match (gradient.kind) {
            case CssGradientKind.Linear => {
                match (gradient.linear) {
                    case Some(linear) => {
                        // 从方向转换为起点/终点
                        let result = directionToWebkitPoints(linear.direction)
                        let fromPoint = result[0]
                        let toPoint = result[1]

                        match (convertStopsToWebkit(linear.items)) {
                            case Some(stops) => Some(CssWebKitGradient(fromPoint, toPoint, stops))
                            case None => None
                        }
                    }
                    case None => None
                }
            }
            case CssGradientKind.Radial => {
                match (gradient.radial) {
                    case Some(radial) => {
                        // WebKit 径向渐变只支持圆
                        match (radial.shape.kind) {
                            case CssEndingShapeKind.Circle => {
                                // 简化: 使用位置和半径
                                let point = positionToWebkitPoint(radial.position)
                                let radius: Float64 = match (radial.shape.circle.kind) {
                                    case CssCircleKind.Radius => radial.shape.circle.radius.toPx()
                                    case CssCircleKind.Extent => -1.0  // 无法直接转换
                                }
                                if (radius < 0.0) {
                                    return None
                                }
                                match (convertStopsToWebkit(radial.items)) {
                                    case Some(stops) => Some(CssWebKitGradient(point, 0.0, point.deepClone(), radius, stops))
                                    case None => None
                                }
                            }
                            case _ => None
                        }
                    }
                    case None => None
                }
            }
            case _ => None
        }
    }

    /// 将方向转换为 WebKit 起点终点
    private static func directionToWebkitPoints(direction: CssLineDirection): Array<CssWebKitGradientPoint> {
        let fromX: CssWebKitGradientPointComponent
        let fromY: CssWebKitGradientPointComponent
        let toX: CssWebKitGradientPointComponent
        let toY: CssWebKitGradientPointComponent

        match (direction.kind) {
            case CssLineDirectionKind.Horizontal => {
                match (direction.horizontal) {
                    case CssHorizontalPositionKeyword.Left => {
                        fromX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(1.0))
                        fromY = CssWebKitGradientPointComponent()
                        toX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(0.0))
                        toY = CssWebKitGradientPointComponent()
                    }
                    case CssHorizontalPositionKeyword.Right => {
                        fromX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(0.0))
                        fromY = CssWebKitGradientPointComponent()
                        toX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(1.0))
                        toY = CssWebKitGradientPointComponent()
                    }
                }
            }
            case CssLineDirectionKind.Vertical => {
                match (direction.vertical) {
                    case CssVerticalPositionKeyword.Top => {
                        fromX = CssWebKitGradientPointComponent()
                        fromY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(1.0))
                        toX = CssWebKitGradientPointComponent()
                        toY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(0.0))
                    }
                    case CssVerticalPositionKeyword.Bottom => {
                        fromX = CssWebKitGradientPointComponent()
                        fromY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(0.0))
                        toX = CssWebKitGradientPointComponent()
                        toY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(1.0))
                    }
                }
            }
            case CssLineDirectionKind.Corner => {
                let fxPct: Float64 = match (direction.horizontal) {
                    case CssHorizontalPositionKeyword.Left => 1.0
                    case CssHorizontalPositionKeyword.Right => 0.0
                }
                let fyPct: Float64 = match (direction.vertical) {
                    case CssVerticalPositionKeyword.Top => 1.0
                    case CssVerticalPositionKeyword.Bottom => 0.0
                }
                let txPct: Float64 = match (direction.horizontal) {
                    case CssHorizontalPositionKeyword.Left => 0.0
                    case CssHorizontalPositionKeyword.Right => 1.0
                }
                let tyPct: Float64 = match (direction.vertical) {
                    case CssVerticalPositionKeyword.Top => 0.0
                    case CssVerticalPositionKeyword.Bottom => 1.0
                }
                fromX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(fxPct))
                fromY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(fyPct))
                toX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(txPct))
                toY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(tyPct))
            }
            case CssLineDirectionKind.Angle => {
                let degrees = direction.angle.toDegrees()
                if (degrees == 0.0) {
                    fromX = CssWebKitGradientPointComponent()
                    fromY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(1.0))
                    toX = CssWebKitGradientPointComponent()
                    toY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(0.0))
                } else if (degrees == 90.0) {
                    fromX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(0.0))
                    fromY = CssWebKitGradientPointComponent()
                    toX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(1.0))
                    toY = CssWebKitGradientPointComponent()
                } else if (degrees == 180.0) {
                    fromX = CssWebKitGradientPointComponent()
                    fromY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(0.0))
                    toX = CssWebKitGradientPointComponent()
                    toY = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(1.0))
                } else if (degrees == 270.0) {
                    fromX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(1.0))
                    fromY = CssWebKitGradientPointComponent()
                    toX = CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(0.0))
                    toY = CssWebKitGradientPointComponent()
                } else {
                    // 默认: 无法精确转换
                    fromX = CssWebKitGradientPointComponent()
                    fromY = CssWebKitGradientPointComponent()
                    toX = CssWebKitGradientPointComponent()
                    toY = CssWebKitGradientPointComponent()
                }
            }
        }

        Array<CssWebKitGradientPoint>(2, {i =>
            if (i == 0) {
                CssWebKitGradientPoint(fromX, fromY)
            } else {
                CssWebKitGradientPoint(toX, toY)
            }
        })
    }

    /// 将位置转换为 WebKit 渐变点
    private static func positionToWebkitPoint(position: CssPosition): CssWebKitGradientPoint {
        let x = positionComponentToWebkit(position.x)
        let y = positionComponentToWebkit(position.y)
        CssWebKitGradientPoint(x, y)
    }

    /// 将位置分量转换为 WebKit 渐变点分量
    private static func positionComponentToWebkit(comp: CssPositionComponent): CssWebKitGradientPointComponent {
        match (comp.kind) {
            case CssPositionComponentKind.Center => CssWebKitGradientPointComponent()
            case CssPositionComponentKind.Length => {
                match (comp.length) {
                    case Some(lp) => {
                        match (lp.kind) {
                            case CssLengthPercentageKind.Percentage => {
                                match (lp.percentage) {
                                    case Some(p) => CssWebKitGradientPointComponent(CssNumberOrPercentage.fromPercentage(p.value))
                                    case None => CssWebKitGradientPointComponent()
                                }
                            }
                            case _ => CssWebKitGradientPointComponent() // 简化
                        }
                    }
                    case None => CssWebKitGradientPointComponent()
                }
            }
            case CssPositionComponentKind.Side => {
                CssWebKitGradientPointComponent(comp.sideKeyword)
            }
        }
    }

    /// 将渐变项转换为 WebKit 颜色停止点
    /// 严格翻译自 convertStopsToWebkit
    public static func convertStopsToWebkit(items: ArrayList<CssGradientItem>): ?ArrayList<CssWebKitColorStop> {
        let stops = ArrayList<CssWebKitColorStop>()
        var i = 0

        for (item in items) {
            match (item.kind) {
                case CssGradientItemKind.ColorStop => {
                    // 位置必须为百分比
                    let position: Float64 = match (item.colorStop.position) {
                        case Some(pos) => {
                            match (pos.kind) {
                                case CssLengthPercentageKind.Percentage => {
                                    match (pos.percentage) {
                                        case Some(p) => p.value
                                        case None => -1.0
                                    }
                                }
                                case _ => -1.0 // 非百分比无法转换
                            }
                        }
                        case None => {
                            // 第一项默认 0.0, 最后一项默认 1.0
                            if (i == 0) {
                                0.0
                            } else if (i == items.size - 1) {
                                1.0
                            } else {
                                -1.0
                            }
                        }
                    }

                    if (position < 0.0) {
                        return None
                    }

                    stops.append(CssWebKitColorStop(item.colorStop.color.deepClone(), position))
                }
                case CssGradientItemKind.Hint => {
                    return None // hints 不能转换为 WebKit 格式
                }
            }
            i++
        }

        return Some(stops)
    }

    /// 从函数名解析渐变类型
    /// 严格翻译自 Gradient.parse 中的函数名匹配
    public static func kindFromFuncName(funcName: String): ?CssGradientKind {
        let lower = funcName.toLowerCase()
        match (lower) {
            case "linear-gradient" => Some(CssGradientKind.Linear)
            case "repeating-linear-gradient" => Some(CssGradientKind.RepeatingLinear)
            case "radial-gradient" => Some(CssGradientKind.Radial)
            case "repeating-radial-gradient" => Some(CssGradientKind.RepeatingRadial)
            case "conic-gradient" => Some(CssGradientKind.Conic)
            case "repeating-conic-gradient" => Some(CssGradientKind.RepeatingConic)
            case "-webkit-linear-gradient" => Some(CssGradientKind.Linear)
            case "-webkit-repeating-linear-gradient" => Some(CssGradientKind.RepeatingLinear)
            case "-webkit-radial-gradient" => Some(CssGradientKind.Radial)
            case "-webkit-repeating-radial-gradient" => Some(CssGradientKind.RepeatingRadial)
            case "-moz-linear-gradient" => Some(CssGradientKind.Linear)
            case "-moz-repeating-linear-gradient" => Some(CssGradientKind.RepeatingLinear)
            case "-moz-radial-gradient" => Some(CssGradientKind.Radial)
            case "-moz-repeating-radial-gradient" => Some(CssGradientKind.RepeatingRadial)
            case "-o-linear-gradient" => Some(CssGradientKind.Linear)
            case "-o-repeating-linear-gradient" => Some(CssGradientKind.RepeatingLinear)
            case "-o-radial-gradient" => Some(CssGradientKind.Radial)
            case "-o-repeating-radial-gradient" => Some(CssGradientKind.RepeatingRadial)
            case "-webkit-gradient" => Some(CssGradientKind.WebkitGradient)
            case _ => None
        }
    }

    /// 从函数名解析供应商前缀
    /// 严格翻译自 Gradient.parse 中的前缀判断
    public static func prefixFromFuncName(funcName: String): VendorPrefix {
        let lower = funcName.toLowerCase()
        if (lower.startsWith("-webkit-")) {
            return VendorPrefix.webkitPrefix()
        }
        if (lower.startsWith("-moz-")) {
            return VendorPrefix.mozPrefix()
        }
        if (lower.startsWith("-o-")) {
            return VendorPrefix.oPrefix()
        }
        let vp = VendorPrefix()
        vp.none = true
        return vp
    }
}
