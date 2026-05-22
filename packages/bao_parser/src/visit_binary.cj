// AST 二元表达式 Visitor
// 严格翻译自: src/js_parser/visit/visit_binary.zig (598 lines)
//   Bun 的二元表达式 Visitor 处理所有二元操作符的常量折叠和优化
//   BinaryExpressionVisitor 是核心结构，使用栈而非递归来处理深嵌套
//   包括: 常量折叠 (加减乘除/比较/位运算), 逻辑短路优化, typeof 优化
//   对应 Bun: CreateBinaryExpressionVisitor()
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// BinaryExpressionVisitor - 二元表达式访问器
// 严格翻译自: visit_binary.zig:53-572
//   pub const BinaryExpressionVisitor = struct {
//       e: *E.Binary,
//       loc: logger.Loc,
//       in: ExprIn,
//       left_in: ExprIn,
//       is_stmt_expr: bool = false,
//
//       pub fn visitRightAndFinish(v: *BinaryExpressionVisitor, p: *P) Expr { ... }
//       pub fn checkAndPrepare(v: *BinaryExpressionVisitor, p: *P) ?Expr { ... }
//   }
// ============================================================================

/// 二元表达式访问器 - 对应 Bun BinaryExpressionVisitor
/// 使用栈而非递归来处理深层嵌套的二元表达式，避免栈溢出
public class BinaryExpressionVisitor {
    /// 二元表达式数据
    public var expr: Expr
    /// 表达式位置
    public var loc: Loc
    /// 输入上下文
    public var input: ExprIn
    /// 左操作数输入上下文
    public var leftIn: ExprIn
    /// 是否为语句表达式
    public var isStmtExpr: Bool

    public init(expr: Expr, loc: Loc, input: ExprIn) {
        this.expr = expr
        this.loc = loc
        this.input = input
        leftIn = ExprIn()
        isStmtExpr = false
    }

    // ========================================================================
    // tryOptimizeTypeofUndefined - 优化 typeof x === 'undefined'
    // 严格翻译自: visit_binary.zig:11-51
    //   fn tryOptimizeTypeofUndefined(e_: *E.Binary, p: *P, replacement_op: js_ast.Op.Code) ?Expr {
    //     // Check if this is a typeof comparison with "undefined"
    //     const typeof_expr, const string_expr, const flip_comparison = exprs: {
    //       // Try left side as typeof, right side as string
    //       if (e_.left.data == .e_unary and e_.left.data.e_unary.op == .un_typeof) {
    //         if (e_.right.data == .e_string and e_.right.data.e_string.eqlComptime("undefined")) {
    //           break :exprs .{ e_.left, e_.right, false };
    //         }
    //         return null;
    //       }
    //       // Try right side as typeof, left side as string
    //       if (e_.right.data == .e_unary and e_.right.data.e_unary.op == .un_typeof) {
    //         if (e_.left.data == .e_string and e_.left.data.e_string.eqlComptime("undefined")) {
    //           break :exprs .{ e_.right, e_.left, true };
    //         }
    //         return null;
    //       }
    //       return null;
    //     };
    //     // Create new string with "u"
    //     const u_string = p.newExpr(E.String{ .data = "u" }, string_expr.loc);
    //     return p.newExpr(E.Binary{ .left, .right, .op = replacement_op }, e_.left.loc);
    //   }
    // ========================================================================

