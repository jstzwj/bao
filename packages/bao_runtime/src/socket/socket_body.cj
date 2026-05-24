// 严格翻译自: src/runtime/socket/socket_body.rs
// TCP/TLS Socket JS 绑定 (Bun.connect / Bun.listen socket 包装器)。
// 包含 NewSocket<SSL> 泛型结构体的核心实现：连接、回调、生命周期管理。
//
// 关键设计说明 (noalias re-entrancy):
// JS 回调是重入的 — socket.write()/socket.end()/socket.reload() 可以通过
// JS 对象的 m_ptr 在同一个回调帧中重新进入，重新派生 &NewSocket。
// 因此所有回调使用 *Self 而非 &self，每个字段访问都是短生命周期的借用。

package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_ptr.*
import bao_uws_sys.*
import bao_sys.*

// ============================================================================
// IntrusiveRc — 侵入式引用计数指针
// 用于 upgradeTLS 产生的双胞胎 Socket 共享
// ============================================================================

/// 侵入式引用计数指针 (stub)
public class IntrusiveRc {}

/// Socket PollRef (stub) — 保持事件循环活跃的引用
/// 统一 bao_io.KeepAlive 和 bao_jsc.KeepAlive 的接口
public class SocketPollRef {
    public init() {}
    public func disable(): Unit {}
    public func unref(ctx: Any): Unit {}
    public func unrefOnNextTick(ctx: Any): Unit {}
    public func refAlias(ctx: Any): Unit {}
}

// ============================================================================
// NewSocket<SSL> — 通用 Socket 包装器
// SSL = false -> TCPSocket, SSL = true -> TLSSocket
// 对应 Bun: fn NewSocket(comptime ssl: bool) type { return struct {...} }
// ============================================================================

/// NewSocket — 通用 Socket 包装器。
/// 使用布尔类型参数区分 TCP 和 TLS 模式。
/// 对应 Zig: fn NewSocket(comptime ssl: bool) type { return struct { ... } }
public class NewSocket {
    /// 底层 socket 处理器
    public var socket: SocketHandler
    /// 此客户端连接的 SSL_CTX*。一个拥有的引用 — deinit 时 SSL_CTX_free。
    /// 服务端接受的 socket 和纯 TCP 将此设为 None。
    public var ownedSslCtx: ?SslCtx
    /// Socket 状态标志
    public var flags: SocketFlags
    /// 引用计数 (侵入式)
    public var refCount: RefCount
    /// handlers 指针 — 服务端模式指向 Listener.handlers，
    /// 客户端模式为堆分配。
    /// 意图为 raw pointer: JS 调度是重入的 (socket.reload() 在回调帧内
    /// 覆盖指针目标)，因此 Rust 的 &排他性无法跨 callback.call 保持。
    public var handlers: ?Handlers
    /// JS 包装器引用。Socket 活跃时保持 strong，关闭/不活跃时降级为 weak。
    public var thisValue: JsRef
    /// 保活引用
    public var pollRef: SocketPollRef
    /// 是否在连接时引用 pollRef
    public var refPollrefOnConnect: Bool
    /// 连接信息
    public var connection: ?ConnectionTarget
    /// ALPN 协议列表
    public var protos: ?Array<Byte>
    /// SNI 服务器名称
    public var serverName: ?Array<Byte>
    /// node:net 缓冲数据
    public var bufferedDataForNodeNet: Array<Byte>
    /// 已写入字节数
    public var bytesWritten: UInt64
    /// 原生回调
    public var nativeCallback: NativeCallbacks
    /// upgradeTLS 产生的双胞胎 Socket (加密视图 vs 原始字节视图)
    public var twin: ?IntrusiveRc

    /// 是否为 TLS 模式
    public var isSsl: Bool

    public init(ssl: Bool) {
        socket = SocketHandler.detachedHandler(ssl)
        ownedSslCtx = None
        flags = SocketFlags()
        refCount = RefCount()
        handlers = None
        thisValue = JsRef()
        pollRef = SocketPollRef()
        refPollrefOnConnect = false
        connection = None
        protos = None
        serverName = None
        bufferedDataForNodeNet = []
        bytesWritten = 0
        nativeCallback = NativeCallbacks.none
        twin = None
        isSsl = ssl
    }

