// 严格翻译自: src/uws_sys/Loop.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: Loop.zig 中 extern fn
// ============================================================================
@C
foreign func us_create_loop(hint: CPointer<Unit>, wakeup_cb: CPointer<Unit>, pre_cb: CPointer<Unit>, post_cb: CPointer<Unit>, ext_size: UInt32): CPointer<Unit>
@C
foreign func us_loop_free(loop: CPointer<Unit>): Unit
@C
foreign func us_loop_ext(loop: CPointer<Unit>): CPointer<Unit>
@C
foreign func us_quic_loop_flush_if_pending(loop: CPointer<Unit>): Unit
@C
foreign func us_loop_run(loop: CPointer<Unit>): Unit
@C
foreign func us_loop_pump(loop: CPointer<Unit>): Unit
@C
foreign func us_wakeup_loop(loop: CPointer<Unit>): Unit
@C
foreign func us_loop_integrate(loop: CPointer<Unit>): Unit
@C
foreign func us_loop_iteration_number(loop: CPointer<Unit>): Int64
@C
foreign func uws_loop_addPostHandler(loop: CPointer<Unit>, ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func uws_loop_removePostHandler(loop: CPointer<Unit>, ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func uws_loop_addPreHandler(loop: CPointer<Unit>, ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func uws_loop_removePreHandler(loop: CPointer<Unit>, ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func us_loop_run_bun_tick(loop: CPointer<Unit>, timeoutMs: CPointer<Unit>): Unit
@C
foreign func us_internal_free_closed_sockets(loop: CPointer<Unit>): Unit
@C
foreign func us_loop_close_all_groups(loop: CPointer<Unit>): Int32
@C
foreign func uws_get_loop(): CPointer<Unit>
@C
foreign func uws_get_loop_with_native(native: CPointer<Unit>): CPointer<Unit>
@C
foreign func uws_loop_defer(loop: CPointer<Unit>, ctx: CPointer<Unit>, cb: CPointer<Unit>): Unit
@C
foreign func uws_res_clear_corked_socket(loop: CPointer<Unit>): Unit
@C
foreign func uws_loop_date_header_timer_update(loop: CPointer<Unit>): Unit

// ============================================================================
// PosixLoop - POSIX 事件循环
// 严格翻译自: Loop.zig PosixLoop = extern struct
// ============================================================================
public class PosixLoop {
    public var internal_loop_data: InternalLoopData = InternalLoopData()
    public var num_polls: Int32 = 0
    public var num_ready_polls: Int32 = 0
    public var current_ready_poll: Int32 = 0
    public var fd: Int32 = -1
    public var active: UInt32 = 0
    public var pending_wakeups: UInt32 = 0

    private var ptr: CPointer<Unit> = CPointer<Unit>.null

    public init() {}

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn uncork(this) void
    public func uncork(): Unit {
        if (ptr != CPointer<Unit>.null) {
            uws_res_clear_corked_socket(ptr)
        }
    }

    /// 对应 Bun: pub fn updateDate(this) void
    public func updateDate(): Unit {
        if (ptr != CPointer<Unit>.null) {
            uws_loop_date_header_timer_update(ptr)
        }
    }

    /// 对应 Bun: pub fn iterationNumber(this) u64
    public func iterationNumber(): UInt64 {
        if (ptr != CPointer<Unit>.null) {
            return UInt64(us_loop_iteration_number(ptr))
        }
        return UInt64(internal_loop_data.iteration_nr)
    }

    /// 对应 Bun: pub fn inc(this) void
    public func inc(): Unit {
        num_polls += 1
    }

    /// 对应 Bun: pub fn dec(this) void
    public func dec(): Unit {
        num_polls -= 1
    }

    /// 对应 Bun: pub fn ref(this) void
    public func ref(): Unit {
        num_polls += 1
        active += 1
    }

    /// 对应 Bun: pub fn unref(this) void
    public func unref(): Unit {
        num_polls -= 1
        active = active > 0 ? active - 1 : 0
    }

    /// 对应 Bun: pub fn isActive(this) bool
    public func isActive(): Bool {
        return active > 0
    }

    /// 对应 Bun: pub fn addActive(this, value) void
    public func addActive(value: UInt32): Unit {
        active = active +| value
    }

    /// 对应 Bun: pub fn subActive(this, value) void
    public func subActive(value: UInt32): Unit {
        active = active -| value
    }

    /// 对应 Bun: pub fn unrefCount(this, count) void
    public func unrefCount(count: Int32): Unit {
        num_polls -= count
        active = active -| UInt32(count)
    }

    /// 对应 Bun: pub fn get() *Loop
    public static func get(): CPointer<Unit> {
        return uws_get_loop()
    }

    /// 对应 Bun: pub fn drainQuicIfNecessary(this) void
    public func drainQuicIfNecessary(): Unit {
        if (internal_loop_data.quic_head == None) {
            return
        }
        if (ptr != CPointer<Unit>.null) {
            us_quic_loop_flush_if_pending(ptr)
        }
    }

    /// 对应 Bun: pub fn wakeup(this) void
    public func wakeup(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_wakeup_loop(ptr)
        }
    }

    /// 对应 Bun: pub const wake = wakeup
    public func wake(): Unit {
        wakeup()
    }

    /// 对应 Bun: pub fn tick(this) void
    public func tick(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_loop_run_bun_tick(ptr, CPointer<Unit>.null)
        }
    }

    /// 对应 Bun: pub fn tickWithoutIdle(this) void
    public func tickWithoutIdle(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_loop_run_bun_tick(ptr, CPointer<Unit>.null)
        }
    }

    /// 对应 Bun: pub fn drainClosedSockets(this) void
    public func drainClosedSockets(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_internal_free_closed_sockets(ptr)
        }
    }

    /// 对应 Bun: pub fn closeAllGroups(this) bool
    public func closeAllGroups(): Bool {
        if (ptr != CPointer<Unit>.null) {
            return us_loop_close_all_groups(ptr) != 0
        }
        return false
    }

    /// 对应 Bun: pub fn run(this) void
    public func run(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_loop_run(ptr)
        }
    }

    /// 对应 Bun: pub fn shouldEnableDateHeaderTimer(this) bool
    public func shouldEnableDateHeaderTimer(): Bool {
        return internal_loop_data.shouldEnableDateHeaderTimer()
    }

    /// 对应 Bun: pub fn deinit(this) void
    public func deinit(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_loop_free(ptr)
        }
    }
}

