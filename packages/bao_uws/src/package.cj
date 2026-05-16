// bao_uws - uWebSocket 高级包装层
// 严格翻译自: src/uws/lib.rs, src/uws/uws.zig
//   Bun 中此 crate 是 uws_sys 之上的高级包装，提供:
//   - ResponseKind: TCP/SSL/H3 响应类型枚举
//   - SocketAddress: 拥有所有权的套接字地址
//   - MaybeAnySocket: 可选的 TCP/TLS 套接字联合
//   - SSLWrapper: BoringSSL 包装器 (TLS 握手/读写/关闭)
//   - CloseCode/CloseKind: WebSocket 关闭码
//   - 常量: LIBUS_TIMEOUT_GRANULARITY, 压缩/解压掩码等
//   - Loop/InternalLoopData 扩展
//   - SocketContext/BunSocketContextOptions 重导出
//
// 在仓颉版本中，这些类型直接定义在此包中
// SSLWrapper 需要 BoringSSL FFI，当前提供类型骨架
package bao_uws

import bao_uws_sys.*
import bao_opaque.*

// ============================================================================
// ResponseKind - 响应类型枚举
// 严格翻译自: src/uws/lib.rs ResponseKind
//   #[repr(i32)] enum ResponseKind { Tcp = 0, Ssl = 1, H3 = 2 }
//   从 *mut c_void 恢复具体的 uWS 响应类型
// ============================================================================

/// 响应类型
/// 对应 Bun: ResponseKind - 标识 HTTP 响应的传输层
public enum ResponseKind {
    | Tcp   // 明文 TCP (HTTP)
    | Ssl   // TLS 加密 (HTTPS)
    | H3    // HTTP/3 (QUIC)
}

/// ResponseKind 工具方法
public extension ResponseKind {
    /// 从 SSL 和 HTTP3 标志构造
    /// 对应 Bun: ResponseKind::from(ssl, http3)
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
// 常量
// 严格翻译自: src/uws/lib.rs 常量定义
// ============================================================================

/// libusockets 超时粒度 (毫秒)
/// 对应 Bun: LIBUS_TIMEOUT_GRANULARITY: i32 = 4
public let LIBUS_TIMEOUT_GRANULARITY: Int64 = 4

/// libusockets 接收缓冲区填充
/// 对应 Bun: LIBUS_RECV_BUFFER_PADDING: i32 = 32
public let LIBUS_RECV_BUFFER_PADDING: Int64 = 32

/// libusockets 扩展对齐
/// 对应 Bun: LIBUS_EXT_ALIGNMENT: i32 = 16
public let LIBUS_EXT_ALIGNMENT: Int64 = 16

/// 压缩器掩码
/// 对应 Bun: _COMPRESSOR_MASK: i32 = 255
public let COMPRESSOR_MASK: Int64 = 255

/// 解压器掩码
/// 对应 Bun: _DECOMPRESSOR_MASK: i32 = 3840
public let DECOMPRESSOR_MASK: Int64 = 3840

/// 禁用压缩/解压
/// 对应 Bun: DISABLED: i32 = 0
public let DISABLED: Int64 = 0

/// 共享压缩器
/// 对应 Bun: SHARED_COMPRESSOR: i32 = 1
public let SHARED_COMPRESSOR: Int64 = 1

/// 共享解压器
/// 对应 Bun: SHARED_DECOMPRESSOR: i32 = 256
public let SHARED_DECOMPRESSOR: Int64 = 256

/// 专用解压器 (各种窗口大小)
public let DEDICATED_DECOMPRESSOR_32KB: Int64 = 3840
public let DEDICATED_DECOMPRESSOR_16KB: Int64 = 3584
public let DEDICATED_DECOMPRESSOR_8KB: Int64 = 3328
public let DEDICATED_DECOMPRESSOR_4KB: Int64 = 3072
public let DEDICATED_DECOMPRESSOR_2KB: Int64 = 2816
public let DEDICATED_DECOMPRESSOR_1KB: Int64 = 2560
public let DEDICATED_DECOMPRESSOR_512B: Int64 = 2304
public let DEDICATED_DECOMPRESSOR: Int64 = 3840

/// 专用压缩器 (各种内存级别)
public let DEDICATED_COMPRESSOR_3KB: Int64 = 145
public let DEDICATED_COMPRESSOR_4KB: Int64 = 146
public let DEDICATED_COMPRESSOR_8KB: Int64 = 163
public let DEDICATED_COMPRESSOR_16KB: Int64 = 180
public let DEDICATED_COMPRESSOR_32KB: Int64 = 197
public let DEDICATED_COMPRESSOR_64KB: Int64 = 214
public let DEDICATED_COMPRESSOR_128KB: Int64 = 231
public let DEDICATED_COMPRESSOR_256KB: Int64 = 248
public let DEDICATED_COMPRESSOR: Int64 = 248

// ============================================================================
// SocketAddress - 拥有所有权的套接字地址
// 严格翻译自: src/uws/lib.rs SocketAddress
//   pub struct SocketAddress { pub ip: Box<[u8]>, pub port: i32, pub is_ipv6: bool }
//   拥有 IP 地址数据的套接字地址，用于需要比 uws_res 生命周期更长的场景
// ============================================================================

/// 拥有所有权的套接字地址
/// 对应 Bun: uws::SocketAddress
/// 区别于 bao_uws_sys 中借用的 SocketAddress (零拷贝，绑定到 Response 生命周期)
public class SocketAddress {
    /// IP 地址字节
    public var ip: Array<UInt8>
    /// 端口号
    public var port: Int64
    /// 是否为 IPv6
    public var isIpv6: Bool

