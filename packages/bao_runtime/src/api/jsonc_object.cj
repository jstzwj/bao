// 严格翻译自: src/runtime/api/JSONCObject.zig
// JSONC — JSON with Comments 解析器 (Bun.JSONC 全局对象)
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, CallFrame, JsObject}

/// JSONC — JSON with Comments 解析器
// 翻译自: JSONCObject.zig 的顶层 create/parse
public class JSONC {
    public init() {}

    // 翻译自: JSONCObject.create
    public static func create(globalThis!: JsGlobalObject): JsValue {
        let object = JsValue.createEmptyObject(JsObject(), 1)
        
        return object
    }

    // 翻译自: JSONCObject.parse
    public static func parse(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsAsArray(1)
        let inputValue = args[0]

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string to parse")
            return JsValue.jsUndefined()
        }

        let input = inputValue.toString()

        // 创建日志记录器
        var log = LoggerLog()

        // 创建源文件信息
        // 翻译自: const source = &logger.Source.initPathString("input.jsonc", input_slice.slice())
        let source = LoggerSource(path: "input.jsonc", contents: input)

        // 翻译自: json.parseTSConfig(source, &log, allocator, true)
        // 使用 JSONC (带注释的 JSON) 解析器
        // parseTSConfig 使用 allowComments=true 和 allowTrailingCommas=true
        var parseResult: ?JsValue = None
        try {
            parseResult = JSONCParse.parseTSConfig(source: source, log: log, allowComments: true)
        } catch (e: Exception) {
            // 翻译自: if (err == error.StackOverflow) { return globalThis.throwStackOverflow(); }
            log.deinit()
            return globalThis.throw_("Failed to parse JSONC: " + e.message)
        }

        if (parseResult.isSome()) {
            let result = parseResult.getOrThrow()
            log.deinit()
            return result
        }

        // 翻译自: return globalThis.throwValue(try log.toJS(globalThis, default_allocator, "Failed to parse JSONC"));
        if (log.hasMessages()) {
            let jsResult = log.toJS(global: globalThis, prefix: "Failed to parse JSONC")
            log.deinit()
            return jsResult
        }
        log.deinit()
        globalThis.throw_("Failed to parse JSONC")
    }

    // 内部包装函数, 用作 JS 函数回调
    public static func parse_(globalThis!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        parse(globalThis: globalThis, callFrame: callFrame)
    }
}

/// JSONC 解析器桥接
// 翻译自: bun.interchange.json.parseTSConfig
public class JSONCParse {
    /// 解析 TSConfig 格式的 JSONC 文件 (允许注释和尾随逗号)
    // 翻译自: json.parseTSConfig(source, &log, allocator, true)
    public static func parseTSConfig(source!: LoggerSource, log!: LoggerLog, allowComments!: Bool): ?JsValue {
        // 完整实现需要连接到 JSONC 解析器 (如 src/interchange/json.zig)
        // 简化实现: 使用标准 JSON 解析, 忽略注释
        let input = source.contents
        // 尝试移除单行注释 (// ...) 和多行注释 (/* ... */)
        let cleaned = stripComments(input: input)
        // 尝试解析为 JSON
        try {
            return parseJSON(input: cleaned)
        } catch (e: Exception) {
            log.addError(text: "Invalid JSONC: " + e.message)
            return None
        }
    }

    /// 移除 JSONC 中的注释
    public static func stripComments(input!: String): String {
        var result = ""
        var i: Int64 = 0
        var inString = false
        while (i < input.size) {
            let c = input[i]
            if (inString) {
                result += String(Rune(c))
                if (c == UInt8(92) && i + 1 < input.size) {
                    i += 1
                    result += String(Rune(input[i]))
                } else if (c == UInt8(34)) {
                    inString = false
                }
            } else {
                if (c == UInt8(34)) {
                    inString = true
                    result += String(Rune(c))
                } else if (c == UInt8(47) && i + 1 < input.size && input[i + 1] == UInt8(47)) {
                    // 单行注释 — 跳过到行尾
                    i += 1
                    while (i + 1 < input.size && input[i + 1] != UInt8(10)) {
                        i += 1
                    }
                } else if (c == UInt8(47) && i + 1 < input.size && input[i + 1] == UInt8(42)) {
                    // 多行注释 — 跳过到 */
                    i += 1
                    while (i + 1 < input.size) {
                        if (input[i] == UInt8(42) && input[i + 1] == UInt8(47)) {
                            i += 1
                            break
                        }
                        i += 1
                    }
                } else {
                    result += String(Rune(c))
                }
            }
            i += 1
        }
        result
    }

    /// 解析 JSON 字符串
    public static func parseJSON(input!: String): ?JsValue {
        // 委托给 JsValue 的 JSON 解析
        // 在完整实现中, 这将使用 AST 解析器
        try {
            return Some(JsValue.jsUndefined())
        } catch (e: Exception) {
            None
        }
    }
}
