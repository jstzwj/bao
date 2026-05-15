// bao_bundler - CSS Values (CSS 值类型系统)
// 严格翻译自: src/css/values/
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
//   对应: values/image.zig - Image
//   对应: values/gradient.zig - Gradient
package bao_bundler

import bao_core.*
import bao_collections.*

// ============================================================================
// CSS 值类型枚举
// ============================================================================

/// CSS 值类型
public enum CssValueType {
    | Ident              // <ident> 标识符
    | CustomIdent        // <custom-ident> 自定义标识符
    | DashedIdent        // <dashed-ident> --var-name
    | String             // <string> 字符串
    | Url                // <url> URL
    | Integer            // <integer> 整数
    | Number             // <number> 数字
    | Percentage         // <percentage> 百分比
    | Length              // <length> 长度
    | Angle              // <angle> 角度
    | Time               // <time> 时间
    | Frequency          // <frequency> 频率
    | Resolution         // <resolution> 分辨率
    | Color              // <color> 颜色
    | Image              // <image> 图像
    | Transform          // <transform> 变换函数
    | Ratio              // <ratio> 比率
    | Calc               // calc() 表达式
    | Var                // var() 引用
    | None               // none
    | Custom             // 自定义值

    /// 获取类型名称
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

/// CSS 值
/// 所有 CSS 值类型的统一表示
public class CssValue {
    /// 值类型
    public var kind: CssValueType
    /// 标识符值 (Ident, CustomIdent, DashedIdent)
    public var text: String
    /// 数值 (Number, Integer, Percentage)
    public var numberValue: Float64
    /// 整数值 (Integer)
    public var intValue: Int64
    /// 单位 (Length, Angle, Time, Frequency, Resolution)
    public var unit: String
    /// 颜色值
    public var color: ?CssColorValue
    /// URL 字符串
    public var urlValue: String
    /// 比率分子
    public var ratioNumerator: Float64
    /// 比率分母
    public var ratioDenominator: Float64
    /// 原始 CSS 文本
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

    /// 创建标识符值
    public static func ident(text: String): CssValue {
        let v = CssValue(CssValueType.Ident)
        v.text = text
        v.raw = text
        return v
    }

    /// 创建自定义标识符
    public static func customIdent(text: String): CssValue {
        let v = CssValue(CssValueType.CustomIdent)
        v.text = text
        v.raw = text
        return v
    }

    /// 创建 Dashed 标识符 (--var)
    public static func dashedIdent(text: String): CssValue {
        let v = CssValue(CssValueType.DashedIdent)
        v.text = text
        v.raw = "--${text}"
        return v
    }

    /// 创建字符串值
    public static func string(text: String): CssValue {
        let v = CssValue(CssValueType.String)
        v.text = text
        v.raw = "\"${text}\""
        return v
    }

    /// 创建 URL 值
    public static func url(urlStr: String): CssValue {
        let v = CssValue(CssValueType.Url)
        v.urlValue = urlStr
        v.raw = "url(${urlStr})"
        return v
    }

    /// 创建整数值
    public static func integer(value: Int64): CssValue {
        let v = CssValue(CssValueType.Integer)
        v.intValue = value
        v.numberValue = Float64(value)
        v.raw = "${value}"
        return v
    }

    /// 创建数字值
    public static func number(value: Float64): CssValue {
        let v = CssValue(CssValueType.Number)
        v.numberValue = value
        v.raw = "${value}"
        return v
    }

    /// 创建百分比值
    public static func percentage(value: Float64): CssValue {
        let v = CssValue(CssValueType.Percentage)
        v.numberValue = value
        v.raw = "${value}%"
        return v
    }

    /// 创建长度值
    public static func length(value: Float64, unit: String): CssValue {
        let v = CssValue(CssValueType.Length)
        v.numberValue = value
        v.unit = unit
        v.raw = "${value}${unit}"
        return v
    }

    /// 创建角度值
    public static func angle(value: Float64, unit: String): CssValue {
        let v = CssValue(CssValueType.Angle)
        v.numberValue = value
        v.unit = unit
        v.raw = "${value}${unit}"
        return v
    }

    /// 创建时间值
    public static func time(value: Float64, unit: String): CssValue {
        let v = CssValue(CssValueType.Time)
        v.numberValue = value
        v.unit = unit
        v.raw = "${value}${unit}"
        return v
    }

    /// 创建颜色值
    public static func color(color: CssColorValue): CssValue {
        let v = CssValue(CssValueType.Color)
        v.color = Some(color)
        v.raw = color.toString()
        return v
    }

    /// 创建比率值
    public static func ratio(numerator: Float64, denominator: Float64): CssValue {
        let v = CssValue(CssValueType.Ratio)
        v.ratioNumerator = numerator
        v.ratioDenominator = denominator
        v.raw = "${numerator}/${denominator}"
        return v
    }

    /// 转为字符串
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
/// 严格翻译自 RGBA struct
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

    /// 透明色
    public static func transparent(): CssRGBAColor {
        CssRGBAColor(0.0, 0.0, 0.0, 0.0)
    }

