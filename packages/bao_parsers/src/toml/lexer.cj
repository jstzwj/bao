// bao_parsers.toml.lexer
// Strict port of Bun: src/parsers/toml/lexer.zig
package bao_parsers.toml

import bao_core.*
import bao_collections.*
import bao_parsers.*
import std.convert.*

public enum TomlTokenKind {
    | EndOfFile
    | OpenParen
    | CloseParen
    | OpenBracket
    | OpenBracketDouble
    | CloseBracket
    | CloseBracketDouble
    | OpenBrace
    | CloseBrace
    | NumericLiteral
    | Comma
    | StringLiteral
    | Dot
    | Equal
    | True_
    | False_
    | Colon
    | Identifier
    | Plus
    | Minus
    | EmptyArray
}

public class TomlLexerError <: Exception {
    public init(message: String) { super(message) }
}

/// Lexer state matching Bun's `Lexer` fields.
public class TomlLexer {
    public var source: String
    public var start: Int64
    public var end: Int64
    public var current: Int64
    public var codePoint: Int64
    public var identifier: String
    public var number: Float64
    public var stringLiteralSlice: String
    public var stringLiteralIsAscii: Bool
    public var lineNumber: Int64
    public var token: TomlTokenKind
    public var allowDoubleBracket: Bool
    public var hasNewlineBefore: Bool
    public var shouldRedactLogs: Bool
    public var errors: ArrayList<ParseError>

    public init(source: String) {
        this.source = source
        start = 0
        end = 0
        current = 0
        codePoint = -1
        identifier = ""
        number = 0.0
        stringLiteralSlice = ""
        stringLiteralIsAscii = true
        lineNumber = 0
        token = TomlTokenKind.EndOfFile
        allowDoubleBracket = true
        hasNewlineBefore = false
        shouldRedactLogs = false
        errors = ArrayList<ParseError>()
        step()
        next()
    }

    public func loc(): Int64 { start }

    public func raw(): String {
        if (start < 0 || end < start || end > source.size) { return "" }
        return source[start..end]
    }

    public func expect(token: TomlTokenKind): Unit {
        if (this.token.toString() != token.toString()) { expected(token) }
        next()
    }

    public func expectAssignment(): Unit {
        match (token) {
            case TomlTokenKind.Equal | TomlTokenKind.Colon => ()
            case _ => expected(TomlTokenKind.Equal)
        }
        next()
    }

    public func next(): Unit {
        hasNewlineBefore = end == 0
        while (true) {
            start = end
            token = TomlTokenKind.EndOfFile
            match (codePoint) {
                case -1 => token = TomlTokenKind.EndOfFile
                case 13 | 10 | 0x2028 | 0x2029 =>
                    step()
                    hasNewlineBefore = true
                    continue
                case 9 | 32 =>
                    step()
                    continue
                case 91 =>
                    step()
                    token = TomlTokenKind.OpenBracket
                    if (codePoint == 91 && allowDoubleBracket) {
                        step(); token = TomlTokenKind.OpenBracketDouble; return
                    }
                    if (codePoint == 93) { step(); token = TomlTokenKind.EmptyArray }
                case 93 =>
                    step(); token = TomlTokenKind.CloseBracket
                    if (codePoint == 93 && allowDoubleBracket) { step(); token = TomlTokenKind.CloseBracketDouble }
                case 43 =>
                    step(); token = TomlTokenKind.Plus
                case 45 =>
                    step(); token = TomlTokenKind.Minus
                case 123 =>
                    step(); token = TomlTokenKind.OpenBrace
                case 125 =>
                    step(); token = TomlTokenKind.CloseBrace
                case 61 =>
                    step(); token = TomlTokenKind.Equal
                case 58 =>
                    step(); token = TomlTokenKind.Colon
                case 44 =>
                    step(); token = TomlTokenKind.Comma
                case 59 =>
                    if (hasNewlineBefore) { skipLineCommentAfterStep(); continue }
                    addDefaultError("Unexpected semicolon")
                case 35 =>
                    skipLineCommentAfterStep()
                    continue
                case 39 => scanLiteralString()
                case 34 => scanBasicString()
                case 46 => parseNumericLiteralOrDot()
                case _ =>
                    if (isDigit(codePoint)) {
                        parseNumericLiteralOrDot()
                    } else if (isIdentifierStart(codePoint)) {
                        scanIdentifier()
                    } else {
                        unexpected()
                    }
            }
            return
        }
    }

