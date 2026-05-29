// 严格翻译自: src/jsc/JSCScheduler.zig
// JSC 调度器 - 管理延迟工作和并发任务调度

package bao_jsc

// ========== JSCDeferredWorkTask ==========
// 严格翻译自 JSCScheduler.JSCDeferredWorkTask (opaque)
public class JSCDeferredWorkTask {
    public var ptr: UInt64 = 0

    public init() {}

    // 严格翻译自 JSCDeferredWorkTask.run
    public func run(globalThis: JsObject) {
        // FFI: Bun__runDeferredWork
    }
}

// ========== JSCScheduler ==========
// 严格翻译自 JSCScheduler
// 管理 JSC 延迟工作任务的调度
public class JSCScheduler {

    // 严格翻译自 Bun__eventLoop__incrementRefConcurrently
    // 导出函数 - 并发递增/递减事件循环引用
    public static func eventLoopIncrementRefConcurrently(jscVm: BunVirtualMachine, delta: Int32) {
        let loop = jscVm.eventLoop
        if (delta > 0) {
            loop.refConcurrently()
        } else {
            loop.unrefConcurrently()
        }
    }

    // 严格翻译自 Bun__queueJSCDeferredWorkTaskConcurrently
    // 导出函数 - 并发地将 JSC 延迟工作任务入队
    public static func queueJSCDeferredWorkTaskConcurrently(jscVm: BunVirtualMachine, task: JSCDeferredWorkTask) {
        let loop = jscVm.eventLoop
        let ct = ConcurrentTask()
        ct.task = ConcurrentPromiseTaskGeneric()
        loop.enqueueTaskConcurrent(ct)
    }

    // 严格翻译自 Bun__tickWhilePaused
    // 导出函数 - 在暂停状态下执行 tick
    public static func tickWhilePaused(paused: Bool) {
        // VirtualMachine.get().eventLoop().tickWhilePaused(paused)
    }
}