    /// 黑色
    public static func black(): CssRGBAColor {
        CssRGBAColor(0.0, 0.0, 0.0, 1.0)
    }

    /// 白色
    public static func white(): CssRGBAColor {
        CssRGBAColor(255.0, 255.0, 255.0, 1.0)
    }

    /// Alpha 归一化 (0.0-1.0)
    public func alphaF32(): Float64 {
        alpha / 255.0
    }

    /// 转为 hex 字符串
    public func toHex(): String {
        if (alpha < 255.0) {
            return "#${toHexByte(red)}${toHexByte(green)}${toHexByte(blue)}${toHexByte(alpha)}"
        }
        let hex = "#${toHexByte(red)}${toHexByte(green)}${toHexByte(blue)}"
        // 短格式: #rgb
        if (hex.length == 7 && hex[1] == hex[2] && hex[3] == hex[4] && hex[5] == hex[6]) {
            return "#${hex[1]}${hex[3]}${hex[5]}"
        }
        return hex
    }

    private static func toHexByte(n: Float64): String {
        let v = clamp(n, 0.0, 255.0)
        let hi = Int64(v) >> 4
        let lo = Int64(v) & 0xF
        let hexChars = "0123456789abcdef"
        return "${hexChars[hi]}${hexChars[lo]}"
    }

    /// 转为 rgb() 字符串
    public func toRgbString(): String {
        if (alpha < 255.0) {
            return "rgba(${clampInt(red, 0, 255)}, ${clampInt(green, 0, 255)}, ${clampInt(blue, 0, 255)}, ${alphaF32()})"
        }
        return "rgb(${clampInt(red, 0, 255)}, ${clampInt(green, 0, 255)}, ${clampInt(blue, 0, 255)})"
    }

    private static func clamp(v: Float64, min: Float64, max: Float64): Float64 {
        if (v < min) { min } else if (v > max) { max } else { v }
    }

    private static func clampInt(v: Float64, min: Int64, max: Int64): Int64 {
        let i = Int64(v)
        if (i < min) { min } else if (i > max) { max } else { i }
    }
}

/// HSL 颜色
/// 严格翻译自 HSL struct
public class CssHSLColor {
    public var h: Float64
    public var s: Float64
    public var l: Float64
    public var alpha: Float64

    public init(h: Float64, s: Float64, l: Float64, alpha: Float64) {
        this.h = h
        this.s = s
        this.l = l
        this.alpha = alpha
    }

    /// HSL 转 RGBA
    /// 严格翻译自 HSL -> SRGB 转换
    public func toRGBA(): CssRGBAColor {
        let c = (1.0 - abs(2.0 * l - 1.0)) * s
        let x = c * (1.0 - abs(((h / 60.0) % 2.0) - 1.0))
        let m = l - c / 2.0

        var r: Float64 = 0.0
        var g: Float64 = 0.0
        var b: Float64 = 0.0

        if (h < 60.0) { r = c; g = x; b = 0.0 }
        else if (h < 120.0) { r = x; g = c; b = 0.0 }
        else if (h < 180.0) { r = 0.0; g = c; b = x }
        else if (h < 240.0) { r = 0.0; g = x; b = c }
        else if (h < 300.0) { r = x; g = 0.0; b = c }
        else { r = c; g = 0.0; b = x }

        return CssRGBAColor((r + m) * 255.0, (g + m) * 255.0, (b + m) * 255.0, alpha * 255.0)
    }

    /// 转为字符串
    public func toString(): String {
        if (alpha < 1.0) {
            return "hsla(${h}, ${s * 100.0}%, ${l * 100.0}%, ${alpha})"
        }
        return "hsl(${h}, ${s * 100.0}%, ${l * 100.0}%)"
    }

    private static func abs(v: Float64): Float64 {
        if (v < 0.0) { -v } else { v }
    }
}

/// CSS 颜色值
/// 严格翻译自 CssColor union
public class CssColorValue {
    /// 颜色类型
    public var kind: CssColorKind
    /// RGBA 颜色
    public var rgba: CssRGBAColor
    /// HSL 颜色
    public var hsl: ?CssHSLColor
    /// 命名颜色名
    public var namedColor: String

    public init() {
        this.kind = CssColorKind.Rgba
        this.rgba = CssRGBAColor.black()
        this.hsl = None
        this.namedColor = ""
    }

    public init(rgba: CssRGBAColor) {
        this.kind = CssColorKind.Rgba
        this.rgba = rgba
        this.hsl = None
        this.namedColor = ""
    }

    /// 创建 currentColor
    public static func currentColor(): CssColorValue {
        let c = CssColorValue()
        c.kind = CssColorKind.CurrentColor
        return c
    }

    /// 从命名颜色创建
    public static func named(name: String): ?CssColorValue {
        let rgb = CssNamedColors.lookup(name)
        match (rgb) {
            case Some(rgba) => return Some(CssColorValue(rgba))
            case None => return None
        }
    }

    /// 从 hex 创建
    public static func fromHex(hex: String): ?CssColorValue {
        CssColorParser.parseHex(hex)
    }

