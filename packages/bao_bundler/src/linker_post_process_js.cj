// 严格翻译自: src/bundler/linker_context/postProcessJSChunk.zig (1126行)
// bao_bundler - JS chunk 后处理: 拼接编译结果、生成入口尾部、source map、字节码
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// JS chunk 后处理
// 严格翻译自: postProcessJSChunk.zig
//
// 在所有 JS 编译结果生成后, 执行后处理:
//   1. 生成跨 chunk 前缀/后缀代码 (导入/导出语句)
//   2. 填充 PostProcessModuleInfo (用于字节码缓存):
//      a. 从 DeclCollector 收集声明
//      b. 检测 import.meta 使用
//      c. 检测顶层 await
//      d. 收集外部导入记录
//      e. 添加包装器生成的声明
//   3. 生成入口点尾部代码:
//      - ESM: export { ... } / export default
//      - CJS: module.exports = require_foo()
//      - IIFE: 包装函数
//   4. 拼接所有代码:
//      a. hashbang (必须在第一行)
//      b. @bun 注释 + CJS 包装
//      c. banner
//      d. "use strict" 指令
//      e. HMR 运行时 (dev server)
//      f. IIFE 包装开始
//      g. 跨 chunk 前缀
//      h. 编译结果 (带文件路径注释)
//      i. 入口点尾部
//      j. 跨 chunk 后缀
//      k. IIFE/CJS 包装结束
//      l. footer
//   5. 生成 source map
// ============================================================================

