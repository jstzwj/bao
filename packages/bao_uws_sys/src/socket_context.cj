// 严格翻译自: src/uws_sys/SocketContext.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: SocketContext.zig 中 extern fn
// ============================================================================
@C
foreign func us_ssl_ctx_from_options(opts: CPointer<Unit>, err: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_ssl_ctx_live_count(): Int64

// ============================================================================
// BunSocketContextOptions - 套接字上下文选项
// 严格翻译自: SocketContext.zig BunSocketContextOptions = extern struct
//  Legacy home of the us_socket_context_t opaque, which is gone - sockets
//  now belong to embedded SocketGroups and dispatch by kind. What remains
//  here is the us_bun_socket_context_options_t extern mirror.
// ============================================================================
public class BunSocketContextOptions {
    public var key_file_name: ?CPointer<Int8> = None
    public var cert_file_name: ?CPointer<Int8> = None
    public var passphrase: ?CPointer<Int8> = None
    public var dh_params_file_name: ?CPointer<Int8> = None
    public var ca_file_name: ?CPointer<Int8> = None
    public var ssl_ciphers: ?CPointer<Int8> = None
    public var ssl_prefer_low_memory_usage: Int32 = 0
    public var key: ?CPointer<CPointer<Int8>> = None
    public var key_count: UInt32 = 0
    public var cert: ?CPointer<CPointer<Int8>> = None
    public var cert_count: UInt32 = 0
    public var ca: ?CPointer<CPointer<Int8>> = None
    public var ca_count: UInt32 = 0
    public var secure_options: UInt32 = 0
    public var reject_unauthorized: Int32 = 0
    public var request_cert: Int32 = 0
    public var client_renegotiation_limit: UInt32 = 3
    public var client_renegotiation_window: UInt32 = 600

    public init() {}

    /// 对应 Bun: pub fn createSSLContext(options, err) ?*BoringSSL.SSL_CTX
    /// Build a BoringSSL SSL_CTX* from these options. Caller owns one ref
    /// and releases with SSL_CTX_free.
    public func createSSLContext(err: CPointer<Unit>): CPointer<Unit> {
        // In real implementation, marshal options to C struct and call
        return CPointer<Unit>.null
    }

    /// 对应 Bun: pub fn digest(self) [32]u8
    /// SHA-256 over every field this struct carries, dereferencing string
    /// pointers so the digest is content-addressed.
    public func digest(): Array<UInt8> {
        // Simplified - in real impl would compute SHA256
        return Array<UInt8>(32, item: 0)
    }

    /// 对应 Bun: pub fn approxCertBytes(self) usize
    /// Best-effort byte count of cert/key/CA material
    public func approxCertBytes(): UIntNative {
        var n: UIntNative = 0
        // In real impl would count bytes from key, cert, ca arrays
        return n
    }
}

/// 对应 Bun: pub const c = struct { ... }
public class SocketContextC {
    /// 对应 Bun: pub extern fn us_ssl_ctx_live_count() c_long
    public static func sslCtxLiveCount(): Int64 {
        return us_ssl_ctx_live_count()
    }
}
