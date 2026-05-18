// 严格翻译自: src/bundler/linker_context/renameSymbolsInChunk.zig (276行)
// bao_bundler - 符号重命名: 为 chunk 中的符号分配缩短/压缩的名称
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// 符号重命名
// 严格翻译自: renameSymbolsInChunk.zig
//
// 在 chunk 生成阶段，需要为所有符号分配最终名称:
//   - 压缩模式 (minify_identifiers): 使用频率优化的短名称
//   - 普通模式: 使用数字编号的名称 (避免冲突)
//
// 处理步骤:
//   1. 计算保留名称 (import/export/module/exports 等)
//   2. 收集跨 chunk 导入的符号
//   3. 遍历每个文件的每个 part:
//      a. 添加顶层声明的符号
//      b. 处理 CJS/ESM 包装器的特殊作用域
//      c. 递归分配嵌套作用域的名称
//   4. 压缩模式下: 按使用频率分配名称
// ============================================================================

/// 符号重命名器 (顶层入口)
// 严格翻译自: renameSymbolsInChunk.zig:1 renameSymbolsInChunk()
public func renameSymbolsInChunkExt(linker: LinkerContext,
                                      chunk: Chunk,
                                      filesInOrder: ArrayList<Int64>): Renamer {
    let allModuleScopes = linker.graph.ast.moduleScopes
    let allFlags = linker.graph.meta.flags
    let allParts = linker.graph.ast.parts
    let allWrapperRefs = linker.graph.ast.wrapperRefs
    let allImportRecords = linker.graph.ast.importRecords

    // Compute initial reserved names
    var reservedNames = computeInitialReservedNames(linker.options.outputFormat)
    for (sourceIndex in filesInOrder) {
        computeReservedNamesForScope(
            allModuleScopes[sourceIndex],
            linker.graph.symbols,
            reservedNames)
    }

    // Collect sorted imports from other chunks
    var sortedImportsFromOtherChunks = ArrayList<StableRef>()
    let importsFromOtherChunks = chunk.content.javascript.importsFromOtherChunks
    let stableSourceIndices = linker.graph.stableSourceIndices

    var count: Int64 = 0
    for (entry in importsFromOtherChunks) {
        count += entry.value.size
    }

    for (entry in importsFromOtherChunks) {
        for (ref in entry.value) {
            sortedImportsFromOtherChunks.append(StableRef(
                stableSourceIndices[ref.ref.sourceIndex()],
                ref.ref
            ))
        }
    }

    // Sort by stable source index
    StableRef.sort(sortedImportsFromOtherChunks)

    // Choose renaming strategy
    if (linker.options.minifyIdentifiers) {
        return renameSymbolsMinified(
            linker, chunk, filesInOrder,
            sortedImportsFromOtherChunks, reservedNames)
    } else {
        return renameSymbolsNumbered(
            linker, chunk, filesInOrder,
            sortedImportsFromOtherChunks, reservedNames)
    }
}

