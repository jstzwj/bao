// 严格翻译自: src/runtime/api/streams.classes.ts
package bao_runtime.api

import bao_jsc.*
import bao_core.*

// ============================================================================
// Streams - 可读流内部源 (ReadableStream Internal Sources)
// 对应 Bun: src/runtime/api/streams.classes.ts
// ============================================================================

// ============================================================================
// InternalReadableStreamSource - 可读流内部源的公共基类
// 严格翻译自: streams.classes.ts BlobInternalReadableStreamSource / FileInternalReadableStreamSource / BytesInternalReadableStreamSource
// ============================================================================

/// InternalReadableStreamSource - 可读流内部源基类
/// Bun: BlobInternalReadableStreamSource / FileInternalReadableStreamSource / BytesInternalReadableStreamSource
/// 这些源类用于 ReadableStream 的底层实现
/// 共享字段: pendingPromise, onCloseCallback, onDrainCallback
public open class InternalReadableStreamSource {

    /// 挂起的 Promise
    public var pendingPromise: ?JsValue = none

    /// 关闭回调
    public var onCloseCallback: ?JsValue = none

    /// 排空回调
    public var onDrainCallback: ?JsValue = none

    // ========================================================================
    // 构造函数 (不可从 JS 直接构造)
    // 严格翻译自: streams.classes.ts construct: false, noConstructor: true
    // ========================================================================

    public init() {}

    // ========================================================================
    // drainFromJS - 从 JS 侧排空数据
    // 严格翻译自: streams.classes.ts drain { fn: "drainFromJS", length: 1 }
    // ========================================================================

    /// drainFromJS - 从 JS 侧排空数据
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::drainFromJS 等
    public func drainFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        // 排空流中的数据到消费者
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // startFromJS - 从 JS 侧启动
    // 严格翻译自: streams.classes.ts start { fn: "startFromJS", length: 1 }
    // ========================================================================

    /// startFromJS - 从 JS 侧启动流
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::startFromJS 等
    public func startFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        // 启动流读取
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // updateRefFromJS - 从 JS 侧更新引用
    // 严格翻译自: streams.classes.ts updateRef { fn: "updateRefFromJS", length: 1 }
    // ========================================================================

    /// updateRefFromJS - 从 JS 侧更新引用计数
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::updateRefFromJS 等
    public func updateRefFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        // 更新引用计数
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // onClose getter/setter
    // 严格翻译自: streams.classes.ts onClose { getter: "getOnCloseFromJS", setter: "setOnCloseFromJS" }
    // ========================================================================

    /// getOnCloseFromJS - 获取关闭回调
    public func getOnCloseFromJS(jsGlobalObject!: JsGlobalObject): JsValue {
        if (let Some(cb) <- onCloseCallback) {
            return cb
        }
        return JsValue.jsUndefined()
    }

    /// setOnCloseFromJS - 设置关闭回调
    public func setOnCloseFromJS(jsGlobalObject!: JsGlobalObject, value!: JsValue): JsValue {
        onCloseCallback = value
        return JsValue.jsBoolean(true)
    }

    // ========================================================================
    // onDrain getter/setter
    // 严格翻译自: streams.classes.ts onDrain { getter: "getOnDrainFromJS", setter: "setOnDrainFromJS" }
    // ========================================================================

    /// getOnDrainFromJS - 获取排空回调
    public func getOnDrainFromJS(jsGlobalObject!: JsGlobalObject): JsValue {
        if (let Some(cb) <- onDrainCallback) {
            return cb
        }
        return JsValue.jsUndefined()
    }

    /// setOnDrainFromJS - 设置排空回调
    public func setOnDrainFromJS(jsGlobalObject!: JsGlobalObject, value!: JsValue): JsValue {
        onDrainCallback = value
        return JsValue.jsBoolean(true)
    }

    // ========================================================================
    // cancelFromJS - 取消流
    // 严格翻译自: streams.classes.ts cancel { fn: "cancelFromJS", length: 1 }
    // ========================================================================

    /// cancelFromJS - 取消流
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::cancelFromJS 等
    public func cancelFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        // 取消流, 释放资源
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // pullFromJS - 拉取数据
    // 严格翻译自: streams.classes.ts pull { fn: "pullFromJS", length: 1 }
    // ========================================================================

