// bao_event_loop - 类型擦除的任务包装
// 严格翻译自: src/event_loop/AnyTask.zig + src/event_loop/AnyTaskWithExtraContext.zig
//
// Bun 的 AnyTask:
//   const AnyTask = @This()
//   ctx: ?*anyopaque
//   callback: *const (fn (*anyopaque) bun.JSError!void)
//
//   pub fn run(this: *AnyTask) bun.JSError!void {
//       const callback = this.callback
//       const ctx = this.ctx
//       try callback(ctx.?)
//   }
//
//   pub fn New(comptime Type: type, comptime Callback: anytype) type {
//       return struct {
//           pub fn init(ctx: *Type) AnyTask {
//               return AnyTask{ .callback = wrap, .ctx = ctx }
//           }
//           pub fn wrap(this: ?*anyopaque) bun.JSError!void {
//               return @call(bun.callmod_inline, Callback, .{@as(*Type, @ptrCast(@alignCast(this.?)))})
//           }
//       }
//   }
//
// Bun 的 AnyTaskWithExtraContext:
//   const AnyTaskWithExtraContext = @This()
//   ctx: ?*anyopaque = undefined
//   callback: *const (fn (*anyopaque, *anyopaque) void) = undefined
//   next: ?*AnyTaskWithExtraContext = null
//
//   pub fn run(this: *AnyTaskWithExtraContext, extra: *anyopaque) void {
//       const callback = this.callback
//       const ctx = this.ctx
//       callback(ctx.?, extra)
//   }
//
//   pub fn fromCallbackAutoDeinit(ptr, comptime fieldName) *AnyTaskWithExtraContext
//     创建自动清理的任务包装
//
//   pub fn New(comptime Type, comptime ContextType, comptime Callback) type
//     创建类型安全的任务包装器 (两个上下文指针)
//
// 仓颉翻译:
//   由于仓颉没有 comptime 泛型, 使用闭包捕获上下文
//   AnyTask - 单上下文任务的类型擦除包装
//   AnyTaskWithExtraContext - 双上下文任务的类型擦除包装
package bao_event_loop

import bao_core.*

// ============================================================================
// AnyTask - 类型擦除的通用任务
// 严格翻译自: src/event_loop/AnyTask.zig
//
// Bun 的 AnyTask 是一个函数指针 + 上下文指针的包装:
//   ctx: ?*anyopaque                           - 类型擦除的上下文
//   callback: *const fn(*anyopaque) !void      - 回调函数指针
//
// 这比直接将任务类型添加到 Task union 慢,
// 但在无法静态知道任务类型时使用
//
// Bun 注释: "This is a slower wrapper around a function pointer.
//            Prefer adding a task type directly to `Task` instead of using this."
// ============================================================================

/// 类型擦除的通用任务 - 对应 Bun AnyTask
/// 包装一个闭包, 可以在任何需要 Task 的地方使用
/// 性能略低于直接使用具体 Task 类型, 但提供了灵活性
public class AnyTask {
    /// 任务回调 - 对应 Bun callback: *const fn(*anyopaque) !void
    /// 仓颉: 使用闭包代替函数指针 + void 指针
    public var callback: () -> Unit
    /// 是否已完成
    public var done: Bool
    /// 任务标签 (用于调试和调度)
    public var label: String

    public init(callback: () -> Unit) {
        this.callback = callback
        done = false
        label = ""
    }

    public init(callback: () -> Unit, label: String) {
        this.callback = callback
        done = false
        this.label = label
    }

    /// 执行任务 - 对应 Bun AnyTask.run
    /// Bun:
    ///   pub fn run(this: *AnyTask) bun.JSError!void {
    ///       @setRuntimeSafety(false)
    ///       const callback = this.callback
    ///       const ctx = this.ctx
    ///       try callback(ctx.?)
    ///   }
    public func run(): Unit {
        if (!done) {
            callback()
            done = true
        }
    }

    /// 创建任务 - 对应 Bun AnyTask.New(Type, Callback).init(ctx)
    /// 仓颉: 使用闭包捕获上下文, 无需 comptime 泛型
    /// Bun:
    ///   pub fn New(comptime Type: type, comptime Callback: anytype) type {
    ///       return struct {
    ///           pub fn init(ctx: *Type) AnyTask {
    ///               return AnyTask{ .callback = wrap, .ctx = ctx }
    ///           }
    ///           pub fn wrap(this: ?*anyopaque) bun.JSError!void {
    ///               return @call(bun.callmod_inline, Callback, .{@as(*Type, @ptrCast(@alignCast(this.?)))})
    ///           }
    ///       }
    ///   }
    public static func create(callback: () -> Unit): AnyTask {
        return AnyTask(callback)
    }

    /// 创建带标签的任务
    public static func create(callback: () -> Unit, label: String): AnyTask {
        return AnyTask(callback, label)
    }

    /// 取消任务 (标记为已完成但不执行)
    public func cancel(): Unit {
        done = true
    }

    /// 是否已完成
    public func isDone(): Bool {
        return done
    }
}

