// bao_css - CSS 选择器解析器
// 严格翻译自: bun/src/css/selectors/parser.rs
//   对应: selectors/parser.zig - Component, Selector, SelectorList, Combinator, PseudoClass, PseudoElement
package bao_css.selectors

import bao_core.*
import bao_collections.*

// ============================================================================
// 组合器
// 严格翻译自: selectors/parser.rs Combinator
// ============================================================================

/// CSS 选择器组合器
/// 严格翻译自 Combinator enum
public enum CssCombinator {
    | Child           // > 子组合器
    | Descendant      // 后代组合器 (空格)
    | NextSibling     // + 相邻兄弟
    | LaterSibling    // ~ 通用兄弟
    | Deep            // /deep/ (已弃用)
    | DeepDescendant  // >>> (已弃用)
    | PseudoElement   // 伪元素分隔符
    | Part            // ::part()
    | SlotAssignment  // ::slotted()

    /// 转为 CSS 文本
    public func toCss(): String {
        match (this) {
            case Child => " > "
            case Descendant => " "
            case NextSibling => " + "
            case LaterSibling => " ~ "
            case Deep => " /deep/ "
            case DeepDescendant => " >>> "
            case PseudoElement => ""
            case Part => ""
            case SlotAssignment => ""
        }
    }
}

// ============================================================================
// 属性选择器操作符
// 严格翻译自: selectors/parser.rs AttrSelectorOperator
// ============================================================================

/// CSS 属性选择器操作符
public enum CssAttrSelectorOperator {
    | Equal       // =
    | Includes    // ~=
    | DashMatch   // |=
    | Prefix      // ^=
    | Substring   // *=
    | Suffix      // $=

    public func toCss(): String {
        match (this) {
            case Equal => "="
            case Includes => "~="
            case DashMatch => "|="
            case Prefix => "^="
            case Substring => "*="
            case Suffix => "$="
        }
    }
}

// ============================================================================
// 大小写敏感度
// 严格翻译自: selectors/parser.rs ParsedCaseSensitivity
// ============================================================================

/// CSS 属性选择器大小写敏感度
public enum CssParsedCaseSensitivity {
    | CaseSensitive                              // 默认大小写敏感
    | AsciiCaseInsensitive                       // i 标志
    | ExplicitCaseSensitive                      // s 标志
    | AsciiCaseInsensitiveIfInHtmlElementInHtmlDocument  // HTML 中默认

    public func toCss(): String {
        match (this) {
            case CaseSensitive => ""
            case AsciiCaseInsensitive => " i"
            case ExplicitCaseSensitive => " s"
            case AsciiCaseInsensitiveIfInHtmlElementInHtmlDocument => ""
        }
    }
}

// ============================================================================
// 伪类
// 严格翻译自: selectors/parser.rs PseudoClass
// ============================================================================

/// CSS 伪类
/// 严格翻译自 PseudoClass enum (大量变体)
public enum CssPseudoClassKind {
    // 用户动作
    | Hover
    | Active
    | Focus
    | FocusVisible
    | FocusWithin
    // 时间
    | Current
    | Past
    | Future
    // 资源状态
    | Playing
    | Paused
    | Seeking
    | Buffering
    | Stalled
    | Muted
    | VolumeLocked
    // 全屏
    | Fullscreen
    // 显示状态
    | Open
    | Closed
    | Modal
    | PictureInPicture
    | PopoverOpen
    | Defined
    // 链接
    | AnyLink
    | Link
    | LocalLink
    | Target
    | TargetWithin
    | Visited
    // 输入状态
    | Enabled
    | Disabled
    | ReadOnly
    | ReadWrite
    | PlaceholderShown
    | Default
    | Checked
    | Indeterminate
    | Blank
    | Valid
    | Invalid
    | InRange
    | OutOfRange
    | Required
    | Optional
    | UserValid
    | UserInvalid
    | Autofill
    // 语言/方向
    | Lang       // :lang()
    | Dir        // :dir()
    // 自定义
    | Custom
    // CSS Modules
    | Local      // :local()
    | Global     // :global()
    // Webkit 滚动条
    | WebkitScrollbar
}

/// CSS 伪类值
public class CssSelectorPseudoClass {
    public var kind: CssPseudoClassKind
    /// 自定义名称
    public var customName: String
    /// 语言列表
    public var languages: ArrayList<String>
    /// 方向
    public var direction: String
    /// 厂商前缀
    public var vendorPrefix: CssVendorPrefix

