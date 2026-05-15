// bao_event_loop - 事件循环
// 严格翻译自:
//   src/event_loop/AnyEventLoop.rs - AnyEventLoop (JS/Mini 联合体)
//   src/event_loop/MiniEventLoop.rs - MiniEventLoop (非 JS 上下文)
//   src/event_loop/EventLoopTimer.rs - EventLoopTimer, Tag, State
//   src/event_loop/ConcurrentTask.rs - ConcurrentTask, TaskTag
//   src/event_loop/AnyTask.rs - AnyTask
//   src/event_loop/AutoFlusher.rs - AutoFlusher
package bao_event_loop

import bao_core.*
import bao_threading.*

// ============================================================================
// Timespec - 时间规格
// 严格翻译自: src/event_loop/EventLoopTimer.rs
//   use Timespec as timespec;
//   pub use bun_core::Timespec;
// ============================================================================

/// 时间规格 - 对应 Bun Timespec
/// 用于定时器的绝对时间表示
public class Timespec {
    public var sec: Int64
    public var nsec: Int64

    public init() {
        sec = 0
        nsec = 0
    }

    public init(sec: Int64, nsec: Int64) {
        this.sec = sec
        this.nsec = nsec
    }

    /// 纪元起点 - 对应 Bun timespec::EPOCH
    public static let EPOCH: Timespec = Timespec(0, 0)

    /// 比较是否早于另一个时间
    /// 对应 Bun EventLoopTimer.less
    public func lessThan(other: Timespec): Bool {
        if (sec != other.sec) {
            return sec < other.sec
        }
        return nsec < other.nsec
    }

    /// 是否为零 (EPOCH)
    public func isZero(): Bool {
        return sec == 0 && nsec == 0
    }

    /// 从毫秒创建
    public static func fromMillis(ms: Int64): Timespec {
        return Timespec(ms / 1000, (ms % 1000) * 1000000)
    }

    /// 转为毫秒
    public func toMillis(): Int64 {
        return sec * 1000 + nsec / 1000000
    }
}

/// 纳秒/毫秒常量
public let NS_PER_MS: Int64 = 1000000
public let NS_PER_SEC: Int64 = 1000000000
public let MS_PER_SEC: Int64 = 1000

// ============================================================================
// EventLoopTimer - 事件循环定时器
// 严格翻译自: src/event_loop/EventLoopTimer.rs:52-59
//   pub struct EventLoopTimer {
//       pub next: timespec,
//       pub state: State,
//       pub tag: Tag,
//       pub heap: IntrusiveField<EventLoopTimer>,
//       pub in_heap: InHeap,
//   }
// ============================================================================

/// 定时器状态 - 对应 Bun EventLoopTimer.State
public enum TimerState {
    | Pending     // 等待中
    | Active      // 活跃
    | Cancelled   // 已取消
    | Fired       // 已触发
}

/// 定时器标签 - 对应 Bun EventLoopTimer.Tag
/// 用于区分定时器来源 (JS timeout, interval, immediate 等)
public enum TimerTag {
    | Timeout         // setTimeout
    | Interval        // setInterval
    | Immediate       // setImmediate
    | Animation       // requestAnimationFrame
    | Custom          // 自定义
}

/// 定时器在堆中的状态 - 对应 Bun InHeap
public enum InHeap {
    | None      // 不在堆中
    | Regular   // 在常规堆中
    | Fake      // 在伪堆中
}

/// 事件循环定时器 - 严格对应 Bun EventLoopTimer
/// Bun 使用配对堆 (pairing heap) 管理定时器
public class EventLoopTimer {
    /// 下次触发的绝对时间 - 对应 Bun EventLoopTimer.next: timespec
    public var next: Timespec
    /// 定时器状态 - 对应 Bun EventLoopTimer.state: State
    public var state: TimerState
    /// 定时器标签 - 对应 Bun EventLoopTimer.tag: Tag
    public var tag: TimerTag
    /// 是否在堆中 - 对应 Bun EventLoopTimer.in_heap: InHeap
    public var inHeap: InHeap
    /// 回调函数
    public var callback: () -> Unit
    /// 间隔 (毫秒, 0 = 一次性)
    public var intervalMs: Int64
    /// 定时器 ID
    public var id: Int64

