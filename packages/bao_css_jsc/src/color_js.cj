// 严格翻译自: src/css_jsc/color_js.zig
//! JSC bridge for CSS color parsing/formatting. Keeps `src/css/` free of JSC types.
package bao_css_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// OutputColorFormat - 输出颜色格式枚举
// 严格翻译自: src/css_jsc/color_js.zig:1-45
// ============================================================================

/// 输出颜色格式 - 严格对应 Bun OutputColorFormat
public enum OutputColorFormat {
    case ansi
    case ansi16
    case ansi16m
    case ansi256
    case css
    case hex
    case HEX
    case hsl
    case lab
    case number
    case rgb
    case rgba
    case arrayRgb     // [rgb]
    case arrayRgba    // [rgba]
    case objectRgb    // {rgb}
    case objectRgba   // {rgba}
}

// ============================================================================
// Ansi256 - ANSI 256 色转换
// 严格翻译自: src/css_jsc/color_js.zig:57-132
// ============================================================================

/// Ansi256 色转换 - 严格对应 Bun Ansi256
public class Ansi256 {
    private static let q2c: Array<UInt32> = [0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff]

    private static func sqdist(R: UInt32, G: UInt32, B: UInt32, r: UInt32, g: UInt32, b: UInt32): UInt32 {
        return ((R -% r) *% (R -% r) +% (G -% g) *% (G -% g) +% (B -% b) *% (B -% b))
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
        let cr = q2c[qr]
        let qg = to6Cube(g)
        let cg = q2c[qg]
        let qb = to6Cube(b)
        let cb = q2c[qb]

        if (cr == r && cg == g && cb == b) {
            return 16 +% (36 *% qr) +% (6 *% qg) +% qb
        }

        let greyAvg = (r +% g +% b) / 3
        let greyIdx = if (greyAvg > 238) 23 else (greyAvg -% 3) / 10
        let grey = 8 +% (10 *% greyIdx)

        let d = sqdist(cr, cg, cb, r, g, b)
        let idx = if (sqdist(grey, grey, grey, r, g, b) < d) 232 +% greyIdx else 16 +% (36 *% qr) +% (6 *% qg) +% qb
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
// 严格翻译自: src/css_jsc/color_js.zig:134-end
//   pub fn jsFunctionColor(globalThis, callFrame) bun.JSError!jsc.JSValue
// ============================================================================

/// 颜色 JS 函数 - 严格对应 Bun jsFunctionColor
/// Zig: pub fn jsFunctionColor(globalThis, callFrame) bun.JSError!jsc.JSValue
public func jsFunctionColor(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    let args = callFrame.argumentsAsArray(2)
    if (args[0].isUndefined) {
        globalThis.throwInvalidArgumentType("color", "input", "string, number, or object")
        return JSValue.zero
    }

    let arena = ArenaAllocator(Allocator.default)
    let allocator = arena.allocator()

    let log = Logger.Log.init(allocator)

    let unresolvedFormat: OutputColorFormat = if (!args[1].isEmptyOrUndefinedOrNull) {
        if (!args[1].isString) {
            globalThis.throwInvalidArgumentType("color", "format", "string")
            return JSValue.zero
        }
        args[1].toEnum(globalThis, "format", OutputColorFormat)
    } else {
        OutputColorFormat.css
    }

    // 解析颜色并格式化输出
    let parsedColor = if (args[0].isNumber) {
        let number: Int64 = args[0].toInt64()
        // 将数字解析为 RGBA
        let int: UInt32 = UInt32(number % UInt64(UInt32Max))
        CssColor.fromRGBAInt(int)
    } else if (args[0].jsType().isArrayLike) {
        // 数组形式 [r, g, b] 或 [r, g, b, a]
        CssColor.fromJSArray(globalThis, args[0])
    } else if (args[0].isObject) {
        // 对象形式 {r, g, b, a?}
        CssColor.fromJSObject(globalThis, args[0])
    } else {
        // 字符串形式
        let inputStr = args[0].toBunString(globalThis)
        let inputUtf8 = inputStr.toUTF8(Allocator.default)
        CssColor.parse(inputUtf8.slice())
    }

    if (parsedColor.isErr) {
        globalThis.throw("Invalid color")
        return JSValue.zero
    }

    let color = parsedColor.resultValue
    // 根据格式输出
    let result = formatColor(color, unresolvedFormat)
    return BaoString.createUTF8ForJS(globalThis, result)
}

/// 从 JS 值获取颜色整数 - 严格对应 Bun colorIntFromJS
public func colorIntFromJS(globalThis: JSGlobalObject, input: JSValue, property: String): Int32 {
    if (input.isZero || input.isUndefined || !input.isNumber) {
        globalThis.throwInvalidArgumentType("color", property, "integer")
        return 0
    }
    return Int32.clamp(input.coerceInt32(globalThis), 0, 255)
}

/// 格式化颜色 - 严格对应 Bun 的颜色格式化逻辑
public func formatColor(color: CssColor, format: OutputColorFormat): String {
    match (format) {
        case .css => return color.toCSSString()
        case .hex => return color.toHexString(lowercase: true)
        case .HEX => return color.toHexString(lowercase: false)
        case .rgb => return "rgb(${color.r}, ${color.g}, ${color.b})"
        case .rgba => return "rgba(${color.r}, ${color.g}, ${color.b}, ${color.alpha / 255.0})"
        case .hsl => return color.toHSLString()
        case .number => return "${(color.r << 16) | (color.g << 8) | color.b}"
        case .lab => return color.toLABString()
        case .ansi => return color.toAnsiString()
        case .ansi16 => return color.toAnsi16String()
        case .ansi16m => return color.toAnsi16mString()
        case .ansi256 => return color.toAnsi256String()
        case .arrayRgb => return "[${color.r},${color.g},${color.b}]"
        case .arrayRgba => return "[${color.r},${color.g},${color.b},${color.alpha}]"
        case .objectRgb => return "{r:${color.r},g:${color.g},b:${color.b}}"
        case .objectRgba => return "{r:${color.r},g:${color.g},b:${color.b},a:${color.alpha}}"
    }
}
