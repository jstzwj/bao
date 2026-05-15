// 严格翻译自: src/runtime/timer/TimerObjectInternals.zig
// TimerObject 和 ImmediateObject 共有的内部数据

package bao_runtime

import bao_core.*
import bao_jsc.*
import bao_event_loop.*

// ============================================================================
// TimerObjectInternals - 定时器对象内部数据
// 严格翻译自: TimerObjectInternals (@This())
//   TimerObject 和 ImmediateObject 共有的数据
//   包含: id, interval, this_value, flags, generation
//   以及: fire, run, cancel, ref, deref 等方法
// ============================================================================

/// 定时器对象内部数据 - 对应 Bun TimerObjectInternals
/// TimerObject 和 ImmediateObject 共有的数据
public class TimerObjectInternals {
    /// 暴露给 JavaScript 的定时器 ID - 对应 Bun id: i32 = -1
    /// (通过 +timer 暴露)
    public var id: Int32 = -1

    /// 间隔时间 (毫秒) - 对应 Bun interval: u31 = 0
    public var interval: Int32 = 0

    /// JS 引用 (this 值) - 对应 Bun this_value: jsc.JSRef = .empty()
    public var thisValue: JSRef = JSRef.empty()

    /// 标志 - 对应 Bun flags: Flags = .{}
    public var flags: TimerFlags = TimerFlags()

    /// 测试隔离代 - 对应 Bun generation: u32 = 0
    /// bun test --isolate 创建此定时器的 generation
    /// 如果在触发时不匹配 vm.test_isolation_generation，定时器被丢弃
    public var generation: UInt32 = 0

    /// 所属的 TimeoutObject 或 ImmediateObject 引用
    public var ownerTimeout: ?TimeoutObject = None
    public var ownerImmediate: ?ImmediateObject = None

    public init() {}

    // ========================================================================
    // eventLoopTimer - 获取关联的事件循环定时器
    // 严格翻译自: TimerObjectInternals.eventLoopTimer
    //   fn eventLoopTimer(this: *TimerObjectInternals) *EventLoopTimer {
    //       switch (this.flags.kind) {
    //           .setImmediate => { ... return &parent.event_loop_timer; },
    //           .setTimeout, .setInterval => { ... return &parent.event_loop_timer; },
    //       }
    //   }
    // ========================================================================

    /// 获取关联的事件循环定时器 - 对应 Bun eventLoopTimer
    public func eventLoopTimer(): EventLoopTimer {
        match (flags.kind) {
            case Kind.setImmediate => {
                if (let Some(parent) <- ownerImmediate) {
                    return parent.eventLoopTimer
                }
                return EventLoopTimer(TimerTagKind.Immediate)
            }
            case Kind.setTimeout => {
                if (let Some(parent) <- ownerTimeout) {
                    return parent.eventLoopTimer
                }
                return EventLoopTimer(TimerTagKind.Timeout)
            }
            case Kind.setInterval => {
                if (let Some(parent) <- ownerTimeout) {
                    return parent.eventLoopTimer
                }
                return EventLoopTimer(TimerTagKind.Timeout)
            }
        }
    }

    // ========================================================================
    // ref / deref - 引用计数操作
    // 严格翻译自: TimerObjectInternals.ref / deref
    //   fn ref(this: *TimerObjectInternals) void {
    //       switch (this.flags.kind) {
    //           .setImmediate => @as(*ImmediateObject, ...).ref(),
    //           .setTimeout, .setInterval => @as(*TimeoutObject, ...).ref(),
    //       }
    //   }
    // ========================================================================

    /// 增加引用 - 对应 Bun ref
    public func ref(): Unit {
        match (flags.kind) {
            case Kind.setImmediate => {
                if (let Some(parent) <- ownerImmediate) {
                    parent.ref()
                }
            }
            case Kind.setTimeout => {
                if (let Some(parent) <- ownerTimeout) {
                    parent.ref()
                }
            }
            case Kind.setInterval => {
                if (let Some(parent) <- ownerTimeout) {
                    parent.ref()
                }
            }
        }
    }

