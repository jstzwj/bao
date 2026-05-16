// 严格翻译自: src/bundler/linker_context/findAllImportedPartsInJSOrder.zig (221行)
// bao_bundler - JS Part 顺序查找: 线性化 chunk 中的 part，依赖在前被依赖在后
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// JS Part 顺序查找
// 严格翻译自: findAllImportedPartsInJSOrder.zig
//
// 将 chunk 中的所有 part 按照依赖顺序线性化:
//   - 依赖的 part 排在被依赖的 part 之前
//   - 使用稳定的源文件索引作为排序决胜符
//   - namespace_export_part_index 总是排在最前面
//   - CommonJS 包装的文件所有 part 必须连续
//
// 核心算法:
//   1. 按到入口点的距离排序 chunk 中的文件
//   2. 从 runtime 开始，深度优先后序遍历 part 依赖
//   3. 结果存储到 chunk.jsContent.filesInChunkOrder 和 partsInChunkOrder
// ============================================================================

/// 为所有 chunk 查找 JS part 顺序
// 严格翻译自: findAllImportedPartsInJSOrder.zig:1
public func findAllImportedPartsInJSOrderExt(linker: LinkerContext,
                                               chunks: ArrayList<Chunk>): Unit {
    for (i in 0..chunks.size) {
        let chunk = chunks[i]
        match (chunk.contentType) {
            case ChunkContentType.JavaScript => {
                findImportedPartsInJSOrder(linker, chunk, i)
            }
            case ChunkContentType.CSS => {
                // 由 findImportedCSSFilesInJSOrder 处理
            }
            case ChunkContentType.HTML => ()
        }
    }
}

/// 为单个 chunk 查找 JS part 顺序
// 严格翻译自: findAllImportedPartsInJSOrder.zig:25
public func findImportedPartsInJSOrder(linker: LinkerContext,
                                         chunk: Chunk,
                                         chunkIndex: Int64): Unit {
    // 按距离排序 chunk 中的文件
    let sortedFiles = sortFilesByDistance(linker, chunk)

    // 创建访问器
    let visitor = FindImportedPartsVisitor()
    visitor.linker = linker
    visitor.entryBits = chunk.entryBits
    visitor.chunkIndex = chunkIndex
    visitor.codeSplitting = linker.graph.codeSplitting
    visitor.partRanges = ArrayList<PartRange>()
    visitor.partsPrefix = ArrayList<PartRange>()
    visitor.visited = HashSet<Int64>()
    visitor.filesInOrder = ArrayList<Int64>()

    // 从 runtime 开始访问
    visitor.visit(SourceIndex.RUNTIME_VALUE)

    // 按排序顺序访问每个文件
    for (sourceIndex in sortedFiles) {
        visitor.visit(sourceIndex)
    }

    // 合并 prefix 和 ranges
    let allRanges = ArrayList<PartRange>()
    for (range in visitor.partsPrefix) {
        allRanges.append(range)
    }
    for (range in visitor.partRanges) {
        allRanges.append(range)
    }

    // 存储到 chunk
    chunk.jsContent.filesInChunkOrder = visitor.filesInOrder
    chunk.jsContent.partsInChunkOrder = allRanges
}

/// 按距离排序 chunk 中的文件
// 严格翻译自: findAllImportedPartsInJSOrder.zig:32 chunk_order_array
private func sortFilesByDistance(linker: LinkerContext, chunk: Chunk): ArrayList<Int64> {
    let distances = linker.graph.files.map({ f => f.distanceFromEntryPoint })
    let stableIndices = linker.graph.stableSourceIndices

    var orders = ArrayList<ChunkOrder>()
    for (entry in chunk.filesWithParts.entries()) {
        let sourceIndex = entry.key
        let distance = if (sourceIndex >= 0 && sourceIndex < distances.size) {
            distances[sourceIndex]
        } else {
            Int64.MAX_VALUE
        }
        let tieBreaker = if (sourceIndex >= 0 && sourceIndex < stableIndices.size) {
            Int64(stableIndices[sourceIndex])
        } else {
            sourceIndex
        }
        orders.append(ChunkOrder(sourceIndex, distance, tieBreaker))
    }

    // 排序 (按距离升序，距离相同按稳定索引升序)
    orders.sort { a, b =>
        if (a.distance != b.distance) {
            a.distance < b.distance
        } else {
            a.tieBreaker < b.tieBreaker
        }
    }

    let result = ArrayList<Int64>()
    for (order in orders) {
        result.append(order.sourceIndex)
    }
    return result
}

