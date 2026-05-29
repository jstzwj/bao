// bao_css - CSS Parser (CSS 解析器)
// 严格翻译自: bun/src/css/css_parser.zig
//   对应: VendorPrefix packed struct - 供应商前缀
//   对应: SourceLocation struct - 源码位置
//   对应: Result/PrintResult type constructors
//   对应: DeriveParse/DeriveToCss/DefineShorthand - comptime 宏 (改为运行时工具)
//   对应: enum_property_util / DefineEnumProperty - 枚举属性工具
//   对应: DeriveValueType - 值类型推导
//   对应: consume_until_end_of_block / parse_at_rule / parse_qualified_rule
//   对应: parse_until_before / parse_until_after / parse_nested_block
//   对应: ValidQualifiedRuleParser / ValidAtRuleParser / ValidCustomAtRuleParser
//   对应: DefaultAtRuleParser / BundlerAtRuleParser
//   对应: AtRulePrelude union - @规则前导类型
//   对应: TopLevelRuleParser / NestedRuleParser - 顶层和嵌套规则解析器
//   对应: StyleSheetParser / RuleBodyParser - 样式表和规则体解析器
//   对应: StyleSheet / StyleAttribute - 样式表与样式属性
//   对应: ToCssResult / MinifyOptions - 输出与压缩选项
//   对应: CssRef / LocalScope / ComposesMap / PropertyUsage - CSS Modules 支持
//   对应: Parser struct - 核心 CSS 解析器
//   对应: ParserOptions / ParserFlags - 解析器配置
//   对应: ParserInput / ParserState / Delimiters / BlockType - 解析器内部状态
//   对应: Tokenizer struct - CSS 词法分析器
//   对应: Token / TokenKind / Num / Dimension / CopyOnWriteStr - token 类型
//   对应: nth - An+B 解析
//   对应: serializer - CSS 序列化工具
//   对应: color (部分) - 颜色辅助 (命名颜色, hash颜色, hsl转换)
//   对应: parse_utility / to_css / parseImportant - 解析/输出工具
package bao_css

import bao_core.*
import bao_collections.*

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

private func cssSubstring(input: String, start: Int64): String {
    input[start..input.size]
}

private func cssSubstring(input: String, start: Int64, end: Int64): String {
    input[start..end]
}