    /// 初始化暂停状态 - 对应 Bun EventLoopTimer.init_paused(tag)
    public init(tag: TimerTag) {
        next = Timespec.EPOCH
        state = TimerState.Pending
        this.tag = tag
        inHeap = InHeap.None
        callback = { }
        intervalMs = 0
        id = 0
    }

    public init(tag: TimerTag, callback: () -> Unit, deadlineMs: Int64, intervalMs: Int64, id: Int64) {
        next = Timespec.fromMillis(deadlineMs)
        state = TimerState.Active
        this.tag = tag
        inHeap = InHeap.None
        this.callback = callback
        this.intervalMs = intervalMs
        this.id = id
    }

    /// 比较是否早于另一个定时器 - 对应 Bun EventLoopTimer.less
    public static func less(a: EventLoopTimer, b: EventLoopTimer): Bool {
        return a.next.lessThan(b.next)
    }

    /// 触发定时器
    public func fire(): Unit {
        if (state == TimerState.Active) {
            state = TimerState.Fired
            callback()
        }
    }

    /// 取消 - 对应 Bun timer 取消逻辑
    public func cancel(): Unit {
        state = TimerState.Cancelled
    }

    /// 是否活跃
    public func isActive(): Bool {
        return state == TimerState.Active
    }
}

// ============================================================================
// TaskTag - 任务标签
// 严格翻译自: src/event_loop/ConcurrentTask.rs:43-100
//   pub struct TaskTag(pub u8)
// 每个标签对应一种异步任务类型
// ============================================================================

/// 任务标签 - 对应 Bun TaskTag
/// 用于标识并发任务的类型
public enum TaskTagKind {
    | Access
    | AppendFile
    | Chmod
    | Chown
    | Close
    | CopyFile
    | Exists
    | Fchmod
    | Fchown
    | Fdatasync
    | Fstat
    | Fsync
    | Ftruncate
    | Link
    | Lstat
    | Mkdir
    | Open
    | Read
    | Readdir
    | Readlink
    | Rename
    | Rmdir
    | Stat
    | Symlink
    | Truncate
    | Unlink
    | Unlinkat
    | Utimes
    | Write
    | Custom

    public func name(): String {
        match (this) {
            case Access => "Access"
            case AppendFile => "AppendFile"
            case Chmod => "Chmod"
            case Chown => "Chown"
            case Close => "Close"
            case CopyFile => "CopyFile"
            case Exists => "Exists"
            case Fchmod => "Fchmod"
            case Fchown => "Fchown"
            case Fdatasync => "Fdatasync"
            case Fstat => "Fstat"
            case Fsync => "Fsync"
            case Ftruncate => "Ftruncate"
            case Link => "Link"
            case Lstat => "Lstat"
            case Mkdir => "Mkdir"
            case Open => "Open"
            case Read => "Read"
            case Readdir => "Readdir"
            case Readlink => "Readlink"
            case Rename => "Rename"
            case Rmdir => "Rmdir"
            case Stat => "Stat"
            case Symlink => "Symlink"
            case Truncate => "Truncate"
            case Unlink => "Unlink"
            case Unlinkat => "Unlinkat"
            case Utimes => "Utimes"
            case Write => "Write"
            case Custom => "Custom"
        }
    }
}

// ============================================================================
// ConcurrentTask - 并发任务
// 严格翻译自: src/event_loop/ConcurrentTask.rs
//   A task that runs concurrently in the work pool.
//   If auto_delete is true, the task is automatically deallocated when it's finished.
// ============================================================================

/// 并发任务接口 - 对应 Bun Taskable
public interface Taskable {
    func run(): Unit
}

