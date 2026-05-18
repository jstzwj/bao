// 严格翻译自: src/parsers/json_lexer.rs
//   JSON 词法分析器 - JSON-only subset of js_lexer
//   从 src/js_parser/lexer.zig 中提取 is_json=true 分支
//   支持: JSON tokens, 字符串字面量, 数字字面量, 标识符 (true/false/null)
//   不支持: JS 运算符, JSX, 正则, 模板字符串, bigint, 私有标识符
//
// 注意: package.cj 中已有 BaseParser (通用解析器基类)
// 本文件提供 JSON 专用的词法分析器实现
package bao_parsers

import bao_core.*
import bao_collections.*

// ============================================================================
// JSONLexerOptions - JSON 词法分析器选项
// 严格翻译自: src/parsers/json_lexer.rs - JSONOptions
//   pub struct JSONOptions {
//       pub is_json: bool,
//       pub allow_comments: bool,
//       pub allow_trailing_commas: bool,
//       pub ignore_leading_escape_sequences: bool,
//       pub ignore_trailing_escape_sequences: bool,
//       pub json_warn_duplicate_keys: bool,
//       pub was_originally_macro: bool,
//       pub guess_indentation: bool,
//   }
// ============================================================================

/// JSON 词法分析器选项 - 对应 Bun JSONOptions
public class JSONLexerOptions {
    /// 是否为 JSON 模式
    public var isJson: Bool
    /// 允许注释 (tsconfig.json 等)
    public var allowComments: Bool
    /// 允许尾逗号
    public var allowTrailingCommas: Bool
    /// 忽略前导转义序列 (.env JSON-in-JSON)
    public var ignoreLeadingEscapeSequences: Bool
    /// 忽略尾随转义序列
    public var ignoreTrailingEscapeSequences: Bool
    /// 警告重复键
    public var jsonWarnDuplicateKeys: Bool
    /// 是否源自宏
    public var wasOriginallyMacro: Bool
    /// 猜测缩进
    public var guessIndentation: Bool

    public init() {
        isJson = true
        allowComments = false
        allowTrailingCommas = false
        ignoreLeadingEscapeSequences = false
        ignoreTrailingEscapeSequences = false
        jsonWarnDuplicateKeys = true
        wasOriginallyMacro = false
        guessIndentation = false
    }

    public static func defaults(): JSONLexerOptions {
        JSONLexerOptions()
    }
}

// ============================================================================
// JSONToken - JSON token 类型
// 严格翻译自: src/parsers/json_lexer.rs - T enum
//   pub enum T {
//       TEndOfFile, TSyntaxError,
//       TOpenBrace, TCloseBrace, TOpenBracket, TCloseBracket,
//       TComma, TColon, TMinus,
//       TTrue, TFalse, TNull,
//       TStringLiteral, TNumericLiteral, TIdentifier,
//   }
// ============================================================================

/// JSON token 类型 - 对应 Bun T (JSON subset)
public enum JSONToken {
    | EndOfFile
    | SyntaxError
    | OpenBrace      // {
    | CloseBrace     // }
    | OpenBracket    // [
    | CloseBracket   // ]
    | Comma          // ,
    | Colon          // :
    | Minus          // -
    | True           // true
    | False          // false
    | Null           // null
    | StringLiteral  // "..."
    | NumericLiteral // 123, 1.5, 0xFF
    | Identifier     // 其他标识符

    /// 转为字符串表示 - 对应 Bun T.to_str
    public func toStr(): String {
        match (this) {
            case EndOfFile => "end of file"
            case OpenBrace => "\"{\""
            case CloseBrace => "\"}\""
            case OpenBracket => "\"[\""
            case CloseBracket => "\"]\""
            case Comma => "\",\""
            case Colon => "\":\""
            case Minus => "\"-\""
            case True => "\"true\""
            case False => "\"false\""
            case Null => "\"null\""
            case StringLiteral => "string"
            case NumericLiteral => "number"
            case Identifier => "identifier"
            case SyntaxError => ""
        }
    }
}

