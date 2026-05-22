// 严格翻译自: src/runtime/socket/UpgradedDuplex.zig
// UpgradedDuplex — 为 Node.js 风格双工流提供 TLS/SSL 加密
package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// UpgradedDuplex
// 对应 Bun: UpgradedDuplex struct
// 为非传统网络 socket 的双工流提供 TLS/SSL 加密
// 用于需要向实现了双工流接口的任意读/写通道添加 TLS 加密的场景
// ============================================================================

/// 证书错误信息
/// 对应 Zig: pub const CertError = struct { ... }
public class CertError {
    /// 错误编号
    public var errorNo: Int32
    /// 错误代码
    public var code: String
    /// 错误原因
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

    /// 释放资源
    public func deinit(): Unit {
        // code 和 reason 在仓颉中由 GC 管理
    }
}

/// UpgradedDuplex 回调处理器
/// 对应 Zig: pub const Handlers = struct { ... }
public class UpgradedDuplexHandlers {
    /// 上下文指针
    public var ctx: ?Any
    /// 连接打开回调
    public var onOpen: (?Any) -> Unit
    /// 握手完成回调 (ctx, success, verify_error)
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
    public var onError: (?Any, JsValue) -> Unit
    /// 超时回调
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
///
/// 当需要向非传统网络 socket 的双工流添加 TLS 加密时使用
/// 在 Node.js 中，双工流可以表示任意读/写通道 — 内存流、自定义传输协议等
/// 这些双工流没有原生 SSL 支持 (不是真正的 socket 文件描述符)
///
/// 双工流管理 SSL 握手、证书验证、加密/解密，
/// 并与 Bun 的事件循环集成用于超时和异步操作
public class UpgradedDuplex {
    /// SSL 包装器
    public var wrapper: ?SslWrapper<UpgradedDuplex>
    /// 原始双工流 (JS 引用)
    public var origin: StrongOptional<JsValue>
    /// 全局对象
    public var global: ?JsGlobalObject
    /// SSL 错误信息
    public var `sslError`: UsBunVerifyError
    /// 虚拟机
    public var vm: VirtualMachine
    /// 事件处理器
    public var handlers: UpgradedDuplexHandlers
    /// onData JS 回调
    public var onDataCallback: StrongOptional<JsValue>
    /// onEnd JS 回调
    public var onEndCallback: StrongOptional<JsValue>
    /// onWritable JS 回调
    public var onWritableCallback: StrongOptional<JsValue>
    /// onClose JS 回调
    public var onCloseCallback: StrongOptional<JsValue>
    /// 事件循环定时器
    public var eventLoopTimer: EventLoopTimer
    /// 当前超时时间
    public var currentTimeout: UInt32

    public init(vm: VirtualMachine, handlers: UpgradedDuplexHandlers) {
        this.wrapper = None
        this.origin = StrongOptional<JsValue>.empty()
        this.global = None
        this.sslError = CertError()
        this.vm = vm
        this.handlers = handlers
        this.onDataCallback = StrongOptional<JsValue>.empty()
        this.onEndCallback = StrongOptional<JsValue>.empty()
        this.onWritableCallback = StrongOptional<JsValue>.empty()
        this.onCloseCallback = StrongOptional<JsValue>.empty()
        this.eventLoopTimer = EventLoopTimer(tag: EventLoopTimerTag.UPGRADED_DUPLEX)
        this.currentTimeout = 0
    }

    /// 连接打开
    func onOpenInternal(): Unit {
        if (handlers.ctx.isSome()) {
            handlers.onOpen(handlers.ctx)
        }
    }

    /// 数据到达
    func onDataInternal(decodedData: Array<Byte>): Unit {
        if (handlers.ctx.isSome()) {
            handlers.onData(handlers.ctx, decodedData)
        }
    }

    /// 握手完成
    func onHandshakeInternal(handshakeSuccess: Bool, sslError: UsBunVerifyError): Unit {
        this.sslError = CertError(
            errorNo: sslError.errorNo,
            code: if (sslError.code.isNone() || sslError.errorNo == 0) { "" } else { sslError.code },
            reason: if (sslError.reason.isNone() || sslError.errorNo == 0) { "" } else { sslError.reason }
        )
        if (handlers.ctx.isSome()) {
            handlers.onHandshake(handlers.ctx, handshakeSuccess, sslError)
        }
    }

    /// 连接关闭
    func onCloseInternal(): Unit {
        // defer deinit() - cleanup will be done inline
        if (handlers.ctx.isSome()) {
            handlers.onClose(handlers.ctx)
        }
        // 关闭底层双工流
        callWriteOrEnd(None, false)
    }

