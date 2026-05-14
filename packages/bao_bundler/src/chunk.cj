// bao_bundler - Chunk (代码分割单元)
// 严格翻译自: src/bundler/Chunk.zig
//   Chunk struct, EntryPoint, JavaScriptChunk, CssChunk,
//   IntermediateOutput, OutputPiece, cross_chunk_imports
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// Chunk 内容类型
// 严格翻译自: Chunk.zig:779 Content union
// ============================================================================

/// Chunk 内容类型
public enum ChunkContentType {
    | JavaScript                      // JavaScript chunk
    | CSS                             // CSS chunk
    | HTML                            // HTML chunk
}

// ============================================================================
// CrossChunkImport - 跨 chunk 导入
// 严格翻译自: Chunk.zig:1 ChunkImport
//   pub const ChunkImport = struct { chunk_index: u32, import_kind: ImportKind }
// ============================================================================

/// 跨 chunk 导入条目
public class CrossChunkImport {
    public var chunkIndex: Int64
    public var importKind: ImportKind
    /// 导入的符号列表 (从目标 chunk 导入哪些符号)
    public var importedSymbols: ArrayList<String>

    public init(chunkIndex: Int64, importKind: ImportKind) {
        this.chunkIndex = chunkIndex
        this.importKind = importKind
        this.importedSymbols = ArrayList<String>()
    }
}

// ============================================================================
// OutputPiece - 输出片段
// 严格翻译自: Chunk.zig:596 OutputPiece
//   用于延迟解析 chunk 间的路径引用 (通过 unique_key 占位)
// ============================================================================

/// 输出片段查询类型
// 严格翻译自: Chunk.zig:606 Query.Kind
public enum OutputPieceKind {
    | None                            // 纯数据片段 (最后一段)
    | Asset                           // 资源文件引用
    | Chunk                           // chunk 引用
    | Scb                             // Server Component Boundary
    | HtmlImport                      // HTML import 引用
}

/// 输出片段 - 代码 + 可选的 chunk/资源引用
// 严格翻译自: Chunk.zig:596
public class OutputPiece {
    public var data: String           // 代码文本
    public var kind: OutputPieceKind
    public var index: Int64           // 引用目标索引

    public init(data: String) {
        this.data = data
        this.kind = OutputPieceKind.None
        this.index = 0
    }

    public init(data: String, kind: OutputPieceKind, index: Int64) {
        this.data = data
        this.kind = kind
        this.index = index
    }

    /// 获取数据长度
    public func dataLen(): Int64 {
        return data.length
    }
}

// ============================================================================
// EntryPoint - 入口点信息
// 严格翻译自: Chunk.zig:637 EntryPoint
//   packed struct(u64) { source_index, entry_point_id, is_entry_point, is_html }
// ============================================================================

/// Chunk 入口点
public class ChunkEntryPoint {
    /// 源文件索引 (在 Graph.input_files 中的位置)
    public var sourceIndex: Int64
    /// 入口点 ID
    public var entryPointId: Int64
    /// 是否为用户指定的入口点
    public var isEntryPoint: Bool
    /// 是否为 HTML 入口
    public var isHtml: Bool

    public init() {
        this.sourceIndex = 0
        this.entryPointId = 0
        this.isEntryPoint = false
        this.isHtml = false
    }

    public init(sourceIndex: Int64, entryPointId: Int64, isEntryPoint: Bool) {
        this.sourceIndex = sourceIndex
        this.entryPointId = entryPointId
        this.isEntryPoint = isEntryPoint
        this.isHtml = false
    }
}

// ============================================================================
// JavaScriptChunk - JavaScript chunk 内容
// 严格翻译自: Chunk.zig:648 JavaScriptChunk
// ============================================================================

