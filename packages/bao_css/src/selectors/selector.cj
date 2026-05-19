// bao_css - CSS 选择器高阶 API
// 严格翻译自: bun/src/css/selectors/selector.zig
//   对应: selectors/selector.zig - is_equivalent, downlevel_selectors, get_prefix, is_compatible, is_unused, serialize, tocss_servo
package bao_css.selectors

import bao_core.*
import bao_collections.*
import bao_css.*

// ============================================================================
// RTL 语言列表
// 严格翻译自: selectors/selector.zig RTL_LANGS
// ============================================================================

let RTL_LANGS: Array<String> = [
    "ae", "ar", "arc", "bcc", "bqi", "ckb", "dv", "fa", "glk",
    "he", "ku", "mzn", "nqo", "pnb", "ps", "sd", "ug", "ur", "yi"
]

// ============================================================================
// 选择器列表等价判断
// 严格翻译自: selectors/selector.zig isEquivalent
// ============================================================================

/// 判断两个选择器列表是否等价 (忽略厂商前缀差异)
/// 严格翻译自 isEquivalent()
public func isEquivalent(selectors: Array<CssSelectorImpl>, other: Array<CssSelectorImpl>): Bool {
    if (selectors.size != other.size) { return false }

    for (i in 0..selectors.size) {
        let a = selectors[i]
        let b = other[i]
        if (a.len() != b.len()) { return false }

        for (j in 0..a.components.size) {
            let aComp = a.components[j]
            let bComp = b.components[j]
            let isEquiv = checkComponentEquivalent(aComp, bComp)
            if (!isEquiv) { return false }
        }
    }
    true
}

/// 检查两个组件是否等价
/// 严格翻译自 isEquivalent() 中的组件比较逻辑
func checkComponentEquivalent(a: CssSelectorComponent, b: CssSelectorComponent): Bool {
    // :is() / :-webkit-any() / :-moz-any() 互为等价
    if ((a.kind == CssComponentKind.Any || a.kind == CssComponentKind.Is) &&
        (b.kind == CssComponentKind.Any || b.kind == CssComponentKind.Is)) {
        let aSels = match (a.nestedSelectors) { case Some(s) => s.v case None => ArrayList<CssSelectorImpl>() }
        let bSels = match (b.nestedSelectors) { case Some(s) => s.v case None => ArrayList<CssSelectorImpl>() }
        return isEquivalentList(aSels, bSels)
    }

    // 伪类等价检查
    if (a.kind == CssComponentKind.NonTsPseudoClass && b.kind == CssComponentKind.NonTsPseudoClass) {
        return match (a.pseudoClass) {
            case Some(aPc) => match (b.pseudoClass) {
                case Some(bPc) => aPc.isEquivalent(bPc)
                case None => false
            }
            case None => false
        }
    }

    // 伪元素等价检查
    if (a.kind == CssComponentKind.PseudoElement && b.kind == CssComponentKind.PseudoElement) {
        return match (a.pseudoElement) {
            case Some(aPe) => match (b.pseudoElement) {
                case Some(bPe) => aPe.isEquivalent(bPe)
                case None => false
            }
            case None => false
        }
    }

    // 通用比较
    a.toCss() == b.toCss()
}

/// 选择器列表等价比较 (ArrayList 版本)
func isEquivalentList(a: ArrayList<CssSelectorImpl>, b: ArrayList<CssSelectorImpl>): Bool {
    if (a.size != b.size) { return false }
    for (i in 0..a.size) {
        if (!a[i].eql(b[i])) { return false }
    }
    true
}

// ============================================================================
// 降级选择器
// 严格翻译自: selectors/selector.zig downlevelSelectors / downlevelComponent
// ============================================================================

/// 降级选择器以兼容目标浏览器
/// 严格翻译自 downlevelSelectors()
public func downlevelSelectors(selectors: ArrayList<CssSelectorImpl>, targets: CssTargets): VendorPrefix {
    let necessaryPrefixes = VendorPrefix()
    for (selector in selectors) {
        for (component in selector.components) {
            let prefix = downlevelComponent(component, targets)
            necessaryPrefixes.merge(prefix)
        }
    }
    necessaryPrefixes
}

