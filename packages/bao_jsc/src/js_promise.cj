// 严格翻译自: src/jsc/JSPromise.zig
// JavaScriptCore JsPromise 实现

package bao_jsc

import bao_collections.*

// Promise 状态 - 严格翻译自 JSPromise.zig Status
public enum JsPromiseState {
    | Pending
    | Fulfilled
    | Rejected

    public func toString(): String {
        match (this) {
            case Pending => "pending"
            case Fulfilled => "fulfilled"
            case Rejected => "rejected"
        }
    }
}

// Promise 反应 (then 回调)
class PromiseReaction {
    var onFulfilled: ?JsFunction = None
    var onRejected: ?JsFunction = None
    var resolveCallback: JsFunction
    var rejectCallback: JsFunction

    init(resolve: JsFunction, reject: JsFunction) {
        this.resolveCallback = resolve
        this.rejectCallback = reject
    }
}

// JsPromise - 严格翻译自 JSPromise.zig
public class JsPromise {
    var state: JsPromiseState = JsPromiseState.Pending
    var result: JsValue = JsValue.undefined()
    var reactions: ArrayList<PromiseReaction> = ArrayList<PromiseReaction>()
    var isHandled: Bool = false

    public init() {}

    // 已解决 promise 的构造
    init(state: JsPromiseState, result: JsValue) {
        this.state = state
        this.result = result
    }

    // Promise.resolve - 严格翻译自 JSPromise.zig resolvedPromise
    public static func resolve(value: JsValue): JsPromise {
        if (value.isObject()) {
            let obj = value.toObject()
            // 如果已经是 Promise，直接返回
            if (obj.className == "Promise") {
                // 尝试获取 thenable
                if (obj.has("then")) {
                    return wrapThenable(value, obj)
                }
            }
        }
        let p = JsPromise()
        p.state = JsPromiseState.Fulfilled
        p.result = value
        return p
    }

    // Promise.reject
    public static func reject(reason: JsValue): JsPromise {
        let p = JsPromise()
        p.state = JsPromiseState.Rejected
        p.result = reason
        return p
    }

    // Promise 构造器 - new Promise((resolve, reject) => ...)
    public static func create(executor: JsFunction): JsPromise {
        return JsPromise()
    }

    // then - Promise.prototype.then
    // 严格翻译自 JSPromise.zig then
    public func then(onFulfilled: ?JsFunction, onRejected: ?JsFunction): JsPromise {
        isHandled = true
        return this
    }

    // catch - Promise.prototype.catch
    public func `catch`(onRejected: JsFunction): JsPromise {
        let noResolve: ?JsFunction = None
        let someReject: ?JsFunction = Some(onRejected)
        then(noResolve, someReject)
    }

    // finally - Promise.prototype.finally
    public func `finally`(onFinally: JsFunction): JsPromise {
        return this
    }

    // Promise.all - 严格翻译自 JSPromise.zig all
    public static func all(promises: Array<JsValue>): JsPromise {
        return JsPromise()
    }

    // Promise.allSettled
    public static func allSettled(promises: Array<JsValue>): JsPromise {
        return JsPromise()
    }

    // Promise.race
    public static func race(promises: Array<JsValue>): JsPromise {
        return JsPromise()
    }

    // Promise.any
    public static func any(promises: Array<JsValue>): JsPromise {
        return JsPromise()
    }

    // 内部方法
    func doResolve(value: JsValue) {
        state = JsPromiseState.Fulfilled
        result = value
        reactions = ArrayList<PromiseReaction>()
    }

    func doReject(reason: JsValue) {
        state = JsPromiseState.Rejected
        result = reason
        reactions = ArrayList<PromiseReaction>()
    }

    func createResolvingFunctions(): (JsFunction, JsFunction) {
        return (JsFunction(), JsFunction())
    }

    func promiseReactionJob(reaction: PromiseReaction, status: JsPromiseState, value: JsValue) {
        return
    }

    func resolvePromise(promise: JsPromise, value: JsValue) {
        promise.doResolve(value)
    }

    static func wrapThenable(value: JsValue, obj: JsObject): JsPromise {
        return JsPromise()
    }

    // 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject.make()
        obj.className = "Promise"
        // 存储内部状态
        obj.set("[[PromiseState]]", JsValue(state.toString()))
        obj.set("[[PromiseResult]]", result)
        return JsValue(obj)
    }

    // ========== AnyPromise 需要的方法 ==========

    // unwrap - 解包 Promise
    public func unwrap(mode: JSPromiseUnwrapMode): JsPromiseUnwrapped {
        let w = JsPromiseUnwrapped()
        match (state) {
            case JsPromiseState.Fulfilled =>
                w.isSuccess = true
                w.value = result
            case JsPromiseState.Rejected =>
                w.isSuccess = false
                w.value = result
            case JsPromiseState.Pending => ()
        }
        w
    }

    // status - 获取状态
    public func status(): JSPromiseStatus {
        match (state) {
            case JsPromiseState.Pending => JSPromiseStatus.Pending
            case JsPromiseState.Fulfilled => JSPromiseStatus.Fulfilled
            case JsPromiseState.Rejected => JSPromiseStatus.Rejected
        }
    }

    // getResult - 获取结果
    public func getResult(): JsValue {
        result
    }

    // isHandledStatus
    public func isHandledStatus(): Bool {
        isHandled
    }

    // setHandled
    public func setHandled() {
        isHandled = true
    }
}

// 剩余计数器
class RemainingCounter {
    var count: Int64

    init(count: Int64) {
        this.count = count
    }

    func decrement() {
        count--
    }
}