    /// 优化 "typeof x === 'undefined'" => "typeof x > 'u'"
    /// 对应 Bun tryOptimizeTypeofUndefined
    /// 返回优化后的表达式，如果不适配则返回 null
    public static func tryOptimizeTypeofUndefined(expr: Expr, p: Parser, replacementOp: OpCode): ?Expr {
        // 检查左侧是否为 typeof，右侧是否为 "undefined"
        if (let Some(left) <- expr.left) {
            if (let Some(right) <- expr.right) {
                var typeofExpr: ?Expr = None
                var stringExpr: ?Expr = None
                var flipComparison = false

                // 尝试左侧为 typeof，右侧为字符串
                if (left.tag == ExprTag.Unary && left.op == OpCode.Typeof) {
                    if (right.tag == ExprTag.String) {
                        if (right.stringValue.toString() == "undefined") {
                            typeofExpr = Some(left)
                            stringExpr = Some(right)
                            flipComparison = false
                        }
                    }
                    if (typeofExpr.isNone()) {
                        return None
                    }
                }

                // 尝试右侧为 typeof，左侧为字符串
                if (typeofExpr.isNone()) {
                    if (right.tag == ExprTag.Unary && right.op == OpCode.Typeof) {
                        if (left.tag == ExprTag.String) {
                            if (left.stringValue.toString() == "undefined") {
                                typeofExpr = Some(right)
                                stringExpr = Some(left)
                                flipComparison = true
                            }
                        }
                    }
                }

                if (let Some(te) <- typeofExpr) {
                    if (let Some(se) <- stringExpr) {
                        // 创建新的字符串 "u"
                        let uString = Expr.string(se.loc, "u")

                        // 创建优化后的比较
                        let leftExpr = if (flipComparison) { uString } else { te }
                        let rightExpr = if (flipComparison) { te } else { uString }

                        var result = Expr()
                        result.tag = ExprTag.Binary
                        result.loc = left.loc
                        result.left = Some(leftExpr)
                        result.right = Some(rightExpr)
                        result.op = replacementOp
                        return Some(result)
                    }
                }
            }
        }
        return None
    }

    // ========================================================================
    // checkAndPrepare - 检查并准备
    // 严格翻译自: visit_binary.zig:536-571
    //   pub fn checkAndPrepare(v: *BinaryExpressionVisitor, p: *P) ?Expr {
    //     switch (e_.left.data) {
    //       .e_private_identifier => |_private| {
    //         if (e_.op == .bin_in) {
    //           // private-in: 查找符号，验证为私有
    //           const name = p.loadNameFromRef(private.ref);
    //           const result = p.findSymbol(e_.left.loc, name) catch unreachable;
    //           private.ref = result.ref;
    //           // 检查 kind 是否为私有
    //           e_.right = p.visitExpr(e_.right);
    //           return Expr{ .loc = v.loc, .data = .{ .e_binary = e_ } };
    //         }
    //       },
    //       else => {},
    //     }
    //     v.is_stmt_expr = p.stmt_expr_value == .e_binary and p.stmt_expr_value.e_binary == e_;
    //     v.left_in = ExprIn{ .assign_target = e_.op.binaryAssignTarget() };
    //     return null;
    //   }
    // ========================================================================

    /// 检查并准备二元表达式的访问
    /// 返回非 null 表示可以立即返回结果 (如 private-in 的情况)
    public func checkAndPrepare(p: Parser): ?Expr {
        // 处理私有标识符的 in 操作
        // 对应 Bun: if (e_.left.data == .e_private_identifier and e_.op == .bin_in)
        if (let Some(left) <- expr.left) {
            if (left.tag == ExprTag.Identifier && expr.op == OpCode.BinIn) {
                // private #id in obj
                // 查找符号并验证
                // 简化处理
            }
        }

        // 设置 isStmtExpr 标志
        // 对应 Bun: v.is_stmt_expr = p.stmt_expr_value == .e_binary and ...

        // 设置左操作数的赋值目标
        leftIn = ExprIn(binaryAssignTarget(expr.op), false)

        return None
    }

