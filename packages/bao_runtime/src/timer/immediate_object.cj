// 严格翻译自: src/runtime/timer/ImmediateObject.zig
// Immediate 对象 - setImmediate 的内部实现

package bao_runtime.timer

import bao_core.*
import bao_jsc.*
import bao_event_loop.*

// ============================================================================
// ImmediateObject - Immediate 对象
// 严格翻译自: ImmediateObject (@This())
//   setImmediate 创建的定时器对象
//   包含引用计数、事件循环定时器和内部数据
//   与 TimeoutObject 类似但 simpler (无 interval/repeat 逻辑)
// ============================================================================

/// Immediate 对象 - 对应 Bun ImmediateObject
/// setImmediate 创建的定时器对象
public class ImmediateObject {
    /// 引用计数 - 对应 Bun ref_count: RefCount
    public var refCount: RefCount

    /// 事件循环定时器 - 对应 Bun event_loop_timer: EventLoopTimer
    /// 初始化:
    ///   .next = .epoch
    ///   .tag = .ImmediateObject
    public var eventLoopTimer: EventLoopTimer

    /// 内部数据 - 对应 Bun internals: TimerObjectInternals
    public var internals: TimerObjectInternals

    public init() {
        refCount = RefCount()
        eventLoopTimer = EventLoopTimer(TimerTagKind.Immediate)
        internals = TimerObjectInternals()
        internals.ownerImmediate = this
    }

    // ========================================================================
    // init - 创建 Immediate 并初始化
    // 严格翻译自: ImmediateObject.init
    //   pub fn init(
    //       globalThis: *JSGlobalObject,
    //       id: i32,
    //       callback: JSValue,
    //       arguments: JSValue,
    //   ) JSValue
    //   注意: kind 总是 .setImmediate, interval 总是 0
    // ========================================================================

    /// 创建并初始化 Immediate - 对应 Bun ImmediateObject.init
    public static func init_(
        globalThis: JSGlobalObject,
        id: Int32,
        callback: JSValue,
        arguments: JSValue
    ): JSValue {
        // internals 由 init() 初始化
        let immediate = ImmediateObject()
        immediate.refCount.init_()

        let jsValue = immediate.toJS(globalThis)
        jsValue.ensureStillAlive()

        immediate.internals.init(
            jsValue,
            globalThis,
            id,
            Kind.setImmediate,  // kind 总是 setImmediate
            Int32(0),           // interval 总是 0
            callback,
            arguments
        )

        if (globalThis.bunVM().isInspectorEnabled()) {
            let timerId = TimerID(id, KindBig.setImmediate)
            Debugger.didScheduleAsyncCall(
                globalThis,
                DOMTimer,
                timerId.asyncID(),
                true  // once = true
            )
        }

        return jsValue
    }

    // ========================================================================
    // deinit - 析构
    // 严格翻译自: ImmediateObject.deinit
    // ========================================================================

    /// 析构 - 对应 Bun deinit
    func deinit(): Unit {
        internals.deinit()
    }

    // ========================================================================
    // constructor - JS 构造器 (不可构造)
    // 严格翻译自: ImmediateObject.constructor
    //   pub fn constructor(globalObject: *jsc.JSGlobalObject, callFrame: *jsc.CallFrame) !*Self {
    //       return globalObject.throw("Immediate is not constructible", .{});
    //   }
    // ========================================================================

    /// JS 构造器 - 对应 Bun constructor
    /// Immediate 不可被构造
    public func constructor(globalObject: JSGlobalObject, callFrame: CallFrame): ?ImmediateObject {
        globalObject.throwError("Immediate is not constructible")
        return None
    }

    // ========================================================================
    // runImmediateTask - 运行 Immediate 任务
    // 严格翻译自: ImmediateObject.runImmediateTask
    //   委托给 internals.runImmediateTask
    //   返回 true 如果抛出了异常
    // ========================================================================

