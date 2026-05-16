// bao_http h2_client Stream - HTTP/2 客户端流
// 严格翻译自: src/http/h2_client/Stream.zig
package bao_http.h2_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H2ClientStream - HTTP/2 客户端单个请求/响应流
// 严格翻译自: bun/src/http/h2_client/Stream.zig
//
// Bun Stream 结构:
//   const Stream = @This();
//   id: u31,                        — 流 ID (客户端发起为奇数)
//   session: *ClientSession,        — 所属会话
//   client: ?*HTTPClient,           — 关联的 HTTP 客户端 (弱引用)
//   header_block: ArrayList(u8),    — HEADERS + CONTINUATION 碎片
//   body_buffer: ArrayList(u8),     — DATA 负载累积
//   decoded_bytes: ArrayList(u8),   — HPACK 解码后的字节
//   decoded_headers: ArrayList(Header), — 解码后的头部列表
//   status_code: u32 = 0,           — 最终状态码 (非 1xx)
//   state: State = .open,           — 流状态
//   rst_done: bool = false,         — 是否通过 RST_STREAM 关闭
//   headers_ready: bool = false,    — 非头部已解码待投递
//   headers_end_stream: bool = false,
//   awaiting_continue: bool = false, — Expect: 100-continue
//   fatal_error: ?anyerror = null,   — 致命错误
//   unacked_bytes: u32 = 0,          — 未确认的 DATA 字节
//   data_bytes_received: u64 = 0,    — DATA 负载字节总数
//   send_window: i32,                — 流级别发送窗口
//   pending_body: []const u8 = "",   — 未发送的请求体后缀
//
// RFC 9113 §5.1 流状态机:
//   open → half_closed_local (发送 END_STREAM)
//   open → half_closed_remote (收到 END_STREAM)
//   half_closed_local + half_closed_remote → closed
//   任何 → closed (RST_STREAM)
// ============================================================================

/// HTTP/2 流状态 - 对应 RFC 9113 §5.1
/// 严格翻译自: Stream.State
public enum H2StreamState {
    | Open               // 双向开放 — 流刚创建
    | HalfClosedLocal    // 本端已半关闭 (已发送 END_STREAM)
    | HalfClosedRemote   // 对端已半关闭 (收到 END_STREAM)
    | Closed             // 完全关闭
}

/// HTTP/2 客户端流 — 一个多路复用 HTTP/2 连接上的单个请求/响应对
/// 严格翻译自: bun/src/http/h2_client/Stream.zig Stream struct
public class H2ClientStream {
    /// 流 ID (31-bit, 客户端发起为奇数)
    /// 严格翻译自: id: u31
    public var id: Int64

    /// 所属会话 (弱引用概念)
    /// 严格翻译自: session: *ClientSession
    public var session: H2SessionRef

    /// 关联的 HTTP 客户端 (在终端回调前清除)
    /// 严格翻译自: client: ?*HTTPClient
    public var client: H2ClientRef

    /// HEADERS + CONTINUATION 碎片, END_HEADERS 到达后解码
    /// 严格翻译自: header_block: std.ArrayListUnmanaged(u8) = .{}
    public var headerBlock: ArrayList<UInt8>

    /// DATA 负载累积
    /// 严格翻译自: body_buffer: std.ArrayListUnmanaged(u8) = .{}
    public var bodyBuffer: ArrayList<UInt8>

    /// HPACK 解码后的字节存储
    /// 严格翻译自: decoded_bytes: std.ArrayListUnmanaged(u8) = .{}
    public var decodedBytes: ArrayList<UInt8>

    /// 解码后的头部列表
    /// 严格翻译自: decoded_headers: std.ArrayListUnmanaged(picohttp.Header) = .{}
    public var decodedHeaders: ArrayList<HeaderPair>

    /// 最终 (非 1xx) 状态码; 0 直到响应 HEADERS 到达
    /// 严格翻译自: status_code: u32 = 0
    public var statusCode: Int64

    /// 流状态
    /// 严格翻译自: state: State = .open
    public var state: H2StreamState

    /// 是否通过 RST_STREAM (发送或接收) 关闭
    /// 严格翻译自: rst_done: bool = false
    public var rstDone: Bool

    /// 非头部已解码并等待投递
    /// 严格翻译自: headers_ready: bool = false
    public var headersReady: Bool

    /// HEADERS 帧是否带 END_STREAM
    /// 严格翻译自: headers_end_stream: bool = false
    public var headersEndStream: Bool

    /// Expect: 100-continue 生效: 等待 1xx 或最终状态
    /// 严格翻译自: awaiting_continue: bool = false
    public var awaitingContinue: Bool

    /// 致命错误
    /// 严格翻译自: fatal_error: ?anyerror = null
    public var fatalError: ?String

    /// DATA 字节消耗量 (自上次 WINDOW_UPDATE)
    /// 严格翻译自: unacked_bytes: u32 = 0
    public var unackedBytes: Int64

    /// DATA 负载字节总数 (用于 Content-Length 检查)
    /// 严格翻译自: data_bytes_received: u64 = 0
    public var dataBytesReceived: Int64

    /// 流级别发送窗口
    /// 严格翻译自: send_window: i32
    public var sendWindow: Int64

    /// 未发送的请求体后缀 (窗口耗尽时暂存)
    /// 严格翻译自: pending_body: []const u8 = ""
    public var pendingBody: Array<UInt8>

