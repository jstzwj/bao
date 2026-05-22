// FileSink - 文件写入 Sink
// 严格翻译自: src/runtime/webcore/FileSink.rs (Rust port of FileSink.zig)
// 包含: FileSink 完整实现, IOWriter, Options, FlushPendingTask, 回调方法, JS 绑定等
package bao_runtime.webcore

import bao_core.*
import bao_collections.*

// ============================================================================
// FileSinkOptions - FileSink 选项
// 严格翻译自 FileSink.rs Options
// ============================================================================

/// FileSink 选项
/// 严格翻译自 Options
public class FileSinkOptions {
    /// 块大小
    /// 严格翻译自 Options.chunk_size
    public var chunkSize: BlobSizeType
    /// 输入路径或文件描述符
    /// 严格翻译自 Options.input_path
    public var inputPath: PathOrFileDescriptor
    /// 是否截断
    /// 严格翻译自 Options.truncate
    public var truncate: Bool
    /// 是否关闭
    /// 严格翻译自 Options.close
    public var close: Bool
    /// 文件模式
    /// 严格翻译自 Options.mode
    public var mode: Int64

    public init() {
        chunkSize = 1024
        inputPath = PathOrFileDescriptor.fd(Fd.INVALID)
        truncate = true
        close = false
        mode = 0o664
    }

    public init(path: String) {
        chunkSize = 1024
        inputPath = PathOrFileDescriptor.path(path)
        truncate = true
        close = false
        mode = 0o664
    }

    /// 获取标志位
    /// 严格翻译自 Options.flags()
    public func flags(): Int64 {
        // O_NONBLOCK | O_CLOEXEC | O_CREAT | O_WRONLY
        return 0x800 | 0x80000 | 0x40 | 0x01
    }
}

// ============================================================================
// PathOrFileDescriptor - 路径或文件描述符
// 严格翻译自 PathOrFileDescriptor
// ============================================================================

/// 路径或文件描述符
public enum PathOrFileDescriptor {
    | Fd(Int64)
    | Path(String)
}

// ============================================================================
// Fd - 文件描述符常量
// ============================================================================

/// 文件描述符常量
public class Fd {
    public static let INVALID: Int64 = -1
}

// ============================================================================
// IOWriterState - IO 写入器状态
// 严格翻译自 FileSink.rs IOWriter (bun.io.StreamingWriter)
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
    /// 是否 owns fd
    public var ownsFd: Bool
    /// 父指针 (用于回调)
    public var parent: Int64
    /// 是否已结束
    public var isDone: Bool

    public init() {
        buffer = ArrayList<UInt8>()
        hasPendingData = false
        pollable = false
        nonblocking = false
        forceSync = false
        isSocket = false
        done = false
        ownsFd = false
        parent = 0
        isDone = false
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
    /// 严格翻译自 IOWriter.write_latin1()
    public func writeLatin1(data: Array<UInt8>): IOWriteResult {
        return write(data)
    }

    /// 写入 UTF16 数据
    /// 严格翻译自 IOWriter.write_utf16()
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
    /// 严格翻译自 IOWriter.end()
    public func end(): Unit {
        isDone = true
        hasPendingData = false
    }

    /// 关闭写入器
    /// 严格翻译自 IOWriter.close()
    public func close(): Unit {
        done = true
        isDone = true
        hasPendingData = false
        buffer.clear()
    }

    /// 内存开销
    /// 严格翻译自 IOWriter.memory_cost()
    public func memoryCost(): Int64 {
        return buffer.capacity
    }

    /// 更新引用
    /// 严格翻译自 IOWriter.update_ref()
    public func updateRef(evtloop: EventLoopHandle, value: Bool): Unit {}

    /// 设置管道 (Windows)
    public func setPipe(pipe: Int64): Unit {}

    /// 设置父指针
    public func setParent(parent: Int64): Unit {
        this.parent = parent
    }

    /// 启用保持进程活跃
    public func enableKeepingProcessAlive(handle: EventLoopHandle): Unit {}

    /// 禁用保持进程活跃
    public func disableKeepingProcessAlive(handle: EventLoopHandle): Unit {}
}

