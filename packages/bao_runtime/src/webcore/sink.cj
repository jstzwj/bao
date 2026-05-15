// Sink - 流式 Sink
// 对应 Bun: src/runtime/webcore/Sink.zig
// 严格翻译自: src/runtime/webcore/Sink.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// SinkStatus - Sink 状态
// 对应 Bun: Sink.Status
// ============================================================================

/// Sink 状态
/// 对应 Bun: Sink.Status
public enum SinkStatus {
    | Ready     // 就绪
    | Closed    // 已关闭
}

// ============================================================================
// SinkData - Sink 数据类型
// 对应 Bun: Sink.Data
// ============================================================================

/// Sink 数据类型
/// 对应 Bun: Sink.Data
public enum SinkData {
    | UTF16(ArrayList<UInt8>)    // UTF-16 数据
    | Latin1(ArrayList<UInt8>)   // Latin-1 数据
    | Bytes(ArrayList<UInt8>)    // 字节数据
}

// ============================================================================
// SinkWriteResult - Sink 写入结果
// 对应 Bun: streams.Result.Writable
// ============================================================================

/// Sink 写入结果
/// 对应 Bun: streams.Result.Writable
public enum SinkWriteResult {
    | Done              // 完成
    | ChunkSize(Int64)  // 下一个期望的块大小
    | Error(String)     // 错误
}

// ============================================================================
// SinkVTable - Sink 虚表
// 对应 Bun: Sink.VTable
// ============================================================================

/// Sink 虚表 — 定义 Sink 的行为接口
/// 对应 Bun: Sink.VTable
public interface SinkVTable {
    /// 连接信号
    func connect(signal: StreamSignal): Unit

    /// 写入 UTF-8 数据
    func write(data: Array<UInt8>): SinkWriteResult

    /// 写入 Latin-1 数据
    func writeLatin1(data: Array<UInt8>): SinkWriteResult

    /// 写入 UTF-16 数据
    func writeUTF16(data: Array<UInt8>): SinkWriteResult

    /// 结束
    func end(err: ?String): Unit
}

// ============================================================================
// Sink - 流式 Sink 基类
// 对应 Bun: src/runtime/webcore/Sink.zig Sink
// ============================================================================

/// Sink — 流式写入目标
/// 对应 Bun: src/runtime/webcore/Sink.zig Sink
public class Sink {
    /// 状态
    /// 对应 Bun: Sink.status
    public var status: SinkStatus
    /// 是否已使用
    /// 对应 Bun: Sink.used
    public var used: Bool
    /// 内部缓冲区
    public var buffer: ArrayList<UInt8>

    public init() {
        status = SinkStatus.Closed
        used = false
        buffer = ArrayList<UInt8>()
    }

    /// 写入字节数据
    /// 对应 Bun: Sink.write()
    public func write(data: Array<UInt8>): SinkWriteResult {
        if (status == SinkStatus.Closed) {
            return SinkWriteResult.Error("Sink is closed")
        }
        for (b in data) {
            buffer.append(b)
        }
        return SinkWriteResult.Done
    }

    /// 写入 Latin-1 数据
    /// 对应 Bun: Sink.writeLatin1()
    public func writeLatin1(data: Array<UInt8>): SinkWriteResult {
        return write(data)
    }

    /// 写入 UTF-16 数据
    /// 对应 Bun: Sink.writeUTF16()
    public func writeUTF16(data: Array<UInt8>): SinkWriteResult {
        return write(data)
    }

    /// 结束 Sink
    /// 对应 Bun: Sink.end()
    public func end(err: ?String): Unit {
        if (status == SinkStatus.Closed) {
            return
        }
        status = SinkStatus.Closed
    }

    /// 连接信号
    /// 对应 Bun: Sink.connect()
    public func connect(signal: StreamSignal): Unit {
        status = SinkStatus.Ready
    }

    /// 获取缓冲区数据
    public func getBuffer(): Array<UInt8> {
        return buffer.toArray()
    }

    /// 关闭
    public func close(): Unit {
        status = SinkStatus.Closed
        buffer.clear()
    }
}

// ============================================================================
// StreamSignal - 流信号
// 对应 Bun: streams.Signal
// ============================================================================

/// 流信号
/// 对应 Bun: streams.Signal
public class StreamSignal {
    /// 是否启动
    public var started: Bool

    public init() {
        started = false
    }

    /// 启动信号
    public func start(): Unit {
        started = true
    }
}
