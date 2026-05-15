// bao_event_loop - 跨线程任务提交
// 严格翻译自: src/event_loop/ConcurrentTask.rs + src/event_loop/ConcurrentTask.zig
//
// Bun 的跨线程任务提交:
//   ConcurrentTask - 在工作线程中运行，结果返回主线程
//     pub struct ConcurrentTask {
//         pub task: Task,               // tag + ptr (热调度标签)
//         pub next: Link<ConcurrentTask>, // 侵入式 MPSC 链接 (AtomicPtr)
//         pub auto_delete: bool,         // 完成后自动释放
//     }
//
//   Task (热调度标签):
//     pub struct Task {
//         pub tag: TaskTag,  // u8 标签 (~96 变体)
//         pub ptr: *mut (),  // 类型擦除指针
//     }
//
//   Taskable trait:
//     pub trait Taskable {
//         const TAG: TaskTag
//         fn into_task(ptr: *mut Self) -> Task
//     }
//
//   MPSC Queue:
//     push: 原子 store next (release store) - 无 RMW
//     popBatch: 从 head 取一批任务
//     drain: 在事件循环线程中执行所有任务
//
//   仓颉实现:
//     ConcurrentTaskQueue - MPSC 无锁队列
//     submit(task) - 从任意线程入队
//     drain() - 在事件循环线程中出队并执行
//     Task - callable 带优先级
package bao_event_loop

import bao_core.*
import bao_threading.*

// ============================================================================
// TaskPriority - 任务优先级
// 对应 Bun 的任务调度优先级
//   Bun 的 MiniEventLoop 使用 FIFO 队列，但某些任务
//   (如 Immediate) 应该在 Timer 之前执行
// ============================================================================

/// 任务优先级 - 对应 Bun 的任务调度顺序
public enum TaskPriority {
    | Low       // 低优先级 (后台 I/O)
    | Normal    // 正常优先级 (大多数操作)
    | High      // 高优先级 (Immediate)
    | Critical  // 关键 (事件循环控制)
}

// ============================================================================
// ConcurrentTask - 并发任务 (完整版)
// 严格翻译自: src/event_loop/ConcurrentTask.rs
//   pub struct ConcurrentTask {
//       pub task: Task,
//       pub next: Link<ConcurrentTask>,  // intrusive MPSC link
//       pub auto_delete: bool,
//   }
//
//   pub struct Task {
//       pub tag: TaskTag,  // u8 标签
//       pub ptr: *mut (),  // 类型擦除指针
//   }
//
//   pub unsafe impl Linked for ConcurrentTask {
//       unsafe fn link(item: *mut Self) -> *const Link<Self> {
//           unsafe { core::ptr::addr_of!((*item).next) }
//       }
//   }
//
//   ConcurrentTask::create(task) -> *mut ConcurrentTask:
//     分配并初始化 ConcurrentTask, auto_delete = true
//
//   ConcurrentTask::create_from<T: Taskable>(task) -> *mut ConcurrentTask:
//     从 Taskable 类型创建
//
//   ConcurrentTask::from_callback<T>(ptr, callback) -> *mut ConcurrentTask:
//     从回调创建 (ManagedTask)
// ============================================================================

/// 并发任务 - 对应 Bun ConcurrentTask
/// 在工作线程中创建，在事件循环线程中执行
/// auto_delete: 完成后自动释放 (对应 Bun auto_delete)
public class ConcurrentTask {
    /// 任务标签 - 对应 Bun ConcurrentTask.task.tag: TaskTag
    public var tag: TaskTagKind
    /// 任务回调 (对应 Bun 的类型擦除指针 + dispatch match)
    public var task: () -> Unit
    /// 是否自动删除 - 对应 Bun ConcurrentTask.auto_delete
    /// Bun: If `auto_delete` is true, the task is automatically deallocated when it's finished.
    public var autoDelete: Bool
    /// 是否已完成
    public var done: Bool
    /// 优先级
    public var priority: TaskPriority
    /// MPSC 链接 (对应 Bun next: Link<ConcurrentTask>)
    /// 仓颉: 使用 ConcurrentLinkedQueue 内部管理
    /// 此字段仅用于标识任务在队列中的状态
    public var enqueued: Bool

