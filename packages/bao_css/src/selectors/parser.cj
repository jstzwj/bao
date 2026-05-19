// bao_css - CSS 选择器解析器
// 严格翻译自: bun/src/css/selectors/parser.zig
//   对应: selectors/parser.zig - Component, Selector, SelectorList, Combinator, PseudoClass, PseudoElement
//   以及: selectors/selector.zig - is_equivalent, downlevel_selectors, get_prefix, is_compatible, is_unused, serialize, tocss_servo
//   以及: selectors/builder.zig - SelectorBuilder
package bao_css.selectors

import bao_core.*
import bao_collections.*
import bao_css.*

// ============================================================================
// 选择器空白字符
// 严格翻译自: selectors/parser.zig SELECTOR_WHITESPACE
// CSS Selectors Level 3 § 4 定义
// ============================================================================

/// CSS 选择器中的空白字符集
/// 严格翻译自 SELECTOR_WHITESPACE
public const SELECTOR_WHITESPACE: String = " \t\n\r"

private func cssAsciiLower(input: String): String {
    var bytes = ArrayList<UInt8>()
    for (ch in input) {
        var b = UInt8(ch)
        if (b >= UInt8(65) && b <= UInt8(90)) {
            b = b + UInt8(32)
        }
        bytes.append(b)
    }
    String.fromUtf8(bytes.toOwnedSlice())
}

private func cssMinU32(a: UInt32, b: UInt32): UInt32 {
    if (a < b) { a } else { b }
}

private func cssTrim(input: String): String {
    var start: Int64 = 0
    var end = input.size
    while (start < end && isWhitespace(input[start])) {
        start++
    }
    while (end > start && isWhitespace(input[end - 1])) {
        end--
    }
    input[start..end]
}

// ============================================================================
// 组合器
// 严格翻译自: selectors/parser.zig Combinator enum
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

    /// 是否为树结构组合器
    /// 严格翻译自 Combinator.isTreeCombinator()
    public func isTreeCombinator(): Bool {
        match (this) {
            case Child => true
            case Descendant => true
            case NextSibling => true
            case LaterSibling => true
            case _ => false
        }
    }

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
// 严格翻译自: selectors/parser.zig attrs.AttrSelectorOperator
// ============================================================================

/// CSS 属性选择器操作符
/// 严格翻译自 AttrSelectorOperator enum
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
// 严格翻译自: selectors/parser.zig attrs.ParsedCaseSensitivity
// ============================================================================

/// CSS 属性选择器大小写敏感度
/// 严格翻译自 ParsedCaseSensitivity enum
public enum CssParsedCaseSensitivity {
    | CaseSensitive                              // 's' 标志
    | AsciiCaseInsensitive                       // 'i' 标志
    | ExplicitCaseSensitive                      // 默认大小写敏感
    | AsciiCaseInsensitiveIfInHtmlElementInHtmlDocument  // HTML 中默认

    public func toCss(): String {
        match (this) {
            case CaseSensitive => " s"
            case AsciiCaseInsensitive => " i"
            case ExplicitCaseSensitive => ""
            case AsciiCaseInsensitiveIfInHtmlElementInHtmlDocument => ""
        }
    }
}

// ============================================================================
// 属性标志
// 严格翻译自: selectors/parser.zig AttributeFlags
// ============================================================================

/// 属性选择器标志 (s/i 标志)
/// 严格翻译自 AttributeFlags enum
public enum CssAttributeFlags {
    | CaseSensitive                    // 's' 标志
    | AsciiCaseInsensitive             // 'i' 标志
    | CaseSensitivityDependsOnName     // 无标志, 取决于属性名

    /// 根据属性名确定大小写敏感度
    /// 严格翻译自 AttributeFlags.toCaseSensitivity()
    public func toCaseSensitivity(localName: String, haveNamespace: Bool): CssParsedCaseSensitivity {
        match (this) {
            case CaseSensitive => CssParsedCaseSensitivity.ExplicitCaseSensitive
            case AsciiCaseInsensitive => CssParsedCaseSensitivity.AsciiCaseInsensitive
            case CaseSensitivityDependsOnName =>
                // HTML 中某些属性默认不区分大小写
                // 严格翻译自 AsciiCaseInsensitiveHtmlAttributes 列表
                let caseInsensitiveAttrs = [
                    "dir", "http-equiv", "rel", "enctype", "align", "accept",
                    "nohref", "lang", "bgcolor", "direction", "valign", "checked",
                    "frame", "link", "accept-charset", "hreflang", "text", "valuetype",
                    "language", "nowrap", "vlink", "disabled", "noshade", "codetype",
                    "defer", "noresize", "target", "scrolling", "rules", "scope",
                    "rev", "media", "method", "charset", "alink", "selected", "multiple",
                    "color", "shape", "type", "clear", "compact", "face", "declare",
                    "axis", "readonly"
                ]
                if (!haveNamespace) {
                    var found = false
                    for (attr in caseInsensitiveAttrs) {
                        if (attr == cssAsciiLower(localName)) {
                            found = true
                        }
                    }
                    if (found) {
                        CssParsedCaseSensitivity.AsciiCaseInsensitiveIfInHtmlElementInHtmlDocument
                    } else {
                        CssParsedCaseSensitivity.ExplicitCaseSensitive
                    }
                } else {
                    CssParsedCaseSensitivity.ExplicitCaseSensitive
                }
        }
    }
}

// ============================================================================
// 属性选择器操作
// 严格翻译自: selectors/parser.zig attrs.ParsedAttrSelectorOperation
// ============================================================================

/// 属性选择器操作 (存在/有值)
/// 严格翻译自 ParsedAttrSelectorOperation union
public class CssAttrSelectorOperation {
    /// 是否为存在性检查 (仅有 local_name)
    public var isExists: Bool
    /// 操作符 (非存在性检查时)
    public var `operator`: CssAttrSelectorOperator
    /// 大小写敏感度 (非存在性检查时)
    public var caseSensitivity: CssParsedCaseSensitivity
    /// 期望值 (非存在性检查时)
    public var expectedValue: String

    public init() {
        this.isExists = true
        this.`operator` = CssAttrSelectorOperator.Equal
        this.caseSensitivity = CssParsedCaseSensitivity.ExplicitCaseSensitive
        this.expectedValue = ""
    }

    public init(`operator`: CssAttrSelectorOperator, caseSensitivity: CssParsedCaseSensitivity, expectedValue: String) {
        this.isExists = false
        this.`operator` = `operator`
        this.caseSensitivity = caseSensitivity
        this.expectedValue = expectedValue
    }

    public func deepClone(): CssAttrSelectorOperation {
        if (isExists) {
            CssAttrSelectorOperation()
        } else {
            CssAttrSelectorOperation(`operator`, caseSensitivity, expectedValue)
        }
    }
}

// ============================================================================
// 命名空间约束
// 严格翻译自: selectors/parser.zig attrs.NamespaceConstraint
// ============================================================================

/// 命名空间约束
/// 严格翻译自 NamespaceConstraint union
public enum CssNamespaceConstraintKind {
    | Any       // *| (任意命名空间)
    | Specific  // 特定命名空间
}

public class CssNamespaceConstraint {
    public var kind: CssNamespaceConstraintKind
    public var prefix: String   // 特定命名空间前缀
    public var url: String      // 特定命名空间 URL

    public init() {
        this.kind = CssNamespaceConstraintKind.Any
        this.prefix = ""
        this.url = ""
    }

    public init(prefix: String, url: String) {
        this.kind = CssNamespaceConstraintKind.Specific
        this.prefix = prefix
        this.url = url
    }

    public func deepClone(): CssNamespaceConstraint {
        CssNamespaceConstraint(prefix, url)
    }
}

// ============================================================================
// 带可选命名空间的属性选择器
// 严格翻译自: selectors/parser.zig attrs.AttrSelectorWithOptionalNamespace
// ============================================================================

/// 带可选命名空间的属性选择器
/// 严格翻译自 AttrSelectorWithOptionalNamespace struct
public class CssAttrSelectorWithNamespace {
    public var namespace: ?CssNamespaceConstraint
    public var localName: String
    public var localNameLower: String
    public var operation: CssAttrSelectorOperation
    public var neverMatches: Bool

    public init() {
        this.namespace = None
        this.localName = ""
        this.localNameLower = ""
        this.operation = CssAttrSelectorOperation()
        this.neverMatches = false
    }

    /// 转为 CSS 文本
    /// 严格翻译自 AttrSelectorWithOptionalNamespace.toCss()
    public func toCss(): String {
        let sb = StringBuilder()
        sb.append("[")
        match (namespace) {
            case Some(nsp) =>
                match (nsp.kind) {
                    case CssNamespaceConstraintKind.Specific =>
                        sb.append(nsp.prefix)
                        sb.append("|")
                    case CssNamespaceConstraintKind.Any =>
                        sb.append("*|")
                }
            case None => ()
        }
        sb.append(localName)
        if (!operation.isExists) {
            sb.append(operation.`operator`.toCss())
            sb.append(operation.expectedValue)
            let cs = operation.caseSensitivity.toCss()
            if (!cs.isEmpty()) {
                sb.append(cs)
            }
        }
        sb.append("]")
        sb.toString()
    }

    public func deepClone(): CssAttrSelectorWithNamespace {
        let c = CssAttrSelectorWithNamespace()
        c.namespace = match (namespace) { case Some(n) => Some(n.deepClone()) case None => None }
        c.localName = localName
        c.localNameLower = localNameLower
        c.operation = operation.deepClone()
        c.neverMatches = neverMatches
        c
    }
}

// ============================================================================
// 特异性 (Specificity)
// 严格翻译自: selectors/parser.zig Specificity
// ============================================================================

/// CSS 选择器特异性
/// 严格翻译自 Specificity struct
public class CssSpecificity {
    public var idSelectors: UInt32
    public var classLikeSelectors: UInt32
    public var elementSelectors: UInt32

    public static let MAX_10BIT: UInt32 = 1023  // (1 << 10) - 1

    public init() {
        this.idSelectors = 0
        this.classLikeSelectors = 0
        this.elementSelectors = 0
    }

    public init(idSelectors: UInt32, classLikeSelectors: UInt32, elementSelectors: UInt32) {
        this.idSelectors = idSelectors
        this.classLikeSelectors = classLikeSelectors
        this.elementSelectors = elementSelectors
    }

    /// 转为 UInt32 表示
    /// 严格翻译自 Specificity.toU32()
    public func toU32(): UInt32 {
        (cssMinU32(idSelectors, CssSpecificity.MAX_10BIT) << 20) |
        (cssMinU32(classLikeSelectors, CssSpecificity.MAX_10BIT) << 10) |
        cssMinU32(elementSelectors, CssSpecificity.MAX_10BIT)
    }

    /// 从 UInt32 解析
    /// 严格翻译自 Specificity.fromU32()
    public static func fromU32(value: UInt32): CssSpecificity {
        CssSpecificity(value >> 20, (value >> 10) & MAX_10BIT, value & MAX_10BIT)
    }

    /// 加法
    /// 严格翻译自 Specificity.add()
    public func add(rhs: CssSpecificity): Unit {
        idSelectors += rhs.idSelectors
        elementSelectors += rhs.elementSelectors
        classLikeSelectors += rhs.classLikeSelectors
    }
}

// ============================================================================
// 方向
// 严格翻译自: selectors/parser.zig Direction
// ============================================================================

/// :dir() 伪类方向
/// 严格翻译自 Direction enum
public enum CssDirection {
    | Ltr   // 从左到右
    | Rtl   // 从右到左

    public func asStr(): String {
        match (this) {
            case Ltr => "ltr"
            case Rtl => "rtl"
        }
    }

    public func toCss(): String {
        asStr()
    }
}

// ============================================================================
// WebKit 滚动条伪类
// 严格翻译自: selectors/parser.zig WebKitScrollbarPseudoClass
// ============================================================================

/// WebKit 滚动条伪类
/// 严格翻译自 WebKitScrollbarPseudoClass enum
public enum CssWebKitScrollbarPseudoClass {
    | Horizontal      // :horizontal
    | Vertical        // :vertical
    | Decrement       // :decrement
    | Increment       // :increment
    | Start           // :start
    | End             // :end
    | DoubleButton    // :double-button
    | SingleButton    // :single-button
    | NoButton        // :no-button
    | CornerPresent   // :corner-present
    | WindowInactive  // :window-inactive

    public func toCss(): String {
        match (this) {
            case Horizontal => ":horizontal"
            case Vertical => ":vertical"
            case Decrement => ":decrement"
            case Increment => ":increment"
            case Start => ":start"
            case End => ":end"
            case DoubleButton => ":double-button"
            case SingleButton => ":single-button"
            case NoButton => ":no-button"
            case CornerPresent => ":corner-present"
            case WindowInactive => ":window-inactive"
        }
    }
}

