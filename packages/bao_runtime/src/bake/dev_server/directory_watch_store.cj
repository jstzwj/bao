// 翻译自 Bun: src/runtime/bake/DevServer/DirectoryWatchStore.zig
// 当文件无法导入相对路径时，添加目录监控器，
// 以便当匹配的文件创建时，依赖可以重新构建。
// 这处理了用户在创建文件之前编写导入或移动文件的 HMR 情况。

package bao_runtime

/// 目录监控存储。管理文件解析失败时的目录监控器。
/// 此结构不是线程安全的。
public class DirectoryWatchStore {
    /// 活跃监控器列表。删除时可能重新排序
    public var watches: StringArrayHashMapUnmanaged<Entry>
    /// 依赖项列表
    public var dependencies: ArrayListUnmanaged<Dep>
    /// 依赖项不能重新排序。此列表跟踪哪些索引是空闲的。
    public var dependencies_free_list: ArrayListUnmanaged<Dep.Index>

    public static let empty: DirectoryWatchStore = DirectoryWatchStore(
        watches: StringArrayHashMapUnmanaged<Entry>(),
        dependencies: ArrayListUnmanaged<Dep>(),
        dependencies_free_list: ArrayListUnmanaged<Dep.Index>(),
    )

    /// 跟踪解析失败
    public func trackResolutionFailure(
        import_source: String,
        specifier: String,
        renderer: Graph,
        loader: Loader,
    ): Unit {
        // 当不是文件路径时，无需跟踪
        if (specifier.length == 0) { return }
        if (!std.fs.path.isAbsolute(import_source)) { return }

        match (loader) {
            case tsx | ts | jsx | js =>
                if (!bun.strings.startsWith(specifier, "./") &&
                    !bun.strings.startsWith(specifier, "../")) { return }
            case css | html => () // CSS 和 HTML 可以解析相对文件
            case file | json | jsonc | toml | yaml | json5 | wasm | napi |
                 base64 | dataurl | text | bunsh | sqlite | sqlite_embedded | md =>
                assert(false) // 这些 loader 不依赖导入其他文件
        }

        let buf = bun.path_buffer_pool.get()
        defer bun.path_buffer_pool.put(buf)
        let joined = bun.path.joinAbsStringBuf(bun.path.dirname(import_source), buf, [specifier])
        let dir = bun.path.dirname(joined)

        let dev = owner()
        dev.graph_safety_lock.lock()
        defer dev.graph_safety_lock.unlock()
        let owned_file_path: String = match (renderer) {
            case client => dev.client_graph.insertEmpty(import_source, FileKind.unknown).key
            case server | ssr => dev.server_graph.insertEmpty(import_source, FileKind.unknown).key
        }

        insert(dir, owned_file_path, specifier) match {
            case ok(()) => ()
            case error(Ignore) => () // 忽略监控错误
            case error(OutOfMemory, let e) => return e
        }
    }

    /// 插入目录监控
    func insert(
        dir_name_to_watch: String,
        file_path: String,
        specifier: String,
    ): Unit {
        assert(specifier.length > 0)
        let dev = owner()

        if (dependencies_free_list.items.length == 0) {
            dependencies.ensureUnusedCapacity(dev.allocator(), 1)
        }

        let gop = watches.getOrPut(dev.allocator(), bun.strings.withoutTrailingSlashWindowsPath(dir_name_to_watch))
        let specifier_cloned: String = if (specifier[0] == '.' || std.fs.path.isAbsolute(specifier)) {
            dev.allocator().dupe(specifier)
        } else {
            "./${specifier}"
        }

        if (gop.found_existing) {
            let dep = appendDepAssumeCapacity(Dep(
                next: gop.value_ptr.first_dep.toOptional(),
                source_file_path: file_path,
                specifier: specifier_cloned,
            ))
            gop.value_ptr.first_dep = dep
            return
        }

        // 添加新监控条目
        let dir_name = dev.allocator().dupe(dir_name_to_watch)
        gop.key_ptr = bun.strings.withoutTrailingSlashWindowsPath(dir_name)

        let watch_index = dev.bun_watcher.addDirectory(bun.invalid_fd, dir_name, bun.Watcher.getHash(dir_name), false)
        let dep = appendDepAssumeCapacity(Dep(
            next: Dep.Index.Optional.none,
            source_file_path: file_path,
            specifier: specifier_cloned,
        ))
        watches.putAssumeCapacity(dir_name, Entry(
            dir: bun.invalid_fd,
            dir_fd_owned: false,
            first_dep: dep,
            watch_index: watch_index,
        ))
    }

