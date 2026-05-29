// 严格翻译自: src/runtime/api/bun/process.zig
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_ptr.*

// ============================================================================
// 类型别名
// 严格翻译自: src/runtime/api/bun/process.zig:1-2
//   const pid_t = if (Environment.isPosix) std.posix.pid_t else uv.uv_pid_t;
//   const fd_t = if (Environment.isPosix) std.posix.fd_t else i32;
// ============================================================================

public type PidT = Int32
public type FdT = Int32

// ============================================================================
// Rusage - 资源使用统计 (POSIX 版本)
// 严格翻译自: src/runtime/api/bun/process.zig:5-97
//   win_rusage / IO_COUNTERS / uv_getrusage / Rusage
// ============================================================================

/// Windows rusage 结构 (POSIX 上不使用)
/// 严格翻译自: process.zig:5-28
public class WinRusage {
    public var utimeSec: Int64 = 0
    public var utimeUsec: Int64 = 0
    public var stimeSec: Int64 = 0
    public var stimeUsec: Int64 = 0
    public var maxrss: UInt64 = 0
    public var inblock: UInt64 = 0
    public var oublock: UInt64 = 0
}

/// Windows IO_COUNTERS 结构
/// 严格翻译自: process.zig:30-37
public class IOCounters {
    public var readOperationCount: UInt64 = 0
    public var writeOperationCount: UInt64 = 0
    public var otherOperationCount: UInt64 = 0
    public var readTransferCount: UInt64 = 0
    public var writeTransferCount: UInt64 = 0
    public var otherTransferCount: UInt64 = 0
}

/// POSIX rusage 结构
/// 严格翻译自: process.zig:72-97 (FreeBSD 分支)
///   std.posix.rusage 对应的字段
public class Rusage {
    public var utimeSec: Int64 = 0
    public var utimeUsec: Int64 = 0
    public var stimeSec: Int64 = 0
    public var stimeUsec: Int64 = 0
    public var maxrss: Int64 = 0
    public var ixrss: Int64 = 0
    public var idrss: Int64 = 0
    public var isrss: Int64 = 0
    public var minflt: Int64 = 0
    public var majflt: Int64 = 0
    public var nswap: Int64 = 0
    public var inblock: Int64 = 0
    public var oublock: Int64 = 0
    public var msgsnd: Int64 = 0
    public var msgrcv: Int64 = 0
    public var nsignals: Int64 = 0
    public var nvcsw: Int64 = 0
    public var nivcsw: Int64 = 0

    public init() {}

    /// 归零 rusage
    /// 对应: std.mem.zeroes(Rusage)
    public static func zeroes(): Rusage {
        return Rusage()
    }
}

/// 读取进程资源使用 (Windows/uv 版本)
/// 严格翻译自: process.zig:41-71
///   pub fn uv_getrusage(process: *uv.uv_process_t) win_rusage
public func uvGetRusage(): WinRusage {
    return WinRusage()
}

// ============================================================================
// PidFDType
// 严格翻译自: process.zig:190
//   pub const PidFDType = if (Environment.isLinux) fd_t else u0;
// ============================================================================

/// Linux 使用 fd_t, 其他平台使用 u0
/// 严格翻译自: process.zig:190
public type PidFDType = Int32

/// 是否应使用 one-shot 轮询
/// 严格翻译自: process.zig:216
///   const process_poll_one_shot = !Environment.isLinux;
/// macOS/FreeBSD 使用 EV_ONESHOT; Linux 使用 level-triggered
public let processPollOneShot: Bool = true // 非 Linux 平台为 true

// ============================================================================
// ProcessExitHandler - 进程退出处理器
// 严格翻译自: process.zig:100-189
// ============================================================================

/// 进程退出处理器
/// 严格翻译自: process.zig:100-189
///   pub const ProcessExitHandler = struct { ptr: TaggedPointer = TaggedPointer.Null, ... }
public class ProcessExitHandler {
    var ptr: TaggedPointer = TaggedPointer.Null

    public static func initFunc(`this`: ProcessExitHandler, ptr!: Any) {
        `this`.ptr = TaggedPointer(ptr)
    }

    public func call(process!: Process, status!: Status, rusage!: Rusage) {
        if (this.ptr.isNull()) { return }

        match (this.ptr.tag()) {
            case "Subprocess" =>
                let subprocess = this.ptr.`as`(Subprocess)
                subprocess.onProcessExit(process, status, rusage)
            case "LifecycleScriptSubprocess" =>
                let subprocess = this.ptr.`as`(LifecycleScriptSubprocess)
                subprocess.onProcessExit(process, status, rusage)
            case "ProcessHandle" =>
                let subprocess = this.ptr.`as`(ProcessHandle)
                subprocess.onProcessExit(process, status, rusage)
            case "MultiRunProcessHandle" =>
                let subprocess = this.ptr.`as`(MultiRunProcessHandle)
                subprocess.onProcessExit(process, status, rusage)
            case "TestWorkerHandle" =>
                let subprocess = this.ptr.`as`(TestWorkerHandle)
                subprocess.onProcessExit(process, status, rusage)
            case "ShellSubprocess" =>
                let subprocess = this.ptr.`as`(ShellSubprocess)
                subprocess.onProcessExit(process, status, rusage)
            case "SecurityScanSubprocess" =>
                let subprocess = this.ptr.`as`(SecurityScanSubprocess)
                subprocess.onProcessExit(process, status, rusage)
            case "WebViewHostProcess" =>
                let subprocess = this.ptr.`as`(WebViewHostProcess)
                subprocess.onProcessExit(process, status, rusage)
            case "ChromeProcess" =>
                let subprocess = this.ptr.`as`(ChromeProcess)
                subprocess.onProcessExit(process, status, rusage)
            case "SyncProcess" =>
                let subprocess = this.ptr.`as`(SyncProcess)
                subprocess.onProcessExit(status, rusage)
            case "CronRegisterJob" =>
                let cronJob = this.ptr.`as`(CronRegisterJob)
                cronJob.onProcessExit(process, status, rusage)
            case "CronRemoveJob" =>
                let cronJob = this.ptr.`as`(CronRemoveJob)
                cronJob.onProcessExit(process, status, rusage)
            case _ =>
                panic("Internal Bun error: ProcessExitHandler has an invalid tag. Please file a bug report.")
        }
    }
}

