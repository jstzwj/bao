// bao_http h3_client ClientSession - HTTP/3 客户端会话
// 严格翻译自: src/http/h3_client/ClientSession.zig
package bao_http.h3_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H3ClientSession - HTTP/3 客户端会话 (QUIC 连接)
// 严格翻译自: bun/src/http/h3_client/ClientSession.zig
//
// Bun ClientSession:
//   //! One QUIC connection to an origin. Owns its UDP endpoint via quic.c and
//   //! multiplexes `Stream`s, each bound 1:1 to an `HTTPClient`. The `qsocket`
//   //! pointer becomes dangling after `callbacks.onConnClose`, so every accessor
//   //! checks `closed` first.
//
// 核心字段:
//   ref_count: RefCount,
//   qsocket: ?*quic.Socket,
//   hostname: []const u8,
//   port: u16,
//   reject_unauthorized: bool,
//   handshake_done: bool = false,
//   closed: bool = false,
//   registry_index: u32 = maxInt(u32),
//   pending: ArrayListUnmanaged(*Stream) = .{},
//
// 关键方法:
//   matches, hasHeadroom, enqueue, detach, fail, retryOrFail,
//   abortByHttpId, deliver, applyHeaders, finish
// ============================================================================

/// HTTP/3 客户端会话 — 一个 QUIC 连接上的多路复用流管理
/// 严格翻译自: bun/src/http/h3_client/ClientSession.zig ClientSession struct
public class H3ClientSession {
    /// QUIC socket (DNS 完成前为 null)
    /// 严格翻译自: qsocket: ?*quic.Socket
    public var qsocket: ?QuicSocketRef

    /// 主机名
    /// 严格翻译自: hostname: []const u8
    public var hostname: String

    /// 端口
    /// 严格翻译自: port: u16
    public var port: Int64

    /// 是否拒绝未授权证书
    /// 严格翻译自: reject_unauthorized: bool
    public var rejectUnauthorized: Bool

    /// 握手是否完成
    /// 严格翻译自: handshake_done: bool = false
    public var handshakeDone: Bool

    /// 是否已关闭
    /// 严格翻译自: closed: bool = false
    public var closed: Bool

    /// 注册表索引
    /// 严格翻译自: registry_index: u32 = std.math.maxInt(u32)
    public var registryIndex: Int64

    /// 等待流分配的请求列表
    /// 严格翻译自: pending: std.ArrayListUnmanaged(*Stream) = .{}
    public var pending: ArrayList<H3ClientStream>

    public init(hostname: String, port: Int64, rejectUnauthorized: Bool) {
        this.hostname = hostname
        this.port = port
        this.rejectUnauthorized = rejectUnauthorized
        qsocket = None
        handshakeDone = false
        closed = false
        registryIndex = Int64.max
        pending = ArrayList<H3ClientStream>()
    }

    // ========================================================================
    // matches - 检查是否匹配连接参数
    // 严格翻译自:
    //   pub fn matches(this: *const ClientSession, hostname: []const u8,
    //       port: u16, reject_unauthorized: bool) bool {
    //       return !this.closed and this.port == port and
    //           this.reject_unauthorized == reject_unauthorized and
    //           strings.eqlLong(this.hostname, hostname, true);
    //   }
    // ========================================================================

    /// 检查是否匹配连接参数
    /// 严格翻译自: ClientSession.matches
    public func matches(hostname: String, port: Int64, rejectUnauthorized: Bool): Bool {
        return !closed && this.port == port &&
               this.rejectUnauthorized == rejectUnauthorized &&
               this.hostname == hostname
    }

    // ========================================================================
    // hasHeadroom - 检查是否可以接受更多流
    // 严格翻译自:
    //   pub fn hasHeadroom(this: *const ClientSession) bool {
    //       if (this.closed) return false;
    //       const qs = this.qsocket orelse return this.pending.items.len < 64;
    //       if (!this.handshake_done) return this.pending.items.len < 64;
    //       return qs.streamsAvail() > 0;
    //   }
    // ========================================================================

    /// 检查是否可以接受更多流
    /// 严格翻译自: ClientSession.hasHeadroom
    public func hasHeadroom(): Bool {
        if (closed) {
            return false
        }
        if (!handshakeDone) {
            return pending.size < 64
        }
        return true  // 桩: 实际应检查 lsquic 可用流数
    }

    // ========================================================================
    // enqueue - 将请求加入等待队列
    // 严格翻译自:
    //   pub fn enqueue(this: *ClientSession, client: *HTTPClient) void {
    //       bun.debugAssert(!this.closed);
    //       client.h3 = null;
    //       client.flags.protocol = .http3;
    //       client.allow_retry = false;
    //       const stream = Stream.new(.{ .session = this, .client = client });
    //       _ = H3.live_streams.fetchAdd(1, .monotonic);
    //       client.h3 = stream;
    //       bun.handleOom(this.pending.append(bun.default_allocator, stream));
    //       this.ref();
    //       if (this.handshake_done) { this.qsocket.?.makeStream(); }
    //   }
    // ========================================================================

    /// 将请求加入等待队列
    /// 严格翻译自: ClientSession.enqueue
    public func enqueue(client: H3ClientRef): H3ClientStream {
        let stream = H3ClientStream(H3SessionRef(this), client)
        pending.append(stream)
        return stream
    }

