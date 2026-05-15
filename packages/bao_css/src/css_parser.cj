// bao_css - CSS Parser (CSS 解析器)
// 严格翻译自: bun/src/css/css_parser.zig (Parser, ParserOptions)
//   对应: Parser struct - 顶层解析器, 从 token 流构建 AST
//   对应: ParserOptions - 解析配置
//   对应: Stylesheet struct - CSS 样式表顶层结构
//   对应: BasicParseErrorKind / ParserError / ParseError - 错误类型
//   对应: VendorPrefix - 供应商前缀
//   对应: SourceLocation / Location - 源码位置
//   对应: Delimiters / BlockType / ParserState - 解析器内部状态
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 解析错误
// 严格翻译自: css_parser.zig ParseError, ParserError, BasicParseError
// ============================================================================

/// CSS 解析错误类型
/// 严格翻译自 BasicParseErrorKind + ParserError 的合并
public enum CssParseErrorKind {
    | UnexpectedToken          // 意外的 token (BasicParseErrorKind.UnexpectedToken)
    | EndOfInput               // 输入结束 (BasicParseErrorKind.EndOfInput)
    | AtRuleInvalid            // 无效 @规则 (BasicParseErrorKind.AtRuleInvalid)
    | AtRuleBodyInvalid        // 无效 @规则体 (BasicParseErrorKind.AtRuleBodyInvalid)
    | QualifiedRuleInvalid     // 无效限定规则 (BasicParseErrorKind.QualifiedRuleInvalid)
    | UnexpectedBlock          // 意外代码块 (BasicParseErrorKind.UnexpectedBlock)
    | DeclarationExpected      // 期望声明 (BasicParseErrorKind.DeclarationExpected)
    | AtRuleExpected           // 期望 @规则 (BasicParseErrorKind.AtRuleExpected)
    | InvalidValue             // 无效值 (ParserError.InvalidValue)
    | InvalidSelector          // 无效选择器
    | MissingClosingBrace      // 缺少右花括号
    | MissingClosingParen      // 缺少右圆括号
    | UnexpectedEof            // 意外的文件结束
    | UnexpectedRuleInBlock    // 块中出现意外规则
    | IoError                  // IO 错误
    | SyntaxError              // 语法错误 (ParserError.SyntaxError)
    | CustomError              // 自定义错误

    public func toString(): String {
        match (this) {
            case UnexpectedToken => "unexpected token"
            case EndOfInput => "end of input"
            case AtRuleInvalid => "invalid @ rule"
            case AtRuleBodyInvalid => "invalid @ rule body"
            case QualifiedRuleInvalid => "invalid qualified rule"
            case UnexpectedBlock => "unexpected block"
            case DeclarationExpected => "expected declaration"
            case AtRuleExpected => "expected @ rule"
            case InvalidValue => "invalid value"
            case InvalidSelector => "invalid selector"
            case MissingClosingBrace => "missing closing brace"
            case MissingClosingParen => "missing closing parenthesis"
            case UnexpectedEof => "unexpected end of file"
            case UnexpectedRuleInBlock => "unexpected rule in block"
            case IoError => "IO error"
            case SyntaxError => "syntax error"
            case CustomError => "custom error"
        }
    }
}

/// CSS 解析错误
public class CssParseError {
    public var kind: CssParseErrorKind
    public var line: Int64
    public var column: Int64
    public var message: String

    public init(kind: CssParseErrorKind, line: Int64, column: Int64) {
        this.kind = kind
        this.line = line
        this.column = column
        this.message = kind.toString()
    }

    public init(kind: CssParseErrorKind, line: Int64, column: Int64, message: String) {
        this.kind = kind
        this.line = line
        this.column = column
        this.message = message
    }

    public func toString(): String {
        "${line}:${column}: ${message}"
    }
}

// ============================================================================
// 解析结果
// ============================================================================

/// 解析结果
public class CssParseResult<T> {
    public var value: ?T
    public var error: ?CssParseError

    public init(value: T) {
        this.value = Some(value)
        this.error = None
    }

    public init(error: CssParseError) {
        this.value = None
        this.error = Some(error)
    }

    public static func ok<T>(value: T): CssParseResult<T> {
        CssParseResult<T>(value)
    }

