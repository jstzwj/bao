// bao_css - CSS Properties: Overflow
// 严格翻译自: bun/src/css/properties/overflow.rs
//   对应: overflow.zig - CSS 溢出属性
//   对应: Overflow, OverflowKeyword, TextOverflow
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// Overflow
// 严格翻译自 Overflow
// ============================================================================

/// overflow 属性值
/// 严格翻译自 Overflow
public class Overflow {
    public var x: OverflowKeyword  // X 方向溢出
    public var y: OverflowKeyword  // Y 方向溢出

    public init(x: OverflowKeyword, y: OverflowKeyword) {
        this.x = x
        this.y = y
    }

    public static func default(): Overflow {
        Overflow(x: OverflowKeyword.Visible, y: OverflowKeyword.Visible)
    }

    public func toCss(): String {
        if (y == x) {
            return x.toCss()
        }
        return x.toCss() + " " + y.toCss()
    }
}

// ============================================================================
// OverflowKeyword
// 严格翻译自 OverflowKeyword (DefineEnumProperty)
// ============================================================================

/// overflow-x/y 属性值关键字
/// 严格翻译自 OverflowKeyword
public enum OverflowKeyword {
    | Visible  // 可见
    | Hidden   // 隐藏
    | Clip     // 裁剪
    | Scroll   // 滚动
    | Auto     // 自动

    public func toCss(): String {
        match (this) {
            case Visible => "visible"
            case Hidden => "hidden"
            case Clip => "clip"
            case Scroll => "scroll"
            case Auto => "auto"
        }
    }
}

// ============================================================================
// TextOverflow
// 严格翻译自 TextOverflow (DefineEnumProperty)
// ============================================================================

/// text-overflow 属性值
/// 严格翻译自 TextOverflow
public enum TextOverflow {
    | Clip      // 裁剪
    | Ellipsis  // 省略号

    public func toCss(): String {
        match (this) {
            case Clip => "clip"
            case Ellipsis => "ellipsis"
        }
    }
}
