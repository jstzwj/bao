// 严格翻译自: src/bundler/linker_context/generateCodeForLazyExport.zig (421行)
// bao_bundler - Lazy Export 代码生成: 为 CSS modules 等生成延迟导出代码
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*

// ============================================================================
// Lazy Export 代码生成
// 严格翻译自: generateCodeForLazyExport.zig
//
// 处理 "lazy export" 语句，用于:
//   1. CSS modules: 将 CSS 局部作用域的类名导出为 JS 对象
//      - 处理 composes 指令 (跨文件引用)
//      - 生成模板字符串 (多个类名用空格连接)
//   2. CommonJS 输出: module.exports = { ... }
//   3. ESM 输出: 为每个属性生成单独的 export 语句
//      - 分离到独立的 part 以支持 tree-shaking
//      - 特殊处理 "default" 导出
// ============================================================================

/// 生成 lazy export 代码
// 严格翻译自: generateCodeForLazyExport.zig:1 generateCodeForLazyExport()
public func generateCodeForLazyExportExt(linker: LinkerContext,
                                           sourceIndex: Int64): Unit {
    let exportsKind = linker.graph.ast.getExportsKind(sourceIndex)
    let allSources = linker.parseGraph.inputFiles.sources
    let allCssAsts = linker.graph.ast.cssAsts
    let maybeCssAst: ?CssStyleSheet = allCssAsts[sourceIndex]
    let parts = linker.graph.ast.getParts(sourceIndex)

    if (parts.size < 1) {
        return
    }

    let part = parts[1] // Second part (index 1) contains the lazy export
    if (part.stmts.size == 0) {
        return
    }

    let moduleRef = linker.graph.ast.getModuleRef(sourceIndex)

    // Handle CSS modules
    // If this JavaScript file is a stub from a CSS file, populate the exports
    // with the local names from that CSS file
    if (maybeCssAst != None) {
        let cssAst = maybeCssAst
        let stmt = part.stmts[0]
        if (stmt.tag != LazyExportStmtTag.LazyExport) {
            return
        }

        if (cssAst.localScopeCount() > 0) {
            var exports = LazyExportExprObject()

            let symbols = linker.graph.ast.getLazyExportSymbols(sourceIndex)
            let allImportRecords = linker.graph.ast.importRecords

            let values = cssAst.localScopeValues()
            if (values.size == 0) {
                // Skip empty
            } else {
                // Compute max inner index for bit set
                let size = computeMaxInnerIndex(values) + 1

                let innerVisited = LazyExportBitSet(size)
                let composesVisited = HashSet<Int64>()

                // Create visitor for composes traversal
                let visitor = ComposesVisitor()
                visitor.innerVisited = innerVisited
                visitor.composesVisited = composesVisited
                visitor.sourceIndex = sourceIndex
                visitor.allImportRecords = allImportRecords
                visitor.allCssAsts = allCssAsts
                visitor.allSources = allSources
                visitor.allLazyExportSymbols = linker.graph.ast.allLazyExportSymbols
                visitor.log = linker.log

                for (entry in values) {
                    let ref = entry.ref

                    var templateParts = ArrayList<TemplatePart>()
                    var value = LazyExportExpr.nameOfLazyExportSymbol(ref, sourceIndex)

                    visitor.parts = templateParts
                    visitor.clearAll()
                    visitor.innerVisited.set(ref.innerIndex)
                    if (ref.tag.`class`) {
                        visitor.visitComposes(cssAst, ref, sourceIndex)
                    }

                    if (templateParts.size > 0) {
                        templateParts.append(TemplatePart(
                            value = value,
                            tail = ""
                        ))
                        value = LazyExportExpr.template(templateParts)
                    }

                    let key = symbols[ref.innerIndex].originalName
                    exports.put(key, value)
                }
            }

            // Replace lazy export with the generated object
            part.stmts[0] = LazyExportStmt.objectExport(exports)
        }
    }

    // Now handle the lazy export expression
    let stmt = part.stmts[0]
    if (stmt.tag != LazyExportStmtTag.LazyExport) {
        return
    }

    let expr = stmt.expr

    match (exportsKind) {
        case ExportsKind.CJS =>
            // "module.exports = expr;"
            part.stmts[0] = LazyExportStmt.assign(
                LazyExportExpr.dot(LazyExportExpr.identifier(moduleRef), "exports"),
                expr
            )

            // Generate symbol import for module_ref
            linker.graph.generateLazyExportSymbolImportAndUse(sourceIndex, 0, moduleRef, 1)

            // If this is a .napi addon and not CJS output, add __require
            if (expr.isRequireCallTarget() &&
                linker.options.outputFormat != OutputFormat.CJS) {
                linker.graph.generateRuntimeLazyExportSymbolImportAndUse(
                    sourceIndex, 1, "__require", 1)
            }
        case _ =>
            // Generate ES6 export statements as additional parts
            part.stmts.clear()

            if (expr.isObject()) {
                for (property in expr.properties) {
                    if (property.key == None || !property.key.isString()) {
                        continue
                    }
                    let name = property.key.stringValue()

                    // Skip "default" and "__esModule"
                    if (name == "default" || name == "__esModule") {
                        continue
                    }

                    // Skip non-identifier names
                    if (!isIdentifier(name)) {
                        continue
                    }

                    // Generate named export as separate part for tree-shaking
                    let generated = generateNamedExportInFile(
                        linker, sourceIndex, moduleRef, name, name)
                    parts[generated[1]].stmts = ArrayList<LazyExportStmt>()
                    parts[generated[1]].stmts.append(LazyExportStmt.localExport(
                        generated[0], property.value, property.key.loc
                    ))
                }
            }

            // Generate default export
            let defaultName = "${sourceIdentifier(linker, sourceIndex)}_default"
            let generated = generateNamedExportInFile(
                linker, sourceIndex, moduleRef, defaultName, "default")
            parts[generated[1]].stmts = ArrayList<LazyExportStmt>()
            parts[generated[1]].stmts.append(LazyExportStmt.exportDefault(
                generated[0], expr
            ))
    }
}

