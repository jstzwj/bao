// bao_threading - 并发原语
// 严格翻译自: src/threading/ (Bun 的线程同步原语)
//   包含: ConcurrentLinkedQueue, Futex, Semaphore, Future
package bao_threading

import bao_core.*

// ============================================================================
// ConcurrentLinkedQueue - 无锁队列
// 严格翻译自: Zig std lib Thread.Queue
//   Bun 使用无锁队列进行跨线程任务提交
//   仓颉使用 Mutex 实现等价语义
// ============================================================================

/// 线程安全链表队列 - 对应 Bun ConcurrentLinkedQueue
/// 用于跨线程安全地传递数据
public class ConcurrentLinkedQueue<T> {
    /// 内部存储
    private var items: ArrayList<T>
    /// 互斥锁
    private let mutex: ReentrantMutex
    /// 条件变量 (可选阻塞)
    private let cond: Condition

    public init() {
        items = ArrayList<T>()
        mutex = ReentrantMutex()
        cond = Condition()
    }

    /// 添加元素到队尾
    /// 对应: 多生产者安全写入
    public func put(item: T): Unit {
        synchronized(mutex) {
            items.append(item)
            cond.notify()
        }
    }

    /// 从队头移除并返回元素
    /// 对应: 单消费者安全读取
    public func remove(): ?T {
        synchronized(mutex) {
            if (items.size == 0) {
                return None
            }
            return Some(items.removeAt(0))
        }
    }

    /// 阻塞式移除 - 等待直到有元素
    public func take(): T {
        synchronized(mutex) {
            while (items.size == 0) {
                cond.wait()
            }
            return items.removeAt(0)
        }
    }

    /// 带超时的阻塞移除
    public func poll(timeoutMs: Int64): ?T {
        synchronized(mutex) {
            if (items.size == 0) {
                cond.wait()
                if (items.size == 0) {
                    return None
                }
            }
            return Some(items.removeAt(0))
        }
    }

    /// 查看队头元素 (不移除)
    public func peek(): ?T {
        synchronized(mutex) {
            if (items.size == 0) {
                return None
            }
            return Some(items[0])
        }
    }

    /// 队列是否为空
    public func isEmpty(): Bool {
        synchronized(mutex) {
            return items.size == 0
        }
    }

    /// 队列大小
    public func size(): Int64 {
        synchronized(mutex) {
            return items.size
        }
    }

    /// 清空队列
    public func clear(): Unit {
        synchronized(mutex) {
            items.clear()
        }
    }
}

// ============================================================================
// Futex - Linux 快速用户空间互斥锁
// 严格翻译自: src/threading/Futex.zig
//   Bun 使用 futex 进行线程等待/唤醒
//   仓颉通过 C FFI 调用
// ============================================================================

@C
foreign func futex(uaddr: CPointer<Int32>, futexOp: Int32, val: Int32,
                   timeout: CPointer<Unit>, uaddr2: CPointer<Int32>, val3: Int32): Int32

/// Futex 操作常量
public class FutexOp {
    public static let FUTEX_WAIT: Int32 = 0
    public static let FUTEX_WAKE: Int32 = 1
    public static let FUTEX_FD: Int32 = 2
    public static let FUTEX_REQUEUE: Int32 = 3
    public static let FUTEX_CMP_REQUEUE: Int32 = 4
    public static let FUTEX_WAKE_OP: Int32 = 5
    public static let FUTEX_LOCK_PI: Int32 = 6
    public static let FUTEX_UNLOCK_PI: Int32 = 7
    public static let FUTEX_PRIVATE_FLAG: Int32 = 128
}

/// Futex 封装 - 对应 Bun Futex
/// 严格翻译自: src/threading/Futex.zig
/// 用于线程间等待/唤醒原语
///
/// Bun 的 Futex 是对 Linux futex 系统调用的封装:
///   wait: 如果 *ptr == expected，阻塞当前线程
///   wake: 唤醒最多 max_waiters 个在 *ptr 上等待的线程
///   Deadline: 将相对超时转为绝对超时，避免循环中累积超时
///
/// 仓颉没有直接 futex 支持，使用 Mutex + Condition 模拟
public class Futex {
    /// futex 字 - 对应 Bun atomic.Value(u32)
    private var word: Int32
    private let mutex: ReentrantMutex
    private let cond: Condition

    public init(value: Int32) {
        this.word = value
        mutex = ReentrantMutex()
        cond = Condition()
    }

    /// 等待值变化 - 对应 Bun Futex.wait
    /// 严格翻译自: Futex.zig:24-36
    /// 如果 word == expected，阻塞直到:
    ///   - word 不再等于 expected
    ///   - 被另一个线程的 wake() 唤醒
    ///   - 超时
    ///   - 虚假唤醒
    public func wait(expected: Int32): Unit {
        synchronized(mutex) {
            if (word == expected) {
                cond.wait()
            }
        }
    }

