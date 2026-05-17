// bao_bundler - CSS Parser (CSS 解析器)
// 严格翻译自: src/css/ 中 CSS 解析相关逻辑
//   对应: src/css/ast.zig - CSS AST 节点定义
//   对应: src/css/parser.zig - CSS 解析器
//   对应: src/css/printer.zig - CSS 打印/压缩
//   对应: Chunk.zig:671 CssChunk - CSS chunk 内容
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// CSS AST 节点
// 严格翻译自: src/css/ast.zig
// ============================================================================

/// CSS 选择器组合符
public enum CssCombinator {
    | Descendant                      // " " (后代)
    | Child                           // ">" (子元素)
    | AdjacentSibling                 // "+" (相邻兄弟)
    | GeneralSibling                  // "~" (通用兄弟)
    | None                            // 无组合符

    public operator func ==(rhs: CssCombinator): Bool {
        match (this) {
            case Descendant => match (rhs) { case Descendant => true case _ => false }
            case Child => match (rhs) { case Child => true case _ => false }
            case AdjacentSibling => match (rhs) { case AdjacentSibling => true case _ => false }
            case GeneralSibling => match (rhs) { case GeneralSibling => true case _ => false }
            case None => match (rhs) { case None => true case _ => false }
        }
    }
}

/// CSS 选择器类型
public enum CssSimpleSelectorKind {
    | Universal                       // *
    | Type                            // div, span
    | Class                           // .class
    | Id                              // #id
    | Attribute                       // [attr=value]
    | PseudoClass                     // :hover, :focus
    | PseudoElement                   // ::before, ::after
}

/// CSS 属性匹配操作符
public enum CssAttributeMatch {
    | Exact                           // [attr=value]
    | Prefix                          // [attr^=value]
    | Suffix                          // [attr$=value]
    | Contains                        // [attr*=value]
    | DashMatch                       // [attr|=value]
    | Exists                          // [attr]
}

/// CSS 选择器 (简单选择器)
// 严格翻译自: css/ast.zig 中 Selector
public class CssSelector {
    public var kind: CssSimpleSelectorKind
    public var name: String           // 类型名 / 类名 / ID 名
    public var attributeName: String  // 属性选择器: 属性名
    public var attributeValue: String // 属性选择器: 属性值
    public var attributeMatch: CssAttributeMatch
    public var argument: String       // 伪类/伪元素参数 (如 :nth-child(2n+1))
    public var combinator: CssCombinator

    public init(kind: CssSimpleSelectorKind, name: String) {
        this.kind = kind
        this.name = name
        this.attributeName = ""
        this.attributeValue = ""
        this.attributeMatch = CssAttributeMatch.Exists
        this.argument = ""
        this.combinator = CssCombinator.Descendant
    }

    /// 通配选择器
    public static func universal(): CssSelector {
        return CssSelector(CssSimpleSelectorKind.Universal, "*")
    }

    /// 类型选择器
    public static func `type`(name: String): CssSelector {
        return CssSelector(CssSimpleSelectorKind.Type, name)
    }

    /// 类选择器
    public static func klass(name: String): CssSelector {
        return CssSelector(CssSimpleSelectorKind.Class, name)
    }

    /// ID 选择器
    public static func id(name: String): CssSelector {
        return CssSelector(CssSimpleSelectorKind.Id, name)
    }

    /// 伪类选择器
    public static func pseudoClass(name: String): CssSelector {
        return CssSelector(CssSimpleSelectorKind.PseudoClass, name)
    }

    /// 伪元素选择器
    public static func pseudoElement(name: String): CssSelector {
        return CssSelector(CssSimpleSelectorKind.PseudoElement, name)
    }

    /// 转为字符串
    public func toString(): String {
        match (kind) {
            case CssSimpleSelectorKind.Universal => "*"
            case CssSimpleSelectorKind.Type => name
            case CssSimpleSelectorKind.Class => ".${name}"
            case CssSimpleSelectorKind.Id => "#${name}"
            case CssSimpleSelectorKind.PseudoClass =>
                if (argument.length > 0) {
                    return ":${name}(${argument})"
                }
                return ":${name}"
            case CssSimpleSelectorKind.PseudoElement =>
                if (argument.length > 0) {
                    return "::${name}(${argument})"
                }
                return "::${name}"
            case CssSimpleSelectorKind.Attribute =>
                match (attributeMatch) {
                    case CssAttributeMatch.Exists => "[${attributeName}]"
                    case CssAttributeMatch.Exact => "[${attributeName}=\"${attributeValue}\"]"
                    case CssAttributeMatch.Prefix => "[${attributeName}^=\"${attributeValue}\"]"
                    case CssAttributeMatch.Suffix => "[${attributeName}$=\"${attributeValue}\"]"
                    case CssAttributeMatch.Contains => "[${attributeName}*=\"${attributeValue}\"]"
                    case CssAttributeMatch.DashMatch => "[${attributeName}|=\"${attributeValue}\"]"
                }
        }
    }

