// bao_parsers - JSON 解析器
// 严格翻译自: src/parsers/json.zig
//   JSONLikeParser - JSON/JSON5/JSON-with-comments 解析器
//   json_lexer.rs  - JSON 词法分析器
// Bun JSON 解析器架构:
//   1. Lexer 扫描源文本生成 Token
//   2. Parser 消费 Token 构建 AST Expr 节点
//   3. 支持严格 JSON、JSONC (带注释)、JSON5 三种模式
//   4. 使用 StackCheck 防止递归溢出
//   5. 使用 HashMapPool 复用临时 HashMap
package bao_parsers

import bao_core.*
import bao_collections.*

// ============================================================================
// JsonValue - JSON 值类型
// 严格翻译自: src/parsers/json.zig 中的 Expr 节点
// Bun 使用 js_ast.Expr 表示 JSON 值:
//   E.Null, E.Boolean, E.String, E.Number{value: f64},
//   E.Array{items}, E.Object{properties}
// 仓颉使用 tagged union 类
// ============================================================================

/// JSON 值类型 - 对应 Bun Expr 的 JSON 子集
/// Bun: switch(expr.data) { .e_null, .e_boolean, .e_string, .e_number, .e_array, .e_object }
public enum JsonKind {
    | Null
    | Bool
    | Number
    | String
    | Array
    | Object
}

/// JSON 值 - 对应 Bun Expr (JSON 场景)
/// Bun: Expr = struct { loc: Loc, data: Data }
/// 仓颉: JsonValue 封装所有 JSON 值类型
public class JsonValue {
    /// 值类型
    public var kind: JsonKind
    /// 布尔值
    public var boolValue: Bool
    /// 数字值 - 对应 Bun E.Number.value: f64
    public var numberValue: Float64
    /// 字符串值 - 对应 Bun E.String.data: string
    public var stringValue: String
    /// 数组值 - 对应 Bun E.Array.items: BabyList(Expr)
    public var arrayValue: ArrayList<JsonValue>
    /// 对象值 - 对应 Bun E.Object.properties
    public var objectValue: LinkedHashMap<String, JsonValue>
    /// 源码位置 - 对应 Bun loc: logger.Loc
    public var offset: Int64

    /// 空值 - 对应 Bun E.Null{}
    public static let NULL: JsonValue = JsonValue(JsonKind.Null)

    /// 真值
    public static let TRUE: JsonValue = JsonValue(JsonKind.Bool, true)

    /// 假值
    public static let FALSE: JsonValue = JsonValue(JsonKind.Bool, false)

    public init(kind: JsonKind) {
        this.kind = kind
        this.boolValue = false
        this.numberValue = Float64(0)
        this.stringValue = ""
        this.arrayValue = ArrayList<JsonValue>()
        this.objectValue = LinkedHashMap<String, JsonValue>()
        this.offset = Int64(-1)
    }

    public init(kind: JsonKind, boolValue: Bool) {
        this.kind = kind
        this.boolValue = boolValue
        this.numberValue = Float64(0)
        this.stringValue = ""
        this.arrayValue = ArrayList<JsonValue>()
        this.objectValue = LinkedHashMap<String, JsonValue>()
        this.offset = Int64(-1)
    }

    public init(kind: JsonKind, numberValue: Float64) {
        this.kind = kind
        this.boolValue = false
        this.numberValue = numberValue
        this.stringValue = ""
        this.arrayValue = ArrayList<JsonValue>()
        this.objectValue = LinkedHashMap<String, JsonValue>()
        this.offset = Int64(-1)
    }

    public init(kind: JsonKind, stringValue: String) {
        this.kind = kind
        this.boolValue = false
        this.numberValue = Float64(0)
        this.stringValue = stringValue
        this.arrayValue = ArrayList<JsonValue>()
        this.objectValue = LinkedHashMap<String, JsonValue>()
        this.offset = Int64(-1)
    }

    /// 是否为 null
    public func isNull(): Bool {
        kind == JsonKind.Null
    }

    /// 是否为布尔值
    public func isBool(): Bool {
        kind == JsonKind.Bool
    }

    /// 是否为数字
    public func isNumber(): Bool {
        kind == JsonKind.Number
    }

    /// 是否为字符串
    public func isString(): Bool {
        kind == JsonKind.String
    }

    /// 是否为数组
    public func isArray(): Bool {
        kind == JsonKind.Array
    }

