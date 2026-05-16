// bao_http h2_client ClientSession - HTTP/2 客户端会话
// 严格翻译自: src/http/h2_client/ClientSession.zig
package bao_http.h2_client

import bao_core.*
import bao_collections.*

// ============================================================================
// H2ClientSession - HTTP/2 客户端会话
// 严格翻译自: bun/src/http/h2_client/ClientSession.zig
//
// Bun ClientSession:
//   //! One TCP+TLS connection running the HTTP/2 protocol for `fetch()`.
//   //! Owns the socket, the connection-scoped HPACK tables, and a map of active `Stream`s.
//
// 核心字段:
//   hpack: *lshpack.HPACK,                    — HPACK 编解码器
//   socket: Socket,                            — TLS socket
//   ctx: *NewHTTPContext(true),                — HTTP 上下文
//   hostname: []const u8,                      — 池键 (主机名)
//   port: u16,                                 — 池键 (端口)
//   ssl_config: ?SSLConfig.SharedPtr,          — SSL 配置
//   write_buffer: bun.io.StreamBuffer,         — 写入缓冲区
//   read_buffer: ArrayListUnmanaged(u8),       — 读取缓冲区
//   streams: AutoArrayHashMapUnmanaged(u31, *Stream), — 活跃流映射
//   next_stream_id: u31 = 1,                   — 下一个流 ID
//   expecting_continuation: u31 = 0,           — 期待 CONTINUATION 的流 ID
//   pending_attach: ArrayListUnmanaged(*HTTPClient), — 冷启动排队的请求
//   preface_sent: bool = false,
//   settings_received: bool = false,
//   goaway_received: bool = false,
//   encoder_poisoned: bool = false,            — HPACK 编码器损坏标记
//   delivering: bool = false,                  — 投递循环进行中标记
//   stream_progressed: bool = false,           — 流进度标记
//   goaway_last_stream_id: u31 = 0,
//   fatal_error: ?anyerror = null,
//   orphan_header_block: ArrayListUnmanaged(u8), — 孤立流头部块
//   encode_scratch: ArrayListUnmanaged(u8),     — HPACK 编码暂存
//   remote_max_frame_size: u24 = 16384,
//   remote_max_concurrent_streams: u32 = 100,
//   remote_initial_window_size: u32 = 65535,
//   pending_hpack_enc_capacity: ?u32 = null,
//   conn_send_window: i32 = 65535,
//   conn_unacked_bytes: u32 = 0,
//   registry_index: u32 = maxInt(u32),
// ============================================================================

/// HTTP/2 客户端会话 — 管理单个 HTTP/2 连接上的所有流和状态
/// 严格翻译自: bun/src/http/h2_client/ClientSession.zig ClientSession struct
public class H2ClientSession {
    /// 主机名 (池键, 拥有拷贝)
    /// 严格翻译自: hostname: []const u8
    public var hostname: String

    /// 端口 (池键)
    /// 严格翻译自: port: u16
    public var port: Int64

    /// 写入缓冲区 — 整帧写入此处，flush() 排空
    /// 严格翻译自: write_buffer: bun.io.StreamBuffer
    public var writeBuffer: ArrayList<UInt8>

    /// 读取缓冲区 — 累积直到完整帧可用
    /// 严格翻译自: read_buffer: std.ArrayListUnmanaged(u8)
    public var readBuffer: ArrayList<UInt8>

    /// 活跃流映射 (stream ID -> Stream)
    /// 严格翻译自: streams: std.AutoArrayHashMapUnmanaged(u31, *Stream)
    public var streams: HashMap<Int64, H2ClientStream>

    /// 下一个客户端流 ID (奇数, 从 1 开始, 每次递增 2)
    /// 严格翻译自: next_stream_id: u31 = 1
    public var nextStreamId: Int64

    /// 期待 CONTINUATION 帧的流 ID (0 = 无)
    /// 严格翻译自: expecting_continuation: u31 = 0
    public var expectingContinuation: Int64

    /// 冷启动排队的请求 (等待服务器 SETTINGS)
    /// 严格翻译自: pending_attach: std.ArrayListUnmanaged(*HTTPClient)
    public var pendingAttach: ArrayList<H2ClientRef>

    /// 是否已发送连接预检
    /// 严格翻译自: preface_sent: bool = false
    public var prefaceSent: Bool

    /// 是否已收到远端 SETTINGS
    /// 严格翻译自: settings_received: bool = false
    public var settingsReceived: Bool

    /// 是否收到 GOAWAY
    /// 严格翻译自: goaway_received: bool = false
    public var goawayReceived: Bool

    /// HPACK 编码器是否损坏
    /// 严格翻译自: encoder_poisoned: bool = false
    public var encoderPoisoned: Bool

