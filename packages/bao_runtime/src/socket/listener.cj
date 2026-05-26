// Socket 监听器 — TCP/TLS 服务器监听管理
// 对应 Bun: src/runtime/socket/Listener.zig
// 管理 Bun.listen() 返回的监听器对象的生命周期
package bao_runtime.socket

import bao_core.*
import bao_collections.{HashMap as CollectionHashMap, ArrayList as CollectionArrayList}
import bao_jsc.*
import bao_uws_sys.{SocketGroup as UwsSocketGroup, SocketKind, UsSocket, ListenSocket, ConnectingSocket, UsBunVerifyError, SocketHandler}

// ============================================================================
// 监听器类型
// 对应 Bun: Listener.ListenerType
// ============================================================================

/// 监听器后端类型
public enum ListenerType {
    /// uWS TCP/TLS 监听器
    | Uws(UwsListenSocket)
    /// Windows 命名管道
    | NamedPipe(NamedPipeContext)
    /// 未初始化
    | None

    public func isNone(): Bool {
        match (this) {
            case None => true
            case _ => false
        }
    }
}

// ============================================================================
// uWS 监听套接字 (占位)
// ============================================================================

/// uWS 监听套接字
public class UwsListenSocket {
    public var socket: ?ListenSocket

    public init() {
        socket = None
    }

    public init(socket: ListenSocket) {
        this.socket = Some(socket)
    }

    /// 关闭监听套接字
    public func close(): Unit {
        if (let Some(s) <- socket) {
            s.close()
        }
        socket = None
    }

    /// 获取本地端口
    public func getLocalPort(): UInt16 {
        if (let Some(s) <- socket) {
            return UInt16(s.getLocalPort())
        }
        return 0
    }

    /// 获取本地地址
    public func getLocalAddress(buf: Array<UInt8>): ?Array<UInt8> {
        if (let Some(s) <- socket) {
            return s.getLocalAddress(buf)
        }
        return None
    }

    /// 添加服务器名称 (SNI)
    public func addServerName(name: String, ctx: SslContext, ssl: ?SslContext): Bool {
        return true
    }

    /// 移除服务器名称
    public func removeServerName(name: String): Unit {}
}

public class ListenerHandleTable {
    private static var nextId: UIntNative = UIntNative(1)
    private static var listeners: CollectionHashMap<UIntNative, Listener> = CollectionHashMap<UIntNative, Listener>()

    public static func allocate(listener: Listener): UIntNative {
        let id = nextId
        nextId += UIntNative(1)
        if (nextId == UIntNative(0)) {
            nextId = UIntNative(1)
        }
        listeners.put(id, listener)
        return id
    }

    public static func lookup(id: UIntNative): ?Listener {
        if (id == UIntNative(0)) {
            return None
        }
        return listeners.get(id)
    }

    public static func release(id: UIntNative): ?Listener {
        if (id == UIntNative(0)) {
            return None
        }
        return listeners.remove(id)
    }
}

/// SSL 上下文占位
public class SslContext {
    public init() {}
}

private func listenerUnsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + Int64(i)).write(Int8(Int64(s[Int64(i)]) & 0xFF))
        }
        (bytesPtr + Int64(len)).write(Int8(0))
        return bytesPtr
    }
}

private func listenerUnsafeNewBytes(s: String): CPointer<UInt8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len))
        let bytesPtr = CPointer<UInt8>(ptr)
        for (i in 0..len) {
            (bytesPtr + Int64(i)).write(UInt8(Int64(s[Int64(i)]) & 0xFF))
        }
        return bytesPtr
    }
}

/// 命名管道上下文占位
public class NamedPipeContext {
    public init() {}
}

// ============================================================================
// Socket 监听器
// 对应 Bun: Listener struct
// ============================================================================

