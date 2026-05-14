// bao_parsers - 通用解析器
// 严格翻译自: src/parsers/
//   json.zig     - JSON 解析器 (JSONLikeParser)
//   json5.rs     - JSON5 解析器
//   json_lexer.rs - JSON 词法分析器
//   toml.zig     - TOML 解析器
//   yaml.zig     - YAML 解析器
package bao_parsers

import bao_core.*
import bao_collections.*

// ============================================================================
// ParseResult - 解析结果
// 严格翻译自: src/parsers/ 中各解析器的返回值
// Bun: Expr 作为统一返回值, 错误通过 logger.Log 传递
// 仓颉使用泛型 Result 类型封装解析结果和错误
// ============================================================================

/// 解析状态
public enum ParseState {
    | Ready          // 初始状态
    | InProgress     // 解析中
    | Success        // 解析成功
    | Error          // 解析错误
    | Eof            // 到达文件末尾
}

/// 解析结果 - 泛型包装
/// 对应 Bun 中 parse() 函数返回 Expr 或 error
public class ParseResult<T> {
    /// 解析结果值
    public var value: ?T
    /// 错误列表 - 对应 Bun logger.Log.msgs
    public var errors: ArrayList<ParseError>
    /// 警告列表
    public var warnings: ArrayList<ParseError>
    /// 解析状态
    public var state: ParseState
    /// 消耗的输入长度
    public var consumedBytes: Int64

    public init() {
        value = None
        errors = ArrayList<ParseError>()
        warnings = ArrayList<ParseError>()
        state = ParseState.Ready
        consumedBytes = Int64(0)
    }

    public init(value: T) {
        this.value = Some(value)
        errors = ArrayList<ParseError>()
        warnings = ArrayList<ParseError>()
        state = ParseState.Success
        consumedBytes = Int64(0)
    }

    /// 是否成功
    public func isSuccess(): Bool {
        state == ParseState.Success && errors.size == Int64(0)
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        errors.size > Int64(0)
    }

    /// 获取值 (如果成功)
    public func getValue(): ?T {
        value
    }

    /// 添加错误
    public func addError(error: ParseError): Unit {
        errors.append(error)
        state = ParseState.Error
    }

    /// 添加警告
    public func addWarning(warning: ParseError): Unit {
        warnings.append(warning)
    }

    /// 合并另一个结果
    public func merge(other: ParseResult<T>): Unit {
        for (err in other.errors) {
            errors.append(err)
        }
        for (warn in other.warnings) {
            warnings.append(warn)
        }
        if (other.hasErrors()) {
            state = ParseState.Error
        }
    }
}

// ============================================================================
// ParseError - 解析错误
// 严格翻译自: src/logger/logger.zig (Log.Msg) + src/parsers/ 中的错误类型
// Bun 使用 error{} 枚举 + logger.Log 双通道报告错误
// 仓颉使用 ParseError 类封装
// ============================================================================

/// 解析错误类型
public enum ParseErrorKind {
    | UnexpectedToken      // 不期望的 token
    | UnexpectedEof        // 意外的文件结束
    | UnexpectedCharacter  // 不期望的字符
    | InvalidSyntax        // 无效语法
    | InvalidNumber        // 无效数字
    | InvalidString        // 无效字符串
    | InvalidEscape        // 无效转义序列
    | UnterminatedString   // 未终止的字符串
    | UnterminatedComment  // 未终止的注释
    | UnterminatedObject   // 未终止的对象
    | UnterminatedArray    // 未终止的数组
    | DuplicateKey         // 重复的键
    | ExpectedColon        // 缺少冒号
    | ExpectedComma        // 缺少逗号
    | ExpectedClosingBrace // 缺少右大括号
    | ExpectedClosingBracket // 缺少右中括号
    | TrailingData         // 尾部多余数据
    | LeadingZeros         // 数字前导零
    | StackOverflow        // 嵌套太深
    | OutOfMemory          // 内存不足
    | Custom               // 自定义错误

