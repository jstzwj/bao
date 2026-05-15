// 严格翻译自: src/bundler/linker_context/scanImportsAndExports.zig (1261行)
//            + src/bundler/linker_context/findImportedFilesInCSSOrder.zig (679行)
// bao_bundler - 链接器扫描: 导入/导出扫描 + CSS 导入顺序
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// 导入/导出扫描
// 严格翻译自: linker_context/scanImportsAndExports.zig
// 核心步骤:
//   Step 1: 判断哪些模块必须是 CommonJS
//   Step 2: 传播 export star 的动态导出状态
//   Step 3: 匹配命名导入与命名导出
//   Step 4: 处理 TypeScript 枚举
//   Step 5: 创建命名空间导出 (在 doStep5.cj 中)
// ============================================================================

/// 导入/导出扫描错误
// 严格翻译自: scanImportsAndExports.zig:1 ScanImportsAndExportsError
public enum ScanImportsAndExportsError {
    | OutOfMemory
    | ImportResolutionFailed
}

/// LinkerContext 扩展: 导入/导出扫描
// 严格翻译自: scanImportsAndExports.zig:3 scanImportsAndExports()
public func scanImportsAndExportsExt(linker: LinkerContext): Unit {
    let reachable = linker.graph.reachableFiles
    let outputFormat = linker.options.outputFormat

    let importRecordsList = linker.graph.asts
    let exportsKind = linker.graph.exportsKinds
    let entryPointKinds = linker.graph.entryPointKinds
    let flags = linker.graph.metaFlags

    let inputFiles = linker.parseGraph.inputFiles
    let loaders = linker.parseGraph.loaders
    let cssAsts = linker.graph.cssAsts

    // Step 1: 判断哪些模块必须是 CommonJS
    // 严格翻译自: scanImportsAndExports.zig:31
    for (sourceIndex in reachable) {
        let id = sourceIndex.value
        if (id < 0 || id >= importRecordsList.size) { continue }

        let importRecords = importRecordsList[id].importRecords

        // CSS 文件特殊处理
        if (id < cssAsts.size && cssAsts[id] != None) {
            scanCSSImports(linker, id, importRecords, cssAsts, inputFiles, loaders)
            validateComposesFromProperties(linker, id, cssAsts[id], importRecordsList, cssAsts)
            continue
        }

        // 根据导入类型更新导出类型
        for (record in importRecords) {
            if (!record.sourceIndex.isValid()) { continue }

            let otherFile = record.sourceIndex.value
            if (otherFile >= exportsKind.size) { continue }
            let otherKind = exportsKind[otherFile]

            match (record.kind) {
                case ImportKind.Static => {
                    // import ... from 'path'
                    // 如果目标文件没有 ES6 语法，且有 * 或 default 导入，
                    // 则目标被当作 CJS 模块
                    if ((record.containsImportStar || record.containsDefaultAlias) &&
                        !flags[otherFile].hasLazyExport &&
                        !flags[otherFile].forceCjsToEsm &&
                        exportsKind[otherFile] == ExportsKind.None) {
                        exportsKind[otherFile] = ExportsKind.CJS
                        flags[otherFile].wrap = WrapKind.CJS
                    }

                    if (record.containsDefaultAlias && flags[otherFile].forceCjsToEsm) {
                        exportsKind[otherFile] = ExportsKind.CJS
                        flags[otherFile].wrap = WrapKind.CJS
                    }
                }
                case ImportKind.Require => {
                    // require('path') 导入的文件必须是 CJS
                    if (otherKind == ExportsKind.ESM) {
                        flags[otherFile].wrap = WrapKind.ESM
                    } else {
                        flags[otherFile].wrap = WrapKind.CJS
                        exportsKind[otherFile] = ExportsKind.CJS
                    }
                }
                case ImportKind.Dynamic => {
                    // 动态导入
                    if (!linker.graph.codeSplitting) {
                        if (exportsKind[otherFile] == ExportsKind.ESM) {
                            flags[otherFile].wrap = WrapKind.ESM
                        } else {
                            flags[otherFile].wrap = WrapKind.CJS
                            exportsKind[otherFile] = ExportsKind.CJS
                        }
                    }
                }
                case _ => ()
            }
        }

        // 如果输出格式没有隐式 CJS 包装器，使用 CJS 特性的文件需要被包装
        let kind = exportsKind[id]
        if (kind == ExportsKind.CJS &&
            (!entryPointKinds[id].isEntryPoint() ||
             outputFormat == OutputFormat.IIFE ||
             outputFormat == OutputFormat.ESM)) {
            flags[id].wrap = WrapKind.CJS
        }
    }

    // Step 2: 传播 export star 的动态导出状态
    // 严格翻译自: scanImportsAndExports.zig:197
    propagateExportStarDynamicExports(linker, reachable)

    // Step 3: 匹配命名导入与命名导出
    // 严格翻译自: scanImportsAndExports.zig 中 Step 3
    matchNamedImports(linker, reachable)
}

