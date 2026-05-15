// bao_parsers - TOML 解析器
// 严格翻译自: src/parsers/toml.zig
//   TOML struct - 解析器主结构 (lexer, log, allocator, stack_check)
//   parseKey / parseKeySegment - 键解析 (dotted keys)
//   runParser - 主解析循环 (处理 table/array-of-tables/kv pairs)
//   TOML 值通过 js_ast.Expr 节点表示:
//     E.String, E.Number, E.Boolean, E.Array, E.Object, E.Date
// Bun TOML 解析器用于 bunfig.toml 配置文件解析
package bao_parsers

import bao_core.*
import bao_collections.*

// ============================================================================
// TomlValue - TOML 值类型
// 严格翻译自: src/parsers/toml.zig 中通过 Expr 节点表示的 TOML 值
// Bun TOML 解析器将 TOML 值映射到 js_ast.Expr:
//   String    → E.String{data: string}
//   Integer   → E.Number{value: f64} 或 E.BigInt
//   Float     → E.Number{value: f64}
//   Boolean   → E.Boolean{value: bool}
//   Array     → E.Array{items: BabyList(Expr)}
//   Table     → E.Object{properties: Property.List}
//   Date/Time → E.String{data: string} (ISO 8601 格式)
// ============================================================================

/// TOML 值类型标签
public enum TomlKind {
    | String      // 基本字符串、多行字符串、字面量字符串
    | Integer     // 十进制、十六进制、八进制、二进制
    | Float       // 浮点数 (含 inf, nan)
    | Bool        // true / false
    | Datetime    // RFC 3339 日期时间
    | Date        // 本地日期
    | Time        // 本地时间
    | Array       // TOML 数组
    | Table       // TOML 表 (内联或标准)
}

/// TOML 日期时间 - 对应 RFC 3339
public class TomlDatetime {
    /// 年
    public var year: Int64
    /// 月 (1-12)
    public var month: Int64
    /// 日 (1-31)
    public var day: Int64
    /// 时
    public var hour: Int64
    /// 分
    public var minute: Int64
    /// 秒
    public var second: Int64
    /// 纳秒部分
    public var nanos: Int64
    /// 时区偏移 (分钟), None 表示本地时间
    public var tzOffset: ?Int64
    /// 是否为仅日期
    public var isDateOnly: Bool
    /// 是否为仅时间
    public var isTimeOnly: Bool

    public init() {
        year = Int64(0)
        month = Int64(1)
        day = Int64(1)
        hour = Int64(0)
        minute = Int64(0)
        second = Int64(0)
        nanos = Int64(0)
        tzOffset = None
        isDateOnly = false
        isTimeOnly = false
    }

    /// 格式化为 ISO 8601 字符串
    public func toISO(): String {
        if (isTimeOnly) {
            return "${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}"
        }
        var s = "${year.toString().padStart(4, '0')}-${month.toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}"
        if (!isDateOnly) {
            s += "T${hour.toString().padStart(2, '0')}:${minute.toString().padStart(2, '0')}:${second.toString().padStart(2, '0')}"
            match (tzOffset) {
                case Some(offset) =>
                    if (offset == Int64(0)) {
                        s += "Z"
                    } else {
                        let sign = if (offset >= Int64(0)) { "+" } else { "-" }
                        let absOffset = if (offset >= Int64(0)) { offset } else { -offset }
                        let h = absOffset / Int64(60)
                        let m = absOffset % Int64(60)
                        s += "${sign}${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}"
                    }
                case None => ()
            }
        }
        return s
    }
}

/// TOML 值 - 对应 Bun Expr (TOML 场景)
/// Bun 使用 E.String, E.Number, E.Boolean, E.Array, E.Object 表示 TOML 值
/// 仓颉使用独立的 TomlValue 类
public class TomlValue {
    /// 值类型
    public var kind: TomlKind
    /// 字符串值 - 对应 Bun E.String.data
    public var stringValue: String
    /// 整数值 - 对应 Bun E.Number.value (整数部分)
    public var intValue: Int64
    /// 浮点值 - 对应 Bun E.Number.value
    public var floatValue: Float64
    /// 布尔值 - 对应 Bun E.Boolean.value
    public var boolValue: Bool
    /// 日期时间值
    public var datetimeValue: TomlDatetime
    /// 数组值 - 对应 Bun E.Array.items
    public var arrayValue: ArrayList<TomlValue>
    /// 表值 - 对应 Bun E.Object.properties
    public var tableValue: LinkedHashMap<String, TomlValue>
    /// 是否为整数
    public var isInteger: Bool
    /// 源码位置
    public var offset: Int64

