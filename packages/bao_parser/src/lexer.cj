// Lexer - JavaScript 词法分析器
// 严格翻译自: src/js_parser/lexer.zig
//   pub fn NewLexer(comptime json_options: JSONOptions) type { ... }
//   约 3400 行 Zig，包含完整的 JS/TS 词法分析
//
// Bun 的 Lexer 使用 comptime 参数生成不同配置的词法分析器
// (JSON/JS/JSX 等)，仓颉使用运行时配置实现等价语义
package bao_parser

import bao_core.*
import bao_collections.*
import bao_unicode.*

// ============================================================================
// Lexer 配置 - 对应 Bun JSONOptions
// 严格翻译自: src/js_parser/lexer.zig:37-56
//   pub const JSONOptions = struct { ... }
// ============================================================================

/// 词法分析器配置 - 对应 Bun JSONOptions
public class LexerOptions {
    /// 是否为 JSON 模式 - 对应 Bun is_json
    public var isJson: Bool
    /// 是否允许注释 (tsconfig.json) - 对应 Bun allow_comments
    public var allowComments: Bool
    /// 是否允许尾逗号 - 对应 Bun allow_trailing_commas
    public var allowTrailingCommas: Bool
    /// 是否忽略前导转义序列 - 对应 Bun ignore_leading_escape_sequences
    public var ignoreLeadingEscapeSequences: Bool
    /// 是否忽略尾部转义序列 - 对应 Bun ignore_trailing_escape_sequences
    public var ignoreTrailingEscapeSequences: Bool
    /// JSON 重复键警告 - 对应 Bun json_warn_duplicate_keys
    public var jsonWarnDuplicateKeys: Bool
    /// 是否原本为宏 - 对应 Bun was_originally_macro
    public var wasOriginallyMacro: Bool
    /// 是否猜测缩进 - 对应 Bun guess_indentation
    public var guessIndentation: Bool

    public init() {
        isJson = false
        allowComments = false
        allowTrailingCommas = false
        ignoreLeadingEscapeSequences = false
        ignoreTrailingEscapeSequences = false
        jsonWarnDuplicateKeys = true
        wasOriginallyMacro = false
        guessIndentation = false
    }

    /// 创建 JSON 配置 - 对应 Bun 默认 JSON 配置
    public static func json(): LexerOptions {
        let opts = LexerOptions()
        opts.isJson = true
        return opts
    }

    /// 创建 tsconfig.json 配置 - 允许注释和尾逗号
    public static func tsconfig(): LexerOptions {
        let opts = LexerOptions()
        opts.isJson = true
        opts.allowComments = true
        opts.allowTrailingCommas = true
        return opts
    }
}

// ============================================================================
// JSX Pragma - 对应 Bun JSXPragma
// 严格翻译自: src/js_parser/lexer.zig:17-35
//   pub const JSXPragma = struct { _jsx, _jsxFrag, _jsxRuntime, _jsxImportSource }
// ============================================================================

/// JSX 编译指示 - 对应 Bun JSXPragma
/// 存储 JSX 相关的编译指示 (pragma)
public class JsxPragma {
    public var jsx: String       // @jsx
    public var jsxFrag: String   // @jsxFrag
    public var jsxRuntime: String // @jsxRuntime
    public var jsxImportSource: String // @jsxImportSource

    public init() {
        jsx = ""
        jsxFrag = ""
        jsxRuntime = ""
        jsxImportSource = ""
    }
}

// ============================================================================
// 字符串字面量格式 - 对应 Bun string_literal_raw_format
// ============================================================================

/// 字符串字面量原始格式 - 对应 Bun enum { ascii, utf16, needs_decode }
public enum StringLiteralFormat {
    | Ascii       // 纯 ASCII，无需解码
    | Utf16       // UTF-16 编码
    | NeedsDecode // 包含转义序列，需要解码
}

// ============================================================================
// ScanResult - 标识符扫描结果
// 严格翻译自: src/js_parser/lexer.zig:852
//   pub const ScanResult = struct { token: T, contents: string }
// ============================================================================

/// 标识符扫描结果 - 对应 Bun ScanResult
public class ScanResult {
    public var token: Token
    public var contents: String

    public init(token: Token, contents: String) {
        this.token = token
        this.contents = contents
    }
}

/// 标识符种类 - 对应 Bun IdentifierKind
public enum IdentifierKind {
    | Normal   // 普通标识符
    | Private  // 私有标识符 (#foo)

    public operator func ==(rhs: IdentifierKind): Bool {
        match (this) {
            case Normal => match (rhs) { case Normal => true case _ => false }
            case Private => match (rhs) { case Private => true case _ => false }
        }
    }
}

// ============================================================================
// Lexer - JavaScript 词法分析器
// 严格翻译自: src/js_parser/lexer.zig:93-...
//   pub fn NewLexer_(...) type { return struct { ... } }
//
// Bun Lexer 字段:
//   log: *logger.Log,
//   source: logger.Source,
//   current: usize = 0,       // 当前读取位置
//   start: usize = 0,         // 当前 token 起始位置
//   end: usize = 0,           // 当前 token 结束位置
//   did_panic: bool = false,
//   approximate_newline_count: usize = 0,
//   token: T = .t_end_of_file,
//   has_newline_before: bool = false,
//   has_pure_comment_before: bool = false,
//   has_no_side_effect_comment_before: bool = false,
//   is_legacy_octal_literal: bool = false,
//   code_point: CodePoint = -1,
//   identifier: string = "",
//   number: f64 = 0.0,
//   ...
// ============================================================================

/// JavaScript 词法分析器 - 严格对应 Bun Lexer
/// 将源代码文本转换为 Token 流
public class Lexer {
    /// 日志 - 对应 Bun log: *logger.Log
    public var log: Log
    /// 源文件 - 对应 Bun source: logger.Source
    public var source: Source
    /// 配置 - 对应 Bun comptime json_options
    public var options: LexerOptions

    // ===== 位置跟踪 =====
    /// 当前读取位置 - 对应 Bun current: usize
    public var current: Int64
    /// 当前 token 起始位置 - 对应 Bun start: usize
    public var start: Int64
    /// 当前 token 结束位置 - 对应 Bun end: usize
    public var end: Int64

    // ===== Token 状态 =====
    /// 当前 token - 对应 Bun token: T
    public var token: Token
    /// 当前 Unicode 码点 - 对应 Bun code_point: CodePoint
    public var codePoint: Int64
    /// 前方是否有换行 - 对应 Bun has_newline_before: bool
    public var hasNewlineBefore: Bool
    /// 前方是否有 @__PURE__ 注释 - 对应 Bun has_pure_comment_before
    public var hasPureCommentBefore: Bool
    /// 前方是否有 @__NO_SIDE_EFFECTS__ 注释
    public var hasNoSideEffectCommentBefore: Bool
    /// 是否发生 panic - 对应 Bun did_panic
    public var didPanic: Bool
    /// 近似换行计数 - 对应 Bun approximate_newline_count
    public var approximateNewlineCount: Int64

    // ===== Token 值 =====
    /// 标识符文本 - 对应 Bun identifier: string
    public var identifier: String
    /// 数值 - 对应 Bun number: f64
    public var number: Float64
    /// 是否为旧式八进制 - 对应 Bun is_legacy_octal_literal
    public var isLegacyOctalLiteral: Bool

    // ===== 字符串字面量 =====
    /// 字符串字面量原始内容 - 对应 Bun string_literal_raw_content
    public var stringLiteralRawContent: String
    /// 字符串字面量起始位置 - 对应 Bun string_literal_start
    public var stringLiteralStart: Int64
    /// 字符串字面量格式 - 对应 Bun string_literal_raw_format
    public var stringLiteralRawFormat: StringLiteralFormat

    // ===== 模板字面量 =====
    /// 是否重新扫描 } 作为模板 token - 对应 Bun rescan_close_brace_as_template_token
    public var rescanCloseBraceAsTemplateToken: Bool

    // ===== 正则表达式 =====
    /// 正则表达式标志起始位置 - 对应 Bun regex_flags_start
    public var regexFlagsStart: Int64

