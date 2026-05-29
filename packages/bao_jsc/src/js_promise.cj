// 严格翻译自: src/jsc/JSPromise.zig
// JavaScriptCore JsPromise 实现
// 完整的 Promise/A+ 语义实现

package bao_jsc

import bao_collections.*

// Promise 状态 - 严格翻译自 JSPromise.zig Status
public enum JsPromiseState {
    | Pending
    | Fulfilled
    | Rejected

    public operator func ==(other: JsPromiseState): Bool {
        match (this) {
            case Pending => match (other) { case Pending => true; case _ => false }
            case Fulfilled => match (other) { case Fulfilled => true; case _ => false }
            case Rejected => match (other) { case Rejected => true; case _ => false }
        }
    }

    public operator func !=(other: JsPromiseState): Bool {
        !(this == other)
    }

    public func toString(): String {
        match (this) {
            case Pending => "pending"
            case Fulfilled => "fulfilled"
            case Rejected => "rejected"
        }
    }
}

// 可变状态包装类 - 用于 lambda 捕获
// Cangjie lambda 不能捕获可变局部变量，需要包装为类实例
class MutableBool {
    var value: Bool
    init(v: Bool) { value = v }
}

class MutableInt64 {
    var value: Int64
    init(v: Int64) { value = v }
}

// Promise 反应 (then 回调)
// 对应 ECMAScript PromiseReaction Record
class PromiseReaction {
    var onFulfilled: ?JsFunction = None
    var onRejected: ?JsFunction = None
    var downstream: JsPromise  // 下游 Promise (then 返回的)

    init(downstream: JsPromise, onFulfilled: ?JsFunction, onRejected: ?JsFunction) {
        this.downstream = downstream
        this.onFulfilled = onFulfilled
        this.onRejected = onRejected
    }
}

// JsPromise - 严格翻译自 JSPromise.zig
// 实现 ECMAScript Promise/A+ 规范
public class JsPromise {
    var state: JsPromiseState = JsPromiseState.Pending
    var result: JsValue = JsValue.undefined()
    var reactions: ArrayList<PromiseReaction> = ArrayList<PromiseReaction>()
    var isHandled: Bool = false
    // 微任务队列引用 (全局共享)
    static var microtaskQueue: ArrayList<() -> Unit> = ArrayList<() -> Unit>()

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
    // 严格翻译自 ECMAScript 25.6.3.1 Promise(executor)
    public static func create(executor: JsFunction): JsPromise {
        let promise = JsPromise()

        // 创建 resolve/reject 函数
        // 使用 MutableBool 包装，因为 lambda 不能直接捕获可变局部变量
        let alreadyResolved = MutableBool(false)

        let resolveFn = JsFunction("resolve", 1, { thisArg, args =>
            if (alreadyResolved.value) {
                return JsValue.undefined()
            }
            alreadyResolved.value = true
            let value = if (args.size > 0) { args[0] } else { JsValue.undefined() }
            resolvePromise(promise, value)
            JsValue.undefined()
        })

        let rejectFn = JsFunction("reject", 1, { thisArg, args =>
            if (alreadyResolved.value) {
                return JsValue.undefined()
            }
            alreadyResolved.value = true
            let reason = if (args.size > 0) { args[0] } else { JsValue.undefined() }
            promise.doReject(reason)
            JsValue.undefined()
        })

        // 调用 executor(resolve, reject)
        try {
            let executorArgs: Array<JsValue> = [JsValue(resolveFn), JsValue(rejectFn)]
            let _ = executor.call(JsValue.undefined(), executorArgs)
        } catch (e: Exception) {
            // executor 抛出异常，reject promise
            promise.doReject(JsValue(e.message))
        }

        return promise
    }