// ============================================================================
// AnyTaskWithExtraContext - 带额外上下文的类型擦除任务
// 严格翻译自: src/event_loop/AnyTaskWithExtraContext.zig
//
// Bun:
//   const AnyTaskWithExtraContext = @This()
//   ctx: ?*anyopaque = undefined
//   callback: *const (fn (*anyopaque, *anyopaque) void) = undefined
//   next: ?*AnyTaskWithExtraContext = null
//
// 这是 AnyTask 的双指针版本: 给你两个指针而非一个
// Bun 注释: "This is AnyTask except it gives you two pointers instead of one.
//            Generally, prefer jsc.Task instead of this."
//
// 使用场景:
//   - 需要同时传递任务上下文和事件循环上下文
//   - MiniEventLoop 的 Task 类型就是 AnyTaskWithExtraContext
//   - ConcurrentTaskQueue 使用其作为队列元素类型
// ============================================================================

/// 带额外上下文的类型擦除任务 - 对应 Bun AnyTaskWithExtraContext
/// 可以携带两个独立的上下文 (主上下文 + 额外上下文)
/// 使用场景: MiniEventLoop 任务队列中的任务类型
public class AnyTaskWithExtraContext {
    /// 任务回调 - 对应 Bun callback: *const fn(*anyopaque, *anyopaque) void
    /// 仓颉: 使用闭包捕获两个上下文
    public var callback: () -> Unit
    /// 是否自动清理 - 对应 Bun fromCallbackAutoDeinit 语义
    public var autoDeinit: Bool
    /// 是否已完成
    public var done: Bool

    /// MPSC 链接指针 - 对应 Bun next: ?*AnyTaskWithExtraContext = null
    /// Bun: ConcurrentTaskQueue = UnboundedQueue(AnyTaskWithExtraContext, .next)
    /// 使用侵入式链表, next 字段内嵌在结构中
    /// 仓颉: 不直接使用侵入式链表, 此字段标识队列状态
    public var next: ?AnyTaskWithExtraContext

    public init(callback: () -> Unit) {
        this.callback = callback
        autoDeinit = true
        done = false
        next = None
    }

    public init(callback: () -> Unit, autoDeinit: Bool) {
        this.callback = callback
        this.autoDeinit = autoDeinit
        done = false
        next = None
    }

    /// 执行任务 - 对应 Bun AnyTaskWithExtraContext.run(extra)
    /// Bun:
    ///   pub fn run(this: *AnyTaskWithExtraContext, extra: *anyopaque) void {
    ///       @setRuntimeSafety(false)
    ///       const callback = this.callback
    ///       const ctx = this.ctx
    ///       callback(ctx.?, extra)
    ///   }
    ///
    /// 仓颉: extra 上下文已通过闭包捕获, 此处直接执行
    public func run(): Unit {
        if (!done) {
            callback()
            done = true
        }
    }

    /// 带额外上下文执行 - 对应 Bun run(this, extra)
    /// 用于需要传递外部上下文给任务的场景
    /// 仓颉: 使用回调传递额外数据
    public func runWith(extra: () -> Unit): Unit {
        if (!done) {
            callback()
            extra()
            done = true
        }
    }

    /// 从回调创建 (自动清理) - 对应 Bun fromCallbackAutoDeinit
    /// Bun:
    ///   pub fn fromCallbackAutoDeinit(ptr: anytype, comptime fieldName: [:0]const u8)
    ///       *AnyTaskWithExtraContext
    ///   {
    ///       const Wrapper = struct {
    ///           any_task: AnyTaskWithExtraContext,
    ///           wrapped: *Ptr,
    ///           pub fn function(this: *anyopaque, extra: *anyopaque) void {
    ///               const that: *@This() = @ptrCast(@alignCast(this))
    ///               defer bun.default_allocator.destroy(that)
    ///               const ctx = that.wrapped
    ///               @field(Ptr, fieldName)(ctx, extra)
    ///           }
    ///       }
    ///       const task = bun.handleOom(bun.default_allocator.create(Wrapper))
    ///       task.* = Wrapper{ .any_task = ..., .wrapped = ptr }
    ///       return &task.any_task
    ///   }
    public static func fromCallbackAutoDeinit(callback: () -> Unit): AnyTaskWithExtraContext {
        return AnyTaskWithExtraContext(callback, true)
    }

    /// 从回调创建 (手动清理)
    public static func fromCallback(callback: () -> Unit): AnyTaskWithExtraContext {
        return AnyTaskWithExtraContext(callback, false)
    }

    /// 取消任务
    public func cancel(): Unit {
        done = true
    }

    /// 是否已完成
    public func isDone(): Bool {
        return done
    }

    /// 是否应该自动释放
    public func shouldAutoDeinit(): Bool {
        return autoDeinit
    }
}

// ============================================================================
// AnyTaskBuilder - AnyTask 构建器
// 提供流畅的 API 构建任务
// ============================================================================

/// AnyTask 构建器 - 便捷创建 AnyTask
public class AnyTaskBuilder {
    private var callback: () -> Unit
    private var label: String

    public init() {
        callback = { }
        label = ""
    }

    /// 设置回调
    public func withCallback(cb: () -> Unit): AnyTaskBuilder {
        callback = cb
        return this
    }

    /// 设置标签
    public func withLabel(label: String): AnyTaskBuilder {
        this.label = label
        return this
    }

    /// 构建 AnyTask
    public func build(): AnyTask {
        return AnyTask(callback, label)
    }

    /// 构建 AnyTaskWithExtraContext
    public func buildWithExtraContext(): AnyTaskWithExtraContext {
        return AnyTaskWithExtraContext(callback, true)
    }
}