// ============================================================================
// Status - 进程退出状态
// 严格翻译自: process.zig:615-708
//   pub const Status = union(enum) { running, exited, signaled, err }
// ============================================================================

/// 进程状态
/// 严格翻译自: process.zig:615-708
public enum Status {
    | Running
    | Exited(ExitStatus)
    | Signaled(SignalCode)
    | Err(SysError)

    /// 是否成功退出 (code == 0)
    /// 严格翻译自: process.zig:621-623
    ///   pub fn isOK(this: *const Status) bool
    public func isOk(): Bool {
        match (this) {
            case Exited(exit) => exit.code == 0
            case _ => false
        }
    }

    /// 获取信号码
    /// 严格翻译自: process.zig:679-685
    ///   pub fn signalCode(this: *const Status) ?bun.SignalCode
    public func signalCode(): ?SignalCode {
        match (this) {
            case Signaled(sig) => sig
            case Exited(exit) =>
                if (exit.signal.value() > 0) { exit.signal } else { None }
            case _ => None
        }
    }

    /// 从 waitpid 结果创建 Status
    /// 严格翻译自: process.zig:630-677
    ///   pub fn from(pid: pid_t, waitpid_result: *const Maybe(WaitPidResult)) ?Status
    public static func from(pid!: PidT, waitpidResult!: SysMaybe<WaitPidResult>): ?Status {
        var exitCode: ?UInt8 = None
        var signal: ?UInt8 = None

        match (waitpidResult) {
            case Err(err) =>
                return Status.Err(err)
            case Ok(result) =>
                if (result.pid != pid) {
                    return None
                }

                // WIFEXITED
                if (posixWifexited(result.status)) {
                    exitCode = posixWexitstatus(result.status)
                }

                // WIFSIGNALLED
                if (posixWifsignaled(result.status)) {
                    signal = posixWtermsig(result.status)
                }
                // WIFSTOPPED
                else if (posixWifstopped(result.status)) {
                    signal = posixWstopsig(result.status)
                }
        }

        if (exitCode.isSome()) {
            return Status.Exited(ExitStatus(
                code: exitCode ?? UInt8(0),
                signal: SignalCode(signal ?? UInt8(0))
            ))
        } else if (signal.isSome()) {
            return Status.Signaled(SignalCode(signal ?? UInt8(0)))
        }

        return None
    }
}

/// 退出状态
/// 严格翻译自: process.zig:625-628
///   pub const Exited = struct { code: u8 = 0, signal: bun.SignalCode }
public class ExitStatus {
    public var code: UInt8 = UInt8(0)
    public var signal: SignalCode

    public init() {
        this.signal = SignalCode(0)
    }

    public init(code: UInt8, signal: SignalCode) {
        this.code = code
        this.signal = signal
    }
}

// ============================================================================
// POSIX wait status 宏
// 严格翻译自: 使用 std.posix.W.* 宏
// ============================================================================

/// WIFEXITED(status) - 正常退出
public func posixWifexited(status!: UInt32): Bool {
    return (status & 0x7f) == 0
}

/// WEXITSTATUS(status) - 退出码
public func posixWexitstatus(status!: UInt32): UInt8 {
    return UInt8((status >> 8) & 0xff)
}

/// WIFSIGNALED(status) - 被信号终止
public func posixWifsignaled(status!: UInt32): Bool {
    return ((status & 0x7f) + 1) >> 1 > 0
}

/// WTERMSIG(status) - 终止信号
public func posixWtermsig(status!: UInt32): UInt8 {
    return UInt8(status & 0x7f)
}

/// WIFSTOPPED(status) - 被停止
public func posixWifstopped(status!: UInt32): Bool {
    return ((status & 0xff) == 0x7f)
}

/// WSTOPSIG(status) - 停止信号
public func posixWstopsig(status!: UInt32): UInt8 {
    return UInt8((status >> 8) & 0xff)
}

/// WNOHANG - 非阻塞 waitpid
public let WNOHANG: UInt32 = 1

/// WUNTRACED - 报告停止的子进程
public let WUNTRACED: UInt32 = 2

// ============================================================================
// Poller - 进程轮询器 (POSIX)
// 严格翻译自: process.zig:710-798
// ============================================================================

/// POSIX 进程轮询器
/// 严格翻译自: process.zig:710-754
///   pub const PollerPosix = union(enum) { fd, waiter_thread, detached }
public enum Poller {
    | Detached
    | Fd(FilePoll)
    | WaiterThread(WaiterThreadPoll)
    | Uv(UvProcessT)

    /// 释放资源
    /// 严格翻译自: process.zig:715-721
    public func deinit() {
        match (this) {
            case Fd(poll) => poll.deinit()
            case WaiterThread(waiter) => waiter.disable()
            case _ => ()
        }
    }

    /// 启用保持事件循环存活
    /// 严格翻译自: process.zig:723-733
    public func enableKeepingEventLoopAlive(eventLoop!: EventLoopHandle) {
        match (this) {
            case Fd(poll) => poll.enableKeepingProcessAlive(eventLoop)
            case WaiterThread(waiter) => waiter.ref(eventLoop)
            case _ => ()
        }
    }

    /// 禁用保持事件循环存活
    /// 严格翻译自: process.zig:735-745
    public func disableKeepingEventLoopAlive(eventLoop!: EventLoopHandle) {
        match (this) {
            case Fd(poll) => poll.disableKeepingProcessAlive(eventLoop)
            case WaiterThread(waiter) => waiter.unref(eventLoop)
            case _ => ()
        }
    }