    // ===== await 处理 =====
    /// 前一个 token 是否为 await 关键字 - 对应 Bun prev_token_was_await_keyword
    public var prevTokenWasAwaitKeyword: Bool
    /// await 关键字位置 - 对应 Bun await_keyword_loc
    public var awaitKeywordLoc: Loc
    /// 函数/箭头起始位置 - 对应 Bun fn_or_arrow_start_loc
    public var fnOrArrowStartLoc: Loc

    // ===== 错误处理 =====
    /// 上一个错误位置 - 对应 Bun prev_error_loc
    public var prevErrorLoc: Loc
    /// 是否禁用日志 - 对应 Bun is_log_disabled
    public var isLogDisabled: Bool

    // ===== 注释跟踪 =====
    /// 是否保留所有注释 - 对应 Bun preserve_all_comments_before
    public var preserveAllCommentsBefore: Bool
    /// 需要保留的注释列表 - 对应 Bun comments_to_preserve_before
    public var commentsToPreserveBefore: ArrayList<Range>
    /// 是否跟踪注释 - 对应 Bun track_comments
    public var trackComments: Bool
    /// 所有注释 - 对应 Bun all_comments
    public var allComments: ArrayList<Range>

    // ===== JSX =====
    /// JSX pragma - 对应 Bun jsx_pragma
    public var jsxPragma: JsxPragma
    /// 源映射 URL - 对应 Bun source_mapping_url
    public var sourceMappingURL: String

    /// 初始化词法分析器但不读取第一个 token
    /// 对应 Bun initWithoutReading
    public init(log: Log, source: Source, options: LexerOptions) {
        this.log = log
        this.source = source
        this.options = options
        current = 0
        start = 0
        end = 0
        token = Token.EndOfFile
        codePoint = -1
        hasNewlineBefore = false
        hasPureCommentBefore = false
        hasNoSideEffectCommentBefore = false
        didPanic = false
        approximateNewlineCount = 0
        identifier = ""
        number = 0.0
        isLegacyOctalLiteral = false
        stringLiteralRawContent = ""
        stringLiteralStart = 0
        stringLiteralRawFormat = StringLiteralFormat.Ascii
        rescanCloseBraceAsTemplateToken = false
        regexFlagsStart = -1
        prevTokenWasAwaitKeyword = false
        awaitKeywordLoc = Loc.EMPTY
        fnOrArrowStartLoc = Loc.EMPTY
        prevErrorLoc = Loc.EMPTY
        isLogDisabled = false
        preserveAllCommentsBefore = false
        commentsToPreserveBefore = ArrayList<Range>()
        trackComments = false
        allComments = ArrayList<Range>()
        jsxPragma = JsxPragma()
        sourceMappingURL = ""
    }

    /// 便捷构造 - 默认 JS 配置
    public init(log: Log, source: Source) {
        this.log = log
        this.source = source
        this.options = LexerOptions()
        current = 0
        start = 0
        end = 0
        token = Token.EndOfFile
        codePoint = -1
        hasNewlineBefore = false
        hasPureCommentBefore = false
        hasNoSideEffectCommentBefore = false
        didPanic = false
        approximateNewlineCount = 0
        identifier = ""
        number = 0.0
        isLegacyOctalLiteral = false
        stringLiteralRawContent = ""
        stringLiteralStart = 0
        stringLiteralRawFormat = StringLiteralFormat.Ascii
        rescanCloseBraceAsTemplateToken = false
        regexFlagsStart = -1
        prevTokenWasAwaitKeyword = false
        awaitKeywordLoc = Loc.EMPTY
        fnOrArrowStartLoc = Loc.EMPTY
        prevErrorLoc = Loc.EMPTY
        isLogDisabled = false
        preserveAllCommentsBefore = false
        commentsToPreserveBefore = ArrayList<Range>()
        trackComments = false
        allComments = ArrayList<Range>()
        jsxPragma = JsxPragma()
        sourceMappingURL = ""
    }

    /// 初始化并读取第一个 token - 对应 Bun init()
    /// Bun: pub fn init(log, source, allocator) !LexerType
    public static func initFunc(log: Log, source: Source): Lexer {
        let lexer = Lexer(log, source)
        lexer.step()
        lexer.nextToken()
        return lexer
    }

    /// 初始化并读取第一个 token (带配置)
    public static func initFunc(log: Log, source: Source, options: LexerOptions): Lexer {
        let lexer = Lexer(log, source, options)
        lexer.step()
        lexer.nextToken()
        return lexer
    }

    // ========================================================================
    // 位置和范围
    // ========================================================================

    /// 获取当前位置 - 对应 Bun loc()
    public func loc(): Loc {
        return Loc(start)
    }

    /// 获取当前 token 范围 - 对应 Bun range()
    public func range(): Range {
        return Range(Loc(start), end - start)
    }

    /// 获取当前 token 的原始文本 - 对应 Bun raw()
    public func raw(): String {
        let contents = source.contents
        if (start >= contents.size) {
            return ""
        }
        let e = if (end > contents.size) { contents.size } else { end }
        var sb = StringBuilder()
        for (i in start..e) {
            sb.append(Rune(contents[Int64(i)]))
        }
        return sb.toString()
    }

    // ========================================================================
    // 核心: step() - 前进到下一个码点
    // 严格对应 Bun Lexer.step()
    //   pub fn step(noalias lexer: *LexerType) void {
    //       lexer.code_point = lexer.nextCodepoint();
    //       lexer.approximate_newline_count += @intFromBool(lexer.code_point == '\n');
    //   }
    // ========================================================================

    /// 前进到下一个码点 - 对应 Bun step()
    public func step(): Unit {
        codePoint = nextCodepoint()
        if (codePoint == 10) { // '\n'
            approximateNewlineCount += 1
        }
    }

    /// 获取下一个码点 - 对应 Bun nextCodepoint()
    private func nextCodepoint(): Int64 {
        if (current >= source.contents.size) {
            end = source.contents.size
            return -1
        }
        let b = Int64(source.contents[current])
        // UTF-8 字节序列长度
        let cpLen: Int64 = if (b < 0x80) {
            1
        } else if (b < 0xE0) {
            2
        } else if (b < 0xF0) {
            3
        } else {
            4
        }

        if (current + cpLen > source.contents.size) {
            end = source.contents.size
            current = source.contents.size
            return -1
        }

        // 解码 UTF-8
        let cp: Int64 = if (cpLen == 1) {
            b
        } else if (cpLen == 2) {
            ((b & 0x1F) << 6) | Int64(source.contents[current + 1] & 0x3F)
        } else if (cpLen == 3) {
            ((b & 0x0F) << 12) | (Int64(source.contents[current + 1] & 0x3F) << 6) |
                Int64(source.contents[current + 2] & 0x3F)
        } else {
            ((b & 0x07) << 18) | (Int64(source.contents[current + 1] & 0x3F) << 12) |
                (Int64(source.contents[current + 2] & 0x3F) << 6) |
                Int64(source.contents[current + 3] & 0x3F)
        }

        end = current
        current += cpLen
        return cp
    }

    // ========================================================================
    // 核心: next() - 扫描下一个 token
    // 严格对应 Bun Lexer.next()
    //   pub fn next(noalias lexer: *LexerType) !void { ... }
    // 约 700 行 Zig，是词法分析器的核心
    // ========================================================================