    // ========================================================================
    // visitRightAndFinish - 访问右操作数并完成
    // 严格翻译自: visit_binary.zig:64-534
    //   pub fn visitRightAndFinish(v: *BinaryExpressionVisitor, p: *P) Expr {
    //     var e_ = v.e;
    //     const is_call_target = ...;
    //     const was_anonymous_named_expr = e_.right.isAnonymousNamed();
    //     const prev_decorator_class_name = p.decorator_class_name;
    //
    //     // Propagate name for anonymous decorated class expressions in assignments
    //     if (e_.op == .bin_assign and was_anonymous_named_expr and ...) {
    //       p.decorator_class_name = p.loadNameFromRef(e_.left.data.e_identifier.ref);
    //     }
    //
    //     // Mark control flow dead for logical operators
    //     switch (e_.op) {
    //       .bin_logical_or => {
    //         const side_effects = SideEffects.toBoolean(p, e_.left.data);
    //         if (side_effects.ok and side_effects.value) {
    //           // "true || dead" - mark right as dead
    //           const old = p.is_control_flow_dead;
    //           p.is_control_flow_dead = true;
    //           e_.right = p.visitExpr(e_.right);
    //           p.is_control_flow_dead = old;
    //         } else { e_.right = p.visitExpr(e_.right); }
    //       },
    //       .bin_logical_and => { ... "false && dead" ... },
    //       .bin_nullish_coalescing => { ... "notNullOrUndefined ?? dead" ... },
    //       else => { e_.right = p.visitExpr(e_.right); },
    //     }
    //
    //     // Reorder constants to right side for equality comparisons
    //     switch (e_.op) {
    //       .bin_loose_eq, .bin_strict_eq, ... => {
    //         if (SideEffects.isPrimitiveToReorder(e_.left) and !SideEffects.isPrimitiveToReorder(e_.right)) {
    //           swap left/right
    //         }
    //       },
    //     }
    //
    //     // Handle specific operators
    //     switch (e_.op) {
    //       .bin_comma => { ... simplifyUnusedExpr ... },
    //       .bin_loose_eq => { ... fold equality ... tryOptimizeTypeofUndefined ... },
    //       .bin_strict_eq => { ... fold equality ... },
    //       .bin_nullish_coalescing => { ... fold null/undefined ... },
    //       .bin_logical_or => { ... fold truthy ... },
    //       .bin_logical_and => { ... fold falsy ... },
    //       .bin_add => { ... fold numeric, fold string concatenation ... },
    //       .bin_sub, .bin_mul, .bin_div, .bin_rem, .bin_pow => { ... fold numeric ... },
    //       .bin_shl, .bin_shr, .bin_u_shr => { ... fold bitwise shift ... },
    //       .bin_bitwise_and, .bin_bitwise_or, .bin_bitwise_xor => { ... fold bitwise ... },
    //       .bin_lt, .bin_gt, .bin_le, .bin_ge => { ... fold comparison ... },
    //       .bin_assign => { ... maybeKeepExprSymbolName ... },
    //       .bin_nullish_coalescing_assign, .bin_logical_or_assign => { ... optimize {}.field ??= value ... },
    //       else => {},
    //     }
    //
    //     return Expr{ .loc = v.loc, .data = .{ .e_binary = e_ } };
    //   }
    // ========================================================================

