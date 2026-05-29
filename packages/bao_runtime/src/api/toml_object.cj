// 严格翻译自: src/runtime/api/TOMLObject.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_io.*

// ============================================================================
// TOMLObject - Bun.TOML 全局对象
// 对应 Bun: src/runtime/api/TOMLObject.zig
// ============================================================================

/// 创建 TOML 对象，挂载到 Bun.TOML
public func create(globalThis!: JsGlobalObject): JsValue {
    let object = JsValue.createEmptyObject(globalThis, 1)
    object.put(
        globalThis,
        ZigString.`static`("parse"),
        JsFunction.create(
            globalThis,
            "parse",
            parse,
            1,
        ),
    )
    return object
}

/// TOML.parse - 解析 TOML 字符串为 JS 对象
public func parse(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    var arena = ArenaAllocator(globalThis.allocator())
    let allocator = arena.allocator()
    var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
    var astScope = astMemoryAllocator.enter(allocator)

    var log = Logger.Log(default_allocator)

    let inputValue = callframe.argument(0)
    if (inputValue.isEmptyOrUndefinedOrNull()) {
        astScope.exit()
        arena.deinit()
        return globalThis.throwInvalidArguments("Expected a string to parse")
    }

    var inputSlice = inputValue.toSlice(globalThis, default_allocator)
    let source = Logger.Source.initPathString("input.toml", inputSlice.slice())
    let parseResult = try {
        TOML.parse(source, log, allocator, false)
    } catch(err: Exception) {
        if (err == Error.StackOverflow) {
            inputSlice.deinit()
            log.deinit()
            astScope.exit()
            arena.deinit()
            return globalThis.throwStackOverflow()
        }
        inputSlice.deinit()
        log.deinit()
        astScope.exit()
        arena.deinit()
        return globalThis.throwValue(log.toJS(globalThis, default_allocator, "Failed to parse toml"))
    }

    // 序列化为 JSON 再解析为 JS 值
    let bufferWriter = JsPrinter.BufferWriter(allocator)
    var writer = JsPrinter.BufferPrinter(bufferWriter)
    try {
        JsPrinter.printJSON(
            writer,
            parseResult,
            source,
            null, // mangled_props
        )
    } catch(_: Exception) {
        inputSlice.deinit()
        log.deinit()
        astScope.exit()
        arena.deinit()
        return globalThis.throwValue(log.toJS(globalThis, default_allocator, "Failed to print toml"))
    }

    let slice = writer.ctx.buffer.slice()
    var out = BunString.borrowUTF8(slice)
    out.deref()
    let result = out.toJSByParseJSON(globalThis)
    inputSlice.deinit()
    log.deinit()
    astScope.exit()
    arena.deinit()
    return result
}

// ============================================================================
// 类型别名
// ============================================================================

// BunString, ASTMemoryAllocator, Logger, JsPrinter, TOML, default_allocator 已通过 import 导入，无需重复定义
