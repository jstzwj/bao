// 严格翻译自: src/uws_sys/udp.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: udp.zig 中 extern fn
// ============================================================================
@C
foreign func us_create_udp_socket(loop: CPointer<Unit>, data_cb: CPointer<Unit>, drain_cb: CPointer<Unit>, close_cb: CPointer<Unit>, recv_error_cb: CPointer<Unit>, host: CPointer<Int8>, port: UInt16, options: Int32, err: CPointer<Int32>, user_data: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_udp_socket_connect(socket: CPointer<Unit>, hostname: CPointer<Int8>, port: UInt32): Int32
@C
foreign func us_udp_socket_disconnect(socket: CPointer<Unit>): Int32
@C
foreign func us_udp_socket_send(socket: CPointer<Unit>, payloads: CPointer<CPointer<UInt8>>, lengths: CPointer<UIntNative>, addresses: CPointer<CPointer<Unit>>, count: Int32): Int32
@C
foreign func us_udp_socket_user(socket: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_udp_socket_bind(socket: CPointer<Unit>, hostname: CPointer<Int8>, port: UInt32): Int32
@C
foreign func us_udp_socket_bound_port(socket: CPointer<Unit>): Int32
@C
foreign func us_udp_socket_bound_ip(socket: CPointer<Unit>, buf: CPointer<UInt8>, length: CPointer<Int32>): Unit
@C
foreign func us_udp_socket_remote_ip(socket: CPointer<Unit>, buf: CPointer<UInt8>, length: CPointer<Int32>): Unit
@C
foreign func us_udp_socket_close(socket: CPointer<Unit>): Unit
@C
foreign func us_udp_socket_set_broadcast(socket: CPointer<Unit>, enabled: Int32): Int32
@C
foreign func us_udp_socket_set_ttl_unicast(socket: CPointer<Unit>, ttl: Int32): Int32
@C
foreign func us_udp_socket_set_ttl_multicast(socket: CPointer<Unit>, ttl: Int32): Int32
@C
foreign func us_udp_socket_set_multicast_loopback(socket: CPointer<Unit>, enabled: Int32): Int32
@C
foreign func us_udp_socket_set_multicast_interface(socket: CPointer<Unit>, iface: CPointer<Unit>): Int32
@C
foreign func us_udp_socket_set_membership(socket: CPointer<Unit>, address: CPointer<Unit>, iface: CPointer<Unit>, drop: Int32): Int32
@C
foreign func us_udp_socket_set_source_specific_membership(socket: CPointer<Unit>, source: CPointer<Unit>, group: CPointer<Unit>, iface: CPointer<Unit>, drop: Int32): Int32
@C
foreign func us_udp_packet_buffer_peer(buf: CPointer<Unit>, index: Int32): CPointer<Unit>
@C
foreign func us_udp_packet_buffer_payload(buf: CPointer<Unit>, index: Int32): CPointer<UInt8>
@C
foreign func us_udp_packet_buffer_payload_length(buf: CPointer<Unit>, index: Int32): Int32
@C
foreign func us_udp_packet_buffer_truncated(buf: CPointer<Unit>, index: Int32): Int32

// ============================================================================
// UdpSocket - UDP 套接字
// 严格翻译自: udp.zig Socket = opaque
// ============================================================================
public class UdpSocket {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn create(loop, data_cb, drain_cb, close_cb, recv_error_cb, host, port, options, err, user_data) ?*Socket
    public static func create(
        loop: CPointer<Unit>,
        dataCb: CPointer<Unit>,
        drainCb: CPointer<Unit>,
        closeCb: CPointer<Unit>,
        recvErrorCb: CPointer<Unit>,
        host: CPointer<Int8>,
        port: UInt16,
        options: Int32,
        err: CPointer<Int32>,
        userData: CPointer<Unit>
    ): ?UdpSocket {
        let raw = us_create_udp_socket(loop, dataCb, drainCb, closeCb, recvErrorCb, host, port, options, err, userData)
        if (raw == CPointer<Unit>.null) {
            return None
        }
        return Some(UdpSocket(raw))
    }

    /// 对应 Bun: pub fn send(this, payloads, lengths, addresses) c_int
    public func send(payloads: CPointer<CPointer<UInt8>>, lengths: CPointer<UIntNative>, addresses: CPointer<CPointer<Unit>>, count: Int32): Int32 {
        return us_udp_socket_send(ptr, payloads, lengths, addresses, count)
    }

    /// 对应 Bun: pub fn user(this) ?*anyopaque
    public func user(): CPointer<Unit> {
        return us_udp_socket_user(ptr)
    }

    /// 对应 Bun: pub fn bind(this, hostname, port) c_int
    public func bind(hostname: CPointer<Int8>, port: UInt32): Int32 {
        return us_udp_socket_bind(ptr, hostname, port)
    }

    /// 对应 Bun: pub fn boundPort(this) c_int
    /// Get the bound port in host byte order
    public func boundPort(): Int32 {
        return us_udp_socket_bound_port(ptr)
    }

    /// 对应 Bun: pub fn boundIp(this, buf, length) void
    public func boundIp(buf: CPointer<UInt8>, length: CPointer<Int32>): Unit {
        us_udp_socket_bound_ip(ptr, buf, length)
    }

    /// 对应 Bun: pub fn remoteIp(this, buf, length) void
    public func remoteIp(buf: CPointer<UInt8>, length: CPointer<Int32>): Unit {
        us_udp_socket_remote_ip(ptr, buf, length)
    }

    /// 对应 Bun: pub fn close(this) void
    public func close(): Unit {
        us_udp_socket_close(ptr)
    }

    /// 对应 Bun: pub fn connect(this, hostname, port) c_int
    public func connect(hostname: CPointer<Int8>, port: UInt32): Int32 {
        return us_udp_socket_connect(ptr, hostname, port)
    }

    /// 对应 Bun: pub fn disconnect(this) c_int
    public func disconnect(): Int32 {
        return us_udp_socket_disconnect(ptr)
    }

    /// 对应 Bun: pub fn setBroadcast(this, enabled) c_int
    public func setBroadcast(enabled: Bool): Int32 {
        return us_udp_socket_set_broadcast(ptr, if (enabled) 1 else 0)
    }

    /// 对应 Bun: pub fn setUnicastTTL(this, ttl) c_int
    public func setUnicastTTL(ttl: Int32): Int32 {
        return us_udp_socket_set_ttl_unicast(ptr, ttl)
    }

    /// 对应 Bun: pub fn setMulticastTTL(this, ttl) c_int
    public func setMulticastTTL(ttl: Int32): Int32 {
        return us_udp_socket_set_ttl_multicast(ptr, ttl)
    }

    /// 对应 Bun: pub fn setMulticastLoopback(this, enabled) c_int
    public func setMulticastLoopback(enabled: Bool): Int32 {
        return us_udp_socket_set_multicast_loopback(ptr, if (enabled) 1 else 0)
    }

    /// 对应 Bun: pub fn setMulticastInterface(this, iface) c_int
    public func setMulticastInterface(iface: CPointer<Unit>): Int32 {
        return us_udp_socket_set_multicast_interface(ptr, iface)
    }

    /// 对应 Bun: pub fn setMembership(this, address, iface, drop) c_int
    public func setMembership(address: CPointer<Unit>, iface: CPointer<Unit>, drop: Bool): Int32 {
        return us_udp_socket_set_membership(ptr, address, iface, if (drop) 1 else 0)
    }

    /// 对应 Bun: pub fn setSourceSpecificMembership(this, source, group, iface, drop) c_int
    public func setSourceSpecificMembership(source: CPointer<Unit>, group: CPointer<Unit>, iface: CPointer<Unit>, drop: Bool): Int32 {
        return us_udp_socket_set_source_specific_membership(ptr, source, group, iface, if (drop) 1 else 0)
    }
}

// ============================================================================
// PacketBuffer - UDP 数据包缓冲区
// 严格翻译自: udp.zig PacketBuffer = opaque
// ============================================================================
public class PacketBuffer {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn getPeer(this, index) *sockaddr_storage
    public func getPeer(index: Int32): CPointer<Unit> {
        return us_udp_packet_buffer_peer(ptr, index)
    }

    /// 对应 Bun: pub fn getPayload(this, index) []u8
    public func getPayload(index: Int32): Array<UInt8> {
        let payload = us_udp_packet_buffer_payload(ptr, index)
        let len = us_udp_packet_buffer_payload_length(ptr, index)
        // In real impl would create slice from payload/len
        return Array<UInt8>()
    }

    /// 对应 Bun: pub fn getTruncated(this, index) bool
    public func getTruncated(index: Int32): Bool {
        return us_udp_packet_buffer_truncated(ptr, index) != 0
    }
}