    /// 是否为对象
    public func isObject(): Bool {
        kind == JsonKind.Object
    }

    /// 获取对象字段
    public func get(key: String): ?JsonValue {
        if (kind != JsonKind.Object) {
            return None
        }
        objectValue.get(key)
    }

    /// 获取对象字段，带默认值
    public func get(key: String, defaultValue: JsonValue): JsonValue {
        match (get(key)) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    /// 获取数组元素
    public func get(index: Int64): ?JsonValue {
        if (kind != JsonKind.Array || index < Int64(0) || index >= arrayValue.size) {
            return None
        }
        Some(arrayValue[index])
    }

    /// 获取字符串值
    public func asString(): ?String {
        if (kind == JsonKind.String) {
            Some(stringValue)
        } else {
            None
        }
    }

    /// 获取整数值
    public func asInt(): ?Int64 {
        if (kind == JsonKind.Number) {
            Some(Int64(numberValue))
        } else {
            None
        }
    }

    /// 获取浮点值
    public func asFloat(): ?Float64 {
        if (kind == JsonKind.Number) {
            Some(numberValue)
        } else {
            None
        }
    }

    /// 获取布尔值
    public func asBool(): ?Bool {
        if (kind == JsonKind.Bool) {
            Some(boolValue)
        } else {
            None
        }
    }

    /// 数组/对象大小
    public prop size: Int64 {
        get() {
            match (kind) {
                case JsonKind.Array => arrayValue.size
                case JsonKind.Object => objectValue.size
                case _ => Int64(0)
            }
        }
    }

    /// 深度克隆
    public func deepClone(): JsonValue {
        let clone = JsonValue(kind)
        clone.boolValue = boolValue
        clone.numberValue = numberValue
        clone.stringValue = stringValue
        clone.offset = offset
        for (item in arrayValue) {
            clone.arrayValue.append(item.deepClone())
        }
        let keys = objectValue.keys()
        for (key in keys) {
            match (objectValue.get(key)) {
                case Some(v) => clone.objectValue.put(key, v.deepClone())
                case None => ()
            }
        }
        return clone
    }
}

// ============================================================================
// LinkedHashMap - 保持插入顺序的映射
// JSON 对象需要保持键的顺序 (对应 Bun E.Object.properties 的顺序保证)
// ============================================================================

/// 保持插入顺序的 Map - 对应 Bun E.Object.properties 的有序特性
public class LinkedHashMap<K, V> {
    private var entries: ArrayList<K>
    private var values: HashMap<K, V>

    public init() {
        entries = ArrayList<K>()
        values = HashMap<K, V>()
    }

    public func put(key: K, value: V): Unit {
        if (!values.containsKey(key)) {
            entries.append(key)
        }
        values.put(key, value)
    }

    public func get(key: K): ?V {
        values.get(key)
    }

    public func containsKey(key: K): Bool {
        values.containsKey(key)
    }

    public func remove(key: K): Unit {
        values.remove(key)
        let idx = entries.indexOf(key)
        if (idx >= Int64(0)) {
            entries.removeAt(idx)
        }
    }

    public prop size: Int64 {
        get() { entries.size }
    }

    public func keys(): ArrayList<K> {
        entries
    }

    public func values(): ArrayList<V> {
        let result = ArrayList<V>()
        for (key in entries) {
            match (values.get(key)) {
                case Some(v) => result.append(v)
                case None => ()
            }
        }
        return result
    }

    public func clear(): Unit {
        entries.clear()
        values.clear()
    }
}

// ============================================================================
// JSONParser - JSON 解析器
// 严格翻译自: src/parsers/json.zig - JSONLikeParser
// Bun: pub fn JSONLikeParser(comptime opts: JSONOptions) type
//   - 使用 comptime 选项特化解析器 (严格JSON/JSONC/JSON5)
//   - 递归下降解析
//   - StackCheck 防止栈溢出
//   - 错误通过 logger.Log 收集
// 仓颉: 运行时选项 + BaseParser 基类
// ============================================================================

/// JSON 解析器 - 对应 Bun JSONLikeParser
/// Bun: pub fn parseExpr(p: *Parser, ...) anyerror!Expr
public class JSONParser <: BaseParser {
    /// 是否严格 JSON 模式
    private var strictJson: Bool

    public init(source: String) {
        super(source, ParseOptions.jsonDefaults())
        strictJson = true
    }

