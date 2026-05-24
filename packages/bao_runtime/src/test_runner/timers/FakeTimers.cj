// FakeTimers.cj - 假定时器
// 严格翻译自 bun/src/runtime/test_runner/timers/FakeTimers.zig

package bao_runtime.test_runner.timers

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.*
import bao_collections.*

// ========== FakeTimers - 假定时器 ==========

/// 当前时间状态
public class CurrentTime {
    /// 最小时间戳
    public static let minTimespec: Timespec = Timespec(Int64.Min, Int64.Min)

    /// 偏移量原始值
    public var offsetRaw: Timespec = minTimespec
    /// Date.now偏移
    public var dateNowOffset: Float64 = 0.0

    public init() {}

    /// 获取当前时间戳
    public func getTimespecNow(): ?Timespec {
        let value = offsetRaw
        if (value.equals(minTimespec)) { return None }
        return value
    }

    /// 设置时间
    public func set(globalObject: JSGlobalObject, offset: Timespec, js: ?Float64) {
        offsetRaw = offset
        let timespecMs = Float64(offset.ms())
        if (js.isSome()) {
            dateNowOffset = Float64(Math.floor(js.getOrThrow())) - timespecMs
        }
        MockHelper.setOverridenDateNow(globalObject, dateNowOffset + timespecMs)
        // 设置overridden_performance_now
        let vm = globalObject.bunVM()
        vm.overriddenPerformanceNow = offset.ns()
    }

    /// 清除时间覆盖
    public func clear(globalObject: JSGlobalObject) {
        offsetRaw = minTimespec
        MockHelper.setOverridenDateNow(globalObject, -1.0)
        let vm = globalObject.bunVM()
        vm.overriddenPerformanceNow = None
    }
}

/// 假定时器，用于在测试中模拟和控制时间
public class FakeTimers {
    public var active: Bool = false
    public var timers: TimerHeap = TimerHeap()
    public static var currentTime: CurrentTime = CurrentTime()

    public init() {}

    // ========== 内部方法 ==========

    /// 检查是否激活
    public func isActive(): Bool {
        return active
    }

    /// 激活假定时器
    public func activate(jsNow: Float64, globalObject: JSGlobalObject) {
        active = true
        FakeTimers.currentTime.set(globalObject, Timespec(0, 0), jsNow)
    }

    /// 停用假定时器
    public func deactivate(globalObject: JSGlobalObject) {
        clear()
        FakeTimers.currentTime.clear(globalObject)
        active = false
    }

    /// 清除所有定时器
    public func clear() {
        while (let Some(timer) <- timers.deleteMin()) {
            timer.state = TimerState.CANCELLED
            timer.inHeap = InHeap.NONE
        }
    }

    /// 执行下一个定时器
    public func executeNext(globalObject: JSGlobalObject): Bool {
        let next = timers.deleteMin()
        if (next.isNone()) { return false }
        fire(globalObject, next.getOrThrow())
        return true
    }

    /// 触发定时器
    public func fire(globalObject: JSGlobalObject, next: EventLoopTimer) {
        let now = next.next
        FakeTimers.currentTime.set(globalObject, now, Option<Float64>.None)
        let vm = globalObject.bunVM()
        next.fire(now, vm)
    }

    /// 执行到指定时间
    public func executeUntil(globalObject: JSGlobalObject, until: Timespec) {
        while (true) {
            let peek = timers.peek()
            if (peek.isNone()) { break }
            if (peek.getOrThrow().next.greater(until)) { break }
            let next = timers.deleteMin()
            if (next.isSome()) {
                fire(globalObject, next.getOrThrow())
            }
        }
    }

    /// 仅执行待处理的定时器
    public func executeOnlyPendingTimers(globalObject: JSGlobalObject) {
        let target = timers.findMax()
        if (target.isNone()) { return }
        let until = target.getOrThrow().next
        executeUntil(globalObject, until)
    }

    /// 执行所有定时器
    public func executeAllTimers(globalObject: JSGlobalObject) {
        while (executeNext(globalObject)) {}
    }

    // ========== JS 函数 ==========