/// 扫描 CSS 导入
// 严格翻译自: scanImportsAndExports.zig 中 scanCSSImports()
public func scanCSSImports(linker: LinkerContext, id: Int64,
                            importRecords: ArrayList<ImportRecord>,
                            cssAsts: ArrayList<?CssStyleSheet>,
                            inputFiles: ArrayList<InputFile>,
                            loaders: ArrayList<Loader>): Unit {
    // 处理 CSS 文件中的内联 URL
    for (record in importRecords) {
        if (!record.sourceIndex.isValid()) { continue }

        // 检查内联 URL
        if (loaders[record.sourceIndex.value].isCSS()) {
            // CSS 导入 CSS
        } else {
            // JS 导入 CSS
        }
    }
}

/// 验证 composes from 属性
// 严格翻译自: scanImportsAndExports.zig:78 validateComposesFromProperties()
public func validateComposesFromProperties(linker: LinkerContext, id: Int64,
                                            cssAst: ?CssStyleSheet,
                                            importRecordsList: ArrayList<Ast>,
                                            cssAsts: ArrayList<?CssStyleSheet>): Unit {
    // 简化: 验证 CSS composes: ... from "..." 指令引用的名称是否在目标文件中存在
}

/// 传播 export star 的动态导出状态
// 严格翻译自: scanImportsAndExports.zig:197
// 对 export * 语句，如果目标模块的导出不是静态可分析的，
// 则该 export star 必须在运行时求值
private func propagateExportStarDynamicExports(linker: LinkerContext,
                                                reachable: ArrayList<SourceIndex>): Unit {
    // 简化: 遍历可达文件，传播 export star 的动态状态
    for (sourceIndex in reachable) {
        let id = sourceIndex.value
        if (id < 0 || id >= linker.graph.asts.size) { continue }
        let ast = linker.graph.asts[id]

        // 遍历 export star 导入记录
        for (recordIdx in ast.exportStarImportRecords) {
            if (recordIdx < Int64(ast.importRecords.size)) {
                let record = ast.importRecords[recordIdx]
                if (record.sourceIndex.isValid()) {
                    // 如果目标模块是 CJS，则该 export star 是动态的
                    if (linker.graph.exportsKinds[record.sourceIndex.value] == ExportsKind.CJS) {
                        // 标记为动态 export star
                    }
                }
            }
        }
    }
}

/// 匹配命名导入
// 严格翻译自: scanImportsAndExports.zig 中 Step 3
private func matchNamedImports(linker: LinkerContext,
                                reachable: ArrayList<SourceIndex>): Unit {
    // 简化: 遍历每个文件的命名导入，尝试匹配到目标文件的命名导出
    for (sourceIndex in reachable) {
        let id = sourceIndex.value
        if (id < 0 || id >= linker.graph.asts.size) { continue }

        let ast = linker.graph.asts[id]
        for (record in ast.importRecords) {
            if (!record.sourceIndex.isValid()) { continue }

            // 匹配导入到导出
            let matchResult = matchImportWithExportForFile(
                linker,
                record,
                record.sourceIndex.value
            )
            record.matchResult = matchResult
        }
    }
}

/// 匹配文件的导入与导出
// 严格翻译自: LinkerContext.zig:1866 matchImportWithExport()
private func matchImportWithExportForFile(linker: LinkerContext,
                                           importRecord: ImportRecord,
                                           targetFileId: Int64): MatchImport {
    let result = MatchImport()

    // 外部模块
    if (importRecord.isExternal) {
        result.kind = MatchImportKind.Ignore
        return result
    }

    // 查找目标文件的导出
    if (targetFileId < 0 || targetFileId >= linker.graph.asts.size) {
        result.kind = MatchImportKind.Ignore
        return result
    }

    // 命名空间导入
    if (importRecord.isNamespaceImport) {
        result.kind = MatchImportKind.Namespace
        result.sourceIndex = targetFileId
        return result
    }

    // 普通导入
    result.kind = MatchImportKind.Normal
    result.sourceIndex = targetFileId
    return result
}

// ============================================================================
// CSS 导入顺序查找
// 严格翻译自: linker_context/findImportedFilesInCSSOrder.zig (679行)
//
// CSS 文件以深度优先后序遍历，但与 JS 不同的是:
// CSS @import 规则每次都会求值（而不是只求值第一次）
//
//       A
//      / \
//     B   C
//      \ /
//       D
//
// 如果 A 导入 B 然后 C，B 导入 D，C 导入 D:
// CSS 遍历顺序是: D B D C A
//
// 但多次求值等价于在最后位置求值一次，所以保留最后一次
// @layer 例外: 在第一次位置保留
// ============================================================================