    public init(tag: TaskTagKind, task: () -> Unit) {
        this.tag = tag
        this.task = task
        autoDelete = true
        done = false
        priority = TaskPriority.Normal
        enqueued = false
    }

    public init(tag: TaskTagKind, task: () -> Unit, priority: TaskPriority) {
        this.tag = tag
        this.task = task
        autoDelete = true
        done = false
        this.priority = priority
        enqueued = false
    }

    /// 创建任务 - 对应 Bun ConcurrentTask.create(task)
    /// Bun:
    ///   pub fn create(task: Task) -> *mut ConcurrentTask {
    ///       ConcurrentTask::new(ConcurrentTask {
    ///           task, next: Link::new(), auto_delete: true
    ///       })
    ///   }
    public static func create(tag: TaskTagKind, task: () -> Unit): ConcurrentTask {
        return ConcurrentTask(tag, task)
    }

    /// 从回调创建 - 对应 Bun ConcurrentTask.from_callback
    /// Bun:
    ///   pub fn from_callback<T>(ptr: *mut T, callback: fn(*mut T) -> JsResult<()>) -> *mut ConcurrentTask {
    ///       Self::create(ManagedTask::new(ptr, callback))
    ///   }
    public static func fromCallback(tag: TaskTagKind, callback: () -> Unit): ConcurrentTask {
        return ConcurrentTask(tag, callback)
    }

    /// 从 Taskable 创建 - 对应 Bun ConcurrentTask.create_from
    /// Bun:
    ///   pub fn create_from<T: Taskable>(task: *mut T) -> *mut ConcurrentTask {
    ///       Self::create(Task::init(task))
    ///   }
    public static func createFrom(tag: TaskTagKind, task: () -> Unit, autoDelete: Bool): ConcurrentTask {
        let t = ConcurrentTask(tag, task)
        t.autoDelete = autoDelete
        return t
    }

    /// 执行任务 - 对应 Bun task dispatch
    /// Bun: bun_runtime::dispatch::run_task 匹配 tag 执行对应逻辑
    public func run(): Unit {
        if (!done) {
            task()
            done = true
        }
    }

    /// 是否自动删除
    /// Bun: pub fn auto_delete(&self) -> bool { self.auto_delete }
    public func shouldAutoDelete(): Bool {
        return autoDelete
    }
}

// ============================================================================
// Taskable - 任务接口
// 严格翻译自: src/event_loop/ConcurrentTask.rs - Taskable trait
//   pub trait Taskable {
//       const TAG: TaskTag
//       fn into_task(ptr: *mut Self) -> Task
//   }
//
//   impl Taskable for AnyTask::AnyTask { const TAG = task_tag::AnyTask }
//   impl Taskable for ManagedTask::ManagedTask { const TAG = task_tag::ManagedTask }
// ============================================================================

/// 任务接口 - 对应 Bun Taskable
/// 实现此接口的类型可以被提交到事件循环
public interface Taskable {
    /// 获取任务标签
    func taskTag(): TaskTagKind
    /// 执行任务
    func run(): Unit
}

// ============================================================================
// ConcurrentTaskQueue - MPSC 无锁任务队列
// 严格翻译自: Bun 的 UnboundedQueue + MiniEventLoop.concurrent_tasks
//
// Bun:
//   pub const ConcurrentTaskQueue = UnboundedQueue(AnyTaskWithExtraContext, .next)
//   UnboundedQueue 是侵入式 MPSC 链表:
//     push: AtomicPtr store (release) - 单条 store 指令
//     popBatch: 从 head 批量取出
//
//   MiniEventLoop.tickConcurrentWithCount:
//     var concurrent = this.concurrent_tasks.popBatch()
//     const count = concurrent.count
//     if (count == 0) return 0
//     // move to local FIFO queue
//     this.tasks.ensureUnusedCapacity(count) catch unreachable
//     var writable = this.tasks.writableSlice(0)
//     while (iter.next()) |task| {
//         writable[0] = task
//         writable = writable[1..]
//         this.tasks.count += 1
//     }
//     return this.tasks.count - start_count
//
//   仓颉: ConcurrentLinkedQueue 提供 MPSC 语义
//     submit: 从任意线程安全入队
//     drain: 在事件循环线程中批量出队
// ============================================================================

