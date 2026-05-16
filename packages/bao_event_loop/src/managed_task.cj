// bao_event_loop - 托管任务 (自动释放)
// 严格翻译自: src/event_loop/ManagedTask.zig
//
// Bun 的 ManagedTask:
//   //! This is a slow, dynamically-allocated one-off task
//   //! Use it when you can't add to jsc.Task directly and managing the
//   //! lifetime of the Task struct is overly complex
//
//   const ManagedTask = @This()
//   ctx: ?*anyopaque
//   callback: *const (fn (*anyopaque) bun.JSError!void)
//
//   pub fn run(this: *ManagedTask) bun.JSError!void {
//       @setRuntimeSafety(false)
//       defer bun.default_allocator.destroy(this)  // 运行后自动释放.getOrThrow()
//       const callback = this.callback
//       const ctx = this.ctx
//       try callback(ctx.?)
//   }
//
//   pub fn cancel(this: *ManagedTask) void {
//       this.callback = &struct {
//           fn f(_: *anyopaque) bun.JSError!void {}
//       }.f
//   }
//
//   pub fn New(comptime Type: type, comptime Callback: anytype) type {
//       return struct {
//           pub fn init(ctx: *Type) Task {
//               var managed = bun.handleOom(bun.default_allocator.create(ManagedTask))
//               managed.* = ManagedTask{ .callback = wrap, .ctx = ctx }
//               return managed.task()
//           }
//           pub fn wrap(this: ?*anyopaque) bun.JSError!void {
//               return @call(bun.callmod_inline, Callback, .{@as(*Type, @ptrCast(@alignCast(this.?)))})
//           }
//       }
//   }
//
// 关键特性:
//   1. 一次性: run() 执行后自动释放 (defer destroy)
//   2. 可取消: cancel() 替换回调为空操作
//   3. 动态分配: 每次创建都从堆分配
//   4. 适用场景: 无法将类型直接添加到 Task union 时
//
// 与 AnyTask 的区别:
//   AnyTask: 调用者管理生命周期
//   ManagedTask: 自管理生命周期 (run 后自动释放)
package bao_event_loop

import bao_core.*

// ============================================================================
// ManagedTask - 托管任务 (自动释放)
// 严格翻译自: src/event_loop/ManagedTask.zig
//
// Bun 注释:
//   "This is a slow, dynamically-allocated one-off task
//    Use it when you can't add to jsc.Task directly and
//    managing the lifetime of the Task struct is overly complex"
//
// ManagedTask 的核心设计:
//   1. 动态分配在堆上
//   2. run() 执行后通过 defer 自动释放
//      Bun: defer bun.default_allocator.destroy(this)
//   3. cancel() 替换回调为空操作, 不释放内存
//      Bun: this.callback = &struct { fn f(_: *anyopaque) bun.JSError!void {} }.f
//   4. New(Type, Callback).init(ctx) 分配并返回 Task
//      Bun: bun.default_allocator.create(ManagedTask)
//
// 仓颉实现:
//   使用引用计数或 GC 管理, 不需要手动释放
//   但保留 defer destroy 的语义: run 后标记为已完成
//   由于仓颉有 GC, 不需要手动 destroy, 但保留 disposable 模式
// ============================================================================

/// 托管任务 - 对应 Bun ManagedTask
/// 一次性任务, 执行后自动标记为已完成
/// 适用于无法静态管理任务生命周期的场景
///
/// Bun:
///   "This is a slow, dynamically-allocated one-off task.
///    Use it when you can't add to jsc.Task directly and
///    managing the lifetime of the Task struct is overly complex."
public class ManagedTask {
    /// 任务回调 - 对应 Bun callback: *const fn(*anyopaque) !void
    public var callback: () -> Unit
    /// 上下文 (通过闭包捕获) - 对应 Bun ctx: ?*anyopaque
    public var done: Bool
    /// 是否已取消 - 对应 Bun cancel() 语义
    public var cancelled: Bool
    /// 是否已释放 (对应 Bun defer destroy)
    public var disposed: Bool
    /// 任务标签 (调试用)
    public var label: String

    public init(callback: () -> Unit) {
        this.callback = callback
        done = false
        cancelled = false
        disposed = false
        label = ""
    }

    public init(callback: () -> Unit, label: String) {
        this.callback = callback
        done = false
        cancelled = false
        disposed = false
        this.label = label
    }

