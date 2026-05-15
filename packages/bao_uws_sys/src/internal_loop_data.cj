// 严格翻译自: src/uws_sys/InternalLoopData.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// InternalLoopData - 内部循环数据
// 严格翻译自: InternalLoopData.zig
//  pub const InternalLoopData = extern struct { ... }
// ============================================================================
public class InternalLoopData {
    public var sweep_timer: ?CPointer<Unit> = None
    public var sweep_timer_count: Int32 = 0
    public var wakeup_async: ?CPointer<Unit> = None
    public var head: ?SocketGroup = None
    public var quic_head: ?CPointer<Unit> = None
    public var quic_next_tick_us: Int64 = 0
    public var quic_timer: ?CPointer<Unit> = None
    public var iterator: ?SocketGroup = None
    public var recv_buf: CPointer<UInt8> = CPointer<UInt8>.null
    public var send_buf: CPointer<UInt8> = CPointer<UInt8>.null
    public var ssl_data: ?CPointer<Unit> = None
    public var pre_cb: ?CPointer<Unit> = None
    public var post_cb: ?CPointer<Unit> = None
    public var closed_udp_head: ?CPointer<Unit> = None
    public var closed_head: ?UsSocket = None
    public var low_prio_head: ?UsSocket = None
    public var low_prio_budget: Int32 = 0
    public var dns_ready_head: ?ConnectingSocket = None
    public var closed_connecting_head: ?ConnectingSocket = None
    public var mutex: Int64 = 0
    public var parent_ptr: ?CPointer<Unit> = None
    public var parent_tag: Int8 = 0
    public var iteration_nr: UIntNative = 0
    public var jsc_vm: ?CPointer<Unit> = None
    public var tick_depth: Int32 = 0

    public init() {}

    /// 对应 Bun: pub const LIBUS_RECV_BUFFER_LENGTH = 524288
    public static let LIBUS_RECV_BUFFER_LENGTH: Int32 = 524288

    /// 对应 Bun: pub fn recvSlice(this) []u8
    public func recvSlice(): ?Array<UInt8> {
        // In real implementation would return slice from recv_buf
        return None
    }

    /// 对应 Bun: pub fn shouldEnableDateHeaderTimer(this) bool
    public func shouldEnableDateHeaderTimer(): Bool {
        return sweep_timer_count > 0
    }

    /// 对应 Bun: pub fn setParentEventLoop(this, parent) void
    public func setParentEventLoop(parent: CPointer<Unit>, tag: Int8): Unit {
        parent_ptr = parent
        parent_tag = tag
    }

    /// 对应 Bun: pub fn getParent(this) jsc.EventLoopHandle
    public func getParent(): CPointer<Unit> {
        return parent_ptr ?? CPointer<Unit>.null
    }
}