    public init() {
        this.ip = Array<UInt8>()
        this.port = 0
        this.isIpv6 = false
    }

    public init(ip: Array<UInt8>, port: Int64, isIpv6: Bool) {
        this.ip = ip
        this.port = port
        this.isIpv6 = isIpv6
    }

    /// 从 IP 字符串创建
    public init(ipStr: String, port: Int64, isIpv6: Bool) {
        this.ip = Array<UInt8>()
        for (c in ipStr) {
            this.ip.append(UInt8(c.value))
        }
        this.port = port
        this.isIpv6 = isIpv6
    }

    /// 获取 IP 字符串
    public func ipString(): String {
        return String.fromUtf8(ip)
    }

    /// 是否为 IPv4
    public func isIpv4(): Bool {
        return !isIpv6
    }
}

// ============================================================================
// MaybeAnySocket - 可选的 TCP/TLS 套接字
// 严格翻译自: src/uws/lib.rs MaybeAnySocket
//   pub enum MaybeAnySocket { Tcp(SocketTCP), Ssl(SocketTLS), None }
//   用于代理隧道 (ProxyTunnel, WebSocketProxyTunnel) 等场景
//   区别于 AnySocket (没有 None 变体)
// ============================================================================

/// 可选的 TCP/TLS 套接字
/// 对应 Bun: uws::MaybeAnySocket
/// 运行时标记的 TCP/TLS 套接字，带 None 变体表示无活跃套接字
public enum MaybeAnySocket {
    | Tcp    // TCP 套接字
    | Ssl    // TLS 套接字
    | None   // 无套接字
}

/// MaybeAnySocket 工具方法
public extension MaybeAnySocket {
    /// 是否已关闭
    public func isClosed(): Bool {
        match(this) {
            case None => true
            case _ => false
        }
    }

    /// 是否为 SSL
    public func isSsl(): Bool {
        match(this) {
            case Ssl => true
            case _ => false
        }
    }

    /// 是否为 TCP
    public func isTcp(): Bool {
        match(this) {
            case Tcp => true
            case _ => false
        }
    }