// ============================================================================
// StringLiteralFormat - 字符串字面量编码格式
// 严格翻译自: src/parsers/json_lexer.rs - StringLiteralFormat
//   enum StringLiteralFormat { Ascii, Utf16, NeedsDecode }
// ============================================================================

/// 字符串编码格式
enum StringLiteralFormat {
    | Ascii       // 纯 ASCII
    | Utf16       // UTF-16 编码
    | NeedsDecode // 需要解码转义
}

// ============================================================================
// JSONLexer - JSON 词法分析器
// 严格翻译自: src/parsers/json_lexer.rs - Lexer struct
//   pub struct Lexer<'a, 'bump> {
//       log: *mut Log,
//       source: &'a Source,
//       current: usize, start: usize, end: usize,
//       approximate_newline_count: usize,
//       token: T,
//       has_newline_before: bool,
//       code_point: CodePoint,
//       identifier: &'a [u8],
//       number: f64,
//       string_literal_raw_content: &'a [u8],
//       is_ascii_only: bool,
//       opts: JSONOptions,
//   }
//
// Lexer 逐字符扫描 JSON 输入，产出 token 序列
// 是 JSON 解析器的底层驱动
// ============================================================================

/// JSON 词法分析器 - 对应 Bun Lexer (JSON subset)
/// 从 JSON 文本中扫描出 token 序列
public class JSONLexer {
    /// 输入源文本
    public var source: String
    /// 当前位置
    public var current: Int64
    /// token 起始位置
    public var start: Int64
    /// token 结束位置
    public var end: Int64
    /// 当前 token
    public var token: JSONToken
    /// 当前代码点
    public var codePoint: Int32
    /// 当前行前是否有换行
    public var hasNewlineBefore: Bool
    /// 当前标识符文本
    public var identifier: String
    /// 当前数字值
    public var number: Float64
    /// 是否仅 ASCII
    public var isAsciiOnly: Bool
    /// 分析器选项
    public var opts: JSONLexerOptions
    /// 错误列表
    public var errors: ArrayList<String>
    /// 是否已 panic
    public var didPanic: Bool
    /// 字符串字面量原始内容
    private var stringLiteralRawContent: String
    /// 字符串字面量格式
    private var stringLiteralFormat: StringLiteralFormat

    /// 从字符串构造 - 对应 Bun Lexer::init
    public init(source: String) {
        this.source = source
        current = 0
        start = 0
        end = 0
        token = JSONToken.EndOfFile
        codePoint = Int32(-1)
        hasNewlineBefore = false
        identifier = ""
        number = Float64(0)
        isAsciiOnly = true
        opts = JSONLexerOptions.defaults()
        errors = ArrayList<String>()
        didPanic = false
        stringLiteralRawContent = ""
        stringLiteralFormat = StringLiteralFormat.Ascii
    }

    /// 从字符串和选项构造 - 对应 Bun Lexer::init with opts
    public init(source: String, opts: JSONLexerOptions) {
        this.source = source
        current = 0
        start = 0
        end = 0
        token = JSONToken.EndOfFile
        codePoint = Int32(-1)
        hasNewlineBefore = false
        identifier = ""
        number = Float64(0)
        isAsciiOnly = true
        this.opts = opts
        errors = ArrayList<String>()
        didPanic = false
        stringLiteralRawContent = ""
        stringLiteralFormat = StringLiteralFormat.Ascii
    }

    /// 初始化并读取第一个 token
    /// 对应 Bun Lexer::init_json
    ///   pub fn init_json(log, source, bump, opts) -> Result<Self> {
    ///       let mut lex = Self::init_without_reading(...);
    ///       lex.step();
    ///       lex.next()?;
    ///       Ok(lex)
    ///   }
    public func initAndScan(): Unit {
        step()
        next()
    }

    // ── positioning ─────────────────────────────────────────────────────────

    /// 获取当前位置信息 - 对应 Bun Lexer::loc
    public func loc(): Int64 {
        start
    }