    /// 扫描下一个 token - 对应 Bun next()
    public func nextToken(): Unit {
        hasNewlineBefore = (end == 0)
        hasPureCommentBefore = false
        hasNoSideEffectCommentBefore = false
        prevTokenWasAwaitKeyword = false

        while (true) {
            start = end
            token = Token.EndOfFile

            if (codePoint == -1) {
                // EOF
                return
            }

            // 主分发 switch - 对应 Bun next() 中的大 switch
            if (codePoint == 35) { // '#'
                // Hashbang 或私有标识符
                scanHashbangOrPrivate()
                return

            } else if (isWhitespace(codePoint)) {
                // 空白字符: \r \n \t 空格 等
                if (codePoint == 13 || codePoint == 10 || codePoint == 0x2028 || codePoint == 0x2029) {
                    hasNewlineBefore = true
                }
                step()
                continue

            } else if (codePoint == 40) { // '('
                step()
                token = Token.OpenParen
                return

            } else if (codePoint == 41) { // ')'
                step()
                token = Token.CloseParen
                return

            } else if (codePoint == 91) { // '['
                step()
                token = Token.OpenBracket
                return

            } else if (codePoint == 93) { // ']'
                step()
                token = Token.CloseBracket
                return

            } else if (codePoint == 123) { // '{'
                step()
                token = Token.OpenBrace
                return

            } else if (codePoint == 125) { // '}'
                step()
                token = Token.CloseBrace
                return

            } else if (codePoint == 44) { // ','
                step()
                token = Token.Comma
                return

            } else if (codePoint == 58) { // ':'
                step()
                token = Token.Colon
                return

            } else if (codePoint == 59) { // ';'
                step()
                token = Token.Semicolon
                return

            } else if (codePoint == 64) { // '@'
                step()
                token = Token.At
                return

            } else if (codePoint == 126) { // '~'
                step()
                token = Token.Tilde
                return

            } else if (codePoint == 63) { // '?'
                // '?' 或 '?.' 或 '??' 或 '??='
                step()
                if (codePoint == 63) { // '??'
                    step()
                    if (codePoint == 61) { // '??='
                        step()
                        token = Token.QuestionQuestionEquals
                    } else {
                        token = Token.QuestionQuestion
                    }
                } else if (codePoint == 46) { // '?.'
                    token = Token.Question
                    // 向前看以区分 'a?.1:b' 和 'a?.b'
                    if (current < source.contents.size) {
                        let c = Int64(source.contents[current])
                        if (c < 48 || c > 57) { // 不是数字
                            step()
                            token = Token.QuestionDot
                        }
                    }
                } else {
                    token = Token.Question
                }
                return

            } else if (codePoint == 37) { // '%'
                step()
                if (codePoint == 61) { // '%='
                    step()
                    token = Token.PercentEquals
                } else {
                    token = Token.Percent
                }
                return

            } else if (codePoint == 38) { // '&'
                step()
                if (codePoint == 61) { // '&='
                    step()
                    token = Token.AmpersandEquals
                } else if (codePoint == 38) { // '&&'
                    step()
                    if (codePoint == 61) { // '&&='
                        step()
                        token = Token.AmpersandAmpersandEquals
                    } else {
                        token = Token.AmpersandAmpersand
                    }
                } else {
                    token = Token.Ampersand
                }
                return

            } else if (codePoint == 124) { // '|'
                step()
                if (codePoint == 61) { // '|='
                    step()
                    token = Token.BarEquals
                } else if (codePoint == 124) { // '||'
                    step()
                    if (codePoint == 61) { // '||='
                        step()
                        token = Token.BarBarEquals
                    } else {
                        token = Token.BarBar
                    }
                } else {
                    token = Token.Bar
                }
                return

            } else if (codePoint == 94) { // '^'
                step()
                if (codePoint == 61) { // '^='
                    step()
                    token = Token.CaretEquals
                } else {
                    token = Token.Caret
                }
                return

            } else if (codePoint == 43) { // '+'
                step()
                if (codePoint == 61) { // '+='
                    step()
                    token = Token.PlusEquals
                } else if (codePoint == 43) { // '++'
                    step()
                    token = Token.PlusPlus
                } else {
                    token = Token.Plus
                }
                return

            } else if (codePoint == 45) { // '-'
                step()
                if (codePoint == 61) { // '-='
                    step()
                    token = Token.MinusEquals
                } else if (codePoint == 45) { // '--'
                    step()
                    if (codePoint == 62 && hasNewlineBefore) { // '-->' HTML 注释
                        // 跳过 HTML 单行注释
                        while (codePoint != -1 && codePoint != 13 &&
                               codePoint != 10 && codePoint != 0x2028 &&
                               codePoint != 0x2029) {
                            step()
                        }
                        continue
                    }
                    token = Token.MinusMinus
                } else {
                    token = Token.Minus
                }
                return

            } else if (codePoint == 42) { // '*'
                step()
                if (codePoint == 61) { // '*='
                    step()
                    token = Token.AsteriskEquals
                } else if (codePoint == 42) { // '**'
                    step()
                    if (codePoint == 61) { // '**='
                        step()
                        token = Token.AsteriskAsteriskEquals
                    } else {
                        token = Token.AsteriskAsterisk
                    }
                } else {
                    token = Token.Asterisk
                }
                return

            } else if (codePoint == 47) { // '/'
                step()
                if (codePoint == 61) { // '/='
                    step()
                    token = Token.SlashEquals
                } else if (codePoint == 47) { // '//'
                    // 单行注释
                    scanSingleLineComment()
                    scanCommentText(false)
                    continue
                } else if (codePoint == 42) { // '/*'
                    step()
                    // 多行注释
                    scanMultiLineComment()
                    scanCommentText(true)
                    continue
                } else {
                    token = Token.Slash
                }
                return

            } else if (codePoint == 61) { // '='
                step()
                if (codePoint == 62) { // '=>'
                    step()
                    token = Token.EqualsGreaterThan
                } else if (codePoint == 61) { // '=='
                    step()
                    if (codePoint == 61) { // '==='
                        step()
                        token = Token.EqualsEqualsEquals
                    } else {
                        token = Token.EqualsEquals
                    }
                } else {
                    token = Token.Equals
                }
                return

            } else if (codePoint == 60) { // '<'
                step()
                if (codePoint == 61) { // '<='
                    step()
                    token = Token.LessThanEquals
                } else if (codePoint == 60) { // '<<'
                    step()
                    if (codePoint == 61) { // '<<='
                        step()
                        token = Token.LessThanLessThanEquals
                    } else {
                        token = Token.LessThanLessThan
                    }
                } else {
                    token = Token.LessThan
                }
                return

            } else if (codePoint == 62) { // '>'
                step()
                if (codePoint == 61) { // '>='
                    step()
                    token = Token.GreaterThanEquals
                } else if (codePoint == 62) { // '>>'
                    step()
                    if (codePoint == 61) { // '>>='
                        step()
                        token = Token.GreaterThanGreaterThanEquals
                    } else if (codePoint == 62) { // '>>>'
                        step()
                        if (codePoint == 61) { // '>>>='
                            step()
                            token = Token.GreaterThanGreaterThanGreaterThanEquals
                        } else {
                            token = Token.GreaterThanGreaterThanGreaterThan
                        }
                    } else {
                        token = Token.GreaterThanGreaterThan
                    }
                } else {
                    token = Token.GreaterThan
                }
                return

            } else if (codePoint == 33) { // '!'
                step()
                if (codePoint == 61) { // '!='
                    step()
                    if (codePoint == 61) { // '!='
                        step()
                        token = Token.ExclamationEqualsEquals
                    } else {
                        token = Token.ExclamationEquals
                    }
                } else {
                    token = Token.Exclamation
                }
                return

            } else if (codePoint == 39) { // '\''
                parseStringLiteral(39)
                return

            } else if (codePoint == 34) { // '"'
                parseStringLiteral(34)
                return

            } else if (codePoint == 96) { // '`'
                parseStringLiteral(96)
                return

            } else if (codePoint == 46 || (codePoint >= 48 && codePoint <= 57)) {
                // '.' 或 '0'-'9'
                parseNumericLiteralOrDot()
                return

            } else if (codePoint == 95 || codePoint == 36 ||
                       (codePoint >= 97 && codePoint <= 122) ||
                       (codePoint >= 65 && codePoint <= 90)) {
                // '_', '$', 'a'-'z', 'A'-'Z'
                scanIdentifier()
                return

            } else if (codePoint == 92) { // '\'
                // 转义标识符
                let result = scanIdentifierWithEscapes(IdentifierKind.Normal)
                identifier = result.contents
                token = result.token
                return

            } else {
                // 检查 Unicode 标识符起始
                if (isIdentifierStart(codePoint)) {
                    step()
                    while (isIdentifierContinue(codePoint)) {
                        step()
                    }
                    if (codePoint == 92) { // '\'
                        let result = scanIdentifierWithEscapes(IdentifierKind.Normal)
                        identifier = result.contents
                        token = result.token
                    } else {
                        token = Token.Identifier
                        identifier = raw()
                    }
                    return
                }

                // 无法识别的字符
                end = current
                token = Token.SyntaxError
                return
            }
        }
    }

