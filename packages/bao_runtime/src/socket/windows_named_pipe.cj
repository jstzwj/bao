// 严格翻译自: src/runtime/socket/WindowsNamedPipe.zig
// Windows 命名管道 — 为 Windows Named Pipes 提供 socket 风格 API
package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// WindowsNamedPipe
// 对应 Bun: WindowsNamedPipe.zig
// 为 Windows Named Pipes 提供 socket 风格的 API
// 注意: 此文件包含大量 stub — 完整实现需要 libuv FFI 绑定
// ============================================================================

/// Windows Named Pipe 标志
public class WindowsNamedPipeFlags {
    public var disconnected: Bool
    public var isClosed: Bool
    public var isClient: Bool
    public var isSsl: Bool

    public init() {
        disconnected = true
        isClosed = false
        isClient = false
        isSsl = false
    }
}

/// Windows Named Pipe 回调处理器
public class WindowsNamedPipeHandlers {
    public var ctx: ?Any
    public var refCtx: (?Any) -> Unit
    public var derefCtx: (?Any) -> Unit
    public var onOpen: (?Any) -> Unit
    public var onHandshake: (?Any, Bool, UsBunVerifyError) -> Unit
    public var onData: (?Any, Array<Byte>) -> Unit
    public var onClose: (?Any) -> Unit
    public var onEnd: (?Any) -> Unit
    public var onWritable: (?Any) -> Unit
    public var onError: (?Any, SysError) -> Unit
    public var onTimeout: (?Any) -> Unit

    public init(
        refCtx: (?Any) -> Unit,
        derefCtx: (?Any) -> Unit,
        onOpen: (?Any) -> Unit,
        onHandshake: (?Any, Bool, UsBunVerifyError) -> Unit,
        onData: (?Any, Array<Byte>) -> Unit,
        onClose: (?Any) -> Unit,
        onEnd: (?Any) -> Unit,
        onWritable: (?Any) -> Unit,
        onError: (?Any, SysError) -> Unit,
        onTimeout: (?Any) -> Unit
    ) {
        this.ctx = None
        this.refCtx = refCtx
        this.derefCtx = derefCtx
        this.onOpen = onOpen
        this.onHandshake = onHandshake
        this.onData = onData
        this.onClose = onClose
        this.onEnd = onEnd
        this.onWritable = onWritable
        this.onError = onError
        this.onTimeout = onTimeout
    }
}

/// Windows Named Pipe
public class WindowsNamedPipe {
    public var wrapper: ?SslWrapper<WindowsNamedPipe>
    public var pipe: ?UvPipe
    public var vm: VirtualMachine
    public var writer: StreamingWriter<WindowsNamedPipe>
    public var incoming: ByteList
    public var `sslError`: UsBunVerifyError
    public var handlers: WindowsNamedPipeHandlers
    public var connectReq: UvConnectT
    public var eventLoopTimer: EventLoopTimer
    public var currentTimeout: UInt32
    public var flags: WindowsNamedPipeFlags

    public init(vm: VirtualMachine, handlers: WindowsNamedPipeHandlers) {
        this.wrapper = None
        this.pipe = None
        this.vm = vm
        this.writer = StreamingWriter()
        this.incoming = ByteList()
        this.sslError = UsBunVerifyError()
        this.handlers = handlers
        this.connectReq = UvConnectT()
        this.eventLoopTimer = EventLoopTimer(EventLoopTimerTag.WINDOWS_NAMED_PIPE)
        this.currentTimeout = 0
        this.flags = WindowsNamedPipeFlags()
    }

    // ========================================================================
    // 内部回调
    // ========================================================================

    func onWritableInternal(): Unit {
        flush()
        if (handlers.ctx.isSome()) {
            handlers.onWritable(handlers.ctx)
        }
    }

    func onPipeClose(): Unit {
        flags.disconnected = true
        pipe = None
        onCloseInternal()
    }

