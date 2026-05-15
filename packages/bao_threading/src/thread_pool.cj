// bao_threading - 线程池
// 严格翻译自:
//   src/threading/ThreadPool.zig - ThreadPool, Task, Batch, Event, Node
//   src/threading/work_pool.zig - WorkPool
//   src/event_loop/ConcurrentTask.zig - ConcurrentTask
//
// Bun 的 ThreadPool 是一个 work-stealing 线程池:
//   sync: Atomic(Sync) - 原子状态 (idle/spawned/notified/state)
//   idle_event: Event - 空闲线程等待通知
//   join_event: Event - 线程退出通知
//   run_queue: Node.Queue - 全局任务队列 (lock-free)
//   threads: Atomic(?*Thread) - 注册线程链表
//   wait_group: WaitGroup - 等待所有任务完成
//
// Thread (工作线程):
//   run_buffer: Node.Buffer - 本地环形缓冲 (256 slots)
//   run_queue: Node.Queue - 本地任务队列
//   pop(): 本地buffer -> 本地queue -> 全局queue -> steal其他线程
//
// 仓颉没有 lock-free 数据结构，使用 Mutex + Condition 实现等价语义
package bao_threading

import std.sync.*
import std.collection.ArrayList
import std.time.Duration

// ============================================================================
// ThreadPoolTask - 线程池任务接口
// 严格翻译自: src/threading/ThreadPool.zig:98-101 Task
//
// Bun Task:
//   pub const Task = struct {
//       node: Node = .{},
//       callback: *const (fn (*Task) void),
//   }
//   Bun 使用侵入式链表节点 + 函数指针
//   仓颉使用接口实现等价语义
// ============================================================================

/// 线程池任务接口 - 对应 Bun ThreadPool.Task
/// 严格翻译自: ThreadPool.zig:98-101
///   Bun Task 通过 callback 函数指针执行
///   仓颉使用接口实现等价语义
public interface ThreadPoolTask {
    func execute(): Unit
}

// ============================================================================
// TaskBatch - 批量任务
// 严格翻译自: src/threading/ThreadPool.zig:104-150 Batch
//
// Bun Batch:
//   pub const Batch = struct {
//       len: usize = 0,
//       head: ?*Task = null,
//       tail: ?*Task = null,
//       pub fn pop(this: *Batch) ?*Task
//       pub fn from(task: *Task) Batch
//       pub fn push(self: *Batch, batch: Batch) void
//   }
// ============================================================================

/// 批量任务 - 对应 Bun ThreadPool.Batch
/// 严格翻译自: ThreadPool.zig:104-150
public class TaskBatch {
    /// 任务数量 - 对应 Bun Batch.len
    public var len: Int64
    /// 任务列表 - 对应 Bun Batch.head/tail 链表
    public var tasks: ArrayList<ThreadPoolTask>

    public init() {
        len = 0
        tasks = ArrayList<ThreadPoolTask>()
    }

    /// 从单个任务创建 - 对应 Bun Batch.from(task)
    /// 严格翻译自: ThreadPool.zig:131-137
    ///   return Batch{ .len = 1, .head = task, .tail = task }
    public static func from(task: ThreadPoolTask): TaskBatch {
        let batch = TaskBatch()
        batch.tasks.append(task)
        batch.len = 1
        return batch
    }

    /// 推入另一个 batch - 对应 Bun Batch.push(batch)
    /// 严格翻译自: ThreadPool.zig:140-150
    ///   if (batch.len == 0) return
    ///   if (self.len == 0) { self.* = batch }
    ///   else { self.tail.next = batch.head; self.tail = batch.tail; self.len += batch.len }
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
    /// 严格翻译自: ThreadPool.zig:109-128
    public func pop(): ?ThreadPoolTask {
        if (len == 0) {
            return None
        }
        let task = tasks.removeAt(0)
        len -= 1
        return Some(task)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == 0
    }
}

// ============================================================================
// ThreadPoolState - 线程池同步状态
// 严格翻译自: src/threading/ThreadPool.zig:45-67 Sync
//
// Bun Sync (packed struct u32):
//   idle: u14 = 0       // 空闲线程数
//   spawned: u14 = 0    // 已创建线程数
//   unused: bool = false
//   notified: bool = false  // 是否有待处理的通知
//   state: enum(u2) {       // 线程池状态
//       pending = 0,    // 可以通知唤醒
//       signaled,       // 已通知，有线程要唤醒
//       waking,         // 有线程正在执行唤醒
//       shutdown,       // 关闭中
//   }
// ============================================================================

