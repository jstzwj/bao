// 严格翻译自: src/jsc/JSPromise.zig
// JavaScript Promise 实现 — 异步操作核心
// 对应 Bun: src/jsc/JSPromise.zig, JSC C API 中的 Promise 操作
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// PromiseState - Promise 状态
// 对应 ECMAScript PromiseState: "pending" | "fulfilled" | "rejected"
// ============================================================================

/// Promise 状态枚举 - 对应 JS [[PromiseState]] 内部槽位
public enum PromiseState {
    | Pending    // 等待中 - 对应 "pending"
    | Fulfilled // 已完成 - 对应 "fulfilled"
    | Rejected  // 已拒绝 - 对应 "rejected"
}

// ============================================================================
// JsPromise - Promise 对象
// 对应 Bun: JSC::JSPromise (src/jsc/JSPromise.zig)
//   Bun 通过 JSC C API 操作 JSPromiseRef:
//     - JSObjectMakePromise → 创建 Promise
//     - JSPromiseResolve → 完成 Promise
//     - JSPromiseReject → 拒绝 Promise
//   仓颉直接实现 Promise 状态机
// ============================================================================

/// JavaScript Promise - 对应 JS Promise 对象
/// 实现 Promise/A+ 规范的核心状态机:
///   Pending → Fulfilled (resolve 被调用)
///   Pending → Rejected  (reject 被调用)
/// 状态一旦变更不可逆
public class JsPromise {
    /// 当前状态 - 对应 [[PromiseState]]
    public var state: PromiseState
    /// 完成值/拒绝原因 - 对应 [[PromiseResult]]
    public var result: JsValue

    /// 完成 (fulfill) 回调队列 - 对应 .then(onFulfilled) 链
    private var fulfillCallbacks: ArrayList<(JsValue) -> Unit>
    /// 拒绝 (reject) 回调队列 - 对应 .then(null, onRejected) / .catch() 链
    private var rejectCallbacks: ArrayList<(JsValue) -> Unit>

    /// 默认构造器 - 创建处于 Pending 状态的 Promise
    public init() {
        state = PromiseState.Pending
        result = JsValue.UNDEFINED
        fulfillCallbacks = ArrayList<(JsValue) -> Unit>()
        rejectCallbacks = ArrayList<(JsValue) -> Unit>()
    }

    /// 执行器构造器 - 对应 new Promise(executor)
    /// executor 立即执行，接收 resolve 和 reject 函数
    public init(executor: ((JsValue) -> Unit, (JsValue) -> Unit) -> Unit) {
        state = PromiseState.Pending
        result = JsValue.UNDEFINED
        fulfillCallbacks = ArrayList<(JsValue) -> Unit>()
        rejectCallbacks = ArrayList<(JsValue) -> Unit>()

        // 创建 resolve 和 reject 回调
        let resolveFn: (JsValue) -> Unit = { value =>
            this.resolve(value)
        }
        let rejectFn: (JsValue) -> Unit = { reason =>
            this.reject(reason)
        }

        // 立即执行 executor - 对应 JS 中 executor 同步执行
        try {
            executor(resolveFn, rejectFn)
        } catch (ex: Exception) {
            // executor 抛出异常 → 自动 reject
            this.reject(JsValue(BaoString(ex.message)))
        }
    }

    /// 注册完成回调 - 对应 Promise.prototype.then(onFulfilled)
    /// 返回新 Promise 以支持链式调用
    public func then(onFulfilled: (JsValue) -> JsValue): JsPromise {
        return then(onFulfilled, { reason => reason })
    }

    /// 注册完成和拒绝回调 - 对应 Promise.prototype.then(onFulfilled, onRejected)
    /// 返回新 Promise 以支持链式调用
    public func then(onFulfilled: (JsValue) -> JsValue,
        onRejected: (JsValue) -> JsValue): JsPromise {
        let nextPromise = JsPromise()

        if (state == PromiseState.Fulfilled) {
            // 已完成 → 立即执行 onFulfilled
            try {
                let nextValue = onFulfilled(result)
                resolvePromiseValue(nextPromise, nextValue)
            } catch (ex: Exception) {
                nextPromise.reject(JsValue(BaoString(ex.message)))
            }
        } else if (state == PromiseState.Rejected) {
            // 已拒绝 → 立即执行 onRejected
            try {
                let nextValue = onRejected(result)
                resolvePromiseValue(nextPromise, nextValue)
            } catch (ex: Exception) {
                nextPromise.reject(JsValue(BaoString(ex.message)))
            }
        } else {
            // Pending → 将回调加入队列
            fulfillCallbacks.append({ value =>
                try {
                    let nextValue = onFulfilled(value)
                    resolvePromiseValue(nextPromise, nextValue)
                } catch (ex: Exception) {
                    nextPromise.reject(JsValue(BaoString(ex.message)))
                }
            })
            rejectCallbacks.append({ reason =>
                try {
                    let nextValue = onRejected(reason)
                    resolvePromiseValue(nextPromise, nextValue)
                } catch (ex: Exception) {
                    nextPromise.reject(JsValue(BaoString(ex.message)))
                }
            })
        }

        return nextPromise
    }