    public init(source: String, options: ParseOptions) {
        super(source, options)
        strictJson = options.strict
    }

    /// 解析 JSON 文本
    /// 对应 Bun: pub fn parse(source, log, allocator) !Expr
    public func parse(): ParseResult<JsonValue> {
        if (source.size == Int64(0)) {
            let err = ParseError(ParseErrorKind.UnexpectedEof, "Empty input")
            let result = ParseResult<JsonValue>()
            result.addError(err)
            return result
        }
        skipWhitespace()
        let value = parseValue()
        let result = ParseResult<JsonValue>()
        if (hasErrors()) {
            for (err in errors) {
                result.addError(err)
            }
        } else {
            // 检查尾部数据
            skipWhitespace()
            if (pos < source.size) {
                result.addError(ParseError(
                    ParseErrorKind.TrailingData,
                    "Unexpected data after JSON value",
                    pos, line, column))
            } else {
                result.value = Some(value)
                result.state = ParseState.Success
            }
        }
        result.consumedBytes = pos
        return result
    }

    /// 解析值 - 对应 Bun parseExpr()
    /// Bun: switch(p.lexer.token) { .t_false => ..., .t_true => ..., ... }
    private func parseValue(): JsonValue {
        if (!enterRecursive()) {
            return JsonValue.NULL
        }
        skipWhitespace()
        if (pos >= source.size) {
            addError(ParseErrorKind.UnexpectedEof, "Unexpected end of input")
            exitRecursive()
            return JsonValue.NULL
        }
        let ch = source[Int64(pos)]
        let value = match (ch) {
            case '{' => parseObject()
            case '[' => parseArray()
            case '"' => parseString()
            case '\'' =>
                if (!strictJson) {
                    parseString()
                } else {
                    addError(ParseErrorKind.UnexpectedCharacter,
                        "Single quotes are not allowed in strict JSON")
                    JsonValue.NULL
                }
            case 't' => parseLiteral("true", JsonValue.TRUE)
            case 'f' => parseLiteral("false", JsonValue.FALSE)
            case 'n' => parseLiteral("null", JsonValue.NULL)
            case '-' | '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' => parseNumber()
            case _ =>
                addError(ParseErrorKind.UnexpectedCharacter,
                    "Unexpected character '${ch}'")
                JsonValue.NULL
        }
        exitRecursive()
        return value
    }

