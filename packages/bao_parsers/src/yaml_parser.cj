// bao_parsers - YAML 解析器
// 严格翻译自: src/parsers/yaml.zig
//   YAML struct - 解析器主结构
//   parse() - 解析 YAML 文档/流
//   print() - YAML 输出
//   Parser(.utf8) - 编码特化解析器
//   Context, Chomp, Indent - 缩进/上下文控制
// Bun YAML 解析器支持:
//   - 多文档 YAML 流
//   - 块标量 (literal |, folded >)
//   - 流式集合 (flow mapping, flow sequence)
//   - 前置元数据 (front matter, --- 分隔)
// 仓颉实现基本 YAML 解析功能
package bao_parsers

import bao_collections.*
import std.convert.*

// ============================================================================
// YamlValue - YAML 值类型
// 严格翻译自: src/parsers/yaml.zig 中通过 Expr 节点表示的 YAML 值
// Bun YAML 解析器将 YAML 值映射到 js_ast.Expr:
//   null     -> E.Null
//   bool     -> E.Boolean
//   int/float-> E.Number
//   string   -> E.String
//   array    -> E.Array
//   map      -> E.Object
// 仓颉使用独立的 YamlValue 类
// ============================================================================

/// YAML 值类型标签
public enum YamlKind {
    | Null       // null / ~
    | Boolean    // true / false / True / False / TRUE / FALSE
    | Int        // 整数
    | Float      // 浮点数 (含 .inf, .nan)
    | String     // 字符串
    | Array      // 序列 (block 或 flow)
    | Map        // 映射 (block 或 flow)

    public operator func ==(right: YamlKind): Bool {
        match (this) {
            case Null => match (right) { case Null => true; case _ => false }
            case Boolean => match (right) { case Boolean => true; case _ => false }
            case Int => match (right) { case Int => true; case _ => false }
            case Float => match (right) { case Float => true; case _ => false }
            case String => match (right) { case String => true; case _ => false }
            case Array => match (right) { case Array => true; case _ => false }
            case Map => match (right) { case Map => true; case _ => false }
        }
    }

    public operator func !=(right: YamlKind): Bool {
        return !(this == right)
    }
}

/// YAML 值 - 对应 Bun Expr (YAML 场景)
public class YamlValue {
    /// 值类型
    public var kind: YamlKind
    /// 字符串值
    public var stringValue: String
    /// 整数值
    public var intValue: Int64
    /// 浮点值
    public var floatValue: Float64
    /// 布尔值
    public var boolValue: Bool
    /// 数组值
    public var arrayValue: ArrayList<YamlValue>
    /// 映射值
    public var mapValue: LinkedHashMap<String, YamlValue>
    /// 标签 (如 !!str, !!int)
    public var tag: String
    /// 锚点名称
    public var anchor: String
    /// 别名引用
    public var alias: String

    public static func nullValue(): YamlValue { return YamlValue(YamlKind.Null) }
    public static func trueValue(): YamlValue { return YamlValue(YamlKind.Boolean, true) }
    public static func falseValue(): YamlValue { return YamlValue(YamlKind.Boolean, false) }

    public init(kind: YamlKind) {
        this.kind = kind
        stringValue = ""
        intValue = Int64(0)
        floatValue = Float64(0)
        boolValue = false
        arrayValue = ArrayList<YamlValue>()
        mapValue = LinkedHashMap<String, YamlValue>()
        tag = ""
        anchor = ""
        alias = ""
    }

    public init(kind: YamlKind, boolValue: Bool) {
        this.kind = kind
        this.boolValue = boolValue
        stringValue = ""
        intValue = Int64(0)
        floatValue = Float64(0)
        arrayValue = ArrayList<YamlValue>()
        mapValue = LinkedHashMap<String, YamlValue>()
        tag = ""
        anchor = ""
        alias = ""
    }

    public init(kind: YamlKind, stringValue: String) {
        this.kind = kind
        this.stringValue = stringValue
        intValue = Int64(0)
        floatValue = Float64(0)
        boolValue = false
        arrayValue = ArrayList<YamlValue>()
        mapValue = LinkedHashMap<String, YamlValue>()
        tag = ""
        anchor = ""
        alias = ""
    }

