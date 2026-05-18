// 严格翻译自: src/bundler/linker_context/computeCrossChunkDependencies.zig (459行)
// bao_bundler - 跨 chunk 依赖计算: 解析 chunk 间的符号导入/导出关系
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// 跨 Chunk 依赖计算
// 严格翻译自: computeCrossChunkDependencies.zig
//
// 在代码分割模式下，不同 chunk 之间需要传递符号。此模块:
//   1. 遍历每个 chunk 中文件的 part，记录使用的符号
//   2. 确定每个符号声明在哪个 chunk
//   3. 生成跨 chunk 导入 (从声明 chunk 导入符号)
//   4. 生成跨 chunk 导出 (向使用 chunk 导出符号)
//   5. 处理动态导入的跨 chunk 引用
//
// 核心数据结构: ChunkMeta - 记录每个 chunk 的导入/导出符号集合
// ============================================================================

/// 计算跨 chunk 依赖 (顶层入口)
// 严格翻译自: computeCrossChunkDependencies.zig:1 computeCrossChunkDependencies()
public func computeCrossChunkDependencies(
    c: LinkerContext,
    chunks: ArrayList<Chunk>
): Unit {
    if (!c.graph.codeSplitting) {
        // No need to compute cross-chunk dependencies if there can't be any
        return
    }

    // Initialize chunk metadata for each chunk
    let chunkMetas = ArrayList<ChunkMetaExt>()
    for (i in 0..chunks.size) {
        chunkMetas.append(ChunkMetaExt())
    }

    // Walk each chunk to collect symbol information
    let crossChunkDeps = CrossChunkDependencies()
    crossChunkDeps.chunks = chunks
    crossChunkDeps.chunkMeta = chunkMetas
    crossChunkDeps.parts = c.graph.ast.parts
    crossChunkDeps.importRecords = c.graph.ast.importRecords
    crossChunkDeps.flags = c.graph.meta.flags
    crossChunkDeps.entryPointChunkIndices = c.graph.files.entryPointChunkIndices
    crossChunkDeps.importsToBind = c.graph.meta.importsToBind
    crossChunkDeps.wrapperRefs = c.graph.ast.wrapperRefs
    crossChunkDeps.exportsRefs = c.graph.ast.exportsRefs
    crossChunkDeps.sortedAndFilteredExportAliases = c.graph.meta.sortedAndFilteredExportAliases
    crossChunkDeps.resolvedExports = c.graph.meta.resolvedExports
    crossChunkDeps.ctx = c
    crossChunkDeps.symbols = c.graph.symbols

    // Walk each chunk (can be parallelized)
    for (i in 0..chunks.size) {
        crossChunkDeps.walk(chunks[i], i)
    }

    // Compute cross-chunk dependencies using the collected metadata
    computeCrossChunkDependenciesWithChunkMetas(c, chunks, chunkMetas)
}

// ============================================================================
// CrossChunkDependencies
// 严格翻译自: computeCrossChunkDependencies.zig:56 CrossChunkDependencies
// ============================================================================

/// 跨 chunk 依赖遍历器
public class CrossChunkDependencies {
    public var chunkMeta: ArrayList<ChunkMetaExt>
    public var chunks: ArrayList<Chunk>
    public var parts: ArrayList<PartList>
    public var importRecords: ArrayList<ImportRecordList>
    public var flags: ArrayList<MetaFlags>
    public var entryPointChunkIndices: ArrayList<Int64>
    public var importsToBind: ArrayList<RefImportData>
    public var wrapperRefs: ArrayList<Int64>
    public var exportsRefs: ArrayList<Int64>
    public var sortedAndFilteredExportAliases: ArrayList<ArrayList<String>>
    public var resolvedExports: ArrayList<ResolvedExports>
    public var ctx: LinkerContext
    public var symbols: SymbolMap

    public init() {}

