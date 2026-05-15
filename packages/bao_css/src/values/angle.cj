// bao_css - CSS 角度值类型
// 严格翻译自: bun/src/css/values/angle.rs
//   对应: values/angle.zig - Angle, AnglePercentage
package bao.css

import bao_core.*

// ============================================================================
// 角度值
// 严格翻译自: values/angle.rs Angle enum
// ============================================================================

/// CSS <angle> 值
/// 严格翻译自 Angle enum { Deg(f32), Rad(f32), Grad(f32), Turn(f32) }
/// 角度可能为显式值或由 calc() 计算，但总是存储为计算值
public class CssAngle {
    public enum CssAngleKind {
        | Deg    // 度 (360度一圈)
        | Rad    // 弧度 (2π弧度一圈)
        | Grad   // 梯度 (400梯度一圈)
        | Turn   // 圈 (1圈一圈)
    }

    public var kind: CssAngleKind
    public var value: Float64

    public init(kind: CssAngleKind, value: Float64) {
        this.kind = kind
        this.value = value
    }

    /// 零度
    /// 严格翻译自 Angle.zero
    public static func zero(): CssAngle {
        CssAngle(CssAngleKind.Deg, 0.0)
    }

    /// 是否为零
    /// 严格翻译自 Angle.is_zero
    public func isZero(): Bool {
        value == 0.0
    }

    /// 转为弧度
    /// 严格翻译自 Angle.to_radians
    public func toRadians(): Float64 {
        let radPerDeg: Float64 = 3.14159265358979323846 / 180.0
        match (kind) {
            case Deg => value * radPerDeg
            case Rad => value
            case Grad => value * 180.0 / 200.0 * radPerDeg
            case Turn => value * 360.0 * radPerDeg
        }
    }

    /// 转为度数
    /// 严格翻译自 Angle.to_degrees
    public func toDegrees(): Float64 {
        let degPerRad: Float64 = 180.0 / 3.14159265358979323846
        match (kind) {
            case Deg => value
            case Rad => value * degPerRad
            case Grad => value * 180.0 / 200.0
            case Turn => value * 360.0
        }
    }

    /// 符号
    /// 严格翻译自 Angle.sign
    public func sign(): Float64 {
        if (value > 0.0) { 1.0 }
        else if (value < 0.0) { -1.0 }
        else { 0.0 }
    }

    /// 乘以浮点数
    /// 严格翻译自 Angle.mul_f32
    public func mulF32(other: Float64): CssAngle {
        CssAngle(kind, value * other)
    }

    /// 相加
    /// 严格翻译自 Angle.add
    public func add(rhs: CssAngle): CssAngle {
        if (kind == rhs.kind) {
            CssAngle(kind, value + rhs.value)
        } else {
            CssAngle(CssAngleKind.Deg, toDegrees() + rhs.toDegrees())
        }
    }

    /// 相等比较 (基于度数)
    /// 严格翻译自 Angle.eql — 比较度数，非结构相等
    public func eql(other: CssAngle): Bool {
        toDegrees() == other.toDegrees()
    }

    /// 深拷贝
    public func deepClone(): CssAngle {
        CssAngle(kind, value)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Angle.to_css
    public func toCss(): String {
        match (kind) {
            case Deg => "${value}deg"
            case Rad => "${value}rad"
            case Grad => "${value}grad"
            case Turn => "${value}turn"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 角度百分比
// 严格翻译自: values/angle.rs AnglePercentage = DimensionPercentage<Angle>
// ============================================================================

/// CSS <angle-percentage> 值
/// 严格翻译自 AnglePercentage = DimensionPercentage<Angle>
/// 可指定为角度或解析为角度的百分比
public class CssAnglePercentage {
    public enum CssAnglePercentageKind {
        | Dimension    // 角度值
        | Percentage   // 百分比值
        | Calc         // calc() 表达式
    }

    public var kind: CssAnglePercentageKind
    public var dimension: ?CssAngle
    public var percentage: Float64  // 0.0~1.0
    public var calcExpression: String

    public init(dimension: CssAngle) {
        this.kind = CssAnglePercentageKind.Dimension
        this.dimension = Some(dimension)
        this.percentage = 0.0
        this.calcExpression = ""
    }

    public init(percentage: Float64) {
        this.kind = CssAnglePercentageKind.Percentage
        this.dimension = None
        this.percentage = percentage
        this.calcExpression = ""
    }

    public init(calc: String) {
        this.kind = CssAnglePercentageKind.Calc
        this.dimension = None
        this.percentage = 0.0
        this.calcExpression = calc
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Dimension => {
                match (dimension) {
                    case Some(d) => d.toCss()
                    case None => ""
                }
            }
            case Percentage => "${percentage * 100.0}%"
            case Calc => calcExpression
        }
    }

    public func toString(): String {
        toCss()
    }
}