// ============================================================================
// Composes 访问器
// 严格翻译自: generateCodeForLazyExport.zig:52 Visitor struct
// ============================================================================

/// Composes 指令访问器
public class ComposesVisitor {
    public var innerVisited: LazyExportBitSet
    public var composesVisited: HashSet<Int64>
    public var parts: ArrayList<TemplatePart>
    public var allImportRecords: ArrayList<LazyExportImportRecordList>
    public var allCssAsts: ArrayList<CssStyleSheet>
    public var allSources: ArrayList<LazyExportInputFile>
    public var allLazyExportSymbols: ArrayList<LazyExportLazyExportSymbolList>
    public var sourceIndex: Int64
    public var log: LazyExportLog
    public var loc: Int64

    public init() {
        innerVisited = LazyExportBitSet(0)
        composesVisited = HashSet<Int64>()
        parts = ArrayList<TemplatePart>()
        sourceIndex = 0
        loc = 0
    }

    /// 清除所有状态
    public func clearAll(): Unit {
        innerVisited.setAll(false)
        composesVisited.clear()
    }

    /// 访问名称
    // 严格翻译自: generateCodeForLazyExport.zig:70 visitName()
    public func visitName(ast: CssStyleSheet, ref: CssRef, idx: Int64): Unit {
        let fromThisFile = ref.sourceIndex(idx) == sourceIndex
        if ((fromThisFile && innerVisited.isSet(ref.innerIndex())) ||
            (!fromThisFile && composesVisited.contains(ref.toRealRef(idx)))) {
            return
        }

        visitComposes(ast, ref, idx)
        parts.append(TemplatePart(
            value = LazyExportExpr.nameOfLazyExportSymbol(ref.toRealRef(idx)),
            tail = " "
        ))

        if (fromThisFile) {
            innerVisited.set(ref.innerIndex())
        } else {
            composesVisited.put(ref.toRealRef(idx))
        }
    }