/// 线程池状态 - 对应 Bun ThreadPool.Sync.state
/// 严格翻译自: ThreadPool.zig:55-66 Sync.state enum
public enum ThreadPoolState {
    | Pending    // 可以通知唤醒 - 对应 Bun pending
    | Signaled   // 已通知，有线程要唤醒 - 对应 Bun signaled
    | Waking     // 有线程正在执行唤醒操作 - 对应 Bun waking
    | Shutdown   // 线程池已关闭 - 对应 Bun shutdown
}

// ============================================================================
// ThreadPoolConfig - 线程池配置
// 严格翻译自: src/threading/ThreadPool.zig:70-74 Config
//
// Bun Config:
//   pub const Config = struct {
//       stack_size: u32 = default_thread_stack_size,  // 4MB
//       max_threads: u32,
//   }
// ============================================================================

/// 线程池配置 - 对应 Bun ThreadPool.Config
/// 严格翻译自: ThreadPool.zig:70-74
public class ThreadPoolConfig {
    /// 栈大小 - 对应 Bun default_thread_stack_size = 4 * 1024 * 1024
    /// 严格翻译自: ThreadPool.zig:317-329
    public var stackSize: Int64
    /// 最大线程数
    public var maxThreads: Int64

    public init() {
        // 严格翻译自: ThreadPool.zig:317 const default = 4 * 1024 * 1024
        stackSize = 4 * 1024 * 1024
        // 对应 Bun bun.getThreadCount()
        maxThreads = 8
    }

    public init(maxThreads: Int64) {
        stackSize = 4 * 1024 * 1024
        this.maxThreads = maxThreads
    }
}

// ============================================================================
// ThreadPool - 线程池
// 严格翻译自: src/threading/ThreadPool.zig
//
// Bun ThreadPool 使用 lock-free 原子操作 + futex:
//   sync: Atomic(Sync) - packed u32 状态
//   idle_event: Event - futex 等待/通知
//   join_event: Event - 线程退出通知
//   run_queue: Node.Queue - lock-free 全局队列
//   threads: Atomic(?*Thread) - lock-free 线程链表
//   wait_group: WaitGroup - 等待所有任务完成
//   is_running: Atomic(bool) - 是否已启动
//
// 仓颉使用 Mutex + Condition + Atomic 实现等价语义
// ============================================================================

/// 线程池 - 严格对应 Bun ThreadPool
/// 严格翻译自: src/threading/ThreadPool.zig
///
/// Bun 使用 lock-free 队列 + 原子操作 + futex 实现高性能线程池
/// 仓颉使用 Mutex + Condition + Atomic 实现等价语义
public class ThreadPool {
    /// 工作线程列表 - 对应 Bun threads: Atomic(?*Thread) 链表
    private var workers: ArrayList<Future<Unit>>
    /// 任务队列 - 对应 Bun run_queue: Node.Queue
    private var taskQueue: ConcurrentQueue<ThreadPoolTask>
    /// 线程池同步状态 - 对应 Bun sync: Atomic(Sync)
    private let state: AtomicEnum<ThreadPoolState>
    /// 是否运行中 - 对应 Bun is_running: Atomic(bool)
    private let running: AtomicBool
    /// 已创建线程数 - 对应 Bun sync.spawned
    private let spawnedCount: AtomicInt64
    /// 最大线程数 - 对应 Bun max_threads
    private let maxThreads: Int64
    /// 栈大小 - 对应 Bun stack_size
    private let stackSize: Int64
    /// 空闲线程数 - 对应 Bun sync.idle
    private let idleCount: AtomicInt64
    /// 互斥锁 - 保护内部状态
    private let mutex: std.sync.Mutex
    /// 空闲等待条件 - 对应 Bun idle_event: Event
    private let idleCond: Condition
    /// 退出等待条件 - 对应 Bun join_event: Event
    private let joinCond: Condition
    /// 等待组 - 对应 Bun wait_group: WaitGroup
    private let waitGroup: WaitGroup
    /// 待处理任务数
    private let pendingCount: AtomicInt64

    public init() {
        let config = ThreadPoolConfig()
        workers = ArrayList<Future<Unit>>()
        taskQueue = ConcurrentQueue<ThreadPoolTask>()
        state = AtomicEnum<ThreadPoolState>(ThreadPoolState.Pending)
        running = AtomicBool(false)
        spawnedCount = AtomicInt64(0)
        maxThreads = config.maxThreads
        stackSize = config.stackSize
        idleCount = AtomicInt64(0)
        mutex = std.sync.Mutex()
        idleCond = mutex.condition()
        joinCond = mutex.condition()
        waitGroup = WaitGroup()
        pendingCount = AtomicInt64(0)
    }

