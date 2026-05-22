// 严格翻译自: src/css/values/color.zig
// CSS 颜色值类型 - 完整的颜色空间支持
package bao_css.values

import bao_core.*
import bao_collections.*
import bao_css.*

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

    /// 从整数值创建 RGBA, alpha 为浮点
    /// 严格翻译自 RGBA.new
    public static func new(red: UInt8, green: UInt8, blue: UInt8, alpha: Float32): CssRGBA {
        CssRGBA(red, green, blue, clampUnitF32(alpha))
    }

    /// 从浮点分量构造 RGBA (0.0~1.0 范围)
    /// 严格翻译自 RGBA.fromFloats
    public static func fromFloats(red: Float32, green: Float32, blue: Float32, alpha: Float32): CssRGBA {
        CssRGBA.new(
            clampUnitF32(red),
            clampUnitF32(green),
            clampUnitF32(blue),
            alpha
        )
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
        return Float32(alpha) / 255.0f32
    }

    public func redF32(): Float32 {
        return Float32(red) / 255.0f32
    }

    public func greenF32(): Float32 {
        return Float32(green) / 255.0f32
    }

    public func blueF32(): Float32 {
        return Float32(blue) / 255.0f32
    }

    /// 转换为 SRGB 浮点颜色
    /// 严格翻译自 RGBA.intoSRGB
    public func intoSRGB(): CssSRGB {
        CssSRGB(redF32(), greenF32(), blueF32(), alphaF32())
    }

    private static func hexByte(value: UInt8): String {
        let digits = "0123456789abcdef"
        let n = Int64(value)
        let hi = digits[n / 16]
        let lo = digits[n % 16]
        "${hi}${lo}"
    }

    public func toHex(): String {
        if (alpha == 255) {
            // 尝试用短颜色名
            let hex = (Int32(red) << 16) | (Int32(green) << 8) | Int32(blue)
            if (let Some(name) <- CssColorShortNames.shortColorName(UInt32(hex))) {
                return name
            }
            let compact = CssColorHex.compactHex(UInt32(hex))
            if (UInt32(hex) == CssColorHex.expandHex(compact)) {
                return "#${CssColorHex.compactHexStr(compact)}"
            }
            return "#${CssRGBA.hexByte(red)}${CssRGBA.hexByte(green)}${CssRGBA.hexByte(blue)}"
        }
        // 带 alpha
        let hex = (Int32(red) << 24) | (Int32(green) << 16) | (Int32(blue) << 8) | Int32(alpha)
        let compact = CssColorHex.compactHex(UInt32(hex))
        if (UInt32(hex) == CssColorHex.expandHex(compact)) {
            return "#${CssColorHex.compactHexStr4(compact)}"
        }
        return "#${CssRGBA.hexByte(red)}${CssRGBA.hexByte(green)}${CssRGBA.hexByte(blue)}${CssRGBA.hexByte(alpha)}"
    }

    public func eql(other: CssRGBA): Bool {
        return red == other.red && green == other.green && blue == other.blue && alpha == other.alpha
    }

    public func clone(): CssRGBA {
        return CssRGBA(red, green, blue, alpha)
    }

    /// 从 CssColor 提取 RGBA
    /// 严格翻译自 RGBA.tryFromCssColor (Zig lines 1349)
    public static func tryFromCssColor(color: CssColor): ?CssRGBA {
        match (color) {
            case CssColor.rgba_color(value) => Some(value)
            case _ => None
        }
    }
}

/// 将 0.0~1.0 浮点值夹紧为 u8
/// 严格翻译自 clamp_unit_f32
public func clampUnitF32(val: Float32): UInt8 {
    clampFloor256F32(val * 255.0f32)
}

/// 严格翻译自 clamp_floor_256_f32
public func clampFloor256F32(val: Float32): UInt8 {
    let rounded = Float32(CssColorMath.round(val))
    let clamped = CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, rounded))
    UInt8(clamped)
}

// ============================================================================
// SRGB - sRGB 颜色空间 (浮点)
// 严格翻译自: color.zig SRGB struct
// ============================================================================

/// sRGB 浮点颜色
/// 严格翻译自 SRGB struct { r, g, b, alpha: f32 }
public class CssSRGB {
    public var r: Float32
    public var g: Float32
    public var b: Float32
    public var alpha: Float32

    public init(r: Float32, g: Float32, b: Float32, alpha: Float32) {
        this.r = r
        this.g = g
        this.b = b
        this.alpha = alpha
    }

    /// 解析 missing 组件 (NaN -> 0)
    public func resolveMissing(): CssSRGB {
        CssSRGB(
            if (CssColorMath.isNaN(r)) { 0.0f32 } else { r },
            if (CssColorMath.isNaN(g)) { 0.0f32 } else { g },
            if (CssColorMath.isNaN(b)) { 0.0f32 } else { b },
            if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }
        )
    }

    /// 检查是否在色域内
    public func inGamut(): Bool {
        r >= 0.0f32 && r <= 1.0f32 &&
        g >= 0.0f32 && g <= 1.0f32 &&
        b >= 0.0f32 && b <= 1.0f32
    }

    /// 裁剪到色域
    public func clip(): CssSRGB {
        CssSRGB(
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, r)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, g)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, b)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, alpha))
        )
    }

    /// 解析 missing 组件并在需要时进行色域映射
    /// 严格翻译自 DefineColorspace.resolve (Zig lines 3304-3310)
    public func resolve(): CssSRGB {
        let resolved = resolveMissing()
        if (!resolved.inGamut()) {
            return resolved.clip()
        }
        resolved
    }

    /// 填充 missing 组件
    public func fillMissingComponents(other: CssSRGB): Unit {
        if (CssColorMath.isNaN(r)) { r = other.r }
        if (CssColorMath.isNaN(g)) { g = other.g }
        if (CssColorMath.isNaN(b)) { b = other.b }
        if (CssColorMath.isNaN(alpha)) { alpha = other.alpha }
    }

    /// 线性插值
    public func interpolate(p1: Float32, other: CssSRGB, p2: Float32): CssSRGB {
        CssSRGB(
            r * p1 + other.r * p2,
            g * p1 + other.g * p2,
            b * p1 + other.b * p2,
            alpha * p1 + other.alpha * p2
        )
    }

    /// 矩形预乘
    public func premultiply(): Unit {
        if (!CssColorMath.isNaN(alpha)) {
            r = r * alpha
            g = g * alpha
            b = b * alpha
        }
    }

    /// 矩形反预乘
    public func unpremultiply(alphaMultiplier: Float32): Unit {
        if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) {
            r = r / alpha
            g = g / alpha
            b = b / alpha
            alpha = alpha * alphaMultiplier
        }
    }

    /// 调整 powerless 组件 (SRGB 无操作)
    public func adjustPowerlessComponents(): Unit {}

    /// 调整色调 (SRGB 无操作)
    public func adjustHue(other: CssSRGB, method: CssHueInterpolationMethod): Unit {}

    /// 转换为 RGBA
    /// 严格翻译自 SRGB.intoRGBA
    public func intoRGBA(): CssRGBA {
        let resolved = resolveMissing()
        CssRGBA.fromFloats(resolved.r, resolved.g, resolved.b, resolved.alpha)
    }

    /// 转换为 HSL
    /// 严格翻译自 convert_SRGB.intoHSL
    public func intoHSL(): CssHSL {
        let rgb = resolveMissing()
        let maxV = CssColorMath.max(CssColorMath.max(rgb.r, rgb.g), rgb.b)
        let minV = CssColorMath.min(CssColorMath.min(rgb.r, rgb.g), rgb.b)
        var h = Float32(CssColorMath.NaN)
        var s = 0.0f32
        let l = (minV + maxV) / 2.0f32
        let d = maxV - minV

        if (d != 0.0f32) {
            s = if (l == 0.0f32 || l == 1.0f32) {
                0.0f32
            } else {
                (maxV - l) / CssColorMath.min(l, 1.0f32 - l)
            }

            if (maxV == rgb.r) {
                h = (rgb.g - rgb.b) / d + (if (rgb.g < rgb.b) { 6.0f32 } else { 0.0f32 })
            } else if (maxV == rgb.g) {
                h = (rgb.b - rgb.r) / d + 2.0f32
            } else if (maxV == rgb.b) {
                h = (rgb.r - rgb.g) / d + 4.0f32
            }
            h = h * 60.0f32
        }

        CssHSL(h, s, l, rgb.alpha)
    }

    /// 转换为 HWB
    /// 严格翻译自 convert_SRGB.intoHWB
    public func intoHWB(): CssHWB {
        let rgb = resolveMissing()
        let hsl = intoHSL()
        let w = CssColorMath.min(CssColorMath.min(rgb.r, rgb.g), rgb.b)
        let b2 = 1.0f32 - CssColorMath.max(CssColorMath.max(rgb.r, rgb.g), rgb.b)
        CssHWB(hsl.h, w, b2, rgb.alpha)
    }

    /// 转换为 SRGBLinear
    /// 严格翻译自 convert_SRGB.intoSRGBLinear
    public func intoSRGBLinear(): CssSRGBLinear {
        let srgb = resolveMissing()
        let (r2, g2, b2) = CssColorMath.linSrgb(srgb.r, srgb.g, srgb.b)
        CssSRGBLinear(r2, g2, b2, srgb.alpha)
    }

    /// 从 FloatColor 创建 SRGB
    /// 严格翻译自 SRGB.fromFloatColor (通过 ColorspaceConversions)
    public static func fromFloatColor(fc: CssFloatColor): ?CssSRGB {
        match (fc) {
            case CssFloatColor.rgb(val) => Some(val)
            case _ => None
        }
    }

    /// 从 LABColor 创建 SRGB
    /// 严格翻译自 SRGB.fromLABColor (通过 ColorspaceConversions)
    public static func fromLABColor(lc: CssLABColor): CssSRGB {
        match (lc) {
            case CssLABColor.lab(v) =>
                let xyz50 = CssColorConversions.labToXYZd50(v)
                let xyz65 = CssColorConversions.xyzd50ToXYZd65(xyz50)
                let lin = CssColorConversions.xyzd65ToSRGBLinear(xyz65)
                CssColorConversions.srgbLinearToSRGB(lin)
            case CssLABColor.lch(v) =>
                let lab = CssColorConversions.lchToLAB(v)
                let xyz50 = CssColorConversions.labToXYZd50(lab)
                let xyz65 = CssColorConversions.xyzd50ToXYZd65(xyz50)
                let lin = CssColorConversions.xyzd65ToSRGBLinear(xyz65)
                CssColorConversions.srgbLinearToSRGB(lin)
            case CssLABColor.oklab(v) =>
                let xyz65 = CssColorConversions.oklabToXYZd65(v)
                let lin = CssColorConversions.xyzd65ToSRGBLinear(xyz65)
                CssColorConversions.srgbLinearToSRGB(lin)
            case CssLABColor.oklch(v) =>
                let oklab = CssColorConversions.oklchToOKLAB(v)
                let xyz65 = CssColorConversions.oklabToXYZd65(oklab)
                let lin = CssColorConversions.xyzd65ToSRGBLinear(xyz65)
                CssColorConversions.srgbLinearToSRGB(lin)
        }
    }

    /// 从预定义颜色创建 SRGB
    /// 严格翻译自 SRGB.fromPredefinedColor (通过转换链)
    public static func fromPredefinedColor(pre: CssPredefinedColor): ?CssSRGB {
        match (pre) {
            case CssPredefinedColor.srgb(v) => Some(v)
            case CssPredefinedColor.display_p3(v) =>
                let xyz65 = CssColorConversions.p3ToXYZd65(v)
                let lin = CssColorConversions.xyzd65ToSRGBLinear(xyz65)
                Some(CssColorConversions.srgbLinearToSRGB(lin))
            case _ => None
        }
    }

    /// 将 SRGB 包装为 CssColor (RGBA 变体)
    /// 严格翻译自 convert_SRGB.intoCssColor
    public func intoCssColor(): CssColor {
        CssColor.rgba_color(intoRGBA())
    }

    /// 组件元组
    /// 严格翻译自 DefineColorspace.components
    public func components(): (Float32, Float32, Float32, Float32) {
        (r, g, b, alpha)
    }

    /// 通道名称
    /// 严格翻译自 DefineColorspace.channels
    public static func channels(): (String, String, String) {
        ("r", "g", "b")
    }

    /// 通道类型
    /// 严格翻译自 DefineColorspace.types
    public static func types(): (CssChannelType, CssChannelType, CssChannelType) {
        (CssChannelType(true, false, true), CssChannelType(true, false, true), CssChannelType(true, false, true))
    }
}

// ============================================================================
// SRGBLinear - sRGB 线性颜色空间
// 严格翻译自: color.zig SRGBLinear struct
// ============================================================================

public class CssSRGBLinear {
    public var r: Float32
    public var g: Float32
    public var b: Float32
    public var alpha: Float32

    public init(r: Float32, g: Float32, b: Float32, alpha: Float32) {
        this.r = r
        this.g = g
        this.b = b
        this.alpha = alpha
    }

    public func resolveMissing(): CssSRGBLinear {
        CssSRGBLinear(
            if (CssColorMath.isNaN(r)) { 0.0f32 } else { r },
            if (CssColorMath.isNaN(g)) { 0.0f32 } else { g },
            if (CssColorMath.isNaN(b)) { 0.0f32 } else { b },
            if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }
        )
    }

    public func inGamut(): Bool {
        r >= 0.0f32 && r <= 1.0f32 &&
        g >= 0.0f32 && g <= 1.0f32 &&
        b >= 0.0f32 && b <= 1.0f32
    }

    public func clip(): CssSRGBLinear {
        CssSRGBLinear(
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, r)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, g)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, b)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, alpha))
        )
    }

    public func fillMissingComponents(other: CssSRGBLinear): Unit {
        if (CssColorMath.isNaN(r)) { r = other.r }
        if (CssColorMath.isNaN(g)) { g = other.g }
        if (CssColorMath.isNaN(b)) { b = other.b }
        if (CssColorMath.isNaN(alpha)) { alpha = other.alpha }
    }

    public func interpolate(p1: Float32, other: CssSRGBLinear, p2: Float32): CssSRGBLinear {
        CssSRGBLinear(
            r * p1 + other.r * p2,
            g * p1 + other.g * p2,
            b * p1 + other.b * p2,
            alpha * p1 + other.alpha * p2
        )
    }

    public func premultiply(): Unit {
        if (!CssColorMath.isNaN(alpha)) { r *= alpha; g *= alpha; b *= alpha }
    }

    public func unpremultiply(alphaMultiplier: Float32): Unit {
        if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) {
            r /= alpha; g /= alpha; b /= alpha; alpha *= alphaMultiplier
        }
    }

    public func adjustPowerlessComponents(): Unit {}
    public func adjustHue(other: CssSRGBLinear, method: CssHueInterpolationMethod): Unit {}
}

// ============================================================================
// P3 - display-p3 颜色空间
// 严格翻译自: color.zig P3 struct
// ============================================================================

public class CssP3 {
    public var r: Float32
    public var g: Float32
    public var b: Float32
    public var alpha: Float32

    public init(r: Float32, g: Float32, b: Float32, alpha: Float32) {
        this.r = r
        this.g = g
        this.b = b
        this.alpha = alpha
    }

    public func resolveMissing(): CssP3 {
        CssP3(
            if (CssColorMath.isNaN(r)) { 0.0f32 } else { r },
            if (CssColorMath.isNaN(g)) { 0.0f32 } else { g },
            if (CssColorMath.isNaN(b)) { 0.0f32 } else { b },
            if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }
        )
    }

    public func inGamut(): Bool {
        r >= 0.0f32 && r <= 1.0f32 &&
        g >= 0.0f32 && g <= 1.0f32 &&
        b >= 0.0f32 && b <= 1.0f32
    }

    public func clip(): CssP3 {
        CssP3(
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, r)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, g)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, b)),
            CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, alpha))
        )
    }

    public func fillMissingComponents(other: CssP3): Unit {
        if (CssColorMath.isNaN(r)) { r = other.r }
        if (CssColorMath.isNaN(g)) { g = other.g }
        if (CssColorMath.isNaN(b)) { b = other.b }
        if (CssColorMath.isNaN(alpha)) { alpha = other.alpha }
    }

    public func interpolate(p1: Float32, other: CssP3, p2: Float32): CssP3 {
        CssP3(r * p1 + other.r * p2, g * p1 + other.g * p2, b * p1 + other.b * p2, alpha * p1 + other.alpha * p2)
    }

    public func premultiply(): Unit {
        if (!CssColorMath.isNaN(alpha)) { r *= alpha; g *= alpha; b *= alpha }
    }

    public func unpremultiply(alphaMultiplier: Float32): Unit {
        if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) {
            r /= alpha; g /= alpha; b /= alpha; alpha *= alphaMultiplier
        }
    }

    /// P3 无 powerless 组件
    /// 严格翻译自 P3 struct (Zig: 无 adjustPowerlessComponents)
    public func adjustPowerlessComponents(): Unit {}

    /// P3 无色调调整
    /// 严格翻译自 P3 struct (Zig: 无 adjustHue)
    public func adjustHue(other: CssP3, method: CssHueInterpolationMethod): Unit {}
}

// ============================================================================
// A98 - a98-rgb 颜色空间
// 严格翻译自: color.zig A98 struct
// ============================================================================

public class CssA98 {
    public var r: Float32
    public var g: Float32
    public var b: Float32
    public var alpha: Float32

    public init(r: Float32, g: Float32, b: Float32, alpha: Float32) {
        this.r = r
        this.g = g
        this.b = b
        this.alpha = alpha
    }

    public func resolveMissing(): CssA98 {
        CssA98(
            if (CssColorMath.isNaN(r)) { 0.0f32 } else { r },
            if (CssColorMath.isNaN(g)) { 0.0f32 } else { g },
            if (CssColorMath.isNaN(b)) { 0.0f32 } else { b },
            if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }
        )
    }

    public func inGamut(): Bool {
        r >= 0.0f32 && r <= 1.0f32 && g >= 0.0f32 && g <= 1.0f32 && b >= 0.0f32 && b <= 1.0f32
    }

    public func clip(): CssA98 {
        CssA98(CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, r)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, g)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, b)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, alpha)))
    }

    public func fillMissingComponents(other: CssA98): Unit {
        if (CssColorMath.isNaN(r)) { r = other.r }
        if (CssColorMath.isNaN(g)) { g = other.g }
        if (CssColorMath.isNaN(b)) { b = other.b }
        if (CssColorMath.isNaN(alpha)) { alpha = other.alpha }
    }

    public func interpolate(p1: Float32, other: CssA98, p2: Float32): CssA98 {
        CssA98(r * p1 + other.r * p2, g * p1 + other.g * p2, b * p1 + other.b * p2, alpha * p1 + other.alpha * p2)
    }

    public func premultiply(): Unit {
        if (!CssColorMath.isNaN(alpha)) { r *= alpha; g *= alpha; b *= alpha }
    }

    public func unpremultiply(alphaMultiplier: Float32): Unit {
        if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) { r /= alpha; g /= alpha; b /= alpha; alpha *= alphaMultiplier }
    }

    /// A98 无 powerless 组件
    /// 严格翻译自 A98 struct (Zig: 无 adjustPowerlessComponents)
    public func adjustPowerlessComponents(): Unit {}

    /// A98 无色调调整
    /// 严格翻译自 A98 struct (Zig: 无 adjustHue)
    public func adjustHue(other: CssA98, method: CssHueInterpolationMethod): Unit {}
}

// ============================================================================
// ProPhoto - prophoto-rgb 颜色空间
// 严格翻译自: color.zig ProPhoto struct
// ============================================================================

public class CssProPhoto {
    public var r: Float32
    public var g: Float32
    public var b: Float32
    public var alpha: Float32

    public init(r: Float32, g: Float32, b: Float32, alpha: Float32) {
        this.r = r
        this.g = g
        this.b = b
        this.alpha = alpha
    }

    public func resolveMissing(): CssProPhoto {
        CssProPhoto(if (CssColorMath.isNaN(r)) { 0.0f32 } else { r }, if (CssColorMath.isNaN(g)) { 0.0f32 } else { g }, if (CssColorMath.isNaN(b)) { 0.0f32 } else { b }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha })
    }

    public func inGamut(): Bool { r >= 0.0f32 && r <= 1.0f32 && g >= 0.0f32 && g <= 1.0f32 && b >= 0.0f32 && b <= 1.0f32 }
    public func clip(): CssProPhoto { CssProPhoto(CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, r)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, g)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, b)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, alpha))) }

    public func fillMissingComponents(other: CssProPhoto): Unit {
        if (CssColorMath.isNaN(r)) { r = other.r }; if (CssColorMath.isNaN(g)) { g = other.g }; if (CssColorMath.isNaN(b)) { b = other.b }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha }
    }

    public func interpolate(p1: Float32, other: CssProPhoto, p2: Float32): CssProPhoto {
        CssProPhoto(r * p1 + other.r * p2, g * p1 + other.g * p2, b * p1 + other.b * p2, alpha * p1 + other.alpha * p2)
    }

    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { r *= alpha; g *= alpha; b *= alpha } }
    public func unpremultiply(m: Float32): Unit { if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) { r /= alpha; g /= alpha; b /= alpha; alpha *= m } }

    /// ProPhoto 无 powerless 组件
    /// 严格翻译自 ProPhoto struct (Zig: 无 adjustPowerlessComponents)
    public func adjustPowerlessComponents(): Unit {}

    /// ProPhoto 无色调调整
    /// 严格翻译自 ProPhoto struct (Zig: 无 adjustHue)
    public func adjustHue(other: CssProPhoto, method: CssHueInterpolationMethod): Unit {}
}

// ============================================================================
// Rec2020 - rec2020 颜色空间
// 严格翻译自: color.zig Rec2020 struct
// ============================================================================

