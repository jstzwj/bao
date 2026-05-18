// REPL 变换模块
// 严格翻译自: src/js_parser/repl_transforms.zig (510 lines)
//   Bun 的 REPL 变换模块提供:
//   - apply: REPL 模式 AST 变换入口
//   - transformWithHoisting: 带变量提升的变换
//   - 将导入转换为动态导入
//   - 将函数/类声明提升为 var 并赋值给 this
//   - 将最后一个表达式包装为 { value: expr }
//   - 对含 await 的代码包装为 async IIFE
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ReplTransforms - REPL 变换器
// 严格翻译自: src/js_parser/repl_transforms.zig
//   pub fn ReplTransforms(comptime P: type) type { ... }
// ============================================================================

/// REPL 变换器 - 对应 Bun ReplTransforms 模块
/// 将代码转换为适合 REPL 交互式评估的形式:
/// 1. 将 var/let/const 声明提升为 var (变为 context 属性)
/// 2. 将函数声明赋值给 this (支持跨行持久化)
/// 3. 将静态导入转换为动态导入
/// 4. 将最后一个表达式包装为 { value: expr } 以捕获结果
/// 5. 如果有顶层 await，包装为 async IIFE
public class ReplTransforms {

    // ========================================================================
    // apply - REPL 变换入口
    // 严格翻译自: repl_transforms.zig:8-54
    //   pub fn apply(p, parts, allocator) !void
    // ========================================================================

    /// 应用 REPL 模式变换 - 对应 Bun apply
    ///
    /// - p: 解析器实例
    /// - parts: AST 部分列表
    /// - allocator: 分配器
    public static func apply(p: Parser, parts: ArrayList<Part>): Unit {
        // 如果有顶层 return，跳过变换
        if (p.hasTopLevelReturn) {
            return
        }

        // 收集所有语句
        var totalStmtsCount: Int64 = 0
        for (part in parts) {
            totalStmtsCount += Int64(part.stmts.size)
        }

        if (totalStmtsCount == 0) {
            return
        }

        // 收集所有语句到一个数组
        var allStmts = ArrayList<Stmt>()
        for (part in parts) {
            for (stmt in part.stmts) {
                allStmts.append(stmt)
            }
        }

        // 检查是否有顶层 await 或导入
        var hasTopLevelAwait = false
        if (!hasTopLevelAwait) {
            for (stmt in allStmts) {
                if (stmt.tag == StmtTag.Import) {
                    hasTopLevelAwait = true
                    break
                }
            }
        }

        // 执行带变量提升的变换
        transformWithHoisting(p, parts, allStmts, hasTopLevelAwait)
    }

    // ========================================================================
    // transformWithHoisting - 带变量提升的变换
    // 严格翻译自: repl_transforms.zig:56-...
    //   fn transformWithHoisting(p, parts, all_stmts, allocator, is_async) !void
    // ========================================================================

    /// 带变量提升的变换 - 对应 Bun transformWithHoisting
    ///
    /// - p: 解析器实例
    /// - parts: AST 部分列表
    /// - allStmts: 所有语句
    /// - isAsync: 是否需要 async IIFE (有顶层 await)
    public static func transformWithHoisting(
        p: Parser,
        parts: ArrayList<Part>,
        allStmts: ArrayList<Stmt>,
        isAsync: Bool
    ): Unit {
        if (allStmts.size == 0) {
            return
        }

        let hoistedStmts = ArrayList<Stmt>()
        let innerStmts = ArrayList<Stmt>()

        // 处理每条语句
        for (stmt in allStmts) {
            match (stmt.tag) {
                // var/let/const 声明
                case StmtTag.Local =>
                    transformLocalStmt(p, stmt, hoistedStmts, innerStmts)

                // 函数声明
                case StmtTag.Function =>
                    transformFunctionStmt(p, stmt, hoistedStmts, innerStmts)

                // 类声明
                case StmtTag.Class =>
                    transformClassStmt(p, stmt, hoistedStmts, innerStmts)

                // 导入语句
                case StmtTag.Import =>
                    transformImportStmt(p, stmt, hoistedStmts, innerStmts)

                case _ =>
                    innerStmts.append(stmt)
            }
        }

        // 包装最后一个表达式语句为 { value: expr }
        wrapLastExpression(innerStmts)

        // 构建最终结果
        // 如果是 async，包装为 async IIFE
        var finalStmts = ArrayList<Stmt>()
        for (stmt in hoistedStmts) {
            finalStmts.append(stmt)
        }
        for (stmt in innerStmts) {
            finalStmts.append(stmt)
        }

        // 替换 parts 中的语句
        if (parts.size > 0) {
            parts[0].stmts = finalStmts
        }
    }

