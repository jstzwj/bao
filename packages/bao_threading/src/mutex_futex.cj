// bao_threading - Mutex FutexImpl 原子状态机
// 严格翻译自:
//   src/threading/Mutex.rs:308-396 FutexImpl
//   Zig std.Thread.Mutex FutexImpl (Zig 0.14.1)
//
// Bun 的 Mutex FutexImpl 使用原子状态机:
//   state: AtomicU32
//   UNLOCKED:  0b00 (0) — 未锁定
//   LOCKED:    0b01 (1) — 已锁定，无线程等待
//   CONTENDED: 0b11 (3) — 已锁定，有线程等待 (futex wait)
//
//   try_lock(): CAS(UNLOCKED, LOCKED) 或 x86 fetch_or(1)
//   lock():     try_lock() 失败则 lock_slow()
//   lock_slow():
//     1. if state == CONTENDED: futex_wait(state, CONTENDED) (避免不必要的 swap)
//     2. loop: swap(CONTENDED) 如果旧值 != UNLOCKED: futex_wait(state, CONTENDED)
//   unlock():   swap(UNLOCKED) 如果旧值 == CONTENDED: futex_wake(1)
//
// 仓颉使用 FutexWord (AtomicUInt32 + Mutex + Condition) 模拟 futex 语义
package bao_threading

import std.sync.*

// ============================================================================
// 常量定义 - 对应 Bun Mutex.rs:320-322
// 严格翻译自: Mutex.rs FutexImpl UNLOCKED/LOCKED/CONTENDED
// ============================================================================

/// 未锁定 - 对应 Bun UNLOCKED: u32 = 0b00
/// 严格翻译自: Mutex.rs:320 const UNLOCKED: u32 = 0b00
private let MUTEX_UNLOCKED: UInt32 = UInt32(0)

/// 已锁定 (无线程等待) - 对应 Bun LOCKED: u32 = 0b01
/// 严格翻译自: Mutex.rs:321 const LOCKED: u32 = 0b01
private let MUTEX_LOCKED: UInt32 = UInt32(1)

/// 已锁定 (有线程等待) - 对应 Bun CONTENDED: u32 = 0b11
/// 严格翻译自: Mutex.rs:322 const CONTENDED: u32 = 0b11
/// 注意: CONTENDED 必须包含 LOCKED 位 (用于 x86 优化)
private let MUTEX_CONTENDED: UInt32 = UInt32(3)

// ============================================================================
// FutexMutex - 基于 futex 的互斥锁
// 严格翻译自: src/threading/Mutex.rs:308-396 FutexImpl
//
// Bun FutexImpl:
//   state: AtomicU32 (UNLOCKED/LOCKED/CONTENDED)
//
//   try_lock(): CAS(UNLOCKED, LOCKED)
//   lock():     try_lock() || lock_slow()
//   lock_slow(): swap(CONTENDED) + futex_wait 循环
//   unlock():   swap(UNLOCKED) + 如果旧值==CONTENDED: futex_wake(1)
//
// 仓颉使用 FutexWord 实现等价的原子状态机 + futex 语义
// ============================================================================

/// 基于 futex 的互斥锁 - 对应 Bun Mutex.rs FutexImpl
/// 严格翻译自: Mutex.rs:308-396
///
/// 原子状态机:
///   UNLOCKED (0) -> LOCKED (1): try_lock CAS 成功
///   LOCKED (1) -> CONTENDED (3): lock_slow swap
///   CONTENDED (3) -> UNLOCKED (0): unlock swap
///
/// 关键语义:
///   - lock_slow 先检查 state==CONTENDED 再 futex_wait，避免不必要的 swap
///   - unlock 时如果旧值==CONTENDED 才 futex_wake，避免不必要的唤醒
///   - swap(CONTENDED) 同时设置 LOCKED 位和等待标志
public class FutexMutex {
    /// 原子状态 - 对应 Bun state: AtomicU32
    /// 严格翻译自: Mutex.rs:311 state: AtomicU32
    private let state: FutexWord

    public init() {
        state = FutexWord(MUTEX_UNLOCKED)
    }

