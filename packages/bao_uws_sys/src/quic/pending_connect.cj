// 严格翻译自: src/uws_sys/quic/PendingConnect.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: quic/PendingConnect.zig 中 extern fn
// ============================================================================
@C
foreign func us_quic_pending_connect_addrinfo(pc: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_quic_pending_connect_resolved(pc: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_quic_pending_connect_cancel(pc: CPointer<Unit>): Unit

// ============================================================================
// QuicPendingConnect - DNS 待处理的 QUIC 客户端连接
// 严格翻译自: quic/PendingConnect.zig
//  us_quic_pending_connect_s - DNS-pending client connect. Created when
//  Context.connect returns 0 (cache miss); holds the Bun__addrinfo
//  request that the caller registers a callback on.
//  Consumed by exactly one of resolved() or cancel().
// ============================================================================
public class QuicPendingConnect {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub const addrinfo = us_quic_pending_connect_addrinfo
    public func addrinfo(): CPointer<Unit> {
        return us_quic_pending_connect_addrinfo(ptr)
    }

    /// 对应 Bun: pub const resolved = us_quic_pending_connect_resolved
    public func resolved(): CPointer<Unit> {
        return us_quic_pending_connect_resolved(ptr)
    }

    /// 对应 Bun: pub const cancel = us_quic_pending_connect_cancel
    public func cancel(): Unit {
        us_quic_pending_connect_cancel(ptr)
    }
}