    /// 遍历单个 chunk 收集符号信息
    // 严格翻译自: computeCrossChunkDependencies.zig:71 walk()
    public func walk(chunk: Chunk, chunkIndex: Int64): Unit {
        let chunkMeta = chunkMeta[chunkIndex]

        // Go over each file in this chunk
        for (sourceIndex in chunk.filesWithPartsInChunk.keys()) {
            if (chunk.content.isCSS) {
                continue
            }
            if (!chunk.content.isJavaScript) {
                continue
            }

            // Go over each part in this file
            let parts = parts[sourceIndex].slice()
            let importRecordsForFile = importRecords[sourceIndex].slice()
            let importsToBindForFile = importsToBind[sourceIndex]
            let wrap = flags[sourceIndex].wrap
            let wrapperRef = wrapperRefs[sourceIndex]

            for (part in parts) {
                if (!part.isLive) {
                    continue
                }

                // Rewrite external dynamic imports to point to the chunk for that entry point
                for (importRecordId in part.importRecordIndices) {
                    let importRecord = importRecordsForFile[importRecordId]
                    if (importRecord.sourceIndex >= 0 &&
                        ctx.isExternalDynamicImport(importRecord, sourceIndex)) {
                        let otherChunkIndex = entryPointChunkIndices[importRecord.sourceIndex]
                        importRecord.path.text = chunks[otherChunkIndex].uniqueKey
                        importRecord.sourceIndex = -1 // Index.invalid

                        // Track this cross-chunk dynamic import
                        if (otherChunkIndex != chunkIndex) {
                            chunkMeta.dynamicImports.put(otherChunkIndex)
                        }
                    }
                }

                // Remember what chunk each top-level symbol is declared in
                symbols.assignChunkIndex(part.declaredSymbols, chunkIndex)

                // Record each symbol used in this part
                let usedRefs = part.symbolUses.keys()
                for (ref in usedRefs) {
                    let refToUse = resolveSymbolRef(
                        ref, symbols, importsToBindForFile, wrap, wrapperRef)

                    if (refToUse < 0) {
                        continue // Unbound or missing
                    }

                    // Record this symbol as imported by this chunk
                    chunkMeta.imports.put(refToUse)
                }
            }
        }

        // Include exports if this is an entry point chunk
        if (chunk.content.isJavaScript && chunk.entryPoint.isEntryPoint) {
            let flags = flags[chunk.entryPoint.sourceIndex]
            if (flags.wrap != WrapKind.CJS) {
                let resolvedExports = resolvedExports[chunk.entryPoint.sourceIndex]
                let sortedAliases = sortedAndFilteredExportAliases[chunk.entryPoint.sourceIndex]
                for (alias in sortedAliases) {
                    let export_ = resolvedExports.get(alias)
                    var targetRef = export_.data.importRef

                    // Follow import reference
                    let importData = importsToBind[export_.data.sourceIndex].get(targetRef)
                    if (importData != None) {
                        targetRef = importData.data.importRef
                    }

                    // Follow namespace alias
                    let symbol = symbols.getConst(targetRef)
                    if (symbol.namespaceAlias != None) {
                        targetRef = symbol.namespaceAlias.namespaceRef
                    }

                    chunkMeta.imports.put(targetRef)
                }
            }

            // Ensure "exports" is included if needed
            if (flags.forceIncludeExportsForEntryPoint) {
                chunkMeta.imports.put(exportsRefs[chunk.entryPoint.sourceIndex])
            }

            // Include the wrapper if present
            if (flags.wrap != WrapKind.None) {
                chunkMeta.imports.put(wrapperRefs[chunk.entryPoint.sourceIndex])
            }
        }
    }

    /// 解析符号引用
    private func resolveSymbolRef(ref: Int64, symbols: SymbolMap,
                                    importsToBindForFile: RefImportData,
                                    wrap: WrapKind, wrapperRef: Int64): Int64 {
        var refToUse = ref
        let symbol = symbols.getConst(refToUse)

        // Ignore unbound symbols
        if (symbol.kind == SymbolKind.Unbound) {
            return -1
        }

        // Ignore symbols that will be replaced by undefined
        if (symbol.importItemStatus == ImportItemStatus.Missing) {
            return -1
        }

        // Follow import reference
        let importData = importsToBindForFile.get(refToUse)
        if (importData != None) {
            refToUse = importData.data.importRef
            let newSymbol = symbols.getConst(refToUse)
            // Continue with resolved symbol
        } else if (wrap == WrapKind.CJS && refToUse == wrapperRef) {
            // The only internal symbol wrapped CJS files export is the wrapper itself
            return -1
        }

        // If this is an ES6 import from a CJS file, follow namespace alias
        let finalSymbol = symbols.getConst(refToUse)
        if (finalSymbol.namespaceAlias != None) {
            refToUse = finalSymbol.namespaceAlias.namespaceRef
        }

        return refToUse
    }
}

// ============================================================================
// 使用 chunk 元数据计算跨 chunk 依赖
// 严格翻译自: computeCrossChunkDependencies.zig:219
// ============================================================================