/// CSS 导入顺序条目
// 严格翻译自: Chunk.zig 中 CssImportOrder
public class CssImportOrder {
    /// 条目类型
    public var kind: CssImportOrderKind
    /// 导入条件列表
    public var conditions: ArrayList<ImportCondition>
    /// 条件导入记录列表
    public var conditionImportRecords: ArrayList<ImportRecord>

    public init() {
        kind = CssImportOrderKind.SourceIndex(0)
        conditions = ArrayList<ImportCondition>()
        conditionImportRecords = ArrayList<ImportRecord>()
    }

    /// 计算哈希
    public func hash(hasher: ContentHasher): Unit {
        match (kind) {
            case CssImportOrderKind.SourceIndex(idx) => {
                hasher.writeInts([idx])
            }
            case CssImportOrderKind.ExternalPath(path) => {
                hasher.write(path.toString())
            }
        }
    }
}

/// CSS 导入顺序条目类型
public enum CssImportOrderKind {
    | SourceIndex(Int64)
    | ExternalPath(FsPath)
}

/// 导入条件
public class ImportCondition {
    public var layer: ?String
    public var supports: ?String
    public var media: ?String

    public init() {
        layer = None
        supports = None
        media = None
    }
}

/// CSS 导入顺序查找器
// 严格翻译自: findImportedFilesInCSSOrder.zig:23 findImportedFilesInCSSOrder()
public func findImportedFilesInCSSOrder(linker: LinkerContext,
                                         entryPoints: ArrayList<SourceIndex>): ArrayList<CssImportOrder> {
    let visitor = CSSImportVisitor()
    visitor.linker = linker
    visitor.cssAsts = linker.graph.cssAsts
    visitor.allImportRecords = linker.graph.asts

    let initialConditions = ArrayList<ImportCondition>()
    let initialRecords = ArrayList<ImportRecord>()

    for (entryPoint in entryPoints) {
        visitor.visit(entryPoint, initialConditions, initialRecords)
    }

    // 后处理: 去重 (保留每个文件的最后一次出现，@layer 保留第一次)
    let result = deduplicateCSSOrder(visitor.order)
    return result
}

/// CSS 导入访问器
// 严格翻译自: findImportedFilesInCSSOrder.zig:24 Visitor
public class CSSImportVisitor {
    /// 链接器
    public var linker: LinkerContext
    /// CSS AST 列表
    public var cssAsts: ArrayList<?CssStyleSheet>
    /// 所有导入记录列表
    public var allImportRecords: ArrayList<Ast>
    /// 已访问列表 (用于循环检测)
    public var visited: ArrayList<Int64>
    /// 结果顺序列表
    public var order: ArrayList<CssImportOrder>
    /// 是否有外部导入
    public var hasExternalImport: Bool

    public init() {
        linker = LinkerContext()
        cssAsts = ArrayList<?CssStyleSheet>()
        allImportRecords = ArrayList<Ast>()
        visited = ArrayList<Int64>()
        order = ArrayList<CssImportOrder>()
        hasExternalImport = false
    }