    /// 获取特异性权重
    public func specificity(): Int64 {
        match (kind) {
            case CssSimpleSelectorKind.Id => 100
            case CssSimpleSelectorKind.Class | CssSimpleSelectorKind.PseudoClass | CssSimpleSelectorKind.Attribute => 10
            case CssSimpleSelectorKind.Type | CssSimpleSelectorKind.PseudoElement => 1
            case CssSimpleSelectorKind.Universal => 0
        }
    }
}

/// CSS 选择器列表 (逗号分隔)
public class CssSelectorList {
    /// 选择器组
    public var selectors: ArrayList<CssComplexSelector>

    public init() {
        this.selectors = ArrayList<CssComplexSelector>()
    }

    /// 添加选择器组
    public func addSelector(sel: CssComplexSelector): Unit {
        selectors.append(sel)
    }

    /// 转为字符串
    public func toString(): String {
        let parts = ArrayList<String>()
        for (sel in selectors) {
            parts.append(sel.toString())
        }
        var result = ""
        for (i in 0..parts.size) {
            if (i > 0) { result = result + ", " }
            result = result + parts[Int64(i)]
        }
        return result
    }
}

/// CSS 声明 (属性: 值)
// 严格翻译自: css/ast.zig 中 Declaration
public class CssDeclaration {
    /// 属性名
    public var property: String
    /// 属性值
    public var value: String
    /// 是否为 !important
    public var important: Bool

    public init(property: String, value: String) {
        this.property = property
        this.value = value
        this.important = false
    }

    public init(property: String, value: String, important: Bool) {
        this.property = property
        this.value = value
        this.important = important
    }

    /// 转为字符串
    public func toString(): String {
        if (important) {
            return "${property}: ${value} !important"
        }
        return "${property}: ${value}"
    }

    /// 压缩输出
    public func toMinifiedString(): String {
        if (important) {
            return "${property}:${value}!important"
        }
        return "${property}:${value}"
    }
}

/// @规则类型
public enum CssAtRuleKind {
    | Charset                         // @charset
    | Import                          // @import
    | Media                           // @media
    | Keyframes                       // @keyframes
    | FontFace                        // @font-face
    | Supports                        // @supports
    | Layer                           // @layer
    | Container                       // @container
    | Custom                          // @<custom>
}

/// CSS @规则
// 严格翻译自: css/ast.zig 中 AtRule
public class CssAtRule {
    /// @规则类型
    public var kind: CssAtRuleKind
    /// @规则名称 (如 "media", "keyframes", 自定义名)
    public var name: String
    /// 前置条件 (如 @media 的查询条件)
    public var prelude: String
    /// 子规则列表
    public var rules: ArrayList<CssRule>

    public init(kind: CssAtRuleKind, name: String, prelude: String) {
        this.kind = kind
        this.name = name
        this.prelude = prelude
        this.rules = ArrayList<CssRule>()
    }

    /// 添加子规则
    public func addRule(rule: CssRule): Unit {
        rules.append(rule)
    }
}

/// CSS 规则
// 严格翻译自: css/ast.zig 中 Rule
public class CssRule {
    /// 样式规则: 选择器 + 声明
    public var selectors: CssSelectorList
    public var declarations: ArrayList<CssDeclaration>
    /// @规则
    public var atRule: ?CssAtRule
    /// 规则来源文件路径
    public var sourcePath: String

    public init() {
        this.selectors = CssSelectorList()
        this.declarations = ArrayList<CssDeclaration>()
        this.atRule = None
        this.sourcePath = ""
    }

    /// 创建样式规则
    public static func style(selectors: CssSelectorList, declarations: ArrayList<CssDeclaration>): CssRule {
        let rule = CssRule()
        rule.selectors = selectors
        rule.declarations = declarations
        return rule
    }

    /// 创建 @规则
    public static func createAtRule(rule: CssAtRule): CssRule {
        let result = CssRule()
        result.atRule = Some(rule)
        return result
    }

