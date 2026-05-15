// 严格翻译自: src/runtime/socket/WindowsNamedPipeContext.zig
// Windows Named Pipe 上下文 — 管理 Named Pipe 的生命周期和事件分发
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// WindowsNamedPipeContext
// 对应 Bun: WindowsNamedPipeContext.zig
// 管理 Windows Named Pipe 的引用计数、事件状态和生命周期
// ============================================================================

/// 事件状态
/// 对应 Zig: pub const EventState = enum(u8) { ... }
public enum EventState {
    | DEINIT    // 去初始化事件
    | NONE      // 无事件
}

/// Socket 类型联合
/// 对应 Zig: pub const SocketType = union(enum) { ... }
public enum SocketType {
    | TLS(TLSSocket)   // TLS socket
    | TCP(TCPSocket)   // TCP socket
    | NONE              // 无

    /// 获取 TLS socket (如果是 TLS 类型)
    public func asTls(): ?TLSSocket {
        match (this) {
            case TLS(tls) => tls
            case _ => None
        }
    }

    /// 获取 TCP socket (如果是 TCP 类型)
    public func asTcp(): ?TCPSocket {
        match (this) {
            case TCP(tcp) => tcp
            case _ => None
        }
    }
}

/// Windows Named Pipe 上下文
/// 管理引用计数、Named Pipe 实例和 Socket 类型
/// 使用任务队列在下一个 tick 中去初始化
/// 对应 Zig: const WindowsNamedPipeContext = @This()
public class WindowsNamedPipeContext {
    /// 引用计数
    public var refCount: RefCount
    /// Named Pipe 实例
    public var namedPipe: WindowsNamedPipe
    /// Socket 类型
    public var socket: SocketType

    /// 虚拟机 (用于排队任务)
    public var vm: VirtualMachine
    /// 全局对象
    public var globalThis: JsGlobalObject
    /// 异步任务
    public var task: AnyTask
    /// 任务事件状态
    public var taskEvent: EventState
    /// 是否已打开
    public var isOpen: Bool

    public init() {
        refCount = RefCount()
        namedPipe = WindowsNamedPipe()
        socket = SocketType.NONE
        vm = VirtualMachine()
        globalThis = JsGlobalObject()
        task = AnyTask()
        taskEvent = EventState.NONE
        isOpen = false
    }

    /// 引用
    public func ref(): Unit {
        refCount.ref()
    }

    /// 解引用
    public func deref(): Unit {
        refCount.deref()
    }

    /// 调度去初始化 (当引用计数归零时)
    func scheduleDeinit(): Unit {
        deinitInNextTick()
    }

    // ========================================================================
    // 事件处理器 — 将事件转发到具体的 socket 类型
    // ========================================================================

    /// 连接打开
    /// 对应 Zig: fn onOpen
    func onOpen(): Unit {
        isOpen = true
        match (socket) {
            case TLS(tls) => {
                let s = TLSSocket.Socket.fromNamedPipe(namedPipe)
                tls.onOpen(s)
            }
            case TCP(tcp) => {
                let s = TCPSocket.Socket.fromNamedPipe(namedPipe)
                tcp.onOpen(s)
            }
            case NONE => ()
        }
    }

    /// 数据接收
    /// 对应 Zig: fn onData
    func onData(decodedData: Array<Byte>): Unit {
        match (socket) {
            case TLS(tls) => {
                let s = TLSSocket.Socket.fromNamedPipe(namedPipe)
                tls.onData(s, decodedData)
            }
            case TCP(tcp) => {
                let s = TCPSocket.Socket.fromNamedPipe(namedPipe)
                tcp.onData(s, decodedData)
            }
            case NONE => ()
        }
    }

    /// 握手完成
    /// 对应 Zig: fn onHandshake
    func onHandshake(success: Bool, sslError: UsBunVerifyError): Unit {
        match (socket) {
            case TLS(tls) => {
                let s = TLSSocket.Socket.fromNamedPipe(namedPipe)
                tls.onHandshake(s, if (success) 1 else 0, sslError)
            }
            case TCP(tcp) => {
                let s = TCPSocket.Socket.fromNamedPipe(namedPipe)
                tcp.onHandshake(s, if (success) 1 else 0, sslError)
            }
            case NONE => ()
        }
    }

    /// 连接结束
    /// 对应 Zig: fn onEnd
    func onEnd(): Unit {
        match (socket) {
            case TLS(tls) => {
                let s = TLSSocket.Socket.fromNamedPipe(namedPipe)
                tls.onEnd(s)
            }
            case TCP(tcp) => {
                let s = TCPSocket.Socket.fromNamedPipe(namedPipe)
                tcp.onEnd(s)
            }
            case NONE => ()
        }
    }

    /// 可写
    /// 对应 Zig: fn onWritable
    func onWritable(): Unit {
        match (socket) {
            case TLS(tls) => {
                let s = TLSSocket.Socket.fromNamedPipe(namedPipe)
                tls.onWritable(s)
            }
            case TCP(tcp) => {
                let s = TCPSocket.Socket.fromNamedPipe(namedPipe)
                tcp.onWritable(s)
            }
            case NONE => ()
        }
    }

