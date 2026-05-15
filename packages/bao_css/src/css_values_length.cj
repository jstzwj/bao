// bao_css - CSS 长度/位置/角度值类型
// 严格翻译自: bun/src/css/values/
//   对应: values/length.zig - LengthValue, Length, LengthOrNumber, LengthPercentage, LengthPercentageOrAuto
//   对应: values/position.zig - Position, PositionComponent, HorizontalPosition, VerticalPosition
//   对应: values/angle.zig - Angle, AnglePercentage
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// 像素转换常量
// 严格翻译自: length.zig PX_PER_IN, PX_PER_CM, PX_PER_MM, PX_PER_Q, PX_PER_PT, PX_PER_PC
// ============================================================================

/// 每英寸像素数
/// 严格翻译自 PX_PER_IN
const PX_PER_IN: Float64 = 96.0

/// 每厘米像素数
/// 严格翻译自 PX_PER_CM
const PX_PER_CM: Float64 = PX_PER_IN / 2.54

/// 每毫米像素数
/// 严格翻译自 PX_PER_MM
const PX_PER_MM: Float64 = PX_PER_CM / 10.0

/// 每四分之一毫米像素数
/// 严格翻译自 PX_PER_Q
const PX_PER_Q: Float64 = PX_PER_CM / 40.0

/// 每磅像素数
/// 严格翻译自 PX_PER_PT
const PX_PER_PT: Float64 = PX_PER_IN / 72.0

/// 每派卡像素数
/// 严格翻译自 PX_PER_PC
const PX_PER_PC: Float64 = PX_PER_IN / 6.0

// ============================================================================
// 长度值与长度
// 严格翻译自: values/length.zig LengthValue, Length
// ============================================================================

/// CSS 长度值
/// 严格翻译自 LengthValue union(enum)
/// 包含所有绝对/字体相对/视口相对/容器查询单位
///
/// LengthValue 在 css_values.cj 中已有 CssLengthUnit 枚举和 CssLength 类
/// 此处提供更完整的翻译，包括 toPx, tryAdd, partialCmp 等运算方法
public class CssLengthValue {
    public var value: Float64
    public var unit: CssLengthUnit

    public init(value: Float64, unit: CssLengthUnit) {
        this.value = value
        this.unit = unit
    }

    /// 零值
    /// 严格翻译自 LengthValue.zero
    public static func zero(): CssLengthValue {
        CssLengthValue(0.0, CssLengthUnit.Px)
    }

    /// 从像素创建
    public static func px(v: Float64): CssLengthValue {
        CssLengthValue(v, CssLengthUnit.Px)
    }

    /// 是否为零
    /// 严格翻译自 LengthValue.isZero
    public func isZero(): Bool {
        value == 0.0
    }

    /// 符号
    /// 严格翻译自 LengthValue.sign
    public func sign(): Float64 {
        if (value > 0.0) { 1.0 }
        else if (value < 0.0) { -1.0 }
        else { 0.0 }
    }

    /// 尝试转为像素值
    /// 严格翻译自 LengthValue.toPx
    /// 仅绝对单位可转换
    public func toPx(): ?Float64 {
        match (unit) {
            case Px => value
            case In => value * PX_PER_IN
            case Cm => value * PX_PER_CM
            case Mm => value * PX_PER_MM
            case Q => value * PX_PER_Q
            case Pt => value * PX_PER_PT
            case Pc => value * PX_PER_PC
            case _ => None  // 相对单位无法直接转换
        }
    }

    /// 相等比较
    /// 严格翻译自 LengthValue.eql
    /// 仅同单位时比较，否则尝试转换像素
    public func eql(other: CssLengthValue): Bool {
        if (unit == other.unit) {
            return value == other.value
        }
        // 尝试都转为像素比较
        match (toPx()) {
            case Some(a) =>
                match (other.toPx()) {
                    case Some(b) => a == b
                    case None => false
                }
            case None => false
        }
    }

    /// 尝试相加
    /// 严格翻译自 LengthValue.tryAdd
    /// 同单位直接相加；绝对单位转像素相加
    public func tryAdd(other: CssLengthValue): ?CssLengthValue {
        // 同单位直接相加
        if (unit == other.unit) {
            return Some(CssLengthValue(value + other.value, unit))
        }
        // 尝试转像素相加
        match (toPx()) {
            case Some(a) =>
                match (other.toPx()) {
                    case Some(b) => Some(CssLengthValue(a + b, CssLengthUnit.Px))
                    case None => None
                }
            case None => None
        }
    }

