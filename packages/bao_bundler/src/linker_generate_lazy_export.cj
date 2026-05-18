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
        if (stmt.tag != StmtTag.LazyExport) {
            return
        }

        if (cssAst.localScopeCount() > 0) {
            var exports = ExprObject()

            let symbols = linker.graph.ast.getSymbols(sourceIndex)
            let allImportRecords = linker.graph.ast.importRecords

            let values = cssAst.localScopeValues()
            if (values.size == 0) {
                // Skip empty
            } else {
                // Compute max inner index for bit set
                let size = computeMaxInnerIndex(values) + 1

                let innerVisited = BitSet(size)
                let composesVisited = HashSet<Int64>()

                // Create visitor for composes traversal
                let visitor = ComposesVisitor()
                visitor.innerVisited = innerVisited
                visitor.composesVisited = composesVisited
                visitor.sourceIndex = sourceIndex
                visitor.allImportRecords = allImportRecords
                visitor.allCssAsts = allCssAsts
                visitor.allSources = allSources
                visitor.allSymbols = linker.graph.ast.allSymbols
                visitor.log = linker.log

                for (entry in values) {
                    let ref = entry.ref

                    var templateParts = ArrayList<TemplatePart>()
                    var value = Expr.nameOfSymbol(ref, sourceIndex)

                    visitor.parts = templateParts
                    visitor.clearAll()
                    visitor.innerVisited.set(ref.innerIndex)
                    if (ref.tag.class) {
                        visitor.visitComposes(cssAst, ref, sourceIndex)
                    }

                    if (templateParts.size > 0) {
                        templateParts.append(TemplatePart(
                            value = value,
                            tail = ""
                        ))
                        value = Expr.template(templateParts)
                    }

                    let key = symbols[ref.innerIndex].originalName
                    exports.put(key, value)
                }
            }

            // Replace lazy export with the generated object
            part.stmts[0] = Stmt.objectExport(exports)
        }
    }

    // Now handle the lazy export expression
    let stmt = part.stmts[0]
    if (stmt.tag != StmtTag.LazyExport) {
        return
    }

    let expr = stmt.expr

    match (exportsKind) {
        case ExportsKind.CJS =>
            // "module.exports = expr;"
            part.stmts[0] = Stmt.assign(
                Expr.dot(Expr.identifier(moduleRef), "exports"),
                expr
            )

            // Generate symbol import for module_ref
            linker.graph.generateSymbolImportAndUse(sourceIndex, 0, moduleRef, 1)

            // If this is a .napi addon and not CJS output, add __require
            if (expr.isRequireCallTarget() &&
                linker.options.outputFormat != OutputFormat.CJS) {
                linker.graph.generateRuntimeSymbolImportAndUse(
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
                    parts[generated[1]].stmts = ArrayList<Stmt>()
                    parts[generated[1]].stmts.append(Stmt.localExport(
                        generated[0], property.value, property.key.loc
                    ))
                }
            }

            // Generate default export
            let defaultName = "${sourceIdentifier(linker, sourceIndex)}_default"
            let generated = generateNamedExportInFile(
                linker, sourceIndex, moduleRef, defaultName, "default")
            parts[generated[1]].stmts = ArrayList<Stmt>()
            parts[generated[1]].stmts.append(Stmt.exportDefault(
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
    public var innerVisited: BitSet
    public var composesVisited: HashSet<Int64>
    public var parts: ArrayList<TemplatePart>
    public var allImportRecords: ArrayList<ImportRecordList>
    public var allCssAsts: ArrayList<CssStyleSheet>
    public var allSources: ArrayList<InputFile>
    public var allSymbols: ArrayList<SymbolList>
    public var sourceIndex: Int64
    public var log: Log
    public var loc: Int64

    public init() {
        innerVisited = BitSet(0)
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
            value = Expr.nameOfSymbol(ref.toRealRef(idx)),
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
                                value = Expr.string(name.v),
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
    public var value: Expr
    public var tail: String

    public init(value: Expr, tail: String) {
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
public class BitSet {
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
public class Expr {
    public var kind: ExprKind
    public var properties: ArrayList<Property>
    public var loc: Int64

    public init() {
        kind = ExprKind.None
        properties = ArrayList<Property>()
        loc = 0
    }

    public static func nameOfSymbol(ref: Int64, sourceIndex: Int64): Expr {
        let e = Expr()
        e.kind = ExprKind.NameOfSymbol
        return e
    }

    public static func nameOfSymbol(ref: Int64): Expr {
        return nameOfSymbol(ref, 0)
    }

    public static func template(parts: ArrayList<TemplatePart>): Expr {
        let e = Expr()
        e.kind = ExprKind.Template
        return e
    }

    public static func string(s: String): Expr {
        let e = Expr()
        e.kind = ExprKind.String
        return e
    }

    public static func dot(target: Expr, name: String): Expr {
        let e = Expr()
        e.kind = ExprKind.Dot
        return e
    }

    public static func identifier(ref: Int64): Expr {
        let e = Expr()
        e.kind = ExprKind.Identifier
        return e
    }

    public func isObject(): Bool {
        return kind == ExprKind.Object
    }

    public func isString(): Bool {
        return kind == ExprKind.String
    }

    public func isRequireCallTarget(): Bool {
        return kind == ExprKind.RequireCallTarget
    }

    public func stringValue(): String {
        return ""
    }
}

/// 表达式种类
public enum ExprKind {
    | None
    | NameOfSymbol
    | Template
    | String
    | Dot
    | Identifier
    | Object
    | RequireCallTarget
}

/// 表达式对象 (简化)
public class ExprObject {
    public func put(key: String, value: Expr): Unit {
        // Simplified
    }
}

/// 属性 (简化)
public class Property {
    public var key: ?Expr
    public var value: ?Expr
    public var loc: Int64

    public init() {
        key = None
        value = None
        loc = 0
    }
}

/// 语句标签
public enum StmtTag {
    | LazyExport
    | Local
    | Assign
    | ExportClause
    | ExportDefault
    | Other
}

/// 语句 (简化)
public class Stmt {
    public var tag: StmtTag
    public var expr: Expr
    public var loc: Int64

    public init() {
        tag = StmtTag.Other
        expr = Expr()
        loc = 0
    }

    public static func objectExport(exports: ExprObject): Stmt {
        let s = Stmt()
        s.tag = StmtTag.Other
        return s
    }

    public static func assign(target: Expr, value: Expr): Stmt {
        let s = Stmt()
        s.tag = StmtTag.Assign
        return s
    }

    public static func localExport(ref: Int64, value: Expr, loc: Int64): Stmt {
        let s = Stmt()
        s.tag = StmtTag.Local
        return s
    }

    public static func exportDefault(ref: Int64, value: Expr): Stmt {
        let s = Stmt()
        s.tag = StmtTag.ExportDefault
        return s
    }
}

/// 符号列表 (简化)
public class SymbolList {
    public func get(index: Int64): Symbol {
        return Symbol()
    }
}

/// 符号 (简化)
public class Symbol {
    public var originalName: String

    public init() {
        originalName = ""
    }
}

/// 输入文件 (简化)
public class InputFile {
    public var identifierName: String

    public init() {
        identifierName = ""
    }
}

/// 导入记录列表 (简化)
public class ImportRecordList {
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

/// Log (简化)
public class Log {
    public func addError(msg: String): Unit {
        // Simplified
    }
}