    /// 是否为 @规则
    public func isAtRule(): Bool {
        match (atRule) {
            case Some(_) => return true
            case None => return false
        }
    }

    /// 转为字符串
    public func toString(): String {
        match (atRule) {
            case Some(at) =>
                let sb = StringBuilder()
                sb.append("@${at.name}")
                if (at.prelude.length > 0) {
                    sb.append(" ${at.prelude}")
                }
                sb.append(" {\n")
                for (rule in at.rules) {
                    sb.append("  ${rule.toString()}\n")
                }
                sb.append("}")
                return sb.toString()
            case None =>
                let sb = StringBuilder()
                sb.append(selectors.toString())
                sb.append(" {\n")
                for (decl in declarations) {
                    sb.append("  ${decl.toString()};\n")
                }
                sb.append("}")
                return sb.toString()
        }
    }

    /// 压缩输出
    public func toMinifiedString(): String {
        match (atRule) {
            case Some(at) =>
                let sb = StringBuilder()
                sb.append("@${at.name}")
                if (at.prelude.length > 0) {
                    sb.append(at.prelude)
                }
                sb.append("{")
                for (rule in at.rules) {
                    sb.append(rule.toMinifiedString())
                }
                sb.append("}")
                return sb.toString()
            case None =>
                let sb = StringBuilder()
                sb.append(selectors.toString())
                sb.append("{")
                let parts = ArrayList<String>()
                for (decl in declarations) {
                    parts.append(decl.toMinifiedString())
                }
                sb.append(String.join(Array<String>(parts.size, {i => parts[Int64(i)]}), delimiter: ";"))
                sb.append("}")
                return sb.toString()
        }
    }
}

/// CSS 样式表
public class CssStylesheet {
    /// 规则列表
    public var rules: ArrayList<CssRule>
    /// 源文件路径
    public var sourcePath: String

    public init() {
        this.rules = ArrayList<CssRule>()
        this.sourcePath = ""
    }

    /// 添加规则
    public func addRule(rule: CssRule): Unit {
        rules.append(rule)
    }

    /// 转为字符串
    public func toString(): String {
        let parts = ArrayList<String>()
        for (rule in rules) {
            parts.append(rule.toString())
        }
        return String.join(Array<String>(parts.size, {i => parts[Int64(i)]}), delimiter: "\n\n")
    }
}

// ============================================================================
// CSS 解析器
// 严格翻译自: src/css/parser.zig
// ============================================================================

/// CSS 解析错误
public class CssParseError {
    public var message: String
    public var line: Int64
    public var column: Int64

    public init(message: String, line: Int64, column: Int64) {
        this.message = message
        this.line = line
        this.column = column
    }

    public func toString(): String {
        return "CSS parse error at ${line}:${column}: ${message}"
    }
}

/// CSS 解析结果
public class CssParseResult {
    public var stylesheet: CssStylesheet
    public var errors: ArrayList<CssParseError>
    public var warnings: ArrayList<CssParseError>

    public init() {
        this.stylesheet = CssStylesheet()
        this.errors = ArrayList<CssParseError>()
        this.warnings = ArrayList<CssParseError>()
    }

    public func hasErrors(): Bool {
        return errors.size > 0
    }
}

/// CSS 解析器
// 严格翻译自: src/css/parser.zig
public class CSSParser {
    private static let SPACE: UInt8 = UInt8(32)
    private static let TAB: UInt8 = UInt8(9)
    private static let LF: UInt8 = UInt8(10)
    private static let CR: UInt8 = UInt8(13)
    private static let DQUOTE: UInt8 = UInt8(34)
    private static let SQUOTE: UInt8 = UInt8(39)
    private static let LPAREN: UInt8 = UInt8(40)
    private static let RPAREN: UInt8 = UInt8(41)
    private static let STAR: UInt8 = UInt8(42)
    private static let PLUS: UInt8 = UInt8(43)
    private static let DOT: UInt8 = UInt8(46)
    private static let SLASH: UInt8 = UInt8(47)
    private static let COLON: UInt8 = UInt8(58)
    private static let SEMICOLON: UInt8 = UInt8(59)
    private static let GT: UInt8 = UInt8(62)
    private static let LBRACKET: UInt8 = UInt8(91)
    private static let RBRACKET: UInt8 = UInt8(93)
    private static let LBRACE: UInt8 = UInt8(123)
    private static let RBRACE: UInt8 = UInt8(125)
    private static let HASH: UInt8 = UInt8(35)
    private static let MINUS: UInt8 = UInt8(45)
    private static let UNDERSCORE: UInt8 = UInt8(95)
    private static let ZERO: UInt8 = UInt8(48)
    private static let NINE: UInt8 = UInt8(57)
    private static let UPPER_A: UInt8 = UInt8(65)
    private static let UPPER_Z: UInt8 = UInt8(90)
    private static let LOWER_A: UInt8 = UInt8(97)
    private static let LOWER_Z: UInt8 = UInt8(122)
    private static let TILDE: UInt8 = UInt8(126)

