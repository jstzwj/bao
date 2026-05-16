// bao_threading - ResetEvent 手动重置事件
// 严格翻译自:
//   src/threading/ResetEvent.rs - ResetEvent (Futex 状态机)
//   Zig std.Thread.ResetEvent (Zig 0.14.1) FutexImpl
//
// Bun 的 ResetEvent 使用 futex 原子状态机:
//   state: AtomicU32
//   UNSET:    0 — 未设置
//   WAITING:  1 — 有线程在等待
//   IS_SET:   2 — 已设置
//
//   is_set(): state.load(Acquire) == IS_SET
//   wait(): is_set() 检查 -> CAS(UNSET, WAITING) -> futex.wait(state, WAITING)
//   timed_wait(timeout_ns): 同上但带超时
//   set(): state.swap(IS_SET, Release) -> 如果旧状态==WAITING: futex.wake(MAX)
//   reset(): state.store(UNSET, Relaxed)
//
// 仓颉使用 FutexWord (Mutex + Condition) 模拟 futex 语义
package bao_threading

import std.sync.*
import std.time.*

// ============================================================================
// 状态常量 - 对应 Bun ResetEvent.rs:26-28
// 严格翻译自: ResetEvent.rs const UNSET/WAITING/IS_SET
// ============================================================================

/// 未设置 - 对应 Bun UNSET: u32 = 0
/// 严格翻译自: ResetEvent.rs:26 const UNSET: u32 = 0
private let STATE_UNSET: UInt32 = UInt32(0)

/// 有线程在等待 - 对应 Bun WAITING: u32 = 1
/// 严格翻译自: ResetEvent.rs:27 const WAITING: u32 = 1
private let STATE_WAITING: UInt32 = UInt32(1)

/// 已设置 - 对应 Bun IS_SET: u32 = 2
/// 严格翻译自: ResetEvent.rs:28 const IS_SET: u32 = 2
private let STATE_IS_SET: UInt32 = UInt32(2)

// ============================================================================
// ResetEvent - 手动重置事件
// 严格翻译自: src/threading/ResetEvent.rs:16-134
//
// Bun ResetEvent:
//   state: AtomicU32 (UNSET/WAITING/IS_SET)
//
//   FutexImpl (多线程版):
//     is_set(): state.load(Acquire) == IS_SET
//     wait():
//       if is_set() -> return
//       state = load(Acquire)
//       if state == UNSET:
//         state = CAS(UNSET, WAITING) or load actual
//       if state == WAITING:
//         futex_deadline.wait(&state, WAITING) loop
//     timed_wait(timeout_ns):
//       同 wait 但带超时，超时返回 Err(Timeout)
//     set():
//       if state.load(Relaxed) == IS_SET -> return (快速路径)
//       old = state.swap(IS_SET, Release)
//       if old == WAITING -> Futex.wake(&state, MAX)
//     reset():
//       state.store(UNSET, Relaxed)
//
// 仓颉使用 FutexWord (封装了 Mutex + Condition) 实现等价语义
// ============================================================================

/// 手动重置事件 - 对应 Bun ResetEvent
/// 严格翻译自: src/threading/ResetEvent.rs
///
/// 线程安全的布尔事件:
///   - 线程可以阻塞等待事件被 "set"
///   - set() 后所有等待线程被唤醒
///   - reset() 将事件重置为 unset
///   - 静态初始化，最多一个 u32 大小的状态
///
/// 状态机:
///   UNSET (0) -> WAITING (1): 有线程开始等待
///   WAITING (1) -> IS_SET (2): 事件被设置
///   IS_SET (2) -> UNSET (0): 事件被重置
///   UNSET (0) -> IS_SET (2): 事件被设置但无线程等待
public class ResetEvent {
    /// 原子状态 - 对应 Bun state: AtomicU32
    /// 严格翻译自: ResetEvent.rs:17 state: AtomicU32
    private let state: AtomicU32

    /// 互斥锁 - 模拟 futex 等待队列
    private let waitMutex: Mutex

    /// 条件变量 - 模拟 futex 唤醒
    private let waitCond: Condition

    public init() {
        state = AtomicU32(STATE_UNSET)
        waitMutex = Mutex()
        waitCond = waitMutex.condition()
    }

    /// 检查事件是否已设置 - 对应 Bun ResetEvent.is_set()
    /// 严格翻译自: ResetEvent.rs:41-44
    ///
    /// Bun 实现:
    ///   self.state.load(Acquire) == IS_SET
    ///
    /// Acquire 屏障确保 set() 之前的内存访问在 is_set() 返回 true 后可见
    public func isSet(): Bool {
        return state.load() == STATE_IS_SET
    }

    /// 阻塞等待事件被设置 - 对应 Bun ResetEvent.wait()
    /// 严格翻译自: ResetEvent.rs:48-54
    ///
    /// Bun 实现:
    ///   match self.wait_inner(None) {
    ///       Ok(()) => {}
    ///       Err(Timeout) => unreachable!()  // 没有超时，不应超时
    ///   }
    public func wait(): Unit {
        // 快速路径: 已设置则立即返回
        // 严格对应 Bun wait_inner: if !self.is_set() -> wait_until_set
        if (isSet()) {
            return
        }
        waitUntilSet()
    }

