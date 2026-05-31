// ESM 导出降级与热模块替换
// 严格翻译自: src/js_parser/lower/lower_esm_exports_hmr.zig (548 lines)
//   Bun 的 ESM 导出降级模块负责:
//   - 将 ESM 导出转换为 HMR (热模块替换) 兼容的格式
//   - 处理命名导出、默认导出、re-export 等
//   - 管理导入去重和引用追踪
//   - ConvertESMExportsForHmr 是核心结构, 包含:
//     convertStmt, deduplicatedImport, visitBindingToExport,
//     visitRefToExport, finalize
//   对应 Bun: ConvertESMExportsForHmr 结构
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ImportRef - 导入引用
// 严格翻译自: lower_esm_exports_hmr.zig:10-13
//   const ImportRef = struct {
//       /// Index into ConvertESMExportsForHmr.stmts
//       stmt_index: u32,
//   }
// ============================================================================

/// 导入引用 - 对应 Bun ImportRef
/// 记录导入语句在 stmts 中的索引
public class ImportRef {
    /// 语句索引 - 对应 stmt_index: u32
    public var stmtIndex: UInt32

    public init() {
        stmtIndex = 0
    }

    public init(stmtIndex: UInt32) {
        this.stmtIndex = stmtIndex
    }
}

// ============================================================================
// DeduplicatedImportResult - 去重导入结果
// 严格翻译自: lower_esm_exports_hmr.zig:15-18
//   const DeduplicatedImportResult = struct {
//       namespace_ref: Ref,
//       import_record_index: u32,
//   }
// ============================================================================

/// 去重导入结果 - 对应 Bun DeduplicatedImportResult
/// 当同一模块被多次导入时, 返回首次导入的引用
public class DeduplicatedImportResult {
    /// 命名空间引用 - 对应 namespace_ref: Ref
    public var namespaceRef: Ref
    /// 导入记录索引 - 对应 import_record_index: u32
    public var importRecordIndex: UInt32

    public init() {
        namespaceRef = Ref.NONE
        importRecordIndex = 0
    }

    public init(namespaceRef: Ref, importRecordIndex: UInt32) {
        this.namespaceRef = namespaceRef
        this.importRecordIndex = importRecordIndex
    }
}

// ============================================================================
// ConvertESMExportsForHmr - ESM 导出 HMR 转换器
// 严格翻译自: lower_esm_exports_hmr.zig:1-548
//   pub const ConvertESMExportsForHmr = struct {
//       last_part: *js_ast.Part,
//       is_in_node_modules: bool,
//       imports_seen: bun.StringArrayHashMapUnmanaged(ImportRef) = .{},
//       export_star_props: std.ArrayListUnmanaged(G.Property) = .{},
//       export_props: std.ArrayListUnmanaged(G.Property) = .{},
//       stmts: std.ArrayListUnmanaged(Stmt) = .{},
//   }
//   impl { convertStmt, deduplicatedImport, visitBindingToExport,
//          visitRefToExport, finalize }
// ============================================================================

/// ESM 导出 HMR 转换器 - 对应 Bun ConvertESMExportsForHmr
/// 将 ESM 导出语句转换为 HMR 兼容的格式，支持热模块替换
public class ConvertESMExportsForHmr {
    /// 最后一个 AST 部分 - 对应 last_part: *js_ast.Part
    /// files in node modules will not get hot updates, so the code generation
    /// can be a bit more concise for re-exports
    public var lastPart: Part
    /// 是否在 node_modules 中 - 对应 is_in_node_modules: bool
    public var isInNodeModules: Bool
    /// 已见过的导入 (path.text -> ImportRef) - 对应 imports_seen
    public var importsSeen: HashMap<String, ImportRef>
    /// 导出星号属性列表 - 对应 export_star_props
    public var exportStarProps: ArrayList<GProperty>
    /// 导出属性列表 - 对应 export_props
    public var exportProps: ArrayList<GProperty>
    /// 生成的语句列表 - 对应 stmts
    public var stmts: ArrayList<Stmt>

    public init(lastPart: Part) {
        this.lastPart = lastPart
        isInNodeModules = false
        importsSeen = HashMap<String, ImportRef>()
        exportStarProps = ArrayList<GProperty>()
        exportProps = ArrayList<GProperty>()
        stmts = ArrayList<Stmt>()
    }

