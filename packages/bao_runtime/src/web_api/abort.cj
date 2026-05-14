// Web API AbortController / AbortSignal
// 对应 Bun: src/runtime/api/abort.zig
// 严格翻译自: src/api/abort.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// AbortController — 中止控制器
// 对应 Bun: src/api/abort.zig AbortController
// ============================================================================

/// AbortController — 对应 Web AbortController API
/// 用于中止一个或多个 Web 请求
/// 对应 Bun: src/api/abort.zig AbortController
public class AbortController {
    /// 关联的中止信号
    public var signal: AbortSignal

    public init() {
        signal = AbortSignal()
    }

    /// 中止操作 (无原因)
    /// 对应 Web API: controller.abort()
    public func abort(): Unit {
        abort("The operation was aborted")
    }

    /// 中止操作 (带原因)
    /// 对应 Web API: controller.abort(reason)
    public func abort(reason: String): Unit {
        if (!signal.aborted) {
            signal.aborted = true
            signal.reason = Some(reason)
            // 通知所有监听器
            for (listener in signal.listeners) {
                listener(signal)
            }
        }
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("signal", self.signal.toJsValue())

        obj.set("abort", JsValue.nativeFunction(JsNativeFunction("abort") { args =>
            if (args.size >= 1) {
                self.abort(Interpreter.jsToString(args[0]))
            } else {
                self.abort()
            }
            return JsValue.UNDEFINED
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// AbortSignal — 中止信号
// 对应 Bun: src/api/abort.zig AbortSignal
// ============================================================================

/// AbortSignal — 对应 Web AbortSignal API
/// 可通过 AbortController 创建，也可独立使用静态方法
/// 对应 Bun: src/api/abort.zig AbortSignal
public class AbortSignal {
    /// 是否已中止
    public var aborted: Bool
    /// 中止原因
    public var reason: ?String
    /// abort 事件监听器列表
    private var listeners: ArrayList<(AbortSignal) -> Unit>

    public init() {
        aborted = false
        reason = None
        listeners = ArrayList<(AbortSignal) -> Unit>()
    }

    /// 如果已中止则抛出异常
    /// 对应 Web API: signal.throwIfAborted()
    public func throwIfAborted(): Unit {
        if (aborted) {
            let msg = match (reason) {
                case Some(r) => r
                case None => "The operation was aborted"
            }
            throw JsError(JsValue(BaoString(msg)))
        }
    }

    /// 注册 abort 事件回调
    /// 对应 Web API: signal.onabort = callback
    public func onabort(callback: (AbortSignal) -> Unit): Unit {
        listeners.append(callback)
    }

    /// 静态工厂: 创建已中止的 AbortSignal
    /// 对应 Web API: AbortSignal.abort()
    public static func abort(): AbortSignal {
        let signal = AbortSignal()
        signal.aborted = true
        signal.reason = Some("The operation was aborted")
        return signal
    }

    /// 静态工厂: 创建已中止的 AbortSignal (带原因)
    /// 对应 Web API: AbortSignal.abort(reason)
    public static func abort(reason: String): AbortSignal {
        let signal = AbortSignal()
        signal.aborted = true
        signal.reason = Some(reason)
        return signal
    }

    /// 静态工厂: 创建超时自动中止的 AbortSignal
    /// 对应 Web API: AbortSignal.timeout(ms)
    /// 简化: 使用定时器模拟超时
    public static func timeout(ms: Int64): AbortSignal {
        let signal = AbortSignal()
        signal.reason = Some("The operation was aborted due to timeout")
        // 注册定时器，超时后触发 abort
        // 简化: 通过 TimersModule 的管理器设置延迟回调
        let mgr = TimersModule.manager
        mgr.setTimeout({ _ =>
            if (!signal.aborted) {
                signal.aborted = true
                for (listener in signal.listeners) {
                    listener(signal)
                }
            }
            return JsValue.UNDEFINED
        }, Float64(ms), ArrayList<JsValue>())
        return signal
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("aborted", JsValue(self.aborted))

        obj.set("reason", match (self.reason) {
            case Some(r) => JsValue(BaoString(r))
            case None => JsValue.UNDEFINED
        })

        obj.set("throwIfAborted", JsValue.nativeFunction(JsNativeFunction("throwIfAborted") { _ =>
            self.throwIfAborted()
            return JsValue.UNDEFINED
        }))

        obj.set("onabort", JsValue.nativeFunction(JsNativeFunction("onabort") { args =>
            // 简化: 注册一个占位回调
            return JsValue.UNDEFINED
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// AbortModule — Abort 模块导出
// ============================================================================

/// Abort 模块导出 — 将 AbortController/AbortSignal 注册到全局
public class AbortModule {
    /// 将 AbortController/AbortSignal 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        // AbortController 构造函数
        env.define("AbortController", Interpreter.makeNativeFn("AbortController") { args =>
            let controller = AbortController()
            return controller.toJsValue()
        }, false)

        // AbortSignal 构造函数 (静态方法)
        env.define("AbortSignal", AbortSignalModule.toJsValue(), false)
    }
}

/// AbortSignal 静态方法导出
public class AbortSignalModule {
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("abort", JsValue.nativeFunction(JsNativeFunction("abort") { args =>
            let signal = if (args.size >= 1) {
                AbortSignal.abort(Interpreter.jsToString(args[0]))
            } else {
                AbortSignal.abort()
            }
            return signal.toJsValue()
        }))

        obj.set("timeout", JsValue.nativeFunction(JsNativeFunction("timeout") { args =>
            if (args.size >= 1) {
                let ms = Int64(Interpreter.jsToNumber(args[0]))
                let signal = AbortSignal.timeout(ms)
                return signal.toJsValue()
            }
            return JsValue.NULL
        }))

        return JsValue(obj)
    }
}