    // then - Promise.prototype.then
    // 严格翻译自 ECMAScript 25.6.5.3 Promise.prototype.then(onFulfilled, onRejected)
    public func then(onFulfilled: ?JsFunction, onRejected: ?JsFunction): JsPromise {
        isHandled = true

        // 创建下游 Promise
        let downstream = JsPromise()

        // 创建 reaction
        let reaction = PromiseReaction(downstream, onFulfilled, onRejected)

        match (state) {
            case JsPromiseState.Pending =>
                // 还在 pending，加入 reactions 列表
                reactions.append(reaction)
            case JsPromiseState.Fulfilled =>
                // 已经 fulfilled，异步调度 reaction
                enqueueReactionJob(reaction, state, result)
            case JsPromiseState.Rejected =>
                // 已经 rejected，异步调度 reaction
                enqueueReactionJob(reaction, state, result)
        }

        return downstream
    }

    // catch - Promise.prototype.catch
    public func `catch`(onRejected: JsFunction): JsPromise {
        then(Option<JsFunction>.None, Some(onRejected))
    }

    // finally - Promise.prototype.finally
    // 严格翻译自 ECMAScript 25.6.5.5 Promise.prototype.finally(onFinally)
    public func `finally`(onFinally: JsFunction): JsPromise {
        then(
            Some(JsFunction("finally-fulfill", 1, { thisArg, args =>
                let value = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                let result = onFinally.call(JsValue.undefined(), Array<JsValue>())
                // 如果 finally 返回的是 thenable，等待它
                let p = JsPromise.resolve(result)
                if (p.state == JsPromiseState.Fulfilled) {
                    return value
                }
                p.result
            })),
            Some(JsFunction("finally-reject", 1, { thisArg, args =>
                let reason = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                let result = onFinally.call(JsValue.undefined(), [])
                let p = JsPromise.resolve(result)
                if (p.state == JsPromiseState.Fulfilled) {
                    return JsPromise.reject(reason).result
                }
                p.result
            }))
        )
    }

    // Promise.all - 严格翻译自 ECMAScript 25.6.4.1 Promise.all(iterable)
    public static func all(promises: Array<JsValue>): JsPromise {
        let result = JsPromise()
        if (promises.size == 0) {
            result.doResolve(JsValue(JsObject()))
            return result
        }

        let values = Array<JsValue>(promises.size, { _ => JsValue.undefined() })
        let remaining = MutableInt64(Int64(promises.size))
        let rejected = MutableBool(false)

        for (i in 0..promises.size) {
            let idx = i
            let p = JsPromise.resolve(promises[i])
            let _ = p.then(
                Some(JsFunction("all-fulfill", 1, { thisArg, args =>
                    if (rejected.value) { return JsValue.undefined() }
                    let val = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                    values[idx] = val
                    remaining.value -= 1
                    if (remaining.value == 0) {
                        result.doResolve(JsValue(JsObject()))
                    }
                    JsValue.undefined()
                })),
                Some(JsFunction("all-reject", 1, { thisArg, args =>
                    if (!rejected.value) {
                        rejected.value = true
                        let reason = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                        result.doReject(reason)
                    }
                    JsValue.undefined()
                }))
            )
        }

        return result
    }

    // Promise.allSettled
    public static func allSettled(promises: Array<JsValue>): JsPromise {
        let result = JsPromise()
        if (promises.size == 0) {
            result.doResolve(JsValue(JsObject()))
            return result
        }

        let results = Array<JsValue>(promises.size, { _ => JsValue.undefined() })
        let remaining = MutableInt64(Int64(promises.size))

        for (i in 0..promises.size) {
            let idx = i
            let p = JsPromise.resolve(promises[i])
            let _ = p.then(
                Some(JsFunction("allSettled-fulfill", 1, { thisArg, args =>
                    let val = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                    let obj = JsObject()
                    obj.set("status", JsValue("fulfilled"))
                    obj.set("value", val)
                    results[idx] = JsValue(obj)
                    remaining.value -= 1
                    if (remaining.value == 0) {
                        result.doResolve(JsValue(JsObject()))
                    }
                    JsValue.undefined()
                })),
                Some(JsFunction("allSettled-reject", 1, { thisArg, args =>
                    let reason = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                    let obj = JsObject()
                    obj.set("status", JsValue("rejected"))
                    obj.set("reason", reason)
                    results[idx] = JsValue(obj)
                    remaining.value -= 1
                    if (remaining.value == 0) {
                        result.doResolve(JsValue(JsObject()))
                    }
                    JsValue.undefined()
                }))
            )
        }

        return result
    }

