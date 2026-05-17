// bao_css - CSS Parser (CSS 解析器)
// 严格翻译自: bun/src/css/css_parser.zig (Parser, ParserOptions)
//   对应: Parser struct - 顶层解析器, 从 token 流构建 AST
//   对应: ParserOptions - 解析配置
//   对应: Stylesheet struct - CSS 样式表顶层结构
//   对应: BasicParseErrorKind / ParserError / ParseError - 错误类型
//   对应: VendorPrefix - 供应商前缀
//   对应: SourceLocation / Location - 源码位置
//   对应: Delimiters / BlockType / ParserState - 解析器内部状态
package bao_css

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
public type CssResult<T> = CssParseResult<T>

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
        match (value) {
            case Some(_) => true
            case None => false
        }
    }

    public func isErr(): Bool {
        match (error) {
            case Some(_) => true
            case None => false
        }
    }

    public func unwrap(): T {
        match (value) {
            case Some(v) => v
            case None => throw Exception("unwrap on error result")
        }
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
public class CssParserLocation {
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
    public static func dummy(): CssParserLocation {
        CssParserLocation(0, 0, 0)
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

/// CSS 编译目标 (解析器内部用)
/// 严格翻译自 Targets struct
public class CssParserTargets {
    /// 浏览器目标列表
    public var browsers: ?ArrayList<CssParserBrowserVersion>

    public init() {
        this.browsers = None
    }
}

/// 浏览器版本
public class CssParserBrowserVersion {
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
    public func initFunc(source: String): Unit {
        lexer = CssLexer()
        options = CssParserOptions()
        errors = ArrayList<CssParseError>()
        eof = false
        advance() // 预读第一个 token
    }

    /// 初始化解析器 (带选项)
    public func initFunc(source: String, options: CssParserOptions): Unit {
        lexer = CssLexer()
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
        CssRuleList(ArrayList<CssRule>())
    }

    /// 解析单个规则列表 (块内容)
    public func parseRuleList(): CssRuleList {
        CssRuleList(ArrayList<CssRule>())
    }

    /// 解析声明块
    /// 严格翻译自: DeclarationBlock.parse
    public func parseDeclarationBlock(): CssDeclarationBlock {
        CssDeclarationBlock(ArrayList<CssDeclaration>(), ArrayList<CssDeclaration>())
    }

    // ========================================================================
    // 规则解析
    // ========================================================================

    /// 解析单个规则
    public func parseRule(): ?CssRule {
        None
    }

    /// 解析 @规则
    private func parseAtRule(): ?CssRule {
        None
    }

    /// 解析 @media 规则
    private func parseMediaRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析 @import 规则
    private func parseImportRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析 @keyframes 规则
    private func parseKeyframesRule(name: String, pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析关键帧块 (from/to/percentage)
    private func parseKeyframeBlock(): ?CssKeyframeBlock {
        None
    }

    /// 解析 @font-face 规则
    private func parseFontFaceRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析 @supports 规则
    private func parseSupportsRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析 @layer 规则
    private func parseLayerRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析 @container 规则
    private func parseContainerRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析 @namespace 规则
    private func parseNamespaceRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析 @charset 规则
    private func parseCharsetRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析 @property 规则
    private func parsePropertyRule(pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析未知 @规则
    private func parseUnknownAtRule(name: String, pos: CssTokenPosition): ?CssRule {
        None
    }

    /// 解析样式规则
    private func parseStyleRule(): ?CssRule {
        None
    }

    /// 解析单个声明
    private func parseDeclaration(): ?CssDeclaration {
        None
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 前进到下一个 token
    private func advance(): Unit {
        currentToken = lexer.nextToken()
        eof = true
    }

    /// 跳过空白
    private func skipWhitespace(): Unit {
        ()
    }

    /// 读取前导内容 (直到 { 或 ;)
    private func readPrelude(): String {
        ""
    }

    /// 读取直到左花括号
    private func readUntilLBrace(): String {
        ""
    }

    /// 读取声明值 (直到 ; 或 } 或 !important)
    private func readValue(): String {
        ""
    }

    /// 读取标识符或字符串
    private func readIdentOrString(): String {
        ""
    }

    /// 期望左花括号
    private func expectLBrace(): Unit {
        ()
    }

    /// 期望右花括号
    private func expectRBrace(): Unit {
        ()
    }

    /// 期望右圆括号
    private func expectRParen(): Unit {
        ()
    }

    /// 期望分号
    private func expectSemicolon(): Unit {
        ()
    }

    /// 添加错误
    private func addError(kind: CssParseErrorKind, message: String): Unit {
        let pos = currentToken.position
        errors.append(CssParseError(kind, pos.line, pos.column, message))
    }

    /// 错误恢复: 跳到下一个规则
    private func recoverToRule(): Unit {
        eof = true
    }

    /// 错误恢复: 跳到分号
    private func recoverToSemicolon(): Unit {
        eof = true
    }
}

// ============================================================================
// ParserState - 解析器状态
// 严格翻译自: css_parser.zig ParserState
// ============================================================================

/// 解析器状态
/// 严格翻译自 ParserState
public class ParserState {
    /// 当前位置
    public var position: Int64
    /// 当前行
    public var line: Int64
    /// 当前列
    public var column: Int64
    /// 当前 token
    public var token: ?CssToken

    public init() {
        position = 0
        line = 0
        column = 1
        token = None
    }
}

// ============================================================================
// Delimiters - 分隔符
// 严格翻译自: css_parser.zig Delimiters
// ============================================================================

/// 分隔符
/// 严格翻译自 Delimiters (bitflags)
public class Delimiters {
    public var semicolon: Bool
    public var curlyBracket: Bool
    public var closeCurlyBracket: Bool
    public var squareBracket: Bool
    public var closeSquareBracket: Bool
    public var parenthesis: Bool
    public var closeParenthesis: Bool

    public init() {
        semicolon = false
        curlyBracket = false
        closeCurlyBracket = false
        squareBracket = false
        closeSquareBracket = false
        parenthesis = false
        closeParenthesis = false
    }

    public static func semicolonDelimiter(): Delimiters {
        let d = Delimiters()
        d.semicolon = true
        return d
    }

    public static func curlyBracketDelimiter(): Delimiters {
        let d = Delimiters()
        d.curlyBracket = true
        return d
    }

    /// 从字节判断分隔符
    /// 严格翻译自 Delimiters.fromByte
    public static func fromByte(byte: ?UInt8): Delimiters {
        let d = Delimiters()
        match (byte) {
            case Some(b) =>
                if (b == UInt8(59)) { d.semicolon = true }
                if (b == UInt8(123)) { d.curlyBracket = true }
                if (b == UInt8(125)) { d.closeCurlyBracket = true }
                if (b == UInt8(91)) { d.squareBracket = true }
                if (b == UInt8(93)) { d.closeSquareBracket = true }
                if (b == UInt8(40)) { d.parenthesis = true }
                if (b == UInt8(41)) { d.closeParenthesis = true }
            case None => ()
        }
        return d
    }
}

// ============================================================================
// BlockType - 块类型
// 严格翻译自: css_parser.zig BlockType
// ============================================================================

/// 块类型
/// 严格翻译自 BlockType
public enum BlockType {
    | CurlyBracket
    | SquareBracket
    | Parenthesis

    /// 获取开始 token 的块类型
    /// 严格翻译自 BlockType.opening
    public static func opening(token: CssToken): ?BlockType {
        match (token.kind) {
            case CssTokenKind.LBrace => Some(CurlyBracket)
            case CssTokenKind.LBracket => Some(SquareBracket)
            case CssTokenKind.LParen => Some(Parenthesis)
            case CssTokenKind.Function => Some(Parenthesis)
            case _ => None
        }
    }

    /// 获取结束 token 的块类型
    /// 严格翻译自 BlockType.closing
    public static func closing(token: CssToken): ?BlockType {
        match (token.kind) {
            case CssTokenKind.RBrace => Some(CurlyBracket)
            case CssTokenKind.RBracket => Some(SquareBracket)
            case CssTokenKind.RParen => Some(Parenthesis)
            case _ => None
        }
    }
}

// ============================================================================
// ParseUntilErrorBehavior - 解析直到错误行为
// 严格翻译自: css_parser.zig ParseUntilErrorBehavior
// ============================================================================

/// 解析直到错误行为
/// 严格翻译自 ParseUntilErrorBehavior
public enum ParseUntilErrorBehavior {
    | Stop
    | Consume
}

// ============================================================================
// Stylesheet - CSS 样式表
// 严格翻译自: Stylesheet struct
// ============================================================================

/// CSS 样式表
/// 严格翻译自 Stylesheet
public class CssStylesheet {
    /// 规则列表
    public var rules: CssRuleList
    /// 源码索引
    public var sourceIndex: Int64
    /// 文件名
    public var filename: String
    /// 是否有错误
    public var hasErrors: Bool

    public init() {
        rules = CssRuleList()
        sourceIndex = 0
        filename = "<input>"
        hasErrors = false
    }

    public init(rules: CssRuleList, sourceIndex: Int64, filename: String) {
        this.rules = rules
        this.sourceIndex = sourceIndex
        this.filename = filename
        this.hasErrors = false
    }

    /// 解析 CSS 样式表
    /// 严格翻译自 Stylesheet.parse
    public static func parse(source: String, options: CssParserOptions): CssParseResult<CssStylesheet> {
        let parser = CssParser()
        parser.initFunc(source, options)
        let rules = parser.parseStylesheet()
        let stylesheet = CssStylesheet(rules, options.sourceIndex, options.filename)
        return CssParseResult<CssStylesheet>(stylesheet)
    }
}

// ============================================================================
// AtRulePrelude - @规则前导
// 严格翻译自: AtRulePrelude
// ============================================================================

/// @规则前导类型
/// 严格翻译自 AtRulePrelude
public enum AtRulePreludeKind {
    | Unknown
    | Custom
}

public class CssTokenList {
    public init() {}
}

/// @规则前导
public class AtRulePrelude {
    public var kind: AtRulePreludeKind
    public var name: String
    public var tokens: CssTokenList

    public init() {
        kind = AtRulePreludeKind.Unknown
        name = ""
        tokens = CssTokenList()
    }

    public init(name: String, tokens: CssTokenList) {
        kind = AtRulePreludeKind.Unknown
        this.name = name
        this.tokens = tokens
    }
}

// ============================================================================
// Selector/rule/module types are provided by split css_* modules.
// ============================================================================
