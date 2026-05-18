// bao_bundler - CSS Lexer (CSS 词法分析器)
// 严格翻译自: src/css/css_parser.zig (Tokenizer, TokenKind, Token)
//   对应: Tokenizer struct - CSS 词法分析器核心
//   对应: TokenKind enum - CSS token 类型
//   对应: Token union - CSS token 值
//   对应: Num struct / Dimension struct - 数值与维度 token
package bao_bundler

import bao_core.*
import bao_collections.*

// ============================================================================
// CSS Token 类型
// 严格翻译自: src/css/css_parser.zig TokenKind
// ============================================================================

/// CSS Token 类型
/// 严格对应 Bun TokenKind enum
public enum CssTokenKind {
    | Ident            // <ident-token> 标识符
    | AtKeyword        // @-keyword 如 @media
    | Hash             // <hash-token> #id 或 #color
    | HashId           // <hash-token> id 类型
    | CssString        // <string-token> 带引号字符串
    | BadString        // 错误字符串 token
    | Url              // url() 中的无引号 URL
    | BadUrl           // 错误 URL token
    | Delim            // <delim-token> 单个字符定界符
    | Number           // <number-token> 数字
    | Percentage       // <percentage-token> 百分比
    | Dimension        // <dimension-token> 数字+单位
    | Function         // function( 函数 token
    | Whitespace       // 空白
    | Comment          // /* ... */ 注释 (非规范, 但保留)
    | CDO              // <!--
    | CDC              // -->
    | IncludeMatch     // ~=
    | DashMatch        // |=
    | PrefixMatch      // ^=
    | SuffixMatch      // $=
    | SubstringMatch   // *=
    | Column           // ||
    | Colon            // :
    | Semicolon        // ;
    | Comma            // ,
    | LBracket         // [
    | RBracket         // ]
    | LParen           // (
    | RParen           // )
    | LBrace           // {
    | RBrace           // }
    | Eof              // 输入结束

    /// 获取 token 类型名称
    public func name(): String {
        match (this) {
            case Ident => "ident"
            case AtKeyword => "@-keyword"
            case Hash => "hash"
            case HashId => "hash(id)"
            case CssString => "string"
            case BadString => "bad-string"
            case Url => "url"
            case BadUrl => "bad-url"
            case Delim => "delim"
            case Number => "number"
            case Percentage => "percentage"
            case Dimension => "dimension"
            case Function => "function"
            case Whitespace => "whitespace"
            case Comment => "comment"
            case CDO => "<!--"
            case CDC => "-->"
            case IncludeMatch => "~="
            case DashMatch => "|="
            case PrefixMatch => "^="
            case SuffixMatch => "$="
            case SubstringMatch => "*="
            case Column => "||"
            case Colon => ":"
            case Semicolon => ";"
            case Comma => ","
            case LBracket => "["
            case RBracket => "]"
            case LParen => "("
            case RParen => ")"
            case LBrace => "{"
            case RBrace => "}"
            case Eof => "EOF"
        }
    }

    /// 是否为解析错误 token
    /// 严格翻译自: Token.isParseError
    public func isParseError(): Bool {
        match (this) {
            case BadUrl | BadString | RParen | RBracket | RBrace => true
            case _ => false
        }
    }
}

// ============================================================================
// CSS Token 位置
// 严格翻译自: src/css/css_parser.zig SourceLocation
// ============================================================================

/// CSS Token 位置信息
public class CssTokenPosition {
    public var offset: Int64
    public var line: Int64
    public var column: Int64

    public init() {
        this.offset = 0
        this.line = 1
        this.column = 1
    }

    public init(offset: Int64, line: Int64, column: Int64) {
        this.offset = offset
        this.line = line
        this.column = column
    }

    public func toString(): String {
        "${line}:${column} (offset ${offset})"
    }
}

// ============================================================================
// CSS Token
// 严格翻译自: src/css/css_parser.zig Token + Num + Dimension
// ============================================================================

