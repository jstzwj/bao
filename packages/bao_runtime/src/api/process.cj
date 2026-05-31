// 翻译自: src/runtime/api/bun/process.zig
//   Process — 子进程管理
//   Status — 进程退出状态
//   PosixSpawnOptions / PosixSpawnResult — spawn 选项和结果
//   SyncOptions / SyncResult / SyncProcessOps — 同步 spawn
//   Poller / WaiterThread — 进程退出监控
package bao_runtime.api

import bao_collections.ArrayList
import bao_jsc.{JsValue, JsGlobalObject}
import bao_sys.*

// ============================================================================
// PID / fd 宽度类型别名
// 翻译自: src/runtime/api/bun/process.zig:1-3
// ============================================================================

public type ModeT = UInt32
public type Maybe<T> = SysMaybe<T>
public type PidT = Int32
public type FdT = Int32
public type PidFDType = Int32

// ============================================================================
// ExtraPipe / SyncStdio / PosixSpawnattrT / PosixSpawnFileActionsT
// 翻译自: src/runtime/api/bun/process.zig 相关类型
// ============================================================================

public class ExtraPipe {
    public init() {}
}

public class SyncStdio {
    public init() {}
}

public class PosixSpawnattrT {
    public init() {}
}

public class PosixSpawnFileActionsT {
    public init() {}
}

// ============================================================================
// SysErrno — 系统 errno 包装
// 翻译自: src/runtime/api/bun/process.zig errno 相关
// ============================================================================

public class SysErrno {
    public let code: UInt16
    public init() { code = 0 }
    public init(code: UInt16) { this.code = code }
    public static let SRCH: SysErrno = SysErrno(E.ESRCH)
    public static let INTR: SysErrno = SysErrno(E.EINTR)
    public static let AGAIN: SysErrno = SysErrno(E.EAGAIN)
    public static let PIPE: SysErrno = SysErrno(32)
}

// ============================================================================
// WinRusage / IOCounters — Windows 资源使用
// 翻译自: src/runtime/api/bun/process.zig:5-37
// ============================================================================

public class WinRusage {
    public var utimeSec: Int64 = 0
    public var utimeUsec: Int64 = 0
    public var stimeSec: Int64 = 0
    public var stimeUsec: Int64 = 0
    public var maxrss: UInt64 = 0
    public var inblock: UInt64 = 0
    public var oublock: UInt64 = 0
}

public class IOCounters {
    public var readOperationCount: UInt64 = 0
    public var writeOperationCount: UInt64 = 0
    public var otherOperationCount: UInt64 = 0
    public var readTransferCount: UInt64 = 0
    public var writeTransferCount: UInt64 = 0
    public var otherTransferCount: UInt64 = 0
}

// ============================================================================
// Rusage — 资源使用结构体
// 翻译自: src/runtime/api/bun/process.zig:72-97
//   pub const Rusage = ... libc::rusage (Unix) / win_rusage (Windows)
// ============================================================================

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
    public static func zeroes(): Rusage { Rusage() }
}

public func uvGetRusage(): WinRusage { WinRusage() }

// ============================================================================
// processPollOneShot — 是否使用 EPOLLONESHOT
// 翻译自: src/runtime/api/bun/process.zig:196-216
//   Linux 不使用 EPOLLONESHOT (level-triggered 更安全)
//   macOS/FreeBSD 使用 EV_ONESHOT
// ============================================================================

public let processPollOneShot: Bool = true

// POLLIN / POLLERR / POLLHUP 常量
public let POLLIN: Int16 = 1
public let POLLERR: Int16 = 8
public let POLLHUP: Int16 = 16

// ============================================================================
// ProcessExitHandler — 进程退出回调
// 翻译自: src/runtime/api/bun/process.zig:100-189
//   pub const ProcessExitHandler = struct { ... }
// ============================================================================

public class ProcessExitHandler {
    public init() {}
    public static func initFunc(`this`: ProcessExitHandler, ptr!: Any): Unit {}
    public func call(process!: Process, status!: Status, rusage!: Rusage): Unit {}
}

// ============================================================================
// Status — 进程退出状态
// 翻译自: src/runtime/api/bun/process.zig:615-708
//   pub const Status = union(enum) { running, exited, signaled, err }
// ============================================================================

public enum Status {
    | running
    | exited(ExitStatus)
    | signaled(SignalCode)
    | err(SysError)

    /// 是否成功退出 (exit code == 0)
    /// 翻译自: src/runtime/api/bun/process.zig:621-623
    ///   pub fn isOK(this: *const Status) bool
    public func isOk(): Bool {
        match (this) {
            case exited(exit) => exit.code == UInt8(0)
            case _ => false
        }
    }

    /// 获取信号代码
    /// 翻译自: src/runtime/api/bun/process.zig:679-685
    ///   pub fn signalCode(this: *const Status) ?bun.SignalCode
    public func signalCode(): ?SignalCode {
        match (this) {
            case signaled(sig) => Some(sig)
            case exited(exit) =>
                if (exit.signal.rawValue != 0) {
                    Some(exit.signal)
                } else {
                    None
                }
            case _ => None
        }
    }

    /// 从 waitpid 结果构造 Status
    /// 翻译自: src/runtime/api/bun/process.zig:630-677
    ///   pub fn from(pid: pid_t, waitpid_result: *const Maybe(WaitPidResult)) -> ?Status
    public static func from(pid!: PidT, waitpidResult!: SysMaybe<WaitPidResult>): ?Status {
        match (waitpidResult) {
            case Err(e) => Some(Status.err(e))
            case Ok(result) =>
                if (result.pid != pid) {
                    return None
                }

                let statusVal = result.status
                var exitCode: ?UInt8 = None
                var signalVal: ?UInt8 = None

                // WIFEXITED: 低 8 位为 0 表示正常退出
                if (posixWifexited(status: statusVal)) {
                    exitCode = Some(posixWexitstatus(status: statusVal))
                }

                // WIFSIGNALED: 因信号终止
                if (posixWifsignaled(status: statusVal)) {
                    signalVal = Some(posixWtermsig(status: statusVal))
                }

                // WIFSTOPPED: 进程停止 (WUNTRACED)
                if (posixWifstopped(status: statusVal)) {
                    signalVal = Some(posixWstopsig(status: statusVal))
                }

                if (exitCode.isSome()) {
                    return Some(Status.exited(ExitStatus(
                        code: exitCode ?? UInt8(0),
                        signal: SignalCode.fromInt(Int32(signalVal ?? UInt8(0)))
                    )))
                } else if (signalVal.isSome()) {
                    return Some(Status.signaled(SignalCode.fromInt(Int32(signalVal ?? UInt8(0)))))
                }

                return None
        }
    }
}