    /// 从 RGB 函数创建
    public static func fromRgb(r: Float64, g: Float64, b: Float64, a: Float64): CssColorValue {
        CssColorValue(CssRGBAColor(r, g, b, a * 255.0))
    }

    /// 从 HSL 函数创建
    public static func fromHsl(h: Float64, s: Float64, l: Float64, a: Float64): CssColorValue {
        let hsl = CssHSLColor(h, s, l, a)
        let rgba = hsl.toRGBA()
        let c = CssColorValue(rgba)
        c.hsl = Some(hsl)
        return c
    }

    /// 转为字符串
    public func toString(): String {
        match (kind) {
            case CssColorKind.CurrentColor => "currentColor"
            case CssColorKind.Rgba => rgba.toHex()
            case CssColorKind.Named => namedColor
        }
    }
}

/// 颜色类型
public enum CssColorKind {
    | CurrentColor
    | Rgba
    | Named
}

// ============================================================================
// 命名颜色表
// 严格翻译自: values/color_generated.zig
// ============================================================================

/// CSS 命名颜色查找表
/// 严格翻译自 color_generated 中的颜色表
public class CssNamedColors {
    /// 查找命名颜色, 返回 RGBA (r, g, b 各 0-255, alpha 255)
    public static func lookup(name: String): ?CssRGBAColor {
        let key = name.toLowerCase()
        match (key) {
            // 基本颜色 (16 种 HTML 颜色)
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

            // 扩展颜色 (SVG 颜色)
            case "aliceblue" => return Some(CssRGBAColor(240, 248, 255, 255))
            case "antiquewhite" => return Some(CssRGBAColor(250, 235, 215, 255))
            case "aquamarine" => return Some(CssRGBAColor(127, 255, 212, 255))
            case "azure" => return Some(CssRGBAColor(240, 255, 255, 255))
            case "beige" => return Some(CssRGBAColor(245, 245, 220, 255))
            case "bisque" => return Some(CssRGBAColor(255, 228, 196, 255))
            case "blanchedalmond" => return Some(CssRGBAColor(255, 235, 205, 255))
            case "blueviolet" => return Some(CssRGBAColor(138, 43, 226, 255))
            case "brown" => return Some(CssRGBAColor(165, 42, 42, 255))
            case "burlywood" => return Some(CssRGBAColor(222, 184, 135, 255))
            case "cadetblue" => return Some(CssRGBAColor(95, 158, 160, 255))
            case "chartreuse" => return Some(CssRGBAColor(127, 255, 0, 255))
            case "chocolate" => return Some(CssRGBAColor(210, 105, 30, 255))
            case "coral" => return Some(CssRGBAColor(255, 127, 80, 255))
            case "cornflowerblue" => return Some(CssRGBAColor(100, 149, 237, 255))
            case "cornsilk" => return Some(CssRGBAColor(255, 248, 220, 255))
            case "crimson" => return Some(CssRGBAColor(220, 20, 60, 255))
            case "darkblue" => return Some(CssRGBAColor(0, 0, 139, 255))
            case "darkcyan" => return Some(CssRGBAColor(0, 139, 139, 255))
            case "darkgoldenrod" => return Some(CssRGBAColor(184, 134, 11, 255))
            case "darkgray" | "darkgrey" => return Some(CssRGBAColor(169, 169, 169, 255))
            case "darkgreen" => return Some(CssRGBAColor(0, 100, 0, 255))
            case "darkkhaki" => return Some(CssRGBAColor(189, 183, 107, 255))
            case "darkmagenta" => return Some(CssRGBAColor(139, 0, 139, 255))
            case "darkolivegreen" => return Some(CssRGBAColor(85, 107, 47, 255))
            case "darkorange" => return Some(CssRGBAColor(255, 140, 0, 255))
            case "darkorchid" => return Some(CssRGBAColor(153, 50, 204, 255))
            case "darkred" => return Some(CssRGBAColor(139, 0, 0, 255))
            case "darksalmon" => return Some(CssRGBAColor(233, 150, 122, 255))
            case "darkseagreen" => return Some(CssRGBAColor(143, 188, 143, 255))
            case "darkslateblue" => return Some(CssRGBAColor(72, 61, 139, 255))
            case "darkslategray" | "darkslategrey" => return Some(CssRGBAColor(47, 79, 79, 255))
            case "darkturquoise" => return Some(CssRGBAColor(0, 206, 209, 255))
            case "darkviolet" => return Some(CssRGBAColor(148, 0, 211, 255))
            case "deeppink" => return Some(CssRGBAColor(255, 20, 147, 255))
            case "deepskyblue" => return Some(CssRGBAColor(0, 191, 255, 255))
            case "dimgray" | "dimgrey" => return Some(CssRGBAColor(105, 105, 105, 255))
            case "dodgerblue" => return Some(CssRGBAColor(30, 144, 255, 255))
            case "firebrick" => return Some(CssRGBAColor(178, 34, 34, 255))
            case "floralwhite" => return Some(CssRGBAColor(255, 250, 240, 255))
            case "forestgreen" => return Some(CssRGBAColor(34, 139, 34, 255))
            case "gainsboro" => return Some(CssRGBAColor(220, 220, 220, 255))
            case "ghostwhite" => return Some(CssRGBAColor(248, 248, 255, 255))
            case "gold" => return Some(CssRGBAColor(255, 215, 0, 255))
            case "goldenrod" => return Some(CssRGBAColor(218, 165, 32, 255))
            case "greenyellow" => return Some(CssRGBAColor(173, 255, 47, 255))
            case "honeydew" => return Some(CssRGBAColor(240, 255, 240, 255))
            case "hotpink" => return Some(CssRGBAColor(255, 105, 180, 255))
            case "indianred" => return Some(CssRGBAColor(205, 92, 92, 255))
            case "indigo" => return Some(CssRGBAColor(75, 0, 130, 255))
            case "ivory" => return Some(CssRGBAColor(255, 255, 240, 255))
            case "khaki" => return Some(CssRGBAColor(240, 230, 140, 255))
            case "lavender" => return Some(CssRGBAColor(230, 230, 250, 255))
            case "lavenderblush" => return Some(CssRGBAColor(255, 240, 245, 255))
            case "lawngreen" => return Some(CssRGBAColor(124, 252, 0, 255))
            case "lemonchiffon" => return Some(CssRGBAColor(255, 250, 205, 255))
            case "lightblue" => return Some(CssRGBAColor(173, 216, 230, 255))
            case "lightcoral" => return Some(CssRGBAColor(240, 128, 128, 255))
            case "lightcyan" => return Some(CssRGBAColor(224, 255, 255, 255))
            case "lightgoldenrodyellow" => return Some(CssRGBAColor(250, 250, 210, 255))
            case "lightgray" | "lightgrey" => return Some(CssRGBAColor(211, 211, 211, 255))
            case "lightgreen" => return Some(CssRGBAColor(144, 238, 144, 255))
            case "lightpink" => return Some(CssRGBAColor(255, 182, 193, 255))
            case "lightsalmon" => return Some(CssRGBAColor(255, 160, 122, 255))
            case "lightseagreen" => return Some(CssRGBAColor(32, 178, 170, 255))
            case "lightskyblue" => return Some(CssRGBAColor(135, 206, 250, 255))
            case "lightslategray" | "lightslategrey" => return Some(CssRGBAColor(119, 136, 153, 255))
            case "lightsteelblue" => return Some(CssRGBAColor(176, 196, 222, 255))
            case "lightyellow" => return Some(CssRGBAColor(255, 255, 224, 255))
            case "limegreen" => return Some(CssRGBAColor(50, 205, 50, 255))
            case "linen" => return Some(CssRGBAColor(250, 240, 230, 255))
            case "magenta" => return Some(CssRGBAColor(255, 0, 255, 255))
            case "mediumaquamarine" => return Some(CssRGBAColor(102, 205, 170, 255))
            case "mediumblue" => return Some(CssRGBAColor(0, 0, 205, 255))
            case "mediumorchid" => return Some(CssRGBAColor(186, 85, 211, 255))
            case "mediumpurple" => return Some(CssRGBAColor(147, 112, 219, 255))
            case "mediumseagreen" => return Some(CssRGBAColor(60, 179, 113, 255))
            case "mediumslateblue" => return Some(CssRGBAColor(123, 104, 238, 255))
            case "mediumspringgreen" => return Some(CssRGBAColor(0, 250, 154, 255))
            case "mediumturquoise" => return Some(CssRGBAColor(72, 209, 204, 255))
            case "mediumvioletred" => return Some(CssRGBAColor(199, 21, 133, 255))
            case "midnightblue" => return Some(CssRGBAColor(25, 25, 112, 255))
            case "mintcream" => return Some(CssRGBAColor(245, 255, 250, 255))
            case "mistyrose" => return Some(CssRGBAColor(255, 228, 225, 255))
            case "moccasin" => return Some(CssRGBAColor(255, 228, 181, 255))
            case "navajowhite" => return Some(CssRGBAColor(255, 222, 173, 255))
            case "oldlace" => return Some(CssRGBAColor(253, 245, 230, 255))
            case "olivedrab" => return Some(CssRGBAColor(107, 142, 35, 255))
            case "orange" => return Some(CssRGBAColor(255, 165, 0, 255))
            case "orangered" => return Some(CssRGBAColor(255, 69, 0, 255))
            case "orchid" => return Some(CssRGBAColor(218, 112, 214, 255))
            case "palegoldenrod" => return Some(CssRGBAColor(238, 232, 170, 255))
            case "palegreen" => return Some(CssRGBAColor(152, 251, 152, 255))
            case "paleturquoise" => return Some(CssRGBAColor(175, 238, 238, 255))
            case "palevioletred" => return Some(CssRGBAColor(219, 112, 147, 255))
            case "papayawhip" => return Some(CssRGBAColor(255, 239, 213, 255))
            case "peachpuff" => return Some(CssRGBAColor(255, 218, 185, 255))
            case "peru" => return Some(CssRGBAColor(205, 133, 63, 255))
            case "pink" => return Some(CssRGBAColor(255, 192, 203, 255))
            case "plum" => return Some(CssRGBAColor(221, 160, 221, 255))
            case "powderblue" => return Some(CssRGBAColor(176, 224, 230, 255))
            case "rosybrown" => return Some(CssRGBAColor(188, 143, 143, 255))
            case "royalblue" => return Some(CssRGBAColor(65, 105, 225, 255))
            case "saddlebrown" => return Some(CssRGBAColor(139, 69, 19, 255))
            case "salmon" => return Some(CssRGBAColor(250, 128, 114, 255))
            case "sandybrown" => return Some(CssRGBAColor(244, 164, 96, 255))
            case "seagreen" => return Some(CssRGBAColor(46, 139, 87, 255))
            case "seashell" => return Some(CssRGBAColor(255, 245, 238, 255))
            case "sienna" => return Some(CssRGBAColor(160, 82, 45, 255))
            case "skyblue" => return Some(CssRGBAColor(135, 206, 235, 255))
            case "slateblue" => return Some(CssRGBAColor(106, 90, 205, 255))
            case "slategray" | "slategrey" => return Some(CssRGBAColor(112, 128, 144, 255))
            case "snow" => return Some(CssRGBAColor(255, 250, 250, 255))
            case "springgreen" => return Some(CssRGBAColor(0, 255, 127, 255))
            case "steelblue" => return Some(CssRGBAColor(70, 130, 180, 255))
            case "tan" => return Some(CssRGBAColor(210, 180, 140, 255))
            case "thistle" => return Some(CssRGBAColor(216, 191, 216, 255))
            case "tomato" => return Some(CssRGBAColor(255, 99, 71, 255))
            case "turquoise" => return Some(CssRGBAColor(64, 224, 208, 255))
            case "violet" => return Some(CssRGBAColor(238, 130, 238, 255))
            case "wheat" => return Some(CssRGBAColor(245, 222, 179, 255))
            case "whitesmoke" => return Some(CssRGBAColor(245, 245, 245, 255))
            case "yellowgreen" => return Some(CssRGBAColor(154, 205, 50, 255))

            // transparent
            case "transparent" => return Some(CssRGBAColor(0, 0, 0, 0))

            case _ => return None
        }
    }
}

// ============================================================================
// 颜色解析器
// 严格翻译自: values/color.zig CssColor.parse
// ============================================================================

/// CSS 颜色解析器
public class CssColorParser {
    /// 解析颜色值
    /// 支持: hex, rgb(), rgba(), hsl(), hsla(), named colors, currentColor
    public static func parse(input: String): ?CssColorValue {
        let s = input.trim()

        // currentColor
        if (s.toLowerCase() == "currentcolor") {
            return CssColorValue.currentColor()
        }

        // transparent
        if (s.toLowerCase() == "transparent") {
            return Some(CssColorValue(CssRGBAColor.transparent()))
        }

        // 命名颜色
        let named = CssColorValue.named(s)
        if (named != None) { return named }

        // Hex 颜色
        if (s[0] == '#') {
            return parseHex(s)
        }

        // 函数式颜色
        let lower = s.toLowerCase()
        if (lower.startsWith("rgb(") || lower.startsWith("rgba(")) {
            return parseRgbFunction(s)
        }
        if (lower.startsWith("hsl(") || lower.startsWith("hsla(")) {
            return parseHslFunction(s)
        }

        return None
    }

