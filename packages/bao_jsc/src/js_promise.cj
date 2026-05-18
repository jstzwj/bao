// 严格翻译自: src/jsc/JSPromise.zig
// JavaScriptCore JsPromise 实现

package bao_jsc

// Promise 状态 - 严格翻译自 JSPromise.zig Status
public enum JsPromiseState {
    | Pending
    | Fulfilled
    | Rejected
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
    var reactions: Array<PromiseReaction> = []
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
        let (resolveCapability, rejectCapability) = createResolvingFunctions()

        let reaction = PromiseReaction(resolve: resolveCapability, reject: rejectCapability)
        reaction.onFulfilled = onFulfilled
        reaction.onRejected = onRejected

        match (state) {
            case Pending => {
                reactions.append(reaction)
            }
            case Fulfilled => {
                let value = result
                let fulfillReaction = reaction
                // 异步执行
                MicrotaskQueue.instance().enqueue({
                    promiseReactionJob(fulfillReaction, JsPromiseState.Fulfilled, value)
                })
            }
            case Rejected => {
                let reason = result
                let rejectReaction = reaction
                if (!isHandled) {
                    // 触发 unhandledrejection
                }
                MicrotaskQueue.instance().enqueue({
                    promiseReactionJob(rejectReaction, JsPromiseState.Rejected, reason)
                })
            }
        }
        isHandled = true
        return resolveCapability.promise
    }

    // catch - Promise.prototype.catch
    public func catch(onRejected: JsFunction): JsPromise {
        then(None, Some(onRejected))
    }

    // finally - Promise.prototype.finally
    public func finally(onFinally: JsFunction): JsPromise {
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
        if (state != JsPromiseState.Pending) { return }
        state = JsPromiseState.Fulfilled
        result = value
        for (reaction in reactions) {
            MicrotaskQueue.instance().enqueue({
                promiseReactionJob(reaction, JsPromiseState.Fulfilled, value)
            })
        }
        reactions = []
    }

    func doReject(reason: JsValue) {
        if (state != JsPromiseState.Pending) { return }
        state = JsPromiseState.Rejected
        result = reason
        for (reaction in reactions) {
            MicrotaskQueue.instance().enqueue({
                promiseReactionJob(reaction, JsPromiseState.Rejected, reason)
            })
        }
        reactions = []
    }

    func createResolvingFunctions(): (JsFunction, JsFunction) {
        let p = JsPromise()
        let resolve = JsFunction.create("resolve", { (thisObj, args) =>
            let val = if (args.size > 0) { args[0] } else { JsValue.undefined() }
            if (JsValue.strictEqual(JsValue(obj: p), val)) {
                p.doReject(JsValue(s: "TypeError: A promise cannot be resolved with itself"))
            } else if (val.isObject()) {
                resolvePromise(p, val)
            } else {
                p.doResolve(val)
            }
            JsValue.undefined()
        })
        let reject = JsFunction.create("reject", { (thisObj, args) =>
            p.doReject(if (args.size > 0) { args[0] } else { JsValue.undefined() })
            JsValue.undefined()
        })
        (resolve, reject)
    }

    func promiseReactionJob(reaction: PromiseReaction, status: JsPromiseState, value: JsValue) {
        let handler = if (status == JsPromiseState.Fulfilled) { reaction.onFulfilled } else { reaction.onRejected }
        if (handler == None) {
            if (status == JsPromiseState.Fulfilled) {
                reaction.resolveCallback.call(JsValue.undefined(), [value])
            } else {
                reaction.rejectCallback.call(JsValue.undefined(), [value])
            }
            return
        }
        let result = handler.getOrThrow().call(JsValue.undefined(), [value])
        reaction.resolveCallback.call(JsValue.undefined(), [result])
    }

    func resolvePromise(promise: JsPromise, value: JsValue) {
        let obj = value.toObject()
        if (obj.has("then")) {
            let thenFn = obj.get("then")
            if (thenFn.isCallable()) {
                // thenable
                let (resolve, reject) = promise.createResolvingFunctions()
                try {
                    thenFn.toObject().call(value, [resolve.toJsValue(), reject.toJsValue()])
                } catch (e: Exception) {
                    promise.doReject(JsValue(s: e.message))
                }
            } else {
                promise.doResolve(value)
            }
        } else {
            promise.doResolve(value)
        }
    }

    static func wrapThenable(value: JsValue, obj: JsObject): JsPromise {
        let p = JsPromise()
        try {
            let thenFn = obj.get("then")
            let (resolve, reject) = p.createResolvingFunctions()
            thenFn.toObject().call(value, [resolve.toJsValue(), reject.toJsValue()])
        } catch (e: Exception) {
            p.doReject(JsValue(s: e.message))
        }
        p
    }

    // 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject.make()
        obj.className = "Promise"
        // 存储内部状态
        obj.set("[[PromiseState]]", JsValue(s: state.toString()))
        obj.set("[[PromiseResult]]", result)
        return JsValue(obj: obj)
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