    /// 获取范围 - 对应 Bun Lexer::range
    public func range(): Range<Int64> {
        Range<Int64>(start, end - start)
    }

    /// 获取原始文本 - 对应 Bun Lexer::raw
    public func raw(): String {
        if (start >= 0 && end <= source.size && start <= end) {
            source[start..end]
        } else {
            ""
        }
    }

    // ── stepping ────────────────────────────────────────────────────────────

    /// 前进到下一个代码点 - 对应 Bun Lexer::next_codepoint
    ///   fn next_codepoint(&mut self) -> CodePoint {
    ///       strings::lexer_step::next_codepoint(&self.source.contents, &mut self.current, &mut self.end)
    ///   }
    private func nextCodepoint(): Int32 {
        if (current >= source.size) {
            return Int32(-1)
        }
        let ch = source[current]
        end = current
        current += 1
        // UTF-8 多字节处理
        if (ch >= UInt8(0xF0)) {
            // 4 字节
            if (current + 2 < source.size) {
                current += 3
            }
        } else if (ch >= UInt8(0xE0)) {
            // 3 字节
            if (current + 1 < source.size) {
                current += 2
            }
        } else if (ch >= UInt8(0xC0)) {
            // 2 字节
            if (current < source.size) {
                current += 1
            }
        }
        Int32(ch)
    }

    /// 步进一个代码点 - 对应 Bun Lexer::step
    ///   fn step(&mut self) {
    ///       self.code_point = self.next_codepoint();
    ///   }
    public func step(): Unit {
        codePoint = nextCodepoint()
    }

    // ── error reporting ─────────────────────────────────────────────────────

    /// 添加语法错误 - 对应 Bun Lexer::add_syntax_error
    private func addSyntaxError(msg: String): Unit {
        errors.append(msg)
        didPanic = true
    }

    /// 添加不支持语法错误 - 对应 Bun Lexer::add_unsupported_syntax_error
    private func addUnsupportedSyntaxError(msg: String): Unit {
        errors.append("Unsupported syntax: ${msg}")
        didPanic = true
    }

    /// 语法错误 - 对应 Bun cold syntax_error
    private func syntaxError(): Unit {
        addSyntaxError("SyntaxError")
    }

    // ── expect / unexpected ─────────────────────────────────────────────────

    /// 期望指定 token - 对应 Bun Lexer::expect
    ///   pub fn expect(&mut self, token: T) -> Result<()> {
    ///       if self.token != token { self.expected(token)?; }
    ///       self.next()
    ///   }
    public func expect(token: JSONToken): Bool {
        if (this.token != token) {
            expected(token)
            return false
        }
        next()
        return !didPanic
    }

    /// 报告期望的 token - 对应 Bun Lexer::expected
    private func expected(token: JSONToken): Unit {
        let name = token.toStr()
        if (!name.isEmpty()) {
            expectedString(name)
        } else {
            unexpected()
        }
    }

    /// 报告期望字符串 - 对应 Bun Lexer::expected_string
    private func expectedString(text: String): Unit {
        let r = raw()
        if (start < source.size) {
            errors.append("Expected ${text} but found \"${r}\"")
        } else {
            errors.append("Expected ${text} but found end of file")
        }
    }

    /// 报告意外 token - 对应 Bun Lexer::unexpected
    public func unexpected(): Unit {
        if (start >= source.size) {
            didPanic = true
            errors.append("Unexpected end of file")
        } else {
            let r = raw()
            didPanic = true
            errors.append("Unexpected ${r}")
        }
    }

    // ── string literal ──────────────────────────────────────────────────────

    /// 解析字符串字面量 - 对应 Bun Lexer::parse_string_literal
    ///   pub fn parse_string_literal(&mut self, quote: CodePoint) -> LexResult
    public func parseStringLiteral(quote: Int32): Unit {
        parseStringLiteralInner(quote)
    }