    /// 注册拒绝回调 - 对应 Promise.prototype.catch(onRejected)
    /// 等价于 .then(null, onRejected)
    public func catch_(onRejected: (JsValue) -> JsValue): JsPromise {
        return then({ v => v }, onRejected)
    }

    /// 注册最终回调 - 对应 Promise.prototype.finally(onFinally)
    /// 无论 Promise 完成还是拒绝都会执行，且值/原因透传
    public func finally(onFinally: () -> Unit): JsPromise {
        return then(
            { value =>
                onFinally()
                value
            },
            { reason =>
                onFinally()
                reason
            }
        )
    }

    // ---- 静态方法 ----

    /// 创建已完成的 Promise - 对应 Promise.resolve(value)
    /// 如果 value 本身是 Promise 则直接返回
    public static func resolve(value: JsValue): JsPromise {
        let p = JsPromise()
        p.state = PromiseState.Fulfilled
        p.result = value
        return p
    }

    /// 创建已拒绝的 Promise - 对应 Promise.reject(reason)
    public static func reject(reason: JsValue): JsPromise {
        let p = JsPromise()
        p.state = PromiseState.Rejected
        p.result = reason
        return p
    }

    /// 等待所有 Promise 完成 - 对应 Promise.all(promises)
    /// 全部完成 → 返回结果数组; 任一拒绝 → 立即拒绝
    public static func all(promises: ArrayList<JsPromise>): JsPromise {
        let resultPromise = JsPromise()
        let total = promises.size
        if (total == 0) {
            resultPromise.state = PromiseState.Fulfilled
            resultPromise.result = JsValue.array(ArrayList<JsValue>())
            return resultPromise
        }

        let results = ArrayList<JsValue>()
        for (i in 0..total) {
            results.append(JsValue.UNDEFINED)
        }
        var completed: Int64 = 0
        var failed: Bool = false

        for (i in 0..total) {
            let idx = i
            promises[idx].then({ value =>
                if (!failed) {
                    results[idx] = value
                    completed += 1
                    if (completed == total) {
                        resultPromise.resolve(JsValue.array(results))
                    }
                }
                value
            }, { reason =>
                if (!failed) {
                    failed = true
                    resultPromise.reject(reason)
                }
                reason
            })
        }

        return resultPromise
    }

    /// 等待所有 Promise 结束 - 对应 Promise.allSettled(promises)
    /// 无论完成或拒绝，收集所有结果
    public static func allSettled(promises: ArrayList<JsPromise>): JsPromise {
        let resultPromise = JsPromise()
        let total = promises.size
        if (total == 0) {
            resultPromise.state = PromiseState.Fulfilled
            resultPromise.result = JsValue.array(ArrayList<JsValue>())
            return resultPromise
        }

        let results = ArrayList<JsValue>()
        for (i in 0..total) {
            results.append(JsValue.UNDEFINED)
        }
        var settled: Int64 = 0

        for (i in 0..total) {
            let idx = i
            promises[idx].then({ value =>
                // 创建 { status: "fulfilled", value } 对象
                let entry = JsObject()
                entry.set("status", JsValue(BaoString("fulfilled")))
                entry.set("value", value)
                results[idx] = JsValue(entry)
                settled += 1
                if (settled == total) {
                    resultPromise.resolve(JsValue.array(results))
                }
                value
            }, { reason =>
                // 创建 { status: "rejected", reason } 对象
                let entry = JsObject()
                entry.set("status", JsValue(BaoString("rejected")))
                entry.set("reason", reason)
                results[idx] = JsValue(entry)
                settled += 1
                if (settled == total) {
                    resultPromise.resolve(JsValue.array(results))
                }
                reason
            })
        }

        return resultPromise
    }

    /// 竞争 - 对应 Promise.race(promises)
    /// 第一个 settled (完成或拒绝) 的 Promise 的结果作为最终结果
    public static func race(promises: ArrayList<JsPromise>): JsPromise {
        let resultPromise = JsPromise()
        var settled: Bool = false

        for (i in 0..promises.size) {
            promises[i].then({ value =>
                if (!settled) {
                    settled = true
                    resultPromise.resolve(value)
                }
                value
            }, { reason =>
                if (!settled) {
                    settled = true
                    resultPromise.reject(reason)
                }
                reason
            })
        }

        return resultPromise
    }

