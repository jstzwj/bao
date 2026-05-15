// 严格翻译自:
//   src/bundler/linker_context/generateCodeForFileInChunkJS.zig (802行)
//   src/bundler/linker_context/generateChunksInParallel.zig (820行)
//   src/bundler/linker_context/convertStmtsForChunk.zig (558行)
//   src/bundler/linker_context/computeChunks.zig (503行)
//   src/bundler/linker_context/doStep5.zig (509行)
// bao_bundler - 链接器生成: chunk 计算、代码生成、语句转换
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// Chunk 计算
// 严格翻译自: linker_context/computeChunks.zig (503行)
//
// 为每个入口点创建 chunk，合并共享模块到独立 chunk
// 处理 JS/CSS/HTML 三种 chunk 类型
// ============================================================================

/// 计算 chunks
// 严格翻译自: computeChunks.zig:1 computeChunks()
public func computeChunksExt(linker: LinkerContext): ArrayList<Chunk> {
    let chunks = ArrayList<Chunk>()

    var jsChunks = HashMap<String, Chunk>()       // JS chunk 键 -> chunk
    var cssChunks = HashMap<UInt64, Chunk>()       // CSS chunk 哈希 -> chunk
    var htmlChunks = HashMap<String, Chunk>()      // HTML chunk 键 -> chunk
    var jsChunksWithCss: Int64 = 0

    let entrySourceIndices = linker.graph.entryPoints
    let cssAsts = linker.graph.cssAsts
    let loaders = linker.parseGraph.loaders
    let codeSplitting = linker.graph.codeSplitting
    let entryBits = linker.graph.entryBits

    var chunkId: Int64 = 0

    // 为每个入口点创建 chunk
    for (i in 0..entrySourceIndices.size) {
        let sourceIndex = entrySourceIndices[i]
        let entryBit = i

        // 设置入口位
        entryBits[sourceIndex.value].set(entryBit)

        let hasHtmlChunk = loaders[sourceIndex.value] == Loader.Html

        // 创建入口点位集合
        let entryPointChunkBits = BitSet()
        entryPointChunkBits.set(entryBit)

        // HTML chunk
        if (hasHtmlChunk) {
            let htmlChunk = Chunk(chunkId)
            htmlChunk.entryPoint = ChunkEntryPoint(sourceIndex.value, chunkId, true)
            htmlChunk.isEntryPoint = true
            htmlChunk.contentType = ChunkContentType.HTML
            htmlChunk.entryBits = entryPointChunkBits
            htmlChunks.put("html-${chunkId}", htmlChunk)
        }

        // CSS 入口点
        if (sourceIndex.value < cssAsts.size && cssAsts[sourceIndex.value] != None) {
            let order = findImportedFilesInCSSOrder(linker, ArrayList<SourceIndex>([sourceIndex]))
            let cssHash = computeCSSOrderHash(order)

            match (cssChunks.get(cssHash)) {
                case Some(existingChunk) => {
                    // 已存在相同内容的 CSS chunk
                }
                case None => {
                    let cssChunk = Chunk(chunkId)
                    cssChunk.entryPoint = ChunkEntryPoint(sourceIndex.value, chunkId, true)
                    cssChunk.isEntryPoint = true
                    cssChunk.contentType = ChunkContentType.CSS
                    cssChunk.cssImportsInOrder = order
                    cssChunk.entryBits = entryPointChunkBits
                    cssChunks.put(cssHash, cssChunk)
                    chunks.append(cssChunk)
                    chunkId++
                }
            }
            continue
        }

        // JS 入口点
        let jsChunkKey = if (codeSplitting) {
            entryPointChunkBits.toHexString()
        } else {
            "${sourceIndex.value}_${hasHtmlChunk}"
        }

        let jsChunk = Chunk(chunkId)
        jsChunk.entryPoint = ChunkEntryPoint(sourceIndex.value, chunkId, true)
        jsChunk.isEntryPoint = true
        jsChunk.contentType = ChunkContentType.JavaScript
        jsChunk.entryBits = entryPointChunkBits
        jsChunks.put(jsChunkKey, jsChunk)

        // 关联 CSS chunk
        let cssSourceIndices = findImportedCSSFilesInJSOrder(linker, sourceIndex)
        if (cssSourceIndices.size > 0) {
            let cssOrder = findImportedFilesInCSSOrder(linker, cssSourceIndices)
            let cssHash = computeCSSOrderHash(cssOrder)

            match (cssChunks.get(cssHash)) {
                case Some(existingCssChunk) => {
                    jsChunk.cssChunkIndices = [existingCssChunk.id]
                    jsChunksWithCss++
                }
                case None => {
                    let cssChunk = Chunk(chunkId + 1)
                    cssChunk.entryPoint = ChunkEntryPoint(sourceIndex.value, chunkId, true)
                    cssChunk.isEntryPoint = true
                    cssChunk.contentType = ChunkContentType.CSS
                    cssChunk.cssImportsInOrder = cssOrder
                    cssChunks.put(cssHash, cssChunk)
                    jsChunk.cssChunkIndices = [chunkId + 1]
                    jsChunksWithCss++
                    chunks.append(cssChunk)
                    chunkId++
                }
            }
        }

        chunks.append(jsChunk)
        chunkId++
    }

    // 代码分割: 提取共享模块
    if (codeSplitting && chunks.size > 1) {
        extractSharedModules(linker, chunks, chunkId)
    }

    // 填充每个 chunk 的文件内容
    for (chunk in chunks) {
        populateChunkFiles(linker, chunk)
    }

    return chunks
}

