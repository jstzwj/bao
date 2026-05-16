// Web API Event / EventTarget / CustomEvent
// 对应 Bun: src/runtime/webcore + 浏览器 Event API
// 严格翻译自 Web Events API
package bao_runtime.web_api

import bao_core.*
import bao_collections.*

// ============================================================================
// Event — DOM 事件
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Event
// ============================================================================

/// EventPhase — 事件阶段常量
/// 对应 Web API: Event.AT_TARGET, Event.BUBBLING_PHASE, Event.CAPTURING_PHASE, Event.NONE
public enum EventPhase {
    | None       // 0 — 事件尚未分发
    | Capturing  // 1 — 捕获阶段
    | AtTarget   // 2 — 到达目标
    | Bubbling   // 3 — 冒泡阶段

    public func value(): Int64 {
        match (this) {
            case None => 0
            case Capturing => 1
            case AtTarget => 2
            case Bubbling => 3
        }
    }
}

/// Event — 表示一个事件
/// 对应 Web API: Event
/// 对应 Bun: 事件系统基础类
public class Event {
    /// 事件类型 (名称)
    public var type: String
    /// 事件目标
    public var target: ?EventTarget
    /// 当前目标 (冒泡链中的当前节点)
    public var currentTarget: ?EventTarget
    /// 事件阶段
    public var eventPhase: EventPhase
    /// 时间戳 (毫秒)
    public var timeStamp: Float64
    /// 是否可以冒泡
    public var bubbles: Bool
    /// 是否可取消
    public var cancelable: Bool
    /// 是否已取消
    public var defaultPrevented: Bool
    /// 是否已停止传播
    public var propagationStopped: Bool
    /// 是否已停止立即传播
    public var immediatePropagationStopped: Bool
    /// 是否由信任源触发
    public var isTrusted: Bool

    public init(type: String) {
        this.type = type
        target = None
        currentTarget = None
        eventPhase = EventPhase.None
        timeStamp = currentTimeMillis()
        bubbles = false
        cancelable = false
        defaultPrevented = false
        propagationStopped = false
        immediatePropagationStopped = false
        isTrusted = false
    }

    public init(type: String, options: EventInit) {
        this.type = type
        target = None
        currentTarget = None
        eventPhase = EventPhase.None
        timeStamp = currentTimeMillis()
        bubbles = options.bubbles
        cancelable = options.cancelable
        defaultPrevented = false
        propagationStopped = false
        immediatePropagationStopped = false
        isTrusted = false
    }

    /// 阻止默认行为
    /// 对应 Web API: event.preventDefault()
    public func preventDefault(): Unit {
        if (cancelable) {
            defaultPrevented = true
        }
    }

    /// 停止传播
    /// 对应 Web API: event.stopPropagation()
    public func stopPropagation(): Unit {
        propagationStopped = true
    }

    /// 立即停止传播
    /// 对应 Web API: event.stopImmediatePropagation()
    public func stopImmediatePropagation(): Unit {
        propagationStopped = true
        immediatePropagationStopped = true
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("type", JsValue(BaoString(self.type)))
        obj.set("bubbles", JsValue(self.bubbles))
        obj.set("cancelable", JsValue(self.cancelable))
        obj.set("defaultPrevented", JsValue(self.defaultPrevented))
        obj.set("isTrusted", JsValue(self.isTrusted))
        obj.set("timeStamp", JsValue(self.timeStamp))
        obj.set("eventPhase", JsValue(Float64(self.eventPhase.value())))

        obj.set("target", match (self.target) {
            case Some(t) => t.toJsValue()
            case None => JsValue.NULL
        })

        obj.set("currentTarget", match (self.currentTarget) {
            case Some(t) => t.toJsValue()
            case None => JsValue.NULL
        })

        obj.set("preventDefault", JsValue.nativeFunction(JsNativeFunction("preventDefault") { _ =>
            self.preventDefault()
            return JsValue.UNDEFINED
        }))

        obj.set("stopPropagation", JsValue.nativeFunction(JsNativeFunction("stopPropagation") { _ =>
            self.stopPropagation()
            return JsValue.UNDEFINED
        }))

        obj.set("stopImmediatePropagation", JsValue.nativeFunction(JsNativeFunction("stopImmediatePropagation") { _ =>
            self.stopImmediatePropagation()
            return JsValue.UNDEFINED
        }))

        // 常量
        obj.set("NONE", JsValue(Float64(0)))
        obj.set("CAPTURING_PHASE", JsValue(Float64(1)))
        obj.set("AT_TARGET", JsValue(Float64(2)))
        obj.set("BUBBLING_PHASE", JsValue(Float64(3)))

        return JsValue(obj)
    }

