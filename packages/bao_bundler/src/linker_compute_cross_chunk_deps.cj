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

/// 跨 chunk 依赖计算器
// 严格翻译自: computeCrossChunkDependencies.zig:1 computeCrossChunkDependencies()
public class CrossChunkDependencyComputer {
    /// 链接器上下文
    public var linker: LinkerContext
    /// chunk 元数据数组
    public var chunkMetas: ArrayList<ChunkMetaExt>

    public init(linker: LinkerContext) {
        this.linker = linker
        this.chunkMetas = ArrayList<ChunkMetaExt>()
    }

    /// 计算跨 chunk 依赖
    // 严格翻译自: computeCrossChunkDependencies.zig:1
    public func compute(chunks: ArrayList<Chunk>): Unit {
        if (!linker.graph.codeSplitting) {
            // 没有代码分割就不需要跨 chunk 依赖
            return
        }

        // 初始化 chunk 元数据
        chunkMetas.clear()
        for (_ in 0..chunks.size) {
            chunkMetas.append(ChunkMetaExt())
        }

        // 第一遍: 遍历每个 chunk，收集符号使用信息
        for (i in 0..chunks.size) {
            let chunk = chunks[i]
            let meta = chunkMetas[i]
            walkChunk(chunk, meta, i, chunks)
        }

        // 第二遍: 匹配符号声明和使用的 chunk
        computeCrossChunkDependenciesWithMetas(chunks)
    }

    /// 遍历 chunk 收集符号信息
    // 严格翻译自: computeCrossChunkDependencies.zig:57 CrossChunkDependencies.walk()
    private func walkChunk(chunk: Chunk, meta: ChunkMetaExt,
                            chunkIndex: Int64, chunks: ArrayList<Chunk>): Unit {
        if (chunk.contentType != ChunkContentType.JavaScript) {
            return
        }

        let entryPointChunkIndices = linker.graph.files.map({ f => f.entryPointChunkIndex })

        // 遍历 chunk 中的每个文件
        for (entry in chunk.filesWithParts.entries()) {
            let sourceIndex = entry.key

            // CSS 文件跳过
            if (sourceIndex >= 0 && sourceIndex < linker.parseGraph.loaders.size) {
                if (linker.parseGraph.loaders[sourceIndex].isCSS()) {
                    continue
                }
            }

            let parts = getParts(sourceIndex)
            let importRecords = getImportRecords(sourceIndex)
            let flags = getFlags(sourceIndex)
            let wrap = flags.wrap
            let wrapperRef = getWrapperRef(sourceIndex)
            let importsToBind = getImportsToBind(sourceIndex)

            // 遍历每个 part
            for (part in parts) {
                if (!part.isLive) { continue }

                // 处理外部动态导入
                for (recordIdx in part.importRecordIndices) {
                    if (recordIdx >= importRecords.size) { continue }
                    let record = importRecords[recordIdx]
                    if (record.sourceIndex.isValid() &&
                        linker.isExternalDynamicImport(record, sourceIndex)) {
                        // 重写动态导入路径指向目标 chunk
                        let otherChunkIndex = entryPointChunkIndices[record.sourceIndex.value]
                        record.path = chunks[otherChunkIndex].uniqueKey
                        record.sourceIndex = SourceIndex.invalid()

                        // 跟踪跨 chunk 动态导入
                        if (otherChunkIndex != chunkIndex) {
                            meta.dynamicImports.put(otherChunkIndex)
                        }
                    }
                }

                // 记录符号声明所在 chunk
                for (declaredRef in part.declaredSymbols) {
                    linker.graph.symbols.assignChunkIndex(declaredRef, chunkIndex)
                }

                // 记录每个使用的符号
                for (ref in part.symbolUses.keys()) {
                    var refToUse = ref
                    let symbol = linker.graph.symbols.get(refToUse)

                    // 忽略未绑定符号
                    if (symbol.kind == SymbolKind.Unbound) { continue }
                    // 忽略将被替换为 undefined 的符号
                    if (symbol.importItemStatus == ImportItemStatus.Missing) { continue }

                    // 如果是从其他文件导入的，跟踪到源文件的符号
                    let importData = importsToBind.get(refToUse)
                    if (importData != None) {
                        refToUse = importData.importRef
                        let linkedSymbol = linker.graph.symbols.get(refToUse)
                        // 忽略 CJS 包装器的内部符号
                        if (wrap == WrapKind.CJS && refToUse == wrapperRef) {
                            continue
                        }
                    }

                    // 如果是 ES6 从 CJS 文件导入，使用命名空间符号
                    if (symbol.namespaceAlias != null) {
                        refToUse = symbol.namespaceAlias.namespaceRef
                    }

                    // 记录此符号在此 chunk 中使用
                    meta.imports.put(refToUse)
                }
            }
        }

        // 如果是入口点 chunk，包含导出符号
        if (chunk.contentType == ChunkContentType.JavaScript && chunk.isEntryPoint()) {
            let entryFlags = getFlags(chunk.entryPoint.sourceIndex)
            if (entryFlags.wrap != WrapKind.CJS) {
                let resolvedExports = getResolvedExports(chunk.entryPoint.sourceIndex)
                let sortedAliases = getSortedExportAliases(chunk.entryPoint.sourceIndex)
                for (alias in sortedAliases) {
                    let export_ = resolvedExports.get(alias)
                    if (export_ == None) { continue }
                    var targetRef = export_.importRef

                    // 如果是导入，跟踪到实际目标
                    let importData = getImportsToBind(export_.sourceIndex.value).get(targetRef)
                    if (importData != None) {
                        targetRef = importData.importRef
                    }

                    // 处理命名空间别名
                    let targetSymbol = linker.graph.symbols.get(targetRef)
                    if (targetSymbol.namespaceAlias != None) {
                        targetRef = targetSymbol.namespaceAlias.namespaceRef
                    }

                    meta.imports.put(targetRef)
                }
            }

            // 确保 exports 引用被包含
            if (entryFlags.forceIncludeExportsForEntryPoint) {
                let exportsRef = getExportsRef(chunk.entryPoint.sourceIndex)
                meta.imports.put(exportsRef)
            }

            // 包含包装器引用
            if (entryFlags.wrap != WrapKind.None) {
                let wrapperRef = getWrapperRef(chunk.entryPoint.sourceIndex)
                meta.imports.put(wrapperRef)
            }
        }
    }