    private func scanLiteralString(): Unit {
        step()
        stringLiteralIsAscii = true
        let s = end
        var multiline = false
        if (codePoint == 39) {
            step()
            if (codePoint == 39) { step(); multiline = true } else {
                token = TomlTokenKind.StringLiteral
                stringLiteralSlice = ""
                return
            }
        }
        while (true) {
            if (codePoint == -1) { addDefaultError("Unterminated string literal") }
            if (!multiline && (codePoint == 10 || codePoint == 13 || codePoint == 0x2028 || codePoint == 0x2029)) {
                addDefaultError("Unterminated string literal (single-line)")
            }
            if (codePoint == 39) {
                let closeStart = end
                step()
                if (multiline) {
                    if (codePoint != 39) { continue }
                    step()
                    if (codePoint != 39) { continue }
                    step()
                    token = TomlTokenKind.StringLiteral
                    stringLiteralSlice = source[(s + 2)..closeStart]
                    return
                }
                token = TomlTokenKind.StringLiteral
                stringLiteralSlice = source[s..(end - 1)]
                return
            }
            step()
        }
    }

    private func scanBasicString(): Unit {
        step()
        var needsSlowPass = false
        let s = end
        var multiline = false
        stringLiteralIsAscii = true
        if (codePoint == 34) {
            step()
            if (codePoint == 34) { step(); multiline = true } else {
                token = TomlTokenKind.StringLiteral
                stringLiteralSlice = ""
                return
            }
        }
        var lo = s
        var hi = s
        while (true) {
            if (codePoint == -1) { addDefaultError("Unterminated basic string") }
            if (!multiline && (codePoint == 10 || codePoint == 13 || codePoint == 0x2028 || codePoint == 0x2029)) {
                addDefaultError("Unterminated basic string (single-line)")
            }
            if (codePoint == 92) { step(); needsSlowPass = true; if (codePoint == 34) { step(); continue } }
            if (codePoint == 34) {
                let closeStart = end
                step()
                if (multiline) {
                    if (codePoint != 34) { continue }
                    step()
                    if (codePoint != 34) { continue }
                    step()
                    lo = s + 2; hi = closeStart
                } else {
                    lo = s; hi = end - 1
                }
                token = TomlTokenKind.StringLiteral
                let text = source[lo..hi]
                if (needsSlowPass) {
                    start = s
                    stringLiteralSlice = decodeEscapeSequences(s, text, multiline)
                    stringLiteralIsAscii = false
                } else {
                    stringLiteralSlice = text
                }
                return
            }
            step()
        }
    }

    private func parseNumericLiteralOrDot(): Unit {
        let first = codePoint
        step()
        if (first == 46 && !isDigit(codePoint)) { token = TomlTokenKind.Dot; return }

        token = TomlTokenKind.NumericLiteral
        while (isIdentifierPart(codePoint) || codePoint == 46 || codePoint == 43 || codePoint == 45) {
            step()
        }
        let text = raw().replace("_", "")
        try {
            number = Float64.parse(text)
        } catch (_: Exception) {
            addSyntaxError(start, "Invalid number")
        }
    }

    private func scanIdentifier(): Unit {
        step()
        while (TomlLexer.isIdentifierPart(codePoint)) { step() }
        identifier = raw()
        if (identifier == "true") { token = TomlTokenKind.True_ }
        else if (identifier == "false") { token = TomlTokenKind.False_ }
        else { token = TomlTokenKind.Identifier }
    }

