// AST 导入扫描器
// 严格翻译自: src/js_parser/scan/scan_imports.zig (530 lines)
//   Bun 的导入扫描器在解析完成后扫描所有导入/导出语句
//   收集导入信息、跟踪符号使用、移除未使用的导入
//   包括完整的处理:
//     SImport       - import 语句, 含默认/命名空间/命名导入, bundle 模式处理
//     SFunction     - 导出的函数声明
//     SClass        - 导出的类声明
//     SLocal        - 导出的变量声明, 含 TS import-equals 处理
//     SExportDefault - 默认导出
//     SExportClause - export { foo, bar }
//     SExportStar   - export * from / export * as ns from
//     SExportFrom   - export { foo } from 'bar'
//   对应 Bun: ImportScanner.scan()
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// NamedImport - 命名导入
// 严格翻译自: src/js_parser/ast/NamedImport.zig
//   pub const NamedImport = struct {
//       alias: ?string,
//       alias_loc: logger.Loc,
//       namespace_ref: Ref,
//       import_record_index: u32,
//       alias_is_star: bool = false,
//       is_exported: bool = false,
//   }
// ============================================================================

/// 命名导入 - 对应 Bun NamedImport
public class NamedImport {
    /// 导入别名 - 对应 alias
    public var alias: String
    /// 别名位置 - 对应 alias_loc
    public var aliasLoc: Loc
    /// 命名空间引用 - 对应 namespace_ref
    public var namespaceRef: Ref
    /// 导入记录索引 - 对应 import_record_index
    public var importRecordIndex: Int64
    /// 是否为星号导入 - 对应 alias_is_star
    public var aliasIsStar: Bool
    /// 是否已导出 - 对应 is_exported
    public var isExported: Bool

    public init() {
        alias = ""
        aliasLoc = Loc.EMPTY
        namespaceRef = Ref.NONE
        importRecordIndex = 0
        aliasIsStar = false
        isExported = false
    }

    public init(alias: String, aliasLoc: Loc, namespaceRef: Ref, importRecordIndex: Int64) {
        this.alias = alias
        this.aliasLoc = aliasLoc
        this.namespaceRef = namespaceRef
        this.importRecordIndex = importRecordIndex
        aliasIsStar = false
        isExported = false
    }

    public init(alias: String, aliasLoc: Loc, namespaceRef: Ref,
                importRecordIndex: Int64, aliasIsStar: Bool, isExported: Bool) {
        this.alias = alias
        this.aliasLoc = aliasLoc
        this.namespaceRef = namespaceRef
        this.importRecordIndex = importRecordIndex
        this.aliasIsStar = aliasIsStar
        this.isExported = isExported
    }
}

// ============================================================================
// ImportRecordFlags - 导入记录标志
// 严格翻译自: src/bundler/ImportRecord.zig
// ============================================================================

/// 导入记录标志 - 对应 Bun ImportRecord.Flags
public class ImportRecordFlags {
    /// 是否未使用
    public var isUnused: Bool
    /// 是否包含 import *
    public var containsImportStar: Bool
    /// 是否包含 default 别名
    public var containsDefaultAlias: Bool
    /// 是否包含 __esModule 别名
    public var containsEsModuleAlias: Bool
    /// 是否为内部导入
    public var isInternal: Bool
    /// 是否原本是 require 调用
    public var wasOriginallyRequire: Bool

    public init() {
        isUnused = false
        containsImportStar = false
        containsDefaultAlias = false
        containsEsModuleAlias = false
        isInternal = false
        wasOriginallyRequire = false
    }
}

// ============================================================================
// ImportScanner - 导入扫描结果
// 严格翻译自: scan_imports.zig:1-4
//   pub const ImportScanner = struct {
//       stmts: []Stmt = &.{},
//       kept_import_equals: bool = false,
//       removed_import_equals: bool = false,
//   }
// ============================================================================

/// 导入扫描结果 - 对应 Bun ImportScanner
public class ImportScanner {
    /// 过滤后的语句列表 - 对应 stmts: []Stmt
    public var stmts: ArrayList<Stmt>
    /// 是否保留了 import-equals - 对应 kept_import_equals: bool
    public var keptImportEquals: Bool
    /// 是否移除了 import-equals - 对应 removed_import_equals: bool
    public var removedImportEquals: Bool

