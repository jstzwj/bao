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
// 注意: JSCScheduler 已移至 jsc_scheduler.cj
// 注意: JSCDeferredWorkTask 已移至 jsc_scheduler.cj

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
        bunVMEventLoopRefConcurrently()
    } else {
        bunVMEventLoopUnrefConcurrently()
    }
}

// ========== Bun__queueJSCDeferredWorkTaskConcurrently ==========
public func queueJSCDeferredWorkTaskConcurrently(jscVm: BunVirtualMachine, task: JSCDeferredWorkTask) {
    bunVMEnqueueDeferredWorkTask(task)
}

// ========== Bun__tickWhilePaused ==========
public func tickWhilePaused(paused: Bool) {
    bunVMEventLoopTickWhilePaused(paused)
}
