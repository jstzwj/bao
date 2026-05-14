// bao_io - Writer 工具集
// 严格翻译自: Bun 的多种 Writer 抽象
//   Bun 使用不同的 Writer 策略处理输出:
//   CountingWriter - 统计写入字节数
//   MultiWriter - 广播写入到多个目标
//   TeeWriter - 同时写入两个目标 (类似 Unix tee)
//   用于日志、进度报告、响应分流等场景
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// Writer 接口
// 严格翻译自: Bun 中的 Writer 抽象
//   仓颉使用接口统一不同的写入目标
// ============================================================================

/// 写入器接口 - 对应 Bun 的写入抽象
/// 所有写入器都实现此接口
public interface Writer {
    /// 写入字节数组
    func write(data: Array<UInt8>): WriteResult
    /// 写入字符串
    func writeString(s: String): WriteResult
    /// 刷新
    func flush(): Unit
    /// 关闭
    func close(): Unit
}

// ============================================================================
// CountingWriter - 计数写入器
// 严格翻译自: Bun 中的写入计数功能
//   在写入时统计总字节数，不修改实际数据
//   用于: Content-Length 计算, 流量统计, 进度追踪
//   对应 Bun: 响应写入时统计 Content-Length
// ============================================================================

/// 计数写入器 - 包装另一个 Writer 并统计写入字节数
/// 写入数据透传到内部 Writer, 同时累计写入量
public class CountingWriter <: Writer {
    /// 内部写入器
    private var inner: Writer
    /// 总写入字节数
    public var totalBytes: Int64
    /// 写入次数
    public var writeCount: Int64
    /// 是否已关闭
    private var closed: Bool

    public init(inner: Writer) {
        this.inner = inner
        this.totalBytes = 0
        this.writeCount = 0
        this.closed = false
    }

    /// 写入字节数组
    public func write(data: Array<UInt8>): WriteResult {
        if (closed) {
            return WriteResult(SysError(9, SysTag.Write))
        }
        let result = inner.write(data)
        if (result.isOk()) {
            totalBytes += result.bytesWritten
            writeCount += 1
        }
        return result
    }

    /// 写入字符串
    public func writeString(s: String): WriteResult {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return write(bytes)
    }

    /// 刷新
    public func flush(): Unit {
        inner.flush()
    }

    /// 关闭
    public func close(): Unit {
        if (!closed) {
            inner.close()
            closed = true
        }
    }

    /// 获取内部写入器
    public func getInner(): Writer {
        return inner
    }

    /// 平均每次写入字节数
    public func averageWriteSize(): Float64 {
        if (writeCount == 0) {
            return 0.0
        }
        return Float64(totalBytes) / Float64(writeCount)
    }
}

// ============================================================================
// MultiWriter - 多目标写入器
// 严格翻译自: Bun 中的广播写入
//   将数据同时写入多个目标
//   用于: 日志同时写入文件和控制台
//         响应同时写入多个客户端
//         调试时同时写入网络和内存缓冲区
//   对应 Bun: WritableStream pipeTo 多个目标
// ============================================================================

/// 多目标写入器 - 将数据广播到多个 Writer
/// 写入时依次写入所有内部 Writer
/// 如果某个 Writer 失败, 记录错误但继续写入其他 Writer
public class MultiWriter <: Writer {
    /// 内部写入器列表
    private var writers: ArrayList<Writer>
    /// 错误收集
    public var errors: ArrayList<SysError>
    /// 是否已关闭
    private var closed: Bool
    /// 失败策略
    public var onFailure: OnFailure

    /// 失败处理策略
    public enum OnFailure {
        | Continue     // 继续写入其他 Writer
        | StopOnFirst  // 第一个失败后停止
        | RemoveFailed // 移除失败的 Writer 并继续
    }

    public init(writers: ArrayList<Writer>) {
        this.writers = writers
        this.errors = ArrayList<SysError>()
        this.closed = false
        this.onFailure = OnFailure.Continue
    }

    public init(writers: ArrayList<Writer>, onFailure: OnFailure) {
        this.writers = writers
        this.errors = ArrayList<SysError>()
        this.closed = false
        this.onFailure = onFailure
    }