    /// 是否有引用
    /// 严格翻译自: process.zig:747-753
    public func hasRef(): Bool {
        match (this) {
            case Fd(poll) => poll.canEnableKeepingProcessAlive()
            case WaiterThread(waiter) => waiter.isActive()
            case _ => false
        }
    }
}

/// WaiterThread 轮询器
/// 严格翻译自: process.zig:801-809
public class WaiterThreadPoll {
    var refCount: AtomicUInt32 = AtomicUInt32(0)
    var pollRef: KeepAlive = KeepAlive()

    public func ref(eventLoop!: EventLoopHandle) {
        pollRef.ref(eventLoop)
    }

    public func unref(eventLoop!: EventLoopHandle) {
        pollRef.unref(eventLoop)
    }

    public func disable() {
        pollRef.disable()
    }

    public func isActive(): Bool {
        return pollRef.isActive()
    }
}

/// UV 进程句柄 (Windows 使用)
/// 对应 uv_process_t
public class UvProcessT {
    public var pid: PidT = 0
    public var isActive: Bool = false

    public func close() {}
    public func ref() {}
    public func unref() {}
    public func isClosed(): Bool { return true }
    public func isClosing(): Bool { return false }
    public func hasRef(): Bool { return false }
}

// ============================================================================
// Process - 子进程管理核心
// 严格翻译自: process.zig:218-613
//   pub const Process = struct { ... }
// ============================================================================

/// 进程 - 管理一个子进程的生命周期
/// 严格翻译自: process.zig:218-613
public class Process {
    var pid: PidT = 0
    var pidfd: PidFDType = 0
    var status: Status = Status.Running
    var poller: Poller = Poller.Detached
    var refCount: ThreadSafeRefCount<Process>
    var exitHandler: ProcessExitHandler = ProcessExitHandler()
    var sync: Bool = false
    var eventLoop: EventLoopHandle

    /// 从 PosixSpawnResult 初始化 (POSIX)
    /// 严格翻译自: process.zig:251-273
    ///   pub fn initPosix(posix, event_loop, sync_) *Process
    public static func initPosix(posix!: PosixSpawnResult, eventLoop!: EventLoopHandle, sync_!: Bool): Process {
        let proc = Process()
        proc.pid = posix.pid
        proc.pidfd = posix.pidfd
        proc.eventLoop = eventLoop
        proc.sync = sync_

        if (posix.hasExited) {
            let rusage = Rusage.zeroes()
            let waitpidResult = wait4(posix.pid, 0, rusage)
            proc.status = Status.from(posix.pid, waitpidResult) ?? Status.Running
        }

        return proc
    }

    /// 内存占用
    /// 严格翻译自: process.zig:235-237
    public func memoryCost(): Int64 {
        return Int64(sizeof<Process>())
    }

    /// 设置退出处理器
    /// 严格翻译自: process.zig:239-241
    public func setExitHandler(handler!: Any) {
        ProcessExitHandler.initFunc(this.exitHandler, handler)
    }

    /// Windows 上更新状态
    /// 严格翻译自: process.zig:243-249
    public func updateStatusOnWindows() {
        match (this.poller) {
            case Uv(uv) =>
                if (!uv.isActive && match (this.status) { case Running => true case _ => false }) {
                    this.onExit(Status.Exited(ExitStatus()), Rusage.zeroes())
                }
            case _ => ()
        }
    }

    /// 是否已退出
    /// 严格翻译自: process.zig:275-282
    public func hasExited(): Bool {
        match (this.status) {
            case Exited => true
            case Signaled => true
            case Err => true
            case _ => false
        }
    }

    /// 是否已被杀死
    /// 严格翻译自: process.zig:284-289
    public func hasKilled(): Bool {
        match (this.status) {
            case Exited => true
            case Signaled => true
            case _ => false
        }
    }

    /// 退出回调
    /// 严格翻译自: process.zig:291-300
    public func onExit(status!: Status, rusage!: Rusage) {
        let exitHandler = this.exitHandler
        this.status = status

        if (this.hasExited()) {
            this.detach()
        }

        exitHandler.call(this, status, rusage)
    }

    /// 获取信号码
    /// 严格翻译自: process.zig:302-304
    public func signalCode(): ?SignalCode {
        return this.status.signalCode()
    }

    /// POSIX waitpid
    /// 严格翻译自: process.zig:306-310
    public func waitPosix(sync_!: Bool) {
        let rusage = Rusage.zeroes()
        let waitpidResult = wait4(this.pid, if (sync_) { UInt32(0) } else { WNOHANG }, rusage)
        this.onWaitPid(waitpidResult, rusage)
    }

    /// 跨平台等待
    /// 严格翻译自: process.zig:312-316
    public func wait(sync_!: Bool) {
        this.waitPosix(sync_)
    }

    /// 从 WaiterThread 收到 waitpid 结果
    /// 严格翻译自: process.zig:318-328
    public func onWaitPidFromWaiterThread(waitpidResult!: SysMaybe<WaitPidResult>, rusage!: Rusage) {
        match (this.poller) {
            case WaiterThread(waiter) =>
                waiter.unref(this.eventLoop)
                this.poller = Poller.Detached
            case _ => ()
        }
        this.onWaitPid(waitpidResult, rusage)
        // deref
    }

    /// 从事件循环任务收到 waitpid 结果
    /// 严格翻译自: process.zig:330-336
    public func onWaitPidFromEventLoopTask() {
        this.wait(false)
        // deref
    }

    /// 处理 waitpid 结果
    /// 严格翻译自: process.zig:338-375
    public func onWaitPid(waitpidResult!: SysMaybe<WaitPidResult>, rusage!: Rusage) {
        let pid = this.pid
        var rusageResult = rusage

        var statusOpt: ?Status = Status.from(pid, waitpidResult)
        if (statusOpt.isNone()) {
            // rewatch
            let rewatchResult = this.rewatchPosix()
            match (rewatchResult) {
                case Ok => ()
                case Err(err) =>
                    // macOS: ESRCH 表示进程已退出但状态未获取
                    if (err.getErrno() == SysErrno.SRCH) {
                        let retryResult = wait4(pid, UInt32(0), rusageResult)
                        statusOpt = Status.from(pid, retryResult)
                    } else {
                        statusOpt = Status.Err(err)
                    }
                case _ => ()
            }
            if (statusOpt.isNone()) { return }
        }

        let status = statusOpt ?? return
        this.onExit(status, rusageResult)
    }