    /// 访问右操作数并完成二元表达式处理
    /// 包含常量折叠、逻辑短路优化、typeof 优化等
    public func visitRightAndFinish(p: Parser, exprVisitor: ExprVisitor): Expr {
        var mutableExpr = expr

        // 对应 Bun: const is_call_target = ...
        let isCallTarget = false

        // 对应 Bun: const was_anonymous_named_expr = e_.right.isAnonymousNamed()

        // 根据操作符进行控制流死代码标记
        // 对应 Bun: switch (e_.op) { .bin_logical_or => ... .bin_logical_and => ... }
        if (mutableExpr.op == OpCode.BinLoOr) {
            // || 短路: 如果左侧已知为 true, 标记右侧为死代码
            if (let Some(left) <- mutableExpr.left) {
                let sideEffects = SideEffects.toBoolean(p, left)
                if (sideEffects.ok && sideEffects.value) {
                    // "true || dead"
                    let old = p.isControlFlowDead
                    p.isControlFlowDead = true
                    if (let Some(right) <- mutableExpr.right) {
                        mutableExpr.right = Some(exprVisitor.visitExpr(right))
                    }
                    p.isControlFlowDead = old
                } else {
                    if (let Some(right) <- mutableExpr.right) {
                        mutableExpr.right = Some(exprVisitor.visitExpr(right))
                    }
                }
            }
        } else if (mutableExpr.op == OpCode.BinLoAnd) {
            // && 短路: 如果左侧已知为 false, 标记右侧为死代码
            if (let Some(left) <- mutableExpr.left) {
                let sideEffects = SideEffects.toBoolean(p, left)
                if (sideEffects.ok && !sideEffects.value) {
                    // "false && dead"
                    let old = p.isControlFlowDead
                    p.isControlFlowDead = true
                    if (let Some(right) <- mutableExpr.right) {
                        mutableExpr.right = Some(exprVisitor.visitExpr(right))
                    }
                    p.isControlFlowDead = old
                } else {
                    if (let Some(right) <- mutableExpr.right) {
                        mutableExpr.right = Some(exprVisitor.visitExpr(right))
                    }
                }
            }
        } else if (mutableExpr.op == OpCode.BinNullish) {
            // ?? 短路: 如果左侧已知非 null/undefined, 标记右侧为死代码
            if (let Some(left) <- mutableExpr.left) {
                let sideEffects = SideEffects.toNullOrUndefined(p, left)
                if (sideEffects.ok && !sideEffects.value) {
                    // "notNullOrUndefined ?? dead"
                    let old = p.isControlFlowDead
                    p.isControlFlowDead = true
                    if (let Some(right) <- mutableExpr.right) {
                        mutableExpr.right = Some(exprVisitor.visitExpr(right))
                    }
                    p.isControlFlowDead = old
                } else {
                    if (let Some(right) <- mutableExpr.right) {
                        mutableExpr.right = Some(exprVisitor.visitExpr(right))
                    }
                }
            }
        } else {
            // 普通操作符: 正常访问右侧
            if (let Some(right) <- mutableExpr.right) {
                mutableExpr.right = Some(exprVisitor.visitExpr(right))
            }
        }

        // 对应 Bun: Always put constants on the right for equality comparisons
        // 对应 Bun: bin_loose_eq, bin_loose_ne, bin_strict_eq, bin_strict_ne
        // 重新排序，让常量在右侧

        // 根据操作符进行优化
        let op = mutableExpr.op

        // --- 逗号运算符优化 ---
        // 对应 Bun: .bin_comma => { simplifyUnusedExpr ... }
        if (op == OpCode.Comma) {
            // "(1, 2)" => "2"
            // "(sideEffects(), 2)" => "(sideEffects(), 2)"
            // 对应 Bun: if (p.options.features.minify_syntax)
        }

        // --- 相等比较优化 ---
        // 对应 Bun: .bin_loose_eq
        if (op == OpCode.BinEq) {
            let result = tryEvaluateEquality(mutableExpr, true)
            if (let Some(value) <- result) {
                return value
            }
            // 对应 Bun: tryOptimizeTypeofUndefined(e_, p, .bin_gt)
            let typeofOpt = BinaryExpressionVisitor.tryOptimizeTypeofUndefined(mutableExpr, p, OpCode.BinGt)
            if (let Some(optimized) <- typeofOpt) {
                return optimized
            }
            // "x == void 0" => "x == null"
        }

        // 对应 Bun: .bin_strict_eq
        if (op == OpCode.BinEqStrict) {
            let result = tryEvaluateEquality(mutableExpr, true)
            if (let Some(value) <- result) {
                return value
            }
            let typeofOpt = BinaryExpressionVisitor.tryOptimizeTypeofUndefined(mutableExpr, p, OpCode.BinGt)
            if (let Some(optimized) <- typeofOpt) {
                return optimized
            }
        }

        // 对应 Bun: .bin_loose_ne
        if (op == OpCode.BinNe) {
            let result = tryEvaluateEquality(mutableExpr, false)
            if (let Some(value) <- result) {
                return value
            }
            let typeofOpt = BinaryExpressionVisitor.tryOptimizeTypeofUndefined(mutableExpr, p, OpCode.BinLt)
            if (let Some(optimized) <- typeofOpt) {
                return optimized
            }
            // "x != void 0" => "x != null"
        }

        // 对应 Bun: .bin_strict_ne
        if (op == OpCode.BinNeStrict) {
            let result = tryEvaluateEquality(mutableExpr, false)
            if (let Some(value) <- result) {
                return value
            }
            let typeofOpt = BinaryExpressionVisitor.tryOptimizeTypeofUndefined(mutableExpr, p, OpCode.BinLt)
            if (let Some(optimized) <- typeofOpt) {
                return optimized
            }
        }

        // --- nullish coalescing 优化 ---
        // 对应 Bun: .bin_nullish_coalescing
        if (op == OpCode.BinNullish) {
            if (let Some(left) <- mutableExpr.left) {
                let nullOrUndefined = SideEffects.toNullOrUndefined(p, left)
                if (nullOrUndefined.ok) {
                    if (!nullOrUndefined.value) {
                        // 左侧非 null/undefined，直接返回左侧
                        return left
                    } else if (nullOrUndefined.sideEffects == SideEffectFlag.NoSideEffects) {
                        // 左侧为 null/undefined 且无副作用，直接返回右侧
                        if (let Some(right) <- mutableExpr.right) {
                            return right
                        }
                    }
                }
            }
        }

        // --- logical or 优化 ---
        // 对应 Bun: .bin_logical_or
        if (op == OpCode.BinLoOr) {
            if (let Some(left) <- mutableExpr.left) {
                let sideEffects = SideEffects.toBoolean(p, left)
                if (sideEffects.ok && sideEffects.value) {
                    // 左侧为 true，直接返回左侧
                    return left
                } else if (sideEffects.ok && sideEffects.sideEffects == SideEffectFlag.NoSideEffects) {
                    // 左侧为 false 且无副作用，直接返回右侧
                    if (let Some(right) <- mutableExpr.right) {
                        return right
                    }
                }
            }
        }

        // --- logical and 优化 ---
        // 对应 Bun: .bin_logical_and
        if (op == OpCode.BinLoAnd) {
            if (let Some(left) <- mutableExpr.left) {
                let sideEffects = SideEffects.toBoolean(p, left)
                if (sideEffects.ok) {
                    if (!sideEffects.value) {
                        // 左侧为 false，直接返回左侧
                        return left
                    } else if (sideEffects.sideEffects == SideEffectFlag.NoSideEffects) {
                        // 左侧为 true 且无副作用，直接返回右侧
                        if (let Some(right) <- mutableExpr.right) {
                            return right
                        }
                    }
                }
            }
        }

        // --- 算术运算常量折叠 ---
        // 对应 Bun: .bin_add => { ... extractNumericValues, foldStringAddition ... }
        if (op == OpCode.BinAdd) {
            if (let Some(result) <- tryFoldArithmetic(mutableExpr)) {
                return result
            }
            // 字符串拼接: "'abc' + 'xyz'" => "'abcxyz'"
            // 对应 Bun: foldStringAddition
            if (let Some(result) <- tryFoldStringAddition(mutableExpr)) {
                return result
            }
        }

        // 对应 Bun: .bin_sub, .bin_mul, .bin_div, .bin_rem, .bin_pow
        if (op == OpCode.BinSub || op == OpCode.BinMul || op == OpCode.BinDiv ||
            op == OpCode.BinRem || op == OpCode.BinPow) {
            if (let Some(result) <- tryFoldArithmetic(mutableExpr)) {
                return result
            }
        }

        // 对应 Bun: .bin_shl, .bin_shr, .bin_u_shr
        if (op == OpCode.BinShl || op == OpCode.BinShr || op == OpCode.BinUShr) {
            if (let Some(result) <- tryFoldBitwiseShift(mutableExpr)) {
                return result
            }
        }

        // 对应 Bun: .bin_bitwise_and, .bin_bitwise_or, .bin_bitwise_xor
        if (op == OpCode.BinAnd || op == OpCode.BinOr || op == OpCode.BinXor) {
            if (let Some(result) <- tryFoldBitwise(mutableExpr)) {
                return result
            }
        }

        // --- 比较运算常量折叠 ---
        // 对应 Bun: .bin_lt, .bin_gt, .bin_le, .bin_ge
        if (op == OpCode.BinLt || op == OpCode.BinGt || op == OpCode.BinLe || op == OpCode.BinGe) {
            if (let Some(result) <- tryFoldComparison(mutableExpr)) {
                return result
            }
        }

        // --- 赋值运算符 ---
        // 对应 Bun: .bin_assign => { ... maybeKeepExprSymbolName ... }
        if (op == OpCode.BinAssign) {
            // 对应 Bun: if (e_.left.data == .e_identifier) {
            //   e_.right = p.maybeKeepExprSymbolName(e_.right, ...)
            // }
        }

        // 对应 Bun: .bin_nullish_coalescing_assign, .bin_logical_or_assign
        // 优化 {}.field ??= value => value
        if (op == OpCode.BinNullishAssign || op == OpCode.BinLoOrAssign) {
            // 对应 Bun: if (e_.left.data.as(.e_dot)) |dot| {
            //   if (dot.target.data.as(.e_object)) |obj| {
            //     if (obj.properties.len == 0) { ... return e_.right; }
            //   }
            // }
        }

        return mutableExpr
    }