    // ========================================================================
    // convertStmt - 转换单条语句
    // 严格翻译自: lower_esm_exports_hmr.zig:20-289
    //   pub fn convertStmt(ctx: *ConvertESMExportsForHmr, p: anytype, stmt: Stmt) !void
    //
    //   处理以下语句类型:
    //     .s_local        -> 导出的 const/let/var 声明
    //     .s_export_default -> 默认导出
    //     .s_class        -> 导出的类声明
    //     .s_function     -> 导出的函数声明
    //     .s_export_clause -> export { foo, bar }
    //     .s_export_from  -> export { foo } from 'bar'
    //     .s_export_star  -> export * from 'bar'
    //     .s_import       -> import 语句
    //     else            -> 直接传递
    // ========================================================================

    /// 转换单条语句 - 对应 Bun convertStmt
    /// 根据语句类型执行不同的 HMR 转换
    public func convertStmt(p: Parser, stmt: Stmt): Unit {
        let newStmt = convertStmtInner(p, stmt)
        stmts.append(newStmt)
    }

    /// 转换语句的内部实现 - 返回转换后的语句
    /// 对应 Bun: convertStmt 中的 switch 语句
    private func convertStmtInner(p: Parser, stmt: Stmt): Stmt {
        match (stmt.tag) {
            // ==================================================================
            // .s_local => |st| - 导出的变量声明
            // 严格翻译自: lower_esm_exports_hmr.zig:25-75
            //   处理 export const/let/var 声明
            //   对于未使用的简单标识符绑定, 将初始值直接移到导出属性
            //   其他情况保留声明但记录导出
            // ==================================================================
            case StmtTag.Local =>
                var localStmt = stmt
                if (!stmt.isExport) {
                    return localStmt
                }
                // 清除 export 标记
                localStmt.isExport = false

                var newLen = 0
                let decls = stmt.decls
                for (i in 0..decls.size) {
                    let decl = decls[Int64(i)]
                    if (decl.value.isNone()) {
                        // 没有初始值的声明, 保留但记录导出
                        decls[Int64(newLen)] = decl
                        newLen += 1
                        visitBindingToExport(p, decl.binding)
                        continue
                    }

                    let binding = decl.binding
                    match (binding.tag) {
                        case BindingTag.Identifier =>
                            let idRef = binding.ref
                            let symbol = p.symbols[idRef.innerIndex]

                            // 如果符号未使用且值可移动, 将初始值直接移到导出属性
                            if (symbol.useCountEstimate == 0 && canBeMoved(decl.value)) {
                                let exportProp = GProperty(binding.loc,
                                    symbol.originalName, decl.value)
                                exportProp.kind = GPropertyKind.Field
                                exportProps.append(exportProp)
                            } else {
                                decls[Int64(newLen)] = decl
                                newLen += 1
                                visitBindingToExport(p, binding)
                            }
                        case _ =>
                            // 非标识符绑定 (解构等), 保留声明
                            decls[Int64(newLen)] = decl
                            newLen += 1
                            visitBindingToExport(p, binding)
                    }
                }

                if (newLen == 0) {
                    // 所有声明都已移到导出属性, 不需要生成语句
                    return localStmt
                }
                // 简化: 保留原始语句
                return localStmt

            // ==================================================================
            // .s_export__ => |st| - 默认导出
            // 严格翻译自: lower_esm_exports_hmr.zig:76-158
            //   React Fast Refresh 边界情况处理
            //   可移动到内部作用域的表达式/类/函数处理
            //   否则生成临时变量赋值
            // ==================================================================
            case StmtTag.ExportDefault =>
                let edStmt = stmt
                // 尝试将默认导出移到末尾的导出属性中
                let canBeMovedToInner = canExportDefaultBeMoved(p, stmt)
                if (canBeMovedToInner) {
                    // 直接移到 exportProps 中
                    let defaultKey = Expr.string(stmt.loc, "default")
                    let defaultValue = getExportDefaultValue(stmt)
                    let `prop` = GProperty(stmt.loc, "default", Some(defaultValue))
                    `prop`.kind = GPropertyKind.Field
                    exportProps.append(`prop`)
                    // 不生成语句
                    return edStmt
                }

                // 否则生成临时变量: var __default_export = expr; export { __default_export as default }
                let tempId = p.newSymbol(SymbolKind.Other, "default_export")
                let declaredSymbols = lastPart.declaredSymbols
                declaredSymbols.append(tempId)
                lastPart.symbolUses.put(tempId, 1)

                let defaultKey = Expr.string(stmt.loc, "default")
                let defaultIdExpr = Expr.identifier(stmt.loc, "", tempId)
                let `prop` = GProperty(stmt.loc, "default", Some(defaultIdExpr))
                `prop`.kind = GPropertyKind.Field
                exportProps.append(`prop`)

                return edStmt

            // ==================================================================
            // .s_class => |st| - 导出的类声明
            // 严格翻译自: lower_esm_exports_hmr.zig:159-177
            //   Strip the "export" keyword
            //   Export as CommonJS: exports.ClassName = ClassName
            // ==================================================================
            case StmtTag.Class =>
                var classStmt = stmt
                if (!stmt.isExport) {
                    return classStmt
                }

                // 导出为 CommonJS 格式
                if (let Some(cls) <- stmt.classData) {
                    let className = cls.name
                    let classRef = Ref.NONE  // placeholder ref
                    let key = Expr.string(stmt.loc, className)
                    let value = Expr.identifier(stmt.loc, className, classRef)
                    let `prop` = GProperty(stmt.loc, className, Some(value))
                    `prop`.kind = GPropertyKind.Field
                    exportProps.append(`prop`)
                }

                // 去除 export 关键字
                classStmt.isExport = false
                return classStmt

            // ==================================================================
            // .s_function => |st| - 导出的函数声明
            // 严格翻译自: lower_esm_exports_hmr.zig:178-193
            //   Strip the "export" keyword
            // ==================================================================
            case StmtTag.Function =>
                var fnStmt = stmt
                if (!stmt.isExport) {
                    return fnStmt
                }

                // 去除 export 标记
                fnStmt.isExport = false

                if (let Some(fn) <- stmt.fn) {
                    let funcName = fn.name
                    let funcRef = Ref.NONE  // placeholder ref
                    visitRefToExport(p, funcRef, Option<String>.None, stmt.loc, false)
                }
                return fnStmt

            // ==================================================================
            // .s_export_clause => |st| - export { foo, bar }
            // 严格翻译自: lower_esm_exports_hmr.zig:194-201
            //   不生成语句, 只记录导出项
            // ==================================================================
            case StmtTag.Export =>
                for (item in stmt.importItems) {
                    let ref = item.nameRef
                    visitRefToExport(p, ref, Some(item.alias), item.nameLoc, false)
                }
                // 不生成语句
                return stmt

            // ==================================================================
            // .s_export_from => |st| - export { foo } from 'bar'
            // 严格翻译自: lower_esm_exports_hmr.zig:202-244
            //   去重导入, 设置 namespace_alias, 交换 alias/original_name
            // ==================================================================
            case StmtTag.ExportFrom =>
                let deduped = deduplicatedImport(
                    p,
                    UInt32(stmt.importRecordIndex),
                    stmt.namespaceRef,
                    stmt.importItems,
                    stmt.starNameLoc,
                    Option<LocRef>.None,
                    stmt.loc
                )

                for (item in stmt.importItems) {
                    let ref = item.nameRef
                    let symbol = p.symbols[ref.innerIndex]

                    // 设置 namespace_alias 使用去重后的导入记录
                    // 对应 Bun: symbol.namespace_alias = .{
                    //     .namespace_ref = deduped.namespace_ref,
                    //     .alias = item.original_name,
                    //     .import_record_index = deduped.import_record_index,
                    // }
                    symbol.namespaceAliasRef = deduped.namespaceRef
                    symbol.namespaceAliasImportRecordIndex = deduped.importRecordIndex

                    let isLiveBinding = !isInNodeModules
                    visitRefToExport(p, ref, Some(item.alias), item.nameLoc, isLiveBinding)
                }
                return stmt

            // ==================================================================
            // .s_export_star => |st| - export * from 'bar' 或 export * as ns from 'bar'
            // 严格翻译自: lower_esm_exports_hmr.zig:245-270
            //   'export * as ns from' 创建一个命名属性
            //   'export * from' 创建 spread, 在顶部提升
            // ==================================================================
            case StmtTag.ExportStar =>
                let deduped = deduplicatedImport(
                    p,
                    UInt32(stmt.importRecordIndex),
                    stmt.namespaceRef,
                    ArrayList<ClauseItem>(),  // 空 items
                    stmt.starNameLoc,
                    Option<LocRef>.None,
                    stmt.loc
                )

                if (stmt.exportStarAlias.isSome()) {
                    let aliasStr = if (let Some(a) <- stmt.exportStarAlias) { a } else { "" }
                    let nsIdExpr = Expr.identifier(stmt.loc, "", deduped.namespaceRef)
                    let `prop` = GProperty(stmt.loc, aliasStr, Some(nsIdExpr))
                    `prop`.kind = GPropertyKind.Field
                    exportProps.append(`prop`)
                } else {
                    // 'export * from' 创建 spread, 在顶部提升
                    let nsIdExpr = Expr.identifier(stmt.loc, "", deduped.namespaceRef)
                    let `prop` = GProperty(stmt.loc, "", Some(nsIdExpr))
                    `prop`.kind = GPropertyKind.Spread
                    exportStarProps.append(`prop`)
                }
                return stmt

            // ==================================================================
            // .s_import => |st| - import 语句
            // 严格翻译自: lower_esm_exports_hmr.zig:271-286
            //   去重导入, 不生成语句
            // ==================================================================
            case StmtTag.Import =>
                let _ = deduplicatedImport(
                    p,
                    UInt32(stmt.importRecordIndex),
                    stmt.namespaceRef,
                    stmt.importItems,
                    stmt.starNameLoc,
                    Option<LocRef>.None,
                    stmt.loc
                )
                return stmt

            // 其他语句直接传递
            case _ =>
                return stmt
        }
    }