    /// 错误
    /// 对应 Zig: fn onError
    func onError(err: SysError): Unit {
        if (isOpen) {
            match (socket) {
                case TLS(tls) => {
                    tls.handleError(err.toJS(globalThis))
                }
                case TCP(tcp) => {
                    tcp.handleError(err.toJS(globalThis))
                }
                case NONE => ()
            }
        } else {
            match (socket) {
                case TLS(tls) => {
                    tls.handleConnectError(err.errno)
                }
                case TCP(tcp) => {
                    tcp.handleConnectError(err.errno)
                }
                case NONE => ()
            }
        }
    }

    /// 超时
    /// 对应 Zig: fn onTimeout
    func onTimeout(): Unit {
        match (socket) {
            case TLS(tls) => {
                let s = TLSSocket.Socket.fromNamedPipe(namedPipe)
                tls.onTimeout(s)
            }
            case TCP(tcp) => {
                let s = TCPSocket.Socket.fromNamedPipe(namedPipe)
                tcp.onTimeout(s)
            }
            case NONE => ()
        }
    }

    /// 关闭
    /// 对应 Zig: fn onClose
    func onClose(): Unit {
        let currentSocket = socket
        socket = SocketType.NONE
        match (currentSocket) {
            case TLS(tls) => {
                tls.onClose(TLSSocket.Socket.fromNamedPipe(namedPipe), 0, None)
                tls.deref()
            }
            case TCP(tcp) => {
                tcp.onClose(TCPSocket.Socket.fromNamedPipe(namedPipe), 0, None)
                tcp.deref()
            }
            case NONE => ()
        }

        deref()
    }

    // ========================================================================
    // 任务队列
    // ========================================================================

    /// 运行事件
    func runEvent(): Unit {
        match (taskEvent) {
            case DEINIT => {
                deinit()
            }
            case NONE => panic("Invalid event state")
        }
    }

    /// 在下一个 tick 去初始化
    func deinitInNextTick(): Unit {
        assert(taskEvent != EventState.DEINIT)
        taskEvent = EventState.DEINIT
        vm.enqueueTask(Task.init(task))
    }

    // ========================================================================
    // 工厂方法
    // ========================================================================

    /// 创建 WindowsNamedPipeContext 实例
    /// 对应 Zig: pub fn create
    public static func create(globalThis: JsGlobalObject, socket: SocketType): WindowsNamedPipeContext {
        let vm = globalThis.bunVM()
        let this = WindowsNamedPipeContext()
        this.refCount = RefCount()
        this.vm = vm
        this.globalThis = globalThis
        this.socket = socket
        this.namedPipe = WindowsNamedPipe() // 稍后设置

        // named_pipe 拥有 pipe (PipeWriter 拥有 pipe 并将关闭和去初始化它)
        this.namedPipe = WindowsNamedPipe.from(
            UvPipe(),
            WindowsNamedPipeHandlers(
                refCtx: (ctx: ?Any) => (ctx as WindowsNamedPipeContext).ref(),
                derefCtx: (ctx: ?Any) => (ctx as WindowsNamedPipeContext).deref(),
                onOpen: (ctx: ?Any) => (ctx as WindowsNamedPipeContext).onOpen(),
                onData: (ctx: ?Any, data: Array<Byte>) => (ctx as WindowsNamedPipeContext).onData(data),
                onHandshake: (ctx: ?Any, success: Bool, err: UsBunVerifyError) => (ctx as WindowsNamedPipeContext).onHandshake(success, err),
                onEnd: (ctx: ?Any) => (ctx as WindowsNamedPipeContext).onEnd(),
                onWritable: (ctx: ?Any) => (ctx as WindowsNamedPipeContext).onWritable(),
                onError: (ctx: ?Any, err: SysError) => (ctx as WindowsNamedPipeContext).onError(err),
                onTimeout: (ctx: ?Any) => (ctx as WindowsNamedPipeContext).onTimeout(),
                onClose: (ctx: ?Any) => (ctx as WindowsNamedPipeContext).onClose()
            ),
            vm
        )
        this.task = AnyTask.new(WindowsNamedPipeContext, WindowsNamedPipeContext.runEvent).init(this)

        match (socket) {
            case TLS(tls) => tls.ref()
            case TCP(tcp) => tcp.ref()
            case NONE => ()
        }

        return this
    }

