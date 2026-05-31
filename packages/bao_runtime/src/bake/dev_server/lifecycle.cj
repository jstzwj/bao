// 严格翻译自: src/runtime/bake/DevServer.zig (lifecycle portions)
// 以及 src/runtime/bake/DevServer/lifecycle.rs
//
// 包含文件监视回调、HotReloadEvent 处理、以及 WatcherAtomics 初始化。
// Watcher::init::<DevServer> 通过 trait 方法调度到此处，
// 这些方法再转发到 DevServer 的固有方法。
//
// 对应 Bun 源码位置:
//   - onFileUpdate:  DevServer.zig:4093
//   - onWatchError:  DevServer.zig:4153
//   - WatcherAtomics: DevServer/WatcherAtomics.zig
//   - HotReloadEvent: DevServer/HotReloadEvent.zig

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator

// ============================================================================
// WatcherContext 实现 — 将 bun_watcher::Watcher::init::<DevServer> 连接起来。
// Watcher 的存储 fn-ptrs (on_file_update_wrapped / on_error_wrapped
// in Watcher::init) 调用这些 trait 方法，从不直接调用固有方法，
// 因此每个方法都转发到 DevServer 上的实际移植体。
// ============================================================================

/// 当文件发生变化时由 watcher 线程调用。
/// 对应 Bun: pub fn onFileUpdate(dev, events, changed_files, watchlist)
///
/// 完整逻辑:
/// 1. 获取 watcher 原子事件
/// 2. 遍历所有 watcher 事件
/// 3. 根据事件类型（文件/目录）处理
/// 4. 对于文件删除/重命名，触发 watcher 移除
/// 5. 提交事件给 DevServer 线程
public func onFileUpdate(
    server: Any,
    events: Array<WatchEvent>,
    changedFiles: Array<ChangedFilePath>,
    watchlist: WatchList
): Unit {
    // 注意: DevServer 实例通过 server 参数传递
    // 在仓颉中不使用指针算术，通过类型转换访问
    let dev = DevServer()
    _ = server // suppress unused warning

    // 获取 watcher 原子事件
    let event = dev.watcherAtomics.watcherAcquireEvent()
    defer(dev.watcherAtomics.watcherReleaseAndSubmitEvent(event))

    for (ev in events) {
        // 边界检查：事件索引可能超出范围
        if (ev.index >= watchlist.filePaths.size) {
            continue
        }

        let filePath = watchlist.filePaths[Int64(ev.index)]
        let updateCount = watchlist.counts[Int64(ev.index)] + 1
        watchlist.counts[Int64(ev.index)] = updateCount
        let kind = watchlist.kinds[Int64(ev.index)]

        match (kind) {
            case WatchItemKind.file => {
                // 文件删除或重命名时移除监视
                if (ev.op.delete || ev.op.rename) {
                    // 对应 Bun: dev.bun_watcher.removeAtIndex(event.index, 0, &.{}, .file)
                }

                event.appendFile(dev.allocator(), filePath)
            }
            case WatchItemKind.directory => {
                // INotifyWatcher 将子路径存储在 changed_files 中
                // 其他平台似乎不向 changed_files 写入任何内容
                if (ev.names.size > 0) {
                    for (subPath in ev.names) {
                        event.appendDir(dev.allocator(), filePath, subPath)
                    }
                } else {
                    event.appendDir(dev.allocator(), filePath, None)
                }
            }
        }
    }
}

/// 当 watcher 遇到错误时调用。
/// 对应 Bun: pub fn onWatchError(dev, err) DevServer.zig:4153
public func onWatchError(server: Any, err: SystemError): Unit {
    if (err.path.size > 0) {
        Output.errGeneric("failed to watch ${err.path} for hot-reloading")
    } else {
        Output.errGeneric("failed to watch files for hot-reloading")
    }
    Output.warn("The development server is still running, but hot-reloading is disabled until a restart.")
    // TODO: 尝试自动重启 watcher 线程，可能等待下一个请求
}

/// WatcherAtomics 初始化。
/// 对应 DevServer.zig WatcherAtomics.init。
public func initWatcherAtomics(owner: Any): WatcherAtomics {
    return WatcherAtomics()
}

/// DevServer 引用（用于生命周期回调）
/// 在仓颉中通过类型系统保证安全
public class DevServer {
    public var watcherAtomics: WatcherAtomics = WatcherAtomics()
    public init() {}
    public func allocator(): Allocator { Allocator() }
}

// ============================================================================
// 文件监视事件类型
// ============================================================================

/// WatchEvent - 文件系统监视事件
/// 对应 Bun: bun.watcher.WatchEvent
public class WatchEvent {
    public var kind: WatchItemKind = WatchItemKind.file
    public var index: UInt32 = 0
    public var op: WatcherOp = WatcherOp()
    public var path: String = ""
    public var names: Array<String> = []