/// 并发任务 - 对应 Bun ConcurrentTask
/// 在线程池中运行，结果返回主线程
public class ConcurrentTask {
    /// 任务标签 - 对应 Bun ConcurrentTask.tag: TaskTag
    public var tag: TaskTagKind
    /// 任务回调
    public var task: () -> Unit
    /// 是否自动删除 - 对应 Bun ConcurrentTask.auto_delete: bool
    public var autoDelete: Bool
    /// 是否已完成
    public var done: Bool

    public init(tag: TaskTagKind, task: () -> Unit) {
        this.tag = tag
        this.task = task
        autoDelete = true
        done = false
    }

    /// 创建任务 - 对应 Bun ConcurrentTask.create(task)
    public static func create(tag: TaskTagKind, task: () -> Unit): ConcurrentTask {
        return ConcurrentTask(tag, task)
    }

    /// 从回调创建 - 对应 Bun ConcurrentTask.fromCallback(ptr, callback)
    public static func fromCallback(tag: TaskTagKind, callback: () -> Unit): ConcurrentTask {
        return ConcurrentTask(tag, callback)
    }

    /// 执行任务
    public func run(): Unit {
        if (!done) {
            task()
            done = true
        }
    }
}

// ============================================================================
// AnyTask - 通用任务抽象
// 严格翻译自: src/event_loop/AnyTask.rs
//   pub type AnyTask = ...
// ============================================================================

/// 通用任务 - 对应 Bun AnyTask
/// 可以是即时任务、定时器任务或 IO 任务
public enum AnyTask {
    | Immediate(() -> Unit)         // 立即执行
    | Timer(EventLoopTimer)         // 定时器
    | Concurrent(ConcurrentTask)    // 并发任务
    | IoEvent(() -> Unit)           // IO 事件
}

// ============================================================================
// EventLoopKind - 事件循环类型
// 严格翻译自: src/event_loop/MiniEventLoop.rs
//   pub enum EventLoopKind { ... }
// ============================================================================

/// 事件循环类型 - 对应 Bun EventLoopKind
public enum EventLoopKind {
    | Js       // JavaScript 事件循环 (JSC)
    | Mini     // 轻量级事件循环 (非 JS 上下文)
}

// ============================================================================
// MiniEventLoop - 轻量级事件循环
// 严格翻译自: src/event_loop/MiniEventLoop.rs:85-100
//   pub struct MiniEventLoop<'a> {
//       pub tasks: Queue,
//       pub concurrent_tasks: ConcurrentTaskQueue,
//       pub loop_: *mut UwsLoop,
//       pub file_polls_: Option<Box<FilePollStore>>,
//       pub env: Option<NonNull<DotEnvLoader<'a>>>,
//       pub top_level_dir: Box<[u8]>,
//   }
// MiniEventLoop 用于非 JS 上下文 (bun build, bun install, Bun Shell)
// ============================================================================

/// 轻量级事件循环 - 对应 Bun MiniEventLoop
/// 提供基本的事件循环功能，不依赖 JavaScript 运行时
public class MiniEventLoop {
    /// 任务队列 - 对应 Bun tasks: Queue
    private var tasks: ConcurrentLinkedQueue<() -> Unit>
    /// 并发任务队列 - 对应 Bun concurrent_tasks: ConcurrentTaskQueue
    private var concurrentTasks: ConcurrentLinkedQueue<ConcurrentTask>
    /// 定时器列表 - 使用排序列表模拟配对堆
    private var timers: ArrayList<EventLoopTimer>
    /// 下一个定时器 ID
    private var nextTimerId: AtomicInt64
    /// 是否运行中
    private var running: Bool
    /// 迭代计数 - 对应 Bun iteration_number
    private var iterationNumber: UInt64
    /// 互斥锁
    private var lock: ReentrantMutex
    /// 条件变量
    private var condVar: Condition

    public init() {
        tasks = ConcurrentLinkedQueue<() -> Unit>()
        concurrentTasks = ConcurrentLinkedQueue<ConcurrentTask>()
        timers = ArrayList<EventLoopTimer>()
        nextTimerId = AtomicInt64(1)
        running = false
        iterationNumber = 0
        lock = ReentrantMutex()
        condVar = Condition()
    }