    /// 是否为 None
    public func isNone(): Bool {
        match(this) {
            case None => true
            case _ => false
        }
    }
}

// ============================================================================
// CloseCode - WebSocket 关闭码
// 严格翻译自: src/uws/lib.rs CloseCode / CloseKind
//   Bun 使用 CloseCode 作为规范名称，CloseKind 作为别名
//   #[repr(i32)] enum CloseCode { Normal, Failure, FastShutdown }
// ============================================================================

/// WebSocket 关闭码
/// 对应 Bun: uws::CloseCode (CloseKind 为别名)
public enum CloseCode {
    | Normal        // 正常关闭
    | Failure       // 异常关闭
    | FastShutdown  // 快速关闭 (不等待对端)
}

/// CloseKind 是 CloseCode 的别名
/// 对应 Bun: pub type CloseKind = CloseCode
public type CloseKind = CloseCode

// ============================================================================
// Opcode - WebSocket 帧操作码
// 严格翻译自: src/uws_sys/lib.rs Opcode
//   #[repr(transparent)] struct Opcode(pub i32)
//   WebSocket 帧类型: Continuation, Text, Binary, Close, Ping, Pong
// ============================================================================

/// WebSocket 帧操作码
/// 对应 Bun: uws_sys::Opcode / uWS::OpCode
public enum Opcode {
    | Continuation   // 帧延续
    | Text           // 文本帧
    | Binary         // 二进制帧
    | Close          // 关闭帧
    | Ping           // 心跳 Ping
    | Pong           // 心跳 Pong
}

/// Opcode 工具方法
public extension Opcode {
    /// 获取操作码数值
    /// 对应 Bun: Opcode(pub i32) 的原始值
    public func value(): Int64 {
        match(this) {
            case Continuation => 0
            case Text => 1
            case Binary => 2
            case Close => 8
            case Ping => 9
            case Pong => 10
        }
    }

    /// 从数值创建
    public static func fromValue(v: Int64): ?Opcode {
        match(v) {
            case 0 => Some(Opcode.Continuation)
            case 1 => Some(Opcode.Text)
            case 2 => Some(Opcode.Binary)
            case 8 => Some(Opcode.Close)
            case 9 => Some(Opcode.Ping)
            case 10 => Some(Opcode.Pong)
            case _ => None
        }
    }
}

// ============================================================================
// SendStatus - WebSocket 发送状态
// 严格翻译自: src/uws_sys/lib.rs SendStatus
//   #[repr(u32)] enum SendStatus { Backpressure = 0, Success = 1, Dropped = 2 }
// ============================================================================

/// WebSocket 发送状态
/// 对应 Bun: uws_sys::SendStatus
public enum SendStatus {
    | Backpressure   // 背压 (缓冲区满)
    | Success        // 发送成功
    | Dropped        // 数据丢弃
}

/// SendStatus 工具方法
public extension SendStatus {
    public func value(): Int64 {
        match(this) {
            case Backpressure => 0
            case Success => 1
            case Dropped => 2
        }
    }
}

// ============================================================================
// DispatchKind - 调度类型 (SocketKind 的别名)
// 严格翻译自: src/uws/lib.rs DispatchKind
//   pub type DispatchKind = SocketKind
//   Phase-A 端口中一些模块使用了 DispatchKind 名称
// ============================================================================

/// 调度类型
/// 对应 Bun: DispatchKind = SocketKind 的别名
public enum DispatchKind {
    | Tcp    // TCP 连接
    | Ssl    // TLS 连接
}

// ============================================================================
// SSLWrapper - BoringSSL 包装器
// 严格翻译自: src/uws/lib.rs ssl_wrapper 模块
//   SSLWrapper<T> 是 Bun 中 TLS 处理的核心类型
//   包装 BoringSSL 的 SSL/SSL_CTX/BIO，提供:
//   - 握手管理 (HandshakeState)
//   - 加密数据读写
//   - 关闭流程 (2-step shutdown)
//   - 重协商处理
//
//   在仓颉版本中，由于没有直接的 BoringSSL FFI 绑定，
//   提供类型骨架和状态机逻辑
// ============================================================================

/// TLS 握手状态
/// 对应 Bun: ssl_wrapper::HandshakeState
public enum HandshakeState {
    | HandshakePending                // 握手进行中
    | HandshakeCompleted              // 握手完成
    | HandshakeRenegotiationPending   // 重协商进行中
}

/// SSL 包装器标志位
/// 对应 Bun: ssl_wrapper::Flags (Cell<u8> 位域)
/// bits 0-1: handshake_state (u2)
/// bit  2:   received_ssl_shutdown
/// bit  3:   sent_ssl_shutdown
/// bit  4:   is_client
/// bit  5:   authorized
/// bit  6:   fatal_error
/// bit  7:   closed_notified
public class SSLFlags {
    private var bits: UInt8