    public static func err<T>(error: CssParseError): CssParseResult<T> {
        CssParseResult<T>(error)
    }

    public func isOk(): Bool {
        value != None
    }

    public func isErr(): Bool {
        error != None
    }

    public func unwrap(): T {
        match (value) {
            case Some(v) => v
            case None => panic("unwrap on error result")
        }
    }
}

/// 获取值或默认值
public func <T> CssParseResult<T>.unwrapOr(default: T): T {
    match (this.value) {
        case Some(v) => v
        case None => default
    }
}

// ============================================================================
// 解析器选项
// 严格翻译自: css_parser.zig ParserOptions
// ============================================================================

/// CSS 解析器选项
/// 严格翻译自 ParserOptions struct
public class CssParserOptions {
    /// 是否启用错误恢复 (跳过错误继续解析)
    public var errorRecovery: Bool
    /// CSS Modules 配置
    public var cssModules: ?CssModulesConfig
    /// 是否为源文件列表
    public var sourceIndex: Int64
    /// 文件名 (用于错误报告)
    public var filename: String

    public init() {
        this.errorRecovery = true
        this.cssModules = None
        this.sourceIndex = 0
        this.filename = "<input>"
    }

    public static func default(): CssParserOptions {
        CssParserOptions()
    }
}

// ============================================================================
// 源码位置 (Location in rules.zig)
// 严格翻译自: Location struct
// ============================================================================

/// CSS 规则位置
/// 严格翻译自 Location struct (source_index, line, column)
public class CssLocation {
    public var sourceIndex: Int64
    public var line: Int64
    public var column: Int64

    public init() {
        this.sourceIndex = 0
        this.line = 0
        this.column = 1
    }

    public init(sourceIndex: Int64, line: Int64, column: Int64) {
        this.sourceIndex = sourceIndex
        this.line = line
        this.column = column
    }

    /// 创建虚拟位置
    public static func dummy(): CssLocation {
        CssLocation(Int64.MAX_VALUE, Int64.MAX_VALUE, Int64.MAX_VALUE)
    }

    public func toString(): String {
        "${sourceIndex}:${line}:${column}"
    }
}

// ============================================================================
// StyleContext
// 严格翻译自: rules/rules.zig StyleContext
// ============================================================================

/// 样式上下文 - 用于嵌套规则打印
/// 严格翻译自 StyleContext struct
public class CssStyleContext {
    /// 选择器列表
    public var selectors: CssSelectorList
    /// 父上下文
    public var parent: ?CssStyleContext

    public init(selectors: CssSelectorList) {
        this.selectors = selectors
        this.parent = None
    }

    public init(selectors: CssSelectorList, parent: CssStyleContext) {
        this.selectors = selectors
        this.parent = Some(parent)
    }
}

// ============================================================================
// MinifyContext
// 严格翻译自: rules/rules.zig MinifyContext
// ============================================================================

/// CSS 压缩上下文
/// 严格翻译自 MinifyContext struct
public class CssMinifyContext {
    /// 目标浏览器
    public var targets: CssTargets
    /// 未使用的符号集合
    public var unusedSymbols: HashSet<String>
    /// 是否启用 CSS Modules
    public var cssModules: Bool

    public init() {
        this.targets = CssTargets()
        this.unusedSymbols = HashSet<String>()
        this.cssModules = false
    }
}

// ============================================================================
// Targets
// 严格翻译自: targets.zig Targets
// ============================================================================

/// CSS 编译目标
/// 严格翻译自 Targets struct
public class CssTargets {
    /// 浏览器目标列表
    public var browsers: ?ArrayList<CssBrowserVersion>

    public init() {
        this.browsers = None
    }
}

/// 浏览器版本
public class CssBrowserVersion {
    public var name: String
    public var version: Int64

    public init(name: String, version: Int64) {
        this.name = name
        this.version = version
    }
}

// ============================================================================
// CSS 解析器
// 严格翻译自: css_parser.zig Parser
//   Parser 持有 Tokenizer 的引用，提供高层解析接口
// ============================================================================

/// CSS 解析器
/// 从 CssLexer 的 token 流构建 CSS AST
public class CssParser {
    /// 词法分析器
    private var lexer: CssLexer
    /// 当前预读的 token
    private var currentToken: CssToken
    /// 解析选项
    private var options: CssParserOptions
    /// 错误列表
    public var errors: ArrayList<CssParseError>
    /// 解析是否已结束
    private var eof: Bool

