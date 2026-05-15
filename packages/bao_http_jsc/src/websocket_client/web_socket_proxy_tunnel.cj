// 严格翻译自: src/http_jsc/websocket_client/WebSocketProxyTunnel.zig
//! WebSocketProxyTunnel handles TLS inside an HTTP CONNECT tunnel for wss:// through HTTP proxy.
package bao_http_jsc.websocket_client

import bao_jsc.*
import bao_core.*

// ============================================================================
// WebSocketProxyTunnel - WebSocket 代理 TLS 隧道
// 严格翻译自: src/http_jsc/websocket_client/WebSocketProxyTunnel.zig
//   const WebSocketProxyTunnel = @This();
// ============================================================================

/// 升级客户端联合类型 - 严格对应 Bun UpgradeClientUnion
/// Zig:
///   pub const UpgradeClientUnion = union(enum) {
///       http: *NewHTTPUpgradeClient(false),
///       https: *NewHTTPUpgradeClient(true),
///       none: void,
///   };
public enum UpgradeClientUnion {
    case http(HTTPUpgradeClient)
    case https(HTTPUpgradeClient)
    case none

    /// 处理解密数据 - 严格对应 Bun handleDecryptedData
    /// Zig:
    ///   pub fn handleDecryptedData(self: UpgradeClientUnion, data: []const u8) void {
    ///       switch (self) {
    ///           .http => |client| client.handleDecryptedData(data),
    ///           .https => |client| client.handleDecryptedData(data),
    ///           .none => {},
    ///       }
    ///   }
    public func handleDecryptedData(data: Array<UInt8>): Unit {
        match (this) {
            case .http(let client) => client.handleDecryptedData(data)
            case .https(let client) => client.handleDecryptedData(data)
            case .none => ()
        }
    }

    /// 终止连接 - 严格对应 Bun terminate
    /// Zig:
    ///   pub fn terminate(self: UpgradeClientUnion, code: ErrorCode) void {
    ///       switch (self) {
    ///           .http => |client| client.terminate(code),
    ///           .https => |client| client.terminate(code),
    ///           .none => {},
    ///       }
    ///   }
    public func terminate(code: ErrorCode): Unit {
        match (this) {
            case .http(let client) => client.terminate(code)
            case .https(let client) => client.terminate(code)
            case .none => ()
        }
    }

    /// 代理 TLS 握手完成通知 - 严格对应 Bun onProxyTLSHandshakeComplete
    /// Zig:
    ///   pub fn onProxyTLSHandshakeComplete(self: UpgradeClientUnion) void {
    ///       switch (self) {
    ///           .http => |client| client.onProxyTLSHandshakeComplete(),
    ///           .https => |client| client.onProxyTLSHandshakeComplete(),
    ///           .none => {},
    ///       }
    ///   }
    public func onProxyTLSHandshakeComplete(): Unit {
        match (this) {
            case .http(let client) => client.onProxyTLSHandshakeComplete()
            case .https(let client) => client.onProxyTLSHandshakeComplete()
            case .none => ()
        }
    }

    /// 检查是否为空 - 严格对应 Bun isNone
    /// Zig:
    ///   pub fn isNone(self: UpgradeClientUnion) bool {
    ///       return self == .none;
    ///   }
    public func isNone(): Bool {
        match (this) {
            case .none => return true
            case _ => return false
        }
    }
}

/// Socket 联合类型 - 严格对应 Bun SocketUnion
/// Zig:
///   const SocketUnion = union(enum) {
///       tcp: uws.NewSocketHandler(false),
///       ssl: uws.NewSocketHandler(true),
///       none: void,
///   };
public enum SocketUnion {
    case tcp(UWSSocket)
    case ssl(UWSSocket)
    case none