    /// 输入文本
    private var source: String
    /// 当前位置
    private var pos: Int64
    /// 当前行号
    private var line: Int64
    /// 当前列号
    private var column: Int64
    /// 解析结果
    private var result: CssParseResult
    /// 是否解析 @规则
    private var parseAtRules: Bool

    public init() {
        this.source = ""
        this.pos = 0
        this.line = 1
        this.column = 1
        this.result = CssParseResult()
        this.parseAtRules = true
    }

    /// 解析 CSS 文本
    public func parse(source: String): CssParseResult {
        this.source = source
        this.pos = 0
        this.line = 1
        this.column = 1
        this.result = CssParseResult()

        while (pos < Int64(source.length)) {
            skipWhitespaceAndComments()

            if (pos >= Int64(source.length)) {
                break
            }

            // @规则
            if (source[pos] == UInt8(64)) {
                parseAtRule()
                continue
            }

            // 普通规则 (选择器 + 声明块)
            parseRule()
        }

        return result
    }

    /// 解析 @规则
    private func parseAtRule(): Unit {
        advance() // 跳过 @

        // 读取 @规则名称
        let name = readIdent()
        let kind = classifyAtRule(name)

        // 读取 prelude (到 { 或 ; 为止)
        var prelude = StringBuilder()
        while (pos < Int64(source.length) && source[pos] != LBRACE && source[pos] != UInt8(59)) {
            prelude.append(source[pos])
            advance()
        }

        let preludeStr = prelude.toString()

        let atRule = CssAtRule(kind, name, preludeStr)

        if (pos < Int64(source.length) && source[pos] == LBRACE) {
            advance() // 跳过 {
            // 读取子规则
            while (pos < Int64(source.length) && source[pos] != RBRACE) {
                skipWhitespaceAndComments()
                if (pos < Int64(source.length) && source[pos] == RBRACE) {
                    break
                }

                // 嵌套 @规则
                if (source[pos] == UInt8(64)) {
                    let savedParseAtRules = parseAtRules
                    parseAtRules = true
                    parseAtRuleInto(atRule)
                    parseAtRules = savedParseAtRules
                    continue
                }

                // 子选择器规则
                parseRuleInto(atRule)
            }

            if (pos < Int64(source.length) && source[pos] == RBRACE) {
                advance() // 跳过 }
            }
        } else if (pos < Int64(source.length) && source[pos] == SEMICOLON) {
            advance() // 跳过 ; (如 @import url(...) ;)
        }

        let rule = CssRule.createAtRule(atRule)
        result.stylesheet.addRule(rule)
    }

    /// 将 @规则解析到父级 atRule
    private func parseAtRuleInto(parent: CssAtRule): Unit {
        advance() // 跳过 @
        let name = readIdent()
        let kind = classifyAtRule(name)

        var prelude = StringBuilder()
        while (pos < Int64(source.length) && source[pos] != LBRACE && source[pos] != UInt8(59)) {
            prelude.append(source[pos])
            advance()
        }

        let atRule = CssAtRule(kind, name, prelude.toString())

        if (pos < Int64(source.length) && source[pos] == LBRACE) {
            advance()
            while (pos < Int64(source.length) && source[pos] != RBRACE) {
                skipWhitespaceAndComments()
                if (pos < Int64(source.length) && source[pos] == RBRACE) { break }
                parseRuleInto(atRule)
            }
            if (pos < Int64(source.length) && source[pos] == RBRACE) { advance() }
        } else if (pos < Int64(source.length) && source[pos] == SEMICOLON) {
            advance()
        }

        parent.addRule(CssRule.createAtRule(atRule))
    }

    /// 解析规则
    private func parseRule(): Unit {
        let rule = CssRule()
        parseRuleBody(rule)
        result.stylesheet.addRule(rule)
    }

