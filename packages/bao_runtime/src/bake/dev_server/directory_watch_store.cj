// 翻译自 Bun: src/runtime/bake/DevServer/DirectoryWatchStore.zig
// 当文件无法导入相对路径时，添加目录监控器，
// 以便当匹配的文件创建时，依赖可以重新构建。
// 这处理了用户在创建文件之前编写导入或移动文件的 HMR 情况。

package bao_runtime.bake.dev_server


import bao_bun_alloc.Allocator
import bao_collections.HashMap

/// Directory watch entry [KEPT: no-pkg]
public class DirectoryWatchEntry {
    public init() {}
}

public struct DirectoryWatchDepIndex {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public func get(): UInt32 { value }
}

public struct DirectoryWatchDepIndexOptional {
    public var value: ?UInt32
    public static let none: DirectoryWatchDepIndexOptional = DirectoryWatchDepIndexOptional()
    public init() { value = None }
    public init(value: ?UInt32) { this.value = value }
    public func unwrap(): ?UInt32 { value }
    public func toOptional(): DirectoryWatchDepIndexOptional { this }
}

/// 依赖项
public class DirectoryWatchDep {
    public var next: DirectoryWatchDepIndexOptional
    public var source_file_path: String
    public var specifier: String

    public init() {
        next = DirectoryWatchDepIndexOptional.none
        source_file_path = ""
        specifier = ""
    }

    public init(next: DirectoryWatchDepIndexOptional, source_file_path: String, specifier: String) {
        this.next = next
        this.source_file_path = source_file_path
        this.specifier = specifier
    }

    public static let empty: DirectoryWatchDep = DirectoryWatchDep()
}

/// 目录监控存储。管理文件解析失败时的目录监控器。
/// 此结构不是线程安全的。
public class DirectoryWatchStore {
    /// 活跃监控器列表。删除时可能重新排序
    public var watches: SimpleHashMap<DirectoryWatchEntry>
    /// 依赖项列表
    public var dependencies: Array<DirectoryWatchDep>
    /// 依赖项不能重新排序。此列表跟踪哪些索引是空闲的。
    public var dependencies_free_list: Array<DirectoryWatchDepIndex>

    public init() {
        watches = SimpleHashMap<DirectoryWatchEntry>()
        dependencies = Array<DirectoryWatchDep>()
        dependencies_free_list = Array<DirectoryWatchDepIndex>()
    }

    public static let empty: DirectoryWatchStore = DirectoryWatchStore()

    /// 跟踪解析失败
    public func trackResolutionFailure(
        import_source: String,
        specifier: String,
        renderer: Graph,
        loader: Loader
    ): Unit {
        // 当不是文件路径时，无需跟踪
        if (specifier.size == 0) { return }
        if (!isAbsolutePath(import_source)) { return }

        match (loader) {
            case FileKind.tsx =>
                if (!specifier.startsWith("./") && !specifier.startsWith("../")) { return }
            case FileKind.ts =>
                if (!specifier.startsWith("./") && !specifier.startsWith("../")) { return }
            case FileKind.jsx =>
                if (!specifier.startsWith("./") && !specifier.startsWith("../")) { return }
            case FileKind.js =>
                if (!specifier.startsWith("./") && !specifier.startsWith("../")) { return }
            case FileKind.css => () // CSS 可以解析相对文件
            case FileKind.html => () // HTML 可以解析相对文件
            case FileKind.file => assert(false)
            case FileKind.json => assert(false)
            case FileKind.jsonc => assert(false)
            case FileKind.toml => assert(false)
            case FileKind.yaml => assert(false)
            case FileKind.json5 => assert(false)
            case FileKind.wasm => assert(false)
            case FileKind.napi => assert(false)
            case FileKind.base64 => assert(false)
            case FileKind.dataurl => assert(false)
            case FileKind.text => assert(false)
            case FileKind.bunsh => assert(false)
            case FileKind.sqlite => assert(false)
            case FileKind.sqlite_embedded => assert(false)
            case FileKind.md => assert(false)
            case _ => ()
        }

        let joined = PathHelper.join([PathHelper.dirname(import_source), specifier])
        let dir = PathHelper.dirname(joined)

        let dev = owner()
        dev.graph_safety_lock.lock()
        dev.graph_safety_lock.unlock()

        let owned_file_path: String = match (renderer) {
            case Graph.client => dev.client_graph.insertEmpty(import_source, FileKind.unknown).key
            case Graph.server => dev.server_graph.insertEmpty(import_source, FileKind.unknown).key
            case Graph.ssr => dev.server_graph.insertEmpty(import_source, FileKind.unknown).key
        }

        insert(dir, owned_file_path, specifier)
    }