    /// 减少引用 - 对应 Bun deref
    public func deref(): Unit {
        match (flags.kind) {
            case Kind.setImmediate => {
                if (let Some(parent) <- ownerImmediate) {
                    parent.deref()
                }
            }
            case Kind.setTimeout => {
                if (let Some(parent) <- ownerTimeout) {
                    parent.deref()
                }
            }
            case Kind.setInterval => {
                if (let Some(parent) <- ownerTimeout) {
                    parent.deref()
                }
            }
        }
    }

    // ========================================================================
    // asyncID - 获取异步 ID
    // 严格翻译自: TimerObjectInternals.asyncID
    //   pub fn asyncID(this: *const TimerObjectInternals) u64 {
    //       return ID.asyncID(.{ .id = this.id, .kind = this.flags.kind.big() });
    //   }
    // ========================================================================

    /// 获取异步 ID - 对应 Bun asyncID
    public func asyncID(): UInt64 {
        let timerId = TimerID(id, flags.kind.big())
        timerId.asyncID()
    }

    // ========================================================================
    // runImmediateTask - 运行 Immediate 任务
    // 严格翻译自: TimerObjectInternals.runImmediateTask
    //   处理 setImmediate 回调的执行
    //   返回 true 如果抛出了异常
    // ========================================================================

    /// 运行 Immediate 任务 - 对应 Bun runImmediateTask
    /// 返回 true 如果抛出了异常
    public func runImmediateTask(vm: VirtualMachine): Bool {
        if (flags.hasClearedTimer ||
            generation != vm.testIsolationGeneration ||
            // 未 ref 的 setImmediate 回调只应在有其他事物保持事件循环活跃时运行
            (!flags.isKeepingEventLoopAlive && !vm.isEventLoopAliveExcludingImmediates())) {

            setEnableKeepingEventLoopAlive(vm, false)
            thisValue.downgrade()
            deref()
            return false
        }

        let timer = thisValue.tryGet()
        if (timer == None) {
            setEnableKeepingEventLoopAlive(vm, false)
            deref()
            return false
        }

        let timerValue = timer.getOrThrow()
        thisValue.downgrade()
        eventLoopTimer().state = TimerState.Fired
        setEnableKeepingEventLoopAlive(vm, false)
        timerValue.ensureStillAlive()

        // 进入事件循环
        vm.enterEventLoop()

        let callback = ImmediateObject.jsCallbackGetCached(timerValue)
        let arguments = ImmediateObject.jsArgumentsGetCached(timerValue)

        var exceptionThrown = false

        // 引用管理
        ref()
        let exceptionThrown_ = run(vm.global, timerValue, callback, arguments, asyncID(), vm)
        exceptionThrown = exceptionThrown_

        // 退出后检查状态
        if (eventLoopTimer().state == TimerState.Fired) {
            deref()
        }
        deref()

        // --- 此点之后，定时器不再保证存活 ---

        vm.exitEventLoopMaybeDrainMicrotasks(!exceptionThrown)

        return exceptionThrown
    }

    // ========================================================================
    // fire - 定时器触发
    // 严格翻译自: TimerObjectInternals.fire
    //   这是 setTimeout/setInterval/setImmediate 的核心触发逻辑
    //   处理:
    //     1. 检查是否已清除
    //     2. 获取回调、参数
    //     3. 执行回调
    //     4. 处理 setInterval 的重新调度
    //     5. 处理 setTimeout -> setInterval 的转换
    // ========================================================================

