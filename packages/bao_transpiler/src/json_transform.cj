// JSON 转换器
// 严格翻译自: src/bundler/ 中 JSON 模块处理
//
// Bun 的 JSON 处理:
//   1. JSON -> ES Module: export default
//      import data from "./config.json" -> data = { ... }
//      转为: export default { ... }
//
//   2. Named exports from JSON keys:
//      import { name, version } from "./package.json"
//      转为: export var name = "..."; export var version = "..."
//
//   3. JSON import attribute:
//      import data from "./config.json" with { type: "json" }
//      或: import data from "./config.json" assert { type: "json" }
//
// 参考:
//   src/bundler/bundle_v2.rs - JSON loader
//   src/js_parser/js_parser.zig - JSON import 解析
package bao_transpiler

import bao_core.*
import bao_collections.*

// ============================================================================
// JSONTransformer - JSON 转换器
// 严格翻译自: Bun bundler 中 JSON 文件加载和转换
// Bun 使用 esbuild 风格的 JSON 处理:
//   JSON 文件被包装为 ES Module，export default 导出整个 JSON
//   同时也可以按名称导出顶层 key
// ============================================================================

/// JSON 转换器 - 对应 Bun 中 JSON 模块的转换处理
public class JSONTransformer {
    private var source: String
    private var pos: Int64
    private var output: StringBuilder

    public init() {
        source = ""
        pos = 0
        output = StringBuilder()
    }

    /// 转换 JSON 为 ES Module - 主入口
    /// 对应 Bun bundler 中 JSON loader 的行为
    public func transform(source: String): String {
        this.source = source
        this.pos = 0
        this.output = StringBuilder()

        // 验证 JSON 格式
        skipWhitespace()
        if (pos >= source.length) {
            return "export default null;\n"
        }

        let firstChar = source[Int64(pos)]
        if (firstChar == Char('{')) {
            return transformJSONObject()
        } else if (firstChar == Char('[')) {
            return transformJSONArray()
        } else if (firstChar == Char('"')) {
            return transformJSONString()
        } else if (firstChar == Char('t') || firstChar == Char('f')) {
            return transformJSONBoolean()
        } else if (firstChar == Char('n')) {
            return transformJSONNull()
        } else {
            // 数字
            return transformJSONNumber()
        }
    }

    /// 转换 JSON 对象为 ES Module
    /// { "name": "foo", "version": "1.0" }
    /// ->
    /// export default { "name": "foo", "version": "1.0" }
    /// export var name = "foo";
    /// export var version = "1.0";
    private func transformJSONObject(): String {
        let jsonContent = source.trim()
        let sb = StringBuilder()

        // export default 完整 JSON
        sb.append("// Generated from JSON\n")
        sb.append("export default ")
        sb.append(jsonContent)
        sb.append(";\n\n")

        // 解析 JSON 提取顶层 key 用于 named exports
        let parsed = parseJSONObject()
        if (parsed.size > 0) {
            sb.append("// Named exports\n")
            let keys = parsed.keys()
            for (key in keys) {
                let safeName = makeSafeIdentifier(key)
                match (parsed.get(key)) {
                    case Some(value) => {
                        sb.append("export var ${safeName} = ")
                        sb.append(generateValue(value))
                        sb.append(";\n")
                    }
                    case None => {}
                }
            }
        }

        return sb.toString()
    }

    /// 转换 JSON 数组为 ES Module
    private func transformJSONArray(): String {
        let jsonContent = source.trim()
        let sb = StringBuilder()
        sb.append("// Generated from JSON array\n")
        sb.append("export default ")
        sb.append(jsonContent)
        sb.append(";\n")
        return sb.toString()
    }

    /// 转换 JSON 字符串为 ES Module
    private func transformJSONString(): String {
        let jsonContent = source.trim()
        let sb = StringBuilder()
        sb.append("// Generated from JSON string\n")
        sb.append("export default ")
        sb.append(jsonContent)
        sb.append(";\n")
        return sb.toString()
    }

    /// 转换 JSON 布尔值
    private func transformJSONBoolean(): String {
        let jsonContent = source.trim()
        let sb = StringBuilder()
        sb.append("export default ${jsonContent};\n")
        return sb.toString()
    }

    /// 转换 JSON null
    private func transformJSONNull(): String {
        return "export default null;\n"
    }

    /// 转换 JSON 数字
    private func transformJSONNumber(): String {
        let jsonContent = source.trim()
        let sb = StringBuilder()
        sb.append("export default ${jsonContent};\n")
        return sb.toString()
    }

    // ========================================================================
    // JSON 解析 - 简化的 JSON 解析器
    // ========================================================================