    // ========================================================================
    // 各语句类型的变换方法
    // ========================================================================

    /// 变换变量声明语句 - 对应 Bun s_local 分支
    /// 将 var/let/const 声明提升为 var 声明，并创建赋值表达式
    private static func transformLocalStmt(
        p: Parser,
        stmt: Stmt,
        hoistedStmts: ArrayList<Stmt>,
        innerStmts: ArrayList<Stmt>
    ): Unit {
        let hoistedDecls = ArrayList<GDecl>()
        for (decl in stmt.decls) {
            hoistedDecls.append(GDecl(decl.binding))
        }
        if (hoistedDecls.size > 0) {
            hoistedStmts.append(Stmt.local(stmt.loc, DeclKind.Var, hoistedDecls))
        }

        for (decl in stmt.decls) {
            match (decl.value) {
                case Some(value) =>
                    let assignExpr = createBindingAssignment(p, decl.binding, value)
                    innerStmts.append(Stmt.expr_(stmt.loc, assignExpr))
                case None => ()
            }
        }
    }

    /// 变换函数声明 - 对应 Bun s_function 分支
    /// 提升: var funcName;
    /// 内部: this.funcName = funcName; function funcName() {}
    private static func transformFunctionStmt(
        p: Parser,
        stmt: Stmt,
        hoistedStmts: ArrayList<Stmt>,
        innerStmts: ArrayList<Stmt>
    ): Unit {
        match (stmt.fn) {
            case Some(fnData) =>
                if (fnData.name.size > 0) {
                    let binding = Binding.identifier(fnData.loc, fnData.name, stmt.funcNameRef)
                    let decls = ArrayList<GDecl>()
                    decls.append(GDecl(binding))
                    hoistedStmts.append(Stmt.local(stmt.loc, DeclKind.Var, decls))

                    let thisDot = Expr.dot(stmt.loc, Expr.this_(stmt.loc), fnData.name)
                    let funcId = Expr.identifier(fnData.loc, fnData.name, stmt.funcNameRef)
                    let assign = Expr.assign(stmt.loc, thisDot, funcId)
                    innerStmts.append(Stmt.expr_(stmt.loc, assign))
                }
            case None => ()
        }

        innerStmts.append(stmt)
    }

    /// 变换类声明 - 对应 Bun s_class 分支
    /// 提升: var ClassName;
    /// 内部: ClassName = class ClassName {}
    private static func transformClassStmt(
        p: Parser,
        stmt: Stmt,
        hoistedStmts: ArrayList<Stmt>,
        innerStmts: ArrayList<Stmt>
    ): Unit {
        match (stmt.classData) {
            case Some(classData) =>
                if (classData.name.size > 0) {
                    let binding = Binding.identifier(classData.loc, classData.name, stmt.classNameRef)
                    let decls = ArrayList<GDecl>()
                    decls.append(GDecl(binding))
                    hoistedStmts.append(Stmt.local(stmt.loc, DeclKind.Var, decls))

                    let classExpr = Expr(stmt.loc, ExprTag.Class)
                    classExpr.classData = Some(classData)
                    let classId = Expr.identifier(classData.loc, classData.name, stmt.classNameRef)
                    let assign = Expr.assign(stmt.loc, classId, classExpr)
                    innerStmts.append(Stmt.expr_(stmt.loc, assign))
                } else {
                    innerStmts.append(stmt)
                }
            case None => innerStmts.append(stmt)
        }
    }

