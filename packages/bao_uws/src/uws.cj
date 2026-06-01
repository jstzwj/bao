// 严格翻译自: src/uws/uws.zig
// uWS (micro WebSockets) 绑定 - WebSocket/HTTP 服务器核心类型

package bao_uws

import std.collection.*

// ============================================================================
// ResponseKind - 响应类型
// 严格翻译自: uws.zig:51-59
//   pub const ResponseKind = enum(i32) { tcp, ssl, h3 }
// ============================================================================

/// 响应传输类型
public enum ResponseKind {
    | Tcp  // 0
    | Ssl  // 1
    | H3   // 2

    public operator func == (rhs: ResponseKind): Bool {
        match (this) {
            case Tcp => match (rhs) { case Tcp => true; case _ => false }
            case Ssl => match (rhs) { case Ssl => true; case _ => false }
            case H3 => match (rhs) { case H3 => true; case _ => false }
        }
    }
    public operator func != (rhs: ResponseKind): Bool {
        !(this == rhs)
    }

    /// 从 SSL 和 HTTP3 标志构造 ResponseKind
    // 严格翻译自: uws.zig:56-58
    //   pub fn from(comptime ssl: bool, comptime http3: bool) ResponseKind {
    //       return if (http3) .h3 else if (ssl) .ssl else .tcp;
    //   }
    public static func from(ssl: Bool, http3: Bool): ResponseKind {
        if (http3) {
            return ResponseKind.H3
        }
        if (ssl) {
            return ResponseKind.Ssl
        }
        return ResponseKind.Tcp
    }
}

// ============================================================================
// 常量 - uWS/uSockets 常量
// 严格翻译自: uws.zig:61-94
// ============================================================================

/// uWS 常量
public class UWSConstants {
    /// 超时粒度 (毫秒)
    public static let LIBUS_TIMEOUT_GRANULARITY: Int32 = 4
    /// 接收缓冲区填充
    public static let LIBUS_RECV_BUFFER_PADDING: Int32 = 32
    /// 扩展对齐
    public static let LIBUS_EXT_ALIGNMENT: Int32 = 16

    /// 压缩器掩码
    public static let _COMPRESSOR_MASK: Int32 = 255
    /// 解压器掩码
    public static let _DECOMPRESSOR_MASK: Int32 = 3840
    /// 禁用压缩
    public static let DISABLED: Int32 = 0
    /// 共享压缩器
    public static let SHARED_COMPRESSOR: Int32 = 1
    /// 共享解压器
    public static let SHARED_DECOMPRESSOR: Int32 = 256
    /// 专用解压器 (32KB)
    public static let DEDICATED_DECOMPRESSOR: Int32 = 3840
    /// 专用压缩器 (256KB)
    public static let DEDICATED_COMPRESSOR: Int32 = 248

    // 监听标志
    public static let LIBUS_LISTEN_DEFAULT: Int32 = 0
    public static let LIBUS_LISTEN_EXCLUSIVE_PORT: Int32 = 1
    public static let LIBUS_SOCKET_ALLOW_HALF_OPEN: Int32 = 2
    public static let LIBUS_LISTEN_REUSE_PORT: Int32 = 4
    public static let LIBUS_SOCKET_IPV6_ONLY: Int32 = 8
    public static let LIBUS_LISTEN_REUSE_ADDR: Int32 = 16
}

// ============================================================================
// Opcode - WebSocket 操作码
// 严格翻译自: uws.zig:131-146
//   pub const Opcode = enum(i32) { continuation, text, binary, close, ping, pong, _ }
// ============================================================================

/// WebSocket 操作码
public enum Opcode {
    | Continuation  // 0
    | Text          // 1
    | Binary        // 2
    | Close         // 8
    | Ping          // 9
    | Pong          // 10

    public operator func == (rhs: Opcode): Bool {
        match (this) {
            case Continuation => match (rhs) { case Continuation => true; case _ => false }
            case Text => match (rhs) { case Text => true; case _ => false }
            case Binary => match (rhs) { case Binary => true; case _ => false }
            case Close => match (rhs) { case Close => true; case _ => false }
            case Ping => match (rhs) { case Ping => true; case _ => false }
            case Pong => match (rhs) { case Pong => true; case _ => false }
        }
    }
    public operator func != (rhs: Opcode): Bool {
        !(this == rhs)
    }
}

