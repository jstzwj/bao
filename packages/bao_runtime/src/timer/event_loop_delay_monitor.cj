// 严格翻译自: src/runtime/timer/EventLoopDelayMonitor.zig
// 事件循环延迟监控器

package bao_runtime

import bao_core.*
import bao_jsc.*
import bao_event_loop.*

// ============================================================================
// EventLoopDelayMonitor - 事件循环延迟监控器
// 严格翻译自: EventLoopDelayMonitor (@This())
//   监控事件循环的延迟，将延迟记录到 JS 直方图
//   目前全局共享同一个实例，由 src/js/internal/perf_hooks/monitorEventLoopDelay.ts
//   的函数作用域保持存活
// ============================================================================

/// 事件循环延迟监控器 - 对应 Bun EventLoopDelayMonitor
/// 监控事件循环延迟并将延迟记录到 JS 直方图
/// 目前全局共享同一个实例
public class EventLoopDelayMonitor {
    /// JS 直方图 - 对应 Bun js_histogram: jsc.JSValue = jsc.JSValue.zero
    /// 由 src/js/internal/perf_hooks/monitorEventLoopDelay.ts 的作用域保持存活
    public var jsHistogram: JSValue = JSValue.zero

    /// 事件循环定时器 - 对应 Bun event_loop_timer: EventLoopTimer
    /// 初始化:
    ///   .next = .epoch
    ///   .tag = .EventLoopDelayMonitor
    public var eventLoopTimer: EventLoopTimer

    /// 分辨率 (毫秒) - 对应 Bun resolution_ms: i32 = 10
    public var resolutionMs: Int32 = 10

    /// 上次触发的纳秒 - 对应 Bun last_fire_ns: u64 = 0
    public var lastFireNs: UInt64 = 0

    /// 是否启用 - 对应 Bun enabled: bool = false
    public var enabled: Bool = false

    public init() {
        eventLoopTimer = EventLoopTimer(TimerTagKind.EventLoopDelayMonitor)
    }

    // ========================================================================
    // enable - 启用监控
    // 严格翻译自: EventLoopDelayMonitor.enable
    //   pub fn enable(this: *EventLoopDelayMonitor, vm: *VirtualMachine,
    //                histogram: jsc.JSValue, resolution_ms: i32) void
    //   如果已启用，直接返回
    //   设置直方图、分辨率、启用标志
    //   调度定时器
    // ========================================================================

    /// 启用监控 - 对应 Bun enable
    public func enable(vm: VirtualMachine, histogram: JSValue, resolutionMs: Int32): Unit {
        if (enabled) {
            return
        }
        this.jsHistogram = histogram
        this.resolutionMs = resolutionMs

        this.enabled = true

        // 调度定时器
        let now = Timespec.nowForceRealTime()
        eventLoopTimer.next = now.addMs(Int64(resolutionMs))
        vm.timer.insert(eventLoopTimer)
    }

    // ========================================================================
    // disable - 禁用监控
    // 严格翻译自: EventLoopDelayMonitor.disable
    //   pub fn disable(this: *EventLoopDelayMonitor, vm: *VirtualMachine) void
    //   如果未启用，直接返回
    //   重置状态，从定时器堆中移除
    // ========================================================================

    /// 禁用监控 - 对应 Bun disable
    public func disable(vm: VirtualMachine): Unit {
        if (!enabled) {
            return
        }

        this.enabled = false
        this.jsHistogram = JSValue.zero
        this.lastFireNs = 0
        vm.timer.remove(eventLoopTimer)
    }

    // ========================================================================
    // isEnabled - 是否启用
    // 严格翻译自: EventLoopDelayMonitor.isEnabled
    //   pub fn isEnabled(this: *const EventLoopDelayMonitor) bool {
    //       return this.enabled and this.js_histogram != jsc.JSValue.zero;
    //   }
    // ========================================================================

    /// 是否启用 - 对应 Bun isEnabled
    public func isEnabled(): Bool {
        return enabled && jsHistogram != JSValue.zero
    }

    // ========================================================================
    // onFire - 定时器触发回调
    // 严格翻译自: EventLoopDelayMonitor.onFire
    //   计算预期时间和实际时间的差值
    //   如果实际时间超过预期时间，记录延迟到直方图
    //   重新调度定时器
    // ========================================================================

    /// 定时器触发回调 - 对应 Bun onFire
    public func onFire(vm: VirtualMachine, now: Timespec): Unit {
        if (!enabled || jsHistogram == JSValue.zero) {
            return
        }

        let nowNs = now.toNanos()
        if (lastFireNs > 0) {
            // 计算预期延迟
            let expectedNs = UInt64(Int64(resolutionMs)) * UInt64(1000000)
            let actualNs = nowNs - lastFireNs

            if (actualNs > expectedNs) {
                // 记录延迟 (饱和减法)
                let delayNs = if (actualNs >= expectedNs) {
                    Int64(actualNs - expectedNs)
                } else {
                    Int64(0)
                }
                // 调用 JS 侧的直方图记录
                jsNodePerformanceHooksHistogramRecordDelay(jsHistogram, delayNs)
            }
        }

        lastFireNs = nowNs

        // 重新调度
        eventLoopTimer.next = now.addMs(Int64(resolutionMs))
        vm.timer.insert(eventLoopTimer)
    }

    // ========================================================================
    // 外部函数声明
    // 对应 Bun 的 extern / export 函数
    // ========================================================================

    /// 记录延迟到直方图 - 对应 Bun JSNodePerformanceHooksHistogram_recordDelay
    extern func jsNodePerformanceHooksHistogramRecordDelay(histogram: JSValue, delayNs: Int64): Unit

    /// 启用事件循环延迟监控 - 对应 Bun Timer_enableEventLoopDelayMonitoring
    public static func enableEventLoopDelayMonitoring(vm: VirtualMachine, histogram: JSValue, resolutionMs: Int32): Unit {
        vm.timer.eventLoopDelay.enable(vm, histogram, resolutionMs)
    }

    /// 禁用事件循环延迟监控 - 对应 Bun Timer_disableEventLoopDelayMonitoring
    public static func disableEventLoopDelayMonitoring(vm: VirtualMachine): Unit {
        vm.timer.eventLoopDelay.disable(vm)
    }
}