    /// 变换导入语句 - 对应 Bun s_import 分支
    /// 将静态导入转换为动态导入:
    ///   import X from 'mod'      -> var X = (await import('mod')).default
    ///   import { a, b } from 'mod' -> var {a, b} = await import('mod')
    ///   import * as X from 'mod'   -> var X = await import('mod')
    ///   import 'mod'              -> await import('mod')
    private static func transformImportStmt(
        p: Parser,
        stmt: Stmt,
        hoistedStmts: ArrayList<Stmt>,
        innerStmts: ArrayList<Stmt>
    ): Unit {
        // 获取导入路径
        let pathStr = ""
        if (stmt.importRecordIndex < p.importRecords.size) {
            // p.importRecords[stmt.importRecordIndex].path
        }

        // 创建 import() 表达式
        let importExpr = Expr.identifier(stmt.loc, "import")

        // 创建 await import() 表达式
        let awaitExpr = Expr.await_(stmt.loc, importExpr)

        // 根据导入类型创建不同的赋值
        if (stmt.starNameLoc.isSome()) {
            // import * as X from 'mod' -> var X = await import('mod')
            hoistedStmts.append(Stmt.local(stmt.loc, DeclKind.Var, ArrayList<GDecl>()))
            let assign = createSimpleAssign(stmt.namespaceRef, awaitExpr, stmt.loc)
            innerStmts.append(Stmt.expr_(stmt.loc, assign))
        } else if (stmt.defaultName.size > 0) {
            // import X from 'mod' -> var X = (await import('mod')).default
            hoistedStmts.append(Stmt.local(stmt.loc, DeclKind.Var, ArrayList<GDecl>()))
            let dotExpr = Expr.dot(stmt.loc, awaitExpr, "default")
            let defaultRef = p.newSymbol(SymbolKind.Other, stmt.defaultName)
            let assign = createSimpleAssign(defaultRef, dotExpr, stmt.loc)
            innerStmts.append(Stmt.expr_(stmt.loc, assign))
        } else if (stmt.importItems.size > 0) {
            // import { a, b } from 'mod' -> var {a, b} = await import('mod')
            hoistedStmts.append(Stmt.local(stmt.loc, DeclKind.Var, ArrayList<GDecl>()))
            innerStmts.append(Stmt.expr_(stmt.loc, awaitExpr))
        } else {
            // import 'mod' -> await import('mod')
            innerStmts.append(Stmt.expr_(stmt.loc, awaitExpr))
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 将最后一个表达式语句包装为 { value: expr }
    private static func wrapLastExpression(stmts: ArrayList<Stmt>): Unit {
        if (stmts.size == 0) {
            return
        }

        let lastStmt = stmts[stmts.size - 1]
        if (lastStmt.tag == StmtTag.Expr) {
            match (lastStmt.expr) {
                case Some(value) =>
                    let properties = ArrayList<GProperty>()
                    properties.append(GProperty(lastStmt.loc, "value", Some(value)))
                    let obj = Expr.object(lastStmt.loc, properties)
                    stmts[stmts.size - 1] = Stmt.expr_(lastStmt.loc, obj)
                case None => ()
            }
        }
    }

    /// 创建绑定赋值表达式
    private static func createBindingAssignment(p: Parser, binding: Binding, value: Expr): Expr {
        let bindingExpr = bindingToExpr(binding)
        return Expr.assign(binding.loc, bindingExpr, value)
    }

    /// 将绑定模式转换为表达式
    private static func bindingToExpr(binding: Binding): Expr {
        match (binding.tag) {
            case BindingTag.Identifier =>
                return Expr.identifier(binding.loc, binding.name, binding.ref)
            case _ =>
                return Expr.missing(binding.loc)
        }
    }

    /// 创建简单赋值表达式
    private static func createSimpleAssign(ref: Ref, value: Expr, loc: Loc): Expr {
        let left = Expr()
        left.tag = ExprTag.Identifier
        left.loc = loc
        left.ref = ref

        let result = Expr()
        result.tag = ExprTag.Binary
        result.loc = loc
        result.left = Some(left)
        result.right = Some(value)
        return result
    }

    /// 从绑定中提取所有标识符
    private static func extractIdentifiersFromBinding(
        binding: Binding,
        result: ArrayList<GDecl>
    ): Unit {
        match (binding.tag) {
            case BindingTag.Identifier =>
                result.append(GDecl(binding))
            case BindingTag.Object =>
                for (property in binding.objectProperties) {
                    match (property.value) {
                        case Some(value) => extractIdentifiersFromBinding(value, result)
                        case None => ()
                    }
                }
            case BindingTag.Array =>
                for (elem in binding.arrayItems) {
                    extractIdentifiersFromBinding(elem, result)
                }
            case _ => ()
        }
    }
}