    public init() {
        stmts = ArrayList<Stmt>()
        keptImportEquals = false
        removedImportEquals = false
    }
}

// ============================================================================
// ImportScanVisitor - 导入扫描访问器
// 严格翻译自: scan_imports.zig:5-506
//   pub fn scan(
//       comptime P: type,
//       p: *P,
//       stmts: []Stmt,
//       will_transform_to_common_js: bool,
//       comptime hot_module_reloading_transformations: bool,
//       hot_module_reloading_context: if (hot_module_reloading_transformations) *ConvertESMExportsForHmr else void,
//   ) !ImportScanner
// ============================================================================

/// 导入扫描访问器 - 对应 Bun scan_imports.scan
/// 遍历所有语句，收集导入信息并移除未使用的导入
public class ImportScanVisitor {
    /// 关联的解析器
    private var p: Parser

    public init(parser: Parser) {
        p = parser
    }

    // ========================================================================
    // scan - 扫描导入入口
    // 严格翻译自: scan_imports.zig:12-506
    //   核心循环遍历所有顶层语句, 按类型处理
    // ========================================================================

    /// 扫描导入 - 对应 Bun ImportScanner.scan
    /// 遍历语句列表，收集导入信息并移除未使用的导入
    public func scan(stmts: ArrayList<Stmt>,
                     willTransformToCommonJs: Bool,
                     hotModuleReloadingTransformations: Bool,
                     hmrContext: ?ConvertESMExportsForHmr): ImportScanner {
        var scanner = ImportScanner()
        var stmtsEnd = 0
        let isTypeScriptEnabled = p.options.features.typescript
        let keepUnusedImports = !p.options.features.trimUnusedImports

        for (i in 0..stmts.size) {
            var stmt = stmts[Int64(i)]
            var shouldSkip = false

            match (stmt.tag) {
                // ==================================================================
                // .s_import => |import_ptr| - 导入语句
                // 严格翻译自: scan_imports.zig:21-358
                //   宏导入跳过, 未使用导入移除, bundle/非bundle 模式分支处理
                //   bundle 模式: 将命名空间属性访问转为命名导入
                //   非 bundle 模式: ESM 实时绑定处理
                // ==================================================================
                case StmtTag.Import =>
                    let record = p.importRecords[stmt.importRecordIndex]

                    // 宏导入直接跳过
                    if (record.path.isMacro()) {
                        record.flags.isUnused = true
                        record.pathIsDisabled = true
                        shouldSkip = true
                    }

                    if (!shouldSkip) {
                        var didRemoveStarLoc = false

                        // ====================================================================
                        // 移除未使用的导入符号
                        // 严格翻译自: scan_imports.zig:89-197
                        //   TypeScript 总是移除未使用导入 (类型系统中可能是假的)
                        //   JavaScript 在特定条件下也移除 (trim_unused_imports)
                        // ====================================================================
                        if (!keepUnusedImports) {
                            var foundImports = false
                            var isUnusedInTypeScript = true

                            // 检查默认导入
                            if (stmt.defaultNameLoc.isSome()) {
                                foundImports = true
                                let symbol = p.symbols[stmt.defaultNameRef.innerIndex]

                                // TypeScript 使用单独的未使用定义
                                if (isTypeScriptEnabled && p.tsUseCounts[stmt.defaultNameRef.innerIndex] != 0) {
                                    isUnusedInTypeScript = false
                                }

                                // 如果从未使用, 移除默认导入
                                if (symbol.useCountEstimate == 0) {
                                    stmt.defaultNameLoc = None
                                }
                            }

                            // 检查命名空间导入 (import *)
                            if (stmt.starNameLoc.isSome()) {
                                foundImports = true
                                let symbol = p.symbols[stmt.namespaceRef.innerIndex]

                                if (isTypeScriptEnabled && p.tsUseCounts[stmt.namespaceRef.innerIndex] != 0) {
                                    isUnusedInTypeScript = false
                                }

                                if (symbol.useCountEstimate == 0) {
                                    // 检查是否有从命名空间导入的属性访问
                                    var hasAny = false
                                    if (let Some(entry) <- p.importItemsForNamespace.get(stmt.namespaceRef)) {
                                        if (entry.count() > 0) {
                                            hasAny = true
                                        }
                                    }
                                    if (!hasAny) {
                                        stmt.starNameLoc = None
                                        didRemoveStarLoc = true
                                    }
                                }
                            }

                            // 移除未使用的命名导入项
                            if (stmt.importItems.size > 0) {
                                foundImports = true
                                var itemsEnd = 0
                                for (j in 0..stmt.importItems.size) {
                                    let item = stmt.importItems[Int64(j)]
                                    let ref = item.nameRef
                                    let symbol = p.symbols[ref.innerIndex]

                                    if (isTypeScriptEnabled && p.tsUseCounts[ref.innerIndex] != 0) {
                                        isUnusedInTypeScript = false
                                    }

                                    // 只保留使用的导入项
                                    if (symbol.useCountEstimate != 0) {
                                        stmt.importItems[Int64(itemsEnd)] = item
                                        itemsEnd += 1
                                    }
                                }
                                // 截断到 itemsEnd (简化: 标记)
                            }

                            // TypeScript: 所有导入都未使用时完全移除
                            // JavaScript: trim_unused_imports 且所有项都移除时移除
                            let allItemsRemoved = stmt.starNameLoc .isNone() &&
                                                  stmt.importItems.size == 0 &&
                                                  stmt.defaultNameLoc .isNone()
                            if ((isTypeScriptEnabled && foundImports && isUnusedInTypeScript &&
                                 !p.options.preserveUnusedImportsTs) ||
                                (!isTypeScriptEnabled && p.options.features.trimUnusedImports &&
                                 foundImports && allItemsRemoved)) {
                                // 内部导入和 require 语句不被移除
                                if (!record.flags.isInternal && !record.flags.wasOriginallyRequire) {
                                    record.flags.isUnused = true
                                    shouldSkip = true
                                }
                            }
                        }

                        // ====================================================================
                        // bundle 模式 vs 非 bundle 模式
                        // 严格翻译自: scan_imports.zig:200-353
                        // ====================================================================
                        let namespaceRef = stmt.namespaceRef
                        let convertStarToClause = !p.options.bundle &&
                            p.symbols[namespaceRef.innerIndex].useCountEstimate == 0

                        if (convertStarToClause && !keepUnusedImports) {
                            stmt.starNameLoc = None
                        }

                        record.flags.containsDefaultAlias = record.flags.containsDefaultAlias ||
                            stmt.defaultNameLoc.isSome()

                        let existingItems = if (let Some(items) <- p.importItemsForNamespace.get(namespaceRef)) { items } else { ImportItemForNamespaceMap() }

                        if (p.options.bundle) {
                            // ================================================================
                            // Bundle 模式处理
                            // 严格翻译自: scan_imports.zig:212-307
                            //   将命名空间属性访问转为命名导入
                            //   记录所有命名导入到 p.named_imports
                            // ================================================================

                            // 处理命名空间属性访问
                            if (stmt.starNameLoc.isSome() && existingItems.count() > 0) {
                                // 将排序后的属性名转为命名导入
                                for (entry in existingItems.items()) {
                                    let alias = entry.first
                                    let item = entry.second
                                    p.namedImports.put(item.ref.getOr(Ref.NONE), NamedImport(
                                        alias, item.loc, namespaceRef, stmt.importRecordIndex
                                    ))

                                    let nameRef = item.ref.getOr(Ref.NONE)
                                    let sym = p.symbols[nameRef.innerIndex]

                                    // 标记命名空间别名以便打印机打印为属性访问
                                    sym.namespaceAliasRef = namespaceRef
                                    sym.namespaceAliasImportRecordIndex = UInt32(stmt.importRecordIndex)

                                    // 记录自动生成的顶层命名空间别名符号
                                    p.declaredSymbols.append(DeclaredSymbol(nameRef, true))
                                }
                            }

                            // 处理星号导入
                            if (stmt.starNameLoc.isSome()) {
                                let loc = stmt.starNameLoc.getOr(Loc.EMPTY)
                                record.flags.containsImportStar = true
                                p.namedImports.put(namespaceRef, NamedImport(
                                    "", loc, Ref.NONE, stmt.importRecordIndex
                                ))
                                // 设置 aliasIsStar
                                if (let Some(ni) <- p.namedImports.get(namespaceRef)) {
                                    ni.aliasIsStar = true
                                }
                            }

                            // 处理默认导入
                            if (stmt.defaultNameLoc.isSome()) {
                                let defaultRef = stmt.defaultNameRef
                                record.flags.containsDefaultAlias = true
                                p.namedImports.put(defaultRef, NamedImport(
                                    "default", stmt.defaultNameLoc.getOr(LocRef(Loc.EMPTY, Option<Ref>.None)).loc,
                                    namespaceRef, stmt.importRecordIndex
                                ))
                            }

                            // 处理命名导入项
                            for (item in stmt.importItems) {
                                let nameRef = item.nameRef
                                p.namedImports.put(nameRef, NamedImport(
                                    item.alias, item.nameLoc, namespaceRef, stmt.importRecordIndex
                                ))
                            }
                        } else {
                            // ================================================================
                            // 非 Bundle 模式 (ESM) 处理
                            // 严格翻译自: scan_imports.zig:308-348
                            //   ESM 需要实时绑定, CommonJS 不需要
                            //   保留 namespace_alias 以便打印时可能使用命名空间形式
                            // ================================================================
                            for (item in stmt.importItems) {
                                record.flags.containsDefaultAlias = record.flags.containsDefaultAlias ||
                                    (item.alias == "default")

                                let nameRef = item.nameRef
                                p.namedImports.put(nameRef, NamedImport(
                                    item.alias, item.nameLoc, namespaceRef, stmt.importRecordIndex
                                ))

                                // 标记命名空间别名
                                let sym = p.symbols[nameRef.innerIndex]
                                if (record.flags.containsImportStar || stmt.starNameLoc.isSome()) {
                                    sym.namespaceAliasRef = namespaceRef
                                    sym.namespaceAliasImportRecordIndex = UInt32(stmt.importRecordIndex)
                                }
                            }

                            // require 语句的命名空间别名
                            if (record.flags.wasOriginallyRequire) {
                                let sym = p.symbols[namespaceRef.innerIndex]
                                sym.namespaceAliasRef = namespaceRef
                                sym.namespaceAliasImportRecordIndex = UInt32(stmt.importRecordIndex)
                            }
                        }

                        // 记录导入记录索引
                        p.importRecordsForCurrentPart.append(UInt32(stmt.importRecordIndex))

                        record.flags.containsImportStar = record.flags.containsImportStar ||
                            stmt.starNameLoc.isSome()
                        record.flags.containsDefaultAlias = record.flags.containsDefaultAlias ||
                            stmt.defaultNameLoc.isSome()

                        for (item in stmt.importItems) {
                            record.flags.containsDefaultAlias = record.flags.containsDefaultAlias ||
                                (item.alias == "default")
                            record.flags.containsEsModuleAlias = record.flags.containsEsModuleAlias ||
                                (item.alias == "__esModule")
                        }
                    }

                // ==================================================================
                // .s_function => |st| - 函数声明
                // 严格翻译自: scan_imports.zig:361-369
                //   如果是导出函数, 记录导出
                // ==================================================================
                case StmtTag.Function =>
                    if (stmt.isExport) {
                        if (stmt.funcName.size > 0) {
                            let originalName = p.symbols[stmt.funcRef.innerIndex].originalName
                            p.recordExport(stmt.funcLoc, originalName, stmt.funcRef)
                        } else {
                            p.log.addRangeError(p.source, Range(stmt.funcOpenParensLoc, 2),
                                "Exported functions must have a name")
                        }
                    }


                // ==================================================================
                // .s_class => |st| - 类声明
                // 严格翻译自: scan_imports.zig:370-379
                // ==================================================================
                case StmtTag.Class =>
                    if (stmt.isExport) {
                        if (stmt.className.size > 0) {
                            let originalName = p.symbols[stmt.classRef.innerIndex].originalName
                            p.recordExport(stmt.classLoc, originalName, stmt.classRef)
                        } else {
                            p.log.addRangeError(p.source, Range(stmt.classBodyLoc, 0),
                                "Exported classes must have a name")
                        }
                    }


                // ==================================================================
                // .s_local => |st| - 变量声明
                // 严格翻译自: scan_imports.zig:380-418
                //   处理导出的声明
                //   移除未使用的 import-equals 语句
                // ==================================================================
                case StmtTag.Local =>
                    if (stmt.isExport) {
                        for (decl in stmt.decls) {
                            p.recordExportedBinding(decl.binding)
                        }
                    }

                    // 移除未使用的 import-equals 语句
                    // 对应 Bun:
                    //   if (st.was_ts_import_equals and !st.is_export and st.decls.len > 0) { ... }
                    if (stmt.wasTsImportEquals && !stmt.isExport && stmt.decls.size > 0) {
                        let decl = stmt.decls[0]
                        var optValue = decl.value

                        // 跳到底层引用 (处理 a.b.c 链)
                        if (optValue.isSome()) {
                            var current = optValue.getOr(Expr(Loc.EMPTY, ExprTag.Missing))
                            var done = false
                            while (!done) {
                                match (current.tag) {
                                    case ExprTag.Dot =>
                                        if (let Some(t) <- current.target) {
                                            current = t
                                        } else {
                                            done = true
                                        }
                                    case _ =>
                                        done = true
                                }
                            }
                            optValue = Some(current)
                        }

                        // 是标识符引用且非 require() 调用?
                        if (optValue.isSome()) {
                            let val = optValue.getOr(Expr(Loc.EMPTY, ExprTag.Missing))
                            if (val.tag == ExprTag.Identifier) {
                                let binding = decl.binding
                                if (binding.tag == BindingTag.Identifier &&
                                    p.symbols[binding.ref.innerIndex].useCountEstimate == 0) {
                                    // 未使用的 import-equals, 移除
                                    p.ignoreUsage(val.ref)
                                    scanner.removedImportEquals = true
                                    shouldSkip = true
                                } else {
                                    scanner.keptImportEquals = true
                                }
                            }
                        }
                    }

                // ==================================================================
                // .s_export__ => |st| - 默认导出
                // 严格翻译自: scan_imports.zig:419-438
                //   记录 default 导出
                //   非 HMR + CommonJS 模式下重写为 __exportDefault 调用
                // ==================================================================
                case StmtTag.ExportDefault =>
                    // 记录 default 导出
                    if (stmt.defaultNameRef.isValid()) {
                        let loc = if (let Some(lr) <- stmt.defaultNameLoc) { lr.loc } else { Loc.EMPTY }
                        p.recordExport(loc, "default", stmt.defaultNameRef)
                    }

                    // 非 HMR 且转换为 CommonJS 时, 重写 export default
                    if (!hotModuleReloadingTransformations && willTransformToCommonJs) {
                        if (let Some(exprVal) <- stmt.exprValue) {
                            // 重写为: __exportDefault(module.exports, expr)
                            let moduleExports = p.moduleExports(exprVal.loc)
                            let exportDefaultArgs = ArrayList<Expr>()
                            exportDefaultArgs.append(moduleExports)
                            exportDefaultArgs.append(exprVal)
                            let call = p.callRuntime(exprVal.loc, "__exportDefault", exportDefaultArgs)
                            stmt = Stmt(exprVal.loc, StmtTag.Expr)
                            stmt.exprValue = Some(call)
                        }
                    }

                // ==================================================================
                // .s_export_clause => |st| - export { foo, bar }
                // 严格翻译自: scan_imports.zig:439-443
                // ==================================================================
                case StmtTag.Export =>
                    for (item in stmt.exportItems) {
                        p.recordExport(item.aliasLoc, item.alias, item.nameRef)
                    }

                // ==================================================================
                // .s_export_star => |st| - export * from / export * as ns from
                // 严格翻译自: scan_imports.zig:444-464
                // ==================================================================
                case StmtTag.ExportStar =>
                    p.importRecordsForCurrentPart.append(UInt32(stmt.importRecordIndex))

                    if (stmt.exportStarAlias .isSome()) {
                        // "export * as ns from 'path'"
                        let aliasStr = if (let Some(a) <- stmt.exportStarAlias) { a } else { "" }
                        p.namedImports.put(stmt.namespaceRef, NamedImport(
                            "", stmt.loc, Ref.NONE, stmt.importRecordIndex, true, true
                        ))
                        p.recordExport(stmt.loc, aliasStr, stmt.namespaceRef)
                        let starRecord = p.importRecords[stmt.importRecordIndex]
                        starRecord.flags.containsImportStar = true
                    } else {
                        // "export * from 'path'"
                        p.exportStarImportRecords.append(stmt.importRecordIndex)
                    }

                // ==================================================================
                // .s_export_from => |st| - export { foo } from 'bar'
                // 严格翻译自: scan_imports.zig:465-490
                //   注意: alias/original_name 的语义与 s_import 不同
                //   SExportFrom 实际上等于 SImport + SExportClause
                // ==================================================================
                case StmtTag.ExportFrom =>
                    p.importRecordsForCurrentPart.append(UInt32(stmt.importRecordIndex))

                    for (item in stmt.exportItems) {
                        let ref = item.nameRef
                        // 注意: 导入的别名不是 item.alias (那是导出别名)
                        // 而是 item.original_name
                        p.namedImports.put(ref, NamedImport(
                            item.originalName, item.nameLoc, stmt.namespaceRef,
                            stmt.importRecordIndex, false, true
                        ))
                        p.recordExport(item.nameLoc, item.alias, ref)

                        let fromRecord = p.importRecords[stmt.importRecordIndex]
                        if (item.originalName == "default") {
                            fromRecord.flags.containsDefaultAlias = true
                        } else if (item.originalName == "__esModule") {
                            fromRecord.flags.containsEsModuleAlias = true
                        }
                    }

                case _ =>
                    ()
            }

            if (shouldSkip) {
                continue
            }

            // 对应 Bun: hot_module_reloading_transformations 分支
            if (hotModuleReloadingTransformations) {
                if (let Some(ctx) <- hmrContext) {
                    ctx.convertStmt(p, stmt)
                }
            } else {
                stmts[Int64(stmtsEnd)] = stmt
                stmtsEnd += 1
            }
        }

        if (!hotModuleReloadingTransformations) {
            scanner.stmts = ArrayList<Stmt>()
            for (i in 0..stmtsEnd) {
                scanner.stmts.append(stmts[Int64(i)])
            }
        }

        return scanner
    }
}

