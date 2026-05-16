// bao_http h3_client callbacks - lsquic -> 仓颉回调桥接
// 严格翻译自: src/http/h3_client/callbacks.zig
package bao_http.h3_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H3Callbacks - lsquic -> 仓颉回调注册和处理
// 严格翻译自: bun/src/http/h3_client/callbacks.zig
//
// Bun callbacks:
//   //! lsquic → Zig callbacks for the HTTP/3 client. Registered on the
//   //! `quic.Context` from `ClientContext.getOrCreate`; lsquic invokes these
//   //! from inside `process_conns` on the HTTP thread.
//
// 注册的回调:
//   onHskDone        — TLS 握手完成
//   onGoaway         — 收到 GOAWAY
//   onConnClose      — 连接关闭
//   onStreamOpen     — 新流打开
//   onStreamHeaders  — 流头部到达
//   onStreamData     — 流数据到达
//   onStreamWritable — 流可写
//   onStreamClose    — 流关闭
//
// 仓颉实现将回调组织为 H3Callbacks 类的静态方法
// ============================================================================

/// HTTP/3 lsquic 回调处理器
/// 严格翻译自: bun/src/http/h3_client/callbacks.zig
public class H3Callbacks {
    // ========================================================================
    // register - 注册所有回调到 QUIC 上下文
    // 严格翻译自:
    //   pub fn register(qctx: *quic.Context) void {
    //       qctx.onHskDone(onHskDone);
    //       qctx.onGoaway(onGoaway);
    //       qctx.onClose(onConnClose);
    //       qctx.onStreamOpen(onStreamOpen);
    //       qctx.onStreamHeaders(onStreamHeaders);
    //       qctx.onStreamData(onStreamData);
    //       qctx.onStreamWritable(onStreamWritable);
    //       qctx.onStreamClose(onStreamClose);
    //   }
    // ========================================================================

    /// 注册所有回调到 QUIC 上下文
    /// 严格翻译自: callbacks.register
    public static func register(ctx: H3QuicContext): Unit {
        ctx.onHskDone = onHskDone
        ctx.onGoaway = onGoaway
        ctx.onConnClose = onConnClose
        ctx.onStreamOpen = onStreamOpen
        ctx.onStreamHeaders = onStreamHeaders
        ctx.onStreamData = onStreamData
        ctx.onStreamWritable = onStreamWritable
        ctx.onStreamClose = onStreamClose
    }

    // ========================================================================
    // onHskDone - TLS 握手完成回调
    // 严格翻译自:
    //   fn onHskDone(qs: *quic.Socket, ok: c_int) callconv(.c) void {
    //       const session = qs.ext(ClientSession).* orelse return;
    //       if (ok == 0) {
    //           session.closed = true;
    //           return;
    //       }
    //       session.handshake_done = true;
    //       for (session.pending.items) |_| qs.makeStream();
    //   }
    // ========================================================================

    /// TLS 握手完成回调
    /// 严格翻译自: callbacks.onHskDone
    public static func onHskDone(ctx: H3QuicContext, socketId: Int64, ok: Bool): Unit {
        match (findSession(socketId)) {
            case Some(session) => {
                if (!ok) {
                    session.closed = true
                    return
                }
                session.handshakeDone = true
                // 为每个等待的请求创建流
                for (_ in session.pending) {
                    match (session.qsocket) {
                        case Some(qs) => qs.makeStream()
                        case None => ()
                    }
                }
            }
            case None => ()
        }
    }

    // ========================================================================
    // onGoaway - GOAWAY 回调
    // 严格翻译自:
    //   fn onGoaway(qs: *quic.Socket) callconv(.c) void {
    //       const session = qs.ext(ClientSession).* orelse return;
    //       session.closed = true;
    //   }
    // ========================================================================

    /// GOAWAY 回调
    /// 严格翻译自: callbacks.onGoaway
    public static func onGoaway(ctx: H3QuicContext, socketId: Int64): Unit {
        match (findSession(socketId)) {
            case Some(session) => session.closed = true
            case None => ()
        }
    }

    // ========================================================================
    // onConnClose - 连接关闭回调
    // 严格翻译自:
    //   fn onConnClose(qs: *quic.Socket) callconv(.c) void {
    //       const session = qs.ext(ClientSession).* orelse return;
    //       session.closed = true;
    //       session.q_socket = null;
    //       if (ClientContext.get()) |ctx| ctx.unregister(session);
    //       while (session.pending.items.len > 0) {
    //           const stream = session.pending.items[0];
    //           session.retryOrFail(stream, ...);
    //       }
    //       _ = H3.live_sessions.fetchSub(1, .monotonic);
    //       session.deref();
    //   }
    // ========================================================================

    /// 连接关闭回调
    /// 严格翻译自: callbacks.onConnClose
    public static func onConnClose(ctx: H3QuicContext, socketId: Int64): Unit {
        match (findSession(socketId)) {
            case Some(session) => {
                session.closed = true
                session.qsocket = None

                // 从注册表中移除
                match (H3ClientContext.get()) {
                    case Some(clientCtx) => clientCtx.unregister(session)
                    case None => ()
                }

                // 重试或失败所有等待的流
                while (session.pending.size > 0) {
                    let stream = session.pending[0]
                    let err = if (session.handshakeDone) { "ConnectionClosed" } else { "HTTP3HandshakeFailed" }
                    session.retryOrFail(stream, err)
                }
            }
            case None => ()
        }
    }

