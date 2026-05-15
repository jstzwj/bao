// 翻译自 Bun: src/runtime/bake/DevServer/IncrementalGraph.zig
// Bake 增量状态的核心范式是存储与 bundle_v2 中 Graph 分开的文件列表。
// 当监控事件发生时，bundler 在更改的文件上运行，通过 isFileStale 排除非过期文件。
//
// 每次 bundle 完成后，client_graph 和 server_graph 的 receiveChunk 方法
// 会被调用，计算所需的总长度。调用 takeJSBundle 连接所有 chunk，
// 产生发送到客户端或在服务器上执行的代码。

package bao_runtime.bake.dev_server

/// 增量图 - 存储 Bake 的增量捆绑状态。
/// 此泛型结构根据 side 参数为客户端和服务器端分别实例化。
public class IncrementalGraph {
    public var side: Side

    /// 键是绝对路径或导入中显示的格式化路径值。
    /// 键切片由 dev.allocator() 拥有
    public var bundled_files: StringArrayHashMapUnmanaged<File>
    /// 跟踪"过期"文件的布尔值
    public var stale_files: DynamicBitSetUnmanaged

    /// 文件"依赖"链表的起始。这些是导入此文件的其他文件。
    public var first_dep: ArrayListUnmanaged<EdgeIndex.Optional>
    /// 文件"导入"链表的起始。这些是此文件导入的文件。
    public var first_import: ArrayListUnmanaged<EdgeIndex.Optional>
    /// Edge 对象数组，充当链表节点
    public var edges: ArrayListUnmanaged<Edge>
    /// 边空闲列表
    public var edges_free_list: ArrayListUnmanaged<EdgeIndex>

    /// 当前 chunk 的字节长度
    public var current_chunk_len: UInt64 = 0
    /// 所有部分内容
    public var current_chunk_parts: ArrayListUnmanaged<ChunkPart>
    /// CSS 文件 ID
    public var current_css_files: ArrayListUnmanaged<UInt64>
    /// 服务器端 source map 数据
    public var current_chunk_source_maps: ArrayListUnmanaged<CurrentChunkSourceMapData>

    public static let empty: IncrementalGraph = IncrementalGraph(
        bundled_files: StringArrayHashMapUnmanaged<File>.empty,
        stale_files: DynamicBitSetUnmanaged.empty,
        first_dep: ArrayListUnmanaged<EdgeIndex.Optional>.empty,
        first_import: ArrayListUnmanaged<EdgeIndex.Optional>.empty,
        edges: ArrayListUnmanaged<Edge>.empty,
        edges_free_list: ArrayListUnmanaged<EdgeIndex>.empty,
        current_chunk_len: 0,
        current_chunk_parts: ArrayListUnmanaged<ChunkPart>.empty,
        current_css_files: ArrayListUnmanaged<UInt64>.empty,
        current_chunk_source_maps: ArrayListUnmanaged<CurrentChunkSourceMapData>.empty,
    )

    /// 当前 chunk 的 source map 数据
    public class CurrentChunkSourceMapData {
        public var file_index: FileIndex
        public var source_map: PackedMap.Shared

        public func deinit(): Unit {
            source_map.deinit()
        }
    }

    /// 文件索引
    public struct FileIndex <: UInt30 {}

    /// 边索引
    public struct EdgeIndex <: UInt32 {}

    /// Edge - 导入关系图的边
    public class Edge {
        /// 包含 import 语句的文件
        public var dependency: FileIndex
        /// import 语句引用的文件
        public var imported: FileIndex
        /// dependency 文件的"导入"链表中的下一条边
        public var next_import: EdgeIndex.Optional
        /// imported 文件的"依赖"链表中的下一条边
        public var next_dependency: EdgeIndex.Optional
        /// imported 文件的"依赖"链表中的上一条边（启用双向遍历）
        public var prev_dependency: EdgeIndex.Optional
    }

    /// 析构
    public func deinit(): Unit {
        let alloc = allocator()
        for ((k, v) in bundled_files) {
            alloc.free(k)
        }
        bundled_files.deinit(alloc)
        stale_files.deinit(alloc)
        first_dep.deinit(alloc)
        first_import.deinit(alloc)
        edges.deinit(alloc)
        edges_free_list.deinit(alloc)
        current_chunk_parts.deinit(alloc)
        current_css_files.deinit(alloc)
        for (source_map in current_chunk_source_maps.items) {
            source_map.deinit()
        }
        current_chunk_source_maps.deinit(alloc)
    }

