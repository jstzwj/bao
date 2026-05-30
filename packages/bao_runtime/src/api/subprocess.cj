// 翻译自: src/runtime/api/bun/subprocess.zig
//   Subprocess — Bun.spawn 返回的子进程对象
//   包含 spawn/spawnSync 实现、IPC、信号处理等
package bao_runtime.api

import bao_collections.ArrayList
import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}
import bao_sys.*

// ============================================================================
// SignalCode — 信号代码
// 翻译自: bun.SignalCode (subprocess.zig:67)
// ============================================================================

public enum SignalCode {
    | SIGTERM | SIGKILL | SIGINT | SIGHUP | SIGQUIT | SIGUSR1 | SIGUSR2 | SIGSTOP | SIGCONT

    public prop rawValue: Int32 {
        get() {
            match (this) {
                case SIGKILL => 9
                case SIGINT => 2
                case SIGHUP => 1
                case SIGQUIT => 3
                case SIGUSR1 => 10
                case SIGUSR2 => 12
                case SIGSTOP => 19
                case SIGCONT => 18
                case SIGTERM => 15
            }
        }
    }

    /// 转为退出码 (128 + signal)
    /// 翻译自: bun.SignalCode.toExitCode
    public func toExitCode(): ?Int32 { Some(128 + rawValue) }

    /// 获取信号名称
    /// 翻译自: bun.SignalCode.name
    public func name(): ?String {
        match (this) {
            case SIGKILL => Some("SIGKILL")
            case SIGINT => Some("SIGINT")
            case SIGHUP => Some("SIGHUP")
            case SIGQUIT => Some("SIGQUIT")
            case SIGUSR1 => Some("SIGUSR1")
            case SIGUSR2 => Some("SIGUSR2")
            case SIGSTOP => Some("SIGSTOP")
            case SIGCONT => Some("SIGCONT")
            case SIGTERM => Some("SIGTERM")
        }
    }

    /// 从整数构造
    public static func fromInt(value: Int32): SignalCode {
        match (value) {
            case 9 => SIGKILL
            case 2 => SIGINT
            case 1 => SIGHUP
            case 3 => SIGQUIT
            case 10 => SIGUSR1
            case 12 => SIGUSR2
            case 19 => SIGSTOP
            case 18 => SIGCONT
            case _ => SIGTERM
        }
    }

    /// 从 JS 值解析
    /// 翻译自: bun.SignalCode.fromJS
    public static func fromJS(v!: Any, globalThis!: JsGlobalObject): SignalCode {
        // TODO(bao-runtime-api): 从 JS 值解析信号 (字符串或数字)
        SignalCode.SIGTERM
    }
}

// ============================================================================
// MaxBufKind / ApiStdioKind — 辅助枚举
// ============================================================================

public enum MaxBufKind { | maxStdout | maxStderr }
public enum ApiStdioKind { | apiStdin | apiStdout | apiStderr }

// ============================================================================
// FileSink / FileSinkJSSinkHelper — 文件写入器
// 翻译自: jsc.WebCore.FileSink
// ============================================================================

public class FileSinkJSSinkHelper {
    public init() {}
    public func fromJS(v!: Any): ?FileSink { None }
    public func setDestroyCallback(v!: Any, i!: Int32): Unit {}
}

public class FileSink {
    public static let JSSink: FileSinkJSSinkHelper = FileSinkJSSinkHelper()
    public init() {}
    public static func create(eventLoop!: EventLoop, result!: StdioResult): FileSink { FileSink() }
    public static func createWithPipe(eventLoop!: EventLoop, result!: StdioResult): FileSink { FileSink() }
    public static func onAttachedProcessExitStatic(pipe!: FileSink, status!: Status): Unit {}
    public func close(): Unit {}
    public func ref(): Unit {}
    public func deref(): Unit {}
    public func updateRef(add!: Bool): Unit {}
    public func toJS(globalThis!: JsGlobalObject): JsValue { JsValue.jsUndefined() }
    public func toJSWithDestructor(globalThis!: JsGlobalObject, destructor!: Any): JsValue { JsValue.jsUndefined() }
    public func onAttachedProcessExit(status!: Status): Unit {}
}

// ============================================================================
// Signal — 信号句柄
// 翻译自: subprocess.zig signal 相关
// ============================================================================

public class Signal {
    public var ptr: Int64 = 0
    public init() {}
    public func clear(): Unit { ptr = 0 }
    public func get(): Signal { this }
}