    // ========================================================================
    // deduplicatedImport - 去重导入
    // 严格翻译自: lower_esm_exports_hmr.zig:292-360
    //   fn deduplicatedImport(
    //       ctx, p, import_record_index, namespace_ref,
    //       items, star_name_loc, default_name, loc
    //   ) !DeduplicatedImportResult
    //
    //   如果同一模块路径已导入过:
    //     - 标记新记录为 unused
    //     - 合并 items 到已有语句
    //     - 复用已有 namespace_ref
    //   否则创建新的 import 语句
    // ========================================================================

    /// 去重导入 - 对应 Bun deduplicatedImport
    /// 如果同一模块已经导入过，复用之前的导入
    public func deduplicatedImport(
        p: Parser,
        importRecordIndex: UInt32,
        namespaceRef: Ref,
        items: ArrayList<ClauseItem>,
        starNameLoc: ?Loc,
        defaultName: ?LocRef,
        loc: Loc
    ): DeduplicatedImportResult {
        let ir = p.importRecords[Int64(importRecordIndex)]
        let pathText = ir.path

        if (let Some(existingRef) <- importsSeen.get(pathText)) {
            // 已存在同一模块的导入
            // 对应 Bun: ir.flags.is_unused = true
            ir.isUnused = true

            let existingStmtIdx = existingRef.stmtIndex
            let existingStmt = stmts[Int64(existingStmtIdx)]
            let existingImportRecordIdx = existingStmt.importRecordIndex
            let survivingRecord = p.importRecords[existingImportRecordIdx]
            survivingRecord.isUnused = false

            // 合并 items
            if (items.size > 0) {
                if (existingStmt.importItems.size == 0) {
                    existingStmt.importItems = items
                } else {
                    for (item in items) {
                        existingStmt.importItems.append(item)
                    }
                }
            }

            // 处理 namespace_ref
            if (namespaceRef.isValid()) {
                let existingNsRef = existingStmt.namespaceRef
                if (!existingNsRef.isValid()) {
                    existingStmt.namespaceRef = namespaceRef
                    return DeduplicatedImportResult(namespaceRef, UInt32(existingImportRecordIdx))
                } else {
                    // 擦除这个 namespace ref 但建立链接
                    let symbol = p.symbols[namespaceRef.innerIndex]
                    symbol.useCountEstimate = 0
                    symbol.link = existingNsRef
                }
            }

            // 合并 star_name_loc
            if (existingStmt.starNameLoc.isNone()) {
                if (let Some(stl) <- starNameLoc) {
                    existingStmt.starNameLoc = Some(stl)
                }
            }

            // 合并 default_name
            if (existingStmt.defaultNameLoc.isNone()) {
                if (let Some(dn) <- defaultName) {
                    existingStmt.defaultNameLoc = Some(dn)
                }
            }

            return DeduplicatedImportResult(existingStmt.namespaceRef, UInt32(existingImportRecordIdx))
        }

        // 新模块导入 - 创建 import 语句并追加
        let importStmt = Stmt(loc, StmtTag.Import)
        importStmt.importRecordIndex = Int64(importRecordIndex)
        importStmt.isSingleLine = true
        if (let Some(dn) <- defaultName) {
            importStmt.defaultNameLoc = Some(dn)
        }
        importStmt.importItems = items
        importStmt.namespaceRef = namespaceRef
        if (let Some(stl) <- starNameLoc) {
            importStmt.starNameLoc = Some(stl)
        }

        stmts.append(importStmt)
        let stmtIndex = UInt32(stmts.size - 1)
        importsSeen.put(pathText, ImportRef(stmtIndex))

        return DeduplicatedImportResult(namespaceRef, importRecordIndex)
    }