    // ========================================================================
    // run - 执行任务并自动释放
    // 严格翻译自: ManagedTask.run
    //
    // Bun:
    //   pub fn run(this: *ManagedTask) bun.JSError!void {
    //       @setRuntimeSafety(false)
    //       defer bun.default_allocator.destroy(this)  // <-- 关键: 自动释放
    //       const callback = this.callback
    //       const ctx = this.ctx
    //       try callback(ctx.?)
    //   }
    //
    // 关键点:
    //   1. defer destroy - 无论成功还是失败, 都释放内存
    //   2. 先保存 callback 和 ctx (防止 use-after-free)
    //   3. 调用 callback(ctx)
    //
    // 仓颉: 使用 disposed 标记代替 defer destroy
    // ========================================================================

    /// 执行任务 - 对应 Bun ManagedTask.run
    /// 执行后自动标记为已释放 (对应 Bun 的 defer destroy)
    public func run(): Unit {
        if (done || cancelled || disposed) {
            return
        }
        // 对应 Bun:
        //   defer bun.default_allocator.destroy(this)
        //   const callback = this.callback
        //   const ctx = this.ctx
        //   try callback(ctx.?)
        let cb = callback
        done = true
        disposed = true
        cb()
    }

    // ========================================================================
    // cancel - 取消任务
    // 严格翻译自: ManagedTask.cancel
    //
    // Bun:
    //   pub fn cancel(this: *ManagedTask) void {
    //       this.callback = &struct {
    //           fn f(_: *anyopaque) bun.JSError!void {}
    //       }.f
    //   }
    //
    // 取消逻辑: 替换回调为空操作
    // 任务仍然会在事件循环中被调度, 但执行时不做任何事
    // ========================================================================

    /// 取消任务 - 对应 Bun ManagedTask.cancel
    /// 将回调替换为空操作 (Bun 的做法)
    public func cancel(): Unit {
        // Bun:
        //   this.callback = &struct { fn f(...) !void {} }.f
        callback = { }
        cancelled = true
    }

    /// 是否已完成
    public func isDone(): Bool {
        return done
    }

    /// 是否已取消
    public func isCancelled(): Bool {
        return cancelled
    }

    /// 是否已释放
    public func isDisposed(): Bool {
        return disposed
    }

    // ========================================================================
    // New - 类型安全的任务创建器
    // 严格翻译自: ManagedTask.New(Type, Callback)
    //
    // Bun:
    //   pub fn New(comptime Type: type, comptime Callback: anytype) type {
    //       return struct {
    //           pub fn init(ctx: *Type) Task {
    //               var managed = bun.handleOom(bun.default_allocator.create(ManagedTask))
    //               managed.* = ManagedTask{ .callback = wrap, .ctx = ctx }
    //               return managed.task()
    //           }
    //           pub fn wrap(this: ?*anyopaque) bun.JSError!void {
    //               return @call(bun.callmod_inline, Callback,
    //                   .{@as(*Type, @ptrCast(@alignCast(this.?)))})
    //           }
    //       }
    //   }
    //
    // 仓颉: 不需要 comptime, 使用泛型和闭包
    // ========================================================================

    /// 创建托管任务 - 对应 Bun ManagedTask.New(Type, Callback).init(ctx)
    /// Bun: 分配 ManagedTask, 设置 callback 和 ctx, 返回 Task
    /// 仓颉: 创建 ManagedTask, 闭包捕获上下文
    public static func create(callback: () -> Unit): ManagedTask {
        return ManagedTask(callback)
    }

    /// 创建带标签的托管任务
    public static func create(callback: () -> Unit, label: String): ManagedTask {
        return ManagedTask(callback, label)
    }

    /// 从回调创建并发任务 - 对应 Bun ConcurrentTask.fromCallback
    /// Bun:
    ///   pub fn fromCallback(ptr: anytype, comptime callback: anytype) *ConcurrentTask {
    ///       return create(ManagedTask.New(std.meta.Child(@TypeOf(ptr)), callback).init(ptr))
    ///   }
    public static func createConcurrent(tag: TaskTagKind, callback: () -> Unit): ConcurrentTask {
        let managed = ManagedTask(callback)
        return ConcurrentTask.createFrom(tag, { => managed.run() }, true)
    }
}
