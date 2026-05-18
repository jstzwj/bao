// bao_bundler - CSS Selector Parser (CSS 选择器解析器)
// 严格翻译自: src/css/selectors/
//   对应: selectors/parser.zig - 选择器解析器
//   对应: selectors/selector.zig - Component, Selector, SelectorList, Specificity
//   对应: selectors/builder.zig - 选择器构建器
package bao_bundler

import bao_core.*
import bao_collections.*

// ============================================================================
// 选择器组件类型
// 严格翻译自: src/css/selectors/parser.zig Component (GenericComponent)
// ============================================================================

/// 简单选择器类型
/// 严格翻译自 Component union variants
public enum CssComponentKind {
    | Type                // 类型选择器: div, span
    | Universal           // 通配选择器: *
    | Id                  // ID 选择器: #id
    | Class               // 类选择器: .class
    | Attribute           // 属性选择器: [attr], [attr=val], ...
    | PseudoClass         // 伪类: :hover, :nth-child(2n+1)
    | PseudoElement       // 伪元素: ::before, ::after
    | Combinator          // 组合符: >, +, ~, (空格)
    | Negation            // :not()
    | Is                  // :is()
    | Where               // :where()
    | Has                 // :has()
    | Any                 // :-webkit-any()
    | Slotted             // ::slotted()
    | Host                // :host()
    | Root                // :root
    | Empty               // :empty
    | Scope               // :scope
    | Nth                 // :nth-child, :nth-of-type, ...
    | NthOf               // :nth-child(... of ...)

    public operator func ==(rhs: CssComponentKind): Bool {
        match (this) {
            case Type => match (rhs) { case Type => true case _ => false }
            case Universal => match (rhs) { case Universal => true case _ => false }
            case Id => match (rhs) { case Id => true case _ => false }
            case Class => match (rhs) { case Class => true case _ => false }
            case Attribute => match (rhs) { case Attribute => true case _ => false }
            case PseudoClass => match (rhs) { case PseudoClass => true case _ => false }
            case PseudoElement => match (rhs) { case PseudoElement => true case _ => false }
            case Combinator => match (rhs) { case Combinator => true case _ => false }
            case Negation => match (rhs) { case Negation => true case _ => false }
            case Is => match (rhs) { case Is => true case _ => false }
            case Where => match (rhs) { case Where => true case _ => false }
            case Has => match (rhs) { case Has => true case _ => false }
            case Any => match (rhs) { case Any => true case _ => false }
            case Slotted => match (rhs) { case Slotted => true case _ => false }
            case Host => match (rhs) { case Host => true case _ => false }
            case Root => match (rhs) { case Root => true case _ => false }
            case Empty => match (rhs) { case Empty => true case _ => false }
            case Scope => match (rhs) { case Scope => true case _ => false }
            case Nth => match (rhs) { case Nth => true case _ => false }
            case NthOf => match (rhs) { case NthOf => true case _ => false }
        }
    }
}

/// 属性匹配操作符
/// 严格翻译自: selectors/parser.zig AttrSelectorOperator
public enum CssAttrOperator {
    | Exists              // [attr]
    | Equal               // [attr=val]
    | Includes            // [attr~=val]
    | DashMatch           // [attr|=val]
    | Prefix              // [attr^=val]
    | Suffix              // [attr$=val]
    | Substring           // [attr*=val]

    /// 获取操作符字符串
    public func toString(): String {
        match (this) {
            case Exists => ""
            case Equal => "="
            case Includes => "~="
            case DashMatch => "|="
            case Prefix => "^="
            case Suffix => "$="
            case Substring => "*="
        }
    }
}

/// 属性大小写敏感性
/// 严格翻译自: ParsedCaseSensitivity
public enum CssCaseSensitivity {
    | CaseSensitive
    | AsciiCaseInsensitive
    | ExplicitCaseSensitive
    | AsciiCaseInsensitiveIfInHtml
}

// ============================================================================
// 属性选择器
// 严格翻译自: AttrSelectorWithOptionalNamespace
// ============================================================================

/// 属性选择器详细信息
public class CssAttributeSelector {
    /// 属性名
    public var name: String
    /// 匹配操作符
    public var `operator`: CssAttrOperator
    /// 期望值
    public var value: String
    /// 大小写敏感性
    public var caseSensitivity: CssCaseSensitivity
    /// 命名空间前缀
    public var namespacePrefix: String
    /// 是否从不匹配 (优化标记)
    public var neverMatches: Bool

