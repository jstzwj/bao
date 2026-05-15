// bao_css - CSS calc() 数学表达式
// 严格翻译自: bun/src/css/values/calc.rs
//   对应: values/calc.zig - Calc, MathFunction, CalcUnit, RoundingStrategy, Constant
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// calc() 函数单位/类型
// 严格翻译自: values/calc.rs CalcUnit enum
// ============================================================================

/// CSS calc() 数学函数类型
/// 严格翻译自 CalcUnit enum
public enum CssCalcUnit {
    | Abs        // abs()
    | Acos       // acos()
    | Asin       // asin()
    | Atan       // atan()
    | Atan2      // atan2()
    | Calc       // calc()
    | Clamp      // clamp()
    | Cos        // cos()
    | Exp        // exp()
    | Hypot      // hypot()
    | Log        // log()
    | Max        // max()
    | Min        // min()
    | Mod        // mod()
    | Pow        // pow()
    | Rem        // rem()
    | Round      // round()
    | Sign       // sign()
    | Sin        // sin()
    | Sqrt       // sqrt()
    | Tan        // tan()

    public func toCss(): String {
        match (this) {
            case Abs => "abs"
            case Acos => "acos"
            case Asin => "asin"
            case Atan => "atan"
            case Atan2 => "atan2"
            case Calc => "calc"
            case Clamp => "clamp"
            case Cos => "cos"
            case Exp => "exp"
            case Hypot => "hypot"
            case Log => "log"
            case Max => "max"
            case Min => "min"
            case Mod => "mod"
            case Pow => "pow"
            case Rem => "rem"
            case Round => "round"
            case Sign => "sign"
            case Sin => "sin"
            case Sqrt => "sqrt"
            case Tan => "tan"
        }
    }
}

// ============================================================================
// 舍入策略
// 严格翻译自: values/calc.rs RoundingStrategy enum
// ============================================================================

/// CSS round() 舍入策略
/// 严格翻译自 RoundingStrategy enum { Nearest, Up, Down, ToZero }
public enum CssRoundingStrategy {
    | Nearest  // 四舍五入 (默认)
    | Up       // 向上取整 (ceil)
    | Down     // 向下取整 (floor)
    | ToZero   // 向零取整 (truncate)

    public func toCss(): String {
        match (this) {
            case Nearest => "nearest"
            case Up => "up"
            case Down => "down"
            case ToZero => "to-zero"
        }
    }
}

// ============================================================================
// 数学常量
// 严格翻译自: values/calc.rs Constant enum
// ============================================================================

/// CSS 数学常量
/// 严格翻译自 Constant enum { E, Pi, Infinity, NegInfinity, Nan }
public enum CssConstant {
    | E           // 自然对数底数
    | Pi          // 圆周率
    | Infinity    // 正无穷
    | NegInfinity // 负无穷
    | Nan         // 非数字

    /// 转为 Float64 值
    public func toFloat64(): Float64 {
        match (this) {
            case E => 2.718281828459045
            case Pi => 3.141592653589793
            case Infinity => Float64.MAX
            case NegInfinity => Float64.MIN
            case Nan => 0.0 / 0.0
        }
    }

    public func toCss(): String {
        match (this) {
            case E => "e"
            case Pi => "pi"
            case Infinity => "infinity"
            case NegInfinity => "-infinity"
            case Nan => "nan"
        }
    }
}

// ============================================================================
// Calc 表达式
// 严格翻译自: values/calc.rs Calc<V> enum
// ============================================================================

/// CSS calc() 数学表达式
/// 严格翻译自 Calc enum { Value, Number, Sum, Product, Function }
/// 泛型 V 支持 Length, Percentage, Time, Angle 等值类型
public class CssCalc {
    public enum CssCalcKind {
        | Value     // 字面值
        | Number    // 字面数字
        | Sum       // 两个表达式之和
        | Product   // 数字与表达式的积
        | Function  // 数学函数 (calc/min/max 等)
    }

    public var kind: CssCalcKind
    /// 数值
    public var numberValue: Float64
    /// 文本值 (用于 Value / Function)
    public var textValue: String
    /// 左操作数 (Sum)
    public var left: ?CssCalc
    /// 右操作数 (Sum)
    public var right: ?CssCalc
    /// 乘数 (Product)
    public var multiplier: Float64
    /// 表达式 (Product)
    public var expression: ?CssCalc
    /// 函数类型 (Function)
    public var functionKind: ?CssCalcUnit
    /// 函数参数 (Function)
    public var functionArgs: ArrayList<CssCalc>