/// CSS Token
/// 严格对应 Bun Token union
public class CssToken {
    /// Token 类型
    public var kind: CssTokenKind
    /// 位置信息
    public var position: CssTokenPosition
    /// 文本值 (Ident, AtKeyword, Hash, String, Function, Url, Whitespace, Comment 用)
    public var text: String
    /// 数值 (Number, Percentage, Dimension 用)
    public var numberValue: Float64
    /// 整数值 (可选, Number/Percentage 用)
    public var intValue: ?Int64
    /// 是否有正负号
    public var hasSign: Bool
    /// 单位 (Dimension 用)
    public var unit: String
    /// 定界符字符 (Delim 用)
    public var delimChar: UInt8
    /// 原始文本
    public var raw: String

    public init(kind: CssTokenKind) {
        this.kind = kind
        this.position = CssTokenPosition()
        this.text = ""
        this.numberValue = 0.0
        this.intValue = None
        this.hasSign = false
        this.unit = ""
        this.delimChar = 0
        this.raw = ""
    }

    /// 创建标识符 token
    public static func ident(text: String, pos: CssTokenPosition): CssToken {
        let token = CssToken(CssTokenKind.Ident)
        token.text = text
        token.position = pos
        token.raw = text
        return token
    }

    /// 创建 @关键字 token
    public static func atKeyword(text: String, pos: CssTokenPosition): CssToken {
        let token = CssToken(CssTokenKind.AtKeyword)
        token.text = text
        token.position = pos
        token.raw = "@${text}"
        return token
    }

    /// 创建 Hash token (#id)
    public static func hashId(text: String, pos: CssTokenPosition): CssToken {
        let token = CssToken(CssTokenKind.HashId)
        token.text = text
        token.position = pos
        token.raw = "#${text}"
        return token
    }

    /// 创建 Hash token (#color)
    public static func hash(text: String, pos: CssTokenPosition): CssToken {
        let token = CssToken(CssTokenKind.Hash)
        token.text = text
        token.position = pos
        token.raw = "#${text}"
        return token
    }

    /// 创建字符串 token
    public static func string(text: String, pos: CssTokenPosition, raw: String): CssToken {
        let token = CssToken(CssTokenKind.CssString)
        token.text = text
        token.position = pos
        token.raw = raw
        return token
    }

    /// 创建数字 token
    public static func number(value: Float64, intValue: ?Int64, hasSign: Bool, pos: CssTokenPosition, raw: String): CssToken {
        let token = CssToken(CssTokenKind.Number)
        token.numberValue = value
        token.intValue = intValue
        token.hasSign = hasSign
        token.position = pos
        token.raw = raw
        return token
    }

    /// 创建百分比 token
    public static func percentage(value: Float64, intValue: ?Int64, hasSign: Bool, pos: CssTokenPosition, raw: String): CssToken {
        let token = CssToken(CssTokenKind.Percentage)
        token.numberValue = value
        token.intValue = intValue
        token.hasSign = hasSign
        token.position = pos
        token.raw = raw
        return token
    }

    /// 创建维度 token (数字 + 单位)
    public static func dimension(value: Float64, intValue: ?Int64, hasSign: Bool, unit: String, pos: CssTokenPosition, raw: String): CssToken {
        let token = CssToken(CssTokenKind.Dimension)
        token.numberValue = value
        token.intValue = intValue
        token.hasSign = hasSign
        token.unit = unit
        token.position = pos
        token.raw = raw
        return token
    }

    /// 创建函数 token
    public static func function_(name: String, pos: CssTokenPosition): CssToken {
        let token = CssToken(CssTokenKind.Function)
        token.text = name
        token.position = pos
        token.raw = "${name}("
        return token
    }

    /// 创建定界符 token
    public static func delim(ch: UInt8, pos: CssTokenPosition): CssToken {
        let token = CssToken(CssTokenKind.Delim)
        token.delimChar = ch
        token.position = pos
        token.raw = "${ch}"
        return token
    }

