// bao_event_loop - AnyTaskWithExtraContext 双上下文任务
// 严格翻译自: src/event_loop/AnyTaskWithExtraContext.zig
//   const AnyTaskWithExtraContext = @This()
//   ctx: ?*anyopaque = undefined
//   callback: *const (fn (*anyopaque, *anyopaque) void) = undefined
//   next: ?*AnyTaskWithExtraContext = null
//   pub fn fromCallbackAutoDeinit, from, run, New
package bao_event_loop

import bao_core.*

// ============================================================================
// AnyTaskWithExtraContext - 双上下文类型擦除任务
// 严格翻译自: src/event_loop/AnyTaskWithExtraContext.zig
//   const AnyTaskWithExtraContext = @This()
//   ctx: ?*anyopaque = undefined
//   callback: *const (fn (*anyopaque, *anyopaque) void) = undefined
//   next: ?*AnyTaskWithExtraContext = null
// ============================================================================

/// 双上下文类型擦除任务 - 对应 Bun AnyTaskWithExtraContext
/// 提供两个指针 (ctx + extra) 而非一个, 用于需要额外上下文的场景
public class AnyTaskWithExtraContext {
    /// 上下文对象
    /// 严格翻译自: ctx: ?*anyopaque = undefined
    public var ctx: ?Object

    /// 回调函数
    /// 严格翻译自: callback: *const (fn (*anyopaque, *anyopaque) void) = undefined
    public var callback: ?(Object, Object) -> Unit

    /// 链表下一个
    /// 严格翻译自: next: ?*AnyTaskWithExtraContext = null
    public var next: ?AnyTaskWithExtraContext

    public init() {
        ctx = None
        callback = None
        next = None
    }

    public init(ctx: Object, callback: (Object, Object) -> Unit) {
        this.ctx = ctx
        this.callback = callback
        next = None
    }

    /// 从回调创建 (自动清理)
    /// 严格翻译自: pub fn fromCallbackAutoDeinit(ptr, fieldName) *AnyTaskWithExtraContext
    public static func fromCallbackAutoDeinit(ctx: Object, callback: (Object, Object) -> Unit): AnyTaskWithExtraContext {
        return AnyTaskWithExtraContext(ctx, callback)
    }

    /// 执行任务
    /// 严格翻译自: pub fn run(this: *AnyTaskWithExtraContext, extra: *anyopaque) void
    ///   const callback = this.callback
    ///   const ctx = this.ctx
    ///   callback(ctx.?, extra)
    public func run(extra: Object): Unit {
        match (callback) {
            case Some(cb) =>
                match (ctx) {
                    case Some(c) => cb(c, extra)
                    case None => ()
                }
            case None => ()
        }
    }
}