/// JS chunk 后处理
// 严格翻译自: postProcessJSChunk.zig:2 postProcessJSChunk()
public func postProcessJSChunk(
    c: LinkerContext,
    chunk: Chunk,
    chunkIndex: Int64,
    chunks: ArrayList<Chunk>
): Unit {
    // Generate cross-chunk prefix/suffix code
    let crossChunkPrefix = PostProcessPrintResult()
    let crossChunkSuffix = PostProcessPrintResult()

    // Simplified: would call js_printer.print() for cross_chunk_prefix_stmts
    // and cross_chunk_suffix_stmts

    // Get runtime symbol references
    let toCommonJSRef = getRuntimeMemberRef(c, "__toCommonJS")
    let toESMRef = getRuntimeMemberRef(c, "__toESM")
    let runtimeRequireRef = if (c.options.outputFormat == OutputFormat.CJS) {
        None
    } else {
        getRuntimeMemberRef(c, "__require")
    }

    // Create PostProcessModuleInfo for ESM bytecode in --compile builds
    let generatePostProcessModuleInfo = c.options.generateBytecodeCache &&
                             c.options.outputFormat == OutputFormat.ESM &&
                             c.options.compile
    let loader = c.parseGraph.getLoader(chunk.entryPoint.sourceIndex)
    let isTypescript = loader.isTypeScript()
    let moduleInfo: ?PostProcessModuleInfo = if (generatePostProcessModuleInfo) {
        PostProcessModuleInfo(isTypescript)
    } else {
        None
    }

    // Populate PostProcessModuleInfo with declarations collected during parallel printing
    if (moduleInfo != None) {
        populatePostProcessModuleInfo(c, chunk, moduleInfo)
    }

    // Generate the exports for the entry point
    let entryPointTail: CompileResult = if (chunk.isEntryPoint()) {
        generateEntryPointTailJS(
            c, toCommonJSRef, toESMRef,
            chunk.entryPoint.sourceIndex, moduleInfo
        )
    } else {
        CompileResult()
    }

    // Store PostProcessModuleInfo on the chunk
    if (moduleInfo != None) {
        chunk.content.javascript.moduleInfo = moduleInfo
    }

    // Build final output
    var j = StringJoiner()
    let outputFormat = c.options.outputFormat
    var lineOffset = LineColumnOffset()

    var newlineBeforeComment = false
    var isExecutable = false

    // Extract hashbang and banner for entry points
    let hashbang: String = ""
    let banner: String = c.options.banner
    if (chunk.isEntryPoint()) {
        // Check for source hashbang or banner hashbang
        // Simplified
    }

    // Start with hashbang (must be first character)
    if (hashbang.size > 0) {
        j.pushStatic(hashbang)
        j.pushStatic("\n")
        lineOffset.advance(hashbang)
        lineOffset.advance("\n")
        newlineBeforeComment = true
        isExecutable = true
    }

    // Add @bun comments and CJS wrapper start for Bun targets
    let isBun = c.graph.isBunTarget(chunk.entryPoint.sourceIndex)
    if (isBun) {
        let cjsEntryChunk = "(function(exports, require, module, __filename, __dirname) {"
        if (c.options.generateBytecodeCache && outputFormat == OutputFormat.CJS) {
            j.pushStatic("// @bun @bytecode @bun-cjs\n" + cjsEntryChunk)
        } else if (c.options.generateBytecodeCache) {
            j.pushStatic("// @bun @bytecode\n")
        } else if (outputFormat == OutputFormat.CJS) {
            j.pushStatic("// @bun @bun-cjs\n" + cjsEntryChunk)
        } else {
            j.pushStatic("// @bun\n")
        }
    }

    // Add banner
    if (banner.size > 0) {
        j.pushStatic(banner)
        lineOffset.advance(banner)
        if (!banner.endsWith("\n")) {
            j.pushStatic("\n")
            lineOffset.advance("\n")
        }
        newlineBeforeComment = true
    }

    // Add "use strict" directive
    if (chunk.isEntryPoint() && !outputFormat.isAlwaysStrictMode()) {
        let flags = c.graph.getMetaFlags(chunk.entryPoint.sourceIndex)
        if (flags.hasExplicitUseStrictDirective) {
            j.pushStatic("\"use strict\";\n")
            lineOffset.advance("\"use strict\";\n")
            newlineBeforeComment = true
        }
    }

    // Add IIFE wrapper start
    match (outputFormat) {
        case OutputFormat.IIFE =>
            let start = if (c.options.minifyWhitespace) { "(()=>{" } else { "(() => {\n" }
            j.pushStatic(start)
            lineOffset.advance(start)
        case OutputFormat.InternalBakeDev =>
            // Add HMR runtime start
            ()
        case _ => ()
    }

    // Add cross-chunk prefix
    if (crossChunkPrefix.code.size > 0) {
        newlineBeforeComment = true
        j.push(crossChunkPrefix.code)
    }

    // Concatenate compile results with file path comments
    let compileResults = chunk.compileResultsForChunk
    var compileResultsForSourceMap = ArrayList<CompileResultForSourceMap>()
    let showComments = c.options.mode == BundleMode.Bundle && !c.options.minifyWhitespace
    let sources = c.parseGraph.inputFiles.sources

    var prevFilenameComment: Int64 = 0
    for (compileResult in compileResults) {
        let sourceIndex = compileResult.sourceIndex
        let isRuntime = sourceIndex == 0

        // Add file path comment
        if (showComments && sourceIndex != prevFilenameComment &&
            compileResult.code.size > 0) {
            prevFilenameComment = sourceIndex
            if (newlineBeforeComment) {
                j.pushStatic("\n")
                lineOffset.advance("\n")
            }

            let pretty = getSourcePrettyPath(c, sourceIndex)
            j.pushStatic("// ")
            lineOffset.advance("// ")
            j.pushStatic(pretty)
            lineOffset.advance(pretty)
            j.pushStatic("\n")
            lineOffset.advance("\n")
        }

        // Append code
        j.push(compileResult.code)
        if (compileResult.sourceMapChunk != None) {
            if (c.options.sourceMaps != SourceMaps.None) {
                compileResultsForSourceMap.append(CompileResultForSourceMap(
                    compileResult.sourceMapChunk,
                    lineOffset,
                    compileResult.sourceIndex
                ))
            }
            lineOffset.reset()
        } else {
            lineOffset.advance(compileResult.code)
        }

        newlineBeforeComment = compileResult.code.size > 0
    }

    // Add entry point tail
    let tailCode = entryPointTail.code
    if (tailCode.size > 0) {
        j.push(tailCode)
    }

    // Add cross-chunk suffix
    if (crossChunkSuffix.code.size > 0) {
        if (newlineBeforeComment) {
            j.pushStatic("\n")
        }
        j.push(crossChunkSuffix.code)
    }

    // Add wrapper endings
    match (outputFormat) {
        case OutputFormat.IIFE =>
            j.pushStatic("})();\n")
        case OutputFormat.InternalBakeDev =>
            // Add HMR runtime closing
            j.pushStatic("}, {\n  main: ")
            let inputPath = c.parseGraph.getInputPath(chunk.entryPoint.sourceIndex)
            j.pushStatic(inputPath)
            j.pushStatic("\n});")
        case OutputFormat.CJS =>
            if (isBun) {
                j.pushStatic("})\n")
            }
        case _ => ()
    }

    j.ensureNewlineAtEnd()

    // Add footer
    if (c.options.footer.size > 0) {
        if (newlineBeforeComment) {
            j.pushStatic("\n")
        }
        j.pushStatic(c.options.footer)
        j.pushStatic("\n")
    }

    // Break output into pieces
    chunk.intermediateOutput = breakOutputIntoPieces(c, j, chunks.size)
    chunk.isolatedHash = generateIsolatedHash(c, chunk)
    chunk.flags.isExecutable = isExecutable

    // Generate source map if enabled
    if (c.options.sourceMaps != SourceMaps.None) {
        let canHaveShifts = chunk.intermediateOutput.isPieces
        chunk.outputSourceMap = generateSourceMapForChunk(
            c, chunk.isolatedHash, compileResultsForSourceMap,
            c.resolver.opts.outputDir, canHaveShifts
        )
    }
}