    func onReadAlloc(suggestedSize: Int64): Array<Byte> {
        var available = incoming.unusedCapacitySlice()
        if (available.size < suggestedSize) {
            incoming.ensureUnusedCapacity(suggestedSize)
            available = incoming.unusedCapacitySlice()
        }
        if (available.size >= suggestedSize) {
            return available[0..suggestedSize]
        }
        return []
    }

    func onReadInternal(buffer: Array<Byte>): Unit {
        incoming.len += buffer.size
        let data = incoming.slice()
        resetTimeout()

        if (wrapper.isSome()) {
            wrapper.getOrThrow().receiveData(data)
        } else {
            if (handlers.ctx.isSome()) {
                handlers.onData(handlers.ctx, data)
            }
        }
        incoming.len = 0
    }

    func onWriteInternal(amount: Int64, status: WriteStatus): Unit {
        match (status) {
            case PENDING => ()
            case DRAINED =>
                if (pipe.isSome()) {
                    pipe.getOrThrow().unref()
                }
            case END_OF_FILE =>
                writer.close()
        }
    }

    func onReadErrorInternal(err: SysErrno): Unit {
        if (err == SysErrno.EOF) {
            if (handlers.ctx.isSome()) {
                handlers.onEnd(handlers.ctx)
            }
        } else {
            onErrorInternal(SysError.fromCode(err, SyscallType.READ))
        }
        writer.close()
    }

    func onErrorInternal(err: SysError): Unit {
        if (handlers.ctx.isSome()) {
            handlers.onError(handlers.ctx, err)
        }
        close()
    }

    func onOpenInternal(): Unit {
        if (handlers.ctx.isSome()) {
            handlers.onOpen(handlers.ctx)
        }
    }

    func onDataInternal(decodedData: Array<Byte>): Unit {
        if (handlers.ctx.isSome()) {
            handlers.onData(handlers.ctx, decodedData)
        }
    }

    func onHandshakeInternal(handshakeSuccess: Bool, sslErr: UsBunVerifyError): Unit {
        this.sslError = UsBunVerifyError(
            sslErr.errorNo,
            if (sslErr.errorNo == 0) { "" } else { sslErr.code },
            if (sslErr.errorNo == 0) { "" } else { sslErr.reason }
        )
        if (handlers.ctx.isSome()) {
            handlers.onHandshake(handlers.ctx, handshakeSuccess, sslErr)
        }
    }

    func onCloseInternal(): Unit {
        if (!flags.isClosed) {
            flags.isClosed = true
            if (handlers.ctx.isSome()) {
                handlers.onClose(handlers.ctx)
            }
            deinit()
        }
    }

    // ========================================================================
    // 写入操作
    // ========================================================================

    func callWriteOrEnd(data: ?Array<Byte>, msgMore: Bool): Unit {
        if (data.isSome()) {
            let bytes = data.getOrThrow()
            if (bytes.size > 0) {
                if (pipe.isSome()) {
                    pipe.getOrThrow().ref()
                }
                if (flags.disconnected) {
                    writer.outgoing.write(bytes)
                } else {
                    writer.write(bytes)
                }
            }
        }

        if (!msgMore) {
            if (wrapper.isSome()) {
                wrapper.getOrThrow().shutdown(false)
            }
            writer.end()
        }
    }

    func internalWrite(encodedData: Array<Byte>): Unit {
        resetTimeout()
        callWriteOrEnd(encodedData, true)
    }

    // ========================================================================
    // 公共 API
    // ========================================================================

    public func resumeStream(): Bool {
        return false
    }

    public func pauseStream(): Bool {
        if (pipe.isNone()) {
            return false
        }
        pipe.getOrThrow().readStop()
        return true
    }

    public func flush(): Unit {
        if (wrapper.isSome()) {
            wrapper.getOrThrow().flush()
        }
        if (!flags.disconnected) {
            writer.flush()
        }
    }

    public func onTimeout(): Unit {
        let hasBeenCleared = eventLoopTimer.state == TimerState.CANCELLED

        eventLoopTimer.state = TimerState.FIRED

        if (hasBeenCleared) {
            return
        }

        if (handlers.ctx.isSome()) {
            handlers.onTimeout(handlers.ctx)
        }
    }

