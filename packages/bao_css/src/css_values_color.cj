// bao_css - CSS 颜色/字符串/Alpha 值类型
// 严格翻译自: bun/src/css/values/
//   对应: values/alpha.zig - AlphaValue (不透明度值)
//   对应: values/css_string.zig - CSSString (引号字符串)
//   对应: values/number.zig - CSSNumber, CSSInteger (数值基础类型)
//   对应: values/percentage.zig - Percentage, NumberOrPercentage (百分比)
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// Alpha 值
// 严格翻译自: values/alpha.zig AlphaValue
// ============================================================================

/// CSS <alpha-value>
/// 严格翻译自 AlphaValue struct { v: f32 }
/// 用于表示 opacity 等属性的不透明度值
/// 解析时接受 <number> 或 <percentage>，但总是存储和序列化为数字
public class CssAlphaValue {
    public var value: Float64

    public init(value: Float64) {
        this.value = value
    }

    /// 从百分比值创建
    /// 严格翻译自 AlphaValue.parse (percentage 分支)
    public static func fromPercentage(percent: Float64): CssAlphaValue {
        CssAlphaValue(percent)
    }

    /// 从数字创建
    public static func fromNumber(num: Float64): CssAlphaValue {
        CssAlphaValue(num)
    }

    /// 从 NumberOrPercentage 创建
    /// 严格翻译自 AlphaValue.parse
    public static func fromNumberOrPercentage(nop: CssNumberOrPercentage): CssAlphaValue {
        CssAlphaValue(nop.toFloat64())
    }

    /// 完全不透明
    public static func opaque(): CssAlphaValue {
        CssAlphaValue(1.0)
    }