    /// 解析字符串字面量内部实现
    /// 对应 Bun Lexer::parse_string_literal_inner<const QUOTE: u8>
    ///   支持: 双引号、单引号、转义序列 (\n, \r, \t, \b, \f, \\, \", \/, \uXXXX, \xXX)
    ///   不支持: 模板字面量 (JS-only)
    private func parseStringLiteralInner(quote: Int32): Unit {
        token = JSONToken.StringLiteral
        step() // consume opening quote

        var needsDecode = false
        val sb = StringBuilder()

        while (true) {
            if (codePoint == Int32(-1)) {
                // EOF
                errors.append("Unterminated string literal")
                break
            }
            if (codePoint == Int32(0x5C)) {
                // backslash \\
                needsDecode = true
                step()
                if (codePoint == Int32(-1)) {
                    errors.append("Unterminated string escape")
                    break
                }
                match (codePoint) {
                    case Int32(0x22) => sb.append(UInt8(0x22))  // "
                    case Int32(0x5C) => sb.append(UInt8(0x5C))  // backslash
                    case Int32(0x2F) => sb.append(UInt8(0x2F))  // /
                    case Int32(0x62) => sb.append(UInt8(0x08))  // \b
                    case Int32(0x66) => sb.append(UInt8(0x0C))  // \f
                    case Int32(0x6E) => sb.append(UInt8(0x0A))  // \n
                    case Int32(0x72) => sb.append(UInt8(0x0D))  // \r
                    case Int32(0x74) => sb.append(UInt8(0x09))  // \t
                    case Int32(0x76) => sb.append(UInt8(0x0B))  // \v
                    case Int32(0x75) =>
                        // \uXXXX Unicode 转义
                        decodeUnicodeEscape(sb)
                    case Int32(0x78) =>
                        // \xXX 十六进制转义
                        decodeHexEscape(sb)
                    case _ =>
                        // 其他转义字符原样保留
                        if (codePoint >= 0) {
                            sb.append(UInt8(codePoint))
                        }
                }
                step()
                continue
            }
            if (codePoint == quote) {
                step() // consume closing quote
                break
            }
            if (codePoint == Int32(0x0D)) {
                // \r - 不允许在字符串中
                errors.append("Unterminated string literal")
                step()
                break
            }
            if (codePoint == Int32(0x0A)) {
                // \n - 不允许在字符串中 (JSON strict)
                errors.append("Unterminated string literal")
                step()
                break
            }
            if (codePoint >= Int32(0x80)) {
                // 非 ASCII 需要慢路径
                needsDecode = true
            } else if (codePoint < Int32(0x20)) {
                // 控制字符不允许
                syntaxError()
                break
            }
            // 普通字符
            if (codePoint >= 0) {
                sb.append(UInt8(codePoint))
            }
            step()
        }

        stringLiteralRawContent = sb.toString()
        stringLiteralFormat = if (needsDecode) {
            StringLiteralFormat.NeedsDecode
        } else {
            StringLiteralFormat.Ascii
        }
        isAsciiOnly = isAsciiOnly && !needsDecode
    }

    /// 解码 \uXXXX Unicode 转义 - 对应 Bun decode_escape_sequences 中的 \u 分支
    private func decodeUnicodeEscape(sb: StringBuilder): Unit {
        step() // consume 'u'
        var value: Int32 = 0
        var count: Int64 = 0
        while (count < 4 && codePoint != Int32(-1)) {
            let digit = hexDigitValue(codePoint)
            if (digit < 0) {
                syntaxError()
                return
            }
            value = value * Int32(16) + digit
            step()
            count += 1
        }
        // 简化: 只处理 BMP
        if (value > 0 && value < 0x10000) {
            sb.append(String(Rune(value)))
        } else if (value >= 0x10000) {
            // 代理对 (简化处理)
            sb.append(String(Rune(value)))
        }
    }

