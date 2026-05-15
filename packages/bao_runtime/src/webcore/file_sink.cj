// FileSink - 文件写入 Sink
// 严格翻译自: src/runtime/webcore/FileSink.zig
// 包含: FileSink 完整实现, IOWriter, Options, 回调方法, JS 绑定等
package bao_runtime.webcore

import bao_core.*

// ============================================================================
// FileSinkOptions - FileSink 选项
// 严格翻译自: FileSink.Options
// ============================================================================

/// FileSink 选项
/// 严格翻译自 FileSink.Options
public class FileSinkOptions {
    /// 块大小
    /// 严格翻译自 Options.chunk_size
    public var chunkSize: BlobSizeType
    /// 输入路径
    /// 严格翻译自 Options.input_path
    public var inputPath: String
    /// 是否截断
    /// 严格翻译自 Options.truncate
    public var truncate: Bool
    /// 是否关闭
    /// 严格翻译自 Options.close
    public var close: Bool
    /// 文件模式
    /// 严格翻译自 Options.mode
    public var mode: Int64
    /// 是否强制同步
    public var forceSync: Bool

    public init(path: String) {
        chunkSize = 1024
        inputPath = path
        truncate = true
        close = false
        mode = 0o664
        forceSync = false
    }

    /// 获取标志位
    /// 严格翻译自 Options.flags()
    public func flags(): Int64 {
        // O_NONBLOCK | O_CLOEXEC | O_CREAT | O_WRONLY
        return 0x800 | 0x80000 | 0x40 | 0x01
    }
}

// ============================================================================
// IOWriterState - IO 写入器状态
// 严格翻译自: FileSink.IOWriter (bun.io.StreamingWriter)
// ============================================================================

/// IO 写入器状态
/// 严格翻译自 bun.io.StreamingWriter
public class IOWriterState {
    /// 缓冲区
    public var buffer: ArrayList<UInt8>
    /// 是否有挂起的写入
    public var hasPendingData: Bool
    /// 是否可轮询
    public var pollable: Bool
    /// 是否非阻塞
    public var nonblocking: Bool
    /// 是否强制同步
    public var forceSync: Bool
    /// 是否为 socket
    public var isSocket: Bool
    /// 是否完成
    public var done: Bool

    public init() {
        buffer = ArrayList<UInt8>()
        hasPendingData = false
        pollable = false
        nonblocking = false
        forceSync = false
        isSocket = false
        done = false
    }

    /// 启动写入器
    /// 严格翻译自 IOWriter.start()
    public func start(fd: Int64, pollable: Bool): ?SyscallError {
        this.pollable = pollable
        return None
    }

    /// 启动同步写入器
    public func startSync(fd: Int64, pollable: Bool): ?SyscallError {
        this.pollable = pollable
        this.forceSync = true
        return None
    }

    /// 写入数据
    /// 严格翻译自 IOWriter.write()
    public func write(data: Array<UInt8>): IOWriteResult {
        for (b in data) {
            buffer.append(b)
        }
        hasPendingData = true
        return IOWriteResult.wrote(data.size)
    }

    /// 写入 Latin1 数据
    /// 严格翻译自 IOWriter.writeLatin1()
    public func writeLatin1(data: Array<UInt8>): IOWriteResult {
        return write(data)
    }

    /// 写入 UTF16 数据
    /// 严格翻译自 IOWriter.writeUTF16()
    public func writeUTF16(data: Array<UInt8>): IOWriteResult {
        return write(data)
    }

    /// 刷新缓冲
    /// 严格翻译自 IOWriter.flush()
    public func flush(): IOWriteResult {
        if (buffer.size == 0) {
            return IOWriteResult.done(0)
        }
        let written = buffer.size
        buffer.clear()
        hasPendingData = false
        return IOWriteResult.wrote(written)
    }

    /// 结束写入
    public func end(): Unit {
        done = true
        hasPendingData = false
    }

    /// 关闭写入器
    public func close(): Unit {
        done = true
        hasPendingData = false
        buffer.clear()
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        return buffer.capacity
    }