    /// 解析 hex 颜色
    /// 支持: #rgb, #rgba, #rrggbb, #rrggbbaa
    public static func parseHex(hex: String): ?CssColorValue {
        if (hex.length < 2 || hex[0] != '#') { return None }

        let digits = hex.substring(1)
        match (digits.length) {
            case 3 =>
                // #rgb -> r=A, g=B, b=C
                let r = parseHexDigit(digits[0]) * 17
                let g = parseHexDigit(digits[1]) * 17
                let b = parseHexDigit(digits[2]) * 17
                return Some(CssColorValue(CssRGBAColor(Float64(r), Float64(g), Float64(b), 255.0)))
            case 4 =>
                // #rgba -> r=A, g=B, b=C, a=D
                let r = parseHexDigit(digits[0]) * 17
                let g = parseHexDigit(digits[1]) * 17
                let b = parseHexDigit(digits[2]) * 17
                let a = parseHexDigit(digits[3]) * 17
                return Some(CssColorValue(CssRGBAColor(Float64(r), Float64(g), Float64(b), Float64(a))))
            case 6 =>
                // #rrggbb
                let r = parseHexDigit(digits[0]) * 16 + parseHexDigit(digits[1])
                let g = parseHexDigit(digits[2]) * 16 + parseHexDigit(digits[3])
                let b = parseHexDigit(digits[4]) * 16 + parseHexDigit(digits[5])
                return Some(CssColorValue(CssRGBAColor(Float64(r), Float64(g), Float64(b), 255.0)))
            case 8 =>
                // #rrggbbaa
                let r = parseHexDigit(digits[0]) * 16 + parseHexDigit(digits[1])
                let g = parseHexDigit(digits[2]) * 16 + parseHexDigit(digits[3])
                let b = parseHexDigit(digits[4]) * 16 + parseHexDigit(digits[5])
                let a = parseHexDigit(digits[6]) * 16 + parseHexDigit(digits[7])
                return Some(CssColorValue(CssRGBAColor(Float64(r), Float64(g), Float64(b), Float64(a))))
            case _ => return None
        }
    }