    /// 解码 \xXX 十六进制转义
    private func decodeHexEscape(sb: StringBuilder): Unit {
        step() // consume 'x'
        var value: Int32 = 0
        var count: Int64 = 0
        while (count < 2 && codePoint != Int32(-1)) {
            let digit = hexDigitValue(codePoint)
            if (digit < 0) {
                syntaxError()
                return
            }
            value = value * Int32(16) + digit
            step()
            count += 1
        }
        if (value >= 0 && value < 256) {
            sb.append(UInt8(value))
        }
    }

    /// 十六进制数字值 - 对应 Bun hex_digit_value_u32
    private static func hexDigitValue(cp: Int32): Int32 {
        if (cp >= Int32(48) && cp <= Int32(57)) {
            return cp - Int32(48)  // '0'-'9'
        }
        if (cp >= Int32(65) && cp <= Int32(70)) {
            return cp - Int32(65) + Int32(10)  // 'A'-'F'
        }
        if (cp >= Int32(97) && cp <= Int32(102)) {
            return cp - Int32(97) + Int32(10)  // 'a'-'f'
        }
        return Int32(-1)
    }

    /// 获取解析后的字符串值
    public func getStringValue(): String {
        stringLiteralRawContent
    }

    // ── numeric literal ─────────────────────────────────────────────────────

    /// 解析数字字面量或点号 - 对应 Bun Lexer::parse_numeric_literal_or_dot
    ///   fn parse_numeric_literal_or_dot(&mut self) -> LexResult {
    ///       let first = self.code_point;
    ///       self.step();
    ///       // Check dot without digit
    ///       // Parse integer/floating-point
    ///       // Handle binary/octal/hex (0b, 0o, 0x)
    ///       // Handle underscores
    ///       // Handle exponent
    ///   }
    private func parseNumericLiteralOrDot(): Unit {
        let first = codePoint
        step()

        // 单独的点号后面没有数字
        if (first == Int32(46) && (codePoint < Int32(48) || codePoint > Int32(57))) {
            syntaxError()
            return
        }

        token = JSONToken.NumericLiteral
        var hasDotOrExponent = first == Int32(46)
        var base: Float64 = Float64(0)
        var isLegacyOctal = false

        // 检查二进制/八进制/十六进制前缀
        if (first == Int32(48)) {
            if (codePoint == Int32(98) || codePoint == Int32(66)) {
                base = Float64(2)
            } else if (codePoint == Int32(111) || codePoint == Int32(79)) {
                base = Float64(8)
            } else if (codePoint == Int32(120) || codePoint == Int32(88)) {
                base = Float64(16)
            } else if ((codePoint >= Int32(48) && codePoint <= Int32(55)) || codePoint == Int32(95)) {
                base = Float64(8)
                isLegacyOctal = true
            }
        }

        if (base != Float64(0)) {
            // 整数字面量 (二进制/八进制/十六进制)
            if (!isLegacyOctal) {
                step() // consume prefix character
            }
            var value: Float64 = Float64(0)
            var isFirst = true
            while (true) {
                if (codePoint == Int32(95)) {
                    // underscore
                    step()
                    continue
                }
                var digit: Float64 = Float64(-1)
                if (codePoint >= Int32(48) && codePoint <= Int32(57)) {
                    digit = Float64(codePoint - Int32(48))
                } else if (codePoint >= Int32(65) && codePoint <= Int32(70)) {
                    digit = Float64(codePoint - Int32(65) + 10)
                } else if (codePoint >= Int32(97) && codePoint <= Int32(102)) {
                    digit = Float64(codePoint - Int32(97) + 10)
                }
                if (digit < Float64(0)) {
                    if (isFirst) {
                        syntaxError()
                    }
                    break
                }
                // 检查基数有效性
                if (base == Float64(2) && digit >= Float64(2)) {
                    syntaxError()
                    break
                }
                if ((base == Float64(8) || base == Float64(2)) &&
                    (digit >= Float64(8))) {
                    if (!isLegacyOctal) {
                        syntaxError()
                        break
                    }
                }
                if (base != Float64(16) && digit >= Float64(10) && base < Float64(10)) {
                    syntaxError()
                    break
                }
                value = value * base + digit
                step()
                isFirst = false
            }
            number = value
        } else {
            // 浮点数字面量
            // 初始数字
            while (codePoint >= Int32(48) && codePoint <= Int32(57) || codePoint == Int32(95)) {
                if (codePoint == Int32(95)) {
                    step()
                    continue
                }
                step()
            }

            // 小数部分
            if (first != Int32(46) && codePoint == Int32(46)) {
                hasDotOrExponent = true
                step()
                while (codePoint >= Int32(48) && codePoint <= Int32(57) || codePoint == Int32(95)) {
                    if (codePoint == Int32(95)) {
                        step()
                        continue
                    }
                    step()
                }
            }

            // 指数部分
            if (codePoint == Int32(101) || codePoint == Int32(69)) {
                hasDotOrExponent = true
                step()
                if (codePoint == Int32(43) || codePoint == Int32(45)) {
                    step()
                }
                if (codePoint < Int32(48) || codePoint > Int32(57)) {
                    syntaxError()
                    return
                }
                while (codePoint >= Int32(48) && codePoint <= Int32(57) || codePoint == Int32(95)) {
                    if (codePoint == Int32(95)) {
                        step()
                        continue
                    }
                    step()
                }
            }

            // 解析数字
            let text = raw()
            // 过滤下划线
            var filtered = ""
            for (i in 0..text.size) {
                if (text[i] != UInt8(95)) {
                    filtered = filtered + String.fromUtf8(Array<Byte>(1, repeat: text[i]))
                }
            }
            if (filtered.isEmpty()) {
                filtered = "0"
            }
            let num = try { Float64.parse(filtered) } catch (_: Exception) {
                addSyntaxError("Invalid number")
                return
            }
            number = num
        }

        // bigint 标识符检查 (JSON 不支持)
        if (isIdentifierStart(codePoint)) {
            syntaxError()
        }
    }