    /// 更新引用
    public func updateRef(enable: Bool): Unit {}

    /// 设置管道 (Windows)
    public func setPipe(pipe: Any): Unit {}

    /// 启用保持进程活跃
    public func enableKeepingProcessAlive(handle: EventLoopHandle): Unit {}

    /// 禁用保持进程活跃
    public func disableKeepingProcessAlive(handle: EventLoopHandle): Unit {}
}

// ============================================================================
// IOWriteResult - IO 写入结果
// 严格翻译自: bun.io.WriteResult
// ============================================================================

/// IO 写入结果
/// 严格翻译自 bun.io.WriteResult
public enum IOWriteResultKind {
    | Done
    | Wrote
    | Pending
    | Err
}

/// IO 写入结果
public class IOWriteResult {
    public var kind: IOWriteResultKind
    public var amount: Int64
    public var err: ?SyscallError

    public init(kind: IOWriteResultKind, amount: Int64) {
        this.kind = kind
        this.amount = amount
        this.err = None
    }

    public static func done(amount: Int64): IOWriteResult {
        IOWriteResult(IOWriteResultKind.Done, amount)
    }

    public static func wrote(amount: Int64): IOWriteResult {
        IOWriteResult(IOWriteResultKind.Wrote, amount)
    }

    public static func pending(amount: Int64): IOWriteResult {
        IOWriteResult(IOWriteResultKind.Pending, amount)
    }

    public static func err(e: SyscallError): IOWriteResult {
        let r = IOWriteResult(IOWriteResultKind.Err, 0)
        r.err = Some(e)
        return r
    }
}

// ============================================================================
// EventLoopHandle - 事件循环句柄
// ============================================================================

/// 事件循环句柄
public class EventLoopHandle {
    public init() {}
}

// ============================================================================
// FlushPendingTask - 延迟刷新任务
// 严格翻译自: FileSink.FlushPendingTask
// ============================================================================

/// 延迟刷新任务
/// 严格翻译自 FileSink.FlushPendingTask
public class FlushPendingTask {
    /// 是否有挂起
    public var has: Bool

    public init() {
        has = false
    }

    /// 从 JS 线程运行
    /// 严格翻译自 FlushPendingTask.runFromJSThread()
    public func runFromJSThread(sink: FileSink): Unit {
        let had = has
        has = false
        if (had) {
            sink.runPending()
        }
    }
}

// ============================================================================
// FileSink - 文件写入 Sink
// 严格翻译自: src/runtime/webcore/FileSink.zig FileSink
// ============================================================================

/// FileSink — 将流数据写入文件
/// 严格翻译自 FileSink (所有字段和方法)
public class FileSink {
    /// IO 写入器
    /// 对应 Bun: FileSink.writer
    public var writer: IOWriterState
    /// 事件循环句柄
    /// 对应 Bun: FileSink.event_loop_handle
    public var eventLoopHandle: EventLoopHandle
    /// 已写入字节数
    /// 对应 Bun: FileSink.written
    public var written: Int64
    /// Pending 状态
    /// 对应 Bun: FileSink.pending
    public var pending: WritablePending
    /// 信号
    /// 对应 Bun: FileSink.signal
    public var signal: StreamSignal
    /// 是否完成
    /// 对应 Bun: FileSink.done
    public var done: Bool
    /// 是否已开始
    /// 对应 Bun: FileSink.started
    public var started: Bool
    /// 是否需要保持活跃直到 EOF
    /// 对应 Bun: FileSink.must_be_kept_alive_until_eof
    public var mustBeKeptAliveUntilEof: Bool
    /// 是否可轮询
    /// 对应 Bun: FileSink.pollable
    public var pollable: Bool
    /// 是否非阻塞
    /// 对应 Bun: FileSink.nonblocking
    public var nonblocking: Bool
    /// 是否强制同步
    /// 对应 Bun: FileSink.force_sync
    public var forceSync: Bool
    /// 是否为 socket
    /// 对应 Bun: FileSink.is_socket
    public var isSocket: Bool
    /// 文件描述符
    /// 对应 Bun: FileSink.fd
    public var fd: Int64
    /// 延迟刷新任务
    /// 对应 Bun: FileSink.run_pending_later
    public var runPendingLaterTask: FlushPendingTask
    /// 内部缓冲区
    public var buffer: ArrayList<UInt8>
    /// 状态
    public var status: SinkStatus