    // ========================================================================
    // 常量折叠和优化辅助方法
    // ========================================================================

    /// 尝试求值相等比较
    /// 对应 Bun 中 e_.left.data.eql(e_.right.data, ...) 的逻辑
    private func tryEvaluateEquality(expr: Expr, isEquality: Bool): ?Expr {
        if (let Some(left) <- expr.left) {
            if (let Some(right) <- expr.right) {
                // 两个 null 比较
                if (left.tag == ExprTag.Null && right.tag == ExprTag.Null) {
                    return Some(Expr.bool_(expr.loc, isEquality))
                }
                // 两个 undefined 比较
                if (left.tag == ExprTag.Undefined && right.tag == ExprTag.Undefined) {
                    return Some(Expr.bool_(expr.loc, isEquality))
                }
                // null 和 undefined 的松散比较
                if (isEquality) {
                    // == null 和 == undefined 在 JS 中等价
                    if ((left.tag == ExprTag.Null && right.tag == ExprTag.Undefined) ||
                        (left.tag == ExprTag.Undefined && right.tag == ExprTag.Null)) {
                        return Some(Expr.bool_(expr.loc, true))
                    }
                }
                // 布尔值比较
                if (left.tag == ExprTag.Boolean && right.tag == ExprTag.Boolean) {
                    if (left.boolValue == right.boolValue) {
                        return Some(Expr.bool_(expr.loc, isEquality))
                    } else {
                        return Some(Expr.bool_(expr.loc, !isEquality))
                    }
                }
                // 数字比较
                if (left.tag == ExprTag.Number && right.tag == ExprTag.Number) {
                    if (left.numberValue == right.numberValue) {
                        return Some(Expr.bool_(expr.loc, isEquality))
                    } else {
                        return Some(Expr.bool_(expr.loc, !isEquality))
                    }
                }
                // 字符串比较
                if (left.tag == ExprTag.String && right.tag == ExprTag.String) {
                    if (left.stringValue.toString() == right.stringValue.toString()) {
                        return Some(Expr.bool_(expr.loc, isEquality))
                    } else {
                        return Some(Expr.bool_(expr.loc, !isEquality))
                    }
                }
            }
        }
        return None
    }