    /// 调用 write 或 end
    func callWriteOrEnd(data: ?Array<Byte>, msgMore: Bool): Unit {
        if (vm.isShuttingDown()) {
            return
        }
        let duplexOpt = origin.get()
        if (duplexOpt.isSome()) {
            let duplex = duplexOpt
            let globalThis = global
            if (globalThis.isNone()) {
                return
            }
            let writeOrEnd = if (msgMore) {
                duplex.getFunction(globalThis, "write")
            } else {
                duplex.getFunction(globalThis, "end")
            }
            if (writeOrEnd.isNone()) {
                return
            }
            if (data.isSome()) {
                let dataVal = data
                let buffer = JsArrayBuffer.toJS(dataVal, globalThis)
                buffer.ensureStillAlive()

                try {
                    writeOrEnd.call(globalThis, duplex, buffer)
                } catch (err: JsError) {
                    if (handlers.ctx.isSome()) {
                        handlers.onError(handlers.ctx, globalThis.takeException(err))
                    }
                }
            } else {
                try {
                    writeOrEnd.call(globalThis, duplex, JsValue.jsNull())
                } catch (err: JsError) {
                    if (handlers.ctx.isSome()) {
                        handlers.onError(handlers.ctx, globalThis.takeException(err))
                    }
                }
            }
        }
    }

    /// 内部写入 (加密后数据发送到网络)
    func internalWrite(encodedData: Array<Byte>): Unit {
        resetTimeout()
        callWriteOrEnd(encodedData, true)
    }

    /// 刷新缓冲数据
    public func flush(): Unit {
        if (wrapper.isSome()) {
            wrapper.flush()
        }
    }

    /// 内部接收数据
    func onInternalReceiveData(data: Array<Byte>): Unit {
        if (wrapper.isSome()) {
            resetTimeout()
            wrapper.receiveData(data)
        }
    }

    /// JS 回调: 接收数据
    static func onReceivedData(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        let function = callFrame.callee()
        let args = callFrame.argumentsOld(1)

        let selfOpt = HostFn.getFunctionData(function)
        if (selfOpt.isSome()) {
            let `this` = selfOpt as UpgradedDuplex
            if (args.size >= 1) {
                let dataArg = args[0]
                if (this.origin.has()) {
                    if (dataArg.isEmptyOrUndefinedOrNull()) {
                        return JsValue.jsUndefined()
                    }
                    let arrayBuffer = dataArg.asArrayBuffer(globalObject)
                    if (arrayBuffer.isSome()) {
                        let payload = arrayBuffer.slice()
                        this.onInternalReceiveData(payload)
                    } else {
                        // node.js 在此情况下报相同的错误
                        let errorValue = globalObject.ERR("STREAM_WRAP", "Stream has StringDecoder set or is in objectMode").toJS()
                        errorValue.ensureStillAlive()
                        if (this.handlers.ctx.isSome()) {
                            this.handlers.onError(this.handlers.ctx, errorValue)
                        }
                    }
                }
            }
        }
        return JsValue.jsUndefined()
    }

    /// JS 回调: 结束
    static func onEnd(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        let function = callFrame.callee()
        let selfOpt = HostFn.getFunctionData(function)
        if (selfOpt.isSome()) {
            let `this` = selfOpt as UpgradedDuplex
            if (this.wrapper.isSome()) {
                if (this.handlers.ctx.isSome()) {
                    this.handlers.onEnd(this.handlers.ctx)
                }
            }
        }
        return JsValue.jsUndefined()
    }

    /// JS 回调: 可写
    static func onWritable(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        let function = callFrame.callee()
        let selfOpt = HostFn.getFunctionData(function)
        if (selfOpt.isSome()) {
            let `this` = selfOpt as UpgradedDuplex
            // 刷新待处理数据
            if (this.wrapper.isSome()) {
                this.wrapper.flush()
            }
            // 调用 onWritable (按需刷新)
            if (this.handlers.ctx.isSome()) {
                this.handlers.onWritable(this.handlers.ctx)
            }
        }
        return JsValue.jsUndefined()
    }

    /// JS 回调: 关闭
    static func onCloseJS(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        let function = callFrame.callee()
        let selfOpt = HostFn.getFunctionData(function)
        if (selfOpt.isSome()) {
            let `this` = selfOpt as UpgradedDuplex
            // 刷新待处理数据
            if (this.wrapper.isSome()) {
                this.wrapper.shutdown(true)
            }
        }
        return JsValue.jsUndefined()
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

        if (handlers.ctx.isSome()) {
            handlers.onTimeout(handlers.ctx)
        }
    }

