// FakeTimers.cj - 假定时器
// 严格翻译自 bun/src/runtime/test_runner/timers/FakeTimers.zig

package bao_runtime.test_runner.timers

// ========== FakeTimers - 假定时器 ==========

/// 当前时间状态
public class CurrentTime {
    /// 最小时间戳
    public static let minTimespec: Timespec = Timespec(sec: Int64.minValue, nsec: Int64.minValue)

    /// 偏移量原始值
    public var offsetRaw: Timespec = minTimespec
    /// Date.now偏移
    public var dateNowOffset: Float64 = 0.0

    public init() {}

    /// 获取当前时间戳
    public func getTimespecNow(): ?Timespec {
        let value = offsetRaw
        if value.equals(minTimespec) { return None }
        return value
    }

    /// 设置时间
    public func set(globalObject: JSGlobalObject, offset: Timespec, js: ?Float64) {
        offsetRaw = offset
        let timespecMs = Float64(offset.ms())
        if js != None {
            dateNowOffset = Float64.floor(js!) - timespecMs
        }
        JSMock.setOverridenDateNow(globalObject, dateNowOffset + timespecMs)
        // 设置overridden_performance_now
        let vm = globalObject.bunVM()
        vm.overriddenPerformanceNow = Float64(offset.ns())
    }

    /// 清除时间覆盖
    public func clear(globalObject: JSGlobalObject) {
        offsetRaw = minTimespec
        JSMock.setOverridenDateNow(globalObject, -1.0)
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
        FakeTimers.currentTime.set(globalObject, offset: Timespec.epoch(), js: jsNow)
    }

    /// 停用假定时器
    public func deactivate(globalObject: JSGlobalObject) {
        clear()
        FakeTimers.currentTime.clear(globalObject)
        active = false
    }

    /// 清除所有定时器
    public func clear() {
        while let timer = timers.deleteMin() {
            timer.state = TimerState.CANCELLED
            timer.inHeap = InHeap.NONE
        }
    }

    /// 执行下一个定时器
    public func executeNext(globalObject: JSGlobalObject): Bool {
        let next = timers.deleteMin()
        if next == None { return false }
        fire(globalObject: globalObject, next: next!)
        return true
    }

    /// 触发定时器
    public func fire(globalObject: JSGlobalObject, next: EventLoopTimer) {
        let now = next.next
        FakeTimers.currentTime.set(globalObject, offset: now)
        let vm = globalObject.bunVM()
        next.fire(now: now, vm: vm)
    }

    /// 执行到指定时间
    public func executeUntil(globalObject: JSGlobalObject, until: Timespec) {
        while true {
            let peek = timers.peek()
            if peek == None { break }
            if peek!.next.greater(until) { break }
            let next = timers.deleteMin()
            if next != None {
                fire(globalObject: globalObject, next: next!)
            }
        }
    }

    /// 仅执行待处理的定时器
    public func executeOnlyPendingTimers(globalObject: JSGlobalObject) {
        let target = timers.findMax()
        if target == None { return }
        let until = target!.next
        executeUntil(globalObject: globalObject, until: until)
    }

    /// 执行所有定时器
    public func executeAllTimers(globalObject: JSGlobalObject) {
        while executeNext(globalObject: globalObject) {}
    }

    // ========== JS 函数 ==========

