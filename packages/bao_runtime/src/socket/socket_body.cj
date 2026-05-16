// 严格翻译自: src/runtime/socket/socket_body.rs
// TCP/TLS Socket JS 绑定 (Bun.connect / Bun.listen socket 包装器)。
// 包含 NewSocket<SSL> 泛型结构体的核心实现：连接、回调、生命周期管理。
//
// 关键设计说明 (noalias re-entrancy):
// JS 回调是重入的 — socket.write()/socket.end()/socket.reload() 可以通过
// JS 对象的 m_ptr 在同一个回调帧中重新进入，重新派生 &mut NewSocket。
// 因此所有回调使用 *mut Self 而非 &mut self，每个字段访问都是短生命周期的借用。

package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_io.*
import bao_ptr.*
import bao_uws_sys.*
import bao_sys.*

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
    /// 覆盖指针目标)，因此 Rust 的 &mut 排他性无法跨 callback.call 保持。
    public var handlers: ?Handlers
    /// JS 包装器引用。Socket 活跃时保持 strong，关闭/不活跃时降级为 weak。
    public var thisValue: JsRef
    /// 保活引用
    public var pollRef: KeepAlive
    /// 是否在连接时引用 pollRef
    public var refPollrefOnConnect: Bool
    /// 连接信息
    public var connection: ?UnixOrHost
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
        socket = SocketHandler.detached
        ownedSslCtx = None
        flags = SocketFlags()
        refCount = RefCount.init()
        handlers = None
        thisValue = JsRef()
        pollRef = KeepAlive.init()
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
    public static func new_(init_: NewSocket): NewSocket {
        return heap.alloc(init_)
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
        return sizeOf<NewSocket>()
            + bufferedDataForNodeNet.capacity
            + sslCost
    }
}

// ============================================================================
// 引用计数 API
// 对应 Bun: bun.ptr.RefCount(@This(), "ref_count", deinit, .{})
// ============================================================================

/// 增加引用计数
public func ref_(socket: NewSocket): Unit {
    socket.refCount.ref_()
}

/// 减少引用计数。当引用计数归零时调用 deinit。
public func deref(socket: NewSocket): Unit {
    socket.refCount.deref()
}

/// deinit 并销毁 — 引用计数归零时调用
public func deinitAndDestroy(socket: NewSocket): Unit {
    socket.pollRef.disable()
    if (let Some(plugin) = socket.handlers) {
        // 服务端: handlers 嵌入在 Listener 中，不释放
        // 客户端: handlers 是堆分配的，释放
    }
    socket.bufferedDataForNodeNet.clearAndFree()
    heap.take(socket)
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
    let group = VirtualMachine.get().rareData().bunConnectGroup(vm, socket.isSsl)

    let kind: SocketKind = if (socket.isSsl) {
        SocketKind.bunSocketTls
    } else {
        SocketKind.bunSocketTcp
    }

    let flags: Int32 = if (socket.flags.allowHalfOpen) {
        LIBUS_SOCKET_ALLOW_HALF_OPEN
    } else {
        0
    }

    let sslCtx: ?SslCtx = if (socket.isSsl) {
        socket.ownedSslCtx
    } else {
        None
    }

    match (socket.connection) {
        | Some(UnixOrHost.host(let host, let port)) =>
            // 去除 IPv6 方括号
            var clean: String = host
            if (host.length > 1 && host[0] == '[' && host[host.length - 1] == ']') {
                clean = host[1..host.length - 1]
            }

            let hostz = ZBox.fromBytes(clean)
            let port_ = port

            match (group.connect(kind, sslCtx, hostz, port_, flags)) {
                | ConnectResult.failed =>
                    return Some(Error.failedToOpenSocket)
                | ConnectResult.socket(let s) =>
                    s.ext = selfPtr
                    socket.socket = SocketHandler.from(s)
                | ConnectResult.connecting(let c) =>
                    c.ext = selfPtr
                    socket.socket = SocketHandler.fromConnecting(c)
            }

        | Some(UnixOrHost.unix(let u)) =>
            let s = group.connectUnix(kind, sslCtx, u, flags)
            if (s == null) {
                return Some(Error.failedToOpenSocket)
            }
            s.ext = selfPtr
            socket.socket = SocketHandler.from(s)

        | Some(UnixOrHost.fd(let f)) =>
            let s = group.fromFd(kind, sslCtx, f.native(), false)
            if (s == null) {
                return Some(Error.connectionFailed)
            }
            s.ext = selfPtr
            socket.socket = SocketHandler.from(s)
            onOpen(selfPtr, socket.socket)

        | None =>
            panic("doConnect requires connection to be set")
    }

    deref(socket)
    return None
}