/// JavaScript chunk 详细内容
public class JavaScriptChunkContent {
    /// chunk 中文件排序 (source_index 列表)
    // 严格翻译自: files_in_chunk_order
    public var filesInChunkOrder: ArrayList<Int64>
    /// chunk 中 parts 排序
    // 严格翻译自: parts_in_chunk_in_order
    public var partsInChunkOrder: ArrayList<PartRange>
    /// 导出给其他 chunk 的符号
    // 严格翻译自: exports_to_other_chunks
    public var exportsToOtherChunks: HashMap<String, String>
    /// 从其他 chunk 导入的符号
    // 严格翻译自: imports_from_other_chunks
    public var importsFromOtherChunks: ArrayList<CrossChunkImport>
    /// 跨 chunk 前缀语句
    public var crossChunkPrefixStmts: ArrayList<String>
    /// 跨 chunk 后缀语句
    public var crossChunkSuffixStmts: ArrayList<String>
    /// 关联的 CSS chunk 索引列表
    // 严格翻译自: css_chunks
    public var cssChunks: ArrayList<Int64>

    public init() {
        this.filesInChunkOrder = ArrayList<Int64>()
        this.partsInChunkOrder = ArrayList<PartRange>()
        this.exportsToOtherChunks = HashMap<String, String>()
        this.importsFromOtherChunks = ArrayList<CrossChunkImport>()
        this.crossChunkPrefixStmts = ArrayList<String>()
        this.crossChunkSuffixStmts = ArrayList<String>()
        this.cssChunks = ArrayList<Int64>()
    }
}

/// Part 范围 (source_index + part_index 范围)
public class PartRange {
    public var sourceIndex: Int64
    public var partIndexBegin: Int64
    public var partIndexEnd: Int64

    public init(sourceIndex: Int64, begin: Int64, end: Int64) {
        this.sourceIndex = sourceIndex
        this.partIndexBegin = begin
        this.partIndexEnd = end
    }
}

// ============================================================================
// CssChunk - CSS chunk 内容
// 严格翻译自: Chunk.zig:671 CssChunk
// ============================================================================

/// CSS import 排序条目
public class CssImportOrder {
    /// 来源文件索引 (-1 表示外部路径)
    public var sourceIndex: Int64
    /// 外部路径 (url 字符串)
    public var externalPath: String
    /// CSS 条件 (layer, media 等)
    public var conditions: ArrayList<String>
    /// 是否冗余 (被后续 import 覆盖)
    public var isRedundant: Bool

    public init(sourceIndex: Int64) {
        this.sourceIndex = sourceIndex
        this.externalPath = ""
        this.conditions = ArrayList<String>()
        this.isRedundant = false
    }

    public init(externalPath: String) {
        this.sourceIndex = -1
        this.externalPath = externalPath
        this.conditions = ArrayList<String>()
        this.isRedundant = false
    }
}

/// CSS chunk 内容
public class CssChunkContent {
    /// chunk 中 CSS import 排序
    // 严格翻译自: imports_in_chunk_in_order
    public var importsInOrder: ArrayList<CssImportOrder>
    /// 压缩后的 CSS 内容
    public var content: String

    public init() {
        this.importsInOrder = ArrayList<CssImportOrder>()
        this.content = ""
    }
}

// ============================================================================
// Chunk - 代码分割单元
// 严格翻译自: Chunk.zig:6 pub const Chunk = struct { ... }
// ============================================================================

/// Chunk 排序顺序
// 严格翻译自: Chunk.zig:106 Order
public class ChunkOrder {
    public var sourceIndex: Int64
    public var distance: Int64         // 到入口点的距离
    public var tieBreaker: Int64       // 稳定排序的决胜符

    public init(sourceIndex: Int64, distance: Int64, tieBreaker: Int64) {
        this.sourceIndex = sourceIndex
        this.distance = distance
        this.tieBreaker = tieBreaker
    }

    /// 比较函数: 距离入口点近的排在前面
    public static func lessThan(a: ChunkOrder, b: ChunkOrder): Bool {
        if (a.distance != b.distance) {
            return a.distance < b.distance
        }
        return a.tieBreaker < b.tieBreaker
    }
}