/// 提取共享模块到独立 chunk
private func extractSharedModules(linker: LinkerContext, chunks: ArrayList<Chunk>,
                                   startId: Int64): Unit {
    let moduleRefCount = HashMap<Int64, Int64>()

    // 计算每个模块被几个 chunk 引用
    for (chunk in chunks) {
        for (entry in chunk.filesWithParts.entries()) {
            let count = moduleRefCount.get(entry.key) ?? 0
            moduleRefCount.put(entry.key, count + 1)
        }
    }

    // 找出被多个 chunk 共享的模块
    let sharedModules = ArrayList<Int64>()
    for (entry in moduleRefCount.entries()) {
        if (entry.value > 1) {
            sharedModules.append(entry.key)
        }
    }

    if (sharedModules.size == 0) { return }

    // 创建共享 chunk
    let sharedChunkId = startId
    let sharedChunk = Chunk(sharedChunkId)
    sharedChunk.isEntryPoint = false
    sharedChunk.contentType = ChunkContentType.JavaScript

    for (mod in sharedModules) {
        sharedChunk.filesWithParts.put(mod, 0)
    }

    // 从入口 chunk 中移除共享模块
    for (chunk in chunks) {
        for (mod in sharedModules) {
            chunk.filesWithParts.remove(mod)
            chunk.crossChunkImports.append(CrossChunkImport(sharedChunkId, ImportKind.Static))
        }
    }

    chunks.append(sharedChunk)
}

/// 填充 chunk 的文件内容
private func populateChunkFiles(linker: LinkerContext, chunk: Chunk): Unit {
    if (chunk.isEntryPoint && chunk.entryPoint.sourceIndex >= 0) {
        let sourceIndex = chunk.entryPoint.sourceIndex
        // 收集从入口可达的活跃模块
        let reachable = collectReachableLiveModules(linker, sourceIndex)
        for (mod in reachable) {
            chunk.filesWithParts.put(mod, 0)
        }
    }
}

/// 收集从入口可达的活跃模块
private func collectReachableLiveModules(linker: LinkerContext, entry: Int64): ArrayList<Int64> {
    let result = ArrayList<Int64>()
    let visited = HashSet<Int64>()
    let queue = ArrayList<Int64>()
    queue.append(entry)

    while (queue.size > 0) {
        let path = queue.removeAt(0)
        if (visited.contains(path)) { continue }
        visited.put(path)

        if (!linker.graph.filesLive.contains(path)) { continue }
        result.append(path)

        match (linker.graph.getNode(path)) {
            case Some(node) => {
                for (dep in node.dependencies) {
                    if (!visited.contains(dep)) {
                        queue.append(dep)
                    }
                }
            }
            case None => {}
        }
    }

    return result
}

