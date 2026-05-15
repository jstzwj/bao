// 严格翻译自: src/uws_sys/vtable.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// VTable - 套接字虚函数表
// 严格翻译自: vtable.zig
//  Comptime us_socket_vtable_t generator. Given a Zig handler type and the
//  ext payload type, emits a single static-const VTable whose entries are
//  callconv(.c) trampolines that recover the typed ext from the raw socket
//  and forward.
//
//  This replaces NewSocketHandler.configure/unsafeConfigure/wrapTLS,
//  which did the same trampoline dance per-call at runtime via
//  us_socket_context_on_*. One handler type -> one vtable in .rodata.
//
//  Handler shape (any subset; missing methods -> vtable entry left null):
//    pub const Ext = *MySocket;
//    pub fn onOpen(ext, *us_socket_t, is_client: bool, ip: []const u8) void
//    pub fn onData(ext, *us_socket_t, data: []const u8) void
//    pub fn onWritable(ext, *us_socket_t) void
//    pub fn onClose(ext, *us_socket_t, code: i32, reason: ?*anyopaque) void
//    pub fn onTimeout(ext, *us_socket_t) void
//    pub fn onLongTimeout(ext, *us_socket_t) void
//    pub fn onEnd(ext, *us_socket_t) void
//    pub fn onFd(ext, *us_socket_t, fd: c_int) void
//    pub fn onConnectError(ext, *us_socket_t, code: i32) void
//    pub fn onConnectingError(*ConnectingSocket, code: i32) void
//    pub fn onHandshake(ext, *us_socket_t, ok: bool, err: us_bun_verify_error_t) void
// ============================================================================

/// 虚函数表条目定义
/// 对应 Bun: SocketGroup.VTable = extern struct { ... }
public class VTable {
    public var on_open: ?CPointer<Unit> = None
    public var on_data: ?CPointer<Unit> = None
    public var on_fd: ?CPointer<Unit> = None
    public var on_writable: ?CPointer<Unit> = None
    public var on_close: ?CPointer<Unit> = None
    public var on_timeout: ?CPointer<Unit> = None
    public var on_long_timeout: ?CPointer<Unit> = None
    public var on_end: ?CPointer<Unit> = None
    public var on_connect_error: ?CPointer<Unit> = None
    public var on_connecting_error: ?CPointer<Unit> = None
    public var on_handshake: ?CPointer<Unit> = None

    public init() {}
}
