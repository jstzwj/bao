// 严格翻译自: src/runtime/api/UnsafeObject.zig
package bao_runtime

import bao_jsc.*
import bao_core.*

// ============================================================================
// UnsafeObject - Bun.unsafe 全局对象
// 对应 Bun: src/runtime/api/UnsafeObject.zig
// ============================================================================

/// 创建 Unsafe 对象，挂载到 Bun.unsafe
public func create(globalThis: JsGlobalObject): JsValue {
    let object = JsValue.createEmptyObject(globalThis, 3)

    // gcAggressionLevel
    object.put(
        globalThis,
        ZigString.static("gcAggressionLevel"),
        JsFunction.create(globalThis, "gcAggressionLevel", gcAggressionLevel, 1),
    )

    // arrayBufferToString
    object.put(
        globalThis,
        ZigString.static("arrayBufferToString"),
        JsFunction.create(globalThis, "arrayBufferToString", arrayBufferToString, 1),
    )

    // mimallocDump
    object.put(
        globalThis,
        ZigString.static("mimallocDump"),
        JsFunction.create(globalThis, "mimallocDump", dumpMimalloc, 1),
    )

    return object
}

/// 获取或设置 GC 激进程度
/// Bun.unsafe.gcAggressionLevel(0|1|2)
/// 0 = none, 1 = mild, 2 = aggressive
public func gcAggressionLevel(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
    let ret = JsValue.jsNumber(Int32(globalThis.bunVM().aggressive_garbage_collection.rawValue))
    let value = callframe.argumentsOld(1).ptr[0]

    if (!value.isEmptyOrUndefinedOrNull()) {
        switch (try value.coerceInt32(globalThis)) {
            case 1 => globalThis.bunVM().aggressive_garbage_collection = .mild
            case 2 => globalThis.bunVM().aggressive_garbage_collection = .aggressive
            case 0 => globalThis.bunVM().aggressive_garbage_collection = .none
            else => {}
        }
    }
    return ret
}

/// 将 ArrayBuffer 转换为字符串
/// 支持 Uint16Array/Int16Array (UTF-16) 和其他类型 (Latin1)
public func arrayBufferToString(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
    let args = callframe.argumentsOld(2).slice()
    if (args.len < 1 || !args[0].isCell() || !args[0].jsType().isTypedArrayOrArrayBuffer()) {
        return globalThis.throwInvalidArguments("Expected an ArrayBuffer")
    }

    let arrayBuffer = ArrayBuffer.fromTypedArray(globalThis, args[0])
    switch (arrayBuffer.typed_array_type) {
        case .Uint16Array, .Int16Array => {
            var zigStr = ZigString.init("")
            zigStr._unsafe_ptr_do_not_use = arrayBuffer.ptr
            zigStr.len = arrayBuffer.len
            zigStr.markUTF16()
            return zigStr.toJS(globalThis)
        }
        else => {
            return ZigString.init(arrayBuffer.slice()).toJS(globalThis)
        }
    }
}

/// 输出 mimalloc 内存分配统计信息
public func dumpMimalloc(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
    globalObject.bunVM().arena.dumpStats()
    if (HeapBreakdown.enabled) {
        dumpZoneMallocStats()
    }
    return JsValue.jsUndefined()
}

// ============================================================================
// 外部函数声明
// ============================================================================

/// 外部 C 函数: 输出 zone malloc 统计信息
extern func dumpZoneMallocStats()