    /// 定时器触发 - 对应 Bun fire
    public func fire(timeSpec: Timespec, vm: VirtualMachine): Unit {
        let id_ = id
        let kind = flags.kind.big()
        let asyncId = TimerID(id_, kind)
        let hasBeenCleared = eventLoopTimer().state == TimerState.Cancelled ||
            flags.hasClearedTimer ||
            vm.scriptExecutionStatus() != ScriptExecutionStatus.Running ||
            generation != vm.testIsolationGeneration

        eventLoopTimer().state = TimerState.Fired

        let globalThis = vm.global
        let thisObject_ = thisValue.tryGet()

        if (thisObject_ == None) {
            setEnableKeepingEventLoopAlive(vm, false)
            flags.hasClearedTimer = true
            thisValue.downgrade()
            deref()
            return
        }

        let thisObject = thisObject_.getOrThrow()

        // 获取回调、参数、idleTimeout、repeat
        var callback: JSValue = JSValue.jsUndefined()
        var arguments: JSValue = JSValue.jsUndefined()
        var idleTimeout: JSValue = JSValue.jsUndefined()
        var repeat: JSValue = JSValue.jsUndefined()

        match (kind) {
            case KindBig.setImmediate => {
                callback = ImmediateObject.jsCallbackGetCached(thisObject)
                arguments = ImmediateObject.jsArgumentsGetCached(thisObject)
            }
            case KindBig.setTimeout => {
                callback = TimeoutObject.jsCallbackGetCached(thisObject)
                arguments = TimeoutObject.jsArgumentsGetCached(thisObject)
                idleTimeout = TimeoutObject.jsIdleTimeoutGetCached(thisObject)
                repeat = TimeoutObject.jsRepeatGetCached(thisObject)
            }
            case KindBig.setInterval => {
                callback = TimeoutObject.jsCallbackGetCached(thisObject)
                arguments = TimeoutObject.jsArgumentsGetCached(thisObject)
                idleTimeout = TimeoutObject.jsIdleTimeoutGetCached(thisObject)
                repeat = TimeoutObject.jsRepeatGetCached(thisObject)
            }
        }

        if (hasBeenCleared || !callback.toBoolean()) {
            if (vm.isInspectorEnabled()) {
                Debugger.didCancelAsyncCall(globalThis, DOMTimer, asyncId.asyncID())
            }
            setEnableKeepingEventLoopAlive(vm, false)
            flags.hasClearedTimer = true
            thisValue.downgrade()
            deref()
            return
        }

        var timeBeforeCall = Timespec()

        if (kind != KindBig.setInterval) {
            thisValue.downgrade()
        } else {
            timeBeforeCall = Timespec.msFromNow(true, interval)
        }
        thisObject.ensureStillAlive()

        vm.enterEventLoop()
        // 确保在此作用域内保持活跃
        ref()

        let _ = run(globalThis, thisObject, callback, arguments, asyncId.asyncID(), vm)

        // 重新获取可能被回调修改的值
        match (kind) {
            case KindBig.setTimeout => {
                idleTimeout = TimeoutObject.jsIdleTimeoutGetCached(thisObject)
                repeat = TimeoutObject.jsRepeatGetCached(thisObject)
            }
            case KindBig.setInterval => {
                idleTimeout = TimeoutObject.jsIdleTimeoutGetCached(thisObject)
                repeat = TimeoutObject.jsRepeatGetCached(thisObject)
            }
            case KindBig.setImmediate => {}
        }

        let isTimerDone = checkTimerDone(kind, repeat, idleTimeout, thisObject, timeBeforeCall, vm, globalThis)

        if (isTimerDone) {
            setEnableKeepingEventLoopAlive(vm, false)
            // 定时器不会再被重新插入事件循环
            deref()
        }

        // defer this.deref() - 引用管理的后半部分
        deref()

        vm.exitEventLoop()
    }

    /// 检查定时器是否完成 - 对应 Bun fire 中的 is_timer_done 逻辑
    func checkTimerDone(
        kind: KindBig,
        repeat: JSValue,
        idleTimeout: JSValue,
        thisObject: JSValue,
        timeBeforeCall: Timespec,
        vm: VirtualMachine,
        globalThis: JSGlobalObject
    ): Bool {
        if (kind == KindBig.setInterval) {
            // setInterval 处理
            if (!shouldRescheduleTimer(repeat, idleTimeout)) {
                return true
            }
            match (eventLoopTimer().state) {
                case TimerState.Fired => {
                    // 如果没有 clear setInterval，从 timeBeforeCall 重新调度
                    vm.timer.update(eventLoopTimer(), timeBeforeCall)

                    if (flags.hasJsRef) {
                        setEnableKeepingEventLoopAlive(vm, true)
                    }
                    // 引用计数不变，没有减少
                    return false
                }
                case TimerState.Active => {
                    // 开发者在回调中同步调用了 timer.refresh()
                    vm.timer.update(eventLoopTimer(), timeBeforeCall)
                    // 平衡引用计数
                    // 从 "FIRED" -> "ACTIVE" 的转换导致它增加了
                    deref()
                    return false
                }
                case _ => {
                    return true
                }
            }
        } else {
            // setTimeout 处理
            if (kind == KindBig.setTimeout && !repeat.isNull()) {
                let numOpt = idleTimeout.getNumber()
                if (numOpt != None) {
                    let num = numOpt.getOrThrow()
                    if (num != -1.0) {
                        // convertToInterval 会看到 state == .FIRED
                        // 并添加一个 ref；落入下面的 switch 让 .ACTIVE 分支平衡它
                        convertToInterval(globalThis, thisObject, repeat)
                    }
                }
            }

            match (eventLoopTimer().state) {
                case TimerState.Fired => {
                    return true
                }
                case TimerState.Active => {
                    // 开发者在回调中同步调用了 timer.refresh()
                    // 或者定时器通过 t._repeat 被转换为 interval
                    // 平衡引用计数: reschedule 从 "FIRED" -> "ACTIVE" 的转换导致增加
                    deref()
                    return false
                }
                case _ => {
                    // 开发者在回调中同步调用了 clearTimeout()
                    // cancel 看到 state == .FIRED 并跳过了它的 deref
                    // 所以在这里释放堆引用
                    return true
                }
            }
        }
    }