// ============================================================================
// 回调处理 — 所有回调使用指针模式避免 noalias 重入问题
// 对应 Bun: NewSocket::{on_writable, on_timeout, on_end, on_close, on_open, ...}
// ============================================================================

/// onWritable 回调
/// PORT NOTE: 使用指针而非 &mut self — callback.call 重入 JS，
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
    if (socket.bufferedDataForNodeNet.length > 0 || socket.socket.isDetached()) {
        deref(socket)
        return
    }

    // 保持 handlers 在回调期间存活
    var scope = Handlers.enterRef(handlers)

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)
    match (callback.call(global, thisValue, [thisValue])) {
        | ok(_) => ()
        | err(err) =>
            let _ = handlers.callErrorHandler(thisValue, [thisValue, global.takeError(err)])
    }
    if (scope.exit()) {
        socket.handlers = None
    }
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

    var scope = Handlers.enterRef(handlers)

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)
    match (callback.call(global, thisValue, [thisValue])) {
        | ok(_) => ()
        | err(err) =>
            let _ = handlers.callErrorHandler(thisValue, [thisValue, global.takeError(err)])
    }
    if (scope.exit()) {
        socket.handlers = None
    }
}

/// handleConnectError — 连接错误处理
/// 对应 Bun: NewSocket.handle_connect_error
public func handleConnectError(socket: NewSocket, errno: Int32): Unit {
    let handlers = getHandlers(socket)

    // 保持 socket 存活
    ref_(socket)

    // 清理缓冲区
    socket.bufferedDataForNodeNet.clearAndFree()

    let needsDeref = !socket.socket.isDetached()
    socket.socket = SocketHandler.detached

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
    var errno_: Int32 = if (errno == SystemErrno.enoent) {
        SystemErrno.enoent
    } else {
        SystemErrno.econnrefused
    }
    let code_ = if (errno == SystemErrno.enoent) {
        "ENOENT"
    } else {
        "ECONNREFUSED"
    }

    let callback = handlers.onConnectError
    let global = handlers.globalObject
    let err = SystemError(
        errno: -errno_,
        message: "Failed to connect",
        syscall: "connect",
        code: code_,
    )

    var scope = Handlers.enterRef(handlers)

    if (callback.isEmpty()) {
        // 连接在打开前失败；允许包装器被 GC 回收
        if (!socket.thisValue.isFinalized()) {
            socket.thisValue.downgrade()
        }

        // 拒绝 promise
        if (let Some(promise) = handlers.promise.trySwap()) {
            handlers.promise.deinit()
            let errValue = err.toErrorInstanceWithAsyncStack(global, promise)
            promise.reject(global, errValue)
        }
        return
    }

    let thisValue = getThisValue(socket, global)
    thisValue.ensureStillAlive()
    socket.thisValue.downgrade()

    let errValue = err.toErrorInstance(global)
    let result = match (callback.call(global, thisValue, [thisValue, errValue])) {
        | ok(v) => v
        | err(e) => global.takeException(e),
    }

    if (scope.exit()) {
        socket.handlers = None
    }
}