    public init() {
        this.lexer = CssLexer()
        this.currentToken = CssToken(CssTokenKind.Eof)
        this.options = CssParserOptions()
        this.errors = ArrayList<CssParseError>()
        this.eof = false
    }

    /// 初始化解析器
    public func init(source: String): Unit {
        lexer.init(source)
        options = CssParserOptions()
        errors = ArrayList<CssParseError>()
        eof = false
        advance() // 预读第一个 token
    }

    /// 初始化解析器 (带选项)
    public func init(source: String, options: CssParserOptions): Unit {
        lexer.init(source)
        this.options = options
        errors = ArrayList<CssParseError>()
        eof = false
        advance()
    }

    // ========================================================================
    // 顶层解析
    // ========================================================================

    /// 解析完整的 CSS 样式表
    /// 严格翻译自: Stylesheet.parse
    /// 返回规则列表
    public func parseStylesheet(): CssRuleList {
        let rules = ArrayList<CssRule>()
        skipWhitespace()

        while (!eof && currentToken.kind != CssTokenKind.Eof) {
            let rule = parseRule()
            match (rule) {
                case Some(r) => rules.append(r)
                case None =>
                    if (!options.errorRecovery) { break }
                    // 错误恢复: 跳到下一个规则
                    recoverToRule()
            }
        }

        return CssRuleList(rules)
    }

    /// 解析单个规则列表 (块内容)
    public func parseRuleList(): CssRuleList {
        let rules = ArrayList<CssRule>()

        while (!eof && currentToken.kind != CssTokenKind.Eof &&
               currentToken.kind != CssTokenKind.RBrace) {
            let rule = parseRule()
            match (rule) {
                case Some(r) => rules.append(r)
                case None =>
                    if (!options.errorRecovery) { break }
                    recoverToRule()
            }
        }

        return CssRuleList(rules)
    }

    /// 解析声明块
    /// 严格翻译自: DeclarationBlock.parse
    public func parseDeclarationBlock(): CssDeclarationBlock {
        let declarations = ArrayList<CssDeclaration>()
        let importantDeclarations = ArrayList<CssDeclaration>()
        skipWhitespace()

        while (!eof && currentToken.kind != CssTokenKind.RBrace &&
               currentToken.kind != CssTokenKind.Eof) {
            // 检测 @规则嵌套
            if (currentToken.kind == CssTokenKind.AtKeyword) {
                // @规则在声明块中按嵌套规则处理
                break
            }

            // 解析声明: property: value;
            let decl = parseDeclaration()
            match (decl) {
                case Some(d) =>
                    if (d.important) {
                        importantDeclarations.append(d)
                    } else {
                        declarations.append(d)
                    }
                case None =>
                    if (!options.errorRecovery) { break }
                    // 跳过错误恢复到分号
                    recoverToSemicolon()
            }
        }

        return CssDeclarationBlock(declarations, importantDeclarations)
    }

    // ========================================================================
    // 规则解析
    // ========================================================================

    /// 解析单个规则
    public func parseRule(): ?CssRule {
        skipWhitespace()
        if (eof || currentToken.kind == CssTokenKind.Eof) { return None }

        // @规则
        if (currentToken.kind == CssTokenKind.AtKeyword) {
            return parseAtRule()
        }

        // 样式规则 (选择器 + 声明块)
        return parseStyleRule()
    }

    /// 解析 @规则
    /// 严格翻译自: AtRuleParser 中各 @规则的解析分发
    private func parseAtRule(): ?CssRule {
        let name = currentToken.text.toLowerCase()
        let pos = currentToken.position
        advance() // 跳过 @keyword
        skipWhitespace()

        match (name) {
            case "media" => return parseMediaRule(pos)
            case "import" => return parseImportRule(pos)
            case "keyframes" | "-webkit-keyframes" | "-moz-keyframes" |
                 "-o-keyframes" | "-ms-keyframes" => return parseKeyframesRule(name, pos)
            case "font-face" => return parseFontFaceRule(pos)
            case "supports" => return parseSupportsRule(pos)
            case "layer" => return parseLayerRule(pos)
            case "container" => return parseContainerRule(pos)
            case "namespace" => return parseNamespaceRule(pos)
            case "charset" => return parseCharsetRule(pos)
            case "property" => return parsePropertyRule(pos)
            case _ => return parseUnknownAtRule(name, pos)
        }
    }

