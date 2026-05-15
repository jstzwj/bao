// bao_css - CSS Values (CSS 值类型系统)
// 严格翻译自: bun/src/css/values/
//   对应: values/ident.zig - Ident, CustomIdent, DashedIdent
//   对应: values/number.zig - CSSInteger, CSSNumber
//   对应: values/percentage.zig - Percentage
//   对应: values/length.zig - Length, LengthValue
//   对应: values/angle.zig - Angle
//   对应: values/time.zig - Time
//   对应: values/resolution.zig - Resolution
//   对应: values/ratio.zig - Ratio
//   对应: values/color.zig - CssColor, RGBA
//   对应: values/url.zig - Url
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// CSS 值类型枚举
// ============================================================================

/// CSS 值类型
public enum CssValueType {
    | Ident
    | CustomIdent
    | DashedIdent
    | String
    | Url
    | Integer
    | Number
    | Percentage
    | Length
    | Angle
    | Time
    | Frequency
    | Resolution
    | Color
    | Image
    | Transform
    | Ratio
    | Calc
    | Var
    | None
    | Custom

    public func name(): String {
        match (this) {
            case Ident => "ident"
            case CustomIdent => "custom-ident"
            case DashedIdent => "dashed-ident"
            case String => "string"
            case Url => "url"
            case Integer => "integer"
            case Number => "number"
            case Percentage => "percentage"
            case Length => "length"
            case Angle => "angle"
            case Time => "time"
            case Frequency => "frequency"
            case Resolution => "resolution"
            case Color => "color"
            case Image => "image"
            case Transform => "transform"
            case Ratio => "ratio"
            case Calc => "calc"
            case Var => "var"
            case None => "none"
            case Custom => "custom"
        }
    }
}

// ============================================================================
// CSS 值 - 统一值容器
// 严格翻译自各 values/*.zig 中的类型
// ============================================================================

/// CSS 值 - 所有 CSS 值类型的统一表示
public class CssValue {
    public var kind: CssValueType
    public var text: String
    public var numberValue: Float64
    public var intValue: Int64
    public var unit: String
    public var color: ?CssColorValue
    public var urlValue: String
    public var ratioNumerator: Float64
    public var ratioDenominator: Float64
    public var raw: String

    public init(kind: CssValueType) {
        this.kind = kind
        this.text = ""
        this.numberValue = 0.0
        this.intValue = 0
        this.unit = ""
        this.color = None
        this.urlValue = ""
        this.ratioNumerator = 1.0
        this.ratioDenominator = 1.0
        this.raw = ""
    }

    public static func ident(text: String): CssValue {
        let v = CssValue(CssValueType.Ident)
        v.text = text
        v.raw = text
        return v
    }

    public static func customIdent(text: String): CssValue {
        let v = CssValue(CssValueType.CustomIdent)
        v.text = text
        v.raw = text
        return v
    }

    public static func dashedIdent(text: String): CssValue {
        let v = CssValue(CssValueType.DashedIdent)
        v.text = text
        v.raw = "--${text}"
        return v
    }

    public static func string(text: String): CssValue {
        let v = CssValue(CssValueType.String)
        v.text = text
        v.raw = "\"${text}\""
        return v
    }

    public static func url(urlStr: String): CssValue {
        let v = CssValue(CssValueType.Url)
        v.urlValue = urlStr
        v.raw = "url(${urlStr})"
        return v
    }

    public static func integer(value: Int64): CssValue {
        let v = CssValue(CssValueType.Integer)
        v.intValue = value
        v.numberValue = Float64(value)
        v.raw = "${value}"
        return v
    }

    public static func number(value: Float64): CssValue {
        let v = CssValue(CssValueType.Number)
        v.numberValue = value
        v.raw = "${value}"
        return v
    }

    public static func percentage(value: Float64): CssValue {
        let v = CssValue(CssValueType.Percentage)
        v.numberValue = value
        v.raw = "${value}%"
        return v
    }

    public static func length(value: Float64, unit: String): CssValue {
        let v = CssValue(CssValueType.Length)
        v.numberValue = value
        v.unit = unit
        v.raw = "${value}${unit}"
        return v
    }

    public static func angle(value: Float64, unit: String): CssValue {
        let v = CssValue(CssValueType.Angle)
        v.numberValue = value
        v.unit = unit
        v.raw = "${value}${unit}"
        return v
    }

    public static func time(value: Float64, unit: String): CssValue {
        let v = CssValue(CssValueType.Time)
        v.numberValue = value
        v.unit = unit
        v.raw = "${value}${unit}"
        return v
    }