    /// 堆分配新 Socket
    public static func new_(initVal: NewSocket): NewSocket {
        return initVal
    }

    /// 内存成本估算
    /// 每个 socket 的 SSL 状态 (SSL*, BIO 对, 握手缓冲区) 约占 40 KB 堆外内存。
    /// 报告此值让 GC 在 JS 频繁创建短命 TLS 连接时施加压力。
    public func memoryCost(): Int64 {
        let sslCost: Int64 = if (isSsl && !flags.bypassTls) {
            40 * 1024
        } else {
            0
        }
        return Int64(256) + bufferedDataForNodeNet.size + sslCost
    }
}

// ============================================================================
// 引用计数 API
// 对应 Bun: bun.ptr.RefCount(@This(), "ref_count", deinit, .{})
// ============================================================================

/// 增加引用计数
public func ref_(socket: NewSocket): Unit {
    socket.refCount.ref()
}

/// 减少引用计数。当引用计数归零时调用 deinit。
public func deref(socket: NewSocket): Unit {
    socket.refCount.deref()
}

/// deinit 并销毁 — 引用计数归零时调用
public func deinitAndDestroy(socket: NewSocket): Unit {
    socket.pollRef.disable()
    if (let Some(plugin) <- socket.handlers) {
        // 服务端: handlers 嵌入在 Listener 中，不释放
        // 客户端: handlers 是堆分配的，释放
    }
    socket.bufferedDataForNodeNet = []
}

// ============================================================================
// 连接管理
// 对应 Bun: NewSocket.do_connect
// ============================================================================

/// 连接到 self.connection (必须已设置)。
/// 对应 Bun: NewSocket.do_connect
public func doConnect(socket: NewSocket): ?Error {
    // 保持 socket 在重入连接路径中存活
    ref_(socket)

    let selfPtr = socket
    let vm = getHandlers(socket).vm
    let group = SocketGroup()

    let kind: SocketKind = if (socket.isSsl) {
        SocketKind.BUN_SOCKET_TLS
    } else {
        SocketKind.BUN_SOCKET_TCP
    }

    let flags: Int32 = if (socket.flags.allowHalfOpen) {
        Int32(LIBUS_SOCKET_ALLOW_HALF_OPEN)
    } else {
        0
    }

    let sslCtx: ?SslCtx = if (socket.isSsl) {
        socket.ownedSslCtx
    } else {
        None
    }

    match (socket.connection) {
        case Some(ConnectionTarget.Host(host, port)) =>
            socket.socket = SocketHandler.detachedHandler(socket.isSsl)
            deref(socket)
            return Some(BaoError(ErrorCode.NotImplemented, "ENOSYS: TCP socket connect FFI is not implemented"))

        case Some(ConnectionTarget.Unix(u)) =>
            socket.socket = SocketHandler.detachedHandler(socket.isSsl)
            deref(socket)
            return Some(BaoError(ErrorCode.NotImplemented, "ENOSYS: Unix socket connect FFI is not implemented"))

        case Some(ConnectionTarget.Fd(f)) =>
            socket.socket = SocketHandler.detachedHandler(socket.isSsl)
            deref(socket)
            return Some(BaoError(ErrorCode.NotImplemented, "ENOSYS: socket adoption from fd is not implemented"))

        case None =>
            throw Exception("doConnect requires connection to be set")
    }

    deref(socket)
    return None
}

// ============================================================================
// 回调处理 — 所有回调使用指针模式避免 noalias 重入问题
// 对应 Bun: NewSocket::{on_writable, on_timeout, on_end, on_close, on_open, ...}
// ============================================================================

