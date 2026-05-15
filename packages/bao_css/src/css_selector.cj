// bao_css - CSS Selector Parser (CSS 选择器解析器)
// 严格翻译自: bun/src/css/selectors/
//   对应: selectors/parser.zig - 选择器解析器
//   对应: selectors/selector.zig - Component, Selector, SelectorList, Specificity
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// 组合符类型
// ============================================================================

/// CSS 组合符
/// 严格翻译自 Combinator enum
public enum CssCombinator {
    | None               // 无组合符
    | Descendant         // 后代 (空格)
    | Child              // 子 (>)
    | AdjacentSibling    // 相邻兄弟 (+)
    | GeneralSibling     // 通用兄弟 (~)

    public func toString(): String {
        match (this) {
            case None => ""
            case Descendant => " "
            case Child => " > "
            case AdjacentSibling => " + "
            case GeneralSibling => " ~ "
        }
    }
}

// ============================================================================
// 选择器组件类型
// 严格翻译自: src/css/selectors/parser.zig Component (GenericComponent)
// ============================================================================

/// 简单选择器类型
public enum CssComponentKind {
    | Type
    | Universal
    | Id
    | Class
    | Attribute
    | PseudoClass
    | PseudoElement
    | Combinator
    | Negation
    | Is
    | Where
    | Has
    | Any
    | Slotted
    | Host
    | Root
    | Empty
    | Scope
    | Nth
    | NthOf
}

/// 属性匹配操作符
/// 严格翻译自: AttrSelectorOperator
public enum CssAttrOperator {
    | Exists
    | Equal
    | Includes
    | DashMatch
    | Prefix
    | Suffix
    | Substring

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
public enum CssCaseSensitivity {
    | CaseSensitive
    | AsciiCaseInsensitive
    | ExplicitCaseSensitive
    | AsciiCaseInsensitiveIfInHtml
}

// ============================================================================
// 属性选择器
// ============================================================================

/// 属性选择器详细信息
/// 严格翻译自 AttrSelectorWithOptionalNamespace
public class CssAttributeSelector {
    public var name: String
    public var operator: CssAttrOperator
    public var value: String
    public var caseSensitivity: CssCaseSensitivity
    public var namespacePrefix: String
    public var neverMatches: Bool

    public init(name: String) {
        this.name = name
        this.operator = CssAttrOperator.Exists
        this.value = ""
        this.caseSensitivity = CssCaseSensitivity.CaseSensitive
        this.namespacePrefix = ""
        this.neverMatches = false
    }

