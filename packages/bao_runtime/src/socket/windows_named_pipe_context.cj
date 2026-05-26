// 严格翻译自: src/runtime/socket/WindowsNamedPipeContext.zig
// Windows Named Pipe 上下文 — 管理 Named Pipe 的生命周期和事件分发
package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.{JsValue, JsGlobalObject}
import bao_uws_sys.{UsBunVerifyError}

// ============================================================================
// WindowsNamedPipeContext
// 对应 Bun: WindowsNamedPipeContext.zig
// Stub: 完整实现需要 libuv FFI 绑定和跨类型事件分发
// ============================================================================

/// 事件状态
public enum EventState {
    | DEINIT
    | NONE

    public operator func ==(right: EventState): Bool {
        match (this) {
            case DEINIT =>
                match (right) {
                    case DEINIT => true
                    case _ => false
                }
            case NONE =>
                match (right) {
                    case NONE => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: EventState): Bool {
        return !(this == right)
    }
}

/// Socket 类型联合
public enum SocketType {
    | WNP_TLS
    | WNP_TCP
    | NONE
}

/// Windows Named Pipe 上下文
public class WindowsNamedPipeContext {
    public var refCount: RefCount
    public var namedPipe: ?WindowsNamedPipe
    public var socket: SocketType
    public var vm: VirtualMachine
    public var globalThis: JsGlobalObject
    public var task: AnyTask
    public var taskEvent: EventState
    public var isOpen: Bool
    public var tlsSocket: ?TLSSocket
    public var tcpSocket: ?TcpSocketWnp

    public init() {
        refCount = RefCount()
        namedPipe = None
        socket = SocketType.NONE
        vm = VirtualMachine()
        globalThis = JsGlobalObject()
        task = AnyTask()
        taskEvent = EventState.NONE
        isOpen = false
        tlsSocket = None
        tcpSocket = None
    }

    public func ref(): Unit {
        refCount.ref()
    }

    public func deref(): Unit {
        refCount.deref()
    }

    func scheduleDeinit(): Unit {
        deinitInNextTick()
    }

    // ========================================================================
    // 事件处理器 — Stub
    // ========================================================================

    func onOpen(): Unit {
        isOpen = true
        match (socket) {
            case WNP_TLS => if (tlsSocket.isSome()) { tlsSocket.getOrThrow().onOpen(namedPipe) }
            case WNP_TCP => if (tcpSocket.isSome()) { tcpSocket.getOrThrow().onOpen(namedPipe) }
            case NONE => ()
        }
    }

    func onData(decodedData: Array<Byte>): Unit {
        match (socket) {
            case WNP_TLS => if (tlsSocket.isSome()) { tlsSocket.getOrThrow().onData(namedPipe, decodedData) }
            case WNP_TCP => if (tcpSocket.isSome()) { tcpSocket.getOrThrow().onData(namedPipe, decodedData) }
            case NONE => ()
        }
    }

    func onHandshake(success: Bool, sslError: UsBunVerifyError): Unit {
        let ok: Int32 = if (success) { 1 } else { 0 }
        match (socket) {
            case WNP_TLS => if (tlsSocket.isSome()) { tlsSocket.getOrThrow().onHandshake(namedPipe, ok, sslError) }
            case WNP_TCP => if (tcpSocket.isSome()) { tcpSocket.getOrThrow().onHandshake(namedPipe, ok, sslError) }
            case NONE => ()
        }
    }

    func onEnd(): Unit {
        match (socket) {
            case WNP_TLS => if (tlsSocket.isSome()) { tlsSocket.getOrThrow().onEnd(namedPipe) }
            case WNP_TCP => if (tcpSocket.isSome()) { tcpSocket.getOrThrow().onEnd(namedPipe) }
            case NONE => ()
        }
    }

    func onWritable(): Unit {
        match (socket) {
            case WNP_TLS => if (tlsSocket.isSome()) { tlsSocket.getOrThrow().onWritable(namedPipe) }
            case WNP_TCP => if (tcpSocket.isSome()) { tcpSocket.getOrThrow().onWritable(namedPipe) }
            case NONE => ()
        }
    }

    func onError(err: SysError): Unit {
        let errValue = JsValue("Windows named pipe error")
        match (socket) {
            case WNP_TLS => if (tlsSocket.isSome()) { tlsSocket.getOrThrow().handleError(errValue) }
            case WNP_TCP => if (tcpSocket.isSome()) { tcpSocket.getOrThrow().handleError(errValue) }
            case NONE => ()
        }
    }

    func onTimeout(): Unit {
        match (socket) {
            case WNP_TLS => if (tlsSocket.isSome()) { tlsSocket.getOrThrow().onTimeout(namedPipe) }
            case WNP_TCP => if (tcpSocket.isSome()) { tcpSocket.getOrThrow().onTimeout(namedPipe) }
            case NONE => ()
        }
    }

    func onClose(): Unit {
        socket = SocketType.NONE
        deref()
    }

    // ========================================================================
    // 任务队列
    // ========================================================================

    func runEvent(): Unit {
        match (taskEvent) {
            case DEINIT =>
                deinit()
            case NONE => throw Exception("Invalid event state")
        }
    }

    func deinitInNextTick(): Unit {
        if (taskEvent == EventState.DEINIT) {
            return
        }
        taskEvent = EventState.DEINIT
        vm.enqueueTask(Task())
    }

    // ========================================================================
    // 工厂方法
    // ========================================================================

    public static func create(globalThis: JsGlobalObject, socket: SocketType): WindowsNamedPipeContext {
        let vm = globalThis.bunVM()
        let result = WindowsNamedPipeContext()
        result.refCount = RefCount()
        result.vm = vm
        result.globalThis = globalThis
        result.socket = socket

        let handlers = WindowsNamedPipeHandlers(
            { ctx: ?Any => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.ref() } },
            { ctx: ?Any => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.deref() } },
            { ctx: ?Any => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.onOpen() } },
            { ctx: ?Any, success: Bool, err: UsBunVerifyError => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.onHandshake(success, err) } },
            { ctx: ?Any, data: Array<Byte> => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.onData(data) } },
            { ctx: ?Any => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.onClose() } },
            { ctx: ?Any => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.onEnd() } },
            { ctx: ?Any => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.onWritable() } },
            { ctx: ?Any, err: SysError => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.onError(err) } },
            { ctx: ?Any => if (ctx is WindowsNamedPipeContext) { let wnp = (ctx as WindowsNamedPipeContext).getOrThrow(); wnp.onTimeout() } }
        )

        result.namedPipe = WindowsNamedPipe(vm, handlers)
        result.task = AnyTask()

        return result
    }

    public static func open(
        globalThis: JsGlobalObject,
        fd: Fd,
        sslConfig: ?SSLConfig,
        ownedCtx: ?SslCtx,
        socket: SocketType
    ): ?WindowsNamedPipe {
        let result = WindowsNamedPipeContext.create(globalThis, socket)
        if (result.namedPipe.isSome()) {
            let np = result.namedPipe.getOrThrow()
            np.open(fd, sslConfig, ownedCtx)
        }
        return result.namedPipe
    }

    public static func connect(
        globalThis: JsGlobalObject,
        path: String,
        sslConfig: ?SSLConfig,
        ownedCtx: ?SslCtx,
        socket: SocketType
    ): ?WindowsNamedPipe {
        let result = WindowsNamedPipeContext.create(globalThis, socket)
        if (result.namedPipe.isSome()) {
            let np = result.namedPipe.getOrThrow()
            np.connect(path, sslConfig, ownedCtx)
        }
        return result.namedPipe
    }

    public func deinit(): Unit {
        socket = SocketType.NONE
        if (namedPipe.isSome()) {
            namedPipe.getOrThrow().deinit()
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 引用计数
public class RefCount {
    private var count: Int64

    public init() {
        count = 1
    }

    public func ref(): Unit {
        count += 1
    }

    public func deref(): Unit {
        count -= 1
        if (count == 0) {
            // 触发去初始化
        }
    }

    public func getCount(): Int64 {
        return count
    }
}

/// AnyTask 不透明类型
public class AnyTask {}

/// Task 不透明类型
public class Task {}

/// VirtualMachine 不透明类型
public class VirtualMachine {
    public var timer: TimerManager

    public init() {
        timer = TimerManager()
    }

    public func uvLoop(): AsyncLoop { AsyncLoop() }
    public func enqueueTask(task: Task): Unit {}
    public func scriptExecutionStatus(): ScriptExecutionStatus { ScriptExecutionStatus.RUNNING }
    public func isShuttingDown(): Bool { false }
}

/// TimerManager 不透明类型
public class TimerManager {
    public func remove(timer: EventLoopTimer): Unit {}
    public func insert(timer: EventLoopTimer): Unit {}
}

/// EventLoopTimer
public class EventLoopTimer {
    public var next: Timespec
    public var state: TimerState
    public var heap: TimerHeap
    public var tag: EventLoopTimerTag

    public init(tag: EventLoopTimerTag) {
        this.next = Timespec()
        this.state = TimerState.CANCELLED
        this.heap = TimerHeap()
        this.tag = tag
    }
}

/// JsGlobalObject 不透明类型
public class JsGlobalObject {
    public func bunVM(): VirtualMachine { VirtualMachine() }
    public func hasException(): Bool { false }
    public func throwInvalidArgumentTypeValue(name: String, expected: String, value: JsValue): JsValue {
        JsValue.jsUndefined()
    }
    public func `throw`(message: String): JsValue { JsValue.jsUndefined() }
}

/// TLSSocket 不透明类型
public class TLSSocket {
    public func onOpen(s: ?WindowsNamedPipe): Unit {}
    public func onData(s: ?WindowsNamedPipe, data: Array<Byte>): Unit {}
    public func onHandshake(s: ?WindowsNamedPipe, ok: Int32, err: UsBunVerifyError): Unit {}
    public func onEnd(s: ?WindowsNamedPipe): Unit {}
    public func onWritable(s: ?WindowsNamedPipe): Unit {}
    public func onTimeout(s: ?WindowsNamedPipe): Unit {}
    public func onClose(s: ?WindowsNamedPipe, code: Int32, reason: ?Any): Unit {}
    public func handleError(err: JsValue): Unit {}
    public func handleConnectError(errno: Int32): Unit {}
    public func ref(): Unit {}
    public func deref(): Unit {}
}

/// TcpSocketWnp 不透明类型 (避免与其他包的 TCPSocket 冲突)
public class TcpSocketWnp {
    public func onOpen(s: ?WindowsNamedPipe): Unit {}
    public func onData(s: ?WindowsNamedPipe, data: Array<Byte>): Unit {}
    public func onHandshake(s: ?WindowsNamedPipe, ok: Int32, err: UsBunVerifyError): Unit {}
    public func onEnd(s: ?WindowsNamedPipe): Unit {}
    public func onWritable(s: ?WindowsNamedPipe): Unit {}
    public func onTimeout(s: ?WindowsNamedPipe): Unit {}
    public func onClose(s: ?WindowsNamedPipe, code: Int32, reason: ?Any): Unit {}
    public func handleError(err: JsValue): Unit {}
    public func handleConnectError(errno: Int32): Unit {}
    public func ref(): Unit {}
    public func deref(): Unit {}
}
