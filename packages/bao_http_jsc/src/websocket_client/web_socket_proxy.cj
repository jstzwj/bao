// 严格翻译自: src/http_jsc/websocket_client/WebSocketProxy.zig
//! WebSocketProxy encapsulates proxy state for WebSocket connections through HTTP/HTTPS proxies.
//! This struct holds only the fields needed after the initial CONNECT request.
package bao_http_jsc

import bao_jsc.*
import bao_core.*

// ============================================================================
// WebSocketProxy - WebSocket 代理状态
// 严格翻译自: src/http_jsc/websocket_client/WebSocketProxy.zig:1-71
//   const WebSocketProxy = @This();
// ============================================================================

/// WebSocket 代理状态 - 严格对应 Bun WebSocketProxy
/// 只保存初始 CONNECT 请求后需要的字段。
/// proxy_port、proxy_authorization、proxy_headers 等字段只在 connect() 期间使用，
/// 在构建 CONNECT 请求后立即释放。
public class WebSocketProxy {
    /// TLS 握手期间用于 SNI 的目标主机名
    public var targetHost: String

    /// 目标是否使用 TLS (wss://)
    public var targetIsHttps: Bool

    /// CONNECT 成功后要发送的 WebSocket 升级请求
    public var websocketRequestBuf: Array<UInt8>

    /// 用于 HTTP 代理中 wss:// 的 TLS 隧道
    public var tunnel: ?WebSocketProxyTunnel

    public init() {
        targetHost = ""
        targetIsHttps = false
        websocketRequestBuf = []
        tunnel = None
    }

    /// 初始化 WebSocket 代理 - 严格对应 Bun WebSocketProxy.init
    /// Zig:
    ///   pub fn init(
    ///       target_host: []const u8,
    ///       target_is_https: bool,
    ///       websocket_request_buf: []u8,
    ///   ) WebSocketProxy {
    ///       return .{
    ///           .target_host = target_host,
    ///           .target_is_https = target_is_https,
    ///           .websocket_request_buf = websocket_request_buf,
    ///       };
    ///   }
    public init(
        targetHost: String,
        targetIsHttps: Bool,
        websocketRequestBuf: Array<UInt8>
    ) {
        this.targetHost = targetHost
        this.targetIsHttps = targetIsHttps
        this.websocketRequestBuf = websocketRequestBuf
        this.tunnel = None
    }

    /// 获取 TLS 握手期间用于 SNI 的目标主机名 - 严格对应 Bun getTargetHost
    /// Zig:
    ///   pub fn getTargetHost(self: *const WebSocketProxy) []const u8 {
    ///       return self.target_host;
    ///   }
    public func getTargetHost(): String {
        return targetHost
    }

    /// 检查目标是否使用 HTTPS (wss://) - 严格对应 Bun isTargetHttps
    /// Zig:
    ///   pub fn isTargetHttps(self: *const WebSocketProxy) bool {
    ///       return self.target_is_https;
    ///   }
    public func isTargetHttps(): Bool {
        return targetIsHttps
    }

    /// 获取 HTTP 代理中 wss:// 的 TLS 隧道 - 严格对应 Bun getTunnel
    /// Zig:
    ///   pub fn getTunnel(self: *const WebSocketProxy) ?*WebSocketProxyTunnel {
    ///       return self.tunnel;
    ///   }
    public func getTunnel(): ?WebSocketProxyTunnel {
        return tunnel
    }

    /// 设置 TLS 隧道 - 严格对应 Bun setTunnel
    /// Zig:
    ///   pub fn setTunnel(self: *WebSocketProxy, new_tunnel: ?*WebSocketProxyTunnel) void {
    ///       self.tunnel = new_tunnel;
    ///   }
    public func setTunnel(newTunnel: ?WebSocketProxyTunnel): Unit {
        tunnel = newTunnel
    }

    /// 获取 WebSocket 请求缓冲区的所有权，清除内部引用 - 严格对应 Bun takeWebsocketRequestBuf
    /// Zig:
    ///   pub fn takeWebsocketRequestBuf(self: *WebSocketProxy) []u8 {
    ///       const buf = self.websocket_request_buf;
    ///       self.websocket_request_buf = &[_]u8{};
    ///       return buf;
    ///   }
    /// 调用者负责释放返回的缓冲区。
    public func takeWebsocketRequestBuf(): Array<UInt8> {
        let buf = websocketRequestBuf
        websocketRequestBuf = []
        return buf
    }

    /// 清理所有分配的资源 - 严格对应 Bun deinit
    /// Zig:
    ///   pub fn deinit(self: *WebSocketProxy) void {
    ///       bun.default_allocator.free(self.target_host);
    ///       if (self.websocket_request_buf.len > 0) {
    ///           bun.default_allocator.free(self.websocket_request_buf);
    ///       }
    ///       if (self.tunnel) |tunnel| {
    ///           self.tunnel = null;
    ///           tunnel.shutdown();
    ///           tunnel.deref();
    ///       }
    ///   }
    public func deinit(): Unit {
        targetHost = ""
        if (websocketRequestBuf.size > 0) {
            websocketRequestBuf = []
        }
        if (let t = tunnel) {
            tunnel = None
            t.shutdown()
            t.deref()
        }
    }
}

/// WebSocket 代理隧道 - 前向声明
/// 完整实现在 web_socket_proxy_tunnel.cj
public class WebSocketProxyTunnel {
    public var refCount: Int64

    public init() {
        refCount = 1
    }

    /// 增加引用计数
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用计数
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            internalDeinit()
        }
    }

    /// 关闭隧道
    public func shutdown(): Unit {}

    /// 内部清理
    private func internalDeinit(): Unit {}
}
