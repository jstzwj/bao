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

    public func toInt(): Int32 {
        match (this) {
            case INVALID => 0
            case BUN_SOCKET_TCP => 1
            case BUN_SOCKET_TLS => 2
            case BUN_LISTENER_TCP => 3
            case BUN_LISTENER_TLS => 4
            case HTTP_CLIENT => 5
            case HTTP_CLIENT_TLS => 6
            case WS_CLIENT_UPGRADE => 7
            case WS_CLIENT_UPGRADE_TLS => 8
            case WS_CLIENT => 9
            case WS_CLIENT_TLS => 10
            case POSTGRES => 11
            case POSTGRES_TLS => 12
            case MYSQL => 13
            case MYSQL_TLS => 14
            case VALKEY => 15
            case VALKEY_TLS => 16
            case SPAWN_IPC => 17
            case DYNAMIC => 18
            case UWS_HTTP => 19
            case UWS_HTTP_TLS => 20
            case UWS_WS => 21
            case UWS_WS_TLS => 22
        }
    }

    public operator func ==(right: SocketKind): Bool {
        return this.toInt() == right.toInt()
    }

    public operator func !=(right: SocketKind): Bool {
        return !(this == right)
    }
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
    private var tables: ArrayList<Tuple2<SocketKind, VTable>>

    public init() {
        tables = ArrayList<Tuple2<SocketKind, VTable>>()

        // Bun.connect / Bun.listen
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.BUN_SOCKET_TCP, VTableFactory.makeBunSocket(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.BUN_SOCKET_TLS, VTableFactory.makeBunSocket(true)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.BUN_LISTENER_TCP, VTableFactory.makeBunListener(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.BUN_LISTENER_TLS, VTableFactory.makeBunListener(true)))

        // HTTP 客户端线程
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.HTTP_CLIENT, VTableFactory.makeHTTPClient(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.HTTP_CLIENT_TLS, VTableFactory.makeHTTPClient(true)))

        // WebSocket 客户端
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.WS_CLIENT_UPGRADE, VTableFactory.makeWSUpgrade(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.WS_CLIENT_UPGRADE_TLS, VTableFactory.makeWSUpgrade(true)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.WS_CLIENT, VTableFactory.makeWSClient(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.WS_CLIENT_TLS, VTableFactory.makeWSClient(true)))

        // SQL 驱动
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.POSTGRES, VTableFactory.makePostgres(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.POSTGRES_TLS, VTableFactory.makePostgres(true)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.MYSQL, VTableFactory.makeMySQL(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.MYSQL_TLS, VTableFactory.makeMySQL(true)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.VALKEY, VTableFactory.makeValkey(false)))
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.VALKEY_TLS, VTableFactory.makeValkey(true)))

        // IPC
        tables.append(Tuple2<SocketKind, VTable>(SocketKind.SPAWN_IPC, VTableFactory.makeSpawnIPC()))
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
func vt(s: UsSocket): VTable {
    let kind = s.kind()
    match (kind) {
        case INVALID => throw Exception("us_socket_t with kind=invalid")
        case DYNAMIC | UWS_HTTP | UWS_HTTP_TLS | UWS_WS | UWS_WS_TLS =>
            return s.rawGroup().vtable
        case _ =>
            let tables = DispatchTables()
            let vtableOpt = tables.get(kind)
            if (vtableOpt.isSome()) {
                return vtableOpt.getOrThrow()
            }
            return VTable()
    }
}

func vtc(c: ConnectingSocket): VTable {
    let kind = c.kind()
    match (kind) {
        case INVALID => throw Exception("us_connecting_socket_t with kind=invalid")
        case DYNAMIC | UWS_HTTP | UWS_HTTP_TLS | UWS_WS | UWS_WS_TLS =>
            return c.rawGroup().vtable
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

/// 连接打开分发
/// 对应 Zig: export fn us_dispatch_open
public func usDispatchOpen(s: UsSocket, isClient: Int32, ip: String, ipLen: Int32): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onOpen.isSome()) {
        return vtable.onOpen.getOrThrow()(s, isClient, ip, ipLen)
    }
    return s
}

