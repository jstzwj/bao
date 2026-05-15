// bao_css - CSS 渐变值类型
// 严格翻译自: bun/src/css/values/gradient.rs
//   对应: values/gradient.zig - Gradient, LinearGradient, RadialGradient, ConicGradient
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 线性渐变
// 严格翻译自: values/gradient.rs LinearGradient struct
// ============================================================================

/// CSS linear-gradient 方向
/// 严格翻译自 LineDirection enum
public class CssLineDirection {
    public enum CssLineDirectionKind {
        | Angle          // 角度
        | ToTop          // to top
        | ToBottom       // to bottom
        | ToLeft         // to left
        | ToRight        // to right
        | ToTopLeft      // to top left
        | ToTopRight     // to top right
        | ToBottomLeft   // to bottom left
        | ToBottomRight  // to bottom right
    }

    public var kind: CssLineDirectionKind
    public var angle: Float64

    public init(kind: CssLineDirectionKind) {
        this.kind = kind
        this.angle = 0.0
    }

    public init(angle: Float64) {
        this.kind = CssLineDirectionKind.Angle
        this.angle = angle
    }

    public func toCss(): String {
        match (kind) {
            case Angle => "${angle}deg"
            case ToTop => "to top"
            case ToBottom => "to bottom"
            case ToLeft => "to left"
            case ToRight => "to right"
            case ToTopLeft => "to top left"
            case ToTopRight => "to top right"
            case ToBottomLeft => "to bottom left"
            case ToBottomRight => "to bottom right"
        }
    }
}

/// CSS 线性渐变
/// 严格翻译自 LinearGradient struct { direction, items, vendor_prefix, ... }
public class CssLinearGradient {
    /// 方向
    public var direction: CssLineDirection
    /// 渐变项列表
    public var items: ArrayList<CssGradientItem>
    /// 供应商前缀
    public var vendorPrefix: VendorPrefix

    public init(direction: CssLineDirection, items: ArrayList<CssGradientItem>) {
        this.direction = direction
        this.items = items
        this.vendorPrefix = VendorPrefix()
    }

    public func toCss(funcName: String): String {
        let sb = StringBuilder()
        sb.append("${funcName}(")
        sb.append(direction.toCss())
        for (item in items) {
            sb.append(", ${item.toCss()}")
        }
        sb.append(")")
        return sb.toString()
    }
}

// ============================================================================
// 径向渐变形状
// ============================================================================

/// CSS 径向渐变形状
public enum CssRadialGradientShape {
    | Circle   // circle
    | Ellipse  // ellipse

    public func toCss(): String {
        match (this) {
            case Circle => "circle"
            case Ellipse => "ellipse"
        }
    }
}

/// CSS 径向渐变
/// 严格翻译自 RadialGradient struct
public class CssRadialGradient {
    /// 形状
    public var shape: CssRadialGradientShape
    /// 渐变项列表
    public var items: ArrayList<CssGradientItem>
    /// 供应商前缀
    public var vendorPrefix: VendorPrefix

    public init(shape: CssRadialGradientShape, items: ArrayList<CssGradientItem>) {
        this.shape = shape
        this.items = items
        this.vendorPrefix = VendorPrefix()
    }

    public func toCss(funcName: String): String {
        let sb = StringBuilder()
        sb.append("${funcName}(${shape.toCss()}")
        for (item in items) {
            sb.append(", ${item.toCss()}")
        }
        sb.append(")")
        return sb.toString()
    }
}

/// CSS conic 渐变
/// 严格翻译自 ConicGradient struct
public class CssConicGradient {
    /// 起始角度
    public var fromAngle: Float64
    /// 渐变项列表
    public var items: ArrayList<CssGradientItem>

    public init(fromAngle: Float64, items: ArrayList<CssGradientItem>) {
        this.fromAngle = fromAngle
        this.items = items
    }

    public func toCss(funcName: String): String {
        let sb = StringBuilder()
        sb.append("${funcName}(")
        if (fromAngle != 0.0) {
            sb.append("from ${fromAngle}deg, ")
        }
        var first = true
        for (item in items) {
            if (!first) { sb.append(", ") }
            first = false
            sb.append(item.toCss())
        }
        sb.append(")")
        return sb.toString()
    }
}

// ============================================================================
// 渐变项
// ============================================================================

/// CSS 渐变项
public class CssGradientItem {
    public enum CssGradientItemKind {
        | ColorStop        // 颜色停止点
        | Hint             // 插值提示
    }

    public var kind: CssGradientItemKind
    /// 颜色
    public var color: String
    /// 位置
    public var position: String
    /// 提示值
    public var hint: String

    public init(colorStop: String, position: String) {
        this.kind = CssGradientItemKind.ColorStop
        this.color = colorStop
        this.position = position
        this.hint = ""
    }

    public init(hint: String) {
        this.kind = CssGradientItemKind.Hint
        this.color = ""
        this.position = ""
        this.hint = hint
    }

    public func toCss(): String {
        match (kind) {
            case ColorStop => {
                if (position.length > 0) {
                    "${color} ${position}"
                } else {
                    color
                }
            }
            case Hint => hint
        }
    }
}

// ============================================================================
// 渐变
// 严格翻译自: values/gradient.rs Gradient enum
// ============================================================================

/// CSS <gradient>
/// 严格翻译自 Gradient enum { Linear, RepeatingLinear, Radial, RepeatingRadial, Conic, RepeatingConic, WebkitGradient }
public class CssGradient {
    public enum CssGradientKind {
        | Linear
        | RepeatingLinear
        | Radial
        | RepeatingRadial
        | Conic
        | RepeatingConic
        | WebkitGradient
    }

    public var kind: CssGradientKind
    /// 线性渐变
    public var linear: ?CssLinearGradient
    /// 径向渐变
    public var radial: ?CssRadialGradient
    /// conic 渐变
    public var conic: ?CssConicGradient

    public init(linear: CssLinearGradient, kind: CssGradientKind) {
        this.kind = kind
        this.linear = Some(linear)
        this.radial = None
        this.conic = None
    }

    public init(radial: CssRadialGradient, kind: CssGradientKind) {
        this.kind = kind
        this.linear = None
        this.radial = Some(radial)
        this.conic = None
    }

    public init(conic: CssConicGradient, kind: CssGradientKind) {
        this.kind = kind
        this.linear = None
        this.radial = None
        this.conic = Some(conic)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Gradient.to_css
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
            case WebkitGradient => "-webkit-gradient(...)"
        }
    }

    public func toString(): String {
        toCss()
    }
}