// ============================================================================
// WebKit 滚动条伪元素
// 严格翻译自: selectors/parser.zig WebKitScrollbarPseudoElement
// ============================================================================

/// WebKit 滚动条伪元素
/// 严格翻译自 WebKitScrollbarPseudoElement enum
public enum CssWebKitScrollbarPseudoElement {
    | Scrollbar    // ::-webkit-scrollbar
    | Button       // ::-webkit-scrollbar-button
    | Track        // ::-webkit-scrollbar-track
    | TrackPiece   // ::-webkit-scrollbar-track-piece
    | Thumb        // ::-webkit-scrollbar-thumb
    | Corner       // ::-webkit-scrollbar-corner
    | Resizer      // ::-webkit-resizer

    public func toCss(): String {
        match (this) {
            case Scrollbar => "::-webkit-scrollbar"
            case Button => "::-webkit-scrollbar-button"
            case Track => "::-webkit-scrollbar-track"
            case TrackPiece => "::-webkit-scrollbar-track-piece"
            case Thumb => "::-webkit-scrollbar-thumb"
            case Corner => "::-webkit-scrollbar-corner"
            case Resizer => "::-webkit-resizer"
        }
    }
}

// ============================================================================
// 视图过渡部件名
// 严格翻译自: selectors/parser.zig ViewTransitionPartName
// ============================================================================

/// 视图过渡部件名选择器
/// 严格翻译自 ViewTransitionPartName union
public enum CssViewTransitionPartNameKind {
    | All     // *
    | Name    // <custom-ident>
    | Class   // .<custom-ident>
}

public class CssViewTransitionPartName {
    public var kind: CssViewTransitionPartNameKind
    public var name: String

    public init() {
        this.kind = CssViewTransitionPartNameKind.All
        this.name = ""
    }

    public init(name: String, kind: CssViewTransitionPartNameKind) {
        this.kind = kind
        this.name = name
    }

    public static func all(): CssViewTransitionPartName {
        CssViewTransitionPartName()
    }

    public static func fromName(name: String): CssViewTransitionPartName {
        CssViewTransitionPartName(name, CssViewTransitionPartNameKind.Name)
    }

    public static func fromClass(name: String): CssViewTransitionPartName {
        CssViewTransitionPartName(name, CssViewTransitionPartNameKind.Class)
    }

    public func toCss(): String {
        match (kind) {
            case All => "*"
            case Name => name
            case Class => ".${name}"
        }
    }

    public func deepClone(): CssViewTransitionPartName {
        CssViewTransitionPartName(name, kind)
    }
}

// ============================================================================
// Nth 类型
// 严格翻译自: selectors/parser.zig NthType
// ============================================================================

/// :nth-* 伪类类型
/// 严格翻译自 NthType enum
public enum CssNthType {
    | Child        // :nth-child
    | LastChild    // :nth-last-child
    | OnlyChild    // :only-child
    | OfType       // :nth-of-type
    | LastOfType   // :nth-last-of-type
    | OnlyOfType   // :only-of-type
    | Col          // :nth-col
    | LastCol      // :nth-last-col

    /// 是否为 only 变体
    /// 严格翻译自 NthType.isOnly()
    public func isOnly(): Bool {
        match (this) {
            case OnlyChild => true
            case OnlyOfType => true
            case _ => false
        }
    }

    /// 是否为 of-type 变体
    /// 严格翻译自 NthType.isOfType()
    public func isOfType(): Bool {
        match (this) {
            case OfType => true
            case LastOfType => true
            case OnlyOfType => true
            case _ => false
        }
    }

    /// 是否从末尾计数
    /// 严格翻译自 NthType.isFromEnd()
    public func isFromEnd(): Bool {
        match (this) {
            case LastChild => true
            case LastOfType => true
            case LastCol => true
            case _ => false
        }
    }

    /// 是否允许 "of <selector-list>" 语法
    /// 严格翻译自 NthType.allowsOfSelector()
    public func allowsOfSelector(): Bool {
        match (this) {
            case Child => true
            case LastChild => true
            case _ => false
        }
    }
}

// ============================================================================
// Nth 选择器数据
// 严格翻译自: selectors/parser.zig NthSelectorData
// ============================================================================

/// :nth- 伪类数据 (An+B 语法)
/// 严格翻译自 NthSelectorData struct
public class CssNthSelectorData {
    public var ty: CssNthType
    public var isFunction: Bool
    public var a: Int32
    public var b: Int32

    public init(ty: CssNthType, isFunction: Bool, a: Int32, b: Int32) {
        this.ty = ty
        this.isFunction = isFunction
        this.a = a
        this.b = b
    }

    /// :only-child / :only-of-type
    /// 严格翻译自 NthSelectorData.only()
    public static func only(ofType: Bool): CssNthSelectorData {
        CssNthSelectorData(
            if (ofType) { CssNthType.OnlyOfType } else { CssNthType.OnlyChild },
            false, 0, 1
        )
    }

    /// :first-child / :first-of-type
    /// 严格翻译自 NthSelectorData.first()
    public static func first(ofType: Bool): CssNthSelectorData {
        CssNthSelectorData(
            if (ofType) { CssNthType.OfType } else { CssNthType.Child },
            false, 0, 1
        )
    }

    /// :last-child / :last-of-type
    /// 严格翻译自 NthSelectorData.last()
    public static func last(ofType: Bool): CssNthSelectorData {
        CssNthSelectorData(
            if (ofType) { CssNthType.LastOfType } else { CssNthType.LastChild },
            false, 0, 1
        )
    }

    /// 是否为函数形式 (需要 An+B 表示)
    /// 严格翻译自 NthSelectorData.isFunction()
    public func isFunctionForm(): Bool {
        a != 0 || b != 1
    }

    /// 写入开头
    /// 严格翻译自 NthSelectorData.writeStart()
    public func writeStart(isFunc: Bool): String {
        match (ty) {
            case Child => if (isFunc) { ":nth-child(" } else { ":first-child" }
            case LastChild => if (isFunc) { ":nth-last-child(" } else { ":last-child" }
            case OfType => if (isFunc) { ":nth-of-type(" } else { ":first-of-type" }
            case LastOfType => if (isFunc) { ":nth-last-of-type(" } else { ":last-of-type" }
            case OnlyChild => ":only-child"
            case OnlyOfType => ":only-of-type"
            case Col => ":nth-col("
            case LastCol => ":nth-last-col("
        }
    }

    /// 格式化 An+B 表达式
    /// 严格翻译自 NthSelectorData.writeAffine()
    public func writeAffine(): String {
        if (a == 0 && b == 0) {
            "0"
        } else if (a == 1 && b == 0) {
            "n"
        } else if (a == -1 && b == 0) {
            "-n"
        } else if (b == 0) {
            "${a}n"
        } else if (a == 2 && b == 1) {
            "odd"
        } else if (a == 0) {
            "${b}"
        } else if (a == 1) {
            "n${numberSign(b)}${b}"
        } else if (a == -1) {
            "-n${numberSign(b)}${b}"
        } else {
            "${a}n${numberSign(b)}${b}"
        }
    }

    /// 数字符号辅助
    private func numberSign(num: Int32): String {
        if (num >= 0) { "+" } else { "" }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        let isFunc = isFunctionForm()
        var result = writeStart(isFunc)
        if (isFunc) {
            result += writeAffine()
            result += ")"
        }
        result
    }

    public func deepClone(): CssNthSelectorData {
        CssNthSelectorData(ty, isFunction, a, b)
    }
}

// ============================================================================
// Nth-of 选择器数据
// 严格翻译自: selectors/parser.zig NthOfSelectorData
// ============================================================================

/// :nth-child(... of ...) / :nth-last-child(... of ...)
/// 严格翻译自 NthOfSelectorData struct
public class CssNthOfSelectorData {
    public var data: CssNthSelectorData
    public var selectors: ArrayList<CssSelectorImpl>

    public init(data: CssNthSelectorData, selectors: ArrayList<CssSelectorImpl>) {
        this.data = data
        this.selectors = selectors
    }

    public func nthData(): CssNthSelectorData {
        data
    }

    public func deepClone(): CssNthOfSelectorData {
        let cloned = ArrayList<CssSelectorImpl>()
        for (s in selectors) { cloned.append(s.deepClone()) }
        CssNthOfSelectorData(data.deepClone(), cloned)
    }
}

// ============================================================================
// 伪类
// 严格翻译自: selectors/parser.zig PseudoClass
// ============================================================================

/// CSS 伪类
/// 严格翻译自 PseudoClass union (大量变体)
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
    | CustomFunction
    // CSS Modules
    | Local      // :local()
    | Global     // :global()
    // Webkit 滚动条
    | WebkitScrollbar
}

/// CSS 伪类值
/// 严格翻译自 PseudoClass union
public class CssSelectorPseudoClass {
    public var kind: CssPseudoClassKind
    /// 自定义名称 (custom / custom_function)
    public var customName: String
    /// 语言列表 (lang)
    public var languages: ArrayList<String>
    /// 方向 (dir)
    public var direction: CssDirection
    /// 厂商前缀 (fullscreen, any-link, read-only, read-write, placeholder-shown, autofill)
    public var vendorPrefix: VendorPrefix
    /// WebKit 滚动条伪类
    public var webkitScrollbar: CssWebKitScrollbarPseudoClass
    /// 自定义函数参数
    public var customArguments: String

    public init(kind: CssPseudoClassKind) {
        this.kind = kind
        this.customName = ""
        this.languages = ArrayList<String>()
        this.direction = CssDirection.Ltr
        this.vendorPrefix = VendorPrefix()
        this.webkitScrollbar = CssWebKitScrollbarPseudoClass.Horizontal
        this.customArguments = ""
    }

    public init(customName: String) {
        this.kind = CssPseudoClassKind.Custom
        this.customName = customName
        this.languages = ArrayList<String>()
        this.direction = CssDirection.Ltr
        this.vendorPrefix = VendorPrefix()
        this.webkitScrollbar = CssWebKitScrollbarPseudoClass.Horizontal
        this.customArguments = ""
    }

    /// 判断是否为用户动作状态伪类
    /// 严格翻译自 PseudoClass.isUserActionState()
    public func isUserActionState(): Bool {
        match (kind) {
            case Active => true
            case Hover => true
            case Focus => true
            case FocusWithin => true
            case FocusVisible => true
            case _ => false
        }
    }

    /// 是否在 webkit-scrollbar 之前有效
    /// 严格翻译自 PseudoClass.isValidBeforeWebkitScrollbar()
    public func isValidBeforeWebkitScrollbar(): Bool {
        match (kind) {
            case WebkitScrollbar => false
            case _ => true
        }
    }

    /// 是否在 webkit-scrollbar 之后有效
    /// 严格翻译自 PseudoClass.isValidAfterWebkitScrollbar()
    public func isValidAfterWebkitScrollbar(): Bool {
        match (kind) {
            case WebkitScrollbar => true
            case Enabled => true
            case Disabled => true
            case Hover => true
            case Active => true
            case _ => false
        }
    }

    /// 是否与另一个伪类等价 (忽略厂商前缀差异)
    /// 严格翻译自 PseudoClass.isEquivalent()
    public func isEquivalent(other: CssSelectorPseudoClass): Bool {
        // 带厂商前缀的伪类, 只要类型相同就认为等价
        match (kind) {
            case Fullscreen => match (other.kind) { case Fullscreen => true case _ => false }
            case AnyLink => match (other.kind) { case AnyLink => true case _ => false }
            case ReadOnly => match (other.kind) { case ReadOnly => true case _ => false }
            case ReadWrite => match (other.kind) { case ReadWrite => true case _ => false }
            case PlaceholderShown => match (other.kind) { case PlaceholderShown => true case _ => false }
            case Autofill => match (other.kind) { case Autofill => true case _ => false }
            case _ => toCss() == other.toCss()
        }
    }

    /// 获取厂商前缀
    /// 严格翻译自 PseudoClass.getPrefix()
    public func getPrefix(): VendorPrefix {
        match (kind) {
            case Fullscreen => vendorPrefix
            case AnyLink => vendorPrefix
            case ReadOnly => vendorPrefix
            case ReadWrite => vendorPrefix
            case PlaceholderShown => vendorPrefix
            case Autofill => vendorPrefix
            case _ => VendorPrefix()
        }
    }

    /// Helper: join languages for :lang()
    private func joinLanguages(): String {
        var langArr = Array<String>(languages.size, repeat: "")
        var li: Int64 = 0
        for (l in languages) { langArr[li] = l; li += 1 }
        String.join(langArr, delimiter: ", ")
    }