    /// 解析 JSON 对象为 HashMap
    private func parseJSONObject(): HashMap<String, JSONValue> {
        let result = HashMap<String, JSONValue>()
        skipWhitespace()

        if (pos >= source.length || source[Int64(pos)] != Char('{')) {
            return result
        }
        pos += 1  // skip '{'
        skipWhitespace()

        while (pos < source.length && source[Int64(pos)] != Char('}')) {
            skipWhitespace()

            // 读取 key
            let key = parseJSONString()
            skipWhitespace()

            // 跳过冒号
            if (pos < source.length && source[Int64(pos)] == Char(':')) {
                pos += 1
            }
            skipWhitespace()

            // 读取 value
            let value = parseJSONValue()
            result.put(key, value)

            skipWhitespace()
            // 跳过逗号
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
            skipWhitespace()
        }

        if (pos < source.length && source[Int64(pos)] == Char('}')) {
            pos += 1
        }

        return result
    }

    /// 解析 JSON 值
    private func parseJSONValue(): JSONValue {
        skipWhitespace()
        if (pos >= source.length) {
            return JSONValue.nullValue()
        }

        let ch = source[Int64(pos)]

        if (ch == Char('"')) {
            return JSONValue.stringValue(parseJSONString())
        }
        if (ch == Char('{')) {
            let obj = parseJSONObject()
            return JSONValue.objectValue(obj)
        }
        if (ch == Char('[')) {
            let arr = parseJSONArray()
            return JSONValue.arrayValue(arr)
        }
        if (ch == Char('t')) {
            pos += 4  // skip "true"
            return JSONValue.boolValue(true)
        }
        if (ch == Char('f')) {
            pos += 5  // skip "false"
            return JSONValue.boolValue(false)
        }
        if (ch == Char('n')) {
            pos += 4  // skip "null"
            return JSONValue.nullValue()
        }

        // 数字
        return JSONValue.numberValue(parseJSONNumber())
    }

    /// 解析 JSON 字符串
    private func parseJSONString(): String {
        skipWhitespace()
        if (pos >= source.length || source[Int64(pos)] != Char('"')) {
            return ""
        }
        pos += 1  // skip opening "

        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char('\\')) {
                pos += 1
                if (pos < source.length) {
                    let escaped = source[Int64(pos)]
                    match (escaped.value) {
                        case 34 => sb.append(Char(34))   // \"
                        case 92 => sb.append(Char(92))   // \\
                        case 47 => sb.append(Char(47))   // \/
                        case 98 => sb.append(Char(8))    // \b
                        case 102 => sb.append(Char(12))  // \f
                        case 110 => sb.append(Char(10))  // \n
                        case 114 => sb.append(Char(13))  // \r
                        case 116 => sb.append(Char(9))   // \t
                        case 117 => {
                            // \uXXXX Unicode escape
                            pos += 1
                            var hexStr = StringBuilder()
                            var count = 0
                            while (count < 4 && pos < source.length) {
                                hexStr.append(source[Int64(pos)])
                                pos += 1
                                count += 1
                            }
                            // 简化: 保留原始 unicode 转义
                            sb.append("\\u${hexStr.toString()}")
                            continue
                        }
                        case _ => sb.append(escaped)
                    }
                    pos += 1
                }
            } else if (ch == Char('"')) {
                pos += 1
                break
            } else {
                sb.append(ch)
                pos += 1
            }
        }
        return sb.toString()
    }

    /// 解析 JSON 数组
    private func parseJSONArray(): ArrayList<JSONValue> {
        let result = ArrayList<JSONValue>()
        skipWhitespace()

        if (pos >= source.length || source[Int64(pos)] != Char('[')) {
            return result
        }
        pos += 1  // skip '['
        skipWhitespace()

        while (pos < source.length && source[Int64(pos)] != Char(']')) {
            let value = parseJSONValue()
            result.append(value)

            skipWhitespace()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
            skipWhitespace()
        }

        if (pos < source.length && source[Int64(pos)] == Char(']')) {
            pos += 1
        }

        return result
    }

    /// 解析 JSON 数字
    private func parseJSONNumber(): String {
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            let v = ch.value
            if ((v >= 48 && v <= 57) || v == 45 || v == 46 ||
                v == 101 || v == 69 || v == 43) {
                // 0-9, -, ., e, E, +
                sb.append(ch)
                pos += 1
            } else {
                break
            }
        }
        return sb.toString()
    }

    // ========================================================================
    // JSON Import Attribute 处理
    // 对应 TC39 Import Attributes 提案
    // import data from "./config.json" with { type: "json" }
    // 或旧语法: import data from "./config.json" assert { type: "json" }
    // ========================================================================

    /// 处理 JSON import attribute
    /// 检测并处理 import 语句中的 with/assert 子句
    public func transformImportWithAttribute(source: String): String {
        var result = source

        // 处理 "with { type: "json" }" 语法
        // 移除 with/assert 子句，因为 JSON 在 Bun 中默认可以导入
        result = removeImportAttribute(result, "with")
        result = removeImportAttribute(result, "assert")

        return result
    }

    /// 移除 import 语句中的 attribute 子句
    private func removeImportAttribute(source: String, keyword: String): String {
        let searchStr = " ${keyword} { type: \"json\" }"
        return source.replace(searchStr, "")
    }

    // ========================================================================
    // 工具方法
    // ========================================================================

    /// 生成 JSONValue 的 JavaScript 表示
    private func generateValue(value: JSONValue): String {
        match (value.kind) {
            case JSONValueKind.Null => "null"
            case JSONValueKind.Bool => if (value.boolValue) { "true" } else { "false" }
            case JSONValueKind.Number => value.stringValue
            case JSONValueKind.String => "\"${escapeJSONString(value.stringValue)}\""
            case JSONValueKind.Array => {
                let sb = StringBuilder()
                sb.append("[")
                for (i in 0..value.arrayValue.size) {
                    if (i > 0) { sb.append(", ") }
                    sb.append(generateValue(value.arrayValue[Int64(i)]))
                }
                sb.append("]")
                sb.toString()
            }
            case JSONValueKind.Object => {
                let sb = StringBuilder()
                sb.append("{")
                let keys = value.objectValue.keys()
                var first = true
                for (key in keys) {
                    if (!first) { sb.append(", ") }
                    first = false
                    sb.append("\"${escapeJSONString(key)}\": ")
                    match (value.objectValue.get(key)) {
                        case Some(v) => sb.append(generateValue(v))
                        case None => sb.append("null")
                    }
                }
                sb.append("}")
                sb.toString()
            }
        }
    }

    /// 将字符串转为安全的 JavaScript 标识符
    private func makeSafeIdentifier(s: String): String {
        if (s.length == 0) {
            return "_"
        }
        let sb = StringBuilder()
        let first = s[Int64(0)]
        let fv = first.value
        if (!((fv >= 97 && fv <= 122) || (fv >= 65 && fv <= 90) || fv == 95 || fv == 36)) {
            sb.append("_")
        }
        for (ch in s) {
            let v = ch.value
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                (v >= 48 && v <= 57) || v == 95 || v == 36) {
                sb.append(ch)
            } else {
                sb.append("_")
            }
        }
        let result = sb.toString()
        // 检查是否是保留字
        if (isReservedWord(result)) {
            return "_${result}"
        }
        return result
    }

    /// 检查是否是 JavaScript 保留字
    private func isReservedWord(s: String): Bool {
        match (s) {
            case "break" | "case" | "catch" | "class" | "const" |
                 "continue" | "debugger" | "default" | "delete" | "do" |
                 "else" | "export" | "extends" | "finally" | "for" |
                 "function" | "if" | "import" | "in" | "instanceof" |
                 "new" | "return" | "super" | "switch" | "this" |
                 "throw" | "try" | "typeof" | "var" | "void" |
                 "while" | "with" | "yield" | "enum" | "implements" |
                 "interface" | "let" | "package" | "private" | "protected" |
                 "public" | "static" | "await" | "abstract" | "boolean" |
                 "byte" | "char" | "double" | "final" | "float" |
                 "goto" | "int" | "long" | "native" | "short" |
                 "synchronized" | "throws" | "transient" | "volatile" |
                 "null" | "true" | "false" | "undefined" | "NaN" |
                 "Infinity" => true
            case _ => false
        }
    }

    /// 转义 JSON 字符串
    private func escapeJSONString(s: String): String {
        var result = s
        result = result.replace("\\", "\\\\")
        result = result.replace("\"", "\\\"")
        result = result.replace("\n", "\\n")
        result = result.replace("\r", "\\r")
        result = result.replace("\t", "\\t")
        return result
    }

    private func skipWhitespace(): Unit {
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char(' ') || ch == Char('\t') || ch == Char('\n') || ch == Char('\r')) {
                pos += 1
            } else {
                break
            }
        }
    }
}

