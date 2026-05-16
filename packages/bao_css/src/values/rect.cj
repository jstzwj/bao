// bao_css - CSS 四边矩形值
// 严格翻译自: bun/src/css/values/rect.rs
//   对应: values/rect.zig - Rect<T> { top, right, bottom, left }
package bao_css.values

import bao_core.*

// ============================================================================
// Rect<T> - 四边矩形
// 严格翻译自: values/rect.rs Rect<T> { top, right, bottom, left }
// ============================================================================

/// CSS 四边矩形值
/// 严格翻译自 Rect<T> struct { top: T, right: T, bottom: T, left: T }
/// 用于 margin, padding, border-width 等属性
public class CssRect {
    /// 顶部
    public var top: String
    /// 右侧
    public var right: String
    /// 底部
    public var bottom: String
    /// 左侧
    public var left: String

    public init(top: String, right: String, bottom: String, left: String) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    /// 所有边相同的矩形
    /// 严格翻译自 Rect::all
    public static func all(value: String): CssRect {
        CssRect(value, value, value, value)
    }

    /// 相等比较
    /// 严格翻译自 Rect::eql
    public func eql(other: CssRect): Bool {
        top == other.top && right == other.right &&
        bottom == other.bottom && left == other.left
    }

    /// 深拷贝
    /// 严格翻译自 Rect::deep_clone
    public func deepClone(): CssRect {
        CssRect(top, right, bottom, left)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Rect::to_css
    /// 当值重复时使用缩写 (如 "10px" 而非 "10px 10px 10px 10px")
    public func toCss(): String {
        let sameVertical = top == bottom
        let sameHorizontal = right == left

        if (sameVertical && sameHorizontal && top == right) {
            // 所有四边相同: "10px"
            return top
        }

        if (sameVertical && sameHorizontal) {
            // 上下相同, 左右相同: "10px 20px"
            return "${top} ${right}"
        }

        if (sameHorizontal) {
            // 左右相同: "10px 20px 30px"
            return "${top} ${right} ${bottom}"
        }

        // 四边都不同: "10px 20px 30px 40px"
        "${top} ${right} ${bottom} ${left}"
    }

    public func toString(): String {
        toCss()
    }
}
