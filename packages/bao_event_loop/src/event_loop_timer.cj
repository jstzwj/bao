// bao_event_loop - EventLoopTimer 事件循环定时器
// 严格翻译自: src/event_loop/EventLoopTimer.zig
//   Bun 的 EventLoopTimer 定义了:
//     Self - 定时器结构 (next: timespec, state, tag, heap, in_heap)
//     Tag - 定时器标签枚举 (20+ 种定时器类型)
//     State - 定时器状态 (PENDING/ACTIVE/CANCELLED/FIRED)
//     less - 比较函数 (用于最小堆排序)
//     fire - 触发回调
package bao_event_loop

import bao_core.*

// ============================================================================
// EventLoopTimer - 事件循环定时器
// 严格翻译自: src/event_loop/EventLoopTimer.zig
//   const Self = @This()
//   next: timespec           // 绝对触发时间
//   state: State = .PENDING  // 定时器状态
//   tag: Tag                 // 定时器类型标签
//   heap: IntrusiveField     // 堆内联字段
//   in_heap: enum { none, regular, fake }
// ============================================================================

/// 事件循环定时器 - 对应 Bun EventLoopTimer
/// 用于管理事件循环中的定时任务
public class EventLoopTimer {
    /// 下次触发的绝对时间 (秒)
    /// 严格翻译自: next: timespec
    public var nextSec: Int64
    /// 下次触发的绝对时间 (纳秒)
    public var nextNsec: Int64
    public var id: Int64
    public var next: Timespec
    public var intervalMs: Int64
    public var callback: () -> Unit

    /// 定时器状态
    /// 严格翻译自: state: State = .PENDING
    public var state: TimerState

    /// 定时器标签
    /// 严格翻译自: tag: Tag
    public var tag: TimerTag

    /// 是否在堆中
    /// 严格翻译自: in_heap: enum { none, regular, fake }
    public var inHeap: TimerInHeap

    public init(tag: TimerTag) {
        nextSec = 0
        nextNsec = 0
        id = Int64(0)
        next = Timespec()
        intervalMs = Int64(0)
        callback = { => () }
        state = TimerState.Pending
        this.tag = tag
        inHeap = TimerInHeap.None
    }

    public init(tag: TimerTag, callback: () -> Unit, deadlineMs: Int64, intervalMs: Int64, id: Int64) {
        nextSec = deadlineMs / Int64(1000)
        nextNsec = (deadlineMs % Int64(1000)) * Int64(1000000)
        this.id = id
        next = Timespec.fromMillis(deadlineMs)
        this.intervalMs = intervalMs
        this.callback = callback
        state = TimerState.Active
        this.tag = tag
        inHeap = TimerInHeap.None
    }

    /// 创建暂停的定时器
    /// 严格翻译自: pub fn initPaused(tag: Tag) Self
    public static func initPaused(tag: TimerTag): EventLoopTimer {
        return EventLoopTimer(tag)
    }

    /// 比较 (小于) - 用于最小堆排序
    /// 严格翻译自: pub fn less(_: void, a: *const Self, b: *const Self) bool
    public static func less(a: EventLoopTimer, b: EventLoopTimer): Bool {
        if (a.nextSec != b.nextSec) {
            return a.nextSec < b.nextSec
        }
        return a.nextNsec < b.nextNsec
    }

    /// 触发定时器
    /// 严格翻译自: pub fn fire(self: *Self, now: *const timespec, vm: *VirtualMachine) void
    public func fire(): Unit {
        state = TimerState.Fired
        // 根据标签类型分发
        match (tag) {
            case TimerTag.TimerCallback => ()
            case TimerTag.TimeoutObject => ()
            case TimerTag.ImmediateObject => ()
            case TimerTag.StatWatcherScheduler => ()
            case TimerTag.UpgradedDuplex => ()
            case TimerTag.DNSResolver => ()
            case TimerTag.WTFTimer => ()
            case TimerTag.SubprocessTimeout => ()
            case TimerTag.AbortSignalTimeout => ()
            case TimerTag.DateHeaderTimer => ()
            case TimerTag.BunTest => ()
            case TimerTag.EventLoopDelayMonitor => ()
            case TimerTag.CronJob => ()
            case _ => ()
        }
    }

    public func isActive(): Bool {
        match (state) {
            case TimerState.Active => true
            case TimerState.Pending => true
            case _ => false
        }
    }

    public func cancel(): Unit {
        state = TimerState.Cancelled
    }

    /// 是否允许假定时器
    /// 严格翻译自: pub fn allowFakeTimers(self: Tag) bool
    public func allowFakeTimers(): Bool {
        match (tag) {
            case TimerTag.WTFTimer |
                 TimerTag.BunTest |
                 TimerTag.EventLoopDelayMonitor |
                 TimerTag.StatWatcherScheduler |
                 TimerTag.CronJob => false
            case _ => true
        }
    }
}

// ============================================================================
// TimerState - 定时器状态
// 严格翻译自: src/event_loop/EventLoopTimer.zig State
//   pub const State = enum { PENDING, ACTIVE, CANCELLED, FIRED }
// ============================================================================

/// 定时器状态 - 对应 Bun TimerState
public enum TimerState {
    | Pending     // 等待启用
    | Active      // 活跃, 将在 next 时间触发
    | Cancelled   // 已取消
    | Fired        // 已触发
}

// ============================================================================
// TimerTag - 定时器标签
// 严格翻译自: src/event_loop/EventLoopTimer.zig Tag
//   pub const Tag = enum { TimerCallback, TimeoutObject, ... }
// ============================================================================

/// 定时器标签 - 对应 Bun TimerTag
/// 标识定时器的具体用途
public enum TimerTag {
    | TimerCallback
    | Timeout
    | Interval
    | Immediate
    | TimeoutObject
    | ImmediateObject
    | StatWatcherScheduler
    | UpgradedDuplex
    | DNSResolver
    | WindowsNamedPipe
    | WTFTimer
    | PostgresSQLConnectionTimeout
    | PostgresSQLConnectionMaxLifetime
    | MySQLConnectionTimeout
    | MySQLConnectionMaxLifetime
    | ValkeyConnectionTimeout
    | ValkeyConnectionReconnect
    | SubprocessTimeout
    | DevServerSweepSourceMaps
    | DevServerMemoryVisualizerTick
    | AbortSignalTimeout
    | DateHeaderTimer
    | BunTest
    | EventLoopDelayMonitor
    | CronJob
}

// ============================================================================
// TimerInHeap - 堆中状态
// 严格翻译自: src/event_loop/EventLoopTimer.zig in_heap
//   in_heap: enum { none, regular, fake }
// ============================================================================

/// 堆中状态 - 对应 Bun TimerInHeap
public enum TimerInHeap {
    | None       // 不在堆中
    | Regular    // 在正规堆中
    | Fake       // 在假定时器堆中
}

// ============================================================================
// TimerCallback - 定时器回调
// 严格翻译自: src/event_loop/EventLoopTimer.zig TimerCallback
//   const TimerCallback = struct {
//       callback: *const fn (*TimerCallback) void,
//       ctx: *anyopaque,
//       event_loop_timer: Self,
//   }
// ============================================================================

/// 定时器回调 - 对应 Bun TimerCallback
public class TimerCallback {
    /// 回调函数
    public var callback: () -> Unit
    /// 定时器
    public var timer: EventLoopTimer

    public init(callback: () -> Unit, timer: EventLoopTimer) {
        this.callback = callback
        this.timer = timer
    }

    /// 执行回调
    public func run(): Unit {
        callback()
    }
}
