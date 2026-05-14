// bao_io - 增强 BufferedWriter
// 严格翻译自: src/io/PipeWriter.zig, src/io/MaxBuf.zig
//   Bun 的 PipeWriter 使用 writev 和缓冲策略高效写入
//   增强版支持自动增长缓冲区, 多种 flush 策略, writev
//   对应 Bun PipeWriter 的 drainBufferedData 和 tryWrite 模式
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// FlushStrategy - 刷新策略
// 严格翻译自: Bun PipeWriter 的不同刷新行为
//   Bun 根据 FileType 选择不同的写入和刷新策略
//   File: 直接写入
//   Pipe: 可能使用非阻塞写入
//   Socket: 使用 sendNonBlock
// ============================================================================

/// 刷新策略 - 对应 Bun PipeWriter 的写入策略
public enum FlushStrategy {
    | Immediate     // 立即刷新: 每次写入后立即 flush
    | OnFull        // 缓冲区满时刷新
    | OnThreshold   // 阈值触发: 缓冲区达到阈值时刷新
    | Manual        // 手动刷新: 只在显式调用 flush 时刷新
    | OnLine        // 行刷新: 遇到换行符时刷新

    public func description(): String {
        match (this) {
            case Immediate => "immediate"
            case OnFull => "on-full"
            case OnThreshold => "on-threshold"
            case Manual => "manual"
            case OnLine => "on-line"
        }
    }
}

// ============================================================================
// WritevEntry - writev 缓冲区条目
// 对应 POSIX iovec / libuv uv_buf_t
// ============================================================================

/// writev 缓冲区条目 - 对应 struct iovec
/// 用于 scatter-gather 写入 (writev 系统调用)
public class WritevEntry {
    /// 数据缓冲区
    public var data: Array<UInt8>
    /// 起始偏移
    public var offset: Int64
    /// 有效长度
    public var length: Int64

    public init(data: Array<UInt8>) {
        this.data = data
        this.offset = 0
        this.length = data.size
    }

    public init(data: Array<UInt8>, offset: Int64, length: Int64) {
        this.data = data
        this.offset = offset
        this.length = length
    }

    /// 获取有效切片
    public func slice(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..length) {
            result.append(data[offset + i])
        }
        return result
    }
}

// ============================================================================
// EnhancedBufferedWriter - 增强缓冲写入器
// 严格翻译自: src/io/PipeWriter.zig BufferedWriter + PosixPipeWriter
//   Bun 的 BufferedWriter 支持自动缓冲和刷新
//   增强版添加: 自动增长, flush 策略, writev, 写入统计
//   对应 Bun PipeWriter 的核心写入逻辑:
//     tryWrite -> drainBufferedData -> onWrite callback
// ============================================================================

/// 增强缓冲写入器 - 对应 Bun BufferedWriter + PosixPipeWriter
/// Bun: pub const BufferedWriter = struct { buffer: ?*StreamBuffer, ... }
/// 支持自动增长缓冲区, 多种刷新策略, writev 聚合写入
public class EnhancedBufferedWriter {
    /// 内部缓冲区
    private var buffer: ArrayList<UInt8>
    /// 缓冲区容量
    private var capacity: Int64
    /// 初始容量 (用于重置)
    private let initialCapacity: Int64
    /// 底层文件描述符
    private var fd: Int64
    /// 刷新策略
    public var flushStrategy: FlushStrategy
    /// 阈值 (用于 OnThreshold 策略)
    public var flushThreshold: Int64
    /// 总写入字节数
    public var totalWritten: Int64
    /// 总刷新次数
    public var flushCount: Int64
    /// 是否已关闭
    private var closed: Bool
    /// 写入错误回调 - 对应 Bun PipeWriter.onError
    public var onError: ?(SysError) -> Unit

    public init(fd: Int64) {
        this.fd = fd
        this.capacity = PIPE_BUF_SIZE
        this.initialCapacity = PIPE_BUF_SIZE
        this.buffer = ArrayList<UInt8>()
        this.flushStrategy = FlushStrategy.OnFull
        this.flushThreshold = MAX_BUF_SIZE
        this.totalWritten = 0
        this.flushCount = 0
        this.closed = false
        this.onError = None
    }