// ============================================================================
// MaxBuf — 最大缓冲区限制
// 翻译自: bun.io.MaxBuf
// ============================================================================

public class MaxBuf {
    public init() {}
    public static func createForSubprocess(owner!: Subprocess, slot!: ?MaxBuf, initial!: ?Int64): Unit {}
    public static func removeFromSubprocess(slot!: ?MaxBuf): Unit {}
    public static func addToPipeReader(limit!: ?MaxBuf, readerMaxbuf!: Any): Unit {}
}

// ============================================================================
// TimerAll — 定时器管理
// 翻译自: JscHooks.timerAllMut()
// ============================================================================

public class TimerAll {
    public init() {}
    public func incrementTimerRef(delta!: Int32, uwsLoop!: Any): Unit {}
    public func remove(timer!: Any): Unit {}
}

// ============================================================================
// CowString — 写时复制字符串
// 翻译自: bun.ptr.CowString
// ============================================================================

public class CowString {
    public init() {}
    public static func initOwned(s!: String): CowString { CowString() }
}

// ============================================================================
// PipeReaderState — 管道读取器状态
// 翻译自: SubprocessPipeReader.zig state
// ============================================================================

public enum PipeReaderState {
    | pending
    | done(Array<UInt8>)
    | pipeErr(SysError)

    public func isPending(): Bool {
        match (this) {
            case pending => true
            case _ => false
        }
    }