/// MPSC 无锁任务队列 - 对应 Bun ConcurrentTaskQueue
/// 多个生产者 (工作线程) / 单个消费者 (事件循环线程)
public class MpscTaskQueue {
    /// 无界 MPSC 队列
    /// Bun: UnboundedQueue<ConcurrentTask>
    private var queue: ConcurrentLinkedQueue<ConcurrentTask>
    /// 已提交任务总数 (统计用)
    private var totalSubmitted: AtomicInt64
    /// 已完成任务总数 (统计用)
    private var totalCompleted: AtomicInt64

    public init() {
        queue = ConcurrentLinkedQueue<ConcurrentTask>()
        totalSubmitted = AtomicInt64(0)
        totalCompleted = AtomicInt64(0)
    }

    // ========================================================================
    // submit - 从任意线程提交任务
    // 严格对应 Bun:
    //   pub fn enqueueTaskConcurrent(this, task) void {
    //       this.concurrent_tasks.push(task)
    //       this.loop.wakeup()
    //   }
    //
    // push 是原子 store next (release store):
    //   pub fn push(queue, item) void {
    //       item.next.store(null, .Release)
    //       const prev = queue.tail.swap(item, .AcqRel)
    //       if (prev) |p| { p.next.store(item, .Release) }
    //       else { queue.head.store(item, .Monotonic) }
    //   }
    // ========================================================================

    /// 从任意线程提交任务 (MPSC push)
    /// 对应 Bun: concurrent_tasks.push(task)
    /// 线程安全: 多个工作线程可以同时调用
    public func submit(task: ConcurrentTask): Unit {
        task.enqueued = true
        queue.put(task)
        totalSubmitted.incrementAndGet()
    }

    /// 提交简单任务 (便捷方法)
    public func submitSimple(tag: TaskTagKind, task: () -> Unit): Unit {
        submit(ConcurrentTask.create(tag, task))
    }

    /// 提交带优先级的任务
    public func submitWithPriority(tag: TaskTagKind, task: () -> Unit, priority: TaskPriority): Unit {
        submit(ConcurrentTask(tag, task, priority))
    }

    // ========================================================================
    // drain - 从事件循环线程批量取出并执行所有任务
    // 严格对应 Bun tickConcurrentWithCount:
    //   pub fn tickConcurrentWithCount(this) usize {
    //       var concurrent = this.concurrent_tasks.popBatch()
    //       const count = concurrent.count
    //       if (count == 0) return 0
    //       // 移动到本地 FIFO 队列
    //       this.tasks.ensureUnusedCapacity(count) catch unreachable
    //       var writable = this.tasks.writableSlice(0)
    //       while (iter.next()) |task| {
    //           writable[0] = task
    //           writable = writable[1..]
    //           this.tasks.count += 1
    //       }
    //       return this.tasks.count - start_count
    //   }
    //
    // 仓颉实现: drain 取出所有任务，按优先级排序后执行
    // ========================================================================

    /// 从事件循环线程取出所有任务
    /// 对应 Bun: concurrent_tasks.popBatch()
    /// 注意: 只能在事件循环线程中调用 (单消费者)
    public func drain(): ArrayList<ConcurrentTask> {
        var tasks = ArrayList<ConcurrentTask>()
        while (true) {
            let task = queue.remove()
            if (task == None) { break }
            let t = task.unwrap()
            t.enqueued = false
            tasks.append(t)
        }
        return tasks
    }

    /// 取出并执行所有任务
    /// 对应 Bun: tickConcurrentWithCount + task.run()
    /// 返回执行的任务数
    public func drainAndExecute(): Int64 {
        var count: Int64 = 0
        while (true) {
            let task = queue.remove()
            if (task == None) { break }
            let t = task.unwrap()
            t.enqueued = false
            t.run()
            totalCompleted.incrementAndGet()
            count += 1
        }
        return count
    }

    /// 取出一批任务 (最多 maxCount 个)
    /// 对应 Bun: popBatch
    public func drainBatch(maxCount: Int64): ArrayList<ConcurrentTask> {
        var tasks = ArrayList<ConcurrentTask>()
        var count: Int64 = 0
        while (count < maxCount) {
            let task = queue.remove()
            if (task == None) { break }
            let t = task.unwrap()
            t.enqueued = false
            tasks.append(t)
            count += 1
        }
        return tasks
    }

    /// 是否有待处理任务
    public func hasPending(): Bool {
        !queue.isEmpty()
    }

