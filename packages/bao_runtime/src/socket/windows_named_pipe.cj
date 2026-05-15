// 严格翻译自: src/runtime/socket/WindowsNamedPipe.zig
// Windows 命名管道 — 为 Windows Named Pipes 提供 socket 风格 API
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// WindowsNamedPipe
// 对应 Bun: WindowsNamedPipe.zig
// 为 Windows Named Pipes 提供 socket 风格的 API
// 允许跨平台使用相同的网络接口和事件处理模式
// 将 Named Pipes 视为常规 socket，在 µWebSockets 的 socket API 和 Windows Named Pipe 操作之间进行桥接
// ============================================================================

/// Windows Named Pipe 标志
/// 对应 Zig: pub const Flags = packed struct(u8) { ... }
public class WindowsNamedPipeFlags {
    /// 是否已断开连接
    public var disconnected: Bool
    /// 是否已关闭
    public var isClosed: Bool
    /// 是否为客户端
    public var isClient: Bool
    /// 是否使用 SSL
    public var isSsl: Bool

    public init() {
        disconnected = true
        isClosed = false
        isClient = false
        isSsl = false
    }
}

/// Windows Named Pipe 回调处理器
/// 对应 Zig: pub const Handlers = struct { ... }
public class WindowsNamedPipeHandlers {
    /// 上下文
    public var ctx: ?Any
    /// 引用上下文
    public var refCtx: (?Any) -> Unit
    /// 解引用上下文
    public var derefCtx: (?Any) -> Unit
    /// 连接打开回调
    public var onOpen: (?Any) -> Unit
    /// 握手完成回调
    public var onHandshake: (?Any, Bool, UsBunVerifyError) -> Unit
    /// 数据接收回调
    public var onData: (?Any, Array<Byte>) -> Unit
    /// 连接关闭回调
    public var onClose: (?Any) -> Unit
    /// 连接结束回调
    public var onEnd: (?Any) -> Unit
    /// 可写回调
    public var onWritable: (?Any) -> Unit
    /// 错误回调
    public var onError: (?Any, SysError) -> Unit
    /// 超时回调
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
/// 使用 libuv 进行底层 Named Pipe 操作，同时保持与 µWebSockets 的兼容性
/// 弥合 libuv 的 pipe 处理和 uSockets 统一 socket 接口之间的差距
public class WindowsNamedPipe {
    /// SSL 包装器
    public var wrapper: ?SslWrapper<WindowsNamedPipe>
    /// libuv Pipe 句柄
    public var pipe: ?UvPipe
    /// 虚拟机
    public var vm: VirtualMachine
    /// 流式写入器
    public var writer: StreamingWriter<WindowsNamedPipe>
    /// 接收缓冲区
    public var incoming: ByteList
    /// SSL 错误信息
    public var sslError: CertError
    /// 事件处理器
    public var handlers: WindowsNamedPipeHandlers
    /// 连接请求
    public var connectReq: UvConnectT
    /// 事件循环定时器
    public var eventLoopTimer: EventLoopTimer
    /// 当前超时时间
    public var currentTimeout: UInt32
    /// 状态标志
    public var flags: WindowsNamedPipeFlags

    public init(vm: VirtualMachine, handlers: WindowsNamedPipeHandlers) {
        this.wrapper = None
        this.pipe = None
        this.vm = vm
        this.writer = StreamingWriter()
        this.incoming = ByteList()
        this.sslError = CertError()
        this.handlers = handlers
        this.connectReq = UvConnectT()
        this.eventLoopTimer = EventLoopTimer(tag: EventLoopTimerTag.WINDOWS_NAMED_PIPE)
        this.currentTimeout = 0
        this.flags = WindowsNamedPipeFlags()
    }

    // ========================================================================
    // 内部回调
    // ========================================================================

    /// 可写回调
    func onWritableInternal(): Unit {
        flush()
        if (handlers.ctx != None) {
            handlers.onWritable(handlers.ctx)
        }
    }

    /// Pipe 关闭回调
    func onPipeClose(): Unit {
        flags.disconnected = true
        pipe = None
        onCloseInternal()
    }

    /// 读取分配回调
    func onReadAlloc(suggestedSize: Int64): Array<Byte> {
        var available = incoming.unusedCapacitySlice()
        if (available.size < suggestedSize) {
            incoming.ensureUnusedCapacity(suggestedSize)
            available = incoming.unusedCapacitySlice()
        }
        return available[0:suggestedSize]
    }