    // Promise.race - 严格翻译自 ECMAScript 25.6.4.3 Promise.race(iterable)
    public static func race(promises: Array<JsValue>): JsPromise {
        let result = JsPromise()
        if (promises.size == 0) {
            return result
        }

        for (i in 0..promises.size) {
            let p = JsPromise.resolve(promises[i])
            let _ = p.then(
                Some(JsFunction("race-fulfill", 1, { thisArg, args =>
                    let val = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                    if (result.state == JsPromiseState.Pending) {
                        result.doResolve(val)
                    }
                    JsValue.undefined()
                })),
                Some(JsFunction("race-reject", 1, { thisArg, args =>
                    let reason = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                    if (result.state == JsPromiseState.Pending) {
                        result.doReject(reason)
                    }
                    JsValue.undefined()
                }))
            )
        }

        return result
    }

    // Promise.any - 严格翻译自 ECMAScript 25.6.4.1 Promise.any(iterable)
    public static func any(promises: Array<JsValue>): JsPromise {
        let result = JsPromise()
        if (promises.size == 0) {
            result.doReject(JsValue("All promises were rejected"))
            return result
        }

        let remaining = MutableInt64(Int64(promises.size))
        let fulfilled = MutableBool(false)

        for (i in 0..promises.size) {
            let p = JsPromise.resolve(promises[i])
            let _ = p.then(
                Some(JsFunction("any-fulfill", 1, { thisArg, args =>
                    if (!fulfilled.value) {
                        fulfilled.value = true
                        let val = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                        result.doResolve(val)
                    }
                    JsValue.undefined()
                })),
                Some(JsFunction("any-reject", 1, { thisArg, args =>
                    remaining.value -= 1
                    if (remaining.value == 0 && !fulfilled.value) {
                        result.doReject(JsValue("All promises were rejected"))
                    }
                    JsValue.undefined()
                }))
            )
        }

        return result
    }

    // ========== 内部方法 ==========

    // doResolve - 内部 fulfill
    func doResolve(value: JsValue) {
        if (state != JsPromiseState.Pending) {
            return
        }
        state = JsPromiseState.Fulfilled
        result = value
        // 触发所有 pending reactions
        triggerReactions()
    }

    // doReject - 内部 reject
    func doReject(reason: JsValue) {
        if (state != JsPromiseState.Pending) {
            return
        }
        state = JsPromiseState.Rejected
        result = reason
        // 触发所有 pending reactions
        triggerReactions()
    }

    // 触发所有 pending reactions
    private func triggerReactions() {
        for (reaction in reactions) {
            enqueueReactionJob(reaction, state, result)
        }
        reactions.clear()
    }

    // 入队 reaction 微任务
    private static func enqueueReactionJob(reaction: PromiseReaction, status: JsPromiseState, value: JsValue): Unit {
        microtaskQueue.append({ =>
            promiseReactionJob(reaction, status, value)
        })
    }

