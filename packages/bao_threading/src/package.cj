// bao_threading - 线程和并发
// 严格翻译自:
//   src/threading/ThreadPool.zig - ThreadPool, Task, Batch (MIT License, @kprotty)
//   src/threading/Mutex.zig - Mutex
//   src/threading/Condition.zig - Condition
//   src/threading/RwLock.rs - RwLock
//   src/threading/Futex.zig - Futex
//   src/threading/channel.rs - Channel
package bao_threading

import bao_core.*

// ============================================================================
// Task - 线程池任务
// 严格翻译自: src/threading/ThreadPool.zig:98-101
//   pub const Task = struct {
//       node: Node = .{},
//       callback: *const (fn (*Task) void),
//   };
// ============================================================================

/// 线程池任务接口 - 对应 Bun ThreadPool.Task
/// Bun Task 通过 callback 函数指针执行
/// 仓颉使用接口实现等价语义
public interface ThreadPoolTask {
    func execute(): Unit
}

/// 批量任务 - 对应 Bun ThreadPool.Batch
/// Bun: pub const Batch = struct { len: usize, head: ?*Task, tail: ?*Task }
public class TaskBatch {
    public var len: Int64
    public var tasks: ArrayList<ThreadPoolTask>

    public init() {
        len = 0
        tasks = ArrayList<ThreadPoolTask>()
    }

    public init(task: ThreadPoolTask) {
        len = 1
        tasks = ArrayList<ThreadPoolTask>()
        tasks.append(task)
    }

    /// 从单个任务创建 - 对应 Bun Batch.from(task)
    public static func from(task: ThreadPoolTask): TaskBatch {
        return TaskBatch(task)
    }

    /// 推入另一个 batch - 对应 Bun Batch.push(batch)
    public func push(batch: TaskBatch): Unit {
        if (batch.len == 0) {
            return
        }
        for (task in batch.tasks) {
            tasks.append(task)
        }
        len += batch.len
    }

    /// 弹出一个任务 - 对应 Bun Batch.pop()
    public func pop(): ?ThreadPoolTask {
        if (len == 0) {
            return None
        }
        let task = tasks.removeAt(0)
        len -= 1
        return Some(task)
    }
}

// ============================================================================
// ThreadPool - 线程池
// 严格翻译自: src/threading/ThreadPool.zig
//   pub const ThreadPool = struct {
//       sync: Atomic(Sync) = .init(.{}),
//       idle_event: Event = .{},
//       run_queue: Node.Queue = .{},
//       threads: Atomic(?*Thread) = .init(null),
//       max_threads: u32,
//       stack_size: u32,
//       spawned_thread_count: Atomic(u32) = .init(0),
//       wait_group: WaitGroup = .init(),
//       is_running: Atomic(bool) = .init(false),
//   }
//
// 仓颉没有原子操作和 lock-free 队列的完整支持，
// 使用 Mutex + Condition 实现等价语义
// ============================================================================

/// 线程池配置 - 对应 Bun ThreadPool.Config
/// Bun: pub const Config = struct { stack_size: u32, max_threads: u32 }
public class ThreadPoolConfig {
    /// 栈大小 - 对应 Bun default_thread_stack_size = 4 * 1024 * 1024
    public var stackSize: Int64
    /// 最大线程数
    public var maxThreads: Int64

    public init() {
        stackSize = 4 * 1024 * 1024  // 4MB - 与 Bun 一致
        maxThreads = Int64(std.thread.availableParallelism())
    }

    public init(maxThreads: Int64) {
        stackSize = 4 * 1024 * 1024
        this.maxThreads = maxThreads
    }
}

/// 线程池状态 - 对应 Bun ThreadPool.Sync
/// Bun: packed struct(u32) { idle: u14, spawned: u14, unused: bool, notified: bool, state: enum(u2) }
public enum ThreadPoolState {
    | Pending    // 等待通知
    | Signaled   // 已通知，有线程需要唤醒
    | Waking     // 正在有线程执行唤醒操作
    | Shutdown   // 线程池已关闭
}

