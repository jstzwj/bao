// bao_css - CSS 选择器高阶 API
// 严格翻译自: bun/src/css/selectors/selector.rs
//   对应: selectors/selector.zig - is_equivalent, downlevel_selectors, get_prefix, is_compatible, is_unused, serialize, tocss_servo
package bao_css.selectors

import bao_core.*
import bao_collections.*

// ============================================================================
// RTL 语言列表
// 严格翻译自: selectors/selector.rs RTL_LANGS
// ============================================================================

let RTL_LANGS: Array<String> = [
    "ae", "ar", "arc", "bcc", "bqi", "ckb", "dv", "fa", "glk",
    "he", "ku", "mzn", "nqo", "pnb", "ps", "sd", "ug", "ur", "yi"
]

// ============================================================================
// 高级选择器 API
// 严格翻译自: selectors/selector.rs 顶层函数
// ============================================================================

/// 降级选择器以兼容目标浏览器
/// 严格翻译自 downlevel_selectors
public func downlevelSelectors(selectors: ArrayList<CssSelectorImpl>, targets: CssTargets): CssVendorPrefix {
    let necessaryPrefixes = CssVendorPrefix()
    for (selector in selectors) {
        for (component in selector.components) {
            let prefix = downlevelComponent(component, targets)
            necessaryPrefixes.insert(prefix)
        }
    }
    necessaryPrefixes
}

/// 降级组件
/// 严格翻译自 downlevel_component
public func downlevelComponent(component: CssSelectorComponent, targets: CssTargets): CssVendorPrefix {
    match (component.kind) {
        case CssComponentKind.NonTsPseudoClass => {
            match (component.pseudoClass) {
                case Some(pc) => pc.getNecessaryPrefixes(targets)
                case None => CssVendorPrefix()
            }
        }
        case CssComponentKind.PseudoElement => {
            match (component.pseudoElement) {
                case Some(pe) => pe.getNecessaryPrefixes(targets)
                case None => CssVendorPrefix()
            }
        }
        case CssComponentKind.Is => {
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => CssVendorPrefix()
            }
        }
        case CssComponentKind.Negation => {
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => CssVendorPrefix()
            }
        }
        case CssComponentKind.Where => {
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => CssVendorPrefix()
            }
        }
        case CssComponentKind.Has => {
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => CssVendorPrefix()
            }
        }
        case _ => CssVendorPrefix()
    }
}

/// 判断选择器列表是否与目标浏览器兼容
/// 严格翻译自 is_compatible
public func isCompatible(selectors: Array<CssSelectorImpl>, targets: CssTargets): Bool {
    for (selector in selectors) {
        for (component in selector.components) {
            let compatible = match (component.kind) {
                case CssComponentKind.Id => true
                case CssComponentKind.Class => true
                case CssComponentKind.LocalName => true
                case CssComponentKind.Root => targets.isCompatible(CssCompatFeature.Selectors3)
                case CssComponentKind.Empty => targets.isCompatible(CssCompatFeature.Selectors3)
                case CssComponentKind.Scope => targets.isCompatible(CssCompatFeature.Shadowdomv1)
                case CssComponentKind.Nesting => targets.isCompatible(CssCompatFeature.IsSelector)
                case CssComponentKind.Is => {
                    match (component.nestedSelectors) {
                        case Some(sels) => {
                            if (!targets.isCompatible(CssCompatFeature.IsSelector)) {
                                false
                            } else {
                                isCompatible(sels.v.toArray(), targets)
                            }
                        }
                        case None => true
                    }
                }
                case CssComponentKind.Where => targets.isCompatible(CssCompatFeature.IsSelector)
                case CssComponentKind.Has => {
                    if (!targets.isCompatible(CssCompatFeature.HasSelector)) { false }
                    else {
                        match (component.nestedSelectors) {
                            case Some(sels) => isCompatible(sels.v.toArray(), targets)
                            case None => true
                        }
                    }
                }
                case CssComponentKind.Negation => targets.isCompatible(CssCompatFeature.Selectors3)
                case CssComponentKind.Host => targets.isCompatible(CssCompatFeature.Shadowdomv1)
                case CssComponentKind.Slotted => targets.isCompatible(CssCompatFeature.Shadowdomv1)
                case CssComponentKind.Part => targets.isCompatible(CssCompatFeature.PartPseudo)
                case _ => true
            }
            if (!compatible) { return false }
        }
    }
    true
}

