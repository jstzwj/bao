// 严格翻译自: src/runtime/socket/UpgradedDuplex.zig
// UpgradedDuplex — 为 Node.js 风格双工流提供 TLS/SSL 加密
package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_uws_sys.{UsBunVerifyError}

// ============================================================================
// UpgradedDuplex
// 对应 Bun: UpgradedDuplex struct
// 为非传统网络 socket 的双工流提供 TLS/SSL 加密
// ============================================================================

/// 证书错误信息
public class CertError {
    public var errorNo: Int32
    public var code: String
    public var reason: String

    public init() {
        errorNo = 0
        code = ""
        reason = ""
    }

    public init(errorNo: Int32, code: String, reason: String) {
        this.errorNo = errorNo
        this.code = code
        this.reason = reason
    }

    public func deinit(): Unit {}
}

/// UpgradedDuplex 回调处理器
public class UpgradedDuplexHandlers {
    public var ctx: ?Any
    public var onOpen: (?Any) -> Unit
    public var onHandshake: (?Any, Bool, UsBunVerifyError) -> Unit
    public var onData: (?Any, Array<Byte>) -> Unit
    public var onClose: (?Any) -> Unit
    public var onEnd: (?Any) -> Unit
    public var onWritable: (?Any) -> Unit
    public var onError: (?Any, JsValue) -> Unit
    public var onTimeout: (?Any) -> Unit

    public init(
        onOpen: (?Any) -> Unit,
        onHandshake: (?Any, Bool, UsBunVerifyError) -> Unit,
        onData: (?Any, Array<Byte>) -> Unit,
        onClose: (?Any) -> Unit,
        onEnd: (?Any) -> Unit,
        onWritable: (?Any) -> Unit,
        onError: (?Any, JsValue) -> Unit,
        onTimeout: (?Any) -> Unit
    ) {
        this.ctx = None
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

/// UpgradedDuplex 为 Node.js 风格的双工流提供 TLS/SSL 加密
public class UpgradedDuplex {
    public var wrapper: ?SslWrapper<UpgradedDuplex>
    public var origin: StrongOptional<JsValue>
    public var global: ?JsGlobalObject
    public var `sslError`: UsBunVerifyError
    public var vm: VirtualMachine
    public var handlers: UpgradedDuplexHandlers
    public var onDataCallback: StrongOptional<JsValue>
    public var onEndCallback: StrongOptional<JsValue>
    public var onWritableCallback: StrongOptional<JsValue>
    public var onCloseCallback: StrongOptional<JsValue>
    public var eventLoopTimer: EventLoopTimer
    public var currentTimeout: UInt32

    public init(vm: VirtualMachine, handlers: UpgradedDuplexHandlers) {
        this.wrapper = None
        this.origin = StrongOptional<JsValue>.empty()
        this.global = None
        this.sslError = UsBunVerifyError()
        this.vm = vm
        this.handlers = handlers
        this.onDataCallback = StrongOptional<JsValue>.empty()
        this.onEndCallback = StrongOptional<JsValue>.empty()
        this.onWritableCallback = StrongOptional<JsValue>.empty()
        this.onCloseCallback = StrongOptional<JsValue>.empty()
        this.eventLoopTimer = EventLoopTimer(EventLoopTimerTag.UPGRADED_DUPLEX)
        this.currentTimeout = 0
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
        if (handlers.ctx.isSome()) {
            handlers.onClose(handlers.ctx)
        }
        var emptyData: ?Array<Byte> = None
        callWriteOrEnd(emptyData, false)
    }

    func callWriteOrEnd(data: ?Array<Byte>, msgMore: Bool): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        // Stub: actual JS duplex write/end not yet implemented
    }

    func internalWrite(encodedData: Array<Byte>): Unit {
        resetTimeout()
        callWriteOrEnd(encodedData, true)
    }

    public func flush(): Unit {
        if (wrapper.isSome()) {
            wrapper.getOrThrow().flush()
        }
    }

    func onInternalReceiveData(data: Array<Byte>): Unit {
        if (wrapper.isSome()) {
            resetTimeout()
            wrapper.getOrThrow().receiveData(data)
        }
    }

    static func onReceivedData(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        // Stub
        return JsValue.jsUndefined()
    }

    static func onEnd(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        // Stub
        return JsValue.jsUndefined()
    }

    static func onWritable(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        // Stub
        return JsValue.jsUndefined()
    }

    static func onCloseJS(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        // Stub
        return JsValue.jsUndefined()
    }

    public func onTimeout(): Unit {
        eventLoopTimer.state = TimerState.FIRED
        if (handlers.ctx.isSome()) {
            handlers.onTimeout(handlers.ctx)
        }
    }

    public static func from(globalThis: JsGlobalObject, origin: JsValue, handlers: UpgradedDuplexHandlers): UpgradedDuplex {
        let result = UpgradedDuplex(
            globalThis.bunVM(),
            handlers
        )
        result.origin = StrongOptional<JsValue>.empty()
        result.global = globalThis
        return result
    }

    public func getJSHandlers(globalThis: JsGlobalObject): JsValue {
        // Stub: return empty array
        return JsValue.jsNull()
    }

    public func startTLS(sslOptions: SSLConfig, isClient: Bool): Unit {
        // Stub: SSL wrapper initialization not yet implemented
    }

    public func startTLSWithCTX(sslCtx: SslCtx, isClient: Bool): Unit {
        // Stub: SSL wrapper initialization not yet implemented
    }

    public func encodeAndWrite(data: Array<Byte>): Int32 {
        if (wrapper.isSome()) {
            return Int32(wrapper.getOrThrow().writeData(data))
        }
        return 0
    }

    public func rawWrite(encodedData: Array<Byte>): Int32 {
        internalWrite(encodedData)
        return Int32(encodedData.size)
    }

    public func close(): Unit {
        if (wrapper.isSome()) {
            wrapper.getOrThrow().shutdown(true)
        }
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
        return true
    }

    public func isClosed(): Bool {
        if (wrapper.isSome()) {
            return wrapper.getOrThrow().isClosed()
        }
        return true
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
        return UsBunVerifyError(
            sslError.errorNo,
            sslError.code,
            sslError.reason
        )
    }

    public func resetTimeout(): Unit {
        setTimeoutInMilliseconds(currentTimeout)
    }

    public func setTimeoutInMilliseconds(ms: UInt32): Unit {
        currentTimeout = ms
    }

    public func setTimeout(seconds: UInt32): Unit {
        setTimeoutInMilliseconds(seconds * 1000)
    }

    public func deinit(): Unit {
        setTimeout(UInt32(0))

        if (wrapper.isSome()) {
            wrapper.getOrThrow().deinit()
            wrapper = None
        }

        origin.deinit()
        sslError = UsBunVerifyError()
    }
}

/// 事件循环定时器标签
public enum EventLoopTimerTag {
    | UPGRADED_DUPLEX
    | WINDOWS_NAMED_PIPE
}

/// 定时器状态
public enum TimerState {
    | ACTIVE
    | CANCELLED
    | FIRED

    public operator func ==(right: TimerState): Bool {
        match (this) {
            case ACTIVE =>
                match (right) {
                    case ACTIVE => true
                    case _ => false
                }
            case CANCELLED =>
                match (right) {
                    case CANCELLED => true
                    case _ => false
                }
            case FIRED =>
                match (right) {
                    case FIRED => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: TimerState): Bool {
        return !(this == right)
    }
}

/// 脚本执行状态
public enum ScriptExecutionStatus {
    | RUNNING
    | STOPPED
}
