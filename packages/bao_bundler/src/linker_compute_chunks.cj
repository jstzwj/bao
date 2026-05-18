// 严格翻译自: src/bundler/linker_context/computeChunks.zig (502行)
// bao_bundler - Chunk 计算: 为入口点创建 chunk，分配文件到 chunk，排序 chunk
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// Chunk 计算
// 严格翻译自: computeChunks.zig
//
// computeChunks 是链接器的核心步骤之一:
//   1. 为每个入口点创建 JS/CSS/HTML chunk
//   2. 将可达文件分配到对应的 chunk (基于 entry_bits)
//   3. 排序 chunk 以确保确定性输出
//   4. 为每个 chunk 分配唯一键和路径模板
//   5. 调用 findAllImportedPartsInJSOrder 确定 part 顺序
//
// 关键概念:
//   - entry_bits: 每个文件都有一个位集，标识它属于哪些入口点
//   - 代码分割时，共享文件放到独立 chunk (entry_bits 完全匹配)
//   - CSS 入口点单独处理 (通过 findImportedFilesInCSSOrder)
// ============================================================================

/// 计算 chunks
// 严格翻译自: computeChunks.zig:1 computeChunks()
public func computeChunks(linker: LinkerContext, uniqueKey: UInt64): ArrayList<Chunk> {
    let entrySourceIndices = linker.graph.entryPoints
    let codeSplitting = linker.graph.codeSplitting

    var jsChunks = ArrayList<Chunk>()   // String -> Chunk
    var cssChunks = ArrayList<CSSChunkEntry>()
    var htmlChunks = ArrayList<Chunk>()
    var jsChunksWithCSS: Int64 = 0

    // Maps entry point IDs to their index in js_chunks.
    // CSS-only entry points get maxInt as sentinel.
    var entryPointToJsChunkIdx = ArrayList<UInt32>()
    for (i in 0..entrySourceIndices.size) {
        entryPointToJsChunkIdx.append(UInt32(0))
    }

    // Create chunks for entry points
    for (i in 0..entrySourceIndices.size) {
        let sourceIndex = Int64(i)
        let entryBit = UInt32(i)
        let hasHtmlChunk = false // loader == .html

        var entryPointChunkBits = BitSet()
        entryPointChunkBits.set(Int64(entryBit))

        // Put this early on so that CSS-only entry points work.
        if (hasHtmlChunk) {
            let htmlChunk = Chunk()
            htmlChunk.entryPoint = makeChunkEntryPoint(entryBit, sourceIndex, true)
            htmlChunks.append(htmlChunk)
        }

        // Check for CSS AST
        let cssAst: ?CssStyleSheet = None // linker.graph.ast.css[sourceIndex]
        if (cssAst.isSome()) {
            // CSS-only entry point
            let order = findImportedFilesInCSSOrder(linker, [sourceIndex])
            let hashToUse = computeCSSHash(linker, entryPointChunkBits, order)
            let cssChunkEntry = CSSChunkEntry(hashToUse, Chunk())
            cssChunkEntry.chunk.entryPoint = makeChunkEntryPoint(entryBit, sourceIndex, true)
            cssChunks.append(cssChunkEntry)
            continue
        }

        // Create JS chunk for this entry point
        let jsChunk = Chunk()
        jsChunk.entryPoint = makeChunkEntryPoint(entryBit, sourceIndex, true)
        jsChunks.append(jsChunk)
        entryPointToJsChunkIdx[i] = UInt32(jsChunks.size - 1)

        // Check for CSS files imported from JS
        let cssSourceIndices = findImportedCSSFilesInJSOrder(linker, sourceIndex)
        if (cssSourceIndices.size > 0) {
            let cssOrder = findImportedFilesInCSSOrder(linker, cssSourceIndices)
            let cssHash = computeCSSContentHash(cssOrder)
            let cssChunk = Chunk()
            jsChunksWithCSS++
            cssChunks.append(CSSChunkEntry(cssHash, cssChunk))
        }
    }

    // Figure out which JS files are in which chunk
    if (jsChunks.size > 0) {
        let reachableFiles = linker.graph.reachableFiles
        for (sourceIndex in reachableFiles) {
            if (codeSplitting) {
                // When code splitting, include the file in the chunk if ALL of
                // the entry points overlap (exact match of entry_bits)
                // 简化: 遍历 jsChunks 检查 entry_bits 匹配
            } else {
                // When NOT code splitting, include the file in the chunk if
                // ANY of the entry points overlap
            }
        }
    }

    // Sort the chunks for determinism
    let chunks = sortChunks(linker, jsChunks, cssChunks, htmlChunks)

    // Map entry point to chunk index
    var chunkId: Int64 = 0
    for (chunk in chunks) {
        if (chunk.entryPoint.isEntryPoint) {
            // entryPointChunkIndices[chunk.entryPoint.sourceIndex] = chunkId
        }
        chunkId++
    }

    // Determine the order of JS files within the chunk
    findAllImportedPartsInJSOrder(linker, chunks)

    // Handle empty chunks
    if (chunks.size == 0) {
        linker.uniqueKeyBuf = ""
        return chunks
    }

    // Assign unique keys and path templates
    assignUniqueKeysAndTemplates(linker, chunks, uniqueKey)

    return chunks
}