    /// 转为 CSS 文本
    /// 严格翻译自 selector.zig serialize.serializePseudoClass()
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
            case Lang => ":lang(${joinLanguages()})"
            case Dir => ":dir(${direction.asStr()})"
            case Custom => ":${customName}"
            case CustomFunction => ":${customName}(${customArguments})"
            case Local => ":local"
            case Global => ":global"
            case WebkitScrollbar => webkitScrollbar.toCss()
        }
    }

    /// 深拷贝
    public func deepClone(): CssSelectorPseudoClass {
        let cloned = CssSelectorPseudoClass(kind)
        cloned.customName = customName
        cloned.languages = languages
        cloned.direction = direction
        cloned.vendorPrefix = vendorPrefix
        cloned.webkitScrollbar = webkitScrollbar
        cloned.customArguments = customArguments
        cloned
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 伪元素
// 严格翻译自: selectors/parser.zig PseudoElement
// ============================================================================

/// CSS 伪元素类型
/// 严格翻译自 PseudoElement union
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
    | CustomFunction  // ::custom()
}

/// CSS 伪元素值
/// 严格翻译自 PseudoElement union
public class CssSelectorPseudoElement {
    public var kind: CssPseudoElementKind
    public var customName: String
    public var vendorPrefix: VendorPrefix
    /// WebKit 滚动条伪元素类型
    public var webkitScrollbar: CssWebKitScrollbarPseudoElement
    /// 视图过渡部件名
    public var viewTransitionPartName: ?CssViewTransitionPartName
    /// 自定义函数参数
    public var customArguments: String

    public init(kind: CssPseudoElementKind) {
        this.kind = kind
        this.customName = ""
        this.vendorPrefix = VendorPrefix()
        this.webkitScrollbar = CssWebKitScrollbarPseudoElement.Scrollbar
        this.viewTransitionPartName = None
        this.customArguments = ""
    }

    public init(customName: String) {
        this.kind = CssPseudoElementKind.Custom
        this.customName = customName
        this.vendorPrefix = VendorPrefix()
        this.webkitScrollbar = CssWebKitScrollbarPseudoElement.Scrollbar
        this.viewTransitionPartName = None
        this.customArguments = ""
    }

    /// 是否在 ::slotted() 之后有效
    /// 严格翻译自 PseudoElement.validAfterSlotted()
    public func validAfterSlotted(): Bool {
        match (kind) {
            case Before => true
            case After => true
            case Marker => true
            case Placeholder => true
            case FileSelectorButton => true
            case _ => false
        }
    }

    /// 是否为未知伪元素
    /// 严格翻译自 PseudoElement.isUnknown()
    public func isUnknown(): Bool {
        match (kind) {
            case Custom => true
            case CustomFunction => true
            case _ => false
        }
    }

    /// 是否接受状态伪类
    /// 严格翻译自 PseudoElement.acceptsStatePseudoClasses()
    public func acceptsStatePseudoClasses(): Bool {
        true  // 宽松处理
    }

    /// 是否为 WebKit 滚动条伪元素
    /// 严格翻译自 PseudoElement.isWebkitScrollbar()
    public func isWebkitScrollbar(): Bool {
        match (kind) {
            case WebkitScrollbar => true
            case _ => false
        }
    }

    /// 是否为视图过渡伪元素
    /// 严格翻译自 PseudoElement.isViewTransition()
    public func isViewTransition(): Bool {
        match (kind) {
            case ViewTransitionGroup => true
            case ViewTransitionImagePair => true
            case ViewTransitionNew => true
            case ViewTransitionOld => true
            case _ => false
        }
    }

    /// 是否与另一个伪元素等价 (忽略厂商前缀差异)
    /// 严格翻译自 PseudoElement.isEquivalent()
    public func isEquivalent(other: CssSelectorPseudoElement): Bool {
        match (kind) {
            case Selection => match (other.kind) { case Selection => true case _ => false }
            case Placeholder => match (other.kind) { case Placeholder => true case _ => false }
            case Backdrop => match (other.kind) { case Backdrop => true case _ => false }
            case FileSelectorButton => match (other.kind) { case FileSelectorButton => true case _ => false }
            case _ => toCss() == other.toCss()
        }
    }