    public init(kind: YamlKind, intValue: Int64) {
        this.kind = kind
        this.intValue = intValue
        stringValue = ""
        floatValue = Float64(0)
        boolValue = false
        arrayValue = ArrayList<YamlValue>()
        mapValue = LinkedHashMap<String, YamlValue>()
        tag = ""
        anchor = ""
        alias = ""
    }

    public init(kind: YamlKind, floatValue: Float64) {
        this.kind = kind
        this.floatValue = floatValue
        stringValue = ""
        intValue = Int64(0)
        boolValue = false
        arrayValue = ArrayList<YamlValue>()
        mapValue = LinkedHashMap<String, YamlValue>()
        tag = ""
        anchor = ""
        alias = ""
    }

    /// 获取映射字段
    public func get(key: String): ?YamlValue {
        if (kind == YamlKind.Map) {
            mapValue.get(key)
        } else {
            None
        }
    }

    /// 获取映射字段带默认值
    public func get(key: String, defaultValue: YamlValue): YamlValue {
        match (get(key)) {
            case Some(v) => v
            case None => defaultValue
        }
    }

    /// 获取数组元素
    public func get(index: Int64): ?YamlValue {
        if (kind == YamlKind.Array && index >= Int64(0) && index < arrayValue.size) {
            Some(arrayValue[index])
        } else {
            None
        }
    }

    /// 大小
    public prop size: Int64 {
        get() {
            match (kind) {
                case YamlKind.Array => arrayValue.size
                case YamlKind.Map => mapValue.size
                case _ => Int64(0)
            }
        }
    }

    /// 是否为 null
    public func isNull(): Bool { kind == YamlKind.Null }

    /// 获取字符串值
    public func asString(): ?String {
        if (kind == YamlKind.String) { Some(stringValue) } else { None }
    }

    /// 获取整数值
    public func asInt(): ?Int64 {
        if (kind == YamlKind.Int) { Some(intValue) } else { None }
    }

    /// 获取浮点值
    public func asFloat(): ?Float64 {
        if (kind == YamlKind.Float) { Some(floatValue) } else { None }
    }

    /// 获取布尔值
    public func asBool(): ?Bool {
        if (kind == YamlKind.Boolean) { Some(boolValue) } else { None }
    }
}

// ============================================================================
// YamlParser - YAML 解析器
// 严格翻译自: src/parsers/yaml.zig - Parser(.utf8)
// Bun YAML 解析器架构:
//   1. 基于 indentation 的块结构解析
//   2. 支持 flow ({}[]) 和 block (缩进) 两种风格
//   3. 多文档流 (---分隔)
//   4. 块标量 (| literal, > folded)
//   5. Context 栈管理嵌套上下文
// 仓颉实现简化版 YAML 解析器，支持常用特性
// ============================================================================

/// YAML 解析器 - 对应 Bun yaml.zig Parser
/// Bun: pub fn parse(source, log, allocator) ParseError!Expr
public class YamlParser <: BaseParser {
    /// 当前缩进级别
    private var currentIndent: Int64
    /// 文档列表 (YAML 支持多文档)
    private var documents: ArrayList<YamlValue>

    public init(source: String) {
        super(source)
        currentIndent = Int64(0)
        documents = ArrayList<YamlValue>()
    }

    /// 解析 YAML 文本
    /// 对应 Bun: pub fn parse(source, log, allocator) ParseError!Expr
    public func parse(): ParseResult<YamlValue> {
        if (source.size == Int64(0)) {
            return ParseResult<YamlValue>(YamlValue.nullValue())
        }
        let result = ParseResult<YamlValue>()
        skipWhitespace()
        // 检查多文档标记
        if (pos + Int64(3) <= source.size && source[Int64(pos)..Int64(pos + Int64(3))] == "---") {
            pos += Int64(3)
            skipWhitespace()
        }
        // 解析第一个文档
        let value = parseDocument()
        if (hasErrors()) {
            for (err in errors) {
                result.addError(err)
            }
        } else {
            // 检查是否有更多文档
            skipWhitespace()
            while (pos + Int64(3) <= source.size && source[Int64(pos)..Int64(pos + Int64(3))] == "---") {
                pos += Int64(3)
                skipWhitespace()
                let nextDoc = parseDocument()
                documents.append(nextDoc)
            }
            if (documents.size > Int64(0)) {
                // 多文档: 返回数组
                documents.insert(Int64(0), value)
                let arr = YamlValue(YamlKind.Array)
                arr.arrayValue = documents
                result.value = Some(arr)
            } else {
                result.value = Some(value)
            }
            result.state = ParseState.Success
        }
        result.consumedBytes = pos
        return result
    }