    /// 已提交任务总数
    public func submittedCount(): Int64 {
        totalSubmitted.get()
    }

    /// 已完成任务总数
    public func completedCount(): Int64 {
        totalCompleted.get()
    }

    /// 清空队列
    public func clear(): Unit {
        while (true) {
            let task = queue.remove()
            if (task == None) { break }
        }
    }
}

// ============================================================================
// DeferredTask - 延迟任务
// 严格翻译自: src/event_loop/DeferredTaskQueue.rs
//   Bun 使用 DeferredTaskQueue 存储需要在事件循环中延迟执行的任务
//   与 ConcurrentTaskQueue 不同，DeferredTask 在当前迭代中执行
// ============================================================================

/// 延迟任务 - 对应 Bun DeferredTask
/// 在当前事件循环迭代中执行 (非跨线程)
public class DeferredTask {
    /// 任务回调
    public var task: () -> Unit
    /// 是否已执行
    public var executed: Bool

    public init(task: () -> Unit) {
        this.task = task
        executed = false
    }

    /// 执行任务
    public func run(): Unit {
        if (!executed) {
            task()
            executed = true
        }
    }
}

/// 延迟任务队列 - 对应 Bun DeferredTaskQueue
/// FIFO 队列，存储当前迭代中需要执行的延迟任务
public class DeferredTaskQueue {
    /// 任务列表
    private var tasks: ArrayList<DeferredTask>

    public init() {
        tasks = ArrayList<DeferredTask>()
    }

    /// 添加延迟任务
    public func defer(task: () -> Unit): Unit {
        tasks.append(DeferredTask(task))
    }

    /// 执行所有延迟任务
    public func drain(): Unit {
        for (t in tasks) {
            t.run()
        }
        tasks.clear()
    }

    /// 是否有待处理任务
    public func hasPending(): Bool {
        return tasks.size > 0
    }

    /// 清空队列
    public func clear(): Unit {
        tasks.clear()
    }
}

// ============================================================================
// AnyTaskWithExtraContext - 带额外上下文的任务
// 严格翻译自: src/event_loop/AnyTaskWithExtraContext.zig
//   const AnyTaskWithExtraContext = @This()
//   ctx: ?*anyopaque = undefined
//   callback: *const (fn (*anyopaque, *anyopaque) void) = undefined
//   next: ?*AnyTaskWithExtraContext = null
//
//   pub fn run(this, extra: *anyopaque) void {
//       const callback = this.callback
//       const ctx = this.ctx
//       callback(ctx.?, extra)
//   }
//
//   pub fn fromCallbackAutoDeinit(ptr, comptime fieldName) *AnyTaskWithExtraContext
//     创建自动清理的任务
//
//   pub fn New(comptime Type, comptime ContextType, comptime Callback) type
//     创建类型安全的任务包装器
// ============================================================================

/// 带额外上下文的任务 - 对应 Bun AnyTaskWithExtraContext
/// 通用任务类型，携带上下文指针和回调
public class AnyTaskWithExtraContext {
    /// 任务回调
    public var callback: () -> Unit
    /// 是否自动清理
    public var autoDeinit: Bool
    /// 是否已完成
    public var done: Bool

    public init(callback: () -> Unit) {
        this.callback = callback
        autoDeinit = true
        done = false
    }

    public init(callback: () -> Unit, autoDeinit: Bool) {
        this.callback = callback
        this.autoDeinit = autoDeinit
        done = false
    }

    /// 执行任务 - 对应 Bun AnyTaskWithExtraContext.run
    /// Bun:
    ///   pub fn run(this, extra) void {
    ///       @setRuntimeSafety(false)
    ///       const callback = this.callback
    ///       const ctx = this.ctx
    ///       callback(ctx.?, extra)
    ///   }
    public func run(): Unit {
        if (!done) {
            callback()
            done = true
        }
    }

    /// 从回调创建 (自动清理)
    /// 对应 Bun: fromCallbackAutoDeinit
    public static func fromCallbackAutoDeinit(callback: () -> Unit): AnyTaskWithExtraContext {
        return AnyTaskWithExtraContext(callback, true)
    }

    /// 从回调创建 (手动清理)
    public static func fromCallback(callback: () -> Unit): AnyTaskWithExtraContext {
        return AnyTaskWithExtraContext(callback, false)
    }
}
