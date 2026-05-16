// bao_http h3_client - HTTP/3 fetch() 客户端模块入口
// 严格翻译自: src/http/H3Client.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_http.h3_client.*

// ============================================================================
// H3Client - HTTP/3 fetch() 客户端模块
// 严格翻译自: bun/src/http/H3Client.zig
//
// Bun H3Client.zig:
//   //! HTTP/3 client over lsquic via packages/bun-usockets/src/quic.c.
//   //! One `ClientContext` per HTTP-thread loop wraps the lsquic client engine;
//   //! each `ClientSession` is one QUIC connection to an origin and multiplexes
//   //! `Stream`s, each bound 1:1 to an `HTTPClient`. The result-delivery surface
//   //! is the same one H2 uses (`handleResponseMetadata` / `handleResponseBody` /
//   //! `progressUpdateH3`), so redirect, decompression, and FetchTasklet plumbing
//   //! are shared with HTTP/1.1.
//   //!
//   //! Layout mirrors `h2_client/`:
//   //!   - `Stream`         — one in-flight request
//   //!   - `ClientSession`  — one QUIC connection (pooled per origin)
//   //!   - `ClientContext`  — process-global lsquic engine + session registry
//   //!   - `encode`         — request header/body framing onto a quic.Stream
//   //!   - `callbacks`      — lsquic → Zig glue (on_hsk_done / on_stream_* / …)
//   //!   - `PendingConnect` — DNS-pending connect resolution
//
// 模块导出:
//   pub const Stream = @import("./h3_client/Stream.zig");
//   pub const ClientSession = @import("./h3_client/ClientSession.zig");
//   pub const ClientContext = @import("./h3_client/ClientContext.zig");
//   pub const PendingConnect = @import("./h3_client/PendingConnect.zig");
//   pub const AltSvc = @import("./h3_client/AltSvc.zig");
//
// 活跃对象计数器:
//   pub var live_sessions = std.atomic.Value(u32).init(0);
//   pub var live_streams = std.atomic.Value(u32).init(0);
// ============================================================================

/// HTTP/3 客户端模块 — 常量和入口
/// 严格翻译自: bun/src/http/H3Client.zig
public class H3Client {
    /// 活跃会话计数 (泄漏测试用)
    /// 严格翻译自: pub var live_sessions = std.atomic.Value(u32).init(0)
    public static var liveSessions: Int64 = 0

    /// 活跃流计数 (泄漏测试用)
    /// 严格翻译自: pub var live_streams = std.atomic.Value(u32).init(0)
    public static var liveStreams: Int64 = 0

    /// 获取或创建 HTTP/3 客户端上下文
    /// 严格翻译自: ClientContext.getOrCreate
    public static func getOrCreateContext(): H3ClientContext {
        return H3ClientContext.getOrCreate()
    }

    /// 获取上下文 (可能为 None)
    /// 严格翻译自: ClientContext.get
    public static func getContext(): ?H3ClientContext {
        return H3ClientContext.get()
    }

    /// 连接到远端并排队请求
    /// 严格翻译自: ClientContext.connect
    public static func connect(client: H3ClientRef, hostname: String, port: Int64,
                                rejectUnauthorized: Bool): Bool {
        let ctx = getOrCreateContext()
        return ctx.connect(client, hostname, port, rejectUnauthorized)
    }

    /// 按 HTTP ID 中止请求
    /// 严格翻译自: ClientContext.abortByHttpId
    public static func abortByHttpId(asyncHttpId: Int64): Bool {
        return H3ClientContext.abortByHttpId(asyncHttpId)
    }

    /// 按 HTTP ID 流式传输请求体
    /// 严格翻译自: ClientContext.streamBodyByHttpId
    public static func streamBodyByHttpId(asyncHttpId: Int64, ended: Bool): Unit {
        H3ClientContext.streamBodyByHttpId(asyncHttpId, ended)
    }

    /// Alt-Svc 查找
    public static func lookupAltSvc(hostname: String, port: Int64): ?Int64 {
        let altSvc = H3AltSvc()
        return altSvc.lookup(hostname, port)
    }

    /// Alt-Svc 记录
    public static func recordAltSvc(hostname: String, port: Int64, fieldValue: String): Unit {
        let altSvc = H3AltSvc()
        altSvc.record(hostname, port, fieldValue)
    }
}