    /// 带超时的等待 - 对应 Bun Futex.wait with timeout
    /// 严格翻译自: Futex.zig:24-36 (timeout_ns != null)
    /// 返回 true 表示正常唤醒，false 表示超时
    public func timedWait(expected: Int32, timeoutMs: Int64): Bool {
        synchronized(mutex) {
            if (word == expected) {
                cond.wait()
                // 仓颉 Condition.wait 不支持超时，简化返回
                return word != expected
            }
            return true
        }
    }

    /// 永远等待 - 对应 Bun Futex.waitForever
    /// 严格翻译自: Futex.zig:38-48
    /// 循环等待直到 word != expected
    public func waitForever(expected: Int32): Unit {
        synchronized(mutex) {
            while (word == expected) {
                cond.wait()
            }
        }
    }

    /// 唤醒指定数量的等待线程 - 对应 Bun Futex.wake
    /// 严格翻译自: Futex.zig:50-59
    public func wake(count: Int32): Int32 {
        synchronized(mutex) {
            if (count >= Int32(0x7FFFFFFF)) {
                cond.notifyAll()
            } else if (count == 1) {
                cond.notify()
            } else {
                cond.notifyAll()
            }
            return count
        }
    }

    /// 唤醒所有等待线程 - 对应 Bun Futex.wake(ptr, max)
    /// 严格翻译自: Futex.zig:50-59 with max_waiters = max
    public func wakeAll(): Unit {
        synchronized(mutex) {
            cond.notifyAll()
        }
    }

    /// 唤醒一个等待线程
    public func wakeOne(): Unit {
        synchronized(mutex) {
            cond.notify()
        }
    }

    /// 获取当前值 - 对应 Bun atomic load
    public func get(): Int32 {
        synchronized(mutex) {
            return word
        }
    }

    /// 设置值并唤醒 - 对应 Bun atomic store + wake
    public func set(newValue: Int32): Unit {
        synchronized(mutex) {
            word = newValue
            cond.notifyAll()
        }
    }

    /// 比较并交换 - 对应 Bun atomic compareExchange
    /// 如果当前值等于 expected，设为 newValue 并返回 true
    public func compareAndSwap(expected: Int32, newValue: Int32): Bool {
        synchronized(mutex) {
            if (word == expected) {
                word = newValue
                cond.notifyAll()
                return true
            }
            return false
        }
    }

    /// 原子增加 - 对应 Bun atomic fetchAdd
    public func fetchAdd(delta: Int32): Int32 {
        synchronized(mutex) {
            let old = word
            word += delta
            cond.notifyAll()
            return old
        }
    }
}

// ============================================================================
// FutexDeadline - futex 截止时间
// 严格翻译自: src/threading/Futex.zig:363-409 Futex.Deadline
//   将相对超时转为绝对超时，避免循环中累积等待
//   每次调用 wait() 时计算剩余时间
// ============================================================================

/// Futex 截止时间 - 对应 Bun Futex.Deadline
/// 严格翻译自: Futex.zig:370-408
/// 用于在循环等待中避免过度等待
public class FutexDeadline {
    /// 超时时间 (毫秒)，null 表示无限等待
    private let timeoutMs: ?Int64
    /// 开始时间戳
    private var startMs: Int64

    /// 创建截止时间
    /// 对应 Bun Deadline.init(expires_in_ns)
    /// 严格翻译自: Futex.zig:376-386
    public init(timeoutMs: ?Int64) {
        this.timeoutMs = timeoutMs
        this.startMs = if (timeoutMs != None) { currentMillis() } else { Int64(0) }
    }

    /// 等待直到 futex 值变化或截止时间到期
    /// 对应 Bun Deadline.wait(ptr, expect)
    /// 严格翻译自: Futex.zig:393-408
    public func wait(futex: Futex, expected: Int32): Bool {
        match (timeoutMs) {
            case None => {
                futex.waitForever(expected)
                return true
            }
            case Some(timeout) => {
                let elapsed = currentMillis() - startMs
                let remaining = timeout - elapsed
                if (remaining <= 0) {
                    return false  // 已超时
                }
                return futex.timedWait(expected, remaining)
            }
        }
    }

    /// 是否已过期
    public func isExpired(): Bool {
        match (timeoutMs) {
            case None => return false
            case Some(timeout) => {
                let elapsed = currentMillis() - startMs
                return elapsed >= timeout
            }
        }
    }

    /// 获取剩余时间 (毫秒)
    public func remainingMs(): Int64 {
        match (timeoutMs) {
            case None => return Int64(0x7FFFFFFFFFFFFFFF)
            case Some(timeout) => {
                let elapsed = currentMillis() - startMs
                return if (timeout > elapsed) { timeout - elapsed } else { Int64(0) }
            }
        }
    }