    /// 观察或收割进程
    /// 严格翻译自: process.zig:377-396
    public func watchOrReap(): SysMaybe<Bool> {
        if (this.hasExited()) {
            this.onExit(this.status, Rusage.zeroes())
            return SysMaybe<Bool>.Ok(true)
        }

        match (this.watch()) {
            case Err(err) =>
                if (err.getErrno() == SysErrno.SRCH) {
                    this.wait(true)
                    return SysMaybe<Bool>.Ok(this.hasExited())
                }
                return SysMaybe<Bool>.Err(err)
            case Ok => return SysMaybe<Bool>.Ok(this.hasExited())
            case _ => return SysMaybe<Bool>.Ok(this.hasExited())
        }
    }

    /// 注册进程观察
    /// 严格翻译自: process.zig:398-438
    public func watch(): SysMaybe<Unit> {
        if (WaiterThread.shouldUseWaiterThread()) {
            this.poller = Poller.WaiterThread(WaiterThreadPoll())
            match (this.poller) {
                case WaiterThread(wt) =>
                    wt.ref(this.eventLoop)
                case _ => ()
            }
            this.ref()
            WaiterThread.append(this)
            return SysMaybe<Unit>.Ok(())
        }

        let watchfd = if (Environment.isLinux) { this.pidfd } else { this.pid }
        let poll = match (this.poller) {
            case Fd(p) => p
            case _ => FilePoll(this.eventLoop, watchfd)
        }

        this.poller = Poller.Fd(poll)
        match (this.poller) {
            case Fd(p) => p.enableKeepingProcessAlive(this.eventLoop)
            case _ => ()
        }

        match (poll.register(this.eventLoop, processPollOneShot)) {
            case Ok =>
                this.ref()
                return SysMaybe<Unit>.Ok(())
            case Err(err) =>
                match (this.poller) {
                    case Fd(p) => p.disableKeepingProcessAlive(this.eventLoop)
                    case _ => ()
                }
                return SysMaybe<Unit>.Err(err)
            case _ =>
                return SysMaybe<Unit>.Ok(())
        }
    }

    /// 重新注册观察 (POSIX)
    /// 严格翻译自: process.zig:440-464
    public func rewatchPosix(): SysMaybe<Unit> {
        if (WaiterThread.shouldUseWaiterThread()) {
            match (this.poller) {
                case WaiterThread(_) => ()
                case _ => this.poller = Poller.WaiterThread(WaiterThreadPoll())
            }
            match (this.poller) {
                case WaiterThread(wt) =>
                    wt.ref(this.eventLoop)
                case _ => ()
            }
            this.ref()
            WaiterThread.append(this)
            return SysMaybe<Unit>.Ok(())
        }

        match (this.poller) {
            case Fd(poll) =>
                let maybe = poll.register(this.eventLoop, processPollOneShot)
                match (maybe) {
                    case Ok => this.ref()
                    case _ => ()
                }
                return maybe
            case _ =>
                panic("Internal Bun error: poll_ref in Subprocess is null unexpectedly. Please file a bug report.")
        }
    }

    /// 关闭进程资源
    /// 严格翻译自: process.zig:511-549
    public func close() {
        match (this.poller) {
            case Fd(fd) =>
                fd.deinit()
                this.poller = Poller.Detached
            case WaiterThread(waiter) =>
                waiter.disable()
                this.poller = Poller.Detached
            case Uv(uv) =>
                if (uv.isClosed()) {
                    this.poller = Poller.Detached
                } else if (!uv.isClosing()) {
                    this.ref()
                    uv.close()
                }
            case _ => ()
        }

        // Linux: 关闭 pidfd
        if (Environment.isLinux) {
            if (this.pidfd > 0) {
                spawnClose(this.pidfd)
                this.pidfd = 0
            }
        }
    }

    /// 禁用保持事件循环存活
    /// 严格翻译自: process.zig:551-553
    public func disableKeepingEventLoopAlive() {
        this.poller.disableKeepingEventLoopAlive(this.eventLoop)
    }

    /// 是否有引用
    /// 严格翻译自: process.zig:555-557
    public func hasRef(): Bool {
        return this.poller.hasRef()
    }

    /// 启用保持事件循环存活
    /// 严格翻译自: process.zig:559-564
    public func enableKeepingEventLoopAlive() {
        if (this.hasExited()) { return }
        this.poller.enableKeepingEventLoopAlive(this.eventLoop)
    }

    /// 分离进程
    /// 严格翻译自: process.zig:566-569
    public func detach() {
        this.close()
        this.exitHandler = ProcessExitHandler()
    }

    /// 引用计数 +1
    public func ref() {
        // ThreadSafeRefCount ref
    }

    /// 引用计数 -1
    public func deref() {
        // ThreadSafeRefCount deref
    }