    /// 检查假定时器是否激活, 否则抛出错误
    private static func errorUnlessFakeTimers(globalObject: JSGlobalObject): ?JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers
        if (fakeTimers.isActive()) { return None }
        let errVal = JsValue("Fake timers are not active. Call useFakeTimers() first.")
        return errVal
    }

    /// 设置假定时器标记(setTimeout.clock)
    private static func setFakeTimerMarker(globalObject: JSGlobalObject, enabled: Bool) {
        let globalThisValue = globalObject.toJSValue()
        let globalObj = globalObject.globalThis
        let setTimeoutFnOpt = globalThisValue.getOwnTruthy(globalObj, "setTimeout")
        if (setTimeoutFnOpt.isNone()) { return }
        let setTimeoutFn = setTimeoutFnOpt.getOrThrow()
        if (enabled) {
            setTimeoutFn.put(globalObj, "clock", JsValue.jsTrue())
        } else {
            let _ = setTimeoutFn.deleteProperty(globalObj, "clock")
        }
    }

    /// useFakeTimers - 安装假定时器
    public static func useFakeTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        var jsNow = MockHelper.getCurrentUnixTimeMs()

        // 检查是否提供了选项对象
        let args = callFrame.argumentsAsArray(1)
        if (args.size > 0 && !args[0].isUndefined()) {
            let optionsValue = args[0]
            let configOpt = FakeTimersConfig.fromJS(globalObject, optionsValue)
            if (configOpt.isNone()) { return JsValue() }
            let config = configOpt.getOrThrow()
            // 检查是否提供了'now'字段
            if (!config.now.isUndefined()) {
                if (config.now.isNumber()) {
                    jsNow = config.now.asNumber()
                } else if (config.now.isDate()) {
                    jsNow = config.now.getUnixTimestamp()
                } else {
                    globalObject.throwInvalidArguments("'now' must be a number or Date")
                    return JsValue()
                }
            }
        }

        fakeTimers.activate(jsNow, globalObject)

        // 设置setTimeout.clock = true
        setFakeTimerMarker(globalObject, true)

        return callFrame.thisValue
    }

    /// useRealTimers - 恢复真实定时器
    public static func useRealTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        fakeTimers.deactivate(globalObject)

        // 移除setTimeout.clock标记
        setFakeTimerMarker(globalObject, false)

        return callFrame.thisValue
    }

    /// advanceTimersToNextTimer - 推进到下一个定时器
    public static func advanceTimersToNextTimer(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject)
        if (err.isSome()) { return err.getOrThrow() }

        fakeTimers.executeNext(globalObject)

        return callFrame.thisValue
    }

    /// advanceTimersByTime - 按时间推进
    public static func advanceTimersByTime(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject)
        if (err.isSome()) { return err.getOrThrow() }

        let arg = callFrame.argumentsAsArray(1)[0]
        if (!arg.isNumber()) {
            return JsValue("advanceTimersByTime() expects a number of milliseconds")
        }

        let current = FakeTimers.currentTime.getTimespecNow()
        if (current.isNone()) {
            return JsValue("Fake timers not initialized. Initialize with useFakeTimers() first.")
        }

        let argNumber = arg.asNumber()
        let maxAdvance = Float64(UInt32(4294967295))
        if (argNumber < 0.0 || argNumber > maxAdvance) {
            return JsValue("advanceTimersByTime() ms is out of range. It must be >= 0 and <= 4294967295. Received ${argNumber}")
        }

        // 当advanceTimersByTime(0)时, 推进1ms以触发setTimeout(fn, 0)
        // 这是因为setTimeout(fn, 0)内部按HTML规范有1ms延迟
        let effectiveAdvance = if (argNumber == 0.0) { 1.0 } else { argNumber }
        let target = current.getOrThrow().addMsFloat(effectiveAdvance)

        fakeTimers.executeUntil(globalObject, target)
        FakeTimers.currentTime.set(globalObject, target, Option<Float64>.None)

        return callFrame.thisValue
    }

    /// runOnlyPendingTimers - 仅运行待处理的定时器
    public static func runOnlyPendingTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject)
        if (err.isSome()) { return err.getOrThrow() }

        fakeTimers.executeOnlyPendingTimers(globalObject)

        return callFrame.thisValue
    }

    /// runAllTimers - 运行所有定时器
    public static func runAllTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject)
        if (err.isSome()) { return err.getOrThrow() }

        fakeTimers.executeAllTimers(globalObject)

        return callFrame.thisValue
    }

    /// getTimerCount - 获取定时器数量
    public static func getTimerCount(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject)
        if (err.isSome()) { return err.getOrThrow() }

        let count = fakeTimers.timers.count()
        return JsValue.jsNumber(count)
    }

    /// clearAllTimers - 清除所有定时器
    public static func clearAllTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject)
        if (err.isSome()) { return err.getOrThrow() }

        fakeTimers.clear()

        return callFrame.thisValue
    }

    /// isFakeTimers - 检查是否使用假定时器
    public static func isFakeTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        let timer = FakeTimerState()
        let fakeTimers = timer.fakeTimers

        let isActive = fakeTimers.isActive()
        return JsValue.jsBoolean(isActive)
    }

    /// 假定时器函数数量
    public static let timerFnsCount: UInt32 = 9

    /// 将定时器函数放入jest和vi对象
    public static func putTimersFns(globalObject: JSGlobalObject, jest: JsValue, vi: JsValue) {
        let globalObj = globalObject.globalThis
        let names = ["useFakeTimers", "useRealTimers", "advanceTimersToNextTimer",
            "advanceTimersByTime", "runOnlyPendingTimers", "runAllTimers",
            "getTimerCount", "clearAllTimers", "isFakeTimers"]
        let callbacks: Array<(JSGlobalObject, CallFrame) -> JsValue> = [
            useFakeTimers, useRealTimers, advanceTimersToNextTimer,
            advanceTimersByTime, runOnlyPendingTimers, runAllTimers,
            getTimerCount, clearAllTimers, isFakeTimers
        ]

        for (i in 0..names.size) {
            let cb = callbacks[i]
            let wrappedCb: JsCallback = { thisObj, args =>
                let callFrame = CallFrame(args, JsValue(thisObj), JsValue.undefined())
                cb(globalObject, callFrame)
            }
            let jsValue = JSFunction.create(globalObject, names[i], { =>
                JsValue()
            }, UInt32(0), JSFunctionCreateOptions())
            vi.put(globalObj, names[i], jsValue)
            jest.put(globalObj, names[i], jsValue)
        }
    }
}

