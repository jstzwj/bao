// 严格翻译自: src/runtime/api/bun/process.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_sys.*

// ============================================================================
// Process - 子进程管理
// 对应 Bun: src/runtime/api/bun/process.zig
// ============================================================================

/// 进程退出处理器
public class ProcessExitHandler {
    var ptr: TaggedPointer = TaggedPointer.Null

    public static func init(this: ProcessExitHandler, ptr: Any) {
        this.ptr = TaggedPointer.init(ptr)
    }

    public func call(process: Process, status: Status, rusage: Rusage) {
        if (this.ptr.isNull()) { return }

        switch (this.ptr.tag()) {
            case "Subprocess" => {
                let subprocess = this.ptr.as(Subprocess)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "LifecycleScriptSubprocess" => {
                let subprocess = this.ptr.as(LifecycleScriptSubprocess)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "ProcessHandle" => {
                let subprocess = this.ptr.as(ProcessHandle)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "MultiRunProcessHandle" => {
                let subprocess = this.ptr.as(MultiRunProcessHandle)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "TestWorkerHandle" => {
                let subprocess = this.ptr.as(TestWorkerHandle)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "ShellSubprocess" => {
                let subprocess = this.ptr.as(ShellSubprocess)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "SecurityScanSubprocess" => {
                let subprocess = this.ptr.as(SecurityScanSubprocess)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "WebViewHostProcess" => {
                let subprocess = this.ptr.as(WebViewHostProcess)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "ChromeProcess" => {
                let subprocess = this.ptr.as(ChromeProcess)
                subprocess.onProcessExit(process, status, rusage)
            }
            case "SyncProcess" => {
                let subprocess = this.ptr.as(SyncProcess)
                subprocess.onProcessExit(status, rusage)
            }
            case "CronRegisterJob" => {
                let cronJob = this.ptr.as(CronRegisterJob)
                cronJob.onProcessExit(process, status, rusage)
            }
            case "CronRemoveJob" => {
                let cronJob = this.ptr.as(CronRemoveJob)
                cronJob.onProcessExit(process, status, rusage)
            }
            else => {
                panic("Internal Bun error: ProcessExitHandler has an invalid tag. Please file a bug report.")
            }
        }
    }
}

/// PidFD 类型 (Linux 使用 fd_t, 其他平台使用 u0)
public typealias PidFDType = Int32

/// 进程状态
public enum Status {
    case running
    case exited(ExitStatus)
    case signaled(SignalCode)
    case err(SysError)

    /// 获取退出码
    public func exitCode(): Int32 {
        return switch (this) {
            case .exited(let exit) => exit.code
            case .signaled(let sig) => 128 + Int32(sig.rawValue)
            else => -1
        }
    }

    /// 获取信号码
    public func signalCode(): SignalCode {
        return switch (this) {
            case .signaled(let sig) => sig
            case .exited(let exit) => exit.signal
            else => null
        }
    }

    /// 从 waitpid 结果创建 Status
    public static func from(pid: PidT, waitpidResult: Maybe<WaitPidResult>): Status {
        return switch (waitpidResult) {
            case .err(let err) => Status.err(err)
            case .result(let result) => {
                if (Posix.W.IFEXITED(result.status)) {
                    return Status.exited(ExitStatus{
                        code = Int32(Posix.W.EXITSTATUS(result.status)),
                        signal = SignalCode(0),
                    })
                }
                if (Posix.W.IFSIGNALED(result.status)) {
                    return Status.signaled(SignalCode(Posix.W.TERMSIG(result.status)))
                }
                return null
            }
        }
    }
}

/// 退出状态
public class ExitStatus {
    var code: Int32
    var signal: SignalCode
}

/// 进程 - 管理一个子进程的生命周期
public class Process {
    var pid: PidT = 0
    var pidfd: PidFDType = 0
    var status: Status = Status.running()
    var poller: Poller = Poller.detached()
    var refCount: RefCount
    var exitHandler: ProcessExitHandler = ProcessExitHandler{}
    var sync: Bool = false
    var eventLoop: EventLoopHandle

    /// 内存占用
    public func memoryCost(): Int64 {
        return Int64(sizeof(Process))
    }

    /// 设置退出处理器
    public func setExitHandler(handler: Any) {
        this.exitHandler.init(handler)
    }

    /// 是否已退出
    public func hasExited(): Bool {
        return switch (this.status) {
            case .exited => true
            case .signaled => true
            case .err => true
            else => false
        }
    }

    /// 是否已被杀死
    public func hasKilled(): Bool {
        return switch (this.status) {
            case .exited, .signaled => true
            else => false
        }
    }

    /// 退出回调
    public func onExit(status: Status, rusage: Rusage) {
        let exitHandler = this.exitHandler
        this.status = status

        if (this.hasExited()) {
            this.detach()
        }

        exitHandler.call(this, status, rusage)
    }

    /// 获取信号码
    public func signalCode(): SignalCode {
        return this.status.signalCode()
    }

    /// POSIX waitpid
    public func waitPosix(sync: Bool) {
        var rusage = zeroes(Rusage)
        let waitpidResult = PosixSpawn.wait4(this.pid, if (sync) 0 else Posix.W.NOHANG, rusage)
        this.onWaitPid(waitpidResult, rusage)
    }

    /// 跨平台等待
    public func wait(sync: Bool) {
        if (Environment.isPosix) {
            this.waitPosix(sync)
        }
        // Windows 使用不同的机制
    }

    /// 处理 waitpid 结果
    public func onWaitPid(waitpidResult: Maybe<WaitPidResult>, rusage: Rusage) {
        let pid = this.pid
        var rusageResult = rusage

        let status = Status.from(pid, waitpidResult) ?? {
            switch (this.rewatchPosix()) {
                case .result => {}
                case .err(let err) => {
                    if (Environment.isMac) {
                        if (err.getErrno() == .SRCH) {
                            return Status.from(pid, PosixSpawn.wait4(pid, 0, rusageResult))
                        }
                    }
                    return Status.err(err)
                }
            }
            return null
        } ?? return

        this.onExit(status, rusageResult)
    }

    /// 观察或收割进程
    public func watchOrReap(): Maybe<Bool> {
        if (this.hasExited()) {
            this.onExit(this.status, zeroes(Rusage))
            return Maybe<Bool>.result(true)
        }

        switch (this.watch()) {
            case .err(let err) => {
                if (Environment.isPosix) {
                    if (err.getErrno() == .SRCH) {
                        this.wait(true)
                        return Maybe<Bool>.result(this.hasExited())
                    }
                }
                return Maybe<Bool>.err(err)
            }
            case .result => return Maybe<Bool>.result(this.hasExited())
        }
    }

    /// 注册进程观察
    public func watch(): Maybe<Unit> {
        if (Environment.isWindows) {
            this.poller.uv.ref()
            return Maybe<Unit>.success
        }

        let watchfd = if (Environment.isLinux) this.pidfd else this.pid
        let poll = if (this.poller == .fd) {
            this.poller.fd
        } else {
            Async.FilePoll.init(this.eventLoop, FD.fromNative(watchfd), Process, this)
        }

        this.poller = Poller.fd(poll)
        this.poller.fd.enableKeepingProcessAlive(this.eventLoop)

        switch (this.poller.fd.register(this.eventLoop.loop(), .process, !Environment.isLinux)) {
            case .result => {
                this.ref()
                return Maybe<Unit>.success
            }
            case .err(let err) => {
                this.poller.fd.disableKeepingProcessAlive(this.eventLoop)
                return Maybe<Unit>.err(err)
            }
        }
    }

    /// 重新注册观察 (POSIX)
    public func rewatchPosix(): Maybe<Unit> {
        if (this.poller == .fd) {
            let maybe = this.poller.fd.register(this.eventLoop.loop(), .process, !Environment.isLinux)
            switch (maybe) {
                case .err => {}
                case .result => this.ref()
            }
            return maybe
        } else {
            panic("Internal Bun error: poll_ref in Subprocess is null unexpectedly. Please file a bug report.")
        }
    }

    /// 关闭进程资源
    public func close() {
        if (Environment.isWindows) {
            if (this.poller == .uv) {
                this.poller.uv.close()
            }
        } else {
            if (this.pidfd != 0) {
                Sys.close(this.pidfd)
                this.pidfd = 0
            }
        }
    }

    /// 分离进程
    public func detach() {
        this.close()
    }

    /// 杀死进程
    public func kill(sig: Int32): Maybe<Unit> {
        if (this.hasExited()) { return Maybe<Unit>.success }

        if (Environment.isWindows) {
            return Sys.kill(this.pid, sig)
        }

        return Sys.kill(this.pid, sig)
    }
}

// ============================================================================
// Poller - 进程轮询器
// ============================================================================

public enum Poller {
    case detached
    case fd(FilePoll)
    case waiter_thread(WaiterThreadPoll)
    case uv(UvProcessT)
}

public class WaiterThreadPoll {
    var refCount: AtomicUInt32 = AtomicUInt32.init(0)
    var pollRef: KeepAlive = KeepAlive()
}

// ============================================================================
// SpawnOptions / SpawnProcessResult / Windows/Posix 结果类型
// ============================================================================

/// 通用 spawn 选项
public class SpawnOptions {
    var stdin: StdioKind
    var stdout: StdioKind
    var stderr: StdioKind
    var cwd: String
    var env: Array<String>
    var argv: Array<String>
    var detached: Bool
    var hideBun: Bool
    var ipc: Bool
}

/// Spawn 结果
public class SpawnProcessResult {
    var pid: PidT
    var hasExited: Bool
}

/// POSIX spawn 结果
public class PosixSpawnResult {
    var pid: PidT
    var pidfd: PidFDType
    var hasExited: Bool
    var extraPipes: ArrayListUnmanaged(ExtraPipe)

    public class ExtraPipe {
        case owned_fd(FD)
        case unowned_fd(FD)
        case unavailable
    }
}

/// Windows spawn 结果
public class WindowsSpawnResult {
    var process: UvProcessT
    var stdioResults: ArrayListUnmanaged(StdioResult)

    public class StdioResult {
        case buffer(UvPipe)
        case null
    }
}

/// 同步 spawn 函数
public class SyncProcessOps {
    /// 同步执行 spawn
    public static func spawnProcess(options: SpawnOptions): Maybe<SpawnProcessResult> {
        // 实现省略 - 依赖于具体的 spawn 系统调用
        return Maybe<SpawnProcessResult>.result(SpawnProcessResult{})
    }
}

// ============================================================================
// 类型别名
// ========================================================================

public typealias PidT = PidT
public typealias Rusage = Rusage
