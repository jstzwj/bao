// 严格翻译自: src/runtime/socket/uws_dispatch.zig
// Socket 事件分发 — 事件循环调用的核心分发函数
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// Socket 事件分发
// 对应 Bun: uws_dispatch.zig
// loop.c 为每个可读/可写/关闭等事件调用这些 us_dispatch_* 导出
// 根据 s.kind 切换并直接调用正确的处理器
// ============================================================================

/// Socket 种类
/// 对应 Zig: SocketKind enum
public enum SocketKind {
    | INVALID                          // 无效
    | BUN_SOCKET_TCP                   // Bun.connect/listen TCP
    | BUN_SOCKET_TLS                   // Bun.connect/listen TLS
    | BUN_LISTENER_TCP                 // TCP 监听器
    | BUN_LISTENER_TLS                 // TLS 监听器
    | HTTP_CLIENT                      // HTTP 客户端线程
    | HTTP_CLIENT_TLS                  // HTTPS 客户端线程
    | WS_CLIENT_UPGRADE               // WebSocket 客户端升级
    | WS_CLIENT_UPGRADE_TLS           // WebSocket 客户端升级 TLS
    | WS_CLIENT                        // WebSocket 客户端
    | WS_CLIENT_TLS                    // WebSocket 客户端 TLS
    | POSTGRES                         // PostgreSQL 连接
    | POSTGRES_TLS                     // PostgreSQL TLS 连接
    | MYSQL                            // MySQL 连接
    | MYSQL_TLS                        // MySQL TLS 连接
    | VALKEY                           // Valkey 连接
    | VALKEY_TLS                       // Valkey TLS 连接
    | SPAWN_IPC                        // Bun.spawn IPC
    | DYNAMIC                          // 动态 (C++ kinds)
    | UWS_HTTP                         // uWS HTTP
    | UWS_HTTP_TLS                     // uWS HTTP TLS
    | UWS_WS                           // uWS WebSocket
    | UWS_WS_TLS                       // uWS WebSocket TLS
}

/// 虚函数表
/// 对应 Zig: VTable struct
public class VTable {
    public var onOpen: ?(UsSocket, Int32, String, Int32) -> UsSocket
    public var onData: ?(UsSocket, String, Int32) -> UsSocket
    public var onFd: ?(UsSocket, Int32) -> UsSocket
    public var onWritable: ?(UsSocket) -> UsSocket
    public var onClose: ?(UsSocket, Int32, ?Any) -> UsSocket
    public var onTimeout: ?(UsSocket) -> UsSocket
    public var onLongTimeout: ?(UsSocket) -> UsSocket
    public var onEnd: ?(UsSocket) -> UsSocket
    public var onConnectError: ?(UsSocket, Int32) -> UsSocket
    public var onConnectingError: ?(ConnectingSocket, Int32) -> ConnectingSocket
    public var onHandshake: ?(UsSocket, Int32, UsBunVerifyError, ?Any) -> Unit

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
    private var tables: HashMap<SocketKind, VTable>

    public init() {
        tables = HashMap<SocketKind, VTable>()

        // Bun.connect / Bun.listen
        tables.put(SocketKind.BUN_SOCKET_TCP, VTableFactory.makeBunSocket(false))
        tables.put(SocketKind.BUN_SOCKET_TLS, VTableFactory.makeBunSocket(true))
        tables.put(SocketKind.BUN_LISTENER_TCP, VTableFactory.makeBunListener(false))
        tables.put(SocketKind.BUN_LISTENER_TLS, VTableFactory.makeBunListener(true))

        // HTTP 客户端线程
        tables.put(SocketKind.HTTP_CLIENT, VTableFactory.makeHTTPClient(false))
        tables.put(SocketKind.HTTP_CLIENT_TLS, VTableFactory.makeHTTPClient(true))

        // WebSocket 客户端
        tables.put(SocketKind.WS_CLIENT_UPGRADE, VTableFactory.makeWSUpgrade(false))
        tables.put(SocketKind.WS_CLIENT_UPGRADE_TLS, VTableFactory.makeWSUpgrade(true))
        tables.put(SocketKind.WS_CLIENT, VTableFactory.makeWSClient(false))
        tables.put(SocketKind.WS_CLIENT_TLS, VTableFactory.makeWSClient(true))

        // SQL 驱动
        tables.put(SocketKind.POSTGRES, VTableFactory.makePostgres(false))
        tables.put(SocketKind.POSTGRES_TLS, VTableFactory.makePostgres(true))
        tables.put(SocketKind.MYSQL, VTableFactory.makeMySQL(false))
        tables.put(SocketKind.MYSQL_TLS, VTableFactory.makeMySQL(true))
        tables.put(SocketKind.VALKEY, VTableFactory.makeValkey(false))
        tables.put(SocketKind.VALKEY_TLS, VTableFactory.makeValkey(true))

        // IPC
        tables.put(SocketKind.SPAWN_IPC, VTableFactory.makeSpawnIPC())
    }

    /// 获取指定 kind 的 vtable
    public func get(kind: SocketKind): ?VTable {
        return tables.get(kind)
    }
}

/// 获取 socket 的 vtable
/// 对应 Zig: inline fn vt(s: *us_socket_t) *const VTable
func vt(s: UsSocket): VTable {
    let kind = s.kind()
    match (kind) {
        case INVALID => panic("us_socket_t with kind=invalid")
        // Per-group vtable: uWS C++ 为每个服务器安装不同的 HttpContext<SSL>* 闭包
        case DYNAMIC | UWS_HTTP | UWS_HTTP_TLS | UWS_WS | UWS_WS_TLS =>
            return s.rawGroup().vtable
        case _ =>
            let tables = DispatchTables()
            return tables.get(kind).expect("missing vtable for kind")
    }
}

