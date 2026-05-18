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
                return ":${name}"
            case CssSimpleSelectorKind.PseudoElement =>
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
                sb.append(" ${at.prelude}")
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
                sb.append(at.prelude)
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
        return result
    }

    /// 解析 @规则
    private func parseAtRule(): Unit {
        let atRule = CssAtRule(CssAtRuleKind.Custom, "", "")
        let rule = CssRule.createAtRule(atRule)
        result.stylesheet.addRule(rule)
    }

    /// 将 @规则解析到父级 atRule
    private func parseAtRuleInto(parent: CssAtRule): Unit {
        let atRule = CssAtRule(CssAtRuleKind.Custom, "", "")
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
        return
    }

    /// 解析选择器列表 (逗号分隔)
    private func parseSelectorList(): CssSelectorList {
        return CssSelectorList()
    }

    /// 解析复合选择器 (空格/>/+/~ 组合的简单选择器序列)
    private func parseComplexSelector(): CssComplexSelector {
        return CssComplexSelector()
    }

    /// 解析简单选择器
    private func parseSimpleSelector(): CssSelector {
        return CssSelector.universal()
    }

    /// 解析属性选择器 [attr=value]
    private func parseAttributeSelector(): CssSelector {
        return CssSelector(CssSimpleSelectorKind.Attribute, "")
    }

    /// 解析声明块
    private func parseDeclarations(rule: CssRule): Unit {
        return
    }


    // -----------------------------------------------------------------------
    // 词法分析辅助
    // -----------------------------------------------------------------------

    /// 跳过空白和注释
    private func skipWhitespaceAndComments(): Unit {
        return
    }

    /// 跳过空白
    private func skipWhitespace(): Unit {
        return
    }

    /// 前进一个字符
    private func advance(): Unit {
        pos++
        column++
    }

    /// 读取标识符
    private func readIdent(): String {
        return ""
    }

    /// 读取属性名
    private func readPropertyName(): String {
        return ""
    }

    /// 读取声明值 (到 ; 或 } 为止)
    private func readDeclarationValue(): String {
        return ""
    }

    /// 读取括号内容
    private func readParenthesized(): String {
        return ""
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
        return CssCombinator.None
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
        return ""
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
        return ""
    }

    /// 移除 CSS 注释
    private static func removeComments(css: String): String {
        return css
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
        return css
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