    /// 运行 Immediate 任务 - 对应 Bun runImmediateTask
    /// 返回 true 如果抛出了异常
    public func runImmediateTask(vm: VirtualMachine): Bool {
        internals.runImmediateTask(vm)
    }

    // ========================================================================
    // toPrimitive - 转为原始值
    // 严格翻译自: ImmediateObject.toPrimitive
    // ========================================================================

    /// 转为原始值 - 对应 Bun toPrimitive
    public func toPrimitive(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        internals.toPrimitive()
    }

    // ========================================================================
    // doRef / doUnref / hasRef
    // 严格翻译自: ImmediateObject.doRef / doUnref / hasRef
    // ========================================================================

    /// ref 操作 - 对应 Bun doRef
    public func doRef(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        internals.doRef(globalThis, callFrame.this_())
    }

    /// unref 操作 - 对应 Bun doUnref
    public func doUnref(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        internals.doUnref(globalThis, callFrame.this_())
    }

    /// hasRef 操作 - 对应 Bun hasRef
    public func hasRef(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        internals.hasRef()
    }

    // ========================================================================
    // finalize / getDestroyed / dispose
    // 严格翻译自: ImmediateObject.finalize / getDestroyed / dispose
    // ========================================================================

    /// GC 终结 - 对应 Bun finalize
    public func finalize(): Unit {
        internals.finalize()
    }

    /// 获取 _destroyed 属性 - 对应 Bun getDestroyed
    public func getDestroyed(globalThis: JSGlobalObject): JSValue {
        JSValue.jsBoolean(internals.getDestroyed())
    }

    /// 释放 - 对应 Bun dispose
    public func dispose(globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
        internals.cancel(globalThis.bunVM())
        JSValue.jsUndefined()
    }

    // ========================================================================
    // toJS / fromJS - JS 绑定
    // 对应 Bun Codegen.JSImmediate.toJS / fromJS / fromJSDirect
    // ========================================================================

    /// 转为 JS 值 - 对应 Bun js.toJS
    public func toJS(globalThis: JSGlobalObject): JSValue {
        JSValue(this)
    }

    /// 从 JS 值获取 - 对应 Bun js.fromJS
    public static func fromJS(value: JSValue): ?ImmediateObject {
        // 尝试从 JS 值提取 ImmediateObject 指针
        if (value.isObject()) {
            return value.getNativeObject() as ImmediateObject
        }
        return None
    }

    /// 从 JS 值直接获取 - 对应 Bun js.fromJSDirect
    public static func fromJSDirect(value: JSValue): ?ImmediateObject {
        fromJS(value)
    }

    // ========================================================================
    // JS 缓存属性访问 - 对应 Bun Codegen.JSImmediate
    //   js.callbackGetCached / callbackSetCached
    //   js.argumentsGetCached / argumentsSetCached
    // ========================================================================

    /// 获取缓存的回调 - 对应 Bun js.callbackGetCached
    public static func jsCallbackGetCached(thisValue: JSValue): JSValue {
        thisValue.getCachedProperty("callback")
    }

    /// 设置缓存的回调 - 对应 Bun js.callbackSetCached
    public static func jsCallbackSetCached(thisValue: JSValue, global: JSGlobalObject, value: JSValue): Unit {
        thisValue.setCachedProperty("callback", value)
    }

    /// 获取缓存的参数 - 对应 Bun js.argumentsGetCached
    public static func jsArgumentsGetCached(thisValue: JSValue): JSValue {
        thisValue.getCachedProperty("arguments")
    }

    /// 设置缓存的参数 - 对应 Bun js.argumentsSetCached
    public static func jsArgumentsSetCached(thisValue: JSValue, global: JSGlobalObject, value: JSValue): Unit {
        thisValue.setCachedProperty("arguments", value)
    }
}

/// JSValue 扩展 - 对象类型检查
public func isObject(): Bool {
    false
}

/// 获取原生对象
public func getNativeObject(): Any {
    Object()
}
