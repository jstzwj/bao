// 严格翻译自: src/runtime/socket/uws_dispatch.zig
// Socket 事件分发 — 事件循环调用的核心分发函数
package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_uws_sys.*

// ============================================================================
// Socket 事件分发
// 对应 Bun: uws_dispatch.zig
// loop.c 为每个可读/可写/关闭等事件调用这些 us_dispatch_* 导出
// 根据 s.kind 切换并直接调用正确的处理器
// ============================================================================

/// 虚函数表
/// 对应 Zig: VTable struct
public class VTable {
    public var onOpen: ?(bao_uws_sys.UsSocket, Int32, String, Int32) -> bao_uws_sys.UsSocket
    public var onData: ?(bao_uws_sys.UsSocket, String, Int32) -> bao_uws_sys.UsSocket
    public var onFd: ?(bao_uws_sys.UsSocket, Int32) -> bao_uws_sys.UsSocket
    public var onWritable: ?(bao_uws_sys.UsSocket) -> bao_uws_sys.UsSocket
    public var onClose: ?(bao_uws_sys.UsSocket, Int32, ?Any) -> bao_uws_sys.UsSocket
    public var onTimeout: ?(bao_uws_sys.UsSocket) -> bao_uws_sys.UsSocket
    public var onLongTimeout: ?(bao_uws_sys.UsSocket) -> bao_uws_sys.UsSocket
    public var onEnd: ?(bao_uws_sys.UsSocket) -> bao_uws_sys.UsSocket
    public var onConnectError: ?(bao_uws_sys.UsSocket, Int32) -> bao_uws_sys.UsSocket
    public var onConnectingError: ?(bao_uws_sys.ConnectingSocket, Int32) -> bao_uws_sys.ConnectingSocket
    public var onHandshake: ?(bao_uws_sys.UsSocket, Int32, bao_uws_sys.UsBunVerifyError, ?Any) -> Unit

    public init() {
        onOpen = None
        onData = None
        onFd = None
        onWritable = None
        onClose = None
        onTimeout = None
        onLongTimeout = None
        onEnd = None
        onConnectError = None
        onConnectingError = None
        onHandshake = None
    }
}

/// kind 到 vtable 的映射表
/// 对应 Zig: const tables = blk: { ... }
/// Zig kinds 获得编译时生成的 Trampolines(H) vtable
/// C++ kinds 使用 per-group vtable
public class DispatchTables {
    private var tables: ArrayList<Tuple2<SocketKind, VTable>>

    public init() {
        tables = ArrayList<Tuple2<SocketKind, VTable>>()

        // Bun.connect / Bun.listen
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.bun_socket_tcp, VTableFactory.makeBunSocket(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.bun_socket_tls, VTableFactory.makeBunSocket(true)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.bun_listener_tcp, VTableFactory.makeBunListener(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.bun_listener_tls, VTableFactory.makeBunListener(true)))

        // HTTP 客户端线程
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.http_client, VTableFactory.makeHTTPClient(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.http_client_tls, VTableFactory.makeHTTPClient(true)))

        // WebSocket 客户端
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.ws_client_upgrade, VTableFactory.makeWSUpgrade(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.ws_client_upgrade_tls, VTableFactory.makeWSUpgrade(true)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.ws_client, VTableFactory.makeWSClient(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.ws_client_tls, VTableFactory.makeWSClient(true)))

        // SQL 驱动
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.postgres, VTableFactory.makePostgres(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.postgres_tls, VTableFactory.makePostgres(true)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.mysql, VTableFactory.makeMySQL(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.mysql_tls, VTableFactory.makeMySQL(true)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.valkey, VTableFactory.makeValkey(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.valkey_tls, VTableFactory.makeValkey(true)))

        // IPC
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.spawn_ipc, VTableFactory.makeSpawnIPC()))
    }

    /// 获取指定 kind 的 vtable
    public func get(kind: SocketKind): ?VTable {
        for (entry in tables) {
            if (entry.first == kind) {
                return entry.second
            }
        }
        return None
    }
}