    /// 解析 @media 规则
    private func parseMediaRule(pos: CssTokenPosition): ?CssRule {
        // 读取媒体查询文本 (从当前位置到 {)
        let prelude = readPrelude()
        skipWhitespace()
        expectLBrace()
        advance()

        let rules = parseRuleList()

        expectRBrace()
        if (currentToken.kind == CssTokenKind.RBrace) { advance() }

        let rule = CssAtMediaRule(prelude, rules)
        rule.position = pos
        return Some(CssRule.createMedia(rule))
    }

    /// 解析 @import 规则
    private func parseImportRule(pos: CssTokenPosition): ?CssRule {
        skipWhitespace()

        // URL: 可以是字符串或 url()
        var url: String = ""
        if (currentToken.kind == CssTokenKind.String) {
            url = currentToken.text
            advance()
        } else if (currentToken.kind == CssTokenKind.Url) {
            url = currentToken.text
            advance()
        } else if (currentToken.kind == CssTokenKind.Function && currentToken.text.toLowerCase() == "url") {
            advance() // 跳过 url(
            if (currentToken.kind == CssTokenKind.String) {
                url = currentToken.text
                advance()
            }
            expectRParen()
            if (currentToken.kind == CssTokenKind.RParen) { advance() }
        } else {
            addError(CssParseErrorKind.InvalidAtRule, "expected URL after @import")
            return None
        }

        skipWhitespace()

        // 条件: media query, layer, supports
        let conditions = readPrelude()
        expectSemicolon()
        if (currentToken.kind == CssTokenKind.Semicolon) { advance() }

        let rule = CssAtImportRule(url, conditions)
        rule.position = pos
        return Some(CssRule.createImport(rule))
    }

    /// 解析 @keyframes 规则
    private func parseKeyframesRule(name: String, pos: CssTokenPosition): ?CssRule {
        skipWhitespace()
        let keyframeName = readIdentOrString()
        skipWhitespace()
        expectLBrace()
        advance()

        let keyframes = ArrayList<CssKeyframeBlock>()

        while (!eof && currentToken.kind != CssTokenKind.RBrace &&
               currentToken.kind != CssTokenKind.Eof) {
            let block = parseKeyframeBlock()
            match (block) {
                case Some(b) => keyframes.append(b)
                case None => break
            }
        }

        expectRBrace()
        if (currentToken.kind == CssTokenKind.RBrace) { advance() }

        let rule = CssAtKeyframesRule(name, keyframeName, keyframes)
        rule.position = pos
        return Some(CssRule.createKeyframes(rule))
    }

    /// 解析关键帧块 (from/to/percentage)
    private func parseKeyframeBlock(): ?CssKeyframeBlock {
        let selectors = ArrayList<String>()
        skipWhitespace()

        // 读取选择器: from, to, 或百分比列表
        while (!eof && currentToken.kind != CssTokenKind.LBrace) {
            if (currentToken.kind == CssTokenKind.Ident) {
                selectors.append(currentToken.text.toLowerCase())
                advance()
            } else if (currentToken.kind == CssTokenKind.Percentage) {
                selectors.append("${currentToken.numberValue}%")
                advance()
            } else if (currentToken.kind == CssTokenKind.Comma) {
                advance()
                skipWhitespace()
            } else {
                break
            }
        }

        skipWhitespace()
        expectLBrace()
        if (currentToken.kind != CssTokenKind.LBrace) { return None }
        advance()

        let declarations = parseDeclarationBlock()

        expectRBrace()
        if (currentToken.kind == CssTokenKind.RBrace) { advance() }

        return Some(CssKeyframeBlock(selectors, declarations))
    }

    /// 解析 @font-face 规则
    private func parseFontFaceRule(pos: CssTokenPosition): ?CssRule {
        skipWhitespace()
        expectLBrace()
        advance()
        let declarations = parseDeclarationBlock()
        expectRBrace()
        if (currentToken.kind == CssTokenKind.RBrace) { advance() }

        let rule = CssAtFontFaceRule(declarations)
        rule.position = pos
        return Some(CssRule.createFontFace(rule))
    }

