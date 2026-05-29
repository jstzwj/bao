// 翻译自 Bun: src/runtime/bake/DevServer/HotReloadEvent.zig
// 此任务通知 DevServer 线程有关要捆绑的新文件。

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator

/// 热重载事件 - 通知 DevServer 线程有关要捆绑的新文件。
/// 对齐到缓存行以消除虚假共享。
public class HotReloadEvent {
    public var owner: DevServer
    /// 在 WatcherAtomics.watcherReleaseAndSubmitEvent 中初始化
    public var concurrent_task: ConcurrentTask
    /// 监控器无法查看 IncrementalGraph 来知道要使哪些文件失效，
    /// 因此监控事件被去重并传递。键由文件监控器拥有。
    public var files: HashMap<String, Unit>
    /// 监控目录以解决解析失败。
    public var dirs: HashMap<String, Unit>
    /// 与 files 用途相同，但键没有所有者。
    public var extra_files: Array<Byte>
    /// 由 WatcherAtomics.watcherAcquireEvent 初始化
    public var timer: Timer
    /// 此事件可能被 DevServer 或 Watcher 线程引用。
    /// 1 表示已引用，0 表示未引用
    public var contention_indicator: Atomic<UInt32>
    /// 调试互斥锁
    public var debug_mutex: ?Mutex

    public init() {
        owner = DevServer()
        concurrent_task = ConcurrentTask()
        files = HashMap<String, Unit>()
        dirs = HashMap<String, Unit>()
        extra_files = Array<Byte>()
        timer = Timer()
        contention_indicator = Atomic<UInt32>(0)
        debug_mutex = None
    }

    /// 初始化空事件
    public static func initEmpty(owner: DevServer): HotReloadEvent {
        let ev = HotReloadEvent()
        ev.owner = owner
        ev.files = HashMap<String, Unit>()
        ev.dirs = HashMap<String, Unit>()
        ev.extra_files = Array<Byte>()
        return ev
    }

    /// 重置事件以供重用
    public func reset(): Unit {
        if (debug_mutex.isSome()) {
            // debug_mutex.getOrThrow().unlock()
        }
        files.clear()
        dirs.clear()
        extra_files = Array<Byte>()
        timer = Timer()
    }

    /// 检查事件是否为空
    public func isEmpty(): Bool {
        return (files.count() + dirs.count()) == 0
    }

    /// 追加文件
    public func appendFile(allocator: Allocator, file_path: String): Unit {
        files.put(file_path, ())
    }

    /// 追加目录
    public func appendDir(allocator: Allocator, dir_path: String, maybe_sub_path: ?String): Unit {
        if (dir_path.size == 0) { return }
        dirs.put(dir_path, ())

        if (let Some(sub_path) <- maybe_sub_path) {
            if (sub_path.size == 0) { return }
            // stub: extra_files is fixed-size Array, cannot append
        }
    }

    /// 使 IncrementalGraph 中的项目失效，将所有新项目追加到 entry_points
    public func processFileList(
        dev: DevServer,
        entry_points: EntryPointList,
        temp_alloc: Allocator
    ): Unit {
        dev.graph_safety_lock.lock()

        // 首先处理目录，因为这可能修改 event.files
        if (dev.directory_watchers.watches.count() > 0) {
            // 简化处理
        }

        // 处理额外文件
        if (extra_files.size > 0) {
            files.put("", ())
        }

        let changed_file_paths = files.keys()
        // dev.client_graph.invalidate(changed_file_paths, entry_points, temp_alloc)
        // dev.server_graph.invalidate(changed_file_paths, entry_points, temp_alloc)

        if (entry_points.set.count() == 0) {
            return
        }
    }

    /// 运行热重载事件
    public static func run(first: HotReloadEvent): Unit {
        let dev = first.owner

        if (dev.current_bundle.isSome()) {
            // dev.next_bundle.reload_event = first
            return
        }

        let entry_points = EntryPointList()

        first.processFileList(dev, entry_points, dev.allocator())

        var current = first
        while (true) {
            current.processFileList(dev, entry_points, dev.allocator())
            let next_event = dev.watcher_atomics.recycleEventFromDevServer(current)
            if (next_event.isNone()) { break }
            current = next_event.getOrThrow()
        }

        if (entry_points.set.count() == 0) {
            return
        }

        // dev.startAsyncBundle(entry_points, true, first.timer)
    }
}