/// Socket 监听器
/// 对应 Zig: const Listener = @This()
/// 管理 Bun.listen() 创建的服务器套接字的生命周期
public class Listener {
    /// 事件处理器
    public var handlers: Handlers
    /// 监听器后端
    public var listener: ListenerType
    /// 连接信息 (主机名/Unix 路径/fd)
    public var connection: ConnectionTarget
    /// 是否启用 SSL
    public var ssl: Bool
    /// ALPN 协议列表
    public var protos: ?String
    /// SSL 上下文
    public var secureCtx: ?SslContext
    /// JS 数据引用
    public var strongData: JsValue
    /// JS 自身引用 (防止 GC)
    public var strongSelf: JsValue
    /// libus listener/group ext 中保存的稳定数字句柄；0 表示未绑定。
    public var nativeHandle: UIntNative

    public init(handlers: Handlers) {
        this.handlers = handlers
        this.listener = ListenerType.None
        this.connection = ConnectionTarget.Host("", 0)
        this.ssl = false
        this.protos = None
        this.secureCtx = None
        this.strongData = JsValue.UNDEFINED
        this.strongSelf = JsValue.UNDEFINED
        this.nativeHandle = UIntNative(0)
    }

    // ========================================================================
    // 监听
    // 对应 Bun: Listener.listen
    // ========================================================================

    /// 开始监听
    /// 对应 Zig: listen(globalObject, opts)
    public static func listen(globalObject: JsObject, opts: JsValue, vm: VirtualMachine): JsValue {
        // 验证参数
        if (opts.valueType != JsValueType.Object) {
            return JsValue("Expected object")
        }

        // 解析 Socket 配置
        let config = SocketConfig.fromJS(vm, opts, globalObject, true)
        match (config) {
            case Some(cfg) =>
                let handlers = cfg.handlers

                // 创建 Listener
                let listener = Listener(handlers)
                listener.ssl = match (cfg.ssl) {
                    case Some(_) => true
                    case None => false
                }

                match (cfg.connection()) {
                    case ConnectionTarget.Host(host, port) =>
                        if (listener.ssl) {
                            return JsValue("ENOSYS: TLS listener requires native SSL_CTX FFI pointer")
                        }
                        let group = handlers.socketGroup
                        if (group.getPtr().isNull() || group.getLoop().isNull()) {
                            return JsValue("ENOSYS: uWS socket group is not initialized for listener")
                        }
                        let id = ListenerHandleTable.allocate(listener)
                        listener.nativeHandle = id
                        let hostPtr = listenerUnsafeNewCString(host)
                        let errPtr = unsafe { malloc(UIntNative(4)) }
                        unsafe { CPointer<Int32>(errPtr).write(Int32(0)) }
                        let listenSocket = group.listen(SocketKind.bun_listener_tcp, CPointer<Unit>(), hostPtr, Int32(port), cfg.socketFlags(), 8, CPointer<Int32>(errPtr))
                        let err = unsafe { CPointer<Int32>(errPtr).read() }
                        unsafe { free(errPtr) }
                        unsafe { free(CPointer<Unit>(hostPtr)) }
                        if (listenSocket.isNone()) {
                            ListenerHandleTable.release(id)
                            listener.nativeHandle = UIntNative(0)
                            return JsValue("uWS TCP listen failed")
                        }
                        let rawListen = listenSocket.getOrThrow()
                        let ext = CPointer<UIntNative>(rawListen.ext())
                        unsafe { ext.write(id) }
                        listener.listener = ListenerType.Uws(UwsListenSocket(rawListen))
                        listener.connection = ConnectionTarget.Host(host, port)
                    case ConnectionTarget.Unix(path) =>
                        if (listener.ssl) {
                            return JsValue("ENOSYS: TLS listener requires native SSL_CTX FFI pointer")
                        }
                        let group = handlers.socketGroup
                        if (group.getPtr().isNull() || group.getLoop().isNull()) {
                            return JsValue("ENOSYS: uWS socket group is not initialized for listener")
                        }
                        let id = ListenerHandleTable.allocate(listener)
                        listener.nativeHandle = id
                        let pathPtr = listenerUnsafeNewBytes(path)
                        let errPtr = unsafe { malloc(UIntNative(4)) }
                        unsafe { CPointer<Int32>(errPtr).write(Int32(0)) }
                        let listenSocket = group.listenUnix(SocketKind.bun_listener_tcp, CPointer<Unit>(), pathPtr, UIntNative(path.size), cfg.socketFlags(), 8, CPointer<Int32>(errPtr))
                        let err = unsafe { CPointer<Int32>(errPtr).read() }
                        unsafe { free(errPtr) }
                        unsafe { free(CPointer<Unit>(pathPtr)) }
                        if (listenSocket.isNone()) {
                            ListenerHandleTable.release(id)
                            listener.nativeHandle = UIntNative(0)
                            return JsValue("uWS Unix socket listen failed")
                        }
                        let rawListen = listenSocket.getOrThrow()
                        let ext = CPointer<UIntNative>(rawListen.ext())
                        unsafe { ext.write(id) }
                        listener.listener = ListenerType.Uws(UwsListenSocket(rawListen))
                        listener.connection = ConnectionTarget.Unix(path)
                    case ConnectionTarget.Fd(fd) =>
                        // 不支持从 fd 监听
                        return JsValue("Bun does not support listening on a file descriptor.")
                }

                // 设置默认数据
                if (cfg.defaultData.valueType != JsValueType.Undefined) {
                    listener.strongData = cfg.defaultData
                }

                return JsValue.UNDEFINED  // 实际返回 listener 的 JS 包装器
            case None =>
                return JsValue("Invalid options")
        }
    }

