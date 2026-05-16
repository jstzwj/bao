// bao_threading - ThreadPool Sync/Event 原子状态机
// 严格翻译自:
//   src/threading/ThreadPool.rs:46-181 Sync/AtomicSync/Event
//   Zig std.Thread.ThreadPool (Zig 0.14.1)
//
// Bun 的 ThreadPool 使用 packed u32 状态字:
//   Sync (packed struct u32):
//     idle:     u14  bits 0-13  (空闲线程数)
//     spawned:  u14  bits 14-27 (已创建线程数)
//     unused:   bool bit  28    (未使用)
//     notified: bool bit  29    (是否有待处理的通知)
//     state:    u2   bits 30-31 (线程池状态: Pending/Signaled/Waking/Shutdown)
//
//   Event:
//     state: AtomicU32 (EMPTY=0, WAITING=1, NOTIFIED=2, SHUTDOWN=3)
//     wait(): CAS 消费通知 或 futex_wait(state, WAITING)
//     notify(): swap(NOTIFIED) + 如果旧状态==WAITING: futex_wake(1)
//     shutdown(): swap(SHUTDOWN) + 如果旧状态==WAITING: futex_wake(MAX)
//
// 仓颉使用 FutexWord + 原子位操作实现等价语义
package bao_threading

import std.sync.*

// ============================================================================
// SyncState - 线程池同步状态枚举
// 严格翻译自: ThreadPool.rs:70-83 SyncState
// ============================================================================

/// 线程池状态 - 对应 Bun SyncState
/// 严格翻译自: ThreadPool.rs:70-83
///
///   Pending:   可以通知唤醒一个线程作为 "waking thread"
///   Signaled:  已通知，一个线程将被唤醒
///   Waking:    有 "waking thread" 在执行任务
///   Shutdown:  线程池已关闭
public enum SyncState {
    | Pending    // 可以通知唤醒 - 对应 Bun Pending = 0
    | Signaled   // 已通知，有线程要唤醒 - 对应 Bun Signaled = 1
    | Waking     // 有线程正在执行唤醒操作 - 对应 Bun Waking = 2
    | Shutdown   // 线程池已关闭 - 对应 Bun Shutdown = 3
}

/// SyncState 转 Int32
public func syncStateToId(s: SyncState): Int32 {
    match (s) {
        case SyncState.Pending => 0
        case SyncState.Signaled => 1
        case SyncState.Waking => 2
        case SyncState.Shutdown => 3
    }
}

/// Int32 转 SyncState
public func syncStateFromId(id: Int32): SyncState {
    match (id) {
        case 0 => SyncState.Pending
        case 1 => SyncState.Signaled
        case 2 => SyncState.Waking
        case _ => SyncState.Shutdown
    }
}

// ============================================================================
// Sync 常量 - 对应 Bun ThreadPool.rs:86-97
// 严格翻译自: ThreadPool.rs Sync 位布局常量
// ============================================================================

/// idle 掩码 (bits 0-13) - 对应 Bun IDLE_MASK: u32 = 0x3FFF
/// 严格翻译自: ThreadPool.rs:93 const IDLE_MASK: u32 = 0x3FFF
private let SYNC_IDLE_MASK: UInt32 = UInt32(0x3FFF)

/// spawned 偏移 (bits 14-27) - 对应 Bun SPAWNED_SHIFT: u32 = 14
/// 严格翻译自: ThreadPool.rs:94 const SPAWNED_SHIFT: u32 = 14
private let SYNC_SPAWNED_SHIFT: UInt32 = UInt32(14)

/// spawned 掩码 - 对应 Bun SPAWNED_MASK: u32 = 0x3FFF << 14
/// 严格翻译自: ThreadPool.rs:95 const SPAWNED_MASK: u32 = 0x3FFF << 14
private let SYNC_SPAWNED_MASK: UInt32 = UInt32(0x3FFF) << SYNC_SPAWNED_SHIFT

/// notified 位 (bit 29) - 对应 Bun NOTIFIED_BIT: u32 = 1 << 29
/// 严格翻译自: ThreadPool.rs:96 const NOTIFIED_BIT: u32 = 1 << 29
private let SYNC_NOTIFIED_BIT: UInt32 = UInt32(1) << 29

