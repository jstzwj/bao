// Compile-gating API surface for src/runtime/api/bun/process.zig.
package bao_runtime.api

import bao_collections.ArrayList
import bao_jsc.{JsValue}
import bao_sys.*

public class ExtraPipe { public init() {} }
public class SyncStdio { public init() {} }
public class PosixSpawnattrT { public init() {} }
public class PosixSpawnFileActionsT { public init() {} }
public type ModeT = UInt32
public type Maybe<T> = SysMaybe<T>
public type PidT = Int32
public type FdT = Int32
public type PidFDType = Int32

public class SysErrno {
    public let code: UInt16
    public init() { code = 0 }
    public init(code: UInt16) { this.code = code }
    public static let SRCH: SysErrno = SysErrno(E.ESRCH)
    public static let INTR: SysErrno = SysErrno(E.EINTR)
    public static let AGAIN: SysErrno = SysErrno(E.EAGAIN)
    public static let PIPE: SysErrno = SysErrno(32)
}

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

public let processPollOneShot: Bool = true

public class ProcessExitHandler {
    public init() {}
    public static func initFunc(`this`: ProcessExitHandler, ptr!: Any): Unit {}
    public func call(process!: Process, status!: Status, rusage!: Rusage): Unit {}
}

public enum Status {
    | running
    | exited(ExitStatus)
    | signaled(SignalCode)
    | err(SysError)

    public func isOk(): Bool {
        match (this) {
            case exited(exit) => exit.code == UInt8(0)
            case _ => false
        }
    }

    public func signalCode(): ?SignalCode {
        match (this) {
            case signaled(sig) => Some(sig)
            case exited(exit) => Some(exit.signal)
            case _ => None
        }
    }

    public static func from(pid!: PidT, waitpidResult!: SysMaybe<WaitPidResult>): ?Status {
        match (waitpidResult) {
            case Ok(result) =>
                if (result.pid == pid) {
                    Some(Status.exited(ExitStatus(code: UInt8(0), signal: SignalCode.SIGTERM)))
                } else {
                    None
                }
            case Err(e) => Some(Status.err(e))
        }
    }
}

public class ExitStatus {
    public var code: UInt8 = UInt8(0)
    public var signal: SignalCode = SignalCode.SIGTERM
    public init() {}
    public init(code!: UInt8, signal!: SignalCode) {
        this.code = code
        this.signal = signal
    }
}

public func posixWifexited(status!: UInt32): Bool { true }
public func posixWexitstatus(status!: UInt32): UInt8 { UInt8(0) }
public func posixWifsignaled(status!: UInt32): Bool { false }
public func posixWtermsig(status!: UInt32): UInt8 { UInt8(0) }
public func posixWifstopped(status!: UInt32): Bool { false }
public func posixWstopsig(status!: UInt32): UInt8 { UInt8(0) }

public let WNOHANG: UInt32 = 1
public let WUNTRACED: UInt32 = 2

public class Poller {
    public init() {}
    public func deinit(): Unit {}
    public func enableKeepingEventLoopAlive(eventLoop!: EventLoopHandle): Unit {}
    public func disableKeepingEventLoopAlive(eventLoop!: EventLoopHandle): Unit {}
    public func hasRef(): Bool { false }
}

public class WaiterThreadPoll {
    public init() {}
    public func ref(eventLoop!: EventLoopHandle): Unit {}
    public func unref(eventLoop!: EventLoopHandle): Unit {}
    public func disable(): Unit {}
    public func isActive(): Bool { false }
}

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

public class Process {
    public var pid: PidT = 0
    public var pidfd: PidFDType = 0
    public var status: Status = Status.running
    public var poller: Poller = Poller()
    public var eventLoop: EventLoopHandle = EventLoopHandle()
    public var thisValue: JsRef = JsRef.empty()
    public var killed: Bool = false

    public init() {}

    public static func initPosix(posix!: PosixSpawnResult, eventLoop!: EventLoopHandle, sync_!: Bool): Process {
        let process = Process()
        process.pid = posix.pid
        process.pidfd = posix.pidfd
        process.eventLoop = eventLoop
        if (posix.hasExited) {
            process.status = Status.exited(ExitStatus())
        }
        process
    }

    public static func fromFieldParentPtr(field!: String, value!: Any): Process { Process() }
    public static func refProcess(process!: BackRef<Process>): Unit {}
    public static func derefProcess(process!: BackRef<Process>): Unit {}