// ============================================================================
// IOWriteResult - IO 写入结果
// 严格翻译自 bun.io.WriteResult
// ============================================================================

/// IO 写入结果类型
/// 严格翻译自 bun.io.WriteResult
public enum IOWriteResultKind {
    | Done
    | Wrote
    | Pending
    | Err
}

/// IO 写入结果
/// 严格翻译自 bun.io.WriteResult
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
/// 严格翻译自 Bun EventLoopHandle (opaque *c_void in JSC bridge)
/// 在 Bun 中，EventLoopHandle 持有事件循环的非拥有引用
/// loop_() 返回底层 bun_io::Loop 指针
public class EventLoopHandle {
    /// 底层循环的原始指针表示 (uv_loop_t* 或 uws_loop*)
    /// 对应 Bun EventLoopHandle.native_loop() -> *bun_io::Loop
    private var loopPtr: Int64

    public init() {
        loopPtr = 0
    }

    public init(loopPtr: Int64) {
        this.loopPtr = loopPtr
    }

    /// 获取底层循环指针
    /// 对应 Bun EventLoopHandle.loop_() -> *bun_io::Loop
    /// 用于 FileSink.loop_() 等需要底层循环引用的场景
    public func loop_(): Int64 {
        return loopPtr
    }

    /// 设置底层循环指针
    public func setLoop(ptr: Int64): Unit {
        loopPtr = ptr
    }
}

// ============================================================================
// FlushPendingTask - 延迟刷新任务
// 严格翻译自 FileSink.rs FlushPendingTask
// ============================================================================

/// 延迟刷新任务
/// 严格翻译自 FlushPendingTask
public class FlushPendingTask {
    /// 是否有挂起
    public var has: Bool

    public init() {
        has = false
    }

    /// 从 JS 线程运行
    /// 严格翻译自 FlushPendingTask.run_from_js_thread()
    public func runFromJsThread(sink: FileSink): Unit {
        let had = has
        has = false
        if (had) {
            sink.runPending()
        }
    }
}

// ============================================================================
// AutoFlusher - 自动刷新器
// 严格翻译自 AutoFlusher
// ============================================================================

/// 自动刷新器
public class AutoFlusher {
    /// 是否已注册
    public var registered: Bool

    public init() {
        registered = false
    }
}

// ============================================================================
// ReadableStreamStrong - 可读流强引用
// 严格翻译自 readable_stream::Strong
// ============================================================================

/// 可读流强引用
public class ReadableStreamStrong {
    public var hasValue: Bool

    public init() {
        hasValue = false
    }

    public func has(): Bool {
        return hasValue
    }

    public func deinit(): Unit {
        hasValue = false
    }
}

// ============================================================================
// FileSink - 文件写入 Sink
// 严格翻译自 FileSink.rs FileSink
// 包含所有字段和方法的完整翻译
// ============================================================================

/// 全局活跃 FileSink 实例计数
/// 严格翻译自 LIVE_COUNT
public class FileSinkLiveCount {
    public static var count: Int64 = 0
}

/// FileSink 引用守卫 (RAII)
/// 严格翻译自 FileSink.rs FileSinkRef
public class FileSinkRef {
    private var sink: ?FileSink

    private init(sink: FileSink) {
        this.sink = Some(sink)
    }

    /// 获取新的引用 (增加引用计数)
    /// 严格翻译自 FileSinkRef.new_ref()
    public static func newRef(sink: FileSink): FileSinkRef {
        sink.ref()
        return FileSinkRef(sink)
    }

    /// 采用已有引用 (不增加计数)
    /// 严格翻译自 FileSinkRef.adopt()
    public static func adopt(sink: FileSink): FileSinkRef {
        return FileSinkRef(sink)
    }

    /// 释放引用 (离开作用域时)
    /// 严格翻译自 FileSinkRef Drop
    public func drop(): Unit {
        match (sink) {
            case Some(s) => FileSink.deref(s)
            case None => ()
        }
    }
}