    // ── identifier scanning ─────────────────────────────────────────────────

    /// 扫描带转义的标识符 - 对应 Bun Lexer::scan_identifier_with_escapes
    ///   fn scan_identifier_with_escapes(&mut self) -> LexResult {
    ///       // 第一遍: 扫描标识符长度
    ///       // 第二遍: 解码转义序列
    ///       // 映射 true/false/null
    ///   }
    private func scanIdentifierWithEscapes(): Unit {
        val sb = StringBuilder()
        while (true) {
            if (codePoint == Int32(0x5C)) {
                // backslash
                step()
                if (codePoint == Int32(0x75)) {
                    // \uXXXX
                    step()
                    if (codePoint == Int32(123)) {
                        // \u{...} 变长
                        step()
                        while (codePoint != Int32(125) && codePoint != Int32(-1)) {
                            if (isHexCodePoint(codePoint)) {
                                sb.append(UInt8(codePoint))
                            }
                            step()
                        }
                        if (codePoint == Int32(125)) { step() }
                    } else {
                        // 固定 4 位
                        var count: Int64 = 0
                        while (count < 4 && isHexCodePoint(codePoint)) {
                            sb.append(UInt8(codePoint))
                            step()
                            count += 1
                        }
                    }
                    continue
                }
                syntaxError()
                return
            }
            if (!isIdentifierContinue(codePoint)) {
                break
            }
            sb.append(UInt8(codePoint))
            step()
        }

        identifier = sb.toString()
        token = match (identifier) {
            case "true" => JSONToken.True
            case "false" => JSONToken.False
            case "null" => JSONToken.Null
            case _ => JSONToken.Identifier
        }
    }

    // ── next - 主扫描循环 ────────────────────────────────────────────────────