    public init(kind: CssPseudoClassKind) {
        this.kind = kind
        this.customName = ""
        this.languages = ArrayList<String>()
        this.direction = ""
        this.vendorPrefix = CssVendorPrefix()
    }

    public init(customName: String) {
        this.kind = CssPseudoClassKind.Custom
        this.customName = customName
        this.languages = ArrayList<String>()
        this.direction = ""
        this.vendorPrefix = CssVendorPrefix()
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Hover => ":hover"
            case Active => ":active"
            case Focus => ":focus"
            case FocusVisible => ":focus-visible"
            case FocusWithin => ":focus-within"
            case Current => ":current"
            case Past => ":past"
            case Future => ":future"
            case Playing => ":playing"
            case Paused => ":paused"
            case Seeking => ":seeking"
            case Buffering => ":buffering"
            case Stalled => ":stalled"
            case Muted => ":muted"
            case VolumeLocked => ":volume-locked"
            case Fullscreen => ":fullscreen"
            case Open => ":open"
            case Closed => ":closed"
            case Modal => ":modal"
            case PictureInPicture => ":picture-in-picture"
            case PopoverOpen => ":popover-open"
            case Defined => ":defined"
            case AnyLink => ":any-link"
            case Link => ":link"
            case LocalLink => ":local-link"
            case Target => ":target"
            case TargetWithin => ":target-within"
            case Visited => ":visited"
            case Enabled => ":enabled"
            case Disabled => ":disabled"
            case ReadOnly => ":read-only"
            case ReadWrite => ":read-write"
            case PlaceholderShown => ":placeholder-shown"
            case Default => ":default"
            case Checked => ":checked"
            case Indeterminate => ":indeterminate"
            case Blank => ":blank"
            case Valid => ":valid"
            case Invalid => ":invalid"
            case InRange => ":in-range"
            case OutOfRange => ":out-of-range"
            case Required => ":required"
            case Optional => ":optional"
            case UserValid => ":user-valid"
            case UserInvalid => ":user-invalid"
            case Autofill => ":autofill"
            case Lang => ":lang(${String.join(", ", languages)})"
            case Dir => ":dir(${direction})"
            case Custom => ":${customName}"
            case Local => ":local"
            case Global => ":global"
            case WebkitScrollbar => ":webkit-scrollbar"
        }
    }

    /// 深拷贝
    public func deepClone(): CssSelectorPseudoClass {
        let cloned = CssSelectorPseudoClass(kind)
        cloned.customName = customName
        cloned.languages = languages
        cloned.direction = direction
        cloned.vendorPrefix = vendorPrefix
        cloned
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 伪元素
// 严格翻译自: selectors/parser.rs PseudoElement
// ============================================================================

/// CSS 伪元素
/// 严格翻译自 PseudoElement enum
public enum CssPseudoElementKind {
    | After           // ::after
    | Before          // ::before
    | FirstLine       // ::first-line
    | FirstLetter     // ::first-letter
    | Marker          // ::marker
    | Selection       // ::selection
    | Cue             // ::cue
    | CueRegion       // ::cue-region
    | CueFunction     // ::cue(selector)
    | CueRegionFunction  // ::cue-region(selector)
    | Placeholder     // ::placeholder
    | Backdrop        // ::backdrop
    | FileSelectorButton  // ::file-selector-button
    | WebkitScrollbar // ::-webkit-scrollbar-*
    | ViewTransition       // ::view-transition
    | ViewTransitionGroup  // ::view-transition-group()
    | ViewTransitionImagePair  // ::view-transition-image-pair()
    | ViewTransitionOld   // ::view-transition-old()
    | ViewTransitionNew   // ::view-transition-new()
    | Custom          // ::custom

    /// 转为 CSS 文本
    public func toCss(): String {
        match (this) {
            case After => ":after"
            case Before => ":before"
            case FirstLine => ":first-line"
            case FirstLetter => ":first-letter"
            case Marker => "::marker"
            case Selection => "::selection"
            case Cue => "::cue"
            case CueRegion => "::cue-region"
            case Placeholder => "::placeholder"
            case Backdrop => "::backdrop"
            case FileSelectorButton => "::file-selector-button"
            case WebkitScrollbar => "::-webkit-scrollbar"
            case ViewTransition => "::view-transition"
            case ViewTransitionGroup => "::view-transition-group"
            case ViewTransitionImagePair => "::view-transition-image-pair"
            case ViewTransitionOld => "::view-transition-old"
            case ViewTransitionNew => "::view-transition-new"
            case Custom => "::custom"
            case CueFunction => "::cue()"
            case CueRegionFunction => "::cue-region()"
        }
    }
}

/// CSS 伪元素值
public class CssSelectorPseudoElement {
    public var kind: CssPseudoElementKind
    public var customName: String
    public var vendorPrefix: CssVendorPrefix

    public init(kind: CssPseudoElementKind) {
        this.kind = kind
        this.customName = ""
        this.vendorPrefix = CssVendorPrefix()
    }

    public init(customName: String) {
        this.kind = CssPseudoElementKind.Custom
        this.customName = customName
        this.vendorPrefix = CssVendorPrefix()
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        if (kind == CssPseudoElementKind.Custom && !customName.isEmpty()) {
            "::${customName}"
        } else {
            kind.toCss()
        }
    }

    /// 深拷贝
    public func deepClone(): CssSelectorPseudoElement {
        let cloned = CssSelectorPseudoElement(kind)
        cloned.customName = customName
        cloned.vendorPrefix = vendorPrefix
        cloned
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 选择器组件
// 严格翻译自: selectors/parser.rs Component
// ============================================================================

/// CSS 选择器组件
/// 严格翻译自 Component enum
public enum CssComponentKind {
    | Combinator         // 组合器
    | Id                 // #id
    | Class              // .class
    | LocalName          // 标签名
    | ExplicitUniversalType  // *
    | DefaultNamespace   // 默认命名空间
    | ExplicitNoNamespace    // |
    | ExplicitAnyNamespace   // *|
    | Namespace          // prefix|
    | AttributeInNoNamespaceExists  // [attr]
    | AttributeInNoNamespace       // [attr op value]
    | AttributeOther     // [ns|attr op value]
    | Root               // :root
    | Empty              // :empty
    | Scope              // :scope
    | Host               // :host()
    | Slotted            // ::slotted()
    | Part               // ::part()
    | Nth                // :nth-child() etc
    | NthOf              // :nth-child(... of ...)
    | Is                 // :is()
    | Where              // :where()
    | Negation           // :not()
    | Has                // :has()
    | Any                // :-prefix-any()
    | NonTsPseudoClass   // 伪类
    | PseudoElement      // 伪元素
    | Nesting            // &
}

/// CSS 选择器组件
public class CssSelectorComponent {
    public var kind: CssComponentKind
    /// 组合器值
    public var combinator: ?CssCombinator
    /// 标识符值 (ID, Class, LocalName)
    public var identifier: String
    /// 命名空间前缀
    public var namespacePrefix: String
    /// 伪类
    public var pseudoClass: ?CssSelectorPseudoClass
    /// 伪元素
    public var pseudoElement: ?CssSelectorPseudoElement
    /// 嵌套选择器列表 (Is, Where, Not, Has, Any)
    public var nestedSelectors: ?CssSelectorListImpl
    /// 厂商前缀
    public var vendorPrefix: CssVendorPrefix

    public init(kind: CssComponentKind) {
        this.kind = kind
        this.combinator = None
        this.identifier = ""
        this.namespacePrefix = ""
        this.pseudoClass = None
        this.pseudoElement = None
        this.nestedSelectors = None
        this.vendorPrefix = CssVendorPrefix()
    }

    public init(combinator: CssCombinator) {
        this.kind = CssComponentKind.Combinator
        this.combinator = Some(combinator)
        this.identifier = ""
        this.namespacePrefix = ""
        this.pseudoClass = None
        this.pseudoElement = None
        this.nestedSelectors = None
        this.vendorPrefix = CssVendorPrefix()
    }

    public init(id: String, kind: CssComponentKind) {
        this.kind = kind
        this.combinator = None
        this.identifier = id
        this.namespacePrefix = ""
        this.pseudoClass = None
        this.pseudoElement = None
        this.nestedSelectors = None
        this.vendorPrefix = CssVendorPrefix()
    }

    /// 是否为组合器
    public func isCombinator(): Bool {
        kind == CssComponentKind.Combinator
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (kind) {
            case Combinator => {
                match (combinator) {
                    case Some(c) => c.toCss()
                    case None => ""
                }
            }
            case Id => "#${identifier}"
            case Class => ".${identifier}"
            case LocalName => identifier
            case ExplicitUniversalType => "*"
            case DefaultNamespace => ""
            case ExplicitNoNamespace => "|"
            case ExplicitAnyNamespace => "*|"
            case Namespace => "${namespacePrefix}|"
            case Root => ":root"
            case Empty => ":empty"
            case Scope => ":scope"
            case Nesting => "&"
            case NonTsPseudoClass => {
                match (pseudoClass) {
                    case Some(pc) => pc.toCss()
                    case None => ""
                }
            }
            case PseudoElement => {
                match (pseudoElement) {
                    case Some(pe) => pe.toCss()
                    case None => ""
                }
            }
            case Is => {
                match (nestedSelectors) {
                    case Some(sels) => ":is(${sels.toCss()})"
                    case None => ":is()"
                }
            }
            case Where => {
                match (nestedSelectors) {
                    case Some(sels) => ":where(${sels.toCss()})"
                    case None => ":where()"
                }
            }
            case Negation => {
                match (nestedSelectors) {
                    case Some(sels) => ":not(${sels.toCss()})"
                    case None => ":not()"
                }
            }
            case Has => {
                match (nestedSelectors) {
                    case Some(sels) => ":has(${sels.toCss()})"
                    case None => ":has()"
                }
            }
            case AttributeInNoNamespaceExists => "[${identifier}]"
            case _ => ""
        }
    }

    /// 深拷贝
    public func deepClone(): CssSelectorComponent {
        let c = CssSelectorComponent(kind)
        c.combinator = combinator
        c.identifier = identifier
        c.namespacePrefix = namespacePrefix
        c.pseudoClass = match (pseudoClass) { case Some(pc) => Some(pc.deepClone()) case None => None }
        c.pseudoElement = match (pseudoElement) { case Some(pe) => Some(pe.deepClone()) case None => None }
        c.nestedSelectors = match (nestedSelectors) { case Some(s) => Some(s.deepClone()) case None => None }
        c.vendorPrefix = vendorPrefix
        c
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 选择器
// 严格翻译自: selectors/parser.rs Selector
// ============================================================================

/// CSS 选择器
/// 严格翻译自 Selector struct { components: SmallVec<[Component; 8]> }
public class CssSelectorImpl {
    /// 组件列表 (从右到左的匹配顺序)
    public var components: ArrayList<CssSelectorComponent>

    public init() {
        this.components = ArrayList<CssSelectorComponent>()
    }

    public init(components: ArrayList<CssSelectorComponent>) {
        this.components = components
    }

    /// 组件数量
    public func len(): Int64 {
        components.size
    }

    /// 是否有组合器
    public func hasCombinator(): Bool {
        for (c in components) {
            if (c.isCombinator()) { return true }
        }
        false
    }

    /// 从组件构建选择器
    /// 严格翻译自 Selector::from_component
    public static func fromComponent(component: CssSelectorComponent): CssSelectorImpl {
        let list = ArrayList<CssSelectorComponent>()
        list.append(component)
        CssSelectorImpl(list)
    }

    /// 相等比较
    public func eql(other: CssSelectorImpl): Bool {
        if (components.size != other.components.size) { return false }
        for (i in 0..components.size) {
            if (components[i].toCss() != other.components[i].toCss()) { return false }
        }
        true
    }

    /// 深拷贝
    public func deepClone(): CssSelectorImpl {
        let cloned = ArrayList<CssSelectorComponent>()
        for (c in components) {
            cloned.append(c.deepClone())
        }
        CssSelectorImpl(cloned)
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        let sb = StringBuilder()
        for (c in components) {
            sb.append(c.toCss())
        }
        sb.toString()
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 选择器列表
// 严格翻译自: selectors/parser.rs SelectorList
// ============================================================================

/// CSS 选择器列表
/// 严格翻译自 SelectorList struct { v: SmallList<Selector, 1> }
public class CssSelectorListImpl {
    /// 选择器列表
    public var v: ArrayList<CssSelectorImpl>

    public init() {
        this.v = ArrayList<CssSelectorImpl>()
    }

    public init(selectors: ArrayList<CssSelectorImpl>) {
        this.v = selectors
    }

    /// 是否为空
    public func isEmpty(): Bool {
        v.isEmpty()
    }

    /// 数量
    public func len(): Int64 {
        v.size
    }

    /// 深拷贝
    public func deepClone(): CssSelectorListImpl {
        let cloned = ArrayList<CssSelectorImpl>()
        for (s in v) {
            cloned.append(s.deepClone())
        }
        CssSelectorListImpl(cloned)
    }

    /// 相等比较
    public func eql(other: CssSelectorListImpl): Bool {
        if (v.size != other.v.size) { return false }
        for (i in 0..v.size) {
            if (!v[i].eql(other.v[i])) { return false }
        }
        true
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        let parts = ArrayList<String>()
        for (s in v) {
            parts.append(s.toCss())
        }
        String.join(", ", parts)
    }

    public func toString(): String {
        toCss()
    }
}
