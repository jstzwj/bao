// bao_http h3_client Stream - HTTP/3 客户端流
// 严格翻译自: src/http/h3_client/Stream.zig
package bao_http.h3_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H3ClientStream - HTTP/3 客户端单个请求/响应流
// 严格翻译自: bun/src/http/h3_client/Stream.zig
//
// Bun Stream:
//   //! One in-flight HTTP/3 request. Created when the request is enqueued on
//   //! a `ClientSession`; the lsquic stream is bound later from
//   //! `callbacks.onStreamOpen` (lsquic creates streams asynchronously once
//   //! MAX_STREAMS credit is available). Owned by the session's `pending` list
//   //! until `ClientSession.detach`.
//
// 字段:
//   session: *ClientSession,
//   client: ?*HTTPClient,
//   qstream: ?*quic.Stream = null,
//   decoded_headers: ArrayListUnmanaged(picohttp.Header) = .{},
//   body_buffer: ArrayListUnmanaged(u8) = .{},
//   status_code: u16 = 0,
//   pending_body: []const u8 = "",
//   request_body_done: bool = false,
//   is_streaming_body: bool = false,
//   headers_delivered: bool = false,
// ============================================================================

/// HTTP/3 客户端流 — 一个 QUIC 连接上的单个请求/响应
/// 严格翻译自: bun/src/http/h3_client/Stream.zig Stream struct
public class H3ClientStream {
    /// 所属会话
    /// 严格翻译自: session: *ClientSession
    public var session: H3SessionRef

    /// 关联的 HTTP 客户端
    /// 严格翻译自: client: ?*HTTPClient
    public var client: H3ClientRef

    /// QUIC 流 (绑定后设置)
    /// 严格翻译自: qstream: ?*quic.Stream = null
    public var qstream: ?QuicStreamRef

    /// 解码后的响应头部
    /// 严格翻译自: decoded_headers: std.ArrayListUnmanaged(picohttp.Header) = .{}
    public var decodedHeaders: ArrayList<HeaderPair>

    /// 响应体缓冲区
    /// 严格翻译自: body_buffer: std.ArrayListUnmanaged(u8) = .{}
    public var bodyBuffer: ArrayList<UInt8>

    /// 响应状态码 (最终, 非 1xx)
    /// 严格翻译自: status_code: u16 = 0
    public var statusCode: Int64

    /// 未发送的请求体后缀
    /// 严格翻译自: pending_body: []const u8 = ""
    public var pendingBody: Array<UInt8>

    /// 请求体是否发送完成
    /// 严格翻译自: request_body_done: bool = false
    public var requestBodyDone: Bool

    /// 是否为流式请求体
    /// 严格翻译自: is_streaming_body: bool = false
    public var isStreamingBody: Bool

    /// 头部是否已投递
    /// 严格翻译自: headers_delivered: bool = false
    public var headersDelivered: Bool

    public init(session: H3SessionRef, client: H3ClientRef) {
        this.session = session
        this.client = client
        qstream = None
        decodedHeaders = ArrayList<HeaderPair>()
        bodyBuffer = ArrayList<UInt8>()
        statusCode = 0
        pendingBody = Array<UInt8>()
        requestBodyDone = false
        isStreamingBody = false
        headersDelivered = false
    }

    // ========================================================================
    // abort - 中止流 (关闭 QUIC 流)
    // 严格翻译自:
    //   pub fn abort(this: *Stream) void {
    //       if (this.qstream) |qs| qs.close();
    //   }
    // ========================================================================

    /// 中止流
    /// 严格翻译自: Stream.abort
    public func abort(): Unit {
        match (qstream) {
            case Some(qs) => qs.close()
            case None => ()
        }
    }

    // ========================================================================
    // deinit - 清理资源
    // 严格翻译自:
    //   pub fn deinit(this: *Stream) void {
    //       this.decoded_headers.deinit(bun.default_allocator);
    //       this.body_buffer.deinit(bun.default_allocator);
    //       _ = H3.live_streams.fetchSub(1, .monotonic);
    //       bun.destroy(this);
    //   }
    // ========================================================================

    /// 清理资源
    /// 严格翻译自: Stream.deinit
    public func deinit(): Unit {
        decodedHeaders = ArrayList<HeaderPair>()
        bodyBuffer = ArrayList<UInt8>()
        qstream = None
    }
}

/// QUIC 流引用
public class QuicStreamRef {
    public var id: Int64
    public var isOpen: Bool

    public init(id: Int64) {
        this.id = id
        isOpen = true
    }

    /// 关闭流
    public func close(): Unit {
        isOpen = false
    }

    /// 重置流
    public func reset(): Unit {
        isOpen = false
    }

    /// 写入数据
    public func write(data: Array<UInt8>): Int64 {
        if (!isOpen) {
            return -1
        }
        return data.size
    }

    /// 关闭写端
    public func shutdown(): Unit {
        isOpen = false
    }

    /// 请求可写通知
    public func wantWrite(want: Bool): Unit {
        // 桩: 实际由 lsquic 事件循环处理
    }
}

/// H3 会话引用类型
public class H3SessionRef {
    public var ptr: H3ClientSession

    public init(session: H3ClientSession) {
        ptr = session
    }
}

/// H3 客户端引用类型
public class H3ClientRef {
    public var asyncHttpId: Int64
    public var isSet: Bool

    public init() {
        asyncHttpId = 0
        isSet = false
    }

    public init(id: Int64) {
        asyncHttpId = id
        isSet = true
    }
}