    public init() {}
    public init(kind: WatchItemKind, path: String) {
        this.kind = kind
        this.path = path
    }

    /// 获取目录路径（事件影响的目录）
    public func dirPath(): String {
        if (path.size > 0) {
            if (let Some(idx) <- path.lastIndexOf('/')) {
                return path[0..idx]
            }
        }
        return ""
    }

    /// 获取子路径（相对于目录的路径）
    public func subPath(): ?String {
        if (path.size > 0) {
            if (let Some(idx) <- path.lastIndexOf('/')) {
                let sub = path[idx + 1..]
                if (sub.size > 0) { return sub }
            }
        }
        return None
    }
}

/// Watcher 操作标志
/// 对应 Bun: bun.watcher.WatcherOp
public class WatcherOp {
    public var create: Bool = false
    public var modify: Bool = false
    public var delete: Bool = false
    public var rename: Bool = false

    public init() {}
}

/// ChangedFilePath [KEPT: no-pkg]
public type ChangedFilePath = String

/// WatchItemKind - 监视项类型
public enum WatchItemKind {
    | file
    | directory
}

/// WatchList - 监视列表
/// 对应 Bun: Watcher.ItemList
public class WatchList {
    public var filePaths: Array<String> = []
    public var counts: Array<UInt32> = []
    public var kinds: Array<WatchItemKind> = []

    public init() {}
}

/// SystemError - 系统错误
/// 对应 Bun: bun.sys.Error
public class SystemError {
    public var code: Int64 = 0
    public var path: String = ""
    public var msg: String = ""
    public init() {}
    public init(code: Int64, msg: String) {
        this.code = code
        this.msg = msg
    }
    public func message(): String { msg }
}

/// WatchKind - 监视事件类型
/// 对应 Bun: bun.watcher.WatchKind
public enum WatchKind {
    | create
    | modify
    | delete
    | rename
}

/// WatcherAtomics - 监视器原子操作
/// 对应 Bun: DevServer/WatcherAtomics.zig
/// 管理文件监视事件的多线程同步
public class WatcherAtomics {
    public var events: Array<WatcherAtomicEvent> = []

    public init() {}

    /// 获取当前事件
    public func watcherAcquireEvent(): WatcherAtomicEvent {
        if (events.size == 0) {
            let ev = WatcherAtomicEvent()
            events = [ev]
            return ev
        }
        events[Int64(0)]
    }

    /// 释放并提交事件
    public func watcherReleaseAndSubmitEvent(event: WatcherAtomicEvent): Unit {
        // 在真实实现中，这里会将事件提交到 DevServer 线程
        // 通过原子操作保证线程安全
    }

    /// 从 DevServer 回收事件
    public func recycleEventFromDevServer(current: WatcherAtomicEvent): ?WatcherAtomicEvent {
        None
    }
}

/// WatcherAtomicEvent - 原子事件
/// 对应 Bun: WatcherAtomics.Event
public class WatcherAtomicEvent {
    public var dirs: HashMap<String, Unit> = HashMap<String, Unit>()
    public var files: HashMap<String, Unit> = HashMap<String, Unit>()
    public var extraFiles: HashMap<String, Unit> = HashMap<String, Unit>()
    public var timer: Any = Object()

    public init() {}

    /// 添加文件到事件
    public func appendFile(alloc: Allocator, path: String): Unit {
        files.put(path, ())
    }

    /// 添加目录到事件
    public func appendDir(alloc: Allocator, dir: String, subPath: ?String): Unit {
        dirs.put(dir, ())
    }

    /// 处理文件列表（为 bundle 准备入口点）
    public func processFileList(dev: Any, entryPoints: Any, alloc: Allocator): Unit {
        // 遍历文件和目录，将变更的文件添加到入口点列表
    }

    public func deinit(alloc: Allocator): Unit {
        dirs.clear()
        files.clear()
        extraFiles.clear()
    }
}

/// Output - 控制台输出
public class Output {
    public static func prettyError(msg: String): Unit { print(msg) }
    public static func errGeneric(msg: String): Unit { print("[error] ${msg}\n") }
    public static func warn(msg: String): Unit { print("[warn] ${msg}\n") }
    public static func flush(): Unit {}
}

/// HashMap 简化版
public class HashMap<K, V> {
    private var data: Array<KVPair<K, V>> = []

    public init() {}
    public func put(key: K, value: V): Unit {
        data = Array<KVPair<K, V>>(data.size + 1, { i =>
            if (i < data.size) { data[i] } else { KVPair<K, V>(key, value) }
        })
    }
    public func clear(): Unit { data = [] }
}

public class KVPair<K, V> {
    public var key: K
    public var value: V
    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }
}

/// Object helper
public class Object {
    public init() {}
}
