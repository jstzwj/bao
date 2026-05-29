// 严格翻译自: src/runtime/api/bun/subprocess.rs
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JSGlobalObject, JsValue, JsCallFrame, JsCell, JsPromise, ZigString, ZigException, JsException}
import bao_collections.*
import bao_core.{Allocator, ArenaAllocator, BaoError, Output, defaultAllocator}
import bao_core.ptr.RefCount
import bao_sys.*
import bao_io.{Source as IoSource, SourceKind, Pipe as IoPipe, PipeReader, PipeWriter, PIPE_BUF_SIZE}
import bao_event_loop.{EventLoopTimer, TimerTag, TimerState, Timespec}

// 本地 stub 类型 (原为外部导入，因可见性限制改为本地定义)
public enum SignalCode { | SIGTERM | SIGKILL | SIGINT | SIGHUP | SIGQUIT | SIGUSR1 | SIGUSR2 | SIGSTOP | SIGCONT }
public enum MaxBufKind { | stdout | stderr }
public class FileSinkJSSinkHelper {
    public func fromJS(v: Any): ?FileSink { None }
    public func setDestroyCallback(v: Any, i: Int32): Unit {}
}
public class FileSink {
    public static func JSSink(): FileSinkJSSinkHelper { FileSinkJSSinkHelper() }
    public func close(): Unit {}
}
public class Signal {
    public func clear(): Unit {}
    public init() {}
}

// 本地 stub 类型
public enum ApiStdioKind { | stdin | stdout | stderr }

public class MaxBuf {
    public init() {}
    public static func createForSubprocess(owner: Subprocess, slot: ?MaxBuf, initial: ?Int64): Unit {}
    public static func removeFromSubprocess(slot: ?MaxBuf): Unit {}
    public static func addToPipeReader(limit: ?MaxBuf, readerMaxbuf: Any): Unit {}
}
public class TimerAll {
    public init() {}
    public func incrementTimerRef(delta: Int32, uwsLoop: Any): Unit {}
    public func remove(timer: EventLoopTimer): Unit {}
}
public class CowString {
    public init() {}
    public static func initOwned(s: String): CowString { CowString() }
}
public enum PipeReaderState {
    | pending
    | done(Array<UInt8>)
    | err(SysError)

    public func isPending(): Bool {
        return match (this) {
            case pending => true
            case _ => false
        }
    }

    public func isDone(): Bool {
        return match (this) {
            case done(_) => true
            case _ => false
        }
    }
}

public class JscHooks {
    public static func timerAllMut(): TimerAll { TimerAll() }
}

public class EnumSet<T> {
    public init() {}
    public func insert(value: T): Unit {}
    public func contains(value: T): Bool { false }
}

// ============================================================================
// Subprocess - Bun.spawn / Bun.spawnSync 返回的子进程对象
// 对应 Bun: src/runtime/api/bun/subprocess.rs
// ============================================================================

/// 平台相关的 stdio 结果类型
/// 对应 Bun: const StdioResult = if (Environment.isWindows) ... else ?bun.FD
/// Linux/macOS: ?bun.FD (可选文件描述符)
/// 简化为枚举类型。[MIGRATED] 迁移到使用 ?Int64 (可选文件描述符)
public enum StdioResult {
    | owned       // FD 拥有权归此进程
    | unowned     // FD 不归此进程管理
    | unavailable // FD 不可用
}

/// MaxBuf 类型别名 - MaxBufKind 已在 bao_io 中定义

// StaticPipeWriter 已通过 import 导入，无需重复定义

/// ObservableGetter - 标记哪些 getter 已被调用
public enum ObservableGetter {
    | stdin
    | stdout
    | stderr
}

/// 子进程对象
public class Subprocess {
    public var refCount: RefCount<Subprocess>
    /// 侵入式引用计数的 Process
    public var process: BackRef<Process>
    public var stdin: Writable
    public var stdout: Readable
    public var stderr: Readable
    public var stdioPipes: ArrayList<StdioPipeItem>
    public var pidRusage: ?Rusage

    /// 附加到此子进程的终端 (如果使用 terminal 选项)
    public var terminal: ?Terminal

    /// JSC 全局对象 (生命周期长于 Subprocess)
    public var globalThis: BackRef<JsGlobalObject>
    public var observableGetters: EnumSet<ObservableGetter>
    public var closed: EnumSet<ApiStdioKind>
    public var thisValue: JsRef

    /// IPC 数据，null 表示未初始化
    public var ipcData: ?IPCSendQueue
    public var flags: Flags

    /// stdin 的弱引用 FileSink
    public var weakFileSinkStdinPtr: ?FileSink
    /// abort signal 的 +1 侵入式引用
    public var abortSignal: ?AbortSignal

    public var eventLoopTimerRefd: Bool = false
    /// 侵入式定时器节点
    public var eventLoopTimer: EventLoopTimer = EventLoopTimer(TimerTag.SubprocessTimeout)
    public var killSignal: SignalCode

    public var stdoutMaxbuf: ?MaxBuf
    public var stderrMaxbuf: ?MaxBuf
    public var exitedDueToMaxbuf: ?MaxBufKind