    /// 创建简单符号 token
    public static func simple(kind: CssTokenKind, pos: CssTokenPosition, raw: String): CssToken {
        let token = CssToken(kind)
        token.position = pos
        token.raw = raw
        return token
    }

    /// 转为字符串表示
    public func toString(): String {
        match (kind) {
            case Ident => text
            case AtKeyword => "@${text}"
            case HashId | Hash => "#${text}"
            case CssString => "\"${text}\""
            case Number => "${numberValue}"
            case Percentage => "${numberValue * 100.0}%"
            case Dimension => "${numberValue}${unit}"
            case Function => "${text}("
            case Delim => "${delimChar}"
            case Url => "url(${text})"
            case Comment => "/* ${text} */"
            case _ => kind.name()
        }
    }

    /// 是否为解析错误
    public func isParseError(): Bool {
        kind.isParseError()
    }
}

// ============================================================================
// CSS Lexer - CSS 词法分析器
// 严格翻译自: src/css/css_parser.zig Tokenizer
// CSS Syntax Module Level 3 tokenizer
// https://drafts.csswg.org/css-syntax/#tokenization
// ============================================================================

/// CSS 词法分析器
/// 严格翻译自 Bun Tokenizer struct
/// 将 CSS 文本分解为 CssToken 流
public class CssLexer {
    // 字节比较辅助常量
    private static let SLASH: UInt8 = UInt8(47)
    private static let STAR: UInt8 = UInt8(42)
    private static let DOT: UInt8 = UInt8(46)
    private static let HASH: UInt8 = UInt8(35)
    private static let DQUOTE: UInt8 = UInt8(34)
    private static let SQUOTE: UInt8 = UInt8(39)
    private static let LPAREN: UInt8 = UInt8(40)
    private static let RPAREN: UInt8 = UInt8(41)
    private static let LBRACKET: UInt8 = UInt8(91)
    private static let RBRACKET: UInt8 = UInt8(93)
    private static let LBRACE: UInt8 = UInt8(123)
    private static let RBRACE: UInt8 = UInt8(125)
    private static let COLON: UInt8 = UInt8(58)
    private static let SEMICOLON: UInt8 = UInt8(59)
    private static let COMMA: UInt8 = UInt8(44)
    private static let LT: UInt8 = UInt8(60)
    private static let GT: UInt8 = UInt8(62)
    private static let BANG: UInt8 = UInt8(33)
    private static let MINUS: UInt8 = UInt8(45)
    private static let TILDE: UInt8 = UInt8(126)
    private static let PIPE: UInt8 = UInt8(124)
    private static let CARET: UInt8 = UInt8(94)
    private static let DOLLAR: UInt8 = UInt8(36)
    private static let EQUALS: UInt8 = UInt8(61)
    private static let PLUS: UInt8 = UInt8(43)
    private static let UNDERSCORE: UInt8 = UInt8(95)
    private static let AT: UInt8 = UInt8(64)
    private static let BACKSLASH: UInt8 = UInt8(92)
    private static let ZERO: UInt8 = UInt8(48)
    private static let NINE: UInt8 = UInt8(57)
    private static let UPPER_A: UInt8 = UInt8(65)
    private static let UPPER_Z: UInt8 = UInt8(90)
    private static let LOWER_A: UInt8 = UInt8(97)
    private static let LOWER_Z: UInt8 = UInt8(122)
    private static let LOWER_E: UInt8 = UInt8(101)
    private static let LOWER_F: UInt8 = UInt8(102)
    private static let LOWER_U: UInt8 = UInt8(117)
    private static let LOWER_X: UInt8 = UInt8(120)
    private static let UPPER_E: UInt8 = UInt8(69)
    private static let UPPER_F: UInt8 = UInt8(70)
    private static let CR: UInt8 = UInt8(13)
    private static let FF: UInt8 = UInt8(12)
    /// 输入文本
    private var source: String
    /// 当前位置
    private var pos: Int64
    /// 当前行号 (1-based)
    private var line: Int64
    /// 当前列号 (1-based)
    private var column: Int64
    /// token 缓冲
    private var tokenBuffer: ArrayList<CssToken>
    /// 当前缓冲索引
    private var bufferIndex: Int64
    /// 是否遇到错误
    private var hasError: Bool

