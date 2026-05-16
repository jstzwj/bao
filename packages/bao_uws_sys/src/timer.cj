// 严格翻译自: src/uws_sys/Timer.zig
package bao_uws_sys

import bao_sys.*

// ============================================================================
// C FFI 声明
// 严格翻译自: Timer.zig 中 extern fn
// ============================================================================
@C
foreign func us_create_timer(loop: CPointer<Unit>, fallthrough: Int32, ext_size: UInt32): CPointer<Unit>
@C
foreign func us_timer_ext(timer: CPointer<Unit>): CPointer<CPointer<Unit>>
@C
foreign func us_timer_close(timer: CPointer<Unit>, fallthrough: Int32): Unit
@C
foreign func us_timer_set(timer: CPointer<Unit>, cb: CPointer<Unit>, ms: Int32, repeat_ms: Int32): Unit
@C
foreign func us_timer_loop(t: CPointer<Unit>): CPointer<Unit>

// ============================================================================
// Timer - 定时器
// 严格翻译自: Timer.zig
//  DEPRECATED - DO NOT USE IN NEW CODE.getOrThrow()
//  Use JSC.EventLoopTimer instead.
//  This code will be deleted eventually! It is very inefficient on POSIX.
//  On Linux, it holds an entire file descriptor for every single timer.
//  On macOS, it's several system calls.
// ============================================================================
public class Timer {
    private var ptr: CPointer<Unit>

    public init(ptr: CPointer<Unit>) {
        this.ptr = ptr
    }

    public func getPtr(): CPointer<Unit> {
        return ptr
    }

    /// 对应 Bun: pub fn create(loop: *Loop, ptr: anytype) *Timer
    public static func create(loop: CPointer<Unit>, extSize: UInt32): Timer {
        let raw = us_create_timer(loop, 0, extSize)
        if (raw == CPointer<Unit>.null) {
            panic("us_create_timer: returned null")
        }
        return Timer(raw)
    }

    /// 对应 Bun: pub fn createFallthrough(loop: *Loop, ptr: anytype) *Timer
    public static func createFallthrough(loop: CPointer<Unit>, extSize: UInt32): Timer {
        let raw = us_create_timer(loop, 1, extSize)
        if (raw == CPointer<Unit>.null) {
            panic("us_create_timer: returned null")
        }
        return Timer(raw)
    }

    /// 对应 Bun: pub fn set(this: *Timer, ptr: anytype, cb, ms, repeat_ms) void
    public func set(cb: CPointer<Unit>, ms: Int32, repeatMs: Int32): Unit {
        us_timer_set(ptr, cb, ms, repeatMs)
    }

    /// 对应 Bun: pub fn deinit(this: *Timer, comptime fallthrough: bool) void
    public func deinit(fallthrough: Bool): Unit {
        us_timer_close(ptr, if (fallthrough) 1 else 0)
    }

    /// 对应 Bun: pub fn ext(this: *Timer, comptime Type: type) ?*Type
    public func ext(): CPointer<CPointer<Unit>> {
        return us_timer_ext(ptr)
    }
}