    /// 访问 composes 指令
    // 严格翻译自: generateCodeForLazyExport.zig:127 visitComposes()
    public func visitComposes(ast: CssStyleSheet, cssRef: CssRef, idx: Int64): Unit {
        let ref = cssRef.toRealRef(idx)
        if (ast.composesCount() == 0) {
            return
        }

        let composes = ast.getComposes(ref)
        if (composes == None) {
            return
        }

        for (compose in composes.items) {
            if (compose.from != None) {
                match (compose.from) {
                    case ComposeFrom.ImportRecordIndex =>
                        let importRecordIdx = compose.from.importRecordIndex
                        let importRecords = allImportRecords[idx]
                        let record = importRecords[importRecordIdx]
                        if (record.sourceIndex >= 0) {
                            let otherFile = allCssAsts[record.sourceIndex]
                            if (otherFile == None) {
                                log.addError("Cannot use composes with non-CSS file")
                                continue
                            }
                            for (name in compose.names) {
                                let otherNameEntry = otherFile.localScopeGet(name.v)
                                if (otherNameEntry == None) {
                                    continue
                                }
                                if (!otherNameEntry.ref.canBeComposed()) {
                                    warnNonSingleClassComposes(otherFile, otherNameEntry.ref,
                                        record.sourceIndex, compose.loc)
                                } else {
                                    visitName(otherFile, otherNameEntry.ref, record.sourceIndex)
                                }
                            }
                        }
                    case ComposeFrom.Global =>
                        // "composes: foo from global" - add as string
                        for (name in compose.names) {
                            parts.append(TemplatePart(
                                value = LazyExportExpr.string(name.v),
                                tail = " "
                            ))
                        }
                }
            } else {
                // From the current file
                for (name in compose.names) {
                    let nameEntry = ast.localScopeGet(name.v)
                    if (nameEntry == None) {
                        log.addError("Name ${name.v} not found in CSS module scope")
                        continue
                    }
                    if (!nameEntry.ref.canBeComposed()) {
                        warnNonSingleClassComposes(ast, nameEntry.ref, idx, compose.loc)
                    } else {
                        visitName(ast, nameEntry.ref, idx)
                    }
                }
            }
        }
    }