    /// 重新加载 SSL 配置
    /// 对应 Bun: pub fn reload(`this`: *Listener, globalObject: *jsc.JSGlobalObject, callframe: *jsc.CallFrame) bun.JSError!JsValue
    /// 允许在不重启服务器的情况下更新 TLS 证书
    public func reload(globalObject: JsObject, args: CollectionArrayList<JsValue>): JsValue {
        // 验证是否有SSL
        if (!ssl) {
            throw JsTypeError("Cannot reload() on a non-SSL listener")
        }

        // 解析新的TLS配置
        let options = args[0]
        if (options.isObject()) {
            let newTls = options.get(globalObject, "tls")
            if (newTls.isSome() && newTls.getOrThrow().isObject()) {
                // 重新配置SSL上下文
                // 对应 Bun: SSLConfig.fromJS(globalObject, newTls)
                // 更新 secureCtx
            }
        }

        return JsValue.UNDEFINED
    }

    /// 构造函数
    /// 对应 Bun: pub fn constructor(*jsc.JSGlobalObject, _: *jsc.CallFrame) bun.JSError!*Listener
    public static func constructor(globalObject: JsObject): Listener {
        let listener = Listener(Handlers(VirtualMachine(), globalObject, SocketMode.Server))
        listener.listener = ListenerType.None
        listener.connection = ConnectionTarget.Host("", 0)
        listener.ssl = false
        return listener
    }

    /// 当新连接创建时的回调
    /// 对应 Bun: pub fn onCreate(comptime ssl: bool, listener: *Listener, socket: uws.NewSocketHandler(ssl)) *NewSocket(ssl)
    /// 在 uWS 接受新连接后创建对应的 NewSocket 包装器，并把 accepted socket ext 绑定到 NewSocket handle。
    public func onCreate(socket: UsSocket): NewSocket {
        let newSocket = NewSocket(this.ssl)
        newSocket.handlers = Some(this.handlers)
        newSocket.connection = Some(this.connection)
        newSocket.thisValue = JsRef(this.strongSelf)
        newSocket.socket = SocketHandler.fromConnected(this.ssl, socket)
        NewSocketHandleTable.stamp(newSocket.socket, newSocket)
        markActive(newSocket)
        return newSocket
    }

    // ========================================================================
    // 连接
    // 对应 Bun: Listener.connect
    // ========================================================================

    /// 建立客户端连接
    /// 对应 Zig: connect(globalObject, opts)
    public static func connect(globalObject: JsObject, opts: JsValue, vm: VirtualMachine): JsValue {
        return connectInner(globalObject, Option<Socket>.None, Option<Socket>.None, opts, vm)
    }