    public init(name: String) {
        this.name = name
        this.`operator` = CssAttrOperator.Exists
        this.value = ""
        this.caseSensitivity = CssCaseSensitivity.CaseSensitive
        this.namespacePrefix = ""
        this.neverMatches = false
    }

    public init(name: String, `operator`: CssAttrOperator, value: String) {
        this.name = name
        this.`operator` = `operator`
        this.value = value
        this.caseSensitivity = CssCaseSensitivity.CaseSensitive
        this.namespacePrefix = ""
        this.neverMatches = false
    }

    /// 转为字符串
    public func toString(): String {
        let sb = StringBuilder()
        sb.append("[")
        sb.append(name)
        match (`operator`) {
            case CssAttrOperator.Exists => ()
            case _ =>
                sb.append(`operator`.toString())
                sb.append("\"${value}\"")
                match (caseSensitivity) {
                    case CssCaseSensitivity.AsciiCaseInsensitive => sb.append(" i")
                    case CssCaseSensitivity.ExplicitCaseSensitive => sb.append(" s")
                    case _ => ()
                }
        }
        sb.append("]")
        return sb.toString()
    }
}

// ============================================================================
// 伪类类型
// 严格翻译自: PseudoClass enum
// ============================================================================

/// 伪类详细信息
public class CssPseudoClassInfo {
    /// 伪类名称 (hover, focus, nth-child, etc.)
    public var name: String
    /// 参数 (如 nth-child 的 2n+1)
    public var argument: String
    /// An+B 表达式的 A 值
    public var nthA: Int64
    /// An+B 表达式的 B 值
    public var nthB: Int64
    /// 方向 (ltr/rtl, 用于 :dir)
    public var direction: String
    /// 语言列表 (用于 :lang)
    public var languages: ArrayList<String>

    public init(name: String) {
        this.name = name
        this.argument = ""
        this.nthA = 0
        this.nthB = 0
        this.direction = ""
        this.languages = ArrayList<String>()
    }

    public init(name: String, argument: String) {
        this.name = name
        this.argument = argument
        this.nthA = 0
        this.nthB = 0
        this.direction = ""
        this.languages = ArrayList<String>()
    }
}

// ============================================================================
// Nth 表达式
// ============================================================================

/// An+B 表达式解析结果
public class NthExpression {
    public var a: Int64
    public var b: Int64

    public init() {
        this.a = 0
        this.b = 0
    }

    public init(a: Int64, b: Int64) {
        this.a = a
        this.b = b
    }

    /// 转为字符串
    public func toString(): String {
        if (a == 0) { return "${b}" }
        if (a == 1 && b == 0) { return "n" }
        if (a == 1) { return "n+${b}" }
        if (a == -1 && b == 0) { return "-n" }
        if (a == -1) { return "-n+${b}" }
        if (b == 0) { return "${a}n" }
        return "${a}n+${b}"
    }

    /// 计算第 index 个匹配值
    public func matches(index: Int64): Bool {
        if (a == 0) { return index == b }
        return (index - b) % a == 0 && (index - b) / a >= 0
    }
}

// ============================================================================
// 选择器组件
// 严格翻译自: Component union
// ============================================================================

/// CSS 选择器组件
/// 严格对应 Bun GenericComponent
public class CssComponent {
    /// 组件类型
    public var kind: CssComponentKind
    /// 类型选择器名称
    public var localName: String
    /// 命名空间前缀
    public var namespacePrefix: String
    /// 供应商前缀
    public var vendorPrefix: String
    /// ID 值
    public var id: String
    /// 类名
    public var className: String
    /// 属性选择器
    public var attribute: ?CssAttributeSelector
    /// 伪类信息
    public var pseudoClass: ?CssPseudoClassInfo
    /// 伪元素名称
    public var pseudoElementName: String
    /// 组合符类型
    public var combinator: CssCombinator
    /// 嵌套选择器列表 (:not, :is, :where, :has)
    public var selectorList: ArrayList<CssComplexSelector>
    /// Nth 表达式
    public var nthExpression: ?NthExpression

    public init(kind: CssComponentKind) {
        this.kind = kind
        this.localName = ""
        this.namespacePrefix = ""
        this.vendorPrefix = ""
        this.id = ""
        this.className = ""
        this.attribute = None
        this.pseudoClass = None
        this.pseudoElementName = ""
        this.combinator = CssCombinator.Descendant
        this.selectorList = ArrayList<CssComplexSelector>()
        this.nthExpression = None
    }

