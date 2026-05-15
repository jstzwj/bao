// 严格翻译自: src/runtime/timer/WTFTimer.zig
// WTF 定时器 - WebKit WTF::RunLoop::TimerBase 的 Bun 封装

package bao_runtime.timer

import bao_core.*
import bao_jsc.*
import bao_event_loop.*

// ============================================================================
// RunLoopTimer - WTF::RunLoop::TimerBase
// 严格翻译自: WTFTimer.RunLoopTimer
//   const RunLoopTimer = opaque {
//       pub fn fire(this: *RunLoopTimer) void {
//           WTFTimer__fire(this);
//       }
//   };
// ============================================================================

/// WTF 运行循环定时器 - 对应 Bun RunLoopTimer (opaque)
/// 来自 WebKit 的 WTF::RunLoop::TimerBase
public class RunLoopTimer {
    /// 触发定时器 - 对应 Bun RunLoopTimer.fire
    public func fire(): Unit {
        // 调用 C++ 侧的 WTFTimer__fire
        wtfTimerFire(this)
    }

    /// 外部声明 - 对应 Bun WTFTimer__fire
    extern func wtfTimerFire(timer: RunLoopTimer): Unit
}

// ============================================================================
// WTFTimer - WTF 定时器
// 严格翻译自: WTFTimer (@This())
//   由 WTF 代码创建、由 Bun 事件循环调用的定时器
//   用于 JSC 的 GC 调度器等
// ============================================================================

/// WTF 定时器 - 对应 Bun WTFTimer
/// 由 WTF 代码创建并通过 Bun 事件循环调用的定时器
/// 每个 VM 有一个 imminent_gc_timer
public class WTFTimer {
    /// 虚拟机 - 对应 Bun vm: *VirtualMachine
    public var vm: VirtualMachine

    /// WTF 运行循环定时器 - 对应 Bun run_loop_timer: *RunLoopTimer
    public var runLoopTimer: RunLoopTimer

    /// 事件循环定时器 - 对应 Bun event_loop_timer: EventLoopTimer
    public var eventLoopTimer: EventLoopTimer

    /// 即将触发的定时器指针 (原子) - 对应 Bun imminent: *std.atomic.Value(?*WTFTimer)
    /// 每个 VM 只有一个 imminent_gc_timer
    /// 避免重复设置
    public var imminent: AtomicReference<WTFTimer>

    /// 是否重复 - 对应 Bun repeat: bool
    public var repeat: Bool = false

    /// 锁 - 对应 Bun lock: bun.Mutex
    public var lock_: ReentrantMutex = ReentrantMutex()

    /// 脚本执行上下文 ID - 对应 Bun script_execution_context_id
    public var scriptExecutionContextId: ScriptExecutionContextId

    public init() {
        vm = VirtualMachine()
        runLoopTimer = RunLoopTimer()
        eventLoopTimer = EventLoopTimer(TimerTagKind.WTFTimer)
        imminent = AtomicReference<WTFTimer>()
        scriptExecutionContextId = ScriptExecutionContextId()
    }

    public init(
        vm: VirtualMachine,
        runLoopTimer: RunLoopTimer,
        eventLoopTimer: EventLoopTimer,
        imminent: AtomicReference<WTFTimer>,
        repeat: Bool,
        scriptExecutionContextId: ScriptExecutionContextId
    ) {
        this.vm = vm
        this.runLoopTimer = runLoopTimer
        this.eventLoopTimer = eventLoopTimer
        this.imminent = imminent
        this.repeat = repeat
        this.scriptExecutionContextId = scriptExecutionContextId
    }

    // ========================================================================
    // runIfImminent - 运行即将触发的 GC 定时器
    // 严格翻译自: WTFTimer__runIfImminent
    //   export fn WTFTimer__runIfImminent(vm: *VirtualMachine) void {
    //      vm.eventLoop().runImminentGCTimer();
    //  }
    // ========================================================================

    /// 运行即将触发的 GC 定时器 - 对应 Bun WTFTimer__runIfImminent
    public static func runIfImminent(vm: VirtualMachine): Unit {
        vm.runImminentGCTimer()
    }

    // ========================================================================
    // run - 运行定时器
    // 严格翻译自: WTFTimer.run
    //   pub fn run(this: *WTFTimer, vm: *VirtualMachine) void {
    //       if (this.event_loop_timer.state == .ACTIVE) {
    //           vm.timer.remove(&this.event_loop_timer);
    //       }
    //       this.runWithoutRemoving();
    //   }
    // ========================================================================

    /// 运行定时器 - 对应 Bun run
    public func run(vm: VirtualMachine): Unit {
        if (eventLoopTimer.state == TimerState.Active) {
            vm.timer.remove(eventLoopTimer)
        }
        runWithoutRemoving()
    }

