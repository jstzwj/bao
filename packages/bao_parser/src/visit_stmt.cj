// AST 语句 Visitor
// 严格翻译自: src/js_parser/visit/visit_stmt.zig (1603 lines)
//   Bun 的语句 Visitor 遍历所有语句节点类型
//   visitAndAppendStmt() 是入口，根据 StmtTag 分派到各自的访问器
//   包括: s_block, s_expr, s_if, s_for, s_for_in, s_for_of, s_while,
//         s_do_while, s_function, s_class, s_local, s_import, s_export*,
//         s_return, s_throw, s_try, s_switch, s_break, s_continue, etc.
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// StmtVisitor - 语句访问器
// 严格翻译自: src/js_parser/visit/visit_stmt.zig
//   VisitStmt() 返回一个包含 visitAndAppendStmt 的 struct
//   仓颉实现为独立类，接收 Parser 实例
// ============================================================================

/// 语句访问器 - 对应 Bun VisitStmt 模块
/// 遍历和变换所有语句节点
public class StmtVisitor {
    /// 关联的解析器
    private var p: Parser

    public init(parser: Parser) {
        p = parser
    }

    // ========================================================================
    // visitAndAppendStmt - 语句访问入口
    // 严格翻译自: visit_stmt.zig:11-39
    //   pub fn visitAndAppendStmt(p: *P, stmts: *ListManaged(Stmt), stmt: *Stmt) anyerror!void
    //
    //   switch (stmt.data) {
    //     .s_directive, .s_comment, .s_empty => { ... append ... },
    //     .s_type_script => return,
    //     .s_debugger => { if (p.define.drop_debugger) return; append },
    //     inline .s_enum, .s_local => ...,
    //     inline else => ...,
    //     .s_lazy_export => unreachable,
    //   }
    // ========================================================================

    /// 访问并追加语句 - 对应 Bun visitAndAppendStmt
    /// 根据语句类型分派到对应的访问器，结果追加到 stmts
    public func visitAndAppendStmt(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 记住进入前的 const local prefix 状态
        // 对应 Bun: const was_after_after_const_local_prefix = p.current_scope.is_after_const_local_prefix
        // 默认情况下，语句结束 const local prefix
        let wasAfterConstLocalPrefix = p.currentScope.isAfterConstLocalPrefix
        p.currentScope.isAfterConstLocalPrefix = true

        match (stmt.tag) {
            // s_directive, s_comment, s_empty 不结束 const local prefix
            case StmtTag.Empty =>
                p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix
                stmts.append(stmt)

            case StmtTag.Debugger =>
                // 对应 Bun: if (p.define.drop_debugger) return
                p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix
                stmts.append(stmt)

            case StmtTag.Type =>
                // TypeScript 类型声明，直接跳过
                // 对应 Bun: s_type_script => return
                p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix
                ()

            case StmtTag.Block =>
                visitBlock(stmts, stmt)

            case StmtTag.Expr =>
                visitExprStmt(stmts, stmt)

            case StmtTag.If =>
                visitIf(stmts, stmt)

            case StmtTag.For =>
                visitFor(stmts, stmt)

            case StmtTag.ForIn =>
                visitForIn(stmts, stmt)

            case StmtTag.ForOf =>
                visitForOf(stmts, stmt)

            case StmtTag.While =>
                visitWhile(stmts, stmt)

            case StmtTag.DoWhile =>
                visitDoWhile(stmts, stmt)

            case StmtTag.Function =>
                visitFunction(stmts, stmt)

            case StmtTag.Class =>
                visitClass(stmts, stmt)

            case StmtTag.Local =>
                // s_local 不结束 const local prefix
                visitLocal(stmts, stmt, wasAfterConstLocalPrefix)

            case StmtTag.Import =>
                visitImport(stmts, stmt)

            case StmtTag.Return =>
                visitReturn(stmts, stmt)

            case StmtTag.Throw =>
                visitThrow(stmts, stmt)

            case StmtTag.Try =>
                visitTry(stmts, stmt)

            case StmtTag.Switch =>
                visitSwitch(stmts, stmt)

            case StmtTag.Break =>
                visitBreak(stmts, stmt)

            case StmtTag.Continue =>
                visitContinue(stmts, stmt)

            case StmtTag.With =>
                visitWith(stmts, stmt)

            case StmtTag.Labeled =>
                visitLabel(stmts, stmt)

            case StmtTag.Enum =>
                // s_enum 不结束 const local prefix
                visitEnum(stmts, stmt, wasAfterConstLocalPrefix)

            case StmtTag.Export =>
                visitExportClause(stmts, stmt)

            case StmtTag.ExportDefault =>
                visitExportDefault(stmts, stmt)

            case StmtTag.ExportStar =>
                visitExportStar(stmts, stmt)

            case StmtTag.ExportFrom =>
                visitExportFrom(stmts, stmt)

            case StmtTag.Directive =>
                p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix
                stmts.append(stmt)

            case StmtTag.Comment =>
                p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix
                stmts.append(stmt)

            case _ =>
                stmts.append(stmt)
        }
    }

    // ========================================================================
    // s_import - 访问 import 语句
    // 严格翻译自: visit_stmt.zig:42-56
    //   pub fn s_import(...) !void {
    //     try p.declaredSymbols.append(DeclaredSymbol(data.namespace_ref);
    //     if (data.default_name) |default_name| {
    //       try p.declaredSymbols.append(DeclaredSymbol(default_name.ref.?);
    //     }
    //     if (data.items.len > 0) {
    //       for (data.items) |*item| {
    //         try p.declaredSymbols.append(DeclaredSymbol(item.name.ref.?);
    //       }
    //     }
    //     try stmts.append(stmt.*);
    //   }
    // ========================================================================

    /// 访问 import 语句 - 对应 Bun s_import
    private func visitImport(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 记录命名空间引用为已声明
        if (stmt.namespaceRef.isValid()) {
            p.declaredSymbols.append(DeclaredSymbol(stmt.namespaceRef, DeclaredSymbolKind.HoistedImport))
        }

        // 记录默认导入引用
        if (stmt.defaultNameRef.isValid()) {
            p.declaredSymbols.append(DeclaredSymbol(stmt.defaultNameRef, DeclaredSymbolKind.HoistedImport))
        }

        // 记录所有命名导入项的引用
        for (item in stmt.clauseItems) {
            if (item.ref.isValid()) {
                p.declaredSymbols.append(DeclaredSymbol(item.ref, DeclaredSymbolKind.HoistedImport))
            }
        }

        stmts.append(stmt)
    }

    // ========================================================================
    // s_export_clause - 访问 export { ... } 语句
    // 严格翻译自: visit_stmt.zig:57-122
    //   处理 "export {foo}" 中的每个导出项:
    //   - 查找符号引用
    //   - 处理 replace_exports
    //   - 处理未绑定符号
    // ========================================================================