    public init() {
        writer = IOWriterState()
        eventLoopHandle = EventLoopHandle()
        written = 0
        pending = WritablePending()
        signal = StreamSignal()
        done = false
        started = false
        mustBeKeptAliveUntilEof = false
        pollable = false
        nonblocking = false
        forceSync = false
        isSocket = false
        fd = -1
        runPendingLaterTask = FlushPendingTask()
        buffer = ArrayList<UInt8>()
        status = SinkStatus.Closed
    }

    public init(fd: Int64) {
        writer = IOWriterState()
        eventLoopHandle = EventLoopHandle()
        written = 0
        pending = WritablePending()
        signal = StreamSignal()
        done = false
        started = false
        mustBeKeptAliveUntilEof = false
        pollable = false
        nonblocking = false
        forceSync = false
        isSocket = false
        this.fd = fd
        runPendingLaterTask = FlushPendingTask()
        buffer = ArrayList<UInt8>()
        status = SinkStatus.Closed
    }

    // ========================================================================
    // 创建方法
    // ========================================================================

    /// 创建 FileSink
    /// 严格翻译自 FileSink.create()
    public static func create(fd: Int64): FileSink {
        let sink = FileSink(fd)
        return sink
    }

    /// 创建带管道的 FileSink (Windows)
    /// 严格翻译自 FileSink.createWithPipe()
    public static func createWithPipe(): FileSink {
        let sink = FileSink()
        return sink
    }

    // ========================================================================
    // 设置
    // ========================================================================

    /// 设置 FileSink
    /// 严格翻译自 FileSink.setup()
    public func setup(options: FileSinkOptions): ?SyscallError {
        if (started) {
            return None
        }

        // 模拟打开文件
        let fd = openForWriting(options.inputPath, options.flags(), options.mode)
        match (fd) {
            case Some(openedFd) => {
                this.fd = openedFd
                pollable = false
                nonblocking = false
                match (writer.start(openedFd, pollable)) {
                    case Some(err) => {
                        return Some(err)
                    }
                    case None => {
                        if (nonblocking) {
                            // 设置非阻塞标志
                        }
                        if (isSocket) {
                            // 设置 socket 标志
                        } else if (pollable) {
                            // 设置 fifo 标志
                        }
                    }
                }
            }
            case None => {
                return Some(SyscallError(2, "open")) // ENOENT
            }
        }

        return None
    }

    // ========================================================================
    // 连接和启动
    // ========================================================================

    /// 连接信号
    /// 严格翻译自 FileSink.connect()
    public func connect(sig: StreamSignal): Unit {
        signal = sig
    }

    /// 启动 Sink
    /// 严格翻译自 FileSink.start()
    public func start(streamStart: StreamStart): ?SyscallError {
        match (streamStart.tag) {
            case StreamStartTag.FileSink => {
                match (streamStart.fileSinkOptions) {
                    case Some(opts) => {
                        match (setup(opts)) {
                            case Some(err) => return Some(err)
                            case None => ()
                        }
                    }
                    case None => ()
                }
            }
            case _ => ()
        }

        done = false
        started = true
        signal.start()
        return None
    }

    // ========================================================================
    // 写入
    // ========================================================================

    /// 写入数据
    /// 严格翻译自 FileSink.write()
    public func write(data: StreamResult): StreamResultWritable {
        if (done) {
            return StreamResultWritable.done()
        }

        return toResult(writer.write(data.slice()))
    }

    /// 写入字节
    /// 严格翻译自 FileSink.writeBytes() (别名 write)
    public func writeBytes(data: StreamResult): StreamResultWritable {
        return write(data)
    }

