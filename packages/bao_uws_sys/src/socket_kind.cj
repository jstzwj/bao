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

    /// Numeric kind value stamped into native us_socket_t/us_socket_group APIs.
    public func toUInt8(): UInt8 {
        match (this) {
            case invalid => UInt8(0)
            case dynamic => UInt8(1)
            case bun_socket_tcp => UInt8(2)
            case bun_socket_tls => UInt8(3)
            case bun_listener_tcp => UInt8(4)
            case bun_listener_tls => UInt8(5)
            case http_client => UInt8(6)
            case http_client_tls => UInt8(7)
            case ws_client_upgrade => UInt8(8)
            case ws_client_upgrade_tls => UInt8(9)
            case ws_client => UInt8(10)
            case ws_client_tls => UInt8(11)
            case postgres => UInt8(12)
            case postgres_tls => UInt8(13)
            case mysql => UInt8(14)
            case mysql_tls => UInt8(15)
            case valkey => UInt8(16)
            case valkey_tls => UInt8(17)
            case spawn_ipc => UInt8(18)
            case uws_http => UInt8(19)
            case uws_http_tls => UInt8(20)
            case uws_ws => UInt8(21)
            case uws_ws_tls => UInt8(22)
        }
    }

    public static func fromUInt8(value: UInt8): SocketKind {
        match (value) {
            case UInt8(1) => SocketKind.dynamic
            case UInt8(2) => SocketKind.bun_socket_tcp
            case UInt8(3) => SocketKind.bun_socket_tls
            case UInt8(4) => SocketKind.bun_listener_tcp
            case UInt8(5) => SocketKind.bun_listener_tls
            case UInt8(6) => SocketKind.http_client
            case UInt8(7) => SocketKind.http_client_tls
            case UInt8(8) => SocketKind.ws_client_upgrade
            case UInt8(9) => SocketKind.ws_client_upgrade_tls
            case UInt8(10) => SocketKind.ws_client
            case UInt8(11) => SocketKind.ws_client_tls
            case UInt8(12) => SocketKind.postgres
            case UInt8(13) => SocketKind.postgres_tls
            case UInt8(14) => SocketKind.mysql
            case UInt8(15) => SocketKind.mysql_tls
            case UInt8(16) => SocketKind.valkey
            case UInt8(17) => SocketKind.valkey_tls
            case UInt8(18) => SocketKind.spawn_ipc
            case UInt8(19) => SocketKind.uws_http
            case UInt8(20) => SocketKind.uws_http_tls
            case UInt8(21) => SocketKind.uws_ws
            case UInt8(22) => SocketKind.uws_ws_tls
            case _ => SocketKind.invalid
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