    /// 解析单个 YAML 文档
    private func parseDocument(): YamlValue {
        skipWhitespace()
        if (pos >= source.size) {
            return YamlValue.nullValue()
        }
        // 空文档
        if (pos + Int64(3) <= source.size &&
            (source[Int64(pos)..Int64(pos + Int64(3))] == "---" ||
             source[Int64(pos)..Int64(pos + Int64(3))] == "...")) {
            return YamlValue.nullValue()
        }
        return parseNode(Int64(0))
    }

    /// 解析节点
    /// 对应 Bun YAML Parser 中的递归下降解析
    private func parseNode(minIndent: Int64): YamlValue {
        skipWhitespace()
        if (pos >= source.size) {
            return YamlValue.nullValue()
        }
        let ch = source[Int64(pos)]
        // 流式映射
        if (ch == UInt8(123)) {
            return parseFlowMap()
        }
        // 流式数组
        if (ch == UInt8(91)) {
            return parseFlowArray()
        }
        // 块序列 (以 - 开头的列表项)
        if (ch == UInt8(45) && pos + Int64(1) < source.size && isSpaceOrTab(source[Int64(pos + Int64(1))])) {
            return parseBlockSequence(minIndent)
        }
        // 块映射 (key: value)
        if (isMappingKey()) {
            return parseBlockMap(minIndent)
        }
        // 块标量 (| 或 >)
        if (ch == UInt8(124) || ch == UInt8(62)) {
            return parseBlockScalar()
        }
        // 引号字符串
        if (ch == UInt8(34) || ch == UInt8(39)) {
            return parseYAMLString()
        }
        // 纯标量
        return parsePlainScalar()
    }