/// Chunk - 代码分割的基本单元
// 严格翻译自: Chunk.zig:6
//   pub const Chunk = struct {
//       unique_key: string,
//       files_with_parts_in_chunk: ...,
//       entry_bits: AutoBitSet,
//       final_rel_path: string,
//       cross_chunk_imports: BabyList(ChunkImport),
//       content: Content,
//       entry_point: EntryPoint,
//       ...
//   }
public class Chunk {
    /// 唯一键 (随机字符串，用于占位引用)
    // 严格翻译自: unique_key
    public var uniqueKey: String

    /// 此 chunk 包含的源文件索引及其字节数
    // 严格翻译自: files_with_parts_in_chunk
    public var filesWithParts: HashMap<Int64, Int64>

    /// 此 chunk 对应的入口点位图
    // 严格翻译自: entry_bits
    public var entryBits: BitSet

    /// 最终输出的相对路径
    // 严格翻译自: final_rel_path
    public var finalRelPath: String

    /// 路径模板
    // 严格翻译自: template
    public var pathTemplate: PathTemplate

    /// 跨 chunk 导入
    // 严格翻译自: cross_chunk_imports
    public var crossChunkImports: ArrayList<CrossChunkImport>

    /// 内容类型
    // 严格翻译自: content
    public var contentType: ChunkContentType

    /// JavaScript chunk 详细内容
    public var jsContent: JavaScriptChunkContent

    /// CSS chunk 详细内容
    public var cssContent: CssChunkContent

    /// 入口点信息
    // 严格翻译自: entry_point
    public var entryPoint: ChunkEntryPoint

    /// 中间输出 (代码片段列表)
    // 严格翻译自: intermediate_output
    public var intermediateOutput: ArrayList<OutputPiece>

    /// 是否可执行
    // 严格翻译自: Flags.is_executable
    public var isExecutable: Bool

    /// 是否包含 HTML chunk
    public var hasHtmlChunk: Bool

    /// 孤立哈希 (用于 sourcemap debug ID)
    // 严格翻译自: isolated_hash
    public var isolatedHash: UInt64

    /// Sourcemap 启用
    public var enableSourceMap: Bool

    /// 重命名器 (符号重命名映射)
    public var renames: HashMap<String, String>

    public init() {
        this.uniqueKey = generateUniqueKey()
        this.filesWithParts = HashMap<Int64, Int64>()
        this.entryBits = BitSet()
        this.finalRelPath = ""
        this.pathTemplate = PathTemplate()
        this.crossChunkImports = ArrayList<CrossChunkImport>()
        this.contentType = ChunkContentType.JavaScript
        this.jsContent = JavaScriptChunkContent()
        this.cssContent = CssChunkContent()
        this.entryPoint = ChunkEntryPoint()
        this.intermediateOutput = ArrayList<OutputPiece>()
        this.isExecutable = false
        this.hasHtmlChunk = false
        this.isolatedHash = 0
        this.enableSourceMap = false
        this.renames = HashMap<String, String>()
    }

    /// 判断是否为入口 chunk
    // 严格翻译自: Chunk.zig:54 isEntryPoint
    public func isEntryPoint(): Bool {
        return entryPoint.isEntryPoint
    }

    /// 获取 HTML 关闭标签 (用于内联转义)
    // 严格翻译自: Chunk.zig:61 closingTagForContent
    public func closingTagForContent(): String {
        match (contentType) {
            case ChunkContentType.JavaScript => "</script"
            case ChunkContentType.CSS => "</style"
            case ChunkContentType.HTML => "</body"
        }
    }

    /// 计算中间输出的大小
    // 严格翻译自: IntermediateOutput.getSize
    public func intermediateOutputSize(): Int64 {
        var total: Int64 = 0
        for (piece in intermediateOutput) {
            total += piece.dataLen()
        }
        return total
    }

    /// 添加输出片段
    public func addOutputPiece(data: String): Unit {
        intermediateOutput.append(OutputPiece(data))
    }

    /// 添加带引用的输出片段
    public func addOutputPiece(data: String, kind: OutputPieceKind, index: Int64): Unit {
        intermediateOutput.append(OutputPiece(data, kind, index))
    }