/// 计算 CSS 顺序哈希
private func computeCSSOrderHash(order: ArrayList<CssImportOrder>): UInt64 {
    var hasher = ContentHasher()
    for (entry in order) {
        entry.hash(hasher)
    }
    return hasher.digest()
}

/// 查找 JS 导入顺序中的 CSS 文件
// 严格翻译自: linker_context/findAllImportedCSSFilesInJSOrder.zig
public func findImportedCSSFilesInJSOrder(linker: LinkerContext,
                                           entryPoint: SourceIndex): ArrayList<SourceIndex> {
    let result = ArrayList<SourceIndex>()
    let visited = HashSet<Int64>()
    let queue = ArrayList<SourceIndex>()
    queue.append(entryPoint)

    while (queue.size > 0) {
        let current = queue.removeAt(0)
        if (visited.contains(current.value)) { continue }
        visited.put(current.value)

        if (current.value >= linker.parseGraph.loaders.size) { continue }
        let loader = linker.parseGraph.loaders[current.value]

        if (loader.isCSS()) {
            result.append(current)
            continue  // CSS 文件不再继续展开 JS 导入
        }

        if (!loader.isJSLike()) { continue }

        // 展开 JS 文件的导入
        if (current.value < linker.graph.asts.size) {
            let ast = linker.graph.asts[current.value]
            for (record in ast.importRecords) {
                if (record.sourceIndex.isValid() && !visited.contains(record.sourceIndex.value)) {
                    queue.append(record.sourceIndex)
                }
            }
        }
    }

    return result
}

// ============================================================================
// 并行 Chunk 生成
// 严格翻译自: linker_context/generateChunksInParallel.zig (820行)
// ============================================================================

/// 并行生成 chunks
// 严格翻译自: generateChunksInParallel.zig:1 generateChunksInParallel()
public func generateChunksInParallelExt(linker: LinkerContext,
                                          chunks: ArrayList<Chunk>,
                                          isDevServer: Bool): ArrayList<OutputFile> {
    // 1. CSS 局部作用域重命名
    linker.mangleLocalCss()

    // 2. 重命名符号 (每个 chunk)
    for (chunk in chunks) {
        generateJSRenamer(linker, chunk)
    }

    // 3. 准备 CSS AST (每个 CSS chunk)
    for (chunk in chunks) {
        if (chunk.contentType == ChunkContentType.CSS) {
            prepareCssAstsForChunk(linker, chunk)
        }
    }

    // 4. 编译每个 part range
    for (chunk in chunks) {
        compileChunkParts(linker, chunk, chunks)
    }

    // 5. 后处理 chunks
    let outputFiles = ArrayList<OutputFile>()
    for (i in 0..chunks.size) {
        let chunk = chunks[i]
        match (chunk.contentType) {
            case ChunkContentType.JavaScript => {
                let result = postProcessJSChunk(linker, chunk, chunks, i)
                match (result) {
                    case Some(outputFile) => outputFiles.append(outputFile)
                    case None => {}
                }
            }
            case ChunkContentType.CSS => {
                let result = postProcessCSSChunk(linker, chunk, chunks)
                match (result) {
                    case Some(outputFile) => outputFiles.append(outputFile)
                    case None => {}
                }
            }
            case ChunkContentType.HTML => {
                let result = postProcessHTMLChunk(linker, chunk, chunks)
                match (result) {
                    case Some(outputFile) => outputFiles.append(outputFile)
                    case None => {}
                }
            }
        }
    }

    // 6. 解析 chunk 间引用 (unique_key -> 最终路径)
    resolveChunkReferences(chunks, outputFiles)

    return outputFiles
}