    /// 解析流式映射 { key: value, ... }
    /// 对应 Bun YAML flow mapping 解析
    private func parseFlowMap(): YamlValue {
        let map = YamlValue(YamlKind.Map)
        advance() // consume {
        skipWhitespace()
        if (pos < source.size && source[Int64(pos)] == UInt8(125)) {
            advance()
            return map
        }
        while (true) {
            skipWhitespace()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedObject, "Unterminated flow mapping")
                return map
            }
            if (source[Int64(pos)] == UInt8(125)) {
                advance()
                return map
            }
            // 解析键
            let key = parseFlowKey()
            skipWhitespace()
            // 期望冒号
            if (pos < source.size && source[Int64(pos)] == UInt8(58)) {
                advance()
                skipWhitespace()
            }
            // 解析值
            let value = parseNode(Int64(0))
            map.mapValue.put(key, value)
            skipWhitespace()
            if (pos < source.size && source[Int64(pos)] == UInt8(44)) {
                advance()
            }
        }
        return map
    }

    /// 解析流式数组 [ item, ... ]
    private func parseFlowArray(): YamlValue {
        let arr = YamlValue(YamlKind.Array)
        advance() // consume [
        skipWhitespace()
        if (pos < source.size && source[Int64(pos)] == UInt8(93)) {
            advance()
            return arr
        }
        while (true) {
            skipWhitespace()
            if (pos >= source.size) {
                addError(ParseErrorKind.UnterminatedArray, "Unterminated flow sequence")
                return arr
            }
            if (source[Int64(pos)] == UInt8(93)) {
                advance()
                return arr
            }
            let value = parseNode(Int64(0))
            arr.arrayValue.append(value)
            skipWhitespace()
            if (pos < source.size && source[Int64(pos)] == UInt8(44)) {
                advance()
            }
        }
        return arr
    }

    /// 解析块序列 - 对应 Bun YAML block sequence
    /// - item1
    /// - item2
    /// - key: value
    private func parseBlockSequence(minIndent: Int64): YamlValue {
        let arr = YamlValue(YamlKind.Array)
        while (pos < source.size) {
            let indent = getLineIndent()
            if (indent < minIndent || pos >= source.size) {
                break
            }
            if (source[Int64(pos)] != UInt8(45)) {
                break
            }
            // 检查后面是否有空格
            if (pos + Int64(1) < source.size && !isSpaceOrTab(source[Int64(pos + Int64(1))])) {
                break
            }
            advance() // consume -
            let nextCh = if (pos < source.size) { source[Int64(pos)] } else { UInt8(10) }
            if (nextCh == UInt8(32) || nextCh == UInt8(9)) {
                advance() // consume space after -
            }
            skipYamlWhitespaceNoNewline()
            if (pos >= source.size || source[Int64(pos)] == UInt8(10)) {
                // 空项或嵌套块
                arr.arrayValue.append(YamlValue.nullValue())
                skipToNextLine()
                continue
            }
            let value = parseNode(indent + Int64(2))
            arr.arrayValue.append(value)
            skipToNextLine()
        }
        return arr
    }

    /// 解析块映射 - key: value 对应 Bun YAML block mapping
    private func parseBlockMap(minIndent: Int64): YamlValue {
        let map = YamlValue(YamlKind.Map)
        while (pos < source.size) {
            let indent = getLineIndent()
            if (indent < minIndent) {
                break
            }
            // 解析键
            let key = parseBlockKey()
            if (key == "") {
                break
            }
            skipYamlWhitespaceNoNewline()
            // 期望冒号
            if (pos < source.size && source[Int64(pos)] == UInt8(58)) {
                advance()
            } else {
                break
            }
            let nextCh = if (pos < source.size) { source[Int64(pos)] } else { UInt8(10) }
            if (nextCh == UInt8(32) || nextCh == UInt8(9)) {
                advance()
                skipWhitespace()
                let value = parseNode(indent)
                map.mapValue.put(key, value)
            } else {
                // 值在下一行 (嵌套块)
                skipToNextLine()
                let value = parseNode(indent + Int64(1))
                map.mapValue.put(key, value)
            }
            skipToNextLine()
        }
        return map
    }

    /// 解析块标量 (| 或 >)
    /// 对应 Bun YAML Chomp, Indent 控制
    private func parseBlockScalar(): YamlValue {
        let ch = source[Int64(pos)]
        advance() // consume | or >
        // 解析 chomp 指示符 (-, +, 或默认)
        var chomp = "clip" // 默认 clip
        if (pos < source.size) {
            match (source[Int64(pos)]) {
                case '-' => chomp = "strip"; advance()
                case '+' => chomp = "keep"; advance()
                case _ => ()
            }
        }
        skipToNextLine()
        // 收集缩进的行
        let sb = StringBuilder()
        let blockIndent = getLineIndent()
        var trailingNewlines = Int64(0)
        while (pos < source.size) {
            let lineIndent = getLineIndent()
            if (lineIndent < blockIndent && !isBlankLine()) {
                break
            }
            let line = readLine()
            if (line.trimAscii().size == Int64(0)) {
                trailingNewlines += Int64(1)
            } else {
                while (trailingNewlines > Int64(0)) {
                    sb.append('\n')
                    trailingNewlines -= Int64(1)
                }
                if (sb.size > Int64(0) && ch == UInt8(62)) {
                    sb.append(' ')  // folded: 空格连接
                } else if (sb.size > Int64(0)) {
                    sb.append('\n') // literal: 换行
                }
                sb.append(line.trimAscii())
            }
            if (pos < source.size) {
                advance() // skip \n
            }
        }
        // Chomp 控制
        match (chomp) {
            case "strip" => () // 不添加尾部换行
            case "keep" =>
                while (trailingNewlines > Int64(0)) {
                    sb.append('\n')
                    trailingNewlines -= Int64(1)
                }
                sb.append('\n')
            case _ => sb.append('\n') // clip: 保留一个换行
        }
        return YamlValue(YamlKind.String, sb.toString())
    }

    /// 解析 YAML 引号字符串
    private func parseYAMLString(): YamlValue {
        let quoteChar = source[Int64(pos)]
        advance() // consume quote
        let sb = StringBuilder()
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (ch == quoteChar) {
                advance()
                break
            }
            if (ch == UInt8(92) && quoteChar == UInt8(34)) {
                advance()
                if (pos < source.size) {
                    let escaped = source[Int64(pos)]
                    advance()
                    match (escaped) {
                        case 110 => sb.append(UInt8(10))
                        case 116 => sb.append(UInt8(9))
                        case 114 => sb.append(UInt8(13))
                        case 92 => sb.append(UInt8(92))
                        case 34 => sb.append(UInt8(34))
                        case _ => sb.append(escaped)
                    }
                }
            } else {
                sb.append(ch)
                advance()
            }
        }
        return YamlValue(YamlKind.String, sb.toString())
    }

    /// 解析纯标量 - 对应 Bun YAML plain scalar
    /// YAML 纯标量直到 : (后跟空格) 或行尾结束
    private func parsePlainScalar(): YamlValue {
        let sb = StringBuilder()
        while (pos < source.size) {
            let ch = source[Int64(pos)]
            if (ch == UInt8(10) || ch == UInt8(13)) {
                break
            }
            if (ch == UInt8(58) && pos + Int64(1) < source.size && isSpaceOrTab(source[Int64(pos + Int64(1))])) {
                break
            }
            if (ch == UInt8(35) && pos > Int64(0) && isSpaceOrTab(source[Int64(pos - Int64(1))])) {
                break
            }
            sb.append(ch)
            advance()
        }
        let text = sb.toString().trimAscii()
        return resolveScalar(text)
    }

    /// 解析流式键
    private func parseFlowKey(): String {
        skipWhitespace()
        let ch = source[Int64(pos)]
        if (ch == UInt8(34) || ch == UInt8(39)) {
            advance()
            let sb = StringBuilder()
            while (pos < source.size && source[Int64(pos)] != ch) {
                sb.append(source[Int64(pos)])
                advance()
            }
            if (pos < source.size) { advance() }
            return sb.toString()
        }
        // 纯标量键
        let sb = StringBuilder()
        while (pos < source.size) {
            let c = source[Int64(pos)]
            if (c == UInt8(58) || c == UInt8(44) || c == UInt8(125) || c == UInt8(93) || c == UInt8(32) || c == UInt8(9) || c == UInt8(10)) {
                break
            }
            sb.append(c)
            advance()
        }
        return sb.toString()
    }

    /// 解析块键
    private func parseBlockKey(): String {
        let ch = source[Int64(pos)]
        if (ch == UInt8(34) || ch == UInt8(39)) {
            return parseYAMLString().stringValue
        }
        let sb = StringBuilder()
        while (pos < source.size) {
            let c = source[Int64(pos)]
            if (c == UInt8(58) && pos + Int64(1) < source.size && (isSpaceOrTab(source[Int64(pos + Int64(1))]) || source[Int64(pos + Int64(1))] == UInt8(10))) {
                break
            }
            if (c == UInt8(10) || c == UInt8(13)) {
                break
            }
            sb.append(c)
            advance()
        }
        return sb.toString().trimAscii()
    }

    /// 是否为映射键 (当前行包含 key: value 模式)
    private func isMappingKey(): Bool {
        var i = pos
        while (i < source.size) {
            let ch = source[Int64(i)]
            if (ch == UInt8(58) && i + Int64(1) < source.size &&
                (source[Int64(i + Int64(1))] == UInt8(32) || source[Int64(i + Int64(1))] == UInt8(9) || source[Int64(i + Int64(1))] == UInt8(10))) {
                return true
            }
            if (ch == UInt8(10) || ch == UInt8(35) || ch == UInt8(45) || ch == UInt8(123) || ch == UInt8(91)) {
                return false
            }
            i += Int64(1)
        }
        return false
    }

    /// 解析标量值 - 将纯文本解析为具体类型
    /// 对应 Bun YAML 中对 null/bool/number/string 的自动类型推断
    private func resolveScalar(text: String): YamlValue {
        if (text.size == Int64(0)) {
            return YamlValue(YamlKind.String, "")
        }
        // null
        if (text == "null" || text == "~" || text == "Null" || text == "NULL") {
            return YamlValue.nullValue()
        }
        // bool
        if (text == "true" || text == "True" || text == "TRUE") {
            return YamlValue.trueValue()
        }
        if (text == "false" || text == "False" || text == "FALSE") {
            return YamlValue.falseValue()
        }
        // 整数
        match (parseIntStrict(text)) {
            case Some(n) => return YamlValue(YamlKind.Int, n)
            case None => ()
        }
        // 浮点数
        if (text == ".inf" || text == ".Inf" || text == ".INF") {
            return YamlValue(YamlKind.Float, Float64(1) / Float64(0))
        }
        if (text == "-.inf" || text == "-.Inf" || text == "-.INF") {
            return YamlValue(YamlKind.Float, Float64(-1) / Float64(0))
        }
        if (text == ".nan" || text == ".NaN" || text == ".NAN") {
            return YamlValue(YamlKind.Float, Float64(0) / Float64(0))
        }
        match (parseFloatStrict(text)) {
            case Some(n) => return YamlValue(YamlKind.Float, n)
            case None => ()
        }
        // 字符串
        return YamlValue(YamlKind.String, text)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 获取当前行的缩进级别
    private func getLineIndent(): Int64 {
        // 找到行首
        var lineStart = pos
        while (lineStart > Int64(0) && source[Int64(lineStart - Int64(1))] != UInt8(10)) {
            lineStart -= Int64(1)
        }
        // 计算空格数
        var indent = Int64(0)
        var i = lineStart
        while (i < source.size && source[Int64(i)] == UInt8(32)) {
            indent += Int64(1)
            i += Int64(1)
        }
        return indent
    }

    private func isSpaceOrTab(ch: Char): Bool {
        ch == UInt8(32) || ch == UInt8(9)
    }

    private func isBlankLine(): Bool {
        var i = pos
        while (i < source.size && source[Int64(i)] != UInt8(10)) {
            if (source[Int64(i)] != UInt8(32) && source[Int64(i)] != UInt8(9) && source[Int64(i)] != UInt8(13)) {
                return false
            }
            i += Int64(1)
        }
        return true
    }

    private func skipToNextLine(): Unit {
        while (pos < source.size && source[Int64(pos)] != UInt8(10)) {
            advance()
        }
        if (pos < source.size) {
            advance()
        }
    }

    private func skipYamlWhitespaceNoNewline(): Unit {
        while (pos < source.size && (source[Int64(pos)] == UInt8(32) || source[Int64(pos)] == UInt8(9))) {
            advance()
        }
    }

    /// 尝试解析整数
    private func parseIntStrict(s: String): ?Int64 {
        if (s.size == Int64(0)) {
            return None
        }
        var start = Int64(0)
        var negative = false
        if (s[Int64(0)] == UInt8(45)) {
            negative = true
            start = Int64(1)
        } else if (s[Int64(0)] == UInt8(43)) {
            start = Int64(1)
        }
        if (start >= s.size) {
            return None
        }
        // 0x (十六进制)
        if (start + Int64(1) < s.size && s[start] == UInt8(48) && (s[start + Int64(1)] == UInt8(120) || s[start + Int64(1)] == UInt8(88))) {
            var result = Int64(0)
            for (i in start + Int64(2)..s.size) {
                let ch = s[i]
                result = result * Int64(16)
                if (ch >= UInt8(48) && ch <= UInt8(57)) {
                    result += Int64(ch) - Int64(48)
                } else if (ch >= UInt8(97) && ch <= UInt8(102)) {
                    result += Int64(ch) - Int64(97) + Int64(10)
                } else if (ch >= UInt8(65) && ch <= UInt8(70)) {
                    result += Int64(ch) - Int64(65) + Int64(10)
                } else {
                    return None
                }
            }
            return if (negative) { -result } else { result }
        }
        // 0o (八进制)
        if (start + Int64(1) < s.size && s[start] == UInt8(48) && (s[start + Int64(1)] == UInt8(111) || s[start + Int64(1)] == UInt8(79))) {
            var result = Int64(0)
            for (i in start + Int64(2)..s.size) {
                let ch = s[i]
                if (ch >= UInt8(48) && ch <= UInt8(55)) {
                    result = result * Int64(8) + Int64(ch) - Int64(48)
                } else {
                    return None
                }
            }
            return if (negative) { -result } else { result }
        }
        // 十进制
        var result = Int64(0)
        for (i in start..s.size) {
            let ch = s[i]
            if (ch >= UInt8(48) && ch <= UInt8(57)) {
                result = result * Int64(10) + Int64(ch) - Int64(48)
            } else if (ch == UInt8(95)) {
                // 跳过下划线分隔符
            } else {
                return None
            }
        }
        return if (negative) { -result } else { result }
    }

    /// 尝试解析浮点数
    private func parseFloatStrict(s: String): ?Float64 {
        if (s.size == Int64(0)) {
            return None
        }
        var hasDot = false
        var hasE = false
        var start = Int64(0)
        if (s[Int64(0)] == UInt8(45) || s[Int64(0)] == UInt8(43)) {
            start = Int64(1)
        }
        for (i in start..s.size) {
            let ch = s[i]
            if (ch == UInt8(46)) {
                if (hasDot || hasE) { return None }
                hasDot = true
            } else if (ch == UInt8(101) || ch == UInt8(69)) {
                if (hasE) { return None }
                hasE = true
            } else if ((ch >= UInt8(48) && ch <= UInt8(57)) || ch == UInt8(95) || ch == UInt8(43) || ch == UInt8(45)) {
                // ok
            } else {
                return None
            }
        }
        if (!hasDot && !hasE) {
            return None
        }
        // 移除下划线后解析
        let clean = stripUnderscores(s)
        return Some(Float64.parse(clean))
    }

    private func stripUnderscores(s: String): String {
        let sb = StringBuilder()
        for (ch in s) {
            if (ch != UInt8(95)) { sb.append(ch) }
        }
        return sb.toString()
    }
}