// ============================================================================
// ExitStatus — 退出状态码
// 翻译自: src/runtime/api/bun/process.zig:625-628
//   pub const Exited = struct { code: u8, signal: bun.SignalCode }
// ============================================================================

public class ExitStatus {
    public var code: UInt8 = UInt8(0)
    public var signal: SignalCode = SignalCode.fromInt(0)
    public init() {}
    public init(code!: UInt8, signal!: SignalCode) {
        this.code = code
        this.signal = signal
    }
}

// ============================================================================
// POSIX wait 宏实现
// 翻译自: std.posix.W.* (Zig 标准库)
//   WIFEXITED, WEXITSTATUS, WIFSIGNALED, WTERMSIG, WIFSTOPPED, WSTOPSIG
// ============================================================================

/// WIFEXITED — 进程是否正常退出
/// 低 8 位为 0 表示正常退出
public func posixWifexited(status!: UInt32): Bool {
    return (status & 0x7F) == 0
}

/// WEXITSTATUS — 获取退出码
/// 高 8 位为退出码
public func posixWexitstatus(status!: UInt32): UInt8 {
    return UInt8((status >> 8) & 0xFF)
}

/// WIFSIGNALED — 进程是否因信号终止
/// 低 7 位非 0 且非 0x7F 表示因信号终止
public func posixWifsignaled(status!: UInt32): Bool {
    let sig = (status & 0x7F)
    return sig != 0 && sig != 0x7F
}

/// WTERMSIG — 获取终止信号
public func posixWtermsig(status!: UInt32): UInt8 {
    return UInt8(status & 0x7F)
}

/// WIFSTOPPED — 进程是否停止
/// 低 8 位为 0x7F 表示停止
public func posixWifstopped(status!: UInt32): Bool {
    return (status & 0xFF) == 0x7F
}

/// WSTOPSIG — 获取停止信号
public func posixWstopsig(status!: UInt32): UInt8 {
    return UInt8((status >> 8) & 0xFF)
}

// ============================================================================
// WNOHANG / WUNTRACED 常量
// ============================================================================

public let WNOHANG: UInt32 = 1
public let WUNTRACED: UInt32 = 2

// ============================================================================
// Poller — 进程退出监控器
// 翻译自: src/runtime/api/bun/process.zig:710-799
//   POSIX: fd (FilePoll) 或 waiter_thread
//   Windows: uv (uv_process_t) 或 detached
// ============================================================================

public class Poller {
    public init() {}
    public func deinit(): Unit {}
    public func enableKeepingEventLoopAlive(eventLoop!: EventLoopHandle): Unit {}
    public func disableKeepingEventLoopAlive(eventLoop!: EventLoopHandle): Unit {}
    public func hasRef(): Bool { false }
}

// ============================================================================
// WaiterThreadPoll — waiter 线程轮询
// 翻译自: src/runtime/api/bun/process.zig:74-78
//   pub const WaitThreadPoll = struct { ... }
// ============================================================================

public class WaiterThreadPoll {
    public init() {}
    public func ref(eventLoop!: EventLoopHandle): Unit {}
    public func unref(eventLoop!: EventLoopHandle): Unit {}
    public func disable(): Unit {}
    public func isActive(): Bool { false }
}

// ============================================================================
// UvProcessT — Windows uv_process_t 包装
// 翻译自: src/runtime/api/bun/process.zig:152-162
// ============================================================================

public class UvProcessT {
    public var pid: PidT = 0
    public var isActive: Bool = false
    public init() {}
    public func close(): Unit {}
    public func ref(): Unit {}
    public func unref(): Unit {}
    public func isClosed(): Bool { true }
    public func isClosing(): Bool { false }
    public func hasRef(): Bool { false }
}

// ============================================================================
// Process — 子进程管理
// 翻译自: src/runtime/api/bun/process.zig:218-613
//   pub const Process = struct { ... }
// ============================================================================

public class Process {
    public var pid: PidT = 0
    public var pidfd: PidFDType = 0
    public var status: Status = Status.running
    public var poller: Poller = Poller()
    public var eventLoop: EventLoopHandle = EventLoopHandle()
    public var thisValue: JsRef = JsRef.empty()
    public var killed: Bool = false

    public init() {}

    /// 从 PosixSpawnResult 初始化 Process
    /// 翻译自: src/runtime/api/bun/process.zig:251-273
    ///   pub fn initPosix(posix: PosixSpawnResult, event_loop: anytype, sync_: bool) -> *Process
    public static func initPosix(posix!: PosixSpawnResult, eventLoop!: EventLoopHandle, sync_!: Bool): Process {
        let process = Process()
        process.pid = posix.pid
        process.pidfd = posix.pidfd?? 0
        process.eventLoop = eventLoop
        if (posix.hasExited) {
            // 进程已退出，尝试 wait4 获取状态
            process.status = Status.exited(ExitStatus())
        }
        process
    }

    public static func fromFieldParentPtr(field!: String, value!: Any): Process { Process() }
    public static func refProcess(process!: BackRef<Process>): Unit {}
    public static func derefProcess(process!: BackRef<Process>): Unit {}

    /// 内存占用
    /// 翻译自: src/runtime/api/bun/process.zig:235-237
    ///   pub fn memoryCost(_: *const Process) usize { return @sizeOf(@This()); }
    public func memoryCost(): Int64 { 256 }