    public init(kind: TomlKind) {
        this.kind = kind
        stringValue = ""
        intValue = Int64(0)
        floatValue = Float64(0)
        boolValue = false
        datetimeValue = TomlDatetime()
        arrayValue = ArrayList<TomlValue>()
        tableValue = LinkedHashMap<String, TomlValue>()
        isInteger = false
        offset = Int64(-1)
    }

    /// 创建字符串值
    public static func str(value: String): TomlValue {
        let v = TomlValue(TomlKind.String)
        v.stringValue = value
        return v
    }

    /// 创建整数值
    public static func integer(value: Int64): TomlValue {
        let v = TomlValue(TomlKind.Integer)
        v.intValue = value
        v.isInteger = true
        return v
    }

    /// 创建浮点值
    public static func float(value: Float64): TomlValue {
        let v = TomlValue(TomlKind.Float)
        v.floatValue = value
        return v
    }

    /// 创建布尔值
    public static func bool(value: Bool): TomlValue {
        let v = TomlValue(TomlKind.Bool)
        v.boolValue = value
        return v
    }

    /// 创建表
    public static func table(): TomlValue {
        return TomlValue(TomlKind.Table)
    }

    /// 创建数组
    public static func array(): TomlValue {
        return TomlValue(TomlKind.Array)
    }

    /// 获取表字段
    public func get(key: String): ?TomlValue {
        if (kind == TomlKind.Table) {
            tableValue.get(key)
        } else {
            None
        }
    }

    /// 获取表字段，带默认值
    public func get(key: String, defaultValue: TomlValue): TomlValue {
        match (get(key)) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    /// 获取字符串
    public func asString(): ?String {
        if (kind == TomlKind.String) { Some(stringValue) } else { None }
    }

    /// 获取整数
    public func asInt(): ?Int64 {
        if (kind == TomlKind.Integer) { Some(intValue) } else { None }
    }

    /// 获取浮点数
    public func asFloat(): ?Float64 {
        if (kind == TomlKind.Float) { Some(floatValue) } else { None }
    }

    /// 获取布尔
    public func asBool(): ?Bool {
        if (kind == TomlKind.Bool) { Some(boolValue) } else { None }
    }

    /// 大小 (数组/表)
    public prop size: Int64 {
        get() {
            match (kind) {
                case TomlKind.Array => arrayValue.size
                case TomlKind.Table => tableValue.size
                case _ => Int64(0)
            }
        }
    }
}

// ============================================================================
// TomlParser - TOML 解析器
// 严格翻译自: src/parsers/toml.zig - TOML struct
// Bun TOML 解析器架构:
//   1. Lexer: 扫描 TOML token (字符串、数字、键、表头)
//   2. parseKey: 解析点分键 (a.b.c)
//   3. runParser: 主循环处理 [table]、[[array-of-tables]]、key = value
//   4. 使用 Rope 链表表示点分键
//   5. 使用 E.Object 嵌套表示 TOML 表层次
// ============================================================================

/// TOML 解析器 - 对应 Bun parsers/toml.zig TOML struct
/// Bun: pub fn parse(source, log, allocator, redact_logs) !Expr
public class TomlParser <: BaseParser {
    /// 当前表路径
    private var currentPath: ArrayList<String>
    /// 根表
    private var root: TomlValue

    public init(source: String) {
        super(source, ParseOptions.tomlDefaults())
        currentPath = ArrayList<String>()
        root = TomlValue.table()
    }

