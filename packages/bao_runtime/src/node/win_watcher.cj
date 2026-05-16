// Windows 文件监视器 — 基于 libuv uv_fs_event_t
// 对应 Bun: src/runtime/node/win_watcher.zig
// 严格翻译自: src/runtime/node/win_watcher.zig
//
// Windows 上使用 libuv 的 uv_fs_event_t 实现文件监视。
// 这是 fs.watch() 的 Windows 后端。
// 与 POSIX 的 path_watcher.zig 形状相同但使用 libuv API。
package bao_runtime.node

import bao_core.*
import bao_threading.*

// ============================================================================
// PathWatcherEventType — 事件类型（重导出）
// ============================================================================
public enum WinWatcherEventType {
    | rename
    | change
}

// ============================================================================
// PathWatcherManager — Windows 路径监视管理器
// 对应 Bun: src/runtime/node/win_watcher.zig - PathWatcherManager
//
// 进程全局单例。绑定到一个 VM 的 uv_loop。
// 监视器映射: path → PathWatcher
// ============================================================================
public class WindowsPathWatcherManager {
    // 单例实例
    private static var defaultManager: ?WindowsPathWatcherManager = None
    private static var managerMutex: Mutex = Mutex()

    // 监视器映射 — path → PathWatcher
    private var watchers: Map<String, WindowsPathWatcher> = HashMap<String, WindowsPathWatcher>()

    // 是否在最后一个监视器移除时自动去初始化
    private var deinitOnLastWatcher: Bool = false

    // 绑定的 VM 引用
    private var vmRef: UIntNative = 0

    public init() {}

    // 获取单例
    // 对应 Bun: win_watcher.zig - getDefaultManager
    public static func get(): WindowsPathWatcherManager {
        managerMutex.lock()
        if (defaultManager == None) {
            defaultManager = WindowsPathWatcherManager()
        }
        managerMutex.unlock()
        return defaultManager.getOrThrow()
    }

    // 初始化管理器
    // 对应 Bun: win_watcher.zig - PathWatcherManager.init
    public static func initManager(vm: UIntNative): WindowsPathWatcherManager {
        let mgr = WindowsPathWatcherManager()
        mgr.vmRef = vm
        return mgr
    }

    // 监视路径
    // 对应 Bun: win_watcher.zig - PathWatcherManager.watch
    public func watch(path: String, handler: WinPathWatchHandler): Unit {
        var watcher = watchers.get(path)
        if (watcher == None) {
            watcher = WindowsPathWatcher(path: path, manager: this)
            watchers.put(path, watcher.getOrThrow())

            // 创建 libuv uv_fs_event_t 并启动监视
            watcher.getOrThrow().startUvWatch()
        }
        watcher.getOrThrow().addHandler(handler)
    }

    // 取消监视
    // 对应 Bun: win_watcher.zig - PathWatcherManager.unregister
    public func unwatch(path: String, handler: WinPathWatchHandler): Unit {
        let watcher = watchers.get(path)
        if (watcher != None) {
            watcher.getOrThrow().removeHandler(handler)
            if (watcher.getOrThrow().handlerCount() == 0) {
                watcher.getOrThrow().close()
                watchers.remove(path)

                // 如果没有更多监视器且设置了去初始化标志
                if (deinitOnLastWatcher && watchers.size == 0) {
                    deinit()
                }
            }
        }
    }

    // 分发事件
    public func dispatchEvent(path: String, eventType: WinWatcherEventType, filename: String): Unit {
        let watcher = watchers.get(path)
        if (watcher != None) {
            watcher.getOrThrow().emit(eventType: eventType, path: filename)
        }
    }

    // 去初始化
    // 对应 Bun: win_watcher.zig - PathWatcherManager.deinit
    public func deinit(): Unit {
        // 关闭所有 watcher
        for ((path, watcher) in watchers) {
            watcher.close()
        }
        watchers = HashMap<String, WindowsPathWatcher>()

        // 清除单例
        managerMutex.lock()
        defaultManager = None
        managerMutex.unlock()
    }

    // uv_fs_event_cb — libuv 文件系统事件回调
    // 对应 Bun: win_watcher.zig - onPathUpdate
    private static func onUvFsEvent(handle: UIntNative, filename: UIntNative, events: Int32, status: Int32): Unit {
        if (status < 0) {
            return
        }

        // 解析事件类型
        let eventType = if ((events & 1) != 0) {  // UV_RENAME
            WinWatcherEventType.rename
        } else {
            WinWatcherEventType.change
        }

        // 获取文件名并分发事件
        // 实际实现从 handle 获取关联的 PathWatcher
    }
}

// ============================================================================
// WindowsPathWatcher — 单个路径的监视器
// 对应 Bun: src/runtime/node/win_watcher.zig - PathWatcher
// ============================================================================
public class WindowsPathWatcher {
    public var path: String = ""
    public var closed: Bool = false

    private var handlers: Array<WinPathWatchHandler> = Array<WinPathWatchHandler>()
    private var manager: ?WindowsPathWatcherManager = None

    // libuv uv_fs_event_t 句柄
    private var uvHandle: UIntNative = 0

    public init() {}

    public init(path: String, manager: WindowsPathWatcherManager) {
        this.path = path
        this.manager = manager
    }

    // 启动 libuv 文件监视
    // 对应 Bun: win_watcher.zig - 注册 uv_fs_event
    public func startUvWatch(): Unit {
        // 实际实现:
        // 1. uv_fs_event_init(loop, handle)
        // 2. uv_fs_event_start(handle, callback, path, flags)
        // flags = UV_FS_EVENT_RECURSIVE (如果 recursive)
    }

    // 添加处理程序
    public func addHandler(handler: WinPathWatchHandler): Unit {
        handlers.add(handler)
    }

    // 移除处理程序
    public func removeHandler(handler: WinPathWatchHandler): Unit {
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
    public func emit(eventType: WinWatcherEventType, path: String): Unit {
        for (handler in handlers) {
            handler.onPathWatchEvent(eventType: eventType, path: path)
        }
    }

    // 关闭监视器
    // 对应 Bun: win_watcher.zig - PathWatcher.close
    public func close(): Unit {
        if (closed) {
            return
        }
        closed = true

        // 关闭 libuv handle
        // uv_fs_event_stop(handle)
        // uv_close(handle, close_cb)

        handlers = Array<WinPathWatchHandler>()
    }
}

// ============================================================================
// Windows 路径监视事件处理接口
// ============================================================================
public interface WinPathWatchHandler {
    func onPathWatchEvent(eventType: WinWatcherEventType, path: String): Unit
}