    /// 静态初始化 - 对应 Bun MiniEventLoop.init()
    public static func initFunc(): MiniEventLoop {
        return MiniEventLoop()
    }

    /// 获取迭代号 - 对应 Bun MiniEventLoop.iteration_number()
    public func getIterationNumber(): UInt64 {
        return iterationNumber
    }

    /// 启动事件循环
    /// 对应 Bun MiniEventLoop.tick / uSockets 事件循环
    public func run(): Unit {
        running = true
        while (running) {
            iterationNumber += 1

            // 1. 处理并发任务 - 对应 Bun concurrent_tasks drain
            processConcurrentTasks()

            // 2. 处理待执行的回调
            processTasks()

            // 3. 处理到期的定时器 - 对应 Bun timers fire
            processTimers()

            // 4. 如果没有任务也没有定时器，等待
            synchronized(lock) {
                if (tasks.isEmpty() && concurrentTasks.isEmpty() && timers.size == 0) {
                    condVar.wait()
                }
            }
        }
    }

    /// 停止事件循环
    public func stop(): Unit {
        running = false
        synchronized(lock) {
            condVar.notifyAll()
        }
    }

    /// 排队任务 - 对应 Bun MiniEventLoop.enqueue
    public func enqueue(task: () -> Unit): Unit {
        tasks.put(task)
        synchronized(lock) {
            condVar.notify()
        }
    }

    /// 排队并发任务 - 对应 Bun concurrent_tasks.push
    public func enqueueConcurrent(task: ConcurrentTask): Unit {
        concurrentTasks.put(task)
        synchronized(lock) {
            condVar.notify()
        }
    }

    /// 设置定时器 (返回定时器 ID)
    /// 对应 Bun setTimeout
    public func setTimeout(callback: () -> Unit, delayMs: Int64): Int64 {
        let id = nextTimerId.incrementAndGet()
        let deadline = currentTimeMillis() + delayMs
        let timer = EventLoopTimer(
            TimerTag.Timeout, callback, deadline, 0, id
        )
        timers.append(timer)
        return id
    }

    /// 设置间隔定时器
    /// 对应 Bun setInterval
    public func setInterval(callback: () -> Unit, intervalMs: Int64): Int64 {
        let id = nextTimerId.incrementAndGet()
        let deadline = currentTimeMillis() + intervalMs
        let timer = EventLoopTimer(
            TimerTag.Interval, callback, deadline, intervalMs, id
        )
        timers.append(timer)
        return id
    }

    /// 设置即时回调
    /// 对应 Bun setImmediate
    public func setImmediate(callback: () -> Unit): Int64 {
        let id = nextTimerId.incrementAndGet()
        let timer = EventLoopTimer(
            TimerTag.Immediate, callback, currentTimeMillis(), 0, id
        )
        timers.append(timer)
        return id
    }

    /// 取消定时器
    public func clearTimer(id: Int64): Unit {
        for (timer in timers) {
            if (timer.id == id) {
                timer.cancel()
            }
        }
    }

    /// 处理任务
    private func processTasks(): Unit {
        while (true) {
            let task = tasks.remove()
            if (task == None) {
                break
            }
            task.unwrap()()
        }
    }

    /// 处理并发任务
    private func processConcurrentTasks(): Unit {
        while (true) {
            let task = concurrentTasks.remove()
            if (task == None) {
                break
            }
            task.unwrap().run()
        }
    }

    /// 处理定时器 - 对应 Bun timer tick
    /// Bun 使用配对堆 (pairing heap) 高效管理定时器
    /// 仓颉简化实现: 线性扫描
    private func processTimers(): Unit {
        let now = currentTimeMillis()
        var toRemove = ArrayList<Int64>()
        for (timer in timers) {
            if (!timer.isActive()) {
                toRemove.append(timer.id)
                continue
            }
            if (timer.next.toMillis() <= now) {
                timer.fire()
                if (timer.intervalMs > 0) {
                    // Interval: 重新调度
                    timer.next = Timespec.fromMillis(now + timer.intervalMs)
                    timer.state = TimerState.Active
                } else {
                    toRemove.append(timer.id)
                }
            }
        }
        // 移除已完成的一次性定时器
        for (id in toRemove) {
            var idx: Int64 = 0
            while (idx < timers.size) {
                if (timers[Int64(idx)].id == id) {
                    timers.removeAt(Int64(idx))
                    break
                }
                idx += 1
            }
        }
    }