    /// 插入目录监控
    func insert(
        dir_name_to_watch: String,
        file_path: String,
        specifier: String
    ): Unit {
        assert(specifier.size > 0)
        let dev = owner()

        if (dependencies_free_list.size == 0) {
            // dependencies.ensureUnusedCapacity(dev.allocator(), 1)
        }

        let dir_key = StringsHelper.withoutTrailingSlashWindowsPath(dir_name_to_watch)
        let specifier_cloned: String = if (specifier.startsWith(".") || isAbsolutePath(specifier)) {
            specifier
        } else {
            "./${specifier}"
        }

        if (watches.get(dir_key).isSome()) {
            // 已存在
            return
        }

        // 添加新监控条目
        let watch_index = 0 // TODO: dev.bun_watcher.addDirectory not yet available
        let dep = appendDepAssumeCapacity(DirectoryWatchDep(
            DirectoryWatchDepIndexOptional.none,
            file_path,
            specifier_cloned
        ))
        watches.put(dir_key, DirectoryWatchEntry())
    }

    /// 释放依赖索引
    public func freeDependencyIndex(alloc: Allocator, index: DirectoryWatchDepIndex): Unit {
        if (Int64(index.get()) < dependencies.size) {
            dependencies[Int64(index.get())] = DirectoryWatchDep.empty
        }

        if (index.get() == UInt32(dependencies.size) - 1) {
            // 如果是最后一个，缩减数组
            dependencies = Array<DirectoryWatchDep>(dependencies.size - 1, { i => dependencies[Int64(i)] })
        } else {
            // 添加到空闲列表
            let freeEntry = DirectoryWatchDepIndex(index.get())
            dependencies_free_list = Array<DirectoryWatchDepIndex>(dependencies_free_list.size + 1, { i =>
                if (i < dependencies_free_list.size) { dependencies_free_list[Int64(i)] } else { freeEntry }
            })
        }
    }

    /// 释放条目
    public func freeDirectoryWatchEntry(alloc: Allocator, entry_index: UInt64): Unit {
        // 使用 HashMap 的键删除 - 简化实现
        // 在实际实现中需要反向查找键
    }

    /// 删除文件的所有依赖项
    public func removeDependenciesForFile(alloc: Allocator, file_path: String): Unit {
        if (watches.count() == 0) { return }
        // 遍历依赖并移除匹配的
        var i: Int64 = 0
        while (i < dependencies.size) {
            if (dependencies[i].source_file_path == file_path) {
                freeDependencyIndex(alloc, DirectoryWatchDepIndex(UInt32(i)))
            }
            i += 1
        }
    }

    func appendDepAssumeCapacity(dep: DirectoryWatchDep): DirectoryWatchDepIndex {
        if (dependencies_free_list.size > 0) {
            let index = dependencies_free_list[dependencies_free_list.size - 1]
            dependencies[Int64(index.get())] = dep
            // 从空闲列表移除
            dependencies_free_list = Array<DirectoryWatchDepIndex>(dependencies_free_list.size - 1, { i =>
                dependencies_free_list[Int64(i)]
            })
            return index
        }
        let index = DirectoryWatchDepIndex(UInt32(dependencies.size))
        // 追加新依赖
        dependencies = Array<DirectoryWatchDep>(dependencies.size + 1, { i =>
            if (i < dependencies.size) { dependencies[Int64(i)] } else { dep }
        })
        return index
    }

    func owner(): DevServer {
        // 通过 fieldParentPtr 获取父 DevServer
        DevServer()
    }
}

/// HashMap helper methods
/// 简化的哈希映射实现，仅用于 String 键
public class SimpleHashMap<V> {
    public var entries: Array<(String, V)> = []
    public init() {}
    public func get(key: String): ?V {
        for (entry in entries) {
            if (entry[0] == key) { return entry[1] }
        }
        return None
    }
    public func put(key: String, value: V): Unit {
        for (i in 0..entries.size) {
            if (entries[Int64(i)][0] == key) {
                entries[Int64(i)] = (key, value)
                return
            }
        }
        entries = Array<(String, V)>(entries.size + 1, { i =>
            if (i < entries.size) { entries[Int64(i)] } else { (key, value) }
        })
    }
    public func remove(key: String): ?V {
        for (i in 0..entries.size) {
            if (entries[Int64(i)][0].toString() == key) {
                let value = entries[Int64(i)][1]
                entries = Array<(String, V)>(entries.size - 1, { j =>
                    if (j < Int64(i)) { entries[j] } else { entries[j + 1] }
                })
                return value
            }
        }
        return None
    }
    public func getOrPut(alloc: Allocator, key: String): GetOrPutResult { GetOrPutResult() }
    public func keys(): Array<String> { Array<String>(entries.size, { i => entries[Int64(i)][0] }) }
    public func values(): Array<V> { Array<V>(entries.size, { i => entries[Int64(i)][1] }) }
    public func count(): Int64 { entries.size }
    public func clear(): Unit { entries = [] }
    public func deinit(alloc: Allocator): Unit { entries = [] }
    public func clearRetainingCapacity(): Unit { entries = [] }
    public func getPtr(key: String): ?V { get(key) }
    public func getIndex(key: String): ?UInt64 {
        for (i in 0..entries.size) {
            if (entries[Int64(i)][0].toString() == key.toString()) { return UInt64(i) }
        }
        return None
    }
}

/// GetOrPutResult helper
public class GetOrPutResult {
    public init() {}
    public var found_existing: Bool = false
    public var index: UInt32 = 0
    public var key_ptr: Any = ""
    public var value_ptr: Any = ""
}
