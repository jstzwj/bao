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
    public func watch(): SysMaybe<Unit> {
        // TODO(bao-runtime-api): 实现 FilePoll / waiter_thread 注册
        // 当前简化: 仅返回成功
        return SysMaybe<Unit>.Ok(())
    }

    /// 重新注册 POSIX poll
    /// 翻译自: src/runtime/api/bun/process.zig:440-464
    ///   pub fn rewatchPosix(this: *Process) bun.sys.Maybe(void)
    public func rewatchPosix(): SysMaybe<Unit> {
        // TODO(bao-runtime-api): 实现 FilePoll 重新注册
        return SysMaybe<Unit>.Ok(())
    }

    /// 关闭进程监控
    /// 翻译自: src/runtime/api/bun/process.zig:511-549
    ///   pub fn close(this: *Process) void
    public func close(): Unit {
        // TODO(bao-runtime-api): 关闭 poller (FilePoll / waiter_thread / uv)
        // Linux: 关闭 pidfd
    }

    /// 禁用事件循环保持活跃
    /// 翻译自: src/runtime/api/bun/process.zig:551-553
    ///   pub fn disableKeepingEventLoopAlive(this: *Process) void
    public func disableKeepingEventLoopAlive(): Unit {
        // TODO(bao-runtime-api): 调用 poller.disableKeepingEventLoopAlive
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
        // TODO(bao-runtime-api): 调用 poller.enableKeepingEventLoopAlive
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
// ============================================================================

public class WaiterThread {
    public init() {}
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
    public func pidfdFromPid(): SysMaybe<PidFDType> {
        // TODO(bao-runtime-api): 实现 pidfd_open 系统调用
        return SysMaybe<PidFDType>.Ok(pidfd ?? 0)
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
/// 委托给 bao_spawn_sys 的 spawnProcessPosix 实现
public func spawnProcessPosix(options!: PosixSpawnOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<PosixSpawnResult> {
    // TODO(bao-runtime-api): 完整实现 — 将 PosixSpawnOptions 转换为
    //   bao_spawn_sys.PosixSpawnOptions 并调用 spawnProcessPosix
    //   当前返回空结果以通过编译
    SysMaybe<PosixSpawnResult>.Ok(PosixSpawnResult())
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
    /// 翻译自: src/runtime/api/bun/process.zig sync.spawn
    public static func `spawn`(options!: SyncOptions): SysMaybe<SyncResult> {
        // TODO(bao-runtime-api): 实现同步 spawn
        //   1. 转换 SyncOptions -> PosixSpawnOptions
        //   2. 调用 spawnProcessPosix
        //   3. 等待进程退出
        //   4. 读取 stdout/stderr
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
    public func give(pgid!: PidT): Unit {
        scriptPgid = pgid
        // TODO(bao-runtime-api): 实现 tcgetpgrp/tcsetpgrp
    }

    /// 恢复终端到原来的进程组
    /// 翻译自: src/runtime/api/bun/process.zig:2277-2281
    ///   fn restore(self: *@This()) void
    public func restore(): Unit {
        if (prev <= 0) { return }
        // TODO(bao-runtime-api): 实现 tcsetpgrp
        prev = 0
    }

    /// 子进程停止回调 (Ctrl-Z)
    /// 翻译自: src/runtime/api/bun/process.zig:2287-2296
    ///   fn onChildStopped(self: *const @This()) void
    public func onChildStopped(): Unit {
        if (prev <= 0) { return }
        // TODO(bao-runtime-api): 实现 SIGTSTP/sigprocmask/tcsetpgrp
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
public func drainFd(fd!: Int32, outFd!: Int32, bytes!: ArrayList<UInt8>): ?SysError {
    // TODO(bao-runtime-api): 实现非阻塞 recv
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
// POLLIN / POLLERR / POLLHUP 常量
// ============================================================================

public let POLLIN: Int16 = 1
public let POLLERR: Int16 = 8
public let POLLHUP: Int16 = 16

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
