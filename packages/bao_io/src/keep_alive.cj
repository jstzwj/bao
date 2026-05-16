// bao_io - KeepAlive (保持事件循环活跃)
// 严格翻译自: src/io/keep_alive.rs
//   Bun 的 KeepAlive 跟踪一个 poll 是否应该保持事件循环活跃
//   不是引用计数, 只有三种状态: Active / Inactive / Done
//   Zig 在 posix_event_loop.zig 和 windows_event_loop.zig 中各保留一份
//   Rust 的 keep_alive.rs 合并了两份, 通过 cfg 分支处理平台差异
//   仓颉实现提供跨平台的统一 KeepAlive
package bao_io

import bao_core.*

// ============================================================================
// KeepAlive - 保持事件循环活跃
// 严格翻译自: src/io/keep_alive.rs KeepAlive
//   #[derive(Default)]
//   pub struct KeepAlive { status: Status }
//   跟踪一个文件描述符的 poll 是否应保持事件循环活跃
//   注意: posix_event_loop.cj 中已有简化版 KeepAlive,
//   此模块提供完整的独立版本, 包含并发 unref 等高级功能
// ============================================================================

/// 保持活跃状态
/// 严格翻译自: keep_alive.rs Status
///   #[derive(Copy, Clone, PartialEq, Eq, Default)]
///   enum Status { Active, #[default] Inactive, Done }
public enum KeepAliveStatus {
    | Active     // 活跃: poll 正在保持事件循环存活
    | Inactive   // 非活跃: 默认状态, 不影响事件循环
    | Done       // 完成: 已被禁用, ref() 变成空操作
}

/// 保持事件循环活跃
/// 严格翻译自: keep_alive.rs KeepAlive
///   pub struct KeepAlive { status: Status }
///   9 of 14 methods were byte-identical across platforms;
///   5 that diverge keep their per-platform behaviour via cfg arms.
///   仓颉统一为一个跨平台实现。
public class KeepAlive {
    /// 当前状态
    /// 翻译自: status: Status
    public var status: KeepAliveStatus

    public init() {
        status = KeepAliveStatus.Inactive
    }

    /// 是否活跃
    /// 严格翻译自: pub fn is_active(&self) -> bool
    ///   self.status == Status::Active
    public func isActive(): Bool {
        return status == KeepAliveStatus.Active
    }

    /// 禁用 - 调用 unref 后将状态设为 Done
    /// 严格翻译自: pub fn disable(&mut self)
    ///   self.unref(js_vm_ctx());
    ///   self.status = Status::Done;
    /// 一旦禁用, 后续的 ref()/unref() 都不会产生实际效果
    public func disable(ctx: EventLoopCtx): Unit {
        unref(ctx)
        status = KeepAliveStatus.Done
    }

    /// 停用 (仅用于 EventLoop.Pollable)
    /// 严格翻译自: pub fn deactivate(&mut self, loop_: &mut Loop)
    ///   if self.status != Status::Active { return; }
    ///   self.status = Status::Inactive;
    ///   loop_.sub_active(1);  // POSIX
    ///   loop_.dec();          // Windows
    public func deactivate(ctx: EventLoopCtx): Unit {
        if (status != KeepAliveStatus.Active) {
            return
        }
        status = KeepAliveStatus.Inactive
        ctx.loopSubActive(1)
    }

    /// 激活 (仅用于 EventLoop.Pollable)
    /// 严格翻译自: pub fn activate(&mut self, loop_: &mut Loop)
    ///   POSIX: if self.status != Status::Inactive { return; }
    ///   Windows: if self.status != Status::Active { return; }
    ///   self.status = Status::Active;
    ///   loop_.add_active(1);  // POSIX
    ///   loop_.inc();          // Windows
    public func activate(ctx: EventLoopCtx): Unit {
        if (status != KeepAliveStatus.Inactive) {
            return
        }
        status = KeepAliveStatus.Active
        ctx.loopAddActive(1)
    }

    /// 创建新实例
    /// 严格翻译自: pub fn init() -> KeepAlive
    ///   KeepAlive::default()
    public static func init(): KeepAlive {
        return KeepAlive()
    }

    /// 防止 poll 保持进程存活 (unref)
    /// 严格翻译自: pub fn unref(&mut self, event_loop_ctx: EventLoopCtx)
    ///   if self.status != Status::Active { return; }
    ///   self.status = Status::Inactive;
    ///   event_loop_ctx.loop_unref();      // POSIX
    ///   event_loop_ctx.loop_sub_active(1); // Windows
    public func unref(ctx: EventLoopCtx): Unit {
        if (status != KeepAliveStatus.Active) {
            return
        }
        status = KeepAliveStatus.Inactive
        ctx.loopUnref()
    }

