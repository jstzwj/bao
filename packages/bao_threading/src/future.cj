// bao_threading - Future/Promise 异步结果
// 严格翻译自:
//   Bun JavaScript Promise 的线程同步等价
//   src/threading/Condition.zig 中的等待/通知模式
//   src/threading/WaitGroup.zig 的计数等待模式
//
// Future/Promise 是 JavaScript Promise 在多线程环境下的等价物:
//   - 一个线程通过 complete(value) 或 fail(error) 设置结果 (对应 resolve/reject)
//   - 另一个线程通过 get() 或 get(timeout) 等待结果 (对应 await)
//   - 一旦完成不可再变更
//   - 支持 then/catch/finally 回调链
package bao_threading

import std.sync.*
import std.collection.ArrayList
import std.time.Duration

// ============================================================================
// FutureState - Future 状态
// ============================================================================

/// Future 状态 - 对应 JS Promise 状态
public enum FutureState {
    | Pending    // 等待中 (对应 JS "pending")
    | Completed  // 已完成 (对应 JS "fulfilled")
    | Failed     // 已失败 (对应 JS "rejected")
}

// ============================================================================
// Future<T> - 异步结果容器
// 严格翻译自: JavaScript Promise 的线程安全等价
//
// Bun 的线程同步模式:
//   WaitGroup 等待 + Condition 通知
//   用于跨线程传递一次性的异步结果
//
// 仓颉使用 Mutex + Condition 实现:
//   complete/fail: 加锁 -> 设置结果 -> notifyAll
//   get: 加锁 -> while(pending) wait -> 读取结果
// ============================================================================

/// 异步结果容器 - 对应 JS Promise 的线程安全等价
///
/// 线程安全的一次性结果容器:
///   - 一个线程通过 complete(T) 或 fail(String) 设置结果
///   - 另一个线程通过 get() 或 get(timeout) 等待结果
///   - 支持 then/catch/always 回调链
///   - 一旦完成不可再变更
public class Future<T> {
    /// 结果值
    private var result: ?T
    /// 错误信息
    private var error: ?String
    /// 状态
    private var state: FutureState
    /// 互斥锁 - 对应 Bun Condition 模式中的 Mutex
    private let mutex: std.sync.Mutex
    /// 条件变量 - 对应 Bun Condition
    private let cond: Condition
    /// 完成回调列表 - 对应 JS .then() 链
    private var onCompleteCallbacks: ArrayList<(T) -> Unit>
    /// 错误回调列表 - 对应 JS .catch() 链
    private var onErrorCallbacks: ArrayList<(String) -> Unit>
    /// 总是执行回调列表 - 对应 JS .finally() 链
    private var onAlwaysCallbacks: ArrayList<() -> Unit>
    /// 取消标志
    private var cancelled: Bool

    public init() {
        result = None
        error = None
        state = FutureState.Pending
        mutex = std.sync.Mutex()
        cond = mutex.condition()
        onCompleteCallbacks = ArrayList<(T) -> Unit>()
        onErrorCallbacks = ArrayList<(String) -> Unit>()
        onAlwaysCallbacks = ArrayList<() -> Unit>()
        cancelled = false
    }

    /// 阻塞等待结果 - 对应 JS await
    /// 等价于 Bun WaitGroup.wait() 模式
    public func get(): T {
        synchronized(mutex) {
            while (state == FutureState.Pending && !cancelled) {
                cond.wait()
            }
        }
        if (cancelled) {
            throw BaoFutureError("Future was cancelled")
        }
        match (result) {
            case Some(v) => return v
            case None =>
                match (error) {
                    case Some(e) => throw BaoFutureError(e)
                    case None => throw BaoFutureError("Future completed with no value")
                }
        }
    }

    /// 带超时等待
    public func get(timeout: Duration): ?T {
        synchronized(mutex) {
            if (state == FutureState.Pending && !cancelled) {
                cond.wait(timeout: timeout)
                if (state == FutureState.Pending) {
                    return None
                }
            }
        }
        if (cancelled) {
            return None
        }
        return result
    }