    public init(name: String, operator: CssAttrOperator, value: String) {
        this.name = name
        this.operator = operator
        this.value = value
        this.caseSensitivity = CssCaseSensitivity.CaseSensitive
        this.namespacePrefix = ""
        this.neverMatches = false
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("[")
        if (namespacePrefix.length > 0) {
            sb.append("${namespacePrefix}|")
        }
        sb.append(name)
        match (operator) {
            case CssAttrOperator.Exists => ()
            case _ =>
                sb.append(operator.toString())
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
// 伪类信息
// ============================================================================

/// 伪类详细信息
public class CssPseudoClassInfo {
    public var name: String
    public var argument: String
    public var nthA: Int64
    public var nthB: Int64
    public var direction: String
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

    public func toString(): String {
        if (a == 0) { return "${b}" }
        if (a == 1 && b == 0) { return "n" }
        if (a == 1) { return "n+${b}" }
        if (a == -1 && b == 0) { return "-n" }
        if (a == -1) { return "-n+${b}" }
        if (b == 0) { return "${a}n" }
        return "${a}n+${b}"
    }

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
public class CssComponent {
    public var kind: CssComponentKind
    public var localName: String
    public var namespacePrefix: String
    public var vendorPrefix: String
    public var id: String
    public var className: String
    public var attribute: ?CssAttributeSelector
    public var pseudoClass: ?CssPseudoClassInfo
    public var pseudoElementName: String
    public var combinator: CssCombinator
    public var selectorList: ArrayList<CssComplexSelector>
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

    public static func universal(): CssComponent {
        CssComponent(CssComponentKind.Universal)
    }

    public static func type(name: String): CssComponent {
        let c = CssComponent(CssComponentKind.Type)
        c.localName = name
        return c
    }

    public static func id(id: String): CssComponent {
        let c = CssComponent(CssComponentKind.Id)
        c.id = id
        return c
    }

    public static func klass(name: String): CssComponent {
        let c = CssComponent(CssComponentKind.Class)
        c.className = name
        return c
    }

    public static func attribute(attr: CssAttributeSelector): CssComponent {
        let c = CssComponent(CssComponentKind.Attribute)
        c.attribute = Some(attr)
        return c
    }

    public static func pseudoClass(info: CssPseudoClassInfo): CssComponent {
        let c = CssComponent(CssComponentKind.PseudoClass)
        c.pseudoClass = Some(info)
        return c
    }

    public static func pseudoElement(name: String): CssComponent {
        let c = CssComponent(CssComponentKind.PseudoElement)
        c.pseudoElementName = name
        return c
    }

    public static func combinator(combinator: CssCombinator): CssComponent {
        let c = CssComponent(CssComponentKind.Combinator)
        c.combinator = combinator
        return c
    }

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
                        if (info.argument.length > 0) {
                            return ":${info.name}(${info.argument})"
                        }
                        return ":${info.name}"
                    case None => ":?"
                }
            case CssComponentKind.PseudoElement => "::${pseudoElementName}"
            case CssComponentKind.Combinator => combinator.toString()
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
// 复合选择器 / 复杂选择器
// ============================================================================

/// CSS 复杂选择器 (由组合符连接的简单选择器序列)
/// 严格翻译自 GenericSelector
public class CssComplexSelector {
    public var components: ArrayList<CssComponent>
    private var specificityCache: ?Specificity

    public init() {
        this.components = ArrayList<CssComponent>()
        this.specificityCache = None
    }

    public func addComponent(comp: CssComponent): Unit {
        components.append(comp)
        specificityCache = None
    }

    public func hasCombinator(): Bool {
        for (comp in components) {
            if (comp.kind == CssComponentKind.Combinator) {
                return true
            }
        }
        return false
    }

    /// 计算特异性
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

    public func toString(): String {
        let sb = StringBuilder()
        for (comp in components) {
            sb.append(comp.toString())
        }
        return sb.toString()
    }
}

// ============================================================================
// 选择器列表
// ============================================================================

/// CSS 选择器列表 (逗号分隔)
/// 严格翻译自 SelectorList
public class CssSelectorList {
    public var selectors: ArrayList<CssComplexSelector>

    public init() {
        this.selectors = ArrayList<CssComplexSelector>()
    }

    public func addSelector(sel: CssComplexSelector): Unit {
        selectors.append(sel)
    }

    public func length(): Int64 {
        selectors.size
    }

    public func isEmpty(): Bool {
        selectors.size == 0
    }

    public func toString(): String {
        let parts = ArrayList<String>()
        for (sel in selectors) {
            parts.append(sel.toString())
        }
        return String.join(", ", parts)
    }
}

// ============================================================================
// 特异性
// ============================================================================

/// CSS 特异性
/// 严格翻译自 Specificity struct
/// (a, b, c) = (ID选择器, 类/属性/伪类, 类型/伪元素)
public class Specificity {
    public var idSelectors: Int64
    public var classLikeSelectors: Int64
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

    public func toU32(): Int64 {
        let max10bit: Int64 = (1 << 10) - 1
        return (min(idSelectors, max10bit) << 20) |
               (min(classLikeSelectors, max10bit) << 10) |
               min(elementSelectors, max10bit)
    }

    public static func fromU32(value: Int64): Specificity {
        let max10bit: Int64 = (1 << 10) - 1
        let spec = Specificity()
        spec.idSelectors = value >> 20
        spec.classLikeSelectors = (value >> 10) & max10bit
        spec.elementSelectors = value & max10bit
        return spec
    }

    public func add(other: Specificity): Unit {
        idSelectors += other.idSelectors
        classLikeSelectors += other.classLikeSelectors
        elementSelectors += other.elementSelectors
    }

    public func compareTo(other: Specificity): Int64 {
        toU32() - other.toU32()
    }

    public func toString(): String {
        "(${idSelectors}, ${classLikeSelectors}, ${elementSelectors})"
    }

    private static func min(a: Int64, b: Int64): Int64 {
        if (a < b) { a } else { b }
    }
}

/// 计算单个组件的特异性
public func computeComponentSpecificity(comp: CssComponent, spec: Specificity): Unit {
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
            for (sel in comp.selectorList) {
                spec.add(sel.specificity())
            }
        case CssComponentKind.Type | CssComponentKind.PseudoElement |
             CssComponentKind.Slotted =>
            spec.elementSelectors += 1
            if (comp.kind == CssComponentKind.Slotted) {
                for (sel in comp.selectorList) {
                    spec.add(sel.specificity())
                }
            }
        case CssComponentKind.Host =>
            spec.classLikeSelectors += 1
            for (sel in comp.selectorList) {
                spec.add(sel.specificity())
            }
        case CssComponentKind.Universal | CssComponentKind.Combinator =>
            {}
    }
}

// ============================================================================
// 选择器解析器
// 严格翻译自: selectors/parser.zig SelectorParser
// ============================================================================

/// CSS 选择器解析器
public class CssSelectorParser {
    private var source: String
    private var pos: Int64
    private var line: Int64
    private var column: Int64
    private var errors: ArrayList<String>

    public init() {
        this.source = ""
        this.pos = 0
        this.line = 1
        this.column = 1
        this.errors = ArrayList<String>()
    }

    /// 解析选择器列表
    public func parse(input: String): ?CssSelectorList {
        this.source = input
        this.pos = 0
        this.line = 1
        this.column = 1
        this.errors = ArrayList<String>()

        let list = CssSelectorList()
        skipWhitespace()
        while (pos < source.length) {
            let sel = parseComplexSelector()
            match (sel) {
                case Some(s) => list.addSelector(s)
                case None => return None
            }
            skipWhitespace()
            if (pos < source.length && source[pos] == ',') {
                advance()
                skipWhitespace()
            } else {
                break
            }
        }
        return Some(list)
    }

    private func parseComplexSelector(): ?CssComplexSelector {
        let complex = CssComplexSelector()
        skipWhitespace()

        let compound = parseCompoundSelector()
        match (compound) {
            case Some(components) =>
                for (comp in components) {
                    complex.addComponent(comp)
                }
            case None => return None
        }

        while (pos < source.length) {
            let combinator = detectCombinator()
            if (combinator == CssCombinator.None) { break }
            complex.addComponent(CssComponent.combinator(combinator))
            skipWhitespace()

            let nextCompound = parseCompoundSelector()
            match (nextCompound) {
                case Some(components) =>
                    for (comp in components) {
                        complex.addComponent(comp)
                    }
                case None => break
            }
        }
        return Some(complex)
    }

    private func parseCompoundSelector(): ?ArrayList<CssComponent> {
        let components = ArrayList<CssComponent>()

        if (pos < source.length) {
            let c = source[pos]
            if (c == '*') {
                advance()
                components.append(CssComponent.universal())
            } else if (isIdentStart(c) || c == '-') {
                let name = readIdent()
                if (name.length > 0) {
                    components.append(CssComponent.type(name))
                }
            }
        }

        var hasMoreComponents = true
        while (hasMoreComponents && pos < source.length) {
            let c = source[pos]
            match (c) {
                case '#' =>
                    advance()
                    let name = readIdent()
                    if (name.length > 0) {
                        let comp = CssComponent(CssComponentKind.Id)
                        comp.id = name
                        components.append(comp)
                    }
                case '.' =>
                    advance()
                    let name = readIdent()
                    if (name.length > 0) {
                        components.append(CssComponent.klass(name))
                    }
                case '[' =>
                    let attrComp = parseAttributeSelectorComponent()
                    match (attrComp) {
                        case Some(comp) => components.append(comp)
                        case None => ()
                    }
                case ':' =>
                    advance()
                    if (pos < source.length && source[pos] == ':') {
                        advance()
                        let name = readIdent()
                        components.append(CssComponent.pseudoElement(name))
                    } else {
                        let pseudoComp = parsePseudoClassComponent()
                        match (pseudoComp) {
                            case Some(comp) => components.append(comp)
                            case None => ()
                        }
                    }
                case _ =>
                    hasMoreComponents = false
            }
        }

        if (components.size == 0) {
            return None
        }
        return Some(components)
    }

    private func parseAttributeSelectorComponent(): ?CssComponent {
        if (pos >= source.length || source[pos] != '[') {
            return None
        }
        advance()
        skipWhitespace()
        let attrName = readIdent()
        skipWhitespace()

        if (pos < source.length && source[pos] == ']') {
            advance()
            return Some(CssComponent.attribute(CssAttributeSelector(attrName)))
        }

        let op = readAttrOperator()
        skipWhitespace()
        var value = ""
        if (pos < source.length && (source[pos] == '"' || source[pos] == '\'')) {
            value = readString()
        } else {
            value = readIdent()
        }
        skipWhitespace()

        var caseSensitivity = CssCaseSensitivity.CaseSensitive
        if (pos < source.length) {
            let flag = source[pos]
            if (flag == 'i' || flag == 'I') {
                caseSensitivity = CssCaseSensitivity.AsciiCaseInsensitive
                advance()
                skipWhitespace()
            } else if (flag == 's' || flag == 'S') {
                caseSensitivity = CssCaseSensitivity.ExplicitCaseSensitive
                advance()
                skipWhitespace()
            }
        }

        if (pos < source.length && source[pos] == ']') {
            advance()
        }

        let attr = CssAttributeSelector(attrName, op, value)
        attr.caseSensitivity = caseSensitivity
        return Some(CssComponent.attribute(attr))
    }

    private func parsePseudoClassComponent(): ?CssComponent {
        let name = readIdent()
        if (name.length == 0) { return None }

        let info = CssPseudoClassInfo(name)

        if (pos < source.length && source[pos] == '(') {
            advance()
            let arg = readParenthesizedContent()
            info.argument = arg.trim()

            if (name == "nth-child" || name == "nth-of-type" ||
                name == "nth-last-child" || name == "nth-last-of-type") {
                let nth = parseNthExpression(info.argument)
                match (nth) {
                    case Some(expr) => info.nthA = expr.a; info.nthB = expr.b
                    case None => ()
                }
            }
        }

        let kind = mapPseudoClassToKind(name)
        let comp = CssComponent(kind)
        comp.pseudoClass = Some(info)
        return Some(comp)
    }

    private static func mapPseudoClassToKind(name: String): CssComponentKind {
        match (name.toLowerCase()) {
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

    private func detectCombinator(): CssCombinator {
        skipWhitespace()
        if (pos >= source.length) { return CssCombinator.None }
        if (source[pos] == '{' || source[pos] == ',' || source[pos] == '}') {
            return CssCombinator.None
        }

        let c = source[pos]
        if (c == '>') { advance(); skipWhitespace(); return CssCombinator.Child }
        if (c == '+') { advance(); skipWhitespace(); return CssCombinator.AdjacentSibling }
        if (c == '~') { advance(); skipWhitespace(); return CssCombinator.GeneralSibling }

        if (c == ' ' || c == '\t' || c == '\n') {
            skipWhitespace()
            if (pos < source.length && source[pos] != '{' && source[pos] != ',' && source[pos] != '}') {
                return CssCombinator.Descendant
            }
        }
        return CssCombinator.None
    }

    private static func parseNthExpression(input: String): ?NthExpression {
        let s = input.trim().toLowerCase()
        if (s == "odd") { return Some(NthExpression(2, 1)) }
        if (s == "even") { return Some(NthExpression(2, 0)) }

        var a: Int64 = 0
        var b: Int64 = 0
        var i: Int64 = 0

        if (i < s.length && s[i] == '-') {
            i++
            let numStart = i
            while (i < s.length && s[i] >= '0' && s[i] <= '9') { i++ }
            if (i < s.length && s[i] == 'n') {
                a = if (i > numStart) { -parseInt(s, numStart, i) } else { -1 }
                i++
            } else {
                return Some(NthExpression(0, -parseInt(s, numStart, i)))
            }
        } else {
            let numStart = i
            if (i < s.length && s[i] == '+') { i++ }
            while (i < s.length && s[i] >= '0' && s[i] <= '9') { i++ }
            if (i < s.length && s[i] == 'n') {
                a = if (i > numStart) { parseInt(s, numStart, i) } else { 1 }
                i++
            } else {
                return Some(NthExpression(0, parseInt(s, numStart, i)))
            }
        }

        if (i < s.length) {
            if (s[i] == '+') {
                i++
                let numStart = i
                while (i < s.length && s[i] >= '0' && s[i] <= '9') { i++ }
                b = parseInt(s, numStart, i)
            } else if (s[i] == '-') {
                i++
                let numStart = i
                while (i < s.length && s[i] >= '0' && s[i] <= '9') { i++ }
                b = -parseInt(s, numStart, i)
            }
        }
        return Some(NthExpression(a, b))
    }

    private static func parseInt(s: String, start: Int64, end: Int64): Int64 {
        var result: Int64 = 0
        var i = start
        while (i < end) {
            result = result * 10 + Int64(s[i] - '0')
            i++
        }
        return result
    }

    // ========================================================================
    // 词法辅助
    // ========================================================================

    private func readIdent(): String {
        let sb = StringBuilder()
        while (pos < source.length) {
            let c = source[pos]
            if (isIdentChar(c)) {
                sb.append(c)
                advance()
            } else if (c == '\\' && pos + 1 < source.length && source[pos + 1] != '\n') {
                advance()
                sb.append(advance())
            } else {
                break
            }
        }
        return sb.toString()
    }

    private func readString(): String {
        if (pos >= source.length) { return "" }
        let quote = source[pos]
        advance()
        let sb = StringBuilder()
        while (pos < source.length) {
            if (source[pos] == quote) {
                advance()
                break
            }
            if (source[pos] == '\\' && pos + 1 < source.length) {
                advance()
                sb.append(advance())
                continue
            }
            sb.append(advance())
        }
        return sb.toString()
    }

    private func readAttrOperator(): CssAttrOperator {
        if (pos >= source.length) { return CssAttrOperator.Exists }
        let c = source[pos]
        let next = if (pos + 1 < source.length) { source[pos + 1] } else { UInt8(0) }

        if (next == '=') {
            advance()
            advance()
            match (c) {
                case '~' => return CssAttrOperator.Includes
                case '|' => return CssAttrOperator.DashMatch
                case '^' => return CssAttrOperator.Prefix
                case '$' => return CssAttrOperator.Suffix
                case '*' => return CssAttrOperator.Substring
                case _ => return CssAttrOperator.Equal
            }
        }
        if (c == '=') {
            advance()
            return CssAttrOperator.Equal
        }
        return CssAttrOperator.Exists
    }

    private func readParenthesizedContent(): String {
        if (pos >= source.length || source[pos] != '(') { return "" }
        advance()
        let sb = StringBuilder()
        var depth: Int64 = 1
        while (pos < source.length && depth > 0) {
            if (source[pos] == '(') { depth++ }
            if (source[pos] == ')') {
                depth--
                if (depth == 0) { advance(); break }
            }
            if (depth > 0) {
                sb.append(source[pos])
                advance()
            }
        }
        return sb.toString()
    }

    private func advance(): Unit {
        if (pos < source.length) {
            if (source[pos] == '\n') {
                line++
                column = 1
            } else {
                column++
            }
            pos++
        }
    }

    private func skipWhitespace(): Unit {
        while (pos < source.length) {
            let c = source[pos]
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                advance()
            } else {
                break
            }
        }
    }

    private static func isIdentStart(c: UInt8): Bool {
        (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
    }

    private static func isIdentChar(c: UInt8): Bool {
        (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '-' || c == '_'
    }
}

// ============================================================================
// 选择器序列化
// 严格翻译自: selectors/serialize.zig
// ============================================================================

/// CSS 选择器序列化器
/// 严格翻译自 serialize 模块中的 serialize_selector_list 等函数
public class CssSelectorSerializer {
    /// 序列化选择器列表
    /// 严格翻译自 serialize_selector_list
    public static func serializeSelectorList(list: CssSelectorList): String {
        let parts = ArrayList<String>()
        for (sel in list.selectors) {
            parts.append(serializeComplexSelector(sel))
        }
        return String.join(", ", parts)
    }

    /// 序列化复杂选择器
    private static func serializeComplexSelector(sel: CssComplexSelector): String {
        let sb = StringBuilder()
        for (comp in sel.components) {
            sb.append(serializeComponent(comp))
        }
        return sb.toString()
    }

    /// 序列化组件
    private static func serializeComponent(comp: CssComponent): String {
        match (comp.kind) {
            case CssComponentKind.Universal => "*"
            case CssComponentKind.Type => comp.localName
            case CssComponentKind.Id => "#${comp.id}"
            case CssComponentKind.Class => ".${comp.className}"
            case CssComponentKind.Combinator => comp.combinator.toString()
            case CssComponentKind.Root => ":root"
            case CssComponentKind.Empty => ":empty"
            case CssComponentKind.Scope => ":scope"
            case CssComponentKind.PseudoElement => "::${comp.pseudoElementName}"
            case CssComponentKind.Negation => ":not(${serializeSubSelectorList(comp.selectorList)})"
            case CssComponentKind.Is => ":is(${serializeSubSelectorList(comp.selectorList)})"
            case CssComponentKind.Where => ":where(${serializeSubSelectorList(comp.selectorList)})"
            case CssComponentKind.Has => ":has(${serializeSubSelectorList(comp.selectorList)})"
            case CssComponentKind.Attribute =>
                match (comp.attribute) {
                    case Some(attr) => attr.toString()
                    case None => "[]"
                }
            case CssComponentKind.PseudoClass =>
                match (comp.pseudoClass) {
                    case Some(info) =>
                        if (info.argument.length > 0) {
                            return ":${info.name}(${info.argument})"
                        }
                        return ":${info.name}"
                    case None => ":?"
                }
            case _ => ""
        }
    }

    /// 序列化子选择器列表
    private static func serializeSubSelectorList(selectors: ArrayList<CssComplexSelector>): String {
        let parts = ArrayList<String>()
        for (sel in selectors) {
            parts.append(serializeComplexSelector(sel))
        }
        return String.join(", ", parts)
    }
}

// ============================================================================
// 选择器兼容性检查
// 严格翻译自: selectors/selector.zig isCompatible
// ============================================================================

/// 检查选择器列表是否兼容目标
/// 严格翻译自 isCompatible 函数
public func isSelectorCompatible(selectors: ArrayList<CssComplexSelector>): Bool {
    // 简化实现: 总是返回 true
    // 完整实现需要检查每个组件的浏览器兼容性
    true
}