    public func isDone(): Bool {
        match (this) {
            case done(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// JscHooks — JSC 钩子
// ============================================================================

public class JscHooks {
    public static func timerAllMut(): TimerAll { TimerAll() }
}

// ============================================================================
// EnumSet<T> — 枚举集合
// 翻译自: std.enums.EnumSet
// ============================================================================

public class EnumSet<T> {
    private var bits: UInt32 = 0
    public init() {}
    public func insert(value!: T): Unit {
        // TODO(bao-runtime-api): 位操作设置
    }
    public func remove(value!: T): Unit {
        // TODO(bao-runtime-api): 位操作清除
    }
    public func contains(value!: T): Bool {
        // TODO(bao-runtime-api): 位操作检查
        false
    }
}

// ============================================================================
// StdioResult — stdio 结果
// 翻译自: subprocess.zig:993
//   pub const StdioResult = if (Environment.isWindows) ... else ?bun.FD
// ============================================================================

public enum StdioResult {
    | owned
    | unowned
    | unavailable
}

// ============================================================================
// ObservableGetter — 可观察的 getter
// 翻译自: subprocess.zig:27-31
//   observable_getters: std.enums.EnumSet(enum { stdin, stdout, stderr })
// ============================================================================

public enum ObservableGetter {
    | observableStdin
    | observableStdout
    | observableStderr
}

// ============================================================================
// SubprocessFlags — 子进程标志
// 翻译自: subprocess.zig:53-65
//   pub const Flags = packed struct(u8) { ... }
// ============================================================================

public class SubprocessFlags {
    public static let IS_SYNC: UInt8 = 1
    public static let KILLED: UInt8 = 2
    public static let HAS_STDIN_DESTRUCTOR_CALLED: UInt8 = 4
    public static let FINALIZED: UInt8 = 8
    public static let DEREF_ON_STDIN_DESTROYED: UInt8 = 16
    public static let IS_STDIN_A_READABLE_STREAM: UInt8 = 32
    public static let OWNS_TERMINAL: UInt8 = 64

    public var isSync: Bool = false
    public var killed: Bool = false
    public var hasStdinDestructorCalled: Bool = false
    public var finalized: Bool = false
    public var derefOnStdinDestroyed: Bool = false
    public var isStdinAReadableStream: Bool = false
    public var ownsTerminal: Bool = false

    public init() {}
    public func contains(flag!: UInt8): Bool { false }
    public func insert(flag!: UInt8): Unit {}
    public func remove(flag!: UInt8): Unit {}
    public func `get`(): UInt8 { 0 }
}

// ============================================================================
// JSSubprocess — JS 子进程绑定
// 翻译自: jsc.Codegen.JSSubprocess
// ============================================================================

public class JSSubprocess {
    public static func stdinGetCached(value!: JsValue): ?JsValue { None }
    public static func stdinSetCached(value!: JsValue, globalThis!: JsGlobalObject, cached!: JsValue): Unit {}
    public static func exitedPromiseGetCached(value!: JsValue): ?JsValue { None }
    public static func exitedPromiseSetCached(value!: JsValue, globalThis!: JsGlobalObject, cached!: JsValue): Unit {}
    public static func ipcCallbackGetCached(value!: JsValue): ?JsValue { None }
    public static func ipcCallbackSetCached(value!: JsValue, globalThis!: JsGlobalObject, cached!: JsValue): Unit {}
    public static func onExitCallbackGetCached(value!: JsValue): ?JsValue { None }
    public static func onExitCallbackSetCached(value!: JsValue, globalThis!: JsGlobalObject, cached!: JsValue): Unit {}
    public static func onDisconnectCallbackGetCached(value!: JsValue): ?JsValue { None }
    public static func onDisconnectCallbackSetCached(value!: JsValue, globalThis!: JsGlobalObject, cached!: JsValue): Unit {}
    public static func toJS(ptr!: Subprocess, global!: JsGlobalObject): JsValue { JsValue.jsUndefined() }
}

// ============================================================================
// SubprocessRefCount — 引用计数
// 翻译自: subprocess.zig:11-13
//   const RefCount = bun.ptr.RefCount(...)
// ============================================================================

public class SubprocessRefCount {
    private var count: Int32 = 1
    public init() {}
    public func ref(): Unit { count++ }
    public func deref(): Unit { count-- }
}

// ============================================================================
// Subprocess — 子进程对象
// 翻译自: src/runtime/api/bun/subprocess.zig:1-1025
//   const Subprocess = @This();
//   Bun.spawn 返回的子进程对象
// ============================================================================

public class Subprocess {
    public var refCount: SubprocessRefCount = SubprocessRefCount()
    public var process: BackRef<Process> = BackRef<Process>.from(value: Process())
    public var stdin: Writable = Writable.ignore
    public var stdout: Readable = Readable.ignore
    public var stderr: Readable = Readable.ignore
    public var stdioPipes: ArrayList<StdioPipeItem> = ArrayList<StdioPipeItem>()
    public var pidRusage: ?Rusage = None
    public var terminal: ?Terminal = None
    public var globalThis: BackRef<JsGlobalObject> = BackRef<JsGlobalObject>.from(value: JsGlobalObject())
    public var observableGetters: EnumSet<ObservableGetter> = EnumSet<ObservableGetter>()
    public var closed: EnumSet<ApiStdioKind> = EnumSet<ApiStdioKind>()
    public var thisValue: JsRef = JsRef.empty()
    public var ipcData: ?IPCSendQueue = None
    public var flags: SubprocessFlags = SubprocessFlags()
    public var weakFileSinkStdinPtr: ?FileSink = None
    public var abortSignal: ?AbortSignal = None
    public var eventLoopTimerRefd: Bool = false
    public var killSignal: SignalCode = SignalCode.SIGTERM
    public var stdoutMaxbuf: ?MaxBuf = None
    public var stderrMaxbuf: ?MaxBuf = None
    public var exitedDueToMaxbuf: ?MaxBufKind = None

    public init() {}

    // ========================================================================
    // 断言 / 工厂方法
    // ========================================================================

    /// 断言 StdioResult 有效
    /// 翻译自: subprocess.zig:79-87
    ///   pub inline fn assertStdioResult(result: StdioResult) void
    public static func assertStdioResult(result!: StdioResult): Unit {}

    /// 从字段父指针构造
    /// 翻译自: @fieldParentPtr
    public static func fromFieldParentPtr(field!: String, value!: Any): Subprocess { Subprocess() }

    /// 从 JS 值获取 Subprocess
    /// 翻译自: subprocess.zig:8-9 (fromJS = js.fromJS)
    public static func fromJS(value!: JsValue): ?Subprocess { None }

    /// 获取定时器
    /// 翻译自: JscHooks.timerAllMut()
    public static func timerAll(): TimerAll { TimerAll() }

    // ========================================================================
    // spawn / spawnSync — 进程生成
    // 翻译自: subprocess.zig:997-998
    //   pub const spawnSync = js_bun_spawn_bindings.spawnSync;
    //   pub const spawn = js_bun_spawn_bindings.spawn;
    // ========================================================================

    /// spawn — 异步生成子进程
    /// 翻译自: js_bun_spawn_bindings.spawn
    public static func `spawn`(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // TODO(bao-runtime-api): 完整实现 spawn
        //   1. 解析 JS 参数 (command, args, env, cwd, stdio, ...)
        //   2. 构建 PosixSpawnOptions
        //   3. 调用 spawnProcessPosix
        //   4. 创建 Process 对象
        //   5. 初始化 Readable/Writable
        //   6. 启动进程监控
        //   7. 返回 JSSubprocess
        JsValue.jsUndefined()
    }

    /// spawnSync — 同步生成子进程
    /// 翻译自: js_bun_spawn_bindings.spawnSync
    public static func spawnSync(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // TODO(bao-runtime-api): 完整实现 spawnSync
        JsValue.jsUndefined()
    }

    /// 转为 JS 值 (从指针)
    /// 翻译自: subprocess.zig:214
    ///   pub fn toJSFromPtr(ptr, global) -> JSValue
    public static func toJSFromPtr(ptr!: Subprocess, global!: JsGlobalObject): JsValue {
        JSSubprocess.toJS(ptr: ptr, global: global)
    }

    // ========================================================================
    // 消费 cached 值
    // 翻译自: subprocess.zig:558-580
    // ========================================================================

    /// 消费 exitedPromise
    /// 翻译自: subprocess.zig:558-564
    ///   fn consumeExitedPromise(this_jsvalue, globalThis) -> ?JSValue
    public static func consumeExitedPromise(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue {
        match (JSSubprocess.exitedPromiseGetCached(value: thisJsvalue)) {
            case Some(promise) =>
                JSSubprocess.exitedPromiseSetCached(value: thisJsvalue, globalThis: globalThis, cached: JsValue.jsUndefined())
                return promise
            case None => return JsValue.jsUndefined()
        }
    }

    /// 消费 onExitCallback
    /// 翻译自: subprocess.zig:566-572
    ///   fn consumeOnExitCallback(this_jsvalue, globalThis) -> ?JSValue
    public static func consumeOnExitCallback(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue {
        match (JSSubprocess.onExitCallbackGetCached(value: thisJsvalue)) {
            case Some(callback) =>
                JSSubprocess.onExitCallbackSetCached(value: thisJsvalue, globalThis: globalThis, cached: JsValue.jsUndefined())
                return callback
            case None => return JsValue.jsUndefined()
        }
    }

    /// 消费 onDisconnectCallback
    /// 翻译自: subprocess.zig:574-580
    ///   fn consumeOnDisconnectCallback(this_jsvalue, globalThis) -> ?JSValue
    public static func consumeOnDisconnectCallback(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue {
        match (JSSubprocess.onDisconnectCallbackGetCached(value: thisJsvalue)) {
            case Some(callback) =>
                JSSubprocess.onDisconnectCallbackSetCached(value: thisJsvalue, globalThis: globalThis, cached: JsValue.jsUndefined())
                return callback
            case None => return JsValue.jsUndefined()
        }
    }

    // ========================================================================
    // 访问器
    // ========================================================================

    public func getProcess(): Process { process.get() }
    public func processMut(): Process { process.get() }
    public func getGlobalThis(): JsGlobalObject { globalThis.get() }
    public func getGlobalThisOptional(): ?JsGlobalObject { Some(globalThis.get()) }

    /// 内存占用
    /// 翻译自: subprocess.zig:550-556
    ///   pub fn memoryCost(this: *const Subprocess) -> usize
    public func memoryCost(): Int64 {
        256 + process.get().memoryCost() + 0 + 0 + 0
    }

    /// 是否已退出
    /// 翻译自: subprocess.zig:148-150
    ///   pub fn hasExited(this: *const Subprocess) -> bool
    public func hasExited(): Bool { getProcess().hasExited() }

    /// 是否已被 kill
    /// 翻译自: subprocess.zig:408-410
    ///   pub fn hasKilled(this: *const Subprocess) -> bool
    public func hasKilled(): Bool { flags.killed || getProcess().hasKilled() }

    // ========================================================================
    // 引用管理
    // 翻译自: subprocess.zig:247-282
    // ========================================================================

    /// 引用
    /// 翻译自: subprocess.zig:12-13 (RefCount.ref)
    public func ref(): Unit { refCount.ref() }

    /// 取消引用
    /// 翻译自: subprocess.zig:12-13 (RefCount.deref)
    public func deref(): Unit { refCount.deref() }

    /// JS 引用 (保持事件循环活跃)
    /// 翻译自: subprocess.zig:247-263
    ///   pub fn jsRef(this: *Subprocess) -> void
    public func jsRef(): Unit {
        getProcess().enableKeepingEventLoopAlive()

        if (!hasCalledGetter(getter: ObservableGetter.observableStdin)) {
            stdin.ref()
        }
        if (!hasCalledGetter(getter: ObservableGetter.observableStdout)) {
            stdout.ref()
        }
        if (!hasCalledGetter(getter: ObservableGetter.observableStderr)) {
            stderr.ref()
        }

        updateHasPendingActivity()
    }

    /// JS 取消引用
    /// 翻译自: subprocess.zig:266-282
    ///   pub fn jsUnref(this: *Subprocess) -> void
    public func jsUnref(): Unit {
        getProcess().disableKeepingEventLoopAlive()

        if (!hasCalledGetter(getter: ObservableGetter.observableStdin)) {
            stdin.unref()
        }
        if (!hasCalledGetter(getter: ObservableGetter.observableStdout)) {
            stdout.unref()
        }
        if (!hasCalledGetter(getter: ObservableGetter.observableStderr)) {
            stderr.unref()
        }

        updateHasPendingActivity()
    }

    // ========================================================================
    // 待处理活动
    // 翻译自: subprocess.zig:152-203
    // ========================================================================

    /// 计算是否有待处理的活动
    /// 翻译自: subprocess.zig:152-173
    ///   pub fn computeHasPendingActivity(this: *const Subprocess) -> bool
    private func computeHasPendingActivity(): Bool {
        // IPC 数据有待处理活动
        if (ipcData.isSome()) {
            // TODO(bao-runtime-api): 检查 close_event_sent
            return true
        }

        if (hasPendingActivityStdio()) {
            return true
        }

        if (!getProcess().hasExited()) {
            return true
        }

        return false
    }

    /// 更新待处理活动状态
    /// 翻译自: subprocess.zig:175-189
    ///   pub fn updateHasPendingActivity(this: *Subprocess) -> void
    public func updateHasPendingActivity(): Unit {
        if (flags.isSync) { return }

        let hasPending = computeHasPendingActivity()

        // 根据待处理活动升级或降级引用
        if (hasPending) {
            thisValue.upgrade(globalThis: getGlobalThis())
        } else {
            thisValue.downgrade()
        }
    }

    /// 检查 stdio 是否有待处理活动
    /// 翻译自: subprocess.zig:191-203
    ///   pub fn hasPendingActivityStdio(this: *const Subprocess) -> bool
    private func hasPendingActivityStdio(): Bool {
        if (stdin.hasPendingActivity()) { return true }
        if (stdout.hasPendingActivity()) { return true }
        if (stderr.hasPendingActivity()) { return true }
        return false
    }

    // ========================================================================
    // IO 关闭
    // 翻译自: subprocess.zig:205-245
    // ========================================================================

    /// 关闭 IO
    /// 翻译自: subprocess.zig:205-245
    ///   pub fn onCloseIO(this: *Subprocess, kind: StdioKind) -> void
    public func onCloseIO(kind!: ApiStdioKind): Unit {
        closed.insert(value: kind)
        updateHasPendingActivity()
    }

    // ========================================================================
    // 进程退出处理
    // 翻译自: subprocess.zig:582-741
    // ========================================================================

    /// 进程退出回调
    /// 翻译自: subprocess.zig:582-741
    ///   pub fn onProcessExit(this, process, status, rusage) -> void
    public func onProcessExit(process!: Process, status!: Status, rusage!: Rusage): Unit {
        pidRusage = Some(rusage)
        this.process.get().status = status
        this.process.get().killed = true

        // 清除 abort signal
        clearAbortSignal()

        // 断开 IPC
        disconnectIPC(nextTick: true)

        // 如果使用了 terminal，关闭它
        if (terminal.isSome()) {
            // TODO(bao-runtime-api): terminal.closePseudoconsole() (Windows)
        }

        // 关闭 stdin buffer
        match (stdin) {
            case Writable.buffer(buf) => buf.close()
            case _ => ()
        }

        // 如果是同步模式，关闭 stdout/stderr 管道
        if (flags.isSync) {
            match (stdout) {
                case Readable.pipe(reader) => reader.close()
                case _ => ()
            }
            match (stderr) {
                case Readable.pipe(reader) => reader.close()
                case _ => ()
            }
        }

        // 更新待处理活动
        updateHasPendingActivity()
    }

    // ========================================================================
    // 最大缓冲区处理
    // 翻译自: subprocess.zig:376-379
    // ========================================================================

    /// 最大缓冲区超出回调
    /// 翻译自: subprocess.zig:376-379
    ///   pub fn onMaxBuffer(this: *Subprocess, kind: MaxBuf.Kind) -> void
    public func onMaxBuffer(kind!: MaxBufKind): Unit {
        exitedDueToMaxbuf = Some(kind)
        _ = tryKill(sig: killSignal)
    }

    // ========================================================================
    // Abort signal 处理
    // 翻译自: subprocess.zig:114-118, 793-800
    // ========================================================================

    /// Abort signal 回调
    /// 翻译自: subprocess.zig:114-118
    ///   pub fn onAbortSignal(subprocess_ctx, _) -> void
    public func handleAbortSignal(reason!: JsValue): Unit {
        clearAbortSignal()
        _ = tryKill(sig: killSignal)
    }

    /// Abort signal 静态回调
    /// 翻译自: subprocess.zig:114-118 (callconv(.c))
    public static func onAbortSignal(ctx!: Unit, reason!: JsValue): Unit {}

    /// 清除 abort signal
    /// 翻译自: subprocess.zig:793-800
    ///   fn clearAbortSignal(this: *Subprocess) -> void
    private func doClearAbortSignal(): Unit {
        if (abortSignal.isSome()) {
            let signal = abortSignal.getOrThrow()
            abortSignal = None
            signal.pendingActivityUnref()
            signal.cleanNativeBindings(this)
            signal.unref()
        }
    }

    // ========================================================================
    // 信号 / kill
    // 翻译自: subprocess.zig:381-417
    // ========================================================================

    /// 尝试发送信号
    /// 翻译自: subprocess.zig:412-417
    ///   pub fn tryKill(this: *Subprocess, sig: SignalCode) -> bun.sys.Maybe(void)
    public func tryKill(sig!: SignalCode): Maybe<Unit> {
        if (hasExited()) {
            return SysMaybe<Unit>.Ok(())
        }
        flags.killed = true
        return getProcess().kill(signal: sig.rawValue)
    }

    /// kill 方法 (JS 调用)
    /// 翻译自: subprocess.zig:381-406
    ///   pub fn kill(this, globalThis, callframe) -> bun.JSError!JSValue
    public func kill(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.argumentsAsArray(1)
        let sig = SignalCode.fromJS(v: args[0], globalThis: globalThis)

        match (tryKill(sig: sig)) {
            case Ok(_) => ()
            case Err(e) =>
                // TODO(bao-runtime-api): 抛出 JS 错误
                ()
        }

        JsValue.jsUndefined()
    }

    // ========================================================================
    // 引用/取消引用 (JS 调用)
    // 翻译自: subprocess.zig:430-438
    // ========================================================================

    /// 引用 (JS 调用)
    /// 翻译自: subprocess.zig:430-433
    ///   pub fn doRef(this, _, _) -> bun.JSError!JSValue
    public func doRef(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        jsRef()
        JsValue.jsUndefined()
    }

    /// 取消引用 (JS 调用)
    /// 翻译自: subprocess.zig:435-438
    ///   pub fn doUnref(this, _, _) -> bun.JSError!JSValue
    public func doUnref(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        jsUnref()
        JsValue.jsUndefined()
    }

    // ========================================================================
    // IPC
    // 翻译自: subprocess.zig:454-468
    // ========================================================================

    /// 发送 IPC 消息
    /// 翻译自: subprocess.zig:454-458
    ///   pub fn doSend(this, global, callFrame) -> bun.JSError!JSValue
    public func doSend(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        // TODO(bao-runtime-api): 实现 IPC.doSend
        JsValue.jsUndefined()
    }

    /// 处理 IPC 消息
    /// 翻译自: subprocess.zig:892-925
    ///   pub fn handleIPCMessage(this, message, handle) -> void
    public func handleIPCMessage(message!: IPCDecodedIPCMessage, handle!: JsValue): Unit {
        // TODO(bao-runtime-api): 实现 IPC 消息分发
    }

    /// 处理 IPC 关闭
    /// 翻译自: subprocess.zig:927-943
    ///   pub fn handleIPCClose(this) -> void
    public func handleIPCClose(): Unit {
        updateHasPendingActivity()
    }

    /// 断开 IPC
    /// 翻译自: subprocess.zig:459-462
    ///   pub fn disconnectIPC(this, nextTick) -> void
    public func disconnectIPC(nextTick!: Bool): Unit {
        // TODO: restore enum pattern matching when associated value destructuring works
        if (ipcData.isSome()) {
            let data = ipcData.getOrThrow()
            data.closeSocketNextTick(nextTick)
        }
    }

    /// 断开连接 (JS 调用)
    /// 翻译自: subprocess.zig:463-468
    ///   pub fn disconnect(this, globalThis, callframe) -> bun.JSError!JSValue
    public func disconnect(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        disconnectIPC(nextTick: true)
        JsValue.jsUndefined()
    }

    /// 获取 IPC 队列
    /// 翻译自: subprocess.zig:945-947
    ///   pub fn ipc(this) -> ?*IPC.SendQueue
    public func ipc(): ?IPCSendQueue { ipcData }

    // ========================================================================
    // Abort signal 引用
    // 翻译自: subprocess.zig:257-264
    // ========================================================================

    /// 获取 abort signal 引用
    /// 翻译自: subprocess.zig:257-262
    ///   pub fn abortSignalRef(this) -> ?*webcore.AbortSignal
    public func abortSignalRef(): ?BackRef<AbortSignal> {
        match (abortSignal) {
            case Some(signal) => Some(BackRef<AbortSignal>.from(value: signal))
            case None => None
        }
    }

    /// 清除 abort signal (委托到完整实现)
    /// 翻译自: subprocess.zig:263
    public func clearAbortSignal(): Unit {
        // 委托到下方的 private 完整版本
        doClearAbortSignal()
    }

    /// 设置事件循环定时器引用
    /// 翻译自: subprocess.zig:355-363
    ///   pub fn setEventLoopTimerRefd(this, refd) -> void
    public func setEventLoopTimerRefd(value!: Bool): Unit {
        if (eventLoopTimerRefd == value) { return }
        eventLoopTimerRefd = value
        // TODO(bao-runtime-api): 调用 timer.incrementTimerRef
    }

    // ========================================================================
    // stdin 销毁
    // 翻译自: subprocess.zig:440-452
    // ========================================================================

    /// stdin 销毁回调
    /// 翻译自: subprocess.zig:440-452
    ///   pub fn onStdinDestroyed(this: *Subprocess) -> void
    public func onStdinDestroyed(): Unit {
        weakFileSinkStdinPtr = None
        flags.hasStdinDestructorCalled = true
        if (!flags.finalized) {
            updateHasPendingActivity()
        }
    }

    // ========================================================================
    // Flags 更新
    // ========================================================================

    /// 更新标志
    public func updateFlags(fn!: (SubprocessFlags) -> Unit): Unit { fn(flags) }

    // ========================================================================
    // Getter 检查
    // 翻译自: subprocess.zig:419-421
    // ========================================================================

    /// 检查是否调用了 getter
    /// 翻译自: subprocess.zig:419-421
    ///   fn hasCalledGetter(this, comptime getter) -> bool
    private func hasCalledGetter(getter!: ObservableGetter): Bool {
        observableGetters.contains(value: getter)
    }

    // ========================================================================
    // 获取 stdio
    // 翻译自: subprocess.zig:291-327
    // ========================================================================

    /// 获取 stdin
    /// 翻译自: subprocess.zig:300-307
    ///   pub fn getStdin(this, globalThis) -> bun.JSError!JSValue
    public func getStdin(globalThis!: JsGlobalObject): JsValue {
        // 如果使用了 terminal，stdin 通过 terminal
        if (terminal.isSome()) {
            return JsValue.jsNull()
        }
        observableGetters.insert(value: ObservableGetter.observableStdin)
        return stdin.toJS(globalThis: globalThis, subprocess: this)
    }

    /// 获取 stdout
    /// 翻译自: subprocess.zig:309-319
    ///   pub fn getStdout(this, globalThis) -> bun.JSError!JSValue
    public func getStdout(globalThis!: JsGlobalObject): JsValue {
        // 如果使用了 terminal，stdout 通过 terminal
        if (terminal.isSome()) {
            return JsValue.jsNull()
        }
        observableGetters.insert(value: ObservableGetter.observableStdout)
        return stdout.toJS(globalThis: globalThis, exited: hasExited())
    }

    /// 获取 stderr
    /// 翻译自: subprocess.zig:291-298
    ///   pub fn getStderr(this, globalThis) -> bun.JSError!JSValue
    public func getStderr(globalThis!: JsGlobalObject): JsValue {
        // 如果使用了 terminal，stderr 通过 terminal
        if (terminal.isSome()) {
            return JsValue.jsNull()
        }
        observableGetters.insert(value: ObservableGetter.observableStderr)
        return stderr.toJS(globalThis: globalThis, exited: hasExited())
    }

    // ========================================================================
    // exited / exitCode / signalCode
    // 翻译自: subprocess.zig:840-890
    // ========================================================================

    /// 获取 exited promise
    /// 翻译自: subprocess.zig:840-866
    ///   pub fn getExited(this, this_value, globalThis) -> JSValue
    public func getExited(thisValue!: JsValue, globalThis!: JsGlobalObject): JsValue {
        // TODO(bao-runtime-api): 实现 exited promise
        JsValue.jsUndefined()
    }

    /// 获取退出码
    /// 翻译自: subprocess.zig:868-876
    ///   pub fn getExitCode(this, _) -> JSValue
    public func getExitCode(globalThis!: JsGlobalObject): JsValue {
        match (getProcess().status) {
            case Status.exited(exit) => JsValue.jsNumber(Int64(exit.code))
            case _ => JsValue.jsNull()
        }
    }

    /// 获取信号代码
    /// 翻译自: subprocess.zig:878-890
    ///   pub fn getSignalCode(this, global) -> JSValue
    public func getSignalCode(global!: JsGlobalObject): JsValue {
        match (getProcess().signalCode()) {
            case Some(signal) =>
                match (signal.name()) {
                    case Some(name) => return JsValue.jsString(name)
                    case None => return JsValue.jsNumber(Int64(signal.rawValue))
                }
            case None => return JsValue.jsNull()
        }
    }

    // ========================================================================
    // 关闭 / 释放
    // 翻译自: subprocess.zig:767-838
    // ========================================================================

    /// 关闭所有 IO
    /// 翻译自: subprocess.zig:743-759
    ///   fn closeIO(this, comptime io) -> void
    private func closeIO(io!: ApiStdioKind): Unit {
        if (closed.contains(value: io)) { return }
        closed.insert(value: io)

        let og = observableFromKind(kind: io)
        if (!hasCalledGetter(getter: og)) {
            // 从未被 JS 访问过，直接释放
            match (io) {
                case ApiStdioKind.apiStdin => stdin.finalize()
                case ApiStdioKind.apiStdout => stdout.finalize()
                case ApiStdioKind.apiStderr => stderr.finalize()
            }
        } else {
            match (io) {
                case ApiStdioKind.apiStdin => stdin.close()
                case ApiStdioKind.apiStdout => stdout.close()
                case ApiStdioKind.apiStderr => stderr.close()
            }
        }
    }

    /// 辅助: ApiStdioKind -> ObservableGetter
    private func observableFromKind(kind!: ApiStdioKind): ObservableGetter {
        match (kind) {
            case ApiStdioKind.apiStdin => ObservableGetter.observableStdin
            case ApiStdioKind.apiStdout => ObservableGetter.observableStdout
            case ApiStdioKind.apiStderr => ObservableGetter.observableStderr
        }
    }

    /// 关闭所有流
    /// 翻译自: subprocess.zig:767-786
    ///   pub fn finalizeStreams(this: *Subprocess) -> void
    private func finalizeStreams(): Unit {
        closeIO(io: ApiStdioKind.apiStdin)
        closeIO(io: ApiStdioKind.apiStdout)
        closeIO(io: ApiStdioKind.apiStderr)
    }

    /// 关闭
    /// 翻译自: subprocess.zig closeIO + finalizeStreams
    public func close(): Unit {
        stdin.close()
        stdout.close()
        stderr.close()
    }

    /// Finalize — GC 回收时调用
    /// 翻译自: subprocess.zig:802-838
    ///   pub fn finalize(this: *Subprocess) callconv(.c) -> void
    public func finalize(): Unit {
        thisValue.finalize()
        clearAbortSignal()
        finalizeStreams()

        getProcess().detach()
        getProcess().deref()

        // 移除定时器
        setEventLoopTimerRefd(value: false)

        // 移除 maxbuf
        MaxBuf.removeFromSubprocess(slot: stdoutMaxbuf)
        MaxBuf.removeFromSubprocess(slot: stderrMaxbuf)

        // 释放 IPC
        if (ipcData.isSome()) {
            ipcData.getOrThrow().deinit()
            ipcData = None
        }

        flags.finalized = true
        deref()
    }
}

// ============================================================================
// TestingAPIs — 测试辅助 API
// 翻译自: subprocess.zig:954-991
//   pub const TestingAPIs = struct { ... }
// ============================================================================

public class TestingAPIs {
    /// 注入 stdio 读取错误
    /// 翻译自: subprocess.zig:964-990
    ///   pub fn injectStdioReadError(globalThis, callframe) -> bun.JSError!jsc.JSValue
    public static func injectStdioReadError(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // TODO(bao-runtime-api): 实现错误注入
        JsValue.jsBoolean(false)
    }
}
