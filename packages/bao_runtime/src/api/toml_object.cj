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
public func create(globalThis: JsGlobalObject): JsValue {
    let object = JsValue.createEmptyObject(globalThis, 1)
    object.put(
        globalThis,
        ZigString.static("parse"),
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
public func parse(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
    var arena = ArenaAllocator.init(globalThis.allocator())
    let allocator = arena.allocator()
    defer arena.deinit()

    var astMemoryAllocator = handleOom(allocator.create(ASTMemoryAllocator))
    var astScope = astMemoryAllocator.enter(allocator)
    defer astScope.exit()

    var log = Logger.Log.init(default_allocator)
    defer log.deinit()

    let inputValue = callframe.argument(0)
    if (inputValue.isEmptyOrUndefinedOrNull()) {
        return globalThis.throwInvalidArguments("Expected a string to parse")
    }

    var inputSlice = try inputValue.toSlice(globalThis, default_allocator)
    defer inputSlice.deinit()

    let source = Logger.Source.initPathString("input.toml", inputSlice.slice())
    let parseResult = TOML.parse(source, log, allocator, false) catch { err =>
        if (err == Error.StackOverflow) {
            return globalThis.throwStackOverflow()
        }
        return globalThis.throwValue(try log.toJS(globalThis, default_allocator, "Failed to parse toml"))
    }

    // 序列化为 JSON 再解析为 JS 值
    let bufferWriter = JsPrinter.BufferWriter.init(allocator)
    var writer = JsPrinter.BufferPrinter.init(bufferWriter)
    _ = JsPrinter.printJSON(
        writer,
        parseResult,
        source,
        null, // mangled_props
    ) catch {
        return globalThis.throwValue(try log.toJS(globalThis, default_allocator, "Failed to print toml"))
    }

    let slice = writer.ctx.buffer.slice()
    var out = BunString.borrowUTF8(slice)
    defer out.deref()

    return out.toJSByParseJSON(globalThis)
}

// ============================================================================
// 类型别名
// ============================================================================

public typealias BunString = BunString
public typealias ASTMemoryAllocator = ASTMemoryAllocator
public typealias Logger = Logger
public typealias JsPrinter = JsPrinter
public typealias TOML = TOML
public let default_allocator = default_allocator