    public init(value: String) {
        this.kind = CssCalcKind.Value
        this.numberValue = 0.0
        this.textValue = value
        this.left = None
        this.right = None
        this.multiplier = 1.0
        this.expression = None
        this.functionKind = None
        this.functionArgs = ArrayList<CssCalc>()
    }

    public init(number: Float64) {
        this.kind = CssCalcKind.Number
        this.numberValue = number
        this.textValue = ""
        this.left = None
        this.right = None
        this.multiplier = 1.0
        this.expression = None
        this.functionKind = None
        this.functionArgs = ArrayList<CssCalc>()
    }

    public init(sum: CssCalc, rhs: CssCalc) {
        this.kind = CssCalcKind.Sum
        this.numberValue = 0.0
        this.textValue = ""
        this.left = Some(sum)
        this.right = Some(rhs)
        this.multiplier = 1.0
        this.expression = None
        this.functionKind = None
        this.functionArgs = ArrayList<CssCalc>()
    }

    public init(product: Float64, expr: CssCalc) {
        this.kind = CssCalcKind.Product
        this.numberValue = 0.0
        this.textValue = ""
        this.left = None
        this.right = None
        this.multiplier = product
        this.expression = Some(expr)
        this.functionKind = None
        this.functionArgs = ArrayList<CssCalc>()
    }

    public init(func: CssCalcUnit, args: ArrayList<CssCalc>) {
        this.kind = CssCalcKind.Function
        this.numberValue = 0.0
        this.textValue = ""
        this.left = None
        this.right = None
        this.multiplier = 1.0
        this.expression = None
        this.functionKind = Some(func)
        this.functionArgs = args
    }

    /// 符号
    /// 严格翻译自 Calc.try_sign
    public func trySign(): Float64 {
        match (kind) {
            case Number => {
                if (numberValue > 0.0) { 1.0 }
                else if (numberValue < 0.0) { -1.0 }
                else { 0.0 }
            }
            case _ => 0.0
        }
    }

    /// 是否为负
    public func isSignNegative(): Bool {
        trySign() < 0.0
    }