    /// 将中间输出合并为最终代码
    // 严格翻译自: IntermediateOutput.code()
    public func generateCode(chunks: ArrayList<Chunk>): String {
        let sb = StringBuilder()
        for (piece in intermediateOutput) {
            match (piece.kind) {
                case OutputPieceKind.None =>
                    sb.append(piece.data)
                case OutputPieceKind.Chunk =>
                    if (piece.index >= 0 && piece.index < chunks.size) {
                        sb.append(chunks[piece.index].finalRelPath)
                    }
                case OutputPieceKind.Asset =>
                    sb.append(piece.data) // 资源路径将在后续处理
                case OutputPieceKind.Scb | OutputPieceKind.HtmlImport =>
                    sb.append(piece.data)
            }
        }
        return sb.toString()
    }

    /// 添加跨 chunk 导入
    public func addCrossChunkImport(targetChunkIndex: Int64, kind: ImportKind): Unit {
        crossChunkImports.append(CrossChunkImport(targetChunkIndex, kind))
    }

    /// 生成唯一键
    private static func generateUniqueKey(): String {
        // 生成随机 hex 字符串 (模拟 Bun 的 unique_key)
        var sb = StringBuilder()
        let hex = "0123456789abcdef"
        for (_ in 0..16) {
            let idx = Int64(std.random() % 16)
            sb.append(hex.substring(idx, idx + 1))
        }
        return sb.toString()
    }
}

// ============================================================================
// PathTemplate - 路径模板
// 严格翻译自: Chunk.zig 中 PathTemplate 引用
// ============================================================================

/// 路径模板 - 用于生成输出文件名
public class PathTemplate {
    /// 模板字符串 (如 "[name].[hash].js")
    public var template: String
    /// 替换数据
    public var name: String
    public var hash: String
    public var ext: String

    public init() {
        this.template = "[name].js"
        this.name = ""
        this.hash = ""
        this.ext = ".js"
    }

    /// 应用模板生成文件名
    public func apply(): String {
        var result = template
        if (name.length > 0) {
            result = result.replace("[name]", name)
        }
        if (hash.length > 0) {
            result = result.replace("[hash]", hash)
        }
        if (ext.length > 0) {
            result = result.replace("[ext]", ext)
        }
        return result
    }
}

// ============================================================================
// ChunkGraph - chunk 依赖图
// 严格翻译自: LinkerGraph 中 chunk 间依赖关系
//   以及 computeChunks() 排序逻辑
// ============================================================================

/// Chunk 依赖图 - 管理 chunk 之间的依赖关系
public class ChunkGraph {
    /// 所有 chunk
    private var chunks: ArrayList<Chunk>
    /// chunk 索引 -> 依赖的 chunk 索引列表
    private var dependencies: HashMap<Int64, ArrayList<Int64>>
    /// 入口 chunk 索引列表
    private var entryChunks: ArrayList<Int64>
    /// 共享模块提取结果
    private var sharedModules: SharedModuleExtraction

    public init() {
        this.chunks = ArrayList<Chunk>()
        this.dependencies = HashMap<Int64, ArrayList<Int64>>()
        this.entryChunks = ArrayList<Int64>()
        this.sharedModules = SharedModuleExtraction()
    }

    /// 添加 chunk
    public func addChunk(chunk: Chunk): Int64 {
        let index = chunks.size
        chunks.append(chunk)
        dependencies.put(index, ArrayList<Int64>())
        return index
    }

    /// 添加 chunk 间依赖
    public func addDependency(from: Int64, to: Int64): Unit {
        match (dependencies.get(from)) {
            case Some(deps) =>
                if (!deps.contains(to)) {
                    deps.append(to)
                }
            case None => {}
        }
    }

    /// 标记入口 chunk
    public func markEntryChunk(index: Int64): Unit {
        entryChunks.append(index)
        chunks[index].entryPoint.isEntryPoint = true
    }

    /// 获取所有 chunk
    public func getChunks(): ArrayList<Chunk> {
        return chunks
    }

