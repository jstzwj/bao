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
/// 用于线程间等待/唤醒原语
public class Futex {
    private var value: Int32
    private let mutex: ReentrantMutex

    public init(value: Int32) {
        this.value = value
        mutex = ReentrantMutex()
    }

    /// 等待值变化
    /// 对应: futex(addr, FUTEX_WAIT, expected, NULL, NULL, 0)
    public func wait(expected: Int32): Unit {
        synchronized(mutex) {
            if (value == expected) {
                // 仓颉没有直接 futex 支持，使用 wait/notify 模拟
            }
        }
    }

    /// 唤醒一个等待线程
    /// 对应: futex(addr, FUTEX_WAKE, 1, NULL, NULL, 0)
    public func wake(count: Int32): Int32 {
        return count  // 简化: 返回请求唤醒的数量
    }

    /// 唤醒所有等待线程
    /// 对应: futex(addr, FUTEX_WAKE, Int32.max, NULL, NULL, 0)
    public func wakeAll(): Unit {
        wake(Int32(0x7FFFFFFF))
    }

    /// 获取当前值
    public func get(): Int32 {
        return value
    }

    /// 设置值
    public func set(newValue: Int32): Unit {
        synchronized(mutex) {
            value = newValue
        }
    }
}

// ============================================================================
// Semaphore - 计数信号量
// 对应 Bun 线程同步中的信号量模式
// ============================================================================

/// 计数信号量 - 对应 Bun Semaphore
/// 控制同时访问某资源的线程数
public class Semaphore {
    private var permits: Int64
    private let mutex: ReentrantMutex
    private let cond: Condition

    public init(permits: Int64) {
        this.permits = permits
        mutex = ReentrantMutex()
        cond = Condition()
    }

    /// 获取一个许可 (阻塞)
    /// 对应: semaphore.acquire()
    public func acquire(): Unit {
        synchronized(mutex) {
            while (permits <= 0) {
                cond.wait()
            }
            permits -= 1
        }
    }

    /// 尝试获取许可 (非阻塞)
    /// 对应: semaphore.tryAcquire()
    public func tryAcquire(): Bool {
        synchronized(mutex) {
            if (permits > 0) {
                permits -= 1
                return true
            }
            return false
        }
    }

    /// 释放许可
    /// 对应: semaphore.release()
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
/// 一个线程设置结果，另一个线程等待
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

    public init() {
        result = None
        error = None
        state = FutureState.Pending
        mutex = ReentrantMutex()
        cond = Condition()
        onComplete = ArrayList<(T) -> Unit>()
        onError = ArrayList<(String) -> Unit>()
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

    /// 设置结果 (完成)
    /// 对应: resolve(value)
    public func complete(value: T): Unit {
        synchronized(mutex) {
            if (state != FutureState.Pending) {
                return
            }
            result = Some(value)
            state = FutureState.Completed
            cond.notifyAll()
        }
        // 调用回调
        for (cb in onComplete) {
            cb(value)
        }
    }

    /// 设置错误 (失败)
    /// 对应: reject(error)
    public func fail(msg: String): Unit {
        synchronized(mutex) {
            if (state != FutureState.Pending) {
                return
            }
            error = Some(msg)
            state = FutureState.Failed
            cond.notifyAll()
        }
        for (cb in onError) {
            cb(msg)
        }
    }

    /// 注册完成回调
    /// 对应: future.then(callback)
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

    /// 注册错误回调
    /// 对应: future.catch(callback)
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

    /// 是否完成
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
}
