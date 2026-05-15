// 严格翻译自: src/uws_sys/quic.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: quic.zig 中 extern fn
// ============================================================================
@C
foreign func us_quic_global_init(): Unit

// ============================================================================
// quic - QUIC 传输绑定
// 严格翻译自: quic.zig
//  Zig bindings for the lsquic-backed QUIC transport in
//  packages/bun-usockets/src/quic.{c,h}. One opaque per C handle; the
//  HTTP/3 server uses these via the C++ uWS layer (uws.H3), the HTTP/3
//  fetch client uses them directly.
// ============================================================================
public class QuicGlobal {
    /// 对应 Bun: pub extern fn us_quic_global_init() callconv(.c) void
    /// pub const globalInit = us_quic_global_init
    public static func globalInit(): Unit {
        us_quic_global_init()
    }
}