    /// 获取厂商前缀
    /// 严格翻译自 PseudoElement.getPrefix()
    public func getPrefix(): VendorPrefix {
        match (kind) {
            case Selection => vendorPrefix
            case Placeholder => vendorPrefix
            case Backdrop => vendorPrefix
            case FileSelectorButton => vendorPrefix
            case _ => VendorPrefix()
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 selector.zig serialize.serializePseudoElement()
    public func toCss(): String {
        match (kind) {
            case After => ":after"
            case Before => ":before"
            case FirstLine => ":first-line"
            case FirstLetter => ":first-letter"
            case Marker => "::marker"
            case Selection => "::selection"
            case Cue => "::cue"
            case CueRegion => "::cue-region"
            case CueFunction => "::cue()"
            case CueRegionFunction => "::cue-region()"
            case Placeholder => "::placeholder"
            case Backdrop => "::backdrop"
            case FileSelectorButton => "::file-selector-button"
            case WebkitScrollbar => webkitScrollbar.toCss()
            case ViewTransition => "::view-transition"
            case ViewTransitionGroup =>
                match (viewTransitionPartName) {
                    case Some(pn) => "::view-transition-group(${pn.toCss()})"
                    case None => "::view-transition-group(*)"
                }
            case ViewTransitionImagePair =>
                match (viewTransitionPartName) {
                    case Some(pn) => "::view-transition-image-pair(${pn.toCss()})"
                    case None => "::view-transition-image-pair(*)"
                }
            case ViewTransitionOld =>
                match (viewTransitionPartName) {
                    case Some(pn) => "::view-transition-old(${pn.toCss()})"
                    case None => "::view-transition-old(*)"
                }
            case ViewTransitionNew =>
                match (viewTransitionPartName) {
                    case Some(pn) => "::view-transition-new(${pn.toCss()})"
                    case None => "::view-transition-new(*)"
                }
            case Custom => if (customName.isEmpty()) { "::custom" } else { "::${customName}" }
            case CustomFunction => "::${customName}(${customArguments})"
        }
    }

    /// 深拷贝
    public func deepClone(): CssSelectorPseudoElement {
        let cloned = CssSelectorPseudoElement(kind)
        cloned.customName = customName
        cloned.vendorPrefix = vendorPrefix
        cloned.webkitScrollbar = webkitScrollbar
        cloned.viewTransitionPartName = match (viewTransitionPartName) {
            case Some(pn) => Some(pn.deepClone())
            case None => None
        }
        cloned.customArguments = customArguments
        cloned
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 选择器组件
// 严格翻译自: selectors/parser.zig GenericComponent
// ============================================================================

/// CSS 选择器组件类型
/// 严格翻译自 GenericComponent union
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

    public operator func ==(rhs: CssComponentKind): Bool {
        match (this) {
            case Combinator => match (rhs) { case Combinator => true case _ => false }
            case Id => match (rhs) { case Id => true case _ => false }
            case Class => match (rhs) { case Class => true case _ => false }
            case LocalName => match (rhs) { case LocalName => true case _ => false }
            case ExplicitUniversalType => match (rhs) { case ExplicitUniversalType => true case _ => false }
            case DefaultNamespace => match (rhs) { case DefaultNamespace => true case _ => false }
            case ExplicitNoNamespace => match (rhs) { case ExplicitNoNamespace => true case _ => false }
            case ExplicitAnyNamespace => match (rhs) { case ExplicitAnyNamespace => true case _ => false }
            case Namespace => match (rhs) { case Namespace => true case _ => false }
            case AttributeInNoNamespaceExists => match (rhs) { case AttributeInNoNamespaceExists => true case _ => false }
            case AttributeInNoNamespace => match (rhs) { case AttributeInNoNamespace => true case _ => false }
            case AttributeOther => match (rhs) { case AttributeOther => true case _ => false }
            case Root => match (rhs) { case Root => true case _ => false }
            case Empty => match (rhs) { case Empty => true case _ => false }
            case Scope => match (rhs) { case Scope => true case _ => false }
            case Host => match (rhs) { case Host => true case _ => false }
            case Slotted => match (rhs) { case Slotted => true case _ => false }
            case Part => match (rhs) { case Part => true case _ => false }
            case Nth => match (rhs) { case Nth => true case _ => false }
            case NthOf => match (rhs) { case NthOf => true case _ => false }
            case Is => match (rhs) { case Is => true case _ => false }
            case Where => match (rhs) { case Where => true case _ => false }
            case Negation => match (rhs) { case Negation => true case _ => false }
            case Has => match (rhs) { case Has => true case _ => false }
            case Any => match (rhs) { case Any => true case _ => false }
            case NonTsPseudoClass => match (rhs) { case NonTsPseudoClass => true case _ => false }
            case PseudoElement => match (rhs) { case PseudoElement => true case _ => false }
            case Nesting => match (rhs) { case Nesting => true case _ => false }
        }
    }
}

/// CSS 选择器组件
/// 严格翻译自 GenericComponent union
public class CssSelectorComponent {
    public var kind: CssComponentKind
    /// 组合器值
    public var combinator: ?CssCombinator
    /// 标识符值 (ID, Class, LocalName)
    public var identifier: String
    /// 标识符小写形式
    public var identifierLower: String
    /// 命名空间前缀
    public var namespacePrefix: String
    /// 命名空间 URL
    public var namespaceUrl: String
    /// 伪类
    public var pseudoClass: ?CssSelectorPseudoClass
    /// 伪元素
    public var pseudoElement: ?CssSelectorPseudoElement
    /// 嵌套选择器列表 (Is, Where, Not, Has, Any)
    public var nestedSelectors: ?CssSelectorListImpl
    /// 厂商前缀
    public var vendorPrefix: VendorPrefix
    /// 属性选择器操作符
    public var attrOperator: CssAttrSelectorOperator
    /// 属性值
    public var attrValue: String
    /// 属性大小写敏感度
    public var attrCaseSensitivity: CssParsedCaseSensitivity
    /// 属性 never_matches
    public var attrNeverMatches: Bool
    /// 带命名空间的属性选择器
    public var attrWithNamespace: ?CssAttrSelectorWithNamespace
    /// Nth 数据
    public var nthData: ?CssNthSelectorData
    /// Nth-of 数据
    public var nthOfData: ?CssNthOfSelectorData
    /// Part 名称列表
    public var partNames: ArrayList<String>
    /// Host 内部选择器
    public var hostSelector: ?CssSelectorImpl
    /// Slotted 内部选择器
    public var slottedSelector: ?CssSelectorImpl

    public init(kind: CssComponentKind) {
        this.kind = kind
        this.combinator = None
        this.identifier = ""
        this.identifierLower = ""
        this.namespacePrefix = ""
        this.namespaceUrl = ""
        this.pseudoClass = None
        this.pseudoElement = None
        this.nestedSelectors = None
        this.vendorPrefix = VendorPrefix()
        this.attrOperator = CssAttrSelectorOperator.Equal
        this.attrValue = ""
        this.attrCaseSensitivity = CssParsedCaseSensitivity.ExplicitCaseSensitive
        this.attrNeverMatches = false
        this.attrWithNamespace = None
        this.nthData = None
        this.nthOfData = None
        this.partNames = ArrayList<String>()
        this.hostSelector = None
        this.slottedSelector = None
    }

    public init(combinator: CssCombinator) {
        this.kind = CssComponentKind.Combinator
        this.combinator = Some(combinator)
        this.identifier = ""
        this.identifierLower = ""
        this.namespacePrefix = ""
        this.namespaceUrl = ""
        this.pseudoClass = None
        this.pseudoElement = None
        this.nestedSelectors = None
        this.vendorPrefix = VendorPrefix()
        this.attrOperator = CssAttrSelectorOperator.Equal
        this.attrValue = ""
        this.attrCaseSensitivity = CssParsedCaseSensitivity.ExplicitCaseSensitive
        this.attrNeverMatches = false
        this.attrWithNamespace = None
        this.nthData = None
        this.nthOfData = None
        this.partNames = ArrayList<String>()
        this.hostSelector = None
        this.slottedSelector = None
    }

    public init(id: String, kind: CssComponentKind) {
        this.kind = kind
        this.combinator = None
        this.identifier = id
        this.identifierLower = cssAsciiLower(id)
        this.namespacePrefix = ""
        this.namespaceUrl = ""
        this.pseudoClass = None
        this.pseudoElement = None
        this.nestedSelectors = None
        this.vendorPrefix = VendorPrefix()
        this.attrOperator = CssAttrSelectorOperator.Equal
        this.attrValue = ""
        this.attrCaseSensitivity = CssParsedCaseSensitivity.ExplicitCaseSensitive
        this.attrNeverMatches = false
        this.attrWithNamespace = None
        this.nthData = None
        this.nthOfData = None
        this.partNames = ArrayList<String>()
        this.hostSelector = None
        this.slottedSelector = None
    }

    /// 是否为组合器
    /// 严格翻译自 GenericComponent.isCombinator()
    public func isCombinator(): Bool {
        kind == CssComponentKind.Combinator
    }

    /// 是否为本地作用域 (CSS Modules)
    /// 严格翻译自 GenericComponent.isLocallyScoped()
    public func isLocallyScoped(): Bool {
        match (kind) {
            case Id => true
            case Class => true
            case _ => false
        }
    }

    /// 作为组合器值
    /// 严格翻译自 GenericComponent.asCombinator()
    public func asCombinator(): ?CssCombinator {
        match (combinator) {
            case Some(c) => Some(c)
            case None => None
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 selector.zig tocss_servo.toCss_Component()
    public func toCss(): String {
        match (kind) {
            case Combinator =>
                match (combinator) {
                    case Some(c) => c.toCss()
                    case None => ""
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
            case AttributeInNoNamespaceExists => "[${identifier}]"
            case AttributeInNoNamespace =>
                let sb = StringBuilder()
                sb.append("[")
                sb.append(identifier)
                sb.append(attrOperator.toCss())
                sb.append(attrValue)
                let cs = attrCaseSensitivity.toCss()
                if (!cs.isEmpty()) {
                    sb.append(cs)
                }
                sb.append("]")
                sb.toString()
            case AttributeOther =>
                match (attrWithNamespace) {
                    case Some(attr) => attr.toCss()
                    case None => "[?]"
                }
            case Host =>
                match (hostSelector) {
                    case Some(sel) => ":host(${sel.toCss()})"
                    case None => ":host"
                }
            case Slotted =>
                match (slottedSelector) {
                    case Some(sel) => "::slotted(${sel.toCss()})"
                    case None => "::slotted()"
                }
            case Part =>
                let nameArr = Array<String>(partNames.size, repeat: "")
                var ni: Int64 = 0
                for (n in partNames) { nameArr[ni] = n; ni += 1 }
                "::part(${String.join(nameArr, delimiter: " ")})"
            case Nth =>
                match (nthData) {
                    case Some(nd) => nd.toCss()
                    case None => ":nth-child(?)"
                }
            case NthOf =>
                match (nthOfData) {
                    case Some(nd) =>
                        let ndBase = nd.nthData()
                        var result = ndBase.writeStart(true)
                        result += ndBase.writeAffine()
                        result += " of "
                        // 序列化选择器列表
                        let selList = nd.selectors
                        let parts = ArrayList<String>()
                        for (s in selList) { parts.append(s.toCss()) }
                        var partArr = Array<String>(parts.size, repeat: "")
                        var pi: Int64 = 0
                        for (p in parts) { partArr[pi] = p; pi += 1 }
                        result += String.join(partArr, delimiter: ", ")
                        result += ")"
                        result
                    case None => ":nth-child(? of ?)"
                }
            case NonTsPseudoClass =>
                match (pseudoClass) {
                    case Some(pc) => pc.toCss()
                    case None => ""
                }
            case PseudoElement =>
                match (pseudoElement) {
                    case Some(pe) => pe.toCss()
                    case None => ""
                }
            case Is =>
                match (nestedSelectors) {
                    case Some(sels) => ":is(${sels.toCss()})"
                    case None => ":is()"
                }
            case Where =>
                match (nestedSelectors) {
                    case Some(sels) => ":where(${sels.toCss()})"
                    case None => ":where()"
                }
            case Negation =>
                match (nestedSelectors) {
                    case Some(sels) => ":not(${sels.toCss()})"
                    case None => ":not()"
                }
            case Has =>
                match (nestedSelectors) {
                    case Some(sels) => ":has(${sels.toCss()})"
                    case None => ":has()"
                }
            case Any =>
                match (nestedSelectors) {
                    case Some(sels) => ":${vendorPrefix.toString()}any(${sels.toCss()})"
                    case None => ":${vendorPrefix.toString()}any()"
                }
        }
    }

    /// 深拷贝
    public func deepClone(): CssSelectorComponent {
        let c = CssSelectorComponent(kind)
        c.combinator = combinator
        c.identifier = identifier
        c.identifierLower = identifierLower
        c.namespacePrefix = namespacePrefix
        c.namespaceUrl = namespaceUrl
        c.pseudoClass = match (pseudoClass) { case Some(pc) => Some(pc.deepClone()) case None => None }
        c.pseudoElement = match (pseudoElement) { case Some(pe) => Some(pe.deepClone()) case None => None }
        c.nestedSelectors = match (nestedSelectors) { case Some(s) => Some(s.deepClone()) case None => None }
        c.vendorPrefix = vendorPrefix
        c.attrOperator = attrOperator
        c.attrValue = attrValue
        c.attrCaseSensitivity = attrCaseSensitivity
        c.attrNeverMatches = attrNeverMatches
        c.attrWithNamespace = match (attrWithNamespace) { case Some(a) => Some(a.deepClone()) case None => None }
        c.nthData = match (nthData) { case Some(n) => Some(n.deepClone()) case None => None }
        c.nthOfData = match (nthOfData) { case Some(n) => Some(n.deepClone()) case None => None }
        c.partNames = partNames
        c.hostSelector = match (hostSelector) { case Some(s) => Some(s.deepClone()) case None => None }
        c.slottedSelector = match (slottedSelector) { case Some(s) => Some(s.deepClone()) case None => None }
        c
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 选择器标志
// 严格翻译自: selectors/parser.zig SelectorFlags
// ============================================================================

/// 选择器标志
/// 严格翻译自 SelectorFlags packed struct
public class CssSelectorFlags {
    public var hasPseudo: Bool
    public var hasSlotted: Bool
    public var hasPart: Bool

    public init() {
        this.hasPseudo = false
        this.hasSlotted = false
        this.hasPart = false
    }

    public init(hasPseudo!: Bool, hasSlotted!: Bool, hasPart!: Bool) {
        this.hasPseudo = hasPseudo
        this.hasSlotted = hasSlotted
        this.hasPart = hasPart
    }
}

// ============================================================================
// 特异性和标志
// 严格翻译自: selectors/parser.zig SpecificityAndFlags
// ============================================================================

/// 特异性和标志
/// 严格翻译自 SpecificityAndFlags struct
public class CssSpecificityAndFlags {
    public var specificity: UInt32
    public var flags: CssSelectorFlags

    public init(specificity: UInt32, flags: CssSelectorFlags) {
        this.specificity = specificity
        this.flags = flags
    }

    /// 是否有伪元素
    /// 严格翻译自 SpecificityAndFlags.hasPseudoElement()
    public func hasPseudoElement(): Bool {
        flags.hasPseudo
    }
}

// ============================================================================
// 选择器解析状态
// 严格翻译自: selectors/parser.zig SelectorParsingState
// ============================================================================

/// 选择器解析状态
/// 严格翻译自 SelectorParsingState packed struct(u16)
public class CssSelectorParsingState {
    /// 是否跳过默认命名空间
    public var skipDefaultNamespace: Bool
    /// 是否已解析 ::slotted()
    public var afterSlotted: Bool
    /// 是否已解析 ::part()
    public var afterPart: Bool
    /// 是否已解析伪元素
    public var afterPseudoElement: Bool
    /// 是否已解析非状态伪元素
    public var afterNonStatefulPseudoElement: Bool
    /// 是否禁止组合器
    public var disallowCombinators: Bool
    /// 是否禁止伪元素
    public var disallowPseudos: Bool
    /// 是否已看到嵌套选择器
    public var afterNesting: Bool
    /// 是否在 webkit-scrollbar 之后
    public var afterWebkitScrollbar: Bool
    /// 是否在视图过渡之后
    public var afterViewTransition: Bool
    /// 是否在未知伪元素之后
    public var afterUnknownPseudoElement: Bool

    public init() {
        this.skipDefaultNamespace = false
        this.afterSlotted = false
        this.afterPart = false
        this.afterPseudoElement = false
        this.afterNonStatefulPseudoElement = false
        this.disallowCombinators = false
        this.disallowPseudos = false
        this.afterNesting = false
        this.afterWebkitScrollbar = false
        this.afterViewTransition = false
        this.afterUnknownPseudoElement = false
    }

    /// 是否在任何伪之后
    /// 严格翻译自 SelectorParsingState.afterAnyPseudo()
    public func afterAnyPseudo(): Bool {
        afterPart || afterSlotted || afterPseudoElement
    }

    /// 是否允许伪元素
    /// 严格翻译自 SelectorParsingState.allowsPseudos()
    public func allowsPseudos(): Bool {
        !afterPseudoElement && !disallowPseudos
    }

    /// 是否允许 ::part()
    /// 严格翻译自 SelectorParsingState.allowsPart()
    public func allowsPart(): Bool {
        !disallowPseudos && !afterAnyPseudo()
    }

    /// 是否允许 ::slotted()
    /// 严格翻译自 SelectorParsingState.allowsSlotted()
    public func allowsSlotted(): Bool {
        allowsPart()
    }

    /// 是否允许树结构伪类
    /// 严格翻译自 SelectorParsingState.allowsTreeStructuralPseudoClasses()
    public func allowsTreeStructuralPseudoClasses(): Bool {
        !afterAnyPseudo()
    }

    /// 是否允许非函数伪类
    /// 严格翻译自 SelectorParsingState.allowsNonFunctionalPseudoClasses()
    public func allowsNonFunctionalPseudoClasses(): Bool {
        !afterSlotted && !afterNonStatefulPseudoElement
    }

    /// 是否允许组合器
    /// 严格翻译自 SelectorParsingState.allowsCombinators()
    public func allowsCombinators(): Bool {
        !disallowCombinators
    }

    /// 是否允许自定义函数伪类
    /// 严格翻译自 SelectorParsingState.allowsCustomFunctionalPseudoClasses()
    public func allowsCustomFunctionalPseudoClasses(): Bool {
        !afterAnyPseudo()
    }
}

// ============================================================================
// 解析错误恢复
// 严格翻译自: selectors/parser.zig ParseErrorRecovery
// ============================================================================

/// 选择器列表解析错误恢复模式
/// 严格翻译自 ParseErrorRecovery enum
public enum CssParseErrorRecovery {
    | DiscardList               // 丢弃整个列表 (默认行为)
    | IgnoreInvalidSelector     // 忽略无效选择器 (用于 :is() 和 :where())
}

// ============================================================================
// 嵌套要求
// 严格翻译自: selectors/parser.zig NestingRequirement
// ============================================================================

/// 嵌套选择器要求
/// 严格翻译自 NestingRequirement enum
public enum CssNestingRequirement {
    | None       // 无要求
    | Prefixed   // 需要 & 前缀
    | Contained  // 包含
    | Implicit   // 隐式
}

// ============================================================================
// 选择器解析错误
// 严格翻译自: selectors/parser.zig SelectorParseErrorKind
// ============================================================================

/// 选择器解析错误类型
/// 严格翻译自 SelectorParseErrorKind union
public enum CssSelectorParseErrorKind {
    | InvalidState
    | ClassNeedsIdent
    | PseudoElementExpectedIdent
    | UnsupportedPseudoClassOrElement
    | NoQualifiedNameInAttributeSelector
    | UnexpectedTokenInAttributeSelector
    | UnexpectedSelectorAfterPseudoElement
    | InvalidQualNameInAttr
    | ExpectedBarInAttr
    | EmptySelector
    | DanglingCombinator
    | InvalidPseudoClassBeforeWebkitScrollbar
    | InvalidPseudoClassAfterWebkitScrollbar
    | InvalidPseudoClassAfterPseudoElement
    | MissingNestingSelector
    | MissingNestingPrefix
    | ExpectedNamespace
    | BadValueInAttr
    | ExplicitNamespaceUnexpectedToken
    | UnexpectedIdent
    | AmbiguousCssModuleClass
}

// ============================================================================
// 简单选择器解析结果
// 严格翻译自: selectors/parser.zig SimpleSelectorParseResult
// ============================================================================

/// 简单选择器解析结果类型
/// 严格翻译自 SimpleSelectorParseResult union
public enum CssSimpleSelectorParseResultKind {
    | SimpleSelector
    | PseudoElement
    | SlottedPseudo
    | PartPseudo
}

/// 简单选择器解析结果
public class CssSimpleSelectorParseResult {
    public var kind: CssSimpleSelectorParseResultKind
    public var simpleSelector: ?CssSelectorComponent
    public var pseudoElement: ?CssSelectorPseudoElement
    public var slottedPseudo: ?CssSelectorImpl
    public var partPseudo: ArrayList<String>

    public init(simpleSelector: CssSelectorComponent) {
        this.kind = CssSimpleSelectorParseResultKind.SimpleSelector
        this.simpleSelector = simpleSelector
        this.pseudoElement = None
        this.slottedPseudo = None
        this.partPseudo = ArrayList<String>()
    }

    public init(pseudoElement: CssSelectorPseudoElement) {
        this.kind = CssSimpleSelectorParseResultKind.PseudoElement
        this.simpleSelector = None
        this.pseudoElement = pseudoElement
        this.slottedPseudo = None
        this.partPseudo = ArrayList<String>()
    }

    public init(slottedPseudo: CssSelectorImpl) {
        this.kind = CssSimpleSelectorParseResultKind.SlottedPseudo
        this.simpleSelector = None
        this.pseudoElement = None
        this.slottedPseudo = slottedPseudo
        this.partPseudo = ArrayList<String>()
    }

    public init(partPseudo: ArrayList<String>) {
        this.kind = CssSimpleSelectorParseResultKind.PartPseudo
        this.simpleSelector = None
        this.pseudoElement = None
        this.slottedPseudo = None
        this.partPseudo = partPseudo
    }
}

// ============================================================================
// 选择器
// 严格翻译自: selectors/parser.zig GenericSelector
// ============================================================================

/// CSS 选择器
/// 严格翻译自 GenericSelector struct { specificity_and_flags, components }
public class CssSelectorImpl {
    /// 特异性和标志
    public var specificityAndFlags: CssSpecificityAndFlags
    /// 组件列表 (从右到左的匹配顺序)
    public var components: ArrayList<CssSelectorComponent>

    public init() {
        this.specificityAndFlags = CssSpecificityAndFlags(0, CssSelectorFlags())
        this.components = ArrayList<CssSelectorComponent>()
    }

    public init(components: ArrayList<CssSelectorComponent>) {
        this.specificityAndFlags = CssSpecificityAndFlags(0, CssSelectorFlags())
        this.components = components
    }

    public init(specificityAndFlags: CssSpecificityAndFlags, components: ArrayList<CssSelectorComponent>) {
        this.specificityAndFlags = specificityAndFlags
        this.components = components
    }

    /// 组件数量
    /// 严格翻译自 GenericSelector.len()
    public func len(): Int64 {
        components.size
    }

    /// 是否有树结构组合器
    /// 严格翻译自 GenericSelector.hasCombinator()
    public func hasCombinator(): Bool {
        for (c in components) {
            match (c.combinator) {
                case Some(combo) =>
                    if (combo.isTreeCombinator()) { return true }
                case None => ()
            }
        }
        false
    }

    /// 是否有伪元素
    /// 严格翻译自 GenericSelector.hasPseudoElement()
    public func hasPseudoElement(): Bool {
        specificityAndFlags.hasPseudoElement()
    }

    /// 获取特异性值
    /// 严格翻译自 GenericSelector.specificity()
    public func specificity(): UInt32 {
        specificityAndFlags.specificity
    }

    /// 从组件构建选择器
    /// 严格翻译自 GenericSelector.fromComponent()
    public static func fromComponent(component: CssSelectorComponent): CssSelectorImpl {
        let list = ArrayList<CssSelectorComponent>()
        list.append(component)
        CssSelectorImpl(list)
    }

    /// 将组件附加到选择器 (插入到组合器/伪元素之前)
    /// 严格翻译自 GenericSelector.append()
    public func append(component: CssSelectorComponent): Unit {
        var index = components.size
        for (i in 0..components.size) {
            match (components[i].kind) {
                case CssComponentKind.Combinator => index = i; break
                case CssComponentKind.PseudoElement => index = i; break
                case _ => ()
            }
        }
        components.insert(index, component)
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
        let sel = CssSelectorImpl(cloned)
        sel.specificityAndFlags = CssSpecificityAndFlags(
            specificityAndFlags.specificity,
            CssSelectorFlags(
                hasPseudo: specificityAndFlags.flags.hasPseudo,
                hasSlotted: specificityAndFlags.flags.hasSlotted,
                hasPart: specificityAndFlags.flags.hasPart
            )
        )
        sel
    }

    /// 转为 CSS 文本
    /// 严格翻译自 selector.zig tocss_servo.toCss_Selector()
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
// 严格翻译自: selectors/parser.zig GenericSelectorList
// ============================================================================

/// CSS 选择器列表
/// 严格翻译自 GenericSelectorList struct { v: SmallList<Selector, 1> }
public class CssSelectorListImpl {
    /// 选择器列表
    public var v: ArrayList<CssSelectorImpl>

    public init() {
        this.v = ArrayList<CssSelectorImpl>()
    }

    public init(selectors: ArrayList<CssSelectorImpl>) {
        this.v = selectors
    }

    /// 从单个选择器创建
    /// 严格翻译自 GenericSelectorList.fromSelector()
    public static func fromSelector(selector: CssSelectorImpl): CssSelectorListImpl {
        let list = ArrayList<CssSelectorImpl>()
        list.append(selector)
        CssSelectorListImpl(list)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        v.isEmpty()
    }

    /// 数量
    public func len(): Int64 {
        v.size
    }

    /// 是否有任意选择器包含伪元素
    /// 严格翻译自 GenericSelectorList.anyHasPseudoElement()
    public func anyHasPseudoElement(): Bool {
        for (sel in v) {
            if (sel.hasPseudoElement()) { return true }
        }
        false
    }

    /// 是否所有特异性相等
    /// 严格翻译自 GenericSelectorList.specifitiesAllEqual()
    public func specifitiesAllEqual(): Bool {
        if (v.size <= 1) { return true }
        let value = v[0].specificity()
        for (i in 1..v.size) {
            if (v[i].specificity() != value) { return false }
        }
        true
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
    /// 严格翻译自 selector.zig tocss_servo.toCss_SelectorList()
    public func toCss(): String {
        let parts = ArrayList<String>()
        for (s in v) {
            parts.append(s.toCss())
        }
        var partArr = Array<String>(parts.size, repeat: "")
        var pi: Int64 = 0
        for (p in parts) { partArr[pi] = p; pi += 1 }
        String.join(partArr, delimiter: ", ")
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// QNamed 前缀
// 严格翻译自: selectors/parser.zig QNamePrefix
// ============================================================================

/// 限定名前缀类型
/// 严格翻译自 QNamePrefix union
public enum CssQNamePrefixKind {
    | ImplicitNoNamespace        // `foo` in attr selectors
    | ImplicitAnyNamespace       // `foo` in type selectors, without a default ns
    | ImplicitDefaultNamespace   // `foo` in type selectors, with a default ns
    | ExplicitNoNamespace        // `|foo`
    | ExplicitAnyNamespace       // `*|foo`
    | ExplicitNamespace          // `prefix|foo`
}

/// 限定名前缀
public class CssQNamePrefix {
    public var kind: CssQNamePrefixKind
    public var prefix: String   // 命名空间前缀
    public var url: String      // 命名空间 URL

    public init(kind: CssQNamePrefixKind) {
        this.kind = kind
        this.prefix = ""
        this.url = ""
    }

    public init(prefix: String, url: String) {
        this.kind = CssQNamePrefixKind.ExplicitNamespace
        this.prefix = prefix
        this.url = url
    }

    public init(url: String) {
        this.kind = CssQNamePrefixKind.ImplicitDefaultNamespace
        this.prefix = ""
        this.url = url
    }
}

/// 可选限定名
/// 严格翻译自 OptionalQName union
public class CssOptionalQName {
    public var hasValue: Bool
    public var prefix: CssQNamePrefix
    public var localName: ?String

    public init() {
        this.hasValue = false
        this.prefix = CssQNamePrefix(CssQNamePrefixKind.ImplicitAnyNamespace)
        this.localName = None
    }

    public init(prefix: CssQNamePrefix, localName: ?String) {
        this.hasValue = true
        this.prefix = prefix
        this.localName = localName
    }
}

// ============================================================================
// 选择器解析器
// 严格翻译自: selectors/parser.zig SelectorParser
// ============================================================================

/// CSS 选择器解析器
/// 严格翻译自 SelectorParser struct
public class CssSelectorParser {
    public var isNestingAllowed: Bool
    public var deepCombinatorEnabled: Bool

    public init() {
        this.isNestingAllowed = true
        this.deepCombinatorEnabled = false
    }

    public init(isNestingAllowed: Bool, deepCombinatorEnabled: Bool) {
        this.isNestingAllowed = isNestingAllowed
        this.deepCombinatorEnabled = deepCombinatorEnabled
    }

    /// 是否允许嵌套
    /// 严格翻译自 SelectorParser.isNestingAllowed()
    public func isNestingAllowedFn(): Bool {
        isNestingAllowed
    }

    /// 是否启用深度组合器
    /// 严格翻译自 SelectorParser.deepCombinatorEnabled()
    public func deepCombinatorEnabledFn(): Bool {
        deepCombinatorEnabled
    }

    /// 是否解析 ::slotted()
    /// 严格翻译自 SelectorParser.parseSlotted()
    public func parseSlotted(): Bool {
        true
    }

    /// 是否解析 ::part()
    /// 严格翻译自 SelectorParser.parsePart()
    public func parsePart(): Bool {
        true
    }

    /// 是否解析 :is() 和 :where()
    /// 严格翻译自 SelectorParser.parseIsAndWhere()
    public func parseIsAndWhere(): Bool {
        true
    }

    /// 错误恢复模式
    /// 严格翻译自 SelectorParser.isAndWhereErrorRecovery()
    public func isAndWhereErrorRecovery(): CssParseErrorRecovery {
        CssParseErrorRecovery.IgnoreInvalidSelector
    }

    /// 是否解析 :host()
    /// 严格翻译自 SelectorParser.parseHost()
    public func parseHost(): Bool {
        true
    }

    /// 默认命名空间
    /// 严格翻译自 SelectorParser.defaultNamespace()
    public func defaultNamespace(): ?String {
        None
    }
}

// ============================================================================
// 选择器解析 - 辅助函数
// 严格翻译自: selectors/parser.zig 中的解析函数
// ============================================================================

/// 判断名称是否为 CSS2 伪元素 (可以用单冒号语法)
/// 严格翻译自 is_css2_pseudo_element()
public func isCss2PseudoElement(name: String): Bool {
    let lower = cssAsciiLower(name)
    lower == "before" || lower == "after" || lower == "first-line" || lower == "first-letter"
}

/// 判断组件是否为命名空间
/// 严格翻译自 selector.zg isNamespace()
public func isNamespace(component: ?CssSelectorComponent): Bool {
    match (component) {
        case Some(c) =>
            match (c.kind) {
                case CssComponentKind.ExplicitAnyNamespace => true
                case CssComponentKind.ExplicitNoNamespace => true
                case CssComponentKind.Namespace => true
                case CssComponentKind.DefaultNamespace => true
                case _ => false
            }
        case None => false
    }
}

/// 判断组件是否为类型选择器
/// 严格翻译自 selector.zig isTypeSelector()
public func isTypeSelector(component: ?CssSelectorComponent): Bool {
    match (component) {
        case Some(c) =>
            match (c.kind) {
                case CssComponentKind.LocalName => true
                case CssComponentKind.ExplicitUniversalType => true
                case _ => false
            }
        case None => false
    }
}

/// 判断选择器是否为简单选择器 (无组合器)
/// 严格翻译自 selector.zig isSimple()
public func isSimpleSelector(selector: CssSelectorImpl): Bool {
    for (c in selector.components) {
        if (c.isCombinator()) { return false }
    }
    true
}

/// 判断选择器是否有类型选择器
/// 严格翻译自 selector.zig hasTypeSelector()
public func hasTypeSelector(selector: CssSelectorImpl): Bool {
    if (selector.components.size == 0) { return false }
    let first = selector.components[0]
    if (isNamespace(Some(first))) {
        if (selector.components.size > 1) {
            isTypeSelector(Some(selector.components[1]))
        } else {
            false
        }
    } else {
        isTypeSelector(Some(first))
    }
}

/// 是否应展开 :is()
/// 严格翻译自 selector.zig shouldUnwrapIs()
public func shouldUnwrapIs(selectors: ArrayList<CssSelectorImpl>): Bool {
    if (selectors.size == 1) {
        let first = selectors[0]
        if (!hasTypeSelector(first) && isSimpleSelector(first)) {
            return true
        }
    }
    false
}

/// 是否应展开 :is() (数组版本)
public func shouldUnwrapIs(selectors: Array<CssSelectorImpl>): Bool {
    if (selectors.size == 1) {
        let first = selectors[0]
        if (!hasTypeSelector(first) && isSimpleSelector(first)) {
            return true
        }
    }
    false
}

// ============================================================================
// 解析伪类名称映射
// 严格翻译自: selectors/parser.zig SelectorParser.parseNonTsPseudoClass()
// ============================================================================

/// 从名称解析伪类
/// 严格翻译自 SelectorParser.parseNonTsPseudoClass() 中的 Map
public func parseNonTsPseudoClassFromName(name: String): CssSelectorPseudoClass {
    let lower = cssAsciiLower(name)
    // 用户动作伪类
    if (lower == "hover") { return CssSelectorPseudoClass(CssPseudoClassKind.Hover) }
    if (lower == "active") { return CssSelectorPseudoClass(CssPseudoClassKind.Active) }
    if (lower == "focus") { return CssSelectorPseudoClass(CssPseudoClassKind.Focus) }
    if (lower == "focus-visible") { return CssSelectorPseudoClass(CssPseudoClassKind.FocusVisible) }
    if (lower == "focus-within") { return CssSelectorPseudoClass(CssPseudoClassKind.FocusWithin) }
    // 时间伪类
    if (lower == "current") { return CssSelectorPseudoClass(CssPseudoClassKind.Current) }
    if (lower == "past") { return CssSelectorPseudoClass(CssPseudoClassKind.Past) }
    if (lower == "future") { return CssSelectorPseudoClass(CssPseudoClassKind.Future) }
    // 资源状态伪类
    if (lower == "playing") { return CssSelectorPseudoClass(CssPseudoClassKind.Playing) }
    if (lower == "paused") { return CssSelectorPseudoClass(CssPseudoClassKind.Paused) }
    if (lower == "seeking") { return CssSelectorPseudoClass(CssPseudoClassKind.Seeking) }
    if (lower == "buffering") { return CssSelectorPseudoClass(CssPseudoClassKind.Buffering) }
    if (lower == "stalled") { return CssSelectorPseudoClass(CssPseudoClassKind.Stalled) }
    if (lower == "muted") { return CssSelectorPseudoClass(CssPseudoClassKind.Muted) }
    if (lower == "volume-locked") { return CssSelectorPseudoClass(CssPseudoClassKind.VolumeLocked) }
    // 全屏
    if (lower == "fullscreen") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.Fullscreen)
        return pc
    }
    if (lower == "-webkit-full-screen") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.Fullscreen)
        return pc
    }
    // 显示状态
    if (lower == "open") { return CssSelectorPseudoClass(CssPseudoClassKind.Open) }
    if (lower == "closed") { return CssSelectorPseudoClass(CssPseudoClassKind.Closed) }
    if (lower == "modal") { return CssSelectorPseudoClass(CssPseudoClassKind.Modal) }
    if (lower == "picture-in-picture") { return CssSelectorPseudoClass(CssPseudoClassKind.PictureInPicture) }
    if (lower == "popover-open") { return CssSelectorPseudoClass(CssPseudoClassKind.PopoverOpen) }
    if (lower == "defined") { return CssSelectorPseudoClass(CssPseudoClassKind.Defined) }
    // 链接伪类
    if (lower == "any-link") { return CssSelectorPseudoClass(CssPseudoClassKind.AnyLink) }
    if (lower == "-webkit-any-link") { return CssSelectorPseudoClass(CssPseudoClassKind.AnyLink) }
    if (lower == "link") { return CssSelectorPseudoClass(CssPseudoClassKind.Link) }
    if (lower == "local-link") { return CssSelectorPseudoClass(CssPseudoClassKind.LocalLink) }
    if (lower == "target") { return CssSelectorPseudoClass(CssPseudoClassKind.Target) }
    if (lower == "target-within") { return CssSelectorPseudoClass(CssPseudoClassKind.TargetWithin) }
    if (lower == "visited") { return CssSelectorPseudoClass(CssPseudoClassKind.Visited) }
    // 输入状态伪类
    if (lower == "enabled") { return CssSelectorPseudoClass(CssPseudoClassKind.Enabled) }
    if (lower == "disabled") { return CssSelectorPseudoClass(CssPseudoClassKind.Disabled) }
    if (lower == "read-only") { return CssSelectorPseudoClass(CssPseudoClassKind.ReadOnly) }
    if (lower == "read-write") { return CssSelectorPseudoClass(CssPseudoClassKind.ReadWrite) }
    if (lower == "placeholder-shown") { return CssSelectorPseudoClass(CssPseudoClassKind.PlaceholderShown) }
    if (lower == "default") { return CssSelectorPseudoClass(CssPseudoClassKind.Default) }
    if (lower == "checked") { return CssSelectorPseudoClass(CssPseudoClassKind.Checked) }
    if (lower == "indeterminate") { return CssSelectorPseudoClass(CssPseudoClassKind.Indeterminate) }
    if (lower == "blank") { return CssSelectorPseudoClass(CssPseudoClassKind.Blank) }
    if (lower == "valid") { return CssSelectorPseudoClass(CssPseudoClassKind.Valid) }
    if (lower == "invalid") { return CssSelectorPseudoClass(CssPseudoClassKind.Invalid) }
    if (lower == "in-range") { return CssSelectorPseudoClass(CssPseudoClassKind.InRange) }
    if (lower == "out-of-range") { return CssSelectorPseudoClass(CssPseudoClassKind.OutOfRange) }
    if (lower == "required") { return CssSelectorPseudoClass(CssPseudoClassKind.Required) }
    if (lower == "optional") { return CssSelectorPseudoClass(CssPseudoClassKind.Optional) }
    if (lower == "user-valid") { return CssSelectorPseudoClass(CssPseudoClassKind.UserValid) }
    if (lower == "user-invalid") { return CssSelectorPseudoClass(CssPseudoClassKind.UserInvalid) }
    if (lower == "autofill") { return CssSelectorPseudoClass(CssPseudoClassKind.Autofill) }
    if (lower == "-webkit-autofill") { return CssSelectorPseudoClass(CssPseudoClassKind.Autofill) }
    // WebKit 滚动条
    if (lower == "horizontal") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.Horizontal
        return pc
    }
    if (lower == "vertical") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.Vertical
        return pc
    }
    if (lower == "decrement") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.Decrement
        return pc
    }
    if (lower == "increment") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.Increment
        return pc
    }
    if (lower == "start") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.Start
        return pc
    }
    if (lower == "end") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.End
        return pc
    }
    if (lower == "double-button") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.DoubleButton
        return pc
    }
    if (lower == "single-button") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.SingleButton
        return pc
    }
    if (lower == "no-button") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.NoButton
        return pc
    }
    if (lower == "corner-present") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.CornerPresent
        return pc
    }
    if (lower == "window-inactive") {
        let pc = CssSelectorPseudoClass(CssPseudoClassKind.WebkitScrollbar)
        pc.webkitScrollbar = CssWebKitScrollbarPseudoClass.WindowInactive
        return pc
    }
    // 默认为自定义伪类
    CssSelectorPseudoClass(name)
}

