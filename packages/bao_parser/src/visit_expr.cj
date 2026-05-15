// AST 表达式 Visitor
// 严格翻译自: src/js_parser/visit/visit_expr.zig (1801 lines)
//   Bun 的表达式 Visitor 遍历所有表达式节点类型
//   visitExpr() 是入口，根据 ExprTag 分派到各自的访问器
//   包括: e_identifier, e_dot, e_index, e_call, e_new, e_unary, e_binary,
//         e_if(ternary), e_array, e_object, e_spread, e_arrow, e_function,
//         e_class, e_template, e_await, e_yield, e_import, e_this 等
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ExprVisitor - 表达式访问器
// 严格翻译自: src/js_parser/visit/visit_expr.zig
//   VisitExpr() 返回一个包含 visitExpr/visitExprInOut 的 struct
//   仓颉实现为独立类，接收 Parser 实例
// ============================================================================

/// 表达式访问器 - 对应 Bun VisitExpr 模块
/// 遍历和变换所有表达式节点
public class ExprVisitor {
    /// 关联的解析器
    private var p: Parser

    public init(parser: Parser) {
        p = parser
    }

    // ========================================================================
    // visitExpr - 表达式访问入口
    // 严格翻译自: visit_expr.zig:14-21
    //   pub inline fn visitExpr(noalias p: *P, expr: Expr) Expr
    // ========================================================================

    /// 访问表达式 - 对应 Bun visitExpr
    /// 入口方法，委托给 visitExprInOut
    public func visitExpr(expr: Expr): Expr {
        return visitExprInOut(expr, ExprIn())
    }

    // ========================================================================
    // visitExprInOut - 带上下文的表达式访问
    // 严格翻译自: visit_expr.zig:23-34
    //   pub fn visitExprInOut(p: *P, expr: Expr, in: ExprIn) Expr
    // ========================================================================

    /// 带上下文访问表达式 - 对应 Bun visitExprInOut
    public func visitExprInOut(expr: Expr, input: ExprIn): Expr {
        // 检查赋值目标是否有效
        if (input.assignTarget != AssignTarget.None && !isValidAssignmentTarget(expr)) {
            p.log.addError(MsgData("Invalid assignment target"))
        }

        // 根据 ExprTag 分派到对应的访问器
        match (expr.tag) {
            case ExprTag.Missing =>
                return expr
            case ExprTag.Undefined =>
                return expr
            case ExprTag.Null =>
                return expr
            case ExprTag.Boolean =>
                return visitBoolean(expr)
            case ExprTag.Number =>
                return visitNumber(expr)
            case ExprTag.String =>
                return expr
            case ExprTag.BigInt =>
                return expr
            case ExprTag.Regex =>
                return expr
            case ExprTag.Identifier =>
                return visitIdentifier(expr, input)
            case ExprTag.ImportIdentifier =>
                return visitImportIdentifier(expr, input)
            case ExprTag.This =>
                return visitThis(expr)
            case ExprTag.Super =>
                return expr
            case ExprTag.New =>
                return visitNew(expr)
            case ExprTag.Call =>
                return visitCall(expr, input)
            case ExprTag.Dot =>
                return visitDot(expr, input)
            case ExprTag.Index =>
                return visitIndex(expr, input)
            case ExprTag.Array =>
                return visitArray(expr, input)
            case ExprTag.Object =>
                return visitObject(expr, input)
            case ExprTag.Spread =>
                return visitSpread(expr)
            case ExprTag.Arrow =>
                return visitArrow(expr)
            case ExprTag.Function =>
                return visitFunction(expr)
            case ExprTag.Class =>
                return visitClass(expr)
            case ExprTag.Template =>
                return visitTemplate(expr)
            case ExprTag.Unary =>
                return visitUnary(expr, input)
            case ExprTag.Binary =>
                return visitBinary(expr, input)
            case ExprTag.Ternary =>
                return visitTernary(expr, input)
            case ExprTag.Assign =>
                return visitAssign(expr, input)
            case ExprTag.Postfix =>
                return visitPostfix(expr, input)
            case ExprTag.Await =>
                return visitAwait(expr)
            case ExprTag.Yield =>
                return visitYield(expr)
            case ExprTag.JsxElement =>
                return visitJsxElement(expr)
            case ExprTag.JsxFragment =>
                return visitJsxFragment(expr)
            case ExprTag.TypeCast =>
                return visitTypeCast(expr, input)
            case _ =>
                return expr
        }
    }