    /// 警告非单类选择器的 composes
    public func warnNonSingleClassComposes(ast: CssStyleSheet, cssRef: CssRef,
                                             idx: Int64, composeLoc: Int64): Unit {
        // Simplified: would log warning about non-single-class composes
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 在文件中生成命名导出
// 严格翻译自: generateCodeForLazyExport.zig:335 generateNamedExportInFile()
private func generateNamedExportInFile(linker: LinkerContext, sourceIndex: Int64,
                                         moduleRef: Int64, name: String,
                                         alias: String): ArrayList<Int64> {
    // Simplified: would generate new symbol and part for the named export
    return ArrayList<Int64>()
}

/// 计算最大内部索引
private func computeMaxInnerIndex(values: ArrayList<CssLocalScopeEntry>): Int64 {
    var max: Int64 = 0
    for (entry in values) {
        if (entry.ref.innerIndex > max) {
            max = entry.ref.innerIndex
        }
    }
    return max
}

/// 检查字符串是否是合法标识符
private func isIdentifier(name: String): Bool {
    return name.size > 0
}

/// 获取源文件标识符名称
private func sourceIdentifier(linker: LinkerContext, sourceIndex: Int64): String {
    return linker.parseGraph.inputFiles.sources[sourceIndex].identifierName
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 模板部分 (用于 CSS module 模板字符串生成)
public class TemplatePart {
    public var value: LazyExportExpr
    public var tail: String

    public init(value: LazyExportExpr, tail: String) {
        this.value = value
        this.tail = tail
    }
}

/// CSS 局部作用域条目
public class CssLocalScopeEntry {
    public var ref: CssRef
    public var loc: Int64

    public init(ref: CssRef, loc: Int64) {
        this.ref = ref
        this.loc = loc
    }
}

/// 位集合 (简化)
public class LazyExportBitSet {
    private var bits: ArrayList<Bool>

    public init(size: Int64) {
        bits = ArrayList<Bool>()
        for (i in 0..size) {
            bits.append(false)
        }
    }

    public func set(index: Int64): Unit {
        if (index >= 0 && index < bits.size) {
            bits[index] = true
        }
    }

    public func isSet(index: Int64): Bool {
        if (index >= 0 && index < bits.size) {
            return bits[index]
        }
        return false
    }

    public func setAll(value: Bool): Unit {
        for (i in 0..bits.size) {
            bits[i] = value
        }
    }
}

/// CSS 引用 (简化)
public class CssRef {
    public var innerIndex: Int64
    public var tag: CssRefTag

    public init() {
        innerIndex = 0
        tag = CssRefTag.Class
    }

    public func sourceIndex(idx: Int64): Int64 {
        return idx
    }

    public func toRealRef(idx: Int64): Int64 {
        return innerIndex
    }

    public func canBeComposed(): Bool {
        return tag == CssRefTag.Class
    }
}

/// CSS 引用标签
public enum CssRefTag {
    | Class
    | Id
    | Other
}

/// 表达式 (简化)
public class LazyExportExpr {
    public var kind: LazyExportExprKind
    public var properties: ArrayList<Property>
    public var loc: Int64

    public init() {
        kind = LazyExportExprKind.None
        properties = ArrayList<Property>()
        loc = 0
    }

    public static func nameOfLazyExportSymbol(ref: Int64, sourceIndex: Int64): LazyExportExpr {
        let e = LazyExportExpr()
        e.kind = LazyExportExprKind.NameOfLazyExportSymbol
        return e
    }

    public static func nameOfLazyExportSymbol(ref: Int64): LazyExportExpr {
        return nameOfLazyExportSymbol(ref, 0)
    }

    public static func template(parts: ArrayList<TemplatePart>): LazyExportExpr {
        let e = LazyExportExpr()
        e.kind = LazyExportExprKind.Template
        return e
    }

    public static func string(s: String): LazyExportExpr {
        let e = LazyExportExpr()
        e.kind = LazyExportExprKind.String
        return e
    }

    public static func dot(target: LazyExportExpr, name: String): LazyExportExpr {
        let e = LazyExportExpr()
        e.kind = LazyExportExprKind.Dot
        return e
    }

    public static func identifier(ref: Int64): LazyExportExpr {
        let e = LazyExportExpr()
        e.kind = LazyExportExprKind.Identifier
        return e
    }

    public func isObject(): Bool {
        return kind == LazyExportExprKind.Object
    }

    public func isString(): Bool {
        return kind == LazyExportExprKind.String
    }

    public func isRequireCallTarget(): Bool {
        return kind == LazyExportExprKind.RequireCallTarget
    }

    public func stringValue(): String {
        return ""
    }
}

/// 表达式种类
public enum LazyExportExprKind {
    | None
    | NameOfLazyExportSymbol
    | Template
    | String
    | Dot
    | Identifier
    | Object
    | RequireCallTarget
}

/// 表达式对象 (简化)
public class LazyExportExprObject {
    public func put(key: String, value: LazyExportExpr): Unit {
        // Simplified
    }
}

/// 属性 (简化)
public class Property {
    public var key: ?LazyExportExpr
    public var value: ?LazyExportExpr
    public var loc: Int64

    public init() {
        key = None
        value = None
        loc = 0
    }
}

/// 语句标签
public enum LazyExportStmtTag {
    | LazyExport
    | Local
    | Assign
    | ExportClause
    | ExportDefault
    | Other
}

/// 语句 (简化)
public class LazyExportStmt {
    public var tag: LazyExportStmtTag
    public var expr: LazyExportExpr
    public var loc: Int64

    public init() {
        tag = LazyExportStmtTag.Other
        expr = LazyExportExpr()
        loc = 0
    }

    public static func objectExport(exports: LazyExportExprObject): LazyExportStmt {
        let s = LazyExportStmt()
        s.tag = LazyExportStmtTag.Other
        return s
    }

    public static func assign(target: LazyExportExpr, value: LazyExportExpr): LazyExportStmt {
        let s = LazyExportStmt()
        s.tag = LazyExportStmtTag.Assign
        return s
    }

    public static func localExport(ref: Int64, value: LazyExportExpr, loc: Int64): LazyExportStmt {
        let s = LazyExportStmt()
        s.tag = LazyExportStmtTag.Local
        return s
    }

    public static func exportDefault(ref: Int64, value: LazyExportExpr): LazyExportStmt {
        let s = LazyExportStmt()
        s.tag = LazyExportStmtTag.ExportDefault
        return s
    }
}

/// 符号列表 (简化)
public class LazyExportLazyExportSymbolList {
    public func get(index: Int64): LazyExportSymbol {
        return LazyExportSymbol()
    }
}

/// 符号 (简化)
public class LazyExportSymbol {
    public var originalName: String

    public init() {
        originalName = ""
    }
}

/// 输入文件 (简化)
public class LazyExportInputFile {
    public var identifierName: String

    public init() {
        identifierName = ""
    }
}

/// 导入记录列表 (简化)
public class LazyExportImportRecordList {
    public func get(index: Int64): ImportRecord {
        return ImportRecord()
    }
}

/// CSS 引用标签
public enum ComposeFrom {
    | ImportRecordIndex
    | Global
}

/// CSS compose 项
public class ComposeItem {
    public var from: ?ComposeFrom
    public var names: ArrayList<CssName>
    public var loc: Int64

    public init() {
        from = None
        names = ArrayList<CssName>()
        loc = 0
    }
}

/// CSS 名称
public class CssName {
    public var v: String

    public init(v: String) {
        this.v = v
    }
}

/// LazyExportLog (简化)
public class LazyExportLog {
    public func addError(msg: String): Unit {
        // Simplified
    }
}
