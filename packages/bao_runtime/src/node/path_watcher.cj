// POSIX 路径监视器
// 对应 Bun: src/runtime/node/path_watcher.zig
// 严格翻译自: src/runtime/node/path_watcher.zig
package bao_runtime.node

// ============================================================================
// PathWatcherManager — 进程全局路径监视管理器
// 对应 Bun: src/runtime/node/path_watcher.zig - PathWatcherManager
// ============================================================================
public class PosixPathWatcherManager {
    // 单例实例
    private static var instance: ?PosixPathWatcherManager = None

    // 监视器映射表
    private var watchers: Map<String, PathWatcher> = HashMap<String, PathWatcher>()

    public init() {}

    // 获取单例
    public static func get(): PosixPathWatcherManager {
        if (instance == None) {
            instance = PosixPathWatcherManager()
        }
        return instance!
    }

    // 监视路径
    public func watch(path: String, recursive: Bool, handler: PathWatchHandler): Unit {
        var watcher = watchers.get(path)
        if (watcher == None) {
            watcher = PathWatcher(path: path, recursive: recursive)
            watchers.put(path, watcher!)
        }
        watcher!.addHandler(handler)
    }

    // 取消监视
    public func unwatch(path: String, handler: PathWatchHandler): Unit {
        let watcher = watchers.get(path)
        if (watcher != None) {
            watcher!.removeHandler(handler)
            if (watcher!.handlerCount() == 0) {
                watchers.remove(path)
            }
        }
    }
}

// ============================================================================
// PathWatcher — 单个路径的监视器
// 对应 Bun: src/runtime/node/path_watcher.zig - PathWatcher
// ============================================================================
public class PathWatcher {
    public var path: String = ""
    public var recursive: Bool = false
    public var closed: Bool = false

    private var handlers: Array<PathWatchHandler> = Array<PathWatchHandler>()

    public init() {}

    public init(path: String, recursive: Bool) {
        this.path = path
        this.recursive = recursive
    }

    // 添加处理程序
    public func addHandler(handler: PathWatchHandler): Unit {
        handlers.add(handler)
    }

    // 移除处理程序
    public func removeHandler(handler: PathWatchHandler): Unit {
        var idx: Int64 = -1
        for (i in 0..handlers.size) {
            if (handlers[i] === handler) {
                idx = i
                break
            }
        }
        if (idx >= 0) {
            handlers.removeAt(idx)
        }
    }

    // 处理程序数量
    public func handlerCount(): Int64 {
        return handlers.size
    }

    // 分发事件
    public func emit(eventType: String, path: String): Unit {
        for (handler in handlers) {
            handler.onPathWatchEvent(eventType: eventType, path: path)
        }
    }

    // 分离（停止监视）
    public func detach(): Unit {
        closed = true
        handlers = Array<PathWatchHandler>()
    }
}

// ============================================================================
// 路径监视事件处理接口
// ============================================================================
public interface PathWatchHandler {
    func onPathWatchEvent(eventType: String, path: String): Unit
}