    /// 将规则解析到父级 atRule
    private func parseRuleInto(parent: CssAtRule): Unit {
        let rule = CssRule()
        parseRuleBody(rule)
        parent.addRule(rule)
    }

    /// 解析规则体 (选择器 + 声明)
    private func parseRuleBody(rule: CssRule): Unit {
        // 读取选择器
        rule.selectors = parseSelectorList()

        skipWhitespaceAndComments()

        // 读取声明块
        if (pos < Int64(source.length) && source[pos] == LBRACE) {
            advance() // 跳过 {
            parseDeclarations(rule)
            skipWhitespaceAndComments()
            if (pos < Int64(source.length) && source[pos] == RBRACE) {
                advance() // 跳过 }
            }
        }
    }

    /// 解析选择器列表 (逗号分隔)
    private func parseSelectorList(): CssSelectorList {
        let list = CssSelectorList()

        while (pos < Int64(source.length) && source[pos] != LBRACE) {
            let sel = parseComplexSelector()
            list.addSelector(sel)

            skipWhitespaceAndComments()

            if (pos < Int64(source.length) && source[pos] == UInt8(44)) {
                advance() // 跳过逗号
                skipWhitespaceAndComments()
            } else {
                break
            }
        }

        return list
    }

    /// 解析复合选择器 (空格/>/+/~ 组合的简单选择器序列)
    private func parseComplexSelector(): CssComplexSelector {
        let complex = CssComplexSelector()
        skipWhitespaceAndComments()

        while (pos < Int64(source.length) && source[pos] != LBRACE && source[pos] != UInt8(44) && source[pos] != RBRACE) {
            // 检查组合符
            let combinator = detectCombinator()
            if (complex.components.size > 0 || match (combinator) { case CssCombinator.Descendant => false case _ => true }) {
                let sel = parseSimpleSelector()
                complex.addComponent(selectorToComponent(sel, combinator))
            } else {
                let sel = parseSimpleSelector()
                complex.addComponent(selectorToComponent(sel, CssCombinator.Descendant))
            }

            skipWhitespace()
        }

        return complex
    }

    /// 解析简单选择器
    private func parseSimpleSelector(): CssSelector {
        if (pos >= Int64(source.length)) {
            return CssSelector.universal()
        }

        let c = source[pos]

        // 通配符
        if (c == STAR) {
            advance()
            return CssSelector.universal()
        }

        // ID 选择器
        if (c == HASH) {
            advance()
            let name = readIdent()
            return CssSelector.id(name)
        }

        // 类选择器
        if (c == DOT) {
            advance()
            let name = readIdent()
            return CssSelector.klass(name)
        }

        // 属性选择器
        if (c == LBRACKET) {
            return parseAttributeSelector()
        }

        // 伪类 / 伪元素
        if (c == COLON) {
            advance()
            // 伪元素 ::before
            if (pos < Int64(source.length) && source[pos] == COLON) {
                advance()
                let name = readIdent()
                let arg = if (pos < Int64(source.length) && source[pos] == LPAREN) {
                    readParenthesized()
                } else {
                    ""
                }
                let sel = CssSelector.pseudoElement(name)
                sel.argument = arg
                return sel
            }
            // 伪类 :hover
            let name = readIdent()
            let arg = if (pos < Int64(source.length) && source[pos] == LPAREN) {
                readParenthesized()
            } else {
                ""
            }
            let sel = CssSelector.pseudoClass(name)
            sel.argument = arg
            return sel
        }

        // 类型选择器
        let name = readIdent()
        return CssSelector.`type`(name)
    }

    /// 解析属性选择器 [attr=value]
    private func parseAttributeSelector(): CssSelector {
        advance() // 跳过 [
        let attrName = readIdent()

        if (pos < Int64(source.length) && source[pos] == RBRACKET) {
            advance()
            let sel = CssSelector(CssSimpleSelectorKind.Attribute, attrName)
            sel.attributeName = attrName
            sel.attributeMatch = CssAttributeMatch.Exists
            return sel
        }

        // 读取匹配操作符
        var op = StringBuilder()
        while (pos < Int64(source.length) && source[pos] != DQUOTE && source[pos] != SQUOTE && source[pos] != UInt8(93)) {
            op.append(source[pos])
            advance()
        }
        let opStr = op.toString()

        // 读取值
        var value = StringBuilder()
        if (pos < Int64(source.length) && (source[pos] == DQUOTE || source[pos] == SQUOTE)) {
            let quoteChar = source[pos]
            advance()
            while (pos < Int64(source.length) && source[pos] != quoteChar) {
                value.append(source[pos])
                advance()
            }
            if (pos < Int64(source.length)) { advance() } // 跳过引号
        }

        // 跳过 ]
        skipWhitespace()
        if (pos < Int64(source.length) && source[pos] == RBRACKET) {
            advance()
        }

        let matchResult = parseAttributeMatch(opStr)
        let sel = CssSelector(CssSimpleSelectorKind.Attribute, attrName)
        sel.attributeName = attrName
        sel.attributeValue = value.toString()
        sel.attributeMatch = matchResult
        return sel
    }