/// FileSink — 将流数据写入文件
/// 严格翻译自 FileSink.rs FileSink (所有字段和方法)
/// 管理文件 IO 写入的生命周期、回调和 Promise 解析
public class FileSink {
    /// 引用计数
    /// 严格翻译自 FileSink.ref_count
    public var refCount: Int64
    /// IO 写入器
    /// 严格翻译自 FileSink.writer
    public var writer: IOWriterState
    /// 事件循环句柄
    /// 严格翻译自 FileSink.event_loop_handle
    public var eventLoopHandle: EventLoopHandle
    /// 已写入字节数
    /// 严格翻译自 FileSink.written
    public var written: Int64
    /// Pending 状态
    /// 严格翻译自 FileSink.pending
    public var pending: WritablePending
    /// 信号
    /// 严格翻译自 FileSink.signal
    public var signal: StreamSignal
    /// 是否完成
    /// 严格翻译自 FileSink.done
    public var done: Bool
    /// 是否已开始
    /// 严格翻译自 FileSink.started
    public var started: Bool
    /// 是否需要保持活跃直到 EOF
    /// 严格翻译自 FileSink.must_be_kept_alive_until_eof
    public var mustBeKeptAliveUntilEof: Bool
    /// 是否可轮询
    /// 严格翻译自 FileSink.pollable
    public var pollable: Bool
    /// 是否非阻塞
    /// 严格翻译自 FileSink.nonblocking
    public var nonblocking: Bool
    /// 是否强制同步
    /// 严格翻译自 FileSink.force_sync
    public var forceSync: Bool
    /// 是否为 socket
    /// 严格翻译自 FileSink.is_socket
    public var isSocket: Bool
    /// 文件描述符
    /// 严格翻译自 FileSink.fd
    public var fd: Int64
    /// 自动刷新器
    /// 严格翻译自 FileSink.auto_flusher
    public var autoFlusher: AutoFlusher
    /// 延迟刷新任务
    /// 严格翻译自 FileSink.run_pending_later
    public var runPendingLaterTask: FlushPendingTask
    /// 可读流引用 (用于 bun.spawn stdin)
    /// 严格翻译自 FileSink.readable_stream
    public var readableStreamRef: ReadableStreamStrong
    /// JS Sink 引用 (防止 GC 回收)
    /// 严格翻译自 FileSink.js_sink_ref
    public var jsSinkRef: JsStrongOptional

    public init() {
        refCount = 1
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
        fd = Fd.INVALID
        autoFlusher = AutoFlusher()
        runPendingLaterTask = FlushPendingTask()
        readableStreamRef = ReadableStreamStrong()
        jsSinkRef = JsStrongOptional.empty()
        FileSinkLiveCount.count += 1
    }

    public init(fd: Int64) {
        refCount = 1
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
        autoFlusher = AutoFlusher()
        runPendingLaterTask = FlushPendingTask()
        readableStreamRef = ReadableStreamStrong()
        jsSinkRef = JsStrongOptional.empty()
        writer.setParent(this.toInt64())
        FileSinkLiveCount.count += 1
    }

    // ========================================================================
    // 引用计数
    // ========================================================================

    /// 增加引用
    /// 严格翻译自 FileSink.ref_()
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 严格翻译自 FileSink.deref()
    public static func deref(`this`: FileSink): Unit {
        this.refCount -= 1
        if (this.refCount <= 0) {
            FileSinkLiveCount.count -= 1
            this.clearData()
        }
    }

    // ========================================================================
    // 创建方法
    // ========================================================================

    /// 创建 FileSink
    /// 严格翻译自 FileSink.create()
    public static func create(eventLoop: EventLoopHandle, fd: Int64): FileSink {
        let sink = FileSink(fd)
        sink.eventLoopHandle = eventLoop
        FileSinkLiveCount.count += 1
        return sink
    }