    // ========================================================================
    // convertToInterval - 将 setTimeout 转换为 setInterval
    // 严格翻译自: TimerObjectInternals.convertToInterval
    // ========================================================================

    /// 将 setTimeout 转换为 setInterval - 对应 Bun convertToInterval
    func convertToInterval(global: JSGlobalObject, timer: JSValue, repeat: JSValue): Unit {
        let vm = global.bunVM()

        let newInterval: Int32 = if (let Some(num) <- repeat.getNumber()) {
            if (num < 1.0 || num > 2147483647.0) {
                Int32(1)
            } else {
                Int32(num)
            }
        } else {
            Int32(1)
        }

        // https://github.com/nodejs/node/blob/a7cbb904745591c9a9d047a364c2c188e5470047/lib/internal/timers.js#L613
        TimeoutObject.jsIdleTimeoutSetCached(timer, global, repeat)
        thisValue.setStrong(timer, global)
        flags.kind = Kind.setInterval
        interval = newInterval
        reschedule(timer, vm, global)
    }

    // ========================================================================
    // run - 执行定时器回调
    // 严格翻译自: TimerObjectInternals.run
    //   调用 Bun__JSTimeout__call 执行 JavaScript 回调
    //   如果 Inspector 启用，会发送调度通知
    // ========================================================================

    /// 执行定时器回调 - 对应 Bun run
    /// 返回 true 如果抛出了异常
    public func run(globalThis: JSGlobalObject, timer: JSValue, callback: JSValue, arguments: JSValue, asyncId: UInt64, vm: VirtualMachine): Bool {
        if (vm.isInspectorEnabled()) {
            Debugger.willDispatchAsyncCall(globalThis, DOMTimer, asyncId)
        }

        // Bun__JSTimeout__call 处理异常
        flags.inCallback = true
        let exceptionThrown = bunJSTimeoutCall(globalThis, timer, callback, arguments)
        flags.inCallback = false

        if (vm.isInspectorEnabled()) {
            Debugger.didDispatchAsyncCall(globalThis, DOMTimer, asyncId)
        }

        return exceptionThrown
    }

    /// 外部函数声明 - 对应 Bun Bun__JSTimeout__call
    extern "c" func bunJSTimeoutCall(globalObject: JSGlobalObject, timer: JSValue, callback: JSValue, arguments: JSValue): Bool

    // ========================================================================
    // init - 初始化定时器内部数据
    // 严格翻译自: TimerObjectInternals.init
    //   设置 ID、flags、interval、generation
    //   对于 setImmediate: 入队 immediate 任务
    //   对于 setTimeout/setInterval: 重新调度
    // ========================================================================