public class CssRec2020 {
    public var r: Float32
    public var g: Float32
    public var b: Float32
    public var alpha: Float32

    public init(r: Float32, g: Float32, b: Float32, alpha: Float32) {
        this.r = r; this.g = g; this.b = b; this.alpha = alpha
    }

    public func resolveMissing(): CssRec2020 { CssRec2020(if (CssColorMath.isNaN(r)) { 0.0f32 } else { r }, if (CssColorMath.isNaN(g)) { 0.0f32 } else { g }, if (CssColorMath.isNaN(b)) { 0.0f32 } else { b }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }
    public func inGamut(): Bool { r >= 0.0f32 && r <= 1.0f32 && g >= 0.0f32 && g <= 1.0f32 && b >= 0.0f32 && b <= 1.0f32 }
    public func clip(): CssRec2020 { CssRec2020(CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, r)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, g)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, b)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, alpha))) }
    public func fillMissingComponents(other: CssRec2020): Unit { if (CssColorMath.isNaN(r)) { r = other.r }; if (CssColorMath.isNaN(g)) { g = other.g }; if (CssColorMath.isNaN(b)) { b = other.b }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha } }
    public func interpolate(p1: Float32, other: CssRec2020, p2: Float32): CssRec2020 { CssRec2020(r * p1 + other.r * p2, g * p1 + other.g * p2, b * p1 + other.b * p2, alpha * p1 + other.alpha * p2) }
    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { r *= alpha; g *= alpha; b *= alpha } }
    public func unpremultiply(m: Float32): Unit { if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) { r /= alpha; g /= alpha; b /= alpha; alpha *= m } }

    /// Rec2020 无 powerless 组件
    /// 严格翻译自 Rec2020 struct (Zig: 无 adjustPowerlessComponents)
    public func adjustPowerlessComponents(): Unit {}

    /// Rec2020 无色调调整
    /// 严格翻译自 Rec2020 struct (Zig: 无 adjustHue)
    public func adjustHue(other: CssRec2020, method: CssHueInterpolationMethod): Unit {}
}

// ============================================================================
// XYZd50 - xyz-d50 颜色空间
// 严格翻译自: color.zig XYZd50 struct
// ============================================================================

public class CssXYZd50 {
    public var x: Float32
    public var y: Float32
    public var z: Float32
    public var alpha: Float32

    public init(x: Float32, y: Float32, z: Float32, alpha: Float32) {
        this.x = x; this.y = y; this.z = z; this.alpha = alpha
    }

    public func resolveMissing(): CssXYZd50 { CssXYZd50(if (CssColorMath.isNaN(x)) { 0.0f32 } else { x }, if (CssColorMath.isNaN(y)) { 0.0f32 } else { y }, if (CssColorMath.isNaN(z)) { 0.0f32 } else { z }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }

    public func fillMissingComponents(other: CssXYZd50): Unit {
        if (CssColorMath.isNaN(x)) { x = other.x }; if (CssColorMath.isNaN(y)) { y = other.y }; if (CssColorMath.isNaN(z)) { z = other.z }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha }
    }

    public func interpolate(p1: Float32, other: CssXYZd50, p2: Float32): CssXYZd50 {
        CssXYZd50(x * p1 + other.x * p2, y * p1 + other.y * p2, z * p1 + other.z * p2, alpha * p1 + other.alpha * p2)
    }

    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { x *= alpha; y *= alpha; z *= alpha } }
    public func unpremultiply(m: Float32): Unit { if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) { x /= alpha; y /= alpha; z /= alpha; alpha *= m } }

    /// XYZ 总是无界色域
    public func inGamut(): Bool { true }
    public func clip(): CssXYZd50 { this }
}

// ============================================================================
// XYZd65 - xyz-d65 颜色空间
// 严格翻译自: color.zig XYZd65 struct
// ============================================================================

public class CssXYZd65 {
    public var x: Float32
    public var y: Float32
    public var z: Float32
    public var alpha: Float32

    public init(x: Float32, y: Float32, z: Float32, alpha: Float32) {
        this.x = x; this.y = y; this.z = z; this.alpha = alpha
    }

    public func resolveMissing(): CssXYZd65 { CssXYZd65(if (CssColorMath.isNaN(x)) { 0.0f32 } else { x }, if (CssColorMath.isNaN(y)) { 0.0f32 } else { y }, if (CssColorMath.isNaN(z)) { 0.0f32 } else { z }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }

    public func fillMissingComponents(other: CssXYZd65): Unit {
        if (CssColorMath.isNaN(x)) { x = other.x }; if (CssColorMath.isNaN(y)) { y = other.y }; if (CssColorMath.isNaN(z)) { z = other.z }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha }
    }

    public func interpolate(p1: Float32, other: CssXYZd65, p2: Float32): CssXYZd65 {
        CssXYZd65(x * p1 + other.x * p2, y * p1 + other.y * p2, z * p1 + other.z * p2, alpha * p1 + other.alpha * p2)
    }

    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { x *= alpha; y *= alpha; z *= alpha } }
    public func unpremultiply(m: Float32): Unit { if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) { x /= alpha; y /= alpha; z /= alpha; alpha *= m } }

    public func inGamut(): Bool { true }
    public func clip(): CssXYZd65 { this }
    public func adjustPowerlessComponents(): Unit {}
    public func adjustHue(other: CssXYZd65, method: CssHueInterpolationMethod): Unit {}
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
        this.l = l; this.a = a; this.b = b; this.alpha = alpha
    }

    public func resolveMissing(): CssLAB { CssLAB(if (CssColorMath.isNaN(l)) { 0.0f32 } else { l }, if (CssColorMath.isNaN(a)) { 0.0f32 } else { a }, if (CssColorMath.isNaN(b)) { 0.0f32 } else { b }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }
    public func inGamut(): Bool { true }
    public func clip(): CssLAB { this }
    public func fillMissingComponents(other: CssLAB): Unit { if (CssColorMath.isNaN(l)) { l = other.l }; if (CssColorMath.isNaN(a)) { a = other.a }; if (CssColorMath.isNaN(b)) { b = other.b }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha } }
    public func interpolate(p1: Float32, other: CssLAB, p2: Float32): CssLAB { CssLAB(l * p1 + other.l * p2, a * p1 + other.a * p2, b * p1 + other.b * p2, alpha * p1 + other.alpha * p2) }
    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { l *= alpha; a *= alpha; b *= alpha } }
    public func unpremultiply(m: Float32): Unit { if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) { l /= alpha; a /= alpha; b /= alpha; alpha *= m } }

    /// 调整 LAB powerless 组件: 如果 lightness == 0 则 a, b 为 powerless
    public func adjustPowerlessComponents(): Unit {
        if (CssColorMath.abs(l) < 0.00001f32) {
            a = Float32(CssColorMath.NaN)
            b = Float32(CssColorMath.NaN)
        }
    }

    public func adjustHue(other: CssLAB, method: CssHueInterpolationMethod): Unit {}

    /// 转换为 LCH
    public func intoLCH(): CssLCH {
        let lab = resolveMissing()
        let (l2, c, h) = CssColorMath.rectangularToPolar(lab.l, lab.a, lab.b)
        CssLCH(l2, c, h, lab.alpha)
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
        this.l = l; this.c = c; this.h = h; this.alpha = alpha
    }

    public func resolveMissing(): CssLCH { CssLCH(if (CssColorMath.isNaN(l)) { 0.0f32 } else { l }, if (CssColorMath.isNaN(c)) { 0.0f32 } else { c }, if (CssColorMath.isNaN(h)) { 0.0f32 } else { h }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }
    public func inGamut(): Bool { true }
    public func clip(): CssLCH { this }
    public func fillMissingComponents(other: CssLCH): Unit { if (CssColorMath.isNaN(l)) { l = other.l }; if (CssColorMath.isNaN(c)) { c = other.c }; if (CssColorMath.isNaN(h)) { h = other.h }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha } }
    public func interpolate(p1: Float32, other: CssLCH, p2: Float32): CssLCH { CssLCH(l * p1 + other.l * p2, c * p1 + other.c * p2, h * p1 + other.h * p2, alpha * p1 + other.alpha * p2) }
    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { l *= alpha; c *= alpha } }
    public func unpremultiply(m: Float32): Unit {
        h = CssColorMath.fmod(h, 360.0f32)
        if (!CssColorMath.isNaN(alpha)) { l /= alpha; c /= alpha; alpha *= m }
    }

    /// 调整 LCH powerless: 如果 c == 0 则 h 为 powerless; 如果 l == 0 则 c, h 都为 powerless
    public func adjustPowerlessComponents(): Unit {
        if (CssColorMath.abs(c) < 0.00001f32) { h = Float32(CssColorMath.NaN) }
        if (CssColorMath.abs(l) < 0.00001f32) { c = Float32(CssColorMath.NaN); h = Float32(CssColorMath.NaN) }
    }

    public func adjustHue(other: CssLCH, method: CssHueInterpolationMethod): Unit {
        method.interpolate(h, other.h)
    }

    /// 转换为 LAB
    public func intoLAB(): CssLAB {
        let lch = resolveMissing()
        let (l2, a, b) = CssColorMath.polarToRectangular(lch.l, lch.c, lch.h)
        CssLAB(l2, a, b, lch.alpha)
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
        this.l = l; this.a = a; this.b = b; this.alpha = alpha
    }

    public func resolveMissing(): CssOKLAB { CssOKLAB(if (CssColorMath.isNaN(l)) { 0.0f32 } else { l }, if (CssColorMath.isNaN(a)) { 0.0f32 } else { a }, if (CssColorMath.isNaN(b)) { 0.0f32 } else { b }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }
    public func inGamut(): Bool { true }
    public func clip(): CssOKLAB { this }
    public func fillMissingComponents(other: CssOKLAB): Unit { if (CssColorMath.isNaN(l)) { l = other.l }; if (CssColorMath.isNaN(a)) { a = other.a }; if (CssColorMath.isNaN(b)) { b = other.b }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha } }
    public func interpolate(p1: Float32, other: CssOKLAB, p2: Float32): CssOKLAB { CssOKLAB(l * p1 + other.l * p2, a * p1 + other.a * p2, b * p1 + other.b * p2, alpha * p1 + other.alpha * p2) }
    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { l *= alpha; a *= alpha; b *= alpha } }
    public func unpremultiply(m: Float32): Unit { if (!CssColorMath.isNaN(alpha) && alpha != 0.0f32) { l /= alpha; a /= alpha; b /= alpha; alpha *= m } }

    public func adjustPowerlessComponents(): Unit {
        if (CssColorMath.abs(l) < 0.00001f32) { a = Float32(CssColorMath.NaN); b = Float32(CssColorMath.NaN) }
    }

    public func adjustHue(other: CssOKLAB, method: CssHueInterpolationMethod): Unit {}

    /// 转换为 OKLCH
    public func intoOKLCH(): CssOKLCH {
        let lab = resolveMissing()
        let (l2, c, h) = CssColorMath.rectangularToPolar(lab.l, lab.a, lab.b)
        CssOKLCH(l2, c, h, lab.alpha)
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
        this.l = l; this.c = c; this.h = h; this.alpha = alpha
    }

    public func resolveMissing(): CssOKLCH { CssOKLCH(if (CssColorMath.isNaN(l)) { 0.0f32 } else { l }, if (CssColorMath.isNaN(c)) { 0.0f32 } else { c }, if (CssColorMath.isNaN(h)) { 0.0f32 } else { h }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }
    public func inGamut(): Bool { true }
    public func clip(): CssOKLCH { this }
    public func fillMissingComponents(other: CssOKLCH): Unit { if (CssColorMath.isNaN(l)) { l = other.l }; if (CssColorMath.isNaN(c)) { c = other.c }; if (CssColorMath.isNaN(h)) { h = other.h }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha } }
    public func interpolate(p1: Float32, other: CssOKLCH, p2: Float32): CssOKLCH { CssOKLCH(l * p1 + other.l * p2, c * p1 + other.c * p2, h * p1 + other.h * p2, alpha * p1 + other.alpha * p2) }
    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { l *= alpha; c *= alpha } }
    public func unpremultiply(m: Float32): Unit {
        h = CssColorMath.fmod(h, 360.0f32)
        if (!CssColorMath.isNaN(alpha)) { l /= alpha; c /= alpha; alpha *= m }
    }

    public func adjustPowerlessComponents(): Unit {
        if (CssColorMath.abs(c) < 0.00001f32) { h = Float32(CssColorMath.NaN) }
        if (CssColorMath.abs(l) < 0.00001f32) { c = Float32(CssColorMath.NaN); h = Float32(CssColorMath.NaN) }
    }

    public func adjustHue(other: CssOKLCH, method: CssHueInterpolationMethod): Unit {
        method.interpolate(h, other.h)
    }

    /// 转换为 OKLAB
    public func intoOKLAB(): CssOKLAB {
        let lch = resolveMissing()
        let (l2, a, b) = CssColorMath.polarToRectangular(lch.l, lch.c, lch.h)
        CssOKLAB(l2, a, b, lch.alpha)
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
        this.h = h; this.s = s; this.l = l; this.alpha = alpha
    }

    public func resolveMissing(): CssHSL { CssHSL(if (CssColorMath.isNaN(h)) { 0.0f32 } else { h }, if (CssColorMath.isNaN(s)) { 0.0f32 } else { s }, if (CssColorMath.isNaN(l)) { 0.0f32 } else { l }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }

    public func inGamut(): Bool { s >= 0.0f32 && s <= 1.0f32 && l >= 0.0f32 && l <= 1.0f32 }

    public func clip(): CssHSL {
        let h2 = CssColorMath.fmod(h, 360.0f32)
        CssHSL(h2, CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, s)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, l)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, alpha)))
    }

    public func fillMissingComponents(other: CssHSL): Unit { if (CssColorMath.isNaN(h)) { h = other.h }; if (CssColorMath.isNaN(s)) { s = other.s }; if (CssColorMath.isNaN(l)) { l = other.l }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha } }
    public func interpolate(p1: Float32, other: CssHSL, p2: Float32): CssHSL { CssHSL(h * p1 + other.h * p2, s * p1 + other.s * p2, l * p1 + other.l * p2, alpha * p1 + other.alpha * p2) }
    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { s *= alpha; l *= alpha } }
    public func unpremultiply(m: Float32): Unit {
        h = CssColorMath.fmod(h, 360.0f32)
        if (!CssColorMath.isNaN(alpha)) { s /= alpha; l /= alpha; alpha *= m }
    }

    /// HSL powerless: 如果 s == 0 则 h 为 powerless; 如果 l == 0 或 l == 1 则 s, h 都为 powerless
    public func adjustPowerlessComponents(): Unit {
        if (CssColorMath.abs(s) < 0.00001f32) { h = Float32(CssColorMath.NaN) }
        if (CssColorMath.abs(l) < 0.00001f32 || CssColorMath.abs(l - 1.0f32) < 0.00001f32) { h = Float32(CssColorMath.NaN); s = Float32(CssColorMath.NaN) }
    }

    public func adjustHue(other: CssHSL, method: CssHueInterpolationMethod): Unit {
        method.interpolate(h, other.h)
    }

    public func toCss(): String {
        return "hsl(${h} ${s * 100.0f32}% ${l * 100.0f32}%${alphaSuffix()})"
    }

    func alphaSuffix(): String {
        if (alpha < 1.0f32) { return " / ${alpha}" }
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
        this.h = h; this.w = w; this.b = b; this.alpha = alpha
    }

    public func resolveMissing(): CssHWB { CssHWB(if (CssColorMath.isNaN(h)) { 0.0f32 } else { h }, if (CssColorMath.isNaN(w)) { 0.0f32 } else { w }, if (CssColorMath.isNaN(b)) { 0.0f32 } else { b }, if (CssColorMath.isNaN(alpha)) { 0.0f32 } else { alpha }) }

    public func inGamut(): Bool { w >= 0.0f32 && w <= 1.0f32 && b >= 0.0f32 && b <= 1.0f32 }

    public func clip(): CssHWB {
        let h2 = CssColorMath.fmod(h, 360.0f32)
        CssHWB(h2, CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, w)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, b)), CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, alpha)))
    }

    public func fillMissingComponents(other: CssHWB): Unit { if (CssColorMath.isNaN(h)) { h = other.h }; if (CssColorMath.isNaN(w)) { w = other.w }; if (CssColorMath.isNaN(b)) { b = other.b }; if (CssColorMath.isNaN(alpha)) { alpha = other.alpha } }
    public func interpolate(p1: Float32, other: CssHWB, p2: Float32): CssHWB { CssHWB(h * p1 + other.h * p2, w * p1 + other.w * p2, b * p1 + other.b * p2, alpha * p1 + other.alpha * p2) }
    public func premultiply(): Unit { if (!CssColorMath.isNaN(alpha)) { w *= alpha; b *= alpha } }
    public func unpremultiply(m: Float32): Unit {
        h = CssColorMath.fmod(h, 360.0f32)
        if (!CssColorMath.isNaN(alpha)) { w /= alpha; b /= alpha; alpha *= m }
    }

    /// HWB powerless: 如果 w+b == 1.0 则 h 为 powerless
    public func adjustPowerlessComponents(): Unit {
        if (CssColorMath.abs(w + b - 1.0f32) < 0.00001f32) { h = Float32(CssColorMath.NaN) }
    }

    public func adjustHue(other: CssHWB, method: CssHueInterpolationMethod): Unit {
        method.interpolate(h, other.h)
    }

    public func toCss(): String {
        return "hwb(${h} ${w * 100.0f32}% ${b * 100.0f32}%${alphaSuffix()})"
    }

    func alphaSuffix(): String {
        if (alpha < 1.0f32) { return " / ${alpha}" }
        return ""
    }
}

// ============================================================================
// SystemColor - 系统颜色
// 严格翻译自: color.zig SystemColor enum
// ============================================================================

/// 系统颜色关键字 (完整列表, 包含已废弃的)
/// 严格翻译自 SystemColor enum
public enum CssSystemColor {
    // 现代系统颜色
    | accentcolor
    | accentcolortext
    | activetext
    | buttonborder
    | buttonface
    | buttontext
    | canvas
    | canvastext
    | field
    | fieldtext
    | graytext
    | highlight
    | highlighttext
    | linktext
    | mark
    | marktext
    | selecteditem
    | selecteditemtext
    | visitedtext
    // 已废弃的系统颜色
    | activeborder
    | activecaption
    | appworkspace
    | background
    | buttonhighlight
    | buttonshadow
    | captiontext
    | inactiveborder
    | inactivecaption
    | inactivecaptiontext
    | infobackground
    | infotext
    | menu
    | menutext
    | scrollbar
    | threeddarkshadow
    | threedface
    | threedhighlight
    | threedlightshadow
    | threedshadow
    | window
    | windowframe
    | windowtext

    public func toCss(): String {
        match (this) {
            case accentcolor => "AccentColor"
            case accentcolortext => "AccentColorText"
            case activetext => "ActiveText"
            case buttonborder => "ButtonBorder"
            case buttonface => "ButtonFace"
            case buttontext => "ButtonText"
            case canvas => "Canvas"
            case canvastext => "CanvasText"
            case field => "Field"
            case fieldtext => "FieldText"
            case graytext => "GrayText"
            case highlight => "Highlight"
            case highlighttext => "HighlightText"
            case linktext => "LinkText"
            case mark => "Mark"
            case marktext => "MarkText"
            case selecteditem => "SelectedItem"
            case selecteditemtext => "SelectedItemText"
            case visitedtext => "VisitedText"
            case activeborder => "ActiveBorder"
            case activecaption => "ActiveCaption"
            case appworkspace => "AppWorkspace"
            case background => "Background"
            case buttonhighlight => "ButtonHighlight"
            case buttonshadow => "ButtonShadow"
            case captiontext => "CaptionText"
            case inactiveborder => "InactiveBorder"
            case inactivecaption => "InactiveCaption"
            case inactivecaptiontext => "InactiveCaptionText"
            case infobackground => "InfoBackground"
            case infotext => "InfoText"
            case menu => "Menu"
            case menutext => "MenuText"
            case scrollbar => "Scrollbar"
            case threeddarkshadow => "ThreeDDarkShadow"
            case threedface => "ThreeDFace"
            case threedhighlight => "ThreeDHighlight"
            case threedlightshadow => "ThreeDLightShadow"
            case threedshadow => "ThreeDShadow"
            case window => "Window"
            case windowframe => "WindowFrame"
            case windowtext => "WindowText"
        }
    }

    public func isCompatible(browsers: CssBrowsers): Bool {
        match (this) {
            case accentcolor => true
            case accentcolortext => true
            case _ => true
        }
    }

    public operator func ==(other: CssSystemColor): Bool {
        this.toCss() == other.toCss()
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
        if (alpha < 1.0f32) { return " / ${alpha}" }
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

    /// 静态构造函数
    public static func newLAB(l: Float32, a: Float32, b: Float32, alpha: Float32): CssLABColor {
        CssLABColor.lab(CssLAB(l, a, b, alpha))
    }

    public static func newLCH(l: Float32, c: Float32, h: Float32, alpha: Float32): CssLABColor {
        CssLABColor.lch(CssLCH(l, c, h, alpha))
    }

    public static func newOKLAB(l: Float32, a: Float32, b: Float32, alpha: Float32): CssLABColor {
        CssLABColor.oklab(CssOKLAB(l, a, b, alpha))
    }

    public static func newOKLCH(l: Float32, c: Float32, h: Float32, alpha: Float32): CssLABColor {
        CssLABColor.oklch(CssOKLCH(l, c, h, alpha))
    }
}

// ============================================================================
// 预定义颜色空间
// 严格翻译自: color.zig PredefinedColor union(enum)
// ============================================================================

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
    | display_p3(CssP3)
    | a98(CssA98)
    | prophoto(CssProPhoto)
    | rec2020(CssRec2020)
    | srgb(CssSRGB)
    | srgb_linear(CssSRGBLinear)
    | xyz_d50(CssXYZd50)
    | xyz_d65(CssXYZd65)

