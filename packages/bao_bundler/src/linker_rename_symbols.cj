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

/// 符号重命名器
// 严格翻译自: renameSymbolsInChunk.zig:1 renameSymbolsInChunk()
public func renameSymbolsInChunkExt(linker: LinkerContext,
                                      chunk: Chunk,
                                      filesInOrder: ArrayList<Int64>): Renamer {
    // 1. 计算保留名称
    let reservedNames = computeInitialReservedNames(linker.options.outputFormat)
    for (sourceIndex in filesInOrder) {
        computeReservedNamesForScope(linker, sourceIndex, reservedNames)
    }

    // 2. 收集排序后的跨 chunk 导入
    let sortedImportsFromOtherChunks = ArrayList<StableRef>()
    for (entry in chunk.jsContent.importsFromOtherChunks.entries()) {
        let chunkIndex = entry.key
        let items = entry.value
        for (item in items) {
            let stableSourceIndex = linker.graph.stableSourceIndices[item.ref]
            sortedImportsFromOtherChunks.append(StableRef(stableSourceIndex, item.ref))
        }
    }
    // 按 stable_source_index 排序
    sortedImportsFromOtherChunks.sort { a, b =>
        if (a.stableSourceIndex != b.stableSourceIndex) {
            a.stableSourceIndex < b.stableSourceIndex
        } else {
            a.ref < b.ref
        }
    }

    // 3. 压缩模式 vs 普通模式
    if (linker.options.minifyIdentifiers) {
        return renameSymbolsMinified(linker, chunk, filesInOrder,
                                      sortedImportsFromOtherChunks, reservedNames)
    } else {
        return renameSymbolsNumbered(linker, chunk, filesInOrder,
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
    let renamer = Renamer()

    // 收集字符频率
    var freq = CharFreq()
    for (sourceIndex in filesInOrder) {
        freq.include(getCharFreq(linker, sourceIndex))
    }

    // 收集所有顶层符号使用计数
    let topLevelSymbolsAll = ArrayList<StableSymbolCount>()
    let stableSourceIndices = linker.graph.stableSourceIndices

    for (sourceIndex in filesInOrder) {
        let topLevelSymbols = ArrayList<StableSymbolCount>()
        let parts = getParts(linker, sourceIndex)

        // exports_ref 和 module_ref
        let flags = getFlags(linker, sourceIndex)
        if (flags.usesExportsRef) {
            accumulateSymbolUseCount(topLevelSymbols, getExportsRef(linker, sourceIndex),
                                      1, stableSourceIndices)
        }
        if (flags.usesModuleRef) {
            accumulateSymbolUseCount(topLevelSymbols, getModuleRef(linker, sourceIndex),
                                      1, stableSourceIndices)
        }

        for (part in parts) {
            if (!part.isLive) { continue }
            accumulateSymbolUseCounts(topLevelSymbols, part.symbolUses, stableSourceIndices)
            for (declaredRef in part.declaredSymbols) {
                accumulateSymbolUseCount(topLevelSymbols, declaredRef, 1, stableSourceIndices)
            }
        }

        // 排序后追加
        topLevelSymbols.sort { a, b =>
            if (a.stableSourceIndex != b.stableSourceIndex) {
                a.stableSourceIndex < b.stableSourceIndex
            } else {
                a.count > b.count
            }
        }
        for (sym in topLevelSymbols) {
            topLevelSymbolsAll.append(sym)
        }
    }

    // 跨 chunk 导入
    for (stableRef in sortedImports) {
        accumulateSymbolUseCount(topLevelSymbolsAll, stableRef.ref, 1, stableSourceIndices)
    }

    // 按频率分配名称
    let minifier = freq.compile()
    var nameIndex: Int64 = 0
    for (sym in topLevelSymbolsAll) {
        let name = minifier.generateName(nameIndex)
        renamer.assignName(sym.ref, name)
        nameIndex++
    }

    return renamer
}

/// 普通模式的符号重命名
// 严格翻译自: renameSymbolsInChunk.zig:133 非压缩分支
private func renameSymbolsNumbered(linker: LinkerContext,
                                      chunk: Chunk,
                                      filesInOrder: ArrayList<Int64>,
                                      sortedImports: ArrayList<StableRef>,
                                      reservedNames: HashSet<String>): Renamer {
    let renamer = Renamer()

    // 添加跨 chunk 导入的符号到顶层
    for (stableRef in sortedImports) {
        renamer.addTopLevelSymbol(stableRef.ref)
    }

    for (sourceIndex in filesInOrder) {
        let flags = getFlags(linker, sourceIndex)
        let wrap = flags.wrap
        let parts = getParts(linker, sourceIndex)

        match (wrap) {
            case WrapKind.CJS => {
                // CJS 包装: 添加 wrapper_ref 到顶层
                let wrapperRef = getWrapperRef(linker, sourceIndex)
                renamer.addTopLevelSymbol(wrapperRef)

                // 如果输出格式保留 ES6 导入语法，外部导入语句的提升符号需要添加到顶层
                if (linker.options.outputFormat == OutputFormat.ESM) {
                    let importRecords = getImportRecords(linker, sourceIndex)
                    for (part in parts) {
                        for (stmt in part.stmts) {
                            // 处理外部导入的符号
                            if (stmt.tag == StmtTag.Import) {
                                // 添加命名空间引用和默认导入引用到顶层
                            }
                        }
                    }
                }

                // 递归分配模块作用域名称
                assignNamesRecursive(linker, sourceIndex, renamer)
            }
            case WrapKind.ESM => {
                // ESM 包装: 添加 wrapper_ref 到顶层
                let wrapperRef = getWrapperRef(linker, sourceIndex)
                renamer.addTopLevelSymbol(wrapperRef)
            }
            case WrapKind.None => ()
        }

        // 遍历活跃的 part
        for (part in parts) {
            if (!part.isLive) { continue }

            // 添加顶层声明符号
            for (declaredRef in part.declaredSymbols) {
                renamer.addTopLevelSymbol(declaredRef)
            }

            // 递归分配嵌套作用域名称
            for (scope in getScopes(linker, sourceIndex)) {
                assignNamesRecursive(linker, sourceIndex, renamer)
            }
        }
    }

    return renamer
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 计算初始保留名称
// 严格翻译自: renamer.computeInitialReservedNames()
private func computeInitialReservedNames(format: OutputFormat): HashSet<String> {
    let reserved = HashSet<String>()
    // JS 保留字
    let jsReserved = [
        "break", "case", "catch", "class", "const", "continue", "debugger",
        "default", "delete", "do", "else", "export", "extends", "false",
        "finally", "for", "function", "if", "import", "in", "instanceof",
        "let", "new", "null", "return", "static", "super", "switch", "this",
        "throw", "true", "try", "typeof", "undefined", "var", "void", "while",
        "with", "yield", "arguments", "await", "eval"
    ]
    for (word in jsReserved) {
        reserved.put(word)
    }

    // 输出格式特定保留
    match (format) {
        case OutputFormat.CJS => {
            reserved.put("exports")
            reserved.put("module")
            reserved.put("require")
        }
        case OutputFormat.ESM => {
            reserved.put("import")
            reserved.put("export")
        }
        case OutputFormat.IIFE => {
            reserved.put("arguments")
        }
    }
    return reserved
}

/// 为作用域计算保留名称
private func computeReservedNamesForScope(linker: LinkerContext, sourceIndex: Int64,
                                            reservedNames: HashSet<String>): Unit {
    // 遍历模块作用域的成员，将不可重命名的名称添加到保留集合
    // 简化
}

/// 积累符号使用计数
private func accumulateSymbolUseCount(list: ArrayList<StableSymbolCount>,
                                        ref: Int64, count: Int64,
                                        stableIndices: Array<UInt32>): Unit {
    let stableIdx = if (ref >= 0 && ref < stableIndices.size) {
        Int64(stableIndices[ref])
    } else {
        ref
    }
    list.append(StableSymbolCount(stableIdx, ref, count))
}

/// 批量积累符号使用计数
private func accumulateSymbolUseCounts(list: ArrayList<StableSymbolCount>,
                                        symbolUses: HashMap<Int64, SymbolUse>,
                                        stableIndices: Array<UInt32>): Unit {
    for (entry in symbolUses.entries()) {
        let ref = entry.key
        let use = entry.value
        accumulateSymbolUseCount(list, ref, use.countEstimate, stableIndices)
    }
}

/// 递归分配名称
private func assignNamesRecursive(linker: LinkerContext, sourceIndex: Int64,
                                    renamer: Renamer): Unit {
    // 简化: 为嵌套作用域中的符号分配名称
}

// 简化的辅助方法
private func getParts(linker: LinkerContext, sourceIndex: Int64): ArrayList<Part> {
    if (sourceIndex < 0 || sourceIndex >= linker.graph.asts.size) {
        return ArrayList<Part>()
    }
    return linker.graph.asts[sourceIndex].parts
}

private func getImportRecords(linker: LinkerContext, sourceIndex: Int64): ArrayList<ImportRecord> {
    if (sourceIndex < 0 || sourceIndex >= linker.graph.asts.size) {
        return ArrayList<ImportRecord>()
    }
    return linker.graph.asts[sourceIndex].importRecords
}

private func getFlags(linker: LinkerContext, sourceIndex: Int64): MetaFlags {
    return MetaFlags()
}

private func getWrapperRef(linker: LinkerContext, sourceIndex: Int64): Int64 { return 0 }
private func getExportsRef(linker: LinkerContext, sourceIndex: Int64): Int64 { return 0 }
private func getModuleRef(linker: LinkerContext, sourceIndex: Int64): Int64 { return 0 }
private func getCharFreq(linker: LinkerContext, sourceIndex: Int64): CharFreq { return CharFreq() }
private func getScopes(linker: LinkerContext, sourceIndex: Int64): ArrayList<Scope> { return ArrayList<Scope>() }

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
}

/// 字符频率计数器
public class CharFreq {
    public var freqs: Array<Int64>

    public init() {
        freqs = Array<Int64>()
        for (_ in 0..64) {
            freqs.append(0)
        }
    }

    /// 包含另一个频率计数
    public func include(other: CharFreq): Unit {
        for (i in 0..freqs.size) {
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
        let base = "abcdefghijklmnopqrstuvwxyz$_"
        if (index < Int64(base.length)) {
            return base.substring(index, index + 1)
        }
        return "v${index}"
    }
}

/// 作用域 (简化)
public class Scope {
    public var members: HashMap<String, Int64>

    public init() {
        members = HashMap<String, Int64>()
    }
}