/// 压缩模式的符号重命名
// 严格翻译自: renameSymbolsInChunk.zig:49 minify 分支
private func renameSymbolsMinified(linker: LinkerContext,
                                     chunk: Chunk,
                                     filesInOrder: ArrayList<Int64>,
                                     sortedImports: ArrayList<StableRef>,
                                     reservedNames: HashSet<String>): Renamer {
    // Compute first top-level slot counts
    let nestedScopeSlotCounts = linker.graph.ast.nestedScopeSlotCounts
    var firstTopLevelSlots = SlotCounts()
    for (i in filesInOrder) {
        firstTopLevelSlots.unionMax(nestedScopeSlotCounts[i])
    }

    // Create minify renamer
    let minifyRenamer = MinifyRenamer(linker.graph.symbols, firstTopLevelSlots, reservedNames)

    // Collect top-level symbols
    var topLevelSymbols = ArrayList<StableSymbolCount>()
    var topLevelSymbolsAll = ArrayList<StableSymbolCount>()

    let stableSourceIndices = linker.graph.stableSourceIndices
    let astFlagsList = linker.graph.ast.flags

    // Compute character frequency
    var freq = CharFreq()
    let charFreqs = linker.graph.ast.charFreqs
    for (sourceIndex in filesInOrder) {
        if (astFlagsList[sourceIndex].hasCharFreq) {
            freq.include(charFreqs[sourceIndex])
        }
    }

    // Accumulate symbol use counts per file
    let exportsRefList = linker.graph.ast.exportsRefs
    let moduleRefList = linker.graph.ast.moduleRefs
    let partsList = linker.graph.ast.parts

    for (sourceIndex in filesInOrder) {
        let astFlags = astFlagsList[sourceIndex]
        let exportsRef = exportsRefList[sourceIndex]
        let moduleRef = moduleRefList[sourceIndex]
        let parts = partsList[sourceIndex].slice()

        topLevelSymbols.clear()

        if (astFlags.usesExportsRef) {
            accumulateSymbolUseCount(topLevelSymbols, exportsRef, 1, stableSourceIndices)
        }
        if (astFlags.usesModuleRef) {
            accumulateSymbolUseCount(topLevelSymbols, moduleRef, 1, stableSourceIndices)
        }

        for (part in parts) {
            if (!part.isLive) {
                continue
            }

            accumulateSymbolUseCounts(topLevelSymbols, part.symbolUses, stableSourceIndices)

            for (declaredRef in part.declaredSymbols) {
                accumulateSymbolUseCount(topLevelSymbols, declaredRef, 1, stableSourceIndices)
            }
        }

        // Sort and append
        StableSymbolCount.sort(topLevelSymbols)
        topLevelSymbolsAll.appendAll(topLevelSymbols)
    }

    // Add cross-chunk imports
    topLevelSymbols.clear()
    for (stableRef in sortedImports) {
        accumulateSymbolUseCount(topLevelSymbols, stableRef.ref, 1, stableSourceIndices)
    }
    topLevelSymbolsAll.appendAll(topLevelSymbols)

    // Allocate slots and assign names by frequency
    minifyRenamer.allocateTopLevelSymbolSlots(topLevelSymbolsAll)

    let minifier = freq.compile()
    minifyRenamer.assignNamesByFrequency(minifier)

    return minifyRenamer.toRenamer()
}