    /// 扫描下一个 token - 对应 Bun Lexer::next
    ///   pub fn next(&mut self) -> LexResult {
    ///       self.has_newline_before = self.end == 0;
    ///       loop {
    ///           self.start = self.end;
    ///           self.token = T::TEndOfFile;
    ///           match self.code_point {
    ///               -1 => { self.token = T::TEndOfFile; }
    ///               '\r' | '\n' | 0x2028 | 0x2029 => { ... continue }
    ///               '\t' | ' ' => { ... continue }
    ///               '[' => { ... TOpenBracket }
    ///               ']' => { ... TCloseBracket }
    ///               '{' => { ... TOpenBrace }
    ///               '}' => { ... TCloseBrace }
    ///               ',' => { ... TComma }
    ///               ':' => { ... TColon }
    ///               '-' => { ... TMinus }
    ///               '/' => { /* comments */ }
    ///               '\'' | '"' => { parse_string_literal }
    ///               '\\' => { scan_identifier_with_escapes }
    ///               '.' | '0'..'9' => { parse_numeric_literal_or_dot }
    ///               '_' | '$' | 'a'..'z' | 'A'..'Z' => { identifier }
    ///               _ => { TSyntaxError }
    ///           }
    ///           return Ok(())
    ///       }
    ///   }
    public func next(): Unit {
        hasNewlineBefore = (end == 0)

        while (true) {
            start = end
            token = JSONToken.EndOfFile

            if (codePoint == Int32(-1)) {
                token = JSONToken.EndOfFile
                return
            }

            // 换行
            if (codePoint == Int32(0x0D) || codePoint == Int32(0x0A) ||
                codePoint == Int32(0x2028) || codePoint == Int32(0x2029)) {
                hasNewlineBefore = true
                step()
                continue
            }

            // 空白
            if (codePoint == Int32(0x09) || codePoint == Int32(0x20)) {
                step()
                continue
            }

            // 不常见空白
            if (isWhitespace(codePoint)) {
                step()
                continue
            }

            match (codePoint) {
                case Int32(91) =>
                    // [
                    step()
                    token = JSONToken.OpenBracket
                case Int32(93) =>
                    // ]
                    step()
                    token = JSONToken.CloseBracket
                case Int32(123) =>
                    // {
                    step()
                    token = JSONToken.OpenBrace
                case Int32(125) =>
                    // }
                    step()
                    token = JSONToken.CloseBrace
                case Int32(44) =>
                    // ,
                    step()
                    token = JSONToken.Comma
                case Int32(58) =>
                    // :
                    step()
                    token = JSONToken.Colon
                case Int32(45) =>
                    // -
                    step()
                    if (codePoint == Int32(61) || codePoint == Int32(45)) {
                        addUnsupportedSyntaxError("Operators are not allowed in JSON")
                        return
                    }
                    token = JSONToken.Minus
                case Int32(47) =>
                    // 注释 (// 或 /* */)
                    step()
                    if (codePoint == Int32(47)) {
                        // 行注释 //
                        while (codePoint != Int32(0x0D) && codePoint != Int32(0x0A) &&
                            codePoint != Int32(-1)) {
                            step()
                        }
                        if (!opts.allowComments) {
                            errors.append("JSON does not support comments")
                        }
                        continue
                    } else if (codePoint == Int32(42)) {
                        // 块注释 /* ... */
                        step()
                        while (true) {
                            if (codePoint == Int32(42)) {
                                step()
                                if (codePoint == Int32(47)) {
                                    step()
                                    break
                                }
                            } else if (codePoint == Int32(-1)) {
                                errors.append("Expected \"*/\" to terminate multi-line comment")
                                return
                            } else {
                                if (codePoint == Int32(0x0D) || codePoint == Int32(0x0A) ||
                                    codePoint == Int32(0x2028) || codePoint == Int32(0x2029)) {
                                    hasNewlineBefore = true
                                }
                                step()
                            }
                        }
                        if (!opts.allowComments) {
                            errors.append("JSON does not support comments")
                        }
                        continue
                    } else {
                        addUnsupportedSyntaxError("Operators are not allowed in JSON")
                        return
                    }
                case Int32(39) =>
                    // 单引号字符串
                    parseStringLiteralInner(Int32(39))
                case Int32(34) =>
                    // 双引号字符串
                    parseStringLiteralInner(Int32(34))
                case Int32(92) =>
                    // 反斜杠 (标识符转义)
                    if (opts.ignoreLeadingEscapeSequences &&
                        (start == 0 || current >= source.size - 1)) {
                        step()
                        continue
                    }
                    scanIdentifierWithEscapes()
                case Int32(46) =>
                    // . 或数字
                    parseNumericLiteralOrDot()
                case _ =>
                    if (codePoint >= Int32(48) && codePoint <= Int32(57)) {
                        // 数字
                        parseNumericLiteralOrDot()
                    } else if (isIdentifierStart(codePoint)) {
                        // 标识符 (true, false, null, 其他)
                        step()
                        while (isIdentifierContinue(codePoint)) {
                            step()
                        }
                        identifier = raw()
                        token = match (identifier) {
                            case "true" => JSONToken.True
                            case "false" => JSONToken.False
                            case "null" => JSONToken.Null
                            case _ => JSONToken.Identifier
                        }
                    } else if (codePoint == Int32(63) || codePoint == Int32(42) ||
                        codePoint == Int32(40) || codePoint == Int32(41)) {
                        // ?, *, (, ) - 允许通过以支持 auto-quote 重试
                        step()
                        token = JSONToken.SyntaxError
                    } else if (codePoint == Int32(35)) {
                        addUnsupportedSyntaxError("Private identifiers are not allowed in JSON")
                        return
                    } else if (codePoint == Int32(59)) {
                        addUnsupportedSyntaxError("Semicolons are not allowed in JSON")
                        return
                    } else if (codePoint == Int32(37) || codePoint == Int32(38) ||
                        codePoint == Int32(124) || codePoint == Int32(94) ||
                        codePoint == Int32(43) || codePoint == Int32(61) ||
                        codePoint == Int32(60) || codePoint == Int32(62) ||
                        codePoint == Int32(33) || codePoint == Int32(96)) {
                        addUnsupportedSyntaxError("Operators are not allowed in JSON")
                        return
                    } else {
                        end = current
                        token = JSONToken.SyntaxError
                    }
            }
            return
        }
    }