/// onWritable 回调
/// PORT NOTE: 使用指针而非 &self — callback.call 重入 JS，
/// 可以通过 m_ptr 再次调用 socket.write()/end()/reload()。
public func onWritable(socket: NewSocket, socketHandler: SocketHandler): Unit {
    if (socket.socket.isDetached()) {
        return
    }
    if (socket.nativeCallback.onWritable()) {
        return
    }
    let handlers = getHandlers(socket)
    let callback = handlers.onWritable
    if (callback.isEmpty()) {
        return
    }

    let vm = handlers.vm
    if (vm.isShuttingDown()) {
        return
    }

    ref_(socket)

    // 内部刷新
    internalFlush(socket)

    // 如果有缓冲数据或已分离，不再写入
    if (socket.bufferedDataForNodeNet.size > 0 || socket.socket.isDetached()) {
        deref(socket)
        return
    }

    // 保持 handlers 在回调期间存活
    handlers.markActive()

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)
    let result = callback.call(global, thisValue, [thisValue])
    if (result.isException()) {
        handleError(socket, result)
    }
    handlers.markInactive()
    deref(socket)
}

/// onTimeout 回调
public func onTimeout(socket: NewSocket, socketHandler: SocketHandler): Unit {
    if (socket.socket.isDetached()) {
        return
    }
    let handlers = getHandlers(socket)
    let callback = handlers.onTimeout
    if (callback.isEmpty() || socket.flags.finalizing) {
        return
    }
    if (handlers.vm.isShuttingDown()) {
        return
    }

    handlers.markActive()

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)
    let result = callback.call(global, thisValue, [thisValue])
    if (result.isException()) {
        handleError(socket, result)
    }
    handlers.markInactive()
}

/// handleConnectError — 连接错误处理
/// 对应 Bun: NewSocket.handle_connect_error
public func handleConnectError(socket: NewSocket, errno: Int32): Unit {
    let handlers = getHandlers(socket)

    // 保持 socket 存活
    ref_(socket)

    // 清理缓冲区
    socket.bufferedDataForNodeNet = []

    let needsDeref = !socket.socket.isDetached()
    socket.socket = SocketHandler.detachedHandler(socket.isSsl)

    let vm = handlers.vm
    socket.pollRef.unrefOnNextTick(jsLoopCtx())

    // 清理 guard
    if (needsDeref) {
        deref(socket)
    }
    markInactive(socket)

    if (vm.isShuttingDown()) {
        return
    }

    // 构建错误对象
    let errnoValue = errno
    let code_ = if (errno == 2) {
        "ENOENT"
    } else {
        "ECONNREFUSED"
    }

    let callback = handlers.onConnectError
    let global = handlers.globalObject
    let err = SystemError(code_, "Failed to connect")

    handlers.markActive()

    if (callback.isEmpty()) {
        // 连接在打开前失败；允许包装器被 GC 回收
        socket.thisValue = JsRef()

        // 拒绝 promise
        if (handlers.promise.valueType != JsValueType.Undefined) {
            handlers.rejectPromise(JsValue("Connection error"))
        }
        return
    }

    let thisValue = getThisValue(socket, global)
    thisValue.ensureStillAlive()
    socket.thisValue = JsRef()

    let errValue = JsValue("Connection error")
    let result = callback.call(global, thisValue, [thisValue, errValue])
    if (result.isException()) {
        handleError(socket, result)
    }
    handlers.markInactive()
}

/// onOpen 回调 — 连接建立时调用
/// 对应 Bun: NewSocket.on_open
public func onOpen(socket: NewSocket, socketHandler: SocketHandler): Unit {
    // 保持 socket 存活
    ref_(socket)

    // 更新内部 socket 实例
    socket.socket = socketHandler

    // TLS: stub — skip SNI and ALPN setup for now

    let handlers = getHandlers(socket)
    let callback = handlers.onOpen

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)

    let _ = handlers.resolvePromise(thisValue)

    if (callback.isEmpty()) {
        deref(socket)
        return
    }

    // 保持 handlers 在回调期间存活
    handlers.markActive()
    let result = callback.call(global, thisValue, [thisValue])
    if (result.isException()) {
        handleError(socket, result)
    }
    handlers.markInactive()
    deref(socket)
}