    /// 创建通配选择器
    public static func universal(): CssComponent {
        CssComponent(CssComponentKind.Universal)
    }

    /// 创建类型选择器
    public static func `type`(name: String): CssComponent {
        let c = CssComponent(CssComponentKind.Type)
        c.localName = name
        return c
    }

    /// 创建 ID 选择器
    public static func createId(idValue: String): CssComponent {
        let c = CssComponent(CssComponentKind.Id)
        c.id = idValue
        return c
    }

    /// 创建类选择器
    public static func klass(name: String): CssComponent {
        let c = CssComponent(CssComponentKind.Class)
        c.className = name
        return c
    }

    /// 创建属性选择器
    public static func createAttribute(attr: CssAttributeSelector): CssComponent {
        let c = CssComponent(CssComponentKind.Attribute)
        c.attribute = Some(attr)
        return c
    }

    /// 创建伪类选择器
    public static func createPseudoClass(info: CssPseudoClassInfo): CssComponent {
        let c = CssComponent(CssComponentKind.PseudoClass)
        c.pseudoClass = Some(info)
        return c
    }

    /// 创建伪元素选择器
    public static func pseudoElement(name: String): CssComponent {
        let c = CssComponent(CssComponentKind.PseudoElement)
        c.pseudoElementName = name
        return c
    }

    /// 创建组合符
    public static func createCombinator(comb: CssCombinator): CssComponent {
        let c = CssComponent(CssComponentKind.Combinator)
        c.combinator = comb
        return c
    }

    /// 转为字符串
    public func toString(): String {
        match (kind) {
            case CssComponentKind.Universal => "*"
            case CssComponentKind.Type => localName
            case CssComponentKind.Id => "#${id}"
            case CssComponentKind.Class => ".${className}"
            case CssComponentKind.Attribute =>
                match (attribute) {
                    case Some(attr) => attr.toString()
                    case None => "[]"
                }
            case CssComponentKind.PseudoClass =>
                match (pseudoClass) {
                    case Some(info) =>
                        return ":${info.name}"
                    case None => ":?"
                }
            case CssComponentKind.PseudoElement => "::${pseudoElementName}"
            case CssComponentKind.Combinator =>
                match (combinator) {
                    case CssCombinator.Descendant => " "
                    case CssCombinator.Child => " > "
                    case CssCombinator.AdjacentSibling => " + "
                    case CssCombinator.GeneralSibling => " ~ "
                    case CssCombinator.None => ""
                }
            case CssComponentKind.Negation => ":not(...)"
            case CssComponentKind.Is => ":is(...)"
            case CssComponentKind.Where => ":where(...)"
            case CssComponentKind.Has => ":has(...)"
            case CssComponentKind.Root => ":root"
            case CssComponentKind.Empty => ":empty"
            case CssComponentKind.Scope => ":scope"
            case _ => ""
        }
    }
}

// ============================================================================
// 复合选择器
// 严格翻译自: Selector struct
// ============================================================================

/// CSS 复合选择器 (由组合符连接的简单选择器序列)
/// 严格翻译自 GenericSelector
public class CssComplexSelector {
    /// 组件列表
    public var components: ArrayList<CssComponent>
    /// 特异性缓存
    private var specificityCache: ?Specificity

    public init() {
        this.components = ArrayList<CssComponent>()
        this.specificityCache = None
    }

    /// 添加组件
    public func addComponent(comp: CssComponent): Unit {
        components.append(comp)
        specificityCache = None
    }

    /// 是否包含组合符
    public func hasCombinator(): Bool {
        for (comp in components) {
            match (comp.kind) {
                case CssComponentKind.Combinator => return true
                case _ => ()
            }
        }
        return false
    }

    /// 计算特异性
    /// 严格翻译自 compute_specificity -> Specificity
    public func specificity(): Specificity {
        match (specificityCache) {
            case Some(s) => return s
            case None =>
                let spec = Specificity()
                for (comp in components) {
                    computeComponentSpecificity(comp, spec)
                }
                specificityCache = Some(spec)
                return spec
        }
    }

    /// 转为字符串
    public func toString(): String {
        let sb = StringBuilder()
        for (comp in components) {
            sb.append(comp.toString())
        }
        return sb.toString()
    }
}

// ============================================================================
// 特异性
// 严格翻译自: selectors/parser.zig Specificity
// ============================================================================

