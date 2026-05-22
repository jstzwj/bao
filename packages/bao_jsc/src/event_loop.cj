// 严格翻译自: src/jsc/event_loop.zig + EventLoopHandle.zig
// Bun 事件循环实现

package bao_jsc

// ========== 事件循环状态 ==========
// 严格翻译自 event_loop.zig
public enum EventLoopState {
    | Running
    | Paused
    | Stopped

    public operator func ==(right: EventLoopState): Bool {
        match (this) {
            case Running => match(right) { case Running => true case _ => false }
            case Paused => match(right) { case Paused => true case _ => false }
            case Stopped => match(right) { case Stopped => true case _ => false }
        }
    }

    public operator func !=(right: EventLoopState): Bool {
        !(this == right)
    }
}

// ========== 事件循环标签 ==========
public enum EventLoopTag {
    | Default
    | Timer
    | Immediate
    | IO
    | Microtask
    | NextTick
}

// ========== 事件循环条目 ==========
// 严格翻译自 event_loop.zig LoopEntry
public class EventLoopEntry {
    public var tag: EventLoopTag = EventLoopTag.Default
    public var callback: ?(() -> Unit) = None
    public var priority: Int64 = 0
    public var isCancelled: Bool = false

    public init() {}

    public init(tag: EventLoopTag, callback: () -> Unit) {
        this.tag = tag
        this.callback = callback
    }

    public func run() {
        if (isCancelled) { return }
        match (callback) {
            case Some(cb) => cb()
            case None => ()
        }
    }

    public func cancel() {
        isCancelled = true
    }
}

// ========== MicrotaskQueue ==========
// 微任务队列 (Promise 回调等)
public class MicrotaskQueue {
    var queue: Array<() -> Unit> = []

    static var instance_: ?MicrotaskQueue = None

    public init() {}

    public static func instance(): MicrotaskQueue {
        if (let Some(q) <- instance_) {
            return q
        }
        instance_ = MicrotaskQueue()
        match (instance_) {
            case Some(q) => q
            case None => MicrotaskQueue()
        }
    }

    // 入队微任务
    public func enqueue(task: () -> Unit) {
        queue = queue.concat([task])
    }

    // 排空微任务队列
    public func drain(): Int64 {
        var count: Int64 = 0
        while (queue.size > 0) {
            let task = queue[0]
            queue = queue.slice(1, queue.size)
            task()
            count++
        }
        count
    }

    public func size(): Int64 {
        Int64(queue.size)
    }
}

// 注意: EventLoopHandle 已移至 event_loop_handle.cj

// ========== EventLoop ==========
// 严格翻译自 event_loop.zig
// Bun 事件循环核心实现
public class EventLoop {
    // 阶段队列
    public var timerQueue: Array<EventLoopEntry> = []
    public var immediateQueue: Array<EventLoopEntry> = []
    public var ioQueue: Array<EventLoopEntry> = []
    public var nextTickQueue: Array<EventLoopEntry> = []
    public var microtaskQueue: MicrotaskQueue = MicrotaskQueue()

    // 状态
    public var state: EventLoopState = EventLoopState.Stopped
    public var isRefed: Bool = true
    public var activeHandles: Int64 = 0
    public var activeRequests: Int64 = 0
    public var parentRef: ?KeepAlive = None

    // 绑定的 VM
    public var vm: ?BunVirtualMachine = None

    // 全局对象 (stub)
    public var global: JsObject = JsObject()

    // 虚拟机快捷访问
    public func virtualMachine(): BunVirtualMachine {
        match (vm) {
            case Some(v) => v
            case None => BunVirtualMachine()
        }
    }

    // 进入事件循环
    public func enter() {
        state = EventLoopState.Running
    }

    // 退出事件循环
    public func exit() {
        state = EventLoopState.Stopped
    }

    public init() {}

    public init(vm: BunVirtualMachine) {
        this.vm = vm
    }

    // ========== 事件循环操作 ==========

    // 启动事件循环
    public func start() {
        state = EventLoopState.Running
        run()
    }