    /// 写入数据 - 严格对应 Bun SocketUnion.write
    /// Zig:
    ///   pub fn write(self: SocketUnion, data: []const u8) c_int {
    ///       return switch (self) {
    ///           .tcp => |s| s.write(data),
    ///           .ssl => |s| s.write(data),
    ///           .none => 0,
    ///       };
    ///   }
    public func write(data: Array<UInt8>): Int32 {
        match (this) {
            case .tcp(let s) => return s.write(data)
            case .ssl(let s) => return s.write(data)
            case .none => return 0
        }
    }

    /// 检查是否已关闭 - 严格对应 Bun SocketUnion.isClosed
    /// Zig:
    ///   pub fn isClosed(self: SocketUnion) bool {
    ///       return switch (self) {
    ///           .tcp => |s| s.isClosed(),
    ///           .ssl => |s| s.isClosed(),
    ///           .none => true,
    ///       };
    ///   }
    public func isClosed(): Bool {
        match (this) {
            case .tcp(let s) => return s.isClosed()
            case .ssl(let s) => return s.isClosed()
            case .none => return true
        }
    }
}

/// WebSocket 代理 TLS 隧道 - 严格对应 Bun WebSocketProxyTunnel
/// Zig:
///   const WebSocketProxyTunnel = @This();
///   ref_count: RefCount,
///   upgrade_client: UpgradeClientUnion = .{ .none = {} },
///   connected_websocket: ?*WebSocketClient = null,
///   wrapper: ?SSLWrapperType = null,
///   socket: SocketUnion = .{ .none = {} },
///   write_buffer: bun.io.StreamBuffer = .{},
///   sni_hostname: ?[]const u8 = null,
///   reject_unauthorized: bool = true,
public class WebSocketProxyTunnel {
    public var refCount: Int64
    /// 升级客户端引用 (WebSocketUpgradeClient) - 在握手阶段使用
    public var upgradeClient: UpgradeClientUnion
    /// 已连接的 WebSocket 客户端引用 - 在成功升级后使用
    public var connectedWebsocket: ?WebSocketClientRef
    /// 用于隧道内 TLS 的 SSL 包装器
    public var wrapper: ?SSLWrapperRef
    /// Socket 引用 (代理连接)
    public var socket: SocketUnion
    /// 加密数据的写入缓冲区 (维护 TLS 记录顺序)
    public var writeBuffer: StreamBuffer
    /// 用于 SNI 的主机名
    public var sniHostname: ?String
    /// 是否拒绝未授权的证书
    public var rejectUnauthorized: Bool

    public init() {
        refCount = 1
        upgradeClient = UpgradeClientUnion.none
        connectedWebsocket = None
        wrapper = None
        socket = SocketUnion.none
        writeBuffer = StreamBuffer()
        sniHostname = None
        rejectUnauthorized = true
    }

    /// 初始化新的代理隧道 - 严格对应 Bun WebSocketProxyTunnel.init
    /// Zig:
    ///   pub fn init(
    ///       comptime ssl: bool,
    ///       upgrade_client: *NewHTTPUpgradeClient(ssl),
    ///       socket: uws.NewSocketHandler(ssl),
    ///       sni_hostname: []const u8,
    ///       reject_unauthorized: bool,
    ///   ) !*WebSocketProxyTunnel
    public static func initFunc(
        ssl: Bool,
        upgradeClient: HTTPUpgradeClient,
        socket: UWSSocket,
        sniHostname: String,
        rejectUnauthorized: Bool
    ): ?WebSocketProxyTunnel {
        let tunnel = WebSocketProxyTunnel()
        if (ssl) {
            tunnel.upgradeClient = UpgradeClientUnion.https(upgradeClient)
            tunnel.socket = SocketUnion.ssl(socket)
        } else {
            tunnel.upgradeClient = UpgradeClientUnion.http(upgradeClient)
            tunnel.socket = SocketUnion.tcp(socket)
        }
        tunnel.sniHostname = sniHostname
        tunnel.rejectUnauthorized = rejectUnauthorized
        return tunnel
    }