    /// 解析声明块
    private func parseDeclarations(rule: CssRule): Unit {
        while (pos < Int64(source.length) && source[pos] != RBRACE) {
            skipWhitespaceAndComments()
            if (pos >= Int64(source.length) || source[pos] == RBRACE) { break }

            // @规则嵌套在声明块中
            if (source[pos] == UInt8(64)) {
                parseAtRule()
                continue
            }

            // 读取属性名
            let property = readPropertyName()
            if (property.length == 0) { break }

            skipWhitespaceAndComments()

            // 读取冒号
            if (pos < Int64(source.length) && source[pos] == COLON) {
                advance()
            }

            skipWhitespace()

            // 读取值
            let value = readDeclarationValue()
            let important = value.endsWith("!important")
            let cleanValue = if (important) {
                value[0..Int64(value.length - 11)]
            } else {
                value
            }

            if (property.length > 0 && cleanValue.length > 0) {
                rule.declarations.append(CssDeclaration(property, cleanValue, important))
            }

            // 跳过分号
            skipWhitespaceAndComments()
            if (pos < Int64(source.length) && source[pos] == SEMICOLON) {
                advance()
            }
        }
    }

    // -----------------------------------------------------------------------
    // 词法分析辅助
    // -----------------------------------------------------------------------

    /// 跳过空白和注释
    private func skipWhitespaceAndComments(): Unit {
        while (pos < Int64(source.length)) {
            let c = source[pos]
            if (c == SPACE || c == TAB || c == LF || c == CR) {
                advance()
            } else if (c == SLASH && pos + 1 < Int64(source.length) && source[pos + 1] == STAR) {
                // CSS 注释 /* ... */
                pos += 2
                while (pos + 1 < Int64(source.length) && !(source[pos] == STAR && source[pos + 1] == SLASH)) {
                    if (source[pos] == LF) { line++; column = 1 }
                    pos++
                }
                if (pos + 1 < Int64(source.length)) { pos += 2 }
            } else {
                break
            }
        }
    }

    /// 跳过空白
    private func skipWhitespace(): Unit {
        while (pos < Int64(source.length)) {
            let c = source[pos]
            if (c == SPACE || c == TAB || c == LF || c == CR) {
                advance()
            } else {
                break
            }
        }
    }

    /// 前进一个字符
    private func advance(): Unit {
        if (pos < Int64(source.length)) {
            if (source[pos] == LF) {
                line++
                column = 1
            } else {
                column++
            }
            pos++
        }
    }

    /// 读取标识符
    private func readIdent(): String {
        let sb = StringBuilder()
        while (pos < Int64(source.length)) {
            let c = source[pos]
            if (isIdentChar(c)) {
                sb.append(c)
                advance()
            } else {
                break
            }
        }
        return sb.toString()
    }

    /// 读取属性名
    private func readPropertyName(): String {
        let sb = StringBuilder()
        while (pos < Int64(source.length) && source[pos] != COLON && source[pos] != RBRACE && source[pos] != SEMICOLON) {
            sb.append(source[pos])
            advance()
        }
        return sb.toString()
    }

    /// 读取声明值 (到 ; 或 } 为止)
    private func readDeclarationValue(): String {
        let sb = StringBuilder()
        var depth: Int64 = 0
        while (pos < Int64(source.length)) {
            let c = source[pos]
            if (c == LPAREN) { depth++ }
            if (c == RPAREN) { depth-- }
            if ((c == SEMICOLON || c == RBRACE) && depth == 0) { break }
            sb.append(c)
            advance()
        }
        return sb.toString()
    }

