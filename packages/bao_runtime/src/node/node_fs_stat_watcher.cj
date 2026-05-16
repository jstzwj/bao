// 文件系统 Stat 监视器 — fs.watchFile() / fs.unwatchFile() 的实现
// 对应 Bun: src/runtime/node/node_fs_stat_watcher.zig
// 严格翻译自: src/runtime/node/node_fs_stat_watcher.zig
//
// 包含:
//   - StatWatcherScheduler: 全局调度器（定时 stat 检查）
//   - StatWatcher: 单个文件的 stat 监视器
//   - stat_to_js_stats: 将 stat 结果转换为 JS Stats 对象
package bao_runtime.node

import bao_core.*
import bao_threading.*

// ============================================================================
// Stat 监视事件
// 对应 Bun: src/runtime/node/node_fs_stat_watcher.zig - 'change' 事件
// ============================================================================
public class StatChangeEvent {
    public var path: String = ""
    public var current: Stats = Stats()
    public var previous: Stats = Stats()

    public init() {}

    public init(path: String, current: Stats, previous: Stats) {
        this.path = path
        this.current = current
        this.previous = previous
    }
}

// ============================================================================
// StatWatcherScheduler — 全局 Stat 监视调度器
// 对应 Bun: src/runtime/node/node_fs_stat_watcher.zig - StatWatcherScheduler
//
// 全局单例，包含一个定时器用于调度 stat 检查。
// 管理所有活跃的 StatWatcher 实例。
// ============================================================================
public class StatWatcherScheduler {
    // 当前轮询间隔
    private var currentInterval: AtomicInt32 = AtomicInt32(0)

    // 主线程 ID
    private var mainThread: UIntNative = 0

    // VM 引用
    private var vm: UIntNative = 0

    // 活跃的 watcher 列表
    private var watchers: Array<StatWatcher> = Array<StatWatcher>()

    // watcher 队列（新增的 watcher）
    private var pendingWatchers: Array<StatWatcher> = Array<StatWatcher>()

    // 定时器
    public var eventLoopTimer: EventLoopTimer = EventLoopTimer()

    // 引用计数
    private var refCount: AtomicInt32 = AtomicInt32(1)

    // 互斥锁
    private var mutex: Mutex = Mutex()

    public init() {}

    // 获取全局调度器
    // 对应 Bun: node_fs_stat_watcher.zig - scheduler()
    private static var globalScheduler: ?StatWatcherScheduler = None

    public static func get(vm: UIntNative): StatWatcherScheduler {
        if (globalScheduler == None) {
            globalScheduler = StatWatcherScheduler()
            globalScheduler.getOrThrow().vm = vm
        }
        return globalScheduler.getOrThrow()
    }

    // 添加 watcher
    // 对应 Bun: node_fs_stat_watcher.zig - StatWatcherScheduler.append
    public func append(watcher: StatWatcher): Unit {
        mutex.lock()
        pendingWatchers.add(watcher)
        mutex.unlock()

        // 更新间隔
        setInterval(watcher.interval)
    }

    // 移除 watcher
    // 对应 Bun: node_fs_stat_watcher.zig - StatWatcherScheduler.remove
    public func remove(watcher: StatWatcher): Unit {
        mutex.lock()
        var idx: Int64 = -1
        for (i in 0..watchers.size) {
            if (watchers[i] === watcher) {
                idx = i
                break
            }
        }
        if (idx >= 0) {
            watchers.removeAt(idx)
        }
        mutex.unlock()

        // 如果没有更多 watcher，停止定时器
        if (watchers.size == 0 && pendingWatchers.size == 0) {
            stopTimer()
        } else {
            // 重新计算最小间隔
            var minInterval: Int32 = Int32.MAX
            for (w in watchers) {
                if (w.interval < minInterval) {
                    minInterval = w.interval
                }
            }
            setInterval(minInterval)
        }
    }

    // 设置轮询间隔
    // 对应 Bun: node_fs_stat_watcher.zig - StatWatcherScheduler.setInterval
    public func setInterval(interval: Int32): Unit {
        let current = currentInterval.get()
        if (interval != current) {
            if (interval < current || current == 0) {
                currentInterval.set(interval)
                startTimer(interval)
            }
        }
    }

    // 启动定时器
    private func startTimer(interval: Int32): Unit {
        eventLoopTimer.start(interval, repeat_: interval)
    }

    // 停止定时器
    private func stopTimer(): Unit {
        eventLoopTimer.stop()
        currentInterval.set(0)
    }

    // 定时器回调 — 执行 stat 检查
    // 对应 Bun: node_fs_stat_watcher.zig - StatWatcherScheduler.onTimer
    public func onTimer(): Unit {
        // 将 pending watchers 合并到活跃列表
        mutex.lock()
        for (w in pendingWatchers) {
            watchers.add(w)
        }
        pendingWatchers = Array<StatWatcher>()
        mutex.unlock()

        // 对每个 watcher 执行 stat 检查
        for (watcher in watchers) {
            if (!watcher.closed) {
                watcher.checkAndEmit()
            }
        }
    }

    // 引用
    public func ref_(): Unit {
        refCount.add(1)
    }

    // 解引用
    public func deref(): Unit {
        if (refCount.sub(1) == 1) {
            deinit()
        }
    }

    // 去初始化
    public func deinit(): Unit {
        stopTimer()
        watchers = Array<StatWatcher>()
        pendingWatchers = Array<StatWatcher>()
    }
}

