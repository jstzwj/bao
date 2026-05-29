// bao_css - CSS 选择器模块入口
// 严格翻译自: bun/src/css/selectors/mod.rs
//   对应: selectors/ - selector parsing, serialization, and builder
package bao_css.selectors

import bao_core.*
import bao_collections.*

// ============================================================================
// 重导出
// 严格翻译自: selectors/mod.rs pub use parser::{...}
// ============================================================================

// 从 parser 重新导出的类型
public type CssComponent = CssSelectorComponent
public type CssPseudoClass = CssSelectorPseudoClass
public type CssPseudoElement = CssSelectorPseudoElement
public type CssSelector = CssSelectorImpl
public type CssSelectorList = CssSelectorListImpl

// ============================================================================
// 选择器实现标记 (Selectors)
// 严格翻译自: selectors/mod.rs impl_::Selectors
// ============================================================================

/// 选择器实现类型标记
/// 严格翻译自 impl_::Selectors marker struct
public class CssSelectorsMarker {
    public init() {}
}