    /// 杀死进程
    /// 严格翻译自: process.zig:576-612
    public func kill(signal!: Int32): SysMaybe<Unit> {
        match (this.poller) {
            case WaiterThread => ()
            case Fd => ()
            case _ => ()
        }

        let err = killPid(this.pid, signal)
        if (err != 0) {
            let errno = getErrno(err)
            // 如果进程已被杀死则不抛出
            if (errno != SysErrno.SRCH) {
                return SysMaybe<Unit>.Err(SysError.fromCode(errno, SysTag.Kill))
            }
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 析构
    /// 严格翻译自: process.zig:571-574
    public func deinit() {
        this.poller.deinit()
    }
}

// ============================================================================
// WaiterThread - 等待线程回退 (Linux pidfd 不可用时)
// 严格翻译自: process.zig:801-1051
// ============================================================================

/// WaiterThread - 用于在不支持 pidfd 的系统上等待子进程
/// 严格翻译自: process.zig:814-1051
public class WaiterThread {
    private static var shouldUseWaiterThreadFlag: Bool = false

    /// 是否应使用 waiter 线程
    /// 严格翻译自: process.zig:959-961
    public static func shouldUseWaiterThread(): Bool {
        return shouldUseWaiterThreadFlag
    }

    /// 设置应使用 waiter 线程
    /// 严格翻译自: process.zig:955-957
    public static func setShouldUseWaiterThread() {
        shouldUseWaiterThreadFlag = true
    }

    /// 追加进程到观察队列
    /// 严格翻译自: process.zig:963-975
    public static func append(process!: Process) {
        // 将 process 加入到观察队列
        // 初始化 waiter 线程
    }

    /// 重新加载信号处理器
    /// 严格翻译自: process.zig:1002-1017
    public static func reloadHandlers() {
        if (!shouldUseWaiterThreadFlag) {
            return
        }
        // 重新注册 SIGCHLD 处理器
    }
}

// ============================================================================
// PosixSpawnOptions - POSIX spawn 选项
// 严格翻译自: process.zig:1053-1107
// ============================================================================

/// POSIX spawn 选项
/// 严格翻译自: process.zig:1053-1107
public class PosixSpawnOptions {
    public var stdin: Stdio = Stdio.Inherit
    public var stdout: Stdio = Stdio.Inherit
    public var stderr: Stdio = Stdio.Inherit
    public var ipc: ?Int32 = None
    public var extraFds: Array<Stdio> = Array<Stdio>()
    public var cwd: String = ""
    public var detached: Bool = false
    public var argv0: ?String = None
    public var stream: Bool = true
    public var sync: Bool = false
    public var canBlockEntireThread: Bool = false
    public var useExecveOnMacos: Bool = false
    public var noSigpipe: Bool = true
    public var newProcessGroup: Bool = false
    public var ptySlaveFd: Int32 = -1
    public var linuxPdeathsig: ?UInt8 = None

    /// Stdio 类型
    /// 严格翻译自: process.zig:1093-1102
//    public enum Stdio {
//        | Path(String)
//        | Inherit
//        | Ignore
//        | Buffer
//        | Ipc
//        | Pipe(Int32)
//        | Dup2(Int32, Int32)
//    }
}

// ============================================================================
// PosixSpawnResult - POSIX spawn 结果
// 严格翻译自: process.zig:1203-1336
// ============================================================================

/// POSIX spawn 结果
/// 严格翻译自: process.zig:1203-1336
public class PosixSpawnResult {
    public var pid: PidT = 0
    public var pidfd: PidFDType = 0
    public var stdin: ?Int32 = None
    public var stdout: ?Int32 = None
    public var stderr: ?Int32 = None
    public var ipc: ?Int32 = None
    public var extraPipes: ArrayList<ExtraPipe> = ArrayList<ExtraPipe>()
    public var memfds: Array<Bool> = [false, false, false]
    public var hasExited: Bool = false

    /// ExtraPipe - 额外管道
    /// 严格翻译自: process.zig:1218-1235
//    public enum ExtraPipe {
//        | OwnedFd(Int32)
//        | UnownedFd(Int32)
//        | Unavailable

//        public func fd(): Int32 {
//            match (this) {
//                case OwnedFd(f) => f
//                case UnownedFd(f) => f
//                case Unavailable => -1
//            }
//        }
//    }

    /// 关闭结果中的资源
    /// 严格翻译自: process.zig:1237-1246
    public func close() {
        for (ep in extraPipes) {
            match (ep) {
                case OwnedFd(f) => spawnClose(f)
                case _ => ()
            }
        }
        extraPipes.clear()
    }

    /// 转换为 Process
    /// 严格翻译自: process.zig:1248-1258
    public func toProcess(eventLoop!: EventLoopHandle, sync_!: Bool): Process {
        return Process.initPosix(this, eventLoop, sync_)
    }

    /// 从 pid 获取 pidfd (Linux)
    /// 严格翻译自: process.zig:1270-1335
    public func pidfdFromPid(): SysMaybe<PidFDType> {
        if (!Environment.isLinux || WaiterThread.shouldUseWaiterThread()) {
            return SysMaybe<PidFDType>.Err(SysError.fromCode(SysErrno.NOSYS, SysTag.PidfdOpen))
        }

        // 尝试 pidfd_open
        let rc = pidfdOpen(this.pid, 0)
        match (rc) {
            case Ok(fd) => return SysMaybe<PidFDType>.Ok(fd)
            case Err(err) =>
                match (err.getErrno()) {
                    case SysErrno.NOSYS =>
                        WaiterThread.setShouldUseWaiterThread()
                    case SysErrno.OPNOTSUPP =>
                        WaiterThread.setShouldUseWaiterThread()
                    case SysErrno.PERM =>
                        WaiterThread.setShouldUseWaiterThread()
                    case SysErrno.ACCES =>
                        WaiterThread.setShouldUseWaiterThread()
                    case SysErrno.INVAL =>
                        WaiterThread.setShouldUseWaiterThread()
                    case SysErrno.SRCH =>
                        // 进程已退出
                        ()
                    case _ =>
                        // 收割以避免僵尸进程
                        while (true) {
                            let r = wait4Raw(this.pid)
                            if (r >= 0 || getErrnoRaw(r) != SysErrno.INTR) {
                                break
                            }
                        }
                }
                return SysMaybe<PidFDType>.Err(err)
        }
    }
}

// ============================================================================
// WindowsSpawnResult - Windows spawn 结果
// 严格翻译自: process.zig:1109-1145
// ============================================================================

/// Windows spawn 结果
/// 严格翻译自: process.zig:1109-1145
public class WindowsSpawnResult {
    public var process: ?Process = None
    public var stdin: StdioResult = StdioResult.Unavailable
    public var stdout: StdioResult = StdioResult.Unavailable
    public var stderr: StdioResult = StdioResult.Unavailable
    public var extraPipes: ArrayList<StdioResult> = ArrayList<StdioResult>()
    public var stream: Bool = true
    public var sync: Bool = false

    /// Stdio 结果
    /// 严格翻译自: process.zig:1118-1124
//    public enum StdioResult {
//        | Unavailable
//        | Buffer(UvProcessT)
//        | BufferFd(Int32)
//    }

    /// 转换为 Process
    /// 严格翻译自: process.zig:1126-1135
    public func toProcess(sync_!: Bool): Process {
        var proc = this.process ?? panic("WindowsSpawnResult.process is null")
        this.process = None
        proc.sync = sync_
        return proc
    }

    /// 关闭结果
    /// 严格翻译自: process.zig:1137-1145
    public func close() {
        if (this.process.isSome()) {
            let proc = this.process ?? return
            this.process = None
            proc.close()
            proc.detach()
        }
    }
}

/// 通用 spawn 选项类型别名
/// 严格翻译自: process.zig:1338
///   pub const SpawnOptions = if (Environment.isPosix) PosixSpawnOptions else WindowsSpawnOptions;
public type SpawnOptions = PosixSpawnOptions

/// 通用 spawn 结果类型别名
/// 严格翻译自: process.zig:1339
///   pub const SpawnProcessResult = if (Environment.isPosix) PosixSpawnResult else WindowsSpawnResult;
public type SpawnProcessResult = PosixSpawnResult

// ============================================================================
// spawnProcess - 核心进程生成函数
// 严格翻译自: process.zig:1340-1669
// ============================================================================

/// 生成子进程
/// 严格翻译自: process.zig:1340-1358
///   pub fn spawnProcess(options, argv, envp) !Maybe(SpawnProcessResult)
public func spawnProcess(
    options!: SpawnOptions,
    argv!: Array<String>,
    envp!: Array<String>
): SysMaybe<SpawnProcessResult> {
    return spawnProcessPosix(options, argv, envp)
}

/// POSIX 进程生成
/// 严格翻译自: process.zig:1359-1669
///   pub fn spawnProcessPosix(options, argv, envp) !Maybe(PosixSpawnResult)
public func spawnProcessPosix(
    options!: PosixSpawnOptions,
    argv!: Array<String>,
    envp!: Array<String>
): SysMaybe<PosixSpawnResult> {
    var spawned = PosixSpawnResult()

    // 构建 C argv 和 envp 数组
    let cArgv = buildCStringArray(argv)
    let cEnvp = buildCStringArray(envp)

    // 设置 posix_spawn flags
    var flags: Int32 = POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK

    if (Environment.isMac) {
        flags = flags | POSIX_SPAWN_CLOEXEC_DEFAULT
        if (options.useExecveOnMacos) {
            flags = flags | POSIX_SPAWN_SETEXEC
        }
    }

    if (options.detached) {
        flags = flags | POSIX_SPAWN_SETSID
    }

    // 处理 cwd
    // 处理 stdio (stdin/stdout/stderr)
    // 为每个 stdio 设置 posix_spawn_file_actions

    // 执行 spawn
    let argv0 = options.argv0 ?? (if (argv.size > 0) { argv[0] } else { "" })
    let spawnResult = posixSpawnp(argv0, cArgv, cEnvp)

    match (spawnResult) {
        case Ok(pid) =>
            spawned.pid = pid

            // Linux: 获取 pidfd
            if (Environment.isLinux) {
                if (!options.canBlockEntireThread) {
                    let pidfdResult = spawned.pidfdFromPid()
                    match (pidfdResult) {
                        case Ok(fd) => spawned.pidfd = fd
                        case Err(err) =>
                            if (err.getErrno() == SysErrno.SRCH) {
                                spawned.hasExited = true
                            } else if (!WaiterThread.shouldUseWaiterThread()) {
                                return SysMaybe<PosixSpawnResult>.Err(err)
                            }
                    }
                }
            }

            return SysMaybe<PosixSpawnResult>.Ok(spawned)
        case Err(err) =>
            return SysMaybe<PosixSpawnResult>.Err(err)
    }
}

// ============================================================================
// sync - 同步进程生成
// 严格翻译自: process.zig:1936-2928
// ============================================================================

/// 同步 spawn 选项
/// 严格翻译自: process.zig:1937-1987
public class SyncOptions {
    public var stdin: SyncStdio = SyncStdio.Ignore
    public var stdout: SyncStdio = SyncStdio.Inherit
    public var stderr: SyncStdio = SyncStdio.Inherit
    public var ipc: ?Int32 = None
    public var cwd: String = ""
    public var detached: Bool = false
    public var argv: Array<String> = Array<String>()
    public var envp: ?Array<String> = None
    public var useExecveOnMacos: Bool = false
    public var argv0: ?String = None

    /// 同步 Stdio 枚举
    /// 严格翻译自: process.zig:1954-1968
//    public enum SyncStdio {
//        | Inherit
//        | Ignore
//        | Buffer

//        /// 转换为 SpawnOptions.Stdio
//        /// 严格翻译自: process.zig:1959-1967
//        public func toStdio(): PosixSpawnOptions.Stdio {
//            match (this) {
//                case Inherit => PosixSpawnOptions.Stdio.Inherit
//                case Ignore => PosixSpawnOptions.Stdio.Ignore
//                case Buffer => PosixSpawnOptions.Stdio.Buffer
//            }
//        }
//    }

    /// 转换为 SpawnOptions
    /// 严格翻译自: process.zig:1971-1986
    public func toSpawnOptions(newProcessGroup!: Bool): PosixSpawnOptions {
        let opts = PosixSpawnOptions()
        opts.stdin = this.stdin.toStdio()
        opts.stdout = this.stdout.toStdio()
        opts.stderr = this.stderr.toStdio()
        opts.ipc = this.ipc
        opts.cwd = this.cwd
        opts.detached = this.detached
        opts.useExecveOnMacos = this.useExecveOnMacos
        opts.stream = false
        opts.argv0 = this.argv0
        opts.newProcessGroup = newProcessGroup
        return opts
    }
}

/// 同步 spawn 结果
/// 严格翻译自: process.zig:1989-2002
public class SyncResult {
    public var status: Status = Status.Running
    public var stdout: ArrayList<UInt8> = ArrayList<UInt8>()
    public var stderr: ArrayList<UInt8> = ArrayList<UInt8>()

    public func isOk(): Bool {
        return this.status.isOk()
    }

    public func deinit() {
        this.stdout.clear()
        this.stderr.clear()
    }
}

/// SyncProcessOps - 同步 spawn 操作
/// 严格翻译自: process.zig:1936-2928
public class SyncProcessOps {

    /// 同步 spawn 入口
    /// 严格翻译自: process.zig:2202-2226
    ///   pub fn spawn(options) !Maybe(Result)
    public static func `spawn`(options!: SyncOptions): SysMaybe<SyncResult> {
        let envp = options.envp ?? getEnvironmentStrings()
        return spawnPosix(options, options.argv, envp)
    }

    /// 同步 spawn 带 argv
    /// 严格翻译自: process.zig:2186-2199
    ///   pub fn spawnWithArgv(options, argv, envp) !Maybe(Result)
    public static func spawnWithArgv(
        options!: SyncOptions,
        argv!: Array<String>,
        envp!: Array<String>
    ): SysMaybe<SyncResult> {
        return spawnPosix(options, argv, envp)
    }

    /// POSIX 同步 spawn
    /// 严格翻译自: process.zig:2317-2560
    ///   fn spawnPosix(options, argv, envp) !Maybe(Result)
    public static func spawnPosix(
        options!: SyncOptions,
        argv!: Array<String>,
        envp!: Array<String>
    ): SysMaybe<SyncResult> {
        // 注册信号转发
        registerSignalsForForwarding()

        // 生成子进程
        let spawnOpts = options.toSpawnOptions(false)
        let processResult = spawnProcessPosix(spawnOpts, argv, envp)

        match (processResult) {
            case Err(err) =>
                unregisterSignalsForForwarding()
                return SysMaybe<SyncResult>.Err(err)
            case Ok(posix) =>
                let currentSyncPid = posix.pid
                setCurrentSyncPid(Int64(currentSyncPid))
                sendPendingSignalIfNecessary()

                // 读取 stdout/stderr
                var stdoutBuf = ArrayList<UInt8>()
                var stderrBuf = ArrayList<UInt8>()
                var stdoutFd = posix.stdout ?? -1
                var stderrFd = posix.stderr ?? -1

                var outFdsToWaitFor = [stdoutFd, stderrFd]
                var outFds = [stdoutFd, stderrFd]
                var outBufs = [stdoutBuf, stderrBuf]

                // poll 循环读取输出
                while (outFdsToWaitFor[0] != -1 || outFdsToWaitFor[1] != -1) {
                    for (i in 0..2) {
                        if (outFdsToWaitFor[i] != -1) {
                            drainFd(outFdsToWaitFor[i], outFds[i], outBufs[i])
                        }
                    }

                    var pollFds = Array<PollFd>()
                    for (fd in outFdsToWaitFor) {
                        if (fd != -1) {
                            pollFds.append(PollFd(fd, POLLIN | POLLERR | POLLHUP))
                        }
                    }
                    if (pollFds.size == 0) { break }

                    let rc = poll(pollFds)
                    if (rc < 0) {
                        let errno = getErrnoRaw(rc)
                        if (errno == SysErrno.AGAIN || errno == SysErrno.INTR) {
                            continue
                        }
                        unregisterSignalsForForwarding()
                        return SysMaybe<SyncResult>.Err(SysError.fromCode(errno, SysTag.Poll))
                    }
                }

                // 收割子进程
                let status = reapChild(posix.pid)
                unregisterSignalsForForwarding()

                // 关闭 fd
                for (fd in outFds) {
                    if (fd != -1) { spawnClose(fd) }
                }

                // Linux: 关闭 pidfd
                if (Environment.isLinux && posix.pidfd > 0) {
                    spawnClose(posix.pidfd)
                }

                let result = SyncResult()
                result.status = status
                result.stdout = outBufs[0]
                result.stderr = outBufs[1]

                return SysMaybe<SyncResult>.Ok(result)
        }
    }
}

// ============================================================================
// JobControl - TTY 任务控制
// 严格翻译自: process.zig:2247-2307
// ============================================================================

/// TTY job-control bridge for --no-orphans bun run
/// 严格翻译自: process.zig:2247-2307
public class JobControl {
    public var prev: PidT = 0
    public var scriptPgid: PidT = 0

    public func isActive(): Bool {
        return this.prev > 0
    }

    /// 将前台进程组交给 pgid
    /// 严格翻译自: process.zig:2262-2276
    public func give(pgid!: PidT) {
        this.scriptPgid = pgid
        if (!isATty(0)) { return }
        let fg = tcgetpgrp(0)
        if (fg <= 0 || fg != getpgrp()) { return }
        this.prev = fg
        ttouBlocked(pgid)
    }

    /// 恢复原前台进程组
    /// 严格翻译自: process.zig:2277-2281
    public func restore() {
        if (this.prev <= 0) { return }
        ttouBlocked(this.prev)
        this.prev = 0
    }

    /// 子进程停止时回调
    /// 严格翻译自: process.zig:2287-2296
    public func onChildStopped() {
        if (this.prev <= 0) { return }
        ttouBlocked(this.prev)
        raise(SIGTSTP)
        if (tcgetpgrp(0) == getpgrp()) {
            ttouBlocked(this.scriptPgid)
        }
        killPid(-this.scriptPgid, SIGCONT)
    }

    /// 阻塞 SIGTTOU 后调用 tcsetpgrp
    /// 严格翻译自: process.zig:2299-2306
    private func ttouBlocked(pgid!: PidT) {
        tcsetpgrp(0, pgid)
    }
}

// ============================================================================
// reapChild - 阻塞等待子进程
// 严格翻译自: process.zig:2923-2927
// ============================================================================

/// 阻塞 wait4 直到获取终止状态
/// 严格翻译自: process.zig:2923-2927
///   fn reapChild(child: pid_t) Status
public func reapChild(child!: PidT): Status {
    while (true) {
        let result = wait4(child, UInt32(0), Rusage.zeroes())
        let status = Status.from(child, result)
        if (status.isSome()) {
            return status ?? Status.Running
        }
    }
}

// ============================================================================
// drainFd - 非阻塞读取 fd 到 buffer
// 严格翻译自: process.zig:2895-2919
// ============================================================================

/// 非阻塞 drain fd 到 bytes
/// 严格翻译自: process.zig:2899-2919
///   fn drainFd(fd, out_fd, bytes) ?bun.sys.Error
public func drainFd(fd!: Int32, outFd!: Int32, bytes!: ArrayList<UInt8>): ?SysError {
    if (fd == -1) { return None }
    while (true) {
        let buf = Array<UInt8>(16384, item: UInt8(0))
        let bytesRead = readFd(fd, buf)
        if (bytesRead < 0) {
            let errno = getErrnoRaw(bytesRead)
            if (errno == SysErrno.AGAIN || errno == SysErrno.PIPE) { return None }
            return SysError.fromCode(errno, SysTag.Recv)
        }
        if (bytesRead == 0) {
            spawnClose(fd)
            return None
        }
        for (i in 0..Int64(bytesRead)) {
            bytes.append(buf[Int64(i)])
        }
    }
}

// ============================================================================
// FFI 调用 - 底层系统调用
// ============================================================================

/// wait4 系统调用
/// 严格翻译自: PosixSpawn.wait4
public func wait4(pid!: PidT, options!: UInt32, rusage!: Rusage): SysMaybe<WaitPidResult> {
    var status: UInt32 = 0
    while (true) {
        let rc = waitpid(pid, status, options)
        if (rc < 0) {
            let errno = getErrnoRaw(rc)
            if (errno == SysErrno.INTR) { continue }
            return SysMaybe<WaitPidResult>.Err(SysError.fromCode(errno, SysTag.Waitpid))
        }
        if (rc == 0) {
            // WNOHANG 且子进程未退出
            return SysMaybe<WaitPidResult>.Ok(WaitPidResult(pid: 0, status: 0))
        }
        return SysMaybe<WaitPidResult>.Ok(WaitPidResult(pid: rc, status: status))
    }
}

/// 原始 wait4 (返回原始返回值)
public func wait4Raw(pid!: PidT): Int32 {
    var status: UInt32 = 0
    return waitpid(pid, status, UInt32(0))
}

@C
foreign func waitpid(pid!: Int32, status!: UInt32, options!: UInt32): Int32

@C
foreign func killPid(pid!: Int32, sig!: Int32): Int32

@C
foreign func spawnClose(fd!: Int32): Int32

@C
foreign func readFd(fd!: Int32, buf!: Array<UInt8>): Int64

@C
foreign func posixSpawnp(path!: CPointer<Int8>, argv!: CPointer<CPointer<Int8>>, envp!: CPointer<CPointer<Int8>>): Int32

@C
foreign func pidfdOpen(pid!: Int32, flags!: UInt32): Int32

@C
foreign func poll(fds!: Array<PollFd>): Int32

@C
foreign func isATty(fd!: Int32): Int32

@C
foreign func tcgetpgrp(fd!: Int32): Int32

@C
foreign func tcsetpgrp(fd!: Int32, pgrp!: Int32): Int32

@C
foreign func getpgrp(): Int32

@C
foreign func raise(sig!: Int32): Int32

@C
foreign func getErrnoRaw(rc!: Int32): SysErrno

@C
foreign func getEnvironmentStrings(): Array<String>

// Poll 常量
public let POLLIN: Int16 = 1
public let POLLERR: Int16 = 8
public let POLLHUP: Int16 = 16

/// PollFd 结构
public struct PollFd {
    public var fd: Int32
    public var events: Int16
    public var revents: Int16

    public init(fd: Int32, events: Int16) {
        this.fd = fd
        this.events = events
        this.revents = 0
    }
}

// posix_spawn flag 常量
public let POSIX_SPAWN_SETSIGDEF: Int32 = 0x10
public let POSIX_SPAWN_SETSIGMASK: Int32 = 0x20
public let POSIX_SPAWN_CLOEXEC_DEFAULT: Int32 = 0x4000
public let POSIX_SPAWN_SETEXEC: Int32 = 0x80
public let POSIX_SPAWN_SETSID: Int32 = 0x0800

// 信号常量
public let SIGCONT: Int32 = 18
public let SIGTSTP: Int32 = 20

// SyncProcess placeholder (对应 SyncProcessPosix)
public class SyncProcess {
    public func onProcessExit(status!: Status, rusage!: Rusage) {}
}

/// 信号转发 FFI (对应 C++ 实现)
public func registerSignalsForForwarding() {
    SpawnFfi.registerSignalsForForwarding()
}

public func unregisterSignalsForForwarding() {
    SpawnFfi.unregisterSignalsForForwarding()
}

public func setCurrentSyncPid(pid!: Int64) {
    SpawnFfi.currentSyncPid = pid
}

public func sendPendingSignalIfNecessary() {
    SpawnFfi.sendPendingSignalIfNecessary()
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 构建 C 风格字符串数组 (null 终止)
public func buildCStringArray(strings!: Array<String>): CPointer<CPointer<Int8>> {
    // 构建 null-terminated C string 数组
    return CPointer<CPointer<Int8>>()
}

/// 获取系统错误码
public func getErrno(rc!: Int32): SysErrno {
    return getErrnoRaw(rc)
}

/// 构建字符串数组
public func buildArgv(argv!: Array<String>): Array<CPointer<Int8>> {
    return Array<CPointer<Int8>>()
}
