// 严格翻译自: src/uws_sys/quic/Context.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: quic/Context.zig 中 extern fn
// ============================================================================
@C
foreign func us_create_quic_client_context(loop: CPointer<Unit>, ext_size: UInt32, conn_ext: UInt32, stream_ext: UInt32): CPointer<Unit>
@C
foreign func us_quic_socket_context_loop(ctx: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_quic_socket_context_connect(ctx: CPointer<Unit>, host: CPointer<Int8>, port: Int32, sni: CPointer<Int8>, reject_unauthorized: Int32, out_qs: CPointer<CPointer<Unit>>, out_pending: CPointer<CPointer<Unit>>, user: CPointer<Unit>): Int32
@C
foreign func us_quic_socket_context_on_hsk_done(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_context_on_goaway(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_context_on_close(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_context_on_stream_open(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_context_on_stream_headers(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_context_on_stream_data(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_context_on_stream_writable(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func us_quic_socket_context_on_stream_close(ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit

// ============================================================================
// QuicContext - QUIC 套接字上下文
// 严格翻译自: quic/Context.zig
//  us_quic_socket_context_t - one lsquic engine + its event-loop wiring.
//  For the client there is exactly one of these per HTTP-thread loop and it
//  lives for the process; the server creates one per Bun.serve({http3:true}).
// ============================================================================
public class QuicContext {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub const createClient = us_create_quic_client_context
    public static func createClient(loop: CPointer<Unit>, extSize: UInt32, connExt: UInt32, streamExt: UInt32): ?QuicContext {
        let raw = us_create_quic_client_context(loop, extSize, connExt, streamExt)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(QuicContext(raw))
    }

    /// 对应 Bun: pub const loop = us_quic_socket_context_loop
    public func loop_(): CPointer<Unit> {
        return us_quic_socket_context_loop(ptr)
    }

    /// 对应 Bun: pub const ConnectResult = union(enum) { socket, pending, err }
    /// 对应 Bun: pub fn connect(ctx, host, port, sni, reject_unauthorized, user) ConnectResult
    public func connect(host: CPointer<Int8>, port: UInt16, sni: CPointer<Int8>, rejectUnauthorized: Bool, user: CPointer<Unit>): QuicConnectResult {
        // In real impl would use out-params for qs and pending
        let result = us_quic_socket_context_connect(ptr, host, Int32(port), sni, if (rejectUnauthorized) 1 else 0,
            CPointer<CPointer<Unit>>.null, CPointer<CPointer<Unit>>.null, user)
        if (result == 1) {
            return QuicConnectResultSocket()
        } else if (result == 0) {
            return QuicConnectResultPending()
        }
        return QuicConnectResultErr()
    }

    /// 对应 Bun: pub const onHskDone = us_quic_socket_context_on_hsk_done
    public func onHskDone(cb: CPointer<Unit>): Unit {
        us_quic_socket_context_on_hsk_done(ptr, cb)
    }

    /// 对应 Bun: pub const onGoaway = us_quic_socket_context_on_goaway
    public func onGoaway(cb: CPointer<Unit>): Unit {
        us_quic_socket_context_on_goaway(ptr, cb)
    }

    /// 对应 Bun: pub const onClose = us_quic_socket_context_on_close
    public func onClose(cb: CPointer<Unit>): Unit {
        us_quic_socket_context_on_close(ptr, cb)
    }

    /// 对应 Bun: pub const onStreamOpen = us_quic_socket_context_on_stream_open
    public func onStreamOpen(cb: CPointer<Unit>): Unit {
        us_quic_socket_context_on_stream_open(ptr, cb)
    }

    /// 对应 Bun: pub const onStreamHeaders = us_quic_socket_context_on_stream_headers
    public func onStreamHeaders(cb: CPointer<Unit>): Unit {
        us_quic_socket_context_on_stream_headers(ptr, cb)
    }

    /// 对应 Bun: pub const onStreamData = us_quic_socket_context_on_stream_data
    public func onStreamData(cb: CPointer<Unit>): Unit {
        us_quic_socket_context_on_stream_data(ptr, cb)
    }

    /// 对应 Bun: pub const onStreamWritable = us_quic_socket_context_on_stream_writable
    public func onStreamWritable(cb: CPointer<Unit>): Unit {
        us_quic_socket_context_on_stream_writable(ptr, cb)
    }

    /// 对应 Bun: pub const onStreamClose = us_quic_socket_context_on_stream_close
    public func onStreamClose(cb: CPointer<Unit>): Unit {
        us_quic_socket_context_on_stream_close(ptr, cb)
    }
}

// ============================================================================
// QuicConnectResult - QUIC 连接结果
// ============================================================================
public open class QuicConnectResult {}
public class QuicConnectResultSocket <: QuicConnectResult {}
public class QuicConnectResultPending <: QuicConnectResult {}
public class QuicConnectResultErr <: QuicConnectResult {}