    /// 解析 @supports 规则
    private func parseSupportsRule(pos: CssTokenPosition): ?CssRule {
        let condition = readPrelude()
        skipWhitespace()
        expectLBrace()
        advance()
        let rules = parseRuleList()
        expectRBrace()
        if (currentToken.kind == CssTokenKind.RBrace) { advance() }

        let rule = CssAtSupportsRule(condition, rules)
        rule.position = pos
        return Some(CssRule.createSupports(rule))
    }

    /// 解析 @layer 规则
    private func parseLayerRule(pos: CssTokenPosition): ?CssRule {
        skipWhitespace()

        if (currentToken.kind == CssTokenKind.LBrace) {
            // 匿名 layer 块
            advance()
            let rules = parseRuleList()
            expectRBrace()
            if (currentToken.kind == CssTokenKind.RBrace) { advance() }
            let rule = CssAtLayerBlockRule("", rules)
            rule.position = pos
            return Some(CssRule.createLayerBlock(rule))
        }

        let name = readPrelude()
        skipWhitespace()

        if (currentToken.kind == CssTokenKind.Semicolon) {
            advance()
            let rule = CssAtLayerStatementRule(name)
            rule.position = pos
            return Some(CssRule.createLayerStatement(rule))
        }

        if (currentToken.kind == CssTokenKind.LBrace) {
            advance()
            let rules = parseRuleList()
            expectRBrace()
            if (currentToken.kind == CssTokenKind.RBrace) { advance() }
            let rule = CssAtLayerBlockRule(name, rules)
            rule.position = pos
            return Some(CssRule.createLayerBlock(rule))
        }

        return None
    }

    /// 解析 @container 规则
    private func parseContainerRule(pos: CssTokenPosition): ?CssRule {
        let name = readIdentOrString()
        skipWhitespace()
        let condition = readPrelude()
        skipWhitespace()
        expectLBrace()
        advance()
        let rules = parseRuleList()
        expectRBrace()
        if (currentToken.kind == CssTokenKind.RBrace) { advance() }

        let rule = CssAtContainerRule(name, condition, rules)
        rule.position = pos
        return Some(CssRule.createContainer(rule))
    }

    /// 解析 @namespace 规则
    private func parseNamespaceRule(pos: CssTokenPosition): ?CssRule {
        let prelude = readPrelude()
        expectSemicolon()
        if (currentToken.kind == CssTokenKind.Semicolon) { advance() }
        let rule = CssAtNamespaceRule(prelude)
        rule.position = pos
        return Some(CssRule.createNamespace(rule))
    }

    /// 解析 @charset 规则
    private func parseCharsetRule(pos: CssTokenPosition): ?CssRule {
        let charset = readPrelude()
        expectSemicolon()
        if (currentToken.kind == CssTokenKind.Semicolon) { advance() }
        return Some(CssRule.createIgnored())
    }

    /// 解析 @property 规则
    private func parsePropertyRule(pos: CssTokenPosition): ?CssRule {
        skipWhitespace()
        let name = readIdentOrString()
        skipWhitespace()
        expectLBrace()
        advance()
        let declarations = parseDeclarationBlock()
        expectRBrace()
        if (currentToken.kind == CssTokenKind.RBrace) { advance() }
        let rule = CssAtPropertyRule(name, declarations)
        rule.position = pos
        return Some(CssRule.createProperty(rule))
    }

    /// 解析未知 @规则
    private func parseUnknownAtRule(name: String, pos: CssTokenPosition): ?CssRule {
        let prelude = readPrelude()
        skipWhitespace()

        if (currentToken.kind == CssTokenKind.Semicolon) {
            advance()
            let rule = CssUnknownAtRule(name, prelude, CssDeclarationBlock.empty())
            rule.position = pos
            return Some(CssRule.createUnknown(rule))
        }

        if (currentToken.kind == CssTokenKind.LBrace) {
            advance()
            // 尝试解析内容 (可能是声明块或规则块)
            let content = parseRuleList()
            expectRBrace()
            if (currentToken.kind == CssTokenKind.RBrace) { advance() }
            let rule = CssUnknownAtRule(name, prelude, CssDeclarationBlock.empty())
            rule.position = pos
            rule.rules = Some(content)
            return Some(CssRule.createUnknown(rule))
        }

        return None
    }