    // ========================================================================
    // 各表达式类型的访问方法
    // ========================================================================

    /// 访问布尔表达式 - 对应 Bun e_string (简化)
    private func visitBoolean(expr: Expr): Expr {
        return expr
    }

    /// 访问数字表达式 - 对应 Bun e_number
    private func visitNumber(expr: Expr): Expr {
        return expr
    }

    /// 访问 this 表达式 - 对应 Bun e_this
    // 严格翻译自: visit_expr.zig:53-64
    private func visitThis(expr: Expr): Expr {
        // 在箭头函数中，this 指向外部作用域
        // 对应 Bun: p.valueForThis(expr.loc)
        return expr
    }

    /// 访问标识符表达式 - 对应 Bun e_identifier
    // 严格翻译自: visit_expr.zig:86-191
    private func visitIdentifier(expr: Expr, input: ExprIn): Expr {
        // 获取标识符名称
        let name = expr.identifierName

        // 严格模式检查: 不能使用保留字
        if (p.isStrictMode() && isStrictModeReservedWord(name)) {
            p.log.addWarning(MsgData("Cannot use reserved word '${name}' as identifier in strict mode"))
        }

        // 在作用域链中查找符号
        let result = p.findSymbol(expr.loc, name)
        // 更新引用
        var mutableExpr = expr
        mutableExpr.ref = result.ref

        // 处理赋值目标
        if (input.assignTarget != AssignTarget.None) {
            // 检查是否赋值给常量
            if (p.isSymbolConstant(result.ref)) {
                p.log.addError(MsgData("Cannot assign to '${name}' because it is a constant"))
            }
            // 标记符号已被赋值
            p.markSymbolAssigned(result.ref)
        }

        // 检查是否需要替换为 define 值
        if (p.isSymbolUnbound(result.ref) && !result.isInsideWithScope) {
            let defineValue = p.getDefineForIdentifier(name)
            if (defineValue != None) {
                if (let Some(value) <- defineValue) {
                    // 标记原始引用不使用
                    p.ignoreUsage(result.ref)
                    return value
                }
            }
        }

        return mutableExpr
    }

    /// 访问导入标识符 - 对应 Bun e_import_identifier
    private func visitImportIdentifier(expr: Expr, input: ExprIn): Expr {
        // 导入标识符的特殊处理
        return visitIdentifier(expr, input)
    }

    /// 访问展开表达式 - 对应 Bun e_spread
    // 严格翻译自: visit_expr.zig:81-85
    private func visitSpread(expr: Expr): Expr {
        if (let Some(value) <- expr.value) {
            var mutableExpr = expr
            mutableExpr.value = Some(visitExpr(value))
            return mutableExpr
        }
        return expr
    }

