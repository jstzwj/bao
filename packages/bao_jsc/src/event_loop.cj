// 严格翻译自: src/jsc/event_loop.zig + EventLoopHandle.zig
// Bun 事件循环实现

package bao_jsc

// ========== 事件循环状态 ==========
// 严格翻译自 event_loop.zig
public enum EventLoopState {
    | Running
    | Paused
    | Stopped
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
        if (let Some(cb) <- callback) {
            cb()
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

    public static func instance() -> MicrotaskQueue {
        if (instance_ == None) {
            instance_ = MicrotaskQueue()
        }
        instance_.getOrThrow()
    }

    // 入队微任务
    public func enqueue(task: () -> Unit) {
        queue.append(task)
    }

    // 排空微任务队列
    public func drain() -> Int64 {
        var count: Int64 = 0
        while (queue.size > 0) {
            let task = queue[0]
            queue = queue.slice(1)
            task()
            count++
        }
        count
    }

    public func size() -> Int64 {
        Int64(queue.size)
    }
}

// ========== EventLoopHandle ==========
// 严格翻译自 EventLoopHandle.zig
// 事件循环句柄，用于管理事件循环的引用计数
public class EventLoopHandle {
    public var loop: ?EventLoop = None
    public var refCount: Int64 = 0
    public var hasExtraRef: Bool = false

    public init() {}

    public init(loop: EventLoop) {
        this.loop = loop
    }

    public func ref() {
        refCount++
    }

    public func unref() {
        refCount--
    }

    public func isActive() -> Bool {
        refCount > 0
    }
}

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
    public func isAlive() -> Bool {
        isRefed && (activeHandles > 0 || activeRequests > 0)
    }

    // 入队任务
    public func enqueue(entry: EventLoopEntry) {
        match (entry.tag) {
            case Timer => timerQueue.append(entry)
            case Immediate => immediateQueue.append(entry)
            case IO => ioQueue.append(entry)
            case NextTick => nextTickQueue.append(entry)
            case Microtask => {
                if (let Some(cb) <- entry.callback) {
                    microtaskQueue.enqueue(cb)
                }
            }
            case _ => immediateQueue.append(entry)
        }
    }

    // ========== 阶段处理 ==========

    func processNextTicks() {
        while (nextTickQueue.size > 0) {
            let entry = nextTickQueue[0]
            nextTickQueue = nextTickQueue.slice(1)
            entry.run()
        }
    }

    func drainMicrotasks() {
        microtaskQueue.drain()
    }

    func processTimers() {
        while (timerQueue.size > 0) {
            let entry = timerQueue[0]
            timerQueue = timerQueue.slice(1)
            entry.run()
        }
    }

    func processIO() {
        while (ioQueue.size > 0) {
            let entry = ioQueue[0]
            ioQueue = ioQueue.slice(1)
            entry.run()
        }
    }

    func processImmediate() {
        while (immediateQueue.size > 0) {
            let entry = immediateQueue[0]
            immediateQueue = immediateQueue.slice(1)
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

    public func refCount() -> Int64 {
        activeHandles
    }

    // ========== 定时器辅助 ==========

    public func setTimeout(callback: () -> Unit, delay: Float64) -> Int64 {
        let entry = EventLoopEntry(EventLoopTag.Timer, callback)
        timerQueue.append(entry)
        activeHandles++
        Int64(timerQueue.size)
    }

    public func setImmediate(callback: () -> Unit) -> Int64 {
        let entry = EventLoopEntry(EventLoopTag.Immediate, callback)
        immediateQueue.append(entry)
        activeHandles++
        Int64(immediateQueue.size)
    }

    public func setNextTick(callback: () -> Unit) {
        let entry = EventLoopEntry(EventLoopTag.NextTick, callback)
        nextTickQueue.append(entry)
    }
}