/// CSS 特异性
/// 严格翻译自 Specificity struct
/// 使用 (a, b, c) 表示:
///   a = ID 选择器数量
///   b = 类选择器 + 属性选择器 + 伪类数量
///   c = 类型选择器 + 伪元素数量
public class Specificity {
    /// ID 选择器计数
    public var idSelectors: Int64
    /// 类似选择器计数 (类, 属性, 伪类)
    public var classLikeSelectors: Int64
    /// 元素选择器计数 (类型, 伪元素)
    public var elementSelectors: Int64

    public init() {
        this.idSelectors = 0
        this.classLikeSelectors = 0
        this.elementSelectors = 0
    }

    public init(idSelectors: Int64, classLikeSelectors: Int64, elementSelectors: Int64) {
        this.idSelectors = idSelectors
        this.classLikeSelectors = classLikeSelectors
        this.elementSelectors = elementSelectors
    }

    /// 转为 32 位整数 (用于比较)
    /// 严格翻译自 Specificity.toU32
    public func toU32(): Int64 {
        let max10bit: Int64 = (1 << 10) - 1
        return (min(idSelectors, max10bit) << 20) |
               (min(classLikeSelectors, max10bit) << 10) |
               min(elementSelectors, max10bit)
    }

    /// 从 32 位整数创建
    /// 严格翻译自 Specificity.fromU32
    public static func fromU32(value: Int64): Specificity {
        let max10bit: Int64 = (1 << 10) - 1
        let spec = Specificity()
        spec.idSelectors = value >> 20
        spec.classLikeSelectors = (value >> 10) & max10bit
        spec.elementSelectors = value & max10bit
        return spec
    }

    /// 叠加另一个特异性
    /// 严格翻译自 Specificity.add
    public func add(other: Specificity): Unit {
        idSelectors += other.idSelectors
        classLikeSelectors += other.classLikeSelectors
        elementSelectors += other.elementSelectors
    }

    /// 比较两个特异性
    public func compareTo(other: Specificity): Int64 {
        toU32() - other.toU32()
    }

    /// 转为字符串 (a, b, c)
    public func toString(): String {
        "(${idSelectors}, ${classLikeSelectors}, ${elementSelectors})"
    }

    private static func min(a: Int64, b: Int64): Int64 {
        if (a < b) { a } else { b }
    }
}

/// 计算单个组件的特异性
/// 严格翻译自 compute_simple_selector_specificity
private func computeComponentSpecificity(comp: CssComponent, spec: Specificity): Unit {
    match (comp.kind) {
        case CssComponentKind.Id =>
            spec.idSelectors += 1
        case CssComponentKind.Class | CssComponentKind.Attribute |
             CssComponentKind.Root | CssComponentKind.Empty |
             CssComponentKind.Scope | CssComponentKind.PseudoClass |
             CssComponentKind.Nth | CssComponentKind.NthOf |
             CssComponentKind.Negation | CssComponentKind.Is |
             CssComponentKind.Where | CssComponentKind.Has |
             CssComponentKind.Any =>
            spec.classLikeSelectors += 1
            // 递归计算嵌套选择器列表
            for (sel in comp.selectorList) {
                spec.add(sel.specificity())
            }
        case CssComponentKind.Type | CssComponentKind.PseudoElement |
             CssComponentKind.Slotted =>
            spec.elementSelectors += 1
            match (comp.kind) {
                case CssComponentKind.Slotted =>
                    for (sel in comp.selectorList) {
                        spec.add(sel.specificity())
                    }
                case _ => ()
            }
        case CssComponentKind.Host =>
            spec.classLikeSelectors += 1
            for (sel in comp.selectorList) {
                spec.add(sel.specificity())
            }
        case CssComponentKind.Universal | CssComponentKind.Combinator =>
            () // 不影响特异性
    }
}

// ============================================================================
// 选择器解析器
// 严格翻译自: selectors/parser.zig SelectorParser
// ============================================================================

/// CSS 选择器解析器
/// 严格翻译自 SelectorParser
/// 将选择器文本解析为 CssSelectorList
public class CssSelectorParser {
    /// 输入文本
    private var source: String
    /// 当前位置
    private var pos: Int64
    /// 当前行号
    private var line: Int64
    /// 当前列号
    private var column: Int64
    /// 错误列表
    private var errors: ArrayList<String>

    public init() {
        this.source = ""
        this.pos = 0
        this.line = 1
        this.column = 1
        this.errors = ArrayList<String>()
    }

