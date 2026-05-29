// BAO_STUB: compile gate for src/runtime/api/bun/subprocess.rs.
// TODO(bao-runtime-api): restore the Bun one-to-one Subprocess implementation.
package bao_runtime.api

import bao_collections.ArrayList
import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame}
import bao_sys.*

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

    public func toExitCode(): ?Int32 { Some(128 + rawValue) }
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
    public static func fromJS(v!: Any, globalThis!: JsGlobalObject): SignalCode { SignalCode.SIGTERM }
}

public enum MaxBufKind { | maxStdout | maxStderr }
public enum ApiStdioKind { | apiStdin | apiStdout | apiStderr }

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

public class Signal {
    public var ptr: Int64 = 0
    public init() {}
    public func clear(): Unit { ptr = 0 }
    public func get(): Signal { this }
}

public class MaxBuf {
    public init() {}
    public static func createForSubprocess(owner!: Subprocess, slot!: ?MaxBuf, initial!: ?Int64): Unit {}
    public static func removeFromSubprocess(slot!: ?MaxBuf): Unit {}
    public static func addToPipeReader(limit!: ?MaxBuf, readerMaxbuf!: Any): Unit {}
}

public class TimerAll {
    public init() {}
    public func incrementTimerRef(delta!: Int32, uwsLoop!: Any): Unit {}
    public func remove(timer!: Any): Unit {}
}

public class CowString {
    public init() {}
    public static func initOwned(s!: String): CowString { CowString() }
}

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

public class JscHooks {
    public static func timerAllMut(): TimerAll { TimerAll() }
}

public class EnumSet<T> {
    public init() {}
    public func insert(value!: T): Unit {}
    public func remove(value!: T): Unit {}
    public func contains(value!: T): Bool { false }
}

public enum StdioResult {
    | owned
    | unowned
    | unavailable
}

public enum ObservableGetter {
    | observableStdin
    | observableStdout
    | observableStderr
}

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

// BAO_STUB: compile gate for src/runtime/api/bun/subprocess.rs intrusive ref_count.
// TODO(bao-runtime-api): replace with bao_core.ptr.RefCount once Subprocess ownership/destructor is restored.
public class SubprocessRefCount {
    public init() {}
    public func ref(): Unit {}
    public func deref(): Unit {}
}

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

    public static func assertStdioResult(result!: StdioResult): Unit {}
    public static func fromFieldParentPtr(field!: String, value!: Any): Subprocess { Subprocess() }
    public static func fromJS(value!: JsValue): ?Subprocess { None }
    public static func timerAll(): TimerAll { TimerAll() }
    public static func `spawn`(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue { JsValue.jsUndefined() }
    public static func spawnSync(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue { JsValue.jsUndefined() }
    public static func toJSFromPtr(ptr!: Subprocess, global!: JsGlobalObject): JsValue { JSSubprocess.toJS(ptr: ptr, global: global) }
    public static func consumeExitedPromise(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue { JsValue.jsUndefined() }
    public static func consumeOnExitCallback(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue { JsValue.jsUndefined() }
    public static func consumeOnDisconnectCallback(thisJsvalue!: JsValue, globalThis!: JsGlobalObject): JsValue { JsValue.jsUndefined() }

    public func getProcess(): Process { process.get() }
    public func processMut(): Process { process.get() }
    public func getGlobalThis(): JsGlobalObject { globalThis.get() }
    public func getGlobalThisOptional(): ?JsGlobalObject { Some(globalThis.get()) }
    public func memoryCost(): Int64 { 0 }
    public func hasExited(): Bool { getProcess().hasExited() }
    public func hasKilled(): Bool { flags.killed || getProcess().hasKilled() }
    public func ref(): Unit {}
    public func deref(): Unit {}
    public func jsRef(): Unit {}
    public func jsUnref(): Unit {}
    public func updateHasPendingActivity(): Unit {}
    public func updateFlags(fn!: (SubprocessFlags) -> Unit): Unit { fn(flags) }
    public func onCloseIO(kind!: ApiStdioKind): Unit { closed.insert(value: kind) }
    public func onStdinDestroyed(): Unit {
        weakFileSinkStdinPtr = None
        flags.hasStdinDestructorCalled = true
    }
    public func onProcessExit(process!: Process, status!: Status, rusage!: Rusage): Unit {
        pidRusage = Some(rusage)
        this.process.get().status = status
    }
    public func onMaxBuffer(kind!: MaxBufKind): Unit { exitedDueToMaxbuf = Some(kind) }
    public func handleAbortSignal(reason!: JsValue): Unit { _ = tryKill(sig: killSignal) }
    public static func onAbortSignal(ctx!: Unit, reason!: JsValue): Unit {}
    public func tryKill(sig!: SignalCode): Maybe<Unit> {
        flags.killed = true
        getProcess().kill(signal: sig.rawValue)
    }
    public func kill(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        _ = tryKill(sig: SignalCode.SIGTERM)
        JsValue.jsUndefined()
    }
    public func doRef(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue { JsValue.jsUndefined() }
    public func doUnref(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue { JsValue.jsUndefined() }
    public func disconnect(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue { JsValue.jsUndefined() }
    public func disconnectIPC(nextTick!: Bool): Unit {}
    public func ipc(): ?IPCSendQueue { ipcData }
    public func abortSignalRef(): ?BackRef<AbortSignal> {
        match (abortSignal) {
            case Some(signal) => Some(BackRef<AbortSignal>.from(value: signal))
            case None => None
        }
    }
    public func clearAbortSignal(): Unit { abortSignal = None }
    public func setEventLoopTimerRefd(value!: Bool): Unit { eventLoopTimerRefd = value }
    public func doSend(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue { JsValue.jsUndefined() }
    public func handleIPCMessage(message!: IPCDecodedIPCMessage, handle!: JsValue): Unit {}
    public func handleIPCClose(): Unit {}
    public func closeIO(io!: ApiStdioKind): Unit { closed.insert(value: io) }
    public func close(): Unit {
        stdin.close()
        stdout.close()
        stderr.close()
    }
    public func finalize(): Unit { flags.finalized = true }
    public func getStdin(globalThis!: JsGlobalObject): JsValue { stdin.toJS(globalThis: globalThis, subprocess: this) }
    public func getStdout(globalThis!: JsGlobalObject): JsValue { stdout.toJS(globalThis: globalThis, exited: hasExited()) }
    public func getStderr(globalThis!: JsGlobalObject): JsValue { stderr.toJS(globalThis: globalThis, exited: hasExited()) }
    public func getExited(thisValue!: JsValue, globalThis!: JsGlobalObject): JsValue { JsValue.jsUndefined() }
    public func getExitCode(globalThis!: JsGlobalObject): JsValue {
        match (getProcess().status) {
            case exited(exit) => JsValue.jsNumber(Int64(exit.code))
            case _ => JsValue.jsNull()
        }
    }
    public func getSignalCode(global!: JsGlobalObject): JsValue { JsValue.jsNull() }
}

public class TestingAPIs {
    public static func injectStdioReadError(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        JsValue.jsBoolean(false)
    }
}