    /// 读取回调
    func onReadInternal(buffer: Array<Byte>): Unit {
        incoming.len += buffer.size

        let data = incoming.slice()
        resetTimeout()

        if (wrapper != None) {
            wrapper.receiveData(data)
        } else {
            if (handlers.ctx != None) {
                handlers.onData(handlers.ctx, data)
            }
        }
        incoming.len = 0
    }

    /// 写入回调
    func onWriteInternal(amount: Int64, status: WriteStatus): Unit {
        match (status) {
            case PENDING => {}
            case DRAINED => {
                // 发送完所有数据后取消引用
                if (writer.source != None) {
                    writer.source.pipe.unref()
                }
            }
            case END_OF_FILE => {
                // 发送 FIN 后关闭
                writer.close()
            }
        }
    }

    /// 读取错误回调
    func onReadErrorInternal(err: SysErrno): Unit {
        if (err == SysErrno.EOF) {
            // 收到 FIN 但目前不允许半开连接
            if (handlers.ctx != None) {
                handlers.onEnd(handlers.ctx)
            }
        } else {
            onErrorInternal(SysError.fromCode(err, SyscallType.READ))
        }
        writer.close()
    }

    /// 错误回调
    func onErrorInternal(err: SysError): Unit {
        if (handlers.ctx != None) {
            handlers.onError(handlers.ctx, err)
        }
        close()
    }

    /// 打开回调
    func onOpenInternal(): Unit {
        if (handlers.ctx != None) {
            handlers.onOpen(handlers.ctx)
        }
    }

    /// 数据回调 (解密后)
    func onDataInternal(decodedData: Array<Byte>): Unit {
        if (handlers.ctx != None) {
            handlers.onData(handlers.ctx, decodedData)
        }
    }

    /// 握手回调
    func onHandshakeInternal(handshakeSuccess: Bool, sslError: UsBunVerifyError): Unit {
        this.sslError = CertError(
            errorNo: sslError.errorNo,
            code: if (sslError.code == None || sslError.errorNo == 0) { "" } else { sslError.code },
            reason: if (sslError.reason == None || sslError.errorNo == 0) { "" } else { sslError.reason }
        )
        if (handlers.ctx != None) {
            handlers.onHandshake(handlers.ctx, handshakeSuccess, sslError)
        }
    }

    /// 关闭回调
    func onCloseInternal(): Unit {
        if (!flags.isClosed) {
            flags.isClosed = true
            if (handlers.ctx != None) {
                handlers.onClose(handlers.ctx)
            }
            deinit()
        }
    }

    // ========================================================================
    // 写入操作
    // ========================================================================

    /// 调用写入或结束
    func callWriteOrEnd(data: ?Array<Byte>, msgMore: Bool): Unit {
        if (data != None) {
            let bytes = data
            if (bytes.size > 0) {
                // 引用因为有待发送数据
                if (writer.source != None) {
                    writer.source.pipe.ref()
                }
                if (flags.disconnected) {
                    // 排队等待连接后发送
                    writer.outgoing.write(bytes)
                } else {
                    writer.write(bytes)
                }
            }
        }

        if (!msgMore) {
            if (wrapper != None) {
                wrapper.shutdown(false)
            }
            writer.end()
        }
    }

    /// 内部写入 (加密后数据)
    func internalWrite(encodedData: Array<Byte>): Unit {
        resetTimeout()
        callWriteOrEnd(encodedData, true)
    }

    // ========================================================================
    // 公共 API
    // ========================================================================

    /// 恢复流
    public func resumeStream(): Bool {
        let stream = writer.getStream()
        if (stream == None) {
            return false
        }
        let readStartResult = stream.readStart(this, onReadAlloc, onReadErrorInternal, onReadInternal)
        if (readStartResult.isErr()) {
            return false
        }
        return true
    }

    /// 暂停流
    public func pauseStream(): Bool {
        if (pipe == None) {
            return false
        }
        pipe.readStop()
        return true
    }

    /// 刷新缓冲数据
    public func flush(): Unit {
        if (wrapper != None) {
            wrapper.flush()
        }
        if (!flags.disconnected) {
            writer.flush()
        }
    }

    /// 超时回调
    public func onTimeout(): Unit {
        let hasBeenCleared = eventLoopTimer.state == TimerState.CANCELLED ||
                             vm.scriptExecutionStatus() != ScriptExecutionStatus.RUNNING

        eventLoopTimer.state = TimerState.FIRED
        eventLoopTimer.heap = TimerHeap()

        if (hasBeenCleared) {
            return
        }

        if (handlers.ctx != None) {
            handlers.onTimeout(handlers.ctx)
        }
    }

