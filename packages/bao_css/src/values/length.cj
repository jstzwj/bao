// bao_css - CSS 长度值
// 严格翻译自: bun/src/css/values/length.rs
//   对应: values/length.zig - LengthValue, Length, LengthOrNumber, LengthPercentage, LengthPercentageOrAuto
package bao_css.values

import bao_core.*
import bao_collections.*

// ============================================================================
// 像素转换常量
// 严格翻译自: values/length.rs PX_PER_IN / PX_PER_CM / PX_PER_MM / PX_PER_Q / PX_PER_PT / PX_PER_PC
// ============================================================================

let PX_PER_IN: Float64 = 96.0
let PX_PER_CM: Float64 = PX_PER_IN / 2.54
let PX_PER_MM: Float64 = PX_PER_CM / 10.0
let PX_PER_Q: Float64 = PX_PER_CM / 40.0
let PX_PER_PT: Float64 = PX_PER_IN / 72.0
let PX_PER_PC: Float64 = PX_PER_IN / 6.0

// ============================================================================
// 长度值单位
// 严格翻译自: values/length.rs LengthValue enum (macro-generated 50 variants)
// ============================================================================

/// CSS 长度单位
/// 严格翻译自 LengthValue 的单位枚举
public enum CssLengthUnit {
    // 绝对单位
    | Px     // px - 像素
    | In     // in - 英寸
    | Cm     // cm - 厘米
    | Mm     // mm - 毫米
    | Q      // q - 四分之一毫米
    | Pt     // pt - 点
    | Pc     // pc - 派卡

    // 字体相对单位
    | Em     // em
    | Rem    // rem
    | Ex     // ex
    | Rex    // rex
    | Ch     // ch
    | Rch    // rch
    | Cap    // cap
    | Rcap   // rcap
    | Ic     // ic
    | Ric    // ric
    | Lh     // lh
    | Rlh    // rlh

    // 视口相对单位 - 宽度
    | Vw     // vw
    | Lvw    // lvw
    | Svw    // svw
    | Dvw    // dvw
    | Cqw    // cqw

    // 视口相对单位 - 高度
    | Vh     // vh
    | Lvh    // lvh
    | Svh    // svh
    | Dvh    // dvh
    | Cqh    // cqh

    // 视口相对单位 - 行内
    | Vi     // vi
    | Svi    // svi
    | Lvi    // lvi
    | Dvi    // dvi
    | Cqi    // cqi

    // 视口相对单位 - 块
    | Vb     // vb
    | Svb    // svb
    | Lvb    // lvb
    | Dvb    // dvb
    | Cqb    // cqb

    // 视口相对单位 - 最小/最大
    | Vmin   // vmin
    | Svmin  // svmin
    | Lvmin  // lvmin
    | Dvmin  // dvmin
    | Cqmin  // cqmin

    | Vmax   // vmax
    | Svmax  // svmax
    | Lvmax  // lvmax
    | Dvmax  // dvmax
    | Cqmax  // cqmax

    /// 获取单位名称
    /// 严格翻译自 LengthValue::unit
    public func unitName(): String {
        match (this) {
            case Px => "px"
            case In => "in"
            case Cm => "cm"
            case Mm => "mm"
            case Q => "q"
            case Pt => "pt"
            case Pc => "pc"
            case Em => "em"
            case Rem => "rem"
            case Ex => "ex"
            case Rex => "rex"
            case Ch => "ch"
            case Rch => "rch"
            case Cap => "cap"
            case Rcap => "rcap"
            case Ic => "ic"
            case Ric => "ric"
            case Lh => "lh"
            case Rlh => "rlh"
            case Vw => "vw"
            case Lvw => "lvw"
            case Svw => "svw"
            case Dvw => "dvw"
            case Cqw => "cqw"
            case Vh => "vh"
            case Lvh => "lvh"
            case Svh => "svh"
            case Dvh => "dvh"
            case Cqh => "cqh"
            case Vi => "vi"
            case Svi => "svi"
            case Lvi => "lvi"
            case Dvi => "dvi"
            case Cqi => "cqi"
            case Vb => "vb"
            case Svb => "svb"
            case Lvb => "lvb"
            case Dvb => "dvb"
            case Cqb => "cqb"
            case Vmin => "vmin"
            case Svmin => "svmin"
            case Lvmin => "lvmin"
            case Dvmin => "dvmin"
            case Cqmin => "cqmin"
            case Vmax => "vmax"
            case Svmax => "svmax"
            case Lvmax => "lvmax"
            case Dvmax => "dvmax"
            case Cqmax => "cqmax"
        }
    }