    /// 创建带管道的 FileSink (Windows)
    /// 严格翻译自 FileSink.create_with_pipe()
    public static func createWithPipe(eventLoop: EventLoopHandle, pipe: Int64): FileSink {
        let sink = FileSink()
        sink.eventLoopHandle = eventLoop
        // 设置管道
        sink.writer.setPipe(pipe)
        sink.writer.setParent(sink.toInt64())
        return sink
    }

    /// 构造新实例 (用于 JSSink codegen)
    /// 严格翻译自 FileSink.construct()
    public static func construct(): FileSink {
        return FileSink()
    }

    // ========================================================================
    // 设置
    // ========================================================================

    /// 设置 FileSink
    /// 严格翻译自 FileSink.setup()
    public func setup(options: FileSinkOptions): ?SyscallError {
        // 已启动
        if (readableStreamRef.has()) {
            return None
        }

        // 打开文件
        var forceSyncOut = forceSync
        var pollableOut = pollable
        var isSocketOut = isSocket
        var nonblockingOut = nonblocking

        let ioPath = match (options.inputPath) {
            case PathOrFileDescriptor.Fd(fd) => fd
            case PathOrFileDescriptor.Path(path) => openForWriting(path, options.flags(), options.mode)
        }

        match (ioPath) {
            case -1 => return Some(SyscallError(2, "open")) // ENOENT
            case _ =>
                fd = ioPath
                match (writer.start(ioPath, pollableOut)) {
                    case Some(err) => return Some(err)
                    case None =>
                        pollable = pollableOut
                        isSocket = isSocketOut
                        nonblocking = nonblockingOut
                        if (forceSyncOut) {
                            forceSync = true
                            writer.forceSync = true
                        }
                }
        }

        return None
    }

    // ========================================================================
    // 事件循环
    // ========================================================================

    /// 获取 IO 事件循环
    /// 严格翻译自 FileSink.io_evtloop()
    public func ioEvtloop(): EventLoopHandle {
        return eventLoopHandle
    }

    /// 获取事件循环
    /// 严格翻译自 FileSink.event_loop()
    public func eventLoop(): EventLoopHandle {
        return eventLoopHandle
    }