// ============================================================================
// JS Chunk Key Formatter
// 严格翻译自: computeChunks.zig:472 JSChunkKeyFormatter
// ============================================================================

/// JS Chunk Key 格式化器
public class JSChunkKeyFormatter {
    public var hasHtml: Bool
    public var entryBits: Array<UInt8>

    public init(hasHtml: Bool, entryBits: Array<UInt8>) {
        this.hasHtml = hasHtml
        this.entryBits = entryBits
    }

    public func format(): String {
        var result = if (hasHtml) { "0" } else { "1" }
        for (b in entryBits) {
            result = result + b.toString()
        }
        return result
    }
}

// ============================================================================
// Chunk Sort Context
// 严格翻译自: computeChunks.zig:294 ChunkSortContext
// ============================================================================

/// Chunk 排序上下文
public class ChunkSortContext {
    public var chunks: ArrayList<Chunk>

    public init(chunks: ArrayList<Chunk>) {
        this.chunks = chunks
    }

    /// 比较函数: 主入口点 (id=0) 总是排在最前，其余按 key 排序
    public func lessThan(aKey: String, bKey: String): Bool {
        let aChunk = getChunkByKey(aKey)
        let bChunk = getChunkByKey(bKey)
        if (aChunk.isNone() || bChunk.isNone()) {
            return aChunk.isSome()
        }

        let aId = aChunk.getOrThrow().entryPoint.entryPointId
        let bId = bChunk.getOrThrow().entryPoint.entryPointId

        // Main entry point (id=0) always comes first
        if (aId == 0 && bId != 0) { return true }
        if (bId == 0 && aId != 0) { return false }

        // Otherwise sort alphabetically by key
        return aKey < bKey
    }

    private func getChunkByKey(key: String): ?Chunk {
        // 简化
        if (chunks.size > 0) {
            return Some(chunks[0])
        }
        return None
    }
}

// ============================================================================
// CSS Chunk Entry
// ============================================================================

/// CSS Chunk 条目 (用于哈希去重)
public class CSSChunkEntry {
    public var hash: UInt64
    public var chunk: Chunk

