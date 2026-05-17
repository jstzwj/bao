// 严格翻译自: src/uws_sys/quic/Socket.zig
package bao_uws_sys.quic

import bao_sys.*

// ============================================================================
// C FFI 声明
// ============================================================================
@C
foreign func us_quic_socket_make_stream(s: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_streams_avail(s: CPointer<Unit>): UInt32
@C
foreign func us_quic_socket_status(s: CPointer<Unit>, buf: CPointer<UInt8>, len: UInt32): Int32
@C
foreign func us_quic_socket_close(s: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_ext(s: CPointer<Unit>): CPointer<Unit>

// ============================================================================
// QuicSocket - QUIC 连接
// ============================================================================
public class QuicSocket {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    public func makeStream(): Unit {
        unsafe { us_quic_socket_make_stream(ptr) }
    }

    public func streamsAvail(): UInt32 {
        return unsafe { us_quic_socket_streams_avail(ptr) }
    }

    public func status(buf: Array<UInt8>): Int32 {
        return unsafe { us_quic_socket_status(ptr, CPointer<UInt8>(), UInt32(buf.size)) }
    }

    public func close(): Unit {
        unsafe { us_quic_socket_close(ptr) }
    }

    public func ext(): CPointer<Unit> {
        return unsafe { us_quic_socket_ext(ptr) }
    }
}