    // ========================================================================
    // Flags - 子进程标志位
    // ========================================================================

//    public class Flags {
//        public static let IS_SYNC: UInt8 = 1 << 0
//        public static let KILLED: UInt8 = 1 << 1
//        public static let HAS_STDIN_DESTRUCTOR_CALLED: UInt8 = 1 << 2
//        public static let FINALIZED: UInt8 = 1 << 3
//        public static let DEREF_ON_STDIN_DESTROYED: UInt8 = 1 << 4
//        public static let IS_STDIN_A_READABLE_STREAM: UInt8 = 1 << 5
//        /// 终端由 spawn 内联创建 (vs. 调用者传入的现有 Terminal)
//        public static let OWNS_TERMINAL: UInt8 = 1 << 6

//        public var bits: UInt8 = 0

//        public func contains(flag!: UInt8): Bool {
//            return (this.bits & flag) != 0
//        }

//        public func insert(flag!: UInt8) {
//            this.bits = this.bits | flag
//        }

//        public func remove(flag!: UInt8) {
//            this.bits = this.bits & ~flag
//        }

//        public func `get`(): UInt8 {
//            return this.bits
//        }

//        public func `set`(bits!: UInt8) {
//            this.bits = bits
//        }

//        // 便捷属性
//        public prop isSync!: Bool {
//            get() { this.contains(Flags.IS_SYNC) }
//            set(v) { if (v) { this.insert(Flags.IS_SYNC) } else { this.remove(Flags.IS_SYNC) } }
//        }
//        public prop killed!: Bool {
//            get() { this.contains(Flags.KILLED) }
//            set(v) { if (v) { this.insert(Flags.KILLED) } else { this.remove(Flags.KILLED) } }
//        }
//        public prop hasStdinDestructorCalled!: Bool {
//            get() { this.contains(Flags.HAS_STDIN_DESTRUCTOR_CALLED) }
//            set(v) { if (v) { this.insert(Flags.HAS_STDIN_DESTRUCTOR_CALLED) } else { this.remove(Flags.HAS_STDIN_DESTRUCTOR_CALLED) } }
//        }
//        public prop finalized!: Bool {
//            get() { this.contains(Flags.FINALIZED) }
//            set(v) { if (v) { this.insert(Flags.FINALIZED) } else { this.remove(Flags.FINALIZED) } }
//        }
//        public prop derefOnStdinDestroyed!: Bool {
//            get() { this.contains(Flags.DEREF_ON_STDIN_DESTROYED) }
//            set(v) { if (v) { this.insert(Flags.DEREF_ON_STDIN_DESTROYED) } else { this.remove(Flags.DEREF_ON_STDIN_DESTROYED) } }
//        }
//        public prop isStdinAReadableStream!: Bool {
//            get() { this.contains(Flags.IS_STDIN_A_READABLE_STREAM) }
//            set(v) { if (v) { this.insert(Flags.IS_STDIN_A_READABLE_STREAM) } else { this.remove(Flags.IS_STDIN_A_READABLE_STREAM) } }
//        }
//        public prop ownsTerminal!: Bool {
//            get() { this.contains(Flags.OWNS_TERMINAL) }
//            set(v) { if (v) { this.insert(Flags.OWNS_TERMINAL) } else { this.remove(Flags.OWNS_TERMINAL) } }
//        }
//    }

    // ========================================================================
    // StdioKind - 标准流类型枚举
    // ========================================================================

//    public enum StdioKind {
//        | stdin
//        | stdout
//        | stderr

//        public func toFd(): FD {
//            return match (this) {
//                case stdin => FD.stdin()
//                case stdout => FD.stdout()
//                case stderr => FD.stderr()
//            }
//        }

//        public func toNum(): Int32 {
//            return match (this) {
//                case stdin => 0
//                case stdout => 1
//                case stderr => 2
//            }
//        }
//    }

    // ========================================================================
    // Source - stdin 数据源
    // ========================================================================

//    public enum Source {
//        | blob(BlobAny)
//        | array_buffer(ArrayBufferStrong)
//        | detached

//        public func memoryCost(): Int64 {
//            return match (this) {
//                case blob => this.blob.memoryCost()
//                case array_buffer => 0
//                case detached => 0
//            }
//        }

//        public func slice(): Array<UInt8> {
//            return match (this) {
//                case blob => this.blob.slice()
//                case array_buffer => this.array_buffer.slice()
//                case _ => panic("Invalid source")
//            }
//        }

//        public func detach() {
//            match (this) {
//                case blob => this.blob.detach()
//                case array_buffer => this.array_buffer.deinit()
//                case _ => ()
//            }
//            this = .detached
//        }
//    }

    // ========================================================================
    // Poll - 轮询 (保持与 Bun 对等, 可能是死代码)
    // ========================================================================

    /// Poll - 轮询机制 (posix FilePoll / windows WaitThread)
//    public enum Poll {
//        | pollRef(?FilePoll)
//        | waitThread(WaitThreadPoll)
//    }

    /// WaitThreadPoll - 等待线程轮询
//    public class WaitThreadPoll {
//        public var refCount: AtomicUInt32
//        public var pollRef: KeepAlive

//        public init() {
//            this.refCount = AtomicUInt32(0)
//            this.pollRef = KeepAlive()
//        }
//    }

    // ========================================================================
    // 核心方法
    // ========================================================================

    /// 调试断言 stdio 结果格式正确
    public static func assertStdioResult(result!: StdioResult) {
        if (Environment.isDebug) {
            if (let fd <- result) {
                assert(fd.isValid())
            }
        }
    }

    /// 借用侵入式引用计数的 Process
    public func getProcess(): Process {
        return this.process.get()
    }

    /// 可变借用 Process
    public func processMut(): Process {
        return this.process.asPtr().pointee
    }

    /// 借用存储的 JSC 全局对象
    public func getGlobalThis(): JsGlobalObject {
        return this.globalThis.get()
    }

    /// self 的地址作为 *Self, 用于 C 回调上下文
    public func asCtxPtr(): Subprocess {
        return this
    }

    /// 通过 &self 读写修改打包的 Flags
    public func updateFlags(f: (Flags) -> Unit) {
        let v = this.flags
        f(v)
        this.flags = v
    }

    /// 侵入式 ref()
    public func ref() {
        RefCount<Subprocess>.ref(this)
    }