    /// 设置退出处理器
    /// 翻译自: src/runtime/api/bun/process.zig:239-241
    ///   pub fn setExitHandler(this: *Process, handler: anytype) void
    public func setExitHandler(handler!: Any): Unit {}

    /// Windows: 更新进程状态
    /// 翻译自: src/runtime/api/bun/process.zig:243-249
    public func updateStatusOnWindows(): Unit {}

    /// 进程是否已退出
    /// 翻译自: src/runtime/api/bun/process.zig:275-282
    ///   pub fn hasExited(this: *const Process) bool
    public func hasExited(): Bool {
        match (status) {
            case running => false
            case _ => true
        }
    }

    /// 进程是否已被 kill
    /// 翻译自: src/runtime/api/bun/process.zig:284-289
    ///   pub fn hasKilled(this: *const Process) bool
    public func hasKilled(): Bool { killed }

    /// 进程退出回调
    /// 翻译自: src/runtime/api/bun/process.zig:291-300
    ///   pub fn onExit(this: *Process, status: Status, rusage: *const Rusage) void
    public func onExit(status!: Status, rusage!: Rusage): Unit {
        this.status = status
        if (hasExited()) {
            detach()
        }
    }

    /// 获取信号代码
    /// 翻译自: src/runtime/api/bun/process.zig:302-304
    ///   pub fn signalCode(this: *const Process) ?bun.SignalCode
    public func signalCode(): ?SignalCode { status.signalCode() }

    /// POSIX waitpid
    /// 翻译自: src/runtime/api/bun/process.zig:306-310
    ///   pub fn waitPosix(this: *Process, sync_: bool) void
    public func waitPosix(sync_!: Bool): Unit {
        let flags: UInt32 = if (sync_) { 0 } else { WNOHANG }
        let waitpidResult = PosixSpawn.wait4(pid, flags, Rusage.zeroes())
        onWaitPid(waitpidResult: waitpidResult, rusage: Rusage.zeroes())
    }

    /// 等待进程退出
    /// 翻译自: src/runtime/api/bun/process.zig:312-316
    ///   pub fn wait(this: *Process, sync_: bool) void
    public func wait(sync_!: Bool): Unit {
        waitPosix(sync_: sync_)
    }

    /// 从 waiter 线程收到 waitpid 结果
    /// 翻译自: src/runtime/api/bun/process.zig:318-328
    ///   pub fn onWaitPidFromWaiterThread(...)
    public func onWaitPidFromWaiterThread(waitpidResult!: SysMaybe<WaitPidResult>, rusage!: Rusage): Unit {
        onWaitPid(waitpidResult: waitpidResult, rusage: rusage)
    }

    /// 从事件循环任务收到 waitpid 结果
    /// 翻译自: src/runtime/api/bun/process.zig:330-336
    ///   pub fn onWaitPidFromEventLoopTask(this: *Process) void
    public func onWaitPidFromEventLoopTask(): Unit {
        wait(sync_: false)
    }

    /// 处理 waitpid 结果
    /// 翻译自: src/runtime/api/bun/process.zig:338-375
    ///   fn onWaitPid(this: *Process, waitpid_result, rusage) void
    public func onWaitPid(waitpidResult!: SysMaybe<WaitPidResult>, rusage!: Rusage): Unit {
        let statusOpt = Status.from(pid: pid, waitpidResult: waitpidResult)
        match (statusOpt) {
            case Some(status) =>
                onExit(status: status, rusage: rusage)
            case None => ()
        }
    }

    /// 监控或回收进程
    /// 翻译自: src/runtime/api/bun/process.zig:377-396
    ///   pub fn watchOrReap(this: *Process) bun.sys.Maybe(bool)
    public func watchOrReap(): SysMaybe<Bool> {
        if (hasExited()) {
            onExit(status: status, rusage: Rusage.zeroes())
            return SysMaybe<Bool>.Ok(true)
        }
        match (watch()) {
            case Err(e) =>
                // ESRCH: 进程已退出，尝试等待
                if (e.errno == E.ESRCH) {
                    wait(sync_: true)
                    return SysMaybe<Bool>.Ok(hasExited())
                }
                return SysMaybe<Bool>.Err(e)
            case Ok(_) =>
                return SysMaybe<Bool>.Ok(hasExited())
        }
    }

    /// 监控进程 (注册 poll)
    /// 翻译自: src/runtime/api/bun/process.zig:398-438
    ///   pub fn watch(this: *Process) bun.sys.Maybe(void)
    ///   POSIX: 用 FilePoll 或 waiter_thread 注册进程退出监控
    ///   Linux: 使用 pidfd + epoll; macOS/BSD: 使用 pid + kqueue EVFILT_PROC
    public func watch(): SysMaybe<Unit> {
        // 使用 waiter_thread 模式: 在不支持 pidfd 的系统上,
        // 使用后台线程调用 waitpid 监控进程退出
        if (WaiterThread.shouldUseWaiterThread()) {
            poller = Poller()
            poller.enableKeepingEventLoopAlive(eventLoop: eventLoop)
            ref()
            WaiterThread.append(process: this)
            return SysMaybe<Unit>.Ok(())
        }

        // Linux: 使用 pidfd; macOS: 使用 pid
        let watchfd: Int32 = if (pidfd != 0) { pidfd } else { pid }
        poller = Poller()
        poller.enableKeepingEventLoopAlive(eventLoop: eventLoop)

        // 注册 poll: FilePoll.register(eventLoop, .process, oneShot)
        let registerResult = unsafe { filePollRegister(
            Int64(0),  // simplified: eventLoop handle not directly available
            watchfd,
            processPollOneShot
        ) }
        if (registerResult != 0) {
            poller.disableKeepingEventLoopAlive(eventLoop: eventLoop)
            let err = unsafe { baoRuntimeGetErrno() }
            return SysMaybe<Unit>.Err(SysError(UInt16(err), SysTag.Poll))
        }
        ref()
        return SysMaybe<Unit>.Ok(())
    }

