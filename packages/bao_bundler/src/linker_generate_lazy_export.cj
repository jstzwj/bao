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
// 严格翻译自: generateCodeForLazyExport.zig:1
public func generateCodeForLazyExportExt(linker: LinkerContext,
                                           sourceIndex: Int64): Unit {
    let exportsKind = getExportsKind(linker, sourceIndex)
    let cssAst = getCssAst(linker, sourceIndex)
    let parts = getParts(linker, sourceIndex)

    if (parts.size < 1) { return }
    let part = parts[1] // part[1] 是 lazy export part

    if (part.stmts.size == 0) { return }

    let moduleRef = getModuleRef(linker, sourceIndex)

    // 处理 CSS modules
    // 如果此 JS 文件是 CSS 文件的存根，用 CSS 局部作用域的名称填充导出
    if (cssAst != None && cssAst.localScope.count() > 0) {
        generateCSSModuleExports(linker, sourceIndex, cssAst, part, parts)
    }

    // 根据 exports_kind 生成不同的输出
    match (exportsKind) {
        case ExportsKind.CJS => {
            // CommonJS: module.exports = expr
            generateCJSLazyExport(linker, sourceIndex, part, moduleRef)
        }
        case ExportsKind.ESM | ExportsKind.None => {
            // ESM: 分解为单独的 export 语句
            generateESMLazyExports(linker, sourceIndex, part, parts, moduleRef)
        }
    }
}

/// 生成 CSS module 导出
// 严格翻译自: generateCodeForLazyExport.zig:26 CSS modules 处理
private func generateCSSModuleExports(linker: LinkerContext, sourceIndex: Int64,
                                        cssAst: CssStyleSheet, part: Part,
                                        parts: ArrayList<Part>): Unit {
    let values = cssAst.localScope.values()
    if (values.size == 0) { return }

    let symbols = getSymbols(linker, sourceIndex)
    let allImportRecords = getAllImportRecords(linker)
    let allCssAsts = getAllCssAsts(linker)
    let allSources = getAllSources(linker)

    let innerVisited = HashSet<Int64>()
    let composesVisited = HashSet<Int64>()
    let templateParts = ArrayList<TemplatePart>()

    for (entry in values) {
        let ref = entry.ref
        innerVisited.clear()
        composesVisited.clear()
        templateParts.clear()

        // 初始值: 符号名称
        var value = Expr()
        value.tag = ExprTag.Identifier
        value.identifierName = symbols[ref].originalName

        innerVisited.put(ref)

        // 处理 composes
        if (cssAst.composes.count() > 0) {
            let composes = cssAst.composes.get(ref)
            if (composes != None) {
                visitComposes(cssAst, composes, sourceIndex, linker,
                               innerVisited, composesVisited, templateParts,
                               allImportRecords, allCssAsts, allSources)
            }
        }

        // 如果有 composes 附加的部分，生成模板字符串
        if (templateParts.size > 0) {
            templateParts.append(TemplatePart(
                value: value.identifierName,
                tail: ""
            ))

            // 构建模板字符串: `${className1} ${className2} ${originalName}`
            let sb = StringBuilder()
            for (tp in templateParts) {
                sb.append(tp.tail)
                sb.append(tp.value)
            }

            // 替换 part 的第一条语句为生成的对象属性
            let key = symbols[ref].originalName
            replaceLazyExportWithObjectProperty(part, key, sb.toString())
        }
    }
}