    public init(id: Int64, session: H2SessionRef, client: H2ClientRef, sendWindow: Int64) {
        this.id = id
        this.session = session
        this.client = client
        this.sendWindow = sendWindow
        headerBlock = ArrayList<UInt8>()
        bodyBuffer = ArrayList<UInt8>()
        decodedBytes = ArrayList<UInt8>()
        decodedHeaders = ArrayList<HeaderPair>()
        statusCode = 0
        state = H2StreamState.Open
        rstDone = false
        headersReady = false
        headersEndStream = false
        awaitingContinue = false
        fatalError = None
        unackedBytes = 0
        dataBytesReceived = 0
        pendingBody = Array<UInt8>()
    }

    // ========================================================================
    // sentEndStream - 发送 END_STREAM 后更新状态
    // 严格翻译自:
    //   pub fn sentEndStream(this: *@This()) void {
    //       this.state = switch (this.state) {
    //           .open => .half_closed_local,
    //           .half_closed_remote => .closed,
    //           else => this.state,
    //       };
    //   }
    // ========================================================================

    /// 发送 END_STREAM 后更新状态
    /// 严格翻译自: Stream.sentEndStream
    public func sentEndStream(): Unit {
        match (state) {
            case H2StreamState.Open => state = H2StreamState.HalfClosedLocal
            case H2StreamState.HalfClosedRemote => state = H2StreamState.Closed
            case _ => ()
        }
    }

    // ========================================================================
    // recvEndStream - 收到 END_STREAM 后更新状态
    // 严格翻译自:
    //   pub fn recvEndStream(this: *@This()) void {
    //       this.state = switch (this.state) {
    //           .open => .half_closed_remote,
    //           .half_closed_local => .closed,
    //           else => this.state,
    //       };
    //   }
    // ========================================================================

    /// 收到 END_STREAM 后更新状态
    /// 严格翻译自: Stream.recvEndStream
    public func recvEndStream(): Unit {
        match (state) {
            case H2StreamState.Open => state = H2StreamState.HalfClosedRemote
            case H2StreamState.HalfClosedLocal => state = H2StreamState.Closed
            case _ => ()
        }
    }

    // ========================================================================
    // localClosed / remoteClosed - 检查本端/对端关闭状态
    // 严格翻译自:
    //   pub inline fn localClosed(this: *const @This()) bool {
    //       return this.state == .half_closed_local or this.state == .closed;
    //   }
    //   pub inline fn remoteClosed(this: *const @This()) bool {
    //       return this.state == .half_closed_remote or this.state == .closed;
    //   }
    // ========================================================================

    /// 本端是否已关闭 (已发送 END_STREAM 或 RST)
    /// 严格翻译自: Stream.localClosed
    public func localClosed(): Bool {
        return state == H2StreamState.HalfClosedLocal || state == H2StreamState.Closed
    }

    /// 对端是否已关闭 (收到 END_STREAM 或 RST)
    /// 严格翻译自: Stream.remoteClosed
    public func remoteClosed(): Bool {
        return state == H2StreamState.HalfClosedRemote || state == H2StreamState.Closed
    }

    // ========================================================================
    // rst - 发送 RST_STREAM (幂等)
    // 严格翻译自:
    //   pub fn rst(this: *@This(), code: wire.ErrorCode) void {
    //       if (this.rst_done or this.state == .closed) return;
    //       this.rst_done = true;
    //       this.state = .closed;
    //       var value: u32 = @byteSwap(@intFromEnum(code));
    //       this.session.writeFrame(.HTTP_FRAME_RST_STREAM, 0, this.id,
    //           std.mem.asBytes(&value));
    //   }
    // ========================================================================

    /// 发送 RST_STREAM (幂等)
    /// 严格翻译自: Stream.rst
    public func rst(errorCode: H2ErrorCode): Unit {
        if (rstDone || state == H2StreamState.Closed) {
            return
        }
        rstDone = true
        state = H2StreamState.Closed
        // 构建并发送 RST_STREAM 帧 (4 字节 big-endian 错误码)
        let payload = Array<UInt8>(4, item: UInt8(0))
        let ec = errorCode.code()
        payload[0] = UInt8((ec >> 24) & 0xFF)
        payload[1] = UInt8((ec >> 16) & 0xFF)
        payload[2] = UInt8((ec >> 8) & 0xFF)
        payload[3] = UInt8(ec & 0xFF)
        session.writeFrame(H2FrameType.RstStream, 0, id, payload)
    }

    /// 累积头部块数据
    public func appendHeaderBlock(data: Array<UInt8>): Unit {
        for (b in data) {
            headerBlock.append(b)
        }
    }

    /// 累积 body 数据
    public func appendBody(data: Array<UInt8>): Unit {
        for (b in data) {
            bodyBuffer.append(b)
        }
        unackedBytes += data.size
    }

    /// 清理资源
    /// 严格翻译自: Stream.deinit
    public func deinit(): Unit {
        headerBlock = ArrayList<UInt8>()
        bodyBuffer = ArrayList<UInt8>()
        decodedBytes = ArrayList<UInt8>()
        decodedHeaders = ArrayList<HeaderPair>()
        pendingBody = Array<UInt8>()
    }
}

/// 会话引用类型 (避免循环依赖)
public class H2SessionRef {
    public var ptr: H2ClientSession

    public init(session: H2ClientSession) {
        ptr = session
    }

    /// 委托: 写帧
    public func writeFrame(frameType: H2FrameType, flags: UInt8, streamId: Int64, payload: Array<UInt8>): Unit {
        ptr.writeFrame(frameType, flags, streamId, payload)
    }

    /// 委托: 写 WINDOW_UPDATE
    public func writeWindowUpdate(streamId: Int64, increment: Int64): Unit {
        ptr.writeWindowUpdate(streamId, increment)
    }
}

/// 客户端引用类型 (避免循环依赖)
public class H2ClientRef {
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