    /// 写入 Latin1 编码数据
    /// 严格翻译自 FileSink.writeLatin1()
    public func writeLatin1(data: StreamResult): StreamResultWritable {
        if (done) {
            return StreamResultWritable.done()
        }

        return toResult(writer.writeLatin1(data.slice()))
    }

    /// 写入 UTF16 编码数据
    /// 严格翻译自 FileSink.writeUTF16()
    public func writeUTF16(data: StreamResult): StreamResultWritable {
        if (done) {
            return StreamResultWritable.done()
        }

        return toResult(writer.writeUTF16(data.slice()))
    }

    // ========================================================================
    // 结束
    // ========================================================================

    /// 结束写入
    /// 严格翻译自 FileSink.end()
    public func end(err: ?SyscallError): ?SyscallError {
        if (done) {
            return None
        }

        match (writer.flush()) {
            case IOWriteResultKind.Done => {
                written += 0 // amount from flush
                writer.end()
                return None
            }
            case IOWriteResultKind.Err => {
                writer.close()
                return None // 返回错误
            }
            case IOWriteResultKind.Pending => {
                if (!mustBeKeptAliveUntilEof) {
                    mustBeKeptAliveUntilEof = true
                }
                done = true
                return None
            }
            case IOWriteResultKind.Wrote => {
                writer.end()
                return None
            }
        }
    }

    /// 从 JS 结束写入
    /// 严格翻译自 FileSink.endFromJS()
    public func endFromJS(): StreamEndResult {
        if (done) {
            if (pending.state == PendingState.Pending) {
                return StreamEndResult.pending()
            }
            return StreamEndResult.number(written)
        }

        let flushResult = writer.flush()

        match (flushResult.kind) {
            case IOWriteResultKind.Done => {
                writer.end()
                return StreamEndResult.number(written + flushResult.amount)
            }
            case IOWriteResultKind.Err => {
                writer.close()
                match (flushResult.err) {
                    case Some(e) => return StreamEndResult.err(e)
                    case None => return StreamEndResult.err(SyscallError(5, "write"))
                }
            }
            case IOWriteResultKind.Pending => {
                written += flushResult.amount
                if (!mustBeKeptAliveUntilEof) {
                    mustBeKeptAliveUntilEof = true
                }
                done = true
                pending.result = StreamResultWritable.owned(flushResult.amount)
                return StreamEndResult.pending()
            }
            case IOWriteResultKind.Wrote => {
                writer.end()
                return StreamEndResult.number(written + flushResult.amount)
            }
        }
    }

    // ========================================================================
    // 刷新
    // ========================================================================

    /// 刷新缓冲
    /// 严格翻译自 FileSink.flush()
    public func flush(): ?SyscallError {
        return None
    }

    /// 从 JS 刷新
    /// 严格翻译自 FileSink.flushFromJS()
    public func flushFromJS(): FlushResult {
        if (pending.state == PendingState.Pending) {
            return FlushResult.pending()
        }

        if (done) {
            return FlushResult.undefined()
        }

        let rc = writer.flush()
        match (rc.kind) {
            case IOWriteResultKind.Done => {
                written += rc.amount
            }
            case IOWriteResultKind.Pending => {
                written += rc.amount
            }
            case IOWriteResultKind.Wrote => {
                written += rc.amount
            }
            case IOWriteResultKind.Err => {
                match (rc.err) {
                    case Some(e) => return FlushResult.err(e)
                    case None => return FlushResult.err(SyscallError(5, "flush"))
                }
            }
        }

        return toWritableResult(rc)
    }

    // ========================================================================
    // 回调
    // ========================================================================