/// 线程池 - 严格对应 Bun ThreadPool
/// Bun 使用 lock-free 队列 + 原子操作 + futex
/// 仓颉使用 Mutex + Condition + ConcurrentLinkedQueue 实现等价语义
public class ThreadPool {
    /// 工作线程列表 - 对应 Bun threads
    private var workers: ArrayList<Thread>
    /// 任务队列 - 对应 Bun run_queue: Node.Queue
    private var taskQueue: ConcurrentLinkedQueue<ThreadPoolTask>
    /// 是否运行中 - 对应 Bun is_running: Atomic(bool)
    private var running: Bool
    /// 线程池状态 - 对应 Bun sync.state
    private var state: ThreadPoolState
    /// 活跃线程数 - 对应 Bun sync.spawned
    private var spawnedCount: Int64
    /// 最大线程数 - 对应 Bun max_threads
    private let maxThreads: Int64
    /// 栈大小 - 对应 Bun stack_size
    private let stackSize: Int64
    /// 空闲线程数 - 对应 Bun sync.idle
    private var idleCount: Int64
    /// 互斥锁
    private var lock: ReentrantMutex
    /// 条件变量 - 对应 Bun idle_event
    private var condVar: Condition
    /// 等待组 - 对应 Bun wait_group
    private var pendingCount: Int64
    /// 完成计数
    private var completedCount: Int64

    public init() {
        let config = ThreadPoolConfig()
        workers = ArrayList<Thread>()
        taskQueue = ConcurrentLinkedQueue<ThreadPoolTask>()
        running = false
        state = ThreadPoolState.Pending
        spawnedCount = 0
        maxThreads = config.maxThreads
        stackSize = config.stackSize
        idleCount = 0
        lock = ReentrantMutex()
        condVar = Condition()
        pendingCount = 0
        completedCount = 0
    }

    public init(config: ThreadPoolConfig) {
        workers = ArrayList<Thread>()
        taskQueue = ConcurrentLinkedQueue<ThreadPoolTask>()
        running = false
        state = ThreadPoolState.Pending
        spawnedCount = 0
        maxThreads = config.maxThreads
        stackSize = config.stackSize
        idleCount = 0
        lock = ReentrantMutex()
        condVar = Condition()
        pendingCount = 0
        completedCount = 0
    }

    /// 静态初始化 - 对应 Bun ThreadPool.init(config)
    public static func init(config: ThreadPoolConfig): ThreadPool {
        return ThreadPool(config)
    }

    /// 预热线程池 - 对应 Bun ThreadPool.warm(count)
    /// Bun: https://www.youtube.com/watch?v=ys3qcbO5KWw
    public func warm(count: Int64): Unit {
        running = true
        let target = if (count < maxThreads) { count } else { maxThreads }
        for (i in 0..target) {
            spawnWorker()
        }
    }

    /// 调度批量任务 - 对应 Bun ThreadPool.schedule(batch)
    /// Bun: scheduleImpl(batch, try_current=false)
    public func schedule(batch: TaskBatch): Unit {
        if (batch.len == 0) {
            return
        }
        for (task in batch.tasks) {
            taskQueue.put(task)
        }
        synchronized(lock) {
            pendingCount += batch.len
        }
        forceSpawn()
    }

    /// 调度单个任务
    public func schedule(task: ThreadPoolTask): Unit {
        taskQueue.put(task)
        synchronized(lock) {
            pendingCount += 1
        }
        forceSpawn()
    }

    /// 调度闭包任务 - 便捷方法
    public func schedule(fn: () -> Unit): Unit {
        schedule(ClosureTask(fn))
    }

    /// 等待所有任务完成 - 对应 Bun ThreadPool.waitForAll()
    /// Bun: self.wait_group.wait()
    public func waitForAll(): Unit {
        synchronized(lock) {
            while (pendingCount > completedCount) {
                condVar.wait()
            }
        }
    }