    /// 详细内存成本
    public func memoryCostDetailed(): MemoryCost {
        var graph: UInt64 = 0
        var code: UInt64 = 0
        var source_maps: UInt64 = 0
        graph += DevServer.memoryCostArrayHashMap(bundled_files)
        graph += stale_files.bytes().length
        graph += DevServer.memoryCostArrayList(first_dep)
        graph += DevServer.memoryCostArrayList(first_import)
        graph += DevServer.memoryCostArrayList(edges)
        graph += DevServer.memoryCostArrayList(edges_free_list)
        graph += DevServer.memoryCostArrayList(current_chunk_parts)
        graph += DevServer.memoryCostArrayList(current_css_files)
        return MemoryCost(graph: graph, code: code, source_maps: source_maps)
    }

    /// 内存成本结构
    public class MemoryCost {
        public var graph: UInt64
        public var code: UInt64
        public var source_maps: UInt64
    }

    /// 获取文件索引
    public func getFileIndex(path: String): ?FileIndex {
        if (let Some(i) = bundled_files.getIndex(path)) {
            return FileIndex.init(i)
        }
        return None
    }

    /// 按索引获取文件
    public func getFileByIndex(index: FileIndex): File {
        return bundled_files.values()[index.get()]
    }

    /// 接收 chunk
    public func receiveChunk(
        ctx: HotUpdateContext,
        index: AstIndex,
        content: ChunkContent,
        is_ssr_graph: Bool,
    ): Unit {
        let dev = owner()
        dev.graph_safety_lock.assertLocked()

        let path = ctx.sources[index.get()].path
        let key = path.keyForIncrementalGraph()

        let gop = bundled_files.getOrPut(dev.allocator(), key)
        let file_index = FileIndex.init(gop.index)

        if (!gop.found_existing) {
            gop.key_ptr = dev.allocator().dupe(key)
            first_dep.append(dev.allocator(), EdgeIndex.Optional.none)
            first_import.append(dev.allocator(), EdgeIndex.Optional.none)
        }

        if (stale_files.bit_length > gop.index) {
            stale_files.unset(gop.index)
        }

        // 根据 side 处理 chunk 内容
        match (side) {
            case client =>
                // 客户端图处理 JS/CSS/Asset
                ()
            case server =>
                // 服务器图跟踪模块图成员身份
                ()
        }
    }

    /// 处理 chunk 依赖
    public func processChunkDependencies(
        ctx: HotUpdateContext,
        mode: ProcessMode,
        bundle_graph_index: AstIndex,
        temp_alloc: Allocator,
    ): Unit {
        let file_index: FileIndex = ctx.getCachedIndex(side, bundle_graph_index).unwrap() ?? panic("unresolved index")

        // 构建从现有导入列表的映射
        var quick_lookup: TempLookupHashTable = TempLookupHashTable()
        defer quick_lookup.deinit(temp_alloc)

        // 处理导入记录并更新边
        match (mode) {
            case normal => processChunkImportRecords(ctx, temp_alloc, quick_lookup, file_index, bundle_graph_index)
            case css => processCSSChunkImportRecords(ctx, temp_alloc, quick_lookup, file_index, bundle_graph_index)
        }

        // 跟踪依赖
        traceDependencies(file_index, ctx.gts, .stop_at_boundary, file_index)
    }

    /// 跟踪依赖项
    public func traceDependencies(
        file_index: FileIndex,
        gts: GraphTraceState,
        goal: TraceDependencyGoal,
        from_file_index: FileIndex,
    ): Unit {
        owner().graph_safety_lock.assertLocked()

        if (gts.bits(side).isSet(file_index.get())) { return }
        gts.bits(side).set(file_index.get())

        let file = getFileByIndex(file_index)

        match (side) {
            case server =>
                let dev = owner()
                if (file.is_route) {
                    // 标记框架路由受影响
                }
                if (file.is_client_component_boundary) {
                    // 标记客户端组件受影响
                }
            case client =>
                let dev = owner()
                if (file.is_hmr_root) {
                    // 跟踪到服务器图
                } else if (let Some(route_bundle_index) = file.html_route_bundle_index) {
                    // 标记 HTML 路由受影响
                }
        }

        if (goal == .stop_at_boundary && file.stopsDependencyTrace()) {
            return
        }

        // 递归跟踪依赖
        var it: ?EdgeIndex = first_dep.items[file_index.get()].unwrap()
        while (let Some(dep_index) = it) {
            let edge = edges.items[dep_index.get()]
            it = edge.next_dependency.unwrap()
            traceDependencies(edge.dependency, gts, goal, file_index)
        }
    }