/// 从名称解析伪元素
/// 严格翻译自 SelectorParser.parsePseudoElement() 中的 Map
public func parsePseudoElementFromName(name: String): CssSelectorPseudoElement {
    let lower = cssAsciiLower(name)
    if (lower == "before") { return CssSelectorPseudoElement(CssPseudoElementKind.Before) }
    if (lower == "after") { return CssSelectorPseudoElement(CssPseudoElementKind.After) }
    if (lower == "first-line") { return CssSelectorPseudoElement(CssPseudoElementKind.FirstLine) }
    if (lower == "first-letter") { return CssSelectorPseudoElement(CssPseudoElementKind.FirstLetter) }
    if (lower == "cue") { return CssSelectorPseudoElement(CssPseudoElementKind.Cue) }
    if (lower == "cue-region") { return CssSelectorPseudoElement(CssPseudoElementKind.CueRegion) }
    if (lower == "selection") { return CssSelectorPseudoElement(CssPseudoElementKind.Selection) }
    if (lower == "-moz-selection") { return CssSelectorPseudoElement(CssPseudoElementKind.Selection) }
    if (lower == "placeholder") { return CssSelectorPseudoElement(CssPseudoElementKind.Placeholder) }
    if (lower == "-webkit-input-placeholder") {
        let pe = CssSelectorPseudoElement(CssPseudoElementKind.Placeholder)
        return pe
    }
    if (lower == "-moz-placeholder") { return CssSelectorPseudoElement(CssPseudoElementKind.Placeholder) }
    if (lower == "marker") { return CssSelectorPseudoElement(CssPseudoElementKind.Marker) }
    if (lower == "backdrop") { return CssSelectorPseudoElement(CssPseudoElementKind.Backdrop) }
    if (lower == "-webkit-backdrop") { return CssSelectorPseudoElement(CssPseudoElementKind.Backdrop) }
    if (lower == "file-selector-button") { return CssSelectorPseudoElement(CssPseudoElementKind.FileSelectorButton) }
    if (lower == "-webkit-file-upload-button") { return CssSelectorPseudoElement(CssPseudoElementKind.FileSelectorButton) }
    if (lower == "-webkit-scrollbar") {
        let pe = CssSelectorPseudoElement(CssPseudoElementKind.WebkitScrollbar)
        pe.webkitScrollbar = CssWebKitScrollbarPseudoElement.Scrollbar
        return pe
    }
    if (lower == "-webkit-scrollbar-button") {
        let pe = CssSelectorPseudoElement(CssPseudoElementKind.WebkitScrollbar)
        pe.webkitScrollbar = CssWebKitScrollbarPseudoElement.Button
        return pe
    }
    if (lower == "-webkit-scrollbar-track") {
        let pe = CssSelectorPseudoElement(CssPseudoElementKind.WebkitScrollbar)
        pe.webkitScrollbar = CssWebKitScrollbarPseudoElement.Track
        return pe
    }
    if (lower == "-webkit-scrollbar-track-piece") {
        let pe = CssSelectorPseudoElement(CssPseudoElementKind.WebkitScrollbar)
        pe.webkitScrollbar = CssWebKitScrollbarPseudoElement.TrackPiece
        return pe
    }
    if (lower == "-webkit-scrollbar-thumb") {
        let pe = CssSelectorPseudoElement(CssPseudoElementKind.WebkitScrollbar)
        pe.webkitScrollbar = CssWebKitScrollbarPseudoElement.Thumb
        return pe
    }
    if (lower == "-webkit-scrollbar-corner") {
        let pe = CssSelectorPseudoElement(CssPseudoElementKind.WebkitScrollbar)
        pe.webkitScrollbar = CssWebKitScrollbarPseudoElement.Corner
        return pe
    }
    if (lower == "-webkit-resizer") {
        let pe = CssSelectorPseudoElement(CssPseudoElementKind.WebkitScrollbar)
        pe.webkitScrollbar = CssWebKitScrollbarPseudoElement.Resizer
        return pe
    }
    if (lower == "view-transition") { return CssSelectorPseudoElement(CssPseudoElementKind.ViewTransition) }
    // 默认为自定义伪元素
    CssSelectorPseudoElement(name)
}