    public static func color(color: CssColorValue): CssValue {
        let v = CssValue(CssValueType.Color)
        v.color = Some(color)
        v.raw = color.toString()
        return v
    }

    public static func ratio(numerator: Float64, denominator: Float64): CssValue {
        let v = CssValue(CssValueType.Ratio)
        v.ratioNumerator = numerator
        v.ratioDenominator = denominator
        v.raw = "${numerator}/${denominator}"
        return v
    }

    public func toString(): String {
        match (kind) {
            case CssValueType.Ident | CssValueType.CustomIdent => text
            case CssValueType.DashedIdent => "--${text}"
            case CssValueType.String => "\"${text}\""
            case CssValueType.Url => "url(${urlValue})"
            case CssValueType.Integer => "${intValue}"
            case CssValueType.Number => "${numberValue}"
            case CssValueType.Percentage => "${numberValue}%"
            case CssValueType.Length | CssValueType.Angle |
                 CssValueType.Time | CssValueType.Frequency |
                 CssValueType.Resolution => "${numberValue}${unit}"
            case CssValueType.Color =>
                match (color) {
                    case Some(c) => c.toString()
                    case None => "currentColor"
                }
            case CssValueType.Ratio => "${ratioNumerator}/${ratioDenominator}"
            case CssValueType.None => "none"
            case _ => raw
        }
    }
}

// ============================================================================
// CSS 颜色值
// 严格翻译自: values/color.zig CssColor, RGBA
// ============================================================================

/// RGBA 颜色
public class CssRGBAColor {
    public var red: Float64
    public var green: Float64
    public var blue: Float64
    public var alpha: Float64

    public init() {
        this.red = 0.0
        this.green = 0.0
        this.blue = 0.0
        this.alpha = 1.0
    }

    public init(red: Float64, green: Float64, blue: Float64, alpha: Float64) {
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
    }

    public static func transparent(): CssRGBAColor {
        CssRGBAColor(0.0, 0.0, 0.0, 0.0)
    }

    public static func black(): CssRGBAColor {
        CssRGBAColor(0.0, 0.0, 0.0, 1.0)
    }

    public static func white(): CssRGBAColor {
        CssRGBAColor(255.0, 255.0, 255.0, 1.0)
    }

    public func toHex(): String {
        if (alpha < 255.0) {
            return "#${toHexByte(red)}${toHexByte(green)}${toHexByte(blue)}${toHexByte(alpha)}"
        }
        "#${toHexByte(red)}${toHexByte(green)}${toHexByte(blue)}"
    }

    private static func toHexByte(n: Float64): String {
        let v = clamp(n, 0.0, 255.0)
        let hi = Int64(v) >> 4
        let lo = Int64(v) & 0xF
        let hexChars = "0123456789abcdef"
        "${hexChars[hi]}${hexChars[lo]}"
    }

    public func toRgbString(): String {
        "rgb(${clampInt(red, 0, 255)}, ${clampInt(green, 0, 255)}, ${clampInt(blue, 0, 255)})"
    }

    private static func clamp(v: Float64, min: Float64, max: Float64): Float64 {
        if (v < min) { min } else if (v > max) { max } else { v }
    }

    private static func clampInt(v: Float64, min: Int64, max: Int64): Int64 {
        let i = Int64(v)
        if (i < min) { min } else if (i > max) { max } else { i }
    }
}

/// 颜色类型
public enum CssColorKind {
    | CurrentColor
    | Rgba
    | Named
}

/// CSS 颜色值
public class CssColorValue {
    public var kind: CssColorKind
    public var rgba: CssRGBAColor
    public var namedColor: String

    public init() {
        this.kind = CssColorKind.Rgba
        this.rgba = CssRGBAColor.black()
        this.namedColor = ""
    }

    public init(rgba: CssRGBAColor) {
        this.kind = CssColorKind.Rgba
        this.rgba = rgba
        this.namedColor = ""
    }

    public static func currentColor(): CssColorValue {
        let c = CssColorValue()
        c.kind = CssColorKind.CurrentColor
        return c
    }

    public static func named(name: String): ?CssColorValue {
        let rgb = CssNamedColors.lookup(name)
        match (rgb) {
            case Some(rgba) => return Some(CssColorValue(rgba))
            case None => return None
        }
    }

    public func toString(): String {
        match (kind) {
            case CssColorKind.CurrentColor => "currentColor"
            case CssColorKind.Rgba => rgba.toHex()
            case CssColorKind.Named => namedColor
        }
    }
}

