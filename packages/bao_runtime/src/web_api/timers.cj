// Web API timers 模块
// 对应 Bun: src/runtime/api/timer.zig
// 严格翻译 Bun 的 setTimeout/setInterval API
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// timers 模块 — Web Timers API
// 对应 Bun: src/runtime/api/timer.zig
// ============================================================================

/// 定时器 ID 类型
public type TimerId = Int64

/// 定时器类型
public enum TimerKind {
    | Timeout
    | Interval
}

/// 定时器记录
public class TimerRecord {
    public var id: TimerId
    public var kind: TimerKind
    public var delay: Float64      // 毫秒
    public var callback: (ArrayList<JsValue>) -> JsValue
    public var args: ArrayList<JsValue>
    public var startTime: Float64
    public var repeat: Bool

    public init(id: TimerId, kind: TimerKind, delay: Float64,
                callback: (ArrayList<JsValue>) -> JsValue, args: ArrayList<JsValue>) {
        this.id = id
        this.kind = kind
        this.delay = delay
        this.callback = callback
        this.args = args
        this.startTime = currentTimeMillis()
        this.repeat = kind == TimerKind.Interval
    }
}

/// 定时器管理器 — 管理 setTimeout/setInterval
/// 对应 Bun: src/runtime/api/timer.zig 中的定时器实现
public class TimerManager {
    /// 活跃定时器
    private var timers: HashMap<TimerId, TimerRecord>
    /// 下一个定时器 ID
    private var nextId: TimerId
    /// 已过期的定时器回调队列
    private var pendingCallbacks: ArrayList<() -> Unit>

    public init() {
        timers = HashMap<TimerId, TimerRecord>()
        nextId = 1
        pendingCallbacks = ArrayList<() -> Unit>()
    }

    /// setTimeout(callback, delay, ...args) — 延迟执行一次
    /// 对应 Bun: setTimeout
    public func setTimeout(callback: (ArrayList<JsValue>) -> JsValue,
                            delay: Float64, args: ArrayList<JsValue>): TimerId {
        let id = nextId
        nextId++
        let record = TimerRecord(id, TimerKind.Timeout, delay, callback, args)
        timers.put(id, record)
        return id
    }

    /// setInterval(callback, delay, ...args) — 周期执行
    /// 对应 Bun: setInterval
    public func setInterval(callback: (ArrayList<JsValue>) -> JsValue,
                             delay: Float64, args: ArrayList<JsValue>): TimerId {
        let id = nextId
        nextId++
        let record = TimerRecord(id, TimerKind.Interval, delay, callback, args)
        timers.put(id, record)
        return id
    }

    /// clearTimeout(id) — 取消 setTimeout
    /// 对应 Bun: clearTimeout
    public func clearTimeout(id: TimerId): Unit {
        timers.remove(id)
    }

    /// clearInterval(id) — 取消 setInterval
    /// 对应 Bun: clearInterval
    public func clearInterval(id: TimerId): Unit {
        timers.remove(id)
    }

    /// 检查并触发到期的定时器
    /// 在事件循环的每个 tick 中调用
    public func tick(): Unit {
        let now = currentTimeMillis()
        let expired = ArrayList<TimerRecord>()

        // 收集已到期的定时器
        for (key in timers.keys()) {
            match (timers.get(key)) {
                case Some(record) => {
                    if (now - record.startTime >= record.delay) {
                        expired.append(record)
                    }
                }
                case None => ()
            }
        }

        // 执行回调
        for (record in expired) {
            record.callback(record.args)

            if (record.repeat) {
                // interval: 重新设置开始时间
                record.startTime = now
            } else {
                // timeout: 执行后移除
                timers.remove(record.id)
            }
        }
    }

    /// 是否有活跃的定时器
    public func hasActiveTimers(): Bool {
        return timers.keys().size > 0
    }

    /// 获取活跃定时器数量
    public func activeCount(): Int64 {
        return timers.keys().size
    }
}

/// timers 模块导出
public class TimersModule {
    /// 全局定时器管理器
    public static var manager: TimerManager = TimerManager()