    /// 释放依赖索引
    public func freeDependencyIndex(alloc: Allocator, index: Dep.Index): Unit {
        alloc.free(dependencies.items[index.get()].specifier)
        dependencies.items[index.get()] = Dep.empty

        if (index.get() == dependencies.items.length - 1) {
            dependencies.items.length -= 1
        } else {
            dependencies_free_list.append(alloc, index)
        }
    }

    /// 释放条目
    public func freeEntry(alloc: Allocator, entry_index: UInt64): Unit {
        let entry = watches.values()[entry_index]
        owner().bun_watcher.removeAtIndex(entry.watch_index, 0, [])

        alloc.free(watches.keys()[entry_index])
        watches.swapRemoveAt(entry_index)

        if (watches.entries.length == 0) {
            assert(dependencies.items.length == dependencies_free_list.items.length)
            dependencies.clearRetainingCapacity()
            dependencies_free_list.clearRetainingCapacity()
        }
    }

    /// 删除文件的所有依赖项
    public func removeDependenciesForFile(alloc: Allocator, file_path: String): Unit {
        if (watches.count() == 0) { return }

        // 反向迭代，因为 freeEntry 使用 swapRemoveAt
        var watch_index = watches.count()
        while (watch_index > 0) {
            watch_index -= 1
            let entry = watches.values()[watch_index]
            var new_chain: Dep.Index.Optional = Dep.Index.Optional.none
            var it: ?Dep.Index = entry.first_dep
            while (let Some(index) = it) {
                let dep = dependencies.items[index.get()]
                it = dep.next.unwrap()
                if (dep.source_file_path == file_path) {
                    freeDependencyIndex(alloc, index)
                } else {
                    dep.next = new_chain
                    new_chain = index.toOptional()
                }
            }
            if (let Some(new_first_dep) = new_chain.unwrap()) {
                entry.first_dep = new_first_dep
            } else {
                freeEntry(alloc, watch_index)
            }
        }
    }

    func appendDepAssumeCapacity(dep: Dep): Dep.Index {
        if (let Some(index) = dependencies_free_list.pop()) {
            dependencies.items[index.get()] = dep
            return index
        }
        let index = Dep.Index.init(dependencies.items.length)
        dependencies.appendAssumeCapacity(dep)
        return index
    }

    func owner(): DevServer {
        // 通过 fieldParentPtr 获取父 DevServer
    }

    /// 监控条目
    public class Entry {
        public var dir: FD              // 目录监控的目录句柄
        public var dir_fd_owned: Bool   // 目录句柄是否拥有的
        public var first_dep: Dep.Index // 第一个依赖
        public var watch_index: UInt16  // 传递给 Watcher.remove 的索引
    }

    /// 依赖项
    public class Dep {
        public var next: Index.Optional
        public var source_file_path: String  // 使用的文件
        public var specifier: String         // 失败的说明符

        public static let empty: Dep = Dep(
            next: Index.Optional.none,
            source_file_path: "",
            specifier: "",
        )

        public struct Index <: UInt32 {}
        public struct Index.Optional {
            public var value: ?UInt32 = None
            public static let none: Index.Optional = Index.Optional(value: None)
            public func unwrap(): ?UInt32 { value }
            public func toOptional(): Index.Optional { this }
        }
    }
}

// 类型别名
public type StringArrayHashMapUnmanaged<V> = std.StringArrayHashMapUnmanaged<V>
public type ArrayListUnmanaged<T> = std.ArrayListUnmanaged<T>
public type FD = bun.FD
