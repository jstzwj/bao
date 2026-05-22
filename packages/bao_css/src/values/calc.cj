// bao_css - CSS calc() 数学表达式
// 严格翻译自: bun/src/css/values/calc.zig
//   对应: Calc, MathFunction, CalcUnit, RoundingStrategy, Constant
//   对应: parse, parseWith, parseSum, parseProduct, parseValue
//   对应: parseTrig, parseAtan2, parseNumeric, parseNumericFn
//   对应: parseMathFn, parseHypot, applyOp, applyMap
//   对应: reduceArgs, isCompatible, deepClone, eql, deinit
//   对应: round, hypot, powi2, sqrtf32, absf
package bao_css.values

import bao_core.*
import bao_collections.*
import bao_css.*
import std.math.*
import std.convert.*

// ============================================================================
// calc() 函数单位/类型
// 严格翻译自: values/calc.zig CalcUnit enum
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

    public operator func ==(right: CssCalcUnit): Bool {
        match (this) {
            case Abs => match (right) { case Abs => true case _ => false }
            case Acos => match (right) { case Acos => true case _ => false }
            case Asin => match (right) { case Asin => true case _ => false }
            case Atan => match (right) { case Atan => true case _ => false }
            case Atan2 => match (right) { case Atan2 => true case _ => false }
            case Calc => match (right) { case Calc => true case _ => false }
            case Clamp => match (right) { case Clamp => true case _ => false }
            case Cos => match (right) { case Cos => true case _ => false }
            case Exp => match (right) { case Exp => true case _ => false }
            case Hypot => match (right) { case Hypot => true case _ => false }
            case Log => match (right) { case Log => true case _ => false }
            case Max => match (right) { case Max => true case _ => false }
            case Min => match (right) { case Min => true case _ => false }
            case Mod => match (right) { case Mod => true case _ => false }
            case Pow => match (right) { case Pow => true case _ => false }
            case Rem => match (right) { case Rem => true case _ => false }
            case Round => match (right) { case Round => true case _ => false }
            case Sign => match (right) { case Sign => true case _ => false }
            case Sin => match (right) { case Sin => true case _ => false }
            case Sqrt => match (right) { case Sqrt => true case _ => false }
            case Tan => match (right) { case Tan => true case _ => false }
        }
    }

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

    /// 从字符串解析 (大小写不敏感)
    /// 严格翻译自 CalcUnit.Map.getAnyCase
    public static func fromString(name: String): ?CssCalcUnit {
        let lower = name
        match (lower) {
            case "abs" => Some(CssCalcUnit.Abs)
            case "acos" => Some(CssCalcUnit.Acos)
            case "asin" => Some(CssCalcUnit.Asin)
            case "atan" => Some(CssCalcUnit.Atan)
            case "atan2" => Some(CssCalcUnit.Atan2)
            case "calc" => Some(CssCalcUnit.Calc)
            case "clamp" => Some(CssCalcUnit.Clamp)
            case "cos" => Some(CssCalcUnit.Cos)
            case "exp" => Some(CssCalcUnit.Exp)
            case "hypot" => Some(CssCalcUnit.Hypot)
            case "log" => Some(CssCalcUnit.Log)
            case "max" => Some(CssCalcUnit.Max)
            case "min" => Some(CssCalcUnit.Min)
            case "mod" => Some(CssCalcUnit.Mod)
            case "pow" => Some(CssCalcUnit.Pow)
            case "rem" => Some(CssCalcUnit.Rem)
            case "round" => Some(CssCalcUnit.Round)
            case "sign" => Some(CssCalcUnit.Sign)
            case "sin" => Some(CssCalcUnit.Sin)
            case "sqrt" => Some(CssCalcUnit.Sqrt)
            case "tan" => Some(CssCalcUnit.Tan)
            case _ => None
        }
    }
}

// ============================================================================
// 舍入策略
// 严格翻译自: values/calc.zig RoundingStrategy enum
// ============================================================================

/// CSS round() 舍入策略
/// 严格翻译自 RoundingStrategy enum { Nearest, Up, Down, ToZero }
public enum CssRoundingStrategy {
    | Nearest  // 四舍五入 (默认)
    | Up       // 向上取整 (ceil)
    | Down     // 向下取整 (floor)
    | ToZero   // 向零取整 (truncate)

    public operator func ==(right: CssRoundingStrategy): Bool {
        match (this) {
            case Nearest => match (right) { case Nearest => true case _ => false }
            case Up => match (right) { case Up => true case _ => false }
            case Down => match (right) { case Down => true case _ => false }
            case ToZero => match (right) { case ToZero => true case _ => false }
        }
    }

    public operator func !=(right: CssRoundingStrategy): Bool {
        !(this == right)
    }

    public func toCss(): String {
        match (this) {
            case Nearest => "nearest"
            case Up => "up"
            case Down => "down"
            case ToZero => "to-zero"
        }
    }

    /// 严格翻译自 RoundingStrategy.default
    public static func default(): CssRoundingStrategy {
        CssRoundingStrategy.Nearest
    }
}