    /// 内部连接实现
    /// 对应 Zig: connectInner
    public static func connectInner(globalObject: JsObject, prevTcp: ?Socket, prevTls: ?Socket, opts: JsValue, vm: VirtualMachine): JsValue {
        if (opts.valueType != JsValueType.Object) {
            return JsValue("Expected options object")
        }

        // 解析配置
        let config = SocketConfig.fromJS(vm, opts, globalObject, false)
        match (config) {
            case Some(cfg) =>
                let handlers = cfg.handlers
                let sslEnabled = match (cfg.ssl) {
                    case Some(_) => true
                    case None => false
                }

                // 创建 Promise
                let promise = JsValue.UNDEFINED  // 实际创建 JSPromise

                // 创建 Socket
                let socket = NewSocket(sslEnabled)
                socket.handlers = Some(handlers)
                socket.flags.allowHalfOpen = cfg.allowHalfOpen
                socket.connection = Some(cfg.connection())
                if (let Some(sslConfig) <- cfg.ssl) {
                    let ctx = sslConfig.asUSocketsForClientVerification().createSSLContext()
                    if (ctx.isNone()) {
                        return JsValue("TLS context creation failed")
                    }
                    socket.ownedSslCtx = ctx
                }

                let err = doConnect(socket)
                if (let Some(e) <- err) {
                    if (let Some(ctx) <- socket.ownedSslCtx) {
                        socket.ownedSslCtx = None
                        BoringSSL.sslCtxFree(ctx)
                    }
                    return JsValue(e.message)
                }

                return promise
            case None =>
                return JsValue("Invalid options")
        }
    }

    // ========================================================================
    // 生命周期管理
    // 对应 Bun: Listener.stop/dispose/finalize/deinit
    // ========================================================================

    /// 停止监听
    /// 对应 Zig: stop
    public func stop(forceClose: Bool): JsValue {
        doStop(forceClose)
        return JsValue.UNDEFINED
    }

    /// 释放监听器
    /// 对应 Zig: dispose
    public func dispose(): JsValue {
        doStop(true)
        return JsValue.UNDEFINED
    }

    /// 内部停止实现
    /// 对应 Zig: doStop
    public func doStop(forceClose: Bool): Unit {
        if (listener.isNone()) {
            return
        }
        if (nativeHandle != UIntNative(0)) {
            ListenerHandleTable.release(nativeHandle)
            nativeHandle = UIntNative(0)
        }

        // 取消 Unix 域套接字文件链接
        match (connection) {
            case ConnectionTarget.Unix(path) =>
                unlinkUnixSocketPath(path)
            case _ => ()
        }

        // 关闭监听器
        match (listener) {
            case ListenerType.Uws(socket) => socket.close()
            case ListenerType.NamedPipe(ctx) => ()
            case ListenerType.None => ()
        }
        listener = ListenerType.None

        // 处理活跃连接
        if (handlers.activeConnections == 0) {
            // 无活跃连接, 清理引用
            strongSelf = JsValue.UNDEFINED
            strongData = JsValue.UNDEFINED
        } else if (forceClose) {
            // 强制关闭所有活跃连接
        }
    }

    /// GC finalize
    /// 对应 Zig: finalize
    public func finalize(): Unit {
        if (nativeHandle != UIntNative(0)) {
            ListenerHandleTable.release(nativeHandle)
            nativeHandle = UIntNative(0)
        }
        let current = listener
        listener = ListenerType.None

        match (current) {
            case ListenerType.Uws(socket) =>
                match (connection) {
                    case ConnectionTarget.Unix(path) => unlinkUnixSocketPath(path)
                    case _ => ()
                }
                socket.close()
            case ListenerType.NamedPipe(ctx) => ()
            case ListenerType.None => ()
        }

        deinit()
    }

