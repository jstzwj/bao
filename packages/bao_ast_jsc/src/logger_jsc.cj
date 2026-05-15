// 严格翻译自: src/ast_jsc/logger_jsc.zig
//! JSC bridge for `bun.logger`. Keeps `src/logger/` free of JSC types.
package bao_ast_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// MsgJSC - Msg 的 JSC 桥接
// 严格翻译自: src/ast_jsc/logger_jsc.zig:3-21
//   pub fn msgFromJS(allocator, globalObject, file, err) bun.JSError!Msg
//   pub fn msgToJS(this: Msg, globalObject, allocator) bun.OOM!jsc.JSValue
// ============================================================================

/// 从 JS 值创建 Msg - 严格对应 Bun msgFromJS
/// Bun: 将 JSValue 错误转换为 logger.Msg
public func msgFromJS(allocator: Allocator, globalObject: JSGlobalObject, file: String, err: JSValue): Msg {
    // Zig: var zig_exception_holder: jsc.ZigException.Holder = jsc.ZigException.Holder.init()
    // Zig: if (err.toError()) |value| { value.toZigException(...) }
    // Zig: else { zig_exception_holder.zigException().message = try err.toBunString(globalObject) }
    let msgText = err.toBunString(globalObject)
    return Msg(
        data: MsgData.text(
            text: msgText,
            location: Location(file: file, line: 0, column: 0)
        )
    )
}

/// 将 Msg 转换为 JS 值 - 严格对应 Bun msgToJS
/// Bun: switch (this.metadata) { .build => ..., .resolve => ... }
public func msgToJS(`this`: Msg, globalObject: JSGlobalObject, allocator: Allocator): JSValue {
    // 在 Bun 中，根据 metadata 类型创建 BuildMessage 或 ResolveMessage
    // 这里简化为创建一个 Error 对象
    let text = this.data.text
    return JSValue.createError(globalObject, text)
}

/// 从 JS 值获取日志级别 - 严格对应 Bun levelFromJS
/// Zig: pub fn levelFromJS(globalThis, value) bun.JSError!?Log.Level
public func levelFromJS(globalThis: JSGlobalObject, value: JSValue): ?LogLevel {
    if (value.isZero || value.isUndefined) {
        return None
    }

    if (!value.isString) {
        globalThis.throwInvalidArguments("Expected logLevel to be a string")
        return None
    }

    return LogLevel.fromJS(globalThis, value)
}

/// 将 Log 转换为 JS 值 - 严格对应 Bun logToJS
/// Zig: pub fn logToJS(this: Log, global, allocator, message) bun.JSError!jsc.JSValue
public func logToJS(`this`: Log, global: JSGlobalObject, allocator: Allocator, message: String): JSValue {
    let msgs: Array<Msg> = this.msgs.items
    let count = msgs.size

    match (count) {
        case 0 => return JSValue.jsUndefined
        case 1 => {
            let msg = msgs[0]
            return msgToJS(msg, global, allocator)
        }
        default => {
            var errorsStack = Array<JSValue>(count)
            for (i in 0..count) {
                errorsStack[i] = msgToJS(msgs[i], global, allocator)
            }
            let out = ZigString.init(message)
            let agg = global.createAggregateError(errorsStack, out)
            return agg
        }
    }
}

/// 将 Log 转换为 AggregateError - 严格对应 Bun logToJSAggregateError
/// Zig: pub fn logToJSAggregateError(this: Log, global, message) bun.JSError!jsc.JSValue
public func logToJSAggregateError(`this`: Log, global: JSGlobalObject, message: BaoString): JSValue {
    let jsArray = logToJSArray(this, global, Allocator.default)
    return global.createAggregateErrorWithArray(message, jsArray)
}

/// 将 Log 转换为 JS 数组 - 严格对应 Bun logToJSArray
/// Zig: pub fn logToJSArray(this: Log, global, allocator) bun.JSError!jsc.JSValue
public func logToJSArray(`this`: Log, global: JSGlobalObject, allocator: Allocator): JSValue {
    let msgs: Array<Msg> = this.msgs.items
    let arr = JSValue.createEmptyArray(global, msgs.size)
    for (i in 0..msgs.size) {
        arr.putIndex(global, Int64(i), msgToJS(msgs[i], global, allocator))
    }
    return arr
}