// ============================================================================
// WindowsLoop - Windows 事件循环
// 严格翻译自: Loop.zig WindowsLoop = extern struct
// ============================================================================
public class WindowsLoop {
    public var internal_loop_data: InternalLoopData = InternalLoopData()

    private var ptr: CPointer<Unit> = CPointer<Unit>.null

    public init() {}

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn shouldEnableDateHeaderTimer(this) bool
    public func shouldEnableDateHeaderTimer(): Bool {
        return internal_loop_data.shouldEnableDateHeaderTimer()
    }

    /// 对应 Bun: pub fn uncork(this) void
    public func uncork(): Unit {
        if (ptr != CPointer<Unit>.null) {
            uws_res_clear_corked_socket(ptr)
        }
    }

    /// 对应 Bun: pub fn get() *WindowsLoop
    public static func get(): CPointer<Unit> {
        return uws_get_loop()
    }

    /// 对应 Bun: pub fn wakeup(this) void
    public func wakeup(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_wakeup_loop(ptr)
        }
    }

    public func wake(): Unit {
        wakeup()
    }

    /// 对应 Bun: pub fn tickWithoutIdle(this) void
    public func tickWithoutIdle(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_loop_pump(ptr)
        }
    }

    /// 对应 Bun: pub fn drainQuicIfNecessary(this) void
    public func drainQuicIfNecessary(): Unit {
        if (internal_loop_data.quic_head == None) {
            return
        }
        if (ptr != CPointer<Unit>.null) {
            us_quic_loop_flush_if_pending(ptr)
        }
    }

    /// 对应 Bun: pub fn run(this) void
    public func run(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_loop_run(ptr)
        }
    }

    public func tick(): Unit {
        run()
    }

    public func drainClosedSockets(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_internal_free_closed_sockets(ptr)
        }
    }

    public func closeAllGroups(): Bool {
        if (ptr != CPointer<Unit>.null) {
            return us_loop_close_all_groups(ptr) != 0
        }
        return false
    }

    public func deinit(): Unit {
        if (ptr != CPointer<Unit>.null) {
            us_loop_free(ptr)
        }
    }
}

// ============================================================================
// Loop - 类型别名
// 严格翻译自: Loop.zig
//  pub const Loop = if (bun.Environment.isWindows) WindowsLoop else PosixLoop
// ============================================================================
public typealias Loop = PosixLoop