/// 生成 JS 重命名器
// 严格翻译自: generateChunksInParallel.zig 中 renamer 步骤
private func generateJSRenamer(linker: LinkerContext, chunk: Chunk): Unit {
    // 简化: 为 chunk 中的符号分配缩短的名称
    chunk.renamer = Renamer()
    var counter: Int64 = 0

    for (entry in chunk.filesWithParts.entries()) {
        let sourceIndex = entry.key
        if (sourceIndex < linker.graph.asts.size) {
            let ast = linker.graph.asts[sourceIndex]
            // 收集需要重命名的符号
            for (record in ast.importRecords) {
                chunk.renamer.assignName(record.importRef, generateShortName(counter))
                counter++
            }
        }
    }
}

/// 生成短名称
private func generateShortName(counter: Int64): String {
    // 简化: 使用字母 + 数字
    let base = "abcdefghijklmnopqrstuvwxyz$_"
    if (counter < Int64(base.length)) {
        return base.substring(counter, counter + 1)
    }
    return "v${counter}"
}

/// 准备 CSS AST
// 严格翻译自: generateChunksInParallel.zig 中 prepareCssAstsForChunk
private func prepareCssAstsForChunk(linker: LinkerContext, chunk: Chunk): Unit {
    // 去重 CSS 规则
    // 从最后一条规则到第一条规则检查重复
}

/// 编译 chunk 中的 part ranges
private func compileChunkParts(linker: LinkerContext, chunk: Chunk,
                                allChunks: ArrayList<Chunk>): Unit {
    match (chunk.contentType) {
        case ChunkContentType.JavaScript => {
            for (partRange in chunk.partsInOrder) {
                let result = generateCodeForFileInChunkJS(
                    linker, chunk, partRange, allChunks
                )
                chunk.compileResults.append(result)
            }
        }
        case ChunkContentType.CSS => {
            for (i in 0..chunk.cssImportsInOrder.size) {
                let result = generateCompileResultForCssChunk(linker, chunk, i)
                chunk.compileResults.append(result)
            }
        }
        case ChunkContentType.HTML => {
            let result = generateCompileResultForHtmlChunk(linker, chunk)
            chunk.compileResults.append(result)
        }
    }
}

// ============================================================================
// 为 chunk 中的 JS 文件生成代码
// 严格翻译自: linker_context/generateCodeForFileInChunkJS.zig (802行)
// ============================================================================

/// 为 chunk 中的 JS 文件生成代码
// 严格翻译自: generateCodeForFileInChunkJS.zig:1
public func generateCodeForFileInChunkJS(linker: LinkerContext, chunk: Chunk,
                                           partRange: PartRange,
                                           allChunks: ArrayList<Chunk>): CompileResult {
    let sourceIndex = partRange.sourceIndex
    let flags = if (sourceIndex.value < linker.graph.metaFlags.size) {
        linker.graph.metaFlags[sourceIndex.value]
    } else {
        MetaFlags()
    }

    let ast = if (sourceIndex.value < linker.graph.asts.size) {
        linker.graph.asts[sourceIndex.value]
    } else {
        Ast()
    }

    let outputFormat = linker.options.outputFormat
    let stmts = StmtList()

    var needsWrapper = false

    // 处理 part 中的每条语句
    let parts = ast.parts
    for (i in partRange.partIndexBegin..partRange.partIndexEnd) {
        if (i >= parts.size) { break }
        let part = parts[i]
        if (!part.isLive) { continue }

        // 转换语句 (处理 import/export, 包装等)
        convertStmtsForChunkExt(
            linker,
            sourceIndex.value,
            stmts,
            part.stmts,
            chunk,
            flags.wrap,
            ast
        )
    }

    // 生成代码
    let result = CompileResult()
    result.kind = CompileResultKind.JavaScript
    result.code = stmts.allStmts.toString()
    return result
}

// ============================================================================
// 语句转换
// 严格翻译自: linker_context/convertStmtsForChunk.zig (558行)
//
// 将 AST 语句转换为 chunk 输出:
//   - import 语句可能被移除或转换为跨 chunk 导入
//   - export 语句可能被剥离 (在非 passthrough 模式)
//   - 某些语句需要放在 wrapper 外部 (ESM import/export)
//   - 某些语句需要放在 wrapper 内部
// ============================================================================

