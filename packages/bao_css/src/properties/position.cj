// bao_css - CSS Properties: Position
// 严格翻译自: bun/src/css/properties/position.rs
//   对应: position.zig - CSS 定位属性
//   对应: Position (5 variants, with vendor prefix for sticky)
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// Position
// 严格翻译自 Position
// ============================================================================

/// position 属性值
/// 严格翻译自 Position
public enum Position {
    | Static               // 静态定位
    | Relative             // 相对定位
    | Absolute             // 绝对定位
    | Sticky(String)       // 粘滞定位（带供应商前缀）
    | Fixed                // 固定定位

    public func toCss(): String {
        match (this) {
            case Static => "static"
            case Relative => "relative"
            case Absolute => "absolute"
            case Fixed => "fixed"
            case Sticky(prefix) => {
                if (prefix == "") {
                    "sticky"
                } else {
                    prefix + "sticky"
                }
            }
        }
    }
}