/// CSS 命名颜色查找表
public class CssNamedColors {
    public static func lookup(name: String): ?CssRGBAColor {
        let key = name.toLowerCase()
        match (key) {
            case "black" => return Some(CssRGBAColor(0, 0, 0, 255))
            case "silver" => return Some(CssRGBAColor(192, 192, 192, 255))
            case "gray" | "grey" => return Some(CssRGBAColor(128, 128, 128, 255))
            case "white" => return Some(CssRGBAColor(255, 255, 255, 255))
            case "maroon" => return Some(CssRGBAColor(128, 0, 0, 255))
            case "red" => return Some(CssRGBAColor(255, 0, 0, 255))
            case "purple" => return Some(CssRGBAColor(128, 0, 128, 255))
            case "fuchsia" => return Some(CssRGBAColor(255, 0, 255, 255))
            case "green" => return Some(CssRGBAColor(0, 128, 0, 255))
            case "lime" => return Some(CssRGBAColor(0, 255, 0, 255))
            case "olive" => return Some(CssRGBAColor(128, 128, 0, 255))
            case "yellow" => return Some(CssRGBAColor(255, 255, 0, 255))
            case "navy" => return Some(CssRGBAColor(0, 0, 128, 255))
            case "blue" => return Some(CssRGBAColor(0, 0, 255, 255))
            case "teal" => return Some(CssRGBAColor(0, 128, 128, 255))
            case "aqua" | "cyan" => return Some(CssRGBAColor(0, 255, 255, 255))
            case "transparent" => return Some(CssRGBAColor(0, 0, 0, 0))
            case "orange" => return Some(CssRGBAColor(255, 165, 0, 255))
            case "pink" => return Some(CssRGBAColor(255, 192, 203, 255))
            case "brown" => return Some(CssRGBAColor(165, 42, 42, 255))
            case "gold" => return Some(CssRGBAColor(255, 215, 0, 255))
            case "violet" => return Some(CssRGBAColor(238, 130, 238, 255))
            case "indigo" => return Some(CssRGBAColor(75, 0, 130, 255))
            case "coral" => return Some(CssRGBAColor(255, 127, 80, 255))
            case "tomato" => return Some(CssRGBAColor(255, 99, 71, 255))
            case "skyblue" => return Some(CssRGBAColor(135, 206, 235, 255))
            case "salmon" => return Some(CssRGBAColor(250, 128, 114, 255))
            case "crimson" => return Some(CssRGBAColor(220, 20, 60, 255))
            case "darkblue" => return Some(CssRGBAColor(0, 0, 139, 255))
            case "darkgreen" => return Some(CssRGBAColor(0, 100, 0, 255))
            case "darkred" => return Some(CssRGBAColor(139, 0, 0, 255))
            case "lightblue" => return Some(CssRGBAColor(173, 216, 230, 255))
            case "lightgreen" => return Some(CssRGBAColor(144, 238, 144, 255))
            case "lightgray" | "lightgrey" => return Some(CssRGBAColor(211, 211, 211, 255))
            case "steelblue" => return Some(CssRGBAColor(70, 130, 180, 255))
            case "forestgreen" => return Some(CssRGBAColor(34, 139, 34, 255))
            case "dodgerblue" => return Some(CssRGBAColor(30, 144, 255, 255))
            case "slategray" | "slategrey" => return Some(CssRGBAColor(112, 128, 144, 255))
            case _ => return None
        }
    }
}

// ============================================================================
// 供应商前缀
// 严格翻译自: css_parser.zig VendorPrefix
// ============================================================================

/// 供应商前缀
/// 严格翻译自 VendorPrefix packed struct (css_parser.zig)
/// 位字段: none, webkit, moz, ms, o
public class VendorPrefix {
    public var none: Bool
    public var webkit: Bool
    public var moz: Bool
    public var ms: Bool
    public var o: Bool

    public init() {
        this.none = false
        this.webkit = false
        this.moz = false
        this.ms = false
        this.o = false
    }

    /// 无前缀
    public static func empty(): VendorPrefix {
        VendorPrefix()
    }

    /// 全部前缀
    /// 严格翻译自 VendorPrefix.all
    public static func allPrefixes(): VendorPrefix {
        let vp = VendorPrefix()
        vp.none = true
        vp.webkit = true
        vp.moz = true
        vp.ms = true
        vp.o = true
        return vp
    }

    public static func webkitPrefix(): VendorPrefix {
        let vp = VendorPrefix()
        vp.webkit = true
        return vp
    }