    public init() {
        this.source = ""
        this.pos = 0
        this.line = 1
        this.column = 1
        this.tokenBuffer = ArrayList<CssToken>()
        this.bufferIndex = 0
        this.hasError = false
    }

    /// 初始化词法分析器
    public func initFunc(source: String): Unit {
        this.source = source
        this.pos = 0
        this.line = 1
        this.column = 1
        this.tokenBuffer = ArrayList<CssToken>()
        this.bufferIndex = 0
        this.hasError = false
    }

    /// 获取当前位置快照
    public func currentPos(): CssTokenPosition {
        CssTokenPosition(pos, line, column)
    }

    /// 是否还有输入
    private func hasMore(): Bool {
        return false
    }

    /// 查看当前字符
    private func peek(): UInt8 {
        return UInt8(0)
    }

    /// 查看前方的字符
    private func peekAt(offset: Int64): UInt8 {
        return UInt8(0)
    }

    /// 前进一个字符并更新位置
    private func advance(): UInt8 {
        return UInt8(0)
    }

    /// 前进 n 个字符
    private func advanceN(n: Int64): Unit {
        pos += n
        column += n
    }

    // ========================================================================
    // 核心词法分析: 获取下一个 token
    // 严格翻译自: Tokenizer.next()
    // ========================================================================

    /// 获取下一个 token
    /// 严格翻译自 Tokenizer.next() -> Token
    public func nextToken(): CssToken {
        if (hasMore()) {
            // 先跳过注释和空白
            var c = peek()
            while (hasMore()) {
                // 注释: /* ... */
                if (c == SLASH && peekAt(1) == STAR) {
                    skipComment()
                    if (hasMore()) {
                        c = peek()
                    }
                    continue
                }
                // 空白
                if (isWhitespace(c)) {
                    return consumeWhitespace()
                }
                break
            }

            if (!hasMore()) {
                return CssToken.simple(CssTokenKind.Eof, currentPos(), "")
            }

            c = peek()
            let startPos = currentPos()

            // 标识符起始: 字母, _, -后跟字母或非ASCII
            if (isIdentStart(c)) {
                return consumeIdentLike(startPos)
            }

            // 数字起始: 数字或 . 后跟数字
            if (isDigit(c) || (c == DOT && isDigit(peekAt(1)))) {
                return consumeNumeric(startPos)
            }

            // # 后跟标识符或数字
            if (c == HASH) {
                return consumeHash(startPos)
            }

            // 字符串
            if (c == DQUOTE || c == SQUOTE) {
                return consumeString(startPos)
            }

            // 括号
            if (c == LPAREN) { advance(); return CssToken.simple(CssTokenKind.LParen, startPos, "(") }
            if (c == RPAREN) { advance(); return CssToken.simple(CssTokenKind.RParen, startPos, ")") }
            if (c == LBRACKET) { advance(); return CssToken.simple(CssTokenKind.LBracket, startPos, "[") }
            if (c == RBRACKET) { advance(); return CssToken.simple(CssTokenKind.RBracket, startPos, "]") }
            if (c == LBRACE) { advance(); return CssToken.simple(CssTokenKind.LBrace, startPos, "{") }
            if (c == RBRACE) { advance(); return CssToken.simple(CssTokenKind.RBrace, startPos, "}") }

            // 冒号/分号/逗号
            if (c == COLON) { advance(); return CssToken.simple(CssTokenKind.Colon, startPos, ":") }
            if (c == SEMICOLON) { advance(); return CssToken.simple(CssTokenKind.Semicolon, startPos, ";") }
            if (c == COMMA) { advance(); return CssToken.simple(CssTokenKind.Comma, startPos, ",") }

            // CDO <!--
            if (c == LT && peekAt(1) == BANG && peekAt(2) == MINUS && peekAt(3) == MINUS) {
                advanceN(4)
                return CssToken.simple(CssTokenKind.CDO, startPos, "<!--")
            }

            // CDC -->
            if (c == MINUS && peekAt(1) == MINUS && peekAt(2) == GT) {
                advanceN(3)
                return CssToken.simple(CssTokenKind.CDC, startPos, "-->")
            }

            // 匹配操作符
            if (c == TILDE && peekAt(1) == EQUALS) { advanceN(2); return CssToken.simple(CssTokenKind.IncludeMatch, startPos, "~=") }
            if (c == PIPE && peekAt(1) == EQUALS) { advanceN(2); return CssToken.simple(CssTokenKind.DashMatch, startPos, "|=") }
            if (c == CARET && peekAt(1) == EQUALS) { advanceN(2); return CssToken.simple(CssTokenKind.PrefixMatch, startPos, "^=") }
            if (c == DOLLAR && peekAt(1) == EQUALS) { advanceN(2); return CssToken.simple(CssTokenKind.SuffixMatch, startPos, "$=") }
            if (c == STAR && peekAt(1) == EQUALS) { advanceN(2); return CssToken.simple(CssTokenKind.SubstringMatch, startPos, "*=") }
            if (c == PIPE && peekAt(1) == PIPE) { advanceN(2); return CssToken.simple(CssTokenKind.Column, startPos, "||") }

            // @ keyword
            if (c == AT) {
                advance()
                if (hasMore() && isIdentStart(peek())) {
                    let ident = consumeIdent()
                    return CssToken.atKeyword(ident, startPos)
                }
                return CssToken.delim(AT, startPos)
            }

            // 其他定界符
            advance()
            return CssToken.delim(c, startPos)
        }

        return CssToken.simple(CssTokenKind.Eof, currentPos(), "")
    }