    /// 解析 rgb()/rgba() 函数
    public static func parseRgbFunction(input: String): ?CssColorValue {
        let s = input.trim()
        // 提取括号内容
        let openParen = s.indexOf('(')
        if (openParen == None) { return None }
        let closeParen = s.indexOf(')')
        if (closeParen == None) { return None }

        let content = s.substring(openParen + 1, closeParen).trim()
        let parts = splitCssFunctionArgs(content)

        if (parts.size == 3 || parts.size == 4) {
            let r = parseColorComponent(parts[0])
            let g = parseColorComponent(parts[1])
            let b = parseColorComponent(parts[2])
            var a: Float64 = 255.0
            if (parts.size == 4) {
                let aVal = parseAlphaComponent(parts[3])
                a = aVal * 255.0
            }
            return Some(CssColorValue(CssRGBAColor(r, g, b, a)))
        }
        return None
    }

    /// 解析 hsl()/hsla() 函数
    public static func parseHslFunction(input: String): ?CssColorValue {
        let s = input.trim()
        let openParen = s.indexOf('(')
        if (openParen == None) { return None }
        let closeParen = s.indexOf(')')
        if (closeParen == None) { return None }

        let content = s.substring(openParen + 1, closeParen).trim()
        let parts = splitCssFunctionArgs(content)

        if (parts.size == 3 || parts.size == 4) {
            let h = parseAngleOrNumber(parts[0])
            let sat = parsePercentageOrNumber(parts[1])
            let l = parsePercentageOrNumber(parts[2])
            var a: Float64 = 1.0
            if (parts.size == 4) {
                a = parseAlphaComponent(parts[3])
            }
            return Some(CssColorValue.fromHsl(h, sat, l, a))
        }
        return None
    }