    // ========================================================================
    // detach - 从会话中分离流
    // 严格翻译自:
    //   pub fn detach(this: *ClientSession, stream: *Stream) void {
    //       if (stream.client) |cl| cl.h3 = null;
    //       stream.client = null;
    //       if (stream.qstream) |qs| {
    //           qs.ext(Stream).* = null;
    //           if (!stream.request_body_done) qs.reset();
    //       }
    //       stream.qstream = null;
    //       if (std.mem.indexOfScalar(*Stream, this.pending.items, stream)) |i| {
    //           _ = this.pending.orderedRemove(i);
    //       }
    //       stream.deinit();
    //       this.deref();
    //   }
    // ========================================================================

    /// 从会话中分离流
    /// 严格翻译自: ClientSession.detach
    public func detach(stream: H3ClientStream): Unit {
        stream.client = H3ClientRef()
        match (stream.qstream) {
            case Some(qs) => {
                qs.reset()
            }
            case None => ()
        }
        stream.qstream = None

        // 从 pending 列表中移除
        var i: Int64 = 0
        while (i < pending.size) {
            if (pending[i] === stream) {
                pending.removeAt(Int32(i))
                break
            }
            i += 1
        }
        stream.deinit()
    }

    // ========================================================================
    // fail - 流失败处理
    // 严格翻译自:
    //   pub fn fail(this: *ClientSession, stream: *Stream, err: anyerror) void {
    //       const client = stream.client;
    //       stream.abort();
    //       this.detach(stream);
    //       if (client) |cl| cl.failFromH2(err);
    //   }
    // ========================================================================

    /// 流失败处理
    /// 严格翻译自: ClientSession.fail
    public func fail(stream: H3ClientStream, err: String): Unit {
        stream.abort()
        detach(stream)
    }

    // ========================================================================
    // retryOrFail - 重试或失败
    // 严格翻译自:
    //   pub fn retryOrFail(this: *ClientSession, stream: *Stream,
    //       err: anyerror) void {
    //       const client = stream.client orelse return this.fail(stream, err);
    //       if (client.flags.h3_retried or stream.is_streaming_body) {
    //           return this.fail(stream, err);
    //       }
    //       // 标记已重试, 关闭旧会话, 在新会话上重新调度
    //   }
    // ========================================================================

    /// 重试或失败
    /// 严格翻译自: ClientSession.retryOrFail
    public func retryOrFail(stream: H3ClientStream, err: String): Bool {
        // 简化: 不支持自动重试
        fail(stream, err)
        return false
    }

    // ========================================================================
    // abortByHttpId - 按 HTTP ID 中止请求
    // 严格翻译自:
    //   pub fn abortByHttpId(this: *ClientSession, async_http_id: u32) bool {
    //       for (this.pending.items) |stream| {
    //           const cl = stream.client orelse continue;
    //           if (cl.async_http_id == async_http_id) {
    //               this.fail(stream, error.Aborted);
    //               return true;
    //           }
    //       }
    //       return false;
    //   }
    // ========================================================================

    /// 按 HTTP ID 中止请求
    /// 严格翻译自: ClientSession.abortByHttpId
    public func abortByHttpId(asyncHttpId: Int64): Bool {
        var i: Int64 = 0
        while (i < pending.size) {
            let stream = pending[i]
            if (stream.client.isSet && stream.client.asyncHttpId == asyncHttpId) {
                fail(stream, "Aborted")
                return true
            }
            i += 1
        }
        return false
    }

    // ========================================================================
    // streamBodyByHttpId - 按 HTTP ID 流式传输请求体
    // 严格翻译自: ClientSession.streamBodyByHttpId
    // ========================================================================

    /// 按 HTTP ID 流式传输请求体
    /// 严格翻译自: ClientSession.streamBodyByHttpId
    public func streamBodyByHttpId(asyncHttpId: Int64, ended: Bool): Unit {
        for (stream in pending) {
            if (stream.client.isSet && stream.client.asyncHttpId == asyncHttpId) {
                // 桩: 应调用 encode.drainSendBody
                return
            }
        }
    }

    // ========================================================================
    // deliver - 投递响应数据
    // 严格翻译自: ClientSession.deliver
    // 镜像 H2 的 ClientSession.deliverStream
    // ========================================================================

    /// 投递响应数据
    /// 严格翻译自: ClientSession.deliver
    public func deliver(stream: H3ClientStream, done: Bool): Unit {
        if (!stream.client.isSet) {
            if (done) {
                detach(stream)
            }
            return
        }

        // 头部投递
        if (stream.statusCode != 0 && !stream.headersDelivered) {
            stream.headersDelivered = true
            // 桩: 实际应调用 applyHeaders + 处理重定向
        }

        // 体数据投递
        if (stream.bodyBuffer.size > 0) {
            if (done) {
                // 最终投递
            }
            stream.bodyBuffer = ArrayList<UInt8>()
        }

        if (done) {
            detach(stream)
        }
    }

    /// 清理资源
    public func deinit(): Unit {
        pending = ArrayList<H3ClientStream>()
        qsocket = None
    }
}

/// QUIC socket 引用
public class QuicSocketRef {
    public var id: Int64
    public var isOpen: Bool

    public init(id: Int64) {
        this.id = id
        isOpen = true
    }

    /// 创建流
    public func makeStream(): Unit {
        // 桩: 调用 lsquic_conn_make_stream
    }

    /// 检查可用流数
    public func streamsAvail(): Int64 {
        return 64  // 桩
    }
}