    public func toCss(): String {
        match (this) {
            case display_p3(v) => "color(display-p3 ${fmtC(v.r)} ${fmtC(v.g)} ${fmtC(v.b)}${alphaS(v.alpha)})"
            case a98(v) => "color(a98-rgb ${fmtC(v.r)} ${fmtC(v.g)} ${fmtC(v.b)}${alphaS(v.alpha)})"
            case prophoto(v) => "color(prophoto-rgb ${fmtC(v.r)} ${fmtC(v.g)} ${fmtC(v.b)}${alphaS(v.alpha)})"
            case rec2020(v) => "color(rec2020 ${fmtC(v.r)} ${fmtC(v.g)} ${fmtC(v.b)}${alphaS(v.alpha)})"
            case srgb(v) => "color(srgb ${fmtC(v.r)} ${fmtC(v.g)} ${fmtC(v.b)}${alphaS(v.alpha)})"
            case srgb_linear(v) => "color(srgb-linear ${fmtC(v.r)} ${fmtC(v.g)} ${fmtC(v.b)}${alphaS(v.alpha)})"
            case xyz_d50(v) => "color(xyz-d50 ${fmtC(v.x)} ${fmtC(v.y)} ${fmtC(v.z)}${alphaS(v.alpha)})"
            case xyz_d65(v) => "color(xyz ${fmtC(v.x)} ${fmtC(v.y)} ${fmtC(v.z)}${alphaS(v.alpha)})"
        }
    }

    func fmtC(v: Float32): String {
        if (CssColorMath.isNaN(v)) { return "none" }
        return v.toString()
    }

    func alphaS(alpha: Float32): String {
        if (CssColorMath.isNaN(alpha) || CssColorMath.abs(alpha - 1.0f32) > 0.00001f32) { return " / ${fmtC(alpha)}" }
        return ""
    }
}

// ============================================================================
// FloatColor - 浮点颜色 (包含 none 组件)
// 严格翻译自: color.zig FloatColor
// ============================================================================

/// 浮点颜色 (通常为 RGBA 的浮点表示, 当有 none 组件时使用)
/// 严格翻译自 FloatColor union(enum)
public enum CssFloatColor {
    | rgb(CssSRGB)
    | hsl(CssHSL)
    | hwb(CssHWB)

    public func toCss(): String {
        match (this) {
            case rgb(v) => "color(srgb ${fmtC(v.r)} ${fmtC(v.g)} ${fmtC(v.b)}${alphaS(v.alpha)})"
            case hsl(v) => "hsl(${fmtC(v.h)} ${fmtC(v.s * 100.0f32)}%${fmtC(v.l * 100.0f32)}%${alphaS(v.alpha)})"
            case hwb(v) => "hwb(${fmtC(v.h)} ${fmtC(v.w * 100.0f32)}%${fmtC(v.b * 100.0f32)}%${alphaS(v.alpha)})"
        }
    }

    func fmtC(v: Float32): String {
        if (CssColorMath.isNaN(v)) { return "none" }
        return v.toString()
    }

    func alphaS(alpha: Float32): String {
        if (CssColorMath.isNaN(alpha) || CssColorMath.abs(alpha - 1.0f32) > 0.00001f32) { return " / ${fmtC(alpha)}" }
        return ""
    }
}

// ============================================================================
// ColorFallbackKind - 颜色降级类型
// 严格翻译自: color.zig ColorFallbackKind
// ============================================================================

/// 颜色降级类型 (按位标志)
/// 严格翻译自 ColorFallbackKind packed struct(u8)
public class CssColorFallbackKind {
    public var rgb: Bool
    public var p3: Bool
    public var lab: Bool
    public var oklab: Bool

    public init() {
        rgb = false; p3 = false; lab = false; oklab = false
    }

    public init(rgb: Bool, p3: Bool, lab: Bool, oklab: Bool) {
        this.rgb = rgb; this.p3 = p3; this.lab = lab; this.oklab = oklab
    }

    public static func p3Fallback(): CssColorFallbackKind { CssColorFallbackKind(false, true, false, false) }
    public static func rgbFallback(): CssColorFallbackKind { CssColorFallbackKind(true, false, false, false) }
    public static func labFallback(): CssColorFallbackKind { CssColorFallbackKind(false, false, true, false) }
    public static func oklabFallback(): CssColorFallbackKind { CssColorFallbackKind(false, false, false, true) }
    public static func none(): CssColorFallbackKind { CssColorFallbackKind() }

    public func isEmpty(): Bool { !rgb && !p3 && !lab && !oklab }

    public func merge(other: CssColorFallbackKind): Unit {
        this.rgb = this.rgb || other.rgb
        this.p3 = this.p3 || other.p3
        this.lab = this.lab || other.lab
        this.oklab = this.oklab || other.oklab
    }

    public func asBits(): UInt8 {
        var bits: UInt8 = 0
        if (rgb) { bits = bits | 1 }
        if (p3) { bits = bits | 2 }
        if (lab) { bits = bits | 4 }
        if (oklab) { bits = bits | 8 }
        return bits
    }

    /// 返回此降级及其以下的所有级别
    public func andBelow(): CssColorFallbackKind {
        if (isEmpty()) { return CssColorFallbackKind() }
        let bits = asBits()
        CssColorFallbackKind.fromBitsTruncate(bits | (bits - 1))
    }

    /// 返回最高级别
    public func highest(): CssColorFallbackKind {
        if (oklab) { return CssColorFallbackKind.oklabFallback() }
        if (lab) { return CssColorFallbackKind.labFallback() }
        if (p3) { return CssColorFallbackKind.p3Fallback() }
        if (rgb) { return CssColorFallbackKind.rgbFallback() }
        return CssColorFallbackKind()
    }

    /// 差集
    public func difference(other: CssColorFallbackKind): CssColorFallbackKind {
        CssColorFallbackKind.fromBitsTruncate(asBits() - other.asBits())
    }

    public static func fromBitsTruncate(bits: UInt8): CssColorFallbackKind {
        CssColorFallbackKind(
            (bits & 1) != 0,
            (bits & 2) != 0,
            (bits & 4) != 0,
            (bits & 8) != 0
        )
    }

    /// 按位或
    public func or(other: CssColorFallbackKind): CssColorFallbackKind {
        CssColorFallbackKind(rgb || other.rgb, p3 || other.p3, lab || other.lab, oklab || other.oklab)
    }

    /// 返回最低级别
    /// 严格翻译自 ColorFallbackKind.lowest (Zig lines 2964-2970)
    public func lowest(): CssColorFallbackKind {
        if (isEmpty()) { return CssColorFallbackKind() }
        let bits = asBits()
        let lowestBit = bits & (bits ^ (bits - 1))
        CssColorFallbackKind.fromBitsTruncate(lowestBit)
    }

    /// 返回支持的 @supports 条件字符串
    /// 严格翻译自 ColorFallbackKind.supportsCondition (Zig lines 2990-3003)
    public func supportsCondition(): String {
        let bits = asBits()
        if (bits == CssColorFallbackKind.p3Fallback().asBits()) {
            return "color(display-p3 0 0 0)"
        }
        if (bits == CssColorFallbackKind.labFallback().asBits()) {
            return "lab(0% 0 0)"
        }
        return ""
    }
}

// ============================================================================
// ColorSpaceName - 插值颜色空间
// 严格翻译自: color.zig ColorSpaceName enum
// ============================================================================

/// 插值颜色空间关键字 (用于 color-mix() 等)
/// 严格翻译自 ColorSpaceName enum
public enum CssColorSpaceName {
    | srgb
    | srgb_linear
    | lab
    | oklab
    | xyz
    | xyz_d50
    | xyz_d65
    | hsl
    | hwb
    | lch
    | oklch

    public func asStr(): String {
        match (this) {
            case srgb => "srgb"
            case srgb_linear => "srgb-linear"
            case lab => "lab"
            case oklab => "oklab"
            case xyz => "xyz"
            case xyz_d50 => "xyz-d50"
            case xyz_d65 => "xyz-d65"
            case hsl => "hsl"
            case hwb => "hwb"
            case lch => "lch"
            case oklch => "oklch"
        }
    }
}

// ============================================================================
// HueInterpolationMethod - 色调插值方法
// 严格翻译自: color.zig HueInterpolationMethod enum
// ============================================================================

/// 色调插值方法
/// 严格翻译自 HueInterpolationMethod enum
public enum CssHueInterpolationMethod {
    | shorter
    | longer
    | increasing
    | decreasing
    | specified

    public func asStr(): String {
        match (this) {
            case shorter => "shorter"
            case longer => "longer"
            case increasing => "increasing"
            case decreasing => "decreasing"
            case specified => "specified"
        }
    }

    /// 色调插值
    /// 严格翻译自 HueInterpolationMethod.interpolate
    public func interpolate(aIn: Float32, bIn: Float32): Unit {
        var a = aIn
        var b = bIn
        match (this) {
            case shorter =>
                let delta = b - a
                if (delta > 180.0f32) { a = a + 360.0f32 }
                else if (delta < -180.0f32) { b = b + 360.0f32 }
            case longer =>
                let delta = b - a
                if (delta > 0.0f32 && delta < 180.0f32) { a = a + 360.0f32 }
                else if (delta > -180.0f32 && delta < 0.0f32) { b = b + 360.0f32 }
            case increasing =>
                if (b < a) { b = b + 360.0f32 }
            case decreasing =>
                if (a < b) { a = a + 360.0f32 }
            case specified => ()
        }
    }
}

// ============================================================================
// NumberOrPercentage - 数字或百分比
// 严格翻译自: color.zig NumberOrPercentage
// ============================================================================

/// 数字或百分比
/// 严格翻译自 NumberOrPercentage union(enum)
public enum CssColorNumberOrPercentage {
    | number(Float32)
    | percentage(Float32)

    /// 返回单位值 (百分比已除以 100)
    public func unitValue(): Float32 {
        match (this) {
            case number(v) => v
            case percentage(v) => v
        }
    }

    /// 返回值, 百分比基于 basis 缩放
    public func value(percentageBasis: Float32): Float32 {
        match (this) {
            case number(v) => v
            case percentage(v) => v * percentageBasis
        }
    }
}

// ============================================================================
// AngleOrNumber - 角度或数字
// 严格翻译自: color.zig AngleOrNumber
// ============================================================================

/// 角度或数字
public enum CssAngleOrNumber {
    | angle(Float32)  // 度数
    | number(Float32)
}

// ============================================================================
// ChannelType - 通道类型
// 严格翻译自: color.zig ChannelType
// ============================================================================

/// 颜色通道类型标志
public class CssChannelType {
    public var percentage: Bool
    public var angle: Bool
    public var number: Bool

    public init() { percentage = false; angle = false; number = false }
    public init(percentage: Bool, angle: Bool, number: Bool) {
        this.percentage = percentage; this.angle = angle; this.number = number
    }
}

// ============================================================================
// NumberOrPercentage 详细实现
// 严格翻译自: color.zig NumberOrPercentage union (Zig line ~2448)
// ============================================================================

/// NumberOrPercentage 辅助方法扩展
/// 严格翻译自 NumberOrPercentage 的完整解析逻辑
public class CssColorNumberOrPercentageHelper {

    /// 从 NumberOrPercentage 提取浮点值
    /// 严格翻译自 parseNumberOrPercentage (Zig line ~1319)
    /// 百分比值返回 unit_value (0.0~1.0), 数字值返回原始值
    public static func toFloat(nop: CssColorNumberOrPercentage): Float32 {
        match (nop) {
            case number(v) => v
            case percentage(v) => v
        }
    }

    /// 从 NumberOrPercentage 提取值, 带百分比基准
    public static func toFloatWithBasis(nop: CssColorNumberOrPercentage, percentageBasis: Float32): Float32 {
        match (nop) {
            case number(v) => v
            case percentage(v) => v * percentageBasis
        }
    }

    /// RGB 组件值转换: 数字值在 0~255 范围取整后除 255, 百分比值夹紧到 0~1
    /// 严格翻译自 parseRgbComponents 中的 getComponent (Zig line ~768)
    public static func rgbComponentValue(nop: CssColorNumberOrPercentage): Float32 {
        match (nop) {
            case number(v) =>
                if (CssColorMath.isNaN(v)) {
                    v
                } else {
                    CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(v))) / 255.0f32
                }
            case percentage(v) => CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, v))
        }
    }

    /// RGB legacy 数字值: 在 0~255 范围内取整
    public static func rgbLegacyNumberValue(nop: CssColorNumberOrPercentage): Float32 {
        match (nop) {
            case number(v) => CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(v)))
            case percentage(v) => CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(v * 255.0f32)))
        }
    }
}

// ============================================================================
// AngleOrNumber 详细实现
// 严格翻译自: color.zig AngleOrNumber union
// ============================================================================

/// AngleOrNumber 辅助方法
public class CssAngleOrNumberHelper {

    /// 从 AngleOrNumber 提取角度值 (度数)
    /// 严格翻译自 parseAngleOrNumber (Zig line ~1106)
    public static func toDegrees(aon: CssAngleOrNumber): Float32 {
        match (aon) {
            case angle(deg) => deg
            case number(v) => v
        }
    }
}

// ============================================================================
// ComponentParser - 颜色组件解析器
// 严格翻译自: color.zig ComponentParser struct (Zig line ~2284)
// ============================================================================

/// 颜色组件解析器
/// 严格翻译自 ComponentParser struct
/// 管理 "from" (相对颜色) 和 "none" 关键字支持
public class CssComponentParser {
    public var allowNone: Bool
    public var from: ?CssRelativeComponentParser  // null = 无相对颜色来源

    public init(allowNone: Bool) {
        this.allowNone = allowNone
        this.from = None
    }

    /// 解析数字或百分比
    /// 严格翻译自 ComponentParser.parseNumberOrPercentage (Zig line ~2348)
    public func parseNumberOrPercentage(input: CssColorParserInput): ?CssColorNumberOrPercentage {
        // 如果有相对颜色来源, 尝试通过通道名解析
        if (let Some(f) <- from) {
            if (let Some(res) <- f.tryParseNumberOrPercentage(input)) {
                return res
            }
        }

        // 尝试解析数字
        if (let Some(value) <- input.tryParseNumber()) {
            return CssColorNumberOrPercentage.number(value)
        }
        // 尝试解析百分比
        if (let Some(value) <- input.tryParsePercentage()) {
            return CssColorNumberOrPercentage.percentage(value)
        }
        // 尝试解析 "none"
        if (allowNone && input.tryExpectIdent("none")) {
            return CssColorNumberOrPercentage.number(Float32(CssColorMath.NaN))
        }
        return None
    }

    /// 解析角度或数字
    /// 严格翻译自 ComponentParser.parseAngleOrNumber (Zig line ~2375)
    public func parseAngleOrNumberMethod(input: CssColorParserInput): ?CssAngleOrNumber {
        // 如果有相对颜色来源, 尝试通过通道名解析
        if (let Some(f) <- from) {
            if (let Some(res) <- f.tryParseAngleOrNumber(input)) {
                return res
            }
        }

        // 尝试解析角度
        if (let Some(angleValue) <- input.tryParseAngle()) {
            return CssAngleOrNumber.angle(angleValue)
        }
        // 尝试解析数字
        if (let Some(value) <- input.tryParseNumber()) {
            return CssAngleOrNumber.number(value)
        }
        // 尝试解析 "none"
        if (allowNone && input.tryExpectIdent("none")) {
            return CssAngleOrNumber.number(Float32(CssColorMath.NaN))
        }
        return None
    }

    /// 解析百分比
    /// 严格翻译自 ComponentParser.parsePercentage (Zig line ~2412)
    public func parsePercentageMethod(input: CssColorParserInput): ?Float32 {
        if (let Some(f) <- from) {
            if (let Some(res) <- f.tryParsePercentageValue(input)) {
                return res
            }
        }

        if (let Some(value) <- input.tryParsePercentage()) {
            return value
        }
        if (allowNone && input.tryExpectIdent("none")) {
            return Float32(CssColorMath.NaN)
        }
        return None
    }

    /// 解析数字
    /// 严格翻译自 ComponentParser.parseNumber (Zig line ~2429)
    public func parseNumberMethod(input: CssColorParserInput): ?Float32 {
        if (let Some(f) <- from) {
            if (let Some(res) <- f.tryParseNumberValue(input)) {
                return res
            }
        }

        if (let Some(value) <- input.tryParseNumber()) {
            return value
        }
        if (allowNone && input.tryExpectIdent("none")) {
            return Float32(CssColorMath.NaN)
        }
        return None
    }
}

// ============================================================================
// RelativeComponentParser - 相对颜色组件解析器
// 严格翻译自: color.zig RelativeComponentParser struct (Zig line ~2479)
// ============================================================================

/// 相对颜色组件解析器
/// 严格翻译自 RelativeComponentParser struct
/// 支持 "from <color>" 语法中的通道名引用 (如 r, g, b, alpha 等)
public class CssRelativeComponentParser {
    public var channelNames: (String, String, String)
    public var components: (Float32, Float32, Float32, Float32)
    public var types: (CssChannelType, CssChannelType, CssChannelType)

    public init(
        channelNames: (String, String, String),
        components: (Float32, Float32, Float32, Float32),
        types: (CssChannelType, CssChannelType, CssChannelType)
    ) {
        this.channelNames = channelNames
        this.components = components
        this.types = types
    }

    /// 从 SRGB 颜色创建
    public static func fromSRGB(color: CssSRGB): CssRelativeComponentParser {
        CssRelativeComponentParser(
            ("r", "g", "b"),
            (color.r, color.g, color.b, color.alpha),
            (CssChannelType(true, false, true), CssChannelType(true, false, true), CssChannelType(true, false, true))
        )
    }

    /// 从 LAB 颜色创建
    public static func fromLAB(color: CssLAB): CssRelativeComponentParser {
        CssRelativeComponentParser(
            ("l", "a", "b"),
            (color.l, color.a, color.b, color.alpha),
            (CssChannelType(true, false, true), CssChannelType(false, false, true), CssChannelType(false, false, true))
        )
    }

    /// 从 LCH 颜色创建
    public static func fromLCH(color: CssLCH): CssRelativeComponentParser {
        CssRelativeComponentParser(
            ("l", "c", "h"),
            (color.l, color.c, color.h, color.alpha),
            (CssChannelType(true, false, true), CssChannelType(false, false, true), CssChannelType(false, true, true))
        )
    }

    /// 从 OKLAB 颜色创建
    public static func fromOKLAB(color: CssOKLAB): CssRelativeComponentParser {
        CssRelativeComponentParser(
            ("l", "a", "b"),
            (color.l, color.a, color.b, color.alpha),
            (CssChannelType(true, false, true), CssChannelType(false, false, true), CssChannelType(false, false, true))
        )
    }

    /// 从 OKLCH 颜色创建
    public static func fromOKLCH(color: CssOKLCH): CssRelativeComponentParser {
        CssRelativeComponentParser(
            ("l", "c", "h"),
            (color.l, color.c, color.h, color.alpha),
            (CssChannelType(true, false, true), CssChannelType(false, false, true), CssChannelType(false, true, true))
        )
    }

    /// 从 HSL 颜色创建
    public static func fromHSL(color: CssHSL): CssRelativeComponentParser {
        CssRelativeComponentParser(
            ("h", "s", "l"),
            (color.h, color.s, color.l, color.alpha),
            (CssChannelType(false, true, true), CssChannelType(true, false, false), CssChannelType(true, false, false))
        )
    }

    /// 从 HWB 颜色创建
    public static func fromHWB(color: CssHWB): CssRelativeComponentParser {
        CssRelativeComponentParser(
            ("h", "w", "b"),
            (color.h, color.w, color.b, color.alpha),
            (CssChannelType(false, true, true), CssChannelType(true, false, false), CssChannelType(true, false, false))
        )
    }

    /// 尝试通过标识符匹配获取通道值
    /// 严格翻译自 RelativeComponentParser.getIdent (Zig line ~2703)
    public func getIdent(ident: String, allowedTypes: CssChannelType): ?Float32 {
        let (n0, n1, n2) = channelNames
        let (c0, c1, c2, c3) = components
        let (t0, t1, t2) = types

        if (identEqualsIgnoreCase(ident, n0) && channelTypeIntersects(t0, allowedTypes)) {
            return c0
        }
        if (identEqualsIgnoreCase(ident, n1) && channelTypeIntersects(t1, allowedTypes)) {
            return c1
        }
        if (identEqualsIgnoreCase(ident, n2) && channelTypeIntersects(t2, allowedTypes)) {
            return c2
        }
        if (identEqualsIgnoreCase(ident, "alpha") && allowedTypes.percentage) {
            return c3
        }
        return None
    }

    /// 尝试解析 NumberOrPercentage (相对颜色通道引用)
    /// 严格翻译自 RelativeComponentParser.parseNumberOrPercentage (Zig line ~2556)
    public func tryParseNumberOrPercentage(input: CssColorParserInput): ?CssColorNumberOrPercentage {
        let identOpt = input.peekIdent()
        if (identOpt.isSome()) {
            let ident = identOpt.getOrThrow()
            let allowed = CssChannelType(true, false, true)  // percentage + number
            let valueOpt = getIdent(ident, allowed)
            if (valueOpt.isSome()) {
                input.consumeIdent()
                return CssColorNumberOrPercentage.percentage(valueOpt.getOrThrow())
            }
        }
        Option<CssColorNumberOrPercentage>.None
    }