    /// 乘以浮点数
    /// 严格翻译自 Calc.mul_f32
    public func mulF32(other: Float64): CssCalc {
        if (other == 1.0) { return this }
        match (kind) {
            case Number => CssCalc(numberValue * other)
            case Product => {
                let num = multiplier * other
                if (num == 1.0) {
                    match (expression) {
                        case Some(e) => e
                        case None => this
                    }
                } else {
                    let c = CssCalc(num, match (expression) { case Some(e) => e case None => CssCalc(0.0) })
                    return c
                }
            }
            case Sum => {
                match (left, right) {
                    case (Some(l), Some(r)) => CssCalc(sum: l.mulF32(other), rhs: r.mulF32(other))
                    case _ => this
                }
            }
            case _ => CssCalc(product: other, expr: this)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Calc.to_css / to_css_impl
    public func toCss(): String {
        match (kind) {
            case Value => textValue
            case Number => "${numberValue}"
            case Sum => {
                let leftCss = match (left) { case Some(l) => l.toCss() case None => "" }
                let rightCalc = match (right) { case Some(r) => r case None => CssCalc(0.0) }
                if (rightCalc.isSignNegative()) {
                    let negated = rightCalc.mulF32(-1.0)
                    "${leftCss} - ${negated.toCss()}"
                } else {
                    "${leftCss} + ${rightCalc.toCss()}"
                }
            }
            case Product => {
                let num = Math.abs(multiplier)
                let exprCss = match (expression) { case Some(e) => e.toCss() case None => "" }
                if (num < 1.0 && num != 0.0) {
                    let div = 1.0 / multiplier
                    "${exprCss} / ${div}"
                } else {
                    "${multiplier} * ${exprCss}"
                }
            }
            case Function => {
                match (functionKind) {
                    case Some(f) => "${f.toCss()}(...)"
                    case None => ""
                }
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 数学函数
// 严格翻译自: values/calc.rs MathFunction<V> enum
// ============================================================================

/// CSS 数学函数
/// 严格翻译自 MathFunction enum { Calc, Min, Max, Clamp, Round, Rem, Mod, Abs, Sign, Hypot }
public class CssMathFunction {
    public enum CssMathFunctionKind {
        | Calc       // calc()
        | Min        // min()
        | Max        // max()
        | Clamp      // clamp()
        | Round      // round()
        | Rem        // rem()
        | Mod        // mod()
        | Abs        // abs()
        | Sign       // sign()
        | Hypot      // hypot()
    }

    public var kind: CssMathFunctionKind
    /// calc 表达式
    public var calc: ?CssCalc
    /// 参数列表 (Min, Max, Hypot)
    public var args: ArrayList<CssCalc>
    /// clamp 最小值
    public var clampMin: ?CssCalc
    /// clamp 中心值
    public var clampCenter: ?CssCalc
    /// clamp 最大值
    public var clampMax: ?CssCalc
    /// round 策略
    public var roundStrategy: CssRoundingStrategy
    /// round 值
    public var roundValue: ?CssCalc
    /// round 间隔
    public var roundInterval: ?CssCalc
    /// rem/mod 被除数
    public var dividend: ?CssCalc
    /// rem/mod 除数
    public var divisor: ?CssCalc

    public init(calc: CssCalc) {
        this.kind = CssMathFunctionKind.Calc
        this.calc = Some(calc)
        this.args = ArrayList<CssCalc>()
        this.clampMin = None
        this.clampCenter = None
        this.clampMax = None
        this.roundStrategy = CssRoundingStrategy.Nearest
        this.roundValue = None
        this.roundInterval = None
        this.dividend = None
        this.divisor = None
    }

    public init(min: ArrayList<CssCalc>) {
        this.kind = CssMathFunctionKind.Min
        this.calc = None
        this.args = min
        this.clampMin = None
        this.clampCenter = None
        this.clampMax = None
        this.roundStrategy = CssRoundingStrategy.Nearest
        this.roundValue = None
        this.roundInterval = None
        this.dividend = None
        this.divisor = None
    }

    public init(max: ArrayList<CssCalc>, isMax: Bool) {
        this.kind = CssMathFunctionKind.Max
        this.calc = None
        this.args = max
        this.clampMin = None
        this.clampCenter = None
        this.clampMax = None
        this.roundStrategy = CssRoundingStrategy.Nearest
        this.roundValue = None
        this.roundInterval = None
        this.dividend = None
        this.divisor = None
    }

    /// 转为 CSS 文本
    /// 严格翻译自 MathFunction.to_css
    public func toCss(): String {
        match (kind) {
            case Calc => {
                match (calc) {
                    case Some(c) => "calc(${c.toCss()})"
                    case None => "calc()"
                }
            }
            case Min => {
                let parts = ArrayList<String>()
                for (a in args) { parts.append(a.toCss()) }
                "min(${String.join(", ", parts)})"
            }
            case Max => {
                let parts = ArrayList<String>()
                for (a in args) { parts.append(a.toCss()) }
                "max(${String.join(", ", parts)})"
            }
            case Clamp => {
                let minStr = match (clampMin) { case Some(c) => c.toCss() case None => "" }
                let centerStr = match (clampCenter) { case Some(c) => c.toCss() case None => "" }
                let maxStr = match (clampMax) { case Some(c) => c.toCss() case None => "" }
                "clamp(${minStr}, ${centerStr}, ${maxStr})"
            }
            case Round => {
                let valStr = match (roundValue) { case Some(c) => c.toCss() case None => "" }
                let intStr = match (roundInterval) { case Some(c) => c.toCss() case None => "" }
                "round(${roundStrategy.toCss()}, ${valStr}, ${intStr})"
            }
            case Rem => {
                let d1 = match (dividend) { case Some(c) => c.toCss() case None => "" }
                let d2 = match (divisor) { case Some(c) => c.toCss() case None => "" }
                "rem(${d1}, ${d2})"
            }
            case Mod => {
                let d1 = match (dividend) { case Some(c) => c.toCss() case None => "" }
                let d2 = match (divisor) { case Some(c) => c.toCss() case None => "" }
                "mod(${d1}, ${d2})"
            }
            case Abs => {
                match (calc) {
                    case Some(c) => "abs(${c.toCss()})"
                    case None => "abs()"
                }
            }
            case Sign => {
                match (calc) {
                    case Some(c) => "sign(${c.toCss()})"
                    case None => "sign()"
                }
            }
            case Hypot => {
                let parts = ArrayList<String>()
                for (a in args) { parts.append(a.toCss()) }
                "hypot(${String.join(", ", parts)})"
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}
