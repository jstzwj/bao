// ArrayBufferSink - ArrayBuffer 接收器
// 对应 Bun: src/runtime/webcore/ArrayBufferSink.zig
// 严格翻译自: src/runtime/webcore/ArrayBufferSink.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// ArrayBufferSink - ArrayBuffer 接收器
// 对应 Bun: src/runtime/webcore/ArrayBufferSink.zig ArrayBufferSink
// ============================================================================

/// ArrayBufferSink — 将流数据收集到 ArrayBuffer/Uint8Array
/// 对应 Bun: src/runtime/webcore/ArrayBufferSink.zig ArrayBufferSink
public class ArrayBufferSink {
    /// 字节缓冲区
    /// 对应 Bun: ArrayBufferSink.bytes
    public var bytes: ArrayList<UInt8>
    /// 是否完成
    /// 对应 Bun: ArrayBufferSink.done
    public var done: Bool
    /// 是否流式模式
    /// 对应 Bun: ArrayBufferSink.streaming
    public var streaming: Bool
    /// 是否为 Uint8Array
    /// 对应 Bun: ArrayBufferSink.as_uint8array
    public var asUint8Array: Bool
    /// 状态
    public var status: SinkStatus

    public init() {
        bytes = ArrayList<UInt8>()
        done = false
        streaming = false
        asUint8Array = false
        status = SinkStatus.Closed
    }

    /// 连接信号
    /// 对应 Bun: ArrayBufferSink.connect()
    public func connect(signal: StreamSignal): Unit {
        status = SinkStatus.Ready
        signal.start()
    }

    /// 启动
    /// 对应 Bun: ArrayBufferSink.start()
    public func start(chunkSize: Int64, asUint8Array: Bool, streaming: Bool): Unit {
        bytes.clear()
        this.asUint8Array = asUint8Array
        this.streaming = streaming
        this.done = false
        this.status = SinkStatus.Ready
    }

    /// 刷新缓冲区
    /// 对应 Bun: ArrayBufferSink.flush()
    public func flush(): Unit {
        // 无操作 — 数据保留在缓冲区
    }

    /// 写入数据
    /// 对应 Bun: ArrayBufferSink.write()
    public func write(data: Array<UInt8>): SinkWriteResult {
        if (status == SinkStatus.Closed) {
            return SinkWriteResult.Error("ArrayBufferSink is closed")
        }
        for (b in data) {
            bytes.append(b)
        }
        return SinkWriteResult.Done
    }

    /// 结束
    /// 对应 Bun: ArrayBufferSink.end()
    public func end(err: ?String): Unit {
        done = true
        status = SinkStatus.Closed
    }

    /// 获取当前缓冲区数据的副本
    /// 对应 Bun: ArrayBufferSink.flushFromJS()
    public func toBytes(): Array<UInt8> {
        return bytes.toArray()
    }

    /// 释放资源
    /// 对应 Bun: ArrayBufferSink.finalize()
    public func finalize(): Unit {
        destroy()
    }

    /// 销毁
    /// 对应 Bun: ArrayBufferSink.destroy()
    public func destroy(): Unit {
        bytes.clear()
        status = SinkStatus.Closed
        done = true
    }
}