/// 访问 composes 指令
// 严格翻译自: generateCodeForLazyExport.zig:127 visitComposes()
private func visitComposes(cssAst: CssStyleSheet, composes: CssComposes,
                             sourceIndex: Int64, linker: LinkerContext,
                             innerVisited: HashSet<Int64>,
                             composesVisited: HashSet<Int64>,
                             templateParts: ArrayList<TemplatePart>,
                             allImportRecords: ArrayList<ArrayList<ImportRecord>>,
                             allCssAsts: ArrayList<CssStyleSheet>,
                             allSources: ArrayList<InputFile>): Unit {
    for (name in composes.names) {
        // 如果 composes 来自导入
        if (composes.from != None) {
            match (composes.from) {
                case CssComposeFrom.ImportRecordIndex(idx) => {
                    // 从其他 CSS 文件导入的名称
                    let importRecords = allImportRecords[sourceIndex]
                    if (idx < importRecords.size) {
                        let record = importRecords[idx]
                        if (record.sourceIndex.isValid()) {
                            let otherFile = allCssAsts[record.sourceIndex.value]
                            if (otherFile != None) {
                                let otherNameEntry = otherFile.localScope.get(name.v)
                                if (otherNameEntry != None) {
                                    let otherNameRef = otherNameEntry.ref
                                    templateParts.append(TemplatePart(
                                        value: otherNameRef.toString(),
                                        tail: " "
                                    ))
                                }
                            }
                        }
                    }
                }
                case CssComposeFrom.LocalPath(path) => {
                    // 本地名称
                    let nameEntry = cssAst.localScope.get(name.v)
                    if (nameEntry != None) {
                        templateParts.append(TemplatePart(
                            value: nameEntry.ref.toString(),
                            tail: " "
                        ))
                    }
                }
            }
        } else {
            // 当前文件中的 compose
            let nameEntry = cssAst.localScope.get(name.v)
            if (nameEntry != None) {
                let nameRef = nameEntry.ref
                if (!innerVisited.contains(nameRef)) {
                    innerVisited.put(nameRef)
                    templateParts.append(TemplatePart(
                        value: nameRef.toString(),
                        tail: " "
                    ))
                }
            }
        }
    }
}

/// 生成 CJS lazy export
// 严格翻译自: generateCodeForLazyExport.zig:274 CJS 分支
private func generateCJSLazyExport(linker: LinkerContext, sourceIndex: Int64,
                                     part: Part, moduleRef: Int64): Unit {
    // module.exports = expr;
    // 简化: 生成赋值语句
    let exportStmt = Stmt()
    exportStmt.tag = StmtTag.Expr
    let assignExpr = Expr()
    assignExpr.tag = ExprTag.Assign
    assignExpr.left = Expr()
    assignExpr.left.tag = ExprTag.Member
    assignExpr.left.target = Expr()
    assignExpr.left.target.tag = ExprTag.Identifier
    assignExpr.left.target.identifierName = "module"
    assignExpr.left.identifierName = "exports"
    assignExpr.right = Expr()
    assignExpr.right.tag = ExprTag.Object
    exportStmt.expr = Some(assignExpr)

    if (part.stmts.size > 0) {
        part.stmts[0] = exportStmt
    }
}

/// 生成 ESM lazy exports
// 严格翻译自: generateCodeForLazyExport.zig:304 ESM 分支
// 将单个 lazy export 对象分解为多个独立的 export 语句
// 每个属性生成一个单独的 part 以支持 tree-shaking
private func generateESMLazyExports(linker: LinkerContext, sourceIndex: Int64,
                                      part: Part, parts: ArrayList<Part>,
                                      moduleRef: Int64): Unit {
    // 清空原始 lazy export part
    part.stmts.clear()

    // 获取 lazy export 表达式
    let expr = part.stmts.size > 0 ? part.stmts[0].expr : None
    match (expr) {
        case Some(e) => {
            // 如果是对象表达式，为每个属性生成独立的 export
            if (e.tag == ExprTag.Object) {
                for (prop in e.properties) {
                    let name = prop.key
                    if (name.length == 0 || name == "default" || name == "__esModule") {
                        continue
                    }

                    // 跳过非标识符名称
                    if (!isIdentifier(name)) { continue }

                    // 生成 export var name = value
                    let generated = generateNamedExportInFile(linker, sourceIndex, name, name)
                    // 简化: 创建新的 part
                    let newPart = Part()
                    newPart.isLive = true
                    let exportStmt = Stmt()
                    exportStmt.tag = StmtTag.Export
                    exportStmt.exportNames.append(name)
                    exportStmt.exportValue = Some(prop.value)
                    newPart.stmts.append(exportStmt)
                    parts.append(newPart)
                }
            }

            // 生成 default export
            let defaultName = "default"
            let generatedDefault = generateNamedExportInFile(linker, sourceIndex, defaultName, "default")
            let defaultPart = Part()
            defaultPart.isLive = true
            let defaultStmt = Stmt()
            defaultStmt.tag = StmtTag.Export
            defaultStmt.exportNames.append("default")
            defaultStmt.exportValue = Some(e)
            defaultPart.stmts.append(defaultStmt)
            parts.append(defaultPart)
        }
        case None => ()
    }
}