    /// 创建 WindowsNamedPipe 实例
    /// 对应 Zig: pub fn from
    public static func from(pipe: UvPipe, handlers: WindowsNamedPipeHandlers, vm: VirtualMachine): WindowsNamedPipe {
        let result = WindowsNamedPipe(vm: vm, handlers: handlers)
        result.pipe = pipe
        return result
    }

    /// 引用上下文
    public func ref(): Unit {
        if (handlers.ctx != None) {
            handlers.refCtx(handlers.ctx)
        }
    }

    /// 解引用上下文
    public func deref(): Unit {
        if (handlers.ctx != None) {
            handlers.derefCtx(handlers.ctx)
        }
    }

    /// 连接回调
    func onConnect(status: UvReturnCode): Unit {
        defer deref()
        if (pipe != None) {
            pipe.unref()
        }

        if (status.toError(UvSyscall.CONNECT) != None) {
            onErrorInternal(status.toError(UvSyscall.CONNECT))
            return
        }

        flags.disconnected = false
        if (start(true)) {
            if (isTLS()) {
                if (wrapper != None) {
                    wrapper.start()
                }
            } else {
                onOpenInternal()
            }
        }
        flush()
    }

    /// 被服务器接受
    /// 对应 Zig: pub fn getAcceptedBy
    public func getAcceptedBy(server: UvPipe, sslCtx: ?SslCtx): SysMaybeVoid {
        assert(pipe != None)
        flags.disconnected = true

        if (sslCtx != None) {
            flags.isSsl = true
            try {
                let sslHandlers = SslWrapperHandlers<WindowsNamedPipe>(
                    onOpen: (ctx: WindowsNamedPipe) => ctx.onOpenInternal(),
                    onHandshake: (ctx: WindowsNamedPipe, success: Bool, err: UsBunVerifyError) => ctx.onHandshakeInternal(success, err),
                    write: (ctx: WindowsNamedPipe, data: Array<Byte>) => ctx.internalWrite(data),
                    onData: (ctx: WindowsNamedPipe, data: Array<Byte>) => ctx.onDataInternal(data),
                    onClose: (ctx: WindowsNamedPipe) => ctx.onCloseInternal()
                )
                wrapper = SslWrapper.initWithCTX(sslCtx, false, this, sslHandlers)
            } catch _: SslError {
                return SysMaybeVoid.err(
                    errno: SysErrno.PIPE,
                    syscall: Syscall.CONNECT
                )
            }
            // 引用因为正在接受，wrapper deinit 时会取消引用
            BoringSSL.sslCtxUpRef(sslCtx)
        }

        let initResult = pipe.init(vm.uvLoop(), false)
        if (initResult.isErr()) {
            return initResult
        }

        let openResult = server.accept(pipe)
        if (openResult.isErr()) {
            return openResult
        }

        flags.disconnected = false
        if (start(false)) {
            if (isTLS()) {
                if (wrapper != None) {
                    wrapper.start()
                }
            } else {
                onOpenInternal()
            }
        }
        return SysMaybeVoid.SUCCESS
    }

    /// 使用文件描述符打开
    /// 对应 Zig: pub fn open
    public func open(fd: Fd, sslOptions: ?SSLConfig, ownedCtx: ?SslCtx): SysMaybeVoid {
        assert(pipe != None)
        flags.disconnected = true

        let tlsResult = initTLSWrapper(sslOptions, ownedCtx)
        if (tlsResult != None && tlsResult.isErr()) {
            return tlsResult
        }

        let initResult = pipe.init(vm.uvLoop(), false)
        if (initResult.isErr()) {
            return initResult
        }

        let openResult = pipe.open(fd)
        if (openResult.isErr()) {
            return openResult
        }

        ref()
        onConnect(UvReturnCode.ZERO)
        return SysMaybeVoid.SUCCESS
    }

    /// 连接到指定路径
    /// 对应 Zig: pub fn connect
    public func connect(path: String, sslOptions: ?SSLConfig, ownedCtx: ?SslCtx): SysMaybeVoid {
        assert(pipe != None)
        flags.disconnected = true
        pipe.ref()

        let tlsResult = initTLSWrapper(sslOptions, ownedCtx)
        if (tlsResult != None && tlsResult.isErr()) {
            return tlsResult
        }

        let initResult = pipe.init(vm.uvLoop(), false)
        if (initResult.isErr()) {
            return initResult
        }

        connectReq.data = this
        let result = pipe.connect(connectReq, path, this, onConnect)
        if (result.asErr() != None) {
            return result
        }
        ref()
        return result
    }