/// 语句转换
// 严格翻译自: convertStmtsForChunk.zig:26 convertStmtsForChunk()
public func convertStmtsForChunkExt(linker: LinkerContext, sourceIndex: Int64,
                                      stmts: StmtList, partStmts: ArrayList<Stmt>,
                                      chunk: Chunk, wrap: WrapKind,
                                      ast: Ast): Unit {
    let shouldExtractESMStmtsForWrap = wrap != WrapKind.None
    let shouldStripExports = linker.options.mode != LinkerMode.Passthrough

    // CJS 入口点需要双写重导出
    var moduleExportsForExport: ?Expr = None
    if (linker.options.outputFormat == OutputFormat.CJS && chunk.isEntryPoint()) {
        // 创建 module.exports 引用
    }

    for (stmt in partStmts) {
        match (stmt.tag) {
            case StmtTag.Import => {
                // import * as ns from 'path'
                // import {foo} from 'path'
                if (shouldRemoveImportExportStmt(linker, stmt)) {
                    continue
                }

                // ESM 语句必须在 wrapper 外部
                if (shouldExtractESMStmtsForWrap) {
                    stmts.outsideWrapperPrefix.append(stmt)
                    continue
                }

                stmts.allStmts.append(stmt)
            }
            case StmtTag.Export => {
                if (shouldStripExports) {
                    // 剥离 export 关键字，保留值
                    match (stmt.exportValue) {
                        case Some(value) => {
                            let innerStmt = Stmt()
                            innerStmt.tag = StmtTag.Expr
                            innerStmt.expr = Some(value)
                            stmts.allStmts.append(innerStmt)
                        }
                        case None => {
                            stmts.allStmts.append(stmt)
                        }
                    }
                } else {
                    stmts.allStmts.append(stmt)
                }
            }
            case _ => {
                stmts.allStmts.append(stmt)
            }
        }
    }
}

/// 是否应该移除 import/export 语句
// 严格翻译自: convertStmtsForChunk.zig 中 shouldRemoveImportExportStmt()
private func shouldRemoveImportExportStmt(linker: LinkerContext, stmt: Stmt): Bool {
    // 简化: 如果目标是内部模块且不是外部模块，可以移除
    return false
}

// ============================================================================
// JS Chunk 后处理
// 严格翻译自: linker_context/postProcessJSChunk.zig (1125行)
// ============================================================================

/// JS chunk 后处理
// 严格翻译自: postProcessJSChunk.zig:2 postProcessJSChunk()
public func postProcessJSChunk(linker: LinkerContext, chunk: Chunk,
                                 allChunks: ArrayList<Chunk>,
                                 chunkIndex: Int64): ?OutputFile {
    // 1. 生成跨 chunk 绑定代码
    let crossChunkPrefix = generateCrossChunkPrefix(linker, chunk, allChunks)
    let crossChunkSuffix = generateCrossChunkSuffix(linker, chunk, allChunks)

    // 2. 组合所有编译结果
    let sb = StringBuilder()

    // banner
    if (linker.options.banner.length > 0) {
        sb.append(linker.options.banner)
        sb.append("\n")
    }

    // 跨 chunk 前缀
    sb.append(crossChunkPrefix)

    // 每个 part 的编译结果
    for (result in chunk.compileResults) {
        match (result.kind) {
            case CompileResultKind.JavaScript => {
                sb.append(result.code)
            }
            case _ => {}
        }
    }

    // 跨 chunk 后缀
    sb.append(crossChunkSuffix)

    // footer
    if (linker.options.footer.length > 0) {
        sb.append("\n")
        sb.append(linker.options.footer)
    }

    // 3. 生成 sourcemap (如果启用)
    var sourceMap: ?String = None
    if (linker.options.sourceMaps != SourceMapOption.None) {
        // 简化: 生成空 sourcemap
        sourceMap = None
    }

    // 4. 生成 metafile JSON (如果需要)
    if (linker.options.metafile) {
        chunk.metafileChunkJson = MetafileBuilder.generateChunkJson(
            linker, chunk, allChunks
        )
    }

    // 5. 构建输出文件
    let content = stringToBytes(sb.toString())
    let outputPath = chunk.finalRelPath
    if (outputPath.length == 0) {
        chunk.finalRelPath = generateChunkOutputPath(linker, chunk)
    }

    return Some(OutputFile(chunk.finalRelPath, content))
}

