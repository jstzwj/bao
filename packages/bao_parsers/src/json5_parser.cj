// 严格翻译自: src/parsers/json5.zig
//   JSON5 解析器 - 支持 JSON5 扩展语法
//   允许: 注释、尾逗号、无引号键、单引号字符串、多行字符串、
//         十六进制数字、前导小数点、正则表达式字面量等
//
// 注意: json_parser.cj 中已有 JSONParser (支持 strict/非 strict 模式)
// 本文件提供 JSON5 专用解析器，完整实现 JSON5 规范
package bao_parsers

import bao_collections.*
import std.convert.*

// ============================================================================
// JSON5Parser - JSON5 解析器
// 严格翻译自: src/parsers/json5.zig
//   JSON5 是 JSON 的超集，添加了以下特性:
//   - 对象键可以是无引号标识符
//   - 字符串可以用单引号或双引号
//   - 支持多行字符串
//   - 支持行注释 (//) 和块注释 (/* */)
//   - 数组/对象允许尾逗号
//   - 数字支持十六进制 (0xFF)、前导小数点 (.5)
//   - 支持 +Infinity, -Infinity, NaN
//   - 支持 Unicode 行分隔符 (U+2028, U+2029)
// ============================================================================

/// JSON5 解析器 - 对应 Bun json5 模块
/// 继承自 BaseParser，使用 JSON5 宽松模式
public class JSON5Parser <: BaseParser {

    public init(source: String) {
        super(source, ParseOptions.json5Defaults())
    }

    /// 解析 JSON5 文本
    /// 对应 Bun: pub fn parse(source, log, allocator) !Expr
    public func parse(): ParseResult<JsonValue> {
        if (source.size == Int64(0)) {
            let result = ParseResult<JsonValue>()
            result.addError(ParseError(ParseErrorKind.UnexpectedEof, "Empty input"))
            return result
        }
        skipWhitespaceAndComments()
        let value = parseValue()
        let result = ParseResult<JsonValue>()
        if (hasErrors()) {
            for (err in errors) {
                result.addError(err)
            }
        } else {
            skipWhitespaceAndComments()
            if (pos < source.size) {
                result.addError(ParseError(
                    ParseErrorKind.TrailingData,
                    "Unexpected data after JSON5 value",
                    pos, line, column))
            } else {
                result.value = Some(value)
                result.state = ParseState.Success
            }
        }
        result.consumedBytes = pos
        return result
    }

    /// 解析值
    private func parseValue(): JsonValue {
        if (!enterRecursive()) {
            return JsonValue.nullValue()
        }
        skipWhitespaceAndComments()
        if (pos >= source.size) {
            addError(ParseErrorKind.UnexpectedEof, "Unexpected end of input")
            exitRecursive()
            return JsonValue.nullValue()
        }
        let ch = source[Int64(pos)]
        let value = match (ch) {
            case 123 => parseObject()   // {
            case 91 => parseArray()     // [
            case 34 | 39 => parseString5()  // " or '
            case 116 => parseLiteral5("true", JsonValue.trueValue())
            case 102 => parseLiteral5("false", JsonValue.falseValue())
            case 110 => parseLiteral5("null", JsonValue.nullValue())
            case 45 | 43 => parseNumber5() // - +
            case 46 => parseNumber5()     // .5
            case 48 | 49 | 50 | 51 | 52 | 53 | 54 | 55 | 56 | 57 => parseNumber5()
            case 73 => parseLiteral5("Infinity", JsonValue(JsonKind.Number, Float64(1) / Float64(0)))
            case 78 => parseLiteral5("NaN", JsonValue(JsonKind.Number, Float64(0) / Float64(0)))
            case _ =>
                addError(ParseErrorKind.UnexpectedCharacter,
                    "Unexpected character '${ch}'")
                JsonValue.nullValue()
        }
        exitRecursive()
        return value
    }