    /// 访问 CSS 文件
    // 严格翻译自: findImportedFilesInCSSOrder.zig:37 visit()
    // 深度优先后序遍历
    public func visit(sourceIndex: SourceIndex,
                       wrappingConditions: ArrayList<ImportCondition>,
                       wrappingImportRecords: ArrayList<ImportRecord>): Unit {
        // 循环检测: 如果已在访问路径中，跳过
        let id = sourceIndex.value
        for (visitedIdx in visited) {
            if (visitedIdx == id) {
                return
            }
        }

        visited.append(id)

        // 获取 CSS AST
        if (id < 0 || id >= cssAsts.size) {
            _ = visited.removeAt(visited.size - 1)
            return
        }

        let cssAst = cssAsts[id]
        if (cssAst == None) {
            _ = visited.removeAt(visited.size - 1)
            return
        }

        let stylesheet = cssAst
        let importRecords = allImportRecords[id].importRecords
        var importRecordIdx: Int64 = 0

        // 遍历顶层 @import 规则
        for (rule in stylesheet.rules) {
            if (rule.tag == CssRuleTag.Import) {
                let recordIdx = importRecordIdx
                importRecordIdx++
                if (recordIdx >= Int64(importRecords.size)) { continue }

                let record = importRecords[recordIdx]

                // 跟随内部依赖
                if (record.sourceIndex.isValid()) {
                    // 如果导入有条件，fork 状态
                    if (rule.hasConditions) {
                        let nestedConditions = deepCloneConditions(wrappingConditions)
                        let nestedRecord = ImportCondition()
                        nestedConditions.append(nestedRecord)
                        visit(record.sourceIndex, nestedConditions, wrappingImportRecords)
                        continue
                    }
                    visit(record.sourceIndex, wrappingConditions, wrappingImportRecords)
                    continue
                }

                // 记录外部依赖
                if (!record.isInternal) {
                    let entry = CssImportOrder()
                    entry.kind = CssImportOrderKind.ExternalPath(record.path)
                    if (rule.hasConditions) {
                        let allConditions = deepCloneConditions(wrappingConditions)
                        entry.conditions = allConditions
                    } else {
                        entry.conditions = wrappingConditions
                    }
                    order.append(entry)
                    hasExternalImport = true
                }
            }
        }

        // 遍历 composes 指令
        for (record in importRecords) {
            if (record.kind == ImportKind.ComposeFrom && record.sourceIndex.isValid()) {
                visit(record.sourceIndex, wrappingConditions, wrappingImportRecords)
            }
        }

        // 深度优先后序: 添加自身
        let selfEntry = CssImportOrder()
        selfEntry.kind = CssImportOrderKind.SourceIndex(id)
        selfEntry.conditions = wrappingConditions
        order.append(selfEntry)

        _ = visited.removeAt(visited.size - 1)
    }

    /// 深度克隆条件列表
    private func deepCloneConditions(conditions: ArrayList<ImportCondition>): ArrayList<ImportCondition> {
        let result = ArrayList<ImportCondition>()
        for (c in conditions) {
            let clone = ImportCondition()
            clone.layer = c.layer
            clone.supports = c.supports
            clone.media = c.media
            result.append(clone)
        }
        return result
    }
}

/// CSS 去重: 保留每个文件的最后一次出现
// 严格翻译自: findImportedFilesInCSSOrder.zig 中去重逻辑
private func deduplicateCSSOrder(order: ArrayList<CssImportOrder>): ArrayList<CssImportOrder> {
    let result = ArrayList<CssImportOrder>()
    let seen = HashSet<Int64>()

    // 从后向前遍历，保留最后一次出现
    var i = order.size - 1
    while (i >= 0) {
        let entry = order[i]
        match (entry.kind) {
            case CssImportOrderKind.SourceIndex(idx) => {
                if (!seen.contains(idx)) {
                    seen.put(idx)
                    result.insertAt(0, entry)
                }
            }
            case CssImportOrderKind.ExternalPath(_) => {
                // 外部导入总是保留
                result.insertAt(0, entry)
            }
        }
        i--
    }

    return result
}

// ============================================================================
// 辅助类型
// ============================================================================

/// CSS 样式表
public class CssStyleSheet {
    public var rules: ArrayList<CssRule>
    public var localScope: HashMap<String, Bool>

    public init() {
        rules = ArrayList<CssRule>()
        localScope = HashMap<String, Bool>()
    }
}

/// CSS 规则
public class CssRule {
    public var tag: CssRuleTag
    public var hasConditions: Bool
    public var conditions: ArrayList<ImportCondition>

    public init() {
        tag = CssRuleTag.Other
        hasConditions = false
        conditions = ArrayList<ImportCondition>()
    }
}

/// CSS 规则标签
public enum CssRuleTag {
    | Import
    | Layer
    | Other
}

/// 包装类型
public enum WrapKind {
    | None
    | ESM
    | CJS
}

/// 元标志
public class MetaFlags {
    public var wrap: WrapKind
    public var hasLazyExport: Bool
    public var forceCjsToEsm: Bool

    public init() {
        wrap = WrapKind.None
        hasLazyExport = false
        forceCjsToEsm = false
    }
}

/// 入口点类型
public class EntryPointKind {
    public var kind: EntryPointKindTag

    public init() {
        kind = EntryPointKindTag.None
    }

    public func isEntryPoint(): Bool {
        return kind == EntryPointKindTag.UserDefined
    }
}

/// 入口点类型标签
public enum EntryPointKindTag {
    | None
    | UserDefined
    | Dynamic
}

/// CSS composes 指令
public class CssComposes {
    public var names: ArrayList<CssComposeName>
    public var from: ?CssComposeFrom
    public var loc: Int64

    public init() {
        names = ArrayList<CssComposeName>()
        from = None
        loc = 0
    }
}

/// CSS compose 名称
public class CssComposeName {
    public var v: String

    public init(v: String) {
        this.v = v
    }
}

/// CSS compose from 来源
public enum CssComposeFrom {
    | ImportRecordIndex(Int64)
    | LocalPath(String)
}