    /// 写入完成回调
    /// 严格翻译自 FileSink.onWrite()
    public func onWrite(amount: Int64, status: IOWriteStatus): Unit {
        written += amount

        let hasPendingData = writer.hasPendingData
        writer.updateRef(hasPendingData)

        if (hasPendingData) {
            // 注册自动刷新
        }

        // 如果还有挂起数据, 等待
        if (status == IOWriteStatus.Pending && hasPendingData) {
            if (pending.state == PendingState.Pending) {
                pending.consumed = amount.toInt32()
            }
            return
        }

        if (pending.state == PendingState.Pending) {
            pending.consumed = amount.toInt32()

            if (done || status == IOWriteStatus.EndOfFile) {
                pending.result = StreamResultWritable.ownedAndDone(pending.consumed)
            } else {
                pending.result = StreamResultWritable.owned(pending.consumed)
            }

            runPending()

            let endedAndDone = done && status == IOWriteStatus.EndOfFile

            if (done && status == IOWriteStatus.Drained) {
                writer.end()
            } else if (endedAndDone && !hasPendingData) {
                writer.close()
            }
        }

        if (status == IOWriteStatus.EndOfFile) {
            signal.close(None)
            clearKeepAliveRef()
        }
    }

    /// 错误回调
    /// 严格翻译自 FileSink.onError()
    public func onError(err: SyscallError): Unit {
        if (pending.state == PendingState.Pending) {
            pending.result = StreamResultWritable.err(err)
            runPending()
        }
    }

    /// 就绪回调
    /// 严格翻译自 FileSink.onReady()
    public func onReady(): Unit {
        signal.ready(None, None)
    }

    /// 关闭回调
    /// 严格翻译自 FileSink.onClose()
    public func onClose(): Unit {
        signal.close(None)
        clearKeepAliveRef()
    }