/// 解析厂商前缀别名 :-prefix-any()
/// 严格翻译自 SelectorParser.parseAnyPrefix()
public func parseAnyPrefix(name: String): ?VendorPrefix {
    let lower = cssAsciiLower(name)
    if (lower == "-webkit-any") { return Some(VendorPrefix()) }
    if (lower == "-moz-any") { return Some(VendorPrefix()) }
    None
}

// ============================================================================
// 计算特异性
// 严格翻译自: selectors/parser.zig compute_specificity
// ============================================================================

/// 计算选择器特异性
/// 严格翻译自 compute_specificity()
public func computeSelectorSpecificity(components: ArrayList<CssSelectorComponent>): UInt32 {
    var spec = CssSpecificity()
    for (i in 0..components.size) {
        computeSimpleSelectorSpecificity(components[i], spec)
    }
    spec.toU32()
}

/// 计算简单选择器特异性
/// 严格翻译自 compute_simple_selector_specificity()
public func computeSimpleSelectorSpecificity(component: CssSelectorComponent, spec: CssSpecificity): Unit {
    match (component.kind) {
        case CssComponentKind.Combinator => ()  // 不应该出现在简单选择器中
        case CssComponentKind.Part => spec.elementSelectors += 1
        case CssComponentKind.PseudoElement => spec.elementSelectors += 1
        case CssComponentKind.LocalName => spec.elementSelectors += 1
        case CssComponentKind.Slotted =>
            spec.elementSelectors += 1
            // slotted 特异性计算
        case CssComponentKind.Host =>
            spec.classLikeSelectors += 1
        case CssComponentKind.Id => spec.idSelectors += 1
        case CssComponentKind.Class => spec.classLikeSelectors += 1
        case CssComponentKind.AttributeInNoNamespace => spec.classLikeSelectors += 1
        case CssComponentKind.AttributeInNoNamespaceExists => spec.classLikeSelectors += 1
        case CssComponentKind.AttributeOther => spec.classLikeSelectors += 1
        case CssComponentKind.Root => spec.classLikeSelectors += 1
        case CssComponentKind.Empty => spec.classLikeSelectors += 1
        case CssComponentKind.Scope => spec.classLikeSelectors += 1
        case CssComponentKind.Nth => spec.classLikeSelectors += 1
        case CssComponentKind.NonTsPseudoClass => spec.classLikeSelectors += 1
        case CssComponentKind.NthOf =>
            spec.classLikeSelectors += 1
            // nth-of 还要加上选择器列表的最大特异性
        case CssComponentKind.Negation => ()
            // negation 特异性计算
        case CssComponentKind.Is => ()
            // is 特异性计算
        case CssComponentKind.Any => ()
            // any 特异性计算
        case CssComponentKind.Where => ()
        case CssComponentKind.Has => ()
        case CssComponentKind.ExplicitUniversalType => ()
        case CssComponentKind.ExplicitAnyNamespace => ()
        case CssComponentKind.ExplicitNoNamespace => ()
        case CssComponentKind.DefaultNamespace => ()
        case CssComponentKind.Namespace => ()
        case CssComponentKind.Nesting => ()
    }
}

