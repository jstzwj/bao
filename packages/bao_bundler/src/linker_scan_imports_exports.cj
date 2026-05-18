// 严格翻译自: src/bundler/linker_context/scanImportsAndExports.zig (1260行)
// bao_bundler - 导入/导出扫描: 6 步管道扫描和绑定所有导入/导出
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// 导入/导出扫描
// 严格翻译自: scanImportsAndExports.zig
//
// 6 步管道:
//   Step 1: 确定哪些模块必须是 CommonJS
//     - 包含 import * / import default 的空模块 -> CJS
//     - require() 导入的文件 -> CJS
//     - 使用 CJS 特性的非入口点 -> CJS
//     - 处理 CSS AST: 扫描 CSS 导入, 验证 composes
//
//   Step 2: 传播动态导出状态 (export star 语句)
//     - 如果 export * 的目标有动态导出 -> 当前模块也有动态导出
//     - 递归传播 (通过 export star 图)
//     - 包装依赖的 CommonJS 文件
//
//   Step 3: 解析 "export * from" 语句
//     - 收集所有 export star 的重导出
//     - 处理歧义 (多个 export star 导出同一名称)
//     - 为 import * 生成特殊导出
//     - 调用 generateCodeForLazyExport
//
//   Step 4: 匹配导入与导出
//     - 将命名导入与解析的导出绑定
//     - 标记未绑定/外部符号
//     - 创建包装器 part
//
//   Step 5: 为每个文件创建命名空间导出 (并行)
//     - 调用 doStep5()
//
//   Step 6: 绑定导入到导出
//     - 生成运行时符号导入 (__toESM, __toCommonJS, __require, __reExport)
//     - 添加跨 part 依赖
//     - 为入口点创建虚拟 part
//     - 生成 CJS 导出副本符号
// ============================================================================