    /// 侵入式 deref() - 可能释放 self, 调用后不要使用 self
    public func deref() {
        RefCount<Subprocess>.deref(this)
    }

    /// 内存占用
    public func memoryCost(): Int64 {
        return sizeof(Subprocess) +
            this.getProcess().memoryCost() +
            this.stdin.memoryCost() +
            this.stdout.memoryCost() +
            this.stderr.memoryCost()
    }

    /// 是否已退出
    public func hasExited(): Bool {
        return this.getProcess().hasExited()
    }

    /// 计算是否有待处理的活动
    public func computeHasPendingActivity(): Bool {
        // `ipc_data` 在初始化后不会设置回 None, 所以仅检查 is_some()
        // 会保持 JSSubprocess 在 VM 生命周期内被强引用。
        // IPC 端在 `_onAfterIPCClosed` 实际运行之前贡献待处理活动:
        // 通过 `close_event_sent` (而非 `socket != closed`) 进行门控,
        // 以在 socket 已经 `.closed` 但持有原始 `*SendQueue` 的任务
        // 仍排队的窗口期间保持 wrapper 为 Strong。
        if (let ipc <- this.ipcData) {
            if (!ipc.closeEventSent) {
                return true
            }
        }

        if (this.hasPendingActivityStdio()) {
            return true
        }

        if (!this.getProcess().hasExited()) {
            return true
        }

        return false
    }

    /// 更新待处理活动状态
    public func updateHasPendingActivity() {
        if (this.flags.isSync) {
            return
        }

        let hasPending = this.computeHasPendingActivity()

        // 根据待处理活动升级或降级引用
        if (hasPending) {
            let globalThis = this.globalThis
            this.thisValue.upgrade(globalThis)
        } else {
            this.thisValue.downgrade()
        }
    }

    /// Stdio 是否有待处理活动
    public func hasPendingActivityStdio(): Bool {
        if (this.stdin.hasPendingActivity()) {
            return true
        }

        // PERF: 原始代码内联展开 stdout 和 stderr
        if (this.stdout.hasPendingActivity()) {
            return true
        }
        if (this.stderr.hasPendingActivity()) {
            return true
        }

        return false
    }

    /// 关闭 IO 回调
    public func onCloseIO(kind!: ApiStdioKind) {
        match (kind) {
            case stdin =>
                match (this.stdin) {
                    case pipe(pipe) =>
                        // signal 是 JsCell, 所以共享的 &FileSink 就足够了
                        pipe.signal.clear()
                        this.stdin = Writable.ignore()
                        // Writable::Pipe 持有一个侵入式引用; 现在释放它
                        pipe.deref()
                    case buffer(buffer) =>
                        buffer.source.detach()
                        this.stdin = Writable.ignore()
                    case _ => ()
                }
            case stdout =>
                let out: Readable = if (kind == stdout) {
                    this.stdout
                } else {
                    this.stderr
                }

                match (out) {
                    case pipe(pipe) =>
                        let pipeState = pipe.reader.state
                        match (pipeState) {
                            case done(bytes) => this.stdout = Readable.buffer(bytes)
                            case _ => ()
                        }
                        this.stdout = Readable.ignore
                        pipe.deref()
                    case _ => ()
                }
            case stderr =>
                let out: Readable = if (kind == stdout) {
                    this.stdout
                } else {
                    this.stderr
                }

                match (out) {
                    case pipe(pipe) =>
                        let pipeState = pipe.reader.state
                        match (pipeState) {
                            case done(bytes) => this.stderr = Readable.buffer(bytes)
                            case _ => ()
                        }
                        this.stderr = Readable.ignore
                        pipe.deref()
                    case _ => ()
                }
        }

        // 当进程在 stdout/stderr 管道完成排空前退出时,
        // onProcessExit 的延迟 updateHasPendingActivity() 观察到管道仍有待处理
        // 并保持 `this_value` 为 Strong。当管道随后完成并到达此处时,
        // 我们必须重新评估, 以便 JsRef 可以被降级,
        // 并且 JSSubprocess + 缓冲输出变得可收集。
        this.updateHasPendingActivity()
    }

    /// JS ref
    public func jsRef() {
        this.processMut().enableKeepingEventLoopAlive()

        if (!this.hasCalledGetter(ObservableGetter.stdin)) {
            this.stdin.ref()
        }

        if (!this.hasCalledGetter(ObservableGetter.stdout)) {
            this.stdout.ref()
        }

        if (!this.hasCalledGetter(ObservableGetter.stderr)) {
            this.stderr.ref()
        }

        this.updateHasPendingActivity()
    }

    /// JS unref - 禁用保持进程活动标志以及 stdin, stdout, stderr 中的标志
    public func jsUnref() {
        this.processMut().disableKeepingEventLoopAlive()

        if (!this.hasCalledGetter(ObservableGetter.stdin)) {
            this.stdin.unref()
        }

        if (!this.hasCalledGetter(ObservableGetter.stdout)) {
            this.stdout.unref()
        }

        if (!this.hasCalledGetter(ObservableGetter.stderr)) {
            this.stderr.unref()
        }

        this.updateHasPendingActivity()
    }

    /// 构造函数 (禁止直接构造)
    public static func constructor(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): Subprocess {
        return globalObject.`throw`("Cannot construct Subprocess")
    }

    // ========================================================================
    // Getter 方法
    // ========================================================================

    /// 获取 stderr
    public func getStderr(globalThis!: JsGlobalObject): JsValue {
        // 使用 terminal 时, stderr 通过终端
        if (this.terminal != none) {
            return JsValue.null()
        }
        this.observableGetters.insert(ObservableGetter.stderr)
        let exited = this.hasExited()
        return this.stderr.toJS(globalThis, exited)
    }

