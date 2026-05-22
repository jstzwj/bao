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
// ColorJSC - 颜色 JS 函数 (stub)
// ============================================================================

/// 颜色 JS 函数 - 严格对应 Bun jsFunctionColor (stub)
public func jsFunctionColor(globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    return JsValue.jsUndefined()
}

/// 从 JS 值获取颜色整数 (stub)
public func colorIntFromJS(globalThis: JSGlobalObject, input: JsValue, property: String): Int32 {
    return 0
}

/// 格式化颜色 (stub)
public func formatColor(colorStr: String, format: OutputColorFormat): String {
    return colorStr
}