    /// 乘以浮点数
    /// 严格翻译自 LengthValue.mulF32
    public func mulF32(other: Float64): CssLengthValue {
        CssLengthValue(value * other, unit)
    }

    /// 获取 (value, unit_string) 元组
    /// 严格翻译自 LengthValue.toUnitValue
    public func toUnitValue(): String {
        "${value}${unit.toString()}"
    }

    /// 是否兼容目标浏览器
    /// 严格翻译自 LengthValue.isCompatible
    public func isCompatible(browsers: CssBrowsers): Bool {
        // viewport 和 container query 单位需检查兼容性
        match (unit) {
            // 视口小尺寸单位
            case Svw | Svh | Svi | Svb | Svmin | Svmax =>
                browsers.supportsViewportSmall()
            // 视口大尺寸单位
            case Lvw | Lvh | Lvi | Lvb | Lvmin | Lvmax =>
                browsers.supportsViewportLarge()
            // 视口动态尺寸单位
            case Dvw | Dvh | Dvi | Dvb | Dvmin | Dvmax =>
                browsers.supportsViewportDynamic()
            // 容器查询单位
            case Cqw | Cqh | Cqi | Cqb | Cqmin | Cqmax =>
                browsers.supportsContainerQueries()
            // 其他单位默认兼容
            case _ => true
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 LengthValue.toCss
    public func toCss(inCalc: Bool): String {
        // 如果值为零且不在 calc 内，可以省略单位
        if (!inCalc && value == 0.0) {
            return "0"
        }
        "${value}${unit.toString()}"
    }

    public func toString(): String {
        toCss(false)
    }
}

/// CSS 长度
/// 严格翻译自 Length union(enum) { value: LengthValue, calc: *Calc(Length) }
/// 支持 calc() 表达式的长度值
public class CssLengthWithCalc {
    public var kind: CssLengthKind
    public var value: ?CssLengthValue
    // calc 字段在完整实现中使用
    public var calcExpr: String  // calc 表达式文本

    public enum CssLengthKind {
        | Value
        | Calc
    }

    public init() {
        this.kind = CssLengthKind.Value
        this.value = Some(CssLengthValue.zero())
        this.calcExpr = ""
    }

    public init(value: CssLengthValue) {
        this.kind = CssLengthKind.Value
        this.value = Some(value)
        this.calcExpr = ""
    }

    public init(calcExpr: String) {
        this.kind = CssLengthKind.Calc
        this.value = None
        this.calcExpr = calcExpr
    }

    /// 零值
    /// 严格翻译自 Length.zero
    public static func zero(): CssLengthWithCalc {
        CssLengthWithCalc(CssLengthValue.zero())
    }

    /// 从像素创建
    /// 严格翻译自 Length.px
    public static func px(v: Float64): CssLengthWithCalc {
        CssLengthWithCalc(CssLengthValue(v, CssLengthUnit.Px))
    }

    /// 是否为零
    /// 严格翻译自 Length.isZero
    public func isZero(): Bool {
        match (kind) {
            case Value =>
                match (value) {
                    case Some(v) => v.isZero()
                    case None => false
                }
            case Calc => false
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Length.toCss
    public func toCss(): String {
        match (kind) {
            case Value =>
                match (value) {
                    case Some(v) => v.toString()
                    case None => "0"
                }
            case Calc => calcExpr
        }
    }

    public func toString(): String {
        toCss()
    }
}

/// LengthOrNumber - 长度或数字
/// 严格翻译自 LengthOrNumber union(enum) { number, length }
public class CssLengthOrNumber {
    public var kind: CssLengthOrNumberKind
    public var number: Float64
    public var length: ?CssLengthValue

    public enum CssLengthOrNumberKind {
        | Number
        | Length
    }

    public init(number: Float64) {
        this.kind = CssLengthOrNumberKind.Number
        this.number = number
        this.length = None
    }

    public init(length: CssLengthValue) {
        this.kind = CssLengthOrNumberKind.Length
        this.number = 0.0
        this.length = Some(length)
    }

    /// 默认值为数字 0
    /// 严格翻译自 LengthOrNumber.default
    public static func default(): CssLengthOrNumber {
        CssLengthOrNumber(0.0)
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Number => "${number}"
            case Length =>
                match (length) {
                    case Some(l) => l.toString()
                    case None => "0"
                }
        }
    }

    public func toString(): String {
        toCss()
    }
}

/// LengthPercentage - 长度/百分比值
/// 严格翻译自 LengthPercentage = DimensionPercentage(LengthValue)
/// union(enum) { dimension: LengthValue, percentage: Percentage, calc }
public class CssLengthPercentage {
    public var kind: CssLengthPercentageKind
    public var dimension: ?CssLengthValue
    public var percentage: ?CssPercentage

    public enum CssLengthPercentageKind {
        | Dimension
        | Percentage
        | Calc
    }

    public init(dimension: CssLengthValue) {
        this.kind = CssLengthPercentageKind.Dimension
        this.dimension = Some(dimension)
        this.percentage = None
    }

    public init(percentage: CssPercentage) {
        this.kind = CssLengthPercentageKind.Percentage
        this.dimension = None
        this.percentage = Some(percentage)
    }

    /// 零值 (0px)
    /// 严格翻译自 DimensionPercentage.zero
    public static func zero(): CssLengthPercentage {
        CssLengthPercentage(CssLengthValue.zero())
    }

    /// 是否为零
    /// 严格翻译自 DimensionPercentage.isZero
    public func isZero(): Bool {
        match (kind) {
            case Dimension =>
                match (dimension) {
                    case Some(d) => d.isZero()
                    case None => false
                }
            case Percentage =>
                match (percentage) {
                    case Some(p) => p.isZero()
                    case None => false
                }
            case Calc => false
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Dimension =>
                match (dimension) {
                    case Some(d) => d.toString()
                    case None => "0"
                }
            case Percentage =>
                match (percentage) {
                    case Some(p) => p.toString()
                    case None => "0%"
                }
            case Calc => "calc()"
        }
    }

    public func toString(): String {
        toCss()
    }
}

/// LengthPercentageOrAuto - 长度/百分比或 auto
/// 严格翻译自 LengthPercentageOrAuto union(enum) { auto, length }
public class CssLengthPercentageOrAuto {
    public var kind: CssLpOrAutoKind
    public var length: ?CssLengthPercentage

    public enum CssLpOrAutoKind {
        | Auto
        | Length
    }

    public init() {
        this.kind = CssLpOrAutoKind.Auto
        this.length = None
    }

    public init(length: CssLengthPercentage) {
        this.kind = CssLpOrAutoKind.Length
        this.length = Some(length)
    }

    /// auto 值
    public static func auto(): CssLengthPercentageOrAuto {
        CssLengthPercentageOrAuto()
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Auto => "auto"
            case Length =>
                match (length) {
                    case Some(l) => l.toString()
                    case None => "auto"
                }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 角度值
// 严格翻译自: values/angle.zig Angle, AnglePercentage
// ============================================================================

/// CSS 角度值 (扩展版，包含完整运算方法)
/// 严格翻译自 Angle union(Tag) { deg, rad, grad, turn }
/// 已在 css_values.cj 中有基础版 CssAngle，此处补充运算
public class CssAngleFull {
    public var value: Float64
    public var unit: CssAngleUnit

    public init(value: Float64, unit: CssAngleUnit) {
        this.value = value
        this.unit = unit
    }

    /// 零值
    /// 严格翻译自 Angle.zero
    public static func zero(): CssAngleFull {
        CssAngleFull(0.0, CssAngleUnit.Deg)
    }

    /// 是否为零
    /// 严格翻译自 Angle.isZero
    public func isZero(): Bool {
        value == 0.0
    }

    /// 转换为度数
    /// 严格翻译自 Angle.toDegrees
    public func toDegrees(): Float64 {
        match (unit) {
            case Deg => value
            case Rad => value * 180.0 / 3.14159265358979323846
            case Grad => value * 180.0 / 200.0
            case Turn => value * 360.0
        }
    }

    /// 转换为弧度
    /// 严格翻译自 Angle.toRadians
    public func toRadians(): Float64 {
        let radPerDeg = 3.14159265358979323846 / 180.0
        match (unit) {
            case Deg => value * radPerDeg
            case Rad => value
            case Grad => value * 180.0 / 200.0 * radPerDeg
            case Turn => value * 360.0 * radPerDeg
        }
    }

    /// 相加 (同单位直接加，不同单位转为度)
    /// 严格翻译自 Angle.add
    public func add(other: CssAngleFull): CssAngleFull {
        if (unit == other.unit) {
            return CssAngleFull(value + other.value, unit)
        }
        // 不同单位，结果用 deg
        CssAngleFull(toDegrees() + other.toDegrees(), CssAngleUnit.Deg)
    }

    /// 相等比较 (通过度数比较)
    /// 严格翻译自 Angle.eql
    public func eql(other: CssAngleFull): Bool {
        toDegrees() == other.toDegrees()
    }

    /// 乘以浮点数
    /// 严格翻译自 Angle.mulF32
    public func mulF32(other: Float64): CssAngleFull {
        CssAngleFull(value * other, unit)
    }

    /// 符号
    /// 严格翻译自 Angle.sign
    public func sign(): Float64 {
        if (value > 0.0) { 1.0 }
        else if (value < 0.0) { -1.0 }
        else { 0.0 }
    }

    /// 是否为负值
    public func isSignNegative(): Bool {
        value < 0.0
    }

    /// 是否为正值
    public func isSignPositive(): Bool {
        value >= 0.0
    }

    /// 符号映射
    /// 严格翻译自 Angle.map
    public func map(fn: (Float64) -> Float64): CssAngleFull {
        CssAngleFull(fn(value), unit)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Angle.toCss (含 rad/deg 优化选择)
    public func toCss(): String {
        // rad 短则用 rad，否则用 deg
        if (unit == CssAngleUnit.Rad) {
            let deg = toDegrees()
            // 简单启发：如果 deg 表示更短则用 deg
            let degStr = "${deg}"
            let radStr = "${value}"
            if (degStr.size < radStr.size) {
                return "${deg}deg"
            }
        }
        "${value}${unit.toString()}"
    }

    public func toString(): String {
        toCss()
    }
}

/// AnglePercentage - 角度/百分比值
/// 严格翻译自 AnglePercentage = DimensionPercentage(Angle)
public class CssAnglePercentage {
    public var kind: CssAnglePercentageKind
    public var angle: ?CssAngleFull
    public var percentage: ?CssPercentage

    public enum CssAnglePercentageKind {
        | Angle
        | Percentage
        | Calc
    }

    public init(angle: CssAngleFull) {
        this.kind = CssAnglePercentageKind.Angle
        this.angle = Some(angle)
        this.percentage = None
    }

    public init(percentage: CssPercentage) {
        this.kind = CssAnglePercentageKind.Percentage
        this.angle = None
        this.percentage = Some(percentage)
    }

    /// 零值
    public static func zero(): CssAnglePercentage {
        CssAnglePercentage(CssAngleFull.zero())
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Angle =>
                match (angle) {
                    case Some(a) => a.toString()
                    case None => "0deg"
                }
            case Percentage =>
                match (percentage) {
                    case Some(p) => p.toString()
                    case None => "0%"
                }
            case Calc => "calc()"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 位置值
// 严格翻译自: values/position.zig
//   Position, PositionComponent, HorizontalPositionKeyword, VerticalPositionKeyword
// ============================================================================

/// 水平位置关键字
/// 严格翻译自 HorizontalPositionKeyword enum { left, right }
public enum CssHorizontalPositionKeyword {
    | Left
    | Right

    public func toString(): String {
        match (this) {
            case Left => "left"
            case Right => "right"
        }
    }

    /// 转为 LengthPercentage
    /// 严格翻译自 HorizontalPositionKeyword.intoLengthPercentage
    public func intoLengthPercentage(): CssLengthPercentage {
        match (this) {
            case Left => CssLengthPercentage(CssLengthValue.zero())
            case Right => CssLengthPercentage(CssPercentage(1.0))
        }
    }
}

/// 垂直位置关键字
/// 严格翻译自 VerticalPositionKeyword enum { top, bottom }
public enum CssVerticalPositionKeyword {
    | Top
    | Bottom

    public func toString(): String {
        match (this) {
            case Top => "top"
            case Bottom => "bottom"
        }
    }

    /// 转为 LengthPercentage
    /// 严格翻译自 VerticalPositionKeyword.intoLengthPercentage
    public func intoLengthPercentage(): CssLengthPercentage {
        match (this) {
            case Top => CssLengthPercentage(CssLengthValue.zero())
            case Bottom => CssLengthPercentage(CssPercentage(1.0))
        }
    }
}

/// 位置组件 (泛型模板，用于水平/垂直)
/// 严格翻译自 PositionComponent(S) union(enum) { center, length, side }
/// side = struct { side: S, offset: ?LengthPercentage }
public class CssPositionComponent {
    public var kind: CssPositionComponentKind
    // center 时为空
    public var length: ?CssLengthPercentage
    public var sideKeyword: String  // "left", "right", "top", "bottom"
    public var sideOffset: ?CssLengthPercentage

    public enum CssPositionComponentKind {
        | Center
        | Length
        | Side
    }

    /// center
    public static func center(): CssPositionComponent {
        let c = CssPositionComponent()
        c.kind = CssPositionComponentKind.Center
        return c
    }

    /// 从长度/百分比
    public init(length: CssLengthPercentage) {
        this.kind = CssPositionComponentKind.Length
        this.length = Some(length)
        this.sideKeyword = ""
        this.sideOffset = None
    }

    public init() {
        this.kind = CssPositionComponentKind.Center
        this.length = None
        this.sideKeyword = ""
        this.sideOffset = None
    }

    /// 从 side 关键字和可选偏移
    public static func side(keyword: String, offset: ?CssLengthPercentage): CssPositionComponent {
        let c = CssPositionComponent()
        c.kind = CssPositionComponentKind.Side
        c.sideKeyword = keyword
        c.sideOffset = offset
        return c
    }

    /// 是否为零
    /// 严格翻译自 PositionComponent.isZero
    public func isZero(): Bool {
        match (kind) {
            case Length =>
                match (length) {
                    case Some(l) => l.isZero()
                    case None => false
                }
            case _ => false
        }
    }

    /// 是否为中心
    /// 严格翻译自 PositionComponent.isCenter
    public func isCenter(): Bool {
        match (kind) {
            case Center => true
            case Length =>
                match (length) {
                    case Some(l) =>
                        // 50% 也视为 center
                        match (l.kind) {
                            case Percentage =>
                                match (l.percentage) {
                                    case Some(p) => p.value == 0.5
                                    case None => false
                                }
                            case _ => false
                        }
                    case None => false
                }
            case _ => false
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 PositionComponent.toCss
    public func toCss(minify: Bool): String {
        match (kind) {
            case Center =>
                if (minify) { "50%" } else { "center" }
            case Length =>
                match (length) {
                    case Some(l) => l.toString()
                    case None => "0"
                }
            case Side => {
                var s = sideKeyword
                match (sideOffset) {
                    case Some(offset) => "${s} ${offset.toString()}"
                    case None => s
                }
            }
        }
    }

    public func toString(): String {
        toCss(false)
    }
}

/// CSS <position> 值
/// 严格翻译自 Position struct { x: HorizontalPosition, y: VerticalPosition }
/// 用于 background-position, gradients, masks 等属性
public class CssPosition {
    public var x: CssPositionComponent
    public var y: CssPositionComponent

    public init(x: CssPositionComponent, y: CssPositionComponent) {
        this.x = x
        this.y = y
    }

    public init() {
        this.x = CssPositionComponent.center()
        this.y = CssPositionComponent.center()
    }

    /// 默认位置 (0% 0%)
    /// 严格翻译自 Position.default
    public static func default(): CssPosition {
        let x = CssPositionComponent(CssLengthPercentage(CssPercentage(0.0)))
        let y = CssPositionComponent(CssLengthPercentage(CssPercentage(0.0)))
        CssPosition(x, y)
    }

    /// 居中位置
    /// 严格翻译自 Position.center
    public static func center(): CssPosition {
        CssPosition(CssPositionComponent.center(), CssPositionComponent.center())
    }

    /// 是否都居中
    /// 严格翻译自 Position.isCenter
    public func isCenter(): Bool {
        x.isCenter() && y.isCenter()
    }

    /// 是否为零
    /// 严格翻译自 Position.isZero
    public func isZero(): Bool {
        x.isZero() && y.isZero()
    }

    /// 相等比较
    /// 严格翻译自 Position.eql
    public func eql(other: CssPosition): Bool {
        x.toString() == other.x.toString() && y.toString() == other.y.toString()
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Position.toCss (含简写优化)
    public func toCss(minify: Bool): String {
        // 两个 center 可简写
        if (isCenter()) {
            if (minify) { "50%" } else { "center" }
        } else if (x.isCenter() && !y.isCenter()) {
            // x 居中时，可省略
            y.toCss(minify)
        } else if (!x.isCenter() && y.isCenter()) {
            // y 居中时，可省略
            x.toCss(minify)
        } else {
            "${x.toCss(minify)} ${y.toCss(minify)}"
        }
    }

    public func toString(): String {
        toCss(false)
    }
}

// ============================================================================
// 时间值
// 严格翻译自: values/time.zig Time
// ============================================================================

/// CSS 时间单位
/// 严格翻译自 Time union(Tag) { seconds, milliseconds }
public enum CssTimeUnit {
    | Seconds      // s
    | Milliseconds // ms

    public func toString(): String {
        match (this) {
            case Seconds => "s"
            case Milliseconds => "ms"
        }
    }
}

/// CSS 时间值
/// 严格翻译自 Time union(Tag) { seconds: CSSNumber, milliseconds: CSSNumber }
public class CssTime {
    public var kind: CssTimeUnit
    public var value: Float64

    public init(value: Float64, unit: CssTimeUnit) {
        this.kind = unit
        this.value = value
    }

    public static func seconds(v: Float64): CssTime {
        CssTime(v, CssTimeUnit.Seconds)
    }

    public static func milliseconds(v: Float64): CssTime {
        CssTime(v, CssTimeUnit.Milliseconds)
    }

    /// 是否为零
    /// 严格翻译自 Time.isZero
    public func isZero(): Bool {
        value == 0.0
    }

    /// 转为毫秒
    /// 严格翻译自 Time.toMs
    public func toMs(): Float64 {
        match (kind) {
            case Seconds => value * 1000.0
            case Milliseconds => value
        }
    }

    /// 转为秒
    public func toSeconds(): Float64 {
        match (kind) {
            case Seconds => value
            case Milliseconds => value / 1000.0
        }
    }

    /// 相加
    /// 严格翻译自 Time.add
    public func add(other: CssTime): CssTime {
        if (kind == other.kind) {
            return CssTime(value + other.value, kind)
        }
        // 不同单位，用秒
        CssTime(toSeconds() + other.toSeconds(), CssTimeUnit.Seconds)
    }

    /// 转为 CSS 文本 (自动选择更短表示)
    /// 严格翻译自 Time.toCss
    /// 0.1s 比 100ms 短，100ms 及以上用秒
    public func toCss(): String {
        match (kind) {
            case Seconds => {
                // 0 < s < 0.1 时用 ms
                if (value > 0.0 && value < 0.1) {
                    "${value * 1000.0}ms"
                } else {
                    "${value}s"
                }
            }
            case Milliseconds => {
                // ms == 0 或 >= 100 时用 s
                if (value == 0.0 || value >= 100.0) {
                    "${value / 1000.0}s"
                } else {
                    "${value}ms"
                }
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 分辨率值
// 严格翻译自: values/resolution.zig Resolution
// ============================================================================

/// CSS 分辨率单位
/// 严格翻译自 Resolution union(enum) { dpi, dpcm, dppx }
public enum CssResolutionUnit {
    | Dpi   // dots per inch
    | Dpcm  // dots per cm
    | Dppx  // dots per px (also 'x')

    public func toString(): String {
        match (this) {
            case Dpi => "dpi"
            case Dpcm => "dpcm"
            case Dppx => "dppx"
        }
    }
}

/// CSS 分辨率值
/// 严格翻译自 Resolution union(enum) { dpi, dpcm, dppx }
public class CssResolution {
    public var value: Float64
    public var unit: CssResolutionUnit

    public init(value: Float64, unit: CssResolutionUnit) {
        this.value = value
        this.unit = unit
    }

    public static func dpi(v: Float64): CssResolution {
        CssResolution(v, CssResolutionUnit.Dpi)
    }

    public static func dpcm(v: Float64): CssResolution {
        CssResolution(v, CssResolutionUnit.Dpcm)
    }

    public static func dppx(v: Float64): CssResolution {
        CssResolution(v, CssResolutionUnit.Dppx)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Resolution.toCss
    /// dppx 在兼容浏览器中可简写为 'x'
    public func toCss(useX: Bool): String {
        let u = if (unit == CssResolutionUnit.Dppx && useX) { "x" } else { unit.toString() }
        "${value}${u}"
    }

    public func toString(): String {
        toCss(false)
    }
}

/// 浏览器兼容性查询接口 (简化版)
/// 用于 LengthValue.isCompatible 等方法
public class CssBrowsers {
    public var hasBrowsers: Bool

    public init() {
        this.hasBrowsers = false
    }

    public func supportsViewportSmall(): Bool {
        hasBrowsers
    }

    public func supportsViewportLarge(): Bool {
        hasBrowsers
    }

    public func supportsViewportDynamic(): Bool {
        hasBrowsers
    }

    public func supportsContainerQueries(): Bool {
        hasBrowsers
    }
}