    /// 获取 stdin
    public func getStdin(globalThis!: JsGlobalObject): JsValue {
        // 使用 terminal 时, stdin 通过终端
        if (this.terminal != none) {
            return JsValue.null()
        }
        this.observableGetters.insert(ObservableGetter.stdin)
        return Writable.toJS(this, globalThis)
    }

    /// 获取 stdout
    public func getStdout(globalThis!: JsGlobalObject): JsValue {
        // 使用 terminal 时, stdout 通过终端
        if (this.terminal != none) {
            return JsValue.null()
        }
        this.observableGetters.insert(ObservableGetter.stdout)
        let exited = this.hasExited()
        return this.stdout.toJS(globalThis, exited)
    }

    /// 获取 terminal
    public func getTerminal(globalThis!: JsGlobalObject): JsValue {
        if (let terminal <- this.terminal) {
            return terminal.toJS(globalThis)
        }
        return JsValue.jsUndefined()
    }

    /// 获取 PID 值
    public func pid(): Int32 {
        return Int32(this.getProcess().pid)
    }

    /// 获取 PID
    public func getPid(globalThis!: JsGlobalObject): JsValue {
        return JsValue.jsNumber(this.pid())
    }

    /// 是否已被杀死
    public func hasKilled(): Bool {
        return this.getProcess().hasKilled()
    }

    /// 获取 killed 状态
    public func getKilled(globalThis!: JsGlobalObject): JsValue {
        return JsValue.jsBoolean(this.hasKilled())
    }

    /// 获取 stdio 数组
    public func getStdio(global!: JsGlobalObject): JsValue {
        let array = JsValue.createEmptyArray(global, 0) 
        array.push(global, JsValue.null() )
        array.push(global, JsValue.null() )
        array.push(global, JsValue.null() )

        for (item in this.stdioPipes) {
            match (item) {
                case owned_fd(fd) => array.push(global, JsValue.jsNumber(fd.native() ))
                case unowned_fd(fd) => array.push(global, JsValue.jsNumber(fd.native() ))
                case unavailable => array.push(global, JsValue.null() )
            }
        }
        return array
    }

    /// 获取 resource usage
    public func resourceUsage(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return this.createResourceUsageObject(globalObject)
    }

    /// 创建 resource usage JS 对象
    public func createResourceUsageObject(jsGlobalObject!: JsGlobalObject): JsValue {
        let rusage: Rusage
        if (let r <- this.pidRusage) {
            rusage = r
        } else {
            return JsValue.jsUndefined()
        }
        return ResourceUsage.create(rusage, globalObject)
    }

    /// 获取 connected 状态
    public func getConnected(globalThis!: JsGlobalObject): JsValue {
        let connected = if (let d <- this.ipcData) {
            d.isConnected()
        } else {
            false
        }
        return JsValue.jsBoolean(connected)
    }

    /// 获取 exited Promise
    public func getExited(thisValue!: JsValue, globalThis!: JsGlobalObject): JsValue {
        if (let promise <- JSSubprocess.exitedPromiseGetCached(thisValue)) {
            return promise
        }

        match (this.getProcess().status) {
            case exited(exit) =>
                return JSPromise.resolvedPromiseValue(globalThis, JsValue.jsNumber(exit.code))
            case signaled(signal) =>
                return JSPromise.resolvedPromiseValue(
                    globalThis,
                    JsValue.jsNumber(SignalCode(signal).toExitCode() ?? 254),
                )
            case err(err) =>
                let jsErr = try { err.toJS(globalThis) } catch(_: JsException) { return JsValue.jsUndefined() }
                return JSPromise.dangerouslyCreateRejectedPromiseValueWithoutNotifyingVM(globalThis, jsErr)
            case _ =>
                let promise = JsPromise.create(globalThis).toJS()
                JSSubprocess.exitedPromiseSetCached(thisValue, globalThis, promise)
                return promise
        }
    }

    /// 获取退出码
    public func getExitCode(globalThis!: JsGlobalObject): JsValue {
        if (let exited <- this.getProcess().status.`as`(Status.exited)) {
            return JsValue.jsNumber(exited.code)
        }
        return JsValue.jsNull()
    }

    /// 获取信号码
    public func getSignalCode(global!: JsGlobalObject): JsValue {
        if (let signal <- this.getProcess().signalCode()) {
            let sysSig = SignalCode(signal.rawValue)
            if (let name <- sysSig.name()) {
                return ZigString(name).toJS(global)
            } else {
                return JsValue.jsNumber(Int32(signal.rawValue))
            }
        }
        return JsValue.jsNull()
    }

    // ========================================================================
    // 操作方法
    // ========================================================================

    /// 杀死子进程
    public func kill(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        this.thisValue.update(globalThis, callframe.`this`())

        let arguments = callframe.argumentsOld(1)
        // 如果信号为 0, 不发送实际信号, 但仍进行错误检查
        let sig = SignalCode.fromJS(arguments.ptr[0], globalThis) 

        if (globalThis.hasException()) { return JsValue.jsUndefined() }

        match (this.tryKill(sig)) {
            case result => ()
            case err(err) =>
                return globalThis.throwValue(err.toJS(globalThis) )
        }

        return JsValue.jsUndefined()
    }

    /// 尝试杀死子进程
    public func tryKill(sig!: SignalCode): Maybe<Unit> {
        if (this.hasExited()) {
            return Maybe<Unit>.success
        }
        return this.processMut().kill(sig.rawValue)
    }

    /// doRef
    public func doRef(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        this.jsRef()
        return JsValue.jsUndefined()
    }

    /// doUnref
    public func doUnref(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        this.jsUnref()
        return JsValue.jsUndefined()
    }