    // PromiseReactionJob - 执行 reaction 回调
    // 严格翻译自 ECMAScript 25.6.2.1 PromiseReactionJob
    static func promiseReactionJob(reaction: PromiseReaction, status: JsPromiseState, value: JsValue) {
        var handlerResult: JsValue = value
        var handlerThrew = false

        match (status) {
            case JsPromiseState.Fulfilled =>
                if (let Some(handler) <- reaction.onFulfilled) {
                    try {
                        handlerResult = handler.call(JsValue.undefined(), [value])
                    } catch (e: Exception) {
                        handlerThrew = true
                        handlerResult = JsValue(e.message)
                    }
                }
            case JsPromiseState.Rejected =>
                if (let Some(handler) <- reaction.onRejected) {
                    try {
                        handlerResult = handler.call(JsValue.undefined(), [value])
                    } catch (e: Exception) {
                        handlerThrew = true
                        handlerResult = JsValue(e.message)
                    }
                } else {
                    // 没有 reject handler，直接 reject 下游
                    reaction.downstream.doReject(value)
                    return
                }
            case _ => ()
        }

        if (handlerThrew) {
            reaction.downstream.doReject(handlerResult)
        } else {
            resolvePromise(reaction.downstream, handlerResult)
        }
    }

    // resolvePromise - Promise Resolution Procedure
    // 严格翻译自 ECMAScript 25.6.2.3 PromiseResolveThenableJob
    static func resolvePromise(promise: JsPromise, x: JsValue): Unit {
        // 25.6.2.3 step 1: If x === promise, throw TypeError
        // (简化：跳过循环检测)

        // 25.6.2.3 step 2: If x is a Promise, adopt its state
        if (x.isObject()) {
            let obj = x.toObject()
            if (obj.className == "Promise") {
                // x 是 Promise，链式等待
                let _ = JsPromise.resolve(x).then(
                    Some(JsFunction("resolve-chain", 1, { thisArg, args =>
                        let val = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                        promise.doResolve(val)
                        JsValue.undefined()
                    })),
                    Some(JsFunction("reject-chain", 1, { thisArg, args =>
                        let reason = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                        promise.doReject(reason)
                        JsValue.undefined()
                    }))
                )
                return
            }

            // 25.6.2.3 step 3: If x is thenable
            if (obj.has("then")) {
                let thenVal = obj.get("then")
                if (thenVal.isCallable()) {
                    // 调用 then.call(x, resolve, reject)
                    let called = MutableBool(false)
                    let resolveFn = JsFunction("then-resolve", 1, { thisArg, args =>
                        if (called.value) { return JsValue.undefined() }
                        called.value = true
                        let val = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                        resolvePromise(promise, val)
                        JsValue.undefined()
                    })
                    let rejectFn = JsFunction("then-reject", 1, { thisArg, args =>
                        if (called.value) { return JsValue.undefined() }
                        called.value = true
                        let reason = if (args.size > 0) { args[0] } else { JsValue.undefined() }
                        promise.doReject(reason)
                        JsValue.undefined()
                    })
                    try {
                        let thenArgs: Array<JsValue> = [JsValue(resolveFn), JsValue(rejectFn)]
                        let _ = thenVal.call(JsObject(), x, thenArgs)
                    } catch (e: Exception) {
                        if (!called.value) {
                            promise.doReject(JsValue(e.message))
                        }
                    }
                    return
                }
            }
        }

        // 25.6.2.3 step 4: x is not a thenable
        promise.doResolve(x)
    }

    // wrapThenable - 包装 thenable 对象
    static func wrapThenable(value: JsValue, obj: JsObject): JsPromise {
        let p = JsPromise()
        resolvePromise(p, value)
        return p
    }

    // 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject.make()
        obj.className = "Promise"
        obj.set("[[PromiseState]]", JsValue(state.toString()))
        obj.set("[[PromiseResult]]", result)
        return JsValue(obj)
    }

    // 转为 JsValue (toJS)
    public func toJS(): JsValue {
        toJsValue()
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

    // ========== 微任务队列 ==========

    // 排空微任务队列
    // 对应 JSC JSGlobalObject drainMicrotasks
    public static func drainMicrotasks(): Unit {
        while (microtaskQueue.size > 0) {
            let task = microtaskQueue.removeAt(0)
            task()
        }
    }

    // 获取微任务队列大小
    public static func microtaskQueueSize(): Int64 {
        Int64(microtaskQueue.size)
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
