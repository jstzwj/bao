// bao_css - CSS Properties: Shape
// 严格翻译自: bun/src/css/properties/shape.rs
//   对应: shape.zig - CSS 形状属性
//   对应: FillRule, AlphaValue
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// FillRule
// 严格翻译自 FillRule (占位)
// ============================================================================

/// fill-rule 属性值（占位）
/// Zig 源码为 DefineEnumProperty(@compileError(...)) 占位
/// 严格翻译自 FillRule
public enum FillRule {
}

// ============================================================================
// AlphaValue
// 严格翻译自 AlphaValue
// ============================================================================

/// alpha-value 属性值
/// 严格翻译自 AlphaValue
public class AlphaValue {
    public var v: Float32  // alpha 值 (0.0 ~ 1.0)

    public init() {
        this.v = 1.0
    }

    public init(v: Float32) {
        this.v = v
    }
}