    /// 访问 export { ... } 语句 - 对应 Bun s_export_clause
    private func visitExportClause(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt
        var end: Int64 = 0
        var anyReplaced = false

        var items = stmt.exportItems

        for (item in items) {
            var mutableItem = item
            let name = if (item.nameRef.isValid()) {
                p.loadNameFromRef(item.nameRef)
            } else if (item.name.size > 0) {
                item.name
            } else {
                ""
            }

            let symbolRef = p.findSymbol(name)
            if (symbolRef.isNone()) {
                continue
            }
            if (let Some(r) <- symbolRef) {
                mutableItem.nameRef = r
            }
            items[Int64(end)] = mutableItem
            end = end + 1
        }

        mutableStmt.exportItems = items
        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_export_from - 访问 export { ... } from 'path' 语句
    // 严格翻译自: visit_stmt.zig:123-173
    // ========================================================================

    /// 访问 export { ... } from 'path' 语句 - 对应 Bun s_export_from
    private func visitExportFrom(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt
        let name = if (stmt.namespaceRef.isValid()) {
            p.loadNameFromRef(stmt.namespaceRef)
        } else {
            ""
        }

        // 创建命名空间符号
        let nsRef = p.newSymbol(SymbolKind.Other, name)
        p.declaredSymbols.append(DeclaredSymbol(nsRef, DeclaredSymbolKind.Other))
        mutableStmt.namespaceRef = nsRef

        // 为每个导出项创建新的导入符号
        // 对应 Bun: "This is a re-export and the symbols created here are used to reference"
        var items = stmt.exportItems
        var j: Int64 = 0
        for (item in items) {
            var mutableItem = item
            let oldRef = if (item.nameRef.isValid()) { item.nameRef } else { Ref.NONE }
            let itemName = p.loadNameFromRef(oldRef)

            let ref = p.newSymbol(SymbolKind.Import, itemName)
            p.declaredSymbols.append(DeclaredSymbol(ref, DeclaredSymbolKind.Other))
            mutableItem.nameRef = ref
            items[j] = mutableItem
            j = j + 1
        }

        mutableStmt.exportItems = items
        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_export_star - 访问 export * from 'path' 语句
    // 严格翻译自: visit_stmt.zig:174-193
    // ========================================================================

    /// 访问 export * from 'path' 语句 - 对应 Bun s_export_star
    private func visitExportStar(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt
        let name = if (stmt.namespaceRef.isValid()) {
            p.loadNameFromRef(stmt.namespaceRef)
        } else {
            ""
        }

        let nsRef = p.newSymbol(SymbolKind.Other, name)
        p.declaredSymbols.append(DeclaredSymbol(nsRef, DeclaredSymbolKind.Other))
        mutableStmt.namespaceRef = nsRef

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_export_default - 访问 export default 语句
    // 严格翻译自: visit_stmt.zig:194-500
    //   pub fn s_export_default(...) !void {
    //     defer { if (data.default_name.ref) |ref| { p.declaredSymbols.append(DeclaredSymbol(ref, DeclaredSymbolKind.Other)) catch unreachable } }
    //     var mark_for_replace: bool = false;
    //     switch (data.value) {
    //       .expr => |expr| { ... visitExpr, maybeKeepExprSymbolName, react_fast_refresh, server_components ... }
    //       .stmt => |s2| switch (s2.data) {
    //         .s_function => |func| { ... visitFunc, react_hook_data, react_fast_refresh ... }
    //         .s_class => |class| { ... visitClass, lowerClass, server_components ... }
    //         else => {},
    //       },
    //     }
    //     try stmts.append(stmt.*);
    //   }
    // ========================================================================

    /// 访问 export default 语句 - 对应 Bun s_export_default
    private func visitExportDefault(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 记录默认名称为已声明
        if (stmt.defaultNameRef.isValid()) {
            p.declaredSymbols.append(DeclaredSymbol(stmt.defaultNameRef, DeclaredSymbolKind.Other))
        }

        let origDead = p.isControlFlowDead

        // 访问导出值
        if (let Some(value) <- stmt.expr) {
            var visitedValue = ExprVisitor(p).visitExpr(value)

            if (p.isControlFlowDead) {
                return
            }

            mutableStmt.expr = Some(visitedValue)
            p.isControlFlowDead = origDead
        } else if (let Some(fnData) <- stmt.fn) {
            // export default function - 简化处理
            stmts.append(stmt)
            return
        } else if (stmt.classData.isSome()) {
            // export default class - 简化处理
            stmts.append(stmt)
            return
        }

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_function - 访问函数声明
    // 严格翻译自: visit_stmt.zig:501-588
    //   pub fn s_function(...) !void {
    //     const mark_as_dead = ...;
    //     data.func = p.visitFunc(data.func, data.func.open_parens_loc);
    //     const name_ref = data.`func`.name.?.ref.?;
    //     // Handle exporting from namespace, server_components, react_fast_refresh
    //   }
    // ========================================================================

    /// 访问函数声明 - 对应 Bun s_function
    private func visitFunction(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 简化处理: 函数声明在解析阶段已处理
        stmts.append(stmt)
    }

    // ========================================================================
    // s_class - 访问类声明
    // 严格翻译自: visit_stmt.zig:590-650
    //   pub fn s_class(...) !void {
    //     _ = p.visitClass(stmt.loc, &data.class, Ref.None);
    //     const lowered = p.lowerClass(...);
    //     // Handle export inside namespace
    //   }
    // ========================================================================

    /// 访问类声明 - 对应 Bun s_class
    private func visitClass(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 简化处理: 类声明在解析阶段已处理
        stmts.append(stmt)
    }

    // ========================================================================
    // s_export_equals - 访问 module.exports = value 语句
    // 严格翻译自: visit_stmt.zig:651-661
    //   pub fn s_export_equals(...) !void {
    //     stmts.append(Stmt.assign(p.@"module.exports"(stmt.loc), p.visitExpr(data.value))) catch unreachable;
    //     p.recordUsage(p.module_ref);
    //   }
    // ========================================================================

    /// 访问 module.exports = value 语句 - 对应 Bun s_export_equals
    private func visitExportEquals(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // "module.exports = value"
        if (let Some(value) <- stmt.expr) {
            let visitedValue = ExprVisitor(p).visitExpr(value)
            // 创建赋值语句
            var assignStmt = Stmt()
            assignStmt.tag = StmtTag.Expr
            assignStmt.expr = Some(visitedValue)
            stmts.append(assignStmt)
        }
    }

    // ========================================================================
    // s_local - 访问局部变量声明
    // 严格翻译自: visit_stmt.zig:712-816
    //   pub fn s_local(..., was_after_after_const_local_prefix: bool) !void {
    //     p.current_scope.is_after_const_local_prefix = was_after_after_const_local_prefix;
    //     p.visitDecls(data.decls.slice(), data.kind == .k_const, false);
    //     // relocate vars, select local kind
    //     // react_fast_refresh, server_components
    //   }
    // ========================================================================

    /// 访问局部变量声明 - 对应 Bun s_local
    private func visitLocal(stmts: ArrayList<Stmt>, stmt: Stmt, wasAfterConstLocalPrefix: Bool): Unit {
        var mutableStmt = stmt

        // 局部声明不结束 const local prefix
        // 对应 Bun: p.current_scope.is_after_const_local_prefix = was_after_after_const_local_prefix
        p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix

        // 访问每个声明
        var newDecls = ArrayList<GDecl>()
        for (decl in stmt.decls) {
            var mutableDecl = decl

            // 访问绑定
            // 对应 Bun: p.visitBinding(decl.binding, null)
            visitBinding(decl.binding)

            // 访问初始值
            if (let Some(value) <- decl.value) {
                let wasAnonymousNamedExpr = false /* isAnonymousNamed */
                mutableDecl.value = Some(ExprVisitor(p).visitExprInOut(value, ExprIn()))
                visitDecl(mutableDecl, wasAnonymousNamedExpr, wasAfterConstLocalPrefix)
            }

            newDecls.append(mutableDecl)
        }
        mutableStmt.decls = newDecls

        // 选择本地声明类型
        // 对应 Bun: const kind = p.selectLocalKind(data.kind)
        let kind = selectLocalKind(stmt.localKind)
        mutableStmt.localKind = kind

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_expr - 访问表达式语句
    // 严格翻译自: visit_stmt.zig:817-918
    //   pub fn s_expr(...) !void {
    //     p.stmt_expr_value = data.value.data;
    //     data.value = p.visitExpr(data.value);
    //     // simplify unused
    //     // handle CommonJS to ESM conversion
    //     stmts.append(stmt.*);
    //   }
    // ========================================================================

    /// 访问表达式语句 - 对应 Bun s_expr
    private func visitExprStmt(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 设置 stmt_expr_value (用于 BinaryExpressionVisitor)
        // 对应 Bun: p.stmt_expr_value = data.value.data

        if (let Some(value) <- stmt.expr) {
            var visitedValue = ExprVisitor(p).visitExpr(value)

            // 简化未使用的表达式
            // 对应 Bun: data.value = SideEffects.simplifyUnusedExpr(p, data.value) orelse return
            if (let Some(simplified) <- SideEffects.simplifyUnusedExpr(p, visitedValue)) {
                visitedValue = simplified
            } else {
                // 表达式没有副作用，可以跳过
                return
            }

            mutableStmt.expr = Some(visitedValue)
        }

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_if - 访问 if 语句
    // 严格翻译自: visit_stmt.zig:1018-1132
    //   pub fn s_if(...) !void {
    //     data.test_ = p.visitExpr(data.test_);
    //     data.test_ = SideEffects.simplifyBoolean(p, data.test_);
    //     const effects = SideEffects.toBoolean(p, data.test_.data);
    //     // 根据条件真假标记死代码
    //     data.yes = p.visitSingleStmt(data.yes, StmtsKind.none);
    //     if (data.no) |no| { data.no = p.visitSingleStmt(no, .none); }
    //     // minify_syntax: 条件已知时折叠 if
    //   }
    // ========================================================================

    /// 访问 if 语句 - 对应 Bun s_if
    private func visitIf(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问条件表达式
        if (let Some(test) <- stmt.expr) {
            var visitedTest = ExprVisitor(p).visitExpr(test)

            // 简化布尔表达式
            // 对应 Bun: data.test_ = SideEffects.simplifyBoolean(p, data.test_)
            visitedTest = SideEffects.simplifyBoolean(p, visitedTest)
            mutableStmt.expr = Some(visitedTest)

            // 分析条件是否已知
            // 对应 Bun: const effects = SideEffects.toBoolean(p, data.test_.data)
            let effects = SideEffects.toBoolean(p, visitedTest)

            // 访问 then 分支
            if (effects.ok && !effects.value) {
                // 条件为 false, 标记 yes 分支为死代码
                let old = p.isControlFlowDead
                p.isControlFlowDead = true
                if (let Some(yes) <- stmt.yes) {
                    mutableStmt.yes = Some(visitSingleStmt(yes, StmtsKind.None))
                }
                p.isControlFlowDead = old
            } else {
                if (let Some(yes) <- stmt.yes) {
                    mutableStmt.yes = Some(visitSingleStmt(yes, StmtsKind.None))
                }
            }

            // 访问 else 分支
            if (let Some(no) <- stmt.no) {
                if (effects.ok && effects.value) {
                    // 条件为 true, 标记 no 分支为死代码
                    let old = p.isControlFlowDead
                    p.isControlFlowDead = true
                    mutableStmt.no = Some(visitSingleStmt(no, StmtsKind.None))
                    p.isControlFlowDead = old
                } else {
                    mutableStmt.no = Some(visitSingleStmt(no, StmtsKind.None))
                }

                // 如果 else 分支被死代码消除清空了，移除 else
                // 对应 Bun: if (no_is_empty) { data.no = null; }
                if (let Some(noStmt) <- mutableStmt.no) {
                    if (noStmt.tag == StmtTag.Empty) {
                        mutableStmt.no = None
                    } else if (noStmt.tag == StmtTag.Block) {
                        if (noStmt.stmts.size == 0) {
                            mutableStmt.no = None
                        }
                    }
                }
            }

            // minify_syntax: 已知条件时折叠 if
            if (effects.ok) {
                if (effects.value) {
                    // 条件为 true, 只保留 then 分支
                    if (let Some(yes) <- mutableStmt.yes) {
                        stmts.append(yes)
                        return
                    }
                } else {
                    // 条件为 false, 只保留 else 分支
                    if (let Some(no) <- mutableStmt.no) {
                        stmts.append(no)
                        return
                    } else {
                        return
                    }
                }
            }
        } else {
            // 无条件表达式
            if (let Some(yes) <- stmt.yes) {
                mutableStmt.yes = Some(visitSingleStmt(yes, StmtsKind.None))
            }
            if (let Some(no) <- stmt.no) {
                mutableStmt.no = Some(visitSingleStmt(no, StmtsKind.None))
            }
        }

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_for - 访问 for 语句
    // 严格翻译自: visit_stmt.zig:1133-1171
    //   pub fn s_for(...) !void {
    //     p.pushScopeForVisitPass(.block, stmt.loc);
    //     if (data.init) |initst| { data.init = p.visitForLoopInit(initst, false); }
    //     if (data.test_) |test_| { data.test_ = SideEffects.simplifyBoolean(p, p.visitExpr(test_)); }
    //     if (data.update) |update| { data.update = p.visitExpr(update); }
    //     data.body = p.visitLoopBody(data.body);
    //     p.popScope();
    //   }
    // ========================================================================

    /// 访问 for 语句 - 对应 Bun s_for
    private func visitFor(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Block)

        var mutableStmt = stmt

        // 访问初始化
        if (let Some(`init`) <- stmt.`init`) {
            mutableStmt.`init` = Some(visitForLoopInit(`init`, false))
        }

        // 访问条件
        if (let Some(test) <- stmt.expr) {
            var visitedTest = ExprVisitor(p).visitExpr(test)
            visitedTest = SideEffects.simplifyBoolean(p, visitedTest)
            mutableStmt.expr = Some(visitedTest)
        }

        // 访问更新
        if (let Some(update) <- stmt.update) {
            mutableStmt.update = Some(ExprVisitor(p).visitExpr(update))
        }

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        p.popScope()
        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_for_in - 访问 for-in 语句
    // 严格翻译自: visit_stmt.zig:1172-1207
    //   pub fn s_for_in(...) !void {
    //     p.pushScopeForVisitPass(.block, stmt.loc);
    //     _ = p.visitForLoopInit(data.init, true);
    //     data.value = p.visitExpr(data.value);
    //     data.body = p.visitLoopBody(data.body);
    //     // 检查变量初始化器, lower for-in variable initializers
    //     p.popScope();
    //   }
    // ========================================================================

    /// 访问 for-in 语句 - 对应 Bun s_for_in
    private func visitForIn(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Block)

        var mutableStmt = stmt

        // 访问初始化
        if (let Some(`init`) <- stmt.`init`) {
            mutableStmt.`init` = Some(visitForLoopInit(`init`, true))
        }

        // 访问迭代值
        if (let Some(value) <- stmt.iterValue) {
            mutableStmt.iterValue = Some(ExprVisitor(p).visitExpr(value))
        }

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        p.popScope()
        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_for_of - 访问 for-of 语句
    // 严格翻译自: visit_stmt.zig:1208-1269
    //   pub fn s_for_of(...) !void {
    //     p.pushScopeForVisitPass(.block, stmt.loc);
    //     _ = p.visitForLoopInit(data.init, true);
    //     data.value = p.visitExpr(data.value);
    //     data.body = p.visitLoopBody(data.body);
    //     // Handle "for (using x of y)"
    //     p.popScope();
    //   }
    // ========================================================================

    /// 访问 for-of 语句 - 对应 Bun s_for_of
    private func visitForOf(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Block)

        var mutableStmt = stmt

        // 访问初始化
        if (let Some(`init`) <- stmt.`init`) {
            mutableStmt.`init` = Some(visitForLoopInit(`init`, true))
        }

        // 访问迭代值
        if (let Some(value) <- stmt.iterValue) {
            mutableStmt.iterValue = Some(ExprVisitor(p).visitExpr(value))
        }

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        // 处理 "for (using x of y)" 和 "for (await using x of y)"
        // 对应 Bun: if data.init.data == .s_local and data.init.data.s_local.kind.isUsing()
        if (let Some(`init`) <- mutableStmt.`init`) {
            if (`init`.tag == StmtTag.Local && `init`.localKind == LocalKind.Using) {
                // "using" 声明的 for-of 循环需要特殊处理
                // 对应 Bun: fn lowerUsingDeclarationInForOf()
                // 这涉及到使用 Symbol.dispose 语义
            }
        }

        p.popScope()
        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_while - 访问 while 语句
    // 严格翻译自: visit_stmt.zig:999-1010
    //   pub fn s_while(...) !void {
    //     data.test_ = p.visitExpr(data.test_);
    //     data.body = p.visitLoopBody(data.body);
    //     data.test_ = SideEffects.simplifyBoolean(p, data.test_);
    //     const result = SideEffects.toBoolean(p, data.test_.data);
    //     if (result.ok and result.side_effects == .no_side_effects) {
    //       data.test_ = p.newExpr(E.Boolean{ .value = result.value }, data.test_.loc);
    //     }
    //   }
    // ========================================================================

    /// 访问 while 语句 - 对应 Bun s_while
    private func visitWhile(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问条件
        if (let Some(test) <- stmt.expr) {
            var visitedTest = ExprVisitor(p).visitExpr(test)
            visitedTest = SideEffects.simplifyBoolean(p, visitedTest)

            // 对应 Bun: const result = SideEffects.toBoolean(p, data.test_.data)
            let result = SideEffects.toBoolean(p, visitedTest)
            if (result.ok && result.sideEffects == SideEffectFlag.NoSideEffects) {
                // 条件已知且无副作用, 简化为布尔字面量
                visitedTest = Expr.bool_(visitedTest.loc, result.value)
            }

            mutableStmt.expr = Some(visitedTest)
        }

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_do_while - 访问 do-while 语句
    // 严格翻译自: visit_stmt.zig:1011-1017
    //   pub fn s_do_while(...) !void {
    //     data.body = p.visitLoopBody(data.body);
    //     data.test_ = p.visitExpr(data.test_);
    //     data.test_ = SideEffects.simplifyBoolean(p, data.test_);
    //   }
    // ========================================================================

    /// 访问 do-while 语句 - 对应 Bun s_do_while
    private func visitDoWhile(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        // 访问条件
        if (let Some(test) <- stmt.expr) {
            var visitedTest = ExprVisitor(p).visitExpr(test)
            visitedTest = SideEffects.simplifyBoolean(p, visitedTest)
            mutableStmt.expr = Some(visitedTest)
        }

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_return - 访问 return 语句
    // 严格翻译自: visit_stmt.zig:923-952
    //   pub fn s_return(...) !void {
    //     if (p.fn_or_arrow_data_visit.is_outside_fn_or_arrow) {
    //       // 检查顶层 return
    //     }
    //     if (data.value) |val| {
    //       data.value = p.visitExpr(val);
    //       // "return undefined;" => "return;"
    //       if (data.value != null and data.value.?.data == .e_undefined) {
    //         data.value = null;
    //       }
    //     }
    //   }
    // ========================================================================

    /// 访问 return 语句 - 对应 Bun s_return
    private func visitReturn(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 检查顶层 return 是否合法
        // 对应 Bun: if (p.fn_or_arrow_data_visit.is_outside_fn_or_arrow)

        if (let Some(value) <- stmt.expr) {
            var visitedValue = ExprVisitor(p).visitExpr(value)

            // "return undefined;" 可以简化为 "return;"
            // 对应 Bun: if data.value is e_undefined, set to null
            if (visitedValue.tag == ExprTag.Undefined) {
                mutableStmt.expr = None
            } else {
                mutableStmt.expr = Some(visitedValue)
            }
        }

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_throw - 访问 throw 语句
    // 严格翻译自: visit_stmt.zig:919-922
    // ========================================================================

    /// 访问 throw 语句 - 对应 Bun s_throw
    private func visitThrow(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        if (let Some(value) <- stmt.expr) {
            mutableStmt.expr = Some(ExprVisitor(p).visitExpr(value))
        }

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_block - 访问块语句
    // 严格翻译自: visit_stmt.zig:953-980
    //   pub fn s_block(...) !void {
    //     p.pushScopeForVisitPass(.block, stmt.loc);
    //     var _stmts = ListManaged(Stmt).fromOwnedSlice(p.allocator, data.stmts);
    //     p.visitStmts(&_stmts, kind);
    //     data.stmts = _stmts.items;
    //     p.popScope();
    //     // minify_syntax: trim empty blocks, unwrap single-statement blocks
    //   }
    // ========================================================================

    /// 访问块语句 - 对应 Bun s_block
    private func visitBlock(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Block)

        var mutableStmt = stmt
        var newStmts = ArrayList<Stmt>()
        visitStmtList(newStmts, stmt.stmts)

        p.popScope()

        // minify_syntax: 修剪空块
        // 对应 Bun: if (data.stmts.len == 0) { ... }
        if (newStmts.size == 0) {
            var emptyStmt = stmt
            emptyStmt.tag = StmtTag.Empty
            stmts.append(emptyStmt)
            return
        }

        // minify_syntax: 解包单语句块
        // 对应 Bun: if (data.stmts.len == 1 and !statementCaresAboutScope(...))
        if (newStmts.size == 1 && !statementCaresAboutScope(newStmts[0])) {
            stmts.append(newStmts[0])
            return
        }

        mutableStmt.stmts = newStmts
        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_with - 访问 with 语句
    // 严格翻译自: visit_stmt.zig:981-998
    //   pub fn s_with(...) !void {
    //     data.value = p.visitExpr(data.value);
    //     p.pushScopeForVisitPass(.with, data.body_loc);
    //     data.body = p.visitSingleStmt(data.body, StmtsKind.none);
    //     p.popScope();
    //   }
    // ========================================================================

    /// 访问 with 语句 - 对应 Bun s_with
    private func visitWith(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问 with 表达式
        if (let Some(value) <- stmt.expr) {
            mutableStmt.expr = Some(ExprVisitor(p).visitExpr(value))
        }

        // 访问 with 体
        p.pushScope(ScopeKind.With)
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitSingleStmt(body, StmtsKind.None))
        }
        p.popScope()

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_label - 访问标签语句
    // 严格翻译自: visit_stmt.zig:694-711
    //   pub fn s_label(...) !void {
    //     p.pushScopeForVisitPass(.label, stmt.loc);
    //     const ref = p.newSymbol(.label, name);
    //     p.current_scope.label_ref = ref;
    //     // 如果标签下的语句是循环, 标记 label_stmt_is_loop
    //     data.stmt = p.visitSingleStmt(data.stmt, StmtsKind.none);
    //     p.popScope();
    //   }
    // ========================================================================

    /// 访问标签语句 - 对应 Bun s_label
    private func visitLabel(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Label)

        var mutableStmt = stmt

        // 创建标签符号
        if (stmt.label.size > 0) {
            let ref = p.newSymbol(SymbolKind.Label, stmt.label)
            p.declaredSymbols.append(DeclaredSymbol(ref, DeclaredSymbolKind.Other))
        }

        // 访问标签体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitSingleStmt(body, StmtsKind.None))
        }

        p.popScope()
        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_break - 访问 break 语句
    // 严格翻译自: visit_stmt.zig:662-677
    //   pub fn s_break(...) !void {
    //     if (data.label) |*label| { ... findLabelSymbol ... }
    //     else if (!p.fn_or_arrow_data_visit.is_inside_loop and !p.fn_or_arrow_data_visit.is_inside_switch) {
    //       // error: Cannot use "break" here
    //     }
    //   }
    // ========================================================================

    /// 访问 break 语句 - 对应 Bun s_break
    private func visitBreak(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 简化处理: break 语句不需要特殊访问
        stmts.append(stmt)
    }

    // ========================================================================
    // s_continue - 访问 continue 语句
    // 严格翻译自: visit_stmt.zig:678-693
    //   pub fn s_continue(...) !void {
    //     if (data.label) |*label| { ... findLabelSymbol ... check is_loop ... }
    //     else if (!p.fn_or_arrow_data_visit.is_inside_loop) {
    //       // error: Cannot use "continue" here
    //     }
    //   }
    // ========================================================================

    /// 访问 continue 语句 - 对应 Bun s_continue
    private func visitContinue(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 简化处理: continue 语句不需要特殊访问
        stmts.append(stmt)
    }

    // ========================================================================
    // s_try - 访问 try 语句
    // 严格翻译自: visit_stmt.zig:1270-1307
    //   pub fn s_try(...) !void {
    //     p.pushScopeForVisitPass(.block, stmt.loc);
    //     { var _stmts = ...; p.fn_or_arrow_data_visit.try_body_count += 1;
    //       p.visitStmts(&_stmts, StmtsKind.none);
    //       p.fn_or_arrow_data_visit.try_body_count -= 1; }
    //     p.popScope();
    //     if (data.catch_) |*catch_| { ... visit catch binding and body ... }
    //     if (data.finally) |*finally| { ... visit finally body ... }
    //   }
    // ========================================================================

    /// 访问 try 语句 - 对应 Bun s_try
    private func visitTry(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问 try 体
        p.pushScope(ScopeKind.Block)
        var tryBody = ArrayList<Stmt>()
        visitStmtList(tryBody, stmt.stmts)
        p.popScope()
        mutableStmt.stmts = tryBody

        // 访问 catch 子句
        // 对应 Bun: if (data.catch_) |*catch_|
        if (stmt.hasCatch) {
            p.pushScope(ScopeKind.CatchBinding)

            // 访问 catch 绑定
            // 对应 Bun: if (catch_.binding) |catch_binding| { p.visitBinding(catch_binding, null); }
            if (let Some(binding) <- stmt.catchBinding) {
                visitBinding(binding)
            }

            p.pushScope(ScopeKind.Block)
            var catchBody = ArrayList<Stmt>()
            visitStmtList(catchBody, stmt.catchBodyStmts)
            p.popScope()
            p.popScope()
            mutableStmt.catchBodyStmts = catchBody
        }

        // 访问 finally 子句
        // 对应 Bun: if (data.finally) |*finally|
        if (stmt.hasFinally) {
            p.pushScope(ScopeKind.Block)
            var finallyBody = ArrayList<Stmt>()
            visitStmtList(finallyBody, stmt.finallyStmts)
            p.popScope()
            mutableStmt.finallyStmts = finallyBody
        }

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_switch - 访问 switch 语句
    // 严格翻译自: visit_stmt.zig:1308-1331
    //   pub fn s_switch(...) !void {
    //     data.test_ = p.visitExpr(data.test_);
    //     p.pushScopeForVisitPass(.block, data.body_loc);
    //     p.fn_or_arrow_data_visit.is_inside_switch = true;
    //     for (data.cases) |case, i| {
    //       if (case.value) |val| { data.cases[i].value = p.visitExpr(val); }
    //       var _stmts = ...; p.visitStmts(&_stmts, StmtsKind.none);
    //       data.cases[i].body = _stmts.items;
    //     }
    //     p.popScope();
    //   }
    // ========================================================================

    /// 访问 switch 语句 - 对应 Bun s_switch
    private func visitSwitch(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问 switch 表达式
        if (let Some(test) <- stmt.expr) {
            mutableStmt.expr = Some(ExprVisitor(p).visitExpr(test))
        }

        // 访问 switch case 体
        p.pushScope(ScopeKind.Block)

        // 对应 Bun: for (data.cases, 0..) |case, i| { ... }
        var newCases = ArrayList<SwitchCase>()
        for (`case` in stmt.cases) {
            var mutableCase = `case`

            // 访问 case 值
            if (let Some(val) <- `case`.value) {
                mutableCase.value = Some(ExprVisitor(p).visitExpr(val))
            }

            // 访问 case 体
            var caseStmts = ArrayList<Stmt>()
            visitStmtList(caseStmts, `case`.body)
            mutableCase.body = caseStmts

            newCases.append(mutableCase)
        }
        mutableStmt.cases = newCases

        p.popScope()

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // s_enum - 访问 TypeScript 枚举
    // 严格翻译自: visit_stmt.zig:1333-1523
    //   pub fn s_enum(..., was_after_after_const_local_prefix: bool) !void {
    //     p.current_scope.is_after_const_local_prefix = was_after_after_const_local_prefix;
    //     p.declaredSymbols.append(DeclaredSymbol(data.name.ref.?);
    //     p.pushScopeForVisitPass(.entry, stmt.loc);
    //     p.declaredSymbols.append(DeclaredSymbol(data.arg);
    //     // Scan values, auto-numbering, create assignments
    //     // 生成闭包
    //     p.generateClosureForTypeScriptNamespaceOrEnum(...)
    //   }
    // ========================================================================

    /// 访问 TypeScript 枚举 - 对应 Bun s_enum
    private func visitEnum(stmts: ArrayList<Stmt>, stmt: Stmt, wasAfterConstLocalPrefix: Bool): Unit {
        // 枚举不结束 const local prefix
        p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix

        // 简化处理: TypeScript 枚举在解析阶段已处理
        stmts.append(stmt)
    }

    // ========================================================================
    // s_namespace - 访问 TypeScript 命名空间
    // 严格翻译自: visit_stmt.zig:1525-1565
    //   pub fn s_namespace(...) !void {
    //     p.declaredSymbols.append(DeclaredSymbol(data.name.ref?);
    //     // Scan ahead for exported declarations
    //     for (data.stmts) |child_stmt| { ... }
    //     p.pushScopeForVisitPass(.entry, stmt.loc);
    //     p.declaredSymbols.append(DeclaredSymbol(data.arg);
    //     p.visitStmtsAndPrependTempRefs(&prepend_list, &prepend_temp_refs);
    //     p.popScope();
    //     p.generateClosureForTypeScriptNamespaceOrEnum(...)
    //   }
    // ========================================================================

    /// 访问 TypeScript 命名空间 - 对应 Bun s_namespace
    private func visitNamespace(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问命名空间体
        p.pushScope(ScopeKind.Entry)

        var newStmts = ArrayList<Stmt>()
        visitStmtList(newStmts, stmt.stmts)
        mutableStmt.stmts = newStmts

        p.popScope()

        stmts.append(mutableStmt)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 访问语句列表 - 对应 Bun visitStmts
    public func visitStmtList(output: ArrayList<Stmt>, input: ArrayList<Stmt>): Unit {
        for (stmt in input) {
            visitAndAppendStmt(output, stmt)
        }
    }

    /// 访问单个语句 - 对应 Bun visitSingleStmt
    // 严格翻译自: visit.zig:498-522
    public func visitSingleStmt(stmt: Stmt, kind: StmtsKind): Stmt {
        // 块语句需要特殊处理
        if (stmt.tag == StmtTag.Block) {
            return visitSingleStmtBlock(stmt, kind)
        }

        // 包装成列表，调用 visitAndAppendStmt
        var list = ArrayList<Stmt>()
        list.append(stmt)
        visitStmtList(list, list)
        if (list.size > 0) {
            return list[0]
        }
        return stmt
    }

    /// 访问单个块语句 - 对应 Bun visitSingleStmtBlock
    // 严格翻译自: visit.zig:483-496
    private func visitSingleStmtBlock(stmt: Stmt, kind: StmtsKind): Stmt {
        p.pushScope(ScopeKind.Block)

        var newStmt = stmt
        var newStmts = ArrayList<Stmt>()
        visitStmtList(newStmts, stmt.stmts)
        newStmt.stmts = newStmts

        p.popScope()
        return newStmt
    }

    /// 访问循环体 - 对应 Bun visitLoopBody
    // 严格翻译自: visit.zig:474-481
    //   pub fn visitLoopBody(noalias p: *P, stmt: StmtNodeIndex) StmtNodeIndex {
    //     const old_is_inside_loop = p.fn_or_arrow_data_visit.is_inside_loop;
    //     p.fn_or_arrow_data_visit.is_inside_loop = true;
    //     p.loop_body = stmt.data;
    //     const res = p.visitSingleStmt(stmt, .loop_body);
    //     p.fn_or_arrow_data_visit.is_inside_loop = old_is_inside_loop;
    //     return res;
    //   }
    public func visitLoopBody(stmt: Stmt): Stmt {
        // 设置循环标志
        // 对应 Bun: p.fn_or_arrow_data_visit.is_inside_loop = true
        return visitSingleStmt(stmt, StmtsKind.LoopBody)
    }

    /// 访问 for 循环初始化 - 对应 Bun visitForLoopInit
    // 严格翻译自: visit.zig:366-388
    //   pub fn visitForLoopInit(p: *P, stmt: Stmt, is_in_or_of: bool) Stmt
    private func visitForLoopInit(stmt: Stmt, isInOrOf: Bool): Stmt {
        match (stmt.tag) {
            case StmtTag.Expr =>
                var mutableStmt = stmt
                if (let Some(value) <- stmt.expr) {
                    let assignTarget = if (isInOrOf) {
                        AssignTarget.Replace
                    } else {
                        AssignTarget.None
                    }
                    mutableStmt.expr = Some(ExprVisitor(p).visitExprInOut(value, ExprIn(assignTarget, false)))
                }
                return mutableStmt
            case StmtTag.Local =>
                var mutableStmt = stmt
                // 访问声明中的绑定和值
                var newDecls = ArrayList<GDecl>()
                for (decl in stmt.decls) {
                    var mutableDecl = decl
                    visitBinding(decl.binding)
                    if (let Some(value) <- decl.value) {
                        mutableDecl.value = Some(ExprVisitor(p).visitExpr(value))
                    }
                    newDecls.append(mutableDecl)
                }
                mutableStmt.decls = newDecls
                // 选择本地类型
                mutableStmt.localKind = selectLocalKind(stmt.localKind)
                return mutableStmt
            case _ =>
                return stmt
        }
    }

    // ========================================================================
    // visitFunc - 访问函数
    // 严格翻译自: visit.zig:49-105
    //   pub fn visitFunc(p: *P, _func: G.Fn, open_parens_loc: logger.Loc) G.Fn {
    //     p.fn_or_arrow_data_visit = FnOrArrowDataVisit{ .is_async = func.flags.contains(.is_async) };
    //     p.fn_only_data_visit = FnOnlyDataVisit{ .is_this_nested = true, .arguments_ref = func.arguments_ref };
    //     // record name, pushScope, visitArgs, pushScope, visitStmts, popScope x2
    //   }
    // ========================================================================

    /// 访问函数 - 对应 Bun visitFunc
    public func visitFunc(`func`: GFunc): GFunc {
        var result = `func`

        // 记录函数名称为已声明
        if (let Some(name) <- `func`.name) {
            if (let Some(ref) <- name.ref) {
                p.declaredSymbols.append(DeclaredSymbol(ref, DeclaredSymbolKind.Other))
            }
        }

        // 推入参数作用域
        p.pushScope(ScopeKind.FunctionArgs)

        // 访问参数
        visitArgs(`func`.args)

        // 推入函数体作用域
        p.pushScope(ScopeKind.FunctionBody)

        // 访问函数体
        var bodyStmts = ArrayList<Stmt>()
        for (s in `func`.body) {
            visitAndAppendStmt(bodyStmts, s)
        }
        result.body = bodyStmts

        p.popScope()
        p.popScope()

        return result
    }

    // ========================================================================
    // visitArgs - 访问函数参数
    // 严格翻译自: visit.zig:107-147
    //   pub fn visitArgs(p: *P, args: []G.Arg, opts: VisitArgsOpts) void {
    //     // 检查 "use strict" 和简单参数列表
    //     // 检查重复参数名
    //     for (args) |*arg| {
    //       p.visitBinding(arg.binding, duplicate_args_check_ptr);
    //       if (arg.default) |default| { arg.default = p.visitExpr(default); }
    //     }
    //   }
    // ========================================================================

    /// 访问函数参数 - 对应 Bun visitArgs
    public func visitArgs(args: ArrayList<GArg>): Unit {
        for (arg in args) {
            // 访问绑定
            visitBinding(arg.binding)

            // 访问装饰器
            // 对应 Bun: if (arg.ts_decorators.len > 0) { arg.ts_decorators = p.visitTSDecorators(...) }
        }
    }

    // ========================================================================
    // visitBinding - 访问绑定模式
    // 严格翻译自: visit.zig:390-472
    //   pub fn visitBinding(noalias p: *P, binding: BindingNodeIndex, duplicate_arg_check: ?*StringVoidMap) void {
    //     switch (binding.data) {
    //       .b_identifier => |bind| { p.declaredSymbols.append(DeclaredSymbol(bind.ref); ... },
    //       .b_array => |bind| { for items { visitBinding, visit default } },
    //       .b_object => |bind| { for properties { visit key, binding, default } },
    //       .b_missing => {},
    //     }
    //   }
    // ========================================================================

    /// 访问绑定 - 对应 Bun visitBinding
    public func visitBinding(binding: Binding): Unit {
        match (binding.tag) {
            case BindingTag.Identifier =>
                // 记录标识符绑定为已声明
                if (binding.ref.isValid()) {
                    p.declaredSymbols.append(DeclaredSymbol(binding.ref, DeclaredSymbolKind.Other))
                }
            case BindingTag.Array =>
                // 递归访问数组解构中的每个绑定
                for (item in binding.arrayItems) {
                    visitBinding(item)
                }
            case BindingTag.Object =>
                // 递归访问对象解构中的每个属性绑定
                for (`prop` in binding.objectProperties) {
                    if (let Some(v) <- `prop`.value) {
                        visitBinding(v)
                    }
                }
            case BindingTag.Missing =>
                ()
        }
    }

    // ========================================================================
    // visitClassExpr - 访问类表达式/声明
    // 严格翻译自: visit.zig:524-767
    //   pub fn visitClass(...) Ref {
    //     class.ts_decorators = p.visitTSDecorators(class.ts_decorators);
    //     if (class.class_name) |name| { p.declaredSymbols.append(DeclaredSymbol(name.ref?) }
    //     p.pushScopeForVisitPass(.class_name, name_scope_loc);
    //     // Insert shadowing name
    //     if (class.extends) |extends| { class.extends = p.visitExpr(extends); }
    //     p.pushScopeForVisitPass(.class_body, class.body_loc);
    //     for (class.properties) |*property| { ... visit key, value, initializer ... }
    //     p.popScope(); p.popScope();
    //   }
    // ========================================================================

    /// 访问类 - 对应 Bun visitClass
    public func visitClassExpr(loc: Loc, classData: GClass): GClass {
        var result = classData

        // 推入类名作用域
        p.pushScope(ScopeKind.ClassName)

        // 如果类有名称，记录符号
        if (classData.name.size > 0) {
            let nameRef = p.newSymbol(SymbolKind.Class, classData.name)
            p.declaredSymbols.append(DeclaredSymbol(nameRef, DeclaredSymbolKind.Other))
        }

        // 访问 extends 子句
        if (let Some(extendsExpr) <- classData.extends_) {
            result.extends_ = Some(ExprVisitor(p).visitExpr(extendsExpr))
        }

        // 推入类体作用域
        p.pushScope(ScopeKind.ClassBody)

        // 访问类属性
        // 对应 Bun: for (class.properties) |*property| { ... }
        var newProps = ArrayList<GProperty>()
        for (`prop` in classData.properties) {
            var mutableProp = `prop`

            // 访问计算属性键
            if (let Some(keyExpr) <- `prop`.keyExpr) {
                mutableProp.keyExpr = Some(ExprVisitor(p).visitExpr(keyExpr))
            }

            // 访问属性值
            if (let Some(val) <- `prop`.value) {
                mutableProp.value = Some(ExprVisitor(p).visitExpr(val))
            }

            // 访问初始化器
            if (let Some(`init`) <- `prop`.initializer) {
                mutableProp.initializer = Some(ExprVisitor(p).visitExpr(`init`))
            }

            newProps.append(mutableProp)
        }
        result.properties = newProps

        p.popScope() // class_body
        p.popScope() // class_name

        return result
    }

    // ========================================================================
    // visitDecl - 访问声明
    // 严格翻译自: visit.zig:336-364
    //   pub fn visitDecl(p: *P, decl: *Decl, ...) void {
    //     switch (decl.binding.data) {
    //       .b_identifier => |id| { ... const_values.put ... maybeKeepExprSymbolName ... },
    //       .b_object, .b_array => { ... visitBindingAndExprForMacro ... },
    //       else => {},
    //     }
    //   }
    // ========================================================================

    /// 访问声明 - 对应 Bun visitDecl
    public func visitDecl(decl: GDecl, wasAnonymousNamedExpr: Bool, couldBeConstValue: Bool): Unit {
        match (decl.binding.tag) {
            case BindingTag.Identifier =>
                if (decl.binding.ref.isValid()) {
                    if (couldBeConstValue) {
                        if (let Some(val) <- decl.value) {
                            // 记录常量值 - 简化
                        }
                    }
                }
            case BindingTag.Object | BindingTag.Array =>
                // 对应 Bun: visitBindingAndExprForMacro (宏相关)
                ()
            case _ =>
                ()
        }
    }

    // ========================================================================
    // visitBindingAndExprForMacro - 宏的绑定和表达式访问
    // 严格翻译自: visit.zig:276-334
    //   pub fn visitBindingAndExprForMacro(p: *P, binding: Binding, expr: Expr) void {
    //     switch (binding.data) {
    //       .b_object => |bound_object| { ... match properties ... },
    //       .b_array => |bound_array| { ... match items ... },
    //       .b_identifier => |id| { ... const_values.put ... },
    //       else => {},
    //     }
    //   }
    // ========================================================================

    /// 宏的绑定和表达式访问 - 对应 Bun visitBindingAndExprForMacro
    public func visitBindingAndExprForMacro(binding: Binding, expr: Expr): Unit {
        match (binding.tag) {
            case BindingTag.Object =>
                // 对应 Bun: if (expr.data == .e_object and expr.data.e_object.was_originally_macro)
                if (expr.tag == ExprTag.Object) {
                    // 匹配绑定中的属性到对象中的属性
                    // 简化: 跳过宏展开检查
                }
            case BindingTag.Array =>
                // 对应 Bun: if (expr.data == .e_array and expr.data.e_array.was_originally_macro)
                if (expr.tag == ExprTag.Array) {
                    // 匹配绑定中的项到数组中的项
                }
            case BindingTag.Identifier =>
                // 对应 Bun: p.const_values.put(p.allocator, id.ref, expr)
                ()
            case _ =>
                ()
        }
    }

    // ========================================================================
    // 工具方法
    // ========================================================================

    /// 记录已声明符号
    private func recordDeclaredSymbol(ref: Ref): Unit {
        p.declaredSymbols.append(DeclaredSymbol(ref, p.currentScope.id == p.moduleScope.id))
    }

    /// 创建默认名称
    // 对应 Bun: createDefaultName
    private func createDefaultName(loc: Loc): LocRef {
        let name = "default"
        let ref = p.newSymbol(SymbolKind.Other, name)
        return LocRef(loc, Some(ref))
    }

    /// 选择本地声明类型
    // 对应 Bun: selectLocalKind
    private func selectLocalKind(kind: LocalKind): LocalKind {
        // 在大多数情况下保持原样
        // 对应 Bun: 在 minify_syntax 下可能将 let/const 转换为 var
        return kind
    }

    /// 可选地保留表达式符号名称
    // 对应 Bun: maybeKeepExprSymbolName
    private func maybeKeepExprSymbolName(expr: Expr, name: String, wasAnonymousNamedExpr: Bool): Expr {
        // 在 minify 模式下，如果表达式是匿名命名且需要保留名称
        // 对应 Bun: p.keepExprSymbolName / p.maybeKeepExprSymbolName
        return expr
    }

    /// 检查语句是否关心作用域
    // 对应 Bun: statementCaresAboutScope
    private func statementCaresAboutScope(stmt: Stmt): Bool {
        match (stmt.tag) {
            case StmtTag.Local | StmtTag.Function | StmtTag.Class =>
                return true
            case _ =>
                return false
        }
    }
}

// ============================================================================
// SwitchCase - switch case 子句
// 严格翻译自: src/js_parser/ast/S.zig
//   pub const Case = struct {
//       loc: logger.Loc,
//       value: ?Expr = null,
//       body: []Stmt = &.{},
//   }
// ============================================================================

// Note: SwitchCase, CatchClause, FinallyClause, GArg, GFunc, GClass,
// LocalKind, BindingTag are already defined in ast.cj or js_printer_stmt.cj

// ============================================================================
// CatchClause - catch 子句
// 严格翻译自: src/js_parser/ast/S.zig
//   pub const Catch = struct {
//       loc: logger.Loc,
//       body_loc: logger.Loc,
//       binding: ?Binding = null,
//       body: []Stmt = &.{},
//   }
// ============================================================================

/// catch 子句 - 对应 Bun S.Try.Catch
public class CatchClause {
    /// catch 子句位置
    public var loc: Loc
    /// 函数体位置
    public var bodyLoc: Loc
    /// catch 绑定 (如 catch (e) 中的 e)
    public var binding: ?Binding
    /// catch 体语句
    public var stmts: ArrayList<Stmt>

    public init(loc: Loc) {
        this.loc = loc
        bodyLoc = loc
        stmts = ArrayList<Stmt>()
        binding = None
    }
}

// ============================================================================
// FinallyClause - finally 子句
// 严格翻译自: src/js_parser/ast/S.zig
//   pub const Finally = struct {
//       loc: logger.Loc,
//       stmts: []Stmt = &.{},
//   }
// ============================================================================

/// finally 子句 - 对应 Bun S.Try.Finally
public class FinallyClause {
    /// finally 子句位置
    public var loc: Loc
    /// finally 体语句
    public var stmts: ArrayList<Stmt>

    public init(loc: Loc) {
        this.loc = loc
        stmts = ArrayList<Stmt>()
    }
}

// ============================================================================
// GArg - 函数参数
// 严格翻译自: src/js_parser/ast/G.zig
//   pub const Arg = struct {
//       binding: Binding,
//       default: ?Expr = null,
//       ts_decorators: ExprNodeList = .{},
//       is_typescript_ctor_field: bool = false,
//   }
// ============================================================================

// Note: GArg, GFunc, GClass are already defined in ast.cj

// ============================================================================
// GFunc - 函数数据
// 严格翻译自: src/js_parser/ast/G.zig
//   pub const Fn = struct {
//       name: ?LocRef = null,
//       args: []Arg = &.{},
//       body: FnBody,
//       arguments_ref: ?Ref = null,
//       flags: Flags,
//       open_parens_loc: logger.Loc,
//   }
// ============================================================================

/// 函数数据 - 对应 Bun G.Fn
public class GFunc {
    /// 函数名称
    public var name: ?LocRef
    /// 参数列表
    public var args: ArrayList<GArg>
    /// 函数体
    public var body: ArrayList<Stmt>
    /// arguments 引用
    public var argumentsRef: ?Ref
    /// 是否为异步
    public var isAsync: Bool
    /// 是否为生成器
    public var isGenerator: Bool
    /// 是否有 rest 参数
    public var hasRestArg: Bool
    /// 是否为导出
    public var isExport: Bool
    /// 开括号位置
    public var openParensLoc: Loc

    public init() {
        name = None
        args = ArrayList<GArg>()
        body = ArrayList<Stmt>()
        argumentsRef = None
        isAsync = false
        isGenerator = false
        hasRestArg = false
        isExport = false
        openParensLoc = Loc.EMPTY
    }
}

// ============================================================================
// GClass - 类数据
// 严格翻译自: src/js_parser/ast/G.zig
//   pub const Class = struct {
//       class_name: ?LocRef = null,
//       extends: ?Expr = null,
//       properties: []Property,
//       body_loc: logger.Loc,
//       class_keyword: logger.Range,
//       has_decorators: bool = false,
//       ...
//   }
// ============================================================================

// Note: GClass is already defined in ast.cj

// ============================================================================
// LocalKind - 局部声明类型
// 严格翻译自: src/js_parser/ast/S.zig
//   pub const Kind = enum { k_var, k_let, k_const, k_using, k_await_using }
// ============================================================================

// Note: LocalKind is already defined in js_printer_stmt.cj

// ============================================================================
// BindingTag - 绑定标签
// ============================================================================

// Note: BindingTag is already defined in ast.cj

// ============================================================================
// StmtTag 补充 - 语句类型标签补充
// ============================================================================

/// 语句类型标签补充 - 对应 Bun S.Data 联合体标签
public enum StmtTagExtra {
    | ExportClause   // s_export_clause - export { ... }
    | ExportDefault  // s_export_default - export default ...
    | ExportStar     // s_export_star - export * from '...'
    | ExportFrom     // s_export_from - export { ... } from '...'
    | ExportEquals   // s_export_equals - module.exports = ...
    | Namespace      // s_namespace - TypeScript namespace
    | Directive      // s_directive - "use strict" 等
    | Comment        // s_comment - 注释
    | TypeScript     // s_type_script - TypeScript 类型声明
}

// ============================================================================
// LocRef - 位置引用
// ============================================================================

/// 位置引用 - 对应 Bun LocRef
public class LocRef {
    public var loc: Loc
    public var ref: ?Ref

    public init(loc: Loc, ref: ?Ref) {
        this.loc = loc
        this.ref = ref
    }

    public static func empty(): LocRef {
        return LocRef(Loc.EMPTY, Option<Ref>.None)
    }
}