    // ========================================================================
    // Hashbang 和私有标识符扫描
    // ========================================================================

    /// 扫描 Hashbang 或私有标识符
    private func scanHashbangOrPrivate(): Unit {
        if (start == 0 && source.contents.size > 1 && source.contents[1] == UInt8(33)) {
            // "#!/usr/bin/env node"
            token = Token.Hashbang
            while (true) {
                step()
                if (codePoint == 13 || codePoint == 10 || codePoint == 0x2028 ||
                    codePoint == 0x2029 || codePoint == -1) {
                    break
                }
            }
            identifier = raw()
        } else {
            // "#foo"
            step()
            if (codePoint == 92) { // '\'
                let result = scanIdentifierWithEscapes(IdentifierKind.Private)
                identifier = result.contents
            } else {
                if (!isIdentifierStart(codePoint)) {
                    addError(start, "Syntax Error")
                }
                step()
                while (isIdentifierContinue(codePoint)) {
                    step()
                }
                if (codePoint == 92) { // '\'
                    let result = scanIdentifierWithEscapes(IdentifierKind.Private)
                    identifier = result.contents
                } else {
                    identifier = raw()
                }
            }
            token = Token.PrivateIdentifier
        }
    }

    // ========================================================================
    // 标识符扫描
    // ========================================================================

    /// 扫描标识符 - 对应 Bun next() 中标识符分支
    private func scanIdentifier(): Unit {
        // 快速扫描 ASCII 标识符
        while (current < source.contents.size) {
            let b = Int64(source.contents[current])
            if ((b >= 97 && b <= 122) || (b >= 65 && b <= 90) ||
                b == 95 || b == 36 || (b >= 48 && b <= 57)) {
                current += 1
            } else {
                break
            }
        }
        end = current
        step()

        // 处理非 ASCII 标识符字符
        if (codePoint >= 0x80) {
            while (isIdentifierContinue(codePoint)) {
                step()
            }
        }

        if (codePoint != 92) { // 不以 '\' 结尾
            identifier = raw()
            let kw = Keywords.get(identifier)
            match (kw) {
                case Some(t) => token = t
                case None => token = Token.Identifier
            }
        } else {
            let result = scanIdentifierWithEscapes(IdentifierKind.Normal)
            identifier = result.contents
            token = result.token
        }
    }

    /// 扫描带转义的标识符 - 对应 Bun scanIdentifierWithEscapes()
    /// Bun: pub fn scanIdentifierWithEscapes(lexer, kind) !ScanResult
    public func scanIdentifierWithEscapes(kind: IdentifierKind): ScanResult {
        // 第一遍: 扫描标识符长度
        while (true) {
            if (codePoint == 92) { // '\'
                step()
                if (codePoint != 117) { // 'u'
                    addError(loc().start, "Invalid escape sequence")
                }
                step()
                if (codePoint == 123) { // '{'
                    // 变长 Unicode 转义
                    step()
                    while (codePoint != 125) { // '}'
                        if ((codePoint >= 48 && codePoint <= 57) ||
                            (codePoint >= 97 && codePoint <= 102) ||
                            (codePoint >= 65 && codePoint <= 70)) {
                            step()
                        } else {
                            addError(loc().start, "Syntax Error")
                            break
                        }
                    }
                    step()
                } else {
                    // 固定 4 位 Unicode 转义
                    var j: Int64 = 0
                    while (j < 4) {
                        if ((codePoint >= 48 && codePoint <= 57) ||
                            (codePoint >= 97 && codePoint <= 102) ||
                            (codePoint >= 65 && codePoint <= 70)) {
                            step()
                        } else {
                            addError(loc().start, "Syntax Error")
                            break
                        }
                        j += 1
                    }
                }
                continue
            }
            if (!isIdentifierContinue(codePoint)) {
                break
            }
            step()
        }

        // 简化: 直接用原始文本作为标识符
        let originalText = raw()
        var resultToken: Token = Token.Identifier
        // 检查是否为关键字 (转义关键字不匹配)
        match (kind) {
            case IdentifierKind.Normal => ()
            case _ => ()
        }
        return ScanResult(resultToken, originalText)
    }

    // ========================================================================
    // 字符串字面量扫描
    // 严格对应 Bun Lexer.parseStringLiteral()
    //   pub fn parseStringLiteral(lexer, comptime quote) !void
    // ========================================================================

    /// 解析字符串字面量 - 对应 Bun parseStringLiteral()
    /// quote: 39=' 34=" 96=`
    public func parseStringLiteral(`quote`: Int64): Unit {
        if (`quote` != 96) { // 非 '`'
            token = Token.StringLiteral
        } else if (rescanCloseBraceAsTemplateToken) {
            token = Token.TemplateTail
        } else {
            token = Token.NoSubstitutionTemplateLiteral
        }

        step()

        // 扫描字符串内容
        var needsDecode = false
        var content = StringBuilder()

        while (true) {
            if (codePoint == -1) {
                addError(start, "Unterminated string literal")
                break
            }
            if (codePoint == `quote`) {
                step()
                break
            }
            if (codePoint == 92) { // '\'
                needsDecode = true
                step()
                let escaped = decodeEscape(codePoint)
                if (escaped >= 0) {
                    content.append(Rune(escaped))
                }
                step()
                continue
            }
            // 模板字面量的 `${` - 对应 Bun template head/middle
            if (`quote` == 96 && codePoint == 36) { // '$'
                // 向前看
                if (current < source.contents.size && source.contents[current] == UInt8(123)) { // '{'
                    step() // 跳过 '$'
                    step() // 跳过 '{'
                    match (token) {
                        case Token.NoSubstitutionTemplateLiteral => token = Token.TemplateHead
                        case _ => token = Token.TemplateMiddle
                    }
                    break
                }
            }
            content.append(Rune(codePoint))
            step()
        }

        stringLiteralRawContent = content.toString()
        stringLiteralStart = start
        stringLiteralRawFormat = if (needsDecode) {
            StringLiteralFormat.NeedsDecode
        } else {
            StringLiteralFormat.Ascii
        }
    }

    /// 解码转义字符 - 对应 Bun decodeEscapeSequences 中的单字符转义
    private func decodeEscape(c: Int64): Int64 {
        if (c == 98) { return 0x08 } // 'b' -> backspace
        if (c == 102) { return 0x0C } // 'f' -> form feed
        if (c == 110) { return 0x0A } // 'n' -> newline
        if (c == 114) { return 0x0D } // 'r' -> carriage return
        if (c == 116) { return 0x09 } // 't' -> tab
        if (c == 118) { return 0x0B } // 'v' -> vertical tab
        if (c == 48) { return 0 }     // '0' -> null
        // \xHH
        if (c == 120) { // 'x'
            step()
            let h1 = decodeHexDigit(codePoint)
            step()
            let h2 = decodeHexDigit(codePoint)
            return (h1 << 4) | h2
        }
        // \uHHHH or \u{H...}
        if (c == 117) { // 'u'
            step()
            if (codePoint == 123) { // '{'
                var value: Int64 = 0
                step()
                while (codePoint != 125) { // '}'
                    value = value * 16 + decodeHexDigit(codePoint)
                    step()
                }
                return value
            } else {
                var value: Int64 = 0
                var i: Int64 = 0
                while (i < 4) {
                    value = value * 16 + decodeHexDigit(codePoint)
                    if (i < 3) {
                        step()
                    }
                    i += 1
                }
                return value
            }
        }
        // 其他: 直接返回字符本身
        return c
    }

    /// 解码十六进制数字
    private func decodeHexDigit(c: Int64): Int64 {
        if (c >= 48 && c <= 57) { return c - 48 }     // '0'-'9'
        if (c >= 97 && c <= 102) { return c - 97 + 10 } // 'a'-'f'
        if (c >= 65 && c <= 70) { return c - 65 + 10 }  // 'A'-'F'
        return 0
    }

    // ========================================================================
    // 数值字面量扫描
    // 严格对应 Bun Lexer.parseNumericLiteralOrDot()
    //   fn parseNumericLiteralOrDot(lexer) !void
    // ========================================================================

