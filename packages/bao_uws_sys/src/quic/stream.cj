// 严格翻译自: src/uws_sys/quic/Stream.zig
package bao_uws_sys.quic

import bao_sys.*

// ============================================================================
// C FFI 声明
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
// ============================================================================
public class QuicStream {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    public func socket(): QuicSocket {
        return QuicSocket(unsafe { us_quic_stream_socket(ptr) })
    }

    public func shutdown(): Unit {
        unsafe { us_quic_stream_shutdown(ptr) }
    }

    public func close(): Unit {
        unsafe { us_quic_stream_close(ptr) }
    }

    public func reset(): Unit {
        unsafe { us_quic_stream_reset(ptr) }
    }

    public func headerCount(): UInt32 {
        return unsafe { us_quic_stream_header_count(ptr) }
    }

    public func header(i: UInt32): CPointer<Unit> {
        return unsafe { us_quic_stream_header(ptr, i) }
    }

    public func ext(): CPointer<Unit> {
        return unsafe { us_quic_stream_ext(ptr) }
    }

    public func write(data: Array<UInt8>): Int32 {
        return unsafe { us_quic_stream_write(ptr, CPointer<UInt8>(), UInt32(data.size)) }
    }

    public func wantWrite(want: Bool): Unit {
        let wantVal: Int32 = if (want) { 1 } else { 0 }
        unsafe { us_quic_stream_want_write(ptr, wantVal) }
    }

    public func sendHeaders(headers: CPointer<Unit>, n: UInt32, endStream: Bool): Int32 {
        let endVal: Int32 = if (endStream) { 1 } else { 0 }
        return unsafe { us_quic_stream_send_headers(ptr, headers, n, endVal) }
    }
}