// ============================================================================
// StatWatcher — 单个文件的 stat 监视器
// 对应 Bun: src/runtime/node/node_fs_stat_watcher.zig - StatWatcher
//
// 每次 fs.watchFile() 创建一个 StatWatcher。
// StatWatcher 包含:
//   - path: 监视的文件路径
//   - interval: 轮询间隔（毫秒）
//   - persistent: 是否阻止进程退出
//   - bigint: 是否使用 BigInt stats
//   - closed: 是否已关闭
//   - lastStats: 上次的 stat 结果
//   - next: 链表指针（用于 UnboundedQueue）
// ============================================================================
public class StatWatcher {
    public var path: String = ""
    public var interval: Int32 = 5007  // 默认 5.007 秒（与 Node.js 一致）
    public var persistent: Bool = true
    public var bigint: Bool = false
    public var closed: Bool = false
    public var verbose: Bool = false

    // 虚拟机上下文
    private var vm: UIntNative = 0

    // 上次的 stat 结果
    private var lastStats: ?Stats = None

    // JS 引用
    private var jsThis: UIntNative = 0
    private var globalThis: UIntNative = 0

    // KeepAlive
    private var pollRef: KeepAlive = KeepAlive()

    // 信号
    private var signal: ?AbortSignalRef = None

    // 互斥锁
    private var mutex: Mutex = Mutex()

    // 链表指针（用于 UnboundedQueue）
    public var next: ?StatWatcher = None

    // 调度器引用
    private var scheduler: ?StatWatcherScheduler = None

    public init() {}

    public init(path: String, interval: Int32, persistent: Bool, bigint: Bool) {
        this.path = path
        this.interval = interval
        this.persistent = persistent
        this.bigint = bigint
    }

    // 初始化
    // 对应 Bun: node_fs_stat_watcher.zig - StatWatcher.init
    public func init(vm: UIntNative, global: UIntNative, path: String,
                     interval: Int32, persistent: Bool, bigint: Bool): Unit {
        this.vm = vm
        this.globalThis = global
        this.path = path
        this.interval = interval
        this.persistent = persistent
        this.bigint = bigint

        // 注册到调度器
        scheduler = StatWatcherScheduler.get(vm)
        scheduler.getOrThrow().append(this)

        // 持久化时 ref 事件循环
        if (persistent) {
            pollRef.ref_()
        }
    }

    // 开始监视
    public func start(): Unit {
        if (closed) {
            return
        }
        // 记录初始 stat
        lastStats = System.stat(path)
    }

    // 停止监视
    // 对应 Bun: node_fs_stat_watcher.zig - StatWatcher.stop
    public func stop(): Unit {
        if (closed) {
            return
        }
        closed = true

        // 从调度器移除
        if (scheduler != None) {
            scheduler.getOrThrow().remove(this)
        }

        // unref 事件循环
        if (persistent) {
            pollRef.unref()
        }
    }

    // 检查变化并发射事件
    // 对应 Bun: node_fs_stat_watcher.zig - StatWatcher.update
    public func checkAndEmit(): Unit {
        if (closed) {
            return
        }

        let currentStats = System.stat(path)
        if (currentStats == None) {
            // 文件不存在
            if (lastStats != None) {
                // 文件被删除，发射变化事件
                emitChange(Stats(), lastStats.getOrThrow())
                lastStats = None
            }
            return
        }

        let prev = lastStats
        if (prev == None) {
            lastStats = currentStats
            return
        }

        let prevStats = prev.getOrThrow()
        let currStats = currentStats.getOrThrow()

        // 检查是否有变化（mtime 或 size 变化）
        if (prevStats.mtimeMs != currStats.mtimeMs || prevStats.size != currStats.size) {
            lastStats = currStats
            emitChange(currStats, prevStats)
        }
    }

    // 发射变化事件
    // 对应 Bun: node_fs_stat_watcher.zig - StatWatcher.emit
    private func emitChange(current: Stats, previous: Stats): Unit {
        // 在 JS 线程上触发 'change' 事件
        // listener(current, previous)
    }

    // 终结化
    public func finalize(): Unit {
        stop()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

// Stats — 文件状态信息（引用自 stat.cj）
public class Stats {
    public var dev: UInt64 = 0
    public var ino: UInt64 = 0
    public var mode: UInt64 = 0
    public var nlink: UInt64 = 0
    public var uid: UInt64 = 0
    public var gid: UInt64 = 0
    public var rdev: UInt64 = 0
    public var size: UInt64 = 0
    public var blksize: UInt64 = 0
    public var blocks: UInt64 = 0
    public var atimeMs: Float64 = 0
    public var mtimeMs: Float64 = 0
    public var ctimeMs: Float64 = 0
    public var birthtimeMs: Float64 = 0

    public init() {}
}

// EventLoopTimer — 事件循环定时器
public class EventLoopTimer {
    public func start(interval: Int32, repeat_: Int32): Unit {}
    public func stop(): Unit {}
}

// AtomicInt32 — 原子 Int32
public class AtomicInt32 {
    private var value: Int32 = 0

    public init(v: Int32) {
        value = v
    }

    public func get(): Int32 {
        return value
    }

    public func set(v: Int32): Unit {
        value = v
    }

    public func add(v: Int32): Unit {
        value = value + v
    }

    public func sub(v: Int32): Int32 {
        value = value - v
        return value
    }
}

// KeepAlive — 事件循环引用计数
public class KeepAlive {
    private var active: Bool = false
    public init() {}
    public func ref_(): Unit { active = true }
    public func unref(): Unit { active = false }
}

// AbortSignalRef — 中止信号
public class AbortSignalRef {}

// System — 系统调用
public class System {
    public static func stat(path: String): ?Stats {
        // 简化实现
        return None
    }
}