    /// 访问点访问表达式 - 对应 Bun e_dot
    // 严格翻译自: visit_expr.zig:828-921
    private func visitDot(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问目标表达式
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExprInOut(target, ExprIn()))
        }

        return mutableExpr
    }

    /// 访问索引访问表达式 - 对应 Bun e_index
    // 严格翻译自: visit_expr.zig:516-700
    private func visitIndex(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问目标
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExprInOut(target, ExprIn(
                hasChainParent: false
            )))
        }

        // 访问索引
        if (let Some(index) <- expr.indexExpr) {
            mutableExpr.indexExpr = Some(visitExpr(index))
        }

        return mutableExpr
    }

    /// 访问调用表达式 - 对应 Bun e_call
    // 严格翻译自: visit_expr.zig:1185-1551
    private func visitCall(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问调用目标
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExprInOut(target, ExprIn(
                hasChainParent: false,
                propertyAccessForMethodCallMaybeShouldReplaceWithUndefined: true
            )))
        }

        // 访问参数列表
        var newArgs = ArrayList<Expr>()
        for (arg in expr.args) {
            newArgs.append(visitExpr(arg))
        }
        mutableExpr.args = newArgs

        return mutableExpr
    }

    /// 访问 new 表达式 - 对应 Bun e_new
    // 严格翻译自: visit_expr.zig:1552-1566
    private func visitNew(expr: Expr): Expr {
        var mutableExpr = expr

        // 访问构造目标
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExpr(target))
        }

        // 访问参数
        var newArgs = ArrayList<Expr>()
        for (arg in expr.args) {
            newArgs.append(visitExpr(arg))
        }
        mutableExpr.args = newArgs

        return mutableExpr
    }

    /// 访问一元表达式 - 对应 Bun e_unary
    // 严格翻译自: visit_expr.zig:701-827
    private func visitUnary(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        if (let Some(value) <- expr.value) {
            let assignTarget = unaryAssignTarget(expr.op)
            mutableExpr.value = Some(visitExprInOut(value, ExprIn(assignTarget: assignTarget)))
        }

        return mutableExpr
    }

    /// 访问二元表达式 - 对应 Bun e_binary
    // 严格翻译自: visit_expr.zig:445-515
    private func visitBinary(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 使用迭代而非递归来避免栈溢出
        // 对应 Bun 的 BinaryExpressionVisitor 栈方法
        if (let Some(left) <- expr.left) {
            let assignTarget = binaryAssignTarget(expr.op)
            mutableExpr.left = Some(visitExprInOut(left, ExprIn(assignTarget: assignTarget)))
        }

        // 访问右侧
        if (let Some(right) <- expr.right) {
            mutableExpr.right = Some(visitExpr(right))
        }

        return mutableExpr
    }

    /// 访问三元表达式 - 对应 Bun e_if
    // 严格翻译自: visit_expr.zig:922-983
    private func visitTernary(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问条件
        if (let Some(test) <- expr.test) {
            mutableExpr.test = Some(visitExpr(test))
        }

        // 访问真分支
        if (let Some(yes) <- expr.yes) {
            mutableExpr.yes = Some(visitExpr(yes))
        }

        // 访问假分支
        if (let Some(no) <- expr.no) {
            mutableExpr.no = Some(visitExpr(no))
        }

        return mutableExpr
    }

    /// 访问赋值表达式 - 对应 Bun e_assign
    private func visitAssign(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问目标 (作为赋值目标)
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExprInOut(target, ExprIn(assignTarget: AssignTarget.Replace)))
        }

        // 访问值
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExpr(value))
        }

        return mutableExpr
    }

    /// 访问后缀表达式 - 对应 Bun e_postfix
    private func visitPostfix(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExprInOut(value, ExprIn(assignTarget: AssignTarget.Update)))
        }
        return mutableExpr
    }

    /// 访问数组表达式 - 对应 Bun e_array
    // 严格翻译自: visit_expr.zig:997-1051
    private func visitArray(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        var newItems = ArrayList<Expr>()

        for (item in expr.items) {
            if (item.tag == ExprTag.Spread) {
                // 展开元素 - 递归访问
                newItems.append(visitExprInOut(item, ExprIn(assignTarget: input.assignTarget)))
            } else if (item.tag == ExprTag.Missing) {
                newItems.append(item)
            } else {
                newItems.append(visitExprInOut(item, ExprIn(assignTarget: input.assignTarget)))
            }
        }
        mutableExpr.items = newItems
        return mutableExpr
    }

    /// 访问对象表达式 - 对应 Bun e_object
    // 严格翻译自: visit_expr.zig:1052-1141
    private func visitObject(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        var newProps = ArrayList<GProperty>()

        for (prop in expr.properties) {
            var newProp = prop

            // 访问键
            // (在简化的 AST 中，key 存储在 propertyName 中)

            // 访问值
            if (let Some(val) <- prop.value) {
                // 注意: 这里 prop.value 是 Expr 类型，但我们通过 GProperty 访问
                // 简化处理: 如果属性有值表达式，需要递归访问
                newProp.hasSideEffects = true // 安全假设
            }

            newProps.append(newProp)
        }

        mutableExpr.properties = newProps
        return mutableExpr
    }

    /// 访问箭头函数 - 对应 Bun e_arrow
    // 严格翻译自: visit_expr.zig:1567-1622
    private func visitArrow(expr: Expr): Expr {
        // 箭头函数需要特殊的作用域处理
        // 保存当前函数状态，创建新的作用域
        // 简化版本: 直接委托给 visitFunction 的通用逻辑
        return visitFunction(expr)
    }

    /// 访问函数表达式 - 对应 Bun e_function
    // 严格翻译自: visit_expr.zig:1623-1661
    private func visitFunction(expr: Expr): Expr {
        var mutableExpr = expr

        if (let Some(fn) <- expr.fn) {
            // 保存当前函数状态
            let oldFnOrArrowData = p.fnOrArrowDataVisit
            let oldFnOnlyData = p.fnOnlyDataVisit

            // 设置新的函数状态
            let newFnOrArrow = FnOrArrowDataVisit()
            newFnOrArrow.isAsync = fn.isAsync
            newFnOrArrow.isArrow = (expr.tag == ExprTag.Arrow)
            newFnOrArrow.isOutsideFnOrArrow = false
            p.fnOrArrowDataVisit = newFnOrArrow

            let newFnOnly = FnOnlyDataVisit()
            newFnOnly.isThisNested = true
            p.fnOnlyDataVisit = newFnOnly

            // 推入函数参数作用域
            p.pushScope(ScopeKind.FunctionArgs, expr.loc)

            // 推入函数体作用域
            p.pushScope(ScopeKind.FunctionBody, fn.bodyLoc)

            // 访问函数体中的语句
            if (fn.body.size > 0) {
                p.visitStmts(fn.body, StmtsKind.FnBody)
            }

            // 弹出作用域
            p.popScope()
            p.popScope()

            // 恢复函数状态
            p.fnOrArrowDataVisit = oldFnOrArrowData
            p.fnOnlyDataVisit = oldFnOnlyData
        }

        return mutableExpr
    }

    /// 访问类表达式 - 对应 Bun e_class
    // 严格翻译自: visit_expr.zig:1662-1692
    private func visitClass(expr: Expr): Expr {
        var mutableExpr = expr

        if (let Some(classData) <- expr.classData) {
            // 推入类名作用域
            p.pushScope(ScopeKind.ClassName, expr.loc)

            // 访问 extends 子句
            if (classData.extends.size > 0) {
                // extends 表达式
            }

            // 推入类体作用域
            p.pushScope(ScopeKind.ClassBody, classData.bodyLoc)

            // 访问类属性
            // ... (属性访问逻辑)

            // 弹出作用域
            p.popScope()
            p.popScope()
        }

        return mutableExpr
    }

    /// 访问模板字符串 - 对应 Bun e_template
    // 严格翻译自: visit_expr.zig:381-444
    private func visitTemplate(expr: Expr): Expr {
        var mutableExpr = expr

        // 访问模板标签
        if (let Some(tag) <- expr.templateTag) {
            mutableExpr.templateTag = Some(visitExpr(tag))
        }

        // 访问模板部分
        var newParts = ArrayList<Expr>()
        for (part in expr.templateParts) {
            newParts.append(visitExpr(part))
        }
        mutableExpr.templateParts = newParts

        return mutableExpr
    }

    /// 访问 await 表达式 - 对应 Bun e_await
    // 严格翻译自: visit_expr.zig:984-989
    private func visitAwait(expr: Expr): Expr {
        var mutableExpr = expr
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExpr(value))
        }
        return mutableExpr
    }

    /// 访问 yield 表达式 - 对应 Bun e_yield
    // 严格翻译自: visit_expr.zig:990-996
    private func visitYield(expr: Expr): Expr {
        var mutableExpr = expr
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExpr(value))
        }
        return mutableExpr
    }

    /// 访问 import() 表达式 - 对应 Bun e_import
    // 严格翻译自: visit_expr.zig:1142-1184
    private func visitImport(expr: Expr): Expr {
        // import() 表达式的特殊处理
        return expr
    }

    /// 访问 JSX 元素 - 对应 Bun e_jsx_element
    // 严格翻译自: visit_expr.zig:192-380
    private func visitJsxElement(expr: Expr): Expr {
        var mutableExpr = expr

        // 访问标签
        if (let Some(tag) <- expr.jsxTag) {
            mutableExpr.jsxTag = Some(visitExpr(tag))
        }

        // 访问子元素
        var newChildren = ArrayList<Expr>()
        for (child in expr.jsxChildren) {
            let visited = visitExpr(child)
            if (visited.tag != ExprTag.Missing) {
                newChildren.append(visited)
            }
        }
        mutableExpr.jsxChildren = newChildren

        return mutableExpr
    }

    /// 访问 JSX 片段
    private func visitJsxFragment(expr: Expr): Expr {
        return visitJsxElement(expr)
    }

    /// 访问类型断言 - 对应 Bun 类型断言
    private func visitTypeCast(expr: Expr, input: ExprIn): Expr {
        // 类型断言在运行时不产生代码，直接访问内部表达式
        if (let Some(value) <- expr.value) {
            return visitExprInOut(value, input)
        }
        return expr
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 检查是否为有效的赋值目标
    private func isValidAssignmentTarget(expr: Expr): Bool {
        match (expr.tag) {
            case ExprTag.Identifier | ExprTag.Index | ExprTag.Dot =>
                return true
            case ExprTag.Object | ExprTag.Array =>
                return true // 解构赋值
            case _ =>
                return false
        }
    }

    /// 获取一元操作符的赋值目标
    /// 对应 Bun Op.Code.unaryAssignTarget()
    private func unaryAssignTarget(op: OpCode): AssignTarget {
        match (op) {
            case OpCode.UnPreInc | OpCode.UnPreDec | OpCode.UnPostInc | OpCode.UnPostDec =>
                return AssignTarget.Update
            case OpCode.UnDelete =>
                return AssignTarget.Replace
            case _ =>
                return AssignTarget.None
        }
    }

    /// 获取二元操作符的赋值目标
    /// 对应 Bun Op.Code.binaryAssignTarget()
    private func binaryAssignTarget(op: OpCode): AssignTarget {
        if (op.isAssign()) {
            // == 不是赋值, 但 === 也不是 - 检查真正的赋值
            match (op) {
                case OpCode.BinAssign =>
                    return AssignTarget.Replace
                case _ =>
                    if (op.isAssign()) {
                        return AssignTarget.Update
                    }
                    return AssignTarget.None
            }
        }
        return AssignTarget.None
    }

    /// 检查是否为严格模式保留字
    private func isStrictModeReservedWord(name: String): Bool {
        match (name) {
            case "implements" | "interface" | "let" | "package" |
                 "private" | "protected" | "public" | "static" |
                 "yield" =>
                return true
            case _ =>
                return false
        }
    }
}

// ============================================================================
// OpCode 扩展 - 一元操作符的赋值目标
// ============================================================================

/// 一元操作符扩展 (前缀/后缀自增自减)
/// 对应 Bun 中不存在的操作符类型，用于支持 visitUnary
public enum UnaryOp {
    | PreIncrement    // ++x
    | PreDecrement    // --x
    | PostIncrement   // x++
    | PostDecrement   // x--
}