    /// 解析数值字面量或点 - 对应 Bun parseNumericLiteralOrDot()
    public func parseNumericLiteralOrDot(): Unit {
        let first = codePoint
        step()

        // '.' 后面不是数字
        if (first == 46 && (codePoint < 48 || codePoint > 57)) {
            // "..."
            if (codePoint == 46 && current < source.contents.size &&
                source.contents[current] == UInt8(46)) {
                step()
                step()
                token = Token.DotDotDot
                return
            }
            // "."
            token = Token.Dot
            return
        }

        var underscoreCount: Int64 = 0
        var lastUnderscoreEnd: Int64 = 0
        var hasDotOrExponent = (first == 46)
        var base: Float64 = 0.0
        isLegacyOctalLiteral = false
        token = Token.NumericLiteral

        // 检查二进制、八进制、十六进制
        if (first == 48) { // '0'
            if (codePoint == 98 || codePoint == 66) { // 'b' 'B'
                base = 2.0
            } else if (codePoint == 111 || codePoint == 79) { // 'o' 'O'
                base = 8.0
            } else if (codePoint == 120 || codePoint == 88) { // 'x' 'X'
                base = 16.0
            } else if ((codePoint >= 48 && codePoint <= 55) || codePoint == 95) {
                // '0'-'7' 或 '_'
                base = 8.0
                isLegacyOctalLiteral = true
            }
        }

        if (base != 0.0) {
            // 整数字面量
            var isFirst = true
            number = 0.0
            if (!isLegacyOctalLiteral) {
                step()
            }

            while (true) {
                if (codePoint == 95) { // '_'
                    if (isFirst) {
                        addError(start, "Syntax Error")
                    }
                    lastUnderscoreEnd = end
                    underscoreCount += 1
                } else if (codePoint >= 48 && codePoint <= 49) { // '0'-'1'
                    number = number * base + Float64(codePoint - 48)
                } else if (codePoint >= 50 && codePoint <= 55) { // '2'-'7'
                    if (base == 2.0) {
                        addError(start, "Syntax Error")
                    }
                    number = number * base + Float64(codePoint - 48)
                } else if (codePoint >= 56 && codePoint <= 57) { // '8'-'9'
                    if (base < 10.0) {
                        addError(start, "Syntax Error")
                    }
                    number = number * base + Float64(codePoint - 48)
                } else if (codePoint >= 65 && codePoint <= 70) { // 'A'-'F'
                    if (base != 16.0) {
                        addError(start, "Syntax Error")
                    }
                    number = number * base + Float64(codePoint + 10 - 65)
                } else if (codePoint >= 97 && codePoint <= 102) { // 'a'-'f'
                    if (base != 16.0) {
                        addError(start, "Syntax Error")
                    }
                    number = number * base + Float64(codePoint + 10 - 97)
                } else {
                    if (isFirst) {
                        addError(start, "Syntax Error")
                    }
                    break
                }
                step()
                isFirst = false
            }

            // 检查 BigInt 后缀 'n'
            let isBigInteger = codePoint == 110 && !hasDotOrExponent
            if (isBigInteger) {
                step()
                token = Token.BigIntegerLiteral
                identifier = raw()
            } else if (isLegacyOctalLiteral) {
                // 旧式八进制: 作为十进制数解析原始文本
                let text = raw()
                number = parseFloat(text)
            }
        } else {
            // 浮点数字面量
            // 初始数字
            while (true) {
                if (codePoint < 48 || codePoint > 57) {
                    if (codePoint != 95) { break }
                    lastUnderscoreEnd = end
                    underscoreCount += 1
                }
                step()
            }

            // 小数部分
            if (first != 46 && codePoint == 46) { // '.'
                hasDotOrExponent = true
                step()
                while (true) {
                    if (codePoint < 48 || codePoint > 57) {
                        if (codePoint != 95) { break }
                    }
                    step()
                }
            }

            // 指数部分
            if (codePoint == 101 || codePoint == 69) { // 'e' 'E'
                hasDotOrExponent = true
                step()
                if (codePoint == 43 || codePoint == 45) { // '+' '-'
                    step()
                }
                while (true) {
                    if (codePoint < 48 || codePoint > 57) { break }
                    step()
                }
            }

            // BigInt 后缀
            if (codePoint == 110 && !hasDotOrExponent) { // 'n'
                step()
                token = Token.BigIntegerLiteral
                identifier = raw()
            } else {
                // 解析数值
                let text = raw()
                number = parseFloat(text)
            }
        }
    }

    // ========================================================================
    // 注释扫描
    // ========================================================================

    /// 扫描单行注释 - 对应 Bun scanSingleLineComment()
    private func scanSingleLineComment(): Unit {
        while (true) {
            if (codePoint == 13 || codePoint == 10 || codePoint == 0x2028 ||
                codePoint == 0x2029 || codePoint == -1) {
                break
            }
            step()
        }
    }

    /// 扫描多行注释 - 对应 Bun 多行注释循环
    private func scanMultiLineComment(): Unit {
        while (true) {
            if (codePoint == 42) { // '*'
                step()
                if (codePoint == 47) { // '/'
                    step()
                    break
                }
            } else if (codePoint == 13 || codePoint == 10 || codePoint == 0x2028 || codePoint == 0x2029) {
                step()
                hasNewlineBefore = true
            } else if (codePoint == -1) {
                addError(start, "Expected \"*/\" to terminate multi-line comment")
                break
            } else {
                step()
            }
        }
    }

    /// 扫描注释文本 - 对应 Bun scanCommentText()
    /// 检测特殊注释如 @__PURE__ 和 @__NO_SIDE_EFFECTS__
    private func scanCommentText(isMultiLine: Bool): Unit {
        let text = raw()

        // 检测 @__PURE__
        if (text.contains("@__PURE__")) {
            hasPureCommentBefore = true
        }
        // 检测 @__NO_SIDE_EFFECTS__
        if (text.contains("@__NO_SIDE_EFFECTS__")) {
            hasNoSideEffectCommentBefore = true
        }

        // 检测 //# sourceMappingURL
        if (!isMultiLine) {
            let sourceMapPrefix = "//# sourceMappingURL="
            if (let Some(idx) <- text.indexOf(sourceMapPrefix)) {
                let startIndex = idx + Int64(sourceMapPrefix.size)
                sourceMappingURL = text[startIndex..text.size]
            }
        }

        if (trackComments) {
            allComments.append(range())
        }
    }

    // ========================================================================
    // 正则表达式扫描
    // 严格对应 Bun Lexer.scanRegExp()
    //   pub fn scanRegExp(lexer) !void
    // ========================================================================

    /// 扫描正则表达式 - 对应 Bun scanRegExp()
    public func scanRegExp(): Unit {
        regexFlagsStart = -1
        while (true) {
            if (codePoint == 47) { // '/'
                step()
                // 扫描标志
                while (isIdentifierContinue(codePoint)) {
                    step()
                }
                break
            } else if (codePoint == 92) { // '\'
                step()
                step()
            } else if (codePoint == 91) { // '['
                // 字符类
                step()
                while (codePoint != 93 && codePoint != -1) { // ']'
                    if (codePoint == 92) { // '\'
                        step()
                    }
                    step()
                }
            } else if (codePoint == -1) {
                addError(start, "Unterminated regular expression")
                break
            } else {
                step()
            }
        }
        identifier = raw()
    }

    // ========================================================================
    // 期望和错误处理
    // 严格对应 Bun Lexer 的 expect/expected/unexpected
    // ========================================================================

    /// 期望特定 token - 对应 Bun expect()
    public func expect(t: Token): Unit {
        if (token != t) {
            expected(t)
        }
        nextToken()
    }

    /// 期望分号或自动插入 - 对应 Bun expectOrInsertSemicolon()
    public func expectOrInsertSemicolon(): Unit {
        if (token == Token.Semicolon || (!hasNewlineBefore &&
            token != Token.CloseBrace && token != Token.EndOfFile)) {
            expect(Token.Semicolon)
        }
    }