    /// 初始化定时器内部数据 - 对应 Bun init
    public func init(
        timer: JSValue,
        global: JSGlobalObject,
        id: Int32,
        kind: Kind,
        interval: Int32,
        callback: JSValue,
        arguments: JSValue
    ): Unit {
        let vm = global.bunVM()
        this.id = id
        this.flags.kind = kind
        this.flags.epoch = vm.timer.epoch
        this.interval = interval
        this.generation = vm.testIsolationGeneration

        if (kind == Kind.setImmediate) {
            ImmediateObject.jsArgumentsSetCached(timer, global, arguments)
            ImmediateObject.jsCallbackSetCached(timer, global, callback)
            if (let Some(parent) <- ownerImmediate) {
                vm.enqueueImmediateTask(parent)
            }
            setEnableKeepingEventLoopAlive(vm, true)
            // 由事件循环 ref
            if (let Some(parent) <- ownerImmediate) {
                parent.ref()
            }
        } else {
            TimeoutObject.jsArgumentsSetCached(timer, global, arguments)
            TimeoutObject.jsCallbackSetCached(timer, global, callback)
            TimeoutObject.jsIdleTimeoutSetCached(timer, global, JSValue.jsNumber(interval))
            TimeoutObject.jsRepeatSetCached(timer, global, if (kind == Kind.setInterval) JSValue.jsNumber(interval) else JSValue.jsNull())

            // 这会递增引用计数并设置 _idleStart
            reschedule(timer, vm, global)
        }

        thisValue.setStrong(timer, global)
    }

    // ========================================================================
    // doRef / doRefresh / doUnref - JS ref/unref/refresh 操作
    // 严格翻译自: TimerObjectInternals.doRef / doRefresh / doUnref
    // ========================================================================

    /// ref 操作 - 对应 Bun doRef
    public func doRef(globalThis: JSGlobalObject, thisValue: JSValue): JSValue {
        thisValue.ensureStillAlive()

        let didHaveJsRef = flags.hasJsRef
        flags.hasJsRef = true

        // https://github.com/nodejs/node/blob/a7cbb904745591c9a9d047a364c2c188e5470047/lib/internal/timers.js#L256
        // 和
        // https://github.com/nodejs/node/blob/a7cbb904745591c9a9d047a364c2c188e5470047/lib/internal/timers.js#L685-L687
        // Node 只在 !this._destroyed 时重新启用 keep-alive ref
        // 只检查 has_cleared_timer 不够: 已触发的一次性定时器 has_cleared_timer == false
        // 但仍然已销毁。对这样的定时器调用 .unref(); .ref() 会泄漏事件循环引用并挂起进程
        if (!didHaveJsRef && !getDestroyed()) {
            setEnableKeepingEventLoopAlive(VirtualMachine.get(), true)
        }

        return thisValue
    }

    /// refresh 操作 - 对应 Bun doRefresh
    public func doRefresh(globalObject: JSGlobalObject, thisValue: JSValue): JSValue {
        // Immediate 没有 refresh 函数
        if (flags.kind == Kind.setImmediate) {
            return thisValue
        }

        // setImmediate 不支持 refresh，清除后也不支持
        if (id == -1 || flags.kind == Kind.setImmediate || flags.hasClearedTimer) {
            return thisValue
        }

        thisValue.setStrong(thisValue, globalObject)
        reschedule(thisValue, VirtualMachine.get(), globalObject)

        return thisValue
    }

    /// unref 操作 - 对应 Bun doUnref
    public func doUnref(globalThis: JSGlobalObject, thisValue: JSValue): JSValue {
        thisValue.ensureStillAlive()

        let didHaveJsRef = flags.hasJsRef
        flags.hasJsRef = false

        if (didHaveJsRef) {
            setEnableKeepingEventLoopAlive(VirtualMachine.get(), false)
        }

        return thisValue
    }

    // ========================================================================
    // cancel - 取消定时器
    // 严格翻译自: TimerObjectInternals.cancel
    //   设置 has_cleared_timer = true
    //   对于 setImmediate: 降级引用
    //   对于 setTimeout/setInterval: 从堆中移除
    // ========================================================================

    /// 取消定时器 - 对应 Bun cancel
    public func cancel(vm: VirtualMachine): Unit {
        setEnableKeepingEventLoopAlive(vm, false)
        flags.hasClearedTimer = true

        if (flags.kind == Kind.setImmediate) {
            // 释放强引用以便 GC 可以回收 JS 对象
            // immediate 任务仍在事件循环队列中
            // runImmediateTask 看到 has_cleared_timer == true 时会跳过
            thisValue.downgrade()
            return
        }

        let wasActive = eventLoopTimer().state == TimerState.Active
        eventLoopTimer().state = TimerState.Cancelled
        thisValue.downgrade()

        if (wasActive) {
            vm.timer.remove(eventLoopTimer())
            deref()
        }
    }