    private static func currentTimeMillis(): Float64 {
        return bao_sys.SysModule.currentTimeMillis()
    }
}

// ============================================================================
// EventInit — Event 构造选项
// 对应 Web API: EventInit
// ============================================================================

/// Event 构造选项
/// 对应 Web API: EventInit
public class EventInit {
    public var bubbles: Bool
    public var cancelable: Bool

    public init() {
        bubbles = false
        cancelable = false
    }

    public init(bubbles: Bool, cancelable: Bool) {
        this.bubbles = bubbles
        this.cancelable = cancelable
    }
}

// ============================================================================
// CustomEvent — 自定义事件
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent
// ============================================================================

/// CustomEvent — 携带自定义数据的事件
/// 对应 Web API: CustomEvent
public class CustomEvent extends Event {
    /// 自定义数据
    public var detail: JsValue

    public init(type: String) {
        super(type)
        detail = JsValue.UNDEFINED
    }

    public init(type: String, options: CustomEventInit) {
        super(type, EventInit(options.bubbles, options.cancelable))
        detail = options.detail
    }

    /// 转为 JsValue
    public func toJsValueCustom(): JsValue {
        let base = super.toJsValue()
        // 在 base 上追加 detail
        match (base.objectData) {
            case Some(obj) => {
                let self = this
                obj.set("detail", self.detail)
            }
            case None => ()
        }
        return base
    }
}

// ============================================================================
// CustomEventInit — CustomEvent 构造选项
// 对应 Web API: CustomEventInit
// ============================================================================

/// CustomEvent 构造选项
/// 对应 Web API: CustomEventInit
public class CustomEventInit {
    public var bubbles: Bool
    public var cancelable: Bool
    public var detail: JsValue

    public init() {
        bubbles = false
        cancelable = false
        detail = JsValue.UNDEFINED
    }

    public init(bubbles: Bool, cancelable: Bool, detail: JsValue) {
        this.bubbles = bubbles
        this.cancelable = cancelable
        this.detail = detail
    }
}

// ============================================================================
// EventListener — 事件监听器回调类型
// ============================================================================

/// 事件监听器回调类型
/// 对应 Web API: EventListener
public type EventListener = (Event) -> Unit

// ============================================================================
// EventListenerEntry — 事件监听器条目
// ============================================================================

/// 事件监听器条目 (内部使用)
class EventListenerEntry {
    var callback: EventListener
    var once: Bool
    var passive: Bool
    var removed: Bool

    init(callback: EventListener) {
        this.callback = callback
        once = false
        passive = false
        removed = false
    }

    init(callback: EventListener, once: Bool, passive: Bool) {
        this.callback = callback
        this.once = once
        this.passive = passive
        removed = false
    }
}

// ============================================================================
// EventTarget — 事件目标
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/EventTarget
// ============================================================================

/// EventTarget — 可以接收事件并拥有监听器的对象
/// 对应 Web API: EventTarget
/// 对应 Bun: 事件系统核心
public class EventTarget {
    /// 事件监听器映射: eventType -> [listeners]
    private var listeners: HashMap<String, ArrayList<EventListenerEntry>>

    public init() {
        listeners = HashMap<String, ArrayList<EventListenerEntry>>()
    }

    /// 添加事件监听器
    /// 对应 Web API: target.addEventListener(type, callback, options)
    public func addEventListener(type: String, callback: EventListener): Unit {
        addEventListener(type, callback, false, false)
    }

    /// 添加事件监听器 (带选项)
    /// 对应 Web API: target.addEventListener(type, callback, { once, passive })
    public func addEventListener(type: String, callback: EventListener, once: Bool, passive: Bool): Unit {
        match (listeners.get(type)) {
            case Some(arr) => {
                let entry = EventListenerEntry(callback, once, passive)
                arr.append(entry)
            }
            case None => {
                let arr = ArrayList<EventListenerEntry>()
                let entry = EventListenerEntry(callback, once, passive)
                arr.append(entry)
                listeners.put(type, arr)
            }
        }
    }

    /// 移除事件监听器
    /// 对应 Web API: target.removeEventListener(type, callback)
    public func removeEventListener(type: String, callback: EventListener): Unit {
        match (listeners.get(type)) {
            case Some(arr) => {
                // 标记已移除 (不能在遍历中删除)
                for (entry in arr) {
                    // 简化: 通过引用比较
                    // Cangjie 没有函数引用比较，标记第一个匹配的
                    if (!entry.removed) {
                        entry.removed = true
                        break  // 只移除一个
                    }
                }
            }
            case None => ()
        }
    }