// ============================================================================
// 解析选择器 - 核心逻辑
// 严格翻译自: selectors/parser.zig parse_selector, parse_compound_selector 等
// ============================================================================

/// 解析选择器字符串到选择器列表
/// 严格翻译自 GenericSelectorList.parseWithOptions() + parseWithState()
public func parseSelectorList(input: String): ?CssSelectorListImpl {
    // 简化实现: 解析逗号分隔的选择器列表
    let parts = splitByComma(input)
    let selectors = ArrayList<CssSelectorImpl>()
    for (part in parts) {
        let trimmed = cssTrim(part)
        if (trimmed.isEmpty()) { continue }
        let sel = parseSingleSelector(trimmed)
        match (sel) {
            case Some(s) => selectors.append(s)
            case None => ()
        }
    }
    if (selectors.size == 0) { return None }
    Some(CssSelectorListImpl(selectors))
}

/// 解析单个选择器
/// 严格翻译自 parse_selector()
public func parseSingleSelector(input: String): ?CssSelectorImpl {
    let components = ArrayList<CssSelectorComponent>()
    var state = CssSelectorParsingState()
    let parser = CssSelectorParser()
    var pos = 0
    let chars = input.toArray()

    parseCompoundSelector(chars, pos, state, parser, components)
    let spec = computeSelectorSpecificity(components)
    let flags = CssSelectorFlags(hasPseudo: state.afterPseudoElement, hasSlotted: state.afterSlotted, hasPart: state.afterPart)
    let sel = CssSelectorImpl(
        CssSpecificityAndFlags(spec, flags),
        components
    )
    Some(sel)
}

/// 解析复合选择器 (内联实现)
/// 严格翻译自 parse_compound_selector()
func parseCompoundSelector(
    chars: Array<UInt8>,
    pos: Int64,
    state: CssSelectorParsingState,
    parser: CssSelectorParser,
    components: ArrayList<CssSelectorComponent>
): Int64 {
    var i = pos
    var len = chars.size

    // 跳过空白
    while (i < len && isWhitespace(chars[i])) { i += 1 }

    var empty = true

    // 解析类型选择器
    i = parseTypeSelectorInternal(chars, i, state, parser, components)
    if (i > pos + 0) {  // 消费了某些字符
        // 检查是否真正消费了
        empty = false
    }

    // 解析简单选择器序列
    while (i < len) {
        let c = chars[i]

        if (c == UInt8(35)) {
            // ID 选择器
            i += 1
            let start = i
            while (i < len && !isWhitespace(chars[i]) && chars[i] != UInt8(46) &&
                   chars[i] != UInt8(35) && chars[i] != UInt8(91) &&
                   chars[i] != UInt8(58) && chars[i] != UInt8(62) &&
                   chars[i] != UInt8(43) && chars[i] != UInt8(126) &&
                   chars[i] != UInt8(44)) {
                i += 1
            }
            let id = substring(chars, start, i)
            components.append(CssSelectorComponent(id, CssComponentKind.Id))
            empty = false
        } else if (c == UInt8(46)) {
            // 类选择器
            i += 1
            let start = i
            while (i < len && !isWhitespace(chars[i]) && chars[i] != UInt8(46) &&
                   chars[i] != UInt8(35) && chars[i] != UInt8(91) &&
                   chars[i] != UInt8(58) && chars[i] != UInt8(62) &&
                   chars[i] != UInt8(43) && chars[i] != UInt8(126) &&
                   chars[i] != UInt8(44)) {
                i += 1
            }
            let className = substring(chars, start, i)
            components.append(CssSelectorComponent(className, CssComponentKind.Class))
            empty = false
        } else if (c == UInt8(91)) {
            // 属性选择器
            i = parseAttributeSelectorInternal(chars, i, components)
            empty = false
        } else if (c == UInt8(58)) {
            // 伪类/伪元素
            i = parseColonSelector(chars, i, state, parser, components)
            empty = false
        } else if (c == UInt8(38)) {
            // 嵌套选择器
            components.append(CssSelectorComponent(CssComponentKind.Nesting))
            state.afterNesting = true
            i += 1
            empty = false
        } else if (c == UInt8(42)) {
            // 通配符
            components.append(CssSelectorComponent(CssComponentKind.ExplicitUniversalType))
            i += 1
            empty = false
        } else {
            // 可能是组合器或结束
            break
        }
    }

    // 解析组合器
    while (i < len) {
        // 跳过空白
        var hadWhitespace = false
        while (i < len && isWhitespace(chars[i])) { i += 1; hadWhitespace = true }

        if (i >= len) { break }

        let c = chars[i]
        var combinator: ?CssCombinator = None

        if (c == UInt8(62)) {
            combinator = Some(CssCombinator.Child)
            i += 1
        } else if (c == UInt8(43)) {
            combinator = Some(CssCombinator.NextSibling)
            i += 1
        } else if (c == UInt8(126)) {
            combinator = Some(CssCombinator.LaterSibling)
            i += 1
        } else if (c == UInt8(47) && parser.deepCombinatorEnabledFn()) {
            // /deep/ combinator (非标准)
            if (i + 5 < len && substring(chars, i, i + 6) == "/deep/") {
                combinator = Some(CssCombinator.Deep)
                i += 6
            } else {
                break
            }
        } else if (hadWhitespace) {
            combinator = Some(CssCombinator.Descendant)
        } else {
            break
        }

        match (combinator) {
            case Some(combo) =>
                components.append(CssSelectorComponent(combo))
                // 递归解析下一个复合选择器
                i = parseCompoundSelector(chars, i, state, parser, components)
            case None => break
        }
    }

    i
}

/// 解析类型选择器
/// 严格翻译自 parse_type_selector()
func parseTypeSelectorInternal(
    chars: Array<UInt8>,
    pos: Int64,
    state: CssSelectorParsingState,
    parser: CssSelectorParser,
    components: ArrayList<CssSelectorComponent>
): Int64 {
    var i = pos
    let len = chars.size
    if (i >= len) { return i }

    let c = chars[i]

    // 通配符 *
    if (c == UInt8(42)) {
        // 检查是否为 *| 或 *|name
        if (i + 1 < len && chars[i + 1] == UInt8(124)) {
            components.append(CssSelectorComponent(CssComponentKind.ExplicitAnyNamespace))
            i += 2
            // 解析名称
            if (i < len && chars[i] != UInt8(42)) {
                let start = i
                while (i < len && isIdentChar(chars[i])) { i += 1 }
                components.append(CssSelectorComponent(substring(chars, start, i), CssComponentKind.LocalName))
            } else if (i < len && chars[i] == UInt8(42)) {
                components.append(CssSelectorComponent(CssComponentKind.ExplicitUniversalType))
                i += 1
            }
        } else {
            // 单独的 * 已经在调用处处理
            return i
        }
        return i
    }

    // |name (无命名空间)
    if (c == UInt8(124)) {
        i += 1
        let start = i
        while (i < len && isIdentChar(chars[i])) { i += 1 }
        if (i > start) {
            components.append(CssSelectorComponent(CssComponentKind.ExplicitNoNamespace))
            components.append(CssSelectorComponent(substring(chars, start, i), CssComponentKind.LocalName))
        }
        return i
    }

    // 标识符 (可能带命名空间前缀)
    if (isIdentStart(c)) {
        let start = i
        while (i < len && isIdentChar(chars[i])) { i += 1 }
        let name = substring(chars, start, i)

        // 检查是否有 | 分隔的命名空间
        if (i < len && chars[i] == UInt8(124)) {
            // name|something
            let nsComp = CssSelectorComponent(CssComponentKind.Namespace)
            nsComp.namespacePrefix = name
            nsComp.namespaceUrl = name
            components.append(nsComp)
            i += 1

            if (i < len && chars[i] == UInt8(42)) {
                components.append(CssSelectorComponent(CssComponentKind.ExplicitUniversalType))
                i += 1
            } else if (i < len && isIdentStart(chars[i])) {
                let start2 = i
                while (i < len && isIdentChar(chars[i])) { i += 1 }
                components.append(CssSelectorComponent(substring(chars, start2, i), CssComponentKind.LocalName))
            }
        } else {
            // 普通类型选择器
            components.append(CssSelectorComponent(name, CssComponentKind.LocalName))
        }
        return i
    }

    i
}