    public init() {
        this.bits = UInt8(0)
    }

    // 位掩码
    private static let HANDSHAKE_MASK: UInt8 = UInt8(0x03)
    private static let RECEIVED_SSL_SHUTDOWN: UInt8 = UInt8(1) << UInt8(2)
    private static let SENT_SSL_SHUTDOWN: UInt8 = UInt8(1) << UInt8(3)
    private static let IS_CLIENT: UInt8 = UInt8(1) << UInt8(4)
    private static let AUTHORIZED: UInt8 = UInt8(1) << UInt8(5)
    private static let FATAL_ERROR: UInt8 = UInt8(1) << UInt8(6)
    private static let CLOSED_NOTIFIED: UInt8 = UInt8(1) << UInt8(7)

    /// 获取握手状态
    public func handshakeState(): HandshakeState {
        match(bits & SSLFlags.HANDSHAKE_MASK) {
            case UInt8(0) => HandshakeState.HandshakePending
            case UInt8(1) => HandshakeState.HandshakeCompleted
            case UInt8(2) => HandshakeState.HandshakeRenegotiationPending
            case _ => HandshakeState.HandshakePending
        }
    }

    /// 设置握手状态
    public func setHandshakeState(s: HandshakeState): Unit {
        let v: UInt8 = match(s) {
            case HandshakePending => UInt8(0)
            case HandshakeCompleted => UInt8(1)
            case HandshakeRenegotiationPending => UInt8(2)
        }
        bits = (bits & ~(SSLFlags.HANDSHAKE_MASK)) | v
    }

    /// 是否已接收 SSL 关闭
    public func receivedSslShutdown(): Bool {
        return (bits & SSLFlags.RECEIVED_SSL_SHUTDOWN) != UInt8(0)
    }
    public func setReceivedSslShutdown(v: Bool): Unit {
        if (v) { bits = bits | SSLFlags.RECEIVED_SSL_SHUTDOWN }
        else { bits = bits & ~(SSLFlags.RECEIVED_SSL_SHUTDOWN) }
    }

    /// 是否已发送 SSL 关闭
    public func sentSslShutdown(): Bool {
        return (bits & SSLFlags.SENT_SSL_SHUTDOWN) != UInt8(0)
    }
    public func setSentSslShutdown(v: Bool): Unit {
        if (v) { bits = bits | SSLFlags.SENT_SSL_SHUTDOWN }
        else { bits = bits & ~(SSLFlags.SENT_SSL_SHUTDOWN) }
    }

    /// 是否为客户端
    public func isClient(): Bool {
        return (bits & SSLFlags.IS_CLIENT) != UInt8(0)
    }
    public func setIsClient(v: Bool): Unit {
        if (v) { bits = bits | SSLFlags.IS_CLIENT }
        else { bits = bits & ~(SSLFlags.IS_CLIENT) }
    }

    /// 是否已授权
    public func authorized(): Bool {
        return (bits & SSLFlags.AUTHORIZED) != UInt8(0)
    }
    public func setAuthorized(v: Bool): Unit {
        if (v) { bits = bits | SSLFlags.AUTHORIZED }
        else { bits = bits & ~(SSLFlags.AUTHORIZED) }
    }

    /// 是否有致命错误
    public func fatalError(): Bool {
        return (bits & SSLFlags.FATAL_ERROR) != UInt8(0)
    }
    public func setFatalError(v: Bool): Unit {
        if (v) { bits = bits | SSLFlags.FATAL_ERROR }
        else { bits = bits & ~(SSLFlags.FATAL_ERROR) }
    }