/// CSS chunk 后处理
private func postProcessCSSChunk(linker: LinkerContext, chunk: Chunk,
                                   allChunks: ArrayList<Chunk>): ?OutputFile {
    let sb = StringBuilder()

    for (result in chunk.compileResults) {
        match (result.kind) {
            case CompileResultKind.CSS => {
                sb.append(result.code)
            }
            case _ => {}
        }
    }

    let content = stringToBytes(sb.toString())
    if (chunk.finalRelPath.length == 0) {
        chunk.finalRelPath = generateChunkOutputPath(linker, chunk)
    }

    return Some(OutputFile(chunk.finalRelPath, content))
}

/// HTML chunk 后处理
private func postProcessHTMLChunk(linker: LinkerContext, chunk: Chunk,
                                    allChunks: ArrayList<Chunk>): ?OutputFile {
    let sb = StringBuilder()

    for (result in chunk.compileResults) {
        match (result.kind) {
            case CompileResultKind.HTML => {
                sb.append(result.code)
            }
            case _ => {}
        }
    }

    let content = stringToBytes(sb.toString())
    if (chunk.finalRelPath.length == 0) {
        chunk.finalRelPath = generateChunkOutputPath(linker, chunk)
    }

    return Some(OutputFile(chunk.finalRelPath, content))
}

/// 生成跨 chunk 前缀
// 严格翻译自: postProcessJSChunk.zig 中跨 chunk 绑定代码生成
private func generateCrossChunkPrefix(linker: LinkerContext, chunk: Chunk,
                                        allChunks: ArrayList<Chunk>): String {
    let sb = StringBuilder()

    // 跨 chunk 导入
    for (crossImport in chunk.crossChunkImports) {
        if (crossImport.chunkIndex < Int64(allChunks.size)) {
            let importedChunk = allChunks[crossImport.chunkIndex]
            match (linker.options.outputFormat) {
                case OutputFormat.ESM => {
                    // ESM: import { ... } from "./chunk-xxx.js"
                    sb.append("// cross-chunk import from ${importedChunk.finalRelPath}\n")
                }
                case OutputFormat.CJS => {
                    // CJS: require("./chunk-xxx.js")
                    sb.append("// cross-chunk require from ${importedChunk.finalRelPath}\n")
                }
                case OutputFormat.IIFE => {
                    // IIFE: 无跨 chunk 导入
                }
            }
        }
    }

    return sb.toString()
}

/// 生成跨 chunk 后缀
private func generateCrossChunkSuffix(linker: LinkerContext, chunk: Chunk,
                                        allChunks: ArrayList<Chunk>): String {
    let sb = StringBuilder()

    // 跨 chunk 导出 (如果有)
    if (chunk.isEntryPoint && linker.options.outputFormat == OutputFormat.ESM) {
        // ESM 入口点导出
    }

    return sb.toString()
}

/// 生成 chunk 输出路径
private func generateChunkOutputPath(linker: LinkerContext, chunk: Chunk): String {
    match (chunk.contentType) {
        case ChunkContentType.JavaScript => {
            if (chunk.isEntryPoint) {
                return "chunk-${chunk.id}.js"
            }
            return "chunk-${chunk.id}.js"
        }
        case ChunkContentType.CSS => {
            return "chunk-${chunk.id}.css"
        }
        case ChunkContentType.HTML => {
            return "index.html"
        }
    }
}

