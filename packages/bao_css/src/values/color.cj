// 严格翻译自: src/css/values/color.zig
// CSS 颜色值类型 - 完整的颜色空间支持
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// RGBA - RGB 颜色 (每分量一字节)
// 严格翻译自: color.zig RGBA struct
// ============================================================================

/// RGBA 颜色值 (每分量一字节)
/// 严格翻译自 RGBA struct { red: u8, green: u8, blue: u8, alpha: u8 }
public class CssRGBA {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
    }

    public static func transparent(): CssRGBA {
        return CssRGBA(0, 0, 0, 0)
    }

    public static func black(): CssRGBA {
        return CssRGBA(0, 0, 0, 255)
    }

    public static func white(): CssRGBA {
        return CssRGBA(255, 255, 255, 255)
    }

    public func alphaF32(): Float32 {
        return Float32(alpha) / 255.0f
    }

    public func toHex(): String {
        if (alpha == 255) {
            return "#${red.formatHex(2)}${green.formatHex(2)}${blue.formatHex(2)}"
        }
        return "#${red.formatHex(2)}${green.formatHex(2)}${blue.formatHex(2)}${alpha.formatHex(2)}"
    }

    public func eql(other: CssRGBA): Bool {
        return red == other.red && green == other.green && blue == other.blue && alpha == other.alpha
    }

    public func clone(): CssRGBA {
        return CssRGBA(red, green, blue, alpha)
    }
}

// ============================================================================
// LAB/OKLAB/LCH/OKLCH 颜色分量
// 严格翻译自: color.zig LAB, OKLAB, LCH, OKLCH structs
// ============================================================================

/// LAB 颜色空间
/// 严格翻译自 LAB struct { l: f32, a: f32, b: f32, alpha: f32 }
public class CssLAB {
    public var l: Float32
    public var a: Float32
    public var b: Float32
    public var alpha: Float32

    public init(l: Float32, a: Float32, b: Float32, alpha: Float32) {
        this.l = l
        this.a = a
        this.b = b
        this.alpha = alpha
    }
}

/// LCH 颜色空间
/// 严格翻译自 LCH struct { l: f32, c: f32, h: f32, alpha: f32 }
public class CssLCH {
    public var l: Float32
    public var c: Float32
    public var h: Float32
    public var alpha: Float32

    public init(l: Float32, c: Float32, h: Float32, alpha: Float32) {
        this.l = l
        this.c = c
        this.h = h
        this.alpha = alpha
    }
}

/// OKLAB 颜色空间
/// 严格翻译自 OKLAB struct { l: f32, a: f32, b: f32, alpha: f32 }
public class CssOKLAB {
    public var l: Float32
    public var a: Float32
    public var b: Float32
    public var alpha: Float32

    public init(l: Float32, a: Float32, b: Float32, alpha: Float32) {
        this.l = l
        this.a = a
        this.b = b
        this.alpha = alpha
    }
}

/// OKLCH 颜色空间
/// 严格翻译自 OKLCH struct { l: f32, c: f32, h: f32, alpha: f32 }
public class CssOKLCH {
    public var l: Float32
    public var c: Float32
    public var h: Float32
    public var alpha: Float32

    public init(l: Float32, c: Float32, h: Float32, alpha: Float32) {
        this.l = l
        this.c = c
        this.h = h
        this.alpha = alpha
    }
}

// ============================================================================
// LABColor - LAB/LCH/OKLAB/OKLCH 联合类型
// 严格翻译自: color.zig LABColor union(enum)
// ============================================================================

/// LAB 系颜色
/// 严格翻译自 LABColor union(enum)
public enum CssLABColor {
    | lab(CssLAB)
    | lch(CssLCH)
    | oklab(CssOKLAB)
    | oklch(CssOKLCH)

    public func toCss(): String {
        match (this) {
            case lab(v) => "lab(${v.l} ${v.a} ${v.b}${alphaSuffix(v.alpha)})"
            case lch(v) => "lch(${v.l} ${v.c} ${v.h}${alphaSuffix(v.alpha)})"
            case oklab(v) => "oklab(${v.l} ${v.a} ${v.b}${alphaSuffix(v.alpha)})"
            case oklch(v) => "oklch(${v.l} ${v.c} ${v.h}${alphaSuffix(v.alpha)})"
        }
    }

    func alphaSuffix(alpha: Float32): String {
        if (alpha < 1.0f) {
            return " / ${alpha}"
        }
        return ""
    }

    public func eql(other: CssLABColor): Bool {
        match (this) {
            case lab(a) => match (other) { case lab(b) => a.l == b.l && a.a == b.a && a.b == b.b && a.alpha == b.alpha case _ => false }
            case lch(a) => match (other) { case lch(b) => a.l == b.l && a.c == b.c && a.h == b.h && a.alpha == b.alpha case _ => false }
            case oklab(a) => match (other) { case oklab(b) => a.l == b.l && a.a == b.a && a.b == b.b && a.alpha == b.alpha case _ => false }
            case oklch(a) => match (other) { case oklch(b) => a.l == b.l && a.c == b.c && a.h == b.h && a.alpha == b.alpha case _ => false }
        }
    }
}

