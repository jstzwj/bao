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

    /// Equality comparison
    public operator func ==(right: SocketKind): Bool {
        this.toUInt8() == right.toUInt8()
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
        if (value == 1) {
            return SocketKind.dynamic
        } else if (value == 2) {
            return SocketKind.bun_socket_tcp
        } else if (value == 3) {
            return SocketKind.bun_socket_tls
        } else if (value == 4) {
            return SocketKind.bun_listener_tcp
        } else if (value == 5) {
            return SocketKind.bun_listener_tls
        } else if (value == 6) {
            return SocketKind.http_client
        } else if (value == 7) {
            return SocketKind.http_client_tls
        } else if (value == 8) {
            return SocketKind.ws_client_upgrade
        } else if (value == 9) {
            return SocketKind.ws_client_upgrade_tls
        } else if (value == 10) {
            return SocketKind.ws_client
        } else if (value == 11) {
            return SocketKind.ws_client_tls
        } else if (value == 12) {
            return SocketKind.postgres
        } else if (value == 13) {
            return SocketKind.postgres_tls
        } else if (value == 14) {
            return SocketKind.mysql
        } else if (value == 15) {
            return SocketKind.mysql_tls
        } else if (value == 16) {
            return SocketKind.valkey
        } else if (value == 17) {
            return SocketKind.valkey_tls
        } else if (value == 18) {
            return SocketKind.spawn_ipc
        } else if (value == 19) {
            return SocketKind.uws_http
        } else if (value == 20) {
            return SocketKind.uws_http_tls
        } else if (value == 21) {
            return SocketKind.uws_ws
        } else if (value == 22) {
            return SocketKind.uws_ws_tls
        }
        return SocketKind.invalid
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