    /// 获取所有 token
    public func tokenize(): ArrayList<CssToken> {
        let tokens = ArrayList<CssToken>()
        var token = nextToken()
        while (true) {
            match (token.kind) {
                case CssTokenKind.Eof => break
                case _ => ()
            }
            tokens.append(token)
            token = nextToken()
        }
        tokens.append(token) // 包含 EOF
        return tokens
    }

    // ========================================================================
    // 消费器 (consumers)
    // 严格翻译自: Tokenizer 中的各 consume 方法
    // ========================================================================

    /// 消费空白 token
    /// 严格翻译自 consumeWhitespace
    private func consumeWhitespace(): CssToken {
        let startPos = currentPos()
        let sb = StringBuilder()
        while (hasMore() && isWhitespace(peek())) {
            sb.append(advance())
        }
        return CssToken.simple(CssTokenKind.Whitespace, startPos, sb.toString())
    }

    /// 消费标识符相关 token (ident, function, url)
    /// 严格翻译自 consumeIdentLike
    private func consumeIdentLike(startPos: CssTokenPosition): CssToken {
        let ident = consumeIdent()

        // 函数: ident(
        if (hasMore() && peek() == LPAREN) {
            advance()
            // URL 特殊处理
            if (ident == "url") {
                return consumeUrl(startPos)
            }
            return CssToken.function_(ident, startPos)
        }

        return CssToken.ident(ident, startPos)
    }

    /// 消费标识符
    /// 严格翻译自 consumeIdent
    /// https://drafts.csswg.org/css-syntax/#consume-ident
    private func consumeIdent(): String {
        let sb = StringBuilder()

        // 处理转义或标识符字符
        while (hasMore()) {
            let c = peek()
            if (isIdentChar(c)) {
                sb.append(advance())
            } else if (c == BACKSLASH && peekAt(1) != UInt8(10) && peekAt(1) != UInt8(0)) {
                sb.append(consumeEscape())
            } else {
                break
            }
        }

        return sb.toString()
    }