/// 使用 chunk 元数据计算跨 chunk 导入/导出
private func computeCrossChunkDependenciesWithChunkMetas(
    c: LinkerContext,
    chunks: ArrayList<Chunk>,
    chunkMetas: ArrayList<ChunkMetaExt>
): Unit {
    // Mark imported symbols as exported in the chunk from which they are declared
    for (i in 0..chunks.size) {
        let chunk = chunks[i]
        if (!chunk.content.isJavaScript) {
            continue
        }

        // Find all uses in this chunk of symbols from other chunks
        for (importRef in chunkMetas[i].imports.keys()) {
            let symbol = c.graph.symbols.getConst(importRef)
            let otherChunkIndex = symbol.chunkIndex()
            if (otherChunkIndex >= 0 && otherChunkIndex != i) {
                // Add to imports_from_other_chunks
                chunk.content.javascript.importsFromOtherChunks
                    .getOrPutValue(otherChunkIndex, ArrayList<CrossChunkImportItem>())
                    .append(CrossChunkImportItem(importRef))
                // Mark as exported in the source chunk
                chunkMetas[otherChunkIndex].exports.put(importRef)
            }
        }

        // If this is an entry point, import all related chunks
        if (chunk.entryPoint.isEntryPoint) {
            for (j in 0..chunks.size) {
                if (j == i || !chunks[j].content.isJavaScript) {
                    continue
                }
                if (chunks[j].entryBits.isSet(chunk.entryPoint.entryPointId)) {
                    chunk.content.javascript.importsFromOtherChunks
                        .getOrPutValue(j, ArrayList<CrossChunkImportItem>())
                }
            }
        }

        // Track dynamic cross-chunk imports for hash calculation
        if (chunkMetas[i].dynamicImports.count() > 0) {
            let dynamicIndices = chunkMetas[i].dynamicImports.keys()
            for (dynamicChunkIndex in dynamicIndices) {
                chunk.crossChunkImports.append(CrossChunkImport(
                    importKind = ImportKind.Dynamic,
                    chunkIndex = dynamicChunkIndex
                ))
            }
        }
    }

    // Generate cross-chunk exports (must be computed before imports)
    generateCrossChunkExports(c, chunks, chunkMetas)

    // Generate cross-chunk imports (must be computed after exports)
    generateCrossChunkImports(c, chunks, chunkMetas)
}

/// 生成跨 chunk 导出
// 严格翻译自: computeCrossChunkDependencies.zig:295
private func generateCrossChunkExports(c: LinkerContext, chunks: ArrayList<Chunk>,
                                          chunkMetas: ArrayList<ChunkMetaExt>): Unit {
    let r = ExportRenamer()

    for (i in 0..chunks.size) {
        if (!chunks[i].content.isJavaScript) {
            continue
        }

        match (c.options.outputFormat) {
            case OutputFormat.ESM =>
                // Sort cross-chunk exports by stable source index
                let stableRefList = c.sortedCrossChunkExportItems(chunkMetas[i].exports)

                // Generate export clause with renamed aliases
                r.clear()
                var clauseItems = ArrayList<ClauseItem>()
                for (stableRef in stableRefList) {
                    let alias = if (c.options.minifyIdentifiers) {
                        r.nextMinifiedName()
                    } else {
                        r.nextRenamedName(c.graph.symbols.get(stableRef.ref).originalName)
                    }

                    clauseItems.append(ClauseItem(
                        ref = stableRef.ref,
                        alias = alias
                    ))

                    // Record the export alias for cross-chunk reference
                    chunks[i].content.javascript.exportsToOtherChunks.put(stableRef.ref, alias)
                }

                // Create export clause statement
                if (clauseItems.size > 0) {
                    chunks[i].content.javascript.crossChunkSuffixStmts =
                        createExportClauseStmt(clauseItems)
                }
            case _ => ()
        }
    }
}