    /// 完全透明
    public static func transparent(): CssAlphaValue {
        CssAlphaValue(0.0)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 AlphaValue.toCss (序列化为数字)
    public func toCss(): String {
        "${value}"
    }

    /// 相等比较
    /// 严格翻译自 AlphaValue.eql
    public func eql(other: CssAlphaValue): Bool {
        value == other.value
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// CSS 字符串
// 严格翻译自: values/css_string.zig CSSString
// ============================================================================

/// CSS 引号字符串
/// 严格翻译自 CSSString = []const u8
/// CSSStringFns { parse, toCss }
public class CssString {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    public init() {
        this.value = ""
    }

    /// 解析 CSS 引号字符串
    /// 严格翻译自 CSSStringFns.parse -> input.expectString()
    public static func parse(text: String): CssString {
        CssString(text)
    }

    /// 转为 CSS 文本 (序列化引号)
    /// 严格翻译自 CSSStringFns.toCss -> serializeString
    public func toCss(): String {
        // 简单实现：用双引号包裹，转义内部双引号
        let escaped = value.replace("\\", "\\\\").replace("\"", "\\\"")
        "\"${escaped}\""
    }

    /// 相等比较
    public func eql(other: CssString): Bool {
        value == other.value
    }

    public func toString(): String {
        value
    }

    /// 获取原始值 (不带引号)
    public func rawValue(): String {
        value
    }
}

// ============================================================================
// CSS 数值 (Number / Integer)
// 严格翻译自: values/number.zig CSSNumber, CSSInteger
// ============================================================================

/// CSS <number> 值
/// 严格翻译自 CSSNumber = f32
/// 提供 parse, toCss, sign 等方法
public class CssNumber {
    public var value: Float64

    public init(value: Float64) {
        this.value = value
    }

    /// 零值
    public static func zero(): CssNumber {
        CssNumber(0.0)
    }

    /// 符号
    /// 严格翻译自 CSSNumberFns.sign
    public func sign(): Float64 {
        if (value > 0.0) { 1.0 }
        else if (value < 0.0) { -1.0 }
        else { 0.0 }
    }

    /// 是否为负
    public func isSignNegative(): Bool {
        value < 0.0
    }

    /// 是否为正
    public func isSignPositive(): Bool {
        value >= 0.0
    }

    /// 转为 CSS 文本
    /// 严格翻译自 CSSNumberFns.toCss
    /// 小数绝对值 < 1.0 时移除前导零 (e.g. 0.5 -> .5)
    public func toCss(): String {
        if (value != 0.0 && Math.abs(value) < 1.0) {
            // 移除前导零: 0.5 -> .5, -0.5 -> -.5
            let s = "${value}"
            if (value < 0.0) {
                "-${s.substring(2)}"
            } else {
                s.substring(1)
            }
        } else {
            "${value}"
        }
    }

    public func toString(): String {
        toCss()
    }
}

/// CSS <integer> 值
/// 严格翻译自 CSSInteger = i32
public class CssInteger {
    public var value: Int64

    public init(value: Int64) {
        this.value = value
    }

    /// 零值
    public static func zero(): CssInteger {
        CssInteger(0)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 CSSIntegerFns.toCss
    public func toCss(): String {
        "${value}"
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 百分比值 (扩展版)
// 严格翻译自: values/percentage.zig Percentage, NumberOrPercentage
// ============================================================================

/// CSS 百分比值 (扩展版，含更多运算)
/// 严格翻译自 Percentage struct { v: CSSNumber }
/// 基础版在 css_values.cj 中为 CssPercentage
public class CssPercentageFull {
    public var value: Float64  // 0.0 ~ 1.0 范围 (即百分比/100)

    public init(value: Float64) {
        this.value = value
    }

    /// 零值
    /// 严格翻译自 Percentage.isZero
    public static func zero(): CssPercentageFull {
        CssPercentageFull(0.0)
    }

    /// 是否为零
    public func isZero(): Bool {
        value == 0.0
    }

    /// 符号
    /// 严格翻译自 Percentage.sign
    public func sign(): Float64 {
        if (value > 0.0) { 1.0 }
        else if (value < 0.0) { -1.0 }
        else { 0.0 }
    }

    /// 相加
    /// 严格翻译自 Percentage.add
    public func add(other: CssPercentageFull): CssPercentageFull {
        CssPercentageFull(value + other.value)
    }

    /// 乘以浮点数
    /// 严格翻译自 Percentage.mulF32
    public func mul(other: Float64): CssPercentageFull {
        CssPercentageFull(value * other)
    }

    /// 相等比较
    /// 严格翻译自 Percentage.eql
    public func eql(other: CssPercentageFull): Bool {
        value == other.value
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Percentage.toCss
    /// value=0.5 输出 50%
    public func toCss(): String {
        let percent = value * 100.0
        "${percent}%"
    }

    public func toString(): String {
        toCss()
    }
}

/// NumberOrPercentage - 数字或百分比
/// 严格翻译自 NumberOrPercentage union(enum) { number, percentage }
public class CssNumberOrPercentage {
    public var kind: CssNumberOrPercentageKind
    public var number: Float64
    public var percentage: Float64  // 0.0~1.0 范围

    public enum CssNumberOrPercentageKind {
        | Number
        | Percentage
    }

    public init(number: Float64) {
        this.kind = CssNumberOrPercentageKind.Number
        this.number = number
        this.percentage = 0.0
    }

    public init(percentage: Float64) {
        this.kind = CssNumberOrPercentageKind.Percentage
        this.number = 0.0
        this.percentage = percentage
    }

    /// 转为 f64 值 (数字直接取，百分比取 .v)
    /// 严格翻译自 NumberOrPercentage.intoF32
    public func toFloat64(): Float64 {
        match (kind) {
            case Number => number
            case Percentage => percentage
        }
    }

    /// 相等比较
    /// 严格翻译自 NumberOrPercentage.eql
    public func eql(other: CssNumberOrPercentage): Bool {
        if (kind != other.kind) { return false }
        match (kind) {
            case Number => number == other.number
            case Percentage => percentage == other.percentage
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Number => "${number}"
            case Percentage => "${percentage * 100.0}%"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 颜色后备类型
// 严格翻译自: values/color.zig ColorFallbackKind
// ============================================================================

/// 颜色后备类型
/// 严格翻译自 ColorFallbackKind packed struct { rgb, p3, lab }
/// 用于确定需要哪些颜色后备
public class CssColorFallbackKind {
    public var rgb: Bool
    public var p3: Bool
    public var lab: Bool

    public init() {
        this.rgb = false
        this.p3 = false
        this.lab = false
    }

    public static func none(): CssColorFallbackKind {
        CssColorFallbackKind()
    }

    public static func rgbOnly(): CssColorFallbackKind {
        let k = CssColorFallbackKind()
        k.rgb = true
        return k
    }

    /// 合并
    public func merge(other: CssColorFallbackKind): Unit {
        if (other.rgb) { rgb = true }
        if (other.p3) { p3 = true }
        if (other.lab) { lab = true }
    }

    /// 是否需要任何后备
    public func needsFallback(): Bool {
        rgb || p3 || lab
    }
}