    public static func from(pipe: UvPipe, handlers: WindowsNamedPipeHandlers, vm: VirtualMachine): WindowsNamedPipe {
        let result = WindowsNamedPipe(vm, handlers)
        result.pipe = pipe
        return result
    }

    public func ref(): Unit {
        if (handlers.ctx.isSome()) {
            handlers.refCtx(handlers.ctx)
        }
    }

    public func deref(): Unit {
        if (handlers.ctx.isSome()) {
            handlers.derefCtx(handlers.ctx)
        }
    }

    func onConnect(status: UvReturnCode): Unit {
        deref()
        if (pipe.isSome()) {
            pipe.getOrThrow().unref()
        }
        flags.disconnected = false
        onOpenInternal()
        flush()
    }

    public func getAcceptedBy(server: UvPipe, sslCtx: ?SslCtx): SysMaybeVoid {
        flags.disconnected = true
        flags.disconnected = false
        onOpenInternal()
        return SysMaybeVoid.SUCCESS
    }

    public func open(fd: Fd, sslOptions: ?SSLConfig, ownedCtx: ?SslCtx): SysMaybeVoid {
        flags.disconnected = true
        flags.disconnected = false
        onConnect(UvReturnCode.ZERO)
        return SysMaybeVoid.SUCCESS
    }

    public func connect(path: String, sslOptions: ?SSLConfig, ownedCtx: ?SslCtx): SysMaybeVoid {
        flags.disconnected = true
        if (pipe.isSome()) {
            pipe.getOrThrow().ref()
        }
        ref()
        return SysMaybeVoid.SUCCESS
    }

    func initTLSWrapper(sslOptions: ?SSLConfig, ownedCtx: ?SslCtx): ?SysMaybeVoid {
        // Stub: TLS wrapper initialization
        return None
    }

    public func startTLS(sslOptions: SSLConfig, isClient: Bool): Unit {
        flags.isSsl = true
    }

    public func start(isClient: Bool): Bool {
        flags.isClient = isClient
        if (pipe.isNone()) {
            return false
        }
        return true
    }

    public func isTLS(): Bool {
        return flags.isSsl
    }

    public func loop(): AsyncLoop {
        return AsyncLoop()
    }

    public func encodeAndWrite(data: Array<Byte>): Int32 {
        if (wrapper.isSome()) {
            return Int32(wrapper.getOrThrow().writeData(data))
        } else {
            internalWrite(data)
        }
        return Int32(data.size)
    }

    public func rawWrite(encodedData: Array<Byte>): Int32 {
        internalWrite(encodedData)
        return Int32(encodedData.size)
    }

    public func close(): Unit {
        if (wrapper.isSome()) {
            wrapper.getOrThrow().shutdown(false)
        }
        writer.end()
    }

    public func shutdown(): Unit {
        if (wrapper.isSome()) {
            wrapper.getOrThrow().shutdown(false)
        }
    }

    public func shutdownRead(): Unit {
        if (wrapper.isSome()) {
            wrapper.getOrThrow().shutdownRead()
        }
    }

    public func isShutdown(): Bool {
        if (wrapper.isSome()) {
            return wrapper.getOrThrow().isShutdown()
        }
        return flags.disconnected || writer.isDone
    }

    public func isClosed(): Bool {
        if (wrapper.isSome()) {
            return wrapper.getOrThrow().isClosed()
        }
        return flags.disconnected
    }

    public func isEstablished(): Bool {
        return !isClosed()
    }

    public func ssl(): ?Ssl {
        if (wrapper.isSome()) {
            return wrapper.getOrThrow().ssl
        }
        return None
    }

    public func getSslError(): UsBunVerifyError {
        return UsBunVerifyError(sslError.errorNo, sslError.code, sslError.reason)
    }

    public func resetTimeout(): Unit {
        setTimeoutInMilliseconds(currentTimeout)
    }

    public func setTimeoutInMilliseconds(ms: UInt32): Unit {
        currentTimeout = ms
    }

