// bao_safety - 线程锁 (单线程断言)
// 严格翻译自: bun/src/safety/ThreadLock.zig
//   pub const ThreadLock = @This();
//   pub fn initUnlocked, initLocked, initLockedIfNonComptime,
//        lock, unlock, assertLocked, lockOrAssert
//   pub const enabled = bun.Environment.ci_assert
//   const traces_enabled = bun.Environment.isDebug
package bao_safety

import bao_core.*

// ============================================================================
// ThreadLock - 线程锁 (单线程断言)
// 严格翻译自: bun/src/safety/ThreadLock.zig
//
//   Zig 原始逻辑:
//     const Self = @This();
//     owning_thread: if (enabled) Thread.Id else void,
//     locked_at: if (traces_enabled) StoredTrace else void = if (traces_enabled) StoredTrace.empty,
//
//     pub fn initUnlocked() Self:
//       return .{ .owning_thread = if (comptime enabled) invalid_thread_id }
//
//     pub fn initLocked() Self:
//       var self = Self.initUnlocked()
//       self.lock()
//       return self
//
//     pub fn initLockedIfNonComptime() Self:
//       return if (@inComptime()) .initUnlocked() else .initLocked()
//
//     pub fn lock(self: *Self) void:
//       if (comptime !enabled) return
//       const current = Thread.getCurrentId()
//       if (self.owning_thread != invalid_thread_id):
//         if (traces_enabled):
//           bun.Output.err("assertion failure", "`ThreadLock` was already locked here:", .{})
//           bun.crash_handler.dumpStackTrace(self.locked_at.trace(), ...)
//         std.debug.panic("tried to lock `ThreadLock` on thread {}, but was already locked by thread {}", ...)
//       self.owning_thread = current
//       if (traces_enabled):
//         self.locked_at = StoredTrace.capture(@returnAddress())
//
//     pub fn unlock(self: *Self) void:
//       if (comptime !enabled) return
//       self.assertLocked()
//       self.* = .initUnlocked()
//
//     pub fn assertLocked(self: *const Self) void:
//       if (comptime !enabled) return
//       bun.assertf(self.owning_thread != invalid_thread_id, "`ThreadLock` is not locked", .{})
//       const current = Thread.getCurrentId()
//       bun.assertf(self.owning_thread == current, "`ThreadLock` is locked by thread {}, not thread {}", ...)
//
//     pub fn lockOrAssert(self: *Self) void:
//       if (comptime !enabled) return
//       if (self.owning_thread == invalid_thread_id): self.lock()
//       else: self.assertLocked()
//
//     pub const enabled = bun.Environment.ci_assert
// ============================================================================

/// 线程锁 - 对应 Bun ThreadLock
/// 确保数据只被一个线程访问 (非互斥锁，是调试断言)
public class ThreadLock {
    /// 持有锁的线程 ID
    /// 对应: owning_thread: if (enabled) Thread.Id else void
    private var owningThread: Int64
    /// 是否启用
    /// 对应: pub const enabled = bun.Environment.ci_assert
    private var enabled: Bool

    public init() {
        owningThread = INVALID_THREAD_ID
        enabled = false
    }

    public init(enabled: Bool) {
        owningThread = INVALID_THREAD_ID
        this.enabled = enabled
    }

    /// 初始化为未锁定状态
    /// 对应: ThreadLock.initUnlocked()
    ///   return .{ .owning_thread = if (comptime enabled) invalid_thread_id }
    public static func initUnlocked(): ThreadLock {
        ThreadLock()
    }

    /// 初始化为已锁定状态
    /// 对应: ThreadLock.initLocked()
    ///   var self = Self.initUnlocked()
    ///   self.lock()
    ///   return self
    public static func initLocked(): ThreadLock {
        let lock = ThreadLock()
        lock.lock()
        lock
    }

    /// 初始化：编译时未锁定，运行时锁定
    /// 对应: ThreadLock.initLockedIfNonComptime()
    ///   return if (@inComptime()) .initUnlocked() else .initLocked()
    public static func initLockedIfNonComptime(): ThreadLock {
        // 仓颉没有 comptime 概念，默认返回已锁定状态
        initLocked()
    }

    /// 获取锁
    /// 对应: ThreadLock.lock()
    ///   如果已被其他线程持有则 panic
    public func lock(): Unit {
        if (!enabled) { return }
        let current = ThreadId.current()
        if (owningThread != INVALID_THREAD_ID) {
            panic("tried to lock ThreadLock on thread ${current}, but was already locked by thread ${owningThread}")
        }
        owningThread = current
    }

    /// 释放锁
    /// 对应: ThreadLock.unlock()
    ///   self.assertLocked()
    ///   self.* = .initUnlocked()
    public func unlock(): Unit {
        if (!enabled) { return }
        assertLocked()
        owningThread = INVALID_THREAD_ID
    }

    /// 断言当前线程持有锁
    /// 对应: ThreadLock.assertLocked()
    ///   bun.assertf(self.owning_thread != invalid_thread_id, "`ThreadLock` is not locked", .{})
    ///   bun.assertf(self.owning_thread == current, "`ThreadLock` is locked by thread {}, not thread {}", ...)
    public func assertLocked(): Unit {
        if (!enabled) { return }
        if (owningThread == INVALID_THREAD_ID) {
            panic("ThreadLock is not locked")
        }
        let current = ThreadId.current()
        if (owningThread != current) {
            panic("ThreadLock is locked by thread ${owningThread}, not thread ${current}")
        }
    }

    /// 获取锁或断言已持有
    /// 对应: ThreadLock.lockOrAssert()
    ///   如果未锁定则获取，如果已锁定则断言当前线程持有
    public func lockOrAssert(): Unit {
        if (!enabled) { return }
        if (owningThread == INVALID_THREAD_ID) {
            lock()
        } else {
            assertLocked()
        }
    }
}