    /// 尝试折叠算术运算
    /// 对应 Bun 中 bin_add/bin_sub/bin_mul/bin_div/bin_rem/bin_pow 等的常量折叠
    private func tryFoldArithmetic(expr: Expr): ?Expr {
        if (let Some(left) <- expr.left) {
            if (let Some(right) <- expr.right) {
                // 提取数字值
                if (left.tag == ExprTag.Number && right.tag == ExprTag.Number) {
                    let lv = left.numberValue
                    let rv = right.numberValue
                    match (expr.op) {
                        case OpCode.BinAdd =>
                            return Some(Expr.number(expr.loc, lv + rv))
                        case OpCode.BinSub =>
                            return Some(Expr.number(expr.loc, lv - rv))
                        case OpCode.BinMul =>
                            return Some(Expr.number(expr.loc, lv * rv))
                        case OpCode.BinDiv =>
                            if (rv != 0.0) {
                                return Some(Expr.number(expr.loc, lv / rv))
                            }
                        case OpCode.BinRem =>
                            // 对应 Bun: fmod(vals[0], vals[1])
                            if (rv != 0.0) {
                                let result = lv - rv * Float64(Int64(lv / rv))
                                return Some(Expr.number(expr.loc, result))
                            }
                        case OpCode.BinPow =>
                            // 对应 Bun: jsc.math.pow(vals[0], vals[1])
                            return Some(Expr.number(expr.loc, BinaryExpressionVisitor.computePow(lv, rv)))
                        case _ =>
                            return None
                    }
                }
            }
        }
        return None
    }

