// Windows 文件监视器
// 对应 Bun: src/runtime/node/win_watcher.zig
// 严格翻译自: src/runtime/node/win_watcher.zig
package bao_runtime

// ============================================================================
// Windows 路径监视管理器
// 对应 Bun: src/runtime/node/win_watcher.zig - PathWatcherManager
// ============================================================================
public class WindowsPathWatcherManager {
    private static var defaultManager: ?WindowsPathWatcherManager = None

    private var watchers: Map<String, WindowsPathWatcher> = HashMap<String, WindowsPathWatcher>()

    public init() {}

    // 获取单例
    public static func get(): WindowsPathWatcherManager {
        if (defaultManager == None) {
            defaultManager = WindowsPathWatcherManager()
        }
        return defaultManager!
    }

    // 监视路径
    public func watch(path: String, handler: PathWatchHandler): Unit {
        var watcher = watchers.get(path)
        if (watcher == None) {
            watcher = WindowsPathWatcher(path: path)
            watchers.put(path, watcher!)
        }
        watcher!.addHandler(handler)
    }

    // 取消监视
    public func unwatch(path: String, handler: PathWatchHandler): Unit {
        let watcher = watchers.get(path)
        if (watcher != None) {
            watcher!.removeHandler(handler)
        }
    }
}

// ============================================================================
// Windows 路径监视器
// ============================================================================
public class WindowsPathWatcher {
    public var path: String = ""

    private var handlers: Array<PathWatchHandler> = Array<PathWatchHandler>()

    public init() {}

    public init(path: String) {
        this.path = path
    }

    public func addHandler(handler: PathWatchHandler): Unit {
        handlers.add(handler)
    }

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

    public func emit(eventType: String, path: String): Unit {
        for (handler in handlers) {
            handler.onPathWatchEvent(eventType: eventType, path: path)
        }
    }
}