    public static func mozPrefix(): VendorPrefix {
        let vp = VendorPrefix()
        vp.moz = true
        return vp
    }

    public static func msPrefix(): VendorPrefix {
        let vp = VendorPrefix()
        vp.ms = true
        return vp
    }

    public static func oPrefix(): VendorPrefix {
        let vp = VendorPrefix()
        vp.o = true
        return vp
    }

    /// 是否为空 (没有任何前缀)
    /// 严格翻译自 VendorPrefix.isEmpty
    public func isEmpty(): Bool {
        !webkit && !moz && !ms && !o && !none
    }

    /// 逻辑或 (如果自身为空则返回 other)
    /// 严格翻译自 VendorPrefix._or
    public func or(other: VendorPrefix): VendorPrefix {
        if (isEmpty()) { return other }
        return this
    }

    /// 如果自身为空则返回 None 前缀
    /// 严格翻译自 VendorPrefix.orNone
    public func orNone(): VendorPrefix {
        or(VendorPrefix())
    }

    /// 按位与
    /// 严格翻译自 VendorPrefix.bitwiseAnd
    public func bitwiseAnd(other: VendorPrefix): VendorPrefix {
        let result = VendorPrefix()
        result.none = none && other.none
        result.webkit = webkit && other.webkit
        result.moz = moz && other.moz
        result.ms = ms && other.ms
        result.o = o && other.o
        return result
    }

    /// 差集
    /// 严格翻译自 VendorPrefix.difference
    public func difference(other: VendorPrefix): VendorPrefix {
        let result = VendorPrefix()
        result.none = none && !other.none
        result.webkit = webkit && !other.webkit
        result.moz = moz && !other.moz
        result.ms = ms && !other.ms
        result.o = o && !other.o
        return result
    }

    /// 合并另一个前缀
    public func merge(other: VendorPrefix): Unit {
        if (other.none) { none = true }
        if (other.webkit) { webkit = true }
        if (other.moz) { moz = true }
        if (other.ms) { ms = true }
        if (other.o) { o = true }
    }

    /// 转为 CSS 前缀字符串
    /// 严格翻译自 VendorPrefix.toCss
    public func toString(): String {
        if (webkit) { return "-webkit-" }
        if (moz) { return "-moz-" }
        if (ms) { return "-ms-" }
        if (o) { return "-o-" }
        return ""
    }
}

// ============================================================================
// CSS 长度值单位
// 严格翻译自: values/length.zig LengthValue union(enum)
// ============================================================================

/// CSS 长度单位
/// 严格翻译自 LengthValue union variants
/// 包含绝对单位, 字体相对单位, 视口相对单位, 容器查询单位
public enum CssLengthUnit {
    // 绝对长度单位
    | Px      // px - 像素
    | In      // in - 英寸 (1in = 96px)
    | Cm      // cm - 厘米
    | Mm      // mm - 毫米
    | Q       // Q - 四分之一毫米
    | Pt      // pt - 点 (1pt = 1/72in)
    | Pc      // pc - 派卡 (1pc = 1/6in)

    // 字体相对长度单位
    | Em      // em
    | Rem     // rem
    | Ex      // ex
    | Rex     // rex
    | Ch      // ch
    | Rch     // rch
    | Cap     // cap
    | Rcap    // rcap
    | Ic      // ic
    | Ric     // ric
    | Lh      // lh
    | Rlh     // rlh

    // 视口相对长度单位
    | Vw      // vw
    | Lvw     // lvw
    | Svw     // svw
    | Dvw     // dvw
    | Cqw     // cqw
    | Vh      // vh
    | Lvh     // lvh
    | Svh     // svh
    | Dvh     // dvh
    | Cqh     // cqh
    | Vi      // vi
    | Svi     // svi
    | Lvi     // lvi
    | Dvi     // dvi
    | Cqi     // cqi
    | Vb      // vb
    | Svb     // svb
    | Lvb     // lvb
    | Dvb     // dvb
    | Cqb     // cqb
    | Vmin    // vmin
    | Svmin   // svmin
    | Lvmin   // lvmin
    | Dvmin   // dvmin
    | Cqmin   // cqmin
    | Vmax    // vmax
    | Svmax   // svmax
    | Lvmax   // lvmax
    | Dvmax   // dvmax
    | Cqmax   // cqmax

