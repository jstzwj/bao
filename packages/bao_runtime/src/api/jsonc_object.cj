// 严格翻译自: src/runtime/api/JSONCObject.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*

// ============================================================================
// JSONCObject - Bun.JSONC API
// 对应 Bun: src/runtime/api/JSONCObject.zig
// ============================================================================

/// JSONCObject 提供 JSONC (JSON with Comments) 解析功能
public class JSONCObject {

    /// 创建 JSONC 对象, 挂载 parse 方法
    public static func create(globalThis: JsGlobalObject): JsValue {
        let object = JsValue.createEmptyObject(globalThis, 1)
        object.put(globalThis, ZigString.static("parse"), JsFunction.create(globalThis, "parse", parse, 1))
        return object
    }

    // ========================================================================
    // parse - JSONC.parse(text)
    // ========================================================================

    /// 解析 JSONC 字符串
    public static func parse(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        var arena = ArenaAllocator.init(globalThis.allocator())
        let allocator = arena.allocator()
        defer arena.deinit()

        // 设置 AST 内存分配器 (JSON 解析所需)
        var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
        var astScope = astMemoryAllocator.enter(allocator)
        defer astScope.exit()

        let inputValue = callframe.argument(0)
        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string to parse")
            return JsValue.zero
        }

        var inputSlice = try inputValue.toSlice(globalThis, default_allocator)
        defer inputSlice.deinit()

        let source = Logger.Source.initPathString("input.jsonc", inputSlice.slice())

        var log = Logger.Log.init(default_allocator)
        defer log.deinit()

        let parseResult = try JSON.parseTSConfig(source, log, allocator, true) catch {
            err => match (err) {
                case Error.StackOverflow =>
                    return globalThis.throwStackOverflow()
                default =>
                    if (log.msgs.items.length > 0) {
                        let firstMsg = log.msgs.items[0]
                        return globalThis.throwValue(
                            globalThis.createSyntaxErrorInstance("JSONC Parse error: " + firstMsg.data.text)
                        )
                    }
                    return globalThis.throwValue(
                        globalThis.createSyntaxErrorInstance("JSONC Parse error: Unable to parse JSONC string")
                    )
            }
        }

        return try parseResult.toJS(allocator, globalThis) catch {
            err => match (err) {
                case Error.OutOfMemory => return Error.OutOfMemory
                case Error.JsError => return Error.JsError
                case Error.JsTerminated => return Error.JsTerminated
                default => unreachable("JSONC parsing does not produce macros or identifiers")
            }
        }
    }
}
