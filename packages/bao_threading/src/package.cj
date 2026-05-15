// bao_threading - 线程和并发原语
// 严格翻译自:
//   src/threading/threading.zig - 包导出
//   src/threading/Mutex.zig - Mutex (FutexImpl)
//   src/threading/Condition.zig - Condition (FutexImpl)
//   src/threading/Futex.zig - Futex, Futex.Deadline
//   src/threading/WaitGroup.zig - WaitGroup
//   src/threading/channel.zig - Channel
//   src/threading/unbounded_queue.zig - UnboundedQueue
//   src/threading/ThreadPool.zig - ThreadPool, Task, Batch, Event
//   src/threading/work_pool.zig - WorkPool
//   src/threading/guarded.zig - Guarded, GuardedBy
//   src/threading/Semaphore.rs - Semaphore (Mutex + Condition + permits)
//   src/threading/RwLock.rs - RwLock<T> (RawRwLock + data-owning wrapper)
//   src/threading/ResetEvent.rs - ResetEvent (Futex state machine)
//   src/bun_core/atomic_cell.rs - AtomicCell, Atom
//   src/event_loop/ConcurrentTask.zig - ConcurrentTask
package bao_threading

// ============================================================================
// 公共导出 - 对应 Bun src/threading/threading.zig
// 严格翻译自:
//   pub const Mutex = @import("./Mutex.zig");
//   pub const Futex = @import("./Futex.zig");
//   pub const Condition = @import("./Condition.zig");
//   pub const guarded = @import("./guarded.zig");
//   pub const Guarded = guarded.Guarded;
//   pub const GuardedBy = guarded.GuardedBy;
//   pub const DebugGuarded = guarded.Debug;
//   pub const WaitGroup = @import("./WaitGroup.zig");
//   pub const ThreadPool = @import("./ThreadPool.zig");
//   pub const Channel = @import("./channel.zig").Channel;
//   pub const UnboundedQueue = @import("./unbounded_queue.zig").UnboundedQueue;
// ============================================================================

// 从子模块重新导出所有公共类型

// -- atomic.cj --
// AtomicBool, AtomicInt8/16/32/64, AtomicUInt8/16/32/64,
// AtomicReference<T>, AtomicEnum<T>, Ordering

// -- sync.cj --
// Mutex, Condvar, RwLock (native wrapper), Semaphore (native wrapper),
// Barrier, Once, CountDownLatch, SpinLock, GuardedValue<T>

// -- semaphore.cj --
// Semaphore (Mutex + Condition + permits implementation, Bun-style)

// -- futex.cj --
// Futex, FutexDeadline, FutexWord

// -- concurrent.cj --
// ConcurrentQueue<T>, ConcurrentMap<K,V>,
// Channel<T> (basic), WaitGroup (embedded),
// Guarded<T>

// -- rwlock.cj --
// RawRwLock (atomic state machine: IS_WRITING/WRITER/READER bits),
// DataRwLock<T> (data-owning wrapper with callback-based read/write)

// -- reset_event.cj --
// ResetEvent (UNSET/WAITING/IS_SET state machine)

// -- wait_group.cj --
// WaitGroup (atomic count + mutex + cond, standalone)

// -- channel.cj --
// Channel<T> (mutex + buffer + putters/getters conditions)

// -- unbounded_queue.cj --
// UnboundedQueue<T> (MPSC queue, Mutex + ArrayList),
// QueueBatch<T>, QueueBatchIterator<T>

// -- future.cj --
// Future<T>, Promise<T>, Futures (combinators), FutureState

// -- thread_pool.cj --
// ThreadPool, ThreadPoolTask, TaskBatch, ThreadPoolConfig,
// ThreadPoolState, WorkPool