    /// 初始化 TLS 包装器
    /// 返回 None 当两者都不请求 TLS 时
    func initTLSWrapper(sslOptions: ?SSLConfig, ownedCtx: ?SslCtx): ?SysMaybeVoid {
        let sslHandlers = SslWrapperHandlers<WindowsNamedPipe>(
            onOpen: (ctx: WindowsNamedPipe) => ctx.onOpenInternal(),
            onHandshake: (ctx: WindowsNamedPipe, success: Bool, err: UsBunVerifyError) => ctx.onHandshakeInternal(success, err),
            write: (ctx: WindowsNamedPipe, data: Array<Byte>) => ctx.internalWrite(data),
            onData: (ctx: WindowsNamedPipe, data: Array<Byte>) => ctx.onDataInternal(data),
            onClose: (ctx: WindowsNamedPipe) => ctx.onCloseInternal()
        )
        if (ownedCtx != None) {
            flags.isSsl = true
            try {
                wrapper = SslWrapper.initWithCTX(ownedCtx, true, this, sslHandlers)
            } catch _ {
                BoringSSL.sslCtxFree(ownedCtx)
                return SysMaybeVoid.err(errno: SysErrno.PIPE, syscall: Syscall.CONNECT)
            }
            return SysMaybeVoid.SUCCESS
        }
        if (sslOptions != None) {
            flags.isSsl = true
            try {
                wrapper = SslWrapper.init(sslOptions, true, this, sslHandlers)
            } catch _ {
                return SysMaybeVoid.err(errno: SysErrno.PIPE, syscall: Syscall.CONNECT)
            }
            return SysMaybeVoid.SUCCESS
        }
        return None
    }

    /// 启动 TLS
    /// 对应 Zig: pub fn startTLS
    public func startTLS(sslOptions: SSLConfig, isClient: Bool): Unit {
        flags.isSsl = true
        if (start(isClient)) {
            let sslHandlers = SslWrapperHandlers<WindowsNamedPipe>(
                onOpen: (ctx: WindowsNamedPipe) => ctx.onOpenInternal(),
                onHandshake: (ctx: WindowsNamedPipe, success: Bool, err: UsBunVerifyError) => ctx.onHandshakeInternal(success, err),
                write: (ctx: WindowsNamedPipe, data: Array<Byte>) => ctx.internalWrite(data),
                onData: (ctx: WindowsNamedPipe, data: Array<Byte>) => ctx.onDataInternal(data),
                onClose: (ctx: WindowsNamedPipe) => ctx.onCloseInternal()
            )
            wrapper = SslWrapper.init(sslOptions, isClient, this, sslHandlers)
            wrapper.start()
        }
    }

    /// 启动管道读写
    /// 对应 Zig: pub fn start
    public func start(isClient: Bool): Bool {
        flags.isClient = isClient
        if (pipe == None) {
            return false
        }
        pipe.unref()
        writer.setParent(this)
        let startPipeResult = writer.startWithPipe(pipe)
        if (startPipeResult.isErr()) {
            onErrorInternal(startPipeResult.err)
            return false
        }
        let stream = writer.getStream()
        if (stream == None) {
            onErrorInternal(SysError.fromCode(SysErrno.PIPE, SyscallType.READ))
            return false
        }

        let readStartResult = stream.readStart(this, onReadAlloc, onReadErrorInternal, onReadInternal)
        if (readStartResult.isErr()) {
            onErrorInternal(readStartResult.err)
            return false
        }
        return true
    }

    /// 是否使用 TLS
    public func isTLS(): Bool {
        return flags.isSsl
    }

    /// 获取事件循环
    public func loop(): AsyncLoop {
        return vm.uvLoop()
    }

    /// 编码并写入数据
    public func encodeAndWrite(data: Array<Byte>): Int32 {
        if (wrapper != None) {
            return wrapper.writeData(data).toInt32()
        } else {
            internalWrite(data)
        }
        return data.size.toInt32()
    }

    /// 原始写入
    public func rawWrite(encodedData: Array<Byte>): Int32 {
        internalWrite(encodedData)
        return encodedData.size.toInt32()
    }

    /// 关闭连接
    public func close(): Unit {
        if (wrapper != None) {
            wrapper.shutdown(false)
        }
        writer.end()
    }

    /// 优雅关闭
    public func shutdown(): Unit {
        if (wrapper != None) {
            wrapper.shutdown(false)
        }
    }

    /// 关闭读取方向
    public func shutdownRead(): Unit {
        if (wrapper != None) {
            wrapper.shutdownRead()
        } else {
            let stream = writer.getStream()
            if (stream != None) {
                stream.readStop()
            }
        }
    }

    /// 是否已关闭
    public func isShutdown(): Bool {
        if (wrapper != None) {
            return wrapper.isShutdown()
        }
        return flags.disconnected || writer.isDone
    }

