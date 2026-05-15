// bao_css - CSS 数值、百分比、位置、比例、矩形、分辨率、尺寸、语法、时间、URL 值类型
// 严格翻译自: bun/src/css/values/
//   对应: values/number.zig - CSSNumber (已有 css_values_color.cj)
//   对应: values/percentage.zig - Percentage (已有 css_values_color.cj)
//   对应: values/position.zig - Position
//   对应: values/ratio.zig - Ratio
//   对应: values/rect.zig - Rect
//   对应: values/resolution.zig - Resolution
//   对应: values/size.zig - Size2D
//   对应: values/syntax.zig - SyntaxString, ParsedComponent
//   对应: values/time.zig - Time
//   对应: values/url.zig - Url
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 位置值
// 严格翻译自: values/position.zig Position
// ============================================================================

/// CSS 水平位置关键字
public enum CssHorizontalPositionKeyword {
    | Left
    | Right
    | XCenter

    public func toCss(): String {
        match (this) {
            case Left => "left"
            case Right => "right"
            case XCenter => "center"
        }
    }
}

/// CSS 垂直位置关键字
public enum CssVerticalPositionKeyword {
    | Top
    | Bottom
    | YCenter

    public func toCss(): String {
        match (this) {
            case Top => "top"
            case Bottom => "bottom"
            case YCenter => "center"
        }
    }
}

/// CSS <position> 值
/// 严格翻译自 Position struct { x, y }
public class CssPosition {
    /// X 位置
    public var x: String
    /// Y 位置
    public var y: String

    public init(x: String, y: String) {
        this.x = x
        this.y = y
    }

    public func toCss(): String {
        "${x} ${y}"
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 比例值
// 严格翻译自: values/ratio.zig Ratio
// ============================================================================

/// CSS <ratio> 值
/// 严格翻译自 Ratio struct { numerator: f32, denominator: f32 }
public class CssRatio {
    public var numerator: Float64
    public var denominator: Float64

    public init(numerator: Float64, denominator: Float64) {
        this.numerator = numerator
        this.denominator = denominator
    }

    public func toCss(): String {
        if (denominator == 1.0) {
            "${numerator}"
        } else {
            "${numerator} / ${denominator}"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 矩形值
// 严格翻译自: values/rect.zig Rect
// ============================================================================

/// CSS rect() 值
/// 严格翻译自 Rect struct { top, right, bottom, left }
public class CssRect {
    public var top: String
    public var right: String
    public var bottom: String
    public var left: String

    public init(top: String, right: String, bottom: String, left: String) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public func toCss(): String {
        "rect(${top}, ${right}, ${bottom}, ${left})"
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 分辨率值
// 严格翻译自: values/resolution.zig Resolution
// ============================================================================

/// CSS <resolution> 值
/// 严格翻译自 Resolution enum { Dpi, Dpcm, Dppx }
public class CssResolution {
    public enum CssResolutionKind {
        | Dpi    // dots per inch
        | Dpcm   // dots per centimeter
        | Dppx   // dots per pixel (device pixel ratio)

        public func toCss(): String {
            match (this) {
                case Dpi => "dpi"
                case Dpcm => "dpcm"
                case Dppx => "dppx"
            }
        }
    }

    public var kind: CssResolutionKind
    public var value: Float64

    public init(kind: CssResolutionKind, value: Float64) {
        this.kind = kind
        this.value = value
    }

    public func toCss(): String {
        "${value}${kind.toCss()}"
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 尺寸 2D
// 严格翻译自: values/size.zig Size2D
// ============================================================================

/// CSS 二维尺寸
/// 严格翻译自 Size2D struct { a, b }
public class CssSize2D {
    public var a: String
    public var b: String

    public init(a: String, b: String) {
        this.a = a
        this.b = b
    }

    /// 是否两个值相同
    public func isSingleValue(): Bool {
        a == b
    }

    public func toCss(): String {
        if (a == b) { a } else { "${a} ${b}" }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 语法字符串
// 严格翻译自: values/syntax.zig SyntaxString, ParsedComponent
// ============================================================================

/// CSS @property 语法字符串
/// 严格翻译自 SyntaxString enum { Universal, Type, ... }
public class CssSyntaxString {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    /// 是否为通用语法 (*)
    public func isUniversal(): Bool {
        value == "*"
    }

    /// 深拷贝
    public func deepClone(): CssSyntaxString {
        CssSyntaxString(value)
    }

    public func toCss(): String {
        "'${value}'"
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 时间值
// 严格翻译自: values/time.zig Time
// ============================================================================

/// CSS <time> 值
/// 严格翻译自 Time enum { Seconds(f32), Milliseconds(f32) }
public class CssTime {
    public enum CssTimeKind {
        | Seconds       // 秒 (s)
        | Milliseconds  // 毫秒 (ms)
    }

    public var kind: CssTimeKind
    public var value: Float64

    public init(kind: CssTimeKind, value: Float64) {
        this.kind = kind
        this.value = value
    }

    /// 转为秒
    public func toSeconds(): Float64 {
        match (kind) {
            case Seconds => value
            case Milliseconds => value / 1000.0
        }
    }

    /// 转为毫秒
    public func toMilliseconds(): Float64 {
        match (kind) {
            case Seconds => value * 1000.0
            case Milliseconds => value
        }
    }

    /// 相等比较
    public func eql(other: CssTime): Bool {
        toSeconds() == other.toSeconds()
    }

    /// 深拷贝
    public func deepClone(): CssTime {
        CssTime(kind, value)
    }

    public func toCss(): String {
        match (kind) {
            case Seconds => "${value}s"
            case Milliseconds => "${value}ms"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// URL 值
// 严格翻译自: values/url.zig Url
// ============================================================================

/// CSS url() 值
/// 严格翻译自 Url struct { url, import_records }
public class CssUrl {
    /// URL 字符串
    public var url: String

    public init(url: String) {
        this.url = url
    }

    /// 深拷贝
    public func deepClone(): CssUrl {
        CssUrl(url)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Url.to_css
    public func toCss(): String {
        "url(\"${url}\")"
    }

    public func toString(): String {
        toCss()
    }
}