    /// 是否已通知关闭
    public func closedNotified(): Bool {
        return (bits & SSLFlags.CLOSED_NOTIFIED) != UInt8(0)
    }
    public func setClosedNotified(v: Bool): Unit {
        if (v) { bits = bits | SSLFlags.CLOSED_NOTIFIED }
        else { bits = bits & ~(SSLFlags.CLOSED_NOTIFIED) }
    }
}

/// SSL 验证错误
/// 对应 Bun: us_bun_verify_error_t
public class VerifyError {
    public var errorNo: Int64
    public var code: String
    public var reason: String

    public init() {
        this.errorNo = 0
        this.code = ""
        this.reason = ""
    }

    public init(errorNo: Int64, code: String, reason: String) {
        this.errorNo = errorNo
        this.code = code
        this.reason = reason
    }

    /// 是否无错误
    public func isNone(): Bool {
        return errorNo == 0
    }
}

/// SSL 初始化错误
/// 对应 Bun: ssl_wrapper::InitError
public enum SSLInitError {
    | OutOfMemory      // 内存不足
    | InvalidOptions   // 无效 SSL 选项
}

/// SSL 写入数据错误
/// 对应 Bun: ssl_wrapper::WriteDataError
public enum SSLWriteDataError {
    | ConnectionClosed  // 连接已关闭
    | WantRead          // 需要读取
    | WantWrite         // 需要写入
}

/// SSL 包装器 (模板化)
/// 对应 Bun: ssl_wrapper::SSLWrapper<T: Copy>
/// T 是拥有套接字的类型 (HTTPClient, WebSocketProxyTunnel, UpgradedDuplex)
/// 在仓颉中，T 通过泛型参数表示
public class SSLWrapper<T> {
    /// 标志位
    public var flags: SSLFlags
    /// 是否有活跃的 SSL 连接
    public var hasSsl: Bool
    /// 是否有 SSL 上下文
    public var hasCtx: Bool
    /// 上下文对象 (持有者引用)
    public var ctx: ?T

    public init() {
        this.flags = SSLFlags()
        this.hasSsl = false
        this.hasCtx = false
        this.ctx = None
    }

    /// 是否已关闭或正在关闭
    /// 对应 Bun: SSLWrapper::is_shutdown
    public func isShutdown(): Bool {
        return flags.closedNotified() || flags.receivedSslShutdown() || flags.sentSslShutdown()
    }

    /// 是否完全关闭 (双向)
    /// 对应 Bun: SSLWrapper::is_closed
    public func isClosed(): Bool {
        return flags.receivedSslShutdown() && flags.sentSslShutdown()
    }

    /// 是否已授权
    /// 对应 Bun: SSLWrapper::is_authorized
    public func isAuthorized(): Bool {
        if (flags.handshakeState() == HandshakeState.HandshakeCompleted) {
            return flags.authorized()
        }
        return false
    }

    /// 关闭读取方向
    /// 对应 Bun: SSLWrapper::shutdown_read
    public func shutdownRead(): Unit {
        // 无法真正关闭 SSL 的读取方向
        // 只是忽略后续数据
    }

    /// 去初始化
    /// 对应 Bun: SSLWrapper::deinit
    public func deinit(): Unit {
        flags.setClosedNotified(true)
        hasSsl = false
        hasCtx = false
    }
}

// ============================================================================
// 线程退出回调
// 严格翻译自: src/uws/lib.rs on_thread_exit
//   pub fn on_thread_exit() { bun_clear_loop_at_thread_exit() }
//   清除线程局部循环指针
// ============================================================================

/// 线程退出回调
/// 对应 Bun: uws::on_thread_exit
/// 清除线程局部的 uWS 事件循环指针
public func onThreadExit(): Unit {
    // 在完整实现中，需要调用 foreign bun_clear_loop_at_thread_exit()
}

// ============================================================================
// 默认密码列表
// 严格翻译自: src/uws/lib.rs get_default_ciphers
//   pub fn get_default_ciphers() -> &'static ZStr
//   返回 uSockets 编译时的默认 TLS 密码列表
// ============================================================================

/// 获取默认 TLS 密码列表
/// 对应 Bun: uws::get_default_ciphers
public func getDefaultCiphers(): String {
    // 在完整实现中，需要调用 foreign us_get_default_ciphers()
    // 返回 BoringSSL 默认密码列表
    return "ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20"
}