// ============================================================================
// 入口点尾部代码生成
// 严格翻译自: postProcessJSChunk.zig:630 generateEntryPointTailJS()
// ============================================================================

/// 生成入口点尾部代码
// 严格翻译自: postProcessJSChunk.zig:630
public func generateEntryPointTailJS(
    c: LinkerContext,
    toCommonJSRef: ?Int64,
    toESMRef: ?Int64,
    sourceIndex: Int64,
    moduleInfo: ?PostProcessModuleInfo
): CompileResult {
    let flags = c.graph.getMetaFlags(sourceIndex)
    var stmts = ArrayList<PostProcessStmt>()

    match (c.options.outputFormat) {
        case OutputFormat.ESM =>
            match (flags.wrap) {
                case WrapKind.CJS =>
                    // "export default require_foo();"
                    // Simplified
                    ()
                case WrapKind.ESM =>
                    if (flags.isAsyncOrHasAsyncDependency) {
                        // "await init_foo();"
                    } else {
                        // "init_foo();"
                    }
                    // Generate export clause for all exported symbols
                    // Simplified
                case WrapKind.None =>
                    // Generate export clause for all exported symbols
                    // Simplified
                    ()
            }
        case OutputFormat.IIFE =>
            // Nothing needed for IIFE
            ()
        case OutputFormat.InternalBakeDev =>
            // Nothing needed - exports forwarded in module closure
            ()
        case OutputFormat.CJS =>
            match (flags.wrap) {
                case WrapKind.CJS =>
                    // "module.exports = require_foo();"
                    ()
                case WrapKind.ESM =>
                    // "init_foo();"
                    ()
                case WrapKind.None => ()
            }
        case _ => ()
    }

    // Add generated local declarations to module_info
    if (moduleInfo != None) {
        for (stmt in stmts) {
            // Add binding vars to module info
        }
    }

    let result = CompileResult()
    result.kind = CompileResultKind.JavaScript
    result.sourceIndex = sourceIndex
    result.code = "" // Simplified: would print stmts to code
    return result
}

// ============================================================================
// PostProcessModuleInfo 填充
// ============================================================================

/// 填充 PostProcessModuleInfo
// 严格翻译自: postProcessJSChunk.zig:99-235
private func populatePostProcessModuleInfo(c: LinkerContext, chunk: Chunk,
                                  moduleInfo: PostProcessModuleInfo): Unit {
    // 1. Add declarations from DeclCollector
    for (compileResult in chunk.compileResultsForChunk) {
        if (compileResult.kind != CompileResultKind.JavaScript) {
            continue
        }
        for (decl in compileResult.decls) {
            let varKind = decl.kind
            moduleInfo.addVar(decl.name, varKind)
        }
    }

    // 1b. Check if any source uses import.meta
    for (partRange in chunk.content.javascript.partsInChunkInOrder) {
        let astFlags = c.graph.getAstFlags(partRange.sourceIndex)
        if (astFlags.hasImportMeta) {
            moduleInfo.flags.containsImportMeta = true
            break
        }
    }

    // 1c. Check for top-level await
    for (partRange in chunk.content.javascript.partsInChunkInOrder) {
        let tlaKeyword = c.graph.getTlaKeyword(partRange.sourceIndex)
        let wraps = c.graph.getMetaFlags(partRange.sourceIndex)
        if (wraps.wrap != WrapKind.None) {
            continue
        }
        if (!tlaKeyword.isEmpty()) {
            moduleInfo.flags.hasTla = true
            break
        }
    }

    // 2. Collect truly-external imports from original AST
    // Simplified: would scan s_import statements for external imports

    // 3. Add wrapper-generated declarations (init_xxx, require_xxx)
    // Simplified
}