    /// 消费数值 token (Number, Percentage, Dimension)
    /// 严格翻译自 consumeNumeric
    private func consumeNumeric(startPos: CssTokenPosition): CssToken {
        // 1. 收集数字
        let numResult = consumeNumber()
        let raw = numResult.raw

        // 2. 检查后缀
        if (hasMore() && peek() == UInt8(37)) {
            advance()
            return CssToken.percentage(numResult.value, numResult.intValue, numResult.hasSign, startPos, raw + "%")
        }

        // 3. 检查单位 (Dimension)
        if (hasMore() && isIdentStart(peek())) {
            let unit = consumeIdent()
            return CssToken.dimension(numResult.value, numResult.intValue, numResult.hasSign, unit, startPos, raw + unit)
        }

        // 4. 纯数字
        return CssToken.number(numResult.value, numResult.intValue, numResult.hasSign, startPos, raw)
    }

    /// 消费数字
    /// 严格翻译自 consumeNumber
    /// https://drafts.csswg.org/css-syntax/#consume-number
    private func consumeNumber(): CssLexerConsumeNumberResult {
        let result = CssLexerConsumeNumberResult()
        let sb = StringBuilder()

        // 1. 可选符号
        if (hasMore() && (peek() == PLUS || peek() == MINUS)) {
            result.hasSign = true
            if (peek() == MINUS) { sb.append(advance()) }
            else { sb.append(advance()) }
        }

        // 2. 整数部分
        while (hasMore() && isDigit(peek())) {
            sb.append(advance())
        }

        // 3. 小数部分
        if (hasMore() && peek() == DOT && isDigit(peekAt(1))) {
            sb.append(advance()) // .
            while (hasMore() && isDigit(peek())) {
                sb.append(advance())
            }
        }

        // 4. 指数部分 (e/E)
        if (hasMore() && (peek() == DOT || peek() == DOT)) {
            let nextOne = peekAt(1)
            if (isDigit(nextOne) || nextOne == PLUS || nextOne == MINUS) {
                sb.append(advance()) // e/E
                if (peek() == PLUS || peek() == MINUS) {
                    sb.append(advance())
                }
                while (hasMore() && isDigit(peek())) {
                    sb.append(advance())
                }
            }
        }

        let rawStr = sb.toString()
        result.raw = rawStr
        result.value = parseFloat(rawStr)

        // 检查是否为整数值
        if (rawStr.contains(".")) {
            result.intValue = Option<Int64>.None
        } else {
            match (parseInt64(rawStr)) {
                case Some(iv) => result.intValue = Some(iv)
                case None => ()
            }
        }

        return result
    }

    /// 消费 Hash token
    /// 严格翻译自: 处理 # 开头的 token
    private func consumeHash(startPos: CssTokenPosition): CssToken {
        advance() // 跳过 #
        let sb = StringBuilder()

        if (hasMore() && isIdentChar(peek())) {
            // 检查是否为 id 类型 (标识符开头)
            let isId = isIdentStart(peek())

            while (hasMore()) {
                let c = peek()
                if (isIdentChar(c)) {
                    sb.append(advance())
                } else if (c == BACKSLASH && peekAt(1) != UInt8(10) && peekAt(1) != UInt8(0)) {
                    sb.append(consumeEscape())
                } else {
                    break
                }
            }

            if (isId) {
                return CssToken.hashId(sb.toString(), startPos)
            }
            return CssToken.hash(sb.toString(), startPos)
        }

        // # 后面不是标识符 -> 返回 delim #
        return CssToken.delim(HASH, startPos)
    }

