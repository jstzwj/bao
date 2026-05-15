// 严格翻译自: src/uws_sys/quic/Stream.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: quic/Stream.zig 中 extern fn
// ============================================================================
@C
foreign func us_quic_stream_socket(s: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_quic_stream_shutdown(s: CPointer<Unit>): Unit
@C
foreign func us_quic_stream_close(s: CPointer<Unit>): Unit
@C
foreign func us_quic_stream_reset(s: CPointer<Unit>): Unit
@C
foreign func us_quic_stream_header_count(s: CPointer<Unit>): UInt32
@C
foreign func us_quic_stream_header(s: CPointer<Unit>, i: UInt32): CPointer<Unit>
@C
foreign func us_quic_stream_ext(s: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_quic_stream_write(s: CPointer<Unit>, data: CPointer<UInt8>, len: UInt32): Int32
@C
foreign func us_quic_stream_want_write(s: CPointer<Unit>, want: Int32): Unit
@C
foreign func us_quic_stream_send_headers(s: CPointer<Unit>, h: CPointer<Unit>, n: UInt32, end_stream: Int32): Int32

// ============================================================================
// QuicStream - QUIC 流
// 严格翻译自: quic/Stream.zig
//  us_quic_stream_t - one bidirectional HTTP/3 request stream. Valid
//  until its on_stream_close callback returns.
// ============================================================================
public class QuicStream {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub const socket = us_quic_stream_socket
    public func socket(): QuicSocket {
        return QuicSocket(us_quic_stream_socket(ptr))
    }

    /// 对应 Bun: pub const shutdown = us_quic_stream_shutdown
    public func shutdown(): Unit {
        us_quic_stream_shutdown(ptr)
    }

    /// 对应 Bun: pub const close = us_quic_stream_close
    public func close(): Unit {
        us_quic_stream_close(ptr)
    }

    /// 对应 Bun: pub const reset = us_quic_stream_reset
    public func reset(): Unit {
        us_quic_stream_reset(ptr)
    }

    /// 对应 Bun: pub const headerCount = us_quic_stream_header_count
    public func headerCount(): UInt32 {
        return us_quic_stream_header_count(ptr)
    }

    /// 对应 Bun: pub const header = us_quic_stream_header
    public func header(i: UInt32): CPointer<Unit> {
        return us_quic_stream_header(ptr, i)
    }

    /// 对应 Bun: pub fn ext(s, comptime T: type) *?*T
    public func ext(): CPointer<Unit> {
        return us_quic_stream_ext(ptr)
    }

    /// 对应 Bun: pub fn write(s, data) c_int
    public func write(data: Array<UInt8>): Int32 {
        return us_quic_stream_write(ptr, CPointer<UInt8>.reinterpret(data), UInt32(data.size))
    }

    /// 对应 Bun: pub fn wantWrite(s, want) void
    public func wantWrite(want: Bool): Unit {
        us_quic_stream_want_write(ptr, if (want) 1 else 0)
    }

    /// 对应 Bun: pub fn sendHeaders(s, headers, end_stream) c_int
    public func sendHeaders(headers: CPointer<Unit>, n: UInt32, endStream: Bool): Int32 {
        return us_quic_stream_send_headers(ptr, headers, n, if (endStream) 1 else 0)
    }
}
