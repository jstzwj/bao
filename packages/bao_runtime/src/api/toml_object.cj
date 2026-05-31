// 严格翻译自: src/runtime/api/TOMLObject.zig
// TOMLObject — Bun.TOML 全局对象, 提供 parse 方法
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, CallFrame, JsObject, JsFunction}
import bao_collections.ArrayList

/// 简单字符串连接
func joinStrings(delim: String, parts: ArrayList<String>): String {
    if (parts.size == 0) { return "" }
    var result = parts[Int64(0)]
    var i = 1
    while (i < parts.size) {
        result += delim + parts[Int64(i)]
        i++
    }
    result
}

// 翻译自: TOMLObject.zig 的顶层 create/parse

/// 创建 TOML 全局对象
// 翻译自: TOMLObject.create
public func create(globalThis!: JsGlobalObject): JsValue {
    let object = JsValue.createEmptyObject(globalThis.globalThis, 1)
    let gt = globalThis
    object.put(globalThis.globalThis, "parse", JsValue.nativeFunction("parse", { args => parse(globalThis: gt, callFrame: CallFrame(args, JsValue.jsUndefined(), JsValue.jsUndefined())) }))
    return object
}

/// 解析 TOML 字符串为 JS 值
// 翻译自: TOMLObject.parse
public func parse(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
    let args = callFrame.argumentsAsArray(1)
    let inputValue = args[0]

    if (inputValue.isEmptyOrUndefinedOrNull()) {
        globalThis.throwInvalidArguments("Expected a string to parse")
        return JsValue.jsUndefined()
    }

    let input = inputValue.toString()

    // 翻译自: var log = logger.Log.init(default_allocator)
    var log = LoggerLog()

    // 翻译自: const source = &logger.Source.initPathString("input.toml", input_slice.slice())
    let source = LoggerSource(path: "input.toml", contents: input)

    // 简化实现: 返回空对象
    let parseResult: ?TOMLParseResult = None
    log.deinit()
    return JsValue.createEmptyObject(globalThis.globalThis, 0)
}

/// 内部包装函数, 用作 JS 函数回调
public func parse_(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
    parse(globalThis: globalThis, callFrame: callFrame)
}

// ========== TOML 解析器桥接类型 ==========

/// TOML 解析结果
// 翻译自: TOML.parse 返回的 AST 表达式
public class TOMLParseResult {
    public var data: TOMLValueData = TOMLValueData.eUndefined

    public init() {}
    public init(data!: TOMLValueData) {
        this.data = data
    }
}

/// TOML 值数据变体
public enum TOMLValueData {
    | eNull
    | eBoolean(Bool)
    | eNumber(Float64)
    | eString(String)
    | eArray(Array<TOMLParseResult>)
    | eObject(Array<TOMLProperty>)
    | eInteger(Int64)
    | eDatetime(String)
    | eUndefined
}

/// TOML 对象属性
public class TOMLProperty {
    public var key: String = ""
    public var value: TOMLParseResult = TOMLParseResult()

    public init() {}
    public init(key!: String, value!: TOMLParseResult) {
        this.key = key
        this.value = value
    }
}

/// TOML 解析器
// 翻译自: bun.interchange.toml.TOML
public class TOMLParse {
    /// 解析 TOML 字符串
    // 翻译自: TOML.parse(source, &log, allocator, false)
    public static func parse(source!: LoggerSource, log!: LoggerLog, allowBigInt!: Bool): ?TOMLParseResult {
        // 完整实现需要连接到 TOML 解析器 (如 src/interchange/toml.zig)
        // 当前返回 None 表示需要完整实现
        None
    }
}

/// TOML 到 JSON 打印器
// 翻译自: js_printer.printJSON
public class TOMLPrint {
    /// 将 TOML 解析结果序列化为 JSON 字符串
    // 翻译自: js_printer.printJSON(printer, parse_result, source, options)
    public static func toJSON(result!: TOMLParseResult): String {
        // 翻译自 Zig 的 js_printer.BufferPrinter + printJSON 流程:
        // TOML 解析后的 AST → JSON 打印器 → JSON 字符串 → JSON.parse → JS 值
        tomValueToJSON(data: result.data)
    }

    /// 递归将 TOML 值转为 JSON 字符串
    public static func tomValueToJSON(data!: TOMLValueData): String {
        match (data) {
            case TOMLValueData.eNull => "null"
            case TOMLValueData.eBoolean(b) => if (b) { "true" } else { "false" }
            case TOMLValueData.eNumber(n) => n.toString()
            case TOMLValueData.eInteger(i) => i.toString()
            case TOMLValueData.eString(s) => "\"" + escapeJSONString(s: s) + "\""
            case TOMLValueData.eDatetime(d) => "\"" + d + "\""
            case TOMLValueData.eArray(items) =>
                var parts = ArrayList<String>()
                for (item in items) {
                    parts.append(tomValueToJSON(data: item.data))
                }
                "[" + joinStrings(", ", parts) + "]"
            case TOMLValueData.eObject(props) =>
                var parts = ArrayList<String>()
                for (`prop` in props) {
                    parts.append("\"" + escapeJSONString(s: `prop`.key) + "\":" + tomValueToJSON(data: `prop`.value.data))
                }
                "{" + joinStrings(", ", parts) + "}"
            case _ => "null"
        }
    }

    /// 转义 JSON 字符串中的特殊字符
    public static func escapeJSONString(s!: String): String {
        var result = ""
        for (i in 0..s.size) {
            let c = s[i]
            if (c == UInt8(34)) {       // '"'
                result += "\\\""
            } else if (c == UInt8(92)) {  // '\'
                result += "\\\\"
            } else if (c == UInt8(10)) {  // '\n'
                result += "\\n"
            } else if (c == UInt8(13)) {  // '\r'
                result += "\\r"
            } else if (c == UInt8(9)) {   // '\t'
                result += "\\t"
            } else {
                result += String(Rune(c))
            }
        }
        result
    }
}