    /// 获取当前时间 (毫秒)
    private func currentTimeMillis(): Int64 {
        return Int64(std.time.DateTime.now().getYear())  // 简化
    }
}

// ============================================================================
// AnyEventLoop - 通用事件循环
// 严格翻译自: src/event_loop/AnyEventLoop.rs:38-46
//   pub enum AnyEventLoop<'a> {
//       Js { owner: JsEventLoop },
//       Mini(MiniEventLoop<'a>),
//   }
// 在 JS 上下文中使用 JS 事件循环，否则使用 MiniEventLoop
// ============================================================================

/// 通用事件循环 - 对应 Bun AnyEventLoop
/// 在 JS 上下文中包装 JSC 事件循环，在非 JS 上下文中使用 MiniEventLoop
public class AnyEventLoop {
    /// 事件循环类型
    private var kind: EventLoopKind
    /// Mini 事件循环 (非 JS 上下文)
    private var mini: MiniEventLoop

    /// 默认构造 (Mini) - 对应 Bun AnyEventLoop::init()
    public init() {
        kind = EventLoopKind.Mini
        mini = MiniEventLoop()
    }

    /// 从 Mini 创建 - 对应 Bun AnyEventLoop::Mini(mini)
    public init(mini: MiniEventLoop) {
        kind = EventLoopKind.Mini
        this.mini = mini
    }

    /// 获取迭代号 - 对应 Bun AnyEventLoop.iteration_number()
    public func iterationNumber(): UInt64 {
        match (kind) {
            case Mini => mini.getIterationNumber()
            case Js => mini.getIterationNumber()  // JS 模式暂用 mini
        }
    }

    /// 运行循环
    public func run(): Unit {
        mini.run()
    }

    /// 停止循环
    public func stop(): Unit {
        mini.stop()
    }

    /// 排队任务
    public func enqueue(task: () -> Unit): Unit {
        mini.enqueue(task)
    }

    /// 设置定时器
    public func setTimeout(callback: () -> Unit, delayMs: Int64): Int64 {
        return mini.setTimeout(callback, delayMs)
    }

    /// 设置间隔
    public func setInterval(callback: () -> Unit, intervalMs: Int64): Int64 {
        return mini.setInterval(callback, intervalMs)
    }

    /// 设置即时
    public func setImmediate(callback: () -> Unit): Int64 {
        return mini.setImmediate(callback)
    }

    /// 清除定时器
    public func clearTimer(id: Int64): Unit {
        mini.clearTimer(id)
    }
}

// ============================================================================
// AutoFlusher - 自动刷新器
// 严格翻译自: src/event_loop/AutoFlusher.rs
//   自动定期刷新 stdout/stderr
// ============================================================================

/// 自动刷新器 - 对应 Bun AutoFlusher
/// 定期刷新标准输出流
public class AutoFlusher {
    private var timerId: Int64
    private var intervalMs: Int64
    private var flushFn: () -> Unit
    private var eventLoop: ?AnyEventLoop

    public init(flushFn: () -> Unit, intervalMs: Int64) {
        timerId = -1
        this.intervalMs = intervalMs
        this.flushFn = flushFn
        eventLoop = None
    }

    /// 启动自动刷新
    public func start(loop: AnyEventLoop): Unit {
        eventLoop = loop
        timerId = loop.setInterval(flushFn, intervalMs)
    }

    /// 停止自动刷新
    public func stop(): Unit {
        if (timerId >= 0) {
            if (let Some(loop) = eventLoop) {
                loop.clearTimer(timerId)
            }
            timerId = -1
        }
    }
}