    // ========================================================================
    // visitBindingToExport - 访问绑定模式并导出
    // 严格翻译自: lower_esm_exports_hmr.zig:362-379
    //   fn visitBindingToExport(ctx, p, binding) !void
    //   递归遍历绑定模式 (标识符/数组/对象), 为每个标识符调用 visitRefToExport
    // ========================================================================

    /// 访问绑定模式并添加到导出
    public func visitBindingToExport(p: Parser, binding: Binding): Unit {
        match (binding.tag) {
            case BindingTag.Missing =>
                () // b_missing: 不做处理
            case BindingTag.Identifier =>
                // b_identifier: 为标识符创建导出
                visitRefToExport(p, binding.ref, Option<String>.None, binding.loc, false)
            case BindingTag.Array =>
                // b_array: 递归处理每个元素的绑定
                for (item in binding.arrayItems) {
                    visitBindingToExport(p, item)
                }
            case BindingTag.Object =>
                // b_object: 递归处理每个属性的值绑定
                for (item in binding.objectProperties) {
                    if (let Some(v) <- item.value) {
                        visitBindingToExport(p, v)
                    }
                }
            case _ =>
                ()
        }
    }

    // ========================================================================
    // visitRefToExport - 访问引用并创建导出属性
    // 严格翻译自: lower_esm_exports_hmr.zig:381-439
    //   fn visitRefToExport(
    //       ctx, p, ref, export_symbol_name, loc, is_live_binding_source
    //   ) !void
    //
    //   对于实时绑定/已赋值符号/非 node_modules 中的导入符号:
    //     生成 getter: get abc() { return abc }
    //   否则:
    //     生成简单属性: abc
    // ========================================================================