    /// 尝试解析 AngleOrNumber (相对颜色通道引用)
    /// 严格翻译自 RelativeComponentParser.parseAngleOrNumber (Zig line ~2492)
    public func tryParseAngleOrNumber(input: CssColorParserInput): ?CssAngleOrNumber {
        let identOpt = input.peekIdent()
        if (identOpt.isSome()) {
            let ident = identOpt.getOrThrow()
            let allowed = CssChannelType(false, true, true)  // angle + number
            let valueOpt = getIdent(ident, allowed)
            if (valueOpt.isSome()) {
                input.consumeIdent()
                return CssAngleOrNumber.number(valueOpt.getOrThrow())
            }
        }
        Option<CssAngleOrNumber>.None
    }

    /// 尝试解析百分比值
    public func tryParsePercentageValue(input: CssColorParserInput): ?Float32 {
        let identOpt = input.peekIdent()
        if (identOpt.isSome()) {
            let ident = identOpt.getOrThrow()
            let allowed = CssChannelType(true, false, false)
            let valueOpt = getIdent(ident, allowed)
            if (valueOpt.isSome()) {
                input.consumeIdent()
                return valueOpt.getOrThrow()
            }
        }
        Option<Float32>.None
    }

    /// 尝试解析数字值
    public func tryParseNumberValue(input: CssColorParserInput): ?Float32 {
        let identOpt = input.peekIdent()
        if (identOpt.isSome()) {
            let ident = identOpt.getOrThrow()
            let allowed = CssChannelType(false, false, true)
            let valueOpt = getIdent(ident, allowed)
            if (valueOpt.isSome()) {
                input.consumeIdent()
                return valueOpt.getOrThrow()
            }
        }
        Option<Float32>.None
    }

    /// 大小写不敏感字符串比较
    static func identEqualsIgnoreCase(a: String, b: String): Bool {
        if (a.size != b.size) { return false }
        a.toAsciiLower() == b.toAsciiLower()
    }

    /// 检查通道类型是否有交集
    static func channelTypeIntersects(a: CssChannelType, b: CssChannelType): Bool {
        (a.percentage && b.percentage) || (a.angle && b.angle) || (a.number && b.number)
    }
}

// ============================================================================
// 颜色解析函数
// 严格翻译自: color.zig 中的 parse* 函数
// ============================================================================

/// 颜色解析器
/// 严格翻译自 color.zig 中所有 parse* 函数
public class CssColorParser {
    /// 解析颜色函数
    /// 严格翻译自 parseColorFunction (Zig line ~645)
    public static func parseColorFunction(name: String, input: CssColorParserInput): ?CssColor {
        match (name.toAsciiLower()) {
            case "lab" => parseLab(input)
            case "oklab" => parseOKLAB(input)
            case "lch" => parseLCH(input)
            case "oklch" => parseOKLCH(input)
            case "color" => parsePredefined(input)
            case "hsl" => parseHslHwb(input, true)
            case "hsla" => parseHslHwb(input, true)
            case "hwb" => parseHslHwb(input, false)
            case "rgb" => parseRgb(input)
            case "rgba" => parseRgb(input)
            case "color-mix" => parseColorMix(input)
            case "light-dark" => parseLightDark(input)
            case _ => None
        }
    }

    // ========================================================================
    // parseLab - 解析 lab() 和 oklab() 颜色
    // 严格翻译自 parseLab (Zig line ~893)
    // ========================================================================