    /// 投递循环是否进行中
    /// 严格翻译自: delivering: bool = false
    public var delivering: Bool

    /// 流进度标记
    /// 严格翻译自: stream_progressed: bool = false
    public var streamProgressed: Bool

    /// GOAWAY 最后流 ID
    /// 严格翻译自: goaway_last_stream_id: u31 = 0
    public var goawayLastStreamId: Int64

    /// 致命错误
    /// 严格翻译自: fatal_error: ?anyerror = null
    public var fatalError: ?String

    /// 孤立流头部块 (已 RST 但仍有 CONTINUATION)
    /// 严格翻译自: orphan_header_block: std.ArrayListUnmanaged(u8)
    public var orphanHeaderBlock: ArrayList<UInt8>

    /// HPACK 编码暂存
    /// 严格翻译自: encode_scratch: std.ArrayListUnmanaged(u8)
    public var encodeScratch: ArrayList<UInt8>

    /// 远端最大帧大小 (默认 16384)
    /// 严格翻译自: remote_max_frame_size: u24 = wire.DEFAULT_MAX_FRAME_SIZE
    public var remoteMaxFrameSize: Int64

    /// 远端最大并发流数 (默认 100)
    /// 严格翻译自: remote_max_concurrent_streams: u32 = 100
    public var remoteMaxConcurrentStreams: Int64

    /// 远端初始窗口大小 (默认 65535)
    /// 严格翻译自: remote_initial_window_size: u32 = wire.DEFAULT_WINDOW_SIZE
    public var remoteInitialWindowSize: Int64

    /// 待确认的 HPACK 编码器容量
    /// 严格翻译自: pending_hpack_enc_capacity: ?u32 = null
    public var pendingHpackEncCapacity: ?Int64

    /// 连接级发送窗口
    /// 严格翻译自: conn_send_window: i32 = wire.DEFAULT_WINDOW_SIZE
    public var connSendWindow: Int64

    /// 连接级未确认 DATA 字节
    /// 严格翻译自: conn_unacked_bytes: u32 = 0
    public var connUnackedBytes: Int64

    /// 注册表索引
    /// 严格翻译自: registry_index: u32 = std.math.maxInt(u32)
    public var registryIndex: Int64

    /// HPACK 编解码器
    private var encoder: HpackEncoder
    private var decoder: HpackDecoder

    /// HTTP/2 客户端连接预检
    /// 严格翻译自: H2FrameParser.client_preface
    public static let CLIENT_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    /// 本端初始窗口大小 (2^24 = 16MB)
    /// 严格翻译自: H2Client.local_initial_window_size: u31 = 1 << 24
    public static let LOCAL_INITIAL_WINDOW_SIZE: Int64 = 1 << 24

    /// 本端最大头部列表大小 (256KB)
    /// 严格翻译自: H2Client.local_max_header_list_size: u32 = 256 * 1024
    public static let LOCAL_MAX_HEADER_LIST_SIZE: Int64 = 256 * 1024

    /// 写入缓冲区高水位 (256KB)
    /// 严格翻译自: H2Client.write_buffer_high_water: usize = 256 * 1024
    public static let WRITE_BUFFER_HIGH_WATER: Int64 = 256 * 1024

    /// 写入缓冲区控制限制 (1MB)
    /// 严格翻译自: H2Client.write_buffer_control_limit: usize = 1024 * 1024
    public static let WRITE_BUFFER_CONTROL_LIMIT: Int64 = 1024 * 1024

    /// 默认最大帧大小 (16384)
    public static let DEFAULT_MAX_FRAME_SIZE: Int64 = 16384

    /// 默认窗口大小 (65535)
    public static let DEFAULT_WINDOW_SIZE: Int64 = 65535

    /// 最大窗口大小
    public static let MAX_WINDOW_SIZE: Int64 = Int64.max >> 1

    /// 最大流 ID
    public static let MAX_STREAM_ID: Int64 = Int64.max >> 1

    public init(hostname: String, port: Int64) {
        this.hostname = hostname
        this.port = port
        writeBuffer = ArrayList<UInt8>()
        readBuffer = ArrayList<UInt8>()
        streams = HashMap<Int64, H2ClientStream>()
        nextStreamId = 1
        expectingContinuation = 0
        pendingAttach = ArrayList<H2ClientRef>()
        prefaceSent = false
        settingsReceived = false
        goawayReceived = false
        encoderPoisoned = false
        delivering = false
        streamProgressed = false
        goawayLastStreamId = 0
        fatalError = None
        orphanHeaderBlock = ArrayList<UInt8>()
        encodeScratch = ArrayList<UInt8>()
        remoteMaxFrameSize = DEFAULT_MAX_FRAME_SIZE
        remoteMaxConcurrentStreams = 100
        remoteInitialWindowSize = DEFAULT_WINDOW_SIZE
        pendingHpackEncCapacity = None
        connSendWindow = DEFAULT_WINDOW_SIZE
        connUnackedBytes = 0
        registryIndex = Int64.max
        encoder = HpackEncoder()
        decoder = HpackDecoder()
    }

