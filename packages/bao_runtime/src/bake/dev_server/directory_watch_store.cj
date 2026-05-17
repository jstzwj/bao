// 翻译自 Bun: src/runtime/bake/DevServer/DirectoryWatchStore.zig
// 当文件无法导入相对路径时，添加目录监控器，
// 以便当匹配的文件创建时，依赖可以重新构建。
// 这处理了用户在创建文件之前编写导入或移动文件的 HMR 情况。

package bao_runtime.bake.dev_server

public struct DirectoryWatchDepIndex {
    public var value: UInt32
}

public struct DirectoryWatchDepIndexOptional {
    public var value: ?UInt32 = None
    public static let none: DirectoryWatchDepIndexOptional = DirectoryWatchDepIndexOptional(value: None)
    public func unwrap(): ?UInt32 { value }
    public func toOptional(): DirectoryWatchDepIndexOptional { this }
}

/// 依赖项
public class DirectoryWatchDep {
    public var next: DirectoryWatchDepIndexOptional
    public var source_file_path: String
    public var specifier: String

    public static let empty: DirectoryWatchDep = DirectoryWatchDirectoryWatchDep(
        next: DirectoryWatchDepIndexOptional.none,
        source_file_path: "",
        specifier: "",
    )
}

/// 监控条目
public class DirectoryWatchEntry {
    public var dir: FD
    public var dir_fd_owned: Bool
    public var first_dep: DirectoryWatchDepIndex
    public var watch_index: UInt16
}

/// 目录监控存储。管理文件解析失败时的目录监控器。
/// 此结构不是线程安全的。
public class DirectoryWatchStore {
    /// 活跃监控器列表。删除时可能重新排序
    public var watches: StringArrayHashMapUnmanaged<DirectoryWatchEntry>
    /// 依赖项列表
    public var dependencies: ArrayListUnmanaged<DirectoryWatchDep>
    /// 依赖项不能重新排序。此列表跟踪哪些索引是空闲的。
    public var dependencies_free_list: ArrayListUnmanaged<DirectoryWatchDepIndex>

    public static let empty: DirectoryWatchStore = DirectoryWatchStore(
        watches: StringArrayHashMapUnmanaged<DirectoryWatchEntry>(),
        dependencies: ArrayListUnmanaged<DirectoryWatchDep>(),
        dependencies_free_list: ArrayListUnmanaged<DirectoryWatchDepIndex>(),
    )

    /// 跟踪解析失败
    public func trackResolutionFailure(
        import_source: String,
        specifier: String,
        renderer: Graph,
        loader: Loader
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

        // TODO: 实现 path buffer pool 和路径拼接
        let joined = import_source
        let dir = joined

        let dev = owner()
        dev.graph_safety_lock.lock()
        dev.graph_safety_lock.unlock()
        let owned_file_path: String = match (renderer) {
            case client => dev.client_graph.insertEmpty(import_source, FileKind.unknown).key
            case server => dev.server_graph.insertEmpty(import_source, FileKind.unknown).key
            case ssr => dev.server_graph.insertEmpty(import_source, FileKind.unknown).key
        }

        insert(dir, owned_file_path, specifier)
    }

    /// 插入目录监控
    func insert(
        dir_name_to_watch: String,
        file_path: String,
        specifier: String
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
            let dep = appendDepAssumeCapacity(DirectoryWatchDep(
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
        let dep = appendDepAssumeCapacity(DirectoryWatchDep(
            next: DirectoryWatchDepIndexOptional.none,
            source_file_path: file_path,
            specifier: specifier_cloned,
        ))
        watches.putAssumeCapacity(dir_name, DirectoryWatchEntry(
            dir: bun.invalid_fd,
            dir_fd_owned: false,
            first_dep: dep,
            watch_index: watch_index,
        ))
    }

    /// 释放依赖索引
    public func freeDependencyIndex(alloc: Allocator, index: DirectoryWatchDepIndex): Unit {
        alloc.free(dependencies.items[index.get()].specifier)
        dependencies.items[index.get()] = DirectoryWatchDep.empty

        if (index.get() == dependencies.items.length - 1) {
            dependencies.items.length -= 1
        } else {
            dependencies_free_list.append(alloc, index)
        }
    }

    /// 释放条目
    public func freeDirectoryWatchEntry(alloc: Allocator, entry_index: UInt64): Unit {
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
            var new_chain: DirectoryWatchDepIndexOptional = DirectoryWatchDepIndexOptional.none
            var it: ?DirectoryWatchDepIndex = entry.first_dep
            while (let Some(index) <- it) {
                let dep = dependencies.items[index.get()]
                it = dep.next.unwrap()
                if (dep.source_file_path == file_path) {
                    freeDependencyIndex(alloc, index)
                } else {
                    dep.next = new_chain
                    new_chain = index.toOptional()
                }
            }
            if (let Some(new_first_dep) <- new_chain.unwrap()) {
                entry.first_dep = new_first_dep
            } else {
                freeDirectoryWatchEntry(alloc, watch_index)
            }
        }
    }

    func appendDepAssumeCapacity(dep: DirectoryWatchDep): DirectoryWatchDepIndex {
        if (let Some(index) <- dependencies_free_list.pop()) {
            dependencies.items[index.get()] = dep
            return index
        }
        let index = DirectoryWatchDepIndex.`init`(dependencies.items.length)
        dependencies.appendAssumeCapacity(dep)
        return index
    }

    func owner(): DevServer {
        // 通过 fieldParentPtr 获取父 DevServer
    }

}

// 类型别名
public type FD = bun.FD
