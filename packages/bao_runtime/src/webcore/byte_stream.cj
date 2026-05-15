// ByteStream - 字节流
// 对应 Bun: src/runtime/webcore/ByteStream.zig
// 严格翻译自: src/runtime/webcore/ByteStream.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// ByteStream - 字节流
// 对应 Bun: src/runtime/webcore/ByteStream.zig ByteStream
// ============================================================================

/// ByteStream — 字节流实现
/// 对应 Bun: src/runtime/webcore/ByteStream.zig ByteStream
public class ByteStream {
    /// 内部缓冲区
    /// 对应 Bun: ByteStream.buffer
    public var buffer: ArrayList<UInt8>
    /// 是否已收到最后一块数据
    /// 对应 Bun: ByteStream.has_received_last_chunk
    public var hasReceivedLastChunk: Bool
    /// 是否已完成
    /// 对应 Bun: ByteStream.done
    public var done: Bool
    /// 读取偏移
    /// 对应 Bun: ByteStream.offset
    public var offset: Int64
    /// 高水位标记
    /// 对应 Bun: ByteStream.highWaterMark
    public var highWaterMark: BlobSizeType
    /// 大小提示
    /// 对应 Bun: ByteStream.size_hint
    public var sizeHint: BlobSizeType
    /// 管道回调
    /// 对应 Bun: ByteStream.pipe
    public var pipeCallback: ?ByteStreamPipeCallback

    public init() {
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        done = false
        offset = 0
        highWaterMark = 0
        sizeHint = 0
        pipeCallback = None
    }

    /// 初始化
    /// 对应 Bun: ByteStream.setup()
    public func setup(): Unit {
        buffer = ArrayList<UInt8>()
        hasReceivedLastChunk = false
        done = false
        offset = 0
        highWaterMark = 0
        sizeHint = 0
        pipeCallback = None
    }

    /// 流启动回调
    /// 对应 Bun: ByteStream.onStart()
    public func onStart(): StreamStartResult {
        if (hasReceivedLastChunk && buffer.size == 0) {
            return StreamStartResult.Empty
        }
        if (hasReceivedLastChunk) {
            return StreamStartResult.OwnedAndDone(buffer.toArray())
        }
        if (highWaterMark == 0) {
            return StreamStartResult.Ready
        }
        // 最大流式响应大小
        let chunkSize = if (highWaterMark > 0) {
            min(highWaterMark, 524288 + 4096)  // 512KB + 1 page
        } else {
            524288 + 4096
        }
        return StreamStartResult.ChunkSize(chunkSize)
    }

    /// 接收数据
    /// 对应 Bun: ByteStream.onData()
    public func onData(data: ArrayList<UInt8>, isDone: Bool): Unit {
        if (done) {
            hasReceivedLastChunk = isDone
            return
        }
        hasReceivedLastChunk = isDone

        // 如果有管道回调，直接传递
        match (pipeCallback) {
            case Some(cb) => {
                cb.onPipe(data.toArray(), isDone)
                return
            }
            case None => ()
        }

        // 追加到缓冲区
        for (b in data) {
            buffer.append(b)
        }
    }

    /// 接收错误
    /// 对应 Bun: ByteStream.onData() error path
    public func onError(error: String): Unit {
        done = true
        hasReceivedLastChunk = true
    }

    /// 取消管道
    /// 对应 Bun: ByteStream.unpipeWithoutDeref()
    public func unpipeWithoutDeref(): Unit {
        pipeCallback = None
    }

    /// 转为 AnyBlob
    /// 对应 Bun: ByteStream.toAnyBlob()
    public func toAnyBlob(): ?Blob {
        if (buffer.size > 0) {
            let bytes = buffer.toArray()
            let blob = Blob(bytes, "")
            return Some(blob)
        }
        if (hasReceivedLastChunk) {
            return Some(Blob.initEmpty())
        }
        return None
    }

    /// 获取流标签
    /// 对应 Bun: ByteStream.tag
    public func tag(): ReadableStreamTag {
        return ReadableStreamTag.Bytes
    }
}

// ============================================================================
// StreamStartResult - 流启动结果
// 对应 Bun: streams.Start
// ============================================================================

/// 流启动结果
/// 对应 Bun: streams.Start
public enum StreamStartResult {
    | Empty                          // 空
    | Error(String)                  // 错误
    | ChunkSize(BlobSizeType)        // 块大小
    | Ready                          // 就绪
    | OwnedAndDone(Array<UInt8>)     // 拥有数据且完成
    | Done(Array<UInt8>)             // 完成 (数据引用)
}

// ============================================================================
// ByteStreamPipeCallback - 字节流管道回调
// 对应 Bun: Pipe.Wrap
// ============================================================================

/// 字节流管道回调
/// 对应 Bun: Pipe.Wrap
public interface ByteStreamPipeCallback {
    /// 管道数据回调
    func onPipe(data: Array<UInt8>, isDone: Bool): Unit
}

// ============================================================================
// ByteStreamSource - 字节流数据源
// 对应 Bun: ByteStream.Source
// ============================================================================

/// 字节流数据源 — 用于 ReadableStream
/// 对应 Bun: ByteStream.Source
public class ByteStreamSource {
    /// 字节流实例
    public var context: ByteStream
    /// 全局对象引用
    public var globalThis: String

    public init(context: ByteStream) {
        this.context = context
        globalThis = ""
    }

    /// 获取父级 (自身)
    public func parent(): ByteStreamSource {
        return this
    }

    /// 取消
    public func cancel(): Unit {
        context.done = true
        context.hasReceivedLastChunk = true
    }

    /// 转为 ReadableStream
    public func toReadableStream(): ReadableStream {
        let source = ReadableStreamSource(ReadableStreamTag.Bytes)
        for (b in context.buffer) {
            source.buffer.append(b)
        }
        source.hasReceivedLastChunk = context.hasReceivedLastChunk
        return ReadableStream(source)
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        return context.buffer.size
    }
}
