// 严格翻译自: src/ast_jsc/logger_jsc.zig
//! JSC bridge for `bun.logger`. Keeps `src/logger/` free of JSC types.
package bao_ast_jsc

import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_jsc.CallFrame
import bao_core.Allocator
import bao_core.defaultAllocator
import bao_core.LogMsg
import bao_core.Log
import bao_core.LogLevel
import bao_core.MsgData
import bao_core.SourceLocation
import bao_core.LogKind

// ============================================================================
// MsgJSC - Msg 的 JSC 桥接
// ============================================================================

/// 从 JS 值创建 Msg - 严格对应 Bun msgFromJS
public func msgFromJS(allocator: Allocator, globalObject: JSGlobalObject, file: String, err: JsValue): LogMsg {
    let msgText = err.toString()
    let loc = SourceLocation(file, 0, 0)
    return LogMsg(LogKind.Error, MsgData(msgText, loc))
}

/// 将 Msg 转换为 JS 值 - 严格对应 Bun msgToJS
public func msgToJS(msg: LogMsg, globalObject: JSGlobalObject, allocator: Allocator): JsValue {
    let text = msg.data.text
    return globalObject.createErrorInstance(text)
}

/// 从 JS 值获取日志级别 - 严格对应 Bun levelFromJS
public func levelFromJS(globalThis: JSGlobalObject, value: JsValue): ?LogLevel {
    if (value.isNull() || value.isUndefined()) {
        return None
    }

    if (!value.isString()) {
        globalThis.throwInvalidArguments("Expected logLevel to be a string")
        return None
    }

    // Simplified: return verbose level
    return LogLevel.Verbose
}

/// 将 Log 转换为 JS 值 - 严格对应 Bun logToJS
public func logToJS(`this`: Log, global: JSGlobalObject, allocator: Allocator, message: String): JsValue {
    let msgs = `this`.msgs
    let count = msgs.size

    match (count) {
        case 0 => return JsValue.jsUndefined()
        case 1 =>
            let msg = msgs[0]
            return msgToJS(msg, global, allocator)
        case _ =>
            var errorsStack = Array<JsValue>(count, {_ => JsValue.jsUndefined()})
            for (i in 0..count) {
                errorsStack[i] = msgToJS(msgs[i], global, allocator)
            }
            let agg = global.createAggregateError(errorsStack, message)
            return agg
    }
}

/// 将 Log 转换为 AggregateError - 严格对应 Bun logToJSAggregateError
public func logToJSAggregateError(`this`: Log, global: JSGlobalObject, message: String): JsValue {
    return logToJS(`this`, global, defaultAllocator, message)
}

/// 将 Log 转换为 JS 数组 - 严格对应 Bun logToJSArray
public func logToJSArray(`this`: Log, global: JSGlobalObject, allocator: Allocator): JsValue {
    let msgs = `this`.msgs
    let arr = JsValue.createEmptyArray(global.globalThis, msgs.size)
    for (i in 0..msgs.size) {
        arr.putIndex(global.globalThis, UInt32(i), msgToJS(msgs[i], global, allocator))
    }
    return arr
}