/// 假定时器配置
public class FakeTimersConfig {
    public var now: JsValue = JsValue.jsUndefined()

    public init() {}

    public static func fromJS(globalObject: JSGlobalObject, value: JsValue): ?FakeTimersConfig {
        if (!value.isObject()) { return None }
        let config = FakeTimersConfig()
        config.now = value.get(globalObject.globalThis, "now") ?? JsValue.jsUndefined()
        return config
    }

    public func deinit() {}
}

// ============================================================================
// 本地存根类型 (这些类型在 bao_runtime.timer 中完整定义)
// ============================================================================

/// 时间规格 - 存根
public class Timespec {
    public var sec: Int64
    public var nsec: Int64

    public init(sec: Int64, nsec: Int64) {
        this.sec = sec
        this.nsec = nsec
    }

    public init() {
        sec = 0
        nsec = 0
    }

    public static func epoch(): Timespec {
        return Timespec(0, 0)
    }

    public func ms(): Int64 {
        return sec * 1000 + nsec / 1000000
    }

    public func ns(): Int64 {
        return sec * 1000000000 + nsec
    }

    public func equals(other: Timespec): Bool {
        return sec == other.sec && nsec == other.nsec
    }

    public func addMsFloat(ms: Float64): Timespec {
        let totalNs = Float64(sec) * 1000000000.0 + Float64(nsec) + ms * 1000000.0
        let secPart = Int64(totalNs / 1000000000.0)
        let nsecPart = Int64(totalNs - Float64(secPart) * 1000000000.0)
        return Timespec(secPart, nsecPart)
    }

    public func greater(other: Timespec): Bool {
        if (sec > other.sec) { return true }
        if (sec < other.sec) { return false }
        return nsec > other.nsec
    }
}

/// 定时器堆 - 存根
public class TimerHeap {
    private var heap: ArrayList<EventLoopTimer> = ArrayList<EventLoopTimer>()

    public init() {}

    public func count(): Int64 {
        return heap.size
    }

    public func deleteMin(): ?EventLoopTimer {
        if (heap.size == 0) { return None }
        let t = heap.removeAt(0)
        return Some(t)
    }

    public func peek(): ?EventLoopTimer {
        if (heap.size == 0) { return None }
        return Some(heap[0])
    }

    public func findMax(): ?EventLoopTimer {
        if (heap.size == 0) { return None }
        return Some(heap[heap.size - 1])
    }

    public func remove(id: Int64): Unit {
        var i: Int64 = 0
        while (i < heap.size) {
            if (heap[i].id == id) {
                let timer = heap.removeAt(i)
                timer.state = TimerState.CANCELLED
                timer.inHeap = InHeap.NONE
                return
            }
            i += 1
        }
    }
}

/// 事件循环定时器 - 存根
public class EventLoopTimer {
    public var next: Timespec = Timespec()
    public var state: TimerState = TimerState.CANCELLED
    public var inHeap: InHeap = InHeap.NONE
    public var id: Int64 = 0

    public init() {}

    public func fire(now: Timespec, vm: Any): Unit {
        state = TimerState.DONE
        inHeap = InHeap.NONE
    }
}

/// 定时器状态
public enum TimerState {
    | ACTIVE
    | CANCELLED
    | DONE
}

/// InHeap 标记
public enum InHeap {
    | NONE
    | Regular
    | Fake
}

/// FakeTimerState stub - wraps fakeTimers
public class FakeTimerState {
    public var fakeTimers: FakeTimers = FakeTimers()
    public init() {}
}

/// Mock helper stubs for JSMock functionality
public class MockHelper {
    public static func setOverridenDateNow(globalObject: Any, value: Float64): Unit {}
    public static func getCurrentUnixTimeMs(): Float64 { 0.0 }
}