    /// 从单位名称解析 (大小写不敏感)
    /// 严格翻译自 LengthValue::from_unit_ci
    public static func fromUnitName(name: String): ?CssLengthUnit {
        let lower = name.toLower()
        match (lower) {
            "px" => Some(CssLengthUnit.Px)
            "in" => Some(CssLengthUnit.In)
            "cm" => Some(CssLengthUnit.Cm)
            "mm" => Some(CssLengthUnit.Mm)
            "q" => Some(CssLengthUnit.Q)
            "pt" => Some(CssLengthUnit.Pt)
            "pc" => Some(CssLengthUnit.Pc)
            "em" => Some(CssLengthUnit.Em)
            "rem" => Some(CssLengthUnit.Rem)
            "ex" => Some(CssLengthUnit.Ex)
            "rex" => Some(CssLengthUnit.Rex)
            "ch" => Some(CssLengthUnit.Ch)
            "rch" => Some(CssLengthUnit.Rch)
            "cap" => Some(CssLengthUnit.Cap)
            "rcap" => Some(CssLengthUnit.Rcap)
            "ic" => Some(CssLengthUnit.Ic)
            "ric" => Some(CssLengthUnit.Ric)
            "lh" => Some(CssLengthUnit.Lh)
            "rlh" => Some(CssLengthUnit.Rlh)
            "vw" => Some(CssLengthUnit.Vw)
            "lvw" => Some(CssLengthUnit.Lvw)
            "svw" => Some(CssLengthUnit.Svw)
            "dvw" => Some(CssLengthUnit.Dvw)
            "cqw" => Some(CssLengthUnit.Cqw)
            "vh" => Some(CssLengthUnit.Vh)
            "lvh" => Some(CssLengthUnit.Lvh)
            "svh" => Some(CssLengthUnit.Svh)
            "dvh" => Some(CssLengthUnit.Dvh)
            "cqh" => Some(CssLengthUnit.Cqh)
            "vi" => Some(CssLengthUnit.Vi)
            "svi" => Some(CssLengthUnit.Svi)
            "lvi" => Some(CssLengthUnit.Lvi)
            "dvi" => Some(CssLengthUnit.Dvi)
            "cqi" => Some(CssLengthUnit.Cqi)
            "vb" => Some(CssLengthUnit.Vb)
            "svb" => Some(CssLengthUnit.Svb)
            "lvb" => Some(CssLengthUnit.Lvb)
            "dvb" => Some(CssLengthUnit.Dvb)
            "cqb" => Some(CssLengthUnit.Cqb)
            "vmin" => Some(CssLengthUnit.Vmin)
            "svmin" => Some(CssLengthUnit.Svmin)
            "lvmin" => Some(CssLengthUnit.Lvmin)
            "dvmin" => Some(CssLengthUnit.Dvmin)
            "cqmin" => Some(CssLengthUnit.Cqmin)
            "vmax" => Some(CssLengthUnit.Vmax)
            "svmax" => Some(CssLengthUnit.Svmax)
            "lvmax" => Some(CssLengthUnit.Lvmax)
            "dvmax" => Some(CssLengthUnit.Dvmax)
            "cqmax" => Some(CssLengthUnit.Cqmax)
            case _ => None
        }
    }
}

// ============================================================================
// 长度值
// 严格翻译自: values/length.rs LengthValue enum
// ============================================================================

/// CSS <length> 显式值
/// 严格翻译自 LengthValue (union enum with ~50 variants, each carrying f32)
public class CssLengthValue {
    public var unit: CssLengthUnit
    public var value: Float64

    public init(unit: CssLengthUnit, value: Float64) {
        this.unit = unit
        this.value = value
    }

    /// 零值 (0px)
    /// 严格翻译自 LengthValue::zero
    public static func zero(): CssLengthValue {
        CssLengthValue(CssLengthUnit.Px, 0.0)
    }

    /// 是否为零
    /// 严格翻译自 LengthValue::is_zero
    public func isZero(): Bool {
        value == 0.0
    }

    /// 符号
    /// 严格翻译自 LengthValue::sign
    public func sign(): Float64 {
        CSSNumberFns.sign(value)
    }

    /// 尝试获取符号
    /// 严格翻译自 LengthValue::try_sign
    public func trySign(): ?Float64 {
        Some(sign())
    }

    /// 乘以浮点数
    /// 严格翻译自 LengthValue::mul_f32
    public func mulF32(other: Float64): CssLengthValue {
        CssLengthValue(unit, value * other)
    }