    /// 从另一个线程防止 poll 保持进程存活
    /// 严格翻译自: pub fn unref_concurrently(&mut self, vm: EventLoopCtx)
    ///   if self.status != Status::Active { return; }
    ///   self.status = Status::Inactive;
    ///   vm.unref_concurrently();
    public func unrefConcurrently(ctx: EventLoopCtx): Unit {
        if (status != KeepAliveStatus.Active) {
            return
        }
        status = KeepAliveStatus.Inactive
        ctx.unrefConcurrently()
    }

    /// 在下一个 tick 防止 poll 保持进程存活
    /// 严格翻译自: pub fn unref_on_next_tick(&mut self, event_loop_ctx: EventLoopCtx)
    ///   if self.status != Status::Active { return; }
    ///   self.status = Status::Inactive;
    ///   event_loop_ctx.increment_pending_unref_counter(); // POSIX
    ///   event_loop_ctx.loop_dec();                        // Windows
    public func unrefOnNextTick(ctx: EventLoopCtx): Unit {
        if (status != KeepAliveStatus.Active) {
            return
        }
        status = KeepAliveStatus.Inactive
        ctx.incrementPendingUnrefCounter()
    }

    /// 从另一个线程在下一个 tick 防止 poll 保持进程存活
    /// 严格翻译自: pub fn unref_on_next_tick_concurrently(&mut self, vm: EventLoopCtx)
    ///   if self.status != Status::Active { return; }
    ///   self.status = Status::Inactive;
    ///   vm.increment_pending_unref_counter(); // POSIX
    ///   vm.loop_dec();                        // Windows
    public func unrefOnNextTickConcurrently(ctx: EventLoopCtx): Unit {
        if (status != KeepAliveStatus.Active) {
            return
        }
        status = KeepAliveStatus.Inactive
        ctx.incrementPendingUnrefCounter()
    }

    /// 允许 poll 保持进程存活 (ref)
    /// 严格翻译自: pub fn ref_(&mut self, event_loop_ctx: EventLoopCtx)
    ///   if self.status != Status::Inactive { return; }
    ///   self.status = Status::Active;
    ///   event_loop_ctx.loop_ref();
    public func refKeepAlive(ctx: EventLoopCtx): Unit {
        if (status != KeepAliveStatus.Inactive) {
            return
        }
        status = KeepAliveStatus.Active
        ctx.loopRef()
    }

    /// ref 的别名, 匹配 Zig 方法名 `ref`
    /// 严格翻译自: pub fn r#ref(&mut self, event_loop_ctx: EventLoopCtx)
    ///   self.ref_(event_loop_ctx)
    public func refAlias(ctx: EventLoopCtx): Unit {
        refKeepAlive(ctx)
    }

    /// 从另一个线程允许 poll 保持进程存活
    /// 严格翻译自: pub fn ref_concurrently(&mut self, vm: EventLoopCtx)
    ///   if self.status != Status::Inactive { return; }
    ///   self.status = Status::Active;
    ///   vm.ref_concurrently();
    public func refConcurrently(ctx: EventLoopCtx): Unit {
        if (status != KeepAliveStatus.Inactive) {
            return
        }
        status = KeepAliveStatus.Active
        ctx.refConcurrently()
    }

    /// 从事件循环 ref concurrently
    /// 严格翻译自: pub fn ref_concurrently_from_event_loop(&mut self, loop_: EventLoopCtx)
    ///   self.ref_concurrently(loop_);
    public func refConcurrentlyFromEventLoop(ctx: EventLoopCtx): Unit {
        refConcurrently(ctx)
    }

    /// 从事件循环 unref concurrently
    /// 严格翻译自: pub fn unref_concurrently_from_event_loop(&mut self, loop_: EventLoopCtx)
    ///   self.unref_concurrently(loop_);
    public func unrefConcurrentlyFromEventLoop(ctx: EventLoopCtx): Unit {
        unrefConcurrently(ctx)
    }
}

// ============================================================================
// EventLoopCtx - 事件循环上下文
// 严格翻译自: lib.rs EventLoopCtx
//   仓颉简化版: 封装事件循环操作的接口
//   用于 KeepAlive 与事件循环交互
// ============================================================================

/// 事件循环上下文接口
/// 严格翻译自: lib.rs EventLoopCtx
///   pub type EventLoopHandle = EventLoopCtx
///   提供 ref/unref/active 计数器操作
public interface EventLoopCtx {
    /// 引用事件循环
    func loopRef(): Unit
    /// 取消引用事件循环
    func loopUnref(): Unit
    /// 增加活跃计数
    func loopAddActive(n: UInt32): Unit
    /// 减少活跃计数
    func loopSubActive(n: UInt32): Unit
    /// 增加计数 (Windows 风格)
    func loopInc(): Unit
    /// 减少计数 (Windows 风格)
    func loopDec(): Unit
    /// 从另一个线程取消引用
    func unrefConcurrently(): Unit
    /// 从另一个线程引用
    func refConcurrently(): Unit
    /// 增加待处理 unref 计数器
    func incrementPendingUnrefCounter(): Unit
}
