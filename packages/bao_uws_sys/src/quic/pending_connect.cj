// 严格翻译自: src/uws_sys/quic/PendingConnect.zig
package bao_uws_sys.quic

import bao_sys.*

// ============================================================================
// C FFI 声明
// ============================================================================
@C
foreign func us_quic_pending_connect_addrinfo(pc: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_quic_pending_connect_resolved(pc: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_quic_pending_connect_cancel(pc: CPointer<Unit>): Unit

// ============================================================================
// QuicPendingConnect - DNS 待处理的 QUIC 客户端连接
// ============================================================================
public class QuicPendingConnect {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    public func addrinfo(): CPointer<Unit> {
        return unsafe { us_quic_pending_connect_addrinfo(ptr) }
    }

    public func resolved(): CPointer<Unit> {
        return unsafe { us_quic_pending_connect_resolved(ptr) }
    }

    public func cancel(): Unit {
        unsafe { us_quic_pending_connect_cancel(ptr) }
    }
}