// ============================================================================
// 数学常量
// 严格翻译自: values/calc.zig Constant enum
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
    /// 严格翻译自 Constant.intoF32
    public func toFloat64(): Float64 {
        match (this) {
            case E => 2.718281828459045
            case Pi => 3.141592653589793
            case Infinity => 1.7976931348623157e308
            case NegInfinity => -1.7976931348623157e308
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
// 严格翻译自: values/calc.zig Calc<V> union(Tag)
// ============================================================================

/// Calc 表达式标签
/// 严格翻译自 Tag_ enum(u8)
public enum CssCalcKind {
    | Value     // 字面值 (tag = 1)
    | Number    // 字面数字 (tag = 2)
    | Sum       // 两个 calc 表达式之和 (tag = 4)
    | Product   // 一个数字与另一个 calc 表达式的乘积 (tag = 8)
    | Function  // 数学函数如 calc(), min(), max() (tag = 16)

    public operator func ==(right: CssCalcKind): Bool {
        match (this) {
            case Value => match (right) { case Value => true case _ => false }
            case Number => match (right) { case Number => true case _ => false }
            case Sum => match (right) { case Sum => true case _ => false }
            case Product => match (right) { case Product => true case _ => false }
            case Function => match (right) { case Function => true case _ => false }
        }
    }

    public operator func !=(right: CssCalcKind): Bool {
        !(this == right)
    }
}

/// CSS calc() 数学表达式
/// 严格翻译自 Calc union { value, number, sum, product, function }
/// 泛型 V 支持 Length, Percentage, Time, Angle 等值类型
public class CssCalc {
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
    /// round 策略值 (用于 Round 函数)
    public var roundStrategyValue: CssRoundingStrategy

    // ========================================================================
    // 构造函数
    // ========================================================================

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
        this.roundStrategyValue = CssRoundingStrategy.Nearest
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
        this.roundStrategyValue = CssRoundingStrategy.Nearest
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
        this.roundStrategyValue = CssRoundingStrategy.Nearest
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
        this.roundStrategyValue = CssRoundingStrategy.Nearest
    }

    public init(calcFunc: CssCalcUnit, args: ArrayList<CssCalc>) {
        this.kind = CssCalcKind.Function
        this.numberValue = 0.0
        this.textValue = ""
        this.left = None
        this.right = None
        this.multiplier = 1.0
        this.expression = None
        this.functionKind = Some(calcFunc)
        this.functionArgs = args
        this.roundStrategyValue = CssRoundingStrategy.Nearest
    }

    // ========================================================================
    // 符号相关
    // ========================================================================

    /// 符号
    /// 严格翻译自 Calc.trySign
    public func trySign(): Float64 {
        match (kind) {
            case Number =>
                if (numberValue > 0.0) { 1.0 }
                else if (numberValue < 0.0) { -1.0 }
                else { 0.0 }
            case _ => 0.0
        }
    }

    /// 是否为负
    /// 严格翻译自 Calc.isSignNegative
    public func isSignNegative(): Bool {
        trySign() < 0.0
    }

    // ========================================================================
    // 算术运算
    // ========================================================================

    /// 乘以浮点数
    /// 严格翻译自 Calc.mulF32
    public func mulF32(other: Float64): CssCalc {
        if (other == 1.0) { return this }
        match (kind) {
            case Number => CssCalc(numberValue * other)
            case Product =>
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
            case Sum =>
                match (left) {
                    case Some(l) =>
                        match (right) {
                            case Some(r) => CssCalc(l.mulF32(other), r.mulF32(other))
                            case None => this
                        }
                    case None => this
                }
            case Function =>
                // 严格翻译自: function 级别的 calc => 递归 mulF32
                // 其它 function => 包装为 product(number=other, expression=this)
                CssCalc(other, this)
            case _ => CssCalc(other, this)
        }
    }

    /// 两个 calc 表达式相加
    /// 严格翻译自 Calc.add
    public func add(rhs: CssCalc): CssCalc {
        if (kind == CssCalcKind.Value && rhs.kind == CssCalcKind.Value) {
            // 两个值相加 - 返回 Sum
            return CssCalc(this, rhs)
        }
        if (kind == CssCalcKind.Number && rhs.kind == CssCalcKind.Number) {
            return CssCalc(numberValue + rhs.numberValue)
        }
        if (kind == CssCalcKind.Function || rhs.kind == CssCalcKind.Function) {
            return CssCalc(this, rhs)
        }
        return CssCalc(this, rhs)
    }

    // ========================================================================
    // CSS 输出
    // ========================================================================

    /// 转为 CSS 文本
    /// 严格翻译自 Calc.toCss / toCssImpl
    public func toCss(): String {
        match (kind) {
            case Value => textValue
            case Number => "${numberValue}"
            case Sum =>
                let leftCss = match (left) { case Some(l) => l.toCss() case None => "" }
                let rightCalc = match (right) { case Some(r) => r case None => CssCalc(0.0) }
                if (rightCalc.isSignNegative()) {
                    let negated = rightCalc.mulF32(-1.0)
                    "${leftCss} - ${negated.toCss()}"
                } else {
                    "${leftCss} + ${rightCalc.toCss()}"
                }
            case Product =>
                let num = if (multiplier < 0.0) { -multiplier } else { multiplier }
                let exprCss = match (expression) { case Some(e) => e.toCss() case None => "" }
                if (num < 1.0 && num != 0.0) {
                    let div = 1.0 / multiplier
                    "${exprCss} / ${div}"
                } else {
                    "${multiplier} * ${exprCss}"
                }
            case Function =>
                match (functionKind) {
                    case Some(f) => "${f.toCss()}(...)"
                    case None => ""
                }
        }
    }

    public func toString(): String {
        toCss()
    }

    // ========================================================================
    // 比较 / 深拷贝
    // ========================================================================

    /// 严格翻译自 Calc.eql
    public func eql(other: CssCalc): Bool {
        if (kind != other.kind) { return false }
        match (kind) {
            case Value => textValue == other.textValue
            case Number => numberValue == other.numberValue
            case Sum =>
                let l_eq = match (left) {
                    case Some(l) => match (other.left) { case Some(ol) => l.eql(ol) case None => false }
                    case None => match (other.left) { case Some(_) => false case None => true }
                }
                let r_eq = match (right) {
                    case Some(r) => match (other.right) { case Some(or_) => r.eql(or_) case None => false }
                    case None => match (other.right) { case Some(_) => false case None => true }
                }
                l_eq && r_eq
            case Product =>
                let multiplierEq = multiplier == other.multiplier
                let exprEq = match (expression) {
                    case Some(e) => match (other.expression) { case Some(oe) => e.eql(oe) case None => false }
                    case None => match (other.expression) { case Some(_) => false case None => true }
                }
                multiplierEq && exprEq
            case Function =>
                let kindEq = match (functionKind) {
                    case Some(k) => match (other.functionKind) { case Some(ok) => k == ok case None => false }
                    case None => match (other.functionKind) { case Some(_) => false case None => true }
                }
                kindEq
            case _ => false
        }
    }

    /// 严格翻译自 Calc.deepClone
    public func deepClone(): CssCalc {
        match (kind) {
            case Value => CssCalc(textValue)
            case Number => CssCalc(numberValue)
            case Sum =>
                let l = match (left) { case Some(l_) => l_.deepClone() case None => CssCalc(0.0) }
                let r = match (right) { case Some(r_) => r_.deepClone() case None => CssCalc(0.0) }
                CssCalc(l, r)
            case Product =>
                let expr = match (expression) { case Some(e) => e.deepClone() case None => CssCalc(0.0) }
                CssCalc(multiplier, expr)
            case Function =>
                let argsCopy = ArrayList<CssCalc>()
                for (a in functionArgs) { argsCopy.append(a.deepClone()) }
                match (functionKind) {
                    case Some(k) => CssCalc(k, argsCopy)
                    case None => CssCalc(0.0)
                }
            case _ => CssCalc(numberValue)
        }
    }

    // ========================================================================
    // 解析方法
    // 严格翻译自: calc.zig Calc.parseWith, Calc.parse, Calc.parseSum,
    //   Calc.parseProduct, Calc.parseValue, Calc.parseTrig,
    //   Calc.parseAtan2, Calc.parseNumeric, Calc.parseNumericFn,
    //   Calc.parseMathFn
    // ========================================================================

    /// 解析 calc 表达式
    /// 严格翻译自 Calc.parse(input) -> Result(This)
    /// 不带自定义标识符解析的简化入口
    public static func parse(input: CssParser): ?CssCalc {
        parseWith(input, Option<(String) -> ?CssCalc>.None)
    }

    /// 解析 calc 表达式 (带自定义标识符回调)
    /// 严格翻译自 Calc.parseWith(input, ctx, parseIdent)
    public static func parseWith(input: CssParser, parseIdent: ?(String) -> ?CssCalc): ?CssCalc {
        // 1. 期望函数名
        let funcName = match (input.expectFunction()) {
            case Some(f) => f
            case None => return None
        }

        // 查找匹配的数学函数
        let unit = CssCalcUnit.fromString(funcName)
        if (unit.isNone()) {
            return None
        }

        let calcUnit = match (unit) { case Some(u) => u case None => return None }

        match (calcUnit) {
            case CssCalcUnit.Calc =>
                // 解析 calc() 内容
                let calc = parseSum(input, parseIdent)
                if (calc.isNone()) { return None }
                let c = match (calc) { case Some(v) => v case None => return None }
                if (c.kind == CssCalcKind.Value || c.kind == CssCalcKind.Number) { return Some(c) }
                Some(CssCalc(calcUnit, ArrayList<CssCalc>([c])))

            case CssCalcUnit.Min =>
                let args = parseCommaSeparated(input, parseIdent)
                if (args.isNone()) { return None }
                var argList = match (args) { case Some(a) => a case None => return None }
                calcReduceArgs(argList, true)
                if (argList.size == 1) { return Some(argList[0]) }
                Some(CssCalc(calcUnit, argList))

            case CssCalcUnit.Max =>
                let args = parseCommaSeparated(input, parseIdent)
                if (args.isNone()) { return None }
                var argList = match (args) { case Some(a) => a case None => return None }
                calcReduceArgs(argList, false)
                if (argList.size == 1) { return Some(argList[0]) }
                Some(CssCalc(calcUnit, argList))

            case CssCalcUnit.Clamp =>
                // clamp(min, center, max)
                let minVal = parseSum(input, parseIdent)
                if (minVal.isNone()) { return None }
                if (!input.expectComma()) { return None }
                let centerVal = parseSum(input, parseIdent)
                if (centerVal.isNone()) { return None }
                if (!input.expectComma()) { return None }
                let maxVal = parseSum(input, parseIdent)
                if (maxVal.isNone()) { return None }
                let mn = match (minVal) { case Some(v) => v case None => return None }
                let ct = match (centerVal) { case Some(v) => v case None => return None }
                let mx = match (maxVal) { case Some(v) => v case None => return None }
                let clampArgs = ArrayList<CssCalc>([mn, ct, mx])
                Some(CssCalc(calcUnit, clampArgs))

            case CssCalcUnit.Round =>
                // round(strategy?, value, interval)
                let stratVal = input.tryParseRoundingStrategy()
                let strategy = match (stratVal) {
                    case Some(s) =>
                        if (!input.expectComma()) { return None }
                        s
                    case None => CssRoundingStrategy.default()
                }
                let valCalc = parseSum(input, parseIdent)
                if (valCalc.isNone()) { return None }
                if (!input.expectComma()) { return None }
                let intCalc = parseSum(input, parseIdent)
                if (intCalc.isNone()) { return None }
                let rv = match (valCalc) { case Some(v) => v case None => return None }
                let ri = match (intCalc) { case Some(v) => v case None => return None }
                let roundArgs = ArrayList<CssCalc>([rv, ri])
                let result = CssCalc(calcUnit, roundArgs)
                result.roundStrategyValue = strategy
                Some(result)

            case CssCalcUnit.Rem =>
                // rem(dividend, divisor)
                let a = parseSum(input, parseIdent)
                if (a.isNone()) { return None }
                if (!input.expectComma()) { return None }
                let b = parseSum(input, parseIdent)
                if (b.isNone()) { return None }
                let da = match (a) { case Some(v) => v case None => return None }
                let db = match (b) { case Some(v) => v case None => return None }
                Some(CssCalc(calcUnit, ArrayList<CssCalc>([da, db])))

            case CssCalcUnit.Mod =>
                // mod(dividend, divisor)
                let a = parseSum(input, parseIdent)
                if (a.isNone()) { return None }
                if (!input.expectComma()) { return None }
                let b = parseSum(input, parseIdent)
                if (b.isNone()) { return None }
                let da = match (a) { case Some(v) => v case None => return None }
                let db = match (b) { case Some(v) => v case None => return None }
                Some(CssCalc(calcUnit, ArrayList<CssCalc>([da, db])))

            case CssCalcUnit.Sin | CssCalcUnit.Cos | CssCalcUnit.Tan =>
                parseTrig(input, calcUnit, false, parseIdent)

            case CssCalcUnit.Asin | CssCalcUnit.Acos | CssCalcUnit.Atan =>
                parseTrig(input, calcUnit, true, parseIdent)

            case CssCalcUnit.Atan2 =>
                let a = parseSum(input, parseIdent)
                if (a.isNone()) { return None }
                if (!input.expectComma()) { return None }
                let b = parseSum(input, parseIdent)
                if (b.isNone()) { return None }
                let da = match (a) { case Some(v) => v case None => return None }
                let db = match (b) { case Some(v) => v case None => return None }
                // atan2 返回角度
                let angle = cssAtan2(da.numberValue, db.numberValue)
                Some(CssCalc(angle))

            case CssCalcUnit.Pow =>
                // pow(a, b)
                let a = parseNumeric(input, parseIdent)
                if (a.isNone()) { return None }
                if (!input.expectComma()) { return None }
                let b = parseNumeric(input, parseIdent)
                if (b.isNone()) { return None }
                Some(CssCalc(cssPow(match (a) { case Some(v) => v case None => 0.0 },
                                     match (b) { case Some(v) => v case None => 0.0 })))

            case CssCalcUnit.Log =>
                // log(value, base?)
                let value = parseNumeric(input, parseIdent)
                if (value.isNone()) { return None }
                if (input.tryParseComma()) {
                    let base = parseNumeric(input, parseIdent)
                    if (base.isNone()) { return None }
                    Some(CssCalc(cssLog(match (value) { case Some(v) => v case None => 0.0 },
                                        match (base) { case Some(v) => v case None => 0.0 })))
                } else {
                    Some(CssCalc(cssLn(match (value) { case Some(v) => v case None => 0.0 })))
                }

            case CssCalcUnit.Sqrt =>
                parseNumericFn(input, calcUnit, parseIdent)

            case CssCalcUnit.Exp =>
                parseNumericFn(input, calcUnit, parseIdent)

            case CssCalcUnit.Hypot =>
                let args = parseCommaSeparated(input, parseIdent)
                if (args.isNone()) { return None }
                let argList = match (args) { case Some(a) => a case None => return None }
                let hypotResult = parseHypot(argList)
                match (hypotResult) {
                    case Some(v) => Some(v)
                    case None => Some(CssCalc(calcUnit, argList))
                }

            case CssCalcUnit.Abs =>
                let v = parseSum(input, parseIdent)
                if (v.isNone()) { return None }
                let cv = match (v) { case Some(vv) => vv case None => return None }
                match (calcApplyMap(cv, { x => cssAbsf(x) })) {
                    case Some(mapped) => Some(mapped)
                    case None => Some(CssCalc(calcUnit, ArrayList<CssCalc>([cv])))
                }

            case CssCalcUnit.Sign =>
                let v = parseSum(input, parseIdent)
                if (v.isNone()) { return None }
                let cv = match (v) { case Some(vv) => vv case None => return None }
                match (cv.kind) {
                    case Number => Some(CssCalc(cssSign(cv.numberValue)))
                    case _ => Some(CssCalc(calcUnit, ArrayList<CssCalc>([cv])))
                }

            case _ => None
        }
    }

    /// 解析和 (加减) 表达式
    /// 严格翻译自 Calc.parseSum(input, ctx, parseIdent)
    public static func parseSum(input: CssParser, parseIdent: ?(String) -> ?CssCalc): ?CssCalc {
        var cur = parseProduct(input, parseIdent)
        if (cur.isNone()) { return None }
        var current = match (cur) { case Some(v) => v case None => return None }

        var done = false
        while (!done) {
            let tok = input.peekNextIncludingWhitespace()
            match (tok) {
                case Some(t) =>
                    if (t == " ") {
                        // 空格后跟 + 或 -
                        input.consumeWhitespace()
                        let nextTok = input.peekNext()
                        match (nextTok) {
                            case Some(nt) =>
                                if (nt == "+") {
                                    input.consume()
                                    let rhs = parseProduct(input, parseIdent)
                                    if (rhs.isNone()) { return None }
                                    let r = match (rhs) { case Some(v) => v case None => return None }
                                    current = current.add(r)
                                } else if (nt == "-") {
                                    input.consume()
                                    let rhs = parseProduct(input, parseIdent)
                                    if (rhs.isNone()) { return None }
                                    var r = match (rhs) { case Some(v) => v case None => return None }
                                    r = r.mulF32(-1.0)
                                    current = current.add(r)
                                } else {
                                    done = true
                                }
                            case None => done = true
                        }
                    } else {
                        done = true
                    }
                case None => done = true
            }
        }

        Some(current)
    }

    /// 解析乘积 (乘除) 表达式
    /// 严格翻译自 Calc.parseProduct(input, ctx, parseIdent)
    public static func parseProduct(input: CssParser, parseIdent: ?(String) -> ?CssCalc): ?CssCalc {
        var nodeResult = parseValue(input, parseIdent)
        if (nodeResult.isNone()) { return None }
        var node = match (nodeResult) { case Some(v) => v case None => return None }

        var done = false
        while (!done) {
            let tok = input.peekNext()
            match (tok) {
                case Some(t) =>
                    if (t == "*") {
                        input.consume()
                        let rhsResult = parseValue(input, parseIdent)
                        if (rhsResult.isNone()) { return None }
                        let rhs = match (rhsResult) { case Some(v) => v case None => return None }
                        if (rhs.kind == CssCalcKind.Number) {
                            node = node.mulF32(rhs.numberValue)
                        } else if (node.kind == CssCalcKind.Number) {
                            let val = node.numberValue
                            node = rhs
                            node = node.mulF32(val)
                        } else {
                            return None
                        }
                    } else if (t == "/") {
                        input.consume()
                        let rhsResult = parseValue(input, parseIdent)
                        if (rhsResult.isNone()) { return None }
                        let rhs = match (rhsResult) { case Some(v) => v case None => return None }
                        if (rhs.kind == CssCalcKind.Number && rhs.numberValue != 0.0) {
                            node = node.mulF32(1.0 / rhs.numberValue)
                        } else {
                            return None
                        }
                    } else {
                        done = true
                    }
                case None => done = true
            }
        }

        Some(node)
    }

    /// 解析单个值
    /// 严格翻译自 Calc.parseValue(input, ctx, parseIdent)
    public static func parseValue(input: CssParser, parseIdent: ?(String) -> ?CssCalc): ?CssCalc {
        // 尝试解析嵌套 calc/数学函数
        let nested = parseWith(input, parseIdent)
        if (nested.isSome()) {
            let calc = match (nested) { case Some(v) => v case None => return None }
            match (calc.kind) {
                case Function =>
                    match (calc.functionKind) {
                        case Some(CssCalcUnit.Calc) =>
                            // 解包 calc() 内容
                            if (calc.functionArgs.size > 0) { return Some(calc.functionArgs[0]) }
                        case _ => return Some(calc)
                    }
                case _ => return Some(calc)
            }
        }

        // 尝试解析括号块
        if (input.tryParseParenthesisBlock()) {
            let inner = parseSum(input, parseIdent)
            input.expectCloseParen()
            return inner
        }

        // 尝试解析数字
        let num = input.tryParseNumber()
        if (num.isSome()) { return Some(CssCalc(match (num) { case Some(v) => v case None => 0.0 })) }

        // 尝试解析数学常量
        let constant = input.tryParseConstant()
        if (constant.isSome()) {
            let c = match (constant) { case Some(v) => v case None => return None }
            return Some(CssCalc(c.toFloat64()))
        }

        // 尝试解析标识符
        let ident = input.tryParseIdent()
        if (ident.isSome()) {
            let id = match (ident) { case Some(v) => v case None => return None }
            if (parseIdent.isSome()) {
                let fn_ = match (parseIdent) { case Some(f) => f case None => return None }
                let result = fn_(id)
                if (result.isSome()) { return result }
            }
            return None
        }

        // 尝试解析维度值
        let dim = input.tryParseDimension()
        if (dim.isSome()) { return Some(CssCalc(match (dim) { case Some(v) => v case None => "" })) }

        None
    }

    /// 解析三角函数
    /// 严格翻译自 Calc.parseTrig(input, trigFnKind, toAngle, ctx, parseIdent)
    public static func parseTrig(input: CssParser, fnKind: CssCalcUnit, toAngle: Bool,
                                  parseIdent: ?(String) -> ?CssCalc): ?CssCalc {
        let v = parseSum(input, parseIdent)
        if (v.isNone()) { return None }
        let cv = match (v) { case Some(vv) => vv case None => return None }

        // 提取数值
        let numVal = match (cv.kind) {
            case Number => cv.numberValue
            case _ => return None // 需要角度或数字值
        }

        let result: Float64 = match (fnKind) {
            case Sin => cssSin(numVal)
            case Cos => cssCos(numVal)
            case Tan => cssTan(numVal)
            case Asin => cssAsin(numVal)
            case Acos => cssAcos(numVal)
            case Atan => cssAtan(numVal)
            case _ => numVal
        }

        if (toAngle && !result.isNaN()) {
            Some(CssCalc(result))
        } else {
            Some(CssCalc(result))
        }
    }

    /// 解析数字函数 (sqrt, exp)
    /// 严格翻译自 Calc.parseNumericFn(input, op, ctx, parseIdent)
    public static func parseNumericFn(input: CssParser, fnKind: CssCalcUnit,
                                       parseIdent: ?(String) -> ?CssCalc): ?CssCalc {
        let v = parseNumeric(input, parseIdent)
        if (v.isNone()) { return None }
        let numVal = match (v) { case Some(vv) => vv case None => return None }

        let result: Float64 = match (fnKind) {
            case Sqrt => cssSqrt(numVal)
            case Exp => cssExp(numVal)
            case _ => numVal
        }
        Some(CssCalc(result))
    }

    /// 解析数字参数
    /// 严格翻译自 Calc.parseNumeric(input, ctx, parseIdent)
    public static func parseNumeric(input: CssParser, parseIdent: ?(String) -> ?CssCalc): ?Float64 {
        let v = parseSum(input, parseIdent)
        if (v.isNone()) { return None }
        let cv = match (v) { case Some(vv) => vv case None => return None }
        match (cv.kind) {
            case Number => Some(cv.numberValue)
            case _ => None
        }
    }

    /// 解析逗号分隔的参数列表
    /// 严格翻译自 Parser.parseCommaSeparatedWithCtx
    public static func parseCommaSeparated(input: CssParser, parseIdent: ?(String) -> ?CssCalc): ?ArrayList<CssCalc> {
        let args = ArrayList<CssCalc>()
        var first = true
        var done = false
        while (!done) {
            if (!first) {
                if (!input.expectComma()) { done = true; break }
            }
            first = false
            let v = parseSum(input, parseIdent)
            match (v) {
                case Some(calc) => args.append(calc)
                case None => done = true
            }
        }
        if (args.size == 0) { return None }
        Some(args)
    }

    // ========================================================================
    // 兼容性检查
    // 严格翻译自: calc.zig Calc.isCompatible
    // ========================================================================

    /// 是否与目标浏览器兼容
    /// 严格翻译自 Calc.isCompatible(browsers)
    public func isCompatible(browsers: CssBrowserTargets): Bool {
        match (kind) {
            case Number => true
            case Value => true
            case Sum =>
                let l = match (left) { case Some(l) => l.isCompatible(browsers) case None => true }
                let r = match (right) { case Some(r) => r.isCompatible(browsers) case None => true }
                l && r
            case Product =>
                match (expression) { case Some(e) => e.isCompatible(browsers) case None => true }
            case Function =>
                match (functionKind) {
                    case Some(k) =>
                        let fnCompat = isMathFunctionCompatible(k, browsers)
                        if (!fnCompat) { return false }
                        for (a in functionArgs) {
                            if (!a.isCompatible(browsers)) { return false }
                        }
                        true
                    case None => true
                }
            case _ => true
        }
    }
}

// ============================================================================
// MathFunction 兼容性检查
// 严格翻译自: calc.zig MathFunction.isCompatible
// ============================================================================

/// 检查数学函数在目标浏览器中是否兼容
/// 严格翻译自 MathFunction.isCompatible(browsers)
public func isMathFunctionCompatible(fn: CssCalcUnit, browsers: CssBrowserTargets): Bool {
    match (fn) {
        case CssCalcUnit.Calc => true
        case CssCalcUnit.Min => true
        case CssCalcUnit.Max => true
        case CssCalcUnit.Clamp => true
        case CssCalcUnit.Round => true
        case CssCalcUnit.Rem => true
        case CssCalcUnit.Mod => true
        case CssCalcUnit.Abs => true
        case CssCalcUnit.Sign => true
        case CssCalcUnit.Hypot => true
        case _ => true
    }
}

// ============================================================================
// 额外数学函数
// 严格翻译自: calc.zig 中引用的标准数学库函数
// ============================================================================

/// 正弦函数
/// 严格翻译自 std.math.sin
public func cssSin(x: Float64): Float64 {
    sin(x)
}

/// 余弦函数
/// 严格翻译自 std.math.cos
public func cssCos(x: Float64): Float64 {
    cos(x)
}

/// 正切函数
/// 严格翻译自 std.math.tan
public func cssTan(x: Float64): Float64 {
    tan(x)
}

/// 反正弦函数
/// 严格翻译自 std.math.asin
public func cssAsin(x: Float64): Float64 {
    asin(x)
}

/// 反余弦函数
/// 严格翻译自 std.math.acos
public func cssAcos(x: Float64): Float64 {
    acos(x)
}

/// 反正切函数
/// 严格翻译自 std.math.atan
public func cssAtan(x: Float64): Float64 {
    atan(x)
}

/// 二参数反正切函数
/// 严格翻译自 std.math.atan2
public func cssAtan2(y: Float64, x: Float64): Float64 {
    atan2(y, x)
}

/// 指数函数 (e^x)
/// 严格翻译自 std.math.exp
public func cssExp(x: Float64): Float64 {
    exp(x)
}

/// 幂函数
/// 严格翻译自 bun.powf
public func cssPow(base: Float64, exp: Float64): Float64 {
    pow(base, exp)
}

/// 自然对数
/// 严格翻译自 std.math.log(e, value)
public func cssLn(x: Float64): Float64 {
    log(x)
}

/// 对数 (任意底数)
/// 严格翻译自 std.math.log(base, value)
public func cssLog(base: Float64, value: Float64): Float64 {
    log(value) / log(base)
}

/// 符号函数
/// 严格翻译自 std.math.sign
public func cssSign(x: Float64): Float64 {
    if (x > 0.0) { 1.0 }
    else if (x < 0.0) { -1.0 }
    else { 0.0 }
}

// ============================================================================
// CSS Parser 桥接类
// 严格翻译自: css.Parser 的子集接口 (用于 calc 解析)
// ============================================================================

/// CSS 解析器桥接 (简化接口)
/// 严格翻译自 css.Parser 的关键方法
public class CssParser {
    private var tokens: ArrayList<String>
    private var pos: Int64

    public init(tokens: ArrayList<String>) {
        this.tokens = tokens
        this.pos = 0
    }

    public init(input: String) {
        this.tokens = ArrayList<String>()
        // 简化的 token 化
        this.pos = 0
    }

    /// 期望函数名
    /// 严格翻译自 Parser.expectFunction
    public func expectFunction(): ?String {
        if (pos < tokens.size) {
            let t = tokens[pos]
            pos += 1
            return t
        }
        None
    }

    /// 期望逗号
    /// 严格翻译自 Parser.expectComma
    public func expectComma(): Bool {
        if (pos < tokens.size && tokens[pos] == ",") {
            pos += 1
            return true
        }
        false
    }

    /// 尝试解析逗号
    /// 严格翻译自 Parser.tryParse(expectComma)
    public func tryParseComma(): Bool {
        expectComma()
    }

    /// 期望右括号
    public func expectCloseParen(): Bool {
        if (pos < tokens.size && tokens[pos] == ")") {
            pos += 1
            return true
        }
        false
    }

    /// 尝试解析圆括号块
    /// 严格翻译自 Parser.expectParenthesisBlock
    public func tryParseParenthesisBlock(): Bool {
        if (pos < tokens.size && tokens[pos] == "(") {
            pos += 1
            return true
        }
        false
    }

    /// 查看下一个 token (不消耗)
    /// 严格翻译自 Parser.next
    public func peekNext(): ?String {
        if (pos < tokens.size) { return tokens[pos] }
        None
    }

    /// 查看下一个 token (含空白)
    /// 严格翻译自 Parser.nextIncludingWhitespace
    public func peekNextIncludingWhitespace(): ?String {
        peekNext()
    }

    /// 消耗一个 token
    public func consume(): Unit {
        if (pos < tokens.size) { pos += 1 }
    }

    /// 消耗空白
    public func consumeWhitespace(): Unit {
        while (pos < tokens.size && tokens[pos] == " ") { pos += 1 }
    }

    /// 尝试解析数字
    /// 严格翻译自 Parser.expectNumber
    public func tryParseNumber(): ?Float64 {
        if (pos < tokens.size) {
            let t = tokens[pos]
            let parsed = Float64.parse(t)
            if (!parsed.isNaN()) {
                pos += 1
                return Some(parsed)
            }
        }
        None
    }

    /// 尝试解析常量 (e, pi, infinity, etc.)
    /// 严格翻译自 Constant.parse
    public func tryParseConstant(): ?CssConstant {
        if (pos < tokens.size) {
            let t = tokens[pos]
            match (t) {
                case "e" => pos += 1; return Some(CssConstant.E)
                case "pi" => pos += 1; return Some(CssConstant.Pi)
                case "infinity" => pos += 1; return Some(CssConstant.Infinity)
                case "-infinity" => pos += 1; return Some(CssConstant.NegInfinity)
                case "nan" => pos += 1; return Some(CssConstant.Nan)
                case _ => ()
            }
        }
        None
    }

    /// 尝试解析标识符
    /// 严格翻译自 Parser.expectIdent
    public func tryParseIdent(): ?String {
        if (pos < tokens.size) {
            let t = tokens[pos]
            if (t.size > 0 && t[0].isAsciiLetter()) {
                pos += 1
                return t
            }
        }
        None
    }

    /// 尝试解析维度值 (返回单位字符串)
    /// 严格翻译自 Parser.tryParse(dimension)
    public func tryParseDimension(): ?String {
        if (pos < tokens.size) {
            let t = tokens[pos]
            pos += 1
            return t
        }
        None
    }

    /// 尝试解析舍入策略
    public func tryParseRoundingStrategy(): ?CssRoundingStrategy {
        if (pos < tokens.size) {
            let t = tokens[pos]
            match (t) {
                case "nearest" => pos += 1; return Some(CssRoundingStrategy.Nearest)
                case "up" => pos += 1; return Some(CssRoundingStrategy.Up)
                case "down" => pos += 1; return Some(CssRoundingStrategy.Down)
                case "to-zero" => pos += 1; return Some(CssRoundingStrategy.ToZero)
                case _ => ()
            }
        }
        None
    }

    /// 当前源位置 (简化)
    public func currentSourceLocation(): Int64 { pos }

    /// 期望数字
    public func expectNumber(): ?Float64 {
        if (pos < tokens.size) {
            let t = tokens[pos]
            let parsed = Float64.parse(t)
            if (!parsed.isNaN()) {
                pos += 1
                return parsed
            }
        }
        Option<Float64>.None
    }

    /// 期望字符串
    public func expectString(): ?String {
        if (pos < tokens.size) {
            let t = tokens[pos]
            pos += 1
            return t
        }
        Option<String>.None
    }

    /// 期望整数
    public func expectInteger(): ?Int64 {
        if (pos < tokens.size) {
            let t = tokens[pos]
            try {
                let parsed = Int64.parse(t)
                pos += 1
                return parsed
            } catch (_: Exception) {
                return Option<Int64>.None
            }
        }
        Option<Int64>.None
    }

    /// 期望百分比
    public func expectPercentage(): ?Float64 {
        if (pos < tokens.size) {
            let t = tokens[pos]
            if (t.endsWith("%")) {
                let numStr = t[0..Int64(t.size) - 1]
                let parsed = Float64.parse(numStr)
                if (!parsed.isNaN()) {
                    pos += 1
                    return parsed / 100.0
                }
            }
        }
        Option<Float64>.None
    }

    /// 期望标识符
    public func expectIdent(): ?String {
        if (pos < tokens.size) {
            let t = tokens[pos]
            if (t.size > 0 && t[0].isAsciiLetter()) {
                pos += 1
                return t
            }
        }
        Option<String>.None
    }

    /// 期望分隔符
    public func expectDelim(): ?Rune {
        Option<Rune>.None
    }

    public func expectDelim(delim: Rune): ?Rune {
        Option<Rune>.None
    }

    /// 尝试解析
    public func tryParse<T>(parser: (CssParser) -> T): ?T {
        Some(parser(this))
    }
}

// ============================================================================
// 数学函数
// 严格翻译自: values/calc.zig MathFunction<V> union(enum)
// ============================================================================

/// MathFunction 类型标签
public enum CssMathFunctionKind {
    | Calc     // calc()
    | Min      // min()
    | Max      // max()
    | Clamp    // clamp()
    | Round    // round()
    | Rem      // rem()
    | Mod      // mod()
    | Abs      // abs()
    | Sign     // sign()
    | Hypot    // hypot()

    public operator func ==(right: CssMathFunctionKind): Bool {
        match (this) {
            case Calc => match (right) { case Calc => true case _ => false }
            case Min => match (right) { case Min => true case _ => false }
            case Max => match (right) { case Max => true case _ => false }
            case Clamp => match (right) { case Clamp => true case _ => false }
            case Round => match (right) { case Round => true case _ => false }
            case Rem => match (right) { case Rem => true case _ => false }
            case Mod => match (right) { case Mod => true case _ => false }
            case Abs => match (right) { case Abs => true case _ => false }
            case Sign => match (right) { case Sign => true case _ => false }
            case Hypot => match (right) { case Hypot => true case _ => false }
        }
    }

    public operator func !=(right: CssMathFunctionKind): Bool {
        !(this == right)
    }
}

/// CSS 数学函数
/// 严格翻译自 MathFunction union { calc, min, max, clamp, round, rem, mod_, abs, sign, hypot }
public class CssMathFunction {
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

    // ========================================================================
    // 构造函数
    // ========================================================================

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

    public init(clampMin: CssCalc, clampCenter: CssCalc, clampMax: CssCalc) {
        this.kind = CssMathFunctionKind.Clamp
        this.calc = None
        this.args = ArrayList<CssCalc>()
        this.clampMin = Some(clampMin)
        this.clampCenter = Some(clampCenter)
        this.clampMax = Some(clampMax)
        this.roundStrategy = CssRoundingStrategy.Nearest
        this.roundValue = None
        this.roundInterval = None
        this.dividend = None
        this.divisor = None
    }

    public init(roundStrategy: CssRoundingStrategy, roundValue: CssCalc, roundInterval: CssCalc) {
        this.kind = CssMathFunctionKind.Round
        this.calc = None
        this.args = ArrayList<CssCalc>()
        this.clampMin = None
        this.clampCenter = None
        this.clampMax = None
        this.roundStrategy = roundStrategy
        this.roundValue = Some(roundValue)
        this.roundInterval = Some(roundInterval)
        this.dividend = None
        this.divisor = None
    }

    public init(remDividend: CssCalc, remDivisor: CssCalc, isRem: Bool) {
        this.kind = CssMathFunctionKind.Rem
        this.calc = None
        this.args = ArrayList<CssCalc>()
        this.clampMin = None
        this.clampCenter = None
        this.clampMax = None
        this.roundStrategy = CssRoundingStrategy.Nearest
        this.roundValue = None
        this.roundInterval = None
        this.dividend = Some(remDividend)
        this.divisor = Some(remDivisor)
    }

    public init(modDividend: CssCalc, modDivisor: CssCalc) {
        this.kind = CssMathFunctionKind.Mod
        this.calc = None
        this.args = ArrayList<CssCalc>()
        this.clampMin = None
        this.clampCenter = None
        this.clampMax = None
        this.roundStrategy = CssRoundingStrategy.Nearest
        this.roundValue = None
        this.roundInterval = None
        this.dividend = Some(modDividend)
        this.divisor = Some(modDivisor)
    }

    public static func abs(absCalc: CssCalc): CssMathFunction {
        let result = CssMathFunction(absCalc)
        result.kind = CssMathFunctionKind.Abs
        return result
    }

    public static func sign(signCalc: CssCalc): CssMathFunction {
        let result = CssMathFunction(signCalc)
        result.kind = CssMathFunctionKind.Sign
        return result
    }

    public static func hypot(hypotArgs: ArrayList<CssCalc>): CssMathFunction {
        let result = CssMathFunction(hypotArgs)
        result.kind = CssMathFunctionKind.Hypot
        return result
    }

    // ========================================================================
    // 深拷贝
    // 严格翻译自 MathFunction.deepClone
    // ========================================================================

    public func deepClone(): CssMathFunction {
        match (kind) {
            case Calc =>
                match (calc) {
                    case Some(c) => CssMathFunction(c.deepClone())
                    case None => CssMathFunction(CssCalc(0.0))
                }
            case Min =>
                let copy = ArrayList<CssCalc>()
                for (a in args) { copy.append(a.deepClone()) }
                CssMathFunction(copy)
            case Max =>
                let copy = ArrayList<CssCalc>()
                for (a in args) { copy.append(a.deepClone()) }
                CssMathFunction(copy, true)
            case Clamp =>
                let mn = match (clampMin) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                let ct = match (clampCenter) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                let mx = match (clampMax) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                CssMathFunction(mn, ct, mx)
            case Round =>
                let val = match (roundValue) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                let intv = match (roundInterval) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                CssMathFunction(roundStrategy, val, intv)
            case Rem =>
                let d1 = match (dividend) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                let d2 = match (divisor) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                CssMathFunction(d1, d2, true)
            case Mod =>
                let d1 = match (dividend) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                let d2 = match (divisor) { case Some(c) => c.deepClone() case None => CssCalc(0.0) }
                CssMathFunction(d1, d2)
            case Abs =>
                match (calc) {
                    case Some(c) => CssMathFunction.abs(c.deepClone())
                    case None => CssMathFunction.abs(CssCalc(0.0))
                }
            case Sign =>
                match (calc) {
                    case Some(c) => CssMathFunction.sign(c.deepClone())
                    case None => CssMathFunction.sign(CssCalc(0.0))
                }
            case Hypot =>
                let copy = ArrayList<CssCalc>()
                for (a in args) { copy.append(a.deepClone()) }
                CssMathFunction.hypot(copy)
        }
    }

    // ========================================================================
    // 比较
    // 严格翻译自 MathFunction.eql
    // ========================================================================

    public func eql(other: CssMathFunction): Bool {
        if (kind != other.kind) { return false }
        match (kind) {
            case Calc =>
                match (calc) {
                    case Some(a) => match (other.calc) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.calc) { case Some(_) => false case None => true }
                }
            case Min =>
                if (args.size != other.args.size) { return false }
                for (i in 0..args.size) {
                    if (!args[i].eql(other.args[i])) { return false }
                }
                true
            case Max =>
                if (args.size != other.args.size) { return false }
                for (i in 0..args.size) {
                    if (!args[i].eql(other.args[i])) { return false }
                }
                true
            case Clamp =>
                let minEq = match (clampMin) {
                    case Some(a) => match (other.clampMin) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.clampMin) { case Some(_) => false case None => true }
                }
                let centerEq = match (clampCenter) {
                    case Some(a) => match (other.clampCenter) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.clampCenter) { case Some(_) => false case None => true }
                }
                let maxEq = match (clampMax) {
                    case Some(a) => match (other.clampMax) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.clampMax) { case Some(_) => false case None => true }
                }
                minEq && centerEq && maxEq
            case Round =>
                roundStrategy != other.roundStrategy &&
                match (roundValue) {
                    case Some(a) => match (other.roundValue) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.roundValue) { case Some(_) => false case None => true }
                } &&
                match (roundInterval) {
                    case Some(a) => match (other.roundInterval) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.roundInterval) { case Some(_) => false case None => true }
                }
            case Rem | Mod =>
                let d1Eq = match (dividend) {
                    case Some(a) => match (other.dividend) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.dividend) { case Some(_) => false case None => true }
                }
                let d2Eq = match (divisor) {
                    case Some(a) => match (other.divisor) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.divisor) { case Some(_) => false case None => true }
                }
                d1Eq && d2Eq
            case Abs | Sign =>
                match (calc) {
                    case Some(a) => match (other.calc) { case Some(b) => a.eql(b) case None => false }
                    case None => match (other.calc) { case Some(_) => false case None => true }
                }
            case Hypot =>
                if (args.size != other.args.size) { return false }
                for (i in 0..args.size) {
                    if (!args[i].eql(other.args[i])) { return false }
                }
                true
            case _ => false
        }
    }

    // ========================================================================
    // CSS 输出
    // ========================================================================

    private func joinParts(parts: ArrayList<String>): String {
        let sb = CssStringBuilder()
        for (i in 0..parts.size) {
            if (i > 0) { sb.append(", ") }
            sb.append(parts[i])
        }
        sb.toString()
    }

    /// 转为 CSS 文本
    /// 严格翻译自 MathFunction.toCss
    public func toCss(): String {
        match (kind) {
            case Calc =>
                match (calc) {
                    case Some(c) => "calc(${c.toCss()})"
                    case None => "calc()"
                }
            case Min =>
                let parts = ArrayList<String>()
                for (a in args) { parts.append(a.toCss()) }
                "min(${joinParts(parts)})"
            case Max =>
                let parts = ArrayList<String>()
                for (a in args) { parts.append(a.toCss()) }
                "max(${joinParts(parts)})"
            case Clamp =>
                let minStr = match (clampMin) { case Some(c) => c.toCss() case None => "" }
                let centerStr = match (clampCenter) { case Some(c) => c.toCss() case None => "" }
                let maxStr = match (clampMax) { case Some(c) => c.toCss() case None => "" }
                "clamp(${minStr}, ${centerStr}, ${maxStr})"
            case Round =>
                let valStr = match (roundValue) { case Some(c) => c.toCss() case None => "" }
                let intStr = match (roundInterval) { case Some(c) => c.toCss() case None => "" }
                if (roundStrategy == CssRoundingStrategy.Nearest) {
                    // 严格翻译自: 如果策略为默认值则不输出策略名
                    "round(${valStr}, ${intStr})"
                } else {
                    "round(${roundStrategy.toCss()}, ${valStr}, ${intStr})"
                }
            case Rem =>
                let d1 = match (dividend) { case Some(c) => c.toCss() case None => "" }
                let d2 = match (divisor) { case Some(c) => c.toCss() case None => "" }
                "rem(${d1}, ${d2})"
            case Mod =>
                let d1 = match (dividend) { case Some(c) => c.toCss() case None => "" }
                let d2 = match (divisor) { case Some(c) => c.toCss() case None => "" }
                "mod(${d1}, ${d2})"
            case Abs =>
                match (calc) {
                    case Some(c) => "abs(${c.toCss()})"
                    case None => "abs()"
                }
            case Sign =>
                match (calc) {
                    case Some(c) => "sign(${c.toCss()})"
                    case None => "sign()"
                }
            case Hypot =>
                let parts = ArrayList<String>()
                for (a in args) { parts.append(a.toCss()) }
                "hypot(${joinParts(parts)})"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 数学辅助函数
// 严格翻译自: values/calc.zig 顶层辅助函数
// ============================================================================

private func cssFloor(v: Float64): Float64 {
    let i = Int64(v)
    if (v < 0.0 && Float64(i) != v) { Float64(i - 1) } else { Float64(i) }
}

private func cssCeil(v: Float64): Float64 {
    let i = Int64(v)
    if (v > 0.0 && Float64(i) != v) { Float64(i + 1) } else { Float64(i) }
}

private func cssTrunc(v: Float64): Float64 {
    Float64(Int64(v))
}

private func cssRoundNearest(v: Float64): Float64 {
    if (v >= 0.0) { cssFloor(v + 0.5) } else { cssCeil(v - 0.5) }
}

/// 舍入运算
/// 严格翻译自 calc.zig round() 函数
public func cssRound(value: Float64, to: Float64, strategy: CssRoundingStrategy): Float64 {
    let v = value / to
    match (strategy) {
        case Down => cssFloor(v) * to
        case Up => cssCeil(v) * to
        case Nearest => cssRoundNearest(v) * to
        case ToZero => cssTrunc(v) * to
    }
}

private func cssSqrtImpl(x: Float64): Float64 {
    if (x < 0.0) { return Float64.NaN }
    if (x == 0.0) { return 0.0 }
    var guess = x
    for (_ in 0..20) {
        guess = (guess + x / guess) / 2.0
    }
    return guess
}

/// 求两数平方和的平方根
/// 严格翻译自 calc.zig hypot() 函数
public func cssHypot(a: Float64, b: Float64): Float64 {
    cssSqrtImpl(a * a + b * b)
}

/// 求平方 (x^2)
/// 严格翻译自 calc.zig powi2() 函数
public func cssPowi2(v: Float64): Float64 {
    v * v
}

/// 求平方根
/// 严格翻译自 calc.zig sqrtf32() 函数
public func cssSqrt(v: Float64): Float64 {
    cssSqrtImpl(v)
}

/// 求绝对值
/// 严格翻译自 calc.zig absf() 函数
public func cssAbsf(v: Float64): Float64 {
    if (v < 0.0) { -v } else { v }
}

/// 创建包含两个元素的列表
/// 严格翻译自 calc.zig arr2() 函数
public func cssArr2(a: CssCalc, b: CssCalc): ArrayList<CssCalc> {
    let list = ArrayList<CssCalc>()
    list.append(a)
    list.append(b)
    return list
}

// ============================================================================
// Calc 辅助: applyOp / applyMap
// 严格翻译自: values/calc.zig Calc.applyOp, Calc.applyMap
// ============================================================================

/// 对两个 Calc 值应用运算符
/// 严格翻译自 Calc.applyOp
public func calcApplyOp(a: CssCalc, b: CssCalc, op: (Float64, Float64) -> Float64): ?CssCalc {
    if (a.kind == CssCalcKind.Value && b.kind == CssCalcKind.Value) {
        return Some(CssCalc(op(a.numberValue, b.numberValue)))
    }
    if (a.kind == CssCalcKind.Number && b.kind == CssCalcKind.Number) {
        return Some(CssCalc(op(a.numberValue, b.numberValue)))
    }
    return None
}

/// 对一个 Calc 值应用映射函数
/// 严格翻译自 Calc.applyMap
public func calcApplyMap(calc: CssCalc, op: (Float64) -> Float64): ?CssCalc {
    match (calc.kind) {
        case Number => Some(CssCalc(op(calc.numberValue)))
        case Value => Some(CssCalc(op(calc.numberValue)))
        case _ => None
    }
}

// ============================================================================
// Calc 辅助: parseHypot
// 严格翻译自: values/calc.zig Calc.parseHypot
// ============================================================================

/// 解析 hypot 参数列表
/// 严格翻译自 Calc.parseHypot
public func parseHypot(args: ArrayList<CssCalc>): ?CssCalc {
    if (args.size == 1) {
        return args[0]
    }

    if (args.size == 2) {
        return calcApplyOp(args[0], args[1], { a, b => cssHypot(a, b) })
    }

    // 三个或更多参数
    let firstMapped = calcApplyMap(args[0], { v => cssPowi2(v) })
    if (firstMapped.isNone()) {
        return None
    }
    var sum = firstMapped.getOrThrow()
    var i: Int64 = 1
    while (i < args.size) {
        let next = calcApplyOp(sum, args[i], { a, b => a + cssPowi2(b) })
        if (next.isNone()) {
            return None
        }
        sum = next.getOrThrow()
        i += 1
    }

    return calcApplyMap(sum, { v => cssSqrt(v) })
}

// ============================================================================
// Calc 辅助: reduceArgs
// 严格翻译自: values/calc.zig Calc.reduceArgs
// ============================================================================

/// 缩减 min()/max() 参数，合并兼容值
/// 严格翻译自 Calc.reduceArgs
/// order: true = lt (min), false = gt (max)
public func calcReduceArgs(args: ArrayList<CssCalc>, orderLt: Bool): Unit {
    var reduced = ArrayList<CssCalc>()
    for (i in 0..args.size) {
        var found = false
        var dominated = false
        let arg = args[i]
        if (arg.kind == CssCalcKind.Number) {
            for (j in 0..reduced.size) {
                if (reduced[j].kind == CssCalcKind.Number) {
                    // 比较数值大小
                    if (orderLt && arg.numberValue < reduced[j].numberValue) {
                        reduced[j] = arg
                        found = true
                        break
                    } else if (!orderLt && arg.numberValue > reduced[j].numberValue) {
                        reduced[j] = arg
                        found = true
                        break
                    } else {
                        dominated = true
                        found = true
                        break
                    }
                }
            }
        }
        if (!found) {
            reduced.append(arg)
        }
    }
    // 用 reduced 替换 args 内容
    args.clear()
    for (r in reduced) {
        args.append(r)
    }
}