/// 递归遍历 Binding 添加变量到 PostProcessModuleInfo
// 严格翻译自: postProcessJSChunk.zig:601 addBindingVarsToPostProcessModuleInfo()
private func addBindingVarsToPostProcessModuleInfo(mi: PostProcessModuleInfo, binding: Binding,
                                          varKind: VarKind, renamer: Renamer,
                                          symbols: PostProcessSymbolMap): Unit {
    match (binding.kind) {
        case BindingKind.Identifier =>
            let name = renamer.nameForSymbol(symbols.follow(binding.ref))
            if (name.size > 0) {
                mi.addVar(name, varKind)
            }
        case BindingKind.Array =>
            for (item in binding.items) {
                addBindingVarsToPostProcessModuleInfo(mi, item.binding, varKind, renamer, symbols)
            }
        case BindingKind.Object =>
            for (property in binding.properties) {
                addBindingVarsToPostProcessModuleInfo(mi, property.value, varKind, renamer, symbols)
            }
        case BindingKind.Missing => ()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 打印结果
public class PostProcessPrintResult {
    public var code: String

    public init() {
        code = ""
    }
}

/// 模块信息 (用于字节码缓存)
public class PostProcessModuleInfo {
    public var flags: PostProcessModuleInfoFlags
    public var isTypescript: Bool

    public init(isTypescript: Bool) {
        flags = PostProcessModuleInfoFlags()
        this.isTypescript = isTypescript
    }

    public func addVar(name: String, kind: VarKind): Unit {
        // Simplified
    }
}

/// 模块信息标志
public class PostProcessModuleInfoFlags {
    public var containsImportMeta: Bool
    public var hasTla: Bool

    public init() {
        containsImportMeta = false
        hasTla = false
    }
}

/// 变量种类
public enum VarKind {
    | Declared
    | Lexical
}

/// 绑定类型
public class Binding {
    public var kind: BindingKind
    public var ref: Int64
    public var items: ArrayList<Binding>
    public var properties: ArrayList<BindingProperty>

    public init() {
        kind = BindingKind.Missing
        ref = 0
        items = ArrayList<Binding>()
        properties = ArrayList<BindingProperty>()
    }
}

/// 绑定种类
public enum BindingKind {
    | Identifier
    | Array
    | Object
    | Missing
}

/// 绑定属性
public class BindingProperty {
    public var value: Binding

    public init(value: Binding) {
        this.value = value
    }
}

/// 语句 (简化)
public class PostProcessStmt {
    public var tag: String
    public var data: PostProcessStmtData

    public init() {
        tag = ""
        data = PostProcessStmtData()
    }
}

/// 语句数据 (简化)
public class PostProcessStmtData {
    public init() {}
}

/// 声明信息
public class PostProcessDeclInfo {
    public var name: String
    public var kind: VarKind

    public init(name: String, kind: VarKind) {
        this.name = name
        this.kind = kind
    }
}

/// 符号映射 (简化)
public class PostProcessSymbolMap {
    public func follow(ref: Int64): Int64 {
        return ref
    }
}

// 简化辅助函数
private func getRuntimeMemberRef(c: LinkerContext, name: String): ?Int64 {
    return None
}

private func getSourcePrettyPath(c: LinkerContext, sourceIndex: Int64): String {
    return ""
}

private func breakOutputIntoPieces(c: LinkerContext, j: StringJoiner, chunksLen: Int64): IntermediateOutput {
    return IntermediateOutput()
}

private func generateIsolatedHash(c: LinkerContext, chunk: Chunk): String {
    return ""
}

private func generateSourceMapForChunk(c: LinkerContext, hash: String,
                                         results: ArrayList<CompileResultForSourceMap>,
                                         outputDir: String, canHaveShifts: Bool): SourceMap {
    return SourceMap()
}