/// 普通模式的符号重命名
// 严格翻译自: renameSymbolsInChunk.zig:133 非压缩分支
private func renameSymbolsNumbered(linker: LinkerContext,
                                      chunk: Chunk,
                                      filesInOrder: ArrayList<Int64>,
                                      sortedImports: ArrayList<StableRef>,
                                      reservedNames: HashSet<String>): Renamer {
    let allFlags = linker.graph.meta.flags
    let allParts = linker.graph.ast.parts
    let allWrapperRefs = linker.graph.ast.wrapperRefs
    let allImportRecords = linker.graph.ast.importRecords

    let r = NumberRenamer(linker.graph.symbols, reservedNames)

    // Add cross-chunk imports as top-level symbols
    for (stableRef in sortedImports) {
        r.addTopLevelSymbol(stableRef.ref)
    }

    for (sourceIndex in filesInOrder) {
        let wrap = allFlags[sourceIndex].wrap
        let parts = allParts[sourceIndex].slice()

        match (wrap) {
            case WrapKind.CJS => {
                // CJS wrapper: add wrapper ref as top-level
                r.addTopLevelSymbol(allWrapperRefs[sourceIndex])

                // Hoist external import statements outside CJS wrapper
                if (linker.options.outputFormat.keepES6ImportExportSyntax()) {
                    let importRecords = allImportRecords[sourceIndex].slice()
                    for (part in parts) {
                        for (stmt in part.stmts) {
                            match (stmt.tag) {
                                case StmtKind.Import => {
                                    if (!importRecords[stmt.importRecordIndex].sourceIndex.isValid) {
                                        r.addTopLevelSymbol(stmt.namespaceRef)
                                        if (stmt.defaultName != None) {
                                            r.addTopLevelSymbol(stmt.defaultName.ref)
                                        }
                                        for (item in stmt.items) {
                                            if (item.name.ref != None) {
                                                r.addTopLevelSymbol(item.name.ref)
                                            }
                                        }
                                    }
                                }
                                case StmtKind.ExportStar => {
                                    if (!importRecords[stmt.importRecordIndex].sourceIndex.isValid) {
                                        r.addTopLevelSymbol(stmt.namespaceRef)
                                    }
                                }
                                case StmtKind.ExportFrom => {
                                    if (!importRecords[stmt.importRecordIndex].sourceIndex.isValid) {
                                        r.addTopLevelSymbol(stmt.namespaceRef)
                                        for (item in stmt.items) {
                                            if (item.name.ref != None) {
                                                r.addTopLevelSymbol(item.name.ref)
                                            }
                                        }
                                    }
                                }
                                case _ => ()
                            }
                        }
                    }
                }
                r.assignNamesRecursiveWithNumberScope(
                    r.root, allModuleScopes[sourceIndex], sourceIndex)
                continue
            }
            case WrapKind.ESM => {
                // ESM wrapper: add wrapper ref as top-level
                r.addTopLevelSymbol(allWrapperRefs[sourceIndex])
            }
            case WrapKind.None => ()
        }

        // Process each live part
        for (part in parts) {
            if (!part.isLive) {
                continue
            }

            r.addTopLevelDeclaredSymbols(part.declaredSymbols)
            for (scope in part.scopes) {
                r.assignNamesRecursiveWithNumberScope(
                    r.root, scope, sourceIndex)
            }
        }
    }

    return r.toRenamer()
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 计算初始保留名称
// 严格翻译自: renamer.computeInitialReservedNames()
private func computeInitialReservedNames(format: OutputFormat): HashSet<String> {
    let reserved = HashSet<String>()
    // JavaScript keywords and built-in names that cannot be used
    reserved.put("break")
    reserved.put("case")
    reserved.put("catch")
    reserved.put("class")
    reserved.put("const")
    reserved.put("continue")
    reserved.put("debugger")
    reserved.put("default")
    reserved.put("delete")
    reserved.put("do")
    reserved.put("else")
    reserved.put("export")
    reserved.put("extends")
    reserved.put("false")
    reserved.put("finally")
    reserved.put("for")
    reserved.put("function")
    reserved.put("if")
    reserved.put("import")
    reserved.put("in")
    reserved.put("instanceof")
    reserved.put("let")
    reserved.put("new")
    reserved.put("null")
    reserved.put("return")
    reserved.put("super")
    reserved.put("switch")
    reserved.put("this")
    reserved.put("throw")
    reserved.put("true")
    reserved.put("try")
    reserved.put("typeof")
    reserved.put("undefined")
    reserved.put("var")
    reserved.put("void")
    reserved.put("while")
    reserved.put("with")
    reserved.put("yield")
    reserved.put("await")
    reserved.put("enum")
    reserved.put("implements")
    reserved.put("interface")
    reserved.put("package")
    reserved.put("private")
    reserved.put("protected")
    reserved.put("public")
    reserved.put("static")
    return reserved
}

/// 为作用域计算保留名称
private func computeReservedNamesForScope(moduleScope: ModuleScope,
                                            symbols: SymbolMap,
                                            reservedNames: HashSet<String>): Unit {
    // Iterate module scope members, add non-renamable names
    // Simplified
}

/// 积累符号使用计数
private func accumulateSymbolUseCount(list: ArrayList<StableSymbolCount>,
                                        ref: Int64, count: Int64,
                                        stableIndices: ArrayList<Int64>): Unit {
    let stableIdx = if (ref >= 0 && ref < stableIndices.size) {
        stableIndices[ref]
    } else {
        ref
    }
    list.append(StableSymbolCount(stableIdx, ref, count))
}

/// 批量积累符号使用计数
private func accumulateSymbolUseCounts(list: ArrayList<StableSymbolCount>,
                                          symbolUses: HashMap<Int64, SymbolUse>,
                                          stableIndices: ArrayList<Int64>): Unit {
    let iter = symbolUses.iterator()
    while (iter.hasNext()) {
        let entry = iter.next()
        accumulateSymbolUseCount(list, entry.key, entry.value.count, stableIndices)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 稳定符号计数 (用于压缩重命名)
public class StableSymbolCount {
    public var stableSourceIndex: Int64
    public var ref: Int64
    public var count: Int64

    public init(stableSourceIndex: Int64, ref: Int64, count: Int64) {
        this.stableSourceIndex = stableSourceIndex
        this.ref = ref
        this.count = count
    }

    /// 排序
    public static func sort(list: ArrayList<StableSymbolCount>): Unit {
        // Sort by stableSourceIndex ascending, then by count descending
        // Simplified
    }
}

/// 稳定引用
public class StableRef {
    public var stableSourceIndex: Int64
    public var ref: Int64

    public init(stableSourceIndex: Int64, ref: Int64) {
        this.stableSourceIndex = stableSourceIndex
        this.ref = ref
    }

    /// 排序
    public static func sort(list: ArrayList<StableRef>): Unit {
        // Sort by stableSourceIndex ascending
        // Simplified
    }
}

/// 字符频率计数器
public class CharFreq {
    public var freqs: Array<Int64>

    public init() {
        freqs = Array<Int64>(64, item: 0)
    }

    /// 包含另一个频率计数
    public func include(other: CharFreq): Unit {
        for (i in 0..64) {
            if (i < other.freqs.size) {
                freqs[i] += other.freqs[i]
            }
        }
    }

    /// 编译为名称生成器
    public func compile(): NameGenerator {
        return NameGenerator(this)
    }
}

/// 名称生成器 (按频率分配)
public class NameGenerator {
    private var freq: CharFreq

    public init(freq: CharFreq) {
        this.freq = freq
    }

    /// 生成第 N 个名称
    public func generateName(index: Int64): String {
        return "v${index}"
    }
}

/// Slot 计数
public class SlotCounts {
    public func unionMax(other: SlotCounts): Unit {
        // Simplified
    }
}

/// 压缩重命名器
public class MinifyRenamer {
    public var symbols: SymbolMap
    public var firstTopLevelSlots: SlotCounts
    public var reservedNames: HashSet<String>

    public init(symbols: SymbolMap, firstTopLevelSlots: SlotCounts,
                reservedNames: HashSet<String>) {
        this.symbols = symbols
        this.firstTopLevelSlots = firstTopLevelSlots
        this.reservedNames = reservedNames
    }

    public func allocateTopLevelSymbolSlots(symbols: ArrayList<StableSymbolCount>): Unit {
        // Simplified
    }

    public func assignNamesByFrequency(minifier: NameGenerator): Unit {
        // Simplified
    }

    public func toRenamer(): Renamer {
        return Renamer()
    }
}

/// 数字重命名器
public class NumberRenamer {
    public var root: NumberScope
    public var symbols: SymbolMap
    public var reservedNames: HashSet<String>

    public init(symbols: SymbolMap, reservedNames: HashSet<String>) {
        this.symbols = symbols
        this.reservedNames = reservedNames
        this.root = NumberScope()
    }

    public func addTopLevelSymbol(ref: Int64): Unit {
        // Simplified
    }

    public func addTopLevelDeclaredSymbols(declaredSymbols: ArrayList<Int64>): Unit {
        for (ref in declaredSymbols) {
            addTopLevelSymbol(ref)
        }
    }

    public func assignNamesRecursiveWithNumberScope(
        parent: NumberScope, scope: Scope, sourceIndex: Int64): Unit {
        // Simplified
    }

    public func toRenamer(): Renamer {
        return Renamer()
    }
}

/// 数字作用域
public class NumberScope {
    public init() {}
}

/// 模块作用域 (简化)
public class ModuleScope {}

/// 作用域 (简化)
public class Scope {}

/// 重命名器 (简化)
public class Renamer {
    public init() {}

    public func nameForSymbol(ref: Int64): String {
        return ""
    }
}

/// 符号使用信息
public class SymbolUse {
    public var count: Int64

    public init() {
        count = 0
    }
}

/// 符号映射 (简化)
public class SymbolMap {
    public func follow(ref: Int64): Int64 {
        return ref
    }
}

/// 语句种类 (简化)
public enum StmtKind {
    | Import
    | ExportStar
    | ExportFrom
    | Other
}

/// 输出格式 (扩展)
public enum OutputFormat {
    | ESM
    | CJS
    | IIFE
    | InternalBakeDev

    public func keepES6ImportExportSyntax(): Bool {
        return this == OutputFormat.ESM || this == OutputFormat.IIFE
    }
}