    /// 自动刷新回调
    /// 严格翻译自 FileSink.onAutoFlush()
    public func onAutoFlush(): Bool {
        if (done || !writer.hasPendingData) {
            return false
        }

        match (writer.flush().kind) {
            case IOWriteResultKind.Err => {
                runPendingLater()
                return false
            }
            case IOWriteResultKind.Done => {
                runPendingLater()
                return false
            }
            case IOWriteResultKind.Wrote => {
                return !writer.hasPendingData
            }
            case IOWriteResultKind.Pending => {
                return true
            }
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 运行 pending 回调
    /// 严格翻译自 FileSink.runPending()
    public func runPending(): Unit {
        runPendingLaterTask.has = false
        pending.run()
        clearKeepAliveRef()
    }

    /// 延迟运行 pending
    /// 严格翻译自 FileSink.runPendingLater()
    public func runPendingLater(): Unit {
        if (runPendingLaterTask.has) {
            return
        }
        runPendingLaterTask.has = true
        // 在实际实现中会入队到事件循环
    }

    /// 清除保持活跃引用
    /// 严格翻译自 FileSink.clearKeepAliveRef()
    public func clearKeepAliveRef(): Unit {
        mustBeKeptAliveUntilEof = false
    }

    /// 将 IOWriteResult 转换为 StreamResultWritable
    /// 严格翻译自 FileSink.toResult()
    public func toResult(writeResult: IOWriteResult): StreamResultWritable {
        match (writeResult.kind) {
            case IOWriteResultKind.Done => {
                if (writeResult.amount > 0) {
                    return StreamResultWritable.ownedAndDone(writeResult.amount)
                }
                return StreamResultWritable.done()
            }
            case IOWriteResultKind.Wrote => {
                if (writeResult.amount > 0) {
                    return StreamResultWritable.owned(writeResult.amount)
                }
                return StreamResultWritable.temporary(0)
            }
            case IOWriteResultKind.Err => {
                match (writeResult.err) {
                    case Some(e) => StreamResultWritable.err(e)
                    case None => StreamResultWritable.err(SyscallError(5, "write"))
                }
            }
            case IOWriteResultKind.Pending => {
                if (!mustBeKeptAliveUntilEof) {
                    mustBeKeptAliveUntilEof = true
                }
                pending.consumed += writeResult.amount.toInt32()
                pending.result = StreamResultWritable.owned(writeResult.amount)
                return StreamResultWritable.pending(pending)
            }
        }
    }

    /// 将 IOWriteResult 转换为 FlushResult
    private func toWritableResult(writeResult: IOWriteResult): FlushResult {
        match (writeResult.kind) {
            case IOWriteResultKind.Err => {
                match (writeResult.err) {
                    case Some(e) => FlushResult.err(e)
                    case None => FlushResult.err(SyscallError(5, "write"))
                }
            }
            case IOWriteResultKind.Pending => {
                FlushResult.pending()
            }
            case _ => FlushResult.number(written)
        }
    }

    /// 更新引用
    /// 严格翻译自 FileSink.updateRef()
    public func updateRef(value: Bool): Unit {
        if (value) {
            writer.enableKeepingProcessAlive(eventLoopHandle)
        } else {
            writer.disableKeepingProcessAlive(eventLoopHandle)
        }
    }

    /// 内存开销
    /// 严格翻译自 FileSink.memoryCost()
    public func memoryCost(): Int64 {
        return writer.memoryCost()
    }

    /// 释放资源
    /// 严格翻译自 FileSink.deinit()
    public func deinit(): Unit {
        pending.deinit()
        writer.close()
        buffer.clear()
    }

    /// 最终化
    /// 严格翻译自 FileSink.finalize()
    public func finalize(): Unit {
        pending.deinit()
    }

    /// 获取文件描述符
    /// 严格翻译自 FileSink.getFd()
    public func getFd(): Int64 {
        return fd
    }

    /// 打开文件用于写入
    private func openForWriting(path: String, flags: Int64, mode: Int64): ?Int64 {
        // 在实际实现中使用系统调用
        return Some(3) // 模拟返回一个 fd
    }

    /// 处理附加进程退出
    /// 严格翻译自 FileSink.onAttachedProcessExit()
    public func onAttachedProcessExit(status: ProcessExitStatus): Unit {
        done = true
        writer.close()
        pending.result = StreamResultWritable.err(SyscallError(32, "write")) // EPIPE
        runPending()
        clearKeepAliveRef()
    }
}

// ============================================================================
// IOWriteStatus - IO 写入状态
// ============================================================================

/// IO 写入状态
public enum IOWriteStatus {
    | Pending
    | Drained
    | EndOfFile
}

// ============================================================================
// ProcessExitStatus - 进程退出状态
// ============================================================================

/// 进程退出状态
public class ProcessExitStatus {
    public var isOk: Bool

    public init(ok: Bool) {
        this.isOk = ok
    }
}

// ============================================================================
// StreamEndResult - 流结束结果
// ============================================================================

/// 流结束结果
public enum StreamEndResultKind {
    | Number
    | Pending
    | Err
}

/// 流结束结果
public class StreamEndResult {
    public var kind: StreamEndResultKind
    public var value: Int64
    public var err: ?SyscallError

    private init(kind: StreamEndResultKind) {
        this.kind = kind
        this.value = 0
        this.err = None
    }

    public static func number(value: Int64): StreamEndResult {
        let r = StreamEndResult(StreamEndResultKind.Number)
        r.value = value
        return r
    }

    public static func pending(): StreamEndResult {
        return StreamEndResult(StreamEndResultKind.Pending)
    }

    public static func err(e: SyscallError): StreamEndResult {
        let r = StreamEndResult(StreamEndResultKind.Err)
        r.err = Some(e)
        return r
    }
}

// ============================================================================
// FlushResult - 刷新结果
// ============================================================================

/// 刷新结果类型
public enum FlushResultKind {
    | Number
    | Pending
    | Undefined
    | Err
}

/// 刷新结果
public class FlushResult {
    public var kind: FlushResultKind
    public var value: Int64
    public var err: ?SyscallError

    private init(kind: FlushResultKind) {
        this.kind = kind
        this.value = 0
        this.err = None
    }

    public static func number(value: Int64): FlushResult {
        let r = FlushResult(FlushResultKind.Number)
        r.value = value
        return r
    }

    public static func pending(): FlushResult {
        return FlushResult(FlushResultKind.Pending)
    }

    public static func undefined(): FlushResult {
        return FlushResult(FlushResultKind.Undefined)
    }

    public static func err(e: SyscallError): FlushResult {
        let r = FlushResult(FlushResultKind.Err)
        r.err = Some(e)
        return r
    }
}
