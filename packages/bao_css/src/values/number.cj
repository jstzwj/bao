// bao_css - CSS 数值类型
// 严格翻译自: bun/src/css/values/number.rs
//   对应: values/number.zig - CSSNumber, CSSNumberFns, CSSInteger, CSSIntegerFns
package bao_css.values

import bao_core.*

// ============================================================================
// CSS 数值类型别名
// 严格翻译自: values/number.rs
// CSSNumber = f32, CSSInteger = i32
// ============================================================================

/// CSS <number> 值 (f32)
/// 严格翻译自 CSSNumber = f32
public type CSSNumber = Float64

/// CSS <integer> 值 (i32)
/// 严格翻译自 CSSInteger = i32
public type CSSInteger = Int64

// ============================================================================
// CSSNumberFns
// 严格翻译自: values/number.rs CSSNumberFns
// ============================================================================

/// CSS 数值函数集
/// 严格翻译自 CSSNumberFns struct
public class CSSNumberFns {
    /// 解析 CSS 数值
    /// 严格翻译自 CSSNumberFns::parse
    public static func parse(input: CssParser): Result<CSSNumber> {
        match (input.expectNumber()) {
            case Some(n) => Result<CSSNumber>.ok(n)
            case None => Result<CSSNumber>.err(CssParseError.invalidValue)
        }
    }

    /// 数值转 CSS 文本
    /// 严格翻译自 CSSNumberFns::to_css
    /// 小数: 去前导零 (e.g. 0.5 -> .5 when minified)
    public static func toCss(value: CSSNumber): String {
        if (value != 0.0 && Math.abs(value) < 1.0) {
            let str = "${value}"
            // 去掉前导零: "0.xxx" -> ".xxx" (if minified)
            // 或 "-0.xxx" -> "-.xxx"
            if (value < 0.0) {
                let trimmed = str.trimStart(Array<char>('-', '0'))
                if (trimmed.isEmpty()) { return "0" }
                "-${trimmed}"
            } else {
                let trimmed = str.trimStart(Array<char>('0'))
                if (trimmed.isEmpty()) { return "0" }
                trimmed
            }
        } else {
            // 整数或大数
            let intVal = Int64(value)
            if (Float64(intVal) == value) {
                "${intVal}"
            } else {
                "${value}"
            }
        }
    }

    /// 符号函数
    /// 严格翻译自 CSSNumberFns::sign
    public static func sign(value: CSSNumber): Float64 {
        if (value == 0.0) {
            // 规范忠实: 两个分支都返回 +0.0
            0.0
        } else {
            Math.sign(value)
        }
    }

    /// 不支持从角度转换
    /// 严格翻译自 CSSNumberFns::try_from_angle -> None
    public static func tryFromAngle(angle: CssAngle): ?CSSNumber {
        None
    }
}

// ============================================================================
// CSSIntegerFns
// 严格翻译自: values/number.rs CSSIntegerFns
// ============================================================================

/// CSS 整数函数集
/// 严格翻译自 CSSIntegerFns struct
public class CSSIntegerFns {
    /// 解析 CSS 整数
    /// 严格翻译自 CSSIntegerFns::parse
    public static func parse(input: CssParser): Result<CSSInteger> {
        match (input.expectInteger()) {
            case Some(n) => Result<CSSInteger>.ok(n)
            case None => Result<CSSInteger>.err(CssParseError.invalidValue)
        }
    }

    /// 整数转 CSS 文本
    /// 严格翻译自 CSSIntegerFns::to_css
    public static func toCss(value: CSSInteger): String {
        "${value}"
    }
}