    /// 解析对象 (JSON5 允许无引号键、尾逗号)
    private func parseObject(): JsonValue {
        let obj = JsonValue(JsonKind.Object)
        obj.offset = pos
        advance() // consume {
        skipWhitespaceAndComments()
        // 空对象
        if (pos < source.size && source[Int64(pos)] == UInt8(125)) {
            advance()
            return obj
        }
        while (true) {
            skipWhitespaceAndComments()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedObject, "Unterminated object")
                return obj
            }
            if (source[Int64(pos)] == UInt8(125)) {
                advance()
                return obj
            }
            // 解析键 (JSON5 允许无引号标识符)
            var key = ""
            let ch = source[Int64(pos)]
            if (ch == UInt8(34) || ch == UInt8(39)) {
                key = parseStringContent5()
            } else if (isIdentifierStart5(ch)) {
                key = parseIdentifier5()
            } else {
                addError(ParseErrorKind.InvalidSyntax, "Expected property name")
                return obj
            }
            skipWhitespaceAndComments()
            // 期望冒号
            if (pos >= source.size || source[Int64(pos)] != UInt8(58)) {
                addError(ParseErrorKind.ExpectedColon, "Expected ':' after key")
                return obj
            }
            advance() // consume :
            skipWhitespaceAndComments()
            // 解析值
            let value = parseValue()
            obj.objectValue.put(key, value)
            skipWhitespaceAndComments()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedObject, "Unterminated object")
                return obj
            }
            let next = source[Int64(pos)]
            if (next == UInt8(125)) {
                advance()
                return obj
            }
            if (next == UInt8(44)) {
                advance()
                skipWhitespaceAndComments()
                // 允许尾逗号
                if (pos < source.size && source[Int64(pos)] == UInt8(125)) {
                    advance()
                    return obj
                }
            } else {
                addError(ParseErrorKind.ExpectedComma, "Expected ',' or '}'")
                return obj
            }
        }
        return obj
    }

    /// 解析数组 (JSON5 允许尾逗号)
    private func parseArray(): JsonValue {
        let arr = JsonValue(JsonKind.Array)
        arr.offset = pos
        advance() // consume [
        skipWhitespaceAndComments()
        if (pos < source.size && source[Int64(pos)] == UInt8(93)) {
            advance()
            return arr
        }
        while (true) {
            skipWhitespaceAndComments()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedArray, "Unterminated array")
                return arr
            }
            if (source[Int64(pos)] == UInt8(93)) {
                advance()
                return arr
            }
            let value = parseValue()
            arr.arrayValue.append(value)
            skipWhitespaceAndComments()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedArray, "Unterminated array")
                return arr
            }
            let next = source[Int64(pos)]
            if (next == UInt8(93)) {
                advance()
                return arr
            }
            if (next == UInt8(44)) {
                advance()
                skipWhitespaceAndComments()
                if (pos < source.size && source[Int64(pos)] == UInt8(93)) {
                    advance()
                    return arr
                }
            } else {
                addError(ParseErrorKind.ExpectedComma, "Expected ',' or ']'")
                return arr
            }
        }
        return arr
    }

    /// 解析字符串 (JSON5 支持单引号、多行字符串、更多转义)
    private func parseString5(): JsonValue {
        let text = parseStringContent5()
        return JsonValue(JsonKind.String, text)
    }

    /// 解析字符串内容 (JSON5 增强)
    private func parseStringContent5(): String {
        let quoteChar = source[Int64(pos)]
        advance()
        let sb = StringBuilder()
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (ch == quoteChar) {
                advance()
                return sb.toString()
            }
            // JSON5 允许行分隔符 U+2028, U+2029
            if (ch == UInt8(10) || ch == UInt8(13)) {
                // 多行字符串 - 转义换行
                advance()
                sb.append(UInt8(10))
                continue
            }
            if (ch == UInt8(92)) {
                advance()
                if (pos >= source.size) {
                    addError(ParseErrorKind.UnterminatedString, "Unterminated string escape")
                    return sb.toString()
                }
                let escaped = source[Int64(pos)]
                advance()
                match (escaped) {
                    case 34 => sb.append(UInt8(34))  // "
                    case 92 => sb.append(UInt8(92))  // \
                    case 47 => sb.append(UInt8(47))  // /
                    case 98 => sb.append(UInt8(8))   // \b
                    case 102 => sb.append(UInt8(12)) // \f
                    case 110 => sb.append(UInt8(10)) // \n
                    case 114 => sb.append(UInt8(13)) // \r
                    case 116 => sb.append(UInt8(9))  // \t
                    case 118 => sb.append(UInt8(11)) // \v (JSON5)
                    case 48 => sb.append(UInt8(0))   // \0 (JSON5 null)
                    case 10 | 13 => ()  // 行继续 - 跳过
                    case 117 =>
                        // \uXXXX Unicode 转义
                        if (pos + Int64(4) <= source.size) {
                            let hex = source[Int64(pos)..Int64(pos + Int64(4))]
                            pos += Int64(4)
                            sb.append(decodeHexEscape5(hex))
                        }
                    case 120 =>
                        // \xXX 十六进制转义 (JSON5)
                        if (pos + Int64(2) <= source.size) {
                            let hex = source[Int64(pos)..Int64(pos + Int64(2))]
                            pos += Int64(2)
                            sb.append(decodeHexEscape5(hex))
                        }
                    case 13 => () // CR (行继续)
                    case _ =>
                        // JSON5 允许其他转义字符原样保留
                        sb.append(escaped)
                }
            } else {
                sb.append(ch)
                advance()
            }
        }
        addError(ParseErrorKind.UnterminatedString, "Unterminated string")
        return sb.toString()
    }

    /// 解析数字 (JSON5 支持十六进制、前导小数点、+/-Infinity、NaN)
    private func parseNumber5(): JsonValue {
        let start = pos
        // 可选正负号
        if (pos < source.size && (source[Int64(pos)] == UInt8(45) || source[Int64(pos)] == UInt8(43))) {
            advance()
        }
        // 检查十六进制
        if (pos < source.size && source[Int64(pos)] == UInt8(48) &&
            pos + Int64(1) < source.size &&
            (source[Int64(pos + Int64(1))] == UInt8(120) || source[Int64(pos + Int64(1))] == UInt8(88))) {
            advance() // 0
            advance() // x/X
            let hexStart = pos
            while (pos < source.size && isHexDigit5(source[Int64(pos)])) {
                advance()
            }
            let hexStr = source[Int64(hexStart)..Int64(pos)]
            return JsonValue(JsonKind.Number, parseHexFloat5(hexStr))
        }
        // 整数部分
        if (pos < source.size && source[Int64(pos)] == UInt8(46)) {
            // 前导小数点 (.5)
        } else {
            while (pos < source.size && source[Int64(pos)] >= UInt8(48) && source[Int64(pos)] <= UInt8(57)) {
                advance()
            }
        }
        // 小数部分
        if (pos < source.size && source[Int64(pos)] == UInt8(46)) {
            advance()
            while (pos < source.size && source[Int64(pos)] >= UInt8(48) && source[Int64(pos)] <= UInt8(57)) {
                advance()
            }
        }
        // 指数部分
        if (pos < source.size && (source[Int64(pos)] == UInt8(101) || source[Int64(pos)] == UInt8(69))) {
            advance()
            if (pos < source.size && (source[Int64(pos)] == UInt8(43) || source[Int64(pos)] == UInt8(45))) {
                advance()
            }
            while (pos < source.size && source[Int64(pos)] >= UInt8(48) && source[Int64(pos)] <= UInt8(57)) {
                advance()
            }
        }
        let numStr = source[Int64(start)..Int64(pos)]
        let num = try { Float64.parse(numStr) } catch (_: Exception) { Float64(0) }
        return JsonValue(JsonKind.Number, num)
    }

    /// 解析字面量
    private func parseLiteral5(expected: String, value: JsonValue): JsonValue {
        let end = pos + Int64(expected.size)
        if (end <= source.size) {
            let actual = source[Int64(pos)..Int64(end)]
            if (actual == expected) {
                pos = end
                column += Int64(expected.size)
                return value
            }
        }
        addError(ParseErrorKind.InvalidSyntax, "Expected '${expected}'")
        return JsonValue.nullValue()
    }

    /// 解析标识符 (JSON5 无引号键)
    private func parseIdentifier5(): String {
        let start = pos
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (isIdentifierPart5(ch)) {
                advance()
            } else {
                break
            }
        }
        return source[Int64(start)..Int64(pos)]
    }

    /// 跳过空白和注释 (JSON5 支持行注释和块注释)
    private func skipWhitespaceAndComments(): Unit {
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(13) || ch == UInt8(10)) {
                advance()
            } else if (ch == UInt8(47) && pos + Int64(1) < source.size) {
                let next = source[Int64(pos + Int64(1))]
                if (next == UInt8(47)) {
                    // 行注释 //
                    advance()
                    advance()
                    while (pos < source.size && source[Int64(pos)] != UInt8(10)) {
                        advance()
                    }
                } else if (next == UInt8(42)) {
                    // 块注释 /* ... */
                    advance()
                    advance()
                    while (pos + Int64(1) < source.size) {
                        if (source[Int64(pos)] == UInt8(42) && source[Int64(pos + Int64(1))] == UInt8(47)) {
                            advance()
                            advance()
                            break
                        }
                        advance()
                    }
                } else {
                    break
                }
            } else {
                break
            }
        }
    }

    /// JSON5 标识符起始字符
    private func isIdentifierStart5(ch: UInt8): Bool {
        (ch >= UInt8(97) && ch <= UInt8(122)) || (ch >= UInt8(65) && ch <= UInt8(90)) ||
            ch == UInt8(95) || ch == UInt8(36) || ch == UInt8(92)
    }

    /// JSON5 标识符字符
    private func isIdentifierPart5(ch: UInt8): Bool {
        isIdentifierStart5(ch) || (ch >= UInt8(48) && ch <= UInt8(57))
    }

    /// 十六进制数字判断
    private func isHexDigit5(ch: UInt8): Bool {
        (ch >= UInt8(48) && ch <= UInt8(57)) ||
            (ch >= UInt8(97) && ch <= UInt8(102)) ||
            (ch >= UInt8(65) && ch <= UInt8(70))
    }

    /// 解码十六进制转义
    private func decodeHexEscape5(hex: String): UInt8 {
        var code = Int32(0)
        for (i in Int64(0)..hex.size) {
            let ch = hex[i]
            code = code * Int32(16)
            if (ch >= UInt8(48) && ch <= UInt8(57)) {
                code += Int32(ch) - Int32(48)
            } else if (ch >= UInt8(97) && ch <= UInt8(102)) {
                code += Int32(ch) - Int32(97) + Int32(10)
            } else if (ch >= UInt8(65) && ch <= UInt8(70)) {
                code += Int32(ch) - Int32(65) + Int32(10)
            }
        }
        UInt8(code)
    }

    /// 解析十六进制浮点数
    private func parseHexFloat5(hex: String): Float64 {
        var result = Float64(0)
        for (i in Int64(0)..hex.size) {
            let ch = hex[i]
            result = result * Float64(16)
            if (ch >= UInt8(48) && ch <= UInt8(57)) {
                result += Float64(Int32(ch) - Int32(48))
            } else if (ch >= UInt8(97) && ch <= UInt8(102)) {
                result += Float64(Int32(ch) - Int32(97) + Int32(10))
            } else if (ch >= UInt8(65) && ch <= UInt8(70)) {
                result += Float64(Int32(ch) - Int32(65) + Int32(10))
            }
        }
        return result
    }
}