    public init(config: ThreadPoolConfig) {
        workers = ArrayList<Future<Unit>>()
        taskQueue = ConcurrentQueue<ThreadPoolTask>()
        state = AtomicEnum<ThreadPoolState>(ThreadPoolState.Pending)
        running = AtomicBool(false)
        spawnedCount = AtomicInt64(0)
        maxThreads = config.maxThreads
        stackSize = config.stackSize
        idleCount = AtomicInt64(0)
        mutex = std.sync.Mutex()
        idleCond = mutex.condition()
        joinCond = mutex.condition()
        waitGroup = WaitGroup()
        pendingCount = AtomicInt64(0)
    }

    /// 静态初始化 - 对应 Bun ThreadPool.init(config)
    /// 严格翻译自: ThreadPool.zig:77-82
    public static func initFunc(config: ThreadPoolConfig): ThreadPool {
        return ThreadPool(config)
    }

    /// 预热线程池 - 对应 Bun ThreadPool.warm(count)
    /// 严格翻译自: ThreadPool.zig:333-349
    ///   is_running.store(true)
    ///   while (sync.spawned < target) spawn new thread
    public func warm(count: Int64): Unit {
        running.store(true)
        let target = if (count < maxThreads) { count } else { maxThreads }
        for (i in 0..target) {
            spawnWorker()
        }
    }

    /// 调度批量任务 - 对应 Bun ThreadPool.schedule(batch)
    /// 严格翻译自: ThreadPool.zig:273-275 schedule -> scheduleImpl(batch, false)
    ///
    /// Bun scheduleImpl:
    ///   1. wait_group.add(batch.len) (或 addUnsynchronized)
    ///   2. run_queue.push(list) 或 thread.run_buffer.push + run_queue.push
    ///   3. forceSpawn() -> notify()
    public func schedule(batch: TaskBatch): Unit {
        if (batch.isEmpty()) {
            return
        }
        // 对应 Bun scheduleImpl 中的 wait_group.add / addUnsynchronized
        if (running.load()) {
            waitGroup.add(batch.len)
        } else {
            waitGroup.addUnsynchronized(batch.len)
        }
        // 对应 Bun run_queue.push(list)
        for (task in batch.tasks) {
            taskQueue.push(task)
        }
        pendingCount.fetchAdd(batch.len)
        // 对应 Bun forceSpawn -> notify
        forceSpawn()
    }

    /// 调度单个任务 - 对应 Bun WorkPool.schedule(task)
    public func schedule(task: ThreadPoolTask): Unit {
        let batch = TaskBatch.from(task)
        schedule(batch)
    }

    /// 调度闭包任务 - 对应 Bun WorkPool.go 便捷方法
    public func schedule(fn: () -> Unit): Unit {
        schedule(ClosureTask(fn))
    }

    /// 等待所有任务完成 - 对应 Bun ThreadPool.waitForAll()
    /// 严格翻译自: ThreadPool.zig:283-285
    ///   self.wait_group.wait()
    public func waitForAll(): Unit {
        waitGroup.wait()
    }

    /// 等待所有任务完成然后关闭 - 对应 Bun ThreadPool.waitAndDeinit()
    /// 严格翻译自: ThreadPool.zig:288-291
    public func waitAndDeinit(): Unit {
        waitForAll()
        deinit()
    }

    /// 关闭线程池 - 对应 Bun ThreadPool.shutdown()
    /// 严格翻译自: ThreadPool.zig:455-476
    ///   while (sync.state != .shutdown) {
    ///     CAS(sync, new_sync with .shutdown)
    ///     if (sync.idle > 0) idle_event.shutdown()
    ///   }
    public func shutdown(): Unit {
        running.store(false)
        state.store(Int64(ThreadPoolState.Shutdown.ordinal()))
        // 唤醒所有等待的线程
        synchronized(mutex) {
            idleCond.notifyAll()
            joinCond.notifyAll()
        }
    }

    /// 关闭并等待 - 对应 Bun ThreadPool.deinit()
    /// 严格翻译自: ThreadPool.zig:90-94
    ///   self.shutdown(); self.join(); self.* = undefined
    public func deinit(): Unit {
        shutdown()
        // 等待所有线程退出
        synchronized(mutex) {
            while (spawnedCount.load() > 0) {
                joinCond.wait(timeout: Duration.second)
            }
        }
    }

    /// 获取工作线程数
    public func size(): Int64 {
        return spawnedCount.load()
    }

    /// 获取待处理任务数
    public func pending(): Int64 {
        return pendingCount.load()
    }

    // ===== 内部方法 =====