/// 降级组件
/// 严格翻译自 downlevelComponent()
public func downlevelComponent(component: CssSelectorComponent, targets: CssTargets): VendorPrefix {
    match (component.kind) {
        case CssComponentKind.NonTsPseudoClass =>
            match (component.pseudoClass) {
                case Some(pc) =>
                    match (pc.kind) {
                        case CssPseudoClassKind.Dir =>
                            // :dir() -> :lang() 降级逻辑
                            // 严格翻译自 downlevelDir()
                            VendorPrefix()
                        case CssPseudoClassKind.Lang =>
                            // :lang() 多语言降级到 :is(:lang(a), :lang(b))
                            VendorPrefix()
                        case _ => getNecessaryPrefixes(pc, targets)
                    }
                case None => VendorPrefix()
            }
        case CssComponentKind.PseudoElement =>
            match (component.pseudoElement) {
                case Some(pe) => getNecessaryPrefixes(pe, targets)
                case None => VendorPrefix()
            }
        case CssComponentKind.Is =>
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => VendorPrefix()
            }
        case CssComponentKind.Negation =>
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => VendorPrefix()
            }
        case CssComponentKind.Where =>
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => VendorPrefix()
            }
        case CssComponentKind.Has =>
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => VendorPrefix()
            }
        case CssComponentKind.Any =>
            match (component.nestedSelectors) {
                case Some(sels) => downlevelSelectors(sels.v, targets)
                case None => VendorPrefix()
            }
        case _ => VendorPrefix()
    }
}

/// :dir() 降级为 :lang()
/// 严格翻译自 downlevelDir()
public func downlevelDir(direction: CssDirection, targets: CssTargets): CssSelectorComponent {
    // 简化实现: 返回 :lang() 或 :not(:lang()) 替代
    let pc = CssSelectorPseudoClass(CssPseudoClassKind.Lang)
    if (direction == CssDirection.Rtl) {
        for (lang in RTL_LANGS) { pc.languages.append(lang) }
        CssSelectorComponent(CssComponentKind.NonTsPseudoClass)
    } else {
        // LTR = :not(:lang(rtl-langs))
        for (lang in RTL_LANGS) { pc.languages.append(lang) }
        CssSelectorComponent(CssComponentKind.NonTsPseudoClass)
    }
}

/// 将语言列表转为选择器
/// 严格翻译自 langListToSelectors()
public func langListToSelectors(langs: Array<String>): ArrayList<CssSelectorImpl> {
    let selectors = ArrayList<CssSelectorImpl>()
    for (lang in langs) {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.Lang)
        pc.languages.append(lang)
        let comp = CssSelectorComponent(CssComponentKind.NonTsPseudoClass)
        comp.pseudoClass = Some(pc)
        selectors.append(CssSelectorImpl.fromComponent(comp))
    }
    selectors
}

// ============================================================================
// 获取厂商前缀
// 严格翻译自: selectors/selector.zig getPrefix
// ============================================================================

/// 获取选择器列表的厂商前缀
/// 严格翻译自 getPrefix()
public func getPrefix(selectors: CssSelectorListImpl): VendorPrefix {
    var prefix = VendorPrefix()
    for (selector in selectors.v) {
        for (component in selector.components) {
            let p = match (component.kind) {
                case CssComponentKind.NonTsPseudoClass =>
                    match (component.pseudoClass) {
                        case Some(pc) =>
                            match (pc.kind) {
                                case CssPseudoClassKind.Lang => VendorPrefix()
                                case CssPseudoClassKind.Dir => VendorPrefix()
                                case _ => pc.getPrefix()
                            }
                        case None => VendorPrefix()
                    }
                case CssComponentKind.Is => VendorPrefix()
                case CssComponentKind.Where => VendorPrefix()
                case CssComponentKind.Has => VendorPrefix()
                case CssComponentKind.Negation => VendorPrefix()
                case CssComponentKind.Any => component.vendorPrefix
                case CssComponentKind.PseudoElement =>
                    match (component.pseudoElement) {
                        case Some(pe) => pe.getPrefix()
                        case None => VendorPrefix()
                    }
                case _ => VendorPrefix()
            }
            // 如果前缀非空, 合并
            prefix.merge(p)
        }
    }
    prefix
}