    // ── helpers ─────────────────────────────────────────────────────────────

    /// 是否为空白字符 - 对应 Bun is_whitespace
    ///   fn is_whitespace(cp: CodePoint) -> bool {
    ///       matches!(cp, 0x000B | 0x000C | 0x2028 | 0x2029 | 0xFEFF)
    ///   }
    private static func isWhitespace(cp: Int32): Bool {
        cp == Int32(0x000B) || cp == Int32(0x000C) ||
            cp == Int32(0x2028) || cp == Int32(0x2029) ||
            cp == Int32(0xFEFF)
    }

    /// 是否为标识符起始字符 - 对应 Bun is_identifier_start
    ///   fn is_identifier_start(cp: CodePoint) -> bool {
    ///       matches!(cp, 0x24 | 0x5F) || (cp >= 'a' && cp <= 'z') || ...
    ///   }
    private static func isIdentifierStart(cp: Int32): Bool {
        cp == Int32(0x24) || cp == Int32(0x5F) ||
            (cp >= Int32(97) && cp <= Int32(122)) ||
            (cp >= Int32(65) && cp <= Int32(90))
    }

    /// 是否为标识符续接字符 - 对应 Bun is_identifier_continue
    ///   fn is_identifier_continue(cp: CodePoint) -> bool {
    ///       is_identifier_start(cp) || (cp >= '0' && cp <= '9')
    ///   }
    private static func isIdentifierContinue(cp: Int32): Bool {
        isIdentifierStart(cp) || (cp >= Int32(48) && cp <= Int32(57))
    }

    /// 是否为十六进制代码点 - 对应 Bun is_hex_code_point
    private static func isHexCodePoint(cp: Int32): Bool {
        (cp >= Int32(48) && cp <= Int32(57)) ||
            (cp >= Int32(65) && cp <= Int32(70)) ||
            (cp >= Int32(97) && cp <= Int32(102))
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        errors.size > Int64(0)
    }
}