    // ========================================================================
    // 解析辅助
    // ========================================================================

    private static func parseHexDigit(c: UInt8): Int64 {
        if (c >= '0' && c <= '9') { return Int64(c - '0') }
        if (c >= 'a' && c <= 'f') { return Int64(c - 'a' + 10) }
        if (c >= 'A' && c <= 'F') { return Int64(c - 'A' + 10) }
        return 0
    }

    private static func parseColorComponent(s: String): Float64 {
        let trimmed = s.trim()
        if (trimmed.endsWith("%")) {
            let pct = parseFloat(trimmed.substring(0, trimmed.length - 1))
            return clamp(pct / 100.0 * 255.0, 0.0, 255.0)
        }
        return clamp(parseFloat(trimmed), 0.0, 255.0)
    }

    private static func parseAlphaComponent(s: String): Float64 {
        let trimmed = s.trim()
        if (trimmed.endsWith("%")) {
            let pct = parseFloat(trimmed.substring(0, trimmed.length - 1))
            return clamp(pct / 100.0, 0.0, 1.0)
        }
        return clamp(parseFloat(trimmed), 0.0, 1.0)
    }

    private static func parseAngleOrNumber(s: String): Float64 {
        let trimmed = s.trim()
        if (trimmed.endsWith("deg")) { return parseFloat(trimmed.substring(0, trimmed.length - 3)) }
        if (trimmed.endsWith("rad")) { return parseFloat(trimmed.substring(0, trimmed.length - 3)) * 180.0 / 3.14159265 }
        if (trimmed.endsWith("turn")) { return parseFloat(trimmed.substring(0, trimmed.length - 4)) * 360.0 }
        return parseFloat(trimmed)
    }

    private static func parsePercentageOrNumber(s: String): Float64 {
        let trimmed = s.trim()
        if (trimmed.endsWith("%")) {
            return parseFloat(trimmed.substring(0, trimmed.length - 1)) / 100.0
        }
        return parseFloat(trimmed)
    }

    private static func splitCssFunctionArgs(s: String): ArrayList<String> {
        let parts = ArrayList<String>()
        let sb = StringBuilder()
        var depth: Int64 = 0
        for (c in s) {
            if (c == '(') { depth++ }
            if (c == ')') { depth-- }
            if (c == ',' && depth == 0) {
                parts.append(sb.toString().trim())
                sb.clear()
            } else {
                sb.append(c)
            }
        }
        let last = sb.toString().trim()
        if (last.length > 0) {
            parts.append(last)
        }
        return parts
    }

    private static func parseFloat(s: String): Float64 {
        var result: Float64 = 0.0
        var sign: Float64 = 1.0
        var i: Int64 = 0

        if (i < s.length && s[i] == '-') { sign = -1.0; i++ }
        else if (i < s.length && s[i] == '+') { i++ }

        while (i < s.length && s[i] >= '0' && s[i] <= '9') {
            result = result * 10.0 + Float64(s[i] - '0')
            i++
        }

        if (i < s.length && s[i] == '.') {
            i++
            var frac: Float64 = 0.1
            while (i < s.length && s[i] >= '0' && s[i] <= '9') {
                result += Float64(s[i] - '0') * frac
                frac *= 0.1
                i++
            }
        }

        return result * sign
    }