    /// 写入字节数组
    public func write(data: Array<UInt8>): WriteResult {
        if (closed) {
            return WriteResult(SysError(9, SysTag.Write))
        }
        var minWritten: Int64 = Int64.MAX_VALUE
        var failed = ArrayList<Writer>()
        var anyError = false

        for (writer in writers) {
            let result = writer.write(data)
            match (result.err) {
                case Some(e) =>
                    errors.append(e)
                    anyError = true
                    match (onFailure) {
                        case OnFailure.StopOnFirst =>
                            return WriteResult(e)
                        case OnFailure.RemoveFailed =>
                            failed.append(writer)
                        case OnFailure.Continue => ()
                    }
                case None =>
                    if (result.bytesWritten < minWritten) {
                        minWritten = result.bytesWritten
                    }
            }
        }

        // 移除失败的 Writer
        if (onFailure == OnFailure.RemoveFailed) {
            for (w in failed) {
                writers.remove(w)
            }
        }

        if (anyError && minWritten == Int64.MAX_VALUE) {
            return WriteResult(errors[Int64(errors.size - 1)])
        }
        return WriteResult(if (minWritten == Int64.MAX_VALUE) 0 else minWritten)
    }

    /// 写入字符串
    public func writeString(s: String): WriteResult {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return write(bytes)
    }

    /// 刷新所有写入器
    public func flush(): Unit {
        for (writer in writers) {
            writer.flush()
        }
    }

    /// 关闭所有写入器
    public func close(): Unit {
        if (!closed) {
            for (writer in writers) {
                writer.close()
            }
            closed = true
        }
    }

    /// 添加写入器
    public func addWriter(writer: Writer): Unit {
        if (!closed) {
            writers.append(writer)
        }
    }

    /// 移除写入器
    public func removeWriter(writer: Writer): Unit {
        writers.remove(writer)
    }

    /// 获取写入器数量
    public func writerCount(): Int64 {
        return writers.size
    }
}

// ============================================================================
// TeeWriter - 双路写入器
// 严格翻译自: Unix tee 命令的等价实现
//   同时写入两个目标, 类似 Unix tee 命令
//   用于: 同时写入文件和标准输出
//         同时写入网络和日志
//         调试流式数据
//   对应 Bun: 响应分流 + console.log 同时输出
// ============================================================================

/// 双路写入器 - 将数据同时写入两个 Writer
/// 类似 Unix tee: 输入 -> primary (主) + secondary (次)
public class TeeWriter <: Writer {
    /// 主写入器
    private var primary: Writer
    /// 次写入器
    private var secondary: Writer
    /// 主写入器总字节
    public var primaryBytes: Int64
    /// 次写入器总字节
    public var secondaryBytes: Int64
    /// 是否已关闭
    private var closed: Bool
    /// 是否在次写入器失败时中止
    public var abortOnSecondaryError: Bool

    public init(primary: Writer, secondary: Writer) {
        this.primary = primary
        this.secondary = secondary
        this.primaryBytes = 0
        this.secondaryBytes = 0
        this.closed = false
        this.abortOnSecondaryError = false
    }

    /// 写入字节数组
    public func write(data: Array<UInt8>): WriteResult {
        if (closed) {
            return WriteResult(SysError(9, SysTag.Write))
        }

        // 写入主目标
        let primaryResult = primary.write(data)
        if (!primaryResult.isOk()) {
            return primaryResult
        }
        primaryBytes += primaryResult.bytesWritten

        // 写入次目标
        let secondaryResult = secondary.write(data)
        match (secondaryResult.err) {
            case Some(e) =>
                if (abortOnSecondaryError) {
                    return WriteResult(e)
                }
                // 不影响主写入器的结果
            case None =>
                secondaryBytes += secondaryResult.bytesWritten
        }

        return primaryResult
    }

    /// 写入字符串
    public func writeString(s: String): WriteResult {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return write(bytes)
    }

    /// 刷新两个写入器
    public func flush(): Unit {
        primary.flush()
        secondary.flush()
    }

    /// 关闭两个写入器
    public func close(): Unit {
        if (!closed) {
            primary.close()
            secondary.close()
            closed = true
        }
    }

    /// 获取主写入器
    public func getPrimary(): Writer {
        return primary
    }

    /// 获取次写入器
    public func getSecondary(): Writer {
        return secondary
    }
}