/// onEnd 回调 — 连接结束时调用
/// 对应 Bun: NewSocket.on_end
public func onEnd(socket: NewSocket, socketHandler: SocketHandler): Unit {
    if (socket.socket.isDetached()) {
        return
    }
    let handlers = getHandlers(socket)
    let callback = handlers.onEnd

    // 保持 socket 存活
    ref_(socket)

    if (callback.isEmpty() || handlers.vm.isShuttingDown()) {
        socket.pollRef.unref(jsLoopCtx())

        // 如果不处理 TCP fin，假定已完成
        markInactive(socket)
        deref(socket)
        return
    }

    handlers.markActive()

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)
    let result = callback.call(global, thisValue, [thisValue])
    if (result.isException()) {
        handleError(socket, result)
    }
    handlers.markInactive()
    deref(socket)
}

/// onHandshake 回调 — TLS 握手完成时调用
/// 对应 Bun: NewSocket.on_handshake
public func onHandshake(
    socket: NewSocket,
    s: SocketHandler,
    success: Int32,
    sslError: UsBunVerifyError
): Unit {
    socket.flags.handshakeComplete = true
    socket.socket = s
    if (socket.socket.isDetached()) {
        return
    }

    let handlers = getHandlers(socket)
    let authorized = (success == 1)
    socket.flags.authorized = authorized

    var callback = handlers.onHandshake
    var isOpen = false

    if (handlers.vm.isShuttingDown()) {
        return
    }

    // 当未提供 handshake 回调时使用 open 回调
    if (callback.isEmpty()) {
        callback = handlers.onOpen
        if (callback.isEmpty()) {
            return
        }
        isOpen = true
    }

    handlers.markActive()

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)

    let result: JsValue
    if (isOpen) {
        result = callback.call(global, thisValue, [thisValue])

        // 客户端只调用一次 onOpen
        if (!handlers.mode.isServer()) {
            handlers.onOpen.unprotect()
            handlers.onOpen = JsValue.UNDEFINED
        }
    } else {
        let authorizationError: JsValue = if (sslError.errorNo == 0) {
            JsValue.jsNull()
        } else {
            JsValue("SSL verify error")
        }

        result = callback.call(global, thisValue, [thisValue, JsValue(authorized), authorizationError])
    }

    if (handlers.markInactive()) {
        socket.handlers = None
    }
}

/// onClose 回调 — 连接关闭时调用
/// 对应 Bun: NewSocket.on_close
public func onClose(
    socket: NewSocket,
    socketHandler: SocketHandler,
    err: Int32,
    reason: ?CPointer<Unit>
): Unit {
    let handlers = getHandlers(socket)

    socket.socket = SocketHandler.detachedHandler(socket.isSsl)

    // upgradeTLS 的原始双胞胎共享同一个 us_socket_t
    if (socket.twin.isSome()) {
        socket.twin = None
    }

    // 清理 guard
    markInactive(socket)
    deref(socket)

    if (handlers.vm.isShuttingDown()) {
        return
    }

    let callback = handlers.onClose
    if (callback.isEmpty()) {
        return
    }

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)

    let result = callback.call(global, thisValue, [thisValue, JsValue(Int64(err))])

    // Error handling stub
}

// ============================================================================
// 状态管理
// ============================================================================

/// 标记为活跃
public func markActive(socket: NewSocket): Unit {
    if (!socket.flags.isActive) {
        let handlers = getHandlers(socket)
        handlers.markActive()
        socket.flags.isActive = true
    }
}

/// 标记为不活跃
public func markInactive(socket: NewSocket): Unit {
    if (socket.flags.isActive) {
        socket.flags.isActive = false
    }
}

/// 关闭并分离
public func closeAndDetach(socket: NewSocket, code: CloseCode): Unit {
    let s = socket.socket
    socket.bufferedDataForNodeNet = []
    socket.socket = SocketHandler.detachedHandler(socket.isSsl)
}

/// 获取 handlers
/// 对应 Bun: NewSocket.get_handlers
public func getHandlers(socket: NewSocket): Handlers {
    return socket.handlers.getOrThrow()
}

/// 获取 this_value JS 引用
public func getThisValue(socket: NewSocket, global: JsObject): JsValue {
    return socket.thisValue.get()
}

/// 是否为服务端 socket
public func isServer(socket: NewSocket): Bool {
    if (socket.handlers.isNone()) {
        return false
    }
    return socket.handlers.getOrThrow().mode.isServer()
}

// ============================================================================
// JS 绑定方法
// 对应 Bun: NewSocket::{resume_from_js, pause_from_js, set_keep_alive, set_no_delay}
// ============================================================================