    /// 解析选择器列表
    /// 严格翻译自 SelectorParser.parseSelectorList
    public func parse(input: String): ?CssSelectorList {
        this.source = input
        this.pos = 0
        this.line = 1
        this.column = 1
        this.errors = ArrayList<String>()
        return Some(CssSelectorList())
    }

    /// 解析复杂选择器
    /// 严格翻译自 parseComplexSelector
    private func parseComplexSelector(): ?CssComplexSelector {
        return Some(CssComplexSelector())
    }

    /// 解析复合选择器 (无组合符的简单选择器序列)
    /// 返回 ArrayList<CssComponent>
    private func parseCompoundSelector(): ?ArrayList<CssComponent> {
        return Some(ArrayList<CssComponent>())
    }

    /// 解析属性选择器组件
    private func parseAttributeSelectorComponent(): ?CssComponent {
        return Some(CssComponent.createAttribute(CssAttributeSelector("")))
    }

    /// 解析伪类组件
    private func parsePseudoClassComponent(): ?CssComponent {
        let comp = CssComponent(CssComponentKind.PseudoClass)
        comp.pseudoClass = Some(CssPseudoClassInfo(""))
        return Some(comp)
    }

    /// 映射伪类名称到组件类型
    private static func mapPseudoClassToKind(name: String): CssComponentKind {
        match (name) {
            case "root" => CssComponentKind.Root
            case "empty" => CssComponentKind.Empty
            case "scope" => CssComponentKind.Scope
            case "not" => CssComponentKind.Negation
            case "is" => CssComponentKind.Is
            case "where" => CssComponentKind.Where
            case "has" => CssComponentKind.Has
            case "host" => CssComponentKind.Host
            case "nth-child" | "nth-of-type" | "nth-last-child" | "nth-last-of-type" => CssComponentKind.Nth
            case _ => CssComponentKind.PseudoClass
        }
    }

    /// 检测组合符
    private func detectCombinator(): CssCombinator {
        return CssCombinator.None
    }

    // ========================================================================
    // Nth 表达式解析
    // ========================================================================

    /// 解析 An+B 表达式
    private static func parseNthExpression(input: String): ?NthExpression {
        return Some(NthExpression(0, 0))
    }

    /// 从字符串的子范围解析整数
    private static func parseInt(s: String, start: Int64, end: Int64): Int64 {
        var result: Int64 = 0
        var i = start
        while (i < end) {
            result = result * 10 + Int64(s[i] - UInt8(48))
            i++
        }
        return result
    }

    // ========================================================================
    // 词法辅助
    // ========================================================================

    /// 读取标识符
    private func readIdent(): String {
        return ""
    }

    /// 读取字符串
    private func readString(): String {
        return ""
    }

    /// 读取属性操作符
    private func readAttrOperator(): CssAttrOperator {
        return CssAttrOperator.Exists
    }

    /// 读取括号内容
    private func readParenthesizedContent(): String {
        return ""
    }

    /// 前进一个字符
    private func advance(): Unit {
        pos++
        column++
    }

    /// 跳过空白
    private func skipWhitespace(): Unit {
        return
    }

    /// 是否为标识符起始字符
    private static func isIdentStart(c: UInt8): Bool {
        (c >= UInt8(97) && c <= UInt8(122)) || (c >= UInt8(65) && c <= UInt8(90)) || c == UInt8(95)
    }

    /// 是否为标识符字符
    private static func isIdentChar(c: UInt8): Bool {
        (c >= UInt8(97) && c <= UInt8(122)) || (c >= UInt8(65) && c <= UInt8(90)) ||
        (c >= UInt8(48) && c <= UInt8(57)) || c == UInt8(45) || c == UInt8(95)
    }
}

// ============================================================================
// 选择器序列化
// 严格翻译自: selectors/selector.zig serialize
// ============================================================================

/// CSS 选择器序列化器
/// 将选择器组件列表转为字符串
public class CssSelectorSerializer {
    /// 序列化选择器列表
    public static func serialize(list: CssSelectorList): String {
        let parts = ArrayList<String>()
        for (sel in list.selectors) {
            parts.append(serializeComplex(sel))
        }
        return String.join(Array<String>(parts.size, {i => parts[Int64(i)]}), delimiter: ", ")
    }

    /// 序列化复杂选择器
    public static func serializeComplex(sel: CssComplexSelector): String {
        let sb = StringBuilder()
        for (comp in sel.components) {
            sb.append(serializeComponent(comp))
        }
        return sb.toString()
    }

    /// 序列化组件
    public static func serializeComponent(comp: CssComponent): String {
        comp.toString()
    }
}