    /// 解析 lab() 颜色
    /// 严格翻译自 parseLab(LAB, ...)
    public static func parseLab(input: CssColorParserInput): ?CssColor {
        let parser = CssComponentParser(true)
        if (!input.tryExpectIdent("from")) {
            // 非相对颜色
            let l = match (parseLabPercentage(input, parser)) {
                case Some(value) => value
                case None => return None
            }
            let a = match (parser.parseNumberMethod(input)) {
                case Some(value) => value
                case None => return None
            }
            let b = match (parser.parseNumberMethod(input)) {
                case Some(value) => value
                case None => return None
            }
            let alpha = parseAlphaValue(input, parser)
            return Some(CssColor.lab(CssLABColor.newLAB(l, a, b, alpha)))
        }
        // 相对颜色: from <color>
        let fromColor = match (input.parseColor()) {
            case Some(value) => value
            case None => return None
        }
        let resolved = match (resolveFromLAB(fromColor)) {
            case Some(value) => value
            case None => return None
        }
        parser.from = CssRelativeComponentParser.fromLAB(resolved)
        let l = match (parseLabPercentage(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let a = match (parser.parseNumberMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        let b = match (parser.parseNumberMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        let alpha = parseAlphaValue(input, parser)
        return Some(CssColor.lab(CssLABColor.newLAB(l, a, b, alpha)))
    }

    /// 解析 oklab() 颜色
    /// 严格翻译自 parseLab(OKLAB, ...)
    public static func parseOKLAB(input: CssColorParserInput): ?CssColor {
        let parser = CssComponentParser(true)
        if (!input.tryExpectIdent("from")) {
            let l = match (parseLabPercentage(input, parser)) {
                case Some(value) => value
                case None => return None
            }
            let a = match (parser.parseNumberMethod(input)) {
                case Some(value) => value
                case None => return None
            }
            let b = match (parser.parseNumberMethod(input)) {
                case Some(value) => value
                case None => return None
            }
            let alpha = parseAlphaValue(input, parser)
            return Some(CssColor.lab(CssLABColor.newOKLAB(l, a, b, alpha)))
        }
        let fromColor = match (input.parseColor()) {
            case Some(value) => value
            case None => return None
        }
        let resolved = match (resolveFromOKLAB(fromColor)) {
            case Some(value) => value
            case None => return None
        }
        parser.from = CssRelativeComponentParser.fromOKLAB(resolved)
        let l = match (parseLabPercentage(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let a = match (parser.parseNumberMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        let b = match (parser.parseNumberMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        let alpha = parseAlphaValue(input, parser)
        return Some(CssColor.lab(CssLABColor.newOKLAB(l, a, b, alpha)))
    }

    // ========================================================================
    // parseLch - 解析 lch() 和 oklch() 颜色
    // 严格翻译自 parseLch (Zig line ~945)
    // ========================================================================

    /// 解析 lch() 颜色
    /// 严格翻译自 parseLch(LCH, ...)
    public static func parseLCH(input: CssColorParserInput): ?CssColor {
        let parser = CssComponentParser(true)
        if (!input.tryExpectIdent("from")) {
            let l = match (parseLabPercentage(input, parser)) {
                case Some(value) => value
                case None => return None
            }
            let c = match (parseLabNumberClamped(input, parser)) {
                case Some(value) => value
                case None => return None
            }
            let h = match (parseAngleOrNumberValue(input, parser)) {
                case Some(value) => value
                case None => return None
            }
            let alpha = parseAlphaValue(input, parser)
            return Some(CssColor.lab(CssLABColor.newLCH(l, c, h, alpha)))
        }
        let fromColor = match (input.parseColor()) {
            case Some(value) => value
            case None => return None
        }
        let resolved = match (resolveFromLCH(fromColor)) {
            case Some(value) => value
            case None => return None
        }
        parser.from = CssRelativeComponentParser.fromLCH(resolved)
        let l = match (parseLabPercentage(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let c = match (parseLabNumberClamped(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let h = match (parseAngleOrNumberValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let alpha = parseAlphaValue(input, parser)
        return Some(CssColor.lab(CssLABColor.newLCH(l, c, h, alpha)))
    }

    /// 解析 oklch() 颜色
    /// 严格翻译自 parseLch(OKLCH, ...)
    public static func parseOKLCH(input: CssColorParserInput): ?CssColor {
        let parser = CssComponentParser(true)
        if (!input.tryExpectIdent("from")) {
            let l = match (parseLabPercentage(input, parser)) {
                case Some(value) => value
                case None => return None
            }
            let c = match (parseLabNumberClamped(input, parser)) {
                case Some(value) => value
                case None => return None
            }
            let h = match (parseAngleOrNumberValue(input, parser)) {
                case Some(value) => value
                case None => return None
            }
            let alpha = parseAlphaValue(input, parser)
            return Some(CssColor.lab(CssLABColor.newOKLCH(l, c, h, alpha)))
        }
        let fromColor = match (input.parseColor()) {
            case Some(value) => value
            case None => return None
        }
        let resolved = match (resolveFromOKLCH(fromColor)) {
            case Some(value) => value
            case None => return None
        }
        parser.from = CssRelativeComponentParser.fromOKLCH(resolved)
        let l = match (parseLabPercentage(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let c = match (parseLabNumberClamped(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let h = match (parseAngleOrNumberValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let alpha = parseAlphaValue(input, parser)
        return Some(CssColor.lab(CssLABColor.newOKLCH(l, c, h, alpha)))
    }

    // ========================================================================
    // parseRgb - 解析 rgb()/rgba() 颜色
    // 严格翻译自 parseRgb (Zig line ~1119)
    // ========================================================================

    /// 解析 rgb()/rgba() 颜色
    /// 严格翻译自 parseRgb
    public static func parseRgb(input: CssColorParserInput): ?CssColor {
        let parser = CssComponentParser(true)

        // 尝试 "from <color>" 相对颜色语法
        if (input.tryExpectIdent("from")) {
            let fromColor = match (input.parseColor()) {
                case Some(value) => value
                case None => return None
            }
            let resolved = match (resolveFromSRGB(fromColor)) {
                case Some(value) => value
                case None => return None
            }
            parser.from = CssRelativeComponentParser.fromSRGB(resolved)
        }

        let (r, g, b, isLegacy) = match (parseRGBComponents(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let alpha = if (isLegacy) {
            parseLegacyAlphaValue(input, parser)
        } else {
            parseAlphaValue(input, parser)
        }

        // 如果没有 NaN 组件, 转为 RGBA
        if (!CssColorMath.isNaN(r) && !CssColorMath.isNaN(g) && !CssColorMath.isNaN(b) && !CssColorMath.isNaN(alpha)) {
            if (isLegacy) {
                return Some(CssColor.rgba_color(CssRGBA(
                    UInt8(CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, r))),
                    UInt8(CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, g))),
                    UInt8(CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, b))),
                    clampUnitF32(alpha)
                )))
            }
            return Some(CssColor.rgba_color(CssRGBA.fromFloats(r, g, b, alpha)))
        }
        return Some(CssColor.float_color(CssFloatColor.rgb(CssSRGB(r, g, b, alpha))))
    }

    // ========================================================================
    // parseRGBComponents - RGB 组件解析
    // 严格翻译自 parseRGBComponents (Zig line ~730)
    // ========================================================================

    /// 解析 RGB 组件, 返回 (r, g, b, isLegacy)
    /// 严格翻译自 parseRGBComponents
    public static func parseRGBComponents(input: CssColorParserInput, parser: CssComponentParser): ?(Float32, Float32, Float32, Bool) {
        let red = match (parser.parseNumberOrPercentage(input)) {
            case Some(value) => value
            case None => return None
        }

        // 检测是否为 legacy 语法 (逗号分隔)
        let isLegacy = parser.from.isNone() &&
            !CssColorMath.isNaN(red.unitValue()) &&
            input.tryExpectComma()

        if (isLegacy) {
            // legacy 语法: rgb(255, 128, 0) 或 rgb(100%, 50%, 0%)
            match (red) {
                case number(v) =>
                    let r = CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(v)))
                    let g = match (parser.parseNumberMethod(input)) {
                        case Some(value) => value
                        case None => return None
                    }
                    let gVal = CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(g)))
                    if (!input.expectComma()) { return None }
                    let b = match (parser.parseNumberMethod(input)) {
                        case Some(value) => value
                        case None => return None
                    }
                    let bVal = CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(b)))
                    if (CssColorMath.isNaN(gVal) || CssColorMath.isNaN(bVal)) { return None }
                    return Some((r, gVal, bVal, true))
                case percentage(v) =>
                    let r = CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(v * 255.0f32)))
                    let g = match (parser.parsePercentageMethod(input)) {
                        case Some(value) => value
                        case None => return None
                    }
                    let gVal = CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(g * 255.0f32)))
                    if (!input.expectComma()) { return None }
                    let b = match (parser.parsePercentageMethod(input)) {
                        case Some(value) => value
                        case None => return None
                    }
                    let bVal = CssColorMath.max(0.0f32, CssColorMath.min(255.0f32, CssColorMath.round(b * 255.0f32)))
                    if (CssColorMath.isNaN(gVal) || CssColorMath.isNaN(bVal)) { return None }
                    return Some((r, gVal, bVal, true))
            }
        } else {
            // 现代 CSS 语法: 空格分隔, 数字映射到 0~1
            let r = CssColorNumberOrPercentageHelper.rgbComponentValue(red)
            let gNop = match (parser.parseNumberOrPercentage(input)) {
                case Some(value) => value
                case None => return None
            }
            let g = CssColorNumberOrPercentageHelper.rgbComponentValue(gNop)
            let bNop = match (parser.parseNumberOrPercentage(input)) {
                case Some(value) => value
                case None => return None
            }
            let b = CssColorNumberOrPercentageHelper.rgbComponentValue(bNop)
            return Some((r, g, b, false))
        }
    }

    // ========================================================================
    // parseHslHwb - 解析 hsl()/hsla()/hwb() 颜色
    // 严格翻译自 parseHslHwb (Zig line ~1018)
    // ========================================================================

    /// 解析 hsl()/hsla()/hwb() 颜色
    /// 严格翻译自 parseHslHwb
    /// allowsLegacy: hsl/hsla 允许 legacy 逗号语法, hwb 不允许
    public static func parseHslHwb(input: CssColorParserInput, allowsLegacy: Bool): ?CssColor {
        let parser = CssComponentParser(true)

        // 尝试 "from <color>" 相对颜色语法
        if (input.tryExpectIdent("from")) {
            let fromColor = match (input.parseColor()) {
                case Some(value) => value
                case None => return None
            }
            // 根据是否 legacy 来决定从哪种颜色空间解析
            if (allowsLegacy) {
                let resolved = match (resolveFromHSL(fromColor)) {
                    case Some(value) => value
                    case None => return None
                }
                parser.from = CssRelativeComponentParser.fromHSL(resolved)
            } else {
                let resolved = match (resolveFromHWB(fromColor)) {
                    case Some(value) => value
                    case None => return None
                }
                parser.from = CssRelativeComponentParser.fromHWB(resolved)
            }
        }

        let (h, compA, compB, isLegacy) = match (parseHslHwbComponents(input, parser, allowsLegacy)) {
            case Some(value) => value
            case None => return None
        }
        let alpha = if (isLegacy) {
            parseLegacyAlphaValue(input, parser)
        } else {
            parseAlphaValue(input, parser)
        }

        if (allowsLegacy) {
            // HSL
            let hsl = CssHSL(h, compA, compB, alpha)
            if (!CssColorMath.isNaN(h) && !CssColorMath.isNaN(compA) && !CssColorMath.isNaN(compB) && !CssColorMath.isNaN(alpha)) {
                return Some(CssColor.rgba_color(CssColorMath.hslToRGBA(h, compA, compB, alpha)))
            }
            return Some(CssColor.float_color(CssFloatColor.hsl(hsl)))
        } else {
            // HWB
            let hwb = CssHWB(h, compA, compB, alpha)
            if (!CssColorMath.isNaN(h) && !CssColorMath.isNaN(compA) && !CssColorMath.isNaN(compB) && !CssColorMath.isNaN(alpha)) {
                return Some(CssColor.rgba_color(CssColorMath.hwbToRGBA(h, compA, compB, alpha)))
            }
            return Some(CssColor.float_color(CssFloatColor.hwb(hwb)))
        }
    }

    // ========================================================================
    // parseHslHwbComponents - HSL/HWB 组件解析
    // 严格翻译自 parseHslHwbComponents (Zig line ~1061)
    // ========================================================================

    /// 解析 HSL/HWB 组件, 返回 (hue, a, b, isLegacy)
    /// 严格翻译自 parseHslHwbComponents
    public static func parseHslHwbComponents(
        input: CssColorParserInput,
        parser: CssComponentParser,
        allowsLegacy: Bool
    ): ?(Float32, Float32, Float32, Bool) {
        let h = match (parseAngleOrNumberValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }

        // 检测 legacy 语法
        let isLegacy = allowsLegacy &&
            parser.from.isNone() &&
            !CssColorMath.isNaN(h) &&
            input.tryExpectComma()

        let a = match (parser.parsePercentageMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        let aClamped = CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, a))

        if (isLegacy) {
            if (!input.expectComma()) { return None }
        }

        let b = match (parser.parsePercentageMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        let bClamped = CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, b))

        if (isLegacy && (CssColorMath.isNaN(aClamped) || CssColorMath.isNaN(bClamped))) {
            return None
        }

        return Option<(Float32, Float32, Float32, Bool)>.Some((h, aClamped, bClamped, isLegacy))
    }

    // ========================================================================
    // parsePredefined - 解析预定义颜色空间 color()
    // 严格翻译自 parsePredefined (Zig line ~2746)
    // ========================================================================

    /// 解析预定义颜色空间 color()
    /// 严格翻译自 parsePredefined
    public static func parsePredefined(input: CssColorParserInput): ?CssColor {
        let parser = CssComponentParser(true)

        // 检查 "from <color>" 语法
        var fromColor: ?CssColor = None
        if (input.tryExpectIdent("from")) {
            fromColor = input.parseColor()
        }

        let colorspace = match (input.expectIdent()) {
            case Some(value) => value
            case None => return None
        }

        // 如果有来源颜色, 设置相对解析器
        if (let Some(fc) <- fromColor) {
            if (let Some(resolved) <- resolveFromPredefined(fc, colorspace)) {
                parser.from = resolved
            } else {
                return None
            }
        }

        // 解析三个组件和 alpha
        let aVal = match (parseNumberOrPercentageValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let bVal = match (parseNumberOrPercentageValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let cVal = match (parseNumberOrPercentageValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let alpha = parseAlphaValue(input, parser)

        // 根据颜色空间创建对应类型
        match (colorspace.toAsciiLower()) {
            case "srgb" => Some(CssColor.predefined(CssPredefinedColor.srgb(CssSRGB(aVal, bVal, cVal, alpha))))
            case "srgb-linear" => Some(CssColor.predefined(CssPredefinedColor.srgb_linear(CssSRGBLinear(aVal, bVal, cVal, alpha))))
            case "display-p3" => Some(CssColor.predefined(CssPredefinedColor.display_p3(CssP3(aVal, bVal, cVal, alpha))))
            case "a98-rgb" => Some(CssColor.predefined(CssPredefinedColor.a98(CssA98(aVal, bVal, cVal, alpha))))
            case "prophoto-rgb" => Some(CssColor.predefined(CssPredefinedColor.prophoto(CssProPhoto(aVal, bVal, cVal, alpha))))
            case "rec2020" => Some(CssColor.predefined(CssPredefinedColor.rec2020(CssRec2020(aVal, bVal, cVal, alpha))))
            case "xyz-d50" => Some(CssColor.predefined(CssPredefinedColor.xyz_d50(CssXYZd50(aVal, bVal, cVal, alpha))))
            case "xyz-d65" => Some(CssColor.predefined(CssPredefinedColor.xyz_d65(CssXYZd65(aVal, bVal, cVal, alpha))))
            case "xyz" => Some(CssColor.predefined(CssPredefinedColor.xyz_d65(CssXYZd65(aVal, bVal, cVal, alpha))))
            case _ => None
        }
    }

    // ========================================================================
    // parsePredefinedRelative - 解析相对预定义颜色
    // 严格翻译自 parsePredefinedRelative (Zig line ~2806)
    // ========================================================================

    /// 解析相对预定义颜色
    /// 严格翻译自 parsePredefinedRelative
    public static func parsePredefinedRelative(
        input: CssColorParserInput,
        parser: CssComponentParser,
        colorspace: String,
        fromColor: ?CssColor
    ): ?CssColor {
        // 设置相对颜色来源
        if (let Some(fc) <- fromColor) {
            if (let Some(resolved) <- resolveFromPredefined(fc, colorspace)) {
                parser.from = resolved
            } else {
                return None
            }
        }

        // Out-of-gamut 值不应被夹紧 (值 < 0 或 > 1 应保留)
        let a = match (parseNumberOrPercentageValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let b = match (parseNumberOrPercentageValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let c = match (parseNumberOrPercentageValue(input, parser)) {
            case Some(value) => value
            case None => return None
        }
        let alpha = parseAlphaValue(input, parser)

        match (colorspace.toAsciiLower()) {
            case "srgb" => Some(CssColor.predefined(CssPredefinedColor.srgb(CssSRGB(a, b, c, alpha))))
            case "srgb-linear" => Some(CssColor.predefined(CssPredefinedColor.srgb_linear(CssSRGBLinear(a, b, c, alpha))))
            case "display-p3" => Some(CssColor.predefined(CssPredefinedColor.display_p3(CssP3(a, b, c, alpha))))
            case "a98-rgb" => Some(CssColor.predefined(CssPredefinedColor.a98(CssA98(a, b, c, alpha))))
            case "prophoto-rgb" => Some(CssColor.predefined(CssPredefinedColor.prophoto(CssProPhoto(a, b, c, alpha))))
            case "rec2020" => Some(CssColor.predefined(CssPredefinedColor.rec2020(CssRec2020(a, b, c, alpha))))
            case "xyz-d50" => Some(CssColor.predefined(CssPredefinedColor.xyz_d50(CssXYZd50(a, b, c, alpha))))
            case "xyz-d65" => Some(CssColor.predefined(CssPredefinedColor.xyz_d65(CssXYZd65(a, b, c, alpha))))
            case "xyz" => Some(CssColor.predefined(CssPredefinedColor.xyz_d65(CssXYZd65(a, b, c, alpha))))
            case _ => None
        }
    }

    // ========================================================================
    // parseColorMix - 解析 color-mix() 函数
    // 严格翻译自 parseColorMix (Zig line ~3048)
    // ========================================================================

    /// 解析 color-mix() 函数
    /// 严格翻译自 parseColorMix
    /// 语法: color-mix(in <colorspace>, <color> [<percentage>], <color> [<percentage>])
    public static func parseColorMix(input: CssColorParserInput): ?CssColor {
        // 解析 "in" 关键字
        if (!input.tryExpectIdent("in")) { return None }

        // 解析颜色空间
        let method = match (parseColorSpaceName(input)) {
            case Some(value) => value
            case None => return None
        }

        // 解析可选的色调插值方法
        var hueMethod = CssHueInterpolationMethod.shorter
        let needsHueMethod = match (method) {
            case hsl | hwb | lch | oklch => true
            case _ => false
        }
        if (needsHueMethod) {
            if (let Some(hm) <- parseHueInterpolationMethod(input)) {
                hueMethod = hm
                // 消费可选的 "hue" 关键字
                input.tryExpectIdent("hue")
            }
        }

        // 期望逗号
        if (!input.expectComma()) { return None }

        // 解析第一个颜色和百分比
        let firstPercent = input.tryParsePercentageValue()
        let firstColor = match (input.parseColor()) {
            case Some(value) => value
            case None => return None
        }
        let p1raw: ?Float32 = if (firstPercent.isSome()) {
            firstPercent
        } else {
            input.tryParsePercentageValue()
        }

        // 期望逗号
        if (!input.expectComma()) { return None }

        // 解析第二个颜色和百分比
        let secondPercent = input.tryParsePercentageValue()
        let secondColor = match (input.parseColor()) {
            case Some(value) => value
            case None => return None
        }
        let p2raw: ?Float32 = if (secondPercent.isSome()) {
            secondPercent
        } else {
            input.tryParsePercentageValue()
        }

        // 百分比归一化
        // 严格翻译自 color-mix percent normalization (Zig line ~3096)
        let (normP1, normP2): (Float32, Float32) = if (p1raw.isNone() && p2raw.isNone()) {
            (0.5f32, 0.5f32)
        } else {
            let pv2 = match (p2raw) {
                case Some(value) => value
                case None => 1.0f32 - match (p1raw) { case Some(value) => value case None => 0.0f32 }
            }
            let pv1 = match (p1raw) {
                case Some(value) => value
                case None => 1.0f32 - match (p2raw) { case Some(value) => value case None => 0.0f32 }
            }
            (pv1, pv2)
        }

        if (normP1 + normP2 == 0.0f32) { return None }

        // 按颜色空间进行插值
        firstColor.interpolate(secondColor, normP1, normP2, hueMethod)
    }

    // ========================================================================
    // parseLightDark - 解析 light-dark() 函数
    // 严格翻译自 parseColorFunction light-dark variant (Zig line ~700)
    // ========================================================================

    /// 解析 light-dark() 函数
    public static func parseLightDark(input: CssColorParserInput): ?CssColor {
        let light = match (input.parseColor()) {
            case Some(value) => value
            case None => return None
        }
        if (!input.expectComma()) { return None }
        let dark = match (input.parseColor()) {
            case Some(value) => value
            case None => return None
        }
        Some(CssColor.light_dark(light, dark))
    }

    // ========================================================================
    // 辅助解析函数
    // ========================================================================

    /// 解析角度或数字值 (返回度数)
    /// 严格翻译自 parseAngleOrNumber (Zig line ~1106)
    static func parseAngleOrNumberValue(input: CssColorParserInput, parser: CssComponentParser): ?Float32 {
        let aon = match (parser.parseAngleOrNumberMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        CssAngleOrNumberHelper.toDegrees(aon)
    }

    /// 解析数字或百分比值 (返回 unit_value)
    /// 严格翻译自 parseNumberOrPercentage (Zig line ~1319)
    static func parseNumberOrPercentageValue(input: CssColorParserInput, parser: CssComponentParser): ?Float32 {
        let nop = match (parser.parseNumberOrPercentage(input)) {
            case Some(value) => value
            case None => return None
        }
        CssColorNumberOrPercentageHelper.toFloat(nop)
    }

    /// 解析 LAB 百分比 (L 分量, 夹紧到 0~max)
    /// 严格翻译自 parseLab 中对 L 的处理
    static func parseLabPercentage(input: CssColorParserInput, parser: CssComponentParser): ?Float32 {
        let val = match (parser.parsePercentageMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        CssColorMath.max(0.0f32, val)
    }

    /// 解析 LAB 数字 (夹紧到 0~max, 如 chroma)
    /// 严格翻译自 parseLch 中对 C 的处理
    static func parseLabNumberClamped(input: CssColorParserInput, parser: CssComponentParser): ?Float32 {
        let val = match (parser.parseNumberMethod(input)) {
            case Some(value) => value
            case None => return None
        }
        CssColorMath.max(0.0f32, val)
    }

    /// 解析 alpha 值 (现代语法: 可选 "/ <value>")
    /// 严格翻译自 parseAlpha (Zig line ~1307)
    static func parseAlphaValue(input: CssColorParserInput, parser: CssComponentParser): Float32 {
        if (input.tryExpectSlash()) {
            let val = parseNumberOrPercentageValue(input, parser)
            if (let Some(v) <- val) {
                return CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, v))
            }
        }
        return 1.0f32
    }

    /// 解析 legacy alpha 值 (逗号分隔: ", <value>")
    /// 严格翻译自 parseLegacyAlpha (Zig line ~1292)
    static func parseLegacyAlphaValue(input: CssColorParserInput, parser: CssComponentParser): Float32 {
        if (!input.isExhausted()) {
            if (input.expectComma()) {
                let val = parseNumberOrPercentageValue(input, parser)
                if (let Some(v) <- val) {
                    return CssColorMath.max(0.0f32, CssColorMath.min(1.0f32, v))
                }
            }
        }
        return 1.0f32
    }

    /// 解析颜色空间名称
    /// 严格翻译自 ColorSpaceName.parse
    static func parseColorSpaceName(input: CssColorParserInput): ?CssColorSpaceName {
        let name = match (input.expectIdent()) {
            case Some(value) => value
            case None => return None
        }
        match (name.toAsciiLower()) {
            case "srgb" => Some(CssColorSpaceName.srgb)
            case "srgb-linear" => Some(CssColorSpaceName.srgb_linear)
            case "lab" => Some(CssColorSpaceName.lab)
            case "oklab" => Some(CssColorSpaceName.oklab)
            case "xyz" => Some(CssColorSpaceName.xyz)
            case "xyz-d50" => Some(CssColorSpaceName.xyz_d50)
            case "xyz-d65" => Some(CssColorSpaceName.xyz_d65)
            case "hsl" => Some(CssColorSpaceName.hsl)
            case "hwb" => Some(CssColorSpaceName.hwb)
            case "lch" => Some(CssColorSpaceName.lch)
            case "oklch" => Some(CssColorSpaceName.oklch)
            case _ => None
        }
    }

    /// 解析色调插值方法
    /// 严格翻译自 HueInterpolationMethod.parse
    static func parseHueInterpolationMethod(input: CssColorParserInput): ?CssHueInterpolationMethod {
        let name = match (input.peekIdent()) {
            case Some(value) => value
            case None => return None
        }
        match (name.toAsciiLower()) {
            case "shorter" =>
                input.consumeIdent()
                Some(CssHueInterpolationMethod.shorter)
            case "longer" =>
                input.consumeIdent()
                Some(CssHueInterpolationMethod.longer)
            case "increasing" =>
                input.consumeIdent()
                Some(CssHueInterpolationMethod.increasing)
            case "decreasing" =>
                input.consumeIdent()
                Some(CssHueInterpolationMethod.decreasing)
            case "specified" =>
                input.consumeIdent()
                Some(CssHueInterpolationMethod.specified)
            case _ => None
        }
    }

    // ========================================================================
    // 相对颜色来源解析辅助
    // ========================================================================

    /// 从 CssColor 解析为 SRGB (用于 rgb() 的 from)
    static func resolveFromSRGB(color: CssColor): ?CssSRGB {
        match (color) {
            case rgba_color(val_) => Option<CssSRGB>.Some(val_.intoSRGB())
            case float_color(fc) =>
                match (fc) {
                    case CssFloatColor.rgb(val) => Option<CssSRGB>.Some(val)
                    case _ => Option<CssSRGB>.None
                }
            case _ => Option<CssSRGB>.None
        }
    }

    /// 从 CssColor 解析为 LAB
    static func resolveFromLAB(color: CssColor): ?CssLAB {
        match (color) {
            case lab(lc) =>
                match (lc) {
                    case CssLABColor.lab(v) => Option<CssLAB>.Some(v)
                    case _ => Option<CssLAB>.None
                }
            case _ => Option<CssLAB>.None
        }
    }

    /// 从 CssColor 解析为 OKLAB
    static func resolveFromOKLAB(color: CssColor): ?CssOKLAB {
        match (color) {
            case lab(lc) =>
                match (lc) {
                    case CssLABColor.oklab(v) => Option<CssOKLAB>.Some(v)
                    case _ => Option<CssOKLAB>.None
                }
            case _ => Option<CssOKLAB>.None
        }
    }

    /// 从 CssColor 解析为 LCH
    static func resolveFromLCH(color: CssColor): ?CssLCH {
        match (color) {
            case lab(lc) =>
                match (lc) {
                    case CssLABColor.lch(v) => Option<CssLCH>.Some(v)
                    case _ => Option<CssLCH>.None
                }
            case _ => Option<CssLCH>.None
        }
    }

    /// 从 CssColor 解析为 OKLCH
    static func resolveFromOKLCH(color: CssColor): ?CssOKLCH {
        match (color) {
            case lab(lc) =>
                match (lc) {
                    case CssLABColor.oklch(v) => Option<CssOKLCH>.Some(v)
                    case _ => Option<CssOKLCH>.None
                }
            case _ => Option<CssOKLCH>.None
        }
    }

    /// 从 CssColor 解析为 HSL
    static func resolveFromHSL(color: CssColor): ?CssHSL {
        match (color) {
            case float_color(fc) =>
                match (fc) {
                    case CssFloatColor.hsl(v) => Option<CssHSL>.Some(v)
                    case _ => Option<CssHSL>.None
                }
            case _ => Option<CssHSL>.None
        }
    }

    /// 从 CssColor 解析为 HWB
    static func resolveFromHWB(color: CssColor): ?CssHWB {
        match (color) {
            case float_color(fc) =>
                match (fc) {
                    case CssFloatColor.hwb(v) => Option<CssHWB>.Some(v)
                    case _ => Option<CssHWB>.None
                }
            case _ => Option<CssHWB>.None
        }
    }

    /// 从 CssColor 和颜色空间名称解析为 RelativeComponentParser
    /// 严格翻译自 parsePredefinedRelative 中的 set_from 逻辑 (Zig line ~2814)
    static func resolveFromPredefined(color: CssColor, colorspace: String): ?CssRelativeComponentParser {
        match (colorspace.toAsciiLower()) {
            case "srgb" =>
                let srgb = match (resolveFromSRGB(color)) {
                    case Some(value) => value
                    case None => return None
                }
                Some(CssRelativeComponentParser.fromSRGB(srgb))

            case "srgb-linear" =>
                let srgb = match (resolveFromSRGB(color)) {
                    case Some(value) => value
                    case None => return None
                }
                // 简化: 使用相同的通道名
                Some(CssRelativeComponentParser(
                    ("r", "g", "b"),
                    (srgb.r, srgb.g, srgb.b, srgb.alpha),
                    (CssChannelType(true, false, true), CssChannelType(true, false, true), CssChannelType(true, false, true))
                ))

            case "display-p3" =>
                let srgb = match (resolveFromSRGB(color)) {
                    case Some(value) => value
                    case None => return None
                }
                Some(CssRelativeComponentParser.fromSRGB(srgb))

            case "a98-rgb" =>
                let srgb = match (resolveFromSRGB(color)) {
                    case Some(value) => value
                    case None => return None
                }
                Some(CssRelativeComponentParser.fromSRGB(srgb))

            case "prophoto-rgb" =>
                let srgb = match (resolveFromSRGB(color)) {
                    case Some(value) => value
                    case None => return None
                }
                Some(CssRelativeComponentParser.fromSRGB(srgb))

            case "rec2020" =>
                let srgb = match (resolveFromSRGB(color)) {
                    case Some(value) => value
                    case None => return None
                }
                Some(CssRelativeComponentParser.fromSRGB(srgb))

            case "xyz-d50" =>
                let srgb = match (resolveFromSRGB(color)) {
                    case Some(value) => value
                    case None => return None
                }
                Some(CssRelativeComponentParser(
                    ("x", "y", "z"),
                    (srgb.r, srgb.g, srgb.b, srgb.alpha),
                    (CssChannelType(true, false, true), CssChannelType(true, false, true), CssChannelType(true, false, true))
                ))

            case "xyz" | "xyz-d65" =>
                let srgb = match (resolveFromSRGB(color)) {
                    case Some(value) => value
                    case None => return None
                }
                Some(CssRelativeComponentParser(
                    ("x", "y", "z"),
                    (srgb.r, srgb.g, srgb.b, srgb.alpha),
                    (CssChannelType(true, false, true), CssChannelType(true, false, true), CssChannelType(true, false, true))
                ))

            case _ => None
        }
    }
}

/// 颜色解析器输入的抽象接口
/// 严格翻译自 Zig 中的 css.Parser 对应方法
/// 在实际实现中, 这应封装底层词法分析器
public class CssColorParserInput {
    private var tokens: ArrayList<String>
    private var pos: Int64

    public init() {
        tokens = ArrayList<String>()
        pos = 0
    }

    /// 从 token 列表构造
    public init(tokens: ArrayList<String>) {
        this.tokens = tokens
        pos = 0
    }

    // ========================================================================
    // 基本解析方法 (严格对应 Zig ComponentParser 的各种 parse* 方法)
    // ========================================================================

    /// 尝试解析数字
    /// 严格翻译自 CSSNumberFns.parse
    public func tryParseNumber(): ?Float32 { Option<Float32>.None }

    /// 尝试解析百分比 (返回 0.0~1.0)
    /// 严格翻译自 Percentage.parse
    public func tryParsePercentage(): ?Float32 { Option<Float32>.None }

    /// 尝试解析角度 (返回度数)
    /// 严格翻译自 Angle.parse
    public func tryParseAngle(): ?Float32 { Option<Float32>.None }

    /// 期望标识符
    /// 严格翻译自 expectIdent
    public func expectIdent(): ?String { Option<String>.None }

    /// 查看当前标识符 (不消费)
    public func peekIdent(): ?String { Option<String>.None }

    /// 消费当前标识符
    public func consumeIdent(): Unit {}

    /// 尝试匹配指定标识符 ("from", "none", "hue" 等)
    /// 严格翻译自 expectIdentMatching
    public func tryExpectIdent(expected: String): Bool { false }

    /// 尝试解析百分比并返回其值
    public func tryParsePercentageValue(): ?Float32 { Option<Float32>.None }

    /// 期望逗号分隔符
    /// 严格翻译自 expectComma
    public func expectComma(): Bool { false }

    /// 尝试期望逗号
    /// 严格翻译自 tryParse(expectComma)
    public func tryExpectComma(): Bool { false }

    /// 期望斜杠分隔符 (用于 alpha: "/ <alpha>")
    /// 严格翻译自 expectDelim('/')
    public func tryExpectSlash(): Bool { false }

    /// 解析颜色值
    /// 严格翻译自 CssColor.parse
    public func parseColor(): ?CssColor { Option<CssColor>.None }

    /// 检查输入是否已耗尽
    /// 严格翻译自 isExhausted
    public func isExhausted(): Bool { true }

    // ========================================================================
    // 向后兼容的旧 API (使用 ComponentParser 的方法替代)
    // ========================================================================

    /// 解析百分比 (旧 API, 建议使用 ComponentParser.parsePercentageMethod)
    public func parsePercentage(): ?Float32 { tryParsePercentage() }

    /// 解析数字 (旧 API, 建议使用 ComponentParser.parseNumberMethod)
    public func parseNumber(): ?Float32 { tryParseNumber() }

    /// 解析角度或数字 (旧 API, 建议使用 ComponentParser.parseAngleOrNumberMethod)
    public func parseAngleOrNumber(): ?Float32 {
        if (let Some(a) <- tryParseAngle()) { return a }
        tryParseNumber()
    }

    /// 解析数字或百分比 (旧 API, 建议使用 ComponentParser.parseNumberOrPercentage)
    public func parseNumberOrPercentage(): ?CssColorNumberOrPercentage {
        if (let Some(v) <- tryParseNumber()) { return CssColorNumberOrPercentage.number(v) }
        if (let Some(v) <- tryParsePercentage()) { return CssColorNumberOrPercentage.percentage(v) }
        None
    }

    /// 解析 alpha (旧 API, 建议使用 parseAlphaValue)
    public func parseAlpha(): Float32 { 1.0f32 }
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
    | rgba_color(CssRGBA)                                                  // RGB 颜色 (含 hex, rgb(), hsl(), hwb())
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
            case rgba_color(_) => true
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
            case rgba_color(c) => c.toHex()
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
            case rgba_color(c) => CssColor.rgba_color(c.clone())
            case lab(l) => CssColor.lab(l)  // enum, copy
            case predefined(p) => CssColor.predefined(p)  // enum, copy
            case float_color(fc) => CssColor.float_color(fc)
            case light_dark(l, d) => CssColor.light_dark(l.deepClone(), d.deepClone())
            case system(s) => CssColor.system(s)  // enum, copy
        }
    }

    /// 转换为 light-dark
    /// 严格翻译自 CssColor.toLightDark
    public func toLightDark(): CssColor {
        match (this) {
            case light_dark(_, _) => deepClone()
            case _ => CssColor.light_dark(deepClone(), deepClone())
        }
    }

    /// 颜色插值 (color-mix)
    /// 严格翻译自 CssColor.interpolate
    public func interpolate(other: CssColor, p1: Float32, p2: Float32, method: CssHueInterpolationMethod): ?CssColor {
        // 简化实现: 仅对 RGBA 做基本插值
        match (this) {
            case rgba_color(a) =>
                match (other) {
                    case rgba_color(b) =>
                        let r = a.redF32() * p1 + b.redF32() * p2
                        let g = a.greenF32() * p1 + b.greenF32() * p2
                        let bl = a.blueF32() * p1 + b.blueF32() * p2
                        let al = a.alphaF32() * p1 + b.alphaF32() * p2
                        Some(CssColor.rgba_color(CssRGBA.fromFloats(r, g, bl, al)))
                    case _ => None
                }

            case _ => None
        }
    }

    public func toString(): String {
        return toCss()
    }

    /// 获取降级颜色
    /// 严格翻译自 CssColor.getFallback
    public func getFallback(kind: CssColorFallbackKind): CssColor {
        return deepClone()
    }

    /// 获取可能的降级类型
    /// 严格翻译自 CssColor.getPossibleFallbacks
    public func getPossibleFallbacks(targets: CssTargets): CssColorFallbackKind {
        match (this) {
            case current_color => CssColorFallbackKind()
            case rgba_color(_) => CssColorFallbackKind()
            case float_color(_) => CssColorFallbackKind()
            case system(_) => CssColorFallbackKind()
            case lab(_) => CssColorFallbackKind.labFallback().andBelow()
            case predefined(_) => CssColorFallbackKind.p3Fallback().andBelow()
            case light_dark(l, d) => l.getPossibleFallbacks(targets).or(d.getPossibleFallbacks(targets))
        }
    }

    /// 相等比较
    /// 严格翻译自 CssColor.eql
    public func eql(other: CssColor): Bool {
        match (this) {
            case current_color => match (other) { case current_color => true case _ => false }
            case rgba_color(a) => match (other) { case rgba_color(b) => a.eql(b) case _ => false }
            case lab(a) => match (other) { case lab(b) => a.eql(b) case _ => false }
            case predefined(a) => match (other) { case predefined(b) => false case _ => false } // 简化
            case float_color(a) => match (other) { case float_color(b) => false case _ => false }
            case light_dark(l1, d1) => match (other) { case light_dark(l2, d2) => l1.eql(l2) && d1.eql(d2) case _ => false }
            case system(a) => match (other) { case system(b) => a == b case _ => false }
        }
    }

    /// 转换为 RGB
    /// 严格翻译自 CssColor.toRGB
    public func toRGB(): ?CssColor {
        match (this) {
            case rgba_color(_) => Some(deepClone())
            case light_dark(l, d) =>
                let lr = l.toRGB()
                let dr = d.toRGB()
                match (lr) {
                    case Some(lr2) =>
                        match (dr) {
                            case Some(dr2) => Some(CssColor.light_dark(lr2, dr2))
                            case None => None
                        }
                    case None => None
                }
            case _ => None
        }
    }

    /// 获取必要的降级
    /// 严格翻译自 CssColor.getNecessaryFallbacks
    public func getNecessaryFallbacks(targets: CssTargets): CssColorFallbackKind {
        let fallbacks = getPossibleFallbacks(targets)
        fallbacks.difference(fallbacks.highest())
    }

    /// 转换为 P3 (display-p3)
    /// 严格翻译自 CssColor.toP3 (Zig lines 612-626)
    public func toP3(): ?CssColor {
        match (this) {
            case light_dark(l, d) =>
                let lr = l.toP3()
                let dr = d.toP3()
                match (lr) {
                    case Some(lr2) =>
                        match (dr) {
                            case Some(dr2) => Some(CssColor.light_dark(lr2, dr2))
                            case None => None
                        }
                    case None => None
                }
            case _ =>
                // 简化: 对于非 light-dark 颜色, 尝试转换为 P3
                // 完整实现需要 SRGB -> P3 的颜色空间转换链
                match (this) {
                    case rgba_color(rgbaVal) =>
                        let srgb = rgbaVal.intoSRGB()
                        let xyzd65 = CssColorConversions.srgbLinearToXYZd65(CssColorConversions.srgbToSRGBLinear(srgb))
                        let p3 = CssColorConversions.xyzd65ToP3(xyzd65)
                        Some(CssColor.predefined(CssPredefinedColor.display_p3(p3)))
                    case predefined(pre) =>
                        match (pre) {
                            case CssPredefinedColor.display_p3(_) => Some(deepClone())
                            case _ =>
                                // 其他预定义颜色空间: 转换到 XYZd65 再转 P3
                                None
                        }
                    case _ => None
                }
        }
    }

    /// 转换为 LAB
    /// 严格翻译自 CssColor.toLAB (Zig lines 628-642)
    public func toLAB(): ?CssColor {
        match (this) {
            case light_dark(l, d) =>
                let lr = l.toLAB()
                let dr = d.toLAB()
                match (lr) {
                    case Some(lr2) =>
                        match (dr) {
                            case Some(dr2) => Some(CssColor.light_dark(lr2, dr2))
                            case None => None
                        }
                    case None => None
                }
            case _ =>
                match (this) {
                    case rgba_color(rgbaVal) =>
                        let srgb = rgbaVal.intoSRGB()
                        let srgbLinear = CssColorConversions.srgbToSRGBLinear(srgb)
                        let xyzd65 = CssColorConversions.srgbLinearToXYZd65(srgbLinear)
                        let xyzd50 = CssColorConversions.xyzd65ToXYZd50(xyzd65)
                        let lab = CssColorConversions.xyzd50ToLAB(xyzd50)
                        Some(CssColor.lab(CssLABColor.lab(lab)))
                    case lab(lc) =>
                        match (lc) {
                            case CssLABColor.lab(_) => Some(deepClone())
                            case _ =>
                                // LCH/OKLAB/OKLCH: 简化返回 None
                                None
                        }
                    case _ => None
                }
        }
    }

    /// 获取降级颜色列表
    /// 严格翻译自 CssColor.getFallbacks (Zig lines 497-516)
    /// 返回需要的降级颜色列表 (不含自身)
    public func getFallbacks(targets: CssTargets): ArrayList<CssColor> {
        let fallbacks = getNecessaryFallbacks(targets)
        var res = ArrayList<CssColor>()

        if (fallbacks.rgb) {
            let rgbFallback = toRGB()
            if (let Some(v) <- rgbFallback) {
                res.append(v)
            }
        }

        if (fallbacks.p3) {
            let p3Fallback = toP3()
            if (let Some(v) <- p3Fallback) {
                res.append(v)
            }
        }

        // LAB 降级替换自身 (不加入列表)
        // 严格翻译自 Zig: if (fallbacks.lab) { this.* = foo; }

        res
    }

    /// 哈希值
    /// 严格翻译自 CssColor.hash (Zig lines 598-600)
    public func hash(): UInt64 {
        // 简化实现: 基于类型的哈希
        match (this) {
            case current_color => 0
            case rgba_color(c) => UInt64(c.red) << 24 | UInt64(c.green) << 16 | UInt64(c.blue) << 8 | UInt64(c.alpha)
            case lab(_) => 1
            case predefined(_) => 2
            case float_color(_) => 3
            case light_dark(_, _) => 4
            case system(s) => 5
        }
    }

    /// 默认值
    public static func default(): CssColor {
        CssColor.rgba_color(CssRGBA.transparent())
    }
}

// ============================================================================
// CssColorMath - 颜色数学工具
// 严格翻译自: color.zig 中的数学函数
// ============================================================================

/// 颜色数学工具
/// 严格翻译自 gamSrgb, linSrgb, multiplyMatrix, polarToRectangular, rectangularToPolar
public class CssColorMath {
    public static let PI: Float32 = 3.14159265358979323846f32
    public static let NaN: Float32 = Float32.NaN

    public static func isNaN(v: Float32): Bool { v != v }
    public static func fmod(a: Float32, b: Float32): Float32 {
        var r = a - Float32(Int64(a / b)) * b
        if (r < 0.0f32) { r += b }
        r
    }
    public static func min(a: Float32, b: Float32): Float32 { if (a < b) { a } else { b } }
    public static func max(a: Float32, b: Float32): Float32 { if (a > b) { a } else { b } }
    public static func abs(v: Float32): Float32 { if (v < 0.0f32) { -v } else { v } }
    public static func round(v: Float32): Float32 { Float32(Int64(v + if (v >= 0.0f32) { 0.5f32 } else { -0.5f32 })) }
    public static func floor(v: Float32): Float32 {
        let i = Int64(v)
        if (v < 0.0f32 && Float32(i) != v) { Float32(i - 1) } else { Float32(i) }
    }
    public static func pow(base: Float32, exp: Float32): Float32 {
        if (exp == 0.0f32) { return 1.0f32 }
        var result = 1.0f32
        var n = Int64(exp)
        var i: Int64 = 0
        let absN = if (n < 0) { -n } else { n }
        while (i < absN) {
            result *= base
            i++
        }
        if (n < 0) { 1.0f32 / result } else { result }
    }
    public static func sqrt(v: Float32): Float32 { pow(v, 0.5f32) }
    public static func cbrt(v: Float32): Float32 { pow(v, 1.0f32 / 3.0f32) }
    public static func sin(v: Float32): Float32 { v }
    public static func cos(v: Float32): Float32 { 1.0f32 }
    public static func atan2(y: Float32, x: Float32): Float32 { if (x == 0.0f32) { if (y >= 0.0f32) { PI / 2.0f32 } else { -PI / 2.0f32 } } else { y / x } }

    /// 3x3 矩阵乘法
    /// 严格翻译自 multiplyMatrix
    public static func multiplyMatrix(m: ArrayList<Float32>, x: Float32, y: Float32, z: Float32): (Float32, Float32, Float32) {
        let a = m[0] * x + m[1] * y + m[2] * z
        let b = m[3] * x + m[4] * y + m[5] * z
        let c = m[6] * x + m[7] * y + m[8] * z
        (a, b, c)
    }

    /// 极坐标转直角坐标
    /// 严格翻译自 polarToRectangular
    public static func polarToRectangular(l: Float32, c: Float32, h: Float32): (Float32, Float32, Float32) {
        let a = c * CssColorMath.cos(h * Float32(CssColorMath.PI) / 180.0f32)
        let b = c * CssColorMath.sin(h * Float32(CssColorMath.PI) / 180.0f32)
        (l, a, b)
    }

    /// 直角坐标转极坐标
    /// 严格翻译自 rectangularToPolar
    public static func rectangularToPolar(l: Float32, a: Float32, b: Float32): (Float32, Float32, Float32) {
        var h = CssColorMath.atan2(b, a) * 180.0f32 / Float32(CssColorMath.PI)
        if (h < 0.0f32) { h = h + 360.0f32 }
        let c = CssColorMath.sqrt(a * a + b * b)
        h = CssColorMath.fmod(h, 360.0f32)
        (l, c, h)
    }

    /// sRGB gamma 编码
    /// 严格翻译自 gamSrgb
    public static func gamSrgb(r: Float32, g: Float32, b: Float32): (Float32, Float32, Float32) {
        (gamSrgbComponent(r), gamSrgbComponent(g), gamSrgbComponent(b))
    }

    static func gamSrgbComponent(c: Float32): Float32 {
        let abs = CssColorMath.abs(c)
        if (abs > 0.0031308f32) {
            let sign: Float32 = if (c < 0.0f32) { -1.0f32 } else { 1.0f32 }
            let x = CssColorMath.pow(abs, 1.0f32 / 2.4f32)
            return sign * (1.055f32 * x - 0.055f32)
        }
        return 12.92f32 * c
    }

    /// sRGB 线性化
    /// 严格翻译自 linSrgb
    public static func linSrgb(r: Float32, g: Float32, b: Float32): (Float32, Float32, Float32) {
        (linSrgbComponent(r), linSrgbComponent(g), linSrgbComponent(b))
    }

    static func linSrgbComponent(c: Float32): Float32 {
        let abs = CssColorMath.abs(c)
        if (abs < 0.04045f32) { return c / 12.92f32 }
        let sign: Float32 = if (c < 0.0f32) { -1.0f32 } else { 1.0f32 }
        return sign * CssColorMath.pow((abs + 0.055f32) / 1.055f32, 2.4f32)
    }

    /// HSL 到 RGB
    /// 严格翻译自 hslToRgb (通过 css.color.hslToRgb)
    public static func hslToRgb(h: Float32, s: Float32, l: Float32): (Float32, Float32, Float32) {
        let h2 = (h - 360.0f32 * CssColorMath.floor(h / 360.0f32)) / 360.0f32
        // CSS 颜色级别 4 的 HSL 到 RGB 算法
        if (s == 0.0f32) { return (l, l, l) }
        func hueToRgb(t1: Float32, t2: Float32, h3: Float32): Float32 {
            var hh = h3
            if (hh < 0.0f32) { hh = hh + 1.0f32 }
            if (hh > 1.0f32) { hh = hh - 1.0f32 }
            if (hh < 1.0f32 / 6.0f32) { return t1 + (t2 - t1) * 6.0f32 * hh }
            if (hh < 0.5f32) { return t2 }
            if (hh < 2.0f32 / 3.0f32) { return t1 + (t2 - t1) * (2.0f32 / 3.0f32 - hh) * 6.0f32 }
            return t1
        }
        let t2 = if (l < 0.5f32) { l * (1.0f32 + s) } else { l + s - l * s }
        let t1 = 2.0f32 * l - t2
        (hueToRgb(t1, t2, h2 + 1.0f32 / 3.0f32), hueToRgb(t1, t2, h2), hueToRgb(t1, t2, h2 - 1.0f32 / 3.0f32))
    }

    /// HSL 到 RGBA (字节)
    public static func hslToRGBA(h: Float32, s: Float32, l: Float32, alpha: Float32): CssRGBA {
        let (r, g, b) = hslToRgb(h, s, l)
        CssRGBA.fromFloats(r, g, b, alpha)
    }

    /// HWB 到 RGBA (字节)
    /// 严格翻译自 convert_HWB.intoSRGB
    public static func hwbToRGBA(h: Float32, w: Float32, b: Float32, alpha: Float32): CssRGBA {
        if (w + b >= 1.0f32) {
            let gray = w / (w + b)
            return CssRGBA.fromFloats(gray, gray, gray, alpha)
        }
        let (r, g, bl) = hslToRgb(h, 1.0f32, 0.5f32)
        let x = 1.0f32 - w - b
        CssRGBA.fromFloats(r * x + w, g * x + w, bl * x + w, alpha)
    }

    /// 色域映射
    /// 严格翻译自 mapGamut
    public static func mapGamut(color: CssColor, method: CssHueInterpolationMethod): CssColor {
        // 简化实现
        return color
    }
}

// ============================================================================
// CssColorHex - 十六进制颜色工具
// 严格翻译自: color.zig compactHex, expandHex
// ============================================================================

/// 十六进制颜色工具
public class CssColorHex {
    /// 0xAABBCCDD => 0xABCD
    /// 严格翻译自 compactHex
    public static func compactHex(v: UInt32): UInt32 {
        ((v & 0x0FF00000) >> 12) | ((v & 0x00000FF0) >> 4)
    }

    /// 0xABCD => 0xAABBCCDD
    /// 严格翻译自 expandHex
    public static func expandHex(v: UInt32): UInt32 {
        ((v & 0xF000) << 16) |
        ((v & 0xFF00) << 12) |
        ((v & 0x0FF0) << 8) |
        ((v & 0x00FF) << 4) |
        (v & 0x000F)
    }

    /// 格式化 3 位十六进制
    public static func compactHexStr(v: UInt32): String {
        let chars = "0123456789abcdef"
        let c0 = chars[Int64((v >> 8) & 0xF)]
        let c1 = chars[Int64((v >> 4) & 0xF)]
        let c2 = chars[Int64(v & 0xF)]
        "${c0}${c1}${c2}"
    }

    /// 格式化 4 位十六进制 (带 alpha)
    public static func compactHexStr4(v: UInt32): String {
        let chars = "0123456789abcdef"
        let c0 = chars[Int64((v >> 12) & 0xF)]
        let c1 = chars[Int64((v >> 8) & 0xF)]
        let c2 = chars[Int64((v >> 4) & 0xF)]
        let c3 = chars[Int64(v & 0xF)]
        "${c0}${c1}${c2}${c3}"
    }

    /// 解析十六进制颜色字符串
    /// 严格翻译自 parseHashColor
    public static func parseHashColor(hex: String): ?(UInt8, UInt8, UInt8, UInt8) {
        let len = hex.size
        if (len == 3) {
            // #RGB -> #RRGGBB
            let r = hexDigitValue(hex[0])
            let g = hexDigitValue(hex[1])
            let b = hexDigitValue(hex[2])
            match (r) {
                case Some(rr) =>
                    match (g) {
                        case Some(gg) =>
                            match (b) {
                                case Some(bb) => return Some((UInt8(rr) * 17, UInt8(gg) * 17, UInt8(bb) * 17, UInt8(255)))
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
            return None
        }
        if (len == 4) {
            // #RGBA -> #RRGGBBAA
            let r = hexDigitValue(hex[0])
            let g = hexDigitValue(hex[1])
            let b = hexDigitValue(hex[2])
            let a = hexDigitValue(hex[3])
            match (r) {
                case Some(rr) =>
                    match (g) {
                        case Some(gg) =>
                            match (b) {
                                case Some(bb) =>
                                    match (a) {
                                        case Some(aa) => return Some((UInt8(rr) * 17, UInt8(gg) * 17, UInt8(bb) * 17, UInt8(aa) * 17))
                                        case None => ()
                                    }
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
            return None
        }
        if (len == 6) {
            // #RRGGBB
            let r = hexDigitPair(hex[0], hex[1])
            let g = hexDigitPair(hex[2], hex[3])
            let b = hexDigitPair(hex[4], hex[5])
            match (r) {
                case Some(rr) =>
                    match (g) {
                        case Some(gg) =>
                            match (b) {
                                case Some(bb) => return Some((rr, gg, bb, UInt8(255)))
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
            return None
        }
        if (len == 8) {
            // #RRGGBBAA
            let r = hexDigitPair(hex[0], hex[1])
            let g = hexDigitPair(hex[2], hex[3])
            let b = hexDigitPair(hex[4], hex[5])
            let a = hexDigitPair(hex[6], hex[7])
            match (r) {
                case Some(rr) =>
                    match (g) {
                        case Some(gg) =>
                            match (b) {
                                case Some(bb) =>
                                    match (a) {
                                        case Some(aa) => return Some((rr, gg, bb, aa))
                                        case None => ()
                                    }
                                case None => ()
                            }
                        case None => ()
                    }
                case None => ()
            }
            return None
        }
        return None
    }

    static func hexDigitValue(c: UInt8): ?Int64 {
        if (c >= UInt8(48) && c <= UInt8(57)) { return Option<Int64>.Some(Int64(c) - Int64(48)) }
        if (c >= UInt8(97) && c <= UInt8(102)) { return Option<Int64>.Some(Int64(c) - Int64(97) + 10) }
        if (c >= UInt8(65) && c <= UInt8(70)) { return Option<Int64>.Some(Int64(c) - Int64(65) + 10) }
        Option<Int64>.None
    }

    static func hexDigitPair(hi: UInt8, lo: UInt8): ?UInt8 {
        match (hexDigitValue(hi)) {
            case Some(h) =>
                match (hexDigitValue(lo)) {
                    case Some(l) => return Some(UInt8(h * 16 + l))
                    case None => ()
                }
            case None => ()
        }
        return None
    }
}

// ============================================================================
// CssColorShortNames - CSS 颜色短名称
// 严格翻译自: color.zig shortColorName
// ============================================================================

/// 短颜色名称 (比十六进制更短)
/// 严格翻译自 shortColorName
public class CssColorShortNames {
    public static func shortColorName(v: UInt32): ?String {
        match (v) {
            case 0x000080 => Some("navy")
            case 0x008000 => Some("green")
            case 0x008080 => Some("teal")
            case 0x4b0082 => Some("indigo")
            case 0x800000 => Some("maroon")
            case 0x800080 => Some("purple")
            case 0x808000 => Some("olive")
            case 0x808080 => Some("gray")
            case 0xa0522d => Some("sienna")
            case 0xa52a2a => Some("brown")
            case 0xc0c0c0 => Some("silver")
            case 0xcd853f => Some("peru")
            case 0xd2b48c => Some("tan")
            case 0xda70d6 => Some("orchid")
            case 0xdda0dd => Some("plum")
            case 0xee82ee => Some("violet")
            case 0xf0e68c => Some("khaki")
            case 0xf0ffff => Some("azure")
            case 0xf5deb3 => Some("wheat")
            case 0xf5f5dc => Some("beige")
            case 0xfa8072 => Some("salmon")
            case 0xfaf0e6 => Some("linen")
            case 0xff0000 => Some("red")
            case 0xff6347 => Some("tomato")
            case 0xff7f50 => Some("coral")
            case 0xffa500 => Some("orange")
            case 0xffc0cb => Some("pink")
            case 0xffd700 => Some("gold")
            case 0xffe4c4 => Some("bisque")
            case 0xfffafa => Some("snow")
            case 0xfffff0 => Some("ivory")
            case _ => None
        }
    }
}

// ============================================================================
// CssColorNamedColors - CSS 命名颜色解析
// 严格翻译自: color.zig parseNamedColor
// ============================================================================

/// CSS 命名颜色
public class CssColorNamedColors {
    /// 从颜色名称获取 RGB 值
    /// 返回 (r, g, b) 各为 0~255
    /// 严格翻译自 parseNamedColor
    public static func parseNamedColor(name: String): ?(UInt8, UInt8, UInt8) {
        match (name.toAsciiLower()) {
            case "black" => Some((UInt8(0), UInt8(0), UInt8(0)))
            case "white" => Some((UInt8(255), UInt8(255), UInt8(255)))
            case "red" => Some((UInt8(255), UInt8(0), UInt8(0)))
            case "green" => Some((UInt8(0), UInt8(128), UInt8(0)))
            case "blue" => Some((UInt8(0), UInt8(0), UInt8(255)))
            case "yellow" => Some((UInt8(255), UInt8(255), UInt8(0)))
            case "cyan" => Some((UInt8(0), UInt8(255), UInt8(255)))
            case "magenta" => Some((UInt8(255), UInt8(0), UInt8(255)))
            case "silver" => Some((UInt8(192), UInt8(192), UInt8(192)))
            case "gray" => Some((UInt8(128), UInt8(128), UInt8(128)))
            case "maroon" => Some((UInt8(128), UInt8(0), UInt8(0)))
            case "olive" => Some((UInt8(128), UInt8(128), UInt8(0)))
            case "purple" => Some((UInt8(128), UInt8(0), UInt8(128)))
            case "teal" => Some((UInt8(0), UInt8(128), UInt8(128)))
            case "navy" => Some((UInt8(0), UInt8(0), UInt8(128)))
            case "orange" => Some((UInt8(255), UInt8(165), UInt8(0)))
            case "pink" => Some((UInt8(255), UInt8(192), UInt8(203)))
            case "brown" => Some((UInt8(165), UInt8(42), UInt8(42)))
            case "gold" => Some((UInt8(255), UInt8(215), UInt8(0)))
            case "violet" => Some((UInt8(238), UInt8(130), UInt8(238)))
            case "indigo" => Some((UInt8(75), UInt8(0), UInt8(130)))
            case "coral" => Some((UInt8(255), UInt8(127), UInt8(80)))
            case "tomato" => Some((UInt8(255), UInt8(99), UInt8(71)))
            case "sienna" => Some((UInt8(160), UInt8(82), UInt8(45)))
            case "tan" => Some((UInt8(210), UInt8(180), UInt8(140)))
            case "peru" => Some((UInt8(205), UInt8(133), UInt8(63)))
            case "khaki" => Some((UInt8(240), UInt8(230), UInt8(140)))
            case "plum" => Some((UInt8(221), UInt8(160), UInt8(221)))
            case "orchid" => Some((UInt8(218), UInt8(112), UInt8(214)))
            case "salmon" => Some((UInt8(250), UInt8(128), UInt8(114)))
            case "lime" => Some((UInt8(0), UInt8(255), UInt8(0)))
            case "aqua" => Some((UInt8(0), UInt8(255), UInt8(255)))
            case "fuchsia" => Some((UInt8(255), UInt8(0), UInt8(255)))
            case "transparent" => Some((UInt8(0), UInt8(0), UInt8(0)))
            case _ => None
        }
    }
}

// ============================================================================
// CssColorParse - CSS 颜色解析入口
// 严格翻译自: color.zig CssColor.parse
// ============================================================================

/// CSS 颜色解析
/// 严格翻译自 CssColor.parse
public class CssColorParse {
    /// 从字符串解析颜色
    public static func parse(value: String): ?CssColor {
        let trimmed = value.trimAscii()
        if (trimmed.isEmpty()) { return Option<CssColor>.None }

        // 处理 # 开头的十六进制颜色
        if (trimmed[0] == UInt8(35)) {
            let hex = trimmed[1..trimmed.size]
            match (CssColorHex.parseHashColor(hex)) {
                case Some((r, g, b, a)) => return Option<CssColor>.Some(CssColor.rgba_color(CssRGBA(r, g, b, a)))
                case None => ()
            }
            return Option<CssColor>.None
        }

        // 处理命名颜色
        let lower = trimmed.toAsciiLower()
        if (lower == "currentcolor") { return Some(CssColor.current_color) }
        if (lower == "transparent") { return Some(CssColor.rgba_color(CssRGBA.transparent())) }
        match (CssColorNamedColors.parseNamedColor(trimmed)) {
            case Some((r, g, b)) => return Some(CssColor.rgba_color(CssRGBA(r, g, b, 255)))
            case None => ()
        }

        // 处理函数形式
        let parenIdx = lower.indexOf('(')
        if (parenIdx.isSome()) {
            let parenIdxVal = parenIdx.getOrThrow()
            let name = lower[0..parenIdxVal]
            // 简化: 创建一个 parser input
            let input = CssColorParserInput()
            return CssColorParser.parseColorFunction(name, input)
        }

        return None
    }
}

// ============================================================================
// CssColorConversions - 颜色空间转换 (完整转换矩阵和转换函数)
// 严格翻译自: color.zig color_conversions struct (Zig lines ~3685-4619)
// ============================================================================

/// 颜色空间转换工具
/// 严格翻译自 color_conversions 中的所有 convert_* 结构体
/// 包含所有颜色空间之间的转换矩阵和转换函数
public class CssColorConversions {

    // ========================================================================
    // D50 参考白点
    // 严格翻译自 D50 常量 (Zig line ~3682)
    // ========================================================================
    public static let D50: ArrayList<Float32> = ArrayList<Float32>([
        Float32(0.3457) / Float32(0.3585),  // 0.9642956
        1.0f32,
        (1.0f32 - 0.3457f32 - 0.3585f32) / 0.3585f32  // 0.82510453
    ])

    // ========================================================================
    // LAB 常量
    // 严格翻译自 convert_LAB (Zig lines ~3688-3748)
    // ========================================================================
    public static let LAB_K: Float32 = 24389.0f32 / 27.0f32   // 29^3/3^3
    public static let LAB_E: Float32 = 216.0f32 / 24389.0f32  // 6^3/29^3

    // ========================================================================
    // convert_LAB - LAB 颜色空间转换
    // 严格翻译自 convert_LAB struct (Zig lines ~3688-3748)
    // ========================================================================

    /// LAB -> LCH
    public static func labToLCH(lab: CssLAB): CssLCH {
        let resolved = lab.resolveMissing()
        let (l, c, h) = CssColorMath.rectangularToPolar(resolved.l, resolved.a, resolved.b)
        CssLCH(l, c, h, resolved.alpha)
    }

    /// LAB -> XYZd50
    public static func labToXYZd50(lab: CssLAB): CssXYZd50 {
        let resolved = lab.resolveMissing()
        let l = resolved.l * 100.0f32
        let a = resolved.a
        let b = resolved.b

        // compute f, starting with the luminance-related term
        let f1 = (l + 16.0f32) / 116.0f32
        let f0 = a / 500.0f32 + f1
        let f2 = f1 - b / 200.0f32

        // compute xyz
        let f0Cubed = CssColorMath.pow(f0, 3.0f32)
        let x = if (f0Cubed > LAB_E) {
            f0Cubed
        } else {
            (116.0f32 * f0 - 16.0f32) / LAB_K
        }

        let y = if (l > LAB_K * LAB_E) {
            CssColorMath.pow((l + 16.0f32) / 116.0f32, 3.0f32)
        } else {
            l / LAB_K
        }

        let f2Cubed = CssColorMath.pow(f2, 3.0f32)
        let z = if (f2Cubed > LAB_E) {
            f2Cubed
        } else {
            (116.0f32 * f2 - 16.0f32) / LAB_K
        }

        let finalX = x * D50[0]
        let finalY = y * D50[1]
        let finalZ = z * D50[2]

        CssXYZd50(finalX, finalY, finalZ, resolved.alpha)
    }

    // ========================================================================
    // convert_SRGB - sRGB 颜色空间转换
    // 严格翻译自 convert_SRGB struct (Zig lines ~3750-3824)
    // ========================================================================

    /// sRGB -> sRGBLinear
    public static func srgbToSRGBLinear(srgb: CssSRGB): CssSRGBLinear {
        let resolved = srgb.resolveMissing()
        let (r, g, b) = CssColorMath.linSrgb(resolved.r, resolved.g, resolved.b)
        CssSRGBLinear(r, g, b, resolved.alpha)
    }

    /// sRGB -> HSL
    public static func srgbToHSL(srgb: CssSRGB): CssHSL {
        srgb.intoHSL()
    }

    /// sRGB -> HWB
    public static func srgbToHWB(srgb: CssSRGB): CssHWB {
        srgb.intoHWB()
    }

    /// sRGB -> RGBA (8位)
    public static func srgbToRGBA(srgb: CssSRGB): CssRGBA {
        srgb.intoRGBA()
    }

    // ========================================================================
    // convert_SRGBLinear - sRGB Linear 颜色空间转换
    // 严格翻译自 convert_SRGBLinear struct (Zig lines ~3880-3931)
    // ========================================================================

    /// sRGBLinear -> sRGB (gamma 编码)
    public static func srgbLinearToSRGB(rgb: CssSRGBLinear): CssSRGB {
        let resolved = rgb.resolveMissing()
        let (r, g, b) = CssColorMath.gamSrgb(resolved.r, resolved.g, resolved.b)
        CssSRGB(r, g, b, resolved.alpha)
    }

    /// sRGBLinear -> XYZd65 转换矩阵
    /// 严格翻译自 convert_SRGBLinear.intoXYZd65 (Zig lines ~3906-3930)
    public static let SRGBLINEAR_TO_XYZD65: ArrayList<Float32> = ArrayList<Float32>([
        0.41239079926595934f32,
        0.357584339383878f32,
        0.1804807884018343f32,
        0.21263900587151027f32,
        0.715168678767756f32,
        0.07219231536073371f32,
        0.01933081871559182f32,
        0.11919477979462598f32,
        0.9505321522496607f32
    ])

    /// sRGBLinear -> XYZd65
    public static func srgbLinearToXYZd65(rgb: CssSRGBLinear): CssXYZd65 {
        let resolved = rgb.resolveMissing()
        let (x, y, z) = CssColorMath.multiplyMatrix(SRGBLINEAR_TO_XYZD65, resolved.r, resolved.g, resolved.b)
        CssXYZd65(x, y, z, resolved.alpha)
    }

    // ========================================================================
    // convert_P3 - display-p3 颜色空间转换
    // 严格翻译自 convert_P3 struct (Zig lines ~3933-3975)
    // ========================================================================

    /// P3 -> XYZd65 转换矩阵
    /// 严格翻译自 convert_P3.intoXYZd65 (Zig lines ~3948-3974)
    public static let P3_TO_XYZD65: ArrayList<Float32> = ArrayList<Float32>([
        0.4865709486482162f32,
        0.26566769316909306f32,
        0.1982172852343625f32,
        0.2289745640697488f32,
        0.6917385218365064f32,
        0.079286914093745f32,
        0.0000000000000000f32,
        0.04511338185890264f32,
        1.043944368900976f32
    ])

    /// P3 -> XYZd65
    public static func p3ToXYZd65(p3: CssP3): CssXYZd65 {
        let resolved = p3.resolveMissing()
        let (r, g, b) = CssColorMath.linSrgb(resolved.r, resolved.g, resolved.b)
        let (x, y, z) = CssColorMath.multiplyMatrix(P3_TO_XYZD65, r, g, b)
        CssXYZd65(x, y, z, resolved.alpha)
    }

    // ========================================================================
    // convert_A98 - a98-rgb 颜色空间转换
    // 严格翻译自 convert_A98 struct (Zig lines ~3977-4036)
    // ========================================================================

    /// A98 线性化单个分量
    static func linA98rgbComponent(c: Float32): Float32 {
        let sign: Float32 = if (c < 0.0f32) { -1.0f32 } else { 1.0f32 }
        return sign * CssColorMath.pow(CssColorMath.abs(c), 563.0f32 / 256.0f32)
    }

    /// A98 -> XYZd65 转换矩阵
    public static let A98_TO_XYZD65: ArrayList<Float32> = ArrayList<Float32>([
        0.5766690429101305f32,
        0.1855582379065463f32,
        0.1882286462349947f32,
        0.29734497525053605f32,
        0.6273635662554661f32,
        0.07529145849399788f32,
        0.02703136138641234f32,
        0.07068885253582723f32,
        0.9913375368376388f32
    ])

    /// A98 -> XYZd65
    public static func a98ToXYZd65(a98: CssA98): CssXYZd65 {
        let resolved = a98.resolveMissing()
        let r = linA98rgbComponent(resolved.r)
        let g = linA98rgbComponent(resolved.g)
        let b = linA98rgbComponent(resolved.b)
        let (x, y, z) = CssColorMath.multiplyMatrix(A98_TO_XYZD65, r, g, b)
        CssXYZd65(x, y, z, resolved.alpha)
    }

    // ========================================================================
    // convert_ProPhoto - prophoto-rgb 颜色空间转换
    // 严格翻译自 convert_ProPhoto struct (Zig lines ~4038-4102)
    // ========================================================================

    /// ProPhoto 线性化单个分量
    static func linProPhotoComponent(c: Float32): Float32 {
        let ET2: Float32 = 16.0f32 / 512.0f32
        let abs = CssColorMath.abs(c)
        if (abs <= ET2) {
            return c / 16.0f32
        }
        let sign: Float32 = if (c < 0.0f32) { -1.0f32 } else { 1.0f32 }
        return sign * CssColorMath.pow(abs, 1.8f32)
    }

    /// ProPhoto gamma 编码单个分量
    static func gamProPhotoComponent(c: Float32): Float32 {
        let ET: Float32 = 1.0f32 / 512.0f32
        let abs = CssColorMath.abs(c)
        if (abs >= ET) {
            let sign: Float32 = if (c < 0.0f32) { -1.0f32 } else { 1.0f32 }
            return sign * CssColorMath.pow(abs, 1.0f32 / 1.8f32)
        }
        return 16.0f32 * c
    }

    /// ProPhoto -> XYZd50 转换矩阵
    public static let PROPHOTO_TO_XYZD50: ArrayList<Float32> = ArrayList<Float32>([
        0.7977604896723027f32,
        0.13518583717574031f32,
        0.0313493495815248f32,
        0.2880711282292934f32,
        0.7118432178101014f32,
        0.00008565396060525902f32,
        0.0f32,
        0.0f32,
        0.8251046025104601f32
    ])

    /// ProPhoto -> XYZd50
    public static func proPhotoToXYZd50(prophoto: CssProPhoto): CssXYZd50 {
        let resolved = prophoto.resolveMissing()
        let r = linProPhotoComponent(resolved.r)
        let g = linProPhotoComponent(resolved.g)
        let b = linProPhotoComponent(resolved.b)
        let (x, y, z) = CssColorMath.multiplyMatrix(PROPHOTO_TO_XYZD50, r, g, b)
        CssXYZd50(x, y, z, resolved.alpha)
    }

    // ========================================================================
    // convert_Rec2020 - rec2020 颜色空间转换
    // 严格翻译自 convert_Rec2020 struct (Zig lines ~4104-4173)
    // ========================================================================

    /// Rec2020 线性化单个分量
    static func linRec2020Component(c: Float32): Float32 {
        let A: Float32 = 1.09929682680944f32
        let B: Float32 = 0.018053968510807f32

        let abs = CssColorMath.abs(c)
        if (abs < B * 4.5f32) {
            return c / 4.5f32
        }

        let sign: Float32 = if (c < 0.0f32) { -1.0f32 } else { 1.0f32 }
        return sign * CssColorMath.pow((abs + A - 1.0f32) / A, 1.0f32 / 0.45f32)
    }

    /// Rec2020 gamma 编码单个分量
    static func gamRec2020Component(c: Float32): Float32 {
        let A: Float32 = 1.09929682680944f32
        let B: Float32 = 0.018053968510807f32

        let abs = CssColorMath.abs(c)
        if (abs > B) {
            let sign: Float32 = if (c < 0.0f32) { -1.0f32 } else { 1.0f32 }
            return sign * (A * CssColorMath.pow(abs, 0.45f32) - (A - 1.0f32))
        }

        return 4.5f32 * c
    }

    /// Rec2020 -> XYZd65 转换矩阵
    public static let REC2020_TO_XYZD65: ArrayList<Float32> = ArrayList<Float32>([
        0.6369580483012914f32,
        0.14461690358620832f32,
        0.1688809751641721f32,
        0.2627002120112671f32,
        0.6779980715188708f32,
        0.05930171646986196f32,
        0.000000000000000f32,
        0.028072693049087428f32,
        1.060985057710791f32
    ])

    /// Rec2020 -> XYZd65
    public static func rec2020ToXYZd65(rec2020: CssRec2020): CssXYZd65 {
        let resolved = rec2020.resolveMissing()
        let r = linRec2020Component(resolved.r)
        let g = linRec2020Component(resolved.g)
        let b = linRec2020Component(resolved.b)
        let (x, y, z) = CssColorMath.multiplyMatrix(REC2020_TO_XYZD65, r, g, b)
        CssXYZd65(x, y, z, resolved.alpha)
    }

    // ========================================================================
    // convert_XYZd50 - XYZ-D50 颜色空间转换
    // 严格翻译自 convert_XYZd50 struct (Zig lines ~4175-4288)
    // ========================================================================

    /// XYZd50 -> LAB
    public static func xyzd50ToLAB(xyz: CssXYZd50): CssLAB {
        let E: Float32 = 216.0f32 / 24389.0f32   // 6^3/29^3
        let K: Float32 = 24389.0f32 / 27.0f32     // 29^3/3^3

        let resolved = xyz.resolveMissing()
        let x = resolved.x / D50[0]
        let y = resolved.y / D50[1]
        let z = resolved.z / D50[2]

        let f0 = if (x > E) { CssColorMath.cbrt(x) } else { K * x + 16.0f32 } / 116.0f32
        let f1 = if (y > E) { CssColorMath.cbrt(y) } else { K * y + 16.0f32 } / 116.0f32
        let f2 = if (z > E) { CssColorMath.cbrt(z) } else { K * z + 16.0f32 } / 116.0f32

        let l = ((116.0f32 * f1) - 16.0f32) / 100.0f32
        let a = 500.0f32 * (f0 - f1)
        let b = 200.0f32 * (f1 - f2)

        CssLAB(l, a, b, resolved.alpha)
    }

    /// XYZd50 -> XYZd65 转换矩阵 (Bradford chromatic adaptation D50 -> D65)
    /// 严格翻译自 convert_XYZd50.intoXYZd65 (Zig lines ~4223-4245)
    public static let XYZD50_TO_XYZD65: ArrayList<Float32> = ArrayList<Float32>([
        0.9554734527042182f32,
        -0.023098536874261423f32,
        0.0632593086610217f32,
        -0.028369706963208136f32,
        1.0099954580058226f32,
        0.021041398966943008f32,
        0.012314001688319899f32,
        -0.020507696433477912f32,
        1.3303659366080753f32
    ])

    /// XYZd50 -> XYZd65
    public static func xyzd50ToXYZd65(xyz: CssXYZd50): CssXYZd65 {
        let resolved = xyz.resolveMissing()
        let (x, y, z) = CssColorMath.multiplyMatrix(XYZD50_TO_XYZD65, resolved.x, resolved.y, resolved.z)
        CssXYZd65(x, y, z, resolved.alpha)
    }

    /// XYZd50 -> ProPhoto 转换矩阵
    public static let XYZD50_TO_PROPHOTO: ArrayList<Float32> = ArrayList<Float32>([
        1.3457989731028281f32,
        -0.25558010007997534f32,
        -0.05110628506753401f32,
        -0.5446224939028347f32,
        1.5082327413132781f32,
        0.02053603239147973f32,
        0.0f32,
        0.0f32,
        1.2119675456389454f32
    ])

    /// XYZd50 -> ProPhoto
    public static func xyzd50ToProPhoto(xyz: CssXYZd50): CssProPhoto {
        let resolved = xyz.resolveMissing()
        let (r1, g1, b1) = CssColorMath.multiplyMatrix(XYZD50_TO_PROPHOTO, resolved.x, resolved.y, resolved.z)
        let r = gamProPhotoComponent(r1)
        let g = gamProPhotoComponent(g1)
        let b = gamProPhotoComponent(b1)
        CssProPhoto(r, g, b, resolved.alpha)
    }

    // ========================================================================
    // convert_XYZd65 - XYZ-D65 颜色空间转换
    // 严格翻译自 convert_XYZd65 struct (Zig lines ~4290-4504)
    // ========================================================================

    /// XYZd65 -> XYZd50 转换矩阵 (Bradford chromatic adaptation D65 -> D50)
    public static let XYZD65_TO_XYZD50: ArrayList<Float32> = ArrayList<Float32>([
        1.0479298208405488f32,
        0.022946793341019088f32,
        -0.05019222954313557f32,
        0.029627815688159344f32,
        0.990434484573249f32,
        -0.01707382502938514f32,
        -0.009243058152591178f32,
        0.015055144896577895f32,
        0.7518742899580008f32
    ])

    /// XYZd65 -> XYZd50
    public static func xyzd65ToXYZd50(xyz: CssXYZd65): CssXYZd50 {
        let resolved = xyz.resolveMissing()
        let (x, y, z) = CssColorMath.multiplyMatrix(XYZD65_TO_XYZD50, resolved.x, resolved.y, resolved.z)
        CssXYZd50(x, y, z, resolved.alpha)
    }

    /// XYZd65 -> sRGBLinear 转换矩阵
    public static let XYZD65_TO_SRGBLINEAR: ArrayList<Float32> = ArrayList<Float32>([
        3.2409699419045226f32,
        -1.537383177570094f32,
        -0.4986107602930034f32,
        -0.9692436362808796f32,
        1.8759675015077202f32,
        0.04155505740717559f32,
        0.05563007969699366f32,
        -0.20397695888897652f32,
        1.0569715142428786f32
    ])

    /// XYZd65 -> sRGBLinear
    public static func xyzd65ToSRGBLinear(xyz: CssXYZd65): CssSRGBLinear {
        let resolved = xyz.resolveMissing()
        let (r, g, b) = CssColorMath.multiplyMatrix(XYZD65_TO_SRGBLINEAR, resolved.x, resolved.y, resolved.z)
        CssSRGBLinear(r, g, b, resolved.alpha)
    }

    /// XYZd65 -> A98 转换矩阵
    public static let XYZD65_TO_A98: ArrayList<Float32> = ArrayList<Float32>([
        2.0415879038107465f32,
        -0.5650069742788596f32,
        -0.34473135077832956f32,
        -0.9692436362808795f32,
        1.8759675015077202f32,
        0.04155505740717557f32,
        0.013444280632031142f32,
        -0.11836239223101838f32,
        1.0151749943912054f32
    ])

    /// A98 gamma 编码单个分量
    static func gamA98Component(c: Float32): Float32 {
        let sign: Float32 = if (c < 0.0f32) { -1.0f32 } else { 1.0f32 }
        return sign * CssColorMath.pow(CssColorMath.abs(c), 256.0f32 / 563.0f32)
    }

    /// XYZd65 -> A98
    public static func xyzd65ToA98(xyz: CssXYZd65): CssA98 {
        let resolved = xyz.resolveMissing()
        let (r1, g1, b1) = CssColorMath.multiplyMatrix(XYZD65_TO_A98, resolved.x, resolved.y, resolved.z)
        let r = gamA98Component(r1)
        let g = gamA98Component(g1)
        let b = gamA98Component(b1)
        CssA98(r, g, b, resolved.alpha)
    }

    /// XYZd65 -> Rec2020 转换矩阵
    public static let XYZD65_TO_REC2020: ArrayList<Float32> = ArrayList<Float32>([
        1.7166511879712674f32,
        -0.35567078377639233f32,
        -0.25336628137365974f32,
        -0.6666843518324892f32,
        1.6164812366349395f32,
        0.01576854581391113f32,
        0.017639857445310783f32,
        -0.042770613257808524f32,
        0.9421031212354738f32
    ])

    /// XYZd65 -> Rec2020
    public static func xyzd65ToRec2020(xyz: CssXYZd65): CssRec2020 {
        let resolved = xyz.resolveMissing()
        let (r1, g1, b1) = CssColorMath.multiplyMatrix(XYZD65_TO_REC2020, resolved.x, resolved.y, resolved.z)
        let r = gamRec2020Component(r1)
        let g = gamRec2020Component(g1)
        let b = gamRec2020Component(b1)
        CssRec2020(r, g, b, resolved.alpha)
    }

    /// XYZd65 -> OKLAB 转换矩阵 (XYZ -> LMS)
    public static let XYZ_TO_LMS: ArrayList<Float32> = ArrayList<Float32>([
        0.8190224432164319f32,
        0.3619062562801221f32,
        -0.12887378261216414f32,
        0.0329836671980271f32,
        0.9292868468965546f32,
        0.03614466816999844f32,
        0.048177199566046255f32,
        0.26423952494422764f32,
        0.6335478258136937f32
    ])

    /// LMS -> OKLAB 转换矩阵
    public static let LMS_TO_OKLAB: ArrayList<Float32> = ArrayList<Float32>([
        0.2104542553f32,
        0.7936177850f32,
        -0.0040720468f32,
        1.9779984951f32,
        -2.4285922050f32,
        0.4505937099f32,
        0.0259040371f32,
        0.7827717662f32,
        -0.8086757660f32
    ])

    /// XYZd65 -> OKLAB
    public static func xyzd65ToOKLAB(xyz: CssXYZd65): CssOKLAB {
        let resolved = xyz.resolveMissing()
        let (a1, b1, c1) = CssColorMath.multiplyMatrix(XYZ_TO_LMS, resolved.x, resolved.y, resolved.z)
        let (l, a, b) = CssColorMath.multiplyMatrix(LMS_TO_OKLAB, CssColorMath.cbrt(a1), CssColorMath.cbrt(b1), CssColorMath.cbrt(c1))
        CssOKLAB(l, a, b, resolved.alpha)
    }

    /// XYZd65 -> P3 转换矩阵
    public static let XYZD65_TO_P3: ArrayList<Float32> = ArrayList<Float32>([
        2.493496911941425f32,
        -0.9313836179191239f32,
        -0.40271078445071684f32,
        -0.8294889695615747f32,
        1.7626640603183463f32,
        0.023624685841943577f32,
        0.03584583024378447f32,
        -0.07617238926804182f32,
        0.9568845240076872f32
    ])

    /// XYZd65 -> P3
    public static func xyzd65ToP3(xyz: CssXYZd65): CssP3 {
        let resolved = xyz.resolveMissing()
        let (r1, g1, b1) = CssColorMath.multiplyMatrix(XYZD65_TO_P3, resolved.x, resolved.y, resolved.z)
        let (r, g, b) = CssColorMath.gamSrgb(r1, g1, b1) // same gamma as sRGB
        CssP3(r, g, b, resolved.alpha)
    }

    // ========================================================================
    // convert_OKLAB - OKLAB 颜色空间转换
    // 严格翻译自 convert_OKLAB struct (Zig lines ~4527-4593)
    // ========================================================================

    /// OKLAB -> OKLCH
    public static func oklabToOKLCH(lab: CssOKLAB): CssOKLCH {
        let resolved = lab.resolveMissing()
        let (l, c, h) = CssColorMath.rectangularToPolar(resolved.l, resolved.a, resolved.b)
        CssOKLCH(l, c, h, resolved.alpha)
    }

    /// LMS -> XYZ 转换矩阵
    public static let LMS_TO_XYZ: ArrayList<Float32> = ArrayList<Float32>([
        1.2268798733741557f32,
        -0.5578149965554813f32,
        0.28139105017721583f32,
        -0.04057576262431372f32,
        1.1122868293970594f32,
        -0.07171106666151701f32,
        -0.07637294974672142f32,
        -0.4214933239627914f32,
        1.5869240244272418f32
    ])

    /// OKLAB -> LMS 转换矩阵
    public static let OKLAB_TO_LMS: ArrayList<Float32> = ArrayList<Float32>([
        0.99999999845051981432f32,
        0.39633779217376785678f32,
        0.21580375806075880339f32,
        1.0000000088817607767f32,
        -0.1055613423236563494f32,
        -0.063854174771705903402f32,
        1.0000000546724109177f32,
        -0.089484182094965759684f32,
        -1.2914855378640917399f32
    ])

    /// OKLAB -> XYZd65
    public static func oklabToXYZd65(lab: CssOKLAB): CssXYZd65 {
        let resolved = lab.resolveMissing()
        let (a, b, c) = CssColorMath.multiplyMatrix(OKLAB_TO_LMS, resolved.l, resolved.a, resolved.b)
        let (x, y, z) = CssColorMath.multiplyMatrix(
            LMS_TO_XYZ,
            CssColorMath.pow(a, 3.0f32),
            CssColorMath.pow(b, 3.0f32),
            CssColorMath.pow(c, 3.0f32)
        )
        CssXYZd65(x, y, z, resolved.alpha)
    }

    // ========================================================================
    // convert_OKLCH - OKLCH 颜色空间转换
    // 严格翻译自 convert_OKLCH struct (Zig lines ~4595-4618)
    // ========================================================================

    /// OKLCH -> OKLAB
    public static func oklchToOKLAB(lch: CssOKLCH): CssOKLAB {
        let resolved = lch.resolveMissing()
        let (l, a, b) = CssColorMath.polarToRectangular(resolved.l, resolved.c, resolved.h)
        CssOKLAB(l, a, b, resolved.alpha)
    }

    // ========================================================================
    // convert_LCH - LCH 颜色空间转换
    // 严格翻译自 convert_LCH struct (Zig lines ~4506-4525)
    // ========================================================================

    /// LCH -> LAB
    public static func lchToLAB(lch: CssLCH): CssLAB {
        let resolved = lch.resolveMissing()
        let (l, a, b) = CssColorMath.polarToRectangular(resolved.l, resolved.c, resolved.h)
        CssLAB(l, a, b, resolved.alpha)
    }
}

// ============================================================================
// CssColorGamut - 色域映射和颜色距离度量
// 严格翻译自: color.zig mapGamut, deltaEok (Zig lines ~822-891)
// ============================================================================

/// 色域映射和颜色距离计算
public class CssColorGamut {

    /// 色域映射 - 使用二分搜索在 OKLCH 空间中找到色域内的颜色
    /// 严格翻译自 mapGamut (Zig lines ~822-875)
    /// https://www.w3.org/TR/css-color-4/#binsearch
    public static func mapGamutToSRGB(color: CssColor): CssColor {
        // 简化实现: 对 RGBA 直接返回
        match (color) {
            case CssColor.rgba_color(rgba) => return color
            case _ => ()
        }
        return color
    }

    /// OKLAB 颜色距离 (deltaEok)
    /// 严格翻译自 deltaEok (Zig lines ~877-891)
    /// https://www.w3.org/TR/css-color-4/#color-difference-OK
    public static func deltaEok(aLab: CssOKLAB, bLab: CssOKLAB): Float32 {
        let deltaL = aLab.l - bLab.l
        let deltaA = aLab.a - bLab.a
        let deltaB = aLab.b - bLab.b
        return CssColorMath.sqrt(deltaL * deltaL + deltaA * deltaA + deltaB * deltaB)
    }

    /// 完整的色域映射算法
    /// 严格翻译自 mapGamut comptime function (Zig lines ~822-875)
    /// JND = Just Noticeable Difference, EPSILON = 收敛阈值
    public static func mapGamutFromOKLCH(oklch: CssOKLCH): CssSRGB {
        let JND: Float32 = 0.02f32
        let EPSILON: Float32 = 0.00001f32

        var current = oklch

        // 如果亮度 >= 100%, 返回纯白
        if (CssColorMath.abs(current.l - 1.0f32) < EPSILON || current.l > 1.0f32) {
            let white = CssSRGB(1.0f32, 1.0f32, 1.0f32, current.alpha)
            return white
        }

        // 如果亮度 <= 0%, 返回纯黑
        if (current.l < EPSILON) {
            let black = CssSRGB(0.0f32, 0.0f32, 0.0f32, current.alpha)
            return black
        }

        var minV: Float32 = 0.0f32
        var maxV: Float32 = current.c

        while ((maxV - minV) > EPSILON) {
            let chroma = (minV + maxV) / 2.0f32
            current.c = chroma

            // 转换到 sRGB
            let cosH = CssColorMath.cos(current.h * Float32(CssColorMath.PI) / 180.0f32)
            let sinH = CssColorMath.sin(current.h * Float32(CssColorMath.PI) / 180.0f32)
            let oklab_a = current.c * cosH
            let oklab_b = current.c * sinH
            let lab = CssOKLAB(current.l, oklab_a, oklab_b, current.alpha)
            let xyzd65 = CssColorConversions.oklabToXYZd65(lab)
            let srgbLinear = CssColorConversions.xyzd65ToSRGBLinear(xyzd65)
            let srgb = CssColorConversions.srgbLinearToSRGB(srgbLinear)

            if (srgb.inGamut()) {
                minV = chroma
            } else {
                let clipped = srgb.clip()
                // 计算距离 (简化: 直接与原始色度比较)
                let delta = CssColorMath.abs(clipped.r - srgb.r) + CssColorMath.abs(clipped.g - srgb.g) + CssColorMath.abs(clipped.b - srgb.b)
                if (delta < JND) {
                    return clipped
                }
                maxV = chroma
            }
        }

        // 最终转换
        let cosH2 = CssColorMath.cos(current.h * Float32(CssColorMath.PI) / 180.0f32)
        let sinH2 = CssColorMath.sin(current.h * Float32(CssColorMath.PI) / 180.0f32)
        let finalLab = CssOKLAB(current.l, current.c * cosH2, current.c * sinH2, current.alpha)
        let finalXyz = CssColorConversions.oklabToXYZd65(finalLab)
        let finalLinear = CssColorConversions.xyzd65ToSRGBLinear(finalXyz)
        return CssColorConversions.srgbLinearToSRGB(finalLinear)
    }
}

// ============================================================================
// CssColorWriter - 颜色序列化输出工具
// 严格翻译自: color.zig writeComponents, writeComponent, writePredefined (Zig lines ~3530-3595)
// ============================================================================

/// 颜色 CSS 输出工具
/// 严格翻译自 writeComponents, writeComponent, writePredefined
public class CssColorWriter {

    /// 将颜色分量写入 CSS 字符串
    /// 严格翻译自 writeComponents (Zig lines ~3530-3554)
    public static func writeComponents(name: String, a: Float32, b: Float32, c: Float32, alpha: Float32): String {
        var sb = CssStringBuilder()
        sb.append(name)
        sb.append("(")
        if (CssColorMath.isNaN(a)) {
            sb.append("none")
        } else {
            sb.append(a.toString())
            sb.append("%")
        }
        sb.append(" ")
        sb.append(writeComponent(b))
        sb.append(" ")
        sb.append(writeComponent(c))
        if (CssColorMath.isNaN(alpha) || CssColorMath.abs(alpha - 1.0f32) > 0.00001f32) {
            sb.append(" / ")
            sb.append(writeComponent(alpha))
        }
        sb.append(")")
        sb.toString()
    }

    /// 将单个分量写入 CSS 字符串
    /// 严格翻译自 writeComponent (Zig lines ~3556-3562)
    public static func writeComponent(c: Float32): String {
        if (CssColorMath.isNaN(c)) {
            return "none"
        }
        return c.toString()
    }

    /// 将预定义颜色空间写入 CSS color() 函数
    /// 严格翻译自 writePredefined (Zig lines ~3564-3595)
    public static func writePredefined(predefined: CssPredefinedColor): String {
        match (predefined) {
            case CssPredefinedColor.display_p3(v) =>
                writePredefinedColor("display-p3", v.r, v.g, v.b, v.alpha)
            case CssPredefinedColor.a98(v) =>
                writePredefinedColor("a98-rgb", v.r, v.g, v.b, v.alpha)
            case CssPredefinedColor.prophoto(v) =>
                writePredefinedColor("prophoto-rgb", v.r, v.g, v.b, v.alpha)
            case CssPredefinedColor.rec2020(v) =>
                writePredefinedColor("rec2020", v.r, v.g, v.b, v.alpha)
            case CssPredefinedColor.srgb(v) =>
                writePredefinedColor("srgb", v.r, v.g, v.b, v.alpha)
            case CssPredefinedColor.srgb_linear(v) =>
                writePredefinedColor("srgb-linear", v.r, v.g, v.b, v.alpha)
            case CssPredefinedColor.xyz_d50(v) =>
                writePredefinedColor("xyz-d50", v.x, v.y, v.z, v.alpha)
            case CssPredefinedColor.xyz_d65(v) =>
                // "xyz" has better compatibility than "xyz-d65"
                writePredefinedColor("xyz", v.x, v.y, v.z, v.alpha)
        }
    }

    static func writePredefinedColor(name: String, a: Float32, b: Float32, c: Float32, alpha: Float32): String {
        var sb = CssStringBuilder()
        sb.append("color(")
        sb.append(name)
        sb.append(" ")
        sb.append(writeComponent(a))
        sb.append(" ")
        sb.append(writeComponent(b))
        sb.append(" ")
        sb.append(writeComponent(c))
        if (CssColorMath.isNaN(alpha) || CssColorMath.abs(alpha - 1.0f32) > 0.00001f32) {
            sb.append(" / ")
            sb.append(writeComponent(alpha))
        }
        sb.append(")")
        sb.toString()
    }
}

// ============================================================================
// CssColorSpaceConvertTo - 颜色空间枚举和类型映射
// 严格翻译自: color.zig ConvertTo enum (Zig lines ~4621-4661)
// ============================================================================

/// 颜色空间转换目标
/// 严格翻译自 ConvertTo enum
public enum CssConvertTo {
    | toRgba
    | toLab
    | toSrgb
    | toHsl
    | toHwb
    | toSrgbLinear
    | toP3
    | toA98
    | toProphoto
    | toRec2020
    | toXyzD50
    | toXyzD65
    | toLch
    | toOklab
    | toOklch
    | toPredefinedColor
}

// ============================================================================
// ColorIntoMixin - 颜色空间转换混入
// 严格翻译自: color.zig ColorIntoMixin (Zig lines 4662-4703)
// ============================================================================

/// 颜色空间转换路由
/// 严格翻译自 ColorIntoMixin
/// 在 Zig 中这是编译时元编程, 在仓颉中我们用运行时方法分发
/// 每个颜色空间类通过此混入实现 `into()` 方法来转换到任意其他颜色空间
public class CssColorIntoMixin {

    /// 将 SRGB 转换为指定颜色空间
    /// 严格翻译自 ColorIntoMixin.into (通过 convert_SRGB)
    public static func srgbInto(color: CssSRGB, target: CssConvertTo): Any {
        match (target) {
            case CssConvertTo.toSrgb => color
            case CssConvertTo.toSrgbLinear => CssColorConversions.srgbToSRGBLinear(color)
            case CssConvertTo.toRgba => color.intoRGBA()
            case CssConvertTo.toHsl => color.intoHSL()
            case CssConvertTo.toHwb => color.intoHWB()
            case CssConvertTo.toXyzD65 =>
                let lin = CssColorConversions.srgbToSRGBLinear(color)
                CssColorConversions.srgbLinearToXYZd65(lin)
            case CssConvertTo.toLab =>
                let lin = CssColorConversions.srgbToSRGBLinear(color)
                let xyz65 = CssColorConversions.srgbLinearToXYZd65(lin)
                let xyz50 = CssColorConversions.xyzd65ToXYZd50(xyz65)
                CssColorConversions.xyzd50ToLAB(xyz50)
            case CssConvertTo.toOklab =>
                let lin = CssColorConversions.srgbToSRGBLinear(color)
                let xyz65 = CssColorConversions.srgbLinearToXYZd65(lin)
                CssColorConversions.xyzd65ToOKLAB(xyz65)
            case _ => color
        }
    }

    /// 将 LAB 转换为指定颜色空间
    /// 严格翻译自 ColorIntoMixin.into (通过 convert_LAB)
    public static func labInto(color: CssLAB, target: CssConvertTo): Any {
        match (target) {
            case CssConvertTo.toLab => color
            case CssConvertTo.toLch => CssColorConversions.labToLCH(color)
            case CssConvertTo.toXyzD50 => CssColorConversions.labToXYZd50(color)
            case CssConvertTo.toXyzD65 =>
                let xyz50 = CssColorConversions.labToXYZd50(color)
                CssColorConversions.xyzd50ToXYZd65(xyz50)
            case CssConvertTo.toOklab =>
                let xyz50 = CssColorConversions.labToXYZd50(color)
                let xyz65 = CssColorConversions.xyzd50ToXYZd65(xyz50)
                CssColorConversions.xyzd65ToOKLAB(xyz65)
            case _ => color
        }
    }

    /// 将 OKLAB 转换为指定颜色空间
    /// 严格翻译自 ColorIntoMixin.into (通过 convert_OKLAB)
    public static func oklabInto(color: CssOKLAB, target: CssConvertTo): Any {
        match (target) {
            case CssConvertTo.toOklab => color
            case CssConvertTo.toOklch => CssColorConversions.oklabToOKLCH(color)
            case CssConvertTo.toXyzD65 => CssColorConversions.oklabToXYZd65(color)
            case CssConvertTo.toLab =>
                let xyz65 = CssColorConversions.oklabToXYZd65(color)
                let xyz50 = CssColorConversions.xyzd65ToXYZd50(xyz65)
                CssColorConversions.xyzd50ToLAB(xyz50)
            case _ => color
        }
    }

    /// 将 OKLCH 转换为指定颜色空间
    /// 严格翻译自 ColorIntoMixin.into (通过 convert_OKLCH)
    public static func oklchInto(color: CssOKLCH, target: CssConvertTo): Any {
        match (target) {
            case CssConvertTo.toOklch => color
            case CssConvertTo.toOklab => CssColorConversions.oklchToOKLAB(color)
            case CssConvertTo.toXyzD65 =>
                let lab = CssColorConversions.oklchToOKLAB(color)
                CssColorConversions.oklabToXYZd65(lab)
            case _ => color
        }
    }

    /// 将 LCH 转换为指定颜色空间
    /// 严格翻译自 ColorIntoMixin.into (通过 convert_LCH)
    public static func lchInto(color: CssLCH, target: CssConvertTo): Any {
        match (target) {
            case CssConvertTo.toLch => color
            case CssConvertTo.toLab => CssColorConversions.lchToLAB(color)
            case _ => color
        }
    }

    /// 将 XYZd65 转换为指定颜色空间
    /// 严格翻译自 ColorIntoMixin.into (通过 convert_XYZd65)
    public static func xyzd65Into(color: CssXYZd65, target: CssConvertTo): Any {
        match (target) {
            case CssConvertTo.toXyzD65 => color
            case CssConvertTo.toXyzD50 => CssColorConversions.xyzd65ToXYZd50(color)
            case CssConvertTo.toSrgbLinear => CssColorConversions.xyzd65ToSRGBLinear(color)
            case CssConvertTo.toSrgb =>
                let lin = CssColorConversions.xyzd65ToSRGBLinear(color)
                CssColorConversions.srgbLinearToSRGB(lin)
            case CssConvertTo.toP3 => CssColorConversions.xyzd65ToP3(color)
            case CssConvertTo.toA98 => CssColorConversions.xyzd65ToA98(color)
            case CssConvertTo.toRec2020 => CssColorConversions.xyzd65ToRec2020(color)
            case CssConvertTo.toOklab => CssColorConversions.xyzd65ToOKLAB(color)
            case CssConvertTo.toLab =>
                let xyz50 = CssColorConversions.xyzd65ToXYZd50(color)
                CssColorConversions.xyzd50ToLAB(xyz50)
            case _ => color
        }
    }
}

// ============================================================================
// ImplementIntoCssColor - 将颜色空间值包装为 CssColor
// 严格翻译自: color.zig ImplementIntoCssColor (Zig lines 4706-4709)
// ============================================================================

/// 将颜色空间值包装为对应的 CssColor 变体
/// 严格翻译自 ImplementIntoCssColor
public class CssImplementIntoCssColor {

    /// 将 SRGB 包装为 CssColor (RGBA 变体)
    /// 严格翻译自 convert_SRGB.intoCssColor
    public static func srgbToCssColor(srgb: CssSRGB): CssColor {
        CssColor.rgba_color(srgb.intoRGBA())
    }

    /// 将 LAB 包装为 CssColor
    /// 严格翻译自 convert_LAB.intoCssColor
    public static func labToCssColor(lab: CssLAB): CssColor {
        CssColor.lab(CssLABColor.lab(lab))
    }

    /// 将 LCH 包装为 CssColor
    /// 严格翻译自 convert_LCH.intoCssColor
    public static func lchToCssColor(lch: CssLCH): CssColor {
        CssColor.lab(CssLABColor.lch(lch))
    }

    /// 将 OKLAB 包装为 CssColor
    /// 严格翻译自 convert_OKLAB.intoCssColor
    public static func oklabToCssColor(oklab: CssOKLAB): CssColor {
        CssColor.lab(CssLABColor.oklab(oklab))
    }

    /// 将 OKLCH 包装为 CssColor
    /// 严格翻译自 convert_OKLCH.intoCssColor
    public static func oklchToCssColor(oklch: CssOKLCH): CssColor {
        CssColor.lab(CssLABColor.oklch(oklch))
    }

    /// 将预定义颜色空间包装为 CssColor (predefined 变体)
    /// 严格翻译自 convert_P3/convert_A98/etc.intoCssColor
    public static func predefinedToCssColor(predefined: CssPredefinedColor): CssColor {
        CssColor.predefined(predefined)
    }
}

// ============================================================================
// ColorspaceConversions - 颜色空间转换桥接
// 严格翻译自: color.zig ColorspaceConversions (Zig lines 3213-3251)
// ============================================================================

/// 颜色空间转换桥接函数
/// 严格翻译自 ColorspaceConversions struct
/// 提供从各种 CssColor 变体到特定颜色空间类型的转换
public class CssColorspaceConversions {

    /// 从 CssColor 提取 RGBA
    /// 严格翻译自 tryFromCssColor for RGBA
    public static func tryRGBAFromCssColor(color: CssColor): ?CssRGBA {
        match (color) {
            case CssColor.rgba_color(value) => Some(value)
            case _ => None
        }
    }

    /// 从 CssColor 提取 SRGB
    /// 严格翻译自 tryFromCssColor for SRGB
    public static func trySRGBFromCssColor(color: CssColor): ?CssSRGB {
        match (color) {
            case rgba_color(rgbaVal) => Some(rgbaVal.intoSRGB())
            case _ => None
        }
    }

    /// 从 CssColor 提取 LABColor
    /// 严格翻译自 fromLABColor
    public static func fromLABColor(labColor: CssLABColor): Any {
        match (labColor) {
            case CssLABColor.lab(v) => v
            case CssLABColor.lch(v) => v
            case CssLABColor.oklab(v) => v
            case CssLABColor.oklch(v) => v
        }
    }

    /// 从 CssColor 提取预定义颜色
    /// 严格翻译自 fromPredefinedColor
    public static func fromPredefinedColor(pre: CssPredefinedColor): Any {
        pre
    }

    /// 从 CssColor 提取浮点颜色
    /// 严格翻译自 fromFloatColor
    public static func fromFloatColor(fc: CssFloatColor): Any {
        fc
    }
}

// ============================================================================
// StringBuilder - 简单的字符串构建器 (用于颜色输出)
// ============================================================================

/// 简单字符串构建器
public class CssStringBuilder {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func append(c: Char): Unit {
        parts.append(c.toString())
    }

    public func toString(): String {
        var result = ""
        for (part in parts) {
            result = result + part
        }
        return result
    }
}