    /// 解析对象 - 对应 Bun parseObject()
    /// Bun: .t_open_brace => { try p.lexer.next(); ... parse properties ... }
    private func parseObject(): JsonValue {
        let obj = JsonValue(JsonKind.Object)
        obj.offset = pos
        advance() // consume '{'
        skipWhitespace()
        // 空对象
        if (pos < source.size && source[Int64(pos)] == '}') {
            advance()
            return obj
        }
        while (true) {
            skipWhitespace()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedObject, "Unterminated object")
                return obj
            }
            // 解析键
            var key = ""
            let ch = source[Int64(pos)]
            if (ch == '"') {
                key = parseStringContent()
            } else if (ch == '\'' && !strictJson) {
                key = parseStringContent()
            } else if (!strictJson && isIdentifierStart(ch)) {
                // JSON5 允许无引号键
                key = parseIdentifier()
            } else {
                addError(ParseErrorKind.ExpectedColon, "Expected string key")
                return obj
            }
            skipWhitespace()
            // 期望冒号
            if (pos >= source.size || source[Int64(pos)] != ':') {
                addError(ParseErrorKind.ExpectedColon, "Expected ':' after key")
                return obj
            }
            advance() // consume ':'
            skipWhitespace()
            // 解析值
            let value = parseValue()
            obj.objectValue.put(key, value)
            skipWhitespace()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedObject, "Unterminated object")
                return obj
            }
            let next = source[Int64(pos)]
            if (next == '}') {
                advance()
                return obj
            }
            if (next == ',') {
                advance()
                // 允许尾逗号
                if (!strictJson || options.allowTrailingCommas) {
                    skipWhitespace()
                    if (pos < source.size && source[Int64(pos)] == '}') {
                        advance()
                        return obj
                    }
                }
            } else {
                addError(ParseErrorKind.ExpectedComma, "Expected ',' or '}'")
                return obj
            }
        }
        return obj
    }

    /// 解析数组 - 对应 Bun parseArray()
    /// Bun: .t_open_bracket => { ... parse elements ... }
    private func parseArray(): JsonValue {
        let arr = JsonValue(JsonKind.Array)
        arr.offset = pos
        advance() // consume '['
        skipWhitespace()
        // 空数组
        if (pos < source.size && source[Int64(pos)] == ']') {
            advance()
            return arr
        }
        while (true) {
            skipWhitespace()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedArray, "Unterminated array")
                return arr
            }
            let value = parseValue()
            arr.arrayValue.append(value)
            skipWhitespace()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedArray, "Unterminated array")
                return arr
            }
            let next = source[Int64(pos)]
            if (next == ']') {
                advance()
                return arr
            }
            if (next == ',') {
                advance()
                // 允许尾逗号
                if (!strictJson || options.allowTrailingCommas) {
                    skipWhitespace()
                    if (pos < source.size && source[Int64(pos)] == ']') {
                        advance()
                        return arr
                    }
                }
            } else {
                addError(ParseErrorKind.ExpectedComma, "Expected ',' or ']'")
                return arr
            }
        }
        return arr
    }

    /// 解析字符串 - 对应 Bun parseString()
    /// Bun: .t_string_literal => { ... decode string ... }
    private func parseString(): JsonValue {
        let text = parseStringContent()
        return JsonValue(JsonKind.String, text)
    }

    /// 解析字符串内容 - 对应 Bun lexer 中的字符串解码
    private func parseStringContent(): String {
        let quote = source[Int64(pos)]
        advance() // consume quote char
        let sb = StringBuilder()
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (ch == quote) {
                advance()
                return sb.toString()
            }
            if (ch == '\\') {
                advance()
                if (pos >= source.size) {
                    addError(ParseErrorKind.UnterminatedString, "Unterminated string escape")
                    return sb.toString()
                }
                let escaped = source[Int64(pos)]
                advance()
                match (escaped) {
                    case '"' => sb.append('"')
                    case '\\' => sb.append('\\')
                    case '/' => sb.append('/')
                    case 'b' => sb.append('\b')
                    case 'f' => sb.append('\f')
                    case 'n' => sb.append('\n')
                    case 'r' => sb.append('\r')
                    case 't' => sb.append('\t')
                    case 'u' => {
                        // Unicode 转义 \uXXXX
                        if (pos + Int64(4) > source.size) {
                            addError(ParseErrorKind.InvalidEscape, "Incomplete unicode escape")
                            return sb.toString()
                        }
                        let hex = source[Int64(pos)..Int64(pos + Int64(4))]
                        pos += Int64(4)
                        sb.append(decodeHexEscape(hex))
                    }
                    case _ =>
                        if (strictJson) {
                            addError(ParseErrorKind.InvalidEscape,
                                "Invalid escape sequence '\\${escaped}'")
                        } else {
                            sb.append(escaped)
                        }
                }
            } else {
                if (ch == '\n' || ch == '\r') {
                    addError(ParseErrorKind.UnterminatedString, "Unterminated string")
                    return sb.toString()
                }
                sb.append(ch)
                advance()
            }
        }
        addError(ParseErrorKind.UnterminatedString, "Unterminated string")
        return sb.toString()
    }

    /// 解析数字 - 对应 Bun lexer 中的数字解析
    /// Bun: .t_numeric_literal => { ... parse number ... }
    private func parseNumber(): JsonValue {
        let start = pos
        var isFloat = false
        // 可选负号
        if (pos < source.size && source[Int64(pos)] == '-') {
            advance()
        }
        // 整数部分
        if (pos < source.size && source[Int64(pos)] == '0') {
            advance()
            // 严格模式禁止前导零
            if (strictJson && pos < source.size) {
                let next = source[Int64(pos)]
                if (next >= '0' && next <= '9') {
                    addError(ParseErrorKind.LeadingZeros, "Leading zeros not allowed")
                }
            }
        } else {
            while (pos < source.size && source[Int64(pos)] >= '0' && source[Int64(pos)] <= '9') {
                advance()
            }
        }
        // 小数部分
        if (pos < source.size && source[Int64(pos)] == '.') {
            isFloat = true
            advance()
            while (pos < source.size && source[Int64(pos)] >= '0' && source[Int64(pos)] <= '9') {
                advance()
            }
        }
        // 指数部分
        if (pos < source.size && (source[Int64(pos)] == 'e' || source[Int64(pos)] == 'E')) {
            isFloat = true
            advance()
            if (pos < source.size && (source[Int64(pos)] == '+' || source[Int64(pos)] == '-')) {
                advance()
            }
            while (pos < source.size && source[Int64(pos)] >= '0' && source[Int64(pos)] <= '9') {
                advance()
            }
        }
        let numStr = source[Int64(start)..Int64(pos)]
        let num = Float64(numStr)
        return JsonValue(JsonKind.Number, num)
    }

    /// 解析 true/false/null 字面量
    /// 对应 Bun: .t_false => newExpr(E.Boolean{.value = false}, loc)
    private func parseLiteral(expected: String, value: JsonValue): JsonValue {
        let end = pos + Int64(expected.size)
        if (end <= source.size) {
            let actual = source[Int64(pos)..Int64(end)]
            if (actual == expected) {
                pos = end
                column += Int64(expected.size)
                return value
            }
        }
        addError(ParseErrorKind.InvalidSyntax,
            "Expected '${expected}'")
        return JsonValue.NULL
    }

    /// 解析标识符 (JSON5 无引号键)
    private func parseIdentifier(): String {
        let start = pos
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (isIdentifierPart(ch)) {
                advance()
            } else {
                break
            }
        }
        return source[Int64(start)..Int64(pos)]
    }

    /// 是否是标识符起始字符
    private func isIdentifierStart(ch: Char): Bool {
        (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_' || ch == '$'
    }

    /// 是否是标识符字符
    private func isIdentifierPart(ch: Char): Bool {
        isIdentifierStart(ch) || (ch >= '0' && ch <= '9')
    }

    /// 解码十六进制转义
    private func decodeHexEscape(hex: String): Char {
        var code = Int32(0)
        for (i in Int64(0)..hex.size) {
            let ch = hex[i]
            code = code * Int32(16)
            if (ch >= '0' && ch <= '9') {
                code += Int32(ch.value) - Int32('0'.value)
            } else if (ch >= 'a' && ch <= 'f') {
                code += Int32(ch.value) - Int32('a'.value) + Int32(10)
            } else if (ch >= 'A' && ch <= 'F') {
                code += Int32(ch.value) - Int32('A'.value) + Int32(10)
            }
        }
        Char(code)
    }
}

