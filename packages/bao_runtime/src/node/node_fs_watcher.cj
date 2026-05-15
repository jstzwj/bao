// 文件系统监视器 (FSWatcher)
// 对应 Bun: src/runtime/node/node_fs_watcher.zig
// 严格翻译自: src/runtime/node/node_fs_watcher.zig
package bao_runtime

// ============================================================================
// 文件系统事件类型
// 对应 Bun: src/runtime/node/node_fs_watcher.zig - Event
// ============================================================================
public enum FsWatchEvent {
    rename,
    change
}

// ============================================================================
// 文件系统监视条目
// ============================================================================
public class FsWatchEntry {
    public var event: FsWatchEvent = FsWatchEvent.change
    public var path: String = ""
    public var needsFree: Bool = false

    public init() {}

    public init(event: FsWatchEvent, path: String) {
        this.event = event
        this.path = path
    }
}

// ============================================================================
// FSWatcher — 文件监视器
// 对应 Bun: src/runtime/node/node_fs_watcher.zig - FSWatcher
// ============================================================================
public class FSWatcher {
    public var path: String = ""
    public var encoding: Encoding = Encoding.utf8
    public var recursive: Bool = false
    public var persistent: Bool = true
    public var closed: Bool = false

    // 事件回调
    private var onChange: ?FsWatchCallback = None

    public init() {}

    public init(path: String, encoding: Encoding, recursive: Bool, persistent: Bool) {
        this.path = path
        this.encoding = encoding
        this.recursive = recursive
        this.persistent = persistent
    }

    // 开始监视
    public func start(): Unit {
        if (closed) {
            return
        }
        // 启动底层平台监视器
        PathWatcherManager.watch(path: path, recursive: recursive, callback: onChange)
    }

    // 关闭监视器
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true
        PathWatcherManager.unwatch(path: path)
    }

    // 设置回调
    public func setCallback(callback: FsWatchCallback): Unit {
        onChange = callback
    }
}

// ============================================================================
// 文件监视回调接口
// ============================================================================
public interface FsWatchCallback {
    func onEvent(event: FsWatchEvent, path: String): Unit
}

// ============================================================================
// 路径监视管理器（进程全局）
// 对应 Bun: src/runtime/node/node_fs_watcher.zig / path_watcher.zig - PathWatcherManager
// ============================================================================
public class PathWatcherManager {
    private static var watchers: Map<String, Array<FsWatchCallback>> = HashMap<String, Array<FsWatchCallback>>()

    // 添加监视
    public static func watch(path: String, recursive: Bool, callback: ?FsWatchCallback): Unit {
        if (callback == None) {
            return
        }
        var list = watchers.get(path)
        if (list == None) {
            list = Array<FsWatchCallback>()
        }
        list!.add(callback!)
        watchers.put(path, list!)
    }

    // 移除监视
    public static func unwatch(path: String): Unit {
        watchers.remove(path)
    }
}
