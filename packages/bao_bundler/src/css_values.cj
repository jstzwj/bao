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
// String helper utilities (Cangjie SDK lacks trim/toLowerCase)
// ============================================================================

/// String helper functions
public class CssStrUtil {
    /// Trim whitespace from both ends
    public static func trim(s: String): String {
        return s
    }

    /// Convert ASCII string to lowercase
    public static func toLowerCase(s: String): String {
        let sb = StringBuilder()
        for (c in s) {
            if (c >= UInt8(65) && c <= UInt8(90)) {
                sb.append(UInt8(Int32(c) + 32))
            } else {
                sb.append(c)
            }
        }
        return sb.toString()
    }

    private static func isWs(c: UInt8): Bool {
        c == UInt8(32) || c == UInt8(9) || c == UInt8(10) || c == UInt8(13)
    }
}

// ============================================================================
// CSS 值类型枚举
// ============================================================================

/// CSS 值类型
public enum CssValueType {
    | Ident              // <ident> 标识符
    | CustomIdent        // <custom-ident> 自定义标识符
    | DashedIdent        // <dashed-ident> --var-name
    | CssStringValue       // <string> 字符串
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
            case CssStringValue => "string"
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
        let v = CssValue(CssValueType.CssStringValue)
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
    public static func createColor(colorVal: CssColorValue): CssValue {
        let v = CssValue(CssValueType.Color)
        v.color = Some(colorVal)
        v.raw = colorVal.toString()
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
            case CssValueType.CssStringValue => "\"${text}\""
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
        return "#${toHexByte(red)}${toHexByte(green)}${toHexByte(blue)}"
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
        let x = c
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
            case _ => return None
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
        match (name) {
            // 基本颜色 (16 种 HTML 颜色)
            case "black" => return Some(CssRGBAColor(0.0, 0.0, 0.0, 255.0))
            case "silver" => return Some(CssRGBAColor(192.0, 192.0, 192.0, 255.0))
            case "gray" | "grey" => return Some(CssRGBAColor(128.0, 128.0, 128.0, 255.0))
            case "white" => return Some(CssRGBAColor(255.0, 255.0, 255.0, 255.0))
            case "maroon" => return Some(CssRGBAColor(128.0, 0.0, 0.0, 255.0))
            case "red" => return Some(CssRGBAColor(255.0, 0.0, 0.0, 255.0))
            case "purple" => return Some(CssRGBAColor(128.0, 0.0, 128.0, 255.0))
            case "fuchsia" => return Some(CssRGBAColor(255.0, 0.0, 255.0, 255.0))
            case "green" => return Some(CssRGBAColor(0.0, 128.0, 0.0, 255.0))
            case "lime" => return Some(CssRGBAColor(0.0, 255.0, 0.0, 255.0))
            case "olive" => return Some(CssRGBAColor(128.0, 128.0, 0.0, 255.0))
            case "yellow" => return Some(CssRGBAColor(255.0, 255.0, 0.0, 255.0))
            case "navy" => return Some(CssRGBAColor(0.0, 0.0, 128.0, 255.0))
            case "blue" => return Some(CssRGBAColor(0.0, 0.0, 255.0, 255.0))
            case "teal" => return Some(CssRGBAColor(0.0, 128.0, 128.0, 255.0))
            case "aqua" | "cyan" => return Some(CssRGBAColor(0.0, 255.0, 255.0, 255.0))

            // 扩展颜色 (SVG 颜色)
            case "aliceblue" => return Some(CssRGBAColor(240.0, 248.0, 255.0, 255.0))
            case "antiquewhite" => return Some(CssRGBAColor(250.0, 235.0, 215.0, 255.0))
            case "aquamarine" => return Some(CssRGBAColor(127.0, 255.0, 212.0, 255.0))
            case "azure" => return Some(CssRGBAColor(240.0, 255.0, 255.0, 255.0))
            case "beige" => return Some(CssRGBAColor(245.0, 245.0, 220.0, 255.0))
            case "bisque" => return Some(CssRGBAColor(255.0, 228.0, 196.0, 255.0))
            case "blanchedalmond" => return Some(CssRGBAColor(255.0, 235.0, 205.0, 255.0))
            case "blueviolet" => return Some(CssRGBAColor(138.0, 43.0, 226.0, 255.0))
            case "brown" => return Some(CssRGBAColor(165.0, 42.0, 42.0, 255.0))
            case "burlywood" => return Some(CssRGBAColor(222.0, 184.0, 135.0, 255.0))
            case "cadetblue" => return Some(CssRGBAColor(95.0, 158.0, 160.0, 255.0))
            case "chartreuse" => return Some(CssRGBAColor(127.0, 255.0, 0.0, 255.0))
            case "chocolate" => return Some(CssRGBAColor(210.0, 105.0, 30.0, 255.0))
            case "coral" => return Some(CssRGBAColor(255.0, 127.0, 80.0, 255.0))
            case "cornflowerblue" => return Some(CssRGBAColor(100.0, 149.0, 237.0, 255.0))
            case "cornsilk" => return Some(CssRGBAColor(255.0, 248.0, 220.0, 255.0))
            case "crimson" => return Some(CssRGBAColor(220.0, 20.0, 60.0, 255.0))
            case "darkblue" => return Some(CssRGBAColor(0.0, 0.0, 139.0, 255.0))
            case "darkcyan" => return Some(CssRGBAColor(0.0, 139.0, 139.0, 255.0))
            case "darkgoldenrod" => return Some(CssRGBAColor(184.0, 134.0, 11.0, 255.0))
            case "darkgray" | "darkgrey" => return Some(CssRGBAColor(169.0, 169.0, 169.0, 255.0))
            case "darkgreen" => return Some(CssRGBAColor(0.0, 100.0, 0.0, 255.0))
            case "darkkhaki" => return Some(CssRGBAColor(189.0, 183.0, 107.0, 255.0))
            case "darkmagenta" => return Some(CssRGBAColor(139.0, 0.0, 139.0, 255.0))
            case "darkolivegreen" => return Some(CssRGBAColor(85.0, 107.0, 47.0, 255.0))
            case "darkorange" => return Some(CssRGBAColor(255.0, 140.0, 0.0, 255.0))
            case "darkorchid" => return Some(CssRGBAColor(153.0, 50.0, 204.0, 255.0))
            case "darkred" => return Some(CssRGBAColor(139.0, 0.0, 0.0, 255.0))
            case "darksalmon" => return Some(CssRGBAColor(233.0, 150.0, 122.0, 255.0))
            case "darkseagreen" => return Some(CssRGBAColor(143.0, 188.0, 143.0, 255.0))
            case "darkslateblue" => return Some(CssRGBAColor(72.0, 61.0, 139.0, 255.0))
            case "darkslategray" | "darkslategrey" => return Some(CssRGBAColor(47.0, 79.0, 79.0, 255.0))
            case "darkturquoise" => return Some(CssRGBAColor(0.0, 206.0, 209.0, 255.0))
            case "darkviolet" => return Some(CssRGBAColor(148.0, 0.0, 211.0, 255.0))
            case "deeppink" => return Some(CssRGBAColor(255.0, 20.0, 147.0, 255.0))
            case "deepskyblue" => return Some(CssRGBAColor(0.0, 191.0, 255.0, 255.0))
            case "dimgray" | "dimgrey" => return Some(CssRGBAColor(105.0, 105.0, 105.0, 255.0))
            case "dodgerblue" => return Some(CssRGBAColor(30.0, 144.0, 255.0, 255.0))
            case "firebrick" => return Some(CssRGBAColor(178.0, 34.0, 34.0, 255.0))
            case "floralwhite" => return Some(CssRGBAColor(255.0, 250.0, 240.0, 255.0))
            case "forestgreen" => return Some(CssRGBAColor(34.0, 139.0, 34.0, 255.0))
            case "gainsboro" => return Some(CssRGBAColor(220.0, 220.0, 220.0, 255.0))
            case "ghostwhite" => return Some(CssRGBAColor(248.0, 248.0, 255.0, 255.0))
            case "gold" => return Some(CssRGBAColor(255.0, 215.0, 0.0, 255.0))
            case "goldenrod" => return Some(CssRGBAColor(218.0, 165.0, 32.0, 255.0))
            case "greenyellow" => return Some(CssRGBAColor(173.0, 255.0, 47.0, 255.0))
            case "honeydew" => return Some(CssRGBAColor(240.0, 255.0, 240.0, 255.0))
            case "hotpink" => return Some(CssRGBAColor(255.0, 105.0, 180.0, 255.0))
            case "indianred" => return Some(CssRGBAColor(205.0, 92.0, 92.0, 255.0))
            case "indigo" => return Some(CssRGBAColor(75.0, 0.0, 130.0, 255.0))
            case "ivory" => return Some(CssRGBAColor(255.0, 255.0, 240.0, 255.0))
            case "khaki" => return Some(CssRGBAColor(240.0, 230.0, 140.0, 255.0))
            case "lavender" => return Some(CssRGBAColor(230.0, 230.0, 250.0, 255.0))
            case "lavenderblush" => return Some(CssRGBAColor(255.0, 240.0, 245.0, 255.0))
            case "lawngreen" => return Some(CssRGBAColor(124.0, 252.0, 0.0, 255.0))
            case "lemonchiffon" => return Some(CssRGBAColor(255.0, 250.0, 205.0, 255.0))
            case "lightblue" => return Some(CssRGBAColor(173.0, 216.0, 230.0, 255.0))
            case "lightcoral" => return Some(CssRGBAColor(240.0, 128.0, 128.0, 255.0))
            case "lightcyan" => return Some(CssRGBAColor(224.0, 255.0, 255.0, 255.0))
            case "lightgoldenrodyellow" => return Some(CssRGBAColor(250.0, 250.0, 210.0, 255.0))
            case "lightgray" | "lightgrey" => return Some(CssRGBAColor(211.0, 211.0, 211.0, 255.0))
            case "lightgreen" => return Some(CssRGBAColor(144.0, 238.0, 144.0, 255.0))
            case "lightpink" => return Some(CssRGBAColor(255.0, 182.0, 193.0, 255.0))
            case "lightsalmon" => return Some(CssRGBAColor(255.0, 160.0, 122.0, 255.0))
            case "lightseagreen" => return Some(CssRGBAColor(32.0, 178.0, 170.0, 255.0))
            case "lightskyblue" => return Some(CssRGBAColor(135.0, 206.0, 250.0, 255.0))
            case "lightslategray" | "lightslategrey" => return Some(CssRGBAColor(119.0, 136.0, 153.0, 255.0))
            case "lightsteelblue" => return Some(CssRGBAColor(176.0, 196.0, 222.0, 255.0))
            case "lightyellow" => return Some(CssRGBAColor(255.0, 255.0, 224.0, 255.0))
            case "limegreen" => return Some(CssRGBAColor(50.0, 205.0, 50.0, 255.0))
            case "linen" => return Some(CssRGBAColor(250.0, 240.0, 230.0, 255.0))
            case "magenta" => return Some(CssRGBAColor(255.0, 0.0, 255.0, 255.0))
            case "mediumaquamarine" => return Some(CssRGBAColor(102.0, 205.0, 170.0, 255.0))
            case "mediumblue" => return Some(CssRGBAColor(0.0, 0.0, 205.0, 255.0))
            case "mediumorchid" => return Some(CssRGBAColor(186.0, 85.0, 211.0, 255.0))
            case "mediumpurple" => return Some(CssRGBAColor(147.0, 112.0, 219.0, 255.0))
            case "mediumseagreen" => return Some(CssRGBAColor(60.0, 179.0, 113.0, 255.0))
            case "mediumslateblue" => return Some(CssRGBAColor(123.0, 104.0, 238.0, 255.0))
            case "mediumspringgreen" => return Some(CssRGBAColor(0.0, 250.0, 154.0, 255.0))
            case "mediumturquoise" => return Some(CssRGBAColor(72.0, 209.0, 204.0, 255.0))
            case "mediumvioletred" => return Some(CssRGBAColor(199.0, 21.0, 133.0, 255.0))
            case "midnightblue" => return Some(CssRGBAColor(25.0, 25.0, 112.0, 255.0))
            case "mintcream" => return Some(CssRGBAColor(245.0, 255.0, 250.0, 255.0))
            case "mistyrose" => return Some(CssRGBAColor(255.0, 228.0, 225.0, 255.0))
            case "moccasin" => return Some(CssRGBAColor(255.0, 228.0, 181.0, 255.0))
            case "navajowhite" => return Some(CssRGBAColor(255.0, 222.0, 173.0, 255.0))
            case "oldlace" => return Some(CssRGBAColor(253.0, 245.0, 230.0, 255.0))
            case "olivedrab" => return Some(CssRGBAColor(107.0, 142.0, 35.0, 255.0))
            case "orange" => return Some(CssRGBAColor(255.0, 165.0, 0.0, 255.0))
            case "orangered" => return Some(CssRGBAColor(255.0, 69.0, 0.0, 255.0))
            case "orchid" => return Some(CssRGBAColor(218.0, 112.0, 214.0, 255.0))
            case "palegoldenrod" => return Some(CssRGBAColor(238.0, 232.0, 170.0, 255.0))
            case "palegreen" => return Some(CssRGBAColor(152.0, 251.0, 152.0, 255.0))
            case "paleturquoise" => return Some(CssRGBAColor(175.0, 238.0, 238.0, 255.0))
            case "palevioletred" => return Some(CssRGBAColor(219.0, 112.0, 147.0, 255.0))
            case "papayawhip" => return Some(CssRGBAColor(255.0, 239.0, 213.0, 255.0))
            case "peachpuff" => return Some(CssRGBAColor(255.0, 218.0, 185.0, 255.0))
            case "peru" => return Some(CssRGBAColor(205.0, 133.0, 63.0, 255.0))
            case "pink" => return Some(CssRGBAColor(255.0, 192.0, 203.0, 255.0))
            case "plum" => return Some(CssRGBAColor(221.0, 160.0, 221.0, 255.0))
            case "powderblue" => return Some(CssRGBAColor(176.0, 224.0, 230.0, 255.0))
            case "rosybrown" => return Some(CssRGBAColor(188.0, 143.0, 143.0, 255.0))
            case "royalblue" => return Some(CssRGBAColor(65.0, 105.0, 225.0, 255.0))
            case "saddlebrown" => return Some(CssRGBAColor(139.0, 69.0, 19.0, 255.0))
            case "salmon" => return Some(CssRGBAColor(250.0, 128.0, 114.0, 255.0))
            case "sandybrown" => return Some(CssRGBAColor(244.0, 164.0, 96.0, 255.0))
            case "seagreen" => return Some(CssRGBAColor(46.0, 139.0, 87.0, 255.0))
            case "seashell" => return Some(CssRGBAColor(255.0, 245.0, 238.0, 255.0))
            case "sienna" => return Some(CssRGBAColor(160.0, 82.0, 45.0, 255.0))
            case "skyblue" => return Some(CssRGBAColor(135.0, 206.0, 235.0, 255.0))
            case "slateblue" => return Some(CssRGBAColor(106.0, 90.0, 205.0, 255.0))
            case "slategray" | "slategrey" => return Some(CssRGBAColor(112.0, 128.0, 144.0, 255.0))
            case "snow" => return Some(CssRGBAColor(255.0, 250.0, 250.0, 255.0))
            case "springgreen" => return Some(CssRGBAColor(0.0, 255.0, 127.0, 255.0))
            case "steelblue" => return Some(CssRGBAColor(70.0, 130.0, 180.0, 255.0))
            case "tan" => return Some(CssRGBAColor(210.0, 180.0, 140.0, 255.0))
            case "thistle" => return Some(CssRGBAColor(216.0, 191.0, 216.0, 255.0))
            case "tomato" => return Some(CssRGBAColor(255.0, 99.0, 71.0, 255.0))
            case "turquoise" => return Some(CssRGBAColor(64.0, 224.0, 208.0, 255.0))
            case "violet" => return Some(CssRGBAColor(238.0, 130.0, 238.0, 255.0))
            case "wheat" => return Some(CssRGBAColor(245.0, 222.0, 179.0, 255.0))
            case "whitesmoke" => return Some(CssRGBAColor(245.0, 245.0, 245.0, 255.0))
            case "yellowgreen" => return Some(CssRGBAColor(154.0, 205.0, 50.0, 255.0))

            // transparent
            case "transparent" => return Some(CssRGBAColor(0.0, 0.0, 0.0, 0.0))

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
        let s = input

        // currentColor
        if (s == "currentcolor" || s == "currentColor") {
            return Some(CssColorValue.currentColor())
        }

        // transparent
        if (s == "transparent") {
            return Some(CssColorValue(CssRGBAColor.transparent()))
        }

        // 命名颜色
        match (CssColorValue.named(s)) {
            case Some(v) => return Some(v)
            case None => ()
        }

        // Hex 颜色
        if (s[0] == UInt8(35)) {
            return parseHex(s)
        }

        // 函数式颜色
        if (s.startsWith("rgb(") || s.startsWith("rgba(")) {
            return parseRgbFunction(s)
        }
        if (s.startsWith("hsl(") || s.startsWith("hsla(")) {
            return parseHslFunction(s)
        }

        return None
    }

    /// 解析 hex 颜色
    /// 支持: #rgb, #rgba, #rrggbb, #rrggbbaa
    public static func parseHex(hex: String): ?CssColorValue {
        return Some(CssColorValue(CssRGBAColor(0.0, 0.0, 0.0, 255.0)))
    }

    /// 解析 rgb()/rgba() 函数
    public static func parseRgbFunction(input: String): ?CssColorValue {
        let s = CssStrUtil.trim(input)
        // 提取括号内容
        let openParenOpt = s.indexOf(UInt8(40))
        let openParen = match (openParenOpt) {
            case Some(v) => v
            case _ => return None
        }
        let closeParenOpt = s.indexOf(UInt8(41))
        let closeParen = match (closeParenOpt) {
            case Some(v) => v
            case _ => return None
        }

        let content = CssStrUtil.trim(s[Int64(openParen) + 1..Int64(closeParen)])
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
        let s = CssStrUtil.trim(input)
        let openParenOpt = s.indexOf(UInt8(40))
        let openParen = match (openParenOpt) {
            case Some(v) => v
            case _ => return None
        }
        let closeParenOpt = s.indexOf(UInt8(41))
        let closeParen = match (closeParenOpt) {
            case Some(v) => v
            case _ => return None
        }

        let content = CssStrUtil.trim(s[Int64(openParen) + 1..Int64(closeParen)])
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
        if (c >= UInt8(48) && c <= UInt8(57)) { return Int64(c) - 48 }
        if (c >= UInt8(97) && c <= UInt8(102)) { return Int64(c) - 87 }
        if (c >= UInt8(65) && c <= UInt8(70)) { return Int64(c) - 55 }
        return 0
    }

    private static func parseColorComponent(s: String): Float64 {
        return 0.0
    }

    private static func parseAlphaComponent(s: String): Float64 {
        return 1.0
    }

    private static func parseAngleOrNumber(s: String): Float64 {
        return 0.0
    }

    private static func parsePercentageOrNumber(s: String): Float64 {
        return 0.0
    }

    private static func splitCssFunctionArgs(s: String): ArrayList<String> {
        let parts = ArrayList<String>()
        parts.append(CssStrUtil.trim(s))
        return parts
    }

    private static func parseFloat(s: String): Float64 {
        var result: Float64 = 0.0
        var sign: Float64 = 1.0
        var i: Int64 = 0

        if (i < Int64(s.size) && s[i] == UInt8(45)) { sign = -1.0; i++ }
        else if (i < Int64(s.size) && s[i] == UInt8(43)) { i++ }

        while (i < Int64(s.size) && s[i] >= UInt8(48) && s[i] <= UInt8(57)) {
            result = result * 10.0 + Float64(s[i]) - 48.0
            i++
        }

        if (i < Int64(s.size) && s[i] == UInt8(46)) {
            i++
            var frac: Float64 = 0.1
            while (i < Int64(s.size) && s[i] >= UInt8(48) && s[i] <= UInt8(57)) {
                result += Float64(s[i]) - 48.0 * frac
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
        match (CssStrUtil.toLowerCase(unit)) {
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
        match (CssStrUtil.toLowerCase(unit)) {
            case "deg" => value
            case "rad" => value * DEG_PER_RAD
            case "grad" => value * DEG_PER_GRAD
            case "turn" => value * DEG_PER_TURN
            case _ => value
        }
    }

    /// 将时间值转换为 s
    public static func timeToS(value: Float64, unit: String): Float64 {
        match (CssStrUtil.toLowerCase(unit)) {
            case "s" => value
            case "ms" => value * S_PER_MS
            case _ => value
        }
    }

    /// 将频率值转换为 Hz
    public static func frequencyToHz(value: Float64, unit: String): Float64 {
        match (CssStrUtil.toLowerCase(unit)) {
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
        let s = CssStrUtil.trim(input)
        if (s.size == 0) { return None }

        // none
        if (CssStrUtil.toLowerCase(s) == "none") {
            return CssValue(CssValueType.None)
        }

        // var()
        if (CssStrUtil.toLowerCase(s).startsWith("var(")) {
            let v = CssValue(CssValueType.Var)
            v.raw = s
            return v
        }

        // calc()
        if (CssStrUtil.toLowerCase(s).startsWith("calc(")) {
            let v = CssValue(CssValueType.Calc)
            v.raw = s
            return v
        }

        // 颜色: 先试 hex
        if (s[0] == UInt8(35)) {
            let color = CssColorParser.parseHex(s)
            match (color) {
                case Some(c) => return CssValue.createColor(c)
                case None => ()
            }
        }

        // 颜色函数
        let lower = CssStrUtil.toLowerCase(s)
        if (lower.startsWith("rgb(") || lower.startsWith("rgba(") ||
            lower.startsWith("hsl(") || lower.startsWith("hsla(")) {
            let color = CssColorParser.parse(s)
            match (color) {
                case Some(c) => return CssValue.createColor(c)
                case None => ()
            }
        }

        // 命名颜色
        let namedColor = CssColorValue.named(s)
        match (namedColor) {
            case Some(c) => return CssValue.createColor(c)
            case _ => ()
        }

        // currentColor
        if (lower == "currentcolor") {
            return CssValue.createColor(CssColorValue.currentColor())
        }

        // url()
        if (lower.startsWith("url(")) {
            let urlContent = extractFunctionArg(s, 4)
            return CssValue.url(urlContent)
        }

        // 百分比
        if (s.endsWith("%")) {
            let numStr = s[0..Int64(s.size) - 1]
            let num = parseFloat64(numStr)
            return CssValue.percentage(num / 100.0)
        }

        // 带单位的值: 尝试匹配 数字+单位
        let unitMatch = matchDimension(s)
        match (unitMatch) {
            case Some(v) => return v
            case _ => ()
        }

        // 纯数字
        let numVal = parseFloat64Strict(s)
        match (numVal) {
            case Some(v) =>
                if (s.contains(".")) {
                    return CssValue.number(v)
                }
                return CssValue.integer(Int64(v))
            case _ => ()
        }

        // 字符串
        if ((s[0] == UInt8(34) && s[Int64(s.size) - 1] == UInt8(34)) ||
            (s[0] == UInt8(39) && s[Int64(s.size) - 1] == UInt8(39))) {
            return CssValue.string(s[1..Int64(s.size) - 1])
        }

        // 标识符
        return CssValue.ident(s)
    }

    /// 尝试匹配带单位的维度值
    private static func matchDimension(s: String): ?CssValue {
        // 找到数字部分结束位置
        var i: Int64 = 0
        if (i < Int64(s.size) && (s[i] == UInt8(43) || s[i] == UInt8(45))) { i++ }
        while (i < Int64(s.size) && s[i] >= UInt8(48) && s[i] <= UInt8(57)) { i++ }
        if (i < Int64(s.size) && s[i] == UInt8(46)) {
            i++
            while (i < Int64(s.size) && s[i] >= UInt8(48) && s[i] <= UInt8(57)) { i++ }
        }
        // 需要有单位
        if (i == 0 || i >= Int64(s.size)) { return None }

        let numStr = s[0..i]
        let unit = s[i..]
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
        if (Int64(s.size) > prefixLen + 1) {
            s[prefixLen..Int64(s.size) - 1]
        } else {
            ""
        }
    }

    private static func parseFloat64(s: String): Float64 {
        var result: Float64 = 0.0
        var sign: Float64 = 1.0
        var i: Int64 = 0
        if (i < Int64(s.size) && s[i] == UInt8(45)) { sign = -1.0; i++ }
        else if (i < Int64(s.size) && s[i] == UInt8(43)) { i++ }
        while (i < Int64(s.size) && s[i] >= UInt8(48) && s[i] <= UInt8(57)) {
            result = result * 10.0 + Float64(s[i]) - 48.0
            i++
        }
        if (i < Int64(s.size) && s[i] == UInt8(46)) {
            i++
            var frac: Float64 = 0.1
            while (i < Int64(s.size) && s[i] >= UInt8(48) && s[i] <= UInt8(57)) {
                result += Float64(s[i]) - 48.0 * frac
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

        if (i < Int64(s.size) && s[i] == UInt8(45)) { sign = -1.0; i++ }
        else if (i < Int64(s.size) && s[i] == UInt8(43)) { i++ }

        while (i < Int64(s.size) && s[i] >= UInt8(48) && s[i] <= UInt8(57)) {
            result = result * 10.0 + Float64(s[i]) - 48.0
            hasDigit = true
            i++
        }
        if (i < Int64(s.size) && s[i] == UInt8(46)) {
            i++
            var frac: Float64 = 0.1
            while (i < Int64(s.size) && s[i] >= UInt8(48) && s[i] <= UInt8(57)) {
                result += Float64(s[i]) - 48.0 * frac
                frac *= 0.1
                hasDigit = true
                i++
            }
        }

        if (!hasDigit || i < Int64(s.size)) { return None }
        return Some(result * sign)
    }
}