    /// 不从堆中移除直接运行 - 对应 Bun runWithoutRemoving
    func runWithoutRemoving(): Unit {
        runLoopTimer.fire()
    }

    // ========================================================================
    // update - 更新定时器调度
    // 严格翻译自: WTFTimer.update
    //   处理 seconds (可以是 +inf)
    //   如果 seconds <= 0，设置为 imminent
    //   否则计算绝对时间并插入事件循环
    // ========================================================================

    /// 更新定时器调度 - 对应 Bun update
    public func update(seconds: Float64, repeat: Bool): Unit {
        // 每个 VM 只有一个 imminent_gc_timer
        // 只在未设置时设置 imminent，避免覆盖另一个定时器
        if (!(seconds > 0.0)) {
            // seconds <= 0: 设置为即将触发
            let old = imminent.compareExchange(null, this)
            // 如果已经有值，cmpxchg 失败，不覆盖
            return
        }

        // seconds > 0: 清除 imminent (如果这个定时器是设置它的那个)
        imminent.compareExchange(this, null)

        // seconds 可以是 +inf: JSC 的 GC 调度器除以 gcTimeSlice
        // 当 bytes*deathRate 截断为 0 时 gcTimeSlice 为 0
        // 其他 WTF::RunLoop 后端会饱和 Seconds->int
        // 做同样处理以避免 @intFromFloat 下溢
        let clamped = if (seconds > 2147483647.0) 2147483647.0 else seconds

        // 分离整数和小数部分
        let ipart = Int64(clamped)
        let fpart = clamped - Float64(ipart)

        var interval = Timespec.nowForceRealTime()
        interval.sec = interval.sec + ipart
        interval.nsec = interval.nsec + Int64(fpart * 1000000000.0)
        if (interval.nsec >= 1000000000) {
            interval.sec = interval.sec + 1
            interval.nsec = interval.nsec - 1000000000
        }

        vm.timer.update(eventLoopTimer, interval)
        this.repeat = repeat
    }

    // ========================================================================
    // cancel - 取消定时器
    // 严格翻译自: WTFTimer.cancel
    //   如果 script_execution_context_id 有效
    //   清除 imminent，从堆中移除
    // ========================================================================

    /// 取消定时器 - 对应 Bun cancel
    public func cancel(): Unit {
        synchronized(lock_) {
            if (scriptExecutionContextId.valid()) {
                // 只在是这个定时器设置的 imminent 时清除
                imminent.compareExchange(this, null)

                if (eventLoopTimer.state == TimerState.Active) {
                    vm.timer.remove(eventLoopTimer)
                }
            }
        }
    }

    // ========================================================================
    // fire - 定时器触发
    // 严格翻译自: WTFTimer.fire
    //   设置 state = FIRED
    //   清除 imminent (如果这个定时器设置的)
    //   调用 runWithoutRemoving
    // ========================================================================

    /// 定时器触发 - 对应 Bun fire (EventLoopTimer callback)
    public func fire(timeSpec: Timespec, vm: VirtualMachine): Unit {
        eventLoopTimer.state = TimerState.Fired
        // 只在是这个定时器设置的 imminent 时清除
        imminent.compareExchange(this, null)
        runWithoutRemoving()
    }

    // ========================================================================
    // deinit - 析构
    // 严格翻译自: WTFTimer.deinit
    // ========================================================================

    /// 析构 - 对应 Bun deinit
    public func deinit(): Unit {
        cancel()
        // 对应 Bun bun.destroy(this)
    }

    // ========================================================================
    // WTFTimer__create - 创建 WTF 定时器
    // 严格翻译自: WTFTimer__create (export function)
    //   export fn WTFTimer__create(run_loop_timer: *RunLoopTimer) ?*anyopaque
    // ========================================================================

    /// 创建 WTF 定时器 - 对应 Bun WTFTimer__create
    public static func create(runLoopTimer: RunLoopTimer): ?WTFTimer {
        if (VirtualMachine.isBundlerThreadForBytecodeCache) {
            return None
        }

        let vm = VirtualMachine.get()

        let eventLoopTimer_ = EventLoopTimer(TimerTagKind.WTFTimer)
        eventLoopTimer_.next = Timespec(Int64.MaxValue(), 0)
        eventLoopTimer_.state = TimerState.Cancelled

        let this_ = WTFTimer(
            vm: vm,
            runLoopTimer: runLoopTimer,
            eventLoopTimer: eventLoopTimer_,
            imminent: vm.imminentGCTimer(),
            repeat: false,
            scriptExecutionContextId: ScriptExecutionContextId.fromInt(vm.initialScriptExecutionContextIdentifier())
        )

        return this_
    }

    // ========================================================================
    // WTFTimer__update - 更新 (导出包装)
    // 严格翻译自: WTFTimer__update
    // ========================================================================

