// bao_css - CSS 分辨率值
// 严格翻译自: bun/src/css/values/resolution.rs
//   对应: values/resolution.zig - Resolution { Dpi, Dpcm, Dppx }
package bao_css.values

import bao_core.*

// ============================================================================
// 分辨率
// 严格翻译自: values/resolution.rs Resolution { Dpi(f32), Dpcm(f32), Dppx(f32) }
// ============================================================================

/// CSS <resolution> 值
/// 严格翻译自 Resolution enum { Dpi, Dpcm, Dppx }
public class CssResolution {
    public enum CssResolutionKind {
        | Dpi    // dots per inch
        | Dpcm   // dots per centimeter
        | Dppx   // dots per px (also 'x')
    }

    public var kind: CssResolutionKind
    public var value: Float64

    public init(kind: CssResolutionKind, value: Float64) {
        this.kind = kind
        this.value = value
    }

    /// 解析分辨率
    /// 严格翻译自 Resolution::parse
    public static func parse(input: CssParser): Result<CssResolution> {
        let token = input.next()
        match (token) {
            case Some(t) => {
                let dim = t.asDimension()
                match (dim) {
                    case Some(d) => {
                        let unit = d.unit.toLower()
                        match (unit) {
                            "dpi" => Result<CssResolution>.ok(CssResolution(CssResolutionKind.Dpi, d.value))
                            "dpcm" => Result<CssResolution>.ok(CssResolution(CssResolutionKind.Dpcm, d.value))
                            "dppx" => Result<CssResolution>.ok(CssResolution(CssResolutionKind.Dppx, d.value))
                            "x" => Result<CssResolution>.ok(CssResolution(CssResolutionKind.Dppx, d.value))
                            case _ => Result<CssResolution>.err(CssParseError.invalidValue)
                        }
                    }
                    case None => Result<CssResolution>.err(CssParseError.invalidValue)
                }
            }
            case None => Result<CssResolution>.err(CssParseError.invalidValue)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Resolution::to_css
    /// dppx 在兼容时使用 'x' 单位 (更短)
    public func toCss(): String {
        let unitStr = match (kind) {
            case Dpi => "dpi"
            case Dpcm => "dpcm"
            case Dppx => "x"  // 简短形式, 严格翻译自 dest.targets.is_compatible(XResolutionUnit) 路径
        }
        "${CSSNumberFns.toCss(value)}${unitStr}"
    }

    /// 加浮点数
    /// 严格翻译自 Resolution::add_f32
    public func addF32(other: Float64): CssResolution {
        CssResolution(kind, value + other)
    }

    /// 深拷贝
    public func deepClone(): CssResolution {
        CssResolution(kind, value)
    }

    /// 相等比较
    public func eql(other: CssResolution): Bool {
        kind == other.kind && value == other.value
    }

    public func toString(): String {
        toCss()
    }
}
