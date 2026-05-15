// 文件系统 Stat 监视器
// 对应 Bun: src/runtime/node/node_fs_stat_watcher.zig
// 严格翻译自: src/runtime/node/node_fs_stat_watcher.zig
package bao_runtime

// ============================================================================
// Stat 监视器事件
// 对应 Bun: src/runtime/node/node_fs_stat_watcher.zig
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
// Stat 监视器
// 对应 Bun: src/runtime/node/node_fs_stat_watcher.zig - StatWatcher
// ============================================================================
public class StatWatcher {
    public var path: String = ""
    public var interval: Int32 = 5007  // 默认 5.007 秒（与 Node.js 一致）
    public var persistent: Bool = true
    public var bigint: Bool = false
    public var closed: Bool = false

    private var lastStats: ?Stats = None

    public init() {}

    public init(path: String, interval: Int32, persistent: Bool, bigint: Bool) {
        this.path = path
        this.interval = interval
        this.persistent = persistent
        this.bigint = bigint
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
    public func stop(): Unit {
        closed = true
    }

    // 检查变化
    public func check(): ?StatChangeEvent {
        if (closed) {
            return None
        }

        let currentStats = System.stat(path)
        if (currentStats == None) {
            return None
        }

        if (lastStats == None) {
            lastStats = currentStats
            return None
        }

        let prev = lastStats!
        let curr = currentStats!

        // 检查是否有变化
        if (prev.mtimeMs != curr.mtimeMs || prev.size != curr.size) {
            lastStats = curr
            return StatChangeEvent(path: path, current: curr, previous: prev)
        }

        return None
    }
}

// ============================================================================
// Stat 监视器调度器
// 对应 Bun: src/runtime/node/node_fs_stat_watcher.zig - StatWatcherScheduler
// ============================================================================
public class StatWatcherScheduler {
    private var watchers: Array<StatWatcher> = Array<StatWatcher>()
    private var running: Bool = false

    public init() {}

    // 添加监视器
    public func append(watcher: StatWatcher): Unit {
        watchers.add(watcher)
    }

    // 移除监视器
    public func remove(watcher: StatWatcher): Unit {
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
    }
}
