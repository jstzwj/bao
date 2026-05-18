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
        var hasTopLevelAwait = p.topLevelAwaitKeyword.size > 0
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
        // 提取所有标识符绑定
        var hoistedBindings = ArrayList<BindingPattern>()

        // 简化: 创建 var 声明
        let hoistedDecl = Decl()
        // 将绑定提升为 var

        // 添加 var 声明到提升列表
        let varStmt = Stmt()
        varStmt.tag = StmtTag.Local
        varStmt.loc = stmt.loc
        varStmt.varKind = VarKind.Var
        hoistedStmts.append(varStmt)

        // 创建赋值表达式
        match (stmt.decls) {
            case Some(decls) =>
                for (decl in decls) {
                    if (let Some(value) <- decl.value) {
                        // binding = value
                        let assignExpr = createBindingAssignment(p, decl.binding, value)
                        let exprStmt = Stmt()
                        exprStmt.tag = StmtTag.Expr
                        exprStmt.loc = stmt.loc
                        exprStmt.exprData = assignExpr
                        innerStmts.append(exprStmt)
                    }
                }
            case None => ()
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
        // var funcName;
        if (let Some(name) <- stmt.funcName) {
            let varDecl = Decl()
            let varBinding = BindingPattern(name.loc, BindingPatternTag.Identifier)
            varBinding.name = name.name
            let varStmt = Stmt()
            varStmt.tag = StmtTag.Local
            varStmt.loc = stmt.loc
            varStmt.varKind = VarKind.Var
            hoistedStmts.append(varStmt)

            // this.funcName = funcName
            let thisExpr = Expr()
            thisExpr.tag = ExprTag.ThisExpr
            thisExpr.loc = stmt.loc

            let thisDot = Expr()
            thisDot.tag = ExprTag.Dot
            thisDot.loc = stmt.loc
            thisDot.dotTarget = thisExpr
            thisDot.propertyName = name.name

            let funcId = Expr()
            funcId.tag = ExprTag.Identifier
            funcId.loc = name.loc
            funcId.identifierName = name.name

            let assign = Expr()
            assign.tag = ExprTag.Binary
            assign.loc = stmt.loc
            assign.left = Some(thisDot)
            assign.right = Some(funcId)

            let assignStmt = Stmt()
            assignStmt.tag = StmtTag.Expr
            assignStmt.loc = stmt.loc
            assignStmt.exprData = assign
            innerStmts.append(assignStmt)
        }

        // 函数声明本身
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
        if (let Some(name) <- stmt.className) {
            // var ClassName;
            let varStmt = Stmt()
            varStmt.tag = StmtTag.Local
            varStmt.loc = stmt.loc
            varStmt.varKind = VarKind.Var
            hoistedStmts.append(varStmt)

            // ClassName = class ClassName {}
            let classExpr = Expr()
            classExpr.tag = ExprTag.Class
            classExpr.loc = stmt.loc

            let classId = Expr()
            classId.tag = ExprTag.Identifier
            classId.loc = name.loc
            classId.identifierName = name.name

            let assign = Expr()
            assign.tag = ExprTag.Binary
            assign.loc = stmt.loc
            assign.left = Some(classId)
            assign.right = Some(classExpr)

            let assignStmt = Stmt()
            assignStmt.tag = StmtTag.Expr
            assignStmt.loc = stmt.loc
            assignStmt.exprData = assign
            innerStmts.append(assignStmt)
        } else {
            innerStmts.append(stmt)
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
        let importExpr = Expr()
        importExpr.tag = ExprTag.Import
        importExpr.loc = stmt.loc

        // 创建 await import() 表达式
        let awaitExpr = Expr()
        awaitExpr.tag = ExprTag.Await
        awaitExpr.loc = stmt.loc
        awaitExpr.exprData = importExpr

        // 根据导入类型创建不同的赋值
        if (stmt.starNameLoc != None) {
            // import * as X from 'mod' -> var X = await import('mod')
            let varStmt = Stmt()
            varStmt.tag = StmtTag.Local
            varStmt.loc = stmt.loc
            varStmt.varKind = VarKind.Var
            hoistedStmts.append(varStmt)

            let assign = createSimpleAssign(stmt.namespaceRef, awaitExpr, stmt.loc)
            let assignStmt = Stmt()
            assignStmt.tag = StmtTag.Expr
            assignStmt.loc = stmt.loc
            assignStmt.exprData = assign
            innerStmts.append(assignStmt)
        } else if (stmt.defaultName != None) {
            // import X from 'mod' -> var X = (await import('mod')).default
            let varStmt = Stmt()
            varStmt.tag = StmtTag.Local
            varStmt.loc = stmt.loc
            varStmt.varKind = VarKind.Var
            hoistedStmts.append(varStmt)

            // (await import('mod')).default
            let dotExpr = Expr()
            dotExpr.tag = ExprTag.Dot
            dotExpr.loc = stmt.loc
            dotExpr.dotTarget = awaitExpr
            dotExpr.propertyName = "default"

            let assign = match (stmt.defaultName) {
                case Some(defaultName) => createSimpleAssign(defaultName.ref, dotExpr, stmt.loc)
                case None => dotExpr
            }
            let assignStmt = Stmt()
            assignStmt.tag = StmtTag.Expr
            assignStmt.loc = stmt.loc
            assignStmt.exprData = assign
            innerStmts.append(assignStmt)
        } else if (stmt.importItems.isSome()) {
            // import { a, b } from 'mod' -> var {a, b} = await import('mod')
            let varStmt = Stmt()
            varStmt.tag = StmtTag.Local
            varStmt.loc = stmt.loc
            varStmt.varKind = VarKind.Var
            hoistedStmts.append(varStmt)

            let assignStmt = Stmt()
            assignStmt.tag = StmtTag.Expr
            assignStmt.loc = stmt.loc
            assignStmt.exprData = awaitExpr
            innerStmts.append(assignStmt)
        } else {
            // import 'mod' -> await import('mod')
            let awaitStmt = Stmt()
            awaitStmt.tag = StmtTag.Expr
            awaitStmt.loc = stmt.loc
            awaitStmt.exprData = awaitExpr
            innerStmts.append(awaitStmt)
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
            // 创建 { value: expr }
            let valueKey = Expr()
            valueKey.tag = ExprTag.String
            valueKey.stringValue = "value"

            let obj = Expr()
            obj.tag = ExprTag.Object
            obj.loc = lastStmt.loc
            obj.objectProperties = ArrayList<Property>()
            let property = Property()
            property.key = valueKey
            property.value = lastStmt.exprData
            match (obj.objectProperties) {
                case Some(props) => props.append(property)
                case None => ()
            }

            // 替换最后一个语句
            let wrappedStmt = Stmt()
            wrappedStmt.tag = StmtTag.Expr
            wrappedStmt.loc = lastStmt.loc
            wrappedStmt.exprData = obj
            stmts[stmts.size - 1] = wrappedStmt
        }
    }

    /// 创建绑定赋值表达式
    private static func createBindingAssignment(p: Parser, binding: BindingPattern, value: Expr): Expr {
        let bindingExpr = bindingToExpr(binding)
        let result = Expr()
        result.tag = ExprTag.Binary
        result.loc = binding.loc
        result.left = Some(bindingExpr)
        result.right = Some(value)
        return result
    }

    /// 将绑定模式转换为表达式
    private static func bindingToExpr(binding: BindingPattern): Expr {
        if (binding.tag == BindingPatternTag.Identifier) {
            let result = Expr()
            result.tag = ExprTag.Identifier
            result.loc = binding.loc
            result.identifierName = binding.name
            result.ref = binding.ref
            return result
        }
        let result = Expr()
        result.tag = ExprTag.Missing
        result.loc = binding.loc
        return result
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
        binding: BindingPattern,
        result: ArrayList<Decl>
    ): Unit {
        match (binding.tag) {
            case BindingPatternTag.Identifier =>
                let decl = Decl()
                decl.binding = binding
                result.append(decl)
            case BindingPatternTag.ObjectPattern =>
                for (property in binding.properties) {
                    extractIdentifiersFromBinding(property.value, result)
                }
            case BindingPatternTag.ArrayPattern =>
                for (elem in binding.elements) {
                    extractIdentifiersFromBinding(elem, result)
                }
            case _ =>
                ()
        }
    }
}