    /// 强制生成线程 - 对应 Bun forceSpawn
    /// 严格翻译自: ThreadPool.zig:293-297
    ///   notify(is_waking=false)
    private func forceSpawn(): Unit {
        synchronized(mutex) {
            // 对应 Bun notifySlow: 如果有等待者，唤醒
            if (idleCount.load() > 0) {
                idleCond.notify()
            } else if (spawnedCount.load() < maxThreads) {
                spawnWorker()
            }
        }
    }

    /// 生成工作线程 - 对应 Bun Thread.run
    /// 严格翻译自: ThreadPool.zig:553-588 Thread.run
    private func spawnWorker(): Unit {
        let count = spawnedCount.fetchAdd(1) + 1
        let fut = spawn {
            workerLoop()
        }
        workers.append(fut)
    }

    /// 工作线程循环 - 对应 Bun Thread.run 中的主循环
    /// 严格翻译自: ThreadPool.zig:572-588
    ///
    /// Bun Thread.run 循环:
    ///   while (true) {
    ///     is_waking = thread_pool.wait(is_waking) catch return
    ///     while (self.pop(thread_pool)) |result| {
    ///       if (result.pushed or is_waking) thread_pool.notify(is_waking)
    ///       is_waking = false
    ///       (task.callback)(task)
    ///       thread_pool.wait_group.finish()
    ///     }
    ///   }
    private func workerLoop(): Unit {
        while (running.load()) {
            // 尝试从队列获取任务 - 对应 Bun Thread.pop
            let task = taskQueue.pop()
            if (task != None) {
                // 执行任务 - 对应 Bun (task.callback)(task)
                task.unwrap().execute()
                // 完成等待组 - 对应 Bun wait_group.finish()
                waitGroup.finish()
                pendingCount.fetchSub(1)
            } else {
                // 没有任务，进入空闲等待 - 对应 Bun idle_event.wait()
                synchronized(mutex) {
                    if (!running.load()) {
                        break
                    }
                    idleCount.fetchAdd(1)
                    // 对应 Bun wait() 中的 idle_event.wait()
                    // 带 10 秒超时，对应 Bun Event.wait 中的 timeout
                    idleCond.wait(timeout: Duration.second * 10)
                    idleCount.fetchSub(1)
                }
            }
        }
        // 线程退出 - 对应 Bun unregister
        let remaining = spawnedCount.fetchSub(1) - 1
        if (remaining == 0) {
            // 最后一个线程退出，通知 join()er
            synchronized(mutex) {
                joinCond.notifyAll()
            }
        }
    }
}

/// 闭包任务包装 - 将 lambda 转为 ThreadPoolTask
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
// WorkPool - 全局工作池
// 严格翻译自: src/threading/work_pool.zig
//
// Bun WorkPool:
//   var pool: ThreadPool = undefined
//   var createOnce = bun.once(create)
//   pub fn get() *ThreadPool { createOnce.call(); return &pool }
//   pub fn schedule(task) { get().schedule(Batch.from(task)) }
//   pub fn go(allocator, ctx, context, function) { ... }
// ============================================================================

/// 全局工作池 - 对应 Bun WorkPool
/// 严格翻译自: src/threading/work_pool.zig
///
/// Bun WorkPool 是全局单例线程池:
///   lazy init (bun.once) -> 获取线程数 -> 创建 ThreadPool
///   schedule(task): 提交单个任务
///   go(allocator, ctx, function): 提交闭包任务
public class WorkPool {
    /// 单例线程池
    private static var pool: ?ThreadPool
    /// 一次性初始化标志 - 对应 Bun bun.once
    private static let once: Once = Once()

    /// 获取全局线程池 - 对应 Bun WorkPool.get()
    /// 严格翻译自: work_pool.zig:19-22
    ///   createOnce.call({})
    ///   return &pool
    public static func get(): ThreadPool {
        once.callOnce({
            pool = ThreadPool(ThreadPoolConfig())
            pool.warm(8)
        })
        return pool.unwrap()
    }

    /// 调度任务 - 对应 Bun WorkPool.schedule(task)
    /// 严格翻译自: work_pool.zig:24-26
    public static func schedule(task: ThreadPoolTask): Unit {
        get().schedule(task)
    }

    /// 调度批量任务
    public static func scheduleBatch(batch: TaskBatch): Unit {
        get().schedule(batch)
    }

    /// 调度闭包 - 对应 Bun WorkPool.go
    /// 严格翻译自: work_pool.zig:32-53
    public static func go(fn: () -> Unit): Unit {
        get().schedule(fn)
    }

    /// 关闭工作池
    public static func shutdown(): Unit {
        match (pool) {
            case Some(p) => p.shutdown()
            case None => ()
        }
    }
}