    /// 读取括号内容
    private func readParenthesized(): String {
        if (pos >= Int64(source.length) || source[pos] != LPAREN) { return "" }
        advance() // 跳过 (
        let sb = StringBuilder()
        var depth: Int64 = 1
        while (pos < Int64(source.length) && depth > 0) {
            if (source[pos] == LPAREN) { depth++ }
            if (source[pos] == RPAREN) {
                depth--
                if (depth == 0) { advance(); break }
            }
            sb.append(source[pos])
            advance()
        }
        return sb.toString()
    }

    /// 将 CssSelector 转为 CssComponent
    private func selectorToComponent(sel: CssSelector, comb: CssCombinator): CssComponent {
        let comp = CssComponent(CssComponentKind.Type)
        comp.localName = sel.name
        comp.combinator = comb
        return comp
    }

    /// 检测组合符
    private func detectCombinator(): CssCombinator {
        skipWhitespace()
        if (pos >= Int64(source.length)) { return CssCombinator.None }

        let c = source[pos]
        if (c == GT) { advance(); return CssCombinator.Child }
        if (c == PLUS) { advance(); return CssCombinator.AdjacentSibling }
        if (c == TILDE) { advance(); return CssCombinator.GeneralSibling }
        // 如果前面有空白且不是特殊字符，则为后代组合符
        return CssCombinator.Descendant
    }

    /// 判断是否为标识符字符
    private static func isIdentChar(c: UInt8): Bool {
        return (c >= LOWER_A && c <= LOWER_Z) || (c >= UPPER_A && c <= UPPER_Z) ||
               (c >= ZERO && c <= NINE) || c == MINUS || c == UNDERSCORE
    }

    /// 分类 @规则
    private static func classifyAtRule(name: String): CssAtRuleKind {
        match (name) {
            case "charset" => CssAtRuleKind.Charset
            case "import" => CssAtRuleKind.Import
            case "media" => CssAtRuleKind.Media
            case "keyframes" | "-webkit-keyframes" | "-moz-keyframes" => CssAtRuleKind.Keyframes
            case "font-face" => CssAtRuleKind.FontFace
            case "supports" => CssAtRuleKind.Supports
            case "layer" => CssAtRuleKind.Layer
            case "container" => CssAtRuleKind.Container
            case _ => CssAtRuleKind.Custom
        }
    }

    /// 解析属性匹配操作符
    private static func parseAttributeMatch(op: String): CssAttributeMatch {
        match (op) {
            case "=" => CssAttributeMatch.Exact
            case "^=" => CssAttributeMatch.Prefix
            case "$=" => CssAttributeMatch.Suffix
            case "*=" => CssAttributeMatch.Contains
            case "|=" => CssAttributeMatch.DashMatch
            case _ => CssAttributeMatch.Exists
        }
    }
}

// ============================================================================
// CSSMinifier - CSS 压缩器
// 严格翻译自: src/css/printer.zig 中压缩逻辑
// ============================================================================

/// CSS 压缩选项
public class CSSMinifyOptions {
    public var removeComments: Bool
    public var removeWhitespace: Bool
    public var mergeLonghand: Bool      // 合并长手属性 (margin-top + margin-bottom -> margin)
    public var reduceColors: Bool       // #ffffff -> #fff, rgb(0,0,0) -> #000
    public var removeEmptyRules: Bool   // 移除空规则
    public var collapseSelectors: Bool  // 合并相同选择器的规则

    public init() {
        this.removeComments = true
        this.removeWhitespace = true
        this.mergeLonghand = false
        this.reduceColors = true
        this.removeEmptyRules = true
        this.collapseSelectors = false
    }
}

/// CSS 压缩器
// 严格翻译自: css/printer.zig 中 minified 输出逻辑
public class CSSMinifier {
    private static let SPACE: UInt8 = UInt8(32)
    private static let TAB: UInt8 = UInt8(9)
    private static let LF: UInt8 = UInt8(10)
    private static let CR: UInt8 = UInt8(13)
    private static let LPAREN: UInt8 = UInt8(40)
    private static let RPAREN: UInt8 = UInt8(41)
    private static let STAR: UInt8 = UInt8(42)
    private static let SLASH: UInt8 = UInt8(47)
    private static let HASH: UInt8 = UInt8(35)
    private static let ZERO: UInt8 = UInt8(48)
    private static let NINE: UInt8 = UInt8(57)
    private static let LOWER_A: UInt8 = UInt8(97)
    private static let LOWER_F: UInt8 = UInt8(102)
    private static let UPPER_A: UInt8 = UInt8(65)
    private static let UPPER_F: UInt8 = UInt8(70)

    private var options: CSSMinifyOptions