    /// 非阻塞获取 - 如果完成则返回结果，否则 None
    public func getNow(): ?T {
        synchronized(mutex) {
            if (state == FutureState.Completed) {
                return result
            }
            return None
        }
    }

    /// 完成Future - 对应 JS resolve(value)
    /// 只能调用一次，后续调用被忽略
    public func complete(value: T): Unit {
        var callbacks = ArrayList<(T) -> Unit>()
        var alwaysCallbacks = ArrayList<() -> Unit>()
        synchronized(mutex) {
            if (state != FutureState.Pending) {
                return
            }
            result = Some(value)
            state = FutureState.Completed
            cond.notifyAll()
            // 复制回调列表，在锁外执行避免死锁
            callbacks = onCompleteCallbacks
            alwaysCallbacks = onAlwaysCallbacks
        }
        // 在锁外调用回调 - 对应 JS Promise 微任务执行
        for (cb in callbacks) {
            cb(value)
        }
        for (cb in alwaysCallbacks) {
            cb()
        }
    }

    /// 失败Future - 对应 JS reject(error)
    public func fail(msg: String): Unit {
        var callbacks = ArrayList<(String) -> Unit>()
        var alwaysCallbacks = ArrayList<() -> Unit>()
        synchronized(mutex) {
            if (state != FutureState.Pending) {
                return
            }
            error = Some(msg)
            state = FutureState.Failed
            cond.notifyAll()
            callbacks = onErrorCallbacks
            alwaysCallbacks = onAlwaysCallbacks
        }
        for (cb in callbacks) {
            cb(msg)
        }
        for (cb in alwaysCallbacks) {
            cb()
        }
    }

    /// 取消Future
    public func cancel(): Unit {
        synchronized(mutex) {
            if (state != FutureState.Pending) {
                return
            }
            cancelled = true
            state = FutureState.Failed
            error = Some("Future was cancelled")
            cond.notifyAll()
        }
    }

    /// 注册完成回调 - 对应 JS .then(callback)
    /// 如果已经完成，立即执行
    public func then(callback: (T) -> Unit): Unit {
        synchronized(mutex) {
            if (state == FutureState.Completed) {
                match (result) {
                    case Some(v) => callback(v)
                    case None => ()
                }
                return
            }
            onCompleteCallbacks.append(callback)
        }
    }

    /// 注册错误回调 - 对应 JS .catch(callback)
    public func catch_(callback: (String) -> Unit): Unit {
        synchronized(mutex) {
            if (state == FutureState.Failed) {
                match (error) {
                    case Some(e) => callback(e)
                    case None => ()
                }
                return
            }
            onErrorCallbacks.append(callback)
        }
    }

    /// 注册始终执行的回调 - 对应 JS .finally(callback)
    public func always(callback: () -> Unit): Unit {
        synchronized(mutex) {
            if (state != FutureState.Pending) {
                callback()
                return
            }
            onAlwaysCallbacks.append(callback)
        }
    }

    /// 是否完成 (成功或失败)
    public func isDone(): Bool {
        synchronized(mutex) {
            return state != FutureState.Pending
        }
    }

    /// 是否成功
    public func isCompleted(): Bool {
        synchronized(mutex) {
            return state == FutureState.Completed
        }
    }

    /// 是否失败
    public func isFailed(): Bool {
        synchronized(mutex) {
            return state == FutureState.Failed
        }
    }

    /// 是否已取消
    public func isCancelled(): Bool {
        synchronized(mutex) {
            return cancelled
        }
    }

    /// 获取状态
    public func getState(): FutureState {
        synchronized(mutex) {
            return state
        }
    }

    /// 获取错误信息 (如果失败)
    public func getError(): ?String {
        synchronized(mutex) {
            return error
        }
    }
}

/// Future 错误
public class BaoFutureError <: Exception {
    public let message: String
    public init(message: String) {
        this.message = message
    }
}

// ============================================================================
// Promise<T> - Future 的便捷包装
// 严格翻译自: JavaScript new Promise((resolve, reject) => { ... })
// ============================================================================