    /// asyncDispose (用于 using 语法 / [Symbol.asyncDispose])
    public func asyncDispose(global!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        if (this.getProcess().hasExited()) {
            // 在这种情况下依赖 GC 清理所有内容
            return JsValue.jsUndefined()
        }

        let thisJsvalue = callframe.`this`()
        // 保持 JS 值活跃

        // 取消引用流, 以便此已释放的进程不会阻止进程退出导致挂起
        this.stdin.unref()
        this.stdout.unref()
        this.stderr.unref()

        match (this.tryKill(this.killSignal)) {
            case result => ()
            case err(err) =>
                // 信号 9 应该总是有效的, 但以防万一失败
                return global.throwValue(err.toJS(global) )
        }

        return this.getExited(thisJsvalue, global)
    }

    /// 设置事件循环定时器引用
    public func setEventLoopTimerRefd(refd!: Bool) {
        if (this.eventLoopTimerRefd == refd) {
            return
        }
        this.eventLoopTimerRefd = refd
        let uwsLoop = this.getGlobalThis().bunVM().uwsLoop()
        let delta: Int32 = if (refd) { 1 } else { -1 }
        Subprocess.timerAll().incrementTimerRef(delta, uwsLoop)
    }

    /// 获取全局定时器
    public static func timerAll(): TimerAll {
        return JscHooks.timerAllMut()
    }

    /// 超时回调
    public func timeoutCallback() {
        this.setEventLoopTimerRefd(false)
        if (this.eventLoopTimer.state == TimerState.Cancelled) {
            return
        }
        if (this.hasExited()) {
            this.eventLoopTimer.state = TimerState.Cancelled
            return
        }
        this.eventLoopTimer.state = TimerState.Fired
        _ = this.tryKill(this.killSignal)
    }

    /// maxbuf 回调
    public func onMaxBuffer(kind!: MaxBufKind) {
        this.exitedDueToMaxbuf = kind
        _ = this.tryKill(this.killSignal)
    }

    /// abort signal 处理
    public func handleAbortSignal(reason!: JsValue) {
        this.clearAbortSignal()
        _ = this.tryKill(this.killSignal)
    }

    /// abort signal 的 extern "C" 包装器
    public static func onAbortSignal(ctx!: Unit, reason!: JsValue) {
        // ctx 被注册为 *Subprocess
        let subprocess = ctx.`as`(Subprocess)
        subprocess.handleAbortSignal(reason)
    }

    /// stdin 销毁回调
    public func onStdinDestroyed() {
        let mustDeref = this.flags.derefOnStdinDestroyed
        this.updateFlags({ f =>
            f.remove(Flags.DEREF_ON_STDIN_DESTROYED)
            f.insert(Flags.HAS_STDIN_DESTRUCTOR_CALLED)
        })
        this.weakFileSinkStdinPtr = none

        if (!this.flags.finalized) {
            // 否则更新待处理活动标志
            this.updateHasPendingActivity()
        }

        // Zig `defer if (must_deref) this.deref()` — 上面没有提前返回,
        // 所以最后运行就是精确的 LIFO 顺序。
        if (mustDeref) {
            this.deref()
        }
    }

    /// IPC 发送
    public func doSend(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let context = if (this.hasExited()) {
            FromEnum.SubprocessExited
        } else {
            FromEnum.Subprocess
        }
        // `ipc()` 集中化唯一的 unsafe JsCell 解引用; `do_send` 可能
        // 重新进入 JS, 但只借用 SendQueue, 而非 `*self`。
        return IPC.doSend(this.ipc(), global, callFrame, context)
    }

    /// 断开 IPC
    public func disconnectIPC(nextTick!: Bool) {
        let ipcData = this.ipc() ?? return
        ipcData.closeSocketNextTick(nextTick)
    }

    /// disconnect 方法
    public func disconnect(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        this.disconnectIPC(true)
        return JsValue.jsUndefined()
    }

    /// 获取 abort signal 的共享借用
    public func abortSignalRef(): ?BackRef<AbortSignal> {
        if (let signal <- this.abortSignal) {
            return BackRef<AbortSignal>.from(signal)
        }
        return none
    }

    /// 获取 IPC 数据
    public func ipc(): ?IPCSendQueue {
        return this.ipcData
    }

    /// 获取全局对象 (可选版本)
    public func getGlobalThisOptional(): ?JsGlobalObject {
        return Some(this.globalThis.get())
    }

    // ========================================================================
    // 进程退出回调
    // ========================================================================