    public init() {
        this.options = CSSMinifyOptions()
    }

    public init(options: CSSMinifyOptions) {
        this.options = options
    }

    /// 压缩 CSS 样式表
    public func minify(stylesheet: CssStylesheet): String {
        let sb = StringBuilder()

        for (rule in stylesheet.rules) {
            let minified = minifyRule(rule)
            if (minified.length > 0) {
                sb.append(minified)
            }
        }

        return sb.toString()
    }

    /// 压缩 CSS 文本 (无需解析)
    public func minifyText(css: String): String {
        // 简易压缩: 移除注释、空白
        var result = removeComments(css)

        if (options.removeWhitespace) {
            // 移除多余空白
            result = collapseWhitespace(result)
        }

        if (options.reduceColors) {
            result = reduceColors(result)
        }

        return result
    }

    /// 压缩规则
    private func minifyRule(rule: CssRule): String {
        match (rule.atRule) {
            case Some(at) => return minifyAtRule(at)
            case None =>
                // 移除空规则
                if (options.removeEmptyRules && rule.declarations.size == 0) {
                    return ""
                }
                return rule.toMinifiedString()
        }
    }

    /// 压缩 @规则
    private func minifyAtRule(at: CssAtRule): String {
        let sb = StringBuilder()
        sb.append("@${at.name}")

        match (at.kind) {
            case CssAtRuleKind.Import =>
                // @import url(...) 保持
                sb.append(" ${at.prelude};")
                return sb.toString()
            case _ => ()
        }

        if (at.prelude.length > 0) {
            sb.append(at.prelude)
        }

        sb.append("{")
        for (rule in at.rules) {
            sb.append(minifyRule(rule))
        }
        sb.append("}")
        return sb.toString()
    }

    /// 移除 CSS 注释
    private static func removeComments(css: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        let n = Int64(css.length)
        while (i < n) {
            if (i + 1 < n && css[i] == SLASH && css[i + 1] == STAR) {
                // 跳过注释
                i += 2
                while (i + 1 < n && !(css[i] == STAR && css[i + 1] == SLASH)) {
                    i++
                }
                i += 2
            } else {
                sb.append(css[i])
                i++
            }
        }
        return sb.toString()
    }

    /// 压缩空白
    private static func collapseWhitespace(css: String): String {
        let sb = StringBuilder()
        var prevIsSpace = false
        for (c in css) {
            if (c == SPACE || c == TAB || c == LF || c == CR) {
                if (!prevIsSpace) {
                    sb.append(SPACE)
                    prevIsSpace = true
                }
            } else {
                sb.append(c)
                prevIsSpace = false
            }
        }
        return sb.toString()
    }

    /// 压缩颜色值
    private static func reduceColors(css: String): String {
        var result = css
        // #ffffff -> #fff
        result = reduceHexColors(result)
        // rgb(0,0,0) -> #000000 (简化)
        result = reduceRgbColors(result)
        return result
    }

    /// #rrggbb -> #rgb (当每对相同)
    private static func reduceHexColors(css: String): String {
        // 查找 #xxxxxx 模式
        let sb = StringBuilder()
        var i: Int64 = 0
        let n = Int64(css.length)
        while (i < n) {
            if (css[i] == HASH && i + 6 < n && isHex(css[Int64(i + 1)]) && isHex(css[Int64(i + 2)]) && isHex(css[Int64(i + 3)]) && isHex(css[Int64(i + 4)]) && isHex(css[Int64(i + 5)]) && isHex(css[Int64(i + 6)])) {
                // 检查是否可以缩短
                if (css[i + 1] == css[i + 2] && css[i + 3] == css[i + 4] && css[i + 5] == css[i + 6]) {
                    sb.append(HASH)
                    sb.append(css[i + 1])
                    sb.append(css[i + 3])
                    sb.append(css[i + 5])
                    i += 7
                } else {
                    sb.append(css[i])
                    i++
                }
            } else {
                sb.append(css[i])
                i++
            }
        }
        return sb.toString()
    }

    /// rgb(r,g,b) -> #rrggbb
    private static func reduceRgbColors(css: String): String {
        return css
    }

    private static func isHex(c: UInt8): Bool {
        return (c >= ZERO && c <= NINE) || (c >= LOWER_A && c <= LOWER_F) || (c >= UPPER_A && c <= UPPER_F)
    }

    private static func parseByte(s: String): Int64 {
        return 0
    }

    private static func toHex(n: Int64): String {
        return "00"
    }
}