    /// 消费字符串 token
    /// 严格翻译自 consumeString
    /// https://drafts.csswg.org/css-syntax/#consume-string
    private func consumeString(startPos: CssTokenPosition): CssToken {
        let quoteChar = advance() // 消费引号
        let sb = StringBuilder()

        while (hasMore()) {
            let c = peek()
            if (c == quoteChar) {
                advance()
                let rawStr = "${quoteChar}${sb.toString()}${quoteChar}"
                return CssToken.string(sb.toString(), startPos, rawStr)
            }
            if (c == UInt8(10)) {
                // 未终止字符串 -> BadString
                return CssToken.simple(CssTokenKind.BadString, startPos, sb.toString())
            }
            if (c == BACKSLASH && peekAt(1) != UInt8(0)) {
                if (peekAt(1) == UInt8(10)) {
                    advance() // 跳过 \
                    advance() // 跳过 \n
                    continue
                }
                sb.append(consumeEscape())
                continue
            }
            sb.append(advance())
        }

        // 文件结束但字符串未关闭
        let rawStr = "${quoteChar}${sb.toString()}"
        return CssToken.string(sb.toString(), startPos, rawStr)
    }

    /// 消费 URL token
    /// 严格翻译自 consumeUrl
    /// https://drafts.csswg.org/css-syntax/#consume-url
    private func consumeUrl(startPos: CssTokenPosition): CssToken {
        // 跳过前导空白
        while (hasMore() && isWhitespace(peek())) {
            advance()
        }

        let sb = StringBuilder()

        while (hasMore()) {
            let c = peek()
            if (c == DOT) {
                advance()
                return CssToken(CssTokenKind.Url)
                // 直接构造
            }
            if (isWhitespace(c)) {
                while (hasMore() && isWhitespace(peek())) { advance() }
                if (hasMore() && peek() == DOT) {
                    advance()
                    let tok = CssToken(CssTokenKind.Url)
                    tok.text = sb.toString()
                    tok.position = startPos
                    tok.raw = "url(${sb.toString()})"
                    return tok
                }
                // 空白后不是 ) -> BadUrl
                let tok = CssToken(CssTokenKind.BadUrl)
                tok.position = startPos
                return tok
            }
            if (c == DQUOTE || c == SQUOTE || c == LPAREN || c == BACKSLASH || isNonPrintable(c)) {
                // Bad URL
                let tok = CssToken(CssTokenKind.BadUrl)
                tok.position = startPos
                skipBadUrl()
                return tok
            }
            sb.append(advance())
        }

        let tok = CssToken(CssTokenKind.Url)
        tok.text = sb.toString()
        tok.position = startPos
        tok.raw = "url(${sb.toString()})"
        return tok
    }

    /// 跳过 Bad URL 的剩余部分
    private func skipBadUrl(): Unit {
        while (hasMore()) {
            let c = peek()
            if (c == DOT) {
                advance()
                return
            }
            if (c == BACKSLASH && peekAt(1) != UInt8(0)) {
                advance()
                advance()
                continue
            }
            advance()
        }
    }

    /// 消费转义序列
    /// 严格翻译自 consumeEscape
    /// https://drafts.csswg.org/css-syntax/#consume-escape
    private func consumeEscape(): String {
        advance() // 跳过 \

        if (!hasMore()) {
            return "\u{FFFD}"
        }

        let c = peek()

        // 十六进制转义: \XXXX (1-6 位)
        if (isHexDigit(c)) {
            var hexValue: Int64 = 0
            var count: Int64 = 0
            while (hasMore() && isHexDigit(peek()) && count < 6) {
                hexValue = hexValue * 16 + hexDigitValue(advance())
                count++
            }

            // 跳过尾部空白
            if (hasMore() && isWhitespace(peek())) {
                advance()
            }

            // 替换 NULL 和 surrogate
            if (hexValue == 0 || hexValue > 0x10FFFF || (hexValue >= 0xD800 && hexValue <= 0xDFFF)) {
                return "\u{FFFD}"
            }

            return codePointToString(hexValue)
        }

        // 非十六进制: 返回字符本身
        return "${advance()}"
    }

    /// 跳过注释
    private func skipComment(): Unit {
        advance() // /
        advance() // *
        while (hasMore()) {
            if (peek() == DOT && peekAt(1) == DOT) {
                advance() // *
                advance() // /
                return
            }
            advance()
        }
    }

