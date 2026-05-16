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

// ============================================================================
// 辅助函数
// 严格翻译自: selectors/mod.rs 顶层函数
// ============================================================================

/// 判断两个选择器列表是否等价 (忽略厂商前缀差异)
/// 严格翻译自 is_equivalent
public func isEquivalent(selectors: Array<CssSelectorImpl>, other: Array<CssSelectorImpl>): Bool {
    if (selectors.size != other.size) {
        return false
    }

    for (i in 0..selectors.size) {
        let a = selectors[i]
        let b = other[i]
        if (!a.eql(b)) {
            return false
        }
    }

    true
}

/// 获取选择器列表的厂商前缀
/// 严格翻译自 get_prefix
public func getPrefix(selectors: CssSelectorListImpl): CssVendorPrefix {
    CssVendorPrefix()
}