    /// 获取 chunk
    public func getChunk(index: Int64): ?Chunk {
        if (index >= 0 && index < chunks.size) {
            return Some(chunks[index])
        }
        return None
    }

    /// 拓扑排序 chunk (确保依赖在前)
    // 严格翻译自: Chunk.zig:119 Order.sort
    public func topologicalSort(): ArrayList<Int64> {
        let result = ArrayList<Int64>()
        let visited = HashSet<Int64>()
        let visiting = HashSet<Int64>()

        func visit(index: Int64): Unit {
            if (visited.contains(index)) { return }
            if (visiting.contains(index)) { return } // 循环依赖
            visiting.put(index)
            match (dependencies.get(index)) {
                case Some(deps) =>
                    for (dep in deps) {
                        visit(dep)
                    }
                case None => {}
            }
            visiting.remove(index)
            visited.put(index)
            result.append(index)
        }

        for (i in 0..chunks.size) {
            visit(i)
        }

        return result
    }

    /// 计算 chunk 顺序 (按到入口点距离排序)
    // 严格翻译自: Chunk.zig:106-122 Order
    public func computeChunkOrder(): ArrayList<Int64> {
        let distances = HashMap<Int64, Int64>()

        // BFS 从入口点计算距离
        var queue = ArrayList<Int64>()
        for (entry in entryChunks) {
            distances.put(entry, 0)
            queue.append(entry)
        }

        while (queue.size > 0) {
            let current = queue.removeAt(0)
            let currentDist = match (distances.get(current)) {
                case Some(d) => d
                case None => Int64(0)
            }
            match (dependencies.get(current)) {
                case Some(deps) =>
                    for (dep in deps) {
                        match (distances.get(dep)) {
                            case Some(existingDist) =>
                                if (currentDist + 1 < existingDist) {
                                    distances.put(dep, currentDist + 1)
                                    queue.append(dep)
                                }
                            case None =>
                                distances.put(dep, currentDist + 1)
                                queue.append(dep)
                        }
                    }
                case None => {}
            }
        }

        // 按距离排序
        var orders = ArrayList<ChunkOrder>()
        for (i in 0..chunks.size) {
            let dist = match (distances.get(i)) {
                case Some(d) => d
                case None => Int64(Int64.MAX_VALUE)
            }
            orders.append(ChunkOrder(i, dist, i))
        }

        // 简单选择排序 (按距离)
        for (i in 0..orders.size) {
            var minIdx = i
            for (j in i + 1..orders.size) {
                if (ChunkOrder.lessThan(orders[j], orders[minIdx])) {
                    minIdx = j
                }
            }
            if (minIdx != i) {
                let tmp = orders[i]
                orders[i] = orders[minIdx]
                orders[minIdx] = tmp
            }
        }

        let result = ArrayList<Int64>()
        for (order in orders) {
            result.append(order.sourceIndex)
        }
        return result
    }

    /// 获取 chunk 数量
    public func size(): Int64 {
        return chunks.size
    }
}

// ============================================================================
// DynamicImportBoundary - 动态导入边界检测
// 严格翻译自: linker 中对 dynamic import 的 chunk 划分逻辑
// ============================================================================

/// 动态导入边界 - 检测 import() 应该创建新的 chunk 边界
public class DynamicImportBoundary {
    /// 检测动态导入边界
    // import() 表达式创建新的 chunk 边界
    public static func detectBoundaries(modules: ArrayList<Module>): ArrayList<DynamicImportInfo> {
        let boundaries = ArrayList<DynamicImportInfo>()
        for (module in modules) {
            match (module.ast) {
                case Some(program) =>
                    for (stmt in program.stmts) {
                        let dynImports = findDynamicImports(stmt, module.path)
                        for (info in dynImports) {
                            boundaries.append(info)
                        }
                    }
                case None => {}
            }
        }
        return boundaries
    }

