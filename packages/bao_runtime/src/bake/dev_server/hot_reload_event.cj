// 翻译自 Bun: src/runtime/bake/DevServer/HotReloadEvent.zig
// 此任务通知 DevServer 线程有关要捆绑的新文件。

package bao_runtime.bake.dev_server

/// 热重载事件 - 通知 DevServer 线程有关要捆绑的新文件。
/// 对齐到缓存行以消除虚假共享。
public class HotReloadEvent {
    public var owner: DevServer
    /// 在 WatcherAtomics.watcherReleaseAndSubmitEvent 中初始化
    public var concurrent_task: ConcurrentTask
    /// 监控器无法查看 IncrementalGraph 来知道要使哪些文件失效，
    /// 因此监控事件被去重并传递。键由文件监控器拥有。
    public var files: StringArrayHashMapUnmanaged<Unit>
    /// 监控目录以解决解析失败。
    public var dirs: StringArrayHashMapUnmanaged<Unit>
    /// 与 files 用途相同，但键没有所有者。
    public var extra_files: ArrayListUnmanaged<Byte>
    /// 由 WatcherAtomics.watcherAcquireEvent 初始化
    public var timer: Timer
    /// 此事件可能被 DevServer 或 Watcher 线程引用。
    /// 1 表示已引用，0 表示未引用
    public var contention_indicator: Atomic<UInt32>
    /// 调试互斥锁
    public var debug_mutex: ?Mutex = None

    /// 初始化空事件
    public static func initEmpty(owner: DevServer): HotReloadEvent {
        return HotReloadEvent(
            owner: owner,
            concurrent_task: ConcurrentTask(),
            files: StringArrayHashMapUnmanaged<Unit>.empty,
            dirs: StringArrayHashMapUnmanaged<Unit>.empty,
            timer: Timer(),
            contention_indicator: Atomic<UInt32>(0),
            debug_mutex: None,
            extra_files: ArrayListUnmanaged<Byte>.empty,
        )
    }

    /// 重置事件以供重用
    public func reset(): Unit {
        if (debug_mutex != None) {
            debug_mutex.getOrThrow().unlock()
        }
        files.clearRetainingCapacity()
        dirs.clearRetainingCapacity()
        extra_files.clearRetainingCapacity()
        timer = Timer()
    }

    /// 检查事件是否为空
    public func isEmpty(): Bool {
        return (files.count() + dirs.count()) == 0
    }

    /// 追加文件
    public func appendFile(allocator: Allocator, file_path: String): Unit {
        files.getOrPut(allocator, file_path)
    }

    /// 追加目录
    public func appendDir(allocator: Allocator, dir_path: String, maybe_sub_path: ?String): Unit {
        if (dir_path.length == 0) { return }
        dirs.getOrPut(allocator, dir_path)

        let sub_path = maybe_sub_path ?? return
        if (sub_path.length == 0) { return }

        let platform = bun.path.Platform.auto
        let ends_with_sep = platform.isSeparator(dir_path[dir_path.length - 1])
        let starts_with_sep = platform.isSeparator(sub_path[0])
        let sep_offset: Int32 = if (ends_with_sep && starts_with_sep) -1 else 1

        extra_files.ensureUnusedCapacity(allocator, Int32(dir_path.length + sub_path.length) + sep_offset + 1)
        if (ends_with_sep) {
            extra_files.appendSliceAssumeCapacity(dir_path.slice(0, dir_path.length - 1))
        } else {
            extra_files.appendSliceAssumeCapacity(dir_path)
        }
        extra_files.appendAssumeCapacity(platform.separator().toByte())
        extra_files.appendSliceAssumeCapacity(sub_path)
        extra_files.appendAssumeCapacity(0)
    }

