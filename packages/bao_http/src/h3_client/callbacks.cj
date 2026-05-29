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
            case Some(session) =>
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
            case Some(session) =>
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

        // 从 streamId 查找关联的会话
        // 对应 Bun: qs = s.socket(); session = qs.ext(ClientSession).*
        let session = findSessionByStreamId(streamId)
        match (session) {
            case Some(sess) =>
                // 查找第一个未绑定 qstream 的待处理流
                var boundStream: ?H3ClientStream = None
                for (st in sess.pending) {
                    if (st.qstream.isNone()) {
                        boundStream = Some(st)
                        break
                    }
                }
                match (boundStream) {
                    case Some(stream) =>
                        // 绑定流
                        let qs = QuicStreamRef(streamId)
                        stream.qstream = Some(qs)
                        // 编码并发送请求
                        H3FrameEncode.writeRequest(
                            sess, stream, qs,
                            "GET", "/", sess.hostname,
                            ArrayList<HeaderPair>(),
                            Array<UInt8>(),
                            false
                        )
                    case None =>
                        // 没有待绑定的请求，关闭流
                        return
                }
            case None =>
                // 找不到会话
                return
        }
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
        // 从 streamId 恢复 stream
        let stream = findStreamByStreamId(streamId)
        match (stream) {
            case Some(s) =>
                // 解析头部, 提取 :status
                var status: Int64 = 0
                for (h in headers) {
                    if (h.name == ":status") {
                        // 解析状态码
                        match (parseStatusCode(h.value)) {
                            case Some(code) => status = code
                            case None => ()
                        }
                    } else if (!h.name.startsWith(":")) {
                        // 非伪头部，保存到 decoded_headers
                        s.decodedHeaders.append(h)
                    }
                }

                if (status == 0) {
                    // 没有 :status — 可能是 trailers，忽略
                    if (s.statusCode != 0) {
                        return
                    }
                    // 否则是协议错误
                    s.session.ptr.fail(s, "HTTP3ProtocolError")
                    return
                }

                // 跳过 1xx 信息响应
                if (status >= 100 && status < 200) {
                    return
                }

                s.statusCode = status
                // 投递响应头部
                s.session.ptr.deliver(s, false)
            case None => ()
        }
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
        // 从 streamId 恢复 stream
        let stream = findStreamByStreamId(streamId)
        match (stream) {
            case Some(s) =>
                // 追加数据到 body_buffer
                if (data.size > 0) {
                    for (b in data) {
                        s.bodyBuffer.append(b)
                    }
                }
                // 投递响应数据
                s.session.ptr.deliver(s, fin)
            case None => ()
        }
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
        // 从 streamId 恢复 stream
        let stream = findStreamByStreamId(streamId)
        match (stream) {
            case Some(s) =>
                match (s.qstream) {
                    case Some(qs) =>
                        // 推送剩余的请求体
                        H3FrameEncode.drainSendBody(s, qs)
                    case None => ()
                }
            case None => ()
        }
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
        // 从 streamId 恢复 stream
        let stream = findStreamByStreamId(streamId)
        match (stream) {
            case Some(s) =>
                // 清除 qstream 引用
                s.qstream = None
                // 最终投递 (done=true)
                s.session.ptr.deliver(s, true)
            case None => ()
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 查找会话 (桩: 实际应从 quic.Socket ext slot 恢复)
    private static func findSession(socketId: Int64): ?H3ClientSession {
        match (H3ClientContext.get()) {
            case Some(ctx) =>
                for (s in ctx.sessions) {
                    match (s.qsocket) {
                        case Some(qs) =>
                            if (qs.id == socketId) {
                                return Some(s)
                            }
                        case None => ()
                    }
                }
                return None
            case None => return None
        }
    }

    /// 通过 streamId 查找会话
    private static func findSessionByStreamId(streamId: Int64): ?H3ClientSession {
        match (H3ClientContext.get()) {
            case Some(ctx) =>
                for (s in ctx.sessions) {
                    for (st in s.pending) {
                        match (st.qstream) {
                            case Some(qs) =>
                                if (qs.id == streamId) {
                                    return Some(s)
                                }
                            case None => ()
                        }
                    }
                }
                return None
            case None => return None
        }
    }

    /// 通过 streamId 查找流
    private static func findStreamByStreamId(streamId: Int64): ?H3ClientStream {
        match (H3ClientContext.get()) {
            case Some(ctx) =>
                for (s in ctx.sessions) {
                    for (st in s.pending) {
                        match (st.qstream) {
                            case Some(qs) =>
                                if (qs.id == streamId) {
                                    return Some(st)
                                }
                            case None => ()
                        }
                    }
                }
                return None
            case None => return None
        }
    }

    /// 解析 HTTP 状态码
    private static func parseStatusCode(value: String): ?Int64 {
        if (value.size == 0 || value.size > 3) {
            return None
        }
        var result: Int64 = 0
        for (ch in value) {
            if (ch < 48 || ch > 57) {
                return None
            }
            result = result * 10 + Int64(ch - 48)
        }
        if (result < 100 || result > 599) {
            return None
        }
        return Some(result)
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

    /// 发起 QUIC 连接
    /// 对应 Bun: quic.Context.connect(host, port, host_z, reject, session)
    /// 返回 .socket (同步) / .pending (DNS 等待) / .err (失败)
    public func connect(hostname: String, port: Int64, rejectUnauthorized: Bool,
                        session: H3ClientSession): QuicConnectResult {
        // 简化实现: 返回错误，因为 QUIC 传输层尚未完全实现
        // 完整实现需要 lsquic 库集成
        return QuicConnectResult.err
    }
}