/// onOpen 回调 — 连接建立时调用
/// 对应 Bun: NewSocket.on_open
public func onOpen(socket: NewSocket, socketHandler: SocketHandler): Unit {
    // 保持 socket 存活
    ref_(socket)

    // 更新内部 socket 实例
    socket.socket = socketHandler

    // TLS: 设置 SNI 和 ALPN
    if (socket.isSsl) {
        if (let Some(sslPtr) = socket.socket.ssl()) {
            if (!Ssl.isInitFinished(sslPtr)) {
                // 设置 SNI 主机名
                if (let Some(serverName) = socket.serverName) {
                    if (!serverName.isEmpty()) {
                        Ssl.setTlsextHostName(sslPtr, serverName)
                    }
                } else if (let Some(conn) = socket.connection) {
                    match (conn) {
                        | UnixOrHost.host(let host, _) =>
                            if (!host.isEmpty()) {
                                Ssl.setTlsextHostName(sslPtr, host)
                            }
                        | _ => ()
                    }
                }

                // 设置 ALPN 协议
                if (let Some(protos) = socket.protos) {
                    if (socket.isServer()) {
                        // 服务端: 设置 ALPN 回调
                        Ssl.setExData(sslPtr, 0, socket)
                        let sslCtx = Ssl.getSslCtx(sslPtr)
                        SslCtx.setAlpnSelectCb(sslCtx, selectAlpnCallback, null)
                    } else {
                        // 客户端: 设置 ALPN 协议列表
                        Ssl.setAlpnProtos(sslPtr, protos)
                    }
                }
            }
        }
    }

    // 更新 ext slot
    if (let Some(ctx) = socketHandler.ext) {
        ctx = socket
    }

    let handlers = getHandlers(socket)
    let callback = handlers.onOpen
    let handshakeCallback = handlers.onHandshake

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)

    markActive(socket)
    let _ = handlers.resolvePromise(thisValue)

    if (socket.isSsl) {
        // 仅在提供握手回调时调用打开回调
        if (callback.isEmpty() || handshakeCallback.isEmpty()) {
            deref(socket)
            return
        }
    } else {
        if (callback.isEmpty()) {
            deref(socket)
            return
        }
    }

    // 保持 handlers 在回调期间存活
    var scope = Handlers.enterRef(handlers)
    let result = match (callback.call(global, thisValue, [thisValue])) {
        | ok(v) => v
        | err(err) => global.takeException(err),
    }

    if (let Some(err) = result.toError()) {
        let rejected = handlers.rejectPromise(err) ?? true
        if (!rejected) {
            let _ = handlers.callErrorHandler(thisValue, [thisValue, err])
        }
        markInactive(socket)
    }
    if (scope.exit()) {
        socket.handlers = None
    }
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

    var scope = Handlers.enterRef(handlers)

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)
    match (callback.call(global, thisValue, [thisValue])) {
        | ok(_) => ()
        | err(err) =>
            let _ = handlers.callErrorHandler(thisValue, [thisValue, global.takeError(err)])
    }
    if (scope.exit()) {
        socket.handlers = None
    }
    deref(socket)
}

/// onHandshake 回调 — TLS 握手完成时调用
/// 对应 Bun: NewSocket.on_handshake
public func onHandshake(
    socket: NewSocket,
    s: SocketHandler,
    success: Int32,
    sslError: VerifyError,
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

    var scope = Handlers.enterRef(handlers)

    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)

    let result: JSValue
    if (isOpen) {
        result = match (callback.call(global, thisValue, [thisValue])) {
            | ok(v) => v
            | err(err) => global.takeException(err),
        }

        // 客户端只调用一次 onOpen
        if (!handlers.mode.isServer()) {
            handlers.onOpen.unprotect()
            handlers.onOpen = JSValue.zero
        }
    } else {
        let authorizationError: JSValue = if (sslError.errorNo == 0) {
            JSValue.null
        } else {
            verifyErrorToJs(sslError, global)
        }

        result = match (callback.call(global, thisValue, [thisValue, JSValue.from(authorized), authorizationError])) {
            | ok(v) => v
            | err(err) => global.takeException(err),
        }
    }

    if (let Some(errValue) = result.toError()) {
        let _ = handlers.callErrorHandler(thisValue, [thisValue, errValue])
    }
    if (scope.exit()) {
        socket.handlers = None
    }
}

/// onClose 回调 — 连接关闭时调用
/// 对应 Bun: NewSocket.on_close
public func onClose(
    socket: NewSocket,
    socketHandler: SocketHandler,
    err: Int32,
    reason: ?RawPtr,
): Unit {
    let handlers = getHandlers(socket)

    socket.detachNativeCallback()
    socket.socket = SocketHandler.detached

    // upgradeTLS 的原始双胞胎共享同一个 us_socket_t
    if (let Some(raw) = socket.twin) {
        socket.twin = None
        onClose(raw, socketHandler, err, reason)
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

    let result = match (callback.call(global, thisValue, [thisValue, JSValue.from(err)])) {
        | ok(v) => v
        | err(err) => global.takeException(err),
    }

    if (let Some(errValue) = result.toError()) {
        let _ = handlers.callErrorHandler(thisValue, [thisValue, errValue])
    }
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

        // 在 socket 活跃期间保持 JS 包装器存活
        if (socket.thisValue.isNotEmpty()) {
            socket.thisValue.upgrade(handlers.globalObject)
        }
    }
}

/// 标记为不活跃
public func markInactive(socket: NewSocket): Unit {
    if (socket.flags.isActive) {
        // 必须在 socket 上下文关闭前关闭 socket
        if (!socket.socket.isClosed()) {
            closeAndDetach(socket, CloseCode.normal)
            return
        }

        socket.flags.isActive = false

        // 允许 JS 包装器被 GC 回收
        if (!socket.thisValue.isFinalized()) {
            socket.thisValue.downgrade()
        }

        let vm = VirtualMachine.get()
        if (vm.isShuttingDown()) {
            socket.pollRef.unref(jsLoopCtx())
            return
        }

        let handlers = getHandlers(socket)
        if (Handlers.markInactive(handlers)) {
            socket.handlers = None
        }
        socket.pollRef.unref(jsLoopCtx())
    }
}