    /// 跟踪导入
    public func traceImports(
        file_index: FileIndex,
        gts: GraphTraceState,
        goal: TraceImportGoal,
    ): Unit {
        owner().graph_safety_lock.assertLocked()

        if (gts.bits(side).isSet(file_index.get())) { return }
        gts.bits(side).set(file_index.get())

        let file = getFileByIndex(file_index)

        match (side) {
            case server =>
                if (file.is_client_component_boundary || file.kind == .css) {
                    let dev = owner()
                    let key = bundled_files.keys()[file_index.get()]
                    let index = dev.client_graph.getFileIndex(key) ?? panic("Missing client component")
                    dev.client_graph.traceImports(index, gts, goal)
                }
            case client =>
                match (file.content) {
                    case css_root(let id) =>
                        if (goal == .find_css) {
                            current_css_files.append(allocator(), id)
                        }
                        return
                    case _ => ()
                }
                if (goal == .find_client_modules) {
                    current_chunk_parts.append(allocator(), file_index)
                    current_chunk_len += file.jsCode()?.length ?? 0
                }
        }

        // 递归跟踪导入
        var it: ?EdgeIndex = first_import.items[file_index.get()].unwrap()
        while (let Some(dep_index) = it) {
            let edge = edges.items[dep_index.get()]
            it = edge.next_import.unwrap()
            traceImports(edge.imported, gts, goal)
        }
    }

    /// 插入过期文件
    public func insertStale(abs_path: String, is_ssr_graph: Bool): FileIndex {
        return insertStaleExtra(abs_path, is_ssr_graph, false)
    }

    /// 插入过期文件（带额外参数）
    public func insertStaleExtra(abs_path: String, is_ssr_graph: Bool, is_route: Bool): FileIndex {
        owner().graph_safety_lock.assertLocked()
        let dev_alloc = allocator()

        let gop = bundled_files.getOrPut(dev_alloc, abs_path)
        let file_index = FileIndex.init(gop.index)

        if (!gop.found_existing) {
            gop.key_ptr = dev_alloc.dupe(abs_path)
            first_dep.append(dev_alloc, EdgeIndex.Optional.none)
            first_import.append(dev_alloc, EdgeIndex.Optional.none)
        }

        if (stale_files.bit_length > gop.index) {
            stale_files.set(gop.index)
        }

        return file_index
    }

    /// 插入空条目
    public func insertEmpty(abs_path: String, kind: FileKind): (FileIndex, String) {
        owner().graph_safety_lock.assertLocked()
        let dev_alloc = allocator()
        let gop = bundled_files.getOrPut(dev_alloc, abs_path)
        if (!gop.found_existing) {
            gop.key_ptr = dev_alloc.dupe(abs_path)
            first_dep.append(dev_alloc, EdgeIndex.Optional.none)
            first_import.append(dev_alloc, EdgeIndex.Optional.none)
            ensureStaleBitCapacity(true)
        }
        return (FileIndex.init(gop.index), gop.key_ptr)
    }

    /// 使文件失效
    public func invalidate(paths: Array<String>, entry_points: EntryPointList, alloc: Allocator): Unit {
        owner().graph_safety_lock.assertLocked()
        for (path in paths) {
            let index = bundled_files.getIndex(path) ?? continue
            let owned_path = bundled_files.keys()[index]
            stale_files.set(index)
            // 根据 side 和文件类型添加到 entry_points
        }
    }

    /// 重置
    public func reset(): Unit {
        owner().graph_safety_lock.assertLocked()
        current_chunk_len = 0
        current_css_files.clearRetainingCapacity()
        current_chunk_parts.clearRetainingCapacity()
    }