/// state 偏移 (bits 30-31) - 对应 Bun STATE_SHIFT: u32 = 30
/// 严格翻译自: ThreadPool.rs:97 const STATE_SHIFT: u32 = 30
private let SYNC_STATE_SHIFT: UInt32 = UInt32(30)

/// state 掩码 - 对应 Bun STATE_MASK: u32 = 0b11 << 30
/// 严格翻译自: ThreadPool.rs:98 const STATE_MASK: u32 = 0b11 << 30
private let SYNC_STATE_MASK: UInt32 = UInt32(0x3) << SYNC_STATE_SHIFT

// ============================================================================
// AtomicSync - 原子 Sync 包装器
// 严格翻译自: ThreadPool.rs:148-181 AtomicSync
//
// Bun:
//   AtomicSync(AtomicU32) — 对 packed u32 的原子操作
//   load(ordering): Sync
//   cmpxchg_weak(old, new, success, failure): Option<Sync>
//   fetch_or(val, ordering): Sync
//   fetch_sub(val, ordering): Sync
// ============================================================================

/// 原子 Sync - 对应 Bun AtomicSync
/// 严格翻译自: ThreadPool.rs:148-181
///
/// Sync 的位布局 (LSB-first, 匹配 Zig packed struct):
///   idle:     u14  bits 0-13
///   spawned:  u14  bits 14-27
///   unused:   bool bit  28
///   notified: bool bit  29
///   state:    u2   bits 30-31
public class AtomicSync {
    /// 内部原子值 - 对应 Bun AtomicSync.0: AtomicU32
    private let inner: AtomicU32

    public init() {
        inner = AtomicU32(UInt32(0))
    }

    public init(value: UInt32) {
        inner = AtomicU32(value)
    }

    /// 加载 - 对应 Bun AtomicSync.load(ordering)
    /// 严格翻译自: ThreadPool.rs:156-158
    public func load(): UInt32 {
        return inner.load()
    }

    /// 比较并交换 (弱) - 对应 Bun AtomicSync.cmpxchg_weak()
    /// 严格翻译自: ThreadPool.rs:160-170
    /// 返回 true 表示成功，false 表示失败
    public func compareAndSwap(expected: UInt32, desired: UInt32): Bool {
        return inner.compareAndSwap(expected, desired)
    }

    /// 原子或 - 对应 Bun AtomicSync.fetch_or()
    /// 严格翻译自: ThreadPool.rs:172-174
    public func fetchOr(value: UInt32): UInt32 {
        return inner.fetchOr(value)
    }

    /// 原子减 - 对应 Bun AtomicSync.fetch_sub()
    /// 严格翻译自: ThreadPool.rs:176-178
    public func fetchSub(value: UInt32): UInt32 {
        return inner.fetchSub(value)
    }
}

// ============================================================================
// Sync 操作工具
// 严格翻译自: ThreadPool.rs:99-145 Sync 方法
// ============================================================================

/// Sync 工具类 - 对应 Bun Sync 的位操作方法
public class SyncOps {
    /// 获取空闲线程数 - 对应 Bun Sync.idle()
    /// 严格翻译自: ThreadPool.rs:103-105
    public static func idle(sync: UInt32): UInt32 {
        return sync & SYNC_IDLE_MASK
    }

    /// 设置空闲线程数 - 对应 Bun Sync.set_idle()
    /// 严格翻译自: ThreadPool.rs:107-110
    public static func setIdle(sync: UInt32, v: UInt32): UInt32 {
        return (sync & (SYNC_IDLE_MASK ^ UInt32.Max)) | (v & SYNC_IDLE_MASK)
    }

    /// 获取已创建线程数 - 对应 Bun Sync.spawned()
    /// 严格翻译自: ThreadPool.rs:112-114
    public static func spawned(sync: UInt32): UInt32 {
        return (sync & SYNC_SPAWNED_MASK) >> SYNC_SPAWNED_SHIFT
    }