    public func toString(): String {
        match (this) {
            case Px => "px"
            case In => "in"
            case Cm => "cm"
            case Mm => "mm"
            case Q => "Q"
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
}

// ============================================================================
// CSS 角度单位
// 严格翻译自: values/angle.zig Angle union(Tag)
// ============================================================================

/// CSS 角度单位
/// 严格翻译自 Angle union(Tag) { deg, rad, grad, turn }
public enum CssAngleUnit {
    | Deg     // 度 (360 度一圆)
    | Rad     // 弧度 (2π 弧度一圆)
    | Grad    // 梯度 (400 梯度一圆)
    | Turn    // 圈 (1 圈一圆)

    public func toString(): String {
        match (this) {
            case Deg => "deg"
            case Rad => "rad"
            case Grad => "grad"
            case Turn => "turn"
        }
    }
}

// ============================================================================
// CSS 长度值
// 严格翻译自: values/length.zig LengthValue
// ============================================================================

/// CSS 长度值 (数值 + 单位)
/// 严格翻译自 LengthValue (union of unit-tagged f32)
public class CssLength {
    public var value: Float64
    public var unit: CssLengthUnit

    public init(value: Float64, unit: CssLengthUnit) {
        this.value = value
        this.unit = unit
    }

    public static func px(v: Float64): CssLength {
        CssLength(v, CssLengthUnit.Px)
    }

    public static func em(v: Float64): CssLength {
        CssLength(v, CssLengthUnit.Em)
    }

    public static func rem(v: Float64): CssLength {
        CssLength(v, CssLengthUnit.Rem)
    }

    public static func percent(v: Float64): CssLength {
        CssLength(v, CssLengthUnit.Px)  // 百分比用 CssPercentage
    }

    /// 是否为零
    /// 严格翻译自 LengthValue.isZero
    public func isZero(): Bool {
        value == 0.0
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        "${value}${unit.toString()}"
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// CSS 角度值
// 严格翻译自: values/angle.zig Angle
// ============================================================================

/// CSS 角度值 (数值 + 单位)
/// 严格翻译自 Angle (union of unit-tagged f32)
public class CssAngle {
    public var value: Float64
    public var unit: CssAngleUnit

    public init(value: Float64, unit: CssAngleUnit) {
        this.value = value
        this.unit = unit
    }

    public static func deg(v: Float64): CssAngle {
        CssAngle(v, CssAngleUnit.Deg)
    }

    public static func rad(v: Float64): CssAngle {
        CssAngle(v, CssAngleUnit.Rad)
    }

    public static func grad(v: Float64): CssAngle {
        CssAngle(v, CssAngleUnit.Grad)
    }

    public static func turn(v: Float64): CssAngle {
        CssAngle(v, CssAngleUnit.Turn)
    }

    /// 零值
    /// 严格翻译自 Angle.zero
    public static func zero(): CssAngle {
        CssAngle(0.0, CssAngleUnit.Deg)
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
            case CssAngleUnit.Deg => value
            case CssAngleUnit.Rad => value * 180.0 / 3.14159265358979323846
            case CssAngleUnit.Grad => value * 180.0 / 200.0
            case CssAngleUnit.Turn => value * 360.0
        }
    }

    /// 转换为弧度
    /// 严格翻译自 Angle.toRadians
    public func toRadians(): Float64 {
        let radPerDeg = 3.14159265358979323846 / 180.0
        match (unit) {
            case CssAngleUnit.Deg => value * radPerDeg
            case CssAngleUnit.Rad => value
            case CssAngleUnit.Grad => value * 180.0 / 200.0 * radPerDeg
            case CssAngleUnit.Turn => value * 360.0 * radPerDeg
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        "${value}${unit.toString()}"
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// CSS 百分比值
// 严格翻译自: values/percentage.zig Percentage
// ============================================================================

/// CSS 百分比值
/// 严格翻译自 Percentage struct { v: CSSNumber }
public class CssPercentage {
    public var value: Float64

    public init(value: Float64) {
        this.value = value
    }

    /// 零值
    public static func zero(): CssPercentage {
        CssPercentage(0.0)
    }

    /// 是否为零
    /// 严格翻译自 Percentage.isZero
    public func isZero(): Bool {
        value == 0.0
    }

    /// 相加
    /// 严格翻译自 Percentage.add
    public func add(other: CssPercentage): CssPercentage {
        CssPercentage(value + other.value)
    }

    /// 相乘
    /// 严格翻译自 Percentage.mulF32
    public func mul(other: Float64): CssPercentage {
        CssPercentage(value * other)
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        "${value * 100.0}%"
    }

    public func toString(): String {
        toCss()
    }
}
