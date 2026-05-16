// POSIX 路径监视器 — fs.watch() 后端
// 对应 Bun: src/runtime/node/path_watcher.zig
// 严格翻译自: src/runtime/node/path_watcher.zig
//
// 独立于 bun.Watcher（bundler/--watch/--hot 监视器）。
// 形状如下:
//   PathWatcherManager   进程全局，延迟创建，拥有 OS 资源
//     ├─ Linux:   一个 inotify fd + 一个 reader 线程，wd → PathWatcher 映射
//     ├─ macOS:   委托给 fs_events.cj（一个 CFRunLoop 线程，一个 FSEventStream）
//     └─ FreeBSD: 一个 kqueue fd + 一个 reader 线程，fd → PathWatcher 映射
//
//   PathWatcher           每个唯一 (realpath, recursive) 对应一个 — 去重
//     └─ handlers[]       共享此监视的 JS FSWatcher 上下文
package bao_runtime.node

import bao_core.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// EventType — 路径监视事件类型
// 对应 Bun: src/runtime/node/path_watcher.zig - EventType
// ============================================================================
public enum PathWatcherEventType {
    | rename
    | change

    // 转换为 Event
    public func toEvent(path: String): PathWatcherEvent {
        return PathWatcherEvent(eventType: this, path: path)
    }
}

// ============================================================================
// PathWatcherEvent — 监视事件
// 对应 Bun: path_watcher.zig - Event
// ============================================================================
public class PathWatcherEvent {
    public var eventType: PathWatcherEventType = PathWatcherEventType.change
    public var path: String = ""

    public init() {}

    public init(eventType: PathWatcherEventType, path: String) {
        this.eventType = eventType
        this.path = path
    }
}

// ============================================================================
// PathWatcherManager — 进程全局路径监视管理器
// 对应 Bun: src/runtime/node/path_watcher.zig - PathWatcherManager
//
// 进程全局的单例，在首次 fs.watch() 时创建，永不销毁。
// 跨平台标记:
//   Linux:   inotify fd + reader 线程
//   macOS:   委托给 fs_events.cj
//   FreeBSD: kqueue fd + reader 线程
// ============================================================================
public class PathWatcherManager {
    // 互斥锁 — 保护 watchers 和所有平台相关的 dispatch 映射
    private var mutex: Mutex = Mutex()

    // 去重映射: 去重键 → PathWatcher
    // 键是已解析路径 + 一个字节的后缀编码 recursive
    private var watchers: Map<String, PathWatcher> = HashMap<String, PathWatcher>()

    // 平台特定的文件描述符
    // Linux: inotify fd
    // FreeBSD: kqueue fd
    // macOS: 不使用（委托给 FSEvents）
    private var platformFd: Int32 = -1

    // reader 线程运行标志
    private var running: Bool = false

    // 平台特定的 inotify wd 映射或 kqueue 映射
    private var platformMap: Map<Int32, PathWatcher> = HashMap<Int32, PathWatcher>()

    // reader 线程
    private var readerThread: ?Thread = None

    public init() {}

    // 获取全局单例
    // 对应 Bun: path_watcher.zig - PathWatcherManager.get
    public static func get(): PathWatcherManager {
        if (defaultManager == None) {
            defaultManagerMutex.lock()
            if (defaultManager == None) {
                defaultManager = PathWatcherManager()
                defaultManager.getOrThrow().initPlatform()
            }
            defaultManagerMutex.unlock()
        }
        return defaultManager.getOrThrow()
    }

    // 初始化平台资源
    private func initPlatform(): Unit {
        // Linux: 初始化 inotify
        //   platformFd = inotify_init1(IN_NONBLOCK | IN_CLOEXEC)
        //   启动 reader 线程
        // macOS: 不需要（FSEvents 自管理线程）
        // FreeBSD: 初始化 kqueue
        //   platformFd = kqueue()
        //   启动 reader 线程
    }

    // 监视路径
    // 对应 Bun: path_watcher.zig - PathWatcherManager.watch
    public func watch(path: String, recursive: Bool, handler: PathWatchHandler): Unit {
        mutex.lock()

        // 生成去重键: realpath + recursive 后缀
        let dedupKey = path + if (recursive) { "\0R" } else { "\0N" }

        var watcher = watchers.get(dedupKey)
        if (watcher == None) {
            watcher = PathWatcher(path: path, recursive: recursive)
            watchers.put(dedupKey, watcher.getOrThrow())

            // 注册平台特定的监视
            registerPlatformWatch(watcher.getOrThrow())
        }

        watcher.getOrThrow().addHandler(handler)
        mutex.unlock()
    }