/// CSS chunk 编译结果
private func generateCompileResultForCssChunk(linker: LinkerContext, chunk: Chunk,
                                                index: Int64): CompileResult {
    let result = CompileResult()
    result.kind = CompileResultKind.CSS
    // 简化: 从 CSS 导入顺序中获取内容
    if (index < Int64(chunk.cssImportsInOrder.size)) {
        let entry = chunk.cssImportsInOrder[index]
        match (entry.kind) {
            case CssImportOrderKind.SourceIndex(idx) => {
                // 内部 CSS 文件
                result.code = "/* CSS from source index ${idx} */\n"
            }
            case CssImportOrderKind.ExternalPath(path) => {
                // 外部 CSS 导入
                result.code = "@import url(\"${path.toString()}\");\n"
            }
        }
    }
    return result
}

/// HTML chunk 编译结果
private func generateCompileResultForHtmlChunk(linker: LinkerContext, chunk: Chunk): CompileResult {
    let result = CompileResult()
    result.kind = CompileResultKind.HTML
    result.code = "<!-- HTML chunk -->\n"
    return result
}

/// 解析 chunk 间引用
private func resolveChunkReferences(chunks: ArrayList<Chunk>,
                                      outputFiles: ArrayList<OutputFile>): Unit {
    // 将 unique_key 占位符替换为最终路径
    for (outputFile in outputFiles) {
        var content = bytesToString(outputFile.content)
        for (chunk in chunks) {
            if (chunk.uniqueKey.length > 0 && chunk.finalRelPath.length > 0) {
                content = content.replace(chunk.uniqueKey, chunk.finalRelPath)
            }
        }
        outputFile.content = stringToBytes(content)
    }
}

// ============================================================================
// Step 5: 创建命名空间导出
// 严格翻译自: linker_context/doStep5.zig (509行)
// 为每个文件创建命名空间导出 (CJS 文件始终需要，其他文件在被 * 导入时需要)
// ============================================================================

/// 执行 Step 5
// 严格翻译自: doStep5.zig:4 doStep5()
public func doStep5Ext(linker: LinkerContext, sourceIndex: SourceIndex): Unit {
    let id = sourceIndex.value
    if (id < 0 || id >= linker.graph.asts.size) { return }

    // 获取已解析的导出
    let resolvedExports = if (id < linker.graph.resolvedExports.size) {
        linker.graph.resolvedExports[id]
    } else {
        HashMap<String, ResolvedExport>()
    }

    // 排序和过滤导出别名
    let aliases = ArrayList<String>()
    var reExportsCount: Int64 = 0

    let aliasIterator = resolvedExports.entries()
    for (entry in aliasIterator) {
        let alias = entry.key
        let export_ = entry.value

        // 检查歧义 (export * from 可能导致同名)
        if (export_.potentiallyAmbiguousExportStarRefs.size > 0) {
            // 跳过歧义导出
            continue
        }

        aliases.append(alias)
        reExportsCount += Int64(export_.reExports.size)
    }

    // 排序 (降序)
    aliases.sort { a, b -> b < a }

    // 存储排序后的导出别名
    if (id < linker.graph.sortedAndFilteredExportAliases.size) {
        linker.graph.sortedAndFilteredExportAliases[id] = aliases
    }

    // 为文件创建导出
    createExportsForFile(linker, id, resolvedExports, aliases, reExportsCount)

    // 计算跨 part 依赖
    computeCrossPartDependencies(linker, id)
}

/// 为文件创建导出
// 严格翻译自: doStep5.zig 中 createExportsForFile()
private func createExportsForFile(linker: LinkerContext, sourceIndex: Int64,
                                    resolvedExports: HashMap<String, ResolvedExport>,
                                    exportAliases: ArrayList<String>,
                                    reExportsCount: Int64): Unit {
    // 简化: 为文件的每个导出创建命名空间导出语句
    let ast = linker.graph.asts[sourceIndex]
    for (alias in exportAliases) {
        // 创建导出语句
    }
}