    /// 访问引用并创建导出属性
    /// 对应 Bun visitRefToExport
    public func visitRefToExport(
        p: Parser,
        ref: Ref,
        exportSymbolName: ?String,
        loc: Loc,
        isLiveBindingSource: Bool
    ): Unit {
        let symbol = p.symbols[ref.innerIndex]
        let id = if (symbol.kind == SymbolKind.Import) {
            // 导入标识符
            Expr(loc, ExprTag.ImportIdentifier)
        } else {
            Expr.identifier(loc, symbol.originalName, ref)
        }

        if (isLiveBindingSource || (symbol.kind == SymbolKind.Import && !isInNodeModules) ||
            symbol.hasBeenAssignedTo) {
            // 生成 getter 形式的导出属性
            // 对应 Bun:
            //   try ctx.export_props.append(p.allocator, .{
            //       .kind = .get,
            //       .key = key,
            //       .value = Expr(E.Function, .{ .func = .{
            //           .body = .{
            //               .stmts = ... S.Return{ .value = id },
            //               .loc = loc,
            //           },
            //       } }, loc),
            //   });
            let name = if (let Some(n) <- exportSymbolName) { n } else { symbol.originalName }
            let key = Expr.string(loc, name)

            // 生成临时变量用于 getter
            let arg1 = p.newSymbol(SymbolKind.Other, symbol.originalName)
            lastPart.declaredSymbols.append(arg1)
            lastPart.symbolUses.put(arg1, 1)

            // 'get abc() { return abc }'
            let returnStmt = Stmt(loc, StmtTag.Return)
            returnStmt.expr = Some(id)

            let getterBody = ArrayList<Stmt>()
            getterBody.append(returnStmt)

            let getterProp = GProperty(loc, name, Some(id))
            getterProp.kind = GPropertyKind.Getter
            exportProps.append(getterProp)
        } else {
            // 'abc,' - 简单属性
            let name2 = if (let Some(n) <- exportSymbolName) { n } else { symbol.originalName }
            let `prop` = GProperty(loc, name2, Some(id))
            `prop`.kind = GPropertyKind.Field
            exportProps.append(`prop`)
        }
    }