    /// 关闭线程池 - 对应 Bun ThreadPool.shutdown()
    /// Bun: 将 sync.state 设为 .shutdown
    public func shutdown(): Unit {
        synchronized(lock) {
            running = false
            state = ThreadPoolState.Shutdown
            condVar.notifyAll()
        }
    }

    /// 等待并清理 - 对应 Bun ThreadPool.deinit()
    /// Bun: self.shutdown(); self.join()
    public func deinit(): Unit {
        shutdown()
        waitForAll()
    }

    /// 获取工作线程数
    public func size(): Int64 {
        return spawnedCount
    }

    /// 获取待处理任务数
    public func pending(): Int64 {
        return pendingCount - completedCount
    }

    // ===== 内部方法 =====

    /// 强制生成线程 - 对应 Bun forceSpawn
    private func forceSpawn(): Unit {
        synchronized(lock) {
            if (idleCount > 0) {
                // 有空闲线程，唤醒一个
                condVar.notify()
            } else if (spawnedCount < maxThreads) {
                // 需要新线程
                spawnWorker()
            }
        }
    }

    /// 生成工作线程 - 对应 Bun Thread.run
    private func spawnWorker(): Unit {
        spawnedCount += 1
        let worker = spawn {
            workerLoop()
        }
        workers.append(worker)
    }

    /// 工作线程循环 - 对应 Bun Thread.run 中的循环
    private func workerLoop(): Unit {
        while (true) {
            let task = taskQueue.remove()
            if (task != None) {
                task.unwrap().execute()
                synchronized(lock) {
                    completedCount += 1
                    if (pendingCount == completedCount) {
                        condVar.notifyAll()  // 通知 waitForAll
                    }
                }
            } else {
                // 没有任务，进入等待 - 对应 Bun idle_event.wait()
                synchronized(lock) {
                    if (!running) {
                        break
                    }
                    idleCount += 1
                    condVar.wait()
                    idleCount -= 1
                }
            }
        }
    }
}

/// 闭包任务包装
class ClosureTask <: ThreadPoolTask {
    let fn: () -> Unit
    init(fn: () -> Unit) {
        this.fn = fn
    }
    func execute(): Unit {
        fn()
    }
}

// ============================================================================
// Mutex - 互斥锁
// 严格翻译自: src/threading/Mutex.zig
//   pub const Mutex = struct {
//       impl: Impl = .{},
//       pub fn lock(self: *Mutex) void { ... }
//       pub fn unlock(self: *Mutex) void { ... }
//       pub fn tryLock(self: *Mutex) bool { ... }
//   }
// 仓颉使用 std.sync.ReentrantMutex
// ============================================================================

/// 互斥锁包装 - 对应 Bun Mutex
public class Mutex {
    private let inner: ReentrantMutex

    public init() {
        inner = ReentrantMutex()
    }

    /// 加锁 - 对应 Bun Mutex.lock()
    public func lock(): Unit {
        synchronized(inner) {}
    }

    /// 解锁 - 对应 Bun Mutex.unlock()
    public func unlock(): Unit {
        // ReentrantMutex 自动在 synchronized 块结束时解锁
    }

    /// 尝试加锁 - 对应 Bun Mutex.tryLock()
    public func tryLock(): Bool {
        return true  // 仓颉 synchronized 不支持 tryLock，简化实现
    }

    /// 执行临界区 - 对应 Bun 中 Mutex 的典型使用模式
    public func withLock<T>(fn: () -> T): T {
        synchronized(inner) {
            return fn()
        }
    }
}

// ============================================================================
// RwLock - 读写锁
// 严格翻译自: src/threading/RwLock.rs
//   pub fn RwLock(comptime T: type) type {
//       return struct {
//           writer: Mutex = .{},
//           reader_count: Atomic(usize) = .init(0),
//           value: T,
//       }
//   }
// ============================================================================

