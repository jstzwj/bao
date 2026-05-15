// 严格翻译自: src/uws_sys/quic/Socket.zig
package bao_uws_sys.quic

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: quic/Socket.zig 中 extern fn
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
// 严格翻译自: quic/Socket.zig
//  us_quic_socket_t - one QUIC connection. Valid until its on_close
//  callback returns; lsquic frees the underlying lsquic_conn immediately
//  after, so callers must drop the pointer inside that callback.
// ============================================================================
public class QuicSocket {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub const makeStream = us_quic_socket_make_stream
    public func makeStream(): Unit {
        us_quic_socket_make_stream(ptr)
    }

    /// 对应 Bun: pub const streamsAvail = us_quic_socket_streams_avail
    public func streamsAvail(): UInt32 {
        return us_quic_socket_streams_avail(ptr)
    }

    /// 对应 Bun: pub fn status(this, buf) c_int
    public func status(buf: Array<UInt8>): Int32 {
        return us_quic_socket_status(ptr, CPointer<UInt8>.reinterpret(buf), UInt32(buf.size))
    }

    /// 对应 Bun: pub const close = us_quic_socket_close
    public func close(): Unit {
        us_quic_socket_close(ptr)
    }

    /// 对应 Bun: pub fn ext(s, comptime T: type) *?*T
    /// conn_ext_size bytes of caller storage co-allocated with the socket.
    public func ext(): CPointer<Unit> {
        return us_quic_socket_ext(ptr)
    }
}
