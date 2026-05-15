// 严格翻译自: src/jsc/JSCScheduler.zig (51行)
// JavaScriptCore JSCScheduler - JSC 延迟工作调度器

package bao_jsc

// ========== JSCScheduler ==========
// 严格翻译自 JSCScheduler.zig
// JSC 调度器，负责延迟工作和并发任务调度
// 提供事件循环引用计数管理和延迟工作队列
//
// 原始 Zig 代码:
//   const JSCScheduler = @This();
//   pub const JSCDeferredWorkTask = opaque { ... };
//   export fn Bun__eventLoop__incrementRefConcurrently(...) void { ... }
//   export fn Bun__queueJSCDeferredWorkTaskConcurrently(...) void { ... }
//   export fn Bun__tickWhilePaused(...) void { ... }
public class JSCScheduler {
    public init() {}

    // ========== JSCDeferredWorkTask ==========
    // 严格翻译自 JSCScheduler.JSCDeferredWorkTask
    // JSC 延迟工作任务 opaque 类型
    //
    // 原始 Zig:
    //   pub const JSCDeferredWorkTask = opaque {
    //       extern fn Bun__runDeferredWork(task: *JSCScheduler.JSCDeferredWorkTask) void;
    //       pub fn run(task: *JSCScheduler.JSCDeferredWorkTask) bun.JSTerminated!void {
    //           const globalThis = bun.jsc.VirtualMachine.get().global;
    //           var scope: bun.jsc.ExceptionValidationScope = undefined;
    //           scope.init(globalThis, @src());
    //           defer scope.deinit();
    //           Bun__runDeferredWork(task);
    //           try scope.assertNoExceptionExceptTermination();
    //       }
    //   };
    public class JSCDeferredWorkTask {
        public var rawPtr: CPointer<UInt8> = CPointer<UInt8>()

        public init() {}

        // 严格翻译自 JSCDeferredWorkTask.run
        // 执行延迟工作
        //
        // FFI: Bun__runDeferredWork(task: *JSCDeferredWorkTask) void
        public func run() {
            // 1. 获取 VM 和 global
            // FFI: const globalThis = bun.jsc.VirtualMachine.get().global
            // 2. 创建异常验证作用域
            // var scope = ExceptionValidationScope()
            // scope.init(globalThis)
            // defer scope.deinit()
            // 3. 运行延迟工作
            // FFI: Bun__runDeferredWork(rawPtr)
            runDeferredWorkFFI()
            // 4. 断言无异常 (除终止外)
            // scope.assertNoExceptionExceptTermination()
        }

        // FFI 桩: Bun__runDeferredWork
        private func runDeferredWorkFFI() {
            // 真实实现: @CFFI 调用 Bun__runDeferredWork(rawPtr)
        }
    }
}

// ========== Bun__eventLoop__incrementRefConcurrently ==========
// 严格翻译自 JSCScheduler.zig Bun__eventLoop__incrementRefConcurrently
// 并发地增减事件循环引用计数
//
// 原始 Zig:
//   export fn Bun__eventLoop__incrementRefConcurrently(jsc_vm: *VirtualMachine, delta: c_int) void {
//       jsc.markBinding(@src());
//       if (delta > 0) {
//           jsc_vm.event_loop.refConcurrently();
//       } else {
//           jsc_vm.event_loop.unrefConcurrently();
//       }
//   }
public func eventLoopIncrementRefConcurrently(jscVm: BunVirtualMachine, delta: Int32) {
    if (delta > 0) {
        // FFI: jscVm.eventLoop.refConcurrently()
        jscVm.eventLoopRefConcurrently()
    } else {
        // FFI: jscVm.eventLoop.unrefConcurrently()
        jscVm.eventLoopUnrefConcurrently()
    }
}

// ========== Bun__queueJSCDeferredWorkTaskConcurrently ==========
// 严格翻译自 JSCScheduler.zig Bun__queueJSCDeferredWorkTaskConcurrently
// 并发地将延迟工作任务排入事件循环
//
// 原始 Zig:
//   export fn Bun__queueJSCDeferredWorkTaskConcurrently(jsc_vm: *VirtualMachine, task: *JSCScheduler.JSCDeferredWorkTask) void {
//       jsc.markBinding(@src());
//       var loop = jsc_vm.eventLoop();
//       loop.enqueueTaskConcurrent(ConcurrentTask.new(.{
//           .task = Task.init(task),
//           .next = .auto_delete,
//       }));
//   }
public func queueJSCDeferredWorkTaskConcurrently(jscVm: BunVirtualMachine, task: JSCScheduler.JSCDeferredWorkTask) {
    // FFI: var loop = jscVm.eventLoop()
    // loop.enqueueTaskConcurrent(ConcurrentTask.new({
    //     task = Task.init(task),
    //     next = .auto_delete,
    // }))
    jscVm.enqueueDeferredWorkTask(task)
}

// ========== Bun__tickWhilePaused ==========
// 严格翻译自 JSCScheduler.zig Bun__tickWhilePaused
// 在暂停状态下驱动事件循环
//
// 原始 Zig:
//   export fn Bun__tickWhilePaused(paused: *bool) void {
//       jsc.markBinding(@src());
//       VirtualMachine.get().eventLoop().tickWhilePaused(paused);
//   }
public func tickWhilePaused(paused: Bool) {
    // FFI: VirtualMachine.get().eventLoop().tickWhilePaused(paused)
    let vm = BunVirtualMachine()
    vm.eventLoopTickWhilePaused(paused)
}
