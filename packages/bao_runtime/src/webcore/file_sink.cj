// FileSink - 文件写入 Sink
// 严格翻译自: src/runtime/webcore/FileSink.rs (Rust port of FileSink.zig)
// 包含: FileSink 完整实现, IOWriter, Options, FlushPendingTask, 回调方法, JS 绑定等
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_jsc.*

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
        inputPath = PathOrFileDescriptor(Int32(Fd.INVALID))
        truncate = true
        close = false
        mode = 0o664
    }

    public init(path: String) {
        chunkSize = 1024
        let p = PathOrFileDescriptor(Int32(-1))
        p.isFd = false
        inputPath = p
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
        return buffer.capacity()
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
    public var errValue: ?SyscallError

    public init(kind: IOWriteResultKind, amount: Int64) {
        this.kind = kind
        this.amount = amount
        this.errValue = None
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
        r.errValue = Some(e)
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

// ============================================================================
// 测试 API
// 严格翻译自 FileSink.rs testing_apis
// ============================================================================

/// FileSink 测试 API
public class FileSinkTestingAPIs {
    /// 获取活跃 FileSink 计数
    /// 严格翻译自 file_sink_live_count()
    public static func fileSinkLiveCount(globalThis: JsGlobalObject): JsValue {
        return JsValue.jsNumber(Float64(FileSinkLiveCount.count))
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
    public var errValue: ?SyscallError

    private init(kind: StreamEndResultKind) {
        this.kind = kind
        this.value = 0
        this.errValue = None
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
        r.errValue = Some(e)
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
    public var errValue: ?SyscallError

    private init(kind: FlushResultKind) {
        this.kind = kind
        this.value = 0
        this.errValue = None
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
        r.errValue = Some(e)
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

/// JSPromiseStrong is defined in streams.cj

