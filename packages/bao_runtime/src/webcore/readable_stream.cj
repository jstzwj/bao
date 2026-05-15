// ReadableStream - 可读流
// 对应 Bun: src/runtime/webcore/ReadableStream.zig
// 严格翻译自: src/runtime/webcore/ReadableStream.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// ReadableStreamTag - 可读流源类型标签
// 对应 Bun: ReadableStream.Tag
// ============================================================================

/// 可读流源类型标签
/// 对应 Bun: ReadableStream.Tag
public enum ReadableStreamTag {
    | Invalid      // 无效 (-1)
    | JavaScript   // JS ReadableStreamDefaultController (0)
    | Blob         // Blob 加载器 (1)
    | File         // File 加载器 (2)
    | Direct       // 直接流 (3)
    | Bytes        // 字节流 (4)
}

// ============================================================================
// ReadableStreamSource - 可读流数据源
// 对应 Bun: ReadableStream.Source
// ============================================================================

/// 可读流数据源
/// 对应 Bun: ReadableStream.Source
public class ReadableStreamSource {
    /// 源类型
    public var tag: ReadableStreamTag
    /// 内部缓冲区
    public var buffer: ArrayList<UInt8>
    /// 是否已收到最后一块数据
    public var hasReceivedLastChunk: Bool
    /// 是否已取消
    public var cancelled: Bool

    public init() {
        tag = ReadableStreamTag.Invalid
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        cancelled = false
    }

    public init(tag: ReadableStreamTag) {
        this.tag = tag
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        cancelled = false
    }

    /// 取消流
    public func cancel(): Unit {
        cancelled = true
        hasReceivedLastChunk = true
    }
}

// ============================================================================
// ReadableStream - 可读流
// 对应 Bun: src/runtime/webcore/ReadableStream.zig ReadableStream
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream
// ============================================================================

/// ReadableStream — 可读字节流
/// 对应 Web API: ReadableStream
/// 对应 Bun: src/runtime/webcore/ReadableStream.zig ReadableStream
public class ReadableStream {
    /// JS 值引用
    /// 对应 Bun: ReadableStream.value
    public var value: JsValue
    /// 数据源
    /// 对应 Bun: ReadableStream.ptr (Source)
    public var source: ReadableStreamSource
    /// 是否已锁定
    public var locked: Bool
    /// 是否已被消费
    public var disturbed: Bool

    public init() {
        value = JsValue.NULL
        source = ReadableStreamSource()
        locked = false
        disturbed = false
    }

    public init(source: ReadableStreamSource) {
        value = JsValue.NULL
        this.source = source
        locked = false
        disturbed = false
    }

    // ========================================================================
    // ReadableStream.Strong — 强引用
    // 对应 Bun: ReadableStream.Strong
    // ========================================================================

    /// 是否有引用
    /// 对应 Bun: ReadableStream.Strong.has()
    public func has(): Bool {
        return value.valueType != JsValueType.Null && value.valueType != JsValueType.Undefined
    }

    /// 检查流是否已被消费
    /// 对应 Bun: ReadableStream.isDisturbed()
    public func isDisturbed(): Bool {
        return disturbed
    }

    /// 标记流为已消费
    public func markDisturbed(): Unit {
        disturbed = true
    }

    /// 完成流
    /// 对应 Bun: ReadableStream.done()
    public func done(): Unit {
        source.cancel()
        disturbed = true
    }

    /// 取消流
    /// 对应 Bun: ReadableStream.cancel()
    public func cancel(): Unit {
        source.cancel()
        disturbed = true
        locked = false
    }

    /// 使用指定原因取消流
    /// 对应 Bun: ReadableStream.cancelWithReason()
    public func cancelWithReason(reason: String): Unit {
        cancel()
    }

    /// 中止流
    /// 对应 Bun: ReadableStream.abort()
    public func abort(): Unit {
        cancel()
    }

    /// 强制分离流
    /// 对应 Bun: ReadableStream.forceDetach()
    public func forceDetach(): Unit {
        source = ReadableStreamSource()
        disturbed = true
    }

    /// 分流 (tee)
    /// 对应 Bun: ReadableStream.tee()
    /// 对应 Web API: readableStream.tee()
    public func tee(): (ReadableStream, ReadableStream) {
        let stream1 = ReadableStream(ReadableStreamSource(source.tag))
        let stream2 = ReadableStream(ReadableStreamSource(source.tag))
        // 复制缓冲区到两个流
        for (b in source.buffer) {
            stream1.source.buffer.append(b)
            stream2.source.buffer.append(b)
        }
        stream1.source.hasReceivedLastChunk = source.hasReceivedLastChunk
        stream2.source.hasReceivedLastChunk = source.hasReceivedLastChunk
        return (stream1, stream2)
    }

