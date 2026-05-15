// 严格翻译自: src/uws_sys/SocketKind.zig
package bao_uws_sys

// ============================================================================
// SocketKind - 套接字类型枚举
// 严格翻译自: SocketKind.zig
//  Closed-world enum of every us_socket_t consumer in Bun. Stamped on the
//  socket at creation (s->kind) and switched on in dispatch.zig so the
//  event loop calls straight into the right Zig/C++ handler with the ext
//  already typed - no per-context vtable, no runtime SSL flag.
// ============================================================================

/// 套接字类型枚举
/// 对应 Bun: SocketKind = enum(u8)
public enum SocketKind <: UInt8 {
    /// Reserved. loop.c callocs sockets, so 0 must be a value that crashes
    /// loudly if dispatch ever sees it instead of silently routing somewhere.
    invalid = 0,
    /// Dispatch reads group->vtable->on_*. For sockets whose handler set is
    /// only known at runtime (uWS C++ via per-App vtable, tests).
    dynamic,

    // -- Bun.connect / Bun.listen (src/runtime/api/bun/socket.zig) --
    bun_socket_tcp,
    bun_socket_tls,
    /// Server-accepted socket; ext is the *Listener so onCreate can attach
    /// a fresh NewSocket before re-stamping to bun_socket_{tcp,tls}.
    bun_listener_tcp,
    bun_listener_tls,

    // -- HTTP client thread (src/http/HTTPContext.zig) --
    http_client,
    http_client_tls,

    // -- new WebSocket(...) client (src/http/websocket_client*) --
    ws_client_upgrade,
    ws_client_upgrade_tls,
    ws_client,
    ws_client_tls,

    // -- Database drivers --
    postgres,
    postgres_tls,
    mysql,
    mysql_tls,
    valkey,
    valkey_tls,

    // -- Bun.spawn IPC over socketpair --
    spawn_ipc,

    // -- Bun.serve / uWS - handlers live in C++; dispatch calls a thunk and
    //    the thunk reads group->ext as the templated HttpContext<SSL>*.
    uws_http,
    uws_http_tls,
    uws_ws,
    uws_ws_tls;

    /// 对应 Bun: pub inline fn isTLS(self: SocketKind) bool
    public func isTLS(): Bool {
        return this == SocketKind.bun_socket_tls ||
            this == SocketKind.bun_listener_tls ||
            this == SocketKind.http_client_tls ||
            this == SocketKind.ws_client_upgrade_tls ||
            this == SocketKind.ws_client_tls ||
            this == SocketKind.postgres_tls ||
            this == SocketKind.mysql_tls ||
            this == SocketKind.valkey_tls ||
            this == SocketKind.uws_http_tls ||
            this == SocketKind.uws_ws_tls
    }
}

// ============================================================================
// 导出序号常量
// 严格翻译自: SocketKind.zig exported_ordinals
//  The four kinds whose handlers live in C++ are also referenced from C++.
//  Export their ordinals so the C++ side links against the Zig source of truth.
// ============================================================================
public class SocketKindOrdinals {
    public static let BUN_SOCKET_KIND_DYNAMIC: UInt8 = UInt8(SocketKind.dynamic)
    public static let BUN_SOCKET_KIND_UWS_HTTP: UInt8 = UInt8(SocketKind.uws_http)
    public static let BUN_SOCKET_KIND_UWS_HTTP_TLS: UInt8 = UInt8(SocketKind.uws_http_tls)
    public static let BUN_SOCKET_KIND_UWS_WS: UInt8 = UInt8(SocketKind.uws_ws)
    public static let BUN_SOCKET_KIND_UWS_WS_TLS: UInt8 = UInt8(SocketKind.uws_ws_tls)
}