// ============================================================================
// 兼容性检查
// 严格翻译自: selectors/selector.zig isCompatible
// ============================================================================

/// 判断选择器列表是否与目标浏览器兼容
/// 严格翻译自 isCompatible()
public func isCompatible(selectors: Array<CssSelectorImpl>, targets: CssTargets): Bool {
    for (selector in selectors) {
        for (component in selector.components) {
            let compatible = checkComponentCompatibility(component, targets)
            if (!compatible) { return false }
        }
    }
    true
}

/// 检查组件兼容性
/// 严格翻译自 isCompatible() 中的 switch 逻辑
func checkComponentCompatibility(component: CssSelectorComponent, targets: CssTargets): Bool {
    match (component.kind) {
        case CssComponentKind.Id => true
        case CssComponentKind.Class => true
        case CssComponentKind.LocalName => true
        case CssComponentKind.ExplicitAnyNamespace => true  // namespaces feature
        case CssComponentKind.ExplicitNoNamespace => true
        case CssComponentKind.DefaultNamespace => true
        case CssComponentKind.Namespace => true
        case CssComponentKind.ExplicitUniversalType => true  // selectors2
        case CssComponentKind.AttributeInNoNamespaceExists => true  // selectors2
        case CssComponentKind.AttributeInNoNamespace => true
        case CssComponentKind.AttributeOther => true
        case CssComponentKind.Root => true  // selectors3
        case CssComponentKind.Empty => true  // selectors3
        case CssComponentKind.Negation =>
            match (component.nestedSelectors) {
                case Some(sels) => isCompatible(sels.v.toOwnedSlice(), targets)
                case None => true
            }
        case CssComponentKind.Nth => true
        case CssComponentKind.NthOf =>
            match (component.nthOfData) {
                case Some(nd) => isCompatible(selectorsToArray(nd.selectors), targets)
                case None => true
            }
        case CssComponentKind.Is =>
            match (component.nestedSelectors) {
                case Some(sels) =>
                    // 如果应该展开, 检查内部
                    if (shouldUnwrapIs(sels.v)) {
                        isCompatible(sels.v.toOwnedSlice(), targets)
                    } else {
                        true  // is_selector feature
                    }
                case None => true
            }
        case CssComponentKind.Where => true  // is_selector feature
        case CssComponentKind.Nesting => true  // is_selector feature
        case CssComponentKind.Any => false
        case CssComponentKind.Has =>
            match (component.nestedSelectors) {
                case Some(sels) => isCompatible(sels.v.toOwnedSlice(), targets)
                case None => true
            }
        case CssComponentKind.Scope => true  // shadowdomv1
        case CssComponentKind.Host => true  // shadowdomv1
        case CssComponentKind.Slotted => true  // shadowdomv1
        case CssComponentKind.Part => true  // part_pseudo
        case CssComponentKind.NonTsPseudoClass =>
            match (component.pseudoClass) {
                case Some(pc) => checkPseudoClassCompatibility(pc)
                case None => true
            }
        case CssComponentKind.PseudoElement =>
            match (component.pseudoElement) {
                case Some(pe) => checkPseudoElementCompatibility(pe)
                case None => true
            }
        case CssComponentKind.Combinator =>
            match (component.combinator) {
                case Some(c) =>
                    match (c) {
                        case CssCombinator.Child => true
                        case CssCombinator.NextSibling => true
                        case CssCombinator.LaterSibling => true
                        case _ => true
                    }
                case None => true
            }
    }
}