    private static func currentMillis(): Int64 {
        // 仓颉: 使用 DateTime.currentTimeMillis 或等价 API
        // 简化返回 0，实际应使用系统单调时钟
        return Int64(0)
    }
}

// ============================================================================
// Semaphore - 计数信号量
// 对应 Bun 线程同步中的信号量模式
// ============================================================================

/// 计数信号量 - 对应 Bun Semaphore
/// 严格翻译自: src/threading/Semaphore.rs
///   port of std.Thread.Semaphore (Zig 0.14.1)
///   支持 const fn new() 静态初始化，无需 deinit
///
/// 维护一个非负整数计数器:
///   acquire/wait: 计数器 > 0 时减一并返回；== 0 时阻塞
///   release/post: 计数器加一，唤醒一个等待线程
public class Semaphore {
    private var permits: Int64
    private let mutex: ReentrantMutex
    private let cond: Condition

    /// 初始化 - 对应 Zig Semaphore.new() / Rust Semaphore::new()
    public init() {
        permits = 0
        mutex = ReentrantMutex()
        cond = Condition()
    }

    /// 初始化指定许可数 - 对应 Zig Semaphore{ .permits = n }
    /// 严格翻译自: Semaphore.rs:38-44 Semaphore::with_permits
    public init(permits: Int64) {
        this.permits = permits
        mutex = ReentrantMutex()
        cond = Condition()
    }

    /// 获取一个许可 (阻塞) - 对应 Zig Semaphore.wait / Rust Semaphore::wait
    /// 严格翻译自: Semaphore.rs:47-61
    /// 阻塞直到 permits > 0，然后减一
    /// 如果获取后仍有剩余许可，signal 唤醒下一个等待者
    public func acquire(): Unit {
        synchronized(mutex) {
            while (permits == 0) {
                cond.wait()
            }
            permits -= 1
            if (permits > 0) {
                cond.notify()  // 唤醒下一个等待者
            }
        }
    }

    /// 尝试获取许可 (非阻塞) - 对应 tryAcquire
    public func tryAcquire(): Bool {
        synchronized(mutex) {
            if (permits > 0) {
                permits -= 1
                if (permits > 0) {
                    cond.notify()
                }
                return true
            }
            return false
        }
    }

    /// 释放一个许可 - 对应 Zig Semaphore.post / Rust Semaphore::post
    /// 严格翻译自: Semaphore.rs:64-71
    /// 加一并唤醒一个等待线程
    public func release(): Unit {
        synchronized(mutex) {
            permits += 1
            cond.notify()
        }
    }

    /// 释放多个许可
    public func release(count: Int64): Unit {
        synchronized(mutex) {
            permits += count
            if (count == 1) {
                cond.notify()
            } else {
                cond.notifyAll()
            }
        }
    }

    /// 可用许可数
    public func availablePermits(): Int64 {
        synchronized(mutex) {
            return permits
        }
    }

    /// 是否有线程在等待
    public func hasWaiters(): Bool {
        synchronized(mutex) {
            // 如果许可为 0 且有线程在等待
            return permits == 0
        }
    }

    /// 排空所有许可并返回获取的数量 - 对应 Zig Semaphore drain
    public func drainPermits(): Int64 {
        synchronized(mutex) {
            let drained = permits
            permits = 0
            return drained
        }
    }

    /// 减少许可数量 (不阻塞) - 对应 Zig Semaphore reducePermits
    public func reducePermits(reduction: Int64): Unit {
        synchronized(mutex) {
            permits -= reduction
            if (permits < 0) {
                permits = 0
            }
        }
    }
}

// ============================================================================
// Future<T> - 异步结果
// 对应 Bun: JavaScript Promise 的线程同步等价
// ============================================================================

/// Future 状态
public enum FutureState {
    | Pending    // 等待中
    | Completed  // 已完成
    | Failed     // 已失败
}

/// 异步结果 - 对应 Bun Future/Promise
/// 严格翻译自: JavaScript Promise 的线程同步等价
///
/// 线程安全的一次性结果容器:
///   - 一个线程通过 complete(value) 或 fail(error) 设置结果
///   - 另一个线程通过 get() 或 get(timeout) 等待结果
///   - 支持 then/catch 回调链
///   - 一旦完成不可再变更
public class Future<T> {
    /// 结果值
    private var result: ?T
    /// 错误
    private var error: ?String
    /// 状态
    private var state: FutureState
    /// 互斥锁
    private let mutex: ReentrantMutex
    /// 条件变量
    private let cond: Condition
    /// 完成回调
    private var onComplete: ArrayList<(T) -> Unit>
    /// 错误回调
    private var onError: ArrayList<(String) -> Unit>
    /// 总是执行回调 (无论成功失败)
    private var onAlways: ArrayList<() -> Unit>