    /// 尝试转为像素
    /// 严格翻译自 LengthValue::to_px
    public func toPx(): ?Float64 {
        match (unit) {
            case Px => Some(value)
            case In => Some(value * PX_PER_IN)
            case Cm => Some(value * PX_PER_CM)
            case Mm => Some(value * PX_PER_MM)
            case Q => Some(value * PX_PER_Q)
            case Pt => Some(value * PX_PER_PT)
            case Pc => Some(value * PX_PER_PC)
            case _ => None // 相对单位无法转换为像素
        }
    }

    /// 偏序比较
    /// 严格翻译自 LengthValue::partial_cmp
    public func partialCmp(other: CssLengthValue): ?Ordering {
        if (unit == other.unit) {
            if (value < other.value) { Some(Ordering.Less) }
            else if (value > other.value) { Some(Ordering.Greater) }
            else { Some(Ordering.Equal) }
        } else {
            let aPx = toPx()
            let bPx = other.toPx()
            match (aPx, bPx) {
                case (Some(a), Some(b)) => {
                    if (a < b) { Some(Ordering.Less) }
                    else if (a > b) { Some(Ordering.Greater) }
                    else { Some(Ordering.Equal) }
                }
                case _ => None
            }
        }
    }

    /// 相等比较
    /// 严格翻译自 LengthValue impl PartialEq
    public func eql(other: CssLengthValue): Bool {
        unit == other.unit && value == other.value
    }

