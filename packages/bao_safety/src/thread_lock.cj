// bao_safety - 线程锁 (单线程断言)
// 严格翻译自: bun/src/safety/ThreadLock.rs (re-export of bun_core::ThreadLock)
//   pub use bun_core::{ThreadLock, ThreadLockGuard};
//   pub(crate) const ENABLED: bool = cfg!(feature = "ci_assert");
//   Zig: bun/src/safety/ThreadLock.zig
//     pub const ThreadLock = @This();
//     pub fn initUnlocked, initLocked, initLockedIfNonComptime,
//          lock, unlock, assertLocked, lockOrAssert
package bao_safety

import bao_threading.*
import bao_crash_handler.*

// ============================================================================
// ThreadLock - 线程锁 (单线程断言)
// 严格翻译自: bun/src/safety/ThreadLock.rs (bun_core::ThreadLock)
//
//   Rust 原始逻辑 (bun_core/src/util.rs):
//     pub struct ThreadLock {
//         #[cfg(ci_assert)]
//         owning_thread: AtomicThreadId,
//         #[cfg(debug_assertions)]
//         locked_at: StoredTrace,
//     }
//
//     impl ThreadLock {
//         pub fn init_unlocked() -> Self
//         pub fn init_locked() -> Self
//         pub fn lock(&mut self)
//         pub fn unlock(&mut self)
//         pub fn assert_locked(&self)
//         pub fn lock_or_assert(&mut self)
//     }
//
//   Zig 原始逻辑:
//     const Self = @This();
//     owning_thread: if (enabled) Thread.Id else void,
//     locked_at: if (traces_enabled) StoredTrace else void,
//
//     pub fn initUnlocked() Self:
//       return .{ .owning_thread = invalid_thread_id }
//     pub fn initLocked() Self:
//       var self = Self.initUnlocked(); self.lock(); return self
//     pub fn initLockedIfNonComptime() Self:
//       return if (@inComptime()) .initUnlocked() else .initLocked()
//
//     pub fn lock(self: *Self) void:
//       if (!enabled) return
//       current = Thread.getCurrentId()
//       if (self.owning_thread != invalid_thread_id):
//         if (traces_enabled):
//           bun.Output.err("assertion failure", ...)
//           bun.crash_handler.dumpStackTrace(self.locked_at.trace())
//         panic("tried to lock `ThreadLock` on thread {}, but was already locked by thread {}")
//       self.owning_thread = current
//       if (traces_enabled): self.locked_at = StoredTrace.capture(@returnAddress())
//
//     pub fn unlock(self: *Self) void:
//       if (!enabled) return
//       self.assertLocked()
//       self.* = .initUnlocked()
//
//     pub fn assertLocked(self: *const Self) void:
//       if (!enabled) return
//       bun.assertf(self.owning_thread != invalid_thread_id, "`ThreadLock` is not locked")
//       bun.assertf(self.owning_thread == current, "`ThreadLock` is locked by thread {}, not thread {}")
//
//     pub fn lockOrAssert(self: *Self) void:
//       if (!enabled) return
//       if (self.owning_thread == invalid_thread_id): self.lock()
//       else: self.assertLocked()
//
//     pub const enabled = bun.Environment.ci_assert
// ============================================================================

/// 线程锁 - 对应 Bun ThreadLock
/// 确保数据只被一个线程访问 (非互斥锁，是调试断言)
/// 使用原子线程 ID 确保线程安全
public class ThreadLock {
    /// 持有锁的线程 ID (原子)
    /// 对应: owning_thread: AtomicThreadId
    private let owningThread: AtomicThreadId

    /// 是否启用
    /// 对应: pub const ENABLED: bool = cfg!(feature = "ci_assert")
    private var enabled: Bool

    /// 是否启用追踪
    /// 对应: #[cfg(debug_assertions)] locked_at: StoredTrace
    private var tracesEnabled: Bool

    /// 锁定时的栈追踪
    /// 对应: locked_at: StoredTrace
    private var lockedAt: StoredTrace

    public init() {
        owningThread = AtomicThreadId.newInvalid()
        enabled = false
        tracesEnabled = false
        lockedAt = StoredTrace.EMPTY
    }

    public init(enabled: Bool) {
        owningThread = AtomicThreadId.newInvalid()
        this.enabled = enabled
        this.tracesEnabled = false
        this.lockedAt = StoredTrace.EMPTY
    }

    public init(enabled: Bool, tracesEnabled: Bool) {
        owningThread = AtomicThreadId.newInvalid()
        this.enabled = enabled
        this.tracesEnabled = tracesEnabled
        this.lockedAt = StoredTrace.EMPTY
    }

    /// 初始化为未锁定状态
    /// 对应: ThreadLock::init_unlocked()
    ///   Rust: pub fn init_unlocked() -> Self
    ///   Zig:  pub fn initUnlocked() Self
    ///     return .{ .owning_thread = invalid_thread_id }
    public static func initUnlocked(): ThreadLock {
        ThreadLock()
    }

    /// 初始化为已锁定状态
    /// 对应: ThreadLock::init_locked()
    ///   var self = Self::init_unlocked()
    ///   self.lock()
    ///   return self
    public static func initLocked(): ThreadLock {
        let lock = ThreadLock()
        lock.lock()
        lock
    }