    /// 在语句中查找动态 import() 调用
    private static func findDynamicImports(stmt: Stmt, modulePath: String): ArrayList<DynamicImportInfo> {
        let result = ArrayList<DynamicImportInfo>()

        if (stmt.tag == StmtTag.Expr) {
            match (stmt.expr) {
                case Some(expr) =>
                    findDynamicImportsInExpr(expr, modulePath, result)
                case None => {}
            }
        }

        // 也在其他语句类型中递归查找
        if (stmt.tag == StmtTag.Decl) {
            match (stmt.declValue) {
                case Some(expr) =>
                    findDynamicImportsInExpr(expr, modulePath, result)
                case None => {}
            }
        }

        return result
    }

    /// 在表达式中递归查找 import() 调用
    private static func findDynamicImportsInExpr(expr: Expr, modulePath: String, result: ArrayList<DynamicImportInfo>): Unit {
        // import() 调用
        if (expr.tag == ExprTag.Call) {
            match (expr.target) {
                case Some(target) =>
                    if (target.tag == ExprTag.Identifier && target.identifierName == "import") {
                        if (expr.args.size > 0) {
                            let arg = expr.args[0]
                            if (arg.tag == ExprTag.String) {
                                let specifier = arg.stringValue.toString()
                                result.append(DynamicImportInfo(
                                    modulePath,
                                    specifier,
                                    expr.loc.start
                                ))
                            }
                        }
                    }
                case None => {}
            }
        }
    }
}

/// 动态导入信息
public class DynamicImportInfo {
    public var fromModule: String       // 来源模块路径
    public var specifier: String        // import() 参数
    public var position: Int64          // 在源文件中的位置

    public init(fromModule: String, specifier: String, position: Int64) {
        this.fromModule = fromModule
        this.specifier = specifier
        this.position = position
    }
}

// ============================================================================
// SharedModuleExtraction - 共享模块提取
// 严格翻译自: computeChunks() 中对共享模块的 chunk 分配逻辑
//   多个入口点共享的模块应该提取到独立的 chunk 中
// ============================================================================

/// 共享模块提取结果
public class SharedModuleExtraction {
    /// 被多个 chunk 共享的模块 -> 分配到的共享 chunk 索引
    private var sharedModulesMap: HashMap<String, Int64>
    /// 共享模块 -> 使用它的入口 chunk 列表
    private var moduleToEntryChunks: HashMap<String, StringSet>

    public init() {
        this.sharedModulesMap = HashMap<String, Int64>()
        this.moduleToEntryChunks = HashMap<String, StringSet>()
    }

    /// 记录模块被某个入口 chunk 使用
    public func recordUsage(modulePath: String, entryChunkIndex: Int64): Unit {
        match (moduleToEntryChunks.get(modulePath)) {
            case Some(set) => set.insert(String(entryChunkIndex))
            case None =>
                let set = StringSet()
                set.insert(String(entryChunkIndex))
                moduleToEntryChunks.put(modulePath, set)
        }
    }

    /// 计算共享模块 (被 2+ 个入口 chunk 使用的模块)
    public func computeSharedModules(): ArrayList<String> {
        let result = ArrayList<String>()
        for (entry in moduleToEntryChunks) {
            let (modulePath, chunks) = entry
            if (chunks.size >= 2) {
                result.append(modulePath)
            }
        }
        return result
    }

    /// 判断模块是否为共享模块
    public func isShared(modulePath: String): Bool {
        match (moduleToEntryChunks.get(modulePath)) {
            case Some(chunks) => return chunks.size >= 2
            case None => return false
        }
    }

    /// 分配共享模块到 chunk
    public func assignSharedChunk(modulePath: String, chunkIndex: Int64): Unit {
        sharedModulesMap.put(modulePath, chunkIndex)
    }

    /// 获取共享模块的 chunk 索引
    public func getSharedChunkIndex(modulePath: String): ?Int64 {
        return sharedModulesMap.get(modulePath)
    }
}

// ============================================================================
// ChunkBuilder - Chunk 构建器
// 严格翻译自: computeChunks() 中 chunk 的创建和分配逻辑
// ============================================================================

/// Chunk 构建器
public class ChunkBuilder {
    private var chunkGraph: ChunkGraph
    private var sharedExtraction: SharedModuleExtraction