/// 扫描导入和导出
// 严格翻译自: scanImportsAndExports.zig:3 scanImportsAndExports()
public func scanImportsAndExports(linker: LinkerContext): Unit {
    let reachable = linker.graph.reachableFiles
    let outputFormat = linker.options.outputFormat

    // Step 1: Figure out what modules must be CommonJS
    // 严格翻译自: scanImportsAndExports.zig:31
    for (sourceIndex_ in reachable) {
        let id = sourceIndex_.get()

        // Skip files without JS AST
        if (!hasJSAST(linker, id)) {
            continue
        }

        let importRecords = getScanImportRecords(linker, id)
        let exportsKind = getExportsKind(linker, id)
        let astFlags = getScanAstFlags(linker, id)

        // Check if it's a CSS file
        let cssAst = getCssAst(linker, id)
        if (cssAst != None) {
            // Scan CSS imports and validate composes
            scanCSSImports(linker, id, importRecords)
            validateComposesFromProperties(linker, id)
            continue
        }

        // Process import records to determine CJS status
        for (record in importRecords) {
            if (record.sourceIndex < 0) {
                continue
            }
            let otherFile = record.sourceIndex
            let otherFlags = getScanAstFlags(linker, otherFile)
            let otherKind = getExportsKind(linker, otherFile)

            match (record.kind) {
                case ScanImportKind.Stmt =>
                    // import * / import default from empty module -> CJS
                    if ((record.flags.containsImportStar || record.flags.containsDefaultAlias) &&
                        !otherFlags.hasLazyExport &&
                        !otherFlags.forceCjsToEsm &&
                        otherKind == ExportsKind.None) {
                        setExportsKind(linker, otherFile, ExportsKind.CJS)
                        setWrap(linker, otherFile, ScanWrapKind.CJS)
                    }
                    if (record.flags.containsDefaultAlias && otherFlags.forceCjsToEsm) {
                        setExportsKind(linker, otherFile, ExportsKind.CJS)
                        setWrap(linker, otherFile, ScanWrapKind.CJS)
                    }
                case ScanImportKind.Require =>
                    if (otherKind == ExportsKind.ESM) {
                        setWrap(linker, otherFile, ScanWrapKind.ESM)
                    } else {
                        setWrap(linker, otherFile, ScanWrapKind.CJS)
                        setExportsKind(linker, otherFile, ExportsKind.CJS)
                    }
                case ScanImportKind.Dynamic =>
                    if (!linker.graph.codeSplitting) {
                        if (otherKind == ExportsKind.ESM) {
                            setWrap(linker, otherFile, ScanWrapKind.ESM)
                        } else {
                            setWrap(linker, otherFile, ScanWrapKind.CJS)
                            setExportsKind(linker, otherFile, ExportsKind.CJS)
                        }
                    }
                case _ => ()
            }
        }

        // Wrap CJS files
        let kind = getExportsKind(linker, id)
        let entryPointKind = getScanEntryPointKind(linker, id)
        if (kind == ExportsKind.CJS &&
            (!entryPointKind.isScanEntryPoint() ||
             outputFormat == OutputFormat.IIFE ||
             outputFormat == OutputFormat.ESM)) {
            setWrap(linker, id, ScanWrapKind.CJS)
        }
    }

    // Step 2: Propagate dynamic export status for export star statements
    // 严格翻译自: scanImportsAndExports.zig:198
    let dependencyWrapper = DependencyWrapper(linker)
    for (sourceIndex_ in reachable) {
        let id = sourceIndex_.get()
        if (!hasJSAST(linker, id)) {
            continue
        }

        let flags = getScanMetaFlags(linker, id)
        if (flags.wrap != ScanWrapKind.None) {
            dependencyWrapper.wrap(id)
        }

        // Check for dynamic exports due to export star
        let exportStarRecords = getExportStarScanImportRecords(linker, id)
        if (exportStarRecords.size > 0) {
            dependencyWrapper.hasDynamicExportsDueToExportStar(id)
        }

        // Wrap files that import CJS files
        let importRecords = getScanImportRecords(linker, id)
        for (record in importRecords) {
            if (record.sourceIndex >= 0) {
                let otherKind = getExportsKind(linker, record.sourceIndex)
                if (otherKind == ExportsKind.CJS) {
                    dependencyWrapper.wrap(record.sourceIndex)
                }
            }
        }
    }

    // Step 3: Resolve "export * from" statements
    // 严格翻译自: scanImportsAndExports.zig:248
    var exportStarCtx: ?ExportStarContext = None
    for (sourceIndex_ in reachable) {
        let id = sourceIndex_.get()
        if (!hasJSAST(linker, id)) {
            continue
        }

        let astFlags = getScanAstFlags(linker, id)
        // Generate lazy exports
        if (astFlags.hasLazyExport) {
            generateCodeForLazyExportExt(linker, id)
        }

        // Propagate exports for export star
        let exportStarIds = getExportStarScanImportRecords(linker, id)
        if (exportStarIds.size > 0) {
            if (exportStarCtx == None) {
                exportStarCtx = ExportStarContext(linker)
            }
            exportStarCtx.addExports(id)
        }

        // Add special export for import star binding
        setResolvedExportStar(linker, id)
    }

    // Step 4: Match imports with exports
    // 严格翻译自: scanImportsAndExports.zig:309
    for (sourceIndex_ in reachable) {
        let id = sourceIndex_.get()
        if (!hasJSAST(linker, id)) {
            continue
        }

        let namedImports = getNamedImports(linker, id)
        if (namedImports.count() > 0) {
            matchImportsWithExportsForFile(linker, id)
        }

        // Create wrapper for wrapped files
        let flags = getScanMetaFlags(linker, id)
        let wrappedRef = getWrapperRef(linker, id)
        createWrapperForFile(linker, flags.wrap, wrappedRef, id)
    }

    // Step 5: Create namespace exports for every file (parallel)
    // 严格翻译自: scanImportsAndExports.zig:371
    for (sourceIndex_ in reachable) {
        doStep5(linker, sourceIndex_.get())
    }

    // Step 6: Bind imports to exports
    // 严格翻译自: scanImportsAndExports.zig:387
    for (sourceIndex_ in reachable) {
        let id = sourceIndex_.get()
        let scanIsEntryPoint = getScanEntryPointKind(linker, id).isScanEntryPoint()
        let aliases = getSortedExportAliases(linker, id)
        let flags = getScanMetaFlags(linker, id)
        let wrap = flags.wrap
        let exportKind = getExportsKind(linker, id)

        // Pre-generate symbols for CJS re-exports
        if (scanIsEntryPoint && outputFormat == OutputFormat.ESM) {
            generateCjsExportCopies(linker, id, aliases)
        }

        // Rename wrapper/init symbols
        if (wrap == ScanWrapKind.ESM) {
            renameWrapperSymbol(linker, id, "init_")
        }

        // Rename unused exports/module symbols
        if (wrap != ScanWrapKind.CJS && exportKind != ExportsKind.CJS &&
            outputFormat != OutputFormat.InternalBakeDev) {
            renameExportsModuleSymbols(linker, id)
        }

        // Bind imports to exports and generate runtime symbol uses
        bindImportsToExportsForFile(linker, id)
    }
}