/// 生成跨 chunk 导入
// 严格翻译自: computeCrossChunkDependencies.zig:362
private func generateCrossChunkImports(c: LinkerContext, chunks: ArrayList<Chunk>,
                                          chunkMetas: ArrayList<ChunkMetaExt>): Unit {
    for (i in 0..chunks.size) {
        if (!chunks[i].content.isJavaScript) {
            continue
        }

        match (c.options.outputFormat) {
            case OutputFormat.ESM =>
                // Sort cross-chunk imports
                let sortedImports = sortCrossChunkImports(chunks, chunks[i])

                var crossChunkPrefixStmts = ArrayList<Stmt>()
                for (crossChunkImport in sortedImports) {
                    // Generate import statement for each cross-chunk import
                    let importRecordIndex = chunks[i].crossChunkImports.size
                    var clauses = ArrayList<ClauseItem>()
                    for (item in crossChunkImport.sortedImportItems) {
                        clauses.append(ClauseItem(
                            ref = item.ref,
                            alias = item.exportAlias
                        ))
                    }

                    chunks[i].crossChunkImports.append(CrossChunkImport(
                        importKind = ImportKind.Stmt,
                        chunkIndex = crossChunkImport.chunkIndex
                    ))

                    crossChunkPrefixStmts.append(
                        createImportStmt(clauses, importRecordIndex))
                }

                chunks[i].content.javascript.crossChunkPrefixStmts = crossChunkPrefixStmts
            case _ => ()
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 扩展的 Chunk 元数据 (包含符号导入/导出集合)
// 严格翻译自: computeCrossChunkDependencies.zig:8 ChunkMeta
public class ChunkMetaExt {
    /// 导入的符号集合 (ref -> void)
    public var imports: HashMap<Int64, Unit>
    /// 导出的符号集合 (ref -> void)
    public var exports: HashMap<Int64, Unit>
    /// 动态导入的 chunk 索引
    public var dynamicImports: HashMap<Int64, Unit>

    public init() {
        imports = HashMap<Int64, Unit>()
        exports = HashMap<Int64, Unit>()
        dynamicImports = HashMap<Int64, Unit>()
    }
}

/// 跨 chunk 导入项
// 严格翻译自: computeCrossChunkDependencies.zig CrossChunkImport.Item
public class CrossChunkImportItem {
    /// 引用的符号
    public var ref: Int64

    public init(ref: Int64) {
        this.ref = ref
    }
}

/// 导出重命名器 (避免别名冲突)
// 严格翻译自: computeCrossChunkDependencies.zig ExportRenamer
public class ExportRenamer {
    private var usedNames: HashSet<String>
    private var counter: Int64

    public init() {
        usedNames = HashSet<String>()
        counter = 0
    }

    /// 清除状态
    public func clear(): Unit {
        usedNames.clear()
        counter = 0
    }

    /// 生成下一个重命名名称
    public func nextRenamedName(originalName: String): String {
        var name = originalName
        while (usedNames.contains(name)) {
            name = "${originalName}_${counter}"
            counter++
        }
        usedNames.put(name)
        return name
    }

    /// 生成下一个压缩名称
    public func nextMinifiedName(): String {
        let name = "v${counter}"
        counter++
        usedNames.put(name)
        return name
    }
}

/// 稳定引用 (用于排序)
public class StableRef {
    public var stableSourceIndex: Int64
    public var ref: Int64

    public init(stableSourceIndex: Int64, ref: Int64) {
        this.stableSourceIndex = stableSourceIndex
        this.ref = ref
    }
}

/// 导出子句项
public class ClauseItem {
    public var ref: Int64
    public var alias: String

    public init(ref: Int64, alias: String) {
        this.ref = ref
        this.alias = alias
    }
}

/// 跨 chunk 导入
public class CrossChunkImport {
    public var importKind: ImportKind
    public var chunkIndex: Int64

    public init(importKind: ImportKind, chunkIndex: Int64) {
        this.importKind = importKind
        this.chunkIndex = chunkIndex
    }
}

// ============================================================================
// 辅助函数 (简化)
// ============================================================================

private func createExportClauseStmt(items: ArrayList<ClauseItem>): ArrayList<Stmt> {
    return ArrayList<Stmt>()
}

private func createImportStmt(clauses: ArrayList<ClauseItem>,
                                importRecordIndex: Int64): Stmt {
    return Stmt()
}

private func sortCrossChunkImports(chunks: ArrayList<Chunk>,
                                     chunk: Chunk): ArrayList<CrossChunkImportGroup> {
    return ArrayList<CrossChunkImportGroup>()
}

/// 跨 chunk 导入分组
public class CrossChunkImportGroup {
    public var chunkIndex: Int64
    public var sortedImportItems: ArrayList<CrossChunkImportItem>

    public init() {
        chunkIndex = 0
        sortedImportItems = ArrayList<CrossChunkImportItem>()
    }
}

/// 符号种类
public enum SymbolKind {
    | Unbound
    | Bound
    | Other
}

/// 导入项状态
public enum ImportItemStatus {
    | None
    | Missing
    | Present
}

/// Part 列表 (简化)
public class PartList {
    public func slice(): ArrayList<Part> {
        return ArrayList<Part>()
    }
}

/// 导入记录列表 (简化)
public class ImportRecordList {
    public func slice(): ArrayList<ImportRecord> {
        return ArrayList<ImportRecord>()
    }
}

/// Ref 导入数据 (简化)
public class RefImportData {
    public func get(ref: Int64): ?ImportData {
        return None
    }
}

/// 导入数据
public class ImportData {
    public var data: ImportDataInner

    public init() {
        data = ImportDataInner()
    }
}

/// 导入数据内部
public class ImportDataInner {
    public var importRef: Int64
    public var sourceIndex: Int64

    public init() {
        importRef = 0
        sourceIndex = 0
    }
}

/// 已解析导出 (简化)
public class ResolvedExports {
    public func get(alias: String): ResolvedExportEntry {
        return ResolvedExportEntry()
    }
}

/// 已解析导出条目
public class ResolvedExportEntry {
    public var data: ResolvedExportData

    public init() {
        data = ResolvedExportData()
    }
}

/// 已解析导出数据
public class ResolvedExportData {
    public var importRef: Int64
    public var sourceIndex: Int64

    public init() {
        importRef = 0
        sourceIndex = 0
    }
}
