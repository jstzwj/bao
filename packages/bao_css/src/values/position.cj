// bao_css - CSS 位置值
// 严格翻译自: bun/src/css/values/position.rs
//   对应: values/position.zig - Position, PositionComponent, HorizontalPositionKeyword, VerticalPositionKeyword
package bao_css.values

import bao_core.*

// ============================================================================
// 水平位置关键字
// 严格翻译自: values/position.rs HorizontalPositionKeyword { Left, Right }
// ============================================================================

/// CSS 水平位置关键字
/// 严格翻译自 HorizontalPositionKeyword { Left, Right }
public enum CssHorizontalPositionKeyword {
    | Left    // left
    | Right   // right

    /// 转为长度百分比
    /// 严格翻译自 HorizontalPositionKeyword::into_length_percentage
    public func intoLengthPercentage(): CssDimensionPercentage {
        match (this) {
            case Left => CssDimensionPercentage.zero()
            case Right => CssDimensionPercentage(CssPercentage(1.0))
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (this) {
            case Left => "left"
            case Right => "right"
        }
    }
}

// ============================================================================
// 垂直位置关键字
// 严格翻译自: values/position.rs VerticalPositionKeyword { Top, Bottom }
// ============================================================================

/// CSS 垂直位置关键字
/// 严格翻译自 VerticalPositionKeyword { Top, Bottom }
public enum CssVerticalPositionKeyword {
    | Top     // top
    | Bottom  // bottom

    /// 转为长度百分比
    /// 严格翻译自 VerticalPositionKeyword::into_length_percentage
    public func intoLengthPercentage(): CssDimensionPercentage {
        match (this) {
            case Top => CssDimensionPercentage.zero()
            case Bottom => CssDimensionPercentage(CssPercentage(1.0))
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (this) {
            case Top => "top"
            case Bottom => "bottom"
        }
    }
}

// ============================================================================
// 位置组件边
// 严格翻译自: values/position.rs PositionComponentSide<S>
// ============================================================================

/// CSS 位置组件边
/// 严格翻译自 PositionComponentSide<S> { side: S, offset: Option<LengthPercentage> }
public class CssPositionComponentSide {
    public var sideKeyword: String  // "left"/"right"/"top"/"bottom"
    public var offset: ?CssDimensionPercentage

    public init(side: String, offset: ?CssDimensionPercentage) {
        this.sideKeyword = side
        this.offset = offset
    }

    /// 深拷贝
    public func deepClone(): CssPositionComponentSide {
        let off = match (offset) {
            case Some(o) => Some(o.deepClone())
            case None => None
        }
        CssPositionComponentSide(sideKeyword, off)
    }
}

// ============================================================================
// 位置组件
// 严格翻译自: values/position.rs PositionComponent<S> { Center, Length, Side }
// ============================================================================

/// CSS 位置组件
/// 严格翻译自 PositionComponent<S> { Center, Length(LengthPercentage), Side(PositionComponentSide<S>) }
public class CssPositionComponent {
    public enum CssPositionComponentKind {
        | Center   // center
        | Length   // 长度或百分比
        | Side     // 边关键字 + 偏移
    }

    public var kind: CssPositionComponentKind
    public var lengthValue: ?CssDimensionPercentage
    public var sideValue: ?CssPositionComponentSide

    public init(center: Unit) {
        this.kind = CssPositionComponentKind.Center
        this.lengthValue = None
        this.sideValue = None
    }

    public init(length: CssDimensionPercentage) {
        this.kind = CssPositionComponentKind.Length
        this.lengthValue = Some(length)
        this.sideValue = None
    }

    public init(side: CssPositionComponentSide) {
        this.kind = CssPositionComponentKind.Side
        this.lengthValue = None
        this.sideValue = Some(side)
    }

    /// 是否居中
    /// 严格翻译自 PositionComponent::is_center
    public func isCenter(): Bool {
        match (kind) {
            case Center => true
            case Length => {
                match (lengthValue) {
                    case Some(lp) => {
                        match (lp.kind) {
                            case CssDimensionPercentage.CssDimensionPercentageKind.Percentage => {
                                match (lp.percentageValue) {
                                    case Some(p) => p.v == 0.5
                                    case None => false
                                }
                            }
                            case _ => false
                        }
                    }
                    case None => false
                }
            }
            case Side => false
        }
    }

    /// 是否为零
    /// 严格翻译自 PositionComponent::is_zero
    public func isZero(): Bool {
        match (kind) {
            case Length => {
                match (lengthValue) {
                    case Some(lp) => lp.isZero()
                    case None => false
                }
            }
            case _ => false
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 PositionComponent::to_css
    public func toCss(minify: Bool): String {
        match (kind) {
            case Center => {
                if (minify) { "50%" } else { "center" }
            }
            case Length => {
                match (lengthValue) {
                    case Some(lp) => lp.toCss()
                    case None => "0"
                }
            }
            case Side => {
                match (sideValue) {
                    case Some(side) => {
                        let base = side.sideKeyword
                        match (side.offset) {
                            case Some(off) => "${base} ${off.toCss()}"
                            case None => base
                        }
                    }
                    case None => "center"
                }
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssPositionComponent {
        match (kind) {
            case Center => CssPositionComponent(center: ())
            case Length => {
                match (lengthValue) {
                    case Some(lp) => CssPositionComponent(length: lp.deepClone())
                    case None => CssPositionComponent(center: ())
                }
            }
            case Side => {
                match (sideValue) {
                    case Some(s) => CssPositionComponent(side: s.deepClone())
                    case None => CssPositionComponent(center: ())
                }
            }
        }
    }

    public func toString(): String {
        toCss(false)
    }
}

// ============================================================================
// 位置
// 严格翻译自: values/position.rs Position { x, y }
// ============================================================================

/// CSS <position> 值
/// 严格翻译自 Position struct { x: HorizontalPosition, y: VerticalPosition }
public class CssPosition {
    public var x: CssPositionComponent
    public var y: CssPositionComponent

    public init(x: CssPositionComponent, y: CssPositionComponent) {
        this.x = x
        this.y = y
    }

    /// 默认值 (0% 0%)
    /// 严格翻译自 Position::default
    public static func defaultValue(): CssPosition {
        CssPosition(
            CssPositionComponent(length: CssDimensionPercentage(CssPercentage(0.0))),
            CssPositionComponent(length: CssDimensionPercentage(CssPercentage(0.0)))
        )
    }

    /// 居中
    /// 严格翻译自 Position::center
    public static func center(): CssPosition {
        CssPosition(
            CssPositionComponent(center: ()),
            CssPositionComponent(center: ())
        )
    }

    /// 是否居中
    /// 严格翻译自 Position::is_center
    public func isCenter(): Bool {
        x.isCenter() && y.isCenter()
    }

    /// 是否为零
    /// 严格翻译自 Position::is_zero
    public func isZero(): Bool {
        x.isZero() && y.isZero()
    }

    /// 深拷贝
    public func deepClone(): CssPosition {
        CssPosition(x.deepClone(), y.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Position::to_css
    public func toCss(minify: Bool): String {
        let xCss = x.toCss(minify)
        let yCss = y.toCss(minify)
        if (xCss == yCss) {
            xCss
        } else {
            "${xCss} ${yCss}"
        }
    }

    public func toString(): String {
        toCss(false)
    }
}