/// 获取 socket 的 vtable
/// 对应 Zig: inline fn vt(s: *us_socket_t) *const VTable
func vt(s: bao_uws_sys.UsSocket): VTable {
    let kind = s.kind()
    match (kind) {
        case invalid => throw Exception("us_socket_t with kind=invalid")
        case dynamic | uws_http | uws_http_tls | uws_ws | uws_ws_tls =>
            throw Exception("ENOSYS: dynamic/uWS group vtable bridge is not wired for native us_socket_t dispatch")
        case _ =>
            let tables = DispatchTables()
            let vtableOpt = tables.get(kind)
            if (vtableOpt.isSome()) {
                return vtableOpt.getOrThrow()
            }
            return VTable()
    }
}

func vtc(c: bao_uws_sys.ConnectingSocket): VTable {
    let kind = c.kind()
    match (kind) {
        case invalid => throw Exception("us_connecting_socket_t with kind=invalid")
        case dynamic | uws_http | uws_http_tls | uws_ws | uws_ws_tls =>
            throw Exception("ENOSYS: dynamic/uWS group vtable bridge is not wired for native us_connecting_socket_t dispatch")
        case _ =>
            let tables = DispatchTables()
            let vtableOpt = tables.get(kind)
            if (vtableOpt.isSome()) {
                return vtableOpt.getOrThrow()
            }
            return VTable()
    }
}

// ============================================================================
// 分发函数
// 对应 Zig: export fn us_dispatch_*
// 这些函数由事件循环调用
// ============================================================================

private func dispatchStringFromCString(ptr: CPointer<Int8>, len: Int32): String {
    if (ptr.isNull() || len <= 0) {
        return ""
    }
    var out = ""
    for (i in 0..Int64(len)) {
        out += Rune(Int32((ptr + i).read())).toString()
    }
    return out
}

/// 连接打开分发
/// 对应 Zig: export fn us_dispatch_open
public func usDispatchOpen(s: bao_uws_sys.UsSocket, isClient: Int32, ip: String, ipLen: Int32): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onOpen.isSome()) {
        return vtable.onOpen.getOrThrow()(s, isClient, ip, ipLen)
    }
    return s
}

public func usDispatchData(s: bao_uws_sys.UsSocket, data: String, len: Int32): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onData.isSome()) {
        return vtable.onData.getOrThrow()(s, data, len)
    }
    return s
}

public func usDispatchFd(s: bao_uws_sys.UsSocket, fd: Int32): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onFd.isSome()) {
        return vtable.onFd.getOrThrow()(s, fd)
    }
    return s
}

public func usDispatchWritable(s: bao_uws_sys.UsSocket): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onWritable.isSome()) {
        return vtable.onWritable.getOrThrow()(s)
    }
    return s
}

public func usDispatchClose(s: bao_uws_sys.UsSocket, code: Int32, reason: ?Any): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onClose.isSome()) {
        return vtable.onClose.getOrThrow()(s, code, reason)
    }
    return s
}

public func usDispatchTimeout(s: bao_uws_sys.UsSocket): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onTimeout.isSome()) {
        return vtable.onTimeout.getOrThrow()(s)
    }
    return s
}

public func usDispatchLongTimeout(s: bao_uws_sys.UsSocket): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onLongTimeout.isSome()) {
        return vtable.onLongTimeout.getOrThrow()(s)
    }
    return s
}

public func usDispatchEnd(s: bao_uws_sys.UsSocket): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onEnd.isSome()) {
        return vtable.onEnd.getOrThrow()(s)
    }
    return s
}

/// 连接错误分发
public func usDispatchConnectError(s: bao_uws_sys.UsSocket, code: Int32): ?bao_uws_sys.UsSocket {
    let vtable = vt(s)
    if (vtable.onConnectError.isSome()) {
        return vtable.onConnectError.getOrThrow()(s, code)
    }
    return s
}

/// 连接中错误分发
public func usDispatchConnectingError(c: bao_uws_sys.ConnectingSocket, code: Int32): ?bao_uws_sys.ConnectingSocket {
    let vtable = vtc(c)
    if (vtable.onConnectingError.isSome()) {
        return vtable.onConnectingError.getOrThrow()(c, code)
    }
    return c
}