    /// 释放资源
    /// 对应 Zig: deinit
    public func deinit(): Unit {
        strongSelf = JsValue.UNDEFINED
        strongData = JsValue.UNDEFINED

        // 如果仍有活跃连接, 强制关闭
        if (handlers.activeConnections > 0) {
            // closeAll()
        }

        match (connection) {
            case ConnectionTarget.Host(_, _) | ConnectionTarget.Unix(_) =>
                connection.deinit()
            case _ => ()
        }

        protos = None
        secureCtx = None
        handlers.deinit()
    }

    // ========================================================================
    // 属性访问
    // 对应 Bun: Listener.getData/setData/getConnectionsCount 等
    // ========================================================================

    /// 获取数据
    /// 对应 Zig: getData
    public func getData(): JsValue {
        return strongData
    }

    /// 设置数据
    /// 对应 Zig: setData
    public func setData(globalObject: JsObject, value: JsValue): Unit {
        strongData = value
    }

    /// 获取活跃连接数
    /// 对应 Zig: getConnectionsCount
    public func getConnectionsCount(): JsValue {
        return JsValue(Float64(handlers.activeConnections))
    }

    /// 获取 Unix 路径
    /// 对应 Zig: getUnix
    public func getUnix(globalObject: JsObject): JsValue {
        match (connection) {
            case ConnectionTarget.Unix(path) => return JsValue(path)
            case _ => return JsValue.UNDEFINED
        }
    }

    /// 获取主机名
    /// 对应 Zig: getHostname
    public func getHostname(globalObject: JsObject): JsValue {
        match (connection) {
            case ConnectionTarget.Host(host, _) => return JsValue(host)
            case _ => return JsValue.UNDEFINED
        }
    }

    /// 获取端口
    /// 对应 Zig: getPort
    public func getPort(): JsValue {
        match (connection) {
            case ConnectionTarget.Host(_, port) => return JsValue(Float64(port))
            case _ => return JsValue.UNDEFINED
        }
    }

    /// 获取文件描述符
    /// 对应 Zig: getFD
    public func getFD(): JsValue {
        match (listener) {
            case ListenerType.Uws(socket) =>
                if (let Some(s) <- socket.socket) {
                    return JsValue(Float64(s.fd()))
                }
                return JsValue(-1.0)
            case _ => return JsValue(-1.0)
        }
    }

    /// 引用 (保持事件循环活跃)
    /// 对应 Zig: ref
    public func refSocket(globalObject: JsObject): JsValue {
        return JsValue.UNDEFINED
    }

    /// 取消引用
    /// 对应 Zig: unref
    public func unrefSocket(globalObject: JsObject): JsValue {
        return JsValue.UNDEFINED
    }

    /// 获取套接字名称 (getsockname)
    /// 对应 Zig: getsockname
    public func getsockname(globalObject: JsObject, out: JsValue): JsValue {
        match (listener) {
            case ListenerType.Uws(socket) =>
                // 填充 out 对象的 family/address/port
                return JsValue.UNDEFINED
            case _ => return JsValue.UNDEFINED
        }
    }

    /// 添加 SNI 服务器名称
    /// 对应 Zig: addServerName
    public func addServerName(globalObject: JsObject, hostname: JsValue, tls: JsValue): JsValue {
        if (!ssl) {
            return JsValue("addServerName requires SSL support")
        }

        match (hostname.valueType) {
            case JsValueType.String =>
                let name = hostname.toString()
                if (name.isEmpty()) {
                    return JsValue("hostname pattern cannot be empty")
                }
                // 添加 SNI 映射
                return JsValue.UNDEFINED
            case _ => return JsValue("hostname pattern expects a string")
        }
    }

    // ========================================================================
    // 私有辅助方法
    // ========================================================================

    /// 取消 Unix 域套接字文件链接
    /// 对应 Zig: unlinkUnixSocketPath
    private func unlinkUnixSocketPath(path: String): Unit {
        if (path.isEmpty()) {
            return
        }
        // Linux 抽象套接字以 NUL 字节开头, 无文件系统入口
        if (path.size > 0 && path[0].toString() == "\u{00}") {
            return
        }
        // 通过 bao_sys unlink 删除文件
    }
}