    /// 解析 TOML 文本
    /// 对应 Bun: pub fn parse(source, log, allocator, redact_logs) !Expr
    public func parse(): ParseResult<TomlValue> {
        if (source.size == Int64(0)) {
            let result = ParseResult<TomlValue>(root)
            result.state = ParseState.Success
            return result
        }
        let result = ParseResult<TomlValue>()
        while (pos < source.size) {
            skipWhitespaceAndComments()
            if (pos >= source.size) {
                break
            }
            let ch = source[Int64(pos)]
            match (ch) {
                case '\n' | '\r' => advance()  // 空行
                case '[' =>
                    // 表头或数组表
                    if (!parseTableHeader()) {
                        result.state = ParseState.Error
                    }
                case '=' =>
                    addError(ParseErrorKind.UnexpectedToken,
                        "Unexpected '=' (missing key)")
                    result.state = ParseState.Error
                case _ =>
                    // 键值对: key = value
                    if (!parseKeyValue()) {
                        result.state = ParseState.Error
                    }
            }
        }
        if (hasErrors()) {
            for (err in errors) {
                result.addError(err)
            }
        } else {
            result.value = Some(root)
            result.state = ParseState.Success
        }
        result.consumedBytes = pos
        return result
    }

    /// 跳过空白和注释
    /// 对应 Bun lexer 中跳过空白和 # 注释
    private func skipWhitespaceAndComments(): Unit {
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (ch == ' ' || ch == '\t' || ch == '\r') {
                advance()
            } else if (ch == '#') {
                // 跳过行注释
                while (pos < source.size && source[Int64(pos)] != '\n') {
                    advance()
                }
            } else {
                break
            }
        }
    }

    /// 解析表头 - 对应 Bun runParser 中的 .t_open_bracket 处理
    /// [table] 或 [[array-of-tables]]
    private func parseTableHeader(): Bool {
        advance() // consume first '['
        let isArray = pos < source.size && source[Int64(pos)] == '['
        if (isArray) {
            advance() // consume second '['
        }
        skipWhitespace()
        // 解析点分键
        let keys = parseDottedKey()
        if (keys.size == Int64(0)) {
            addError(ParseErrorKind.InvalidSyntax, "Empty table key")
            return false
        }
        skipWhitespace()
        // 期望 ] 或 ]]
        if (isArray) {
            if (!expect(']') || !expect(']')) {
                addError(ParseErrorKind.ExpectedClosingBracket, "Expected ']]'")
                return false
            }
        } else {
            if (!expect(']')) {
                addError(ParseErrorKind.ExpectedClosingBracket, "Expected ']'")
                return false
            }
        }
        // 更新当前路径
        currentPath = keys
        // 确保路径上的表存在
        if (isArray) {
            ensureArrayTablePath(keys)
        } else {
            ensureTablePath(keys)
        }
        skipToNextLine()
        return true
    }

    /// 解析键值对 - key = value
    /// 对应 Bun runParser 中的 default case (解析键和值)
    private func parseKeyValue(): Bool {
        // 解析键
        let keys = parseDottedKey()
        if (keys.size == Int64(0)) {
            addError(ParseErrorKind.InvalidSyntax, "Expected key")
            return false
        }
        skipWhitespace()
        // 期望 =
        if (!expect('=')) {
            addError(ParseErrorKind.ExpectedColon, "Expected '=' after key")
            return false
        }
        skipWhitespace()
        // 解析值
        let value = parseValue()
        // 设置值到当前表路径下
        setValue(currentPath, keys, value)
        skipToNextLine()
        return true
    }

    /// 解析点分键 - a.b.c
    /// 对应 Bun parseKey / parseKeySegment
    /// Bun: pub fn parseKey(p: *TOML, allocator) !*Rope
    private func parseDottedKey(): ArrayList<String> {
        let keys = ArrayList<String>()
        var key = parseKeySegment()
        if (key == "") {
            return keys
        }
        keys.append(key)
        while (pos < source.size) {
            skipWhitespace()
            if (pos < source.size && source[Int64(pos)] == '.') {
                advance()
                skipWhitespace()
                key = parseKeySegment()
                if (key == "") {
                    addError(ParseErrorKind.InvalidSyntax, "Expected key after '.'")
                    return keys
                }
                keys.append(key)
            } else {
                break
            }
        }
        return keys
    }