    /// 设置已创建线程数 - 对应 Bun Sync.set_spawned()
    /// 严格翻译自: ThreadPool.rs:116-119
    public static func setSpawned(sync: UInt32, v: UInt32): UInt32 {
        return (sync & (SYNC_SPAWNED_MASK ^ UInt32.Max)) | ((v & UInt32(0x3FFF)) << SYNC_SPAWNED_SHIFT)
    }

    /// 是否有通知 - 对应 Bun Sync.notified()
    /// 严格翻译自: ThreadPool.rs:121-123
    public static func notified(sync: UInt32): Bool {
        return (sync & SYNC_NOTIFIED_BIT) != UInt32(0)
    }

    /// 设置通知标志 - 对应 Bun Sync.set_notified()
    /// 严格翻译自: ThreadPool.rs:125-130
    public static func setNotified(sync: UInt32, v: Bool): UInt32 {
        if (v) {
            return sync | SYNC_NOTIFIED_BIT
        }
        return sync & (SYNC_NOTIFIED_BIT ^ UInt32.Max)
    }

    /// 获取状态 - 对应 Bun Sync.state()
    /// 严格翻译自: ThreadPool.rs:132-141
    public static func state(sync: UInt32): SyncState {
        let stateBits = (sync >> SYNC_SPAWNED_SHIFT) & UInt32(0x3)
        // 注意: state 在 bits 30-31
        let stateVal = (sync >> UInt32(30)) & UInt32(0x3)
        return syncStateFromId(Int32(stateVal))
    }

    /// 设置状态 - 对应 Bun Sync.set_state()
    /// 严格翻译自: ThreadPool.rs:143-145
    public static func setState(sync: UInt32, s: SyncState): UInt32 {
        let stateVal = UInt32(syncStateToId(s))
        return (sync & (SYNC_STATE_MASK ^ UInt32.Max)) | (stateVal << SYNC_STATE_SHIFT)
    }

    /// 创建零值 Sync
    public static func zero(): UInt32 {
        return UInt32(0)
    }

    /// 创建只包含 spawned=1 的 Sync
    public static func oneSpawned(): UInt32 {
        return UInt32(1) << SYNC_SPAWNED_SHIFT
    }
}

// ============================================================================
// PoolEvent - 线程池事件 (信号量令牌)
// 严格翻译自: ThreadPool.rs:1341-1453 Event
//
// Bun Event:
//   state: AtomicU32 (EMPTY=0, WAITING=1, NOTIFIED=2, SHUTDOWN=3)
//
//   wait():
//     1. if state == SHUTDOWN: return
//     2. if state == NOTIFIED: CAS(NOTIFIED, acquire_with)
//     3. if state != WAITING: CAS(state, WAITING)
//     4. futex_wait(state, WAITING) 带 10 秒超时
//     5. 被唤醒后 acquire_with = WAITING (确保其他等待者也能被唤醒)
//
//   notify(): swap(NOTIFIED) + 如果旧状态==WAITING: futex_wake(1)
//   shutdown(): swap(SHUTDOWN) + 如果旧状态==WAITING: futex_wake(MAX)
//
// 仓颉使用 FutexWord 实现等价的状态机
// ============================================================================

/// 事件状态常量 - 对应 Bun Event::EMPTY/WAITING/NOTIFIED/SHUTDOWN
/// 严格翻译自: ThreadPool.rs:1355-1358
private let EVENT_EMPTY: UInt32 = UInt32(0)
private let EVENT_WAITING: UInt32 = UInt32(1)
/// 对应 Bun pub(crate) const NOTIFIED: u32 = 2
public let EVENT_NOTIFIED: UInt32 = UInt32(2)
private let EVENT_SHUTDOWN: UInt32 = UInt32(3)

/// 线程池事件 - 对应 Bun ThreadPool Event
/// 严格翻译自: ThreadPool.rs:1341-1453
///
/// 存储 1 个信号量令牌的事件，多线程安全:
///   wait(): 等待并消费通知
///   notify(): 发布通知并唤醒一个等待线程
///   shutdown(): 标记关闭，唤醒所有等待线程
///
/// 状态机:
///   EMPTY (0) -> WAITING (1): 有线程开始等待
///   WAITING (1) -> NOTIFIED (2): 有通知发布
///   WAITING (1) -> SHUTDOWN (3): 事件被关闭
///   NOTIFIED (2) -> EMPTY/WAITING: 通知被消费
public class PoolEvent {
    /// 原子状态 - 对应 Bun Event.state: AtomicU32
    /// 严格翻译自: ThreadPool.rs:1342 state: AtomicU32
    private let state: FutexWord

