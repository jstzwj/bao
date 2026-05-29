// 翻译自 Bun: src/runtime/bake/DevServer/IncrementalGraph.zig
// Bake 增量状态的核心范式是存储与 bundle_v2 中 Graph 分开的文件列表。

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator

/// EdgeIndex type alias
public type EdgeIndex = UInt32

/// 当前 chunk 的 source map 数据
public class CurrentChunkSourceMapData {
    public var file_index: FileIndex
    public var source_map: PackedMap

    public init() {
        file_index = FileIndex(0)
        source_map = PackedMap()
    }

    public func deinit(): Unit {
        source_map.deinit()
    }
}

/// Edge - 导入关系图的边
public class Edge {
    public var dependency: FileIndex
    public var imported: FileIndex
    public var next_import: EdgeIndexOptional
    public var next_dependency: EdgeIndexOptional
    public var prev_dependency: EdgeIndexOptional

    public init() {
        dependency = FileIndex(0)
        imported = FileIndex(0)
        next_import = EdgeIndexOptional.none
        next_dependency = EdgeIndexOptional.none
        prev_dependency = EdgeIndexOptional.none
    }
}

/// EdgeIndexOptional
public struct EdgeIndexOptional {
    public var value: ?UInt32
    public static let none: EdgeIndexOptional = EdgeIndexOptional()
    public init() { value = None }
    public init(value: UInt32) { this.value = value }
    public func unwrap(): ?UInt32 { value }
    public func toOptional(): EdgeIndexOptional { this }
}

/// 增量图 - 存储 Bake 的增量捆绑状态。
public class IncrementalGraph {
    public var side: Side

    /// 键是绝对路径或导入中显示的格式化路径值。
    public var bundled_files: HashMap<String, File>
    /// 跟踪"过期"文件的布尔值
    public var stale_files: DynamicBitSetUnmanaged

    /// 文件"依赖"链表的起始。
    public var first_dep: Array<EdgeIndexOptional>
    /// 文件"导入"链表的起始。
    public var first_import: Array<EdgeIndexOptional>
    /// Edge 对象数组
    public var edges: Array<Edge>
    /// 边空闲列表
    public var edges_free_list: Array<EdgeIndex>

    /// 当前 chunk 的字节长度
    public var current_chunk_len: UInt64
    /// 所有部分内容
    public var current_chunk_parts: Array<FileIndex>
    /// CSS 文件 ID
    public var current_css_files: Array<UInt64>
    /// 服务器端 source map 数据
    public var current_chunk_source_maps: Array<CurrentChunkSourceMapData>

    public init() {
        side = Side.client
        bundled_files = HashMap<String, File>()
        stale_files = DynamicBitSetUnmanaged()
        first_dep = Array<EdgeIndexOptional>()
        first_import = Array<EdgeIndexOptional>()
        edges = Array<Edge>()
        edges_free_list = Array<EdgeIndex>()
        current_chunk_len = 0
        current_chunk_parts = Array<FileIndex>()
        current_css_files = Array<UInt64>()
        current_chunk_source_maps = Array<CurrentChunkSourceMapData>()
    }

    public static let empty: IncrementalGraph = IncrementalGraph()

    /// 析构
    public func deinit(): Unit {
        bundled_files.clear()
        stale_files.deinit(Allocator())
    }

    /// 内存成本详细信息
    public func memoryCostDetailed(): MemoryCostResult {
        var graph: UInt64 = 0
        var code: UInt64 = 0
        var source_maps: UInt64 = 0
        return MemoryCostResult(graph, code, source_maps)
    }

    /// 获取文件索引
    public func getFileIndex(path: String): ?FileIndex {
        if (let Some(i) <- bundled_files.getIndex(path)) {
            return FileIndex(UInt32(i))
        }
        return None
    }

    /// 按索引获取文件
    public func getFileByIndex(index: FileIndex): File {
        let files = bundled_files.values()
        if (Int64(index.get()) < files.size) {
            return files[Int64(index.get())]
        }
        return File()
    }

    /// 接收 chunk
    public func receiveChunk(
        ctx: Any,
        index: AstIndex,
        content: ChunkContent,
        is_ssr_graph: Bool
    ): Unit {
        owner().graph_safety_lock.assertLocked()
    }

    /// 插入空条目
    public func insertEmpty(abs_path: String, kind: FileKind): InsertResult {
        owner().graph_safety_lock.assertLocked()
        let result = InsertResult()
        result.key = abs_path
        return result
    }

    /// 使文件失效
    public func invalidate(paths: Array<String>, entry_points: EntryPointList, alloc: Allocator): Unit {
        owner().graph_safety_lock.assertLocked()
        for (path in paths) {
            if (bundled_files.getIndex(path).isSome()) {
                // 标记为过期
            }
        }
    }

    /// 重置
    public func reset(): Unit {
        owner().graph_safety_lock.assertLocked()
        current_chunk_len = 0
        current_css_files = Array<UInt64>()
        current_chunk_parts = Array<FileIndex>()
    }

    /// 确保过期位容量
    public func ensureStaleBitCapacity(are_new_files_stale: Bool): Unit {
        // 简化
    }

    func owner(): DevServer {
        DevServer()
    }

    func allocator(): Allocator {
        return owner().allocator()
    }
}

/// 文件内容
public enum Content {
    | unknown
    | js(String)
    | asset(String)
    | css_root(UInt64)
    | css_child
}

/// 文件
public class File {
    public var content: Content
    public var source_map: PackedMap
    public var html_route_bundle_index: ?UInt32
    public var failed: Bool
    public var is_hmr_root: Bool
    public var is_special_framework_file: Bool
    public var is_client_component_boundary: Bool
    public var is_route: Bool
    public var kind: FileKind

    public init() {
        content = Content.unknown
        source_map = PackedMap()
        html_route_bundle_index = None
        failed = false
        is_hmr_root = false
        is_special_framework_file = false
        is_client_component_boundary = false
        is_route = false
        kind = FileKind.unknown
    }

    public func stopsDependencyTrace(): Bool {
        return is_client_component_boundary
    }

    public func jsCode(): ?String {
        return match (content) {
            case Content.js(code) => code
            case Content.asset(code) => code
            case _ => None
        }
    }

    public func unpack(): File { this }
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

/// 跟踪导入目标
public enum TraceImportGoal {
    | find_client_modules
    | find_errors
    | find_css
}