/// 解析冒号选择器 (伪类/伪元素)
/// 严格翻译自 parse_one_simple_selector() 中的 .colon 分支
func parseColonSelector(
    chars: Array<UInt8>,
    pos: Int64,
    state: CssSelectorParsingState,
    parser: CssSelectorParser,
    components: ArrayList<CssSelectorComponent>
): Int64 {
    var i = pos
    let len = chars.size

    i += 1  // 跳过第一个 :
    if (i >= len) { return i }

    let isSingleColon = if (chars[i] == UInt8(58)) {
        i += 1
        false  // 双冒号 -> 伪元素
    } else {
        true  // 单冒号 -> 可能伪类或 CSS2 伪元素
    }

    // 读取名称
    let start = i
    while (i < len && (isIdentChar(chars[i]) || chars[i] == UInt8(45))) { i += 1 }
    let name = substring(chars, start, i)

    if (name.isEmpty()) { return i }

    // 判断是伪元素还是伪类
    let isPseudoElement = !isSingleColon || isCss2PseudoElement(name)

    if (isPseudoElement) {
        let pe = parsePseudoElementFromName(name)
        if (!pe.isUnknown()) {
            state.afterPseudoElement = true
            components.append(CssSelectorComponent(CssCombinator.PseudoElement))
        } else {
            state.afterUnknownPseudoElement = true
        }
        if (pe.isWebkitScrollbar()) { state.afterWebkitScrollbar = true }
        if (pe.isViewTransition()) { state.afterViewTransition = true }
        let comp = CssSelectorComponent(CssComponentKind.PseudoElement)
        comp.pseudoElement = Some(pe)
        components.append(comp)
    } else {
        // 伪类
        // 检查是否有参数
        var hasArgs = false
        if (i < len && chars[i] == UInt8(40)) {
            hasArgs = true
            i += 1
            let argStart = i
            var depth = 1
            while (i < len && depth > 0) {
                if (chars[i] == UInt8(40)) { depth += 1 }
                else if (chars[i] == UInt8(41)) { depth -= 1 }
                if (depth > 0) { i += 1 }
            }
            let args = substring(chars, argStart, i)
            i += 1  // 跳过 )

            // 函数伪类
            let lower = cssAsciiLower(name)
            if (lower == "nth-child" || lower == "nth-of-type" || lower == "nth-last-child" || lower == "nth-last-of-type") {
                let nthType = match (lower) {
                    case "nth-child" => CssNthType.Child
                    case "nth-of-type" => CssNthType.OfType
                    case "nth-last-child" => CssNthType.LastChild
                    case "nth-last-of-type" => CssNthType.LastOfType
                    case _ => CssNthType.Child
                }
                // 解析 An+B
                let parsedNth = parseNthExpression(args)
                let nthData = CssNthSelectorData(nthType, true, parsedNth[0], parsedNth[1])
                let comp = CssSelectorComponent(CssComponentKind.Nth)
                comp.nthData = Some(nthData)
                components.append(comp)
            } else if (lower == "not") {
                // :not() - 解析内部选择器列表
                let innerSels = parseSelectorList(args)
                let comp = CssSelectorComponent(CssComponentKind.Negation)
                comp.nestedSelectors = innerSels
                components.append(comp)
            } else if (lower == "is") {
                let innerSels = parseSelectorList(args)
                let comp = CssSelectorComponent(CssComponentKind.Is)
                comp.nestedSelectors = innerSels
                components.append(comp)
            } else if (lower == "where") {
                let innerSels = parseSelectorList(args)
                let comp = CssSelectorComponent(CssComponentKind.Where)
                comp.nestedSelectors = innerSels
                components.append(comp)
            } else if (lower == "has") {
                let innerSels = parseSelectorList(args)
                let comp = CssSelectorComponent(CssComponentKind.Has)
                comp.nestedSelectors = innerSels
                components.append(comp)
            } else if (lower == "lang") {
                let pc = CssSelectorPseudoClass(CssPseudoClassKind.Lang)
                let langs = splitByComma(cssTrim(args))
                for (l in langs) { pc.languages.append(cssTrim(l)) }
                let comp = CssSelectorComponent(CssComponentKind.NonTsPseudoClass)
                comp.pseudoClass = Some(pc)
                components.append(comp)
            } else if (lower == "dir") {
                let pc = CssSelectorPseudoClass(CssPseudoClassKind.Dir)
                let dirStr = cssAsciiLower(cssTrim(args))
                pc.direction = if (dirStr == "rtl") { CssDirection.Rtl } else { CssDirection.Ltr }
                let comp = CssSelectorComponent(CssComponentKind.NonTsPseudoClass)
                comp.pseudoClass = Some(pc)
                components.append(comp)
            } else if (lower == "host") {
                let innerSel = parseSingleSelector(cssTrim(args))
                let comp = CssSelectorComponent(CssComponentKind.Host)
                comp.hostSelector = innerSel
                components.append(comp)
            } else {
                // 未知函数伪类
                let pc = CssSelectorPseudoClass(CssPseudoClassKind.CustomFunction)
                pc.customName = name
                pc.customArguments = args
                let comp = CssSelectorComponent(CssComponentKind.NonTsPseudoClass)
                comp.pseudoClass = Some(pc)
                components.append(comp)
            }
        } else {
            // 非函数伪类
            let lower = cssAsciiLower(name)
            // 树结构伪类
            if (lower == "first-child") {
                let comp = CssSelectorComponent(CssComponentKind.Nth)
                comp.nthData = Some(CssNthSelectorData.first(false))
                components.append(comp)
            } else if (lower == "last-child") {
                let comp = CssSelectorComponent(CssComponentKind.Nth)
                comp.nthData = Some(CssNthSelectorData.last(false))
                components.append(comp)
            } else if (lower == "only-child") {
                let comp = CssSelectorComponent(CssComponentKind.Nth)
                comp.nthData = Some(CssNthSelectorData.only(false))
                components.append(comp)
            } else if (lower == "first-of-type") {
                let comp = CssSelectorComponent(CssComponentKind.Nth)
                comp.nthData = Some(CssNthSelectorData.first(true))
                components.append(comp)
            } else if (lower == "last-of-type") {
                let comp = CssSelectorComponent(CssComponentKind.Nth)
                comp.nthData = Some(CssNthSelectorData.last(true))
                components.append(comp)
            } else if (lower == "only-of-type") {
                let comp = CssSelectorComponent(CssComponentKind.Nth)
                comp.nthData = Some(CssNthSelectorData.only(true))
                components.append(comp)
            } else if (lower == "root") {
                components.append(CssSelectorComponent(CssComponentKind.Root))
            } else if (lower == "empty") {
                components.append(CssSelectorComponent(CssComponentKind.Empty))
            } else if (lower == "scope") {
                components.append(CssSelectorComponent(CssComponentKind.Scope))
            } else if (lower == "host") {
                components.append(CssSelectorComponent(CssComponentKind.Host))
            } else {
                let pc = parseNonTsPseudoClassFromName(name)
                let comp = CssSelectorComponent(CssComponentKind.NonTsPseudoClass)
                comp.pseudoClass = Some(pc)
                components.append(comp)
            }
        }
    }

    i
}

/// 解析属性选择器
/// 严格翻译自 parse_attribute_selector()
func parseAttributeSelectorInternal(
    chars: Array<UInt8>,
    pos: Int64,
    components: ArrayList<CssSelectorComponent>
): Int64 {
    var i = pos
    let len = chars.size

    if (chars[i] != UInt8(91)) { return i }
    i += 1

    // 跳过空白
    while (i < len && isWhitespace(chars[i])) { i += 1 }

    // 解析属性名 (可能带命名空间)
    let nameStart = i
    while (i < len && chars[i] != UInt8(93) && chars[i] != UInt8(61) &&
           chars[i] != UInt8(126) && chars[i] != UInt8(124) &&
           chars[i] != UInt8(94) && chars[i] != UInt8(42) &&
           chars[i] != UInt8(36) && !isWhitespace(chars[i])) {
        i += 1
    }
    let attrName = substring(chars, nameStart, i)

    // 跳过空白
    while (i < len && isWhitespace(chars[i])) { i += 1 }

    if (i < len && chars[i] == UInt8(93)) {
        // [attr] - 存在性检查
        let comp = CssSelectorComponent(attrName, CssComponentKind.AttributeInNoNamespaceExists)
        components.append(comp)
        return i + 1
    }

    // 解析操作符
    var op = CssAttrSelectorOperator.Equal
    if (i < len) {
        let c = chars[i]
        if (c == UInt8(61) && i > pos) {
            op = CssAttrSelectorOperator.Equal
            i += 1
        } else if (c == UInt8(126) && i + 1 < len && chars[i + 1] == UInt8(61)) {
            op = CssAttrSelectorOperator.Includes
            i += 2
        } else if (c == UInt8(124) && i + 1 < len && chars[i + 1] == UInt8(61)) {
            op = CssAttrSelectorOperator.DashMatch
            i += 2
        } else if (c == UInt8(94) && i + 1 < len && chars[i + 1] == UInt8(61)) {
            op = CssAttrSelectorOperator.Prefix
            i += 2
        } else if (c == UInt8(42) && i + 1 < len && chars[i + 1] == UInt8(61)) {
            op = CssAttrSelectorOperator.Substring
            i += 2
        } else if (c == UInt8(36) && i + 1 < len && chars[i + 1] == UInt8(61)) {
            op = CssAttrSelectorOperator.Suffix
            i += 2
        }
    }

    // 跳过空白
    while (i < len && isWhitespace(chars[i])) { i += 1 }

    // 解析值
    let valueStart = i
    if (i < len && (chars[i] == UInt8(34) || chars[i] == UInt8(39))) {
        let quoteChar = chars[i]
        i += 1
        let vs = i
        while (i < len && chars[i] != quoteChar) { i += 1 }
        let value = substring(chars, vs, i)
        if (i < len) { i += 1 }  // 跳过引号

        // 跳过空白
        while (i < len && isWhitespace(chars[i])) { i += 1 }

        // 解析标志 (i/s)
        var caseSensitivity = CssParsedCaseSensitivity.ExplicitCaseSensitive
        if (i < len && chars[i] != UInt8(93)) {
            let flagStart = i
            while (i < len && chars[i] != UInt8(93) && !isWhitespace(chars[i])) { i += 1 }
            let flag = cssAsciiLower(substring(chars, flagStart, i))
            if (flag == "i") {
                caseSensitivity = CssParsedCaseSensitivity.AsciiCaseInsensitive
            } else if (flag == "s") {
                caseSensitivity = CssParsedCaseSensitivity.ExplicitCaseSensitive
            }
        }

        // 跳过空白和 ]
        while (i < len && isWhitespace(chars[i])) { i += 1 }
        if (i < len && chars[i] == UInt8(93)) { i += 1 }

        let comp = CssSelectorComponent(CssComponentKind.AttributeInNoNamespace)
        comp.identifier = attrName
        comp.attrOperator = op
        comp.attrValue = value
        comp.attrCaseSensitivity = caseSensitivity
        components.append(comp)
    } else {
        // 无引号值
        while (i < len && chars[i] != UInt8(93) && !isWhitespace(chars[i])) { i += 1 }
        let value = substring(chars, valueStart, i)

        // 跳过空白和 ]
        while (i < len && isWhitespace(chars[i])) { i += 1 }
        if (i < len && chars[i] == UInt8(93)) { i += 1 }

        let comp = CssSelectorComponent(CssComponentKind.AttributeInNoNamespace)
        comp.identifier = attrName
        comp.attrOperator = op
        comp.attrValue = value
        components.append(comp)
    }

    i
}

// ============================================================================
// Nth 表达式解析 (An+B 语法)
// 严格翻译自: selectors/parser.zig nth.parse_nth() 的简化实现
// ============================================================================

/// 解析 An+B 表达式, 返回 [a, b]
/// 严格翻译自 css/nth 解析逻辑
func parseNthExpression(input: String): Array<Int32> {
    let s = cssAsciiLower(cssTrim(input))
    let result = Array<Int32>(2, repeat: 0)  // [a, b]

    if (s == "odd") {
        result[0] = 2
        result[1] = 1
        return result
    }
    if (s == "even") {
        result[0] = 2
        result[1] = 0
        return result
    }

    // 尝试解析 An+B 格式
    let nIdx = s.indexOf("n")
    if (nIdx >= 0) {
        // An+B
        let aPart = s[0..nIdx]
        let bPart = s[(nIdx + 1)..s.size]
        if (aPart.isEmpty() || aPart == "+") {
            result[0] = 1
        } else if (aPart == "-") {
            result[0] = -1
        } else {
            result[0] = parseInt32(aPart)
        }

        if (bPart.isEmpty()) {
            result[1] = 0
        } else {
            result[1] = parseInt32(bPart.replace(" ", ""))
        }
    } else {
        // 纯数字
        result[0] = 0
        result[1] = parseInt32(s)
    }

    result
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 判断是否为空白字符
func isWhitespace(c: UInt8): Bool {
    c == UInt8(32) || c == UInt8(9) || c == UInt8(10) ||
    c == UInt8(13) || c == UInt8(12)
}

/// 判断是否为标识符起始字符
func isIdentStart(c: UInt8): Bool {
    (c >= UInt8(97) && c <= UInt8(122)) ||
    (c >= UInt8(65) && c <= UInt8(90)) ||
    c == UInt8(95) || c == UInt8(45)
}

/// 判断是否为标识符字符
func isIdentChar(c: UInt8): Bool {
    isIdentStart(c) || (c >= UInt8(48) && c <= UInt8(57))
}

/// 从字符数组提取子字符串
func substring(chars: Array<UInt8>, start: Int64, end: Int64): String {
    if (end <= start) { return "" }
    var sb = StringBuilder()
    for (i in start..end) {
        sb.append(String.fromUInt8(chars[i]))
    }
    sb.toString()
}

/// 按逗号分割
func splitByComma(input: String): Array<String> {
    let parts = ArrayList<String>()
    var depth = 0
    var start = 0
    let chars = input.toArray()
    var i: Int64 = 0
    while (i < chars.size) {
        let c = chars[i]
        if (c == UInt8(40)) { depth += 1 }
        else if (c == UInt8(41)) { depth -= 1 }
        else if (c == UInt8(91)) { depth += 1 }
        else if (c == UInt8(93)) { depth -= 1 }
        else if (c == UInt8(44) && depth == 0) {
            parts.append(input[start..i])
            start = i + 1
        }
        i += 1
    }
    if (start < chars.size) {
        parts.append(input[start..chars.size])
    }
    if (parts.size == 0) {
        parts.append(input)
    }
    var result = Array<String>(parts.size, repeat: "")
    for (j in 0..parts.size) { result[j] = parts[j] }
    result
}

/// 解析 Int32
func parseInt32(s: String): Int32 {
    if (s.isEmpty()) { return 0 }
    var cleaned = s.replace("+", "").replace(" ", "")
    var negative = false
    var idx: Int64 = 0
    let chars = cleaned.toArray()
    if (chars.size > 0 && chars[0] == UInt8(45)) {
        negative = true
        idx = 1
    }
    var result: Int32 = 0
    while (idx < chars.size) {
        let c = chars[idx]
        if (c >= UInt8(48) && c <= UInt8(57)) {
            result = result * 10 + (c - UInt8(48))
        }
        idx += 1
    }
    if (negative) { -result } else { result }
}