    public init(fd: Int64, capacity: Int64) {
        this.fd = fd
        this.capacity = capacity
        this.initialCapacity = capacity
        this.buffer = ArrayList<UInt8>()
        this.flushStrategy = FlushStrategy.OnFull
        this.flushThreshold = MAX_BUF_SIZE
        this.totalWritten = 0
        this.flushCount = 0
        this.closed = false
        this.onError = None
    }

    public init(fd: Int64, capacity: Int64, strategy: FlushStrategy) {
        this.fd = fd
        this.capacity = capacity
        this.initialCapacity = capacity
        this.buffer = ArrayList<UInt8>()
        this.flushStrategy = strategy
        this.flushThreshold = MAX_BUF_SIZE
        this.totalWritten = 0
        this.flushCount = 0
        this.closed = false
        this.onError = None
    }

    /// 写入单个字节
    /// 对应 Bun: PipeWriter 的逐字节写入
    public func write(b: UInt8): Unit {
        if (closed) {
            return
        }
        buffer.append(b)
        totalWritten += 1
        checkFlush()
    }

    /// 写入字节数组
    /// 对应 Bun: PipeWriter.write(data) -> WriteResult
    /// Bun PipeWriter.zig: fn tryWrite(this, force_sync, buf) WriteResult
    public func writeBytes(data: Array<UInt8>): WriteResult {
        if (closed) {
            return WriteResult(SysError(9, SysTag.Write))  // EBADF
        }
        for (b in data) {
            buffer.append(b)
        }
        totalWritten += data.size
        checkFlush()
        return WriteResult(data.size)
    }

    /// 写入字符串
    /// 对应 Bun: PipeWriter.writeString
    public func writeString(s: String): WriteResult {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return writeBytes(bytes)
    }

    /// 写入行 (追加换行符)
    /// 对应 Bun: PipeWriter.writeLine
    public func writeLine(line: String): WriteResult {
        let result = writeString(line)
        write(UInt8('\n'))
        return WriteResult(result.bytesWritten + 1)
    }

    /// 使用 writev 批量写入多个缓冲区
    /// 对应 Bun: pwritev / uv_fs_write 的 scatter-gather 写入
    /// Bun sys_uv.zig: pub fn pwritev(fd, bufs, position) Maybe(usize)
    public func writev(entries: Array<WritevEntry>): WriteResult {
        if (closed) {
            return WriteResult(SysError(9, SysTag.Writev))
        }
        var totalSize: Int64 = 0
        for (entry in entries) {
            let slice = entry.slice()
            for (b in slice) {
                buffer.append(b)
            }
            totalSize += entry.length
        }
        totalWritten += totalSize
        checkFlush()
        return WriteResult(totalSize)
    }

    /// 排空缓冲区到文件描述符
    /// 严格对应 Bun: PosixPipeWriter.drainBufferedData()
    /// Bun PipeWriter.zig:
    ///   pub fn drainBufferedData(parent, buf, max_write_size, received_hup) WriteResult
    ///   循环调用 tryWrite 直到缓冲区清空或遇到错误
    public func drainBufferedData(): WriteResult {
        if (buffer.size == 0) {
            return WriteResult(0)
        }
        if (closed) {
            return WriteResult(SysError(9, SysTag.Write))
        }

        var data = buffer.toArray()
        var offset: Int64 = 0
        var totalDrained: Int64 = 0

        while (offset < data.size) {
            let remaining = data.size - offset
            let chunkSize = if (remaining > MAX_BUF_SIZE) { MAX_BUF_SIZE } else { remaining }
            var chunk = Array<UInt8>()
            for (i in 0..chunkSize) {
                chunk.append(data[offset + i])
            }
            match (SysFs.write(fd, chunk)) {
                case SysMaybe<Int64>.Err(err) =>
                    // 对应 Bun: if (err.isRetry()) { return .pending }
                    if (err.isRetry()) {
                        // 部分写入: 保留未写入的数据
                        trimBuffer(offset + totalDrained)
                        return WriteResult(totalDrained)
                    }
                    // 对应 Bun: onError(parent, err)
                    match (onError) {
                        case Some(cb) => cb(err)
                        case None => ()
                    }
                    return WriteResult(err)
                case SysMaybe<Int64>.Ok(written) =>
                    offset += written
                    totalDrained += written
                    if (written == 0) {
                        // 写入返回 0 = EOF
                        trimBuffer(offset)
                        return WriteResult(totalDrained)
                    }
            }
        }
        // 全部写入完成
        buffer.clear()
        flushCount += 1
        return WriteResult(totalDrained)
    }