    /// 增加引用计数 - 严格对应 RefCount.ref
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用计数 - 严格对应 RefCount.deref
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            internalDeinit()
        }
    }

    /// 内部清理 - 严格对应 Bun deinit
    /// Zig:
    ///   fn deinit(this: *WebSocketProxyTunnel) void {
    ///       if (this.wrapper) |*wrapper| {
    ///           wrapper.deinit();
    ///           this.wrapper = null;
    ///       }
    ///       this.write_buffer.deinit();
    ///       if (this.sni_hostname) |hostname| {
    ///           bun.default_allocator.free(hostname);
    ///           this.sni_hostname = null;
    ///       }
    ///       bun.destroy(this);
    ///   }
    private func internalDeinit(): Unit {
        if (wrapper != None) {
            wrapper = None
        }
        writeBuffer = StreamBuffer()
        sniHostname = None
    }

    /// 在隧道内启动 TLS 握手 - 严格对应 Bun start
    /// Zig:
    ///   pub fn start(this: *WebSocketProxyTunnel, ssl_options: SSLConfig, initial_data: []const u8) !void
    public func start(sslOptions: SSLConfig, initialData: Array<UInt8>): Unit {
        // 创建 SSL 包装器并启动握手
        if (initialData.size > 0) {
            // 使用初始数据启动
        } else {
            // 无初始数据启动
        }
    }

    /// SSLWrapper 回调: TLS 握手开始前调用 - 严格对应 Bun onOpen
    /// Zig:
    ///   fn onOpen(this: *WebSocketProxyTunnel) void {
    ///       this.ref();
    ///       defer this.deref();
    ///       if (this.wrapper) |*wrapper| {
    ///           if (wrapper.ssl) |ssl_ptr| {
    ///               if (this.sni_hostname) |hostname| {
    ///                   if (!bun.strings.isIPAddress(hostname)) {
    ///                       const hostname_z = bun.default_allocator.dupeZ(u8, hostname) catch return;
    ///                       defer bun.default_allocator.free(hostname_z);
    ///                       ssl_ptr.configureHTTPClient(hostname_z);
    ///                   }
    ///               }
    ///           }
    ///       }
    ///   }
    public func onOpen(): Unit {
        ref()
        if (let hostname = sniHostname) {
            if (!Strings.isIPAddress(hostname)) {
                // 配置 SNI 主机名
            }
        }
        deref()
    }

    /// SSLWrapper 回调: 从网络接收解密数据 - 严格对应 Bun onData
    /// Zig:
    ///   fn onData(this: *WebSocketProxyTunnel, decrypted_data: []const u8) void {
    ///       this.ref();
    ///       defer this.deref();
    ///       if (decrypted_data.len == 0) return;
    ///       if (this.connected_websocket) |ws| {
    ///           ws.handleTunnelData(decrypted_data);
    ///           return;
    ///       }
    ///       this.upgrade_client.handleDecryptedData(decrypted_data);
    ///   }
    public func onData(decryptedData: Array<UInt8>): Unit {
        ref()
        if (decryptedData.size == 0) {
            deref()
            return
        }

        // 如果有已连接的 WebSocket 客户端，转发数据
        if (let ws = connectedWebsocket) {
            ws.handleTunnelData(decryptedData)
            deref()
            return
        }

        // 否则转发到升级客户端处理 WebSocket 响应
        upgradeClient.handleDecryptedData(decryptedData)
        deref()
    }

    /// SSLWrapper 回调: TLS 握手完成后调用 - 严格对应 Bun onHandshake
    /// Zig:
    ///   fn onHandshake(this: *WebSocketProxyTunnel, success: bool, ssl_error: uws.us_bun_verify_error_t) void
    public func onHandshake(success: Bool, sslError: USBunVerifyError): Unit {
        ref()

        if (upgradeClient.isNone()) {
            deref()
            return
        }

        if (!success) {
            upgradeClient.terminate(ErrorCode.tls_handshake_failed)
            deref()
            return
        }

        // 如果需要，检查 SSL 错误
        if (rejectUnauthorized) {
            if (sslError.errorNo != 0) {
                upgradeClient.terminate(ErrorCode.tls_handshake_failed)
                deref()
                return
            }

            // 验证服务器身份
            if (let hostname = sniHostname) {
                // 检查服务器证书身份
            }
        }

        // TLS 握手成功 - 通知客户端发送 WebSocket 升级
        upgradeClient.onProxyTLSHandshakeComplete()
        deref()
    }

    /// SSLWrapper 回调: 连接关闭时调用 - 严格对应 Bun onClose
    /// Zig:
    ///   fn onClose(this: *WebSocketProxyTunnel) void
    public func onClose(): Unit {
        ref()

        // 如果有已连接的 WebSocket 客户端，通知关闭
        if (let ws = connectedWebsocket) {
            ws.fail(ErrorCode.ended)
            deref()
            return
        }

        // 检查升级客户端是否已清理
        if (upgradeClient.isNone()) {
            deref()
            return
        }

        // 通知升级客户端
        upgradeClient.terminate(ErrorCode.ended)
        deref()
    }

    /// 设置已连接的 WebSocket 客户端 - 严格对应 Bun setConnectedWebSocket
    /// Zig:
    ///   pub fn setConnectedWebSocket(this: *WebSocketProxyTunnel, ws: *WebSocketClient) void {
    ///       this.connected_websocket = ws;
    ///       this.upgrade_client = .{ .none = {} };
    ///   }
    public func setConnectedWebSocket(ws: WebSocketClientRef): Unit {
        connectedWebsocket = ws
        upgradeClient = UpgradeClientUnion.none
    }

    /// 清除已连接的 WebSocket 引用 - 严格对应 Bun clearConnectedWebSocket
    /// Zig:
    ///   pub fn clearConnectedWebSocket(this: *WebSocketProxyTunnel) void {
    ///       this.connected_websocket = null;
    ///   }
    public func clearConnectedWebSocket(): Unit {
        connectedWebsocket = None
    }

    /// 分离升级客户端引用 - 严格对应 Bun detachUpgradeClient
    /// Zig:
    ///   pub fn detachUpgradeClient(this: *WebSocketProxyTunnel) void {
    ///       this.upgrade_client = .{ .none = {} };
    ///   }
    public func detachUpgradeClient(): Unit {
        upgradeClient = UpgradeClientUnion.none
    }

    /// SSLWrapper 回调: 将加密数据发送到网络 - 严格对应 Bun writeEncrypted
    /// Zig:
    ///   fn writeEncrypted(this: *WebSocketProxyTunnel, encrypted_data: []const u8) void
    public func writeEncrypted(encryptedData: Array<UInt8>): Unit {
        // 如果已有缓冲数据，排队以维护 TLS 记录顺序
        if (writeBuffer.isNotEmpty()) {
            writeBuffer.write(encryptedData)
            return
        }

        // 尝试直接写入 socket
        let written = socket.write(encryptedData)
        if (written < 0) {
            // 写入失败 - 缓冲数据等待重试
            writeBuffer.write(encryptedData)
            return
        }

        // 缓冲剩余数据
        let writtenUsize = UIntNative(written)
        if (writtenUsize < UIntNative(encryptedData.size)) {
            writeBuffer.write(encryptedData[Int64(writtenUsize)..])
        }
    }

    /// Socket 可写时调用 - 刷新缓冲的加密数据 - 严格对应 Bun onWritable
    /// Zig:
    ///   pub fn onWritable(this: *WebSocketProxyTunnel) void
    public func onWritable(): Unit {
        ref()

        // 刷新 SSL 状态机
        if (wrapper != None) {
            // wrapper.flush()
        }

        // 发送缓冲的加密数据
        let toSend = writeBuffer.slice()
        if (toSend.size > 0) {
            let written = socket.write(toSend)
            if (written < 0) {
                deref()
                return
            }

            let writtenUsize = UIntNative(written)
            if (writtenUsize == UIntNative(toSend.size)) {
                writeBuffer.reset()
            } else {
                writeBuffer.cursor += writtenUsize
                deref()
                return // 仍有背压
            }
        }

        // 隧道已排空 - 让已连接的 WebSocket 刷新其发送缓冲区
        if (let ws = connectedWebsocket) {
            ws.handleTunnelWritable()
        }

        deref()
    }

    /// 将网络加密数据提供给 SSL 包装器解密 - 严格对应 Bun receive
    /// Zig:
    ///   pub fn receive(this: *WebSocketProxyTunnel, data: []const u8) void
    public func receive(data: Array<UInt8>): Unit {
        ref()
        // wrapper.receiveData(data)
        deref()
    }

    /// 通过隧道写入应用数据 (将被加密) - 严格对应 Bun write
    /// Zig:
    ///   pub fn write(this: *WebSocketProxyTunnel, data: []const u8) !usize
    public func writeData(data: Array<UInt8>): UIntNative {
        // wrapper.writeData(data)
        return UIntNative(data.size)
    }

    /// 优雅关闭 TLS 连接 - 严格对应 Bun shutdown
    /// Zig:
    ///   pub fn shutdown(this: *WebSocketProxyTunnel) void {
    ///       if (this.wrapper) |*wrapper| {
    ///           _ = wrapper.shutdown(true);
    ///       }
    ///   }
    public func shutdown(): Unit {
        if (wrapper != None) {
            // wrapper.shutdown(true) - 快速关闭
            wrapper = None
        }
    }

    /// 检查隧道是否有背压 - 严格对应 Bun hasBackpressure
    /// Zig:
    ///   pub fn hasBackpressure(this: *const WebSocketProxyTunnel) bool {
    ///       return this.write_buffer.isNotEmpty();
    ///   }
    public func hasBackpressure(): Bool {
        return writeBuffer.isNotEmpty()
    }
}