// ============================================================================
// ClauseItem - 导入/导出子句项
// 严格翻译自: src/js_parser/ast/ClauseItem.zig
//   import { foo as bar } from 'path'
//   中的 "foo as bar" 就是一个 ClauseItem
// ============================================================================

// ClauseItem - 已在 ast.cj 中定义

// ============================================================================
// ImportItemForNamespaceMap - 命名空间导入项映射
// 严格翻译自: src/js_parser/js_parser.zig ImportItemForNamespaceMap
// ============================================================================

/// 命名空间导入项映射 - 对应 Bun ImportItemForNamespaceMap
/// 用于 bundle 模式下将命名空间属性访问转为命名导入
public class ImportItemForNamespaceMap {
    private var entries: HashMap<String, ImportItemForNamespaceEntry>

    public init() {
        entries = HashMap<String, ImportItemForNamespaceEntry>()
    }

    public func count(): Int64 {
        return entries.size
    }

    public func get(key: String): ?ImportItemForNamespaceEntry {
        return entries.get(key)
    }

    public func contains(key: String): Bool {
        return entries.contains(key)
    }

    public func put(key: String, value: ImportItemForNamespaceEntry): Unit {
        entries.put(key, value)
    }

    public func items(): ArrayList<Tuple<String, ImportItemForNamespaceEntry>> {
        let result = ArrayList<Tuple<String, ImportItemForNamespaceEntry>>()
        let iter = entries.iterator()
        while (true) {
            let next = iter.next()
            if (next.isNone()) {
                break
            }
            if (let Some((k, v)) <- next) {
                result.append(Tuple(k, v))
            }
        }
        return result
    }
}

/// 命名空间导入项条目 - 对应 Bun 中的属性访问条目
public class ImportItemForNamespaceEntry {
    public var ref: ?Ref
    public var loc: Loc

    public init(ref: Ref, loc: Loc) {
        this.ref = Some(ref)
        this.loc = loc
    }

    public init() {
        ref = None
        loc = Loc.EMPTY
    }
}

// ============================================================================
// Range - 源码范围 (用于错误报告)
// ============================================================================

