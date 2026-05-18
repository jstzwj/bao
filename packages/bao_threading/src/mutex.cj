// bao_threading - ThreadMutex 互斥锁
// 严格翻译自: src/threading/ThreadMutex.zig
//   互斥锁同步原语, 确保一次只有一个线程进入临界区
//   基于 Impl 策略:
//     Windows: SRWLOCK (TryAcquireSRWLockExclusive / AcquireSRWLockExclusive / ReleaseSRWLockExclusive)
//     Darwin: os_unfair_lock (os_unfair_lock_trylock / os_unfair_lock_lock / os_unfair_lock_unlock)
//     Posix: FutexImpl (unlocked/locked/contended 原子状态机 + futex wait/wake)
//   Debug 模式: DebugImpl 包装 ReleaseImpl + 死锁检测 (locking_thread)
//   仓颉: 委托到 FutexMutex (对应 FutexImpl)
//
// 同步自 Zig 0.14.1 std.Thread.ThreadMutex
package bao_threading

import std.sync.*

// ============================================================================
// ThreadMutex - 互斥锁
// 严格翻译自: src/threading/ThreadMutex.zig
//   const ThreadMutex = @This();
//   impl: Impl = .{},
//
//   pub fn tryLock(self: *ThreadMutex) bool
//   pub fn lock(self: *ThreadMutex) void
//   pub fn unlock(self: *ThreadMutex) void
//   pub const deinit = void;
//
//   Impl = if (builtin.mode == .Debug and !builtin.single_threaded) DebugImpl else ReleaseImpl
//   ReleaseImpl = if (os == .windows) WindowsImpl
//                 else if (os.isDarwin()) DarwinImpl
//                 else FutexImpl
//
// FutexImpl:
//   state: AtomicU32 (UNLOCKED=0b00, LOCKED=0b01, CONTENDED=0b11)
//   try_lock(): CAS(UNLOCKED, LOCKED) 或 x86 fetch_or(1)
//   lock(): try_lock() || lock_slow()
//   lock_slow(): swap(CONTENDED) + futex_wait 循环
//   unlock(): swap(UNLOCKED) + if CONTENDED: futex_wake(1)
//
// WindowsImpl:
//   srwlock: SRWLOCK = .{}
//   try_lock(): TryAcquireSRWLockExclusive
//   lock(): AcquireSRWLockExclusive
//   unlock(): ReleaseSRWLockExclusive
//
// DarwinImpl:
//   oul: os_unfair_lock = .{}
//   try_lock(): os_unfair_lock_trylock
//   lock(): os_unfair_lock_lock
//   unlock(): os_unfair_lock_unlock
//
// DebugImpl:
//   locking_thread: Atomic(Thread.Id) + impl: ReleaseImpl
//   try_lock(): impl.tryLock() + store current id
//   lock(): check deadlock + impl.lock() + store current id
//   unlock(): assert owner + clear + impl.unlock()
// ============================================================================

/// 互斥锁 - 对应 Bun ThreadMutex
/// 严格翻译自: src/threading/ThreadMutex.zig
///
/// 互斥锁同步原语, 确保一次只有一个线程进入临界区
/// 可静态初始化, 最多 u64 大小
///
/// 使用:
///   let m = ThreadMutex()
///   m.lock()
///   try { ... } finally { m.unlock() }
///
///   if (m.tryLock()) {
///       try { ... } finally { m.unlock() }
///   }
///
/// 底层实现:
///   Windows: SRWLOCK
///   Darwin: os_unfair_lock
///   Posix: FutexImpl (原子状态机 + futex)
///
/// 仓颉委托到 FutexMutex (对应 Bun FutexImpl)
public class ThreadMutex <: Lock {
    /// 底层实现 - 对应 Bun impl: Impl = .{}
    /// 严格翻译自: ThreadMutex.zig:29 impl: Impl = .{}
    private let impl: FutexMutex

    public init() {
        impl = FutexMutex()
    }

    /// 尝试获取锁 - 对应 Bun ThreadMutex.tryLock()
    /// 严格翻译自: ThreadMutex.zig:34-36
    ///
    ///   pub fn tryLock(self: *ThreadMutex) bool {
    ///       return self.impl.tryLock();
    ///   }
    ///
    /// 尝试获取互斥锁而不阻塞调用线程
    /// 返回 false 如果需要阻塞才能获取
    /// 返回 true 时应调用 unlock() 释放
    public func tryLock(): Bool {
        // 严格对应 Bun: self.impl.tryLock()
        return impl.tryLock()
    }