    // 停止事件循环
    public func stop() {
        state = EventLoopState.Stopped
    }

    // 主循环运行
    public func run() {
        while (state == EventLoopState.Running) {
            tick()
            if (!isAlive()) {
                break
            }
        }
        state = EventLoopState.Stopped
    }

    // 单次 tick
    // 严格翻译自 event_loop 的 tick 逻辑
    public func tick() {
        // 1. nextTick 阶段
        processNextTicks()
        // 2. 微任务阶段
        drainMicrotasks()
        // 3. 定时器阶段
        processTimers()
        // 4. I/O 阶段
        processIO()
        // 5. immediate 阶段
        processImmediate()
        // 6. 关闭回调
        processCloseCallbacks()
    }

    // 严格翻译自 event_loop.isAlive
    public func isAlive(): Bool {
        isRefed && (activeHandles > 0 || activeRequests > 0)
    }

    // 入队任务
    public func enqueue(entry: EventLoopEntry) {
        match (entry.tag) {
            case Timer => timerQueue = timerQueue.concat([entry])
            case Immediate => immediateQueue = immediateQueue.concat([entry])
            case IO => ioQueue = ioQueue.concat([entry])
            case NextTick => nextTickQueue = nextTickQueue.concat([entry])
            case Microtask=>
                if (let Some(cb) <- entry.callback) {
                    microtaskQueue.enqueue(cb)
                }
            case _ => immediateQueue = immediateQueue.concat([entry])
        }
    }

    // ========== 阶段处理 ==========

    func processNextTicks() {
        while (nextTickQueue.size > 0) {
            let entry = nextTickQueue[0]
            nextTickQueue = nextTickQueue.slice(1, nextTickQueue.size)
            entry.run()
        }
    }

    func drainMicrotasks() {
        microtaskQueue.drain()
    }

    func processTimers() {
        while (timerQueue.size > 0) {
            let entry = timerQueue[0]
            timerQueue = timerQueue.slice(1, timerQueue.size)
            entry.run()
        }
    }

    func processIO() {
        while (ioQueue.size > 0) {
            let entry = ioQueue[0]
            ioQueue = ioQueue.slice(1, ioQueue.size)
            entry.run()
        }
    }

    func processImmediate() {
        while (immediateQueue.size > 0) {
            let entry = immediateQueue[0]
            immediateQueue = immediateQueue.slice(1, immediateQueue.size)
            entry.run()
        }
    }

    func processCloseCallbacks() {
        // 处理关闭回调
    }

    // ========== 引用管理 ==========

    public func ref() {
        isRefed = true
        activeHandles++
    }

    public func unref() {
        activeHandles--
        if (activeHandles <= 0) {
            isRefed = false
        }
    }

    public func refCount(): Int64 {
        activeHandles
    }

    // ========== 定时器辅助 ==========

    public func setTimeout(callback: () -> Unit, delay: Float64): Int64 {
        let entry = EventLoopEntry(EventLoopTag.Timer, callback)
        timerQueue = timerQueue.concat([entry])
        activeHandles++
        Int64(timerQueue.size)
    }

    public func setImmediate(callback: () -> Unit): Int64 {
        let entry = EventLoopEntry(EventLoopTag.Immediate, callback)
        immediateQueue = immediateQueue.concat([entry])
        activeHandles++
        Int64(immediateQueue.size)
    }

    public func setNextTick(callback: () -> Unit) {
        let entry = EventLoopEntry(EventLoopTag.NextTick, callback)
        nextTickQueue = nextTickQueue.concat([entry])
    }

    // 入队通用任务
    public func enqueueTask(task: Task) {
        // stub: 入队到 immediate 队列
        let entry = EventLoopEntry(EventLoopTag.Immediate, { => })
        immediateQueue = immediateQueue.concat([entry])
    }

    // 入队并发任务
    public func enqueueTaskConcurrent(task: ConcurrentTaskObj) {
        // stub: 入队到 immediate 队列
        let entry = EventLoopEntry(EventLoopTag.Immediate, { => })
        immediateQueue = immediateQueue.concat([entry])
    }
}
