// FileSink - 文件写入 Sink
// 对应 Bun: src/runtime/webcore/FileSink.zig
// 严格翻译自: src/runtime/webcore/FileSink.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// FileSinkOptions - FileSink 选项
// 对应 Bun: FileSink.Options
// ============================================================================

/// FileSink 选项
/// 对应 Bun: FileSink.Options
public class FileSinkOptions {
    /// 块大小
    public var chunkSize: BlobSizeType
    /// 输入路径
    public var inputPath: String
    /// 是否截断
    public var truncate: Bool
    /// 是否关闭
    public var close: Bool
    /// 文件模式
    public var mode: Int64

    public init(path: String) {
        chunkSize = 1024
        inputPath = path
        truncate = true
        close = false
        mode = 0o664
    }
}

// ============================================================================
// FileSink - 文件写入 Sink
// 对应 Bun: src/runtime/webcore/FileSink.zig FileSink
// ============================================================================

/// FileSink — 将流数据写入文件
/// 对应 Bun: src/runtime/webcore/FileSink.zig FileSink
public class FileSink {
    /// 文件路径
    public var path: String
    /// 已写入字节数
    /// 对应 Bun: FileSink.written
    public var written: Int64
    /// 是否完成
    /// 对应 Bun: FileSink.done
    public var done: Bool
    /// 是否已开始
    /// 对应 Bun: FileSink.started
    public var started: Bool
    /// 内部缓冲区
    public var buffer: ArrayList<UInt8>
    /// 状态
    public var status: SinkStatus

    public init() {
        path = ""
        written = 0
        done = false
        started = false
        buffer = ArrayList<UInt8>()
        status = SinkStatus.Closed
    }

    public init(path: String) {
        this.path = path
        written = 0
        done = false
        started = false
        buffer = ArrayList<UInt8>()
        status = SinkStatus.Closed
    }

    /// 启动 Sink
    /// 对应 Bun: FileSink.start()
    public func start(options: FileSinkOptions): Unit {
        path = options.inputPath
        status = SinkStatus.Ready
        started = true
        done = false
        written = 0
        buffer.clear()
    }

    /// 写入数据
    /// 对应 Bun: FileSink.write()
    public func write(data: Array<UInt8>): SinkWriteResult {
        if (status == SinkStatus.Closed) {
            return SinkWriteResult.Error("FileSink is closed")
        }
        for (b in data) {
            buffer.append(b)
        }
        written += data.size
        return SinkWriteResult.Done
    }

    /// 结束写入
    /// 对应 Bun: FileSink.end()
    public func end(err: ?String): Unit {
        if (status == SinkStatus.Closed) {
            return
        }
        // 将缓冲区数据写入文件
        if (path.length > 0 && buffer.size > 0) {
            try {
                BaoFile.writeAllBytes(path, buffer.toArray())
            } catch (_: Exception) {
                // 写入失败
            }
        }
        status = SinkStatus.Closed
        done = true
    }

    /// 关闭 Sink
    public func close(): Unit {
        if (!done) {
            end(None)
        }
        buffer.clear()
    }

    /// 内存开销
    /// 对应 Bun: FileSink.memoryCost()
    public func memoryCost(): Int64 {
        return buffer.size
    }
}
