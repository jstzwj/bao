// bao_css - CSS 时间值
// 严格翻译自: bun/src/css/values/time.rs
//   对应: values/time.zig - Time { Seconds, Milliseconds }
package bao_css.values

import bao_core.*

// ============================================================================
// 时间值
// 严格翻译自: values/time.rs Time { Seconds(f32), Milliseconds(f32) }
// ============================================================================

public enum CssTimeKind {
    | Seconds       // 秒 (s)
    | Milliseconds  // 毫秒 (ms)

    public operator func ==(right: CssTimeKind): Bool {
        match (this) {
            case Seconds => match (right) { case Seconds => true case _ => false }
            case Milliseconds => match (right) { case Milliseconds => true case _ => false }
        }
    }
}

/// CSS <time> 值
/// 严格翻译自 Time enum { Seconds(f32), Milliseconds(f32) }
/// 时间值可以为显式值或由 calc() 计算, 但总是存储和序列化为计算值
public class CssTime {
    public var kind: CssTimeKind
    public var value: Float64

    public init(kind: CssTimeKind, value: Float64) {
        this.kind = kind
        this.value = value
    }

    /// 解析时间值
    /// 严格翻译自 Time::parse
    public static func parse(input: CssParser): Result<CssTime, CssParseError> {
        let numOpt = input.expectNumber()
        match (numOpt) {
            case Some(num) =>
                let delimOpt = input.expectIdent()
                match (delimOpt) {
                    case Some(unit) =>
                        if (unit == "s") {
                            Result<CssTime, CssParseError>.Ok(CssTime(CssTimeKind.Seconds, num))
                        } else if (unit == "ms") {
                            Result<CssTime, CssParseError>.Ok(CssTime(CssTimeKind.Milliseconds, num))
                        } else {
                            Result<CssTime, CssParseError>.Err(CssParseError.invalidValue)
                        }
                    case None => Result<CssTime, CssParseError>.Err(CssParseError.invalidValue)
                }
            case None => Result<CssTime, CssParseError>.Err(CssParseError.invalidValue)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Time::to_css
    /// 0.1s 比 100ms 短, 更小的值更长
    public func toCss(): String {
        match (kind) {
            case Seconds =>
                if (value > 0.0 && value < 0.1) {
                    "${CSSNumberFns.toCss(value * 1000.0)}ms"
                } else {
                    "${CSSNumberFns.toCss(value)}s"
                }
            case Milliseconds =>
                if (value == 0.0 || value >= 100.0) {
                    "${CSSNumberFns.toCss(value / 1000.0)}s"
                } else {
                    "${CSSNumberFns.toCss(value)}ms"
                }
        }
    }

    /// 是否为零
    /// 严格翻译自 Time::is_zero
    public func isZero(): Bool {
        value == 0.0
    }

    /// 转为毫秒
    /// 严格翻译自 Time::to_ms
    public func toMs(): Float64 {
        match (kind) {
            case Seconds => value * 1000.0
            case Milliseconds => value
        }
    }

    /// 乘以浮点数
    /// 严格翻译自 Time::mul_f32
    public func mulF32(other: Float64): CssTime {
        CssTime(kind, value * other)
    }

    /// 相加
    /// 严格翻译自 Time::add
    public func add(other: CssTime): CssTime {
        op(other, { a: Float64, b: Float64 => a + b })
    }

    /// 内部加法
    /// 严格翻译自 Time::add_internal
    public func addInternal(other: CssTime): CssTime {
        add(other)
    }

    /// 操作
    /// 严格翻译自 Time::op
    public func op(other: CssTime, opFn: (Float64, Float64) -> Float64): CssTime {
        if (kind == CssTimeKind.Seconds && other.kind == CssTimeKind.Milliseconds) {
            return CssTime(CssTimeKind.Seconds, opFn(value, other.value / 1000.0))
        }
        if (kind == CssTimeKind.Milliseconds && other.kind == CssTimeKind.Seconds) {
            return CssTime(CssTimeKind.Milliseconds, opFn(value, other.value * 1000.0))
        }
        return CssTime(kind, opFn(value, other.value))
    }

    /// 偏序比较
    /// 严格翻译自 Time::partial_cmp (基于毫秒)
    public func partialCmp(other: CssTime): ?Ordering {
        let aMs = toMs()
        let bMs = other.toMs()
        if (aMs < bMs) { Some(Ordering.LT) }
        else if (aMs > bMs) { Some(Ordering.GT) }
        else if (aMs == bMs) { Some(Ordering.EQ) }
        else { None }
    }

    /// 符号
    /// 严格翻译自 Time::sign
    public func sign(): Float64 {
        CSSNumberFns.sign(value)
    }

    /// 映射值
    /// 严格翻译自 Time::map
    public func map(mapFn: (Float64) -> Float64): CssTime {
        CssTime(kind, mapFn(value))
    }

    /// 转为 calc
    /// 严格翻译自 Time::into_calc
    public func intoCalc(): CssCalc {
        CssCalc(toCss())
    }

    /// 深拷贝
    public func deepClone(): CssTime {
        CssTime(kind, value)
    }

    /// 相等比较
    public func eql(other: CssTime): Bool {
        kind == other.kind && value == other.value
    }

    public func toString(): String {
        toCss()
    }
}
