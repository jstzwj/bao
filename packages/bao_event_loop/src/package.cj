// bao_event_loop - 事件循环
// 对应 Bun: src/event_loop/
// Bun 使用 libuv 风格的事件循环
package bao_event_loop

import bao_core.*
import bao_threading.*

// ============================================================================
// 事件循环
// 对应 Bun: src/event_loop/event_loop.zig
// ============================================================================

/// 定时器回调
public type TimerCallback = () -> Unit

/// 定时器句柄
public class Timer {
    public let id: Int64
    public let deadline: Int64  // 时间戳 (毫秒)
    public let interval: Int64  // 间隔 (毫秒, 0 = 一次性)
    public let callback: TimerCallback
    public var active: Bool

    public init(id: Int64, deadline: Int64, interval: Int64, callback: TimerCallback) {
        this.id = id
        this.deadline = deadline
        this.interval = interval
        this.callback = callback
        this.active = true
    }
}

/// IO 事件类型
public enum IoEvent {
    | Readable
    | Writable
    | Error
}

/// IO 观察者
public class IoWatcher {
    public let fd: Fd
    public let events: Array<IoEvent>
    public let callback: () -> Unit

    public init(fd: Fd, events: Array<IoEvent>, callback: () -> Unit) {
        this.fd = fd
        this.events = events
        this.callback = callback
    }
}

/// 事件循环
public class EventLoop {
    private var timers: ArrayList<Timer>
    private var ioWatchers: ArrayList<IoWatcher>
    private var nextTimerId: AtomicInt64
    private var running: Bool
    private var pendingCallbacks: ConcurrentLinkedQueue<() -> Unit>
    private let lock = ReentrantMutex()

    public init() {
        timers = ArrayList<Timer>()
        ioWatchers = ArrayList<IoWatcher>()
        nextTimerId = AtomicInt64(1)
        running = false
        pendingCallbacks = ConcurrentLinkedQueue<() -> Unit>()
    }

    /// 启动事件循环
    public func run(): Unit {
        running = true
        while (running) {
            // 1. 处理待执行的回调
            processPendingCallbacks()

            // 2. 处理到期的定时器
            processTimers()

            // 3. 轮询 IO 事件
            pollIo(0)

            // 4. 如果没有定时器也没有 IO 观察者，退出
            synchronized(lock) {
                if (timers.size == 0 && ioWatchers.size == 0) {
                    let cb = pendingCallbacks.remove()
                    if (cb == None) {
                        running = false
                    }
                }
            }
        }
    }

    /// 停止事件循环
    public func stop(): Unit {
        running = false
    }

    /// 设置定时器 (返回定时器 ID)
    public func setTimeout(callback: TimerCallback, delayMs: Int64): Int64 {
        let id = nextTimerId.incrementAndGet()
        let now = currentTimeMillis()
        let timer = Timer(id, now + delayMs, 0, callback)
        synchronized(lock) {
            timers.append(timer)
        }
        return id
    }

    /// 设置间隔定时器
    public func setInterval(callback: TimerCallback, intervalMs: Int64): Int64 {
        let id = nextTimerId.incrementAndGet()
        let now = currentTimeMillis()
        let timer = Timer(id, now + intervalMs, intervalMs, callback)
        synchronized(lock) {
            timers.append(timer)
        }
        return id
    }

    /// 取消定时器
    public func clearTimer(id: Int64): Unit {
        synchronized(lock) {
            for (timer in timers) {
                if (timer.id == id) {
                    timer.active = false
                }
            }
        }
    }

    /// 在事件循环中调度回调
    public func queueCallback(callback: () -> Unit): Unit {
        pendingCallbacks.put(callback)
    }

    /// 注册 IO 观察者
    public func watchIo(fd: Fd, events: Array<IoEvent>, callback: () -> Unit): Unit {
        let watcher = IoWatcher(fd, events, callback)
        synchronized(lock) {
            ioWatchers.append(watcher)
        }
    }

    /// 处理待执行回调
    private func processPendingCallbacks(): Unit {
        while (true) {
            let cb = pendingCallbacks.remove()
            if (cb == None) {
                break
            }
            cb.unwrap()()
        }
    }

    /// 处理定时器
    private func processTimers(): Unit {
        let now = currentTimeMillis()
        synchronized(lock) {
            var toRemove = ArrayList<Int64>()
            for (timer in timers) {
                if (!timer.active) {
                    toRemove.append(timer.id)
                    continue
                }
                if (timer.deadline <= now) {
                    timer.callback()
                    if (timer.interval > 0) {
                        timer.deadline = now + timer.interval
                    } else {
                        toRemove.append(timer.id)
                    }
                }
            }
            // 移除已完成的一次性定时器
            for (id in toRemove) {
                for (i in 0..timers.size) {
                    if (timers[i].id == id) {
                        timers.removeAt(i)
                        break
                    }
                }
            }
        }
    }

    /// 轮询 IO (简化版)
    private func pollIo(timeoutMs: Int64): Unit {
        // TODO: 使用 epoll/kqueue 实现真正的 IO 轮询
        // 当前简化版本不做等待
    }

    /// 获取当前时间 (毫秒)
    private func currentTimeMillis(): Int64 {
        return Int64(std.time.Duration.second) *
            Int64(std.time.DateTime.now().getYear()) // 简化
    }
}