    /// 尝试加法
    /// 严格翻译自 LengthValue::try_add
    public func tryAdd(rhs: CssLengthValue): ?CssLengthValue {
        if (unit == rhs.unit) {
            Some(CssLengthValue(unit, value + rhs.value))
        } else {
            let aPx = toPx()
            let bPx = rhs.toPx()
            match (aPx, bPx) {
                case (Some(a), Some(b)) => Some(CssLengthValue(CssLengthUnit.Px, a + b))
                case _ => None
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssLengthValue {
        CssLengthValue(unit, value)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 LengthValue::to_css
    public func toCss(): String {
        if (value == 0.0) {
            "0"
        } else {
            "${CSSNumberFns.toCss(value)}${unit.unitName()}"
        }
    }

    /// 映射值
    /// 严格翻译自 LengthValue::map
    public func map(mapFn: (Float64) -> Float64): CssLengthValue {
        CssLengthValue(unit, mapFn(value))
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// CSS <length> 值 (带 calc 支持)
// 严格翻译自: values/length.rs Length enum { Value, Calc }
// ============================================================================

/// CSS <length> 值 (支持 calc)
/// 严格翻译自 Length enum { Value(LengthValue), Calc(Box<Calc<Length>>) }
public class CssLength {
    public enum CssLengthKind {
        | Value    // 显式长度值
        | Calc     // calc() 表达式
    }

    public var kind: CssLengthKind
    public var value: ?CssLengthValue
    public var calcExpression: ?CssCalc

    public init(value: CssLengthValue) {
        this.kind = CssLengthKind.Value
        this.value = Some(value)
        this.calcExpression = None
    }

    public init(calc: CssCalc) {
        this.kind = CssLengthKind.Calc
        this.value = None
        this.calcExpression = Some(calc)
    }

    /// 零值
    /// 严格翻译自 Length::zero
    public static func zero(): CssLength {
        CssLength(CssLengthValue.zero())
    }

    /// 像素值
    /// 严格翻译自 Length::px
    public static func px(p: Float64): CssLength {
        CssLength(CssLengthValue(CssLengthUnit.Px, p))
    }

    /// 是否为零
    /// 严格翻译自 Length::is_zero
    public func isZero(): Bool {
        match (kind) {
            case Value => {
                match (value) {
                    case Some(v) => v.isZero()
                    case None => false
                }
            }
            case Calc => false
        }
    }

    /// 乘以浮点数
    /// 严格翻译自 Length::mul_f32
    public func mulF32(other: Float64): CssLength {
        match (kind) {
            case Value => {
                match (value) {
                    case Some(v) => CssLength(v.mulF32(other))
                    case None => CssLength.zero()
                }
            }
            case Calc => {
                match (calcExpression) {
                    case Some(c) => CssLength(calc: c.mulF32(other))
                    case None => CssLength.zero()
                }
            }
        }
    }

    /// 符号
    /// 严格翻译自 Length::sign -> try_sign
    public func trySign(): ?Float64 {
        match (kind) {
            case Value => {
                match (value) {
                    case Some(v) => Some(v.sign())
                    case None => None
                }
            }
            case Calc => {
                match (calcExpression) {
                    case Some(c) => Some(c.trySign())
                    case None => None
                }
            }
        }
    }

    /// 尝试转为像素
    /// 严格翻译自 Length::to_px
    public func toPx(): ?Float64 {
        match (kind) {
            case Value => {
                match (value) {
                    case Some(v) => v.toPx()
                    case None => None
                }
            }
            case Calc => None
        }
    }

    /// 深拷贝
    public func deepClone(): CssLength {
        match (kind) {
            case Value => {
                match (value) {
                    case Some(v) => CssLength(v.deepClone())
                    case None => CssLength.zero()
                }
            }
            case Calc => {
                match (calcExpression) {
                    case Some(c) => CssLength(calc: c)
                    case None => CssLength.zero()
                }
            }
        }
    }

    /// 偏序比较
    /// 严格翻译自 Length::partial_cmp
    public func partialCmp(other: CssLength): ?Ordering {
        if (kind == CssLengthKind.Value && other.kind == CssLengthKind.Value) {
            let a = match (value) { case Some(v) => v case None => return None }
            let b = match (other.value) { case Some(v) => v case None => return None }
            a.partialCmp(b)
        } else {
            None
        }
    }

    /// 相等比较
    public func eql(other: CssLength): Bool {
        if (kind != other.kind) { return false }
        match (kind) {
            case Value => {
                let a = match (value) { case Some(v) => v case None => return false }
                let b = match (other.value) { case Some(v) => v case None => return false }
                a.eql(b)
            }
            case Calc => false // calc 表达式比较简化
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Value => {
                match (value) {
                    case Some(v) => v.toCss()
                    case None => "0"
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
// 长度或数值
// 严格翻译自: values/length.rs LengthOrNumber enum { Number, Length }
// ============================================================================

/// CSS <length-or-number> 值
/// 严格翻译自 LengthOrNumber enum { Number(f32), Length(Length) }
public class CssLengthOrNumber {
    public enum CssLengthOrNumberKind {
        | Number   // 数值
        | Length   // 长度值
    }

    public var kind: CssLengthOrNumberKind
    public var numberValue: Float64
    public var lengthValue: ?CssLengthValue

    public init(number: Float64) {
        this.kind = CssLengthOrNumberKind.Number
        this.numberValue = number
        this.lengthValue = None
    }

    public init(length: CssLengthValue) {
        this.kind = CssLengthOrNumberKind.Length
        this.numberValue = 0.0
        this.lengthValue = Some(length)
    }

    /// 默认值 (0)
    /// 严格翻译自 LengthOrNumber default
    public static func defaultValue(): CssLengthOrNumber {
        CssLengthOrNumber(0.0)
    }

    /// 深拷贝
    public func deepClone(): CssLengthOrNumber {
        match (kind) {
            case Number => CssLengthOrNumber(numberValue)
            case Length => {
                match (lengthValue) {
                    case Some(v) => CssLengthOrNumber(length: v.deepClone())
                    case None => CssLengthOrNumber(0.0)
                }
            }
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Number => CSSNumberFns.toCss(numberValue)
            case Length => {
                match (lengthValue) {
                    case Some(v) => v.toCss()
                    case None => "0"
                }
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 长度百分比类型别名
// 严格翻译自: values/length.rs LengthPercentage = DimensionPercentage<LengthValue>
// ============================================================================

/// CSS <length-percentage> 值
/// 严格翻译自 LengthPercentage = DimensionPercentage<LengthValue>
public type CssLengthPercentage = CssDimensionPercentage

// ============================================================================
// 长度百分比或 auto
// 严格翻译自: values/length.rs LengthPercentageOrAuto enum { Auto, Length }
// ============================================================================

/// CSS <length-percentage> 或 auto
/// 严格翻译自 LengthPercentageOrAuto enum { Auto, Length(LengthPercentage) }
public class CssLengthPercentageOrAuto {
    public enum CssLengthPercentageOrAutoKind {
        | Auto               // auto
        | LengthPercentage   // 长度或百分比
    }

    public var kind: CssLengthPercentageOrAutoKind
    public var lpValue: ?CssDimensionPercentage

    public init() {
        this.kind = CssLengthPercentageOrAutoKind.Auto
        this.lpValue = None
    }

    public init(lp: CssDimensionPercentage) {
        this.kind = CssLengthPercentageOrAutoKind.LengthPercentage
        this.lpValue = Some(lp)
    }

    /// 深拷贝
    public func deepClone(): CssLengthPercentageOrAuto {
        match (kind) {
            case Auto => CssLengthPercentageOrAuto()
            case LengthPercentage => {
                match (lpValue) {
                    case Some(lp) => CssLengthPercentageOrAuto(lp.deepClone())
                    case None => CssLengthPercentageOrAuto()
                }
            }
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Auto => "auto"
            case LengthPercentage => {
                match (lpValue) {
                    case Some(lp) => lp.toCss()
                    case None => "auto"
                }
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}