    /// 进程退出时的回调
    public func onProcessExit(process!: Process, status!: Status, rusage!: Rusage) {
        let thisJsvalue = this.thisValue.tryGet() ?? JsValue.jsUndefined()
        // 复制 BackRef, 以便 &JSGlobalObject 借用与 &self 分离
        let globalThis = this.globalThis
        let globalThisRef = globalThis.get()
        let jscVm = globalThisRef.bunVM()
        thisJsvalue.ensureStillAlive()
        this.pidRusage = rusage
        let isSync = this.flags.isSync
        this.clearAbortSignal()

        // defer this.deref()
        // defer this.disconnectIPC(true)
        // R-2: 现在两者都接受 &self, scopeguard 不再会别名 —
        // 目前在尾部保持显式 (此体中没有提前返回)。

        if (this.eventLoopTimer.state == TimerState.Active) {
            Subprocess.timerAll().remove(this.eventLoopTimer)
        }
        this.setEventLoopTimerRefd(false)

        jscVm.onSubprocessExit(process)

        // Windows: 如果拥有终端, 在子进程退出时关闭伪控制台
        if (this.flags.ownsTerminal) {
            if (let terminal <- this.terminal) {
                terminal.closePseudoconsole()
            }
        }

        var stdin: ?FileSink = none
        if (this.flags.isStdinAReadableStream) {
            match (this.stdin) {
                case Writable.pipe(p) => stdin = Some(p)
                case _ => ()
            }
        } else {
            stdin = this.weakFileSinkStdinPtr
        }
        var existingStdinValue = JsValue.jsUndefined()
        if (!thisJsvalue.isEmpty()) {
            if (let existingValue <- JSSubprocess.stdinGetCached(thisJsvalue)) {
                if (existingValue.isCell()) {
                    if (stdin == none) {
                        stdin = FileSink.JSSink.fromJS(existingValue)
                    }

                    if (!this.flags.isStdinAReadableStream) {
                        existingStdinValue = existingValue
                    }
                }
            }
        }

        // 我们不会再发送任何数据了
        match (this.stdin) {
            case Writable.buffer(b) => b.close()
            case _ => ()
        }

        if (!existingStdinValue.isEmpty()) {
            FileSink.JSSink.setDestroyCallback(existingStdinValue, 0)
        }

        if (this.flags.isSync) {
            // 这与 Node.js 的行为不匹配, 但对于同步子进程,
            // 流不应该保持计时器运行。
            match (this.stdout) {
                case pipe(_) => this.stdout.close()
                case _ => ()
            }

            match (this.stderr) {
                case pipe(_) => this.stderr.close()
                case _ => ()
            }
        } else {
            // 这与 Node.js 的行为匹配。Node 在流上调用 resume()。
            match (this.stdout) {
                case pipe(pipe) =>
                    if (!pipe.reader.isDone()) {
                        pipe.reader.read()
                    }
                case _ => ()
            }

            match (this.stderr) {
                case pipe(pipe) =>
                    if (!pipe.reader.isDone()) {
                        pipe.reader.read()
                    }
                case _ => ()
            }
        }

        if (let pipePtr <- stdin) {
            this.weakFileSinkStdinPtr = none
            this.updateFlags({ f => f.insert(Flags.HAS_STDIN_DESTRUCTOR_CALLED) })

            let pipe = BackRef<FileSink>.from(pipePtr)

            // `onAttachedProcessExit()` → `writer.close()` → `FileSink.onClose`
            // 在 POSIX 上同步触发 `pipe.signal`。当信号仍指向 `&self.stdin` 时
            // (用户从未读取 `.stdin`, 或读取了但 `Writable.toJS` 保持其连接),
            // 那会重新进入 `Writable.onClose` → `pipe.deref()`,
            // 而 `onAttachedProcessExit` 仍在 `pipe` 上运行。
            // 先分离信号并自行驱动 `onStdinDestroyed()` 的 deref;
            // 这也使 `self.stdin` 保持为 `.pipe`, 以便退出后读取 `.stdin`
            // 仍返回 sink。
            if (pipe.signal.get().ptr == this.asCtxPtr()) {
                pipe.signal.clear()
            }
            let mustDeref = this.flags.derefOnStdinDestroyed
            this.updateFlags({ f => f.remove(Flags.DEREF_ON_STDIN_DESTROYED) })

            FileSink.onAttachedProcessExit(pipePtr, status)

            if (mustDeref) {
                this.deref()
            }
        }

        var didUpdateHasPendingActivity = false

        let eventLoop = jscVm.eventLoop()

        if (!isSync) {
            if (!thisJsvalue.isEmpty()) {
                if (let promise <- consumeExitedPromise(thisJsvalue, globalThisRef)) {
                    let _exitGuard = EventLoop.enterScope(eventLoop)

                    if (!didUpdateHasPendingActivity) {
                        this.updateHasPendingActivity()
                        didUpdateHasPendingActivity = true
                    }

                    match (status) {
                        case exited(exited) =>
                            _ = promise.asAnyPromise().resolve(globalThisRef, JsValue.jsNumber(exited.code))
                        case err(err) =>
                            let jsErr = err.toJS(globalThisRef)
                            _ = promise.asAnyPromise().rejectWithAsyncStack(globalThisRef, jsErr)
                        case signaled(signaled) =>
                            _ = promise.asAnyPromise().resolve(
                                globalThisRef,
                                JsValue.jsNumber(128 + signaled),
                            )
                        case _ =>
                            // 在 debug 模式下崩溃
                            if (Environment.isDebug) {
                                unreachable()
                            }
                    }
                }

                if (let callback <- consumeOnExitCallback(thisJsvalue, globalThisRef)) {
                    let waitpidValue: JsValue = if (let err <- status.`as`(Status.err)) {
                        err.toJS(globalThisRef)
                    } else {
                        JsValue.jsUndefined()
                    }

                    let thisValue: JsValue = if (thisJsvalue.isEmptyOrUndefinedOrNull()) {
                        JsValue.jsUndefined()
                    } else {
                        thisJsvalue
                    }
                    thisValue.ensureStillAlive()

                    let args = [
                        thisValue,
                        this.getExitCode(globalThisRef),
                        this.getSignalCode(globalThisRef),
                        waitpidValue
                    ]

                    if (!didUpdateHasPendingActivity) {
                        this.updateHasPendingActivity()
                        didUpdateHasPendingActivity = true
                    }

                    eventLoop.runCallback(callback, globalThisRef, thisValue, args)
                }
            }
        }

        // defer if (!did_update_has_pending_activity) this.updateHasPendingActivity()
        if (!didUpdateHasPendingActivity) {
            this.updateHasPendingActivity()
        }
        // defer this.disconnectIPC(true)
        this.disconnectIPC(true)
        // defer this.deref()
        this.deref()
    }

    // ========================================================================
    // IO 关闭与终结
    // ========================================================================

