// 严格翻译自: src/uws_sys/us_socket_t.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: us_socket_t.zig 中 extern fn
// ============================================================================
@C
foreign func us_socket_get_native_handle(s: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_socket_local_port(s: CPointer<Unit>): Int32
@C
foreign func us_socket_remote_port(s: CPointer<Unit>): Int32
@C
foreign func us_socket_remote_address(s: CPointer<Unit>, buf: CPointer<UInt8>, length: CPointer<Int32>): Unit
@C
foreign func us_socket_local_address(s: CPointer<Unit>, buf: CPointer<UInt8>, length: CPointer<Int32>): Unit
@C
foreign func us_socket_timeout(s: CPointer<Unit>, seconds: UInt32): Unit
@C
foreign func us_socket_long_timeout(s: CPointer<Unit>, minutes: UInt32): Unit
@C
foreign func us_socket_nodelay(s: CPointer<Unit>, enable: Int32): Unit
@C
foreign func us_socket_keepalive(s: CPointer<Unit>, enable: Int32, delay: UInt32): Int32
@C
foreign func us_socket_ext(s: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_socket_group(s: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_socket_kind(s: CPointer<Unit>): UInt8
@C
foreign func us_socket_set_kind(s: CPointer<Unit>, kind: UInt8): Unit
@C
foreign func us_socket_set_ssl_raw_tap(s: CPointer<Unit>, enabled: Int32): Unit
@C
foreign func us_socket_is_tls(s: CPointer<Unit>): Int32
@C
foreign func us_socket_write(s: CPointer<Unit>, data: CPointer<UInt8>, length: Int32): Int32
@C
foreign func us_socket_ipc_write_fd(s: CPointer<Unit>, data: CPointer<UInt8>, length: Int32, fd: Int32): Int32
@C
foreign func us_socket_write2(s: CPointer<Unit>, header: CPointer<UInt8>, len: UIntNative, payload: CPointer<UInt8>, plen: UIntNative): Int32
@C
foreign func us_socket_raw_write(s: CPointer<Unit>, data: CPointer<UInt8>, length: Int32): Int32
@C
foreign func us_socket_flush(s: CPointer<Unit>): Unit
@C
foreign func us_socket_open(s: CPointer<Unit>, is_client: Int32, ip: CPointer<UInt8>, ip_length: Int32): CPointer<Unit>
@C
foreign func us_socket_pause(s: CPointer<Unit>): Unit
@C
foreign func us_socket_resume(s: CPointer<Unit>): Unit
@C
foreign func us_socket_close(s: CPointer<Unit>, code: Int32, reason: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_socket_shutdown(s: CPointer<Unit>): Unit
@C
foreign func us_socket_is_closed(s: CPointer<Unit>): Int32
@C
foreign func us_socket_shutdown_read(s: CPointer<Unit>): Unit
@C
foreign func us_socket_is_shut_down(s: CPointer<Unit>): Int32
@C
foreign func us_socket_sendfile_needs_more(s: CPointer<Unit>): Unit
@C
foreign func us_socket_get_fd(s: CPointer<Unit>): Int32
@C
foreign func us_socket_verify_error(s: CPointer<Unit>): UsBunVerifyError
@C
foreign func us_socket_get_error(s: CPointer<Unit>): Int32
@C
foreign func us_socket_is_established(s: CPointer<Unit>): Int32
@C
foreign func us_socket_adopt(s: CPointer<Unit>, group: CPointer<Unit>, kind: UInt8, old_ext_size: Int32, ext_size: Int32): CPointer<Unit>
@C
foreign func us_socket_adopt_tls(s: CPointer<Unit>, group: CPointer<Unit>, kind: UInt8, ssl_ctx: CPointer<Unit>, sni: CPointer<Int8>, old_ext_size: Int32, ext_size: Int32): CPointer<Unit>
@C
foreign func us_socket_start_tls_handshake(s: CPointer<Unit>): Unit

// ============================================================================
// UsSocket - 套接字
// 严格翻译自: us_socket_t.zig
//  Zig bindings for us_socket_t.
//  TLS is per-socket (s->ssl != NULL in C); there is no int ssl selector.
//  Dispatch is by kind() - see SocketKind and dispatch.zig.
// ============================================================================

/// 关闭代码
/// 对应 Bun: pub const CloseCode = enum(i32)
public enum CloseCode <: Int32 {
    normal = 0
    failure = 1
    fast_shutdown = 2
}

/// 对应 Bun: pub const us_socket_t = opaque
public class UsSocket {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn open(this, is_client, ip_addr) void
    public func open(isClient: Bool, ipAddr: ?CPointer<UInt8>, ipLen: Int32): Unit {
        if (let Some(ip) <- ipAddr) {
            us_socket_open(ptr, if (isClient) 1 else 0, ip, ipLen)
        } else {
            us_socket_open(ptr, if (isClient) 1 else 0, CPointer<UInt8>.null, 0)
        }
    }

    /// 对应 Bun: pub fn pause(this: *us_socket_t) void
    public func pause(): Unit {
        us_socket_pause(ptr)
    }

    /// 对应 Bun: pub fn @"resume"(this: *us_socket_t) void
    public func resume(): Unit {
        us_socket_resume(ptr)
    }

    /// 对应 Bun: pub fn close(this: *us_socket_t, code: CloseCode) void
    public func close(code: CloseCode): Unit {
        us_socket_close(ptr, Int32(code), CPointer<Unit>.null)
    }

    /// 对应 Bun: pub fn shutdown(this: *us_socket_t) void
    public func shutdown(): Unit {
        us_socket_shutdown(ptr)
    }

    /// 对应 Bun: pub fn shutdownRead(this: *us_socket_t) void
    public func shutdownRead(): Unit {
        us_socket_shutdown_read(ptr)
    }

    /// 对应 Bun: pub fn isClosed(this: *us_socket_t) bool
    public func isClosed(): Bool {
        return us_socket_is_closed(ptr) > 0
    }

    /// 对应 Bun: pub fn isShutdown(this: *us_socket_t) bool
    public func isShutdown(): Bool {
        return us_socket_is_shut_down(ptr) > 0
    }

    /// 对应 Bun: pub fn isTLS(this: *us_socket_t) bool
    public func isTLS(): Bool {
        return us_socket_is_tls(ptr) > 0
    }

    /// 对应 Bun: pub fn localPort(this: *us_socket_t) i32
    public func localPort(): Int32 {
        return us_socket_local_port(ptr)
    }

    /// 对应 Bun: pub fn remotePort(this: *us_socket_t) i32
    public func remotePort(): Int32 {
        return us_socket_remote_port(ptr)
    }

    /// 对应 Bun: pub fn localAddress(this: *us_socket_t, buf: []u8) ![]const u8
    public func localAddress(buf: Array<UInt8>): ?Array<UInt8> {
        var length: Int32 = Int32(buf.size)
        us_socket_local_address(ptr, CPointer<UInt8>.reinterpret(buf), CPointer<Int32>.reinterpret(length))
        if (length < 0) {
            return None
        }
        return buf[0..Int64(length)]
    }

    /// 对应 Bun: pub fn remoteAddress(this: *us_socket_t, buf: []u8) ![]const u8
    public func remoteAddress(buf: Array<UInt8>): ?Array<UInt8> {
        var length: Int32 = Int32(buf.size)
        us_socket_remote_address(ptr, CPointer<UInt8>.reinterpret(buf), CPointer<Int32>.reinterpret(length))
        if (length < 0) {
            return None
        }
        return buf[0..Int64(length)]
    }

    /// 对应 Bun: pub fn setTimeout(this: *us_socket_t, seconds: u32) void
    public func setTimeout(seconds: UInt32): Unit {
        us_socket_timeout(ptr, seconds)
    }

    /// 对应 Bun: pub fn setLongTimeout(this: *us_socket_t, minutes: u32) void
    public func setLongTimeout(minutes: UInt32): Unit {
        us_socket_long_timeout(ptr, minutes)
    }

    /// 对应 Bun: pub fn setNodelay(this: *us_socket_t, enabled: bool) void
    public func setNodelay(enabled: Bool): Unit {
        us_socket_nodelay(ptr, if (enabled) 1 else 0)
    }

    /// 对应 Bun: pub fn setKeepalive(this: *us_socket_t, enabled: bool, delay: u32) i32
    public func setKeepalive(enabled: Bool, delay: UInt32): Int32 {
        return us_socket_keepalive(ptr, if (enabled) 1 else 0, delay)
    }

    /// 对应 Bun: pub fn ssl(this: *us_socket_t) ?*BoringSSL.SSL
    public func ssl(): CPointer<Unit> {
        if (!isTLS()) {
            return CPointer<Unit>.null
        }
        return us_socket_get_native_handle(ptr)
    }

    /// 对应 Bun: pub fn getNativeHandle(this: *us_socket_t) ?*anyopaque
    public func getNativeHandle(): CPointer<Unit> {
        return us_socket_get_native_handle(ptr)
    }

    /// 对应 Bun: pub fn ext(this: *us_socket_t, comptime T: type) *T
    public func ext(): CPointer<Unit> {
        return us_socket_ext(ptr)
    }

    /// 对应 Bun: pub fn extPtr(this: *us_socket_t) [*]align(16) u8
    public func extPtr(): CPointer<Unit> {
        return us_socket_ext(ptr)
    }

    /// 对应 Bun: pub fn group(this: *us_socket_t) *SocketGroup
    public func group(): SocketGroup {
        return SocketGroup(us_socket_group(ptr))
    }

    /// 对应 Bun: pub const rawGroup = group
    public func rawGroup(): SocketGroup {
        return group()
    }

    /// 对应 Bun: pub fn kind(this: *us_socket_t) SocketKind
    public func kind(): SocketKind {
        return SocketKind(us_socket_kind(ptr))
    }

    /// 对应 Bun: pub fn setKind(this: *us_socket_t, k: SocketKind) void
    public func setKind(k: SocketKind): Unit {
        us_socket_set_kind(ptr, UInt8(k))
    }

    /// 对应 Bun: pub fn adopt(this, g, k, old_ext, new_ext) ?*us_socket_t
    public func adopt(g: SocketGroup, k: SocketKind, oldExt: Int32, newExt: Int32): ?UsSocket {
        let raw = us_socket_adopt(ptr, g.getPtr(), UInt8(k), oldExt, newExt)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(UsSocket(raw))
    }

    /// 对应 Bun: pub fn adoptTLS(this, g, k, ssl_ctx, sni, old_ext, new_ext) ?*us_socket_t
    public func adoptTLS(g: SocketGroup, k: SocketKind, sslCtx: CPointer<Unit>, sni: CPointer<Int8>, oldExt: Int32, newExt: Int32): ?UsSocket {
        let raw = us_socket_adopt_tls(ptr, g.getPtr(), UInt8(k), sslCtx, sni, oldExt, newExt)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(UsSocket(raw))
    }

    /// 对应 Bun: pub fn startTLSHandshake(this: *us_socket_t) void
    public func startTLSHandshake(): Unit {
        us_socket_start_tls_handshake(ptr)
    }

    /// 对应 Bun: pub fn setSslRawTap(this, enabled) void
    public func setSslRawTap(enabled: Bool): Unit {
        us_socket_set_ssl_raw_tap(ptr, if (enabled) 1 else 0)
    }

    /// 对应 Bun: pub fn write(this: *us_socket_t, data: []const u8) i32
    public func write(data: Array<UInt8>): Int32 {
        return us_socket_write(ptr, CPointer<UInt8>.reinterpret(data), Int32(data.size))
    }

    /// 对应 Bun: pub fn writeFd(this, data, file_descriptor) i32
    public func writeFd(data: Array<UInt8>, fileDescriptor: Int32): Int32 {
        return us_socket_ipc_write_fd(ptr, CPointer<UInt8>.reinterpret(data), Int32(data.size), fileDescriptor)
    }

    /// 对应 Bun: pub fn write2(this, first, second) i32
    public func write2(first: Array<UInt8>, second: Array<UInt8>): Int32 {
        return us_socket_write2(ptr, CPointer<UInt8>.reinterpret(first), UIntNative(first.size), CPointer<UInt8>.reinterpret(second), UIntNative(second.size))
    }

    /// 对应 Bun: pub fn rawWrite(this: *us_socket_t, data: []const u8) i32
    public func rawWrite(data: Array<UInt8>): Int32 {
        return us_socket_raw_write(ptr, CPointer<UInt8>.reinterpret(data), Int32(data.size))
    }

    /// 对应 Bun: pub fn flush(this: *us_socket_t) void
    public func flush(): Unit {
        us_socket_flush(ptr)
    }

    /// 对应 Bun: pub fn sendFileNeedsMore(this: *us_socket_t) void
    public func sendFileNeedsMore(): Unit {
        us_socket_sendfile_needs_more(ptr)
    }

    /// 对应 Bun: pub fn getFd(this: *us_socket_t) bun.FD
    public func getFd(): Int32 {
        return us_socket_get_fd(ptr)
    }

    /// 对应 Bun: pub fn getVerifyError(this: *us_socket_t) us_bun_verify_error_t
    public func getVerifyError(): UsBunVerifyError {
        return us_socket_verify_error(ptr)
    }

    /// 对应 Bun: pub fn getError(this: *us_socket_t) i32
    public func getError(): Int32 {
        return us_socket_get_error(ptr)
    }

    /// 对应 Bun: pub fn isEstablished(this: *us_socket_t) bool
    public func isEstablished(): Bool {
        return us_socket_is_established(ptr) > 0
    }
}

// ============================================================================
// UsBunVerifyError - TLS 验证错误
// 严格翻译自: us_socket_t.zig us_bun_verify_error_t
// ============================================================================
public class UsBunVerifyError {
    public var error_no: Int32 = 0
    public var code: Int32 = 0
    public var depth: Int32 = 0

    public init() {}
    public init(errorNo: Int32, code: Int32, depth: Int32) {
        this.error_no = errorNo
        this.code = code
        this.depth = depth
    }
}

// ============================================================================
// UsSocketStreamBuffer - 套接字流缓冲区
// 严格翻译自: us_socket_t.zig us_socket_stream_buffer_t
// ============================================================================
public class UsSocketStreamBuffer {
    public var list_ptr: ?CPointer<UInt8> = None
    public var list_cap: UIntNative = 0
    public var list_len: UIntNative = 0
    public var total_bytes_written: UIntNative = 0
    public var cursor: UIntNative = 0

    public init() {}

    /// 对应 Bun: pub fn wrote(this, written) void
    public func wrote(written: UIntNative): Unit {
        this.total_bytes_written = this.total_bytes_written +| written
    }
}
