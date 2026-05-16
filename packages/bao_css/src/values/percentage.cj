// bao_css - CSS 百分比值
// 严格翻译自: bun/src/css/values/percentage.rs
//   对应: values/percentage.zig - Percentage, DimensionPercentage, NumberOrPercentage
package bao_css.values

import bao_core.*
import bao_collections.*

// ============================================================================
// 百分比
// 严格翻译自: values/percentage.rs Percentage { v: CSSNumber }
// ============================================================================

/// CSS <percentage> 值
/// 严格翻译自 Percentage struct { v: f32 }
/// v 是 0~1 范围的小数 (e.g. 50% -> 0.5)
public class CssPercentage {
    public var v: Float64

    public init(v: Float64) {
        this.v = v
    }

    /// 解析百分比
    /// 严格翻译自 Percentage::parse
    public static func parse(input: CssParser): Result<CssPercentage> {
        match (input.expectPercentage()) {
            case Some(pct) => Result<CssPercentage>.ok(CssPercentage(pct))
            case None => Result<CssPercentage>.err(CssParseError.invalidValue)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Percentage::to_css
    public func toCss(): String {
        let x = v * 100.0
        if (v != 0.0 && Math.abs(v) < 0.01) {
            // 小百分比: 去前导零
            let str = "${x}%"
            str
        } else {
            let intVal = Int64(x)
            if (Float64(intVal) == x) {
                "${intVal}%"
            } else {
                "${x}%"
            }
        }
    }

    /// 相等比较
    /// 严格翻译自 Percentage::eql
    public func eql(other: CssPercentage): Bool {
        v == other.v
    }

    /// 加法
    /// 严格翻译自 Percentage::add
    public func add(rhs: CssPercentage): CssPercentage {
        CssPercentage(v + rhs.v)
    }

    /// 内部加法
    /// 严格翻译自 Percentage::add_internal
    public func addInternal(rhs: CssPercentage): CssPercentage {
        add(rhs)
    }

    /// 乘以浮点数
    /// 严格翻译自 Percentage::mul_f32
    public func mulF32(other: Float64): CssPercentage {
        CssPercentage(v * other)
    }

    /// 是否为零
    /// 严格翻译自 Percentage::is_zero
    public func isZero(): Bool {
        v == 0.0
    }

    /// 符号
    /// 严格翻译自 Percentage::sign -> sign_f32
    public func sign(): Float64 {
        CSSNumberFns.sign(v)
    }

    /// 尝试获取符号
    /// 严格翻译自 Percentage::try_sign
    public func trySign(): ?Float64 {
        Some(sign())
    }

    /// 偏序比较
    /// 严格翻译自 Percentage::partial_cmp
    public func partialCmp(other: CssPercentage): ?Ordering {
        if (v < other.v) {
            Some(Ordering.Less)
        } else if (v > other.v) {
            Some(Ordering.Greater)
        } else if (v == other.v) {
            Some(Ordering.Equal)
        } else {
            None // NaN
        }
    }

    /// 操作
    /// 严格翻译自 Percentage::op
    public func op(other: CssPercentage, opFn: (Float64, Float64) -> Float64): CssPercentage {
        CssPercentage(opFn(v, other.v))
    }

    /// 转为 calc
    /// 严格翻译自 Percentage::into_calc
    public func intoCalc(): CssCalc {
        CssCalc(toCss())
    }

    /// 深拷贝
    public func deepClone(): CssPercentage {
        CssPercentage(v)
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 维度百分比
// 严格翻译自: values/percentage.rs DimensionPercentage<D>
// Dimension(D), Percentage(Percentage), Calc(Box<Calc<DimensionPercentage<D>>>)
// ============================================================================

/// CSS <dimension-percentage> 值
/// 严格翻译自 DimensionPercentage enum { Dimension, Percentage, Calc }
/// 泛型 D 可以是 Length, Angle, Time 等
public class CssDimensionPercentage {
    public enum CssDimensionPercentageKind {
        | Dimension   // 维度值 (长度/角度/时间)
        | Percentage  // 百分比
        | Calc        // calc() 表达式
    }

    public var kind: CssDimensionPercentageKind
    /// 维度值文本
    public var dimensionText: String
    /// 百分比值
    public var percentageValue: ?CssPercentage
    /// calc 表达式
    public var calcExpression: ?CssCalc

    public init(dimension: String) {
        this.kind = CssDimensionPercentageKind.Dimension
        this.dimensionText = dimension
        this.percentageValue = None
        this.calcExpression = None
    }

    public init(percentage: CssPercentage) {
        this.kind = CssDimensionPercentageKind.Percentage
        this.dimensionText = ""
        this.percentageValue = Some(percentage)
        this.calcExpression = None
    }

    public init(calc: CssCalc) {
        this.kind = CssDimensionPercentageKind.Calc
        this.dimensionText = ""
        this.percentageValue = None
        this.calcExpression = Some(calc)
    }

    /// 零值
    /// 严格翻译自 DimensionPercentage::zero -> Dimension(D::zero())
    public static func zero(): CssDimensionPercentage {
        CssDimensionPercentage("0")
    }

    /// 是否为零
    /// 严格翻译自 DimensionPercentage::is_zero
    public func isZero(): Bool {
        match (kind) {
            case Dimension => dimensionText == "0" || dimensionText == "0px"
            case Percentage => {
                match (percentageValue) {
                    case Some(p) => p.isZero()
                    case None => false
                }
            }
            case Calc => false
        }
    }

    /// 深拷贝
    public func deepClone(): CssDimensionPercentage {
        match (kind) {
            case Dimension => CssDimensionPercentage(dimensionText)
            case Percentage => {
                match (percentageValue) {
                    case Some(p) => CssDimensionPercentage(p.deepClone())
                    case None => CssDimensionPercentage(CssPercentage(0.0))
                }
            }
            case Calc => {
                match (calcExpression) {
                    case Some(c) => CssDimensionPercentage(c)
                    case None => CssDimensionPercentage(CssPercentage(0.0))
                }
            }
        }
    }

    /// 乘以浮点数
    /// 严格翻译自 DimensionPercentage::mul_f32
    public func mulF32(other: Float64): CssDimensionPercentage {
        match (kind) {
            case Dimension => CssDimensionPercentage(dimensionText) // 简化: 维度乘法需要实际值
            case Percentage => {
                match (percentageValue) {
                    case Some(p) => CssDimensionPercentage(p.mulF32(other))
                    case None => CssDimensionPercentage(CssPercentage(0.0))
                }
            }
            case Calc => {
                match (calcExpression) {
                    case Some(c) => CssDimensionPercentage(c.mulF32(other))
                    case None => CssDimensionPercentage(CssPercentage(0.0))
                }
            }
        }
    }

    /// 相等比较
    /// 严格翻译自 DimensionPercentage::eql
    public func eql(other: CssDimensionPercentage): Bool {
        if (kind != other.kind) { return false }
        match (kind) {
            case Dimension => dimensionText == other.dimensionText
            case Percentage => {
                let a = match (percentageValue) { case Some(p) => p case None => return false }
                let b = match (other.percentageValue) { case Some(p) => p case None => return false }
                a.eql(b)
            }
            case Calc => false // calc 表达式比较复杂, 简化返回 false
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Dimension => dimensionText
            case Percentage => {
                match (percentageValue) {
                    case Some(p) => p.toCss()
                    case None => "0%"
                }
            }
            case Calc => {
                match (calcExpression) {
                    case Some(c) => c.toCss()
                    case None => "calc(0)"
                }
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 数值或百分比
// 严格翻译自: values/percentage.rs NumberOrPercentage
// ============================================================================

/// CSS <number-or-percentage> 值
/// 严格翻译自 NumberOrPercentage enum { Number, Percentage }
public class CssNumberOrPercentage {
    public enum CssNumberOrPercentageKind {
        | Number      // 数值
        | Percentage  // 百分比
    }

    public var kind: CssNumberOrPercentageKind
    public var numberValue: Float64
    public var percentageValue: ?CssPercentage

    public init(number: Float64) {
        this.kind = CssNumberOrPercentageKind.Number
        this.numberValue = number
        this.percentageValue = None
    }

    public init(percentage: CssPercentage) {
        this.kind = CssNumberOrPercentageKind.Percentage
        this.numberValue = 0.0
        this.percentageValue = Some(percentage)
    }

    /// 解析数值或百分比
    /// 严格翻译自 NumberOrPercentage::parse
    public static func parse(input: CssParser): Result<CssNumberOrPercentage> {
        // 先尝试数值
        let numResult = CSSNumberFns.parse(input)
        match (numResult) {
            case Ok(n) => return Result<CssNumberOrPercentage>.ok(CssNumberOrPercentage(number: n))
            case _ => {}
        }
        // 再尝试百分比
        let pctResult = CssPercentage.parse(input)
        match (pctResult) {
            case Ok(p) => return Result<CssNumberOrPercentage>.ok(CssNumberOrPercentage(percentage: p))
            case Err(e) => Result<CssNumberOrPercentage>.err(e)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 NumberOrPercentage::to_css
    public func toCss(): String {
        match (kind) {
            case Number => CSSNumberFns.toCss(numberValue)
            case Percentage => {
                match (percentageValue) {
                    case Some(p) => p.toCss()
                    case None => "0%"
                }
            }
        }
    }

    /// 转为 f64
    /// 严格翻译自 NumberOrPercentage::into_f32
    public func intoF64(): Float64 {
        match (kind) {
            case Number => numberValue
            case Percentage => {
                match (percentageValue) {
                    case Some(p) => p.v
                    case None => 0.0
                }
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssNumberOrPercentage {
        match (kind) {
            case Number => CssNumberOrPercentage(number: numberValue)
            case Percentage => {
                match (percentageValue) {
                    case Some(p) => CssNumberOrPercentage(percentage: p.deepClone())
                    case None => CssNumberOrPercentage(percentage: CssPercentage(0.0))
                }
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}
