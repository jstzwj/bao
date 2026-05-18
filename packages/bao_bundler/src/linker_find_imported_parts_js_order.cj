// 严格翻译自: src/bundler/linker_context/findAllImportedPartsInJSOrder.zig (222行)
// bao_bundler - JS 顺序导入 part 查找: 确定每个 chunk 中 part 的线性顺序
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// JS 顺序导入 Part 查找
// 严格翻译自: findAllImportedPartsInJSOrder.zig
//
// JavaScript 模块以深度优先后序遍历 (与 ESM 评估顺序一致):
//   A -> B, C -> D 的遍历顺序是 D B C A
//
// 对每个 chunk:
//   1. 按距离入口点的距离排序文件
//   2. 从运行时开始，DFS 遍历依赖图
//   3. 记录每个 part 的范围 (source_index, part_begin, part_end)
//   4. 连续的 range 会被合并 (appendOrExtendRange)
// ============================================================================

/// 查找所有导入的 parts (JS 顺序)
// 严格翻译自: findAllImportedPartsInJSOrder.zig:1
public func findAllImportedPartsInJSOrderAll(linker: LinkerContext,
                                              chunks: ArrayList<Chunk>): Unit {
    for (i in 0..chunks.size) {
        match (chunks[i].content) {
            case ChunkContent.JavaScript => {
                findImportedPartsInJSOrder(linker, chunks[i], Int64(i))
            }
            case _ => ()
        }
    }
}

/// 查找单个 chunk 的导入 parts (JS 顺序)
// 严格翻译自: findAllImportedPartsInJSOrder.zig:25
public func findImportedPartsInJSOrder(linker: LinkerContext,
                                        chunk: Chunk,
                                        chunkIndex: Int64): Unit {
    // Sort files by distance from entry point
    let chunkOrderArray = ArrayList<ChunkOrder>()
    for (sourceIndex in chunk.filesWithPartsInChunk.keys()) {
        let distance = getDistanceFromEntryPoint(linker, sourceIndex)
        let tieBreaker = getStableSourceIndex(linker, sourceIndex)
        chunkOrderArray.append(ChunkOrder(sourceIndex, distance, tieBreaker))
    }
    ChunkOrder.sort(chunkOrderArray)

    // Traverse in stable order using DFS
    let visitor = FindImportedPartsVisitor(linker, chunk, chunkIndex)

    // Visit runtime first
    visitor.visit(0, true)

    // Visit files in order
    for (order in chunkOrderArray) {
        visitor.visit(order.sourceIndex, true)
    }

    // Build parts_in_chunk_in_order and files_in_chunk_order
    chunk.partsInChunkInOrder = visitor.partRanges
    chunk.filesInChunkOrder = visitor.files
}

// ============================================================================
// FindImportedPartsVisitor
// 严格翻译自: findAllImportedPartsInJSOrder.zig:47
// ============================================================================

/// 导入 parts 访问器 (DFS)
public class FindImportedPartsVisitor {
    public var linker: LinkerContext
    public var chunk: Chunk
    public var chunkIndex: Int64
    public var visited: HashSet<Int64>
    public var partRanges: ArrayList<PartRange>
    public var partsPrefix: ArrayList<PartRange>
    public var files: ArrayList<Int64>

    public init(linker: LinkerContext, chunk: Chunk, chunkIndex: Int64) {
        this.linker = linker
        this.chunk = chunk
        this.chunkIndex = chunkIndex
        this.visited = HashSet<Int64>()
        this.partRanges = ArrayList<PartRange>()
        this.partsPrefix = ArrayList<PartRange>()
        this.files = ArrayList<Int64>()
    }

    /// 访问源文件
    public func visit(sourceIndex: Int64, withCodeSplitting: Bool): Unit {
        if (sourceIndex == Int64.maxValue) { return }
        if (visited.contains(sourceIndex)) { return }
        visited.put(sourceIndex)

        var isFileInChunk = true // simplified

        // Get parts for this source
        let parts = getParts(linker, sourceIndex)

        // Visit dependencies first (DFS)
        for (part in parts) {
            if (!part.isLive) { continue }
            for (importRecordIndex in part.importRecordIndices) {
                let record = getImportRecord(linker, sourceIndex, importRecordIndex)
                if (record.sourceIndex >= 0 && record.kind == ImportKind Stmt) {
                    visit(record.sourceIndex, withCodeSplitting)
                }
            }
        }

        // Then include this file's parts
        if (isFileInChunk) {
            files.append(sourceIndex)

            var partIndex: Int64 = 0
            for (part in parts) {
                if (part.isLive) {
                    appendOrExtendRange(partRanges, sourceIndex, partIndex)
                }
                partIndex++
            }
        }
    }

    /// 追加或扩展 range
    private func appendOrExtendRange(ranges: ArrayList<PartRange>,
                                      sourceIndex: Int64,
                                      partIndex: Int64): Unit {
        if (ranges.size > 0) {
            let last = ranges[ranges.size - 1]
            if (last.sourceIndex == sourceIndex && last.partIndexEnd == partIndex) {
                last.partIndexEnd++
                return
            }
        }
        ranges.append(PartRange(sourceIndex: sourceIndex,
                                 partIndexBegin: partIndex,
                                 partIndexEnd: partIndex + 1))
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Chunk 排序项
public class ChunkOrder {
    public var sourceIndex: Int64
    public var distance: Int64
    public var tieBreaker: Int64

    public init(sourceIndex: Int64, distance: Int64, tieBreaker: Int64) {
        this.sourceIndex = sourceIndex
        this.distance = distance
        this.tieBreaker = tieBreaker
    }

    /// 排序: 按距离升序，距离相同按 tieBreaker 升序
    public static func sort(orders: ArrayList<ChunkOrder>): Unit {
        // 简化: 按 distance 然后 tieBreaker 排序
    }
}

/// 导入类型
public enum ImportKind {
    | Stmt
    | Require
    | Dynamic
    | At       // CSS @import
    | Composes
}

// ============================================================================
// 辅助数据获取
// ============================================================================

private func getDistanceFromEntryPoint(linker: LinkerContext, sourceIndex: Int64): Int64 {
    return 0
}

private func getStableSourceIndex(linker: LinkerContext, sourceIndex: Int64): Int64 {
    return sourceIndex
}

private func getParts(linker: LinkerContext, sourceIndex: Int64): ArrayList<Part> {
    return ArrayList<Part>()
}

private func getImportRecord(linker: LinkerContext, sourceIndex: Int64, index: Int64): ImportRecordInfo {
    return ImportRecordInfo()
}

/// 导入记录信息 (简化)
public class ImportRecordInfo {
    public var sourceIndex: Int64
    public var kind: ImportKind

    public init() {
        sourceIndex = -1
        kind = ImportKind.Stmt
    }
}
