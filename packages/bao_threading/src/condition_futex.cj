// bao_threading - Condition FutexImpl 原子状态机
// 严格翻译自:
//   src/threading/Condition.rs:314-464 FutexImpl
//   Zig std.Thread.Condition FutexImpl (Zig 0.14.1)
//
// Bun 的 Condition FutexImpl 使用两个原子字:
//   state: AtomicU32
//     低 16 位 (WAITER_MASK): 等待线程计数
//     高 16 位 (SIGNAL_MASK): 信号计数
//   epoch: AtomicU32
//     用于 futex 等待/唤醒的地址，每次 wake 递增
//
//   wait(mutex):
//     1. epoch.load(Acquire) — 观察当前 epoch
//     2. state.fetchAdd(ONE_WAITER, Relaxed) — 增加等待者计数
//     3. mutex.unlock() — 原子释放互斥锁
//     4. futex_deadline.wait(&epoch, epoch) — futex 等待 epoch 变化
//     5. epoch.load(Acquire) + state.load(Relaxed) — 检查是否有信号
//     6. CAS(state, state - ONE_WAITER - ONE_SIGNAL) — 消费信号并减少等待者
//     7. mutex.lock() — 重新获取互斥锁
//
//   wake(Notify::One/All):
//     1. state.load(Relaxed) — 读取当前状态
//     2. 计算 wakeable = waiters - signals
//     3. CAS(state, state + ONE_SIGNAL * to_wake) — 预留唤醒信号
//     4. epoch.fetchAdd(1, Release) — 递增 epoch
//     5. Futex::wake(&epoch, to_wake) — futex 唤醒
//
// 仓颉使用 FutexWord 模拟等价的 waiter/signal 计数 + epoch 语义
package bao_threading

import std.sync.*
import std.time.Duration

// ============================================================================
// 常量定义 - 对应 Bun Condition.rs:329-333
// 严格翻译自: Condition.rs FutexImpl ONE_WAITER/WAITER_MASK/ONE_SIGNAL/SIGNAL_MASK
// ============================================================================

/// 一个等待者 - 对应 Bun ONE_WAITER: u32 = 1
/// 严格翻译自: Condition.rs:329 const ONE_WAITER: u32 = 1
private let ONE_WAITER: UInt32 = UInt32(1)

/// 等待者掩码 (低 16 位) - 对应 Bun WAITER_MASK: u32 = 0xffff
/// 严格翻译自: Condition.rs:330 const WAITER_MASK: u32 = 0xffff
private let WAITER_MASK: UInt32 = UInt32(0xFFFF)

/// 一个信号 - 对应 Bun ONE_SIGNAL: u32 = 1 << 16
/// 严格翻译自: Condition.rs:332 const ONE_SIGNAL: u32 = 1 << 16
private let ONE_SIGNAL: UInt32 = UInt32(1) << 16

/// 信号掩码 (高 16 位) - 对应 Bun SIGNAL_MASK: u32 = 0xffff << 16
/// 严格翻译自: Condition.rs:333 const SIGNAL_MASK: u32 = 0xffff << 16
private let SIGNAL_MASK: UInt32 = UInt32(0xFFFF) << 16

// ============================================================================
// FutexCondition - 基于 futex 的条件变量
// 严格翻译自: src/threading/Condition.rs:314-464 FutexImpl
//
// Bun FutexImpl:
//   state: AtomicU32 (低16位=waiter计数, 高16位=signal计数)
//   epoch: AtomicU32 (futex 等待/唤醒地址)
//
//   wait(mutex, timeout):
//     1. epoch.load(Acquire)
//     2. state.fetchAdd(ONE_WAITER)
//     3. mutex.unlock()
//     4. futex_deadline.wait(&epoch, epoch) 循环
//     5. 超时时: CAS 消费信号或移除等待者
//     6. 唤醒时: CAS 消费信号并移除等待者
//     7. mutex.lock()
//
//   wake(One/All):
//     1. 计算可唤醒数 = waiters - signals
//     2. CAS 预留信号
//     3. epoch.fetchAdd(1)
//     4. Futex::wake(&epoch, to_wake)
//
// 仓颉使用 FutexWord + 原子操作实现等价语义
// ============================================================================

/// 基于 futex 的条件变量 - 对应 Bun Condition.rs FutexImpl
/// 严格翻译自: Condition.rs:314-464
///
/// 状态字 state 的位布局:
///   bits 0-15:  waiter 计数 (正在等待的线程数)
///   bits 16-31: signal 计数 (已发出但未被消费的信号数)
///
/// epoch 字用于 futex 等待/唤醒:
///   每次 wake 时递增，等待线程在 epoch 上 futex_wait
public class FutexCondition {
    /// 状态字 - 对应 Bun state: AtomicU32
    /// 严格翻译自: Condition.rs:316 state: AtomicU32
    /// 低 16 位 = waiter 计数, 高 16 位 = signal 计数
    private let state: AtomicU32

