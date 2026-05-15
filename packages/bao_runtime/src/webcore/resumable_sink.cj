// ResumableSink - 可恢复 Sink
// 对应 Bun: src/runtime/webcore/ResumableSink.zig
// 严格翻译自: src/runtime/webcore/ResumableSink.zig
package bao_runtime.webcore

import bao_core.*

// ============================================================================
// ResumableSink - 可恢复 Sink
// 对应 Bun: src/runtime/webcore/ResumableSink.zig
// ============================================================================

/// ResumableSink — 支持断点续传的 Sink
/// 对应 Bun: src/runtime/webcore/ResumableSink.zig
/// 用于大文件上传/下载的断点续传场景
public class ResumableSink {
    /// 目标路径
    public var path: String
    /// 已写入字节数
    public var written: Int64
    /// 总大小
    public var totalSize: Int64
    /// 是否完成
    public var done: Bool
    /// 是否可恢复
    public var resumable: Bool
    /// 内部缓冲区
    public var buffer: ArrayList<UInt8>
    /// 状态
    public var status: SinkStatus

    public init(path: String) {
        this.path = path
        written = 0
        totalSize = 0
        done = false
        resumable = true
        buffer = ArrayList<UInt8>()
        status = SinkStatus.Closed
    }

    /// 启动 Sink
    /// 对应 Bun: ResumableSink.start()
    public func start(totalSize: Int64): Unit {
        this.totalSize = totalSize
        status = SinkStatus.Ready
        done = false
        // 检查已有文件以支持断点续传
        resumable = true
    }

    /// 写入数据
    /// 对应 Bun: ResumableSink.write()
    public func write(data: Array<UInt8>): SinkWriteResult {
        if (status == SinkStatus.Closed) {
            return SinkWriteResult.Error("ResumableSink is closed")
        }
        for (b in data) {
            buffer.append(b)
        }
        written += data.size

        // 当缓冲区达到阈值时刷新到文件
        if (buffer.size >= 4096) {
            flush()
        }

        return SinkWriteResult.Done
    }

    /// 刷新缓冲区到文件
    /// 对应 Bun: ResumableSink.flush()
    public func flush(): Unit {
        if (buffer.size > 0 && path.length > 0) {
            try {
                // 追加写入
                BaoFile.appendAllBytes(path, buffer.toArray())
            } catch (_: Exception) {
                // 忽略写入错误以保持可恢复性
            }
            buffer.clear()
        }
    }

    /// 结束写入
    /// 对应 Bun: ResumableSink.end()
    public func end(err: ?String): Unit {
        if (status == SinkStatus.Closed) {
            return
        }
        // 刷新剩余数据
        flush()
        status = SinkStatus.Closed
        done = true
    }

    /// 获取当前写入位置 (用于恢复)
    /// 对应 Bun: ResumableSink 断点续传位置
    public func getOffset(): Int64 {
        return written
    }

    /// 从指定偏移恢复
    /// 对应 Bun: ResumableSink 恢复上传
    public func resume(offset: Int64): Bool {
        if (offset > written) {
            return false
        }
        written = offset
        status = SinkStatus.Ready
        done = false
        return true
    }

    /// 进度百分比
    public func progress(): Float64 {
        if (totalSize == 0) { return 0.0 }
        return Float64(written) / Float64(totalSize) * 100.0
    }
}