    private static func clamp(v: Float64, min: Float64, max: Float64): Float64 {
        if (v < min) { min } else if (v > max) { max } else { v }
    }
}

// ============================================================================
// CSS 单位转换表
// 严格翻译自: values/length.zig 中的常量
// ============================================================================

/// CSS 单位转换工具
/// 严格翻译自各 values/*.zig 中的单位定义
public class CssUnitConversion {
    // 长度单位 (转换为 px)
    // 严格翻译自 length.zig
    public static let PX_PER_IN: Float64 = 96.0
    public static let PX_PER_CM: Float64 = PX_PER_IN / 2.54
    public static let PX_PER_MM: Float64 = PX_PER_CM / 10.0
    public static let PX_PER_Q: Float64 = PX_PER_CM / 40.0
    public static let PX_PER_PT: Float64 = PX_PER_IN / 72.0
    public static let PX_PER_PC: Float64 = PX_PER_IN / 6.0

    // 角度单位 (转换为 deg)
    // 严格翻译自 angle.zig
    public static let DEG_PER_RAD: Float64 = 180.0 / 3.14159265358979
    public static let DEG_PER_GRAD: Float64 = 0.9     // 360/400
    public static let DEG_PER_TURN: Float64 = 360.0

    // 时间单位 (转换为 s)
    // 严格翻译自 time.zig
    public static let S_PER_MS: Float64 = 0.001

    // 频率单位 (转换为 Hz)
    public static let HZ_PER_KHZ: Float64 = 1000.0

    // 分辨率单位 (转换为 dppx)
    // 严格翻译自 resolution.zig
    public static let DPPX_PER_DPI: Float64 = 1.0 / 96.0
    public static let DPPX_PER_DPCM: Float64 = PX_PER_CM / 96.0

    /// 将长度值转换为 px
    public static func lengthToPx(value: Float64, unit: String): Float64 {
        match (unit.toLowerCase()) {
            case "px" => value
            case "in" => value * PX_PER_IN
            case "cm" => value * PX_PER_CM
            case "mm" => value * PX_PER_MM
            case "q" => value * PX_PER_Q
            case "pt" => value * PX_PER_PT
            case "pc" => value * PX_PER_PC
            case "vw" | "vh" | "vmin" | "vmax" |
                 "em" | "rem" | "ex" | "rex" | "ch" | "rch" |
                 "cap" | "rcap" | "ic" | "ric" | "lh" | "rlh" => value // 相对单位需要上下文
            case _ => value
        }
    }

    /// 将角度值转换为 deg
    public static func angleToDeg(value: Float64, unit: String): Float64 {
        match (unit.toLowerCase()) {
            case "deg" => value
            case "rad" => value * DEG_PER_RAD
            case "grad" => value * DEG_PER_GRAD
            case "turn" => value * DEG_PER_TURN
            case _ => value
        }
    }

    /// 将时间值转换为 s
    public static func timeToS(value: Float64, unit: String): Float64 {
        match (unit.toLowerCase()) {
            case "s" => value
            case "ms" => value * S_PER_MS
            case _ => value
        }
    }

    /// 将频率值转换为 Hz
    public static func frequencyToHz(value: Float64, unit: String): Float64 {
        match (unit.toLowerCase()) {
            case "hz" => value
            case "khz" => value * HZ_PER_KHZ
            case _ => value
        }
    }
}

// ============================================================================
// CSS 值解析器
// ============================================================================

/// CSS 值解析器
/// 从 CSS 文本解析出 CssValue
public class CssValueParser {
    /// 解析 CSS 值
    public static func parseValue(input: String): ?CssValue {
        let s = input.trim()
        if (s.length == 0) { return None }

        // none
        if (s.toLowerCase() == "none") {
            return CssValue(CssValueType.None)
        }

        // var()
        if (s.toLowerCase().startsWith("var(")) {
            let v = CssValue(CssValueType.Var)
            v.raw = s
            return v
        }

        // calc()
        if (s.toLowerCase().startsWith("calc(")) {
            let v = CssValue(CssValueType.Calc)
            v.raw = s
            return v
        }

        // 颜色: 先试 hex
        if (s[0] == '#') {
            let color = CssColorParser.parseHex(s)
            match (color) {
                case Some(c) => return CssValue.color(c)
                case None => ()
            }
        }

        // 颜色函数
        let lower = s.toLowerCase()
        if (lower.startsWith("rgb(") || lower.startsWith("rgba(") ||
            lower.startsWith("hsl(") || lower.startsWith("hsla(")) {
            let color = CssColorParser.parse(s)
            match (color) {
                case Some(c) => return CssValue.color(c)
                case None => ()
            }
        }

        // 命名颜色
        let namedColor = CssColorValue.named(s)
        if (namedColor != None) {
            match (namedColor) {
                case Some(c) => return CssValue.color(c)
                case None => ()
            }
        }

        // currentColor
        if (lower == "currentcolor") {
            return CssValue.color(CssColorValue.currentColor())
        }

        // url()
        if (lower.startsWith("url(")) {
            let urlContent = extractFunctionArg(s, 4)
            return CssValue.url(urlContent)
        }

        // 百分比
        if (s.endsWith("%")) {
            let numStr = s.substring(0, s.length - 1)
            let num = parseFloat64(numStr)
            return CssValue.percentage(num / 100.0)
        }

        // 带单位的值: 尝试匹配 数字+单位
        let unitMatch = matchDimension(s)
        if (unitMatch != None) {
            return unitMatch
        }

        // 纯数字
        let numVal = parseFloat64Strict(s)
        if (numVal != None) {
            match (numVal) {
                case Some(v) =>
                    if (s.contains(".")) {
                        return CssValue.number(v)
                    }
                    return CssValue.integer(Int64(v))
                case None => ()
            }
        }

        // 字符串
        if ((s[0] == '"' && s[s.length - 1] == '"') ||
            (s[0] == '\'' && s[s.length - 1] == '\'')) {
            return CssValue.string(s.substring(1, s.length - 1))
        }

        // 标识符
        return CssValue.ident(s)
    }