    /// 解析单个键段
    /// 对应 Bun parseKeySegment
    /// TOML 键可以是: 裸键 (identifier)、引号字符串、true/false
    private func parseKeySegment(): String {
        if (pos >= source.size) {
            return ""
        }
        let ch = source[Int64(pos)]
        if (ch == '"') {
            // 引号键
            let startLine = line
            let startCol = column
            let sb = StringBuilder()
            advance() // consume "
            while (pos < source.size && source[Int64(pos)] != '"') {
                if (source[Int64(pos)] == '\\') {
                    advance()
                    if (pos < source.size) {
                        sb.append(source[Int64(pos)])
                        advance()
                    }
                } else {
                    sb.append(source[Int64(pos)])
                    advance()
                }
            }
            if (pos < source.size) {
                advance() // consume closing "
            }
            return sb.toString()
        }
        // 裸键: [A-Za-z0-9_-]+
        if (isBareKeyChar(ch)) {
            let start = pos
            while (pos < source.size && isBareKeyChar(source[Int64(pos)])) {
                advance()
            }
            return source[Int64(start)..Int64(pos)]
        }
        return ""
    }

    /// 是否为裸键字符
    private func isBareKeyChar(ch: Char): Bool {
        (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
        (ch >= '0' && ch <= '9') || ch == '-' || ch == '_'
    }

    /// 解析值 - 对应 Bun parseExpr
    /// TOML 值: string, integer, float, bool, datetime, array, inline-table
    private func parseValue(): TomlValue {
        if (pos >= source.size) {
            addError(ParseErrorKind.UnexpectedEof, "Expected value")
            return TomlValue.str("")
        }
        let ch = source[Int64(pos)]
        // 字符串
        if (ch == '"') {
            return parseTOMLString()
        }
        // 单引号字符串 (字面量字符串)
        if (ch == '\'') {
            return parseTOMLLiteralString()
        }
        // 三引号多行字符串
        if (pos + Int64(2) < source.size && source[Int64(pos)] == '"' && source[Int64(pos + Int64(1))] == '"' && source[Int64(pos + Int64(2))] == '"') {
            return parseTOMLMultilineString()
        }
        if (pos + Int64(2) < source.size && source[Int64(pos)] == '\'' && source[Int64(pos + Int64(1))] == '\'' && source[Int64(pos + Int64(2))] == '\'') {
            return parseTOMLMultilineLiteralString()
        }
        // 数组
        if (ch == '[') {
            return parseTOMLArray()
        }
        // 内联表
        if (ch == '{') {
            return parseTOMLInlineTable()
        }
        // true / false
        if (ch == 't' && pos + Int64(4) <= source.size && source[Int64(pos)..Int64(pos + Int64(4))] == "true") {
            pos += Int64(4)
            column += Int64(4)
            return TomlValue.bool(true)
        }
        if (ch == 'f' && pos + Int64(5) <= source.size && source[Int64(pos)..Int64(pos + Int64(5))] == "false") {
            pos += Int64(5)
            column += Int64(5)
            return TomlValue.bool(false)
        }
        // 数字 (含 inf, nan)
        if (ch == '-' || ch == '+' || (ch >= '0' && ch <= '9') ||
            (ch == 'i' && pos + Int64(3) <= source.size && source[Int64(pos)..Int64(pos + Int64(3))] == "inf") ||
            (ch == 'n' && pos + Int64(3) <= source.size && source[Int64(pos)..Int64(pos + Int64(3))] == "nan")) {
            return parseTOMLNumber()
        }
        addError(ParseErrorKind.UnexpectedCharacter, "Unexpected character '${ch}' in value")
        return TomlValue.str("")
    }

    /// 解析 TOML 基本字符串 - 对应 Bun lexer toString
    private func parseTOMLString(): TomlValue {
        advance() // consume "
        let sb = StringBuilder()
        while (pos < source.size && source[Int64(pos)] != '"') {
            if (source[Int64(pos)] == '\\') {
                advance()
                if (pos < source.size) {
                    let escaped = source[Int64(pos)]
                    advance()
                    match (escaped) {
                        case '"' => sb.append('"')
                        case '\\' => sb.append('\\')
                        case 'b' => sb.append('\b')
                        case 'f' => sb.append('\f')
                        case 'n' => sb.append('\n')
                        case 'r' => sb.append('\r')
                        case 't' => sb.append('\t')
                        case 'u' => sb.append(decodeUnicodeEscape(Int64(4)))
                        case 'U' => sb.append(decodeUnicodeEscape(Int64(8)))
                        case _ => sb.append(escaped)
                    }
                }
            } else {
                sb.append(source[Int64(pos)])
                advance()
            }
        }
        if (pos < source.size) {
            advance() // consume closing "
        }
        return TomlValue.str(sb.toString())
    }

    /// 解析字面量字符串 (不处理转义)
    private func parseTOMLLiteralString(): TomlValue {
        advance() // consume '
        let sb = StringBuilder()
        while (pos < source.size && source[Int64(pos)] != '\'') {
            sb.append(source[Int64(pos)])
            advance()
        }
        if (pos < source.size) {
            advance() // consume closing '
        }
        return TomlValue.str(sb.toString())
    }

    /// 解析多行字符串 """
    private func parseTOMLMultilineString(): TomlValue {
        pos += Int64(3)
        column += Int64(3)
        // 跳过第一个换行
        if (pos < source.size && source[Int64(pos)] == '\n') {
            advance()
        }
        let sb = StringBuilder()
        while (pos + Int64(2) < source.size) {
            if (source[Int64(pos)] == '"' && source[Int64(pos + Int64(1))] == '"' && source[Int64(pos + Int64(2))] == '"') {
                pos += Int64(3)
                column += Int64(3)
                return TomlValue.str(sb.toString())
            }
            if (source[Int64(pos)] == '\\') {
                advance()
                // 行尾反斜杠: trim trailing whitespace
                if (pos < source.size && source[Int64(pos)] == '\n') {
                    advance()
                    while (pos < source.size && (source[Int64(pos)] == ' ' || source[Int64(pos)] == '\t' || source[Int64(pos)] == '\n')) {
                        advance()
                    }
                } else if (pos < source.size) {
                    let escaped = source[Int64(pos)]
                    advance()
                    match (escaped) {
                        case '"' => sb.append('"')
                        case '\\' => sb.append('\\')
                        case 'b' => sb.append('\b')
                        case 'f' => sb.append('\f')
                        case 'n' => sb.append('\n')
                        case 'r' => sb.append('\r')
                        case 't' => sb.append('\t')
                        case _ => sb.append('\\').append(escaped)
                    }
                }
            } else {
                sb.append(source[Int64(pos)])
                advance()
            }
        }
        addError(ParseErrorKind.UnterminatedString, "Unterminated multi-line string")
        return TomlValue.str(sb.toString())
    }

    /// 解析多行字面量字符串 '''
    private func parseTOMLMultilineLiteralString(): TomlValue {
        pos += Int64(3)
        column += Int64(3)
        if (pos < source.size && source[Int64(pos)] == '\n') {
            advance()
        }
        let sb = StringBuilder()
        while (pos + Int64(2) < source.size) {
            if (source[Int64(pos)] == '\'' && source[Int64(pos + Int64(1))] == '\'' && source[Int64(pos + Int64(2))] == '\'') {
                pos += Int64(3)
                column += Int64(3)
                return TomlValue.str(sb.toString())
            }
            sb.append(source[Int64(pos)])
            advance()
        }
        addError(ParseErrorKind.UnterminatedString, "Unterminated multi-line literal string")
        return TomlValue.str(sb.toString())
    }

    /// 解析 TOML 数字 (整数/浮点/inf/nan)
    /// 对应 Bun lexer 中的数字解析
    private func parseTOMLNumber(): TomlValue {
        let start = pos
        // 可选正负号
        if (pos < source.size && (source[Int64(pos)] == '+' || source[Int64(pos)] == '-')) {
            advance()
        }
        // inf
        if (pos + Int64(3) <= source.size && source[Int64(pos)..Int64(pos + Int64(3))] == "inf") {
            pos += Int64(3)
            let sign = if (source[Int64(start)] == '-') { Float64(-1) } else { Float64(1) }
            return TomlValue.float(sign * Float64.infinity)
        }
        // nan
        if (pos + Int64(3) <= source.size && source[Int64(pos)..Int64(pos + Int64(3))] == "nan") {
            pos += Int64(3)
            return TomlValue.float(Float64.nan)
        }
        var isFloat = false
        // 十六进制 0x
        if (pos + Int64(1) < source.size && source[Int64(pos)] == '0' && source[Int64(pos + Int64(1))] == 'x') {
            advance()
            advance()
            let numStart = pos
            while (pos < source.size && isHexDigit(source[Int64(pos)])) {
                advance()
            }
            let hexStr = source[Int64(numStart)..Int64(pos)]
            return TomlValue.integer(parseIntHex(hexStr))
        }
        // 八进制 0o
        if (pos + Int64(1) < source.size && source[Int64(pos)] == '0' && source[Int64(pos + Int64(1))] == 'o') {
            advance()
            advance()
            let numStart = pos
            while (pos < source.size && source[Int64(pos)] >= '0' && source[Int64(pos)] <= '7') {
                advance()
            }
            let octStr = source[Int64(numStart)..Int64(pos)]
            return TomlValue.integer(parseIntOctal(octStr))
        }
        // 二进制 0b
        if (pos + Int64(1) < source.size && source[Int64(pos)] == '0' && source[Int64(pos + Int64(1))] == 'b') {
            advance()
            advance()
            let numStart = pos
            while (pos < source.size && (source[Int64(pos)] == '0' || source[Int64(pos)] == '1')) {
                advance()
            }
            let binStr = source[Int64(numStart)..Int64(pos)]
            return TomlValue.integer(parseIntBinary(binStr))
        }
        // 十进制整数部分
        while (pos < source.size && source[Int64(pos)] >= '0' && source[Int64(pos)] <= '9') {
            advance()
        }
        // 下划线分隔符 (TOML 允许)
        while (pos < source.size && (source[Int64(pos)] == '_' || (source[Int64(pos)] >= '0' && source[Int64(pos)] <= '9'))) {
            advance()
        }
        // 小数部分
        if (pos < source.size && source[Int64(pos)] == '.') {
            isFloat = true
            advance()
            while (pos < source.size && (source[Int64(pos)] == '_' || (source[Int64(pos)] >= '0' && source[Int64(pos)] <= '9'))) {
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
            while (pos < source.size && (source[Int64(pos)] == '_' || (source[Int64(pos)] >= '0' && source[Int64(pos)] <= '9'))) {
                advance()
            }
        }
        let numStr = stripUnderscores(source[Int64(start)..Int64(pos)])
        if (isFloat) {
            return TomlValue.float(Float64(numStr))
        } else {
            return TomlValue.integer(Int64(numStr))
        }
    }

    /// 解析 TOML 数组 - 对应 Bun parseExpr 中 .t_open_bracket case
    private func parseTOMLArray(): TomlValue {
        let arr = TomlValue.array()
        advance() // consume [
        skipWhitespaceAndComments()
        // 跳过换行
        while (pos < source.size && source[Int64(pos)] == '\n') {
            advance()
            skipWhitespaceAndComments()
        }
        if (pos < source.size && source[Int64(pos)] == ']') {
            advance()
            return arr
        }
        while (true) {
            skipWhitespaceAndComments()
            while (pos < source.size && source[Int64(pos)] == '\n') {
                advance()
                skipWhitespaceAndComments()
            }
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedArray, "Unterminated array")
                return arr
            }
            if (source[Int64(pos)] == ']') {
                advance()
                return arr
            }
            let value = parseValue()
            arr.arrayValue.append(value)
            skipWhitespaceAndComments()
            while (pos < source.size && source[Int64(pos)] == '\n') {
                advance()
                skipWhitespaceAndComments()
            }
            if (pos < source.size && source[Int64(pos)] == ',') {
                advance()
                skipWhitespaceAndComments()
                while (pos < source.size && source[Int64(pos)] == '\n') {
                    advance()
                    skipWhitespaceAndComments()
                }
            }
        }
        return arr
    }