    // ========================================================================
    // hasHeadroom - 检查是否可以接受更多流
    // 严格翻译自:
    //   pub fn hasHeadroom(this: *const ClientSession) bool {
    //       return !this.goaway_received and !this.encoder_poisoned and
    //           this.fatal_error == null and
    //           this.streams.count() < this.remote_max_concurrent_streams and
    //           this.next_stream_id < wire.MAX_STREAM_ID;
    //   }
    // ========================================================================

    /// 检查是否可以接受更多流
    /// 严格翻译自: ClientSession.hasHeadroom
    public func hasHeadroom(): Bool {
        return !goawayReceived && !encoderPoisoned && fatalError == None &&
               streams.size < remoteMaxConcurrentStreams &&
               nextStreamId < MAX_STREAM_ID
    }

    // ========================================================================
    // matches - 检查是否匹配给定连接参数
    // 严格翻译自:
    //   pub fn matches(this: *const ClientSession, hostname: []const u8,
    //                  port: u16, ssl_config: ?*SSLConfig) bool {
    //       return this.port == port and SSLConfig.rawPtr(this.ssl_config) == ssl_config
    //           and strings.eqlLong(this.hostname, hostname, true);
    //   }
    // ========================================================================

    /// 检查是否匹配给定连接参数
    /// 严格翻译自: ClientSession.matches
    public func matches(hostname: String, port: Int64): Bool {
        return this.port == port && this.hostname == hostname
    }

    // ========================================================================
    // newStream - 分配新流
    // 严格翻译自: ClientSession.attach (流分配部分)
    //   const stream = Stream.new(.{
    //       .id = this.next_stream_id,
    //       .session = this,
    //       .client = client,
    //       .send_window = @intCast(@min(this.remote_initial_window_size,
    //           @as(u32, wire.MAX_WINDOW_SIZE))),
    //   });
    //   this.next_stream_id +|= 2;
    //   bun.handleOom(this.streams.put(..., stream.id, stream));
    // ========================================================================

    /// 分配新流
    /// 严格翻译自: ClientSession.attach 中的流分配逻辑
    public func newStream(client: H2ClientRef): ?H2ClientStream {
        if (!hasHeadroom()) {
            return None
        }

        let streamId = nextStreamId
        nextStreamId += 2

        let sendWindow = if (remoteInitialWindowSize < MAX_WINDOW_SIZE) {
            remoteInitialWindowSize
        } else {
            MAX_WINDOW_SIZE
        }

        let stream = H2ClientStream(streamId, H2SessionRef(this), client, sendWindow)
        streams.put(streamId, stream)
        return stream
    }

    // ========================================================================
    // writeFrame - 写入一个完整的 HTTP/2 帧
    // 严格翻译自:
    //   pub fn writeFrame(this: *ClientSession, frame_type: wire.FrameType,
    //       flags: u8, stream_id: u32, payload: []const u8) void {
    //       var header: wire.FrameHeader = .{ ... };
    //       std.mem.byteSwapAllFields(wire.FrameHeader, &header);
    //       this.queue(std.mem.asBytes(&header)[0..9]);
    //       this.queue(payload);
    //   }
    // ========================================================================

    /// 写入一个完整的 HTTP/2 帧 (9 字节头 + 负载)
    /// 严格翻译自: ClientSession.writeFrame
    public func writeFrame(frameType: H2FrameType, flags: UInt8, streamId: Int64, payload: Array<UInt8>): Unit {
        // 帧头: 9 字节 (3 字节长度 + 1 字节类型 + 1 字节标志 + 4 字节流 ID)
        let length = payload.size
        writeBuffer.append(UInt8((length >> 16) & 0xFF))
        writeBuffer.append(UInt8((length >> 8) & 0xFF))
        writeBuffer.append(UInt8(length & 0xFF))
        writeBuffer.append(frameType.code())
        writeBuffer.append(flags)
        writeBuffer.append(UInt8((streamId >> 24) & 0x7F))
        writeBuffer.append(UInt8((streamId >> 16) & 0xFF))
        writeBuffer.append(UInt8((streamId >> 8) & 0xFF))
        writeBuffer.append(UInt8(streamId & 0xFF))
        // 负载
        for (b in payload) {
            writeBuffer.append(b)
        }
    }