// ============================================================================
// JSONValue - JSON 值类型
// 对应 Bun 中 JSON AST 节点
// ============================================================================

/// JSON 值类型
public enum JSONValueKind {
    | Null
    | Bool
    | Number
    | String
    | Array
    | Object
}

/// JSON 值 - 对应 Bun js_ast.E 中的 JSON 字面量
public class JSONValue {
    public var kind: JSONValueKind
    public var boolValue: Bool
    public var stringValue: String
    public var arrayValue: ArrayList<JSONValue>
    public var objectValue: HashMap<String, JSONValue>

    private init(kind: JSONValueKind) {
        this.kind = kind
        boolValue = false
        stringValue = ""
        arrayValue = ArrayList<JSONValue>()
        objectValue = HashMap<String, JSONValue>()
    }

    public static func nullValue(): JSONValue {
        return JSONValue(JSONValueKind.Null)
    }

    public static func boolValue(v: Bool): JSONValue {
        let result = JSONValue(JSONValueKind.Bool)
        result.boolValue = v
        return result
    }

    public static func numberValue(s: String): JSONValue {
        let result = JSONValue(JSONValueKind.Number)
        result.stringValue = s
        return result
    }

    public static func stringValue(s: String): JSONValue {
        let result = JSONValue(JSONValueKind.String)
        result.stringValue = s
        return result
    }

    public static func arrayValue(arr: ArrayList<JSONValue>): JSONValue {
        let result = JSONValue(JSONValueKind.Array)
        result.arrayValue = arr
        return result
    }

    public static func objectValue(obj: HashMap<String, JSONValue>): JSONValue {
        let result = JSONValue(JSONValueKind.Object)
        result.objectValue = obj
        return result
    }
}