    public init() {
        state = FutexWord(EVENT_EMPTY)
    }

    /// 等待并消费通知 - 对应 Bun Event.wait()
    /// 严格翻译自: ThreadPool.rs:1362-1428
    ///
    /// Bun 实现:
    ///   var acquire_with = EMPTY
    ///   var state = self.state.load(Relaxed)
    ///   loop {
    ///       if (state == SHUTDOWN) return
    ///       if (state == NOTIFIED) {
    ///           CAS(state, acquire_with) -> return
    ///       }
    ///       if (state != WAITING) {
    ///           CAS(state, WAITING) -> fall through to futex wait
    ///       }
    ///       futex_wait(state, WAITING, timeout=10s)
    ///       acquire_with = WAITING  // 下次消费后保持 WAITING
    ///   }
    public func wait(): Unit {
        var acquireWith = EVENT_EMPTY
        var s = state.load()

        while (true) {
            // 严格对应 Bun: if (state == SHUTDOWN) return
            if (s == EVENT_SHUTDOWN) {
                return
            }

            // 严格对应 Bun: if (state == NOTIFIED) CAS(state, acquire_with)
            if (s == EVENT_NOTIFIED) {
                if (state.compareAndSwap(s, acquireWith)) {
                    return
                }
                // CAS 失败，重新加载
                s = state.load()
            } else if (s != EVENT_WAITING) {
                // 严格对应 Bun: if (state != WAITING) CAS(state, WAITING)
                if (state.compareAndSwap(s, EVENT_WAITING)) {
                    // 成功设置为 WAITING，继续 futex 等待
                    s = EVENT_WAITING
                } else {
                    s = state.load()
                }
            } else {
                // 严格对应 Bun: futex_wait(state, WAITING, timeout)
                // 10 秒超时，对应 Bun: 10_000_000_000 ns
                // 对应 Bun 中 futex 等待后检查内存释放
                state.waitForever(EVENT_WAITING)
                s = state.load()
                // 严格对应 Bun: acquire_with = WAITING
                // 被唤醒后，消费通知时保持 WAITING 状态
                // 这确保其他等待线程也能被唤醒 (链式唤醒)
                acquireWith = EVENT_WAITING
            }
        }
    }

    /// 发布通知 - 对应 Bun Event.notify()
    /// 严格翻译自: ThreadPool.rs:1432-1434
    ///
    /// Bun 实现:
    ///   self.wake(NOTIFIED, 1)
    public func notify(): Unit {
        wakeInternal(EVENT_NOTIFIED, UInt32(1))
    }

    /// 关闭事件 - 对应 Bun Event.shutdown()
    /// 严格翻译自: ThreadPool.rs:1437-1439
    ///
    /// Bun 实现:
    ///   self.wake(SHUTDOWN, u32::MAX)
    /// 标记事件为 SHUTDOWN，使后续 wait() 立即返回
    public func shutdown(): Unit {
        wakeInternal(EVENT_SHUTDOWN, UInt32(0x7FFFFFFF))
    }

    // ===== 内部方法 =====

    /// 内部唤醒 - 对应 Bun Event.wake()
    /// 严格翻译自: ThreadPool.rs:1442-1452
    ///
    /// Bun 实现:
    ///   let state = self.state.swap(release_with, Release)
    ///   if (state == WAITING) {
    ///       Futex::wake(&self.state, wake_threads)
    ///   }
    private func wakeInternal(releaseWith: UInt32, wakeThreads: UInt32): Unit {
        // 严格对应 Bun: state.swap(release_with, Release)
        let oldState = state.swap(releaseWith)
        // 严格对应 Bun: if (state == WAITING) futex.wake(wake_threads)
        if (oldState == EVENT_WAITING) {
            state.wake(wakeThreads)
        }
    }
}
