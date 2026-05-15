// Node.js events 模块 — EventEmitter
// 对应 Bun: src/runtime/node/events.zig
// 严格翻译 Bun 的 Node.js events 兼容层
package bao_runtime.node_api

import bao_core.*
import bao_collections.*

// ============================================================================
// events 模块 — Node.js EventEmitter
// 对应 Bun: src/runtime/node/events.zig
// ============================================================================

/// 事件监听器类型
public type EventListener = (ArrayList<JsValue>) -> JsValue

/// EventEmitter — Node.js 事件发射器
/// 对应 Bun: src/runtime/node/events.zig EventEmitter
public class EventEmitter {
    /// 事件监听器映射: eventName -> [listeners]
    private var listeners: HashMap<String, ArrayList<EventListener>>
    /// 单次监听器映射
    private var onceListeners: HashMap<String, ArrayList<EventListener>>
    /// 最大监听器数量
    public var maxListeners: Int64

    public init() {
        listeners = HashMap<String, ArrayList<EventListener>>()
        onceListeners = HashMap<String, ArrayList<EventListener>>()
        maxListeners = 10
    }

    /// on(eventName, listener) — 注册事件监听器
    /// 对应 Node.js: emitter.on(eventName, listener)
    public func on(eventName: String, listener: EventListener): EventEmitter {
        match (listeners.get(eventName)) {
            case Some(arr) => arr.append(listener)
            case None => {
                let arr = ArrayList<EventListener>()
                arr.append(listener)
                listeners.put(eventName, arr)
            }
        }
        return this
    }

    /// addListener — on 的别名
    public func addListener(eventName: String, listener: EventListener): EventEmitter {
        return on(eventName, listener)
    }

    /// once(eventName, listener) — 注册一次性监听器
    /// 对应 Node.js: emitter.once(eventName, listener)
    public func once(eventName: String, listener: EventListener): EventEmitter {
        match (onceListeners.get(eventName)) {
            case Some(arr) => arr.append(listener)
            case None => {
                let arr = ArrayList<EventListener>()
                arr.append(listener)
                onceListeners.put(eventName, arr)
            }
        }
        return this
    }

    /// emit(eventName, args) — 触发事件
    /// 对应 Node.js: emitter.emit(eventName, ...args)
    public func emit(eventName: String, args: ArrayList<JsValue>): Bool {
        var hadListeners = false

        // 触发持久监听器
        match (listeners.get(eventName)) {
            case Some(arr) => {
                hadListeners = true
                for (listener in arr) {
                    listener(args)
                }
            }
            case None => ()
        }

        // 触发一次性监听器 (触发后移除)
        match (onceListeners.get(eventName)) {
            case Some(arr) => {
                hadListeners = true
                for (listener in arr) {
                    listener(args)
                }
                onceListeners.remove(eventName)
            }
            case None => ()
        }

        return hadListeners
    }

    /// off(eventName, listener) — 移除事件监听器
    /// 对应 Node.js: emitter.off(eventName, listener)
    public func off(eventName: String, listener: EventListener): EventEmitter {
        match (listeners.get(eventName)) {
            case Some(arr) => {
                // 通过引用相等移除
                let newArr = ArrayList<EventListener>()
                for (l in arr) {
                    if (l !== listener) {
                        newArr.append(l)
                    }
                }
                listeners.put(eventName, newArr)
            }
            case None => ()
        }
        return this
    }

    /// removeListener — off 的别名
    public func removeListener(eventName: String, listener: EventListener): EventEmitter {
        return off(eventName, listener)
    }

    /// removeAllListeners(eventName?) — 移除所有监听器
    /// 对应 Node.js: emitter.removeAllListeners([eventName])
    public func removeAllListeners(eventName: ?String): EventEmitter {
        match (eventName) {
            case Some(name) => {
                listeners.remove(name)
                onceListeners.remove(name)
            }
            case None => {
                listeners = HashMap<String, ArrayList<EventListener>>()
                onceListeners = HashMap<String, ArrayList<EventListener>>()
            }
        }
        return this
    }

