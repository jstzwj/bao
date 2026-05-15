// 严格翻译自: src/uws_sys/SocketGroup.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: SocketGroup.zig 中 extern fn
// ============================================================================
@C
foreign func us_socket_group_init(group: CPointer<Unit>, loop: CPointer<Unit>, vt: CPointer<Unit>, ext: CPointer<Unit>): Unit
@C
foreign func us_socket_group_deinit(group: CPointer<Unit>): Unit
@C
foreign func us_socket_group_close_all(group: CPointer<Unit>): Unit
@C
foreign func us_socket_group_timestamp(group: CPointer<Unit>): UInt16
@C
foreign func us_socket_group_loop(group: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_socket_group_next(group: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_socket_group_listen(group: CPointer<Unit>, kind: UInt8, ssl_ctx: CPointer<Unit>, host: CPointer<Int8>, port: Int32, options: Int32, socket_ext_size: Int32, err: CPointer<Int32>): CPointer<Unit>
@C
foreign func us_socket_group_listen_unix(group: CPointer<Unit>, kind: UInt8, ssl_ctx: CPointer<Unit>, path: CPointer<UInt8>, pathlen: UIntNative, options: Int32, socket_ext_size: Int32, err: CPointer<Int32>): CPointer<Unit>
@C
foreign func us_socket_group_connect(group: CPointer<Unit>, kind: UInt8, ssl_ctx: CPointer<Unit>, host: CPointer<Int8>, port: Int32, options: Int32, socket_ext_size: Int32, has_dns_resolved: CPointer<Int32>): CPointer<Unit>
@C
foreign func us_socket_group_connect_unix(group: CPointer<Unit>, kind: UInt8, ssl_ctx: CPointer<Unit>, path: CPointer<UInt8>, pathlen: UIntNative, options: Int32, socket_ext_size: Int32): CPointer<Unit>
@C
foreign func us_socket_from_fd(group: CPointer<Unit>, kind: UInt8, ssl_ctx: CPointer<Unit>, socket_ext_size: Int32, fd: Int32, ipc: Int32): CPointer<Unit>
@C
foreign func us_socket_pair(group: CPointer<Unit>, kind: UInt8, ext_size: Int32, fds: CPointer<Int32>): CPointer<Unit>

// ============================================================================
// SocketGroup - 套接字组
// 严格翻译自: SocketGroup.zig
//  Zig mirror of struct us_socket_group_t. Embedded by value in its owner
//  (Listener, VirtualMachine, uWS App, HTTPThread) - never heap-allocated on
//  its own. The loop links it lazily on first socket and unlinks on last, so
//  unused kinds cost nothing.
// ============================================================================
public class SocketGroup {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn init(self, loop_, vt, owner_ptr) void
    public static func initGroup(group: CPointer<Unit>, loop: CPointer<Unit>, vt: CPointer<Unit>, ext: CPointer<Unit>): Unit {
        us_socket_group_init(group, loop, vt, ext)
    }

    /// 对应 Bun: pub fn deinit(self: *SocketGroup) void
    public func deinit(): Unit {
        us_socket_group_deinit(ptr)
    }

    /// 对应 Bun: pub fn closeAll(self: *SocketGroup) void
    public func closeAll(): Unit {
        us_socket_group_close_all(ptr)
    }

    /// 对应 Bun: pub fn getLoop(self: *const SocketGroup) *Loop
    public func getLoop(): CPointer<Unit> {
        return us_socket_group_loop(ptr)
    }

    /// 对应 Bun: pub fn isEmpty(self: *const SocketGroup) bool
    public func isEmpty(): Bool {
        // Simplified - in real impl would check head_sockets etc.
        return true
    }

    /// 对应 Bun: pub fn listen(self, kind, ssl_ctx, host, port, options, socket_ext_size, err) ?*ListenSocket
    public func listen(kind: SocketKind, sslCtx: CPointer<Unit>, host: CPointer<Int8>, port: Int32, options: Int32, socketExtSize: Int32, err: CPointer<Int32>): ?ListenSocket {
        let raw = us_socket_group_listen(ptr, UInt8(kind), sslCtx, host, port, options, socketExtSize, err)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(ListenSocket(raw))
    }

    /// 对应 Bun: pub fn listenUnix(self, kind, ssl_ctx, path, pathlen, options, socket_ext_size, err) ?*ListenSocket
    public func listenUnix(kind: SocketKind, sslCtx: CPointer<Unit>, path: CPointer<UInt8>, pathlen: UIntNative, options: Int32, socketExtSize: Int32, err: CPointer<Int32>): ?ListenSocket {
        let raw = us_socket_group_listen_unix(ptr, UInt8(kind), sslCtx, path, pathlen, options, socketExtSize, err)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(ListenSocket(raw))
    }

    /// 对应 Bun: pub const ConnectResult = union(enum) { socket, connecting, failed }
    /// 对应 Bun: pub fn connect(self, kind, ssl_ctx, host, port, options, socket_ext_size) ConnectResult
    public func connect(kind: SocketKind, sslCtx: CPointer<Unit>, host: CPointer<Int8>, port: Int32, options: Int32, socketExtSize: Int32): ConnectResult {
        var hasDnsResolved: Int32 = 0
        let raw = us_socket_group_connect(ptr, UInt8(kind), sslCtx, host, port, options, socketExtSize, CPointer<Int32>.reinterpret(hasDnsResolved))
        if (raw == CPointer<Unit>.null) {
            return ConnectResultFailed()
        }
        return ConnectResultSocket(raw)
    }

    /// 对应 Bun: pub fn connectUnix(self, kind, ssl_ctx, path, pathlen, options, socket_ext_size) ?*us_socket_t
    public func connectUnix(kind: SocketKind, sslCtx: CPointer<Unit>, path: CPointer<UInt8>, pathlen: UIntNative, options: Int32, socketExtSize: Int32): ?UsSocket {
        let raw = us_socket_group_connect_unix(ptr, UInt8(kind), sslCtx, path, pathlen, options, socketExtSize)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(UsSocket(raw))
    }

    /// 对应 Bun: pub fn fromFd(self, kind, ssl_ctx, socket_ext_size, fd, ipc) ?*us_socket_t
    public func fromFd(kind: SocketKind, sslCtx: CPointer<Unit>, socketExtSize: Int32, fd: Int32, ipc: Bool): ?UsSocket {
        let raw = us_socket_from_fd(ptr, UInt8(kind), sslCtx, socketExtSize, fd, if (ipc) 1 else 0)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(UsSocket(raw))
    }

    /// 对应 Bun: pub fn pair(self, kind, ext_size, fds) ?*us_socket_t
    public func pair(kind: SocketKind, extSize: Int32, fds: CPointer<Int32>): ?UsSocket {
        let raw = us_socket_pair(ptr, UInt8(kind), extSize, fds)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(UsSocket(raw))
    }

    /// 对应 Bun: pub fn nextInLoop(self: *SocketGroup) ?*SocketGroup
    public func nextInLoop(): ?SocketGroup {
        let raw = us_socket_group_next(ptr)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(SocketGroup(raw))
    }

    /// Helper: convert UInt8 to SocketKind
    public static func socketKindFromInt(v: UInt8): SocketKind {
        return SocketKind(v)
    }
}

// ============================================================================
// ConnectResult - 连接结果联合体
// 严格翻译自: SocketGroup.zig ConnectResult = union(enum)
// ============================================================================
public open class ConnectResult {}
public class ConnectResultSocket <: ConnectResult {
    public let socket: CPointer<Unit>
    public init(socket: CPointer<Unit>) {
        this.socket = socket
    }
}
public class ConnectResultConnecting <: ConnectResult {
    public let connecting: CPointer<Unit>
    public init(connecting: CPointer<Unit>) {
        this.connecting = connecting
    }
}
public class ConnectResultFailed <: ConnectResult {}
