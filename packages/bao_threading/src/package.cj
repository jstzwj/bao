// bao_threading - 线程和并发
// 对应 Bun: src/threading/
package bao_threading

import bao_core.*

// ============================================================================
// 线程池
// 对应 Bun: src/threading/ThreadPool.zig
// ============================================================================

/// 线程池任务
public interface Task<T> {
    func execute(): T
}

/// 线程池
public class ThreadPool {
    private var workers: ArrayList<Thread>
    private var taskQueue: ConcurrentLinkedQueue<Task<Unit>>
    private var running: Bool
    private var lock: ReentrantMutex
    private var condVar: Condition

    public init(size: Int64) {
        workers = ArrayList<Thread>()
        taskQueue = ConcurrentLinkedQueue<Task<Unit>>()
        running = true
        lock = ReentrantMutex()
        condVar = Condition()

        for (i in 0..size) {
            let worker = spawn {
                while (true) {
                    let task = taskQueue.remove()
                    if (task != None) {
                        task.unwrap().execute()
                    }
                }
            }
            workers.append(worker)
        }
    }

    /// 提交任务
    public func submit(task: Task<Unit>): Unit {
        taskQueue.put(task)
    }

    /// 提交闭包任务
    public func submit(fn: () -> Unit): Unit {
        taskQueue.put(ClosureTask(fn))
        synchronized(lock) {
            condVar.notify()
        }
    }

    /// 关闭线程池
    public func shutdown(): Unit {
        running = false
        synchronized(lock) {
            condVar.notifyAll()
        }
    }

    /// 获取工作线程数
    public func size(): Int64 {
        return workers.size
    }
}

/// 闭包任务包装
class ClosureTask <: Task<Unit> {
    let fn: () -> Unit
    init(fn: () -> Unit) {
        this.fn = fn
    }
    func execute(): Unit {
        fn()
    }
}

// ============================================================================
// 原子计数器
// ============================================================================

/// 原子 Int64 计数器
public class AtomicInt64 {
    private var value: Int64
    private let mutex = ReentrantMutex()

    public init(initial: Int64) {
        value = initial
    }

    public func get(): Int64 {
        synchronized(mutex) {
            return value
        }
    }

    public func set(newValue: Int64): Unit {
        synchronized(mutex) {
            value = newValue
        }
    }

    public func addAndGet(delta: Int64): Int64 {
        synchronized(mutex) {
            value += delta
            return value
        }
    }

    public func incrementAndGet(): Int64 {
        return addAndGet(1)
    }

    public func decrementAndGet(): Int64 {
        return addAndGet(-1)
    }

    public func compareAndSwap(expected: Int64, newValue: Int64): Bool {
        synchronized(mutex) {
            if (value == expected) {
                value = newValue
                return true
            }
            return false
        }
    }
}

// ============================================================================
// Once - 一次性执行
// 对应 Rust: std::sync::Once
// ============================================================================

/// 确保函数只执行一次
public class Once {
    private var done: Bool
    private let mutex = ReentrantMutex()

    public init() {
        done = false
    }

    /// 执行一次
    public func callOnce(fn: () -> Unit): Unit {
        synchronized(mutex) {
            if (!done) {
                fn()
                done = true
            }
        }
    }

    /// 是否已执行
    public func isDone(): Bool {
        synchronized(mutex) {
            return done
        }
    }
}
