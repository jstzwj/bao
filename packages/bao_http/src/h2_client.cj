// bao_http h2_client - HTTP/2 fetch() 客户端模块入口
// 严格翻译自: src/http/H2Client.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_http.h2_client.*

// ============================================================================
// H2Client - HTTP/2 fetch() 客户端模块
// 严格翻译自: bun/src/http/H2Client.zig
//
// Bun H2Client.zig:
//   //! HTTP/2 path for Bun's fetch HTTP client.
//   //! `ClientSession` owns the TLS socket once ALPN selects "h2" and is the
//   //! `ActiveSocket` variant the HTTPContext handlers dispatch to. It holds
//   //! the connection-scoped state — HPACK tables, write/read buffers, server
//   //! SETTINGS — and a map of active `Stream`s, each bound to one `HTTPClient`.
//   //! Response frames are parsed into per-stream buffers and then handed to the
//   //! same `picohttp.Response` / `handleResponseBody` machinery the HTTP/1.1
//   //! path uses, so redirects, decompression and the result callback are shared.
//
// 常量 (对应 H2Client.zig 中的 pub const):
//   local_initial_window_size: u31 = 1 << 24        — 16MB
//   local_max_header_list_size: u32 = 256 * 1024     — 256KB
//   write_buffer_high_water: usize = 256 * 1024      — 256KB
//   write_buffer_control_limit: usize = 1024 * 1024  — 1MB
//   live_sessions / live_streams                     — 泄漏测试计数器
//
// 模块导出:
//   pub const Stream = @import("./h2_client/Stream.zig");
//   pub const ClientSession = @import("./h2_client/ClientSession.zig");
//   pub const PendingConnect = @import("./h2_client/PendingConnect.zig");
// ============================================================================

/// HTTP/2 客户端模块 — 常量和入口
/// 严格翻译自: bun/src/http/H2Client.zig
public class H2Client {
    /// 本端初始窗口大小 (2^24 = 16MB)
    /// 严格翻译自: local_initial_window_size: u31 = 1 << 24
    public static let LOCAL_INITIAL_WINDOW_SIZE: Int64 = 1 << 24

    /// 本端最大头部列表大小 (256KB)
    /// 严格翻译自: local_max_header_list_size: u32 = 256 * 1024
    public static let LOCAL_MAX_HEADER_LIST_SIZE: Int64 = 256 * 1024

    /// 写入缓冲区高水位 (256KB)
    /// 严格翻译自: write_buffer_high_water: usize = 256 * 1024
    public static let WRITE_BUFFER_HIGH_WATER: Int64 = 256 * 1024

    /// 写入缓冲区控制限制 (1MB)
    /// 严格翻译自: write_buffer_control_limit: usize = 1024 * 1024
    public static let WRITE_BUFFER_CONTROL_LIMIT: Int64 = 1024 * 1024

    /// HTTP/2 连接预检
    /// 严格翻译自: H2FrameParser.client_preface
    public static let CLIENT_PREFACE = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n"

    /// 默认最大帧大小 (16384)
    /// 严格翻译自: H2FrameParser.DEFAULT_MAX_FRAME_SIZE
    public static let DEFAULT_MAX_FRAME_SIZE: Int64 = 16384

    /// 默认窗口大小 (65535)
    /// 严格翻译自: H2FrameParser.DEFAULT_WINDOW_SIZE
    public static let DEFAULT_WINDOW_SIZE: Int64 = 65535

    /// 最大帧大小 (2^24 - 1)
    /// 严格翻译自: H2FrameParser.MAX_FRAME_SIZE
    public static let MAX_FRAME_SIZE: Int64 = (1 << 24) - 1

    /// 最大流 ID (2^31 - 1)
    /// 严格翻译自: H2FrameParser.MAX_STREAM_ID
    public static let MAX_STREAM_ID: Int64 = Int64.max >> 1

    /// 最大窗口大小 (2^31 - 1)
    /// 严格翻译自: H2FrameParser.MAX_WINDOW_SIZE
    public static let MAX_WINDOW_SIZE: Int64 = Int64.max >> 1

    /// 活跃会话计数 (泄漏测试用)
    /// 严格翻译自: pub var live_sessions = std.atomic.Value(i32).init(0)
    public static var liveSessions: Int64 = 0

    /// 活跃流计数 (泄漏测试用)
    /// 严格翻译自: pub var live_streams = std.atomic.Value(i32).init(0)
    public static var liveStreams: Int64 = 0

    /// 创建新的 HTTP/2 客户端会话
    public static func createSession(hostname: String, port: Int64): H2ClientSession {
        liveSessions += 1
        return H2ClientSession(hostname, port)
    }

    /// 创建新的流
    public static func createStream(session: H2ClientSession, client: H2ClientRef): ?H2ClientStream {
        liveStreams += 1
        match (session.newStream(client)) {
            case Some(stream) => return stream
            case None => {
                liveStreams -= 1
                return None
            }
        }
    }
}