    // ========================================================================
    // shouldRescheduleTimer - 检查是否应该重新调度
    // 严格翻译自: TimerObjectInternals.shouldRescheduleTimer
    // ========================================================================

    /// 检查是否应该重新调度 - 对应 Bun shouldRescheduleTimer
    func shouldRescheduleTimer(repeat: JSValue, idleTimeout: JSValue): Bool {
        if (flags.kind == Kind.setInterval && repeat.isNull()) {
            return false
        }
        if (let Some(num) <- idleTimeout.getNumber()) {
            if (num == -1.0) {
                return false
            }
        }
        return true
    }

    // ========================================================================
    // reschedule - 重新调度定时器
    // 严格翻译自: TimerObjectInternals.reschedule
    //   对于 setImmediate: 立即返回 (不支持)
    //   获取 idleTimeout 和 repeat，检查是否应该重新调度
    //   计算新的调度时间，插入堆中
    // ========================================================================

    /// 重新调度定时器 - 对应 Bun reschedule
    public func reschedule(timer: JSValue, vm: VirtualMachine, globalThis: JSGlobalObject): Unit {
        if (flags.kind == Kind.setImmediate) {
            return
        }

        let idleTimeout = TimeoutObject.jsIdleTimeoutGetCached(timer)
        let repeat = TimeoutObject.jsRepeatGetCached(timer)

        // https://github.com/nodejs/node/blob/a7cbb904745591c9a9d047a364c2c188e5470047/lib/internal/timers.js#L612
        if (!shouldRescheduleTimer(repeat, idleTimeout)) {
            return
        }

        let now = Timespec.nowAllowMocked()
        let scheduledTime = now.addMs(Int64(interval))
        let wasActive = eventLoopTimer().state == TimerState.Active
        if (wasActive) {
            vm.timer.remove(eventLoopTimer())
        } else {
            ref()
        }

        vm.timer.update(eventLoopTimer(), scheduledTime)
        flags.hasClearedTimer = false

        // 设置 _idleStart 为当前单调时间戳 (毫秒)
        // 这模仿 Node.js 的行为: _idleStart 是调度定时器时的 libuv 时间戳
        TimeoutObject.jsIdleStartSetCached(timer, globalThis, JSValue.jsNumberFromInt64(now.toMillisUnsigned()))

        if (flags.hasJsRef) {
            setEnableKeepingEventLoopAlive(vm, true)
        }
    }

    // ========================================================================
    // setEnableKeepingEventLoopAlive - 设置是否保持事件循环活跃
    // 严格翻译自: TimerObjectInternals.setEnableKeepingEventLoopAlive
    // ========================================================================

    /// 设置是否保持事件循环活跃 - 对应 Bun setEnableKeepingEventLoopAlive
    func setEnableKeepingEventLoopAlive(vm: VirtualMachine, enable: Bool): Unit {
        if (flags.isKeepingEventLoopAlive == enable) {
            return
        }
        flags.isKeepingEventLoopAlive = enable
        match (flags.kind) {
            case Kind.setTimeout => vm.timer.incrementTimerRef(if (enable) Int32(1) else Int32(-1))
            case Kind.setInterval => vm.timer.incrementTimerRef(if (enable) Int32(1) else Int32(-1))
            // setImmediate 有略微不同的事件循环逻辑
            case Kind.setImmediate => vm.timer.incrementImmediateRef(if (enable) Int32(1) else Int32(-1))
        }
    }

    // ========================================================================
    // hasRef - 检查是否有引用
    // 严格翻译自: TimerObjectInternals.hasRef
    // ========================================================================

    /// 检查是否有引用 - 对应 Bun hasRef
    public func hasRef(): JSValue {
        JSValue.jsBoolean(flags.isKeepingEventLoopAlive)
    }

    // ========================================================================
    // toPrimitive - 转为原始值
    // 严格翻译自: TimerObjectInternals.toPrimitive
    //   如果第一次访问，创建 hashmap 条目
    //   返回 ID 作为数字
    // ========================================================================