    /// 初始化：编译时未锁定，运行时锁定
    /// 对应: ThreadLock::init_locked_if_non_comptime() / Zig initLockedIfNonComptime
    ///   return if (@inComptime()) .initUnlocked() else .initLocked()
    public static func initLockedIfNonComptime(): ThreadLock {
        // 仓颉没有 comptime 概念，默认返回已锁定状态
        initLocked()
    }

    /// 获取锁
    /// 对应: ThreadLock::lock()
    ///   current = current_thread_id()
    ///   if (self.owning_thread != invalid_thread_id):
    ///     if (traces_enabled):
    ///       Output::err("assertion failure", "`ThreadLock` was already locked here:")
    ///       dump_stored_trace(&self.locked_at)
    ///     panic("tried to lock `ThreadLock` on thread {}, but was already locked by thread {}")
    ///   self.owning_thread = current
    ///   if (traces_enabled): self.locked_at = StoredTrace::capture(None)
    public func lock(): Unit {
        if (!enabled) { return }
        let current = ThreadId.current()
        if (owningThread.load() != INVALID_THREAD_ID) {
            if (tracesEnabled) {
                print("assertion failure: `ThreadLock` was already locked here:")
                // 对应: dump_stored_trace(&self.locked_at)
            }
            panic("tried to lock `ThreadLock` on thread ${current}, but was already locked by thread ${owningThread.load()}")
        }
        owningThread.store(current)
        if (tracesEnabled) {
            lockedAt = StoredTrace.capture(None)
        }
    }

    /// 释放锁
    /// 对应: ThreadLock::unlock()
    ///   self.assert_locked()
    ///   *self = Self::init_unlocked()  // 重置状态
    public func unlock(): Unit {
        if (!enabled) { return }
        assertLocked()
        owningThread.store(INVALID_THREAD_ID)
        if (tracesEnabled) {
            lockedAt = StoredTrace.EMPTY
        }
    }

    /// 断言当前线程持有锁
    /// 对应: ThreadLock::assert_locked()
    ///   assertf(self.owning_thread != INVALID, "`ThreadLock` is not locked")
    ///   assertf(self.owning_thread == current, "`ThreadLock` is locked by thread {}, not thread {}")
    public func assertLocked(): Unit {
        if (!enabled) { return }
        let ownerId = owningThread.load()
        if (ownerId == INVALID_THREAD_ID) {
            panic("`ThreadLock` is not locked")
        }
        let current = ThreadId.current()
        if (ownerId != current) {
            panic("`ThreadLock` is locked by thread ${ownerId}, not thread ${current}")
        }
    }

    /// 获取锁或断言已持有
    /// 对应: ThreadLock::lock_or_assert()
    ///   if (self.owning_thread == INVALID): self.lock()
    ///   else: self.assert_locked()
    public func lockOrAssert(): Unit {
        if (!enabled) { return }
        if (owningThread.load() == INVALID_THREAD_ID) {
            lock()
        } else {
            assertLocked()
        }
    }

    /// 检查当前是否被锁定 (不触发断言)
    public func isLocked(): Bool {
        owningThread.load() != INVALID_THREAD_ID
    }

    /// 检查当前线程是否持有锁
    public func isLockedByCurrentThread(): Bool {
        owningThread.load() == ThreadId.current()
    }
}

// ============================================================================
// ThreadLockGuard - RAII 风格的 ThreadLock 守卫
// 严格翻译自: bun/src/safety/ThreadLock.rs (re-export of bun_core::ThreadLockGuard)
//
//   Rust 原始逻辑 (bun_core/src/util.rs):
//     pub struct ThreadLockGuard<'a> {
//         lock: &'a mut ThreadLock,
//     }
//     impl<'a> ThreadLockGuard<'a> {
//         pub fn new(lock: &'a mut ThreadLock) -> Self {
//             lock.lock();
//             Self { lock }
//         }
//     }
//     impl<'a> Drop for ThreadLockGuard<'a> {
//         fn drop(&mut self) {
//             self.lock.unlock();
//         }
//     }
// ============================================================================

/// ThreadLock 守卫 - 对应 Bun ThreadLockGuard
/// RAII 模式：创建时获取锁，销毁时自动释放
/// 对应 Rust 的 ThreadLockGuard<'a>
///
/// 用法:
///   func doWork(data: SharedData): Unit {
///       let guard = ThreadLockGuard(data.threadLock)
///       defer guard.release()  // 仓颉使用 defer 替代 Drop
///       // 操作共享数据...
///   }
public class ThreadLockGuard {
    /// 关联的 ThreadLock
    private let lock: ThreadLock

    /// 是否已释放 (防止重复释放)
    private var released: Bool

    /// 创建并锁定
    /// 对应: ThreadLockGuard::new(lock: &'a mut ThreadLock) -> Self
    ///   lock.lock()
    ///   Self { lock }
    public init(lock: ThreadLock) {
        this.lock = lock
        this.released = false
        lock.lock()
    }

    /// 手动释放锁 (在 defer 中调用)
    /// 对应: impl Drop for ThreadLockGuard { fn drop() { self.lock.unlock() } }
    /// 仓颉没有 Drop trait，需要手动调用或在 defer 中调用
    public func release(): Unit {
        if (!released) {
            lock.unlock()
            released = true
        }
    }
}