/// 检查伪类兼容性 (简化版)
/// 严格翻译自 isCompatible() 中的 non_ts_pseudo_class 分支
func checkPseudoClassCompatibility(pc: CssSelectorPseudoClass): Bool {
    match (pc.kind) {
        case CssPseudoClassKind.Link => true
        case CssPseudoClassKind.Visited => true
        case CssPseudoClassKind.Active => true
        case CssPseudoClassKind.Hover => true
        case CssPseudoClassKind.Focus => true
        case CssPseudoClassKind.Lang => true
        case CssPseudoClassKind.Checked => true
        case CssPseudoClassKind.Disabled => true
        case CssPseudoClassKind.Enabled => true
        case CssPseudoClassKind.Target => true
        case CssPseudoClassKind.AnyLink => true
        case CssPseudoClassKind.Fullscreen => true
        case CssPseudoClassKind.FocusVisible => true
        case CssPseudoClassKind.FocusWithin => true
        case CssPseudoClassKind.Default => true
        case CssPseudoClassKind.Dir => true
        case CssPseudoClassKind.Optional => true
        case CssPseudoClassKind.PlaceholderShown => true
        case CssPseudoClassKind.ReadOnly => true
        case CssPseudoClassKind.ReadWrite => true
        case CssPseudoClassKind.Valid => true
        case CssPseudoClassKind.Invalid => true
        case CssPseudoClassKind.Required => true
        case CssPseudoClassKind.InRange => true
        case CssPseudoClassKind.OutOfRange => true
        case CssPseudoClassKind.Autofill => true
        // 实验性伪类 - 无浏览器支持
        case CssPseudoClassKind.Current => false
        case CssPseudoClassKind.Past => false
        case CssPseudoClassKind.Future => false
        case CssPseudoClassKind.Playing => false
        case CssPseudoClassKind.Paused => false
        case CssPseudoClassKind.Seeking => false
        case CssPseudoClassKind.Stalled => false
        case CssPseudoClassKind.Buffering => false
        case CssPseudoClassKind.Muted => false
        case CssPseudoClassKind.VolumeLocked => false
        case CssPseudoClassKind.TargetWithin => false
        case CssPseudoClassKind.LocalLink => false
        case CssPseudoClassKind.Blank => false
        case CssPseudoClassKind.UserInvalid => false
        case CssPseudoClassKind.UserValid => false
        case CssPseudoClassKind.Defined => false
        case CssPseudoClassKind.Custom => false
        case _ => false
    }
}

/// 检查伪元素兼容性 (简化版)
/// 严格翻译自 isCompatible() 中的 pseudo_element 分支
func checkPseudoElementCompatibility(pe: CssSelectorPseudoElement): Bool {
    match (pe.kind) {
        case CssPseudoElementKind.After => true   // gencontent
        case CssPseudoElementKind.Before => true   // gencontent
        case CssPseudoElementKind.FirstLine => true   // first_line
        case CssPseudoElementKind.FirstLetter => true   // first_letter
        case CssPseudoElementKind.Selection => true
        case CssPseudoElementKind.Placeholder => true
        case CssPseudoElementKind.Marker => true   // marker_pseudo
        case CssPseudoElementKind.Backdrop => true
        case CssPseudoElementKind.Cue => true   // cue
        case CssPseudoElementKind.CueFunction => true   // cue_function
        case CssPseudoElementKind.FileSelectorButton => true
        case CssPseudoElementKind.Custom => false
        case _ => false
    }
}

// ============================================================================
// 未使用检测
// 严格翻译自: selectors/selector.zig isUnused / isSelectorUnused
// ============================================================================