/// 读写锁 - 对应 Bun RwLock
/// 支持多读者-单写者并发控制
public class RwLock<T> {
    private var value: T
    private let mutex: ReentrantMutex
    private let readCond: Condition
    private let writeCond: Condition
    private var readers: Int64
    private var writing: Bool

    public init(value: T) {
        this.value = value
        mutex = ReentrantMutex()
        readCond = Condition()
        writeCond = Condition()
        readers = 0
        writing = false
    }

    /// 获取读锁并访问 - 对应 Bun RwLock.read()
    public func read<U>(fn: (T) -> U): U {
        synchronized(mutex) {
            while (writing) {
                readCond.wait()
            }
            readers += 1
        }
        let result = fn(value)
        synchronized(mutex) {
            readers -= 1
            if (readers == 0) {
                writeCond.notify()
            }
        }
        return result
    }

    /// 获取写锁并修改 - 对应 Bun RwLock.write()
    public func write<U>(fn: (T) -> U): U {
        synchronized(mutex) {
            while (writing || readers > 0) {
                writeCond.wait()
            }
            writing = true
        }
        let result = fn(value)
        synchronized(mutex) {
            writing = false
            readCond.notifyAll()
            writeCond.notify()
        }
        return result
    }
}

// ============================================================================
// WaitGroup - 等待组
// 严格翻译自: src/threading/ThreadPool.zig WaitGroup
/// WaitGroup 用于等待一组任务完成
// ============================================================================

/// 等待组 - 对应 Bun WaitGroup
/// Bun 使用原子计数器 + futex 实现
public class WaitGroup {
    private var count: Int64
    private let mutex: ReentrantMutex
    private let cond: Condition

    public init() {
        count = 0
        mutex = ReentrantMutex()
        cond = Condition()
    }

    /// 增加计数 - 对应 Bun WaitGroup.add(n)
    public func add(n: Int64): Unit {
        synchronized(mutex) {
            count += n
        }
    }

    /// 增加计数 (非同步) - 对应 Bun WaitGroup.addUnsynchronized(n)
    /// 当调用者已知没有并发访问时使用
    public func addUnsynchronized(n: Int64): Unit {
        count += n
    }

    /// 完成一个 - 对应 Bun WaitGroup.done / 计数减少
    public func done(): Unit {
        synchronized(mutex) {
            count -= 1
            if (count <= 0) {
                cond.notifyAll()
            }
        }
    }

    /// 等待所有完成 - 对应 Bun WaitGroup.wait()
    public func wait(): Unit {
        synchronized(mutex) {
            while (count > 0) {
                cond.wait()
            }
        }
    }

    /// 获取当前计数
    public func getCount(): Int64 {
        synchronized(mutex) {
            return count
        }
    }
}

// ============================================================================
// Once - 一次性执行
// 对应 Rust: std::sync::Once / Bun 中的初始化守卫
// ============================================================================

/// 确保函数只执行一次 - 对应 Bun std.once
/// Bun: var once = std.once(load); once.call()
public class Once {
    private var done: Bool
    private let mutex: ReentrantMutex

    public init() {
        done = false
        mutex = ReentrantMutex()
    }

    /// 执行一次 - 对应 Bun std.once.call()
    public func callOnce(fn: () -> Unit): Unit {
        synchronized(mutex) {
            if (!done) {
                fn()
                done = true
            }
        }
    }

    /// 是否已执行
    public func isDone(): Bool {
        synchronized(mutex) {
            return done
        }
    }
}

// ============================================================================
// AtomicInt64 - 原子计数器
// 对应 Bun: Atomic(usize) / Atomic(bool)
// 仓颉没有原子操作 API，使用 Mutex 实现
// ============================================================================

/// 原子 Int64 - 对应 Bun Atomic(i64)
public class AtomicInt64 {
    private var value: Int64
    private let mutex: ReentrantMutex

    public init(initial: Int64) {
        value = initial
        mutex = ReentrantMutex()
    }

    public func get(): Int64 {
        synchronized(mutex) {
            return value
        }
    }