    /// 带超时等待事件被设置 - 对应 Bun ResetEvent.timed_wait()
    /// 严格翻译自: ResetEvent.rs:58-60
    ///
    /// Bun 实现:
    ///   self.wait_inner(Some(timeout_ns))
    ///   超时返回 Err(TimeoutError::Timeout)
    ///
    /// 返回 true 表示事件被设置，false 表示超时
    public func timedWait(timeout: Duration): Bool {
        // 快速路径: 已设置则立即返回
        if (isSet()) {
            return true
        }
        return timedWaitUntilSet(timeout)
    }

    /// 设置事件并唤醒所有等待线程 - 对应 Bun ResetEvent.set()
    /// 严格翻译自: ResetEvent.rs:112-124
    ///
    /// Bun 实现:
    ///   // 快速检查是否已设置，避免不必要的 swap 增加竞争
    ///   if self.state.load(Relaxed) == IS_SET {
    ///       return
    ///   }
    ///   // 标记为 IS_SET 并唤醒所有等待者
    ///   // Release 屏障确保 set() 之前的内存访问在事件被观察为设置之前发生
    ///   if self.state.swap(IS_SET, Release) == WAITING {
    ///       Futex::wake(&self.state, u32::MAX)
    ///   }
    public func set(): Unit {
        // 严格对应 Bun: 快速路径 - Relaxed 检查是否已设置
        if (state.load() == STATE_IS_SET) {
            return
        }
        // 严格对应 Bun: swap(IS_SET) 并检查旧状态
        let oldState = state.swap(STATE_IS_SET)
        if (oldState == STATE_WAITING) {
            // 有线程在等待，唤醒所有
            // 对应 Bun Futex::wake(&self.state, u32::MAX)
            synchronized(waitMutex) {
                waitCond.notifyAll()
            }
        }
    }

    /// 重置事件为未设置状态 - 对应 Bun ResetEvent.reset()
    /// 严格翻译自: ResetEvent.rs:128-131
    ///
    /// Bun 实现:
    ///   self.state.store(UNSET, Relaxed)
    ///
    /// 注意: 在有线程阻塞在 wait()/timed_wait() 时调用 reset() 是未定义行为
    /// 允许并发调用 set()/is_set()/reset()
    public func reset(): Unit {
        // 严格对应 Bun: state.store(UNSET, Relaxed)
        state.store(STATE_UNSET)
    }

    // ===== 内部方法 =====

    /// 等待直到事件被设置 (慢路径) - 对应 Bun wait_until_set
    /// 严格翻译自: ResetEvent.rs:72-107
    ///
    /// Bun 实现:
    ///   let mut state = self.state.load(Acquire)
    ///   if state == UNSET {
    ///       state = CAS(UNSET, WAITING) or actual_state
    ///   }
    ///   if state == WAITING {
    ///       loop {
    ///           futex_deadline.wait(&self.state, WAITING)
    ///           state = self.state.load(Acquire)
    ///           if state != WAITING { break }
    ///           wait_result?  // 报告超时
    ///       }
    ///   }
    private func waitUntilSet(): Unit {
        synchronized(waitMutex) {
            // 严格对应 Bun: load(Acquire)
            var s = state.load()
            // 严格对应 Bun: CAS(UNSET, WAITING)
            if (s == STATE_UNSET) {
                // 尝试将状态从 UNSET 改为 WAITING，告诉 set() 有线程在阻塞
                if (state.compareAndSwap(STATE_UNSET, STATE_WAITING)) {
                    s = STATE_WAITING
                } else {
                    s = state.load()
                }
            }
            // 严格对应 Bun: if state == WAITING -> futex wait 循环
            if (s == STATE_WAITING) {
                while (true) {
                    // 检查是否被设置 - 对应 Bun futex_deadline.wait 后检查
                    waitCond.wait()
                    s = state.load()
                    if (s != STATE_WAITING) {
                        break
                    }
                }
            }
            // 严格对应 Bun: debug_assert!(state == IS_SET)
            // 此时 state 应该是 IS_SET
        }
    }

    /// 带超时等待直到事件被设置 (慢路径)
    /// 严格翻译自: ResetEvent.rs:72-107 的带超时版本
    private func timedWaitUntilSet(timeout: Duration): Bool {
        synchronized(waitMutex) {
            var s = state.load()
            if (s == STATE_UNSET) {
                if (state.compareAndSwap(STATE_UNSET, STATE_WAITING)) {
                    s = STATE_WAITING
                } else {
                    s = state.load()
                }
            }
            if (s == STATE_WAITING) {
                while (true) {
                    let signaled = waitCond.wait(timeout: timeout)
                    s = state.load()
                    if (s != STATE_WAITING) {
                        break
                    }
                    // 严格对应 Bun: wait_result? (超时返回 false)
                    if (!signaled) {
                        return false
                    }
                }
            }
            return true
        }
    }
}