    /// 解析样式规则
    /// 严格翻译自: parseStyleRule
    private func parseStyleRule(): ?CssRule {
        let pos = currentToken.position

        // 解析选择器
        let selectorText = readUntilLBrace()
        let selectorParser = CssSelectorParser()
        let selectors = selectorParser.parse(selectorText)
        skipWhitespace()

        if (currentToken.kind != CssTokenKind.LBrace) {
            addError(CssParseErrorKind.MissingClosingBrace, "expected '{' after selector")
            return None
        }
        advance()

        // 解析声明和嵌套规则
        let declarations = ArrayList<CssDeclaration>()
        let importantDeclarations = ArrayList<CssDeclaration>()
        let nestedRules = ArrayList<CssRule>()

        while (!eof && currentToken.kind != CssTokenKind.RBrace &&
               currentToken.kind != CssTokenKind.Eof) {
            skipWhitespace()
            if (eof || currentToken.kind == CssTokenKind.RBrace) { break }

            if (currentToken.kind == CssTokenKind.AtKeyword) {
                // 嵌套 @规则
                let rule = parseAtRule()
                match (rule) {
                    case Some(r) => nestedRules.append(r)
                    case None => if (!options.errorRecovery) { break }
                }
            } else {
                // 声明或嵌套样式规则
                let decl = parseDeclaration()
                match (decl) {
                    case Some(d) =>
                        if (d.important) {
                            importantDeclarations.append(d)
                        } else {
                            declarations.append(d)
                        }
                    case None =>
                        if (!options.errorRecovery) { break }
                        recoverToSemicolon()
                }
            }
        }

        expectRBrace()
        if (currentToken.kind == CssTokenKind.RBrace) { advance() }

        let selList = match (selectors) {
            case Some(s) => s
            case None => CssSelectorList()
        }

        let rule = CssStyleRule(selList, CssDeclarationBlock(declarations, importantDeclarations), nestedRules)
        rule.position = pos
        return Some(CssRule.createStyle(rule))
    }