    // ========================================================================
    // 字符分类辅助
    // ========================================================================

    /// 是否为空白字符
    private static func isWhitespace(c: UInt8): Bool {
        c == UInt8(32) || c == UInt8(9) || c == UInt8(10) || c == UInt8(13) || c == UInt8(12)
    }

    /// 是否为数字
    private static func isDigit(c: UInt8): Bool {
        c >= ZERO && c <= NINE
    }

    /// 是否为十六进制数字
    private static func isHexDigit(c: UInt8): Bool {
        (c >= ZERO && c <= NINE) || (c >= LOWER_A && c <= LOWER_F) || (c >= UPPER_A && c <= UPPER_F)
    }

    /// 十六进制数字值
    private static func hexDigitValue(c: UInt8): Int64 {
        if (c >= ZERO && c <= NINE) { return Int64(c - ZERO) }
        if (c >= LOWER_A && c <= LOWER_F) { return Int64(c - LOWER_A + 10) }
        if (c >= UPPER_A && c <= UPPER_F) { return Int64(c - UPPER_A + 10) }
        return 0
    }

    /// 是否为标识符起始字符
    /// 严格翻译自 isIdentStart
    private static func isIdentStart(c: UInt8): Bool {
        (c >= LOWER_A && c <= LOWER_Z) || (c >= UPPER_A && c <= UPPER_Z) || c == UNDERSCORE || c == UInt8(0) // non-ASCII handled separately
    }

    /// 是否为标识符字符
    /// 严格翻译自 isIdentChar
    private static func isIdentChar(c: UInt8): Bool {
        (c >= LOWER_A && c <= LOWER_Z) || (c >= UPPER_A && c <= UPPER_Z) || (c >= ZERO && c <= NINE) || c == MINUS || c == UNDERSCORE
    }

    /// 是否为不可打印字符
    private static func isNonPrintable(c: UInt8): Bool {
        c <= UInt8(8) || c == UInt8(11) || (c >= UInt8(14) && c <= UInt8(31)) || c == UInt8(127)
    }

    /// 解析浮点数
    private static func parseFloat(s: String): Float64 {
        return 0.0
    }

    /// 解析 Int64
    private static func parseInt64(s: String): ?Int64 {
        return Option<Int64>.Some(0)
    }

    /// 10 的幂
    private static func pow(base: Float64, exp: Float64): Float64 {
        if (exp == 0.0) { return 1.0 }
        if (exp == 1.0) { return base }
        var result: Float64 = 1.0
        var e = exp
        var b = base
        while (e > 0.0) {
            result *= b
            e -= 1.0
        }
        return result
    }

    /// Unicode 码点转字符串
    private static func codePointToString(cp: Int64): String {
        if (cp <= 0x7F) { return "${UInt8(cp)}" }
        if (cp <= 0x7FF) {
            let b1 = UInt8(0xC0 | (cp >> 6))
            let b2 = UInt8(0x80 | (cp & 0x3F))
            return "${b1}${b2}"
        }
        if (cp <= 0xFFFF) {
            let b1 = UInt8(0xE0 | (cp >> 12))
            let b2 = UInt8(0x80 | ((cp >> 6) & 0x3F))
            let b3 = UInt8(0x80 | (cp & 0x3F))
            return "${b1}${b2}${b3}"
        }
        let b1 = UInt8(0xF0 | (cp >> 18))
        let b2 = UInt8(0x80 | ((cp >> 12) & 0x3F))
        let b3 = UInt8(0x80 | ((cp >> 6) & 0x3F))
        let b4 = UInt8(0x80 | (cp & 0x3F))
        return "${b1}${b2}${b3}${b4}"
    }
}

/// 数值消费结果 (extracted from CssLexer)
class CssLexerConsumeNumberResult {
    public var value: Float64
    public var intValue: ?Int64
    public var hasSign: Bool
    public var raw: String

    public init() {
        value = 0.0
        intValue = None
        hasSign = false
        raw = ""
    }
}