    public init() {
        this.chunkGraph = ChunkGraph()
        this.sharedExtraction = SharedModuleExtraction()
    }

    /// 从模块图构建 chunks
    // 严格翻译自: computeChunks() 的整体流程
    public func buildChunks(modules: ArrayList<Module>, entryPoints: Array<String>): ChunkGraph {
        // 1. 为每个入口点创建 chunk
        let modulePathToIndex = HashMap<String, Int64>()
        for (i in 0..modules.size) {
            modulePathToIndex.put(modules[i].path, i)
        }

        // 2. 分析每个模块被哪些入口点使用
        let moduleEntryUsage = HashMap<String, StringSet>()
        for (entry in entryPoints) {
            let reachable = bfsReachable(entry, modules, modulePathToIndex)
            for (mod in reachable) {
                match (moduleEntryUsage.get(mod)) {
                    case Some(set) => set.insert(entry)
                    case None =>
                        let set = StringSet()
                        set.insert(entry)
                        moduleEntryUsage.put(mod, set)
                }
                sharedExtraction.recordUsage(mod, entryPoints.indexOf(entry).getOr(0))
            }
        }

        // 3. 创建入口 chunk
        for (i in 0..entryPoints.size) {
            let chunk = Chunk()
            chunk.entryPoint = ChunkEntryPoint(
                modulePathToIndex.get(entryPoints[i]).getOr(0),
                i,
                true
            )
            chunk.finalRelPath = generateChunkName(entryPoints[i], i)
            let idx = chunkGraph.addChunk(chunk)
            chunkGraph.markEntryChunk(idx)
        }

        // 4. 提取共享模块到独立 chunk
        let sharedModules = sharedExtraction.computeSharedModules()
        if (sharedModules.size > 0) {
            let sharedChunk = Chunk()
            sharedChunk.entryPoint.isEntryPoint = false
            sharedChunk.finalRelPath = "shared.${hashModules(sharedModules)}.js"
            let sharedIdx = chunkGraph.addChunk(sharedChunk)
            for (mod in sharedModules) {
                sharedExtraction.assignSharedChunk(mod, sharedIdx)
                // 添加依赖: 入口 chunk -> 共享 chunk
                for (i in 0..entryPoints.size) {
                    let entryChunkIdx = i
                    chunkGraph.addDependency(entryChunkIdx, sharedIdx)
                    sharedChunk.addCrossChunkImport(entryChunkIdx, ImportKind.Dynamic)
                }
            }
        }

        return chunkGraph
    }

    /// BFS 获取从入口点可达的所有模块
    private func bfsReachable(entry: String, modules: ArrayList<Module>, pathToIndex: HashMap<String, Int64>): ArrayList<String> {
        let result = ArrayList<String>()
        let visited = StringSet()
        var queue = ArrayList<String>()
        queue.append(entry)

        while (queue.size > 0) {
            let current = queue.removeAt(0)
            if (visited.contains(current)) { continue }
            visited.insert(current)
            result.append(current)

            // 查找当前模块的依赖
            for (mod in modules) {
                if (mod.path == current) {
                    for (dep in mod.dependencies) {
                        if (!visited.contains(dep)) {
                            queue.append(dep)
                        }
                    }
                }
            }
        }

        return result
    }

    /// 生成 chunk 文件名
    private func generateChunkName(entryPath: String, index: Int64): String {
        let name = Path.basename(entryPath)
        let baseName = if (name.contains(".")) {
            name.substring(0, name.lastIndexOf(".").getOr(0))
        } else {
            name
        }
        return baseName + ".js"
    }

    /// 哈希模块列表
    private func hashModules(modules: ArrayList<String>): String {
        var hash: UInt64 = 5381
        for (mod in modules) {
            for (c in mod) {
                hash = ((hash << 5) + hash) + UInt64(c.value)
            }
        }
        return hash.toHexString().substring(0, 8)
    }

    /// 获取共享模块提取结果
    public func getSharedExtraction(): SharedModuleExtraction {
        return sharedExtraction
    }
}