    /// 解析单个声明
    /// 严格翻译自: parseDeclaration
    private func parseDeclaration(): ?CssDeclaration {
        if (currentToken.kind != CssTokenKind.Ident) { return None }

        let name = currentToken.text
        let pos = currentToken.position
        advance()
        skipWhitespace()

        // 期望冒号
        if (currentToken.kind != CssTokenKind.Colon) {
            addError(CssParseErrorKind.InvalidDeclaration, "expected ':' after property name '${name}'")
            return None
        }
        advance()
        skipWhitespace()

        // 读取值 (直到 ; 或 !important 或 })
        let value = readValue()

        // 检查 !important
        var important = false
        if (currentToken.kind == CssTokenKind.Delim && currentToken.delimChar == '!') {
            advance()
            skipWhitespace()
            if (currentToken.kind == CssTokenKind.Ident &&
                currentToken.text.toLowerCase() == "important") {
                important = true
                advance()
                skipWhitespace()
            }
        }

        // 消费分号
        if (currentToken.kind == CssTokenKind.Semicolon) {
            advance()
        }

        return Some(CssDeclaration(name, value, important, pos))
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 前进到下一个 token
    private func advance(): Unit {
        currentToken = lexer.nextToken()
        if (currentToken.kind == CssTokenKind.Eof) {
            eof = true
        }
    }

    /// 跳过空白
    private func skipWhitespace(): Unit {
        while (currentToken.kind == CssTokenKind.Whitespace) {
            advance()
        }
    }

    /// 读取前导内容 (直到 { 或 ;)
    private func readPrelude(): String {
        let sb = StringBuilder()
        var depth: Int64 = 0

        while (!eof && currentToken.kind != CssTokenKind.Eof) {
            if (depth == 0 && (currentToken.kind == CssTokenKind.LBrace ||
                               currentToken.kind == CssTokenKind.Semicolon)) {
                break
            }
            if (currentToken.kind == CssTokenKind.LParen ||
                currentToken.kind == CssTokenKind.LBracket) {
                depth++
            }
            if (currentToken.kind == CssTokenKind.RParen ||
                currentToken.kind == CssTokenKind.RBracket) {
                depth--
                if (depth < 0) { depth = 0 }
            }
            sb.append(currentToken.toString())
            advance()
        }

        return sb.toString().trim()
    }

    /// 读取直到左花括号
    private func readUntilLBrace(): String {
        let sb = StringBuilder()
        while (!eof && currentToken.kind != CssTokenKind.LBrace &&
               currentToken.kind != CssTokenKind.Eof) {
            sb.append(currentToken.toString())
            advance()
        }
        return sb.toString().trim()
    }

    /// 读取声明值 (直到 ; 或 } 或 !important)
    private func readValue(): String {
        let sb = StringBuilder()
        var depth: Int64 = 0

        while (!eof && currentToken.kind != CssTokenKind.Eof) {
            if (depth == 0 && (currentToken.kind == CssTokenKind.Semicolon ||
                               currentToken.kind == CssTokenKind.RBrace)) {
                break
            }
            // !important 标记
            if (depth == 0 && currentToken.kind == CssTokenKind.Delim &&
                currentToken.delimChar == '!') {
                break
            }
            if (currentToken.kind == CssTokenKind.LParen ||
                currentToken.kind == CssTokenKind.LBracket ||
                currentToken.kind == CssTokenKind.Function) {
                depth++
            }
            if (currentToken.kind == CssTokenKind.RParen ||
                currentToken.kind == CssTokenKind.RBracket) {
                depth--
                if (depth < 0) { break }
            }
            sb.append(currentToken.toString())
            advance()
        }

        return sb.toString().trim()
    }

    /// 读取标识符或字符串
    private func readIdentOrString(): String {
        skipWhitespace()
        if (currentToken.kind == CssTokenKind.String) {
            let text = currentToken.text
            advance()
            return text
        }
        if (currentToken.kind == CssTokenKind.Ident) {
            let text = currentToken.text
            advance()
            return text
        }
        return ""
    }

    /// 期望左花括号
    private func expectLBrace(): Unit {
        if (currentToken.kind != CssTokenKind.LBrace) {
            addError(CssParseErrorKind.MissingClosingBrace, "expected '{'")
        }
    }

    /// 期望右花括号
    private func expectRBrace(): Unit {
        if (currentToken.kind != CssTokenKind.RBrace) {
            addError(CssParseErrorKind.MissingClosingBrace, "expected '}'")
        }
    }

    /// 期望右圆括号
    private func expectRParen(): Unit {
        if (currentToken.kind != CssTokenKind.RParen) {
            addError(CssParseErrorKind.MissingClosingParen, "expected ')'")
        }
    }

    /// 期望分号
    private func expectSemicolon(): Unit {
        // 分号是可选的, 不强制
    }

    /// 添加错误
    private func addError(kind: CssParseErrorKind, message: String): Unit {
        let pos = currentToken.position
        errors.append(CssParseError(kind, pos.line, pos.column, message))
    }

    /// 错误恢复: 跳到下一个规则
    private func recoverToRule(): Unit {
        var depth: Int64 = 0
        while (!eof && currentToken.kind != CssTokenKind.Eof) {
            if (currentToken.kind == CssTokenKind.LBrace) { depth++ }
            if (currentToken.kind == CssTokenKind.RBrace) {
                depth--
                if (depth <= 0) { advance(); return }
            }
            if (currentToken.kind == CssTokenKind.Semicolon && depth == 0) {
                advance()
                return
            }
            advance()
        }
    }

    /// 错误恢复: 跳到分号
    private func recoverToSemicolon(): Unit {
        var depth: Int64 = 0
        while (!eof && currentToken.kind != CssTokenKind.Eof) {
            if (depth == 0 && currentToken.kind == CssTokenKind.Semicolon) {
                advance()
                return
            }
            if (currentToken.kind == CssTokenKind.LBrace ||
                currentToken.kind == CssTokenKind.LParen ||
                currentToken.kind == CssTokenKind.LBracket) {
                depth++
            }
            if (currentToken.kind == CssTokenKind.RBrace ||
                currentToken.kind == CssTokenKind.RParen ||
                currentToken.kind == CssTokenKind.RBracket) {
                depth--
                if (depth < 0) {
                    return // 不消费结束符
                }
            }
            advance()
        }
    }
}