    /// 获取 JS Bundle
    public func takeJSBundle(options: TakeJSBundleOptions): Array<Byte> {
        var chunk: ArrayList<Byte> = ArrayList<Byte>.init(allocator())
        takeJSBundleToList(chunk, options)
        return chunk.items
    }

    /// 将 JS Bundle 写入列表
    public func takeJSBundleToList(list: ArrayList<Byte>, options: TakeJSBundleOptions): Unit {
        owner().graph_safety_lock.assertLocked()
        assert(current_chunk_len > 0)

        let runtime: HmrRuntime = match (options.kind) {
            case initial_response => bake.getHmrRuntime(side)
            case hmr_chunk => match (side) {
                case server => HmrRuntime.init("({")
                case client => HmrRuntime.init("self[Symbol.for(\"bun:hmr\")]({\n")
            }
        }

        // 追加运行时代码
        list.appendSlice(runtime.code)
        // 追加 chunk 部分
        for (entry in current_chunk_parts.items) {
            match (side) {
                case client =>
                    if (let Some(code) = bundled_files.values()[entry.get()].unpack().jsCode()) {
                        list.appendSlice(code)
                    }
                case server =>
                    list.appendSlice(entry.get())
            }
        }
    }

    /// 获取 Source Map
    public func takeSourceMap(arena: Allocator, gpa: Allocator, out: SourceMapStore.Entry): Unit {
        let paths = bundled_files.keys()

        match (side) {
            case client =>
                let files = bundled_files.values()
                var file_paths: ArrayListUnmanaged<String> = ArrayListUnmanaged<String>.initCapacity(gpa, current_chunk_parts.items.length)
                var contained_maps: MultiArrayList<PackedMap.Shared> = MultiArrayList<PackedMap.Shared>.empty
                contained_maps.ensureTotalCapacity(gpa, current_chunk_parts.items.length)

                for (file_index in current_chunk_parts.items) {
                    file_paths.appendAssumeCapacity(paths[file_index.get()])
                    let source_map = files[file_index.get()].unpack().source_map.clone()
                    contained_maps.appendAssumeCapacity(source_map)
                }

                out.paths = file_paths.items
                out.files = contained_maps

            case server =>
                var file_paths: ArrayListUnmanaged<String> = ArrayListUnmanaged<String>.initCapacity(gpa, current_chunk_parts.items.length)
                var contained_maps: MultiArrayList<PackedMap.Shared> = MultiArrayList<PackedMap.Shared>.empty
                contained_maps.ensureTotalCapacity(gpa, current_chunk_parts.items.length)

                for (item in current_chunk_source_maps.items) {
                    file_paths.appendAssumeCapacity(paths[item.file_index.get()])
                    contained_maps.appendAssumeCapacity(item.source_map.clone())
                }

                out.paths = file_paths.items
                out.files = contained_maps
        }
    }

    /// 确保过期位容量
    public func ensureStaleBitCapacity(are_new_files_stale: Bool): Unit {
        stale_files.resize(
            allocator(),
            max(bundled_files.count(), stale_files.bit_length),
            are_new_files_stale,
        )
    }

    /// 断开并删除文件
    func disconnectAndDeleteFile(file_index: FileIndex): Unit {
        assert(first_dep.items[file_index.get()] == EdgeIndex.Optional.none)

        // 断开所有导入
        var it: ?EdgeIndex = first_import.items[file_index.get()].unwrap()
        first_import.items[file_index.get()] = EdgeIndex.Optional.none
        while (let Some(edge_index) = it) {
            let dep = edges.items[edge_index.get()]
            it = dep.next_import.unwrap()
            assert(dep.dependency == file_index)
            disconnectEdgeFromDependencyList(edge_index)
            freeEdge(edge_index)
        }

        let key = bundled_files.keys()[file_index.get()]
        owner().directory_watchers.removeDependenciesForFile(allocator(), key)
        allocator().free(key)
    }