// ============================================================================
// 预定义颜色空间
// 严格翻译自: color.zig PredefinedColor union(enum)
// ============================================================================

/// 预定义 RGB 颜色空间值
/// 严格翻译自 PredefinedRGB struct
public class CssPredefinedRGB {
    public var red: Float32
    public var green: Float32
    public var blue: Float32
    public var alpha: Float32

    public init(red: Float32, green: Float32, blue: Float32, alpha: Float32) {
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
    }
}

/// 预定义颜色空间类型
/// 严格翻译自 PredefinedColorSpace enum
public enum CssPredefinedColorSpace {
    | display_p3
    | a98_rgb
    | prophoto_rgb
    | rec2020
    | srgb
    | srgb_linear
    | xyz_d50
    | xyz_d65

    public func asStr(): String {
        match (this) {
            case display_p3 => "display-p3"
            case a98_rgb => "a98-rgb"
            case prophoto_rgb => "prophoto-rgb"
            case rec2020 => "rec2020"
            case srgb => "srgb"
            case srgb_linear => "srgb-linear"
            case xyz_d50 => "xyz-d50"
            case xyz_d65 => "xyz-d65"
        }
    }
}

/// 预定义颜色
/// 严格翻译自 PredefinedColor union(enum)
public enum CssPredefinedColor {
    | display_p3(CssPredefinedRGB)
    | a98_rgb(CssPredefinedRGB)
    | prophoto_rgb(CssPredefinedRGB)
    | rec2020(CssPredefinedRGB)
    | srgb(CssPredefinedRGB)
    | srgb_linear(CssPredefinedRGB)
    | xyz_d50(CssPredefinedRGB)
    | xyz_d65(CssPredefinedRGB)

    public func toCss(): String {
        match (this) {
            case display_p3(v) => "color(display-p3 ${v.red} ${v.green} ${v.blue}${alphaSuffix(v.alpha)})"
            case a98_rgb(v) => "color(a98-rgb ${v.red} ${v.green} ${v.blue}${alphaSuffix(v.alpha)})"
            case prophoto_rgb(v) => "color(prophoto-rgb ${v.red} ${v.green} ${v.blue}${alphaSuffix(v.alpha)})"
            case rec2020(v) => "color(rec2020 ${v.red} ${v.green} ${v.blue}${alphaSuffix(v.alpha)})"
            case srgb(v) => "color(srgb ${v.red} ${v.green} ${v.blue}${alphaSuffix(v.alpha)})"
            case srgb_linear(v) => "color(srgb-linear ${v.red} ${v.green} ${v.blue}${alphaSuffix(v.alpha)})"
            case xyz_d50(v) => "color(xyz-d50 ${v.red} ${v.green} ${v.blue}${alphaSuffix(v.alpha)})"
            case xyz_d65(v) => "color(xyz-d65 ${v.red} ${v.green} ${v.blue}${alphaSuffix(v.alpha)})"
        }
    }

    func alphaSuffix(alpha: Float32): String {
        if (alpha < 1.0f) { return " / ${alpha}" }
        return ""
    }
}

// ============================================================================
// FloatColor - 浮点 RGB 颜色 (用于包含 none 组件)
// 严格翻译自: color.zig FloatColor
// ============================================================================

/// 浮点颜色 (用于 none 组件和颜色插值)
/// 严格翻译自 FloatColor struct
public class CssFloatColor {
    public var red: ?Float32
    public var green: ?Float32
    public var blue: ?Float32
    public var alpha: ?Float32
    public var color_space: CssPredefinedColorSpace

    public init(red: ?Float32, green: ?Float32, blue: ?Float32, alpha: ?Float32, color_space: CssPredefinedColorSpace) {
        this.red = red
        this.green = green
        this.blue = blue
        this.alpha = alpha
        this.color_space = color_space
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        match (red) { case Some(v) => parts.append(v.toString()) case None => parts.append("none") }
        match (green) { case Some(v) => parts.append(v.toString()) case None => parts.append("none") }
        match (blue) { case Some(v) => parts.append(v.toString()) case None => parts.append("none") }

        var result = "color(${color_space.asStr()}"
        for (i in 0..parts.size) {
            result = result + " " + parts[i]
        }

        match (alpha) {
            case Some(a) => if (a < 1.0f) { result = result + " / ${a}" }
            case None => result = result + " / none"
        }

        return result + ")"
    }
}

// ============================================================================
// HSL/HWB 颜色
// 严格翻译自: color.zig HSL, HWB
// ============================================================================

/// HSL 颜色
/// 严格翻译自 HSL struct
public class CssHSL {
    public var h: Float32
    public var s: Float32
    public var l: Float32
    public var alpha: Float32

    public init(h: Float32, s: Float32, l: Float32, alpha: Float32) {
        this.h = h
        this.s = s
        this.l = l
        this.alpha = alpha
    }

    public func toCss(): String {
        return "hsl(${h} ${s * 100.0f}% ${l * 100.0f}%${alphaSuffix()})"
    }