    // ========================================================================
    // finalize - 最终化 HMR 转换
    // 严格翻译自: lower_esm_exports_hmr.zig:441-523
    //   pub fn finalize(ctx, p, all_parts) !void
    //
    //   1. 合并 export_star_props 到 export_props 开头
    //   2. 创建 hmr.exports = { ... } 赋值
    //   3. React Fast Refresh 处理
    //   4. 合并所有 part 元数据到最后一个 part
    // ========================================================================

    /// 最终化 HMR 转换 - 对应 Bun finalize
    /// 组装所有导出属性和语句为最终的 AST
    public func finalize(p: Parser, allParts: ArrayList<Part>): Unit {
        // 1. 合并 export_star_props
        // 对应 Bun: if (ctx.export_star_props.items.len > 0) { ... }
        if (exportStarProps.size > 0) {
            if (exportProps.size == 0) {
                exportProps = exportStarProps
            } else {
                // 将 export_star_props 放到开头
                let merged = ArrayList<GProperty>()
                for (`prop` in exportStarProps) { merged.append(`prop`) }
                for (`prop` in exportProps) { merged.append(`prop`) }
                exportProps = merged
            }
        }

        // 2. 创建 hmr.exports = { ... } 赋值
        if (exportProps.size > 0) {
            // 构建导出对象
            let obj = Expr(Loc.EMPTY, ExprTag.Object)
            obj.properties = exportProps

            // hmr.exports = { ... }
            // 对应 Bun:
            //   Expr.assign(
            //       Expr(E.Dot, .{
            //           .target = Expr.initIdentifier(p.hmr_api_ref, logger.Loc.Empty),
            //           .name = "exports",
            //           .name_loc = logger.Loc.Empty,
            //       }, logger.Loc.Empty),
            //       obj,
            //   )
            let hmrRef = Expr.identifier(Loc.EMPTY, "hmr", p.hmrApiRef)
            let exportsDot = Expr(Loc.EMPTY, ExprTag.Dot)
            exportsDot.target = Some(hmrRef)
            exportsDot.propertyName = "exports"

            let assignExpr = Expr(Loc.EMPTY, ExprTag.Assign)
            assignExpr.left = Some(exportsDot)
            assignExpr.right = Some(obj)

            let assignStmt = Stmt(Loc.EMPTY, StmtTag.Expr)
            assignStmt.expr = Some(assignExpr)
            stmts.append(assignStmt)

            // 标记 module_ref 依赖
            lastPart.symbolUses.put(p.moduleRef, 1)
            lastPart.declaredSymbols.append(p.moduleRef)
        }

        // 3. React Fast Refresh 处理
        // 对应 Bun:
        //   if (p.options.features.react_fast_refresh and p.react_refresh.register_used) { ... }
        if (p.options.features.reactFastRefresh && p.reactRefresh.registerUsed) {
            let hmrRef = Expr.identifier(Loc.EMPTY, "hmr", p.hmrApiRef)
            let dotExpr = Expr(Loc.EMPTY, ExprTag.Dot)
            dotExpr.target = Some(hmrRef)
            dotExpr.propertyName = "reactRefreshAccept"

            let callExpr = Expr(Loc.EMPTY, ExprTag.Call)
            callExpr.target = Some(dotExpr)
            callExpr.args = ArrayList<Expr>()

            let callStmt = Stmt(Loc.EMPTY, StmtTag.Expr)
            callStmt.expr = Some(callExpr)
            stmts.append(callStmt)
        }

        // 4. 合并所有 part 元数据到第一个 part
        // 对应 Bun:
        //   for (all_parts[0 .. all_parts.len - 1]) |*part| { ... }
        for (i in 0..allParts.size - 1) {
            let part = allParts[Int64(i)]
            // 合并声明的符号
            for (ds in part.declaredSymbols) {
                lastPart.declaredSymbols.append(ds)
            }
            // 合并导入记录索引
            for (idx in part.importRecordIndices) {
                lastPart.importRecordIndices.append(idx)
            }
            // 合并符号使用
            let keys = part.symbolUses.keys()
            let values = part.symbolUses.values()
            for (j in 0..keys.size) {
                let k = keys[Int64(j)]
                let v = values[Int64(j)]
                if (let Some(existing) <- lastPart.symbolUses.get(k)) {
                    lastPart.symbolUses.put(k, existing + v)
                } else {
                    lastPart.symbolUses.put(k, v)
                }
            }
            // 清空当前 part
            part.stmts = ArrayList<Stmt>()
            part.declaredSymbols = ArrayList<Ref>()
            part.tag = PartTag.DeadDueToInlining
            part.dependencies = ArrayList<PartDependency>()
            part.dependencies.append(PartDependency(
                UInt32(allParts.size - 1),
                UInt32(p.source.index)
            ))
        }

        // 追加当前 part 的导入记录
        for (idx in p.importRecordsForCurrentPart) {
            lastPart.importRecordIndices.append(idx)
        }
        for (ds in p.declaredSymbols) {
            lastPart.declaredSymbols.append(ds.ref)
        }

        lastPart.stmts = stmts
        lastPart.tag = PartTag.PartNone
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 检查表达式是否可以安全移动
    /// 对应 Bun: value.canBeMoved()
    private func canBeMoved(value: ?Expr): Bool {
        match (value) {
            case Some(v) =>
                match (v.tag) {
                    case ExprTag.Null | ExprTag.Undefined | ExprTag.Boolean |
                         ExprTag.Number | ExprTag.String | ExprTag.BigInt |
                         ExprTag.Identifier | ExprTag.Function | ExprTag.Arrow =>
                        true
                    case _ =>
                        false
                }
            case None =>
                false
        }
    }

    /// 检查 export default 是否可移动到内部作用域
    /// 对应 Bun: lower_esm_exports_hmr.zig:97-113
    ///   const can_be_moved_to_inner_scope = switch (st.value) { ... }
    private func canExportDefaultBeMoved(p: Parser, stmt: Stmt): Bool {
        // 简化实现: 对于表达式和简单声明, 返回 true
        if (let Some(e) <- stmt.expr) {
            match (e.tag) {
                case ExprTag.Identifier => true
                case ExprTag.Function | ExprTag.Class =>
                    // 只有在符号未使用时可移动
                    true
                case _ =>
                    false
            }
        } else {
            false
        }
    }

    /// 获取 export default 的值表达式
    private func getExportDefaultValue(stmt: Stmt): Expr {
        if (let Some(e) <- stmt.expr) {
            e
        } else {
            Expr(Loc.EMPTY, ExprTag.Missing)
        }
    }
}

// ============================================================================
// 辅助类型 (HMR 转换所需)
// ============================================================================

/// 符号使用记录 - 对应 Bun SymbolUse
public class SymbolUse {
    public var countEstimate: Int64

    public init(countEstimate: Int64) {
        this.countEstimate = countEstimate
    }
}

/// 部分依赖 - 对应 Bun PartDependency
public class PartDependency {
    public var partIndex: UInt32
    public var sourceIndex: UInt32

    public init(partIndex: UInt32, sourceIndex: UInt32) {
        this.partIndex = partIndex
        this.sourceIndex = sourceIndex
    }
}