    /// 使用文件描述符打开
    /// owned_ctx 是一个 SSL_CTX_up_ref，由 named_pipe.open 采用 (成功时保留，失败时释放)
    /// 优先使用它而不是 ssl_config，以便缓存的 tls.createSecureContext 能保留其信任存储
    /// 对应 Zig: pub fn open
    public static func open(
        globalThis: JsGlobalObject,
        fd: Fd,
        sslConfig: ?SSLConfig,
        ownedCtx: ?SslCtx,
        socket: SocketType
    ): ?WindowsNamedPipe {
        let this = WindowsNamedPipeContext.create(globalThis, socket)

        try {
            this.namedPipe.open(fd, sslConfig, ownedCtx).unwrap()
        } catch _ {
            match (socket) {
                case TLS(tls) => tls.handleConnectError(SysErrno.ENOENT)
                case TCP(tcp) => tcp.handleConnectError(SysErrno.ENOENT)
                case NONE => ()
            }
            this.deref()
            throw SslError.ConnectionClosed
        }
        return this.namedPipe
    }

    /// 连接到指定路径
    /// 参见 open 中 owned_ctx 的所有权说明
    /// 对应 Zig: pub fn connect
    public static func connect(
        globalThis: JsGlobalObject,
        path: String,
        sslConfig: ?SSLConfig,
        ownedCtx: ?SslCtx,
        socket: SocketType
    ): ?WindowsNamedPipe {
        let this = WindowsNamedPipeContext.create(globalThis, socket)
        try {
            // 需要确保路径以 null 结尾
            if (path[path.size - 1] == '\0') {
                this.namedPipe.connect(path[0:path.size - 1], sslConfig, ownedCtx).unwrap()
            } else {
                // 需要添加 null 终止符
                var pathBuf = Array<Byte>(path.size + 1)
                path.copyTo(pathBuf, 0)
                pathBuf[path.size] = '\0'
                this.namedPipe.connect(pathBuf[0:path.size], sslConfig, ownedCtx).unwrap()
            }
        } catch _ {
            match (socket) {
                case TLS(tls) => tls.handleConnectError(SysErrno.ENOENT)
                case TCP(tcp) => tcp.handleConnectError(SysErrno.ENOENT)
                case NONE => ()
            }
            this.deref()
            throw SslError.ConnectionClosed
        }
        return this.namedPipe
    }

    /// 去初始化
    /// 对应 Zig: pub fn deinit
    public func deinit(): Unit {
        let currentSocket = socket
        socket = SocketType.NONE
        match (currentSocket) {
            case TLS(tls) => tls.deref()
            case TCP(tcp) => tcp.deref()
            case NONE => ()
        }

        namedPipe.deinit()
        // 释放 this
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
public class AnyTask {
    public static func new(cls: Class, method: Func): AnyTask { ... }
    public func initFunc(ctx: Any): AnyTask { ... }
}

/// Task 不透明类型
public class Task {
    public static func initFunc(task: AnyTask): Task { ... }
}

/// VirtualMachine 不透明类型
public class VirtualMachine {
    public func uvLoop(): AsyncLoop { ... }
    public func enqueueTask(task: Task): Unit { ... }
    public func scriptExecutionStatus(): ScriptExecutionStatus { ... }
    public func isShuttingDown(): Bool { ... }
    public var timer: TimerManager
}

/// TimerManager 不透明类型
public class TimerManager {
    public func remove(timer: EventLoopTimer): Unit { ... }
    public func insert(timer: EventLoopTimer): Unit { ... }
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
    public func bunVM(): VirtualMachine { ... }
    public func hasException(): Bool { ... }
    public func throwInvalidArgumentTypeValue(name: String, expected: String, value: JsValue): JsValue { ... }
    public func throw(message: String): JsValue { ... }
    public func ERR(code: String, message: String): SystemError { ... }
}

/// TLSSocket 不透明类型
public class TLSSocket {
    public func onOpen(s: Any): Unit { ... }
    public func onData(s: Any, data: Array<Byte>): Unit { ... }
    public func onHandshake(s: Any, ok: Int32, err: UsBunVerifyError): Unit { ... }
    public func onEnd(s: Any): Unit { ... }
    public func onWritable(s: Any): Unit { ... }
    public func onTimeout(s: Any): Unit { ... }
    public func onClose(s: Any, code: Int32, reason: ?Any): Unit { ... }
    public func handleError(err: JsValue): Unit { ... }
    public func handleConnectError(errno: Int32): Unit { ... }
    public func ref(): Unit { ... }
    public func deref(): Unit { ... }

    public class Socket {
        public static func fromNamedPipe(np: WindowsNamedPipe): Any { ... }
    }
}

/// TCPSocket 不透明类型
public class TCPSocket {
    public func onOpen(s: Any): Unit { ... }
    public func onData(s: Any, data: Array<Byte>): Unit { ... }
    public func onHandshake(s: Any, ok: Int32, err: UsBunVerifyError): Unit { ... }
    public func onEnd(s: Any): Unit { ... }
    public func onWritable(s: Any): Unit { ... }
    public func onTimeout(s: Any): Unit { ... }
    public func onClose(s: Any, code: Int32, reason: ?Any): Unit { ... }
    public func handleError(err: JsValue): Unit { ... }
    public func handleConnectError(errno: Int32): Unit { ... }
    public func ref(): Unit { ... }
    public func deref(): Unit { ... }

    public class Socket {
        public static func fromNamedPipe(np: WindowsNamedPipe): Any { ... }
    }
}