    /// 从依赖列表断开边
    func disconnectEdgeFromDependencyList(edge_index: EdgeIndex): Unit {
        let edge = edges.items[edge_index.get()]
        let imported = edge.imported.get()

        if (let Some(prev) = edge.prev_dependency.unwrap()) {
            let prev_dependency = edges.items[prev.get()]
            prev_dependency.next_dependency = edge.next_dependency
            if (let Some(next) = edge.next_dependency.unwrap()) {
                let next_dependency = edges.items[next.get()]
                next_dependency.prev_dependency = edge.prev_dependency
            }
        } else {
            if (let Some(next) = edge.next_dependency.unwrap()) {
                let next_dependency = edges.items[next.get()]
                next_dependency.prev_dependency = EdgeIndex.Optional.none
                first_dep.items[edge.imported.get()] = next.toOptional()
            } else {
                first_dep.items[edge.imported.get()] = EdgeIndex.Optional.none
            }
        }
    }

    /// 创建新边
    func newEdge(edge: Edge): EdgeIndex {
        if (let Some(index) = edges_free_list.pop()) {
            edges.items[index.get()] = edge
            return index
        }
        let index = EdgeIndex.init(edges.items.length)
        edges.append(allocator(), edge)
        return index
    }

    /// 释放边
    func freeEdge(edge_index: EdgeIndex): Unit {
        if (edge_index.get() == edges.items.length - 1) {
            edges.items.length -= 1
        } else {
            edges_free_list.append(allocator(), edge_index)
        }
    }

    func owner(): DevServer {
        // 通过 fieldParentPtr 获取父 DevServer
    }

    func allocator(): Allocator {
        return owner().allocator()
    }
}

/// 文件内容
public enum Content {
    | unknown           // 未知
    | js(String)        // JS 代码
    | asset(String)     // 资产代码
    | css_root(UInt64)  // CSS 根文件
    | css_child         // CSS 子文件
}

/// 服务器文件
public class ServerFile {
    public var is_rsc: Bool
    public var is_ssr: Bool
    public var is_client_component_boundary: Bool
    public var is_route: Bool
    public var failed: Bool
    public var kind: FileKind

    public func stopsDependencyTrace(): Bool {
        return is_client_component_boundary
    }
}

/// 客户端文件
public class ClientFile {
    public var content: Content = Content.unknown
    public var source_map: PackedMap.Shared = PackedMap.Shared.none
    public var html_route_bundle_index: ?RouteBundle.Index = None
    public var failed: Bool = false
    public var is_hmr_root: Bool = false
    public var is_special_framework_file: Bool = false

    public func kind(): FileKind {
        return match (content) {
            case unknown => FileKind.unknown
            case js(_) => FileKind.js
            case asset(_) => FileKind.asset
            case css_root(_) | css_child => FileKind.css
        }
    }

    public func jsCode(): ?String {
        return match (content) {
            case js(let code) | asset(let code) => code
            case _ => None
        }
    }

    public func stopsDependencyTrace(): Bool {
        return false
    }
}

/// 处理模式
public enum ProcessMode {
    | normal
    | css
}

/// 跟踪依赖目标
public enum TraceDependencyGoal {
    | stop_at_boundary
    | no_stop
}

/// Chunk 内容
public enum ChunkContent {
    | js(ChunkJsContent)
    | css(UInt64)
}

/// Chunk JS 内容
public class ChunkJsContent {
    public var code: String
    public var source_map: ?ChunkSourceMap
}

/// Chunk source map
public class ChunkSourceMap {
    public var chunk: SourceMap.Chunk
    public var escaped_source: Owned<String>
}

/// TakeJSBundle 选项
public class TakeJSBundleOptions {
    public var kind: ChunkKind
    public var script_id: SourceMapStore.Key
    public var initial_response_entry_point: String = ""
    public var react_refresh_entry_point: String = ""
    public var console_log: Bool
}

// 类型别名
public type StringArrayHashMapUnmanaged<V> = std.StringArrayHashMapUnmanaged<V>
public type ArrayListUnmanaged<T> = std.ArrayListUnmanaged<T>
public type DynamicBitSetUnmanaged = bun.bit_set.DynamicBitSetUnmanaged
public type Allocator = std.mem.Allocator
public type RouteBundle = dev_server.RouteBundle
public type SourceMapStore = dev_server.SourceMapStore
public type PackedMap = dev_server.PackedMap
public type HotUpdateContext = dev_server.HotUpdateContext
public type GraphTraceState = dev_server.GraphTraceState
public type EntryPointList = dev_server.EntryPointList
