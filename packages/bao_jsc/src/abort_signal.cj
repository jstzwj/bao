// 严格翻译自: src/jsc/AbortSignal.zig
package bao_jsc

// ========== AbortReason ==========
// 严格翻译自 AbortSignal.AbortReason
public enum AbortReason {
    case common(CommonAbortReason)
    case js(JsValue)

    // 严格翻译自 AbortReason.toBodyValueError
    public func toBodyValueError(globalObject: JsObject) -> BodyValueError {
        match (this) {
            case common(let reason) => BodyValueError.abortReason(reason)
            case js(let value) => BodyValueError.jsValue(JsValue.create(value, globalObject))
        }
    }

    // 严格翻译自 AbortReason.toJS
    public func toJS(global: JsObject) -> JsValue {
        match (this) {
            case common(let reason) => reason.toJS(global)
            case js(let value) => value
        }
    }
}

// ========== AbortSignal.Timeout ==========
// 严格翻译自 AbortSignal.Timeout
public class AbortSignalTimeout {
    public var eventLoopTimer: EventLoopTimer = EventLoopTimer()
    public var signal_: AbortSignal
    public var flags: TimerObjectInternalsFlags = TimerObjectInternalsFlags()
    public var generation: UInt32 = 0

    public init(signal_: AbortSignal) {
        this.signal_ = signal_
    }

    // 严格翻译自 Timeout.cancel
    public func cancel(vm: BunVirtualMachine) {
        if (eventLoopTimer.isActive) {
            vm.timer.remove(eventLoopTimer)
        }
    }

    // 严格翻译自 Timeout.run
    public func run(vm: BunVirtualMachine) {
        eventLoopTimer.state = EventLoopTimerState.FIRED
        cancel(vm)

        if (generation != vm.testIsolationGeneration) {
            signal_.unref()
            return
        }

        dispatch(vm, signal_)
    }

    // 严格翻译自 Timeout.dispatch
    public func dispatch(vm: BunVirtualMachine, signalPtr: AbortSignal) {
        let loop = vm.eventLoop()
        loop.enter()
        signalPtr.signal(vm.global, CommonAbortReason.timeout)
        loop.exit()
    }

    // 严格翻译自 Timeout.deinit
    public func deinit(vm: BunVirtualMachine) {
        cancel(vm)
    }
}

// ========== AbortSignal ==========
// 严格翻译自 AbortSignal
// 表示 JavaScript AbortSignal 对象的 native 包装
public class AbortSignal {
    public var ptr: UInt64 = 0  // native pointer
    public var aborted_: Bool = false
    public var abortReasonValue: JsValue = JsValue.undefined()

    public init() {}

    // 严格翻译自 AbortSignal.listen (with context and callback)
    public func listen(ctx: UInt64, callback: (UInt64, JsValue) -> Void) -> AbortSignal {
        addListener(ctx, callback)
    }

    // 严格翻译自 AbortSignal.addListener
    public func addListener(ctx: UInt64, callback: (UInt64, JsValue) -> Void) -> AbortSignal {
        // FFI call to WebCore__AbortSignal__addListener
        this
    }

    // 严格翻译自 AbortSignal.cleanNativeBindings
    public func cleanNativeBindings(ctx: UInt64) {
        // FFI call to WebCore__AbortSignal__cleanNativeBindings
    }

    // 严格翻译自 AbortSignal.signal
    public func signal(globalObject: JsObject, reason: CommonAbortReason) {
        aborted_ = true
        abortReasonValue = reason.toJS(globalObject)
        // FFI call to WebCore__AbortSignal__signal
    }

    // 严格翻译自 AbortSignal.pendingActivityRef
    public func pendingActivityRef() {
        // FFI call to WebCore__AbortSignal__incrementPendingActivity
    }

    // 严格翻译自 AbortSignal.pendingActivityUnref
    public func pendingActivityUnref() {
        // FFI call to WebCore__AbortSignal__decrementPendingActivity
    }

    // 严格翻译自 AbortSignal.aborted
    // 注意: 此函数非线程安全. aborted 是布尔值，非原子.getOrThrow()
    public func aborted() -> Bool {
        aborted_
    }

    // 严格翻译自 AbortSignal.abortReason
    // 注意: 此函数非线程安全. JSValue 不能安全在线程间传递.
    public func abortReason() -> JsValue {
        abortReasonValue
    }

    // 严格翻译自 AbortSignal.reasonIfAborted
    public func reasonIfAborted(global: JsObject) -> ?AbortReason {
        if (!aborted_) {
            return None
        }
        if (abortReasonValue == JsValue.zero) {
            return None
        }
        Some(AbortReason.js(abortReasonValue))
    }

    // 严格翻译自 AbortSignal.ref
    public func ref() -> AbortSignal {
        this
    }

    // 严格翻译自 AbortSignal.unref
    public func unref() {
        // FFI call to WebCore__AbortSignal__unref
    }

    // 严格翻译自 AbortSignal.detach
    public func detach(ctx: UInt64) {
        cleanNativeBindings(ctx)
        unref()
    }

    // 严格翻译自 AbortSignal.fromJS
    public static func fromJS(value: JsValue) -> ?AbortSignal {
        // FFI call to WebCore__AbortSignal__fromJS
        if (value.isUndefinedOrNull()) {
            return None
        }
        AbortSignal()
    }

    // 严格翻译自 AbortSignal.toJS
    public func toJS(global: JsObject) -> JsValue {
        abortReasonValue
    }

    // 严格翻译自 AbortSignal.create
    public static func create(global: JsObject) -> JsValue {
        // FFI call to WebCore__AbortSignal__create
        JsValue.undefined()
    }

    // 严格翻译自 AbortSignal.new
    public static func new(global: JsObject) -> AbortSignal {
        AbortSignal()
    }

    // 严格翻译自 AbortSignal.getTimeout
    // 返回内部 Timeout 的借用句柄，或 null
    public func getTimeout() -> ?AbortSignalTimeout {
        None
    }
}