    /// 是否完全关闭
    public func isClosed(): Bool {
        if (wrapper != None) {
            return wrapper.isClosed()
        }
        return flags.disconnected
    }

    /// 是否已建立连接
    public func isEstablished(): Bool {
        return !isClosed()
    }

    /// 获取 SSL 对象
    public func ssl(): ?Ssl {
        if (wrapper != None) {
            return wrapper.ssl
        }
        return None
    }

    /// 获取 SSL 错误
    public func sslError(): UsBunVerifyError {
        return UsBunVerifyError(
            errorNo: sslError.errorNo,
            code: sslError.code,
            reason: sslError.reason
        )
    }

    /// 重置超时
    public func resetTimeout(): Unit {
        setTimeoutInMilliseconds(currentTimeout)
    }

    /// 设置超时 (毫秒)
    public func setTimeoutInMilliseconds(ms: UInt32): Unit {
        if (eventLoopTimer.state == TimerState.ACTIVE) {
            vm.timer.remove(eventLoopTimer)
        }
        currentTimeout = ms
        if (ms == 0) {
            return
        }
        eventLoopTimer.next = Timespec.msFromNow(ms)
        vm.timer.insert(eventLoopTimer)
    }

    /// 设置超时 (秒)
    public func setTimeout(seconds: UInt32): Unit {
        setTimeoutInMilliseconds(seconds * 1000)
    }

    /// 释放资源 (可多次调用)
    public func deinit(): Unit {
        setTimeout(0)
        let stream = writer.getStream()
        if (stream != None) {
            stream.readStop()
        }
        writer.deinit()
        if (wrapper != None) {
            wrapper.deinit()
            wrapper = None
        }
        sslError.deinit()
        sslError = CertError()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 系统错误
public class SysError {
    public var errno: Int32
    public var syscall: Syscall

    public init(errno: Int32, syscall: Syscall) {
        this.errno = errno
        this.syscall = syscall
    }

    public static func fromCode(code: SysErrno, syscall: SyscallType): SysError { ... }
    public func toJS(globalObject: JsGlobalObject): JsValue { ... }
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
}

/// 写入状态
public enum WriteStatus {
    | PENDING
    | DRAINED
    | END_OF_FILE
}

/// UvPipe 不透明类型
public class UvPipe {
    public func init(loop: AsyncLoop, ipc: Bool): SysMaybeVoid { ... }
    public func open(fd: Fd): SysMaybeVoid { ... }
    public func accept(client: UvPipe): SysMaybeVoid { ... }
    public func connect(req: UvConnectT, path: String, ctx: Any, callback: (UvReturnCode) -> Unit): SysMaybeVoid { ... }
    public func ref(): Unit { ... }
    public func unref(): Unit { ... }
    public func readStop(): Unit { ... }
}

/// UvConnectT 不透明类型
public class UvConnectT {
    public var data: ?Any
}

/// UvReturnCode
public class UvReturnCode {
    public static let ZERO = UvReturnCode(0)
    public func toError(syscall: UvSyscall): ?SysError { ... }
}

/// UvSyscall
public enum UvSyscall {
    | CONNECT
}

/// Fd 类型别名
public typealias Fd = Int32

/// ByteList 类型
public class ByteList {
    public var len: Int64
    public var cap: Int64

    public init() {
        len = 0
        cap = 0
    }

    public func unusedCapacitySlice(): Array<Byte> { ... }
    public func ensureUnusedCapacity(count: Int64): Unit { ... }
    public func slice(): Array<Byte> { ... }
    public func allocatedSlice(): Array<Byte> { ... }
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

    public func setParent(parent: T): Unit { ... }
    public func startWithPipe(pipe: UvPipe): SysMaybeVoid { ... }
    public func getStream(): ?Stream { ... }
    public func write(data: Array<Byte>): Int64 { ... }
    public func flush(): Int64 { ... }
    public func end(): Unit { ... }
    public func close(): Unit { ... }
    public func deinit(): Unit { ... }
}

/// Stream 不透明类型
public class Stream {
    public func readStart(
        ctx: Any,
        onAlloc: (Int64) -> Array<Byte>,
        onError: (SysErrno) -> Unit,
        onRead: (Array<Byte>) -> Unit
    ): SysMaybeVoid { ... }
    public func readStop(): Unit { ... }
}

/// AsyncLoop 不透明类型
public class AsyncLoop {}

/// TimerHeap 不透明类型
public class TimerHeap {}

/// Timespec 辅助
public class Timespec {
    public static func msFromNow(ms: UInt32): Timespec { ... }
}