    /// 创建 UpgradedDuplex 实例
    /// 对应 Zig: pub fn from
    public static func from(globalThis: JsGlobalObject, origin: JsValue, handlers: UpgradedDuplexHandlers): UpgradedDuplex {
        let result = UpgradedDuplex(
            vm: globalThis.bunVM(),
            handlers: handlers
        )
        result.origin = StrongOptional<JsValue>.create(origin, globalThis)
        result.global = globalThis
        return result
    }

    /// 获取 JS 处理函数数组 [onData, onEnd, onWritable, onClose]
    /// 对应 Zig: pub fn getJSHandlers
    public func getJSHandlers(globalThis: JsGlobalObject): JsValue {
        let array = JsValue.createEmptyArray(globalThis, 4)
        array.ensureStillAlive()

        // onData 回调
        var callback = onDataCallback.get()
        if (callback.isNone()) {
            let dataCallback = HostFn.newFunctionWithData(globalThis, None, 0, UpgradedDuplex.onReceivedData, this)
            dataCallback.ensureStillAlive()
            HostFn.setFunctionData(dataCallback, this)
            onDataCallback = StrongOptional<JsValue>.create(dataCallback, globalThis)
            callback = dataCallback
        }
        array.putIndex(globalThis, 0, callback)

        // onEnd 回调
        callback = onEndCallback.get()
        if (callback.isNone()) {
            let endCallback = HostFn.newFunctionWithData(globalThis, None, 0, UpgradedDuplex.onEnd, this)
            endCallback.ensureStillAlive()
            HostFn.setFunctionData(endCallback, this)
            onEndCallback = StrongOptional<JsValue>.create(endCallback, globalThis)
            callback = endCallback
        }
        array.putIndex(globalThis, 1, callback)

        // onWritable 回调
        callback = onWritableCallback.get()
        if (callback.isNone()) {
            let writableCallback = HostFn.newFunctionWithData(globalThis, None, 0, UpgradedDuplex.onWritable, this)
            writableCallback.ensureStillAlive()
            HostFn.setFunctionData(writableCallback, this)
            onWritableCallback = StrongOptional<JsValue>.create(writableCallback, globalThis)
            callback = writableCallback
        }
        array.putIndex(globalThis, 2, callback)

        // onClose 回调
        callback = onCloseCallback.get()
        if (callback.isNone()) {
            let closeCallback = HostFn.newFunctionWithData(globalThis, None, 0, UpgradedDuplex.onCloseJS, this)
            closeCallback.ensureStillAlive()
            HostFn.setFunctionData(closeCallback, this)
            onCloseCallback = StrongOptional<JsValue>.create(closeCallback, globalThis)
            callback = closeCallback
        }
        array.putIndex(globalThis, 3, callback)

        return array
    }

    /// 启动 TLS
    /// 对应 Zig: pub fn startTLS
    public func startTLS(sslOptions: SSLConfig, isClient: Bool): Unit {
        let handlers = SslWrapperHandlers<UpgradedDuplex>(
            { ctx: UpgradedDuplex => ctx.onOpenInternal() },
            { ctx: UpgradedDuplex, success: Bool, err: UsBunVerifyError => ctx.onHandshakeInternal(success, err) },
            { ctx: UpgradedDuplex, data: Array<Byte> => ctx.internalWrite(data) },
            { ctx: UpgradedDuplex, data: Array<Byte> => ctx.onDataInternal(data) },
            { ctx: UpgradedDuplex => ctx.onCloseInternal() }
        )
        wrapper = SslWrapper(sslOptions, isClient, this, handlers)
        wrapper.start()
    }

    /// 使用已有的 SSL_CTX 启动 TLS
    /// 采用 ctx (一个引用) — 在成功和失败时都会释放
    /// 对应 Zig: pub fn startTLSWithCTX
    public func startTLSWithCTX(ctx: SslCtx, isClient: Bool): Unit {
        try {
            let handlers = SslWrapperHandlers<UpgradedDuplex>(
                { ctx2: UpgradedDuplex => ctx2.onOpenInternal() },
                { ctx2: UpgradedDuplex, success: Bool, err: UsBunVerifyError => ctx2.onHandshakeInternal(success, err) },
                { ctx2: UpgradedDuplex, data: Array<Byte> => ctx2.internalWrite(data) },
                { ctx2: UpgradedDuplex, data: Array<Byte> => ctx2.onDataInternal(data) },
                { ctx2: UpgradedDuplex => ctx2.onCloseInternal() }
            )
            wrapper = SslWrapper.initWithCTX(ctx, isClient, this, handlers)
            wrapper.start()
        } catch (ex: SslError) {
            BoringSSL.sslCtxFree(ctx)
            throw ex
        }
    }