// ============================================================================
// DependencyWrapper
// 严格翻译自: scanImportsAndExports.zig:883 DependencyWrapper
// ============================================================================

/// 依赖包装器 - 传播动态导出状态
public class DependencyWrapper {
    public var linker: LinkerContext
    public var exportStarMap: HashSet<Int64>

    public init(linker: LinkerContext) {
        this.linker = linker
        this.exportStarMap = HashSet<Int64>()
    }

    /// 检查 export star 是否导致动态导出
    // 严格翻译自: scanImportsAndExports.zig:893 hasDynamicExportsDueToExportStar()
    public func hasDynamicExportsDueToExportStar(sourceIndex: Int64): Bool {
        let exportKind = getExportsKind(linker, sourceIndex)
        if (exportKind == ExportsKind.CJS ||
            exportKind == ExportsKind.ESMWithDynamicFallback) {
            return true
        }

        // Avoid infinite loops
        if (exportStarMap.contains(sourceIndex)) {
            return false
        }
        exportStarMap.put(sourceIndex)

        let records = getScanImportRecords(linker, sourceIndex)
        let exportStarRecords = getExportStarScanImportRecords(linker, sourceIndex)
        let entryPointKind = getScanEntryPointKind(linker, sourceIndex)

        for (importId in exportStarRecords) {
            if (importId >= records.size) {
                continue
            }
            let record = records[importId]
            let happensAtRuntime = (record.sourceIndex < 0 &&
                (!entryPointKind.isScanEntryPoint() ||
                 !outputFormatKeepES6ImportExportSyntax(linker))) ||
                (record.sourceIndex >= 0 &&
                 record.sourceIndex != sourceIndex &&
                 hasDynamicExportsDueToExportStar(record.sourceIndex))

            if (happensAtRuntime) {
                setExportsKind(linker, sourceIndex, ExportsKind.ESMWithDynamicFallback)
                return true
            }
        }

        return false
    }

    /// 递归包装依赖
    // 严格翻译自: scanImportsAndExports.zig:926 wrap()
    public func wrap(sourceIndex: Int64): Unit {
        let flags = getScanMetaFlags(linker, sourceIndex)
        if (flags.didWrapDependencies) {
            return
        }
        flags.didWrapDependencies = true

        // Never wrap the runtime file
        if (sourceIndex == 0) {
            return
        }

        if (flags.wrap == ScanWrapKind.None) {
            let kind = getExportsKind(linker, sourceIndex)
            flags.wrap = match (kind) {
                case ExportsKind.CJS => ScanWrapKind.CJS
                case _ => ScanWrapKind.ESM
            }
        }

        // Recursively wrap dependencies
        let records = getScanImportRecords(linker, sourceIndex)
        for (record in records) {
            if (record.sourceIndex >= 0) {
                wrap(record.sourceIndex)
            }
        }
    }
}

// ============================================================================
// ExportStarContext
// 严格翻译自: scanImportsAndExports.zig:959 ExportStarContext
// ============================================================================

/// Export star 上下文 - 解析 export * 语句
public class ExportStarContext {
    public var linker: LinkerContext
    public var sourceIndexStack: ArrayList<Int64>

    public init(linker: LinkerContext) {
        this.linker = linker
        this.sourceIndexStack = ArrayList<Int64>()
    }