    // ========================================================================
    // writeWindowUpdate - 写入 WINDOW_UPDATE 帧
    // 严格翻译自:
    //   pub fn writeWindowUpdate(this: *ClientSession, stream_id: u32,
    //       increment: u31) void {
    //       var value: u32 = @byteSwap(@as(u32, increment));
    //       this.writeFrame(.HTTP_FRAME_WINDOW_UPDATE, 0, stream_id,
    //           std.mem.asBytes(&value));
    //   }
    // ========================================================================

    /// 写入 WINDOW_UPDATE 帧
    /// 严格翻译自: ClientSession.writeWindowUpdate
    public func writeWindowUpdate(streamId: Int64, increment: Int64): Unit {
        let payload = Array<UInt8>(4, item: UInt8(0))
        payload[0] = UInt8((increment >> 24) & 0x7F)
        payload[1] = UInt8((increment >> 16) & 0xFF)
        payload[2] = UInt8((increment >> 8) & 0xFF)
        payload[3] = UInt8(increment & 0xFF)
        writeFrame(H2FrameType.WindowUpdate, 0, streamId, payload)
    }

    // ========================================================================
    // queue - 向写入缓冲区追加字节
    // 严格翻译自:
    //   pub fn queue(this: *ClientSession, bytes: []const u8) void {
    //       bun.handleOom(this.write_buffer.write(bytes));
    //   }
    // ========================================================================

    /// 向写入缓冲区追加字节
    /// 严格翻译自: ClientSession.queue
    public func queue(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            writeBuffer.append(b)
        }
    }

    // ========================================================================
    // replenishWindow - 补充流量控制窗口
    // 严格翻译自:
    //   fn replenishWindow(this: *ClientSession) void {
    //       const threshold = local_initial_window_size / 2;
    //       if (this.conn_unacked_bytes >= threshold) {
    //           this.writeWindowUpdate(0, @intCast(this.conn_unacked_bytes));
    //           this.conn_unacked_bytes = 0;
    //       }
    //       // per-stream...
    //   }
    // ========================================================================

    /// 补充流量控制窗口
    /// 严格翻译自: ClientSession.replenishWindow
    public func replenishWindow(): Unit {
        let threshold = LOCAL_INITIAL_WINDOW_SIZE / 2
        if (connUnackedBytes >= threshold) {
            writeWindowUpdate(0, connUnackedBytes)
            connUnackedBytes = 0
        }
        // 每流窗口补充
        for (key in streams.keys()) {
            match (streams.get(key)) {
                case Some(stream) => {
                    if (stream.unackedBytes >= threshold && !stream.remoteClosed()) {
                        writeWindowUpdate(stream.id, stream.unackedBytes)
                        stream.unackedBytes = 0
                    }
                }
                case None => ()
            }
        }
    }

    // ========================================================================
    // canPool - 检查是否可以放入连接池
    // 严格翻译自:
    //   pub fn canPool(this: *const ClientSession) bool {
    //       return this.streams.count() == 0 and !this.goaway_received and
    //           !this.encoder_poisoned and this.fatal_error == null and
    //           this.expecting_continuation == 0 and
    //           this.read_buffer.items.len == 0 and
    //           this.write_buffer.isEmpty() and
    //           this.remote_max_concurrent_streams > 0 and
    //           this.next_stream_id < wire.MAX_STREAM_ID;
    //   }
    // ========================================================================

    /// 检查是否可以放入连接池
    /// 严格翻译自: ClientSession.canPool
    public func canPool(): Bool {
        return streams.size == 0 && !goawayReceived && !encoderPoisoned &&
               fatalError == None && expectingContinuation == 0 &&
               readBuffer.size == 0 && writeBuffer.size == 0 &&
               remoteMaxConcurrentStreams > 0 && nextStreamId < MAX_STREAM_ID
    }

    /// 获取活跃流数量
    public func activeStreamCount(): Int64 {
        return streams.size
    }

    /// 获取流
    public func getStream(id: Int64): ?H2ClientStream {
        return streams.get(id)
    }

    /// 移除流
    public func removeStream(id: Int64): Unit {
        streams.remove(id)
    }

    /// 清理资源
    /// 严格翻译自: ClientSession.deinit
    public func deinit(): Unit {
        writeBuffer = ArrayList<UInt8>()
        readBuffer = ArrayList<UInt8>()
        streams = HashMap<Int64, H2ClientStream>()
        pendingAttach = ArrayList<H2ClientRef>()
        orphanHeaderBlock = ArrayList<UInt8>()
        encodeScratch = ArrayList<UInt8>()
    }
}