// ============================================================================
// SendStatus - 发送状态
// 严格翻译自: uws.zig:148-152
//   pub const SendStatus = enum(c_uint) { backpressure, success, dropped }
// ============================================================================

/// WebSocket 发送状态
public enum SendStatus {
    | Backpressure  // 0
    | Success       // 1
    | Dropped       // 2

    public operator func == (rhs: SendStatus): Bool {
        match (this) {
            case Backpressure => match (rhs) { case Backpressure => true; case _ => false }
            case Success => match (rhs) { case Success => true; case _ => false }
            case Dropped => match (rhs) { case Dropped => true; case _ => false }
        }
    }
    public operator func != (rhs: SendStatus): Bool {
        !(this == rhs)
    }
}

// ============================================================================
// create_bun_socket_error_t - Socket 创建错误
// 严格翻译自: uws.zig:97-115
// ============================================================================

/// Socket 创建错误类型
public enum CreateBunSocketError {
    | None
    | LoadCaFile
    | InvalidCaFile
    | InvalidCa
    | InvalidCiphers

    public operator func == (rhs: CreateBunSocketError): Bool {
        match (this) {
            case None => match (rhs) { case None => true; case _ => false }
            case LoadCaFile => match (rhs) { case LoadCaFile => true; case _ => false }
            case InvalidCaFile => match (rhs) { case InvalidCaFile => true; case _ => false }
            case InvalidCa => match (rhs) { case InvalidCa => true; case _ => false }
            case InvalidCiphers => match (rhs) { case InvalidCiphers => true; case _ => false }
        }
    }
    public operator func != (rhs: CreateBunSocketError): Bool {
        !(this == rhs)
    }
}

    /// 获取错误消息
    // 严格翻译自: uws.zig:104-111
    public func message(): ?String {
        match (this) {
            case None => None
            case LoadCaFile => "Failed to load CA file"
            case InvalidCaFile => "Invalid CA file"
            case InvalidCa => "Invalid CA"
            case InvalidCiphers => "Invalid ciphers"
        }
    }
}

// ============================================================================
// SocketAddress - 套接字地址
// 严格翻译自: uws.zig:125-129
//   pub const SocketAddress = struct { ip: []const u8, port: i32, is_ipv6: bool }
// ============================================================================

/// 套接字地址信息
public class SocketAddress {
    public var ip: String
    public var port: Int32
    public var isIpv6: Bool

    public init() {
        this.ip = ""
        this.port = 0
        this.isIpv6 = false
    }

    public init(ip: String, port: Int32, isIpv6: Bool) {
        this.ip = ip
        this.port = port
        this.isIpv6 = isIpv6
    }
}

// ============================================================================
// SubscriptionPushMessage - 订阅推送消息类型
// 严格翻译自: uws.zig:551-561
//   pub const SubscriptionPushMessage = enum(u2) { message, subscribe, unsubscribe }
// ============================================================================

/// 订阅推送消息类型
public enum SubscriptionPushMessage {
    | Message
    | Subscribe
    | Unsubscribe

    public operator func == (rhs: SubscriptionPushMessage): Bool {
        match (this) {
            case Message => match (rhs) { case Message => true; case _ => false }
            case Subscribe => match (rhs) { case Subscribe => true; case _ => false }
            case Unsubscribe => match (rhs) { case Unsubscribe => true; case _ => false }
        }
    }
    public operator func != (rhs: SubscriptionPushMessage): Bool {
        !(this == rhs)
    }

    /// 从字节解析
    public static func fromBytes(bytes: Array<UInt8>): ?SubscriptionPushMessage {
        let s = String.fromUtf8(bytes)
        match (s) {
            case "message" => SubscriptionPushMessage.Message
            case "subscribe" => SubscriptionPushMessage.Subscribe
            case "unsubscribe" => SubscriptionPushMessage.Unsubscribe
            case _ => None
        }
    }
}

// ============================================================================
// onThreadExit - 线程退出清理
// 严格翻译自: uws.zig:155-157
// ============================================================================

/// 线程退出时清理循环资源
// 严格翻译自: uws.zig:155-157
//   pub fn onThreadExit() void { bun_clear_loop_at_thread_exit(); }
public func onThreadExit(): Unit {
    // PORT NOTE: 需要调用 bun_clear_loop_at_thread_exit FFI
}