    /// 尝试获取锁 - 对应 Bun FutexImpl.try_lock()
    /// 严格翻译自: Mutex.rs:331-357
    ///
    /// Bun 实现:
    ///   // x86: fetch_or(1, Acquire) 检查 bit 0
    ///   // 其他: CAS(UNLOCKED, LOCKED, Acquire, Relaxed)
    ///   compare_exchange_weak(UNLOCKED, LOCKED, Acquire, Relaxed)
    ///
    /// Acquire 屏障: 确保获取锁后的临界区代码不会被重排到获取锁之前
    public func tryLock(): Bool {
        // 严格对应 Bun: CAS(UNLOCKED, LOCKED)
        return state.compareAndSwap(MUTEX_UNLOCKED, MUTEX_LOCKED)
    }

    /// 获取锁 (阻塞) - 对应 Bun FutexImpl.lock()
    /// 严格翻译自: Mutex.rs:325-329
    ///
    /// Bun 实现:
    ///   if (!self.try_lock()) {
    ///       self.lock_slow()
    ///   }
    public func lock(): Unit {
        if (!tryLock()) {
            lockSlow()
        }
    }

    /// 释放锁 - 对应 Bun FutexImpl.unlock()
    /// 严格翻译自: Mutex.rs:381-395
    ///
    /// Bun 实现:
    ///   let state = self.state.swap(UNLOCKED, Release)
    ///   debug_assert!(state != UNLOCKED)
    ///   if (state == CONTENDED) {
    ///       Futex::wake(&self.state, 1)
    ///   }
    ///
    /// Release 屏障: 确保临界区代码在释放锁之前完成
    public func unlock(): Unit {
        // 严格对应 Bun: swap(UNLOCKED, Release)
        let oldState = state.swap(MUTEX_UNLOCKED)
        // 严格对应 Bun: if (state == CONTENDED) futex.wake(1)
        if (oldState == MUTEX_CONTENDED) {
            // 唤醒一个等待线程
            // 对应 Bun Futex::wake(&self.state, 1)
            state.wake(UInt32(1))
        }
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

    /// 检查锁是否被持有 (调试用)
    public func isLocked(): Bool {
        return state.load() != MUTEX_UNLOCKED
    }

    // ===== 内部方法 =====

    /// 慢路径锁定 - 对应 Bun FutexImpl.lock_slow()
    /// 严格翻译自: Mutex.rs:359-379
    ///
    /// Bun 实现:
    ///   // 先检查 state==CONTENDED，避免不必要的 swap
    ///   if (self.state.load(Relaxed) == CONTENDED) {
    ///       Futex::wait_forever(&self.state, CONTENDED)
    ///   }
    ///   // swap(CONTENDED) 循环等待
    ///   while (self.state.swap(CONTENDED, Acquire) != UNLOCKED) {
    ///       Futex::wait_forever(&self.state, CONTENDED)
    ///   }
    ///
    /// 关键细节:
    ///   - 先 load 检查避免不必要的 swap (swap 会标记缓存行已修改)
    ///   - swap(CONTENDED) 同时设置 LOCKED 和等待标志
    ///   - 一旦有线程在 futex 等待，后续获取锁必须用 CONTENDED
    ///     以确保 unlock 时唤醒等待线程
    private func lockSlow(): Unit {
        // 严格对应 Bun: if (state.load(Relaxed) == CONTENDED)
        //              Futex::wait_forever(&self.state, CONTENDED)
        if (state.load() == MUTEX_CONTENDED) {
            state.waitForever(MUTEX_CONTENDED)
        }

        // 严格对应 Bun: while (state.swap(CONTENDED, Acquire) != UNLOCKED)
        //              Futex::wait_forever(&self.state, CONTENDED)
        while (state.swap(MUTEX_CONTENDED) != MUTEX_UNLOCKED) {
            // futex 等待直到被唤醒
            // 对应 Bun Futex::wait_forever(&self.state, CONTENDED)
            state.waitForever(MUTEX_CONTENDED)
        }
        // 成功获取锁: state 已被设为 CONTENDED
        // Acquire 屏障确保之前的锁持有者的临界区对当前线程可见
    }
}