    /// 获取锁 (阻塞) - 对应 Bun ThreadMutex.lock()
    /// 严格翻译自: ThreadMutex.zig:41-43
    ///
    ///   pub fn lock(self: *ThreadMutex) void {
    ///       self.impl.lock();
    ///   }
    ///
    /// 获取互斥锁, 阻塞调用线程直到获取成功
    /// 如果同一线程已经持有锁则为未定义行为
    /// 获取后调用 unlock() 释放
    public func lock(): Unit {
        // 严格对应 Bun: self.impl.lock()
        impl.lock()
    }

    /// 释放锁 - 对应 Bun ThreadMutex.unlock()
    /// 严格翻译自: ThreadMutex.zig:47-49
    ///
    ///   pub fn unlock(self: *ThreadMutex) void {
    ///       self.impl.unlock();
    ///   }
    ///
    /// 释放先前通过 lock() 或 tryLock() 获取的互斥锁
    /// 从不同线程释放为未定义行为
    public func unlock(): Unit {
        // 严格对应 Bun: self.impl.unlock()
        impl.unlock()
    }

    /// 在锁保护下执行 - 对应 Bun 中 m.lock(); defer m.unlock(); ... 的模式
    public func withLock<T>(fn: () -> T): T {
        lock()
        try {
            return fn()
        } finally {
            unlock()
        }
    }

    public func conditionThreadMutex(): FutexMutex {
        return impl
    }

    /// 检查锁是否被持有 (调试用)
    public func isLocked(): Bool {
        return impl.isLocked()
    }

    /// deinit 是 no-op
    /// 严格翻译自: pub const deinit = void;
    public func deinit(): Unit {}
}

// ============================================================================
// C 导出函数 - 对应 Bun export fn Bun__lock/Bun__unlock
// 严格翻译自: ThreadMutex.zig:208-217
//   export fn Bun__lock(ptr: *ReleaseImpl) void { ptr.lock(); }
//   export fn Bun__unlock(ptr: *ReleaseImpl) void { ptr.unlock(); }
//   export const Bun__lock__size: usize = @sizeOf(ReleaseImpl);
//
// 仓颉没有 C 导出函数, 以下为等价的静态方法
// ============================================================================

/// ThreadMutex C 导出桥接 - 对应 Bun Bun__lock/Bun__unlock
/// 严格翻译自: ThreadMutex.zig:208-217
///
/// Bun 通过 export fn 暴露给 C 代码:
///   export fn Bun__lock(ptr: *ReleaseImpl) void { ptr.lock(); }
///   export fn Bun__unlock(ptr: *ReleaseImpl) void { ptr.unlock(); }
///   export const Bun__lock__size: usize = @sizeOf(ReleaseImpl);
///
/// 仓颉等价: 静态方法供 FFI 使用
public class ThreadMutexCApi {
    /// C 导出 lock - 对应 Bun__lock
    /// 严格翻译自: export fn Bun__lock(ptr: *ReleaseImpl) void { ptr.lock(); }
    public static func lock(mutex: FutexMutex): Unit {
        mutex.lock()
    }

    /// C 导出 unlock - 对应 Bun__unlock
    /// 严格翻译自: export fn Bun__unlock(ptr: *ReleaseImpl) void { ptr.unlock(); }
    public static func unlock(mutex: FutexMutex): Unit {
        mutex.unlock()
    }

    /// ReleaseImpl 大小 - 对应 Bun__lock__size
    /// 严格翻译自: export const Bun__lock__size: usize = @sizeOf(ReleaseImpl)
    /// FutexImpl = AtomicU32 = 4 字节
    public static let lockSize: Int64 = 4
}

// ============================================================================
// 旋转循环 - 对应 Bun spinCycle
// 严格翻译自: ThreadMutex.zig:205
//   pub fn spinCycle() void {}
// ============================================================================

/// 旋转循环 - 对应 Bun spinCycle
/// 严格翻译自: ThreadMutex.zig:205 pub fn spinCycle() void {}
/// 在某些自旋锁场景中使用, 当前为空实现
public func spinCycle(): Unit {}