/// JS: resume()
public func resumeFromJs(socket: NewSocket, global: JSGlobalObject): JsValue {
    if (socket.socket.isDetached()) {
        return JsValue.undefined()
    }
    // TLS 升级的原始半部分是观测抽头；流量控制属于 TLS 半部分
    if (socket.flags.bypassTls) {
        return JsValue.undefined()
    }
    if (socket.flags.isPaused) {
        let resumed = socket.socket.resumeStream()
        socket.flags.isPaused = !resumed
    }
    return JsValue.undefined()
}

/// JS: pause()
public func pauseFromJs(socket: NewSocket, global: JSGlobalObject): JsValue {
    if (socket.socket.isDetached()) {
        return JsValue.undefined()
    }
    if (socket.flags.bypassTls) {
        return JsValue.undefined()
    }
    if (!socket.flags.isPaused) {
        let paused = socket.socket.pauseStream()
        socket.flags.isPaused = paused
    }
    return JsValue.undefined()
}

/// JS: setKeepAlive(enabled, initialDelay)
public func setKeepAliveFromJs(
    socket: NewSocket,
    global: JSGlobalObject,
    enabled: Bool,
    initialDelay: UInt32
): JsValue {
    return JsValue(socket.socket.setKeepAlive(enabled, initialDelay))
}

/// JS: setNoDelay(enabled)
public func setNoDelayFromJs(socket: NewSocket, global: JSGlobalObject, enabled: Bool): JsValue {
    return JsValue(socket.socket.setNoDelay(enabled))
}

// ============================================================================
// 数据写入
// 对应 Bun: NewSocket::{write, end, internal_flush, reload}
// ============================================================================

/// 内部刷新 — 将缓冲数据写入 socket
/// 对应 Bun: NewSocket.internal_flush
public func internalFlush(socket: NewSocket): Unit {
    if (socket.socket.isDetached() || socket.socket.isClosed()) {
        return
    }

    let data = socket.bufferedDataForNodeNet
    if (data.isEmpty()) {
        return
    }

    let result = socket.socket.write(data)
    match (result) {
        case WriteResult.Success(wrote, total) =>
            socket.bytesWritten += UInt64(wrote)
            if (wrote >= total) {
                socket.bufferedDataForNodeNet = []
            } else {
                socket.bufferedDataForNodeNet = data[wrote..data.size]
            }
        case WriteResult.Fail => ()
    }
}

/// JS: write(data)
public func writeFromJs(
    socket: NewSocket,
    global: JsObject,
    data: JsValue
): JsValue {
    if (socket.socket.isDetached()) {
        return JsValue(false)
    }

    let bytesOpt = socketWriteBytesFromJs(global, data)
    if (bytesOpt.isNone()) {
        throw JsTypeError("socket.write expects a string, Buffer, ArrayBuffer, DataView, or TypedArray backed by owned byte storage")
    }

    let bytes = bytesOpt.getOrThrow()
    if (bytes.isEmpty()) {
        return JsValue(true)
    }

    let wroteRaw = socket.socket.write(bytes)
    if (wroteRaw < 0) {
        return JsValue(false)
    }

    let wrote = Int64(wroteRaw)
    socket.bytesWritten += UInt64(wrote)
    if (wrote < bytes.size) {
        socket.bufferedDataForNodeNet = bytes[wrote..bytes.size]
        return JsValue(false)
    }

    return JsValue(true)
}

func socketWriteBytesFromJs(global: JsObject, data: JsValue): ?Array<Byte> {
    if (data.isString()) {
        return Some(data.toString().toArray())
    }

    match (data.asArrayBuffer(global)) {
        case Some(view) => return Some(view.bytes())
        case None => return None
    }
}

/// JS: end(data?)
public func endFromJs(
    socket: NewSocket,
    global: JsObject,
    data: ?JsValue
): JsValue {
    if (data.isSome()) {
        writeFromJs(socket, global, data.getOrThrow())
    }

    if (socket.bufferedDataForNodeNet.isEmpty()) {
        closeAndDetach(socket, CloseCode.normal)
    } else {
        socket.flags.endAfterFlush = true
    }
    return JsValue.undefined()
}