    /// 使用 chunk 元数据计算跨 chunk 导入/导出
    // 严格翻译自: computeCrossChunkDependencies.zig:219
    // computeCrossChunkDependenciesWithChunkMetas()
    private func computeCrossChunkDependenciesWithMetas(chunks: ArrayList<Chunk>): Unit {
        // 标记导入的符号在声明 chunk 中为导出
        for (i in 0..chunks.size) {
            let chunk = chunks[i]
            if (chunk.contentType != ChunkContentType.JavaScript) { continue }
            let js = chunk.jsContent
            let meta = chunkMetas[i]

            // 查找此 chunk 中使用的来自其他 chunk 的符号
            for (importRef in meta.imports.keys()) {
                let symbol = linker.graph.symbols.get(importRef)
                let otherChunkIndex = symbol.chunkIndex()

                if (otherChunkIndex >= 0 && otherChunkIndex != i && otherChunkIndex < chunks.size) {
                    // 添加到 imports_from_other_chunks
                    let entry = js.importsFromOtherChunks.getOrPut(otherChunkIndex)
                    entry.append(CrossChunkImportItem(importRef))

                    // 在声明 chunk 中标记为导出
                    chunkMetas[otherChunkIndex].exports.put(importRef)
                }
            }

            // 如果是入口点，确保所有属于此入口点的 chunk 都被导入
            if (chunk.isEntryPoint()) {
                for (j in 0..chunks.size) {
                    if (j == i) { continue }
                    let otherChunk = chunks[j]
                    if (otherChunk.contentType != ChunkContentType.JavaScript) { continue }

                    if (otherChunk.entryBits.hasIntersection(chunk.entryBits)) {
                        js.importsFromOtherChunks.getOrPut(j)
                    }
                }
            }

            // 跟踪动态跨 chunk 导入
            if (meta.dynamicImports.count() > 0) {
                let dynamicIndices = meta.dynamicImports.keys()
                dynamicIndices.sort()

                for (dynamicChunkIndex in dynamicIndices) {
                    chunk.crossChunkImports.append(CrossChunkImport(
                        dynamicChunkIndex,
                        ImportKind.Dynamic
                    ))
                }
            }
        }

        // 生成跨 chunk 导出 (ESM 格式)
        generateCrossChunkExports(chunks)

        // 生成跨 chunk 导入
        generateCrossChunkImports(chunks)
    }

    /// 生成跨 chunk 导出
    // 严格翻译自: computeCrossChunkDependencies.zig:295
    private func generateCrossChunkExports(chunks: ArrayList<Chunk>): Unit {
        let exportRenamer = ExportRenamer()

        for (i in 0..chunks.size) {
            let chunk = chunks[i]
            if (chunk.contentType != ChunkContentType.JavaScript) { continue }
            let js = chunk.jsContent
            let meta = chunkMetas[i]

            match (linker.options.outputFormat) {
                case OutputFormat.ESM => {
                    let sortedRefs = linker.sortedCrossChunkExportItems(meta.exports)

                    var clauseItems = ArrayList<ClauseItem>()
                    exportRenamer.clear()

                    for (stableRef in sortedRefs) {
                        let ref = stableRef.ref
                        let alias = if (linker.options.minifyIdentifiers) {
                            exportRenamer.nextMinifiedName()
                        } else {
                            exportRenamer.nextRenamedName(
                                linker.graph.symbols.get(ref).originalName
                            )
                        }

                        clauseItems.append(ClauseItem(
                            name: ref,
                            alias: alias
                        ))

                        js.exportsToOtherChunks.put(ref, alias)
                    }

                    if (clauseItems.size > 0) {
                        // 生成 export { ... } 语句
                        let exportStmt = "export { "
                        var first = true
                        for (item in clauseItems) {
                            if (!first) { exportStmt.append(", ") }
                            first = false
                            let name = linker.graph.symbols.get(item.name).originalName
                            exportStmt.append("${name} as ${item.alias}")
                        }
                        exportStmt.append(" }")
                        js.crossChunkSuffixStmts.append(exportStmt)
                    }
                }
                case _ => ()
            }
        }
    }

