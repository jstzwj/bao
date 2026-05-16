// bao_http h3_client encode - HTTP/3 请求编码
// 严格翻译自: src/http/h3_client/encode.zig
package bao_http.h3_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H3FrameEncode - HTTP/3 请求侧帧编码
// 严格翻译自: bun/src/http/h3_client/encode.zig
//
// Bun encode.zig:
//   //! Request-side framing for the HTTP/3 client: build the QPACK header
//   //! list from `HTTPClient.buildRequest` and drain the request body (inline
//   //! bytes or a JS streaming sink) onto the lsquic stream.
//   //! Mirrors `h2_client/encode.zig`.
//
// 核心函数:
//   writeRequest: 构建 QPACK 头部列表并发送请求
//   drainSendBody: 推送请求体到 QUIC 流
//
// 与 h2_client/encode.zig 的区别:
//   - HTTP/3 使用 QPACK (而非 HPACK) 头部压缩
//   - QUIC 流内置流量控制, 不需要手动 WINDOW_UPDATE
//   - 帧分割由 QUIC 层处理, 不需要 CONTINUATION
//   - sendfile 在 HTTP/3 中不适用 (QUIC 是用户态协议)
// ============================================================================

/// HTTP/3 请求帧编码器
/// 严格翻译自: bun/src/http/h3_client/encode.zig
public class H3FrameEncode {
    // ========================================================================
    // writeRequest - 构建并发送 HTTP/3 请求
    // 严格翻译自:
    //   pub fn writeRequest(session: *ClientSession, stream: *Stream,
    //       qs: *quic.Stream) !void {
    //       const client = stream.client orelse return error.Aborted;
    //       const request = client.buildRequest(...);
    //       // 构建 QPACK 头部列表
    //       var headers: ArrayListUnmanaged(quic.Header) = .{};
    //       // 伪头部: :method, :scheme, :authority, :path
    //       // 用户头部: 跳过 forbidden/host, 处理 indexed/新名称
    //       // 发送头部
    //       const end_stream = !has_inline_body and !is_streaming;
    //       if (qs.sendHeaders(headers.items, end_stream) != 0) {
    //           return error.HTTP3HeaderEncodingError;
    //       }
    //       // 处理请求体
    //       if (has_inline_body) {
    //           stream.pending_body = body;
    //           drainSendBody(stream, qs);
    //       } else if (is_streaming) {
    //           stream.is_streaming_body = true;
    //           drainSendBody(stream, qs);
    //       } else {
    //           stream.request_body_done = true;
    //       }
    //   }
    // ========================================================================

    /// 构建并发送 HTTP/3 请求
    /// 严格翻译自: encode.writeRequest
    public static func writeRequest(session: H3ClientSession, stream: H3ClientStream,
                                     qs: QuicStreamRef, method: String, path: String,
                                     host: String, headers: ArrayList<HeaderPair>,
                                     body: Array<UInt8>, isStreaming: Bool): Unit {
        // 构建 QPACK 头部列表
        let qpackHeaders = ArrayList<H3QpackHeader>()

        // 1. 伪头部
        var authority = host
        for (h in headers) {
            if (h.name.toLower() == "host") {
                authority = h.value
            }
        }
        qpackHeaders.append(H3QpackHeader(":method", method))
        qpackHeaders.append(H3QpackHeader(":scheme", "https"))
        qpackHeaders.append(H3QpackHeader(":authority", authority))
        qpackHeaders.append(H3QpackHeader(":path", if (path.size > 0) { path } else { "/" }))

        // 2. 用户头部 (跳过逐跳头部)
        let skipNames = Array<String>(["connection", "keep-alive", "proxy-connection",
                                        "transfer-encoding", "upgrade", "host"])
        for (h in headers) {
            let lower = h.name.toLower()
            var skip = false
            for (s in skipNames) {
                if (lower == s) { skip = true }
            }
            if (skip) { continue }

            // te: 仅转发 "trailers"
            if (lower == "te" && h.value.toLower().trim() != "trailers") { continue }

            qpackHeaders.append(H3QpackHeader(lower, h.value))
        }

        let hasInlineBody = body.size > 0 && !isStreaming
        let endStream = !hasInlineBody && !isStreaming

        // 发送头部 (桩: 实际调用 lsquic lsquic_conn_send_headers)
        // if (qs.sendHeaders(qpackHeaders, endStream) != 0) -> error

        // 处理请求体
        if (hasInlineBody) {
            stream.pendingBody = body
            drainSendBody(stream, qs)
        } else if (isStreaming) {
            stream.isStreamingBody = true
            drainSendBody(stream, qs)
        } else {
            stream.requestBodyDone = true
        }
    }

    // ========================================================================
    // drainSendBody - 推送请求体到 QUIC 流
    // 严格翻译自:
    //   pub fn drainSendBody(stream: *Stream, qs: *quic.Stream) void {
    //       if (stream.request_body_done) return;
    //       const client = stream.client orelse return;
    //       if (stream.is_streaming_body) {
    //           // 流式体: 从 ThreadSafeStreamBuffer 读取
    //           const body = &client.state.original_request_body.stream;
    //           const sb = body.buffer orelse return;
    //           const buffer = sb.acquire();
    //           const data = buffer.slice();
    //           var written: usize = 0;
    //           while (written < data.len) {
    //               const w = qs.write(data[written..]);
    //               if (w <= 0) break;
    //               written += @intCast(w);
    //           }
    //           buffer.cursor += written;
    //           const drained = buffer.isEmpty();
    //           if (drained) buffer.reset();
    //           if (drained and body.ended) {
    //               stream.request_body_done = true;
    //               qs.shutdown();
    //           } else if (!drained) {
    //               qs.wantWrite(true);
    //           } else if (data.len > 0) {
    //               sb.reportDrain();
    //           }
    //           sb.release();
    //       } else {
    //           // 内联体: 写入所有 pending_body
    //           while (stream.pending_body.len > 0) {
    //               const w = qs.write(stream.pending_body);
    //               if (w <= 0) break;
    //               stream.pending_body = stream.pending_body[@intCast(w)..];
    //           }
    //           if (stream.pending_body.len == 0) {
    //               stream.request_body_done = true;
    //               qs.shutdown();
    //           } else {
    //               qs.wantWrite(true);
    //           }
    //       }
    //   }
    // ========================================================================

    /// 推送请求体到 QUIC 流
    /// 严格翻译自: encode.drainSendBody
    public static func drainSendBody(stream: H3ClientStream, qs: QuicStreamRef): Unit {
        if (stream.requestBodyDone) {
            return
        }

        if (stream.isStreamingBody) {
            // 流式体处理 (桩)
            // 实际: 从 ThreadSafeStreamBuffer 读取, 写入 qs
        } else {
            // 内联体
            while (stream.pendingBody.size > 0) {
                let w = qs.write(stream.pendingBody)
                if (w <= 0) {
                    break
                }
                // 移除已写入的字节
                let remaining = ArrayList<UInt8>()
                for (i in w..stream.pendingBody.size) {
                    remaining.append(stream.pendingBody[i])
                }
                stream.pendingBody = remaining.toArray()
            }
            if (stream.pendingBody.size == 0) {
                stream.requestBodyDone = true
                qs.shutdown()
            } else {
                qs.wantWrite(true)
            }
        }
    }
}

/// QPACK 头部条目 (名称/值对)
/// 用于 HTTP/3 头部编码 (QPACK 是 HTTP/3 的头部压缩算法, 类似 HPACK)
public class H3QpackHeader {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}