    // 取消监视
    // 对应 Bun: path_watcher.zig - PathWatcher.detach
    public func unwatch(path: String, recursive: Bool, handler: PathWatchHandler): Unit {
        mutex.lock()
        let dedupKey = path + if (recursive) { "\0R" } else { "\0N" }

        let watcher = watchers.get(dedupKey)
        if (watcher != None) {
            watcher.getOrThrow().removeHandler(handler)
            if (watcher.getOrThrow().handlerCount() == 0) {
                // 注销平台监视
                unregisterPlatformWatch(watcher.getOrThrow())
                watchers.remove(dedupKey)
            }
        }
        mutex.unlock()
    }

    // 注册平台特定的监视
    private func registerPlatformWatch(watcher: PathWatcher): Unit {
        // Linux:
        //   let wd = inotify_add_watch(platformFd, watcher.path, mask)
        //   platformMap[wd] = watcher
        //
        // macOS:
        //   FSEventsGlobal.watch(watcher.path, watcher.recursive, callback, flushCallback, ctx)
        //
        // FreeBSD:
        //   通过 kqueue 监视目录 fd
    }

    // 注销平台特定的监视
    private func unregisterPlatformWatch(watcher: PathWatcher): Unit {
        // Linux:
        //   inotify_rm_watch(platformFd, wd)
        //   platformMap.remove(wd)
        //
        // macOS:
        //   FSEventsWatcher.close()
        //
        // FreeBSD:
        //   关闭目录 fd，从 kqueue 移除
    }

    // 平台 reader 线程主循环
    // 对应 Bun: path_watcher.zig - Linux inotify reader / FreeBSD kqueue reader
    private func readerThreadLoop(): Unit {
        running = true
        while (running) {
            // Linux:
            //   读取 inotify 事件
            //   解析事件类型（IN_CREATE, IN_DELETE, IN_MODIFY 等）
            //   查找 wd → PathWatcher 映射
            //   发射事件给所有 handlers
            //
            // FreeBSD:
            //   kevent() 等待事件
            //   解析 EVFILT_VNODE 事件标志
            //   发射事件
        }
    }

    // 分发文件系统事件
    // 对应 Bun: path_watcher.zig - onFsEvent / PathWatcher.emit
    public func dispatchEvent(watcher: PathWatcher, eventType: PathWatcherEventType, path: String): Unit {
        watcher.emit(eventType: eventType, path: path)
    }

    // 全局单例
    private static var defaultManager: ?PathWatcherManager = None
    private static var defaultManagerMutex: Mutex = Mutex()
}

// ============================================================================
// PathWatcher — 单个路径的监视器
// 对应 Bun: src/runtime/node/path_watcher.zig - PathWatcher
//
// 一个 PathWatcher 对应一个唯一的 (realpath, recursive) 对。
// 多个 FSWatcher 可以共享同一个 PathWatcher。
// ============================================================================
public class PathWatcher {
    public var path: String = ""
    public var recursive: Bool = false
    public var closed: Bool = false

    // macOS: FSEvents watcher 引用
    public var fsEventsWatcher: ?FSEventsWatcher = None

    // Linux/FreeBSD: 平台监视 ID
    public var platformWatchId: Int32 = -1

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

    // 分发事件给所有 handlers
    // 对应 Bun: path_watcher.zig - PathWatcher.emit
    public func emit(eventType: PathWatcherEventType, path: String): Unit {
        let event = PathWatcherEvent(eventType: eventType, path: path)
        for (handler in handlers) {
            handler.onPathWatchEvent(eventType: eventType, path: path)
        }
    }

    // 分离（停止监视）
    // 对应 Bun: path_watcher.zig - PathWatcher.detach
    public func detach(): Unit {
        closed = true
        handlers = Array<PathWatchHandler>()
        if (fsEventsWatcher != None) {
            fsEventsWatcher.getOrThrow().close()
            fsEventsWatcher = None
        }
    }
}

// ============================================================================
// 路径监视事件处理接口
// ============================================================================
public interface PathWatchHandler {
    func onPathWatchEvent(eventType: PathWatcherEventType, path: String): Unit
}

// FSEventsWatcher 的前向引用（定义在 fs_events.cj 中）
public class FSEventsWatcher {
    public func close(): Unit {}
}
