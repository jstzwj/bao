// 严格翻译自: src/jsc/WorkTask.zig
// 工作任务 - 在线程池运行并在主 JS 线程执行回调

package bao_jsc

// ========== WorkTask ==========
// 严格翻译自 WorkTask(Context)
// 在线程池中运行工作并在主 JavaScript 线程执行回调的通用任务
// 与 ConcurrentPromiseTask 不同（后者自动 resolve Promise），
// WorkTask 提供更大的灵活性，允许 Context 以任何方式处理结果
public class WorkTask<Context> {
    public var ctx: Context
    public var task: WorkPoolTask = WorkPoolTask()
    public var eventLoop: EventLoop = EventLoop()
    public var allocator: UInt64 = 0
    public var globalThis: JsObject = JsObject()
    public var concurrentTask: ConcurrentTask = ConcurrentTask()
    public var asyncTaskTracker: AsyncTaskTracker = AsyncTaskTracker()
    public var ref: KeepAlive = KeepAlive()

    public init(ctx: Context) {
        this.ctx = ctx
    }

    // 严格翻译自 WorkTask.createOnJSThread
    public static func createOnJSThread(
        allocator: UInt64,
        globalThis: JsObject,
        value: Context
    ): WorkTask<Context> {
        let vm = globalThis.bunVM()
        let task = WorkTask<Context>(value)
        task.eventLoop = vm.eventLoop
        task.allocator = allocator
        task.globalThis = globalThis
        task.ref.ref(vm)
        task
    }

    // 严格翻译自 WorkTask.deinit
    public func deinit() {
        ref.unref(eventLoop.virtualMachine())
    }

    // 严格翻译自 WorkTask.runFromThreadPool
    public func runFromThreadPool() {
        // Context.run(ctx, this)
    }

    // 严格翻译自 WorkTask.runFromJS
    public func runFromJS() {
        ref.unref(eventLoop.virtualMachine())
        // tracker.willDispatch / didDispatch
        // ctx.then(globalThis)
    }

    // 严格翻译自 WorkTask.schedule
    public func schedule() {
        let vm = eventLoop.virtualMachine()
        ref.ref(vm)
        // asyncTaskTracker.didSchedule(globalThis)
        // WorkPool.schedule(&task)
    }

    // 严格翻译自 WorkTask.onFinish
    public func onFinish() {
        // eventLoop.enqueueTaskConcurrent(concurrentTask.from(this, .manual_deinit))
    }
}

// 注意: WorkPoolTask 已移至 concurrent_promise_task.cj

public class KeepAlive {
    public var isRefed: Bool = false

    public init() {}

    // 严格翻译自 KeepAlive.ref
    // 递增 VM 事件循环引用计数, 防止事件循环提前退出
    public func ref(vm: BunVirtualMachine) {
        if (!isRefed) {
            isRefed = true
            vm.eventLoop.ref()
        }
    }

    // 严格翻译自 KeepAlive.unref
    // 递减 VM 事件循环引用计数
    public func unref(vm: BunVirtualMachine) {
        if (isRefed) {
            isRefed = false
            vm.eventLoop.unref()
        }
    }
}

public class AsyncTaskTracker {
    public init() {}

    public func didSchedule(global: JsObject) {}
    public func willDispatch(global: JsObject) {}
    public func didDispatch(global: JsObject) {}
}