/// 握手分发
public func usDispatchHandshake(s: bao_uws_sys.UsSocket, ok: Int32, err: bao_uws_sys.UsBunVerifyError): Unit {
    let vtable = vt(s)
    if (vtable.onHandshake.isSome()) {
        vtable.onHandshake.getOrThrow()(s, ok, err, None)
        return
    }

    match (s.kind()) {
        case bun_socket_tls | bun_listener_tls | http_client_tls | ws_client_upgrade_tls |
             ws_client_tls | postgres_tls | mysql_tls | valkey_tls | uws_http_tls | uws_ws_tls =>
            throw Exception(
                "ENOSYS: TLS handshake dispatch is not wired; missing " +
                "vtable.onHandshake bridge from native uWS SSL callback to " +
                "the owning Bao socket/listener handler"
            )
        case _ => ()
    }
}

/// SSL 原始数据分接 — unavailable until the native raw-tap bridge is wired.
public func usDispatchSslRawTap(s: bao_uws_sys.UsSocket, data: String, len: Int32): ?bao_uws_sys.UsSocket {
    return None
}

// ============================================================================
// Native C callback glue
// ============================================================================

@C
public func bao_us_dispatch_open(raw: CPointer<Unit>, isClient: Int32, ip: CPointer<Int8>, ipLen: Int32): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchOpen(socket, isClient, dispatchStringFromCString(ip, ipLen), ipLen)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_data(raw: CPointer<Unit>, data: CPointer<Int8>, len: Int32): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchData(socket, dispatchStringFromCString(data, len), len)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_fd(raw: CPointer<Unit>, fd: Int32): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchFd(socket, fd)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_writable(raw: CPointer<Unit>): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchWritable(socket)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_close(raw: CPointer<Unit>, code: Int32, reason: CPointer<Unit>): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchClose(socket, code, if (reason.isNull()) { None } else { Some(reason) })
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_timeout(raw: CPointer<Unit>): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchTimeout(socket)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_long_timeout(raw: CPointer<Unit>): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchLongTimeout(socket)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_end(raw: CPointer<Unit>): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchEnd(socket)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_connect_error(raw: CPointer<Unit>, code: Int32): CPointer<Unit> {
    let socket = bao_uws_sys.UsSocket(raw)
    let next = usDispatchConnectError(socket, code)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_connecting_error(raw: CPointer<Unit>, code: Int32): CPointer<Unit> {
    let socket = bao_uws_sys.ConnectingSocket(raw)
    let next = usDispatchConnectingError(socket, code)
    if (next.isSome()) {
        return next.getOrThrow().getPtr()
    }
    return CPointer<Unit>()
}

@C
public func bao_us_dispatch_handshake(raw: CPointer<Unit>, ok: Int32, err: bao_uws_sys.UsBunVerifyErrorRaw, customData: CPointer<Unit>): Unit {
    usDispatchHandshake(bao_uws_sys.UsSocket(raw), ok, bao_uws_sys.UsBunVerifyError(err))
}

/// BunSocket TCP dispatch adapter.
///
/// Bun stores `*?*NewSocket` in the uWS ext slot and forwards to NewSocket.onOpen/onData/onWritable/onClose.
/// Bao stores a stable NewSocketHandle in the uWS ext slot and resolves through NewSocketHandleTable.
public class BunSocketDispatch {
    private static func missingExt(eventName: String): Exception {
        return Exception("ENOSYS: BunSocket TCP " + eventName + " dispatch requires native us_socket_t ext handle bridge")
    }

    private static func lookup(s: bao_uws_sys.UsSocket, eventName: String): NewSocket {
        let handle = s.loadExtRaw()
        let socket = NewSocketHandleTable.lookup(handle)
        if (socket.isNone()) {
            throw missingExt(eventName)
        }
        return socket.getOrThrow()
    }

    private static func lookup(c: bao_uws_sys.ConnectingSocket, eventName: String): NewSocket {
        let handle = c.loadExtRaw()
        let socket = NewSocketHandleTable.lookup(handle)
        if (socket.isNone()) {
            throw missingExt(eventName)
        }
        return socket.getOrThrow()
    }

    public static func onOpen(s: bao_uws_sys.UsSocket, isClient: Int32, ip: String, ipLen: Int32): bao_uws_sys.UsSocket {
        let socket = lookup(s, "onOpen")
        onOpen(socket, SocketHandler.fromConnected(false, s))
        return s
    }

    public static func onData(s: bao_uws_sys.UsSocket, data: String, len: Int32): bao_uws_sys.UsSocket {
        let socket = lookup(s, "onData")
        onData(socket, SocketHandler.fromConnected(false, s), data.toArray()[0..Int64(len)])
        return s
    }

    public static func onWritable(s: bao_uws_sys.UsSocket): bao_uws_sys.UsSocket {
        let socket = lookup(s, "onWritable")
        onWritable(socket, SocketHandler.fromConnected(false, s))
        return s
    }

    public static func onClose(s: bao_uws_sys.UsSocket, code: Int32, reason: ?Any): bao_uws_sys.UsSocket {
        let socket = lookup(s, "onClose")
        onClose(socket, SocketHandler.fromConnected(false, s), code, None)
        return s
    }

    public static func onConnectError(s: bao_uws_sys.UsSocket, code: Int32): bao_uws_sys.UsSocket {
        let socket = lookup(s, "onConnectError")
        handleConnectError(socket, code)
        return s
    }

    public static func onConnectingError(c: bao_uws_sys.ConnectingSocket, code: Int32): bao_uws_sys.ConnectingSocket {
        let socket = lookup(c, "onConnectingError")
        handleConnectError(socket, code)
        return c
    }
}

/// VTable 工厂
/// 对应 Zig 中各 handler 适配器
public class BunListenerDispatch {
    private static func missingListener(): Exception {
        return Exception("ENOSYS: BunListener TCP open dispatch requires native us_listen_socket_t ext handle bridge")
    }

    private static func lookupListener(s: bao_uws_sys.UsSocket): Listener {
        let listenExt = CPointer<UIntNative>(s.rawGroup().ext())
        if (listenExt.isNull()) {
            throw missingListener()
        }
        let listener = ListenerHandleTable.lookup(listenExt.read())
        if (listener.isNone()) {
            throw missingListener()
        }
        return listener.getOrThrow()
    }

    public static func onOpen(s: bao_uws_sys.UsSocket, isClient: Int32, ip: String, ipLen: Int32): bao_uws_sys.UsSocket {
        let listener = lookupListener(s)
        let socket = listener.onCreate(s)
        onOpen(socket, SocketHandler.fromConnected(false, s))
        return s
    }
}

public class VTableFactory {
    private static func makeUnsupported(name: String): VTable {
        let table = VTable()
        table.onOpen = { s: bao_uws_sys.UsSocket, isClient: Int32, ip: String, ipLen: Int32 => throw Exception("ENOSYS: uWS " + name + " open dispatch is not wired") }
        table.onData = { s: bao_uws_sys.UsSocket, data: String, len: Int32 => throw Exception("ENOSYS: uWS " + name + " data dispatch is not wired") }
        table.onWritable = { s: bao_uws_sys.UsSocket => throw Exception("ENOSYS: uWS " + name + " writable dispatch is not wired") }
        table.onClose = { s: bao_uws_sys.UsSocket, code: Int32, reason: ?Any => throw Exception("ENOSYS: uWS " + name + " close dispatch is not wired") }
        table.onTimeout = { s: bao_uws_sys.UsSocket => throw Exception("ENOSYS: uWS " + name + " timeout dispatch is not wired") }
        table.onLongTimeout = { s: bao_uws_sys.UsSocket => throw Exception("ENOSYS: uWS " + name + " long-timeout dispatch is not wired") }
        table.onEnd = { s: bao_uws_sys.UsSocket => throw Exception("ENOSYS: uWS " + name + " end dispatch is not wired") }
        table.onConnectError = { s: bao_uws_sys.UsSocket, code: Int32 => throw Exception("ENOSYS: uWS " + name + " connect-error dispatch is not wired") }
        table.onConnectingError = { c: bao_uws_sys.ConnectingSocket, code: Int32 => throw Exception("ENOSYS: uWS " + name + " connecting-error dispatch is not wired") }
        table.onHandshake = { s: bao_uws_sys.UsSocket, ok: Int32, err: bao_uws_sys.UsBunVerifyError, ctx: ?Any => throw Exception("ENOSYS: uWS " + name + " handshake dispatch is not wired") }
        return table
    }

    public static func makeBunSocket(ssl: Bool): VTable {
        if (ssl) {
            return makeUnsupported("BunSocketTLS")
        }
        let table = VTable()
        table.onOpen = { s: bao_uws_sys.UsSocket, isClient: Int32, ip: String, ipLen: Int32 => BunSocketDispatch.onOpen(s, isClient, ip, ipLen) }
        table.onData = { s: bao_uws_sys.UsSocket, data: String, len: Int32 => BunSocketDispatch.onData(s, data, len) }
        table.onWritable = { s: bao_uws_sys.UsSocket => BunSocketDispatch.onWritable(s) }
        table.onClose = { s: bao_uws_sys.UsSocket, code: Int32, reason: ?Any => BunSocketDispatch.onClose(s, code, reason) }
        table.onConnectError = { s: bao_uws_sys.UsSocket, code: Int32 => BunSocketDispatch.onConnectError(s, code) }
        table.onConnectingError = { c: bao_uws_sys.ConnectingSocket, code: Int32 => BunSocketDispatch.onConnectingError(c, code) }
        return table
    }
    public static func makeBunListener(ssl: Bool): VTable {
        if (ssl) {
            return makeUnsupported("BunListenerTLS")
        }
        let table = VTable()
        table.onOpen = { s: bao_uws_sys.UsSocket, isClient: Int32, ip: String, ipLen: Int32 => BunListenerDispatch.onOpen(s, isClient, ip, ipLen) }
        table.onData = { s: bao_uws_sys.UsSocket, data: String, len: Int32 => BunSocketDispatch.onData(s, data, len) }
        table.onWritable = { s: bao_uws_sys.UsSocket => BunSocketDispatch.onWritable(s) }
        table.onClose = { s: bao_uws_sys.UsSocket, code: Int32, reason: ?Any => BunSocketDispatch.onClose(s, code, reason) }
        return table
    }
    public static func makeHTTPClient(ssl: Bool): VTable { makeUnsupported(if (ssl) { "HTTPClientTLS" } else { "HTTPClient" }) }
    public static func makeWSUpgrade(ssl: Bool): VTable { makeUnsupported(if (ssl) { "WSUpgradeTLS" } else { "WSUpgrade" }) }
    public static func makeWSClient(ssl: Bool): VTable { makeUnsupported(if (ssl) { "WSClientTLS" } else { "WSClient" }) }
    public static func makePostgres(ssl: Bool): VTable { makeUnsupported(if (ssl) { "PostgresTLS" } else { "Postgres" }) }
    public static func makeMySQL(ssl: Bool): VTable { makeUnsupported(if (ssl) { "MySQLTLS" } else { "MySQL" }) }
    public static func makeValkey(ssl: Bool): VTable { makeUnsupported(if (ssl) { "ValkeyTLS" } else { "Valkey" }) }
    public static func makeSpawnIPC(): VTable {
        let table = VTable()
        let h = SpawnIPCHandler()
        table.onData = { s: bao_uws_sys.UsSocket, data: String, len: Int32 =>
            h.onData(s, data.toArray()[0..Int64(len)])
            s
        }
        table.onFd = { s: bao_uws_sys.UsSocket, fd: Int32 =>
            h.onFd(s, fd)
            s
        }
        table.onWritable = { s: bao_uws_sys.UsSocket =>
            h.onWritable(s)
            s
        }
        table.onClose = { s: bao_uws_sys.UsSocket, code: Int32, reason: ?Any =>
            h.onClose(s, code, reason)
            s
        }
        table.onTimeout = { s: bao_uws_sys.UsSocket =>
            h.onTimeout(s)
            s
        }
        table.onEnd = { s: bao_uws_sys.UsSocket =>
            h.onEnd(s)
            s
        }
        return table
    }
}