public func usDispatchData(s: UsSocket, data: String, len: Int32): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onData.isSome()) {
        return vtable.onData.getOrThrow()(s, data, len)
    }
    return s
}

public func usDispatchFd(s: UsSocket, fd: Int32): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onFd.isSome()) {
        return vtable.onFd.getOrThrow()(s, fd)
    }
    return s
}

public func usDispatchWritable(s: UsSocket): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onWritable.isSome()) {
        return vtable.onWritable.getOrThrow()(s)
    }
    return s
}

public func usDispatchClose(s: UsSocket, code: Int32, reason: ?Any): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onClose.isSome()) {
        return vtable.onClose.getOrThrow()(s, code, reason)
    }
    return s
}

public func usDispatchTimeout(s: UsSocket): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onTimeout.isSome()) {
        return vtable.onTimeout.getOrThrow()(s)
    }
    return s
}

public func usDispatchLongTimeout(s: UsSocket): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onLongTimeout.isSome()) {
        return vtable.onLongTimeout.getOrThrow()(s)
    }
    return s
}

public func usDispatchEnd(s: UsSocket): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onEnd.isSome()) {
        return vtable.onEnd.getOrThrow()(s)
    }
    return s
}

/// 连接错误分发
public func usDispatchConnectError(s: UsSocket, code: Int32): ?UsSocket {
    let vtable = vt(s)
    if (vtable.onConnectError.isSome()) {
        return vtable.onConnectError.getOrThrow()(s, code)
    }
    return s
}

/// 连接中错误分发
public func usDispatchConnectingError(c: ConnectingSocket, code: Int32): ?ConnectingSocket {
    let vtable = vtc(c)
    if (vtable.onConnectingError.isSome()) {
        return vtable.onConnectingError.getOrThrow()(c, code)
    }
    return c
}

/// 握手分发
public func usDispatchHandshake(s: UsSocket, ok: Int32, err: UsBunVerifyError): Unit {
    let vtable = vt(s)
    if (vtable.onHandshake.isSome()) {
        vtable.onHandshake.getOrThrow()(s, ok, err, None)
    }
}

/// SSL 原始数据分接 — stub
public func usDispatchSslRawTap(s: UsSocket, data: String, len: Int32): ?UsSocket {
    // Stub: SSL raw tap not yet implemented
    return s
}

// ============================================================================
// 不透明类型
// ============================================================================

/// us_socket_t 的不透明类型
public class UsSocket {
    public func kind(): SocketKind { SocketKind.BUN_SOCKET_TCP }
    public func rawGroup(): SocketGroup { SocketGroup() }
    public func ext<T>(): ?T { None }
}

/// ConnectingSocket 的不透明类型
public class ConnectingSocket {
    public func kind(): SocketKind { SocketKind.BUN_SOCKET_TCP }
    public func rawGroup(): SocketGroup { SocketGroup() }
    public func ext<T>(): ?T { None }
}

/// SocketGroup 的不透明类型
public class SocketGroup {
    public var vtable: VTable

    public init() {
        vtable = VTable()
    }

    public func owner<T>(): T { throw Exception("not implemented") }
}

/// VTable 工厂
/// 对应 Zig 中各 handler 适配器
public class VTableFactory {
    public static func makeBunSocket(ssl: Bool): VTable { VTable() }
    public static func makeBunListener(ssl: Bool): VTable { VTable() }
    public static func makeHTTPClient(ssl: Bool): VTable { VTable() }
    public static func makeWSUpgrade(ssl: Bool): VTable { VTable() }
    public static func makeWSClient(ssl: Bool): VTable { VTable() }
    public static func makePostgres(ssl: Bool): VTable { VTable() }
    public static func makeMySQL(ssl: Bool): VTable { VTable() }
    public static func makeValkey(ssl: Bool): VTable { VTable() }
    public static func makeSpawnIPC(): VTable { VTable() }
}