    public func setTimeout(seconds: UInt32): Unit {
        setTimeoutInMilliseconds(seconds * UInt32(1000))
    }

    public func deinit(): Unit {
        setTimeout(UInt32(0))
        writer.deinit()
        if (wrapper.isSome()) {
            wrapper.getOrThrow().deinit()
            wrapper = None
        }
        sslError = UsBunVerifyError()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 系统错误
public class SysError {
    public var errno: Int32
    public var syscall: Syscall

    public init() {
        errno = 0
        syscall = Syscall.CONNECT
    }

    public init(errno: Int32, syscall: Syscall) {
        this.errno = errno
        this.syscall = syscall
    }

    public static func fromCode(code: SysErrno, syscall: SyscallType): SysError {
        SysError(0, Syscall.CONNECT)
    }
}

/// 系统调用类型
public enum SyscallType {
    | READ
    | WRITE
    | CONNECT
    | ACCEPT
}

/// 系统调用
public enum Syscall {
    | CONNECT
    | READ
    | WRITE
}

/// 系统错误码
public enum SysErrno {
    | EOF
    | PIPE
    | ENOENT

    public operator func ==(right: SysErrno): Bool {
        match (this) {
            case EOF =>
                match (right) {
                    case EOF => true
                    case _ => false
                }
            case PIPE =>
                match (right) {
                    case PIPE => true
                    case _ => false
                }
            case ENOENT =>
                match (right) {
                    case ENOENT => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: SysErrno): Bool {
        return !(this == right)
    }
}

/// 系统调用结果 (Void)
public enum SysMaybeVoid {
    | SUCCESS
    | ERR(Int32, Syscall)

    public func isErr(): Bool {
        match (this) {
            case SUCCESS => false
            case ERR(_, _) => true
        }
    }

    public static func err(errno: Int32, syscall: Syscall): SysMaybeVoid {
        return SysMaybeVoid.ERR(errno, syscall)
    }

    public func isSome(): Bool { true }
}

/// 写入状态
public enum WriteStatus {
    | PENDING
    | DRAINED
    | END_OF_FILE
}

/// UvPipe 不透明类型
public class UvPipe {
    public func ref(): Unit {}
    public func unref(): Unit {}
    public func readStop(): Unit {}
}

/// UvConnectT 不透明类型
public class UvConnectT {
    public var data: ?Any

    public init() {
        data = None
    }
}

/// UvReturnCode
public class UvReturnCode {
    public var value: Int32

    public init(value: Int32) {
        this.value = value
    }

    public static let ZERO = UvReturnCode(0)
}

/// Fd 类型别名
public type Fd = Int32

/// ByteList 类型
public class ByteList {
    public var len: Int64
    public var cap: Int64

    public init() {
        len = 0
        cap = 0
    }

    public func unusedCapacitySlice(): Array<Byte> { [] }
    public func ensureUnusedCapacity(count: Int64): Unit {}
    public func slice(): Array<Byte> { [] }
    public func allocatedSlice(): Array<Byte> { [] }
    public func write(data: Array<Byte>): Unit {}
}

/// StreamingWriter 不透明类型
public class StreamingWriter<T> {
    public var source: ?T
    public var outgoing: ByteList
    public var isDone: Bool

    public init() {
        source = None
        outgoing = ByteList()
        isDone = false
    }

    public func setParent(parent: T): Unit {}
    public func startWithPipe(pipe: UvPipe): SysMaybeVoid { SysMaybeVoid.SUCCESS }
    public func getStream(): ?Stream { None }
    public func write(data: Array<Byte>): Int64 { 0 }
    public func flush(): Int64 { 0 }
    public func end(): Unit {}
    public func close(): Unit {}
    public func deinit(): Unit {}
}

/// Stream 不透明类型
public class Stream {
    public func readStop(): Unit {}
}

/// AsyncLoop 不透明类型
public class AsyncLoop {}

/// TimerHeap 不透明类型
public class TimerHeap {}

/// Timespec 辅助
public class Timespec {
    public static func msFromNow(ms: UInt32): Timespec { Timespec() }
}
