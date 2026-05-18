// bao_event_loop - AutoFlusher 自动刷新器
// 严格翻译自: src/event_loop/AutoFlusher.zig
//   AutoFlusher 是一个简单的注册标志:
//     registered: bool = false
//     registerDeferredMicrotaskWithType(Type, this, vm)
//     unregisterDeferredMicrotaskWithType(Type, this, vm)
//   用于将对象注册为延迟微任务 (如 onAutoFlush)
package bao_event_loop

import bao_core.*

// ============================================================================
// AutoFlusher - 自动刷新器
// 严格翻译自: src/event_loop/AutoFlusher.zig
//   registered: bool = false
//   pub fn registerDeferredMicrotaskWithType
//   pub fn unregisterDeferredMicrotaskWithType
// ============================================================================

/// 自动刷新器 - 对应 Bun AutoFlusher
/// 管理延迟微任务的注册/注销状态
public class AutoFlusher {
    /// 是否已注册
    /// 严格翻译自: registered: bool = false
    public var registered: Bool

    /// 注册时的回调
    public var onAutoFlush: ?() -> Unit

    public init() {
        registered = false
        onAutoFlush = None
    }

    /// 注册延迟微任务
    /// 严格翻译自: pub fn registerDeferredMicrotaskWithType(comptime Type, this, vm) void
    ///   if (this.auto_flusher.registered) return
    ///   registerDeferredMicrotaskWithTypeUnchecked(Type, this, vm)
    public func registerDeferredMicrotask(onFlush: () -> Unit): Unit {
        if (registered) {
            return
        }
        registered = true
        onAutoFlush = onFlush
    }

    /// 注销延迟微任务
    /// 严格翻译自: pub fn unregisterDeferredMicrotaskWithType(comptime Type, this, vm) void
    ///   if (!this.auto_flusher.registered) return
    ///   unregisterDeferredMicrotaskWithTypeUnchecked(Type, this, vm)
    public func unregisterDeferredMicrotask(): Unit {
        if (!registered) {
            return
        }
        registered = false
        onAutoFlush = None
    }

    /// 注册延迟微任务 (不检查)
    /// 严格翻译自: pub fn registerDeferredMicrotaskWithTypeUnchecked(comptime Type, this, vm) void
    ///   bun.assert(!this.auto_flusher.registered)
    ///   this.auto_flusher.registered = true
    ///   bun.assert(!vm.eventLoop().deferred_tasks.postTask(this, @ptrCast(&Type.onAutoFlush)))
    public func registerUnchecked(onFlush: () -> Unit): Unit {
        registered = true
        onAutoFlush = onFlush
    }

    /// 注销延迟微任务 (不检查)
    /// 严格翻译自: pub fn unregisterDeferredMicrotaskWithTypeUnchecked(comptime Type, this, vm) void
    ///   bun.assert(this.auto_flusher.registered)
    ///   bun.assert(vm.eventLoop().deferred_tasks.unregisterTask(this))
    ///   this.auto_flusher.registered = false
    public func unregisterUnchecked(): Unit {
        registered = false
        onAutoFlush = None
    }

    /// 执行自动刷新
    public func flush(): Unit {
        if (registered) {
            match (onAutoFlush) {
                case Some(cb) => cb()
                case None => ()
            }
        }
    }
}