    /// 关闭 IO
    public func closeIO(io!: ApiStdioKind) {
        if (this.closed.contains(io)) {
            return
        }
        this.closed.insert(io)

        // 如果你从未引用过 stdout/stderr, 它们不会被垃圾回收。
        //
        // 这意味着:
        //   1. 我们需要停止监视它们
        //   2. 我们需要释放内存
        //   3. 我们需要停止任何待处理的读取 (1)

        let getter = match (io) {
            case stdin => ObservableGetter.stdin
            case stdout => ObservableGetter.stdout
            case stderr => ObservableGetter.stderr
        }
        let called = this.hasCalledGetter(getter)

        match (io) {
            case stdin =>
                if (!called) {
                    Writable.finalize(this)
                } else {
                    this.stdin.close()
                }
            case stdout =>
                if (!called) {
                    this.stdout.finalize()
                } else {
                    this.stdout.close()
                }
            case stderr =>
                if (!called) {
                    this.stderr.finalize()
                } else {
                    this.stderr.close()
                }
        }
    }

    /// 终结流 - 每个 Subprocess 只能运行一次
    public func finalizeStreams() {
        this.closeProcess()

        this.closeIO(ApiStdioKind.stdin)
        this.closeIO(ApiStdioKind.stdout)
        this.closeIO(ApiStdioKind.stderr)

        // POSIX: 关闭拥有的 fd
        for (item in this.stdioPipes) {
            match (item) {
                case owned_fd(fd) => fd.close()
                case unowned_fd => ()
                case unavailable => ()
            }
        }
        this.stdioPipes.clear()
        this.stdioPipes.shrinkToFit()
    }

    /// 关闭进程资源 (仅 Linux/Android)
    public func closeProcess() {
        if (!Environment.isLinux) {
            return
        }
        this.processMut().close()
    }

    /// 是否已调用 getter
    public func hasCalledGetter(getter!: ObservableGetter): Bool {
        return this.observableGetters.contains(getter)
    }

    /// 清除 abort signal
    public func clearAbortSignal() {
        if (let signal <- this.abortSignal) {
            this.abortSignal = none
            signal.pendingActivityUnref()
            signal.cleanNativeBindings(this.asCtxPtr())
            signal.unref()
        }
    }

    /// 终结化 (GC finalizer)
    public func finalize() {
        // 引用计数: 尾随的 `this.deref()` 释放 JS wrapper 的 +1;
        // 如果其他引用仍然存在, 分配可能比此调用存活更久,
        // 所以将所有权交还给原始引用计数。
        // 确保任何引用 "this" 值的代码不会尝试在它被释放后访问它
        // 我们无法在终结器期间调用任何访问 GC 值的方法
        this.thisValue.finalize()

        this.clearAbortSignal()

        assert(
            !this.computeHasPendingActivity()
                || VirtualMachine.get().isShuttingDown()
        )
        this.finalizeStreams()

        this.processMut().detach()
        // 匹配 Zig 的 `this.process.deref()`: 现在释放侵入式引用,
        // 而不是当 `ref_count` → 0 时。
        Process.deref(this.process)

        if (this.eventLoopTimer.state == TimerState.Active) {
            Subprocess.timerAll().remove(this.eventLoopTimer)
        }
        this.setEventLoopTimerRefd(false)

        var mb = this.stdoutMaxbuf
        MaxBuf.removeFromSubprocess(mb)
        this.stdoutMaxbuf = mb
        mb = this.stderrMaxbuf
        MaxBuf.removeFromSubprocess(mb)
        this.stderrMaxbuf = mb

        if (let ipcData <- this.ipcData) {
            this.ipcData = none
            // 在正常操作中, socket 在我们到达这里时已经 `.closed`
            // (这就是允许 `computeHasPendingActivity` 降为 false
            // 并让 GC 收集我们的原因)。在该状态下 `disconnectIPC`
            // 将是无操作并会泄漏 SendQueue 的缓冲区;
            // 改为 deinit 它。`SendQueue.deinit` 处理 VM 关闭的情况,
            // 此时 socket 仍然打开。
            ipcData.deinit()
        }

        this.updateFlags({ f => f.insert(Flags.FINALIZED) })
        this.deref()
    }

    // ========================================================================
    // IPC 消息处理
    // ========================================================================

    /// IPC 消息处理
    public func handleIPCMessage(message!: IPCDecodedIPCMessage, handle!: JsValue) {
        match (message) {
            case version(v) =>
                // 在未来版本中, 我们可以读取此内容以检测版本不匹配,
                // 或者如果子进程较旧则禁用未来的优化。
                ()
            case data(data) =>
                let thisJsvalue = this.thisValue.tryGet() ?? JsValue.jsUndefined()
                // 保持 JS 值活跃
                if (!thisJsvalue.isEmpty()) {
                    if (let cb <- JSSubprocess.ipcCallbackGetCached(thisJsvalue)) {
                        let globalThis = this.getGlobalThis()
                        let eventLoop = globalThis.bunVM().eventLoop()
                        eventLoop.runCallback(
                            cb,
                            globalThis,
                            thisJsvalue,
                            [data, thisJsvalue, handle],
                        )
                    }
                }
            case internal(data) =>
                let globalThis = this.globalThis
                _ = NodeClusterBinding.handleInternalMessagePrimary(
                    globalThis,
                    this,
                    data,
                )
        }
    }

    /// IPC 关闭处理
    public func handleIPCClose() {
        let thisJsvalue = this.thisValue.tryGet() ?? JsValue.jsUndefined()
        // 保持 JS 值活跃
        let globalThis = this.globalThis
        let globalThisRef = globalThis.get()
        this.updateHasPendingActivity()

        if (!thisJsvalue.isEmpty()) {
            // 避免将回调保持存活超过必要时间
            JSSubprocess.ipcCallbackSetCached(thisJsvalue, globalThisRef, JsValue.jsUndefined())

            // 调用 onDisconnectCallback (如果存在) 并防止它被保持存活超过必要时间
            if (let callback <- consumeOnDisconnectCallback(thisJsvalue, globalThisRef)) {
                let eventLoop = globalThisRef.bunVM().eventLoop()
                eventLoop.runCallback(
                    callback,
                    globalThisRef,
                    thisJsvalue,
                    [JsValue.jsBoolean(true)],
                )
            }
        }
    }