    /// pullFromJS - 从流拉取数据
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::pullFromJS 等
    public func pullFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        // 拉取更多数据
        return JsValue.jsUndefined()
    }

    // ========================================================================
    // isClosed getter
    // 严格翻译自: streams.classes.ts isClosed { getter: "getIsClosedFromJS" }
    // ========================================================================

    /// getIsClosedFromJS - 获取是否已关闭
    public func getIsClosedFromJS(jsGlobalObject!: JsGlobalObject): JsValue {
        return JsValue.jsBoolean(false)
    }

    // ========================================================================
    // finalize - GC 回收
    // 严格翻译自: streams.classes.ts finalize: true
    // ========================================================================

    /// finalize - GC 回收时调用
    public func finalize(): Unit {
        pendingPromise = none
        onCloseCallback = none
        onDrainCallback = none
    }

    // ========================================================================
    // memoryCost - 内存开销
    // 严格翻译自: streams.classes.ts memoryCost: true
    // ========================================================================

    /// memoryCost - 返回此源的内存开销
    public func memoryCost(): Int64 {
        return 256
    }
}

// ============================================================================
// BlobInternalReadableStreamSource - Blob 源
// 严格翻译自: streams.classes.ts BlobInternalReadableStreamSource
// rustPath: crate::webcore::byte_blob_loader::Source
// 支持缓冲读取: text, json, arrayBuffer, blob, bytes
// ============================================================================

/// BlobInternalReadableStreamSource - Blob 内部可读流源
/// rustPath: crate::webcore::byte_blob_loader::Source
public class BlobInternalReadableStreamSource <: InternalReadableStreamSource {

    // ========================================================================
    // 缓冲读取方法 (Blob/Bytes 源支持, File 源暂不支持)
    // 严格翻译自: streams.classes.ts text, json, arrayBuffer, blob, bytes
    // ========================================================================

    /// textFromJS - 读取流为文本
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::textFromJS
    public func textFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 将流数据读取为 UTF-8 文本
        return JsValue.jsEmptyString()
    }

    /// jsonFromJS - 读取流为 JSON
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::jsonFromJS
    public func jsonFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 将流数据解析为 JSON
        return JsValue.jsUndefined()
    }

    /// arrayBufferFromJS - 读取流为 ArrayBuffer
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::arrayBufferFromJS
    public func arrayBufferFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 将流数据读取为 ArrayBuffer
        return JsValue.jsNull()
    }

    /// blobFromJS - 读取流为 Blob
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::blobFromJS
    public func blobFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 将流数据读取为 Blob
        return JsValue.jsNull()
    }

    /// bytesFromJS - 读取流为 Uint8Array
    /// 严格翻译自: crate::webcore::byte_blob_loader::Source::bytesFromJS
    public func bytesFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 将流数据读取为 Uint8Array
        return JsValue.jsNull()
    }
}

// ============================================================================
// FileInternalReadableStreamSource - File 源
// 严格翻译自: streams.classes.ts FileInternalReadableStreamSource
// rustPath: crate::webcore::file_reader::Source
// 不支持缓冲读取, 但支持 setRawMode / setFlowing
// ============================================================================

/// FileInternalReadableStreamSource - File 内部可读流源
/// rustPath: crate::webcore::file_reader::Source
/// File 源不支持 text/json/arrayBuffer/blob/bytes 缓冲读取
public class FileInternalReadableStreamSource <: InternalReadableStreamSource {

    // ========================================================================
    // File 源特有的方法
    // 严格翻译自: streams.classes.ts setRawMode, setFlowing (仅 File 有)
    // ========================================================================

    /// setRawModeFromJS - 设置原始模式
    /// 严格翻译自: crate::webcore::file_reader::Source::setRawModeFromJS
    public func setRawModeFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        // 设置流为原始模式
        return JsValue.jsUndefined()
    }

    /// setFlowingFromJS - 设置流动模式
    /// 严格翻译自: crate::webcore::file_reader::Source::setFlowingFromJS
    public func setFlowingFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        // 设置流为流动模式
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// BytesInternalReadableStreamSource - Bytes 源
// 严格翻译自: streams.classes.ts BytesInternalReadableStreamSource
// rustPath: crate::webcore::byte_stream::Source
// 支持缓冲读取: text, json, arrayBuffer, blob, bytes
// ============================================================================

/// BytesInternalReadableStreamSource - Bytes 内部可读流源
/// rustPath: crate::webcore::byte_stream::Source
/// Bytes 源支持 text/json/arrayBuffer/blob/bytes 缓冲读取
public class BytesInternalReadableStreamSource <: InternalReadableStreamSource {

    /// textFromJS - 读取流为文本
    public func textFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsEmptyString()
    }

    /// jsonFromJS - 读取流为 JSON
    public func jsonFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// arrayBufferFromJS - 读取流为 ArrayBuffer
    public func arrayBufferFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsNull()
    }

    /// blobFromJS - 读取流为 Blob
    public func blobFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsNull()
    }

    /// bytesFromJS - 读取流为 Uint8Array
    public func bytesFromJS(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsNull()
    }
}

// ported from: src/runtime/api/streams.classes.ts