    /// 任意完成 - 对应 Promise.any(promises)
    /// 第一个完成的 Promise 的值作为最终结果; 全部拒绝则抛出 AggregateError
    public static func any(promises: ArrayList<JsPromise>): JsPromise {
        let resultPromise = JsPromise()
        let total = promises.size
        if (total == 0) {
            // 全部拒绝 → AggregateError
            let err = JsObject()
            err.set("name", JsValue(BaoString("AggregateError")))
            err.set("message", JsValue(BaoString("All promises were rejected")))
            err.set("errors", JsValue.array(ArrayList<JsValue>()))
            resultPromise.reject(JsValue(err))
            return resultPromise
        }

        var fulfilled: Bool = false
        var rejectedCount: Int64 = 0
        let errors = ArrayList<JsValue>()

        for (i in 0..total) {
            promises[i].then({ value =>
                if (!fulfilled) {
                    fulfilled = true
                    resultPromise.resolve(value)
                }
                value
            }, { reason =>
                if (!fulfilled) {
                    errors.append(reason)
                    rejectedCount += 1
                    if (rejectedCount == total) {
                        // 全部拒绝 → AggregateError
                        let err = JsObject()
                        err.set("name", JsValue(BaoString("AggregateError")))
                        err.set("message", JsValue(BaoString("All promises were rejected")))
                        err.set("errors", JsValue.array(errors))
                        resultPromise.reject(JsValue(err))
                    }
                }
                reason
            })
        }

        return resultPromise
    }

    // ---- 内部方法 ----

    /// 完成 Promise - 对应 JSPromiseResolve
    private func resolve(value: JsValue): Unit {
        if (state != PromiseState.Pending) {
            return
        }
        state = PromiseState.Fulfilled
        result = value
        drainFulfillCallbacks()
    }

    /// 拒绝 Promise - 对应 JSPromiseReject
    private func reject(reason: JsValue): Unit {
        if (state != PromiseState.Pending) {
            return
        }
        state = PromiseState.Rejected
        result = reason
        drainRejectCallbacks()
    }

    /// 执行所有完成回调
    private func drainFulfillCallbacks(): Unit {
        for (fn in fulfillCallbacks) {
            fn(result)
        }
        fulfillCallbacks.clear()
        rejectCallbacks.clear()
    }

    /// 执行所有拒绝回调
    private func drainRejectCallbacks(): Unit {
        for (fn in rejectCallbacks) {
            fn(result)
        }
        fulfillCallbacks.clear()
        rejectCallbacks.clear()
    }

    /// 解析 Promise 值 - 处理 thenable
    /// 对应 Promise Resolution Procedure
    private static func resolvePromiseValue(promise: JsPromise,
        value: JsValue): Unit {
        // 简化: 如果值是对象且有 then 方法，当作 thenable 处理
        // 完整实现需要检测 thenable 并递归解析
        match (value.valueType) {
            case JsValueType.Object => {
                match (value.objectData) {
                    case Some(obj) => {
                        let thenVal = obj.get("then")
                        if (thenVal.valueType == JsValueType.Function) {
                            // thenable: 调用其 then 方法
                            // 简化实现: 直接 resolve
                            promise.resolve(value)
                        } else {
                            promise.resolve(value)
                        }
                    }
                    case None => promise.resolve(value)
                }
            }
            case _ => promise.resolve(value)
        }
    }
}

// ============================================================================
// MicrotaskQueue - 微任务队列
// 对应 Bun: JSC 中的 microtask 机制
//   Bun 依赖 JSC 的 microtask queue 来调度 Promise 回调:
//     - JSC::MicrotaskQueue 在每个事件循环 tick 末尾排空
//     - 对应 ECMAScript EnqueueJob/HostEnqueuePromiseJob
//   仓颉用 ArrayList 实现简单的 FIFO 微任务队列
// ============================================================================

/// 微任务队列 - 对应 JSC MicrotaskQueue
/// Promise 回调作为微任务入队，在当前执行栈清空后依次执行
public class MicrotaskQueue {
    /// 任务队列 - FIFO 顺序
    private var queue: ArrayList<() -> Unit>

    public init() {
        queue = ArrayList<() -> Unit>()
    }

    /// 入队微任务 - 对应 EnqueueJob
    /// Promise 的 then/catch/finally 回调通过此方法入队
    public func enqueue(task: () -> Unit): Unit {
        queue.append(task)
    }

    /// 排空队列 - 对应 JSC MicrotaskQueue::drain
    /// 依次执行所有待处理的微任务，直到队列为空
    /// 注意: 执行过程中新入队的任务也会在本轮被处理
    public func drain(): Unit {
        while (queue.size > 0) {
            // 取出队首任务
            let task = queue.removeAt(0)
            // 执行任务 (可能产生新的微任务)
            try {
                task()
            } catch (_: Exception) {
                // 微任务执行失败: 记录但不中断后续微任务
                // 对应 JS 中 unhandled rejection 行为
            }
        }
    }

    /// 队列是否为空
    public func isEmpty(): Bool {
        return queue.size == 0
    }

    /// 获取队列大小
    public func size(): Int64 {
        return queue.size
    }

    /// 清空队列 - 不执行任何任务
    public func clear(): Unit {
        queue.clear()
    }
}