    // ========================================================================
    // 静态 spawn 方法
    // ========================================================================

    /// Bun.spawn - 异步创建子进程
    public static func `spawn`(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsBunSpawnBindings.`spawn`(globalThis, callframe)
    }

    /// Bun.spawnSync - 同步创建子进程
    public static func spawnSync(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsBunSpawnBindings.spawnSync(globalThis, callframe)
    }

    // ========================================================================
    // 消费缓存回调
    // ========================================================================

    /// 消费已缓存的 exited Promise
    public static func consumeExitedPromise(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue {
        if (let promise <- JSSubprocess.exitedPromiseGetCached(thisJsvalue)) {
            JSSubprocess.exitedPromiseSetCached(thisJsvalue, globalThis, JsValue.jsUndefined())
            return promise
        }
        return none
    }

    /// 消费已缓存的 onExit 回调
    public static func consumeOnExitCallback(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue {
        if (let callback <- JSSubprocess.onExitCallbackGetCached(thisJsvalue)) {
            JSSubprocess.onExitCallbackSetCached(thisJsvalue, globalThis, JsValue.jsUndefined())
            return callback
        }
        return none
    }

    /// 消费已缓存的 onDisconnect 回调
    public static func consumeOnDisconnectCallback(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue {
        if (let callback <- JSSubprocess.onDisconnectCallbackGetCached(thisJsvalue)) {
            JSSubprocess.onDisconnectCallbackSetCached(thisJsvalue, globalThis, JsValue.jsUndefined())
            return callback
        }
        return none
    }

    // ========================================================================
    // JS 包装器
    // ========================================================================

    /// 将已堆分配的 Subprocess 包装在其 JS cell 中。
    /// `Bun.spawn` 提前装箱, 以便依赖地址的反向指针
    /// (stdin.pipe.signal, MaxBuf owner, IPC owner) 可以在
    /// `subprocess.toJS(globalThis)` 运行前连接好;
    /// 这是避免重新装箱的原始指针入口点。
    public static func toJSFromPtr(ptr!: Subprocess, global!: JsGlobalObject): JsValue {
        return JSSubprocess.toJS(ptr, global)
    }
}

// ============================================================================
// Source 辅助函数
// ============================================================================

/// 从 AnyBlob 创建 Source
public func sourceFromBlob(b!: AnyBlob): IoSource {
    return IoSource(SourceKind.File)
}

/// 从 ArrayBufferStrong 创建 Source
public func sourceFromArrayBuffer(ab!: ArrayBufferStrong): IoSource {
    return IoSource(SourceKind.File)
}

/// ArrayBufferSource - ArrayBuffer 的 SourceData 实现
/// 局部 newtype 以便 SourceData 实现满足一致性
public class ArrayBufferSource {
    public var buffer: ArrayBufferStrong

    public init(buffer: ArrayBufferStrong) {
        this.buffer = buffer
    }

    public func slice(): Array<UInt8> {
        return this.buffer.slice()
    }

    public func detach() {
        // GC 所有; Drop 释放 Strong handle
    }

    public func memoryCost(): Int64 {
        return 0
    }
}

// ============================================================================
// 测试 API
// ============================================================================

/// 测试 API - 注入合成读取错误
public class TestingAPIs {

    /// 注入合成读取错误到子进程的 stdout/stderr PipeReader,
    /// 就像底层 read() 系统调用 (Posix) 或 libuv 读取回调 (Windows) 失败并返回 EBADF。
    /// 测试使用此来锻炼 onReaderError 清理路径,
    /// 该路径否则很难确定性地触发 — 特别是在 Windows 上,
    //  命名管道上的对等端死亡映射到 UV_EOF 而非错误。
    ///
    /// 如果注入了错误则返回 true, 如果给定的 stdio 不是
    /// (或不再是) 缓冲管道读取器则返回 false。
    public static func injectStdioReadError(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let subprocessValue = callframe.argumentsAsArray(2)[0]
        let kindValue = callframe.argumentsAsArray(2)[1]
                let subprocessOpt = Subprocess.fromJS(subprocessValue)
        if (subprocessOpt.isNone()) {
            return globalThis.`throw`("first argument must be a Subprocess")
        }
        let subprocess = subprocessOpt.get()()

        let kindStr = kindValue.toBunString(globalThis) 

        let out: Readable = if (kindStr.eqlComptime("stdout")) {
            subprocess.stdout
        } else if (kindStr.eqlComptime("stderr")) {
            subprocess.stderr
        } else {
            return globalThis.`throw`("second argument must be 'stdout' or 'stderr'")
        }

        match (out) {
            case pipe(pipe) =>
                // 模拟真实错误路径的行为
                let fakeErr = SysError(9, SysTag.Read)
                pipe.onReaderError(fakeErr)
                return JsValue.jsBoolean(true)
            case _ => ()
        }

        return JsValue.jsBoolean(false)
    }
}

/// testing_apis 的别名 (匹配 Bun 的 snake_case 命名)
public type testingAPIs = TestingAPIs

// ============================================================================
// 模块级 assert_stdio_result
// ============================================================================

/// 模块级调试断言 stdio 结果格式正确
public func assertStdioResult(result!: StdioResult) {
    if (Environment.isDebug) {
        if (let fd <- result) {
            assert(fd.isValid())
        }
    }
}