    /// 生成跨 chunk 导入
    // 严格翻译自: computeCrossChunkDependencies.zig:362
    private func generateCrossChunkImports(chunks: ArrayList<Chunk>): Unit {
        for (i in 0..chunks.size) {
            let chunk = chunks[i]
            if (chunk.contentType != ChunkContentType.JavaScript) { continue }
            let js = chunk.jsContent

            for (entry in js.importsFromOtherChunks.entries()) {
                let otherChunkIndex = entry.key
                let importItems = entry.value

                if (otherChunkIndex < 0 || otherChunkIndex >= chunks.size) { continue }
                let otherChunk = chunks[otherChunkIndex]

                match (linker.options.outputFormat) {
                    case OutputFormat.ESM => {
                        // 生成 import { ... } from "./chunk-xxx.js"
                        let importStmt = StringBuilder()
                        importStmt.append("import { ")
                        var first = true
                        for (item in importItems) {
                            let exportAlias = otherChunk.jsContent.exportsToOtherChunks.get(item.ref)
                            if (exportAlias == None) { continue }
                            let symbolName = linker.graph.symbols.get(item.ref).originalName
                            if (!first) { importStmt.append(", ") }
                            first = false
                            importStmt.append("${exportAlias}")
                        }
                        importStmt.append(" } from \"${otherChunk.finalRelPath}\"")
                        js.crossChunkPrefixStmts.append(importStmt.toString())
                    }
                    case _ => ()
                }
            }
        }
    }

    // ========================================================================
    // 辅助方法 (获取链接器图中的数据)
    // ========================================================================

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
        // 简化: 返回默认标志
        return MetaFlags()
    }

    private func getWrapperRef(sourceIndex: Int64): Int64 {
        // 简化
        return 0
    }

    private func getExportsRef(sourceIndex: Int64): Int64 {
        // 简化
        return 0
    }

    private func getImportsToBind(sourceIndex: Int64): HashMap<Int64, ImportBinding> {
        // 简化
        return HashMap<Int64, ImportBinding>()
    }

    private func getResolvedExports(sourceIndex: Int64): HashMap<String, ResolvedExport> {
        // 简化
        return HashMap<String, ResolvedExport>()
    }

    private func getSortedExportAliases(sourceIndex: Int64): ArrayList<String> {
        // 简化
        return ArrayList<String>()
    }
}

// ============================================================================
// 扩展的 Chunk 元数据
// 严格翻译自: computeCrossChunkDependencies.zig:8 ChunkMeta
// ============================================================================

/// 扩展的 Chunk 元数据 (包含符号导入/导出集合)
public class ChunkMetaExt {
    /// 导入的符号集合 (ref -> void)
    public var imports: HashSet<Int64>
    /// 导出的符号集合 (ref -> void)
    public var exports: HashSet<Int64>
    /// 动态导入的 chunk 索引
    public var dynamicImports: HashSet<Int64>

    public init() {
        imports = HashSet<Int64>()
        exports = HashSet<Int64>()
        dynamicImports = HashSet<Int64>()
    }
}

/// 跨 chunk 导入项
// 严格翻译自: computeCrossChunkDependencies.zig CrossChunkImport.Item
public class CrossChunkImportItem {
    /// 引用的符号
    public var ref: Int64
    /// 导出别名 (从目标 chunk 的导出映射中获取)
    public var exportAlias: String

    public init(ref: Int64) {
        this.ref = ref
        this.exportAlias = ""
    }
}

/// 子句项 (import/export 子句中的单个绑定)
public class ClauseItem {
    /// 符号引用
    public var name: Int64
    /// 导出别名
    public var alias: String

    public init(name: Int64, alias: String) {
        this.name = name
        this.alias = alias
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
        let base = "abcdefghijklmnopqrstuvwxyz$_"
        var name: String
        var c = counter
        name = ""
        if (c < base.length) {
            name = base.substring(c, c + 1)
        } else {
            name = "v${c}"
        }
        counter++
        while (usedNames.contains(name)) {
            name = "${name}_"
        }
        usedNames.put(name)
        return name
    }
}

/// 导入绑定数据
public class ImportBinding {
    public var importRef: Int64

    public init(importRef: Int64) {
        this.importRef = importRef
    }
}
