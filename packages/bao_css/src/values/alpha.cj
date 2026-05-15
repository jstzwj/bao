// bao_css - CSS Alpha 值类型
// 严格翻译自: bun/src/css/values/alpha.rs
//   对应: values/alpha.zig - AlphaValue
package bao_css.values

import bao_core.*

// ============================================================================
// Alpha 值
// 严格翻译自: values/alpha.rs AlphaValue struct { v: f32 }
// ============================================================================

/// CSS <alpha-value>
/// 严格翻译自 AlphaValue struct { v: f32 }
/// 用于表示 opacity 等属性的不透明度值
/// 解析时接受 <number> 或 <percentage>，但总是存储和序列化为数字
public class CssAlphaValueFull {
    public var v: Float64

    public init(v: Float64) {
        this.v = v
    }

    /// 深拷贝
    /// 严格翻译自 AlphaValue.deep_clone — Copy
    public func deepClone(): CssAlphaValueFull {
        CssAlphaValueFull(v)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 AlphaValue.to_css
    public func toCss(): String {
        "${v}"
    }

    /// 相等比较
    /// 严格翻译自 AlphaValue.eql
    public func eql(other: CssAlphaValueFull): Bool {
        v == other.v
    }

    public func toString(): String {
        toCss()
    }
}