    /// 编码并写入数据
    /// 对应 Zig: pub fn encodeAndWrite
    public func encodeAndWrite(data: Array<Byte>): Int32 {
        if (wrapper.isSome()) {
            return wrapper.writeData(data).toInt32()
        }
        return 0
    }

    /// 原始写入
    /// 对应 Zig: pub fn rawWrite
    public func rawWrite(encodedData: Array<Byte>): Int32 {
        internalWrite(encodedData)
        return encodedData.size.toInt32()
    }

    /// 关闭连接
    /// 对应 Zig: pub fn close
    public func close(): Unit {
        if (wrapper.isSome()) {
            wrapper.shutdown(true)
        }
    }

    /// 优雅关闭
    /// 对应 Zig: pub fn shutdown
    public func shutdown(): Unit {
        if (wrapper.isSome()) {
            wrapper.shutdown(false)
        }
    }

    /// 关闭读取方向
    /// 对应 Zig: pub fn shutdownRead
    public func shutdownRead(): Unit {
        if (wrapper.isSome()) {
            wrapper.shutdownRead()
        }
    }

    /// 是否已关闭
    /// 对应 Zig: pub fn isShutdown
    public func isShutdown(): Bool {
        if (wrapper.isSome()) {
            return wrapper.isShutdown()
        }
        return true
    }

    /// 是否完全关闭
    /// 对应 Zig: pub fn isClosed
    public func isClosed(): Bool {
        if (wrapper.isSome()) {
            return wrapper.isClosed()
        }
        return true
    }

    /// 是否已建立连接
    /// 对应 Zig: pub fn isEstablished
    public func isEstablished(): Bool {
        return !isClosed()
    }

    /// 获取 SSL 对象
    /// 对应 Zig: pub fn ssl
    public func ssl(): ?Ssl {
        if (wrapper.isSome()) {
            return wrapper.ssl
        }
        return None
    }

    /// 获取 SSL 错误
    /// 对应 Zig: pub fn sslError
    public func getSslError(): UsBunVerifyError {
        return UsBunVerifyError(
            errorNo: sslError.errorNo,
            code: sslError.code,
            reason: sslError.reason
        )
    }

    /// 重置超时
    /// 对应 Zig: pub fn resetTimeout
    public func resetTimeout(): Unit {
        setTimeoutInMilliseconds(currentTimeout)
    }

    /// 设置超时 (毫秒)
    /// 对应 Zig: pub fn setTimeoutInMilliseconds
    public func setTimeoutInMilliseconds(ms: UInt32): Unit {
        if (eventLoopTimer.state == TimerState.ACTIVE) {
            vm.timer.remove(eventLoopTimer)
        }
        currentTimeout = ms

        // 间隔为 0 表示停止定时器
        if (ms == 0) {
            return
        }

        // 重新调度定时器
        eventLoopTimer.next = Timespec.msFromNow(ms)
        vm.timer.insert(eventLoopTimer)
    }

    /// 设置超时 (秒)
    /// 对应 Zig: pub fn setTimeout
    public func setTimeout(seconds: UInt32): Unit {
        setTimeoutInMilliseconds(seconds * 1000)
    }

    /// 释放资源
    /// 对应 Zig: pub fn deinit
    public func deinit(): Unit {
        // 清除定时器
        setTimeout(0)

        if (wrapper.isSome()) {
            wrapper.deinit()
            wrapper = None
        }

        origin.deinit()

        let onDataCb = onDataCallback.get()
        if (onDataCb.isSome()) {
            HostFn.setFunctionData(onDataCb, None)
            onDataCallback.deinit()
        }
        let onEndCb = onEndCallback.get()
        if (onEndCb.isSome()) {
            HostFn.setFunctionData(onEndCb, None)
            onEndCallback.deinit()
        }
        let onWritableCb = onWritableCallback.get()
        if (onWritableCb.isSome()) {
            HostFn.setFunctionData(onWritableCb, None)
            onWritableCallback.deinit()
        }
        let onCloseCb = onCloseCallback.get()
        if (onCloseCb.isSome()) {
            HostFn.setFunctionData(onCloseCb, None)
            onCloseCallback.deinit()
        }

        sslError.deinit()
        sslError = CertError()
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
}

/// 脚本执行状态
public enum ScriptExecutionStatus {
    | RUNNING
    | STOPPED
}
