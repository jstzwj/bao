// 严格翻译自: src/uws_sys/ConnectingSocket.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: ConnectingSocket.zig 中 extern fn
// ============================================================================
@C
foreign func us_connecting_socket_close(s: CPointer<Unit>): Unit
@C
foreign func us_connecting_socket_group(s: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_connecting_socket_kind(s: CPointer<Unit>): UInt8
@C
foreign func us_connecting_socket_ext(s: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_connecting_socket_get_error(s: CPointer<Unit>): Int32
@C
foreign func us_connecting_socket_get_native_handle(s: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_connecting_socket_is_closed(s: CPointer<Unit>): Int32
@C
foreign func us_connecting_socket_is_shut_down(s: CPointer<Unit>): Int32
@C
foreign func us_connecting_socket_long_timeout(s: CPointer<Unit>, seconds: UInt32): Unit
@C
foreign func us_connecting_socket_shutdown(s: CPointer<Unit>): Unit
@C
foreign func us_connecting_socket_shutdown_read(s: CPointer<Unit>): Unit
@C
foreign func us_connecting_socket_timeout(s: CPointer<Unit>, seconds: UInt32): Unit
@C
foreign func us_connecting_socket_get_loop(s: CPointer<Unit>): CPointer<Unit>

// ============================================================================
// ConnectingSocket - 连接中的套接字
// 严格翻译自: ConnectingSocket.zig
//  us_connecting_socket_t - a connect in flight (DNS / non-blocking
//  connect() / happy-eyeballs). No I/O is possible yet; on success the loop
//  promotes it to a us_socket_t and fires onOpen, on failure onConnectingError.
// ============================================================================
public class ConnectingSocket {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn close(this: *ConnectingSocket) void
    public func close(): Unit {
        us_connecting_socket_close(ptr)
    }

    /// 对应 Bun: pub fn group(this: *ConnectingSocket) *SocketGroup
    public func group(): SocketGroup {
        return SocketGroup(us_connecting_socket_group(ptr))
    }

    /// 对应 Bun: pub const rawGroup = group
    public func rawGroup(): SocketGroup {
        return group()
    }

    /// 对应 Bun: pub fn kind(this: *ConnectingSocket) SocketKind
    public func kind(): SocketKind {
        return SocketGroup.socketKindFromInt(us_connecting_socket_kind(ptr))
    }

    /// 对应 Bun: pub fn ext(this: *ConnectingSocket, comptime T: type) *T
    public func ext(): CPointer<Unit> {
        return us_connecting_socket_ext(ptr)
    }

    /// 对应 Bun: pub fn getError(this: *ConnectingSocket) i32
    public func getError(): Int32 {
        return us_connecting_socket_get_error(ptr)
    }

    /// 对应 Bun: pub fn getNativeHandle(this: *ConnectingSocket) ?*anyopaque
    public func getNativeHandle(): CPointer<Unit> {
        return us_connecting_socket_get_native_handle(ptr)
    }

    /// 对应 Bun: pub fn isClosed(this: *ConnectingSocket) bool
    public func isClosed(): Bool {
        return us_connecting_socket_is_closed(ptr) == 1
    }

    /// 对应 Bun: pub fn isShutdown(this: *ConnectingSocket) bool
    public func isShutdown(): Bool {
        return us_connecting_socket_is_shut_down(ptr) == 1
    }

    /// 对应 Bun: pub fn longTimeout(this: *ConnectingSocket, seconds: c_uint) void
    public func longTimeout(seconds: UInt32): Unit {
        us_connecting_socket_long_timeout(ptr, seconds)
    }

    /// 对应 Bun: pub fn shutdown(this: *ConnectingSocket) void
    public func shutdown(): Unit {
        us_connecting_socket_shutdown(ptr)
    }

    /// 对应 Bun: pub fn shutdownRead(this: *ConnectingSocket) void
    public func shutdownRead(): Unit {
        us_connecting_socket_shutdown_read(ptr)
    }

    /// 对应 Bun: pub fn timeout(this: *ConnectingSocket, seconds: c_uint) void
    public func timeout(seconds: UInt32): Unit {
        us_connecting_socket_timeout(ptr, seconds)
    }

    /// 对应 Bun: pub fn loop(this: *ConnectingSocket) *uws.Loop
    public func loop_(): CPointer<Unit> {
        return us_connecting_socket_get_loop(ptr)
    }
}