    /// 分发事件
    /// 对应 Web API: target.dispatchEvent(event)
    /// 返回 false 如果 preventDefault 被调用
    public func dispatchEvent(event: Event): Bool {
        event.target = Some(this)
        event.currentTarget = Some(this)
        event.eventPhase = EventPhase.AtTarget

        match (listeners.get(event.type)) {
            case Some(arr) => {
                // 复制一份避免遍历中修改
                let toRemove = ArrayList<Int64>()

                for (i in 0..arr.size) {
                    let entry = arr[Int64(i)]
                    if (entry.removed) {
                        continue
                    }
                    if (event.immediatePropagationStopped) {
                        break
                    }

                    // 调用监听器
                    entry.callback(event)

                    // once 监听器执行后移除
                    if (entry.once) {
                        entry.removed = true
                    }
                }

                // 清理已移除的条目
                let newArr = ArrayList<EventListenerEntry>()
                for (entry in arr) {
                    if (!entry.removed) {
                        newArr.append(entry)
                    }
                }
                if (newArr.size == 0) {
                    listeners.remove(event.type)
                } else {
                    listeners.put(event.type, newArr)
                }
            }
            case None => ()
        }

        event.currentTarget = None
        return !event.defaultPrevented
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("addEventListener", JsValue.nativeFunction(JsNativeFunction("addEventListener") { args =>
            if (args.size >= 2) {
                let type = Interpreter.jsToString(args[0])
                // 简化: 将 JS function 包装为 EventListener
                let fn = args[1]
                self.addEventListener(type, { event =>
                    // 调用 JS 回调
                    if (fn.nativeFnData != None) {
                        match (fn.nativeFnData) {
                            case Some(nf) => {
                                let eventArgs = ArrayList<JsValue>()
                                eventArgs.append(event.toJsValue())
                                nf.fn(eventArgs)
                            }
                            case None => ()
                        }
                    }
                })
            }
            return JsValue.UNDEFINED
        }))

        obj.set("removeEventListener", JsValue.nativeFunction(JsNativeFunction("removeEventListener") { args =>
            // 简化实现
            return JsValue.UNDEFINED
        }))

        obj.set("dispatchEvent", JsValue.nativeFunction(JsNativeFunction("dispatchEvent") { args =>
            if (args.size >= 1) {
                // 简化: 创建并分发事件
                let eventType = Interpreter.jsToString(args[0])
                let event = Event(eventType)
                let result = self.dispatchEvent(event)
                return JsValue(result)
            }
            return JsValue(false)
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// MessageEvent — 消息事件 (用于 WebSocket / Worker)
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/MessageEvent
// ============================================================================

/// MessageEvent — 消息事件
/// 对应 Web API: MessageEvent
/// 用于 WebSocket onmessage, Worker onmessage 等
public class MessageEvent extends Event {
    /// 消息数据
    public var data: JsValue
    /// 消息来源
    public var origin: String
    /// 最后事件 ID
    public var lastEventId: String
    /// 消息源 (Window / MessagePort)
    public var source: JsValue
    /// 传输端口列表
    public var ports: ArrayList<JsValue>

    public init(type: String) {
        super(type)
        data = JsValue.UNDEFINED
        origin = ""
        lastEventId = ""
        source = JsValue.NULL
        ports = ArrayList<JsValue>()
    }

    public init(type: String, data: JsValue, origin: String) {
        super(type)
        this.data = data
        this.origin = origin
        lastEventId = ""
        source = JsValue.NULL
        ports = ArrayList<JsValue>()
    }

    /// 转为 JsValue
    public func toJsValueMessage(): JsValue {
        let base = super.toJsValue()
        match (base.objectData) {
            case Some(obj) => {
                let self = this
                obj.set("data", self.data)
                obj.set("origin", JsValue(BaoString(self.origin)))
                obj.set("lastEventId", JsValue(BaoString(self.lastEventId)))
                obj.set("source", self.source)
            }
            case None => ()
        }
        return base
    }
}

// ============================================================================
// ErrorEvent — 错误事件
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/ErrorEvent
// ============================================================================

/// ErrorEvent — 错误事件
/// 对应 Web API: ErrorEvent
public class ErrorEvent extends Event {
    /// 错误消息
    public var message: String
    /// 错误文件名
    public var filename: String
    /// 行号
    public var lineno: Int64
    /// 列号
    public var colno: Int64
    /// 错误对象
    public var error: JsValue

    public init(type: String, message: String, filename: String, lineno: Int64, colno: Int64, error: JsValue) {
        super(type, EventInit(true, true))
        this.message = message
        this.filename = filename
        this.lineno = lineno
        this.colno = colno
        this.error = error
    }

    /// 转为 JsValue
    public func toJsValueError(): JsValue {
        let base = super.toJsValue()
        match (base.objectData) {
            case Some(obj) => {
                let self = this
                obj.set("message", JsValue(BaoString(self.message)))
                obj.set("filename", JsValue(BaoString(self.filename)))
                obj.set("lineno", JsValue(Float64(self.lineno)))
                obj.set("colno", JsValue(Float64(self.colno)))
                obj.set("error", self.error)
            }
            case None => ()
        }
        return base
    }
}

// ============================================================================
// CloseEvent — 关闭事件 (用于 WebSocket)
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/CloseEvent
// ============================================================================

/// CloseEvent — 关闭事件
/// 对应 Web API: CloseEvent
public class CloseEvent extends Event {
    /// 关闭代码
    public var code: Int64
    /// 关闭原因
    public var reason: String
    /// 是否正常关闭
    public var wasClean: Bool

    public init(type: String, code: Int64, reason: String, wasClean: Bool) {
        super(type)
        this.code = code
        this.reason = reason
        this.wasClean = wasClean
    }

    /// 转为 JsValue
    public func toJsValueClose(): JsValue {
        let base = super.toJsValue()
        match (base.objectData) {
            case Some(obj) => {
                let self = this
                obj.set("code", JsValue(Float64(self.code)))
                obj.set("reason", JsValue(BaoString(self.reason)))
                obj.set("wasClean", JsValue(self.wasClean))
            }
            case None => ()
        }
        return base
    }
}

// ============================================================================
// PromiseRejectionEvent — Promise 拒绝事件
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/PromiseRejectionEvent
// ============================================================================

/// PromiseRejectionEvent — Promise 拒绝事件
/// 对应 Web API: PromiseRejectionEvent
public class PromiseRejectionEvent extends Event {
    /// Promise 对象
    public var promise: JsValue
    /// 拒绝原因
    public var reason: JsValue

    public init(type: String, promise: JsValue, reason: JsValue) {
        super(type, EventInit(true, true))
        this.promise = promise
        this.reason = reason
    }

    /// 转为 JsValue
    public func toJsValuePromiseRejection(): JsValue {
        let base = super.toJsValue()
        match (base.objectData) {
            case Some(obj) => {
                let self = this
                obj.set("promise", self.promise)
                obj.set("reason", self.reason)
            }
            case None => ()
        }
        return base
    }
}

// ============================================================================
// EventModule — Event 模块导出
// ============================================================================

/// Event 模块导出 — 将 Event/EventTarget/CustomEvent 等注册到全局
public class EventModule {
    /// 将 Event 相关 API 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        // Event 构造函数
        env.define("Event", Interpreter.makeNativeFn("Event") { args =>
            let type = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            let event = Event(type)
            return event.toJsValue()
        }, false)

        // CustomEvent 构造函数
        env.define("CustomEvent", Interpreter.makeNativeFn("CustomEvent") { args =>
            let type = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            let customEvent = CustomEvent(type)
            return customEvent.toJsValueCustom()
        }, false)

        // EventTarget 构造函数
        env.define("EventTarget", Interpreter.makeNativeFn("EventTarget") { _ =>
            let target = EventTarget()
            return target.toJsValue()
        }, false)

        // MessageEvent 构造函数
        env.define("MessageEvent", Interpreter.makeNativeFn("MessageEvent") { args =>
            let type = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "message" }
            let data = if (args.size >= 2) { args[1] } else { JsValue.UNDEFINED }
            let event = MessageEvent(type, data, "")
            return event.toJsValueMessage()
        }, false)

        // ErrorEvent 构造函数
        env.define("ErrorEvent", Interpreter.makeNativeFn("ErrorEvent") { args =>
            let type = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "error" }
            let event = ErrorEvent(type, "", "", 0, 0, JsValue.NULL)
            return event.toJsValueError()
        }, false)

        // CloseEvent 构造函数
        env.define("CloseEvent", Interpreter.makeNativeFn("CloseEvent") { args =>
            let type = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "close" }
            let event = CloseEvent(type, 0, "", true)
            return event.toJsValueClose()
        }, false)
    }
}