/// 关闭并分离
public func closeAndDetach(socket: NewSocket, code: CloseCode): Unit {
    let s = socket.socket
    socket.bufferedDataForNodeNet.clearAndFree()
    socket.socket = SocketHandler.detached
    socket.detachNativeCallback()
    s.close(code)
}

/// 获取 handlers
/// 对应 Bun: NewSocket.get_handlers
/// 返回 BackRef<Handlers>，约 40 个只读字段投影通过 Deref 进行。
public func getHandlers(socket: NewSocket): Handlers {
    return socket.handlers ?? panic("No handlers set on Socket")
}

/// 获取 this_value JS 引用
public func getThisValue(socket: NewSocket, global: JSGlobalObject): JSValue {
    if (let Some(value) = socket.thisValue.tryGet()) {
        return value
    }
    if (socket.thisValue.isFinalized()) {
        return JSValue.undefined
    }
    let value = socket.toJs(global)
    value.ensureStillAlive()
    socket.thisValue.setStrong(value, global)
    return value
}

/// 是否为服务端 socket
public func isServer(socket: NewSocket): Bool {
    if (socket.handlers.isNone()) {
        return false
    }
    return socket.handlers.mode.isServer()
}

// ============================================================================
// JS 绑定方法
// 对应 Bun: NewSocket::{resume_from_js, pause_from_js, set_keep_alive, set_no_delay}
// ============================================================================

/// JS: resume()
public func resumeFromJs(socket: NewSocket, global: JSGlobalObject): JSValue {
    if (socket.socket.isDetached()) {
        return JSValue.undefined
    }
    // TLS 升级的原始半部分是观测抽头；流量控制属于 TLS 半部分
    if (socket.flags.bypassTls) {
        return JSValue.undefined
    }
    if (socket.flags.isPaused) {
        let resumed = socket.socket.resumeStream()
        socket.flags.isPaused = !resumed
    }
    return JSValue.undefined
}

/// JS: pause()
public func pauseFromJs(socket: NewSocket, global: JSGlobalObject): JSValue {
    if (socket.socket.isDetached()) {
        return JSValue.undefined
    }
    if (socket.flags.bypassTls) {
        return JSValue.undefined
    }
    if (!socket.flags.isPaused) {
        let paused = socket.socket.pauseStream()
        socket.flags.isPaused = paused
    }
    return JSValue.undefined
}

/// JS: setKeepAlive(enabled, initialDelay)
public func setKeepAliveFromJs(
    socket: NewSocket,
    global: JSGlobalObject,
    enabled: Bool,
    initialDelay: UInt32,
): JSValue {
    return JSValue.from(socket.socket.setKeepAlive(enabled, initialDelay))
}

/// JS: setNoDelay(enabled)
public func setNoDelayFromJs(socket: NewSocket, global: JSGlobalObject, enabled: Bool): JSValue {
    return JSValue.from(socket.socket.setNoDelay(enabled))
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
        | WriteResult.success(let wrote, let total) =>
            socket.bytesWritten += wrote
            if (wrote == total) {
                socket.bufferedDataForNodeNet.clearAndFree()
            } else {
                socket.bufferedDataForNodeNet = data[wrote..]
            }
        | WriteResult.fail =>
            // 写入失败，关闭连接
            closeAndDetach(socket, CloseCode.normal)
    }
}

/// JS: write(data)
public func writeFromJs(
    socket: NewSocket,
    global: JSGlobalObject,
    data: JSValue,
): JSValue {
    if (socket.socket.isDetached()) {
        return JSValue.from(false)
    }

    let buffer = data.toBuffer(global)
    if (buffer.isNone()) {
        return JSValue.from(false)
    }

    let bytes = buffer.unwrap()

    // 如果有缓冲数据，先追加
    if (!socket.bufferedDataForNodeNet.isEmpty()) {
        socket.bufferedDataForNodeNet.append(bytes)
        return JSValue.from(true)
    }

    // 直接写入
    let result = socket.socket.write(bytes)
    match (result) {
        | WriteResult.success(let wrote, let total) =>
            socket.bytesWritten += wrote
            if (wrote < total) {
                socket.bufferedDataForNodeNet = bytes[wrote..]
            }
            return JSValue.from(true)
        | WriteResult.fail =>
            return JSValue.from(false)
    }
}