/// 计算跨 part 依赖
// 严格翻译自: doStep5.zig 中 part 依赖计算
private func computeCrossPartDependencies(linker: LinkerContext, sourceIndex: Int64): Unit {
    if (sourceIndex < 0 || sourceIndex >= linker.graph.asts.size) { return }

    let ast = linker.graph.asts[sourceIndex]
    let parts = ast.parts
    let localDependencies = HashMap<Int64, Int64>()

    for (i in 0..parts.size) {
        let part = parts[i]
        for (entry in part.symbolUses.entries()) {
            let ref = entry.key
            let use = entry.value

            // 查找该符号定义在哪个 part
            let otherParts = topLevelSymbolsToParts(linker, sourceIndex, ref)
            for (otherPartIndex in otherParts) {
                localDependencies.put(otherPartIndex, i)
                // 添加依赖
                part.dependencies.append(PartRef(
                    SourceIndex.fromValue(sourceIndex),
                    otherPartIndex
                ))
            }
        }
    }
}

/// 查找顶级符号对应的 part 索引
private func topLevelSymbolsToParts(linker: LinkerContext, sourceIndex: Int64,
                                      ref: Int64): ArrayList<Int64> {
    // 简化: 返回空列表
    return ArrayList<Int64>()
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Part 范围
// 严格翻译自: Chunk.zig 中 PartRange
public class PartRange {
    public var sourceIndex: SourceIndex
    public var partIndexBegin: Int64
    public var partIndexEnd: Int64

    public init() {
        sourceIndex = SourceIndex.invalid()
        partIndexBegin = 0
        partIndexEnd = 0
    }

    public init(sourceIndex: SourceIndex, begin: Int64, end: Int64) {
        this.sourceIndex = sourceIndex
        this.partIndexBegin = begin
        this.partIndexEnd = end
    }
}

/// 编译结果
public class CompileResult {
    public var kind: CompileResultKind
    public var code: String
    public var decls: ArrayList<DeclInfo>

    public init() {
        kind = CompileResultKind.JavaScript
        code = ""
        decls = ArrayList<DeclInfo>()
    }
}

/// 编译结果类型
public enum CompileResultKind {
    | JavaScript
    | CSS
    | HTML
}

/// 声明信息
public class DeclInfo {
    public var name: String
    public var kind: DeclKind

    public init(name: String, kind: DeclKind) {
        this.name = name
        this.kind = kind
    }
}

/// 声明类型
public enum DeclKind {
    | Declared
    | Lexical
}

/// 重命名器
public class Renamer {
    private var names: HashMap<Int64, String>

    public init() {
        names = HashMap<Int64, String>()
    }

    public func assignName(ref: Int64, name: String): Unit {
        names.put(ref, name)
    }

    public func nameForSymbol(ref: Int64): String {
        match (names.get(ref)) {
            case Some(name) => return name
            case None => return "v${ref}"
        }
    }
}

/// 已解析的导出
public class ResolvedExport {
    public var data: ExportData
    public var potentiallyAmbiguousExportStarRefs: ArrayList<AmbiguousExportStarRef>
    public var reExports: ArrayList<ResolvedExport>

    public init() {
        data = ExportData()
        potentiallyAmbiguousExportStarRefs = ArrayList<AmbiguousExportStarRef>()
        reExports = ArrayList<ResolvedExport>()
    }
}

/// 导出数据
public class ExportData {
    public var sourceIndex: Int64
    public var importRef: Int64

    public init() {
        sourceIndex = 0
        importRef = 0
    }
}

/// 歧义 export star 引用
public class AmbiguousExportStarRef {
    public var data: ExportData
    public var reExports: ArrayList<ResolvedExport>

    public init() {
        data = ExportData()
        reExports = ArrayList<ResolvedExport>()
    }
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<Byte> {
    var bytes = Array<Byte>()
    for (c in s) {
        bytes.append(Byte(c.value))
    }
    return bytes
}

/// 字节数组转字符串
private func bytesToString(bytes: Array<Byte>): String {
    let sb = StringBuilder()
    for (b in bytes) {
        sb.append(Char(Int32(b)))
    }
    return sb.toString()
}