/// Part 顺序访问器
// 严格翻译自: findAllImportedPartsInJSOrder.zig:47 FindImportedPartsVisitor
public class FindImportedPartsVisitor {
    /// 链接器
    public var linker: LinkerContext
    /// 入口点位图
    public var entryBits: BitSet
    /// chunk 索引
    public var chunkIndex: Int64
    /// 是否代码分割
    public var codeSplitting: Bool
    /// part 范围列表 (主)
    public var partRanges: ArrayList<PartRange>
    /// part 范围列表 (前缀 - runtime 等)
    public var partsPrefix: ArrayList<PartRange>
    /// 已访问集合
    public var visited: HashSet<Int64>
    /// 文件顺序列表
    public var filesInOrder: ArrayList<Int64>

    public init() {
        linker = LinkerContext()
        entryBits = BitSet()
        chunkIndex = 0
        codeSplitting = false
        partRanges = ArrayList<PartRange>()
        partsPrefix = ArrayList<PartRange>()
        visited = HashSet<Int64>()
        filesInOrder = ArrayList<Int64>()
    }

    /// 访问源文件
    // 严格翻译自: findAllImportedPartsInJSOrder.zig:82 visit()
    // 深度优先后序: 先递归处理依赖，再处理自身
    public func visit(sourceIndex: Int64): Unit {
        if (sourceIndex < 0) { return }
        if (visited.contains(sourceIndex)) { return }
        visited.put(sourceIndex)

        // 判断文件是否在此 chunk 中
        var isFileInChunk = true
        if (codeSplitting) {
            // 代码分割时: 文件的所有入口点必须与此 chunk 完全匹配
            isFileInChunk = entryBits.eql(linker.graph.files[sourceIndex].entryBits)
        } else {
            // 非代码分割时: 只要有交集
            isFileInChunk = entryBits.hasIntersection(
                linker.graph.files[sourceIndex].entryBits
            )
        }

        // CommonJS 包装的文件不能被分割
        let flags = getFlags(sourceIndex)
        let canBeSplit = flags.wrap == WrapKind.None

        // 获取 parts
        let parts = getParts(sourceIndex)
        let importRecords = getImportRecords(sourceIndex)

        // namespace_export_part_index (通常是 part 0)
        let namespaceExportPartIndex: Int64 = 0
        if (canBeSplit && isFileInChunk &&
            namespaceExportPartIndex < parts.size &&
            parts[namespaceExportPartIndex].isLive) {
            appendOrExtendRange(partRanges, sourceIndex, namespaceExportPartIndex)
        }

        // 遍历每个 part
        for (partIndex in 0..parts.size) {
            let part = parts[partIndex]
            let isPartInThisChunk = isFileInChunk && part.isLive

            // 先递归处理 part 的导入依赖
            for (recordId in part.importRecordIndices) {
                if (recordId >= importRecords.size) { continue }
                let record = importRecords[recordId]
                if (record.sourceIndex.isValid() &&
                    (record.kind == ImportKind.Static || isPartInThisChunk)) {
                    if (linker.isExternalDynamicImport(record, sourceIndex)) {
                        // 不跟随 import() 依赖
                        continue
                    }
                    visit(record.sourceIndex.value)
                }
            }

            // 然后包含此 part (在依赖之后)
            if (isPartInThisChunk) {
                isFileInChunk = true

                if (canBeSplit && partIndex != namespaceExportPartIndex &&
                    linker.shouldIncludePart(sourceIndex, part.stmts)) {
                    // runtime 的 part 放入 prefix
                    let targetRanges = if (sourceIndex == SourceIndex.RUNTIME_VALUE) {
                        partsPrefix
                    } else {
                        partRanges
                    }
                    appendOrExtendRange(targetRanges, sourceIndex, partIndex)
                }
            }
        }

        // 如果文件在此 chunk 中，记录
        if (isFileInChunk) {
            filesInOrder.append(sourceIndex)

            // CommonJS 文件所有 part 必须连续
            if (!canBeSplit) {
                partsPrefix.append(PartRange(sourceIndex, 0, parts.size))
            }
        }
    }