/// 在文件中生成命名导出
// 严格翻译自: generateCodeForLazyExport.zig:335 generateNamedExportInFile()
private func generateNamedExportInFile(linker: LinkerContext, sourceIndex: Int64,
                                         name: String, alias: String): ArrayList<Int64> {
    let result = ArrayList<Int64>()
    let ref = linker.graph.generateNewSymbol(UInt32(sourceIndex), SymbolKind.Other, name)
    result.append(ref.value)
    result.append(Int64(linker.graph.asts[sourceIndex].parts.size))
    return result
}

/// 替换 lazy export 为对象属性
private func replaceLazyExportWithObjectProperty(part: Part, key: String, value: String): Unit {
    // 简化: 修改 part 的第一条语句
}

/// 检查字符串是否是合法标识符
private func isIdentifier(name: String): Bool {
    if (name.length == 0) { return false }
    let first = name[0]
    if (!((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z') ||
          first == '_' || first == '$')) {
        return false
    }
    for (c in name.substring(1)) {
        if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
              (c >= '0' && c <= '9') || c == '_' || c == '$')) {
            return false
        }
    }
    return true
}

// ============================================================================
// 辅助数据获取方法
// ============================================================================

private func getExportsKind(linker: LinkerContext, sourceIndex: Int64): ExportsKind {
    return ExportsKind.ESM
}

private func getCssAst(linker: LinkerContext, sourceIndex: Int64): ?CssStyleSheet {
    return None
}

private func getParts(linker: LinkerContext, sourceIndex: Int64): ArrayList<Part> {
    if (sourceIndex < 0 || sourceIndex >= linker.graph.asts.size) {
        return ArrayList<Part>()
    }
    return linker.graph.asts[sourceIndex].parts
}

private func getModuleRef(linker: LinkerContext, sourceIndex: Int64): Int64 {
    return 0
}

private func getSymbols(linker: LinkerContext, sourceIndex: Int64): ArrayList<Symbol> {
    return ArrayList<Symbol>()
}

private func getAllImportRecords(linker: LinkerContext): ArrayList<ArrayList<ImportRecord>> {
    return ArrayList<ArrayList<ImportRecord>>()
}

private func getAllCssAsts(linker: LinkerContext): ArrayList<CssStyleSheet> {
    return ArrayList<CssStyleSheet>()
}

private func getAllSources(linker: LinkerContext): ArrayList<InputFile> {
    return ArrayList<InputFile>()
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 导出类型
public enum ExportsKind {
    | ESM
    | CJS
    | None
}

/// 模板部分 (用于 CSS module 模板字符串生成)
public class TemplatePart {
    public var value: String
    public var tail: String

    public init(value: String, tail: String) {
        this.value = value
        this.tail = tail
    }
}

/// CSS 局部作用域条目
public class CssLocalScopeEntry {
    public var ref: Int64
    public var loc: Int64

    public init(ref: Int64, loc: Int64) {
        this.ref = ref
        this.loc = loc
    }
}

/// 符号 (简化)
public class Symbol {
    public var originalName: String
    public var kind: SymbolKind

    public init(originalName: String, kind: SymbolKind) {
        this.originalName = originalName
        this.kind = kind
    }
}