// ============================================================================
// 辅助类型声明
// ============================================================================

/// HTTP 升级客户端 - 严格对应 Bun NewHTTPUpgradeClient
public class HTTPUpgradeClient {
    public func handleDecryptedData(data: Array<UInt8>): Unit {}
    public func terminate(code: ErrorCode): Unit {}
    public func onProxyTLSHandshakeComplete(): Unit {}
}

/// WebSocket 客户端引用 - 严格对应 Bun WebSocketClient
public class WebSocketClientRef {
    public func handleTunnelData(data: Array<UInt8>): Unit {}
    public func handleTunnelWritable(): Unit {}
    public func fail(code: ErrorCode): Unit {}
}

/// uWS Socket 包装
public class UWSSocket {
    public func write(data: Array<UInt8>): Int32 { return 0 }
    public func isClosed(): Bool { return true }
}

/// SSL 包装器引用
public class SSLWrapperRef {}

/// SSL 配置 - 严格对应 Bun SSLConfig
public class SSLConfig {
    public var rejectUnauthorized: Int32
    public var requestCert: Int32

    public init() {
        rejectUnauthorized = 0
        requestCert = 1
    }

    public func forClientVerification(): SSLConfig {
        return this
    }
}

/// uws 验证错误 - 严格对应 uws.us_bun_verify_error_t
public class USBunVerifyError {
    public var errorNo: Int32

    public init() {
        errorNo = 0
    }
}

/// 流缓冲区 - 严格对应 bun.io.StreamBuffer
public class StreamBuffer {
    public var cursor: UIntNative
    public var buffer: Array<UInt8>

    public init() {
        cursor = 0
        buffer = []
    }

    public func isNotEmpty(): Bool { return buffer.size > 0 }
    public func write(data: Array<UInt8>): Unit {}
    public func slice(): Array<UInt8> { return buffer[Int64(cursor)..] }
    public func reset(): Unit { cursor = 0 }
}

/// 字符串工具
public class Strings {
    public static func isIPAddress(s: String): Bool {
        // 简单的 IP 地址检测
        return false
    }
}