/// JS: end(data?)
public func endFromJs(
    socket: NewSocket,
    global: JSGlobalObject,
    data: ?JSValue,
): JSValue {
    if (let Some(d) = data) {
        writeFromJs(socket, global, d)
    }

    if (socket.bufferedDataForNodeNet.isEmpty()) {
        closeAndDetach(socket, CloseCode.normal)
    } else {
        socket.flags.endAfterFlush = true
    }
    return JSValue.undefined
}

/// JS: reload(handlerObject)
/// 对应 Bun: NewSocket.reload
public func reloadFromJs(
    socket: NewSocket,
    global: JSGlobalObject,
    handlerObject: JSValue,
): JSValue {
    let handlers = getHandlers(socket)
    let newHandlers = Handlers.fromJs(global, handlerObject, handlers.mode, handlers.vm)

    if (newHandlers.isErr()) {
        return JSValue.from(false)
    }

    // 服务端模式: handlers 嵌入在 Listener 中，直接更新
    // 客户端模式: 替换堆分配的 handlers
    if (socket.isServer()) {
        handlers.updateFrom(newHandlers.unwrap())
    } else {
        let oldHandlers = socket.handlers
        socket.handlers = newHandlers.unwrap()
        if (let Some(old) = oldHandlers) {
            heap.take(old)
        }
    }

    return JSValue.from(true)
}

// ============================================================================
// 原生回调管理
// ============================================================================

/// 附加原生回调
public func attachNativeCallback(socket: NewSocket, callback: NativeCallbacks): Bool {
    if (socket.nativeCallback != NativeCallbacks.none) {
        return false
    }
    socket.nativeCallback = callback
    return true
}

/// 分离原生回调
public func detachNativeCallback(socket: NewSocket): Unit {
    match (socket.nativeCallback) {
        | NativeCallbacks.h2(let h2) =>
            h2.onNativeClose()
            socket.nativeCallback = NativeCallbacks.none
        | NativeCallbacks.none => ()
    }
}

// ============================================================================
// 错误处理
// 对应 Bun: NewSocket.handle_error
// ============================================================================

/// 处理 JS 错误值
public func handleError(socket: NewSocket, errValue: JSValue): Unit {
    let handlers = getHandlers(socket)
    let vm = handlers.vm
    if (vm.isShuttingDown()) {
        return
    }

    var scope = Handlers.enterRef(handlers)
    let global = handlers.globalObject
    let thisValue = getThisValue(socket, global)
    let _ = handlers.callErrorHandler(thisValue, [thisValue, errValue])
    if (scope.exit()) {
        socket.handlers = None
    }
}

// ============================================================================
// JS 构造和转换
// ============================================================================

/// 转换为 JS 值
public func toJs(socket: NewSocket, global: JSGlobalObject): JSValue {
    if (socket.isSsl) {
        return JsTlsSocket.toJs(socket, global)
    } else {
        return JsTcpSocket.toJs(socket, global)
    }
}

/// JS 构造器 (禁止直接构造)
public func constructor(global: JSGlobalObject): JSValue {
    return global.throw("Cannot construct Socket")
}

// ============================================================================
// ALPN 选择回调
// 对应 Bun: select_alpn_callback
// ============================================================================

/// ALPN 协议选择回调
/// SSL_CTX_set_alpn_select_cb 注册在监听器级别的 SSL_CTX 上，
/// 其 arg 在每个接受的连接间共享。
func selectAlpnCallback(
    ssl: Ssl,
    out: RawPtr,
    outlen: RawPtr,
    in_: RawPtr,
    inlen: UInt32,
): Int32 {
    let thisPtr = Ssl.getExData(ssl, 0)
    if (thisPtr == null) {
        return SSL_TLSEXT_ERR_NOACK
    }

    let socket = thisPtr as NewSocket
    if (let Some(protos) = socket.protos) {
        if (protos.isEmpty()) {
            return SSL_TLSEXT_ERR_NOACK
        }

        let status = Ssl.selectNextProto(out, outlen, protos, in_, inlen)

        if (status == OPENSSL_NPN_NEGOTIATED) {
            return SSL_TLSEXT_ERR_OK
        } else {
            return SSL_TLSEXT_ERR_ALERT_FATAL
        }
    } else {
        return SSL_TLSEXT_ERR_NOACK
    }
}

// ============================================================================
// 辅助
// ============================================================================

/// 获取 JS 事件循环上下文
func jsLoopCtx(): EventLoopCtx {
    return PosixEventLoop.getVmCtx(AllocatorType.js)
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
            | h2(let parser) => parser.onWritable()
            | none => false
        }
    }
}