    /// 期望 '<' 或相关 token - 对应 Bun expectLessThan()
    /// 严格翻译自: src/js_parser/lexer.zig:1019-1045
    ///   pub fn expectLessThan(noalias lexer: *LexerType, comptime is_inside_jsx_element: bool) !void
    /// 支持: '<', '<=', '<<', '<<=' 的分解消费
    public func expectLessThan(isInsideJsxElement: Bool): Unit {
        match (token) {
            case Token.LessThan =>
                if (isInsideJsxElement) {
                    nextInsideJsxElement()
                } else {
                    nextToken()
                }
            case Token.LessThanEquals =>
                token = Token.Equals
                start += 1
                maybeExpandEquals()
            case Token.LessThanLessThan =>
                token = Token.LessThan
                start += 1
            case Token.LessThanLessThanEquals =>
                token = Token.LessThanEquals
                start += 1
            case _ =>
                expected(Token.LessThan)
        }
    }

    /// 期望 '>' 或相关 token - 对应 Bun expectGreaterThan()
    /// 严格翻译自: src/js_parser/lexer.zig:1047-1087
    ///   pub fn expectGreaterThan(noalias lexer: *LexerType, comptime is_inside_jsx_element: bool) !void
    /// 支持: '>', '>=', '>>', '>>=', '>>>', '>>>=' 的分解消费
    public func expectGreaterThan(isInsideJsxElement: Bool): Unit {
        match (token) {
            case Token.GreaterThan =>
                if (isInsideJsxElement) {
                    nextInsideJsxElement()
                } else {
                    nextToken()
                }
            case Token.GreaterThanEquals =>
                token = Token.Equals
                start += 1
                maybeExpandEquals()
            case Token.GreaterThanGreaterThanEquals =>
                token = Token.GreaterThanEquals
                start += 1
            case Token.GreaterThanGreaterThanGreaterThanEquals =>
                token = Token.GreaterThanGreaterThanEquals
                start += 1
            case Token.GreaterThanGreaterThan =>
                token = Token.GreaterThan
                start += 1
            case Token.GreaterThanGreaterThanGreaterThan =>
                token = Token.GreaterThanGreaterThan
                start += 1
            case _ =>
                expected(Token.GreaterThan)
        }
    }

    /// 等号后可能的扩展 - 对应 Bun maybeExpandEquals()
    /// 严格翻译自: src/js_parser/lexer.zig:997-1017
    ///   pub fn maybeExpandEquals(noalias lexer: *LexerType) !void
    /// '=' + '>' = '=>'
    /// '=' + '=' = '=='
    /// '=' + '==' = '==='
    public func maybeExpandEquals(): Unit {
        if (codePoint == 62) { // '>'
            token = Token.EqualsGreaterThan
            step()
        } else if (codePoint == 61) { // '='
            token = Token.EqualsEquals
            step()
            if (codePoint == 61) { // '='
                token = Token.EqualsEqualsEquals
                step()
            }
        }
    }

    /// 期望上下文关键字 - 对应 Bun expectContextualKeyword()
    /// 严格翻译自: src/js_parser/lexer.zig:981-995
    ///   pub fn expectContextualKeyword(noalias self: *LexerType, comptime keyword: string) !void
    public func expectContextualKeyword(keyword: String): Unit {
        if (!isContextualKeyword(keyword)) {
            addRangeError(range(), "Expected \"${keyword}\" but found \"${raw()}\"")
        }
        nextToken()
    }

    /// 重新扫描 '}' 作为模板 token - 对应 Bun rescanCloseBraceAsTemplateToken()
    /// 严格翻译自: src/js_parser/lexer.zig:2636-2649
    ///   pub fn rescanCloseBraceAsTemplateToken(lexer: *LexerType) !void
    /// 在模板字面量 ${expr} 的 } 之后调用，将 } 重新扫描为模板中间/尾部 token
    public func doRescanCloseBraceAsTemplateToken(): Unit {
        rescanCloseBraceAsTemplateToken = true
        step() // 消费 '}'
        scanTemplateContinuation()
        rescanCloseBraceAsTemplateToken = false
    }

    /// 获取原始模板内容 - 对应 Bun rawTemplateContents()
    /// 严格翻译自: src/js_parser/lexer.zig:2651-2701
    ///   pub fn rawTemplateContents(noalias lexer: *LexerType) string
    /// 返回模板字面量的原始文本内容（不含分隔符）
    public func rawTemplateContents(): String {
        // 根据 token 类型确定偏移
        var beginOffset: Int64 = 0
        var endOffset: Int64 = 0
        match (token) {
            case Token.NoSubstitutionTemplateLiteral =>
                beginOffset = 1
                endOffset = 1
            case Token.TemplateHead =>
                beginOffset = 1
                endOffset = 2 // "${"
            case Token.TemplateMiddle =>
                beginOffset = 1 // "}"
                endOffset = 2 // "${"
            case Token.TemplateTail =>
                beginOffset = 1 // "}"
                endOffset = 1
            case _ =>
                beginOffset = 0
                endOffset = 0
        }

        let b = start + beginOffset
        let e = if (end > endOffset) { end - endOffset } else { end }
        if (b >= e || b >= source.contents.size) {
            return ""
        }
        var sb = StringBuilder()
        for (i in b..e) {
            if (Int64(i) < source.contents.size) {
                sb.append(Rune(source.contents[Int64(i)]))
            }
        }
        return sb.toString()
    }

    /// 期望 token 错误 - 对应 Bun expected()
    public func expected(t: Token): Unit {
        if (isLogDisabled) {
            return
        }
        let name = t.toString()
        addRangeError(range(), "Expected ${name}")
    }