    public func memoryCost(): Int64 { 0 }
    public func setExitHandler(handler!: Any): Unit {}
    public func updateStatusOnWindows(): Unit {}
    public func hasExited(): Bool {
        match (status) {
            case running => false
            case _ => true
        }
    }
    public func hasKilled(): Bool { killed }
    public func onExit(status!: Status, rusage!: Rusage): Unit { this.status = status }
    public func signalCode(): ?SignalCode { status.signalCode() }
    public func waitPosix(sync_!: Bool): Unit {}
    public func wait(sync_!: Bool): Unit {}
    public func onWaitPidFromWaiterThread(waitpidResult!: SysMaybe<WaitPidResult>, rusage!: Rusage): Unit {}
    public func onWaitPidFromEventLoopTask(): Unit {}
    public func onWaitPid(waitpidResult!: SysMaybe<WaitPidResult>, rusage!: Rusage): Unit {}
    public func watchOrReap(): SysMaybe<Bool> { SysMaybe<Bool>.Ok(false) }
    public func watch(): SysMaybe<Unit> { SysMaybe<Unit>.Ok(()) }
    public func rewatchPosix(): SysMaybe<Unit> { SysMaybe<Unit>.Ok(()) }
    public func close(): Unit {}
    public func disableKeepingEventLoopAlive(): Unit {}
    public func hasRef(): Bool { false }
    public func enableKeepingEventLoopAlive(): Unit {}
    public func detach(): Unit {}
    public func ref(): Unit {}
    public func deref(): Unit {}
    public func onStdinDestroyed(): Unit {}
    public func kill(signal!: Int32): SysMaybe<Unit> {
        killed = true
        SysMaybe<Unit>.Ok(())
    }
    public func deinit(): Unit {}
}

public class WaiterThread { public init() {} }

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
    public init() {}
    public func close(): Unit {}
    public func toProcess(eventLoop!: EventLoopHandle, sync_!: Bool): Process {
        Process.initPosix(posix: this, eventLoop: eventLoop, sync_: sync_)
    }
    public func pidfdFromPid(): SysMaybe<PidFDType> { SysMaybe<PidFDType>.Ok(pidfd) }
}

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

public type SpawnOptions = PosixSpawnOptions
public type SpawnProcessResult = PosixSpawnResult

public func spawnProcess(options!: SpawnOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<SpawnProcessResult> {
    spawnProcessPosix(options: options, argv: argv, envp: envp)
}

public func spawnProcessPosix(options!: PosixSpawnOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<PosixSpawnResult> {
    SysMaybe<PosixSpawnResult>.Ok(PosixSpawnResult())
}

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
    public func toSpawnOptions(newProcessGroup!: Bool): PosixSpawnOptions { PosixSpawnOptions() }
}

public class SyncResult {
    public var status: Status = Status.running
    public var stdout: ArrayList<UInt8> = ArrayList<UInt8>()
    public var stderr: ArrayList<UInt8> = ArrayList<UInt8>()
    public init() {}
    public func isOk(): Bool { status.isOk() }
    public func deinit(): Unit {}
}

public class SyncProcessOps {
    public init() {}
    public static func `spawn`(options!: SyncOptions): SysMaybe<SyncResult> {
        SysMaybe<SyncResult>.Ok(SyncResult())
    }
    public static func spawnAsync(options!: SyncOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<SyncResult> {
        SysMaybe<SyncResult>.Ok(SyncResult())
    }
    public static func spawnSync(options!: SyncOptions, argv!: Array<String>, envp!: Array<String>): SysMaybe<SyncResult> {
        SysMaybe<SyncResult>.Ok(SyncResult())
    }
}

public class JobControl {
    public var prev: PidT = 0
    public var scriptPgid: PidT = 0
    public init() {}
    public func isActive(): Bool { false }
    public func give(pgid!: PidT): Unit {}
    public func restore(): Unit {}
    public func onChildStopped(): Unit {}
}

public func reapChild(child!: PidT): Status { Status.exited(ExitStatus()) }
public func drainFd(fd!: Int32, outFd!: Int32, bytes!: ArrayList<UInt8>): ?SysError { None }
public func wait4(pid!: PidT, options!: UInt32, rusage!: Rusage): SysMaybe<WaitPidResult> {
    let result = WaitPidResult()
    result.pid = pid
    result.status = 0
    SysMaybe<WaitPidResult>.Ok(result)
}
public func wait4Raw(pid!: PidT): Int32 { 0 }

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

public let POSIX_SPAWN_SETSIGDEF: Int32 = 0x10
public let POSIX_SPAWN_SETSIGMASK: Int32 = 0x20
public let POSIX_SPAWN_CLOEXEC_DEFAULT: Int32 = 0x4000
public let POSIX_SPAWN_SETEXEC: Int32 = 0x80
public let POSIX_SPAWN_SETSID: Int32 = 0x0800
public let SIGCONT: Int32 = 18
public let SIGTSTP: Int32 = 20

public class SyncProcess {
    public init() {}
    public func onProcessExit(status!: Status, rusage!: Rusage): Unit {}
}

public func registerSignalsForForwarding(): Unit {}
public func unregisterSignalsForForwarding(): Unit {}
public func setCurrentSyncPid(pid!: Int64): Unit {}
public func sendPendingSignalIfNecessary(): Unit {}
public func buildCStringArray(strings!: Array<String>): CPointer<CPointer<Int8>> { CPointer<CPointer<Int8>>() }
public func getErrno(rc!: Int32): SysErrno { SysErrno() }
public func buildArgv(argv!: Array<String>): Array<CPointer<Int8>> { Array<CPointer<Int8>>() }