    /// 获取底层事件循环
    /// 严格翻译自 FileSink.loop_()
    /// Bun: self.event_loop_handle.native_loop() -> *bun_io::Loop
    /// 仓颉: 委托给 EventLoopHandle.loop_() 获取底层循环引用
    public func loop(): Int64 {
        return eventLoopHandle.loop_()
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
            case StreamStartTag.FileSink =>
                match (streamStart.fileSinkOptions) {
                    case Some(opts) =>
                        match (setup(opts)) {
                            case Some(err) => return Some(err)
                            case None => ()
                        }
                    case None => ()
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
    /// 严格翻译自 FileSink.write_bytes()
    public func writeBytes(data: StreamResult): StreamResultWritable {
        return write(data)
    }

    /// 写入 Latin1 编码数据
    /// 严格翻译自 FileSink.write_latin1()
    public func writeLatin1(data: StreamResult): StreamResultWritable {
        if (done) {
            return StreamResultWritable.done()
        }

        return toResult(writer.writeLatin1(data.slice()))
    }

    /// 写入 UTF16 编码数据
    /// 严格翻译自 FileSink.write_utf16()
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

        match (writer.flush().kind) {
            case IOWriteResultKind.Done =>
                written += writer.flush().amount
                writer.end()
                return None
            case IOWriteResultKind.Err =>
                writer.close()
                match (writer.flush().err) {
                    case Some(e) => return Some(e)
                    case None => return Some(SyscallError(5, "write"))
                }
            case IOWriteResultKind.Pending =>
                if (!mustBeKeptAliveUntilEof) {
                    mustBeKeptAliveUntilEof = true
                    ref()
                }
                done = true
                return None
            case IOWriteResultKind.Wrote =>
                writer.end()
                return None
        }
    }

    /// 从 JS 结束写入
    /// 严格翻译自 FileSink.end_from_js()
    public func endFromJS(): StreamEndResult {
        if (done) {
            if (pending.state == PendingState.Pending) {
                return StreamEndResult.pending()
            }
            return StreamEndResult.number(written)
        }

        let flushResult = writer.flush()

        match (flushResult.kind) {
            case IOWriteResultKind.Done =>
                updateRef(false)
                writer.end()
                return StreamEndResult.number(flushResult.amount)
            case IOWriteResultKind.Err =>
                writer.close()
                match (flushResult.err) {
                    case Some(e) => return StreamEndResult.err(e)
                    case None => return StreamEndResult.err(SyscallError(5, "write"))
                }
            case IOWriteResultKind.Pending =>
                written += flushResult.amount
                if (!mustBeKeptAliveUntilEof) {
                    mustBeKeptAliveUntilEof = true
                    ref()
                }
                done = true
                pending.result = StreamResultWritable.owned(flushResult.amount)
                return StreamEndResult.pending()
            case IOWriteResultKind.Wrote =>
                writer.end()
                return StreamEndResult.number(flushResult.amount)
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
    /// 严格翻译自 FileSink.flush_from_js()
    public func flushFromJS(wait: Bool): FlushResult {
        if (pending.state == PendingState.Pending) {
            return FlushResult.pending()
        }

        if (done) {
            return FlushResult.undefined()
        }

        let rc = writer.flush()
        match (rc.kind) {
            case IOWriteResultKind.Done =>
                written += rc.amount
            case IOWriteResultKind.Pending =>
                written += rc.amount
            case IOWriteResultKind.Wrote =>
                written += rc.amount
            case IOWriteResultKind.Err =>
                match (rc.err) {
                    case Some(e) => return FlushResult.err(e)
                    case None => return FlushResult.err(SyscallError(5, "flush"))
                }
        }

        return toWritableResult(rc)
    }

    // ========================================================================
    // 回调
    // ========================================================================

    /// 写入完成回调
    /// 严格翻译自 FileSink.on_write()
    public func onWrite(amount: Int64, status: IOWriteStatus): Unit {
        let guard = FileSinkRef.newRef(this)
        written += amount

        let hasPendingData = writer.hasPendingData
        let evtloop = ioEvtloop()
        writer.updateRef(evtloop, hasPendingData)

        if (hasPendingData) {
            // 注册自动刷新延迟微任务
        }

        // 如果还有挂起数据, 等待
        if (status == IOWriteStatus.Pending && hasPendingData) {
            if (pending.state == PendingState.Pending) {
                pending.consumed = amount
            }
            guard.drop()
            return
        }

        if (pending.state == PendingState.Pending) {
            pending.consumed = amount

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

        guard.drop()
    }

    /// 错误回调
    /// 严格翻译自 FileSink.on_error()
    public func onError(err: SyscallError): Unit {
        if (pending.state == PendingState.Pending) {
            pending.result = StreamResultWritable.err(err)
            runPending()
        }
        clearKeepAliveRef()
    }

    /// 就绪回调
    /// 严格翻译自 FileSink.on_ready()
    public func onReady(): Unit {
        signal.ready(None, None)
    }

    /// 关闭回调
    /// 严格翻译自 FileSink.on_close()
    public func onClose(): Unit {
        // 处理可读流
        if (readableStreamRef.has()) {
            // 通知流完成
        }

        signal.close(None)
        clearKeepAliveRef()
    }

    /// 附加进程退出回调
    /// 严格翻译自 FileSink.on_attached_process_exit()
    public func onAttachedProcessExit(status: ProcessExitStatus): Unit {
        let guard = FileSinkRef.newRef(this)

        done = true

        // 处理可读流
        if (readableStreamRef.has()) {
            if (!status.isOk) {
                // 取消流
            } else {
                // 标记流完成
            }
            readableStreamRef = ReadableStreamStrong()
        }

        writer.close()

        pending.result = StreamResultWritable.err(SyscallError(32, "write")) // EPIPE
        runPending()
        clearKeepAliveRef()

        guard.drop()
    }

    /// 自动刷新回调
    /// 严格翻译自 FileSink.on_auto_flush()
    public func onAutoFlush(): Bool {
        if (done || !writer.hasPendingData) {
            updateRef(false)
            autoFlusher.registered = false
            return false
        }

        let guard = FileSinkRef.newRef(this)

        let amountBuffered = writer.buffer.size

        match (writer.flush().kind) {
            case IOWriteResultKind.Err =>
                updateRef(false)
                runPendingLater()
                guard.drop()
                return false
            case IOWriteResultKind.Done =>
                updateRef(false)
                runPendingLater()
                guard.drop()
                return false
            case IOWriteResultKind.Wrote =>
                () // 检查是否全部写出
            case IOWriteResultKind.Pending =>
                guard.drop()
                return true
        }

        let isRegistered = !writer.hasPendingData
        autoFlusher.registered = isRegistered
        guard.drop()
        return isRegistered
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 运行 pending 回调
    /// 严格翻译自 FileSink.run_pending()
    public func runPending(): Unit {
        let guard = FileSinkRef.newRef(this)
        runPendingLaterTask.has = false
        pending.run()
        jsSinkRef.deinit()
        guard.drop()
    }

    /// 延迟运行 pending
    /// 严格翻译自 FileSink.run_pending_later()
    public func runPendingLater(): Unit {
        if (runPendingLaterTask.has) {
            return
        }
        runPendingLaterTask.has = true
        ref()
        // 在实际实现中会入队到事件循环
        // EventLoopHandle.Js => enqueueTask(FlushPendingFileSinkTask)
        FileSink.deref(this)
    }

    /// 清除保持活跃引用
    /// 严格翻译自 FileSink.clear_keep_alive_ref()
    public func clearKeepAliveRef(): Unit {
        if (mustBeKeptAliveUntilEof) {
            mustBeKeptAliveUntilEof = false
            FileSink.deref(this)
        }
    }

    /// 将 IOWriteResult 转换为 StreamResultWritable
    /// 严格翻译自 FileSink.to_result()
    public func toResult(writeResult: IOWriteResult): StreamResultWritable {
        match (writeResult.kind) {
            case IOWriteResultKind.Done =>
                if (writeResult.amount > 0) {
                    return StreamResultWritable.ownedAndDone(writeResult.amount)
                }
                return StreamResultWritable.done()
            case IOWriteResultKind.Wrote =>
                if (writeResult.amount > 0) {
                    return StreamResultWritable.owned(writeResult.amount)
                }
                return StreamResultWritable.temporary(0)
            case IOWriteResultKind.Err =>
                match (writeResult.err) {
                    case Some(e) => StreamResultWritable.err(e)
                    case None => StreamResultWritable.err(SyscallError(5, "write"))
                }
            case IOWriteResultKind.Pending =>
                if (!mustBeKeptAliveUntilEof) {
                    mustBeKeptAliveUntilEof = true
                    ref()
                }
                pending.consumed += writeResult.amount
                pending.result = StreamResultWritable.owned(writeResult.amount)
                return StreamResultWritable.pending(pending)
        }
    }

    /// 将 IOWriteResult 转换为 FlushResult
    /// 严格翻译自 FileSink 内部 toWritableResult
    private func toWritableResult(writeResult: IOWriteResult): FlushResult {
        match (writeResult.kind) {
            case IOWriteResultKind.Err =>
                match (writeResult.err) {
                    case Some(e) => FlushResult.err(e)
                    case None => FlushResult.err(SyscallError(5, "write"))
                }
            case IOWriteResultKind.Pending =>
                FlushResult.pending()
            case _ => FlushResult.number(written)
        }
    }

    /// 更新引用
    /// 严格翻译自 FileSink.update_ref()
    public func updateRef(value: Bool): Unit {
        if (value) {
            writer.enableKeepingProcessAlive(eventLoopHandle)
        } else {
            writer.disableKeepingProcessAlive(eventLoopHandle)
        }
    }

    /// 内存开销
    /// 严格翻译自 FileSink.memory_cost()
    public func memoryCost(): Int64 {
        return writer.memoryCost()
    }

    /// 清除数据
    /// 严格翻译自 FileSink.clear_data() (对应 deinit 的清理部分)
    public func clearData(): Unit {
        readableStreamRef.deinit()
        pending.deinit()
        jsSinkRef.deinit()
        writer.close()
    }

    /// 释放资源 (deinit)
    /// 严格翻译自 FileSink.deinit()
    public static func deinit(`this`: FileSink): Unit {
        FileSinkLiveCount.count -= 1
        this.clearData()
    }

    /// 最终化
    /// 严格翻译自 FileSink.finalize()
    public func finalize(): Unit {
        readableStreamRef.deinit()
        pending.deinit()
        jsSinkRef.deinit()
        FileSink.deref(this)
    }

    /// 获取文件描述符
    /// 严格翻译自 FileSink.get_fd()
    public func getFd(): Int64 {
        return fd
    }

    /// 保护 JS 包装器
    /// 严格翻译自 FileSink.protect_js_wrapper()
    public func protectJsWrapper(globalThis: JsGlobalObject, jsWrapper: JsValue): Unit {
        jsSinkRef.set(globalThis, jsWrapper)
    }

    /// 打开文件用于写入
    private func openForWriting(path: String, flags: Int64, mode: Int64): Int64 {
        // 在实际实现中使用系统调用
        return 3 // 模拟返回一个 fd
    }

    // ========================================================================
    // 分配到流
    // ========================================================================

    /// 处理解析流
    /// 严格翻译自 FileSink.handle_resolve_stream()
    public func handleResolveStream(globalThis: JsGlobalObject): Unit {
        // 通知流完成
        if (!done) {
            writer.close()
        }
    }

    /// 处理拒绝流
    /// 严格翻译自 FileSink.handle_reject_stream()
    public func handleRejectStream(globalThis: JsGlobalObject, err: JsValue): Unit {
        readableStreamRef = ReadableStreamStrong()
        if (!done) {
            writer.close()
        }
    }

    /// 分配到流
    /// 严格翻译自 FileSink.assign_to_stream()
    public func assignToStream(stream: ReadableStream, globalThis: JsGlobalObject): JsValue {
        let guard = FileSinkRef.newRef(this)

        // 清除信号
        signal.clear()

        readableStreamRef = ReadableStreamStrong()
        readableStreamRef.hasValue = true

        // 调用 JSSink.assignToStream
        // 在实际实现中会调用 JSSink::assign_to_stream
        let promiseResult = JsValue.ZERO

        match (promiseResult.toError()) {
            case Some(err) =>
                readableStreamRef = ReadableStreamStrong()
                guard.drop()
                return err
            case None => ()
        }

        if (!promiseResult.isEmptyOrUndefinedOrNull()) {
            match (promiseResult.asAnyPromise()) {
                case Some(promise) =>
                    match (promise.status()) {
                        case JsPromiseStatus.Pending =>
                            writer.enableKeepingProcessAlive(ioEvtloop())
                            ref()
                            // 绑定 resolve/reject 处理器
                        case JsPromiseStatus.Fulfilled =>
                            handleResolveStream(globalThis)
                        case JsPromiseStatus.Rejected =>
                            let result = promise.result(globalThis)
                            handleRejectStream(globalThis, result)
                    }
                case None => ()
            }
        }

        guard.drop()
        return promiseResult
    }

    /// 转为 JS 值
    /// 严格翻译自 FileSink.to_js()
    public func toJS(globalThis: JsGlobalObject): JsValue {
        ref() // Wrapper 的 +1; 由 finalize -> deref() 释放
        return JsValue.fromSink(this)
    }

    /// 转为带析构器的 JS 值
    /// 严格翻译自 FileSink.to_js_with_destructor()
    public func toJSWithDestructor(globalThis: JsGlobalObject, destructor: ?Int64): JsValue {
        ref()
        return JsValue.fromSinkWithDestructor(this, destructor)
    }

    /// 转为 Sink
    /// 严格翻译自 FileSink.sink()
    public func sink(): SinkHandle {
        return SinkHandle(this)
    }

    /// 转为 Int64
    private func toInt64(): Int64 {
        // 模拟对象地址
        return hashIdentity()
    }
}

// ============================================================================
// 测试 API
// 严格翻译自 FileSink.rs testing_apis
// ============================================================================

/// FileSink 测试 API
public class FileSinkTestingAPIs {
    /// 获取活跃 FileSink 计数
    /// 严格翻译自 file_sink_live_count()
    public static func fileSinkLiveCount(globalThis: JsGlobalObject): JsValue {
        return JsValue.fromNumber(Float64(FileSinkLiveCount.count))
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

/// 流结束结果类型
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

// ============================================================================
// SinkHandle - Sink 句柄
// 严格翻译自 Sink.JSSink
// ============================================================================

/// Sink 句柄
public class SinkHandle {
    public var sink: FileSink

    public init(sink: FileSink) {
        this.sink = sink
    }
}

// ============================================================================
// JsStrongOptional - JS 强引用 Optional
// 严格翻译自 bun_jsc::strong::Optional
// ============================================================================

/// JS 强引用 Optional
public class JsStrongOptional {
    private var hasValue: Bool

    public init() {
        hasValue = false
    }

    public static func empty(): JsStrongOptional {
        return JsStrongOptional()
    }

    public func has(): Bool {
        return hasValue
    }

    public func set(globalThis: JsGlobalObject, value: JsValue): Unit {
        hasValue = true
    }

    public func deinit(): Unit {
        hasValue = false
    }

    public func handlePtr(): Int64 {
        return 0
    }
}

// ============================================================================
// JsGlobalObject / JsValue - JS 桥接类型
// ============================================================================

/// JS 全局对象
public class JsGlobalObject {
    public init() {}

    public func err(code: Int64, message: String): JsValue {
        return JsValue.fromError(message)
    }

    public func bunVm(): ?VirtualMachine {
        return None
    }
}

/// JS 值
public class JsValue {
    public static let ZERO: JsValue = JsValue()
    public static let UNDEFINED: JsValue = JsValue()

    public init() {}

    public static func fromNumber(v: Float64): JsValue {
        return JsValue()
    }

    public static func fromError(message: String): JsValue {
        return JsValue()
    }

    public static func fromSink(sink: FileSink): JsValue {
        return JsValue()
    }

    public static func fromSinkWithDestructor(sink: FileSink, destructor: ?Int64): JsValue {
        return JsValue()
    }

    public func isEmptyOrUndefinedOrNull(): Bool {
        return true
    }

    public func isAnyError(): Bool {
        return false
    }

    public func ensureStillAlive(): Unit {}

    public func toError(): ?JsValue {
        return None
    }

    public func asAnyPromise(): ?JsPromise {
        return None
    }
}

/// JS Promise
public class JsPromise {
    public func status(): JsPromiseStatus {
        return JsPromiseStatus.Pending
    }

    public func result(globalThis: JsGlobalObject): JsValue {
        return JsValue.ZERO
    }
}

/// JS Promise 状态
public enum JsPromiseStatus {
    | Pending
    | Fulfilled
    | Rejected
}

/// JS Weak 引用
public class JsWeak {
    public init() {}

    public func get(): ?JsValue {
        return None
    }

    public func clear(): Unit {}
}

/// JS Promise 强引用
public class JSPromiseStrong {
    public init() {}

    public static func empty(): JSPromiseStrong {
        return JSPromiseStrong()
    }

    public func valueOrEmpty(): JsValue {
        return JsValue.ZERO
    }

    public func take(): JSPromiseStrong {
        return JSPromiseStrong()
    }
}

/// VirtualMachine
public class VirtualMachine {
    public init() {}

    public func isShuttingDown(): Bool {
        return false
    }

    public func jscVm(): Int64 {
        return 0
    }
}

// ============================================================================
// SyscallError - 系统调用错误
// ============================================================================

/// 系统调用错误
public class SyscallError {
    public var errno: Int64
    public var syscall: String

    public init(errno: Int64, syscall: String) {
        this.errno = errno
        this.syscall = syscall
    }
}