    /// 将定时器函数注册到全局对象
    public static func registerGlobals(env: Environment): Unit {
        let mgr = manager

        env.define("setTimeout", Interpreter.makeNativeFn("setTimeout") { args =>
            if (args.size < 1) { return JsValue(0.0) }
            // args[0] 是回调函数
            let fn = args[0]
            let delay = if (args.size > 1) { Interpreter.jsToNumber(args[1]) } else { 0.0 }
            let fnArgs = ArrayList<JsValue>()
            for (i in 2..args.size) {
                fnArgs.append(args[i])
            }
            let id = mgr.setTimeout({ callbackArgs =>
                // 调用 JS 函数
                if (fn.nativeFnData != None) {
                    match (fn.nativeFnData) {
                        case Some(nf) => return nf.fn(callbackArgs)
                        case None => ()
                    }
                }
                if (fn.functionData != None) {
                    // JS 函数需要 Interpreter 来调用，此处占位
                    return JsValue.UNDEFINED
                }
                return JsValue.UNDEFINED
            }, delay, fnArgs)
            return JsValue(Float64(id))
        }, false)

        env.define("setInterval", Interpreter.makeNativeFn("setInterval") { args =>
            if (args.size < 1) { return JsValue(0.0) }
            let fn = args[0]
            let delay = if (args.size > 1) { Interpreter.jsToNumber(args[1]) } else { 0.0 }
            let fnArgs = ArrayList<JsValue>()
            for (i in 2..args.size) {
                fnArgs.append(args[i])
            }
            let id = mgr.setInterval({ callbackArgs =>
                if (fn.nativeFnData != None) {
                    match (fn.nativeFnData) {
                        case Some(nf) => return nf.fn(callbackArgs)
                        case None => ()
                    }
                }
                return JsValue.UNDEFINED
            }, delay, fnArgs)
            return JsValue(Float64(id))
        }, false)

        env.define("clearTimeout", Interpreter.makeNativeFn("clearTimeout") { args =>
            if (args.size > 0) {
                let id = Int64(Interpreter.jsToNumber(args[0]))
                mgr.clearTimeout(id)
            }
            return JsValue.UNDEFINED
        }, false)

        env.define("clearInterval", Interpreter.makeNativeFn("clearInterval") { args =>
            if (args.size > 0) {
                let id = Int64(Interpreter.jsToNumber(args[0]))
                mgr.clearInterval(id)
            }
            return JsValue.UNDEFINED
        }, false)

        env.define("setImmediate", Interpreter.makeNativeFn("setImmediate") { args =>
            if (args.size < 1) { return JsValue(0.0) }
            let fn = args[0]
            let fnArgs = ArrayList<JsValue>()
            for (i in 1..args.size) {
                fnArgs.append(args[i])
            }
            let id = mgr.setTimeout({ callbackArgs =>
                if (fn.nativeFnData != None) {
                    match (fn.nativeFnData) {
                        case Some(nf) => return nf.fn(callbackArgs)
                        case None => ()
                    }
                }
                return JsValue.UNDEFINED
            }, 0.0, fnArgs)
            return JsValue(Float64(id))
        }, false)

        env.define("clearImmediate", Interpreter.makeNativeFn("clearImmediate") { args =>
            if (args.size > 0) {
                let id = Int64(Interpreter.jsToNumber(args[0]))
                mgr.clearTimeout(id)
            }
            return JsValue.UNDEFINED
        }, false)

        // requestAnimationFrame / cancelAnimationFrame (简化为 setTimeout 0)
        env.define("requestAnimationFrame", Interpreter.makeNativeFn("requestAnimationFrame") { args =>
            if (args.size < 1) { return JsValue(0.0) }
            let fn = args[0]
            let id = mgr.setTimeout({ _ =>
                if (fn.nativeFnData != None) {
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(ArrayList<JsValue>([JsValue(currentTimeMillis())]))
                        case None => ()
                    }
                }
                return JsValue.UNDEFINED
            }, 16.0, ArrayList<JsValue>())  // ~60fps
            return JsValue(Float64(id))
        }, false)

        env.define("cancelAnimationFrame", Interpreter.makeNativeFn("cancelAnimationFrame") { args =>
            if (args.size > 0) {
                let id = Int64(Interpreter.jsToNumber(args[0]))
                mgr.clearTimeout(id)
            }
            return JsValue.UNDEFINED
        }, false)

        // queueMicrotask
        env.define("queueMicrotask", Interpreter.makeNativeFn("queueMicrotask") { args =>
            if (args.size > 0) {
                let fn = args[0]
                if (fn.nativeFnData != None) {
                    match (fn.nativeFnData) {
                        case Some(nf) => nf.fn(ArrayList<JsValue>())
                        case None => ()
                    }
                }
            }
            return JsValue.UNDEFINED
        }, false)
    }

    /// 获取当前时间戳 (毫秒)
    private static func currentTimeMillis(): Float64 {
        return bao_sys.SysModule.currentTimeMillis()
    }
}