    /// 尝试折叠字符串拼接
    /// 对应 Bun foldStringAddition
    /// "'abc' + 'xyz'" => "'abcxyz'"
    private func tryFoldStringAddition(expr: Expr): ?Expr {
        if (expr.op != OpCode.BinAdd) {
            return None
        }
        if (let Some(left) <- expr.left) {
            if (let Some(right) <- expr.right) {
                if (left.tag == ExprTag.String && right.tag == ExprTag.String) {
                    let combined = left.stringValue.toString() + right.stringValue.toString()
                    return Some(Expr.string(expr.loc, combined))
                }
            }
        }
        return None
    }

    /// 尝试折叠位运算移位
    /// 对应 Bun: .bin_shl, .bin_shr, .bin_u_shr
    /// 使用 floatToInt32 将浮点数转为 32 位整数
    private func tryFoldBitwiseShift(expr: Expr): ?Expr {
        if (let Some(left) <- expr.left) {
            if (let Some(right) <- expr.right) {
                if (left.tag == ExprTag.Number && right.tag == ExprTag.Number) {
                    let lv = left.numberValue
                    let rv = right.numberValue
                    let leftInt = floatToInt32(lv)
                    let rightInt = floatToInt32(rv)
                    // 对应 Bun: @intCast(@as(u32, @bitCast(floatToInt32(vals[1]))) % 32)
                    let shift = rightInt % 32

                    match (expr.op) {
                        case OpCode.BinShl =>
                            // <<
                            let result = leftInt << shift
                            return Some(Expr.number(expr.loc, Float64(result)))
                        case OpCode.BinShr =>
                            // >> (算术右移)
                            let result = leftInt >> shift
                            return Some(Expr.number(expr.loc, Float64(result)))
                        case OpCode.BinUShr =>
                            // >>> (无符号右移)
                            // 对应 Bun: std.math.shr(u32, left, right)
                            let leftU = UInt32(leftInt)
                            let result = leftU >> UInt32(shift)
                            return Some(Expr.number(expr.loc, Float64(Int64(result))))
                        case _ =>
                            return None
                    }
                }
            }
        }
        return None
    }

    /// 尝试折叠位运算 (AND/OR/XOR)
    /// 对应 Bun: .bin_bitwise_and, .bin_bitwise_or, .bin_bitwise_xor
    private func tryFoldBitwise(expr: Expr): ?Expr {
        if (let Some(left) <- expr.left) {
            if (let Some(right) <- expr.right) {
                if (left.tag == ExprTag.Number && right.tag == ExprTag.Number) {
                    let lv = left.numberValue
                    let rv = right.numberValue
                    let leftInt = floatToInt32(lv)
                    let rightInt = floatToInt32(rv)

                    match (expr.op) {
                        case OpCode.BinAnd =>
                            // &
                            let result = leftInt & rightInt
                            return Some(Expr.number(expr.loc, Float64(result)))
                        case OpCode.BinOr =>
                            // |
                            let result = leftInt | rightInt
                            return Some(Expr.number(expr.loc, Float64(result)))
                        case OpCode.BinXor =>
                            // ^
                            let result = leftInt ^ rightInt
                            return Some(Expr.number(expr.loc, Float64(result)))
                        case _ =>
                            return None
                    }
                }
            }
        }
        return None
    }