    /// 解析内联表 - { key = value, ... }
    private func parseTOMLInlineTable(): TomlValue {
        let tbl = TomlValue.table()
        advance() // consume {
        skipWhitespace()
        if (pos < source.size && source[Int64(pos)] == '}') {
            advance()
            return tbl
        }
        while (true) {
            skipWhitespace()
            let keys = parseDottedKey()
            if (keys.size == Int64(0)) {
                addError(ParseErrorKind.InvalidSyntax, "Expected key in inline table")
                return tbl
            }
            skipWhitespace()
            if (!expect('=')) {
                addError(ParseErrorKind.ExpectedColon, "Expected '=' in inline table")
                return tbl
            }
            skipWhitespace()
            let value = parseValue()
            // 设置到内联表
            setNestedValue(tbl, keys, value)
            skipWhitespace()
            if (pos < source.size && source[Int64(pos)] == ',') {
                advance()
            } else if (pos < source.size && source[Int64(pos)] == '}') {
                advance()
                return tbl
            } else {
                addError(ParseErrorKind.ExpectedClosingBrace, "Expected ',' or '}'")
                return tbl
            }
        }
        return tbl
    }

    // ========================================================================
    // 表路径操作
    // ========================================================================

    /// 确保表路径存在
    private func ensureTablePath(keys: ArrayList<String>): Unit {
        var current = root
        for (key in keys) {
            let child = current.tableValue.get(key)
            match (child) {
                case Some(v) => current = v
                case None =>
                    let newTable = TomlValue.table()
                    current.tableValue.put(key, newTable)
                    current = newTable
            }
        }
    }