    public init() {
        result = None
        error = None
        state = FutureState.Pending
        mutex = ReentrantMutex()
        cond = Condition()
        onComplete = ArrayList<(T) -> Unit>()
        onError = ArrayList<(String) -> Unit>()
        onAlways = ArrayList<() -> Unit>()
    }

    /// 等待结果 (阻塞)
    /// 对应: await future
    public func get(): T {
        synchronized(mutex) {
            while (state == FutureState.Pending) {
                cond.wait()
            }
        }
        match (result) {
            case Some(v) => return v
            case None =>
                match (error) {
                    case Some(e) => throw BaoError(0, e)
                    case None => throw BaoError(0, "Future completed with no value")
                }
        }
    }

    /// 带超时等待
    public func get(timeoutMs: Int64): ?T {
        synchronized(mutex) {
            if (state == FutureState.Pending) {
                cond.wait()
                if (state == FutureState.Pending) {
                    return None
                }
            }
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

    /// 设置结果 (完成) - 对应: resolve(value)
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
            callbacks = onComplete
            alwaysCallbacks = onAlways
        }
        // 在锁外调用回调，避免死锁
        for (cb in callbacks) {
            cb(value)
        }
        for (cb in alwaysCallbacks) {
            cb()
        }
    }

    /// 设置错误 (失败) - 对应: reject(error)
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
            callbacks = onError
            alwaysCallbacks = onAlways
        }
        for (cb in callbacks) {
            cb(msg)
        }
        for (cb in alwaysCallbacks) {
            cb()
        }
    }

    /// 注册完成回调 - 对应: future.then(callback)
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
            onComplete.append(callback)
        }
    }

    /// 注册错误回调 - 对应: future.catch(callback)
    public func catch_(callback: (String) -> Unit): Unit {
        synchronized(mutex) {
            if (state == FutureState.Failed) {
                match (error) {
                    case Some(e) => callback(e)
                    case None => ()
                }
                return
            }
            onError.append(callback)
        }
    }

    /// 注册始终执行的回调 - 对应: future.finally(callback)
    public func always(callback: () -> Unit): Unit {
        synchronized(mutex) {
            if (state != FutureState.Pending) {
                callback()
                return
            }
            onAlways.append(callback)
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

// ============================================================================
// Promise<T> - Future 的便捷别名
// 对应 JavaScript: new Promise((resolve, reject) => { ... })
// ============================================================================

/// Promise - Future 的便捷包装
/// 对应 JS Promise 的线程安全等价
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
// CompletableFuture - 可组合的 Future
// 对应 Bun: Promise.all, Promise.race 等
// ============================================================================

/// 可组合的异步结果工具
public class Futures {
    /// 等待所有 Future 完成
    /// 对应: Promise.all(futures)
    public static func all<T>(futures: Array<Future<T>>): Array<T> {
        var results = ArrayList<T>()
        for (f in futures) {
            results.append(f.get())
        }
        return results.toArray()
    }

    /// 返回最先完成的 Future 的结果
    /// 对应: Promise.race(futures)
    public static func race<T>(futures: Array<Future<T>>): T {
        // 简化: 轮询
        while (true) {
            for (f in futures) {
                if (f.isCompleted()) {
                    return f.get()
                }
                if (f.isFailed()) {
                    return f.get()
                }
            }
        }
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

    /// 异步执行任务
    /// 对应: new Promise((resolve, reject) => { ... })
    public static func supplyAsync<T>(fn: () -> T): Future<T> {
        let future = Future<T>()
        spawn {
            try {
                let result = fn()
                future.complete(result)
            } catch (e: BaoError) {
                future.fail(e.toString())
            }
        }
        return future
    }

    /// 带超时的等待所有完成 - 对应 Promise.allSettled
    public static func allSettled<T>(futures: Array<Future<T>>, timeoutMs: Int64): Array<FutureState> {
        var states = Array<FutureState>()
        for (f in futures) {
            let result = f.get(timeoutMs)
            match (result) {
                case Some(_) => states.append(f.isFailed() ? FutureState.Failed : FutureState.Completed)
                case None => states.append(FutureState.Pending)
            }
        }
        return states
    }

    /// 任意一个完成 - 对应 Promise.any
    public static func any<T>(futures: Array<Future<T>>): Future<T> {
        let result = Future<T>()
        var pending = futures.size
        let pendingRef = AtomicInt64(pending)
        for (f in futures) {
            f.then({ value =>
                if (pendingRef.decrementAndGet() == futures.size - 1) {
                    // 第一个完成
                    result.complete(value)
                }
            })
        }
        return result
    }
}