    /// 将流转为 AnyBlob (如果可能)
    /// 对应 Bun: ReadableStream.toAnyBlob()
    public func toAnyBlob(): ?Blob {
        if (disturbed) {
            return None
        }
        if (source.buffer.size > 0) {
            let bytes = source.buffer.toArray()
            let blob = Blob(bytes, "")
            done()
            return Some(blob)
        }
        return None
    }

    /// 创建已使用的流
    /// 对应 Bun: ReadableStream.used()
    public static func used(): ReadableStream {
        let stream = ReadableStream()
        stream.disturbed = true
        stream.source.hasReceivedLastChunk = true
        return stream
    }

    /// 创建空流
    /// 对应 Bun: ReadableStream.empty()
    public static func empty(): ReadableStream {
        let stream = ReadableStream()
        stream.source.hasReceivedLastChunk = true
        return stream
    }

    /// 从 Blob 创建可读流
    /// 对应 Bun: ReadableStream.fromBlobCopyRef()
    public static func fromBlob(blob: Blob): ReadableStream {
        let source = ReadableStreamSource(ReadableStreamTag.Blob)
        let bytes = blob.sharedView()
        for (b in bytes) {
            source.buffer.append(b)
        }
        source.hasReceivedLastChunk = true
        return ReadableStream(source)
    }

    /// 从字节数组创建可读流
    public static func fromBytes(bytes: Array<UInt8>): ReadableStream {
        let source = ReadableStreamSource(ReadableStreamTag.Bytes)
        for (b in bytes) {
            source.buffer.append(b)
        }
        source.hasReceivedLastChunk = true
        return ReadableStream(source)
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("locked", JsValue(self.locked))

        obj.set("cancel", JsValue.nativeFunction(JsNativeFunction("cancel") { _ =>
            self.cancel()
            JsValue.UNDEFINED
        }))

        obj.set("getReader", JsValue.nativeFunction(JsNativeFunction("getReader") { _ =>
            self.locked = true
            let reader = ReadableStreamDefaultReader(self)
            return reader.toJsValue()
        }))

        obj.set("tee", JsValue.nativeFunction(JsNativeFunction("tee") { _ =>
            let (stream1, stream2) = self.tee()
            let arr = ArrayList<JsValue>()
            arr.append(stream1.toJsValue())
            arr.append(stream2.toJsValue())
            JsValue.array(arr)
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// ReadableStreamDefaultReader - 可读流默认读取器
// 对应 Web API: ReadableStreamDefaultReader
// ============================================================================

/// ReadableStreamDefaultReader — 可读流默认读取器
/// 对应 Web API: ReadableStreamDefaultReader
public class ReadableStreamDefaultReader {
    /// 关联的流
    public var stream: ReadableStream
    /// 读取位置
    public var position: Int64

    public init(stream: ReadableStream) {
        this.stream = stream
        position = 0
    }

    /// 读取下一个块
    /// 对应 Web API: reader.read()
    public func read(): ReadResult {
        if (position < stream.source.buffer.size) {
            let chunk = ArrayList<UInt8>()
            // 每次读取一个块
            let chunkSize = 4096
            var count = 0
            while (position < stream.source.buffer.size && count < chunkSize) {
                chunk.append(stream.source.buffer[position])
                position += 1
                count += 1
            }
            let done = position >= stream.source.buffer.size && stream.source.hasReceivedLastChunk
            return ReadResult(Some(chunk.toArray()), done)
        }
        if (stream.source.hasReceivedLastChunk) {
            return ReadResult(None, true)
        }
        return ReadResult(None, false)
    }

    /// 释放读取器锁
    /// 对应 Web API: reader.releaseLock()
    public func releaseLock(): Unit {
        stream.locked = false
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("read", JsValue.nativeFunction(JsNativeFunction("read") { _ =>
            let result = self.read()
            let resultObj = JsObject()
            match (result.value) {
                case Some(bytes) => {
                    let arr = ArrayList<JsValue>()
                    for (b in bytes) {
                        arr.append(JsValue(Float64(Int64(b))))
                    }
                    resultObj.set("value", JsValue.array(arr))
                }
                case None => resultObj.set("value", JsValue.UNDEFINED)
            }
            resultObj.set("done", JsValue(result.done))
            JsValue(resultObj)
        }))

        obj.set("releaseLock", JsValue.nativeFunction(JsNativeFunction("releaseLock") { _ =>
            self.releaseLock()
            JsValue.UNDEFINED
        }))

        obj.set("closed", JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue()))

        return JsValue(obj)
    }
}

// ============================================================================
// ReadResult - 读取结果
// ============================================================================

/// 读取结果
/// 对应 Web API: ReadableStreamDefaultReader 返回值
public class ReadResult {
    /// 值 (字节数组)
    public var value: ?Array<UInt8>
    /// 是否完成
    public var done: Bool

    public init(value: ?Array<UInt8>, done: Bool) {
        this.value = value
        this.done = done
    }
}