// ============================================================================
// JSON 序列化 - stringify
// 严格翻译自: src/js_printer/ 中的 JSON 序列化
// Bun: pub fn quoteForJSON(input: []const u8, output: *MutableString, ascii: bool)
// ============================================================================

/// JSON 序列化器 - 对应 Bun js_printer 中的 JSON 输出
public class JSONStringify {
    /// 序列化 JSON 值为字符串
    /// 对应 Bun 中将 AST Expr 打印为 JSON 文本
    public static func stringify(value: JsonValue): String {
        stringify(value, false)
    }

    /// 序列化 JSON 值 (可选缩进)
    public static func stringify(value: JsonValue, pretty: Bool): String {
        let sb = StringBuilder()
        doStringify(value, sb, if (pretty) { Int64(0) } else { Int64(-1) })
        return sb.toString()
    }

    private static func doStringify(value: JsonValue, sb: StringBuilder, indent: Int64): Unit {
        match (value.kind) {
            case JsonKind.Null => sb.append("null")
            case JsonKind.Bool => sb.append(if (value.boolValue) { "true" } else { "false" })
            case JsonKind.Number => {
                let n = value.numberValue
                if (n == Float64(Int64(n)) && !n.isNaN() && !n.isInfinite()) {
                    sb.append(Int64(n).toString())
                } else {
                    sb.append(n.toString())
                }
            }
            case JsonKind.String => {
                sb.append('"')
                escapeString(value.stringValue, sb)
                sb.append('"')
            }
            case JsonKind.Array => {
                if (value.arrayValue.size == Int64(0)) {
                    sb.append("[]")
                    return
                }
                sb.append('[')
                let newIndent = if (indent >= Int64(0)) { indent + Int64(1) } else { Int64(-1) }
                var first = true
                for (item in value.arrayValue) {
                    if (!first) {
                        sb.append(',')
                    }
                    first = false
                    if (newIndent >= Int64(0)) {
                        sb.append('\n')
                        writeIndent(sb, newIndent)
                    }
                    doStringify(item, sb, newIndent)
                }
                if (newIndent >= Int64(0)) {
                    sb.append('\n')
                    writeIndent(sb, indent)
                }
                sb.append(']')
            }
            case JsonKind.Object => {
                if (value.objectValue.size == Int64(0)) {
                    sb.append("{}")
                    return
                }
                sb.append('{')
                let newIndent = if (indent >= Int64(0)) { indent + Int64(1) } else { Int64(-1) }
                var first = true
                let keys = value.objectValue.keys()
                for (key in keys) {
                    match (value.objectValue.get(key)) {
                        case Some(v) =>
                            if (!first) {
                                sb.append(',')
                            }
                            first = false
                            if (newIndent >= Int64(0)) {
                                sb.append('\n')
                                writeIndent(sb, newIndent)
                            }
                            sb.append('"')
                            escapeString(key, sb)
                            sb.append('"')
                            sb.append(':')
                            if (newIndent >= Int64(0)) {
                                sb.append(' ')
                            }
                            doStringify(v, sb, newIndent)
                        case None => ()
                    }
                }
                if (newIndent >= Int64(0)) {
                    sb.append('\n')
                    writeIndent(sb, indent)
                }
                sb.append('}')
            }
        }
    }