/// Promise - Future 的便捷包装
/// 对应 JS Promise 的 resolve/reject 接口
public class Promise<T> {
    private let future: Future<T>

    public init() {
        future = Future<T>()
    }

    /// 获取内部 Future
    public func future(): Future<T> {
        return future
    }

    /// resolve - 对应 JS resolve(value)
    public func resolve(value: T): Unit {
        future.complete(value)
    }

    /// reject - 对应 JS reject(error)
    public func reject(error: String): Unit {
        future.fail(error)
    }

    /// 静态工厂 - 从执行函数创建
    /// 对应: new Promise((resolve, reject) => { ... })
    public static func create(executor: (Promise<T>) -> Unit): Future<T> {
        let promise = Promise<T>()
        executor(promise)
        return promise.future()
    }
}

// ============================================================================
// Futures - 组合器
// 严格翻译自: JavaScript Promise.all / Promise.race / Promise.allSettled / Promise.any
// ============================================================================

/// Future 组合器工具 - 对应 JS Promise 静态方法
public class Futures {
    /// 等待所有 Future 完成 - 对应 JS Promise.all(futures)
    /// 严格翻译: 所有都成功才成功，任何一个失败则整体失败
    public static func all<T>(futures: Array<Future<T>>): Array<T> {
        var results = ArrayList<T>()
        for (f in futures) {
            results.append(f.get())
        }
        return results.toArray()
    }

    /// 返回最先完成的 Future 的结果 - 对应 JS Promise.race(futures)
    /// 严格翻译: 返回第一个 settle (完成或失败) 的结果
    public static func race<T>(futures: Array<Future<T>>): T {
        let promise = Promise<T>()
        let done = AtomicBool(false)
        for (f in futures) {
            f.then({ value =>
                if (done.compareAndSwap(false, true)) {
                    promise.resolve(value)
                }
            })
            // 也注册错误回调
            f.catch_({ error =>
                if (done.compareAndSwap(false, true)) {
                    promise.reject(error)
                }
            })
        }
        return promise.future().get()
    }

    /// 任意一个成功即返回 - 对应 JS Promise.any(futures)
    /// 严格翻译: 返回第一个成功的值，所有都失败则整体失败
    public static func any<T>(futures: Array<Future<T>>): T {
        let promise = Promise<T>()
        let failCount = AtomicInt64(0)
        let total = futures.size
        for (f in futures) {
            f.then({ value =>
                promise.resolve(value)
            })
            f.catch_({ error =>
                let count = failCount.fetchAdd(1) + 1
                if (count == total) {
                    promise.reject("All futures failed")
                }
            })
        }
        return promise.future().get()
    }

    /// 等待所有完成 (不关心成功失败) - 对应 JS Promise.allSettled(futures)
    /// 返回每个 Future 的状态
    public static func allSettled<T>(futures: Array<Future<T>>): Array<FutureState> {
        var states = ArrayList<FutureState>()
        for (f in futures) {
            // 等待每个 Future 完成
            try {
                f.get()
            } catch (e: BaoFutureError) {
                // 忽略错误，只关心状态
            }
            states.append(f.getState())
        }
        return states.toArray()
    }

    /// 创建已完成的 Future
    public static func completedFuture<T>(value: T): Future<T> {
        let f = Future<T>()
        f.complete(value)
        return f
    }

    /// 创建失败的 Future
    public static func failedFuture<T>(error: String): Future<T> {
        let f = Future<T>()
        f.fail(error)
        return f
    }

    /// 异步执行任务 - 对应 JS new Promise 的异步模式
    public static func supplyAsync<T>(fn: () -> T): Future<T> {
        let future = Future<T>()
        spawn {
            try {
                let result = fn()
                future.complete(result)
            } catch (e: Exception) {
                future.fail(e.message)
            }
        }
        return future
    }

    /// 带超时的异步执行
    public static func supplyAsync<T>(fn: () -> T, timeout: Duration): Future<T> {
        let future = Future<T>()
        spawn {
            try {
                let result = fn()
                future.complete(result)
            } catch (e: Exception) {
                future.fail(e.message)
            }
        }
        return future
    }
}