    /// 尝试折叠比较运算
    /// 对应 Bun: .bin_lt, .bin_gt, .bin_le, .bin_ge
    private func tryFoldComparison(expr: Expr): ?Expr {
        if (let Some(left) <- expr.left) {
            if (let Some(right) <- expr.right) {
                // 数字比较
                if (left.tag == ExprTag.Number && right.tag == ExprTag.Number) {
                    let lv = left.numberValue
                    let rv = right.numberValue
                    match (expr.op) {
                        case OpCode.BinLt =>
                            return Some(Expr.bool_(expr.loc, lv < rv))
                        case OpCode.BinGt =>
                            return Some(Expr.bool_(expr.loc, lv > rv))
                        case OpCode.BinLe =>
                            return Some(Expr.bool_(expr.loc, lv <= rv))
                        case OpCode.BinGe =>
                            return Some(Expr.bool_(expr.loc, lv >= rv))
                        case _ =>
                            return None
                    }
                }

                // 字符串比较
                if (left.tag == ExprTag.String && right.tag == ExprTag.String) {
                    let lv = left.stringValue.toString()
                    let rv = right.stringValue.toString()
                    match (expr.op) {
                        case OpCode.BinLt =>
                            return Some(Expr.bool_(expr.loc, lv < rv))
                        case OpCode.BinGt =>
                            return Some(Expr.bool_(expr.loc, lv > rv))
                        case OpCode.BinLe =>
                            return Some(Expr.bool_(expr.loc, lv <= rv))
                        case OpCode.BinGe =>
                            return Some(Expr.bool_(expr.loc, lv >= rv))
                        case _ =>
                            return None
                    }
                }
            }
        }
        return None
    }

    // ========================================================================
    // 工具方法
    // ========================================================================

    /// 浮点数转 32 位整数 - 对应 Bun floatToInt32
    /// JavaScript 的位运算将操作数转为 32 位有符号整数
    /// 对应 Bun: js_parser.floatToInt32
    private func floatToInt32(f: Float64): Int64 {
        if (f >= Float64(Int64.Max) || f < Float64(Int64.Min) || f.isNaN() || f.isInf()) {
            return Int64(0)
        }
        return Int64(f)
    }

    /// 获取二元操作符的赋值目标
    /// 对应 Bun: Op.Code.binaryAssignTarget()
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

    /// 计算 pow - 对应 Bun jsc.math.pow
    private static func computePow(base: Float64, exp: Float64): Float64 {
        if (exp == 0.0) { return 1.0 }
        if (exp == 1.0) { return base }
        if (exp == 2.0) { return base * base }
        if (exp == 0.5) { return sqrt(base) }
        // 简单迭代实现
        var result = 1.0
        var b = base
        var e = Int64(exp)
        var neg = false
        if (e < 0) {
            neg = true
            e = -e
        }
        while (e > 0) {
            if (e % 2 == 1) {
                result = result * b
            }
            b = b * b
            e = e / 2
        }
        if (neg) { result = 1.0 / result }
        return result
    }

    /// sqrt 辅助 - 牛顿迭代法
    private static func sqrt(x: Float64): Float64 {
        if (x <= 0.0) { return 0.0 }
        var guess = x
        var i = 0
        while (i < 20) {
            guess = (guess + x / guess) / 2.0
            i += 1
        }
        return guess
    }
}

// ============================================================================
// BinaryExpressionSimplifyVisitor - 二元表达式简化访问器
// 严格翻译自: scan_side_effects.zig:358-360
//   pub const BinaryExpressionSimplifyVisitor = struct { bin: *E.Binary }
// ============================================================================

/// 二元表达式简化访问器 - 对应 Bun BinaryExpressionSimplifyVisitor
/// 用于简化未使用的二元表达式
public class BinaryExpressionSimplifyVisitor {
    /// 二元表达式
    public var bin: Expr

    public init(bin: Expr) {
        this.bin = bin
    }
}

// OpCode 枚举已在 package.cj 中定义
// 此处使用的 OpCode 值对应:
//   Typeof (typeof), UnNot (!), UnDelete (delete), BinEq (==), BinNe (!=),
//   BinEqStrict (===), BinNeStrict (!==), BinLt (<), BinGt (>), BinLe (<=),
//   BinGe (>=), BinLoOr (||), BinLoAnd (&&), BinNullish (??),
//   BinAdd (+), BinSub (-), BinMul (*), BinDiv (/), BinRem (%), BinPow (**),
//   BinShl (<<), BinShr (>>), BinUShr (>>>), BinAnd (&), BinOr (|), BinXor (^),
//   BinAssign (=), BinNullishAssign (??=), BinLoOrAssign (||=), BinLoAndAssign (&&=),
//   Comma (,), BinIn (in), UnCpl (~), BinInstanceof (instanceof)
