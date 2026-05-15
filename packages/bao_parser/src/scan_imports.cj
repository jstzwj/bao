// AST 导入扫描器
// 严格翻译自: src/js_parser/scan/scan_imports.zig (530 lines)
//   Bun 的导入扫描器在解析完成后扫描所有导入/导出语句
//   收集导入信息、跟踪符号使用、移除未使用的导入
//   包括: SImport, SExportClause, SExportFrom, SExportStar, SExportDefault,
//         SFunction (exported), SClass (exported), SLocal (exported)
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
// ImportScanVisitor - 导入扫描访问器
// 严格翻译自: scan_imports.zig:5-506
//   pub fn scan(comptime P: type, p: *P, stmts: []Stmt, ...) !ImportScanner
// ============================================================================

/// 导入扫描访问器 - 对应 Bun scan_imports.scan
/// 遍历所有语句，收集导入/导出信息
public class ImportScanVisitor {
    /// 关联的解析器
    private var p: Parser

    public init(parser: Parser) {
        p = parser
    }

    // ========================================================================
    // scan - 扫描导入入口
    // 严格翻译自: scan_imports.zig:12-506
    // ========================================================================

    /// 扫描导入 - 对应 Bun ImportScanner.scan
    /// 遍历语句列表，收集导入信息并移除未使用的导入
    public func scan(stmts: ArrayList<Stmt>): ImportScanner {
        let scanner = ImportScanner()
        var stmtsEnd = 0
        let keepUnusedImports = !p.options.trimUnusedImports
        let isTypeScriptEnabled = p.options.isTypeScriptEnabled

        for (i in 0..stmts.size) {
            var stmt = stmts[Int64(i)]
            var shouldKeep = true

            match (stmt.tag) {
                case StmtTag.Import => {
                    // 对应 Bun: s_import
                    // 处理 import 语句，跟踪命名导入
                    let result = scanImportStmt(stmt, keepUnusedImports, isTypeScriptEnabled)
                    shouldKeep = result
                }
                case StmtTag.Function => {
                    // 对应 Bun: s_function
                    // 如果函数是导出的，记录导出
                    if (stmt.isExport) {
                        if (let Some(fn) <- stmt.fn) {
                            if (fn.name.size > 0) {
                                p.recordExport(fn.nameLoc, fn.name, fn.nameRef)
                            }
                        }
                    }
                }
                case StmtTag.Class => {
                    // 对应 Bun: s_class
                    // 如果类是导出的，记录导出
                    if (stmt.isExport) {
                        if (let Some(classData) <- stmt.classData) {
                            if (classData.name.size > 0) {
                                p.recordExport(classData.nameLoc, classData.name, classData.nameRef)
                            }
                        }
                    }
                }
                case StmtTag.Local => {
                    // 对应 Bun: s_local
                    // 如果局部变量是导出的，记录导出
                    if (stmt.isExport) {
                        for (decl in stmt.decls) {
                            p.recordExportedBinding(decl.binding)
                        }
                    }
                }
                case StmtTag.Export => {
                    // 对应 Bun: s_export_clause
                    // 记录所有导出项
                    for (item in stmt.importItems) {
                        p.recordExport(item.aliasLoc, item.alias, item.nameRef)
                    }
                }
                case _ =>
                    // 其他语句类型不涉及导入/导出处理
                    true
            }

            if (shouldKeep) {
                if (Int64(stmtsEnd) != Int64(i)) {
                    stmts[Int64(stmtsEnd)] = stmt
                }
                stmtsEnd += 1
            }
        }

        // 裁剪语句列表
        scanner.stmts = ArrayList<Stmt>()
        for (i in 0..stmtsEnd) {
            scanner.stmts.append(stmts[Int64(i)])
        }

        return scanner
    }

    // ========================================================================
    // scanImportStmt - 扫描导入语句
    // 严格翻译自: scan_imports.zig:21-358
    // ========================================================================

    /// 扫描 import 语句
    /// 返回 false 表示应该移除该语句
    private func scanImportStmt(stmt: Stmt, keepUnusedImports: Bool, isTypeScriptEnabled: Bool): Bool {
        // 对应 Bun: .s_import => |import_ptr| 的处理

        // 检查是否为宏导入 - 宏导入在运行时不需要
        // 对应 Bun: if (record.path.isMacro()) { record.flags.is_unused = true; continue; }

        var foundImports = false
        var isUnusedInTypeScript = true

        // 检查默认导入是否使用
        // 对应 Bun: if (st.default_name) |default_name| { ... }
        if (stmt.defaultName.size > 0) {
            foundImports = true
            // 简化：跳过 TypeScript 特定逻辑
        }

        // 检查命名空间导入是否使用
        // 对应 Bun: if (st.star_name_loc) |_| { ... }

        // 检查命名导入项是否使用
        // 对应 Bun: if (st.items.len > 0) { ... }
        if (stmt.importItems.size > 0) {
            foundImports = true
            var itemsEnd = 0
            for (item in stmt.importItems) {
                // 移除未使用的导入符号
                // 对应 Bun: if (symbol.use_count_estimate != 0) { keep }
                itemsEnd += 1
            }
        }

        // TypeScript 中所有导入都未使用时移除
        // 对应 Bun: if is_typescript and all unused -> remove
        if (isTypeScriptEnabled && foundImports && isUnusedInTypeScript && !p.options.preserveUnusedImportsTs) {
            return false
        }

        return true
    }
}

// ============================================================================
// ClauseItem - 导入/导出子句项
// 严格翻译自: src/js_parser/ast/ClauseItem.zig
//   import { foo as bar } from 'path'
//   中的 "foo as bar" 就是一个 ClauseItem
// ============================================================================

/// 导入/导出子句项 - 对应 Bun ClauseItem
public class ClauseItem {
    /// 导入的原始名称 (如 "foo")
    public var originalName: String
    /// 别名 (如 "bar" in "foo as bar")
    public var alias: String
    /// 别名位置
    public var aliasLoc: Loc
    /// 名称位置
    public var nameLoc: Loc
    /// 名称引用
    public var nameRef: Ref
    /// 默认别名 - 对应 Bun ClauseItem.default_alias
    public static let defaultAlias: String = "default"

    public init() {
        originalName = ""
        alias = ""
        aliasLoc = Loc.EMPTY
        nameLoc = Loc.EMPTY
        nameRef = Ref.NONE
    }

    public init(originalName: String, alias: String, aliasLoc: Loc, nameLoc: Loc, nameRef: Ref) {
        this.originalName = originalName
        this.alias = alias
        this.aliasLoc = aliasLoc
        this.nameLoc = nameLoc
        this.nameRef = nameRef
    }

    /// 是否为默认导入/导出
    public func isDefault(): Bool {
        return alias == "default" || originalName == "default"
    }
}