    /// 意外 token 错误 - 对应 Bun unexpected()
    public func unexpected(): Unit {
        var found: String = ""
        let s = if (start < end) { start } else { end }
        if (s >= source.contents.size) {
            found = "end of file"
        } else {
            found = raw()
        }
        didPanic = true
        addRangeError(range(), "Unexpected ${found}")
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 是否为空白字符 - 对应 Bun isWhitespace()
    public static func isWhitespace(c: Int64): Bool {
        return c == 9 || c == 11 || c == 12 || c == 32 || c == 160 ||
               c == 0x2028 || c == 0x2029 || c == 0xFEFF ||
               (c >= 0x2000 && c <= 0x200A) ||
               c == 10 || c == 13
    }

    /// 是否为标识符起始 - 对应 Bun isIdentifierStart()
    public static func isIdentifierStart(c: Int64): Bool {
        // 简化实现: ASCII 范围内检查
        return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 36
    }

    /// 是否为标识符继续 - 对应 Bun isIdentifierContinue()
    public static func isIdentifierContinue(c: Int64): Bool {
        // 简化实现: ASCII 范围内检查
        return isIdentifierStart(c) || (c >= 48 && c <= 57)
    }

    /// 是否为上下文关键字 - 对应 Bun isContextualKeyword()
    public func isContextualKeyword(keyword: String): Bool {
        return token == Token.Identifier && raw() == keyword
    }

    /// 添加错误
    public func addError(locStart: Int64, msg: String): Unit {
        if (isLogDisabled) { return }
        let errorLoc = Loc(locStart)
        if (errorLoc.eql(prevErrorLoc)) { return }
        log.addError(MsgData(msg, SourceLoc(source.path, 0, 0)))
        prevErrorLoc = errorLoc
    }

    /// 添加范围错误
    public func addRangeError(r: Range, msg: String): Unit {
        if (isLogDisabled) { return }
        if (r.loc.eql(prevErrorLoc)) { return }
        log.addError(MsgData(msg))
        prevErrorLoc = r.loc
    }

    /// 浮点数解析 - 对应 Bun std.fmt.parseFloat
    /// 支持: 整数、小数、指数 (e/E)、正负号、十六进制 (0x)
    private func parseFloat(text: String): Float64 {
        if (text.size == 0) {
            return 0.0
        }
        var result: Float64 = 0.0
        var sign: Float64 = 1.0
        var i: Int64 = 0
        let len = Int64(text.size)

        // 符号
        if (i < len && text[i] == UInt8(45)) { sign = -1.0; i++ }  // '-'
        else if (i < len && text[i] == UInt8(43)) { i++ }           // '+'

        // 十六进制
        if (i + 1 < len && text[i] == UInt8(48) &&
            (text[i + 1] == UInt8(120) || text[i + 1] == UInt8(88))) { // 'x'/'X'
            i += 2
            while (i < len) {
                let c = text[i]
                if (c >= UInt8(48) && c <= UInt8(57)) {        // '0'-'9'
                    result = result * 16.0 + Float64(c) - 48.0
                } else if (c >= UInt8(97) && c <= UInt8(102)) { // 'a'-'f'
                    result = result * 16.0 + Float64(c) - 87.0
                } else if (c >= UInt8(65) && c <= UInt8(70)) {  // 'A'-'F'
                    result = result * 16.0 + Float64(c) - 55.0
                } else {
                    break
                }
                i++
            }
            return result * sign
        }

        // 整数部分
        while (i < len && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
            result = result * 10.0 + Float64(text[i]) - 48.0
            i++
        }

        // 小数部分
        if (i < len && text[i] == UInt8(46)) { // '.'
            i++
            var frac: Float64 = 0.1
            while (i < len && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
                result += (Float64(text[i]) - 48.0) * frac
                frac *= 0.1
                i++
            }
        }

        // 指数部分
        if (i < len && (text[i] == UInt8(101) || text[i] == UInt8(69))) { // 'e'/'E'
            i++
            var expSign: Float64 = 1.0
            if (i < len && text[i] == UInt8(45)) { expSign = -1.0; i++ }
            else if (i < len && text[i] == UInt8(43)) { i++ }
            var exp: Float64 = 0.0
            while (i < len && text[i] >= UInt8(48) && text[i] <= UInt8(57)) {
                exp = exp * 10.0 + Float64(text[i]) - 48.0
                i++
            }
            // 快速整数幂
            var pow10: Float64 = 1.0
            var e = Int64(exp * expSign)
            if (e < 0) { while (e < 0) { pow10 *= 0.1; e++ } }
            else { while (e > 0) { pow10 *= 10.0; e-- } }
            result *= pow10
        }

        return result * sign
    }

    /// 向前看 n 个码点 - 对应 Bun peek()
    public func peek(n: Int64): String {
        let originalCurrent = current
        var endIx = originalCurrent
        var count: Int64 = 0
        while (count < n && endIx < source.contents.size) {
            let b = Int64(source.contents[endIx])
            let cpLen: Int64 = if (b < 0x80) { 1 }
                else if (b < 0xE0) { 2 }
                else if (b < 0xF0) { 3 }
                else { 4 }
            if (endIx + cpLen > source.contents.size) { break }
            endIx += cpLen
            count += 1
        }
        var sb = StringBuilder()
        for (i in originalCurrent..endIx) {
            sb.append(Rune(source.contents[Int64(i)]))
        }
        return sb.toString()
    }

    // ========================================================================
    // JSX 支持
    // 严格对应 Bun Lexer 的 JSX 相关方法
    //   nextInsideJSXElement, nextJSXElementChild, decodeJSXEntities
    //   expectJSXElementChild, expectInsideJSXElement, parseJSXStringLiteral
    //   fixWhitespaceAndDecodeJSXEntities, maybeDecodeJSXEntity, decodeJSXEntities
    // ========================================================================

    /// JSX 元素内部下一个 token - 对应 Bun nextInsideJSXElement()
    /// 严格翻译自: src/js_parser/lexer.zig:2177-2326
    ///   pub fn nextInsideJSXElement(noalias lexer: *LexerType) !void
    /// 在 JSX 元素内部，只识别有限的 token 类型:
    ///   标识符, 字符串, {, }, <, >, =, ., /, 注释, 空白
    public func nextInsideJsxElement(): Unit {
        hasNewlineBefore = false

        while (true) {
            start = end
            token = Token.EndOfFile

            if (codePoint == -1) {
                // EOF
                return
            }

            if (codePoint == 13 || codePoint == 10 || codePoint == 0x2028 || codePoint == 0x2029) {
                // 换行
                step()
                hasNewlineBefore = true
                continue
            }

            if (codePoint == 9 || codePoint == 32) {
                // 空白
                step()
                continue
            }

            if (codePoint == 46) { // '.'
                step()
                token = Token.Dot
                return
            }

            if (codePoint == 61) { // '='
                step()
                token = Token.Equals
                return
            }

            if (codePoint == 123) { // '{'
                step()
                token = Token.OpenBrace
                return
            }

            if (codePoint == 125) { // '}'
                step()
                token = Token.CloseBrace
                return
            }

            if (codePoint == 60) { // '<'
                step()
                token = Token.LessThan
                return
            }

            if (codePoint == 62) { // '>'
                step()
                token = Token.GreaterThan
                return
            }

            if (codePoint == 47) { // '/'
                step()
                if (codePoint == 47) { // '//'
                    // 单行注释
                    scanSingleLineComment()
                    scanCommentText(false)
                    continue
                } else if (codePoint == 42) { // '/*'
                    step()
                    scanMultiLineComment()
                    scanCommentText(true)
                    continue
                } else {
                    token = Token.Slash
                }
                return
            }

            if (codePoint == 39 || codePoint == 34) { // '\'' or '"'
                // JSX 字符串字面量
                parseJsxStringLiteral(codePoint)
                return
            }

            if (codePoint == 95 || codePoint == 36 ||
                (codePoint >= 97 && codePoint <= 122) ||
                (codePoint >= 65 && codePoint <= 90) ||
                codePoint >= 0x80) {
                // 标识符 (包括 Unicode 标识符)
                scanIdentifier()
                return
            }

            // 其他字符
            step()
            token = Token.SyntaxError
            return
        }
    }

    /// 解析 JSX 字符串字面量 - 对应 Bun parseJSXStringLiteral()
    /// 严格翻译自: src/js_parser/lexer.zig:2327-2397
    ///   pub fn parseJSXStringLiteral(lexer: *LexerType, comptime quote: u8) !void
    /// JSX 字符串属性值中的转义序列处理
    private func parseJsxStringLiteral(`quote`: Int64): Unit {
        token = Token.StringLiteral
        step()

        var needsDecode = false
        var backslash: Range = Range.NONE

        while (true) {
            if (codePoint == -1) {
                addError(start, "Unterminated string literal")
                break
            }

            if (codePoint == `quote`) {
                step()
                break
            }

            if (codePoint == 92) { // '\'
                // 反斜杠转义
                needsDecode = true
                step()
                if (codePoint == 13) { // '\r'
                    // CRLF 处理
                    step()
                    if (codePoint == 10) { // '\n'
                        step()
                    }
                    continue
                }
                // 消费转义字符
                step()
                continue
            }

            if (codePoint == 13 || codePoint == 10 || codePoint == 0x2028 || codePoint == 0x2029) {
                // JSX 字符串中不允许换行
                addError(start, "Unterminated string literal")
                break
            }

            if (codePoint >= 0x80) {
                needsDecode = true
            }

            step()
        }

        // 设置原始内容
        if (start + 1 < end - 1) {
            stringLiteralRawContent = raw()
            stringLiteralStart = start
            stringLiteralRawFormat = if (needsDecode) {
                StringLiteralFormat.NeedsDecode
            } else {
                StringLiteralFormat.Ascii
            }
        } else {
            stringLiteralRawContent = ""
            stringLiteralStart = start
            stringLiteralRawFormat = StringLiteralFormat.Ascii
        }
    }

    /// JSX 元素子元素期望 - 对应 Bun expectJSXElementChild()
    /// 严格翻译自: src/js_parser/lexer.zig:2399-2407
    ///   pub fn expectJSXElementChild(noalias lexer: *LexerType, token: T) !void
    public func expectJsxElementChild(t: Token): Unit {
        if (token != t) {
            expected(t)
        }
        nextJsxElementChild()
    }

    /// JSX 子元素下一个 token - 对应 Bun nextJSXElementChild()
    /// 严格翻译自: src/js_parser/lexer.zig:2409-2478
    ///   pub fn nextJSXElementChild(lexer: *LexerType) !void
    /// 在 JSX 子元素中:
    ///   '{' -> OpenBrace (开始表达式)
    ///   '<' -> LessThan (开始新元素)
    ///   其他 -> StringLiteral (文本内容)
    public func nextJsxElementChild(): Unit {
        hasNewlineBefore = false
        let originalStart = end

        while (true) {
            start = end
            token = Token.EndOfFile

            if (codePoint == -1) {
                // EOF
                return
            }

            if (codePoint == 123) { // '{'
                step()
                token = Token.OpenBrace
                return
            }

            if (codePoint == 60) { // '<'
                step()
                token = Token.LessThan
                return
            }

            // 文本内容 - 扫描直到遇到 '{', '<', 或 EOF
            var needsFixing = false

            while (true) {
                if (codePoint == -1) {
                    addError(start, "Unexpected end of file in JSX")
                    break
                }
                if (codePoint == 38) { // '&' - JSX 实体
                    needsFixing = true
                    step()
                    continue
                }
                if (codePoint == 13 || codePoint == 10 ||
                    codePoint == 0x2028 || codePoint == 0x2029) {
                    needsFixing = true
                    step()
                    continue
                }
                if (codePoint == 123 || codePoint == 60) { // '{' or '<'
                    break
                }
                if (codePoint >= 0x80) {
                    needsFixing = true
                }
                step()
            }

            token = Token.StringLiteral

            // 设置原始内容
            if (originalStart < end) {
                var sb = StringBuilder()
                for (i in originalStart..end) {
                    sb.append(Rune(source.contents[Int64(i)]))
                }
                stringLiteralRawContent = sb.toString()
            } else {
                stringLiteralRawContent = ""
            }
            stringLiteralStart = start
            stringLiteralRawFormat = if (needsFixing) {
                StringLiteralFormat.NeedsDecode
            } else {
                StringLiteralFormat.Ascii
            }

            // 跳过空内容
            if (stringLiteralRawContent.size == 0 && needsFixing) {
                hasNewlineBefore = true
                continue
            }

            return
        }
    }

    /// JSX 元素内部期望 token - 对应 Bun expectInsideJSXElement()
    /// 严格翻译自: src/js_parser/lexer.zig:2593-2603
    ///   pub fn expectInsideJSXElement(noalias lexer: *LexerType, token: T) !void
    public func expectInsideJsxElement(t: Token): Unit {
        if (token != t) {
            expected(t)
        }
        nextInsideJsxElement()
    }

    /// JSX 元素内部期望 token (带名称) - 对应 Bun expectInsideJSXElementWithName()
    /// 严格翻译自: src/js_parser/lexer.zig:2604-2614
    public func expectInsideJsxElementWithName(t: Token, name: String): Unit {
        if (token != t) {
            expected(t)
        }
        nextInsideJsxElement()
    }

    /// 解码 JSX 实体 - 对应 Bun decodeJSXEntities()
    /// 严格翻译自: src/js_parser/lexer.zig:2565-2592
    ///   pub fn decodeJSXEntities(lexer: *LexerType, text: string, out: *std.array_list.Managed(u16)) !void
    /// 将 JSX 文本中的 HTML 实体引用 (&amp; etc.) 解码为 Unicode 码点
    public func decodeJsxEntities(text: String): String {
        var result = StringBuilder()
        var i: Int64 = 0
        while (i < text.size) {
            let c = Int64(text[Int64(i)])
            if (c == 38) { // '&'
                // 尝试解码实体
                let decoded = tryDecodeJsxEntity(text, i)
                if (decoded.codePoint >= 0) {
                    result.append(Rune(decoded.codePoint))
                    i = decoded.nextIndex
                    continue
                }
            }
            result.append(Rune(c))
            i += 1
        }
        return result.toString()
    }

    /// 尝试解码 JSX 实体 - 对应 Bun maybeDecodeJSXEntity()
    /// 严格翻译自: src/js_parser/lexer.zig:2529-2563
    private func tryDecodeJsxEntity(text: String, startPos: Int64): JsxEntityResult {
        // 查找 ';' 终止符
        var semiPos: Int64 = startPos + 1
        while (semiPos < text.size) {
            if (Int64(text[Int64(semiPos)]) == 59) { // ';'
                break
            }
            semiPos += 1
        }
        if (semiPos >= text.size || Int64(text[Int64(semiPos)]) != 59) {
            return JsxEntityResult(-1, startPos + 1)
        }

        let entity = text[Int64(startPos + 1)..Int64(semiPos)]
        if (entity.size == 0) {
            return JsxEntityResult(-1, startPos + 1)
        }

        // 数字实体: &#123; 或 &#x1F;
        if (Int64(entity[Int64(0)]) == 35) { // '#'
            var number = entity[1..]
            var base: Int64 = 10
            if (number.size > 1 && Int64(number[Int64(0)]) == 120) { // 'x'
                number = number[1..]
                base = 16
            }
            var value: Int64 = 0
            var valid = true
            for (c in number) {
                let d = decodeHexDigit(Int64(c))
                if (base == 16 || (Int64(c) >= 48 && Int64(c) <= 57)) {
                    value = value * base + d
                } else {
                    valid = false
                    break
                }
            }
            if (valid && value > 0 && value <= 0x10FFFF) {
                return JsxEntityResult(value, semiPos + 1)
            }
            return JsxEntityResult(-1, startPos + 1)
        }

        // 命名实体: 从查找表获取
        let cp = JsxEntityMap.getJsxEntity(entity)
        if (cp >= 0) {
            return JsxEntityResult(cp, semiPos + 1)
        }
        return JsxEntityResult(-1, startPos + 1)
    }

    // ========================================================================
    // 模板字面量支持
    // ========================================================================

    /// 扫描模板字面量续接部分 - 在 ${expr} 的 } 之后调用
    /// 从当前 lexer 位置扫描模板尾部文本，设置 token 为 TemplateMiddle 或 TemplateTail
    /// 对应 Bun: rescanCloseBraceAsTemplateToken + next()
    public func scanTemplateContinuation(): Unit {
        // 此时 lexer 已经消费了 }，current 指向 } 后面的字符
        // 需要扫描从 } 后面到下一个 ${ 或 ` 之间的文本
        var content = StringBuilder()
        token = Token.TemplateTail // 默认 Tail，如果遇到 ${ 则改为 Middle

        while (true) {
            if (codePoint == -1) {
                addError(start, "Unterminated template literal")
                break
            }
            if (codePoint == 96) { // '`' — 模板结束
                step()
                break
            }
            if (codePoint == 92) { // '\' — 转义
                step()
                let escaped = decodeEscape(codePoint)
                if (escaped >= 0) {
                    content.append(Rune(escaped))
                }
                step()
                continue
            }
            if (codePoint == 36) { // '$' — 可能是 ${
                if (current < source.contents.size && source.contents[current] == UInt8(123)) { // '{'
                    step() // 跳过 '$'
                    step() // 跳过 '{'
                    token = Token.TemplateMiddle
                    break
                }
            }
            content.append(Rune(codePoint))
            step()
        }

        stringLiteralRawContent = content.toString()
        stringLiteralStart = start
        stringLiteralRawFormat = StringLiteralFormat.Ascii
    }

    /// 恢复词法分析器状态 - 对应 Bun restore()
    public func restore(original: Lexer): Unit {
        // 保留 buffer 引用
        let myComments = allComments
        let myPreserve = commentsToPreserveBefore

        // 复制状态
        current = original.current
        start = original.start
        end = original.end
        token = original.token
        codePoint = original.codePoint
        hasNewlineBefore = original.hasNewlineBefore
        hasPureCommentBefore = original.hasPureCommentBefore
        hasNoSideEffectCommentBefore = original.hasNoSideEffectCommentBefore
        didPanic = original.didPanic
        identifier = original.identifier
        number = original.number
        isLegacyOctalLiteral = original.isLegacyOctalLiteral

        // 恢复 buffer
        allComments = myComments
        commentsToPreserveBefore = myPreserve
    }
}

/// JSX 实体解码结果 (moved out of Lexer class due to Cangjie restriction)
class JsxEntityResult {
    public var codePoint: Int64
    public var nextIndex: Int64
    public init(cp: Int64, next: Int64) {
        codePoint = cp
        nextIndex = next
    }
}