    /// 获取错误描述
    public func description(): String {
        match (this) {
            case UnexpectedToken => "Unexpected token"
            case UnexpectedEof => "Unexpected end of file"
            case UnexpectedCharacter => "Unexpected character"
            case InvalidSyntax => "Invalid syntax"
            case InvalidNumber => "Invalid number"
            case InvalidString => "Invalid string"
            case InvalidEscape => "Invalid escape sequence"
            case UnterminatedString => "Unterminated string"
            case UnterminatedComment => "Unterminated comment"
            case UnterminatedObject => "Unterminated object"
            case UnterminatedArray => "Unterminated array"
            case DuplicateKey => "Duplicate key"
            case ExpectedColon => "Expected ':'"
            case ExpectedComma => "Expected ','"
            case ExpectedClosingBrace => "Expected '}'"
            case ExpectedClosingBracket => "Expected ']'"
            case TrailingData => "Trailing data after end"
            case LeadingZeros => "Leading zeros in number"
            case StackOverflow => "Stack overflow (too deeply nested)"
            case OutOfMemory => "Out of memory"
            case Custom => "Custom error"
        }
    }
}

/// 解析错误 - 对应 Bun logger.Msg + 解析器特定错误
public class ParseError {
    /// 错误类型
    public var kind: ParseErrorKind
    /// 错误消息
    public var message: String
    /// 位置 (字节偏移)
    public var offset: Int64
    /// 行号 (1-based)
    public var line: Int64
    /// 列号 (1-based)
    public var column: Int64
    /// 是否为警告
    public var isWarning: Bool

    public init(kind: ParseErrorKind, message: String) {
        this.kind = kind
        this.message = message
        this.offset = Int64(-1)
        this.line = Int64(-1)
        this.column = Int64(-1)
        this.isWarning = false
    }

    public init(kind: ParseErrorKind, message: String, offset: Int64, line: Int64, column: Int64) {
        this.kind = kind
        this.message = message
        this.offset = offset
        this.line = line
        this.column = column
        this.isWarning = false
    }

    /// 格式化错误消息
    public func format(): String {
        if (line >= Int64(0) && column >= Int64(0)) {
            return "${kind.description()}: ${message} at line ${line}, column ${column}"
        }
        return "${kind.description()}: ${message}"
    }

    /// 格式化为带位置的消息
    public func formatWithSource(sourceText: String): String {
        var result = format()
        if (line >= Int64(0)) {
            let lineText = getLine(sourceText, line)
            if (lineText.size > Int64(0)) {
                result += "\n  ${lineText}"
                if (column >= Int64(0)) {
                    var pointer = "  "
                    var i = Int64(0)
                    while (i < column - Int64(1)) {
                        pointer += " "
                        i += Int64(1)
                    }
                    pointer += "^"
                    result += "\n${pointer}"
                }
            }
        }
        return result
    }

    /// 获取源文本中的行
    private func getLine(source: String, lineNum: Int64): String {
        var currentLine = Int64(1)
        var lineStart = Int64(0)
        for (i in Int64(0)..source.size) {
            if (currentLine == lineNum) {
                let end = findLineEnd(source, i)
                return source[i..end]
            }
            if (source[i] == '\n') {
                currentLine += Int64(1)
            }
        }
        return ""
    }

    private func findLineEnd(source: String, start: Int64): Int64 {
        for (i in start..source.size) {
            if (source[i] == '\n') {
                return i
            }
        }
        return source.size
    }
}

// ============================================================================
// Parser - 解析器基类
// 严格翻译自: src/parsers/json.zig (JSONLikeParser), src/parsers/toml.zig (TOML)
// Bun 解析器通用结构:
//   - lexer/scanner: 输入文本和当前位置
//   - log: *logger.Log 错误收集
//   - allocator: 内存分配器
//   - stack_check: 递归深度检查
// 仓颉用抽象基类统一这些模式
// ============================================================================

/// 解析器配置 - 对应 Bun JSONOptions 等配置结构
public class ParseOptions {
    /// 是否允许注释
    public var allowComments: Bool
    /// 是否允许尾逗号
    public var allowTrailingCommas: Bool
    /// 是否严格模式 (严格检查)
    public var strict: Bool
    /// 最大递归深度 - 对应 Bun StackCheck
    public var maxDepth: Int64
    /// 最大输入长度
    public var maxInputLength: Int64

    public init() {
        allowComments = false
        allowTrailingCommas = false
        strict = true
        maxDepth = Int64(256)
        maxInputLength = Int64(512) * Int64(1024) * Int64(1024) // 512MB
    }

    /// JSON 默认配置
    public static func jsonDefaults(): ParseOptions {
        let opts = ParseOptions()
        opts.allowComments = false
        opts.allowTrailingCommas = false
        opts.strict = true
        return opts
    }

    /// JSON5 配置
    public static func json5Defaults(): ParseOptions {
        let opts = ParseOptions()
        opts.allowComments = true
        opts.allowTrailingCommas = true
        opts.strict = false
        return opts
    }

