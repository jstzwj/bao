// 严格翻译自: src/runtime/api/JSONCObject.zig
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_core.{Allocator, Output}
import bao_collections.{ArrayList, HashMap}

// 本地 stub 类型
public class OutOfMemory { public init() {} }
public class JsError { public init() {} }
public class JsTerminated { public init() {} }

// ============================================================================
// JSONCObject - Bun.JSONC API
// 对应 Bun: src/runtime/api/JSONCObject.zig
// ============================================================================

/// JSONCObject 提供 JSONC (JSON with Comments) 解析功能
public class JSONCObject {

    /// 创建 JSONC 对象, 挂载 parse 方法
    public static func create(globalThis!: JsGlobalObject): JsValue {
        let object = JsValue.createEmptyObject(globalThis, 1)
        object.put(globalThis, ZigString.`static`("parse"), JsFunction.create(globalThis, "parse", parse, 1))
        return object
    }

    // ========================================================================
    // parse - JSONC.parse(text)
    // ========================================================================

    /// 解析 JSONC 字符串
    public static func parse(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        var arena = ArenaAllocator(globalThis.allocator())
        let allocator = arena.allocator()
        // 设置 AST 内存分配器 (JSON 解析所需)
        var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
        var astScope = astMemoryAllocator.enter(allocator)

        let inputValue = callframe.argument(0)
        if (inputValue.isEmptyOrUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Expected a string to parse")
            astScope.exit()
            arena.deinit()
            return JsValue.jsUndefined()
        }

        var inputSlice = inputValue.toSlice(globalThis, default_allocator)
        let source = Logger.Source.initPathString("input.jsonc", inputSlice.slice())

        var log = Logger.Log(default_allocator)

        let parseResult = try {
            JSON.parseTSConfig(source, log, allocator, true)
        } catch(err: Exception) {
            match (err) {
                case Error.StackOverflow =>
                    inputSlice.deinit()
                    log.deinit()
                    astScope.exit()
                    arena.deinit()
                    return globalThis.throwStackOverflow()
                case _ =>
                    if (log.msgs.items.size > 0) {
                        let firstMsg = log.msgs.items[0]
                        inputSlice.deinit()
                        log.deinit()
                        astScope.exit()
                        arena.deinit()
                        return globalThis.throwValue(
                            globalThis.createSyntaxErrorInstance("JSONC Parse error: " + firstMsg.data.text)
                        )
                    }
                    inputSlice.deinit()
                    log.deinit()
                    astScope.exit()
                    arena.deinit()
                    return globalThis.throwValue(
                        globalThis.createSyntaxErrorInstance("JSONC Parse error: Unable to parse JSONC string")
                    )
            }
        }

        let jsResult = try {
            parseResult.toJS(allocator, globalThis)
        } catch (err: Exception) {
            inputSlice.deinit()
            log.deinit()
            astScope.exit()
            arena.deinit()
            if (err is OutOfMemory) {
                return OutOfMemory
            }
            if (err is JsError) {
                return JsError
            }
            if (err is JsTerminated) {
                return JsTerminated
            }
            unreachable()("JSONC parsing does not produce macros or identifiers")
        }

        inputSlice.deinit()
        log.deinit()
        astScope.exit()
        arena.deinit()
        return jsResult
    }
}