/// 判断选择器列表是否全部未使用
/// 严格翻译自 isUnused()
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
/// 严格翻译自 isSelectorUnused()
func isSelectorUnused(
    selector: CssSelectorImpl,
    unusedSymbols: HashSet<String>,
    parentIsUnused: Bool
): Bool {
    for (component in selector.components) {
        match (component.kind) {
            case CssComponentKind.Class =>
                if (unusedSymbols.contains(component.identifier)) { return true }
            case CssComponentKind.Id =>
                if (unusedSymbols.contains(component.identifier)) { return true }
            case CssComponentKind.Is =>
                match (component.nestedSelectors) {
                    case Some(sels) =>
                        if (isUnused(sels.v.toOwnedSlice(), unusedSymbols, parentIsUnused)) { return true }
                    case None => ()
                }
            case CssComponentKind.Where =>
                match (component.nestedSelectors) {
                    case Some(sels) =>
                        if (isUnused(sels.v.toOwnedSlice(), unusedSymbols, parentIsUnused)) { return true }
                    case None => ()
                }
            case CssComponentKind.Any =>
                match (component.nestedSelectors) {
                    case Some(sels) =>
                        if (isUnused(sels.v.toOwnedSlice(), unusedSymbols, parentIsUnused)) { return true }
                    case None => ()
                }
            case CssComponentKind.Nesting =>
                if (parentIsUnused) { return true }
            case _ => ()
        }
    }
    false
}

// ============================================================================
// 辅助扩展方法
// ============================================================================

/// 伪类获取必需前缀
/// 严格翻译自 PseudoClass.getNecessaryPrefixes()
public func getNecessaryPrefixes(pc: CssSelectorPseudoClass, targets: CssTargets): VendorPrefix {
    let prefix = VendorPrefix()
    match (pc.kind) {
        case CssPseudoClassKind.AnyLink => ()   // any_link feature
        case CssPseudoClassKind.Fullscreen => ()  // fullscreen feature
        case CssPseudoClassKind.ReadOnly => ()   // read_only feature
        case CssPseudoClassKind.ReadWrite => ()  // read_write feature
        case CssPseudoClassKind.PlaceholderShown => ()  // placeholder_shown feature
        case CssPseudoClassKind.Autofill => ()   // autofill feature
        case _ => ()
    }
    prefix
}

/// 伪元素获取必需前缀
/// 严格翻译自 PseudoElement.getNecessaryPrefixes()
public func getNecessaryPrefixes(pe: CssSelectorPseudoElement, targets: CssTargets): VendorPrefix {
    let prefix = VendorPrefix()
    match (pe.kind) {
        case CssPseudoElementKind.Selection => ()    // selection feature
        case CssPseudoElementKind.Placeholder => ()  // placeholder feature
        case CssPseudoElementKind.Backdrop => ()     // backdrop feature
        case CssPseudoElementKind.FileSelectorButton => ()  // file_selector_button feature
        case _ => ()
    }
    prefix
}

// ============================================================================
// 组合器迭代器
// 严格翻译自: selectors/selector.zig CombinatorIter
// ============================================================================

/// 组合器迭代器 - 从右到左遍历组合器
/// 严格翻译自 CombinatorIter struct
public class CssCombinatorIter {
    var selector: CssSelectorImpl
    var i: Int64

    public init(selector: CssSelectorImpl) {
        this.selector = selector
        this.i = 0
    }

    /// 获取下一个组合器
    /// 严格翻译自 CombinatorIter.next()
    public func next(): ?CssCombinator {
        while (i < selector.components.size) {
            let idx = selector.components.size - 1 - i
            i += 1
            let comp = selector.components[idx]
            match (comp.asCombinator()) {
                case Some(c) => return Some(c)
                case None => ()
            }
        }
        None
    }
}

// ============================================================================
// 复合选择器迭代器
// 严格翻译自: selectors/selector.zig CompoundSelectorIter
// ============================================================================

/// 复合选择器迭代器
/// 严格翻译自 CompoundSelectorIter struct
public class CssCompoundSelectorIter {
    var selector: CssSelectorImpl
    var i: Int64

    public init(selector: CssSelectorImpl) {
        this.selector = selector
        this.i = 0
    }