    /// TOML 配置
    public static func tomlDefaults(): ParseOptions {
        let opts = ParseOptions()
        opts.allowComments = true
        opts.allowTrailingCommas = false
        opts.strict = true
        return opts
    }
}

/// Token 类型 - 对应 Bun js_lexer.Token
public enum TokenKind {
    | Eof            // 文件结束
    | LeftBrace      // {
    | RightBrace     // }
    | LeftBracket    // [
    | RightBracket   // ]
    | Colon          // :
    | Comma          // ,
    | Dot            // .
    | String         // 字符串字面量
    | Number         // 数字字面量
    | Boolean        // true/false
    | Null           // null
    | Identifier     // 标识符
    | Newline        // 换行 (TOML/YAML 使用)
    | Comment        // 注释
    | Equal          // =
    | Minus          // -
    | Plus           // +
    | LeftParen      // (
    | RightParen     // )
    | TripleDash     // --- (YAML front matter)
    | TripleDot      // ... (YAML document end)
    | Hash           // # (TOML comment)
    | LeftAngle      // [[ (TOML array of tables)
    | DoubleQuote    // "
    | SingleQuote    // '
    | Pipe           // |
    | GreaterThan    // >
    | At             // @
    | Percent        // %
    | Tilde          // ~
    | Ampersand      // &
    | Asterisk       // *
    | Caret          // ^
    | Question       // ?
    | Unknown        // 未知 token

    public func name(): String {
        match (this) {
            case Eof => "EOF"
            case LeftBrace => "{"
            case RightBrace => "}"
            case LeftBracket => "["
            case RightBracket => "]"
            case Colon => ":"
            case Comma => ","
            case Dot => "."
            case String => "string"
            case Number => "number"
            case Boolean => "boolean"
            case Null => "null"
            case Identifier => "identifier"
            case Newline => "newline"
            case Comment => "comment"
            case Equal => "="
            case Minus => "-"
            case Plus => "+"
            case LeftParen => "("
            case RightParen => ")"
            case TripleDash => "---"
            case TripleDot => "..."
            case Hash => "#"
            case LeftAngle => "[["
            case DoubleQuote => "\""
            case SingleQuote => "'"
            case Pipe => "|"
            case GreaterThan => ">"
            case At => "@"
            case Percent => "%"
            case Tilde => "~"
            case Ampersand => "&"
            case Asterisk => "*"
            case Caret => "^"
            case Question => "?"
            case Unknown => "unknown"
        }
    }
}

/// Token - 对应 Bun js_lexer.Token
/// Bun: const Token = struct { loc: Loc, data: Data }
public class Token {
    /// Token 类型
    public var kind: TokenKind
    /// 位置偏移
    public var offset: Int64
    /// 行号
    public var line: Int64
    /// 列号
    public var column: Int64
    /// 字符串值 (String/Identifier 类型)
    public var text: String
    /// 数字值 (Number 类型)
    public var number: Float64
    /// 布尔值 (Boolean 类型)
    public var bool: Bool
    /// 原始文本
    public var raw: String

    public init(kind: TokenKind, offset: Int64) {
        this.kind = kind
        this.offset = offset
        line = Int64(1)
        column = Int64(1)
        text = ""
        number = Float64(0)
        bool = false
        raw = ""
    }

    public init(kind: TokenKind, offset: Int64, text: String) {
        this.kind = kind
        this.offset = offset
        line = Int64(1)
        column = Int64(1)
        this.text = text
        number = Float64(0)
        bool = false
        raw = text
    }

    public init(kind: TokenKind, offset: Int64, number: Float64) {
        this.kind = kind
        this.offset = offset
        line = Int64(1)
        column = Int64(1)
        text = ""
        this.number = number
        bool = false
        raw = ""
    }

    public init(kind: TokenKind, offset: Int64, bool: Bool) {
        this.kind = kind
        this.offset = offset
        line = Int64(1)
        column = Int64(1)
        text = ""
        number = Float64(0)
        this.bool = bool
        raw = ""
    }
}

/// 解析器基类 - 对应 Bun JSONLikeParser/TOML 的通用结构
/// Bun: pub fn init(allocator, source, log) !Parser
/// 仓颉用抽象类提供通用位置追踪和错误报告
public abstract class BaseParser {
    /// 输入文本
    protected var source: String
    /// 当前位置 - 对应 Bun lexer.pos
    protected var pos: Int64
    /// 当前行号
    protected var line: Int64
    /// 当前列号
    protected var column: Int64
    /// 解析选项
    protected var options: ParseOptions
    /// 错误收集 - 对应 Bun *logger.Log
    protected var errors: ArrayList<ParseError>
    /// 当前 token - 对应 Bun lexer.token
    protected var currentToken: Token
    /// 递归深度 - 对应 Bun StackCheck
    protected var depth: Int64