    /// 使 IncrementalGraph 中的项目失效，将所有新项目追加到 entry_points
    public func processFileList(
        dev: DevServer,
        entry_points: EntryPointList,
        temp_alloc: Allocator,
    ): Unit {
        dev.graph_safety_lock.lock()
        defer dev.graph_safety_lock.unlock()

        // 首先处理目录，因为这可能修改 event.files
        if (dev.directory_watchers.watches.count() > 0) {
            for (changed_dir_with_slash in dirs.keys()) {
                let changed_dir = bun.strings.withoutTrailingSlashWindowsPath(changed_dir_with_slash)

                // 清除解析缓存
                dev.server_transpiler.resolver.bustDirCache(changed_dir)

                // 如果存在解析失败的目录监控，现在检查
                if (let Some(watcher_index) = dev.directory_watchers.watches.getIndex(changed_dir)) {
                    let entry = dev.directory_watchers.watches.values()[watcher_index]
                    var new_chain: DirectoryWatchStore.Dep.Index.Optional = DirectoryWatchStore.Dep.Index.Optional.none
                    var it: ?DirectoryWatchStore.Dep.Index = entry.first_dep

                    while (let Some(index) = it) {
                        let dep = dev.directory_watchers.dependencies.items[index.get()]
                        it = dep.next.unwrap()

                        if ((dev.server_transpiler.resolver.resolve(
                            bun.path.dirname(dep.source_file_path),
                            dep.specifier,
                            .stmt,
                        )) != None) {
                            appendFile(dev.allocator(), dep.source_file_path)
                            dev.directory_watchers.freeDependencyIndex(dev.allocator(), index)
                        } else {
                            dep.next = new_chain
                            new_chain = index.toOptional()
                        }
                    }

                    if (let Some(new_first_dep) = new_chain.unwrap()) {
                        entry.first_dep = new_first_dep
                    } else {
                        dev.directory_watchers.freeEntry(dev.allocator(), watcher_index)
                    }
                }
            }
        }

        // 处理额外文件
        var rest_extra = extra_files.items
        while (let Some(str) = bun.strings.indexOfChar(rest_extra, 0)) {
            files.put(dev.allocator(), rest_extra.slice(0, str), Unit())
            rest_extra = rest_extra.slice(str + 1)
        }
        if (rest_extra.length > 0) {
            files.put(dev.allocator(), rest_extra, Unit())
        }

        let changed_file_paths = files.keys()
        for (g in [dev.server_graph, dev.client_graph]) {
            g.invalidate(changed_file_paths, entry_points, temp_alloc)
        }

        if (entry_points.set.count() == 0) {
            dev.publish(.testing_watch_synchronization, [MessageId.testing_watch_synchronization.char(), 1], .binary)
            return
        }
    }

    /// 运行热重载事件
    public static func run(first: HotReloadEvent): Unit {
        assert(first.owner.magic == .valid)

        let dev = first.owner

        if (dev.current_bundle != None) {
            dev.next_bundle.reload_event = first
            return
        }

        var entry_points: EntryPointList = EntryPointList.empty
        defer entry_points.deinit(dev.allocator())

        first.processFileList(dev, entry_points, dev.allocator())

        let timer = first.timer

        var current = first
        while (true) {
            current.processFileList(dev, entry_points, dev.allocator())
            current = dev.watcher_atomics.recycleEventFromDevServer(current) ?? break
        }

        if (entry_points.set.count() == 0) {
            return
        }

        dev.startAsyncBundle(entry_points, true, timer)
    }
}

// 类型别名
public type Timer = std.time.Timer
public type ConcurrentTask = jsc.ConcurrentTask
public type StringArrayHashMapUnmanaged<V> = std.StringArrayHashMapUnmanaged<V>
public type ArrayListUnmanaged<T> = std.ArrayListUnmanaged<T>
public type Atomic<T> = std.atomic.Value<T>
public type Mutex = bun.Mutex
public type Allocator = std.mem.Allocator
public type DirectoryWatchStore = dev_server.DirectoryWatchStore