    // ========================================================================
    // onStreamOpen - 流打开回调
    // 严格翻译自:
    //   fn onStreamOpen(s: *quic.Stream, is_client: c_int) callconv(.c) void {
    //       s.ext(Stream).* = null;
    //       if (is_client == 0) return;
    //       const qs = s.socket() orelse return;
    //       const session = qs.ext(ClientSession).* orelse { s.close(); return; };
    //       // 绑定下一个等待的请求到这个流
    //       const stream: *Stream = for (session.pending.items) |st| {
    //           if (st.qstream == null) break st;
    //       } else { s.close(); return; };
    //       stream.qstream = s;
    //       s.ext(Stream).* = stream;
    //       encode.writeRequest(session, stream, s) catch |err| {
    //           session.fail(stream, err);
    //       };
    //   }
    // ========================================================================

    /// 流打开回调
    /// 严格翻译自: callbacks.onStreamOpen
    public static func onStreamOpen(ctx: H3QuicContext, streamId: Int64, isClient: Bool): Unit {
        if (!isClient) {
            return
        }

        // 查找会话和待绑定的流
        // 桩: 实际应从 quic.Stream 的 ext slot 恢复 session
    }

    // ========================================================================
    // onStreamHeaders - 流头部回调
    // 严格翻译自:
    //   fn onStreamHeaders(s: *quic.Stream) callconv(.c) void {
    //       const stream = s.ext(Stream).* orelse return;
    //       const n = s.headerCount();
    //       // 解析头部, 提取 :status
    //       // 跳过 1xx 和 trailers
    //       stream.session.deliver(stream, false);
    //   }
    // ========================================================================

    /// 流头部回调
    /// 严格翻译自: callbacks.onStreamHeaders
    public static func onStreamHeaders(ctx: H3QuicContext, streamId: Int64,
                                        headers: ArrayList<HeaderPair>): Unit {
        // 桩: 从 stream ext slot 恢复 stream
        // 解析头部, 提取 :status
        // 跳过 1xx 和 trailers
    }

    // ========================================================================
    // onStreamData - 流数据回调
    // 严格翻译自:
    //   fn onStreamData(s: *quic.Stream, data: [*]const u8, len: c_uint,
    //       fin: c_int) callconv(.c) void {
    //       const stream = s.ext(Stream).* orelse return;
    //       if (len > 0) {
    //           bun.handleOom(stream.body_buffer.appendSlice(..., data[0..len]));
    //       }
    //       stream.session.deliver(stream, fin != 0);
    //   }
    // ========================================================================

    /// 流数据回调
    /// 严格翻译自: callbacks.onStreamData
    public static func onStreamData(ctx: H3QuicContext, streamId: Int64,
                                     data: Array<UInt8>, fin: Bool): Unit {
        // 桩: 从 stream ext slot 恢复 stream
        // 追加数据到 body_buffer
        // 调用 session.deliver(stream, fin)
    }

    // ========================================================================
    // onStreamWritable - 流可写回调
    // 严格翻译自:
    //   fn onStreamWritable(s: *quic.Stream) callconv(.c) void {
    //       const stream = s.ext(Stream).* orelse return;
    //       encode.drainSendBody(stream, s);
    //   }
    // ========================================================================

    /// 流可写回调
    /// 严格翻译自: callbacks.onStreamWritable
    public static func onStreamWritable(ctx: H3QuicContext, streamId: Int64): Unit {
        // 桩: 从 stream ext slot 恢复 stream
        // 调用 encode.drainSendBody(stream, qs)
    }

    // ========================================================================
    // onStreamClose - 流关闭回调
    // 严格翻译自:
    //   fn onStreamClose(s: *quic.Stream) callconv(.c) void {
    //       const stream = s.ext(Stream).* orelse return;
    //       s.ext(Stream).* = null;
    //       stream.qstream = null;
    //       stream.session.deliver(stream, true);
    //   }
    // ========================================================================

    /// 流关闭回调
    /// 严格翻译自: callbacks.onStreamClose
    public static func onStreamClose(ctx: H3QuicContext, streamId: Int64): Unit {
        // 桩: 从 stream ext slot 恢复 stream
        // 调用 session.deliver(stream, true)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 查找会话 (桩: 实际应从 quic.Socket ext slot 恢复)
    private static func findSession(socketId: Int64): ?H3ClientSession {
        match (H3ClientContext.get()) {
            case Some(ctx) => {
                for (s in ctx.sessions) {
                    match (s.qsocket) {
                        case Some(qs) => {
                            if (qs.id == socketId) {
                                return Some(s)
                            }
                        }
                        case None => ()
                    }
                }
                return None
            }
            case None => return None
        }
    }
}

/// QUIC 上下文 (回调注册目标)
public class H3QuicContext {
    public var onHskDone: (H3QuicContext, Int64, Bool) -> Unit
    public var onGoaway: (H3QuicContext, Int64) -> Unit
    public var onConnClose: (H3QuicContext, Int64) -> Unit
    public var onStreamOpen: (H3QuicContext, Int64, Bool) -> Unit
    public var onStreamHeaders: (H3QuicContext, Int64, ArrayList<HeaderPair>) -> Unit
    public var onStreamData: (H3QuicContext, Int64, Array<UInt8>, Bool) -> Unit
    public var onStreamWritable: (H3QuicContext, Int64) -> Unit
    public var onStreamClose: (H3QuicContext, Int64) -> Unit

    public init() {
        onHskDone = { ctx, id, ok => () }
        onGoaway = { ctx, id => () }
        onConnClose = { ctx, id => () }
        onStreamOpen = { ctx, id, isClient => () }
        onStreamHeaders = { ctx, id, headers => () }
        onStreamData = { ctx, id, data, fin => () }
        onStreamWritable = { ctx, id => () }
        onStreamClose = { ctx, id => () }
    }
}