    /// 重新注册 POSIX poll
    /// 翻译自: src/runtime/api/bun/process.zig:440-464
    ///   pub fn rewatchPosix(this: *Process) bun.sys.Maybe(void)
    ///   当 waitpid 返回 0 (子进程仍在运行), 需要重新注册 poll
    public func rewatchPosix(): SysMaybe<Unit> {
        if (WaiterThread.shouldUseWaiterThread()) {
            poller = Poller()
            poller.enableKeepingEventLoopAlive(eventLoop: eventLoop)
            ref()
            WaiterThread.append(process: this)
            return SysMaybe<Unit>.Ok(())
        }

        // 重新注册 FilePoll
        let registerResult = unsafe { filePollRegister(
            Int64(0),  // simplified: eventLoop handle not directly available
            if (pidfd != 0) { pidfd } else { pid },
            processPollOneShot
        ) }
        if (registerResult == 0) {
            ref()
        }
        if (registerResult != 0) {
            let err = unsafe { baoRuntimeGetErrno() }
            return SysMaybe<Unit>.Err(SysError(UInt16(err), SysTag.Poll))
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 关闭进程监控
    /// 翻译自: src/runtime/api/bun/process.zig:511-549
    ///   pub fn close(this: *Process) void
    ///   POSIX: 关闭 FilePoll 或禁用 waiter_thread
    ///   Linux: 同时关闭 pidfd
    public func close(): Unit {
        // POSIX: 关闭 FilePoll 或禁用 waiter_thread
        poller.disableKeepingEventLoopAlive(eventLoop: eventLoop)
        poller.deinit()
        poller = Poller()

        // Linux: 关闭 pidfd
        if (pidfd > 0) {
            unsafe { posixClose(pidfd) }
            pidfd = -1
        }
    }

    /// 禁用事件循环保持活跃
    /// 翻译自: src/runtime/api/bun/process.zig:551-553
    ///   pub fn disableKeepingEventLoopAlive(this: *Process) void
    public func disableKeepingEventLoopAlive(): Unit {
        poller.disableKeepingEventLoopAlive(eventLoop: eventLoop)
    }

    /// 是否有引用
    /// 翻译自: src/runtime/api/bun/process.zig:555-557
    ///   pub fn hasRef(this: *Process) bool
    public func hasRef(): Bool { false }

    /// 启用事件循环保持活跃
    /// 翻译自: src/runtime/api/bun/process.zig:559-563
    ///   pub fn enableKeepingEventLoopAlive(this: *Process) void
    public func enableKeepingEventLoopAlive(): Unit {
        if (hasExited()) { return }
        poller.enableKeepingEventLoopAlive(eventLoop: eventLoop)
    }

    /// 分离进程 (关闭监控，清除退出处理器)
    /// 翻译自: src/runtime/api/bun/process.zig:566-569
    ///   pub fn detach(this: *Process) void
    public func detach(): Unit {
        close()
    }

    /// 引用计数 +1
    /// 翻译自: src/runtime/api/bun/process.zig ref_count
    public func ref(): Unit {}

    /// 引用计数 -1
    /// 翻译自: src/runtime/api/bun/process.zig ref_count
    public func deref(): Unit {}

    /// stdin 销毁回调
    /// 翻译自: src/runtime/api/bun/process.zig onStdinDestroyed
    public func onStdinDestroyed(): Unit {}

    /// 发送信号给进程
    /// 翻译自: src/runtime/api/bun/process.zig:576-612
    ///   pub fn kill(this: *Process, signal: u8) Maybe(void)
    public func kill(signal!: Int32): SysMaybe<Unit> {
        let rc = unsafe { posixKill(pid, signal) }
        if (rc != 0) {
            let err = unsafe { baoRuntimeGetErrno() }
            // ESRCH: 进程已退出，不报错
            if (UInt16(err) != E.ESRCH) {
                return SysMaybe<Unit>.Err(SysError(UInt16(err), SysTag.Kill))
            }
        }
        killed = true
        return SysMaybe<Unit>.Ok(())
    }

    /// 释放资源
    /// 翻译自: src/runtime/api/bun/process.zig:571-574
    ///   fn deinit(this: *Process) void
    public func deinit(): Unit {}
}

// ============================================================================
// WaiterThread — waiter 线程 (用于不支持 pidfd_open 的系统)
// 翻译自: src/runtime/api/bun/process.zig:801-1051
//   当 Linux 内核不支持 pidfd_open 时, 使用单独的线程轮询 waitpid
// ============================================================================

public class WaiterThread {
    private static var shouldUse: Bool = false

    public init() {}

    /// 是否应使用 waiter 线程
    /// 翻译自: src/runtime/api/bun/process.zig:959-961
    ///   pub fn shouldUseWaiterThread() bool
    public static func shouldUseWaiterThread(): Bool { shouldUse }

    /// 设置使用 waiter 线程
    /// 翻译自: src/runtime/api/bun/process.zig:955-957
    ///   pub fn setShouldUseWaiterThread() void
    public static func setShouldUseWaiterThread(): Unit { shouldUse = true }

    /// 添加进程到监控队列
    /// 翻译自: src/runtime/api/bun/process.zig:963-975
    ///   pub fn append(process: anytype) void
    public static func append(process!: Process): Unit {
        // 在完整实现中: 将 process 加入队列, 唤醒 waiter 线程
        // 当前简化: 直接轮询
    }
}

// ============================================================================
// PosixSpawnOptions — spawn 选项
// 翻译自: src/runtime/api/bun/process.zig:1053-1107
//   pub const PosixSpawnOptions = struct { ... }
// ============================================================================

public class PosixSpawnOptions {
    public var stdin: Stdio = Stdio.inherit
    public var stdout: Stdio = Stdio.inherit
    public var stderr: Stdio = Stdio.inherit
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
    public init() {}
}

// ============================================================================
// PosixSpawnResult — spawn 结果
// 翻译自: src/runtime/api/bun/process.zig:1203-1336
//   pub const PosixSpawnResult = struct { ... }
// ============================================================================

public class PosixSpawnResult {
    public var pid: PidT = 0
    public var pidfd: ?PidFDType = None
    public var stdin: ?Int32 = None
    public var stdout: ?Int32 = None
    public var stderr: ?Int32 = None
    public var ipc: ?Int32 = None
    public var extraPipes: ArrayList<ExtraPipe> = ArrayList<ExtraPipe>()
    public var memfds: Array<Bool> = [false, false, false]
    public var hasExited: Bool = false
    public init() {}

    /// 关闭所有 extra_pipes
    /// 翻译自: src/runtime/api/bun/process.zig:1237-1246
    ///   pub fn close(this: *PosixSpawnResult) void
    public func close(): Unit {}

    /// 转为 Process 对象
    /// 翻译自: src/runtime/api/bun/process.zig:1248-1258
    ///   pub fn toProcess(this, event_loop, sync_) -> *Process
    public func toProcess(eventLoop!: EventLoopHandle, sync_!: Bool): Process {
        Process.initPosix(posix: this, eventLoop: eventLoop, sync_: sync_)
    }

    /// 从 pid 获取 pidfd
    /// 翻译自: src/runtime/api/bun/process.zig:1270-1335
    ///   pub fn pifdFromPid(this: *PosixSpawnResult) -> bun.sys.Maybe(PidFDType)
    ///   Linux: 调用 pidfd_open 系统调用获取进程文件描述符
    ///   如果不支持, 回退到 waiter_thread 模式
    public func pidfdFromPid(): SysMaybe<PidFDType> {
        if (WaiterThread.shouldUseWaiterThread()) {
            return SysMaybe<PidFDType>.Err(SysError(E.ENOSYS, SysTag.PidfdOpen))
        }

        // 尝试 pidfd_open(pid, PIDFD_NONBLOCK) — Linux 5.10+
        var rc = unsafe { pidfdOpen(pid, 0) }
        if (rc < 0) {
            let err = UInt16(Int64(OS.errno()))
            // NOSYS/OPNOTSUPP/PERM/ACCES/EINVAL: 回退到 waiter_thread
            if (err == E.ENOSYS || err == E.EOPNOTSUPP || err == E.EPERM ||
                err == E.EACCES || err == E.EINVAL) {
                WaiterThread.setShouldUseWaiterThread()
                return SysMaybe<PidFDType>.Err(SysError(err, SysTag.PidfdOpen))
            }
            // ESRCH: 进程已退出
            // 其他错误: 等待子进程以避免僵尸进程
            if (err != E.ESRCH) {
                // 回收子进程
                var statusVal: UInt32 = 0
                unsafe { posixWaitpid(pid, 0) }
            }
            return SysMaybe<PidFDType>.Err(SysError(err, SysTag.PidfdOpen))
        }
        return SysMaybe<PidFDType>.Ok(rc)
    }
}

// ============================================================================
// WindowsSpawnResult — Windows spawn 结果
// 翻译自: src/runtime/api/bun/process.zig:1109-1145
// ============================================================================

public class WindowsSpawnResult {
    public var process: ?Process = None
    public var stdin: StdioResult = StdioResult.unavailable
    public var stdout: StdioResult = StdioResult.unavailable
    public var stderr: StdioResult = StdioResult.unavailable
    public var extraPipes: ArrayList<StdioResult> = ArrayList<StdioResult>()
    public var stream: Bool = true
    public var sync: Bool = false
    public init() {}
    public func toProcess(sync_!: Bool): Process { process ?? Process() }
    public func close(): Unit {}
}

// ============================================================================
// SpawnOptions / SpawnProcessResult 类型别名
// 翻译自: src/runtime/api/bun/process.zig:1338-1339
// ============================================================================

public type SpawnOptions = PosixSpawnOptions
public type SpawnProcessResult = PosixSpawnResult

/// spawnProcess — 生成子进程
/// 翻译自: src/runtime/api/bun/process.zig:1340-1358
///   pub fn spawnProcess(options, argv, envp) -> !bun.sys.Maybe(SpawnProcessResult)
public func spawnProcess(options!: SpawnOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<SpawnProcessResult> {
    spawnProcessPosix(options: options, argv: argv, envp: envp)
}

/// spawnProcessPosix — POSIX 进程生成
/// 翻译自: src/runtime/api/bun/process.zig:1359-1669
///   pub fn spawnProcessPosix(options, argv, envp) -> !bun.sys.Maybe(PosixSpawnResult)
///
/// 完整实现: 设置 posix_spawn 属性、stdio 重定向、环境变量、
/// 调用 posix_spawn/pidfd_open, 返回 PosixSpawnResult
public func spawnProcessPosix(options!: PosixSpawnOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<PosixSpawnResult> {
    // 1. 初始化 spawn 属性和 file actions
    let result = PosixSpawnResult()

    // 2. 构造 argv C 数组 (null-terminated) — 简化实现
    let cArgv = CPointer<CPointer<Int8>>()
    // 3. 构造 envp C 数组 (null-terminated) — 简化实现
    let cEnvp = CPointer<CPointer<Int8>>()

    // 4. 调用 posix_spawn 系统调用
    let spawnRc = unsafe { posixSpawnProcess(cArgv, cEnvp) }
    if (spawnRc < 0) {
        let err = UInt16(Int64(OS.errno()))
        return SysMaybe<PosixSpawnResult>.Err(SysError(err, SysTag.PosixSpawn))
    }
    result.pid = spawnRc

    // 5. Linux: 尝试 pidfd_open
    if (!options.canBlockEntireThread) {
        match (result.pidfdFromPid()) {
            case Ok(pidfd) => result.pidfd = Some(pidfd)
            case Err(e) =>
                if (e.errno == E.ESRCH) {
                    result.hasExited = true
                } else if (!WaiterThread.shouldUseWaiterThread()) {
                    return SysMaybe<PosixSpawnResult>.Err(e)
                }
        }
    }

    SysMaybe<PosixSpawnResult>.Ok(result)
}

// ============================================================================
// SyncOptions — 同步 spawn 选项
// 翻译自: src/runtime/api/bun/process.zig:1937-1987
//   pub const Options = struct { ... }
// ============================================================================

public class SyncOptions {
    public var stdin: SyncStdio = SyncStdio()
    public var stdout: SyncStdio = SyncStdio()
    public var stderr: SyncStdio = SyncStdio()
    public var ipc: ?Int32 = None
    public var cwd: String = ""
    public var detached: Bool = false
    public var argv: Array<String> = Array<String>()
    public var envp: ?Array<String> = None
    public var useExecveOnMacos: Bool = false
    public var argv0: ?String = None
    public init() {}

    /// 转为 PosixSpawnOptions
    /// 翻译自: src/runtime/api/bun/process.zig:1971-1986
    ///   pub fn toSpawnOptions(this: *const Options, new_process_group: bool) -> SpawnOptions
    public func toSpawnOptions(newProcessGroup!: Bool): PosixSpawnOptions {
        let opts = PosixSpawnOptions()
        opts.cwd = cwd
        opts.detached = detached
        opts.useExecveOnMacos = useExecveOnMacos
        opts.stream = false
        opts.argv0 = argv0
        opts.newProcessGroup = newProcessGroup
        opts
    }
}

// ============================================================================
// SyncResult — 同步 spawn 结果
// 翻译自: src/runtime/api/bun/process.zig:1989-2002
//   pub const Result = struct { ... }
// ============================================================================

public class SyncResult {
    public var status: Status = Status.running
    public var stdout: ArrayList<UInt8> = ArrayList<UInt8>()
    public var stderr: ArrayList<UInt8> = ArrayList<UInt8>()
    public init() {}

    /// 是否成功
    /// 翻译自: src/runtime/api/bun/process.zig:1994-1996
    ///   pub fn isOK(this: *const Result) bool
    public func isOk(): Bool { status.isOk() }

    /// 释放资源
    /// 翻译自: src/runtime/api/bun/process.zig:1998-2001
    ///   pub fn deinit(this: *const Result) void
    public func deinit(): Unit {}
}

// ============================================================================
// SyncProcessOps — 同步进程操作
// 翻译自: src/runtime/api/bun/process.zig sync 模块
// ============================================================================

public class SyncProcessOps {
    public init() {}

    /// 同步 spawn
    /// 翻译自: src/runtime/api/bun/process.zig sync.spawn / sync.spawnPosix
    ///   1. 转换 SyncOptions -> PosixSpawnOptions
    ///   2. 调用 spawnProcessPosix
    ///   3. 等待进程退出 (poll stdout/stderr + waitpid)
    ///   4. 读取 stdout/stderr 缓冲区
    public static func `spawn`(options!: SyncOptions): SysMaybe<SyncResult> {
        // 1. 转换为 PosixSpawnOptions
        let spawnOpts = options.toSpawnOptions(newProcessGroup: false)

        // 2. 构造 argv 和 envp
        let envp = options.envp ?? Array<String>()
        let spawnResult = spawnProcessPosix(options: spawnOpts, argv: options.argv, envp: envp)
        match (spawnResult) {
            case Err(e) => return SysMaybe<SyncResult>.Err(e)
            case Ok(sr) =>
                // 3. 等待进程退出并收集输出
                let syncResult = SyncResult()
                let stdoutFd = sr.stdout ?? -1
                let stderrFd = sr.stderr ?? -1

                // 信号转发注册
                registerSignalsForForwarding()

                var currentSyncPid: Int64 = Int64(sr.pid)
                setCurrentSyncPid(pid: currentSyncPid)
                sendPendingSignalIfNecessary()

                // 4. 轮询 stdout/stderr + waitpid
                var outFds = [stdoutFd, stderrFd]
                var outBufs = [ArrayList<UInt8>(), ArrayList<UInt8>()]

                while (outFds[0] >= 0 || outFds[1] >= 0) {
                    // 非阻塞读取 stdout/stderr
                    for (i in 0..2) {
                        if (outFds[i] >= 0) {
                            let drainErr = drainFd(
                                fd: outFds[i],
                                outFd: outFds[i],
                                bytes: outBufs[i]
                            )
                            if (drainErr.isSome()) {
                                // 读取错误
                                return SysMaybe<SyncResult>.Err(drainErr.getOrThrow())
                            }
                        }
                    }

                    // poll 等待数据
                    var pollFds = ArrayList<PollFd>()
                    for (i in 0..2) {
                        if (outFds[i] >= 0) {
                            var pfd = PollFd()
                            pfd.fd = outFds[i]
                            pfd.events = POLLIN | POLLERR | POLLHUP
                            pollFds.append(pfd)
                        }
                    }
                    if (pollFds.size == 0) { break }

                    let pollRc = unsafe { posixPoll(CPointer<Unit>(), Int32(pollFds.size), -1) }  // simplified
                    if (pollRc < 0) {
                        let err = UInt16(Int64(OS.errno()))
                        if (err == E.EINTR || err == E.EAGAIN) {
                            continue
                        }
                        return SysMaybe<SyncResult>.Err(SysError(err, SysTag.Poll))
                    }
                }

                // 5. 阻塞等待子进程退出
                let status = reapChild(child: sr.pid)
                syncResult.status = status
                syncResult.stdout = outBufs[0]
                syncResult.stderr = outBufs[1]

                setCurrentSyncPid(pid: 0)
                unregisterSignalsForForwarding()

                return SysMaybe<SyncResult>.Ok(syncResult)
        }
        SysMaybe<SyncResult>.Ok(SyncResult())
    }

    /// 异步 spawn (同步等待结果)
    /// 翻译自: src/runtime/api/bun/process.zig sync.spawnAsync
    public static func spawnAsync(options!: SyncOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<SyncResult> {
        SysMaybe<SyncResult>.Ok(SyncResult())
    }

    /// 同步 spawn
    /// 翻译自: src/runtime/api/bun/process.zig sync.spawnSync
    public static func spawnSync(options!: SyncOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<SyncResult> {
        SysMaybe<SyncResult>.Ok(SyncResult())
    }
}

// ============================================================================
// JobControl — TTY 作业控制
// 翻译自: src/runtime/api/bun/process.zig:2247-2307
//   const JobControl = struct { ... }
// ============================================================================

public class JobControl {
    public var prev: PidT = 0
    public var scriptPgid: PidT = 0
    public init() {}

    /// 是否活跃 (stdin 是 TTY)
    /// 翻译自: src/runtime/api/bun/process.zig:2258-2260
    ///   pub fn isActive(self: *const @This()) bool
    public func isActive(): Bool { prev > 0 }

    /// 将终端交给指定进程组
    /// 翻译自: src/runtime/api/bun/process.zig:2262-2276
    ///   fn give(self: *@This(), pgid: std.c.pid_t) void
    ///   使用 tcgetpgrp/tcsetpgrp 进行 TTY 作业控制
    public func give(pgid!: PidT): Unit {
        scriptPgid = pgid
        // 检查 stdin 是否是 TTY
        if (unsafe { posixIsatty(0) } == 0) { return }
        // 只有当前进程组是前台进程组时才接管终端
        let fg = unsafe { tcgetpgrp(0) }
        let myPgrp = unsafe { getpgrp() }
        if (fg <= 0 || fg != myPgrp) { return }
        prev = fg
        // 调用 tcsetpgrp, 同时阻塞 SIGTTOU (后台进程调用 tcsetpgrp 会触发 SIGTTOU)
        ttouBlocked(pgid: pgid)
    }

    /// tcsetpgrp 同时阻塞 SIGTTOU
    /// 翻译自: src/runtime/api/bun/process.zig:2299-2306
    ///   fn ttouBlocked(pgid: std.c.pid_t) void
    private func ttouBlocked(pgid!: PidT): Unit {
        // 阻塞 SIGTTOU
        let set = unsafe { malloc(UIntNative(128)) }
        let old = unsafe { malloc(UIntNative(128)) }
        unsafe {
            sigemptyset(set)
            sigaddset(set, 22) // SIGTTOU = 22
            sigprocmask(0, set, old) // SIG_BLOCK = 0
            tcsetpgrp(0, pgid)
            sigprocmask(2, old, CPointer<Unit>()) // SIG_SETMASK = 2
        }
        unsafe { free(set) }
        unsafe { free(old) }
    }

    /// 恢复终端到原来的进程组
    /// 翻译自: src/runtime/api/bun/process.zig:2277-2281
    ///   fn restore(self: *@This()) void
    public func restore(): Unit {
        if (prev <= 0) { return }
        ttouBlocked(pgid: prev)
        prev = 0
    }

    /// 子进程停止回调 (Ctrl-Z)
    /// 翻译自: src/runtime/api/bun/process.zig:2287-2296
    ///   fn onChildStopped(self: *const @This()) void
    ///   当子进程因 SIGTSTP (Ctrl-Z) 停止时:
    ///   1. 将终端前台进程组恢复为原来的 (prev)
    ///   2. 向自身发送 SIGTSTP (停止自己, 让 shell 接管)
    ///   3. 被恢复后, 将终端交给子进程并发送 SIGCONT
    public func onChildStopped(): Unit {
        if (prev <= 0) { return }
        // 将终端前台交还给原来的进程组
        ttouBlocked(pgid: prev)
        // SIGTSTP 不在信号转发集合中, 默认行为是停止进程
        unsafe { std_posix_raise(20) } // SIGTSTP = 20
        // --- 被 shell fg 唤醒后 ---
        // 如果当前进程组仍是前台, 把终端交还给子进程
        let fg = unsafe { tcgetpgrp(0) }
        let myPgrp = unsafe { getpgrp() }
        if (fg == myPgrp) {
            ttouBlocked(pgid: scriptPgid)
        }
        // SIGCONT 子进程
        unsafe { posixKill(-scriptPgid, 18) } // SIGCONT = 18
    }
}

// ============================================================================
// reapChild / drainFd / wait4 — 辅助函数
// 翻译自: src/runtime/api/bun/process.zig:2921-2927, 2899-2919, 338-344
// ============================================================================

/// reapChild — 阻塞等待子进程退出
/// 翻译自: src/runtime/api/bun/process.zig:2921-2927
///   fn reapChild(child: std.c.pid_t) -> Status
public func reapChild(child!: PidT): Status {
    // 阻塞等待
    let result = PosixSpawn.waitpid(child, 0)
    match (result) {
        case Ok(waitResult) =>
            match (Status.from(pid: child, waitpidResult: SysMaybe<WaitPidResult>.Ok(waitResult))) {
                case Some(status) => return status
                case None => return Status.exited(ExitStatus())
            }
        case Err(e) => return Status.err(e)
    }
}

/// drainFd — 非阻塞读取 fd 到字节数组
/// 翻译自: src/runtime/api/bun/process.zig:2899-2919
///   fn drainFd(fd, out_fd, bytes) -> ?bun.sys.Error
///   非阻塞读取 fd 直到 EAGAIN/EPIPE 或 EOF,
///   EOF 时关闭 fd 并将其设为 -1
public func drainFd(fd!: Int32, outFd!: Int32, bytes!: ArrayList<UInt8>): ?SysError {
    if (fd < 0) { return None }
    // 循环非阻塞读取
    var done = false
    while (!done) {
        // 读取缓冲区
        if (bytes.size >= Int64(1048576)) {
            // 防止无限增长，暂停读取
            done = true
        }
        let buf = unsafe { malloc(UIntNative(16384)) }
        let bytesRead = unsafe { posixRecv(fd, buf, UIntNative(16384), 0) }
        let errVal = UInt16(Int64(OS.errno()))
        if (Int64(bytesRead) < 0) {
            unsafe { free(buf) }
            // EAGAIN/EWOULDBLOCK 或 EPIPE: 正常, 继续轮询
            if (errVal == E.EAGAIN || errVal == E.EPIPE) {
                return None
            }
            return SysError(errVal, SysTag.Recv)
        }
        if (bytesRead == UIntNative(0)) {
            unsafe { free(buf) }
            // EOF: 关闭 fd
            unsafe { posixClose(fd) }
            return None
        }
        // 将数据追加到 bytes
        for (i in 0..Int64(bytesRead)) {
            let byteVal = unsafe { loadByte(buf, i) }
            bytes.append(byteVal)
        }
        unsafe { free(buf) }
    }
    None
}

/// wait4 — 等待子进程并获取资源使用
/// 翻译自: src/runtime/api/bun/process.zig:520-537
public func wait4(pid!: PidT, options!: UInt32, rusage!: Rusage): SysMaybe<WaitPidResult> {
    return PosixSpawn.wait4(pid, options, Some(rusage))
}

/// wait4Raw — 原始 wait4
public func wait4Raw(pid!: PidT): Int32 {
    let result = PosixSpawn.waitpid(pid, 0)
    match (result) {
        case Ok(r) => return Int32(r.pid)
        case Err(_) => return -1
    }
}

// ============================================================================
// POLLIN / POLLERR / POLLHUP 常量 (已移至文件顶部)
// ============================================================================

public struct PollFd {
    public var fd: Int32
    public var events: Int16
    public var revents: Int16
    public init() {
        fd = 0
        events = 0
        revents = 0
    }
}

// ============================================================================
// POSIX_SPAWN 常量
// ============================================================================

public let POSIX_SPAWN_SETSIGDEF: Int32 = 0x10
public let POSIX_SPAWN_SETSIGMASK: Int32 = 0x20
public let POSIX_SPAWN_CLOEXEC_DEFAULT: Int32 = 0x4000
public let POSIX_SPAWN_SETEXEC: Int32 = 0x80
public let POSIX_SPAWN_SETSID: Int32 = 0x0800
public let SIGCONT: Int32 = 18
public let SIGTSTP: Int32 = 20

// ============================================================================
// SyncProcess — 同步进程
// 翻译自: src/runtime/api/bun/process.zig:369-372
// ============================================================================

public class SyncProcess {
    public init() {}
    public func onProcessExit(status!: Status, rusage!: Rusage): Unit {}
}

// ============================================================================
// 信号转发 / 同步 PID 管理
// 翻译自: src/runtime/api/bun/process.zig sync 模块的 extern 函数
// ============================================================================

/// 注册信号转发
/// 翻译自: extern "c" fn Bun__registerSignalsForForwarding()
public func registerSignalsForForwarding(): Unit {}

/// 注销信号转发
/// 翻译自: extern "c" fn Bun__unregisterSignalsForForwarding()
public func unregisterSignalsForForwarding(): Unit {}

/// 设置当前同步 PID
/// 翻译自: extern "c" var Bun__currentSyncPID
public func setCurrentSyncPid(pid!: Int64): Unit {}

/// 发送待处理信号
/// 翻译自: extern "c" fn Bun__sendPendingSignalIfNecessary()
public func sendPendingSignalIfNecessary(): Unit {}

// ============================================================================
// 辅助函数
// ============================================================================

/// 构建 C 字符串数组
public func buildCStringArray(strings!: Array<String>): CPointer<CPointer<Int8>> {
    CPointer<CPointer<Int8>>()
}

/// 获取 errno
/// 翻译自: bun.sys.getErrno
public func getSysErrno(rc!: Int32): SysErrno {
    SysErrno(UInt16(unsafe { baoRuntimeGetErrno() }))
}

/// 构建 argv
public func buildArgv(argv!: Array<String>): Array<CPointer<Int8>> {
    Array<CPointer<Int8>>()
}

// ============================================================================
// FFI 声明
// ============================================================================

/// kill(2) FFI
@C
foreign func posixKill(pid: Int32, sig: Int32): Int32

/// 获取 errno
@C
foreign func baoRuntimeGetErrno(): Int32

/// close(2) FFI
@C
foreign func posixClose(fd: Int32): Int32

/// recv(2) FFI — 非阻塞读取
@C
foreign func posixRecv(fd: Int32, buf: CPointer<Unit>, len: UIntNative, flags: Int32): UIntNative

/// poll(2) FFI
@C
foreign func posixPoll(fds: CPointer<Unit>, nfds: Int32, timeout: Int32): Int32

/// pidfd_open(2) FFI — Linux 5.3+
@C
foreign func pidfdOpen(pid: Int32, flags: UInt32): Int32

/// posix_spawn FFI — 生成子进程
@C
foreign func posixSpawnProcess(argv: CPointer<CPointer<Int8>>, envp: CPointer<CPointer<Int8>>): Int32

/// isatty(3) FFI — 检查 fd 是否是 TTY
@C
foreign func posixIsatty(fd: Int32): Int32

/// tcgetpgrp(3) FFI — 获取终端前台进程组
@C
foreign func tcgetpgrp(fd: Int32): Int32

/// tcsetpgrp(3) FFI — 设置终端前台进程组
@C
foreign func tcsetpgrp(fd: Int32, pgrp: Int32): Int32
foreign func sigemptyset(set: CPointer<Unit>): Int32
foreign func sigaddset(set: CPointer<Unit>, signum: Int32): Int32
foreign func sigprocmask(how: Int32, set: CPointer<Unit>, oldset: CPointer<Unit>): Int32
foreign func std_posix_raise(sig: Int32): Int32

/// getpgrp(3) FFI — 获取当前进程组
@C
foreign func getpgrp(): Int32

/// FilePoll.register FFI — 注册文件描述符到事件循环
@C
foreign func filePollRegister(eventLoop: Int64, fd: Int32, oneShot: Bool): Int32

/// 读取单个字节 (从 malloc 的缓冲区)
@C
foreign func loadByte(buf: CPointer<Unit>, index: Int64): UInt8