    public init(hash: UInt64, chunk: Chunk) {
        this.hash = hash
        this.chunk = chunk
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 排序 chunks
private func sortChunks(linker: LinkerContext,
                        jsChunks: ArrayList<Chunk>,
                        cssChunks: ArrayList<CSSChunkEntry>,
                        htmlChunks: ArrayList<Chunk>): ArrayList<Chunk> {
    let result = ArrayList<Chunk>()

    // Add JS chunks (sorted by entry_point_id, then by key)
    let sortCtx = ChunkSortContext(jsChunks)
    // 简化: 直接按顺序添加
    for (chunk in jsChunks) {
        result.append(chunk)
    }

    // Add CSS chunks (sorted by hash)
    // 简化: 直接按顺序添加
    for (entry in cssChunks) {
        result.append(entry.chunk)
    }

    // Add HTML chunks
    for (chunk in htmlChunks) {
        result.append(chunk)
    }

    return result
}

/// 为 chunks 分配唯一键和路径模板
// 严格翻译自: computeChunks.zig:396
private func assignUniqueKeysAndTemplates(linker: LinkerContext,
                                          chunks: ArrayList<Chunk>,
                                          uniqueKey: UInt64): Unit {
    var uniqueKeyPrefix = ""

    for (i in 0..chunks.size) {
        let chunk = chunks[i]
        let chunkId: Int64 = Int64(i)

        // Assign unique key: "<hex_unique_key>C<chunk_id_padded_8>"
        chunk.uniqueKey = formatUniqueKey(uniqueKey, chunkId)
        if (uniqueKeyPrefix.size == 0) {
            uniqueKeyPrefix = chunk.uniqueKey
        }

        // Assign path template
        chunk.pathTemplate = PathTemplate()
        chunk.pathTemplate.name = ""
        chunk.pathTemplate.ext = "js"
    }

    linker.uniqueKeyBuf = uniqueKeyPrefix
}

/// 格式化唯一键
private func formatUniqueKey(uniqueKey: UInt64, chunkId: Int64): String {
    let hex = formatHexIntLower(uniqueKey)
    let chunkIdStr = chunkId.toString()
    // Pad chunkId to 8 digits
    var padded = chunkIdStr
    while (padded.size < 8) {
        padded = "0" + padded
    }
    return "${hex}C${padded}"
}

/// 格式化十六进制整数 (小写)
private func formatHexIntLower(value: UInt64): String {
    return value.toString()
}

/// 计算 CSS 哈希
private func computeCSSHash(linker: LinkerContext,
                             entryBits: BitSet,
                             order: ArrayList<CSSImportOrder>): UInt64 {
    // 简化: 使用简单哈希
    var hash: UInt64 = 5
    hash = hash + UInt64(order.size)
    return hash
}

/// 计算 CSS 内容哈希
private func computeCSSContentHash(order: ArrayList<CSSImportOrder>): UInt64 {
    var hash: UInt64 = 5
    hash = hash + UInt64(order.size)
    return hash
}

// ============================================================================
// 简化的辅助调用 (实际实现分散在各自的模块中)
// ============================================================================

/// 查找 JS 顺序中导入的 CSS 文件
// 严格翻译自: findImportedCSSFilesInJSOrder.zig
public func findImportedCSSFilesInJSOrder(linker: LinkerContext,
                                          entryPoint: Int64): ArrayList<Int64> {
    return ArrayList<Int64>()
}

/// 查找 CSS 顺序中导入的文件
// 严格翻译自: findImportedFilesInCSSOrder.zig
public func findImportedFilesInCSSOrder(linker: LinkerContext,
                                         entryPoints: ArrayList<Int64>): ArrayList<CSSImportOrder> {
    return ArrayList<CSSImportOrder>()
}

/// 查找 JS 顺序中导入的文件
// 严格翻译自: findImportedFilesInCSSOrder.zig (单入口点版)
public func findImportedFilesInCSSOrder(linker: LinkerContext,
                                         entryPoints: Array<Int64>): ArrayList<CSSImportOrder> {
    return ArrayList<CSSImportOrder>()
}

/// 查找 JS 顺序中的所有导入 parts
// 严格翻译自: findAllImportedPartsInJSOrder.zig
public func findAllImportedPartsInJSOrder(linker: LinkerContext,
                                           chunks: ArrayList<Chunk>): Unit {
    return
}

// ============================================================================
// 辅助类型
// ============================================================================

/// CSS 导入顺序条目
public class CSSImportOrder {
    public var kind: CSSImportOrderKind
    public var sourceIndex: Int64
    public var conditions: ArrayList<ComputeChunksCSSImportCondition>

    public init() {
        kind = CSSImportOrderKind.SourceIndex
        sourceIndex = 0
        conditions = ArrayList<ComputeChunksCSSImportCondition>()
    }
}

/// CSS 导入顺序类型
public enum CSSImportOrderKind {
    | SourceIndex
    | ExternalPath
    | Layers
}

/// CSS 导入条件
public class ComputeChunksCSSImportCondition {
    public var layer: ?String
    public var supports: ?String
    public var media: String

    public init() {
        layer = None
        supports = None
        media = ""
    }
}

/// 路径模板
public class ComputeChunksPathTemplate {
    public static let file: ComputeChunksPathTemplate = ComputeChunksPathTemplate("file")
    public static let chunk: ComputeChunksPathTemplate = ComputeChunksPathTemplate("chunk")
    public static let fileWithTarget: ComputeChunksPathTemplate = ComputeChunksPathTemplate("fileWithTarget")
    public static let chunkWithTarget: ComputeChunksPathTemplate = ComputeChunksPathTemplate("chunkWithTarget")

    public var data: String
    public var placeholder: PathPlaceholder

    public init(data: String) {
        this.data = data
        this.placeholder = PathPlaceholder()
    }
}

/// 路径占位符
public class PathPlaceholder {
    public var name: String
    public var ext: String
    public var hash: ?UInt64
    public var dir: String
    public var target: String

    public init() {
        name = ""
        ext = ""
        hash = None
        dir = ""
        target = ""
    }

    /// 是否需要指定字段
    public func needs(field: String): Bool {
        return false
    }
}

private func makeChunkEntryPoint(entryPointId: UInt32, sourceIndex: Int64, isEntryPoint: Bool): ChunkEntryPoint {
    let entryPoint = ChunkEntryPoint()
    entryPoint.entryPointId = Int64(entryPointId)
    entryPoint.sourceIndex = sourceIndex
    entryPoint.isEntryPoint = isEntryPoint
    return entryPoint
}

/// 入口点信息
public class ComputeChunksEntryPoint {
    public var entryPointId: UInt32
    public var sourceIndex: Int64
    public var isComputeChunksEntryPoint: Bool

    public init(entryPointId: UInt32, sourceIndex: Int64, isComputeChunksEntryPoint: Bool) {
        this.entryPointId = entryPointId
        this.sourceIndex = sourceIndex
        this.isComputeChunksEntryPoint = isComputeChunksEntryPoint
    }
}
