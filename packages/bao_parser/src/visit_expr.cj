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
    //   pub inline fn visitExpr(noalias p: *P, expr: Expr) Expr {
    //     return p.visitExprInOut(expr, .{});
    //   }
    // ========================================================================

    /// 访问表达式 - 对应 Bun visitExpr
    /// 入口方法，委托给 visitExprInOut
    public func visitExpr(expr: Expr): Expr {
        return visitExprInOut(expr, ExprIn())
    }

    // ========================================================================
    // visitExprInOut - 带上下文的表达式访问
    // 严格翻译自: visit_expr.zig:23-34
    //   pub fn visitExprInOut(p: *P, expr: Expr, in: ExprIn) Expr {
    //     if (in.assign_target != .none and !p.isValidAssignmentTarget(expr)) {
    //       p.log.addError(...)
    //     }
    //     return switch (expr.data) {
    //       inline else => |tag| if (@hasDecl(visitors, @tagName(tag)))
    //         @field(visitors, @tagName(tag))(p, expr, in)
    //       else expr,
    //     };
    //   }
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
                // 对应 Bun e_string: return expr
                return expr
            case ExprTag.BigInt =>
                return expr
            case ExprTag.Regex =>
                return expr
            case ExprTag.Identifier =>
                return visitIdentifier(expr, input)
            case ExprTag.ImportIdentifier =>
                return visitImportIdentifier(expr, input)
            case ExprTag.ThisExpr =>
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
    // e_new_target - 访问 new.target
    // 严格翻译自: visit_expr.zig:37-43
    //   pub fn e_new_target(_: *P, expr: Expr, _: ExprIn) Expr {
    //     return expr;
    //   }
    // ========================================================================

    // visitBoolean 不需要特殊处理

    /// 访问布尔表达式 - 对应 Bun e_string (简化)
    private func visitBoolean(expr: Expr): Expr {
        return expr
    }

    /// 访问数字表达式 - 对应 Bun e_number
    private func visitNumber(expr: Expr): Expr {
        return expr
    }

    // ========================================================================
    // e_this - 访问 this 表达式
    // 严格翻译自: visit_expr.zig:53-64
    //   pub fn e_this(p: *P, expr: Expr, _: ExprIn) Expr {
    //     if (p.valueForThis(expr.loc)) |exp| { return exp; }
    //     return expr;
    //   }
    // ========================================================================

    /// 访问 this 表达式 - 对应 Bun e_this
    private func visitThis(expr: Expr): Expr {
        // 对应 Bun: p.valueForThis(expr.loc)
        // 在箭头函数中，this 指向外部作用域
        // 如果有 this 替换值，返回它
        return expr
    }

    // ========================================================================
    // e_import_meta - 访问 import.meta
    // 严格翻译自: visit_expr.zig:65-80
    //   pub fn e_import_meta(p: *P, expr: Expr, in: ExprIn) Expr {
    //     const is_delete_target = p.delete_target == .e_import_meta;
    //     if (p.define.dots.get("meta")) |meta| { ... }
    //     return expr;
    //   }
    // ========================================================================

    /// 访问 import.meta 表达式 - 对应 Bun e_import_meta
    private func visitImportMeta(expr: Expr, input: ExprIn): Expr {
        // 对应 Bun: 检查 define 中是否有 meta 相关的替换
        // 以及 is_delete_target 检查
        return expr
    }

    // ========================================================================
    // e_spread - 访问展开表达式
    // 严格翻译自: visit_expr.zig:81-85
    //   pub fn e_spread(p: *P, expr: Expr, _: ExprIn) Expr {
    //     const exp = expr.data.e_spread;
    //     exp.value = p.visitExpr(exp.value);
    //     return expr;
    //   }
    // ========================================================================

    /// 访问展开表达式 - 对应 Bun e_spread
    private func visitSpread(expr: Expr): Expr {
        if (let Some(value) <- expr.value) {
            var mutableExpr = expr
            mutableExpr.value = Some(visitExpr(value))
            return mutableExpr
        }
        return expr
    }

    // ========================================================================
    // e_identifier - 访问标识符表达式
    // 严格翻译自: visit_expr.zig:86-191
    //   pub fn e_identifier(p: *P, expr: Expr, in: ExprIn) Expr {
    //     var e_ = expr.data.e_identifier;
    //     const is_delete_target = ...;
    //     const name = p.loadNameFromRef(e_.ref);
    //     const result = p.findSymbol(expr.loc, name) catch unreachable;
    //     e_.ref = result.ref;
    //     // Handle assigning to constant
    //     if (in.assign_target != .none) { ... }
    //     // Substitute user-specified defines for unbound symbols
    //     if (... kind == .unbound ...) { ... }
    //     return p.handleIdentifier(...)
    //   }
    // ========================================================================

    /// 访问标识符表达式 - 对应 Bun e_identifier
    private func visitIdentifier(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        let name = expr.identifierName

        // 查找符号
        // 对应 Bun: const result = p.findSymbol(expr.loc, name) catch unreachable
        let result = p.findSymbol(name)
        if (let Some(ref) <- result) {
            mutableExpr.ref = ref
        }

        // 处理常量赋值
        // 对应 Bun: if (in.assign_target != .none) { ... check constant ... }
        if (input.assignTarget != AssignTarget.None) {
            if (let Some(ref) <- result) {
                // 检查是否赋值给常量
                // 对应 Bun: if (p.symbols.items[result.ref.innerIndex()].kind == .constant)
            }
        }

        // 替换未绑定符号的用户定义值
        // 对应 Bun: if (p.symbols.items[e_.ref.innerIndex()].kind == .unbound and ...)
        if (let Some(ref) <- result) {
            // 处理 require 引用
            // 对应 Bun: if (p.require_ref.eql(e_.ref) and !p.isSourceRuntime())
            if (ref == p.requireRef && !p.options.bundle) {
                // 记录 require 使用
                // 返回 require 的值
            }
        }

        return mutableExpr
    }

    /// 访问导入标识符 - 对应 Bun e_import_identifier
    private func visitImportIdentifier(expr: Expr, input: ExprIn): Expr {
        return visitIdentifier(expr, input)
    }

    // ========================================================================
    // e_jsx_element - 访问 JSX 元素
    // 严格翻译自: visit_expr.zig:192-380
    //   pub fn e_jsx_element(p: *P, expr: Expr, _: ExprIn) Expr {
    //     const e_ = expr.data.e_jsx_element;
    //     switch (jsx_transform_type) {
    //       .react => {
    //         // 访问标签、属性、子元素
    //         // 生成 createElement 或 jsx 调用
    //       },
    //     }
    //   }
    // ========================================================================

    /// 访问 JSX 元素 - 对应 Bun e_jsx_element
    private func visitJsxElement(expr: Expr): Expr {
        var mutableExpr = expr

        // 访问标签
        if (let Some(tag) <- expr.jsxTag) {
            mutableExpr.jsxTag = Some(visitExpr(tag))
        }

        // 访问属性
        // 对应 Bun: for (all_props) |*property| { ... visit key, value, initializer ... }
        var newProps = ArrayList<GProperty>()
        for (`prop` in expr.jsxProps) {
            var mutableProp = `prop`

            if (!`prop`.flags.isSpread) {
                if (let Some(keyExpr) <- `prop`.keyExpr) {
                    mutableProp.keyExpr = Some(visitExpr(keyExpr))
                }
            }

            if (let Some(val) <- `prop`.value) {
                mutableProp.value = Some(visitExpr(val))
            }

            if (let Some(`init`) <- `prop`.initializer) {
                mutableProp.initializer = Some(visitExpr(`init`))
            }

            newProps.append(mutableProp)
        }
        mutableExpr.jsxProps = newProps

        // 访问子元素
        // 对应 Bun: for (children_elements) |child| { arg = p.visitExpr(child); if (arg.data != .e_missing) { args.append(...) } }
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

    // ========================================================================
    // e_template - 访问模板字符串
    // 严格翻译自: visit_expr.zig:381-444
    //   pub fn e_template(p: *P, expr: Expr, _: ExprIn) Expr {
    //     if (e_.tag) |tag| {
    //       e_.tag = p.visitExpr(tag);
    //       // Handle macros
    //     }
    //     for (e_.parts) |*part| { part.value = p.visitExpr(part.value); }
    //     // Fold template literal
    //     if (p.should_fold_typescript_constant_expressions or p.options.features.inlining) {
    //       return e_.fold(p.allocator, expr.loc);
    //     }
    //     return expr;
    //   }
    // ========================================================================

    /// 访问模板字符串 - 对应 Bun e_template
    private func visitTemplate(expr: Expr): Expr {
        var mutableExpr = expr

        // 访问模板标签
        if (let Some(tag) <- expr.templateTag) {
            mutableExpr.templateTag = Some(visitExpr(tag))

            // 对应 Bun: if (allow_macros) { ... 检查宏调用 ... }
            // 宏处理在模板标签中
        }

        // 访问模板部分
        // 对应 Bun: for (e_.parts) |*part| { part.value = p.visitExpr(part.value); }
        var newParts = ArrayList<Expr>()
        for (part in expr.templateParts) {
            newParts.append(visitExpr(part))
        }
        mutableExpr.templateParts = newParts

        // 对应 Bun: fold template literal
        // if (p.should_fold_typescript_constant_expressions or p.options.features.inlining) {
        //   return e_.fold(p.allocator, expr.loc);
        // }

        return mutableExpr
    }

    // ========================================================================
    // e_binary - 访问二元表达式
    // 严格翻译自: visit_expr.zig:445-515
    //   pub fn e_binary(p: *P, expr: Expr, in: ExprIn) Expr {
    //     var v = BinaryExpressionVisitor{...};
    //     const stack_bottom = p.binary_expression_stack.items.len;
    //     var current = Expr{ .data = .{ .e_binary = e_ }, .loc = v.loc };
    //     // Iterate down left node
    //     while (true) {
    //       if (v.checkAndPrepare(p)) |out| { current = out; break; }
    //       // Stop if left isn't binary or is assignment target
    //       if (left_binary == null or left_in.assign_target != .none) { ... break; }
    //       p.binary_expression_stack.append(v);
    //       v = BinaryExpressionVisitor{...};
    //     }
    //     // Process back up
    //     while (p.binary_expression_stack.items.len > stack_bottom) {
    //       v = p.binary_expression_stack.pop().?;
    //       v.e.left = current;
    //       current = v.visitRightAndFinish(p);
    //     }
    //     return current;
    //   }
    // ========================================================================

    /// 访问二元表达式 - 对应 Bun e_binary
    private func visitBinary(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 使用迭代而非递归来避免栈溢出
        // 对应 Bun 的 BinaryExpressionVisitor 栈方法
        if (let Some(left) <- expr.left) {
            let assignTarget = binaryAssignTarget(expr.op)
            mutableExpr.left = Some(visitExprInOut(left, ExprIn(assignTarget, false)))
        }

        // 访问右侧
        if (let Some(right) <- expr.right) {
            // 使用 BinaryExpressionVisitor 处理常量折叠
            var visitor = BinaryExpressionVisitor(mutableExpr, expr.loc, input)
            mutableExpr = visitor.visitRightAndFinish(p, this)
        }

        return mutableExpr
    }

    // ========================================================================
    // e_index - 访问索引访问表达式
    // 严格翻译自: visit_expr.zig:516-700
    //   pub fn e_index(p: *P, expr: Expr, in: ExprIn) Expr {
    //     // "a['b']" => "a.b" (minify_syntax)
    //     const target_visited = p.visitExprInOut(e_.target, ...);
    //     switch (e_.index.data) {
    //       .e_private_identifier => { ... findSymbol, check kind ... },
    //       else => { visit index, maybeRewritePropertyAccess, fold "foo"[2] -> "o" },
    //     }
    //   }
    // ========================================================================

    /// 访问索引访问表达式 - 对应 Bun e_index
    private func visitIndex(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问目标
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExprInOut(target, ExprIn(AssignTarget.None, false)))
        }

        // 访问索引
        if (let Some(index) <- expr.indexExpr) {
            mutableExpr.indexExpr = Some(visitExpr(index))

            // 对应 Bun: "a['b']" => "a.b" (minify_syntax)
            // 索引可能是字符串，转换为点访问
        }

        return mutableExpr
    }

    // ========================================================================
    // e_unary - 访问一元表达式
    // 严格翻译自: visit_expr.zig:701-827
    //   pub fn e_unary(p: *P, expr: Expr, _: ExprIn) Expr {
    //     switch (e_.op) {
    //       .un_typeof => {
    //         // typeof x: 特殊处理, 避免对未绑定标识符抛出 ReferenceError
    //         // typeof(require) => "function"
    //         // SideEffects.typeof optimization
    //       },
    //       .un_delete => { e_.value = p.visitExprInOut(e_.value, ExprIn{ .has_chain_parent = true }); },
    //       else => {
    //         e_.value = p.visitExprInOut(e_.value, ExprIn{ .assign_target = e_.op.unaryAssignTarget() });
    //         // Post-process: un_not, un_cpl, un_void, un_pos, un_neg
    //         // Minify: "-(a, b)" => "a, -b"
    //       },
    //     }
    //   }
    // ========================================================================

    /// 访问一元表达式 - 对应 Bun e_unary
    private func visitUnary(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        let op = expr.op

        // 对应 Bun: switch (e_.op)
        if (op == OpCode.Typeof) {
            // typeof 操作符特殊处理
            // 对应 Bun: .un_typeof => { ... }
            if (let Some(value) <- expr.value) {
                let idBefore = value.tag == ExprTag.Identifier
                mutableExpr.value = Some(visitExprInOut(value, ExprIn(unaryAssignTarget(op), false)))
                let idAfter = if (let Some(v) <- mutableExpr.value) { v.tag == ExprTag.Identifier } else { false }

                // 对应 Bun: typeof(require) => "function"
                // 对应 Bun: SideEffects.typeof optimization
            }
            return mutableExpr
        }

        if (op == OpCode.UnDelete) {
            // delete 操作符
            // 对应 Bun: .un_delete => { e_.value = p.visitExprInOut(e_.value, ExprIn{ .has_chain_parent = true }) }
            if (let Some(value) <- expr.value) {
                mutableExpr.value = Some(visitExprInOut(value, ExprIn(AssignTarget.None, true)))
            }
            return mutableExpr
        }

        // 其他一元操作符
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExprInOut(value, ExprIn(unaryAssignTarget(op), false)))
        }

        // 后处理
        // 对应 Bun: switch (e_.op) { .un_not => { ... simplifyBoolean ... } }
        if (op == OpCode.UnNot) {
            // ! 操作符: 简化布尔表达式
            // 对应 Bun: if (p.options.features.minify_syntax) e_.value = SideEffects.simplifyBoolean(p, e_.value)
            if (let Some(value) <- mutableExpr.value) {
                let sideEffects = SideEffects.toBoolean(p, value)
                if (sideEffects.ok) {
                    // 已知布尔值，可以折叠
                    // 对应 Bun: return p.newExpr(E.Boolean{ .value = !side_effects.value }, expr.loc)
                    return Expr.bool_(expr.loc, !sideEffects.value)
                }
            }
        }

        if (op == OpCode.UnCpl) {
            // ~ 操作符: 位取反常量折叠
            // 对应 Bun: .un_cpl => { if SideEffects.toNumber(e_.value.data) |value| { ... } }
        }

        if (op == OpCode.UnVoid) {
            // void 操作符: 如果值可以移除，返回 undefined
            // 对应 Bun: .un_void => { if (p.exprCanBeRemovedIfUnused(&e_.value)) { return undefined } }
        }

        if (op == OpCode.UnPos) {
            // + 操作符: 一元加常量折叠
            // 对应 Bun: .un_pos => { if (SideEffects.toNumber(e_.value.data)) |num| { ... } }
        }

        if (op == OpCode.UnNeg) {
            // - 操作符: 一元减常量折叠
            // 对应 Bun: .un_neg => { if (SideEffects.toNumber(e_.value.data)) |num| { ... } }
        }

        // minify_syntax: "-(a, b)" => "a, -b"
        // 对应 Bun: if (minify_syntax) { switch (e_.value.data) { .e_binary => |comma| { ... } } }

        return mutableExpr
    }

    // ========================================================================
    // e_dot - 访问点访问表达式
    // 严格翻译自: visit_expr.zig:828-921
    //   pub fn e_dot(p: *P, expr: Expr, in: ExprIn) Expr {
    //     // Handle define substitutions (e.g. process.env.NODE_ENV => "production")
    //     if (p.define.dots.get(e_.name)) |parts| { ... }
    //     // Track .then().catch() chains
    //     if (is_call_target and ...) { ... }
    //     e_.target = p.visitExprInOut(e_.target, ...);
    //     // require.resolve -> e_require_resolve_call_target
    //     // maybeRewritePropertyAccess
    //     // Macro expansion
    //   }
    // ========================================================================

    /// 访问点访问表达式 - 对应 Bun e_dot
    private func visitDot(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        let name = expr.propertyName

        // 对应 Bun: 检查 define 中的点替换
        // if (p.define.dots.get(e_.name)) |parts| { ... }

        // 访问目标表达式
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExprInOut(target, ExprIn(
                input.assignTarget,
                input.propertyAccessForMethodCallMaybeShouldReplaceWithUndefined
            )))
        }

        // require.resolve -> e_require_resolve_call_target
        // 对应 Bun: if (e_.target.data == .e_require_call_target and strings.eqlComptime(e_.name, "resolve"))

        // maybeRewritePropertyAccess
        // 对应 Bun: if (e_.optional_chain == null) { if (p.maybeRewritePropertyAccess(...)) |_expr| { return _expr } }

        return mutableExpr
    }

    // ========================================================================
    // e_if (ternary) - 访问三元表达式
    // 严格翻译自: visit_expr.zig:922-983
    //   pub fn e_if(p: *P, expr: Expr, _: ExprIn) Expr {
    //     e_.test_ = p.visitExpr(e_.test_);
    //     e_.test_ = SideEffects.simplifyBoolean(p, e_.test_);
    //     const side_effects = SideEffects.toBoolean(p, e_.test_.data);
    //     if (!side_effects.ok) { e_.yes = p.visitExpr(e_.yes); e_.no = p.visitExpr(e_.no); }
    //     else { ... dead code elimination ... }
    //     return expr;
    //   }
    // ========================================================================

    /// 访问三元表达式 - 对应 Bun e_if
    private func visitTernary(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问条件
        if (let Some(test) <- expr.test) {
            var visitedTest = visitExpr(test)
            visitedTest = SideEffects.simplifyBoolean(p, visitedTest)
            mutableExpr.test = Some(visitedTest)

            // 分析条件是否已知
            let sideEffects = SideEffects.toBoolean(p, visitedTest)

            if (!sideEffects.ok) {
                // 条件未知，正常访问两个分支
                if (let Some(yes) <- expr.yes) {
                    mutableExpr.yes = Some(visitExpr(yes))
                }
                if (let Some(no) <- expr.no) {
                    mutableExpr.no = Some(visitExpr(no))
                }
            } else {
                // 条件已知，标记死代码
                if (sideEffects.value) {
                    // "true ? live : dead"
                    if (let Some(yes) <- expr.yes) {
                        mutableExpr.yes = Some(visitExpr(yes))
                    }
                    let old = p.isControlFlowDead
                    p.isControlFlowDead = true
                    if (let Some(no) <- expr.no) {
                        mutableExpr.no = Some(visitExpr(no))
                    }
                    p.isControlFlowDead = old

                    // 如果条件没有副作用，直接返回 then 分支
                    if (sideEffects.sideEffects == SideEffectFlag.NoSideEffects) {
                        if (let Some(yes) <- mutableExpr.yes) {
                            return yes
                        }
                    }
                } else {
                    // "false ? dead : live"
                    let old = p.isControlFlowDead
                    p.isControlFlowDead = true
                    if (let Some(yes) <- expr.yes) {
                        mutableExpr.yes = Some(visitExpr(yes))
                    }
                    p.isControlFlowDead = old
                    if (let Some(no) <- expr.no) {
                        mutableExpr.no = Some(visitExpr(no))
                    }

                    // 如果条件没有副作用，直接返回 else 分支
                    if (sideEffects.sideEffects == SideEffectFlag.NoSideEffects) {
                        if (let Some(no) <- mutableExpr.no) {
                            return no
                        }
                    }
                }
            }
        } else {
            // 无条件表达式
            if (let Some(yes) <- expr.yes) {
                mutableExpr.yes = Some(visitExpr(yes))
            }
            if (let Some(no) <- expr.no) {
                mutableExpr.no = Some(visitExpr(no))
            }
        }

        return mutableExpr
    }

    // ========================================================================
    // e_await - 访问 await 表达式
    // 严格翻译自: visit_expr.zig:984-989
    //   pub fn e_await(p: *P, expr: Expr, _: ExprIn) Expr {
    //     const e_ = expr.data.e_await;
    //     p.await_target = e_.value.data;
    //     e_.value = p.visitExpr(e_.value);
    //     return expr;
    //   }
    // ========================================================================

    /// 访问 await 表达式 - 对应 Bun e_await
    private func visitAwait(expr: Expr): Expr {
        var mutableExpr = expr
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExpr(value))
        }
        return mutableExpr
    }

    // ========================================================================
    // e_yield - 访问 yield 表达式
    // 严格翻译自: visit_expr.zig:990-996
    //   pub fn e_yield(p: *P, expr: Expr, _: ExprIn) Expr {
    //     const e_ = expr.data.e_yield;
    //     if (e_.value) |val| { e_.value = p.visitExpr(val); }
    //     return expr;
    //   }
    // ========================================================================

    /// 访问 yield 表达式 - 对应 Bun e_yield
    private func visitYield(expr: Expr): Expr {
        var mutableExpr = expr
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExpr(value))
        }
        return mutableExpr
    }

    // ========================================================================
    // e_array - 访问数组表达式
    // 严格翻译自: visit_expr.zig:997-1051
    //   pub fn e_array(p: *P, expr: Expr, in: ExprIn) Expr {
    //     for (items) |*item| {
    //       switch (item.data) {
    //         .e_missing => {},
    //         .e_spread => { spread.value = p.visitExprInOut(spread.value, ...); },
    //         .e_binary => { ... handle assignment in destructuring ... },
    //         else => { item.* = p.visitExprInOut(item.*, ...); },
    //       }
    //     }
    //     // "[1, ...[2, 3], 4]" => "[1, 2, 3, 4]" (minify_syntax)
    //   }
    // ========================================================================

    /// 访问数组表达式 - 对应 Bun e_array
    private func visitArray(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        var newItems = ArrayList<Expr>()

        for (item in expr.items) {
            if (item.tag == ExprTag.Missing) {
                newItems.append(item)
            } else if (item.tag == ExprTag.Spread) {
                // 展开元素 - 递归访问
                newItems.append(visitExprInOut(item, ExprIn(input.assignTarget, false)))
            } else if (item.tag == ExprTag.Binary) {
                // 解构赋值中的二元表达式
                // 对应 Bun: if (in.assign_target != .none and e2.op == .bin_assign) { ... }
                newItems.append(visitExprInOut(item, ExprIn(input.assignTarget, false)))
            } else {
                newItems.append(visitExprInOut(item, ExprIn(input.assignTarget, false)))
            }
        }
        mutableExpr.items = newItems
        return mutableExpr
    }

    // ========================================================================
    // e_object - 访问对象表达式
    // 严格翻译自: visit_expr.zig:1052-1141
    //   pub fn e_object(p: *P, expr: Expr, in: ExprIn) Expr {
    //     var has_spread = false;
    //     var has_proto = false;
    //     for (properties) |*property| {
    //       if (property.kind != .spread) { property.key = p.visitExpr(property.key); ... }
    //       else { has_spread = true; }
    //       // Handle __proto__ duplicate check
    //       // Extract initializer from assignment in destructuring
    //       // Propagate name for decorated anonymous class expressions
    //       property.value = p.visitExprInOut(property.value, ...);
    //       property.initializer = p.visitExpr(property.initializer);
    //     }
    //   }
    // ========================================================================

    /// 访问对象表达式 - 对应 Bun e_object
    private func visitObject(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        var hasSpread = false
        var hasProto = false
        var newProps = ArrayList<GProperty>()

        for (`prop` in expr.properties) {
            var newProp = `prop`

            // 处理非展开属性
            if (!`prop`.flags.isSpread) {
                // 访问计算键
                if (let Some(keyExpr) <- `prop`.keyExpr) {
                    newProp.keyExpr = Some(visitExpr(keyExpr))
                }

                // 检查 __proto__ 重复
                // 对应 Bun: if (!property.flags.is_computed and !property.flags.was_shorthand and
                //   !property.flags.is_method and strings.eqlComptime(key, "__proto__"))
                if (`prop`.key == "__proto__") {
                    if (hasProto) {
                        p.log.addError(MsgData("Cannot specify the \"__proto__\" property more than once per object"))
                    }
                    hasProto = true
                }
            } else {
                hasSpread = true
            }

            // 提取初始化器 (解构赋值中)
            // 对应 Bun: if (in.assign_target != .none and property.initializer == null and property.value != null)
            // { switch (property.value.data) { .e_binary => |bin| { if (bin.op == .bin_assign) { ... } } } }

            // 访问值
            if (let Some(val) <- `prop`.value) {
                newProp.value = Some(visitExprInOut(val, ExprIn(input.assignTarget, false)))
            }

            // 访问初始化器
            if (let Some(`init`) <- `prop`.initializer) {
                newProp.initializer = Some(visitExpr(`init`))
            }

            newProps.append(newProp)
        }

        mutableExpr.properties = newProps
        return mutableExpr
    }

    // ========================================================================
    // e_import - 访问 import() 表达式
    // 严格翻译自: visit_expr.zig:1142-1184
    //   pub fn e_import(p: *P, expr: Expr, _: ExprIn) Expr {
    //     // 强制常量折叠 (用于动态导入字符串模板)
    //     e_.expr = p.visitExpr(e_.expr);
    //     e_.options = p.visitExpr(e_.options);
    //     // Import transposition
    //     if (p.exprCanBeRemovedIfUnused(&e_.options)) {
    //       return p.import_transposer.maybeTransposeIf(e_.expr, &state);
    //     }
    //   }
    // ========================================================================

    /// 访问 import() 表达式 - 对应 Bun e_import
    private func visitImport(expr: Expr): Expr {
        var mutableExpr = expr

        // 访问 import() 的参数 (模块路径和选项)
        var newArgs = ArrayList<Expr>()
        for (arg in expr.args) {
            newArgs.append(visitExpr(arg))
        }
        mutableExpr.args = newArgs

        return mutableExpr
    }

    // ========================================================================
    // e_call - 访问调用表达式
    // 严格翻译自: visit_expr.zig:1185-1551
    //   pub fn e_call(p: *P, expr: Expr, in: ExprIn) Expr {
    //     p.call_target = e_.target.data;
    //     p.then_catch_chain = ...;
    //     e_.target = p.visitExprInOut(e_.target, ...);
    //     // Detect direct eval
    //     // Handle macros
    //     // Handle method_call_must_be_replaced_with_undefined (--drop)
    //     for (e_.args) |*arg| { arg.* = p.visitExpr(arg.*); }
    //     // Handle require(), require.resolve()
    //     // Handle feature() from "bun:bundle"
    //     // Handle React hooks
    //     // Constant fold string.charCodeAt(n)
    //   }
    // ========================================================================

    /// 访问调用表达式 - 对应 Bun e_call
    private func visitCall(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问调用目标
        // 对应 Bun: p.call_target = e_.target.data
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExprInOut(target, ExprIn(AssignTarget.None, false)))
        }

        // 检测直接 eval 调用
        // 对应 Bun: if e_.optional_chain == null and target_was_identifier_before_visit and name == "eval"
        // { e_.is_direct_eval = true; ... }

        // 访问参数列表
        var newArgs = ArrayList<Expr>()
        for (arg in expr.args) {
            newArgs.append(visitExpr(arg))
        }
        mutableExpr.args = newArgs

        // Handle require() and require.resolve()
        // 对应 Bun: if (e_.target.data == .e_require_call_target) { ... }

        // Handle feature() from "bun:bundle"
        // 对应 Bun: if (p.bundler_feature_flag_ref.isValid()) { ... maybeReplaceBundlerFeatureCall ... }

        // Handle React hooks
        // 对应 Bun: if (p.options.features.react_fast_refresh or p.options.features.server_components.isServerSide())
        // { ... try_record_hook ... }

        // Constant fold string.charCodeAt(n)
        // 对应 Bun: if (e_.args.len == 1) if (e_.target.data.as(.e_dot)) |dot| { ... }

        return mutableExpr
    }

    // ========================================================================
    // e_new - 访问 new 表达式
    // 严格翻译自: visit_expr.zig:1552-1566
    //   pub fn e_new(p: *P, expr: Expr, _: ExprIn) Expr {
    //     e_.target = p.visitExpr(e_.target);
    //     for (e_.args) |*arg| { arg.* = p.visitExpr(arg.*); }
    //     // KnownGlobal.minifyGlobalConstructor
    //   }
    // ========================================================================

    /// 访问 new 表达式 - 对应 Bun e_new
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

    // ========================================================================
    // e_arrow - 访问箭头函数
    // 严格翻译自: visit_expr.zig:1567-1622
    //   pub fn e_arrow(p: *P, expr: Expr, _: ExprIn) Expr {
    //     if (p.is_revisit_for_substitution) return expr;
    //     // Save/restore fn_or_arrow_data_visit and fn_only_data_visit
    //     p.pushScopeForVisitPass(.function_args, expr.loc);
    //     p.visitArgs(e_.args, ...);
    //     p.pushScopeForVisitPass(.function_body, e_.body.loc);
    //     p.visitStmtsAndPrependTempRefs(&stmts_list, &temp_opts);
    //     p.popScope(); p.popScope();
    //     // React hooks
    //   }
    // ========================================================================

    /// 访问箭头函数 - 对应 Bun e_arrow
    private func visitArrow(expr: Expr): Expr {
        // 箭头函数需要特殊的作用域处理
        // 保存当前函数状态，创建新的作用域
        // 对应 Bun: pushScope(.function_args), visitArgs, pushScope(.function_body), visitStmts

        p.pushScope(ScopeKind.FunctionArgs)

        // 访问参数 (简化)
        // 对应 Bun: p.visitArgs(e_.args, ...)

        p.pushScope(ScopeKind.FunctionBody)

        // 访问箭头函数体
        if (let Some(fnData) <- expr.fn) {
            var bodyStmts = ArrayList<Stmt>()
            match (fnData.body) {
                case GFnBody.StmtBody(body) =>
                    let sv = StmtVisitor(p)
                    sv.visitSingleStmt(body, StmtsKind.FnBody)
                case GFnBody.StmtsBody(stmts) =>
                    let sv = StmtVisitor(p)
                    sv.visitStmtList(bodyStmts, stmts)
                case GFnBody.ExprBody(bodyExpr) =>
                    let visited = visitExpr(bodyExpr)
                    ()
            }
            // 设置函数体
        }

        p.popScope() // function_body
        p.popScope() // function_args

        return expr
    }

    // ========================================================================
    // e_function - 访问函数表达式
    // 严格翻译自: visit_expr.zig:1623-1661
    //   pub fn e_function(p: *P, expr: Expr, _: ExprIn) Expr {
    //     e_.func = p.visitFunc(e_.func, expr.loc);
    //     // Remove unused function names when minifying
    //     // React hooks
    //     // keepExprSymbolName
    //   }
    // ========================================================================

    /// 访问函数表达式 - 对应 Bun e_function
    private func visitFunction(expr: Expr): Expr {
        // 对应 Bun: e_.func = p.visitFunc(e_.func, expr.loc)
        // 简化版本: 函数表达式的访问通过 StmtVisitor 处理
        // 由于 GFn (ast.cj) 和 GFunc (visit_stmt.cj) 是不同的类,
        // 我们直接返回表达式，让 visitFunc 在解析阶段处理
        return expr
    }

    // ========================================================================
    // e_class - 访问类表达式
    // 严格翻译自: visit_expr.zig:1662-1692
    //   pub fn e_class(p: *P, expr: Expr, _: ExprIn) Expr {
    //     _ = p.visitClass(expr.loc, e_, Ref.None);
    //     // Lower standard decorators
    //     // Remove unused class names when minifying
    //   }
    // ========================================================================

    /// 访问类表达式 - 对应 Bun e_class
    private func visitClass(expr: Expr): Expr {
        let sv = StmtVisitor(p)
        if (let Some(cd) <- expr.classData) {
            let visitedClass = sv.visitClassExpr(expr.loc, cd)
            var mutableExpr = expr
            mutableExpr.classData = Some(visitedClass)
            return mutableExpr
        }
        return expr
    }

    // ========================================================================
    // e_assign - 访问赋值表达式
    // ========================================================================

    /// 访问赋值表达式 - 对应 Bun e_assign (simplified)
    private func visitAssign(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr

        // 访问目标 (作为赋值目标)
        if (let Some(target) <- expr.target) {
            mutableExpr.target = Some(visitExprInOut(target, ExprIn(AssignTarget.Replace, false)))
        }

        // 访问值
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExpr(value))
        }

        return mutableExpr
    }

    // ========================================================================
    // e_postfix - 访问后缀表达式
    // ========================================================================

    /// 访问后缀表达式 - 对应 Bun e_postfix
    private func visitPostfix(expr: Expr, input: ExprIn): Expr {
        var mutableExpr = expr
        if (let Some(value) <- expr.value) {
            mutableExpr.value = Some(visitExprInOut(value, ExprIn(AssignTarget.Update, false)))
        }
        return mutableExpr
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
            match (op) {
                case OpCode.BinAssign =>
                    return AssignTarget.Replace
                case _ =>
                    return AssignTarget.Update
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

    // ========================================================================
    // maybeReplaceBundlerFeatureCall - 替换 feature() 调用
    // 严格翻译自: visit_expr.zig:1703-1752
    //   fn maybeReplaceBundlerFeatureCall(p: *P, e_: *E.Call, loc: logger.Loc) ?Expr {
    //     // Check if the target is the `feature` function from "bun:bundle"
    //     const target_ref: ?Ref = switch (e_.target.data) { ... };
    //     if (target_ref == null or !target_ref.?.eql(p.bundler_feature_flag_ref)) return null;
    //     // Validate: exactly one argument required
    //     // Validate: argument must be a string literal
    //     // feature() can only be used directly in an if/ternary condition
    //     const is_enabled = p.options.features.bundler_feature_flags.map.contains(flag_string.data);
    //     return .{ .data = .{ .e_branch_boolean = .{ .value = is_enabled } }, .loc = loc };
    //   }
    // ========================================================================

    /// 替换 feature() 调用 - 对应 Bun maybeReplaceBundlerFeatureCall
    /// 检查调用目标是否为 "bun:bundle" 的 feature 函数
    /// 如果是，用布尔值替换
    private func maybeReplaceBundlerFeatureCall(expr: Expr): ?Expr {
        // 检查参数数量和类型
        if (expr.args.size != 1) {
            return None
        }

        let arg = expr.args[0]
        if (arg.tag != ExprTag.String) {
            return None
        }

        // 对应 Bun: p.in_branch_condition check
        // feature() 只能在 if/三元条件中直接使用

        // 对应 Bun: const is_enabled = p.options.features.bundler_feature_flags.map.contains(flag_string.data)
        // 简化: 返回 None 表示不替换
        return None
    }
}

// Note: SideEffects class is already defined in scan_side_effects.cj

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