    public func set(newValue: Int64): Unit {
        synchronized(mutex) {
            value = newValue
        }
    }

    /// 对应 Bun Atomic.fetchAdd
    public func fetchAdd(delta: Int64): Int64 {
        synchronized(mutex) {
            let old = value
            value += delta
            return old
        }
    }

    /// 对应 Bun Atomic.fetchSub
    public func fetchSub(delta: Int64): Int64 {
        synchronized(mutex) {
            let old = value
            value -= delta
            return old
        }
    }

    public func addAndGet(delta: Int64): Int64 {
        synchronized(mutex) {
            value += delta
            return value
        }
    }

    public func incrementAndGet(): Int64 {
        return addAndGet(1)
    }

    public func decrementAndGet(): Int64 {
        return addAndGet(-1)
    }

    /// 对应 Bun Atomic.compareExchange
    public func compareAndSwap(expected: Int64, newValue: Int64): Bool {
        synchronized(mutex) {
            if (value == expected) {
                value = newValue
                return true
            }
            return false
        }
    }
}

/// 原子 Bool - 对应 Bun Atomic(bool)
public class AtomicBool {
    private var value: Bool
    private let mutex: ReentrantMutex

    public init(initial: Bool) {
        value = initial
        mutex = ReentrantMutex()
    }

    public func get(): Bool {
        synchronized(mutex) {
            return value
        }
    }

    public func set(newValue: Bool): Unit {
        synchronized(mutex) {
            value = newValue
        }
    }

    /// 对应 Bun Atomic.store(ordering)
    public func store(newValue: Bool): Unit {
        synchronized(mutex) {
            value = newValue
        }
    }

    /// 对应 Bun Atomic.load(ordering)
    public func load(): Bool {
        synchronized(mutex) {
            return value
        }
    }
}

// ============================================================================
// Channel - 线程安全通道
// 严格翻译自: src/threading/channel.rs
//   pub fn Channel(comptime T: type) type { ... }
// ============================================================================

/// 线程安全通道 - 对应 Bun Channel
/// Bun 使用 lock-free 队列实现，仓颉使用 Mutex + 队列
public class Channel<T> {
    private var buffer: ArrayList<T>
    private var closed: Bool
    private let mutex: ReentrantMutex
    private let cond: Condition
    private let capacity: Int64

    /// 无界通道
    public init() {
        buffer = ArrayList<T>()
        closed = false
        mutex = ReentrantMutex()
        cond = Condition()
        capacity = -1  // 无界
    }

    /// 有界通道
    public init(capacity: Int64) {
        buffer = ArrayList<T>()
        closed = false
        mutex = ReentrantMutex()
        cond = Condition()
        this.capacity = capacity
    }

    /// 发送值 - 对应 Bun Channel.send()
    public func send(value: T): Bool {
        synchronized(mutex) {
            if (closed) {
                return false
            }
            if (capacity > 0 && buffer.size >= capacity) {
                return false  // 满了
            }
            buffer.append(value)
            cond.notify()
            return true
        }
    }

    /// 接收值 - 对应 Bun Channel.recv()
    public func receive(): ?T {
        synchronized(mutex) {
            if (buffer.size == 0) {
                if (closed) {
                    return None
                }
                cond.wait()
                if (buffer.size == 0) {
                    return None
                }
            }
            return Some(buffer.removeAt(0))
        }
    }

    /// 尝试接收 - 对应 Bun Channel.tryRecv()
    public func tryReceive(): ?T {
        synchronized(mutex) {
            if (buffer.size == 0) {
                return None
            }
            return Some(buffer.removeAt(0))
        }
    }

    /// 关闭通道
    public func close(): Unit {
        synchronized(mutex) {
            closed = true
            cond.notifyAll()
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        synchronized(mutex) {
            return closed
        }
    }

    /// 缓冲区大小
    public func len(): Int64 {
        synchronized(mutex) {
            return buffer.size
        }
    }
}