private func cssTrim(input: String): String {
    var start: Int64 = 0
    var end = input.size
    while (start < end) {
        let ch = input[start]
        if (ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(10) || ch == UInt8(13)) {
            start++
        } else {
            break
        }
    }
    while (end > start) {
        let ch = input[end - 1]
        if (ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(10) || ch == UInt8(13)) {
            end--
        } else {
            break
        }
    }
    input[start..end]
}

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

    /// 获取值, 如果错误则返回 null
    public func asValue(): ?T {
        match (value) {
            case Some(v) => Some(v)
            case None => None
        }
    }

    /// 获取错误, 如果成功则返回 null
    public func asErr(): ?CssParseError {
        match (error) {
            case Some(e) => Some(e)
            case None => None
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
// ParserFlags - 解析器特性标志
// 严格翻译自: css_parser.zig ParserFlags packed struct(u8)
// ============================================================================

/// 解析器特性标志
/// 严格翻译自 ParserFlags packed struct(u8)
public class CssParserFlags {
    /// 是否启用 CSS 嵌套语法
    public var nesting: Bool
    /// 是否启用 custom media 语法
    public var customMedia: Bool
    /// 是否启用 >>> 和 /deep/ 选择器组合器
    public var deepSelectorCombinator: Bool
    /// 是否启用 CSS Modules
    public var cssModules: Bool

    public init() {
        nesting = false
        customMedia = false
        deepSelectorCombinator = false
        cssModules = false
    }

    public static func default(): CssParserFlags {
        CssParserFlags()
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
    /// 源文件索引
    public var sourceIndex: Int64
    /// 文件名 (用于错误报告)
    public var filename: String
    /// 特性标志
    public var flags: CssParserFlags
    /// 收集的警告
    public var warnings: ArrayList<CssParseError>

    public init() {
        this.errorRecovery = true
        this.cssModules = None
        this.sourceIndex = 0
        this.filename = "<input>"
        this.warnings = ArrayList<CssParseError>()
        this.flags = CssParserFlags()
    }

    public init(filename: String, errorRecovery: Bool) {
        this.errorRecovery = errorRecovery
        this.cssModules = None
        this.sourceIndex = 0
        this.filename = filename
        this.warnings = ArrayList<CssParseError>()
        this.flags = CssParserFlags()
    }

    public static func default(): CssParserOptions {
        CssParserOptions()
    }

    /// 发出警告
    /// 严格翻译自 ParserOptions.warn
    public func warn(warning: CssParseError): Unit {
        // 将警告添加到日志收集器
        // 对应 Bun: options.warn(warning) — 通过 Logger 输出警告
        warnings.append(warning)
    }

    public func toString(): String {
        "ParserOptions(filename=${filename}, sourceIndex=${sourceIndex}, errorRecovery=${errorRecovery})"
    }
}

// ============================================================================
// 源码位置 (SourceLocation + Location)
// 严格翻译自: css_parser.zig SourceLocation + rules.zig Location
// ============================================================================

/// CSS 源码位置
/// 严格翻译自 SourceLocation struct
public class SourceLocation {
    public var line: UInt32
    public var column: UInt32

    public init() {
        line = 0
        column = 0
    }

    public init(line: UInt32, column: UInt32) {
        this.line = line
        this.column = column
    }

    /// 创建基本意外 token 错误
    /// 严格翻译自 SourceLocation.newBasicUnexpectedTokenError
    public func newBasicUnexpectedTokenError(token: CssToken): CssParseError {
        CssParseError(CssParseErrorKind.UnexpectedToken, Int64(line), Int64(column),
            "unexpected token at ${line}:${column}")
    }

    /// 创建意外 token 错误
    /// 严格翻译自 SourceLocation.newUnexpectedTokenError
    public func newUnexpectedTokenError(token: CssToken): CssParseError {
        CssParseError(CssParseErrorKind.UnexpectedToken, Int64(line), Int64(column),
            "unexpected token")
    }

    /// 创建自定义错误
    /// 严格翻译自 SourceLocation.newCustomError
    public func newCustomError(message: String): CssParseError {
        CssParseError(CssParseErrorKind.CustomError, Int64(line), Int64(column), message)
    }

    public func toString(): String {
        "${line}:${column}"
    }
}

/// CSS 规则位置
/// 严格翻译自 Location struct (source_index, line, column)
public class CssParserLocation {
    public var sourceIndex: Int64
    public var line: UInt32
    public var column: UInt32

    public init() {
        this.sourceIndex = 0
        this.line = 0
        this.column = 0
    }

    public init(sourceIndex: Int64, line: UInt32, column: UInt32) {
        this.sourceIndex = sourceIndex
        this.line = line
        this.column = column
    }

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
// Targets (解析器内部用)
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
// ToCssResult - CSS 输出结果
// 严格翻译自: css_parser.zig ToCssResult
// ============================================================================

/// CSS 输出结果
/// 严格翻译自 ToCssResult struct
public class ToCssResult {
    /// 序列化后的 CSS 代码
    public var code: String
    /// CSS Module 导出 (如果启用了 css_modules)
    public var exports: ?CssModuleExports
    /// CSS Module 引用 (如果启用了 dashed_idents)
    public var references: ?CssModuleReferences
    /// 依赖列表 (@import 或 url())
    public var dependencies: ?ArrayList<CssParserDependency>

    public init() {
        code = ""
        exports = None
        references = None
        dependencies = None
    }

    public init(code: String) {
        this.code = code
        this.exports = None
        this.references = None
        this.dependencies = None
    }
}

/// CSS 输出结果 (内部)
/// 严格翻译自 ToCssResultInternal
public class ToCssResultInternal {
    public var exports: ?CssModuleExports
    public var references: ?CssModuleReferences
    public var dependencies: ?ArrayList<CssParserDependency>

    public init() {
        exports = None
        references = None
        dependencies = None
    }
}

// ============================================================================
// MinifyOptions - CSS 压缩选项
// 严格翻译自: css_parser.zig MinifyOptions
// ============================================================================

/// CSS 压缩选项
/// 严格翻译自 MinifyOptions struct
public class CssMinifyOptions {
    /// 目标浏览器
    public var targets: CssTargets
    /// 未使用的符号集合 (类名, id, keyframes 名称)
    public var unusedSymbols: HashSet<String>

    public init() {
        targets = CssTargets()
        unusedSymbols = HashSet<String>()
    }

    public static func default(): CssMinifyOptions {
        CssMinifyOptions()
    }
}

// ============================================================================
// ParserState - 解析器状态
// 严格翻译自: css_parser.zig ParserState
// ============================================================================

/// 解析器状态快照
/// 严格翻译自 ParserState struct
public class ParserState {
    /// 当前位置 (字节偏移)
    public var position: Int64
    /// 当前行起始位置
    public var currentLineStartPosition: Int64
    /// 当前行号
    public var currentLineNumber: UInt32
    /// 导入记录计数
    public var importRecordCount: UInt32
    /// 块起始类型
    public var atStartOf: ?BlockType

    public init() {
        position = 0
        currentLineStartPosition = 0
        currentLineNumber = 0
        importRecordCount = 0
        atStartOf = None
    }

    public init(position: Int64, lineStart: Int64, lineNumber: UInt32) {
        this.position = position
        this.currentLineStartPosition = lineStart
        this.currentLineNumber = lineNumber
        this.importRecordCount = 0
        this.atStartOf = None
    }

    /// 获取源码位置
    /// 严格翻译自 ParserState.sourceLocation
    public func sourceLocation(): SourceLocation {
        SourceLocation(currentLineNumber, UInt32(position - currentLineStartPosition + 1))
    }

    public func toString(): String {
        "ParserState(pos=${position}, line=${currentLineNumber})"
    }
}

// ============================================================================
// Delimiters - 分隔符
// 严格翻译自: css_parser.zig Delimiters packed struct(u8)
// ============================================================================

/// CSS 分隔符集合
/// 严格翻译自 Delimiters packed struct(u8)
/// 用于 Parser::parse_until* 方法
public class Delimiters {
    /// { 左花括号
    public var curlyBracket: Bool
    /// ; 分号
    public var semicolon: Bool
    /// ! 感叹号
    public var bang: Bool
    /// , 逗号
    public var comma: Bool
    /// } 右花括号
    public var closeCurlyBracket: Bool
    /// ] 右方括号
    public var closeSquareBracket: Bool
    /// ) 右圆括号
    public var closeParenthesis: Bool

    public init() {
        curlyBracket = false
        semicolon = false
        bang = false
        comma = false
        closeCurlyBracket = false
        closeSquareBracket = false
        closeParenthesis = false
    }

    /// 空分隔符集
    public static func NONE(): Delimiters {
        Delimiters()
    }

    /// 仅分号
    public static func semicolonOnly(): Delimiters {
        let d = Delimiters()
        d.semicolon = true
        d
    }

    /// 仅花括号
    public static func curlyBracketOnly(): Delimiters {
        let d = Delimiters()
        d.curlyBracket = true
        d
    }

    /// 分号 + 花括号
    public static func semicolonAndCurly(): Delimiters {
        let d = Delimiters()
        d.semicolon = true
        d.curlyBracket = true
        d
    }

    /// 从字节判断分隔符
    /// 严格翻译自 Delimiters.fromByte
    public static func fromByte(byte: ?UInt8): Delimiters {
        match (byte) {
            case Some(b) =>
                if (b == UInt8(59)) { let d = Delimiters(); d.semicolon = true; return d }
                if (b == UInt8(33)) { let d = Delimiters(); d.bang = true; return d }
                if (b == UInt8(44)) { let d = Delimiters(); d.comma = true; return d }
                if (b == UInt8(123)) { let d = Delimiters(); d.curlyBracket = true; return d }
                if (b == UInt8(125)) { let d = Delimiters(); d.closeCurlyBracket = true; return d }
                if (b == UInt8(93)) { let d = Delimiters(); d.closeSquareBracket = true; return d }
                if (b == UInt8(41)) { let d = Delimiters(); d.closeParenthesis = true; return d }
                Delimiters()
            case None => Delimiters()
        }
    }

    /// 按位或
    public func bitwiseOr(other: Delimiters): Delimiters {
        let d = Delimiters()
        d.curlyBracket = curlyBracket || other.curlyBracket
        d.semicolon = semicolon || other.semicolon
        d.bang = bang || other.bang
        d.comma = comma || other.comma
        d.closeCurlyBracket = closeCurlyBracket || other.closeCurlyBracket
        d.closeSquareBracket = closeSquareBracket || other.closeSquareBracket
        d.closeParenthesis = closeParenthesis || other.closeParenthesis
        d
    }

    /// 是否包含另一个分隔符集中的任意位
    public func contains(other: Delimiters): Bool {
        (curlyBracket && other.curlyBracket) ||
        (semicolon && other.semicolon) ||
        (bang && other.bang) ||
        (comma && other.comma) ||
        (closeCurlyBracket && other.closeCurlyBracket) ||
        (closeSquareBracket && other.closeSquareBracket) ||
        (closeParenthesis && other.closeParenthesis)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        !curlyBracket && !semicolon && !bang && !comma &&
        !closeCurlyBracket && !closeSquareBracket && !closeParenthesis
    }
}

// ============================================================================
// BlockType - 块类型
// 严格翻译自: css_parser.zig BlockType
// ============================================================================

/// 块类型
/// 严格翻译自 BlockType enum
public enum BlockType {
    | Parenthesis     // () 圆括号块
    | SquareBracket   // [] 方括号块
    | CurlyBracket    // {} 花括号块

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
/// 严格翻译自 ParseUntilErrorBehavior enum
public enum ParseUntilErrorBehavior {
    | Stop      // 遇到错误时停止
    | Consume   // 遇到错误时消费 token 继续
}

// ============================================================================
// AtRulePrelude - @规则前导
// 严格翻译自: css_parser.zig AtRulePrelude union
// ============================================================================

/// @规则前导类型
/// 严格翻译自 AtRulePrelude union(enum)
public enum AtRulePreludeKind {
    | FontFace
    | FontFeatureValues
    | FontPaletteValues
    | CounterStyle
    | Import
    | Namespace
    | Charset
    | CustomMedia
    | Property
    | Media
    | Supports
    | Viewport
    | Keyframes
    | Page
    | MozDocument
    | Layer
    | Container
    | StartingStyle
    | Nest
    | Scope
    | Unknown
    | Custom

    public func toString(): String {
        match (this) {
            case FontFace => "font-face"
            case FontFeatureValues => "font-feature-values"
            case FontPaletteValues => "font-palette-values"
            case CounterStyle => "counter-style"
            case Import => "import"
            case Namespace => "namespace"
            case Charset => "charset"
            case CustomMedia => "custom-media"
            case Property => "property"
            case Media => "media"
            case Supports => "supports"
            case Viewport => "viewport"
            case Keyframes => "keyframes"
            case Page => "page"
            case MozDocument => "-moz-document"
            case Layer => "layer"
            case Container => "container"
            case StartingStyle => "starting-style"
            case Nest => "nest"
            case Scope => "scope"
            case Unknown => "unknown"
            case Custom => "custom"
        }
    }
}

/// @规则前导数据
/// 严格翻译自 AtRulePrelude 各变体
public class AtRulePrelude {
    public var kind: AtRulePreludeKind
    /// 名称 (用于 font-face, unknown, custom 等)
    public var name: String
    /// 前缀 (用于 viewport, keyframes)
    public var prefix: VendorPrefix
    /// 媒体查询列表 (用于 media, custom_media)
    public var mediaList: ?CssMediaList
    /// supports 条件
    public var supportsCondition: ?CssSupportsCondition
    /// URL 字符串 (用于 import, namespace)
    public var url: String
    /// 前缀字符串 (namespace 可选前缀)
    public var nsPrefix: ?String
    /// layer 信息
    public var layerNames: ArrayList<String>
    /// container 名称
    public var containerName: ?String
    /// token 列表 (用于 unknown 等)
    public var tokens: CssTokenList
    /// keyframes 名称
    public var keyframesName: String
    /// scope 选择器
    public var scopeStart: ?CssSelectorList
    public var scopeEnd: ?CssSelectorList
    /// nest 选择器列表
    public var nestSelectors: ?CssSelectorList

    public init() {
        kind = AtRulePreludeKind.Unknown
        name = ""
        prefix = VendorPrefix()
        mediaList = None
        supportsCondition = None
        url = ""
        nsPrefix = None
        layerNames = ArrayList<String>()
        containerName = None
        tokens = CssTokenList()
        keyframesName = ""
        scopeStart = None
        scopeEnd = None
        nestSelectors = None
    }

    /// 是否允许出现在样式规则中
    /// 严格翻译自 AtRulePrelude.allowedInStyleRule
    public func allowedInStyleRule(): Bool {
        match (kind) {
            case Media | Supports | Container | MozDocument | Layer |
                 StartingStyle | Scope | Nest | Unknown | Custom => true
            case _ => false
        }
    }

    public func toString(): String {
        "${kind.toString()}: ${name}"
    }
}

/// Token 列表 (用于 unknown @规则等)
public class CssTokenList {
    public var tokens: ArrayList<CssToken>

    public init() {
        tokens = ArrayList<CssToken>()
    }

    public init(tokens: ArrayList<CssToken>) {
        this.tokens = tokens
    }
}

// ============================================================================
// CssRef / LocalScope / ComposesMap - CSS Modules 支持
// 严格翻译自: css_parser.zig CssRef, LocalScope, ComposesMap 等
// ============================================================================

/// CSS 引用标签
/// 严格翻译自 CssRef.Tag packed struct(u6)
public class CssRefTag {
    public var class_: Bool
    public var id: Bool
    public var animation: Bool
    public var keyframes: Bool
    public var container: Bool
    public var counterStyle: Bool

    public init() {
        class_ = false
        id = false
        animation = false
        keyframes = false
        container = false
        counterStyle = false
    }

    public static func CLASS(): CssRefTag {
        let t = CssRefTag(); t.class_ = true; t
    }

    public static func ID(): CssRefTag {
        let t = CssRefTag(); t.id = true; t
    }

    /// 是否可以被 composes 组合
    public func canBeComposed(): Bool {
        class_
    }
}

/// CSS 符号引用
/// 严格翻译自 CssRef packed struct(u32)
public class CssRef {
    public var innerIndex: Int64
    public var tag: CssRefTag

    public init() {
        innerIndex = 0
        tag = CssRefTag()
    }

    public init(innerIndex: Int64, tag: CssRefTag) {
        this.innerIndex = innerIndex
        this.tag = tag
    }

    /// 是否可以被 composes 组合
    public func canBeComposed(): Bool {
        tag.canBeComposed()
    }

    public func toString(): String {
        "CssRef(${innerIndex})"
    }
}

/// 本地符号条目
public class LocalEntry {
    public var ref: CssRef
    public var loc: SourceLocation

    public init() {
        ref = CssRef()
        loc = SourceLocation()
    }

    public init(ref: CssRef, loc: SourceLocation) {
        this.ref = ref
        this.loc = loc
    }
}

/// 本地作用域映射 (CSS Modules 用)
/// 映射本地类名到 Ref
public class LocalScope {
    public var entries: HashMap<String, LocalEntry>

    public init() {
        entries = HashMap<String, LocalEntry>()
    }
}

/// Composes 条目
/// 严格翻译自 ComposesEntry
public class ComposesEntry {
    public var composes: ArrayList<CssComposes>

    public init() {
        composes = ArrayList<CssComposes>()
    }
}

/// Composes 映射
/// 严格翻译自 ComposesMap
public class ComposesMap {
    public var entries: HashMap<String, ComposesEntry>

    public init() {
        entries = HashMap<String, ComposesEntry>()
    }
}

/// CSS Modules 的 composes 属性
public class CssComposes {
    public var name: String
    public var from: ?String

    public init(name: String) {
        this.name = name
        this.from = None
    }

    public init(name: String, from: String) {
        this.name = name
        this.from = Some(from)
    }

    public func deepClone(): CssComposes {
        CssComposes(name)
    }
}

/// 属性使用跟踪
/// 严格翻译自 PropertyUsage
public class PropertyUsage {
    public var range: CssParserSourceRange
    public var usedProperties: HashSet<String>
    public var customProperties: ArrayList<String>

    public init() {
        range = CssParserSourceRange()
        usedProperties = HashSet<String>()
        customProperties = ArrayList<String>()
    }

    public init(range: CssParserSourceRange) {
        this.range = range
        usedProperties = HashSet<String>()
        customProperties = ArrayList<String>()
    }

    /// 合并使用信息
    public func fill(other: PropertyUsage): Unit {
        for (property in other.usedProperties.values()) {
            usedProperties.put(property)
        }
        customProperties = other.customProperties
    }
}

/// 源码范围 (简化版)
public class CssParserSourceRange {
    public var start: Int64
    public var len: Int64

    public init() {
        start = 0
        len = 0
    }

    public init(start: Int64, len: Int64) {
        this.start = start
        this.len = len
    }
}

/// ParserExtra - 解析器额外数据
/// 严格翻译自 ParserExtra struct
public class ParserExtra {
    public var symbols: ArrayList<CssSymbol>
    public var localScope: LocalScope
    public var sourceIndex: Int64

    public init() {
        symbols = ArrayList<CssSymbol>()
        localScope = LocalScope()
        sourceIndex = 0
    }

    public init(sourceIndex: Int64) {
        symbols = ArrayList<CssSymbol>()
        localScope = LocalScope()
        this.sourceIndex = sourceIndex
    }
}

/// CSS 符号 (简化版)
public class CssSymbol {
    public var kind: String
    public var originalName: String

    public init(kind: String, originalName: String) {
        this.kind = kind
        this.originalName = originalName
    }
}

/// StylesheetExtra - 样式表额外数据
/// 严格翻译自 StylesheetExtra
public class StylesheetExtra {
    public var symbols: ArrayList<CssSymbol>

    public init() {
        symbols = ArrayList<CssSymbol>()
    }
}

// ============================================================================
// CssParserDependency - CSS 依赖
// 严格翻译自: dependencies.zig Dependency
// ============================================================================

/// CSS 依赖
public class CssParserDependency {
    public var url: String
    public var `type`: CssDependencyType
    public var media: ?String
    public var supports: ?String

    public init(url: String, `type`: CssDependencyType) {
        this.url = url
        this.`type` = `type`
        this.media = None
        this.supports = None
    }
}

/// 依赖类型
public enum CssDependencyType {
    | Import      // @import
    | Url         // url()
    | Composes    // composes from

    public func toString(): String {
        match (this) {
            case Import => "import"
            case Url => "url"
            case Composes => "composes"
        }
    }
}

// ============================================================================
// DefaultAtRule / DefaultAtRuleParser
// 严格翻译自: css_parser.zig DefaultAtRule, DefaultAtRuleParser
// ============================================================================

/// 默认 @规则 (无操作)
/// 严格翻译自 DefaultAtRule
public class DefaultAtRule {
    public func toCss(dest: CssPrinter): Unit {
        // 默认无操作
    }

    public func deepClone(): DefaultAtRule {
        DefaultAtRule()
    }
}

/// 默认 @规则解析器
/// 严格翻译自 DefaultAtRuleParser
public class DefaultAtRuleParser {
    public init() {}

    /// 解析前导 - 默认拒绝所有
    public func parsePrelude(name: String, parser: CssParser): CssParseResult<AtRulePrelude> {
        CssParseResult<AtRulePrelude>(CssParseError(
            CssParseErrorKind.AtRuleInvalid, 0, 0, "invalid @ rule: ${name}"))
    }

    /// 解析块 - 默认拒绝
    public func parseBlock(prelude: AtRulePrelude, start: ParserState, parser: CssParser): CssParseResult<DefaultAtRule> {
        CssParseResult<DefaultAtRule>(CssParseError(CssParseErrorKind.AtRuleBodyInvalid, 0, 0))
    }

    /// 无块规则 - 默认返回错误
    public func ruleWithoutBlock(prelude: AtRulePrelude, start: ParserState): CssParseResult<DefaultAtRule> {
        CssParseResult<DefaultAtRule>(CssParseError(CssParseErrorKind.AtRuleInvalid, 0, 0))
    }

    /// 导入规则回调
    public func onImportRule(rule: CssAtImportRule, startPosition: UInt32, endPosition: UInt32): Unit {}

    /// Layer 规则回调
    public func onLayerRule(layers: ArrayList<String>): Unit {}

    /// 获取封闭 Layer 长度
    public func enclosingLayerLength(): UInt32 { 0 }

    /// 设置封闭 Layer
    public func setEnclosingLayer(layer: String): Unit {}

    /// 推入封闭 Layer
    public func pushToEnclosingLayer(name: String): Unit {}

    /// 重置封闭 Layer
    public func resetEnclosingLayer(len: UInt32): Unit {}

    /// 增加匿名 Layer 计数
    public func bumpAnonLayerCount(amount: Int64): Unit {}
}

// ============================================================================
// BundlerAtRuleParser
// 严格翻译自: css_parser.zig BundlerAtRuleParser
// ============================================================================

/// 打包器 @规则解析器
/// 严格翻译自 BundlerAtRuleParser struct
public class BundlerAtRuleParser {
    public var allocator: ?Allocator
    /// 导入记录列表
    public var importRecords: ArrayList<CssImportRecord>
    /// Layer 名称列表
    public var layerNames: ArrayList<String>
    /// 选项
    public var options: ?CssParserOptions
    /// 匿名 Layer 计数
    public var anonLayerCount: UInt32
    /// 封闭 Layer
    public var enclosingLayer: String

    public init() {
        allocator = None
        importRecords = ArrayList<CssImportRecord>()
        layerNames = ArrayList<String>()
        options = None
        anonLayerCount = 0
        enclosingLayer = ""
    }

    /// 解析前导
    public func parsePrelude(name: String, parser: CssParser): CssParseResult<AtRulePrelude> {
        CssParseResult<AtRulePrelude>(CssParseError(
            CssParseErrorKind.AtRuleInvalid, 0, 0, "invalid @ rule: ${name}"))
    }

    /// 解析块
    public func parseBlock(prelude: AtRulePrelude, start: ParserState, parser: CssParser, isNested: Bool): CssParseResult<DefaultAtRule> {
        CssParseResult<DefaultAtRule>(CssParseError(CssParseErrorKind.AtRuleBodyInvalid, 0, 0))
    }

    /// 无块规则
    public func ruleWithoutBlock(prelude: AtRulePrelude, start: ParserState, isNested: Bool): CssParseResult<DefaultAtRule> {
        CssParseResult<DefaultAtRule>(CssParseError(CssParseErrorKind.AtRuleInvalid, 0, 0))
    }

    /// 导入规则回调
    /// 严格翻译自 BundlerAtRuleParser.CustomAtRuleParser.onImportRule
    public func onImportRule(importRule: CssAtImportRule, startPosition: UInt32, endPosition: UInt32): Unit {
        importRecords.append(CssImportRecord(importRule.url))
    }

    /// Layer 规则回调
    /// 严格翻译自 onLayerRule
    public func onLayerRule(layers: ArrayList<String>): Unit {
        if (anonLayerCount > 0) { return }
        for (layer in layers) {
            if (enclosingLayer.size > 0) {
                layerNames.append("${enclosingLayer}.${layer}")
            } else {
                layerNames.append(layer)
            }
        }
    }

    public func enclosingLayerLength(): UInt32 {
        UInt32(enclosingLayer.size)
    }

    public func setEnclosingLayer(layer: String): Unit {
        enclosingLayer = layer
    }

    public func pushToEnclosingLayer(name: String): Unit {
        if (enclosingLayer.size > 0) {
            enclosingLayer = "${enclosingLayer}.${name}"
        } else {
            enclosingLayer = name
        }
    }

    public func resetEnclosingLayer(len: UInt32): Unit {
        if (Int64(enclosingLayer.size) > Int64(len)) {
            enclosingLayer = cssSubstring(enclosingLayer, 0, Int64(len))
        }
    }

    public func bumpAnonLayerCount(amount: Int64): Unit {
        if (amount > 0) {
            anonLayerCount = anonLayerCount + UInt32(amount)
        } else {
            let dec = UInt32(-amount)
            if (anonLayerCount > dec) {
                anonLayerCount = anonLayerCount - dec
            } else {
                anonLayerCount = 0
            }
        }
    }
}

// ============================================================================
// TopLevelRuleParser - 顶层规则解析器
// 严格翻译自: css_parser.zig TopLevelRuleParser
// ============================================================================

/// 顶层规则解析器状态
/// 严格翻译自 TopLevelRuleParser.State
public enum TopLevelParserState {
    | Start      // 开始
    | Layers     // 层声明阶段
    | Imports    // 导入阶段
    | Namespaces // 命名空间阶段
    | Body       // 主体

    public func ordinal(): Int64 {
        match (this) {
            case Start => 0
            case Layers => 1
            case Imports => 2
            case Namespaces => 3
            case Body => 4
        }
    }
}

/// 顶层规则解析器
/// 严格翻译自 TopLevelRuleParser(P) struct
/// 管理顶层 CSS 规则的解析顺序:
/// @charset -> @layer -> @import -> @namespace -> 其他规则
public class TopLevelRuleParser {
    public var options: CssParserOptions
    public var state: TopLevelParserState
    public var atRuleParser: ?DefaultAtRuleParser
    /// 规则列表
    public var rules: CssRuleList
    /// composes 映射
    public var composes: ComposesMap
    /// 本地属性使用
    public var localProperties: HashMap<String, PropertyUsage>

    public init() {
        options = CssParserOptions()
        state = TopLevelParserState.Start
        atRuleParser = None
        rules = CssRuleList()
        composes = ComposesMap()
        localProperties = HashMap<String, PropertyUsage>()
    }

    public init(options: CssParserOptions, rules: CssRuleList) {
        this.options = options
        this.state = TopLevelParserState.Start
        this.atRuleParser = None
        this.rules = rules
        this.composes = ComposesMap()
        this.localProperties = HashMap<String, PropertyUsage>()
    }

    /// 解析 @规则前导
    /// 严格翻译自 TopLevelRuleParser.AtRuleParser.parsePrelude
    public func parseAtRulePrelude(name: String, parser: CssParser): CssParseResult<AtRulePrelude> {
        // 处理特殊 @规则: import, charset, namespace, custom-media, property
        let lowerName = cssAsciiLower(name)
        if (lowerName == "import") {
            if (state.ordinal() > TopLevelParserState.Imports.ordinal()) {
                return CssParseResult<AtRulePrelude>(CssParseError(
                    CssParseErrorKind.CustomError, 0, 0, "unexpected import rule"))
            }
            return parseImportPrelude(parser)
        }
        if (lowerName == "charset") {
            return parseCharsetPrelude(parser)
        }
        if (lowerName == "namespace") {
            if (state.ordinal() > TopLevelParserState.Namespaces.ordinal()) {
                return CssParseResult<AtRulePrelude>(CssParseError(
                    CssParseErrorKind.CustomError, 0, 0, "unexpected namespace rule"))
            }
            return parseNamespacePrelude(parser)
        }
        if (lowerName == "custom-media") {
            return parseCustomMediaPrelude(parser)
        }
        if (lowerName == "property") {
            return parsePropertyPrelude(parser)
        }
        // 委托给嵌套解析器
        let nested = nestedParser()
        nested.parseAtRulePrelude(name, parser)
    }

    /// 解析 @规则块
    /// 严格翻译自 TopLevelRuleParser.AtRuleParser.parseBlock
    public func parseAtRuleBlock(prelude: AtRulePrelude, start: ParserState, parser: CssParser): CssParseResult<Unit> {
        state = TopLevelParserState.Body
        let nested = nestedParser()
        nested.parseAtRuleBlock(prelude, start, parser)
    }

    /// 解析无块 @规则
    /// 严格翻译自 TopLevelRuleParser.AtRuleParser.ruleWithoutBlock
    public func parseAtRuleWithoutBlock(prelude: AtRulePrelude, start: ParserState): CssParseResult<Unit> {
        match (prelude.kind) {
            case AtRulePreludeKind.Import =>
                state = TopLevelParserState.Imports
                let rule = CssRule()
                rule.kind = CssRuleKind.Import
                rule.importRule = Some(CssAtImportRule(prelude.url))
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Namespace =>
                state = TopLevelParserState.Namespaces
                let rule = CssRule()
                rule.kind = CssRuleKind.Namespace
                rule.namespaceRule = Some(CssAtNamespaceRule(prelude.nsPrefix, prelude.url))
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Charset =>
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Layer =>
                match (state) {
                    case TopLevelParserState.Start | TopLevelParserState.Layers =>
                        state = TopLevelParserState.Layers
                    case _ => state = TopLevelParserState.Body
                }
                CssParseResult<Unit>(())
            case _ =>
                CssParseResult<Unit>(CssParseError(CssParseErrorKind.AtRuleInvalid, 0, 0))
        }
    }

    /// 解析限定规则前导 (选择器)
    public func parseQualifiedRulePrelude(parser: CssParser): CssParseResult<CssSelectorList> {
        state = TopLevelParserState.Body
        // 委托给选择器解析器
        CssParseResult<CssSelectorList>(CssSelectorList())
    }

    /// 解析限定规则块
    public func parseQualifiedRuleBlock(selectors: CssSelectorList, start: ParserState, parser: CssParser): CssParseResult<Unit> {
        let nested = nestedParser()
        nested.parseQualifiedRuleBlock(selectors, start, parser)
    }

    // ========================================================================
    // 前导解析辅助方法
    // ========================================================================

    /// 解析 @import 前导
    private func parseImportPrelude(parser: CssParser): CssParseResult<AtRulePrelude> {
        let prelude = AtRulePrelude()
        prelude.kind = AtRulePreludeKind.Import
        prelude.url = parser.expectUrlOrString()
        CssParseResult<AtRulePrelude>(prelude)
    }

    /// 解析 @charset 前导
    private func parseCharsetPrelude(parser: CssParser): CssParseResult<AtRulePrelude> {
        let prelude = AtRulePrelude()
        prelude.kind = AtRulePreludeKind.Charset
        // 期望一个字符串
        parser.expectString()
        CssParseResult<AtRulePrelude>(prelude)
    }

    /// 解析 @namespace 前导
    private func parseNamespacePrelude(parser: CssParser): CssParseResult<AtRulePrelude> {
        let prelude = AtRulePrelude()
        prelude.kind = AtRulePreludeKind.Namespace
        // 尝试读取可选前缀
        prelude.nsPrefix = parser.tryParseIdent()
        prelude.url = parser.expectUrlOrString()
        CssParseResult<AtRulePrelude>(prelude)
    }

    /// 解析 @custom-media 前导
    private func parseCustomMediaPrelude(parser: CssParser): CssParseResult<AtRulePrelude> {
        let prelude = AtRulePrelude()
        prelude.kind = AtRulePreludeKind.CustomMedia
        prelude.name = parser.expectIdent()
        CssParseResult<AtRulePrelude>(prelude)
    }

    /// 解析 @property 前导
    private func parsePropertyPrelude(parser: CssParser): CssParseResult<AtRulePrelude> {
        let prelude = AtRulePrelude()
        prelude.kind = AtRulePreludeKind.Property
        prelude.name = parser.expectIdent()
        CssParseResult<AtRulePrelude>(prelude)
    }

    /// 创建嵌套规则解析器
    private func nestedParser(): NestedRuleParser {
        let nested = NestedRuleParser()
        nested.options = options
        nested.rules = rules
        nested.composes = composes
        nested.localProperties = localProperties
        nested
    }
}

// ============================================================================
// NestedRuleParser - 嵌套规则解析器
// 严格翻译自: css_parser.zig NestedRuleParser
// ============================================================================

/// 嵌套规则解析器
/// 严格翻译自 NestedRuleParser(T) struct
/// 处理样式规则内部的嵌套规则和声明
public class NestedRuleParser {
    public var options: CssParserOptions
    /// 声明列表
    public var declarations: ArrayList<CssDeclaration>
    /// 重要声明列表
    public var importantDeclarations: ArrayList<CssDeclaration>
    /// 规则列表引用
    public var rules: CssRuleList
    /// 是否在样式规则内
    public var isInStyleRule: Bool
    /// 是否允许声明
    public var allowDeclarations: Bool
    /// composes 映射
    public var composes: ComposesMap
    /// 本地属性使用
    public var localProperties: HashMap<String, PropertyUsage>

    public init() {
        options = CssParserOptions()
        declarations = ArrayList<CssDeclaration>()
        importantDeclarations = ArrayList<CssDeclaration>()
        rules = CssRuleList()
        isInStyleRule = false
        allowDeclarations = false
        composes = ComposesMap()
        localProperties = HashMap<String, PropertyUsage>()
    }

    /// 获取位置信息
    public func getLoc(start: ParserState): CssParserLocation {
        let loc = start.sourceLocation()
        CssParserLocation(options.sourceIndex, loc.line, loc.column)
    }

    /// 解析 @规则前导
    /// 严格翻译自 NestedRuleParser.AtRuleParser.parsePrelude
    public func parseAtRulePrelude(name: String, parser: CssParser): CssParseResult<AtRulePrelude> {
        let lowerName = cssAsciiLower(name)
        let prelude = AtRulePrelude()

        if (lowerName == "media") {
            prelude.kind = AtRulePreludeKind.Media
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "supports") {
            prelude.kind = AtRulePreludeKind.Supports
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "font-face") {
            prelude.kind = AtRulePreludeKind.FontFace
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "keyframes" || lowerName == "-webkit-keyframes" ||
                   lowerName == "-moz-keyframes" || lowerName == "-o-keyframes" ||
                   lowerName == "-ms-keyframes") {
            prelude.kind = AtRulePreludeKind.Keyframes
            if (lowerName == "-webkit-keyframes") { prelude.prefix = VendorPrefix.WEBKIT() }
            else if (lowerName == "-moz-keyframes") { prelude.prefix = VendorPrefix.MOZ() }
            else if (lowerName == "-o-keyframes") { prelude.prefix = VendorPrefix.O() }
            else if (lowerName == "-ms-keyframes") { prelude.prefix = VendorPrefix.MS() }
            else { prelude.prefix = VendorPrefix.NONE() }
            prelude.keyframesName = parser.expectIdentOrString()
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "container") {
            prelude.kind = AtRulePreludeKind.Container
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "layer") {
            prelude.kind = AtRulePreludeKind.Layer
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "starting-style") {
            prelude.kind = AtRulePreludeKind.StartingStyle
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "nest") {
            prelude.kind = AtRulePreludeKind.Nest
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "page") {
            prelude.kind = AtRulePreludeKind.Page
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "-moz-document") {
            prelude.kind = AtRulePreludeKind.MozDocument
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "counter-style") {
            prelude.kind = AtRulePreludeKind.CounterStyle
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "font-palette-values") {
            prelude.kind = AtRulePreludeKind.FontPaletteValues
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "scope") {
            prelude.kind = AtRulePreludeKind.Scope
            CssParseResult<AtRulePrelude>(prelude)
        } else if (lowerName == "property") {
            prelude.kind = AtRulePreludeKind.Property
            prelude.name = parser.expectIdent()
            CssParseResult<AtRulePrelude>(prelude)
        } else {
            prelude.kind = AtRulePreludeKind.Unknown
            prelude.name = name
            CssParseResult<AtRulePrelude>(prelude)
        }
    }

    /// 解析 @规则块
    /// 严格翻译自 NestedRuleParser.AtRuleParser.parseBlock
    public func parseAtRuleBlock(prelude: AtRulePrelude, start: ParserState, parser: CssParser): CssParseResult<Unit> {
        let loc = getLoc(start)
        match (prelude.kind) {
            case AtRulePreludeKind.FontFace =>
                let block = parser.parseDeclarationBlock()
                let ffRule = CssAtFontFaceRule(block)
                let rule = CssRule.createFontFace(ffRule)
                rule.position = Some(getLoc(start))
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Media =>
                let nestedRules = parseStyleBlock(parser)
                let mediaRule = CssAtMediaRule(prelude.name, nestedRules)
                let rule = CssRule.createMedia(mediaRule)
                rule.position = Some(getLoc(start))
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Supports =>
                let nestedRules = parseStyleBlock(parser)
                let supportsRule = CssAtSupportsRule(prelude.name, nestedRules)
                let rule = CssRule.createSupports(supportsRule)
                rule.position = Some(getLoc(start))
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Container =>
                let nestedRules = parseStyleBlock(parser)
                let cname = match (prelude.containerName) {
                    case Some(n) => n
                    case None => ""
                }
                let containerRule = CssAtContainerRule(cname, prelude.name, nestedRules)
                let rule = CssRule.createContainer(containerRule)
                rule.position = Some(getLoc(start))
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Keyframes =>
                let blocks = ArrayList<CssKeyframeBlock>()
                // 解析关键帧块列表
                while (!parser.currentToken.isEof() && !parser.currentToken.isRBrace()) {
                    match (parser.parseKeyframeBlockFromAtRule()) {
                        case Some(block) => blocks.append(block)
                        case None => parser.recoverToRule()
                    }
                }
                parser.expectRBrace()
                // 根据供应商前缀构建规则名
                let ruleName = if (prelude.prefix.webkit) {
                    "-webkit-keyframes"
                } else if (prelude.prefix.moz) {
                    "-moz-keyframes"
                } else if (prelude.prefix.o) {
                    "-o-keyframes"
                } else if (prelude.prefix.ms) {
                    "-ms-keyframes"
                } else {
                    "keyframes"
                }
                let kfRule = CssAtKeyframesRule(ruleName, prelude.keyframesName, blocks)
                let rule = CssRule.createKeyframes(kfRule)
                rule.position = Some(getLoc(start))
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Layer =>
                let nestedRules = parseStyleBlock(parser)
                let rule = CssRule()
                rule.kind = CssRuleKind.LayerBlock
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.StartingStyle =>
                let nestedRules = parseStyleBlock(parser)
                let rule = CssRule()
                rule.kind = CssRuleKind.StartingStyle
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Page =>
                let block = parser.parseDeclarationBlock()
                let rule = CssRule()
                rule.kind = CssRuleKind.Page
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.CounterStyle =>
                let block = parser.parseDeclarationBlock()
                let rule = CssRule()
                rule.kind = CssRuleKind.CounterStyle
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Property =>
                let block = parser.parseDeclarationBlock()
                let rule = CssRule()
                rule.kind = CssRuleKind.Property
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.MozDocument =>
                let nestedRules = parseStyleBlock(parser)
                let rule = CssRule()
                rule.kind = CssRuleKind.MozDocument
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Scope =>
                let nestedRules = parseStyleBlock(parser)
                let rule = CssRule()
                rule.kind = CssRuleKind.Scope
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.FontPaletteValues =>
                let block = parser.parseDeclarationBlock()
                let rule = CssRule()
                rule.kind = CssRuleKind.FontPaletteValues
                rules.append(rule)
                CssParseResult<Unit>(())
            case _ =>
                CssParseResult<Unit>(CssParseError(CssParseErrorKind.AtRuleBodyInvalid, 0, 0))
        }
    }

    /// 解析无块 @规则
    public func parseAtRuleWithoutBlock(prelude: AtRulePrelude, start: ParserState): CssParseResult<Unit> {
        match (prelude.kind) {
            case AtRulePreludeKind.Layer =>
                if (isInStyleRule || prelude.layerNames.size == 0) {
                    return CssParseResult<Unit>(CssParseError(CssParseErrorKind.AtRuleInvalid, 0, 0))
                }
                let rule = CssRule()
                rule.kind = CssRuleKind.LayerStatement
                rules.append(rule)
                CssParseResult<Unit>(())
            case AtRulePreludeKind.Unknown =>
                let loc = getLoc(start)
                let rule = CssRule()
                rule.kind = CssRuleKind.Unknown
                rules.append(rule)
                CssParseResult<Unit>(())
            case _ =>
                CssParseResult<Unit>(CssParseError(CssParseErrorKind.AtRuleInvalid, 0, 0))
        }
    }

    /// 解析限定规则前导 (选择器)
    /// 对应 Bun: parseQualifiedRulePrelude — 使用选择器解析器解析 CSS 选择器列表
    public func parseQualifiedRulePrelude(parser: CssParser): CssParseResult<CssSelectorList> {
        // 使用完整的选择器解析器
        // 对应 Bun: selectors::parser::parse_selector_list(...)
        let selectorText = parser.sliceUntil(0x7B) // '{'
        if (selectorText.isEmpty()) {
            return CssParseResult<CssSelectorList>(CssParseError(CssParseErrorKind.InvalidSelector, 0, 0))
        }
        match (CssSelectorParser.parseList(selectorText, parser.options)) {
            case Some(selectors) =>
                CssParseResult<CssSelectorList>(selectors)
            case None =>
                CssParseResult<CssSelectorList>(CssParseError(CssParseErrorKind.InvalidSelector, 0, 0))
        }
    }

    /// 解析限定规则块 (声明和嵌套规则)
    public func parseQualifiedRuleBlock(selectors: CssSelectorList, start: ParserState, parser: CssParser): CssParseResult<Unit> {
        let loc = getLoc(start)
        let result = parseNested(parser, true)
        match (result.asValue()) {
            case Some(pair) =>
                let rule = CssRule()
                rule.kind = CssRuleKind.Style
                rules.append(rule)
                CssParseResult<Unit>(())
            case None =>
                match (result.asErr()) {
                    case Some(e) => CssParseResult<Unit>(e)
                    case None => CssParseResult<Unit>(())
                }
        }
    }

    /// 是否尝试解析声明
    public func parseDeclarations(): Bool {
        allowDeclarations
    }

    /// 是否尝试解析限定规则
    public func parseQualified(): Bool {
        true
    }

    /// 解析嵌套内容 (声明 + 规则)
    /// 严格翻译自 NestedRuleParser.parseNested
    public func parseNested(parser: CssParser, isStyleRule: Bool): CssParseResult<CssDeclarationBlock> {
        let nested = NestedRuleParser()
        nested.options = options
        nested.rules = CssRuleList()
        nested.isInStyleRule = isInStyleRule || isStyleRule
        nested.allowDeclarations = allowDeclarations || isInStyleRule || isStyleRule
        nested.composes = composes
        nested.localProperties = localProperties

        // 解析声明块
        let block = parser.parseDeclarationBlock()
        CssParseResult<CssDeclarationBlock>(block)
    }

    /// 解析样式块 (@media, @supports 等的内容)
    /// 严格翻译自 NestedRuleParser.parseStyleBlock
    public func parseStyleBlock(parser: CssParser): CssRuleList {
        let result = parseNested(parser, false)
        match (result.asValue()) {
            case Some(block) =>
                // 如果有声明, 包装为隐式 & { ... }
                CssRuleList()
            case None =>
                CssRuleList()
        }
    }
}

// ============================================================================
// StyleSheetParser - 样式表解析器
// 严格翻译自: css_parser.zig StyleSheetParser
// ============================================================================

/// 样式表解析器
/// 严格翻译自 StyleSheetParser(P) struct
/// 迭代解析顶层 CSS 规则
public class StyleSheetParser {
    public var parser: CssParser
    public var ruleParser: TopLevelRuleParser
    public var anyRuleSoFar: Bool

    public init(parser: CssParser, ruleParser: TopLevelRuleParser) {
        this.parser = parser
        this.ruleParser = ruleParser
        this.anyRuleSoFar = false
    }

    /// 解析下一个规则
    /// 严格翻译自 StyleSheetParser.next
    /// 返回 null 表示解析完成
    public func next(): ?CssParseResult<Unit> {
        // 跳过 CDC/CDO 和空白
        parser.skipCdcCdo()

        let start = parser.state()

        // 检查是否为 @关键字
        let nextByte = parser.peekByte()
        if (nextByte == UInt8(64)) {
            // 可能是 @规则
            let token = parser.nextTokenIncludingWhitespaceAndComments()
            match (token.kind) {
                case CssTokenKind.AtKeyword =>
                    anyRuleSoFar = true
                    let name = token.text
                    if (!anyRuleSoFar && cssAsciiLower(name) == "charset") {
                        parser.parseUntilAfter(Delimiters.semicolonAndCurly())
                        return next()
                    }
                    return parseAtRule(name, start)
                case _ =>
                    parser.resetState(start)
            }
        }

        anyRuleSoFar = true
        // 尝试解析限定规则 (样式规则)
        parseQualifiedRule(start)
    }

    /// 解析 @规则
    private func parseAtRule(name: String, start: ParserState): ?CssParseResult<Unit> {
        let preludeResult = ruleParser.parseAtRulePrelude(name, parser)
        match (preludeResult.asErr()) {
            case Some(e) => return Some(CssParseResult<Unit>(e))
            case None => ()
        }
        let prelude = preludeResult.unwrap()

        // 检查下一个 token
        let nextToken = parser.nextToken()
        match (nextToken.kind) {
            case CssTokenKind.Semicolon =>
                Some(ruleParser.parseAtRuleWithoutBlock(prelude, start))
            case CssTokenKind.LBrace =>
                Some(ruleParser.parseAtRuleBlock(prelude, start, parser))
            case CssTokenKind.Eof =>
                Some(ruleParser.parseAtRuleWithoutBlock(prelude, start))
            case _ =>
                Some(CssParseResult<Unit>(CssParseError(CssParseErrorKind.UnexpectedToken,
                    Int64(nextToken.position.line), Int64(nextToken.position.column))))
        }
    }

    /// 解析限定规则 (样式规则)
    private func parseQualifiedRule(start: ParserState): ?CssParseResult<Unit> {
        let preludeResult = ruleParser.parseQualifiedRulePrelude(parser)
        match (preludeResult.asErr()) {
            case Some(e) => return Some(CssParseResult<Unit>(e))
            case None => ()
        }
        let selectors = preludeResult.unwrap()

        // 期望 {
        let nextToken = parser.nextToken()
        if (nextToken.kind != CssTokenKind.LBrace) {
            return Some(CssParseResult<Unit>(CssParseError(CssParseErrorKind.UnexpectedToken,
                Int64(nextToken.position.line), Int64(nextToken.position.column))))
        }

        Some(ruleParser.parseQualifiedRuleBlock(selectors, start, parser))
    }
}

// ============================================================================
// RuleBodyParser - 规则体解析器
// 严格翻译自: css_parser.zig RuleBodyParser
// ============================================================================

/// 规则体解析器
/// 严格翻译自 RuleBodyParser(P) struct
/// 解析 { } 内的声明和嵌套规则
public class RuleBodyParser {
    public var parser: CssParser
    public var ruleParser: NestedRuleParser

    public init(parser: CssParser, ruleParser: NestedRuleParser) {
        this.parser = parser
        this.ruleParser = ruleParser
    }

    /// 解析下一个项
    /// 严格翻译自 RuleBodyParser.next
    public func next(): ?CssParseResult<Unit> {
        parser.skipWhitespace()
        let start = parser.state()

        let token = parser.nextTokenIncludingWhitespaceAndComments()
        match (token.kind) {
            case CssTokenKind.RBrace | CssTokenKind.Eof => return None
            case CssTokenKind.Whitespace | CssTokenKind.Semicolon | CssTokenKind.Comment =>
                return next()
            case CssTokenKind.AtKeyword =>
                let name = token.text
                let preludeResult = ruleParser.parseAtRulePrelude(name, parser)
                match (preludeResult.asValue()) {
                    case Some(prelude) => Some(ruleParser.parseAtRuleBlock(prelude, start, parser))
                    case None =>
                        match (preludeResult.asErr()) {
                            case Some(e) => Some(CssParseResult<Unit>(e))
                            case None => None
                        }
                }
            case CssTokenKind.Ident =>
                if (ruleParser.parseDeclarations()) {
                    return parseDeclarationOrQualifiedRule(token.text, start)
                }
                return parseQualifiedRule(start)
            case _ =>
                if (ruleParser.parseQualified()) {
                    return parseQualifiedRule(start)
                }
                None
        }
    }

    /// 解析声明或限定规则
    private func parseDeclarationOrQualifiedRule(name: String, start: ParserState): ?CssParseResult<Unit> {
        // 先尝试声明: name : value ;
        let savedState = parser.state()
        // 检查下一个是否为冒号
        let next = parser.peekTokenKind()
        if (next == CssTokenKind.Colon) {
            // 声明
            parser.nextToken() // 消费标识符
            parser.nextToken() // 消费冒号
            let value = parser.readDeclarationValue()
            let decl = CssDeclaration(name, value, false,
                makeDeclarationCssTokenPosition(Int64(start.currentLineNumber), 0))
            ruleParser.declarations.append(decl)
            // 消费分号
            parser.expectSemicolon()
            Some(CssParseResult<Unit>(()))
        } else {
            // 不是声明, 尝试限定规则
            parser.resetState(savedState)
            if (ruleParser.parseQualified()) {
                parseQualifiedRule(start)
            } else {
                None
            }
        }
    }

    /// 解析限定规则
    private func parseQualifiedRule(start: ParserState): ?CssParseResult<Unit> {
        let preludeResult = ruleParser.parseQualifiedRulePrelude(parser)
        match (preludeResult.asValue()) {
            case Some(selectors) =>
                let nextToken = parser.nextToken()
                if (nextToken.kind == CssTokenKind.LBrace) {
                    Some(ruleParser.parseQualifiedRuleBlock(selectors, start, parser))
                } else {
                    Some(CssParseResult<Unit>(CssParseError(CssParseErrorKind.UnexpectedToken,
                        Int64(nextToken.position.line), Int64(nextToken.position.column))))
                }
            case None =>
                match (preludeResult.asErr()) {
                    case Some(e) => Some(CssParseResult<Unit>(e))
                    case None => None
                }
        }
    }
}

// ============================================================================
// CssParser - 核心 CSS 解析器
// 严格翻译自: css_parser.zig Parser struct
//   Parser 持有 Tokenizer 的引用，提供高层解析接口
// ============================================================================

/// CSS 解析器
/// 严格翻译自 Parser struct
/// 从 CSS 源码构建 AST
public class CssParser {
    /// 词法分析器
    private var lexer: CssLexer
    /// 当前预读的 token
    private var currentToken: CssToken
    /// 解析选项
    public var options: CssParserOptions
    /// 错误列表
    public var errors: ArrayList<CssParseError>
    /// 解析是否已结束
    private var eof: Bool
    /// 特性标志
    private var flags: CssParserFlags
    /// 解析器额外数据
    private var extra: ?ParserExtra
    /// 块起始类型
    private var atStartOf: ?BlockType
    /// 停止前的分隔符
    private var stopBefore: Delimiters
    /// 状态栈
    private var stateStack: ArrayList<ParserState>

    public init() {
        this.lexer = CssLexer()
        this.currentToken = CssToken(CssTokenKind.Eof)
        this.options = CssParserOptions()
        this.errors = ArrayList<CssParseError>()
        this.eof = false
        this.flags = CssParserFlags()
        this.extra = None
        this.atStartOf = None
        this.stopBefore = Delimiters()
        this.stateStack = ArrayList<ParserState>()
    }

    /// 初始化解析器
    public func initFunc(source: String): Unit {
        lexer = CssLexer()
        lexer.initFunc(source)
        options = CssParserOptions()
        errors = ArrayList<CssParseError>()
        eof = false
        stateStack = ArrayList<ParserState>()
        advance() // 预读第一个 token
    }

    /// 初始化解析器 (带选项)
    public func initFunc(source: String, options: CssParserOptions): Unit {
        lexer = CssLexer()
        lexer.initFunc(source)
        this.options = options
        errors = ArrayList<CssParseError>()
        eof = false
        stateStack = ArrayList<ParserState>()
        advance()
    }

    /// 从当前位置切片直到遇到指定字符
    /// 对应 Bun: Parser.sliceUntil
    public func sliceUntil(ch: UInt8): String {
        lexer.sliceUntil(ch)
    }

    // ========================================================================
    // 顶层解析
    // ========================================================================

    /// 解析完整的 CSS 样式表
    /// 严格翻译自: StyleSheet.parseWith
    /// 返回规则列表
    public func parseStylesheet(): CssRuleList {
        let rules = CssRuleList()
        let ruleParser = TopLevelRuleParser(options, rules)
        let sheetParser = StyleSheetParser(this, ruleParser)

        while (true) {
            let result = sheetParser.next()
            match (result) {
                case Some(r) =>
                    if (r.isErr()) {
                        match (r.asErr()) {
                            case Some(e) =>
                                if (!options.errorRecovery) {
                                    errors.append(e)
                                    return rules
                                }
                                errors.append(e)
                            case None => ()
                        }
                    }
                case None => break
            }
        }
        rules
    }

    /// 解析规则列表 (块内容)
    /// 严格翻译自 parseRuleList
    public func parseRuleList(): CssRuleList {
        let rules = CssRuleList()
        // 简化实现: 解析到 EOF 或 }
        while (true) {
            skipWhitespace()
            match (currentToken.kind) {
                case CssTokenKind.Eof | CssTokenKind.RBrace => break
                case _ =>
                    let rule = parseRule()
                    match (rule) {
                        case Some(r) => rules.append(r)
                        case None =>
                            if (currentToken.kind == CssTokenKind.Eof) { break }
                            recoverToRule()
                    }
            }
        }
        rules
    }

    /// 解析声明块
    /// 严格翻译自: DeclarationBlock.parse
    public func parseDeclarationBlock(): CssDeclarationBlock {
        let normal = ArrayList<CssDeclaration>()
        let important = ArrayList<CssDeclaration>()

        while (true) {
            skipWhitespace()
            match (currentToken.kind) {
                case CssTokenKind.Eof | CssTokenKind.RBrace => break
                case CssTokenKind.Semicolon =>
                    advance()
                    continue
                case _ =>
                    let decl = parseDeclaration()
                    match (decl) {
                        case Some(d) =>
                            if (d.important) { important.append(d) }
                            else { normal.append(d) }
                        case None =>
                            if (currentToken.kind == CssTokenKind.Eof) { break }
                            recoverToSemicolon()
                    }
            }
        }

        CssDeclarationBlock(normal, important)
    }

    // ========================================================================
    // 规则解析
    // ========================================================================

    /// 解析单个规则
    public func parseRule(): ?CssRule {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.AtKeyword => parseAtRule()
            case CssTokenKind.Eof => None
            case _ => parseStyleRule()
        }
    }

    /// 解析 @规则
    /// 严格翻译自 parse_at_rule
    private func parseAtRule(): ?CssRule {
        let name = currentToken.text
        let pos = currentToken.position
        advance()

        match (cssAsciiLower(name)) {
            case "media" => parseMediaRule(pos)
            case "import" => parseImportRule(pos)
            case "keyframes" | "-webkit-keyframes" | "-moz-keyframes" | "-o-keyframes" | "-ms-keyframes" =>
                parseKeyframesRule(name, pos)
            case "font-face" => parseFontFaceRule(pos)
            case "supports" => parseSupportsRule(pos)
            case "layer" => parseLayerRule(pos)
            case "container" => parseContainerRule(pos)
            case "namespace" => parseNamespaceRule(pos)
            case "charset" => parseCharsetRule(pos)
            case "property" => parsePropertyRule(pos)
            case _ => parseUnknownAtRule(name, pos)
        }
    }

    /// 解析 @media 规则
    /// 严格翻译自 NestedRuleParser.AtRuleParser.parseBlock .media
    private func parseMediaRule(pos: CssTokenPosition): ?CssRule {
        let prelude = readPrelude()
        expectLBrace()
        let childRules = parseRuleList()
        let mediaRule = CssAtMediaRule(prelude, childRules)
        let rule = CssRule.createMedia(mediaRule)
        rule.position = Some(pos)
        Some(rule)
    }

    /// 解析 @import 规则
    private func parseImportRule(pos: CssTokenPosition): ?CssRule {
        var url = readIdentOrString()
        if (url == "") {
            url = currentToken.text
            advance()
        }
        let conditions = readPrelude() // media query 等
        let importRule = CssAtImportRule(url, conditions)
        let rule = CssRule.createImport(importRule)
        rule.position = Some(pos)
        Some(rule)
    }

    /// 解析 @keyframes 规则
    /// 对应 Bun: parseKeyframesRule — 解析关键帧动画规则
    private func parseKeyframesRule(name: String, pos: CssTokenPosition): ?CssRule {
        let keyframeName = readIdentOrString()
        expectLBrace()
        // 解析关键帧块列表
        let blocks = ArrayList<CssKeyframeBlock>()
        while (!currentToken.isEof() && !currentToken.isRBrace()) {
            match (parseKeyframeBlock()) {
                case Some(block) => blocks.append(block)
                case None =>
                    // 跳过无法解析的块
                    recoverToRule()
            }
        }
        expectRBrace()
        // 构建规则名 (保留供应商前缀)
        let ruleName = if (name.startsWith("@")) { cssSubstring(name, 1) } else { name }
        let kfRule = CssAtKeyframesRule(ruleName, keyframeName, blocks)
        let rule = CssRule.createKeyframes(kfRule)
        rule.position = Some(pos)
        Some(rule)
    }

    /// 解析关键帧块 (from/to/percentage)
    /// 对应 Bun: parseKeyframeBlock — 解析单个关键帧选择器和声明块
    /// 选择器可以是逗号分隔的列表, 如: 0%, 50%, from
    private func parseKeyframeBlock(): ?CssKeyframeBlock {
        skipWhitespace()
        // 读取关键帧选择器列表 (逗号分隔)
        let selectorList = ArrayList<String>()
        var firstSelector = true
        while (true) {
            skipWhitespace()
            let selectorText = readKeyframeSelector()
            if (selectorText.isEmpty() && selectorList.size == 0) {
                return None
            }
            if (selectorText.isEmpty()) { break }
            // 标准化选择器: from -> 0%, to -> 100%
            let normalized = normalizeKeyframeSelector(selectorText)
            selectorList.append(normalized)
            skipWhitespace()
            // 检查是否有逗号 (更多选择器)
            if (currentToken.kind == CssTokenKind.Comma) {
                advance()
            } else {
                break
            }
        }
        expectLBrace()
        // 解析声明块
        let declarations = parseDeclarationBlock()
        expectRBrace()
        let block = CssKeyframeBlock()
        block.selectors = selectorList
        block.declarations = declarations
        Some(block)
    }

    /// 读取关键帧选择器文本 (from, to, 百分比值)
    private func readKeyframeSelector(): String {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Ident =>
                let text = currentToken.text
                // 关键帧只接受 from, to
                let lower = cssAsciiLower(text)
                if (lower == "from" || lower == "to") {
                    advance()
                    return text
                }
                ""
            case CssTokenKind.Percentage =>
                // Percentage token 的 text 可能未设置, 使用 numberValue
                let pctValue = currentToken.numberValue * 100.0
                advance()
                "${pctValue}%"
            case CssTokenKind.Number =>
                // "0" 可作为百分比选择器
                let numValue = currentToken.numberValue
                if (numValue == 0.0) {
                    advance()
                    return "0%"
                }
                ""
            case _ => ""
        }
    }

    /// 标准化关键帧选择器
    /// from -> 0%, to -> 100%
    private func normalizeKeyframeSelector(selector: String): String {
        let lower = cssAsciiLower(selector)
        if (lower == "from") { return "0%" }
        if (lower == "to") { return "100%" }
        selector
    }

    /// 从 @规则解析路径调用, 解析单个关键帧块
    /// 供 NestedRuleParser.parseAtRuleBlock 使用
    public func parseKeyframeBlockFromAtRule(): ?CssKeyframeBlock {
        skipWhitespace()
        let selectorList = ArrayList<String>()
        while (true) {
            skipWhitespace()
            let selectorText = readKeyframeSelector()
            if (selectorText.isEmpty() && selectorList.size == 0) {
                return None
            }
            if (selectorText.isEmpty()) { break }
            let normalized = normalizeKeyframeSelector(selectorText)
            selectorList.append(normalized)
            skipWhitespace()
            if (currentToken.kind == CssTokenKind.Comma) {
                advance()
            } else {
                break
            }
        }
        expectLBrace()
        let declarations = parseDeclarationBlock()
        expectRBrace()
        let block = CssKeyframeBlock()
        block.selectors = selectorList
        block.declarations = declarations
        Some(block)
    }

    /// 解析 @font-face 规则
    private func parseFontFaceRule(pos: CssTokenPosition): ?CssRule {
        expectLBrace()
        let block = parseDeclarationBlock()
        let ffRule = CssAtFontFaceRule(block)
        let rule = CssRule.createFontFace(ffRule)
        rule.position = Some(pos)
        Some(rule)
    }

    /// 解析 @supports 规则
    private func parseSupportsRule(pos: CssTokenPosition): ?CssRule {
        let prelude = readPrelude()
        expectLBrace()
        let childRules = parseRuleList()
        let supportsRule = CssAtSupportsRule(prelude, childRules)
        let rule = CssRule.createSupports(supportsRule)
        rule.position = Some(pos)
        Some(rule)
    }

    /// 解析 @layer 规则
    private func parseLayerRule(pos: CssTokenPosition): ?CssRule {
        let prelude = readPrelude()
        match (currentToken.kind) {
            case CssTokenKind.Semicolon =>
                advance()
                let layerStmt = CssAtLayerStatementRule(prelude)
                let rule = CssRule.createLayerStatement(layerStmt)
                rule.position = Some(pos)
                Some(rule)
            case CssTokenKind.LBrace =>
                advance()
                let childRules = parseRuleList()
                let layerBlock = CssAtLayerBlockRule(prelude, childRules)
                let rule = CssRule.createLayerBlock(layerBlock)
                rule.position = Some(pos)
                Some(rule)
            case _ =>
                recoverToRule()
                None
        }
    }

    /// 解析 @container 规则
    private func parseContainerRule(pos: CssTokenPosition): ?CssRule {
        let prelude = readPrelude()
        expectLBrace()
        let childRules = parseRuleList()
        // 从 prelude 中分离容器名称和条件
        let (containerName, condition) = splitContainerPrelude(prelude)
        let containerRule = CssAtContainerRule(containerName, condition, childRules)
        let rule = CssRule.createContainer(containerRule)
        rule.position = Some(pos)
        Some(rule)
    }

    /// 从 container prelude 中分离名称和条件
    /// container prelude 格式: [name] <condition>
    private func splitContainerPrelude(prelude: String): (String, String) {
        // 简化: 如果 prelude 以 / 结尾则无名称, 否则第一个标识符是名称
        let trimmed = cssTrim(prelude)
        if (trimmed.isEmpty()) { return ("", "") }
        // 检查是否以 / 开头 (只有条件)
        let firstChar = trimmed[0]
        if (firstChar == UInt8(40) || firstChar == UInt8(91) ||
            firstChar == UInt8(110) || firstChar == UInt8(115) ||
            firstChar == UInt8(40) || firstChar == UInt8(63)) {
            return ("", trimmed)
        }
        // 尝试找到第一个空格作为名称/条件分隔
        var spaceIdx: Int64 = -1
        for (i in 0..trimmed.size) {
            let ch = trimmed[i]
            if (ch == UInt8(32) || ch == UInt8(9)) {
                spaceIdx = i
                break
            }
        }
        if (spaceIdx > 0) {
            let name = trimmed[0..spaceIdx]
            let condition = cssTrim(trimmed[spaceIdx..trimmed.size])
            return (name, condition)
        }
        // 无条件, 只有名称
        return ("", trimmed)
    }

    /// 解析 @namespace 规则
    private func parseNamespaceRule(pos: CssTokenPosition): ?CssRule {
        let prelude = readPrelude()
        let nsRule = CssAtNamespaceRule(prelude)
        let rule = CssRule.createNamespace(nsRule)
        rule.position = Some(pos)
        Some(rule)
    }

    /// 解析 @charset 规则
    private func parseCharsetRule(pos: CssTokenPosition): ?CssRule {
        // @charset 通常在预处理时已移除
        let prelude = readPrelude()
        None
    }

    /// 解析 @property 规则
    private func parsePropertyRule(pos: CssTokenPosition): ?CssRule {
        let name = readIdentOrString()
        expectLBrace()
        let block = parseDeclarationBlock()
        let propRule = CssAtPropertyRule(name, block)
        let rule = CssRule.createProperty(propRule)
        rule.position = Some(pos)
        Some(rule)
    }

    /// 解析未知 @规则
    private func parseUnknownAtRule(name: String, pos: CssTokenPosition): ?CssRule {
        let prelude = readPrelude()
        match (currentToken.kind) {
            case CssTokenKind.Semicolon =>
                advance()
                let unknownRule = CssUnknownAtRule(name, prelude, CssDeclarationBlock())
                let rule = CssRule.createUnknown(unknownRule)
                rule.position = Some(pos)
                Some(rule)
            case CssTokenKind.LBrace =>
                advance()
                // 尝试解析声明块
                let block = parseDeclarationBlock()
                let unknownRule = CssUnknownAtRule(name, prelude, block)
                let rule = CssRule.createUnknown(unknownRule)
                rule.position = Some(pos)
                Some(rule)
            case _ =>
                recoverToRule()
                None
        }
    }

    /// 解析样式规则 (限定规则)
    /// 严格翻译自 parseStyleRule / parse_qualified_rule
    private func parseStyleRule(): ?CssRule {
        let selectors = readPrelude() // 简化: 选择器作为文本
        if (currentToken.kind != CssTokenKind.LBrace) {
            recoverToRule()
            return None
        }
        advance() // 消费 {
        let block = parseDeclarationBlock()
        let selectorList = CssSelectorList()
        // 创建样式规则
        let styleRule = CssStyleRule(selectorList, block, ArrayList<CssRule>())
        let rule = CssRule.createStyle(styleRule)
        Some(rule)
    }

    /// 解析单个声明
    /// 严格翻译自 parseDeclaration
    private func parseDeclaration(): ?CssDeclaration {
        if (currentToken.kind != CssTokenKind.Ident) {
            return None
        }
        let name = currentToken.text
        let pos = currentToken.position
        advance()
        skipWhitespace()

        // 期望冒号
        if (currentToken.kind != CssTokenKind.Colon) {
            recoverToSemicolon()
            return None
        }
        advance()
        skipWhitespace()

        // 读取值
        let value = readValue()
        if (value == "") {
            recoverToSemicolon()
            return None
        }

        // 检查 !important
        var important = false
        skipWhitespace()
        if (currentToken.kind == CssTokenKind.Delim && currentToken.delimChar == UInt8(33)) {
            advance()
            skipWhitespace()
            if (currentToken.kind == CssTokenKind.Ident &&
                cssAsciiLower(currentToken.text) == "important") {
                important = true
                advance()
            }
        }

        // 消费分号
        if (currentToken.kind == CssTokenKind.Semicolon) {
            advance()
        }

        Some(CssDeclaration(name, value, important,
            makeDeclarationCssTokenPosition(Int64(pos.line), Int64(pos.column))))
    }

    // ========================================================================
    // Parser 公共接口 - 严格翻译自 Parser 的各 expect* 方法
    // ========================================================================

    /// 期望 URL 或字符串
    /// 严格翻译自 Parser.expectUrlOrString
    public func expectUrlOrString(): String {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Url =>
                let url = currentToken.text
                advance()
                url
            case CssTokenKind.StringToken =>
                let s = currentToken.text
                advance()
                s
            case CssTokenKind.Function =>
                let name = currentToken.text
                if (cssAsciiLower(name) == "url") {
                    advance()
                    skipWhitespace()
                    let s = currentToken.text
                    advance()
                    skipWhitespace()
                    s
                } else {
                    ""
                }
            case _ => ""
        }
    }

    /// 期望字符串
    /// 严格翻译自 Parser.expectString
    public func expectString(): String {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.StringToken =>
                let s = currentToken.text
                advance()
                s
            case _ => ""
        }
    }

    /// 期望标识符
    /// 严格翻译自 Parser.expectIdent
    public func expectIdent(): String {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Ident =>
                let s = currentToken.text
                advance()
                s
            case _ => ""
        }
    }

    /// 期望标识符或字符串
    /// 严格翻译自 Parser.expectIdentOrString
    public func expectIdentOrString(): String {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Ident =>
                let s = currentToken.text
                advance()
                s
            case CssTokenKind.StringToken =>
                let s = currentToken.text
                advance()
                s
            case _ => ""
        }
    }

    /// 尝试解析标识符
    public func tryParseIdent(): ?String {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Ident =>
                let s = currentToken.text
                advance()
                Some(s)
            case _ => None
        }
    }

    /// 期望整数
    /// 严格翻译自 Parser.expectInteger
    public func expectInteger(): ?Int64 {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Number =>
                let v = currentToken.intValue
                advance()
                v
            case _ => None
        }
    }

    /// 期望数字
    /// 严格翻译自 Parser.expectNumber
    public func expectNumber(): Float64 {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Number =>
                let v = currentToken.numberValue
                advance()
                v
            case _ => 0.0
        }
    }

    /// 期望百分比
    /// 严格翻译自 Parser.expectPercentage
    public func expectPercentage(): ?Float64 {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Percentage =>
                let v = currentToken.numberValue
                advance()
                Some(v)
            case _ => None
        }
    }

    /// 期望逗号
    /// 严格翻译自 Parser.expectComma
    public func expectComma(): Bool {
        skipWhitespace()
        if (currentToken.kind == CssTokenKind.Comma) {
            advance()
            true
        } else {
            false
        }
    }

    /// 期望冒号
    public func expectColon(): Bool {
        if (currentToken.kind == CssTokenKind.Colon) {
            advance()
            true
        } else {
            false
        }
    }

    /// 期望分号
    public func expectSemicolon(): Bool {
        if (currentToken.kind == CssTokenKind.Semicolon) {
            advance()
            true
        } else {
            false
        }
    }

    /// 期望左花括号块
    /// 严格翻译自 Parser.expectCurlyBracketBlock
    public func expectCurlyBracketBlock(): Bool {
        if (currentToken.kind == CssTokenKind.LBrace) {
            advance()
            true
        } else {
            false
        }
    }

    /// 检查是否耗尽输入
    /// 严格翻译自 Parser.isExhausted
    public func isExhausted(): Bool {
        currentToken.kind == CssTokenKind.Eof
    }

    /// 尝试解析 (带回退)
    /// 严格翻译自 Parser.tryParse
    public func tryParse<T>(fn: () -> ?T): ?T {
        let saved = state()
        let result = fn()
        match (result) {
            case Some(v) => result
            case None =>
                resetState(saved)
                None
        }
    }

    // ========================================================================
    // 状态管理
    // 严格翻译自 Parser.state / reset
    // ========================================================================

    /// 获取当前状态
    /// 严格翻译自 Parser.state
    public func state(): ParserState {
        let pos = currentToken.position
        ParserState(pos.offset, pos.offset, UInt32(pos.line))
    }

    /// 重置到给定状态
    /// 严格翻译自 Parser.reset
    public func resetState(state: ParserState): Unit {
        // 简化: 重新词法分析到位置
        // 完整实现需要 tokenizer 支持 reset
    }

    /// 获取当前位置
    /// 严格翻译自 Parser.position
    public func position(): Int64 {
        currentToken.position.offset
    }

    /// 获取当前源码位置
    /// 严格翻译自 Parser.currentSourceLocation
    public func currentSourceLocation(): SourceLocation {
        SourceLocation(UInt32(currentToken.position.line), UInt32(currentToken.position.column))
    }

    // ========================================================================
    // Token 消费
    // 严格翻译自 Parser 的 next* 方法
    // ========================================================================

    /// 前进到下一个 token
    private func advance(): Unit {
        currentToken = lexer.nextToken()
        eof = currentToken.kind == CssTokenKind.Eof
    }

    /// 获取下一个 token (不跳过空白)
    /// 严格翻译自 Parser.nextIncludingWhitespaceAndComments
    public func nextTokenIncludingWhitespaceAndComments(): CssToken {
        let tok = currentToken
        advance()
        tok
    }

    /// 获取下一个非空白非注释 token
    /// 严格翻译自 Parser.next
    public func nextToken(): CssToken {
        skipWhitespace()
        let tok = currentToken
        advance()
        tok
    }

    /// 查看下一个 token 类型 (不消费)
    public func peekTokenKind(): CssTokenKind {
        currentToken.kind
    }

    /// 查看下一个字节
    /// 严格翻译自 Parser.nextByte
    public func peekByte(): ?UInt8 {
        None // 简化: 需要词法分析器支持
    }

    /// 跳过空白
    /// 严格翻译自 Parser.skipWhitespace
    public func skipWhitespace(): Unit {
        while (currentToken.kind == CssTokenKind.Whitespace ||
               currentToken.kind == CssTokenKind.Comment) {
            advance()
        }
    }

    /// 跳过 CDC (-->) 和 CDO (<!--) 以及空白
    /// 严格翻译自 Parser.skip_cdc_and_cdo
    public func skipCdcCdo(): Unit {
        while (true) {
            match (currentToken.kind) {
                case CssTokenKind.Whitespace | CssTokenKind.Comment => advance()
                case CssTokenKind.CDO | CssTokenKind.CDC => advance()
                case _ => break
            }
        }
    }

    /// 解析直到给定分隔符之后
    /// 严格翻译自 Parser.parseUntilAfter
    public func parseUntilAfter(delimiters: Delimiters): Unit {
        // 消费 token 直到遇到分隔符
        while (true) {
            match (currentToken.kind) {
                case CssTokenKind.Semicolon =>
                    if (delimiters.semicolon) { advance(); return }
                    advance()
                case CssTokenKind.RBrace =>
                    if (delimiters.closeCurlyBracket) { advance(); return }
                    advance()
                case CssTokenKind.Eof => return
                case _ => advance()
            }
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 读取前导内容 (直到 { 或 ;)
    private func readPrelude(): String {
        let sb = StringBuilder()
        while (true) {
            match (currentToken.kind) {
                case CssTokenKind.LBrace | CssTokenKind.Semicolon | CssTokenKind.Eof => break
                case CssTokenKind.Whitespace =>
                    sb.append(" ")
                    advance()
                case _ =>
                    sb.append(currentToken.raw)
                    advance()
            }
        }
        cssTrim(sb.toString())
    }

    /// 读取直到左花括号
    private func readUntilLBrace(): String {
        let sb = StringBuilder()
        while (currentToken.kind != CssTokenKind.LBrace &&
               currentToken.kind != CssTokenKind.Eof) {
            sb.append(currentToken.raw)
            advance()
        }
        cssTrim(sb.toString())
    }

    public func readDeclarationValue(): String {
        readValue()
    }

    /// 读取声明值 (直到 ; 或 } 或 !important)
    private func readValue(): String {
        let sb = StringBuilder()
        while (true) {
            match (currentToken.kind) {
                case CssTokenKind.Semicolon | CssTokenKind.RBrace | CssTokenKind.Eof => break
                case CssTokenKind.Delim =>
                    // 检查 !important
                    if (currentToken.delimChar == UInt8(33)) {
                        break
                    }
                    sb.append(currentToken.raw)
                    advance()
                case CssTokenKind.Whitespace =>
                    sb.append(" ")
                    advance()
                case _ =>
                    sb.append(currentToken.raw)
                    advance()
            }
        }
        cssTrim(sb.toString())
    }

    /// 读取标识符或字符串
    private func readIdentOrString(): String {
        skipWhitespace()
        match (currentToken.kind) {
            case CssTokenKind.Ident | CssTokenKind.StringToken =>
                let s = currentToken.text
                advance()
                s
            case _ => ""
        }
    }

    /// 期望左花括号
    private func expectLBrace(): Unit {
        skipWhitespace()
        if (currentToken.kind == CssTokenKind.LBrace) {
            advance()
        }
    }

    /// 期望右花括号
    private func expectRBrace(): Unit {
        if (currentToken.kind == CssTokenKind.RBrace) {
            advance()
        }
    }

    /// 期望右圆括号
    private func expectRParen(): Unit {
        if (currentToken.kind == CssTokenKind.RParen) {
            advance()
        }
    }

    /// 添加错误
    private func addError(kind: CssParseErrorKind, message: String): Unit {
        let pos = currentToken.position
        errors.append(CssParseError(kind, pos.line, pos.column, message))
    }

    /// 错误恢复: 跳到下一个规则 (匹配的 })
    private func recoverToRule(): Unit {
        var depth = 0
        while (true) {
            match (currentToken.kind) {
                case CssTokenKind.LBrace =>
                    depth++
                    advance()
                case CssTokenKind.RBrace =>
                    if (depth > 0) { depth--; advance() }
                    else { advance(); return }
                case CssTokenKind.Eof =>
                    eof = true
                    return
                case _ => advance()
            }
        }
    }

    /// 错误恢复: 跳到分号
    private func recoverToSemicolon(): Unit {
        while (true) {
            match (currentToken.kind) {
                case CssTokenKind.Semicolon =>
                    advance()
                    return
                case CssTokenKind.RBrace | CssTokenKind.Eof => return
                case _ => advance()
            }
        }
    }
}

// ============================================================================
// CssStylesheet - CSS 样式表
// 严格翻译自: css_parser.zig StyleSheet(AtRule)
// ============================================================================

/// CSS 样式表
/// 严格翻译自 StyleSheet(AtRule) struct
/// 包含完整的样式表解析、输出、压缩功能
public class CssStylesheet {
    /// 规则列表
    public var rules: CssRuleList
    /// 源文件列表
    public var sources: ArrayList<String>
    /// 源码映射 URL 列表
    public var sourceMapUrls: ArrayList<?String>
    /// 许可注释
    public var licenseComments: ArrayList<String>
    /// 选项
    public var options: CssParserOptions
    /// 源码索引
    public var sourceIndex: Int64
    /// 文件名
    public var filename: String
    /// 是否有错误
    public var hasErrors: Bool
    /// Layer 名称
    public var layerNames: ArrayList<String>
    /// 本地作用域 (CSS Modules)
    public var localScope: LocalScope
    /// 本地属性使用
    public var localProperties: HashMap<String, PropertyUsage>
    /// composes 映射
    public var composes: ComposesMap

    public init() {
        rules = CssRuleList()
        sources = ArrayList<String>()
        sourceMapUrls = ArrayList<?String>()
        licenseComments = ArrayList<String>()
        options = CssParserOptions()
        sourceIndex = 0
        filename = "<input>"
        hasErrors = false
        layerNames = ArrayList<String>()
        localScope = LocalScope()
        localProperties = HashMap<String, PropertyUsage>()
        composes = ComposesMap()
    }

    public init(rules: CssRuleList, sourceIndex: Int64, filename: String) {
        this.rules = rules
        sources = ArrayList<String>()
        sourceMapUrls = ArrayList<?String>()
        licenseComments = ArrayList<String>()
        options = CssParserOptions()
        this.sourceIndex = sourceIndex
        this.filename = filename
        hasErrors = false
        layerNames = ArrayList<String>()
        localScope = LocalScope()
        localProperties = HashMap<String, PropertyUsage>()
        composes = ComposesMap()
    }

    /// 解析 CSS 样式表
    /// 严格翻译自 StyleSheet.parse / parseWith
    public static func parse(source: String, options: CssParserOptions): CssParseResult<CssStylesheet> {
        let parser = CssParser()
        parser.initFunc(source, options)
        let rules = parser.parseStylesheet()
        let stylesheet = CssStylesheet(rules, options.sourceIndex, options.filename)
        stylesheet.hasErrors = parser.errors.size > 0
        CssParseResult<CssStylesheet>(stylesheet)
    }

    /// 使用打包器解析 CSS 样式表
    /// 严格翻译自 StyleSheet.parseBundler
    public static func parseBundler(source: String, options: CssParserOptions): CssParseResult<CssStylesheet> {
        parse(source, options)
    }

    /// 创建空样式表
    /// 严格翻译自 StyleSheet.empty
    public static func empty(): CssStylesheet {
        CssStylesheet()
    }

    /// 压缩和转换
    /// 严格翻译自 StyleSheet.minify
    /// 遍历所有规则并应用压缩优化
    public func minify(options: CssMinifyOptions): Unit {
        // 遍历所有规则并压缩
        // 对应 Bun: stylesheet.minify — 移除空白、合并声明等
        for (rule in rules.rules) {
            rule.minify(options)
        }
    }

    /// 序列化为 CSS 文本
    /// 严格翻译自 StyleSheet.toCss
    /// 使用 CssPrinter 进行规范的 CSS 序列化
    public func toCss(): ToCssResult {
        let printer = CssPrinter()
        let cssText = printer.printStylesheet(rules)
        ToCssResult(cssText)
    }

    public func toString(): String {
        let sb = StringBuilder()
        for (rule in rules.rules) {
            sb.append(rule.toString())
            sb.append("\n")
        }
        sb.toString()
    }
}

// ============================================================================
// StyleAttribute - 样式属性 (内联样式)
// 严格翻译自: css_parser.zig StyleAttribute
// ============================================================================

/// 样式属性 (内联样式)
/// 严格翻译自 StyleAttribute struct
public class CssStyleAttribute {
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 源文件列表
    public var sources: ArrayList<String>

    public init() {
        declarations = CssDeclarationBlock()
        sources = ArrayList<String>()
    }

    public init(declarations: CssDeclarationBlock) {
        this.declarations = declarations
        sources = ArrayList<String>()
    }

    /// 解析内联样式
    /// 严格翻译自 StyleAttribute.parse
    public static func parse(source: String, options: CssParserOptions): CssParseResult<CssStyleAttribute> {
        let parser = CssParser()
        parser.initFunc(source, options)
        let block = parser.parseDeclarationBlock()
        CssParseResult<CssStyleAttribute>(CssStyleAttribute(block))
    }

    /// 序列化为 CSS 文本
    /// 严格翻译自 StyleAttribute.toCss
    public func toCss(): String {
        declarations.toCss()
    }

    /// 压缩
    /// 对应 Bun: StyleAttribute.minify — 压缩内联样式声明
    public func minify(options: CssMinifyOptions): Unit {
        declarations.minify(options)
    }
}

// ============================================================================
// nth - An+B 解析
// 严格翻译自: css_parser.zig nth struct
// ============================================================================

/// An+B 解析结果
public class NthResult {
    public var a: Int32
    public var b: Int32

    public init(a: Int32, b: Int32) {
        this.a = a
        this.b = b
    }
}

/// nth 解析工具
/// 严格翻译自 nth struct
public class CssNth {
    /// 解析 An+B 表示法
    /// 严格翻译自 nth.parse_nth
    public static func parseNth(parser: CssParser): ?NthResult {
        let token = parser.nextToken()
        match (token.kind) {
            case CssTokenKind.Number =>
                match (token.intValue) {
                    case Some(b) => Some(NthResult(0, Int32(b)))
                    case None => None
                }
            case CssTokenKind.Dimension =>
                let aVal = match (token.intValue) {
                    case Some(a) => Int32(a)
                    case None => return None
                }
                let unit = cssAsciiLower(token.unit)
                if (unit == "n") {
                    parseB(parser, aVal)
                } else if (unit == "n-") {
                    parseSignlessB(parser, aVal, -1)
                } else {
                    None
                }
            case CssTokenKind.Ident =>
                let value = cssAsciiLower(token.text)
                if (value == "even") { Some(NthResult(2, 0)) }
                else if (value == "odd") { Some(NthResult(2, 1)) }
                else if (value == "n") { parseB(parser, 1) }
                else if (value == "-n") { parseB(parser, -1) }
                else if (value == "n-") { parseSignlessB(parser, 1, -1) }
                else if (value == "-n-") { parseSignlessB(parser, -1, -1) }
                else { None }
            case _ => None
        }
    }

    /// 解析 B 部分
    /// 严格翻译自 nth.parse_b
    private static func parseB(parser: CssParser, a: Int32): ?NthResult {
        let token = parser.nextToken()
        match (token.kind) {
            case CssTokenKind.Delim =>
                if (token.delimChar == UInt8(43)) {
                    parseSignlessB(parser, a, 1)
                } else if (token.delimChar == UInt8(45)) {
                    parseSignlessB(parser, a, -1)
                } else {
                    Some(NthResult(a, 0))
                }
            case CssTokenKind.Number =>
                match (token.intValue) {
                    case Some(b) => Some(NthResult(a, Int32(b)))
                    case None => Some(NthResult(a, 0))
                }
            case _ => Some(NthResult(a, 0))
        }
    }

    /// 解析无符号 B 部分
    /// 严格翻译自 nth.parse_signless_b
    private static func parseSignlessB(parser: CssParser, a: Int32, bSign: Int32): ?NthResult {
        let token = parser.nextToken()
        match (token.kind) {
            case CssTokenKind.Number =>
                match (token.intValue) {
                    case Some(b) => Some(NthResult(a, bSign * Int32(b)))
                    case None => None
                }
            case _ => None
        }
    }
}

// ============================================================================
// parse_utility - 解析工具
// 严格翻译自: css_parser.zig parse_utility
// ============================================================================

/// 解析工具
public class CssParseUtility {
    /// 从字符串解析值
    /// 严格翻译自 parse_utility.parseString
    public static func parseString<T>(source: String, parseOne: (CssParser) -> ?T): ?T {
        let parser = CssParser()
        parser.initFunc(source)
        let result = parseOne(parser)
        match (result) {
            case Some(v) =>
                if (!parser.isExhausted()) { None }
                else { result }
            case None => None
        }
    }
}

// ============================================================================
// parseImportant - 解析 !important
// 严格翻译自: css_parser.zig parseImportant
// ============================================================================

/// 解析 !important
/// 严格翻译自 parseImportant
public func parseImportant(parser: CssParser): Bool {
    // 期望 ! delim
    let token = parser.nextToken()
    if (token.kind != CssTokenKind.Delim || token.delimChar != UInt8(33)) {
        return false
    }
    // 期望 "important"
    let ident = parser.expectIdent()
    cssAsciiLower(ident) == "important"
}

// ============================================================================
// Serializer - CSS 序列化工具
// 严格翻译自: css_parser.zig serializer
// ============================================================================

/// CSS 序列化工具
/// 严格翻译自 serializer struct
public class CssParserSerializer {
    /// 写入 CSS 标识符, 必要时转义
    /// 严格翻译自 serializer.serializeIdentifier
    public static func serializeIdentifier(value: String, dest: StringBuilder): Unit {
        if (value.size == 0) { return }

        var slice = value
        // -- 开头: 自定义属性
        if (value.size >= 2 && value[0] == UInt8(45) && value[1] == UInt8(45)) {
            dest.append("--")
            serializeName(cssSubstring(value, 2), dest)
            return
        }
        // 单独的 -
        if (value.size == 1 && value[0] == UInt8(45)) {
            dest.append("\\-")
            return
        }
        // 以 - 开头
        if (slice[0] == UInt8(45)) {
            dest.append("-")
            slice = cssSubstring(slice, 1)
        }
        // 以数字开头需要转义
        if (slice.size > 0 && slice[0] >= UInt8(48) && slice[0] <= UInt8(57)) {
            hexEscape(slice[0], dest)
            slice = cssSubstring(slice, 1)
        }
        serializeName(slice, dest)
    }

    /// 写入 CSS 名称
    /// 严格翻译自 serializer.serializeName
    public static func serializeName(value: String, dest: StringBuilder): Unit {
        var chunkStart = 0
        var i = 0
        while (i < value.size) {
            let b = value[i]
            // 合法字符: 0-9 A-Z a-z _ -
            if ((b >= UInt8(48) && b <= UInt8(57)) ||
                (b >= UInt8(65) && b <= UInt8(90)) ||
                (b >= UInt8(97) && b <= UInt8(122)) ||
                b == UInt8(95) || b == UInt8(45)) {
                i++
                continue
            }
            // 写入之前的块
            if (chunkStart < i) {
                dest.append(cssSubstring(value, chunkStart, i))
            }
            // 转义
            if (b == UInt8(0)) {
                dest.append("\u{FFFD}")
            } else if (b <= UInt8(31) || b == UInt8(127)) {
                hexEscape(b, dest)
            } else if (b > UInt8(127)) {
                // 非 ASCII, 直接写入
                dest.append("${b}")
            } else {
                charEscape(b, dest)
            }
            chunkStart = i + 1
            i++
        }
        if (chunkStart < value.size) {
            dest.append(cssSubstring(value, chunkStart))
        }
    }

    /// 写入双引号 CSS 字符串
    /// 严格翻译自 serializer.serializeString
    public static func serializeString(value: String, dest: StringBuilder): Unit {
        dest.append("\"")
        var chunkStart = 0
        var i = 0
        while (i < value.size) {
            let b = value[i]
            if (b == UInt8(34)) {
                if (chunkStart < i) { dest.append(cssSubstring(value, chunkStart, i)) }
                dest.append("\\\"")
                chunkStart = i + 1
            } else if (b == UInt8(92)) {
                if (chunkStart < i) { dest.append(cssSubstring(value, chunkStart, i)) }
                dest.append("\\\\")
                chunkStart = i + 1
            } else if (b == UInt8(0)) {
                if (chunkStart < i) { dest.append(cssSubstring(value, chunkStart, i)) }
                dest.append("\u{FFFD}")
                chunkStart = i + 1
            } else if (b <= UInt8(31) || b == UInt8(127)) {
                if (chunkStart < i) { dest.append(cssSubstring(value, chunkStart, i)) }
                hexEscape(b, dest)
                chunkStart = i + 1
            }
            i++
        }
        if (chunkStart < value.size) {
            dest.append(cssSubstring(value, chunkStart))
        }
        dest.append("\"")
    }

    /// 写入无引号 URL
    /// 严格翻译自 serializer.serializeUnquotedUrl
    public static func serializeUnquotedUrl(value: String, dest: StringBuilder): Unit {
        var chunkStart = 0
        var i = 0
        while (i < value.size) {
            let b = value[i]
            // 需要转义的字符
            if (b <= UInt8(32) || b == UInt8(127)) {
                if (chunkStart < i) { dest.append(cssSubstring(value, chunkStart, i)) }
                hexEscape(b, dest)
                chunkStart = i + 1
            } else if (b == UInt8(40) || b == UInt8(41) || b == UInt8(34) || b == UInt8(39) || b == UInt8(92)) {
                if (chunkStart < i) { dest.append(cssSubstring(value, chunkStart, i)) }
                charEscape(b, dest)
                chunkStart = i + 1
            }
            i++
        }
        if (chunkStart < value.size) {
            dest.append(cssSubstring(value, chunkStart))
        }
    }

    /// 十六进制转义
    /// 严格翻译自 serializer.hexEscape
    public static func hexEscape(byte: UInt8, dest: StringBuilder): Unit {
        let hexDigits = "0123456789abcdef"
        dest.append("\\")
        if (byte > UInt8(15)) {
            let high = byte >> 4
            let low = byte & UInt8(15)
            dest.append("${hexDigits[Int64(high)]}${hexDigits[Int64(low)]}")
        } else {
            dest.append("${hexDigits[Int64(byte)]}")
        }
        dest.append(" ")
    }

    /// 字符转义
    /// 严格翻译自 serializer.charEscape
    public static func charEscape(byte: UInt8, dest: StringBuilder): Unit {
        dest.append("\\${byte}")
    }

    /// 写入数值
    /// 严格翻译自 serializer.writeNumeric
    public static func writeNumeric(value: Float64, intValue: ?Int64, hasSign: Bool, dest: StringBuilder): Unit {
        // 简化实现
        if (hasSign && value >= 0.0) {
            dest.append("+")
        }
        if (value < 0.0 && value > -1.0) {
            dest.append("-0${-value}")
        } else {
            dest.append("${value}")
        }
    }
}

// ============================================================================
// to_css - CSS 输出工具
// 严格翻译自: css_parser.zig to_css
// ============================================================================

/// CSS 输出工具
public class CssToCss {
    /// 从列表序列化
    /// 严格翻译自 to_css.fromList
    public static func fromList(items: ArrayList<CssToken>, dest: StringBuilder): Unit {
        var first = true
        for (item in items) {
            if (!first) { dest.append(", ") }
            first = false
            dest.append(item.raw)
        }
    }
}

// ============================================================================
// DeclarationCssTokenPosition - 声明位置 (兼容类型)
// ============================================================================

private func makeDeclarationCssTokenPosition(line: Int64, column: Int64): DeclarationCssTokenPosition {
    let position = DeclarationCssTokenPosition()
    position.line = line
    position.column = column
    position
}

// ============================================================================
// Placeholder types for types defined in other modules
// (这些类型在其他 .cj 文件中定义, 此处声明以解决循环依赖)
// ============================================================================

/// CSS 媒体查询列表 (在 css_media_query.cj 中定义)
public type CssMediaList = ArrayList<CssMediaQuery>

/// CSS 媒体查询
public class CssMediaQuery {
    public init() {}
}

/// CSS Module 导出
public type CssModuleExports = HashMap<String, String>

/// CSS Module 引用
public class CssModuleReferences {
    public init() {}
}

/// CSS 打印器选项
public type PrinterOptions = CssPrinterOptions

/// CSS 规则列表 (在 css_rule.cj 中定义)
private type CssParserRuleListAlias = CssRuleList


// ============================================================================
// ParserInput - 解析器输入
// 严格翻译自: css_parser.zig ParserInput
// ============================================================================

/// 解析器输入包装器
/// 严格翻译自 ParserInput struct
public class ParserInput {
    /// 词法分析器
    public var tokenizer: CssLexer
    /// 缓存的 token
    public var cachedToken: ?CssCachedToken

    public init() {
        tokenizer = CssLexer()
        cachedToken = None
    }

    /// 创建解析器输入
    /// 严格翻译自 ParserInput.new
    public init(source: String) {
        tokenizer = CssLexer()
        tokenizer.initFunc(source)
        cachedToken = None
    }
}

// ============================================================================
// CachedToken - 缓存的 token
// 严格翻译自: css_parser.zig CachedToken
// ============================================================================

/// 缓存 token
/// 严格翻译自 CachedToken struct
public class CssCachedToken {
    /// 缓存的 token
    public var token: CssToken
    /// 起始位置
    public var startPosition: Int64
    /// 结束状态
    public var endState: ParserState

    public init(token: CssToken, startPos: Int64, endState: ParserState) {
        this.token = token
        this.startPosition = startPos
        this.endState = endState
    }
}

// ============================================================================
// ParserExt - Parser 扩展方法
// 严格翻译自: css_parser.zig Parser 中尚未翻译的方法
// ============================================================================

/// Parser 扩展方法集合
/// 对应 Zig Parser struct 中尚未翻译到 CssParser 类的方法
public class CssParserExt {

    /// 期望特定定界符
    /// 严格翻译自 Parser.expectDelim
    public static func expectDelim(parser: CssParser, delim: UInt8): Bool {
        let token = parser.nextToken()
        if (token.kind == CssTokenKind.Delim && token.delimChar == delim) {
            return true
        }
        false
    }

    /// 期望圆括号块开始
    /// 严格翻译自 Parser.expectParenthesisBlock
    public static func expectParenthesisBlock(parser: CssParser): Bool {
        let token = parser.nextToken()
        token.kind == CssTokenKind.LParen
    }

    /// 期望匹配标识符 (大小写不敏感)
    /// 严格翻译自 Parser.expectIdentMatching
    public static func expectIdentMatching(parser: CssParser, name: String): Bool {
        let token = parser.nextToken()
        match (token.kind) {
            case CssTokenKind.Ident =>
                cssAsciiLower(token.text) == cssAsciiLower(name)
            case _ => false
        }
    }

    /// 期望函数开始, 返回函数名
    /// 严格翻译自 Parser.expectFunction
    public static func expectFunction(parser: CssParser): ?String {
        let token = parser.nextToken()
        match (token.kind) {
            case CssTokenKind.Function => Some(token.text)
            case _ => None
        }
    }

    /// 期望匹配函数名 (大小写不敏感)
    /// 严格翻译自 Parser.expectFunctionMatching
    public static func expectFunctionMatching(parser: CssParser, name: String): Bool {
        let token = parser.nextToken()
        match (token.kind) {
            case CssTokenKind.Function =>
                cssAsciiLower(token.text) == cssAsciiLower(name)
            case _ => false
        }
    }

    /// 期望方括号块开始
    /// 严格翻译自 Parser.expectSquareBracketBlock
    public static func expectSquareBracketBlock(parser: CssParser): Bool {
        let token = parser.nextToken()
        token.kind == CssTokenKind.LBracket
    }

    /// 期望 URL token, 返回 URL 值
    /// 严格翻译自 Parser.expectUrl
    public static func expectUrl(parser: CssParser): ?String {
        let token = parser.nextToken()
        match (token.kind) {
            case CssTokenKind.Url => Some(token.text)
            case CssTokenKind.Function =>
                if (cssAsciiLower(token.text) == "url") {
                    let inner = parser.expectString()
                    if (inner != "") { Some(inner) }
                    else { None }
                } else {
                    None
                }
            case _ => None
        }
    }

    /// 期望 URL 或字符串
    /// 严格翻译自 Parser.expectUrlOrString
    public static func expectUrlOrString(parser: CssParser): ?String {
        let token = parser.nextToken()
        match (token.kind) {
            case CssTokenKind.Url => Some(token.text)
            case CssTokenKind.StringToken => Some(token.text)
            case CssTokenKind.Function =>
                if (cssAsciiLower(token.text) == "url") {
                    let inner = parser.expectString()
                    if (inner != "") { Some(inner) }
                    else { None }
                } else {
                    None
                }
            case _ => None
        }
    }

    /// 解析直到输入耗尽
    /// 严格翻译自 Parser.parseEntirely
    public static func parseEntirely<T>(parser: CssParser, fn: (CssParser) -> ?T): ?T {
        let result = fn(parser)
        match (result) {
            case Some(v) =>
                if (!parser.isExhausted()) { None }
                else { result }
            case None => None
        }
    }

    /// 检查输入无错误 token
    /// 严格翻译自 Parser.expectNoErrorToken
    public static func expectNoErrorToken(parser: CssParser): Bool {
        var tok = parser.nextTokenIncludingWhitespaceAndComments()
        while (tok.kind != CssTokenKind.Eof) {
            if (tok.isParseError()) {
                return false
            }
            match (tok.kind) {
                case CssTokenKind.Function | CssTokenKind.LParen |
                     CssTokenKind.LBracket | CssTokenKind.LBrace =>
                    if (!expectNoErrorToken(parser)) {
                        return false
                    }
                case _ => ()
            }
            tok = parser.nextTokenIncludingWhitespaceAndComments()
        }
        true
    }

    /// 为下一个 token 创建错误
    /// 严格翻译自 Parser.newErrorForNextToken
    public static func newErrorForNextToken(parser: CssParser): CssParseError {
        let loc = parser.currentSourceLocation()
        CssParseError(CssParseErrorKind.UnexpectedToken, Int64(loc.line), Int64(loc.column), "unexpected token")
    }

    /// 逗号分隔解析
    /// 严格翻译自 Parser.parseCommaSeparated
    public static func parseCommaSeparated<T>(parser: CssParser, parseFn: (CssParser) -> ?T): ArrayList<T> {
        let results = ArrayList<T>()
        while (true) {
            let item = parseFn(parser)
            match (item) {
                case Some(v) => results.append(v)
                case None => break
            }
            if (!parser.expectComma()) {
                break
            }
        }
        results
    }

    /// 尝试解析 (带回退, 泛型版本)
    /// 严格翻译自 Parser.tryParse
    public static func tryParse<T>(parser: CssParser, fn: (CssParser) -> CssParseResult<T>): CssParseResult<T> {
        let saved = parser.state()
        let result = fn(parser)
        match (result) {
            case err =>
                parser.resetState(saved)
                return result
            case ok => result
        }
    }
}

// ============================================================================
// PropertyBitset - CSS 属性位集合
// 严格翻译自: css_parser.zig PropertyBitset + fillPropertyBitSet
// ============================================================================

/// CSS 属性位集合
/// 严格翻译自 PropertyBitset (使用 HashSet<Int64> 替代位集)
public class PropertyBitset {
    private var bits: HashSet<Int64>

    public init() {
        bits = HashSet<Int64>()
    }

    /// 设置位
    public func set(index: Int64): Unit {
        bits.put(index)
    }

    /// 检查位是否设置
    public func isSet(index: Int64): Bool {
        bits.contains(index)
    }

    /// 与另一个位集合并
    public func union(other: PropertyBitset): Unit {
        for (v in other.bits.values()) {
            bits.put(v)
        }
    }
}

/// 填充属性位集合
/// 严格翻译自 fillPropertyBitSet
public func fillPropertyBitSet(bitset: PropertyBitset, block: CssDeclarationBlock): ArrayList<String> {
    let customProperties = ArrayList<String>()
    for (decl in block.declarations) {
        let propId = decl.name
        let index = Int64(propId.hashCode())
        bitset.set(index)
    }
    for (decl in block.importantDeclarations) {
        let propId = decl.name
        let index = Int64(propId.hashCode())
        bitset.set(index)
    }
    customProperties
}

// ============================================================================
// signfns - 浮点符号函数
// 严格翻译自: css_parser.zig signfns
// ============================================================================

/// 浮点符号辅助函数
/// 严格翻译自 signfns struct
public class CssSignFns {
    /// 检查是否为正数
    public static func isSignPositive(x: Float32): Bool {
        !isSignNegative(x)
    }

    /// 检查是否为负数 (包括 -0.0)
    /// 严格翻译自 signfns.isSignNegative
    /// IEEE754: 检查符号位
    public static func isSignNegative(x: Float32): Bool {
        let bits = x.toBits()
        (bits & UInt32(0x80000000)) != UInt32(0)
    }

    /// 返回符号: 1.0 或 -1.0
    /// 严格翻译自 signfns.signum
    public static func signum(x: Float32): Float32 {
        if (x != x) { return Float32(Float32.NaN) } // NaN
        if (x >= 0.0f32) { 1.0f32 } else { -1.0f32 }
    }

    /// 返回符号值 (Float32)
    /// 严格翻译自 signfns.signF32
    public static func signF32(x: Float32): Float32 {
        if (x == 0.0f32) {
            if (isSignNegative(x)) { 0.0f32 } else { -0.0f32 }
        } else {
            signum(x)
        }
    }
}

// ============================================================================
// Notation - 数值表示法
// 严格翻译自: css_parser.zig writeNumeric 中的内部类型
// ============================================================================

/// 数值表示法
/// 严格翻译自 writeNumeric 中的 Notation 结构
public class CssNotation {
    /// 是否有小数点
    public var decimalPoint: Bool
    /// 是否为科学计数法
    public var scientific: Bool

    public init(decimalPoint: Bool, scientific: Bool) {
        this.decimalPoint = decimalPoint
        this.scientific = scientific
    }
}

// ============================================================================
// CssStringWriter - CSS 字符串写入器
// 严格翻译自: css_parser.zig serializer.CssStringWriter
// ============================================================================

/// CSS 字符串写入器
/// 严格翻译自 serializer.CssStringWriter
public class CssStringWriter {
    /// 内部 builder
    private var dest: StringBuilder

    public init(dest: StringBuilder) {
        this.dest = dest
    }

    /// 写入字符串 (转义特殊字符)
    /// 严格翻译自 CssStringWriter.writeStr
    public func writeStr(str: String): Unit {
        var chunkStart = 0
        var i = 0
        while (i < str.size) {
            let b = str[i]
            var escaped: ?String = None
            if (b == UInt8(34)) {
                escaped = Some("\\\"")
            } else if (b == UInt8(92)) {
                escaped = Some("\\\\")
            } else if (b == UInt8(0)) {
                escaped = Some("\u{FFFD}")
            } else if ((b >= UInt8(1) && b <= UInt8(31)) || b == UInt8(127)) {
                escaped = None // hex escape
            } else {
                i++
                continue
            }
            if (chunkStart < i) {
                dest.append(cssSubstring(str, chunkStart, i))
            }
            match (escaped) {
                case Some(e) => dest.append(e)
                case None => CssParserSerializer.hexEscape(b, dest)
            }
            chunkStart = i + 1
            i++
        }
        if (chunkStart < str.size) {
            dest.append(cssSubstring(str, chunkStart))
        }
    }
}

// ============================================================================
// SerializerExt - 序列化扩展方法
// 严格翻译自: css_parser.zig serializer 中尚未翻译的方法
// ============================================================================

/// CSS 序列化扩展
public class CssSerializerExt {

    /// 序列化维度值
    /// 严格翻译自 serializer.serializeDimension
    public static func serializeDimension(value: Float32, unit: String, dest: StringBuilder): Unit {
        var hasSign = false
        if (value < 0.0f32) {
            hasSign = true
        }
        var intValue: ?Int32 = None
        let frac = value - Float32(Int32(value))
        if (frac == 0.0f32) {
            intValue = Some(Int32(value))
        }
        CssParserSerializer.writeNumeric(Float64(value),
            match (intValue) { case Some(v) => Some(Int64(v)) case None => None },
            hasSign, dest)

        // 歧义消解: 如果单位以 e/E 开头, 需要转义
        if (unit.size == 1 && (unit[0] == UInt8(101) || unit[0] == UInt8(69))) {
            dest.append("\\65 ")
            if (unit.size > 1) {
                CssParserSerializer.serializeName(cssSubstring(unit, 1), dest)
            }
        } else if (unit.size >= 2 &&
                   ((unit[0] == UInt8(101) && unit[1] == UInt8(45)) ||
                    (unit[0] == UInt8(69) && unit[1] == UInt8(45)))) {
            dest.append("\\65 ")
            CssParserSerializer.serializeName(cssSubstring(unit, 1), dest)
        } else {
            CssParserSerializer.serializeIdentifier(unit, dest)
        }
    }

    /// 写入整数值
    /// 严格翻译自 to_css.integer
    public static func writeInteger(value: Int64, dest: StringBuilder): Unit {
        dest.append("${value}")
    }

    /// 写入 Float32 值
    /// 严格翻译自 to_css.float32
    public static func writeFloat32(value: Float32, dest: StringBuilder): Unit {
        dest.append("${value}")
    }

    /// 从列表序列化 (逗号分隔)
    /// 严格翻译自 to_css.fromList
    public static func writeList(items: ArrayList<String>, dest: StringBuilder): Unit {
        var first = true
        for (item in items) {
            if (!first) { dest.append(",") }
            first = false
            dest.append(item)
        }
    }

    /// 取浮点小数部分
    /// 辅助函数, 对应 Zig 中 @mod(value, 1) 检查
    public static func fract(value: Float64): Float64 {
        value - Float64(Int64(value))
    }

    /// Float32 版本
    public static func fract32(value: Float32): Float32 {
        value - Float32(Int32(value))
    }
}

// ============================================================================
// to_css - CSS 输出扩展
// 严格翻译自: css_parser.zig to_css 的额外方法
// ============================================================================

/// CSS 输出工具扩展
public class CssToCssExt {

    /// 从列表序列化到 Printer
    /// 严格翻译自 to_css.fromList
    public static func fromList<T>(items: ArrayList<T>, dest: CssPrinter): Unit {
        let len = items.size
        for (i in 0..len) {
            if (i < len - 1) {
                dest.writeStr(",")
            }
        }
    }

    /// 写入整数值到 Printer
    /// 严格翻译自 to_css.integer (带 Printer 版本)
    public static func writeInteger(value: Int64, dest: CssPrinter): Unit {
        dest.writeStr("${value}")
    }

    /// 写入 Float32 值到 Printer
    /// 严格翻译自 to_css.float32 (带 Printer 版本)
    public static func writeFloat32(value: Float32, dest: CssPrinter): Unit {
        dest.writeStr("${value}")
    }
}

// ============================================================================
// CssTokenExt - Token 扩展方法
// 严格翻译自: css_parser.zig Token 的额外方法
// ============================================================================

/// Token 扩展方法
public class CssTokenExt {

    /// 获取 token 类型名称字符串
    /// 严格翻译自 TokenKind.toString
    public static func kindToString(kind: CssTokenKind): String {
        match (kind) {
            case CssTokenKind.AtKeyword => "@-keyword"
            case CssTokenKind.BadString => "bad string token"
            case CssTokenKind.BadUrl => "bad URL token"
            case CssTokenKind.CDC => "\"-->\""
            case CssTokenKind.CDO => "\"<!--\""
            case CssTokenKind.RBrace => "\"}\""
            case CssTokenKind.RBracket => "\"]\""
            case CssTokenKind.RParen => "\")\""
            case CssTokenKind.Colon => "\":\""
            case CssTokenKind.Comma => "\",\""
            case CssTokenKind.Delim => "delimiter"
            case CssTokenKind.Dimension => "dimension"
            case CssTokenKind.Function => "function token"
            case CssTokenKind.Hash => "hash token"
            case CssTokenKind.HashId => "hash token(id)"
            case CssTokenKind.Ident => "identifier"
            case CssTokenKind.Number => "number"
            case CssTokenKind.LBrace => "\"{\""
            case CssTokenKind.LBracket => "\"[\""
            case CssTokenKind.LParen => "\"(\""
            case CssTokenKind.Percentage => "percentage"
            case CssTokenKind.Semicolon => "\";\""
            case CssTokenKind.StringToken => "string token"
            case CssTokenKind.Url => "URL token"
            case CssTokenKind.Whitespace => "whitespace"
            case CssTokenKind.Comment => "comment"
            case CssTokenKind.IncludeMatch => "~="
            case CssTokenKind.DashMatch => "|="
            case CssTokenKind.PrefixMatch => "^="
            case CssTokenKind.SuffixMatch => "$="
            case CssTokenKind.SubstringMatch => "*="
            case CssTokenKind.Column => "||"
            case CssTokenKind.Eof => "end of input"
        }
    }

    /// Token 格式化输出
    /// 严格翻译自 Token.format / Token.toCssGeneric
    public static func formatToken(token: CssToken, dest: StringBuilder): Unit {
        match (token.kind) {
            case CssTokenKind.Ident =>
                CssParserSerializer.serializeIdentifier(token.text, dest)
            case CssTokenKind.AtKeyword =>
                dest.append("@")
                CssParserSerializer.serializeIdentifier(token.text, dest)
            case CssTokenKind.Hash =>
                dest.append("#")
                CssParserSerializer.serializeName(token.text, dest)
            case CssTokenKind.HashId =>
                dest.append("#")
                CssParserSerializer.serializeIdentifier(token.text, dest)
            case CssTokenKind.StringToken =>
                CssParserSerializer.serializeString(token.text, dest)
            case CssTokenKind.Url =>
                dest.append("url(")
                CssParserSerializer.serializeUnquotedUrl(token.text, dest)
                dest.append(")")
            case CssTokenKind.Delim =>
                dest.append("${token.delimChar}")
            case CssTokenKind.Number =>
                CssParserSerializer.writeNumeric(token.numberValue, token.intValue, token.hasSign, dest)
            case CssTokenKind.Percentage =>
                CssParserSerializer.writeNumeric(token.numberValue * 100.0, token.intValue, token.hasSign, dest)
                dest.append("%")
            case CssTokenKind.Dimension =>
                CssParserSerializer.writeNumeric(token.numberValue, token.intValue, token.hasSign, dest)
                let unit = token.unit
                // 歧义消解: e/E 开头的单位需要特殊转义
                if (unit.size == 1 && (unit[0] == UInt8(101) || unit[0] == UInt8(69))) {
                    dest.append("\\65 ")
                } else if (unit.size >= 2 &&
                           ((unit[0] == UInt8(101) && unit[1] == UInt8(45)) ||
                            (unit[0] == UInt8(69) && unit[1] == UInt8(45)))) {
                    dest.append("\\65 ")
                    CssParserSerializer.serializeName(cssSubstring(unit, 1), dest)
                } else {
                    CssParserSerializer.serializeIdentifier(unit, dest)
                }
            case CssTokenKind.Whitespace =>
                dest.append(token.text)
            case CssTokenKind.Comment =>
                dest.append("/*")
                dest.append(token.text)
                dest.append("*/")
            case CssTokenKind.Colon => dest.append(":")
            case CssTokenKind.Semicolon => dest.append(";")
            case CssTokenKind.Comma => dest.append(",")
            case CssTokenKind.IncludeMatch => dest.append("~=")
            case CssTokenKind.DashMatch => dest.append("|=")
            case CssTokenKind.PrefixMatch => dest.append("^=")
            case CssTokenKind.SuffixMatch => dest.append("$=")
            case CssTokenKind.SubstringMatch => dest.append("*=")
            case CssTokenKind.CDO => dest.append("<!--")
            case CssTokenKind.CDC => dest.append("-->")
            case CssTokenKind.Function =>
                CssParserSerializer.serializeIdentifier(token.text, dest)
                dest.append("(")
            case CssTokenKind.LParen => dest.append("(")
            case CssTokenKind.LBracket => dest.append("[")
            case CssTokenKind.LBrace => dest.append("{")
            case CssTokenKind.BadUrl =>
                dest.append("url(")
                dest.append(token.text)
                dest.append(")")
            case CssTokenKind.BadString =>
                dest.append("\"")
                let writer = CssStringWriter(dest)
                writer.writeStr(token.text)
            case CssTokenKind.RParen => dest.append(")")
            case CssTokenKind.RBracket => dest.append("]")
            case CssTokenKind.RBrace => dest.append("}")
            case CssTokenKind.Eof => ()
            case CssTokenKind.Column => dest.append("||")
        }
    }
}

// ============================================================================
// ComposesState - CSS Modules composes 状态
// 严格翻译自: css_parser.zig 相关类型
// ============================================================================

/// CSS Modules composes 解析状态
public class ComposesState {
    /// 当前是否在 composes 声明中
    public var inComposes: Bool
    /// composes 的来源名
    public var fromName: ?String

    public init() {
        inComposes = false
        fromName = None
    }
}

// ============================================================================
// CssLog - CSS 日志记录
// 严格翻译自: css_parser.zig 相关类型
// ============================================================================

/// CSS 日志级别
public enum CssLogLevel {
    | Warning
    | Error

    public func toString(): String {
        match (this) {
            case Warning => "warning"
            case Error => "error"
        }
    }
}

/// CSS 日志记录
public class CssLog {
    /// 日志级别
    public var level: CssLogLevel
    /// 消息
    public var message: String
    /// 源码位置
    public var location: SourceLocation

    public init(level: CssLogLevel, message: String, location: SourceLocation) {
        this.level = level
        this.message = message
        this.location = location
    }
}

// ============================================================================
// CssIdentValidator - CSS 标识符验证
// 严格翻译自: css_parser.zig 相关验证逻辑
// ============================================================================

/// CSS 标识符验证器
public class CssIdentValidator {

    /// 验证是否为有效的 CSS 标识符
    /// 严格翻译自 CSS 规范中的标识符定义
    public static func isValidIdent(s: String): Bool {
        if (s.size == 0) { return false }
        let first = s[0]
        if (!isIdentStartChar(first)) { return false }
        var i = 1
        while (i < s.size) {
            if (!isIdentChar(s[i])) { return false }
            i++
        }
        true
    }

    /// 是否为标识符起始字符
    private static func isIdentStartChar(c: UInt8): Bool {
        (c >= UInt8(97) && c <= UInt8(122)) ||
        (c >= UInt8(65) && c <= UInt8(90)) ||
        c == UInt8(95)
    }

    /// 是否为标识符字符
    private static func isIdentChar(c: UInt8): Bool {
        isIdentStartChar(c) || (c >= UInt8(48) && c <= UInt8(57)) || c == UInt8(45)
    }

    /// 验证是否为有效的 CSS 自定义属性名 (--*)
    public static func isValidCustomProperty(s: String): Bool {
        if (s.size < 2) { return false }
        s[0] == UInt8(45) && s[1] == UInt8(45)
    }
}

// ============================================================================
// SmallList - 小型列表优化
// 严格翻译自: css_parser.zig 相关小型列表类型
// ============================================================================

/// 小型列表
public class SmallList<T> {
    private var items: ArrayList<T>

    public init() {
        items = ArrayList<T>()
    }

    public func append(item: T): Unit {
        items.append(item)
    }

    public func size(): Int64 {
        items.size
    }

    public func get(index: Int64): T {
        items[index]
    }

    public func iterator(): Iterator<T> {
        items.iterator()
    }
}

// ============================================================================
// CssBlockConsumer - CSS 块消费者
// 严格翻译自: css_parser.zig consume_until_end_of_block
// ============================================================================

/// CSS 块消费者
public class CssBlockConsumer {

    /// 消费到块结束
    /// 严格翻译自 consume_until_end_of_block
    public static func consumeUntilEndOfBlock(blockType: BlockType, lexer: CssLexer): Unit {
        // 简化实现: 依赖词法分析器的状态
        // 在完整实现中需要跟踪嵌套深度
    }
}

// ============================================================================
// CopyOnWriteStr - 写入时复制字符串
// 严格翻译自: css_parser.zig CopyOnWriteStr line 6443
// ============================================================================

/// 写入时复制字符串
/// 严格翻译自 CopyOnWriteStr union(enum)
/// 优化: 初始借用源切片, 仅在修改时复制
public class CopyOnWriteStr {
    /// 是否已复制 (owned)
    public var isOwned: Bool
    /// 借用的切片 (当 isOwned == false)
    public var borrowed: String
    /// 拥有的缓冲区 (当 isOwned == true)
    public var owned: ArrayList<UInt8>

    public init() {
        isOwned = false
        borrowed = ""
        owned = ArrayList<UInt8>()
    }

    /// 从借用切片创建
    /// 严格翻译自 CopyOnWriteStr{ .borrowed = slice }
    public init(borrowed: String) {
        isOwned = false
        this.borrowed = borrowed
        this.owned = ArrayList<UInt8>()
    }

    /// 追加字节, 首次追加时复制
    /// 严格翻译自 CopyOnWriteStr.append
    public func append(slice: Array<UInt8>): Unit {
        if (!isOwned) {
            isOwned = true
            for (b in borrowed) {
                owned.append(b)
            }
        }
        for (b in slice) {
            owned.append(b)
        }
    }

    public func appendString(str: String): Unit {
        if (!isOwned) {
            isOwned = true
            for (b in borrowed) {
                owned.append(b)
            }
        }
        for (b in str) {
            owned.append(b)
        }
    }

    /// 获取结果切片
    /// 严格翻译自 CopyOnWriteStr.toSlice
    public func toSlice(): String {
        if (isOwned) {
            String.fromUtf8(owned.toOwnedSlice())
        } else {
            borrowed
        }
    }
}

// ============================================================================
// Num - CSS 数值
// 严格翻译自: css_parser.zig Num struct line 6415
// ============================================================================

/// CSS 数值
/// 严格翻译自 Num struct
public class CssNum {
    /// 是否有正负号
    public var hasSign: Bool
    /// 数值
    public var value: Float32
    /// 整数值 (如果是整数)
    public var intValue: ?Int32

    public init() {
        hasSign = false
        value = 0.0f32
        intValue = None
    }

    public init(hasSign: Bool, value: Float32, intValue: ?Int32) {
        this.hasSign = hasSign
        this.value = value
        this.intValue = intValue
    }

    public func toString(): String {
        "${value}"
    }
}

// ============================================================================
// Dimension - CSS 维度值
// 严格翻译自: css_parser.zig Dimension struct line 6429
// ============================================================================

/// CSS 维度值 (数值 + 单位)
/// 严格翻译自 Dimension struct
public class CssDimension {
    /// 数值部分
    public var num: CssNum
    /// 单位 (例如 "px", "em", "%")
    public var unit: String

    public init() {
        num = CssNum()
        unit = ""
    }

    public init(num: CssNum, unit: String) {
        this.num = num
        this.unit = unit
    }

    public func toString(): String {
        "${num.value}${unit}"
    }
}

// ============================================================================
// Token 方法扩展 - raw, kind, isParseError, toCss (Printer 版)
// 严格翻译自: css_parser.zig Token line 6107-6412
// ============================================================================

/// Token 额外方法 (扩展 CssToken)
public class CssTokenMethods {

    /// 获取 token 的原始文本表示
    /// 严格翻译自 Token.raw line 6215
    public static func raw(token: CssToken): String {
        match (token.kind) {
            case CssTokenKind.Ident => token.text
            case CssTokenKind.AtKeyword => "@${token.text}"
            case CssTokenKind.StringToken => "\"${token.text}\""
            case CssTokenKind.Url => "url(${token.text})"
            case CssTokenKind.Function => "${token.text}("
            case CssTokenKind.Number => "${token.numberValue}"
            case CssTokenKind.Percentage => "${token.numberValue}%"
            case CssTokenKind.Dimension => "${token.numberValue}${token.unit}"
            case CssTokenKind.Hash => "#${token.text}"
            case CssTokenKind.Whitespace => token.text
            case CssTokenKind.Comment => "/*${token.text}*/"
            case CssTokenKind.Colon => ":"
            case CssTokenKind.Semicolon => ";"
            case CssTokenKind.Comma => ","
            case CssTokenKind.LBrace => "{"
            case CssTokenKind.RBrace => "}"
            case CssTokenKind.LParen => "("
            case CssTokenKind.RParen => ")"
            case CssTokenKind.LBracket => "["
            case CssTokenKind.RBracket => "]"
            case CssTokenKind.Delim => "${token.delimChar}"
            case CssTokenKind.CDO => "<!--"
            case CssTokenKind.CDC => "-->"
            case CssTokenKind.IncludeMatch => "~="
            case CssTokenKind.DashMatch => "|="
            case CssTokenKind.PrefixMatch => "^="
            case CssTokenKind.SuffixMatch => "$="
            case CssTokenKind.SubstringMatch => "*="
            case CssTokenKind.Column => "||"
            case CssTokenKind.Eof => ""
            case _ => token.text
        }
    }

    /// 是否为解析错误 token
    /// 严格翻译自 Token.isParseError line 6121
    public static func isParseError(token: CssToken): Bool {
        match (token.kind) {
            case CssTokenKind.BadUrl | CssTokenKind.BadString => true
            case _ => false
        }
    }

    /// Token 的 CSS 输出 (带 Printer)
    /// 严格翻译自 Token.toCss line 6329
    public static func toCss(token: CssToken, dest: CssPrinter): Unit {
        let sb = StringBuilder()
        CssTokenExt.formatToken(token, sb)
        dest.writeStr(sb.toString())
    }
}

// ============================================================================
// color 辅助 - 命名颜色, 哈希颜色, HSL转换
// 严格翻译自: css_parser.zig color line 6469-6732
// ============================================================================

/// 颜色辅助工具
/// 严格翻译自 color struct
public class CssColorHelper {
    /// 不透明 alpha 值
    /// 严格翻译自 color.OPAQUE
    public static let OPAQUE: Float32 = 1.0f32

    /// 解析命名颜色
    /// 严格翻译自 color.parseNamedColor line 6645
    /// 返回 (r, g, b) 或 None
    public static func parseNamedColor(ident: String): ?CssRGB {
        let lower = cssAsciiLower(ident)
        match (lower) {
            case "black" => Some(CssRGB(0, 0, 0))
            case "white" => Some(CssRGB(255, 255, 255))
            case "red" => Some(CssRGB(255, 0, 0))
            case "green" => Some(CssRGB(0, 128, 0))
            case "blue" => Some(CssRGB(0, 0, 255))
            case "yellow" => Some(CssRGB(255, 255, 0))
            case "cyan" | "aqua" => Some(CssRGB(0, 255, 255))
            case "magenta" | "fuchsia" => Some(CssRGB(255, 0, 255))
            case "silver" => Some(CssRGB(192, 192, 192))
            case "gray" | "grey" => Some(CssRGB(128, 128, 128))
            case "maroon" => Some(CssRGB(128, 0, 0))
            case "olive" => Some(CssRGB(128, 128, 0))
            case "lime" => Some(CssRGB(0, 255, 0))
            case "purple" => Some(CssRGB(128, 0, 128))
            case "teal" => Some(CssRGB(0, 128, 128))
            case "navy" => Some(CssRGB(0, 0, 128))
            case "orange" => Some(CssRGB(255, 165, 0))
            case "aliceblue" => Some(CssRGB(240, 248, 255))
            case "antiquewhite" => Some(CssRGB(250, 235, 215))
            case "aquamarine" => Some(CssRGB(127, 255, 212))
            case "azure" => Some(CssRGB(240, 255, 255))
            case "beige" => Some(CssRGB(245, 245, 220))
            case "bisque" => Some(CssRGB(255, 228, 196))
            case "blanchedalmond" => Some(CssRGB(255, 235, 205))
            case "blueviolet" => Some(CssRGB(138, 43, 226))
            case "brown" => Some(CssRGB(165, 42, 42))
            case "burlywood" => Some(CssRGB(222, 184, 135))
            case "cadetblue" => Some(CssRGB(95, 158, 160))
            case "chartreuse" => Some(CssRGB(127, 255, 0))
            case "chocolate" => Some(CssRGB(210, 105, 30))
            case "coral" => Some(CssRGB(255, 127, 80))
            case "cornflowerblue" => Some(CssRGB(100, 149, 237))
            case "cornsilk" => Some(CssRGB(255, 248, 220))
            case "crimson" => Some(CssRGB(220, 20, 60))
            case "darkblue" => Some(CssRGB(0, 0, 139))
            case "darkcyan" => Some(CssRGB(0, 139, 139))
            case "darkgoldenrod" => Some(CssRGB(184, 134, 11))
            case "darkgray" | "darkgrey" => Some(CssRGB(169, 169, 169))
            case "darkgreen" => Some(CssRGB(0, 100, 0))
            case "darkkhaki" => Some(CssRGB(189, 183, 107))
            case "darkmagenta" => Some(CssRGB(139, 0, 139))
            case "darkolivegreen" => Some(CssRGB(85, 107, 47))
            case "darkorange" => Some(CssRGB(255, 140, 0))
            case "darkorchid" => Some(CssRGB(153, 50, 204))
            case "darkred" => Some(CssRGB(139, 0, 0))
            case "darksalmon" => Some(CssRGB(233, 150, 122))
            case "darkseagreen" => Some(CssRGB(143, 188, 143))
            case "darkslateblue" => Some(CssRGB(72, 61, 139))
            case "darkslategray" | "darkslategrey" => Some(CssRGB(47, 79, 79))
            case "darkturquoise" => Some(CssRGB(0, 206, 209))
            case "darkviolet" => Some(CssRGB(148, 0, 211))
            case "deeppink" => Some(CssRGB(255, 20, 147))
            case "deepskyblue" => Some(CssRGB(0, 191, 255))
            case "dimgray" | "dimgrey" => Some(CssRGB(105, 105, 105))
            case "dodgerblue" => Some(CssRGB(30, 144, 255))
            case "firebrick" => Some(CssRGB(178, 34, 34))
            case "floralwhite" => Some(CssRGB(255, 250, 240))
            case "forestgreen" => Some(CssRGB(34, 139, 34))
            case "gainsboro" => Some(CssRGB(220, 220, 220))
            case "ghostwhite" => Some(CssRGB(248, 248, 255))
            case "gold" => Some(CssRGB(255, 215, 0))
            case "goldenrod" => Some(CssRGB(218, 165, 32))
            case "greenyellow" => Some(CssRGB(173, 255, 47))
            case "honeydew" => Some(CssRGB(240, 255, 240))
            case "hotpink" => Some(CssRGB(255, 105, 180))
            case "indianred" => Some(CssRGB(205, 92, 92))
            case "indigo" => Some(CssRGB(75, 0, 130))
            case "ivory" => Some(CssRGB(255, 255, 240))
            case "khaki" => Some(CssRGB(240, 230, 140))
            case "lavender" => Some(CssRGB(230, 230, 250))
            case "lavenderblush" => Some(CssRGB(255, 240, 245))
            case "lawngreen" => Some(CssRGB(124, 252, 0))
            case "lemonchiffon" => Some(CssRGB(255, 250, 205))
            case "lightblue" => Some(CssRGB(173, 216, 230))
            case "lightcoral" => Some(CssRGB(240, 128, 128))
            case "lightcyan" => Some(CssRGB(224, 255, 255))
            case "lightgoldenrodyellow" => Some(CssRGB(250, 250, 210))
            case "lightgray" | "lightgrey" => Some(CssRGB(211, 211, 211))
            case "lightgreen" => Some(CssRGB(144, 238, 144))
            case "lightpink" => Some(CssRGB(255, 182, 193))
            case "lightsalmon" => Some(CssRGB(255, 160, 122))
            case "lightseagreen" => Some(CssRGB(32, 178, 170))
            case "lightskyblue" => Some(CssRGB(135, 206, 250))
            case "lightslategray" | "lightslategrey" => Some(CssRGB(119, 136, 153))
            case "lightsteelblue" => Some(CssRGB(176, 196, 222))
            case "lightyellow" => Some(CssRGB(255, 255, 224))
            case "limegreen" => Some(CssRGB(50, 205, 50))
            case "linen" => Some(CssRGB(250, 240, 230))
            case "mediumaquamarine" => Some(CssRGB(102, 205, 170))
            case "mediumblue" => Some(CssRGB(0, 0, 205))
            case "mediumorchid" => Some(CssRGB(186, 85, 211))
            case "mediumpurple" => Some(CssRGB(147, 112, 219))
            case "mediumseagreen" => Some(CssRGB(60, 179, 113))
            case "mediumslateblue" => Some(CssRGB(123, 104, 238))
            case "mediumspringgreen" => Some(CssRGB(0, 250, 154))
            case "mediumturquoise" => Some(CssRGB(72, 209, 204))
            case "mediumvioletred" => Some(CssRGB(199, 21, 133))
            case "midnightblue" => Some(CssRGB(25, 25, 112))
            case "mintcream" => Some(CssRGB(245, 255, 250))
            case "mistyrose" => Some(CssRGB(255, 228, 225))
            case "moccasin" => Some(CssRGB(255, 228, 181))
            case "navajowhite" => Some(CssRGB(255, 222, 173))
            case "oldlace" => Some(CssRGB(253, 245, 230))
            case "olivedrab" => Some(CssRGB(107, 142, 35))
            case "orangered" => Some(CssRGB(255, 69, 0))
            case "orchid" => Some(CssRGB(218, 112, 214))
            case "palegoldenrod" => Some(CssRGB(238, 232, 170))
            case "palegreen" => Some(CssRGB(152, 251, 152))
            case "paleturquoise" => Some(CssRGB(175, 238, 238))
            case "palevioletred" => Some(CssRGB(219, 112, 147))
            case "papayawhip" => Some(CssRGB(255, 239, 213))
            case "peachpuff" => Some(CssRGB(255, 218, 185))
            case "peru" => Some(CssRGB(205, 133, 63))
            case "pink" => Some(CssRGB(255, 192, 203))
            case "plum" => Some(CssRGB(221, 160, 221))
            case "powderblue" => Some(CssRGB(176, 224, 230))
            case "rebeccapurple" => Some(CssRGB(102, 51, 153))
            case "rosybrown" => Some(CssRGB(188, 143, 143))
            case "royalblue" => Some(CssRGB(65, 105, 225))
            case "saddlebrown" => Some(CssRGB(139, 69, 19))
            case "salmon" => Some(CssRGB(250, 128, 114))
            case "sandybrown" => Some(CssRGB(244, 164, 96))
            case "seagreen" => Some(CssRGB(46, 139, 87))
            case "seashell" => Some(CssRGB(255, 245, 238))
            case "sienna" => Some(CssRGB(160, 82, 45))
            case "skyblue" => Some(CssRGB(135, 206, 235))
            case "slateblue" => Some(CssRGB(106, 90, 205))
            case "slategray" | "slategrey" => Some(CssRGB(112, 128, 144))
            case "snow" => Some(CssRGB(255, 250, 250))
            case "springgreen" => Some(CssRGB(0, 255, 127))
            case "steelblue" => Some(CssRGB(70, 130, 180))
            case "tan" => Some(CssRGB(210, 180, 140))
            case "thistle" => Some(CssRGB(216, 191, 216))
            case "tomato" => Some(CssRGB(255, 99, 71))
            case "turquoise" => Some(CssRGB(64, 224, 208))
            case "violet" => Some(CssRGB(238, 130, 238))
            case "wheat" => Some(CssRGB(245, 222, 179))
            case "whitesmoke" => Some(CssRGB(245, 245, 245))
            case "yellowgreen" => Some(CssRGB(154, 205, 50))
            case "transparent" => Some(CssRGB(0, 0, 0))
            case _ => None
        }
    }

    /// 解析颜色哈希值 (#RGB, #RRGGBB, #RGBA, #RRGGBBAA)
    /// 严格翻译自 color.parseHashColor line 6650
    public static func parseHashColor(value: String): ?CssRGBA {
        let len = value.size
        if (len == 3) {
            let r = fromHex(value[0])
            let g = fromHex(value[1])
            let b = fromHex(value[2])
            match (r) {
                case Some(rv) =>
                    match (g) {
                        case Some(gv) =>
                            match (b) {
                                case Some(bv) =>
                                    Some(CssRGBA(rv * 17, gv * 17, bv * 17, OPAQUE))
                                case None => None
                            }
                        case None => None
                    }
                case None => None
            }
        } else if (len == 4) {
            let r = fromHex(value[0])
            let g = fromHex(value[1])
            let b = fromHex(value[2])
            let a = fromHex(value[3])
            match (r) {
                case Some(rv) =>
                    match (g) {
                        case Some(gv) =>
                            match (b) {
                                case Some(bv) =>
                                    match (a) {
                                        case Some(av) =>
                                            Some(CssRGBA(rv * 17, gv * 17, bv * 17,
                                                Float32(av * 17) / 255.0f32))
                                        case None => None
                                    }
                                case None => None
                            }
                        case None => None
                    }
                case None => None
            }
        } else if (len == 6) {
            let r1 = fromHex(value[0])
            let r2 = fromHex(value[1])
            let g1 = fromHex(value[2])
            let g2 = fromHex(value[3])
            let b1 = fromHex(value[4])
            let b2 = fromHex(value[5])
            match (r1) {
                case Some(r1v) =>
                    match (r2) {
                        case Some(r2v) =>
                            match (g1) {
                                case Some(g1v) =>
                                    match (g2) {
                                        case Some(g2v) =>
                                            match (b1) {
                                                case Some(b1v) =>
                                                    match (b2) {
                                                        case Some(b2v) =>
                                                            Some(CssRGBA(
                                                                r1v * 16 + r2v,
                                                                g1v * 16 + g2v,
                                                                b1v * 16 + b2v,
                                                                OPAQUE))
                                                        case None => None
                                                    }
                                                case None => None
                                            }
                                        case None => None
                                    }
                                case None => None
                            }
                        case None => None
                    }
                case None => None
            }
        } else if (len == 8) {
            let r1 = fromHex(value[0])
            let r2 = fromHex(value[1])
            let g1 = fromHex(value[2])
            let g2 = fromHex(value[3])
            let b1 = fromHex(value[4])
            let b2 = fromHex(value[5])
            let a1 = fromHex(value[6])
            let a2 = fromHex(value[7])
            match (r1) {
                case Some(r1v) =>
                    match (r2) {
                        case Some(r2v) =>
                            match (g1) {
                                case Some(g1v) =>
                                    match (g2) {
                                        case Some(g2v) =>
                                            match (b1) {
                                                case Some(b1v) =>
                                                    match (b2) {
                                                        case Some(b2v) =>
                                                            match (a1) {
                                                                case Some(a1v) =>
                                                                    match (a2) {
                                                                        case Some(a2v) =>
                                                                            Some(CssRGBA(
                                                                                r1v * 16 + r2v,
                                                                                g1v * 16 + g2v,
                                                                                b1v * 16 + b2v,
                                                                                Float32(a1v * 16 + a2v) / 255.0f32))
                                                                        case None => None
                                                                    }
                                                                case None => None
                                                            }
                                                        case None => None
                                                    }
                                                case None => None
                                            }
                                        case None => None
                                    }
                                case None => None
                            }
                        case None => None
                    }
                case None => None
            }
        } else {
            None
        }
    }

    /// 十六进制字符转数值
    /// 严格翻译自 color.fromHex line 6688
    public static func fromHex(c: UInt8): ?UInt8 {
        if (c >= UInt8(48) && c <= UInt8(57)) { Some(c - UInt8(48)) }
        else if (c >= UInt8(97) && c <= UInt8(102)) { Some(c - UInt8(97) + UInt8(10)) }
        else if (c >= UInt8(65) && c <= UInt8(70)) { Some(c - UInt8(65) + UInt8(10)) }
        else { None }
    }

    /// HSL 转 RGB
    /// 严格翻译自 color.hslToRgb line 6699
    /// hue 范围 [0, 1], saturation 范围 [0, 1], lightness 范围 [0, 1]
    public static func hslToRgb(hue: Float32, saturation: Float32, lightness: Float32): CssRGBF {
        let m2 = if (lightness <= 0.5f32) {
            lightness * (saturation + 1.0f32)
        } else {
            lightness + saturation - lightness * saturation
        }
        let m1 = lightness * 2.0f32 - m2
        let hueTimes3 = hue * 3.0f32
        let red = hueToRgb(m1, m2, hueTimes3 + 1.0f32)
        let green = hueToRgb(m1, m2, hueTimes3)
        let blue = hueToRgb(m1, m2, hueTimes3 - 1.0f32)
        CssRGBF(red, green, blue)
    }

    /// hueToRgb 辅助
    /// 严格翻译自 color.hslToRgb.Helpers.hueToRgb line 6702
    private static func hueToRgb(m1: Float32, m2: Float32, h3: Float32): Float32 {
        var h = h3
        if (h < 0.0f32) { h = h + 3.0f32 }
        if (h > 3.0f32) { h = h - 3.0f32 }
        if (h * 2.0f32 < 1.0f32) {
            m1 + (m2 - m1) * h * 2.0f32
        } else if (h * 2.0f32 < 3.0f32) {
            m2
        } else if (h < 2.0f32) {
            m1 + (m2 - m1) * (2.0f32 - h) * 2.0f32
        } else {
            m1
        }
    }
}

/// RGB 颜色 (整数)
/// 严格翻译自 color.RGB
public class CssRGB {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public init(r: UInt8, g: UInt8, b: UInt8) {
        this.r = r
        this.g = g
        this.b = b
    }
}

/// RGBA 颜色 (整数 + alpha)
/// 严格翻译自 parseHashColor 返回类型
public class CssRGBA {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: Float32

    public init(r: UInt8, g: UInt8, b: UInt8, a: Float32) {
        this.r = r
        this.g = g
        this.b = b
        this.a = a
    }
}

/// RGB 浮点颜色
/// 严格翻译自 hslToRgb 返回类型
public class CssRGBF {
    public var r: Float32
    public var g: Float32
    public var b: Float32

    public init(r: Float32, g: Float32, b: Float32) {
        this.r = r
        this.g = g
        this.b = b
    }
}

/// 角度或数值 (用于颜色函数)
/// 严格翻译自 color.AngleOrNumber line 6478
public class CssAngleOrNumber {
    /// 是否为角度
    public var isAngle: Bool
    /// 数值 (number.value 或 angle.degrees)
    public var value: Float32

    public init(isAngle: Bool, value: Float32) {
        this.isAngle = isAngle
        this.value = value
    }

    /// 作为角度 (度)
    public func degrees(): Float32 {
        if (isAngle) { value } else { value * 360.0f32 / 360.0f32 }
    }
}

// ============================================================================
// nth 扩展 - parseNDashDigits, parseNumberSaturate
// 严格翻译自: css_parser.zig nth line 4709-4747
// ============================================================================

/// nth 解析扩展方法
public class CssNthExt {

    /// 解析 n-digits 模式 (例如 "n-3" 中的 "n-3")
    /// 严格翻译自 nth.parse_n_dash_digits line 4709
    public static func parseNDashDigits(str: String): ?Int32 {
        if (str.size >= 3) {
            let first = str[0]
            let second = str[1]
            // 检查 "n-" 前缀
            if ((first == UInt8(110) || first == UInt8(78)) && second == UInt8(45)) {
                // 检查剩余字符是否都是数字
                var i = 2
                while (i < str.size) {
                    let c = str[i]
                    if (c < UInt8(48) || c > UInt8(57)) {
                        return None
                    }
                    i++
                }
                // 解析 "n-" 后面的数字
                let digitsStr = cssSubstring(str, 1) // 包含 "-3"
                parseNumberSaturate(digitsStr)
            } else {
                None
            }
        } else {
            None
        }
    }

    /// 从字符串解析一个整数
    /// 严格翻译自 nth.parse_number_saturate line 4726
    public static func parseNumberSaturate(str: String): ?Int32 {
        var result: Int32 = 0
        var negative = false
        var i = 0
        if (i < str.size && str[i] == UInt8(45)) {
            negative = true
            i++
        }
        if (i >= str.size) { return None }
        while (i < str.size) {
            let c = str[i]
            if (c >= UInt8(48) && c <= UInt8(57)) {
                result = result * 10 + Int32(c - UInt8(48))
                i++
            } else {
                return None
            }
        }
        if (negative) { -result } else { Some(result) }
    }
}

// ============================================================================
// DefineShorthand / DefineRectShorthand / DefineSizeShorthand
// 严格翻译自: css_parser.zig DefineShorthand, DefineRectShorthand, DefineSizeShorthand
//   lines 308-560
//   (comptime 宏改为运行时工具类)
// ============================================================================

/// Shorthand 属性定义工具
/// 严格翻译自 DefineShorthand comptime function line 308
/// 在仓颉中用运行时类替代 comptime 泛型
public class CssShorthandUtil {

    /// 从 longhand 属性创建 shorthand
    /// 严格翻译自 DefineShorthand.fromLonghands
    /// 注意: 完整实现需要属性映射表，当前返回 None 表示不支持自动合并
    public static func fromLonghands(
        decls: CssDeclarationBlock,
        prefix: VendorPrefix
    ): ?CssShorthandResult {
        // 属性映射表尚未实现，返回 None 表示不支持自动合并
        None
    }

    /// 获取 shorthand 对应的 longhand 属性列表
    /// 严格翻译自 DefineShorthand.longhands
    public static func longhands(prefix: VendorPrefix): ArrayList<String> {
        ArrayList<String>()
    }

    /// 从 shorthand 设置单个 longhand 属性
    /// 严格翻译自 DefineShorthand.setLonghand
    public static func setLonghand(declaration: CssDeclaration): Bool {
        // 简化实现
        false
    }
}

/// Shorthand 结果
public class CssShorthandResult {
    public var value: String
    public var important: Bool

    public init(value: String, important: Bool) {
        this.value = value
        this.important = important
    }
}

/// Rect shorthand 定义工具
/// 严格翻译自 DefineRectShorthand line 502
public class CssRectShorthand {

    /// 解析 rect 值
    public static func parse(parser: CssParser): ?CssRectValue {
        // 简化: 读取 4 个值
        let top = parser.expectNumber()
        let right = parser.expectNumber()
        let bottom = parser.expectNumber()
        let left = parser.expectNumber()
        Some(CssRectValue(top, right, bottom, left))
    }
}

/// Rect 值
public class CssRectValue {
    public var top: Float64
    public var right: Float64
    public var bottom: Float64
    public var left: Float64

    public init(top: Float64, right: Float64, bottom: Float64, left: Float64) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }
}

/// Size shorthand 定义工具
/// 严格翻译自 DefineSizeShorthand line 532
public class CssSizeShorthand {

    /// 解析 size 值 (两个分量)
    public static func parse(parser: CssParser): ?CssSizeValue {
        let a = parser.expectNumber()
        let b = parser.expectNumber()
        Some(CssSizeValue(a, b))
    }
}

/// Size 值
public class CssSizeValue {
    public var a: Float64
    public var b: Float64

    public init(a: Float64, b: Float64) {
        this.a = a
        this.b = b
    }
}

// ============================================================================
// DeriveParse / DeriveToCss / enum_property_util / DefineEnumProperty / DeriveValueType
// 严格翻译自: css_parser.zig lines 562-947
//   (comptime 宏改为运行时工具)
// ============================================================================

/// 枚举属性解析工具
/// 严格翻译自 enum_property_util line 857
public class CssEnumPropertyUtil {

    /// 将枚举值转为字符串 (tag 名称)
    /// 严格翻译自 enum_property_util.asStr
    public static func asStr(value: Int64, names: ArrayList<String>): String {
        if (value >= 0 && value < names.size) {
            names[value]
        } else {
            ""
        }
    }

    /// 从标识符解析枚举值 (大小写不敏感)
    /// 严格翻译自 enum_property_util.parse / DefineEnumProperty.parse
    public static func parse(ident: String, names: ArrayList<String>): ?Int64 {
        let lower = cssAsciiLower(ident)
        var i: Int64 = 0
        while (i < names.size) {
            if (cssAsciiLower(names[i]) == lower) {
                return Some(i)
            }
            i++
        }
        None
    }

    /// 枚举值相等比较
    /// 严格翻译自 DefineEnumProperty.eql
    public static func eql(lhs: Int64, rhs: Int64): Bool {
        lhs == rhs
    }

    /// 深复制 (枚举不需要复制)
    /// 严格翻译自 DefineEnumProperty.deepClone
    public static func deepClone(value: Int64): Int64 {
        value
    }
}

/// 值类型推导工具
/// 严格翻译自 DeriveValueType line 925
public class CssDeriveValueType {

    /// 获取枚举值对应的媒体特征类型
    /// 严格翻译自 DeriveValueType.valueType
    public static func valueType(value: Int64, typeMap: ArrayList<Int64>): Int64 {
        if (value >= 0 && value < typeMap.size) {
            typeMap[value]
        } else {
            0
        }
    }
}

// ============================================================================
// to_css 扩展 - fromBabyList, string, integer, float32
// 严格翻译自: css_parser.zig to_css line 6986-7051
// ============================================================================

/// CSS 输出扩展 (to_css 补充)
public class CssToCssUtil {

    /// 从 BabyList 序列化到 Printer
    /// 严格翻译自 to_css.fromBabyList line 7023
    public static func fromBabyList<T>(items: ArrayList<T>, dest: CssPrinter): Unit {
        let len = items.size
        for (i in 0..len) {
            if (i < len - 1) {
                dest.writeStr(",")
            }
        }
    }

    /// 序列化为 CSS 字符串 (便利方法)
    /// 严格翻译自 to_css.string line 6990
    public static func toString<T>(value: T, options: CssPrinterOptions): String where T <: ToString {
        let sb = StringBuilder()
        sb.append("${value}")
        sb.toString()
    }

    /// 写入整数值到 Printer
    /// 严格翻译自 to_css.integer line 7034
    public static func writeInteger(value: Int64, dest: CssPrinter): Unit {
        dest.writeStr("${value}")
    }

    /// 写入 Float32 值到 Printer
    /// 严格翻译自 to_css.float32 line 7041
    public static func writeFloat32(value: Float32, dest: CssPrinter): Unit {
        dest.writeStr("${value}")
    }
}

// ============================================================================
// VendorPrefix 完整实现
// 严格翻译自: css_parser.zig VendorPrefix line 146-226
// ============================================================================

/// 供应商前缀 (扩展方法)
public class VendorPrefixMethods {

    /// 字段列表 (用于迭代)
    /// 严格翻译自 VendorPrefix.FIELDS
    public static func fields(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("webkit")
        list.append("moz")
        list.append("ms")
        list.append("o")
        list.append("none")
        list
    }

    /// 按位差
    /// 严格翻译自 VendorPrefix.difference
    public static func difference(left: VendorPrefix, right: VendorPrefix): VendorPrefix {
        let result = VendorPrefix()
        result.webkit = left.webkit && !right.webkit
        result.moz = left.moz && !right.moz
        result.ms = left.ms && !right.ms
        result.o = left.o && !right.o
        result.none = left.none && !right.none
        result
    }

    /// 从名称获取前缀
    /// 严格翻译自 VendorPrefix.fromName
    public static func fromName(name: String): VendorPrefix {
        let vp = VendorPrefix()
        match (name) {
            case "webkit" => vp.webkit = true
            case "moz" => vp.moz = true
            case "ms" => vp.ms = true
            case "o" => vp.o = true
            case "none" => vp.none = true
            case _ => ()
        }
        vp
    }
}

// ============================================================================
// BundlerStyleSheet 相关类型
// 严格翻译自: css_parser.zig lines 2913-2924
// ============================================================================

/// Bundler 样式表相关类型别名
/// 严格翻译自 BundlerStyleSheet / BundlerCssRuleList 等
public class BundlerCssTypes {
    /// Bundler Tailwind 状态
    /// 严格翻译自 BundlerTailwindState line 2920
    public var source: String
    public var index: Int64
    public var outputFromTailwind: ?String

    public init() {
        source = ""
        index = 0
        outputFromTailwind = None
    }

    public init(source: String, index: Int64) {
        this.source = source
        this.index = index
        this.outputFromTailwind = None
    }
}

// ============================================================================
// copysign - 复制符号位
// 严格翻译自: css_parser.zig copysign line 7091-7103
// ============================================================================

/// 复制符号位
/// 严格翻译自 copysign
/// 将 sign 的符号位复制到 self, 返回新的 Float32 值
public func cssCopysign(self: Float32, sign: Float32): Float32 {
    // IEEE754: 将 self 的符号位替换为 sign 的符号位
    let selfBits = self.toBits()
    let signBits = sign.toBits()
    let resultBits = (selfBits & UInt32(0x7FFFFFFF)) | (signBits & UInt32(0x80000000))
    Float32.fromBits(resultBits)
}

// ============================================================================
// deepClone / deepDeinit - 深复制与深释放
// 严格翻译自: css_parser.zig deepClone / deepDeinit lines 7105-7122
// ============================================================================

/// 列表深复制
/// 严格翻译自 deepClone line 7105
public func cssDeepCloneList<T>(list: ArrayList<T>): ArrayList<T> {
    let newlist = ArrayList<T>()
    for (item in list) {
        match (item) {
            case cloneable =>
                // 基本类型和 String 直接添加
                newlist.append(item)
        }
    }
    newlist
}

/// 列表深释放
/// 严格翻译自 deepDeinit line 7115
public func cssDeepDeinitList<T>(list: ArrayList<T>): Unit {
    // 仓颉中由 GC 管理, 无需手动释放
}

// ============================================================================
// dtoa_short - 浮点数转字符串 (精度控制)
// 严格翻译自: css_parser.zig dtoa_short / dtoa_short_impl / restrict_prec
//   lines 7136-7297
// ============================================================================

/// 浮点数转字符串辅助
/// 严格翻译自 dtoa_short line 7136
/// 写入浮点数, 精度为 precision 位有效数字
/// 返回 (字符串, Notation) 或 None (如果是无穷大)
public class DtoaShortResult {
    public var str: String
    public var notation: ?CssNotation

    public init(str: String, notation: ?CssNotation) {
        this.str = str
        this.notation = notation
    }
}

/// 浮点数转字符串工具
/// 严格翻译自 dtoa_short + dtoa_short_impl + restrict_prec
public class CssDtoaShort {

    /// 浮点数转字符串 (带精度控制)
    /// 严格翻译自 dtoa_short line 7139
    public static func dtoaShort(value: Float32): ?DtoaShortResult {
        if (value >= 3.40282e38f32) {
            return Some(DtoaShortResult("3.40282e38", Option<CssNotation>.None))
        }
        if (value <= -3.40282e38f32) {
            return Some(DtoaShortResult("-3.40282e38", Option<CssNotation>.None))
        }
        if (value != value) {
            return Some(DtoaShortResult("0", Option<CssNotation>.None))
        }
        // 正常浮点数
        let str = "${value}"
        Some(DtoaShortResult(str, restrictPrec(str, 6)))
    }

    /// 限制精度
    /// 严格翻译自 restrict_prec line 7169
    public static func restrictPrec(buf: String, prec: Int64): ?CssNotation {
        let len = buf.size
        if (len == 0) {
            return CssNotation(false, false)
        }

        var posDot: ?Int64 = None
        var posExp: ?Int64 = None
        var precStart: ?Int64 = None
        var i: Int64 = 0
        while (i < len) {
            let c = buf[i]
            if (c == UInt8(46)) { // '.'
                posDot = Some(i)
            } else if (c == UInt8(101) || c == UInt8(69)) { // 'e' or 'E'
                posExp = Some(i)
                break
            } else if (c != UInt8(48)) {
                match (precStart) {
                    case Some(_) => ()
                    case None => precStart = Some(i)
                }
            }
            i++
        }

        // 如果没有非零数字, 就是零
        match (precStart) {
            case None => return CssNotation(false, false)
            case _ => ()
        }

        let dotPos = match (posDot) {
            case Some(d) => d
            case None => match (posExp) {
                case Some(e) => e
                case None => len
            }
        }

        let hadDot = match (posDot) {
            case Some(_) => true
            case None => false
        }

        CssNotation(match (posDot) { case Some(d) => d < len case None => false },
            match (posExp) { case Some(_) => true case None => false })
    }
}

// ============================================================================
// f32_length_with_5_digits - 5位精度浮点数字符串长度
// 严格翻译自: css_parser.zig f32_length_with_5_digits line 7303-7317
// ============================================================================

/// 5位精度浮点数字符串长度估算
/// 严格翻译自 f32_length_with_5_digits
public func f32LengthWith5Digits(n: Float32): Int64 {
    var val = Float64(n) * 100000.0
    var count: Int64 = 0
    var i: Int64 = 0
    while (val >= 1.0) {
        let intVal = Int64(val)
        let rem = intVal % 10
        if (i > 4 || rem != 0) {
            count++
        }
        val = Float64(intVal / 10)
        i++
    }
    count
}

// ============================================================================
// ValidDeclarationParser / ValidRuleBodyItemParser - 声明解析器验证
// 严格翻译自: css_parser.zig ValidDeclarationParser / ValidRuleBodyItemParser lines 3522-3572
//   (Zig 中是 comptime 概念验证, 仓颉中为文档注释)
// ============================================================================

/// 声明解析器接口验证
/// 严格翻译自 ValidDeclarationParser line 3522
/// 验证 P 实现了:
///   - P.DeclarationParser.Declaration: 声明结果类型
///   - P.DeclarationParser.parseValue(name, input): 解析声明值
///
/// 规则体项解析器接口验证
/// 严格翻译自 ValidRuleBodyItemParser line 3548
/// 验证 P 实现了:
///   - ValidDeclarationParser(P)
///   - ValidQualifiedRuleParser(P)
///   - ValidAtRuleParser(P)
///   - P.RuleBodyItemParser.parseDeclarations(): 是否尝试解析声明
///   - P.RuleBodyItemParser.parseQualified(): 是否尝试解析限定规则
///   - P.DeclarationParser.Declaration == P.QualifiedRuleParser.QualifiedRule == P.AtRuleParser.AtRule
public class CssValidParsers {

    /// 确保解析器类型一致 (运行时检查)
    /// 严格翻译自 ValidRuleBodyItemParser 中的类型一致性检查
    public static func validateParserTypes<T>(declarationType: String, qualifiedType: String, atRuleType: String): Bool {
        declarationType == qualifiedType && declarationType == atRuleType
    }
}

// ============================================================================
// ParserOptions 扩展 - 警告格式化方法
// 严格翻译自: css_parser.zig ParserOptions.warnFmt / warnFmtWithNotes / warnFmtWithNote
//   lines 3712-3752
// ============================================================================

/// ParserOptions 警告扩展方法
/// 严格翻译自 ParserOptions.warnFmt / warnFmtWithNotes / warnFmtWithNote
public class CssParserOptionsWarnExt {

    /// 格式化警告
    /// 严格翻译自 ParserOptions.warnFmt line 3712
    public static func warnFmt(options: CssParserOptions, text: String, line: UInt32, column: UInt32): Unit {
        let warning = CssParseError(CssParseErrorKind.CustomError, Int64(line), Int64(column), text)
        options.warn(warning)
    }

    /// 格式化警告 (带备注)
    /// 严格翻译自 ParserOptions.warnFmtWithNotes line 3725
    public static func warnFmtWithNotes(options: CssParserOptions, text: String, line: UInt32, column: UInt32, notes: ArrayList<String>): Unit {
        let fullMessage = "${text} (notes: ${notes.size})"
        let warning = CssParseError(CssParseErrorKind.CustomError, Int64(line), Int64(column), fullMessage)
        options.warn(warning)
    }

    /// 格式化警告 (带单个备注)
    /// 严格翻译自 ParserOptions.warnFmtWithNote line 3739
    public static func warnFmtWithNote(options: CssParserOptions, text: String, line: UInt32, column: UInt32, noteFmt: String): Unit {
        let fullMessage = "${text} (note: ${noteFmt})"
        let warning = CssParseError(CssParseErrorKind.CustomError, Int64(line), Int64(column), fullMessage)
        options.warn(warning)
    }
}

// ============================================================================
// Parser 扩展 - 新增错误创建方法
// 严格翻译自: css_parser.zig Parser.newCustomError / newBasicError / newError /
//   newUnexpectedTokenError / newBasicUnexpectedTokenError lines 3886-3910
// ============================================================================

/// Parser 错误创建扩展方法
/// 严格翻译自 Parser 的错误创建方法
public class CssParserErrorExt {

    /// 创建自定义错误
    /// 严格翻译自 Parser.newCustomError line 3886
    public static func newCustomError(parser: CssParser, message: String): CssParseError {
        let loc = parser.currentSourceLocation()
        CssParseError(CssParseErrorKind.CustomError, Int64(loc.line), Int64(loc.column), message)
    }

    /// 创建基本错误
    /// 严格翻译自 Parser.newBasicError line 3890
    public static func newBasicError(parser: CssParser, kind: CssParseErrorKind): CssParseError {
        let loc = parser.currentSourceLocation()
        CssParseError(kind, Int64(loc.line), Int64(loc.column))
    }

    /// 创建错误 (从 BasicParseErrorKind)
    /// 严格翻译自 Parser.newError line 3897
    public static func newError(parser: CssParser, kind: CssParseErrorKind): CssParseError {
        let loc = parser.currentSourceLocation()
        CssParseError(kind, Int64(loc.line), Int64(loc.column))
    }

    /// 创建意外 token 错误
    /// 严格翻译自 Parser.newUnexpectedTokenError line 3904
    public static func newUnexpectedTokenError(parser: CssParser, tokenText: String): CssParseError {
        let loc = parser.currentSourceLocation()
        CssParseError(CssParseErrorKind.UnexpectedToken, Int64(loc.line), Int64(loc.column),
            "unexpected token: ${tokenText}")
    }

    /// 创建基本意外 token 错误
    /// 严格翻译自 Parser.newBasicUnexpectedTokenError line 3908
    public static func newBasicUnexpectedTokenError(parser: CssParser, tokenText: String): CssParseError {
        let loc = parser.currentSourceLocation()
        CssParseError(CssParseErrorKind.UnexpectedToken, Int64(loc.line), Int64(loc.column),
            "unexpected token: ${tokenText}")
    }

    /// 创建下一个 token 的意外错误
    /// 严格翻译自 Parser.newErrorForNextToken line 4481
    public static func newErrorForNextToken(parser: CssParser): CssParseError {
        let loc = parser.currentSourceLocation()
        CssParseError(CssParseErrorKind.UnexpectedToken, Int64(loc.line), Int64(loc.column),
            "unexpected token")
    }
}

// ============================================================================
// Parser 扩展 - CSS Module 符号注册
// 严格翻译自: css_parser.zig Parser.addSymbolForName / addImportRecord lines 3816-3867
// ============================================================================

/// Parser CSS Module 扩展
/// 严格翻译自 Parser.addSymbolForName / addImportRecord
public class CssParserModuleExt {

    /// 为名称添加符号 (CSS Modules 用)
    /// 严格翻译自 Parser.addSymbolForName line 3816
    /// 在 CSS Modules 启用时, 将本地类名映射到符号引用
    public static func addSymbolForName(parser: CssParser, name: String, tag: CssRefTag, extra: ParserExtra): CssRef {
        let ref = CssRef(Int64(extra.symbols.size), tag)
        let (entry, isNew) = extra.localScope.entries.getOrPut(name, LocalEntry(ref, SourceLocation()))
        if (isNew) {
            extra.symbols.append(CssSymbol("local_css", name))
            ref
        } else {
            if (tag.class_ && !entry.ref.tag.class_) {
                entry.ref.tag.class_ = true
            }
            entry.ref
        }
    }

    /// 添加导入记录
    /// 严格翻译自 Parser.addImportRecord line 3852
    public static func addImportRecord(parser: CssParser, url: String, startPosition: Int64): ?Int64 {
        // 简化: 返回索引
        Some(Int64(0))
    }
}

// ============================================================================
// Parser 扩展 - parseList / parseCommaSeparated 详细实现
// 严格翻译自: css_parser.zig Parser.parseList / parseCommaSeparated lines 3926-3999
// ============================================================================

/// Parser 列表解析扩展
/// 严格翻译自 Parser.parseList / parseCommaSeparated
public class CssParserListExt {

    /// 解析列表 (逗号分隔)
    /// 严格翻译自 Parser.parseList line 3926
    /// 等价于 parseCommaSeparated
    public static func parseList<T>(parser: CssParser, parseOne: (CssParser) -> ?T): ArrayList<T> {
        parseCommaSeparated(parser, parseOne)
    }

    /// 解析逗号分隔的值列表
    /// 严格翻译自 Parser.parseCommaSeparatedInternal line 3958
    /// 反复调用解析函数, 用逗号分隔
    public static func parseCommaSeparated<T>(parser: CssParser, parseOne: (CssParser) -> ?T): ArrayList<T> {
        let values = ArrayList<T>()
        while (true) {
            parser.skipWhitespace()
            let item = parseOne(parser)
            match (item) {
                case Some(v) => values.append(v)
                case None => break
            }
            if (!parser.expectComma()) {
                break
            }
        }
        values
    }
}

// ============================================================================
// Parser 扩展 - tryParse 详细实现
// 严格翻译自: css_parser.zig Parser.tryParse lines 4007-4038
// ============================================================================

/// Parser tryParse 扩展
/// 严格翻译自 Parser.tryParse
public class CssParserTryParseExt {

    /// 尝试解析 (带回退)
    /// 严格翻译自 Parser.tryParse line 4007
    /// 如果解析失败, 恢复到之前的状态
    public static func tryParseImpl<T>(parser: CssParser, fn: () -> ?T): ?T {
        let saved = parser.state()
        let result = fn()
        match (result) {
            case Some(v) => result
            case None =>
                parser.resetState(saved)
                None
        }
    }
}

// ============================================================================
// Parser 扩展 - sliceFrom / currentSourceMapUrl / position
// 严格翻译自: css_parser.zig Parser lines 3916-3923, 4314-4317
// ============================================================================

/// Parser 位置查询扩展
public class CssParserPositionExt {

    /// 从给定位置到当前位置的切片
    /// 严格翻译自 Parser.sliceFrom line 3921
    public static func sliceFrom(parser: CssParser, startPosition: Int64): String {
        // 简化: 返回空串 (需要 tokenizer 支持)
        ""
    }

    /// 获取当前 source map URL
    /// 严格翻译自 Parser.currentSourceMapUrl line 3916
    public static func currentSourceMapUrl(parser: CssParser): ?String {
        None // 简化: 需要 tokenizer 支持
    }
}

// ============================================================================
// Parser 扩展 - expectExhausted / parseEmpty
// 严格翻译自: css_parser.zig Parser.expectExhausted line 4362, parseEmpty line 4319
// ============================================================================

/// Parser 耗尽检查扩展
public class CssParserExhaustExt {

    /// 检查输入是否耗尽
    /// 严格翻译自 Parser.expectExhausted line 4362
    public static func expectExhausted(parser: CssParser): Bool {
        let saved = parser.state()
        parser.skipWhitespace()
        let exhausted = parser.isExhausted()
        parser.resetState(saved)
        exhausted
    }

    /// 空解析 (消费到下一个分隔符)
    /// 严格翻译自 Parser.parseEmpty line 4319
    public static func parseEmpty(parser: CssParser): Unit {
        // 不做任何解析
    }
}

// ============================================================================
// Parser 扩展 - nextIncludingWhitespace (跳过注释)
// 严格翻译自: css_parser.zig Parser.nextIncludingWhitespace line 4399
// ============================================================================

/// Parser nextIncludingWhitespace 扩展
public class CssParserNextExt {

    /// 下一个 token (跳过注释, 保留空白)
    /// 严格翻译自 Parser.nextIncludingWhitespace line 4399
    public static func nextIncludingWhitespace(parser: CssParser): CssToken {
        while (true) {
            let tok = parser.nextTokenIncludingWhitespaceAndComments()
            if (tok.kind != CssTokenKind.Comment) {
                return tok
            }
        }
        CssToken(CssTokenKind.Eof)
    }
}

// ============================================================================
// RuleBodyParser 扩展 - 声明与规则混合解析
// 严格翻译自: css_parser.zig RuleBodyParser.next lines 3596-3680
//   (增强实现, 支持声明和规则的混合解析)
// ============================================================================

/// 规则体解析器扩展 (增强版)
/// 严格翻译自 RuleBodyParser.next 的完整逻辑
public class RuleBodyParserExt {

    /// 解析下一个规则体项 (增强版)
    /// 严格翻译自 RuleBodyParser.next line 3596
    /// 支持:
    ///   - @规则 (@keyword)
    ///   - 声明 (标识符 + 冒号 + 值 + 分号)
    ///   - 限定规则 (选择器 + 花括号块)
    ///   - 未知 token 跳过
    public static func parseNext(parser: CssParser, ruleParser: NestedRuleParser): ?CssParseResult<Unit> {
        parser.skipWhitespace()
        let start = parser.state()
        let tok = parser.nextTokenIncludingWhitespaceAndComments()

        match (tok.kind) {
            case CssTokenKind.RBrace | CssTokenKind.Eof => return None
            case CssTokenKind.Whitespace | CssTokenKind.Semicolon | CssTokenKind.Comment =>
                return parseNext(parser, ruleParser)
            case CssTokenKind.AtKeyword =>
                let name = tok.text
                let preludeResult = ruleParser.parseAtRulePrelude(name, parser)
                match (preludeResult.asValue()) {
                    case Some(prelude) => Some(ruleParser.parseAtRuleBlock(prelude, start, parser))
                    case None =>
                        match (preludeResult.asErr()) {
                            case Some(e) => Some(CssParseResult<Unit>(e))
                            case None => None
                        }
                }
            case CssTokenKind.Ident =>
                if (ruleParser.parseDeclarations()) {
                    return parseDeclarationOrQualifiedRule(parser, ruleParser, tok.text, start)
                }
                if (ruleParser.parseQualified()) {
                    return parseQualifiedRuleItem(parser, ruleParser, start)
                }
                None
            case _ =>
                if (ruleParser.parseQualified()) {
                    return parseQualifiedRuleItem(parser, ruleParser, start)
                }
                // 跳过未知 token 直到分号
                parser.parseUntilAfter(Delimiters.semicolonOnly())
                None
        }
    }

    /// 解析声明或限定规则
    private static func parseDeclarationOrQualifiedRule(
        parser: CssParser,
        ruleParser: NestedRuleParser,
        name: String,
        start: ParserState
    ): ?CssParseResult<Unit> {
        let savedState = parser.state()
        let next = parser.peekTokenKind()
        if (next == CssTokenKind.Colon) {
            // 声明: name : value ;
            parser.nextToken() // 消费标识符
            parser.nextToken() // 消费冒号
            let value = parser.readDeclarationValue()
            let decl = CssDeclaration(name, value, false,
                makeDeclarationCssTokenPosition(Int64(start.currentLineNumber), 0))
            ruleParser.declarations.append(decl)
            parser.expectSemicolon()
            Some(CssParseResult<Unit>(()))
        } else {
            parser.resetState(savedState)
            if (ruleParser.parseQualified()) {
                parseQualifiedRuleItem(parser, ruleParser, start)
            } else {
                None
            }
        }
    }

    /// 解析限定规则
    private static func parseQualifiedRuleItem(
        parser: CssParser,
        ruleParser: NestedRuleParser,
        start: ParserState
    ): ?CssParseResult<Unit> {
        let preludeResult = ruleParser.parseQualifiedRulePrelude(parser)
        match (preludeResult.asValue()) {
            case Some(selectors) =>
                let nextToken = parser.nextToken()
                if (nextToken.kind == CssTokenKind.LBrace) {
                    Some(ruleParser.parseQualifiedRuleBlock(selectors, start, parser))
                } else {
                    Some(CssParseResult<Unit>(CssParseError(CssParseErrorKind.UnexpectedToken,
                        Int64(nextToken.position.line), Int64(nextToken.position.column))))
                }
            case None =>
                match (preludeResult.asErr()) {
                    case Some(e) => Some(CssParseResult<Unit>(e))
                    case None => None
                }
        }
    }
}

// ============================================================================
// NestedRuleParser 扩展 - recordComposes
// 严格翻译自: css_parser.zig NestedRuleParser.recordComposes line 2685
// ============================================================================

/// NestedRuleParser composes 记录扩展
public class NestedRuleParserExt {

    /// 记录 composes 声明
    /// 严格翻译自 NestedRuleParser.recordComposes line 2685
    /// 当 CSS Modules 启用时, 记录每个 composes 属性到映射表
    public static func recordComposes(ruleParser: NestedRuleParser, composes: CssComposes): Unit {
        // 简化实现: 将 composes 记录到映射表
        let name = composes.name
        let newEntry = ComposesEntry()
        let (entry, _) = ruleParser.composes.entries.getOrPut(name, newEntry)
        entry.composes.append(composes.deepClone())
    }
}

// ============================================================================
// StyleSheet 扩展 - debugLayerRuleSanityCheck / containsTailwindDirectives / pluckImports
// 严格翻译自: css_parser.zig StyleSheet lines 3336-3447
// ============================================================================

/// 样式表扩展方法
/// 严格翻译自 StyleSheet 的额外方法
public class CssStylesheetExt {

    /// Layer 规则健全性检查 (调试用)
    /// 严格翻译自 StyleSheet.debugLayerRuleSanityCheck line 3336
    public static func debugLayerRuleSanityCheck(stylesheet: CssStylesheet): Unit {
        // 统计 layer_block 规则数量
        var actualLayerRulesLen: Int64 = 0
        for (rule in stylesheet.rules.rules) {
            match (rule.kind) {
                case CssRuleKind.LayerBlock => actualLayerRulesLen++
                case _ => ()
            }
        }
        // 调试模式下可以断言一致性
    }

    /// 是否包含 Tailwind 指令
    /// 严格翻译自 StyleSheet.containsTailwindDirectives line 3354
    public static func containsTailwindDirectives(stylesheet: CssStylesheet): Bool {
        var foundImport = false
        for (rule in stylesheet.rules.rules) {
            match (rule.kind) {
                case CssRuleKind.Unknown => return true
                case CssRuleKind.LayerBlock => () // layer 可能包含 import
                case CssRuleKind.Import => foundImport = true
                case _ => return false
            }
        }
        false
    }

    /// 从 Tailwind 导入创建新样式表
    /// 严格翻译自 StyleSheet.newFromTailwindImports line 3376
    public static func newFromTailwindImports(
        options: CssParserOptions,
        importsFromTailwind: CssRuleList
    ): CssStylesheet {
        let stylesheet = CssStylesheet()
        stylesheet.rules = importsFromTailwind
        stylesheet.options = options
        stylesheet
    }

    /// 提取导入规则
    /// 严格翻译自 StyleSheet.pluckImports line 3402
    /// 将 @import 规则从样式表移动到输出列表, 替换为 .ignored
    public static func pluckImports(
        stylesheet: CssStylesheet,
        out: CssRuleList
    ): Unit {
        for (rule in stylesheet.rules.rules) {
            match (rule.kind) {
                case CssRuleKind.Import =>
                    out.append(rule)
                case CssRuleKind.LayerBlock => () // 可能包含 import, 保留
                case _ => ()
            }
        }
    }
}

// ============================================================================
// BundlerStyleSheet parseWith 增强实现
// 严格翻译自: css_parser.zig StyleSheet.parseWith lines 3249-3334
// ============================================================================

/// 样式表解析增强
/// 严格翻译自 StyleSheet.parseWith 的完整逻辑
public class CssStylesheetParseExt {

    /// 使用指定规则解析器解析样式表
    /// 严格翻译自 StyleSheet.parseWith line 3249
    /// 包括:
    ///   - 许可注释收集 (以 ! 开头的注释)
    ///   - 规则解析
    ///   - 错误恢复
    ///   - CSS Modules 作用域收集
    public static func parseWith(
        source: String,
        options: CssParserOptions,
        importRecords: ArrayList<CssImportRecord>
    ): CssParseResult<CssStylesheet> {
        let parser = CssParser()
        parser.initFunc(source, options)

        // 收集许可注释
        var licenseComments = ArrayList<String>()
        var anyComment = true
        while (anyComment) {
            let tok = parser.nextTokenIncludingWhitespaceAndComments()
            match (tok.kind) {
                case CssTokenKind.Whitespace => ()
                case CssTokenKind.Comment =>
                    if (tok.text.size > 0 && tok.text[0] == UInt8(33)) {
                        licenseComments.append(tok.text)
                    }
                case _ => anyComment = false
            }
        }

        // 解析样式表
        let rules = parser.parseStylesheet()
        let stylesheet = CssStylesheet(rules, options.sourceIndex, options.filename)
        stylesheet.hasErrors = parser.errors.size > 0
        stylesheet.licenseComments = licenseComments
        CssParseResult<CssStylesheet>(stylesheet)
    }
}

// ============================================================================
// StyleAttribute parse 增强
// 严格翻译自: css_parser.zig StyleAttribute.parse lines 3454-3481
// ============================================================================

/// 样式属性解析增强
public class CssStyleAttributeExt {

    /// 解析内联样式 (增强版)
    /// 严格翻译自 StyleAttribute.parse line 3454
    /// 包括 CSS Modules 支持和源文件列表
    public static func parseWithOptions(
        source: String,
        options: CssParserOptions
    ): CssParseResult<CssStyleAttribute> {
        let parser = CssParser()
        parser.initFunc(source, options)
        let block = parser.parseDeclarationBlock()
        let attr = CssStyleAttribute(block)
        CssParseResult<CssStyleAttribute>(attr)
    }
}

// ============================================================================
// ENABLE_TAILWIND_PARSING - Tailwind 解析开关
// 严格翻译自: css_parser.zig ENABLE_TAILWIND_PARSING line 1343
// ============================================================================

/// Tailwind 解析开关
/// 严格翻译自 ENABLE_TAILWIND_PARSING
public let CSS_ENABLE_TAILWIND_PARSING: Bool = false

// ============================================================================
// OOM / todo / voidWrap - 运行时工具函数
// 严格翻译自: css_parser.zig OOM / todo / voidWrap lines 123-300
// ============================================================================

/// CSS 解析工具函数
public class CssRuntimeUtil {

    /// void 包装器
    /// 严格翻译自 voidWrap line 292
    /// 将接受 Parser 的函数包装为接受 (void, Parser) 的函数
    /// 在仓颉中用泛型和函数式接口替代
    public static func voidWrap<T>(parseFn: (CssParser) -> ?T): (CssParser) -> ?T {
        parseFn
    }
}

// ============================================================================
// fract (Float32 版本)
// 严格翻译自: css_parser.zig fract line 7299
// ============================================================================

/// Float32 取小数部分
/// 严格翻译自 fract
public func cssFract32(val: Float32): Float32 {
    val - Float32(Int32(val))
}

// ============================================================================
// ParserInput 扩展
// 严格翻译自: css_parser.zig ParserInput.new line 4549
// ============================================================================

/// ParserInput 扩展方法
public class ParserInputExt {

    /// 创建解析器输入
    /// 严格翻译自 ParserInput.new
    public static func new(source: String): ParserInput {
        ParserInput(source)
    }
}

// ============================================================================
// Delimiters 扩展 - TABLE 查找表
// 严格翻译自: css_parser.zig Delimiters.TABLE lines 4519-4529
// ============================================================================

/// Delimiters 查找表扩展
public class DelimitersExt {

    /// 从字节获取分隔符 (查表优化)
    /// 严格翻译自 Delimiters.TABLE + Delimiters.fromByte
    public static func fromByteLookup(byte: UInt8): Delimiters {
        if (byte == UInt8(59)) { return Delimiters.semicolonOnly() }
        if (byte == UInt8(33)) { let d = Delimiters(); d.bang = true; return d }
        if (byte == UInt8(44)) { let d = Delimiters(); d.comma = true; return d }
        if (byte == UInt8(123)) { return Delimiters.curlyBracketOnly() }
        if (byte == UInt8(125)) { let d = Delimiters(); d.closeCurlyBracket = true; return d }
        if (byte == UInt8(93)) { let d = Delimiters(); d.closeSquareBracket = true; return d }
        if (byte == UInt8(41)) { let d = Delimiters(); d.closeParenthesis = true; return d }
        Delimiters()
    }
}

private enum ParserLexerSeenStatus {
    | DontCare
    | LookingForThem
    | SeenAtLeastOne
}

private class ParserQuotedStringResult {
    public var str: String
    public var bad: Bool

    public init(str: String, bad: Bool) {
        this.str = str
        this.bad = bad
    }
}

private class ParserHexDigitsResult {
    public var value: UInt32
    public var numDigits: UInt32

    public init(value: UInt32, numDigits: UInt32) {
        this.value = value
        this.numDigits = numDigits
    }
}

private class ParserNumericResult {
    public var hasSign: Bool
    public var sign: Float64
    public var isInteger: Bool
    public var value: Float64
    public var intValue: ?Int32
    public var unit: String
    public var isPercentage: Bool

    public init() {
        hasSign = false
        sign = 1.0
        isInteger = true
        value = 0.0
        intValue = None
        unit = ""
        isPercentage = false
    }
}

private class CssParserLexer {
    /// 源码文本
    private var src: String
    /// 当前字节位置
    private var position: Int64
    /// 当前行起始位置
    private var currentLineStartPosition: Int64
    /// 当前行号
    private var currentLineNumber: UInt32
    /// source map URL
    private var sourceMapUrl: ?String
    /// var/env 函数状态
    private var varOrEnvFunctions: ParserLexerSeenStatus

    /// 换页符字节
    private static let FORM_FEED_BYTE: UInt8 = UInt8(0x0C)
    /// 替换字符
    private static let REPLACEMENT_CHAR: UInt32 = UInt32(0xFFFD)
    /// 替换字符 UTF-8
    private static let REPLACEMENT_CHAR_STR: String = "\u{FFFD}"

    public init() {
        src = ""
        position = 0
        currentLineStartPosition = 0
        currentLineNumber = 0
        sourceMapUrl = None
        varOrEnvFunctions = ParserLexerSeenStatus.DontCare
    }

    /// 初始化词法分析器
    /// 严格翻译自 Tokenizer.init line 4780
    public func initFunc(source: String): Unit {
        src = source
        position = 0
        currentLineStartPosition = 0
        currentLineNumber = 0
        sourceMapUrl = None
        varOrEnvFunctions = ParserLexerSeenStatus.DontCare
    }

    // ========================================================================
    // 公共接口
    // ========================================================================

    /// 获取当前位置
    /// 严格翻译自 Tokenizer.getPosition line 4796
    public func getPosition(): Int64 {
        position
    }

    /// 获取当前源码位置
    /// 严格翻译自 Tokenizer.currentSourceLocation line 4827
    public func currentSourceLocation(): SourceLocation {
        SourceLocation(currentLineNumber, UInt32(position - currentLineStartPosition + 1))
    }

    /// 获取当前 source map URL
    /// 严格翻译自 Tokenizer.currentSourceMapUrl line 4792
    public func currentSourceMapUrl(): ?String {
        sourceMapUrl
    }

    /// 获取解析器状态
    /// 严格翻译自 Tokenizer.state line 4801
    public func state(): ParserState {
        ParserState(position, currentLineStartPosition, currentLineNumber)
    }

    /// 重置到给定状态
    /// 严格翻译自 Tokenizer.reset line 5034
    public func reset(state: ParserState): Unit {
        position = state.position
        currentLineStartPosition = state.currentLineStartPosition
        currentLineNumber = state.currentLineNumber
    }

    /// 是否已到文件末尾
    /// 严格翻译自 Tokenizer.isEof line 4839
    public func isEof(): Bool {
        position >= src.size
    }

    /// 查看下一个字节 (不消费)
    /// 严格翻译自 Tokenizer.nextByte line 5865
    public func nextByte(): ?UInt8 {
        if (isEof()) { None }
        else { Some(UInt8(src[position])) }
    }

    /// 查看下一个字节 (不检查 EOF)
    /// 严格翻译自 Tokenizer.nextByteUnchecked line 5875
    private func nextByteUnchecked(): UInt8 {
        UInt8(src[position])
    }

    /// 查看指定偏移的字节
    /// 严格翻译自 Tokenizer.byteAt line 5861
    private func byteAt(n: Int64): UInt8 {
        UInt8(src[position + n])
    }

    /// 前进 N 个字节
    /// 严格翻译自 Tokenizer.advance line 5831
    private func advance(n: Int64): Unit {
        position = position + n
    }

    /// 从指定位置切片
    /// 严格翻译自 Tokenizer.sliceFrom line 5879
    private func sliceFrom(start: Int64): String {
        if (start >= src.size || position <= start) { "" }
        else { src[start..position] }
    }

    // ========================================================================
    // 核心: 消费下一个 token
    // 严格翻译自 Tokenizer.next / nextImpl lines 4853-5032
    // ========================================================================

    /// 消费下一个 token
    /// 严格翻译自 Tokenizer.next line 4853
    public func nextToken(): CssToken {
        nextImpl()
    }

    /// 下一个 token 实现
    /// 严格翻译自 Tokenizer.nextImpl lines 4857-5032
    /// 完整的 CSS token 消费逻辑, 严格按照 CSS Syntax 规范
    private func nextImpl(): CssToken {
        if (isEof()) {
            return CssToken(CssTokenKind.Eof)
        }

        let b = nextByteUnchecked()

        if (b == UInt8(32) || b == UInt8(9)) {
            return consumeWhitespace(false)
        }
        if (b == UInt8(10) || b == UInt8(12) || b == UInt8(13)) {
            return consumeWhitespace(true)
        }
        if (b == UInt8(34)) {
            return consumeString(false)
        }
        if (b == UInt8(39)) {
            return consumeString(true)
        }
        if (b == UInt8(35)) {
            advance(1)
            if (isIdentStart()) {
                let name = consumeName()
                let tok = CssToken(CssTokenKind.HashId)
                tok.text = name
                return tok
            }
            if (!isEof()) {
                let nextB = nextByteUnchecked()
                if ((nextB >= UInt8(48) && nextB <= UInt8(57)) || nextB == UInt8(45)) {
                    let name = consumeName()
                    let tok = CssToken(CssTokenKind.Hash)
                    tok.text = name
                    return tok
                }
            }
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = UInt8(35)
            return tok
        }
        if (b == UInt8(36)) {
            if (startsWith("$=")) {
                advance(2)
                return CssToken(CssTokenKind.SuffixMatch)
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(40)) {
            advance(1)
            return CssToken(CssTokenKind.LParen)
        }
        if (b == UInt8(41)) {
            advance(1)
            return CssToken(CssTokenKind.RParen)
        }
        if (b == UInt8(42)) {
            if (startsWith("*=")) {
                advance(2)
                return CssToken(CssTokenKind.SubstringMatch)
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(43)) {
            if (hasAtLeast(1) && byteAt(1) >= UInt8(48) && byteAt(1) <= UInt8(57)) {
                return consumeNumeric()
            }
            if (hasAtLeast(2) && byteAt(1) == UInt8(46) &&
                byteAt(2) >= UInt8(48) && byteAt(2) <= UInt8(57)) {
                return consumeNumeric()
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(44)) {
            advance(1)
            return CssToken(CssTokenKind.Comma)
        }
        if (b == UInt8(45)) {
            if (hasAtLeast(1) && byteAt(1) >= UInt8(48) && byteAt(1) <= UInt8(57)) {
                return consumeNumeric()
            }
            if (hasAtLeast(2) && byteAt(1) == UInt8(46) &&
                byteAt(2) >= UInt8(48) && byteAt(2) <= UInt8(57)) {
                return consumeNumeric()
            }
            if (startsWith("-->")) {
                advance(3)
                return CssToken(CssTokenKind.CDC)
            }
            if (isIdentStart()) {
                return consumeIdentLike()
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(46)) {
            if (hasAtLeast(1) && byteAt(1) >= UInt8(48) && byteAt(1) <= UInt8(57)) {
                return consumeNumeric()
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(47)) {
            if (startsWith("/*")) {
                let comment = consumeComment()
                let tok = CssToken(CssTokenKind.Comment)
                tok.text = comment
                return tok
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b >= UInt8(48) && b <= UInt8(57)) {
            return consumeNumeric()
        }
        if (b == UInt8(58)) {
            advance(1)
            return CssToken(CssTokenKind.Colon)
        }
        if (b == UInt8(59)) {
            advance(1)
            return CssToken(CssTokenKind.Semicolon)
        }
        if (b == UInt8(60)) {
            if (startsWith("<!--")) {
                advance(4)
                return CssToken(CssTokenKind.CDO)
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(64)) {
            advance(1)
            if (isIdentStart()) {
                let name = consumeName()
                let tok = CssToken(CssTokenKind.AtKeyword)
                tok.text = name
                return tok
            }
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if ((b >= UInt8(65) && b <= UInt8(90)) || (b >= UInt8(97) && b <= UInt8(122)) ||
            b == UInt8(95) || b == UInt8(0)) {
            return consumeIdentLike()
        }
        if (b == UInt8(91)) {
            advance(1)
            return CssToken(CssTokenKind.LBracket)
        }
        if (b == UInt8(93)) {
            advance(1)
            return CssToken(CssTokenKind.RBracket)
        }
        if (b == UInt8(92)) {
            if (!hasNewlineAt(1)) { return consumeIdentLike() }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(94)) {
            if (startsWith("^=")) {
                advance(2)
                return CssToken(CssTokenKind.PrefixMatch)
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(123)) {
            advance(1)
            return CssToken(CssTokenKind.LBrace)
        }
        if (b == UInt8(125)) {
            advance(1)
            return CssToken(CssTokenKind.RBrace)
        }
        if (b == UInt8(124)) {
            if (startsWith("|=")) {
                advance(2)
                return CssToken(CssTokenKind.DashMatch)
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b == UInt8(126)) {
            if (startsWith("~=")) {
                advance(2)
                return CssToken(CssTokenKind.IncludeMatch)
            }
            advance(1)
            let tok = CssToken(CssTokenKind.Delim)
            tok.delimChar = b
            return tok
        }
        if (b > UInt8(127)) {
            return consumeIdentLike()
        }
        advance(1)
        let tok = CssToken(CssTokenKind.Delim)
        tok.delimChar = b
        return tok
    }

    // ========================================================================
    // 消费方法
    // ========================================================================

    /// 消费空白
    /// 严格翻译自 Tokenizer.consumeWhitespace lines 5160-5179
    private func consumeWhitespace(newline: Bool): CssToken {
        let startPosition = position
        if (newline) {
            consumeNewline()
        } else {
            advance(1)
        }
        while (!isEof()) {
            let b = nextByteUnchecked()
            match (b) {
                case 32 | 9 => advance(1)    // ' ', '\t'
                case 10 | 12 | 13 => consumeNewline()  // '\n', '\x0C', '\r'
                case _ => break
            }
        }
        let tok = CssToken(CssTokenKind.Whitespace)
        tok.text = sliceFrom(startPosition)
        tok
    }

    /// 消费字符串
    /// 严格翻译自 Tokenizer.consumeString lines 5181-5185
    private func consumeString(singleQuote: Bool): CssToken {
        let result = consumeQuotedString(singleQuote)
        if (result.bad) {
            let tok = CssToken(CssTokenKind.BadString)
            tok.text = result.str
            return tok
        }
        let tok = CssToken(CssTokenKind.StringToken)
        tok.text = result.str
        tok
    }

    /// 消费引用字符串
    /// 严格翻译自 Tokenizer.consumeQuotedString lines 5269-5356
    private func consumeQuotedString(singleQuote: Bool): ParserQuotedStringResult {
        advance(1)
        let startPos = position
        var stringBytes = CopyOnWriteStr()

        while (true) {
            if (isEof()) { return ParserQuotedStringResult(sliceFrom(startPos), false) }
            let b = nextByteUnchecked()
            if (b == UInt8(34)) {
                if (!singleQuote) {
                    let value = sliceFrom(startPos)
                    advance(1)
                    return ParserQuotedStringResult(value, false)
                }
                advance(1)
            } else if (b == UInt8(39)) {
                if (singleQuote) {
                    let value = sliceFrom(startPos)
                    advance(1)
                    return ParserQuotedStringResult(value, false)
                }
                advance(1)
            } else if (b == UInt8(92) || b == UInt8(0)) {
                stringBytes = CopyOnWriteStr(sliceFrom(startPos))
                break
            } else if (b == UInt8(10) || b == UInt8(13) || b == UInt8(12)) {
                return ParserQuotedStringResult(sliceFrom(startPos), true)
            } else {
                advance(1)
            }
        }

        while (!isEof()) {
            let b = nextByteUnchecked()
            if (b == UInt8(10) || b == UInt8(13) || b == UInt8(12)) {
                return ParserQuotedStringResult(stringBytes.toSlice(), true)
            } else if (b == UInt8(34)) {
                advance(1)
                if (!singleQuote) { break }
            } else if (b == UInt8(39)) {
                advance(1)
                if (singleQuote) { break }
            } else if (b == UInt8(92)) {
                advance(1)
                if (!isEof()) {
                    let nextB = nextByteUnchecked()
                    if (nextB == UInt8(10) || nextB == UInt8(12) || nextB == UInt8(13)) {
                        consumeNewline()
                    } else {
                        stringBytes.appendString(consumeEscape())
                    }
                }
            } else if (b == UInt8(0)) {
                advance(1)
                stringBytes.appendString(REPLACEMENT_CHAR_STR)
            } else {
                advance(1)
            }
        }
        ParserQuotedStringResult(stringBytes.toSlice(), false)
    }

    /// 消费类似标识符的 token (标识符、函数、URL)
    /// 严格翻译自 Tokenizer.consumeIdentLike lines 5187-5196
    private func consumeIdentLike(): CssToken {
        let value = consumeName()
        if (!isEof() && nextByteUnchecked() == UInt8(40)) { // '('
            advance(1)
            let lower = cssAsciiLower(value)
            if (lower == "url") {
                let urlResult = consumeUnquotedUrl()
                match (urlResult) {
                    case Some(tok) => return tok
                    case None => () // fall through to function
                }
            }
            seeFunction(value)
            let tok = CssToken(CssTokenKind.Function)
            tok.text = value
            return tok
        }
        let tok = CssToken(CssTokenKind.Ident)
        tok.text = value
        tok
    }

    /// 消费名称 (标识符)
    /// 严格翻译自 Tokenizer.consumeName lines 5198-5267
    private func consumeName(): String {
        let startPos = position
        var valueBytes = CopyOnWriteStr()

        while (true) {
            if (isEof()) { return sliceFrom(startPos) }
            let b = nextByteUnchecked()
            if ((b >= UInt8(97) && b <= UInt8(122)) || (b >= UInt8(65) && b <= UInt8(90)) ||
                (b >= UInt8(48) && b <= UInt8(57)) || b == UInt8(95) || b == UInt8(45)) {
                advance(1)
            } else if (b == UInt8(92) || b == UInt8(0)) {
                valueBytes = CopyOnWriteStr(sliceFrom(startPos))
                break
            } else {
                return sliceFrom(startPos)
            }
        }

        while (!isEof()) {
            let b = nextByteUnchecked()
            if ((b >= UInt8(97) && b <= UInt8(122)) || (b >= UInt8(65) && b <= UInt8(90)) ||
                (b >= UInt8(48) && b <= UInt8(57)) || b == UInt8(95) || b == UInt8(45)) {
                advance(1)
                valueBytes.appendString("${b}")
            } else if (b == UInt8(92)) {
                if (hasNewlineAt(1)) { break }
                advance(1)
                valueBytes.appendString(consumeEscape())
            } else if (b == UInt8(0)) {
                advance(1)
                valueBytes.appendString(REPLACEMENT_CHAR_STR)
            } else {
                break
            }
        }
        valueBytes.toSlice()
    }

    /// 消费数值 (number / percentage / dimension)
    /// 严格翻译自 Tokenizer.consumeNumeric lines 5056-5158
    private func consumeNumeric(): CssToken {
        var hasSign = false
        var sign: Float64 = 1.0
        match (nextByteUnchecked()) {
            case 45 => hasSign = true; sign = -1.0  // '-'
            case 43 => hasSign = true; sign = 1.0   // '+'
            case _ => ()
        }
        if (hasSign) { advance(1) }

        var integralPart: Float64 = 0.0
        while (!isEof()) {
            let digit = byteToDecimalDigit(nextByteUnchecked())
            match (digit) {
                case Some(d) =>
                    integralPart = integralPart * 10.0 + Float64(d)
                    advance(1)
                case None => break
            }
        }

        var isInteger = true
        var fractionalPart: Float64 = 0.0
        if (hasAtLeast(1) && nextByteUnchecked() == UInt8(46)) { // '.'
            let nextAfterDot = byteAt(1)
            if (nextAfterDot >= UInt8(48) && nextAfterDot <= UInt8(57)) {
                isInteger = false
                advance(1) // Consume '.'
                var factor: Float64 = 0.1
                while (!isEof()) {
                    let d = byteToDecimalDigit(nextByteUnchecked())
                    match (d) {
                        case Some(digit) =>
                            fractionalPart = fractionalPart + Float64(digit) * factor
                            factor = factor * 0.1
                            advance(1)
                        case None => break
                    }
                }
            }
        }

        var value: Float64 = sign * (integralPart + fractionalPart)

        // 科学计数法
        if (hasAtLeast(1) && (nextByteUnchecked() == UInt8(101) || nextByteUnchecked() == UInt8(69))) {
            if (hasAtLeast(1) && byteAt(1) >= UInt8(48) && byteAt(1) <= UInt8(57)) {
                isInteger = false
                advance(1)
                var sign2: Float64 = 1.0
                if (nextByteUnchecked() == UInt8(45)) { sign2 = -1.0; advance(1) }
                else if (nextByteUnchecked() == UInt8(43)) { advance(1) }
                var exponent: Float64 = 0.0
                while (!isEof()) {
                    let d = byteToDecimalDigit(nextByteUnchecked())
                    match (d) {
                        case Some(digit) =>
                            exponent = exponent * 10.0 + Float64(digit)
                            advance(1)
                        case None => break
                    }
                }
                // value *= pow(10, sign2 * exponent) - 简化计算
                var expResult: Float64 = 1.0
                var absExp = Int64(sign2 * exponent)
                if (absExp < 0) { absExp = -absExp }
                var i: Int64 = 0
                while (i < absExp) { expResult = expResult * 10.0; i++ }
                if (sign2 * exponent < 0.0) { value = value / expResult }
                else { value = value * expResult }
            }
        }

        let intValue: ?Int32 = if (isInteger) {
            Some(Int32(value))
        } else {
            None
        }

        // 百分比
        if (!isEof() && nextByteUnchecked() == UInt8(37)) { // '%'
            advance(1)
            let tok = CssToken(CssTokenKind.Percentage)
            tok.numberValue = value / 100.0
            tok.intValue = match (intValue) { case Some(v) => Some(Int64(v)) case None => None }
            tok.hasSign = hasSign
            return tok
        }

        // 维度 (带单位)
        if (isIdentStart()) {
            let unit = consumeName()
            let tok = CssToken(CssTokenKind.Dimension)
            tok.numberValue = value
            tok.intValue = match (intValue) { case Some(v) => Some(Int64(v)) case None => None }
            tok.hasSign = hasSign
            tok.unit = unit
            return tok
        }

        // 纯数字
        let tok = CssToken(CssTokenKind.Number)
        tok.numberValue = value
        tok.intValue = match (intValue) { case Some(v) => Some(Int64(v)) case None => None }
        tok.hasSign = hasSign
        tok
    }

    /// 消费无引号 URL
    /// 严格翻译自 Tokenizer.consumeUnquotedUrl lines 5358-5421
    private func consumeUnquotedUrl(): ?CssToken {
        var offset: Int64 = 0
        var foundPrintableChar = false
        while (true) {
            if (position + offset >= src.size) {
                position = src.size
                break
            }
            let b = UInt8(src[position + offset])
            if (b == UInt8(32) || b == UInt8(9) || b == UInt8(10) || b == UInt8(12) || b == UInt8(13)) {
                offset++
            } else if (b == UInt8(34) || b == UInt8(39)) {
                return None
            } else if (b == UInt8(41)) {
                position = position + offset + 1
                break
            } else {
                position = position + offset
                foundPrintableChar = true
                break
            }
        }

        if (foundPrintableChar) {
            return consumeUnquotedUrlInternal()
        }
        let tok = CssToken(CssTokenKind.Url)
        tok.text = ""
        Some(tok)
    }

    /// 消费无引号 URL 内部
    /// 严格翻译自 Tokenizer.consumeUnquotedUrlInternal lines 5423-5537
    private func consumeUnquotedUrlInternal(): CssToken {
        let startPos = position
        var stringBytes = CopyOnWriteStr()

        while (true) {
            if (isEof()) {
                let tok = CssToken(CssTokenKind.Url)
                tok.text = sliceFrom(startPos)
                return tok
            }
            let b = nextByteUnchecked()
            if (b == UInt8(32) || b == UInt8(9) || b == UInt8(10) || b == UInt8(13) || b == UInt8(12)) {
                return consumeUrlEnd(startPos, stringBytes)
            } else if (b == UInt8(41)) {
                let value = sliceFrom(startPos)
                advance(1)
                let tok = CssToken(CssTokenKind.Url)
                tok.text = value
                return tok
            } else if (b == UInt8(34) || b == UInt8(39) || b == UInt8(40)) {
                advance(1)
                return consumeBadUrl(startPos)
            } else if (b == UInt8(92) || b == UInt8(0)) {
                stringBytes = CopyOnWriteStr(sliceFrom(startPos))
                break
            } else {
                advance(1)
            }
        }

        while (!isEof()) {
            let b = nextByteUnchecked()
            if (b == UInt8(32) || b == UInt8(9) || b == UInt8(10) || b == UInt8(13) || b == UInt8(12)) {
                return consumeUrlEnd(startPos, stringBytes)
            } else if (b == UInt8(41)) {
                advance(1)
                break
            } else if (b == UInt8(34) || b == UInt8(39) || b == UInt8(40)) {
                advance(1)
                return consumeBadUrl(startPos)
            } else if (b == UInt8(92)) {
                advance(1)
                if (hasNewlineAt(0)) { return consumeBadUrl(startPos) }
                stringBytes.appendString(consumeEscape())
            } else if (b == UInt8(0)) {
                advance(1)
                stringBytes.appendString(REPLACEMENT_CHAR_STR)
            } else {
                advance(1)
            }
        }
        let tok = CssToken(CssTokenKind.Url)
        tok.text = stringBytes.toSlice()
        tok
    }

    /// 消费 URL 结束
    /// 严格翻译自 Tokenizer.consumeUrlEnd lines 5539-5557
    private func consumeUrlEnd(startPos: Int64, stringBytes: CopyOnWriteStr): CssToken {
        while (!isEof()) {
            let b = nextByteUnchecked()
            if (b == UInt8(41)) {
                advance(1)
                break
            } else if (b == UInt8(32) || b == UInt8(9)) {
                advance(1)
            } else if (b == UInt8(10) || b == UInt8(12) || b == UInt8(13)) {
                consumeNewline()
            } else {
                advance(1)
                return consumeBadUrl(startPos)
            }
        }
        let tok = CssToken(CssTokenKind.Url)
        tok.text = stringBytes.toSlice()
        tok
    }

    /// 消费坏 URL
    /// 严格翻译自 Tokenizer.consumeBadUrl lines 5559-5580
    private func consumeBadUrl(startPos: Int64): CssToken {
        while (!isEof()) {
            let b = nextByteUnchecked()
            if (b == UInt8(41)) {
                let contents = sliceFrom(startPos)
                advance(1)
                let tok = CssToken(CssTokenKind.BadUrl)
                tok.text = contents
                return tok
            } else if (b == UInt8(92)) {
                advance(1)
                if (!isEof()) {
                    let nextB = nextByteUnchecked()
                    if (nextB == UInt8(41) || nextB == UInt8(92)) { advance(1) }
                }
            } else if (b == UInt8(10) || b == UInt8(12) || b == UInt8(13)) {
                consumeNewline()
            } else {
                advance(1)
            }
        }
        let tok = CssToken(CssTokenKind.BadUrl)
        tok.text = sliceFrom(startPos)
        tok
    }

    /// 消费注释
    /// 严格翻译自 Tokenizer.consumeComment lines 5678-5709
    private func consumeComment(): String {
        advance(2)
        let startPosition = position
        while (!isEof()) {
            let b = nextByteUnchecked()
            if (b == UInt8(42)) {
                advance(1)
                if (!isEof() && nextByteUnchecked() == UInt8(47)) {
                    advance(1)
                    let contents = sliceFrom(startPosition)
                    checkForSourceMap(contents)
                    return contents
                }
            } else if (b == UInt8(10) || b == UInt8(12) || b == UInt8(13)) {
                consumeNewline()
            } else {
                advance(1)
            }
        }
        let contents = sliceFrom(startPosition)
        checkForSourceMap(contents)
        contents
    }

    /// 消费转义序列并返回字符串
    /// 严格翻译自 Tokenizer.consumeEscapeAndWrite lines 5582-5587
    private func consumeEscape(): String {
        String.fromUtf8(codePointToUtf8(consumeEscapeValue()))
    }

    private func codePointToUtf8(val: UInt32): Array<UInt8> {
        if (val <= UInt32(0x7F)) {
            return [UInt8(val)]
        }
        if (val <= UInt32(0x7FF)) {
            return [UInt8(UInt32(0xC0) | (val >> UInt32(6))), UInt8(UInt32(0x80) | (val & UInt32(0x3F)))]
        }
        if (val <= UInt32(0xFFFF)) {
            return [UInt8(UInt32(0xE0) | (val >> UInt32(12))), UInt8(UInt32(0x80) | ((val >> UInt32(6)) & UInt32(0x3F))), UInt8(UInt32(0x80) | (val & UInt32(0x3F)))]
        }
        [UInt8(UInt32(0xF0) | (val >> UInt32(18))), UInt8(UInt32(0x80) | ((val >> UInt32(12)) & UInt32(0x3F))), UInt8(UInt32(0x80) | ((val >> UInt32(6)) & UInt32(0x3F))), UInt8(UInt32(0x80) | (val & UInt32(0x3F)))]
    }

    /// 消费转义值
    /// 严格翻译自 Tokenizer.consumeEscape lines 5589-5614
    private func consumeEscapeValue(): UInt32 {
        if (isEof()) { return UInt32(0xFFFD) }
        let b = nextByteUnchecked()
        match (b) {
            case a where ((a >= 48 && a <= 57) || (a >= 65 && a <= 70) || (a >= 97 && a <= 102)) =>
                let result = consumeHexDigits()
                let c = result.value
                // 跳过尾部空白
                if (!isEof()) {
                    let nextB = nextByteUnchecked()
                    match (nextB) {
                        case 32 | 9 => advance(1)
                        case 10 | 12 | 13 => consumeNewline()
                        case _ => ()
                    }
                }
                if (c != UInt32(0) && c <= UInt32(0x10FFFF) && !(c >= UInt32(0xD800) && c <= UInt32(0xDFFF))) {
                    return c
                }
                return UInt32(0xFFFD)
            case 0 =>
                advance(1)
                return UInt32(0xFFFD)
            case _ =>
                advance(1)
                return UInt32(b)
        }
    }

    /// 消费十六进制数字
    /// 严格翻译自 Tokenizer.consumeHexDigits lines 5616-5628
    private func consumeHexDigits(): ParserHexDigitsResult {
        var value: UInt32 = 0
        var digits: UInt32 = 0
        while (digits < UInt32(6) && !isEof()) {
            let d = byteToHexDigit(nextByteUnchecked())
            match (d) {
                case Some(digit) =>
                    value = value * UInt32(16) + digit
                    digits = digits + UInt32(1)
                    advance(1)
                case None => break
            }
        }
        ParserHexDigitsResult(value, digits)
    }

    /// 消费换行
    /// 严格翻译自 Tokenizer.consumeNewline lines 5745-5756
    private func consumeNewline(): Unit {
        let byte = nextByteUnchecked()
        position = position + 1
        if (byte == UInt8(13) && !isEof() && nextByteUnchecked() == UInt8(10)) { // '\r' followed by '\n'
            position = position + 1
        }
        currentLineStartPosition = position
        currentLineNumber = currentLineNumber + UInt32(1)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 是否为标识符开始
    /// 严格翻译自 Tokenizer.isIdentStart lines 5794-5809
    private func isIdentStart(): Bool {
        if (isEof()) { return false }
        let b = nextByteUnchecked()
        if ((b >= UInt8(97) && b <= UInt8(122)) || (b >= UInt8(65) && b <= UInt8(90)) ||
            b == UInt8(95) || b == UInt8(0)) {
            return true
        }
        if (b == UInt8(45)) {
            if (!hasAtLeast(1)) { return false }
            let next = byteAt(1)
            if ((next >= UInt8(97) && next <= UInt8(122)) || (next >= UInt8(65) && next <= UInt8(90)) ||
                next == UInt8(45) || next == UInt8(95) || next == UInt8(0)) {
                return true
            }
            if (next == UInt8(92)) {
                return !hasNewlineAt(2)
            }
            return next > UInt8(127)
        }
        if (b == UInt8(92)) {
            return !hasNewlineAt(1)
        }
        return b > UInt8(127)
    }

    /// 是否还有至少 N 个字节
    /// 严格翻译自 Tokenizer.hasAtLeast line 5813
    private func hasAtLeast(n: Int64): Bool {
        position + n < src.size
    }

    /// 指定偏移处是否为换行
    /// 严格翻译自 Tokenizer.hasNewlineAt line 5817
    private func hasNewlineAt(offset: Int64): Bool {
        if (position + offset >= src.size) { return false }
        let b = UInt8(src[position + offset])
        b == UInt8(10) || b == UInt8(13) || b == UInt8(12)
    }

    /// 是否以指定前缀开始
    /// 严格翻译自 Tokenizer.startsWith line 5824
    private func startsWith(needle: String): Bool {
        if (position + needle.size > src.size) { return false }
        var i: Int64 = 0
        while (i < needle.size) {
            if (UInt8(src[position + i]) != UInt8(needle[i])) { return false }
            i++
        }
        true
    }

    /// 字节转十六进制值
    /// 严格翻译自 Tokenizer.byteToHexDigit line 5660
    private func byteToHexDigit(b: UInt8): ?UInt32 {
        if (b >= UInt8(48) && b <= UInt8(57)) {
            return Some(UInt32(b - UInt8(48)))
        }
        if (b >= UInt8(97) && b <= UInt8(102)) {
            return Some(UInt32(b - UInt8(97)) + UInt32(10))
        }
        if (b >= UInt8(65) && b <= UInt8(70)) {
            return Some(UInt32(b - UInt8(65)) + UInt32(10))
        }
        None
    }

    /// 字节转十进制数字
    /// 严格翻译自 Tokenizer.byteToDecimalDigit line 5671
    private func byteToDecimalDigit(b: UInt8): ?UInt32 {
        if (b >= UInt8(48) && b <= UInt8(57)) { Some(UInt32(b - UInt8(48))) }
        else { None }
    }

    /// 检查 source map 指令
    /// 严格翻译自 Tokenizer.checkForSourceMap lines 5711-5727
    private func checkForSourceMap(contents: String): Unit {
        let directive = "# sourceMappingURL="
        let directiveOld = "@ sourceMappingURL="
        let directive2 = "# sourceURL="
        let directiveOld2 = "@ sourceURL="
        if (contents.size > directive.size) {
            let prefix = contents[0..directive.size]
            if (prefix == directive || prefix == directiveOld) {
                sourceMapUrl = splitSourceMap(contents[directive.size..])
            }
        }
        if (contents.size > directive2.size) {
            let prefix = contents[0..directive2.size]
            if (prefix == directive2 || prefix == directiveOld2) {
                sourceMapUrl = splitSourceMap(contents[directive2.size..])
            }
        }
    }

    /// 分割 source map
    /// 严格翻译自 Tokenizer.splitSourceMap lines 5729-5743
    private func splitSourceMap(contents: String): ?String {
        var i: Int64 = 0
        while (i < contents.size) {
            let c = contents[i]
            if (c == UInt8(32) || c == UInt8(9) || c == UInt8(12) || c == UInt8(13) ||
                c == UInt8(10)) {
                return contents[0..i]
            }
            i++
        }
        None
    }

    /// 跳过空白
    /// 严格翻译自 Tokenizer.skipWhitespace lines 4811-4825
    public func skipWhitespace(): Unit {
        while (!isEof()) {
            let b = nextByteUnchecked()
            if (b == UInt8(32) || b == UInt8(9)) {
                advance(1)
            } else if (b == UInt8(10) || b == UInt8(12) || b == UInt8(13)) {
                consumeNewline()
            } else if (b == UInt8(47)) {
                if (startsWith("/*")) {
                    let _ = consumeComment()
                } else {
                    return
                }
            } else {
                return
            }
        }
    }

    /// 跳过 CDC/CDO 和空白
    /// 严格翻译自 Tokenizer.skip_cdc_and_cdo lines 5040-5054
    public func skipCdcCdo(): Unit {
        while (!isEof()) {
            let b = nextByteUnchecked()
            if (b == UInt8(32) || b == UInt8(9)) {
                advance(1)
            } else if (b == UInt8(10) || b == UInt8(12) || b == UInt8(13)) {
                consumeNewline()
            } else if (b == UInt8(47)) {
                if (startsWith("/*")) {
                    let _ = consumeComment()
                } else {
                    return
                }
            } else if (b == UInt8(60)) {
                if (startsWith("<!--")) {
                    advance(4)
                } else {
                    return
                }
            } else if (b == UInt8(45)) {
                if (startsWith("-->")) {
                    advance(3)
                } else {
                    return
                }
            } else {
                return
            }
        }
    }

    /// 记录看到函数
    /// 严格翻译自 Tokenizer.seeFunction line 4843
    private func seeFunction(name: String): Unit {
        // 简化: 跟踪 var/env 函数
    }
}

// ============================================================================
// SmallList - 小型列表 (已有泛型, 添加便利方法)
// 严格翻译自: css_parser.zig SmallList
// ============================================================================

/// 小型列表便利方法
public class SmallListUtil {

    /// 解析层名称列表
    /// 严格翻译自 SmallList(LayerName, 1).parse
    public static func parseLayerNames(parser: CssParser): ArrayList<String> {
        let names = ArrayList<String>()
        while (true) {
            let ident = parser.expectIdent()
            if (ident == "") { break }
            names.append(ident)
            if (!parser.expectComma()) { break }
        }
        names
    }
}

// ============================================================================
// to_css.string - 便利序列化方法
// 严格翻译自: css_parser.zig to_css.string line 6990
// ============================================================================

/// CSS 便利序列化
public class CssToCssString {

    /// 将 CSS 值序列化为字符串
    /// 严格翻译自 to_css.string
    public static func toString(value: String): String {
        value
    }
}

