// bao_css - CSS 比率值
// 严格翻译自: bun/src/css/values/ratio.rs
//   对应: values/ratio.zig - Ratio { numerator, denominator }
package bao_css.values

import bao_core.*

// ============================================================================
// 比率
// 严格翻译自: values/ratio.rs Ratio { numerator: CSSNumber, denominator: CSSNumber }
// ============================================================================

/// CSS <ratio> 值
/// 严格翻译自 Ratio struct { numerator: f32, denominator: f32 }
/// 表示两个数值的比率, 例如 16/9
public class CssRatio {
    public var numerator: Float64
    public var denominator: Float64

    public init(numerator: Float64, denominator: Float64) {
        this.numerator = numerator
        this.denominator = denominator
    }

    /// 解析比率
    /// 严格翻译自 Ratio::parse
    /// 解析第一个数值, 然后可选的 '/' 和第二个数值
    public static func parse(input: CssParser): Result<CssRatio> {
        let firstResult = CSSNumberFns.parse(input)
        let first = match (firstResult) {
            case Ok(n) => n
            case Err(e) => return Result<CssRatio>.err(e)
        }

        // 尝试解析 '/' 和第二个数值
        let slashResult = input.tryParse({ i: CssParser ->
            i.expectDelim('/')
        })
        let second = match (slashResult) {
            case Some(_) => {
                let secondResult = CSSNumberFns.parse(input)
                match (secondResult) {
                    case Ok(n) => n
                    case Err(e) => return Result<CssRatio>.err(e)
                }
            }
            case None => 1.0
        }

        Result<CssRatio>.ok(CssRatio(first, second))
    }

    /// 解析必需的比率 (两个操作数都需要)
    /// 严格翻译自 Ratio::parse_required
    public static func parseRequired(input: CssParser): Result<CssRatio> {
        let firstResult = CSSNumberFns.parse(input)
        let first = match (firstResult) {
            case Ok(n) => n
            case Err(e) => return Result<CssRatio>.err(e)
        }

        let slashResult = input.expectDelim()
        match (slashResult) {
            case Some(_) => {}
            case None => return Result<CssRatio>.err(CssParseError.invalidValue)
        }

        let secondResult = CSSNumberFns.parse(input)
        let second = match (secondResult) {
            case Ok(n) => n
            case Err(e) => return Result<CssRatio>.err(e)
        }

        Result<CssRatio>.ok(CssRatio(first, second))
    }

    /// 加浮点数
    /// 严格翻译自 Ratio::add_f32
    public func addF32(other: Float64): CssRatio {
        CssRatio(numerator + other, denominator)
    }

    /// 相等比较
    /// 严格翻译自 Ratio::eql
    public func eql(other: CssRatio): Bool {
        numerator == other.numerator && denominator == other.denominator
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Ratio::to_css
    public func toCss(): String {
        if (denominator != 1.0) {
            "${CSSNumberFns.toCss(numerator)}/${CSSNumberFns.toCss(denominator)}"
        } else {
            CSSNumberFns.toCss(numerator)
        }
    }

    /// 深拷贝
    public func deepClone(): CssRatio {
        CssRatio(numerator, denominator)
    }

    public func toString(): String {
        toCss()
    }
}