// ============================================================================
// Front Matter 提取
// 严格翻译自: Bun 中 Markdown front matter 提取模式
// Bun 在 bunfig 和 Markdown 处理中使用 --- 分隔的 YAML front matter
// ============================================================================

/// Front Matter 提取器
/// 从文本中提取 --- 分隔的 YAML front matter
/// 格式: ---\n<yaml content>\n---\n<remaining content>
public class FrontMatter {
    /// YAML 内容
    public var yaml: String
    /// 剩余内容 (front matter 之后)
    public var content: String
    /// 是否找到 front matter
    public var found: Bool

    public init(yaml: String, content: String, found: Bool) {
        this.yaml = yaml
        this.content = content
        this.found = found
    }

    /// 解析 front matter 并返回 YAML 值
    public func parseYaml(): ParseResult<YamlValue> {
        let parser = YamlParser(yaml)
        return parser.parse()
    }

    /// 从文本中提取 front matter
    /// 对应 Bun Markdown/bunfig 中的 --- 分隔处理
    public static func extract(source: String): FrontMatter {
        if (source.size < Int64(4)) {
            return FrontMatter("", source, false)
        }
        // 检查是否以 --- 开头
        if (source[Int64(0)] != UInt8(45) || source[Int64(1)] != UInt8(45) || source[Int64(2)] != UInt8(45)) {
            return FrontMatter("", source, false)
        }
        // 找到起始换行
        var start = Int64(3)
        if (start < source.size && source[start] == UInt8(13)) {
            start += Int64(1)
        }
        if (start < source.size && source[start] == UInt8(10)) {
            start += Int64(1)
        }
        // 找到结束 ---
        var end = start
        while (end + Int64(3) <= source.size) {
            if (source[end] == UInt8(45) && source[end + Int64(1)] == UInt8(45) && source[end + Int64(2)] == UInt8(45)) {
                // 检查前后是否为行首/行尾
                let afterDash = end + Int64(3)
                if (afterDash >= source.size || source[afterDash] == UInt8(10) || source[afterDash] == UInt8(13)) {
                    let yaml = source[start..end]
                    var contentStart = afterDash
                    if (contentStart < source.size && source[contentStart] == UInt8(13)) {
                        contentStart += Int64(1)
                    }
                    if (contentStart < source.size && source[contentStart] == UInt8(10)) {
                        contentStart += Int64(1)
                    }
                    let content = if (contentStart < source.size) {
                        source[contentStart..source.size]
                    } else {
                        ""
                    }
                    return FrontMatter(yaml, content, true)
                }
            }
            end += Int64(1)
        }
        return FrontMatter("", source, false)
    }
}