    /// 转义字符串 - 对应 Bun quoteForJSON
    /// Bun: pub fn quoteForJSON(input, output, ascii) !void
    private static func escapeString(s: String, sb: StringBuilder): Unit {
        for (ch in s) {
            match (ch) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case '\b' => sb.append("\\b")
                case '\f' => sb.append("\\f")
                case '\n' => sb.append("\\n")
                case '\r' => sb.append("\\r")
                case '\t' => sb.append("\\t")
                case _ =>
                    if (ch.value < Int32(0x20)) {
                        sb.append("\\u")
                        sb.append(hex4(UInt16(ch.value)))
                    } else {
                        sb.append(ch)
                    }
            }
        }
    }

    private static func hex4(value: UInt16): String {
        let hex = "0123456789abcdef"
        var result = ""
        result += hex[Int32((value >> UInt16(12)) & UInt16(0xF))]
        result += hex[Int32((value >> UInt16(8)) & UInt16(0xF))]
        result += hex[Int32((value >> UInt16(4)) & UInt16(0xF))]
        result += hex[Int32(value & UInt16(0xF))]
        return result
    }

    private static func writeIndent(sb: StringBuilder, level: Int64): Unit {
        var i = Int64(0)
        while (i < level) {
            sb.append("  ")
            i += Int64(1)
        }
    }
}

// ============================================================================
// StreamingJSONParser - 流式 JSON 解析器
// 严格翻译自: src/parsers/json.zig 中的增量解析模式
// Bun 本身不直接提供流式 JSON 解析，但在 fetch 响应等场景需要增量解析
// ============================================================================

/// 流式 JSON 解析器 - 用于大文件增量解析
public class StreamingJSONParser {
    /// 缓冲区
    private var buffer: StringBuilder
    /// 已解析的完整值
    private var parsedValues: ArrayList<JsonValue>
    /// 内部解析器
    private var parser: ?JSONParser
    /// 是否已完成
    private var completed: Bool

    public init() {
        buffer = StringBuilder()
        parsedValues = ArrayList<JsonValue>()
        parser = None
        completed = false
    }

    /// 追加数据
    public func feed(chunk: String): Unit {
        if (completed) {
            return
        }
        buffer.append(chunk)
    }

    /// 尝试解析已缓冲的数据
    public func parse(): ParseResult<ArrayList<JsonValue>> {
        let text = buffer.toString()
        let p = JSONParser(text)
        let result = p.parse()
        let output = ParseResult<ArrayList<JsonValue>>()
        if (result.isSuccess()) {
            match (result.getValue()) {
                case Some(v) =>
                    parsedValues.append(v)
                    output.value = Some(parsedValues)
                    output.state = ParseState.Success
                case None => ()
            }
            completed = true
        } else {
            output.errors = result.errors
            output.warnings = result.warnings
            output.state = result.state
        }
        output.consumedBytes = result.consumedBytes
        return output
    }

    /// 是否完成
    public func isComplete(): Bool { completed }

    /// 获取已解析的值
    public func getParsedValues(): ArrayList<JsonValue> { parsedValues }

    /// 重置
    public func reset(): Unit {
        buffer = StringBuilder()
        parsedValues.clear()
        parser = None
        completed = false
    }
}