    /// 转为原始值 - 对应 Bun toPrimitive
    public func toPrimitive(): JSValue {
        if (!flags.hasAccessedPrimitive) {
            flags.hasAccessedPrimitive = true
            let vm = VirtualMachine.get()
            vm.timer.maps.get(flags.kind).put(id, eventLoopTimer())
        }
        return JSValue.jsNumber(id)
    }

    // ========================================================================
    // getDestroyed - 获取 _destroyed 属性
    // 严格翻译自: TimerObjectInternals.getDestroyed
    //   这是 JS Timeout 和 Immediate 对象上 _destroyed 的 getter
    // ========================================================================

    /// 获取 _destroyed 属性 - 对应 Bun getDestroyed
    /// 这是 JS Timeout 和 Immediate 对象上 _destroyed 的 getter
    public func getDestroyed(): Bool {
        if (flags.hasClearedTimer) {
            return true
        }
        if (flags.inCallback) {
            return false
        }
        return match (eventLoopTimer().state) {
            case TimerState.Active => false
            case TimerState.Pending => false
            case TimerState.Fired => true
            case TimerState.Cancelled => true
        }
    }

    // ========================================================================
    // finalize - GC 终结
    // 严格翻译自: TimerObjectInternals.finalize
    // ========================================================================

    /// GC 终结 - 对应 Bun finalize
    public func finalize(): Unit {
        thisValue.finalize()
        deref()
    }

    // ========================================================================
    // deinit - 析构
    // 严格翻译自: TimerObjectInternals.deinit
    //   清理定时器，释放资源
    // ========================================================================

    /// 析构 - 对应 Bun deinit
    public func deinit(): Unit {
        thisValue.deinit()
        let vm = VirtualMachine.get()
        let kind = flags.kind

        if (eventLoopTimer().state == TimerState.Active) {
            vm.timer.remove(eventLoopTimer())
        }

        if (flags.hasAccessedPrimitive) {
            let map = vm.timer.maps.get(kind)
            if (map.orderedRemove(id) != None) {
                // 如果数组变大了，缩小它
                // 数组键是 i32，值是 1 个指针 = 12 字节/条目
                // 所以如果创建了 21,000 个定时器并通过 ID 访问，就使用 252KB
                let allocatedBytes = map.capacity() * 12
                let usedBytes = map.count() * 12
                if (allocatedBytes - usedBytes > 262144) {
                    map.shrinkAndFree(map.count() + 8)
                }
            }
        }

        setEnableKeepingEventLoopAlive(vm, false)

        // 断言没有残留引用
        match (kind) {
            case Kind.setImmediate => {
                if (let Some(parent) <- ownerImmediate) {
                    parent.refCount.assertNoRefs()
                }
            }
            case Kind.setTimeout => {
                if (let Some(parent) <- ownerTimeout) {
                    parent.refCount.assertNoRefs()
                }
            }
            case Kind.setInterval => {
                if (let Some(parent) <- ownerTimeout) {
                    parent.refCount.assertNoRefs()
                }
            }
        }
    }
}

// ============================================================================
// JSRef - JavaScript 引用
// 对应 Bun jsc.JSRef
// ============================================================================

/// JavaScript 引用 - 对应 Bun jsc.JSRef
/// 管理 JS 值的强/弱引用
public class JSRef {
    private var strong: ?JSValue = None
    private var weak: ?JSValue = None

    public init() {}

    /// 空引用 - 对应 Bun JSRef.empty()
    public static func empty(): JSRef {
        JSRef()
    }

    /// 设置强引用 - 对应 Bun JSRef.setStrong
    public func setStrong(value: JSValue, global: JSGlobalObject): Unit {
        strong = value
    }

    /// 降级为弱引用 - 对应 Bun JSRef.downgrade
    public func downgrade(): Unit {
        weak = strong
        strong = None
    }

    /// 尝试获取值 - 对应 Bun JSRef.tryGet
    public func tryGet(): ?JSValue {
        if (strong != None) {
            return strong
        }
        weak
    }

    /// 终结 - 对应 Bun JSRef.finalize
    public func finalize(): Unit {
        strong = None
        weak = None
    }

    /// 析构 - 对应 Bun JSRef.deinit
    public func deinit(): Unit {
        strong = None
        weak = None
    }
}

/// DOMTimer 常量 - 对应 Bun Debugger.AsyncCallType.DOMTimer
public let DOMTimer: Int64 = 0