/// 获取连接中 socket 的 vtable
/// 对应 Zig: inline fn vtc(c: *ConnectingSocket) *const VTable
func vtc(c: ConnectingSocket): VTable {
    let kind = c.kind()
    match (kind) {
        case INVALID => panic("us_connecting_socket_t with kind=invalid")
        case DYNAMIC | UWS_HTTP | UWS_HTTP_TLS | UWS_WS | UWS_WS_TLS =>
            return c.rawGroup().vtable
        case _ =>
            let tables = DispatchTables()
            return tables.get(kind).expect("missing vtable for kind")
    }
}

// ============================================================================
// 分发函数
// 对应 Zig: export fn us_dispatch_*
// 这些函数由事件循环调用
// ============================================================================

/// 连接打开分发
/// 对应 Zig: export fn us_dispatch_open
public func usDispatchOpen(s: UsSocket, isClient: Int32, ip: String, ipLen: Int32): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onOpen != None) {
        return vtable.onOpen(s, isClient, ip, ipLen)
    }
    return s
}

/// 数据到达分发
/// 对应 Zig: export fn us_dispatch_data
public func usDispatchData(s: UsSocket, data: String, len: Int32): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onData != None) {
        return vtable.onData(s, data, len)
    }
    return s
}

/// 文件描述符分发
/// 对应 Zig: export fn us_dispatch_fd
public func usDispatchFd(s: UsSocket, fd: Int32): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onFd != None) {
        return vtable.onFd(s, fd)
    }
    return s
}

/// 可写分发
/// 对应 Zig: export fn us_dispatch_writable
public func usDispatchWritable(s: UsSocket): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onWritable != None) {
        return vtable.onWritable(s)
    }
    return s
}

/// 关闭分发
/// 对应 Zig: export fn us_dispatch_close
public func usDispatchClose(s: UsSocket, code: Int32, reason: ?Any): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onClose != None) {
        return vtable.onClose(s, code, reason)
    }
    return s
}

/// 超时分发
/// 对应 Zig: export fn us_dispatch_timeout
public func usDispatchTimeout(s: UsSocket): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onTimeout != None) {
        return vtable.onTimeout(s)
    }
    return s
}

/// 长超时分发
/// 对应 Zig: export fn us_dispatch_long_timeout
public func usDispatchLongTimeout(s: UsSocket): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onLongTimeout != None) {
        return vtable.onLongTimeout(s)
    }
    return s
}

/// 结束分发
/// 对应 Zig: export fn us_dispatch_end
public func usDispatchEnd(s: UsSocket): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onEnd != None) {
        return vtable.onEnd(s)
    }
    return s
}

/// 连接错误分发
/// 对应 Zig: export fn us_dispatch_connect_error
public func usDispatchConnectError(s: UsSocket, code: Int32): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onConnectError != None) {
        return vtable.onConnectError(s, code)
    }
    return s
}

/// 连接中错误分发
/// 对应 Zig: export fn us_dispatch_connecting_error
public func usDispatchConnectingError(c: ConnectingSocket, code: Int32): ?ConnectingSocket {
    let vtable = vtc(c)
    if (vtable.onConnectingError != None) {
        return vtable.onConnectingError(c, code)
    }
    return c
}

/// 握手分发
/// 对应 Zig: export fn us_dispatch_handshake
public func usDispatchHandshake(s: UsSocket, ok: Int32, err: UsBunVerifyError): Unit {
    let vtable = vt(s)
    if (vtable.onHandshake != None) {
        vtable.onHandshake(s, ok, err, None)
    }
}

/// SSL 原始数据分接 — 用于 socket.upgradeTLS()
/// 在返回对的 [raw, _] 半部分上在解密前触发
/// 对应 Zig: export fn us_dispatch_ssl_raw_tap
public func usDispatchSslRawTap(s: UsSocket, data: String, len: Int32): ?UsSocket {
    // 仅 bun_socket_tls 设置 ssl_raw_tap 位
    assert(s.kind() == SocketKind.BUN_SOCKET_TLS)
    let tls = s.ext<TLSSocket>()
    if (tls != None && tls.twin != None) {
        let raw = tls.twin
        raw.onData(TLSSocket.Socket.from(s), data[0:len])
    }
    return s
}

// ============================================================================
// 不透明类型
// ============================================================================

/// us_socket_t 的不透明类型
public class UsSocket {
    public func kind(): SocketKind { ... }
    public func rawGroup(): SocketGroup { ... }
    public func ext<T>(): ?T { ... }
}

/// ConnectingSocket 的不透明类型
public class ConnectingSocket {
    public func kind(): SocketKind { ... }
    public func rawGroup(): SocketGroup { ... }
    public func ext<T>(): ?T { ... }
}

/// SocketGroup 的不透明类型
public class SocketGroup {
    public var vtable: VTable
    public func owner<T>(): T { ... }
}

/// VTable 工厂
/// 对应 Zig 中各 handler 适配器
public class VTableFactory {
    public static func makeBunSocket(ssl: Bool): VTable { ... }
    public static func makeBunListener(ssl: Bool): VTable { ... }
    public static func makeHTTPClient(ssl: Bool): VTable { ... }
    public static func makeWSUpgrade(ssl: Bool): VTable { ... }
    public static func makeWSClient(ssl: Bool): VTable { ... }
    public static func makePostgres(ssl: Bool): VTable { ... }
    public static func makeMySQL(ssl: Bool): VTable { ... }
    public static func makeValkey(ssl: Bool): VTable { ... }
    public static func makeSpawnIPC(): VTable { ... }
}
