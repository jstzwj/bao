// 严格翻译自: src/uws_sys/lib.rs, src/uws_sys/*.rs
// bao_uws_sys - uWebSocket 系统绑定 (严格 1:1 翻译)
//  此包提供对 Bun 的 uWebSockets C 层的 Cangjie 绑定。
//  包含:
//  - App (HTTP/WebSocket 应用)
//  - Request / Response (HTTP 请求/响应)
//  - WebSocket (WebSocket 连接)
//  - Loop (事件循环)
//  - Socket / SocketGroup / SocketKind (套接字管理)
//  - Timer (定时器)
//  - UDP (UDP 套接字)
//  - H3 (HTTP/3 支持)
//  - QUIC (QUIC 传输)
//  - BodyReaderMixin (请求体读取混入)
//  - ListenSocket (监听套接字)
//  - InternalLoopData (内部循环数据)
//  - SocketContext (套接字上下文)
//  - ConnectingSocket (连接中套接字)
//  - VTable (虚函数表)
//  - Thunk (回调 thunk)
//
// 模块映射 (严格翻译自 Bun uws_sys/lib.rs):
//   App.rs             -> app.cj
//   BodyReaderMixin.rs -> body_reader_mixin.cj
//   ConnectingSocket.rs -> connecting_socket.cj
//   h3.rs              -> h3.cj
//   InternalLoopData.rs -> internal_loop_data.cj
//   ListenSocket.rs    -> listen_socket.cj
//   Loop.rs            -> loop.cj
//   quic.rs            -> quic.cj
//   Request.rs         -> request.cj
//   Response.rs        -> response.cj
//   SocketContext.rs   -> socket_context.cj
//   SocketGroup.rs     -> socket_group.cj
//   SocketKind.rs      -> socket_kind.cj
//   thunk.rs           -> thunk.cj (如需)
//   Timer.rs           -> timer.cj
//   udp.rs             -> udp.cj
//   us_socket_t.rs     -> us_socket_t.cj
//   vtable.rs          -> vtable.cj
//   WebSocket.rs       -> web_socket.cj
//   socket.rs          -> socket.cj
package bao_uws_sys

// ============================================================================
// crate-root FFI 原始类型
// 严格翻译自: src/uws_sys/lib.rs crate-root FFI primitives
// ============================================================================

/// LIBUS_SOCKET_DESCRIPTOR
/// 对应 Bun: pub type LIBUS_SOCKET_DESCRIPTOR = c_int (POSIX) / usize (Windows)
/// 仓颉中使用 Int64 统一表示
public type LibusSocketDescriptor = Int64

// ============================================================================
// libusockets 监听/连接选项标志
// 严格翻译自: src/uws_sys/lib.rs LIBUS_LISTEN_* 常量
//   pub const LIBUS_LISTEN_DEFAULT: c_int = 0;
//   ...
// ============================================================================

/// 默认监听选项
public let LIBUS_LISTEN_DEFAULT: Int64 = 0
/// 独占端口
public let LIBUS_LISTEN_EXCLUSIVE_PORT: Int64 = 1
/// 允许半关闭
public let LIBUS_SOCKET_ALLOW_HALF_OPEN: Int64 = 2
/// 复用端口
public let LIBUS_LISTEN_REUSE_PORT: Int64 = 4
/// 仅 IPv6
public let LIBUS_SOCKET_IPV6_ONLY: Int64 = 8
/// 复用地址
public let LIBUS_LISTEN_REUSE_ADDR: Int64 = 16
/// 禁止复用端口失败
public let LIBUS_LISTEN_DISALLOW_REUSE_PORT_FAILURE: Int64 = 32

// ============================================================================
// us_bun_verify_error_t - TLS 握手验证结果
// 严格翻译自: src/uws_sys/lib.rs us_bun_verify_error_t
//   #[repr(C)] struct { error_no: c_int, code: *const c_char, reason: *const c_char }
// ============================================================================

/// TLS 验证错误
/// 对应 Bun: us_bun_verify_error_t
public class UsBunVerifyError {
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

    /// 无错误
    public static func none(): UsBunVerifyError {
        return UsBunVerifyError()
    }
}

// ============================================================================
// create_bun_socket_error_t - SSL 上下文创建错误
// 严格翻译自: src/uws_sys/lib.rs create_bun_socket_error_t
//   #[repr(C)] enum { none = 0, load_ca_file, invalid_ca_file, invalid_ca, invalid_ciphers }
// ============================================================================

/// SSL 上下文创建错误
/// 对应 Bun: create_bun_socket_error_t
public enum CreateBunSocketError {
    | None              // 无错误
    | LoadCaFile        // CA 文件加载失败
    | InvalidCaFile     // 无效 CA 文件
    | InvalidCa         // 无效 CA
    | InvalidCiphers    // 无效密码套件
}

/// CreateBunSocketError 工具方法
public extension CreateBunSocketError {
    /// 获取错误消息
    /// 对应 Bun: create_bun_socket_error_t::message
    public func message(): ?String {
        match(this) {
            case None => None
            case LoadCaFile => "Failed to load CA file"
            case InvalidCaFile => "Invalid CA file"
            case InvalidCa => "Invalid CA"
            case InvalidCiphers => "Invalid ciphers"
        }
    }

    /// 获取数值
    public func value(): Int64 {
        match(this) {
            case None => 0
            case LoadCaFile => 1
            case InvalidCaFile => 2
            case InvalidCa => 3
            case InvalidCiphers => 4
        }
    }
}
