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
public enum SocketKind {
    | invalid         // 0
    | dynamic
    | bun_socket_tcp
    | bun_socket_tls
    | bun_listener_tcp
    | bun_listener_tls
    | http_client
    | http_client_tls
    | ws_client_upgrade
    | ws_client_upgrade_tls
    | ws_client
    | ws_client_tls
    | postgres
    | postgres_tls
    | mysql
    | mysql_tls
    | valkey
    | valkey_tls
    | spawn_ipc
    | uws_http
    | uws_http_tls
    | uws_ws
    | uws_ws_tls

    /// 是否为 TLS 类型
    public func isTLS(): Bool {
        match (this) {
            case bun_socket_tls |
                 bun_listener_tls |
                 http_client_tls |
                 ws_client_upgrade_tls |
                 ws_client_tls |
                 postgres_tls |
                 mysql_tls |
                 valkey_tls |
                 uws_http_tls |
                 uws_ws_tls => true
            case _ => false
        }
    }
}

// ============================================================================
// 导出序号常量
// 严格翻译自: SocketKind.zig exported_ordinals
//  The four kinds whose handlers live in C++ are also referenced from C++.
//  Export their ordinals so the C++ side links against the Zig source of truth.
// ============================================================================
public class SocketKindOrdinals {
    public static let BUN_SOCKET_KIND_DYNAMIC: UInt8 = UInt8(1)
    public static let BUN_SOCKET_KIND_UWS_HTTP: UInt8 = UInt8(19)
    public static let BUN_SOCKET_KIND_UWS_HTTP_TLS: UInt8 = UInt8(20)
    public static let BUN_SOCKET_KIND_UWS_WS: UInt8 = UInt8(21)
    public static let BUN_SOCKET_KIND_UWS_WS_TLS: UInt8 = UInt8(22)
}
