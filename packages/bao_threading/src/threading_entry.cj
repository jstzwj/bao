// bao_threading - 模块入口导出
// 严格翻译自: src/threading/threading.zig
//   Bun threading 模块的公共导出:
//     pub const Mutex = @import("./Mutex.zig");
//     pub const Futex = @import("./Futex.zig");
//     pub const Condition = @import("./Condition.zig");
//     pub const guarded = @import("./guarded.zig");
//     pub const Guarded = guarded.Guarded;
//     pub const GuardedBy = guarded.GuardedBy;
//     pub const DebugGuarded = guarded.Debug;
//     pub const WaitGroup = @import("./WaitGroup.zig");
//     pub const ThreadPool = @import("./ThreadPool.zig");
//     pub const Channel = @import("./channel.zig").Channel;
//     pub const UnboundedQueue = @import("./unbounded_queue.zig").UnboundedQueue;
package bao_threading

// ============================================================================
// 模块导出 - 对应 Bun src/threading/threading.zig
// 严格翻译自:
//   pub const Mutex = @import("./Mutex.zig");
//   pub const Condition = @import("./Condition.zig");
//   pub const WaitGroup = @import("./WaitGroup.zig");
//   pub const ThreadPool = @import("./ThreadPool.zig");
//   pub const Channel = @import("./channel.zig").Channel;
//   pub const UnboundedQueue = @import("./unbounded_queue.zig").UnboundedQueue;
// ============================================================================

// -- mutex.cj --
// Mutex (公共 API, 委托到 FutexMutex)
// MutexCApi (C 导出桥接: Bun__lock/Bun__unlock)
// spinCycle()

// -- mutex_futex.cj --
// FutexMutex (FutexImpl: unlocked/locked/contended 原子状态机)

// -- condition.cj --
// Condition (公共 API, 委托到 FutexCondition)
// ConditionNotify (One/All 枚举)

// -- condition_futex.cj --
// FutexCondition (FutexImpl: waiter/signal 计数 + epoch futex)

// -- futex.cj --
// Futex, FutexDeadline, FutexWord

// -- guarded.cj --
// Guarded<T>, GuardedBy (DebugGuarded)

// -- wait_group.cj --
// WaitGroup

// -- channel.cj --
// Channel<T>

// -- unbounded_queue.cj --
// UnboundedQueue<T>, QueueBatch<T>

// -- thread_pool.cj --
// ThreadPool, WorkPool

// -- rwlock.cj --
// RawRwLock, DataRwLock<T>

// -- reset_event.cj --
// ResetEvent

// -- semaphore.cj --
// Semaphore

// -- sync.cj --
// Mutex, Condvar, RwLock (native wrapper)

// -- atomic.cj --
// AtomicBool, AtomicInt8/16/32/64, AtomicUInt8/16/32/64, AtomicReference<T>

// -- concurrent.cj --
// ConcurrentQueue<T>, ConcurrentMap<K,V>

// -- future.cj --
// Future<T>, Promise<T>

// -- pool_sync.cj --
// AtomicSync, SyncOps, SyncState, PoolEvent

/// 模块版本 - 对应 Bun threading 模块
public let BAO_THREADING_VERSION = "0.1.0"