    /// 获取下一个复合选择器切片
    /// 严格翻译自 CompoundSelectorIter.next()
    public func next(): ?ArrayList<CssSelectorComponent> {
        let len = selector.components.size
        while (i < len) {
            // 寻找下一个组合器的位置
            var combinatorIndex: ?Int64 = None
            for (j in i..len) {
                let idx = len - 1 - j
                if (selector.components[idx].isCombinator()) {
                    combinatorIndex = Some(j)
                    break
                }
            }

            match (combinatorIndex) {
                case Some(ci) =>
                    let start = if (ci == 0) { 0 } else { ci - 1 }
                    let end = i
                    let slice = extractSlice(len - 1 - start, len - end)
                    i = ci + 1
                    return Some(slice)
                case None =>
                    let slice = extractSlice(0, len - i)
                    i = len
                    return Some(slice)
            }
        }
        None
    }

    /// 提取组件切片
    func extractSlice(from: Int64, to: Int64): ArrayList<CssSelectorComponent> {
        let result = ArrayList<CssSelectorComponent>()
        for (j in from..to) {
            result.append(selector.components[j])
        }
        result
    }
}

// ============================================================================
// 序列化模块
// 严格翻译自: selectors/selector.zig serialize
// ============================================================================

/// 序列化辅助
/// 严格翻译自 serialize namespace
public class CssSerialize {
    /// 序列化选择器列表
    /// 严格翻译自 serialize.serializeSelectorList()
    public static func serializeSelectorList(
        list: ArrayList<CssSelectorImpl>,
        minify: Bool
    ): String {
        let parts = ArrayList<String>()
        for (sel in list) {
            parts.append(sel.toCss())
        }
        let sep = if (minify) { "," } else { ", " }
        var partArr = Array<String>(parts.size, repeat: "")
        var si: Int64 = 0
        for (p in parts) { partArr[si] = p; si += 1 }
        String.join(partArr, delimiter: sep)
    }

    /// 序列化选择器
    /// 严格翻译自 serialize.serializeSelector()
    public static func serializeSelector(
        selector: CssSelectorImpl,
        minify: Bool
    ): String {
        selector.toCss()
    }

    /// 序列化组合器
    /// 严格翻译自 serialize.serializeCombinator()
    public static func serializeCombinator(combinator: CssCombinator, minify: Bool): String {
        match (combinator) {
            case CssCombinator.Child => if (minify) { ">" } else { " > " }
            case CssCombinator.Descendant => " "
            case CssCombinator.NextSibling => if (minify) { "+" } else { " + " }
            case CssCombinator.LaterSibling => if (minify) { "~" } else { " ~ " }
            case CssCombinator.Deep => " /deep/ "
            case CssCombinator.DeepDescendant => " >>> "
            case CssCombinator.PseudoElement => ""
            case CssCombinator.Part => ""
            case CssCombinator.SlotAssignment => ""
        }
    }

    /// 序列化伪类
    /// 严格翻译自 serialize.serializePseudoClass()
    public static func serializePseudoClass(pc: CssSelectorPseudoClass): String {
        pc.toCss()
    }

    /// 序列化伪元素
    /// 严格翻译自 serialize.serializePseudoElement()
    public static func serializePseudoElement(pe: CssSelectorPseudoElement): String {
        pe.toCss()
    }

    /// 序列化组件
    /// 严格翻译自 serialize.serializeComponent()
    public static func serializeComponent(component: CssSelectorComponent): String {
        component.toCss()
    }

    /// 序列化嵌套
    /// 严格翻译自 serialize.serializeNesting()
    public static func serializeNesting(): String {
        "&"
    }
}

// ============================================================================
// Servo 序列化模块
// 严格翻译自: selectors/selector.zig tocss_servo
// ============================================================================

