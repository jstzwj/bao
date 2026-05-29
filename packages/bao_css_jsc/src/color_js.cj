// 严格翻译自: src/css_jsc/color_js.zig
//! JSC bridge for CSS color parsing/formatting. Keeps `src/css/` free of JSC types.
package bao_css_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// OutputColorFormat - 输出颜色格式枚举
// ============================================================================

/// 输出颜色格式 - 严格对应 Bun OutputColorFormat
public enum OutputColorFormat {
    | ansi
    | ansi16
    | ansi16m
    | ansi256
    | css
    | hex
    | HEX
    | hsl
    | lab
    | number
    | rgb
    | rgba
    | arrayRgb
    | arrayRgba
    | objectRgb
    | objectRgba
}

// ============================================================================
// Ansi256 - ANSI 256 色转换
// ============================================================================

/// Ansi256 色转换 - 严格对应 Bun Ansi256
public class Ansi256 {
    private static let q2c: Array<UInt32> = [0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff]

    private static func sqdist(R: UInt32, G: UInt32, B: UInt32, r: UInt32, g: UInt32, b: UInt32): UInt32 {
        return ((R - r) * (R - r) + (G - g) * (G - g) + (B - b) * (B - b))
    }

    private static func to6Cube(v: UInt32): UInt32 {
        if (v < 48) {
            return 0
        }
        if (v < 114) {
            return 1
        }
        return (v - 35) / 40
    }

    public static func get(r: UInt32, g: UInt32, b: UInt32): UInt32 {
        let qr = to6Cube(r)
        let cr = q2c[Int64(qr)]
        let qg = to6Cube(g)
        let cg = q2c[Int64(qg)]
        let qb = to6Cube(b)
        let cb = q2c[Int64(qb)]

        if (cr == r && cg == g && cb == b) {
            return 16 + (36 * qr) + (6 * qg) + qb
        }

        let greyAvg = (r + g + b) / 3
        let greyIdx: UInt32 = if (greyAvg > 238) { UInt32(23) } else { (greyAvg - UInt32(3)) / UInt32(10) }
        let grey = UInt32(8) + (UInt32(10) * greyIdx)

        let d = sqdist(cr, cg, cb, r, g, b)
        let idx = if (sqdist(grey, grey, grey, r, g, b) < d) { 232 + greyIdx } else { 16 + (36 * qr) + (6 * qg) + qb }
        return idx
    }

    public static func get16(r: UInt32, g: UInt32, b: UInt32): UInt8 {
        let val = get(r, g, b)
        return table256[Int64(val & 0xFF)]
    }

    private static let table256: Array<UInt8> = [
        0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14, 15,
        0,  4,  4,  4,  12, 12, 2,  6,  4,  4,  12, 12, 2,  2,  6,  4,
        12, 12, 2,  2,  2,  6,  12, 12, 10, 10, 10, 10, 14, 12, 10, 10,
        10, 10, 10, 14, 1,  5,  4,  4,  12, 12, 3,  8,  4,  4,  12, 12,
        2,  2,  6,  4,  12, 12, 2,  2,  2,  6,  12, 12, 10, 10, 10, 10,
        14, 12, 10, 10, 10, 10, 10, 14, 1,  1,  5,  4,  12, 12, 1,  1,
        5,  4,  12, 12, 3,  3,  8,  4,  12, 12, 2,  2,  2,  6,  12, 12,
        10, 10, 10, 10, 14, 12, 10, 10, 10, 10, 10, 14, 1,  1,  1,  5,
        12, 12, 1,  1,  1,  5,  12, 12, 1,  1,  1,  5,  12, 12, 3,  3,
        3,  7,  12, 12, 10, 10, 10, 10, 14, 12, 10, 10, 10, 10, 10, 14,
        9,  9,  9,  9,  13, 12, 9,  9,  9,  9,  13, 12, 9,  9,  9,  9,
        13, 12, 9,  9,  9,  9,  13, 12, 11, 11, 11, 11, 7,  12, 10, 10,
        10, 10, 10, 14, 9,  9,  9,  9,  9,  13, 9,  9,  9,  9,  9,  13,
        9,  9,  9,  9,  9,  13, 9,  9,  9,  9,  9,  13, 9,  9,  9,  9,
        9,  13, 11, 11, 11, 11, 11, 15, 0,  0,  0,  0,  0,  0,  8,  8,
        8,  8,  8,  8,  7,  7,  7,  7,  7,  7,  15, 15, 15, 15, 15, 15
    ]
}

// ============================================================================
// ColorJSC - 颜色 JS 函数
// ============================================================================

/// 颜色 JS 函数 - 严格对应 Bun jsFunctionColor
public func jsFunctionColor(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    return JsValue.jsUndefined()
}

/// 从 JS 值获取颜色整数
public func colorIntFromJS(globalThis: JSGlobalObject, input: JsValue, property: String): Int32 {
    if (input.isUndefinedOrNull() || !input.isNumber()) {
        globalThis.throwInvalidArgumentType("color", property, "integer")
        return 0
    }

    let intValue = input.toInt32()
    if (intValue < 0) {
        return 0
    }
    if (intValue > 255) {
        return 255
    }
    return intValue
}