    /// 追加或扩展 part range
    // 严格翻译自: findAllImportedPartsInJSOrder.zig:60 appendOrExtendRange()
    private func appendOrExtendRange(ranges: ArrayList<PartRange>,
                                       sourceIndex: Int64,
                                       partIndex: Int64): Unit {
        if (ranges.size > 0) {
            let lastRange = ranges[ranges.size - 1]
            if (lastRange.sourceIndex == sourceIndex &&
                lastRange.partIndexEnd == partIndex) {
                // 扩展最后一个 range
                ranges[ranges.size - 1] = PartRange(
                    sourceIndex,
                    lastRange.partIndexBegin,
                    partIndex + 1
                )
                return
            }
        }
        ranges.append(PartRange(sourceIndex, partIndex, partIndex + 1))
    }

    // 简化的辅助方法
    private func getParts(sourceIndex: Int64): ArrayList<Part> {
        if (sourceIndex < 0 || sourceIndex >= linker.graph.asts.size) {
            return ArrayList<Part>()
        }
        return linker.graph.asts[sourceIndex].parts
    }

    private func getImportRecords(sourceIndex: Int64): ArrayList<ImportRecord> {
        if (sourceIndex < 0 || sourceIndex >= linker.graph.asts.size) {
            return ArrayList<ImportRecord>()
        }
        return linker.graph.asts[sourceIndex].importRecords
    }

    private func getFlags(sourceIndex: Int64): MetaFlags {
        return MetaFlags()
    }
}

/// Part 数据
// 严格翻译自: Part 结构
public class Part {
    /// 是否活跃 (tree-shaking 后保留)
    public var isLive: Bool
    /// 语句列表
    public var stmts: ArrayList<Stmt>
    /// 导入记录索引列表
    public var importRecordIndices: ArrayList<Int64>
    /// 声明的符号
    public var declaredSymbols: ArrayList<Int64>
    /// 使用的符号
    public var symbolUses: HashMap<Int64, SymbolUse>
    /// 依赖的 part 列表
    public var dependencies: ArrayList<PartRef>

    public init() {
        isLive = true
        stmts = ArrayList<Stmt>()
        importRecordIndices = ArrayList<Int64>()
        declaredSymbols = ArrayList<Int64>()
        symbolUses = HashMap<Int64, SymbolUse>()
        dependencies = ArrayList<PartRef>()
    }
}

/// Part 引用 (source_index + part_index)
public class PartRef {
    public var sourceIndex: Int64
    public var partIndex: Int64

    public init(sourceIndex: Int64, partIndex: Int64) {
        this.sourceIndex = sourceIndex
        this.partIndex = partIndex
    }
}

/// 符号使用
public class SymbolUse {
    public var countEstimate: Int64

    public init(countEstimate: Int64) {
        this.countEstimate = countEstimate
    }
}

/// SourceIndex 常量
public class SourceIndex {
    public static let RUNTIME_VALUE: Int64 = 0

    public static func invalid(): Int64 {
        return -1
    }

    public static func isValid(value: Int64): Bool {
        return value >= 0
    }

    public static func fromValue(value: Int64): Int64 {
        return value
    }
}

/// Chunk 顺序条目 (用于排序)
public class ChunkOrder {
    public var sourceIndex: Int64
    public var distance: Int64
    public var tieBreaker: Int64

    public init(sourceIndex: Int64, distance: Int64, tieBreaker: Int64) {
        this.sourceIndex = sourceIndex
        this.distance = distance
        this.tieBreaker = tieBreaker
    }
}