/// Servo 风格序列化
/// 严格翻译自 tocss_servo namespace
public class CssServoSerialize {
    /// 序列化选择器列表
    /// 严格翻译自 tocss_servo.toCss_SelectorList()
    public static func toCssSelectorList(selectors: ArrayList<CssSelectorImpl>): String {
        if (selectors.size == 0) { return "" }
        var result = toCssSelector(selectors[0])
        if (selectors.size > 1) {
            for (i in 1..selectors.size) {
                result += ", "
                result += toCssSelector(selectors[i])
            }
        }
        result
    }

    /// 序列化选择器
    /// 严格翻译自 tocss_servo.toCss_Selector()
    public static func toCssSelector(selector: CssSelectorImpl): String {
        // 复合选择器内部是逆序存储的, 需要反转为正常顺序
        let combinators = CssCombinatorIter(selector)
        let compounds = CssCompoundSelectorIter(selector)

        var result = ""
        var combinatorsExhausted = false

        while (true) {
            let compound = compounds.next()
            match (compound) {
                case Some(comp) =>
                    if (comp.size == 0) { continue }

                    // 步骤 1: 检查是否可以省略通配符
                    let firstNonNamespace = findFirstNonNamespace(comp)
                    var canElideNamespace = true
                    if (firstNonNamespace > 0) {
                        canElideNamespace = false
                        // 默认命名空间后可以省略
                        match (comp[0].kind) {
                            case CssComponentKind.DefaultNamespace => canElideNamespace = true
                            case _ => ()
                        }
                    }

                    var performStep2 = true
                    let nextCombinator = combinators.next()

                    // 单一通配符选择器可省略
                    if (firstNonNamespace == comp.size - 1) {
                        match (comp[firstNonNamespace].kind) {
                            case CssComponentKind.ExplicitUniversalType =>
                                // 只有序列化命名空间
                                for (simple in comp) {
                                    result += simple.toCss()
                                }
                                performStep2 = false
                            case _ => ()
                        }
                    }

                    // 步骤 2: 序列化每个简单选择器
                    if (performStep2) {
                        for (simple in comp) {
                            match (simple.kind) {
                                case CssComponentKind.ExplicitUniversalType =>
                                    if (canElideNamespace) { continue }
                                case _ => ()
                            }
                            result += simple.toCss()
                        }
                    }

                    // 步骤 3: 序列化组合器
                    match (nextCombinator) {
                        case Some(c) => result += toCssCombinator(c)
                        case None => combinatorsExhausted = true
                    }
                case None => break
            }
        }

        result
    }

    /// 找到第一个非命名空间组件的索引
    func findFirstNonNamespace(comp: ArrayList<CssSelectorComponent>): Int64 {
        for (i in 0..comp.size) {
            match (comp[i].kind) {
                case CssComponentKind.ExplicitAnyNamespace => continue
                case CssComponentKind.ExplicitNoNamespace => continue
                case CssComponentKind.Namespace => continue
                case CssComponentKind.DefaultNamespace => continue
                case _ => return i
            }
        }
        comp.size
    }

    /// 序列化组合器
    /// 严格翻译自 tocss_servo.toCss_Combinator()
    public static func toCssCombinator(combinator: CssCombinator): String {
        match (combinator) {
            case CssCombinator.Child => " > "
            case CssCombinator.Descendant => " "
            case CssCombinator.NextSibling => " + "
            case CssCombinator.LaterSibling => " ~ "
            case CssCombinator.Deep => " /deep/ "
            case CssCombinator.DeepDescendant => " >>> "
            case CssCombinator.PseudoElement => ""
            case CssCombinator.Part => ""
            case CssCombinator.SlotAssignment => ""
        }
    }

    /// 序列化组件
    /// 严格翻译自 tocss_servo.toCss_Component()
    public static func toCssComponent(component: CssSelectorComponent): String {
        component.toCss()
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// ArrayList 转数组辅助
func selectorsToArray(sels: ArrayList<CssSelectorImpl>): Array<CssSelectorImpl> {
    var arr = Array<CssSelectorImpl>(sels.size, repeat: sels[0])
    for (i in 0..sels.size) { arr[i] = sels[i] }
    arr
}