    /// 刷新缓冲区 - 对应 Bun PipeWriter.flush()
    public func flush(): WriteResult {
        if (buffer.size == 0) {
            return WriteResult(0)
        }
        return drainBufferedData()
    }

    /// 强制同步刷新 (fsync)
    public func flushSync(): SysMaybe<Unit> {
        let result = flush()
        if (!result.isOk()) {
            match (result.err) {
                case Some(e) => return SysMaybe<Unit>.Err(e)
                case None => ()
            }
        }
        return SysFs.fsync(fd)
    }

    /// 获取缓冲区大小
    public func bufferSize(): Int64 {
        return buffer.size
    }

    /// 获取可用容量
    public func available(): Int64 {
        return capacity - buffer.size
    }

    /// 检查是否需要自动增长
    /// 当缓冲区接近满时自动扩大
    public func ensureCapacity(needed: Int64): Unit {
        if (buffer.size + needed > capacity) {
            capacity = capacity * 2
            if (capacity < buffer.size + needed) {
                capacity = buffer.size + needed
            }
        }
    }

    /// 关闭写入器
    /// 对应 Bun: PipeWriter.close()
    public func close(): Unit {
        if (!closed) {
            flush()
            SysFs.close(fd)
            closed = true
        }
    }

    /// 关闭但不刷新
    /// 对应 Bun: PipeWriter.end()
    public func end(): Unit {
        if (!closed) {
            SysFs.close(fd)
            closed = true
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        return closed
    }

    /// 重置写入器 (重新使用)
    public func reset(newFd: Int64): Unit {
        buffer.clear()
        capacity = initialCapacity
        fd = newFd
        closed = false
    }

    /// 获取写入统计
    public func stats(): WriterStats {
        return WriterStats(totalWritten, flushCount, buffer.size, capacity)
    }

    // ===== 内部方法 =====

    /// 检查是否需要刷新
    private func checkFlush(): Unit {
        match (flushStrategy) {
            case FlushStrategy.Immediate =>
                flush()
            case FlushStrategy.OnFull =>
                if (buffer.size >= capacity) {
                    flush()
                }
            case FlushStrategy.OnThreshold =>
                if (buffer.size >= flushThreshold) {
                    flush()
                }
            case FlushStrategy.Manual =>
                ()  // 不自动刷新
            case FlushStrategy.OnLine =>
                // 检查最后一个字节是否为换行符
                if (buffer.size > 0 && buffer[Int64(buffer.size - 1)] == UInt8('\n')) {
                    flush()
                }
        }
    }

    /// 修剪缓冲区前 n 个字节
    private func trimBuffer(n: Int64): Unit {
        if (n <= 0) {
            return
        }
        var newBuffer = ArrayList<UInt8>()
        for (i in n..buffer.size) {
            newBuffer.append(buffer[Int64(i)])
        }
        buffer = newBuffer
    }
}

// ============================================================================
// WriterStats - 写入统计
// ============================================================================

/// 写入统计信息
public class WriterStats {
    /// 总写入字节数
    public var totalBytes: Int64
    /// 刷新次数
    public var flushCount: Int64
    /// 当前缓冲区大小
    public var bufferedBytes: Int64
    /// 缓冲区容量
    public var bufferCapacity: Int64

    public init(totalBytes: Int64, flushCount: Int64, bufferedBytes: Int64, bufferCapacity: Int64) {
        this.totalBytes = totalBytes
        this.flushCount = flushCount
        this.bufferedBytes = bufferedBytes
        this.bufferCapacity = bufferCapacity
    }

    /// 缓冲区利用率
    public func utilization(): Float64 {
        if (bufferCapacity == 0) {
            return 0.0
        }
        return Float64(bufferedBytes) / Float64(bufferCapacity)
    }
}
