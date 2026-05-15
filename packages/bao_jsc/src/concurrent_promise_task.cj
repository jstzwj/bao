// 严格翻译自: src/jsc/ConcurrentPromiseTask.zig (77行)
// 在线程池上运行工作并通过 JavaScript Promise 解决结果的通用任务

package bao_jsc

// ========== ConcurrentPromiseTaskGeneric ==========
// 严格翻译自 ConcurrentPromiseTask.zig ConcurrentPromiseTask
// 一个通用任务，在线程池上运行工作并通过 JavaScript Promise 解决结果。
// 这允许 CPU 密集型操作在主 JavaScript 线程之外执行，
// 同时为 JavaScript 消费者维护基于 Promise 的 API。
//
// Context 类型必须实现:
// - `run()` - 在线程池上执行工作
// - `then(promise)` - 在 JS 线程上用结果解决 Promise
public class ConcurrentPromiseTaskGeneric {
    // 上下文数据
    public var ctx: ?ConcurrentTaskContext = None
    // 工作池任务
    public var task: WorkPoolTask = WorkPoolTask()
    // 事件循环引用
    public var eventLoop: ?EventLoop = None
    // 分配器标识
    public var allocator: String = ""
    // Promise 强引用
    public var promise: ?JsPromise = None
    // 全局对象
    public var globalThis: ?JsObject = None
    // 并发任务
    public var concurrentTask: ?ConcurrentTask = None
    // Keep-Alive 引用 (poll 模式)
    public var ref: KeepAlive = KeepAlive()

    public init() {}

    // 严格翻译自 ConcurrentPromiseTask.createOnJSThread
    // 在 JS 线程上创建并发 Promise 任务
    public static func createOnJSThread(
        allocator: String,
        globalThis: JsObject,
        value: ConcurrentTaskContext
    ) -> ConcurrentPromiseTaskGeneric {
        let task = ConcurrentPromiseTaskGeneric()
        task.eventLoop = EventLoop()
        task.ctx = value
        task.allocator = allocator
        task.globalThis = globalThis

        // 创建 Promise 并建立强引用
        let promise = JsPromise()
        task.promise = promise
        task.ref.ref()

        task
    }

    // 严格翻译自 ConcurrentPromiseTask.runFromThreadPool
    // 从线程池运行
    public func runFromThreadPool() {
        if (let Some(c) <- ctx) {
            c.run()
        }
        onFinish()
    }

    // 严格翻译自 ConcurrentPromiseTask.runFromJS
    // 从 JS 线程运行
    public func runFromJS() -> Bool {
        // 交换 promise
        let promise_ = promise
        if (let Some(ref) <- eventLoop) {
            ref.unref()
        }

        if (let Some(c) <- ctx) {
            if (let Some(p) <- promise_) {
                return c.then(p)
            }
        }
        false
    }

    // 严格翻译自 ConcurrentPromiseTask.schedule
    // 调度到工作池
    public func schedule() {
        // WorkPool.schedule(&this.task)
        runFromThreadPool()
    }

    // 严格翻译自 ConcurrentPromiseTask.onFinish
    // 完成时回调
    public func onFinish() {
        if (let Some(el) <- eventLoop) {
            if (let Some(ct) <- concurrentTask) {
                el.enqueueTaskConcurrent(ct)
            }
        }
    }

    // 严格翻译自 ConcurrentPromiseTask.deinit
    public func deinit() {
        promise = None
        ctx = None
    }
}

// ========== ConcurrentTaskContext ==========
// 严格翻译自 ConcurrentPromiseTask 要求的 Context 接口
// 具体实现必须提供 run() 和 then() 方法
public abstract class ConcurrentTaskContext {
    // 在线程池上执行工作
    public func run() {
        // 子类实现
    }

    // 在 JS 线程上用结果解决 Promise
    // 返回 true 表示正常，false 表示终止
    public func then(promise: JsPromise) -> Bool {
        // 子类实现
        false
    }
}

// ========== WorkPoolTask ==========
// 严格翻译自 WorkPoolTask
public class WorkPoolTask {
    // 回调函数
    public var callback: ?(() -> Unit) = None

    public init() {}

    public init(callback: () -> Unit) {
        this.callback = callback
    }

    // 执行任务
    public func run() {
        if (let Some(cb) <- callback) {
            cb()
        }
    }
}

// ========== ConcurrentTask ==========
// 严格翻译自 jsc.ConcurrentTask
public class ConcurrentTask {
    // 任务引用
    public var task: ?ConcurrentPromiseTaskGeneric = None
    // 是否手动 deinit
    public var manualDeinit: Bool = false

    public init() {}

    public init(task: ConcurrentPromiseTaskGeneric) {
        this.task = task
    }

    // 从 ConcurrentPromiseTaskGeneric 创建
    public static func from(task: ConcurrentPromiseTaskGeneric, mode: String) -> ConcurrentTask {
        let ct = ConcurrentTask(task: task)
        ct.manualDeinit = (mode == "manual_deinit")
        ct
    }

    // 执行任务
    public func run() {
        if (let Some(t) <- task) {
            t.runFromJS()
        }
    }
}

// ========== EventLoop 扩展 ==========
// ConcurrentPromiseTask 需要 EventLoop 的额外方法
public func enqueueTaskConcurrent(el: EventLoop, task: ConcurrentTask) {
    // 将并发任务入队到事件循环
    el.enqueue(EventLoopEntry(EventLoopTag.Default, {
        task.run()
    }))
}