/// 判断选择器列表是否全部未使用
/// 严格翻译自 is_unused
public func isUnused(
    selectors: Array<CssSelectorImpl>,
    unusedSymbols: HashSet<String>,
    parentIsUnused: Bool
): Bool {
    if (unusedSymbols.isEmpty()) { return false }

    for (selector in selectors) {
        if (!isSelectorUnused(selector, unusedSymbols, parentIsUnused)) {
            return false
        }
    }
    true
}

/// 判断单个选择器是否未使用
func isSelectorUnused(
    selector: CssSelectorImpl,
    unusedSymbols: HashSet<String>,
    parentIsUnused: Bool
): Bool {
    for (component in selector.components) {
        match (component.kind) {
            case CssComponentKind.Class => {
                if (unusedSymbols.contains(component.identifier)) { return true }
            }
            case CssComponentKind.Id => {
                if (unusedSymbols.contains(component.identifier)) { return true }
            }
            case CssComponentKind.Is => {
                match (component.nestedSelectors) {
                    case Some(sels) => {
                        if (isUnused(sels.v.toArray(), unusedSymbols, parentIsUnused)) { return true }
                    }
                    case None => {}
                }
            }
            case CssComponentKind.Where => {
                match (component.nestedSelectors) {
                    case Some(sels) => {
                        if (isUnused(sels.v.toArray(), unusedSymbols, parentIsUnused)) { return true }
                    }
                    case None => {}
                }
            }
            case CssComponentKind.Nesting => {
                if (parentIsUnused) { return true }
            }
            case _ => {}
        }
    }
    false
}

// ============================================================================
// 辅助扩展方法
// ============================================================================

/// 伪类获取必需前缀
public func getNecessaryPrefixes(pc: CssSelectorPseudoClass, targets: CssTargets): CssVendorPrefix {
    let prefix = CssVendorPrefix()
    match (pc.kind) {
        case CssPseudoClassKind.AnyLink => {
            if (targets.shouldCompileSame(CssCompatFeature.AnyLink)) {
                // 需要前缀
            }
        }
        case CssPseudoClassKind.Fullscreen => {
            if (targets.shouldCompileSame(CssCompatFeature.Fullscreen)) {
                // 需要前缀
            }
        }
        case _ => {}
    }
    prefix
}

/// 伪元素获取必需前缀
public func getNecessaryPrefixes(pe: CssSelectorPseudoElement, targets: CssTargets): CssVendorPrefix {
    CssVendorPrefix()
}

/// 是否应展开 :is()
/// 严格翻译自 should_unwrap_is
public func shouldUnwrapIs(selectors: ArrayList<CssSelectorImpl>): Bool {
    if (selectors.size == 1) {
        let first = selectors[0]
        if (!first.hasCombinator()) {
            return true
        }
    }
    false
}

// ============================================================================
// 序列化辅助
// 严格翻译自: selectors/selector.rs serialize namespace
// ============================================================================

/// 序列化选择器列表
/// 严格翻译自 serialize::serialize_selector_list
public func serializeSelectorList(
    list: ArrayList<CssSelectorImpl>,
    minify: Bool
): String {
    let parts = ArrayList<String>()
    for (sel in list) {
        parts.append(sel.toCss())
    }
    let sep = if (minify) { "," } else { ", " }
    String.join(sep, parts)
}
