// 严格翻译自: src/uws_sys/ListenSocket.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: ListenSocket.zig 中 extern fn
// ============================================================================
@C
foreign func us_listen_socket_close(ls: CPointer<Unit>): Unit
@C
foreign func us_listen_socket_group(ls: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_listen_socket_ext(ls: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_listen_socket_get_fd(ls: CPointer<Unit>): Int32
@C
foreign func us_listen_socket_port(ls: CPointer<Unit>): Int32
@C
foreign func us_listen_socket_add_server_name(ls: CPointer<Unit>, hostname: CPointer<Int8>, ssl_ctx: CPointer<Unit>, user: CPointer<Unit>): Int32
@C
foreign func us_listen_socket_remove_server_name(ls: CPointer<Unit>, hostname: CPointer<Int8>): Unit
@C
foreign func us_listen_socket_find_server_name_userdata(ls: CPointer<Unit>, hostname: CPointer<Int8>): CPointer<Unit>
@C
foreign func us_listen_socket_on_server_name(ls: CPointer<Unit>, cb: CPointer<Unit>): Unit

// ============================================================================
// ListenSocket - 监听套接字
// 严格翻译自: ListenSocket.zig
// ============================================================================
public class ListenSocket {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn close(this: *ListenSocket) void
    public func close(): Unit {
        us_listen_socket_close(ptr)
    }

    /// 对应 Bun: pub fn getLocalAddress(this: *ListenSocket, buf: []u8) ![]const u8
    public func getLocalAddress(buf: Array<UInt8>): ?Array<UInt8> {
        let socket = getSocket()
        return socket.localAddress(buf)
    }

    /// 对应 Bun: pub fn getLocalPort(this: *ListenSocket) i32
    public func getLocalPort(): Int32 {
        return getSocket().localPort()
    }

    /// 对应 Bun: pub fn getSocket(this: *ListenSocket) *uws.us_socket_t
    public func getSocket(): UsSocket {
        return UsSocket(ptr)
    }

    /// 对应 Bun: pub fn socket(this: *ListenSocket, comptime is_ssl: bool) uws.NewSocketHandler(is_ssl)
    public func socket(isSsl: Bool): InternalSocket {
        return InternalSocket.fromConnected(getSocket())
    }

    /// 对应 Bun: pub fn group(this: *ListenSocket) *SocketGroup
    /// Group accepted sockets are linked into.
    public func group(): SocketGroup {
        return SocketGroup(us_listen_socket_group(ptr))
    }

    /// 对应 Bun: pub fn ext(this: *ListenSocket, comptime T: type) *T
    public func ext(): CPointer<Unit> {
        return us_listen_socket_ext(ptr)
    }

    /// 对应 Bun: pub fn fd(this: *ListenSocket) bun.FD
    public func fd(): Int32 {
        return us_listen_socket_get_fd(ptr)
    }

    /// 对应 Bun: pub fn addServerName(this: *ListenSocket, hostname, ssl_ctx, user) bool
    /// ssl_ctx is SSL_CTX_up_ref'd for the SNI node; the listener drops
    /// that ref on close / removeServerName. user is the per-domain handle
    /// findServerNameUserdata recovers.
    public func addServerName(hostname: CPointer<Int8>, sslCtx: CPointer<Unit>, user: CPointer<Unit>): Bool {
        return us_listen_socket_add_server_name(ptr, hostname, sslCtx, user) == 0
    }

    /// 对应 Bun: pub fn removeServerName(this: *ListenSocket, hostname) void
    public func removeServerName(hostname: CPointer<Int8>): Unit {
        us_listen_socket_remove_server_name(ptr, hostname)
    }

    /// 对应 Bun: pub fn findServerNameUserdata(this: *ListenSocket, comptime T, hostname) ?*T
    public func findServerNameUserdata(hostname: CPointer<Int8>): CPointer<Unit> {
        return us_listen_socket_find_server_name_userdata(ptr, hostname)
    }

    /// 对应 Bun: pub fn onServerName(this: *ListenSocket, cb) void
    public func onServerName(cb: CPointer<Unit>): Unit {
        us_listen_socket_on_server_name(ptr, cb)
    }
}