/// JS: reload(handlerObject)
/// 对应 Bun: NewSocket.reload
public func reloadFromJs(
    socket: NewSocket,
    global: JsObject,
    handlerObject: JsValue
): JsValue {
    // Handler reload parsing is not wired yet. Do not claim success.
    return JsValue(false)
}

// ============================================================================
// 原生回调管理
// ============================================================================

/// 附加原生回调
public func attachNativeCallback(socket: NewSocket, callback: NativeCallbacks): Bool {
    if (!socket.nativeCallback.isNone()) {
        return false
    }
    socket.nativeCallback = callback
    return true
}

/// 分离原生回调
public func detachNativeCallback(socket: NewSocket): Unit {
    match (socket.nativeCallback) {
        case NativeCallbacks.h2(h2Parser) =>
            NativeCallbacks.h2(h2Parser).onNativeClose()
            socket.nativeCallback = NativeCallbacks.none
        case NativeCallbacks.none => ()
    }
}

// ============================================================================
// 错误处理
// 对应 Bun: NewSocket.handle_error
// ============================================================================

/// 处理 JS 错误值
public func handleError(socket: NewSocket, errValue: JsValue): Unit {
    let handlers = getHandlers(socket)
    let vm = handlers.vm
    if (vm.isShuttingDown()) {
        return
    }

    handlers.markActive()
    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)
    let _ = handlers.callErrorHandler(thisValue, errValue)
    if (handlers.markInactive()) {
        socket.handlers = None
    }
}

// ============================================================================
// JS 构造和转换
// ============================================================================

/// 转换为 JS 值
public func toJs(socket: NewSocket, global: JSGlobalObject): JsValue {
    throw JsTypeError("ENOSYS: socket JS wrapper creation is not implemented")
}

/// JS 构造器 (禁止直接构造)
public func constructor(global: JSGlobalObject): JsValue {
    throw JsTypeError("Cannot construct Socket")
}

// ============================================================================
// ALPN 选择回调
// 对应 Bun: select_alpn_callback
// ============================================================================

/// SSL ALPN 选择回调常量
let SSL_TLSEXT_ERR_OK: Int32 = 0
let SSL_TLSEXT_ERR_ALERT_FATAL: Int32 = 2
let SSL_TLSEXT_ERR_NOACK: Int32 = 3
let OPENSSL_NPN_NEGOTIATED: Int32 = 1

/// ALPN 协议选择回调
/// SSL_CTX_set_alpn_select_cb 注册在监听器级别的 SSL_CTX 上，
/// 其 arg 在每个接受的连接间共享。
func selectAlpnCallback(
    ssl: Ssl,
    out: CPointer<Unit>,
    outlen: CPointer<Unit>,
    in_: CPointer<Unit>,
    inlen: UInt32
): Int32 {
    if (inlen == UInt32(0)) {
        return SSL_TLSEXT_ERR_NOACK
    }

    // No protocol list is wired into the callback yet. Decline ALPN negotiation
    // instead of pretending a protocol was selected.
    return SSL_TLSEXT_ERR_NOACK
}

// ============================================================================
// 辅助
// ============================================================================

/// 获取 JS 事件循环上下文
func jsLoopCtx(): Any {
    // Stub: return placeholder context — actual event loop integration not yet implemented
    return "js_loop_ctx"
}

// ============================================================================
// NativeCallbacks — 原生回调枚举
// ============================================================================

/// 原生回调枚举
public enum NativeCallbacks {
    | none
    | h2(H2FrameParser)

    /// 是否处理 writable 事件
    public func onWritable(): Bool {
        match (this) {
            case h2(parser) => parser.onWritable()
            case none => false
        }
    }

    /// Equality check — compare with none
    public func isNone(): Bool {
        match (this) {
            case none => true
            case _ => false
        }
    }

    /// 获取 h2 解析器
    public func getH2(): ?H2FrameParser {
        match (this) {
            case h2(parser) => parser
            case none => None
        }
    }

    /// 触发原生关闭回调
    public func onNativeClose(): Unit {
        match (this) {
            case h2(parser) => ()
            case none => ()
        }
    }
}