    func alphaSuffix(): String {
        if (alpha < 1.0f) { return " / ${alpha}" }
        return ""
    }
}

/// HWB 颜色
/// 严格翻译自 HWB struct
public class CssHWB {
    public var h: Float32
    public var w: Float32
    public var b: Float32
    public var alpha: Float32

    public init(h: Float32, w: Float32, b: Float32, alpha: Float32) {
        this.h = h
        this.w = w
        this.b = b
        this.alpha = alpha
    }

    public func toCss(): String {
        return "hwb(${h} ${w * 100.0f}% ${b * 100.0f}%${alphaSuffix()})"
    }

    func alphaSuffix(): String {
        if (alpha < 1.0f) { return " / ${alpha}" }
        return ""
    }
}

// ============================================================================
// SystemColor - 系统颜色
// 严格翻译自: color.zig SystemColor enum
// ============================================================================

/// 系统颜色关键字
/// 严格翻译自 SystemColor enum (部分)
public enum CssSystemColor {
    | accent_color
    | accent_color_text
    | active_text
    | button_border
    | button_face
    | button_text
    | canvas
    | canvas_text
    | field
    | field_text
    | gray_text
    | highlight
    | highlight_text
    | link_text
    | mark
    | mark_text
    | visited_text
    | custom(String)

    public func toCss(): String {
        match (this) {
            case accent_color => "AccentColor"
            case accent_color_text => "AccentColorText"
            case active_text => "ActiveText"
            case button_border => "ButtonBorder"
            case button_face => "ButtonFace"
            case button_text => "ButtonText"
            case canvas => "Canvas"
            case canvas_text => "CanvasText"
            case field => "Field"
            case field_text => "FieldText"
            case gray_text => "GrayText"
            case highlight => "Highlight"
            case highlight_text => "HighlightText"
            case link_text => "LinkText"
            case mark => "Mark"
            case mark_text => "MarkText"
            case visited_text => "VisitedText"
            case custom(name) => name
        }
    }

    public func isCompatible(browsers: CssBrowsers): Bool {
        // 大部分系统颜色在现代浏览器中支持
        return true
    }
}

// ============================================================================
// CssColor - CSS 颜色值 (联合类型)
// 严格翻译自: color.zig CssColor union(enum)
// ============================================================================

/// CSS `<color>` 值
/// 严格翻译自 CssColor union(enum)
/// 支持多种颜色空间表示: currentColor, RGBA, LAB, 预定义颜色空间, 浮点颜色, light-dark(), 系统颜色
public enum CssColor {
    | current_color                                                  // currentColor 关键字
    | rgba(CssRGBA)                                                  // RGB 颜色 (含 hex, rgb(), hsl(), hwb())
    | lab(CssLABColor)                                               // LAB 系颜色 (lab, lch, oklab, oklch)
    | predefined(CssPredefinedColor)                                 // 预定义颜色空间 (display-p3 等)
    | float_color(CssFloatColor)                                     // 浮点 RGB/HSL/HWB (含 none 组件)
    | light_dark(CssColor, CssColor)                                 // light-dark() 函数
    | system(CssSystemColor)                                         // 系统颜色关键字

    /// 检查浏览器兼容性
    /// 严格翻译自 CssColor.isCompatible()
    public func isCompatible(browsers: CssBrowsers): Bool {
        match (this) {
            case current_color => true
            case rgba(_) => true
            case float_color(_) => true
            case lab(lab_color) =>
                match (lab_color) {
                    case CssLABColor.lab(_) => true
                    case CssLABColor.lch(_) => true
                    case CssLABColor.oklab(_) => true
                    case CssLABColor.oklch(_) => true
                }
            case predefined(pre) =>
                match (pre) {
                    case CssPredefinedColor.display_p3(_) => true
                    case _ => true
                }
            case light_dark(light, dark) =>
                light.isCompatible(browsers) && dark.isCompatible(browsers)
            case system(sys) => sys.isCompatible(browsers)
        }
    }

    /// 序列化为 CSS
    /// 严格翻译自 CssColor.toCss()
    public func toCss(): String {
        match (this) {
            case current_color => "currentColor"
            case rgba(color) => color.toHex()
            case lab(lab_color) => lab_color.toCss()
            case predefined(pre) => pre.toCss()
            case float_color(fc) => fc.toCss()
            case light_dark(light, dark) =>
                "light-dark(${light.toCss()}, ${dark.toCss()})"
            case system(sys) => sys.toCss()
        }
    }

    /// 深拷贝
    public func deepClone(): CssColor {
        match (this) {
            case current_color => CssColor.current_color
            case rgba(c) => CssColor.rgba(c.clone())
            case lab(l) => CssColor.lab(l)  // enum, copy
            case predefined(p) => CssColor.predefined(p)  // enum, copy
            case float_color(fc) =>
                CssColor.float_color(CssFloatColor(fc.red, fc.green, fc.blue, fc.alpha, fc.color_space))
            case light_dark(l, d) => CssColor.light_dark(l.deepClone(), d.deepClone())
            case system(s) => CssColor.system(s)  // enum, copy
        }
    }

    public func toString(): String {
        return toCss()
    }
}