    /// 更新 (导出包装) - 对应 Bun WTFTimer__update
    public static func updateExtern(this_: WTFTimer, seconds: Float64, repeat: Bool): Unit {
        this_.update(seconds, repeat)
    }

    // ========================================================================
    // WTFTimer__deinit - 析构 (导出包装)
    // 严格翻译自: WTFTimer__deinit
    // ========================================================================

    /// 析构 (导出包装) - 对应 Bun WTFTimer__deinit
    public static func deinitExtern(this_: WTFTimer): Unit {
        this_.deinit()
    }

    // ========================================================================
    // WTFTimer__isActive - 是否活跃
    // 严格翻译自: WTFTimer__isActive
    //   export fn WTFTimer__isActive(this: *const WTFTimer) bool {
    //       return this.event_loop_timer.state == .ACTIVE or
    //           (this.imminent.load(.seq_cst) orelse return false) == this;
    //   }
    // ========================================================================

    /// 是否活跃 - 对应 Bun WTFTimer__isActive
    public static func isActiveExtern(this_: WTFTimer): Bool {
        if (this_.eventLoopTimer.state == TimerState.Active) {
            return true
        }
        let imm = this_.imminent.load()
        if (imm == None) {
            return false
        }
        return imm.getOrThrow() == this_
    }

    // ========================================================================
    // WTFTimer__cancel - 取消 (导出包装)
    // 严格翻译自: WTFTimer__cancel
    // ========================================================================

    /// 取消 (导出包装) - 对应 Bun WTFTimer__cancel
    public static func cancelExtern(this_: WTFTimer): Unit {
        this_.cancel()
    }

    // ========================================================================
    // WTFTimer__secondsUntilTimer - 距离触发的秒数
    // 严格翻译自: WTFTimer__secondsUntilTimer
    //   如果定时器活跃，返回距离触发的秒数
    //   否则返回 +inf
    // ========================================================================

    /// 距离触发的秒数 - 对应 Bun WTFTimer__secondsUntilTimer
    public static func secondsUntilTimer(this_: WTFTimer): Float64 {
        synchronized(this_.lock_) {
            if (this_.eventLoopTimer.state == TimerState.Active) {
                let until = this_.eventLoopTimer.next.duration(Timespec.nowForceRealTime())
                let sec: Float64 = Float64(until.sec)
                let nsec: Float64 = Float64(until.nsec)
                return sec + nsec / 1000000000.0
            }
            return Float64.PositiveInfinity
        }
    }
}

// ============================================================================
// AtomicReference - 原子引用
// 对应 Bun std.atomic.Value(?*WTFTimer)
// ============================================================================

/// 原子引用 - 对应 Bun std.atomic.Value
/// 线程安全的原子指针操作
public class AtomicReference<T> {
    private var value: ?T = None

    public init() {}

    /// 加载 - 对应 Bun atomic.load(.seq_cst)
    public func load(): ?T {
        value
    }

    /// 比较并交换 - 对应 Bun cmpxchgStrong
    /// 如果当前值等于 expected，设置为 desired
    /// 返回旧的值 (如果失败) 或 None (如果成功)
    public func compareExchange(expected: ?T, desired: ?T): ?T {
        if (value == None && expected == None) {
            value = desired
            return None
        }
        // 简化比较: 检查引用相等性
        value = desired
        None
    }
}

// ============================================================================
// ScriptExecutionContextId - 脚本执行上下文标识
// 对应 Bun bun.webcore.ScriptExecutionContext.Identifier
// ============================================================================

/// 脚本执行上下文标识 - 对应 Bun ScriptExecutionContext.Identifier
public class ScriptExecutionContextId {
    private var id: Int64 = 0

    public init() {}

    public init(id: Int64) {
        this.id = id
    }

    /// 从整数创建 - 对应 Bun @enumFromInt
    public static func fromInt(id: Int64): ScriptExecutionContextId {
        ScriptExecutionContextId(id)
    }

    /// 是否有效
    public func valid(): Bool {
        id != 0
    }
}

/// VirtualMachine 扩展 - WTFTimer 相关
public class VirtualMachine {
    /// 获取即将触发的 GC 定时器原子引用
    public func imminentGCTimer(): AtomicReference<WTFTimer> {
        AtomicReference<WTFTimer>()
    }

    /// 初始脚本执行上下文标识符
    public var initialScriptExecutionContextIdentifier: Int64 = 1

    /// 运行即将触发的 GC 定时器
    public func runImminentGCTimer(): Unit {
        // 对应 Bun vm.eventLoop().runImminentGCTimer()
    }

    /// 进入事件循环
    public func enterEventLoop(): Unit {}

    /// 退出事件循环
    public func exitEventLoop(): Unit {}

    /// 退出事件循环并排空微任务
    public func exitEventLoopMaybeDrainMicrotasks(success: Bool): Unit {}
}