    /// 纪元字 - 对应 Bun epoch: AtomicU32
    /// 严格翻译自: Condition.rs:317 epoch: AtomicU32
    /// futex 等待/唤醒的地址，每次 wake 递增
    private let epoch: FutexWord

    /// 内部互斥锁 - 保护 state 和 epoch 的 CAS 操作
    private let casMutex: std.sync.Mutex

    public init() {
        state = AtomicU32(UInt32(0))
        epoch = FutexWord(UInt32(0))
        casMutex = std.sync.Mutex()
    }

    /// 等待条件变量 - 对应 Bun FutexImpl.wait()
    /// 严格翻译自: Condition.rs:335-413
    ///
    /// Bun 实现:
    ///   1. epoch.load(Acquire) — 观察当前 epoch
    ///   2. state.fetchAdd(ONE_WAITER, Relaxed) — 增加等待者计数
    ///   3. mutex.unlock() — 释放互斥锁
    ///   4. futex_deadline.wait(&epoch, epoch) 循环
    ///      - 被唤醒: CAS(state, state - ONE_WAITER - ONE_SIGNAL)
    ///      - 超时: CAS 移除等待者或消费信号
    ///   5. mutex.lock() — 重新获取互斥锁
    ///
    /// 注意: 仓颉版本的 mutex 参数由调用者管理 (与 Bun 不同)
    /// Bun 中 wait(mutex) 会自动 unlock/lock mutex
    /// 仓颉中调用者需要在 wait 前后管理 mutex
    public func wait(mutex: FutexMutex): Unit {
        // 严格对应 Bun: epoch.load(Acquire)
        var currentEpoch = epoch.load()

        // 严格对应 Bun: state.fetchAdd(ONE_WAITER, Relaxed)
        state.fetchAdd(ONE_WAITER)

        // 严格对应 Bun: mutex.unlock()
        mutex.unlock()

        // 严格对应 Bun: futex_deadline.wait(&epoch, epoch) 循环
        var loopDone = false
        while (!loopDone) {
            // futex 等待 epoch 变化
            epoch.waitForever(currentEpoch)

            // 严格对应 Bun: epoch.load(Acquire) + state.load(Relaxed)
            currentEpoch = epoch.load()
            var s = state.load()

            // 严格对应 Bun: while (state & SIGNAL_MASK != 0) CAS 消费信号
            while ((s & SIGNAL_MASK) != UInt32(0)) {
                let newState = s - ONE_WAITER - ONE_SIGNAL
                // 仓颉 CAS 需要在锁保护下
                synchronized(casMutex) {
                    if (state.compareAndSwap(s, newState)) {
                        // 成功消费信号，返回
                        // 严格对应 Bun: return Ok(())
                        loopDone = true
                    }
                }
                if (loopDone) {
                    break
                }
                // CAS 失败，重新加载状态
                s = state.load()
            }
            // 没有信号，继续 futex 等待
        }

        // 严格对应 Bun: mutex.lock()
        mutex.lock()
    }

    /// 带超时等待 - 对应 Bun FutexImpl.wait() 带超时
    /// 严格翻译自: Condition.rs:335-413 timeout 参数路径
    ///
    /// 返回 true 表示被正常唤醒，false 表示超时
    public func timedWait(mutex: FutexMutex, timeout: Duration): Bool {
        var currentEpoch = epoch.load()
        state.fetchAdd(ONE_WAITER)
        mutex.unlock()

        // 创建 futex 截止时间
        let deadline = FutexDeadline(timeout.toNanoseconds())

        var timedOut = false

        var loopDone = false
        while (!loopDone) {
            // 带超时的 futex 等待
            let waitResult = deadline.wait(epoch, currentEpoch)
            if (!waitResult) {
                // 超时处理 - 严格对应 Bun 的超时路径
                var s = state.load()
                // 尝试消费信号 (如果有) 而不是报告超时
                while ((s & SIGNAL_MASK) != UInt32(0)) {
                    let newState = s - ONE_WAITER - ONE_SIGNAL
                    synchronized(casMutex) {
                        if (state.compareAndSwap(s, newState)) {
                            loopDone = true
                        }
                    }
                    if (loopDone) {
                        break
                    }
                    s = state.load()
                }
                if (loopDone) {
                    break
                }
                // 没有信号，移除等待者并返回超时
                let newState = s - ONE_WAITER
                synchronized(casMutex) {
                    if (state.compareAndSwap(s, newState)) {
                        timedOut = true
                        loopDone = true
                    }
                }
                if (loopDone) {
                    break
                }
                // CAS 失败，重试
                s = state.load()
            } else {
                // 被唤醒
                currentEpoch = epoch.load()
                var s = state.load()
                while ((s & SIGNAL_MASK) != UInt32(0)) {
                    let newState = s - ONE_WAITER - ONE_SIGNAL
                    synchronized(casMutex) {
                        if (state.compareAndSwap(s, newState)) {
                            loopDone = true
                        }
                    }
                    if (loopDone) {
                        break
                    }
                    s = state.load()
                }
                // 没有信号，继续等待
            }
        }

        mutex.lock()
        return !timedOut
    }