    /// 检查假定时器是否激活, 否则抛出错误
    private static func errorUnlessFakeTimers(globalObject: JSGlobalObject): ?JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers
        if fakeTimers.isActive() { return None }
        return globalObject.throw_("Fake timers are not active. Call useFakeTimers() first.")
    }

    /// 设置假定时器标记(setTimeout.clock)
    private static func setFakeTimerMarker(globalObject: JSGlobalObject, enabled: Bool) {
        let globalThisValue = globalObject.toJSValue()
        let setTimeoutFn = globalThisValue.getOwnTruthy(globalObject, key: "setTimeout") ?? return
        if enabled {
            setTimeoutFn.put(globalObject, key: "clock", value: JSValue.jsTrue)
        } else {
            setTimeoutFn.deleteProperty(globalObject, key: "clock")
        }
    }

    /// useFakeTimers - 安装假定时器
    public static func useFakeTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        var jsNow = JSMock.getCurrentUnixTimeMs()

        // 检查是否提供了选项对象
        let args = callFrame.argumentsAsArray(1)
        if args.length > 0 && !args[0].isUndefined() {
            let optionsValue = args[0]
            let config = FakeTimersConfig.fromJS(globalObject, value: optionsValue) ?? return JSValue.zero
            // 检查是否提供了'now'字段
            if !config.now.isUndefined() {
                if config.now.isNumber() {
                    jsNow = config.now.asNumber()
                } else if config.now.isDate() {
                    jsNow = config.now.getUnixTimestamp()
                } else {
                    globalObject.throwInvalidArguments("'now' must be a number or Date")
                    return JSValue.zero
                }
            }
        }

        fakeTimers.activate(jsNow: jsNow, globalObject: globalObject)

        // 设置setTimeout.clock = true
        setFakeTimerMarker(globalObject, enabled: true)

        return callFrame.this_()
    }

    /// useRealTimers - 恢复真实定时器
    public static func useRealTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        fakeTimers.deactivate(globalObject: globalObject)

        // 移除setTimeout.clock标记
        setFakeTimerMarker(globalObject, enabled: false)

        return callFrame.this_()
    }

    /// advanceTimersToNextTimer - 推进到下一个定时器
    public static func advanceTimersToNextTimer(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject: globalObject)
        if err != None { return err! }

        fakeTimers.executeNext(globalObject: globalObject)

        return callFrame.this_()
    }

    /// advanceTimersByTime - 按时间推进
    public static func advanceTimersByTime(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject: globalObject)
        if err != None { return err! }

        let arg = callFrame.argumentsAsArray(1)[0]
        if !arg.isNumber() {
            return globalObject.throwInvalidArguments("advanceTimersByTime() expects a number of milliseconds")
        }

        let current = FakeTimers.currentTime.getTimespecNow()
        if current == None {
            return globalObject.throwInvalidArguments("Fake timers not initialized. Initialize with useFakeTimers() first.")
        }

        let argNumber = arg.asNumber()
        let maxAdvance = Float64(UInt32.maxValue)
        if argNumber < 0 || argNumber > maxAdvance {
            return globalObject.throwInvalidArguments("advanceTimersByTime() ms is out of range. It must be >= 0 and <= ${UInt32.maxValue}. Received ${argNumber}")
        }

        // 当advanceTimersByTime(0)时, 推进1ms以触发setTimeout(fn, 0)
        // 这是因为setTimeout(fn, 0)内部按HTML规范有1ms延迟
        let effectiveAdvance = argNumber == 0 ? 1.0 : argNumber
        let target = current!.addMsFloat(effectiveAdvance)

        fakeTimers.executeUntil(globalObject: globalObject, until: target)
        FakeTimers.currentTime.set(globalObject, offset: target)

        return callFrame.this_()
    }

    /// runOnlyPendingTimers - 仅运行待处理的定时器
    public static func runOnlyPendingTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject: globalObject)
        if err != None { return err! }

        fakeTimers.executeOnlyPendingTimers(globalObject: globalObject)

        return callFrame.this_()
    }

    /// runAllTimers - 运行所有定时器
    public static func runAllTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject: globalObject)
        if err != None { return err! }

        fakeTimers.executeAllTimers(globalObject: globalObject)

        return callFrame.this_()
    }

    /// getTimerCount - 获取定时器数量
    public static func getTimerCount(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject: globalObject)
        if err != None { return err! }

        let count = fakeTimers.timers.count()
        return JSValue.jsNumber(count)
    }

    /// clearAllTimers - 清除所有定时器
    public static func clearAllTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        let err = errorUnlessFakeTimers(globalObject: globalObject)
        if err != None { return err! }

        fakeTimers.clear()

        return callFrame.this_()
    }

    /// isFakeTimers - 检查是否使用假定时器
    public static func isFakeTimers(globalObject: JSGlobalObject, callFrame: CallFrame): JSValue {
        let vm = globalObject.bunVM()
        let timer = vm.timer
        let fakeTimers = timer.fakeTimers

        let isActive = fakeTimers.isActive()
        return JSValue.jsBoolean(isActive)
    }

    /// 假定时器函数数量
    public static let timerFnsCount: UInt32 = 9

    /// 将定时器函数放入jest和vi对象
    public static func putTimersFns(globalObject: JSGlobalObject, jest: JSValue, vi: JSValue) {
        let fns: Array<(String, UInt32, (JSGlobalObject, CallFrame) -> JSValue)> = [
            ("useFakeTimers", 0, useFakeTimers),
            ("useRealTimers", 0, useRealTimers),
            ("advanceTimersToNextTimer", 0, advanceTimersToNextTimer),
            ("advanceTimersByTime", 1, advanceTimersByTime),
            ("runOnlyPendingTimers", 0, runOnlyPendingTimers),
            ("runAllTimers", 0, runAllTimers),
            ("getTimerCount", 0, getTimerCount),
            ("clearAllTimers", 0, clearAllTimers),
            ("isFakeTimers", 0, isFakeTimers),
        ]

        for fn in fns {
            let str = ZigString.static(fn.0)
            let jsValue = JSFunction.create(globalObject, name: fn.0, callback: fn.2, length: fn.1)
            vi.put(globalObject, key: str, value: jsValue)
            jest.put(globalObject, key: str, value: jsValue)
        }
    }
}

/// 假定时器配置
public class FakeTimersConfig {
    public var now: JSValue = JSValue.jsUndefined

    public init() {}

    public static func fromJS(globalObject: JSGlobalObject, value: JSValue): ?FakeTimersConfig {
        if !value.isObject() { return None }
        let config = FakeTimersConfig()
        config.now = value.get(globalObject, key: "now") ?? JSValue.jsUndefined
        return config
    }

    public func deinit() {}
}