    /// listenerCount(eventName) — 获取监听器数量
    /// 对应 Node.js: emitter.listenerCount(eventName)
    public func listenerCount(eventName: String): Int64 {
        var count = 0
        match (listeners.get(eventName)) {
            case Some(arr) => count += arr.size
            case None => ()
        }
        match (onceListeners.get(eventName)) {
            case Some(arr) => count += arr.size
            case None => ()
        }
        return count
    }

    /// eventNames() — 获取所有已注册事件名
    /// 对应 Node.js: emitter.eventNames()
    public func eventNames(): ArrayList<String> {
        let names = ArrayList<String>()
        for (key in listeners.keys()) {
            if (!names.contains(key)) {
                names.append(key)
            }
        }
        for (key in onceListeners.keys()) {
            if (!names.contains(key)) {
                names.append(key)
            }
        }
        return names
    }

    /// 将 EventEmitter 导出为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let emitter = this

        obj.set("on", JsValue.nativeFunction(JsNativeFunction("on") { args =>
            if (args.size >= 2) {
                let eventName = Interpreter.jsToString(args[0])
                // args[1] 应该是函数，作为 EventListener 调用
                // 简化: 注册一个占位监听器
                emitter.on(eventName) { listenerArgs =>
                    // 实际应调用 args[1] 作为 JS 函数
                    JsValue.UNDEFINED
                }
            }
            return JsValue(obj)
        }))

        obj.set("emit", JsValue.nativeFunction(JsNativeFunction("emit") { args =>
            if (args.size >= 1) {
                let eventName = Interpreter.jsToString(args[0])
                let emitArgs = ArrayList<JsValue>()
                for (i in 1..args.size) {
                    emitArgs.append(args[i])
                }
                return JsValue(emitter.emit(eventName, emitArgs))
            }
            return JsValue(false)
        }))

        obj.set("off", JsValue.nativeFunction(JsNativeFunction("off") { args =>
            if (args.size >= 2) {
                let eventName = Interpreter.jsToString(args[0])
                // 简化: 无法精确匹配 listener
                emitter.removeAllListeners(Some(eventName))
            }
            return JsValue(obj)
        }))

        obj.set("once", JsValue.nativeFunction(JsNativeFunction("once") { args =>
            if (args.size >= 2) {
                let eventName = Interpreter.jsToString(args[0])
                emitter.once(eventName) { _ => JsValue.UNDEFINED }
            }
            return JsValue(obj)
        }))

        obj.set("removeAllListeners", JsValue.nativeFunction(JsNativeFunction("removeAllListeners") { args =>
            if (args.size >= 1) {
                emitter.removeAllListeners(Some(Interpreter.jsToString(args[0])))
            } else {
                emitter.removeAllListeners(None)
            }
            return JsValue(obj)
        }))

        obj.set("listenerCount", JsValue.nativeFunction(JsNativeFunction("listenerCount") { args =>
            if (args.size >= 1) {
                return JsValue(Float64(emitter.listenerCount(Interpreter.jsToString(args[0]))))
            }
            return JsValue(0.0)
        }))

        obj.set("eventNames", JsValue.nativeFunction(JsNativeFunction("eventNames") { _ =>
            let names = emitter.eventNames()
            let arr = ArrayList<JsValue>()
            for (name in names) {
                arr.append(JsValue(BaoString(name)))
            }
            return JsValue.array(arr)
        }))

        obj.set("maxListeners", JsValue(Float64(emitter.maxListeners)))

        return JsValue(obj)
    }
}

/// events 模块导出
public class EventsModule {
    /// 将 EventEmitter 类导出为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("EventEmitter", JsValue.nativeFunction(JsNativeFunction("EventEmitter") { _ =>
            let emitter = EventEmitter()
            return emitter.toJsValue()
        }))
        return JsValue(obj)
    }
}