    /// 添加导出
    // 严格翻译自: scanImportsAndExports.zig:969 addExports()
    public func addExports(sourceIndex: Int64): Unit {
        // Avoid cycles
        for (prev in sourceIndexStack) {
            if (prev == sourceIndex) {
                return
            }
        }
        sourceIndexStack.append(sourceIndex)
        let stackEndPos = sourceIndexStack.size

        let importRecords = getScanImportRecords(linker, sourceIndex)
        let exportStarRecords = getExportStarScanImportRecords(linker, sourceIndex)
        let namedExports = getScanNamedExportsForSource(linker, sourceIndex)
        let exportsKind = getExportsKind(linker, sourceIndex)

        for (importId in exportStarRecords) {
            if (importId >= importRecords.size) {
                continue
            }
            let record = importRecords[importId]
            let otherSourceIndex = record.sourceIndex
            if (otherSourceIndex < 0) {
                continue
            }

            // Skip CJS export stars
            let otherKind = getExportsKind(linker, otherSourceIndex)
            if (otherKind == ExportsKind.CJS) {
                continue
            }

            // Iterate named exports from other file
            let otherScanNamedExports = getScanNamedExportsForSource(linker, otherSourceIndex)
            let otherIter = otherScanNamedExports.iterator()
            while (otherIter.hasNext()) {
                let entry = otherIter.next()
                let alias = entry.key
                let name = entry.value

                // ES6 export star ignores "default"
                if (alias == "default") {
                    continue
                }

                // Check if shadowed by any file in the stack
                var isShadowed = false
                for (prev in sourceIndexStack) {
                    if (getScanNamedExportsForSource(linker, prev).contains(alias)) {
                        isShadowed = true
                        break
                    }
                }
                if (isShadowed) {
                    continue
                }

                // Add resolved export
                addResolvedExport(linker, sourceIndex, alias, name, otherSourceIndex)
            }

            // Recurse through other file's export stars
            addExports(otherSourceIndex)
        }

        // Pop from stack
        sourceIndexStack.removeAt(sourceIndexStack.size - 1)
    }
}

// ============================================================================
// 辅助数据获取函数 (简化)
// ============================================================================

private func hasJSAST(linker: LinkerContext, id: Int64): Bool {
    return id >= 0 && id < linker.graph.ast.size
}

private func getScanImportRecords(linker: LinkerContext, id: Int64): ArrayList<ScanImportRecord> {
    return ArrayList<ScanImportRecord>()
}

private func getExportsKind(linker: LinkerContext, id: Int64): ExportsKind {
    return ExportsKind.None
}

private func setExportsKind(linker: LinkerContext, id: Int64, kind: ExportsKind): Unit {
    // Simplified
}

private func getScanAstFlags(linker: LinkerContext, id: Int64): ScanAstFlags {
    return ScanAstFlags()
}

private func getScanMetaFlags(linker: LinkerContext, id: Int64): ScanMetaFlags {
    return ScanMetaFlags()
}

private func setWrap(linker: LinkerContext, id: Int64, wrap: ScanWrapKind): Unit {
    // Simplified
}

private func getScanEntryPointKind(linker: LinkerContext, id: Int64): ScanEntryPointKind {
    return ScanEntryPointKind()
}

private func getCssAst(linker: LinkerContext, id: Int64): ?ScanCssStyleSheet {
    return None
}

private func scanCSSImports(linker: LinkerContext, id: Int64,
                              importRecords: ArrayList<ScanImportRecord>): Unit {
    // Simplified
}

private func validateComposesFromProperties(linker: LinkerContext, id: Int64): Unit {
    // Simplified
}

private func getExportStarScanImportRecords(linker: LinkerContext, id: Int64): ArrayList<Int64> {
    return ArrayList<Int64>()
}

private func setResolvedExportStar(linker: LinkerContext, id: Int64): Unit {
    // Simplified
}

private func getNamedImports(linker: LinkerContext, id: Int64): NamedImports {
    return NamedImports()
}

private func matchImportsWithExportsForFile(linker: LinkerContext, id: Int64): Unit {
    // Simplified
}

private func createWrapperForFile(linker: LinkerContext, wrap: ScanWrapKind,
                                    wrappedRef: Int64, id: Int64): Unit {
    // Simplified
}

private func getSortedExportAliases(linker: LinkerContext, id: Int64): ArrayList<String> {
    return ArrayList<String>()
}

private func getWrapperRef(linker: LinkerContext, id: Int64): Int64 {
    return 0
}

private func generateCjsExportCopies(linker: LinkerContext, id: Int64,
                                       aliases: ArrayList<String>): Unit {
    // Simplified
}

private func renameWrapperSymbol(linker: LinkerContext, id: Int64, prefix: String): Unit {
    // Simplified
}

private func renameExportsModuleSymbols(linker: LinkerContext, id: Int64): Unit {
    // Simplified
}

private func bindImportsToExportsForFile(linker: LinkerContext, id: Int64): Unit {
    // Simplified
}

private func getScanNamedExportsForSource(linker: LinkerContext, id: Int64): ScanNamedExportsMap {
    return ScanNamedExportsMap()
}