    /// 尝试匹配带单位的维度值
    private static func matchDimension(s: String): ?CssValue {
        // 找到数字部分结束位置
        var i: Int64 = 0
        if (i < s.length && (s[i] == '+' || s[i] == '-')) { i++ }
        while (i < s.length && s[i] >= '0' && s[i] <= '9') { i++ }
        if (i < s.length && s[i] == '.') {
            i++
            while (i < s.length && s[i] >= '0' && s[i] <= '9') { i++ }
        }
        // 需要有单位
        if (i == 0 || i >= s.length) { return None }

        let numStr = s.substring(0, i)
        let unit = s.substring(i).toLowerCase()
        let value = parseFloat64(numStr)

        // 长度单位
        if (isLengthUnit(unit)) {
            return CssValue.length(value, unit)
        }

        // 角度单位
        if (isAngleUnit(unit)) {
            return CssValue.angle(value, unit)
        }

        // 时间单位
        if (isTimeUnit(unit)) {
            return CssValue.time(value, unit)
        }

        // 频率单位
        if (unit == "hz" || unit == "khz") {
            let v = CssValue(CssValueType.Frequency)
            v.numberValue = value
            v.unit = unit
            v.raw = s
            return v
        }

        // 分辨率单位
        if (unit == "dpi" || unit == "dpcm" || unit == "dppx" || unit == "x") {
            let v = CssValue(CssValueType.Resolution)
            v.numberValue = value
            v.unit = unit
            v.raw = s
            return v
        }

        return None
    }

    private static func isLengthUnit(unit: String): Bool {
        match (unit) {
            case "px" | "in" | "cm" | "mm" | "q" | "pt" | "pc" |
                 "em" | "rem" | "ex" | "ch" | "vw" | "vh" | "vmin" | "vmax" |
                 "cap" | "ic" | "lh" | "rlh" | "rex" | "rch" | "rcap" | "ric" => true
            case _ => false
        }
    }

    private static func isAngleUnit(unit: String): Bool {
        match (unit) {
            case "deg" | "rad" | "grad" | "turn" => true
            case _ => false
        }
    }

    private static func isTimeUnit(unit: String): Bool {
        match (unit) {
            case "s" | "ms" => true
            case _ => false
        }
    }

    private static func extractFunctionArg(s: String, prefixLen: Int64): String {
        if (s.length > prefixLen + 1) {
            s.substring(prefixLen, s.length - 1).trim()
        } else {
            ""
        }
    }

    private static func parseFloat64(s: String): Float64 {
        var result: Float64 = 0.0
        var sign: Float64 = 1.0
        var i: Int64 = 0
        if (i < s.length && s[i] == '-') { sign = -1.0; i++ }
        else if (i < s.length && s[i] == '+') { i++ }
        while (i < s.length && s[i] >= '0' && s[i] <= '9') {
            result = result * 10.0 + Float64(s[i] - '0')
            i++
        }
        if (i < s.length && s[i] == '.') {
            i++
            var frac: Float64 = 0.1
            while (i < s.length && s[i] >= '0' && s[i] <= '9') {
                result += Float64(s[i] - '0') * frac
                frac *= 0.1
                i++
            }
        }
        return result * sign
    }

    private static func parseFloat64Strict(s: String): ?Float64 {
        var result: Float64 = 0.0
        var sign: Float64 = 1.0
        var i: Int64 = 0
        var hasDigit: Bool = false

        if (i < s.length && s[i] == '-') { sign = -1.0; i++ }
        else if (i < s.length && s[i] == '+') { i++ }

        while (i < s.length && s[i] >= '0' && s[i] <= '9') {
            result = result * 10.0 + Float64(s[i] - '0')
            hasDigit = true
            i++
        }
        if (i < s.length && s[i] == '.') {
            i++
            var frac: Float64 = 0.1
            while (i < s.length && s[i] >= '0' && s[i] <= '9') {
                result += Float64(s[i] - '0') * frac
                frac *= 0.1
                hasDigit = true
                i++
            }
        }

        if (!hasDigit || i < s.length) { return None }
        return Some(result * sign)
    }
}
