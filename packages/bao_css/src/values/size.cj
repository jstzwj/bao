// bao_css - CSS 二维尺寸值
// 严格翻译自: bun/src/css/values/size.rs
//   对应: values/size.zig - Size2D<T> { a, b }
package bao_css.values

import bao_core.*

// ============================================================================
// Size2D<T> - 二维尺寸
// 严格翻译自: values/size.rs Size2D<T> { a: T, b: T }
// ============================================================================

/// CSS 二维尺寸值
/// 严格翻译自 Size2D<T> struct { a: T, b: T }
/// 用于 border-radius 等属性, 当两值相等时只序列化一个
public class CssSize2D {
    /// 第一个分量 (水平)
    public var a: String
    /// 第二个分量 (垂直)
    public var b: String

    public init(a: String, b: String) {
        this.a = a
        this.b = b
    }

    /// 相等比较
    /// 严格翻译自 Size2D::eql (注意: 比较 lhs.a vs rhs.b, 如源码注释所说是可能的 bug)
    public func eql(other: CssSize2D): Bool {
        a == other.b
    }

    /// 深拷贝
    /// 严格翻译自 Size2D::deep_clone
    public func deepClone(): CssSize2D {
        CssSize2D(a, b)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Size2D::to_css
    /// 当两个值相同时只输出一个
    public func toCss(): String {
        if (a == b) {
            a
        } else {
            "${a} ${b}"
        }
    }

    public func toString(): String {
        toCss()
    }
}