    /// 确保数组表路径存在
    private func ensureArrayTablePath(keys: ArrayList<String>): Unit {
        var current = root
        for (i in Int64(0)..keys.size) {
            let key = keys[i]
            let isLast = i == keys.size - Int64(1)
            let child = current.tableValue.get(key)
            match (child) {
                case Some(v) =>
                    if (isLast && v.kind == TomlKind.Array) {
                        // 添加新元素到已有数组
                        let newTable = TomlValue.table()
                        v.arrayValue.append(newTable)
                        current = newTable
                    } else {
                        current = v
                    }
                case None =>
                    if (isLast) {
                        // 创建新数组表
                        let arr = TomlValue.array()
                        let newTable = TomlValue.table()
                        arr.arrayValue.append(newTable)
                        current.tableValue.put(key, arr)
                        current = newTable
                    } else {
                        let newTable = TomlValue.table()
                        current.tableValue.put(key, newTable)
                        current = newTable
                    }
            }
        }
    }

    /// 设置值到指定路径
    private func setValue(tablePath: ArrayList<String>, keys: ArrayList<String>, value: TomlValue): Unit {
        var current = root
        for (key in tablePath) {
            match (current.tableValue.get(key)) {
                case Some(v) => current = v
                case None => return  // 路径不存在
            }
        }
        setNestedValue(current, keys, value)
    }