    public init(source: String) {
        this.source = source
        this.pos = Int64(0)
        this.line = Int64(1)
        this.column = Int64(1)
        this.options = ParseOptions()
        this.errors = ArrayList<ParseError>()
        this.currentToken = Token(TokenKind.Eof, Int64(0))
        this.depth = Int64(0)
    }

    public init(source: String, options: ParseOptions) {
        this.source = source
        this.pos = Int64(0)
        this.line = Int64(1)
        this.column = Int64(1)
        this.options = options
        this.errors = ArrayList<ParseError>()
        this.currentToken = Token(TokenKind.Eof, Int64(0))
        this.depth = Int64(0)
    }

    /// 是否还有输入
    protected func hasMore(): Bool {
        pos < source.size
    }

    /// 查看当前字符
    protected func peek(): Char {
        if (pos >= Int64(0) && pos < source.size) {
            source[Int64(pos)]
        } else {
            Char(0)
        }
    }

    /// 查看前方字符
    protected func peek(offset: Int64): Char {
        let idx = pos + offset
        if (idx >= Int64(0) && idx < source.size) {
            source[Int64(idx)]
        } else {
            Char(0)
        }
    }

    /// 前进一个字符 - 对应 Bun lexer.step()
    protected func advance(): Char {
        if (pos >= source.size) {
            return Char(0)
        }
        let ch = source[Int64(pos)]
        pos += Int64(1)
        if (ch == '\n') {
            line += Int64(1)
            column = Int64(1)
        } else {
            column += Int64(1)
        }
        return ch
    }

    /// 期望并消费指定字符
    protected func expect(ch: Char): Bool {
        skipWhitespace()
        if (pos < source.size && source[Int64(pos)] == ch) {
            advance()
            return true
        }
        return false
    }

    /// 跳过空白 - 对应 Bun lexer 中的 skipWhitespace
    protected func skipWhitespace(): Unit {
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
                advance()
            } else {
                break
            }
        }
    }

    /// 跳过空白 (不含换行) - TOML 使用
    protected func skipWhitespaceNoNewline(): Unit {
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (ch == ' ' || ch == '\t' || ch == '\r') {
                advance()
            } else {
                break
            }
        }
    }

    /// 跳过注释 - 对应 Bun lexer 中的注释处理
    protected func skipLineComment(): Bool {
        if (pos + Int64(1) < source.size) {
            let ch = source[Int64(pos)]
            let next = source[Int64(pos + Int64(1))]
            // 单行注释: // 或 #
            if ((ch == '/' && next == '/') || ch == '#') {
                while (pos < source.size && source[Int64(pos)] != '\n') {
                    advance()
                }
                return true
            }
            // 块注释: /* ... */
            if (ch == '/' && next == '*') {
                advance()
                advance()
                while (pos + Int64(1) < source.size) {
                    if (source[Int64(pos)] == '*' && source[Int64(pos + Int64(1))] == '/') {
                        advance()
                        advance()
                        return true
                    }
                    advance()
                }
            }
        }
        return false
    }

    /// 报告错误 - 对应 Bun log.addError()
    protected func addError(kind: ParseErrorKind, message: String): Unit {
        errors.append(ParseError(kind, message, pos, line, column))
    }

    /// 检查递归深度 - 对应 Bun StackCheck.isSafeToRecurse()
    protected func checkDepth(): Bool {
        depth < options.maxDepth
    }

    /// 进入递归
    protected func enterRecursive(): Bool {
        depth += Int64(1)
        if (depth > options.maxDepth) {
            addError(ParseErrorKind.StackOverflow, "Nesting too deep")
            return false
        }
        return true
    }

    /// 退出递归
    protected func exitRecursive(): Unit {
        depth -= Int64(1)
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        errors.size > Int64(0)
    }

    /// 获取错误列表
    public func getErrors(): ArrayList<ParseError> {
        errors
    }

    /// 读取剩余输入
    protected func remainingText(): String {
        if (pos >= source.size) {
            return ""
        }
        return source[Int64(pos)..source.size]
    }

    /// 读取到行尾
    protected func readLine(): String {
        let start = pos
        while (pos < source.size && source[Int64(pos)] != '\n') {
            pos += Int64(1)
        }
        return source[Int64(start)..Int64(pos)]
    }
}