// ============================================================================
// FdWriter - 文件描述符写入器
// 最基础的 Writer 实现, 直接写入 FD
// ============================================================================

/// 文件描述符写入器 - 直接写入系统 FD
/// 最基础的 Writer 实现
public class FdWriter <: Writer {
    /// 文件描述符
    public var fd: Int64
    /// 是否已关闭
    private var closed: Bool
    /// 内部缓冲 (可选)
    private var buffered: Bool
    private var buffer: ArrayList<UInt8>

    public init(fd: Int64) {
        this.fd = fd
        this.closed = false
        this.buffered = false
        this.buffer = ArrayList<UInt8>()
    }

    public init(fd: Int64, buffered: Bool) {
        this.fd = fd
        this.closed = false
        this.buffered = buffered
        this.buffer = ArrayList<UInt8>()
    }

    /// 写入字节数组
    public func write(data: Array<UInt8>): WriteResult {
        if (closed) {
            return WriteResult(SysError(9, SysTag.Write))
        }
        if (buffered) {
            for (b in data) {
                buffer.append(b)
            }
            if (buffer.size >= MAX_BUF_SIZE) {
                flush()
            }
            return WriteResult(data.size)
        }
        match (SysFs.write(fd, data)) {
            case SysMaybe<Int64>.Err(e) => return WriteResult(e)
            case SysMaybe<Int64>.Ok(n) => return WriteResult(n)
        }
    }

    /// 写入字符串
    public func writeString(s: String): WriteResult {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return write(bytes)
    }

    /// 刷新
    public func flush(): Unit {
        if (buffer.size > 0) {
            let data = buffer.toArray()
            SysFs.write(fd, data)
            buffer.clear()
        }
    }

    /// 关闭
    public func close(): Unit {
        if (!closed) {
            flush()
            SysFs.close(fd)
            closed = true
        }
    }
}

// ============================================================================
// NullWriter - 空写入器
// 丢弃所有写入的数据 (类似 /dev/null)
// ============================================================================

/// 空写入器 - 丢弃所有数据
/// 类似 Unix /dev/null
/// 用于: 性能测试, 吞吐量测量, 条件写入的空目标
public class NullWriter <: Writer {
    /// 已丢弃的字节数
    public var discardedBytes: Int64
    /// 写入次数
    public var writeCount: Int64

    public init() {
        discardedBytes = 0
        writeCount = 0
    }

    /// 丢弃数据
    public func write(data: Array<UInt8>): WriteResult {
        discardedBytes += data.size
        writeCount += 1
        return WriteResult(data.size)
    }

    /// 丢弃字符串
    public func writeString(s: String): WriteResult {
        discardedBytes += s.size
        writeCount += 1
        return WriteResult(s.size)
    }

    /// 无操作
    public func flush(): Unit {
        // /dev/null 不需要刷新
    }

    /// 无操作
    public func close(): Unit {
        // /dev/null 不需要关闭
    }
}

// ============================================================================
// WriterBuilder - Writer 构建器
// ============================================================================

/// Writer 构建器 - 方便创建各种 Writer 组合
public class WriterBuilder {
    /// 创建计数写入器
    public static func counting(inner: Writer): CountingWriter {
        return CountingWriter(inner)
    }

    /// 创建双路写入器
    public static func tee(primary: Writer, secondary: Writer): TeeWriter {
        return TeeWriter(primary, secondary)
    }

    /// 创建多目标写入器
    public static func multi(writers: ArrayList<Writer>): MultiWriter {
        return MultiWriter(writers)
    }

    /// 创建文件描述符写入器
    public static func fromFd(fd: Int64): FdWriter {
        return FdWriter(fd)
    }

    /// 创建缓冲 FD 写入器
    public static func fromFdBuffered(fd: Int64): FdWriter {
        return FdWriter(fd, true)
    }

    /// 创建空写入器
    public static func nullWriter(): NullWriter {
        return NullWriter()
    }

    /// 创建日志写入器 (tee 到文件 + 控制台)
    public static func logWriter(filePath: String): ?TeeWriter {
        match (SysFs.openWrite(filePath)) {
            case Ok(fd) =>
                let fileWriter = FdWriter(fd, true)
                let consoleWriter = FdWriter(1)  // stdout
                return TeeWriter(consoleWriter, fileWriter)
            case Err(_) => None
        }
    }
}