    /// 在表中设置嵌套值
    private func setNestedValue(table: TomlValue, keys: ArrayList<String>, value: TomlValue): Unit {
        if (keys.size == Int64(1)) {
            table.tableValue.put(keys[Int64(0)], value)
            return
        }
        var current = table
        for (i in Int64(0)..keys.size - Int64(1)) {
            let key = keys[i]
            let child = current.tableValue.get(key)
            match (child) {
                case Some(v) => current = v
                case None =>
                    let newTable = TomlValue.table()
                    current.tableValue.put(key, newTable)
                    current = newTable
            }
        }
        current.tableValue.put(keys[keys.size - Int64(1)], value)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 跳到下一行
    private func skipToNextLine(): Unit {
        while (pos < source.size && source[Int64(pos)] != '\n') {
            advance()
        }
        if (pos < source.size) {
            advance() // skip \n
        }
    }

    /// 移除数字中的下划线
    private func stripUnderscores(s: String): String {
        let sb = StringBuilder()
        for (ch in s) {
            if (ch != '_') {
                sb.append(ch)
            }
        }
        return sb.toString()
    }

    private func isHexDigit(ch: Char): Bool {
        (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F')
    }

    private func parseIntHex(s: String): Int64 {
        var result = Int64(0)
        for (ch in s) {
            result = result * Int64(16)
            if (ch >= '0' && ch <= '9') {
                result += Int64(ch.value - '0'.value)
            } else if (ch >= 'a' && ch <= 'f') {
                result += Int64(ch.value - 'a'.value) + Int64(10)
            } else if (ch >= 'A' && ch <= 'F') {
                result += Int64(ch.value - 'A'.value) + Int64(10)
            }
        }
        return result
    }

    private func parseIntOctal(s: String): Int64 {
        var result = Int64(0)
        for (ch in s) {
            result = result * Int64(8) + Int64(ch.value - '0'.value)
        }
        return result
    }

    private func parseIntBinary(s: String): Int64 {
        var result = Int64(0)
        for (ch in s) {
            result = result * Int64(2) + Int64(ch.value - '0'.value)
        }
        return result
    }

    private func decodeUnicodeEscape(len: Int64): Char {
        var code = Int32(0)
        var count = Int64(0)
        while (count < len && pos < source.size) {
            let ch = source[Int64(pos)]
            code = code * Int32(16)
            if (ch >= '0' && ch <= '9') {
                code += Int32(ch.value) - Int32('0'.value)
            } else if (ch >= 'a' && ch <= 'f') {
                code += Int32(ch.value) - Int32('a'.value) + Int32(10)
            } else if (ch >= 'A' && ch <= 'F') {
                code += Int32(ch.value) - Int32('A'.value) + Int32(10)
            }
            advance()
            count += Int64(1)
        }
        return Char(code)
    }
}

// ============================================================================
// TOML 序列化
// 严格翻译自: Bun 中 TOML 的序列化 (用于 bunfig.toml 生成)
// ============================================================================

/// TOML 序列化器
public class TOMLStringify {
    /// 序列化 TOML 值为字符串
    public static func stringify(value: TomlValue): String {
        let sb = StringBuilder()
        stringifyTable(value, sb, "")
        return sb.toString()
    }

    private static func stringifyTable(value: TomlValue, sb: StringBuilder, prefix: String): Unit {
        if (value.kind != TomlKind.Table) {
            return
        }
        let keys = value.tableValue.keys()
        // 先输出简单值
        for (key in keys) {
            match (value.tableValue.get(key)) {
                case Some(v) =>
                    if (v.kind != TomlKind.Table && v.kind != TomlKind.Array) {
                        sb.append(key)
                        sb.append(" = ")
                        stringifyValue(v, sb)
                        sb.append('\n')
                    }
                case None => ()
            }
        }
        // 输出子表和数组表
        for (key in keys) {
            match (value.tableValue.get(key)) {
                case Some(v) =>
                    if (v.kind == TomlKind.Table) {
                        sb.append('\n')
                        let newPrefix = if (prefix.size > Int64(0)) { "${prefix}.${key}" } else { key }
                        sb.append("[${newPrefix}]\n")
                        stringifyTable(v, sb, newPrefix)
                    } else if (v.kind == TomlKind.Array) {
                        let newPrefix = if (prefix.size > Int64(0)) { "${prefix}.${key}" } else { key }
                        for (item in v.arrayValue) {
                            sb.append('\n')
                            sb.append("[[${newPrefix}]]\n")
                            stringifyTable(item, sb, newPrefix)
                        }
                    }
                case None => ()
            }
        }
    }

    private static func stringifyValue(value: TomlValue, sb: StringBuilder): Unit {
        match (value.kind) {
            case TomlKind.String => {
                sb.append('"')
                escapeTOMLString(value.stringValue, sb)
                sb.append('"')
            }
            case TomlKind.Integer => sb.append(value.intValue.toString())
            case TomlKind.Float => sb.append(value.floatValue.toString())
            case TomlKind.Bool => sb.append(if (value.boolValue) { "true" } else { "false" })
            case TomlKind.Array => {
                sb.append('[')
                var first = true
                for (item in value.arrayValue) {
                    if (!first) { sb.append(", ") }
                    first = false
                    stringifyValue(item, sb)
                }
                sb.append(']')
            }
            case _ => sb.append("\"unknown\"")
        }
    }

    private static func escapeTOMLString(s: String, sb: StringBuilder): Unit {
        for (ch in s) {
            match (ch) {
                case '"' => sb.append("\\\"")
                case '\\' => sb.append("\\\\")
                case '\b' => sb.append("\\b")
                case '\f' => sb.append("\\f")
                case '\n' => sb.append("\\n")
                case '\r' => sb.append("\\r")
                case '\t' => sb.append("\\t")
                case _ => sb.append(ch)
            }
        }
    }
}