    public func decodeEscapeSequences(start: Int64, text: String, allowMultiline: Bool): String {
        let out = StringBuilder()
        var i: Int64 = 0
        while (i < text.size) {
            let c = Int64(UInt32(text[i]))
            if (c == 92 && i + 1 < text.size) {
                i += 1
                match (Int64(UInt32(text[i]))) {
                    case 98 => out.appendRune(Rune(8))
                    case 102 => out.appendRune(Rune(9))
                    case 110 => out.appendRune(Rune(10))
                    case 118 => out.appendRune(Rune(11))
                    case 116 => out.appendRune(Rune(12))
                    case 114 => out.appendRune(Rune(13))
                    case 92 => out.appendRune(Rune(92))
                    case 34 => out.appendRune(Rune(34))
                    case 10 => if (!allowMultiline) { addDefaultError("Unexpected end of line") }
                    case _ => out.appendRune(text[i])
                }
            } else if (c == 13) {
                out.appendRune(Rune(10))
                if (i + 1 < text.size && Int64(UInt32(text[i + 1])) == 10) { i += 1 }
            } else {
                out.appendRune(text[i])
            }
            i += 1
        }
        return out.toString()
    }

    public func expected(token: TomlTokenKind): Unit {
        expectedString(tokenName(token))
    }

    public func expectedString(text: String): Unit {
        let found = if (start == source.size) { "end of file" } else { raw() }
        addRangeError(start, end - start, "Expected " + text + " but found " + found)
    }

    public func unexpected(): Unit {
        let found = if (start == source.size) { "end of file" } else { raw() }
        addRangeError(start, end - start, "Unexpected " + found)
    }

    private func step(): Unit {
        codePoint = nextCodepoint()
        if (codePoint == 10) { lineNumber += 1 }
    }

    private func nextCodepoint(): Int64 {
        if (current >= source.size) { end = source.size; return -1 }
        end = current
        let ch = source[current]
        current += 1
        return Int64(UInt32(ch))
    }

    private func skipLineCommentAfterStep(): Unit {
        step()
        while (codePoint != -1 && codePoint != 10 && codePoint != 13 && codePoint != 0x2028 && codePoint != 0x2029) { step() }
    }

    private func addDefaultError(msg: String): Nothing { addSyntaxError(start, msg) }
    private func addSyntaxError(loc: Int64, msg: String): Nothing {
        errors.append(ParseError(ParseErrorKind.InvalidSyntax, msg, loc, lineNumber + 1, loc - lineStart(loc) + 1))
        throw TomlLexerError(msg)
    }
    private func addRangeError(loc: Int64, len: Int64, msg: String): Nothing {
        errors.append(ParseError(ParseErrorKind.UnexpectedToken, msg, loc, lineNumber + 1, loc - lineStart(loc) + 1))
        throw TomlLexerError(msg)
    }
    private func lineStart(loc: Int64): Int64 {
        var i = loc
        while (i > 0 && Int64(UInt32(source[i - 1])) != 10) { i -= 1 }
        return i
    }

    public static func isIdentifierPart(codePoint: Int64): Bool {
        return isDigit(codePoint) || (codePoint >= 65 && codePoint <= 90) || (codePoint >= 97 && codePoint <= 122) || codePoint == 36 || codePoint == 95 || codePoint == 45 || codePoint == 58
    }

    public static func isLatin1Identifier(name: String): Bool {
        if (name.size == 0) { return false }
        let first = Int64(UInt32(name[0]))
        if (!((first >= 65 && first <= 90) || (first >= 97 && first <= 122) || first == 36 || (first >= 49 && first <= 57) || first == 95 || first == 45)) { return false }
        var i: Int64 = 1
        while (i < name.size) {
            if (!isIdentifierPart(Int64(UInt32(name[i])))) { return false }
            i += 1
        }
        return true
    }

    private static func isDigit(cp: Int64): Bool { cp >= 48 && cp <= 57 }
    private static func isIdentifierStart(cp: Int64): Bool { cp == 64 || cp == 36 || cp == 95 || (cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122) }
    private static func tokenName(t: TomlTokenKind): String { return t.toString() }
}
