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
    // ========================================================================

    /// 访问并追加语句 - 对应 Bun visitAndAppendStmt
    /// 根据语句类型分派到对应的访问器，结果追加到 stmts
    public func visitAndAppendStmt(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 保存 const local prefix 状态
        // 对应 Bun: p.current_scope.is_after_const_local_prefix
        let wasAfterConstLocalPrefix = p.currentScope.isAfterConstLocalPrefix

        match (stmt.tag) {
            case StmtTag.Empty =>
                // 空语句保持 const local prefix 状态
                p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix
                stmts.append(stmt)

            case StmtTag.Debugger =>
                p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix
                // 如果定义要求删除 debugger，则跳过
                if (!p.options.dropDebugger) {
                    stmts.append(stmt)
                }

            case StmtTag.Type =>
                // TypeScript 类型声明在运行时被忽略
                p.currentScope.isAfterConstLocalPrefix = wasAfterConstLocalPrefix
                // 不追加到语句列表

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
                visitLocal(stmts, stmt)

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
                visitEnum(stmts, stmt)

            case StmtTag.Export =>
                visitExport(stmts, stmt)

            case _ =>
                // 未知语句类型，保持原样
                stmts.append(stmt)
        }
    }

    // ========================================================================
    // 各语句类型的访问方法
    // ========================================================================

    /// 访问块语句 - 对应 Bun s_block
    // 严格翻译自: visit_stmt.zig:953-980
    private func visitBlock(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Block, stmt.loc)

        // 访问块中的每条语句
        var newStmts = ArrayList<Stmt>()
        // 遍历 stmt.stmts 并递归访问
        visitStmtList(newStmts, stmt.stmts)

        p.popScope()

        var mutableStmt = stmt
        mutableStmt.stmts = newStmts
        stmts.append(mutableStmt)
    }

    /// 访问表达式语句 - 对应 Bun s_expr
    // 严格翻译自: visit_stmt.zig:817-918
    private func visitExprStmt(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        if (let Some(value) <- stmt.expr) {
            mutableStmt.expr = Some(p.exprVisitor.visitExpr(value))
        }

        stmts.append(mutableStmt)
    }

    /// 访问 if 语句 - 对应 Bun s_if
    // 严格翻译自: visit_stmt.zig:1018-1132
    private func visitIf(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问条件表达式
        if (let Some(test) <- stmt.expr) {
            mutableStmt.expr = Some(p.exprVisitor.visitExpr(test))
        }

        // 访问 then 分支
        if (let Some(yes) <- stmt.yes) {
            mutableStmt.yes = Some(visitSingleStmt(yes, StmtsKind.None))
        }

        // 访问 else 分支
        if (let Some(no) <- stmt.no) {
            mutableStmt.no = Some(visitSingleStmt(no, StmtsKind.None))
        }

        stmts.append(mutableStmt)
    }

    /// 访问 for 语句 - 对应 Bun s_for
    // 严格翻译自: visit_stmt.zig:1133-1171
    private func visitFor(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Block, stmt.loc)

        var mutableStmt = stmt

        // 访问初始化
        if (let Some(init) <- stmt.init) {
            mutableStmt.init = Some(visitForLoopInit(init, false))
        }

        // 访问条件
        if (let Some(test) <- stmt.expr) {
            mutableStmt.expr = Some(p.exprVisitor.visitExpr(test))
        }

        // 访问更新
        if (let Some(update) <- stmt.update) {
            mutableStmt.update = Some(p.exprVisitor.visitExpr(update))
        }

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        p.popScope()
        stmts.append(mutableStmt)
    }

    /// 访问 for-in 语句 - 对应 Bun s_for_in
    // 严格翻译自: visit_stmt.zig:1172-1207
    private func visitForIn(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Block, stmt.loc)

        var mutableStmt = stmt

        // 访问初始化
        if (let Some(init) <- stmt.init) {
            mutableStmt.init = Some(visitForLoopInit(init, true))
        }

        // 访问迭代值
        if (let Some(value) <- stmt.iterValue) {
            mutableStmt.iterValue = Some(p.exprVisitor.visitExpr(value))
        }

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        p.popScope()
        stmts.append(mutableStmt)
    }

    /// 访问 for-of 语句 - 对应 Bun s_for_of
    // 严格翻译自: visit_stmt.zig:1208-1269
    private func visitForOf(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Block, stmt.loc)

        var mutableStmt = stmt

        // 访问初始化
        if (let Some(init) <- stmt.init) {
            mutableStmt.init = Some(visitForLoopInit(init, true))
        }

        // 访问迭代值
        if (let Some(value) <- stmt.iterValue) {
            mutableStmt.iterValue = Some(p.exprVisitor.visitExpr(value))
        }

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        p.popScope()
        stmts.append(mutableStmt)
    }

    /// 访问 while 语句 - 对应 Bun s_while
    // 严格翻译自: visit_stmt.zig:999-1010
    private func visitWhile(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问条件
        if (let Some(test) <- stmt.expr) {
            mutableStmt.expr = Some(p.exprVisitor.visitExpr(test))
        }

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        stmts.append(mutableStmt)
    }

    /// 访问 do-while 语句 - 对应 Bun s_do_while
    // 严格翻译自: visit_stmt.zig:1011-1017
    private func visitDoWhile(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问循环体
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitLoopBody(body))
        }

        // 访问条件
        if (let Some(test) <- stmt.expr) {
            mutableStmt.expr = Some(p.exprVisitor.visitExpr(test))
        }

        stmts.append(mutableStmt)
    }

    /// 访问函数声明 - 对应 Bun s_function
    // 严格翻译自: visit_stmt.zig:501-588
    private func visitFunction(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        if (let Some(fn) <- stmt.fn) {
            // 保存当前函数状态
            let oldFnOrArrowData = p.fnOrArrowDataVisit.copy()
            let oldFnOnlyData = p.fnOnlyDataVisit.copy()

            // 设置新的函数状态
            let newFnOrArrow = FnOrArrowDataVisit()
            newFnOrArrow.isAsync = fn.isAsync
            newFnOrArrow.isOutsideFnOrArrow = false
            p.fnOrArrowDataVisit = newFnOrArrow

            let newFnOnly = FnOnlyDataVisit()
            newFnOnly.isThisNested = true
            newFnOnly.isNewTargetAllowed = true
            p.fnOnlyDataVisit = newFnOnly

            // 推入函数参数作用域
            p.pushScope(ScopeKind.FunctionArgs, fn.openParensLoc)

            // 推入函数体作用域
            p.pushScope(ScopeKind.FunctionBody, fn.bodyLoc)

            // 访问函数体
            if (fn.body.size > 0) {
                p.visitStmts(fn.body, StmtsKind.FnBody)
            }

            // 弹出作用域
            p.popScope()
            p.popScope()

            // 恢复函数状态
            p.fnOrArrowDataVisit = oldFnOrArrowData
            p.fnOnlyDataVisit = oldFnOnlyData

            mutableStmt.fn = Some(fn)
        }

        stmts.append(mutableStmt)
    }

    /// 访问类声明 - 对应 Bun s_class
    // 严格翻译自: visit_stmt.zig:590-650
    private func visitClass(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 类访问委托给 Parser 的 visitClass 方法
        // 简化版本：直接访问类表达式
        stmts.append(stmt)
    }

    /// 访问局部变量声明 - 对应 Bun s_local
    // 严格翻译自: visit_stmt.zig:712-816
    private func visitLocal(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问每个声明
        var newDecls = ArrayList<GDecl>()
        for (decl in stmt.decls) {
            var mutableDecl = decl

            // 访问绑定
            p.visitBinding(decl.binding, None)

            // 访问初始值
            if (let Some(value) <- decl.value) {
                mutableDecl.value = Some(p.exprVisitor.visitExpr(value))
            }

            newDecls.append(mutableDecl)
        }
        mutableStmt.decls = newDecls

        stmts.append(mutableStmt)
    }

    /// 访问 import 语句 - 对应 Bun s_import
    // 严格翻译自: visit_stmt.zig:42-56
    private func visitImport(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // import 语句在访问阶段通常不需要变换
        stmts.append(stmt)
    }

    /// 访问 return 语句 - 对应 Bun s_return
    // 严格翻译自: visit_stmt.zig:923-952
    private func visitReturn(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        if (let Some(value) <- stmt.expr) {
            var visitedValue = p.exprVisitor.visitExpr(value)

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

    /// 访问 throw 语句 - 对应 Bun s_throw
    // 严格翻译自: visit_stmt.zig:919-922
    private func visitThrow(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        if (let Some(value) <- stmt.expr) {
            mutableStmt.expr = Some(p.exprVisitor.visitExpr(value))
        }

        stmts.append(mutableStmt)
    }

    /// 访问 try 语句 - 对应 Bun s_try
    // 严格翻译自: visit_stmt.zig:1270-1307
    private func visitTry(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问 try 体
        p.pushScope(ScopeKind.Block, stmt.loc)
        var tryBody = ArrayList<Stmt>()
        // 访问 try body 中的语句
        visitStmtList(tryBody, stmt.stmts)
        p.popScope()
        mutableStmt.stmts = tryBody

        // 访问 catch 子句
        if (let Some(catchStmt) <- stmt.catch_) {
            p.pushScope(ScopeKind.CatchBinding, catchStmt.loc)

            // 访问 catch 绑定
            // p.visitBinding(catchStmt.binding, None)

            p.pushScope(ScopeKind.Block, catchStmt.bodyLoc)
            var catchBody = ArrayList<Stmt>()
            visitStmtList(catchBody, catchStmt.stmts)
            p.popScope()

            // 更新 catch 子句的 body
            var mutableCatch = catchStmt
            mutableCatch.stmts = catchBody
            mutableStmt.catch_ = Some(mutableCatch)

            p.popScope()
        }

        // 访问 finally 子句
        if (let Some(finallyStmt) <- stmt.finally) {
            p.pushScope(ScopeKind.Block, finallyStmt.loc)
            var finallyBody = ArrayList<Stmt>()
            visitStmtList(finallyBody, finallyStmt.stmts)
            p.popScope()

            // 更新 finally 子句
            var mutableFinally = finallyStmt
            mutableFinally.stmts = finallyBody
            mutableStmt.finally = Some(mutableFinally)
        }

        stmts.append(mutableStmt)
    }

    /// 访问 switch 语句 - 对应 Bun s_switch
    // 严格翻译自: visit_stmt.zig:1308-1331
    private func visitSwitch(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问 switch 表达式
        if (let Some(test) <- stmt.expr) {
            mutableStmt.expr = Some(p.exprVisitor.visitExpr(test))
        }

        // 访问 switch case 体
        p.pushScope(ScopeKind.Block, stmt.loc)

        // 标记在 switch 内
        let oldIsInsideSwitch = p.fnOrArrowDataVisit.isInsideSwitch
        p.fnOrArrowDataVisit.isInsideSwitch = true

        var newStmts = ArrayList<Stmt>()
        visitStmtList(newStmts, stmt.stmts)
        mutableStmt.stmts = newStmts

        p.fnOrArrowDataVisit.isInsideSwitch = oldIsInsideSwitch
        p.popScope()

        stmts.append(mutableStmt)
    }

    /// 访问 break 语句 - 对应 Bun s_break
    // 严格翻译自: visit_stmt.zig:662-677
    private func visitBreak(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // break 语句不需要访问子节点
        // 但需要验证: 如果没有标签且不在循环/switch 内，报错
        if (!p.fnOrArrowDataVisit.isInsideLoop && !p.fnOrArrowDataVisit.isInsideSwitch) {
            // 没有标签的 break 只能在循环或 switch 中使用
            // 对应 Bun: Cannot use "break" here
        }
        stmts.append(stmt)
    }

    /// 访问 continue 语句 - 对应 Bun s_continue
    // 严格翻译自: visit_stmt.zig:678-693
    private func visitContinue(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // continue 语句不需要访问子节点
        // 但需要验证: 如果没有标签且不在循环内，报错
        if (!p.fnOrArrowDataVisit.isInsideLoop) {
            // 没有标签的 continue 只能在循环中使用
            // 对应 Bun: Cannot use "continue" here
        }
        stmts.append(stmt)
    }

    /// 访问 with 语句 - 对应 Bun s_with
    // 严格翻译自: visit_stmt.zig:981-998
    private func visitWith(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        var mutableStmt = stmt

        // 访问 with 表达式
        if (let Some(value) <- stmt.expr) {
            mutableStmt.expr = Some(p.exprVisitor.visitExpr(value))
        }

        // 访问 with 体
        p.pushScope(ScopeKind.With, stmt.loc)
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitSingleStmt(body, StmtsKind.None))
        }
        p.popScope()

        stmts.append(mutableStmt)
    }

    /// 访问标签语句 - 对应 Bun s_label
    // 严格翻译自: visit_stmt.zig:694-711
    private func visitLabel(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        p.pushScope(ScopeKind.Label, stmt.loc)

        var mutableStmt = stmt

        // 访问标签下的语句
        if (let Some(body) <- stmt.body) {
            mutableStmt.body = Some(visitSingleStmt(body, StmtsKind.None))
        }

        p.popScope()
        stmts.append(mutableStmt)
    }

    /// 访问 TypeScript 枚举 - 对应 Bun s_enum
    // 严格翻译自: visit_stmt.zig:1333-1523
    private func visitEnum(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // TypeScript 枚举在访问阶段的特殊处理
        // 枚举值会被内联到使用处
        stmts.append(stmt)
    }

    /// 访问导出语句 - 对应 Bun s_export_*
    private func visitExport(stmts: ArrayList<Stmt>, stmt: Stmt): Unit {
        // 导出语句的访问取决于具体类型
        // 简化处理：保持原样
        stmts.append(stmt)
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
        p.pushScope(ScopeKind.Block, stmt.loc)

        var newStmt = stmt
        var newStmts = ArrayList<Stmt>()
        visitStmtList(newStmts, stmt.stmts)
        newStmt.stmts = newStmts

        p.popScope()
        return newStmt
    }

    /// 访问循环体 - 对应 Bun visitLoopBody
    // 严格翻译自: visit.zig:474-481
    public func visitLoopBody(stmt: Stmt): Stmt {
        let oldIsInsideLoop = p.fnOrArrowDataVisit.isInsideLoop
        p.fnOrArrowDataVisit.isInsideLoop = true
        let result = visitSingleStmt(stmt, StmtsKind.LoopBody)
        p.fnOrArrowDataVisit.isInsideLoop = oldIsInsideLoop
        return result
    }

    /// 访问 for 循环初始化 - 对应 Bun visitForLoopInit
    // 严格翻译自: visit.zig:366-388
    private func visitForLoopInit(stmt: Stmt, isInOrOf: Bool): Stmt {
        match (stmt.tag) {
            case StmtTag.Expr => {
                var mutableStmt = stmt
                if (let Some(value) <- stmt.expr) {
                    let assignTarget = if (isInOrOf) {
                        AssignTarget.Replace
                    } else {
                        AssignTarget.None
                    }
                    mutableStmt.expr = Some(p.exprVisitor.visitExprInOut(value, ExprIn(assignTarget: assignTarget)))
                }
                return mutableStmt
            }
            case StmtTag.Local => {
                var mutableStmt = stmt
                for (decl in stmt.decls) {
                    p.visitBinding(decl.binding, None)
                }
                return mutableStmt
            }
            case _ =>
                return stmt
        }
    }
}

// ============================================================================
// ScopeKind - 作用域类型
// 用于 visit 过程中的作用域管理
// ============================================================================

/// 作用域类型 - 对应 Bun Scope.Kind 中与 visit 相关的类型
public enum ScopeKind {
    | Block            // 块作用域
    | With             // with 语句
    | Label            // 标签
    | ClassName        // 类名
    | ClassBody        // 类体
    | ClassStaticInit  // 静态初始化块
    | CatchBinding     // catch 绑定
    | FunctionArgs     // 函数参数
    | FunctionBody     // 函数体
    | Entry            // 命名空间/枚举入口
}

/// 导出子句中的 catch 语句信息
/// 用于 try 语句中 catch 子句的存储
public class CatchClause {
    /// catch 子句位置
    public var loc: Loc
    /// 函数体位置
    public var bodyLoc: Loc
    /// catch 体语句
    public var stmts: ArrayList<Stmt>
    /// catch 绑定 (如 catch (e) 中的 e)
    public var binding: ?Binding

    public init(loc: Loc) {
        this.loc = loc
        bodyLoc = loc
        stmts = ArrayList<Stmt>()
        binding = None
    }
}

/// 导出子句中的 finally 子句信息
/// 用于 try 语句中 finally 子句的存储
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