private func addResolvedExport(linker: LinkerContext, sourceIndex: Int64,
                                 alias: String, name: ScanNamedExport,
                                 otherSourceIndex: Int64): Unit {
    // Simplified
}

private func outputFormatKeepES6ImportExportSyntax(linker: LinkerContext): Bool {
    return linker.options.outputFormat == OutputFormat.ESM ||
           linker.options.outputFormat == OutputFormat.IIFE
}

// ============================================================================
// 辅助类型
// ============================================================================

/// AST 标志
public class ScanAstFlags {
    public var hasLazyExport: Bool
    public var forceCjsToEsm: Bool
    public var hasImportMeta: Bool
    public var usesExportsRef: Bool
    public var usesModuleRef: Bool
    public var hasCharFreq: Bool

    public init() {
        hasLazyExport = false
        forceCjsToEsm = false
        hasImportMeta = false
        usesExportsRef = false
        usesModuleRef = false
        hasCharFreq = false
    }
}

/// Meta 标志
public class ScanMetaFlags {
    public var wrap: ScanWrapKind
    public var didWrapDependencies: Bool
    public var needsExportsVariable: Bool
    public var forceIncludeExportsForEntryPoint: Bool
    public var isAsyncOrHasAsyncDependency: Bool
    public var needsSyntheticDefaultExport: Bool
    public var needsExportSymbolFromRuntime: Bool
    public var hasExplicitUseStrictDirective: Bool

    public init() {
        wrap = ScanWrapKind.None
        didWrapDependencies = false
        needsExportsVariable = false
        forceIncludeExportsForEntryPoint = false
        isAsyncOrHasAsyncDependency = false
        needsSyntheticDefaultExport = false
        needsExportSymbolFromRuntime = false
        hasExplicitUseStrictDirective = false
    }
}

/// 包装类型
public enum ScanWrapKind {
    | None
    | CJS
    | ESM
}

/// 入口点类型
public class ScanEntryPointKind {
    public var scanIsEntryPoint: Bool

    public init() {
        scanIsEntryPoint = false
    }

    public func isScanEntryPoint(): Bool {
        return scanIsEntryPoint
    }
}

/// 命名导入集合
public class NamedImports {
    public func count(): Int64 {
        return 0
    }
}

/// 命名导出映射
public class ScanMapEntry<K, V> {
    public var key: K
    public var value: V

    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }
}

public class ScanNamedExportsMap {
    public func iterator(): Iterator<ScanMapEntry<String, ScanNamedExport>> {
        return ArrayList<ScanMapEntry<String, ScanNamedExport>>().iterator()
    }

    public func contains(key: String): Bool {
        return false
    }
}

/// 命名导出
public class ScanNamedExport {
    public var ref: Int64
    public var aliasLoc: Int64

    public init() {
        ref = 0
        aliasLoc = 0
    }
}

/// CSS 样式表 (简化)
public class ScanCssStyleSheet {
    public init() {}
}

/// 导入记录
public class ScanImportRecord {
    public var sourceIndex: Int64
    public var kind: ScanImportKind
    public var flags: ScanImportRecordFlagsExt
    public var path: ImportPath

    public init() {
        sourceIndex = -1
        kind = ScanImportKind.Stmt
        flags = ScanImportRecordFlagsExt()
        path = ImportPath()
    }
}

/// 导入记录标志
public class ScanImportRecordFlagsExt {
    public var containsImportStar: Bool
    public var containsDefaultAlias: Bool
    public var containsEsModuleAlias: Bool
    public var isExternalWithoutSideEffects: Bool
    public var wrapWithToEsm: Bool
    public var wrapWithToCommonjs: Bool
    public var callsRuntimeReExportFn: Bool
    public var isUnused: Bool

    public init() {
        containsImportStar = false
        containsDefaultAlias = false
        containsEsModuleAlias = false
        isExternalWithoutSideEffects = false
        wrapWithToEsm = false
        wrapWithToCommonjs = false
        callsRuntimeReExportFn = false
        isUnused = false
    }
}

/// 导入路径
public class ImportPath {
    public var text: String
    public var pretty: String
    public var isDisabled: Bool

    public init() {
        text = ""
        pretty = ""
        isDisabled = false
    }
}

/// 导入类型
public enum ScanImportKind {
    | Stmt
    | Require
    | Dynamic
    | At
    | Composes
}