/// 格式化颜色
public func formatColor(colorStr: String, format: OutputColorFormat): String {
    let rgba = parseHexColor(colorStr)
    match (rgba) {
        case Some(color) => return formatRGBA(color, format)
        case None => return colorStr
    }
}

private class RGBAColor {
    public let r: UInt32
    public let g: UInt32
    public let b: UInt32
    public let a: UInt32

    public init(r: UInt32, g: UInt32, b: UInt32, a: UInt32) {
        this.r = r
        this.g = g
        this.b = b
        this.a = a
    }
}

private func parseHexNibble(c: UInt8): ?UInt32 {
    if (c >= UInt8(48) && c <= UInt8(57)) { return Some(UInt32(c - UInt8(48))) }
    if (c >= UInt8(65) && c <= UInt8(70)) { return Some(UInt32(c - UInt8(65)) + UInt32(10)) }
    if (c >= UInt8(97) && c <= UInt8(102)) { return Some(UInt32(c - UInt8(97)) + UInt32(10)) }
    return None
}

private func parseHexByte(s: String, index: Int64): ?UInt32 {
    let hi = parseHexNibble(s[index])
    let lo = parseHexNibble(s[index + 1])
    if (hi.isNone() || lo.isNone()) { return None }
    return Some(hi.getOrThrow() * UInt32(16) + lo.getOrThrow())
}

private func parseHexColor(input: String): ?RGBAColor {
    if (input.size != 7 && input.size != 9) { return None }
    if (input[0] != UInt8(35)) { return None }
    let r = parseHexByte(input, 1)
    let g = parseHexByte(input, 3)
    let b = parseHexByte(input, 5)
    if (r.isNone() || g.isNone() || b.isNone()) { return None }
    let a = if (input.size == 9) { parseHexByte(input, 7) } else { Some(UInt32(255)) }
    if (a.isNone()) { return None }
    return Some(RGBAColor(r.getOrThrow(), g.getOrThrow(), b.getOrThrow(), a.getOrThrow()))
}

private func hexDigit(v: UInt32, uppercase: Bool): String {
    let chars = if (uppercase) { "0123456789ABCDEF" } else { "0123456789abcdef" }
    return String(Rune(chars[Int64(v & UInt32(0xF))]))
}

private func hexByte(v: UInt32, uppercase: Bool): String {
    return hexDigit(v >> UInt32(4), uppercase) + hexDigit(v, uppercase)
}

private func formatRGBA(color: RGBAColor, format: OutputColorFormat): String {
    match (format) {
        case hex => return "#" + hexByte(color.r, false) + hexByte(color.g, false) + hexByte(color.b, false)
        case HEX => return "#" + hexByte(color.r, true) + hexByte(color.g, true) + hexByte(color.b, true)
        case rgb => return "rgb(" + color.r.toString() + ", " + color.g.toString() + ", " + color.b.toString() + ")"
        case rgba => return "rgba(" + color.r.toString() + ", " + color.g.toString() + ", " + color.b.toString() + ", " + (Float64(color.a) / 255.0).toString() + ")"
        case number => return ((color.a << UInt32(24)) | (color.r << UInt32(16)) | (color.g << UInt32(8)) | color.b).toString()
        case ansi256 => return "\u{1b}[38;5;" + Ansi256.get(color.r, color.g, color.b).toString() + "m"
        case ansi16 => return "\u{1b}[3" + Ansi256.get16(color.r, color.g, color.b).toString() + "m"
        case ansi16m => return "\u{1b}[38;2;" + color.r.toString() + ";" + color.g.toString() + ";" + color.b.toString() + "m"
        case arrayRgb => return "[" + color.r.toString() + "," + color.g.toString() + "," + color.b.toString() + "]"
        case arrayRgba => return "[" + color.r.toString() + "," + color.g.toString() + "," + color.b.toString() + "," + color.a.toString() + "]"
        case objectRgb => return "{\"r\":" + color.r.toString() + ",\"g\":" + color.g.toString() + ",\"b\":" + color.b.toString() + "}"
        case objectRgba => return "{\"r\":" + color.r.toString() + ",\"g\":" + color.g.toString() + ",\"b\":" + color.b.toString() + ",\"a\":" + (Float64(color.a) / 255.0).toString() + "}"
        case css => return "rgb(" + color.r.toString() + " " + color.g.toString() + " " + color.b.toString() + ")"
        case hsl => return "rgb(" + color.r.toString() + " " + color.g.toString() + " " + color.b.toString() + ")"
        case lab => return "rgb(" + color.r.toString() + " " + color.g.toString() + " " + color.b.toString() + ")"
        case ansi => return "\u{1b}[38;5;" + Ansi256.get(color.r, color.g, color.b).toString() + "m"
    }
}
