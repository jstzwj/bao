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
    | invalid
    | this
    | this
    | this
    | this
    | this
    | this
    | this
    | this
    | this
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