    /// 唤醒一个等待线程 - 对应 Bun FutexImpl.wake(Notify::One)
    /// 严格翻译自: Condition.rs:415-463
    ///
    /// Bun 实现:
    ///   1. state.load(Relaxed)
    ///   2. waiters = (state & WAITER_MASK) / ONE_WAITER
    ///   3. signals = (state & SIGNAL_MASK) / ONE_SIGNAL
    ///   4. wakeable = waiters - signals
    ///   5. if (wakeable == 0) return
    ///   6. CAS(state, state + ONE_SIGNAL) — 预留一个信号
    ///   7. epoch.fetchAdd(1, Release) — 递增 epoch
    ///   8. Futex::wake(&epoch, 1) — futex 唤醒
    public func signal(): Unit {
        wakeInternal(UInt32(1))
    }

    /// 唤醒所有等待线程 - 对应 Bun FutexImpl.wake(Notify::All)
    /// 严格翻译自: Condition.rs:415-463 (to_wake = wakeable)
    public func broadcast(): Unit {
        wakeInternal(UInt32(0x7FFFFFFF))
    }

    /// 别名 - 对应 Bun Condition.notify_one()
    public func notifyOne(): Unit {
        signal()
    }

    /// 别名 - 对应 Bun Condition.notify_all()
    public func notifyAll(): Unit {
        broadcast()
    }

    // ===== 内部方法 =====

    /// 内部唤醒实现 - 对应 Bun FutexImpl.wake()
    /// 严格翻译自: Condition.rs:415-463
    ///
    /// Bun 实现:
    ///   let mut state = self.state.load(Relaxed)
    ///   loop {
    ///       let waiters = (state & WAITER_MASK) / ONE_WAITER
    ///       let signals = (state & SIGNAL_MASK) / ONE_SIGNAL
    ///       let wakeable = waiters - signals
    ///       if (wakeable == 0) return
    ///       let to_wake = min(maxWaiters, wakeable)
    ///       let new_state = state + (ONE_SIGNAL * to_wake)
    ///       match CAS(state, new_state, Release, Relaxed) {
    ///           Ok(_) => {
    ///               epoch.fetchAdd(1, Release)
    ///               Futex::wake(&epoch, to_wake)
    ///               return
    ///           }
    ///           Err(s) => state = s
    ///       }
    ///   }
    private func wakeInternal(maxWake: UInt32): Unit {
        var s = state.load()
        while (true) {
            // 严格对应 Bun: waiters = (state & WAITER_MASK) / ONE_WAITER
            let waiters = (s & WAITER_MASK) / ONE_WAITER
            // 严格对应 Bun: signals = (state & SIGNAL_MASK) / ONE_SIGNAL
            let signals = (s & SIGNAL_MASK) / ONE_SIGNAL
            // 严格对应 Bun: wakeable = waiters - signals
            let wakeable = waiters - signals
            // 严格对应 Bun: if (wakeable == 0) return
            if (wakeable == UInt32(0)) {
                return
            }

            // 计算实际唤醒数量
            let toWake = if (maxWake < wakeable) { maxWake } else { wakeable }

            // 严格对应 Bun: CAS(state, state + ONE_SIGNAL * to_wake, Release)
            let newState = s + (ONE_SIGNAL * toWake)
            synchronized(casMutex) {
                if (state.compareAndSwap(s, newState)) {
                    // 严格对应 Bun: epoch.fetchAdd(1, Release)
                    // Release 屏障确保信号添加在 epoch 变化之前
                    epoch.fetchAdd(UInt32(1))
                    // 严格对应 Bun: Futex::wake(&epoch, to_wake)
                    epoch.wake(toWake)
                    return
                }
            }
            // CAS 失败，重新加载状态
            s = state.load()
        }
    }

    /// 获取等待者计数 (调试用)
    public func waiterCount(): UInt32 {
        return (state.load() & WAITER_MASK) / ONE_WAITER
    }

    /// 获取信号计数 (调试用)
    public func signalCount(): UInt32 {
        return (state.load() & SIGNAL_MASK) / ONE_SIGNAL
    }
}
