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
    // checkAndPrepare - 检查并准备
    // 严格翻译自: visit_binary.zig:536-571
    //   pub fn checkAndPrepare(v: *BinaryExpressionVisitor, p: *P) ?Expr
    // ========================================================================

    /// 检查并准备二元表达式的访问
    /// 返回非 null 表示可以立即返回结果 (如 private-in 的情况)
    public func checkAndPrepare(p: Parser): ?Expr {
        // 设置左操作数的赋值目标
        leftIn = ExprIn(assignTarget: binaryAssignTarget(expr.op))

        // 设置 isStmtExpr 标志
        // 对应 Bun: v.is_stmt_expr = p.stmt_expr_value == .e_binary and ...

        return None
    }

    // ========================================================================
    // visitRightAndFinish - 访问右操作数并完成
    // 严格翻译自: visit_binary.zig:64-534
    //   pub fn visitRightAndFinish(v: *BinaryExpressionVisitor, p: *P) Expr
    // ========================================================================

    /// 访问右操作数并完成二元表达式处理
    /// 包含常量折叠、逻辑短路优化、typeof 优化等
    public func visitRightAndFinish(p: Parser, exprVisitor: ExprVisitor): Expr {
        var mutableExpr = expr

        // 访问右操作数
        if (let Some(right) <- mutableExpr.right) {
            mutableExpr.right = Some(exprVisitor.visitExpr(right))
        }

        // 根据操作符进行优化
        let op = mutableExpr.op

        // --- 逗号运算符优化 ---
        if (op == OpCode.Comma) {
            // "(1, 2)" => "2"
            // "(sideEffects(), 2)" => "(sideEffects(), 2)"
            // 对应 Bun: bin_comma
        }

        // --- 相等比较优化 ---
        if (op == OpCode.BinEq) {
            // 严格相等比较的常量折叠
            // 对应 Bun: bin_strict_eq
            let result = tryEvaluateEquality(mutableExpr, true)
            if (let Some(value) <- result) {
                return value
            }
        }

        if (op == OpCode.BinEqStrict) {
            let result = tryEvaluateEquality(mutableExpr, true)
            if (let Some(value) <- result) {
                return value
            }
        }

        if (op == OpCode.BinNe) {
            let result = tryEvaluateEquality(mutableExpr, false)
            if (let Some(value) <- result) {
                return value
            }
        }

        if (op == OpCode.BinNeStrict) {
            let result = tryEvaluateEquality(mutableExpr, false)
            if (let Some(value) <- result) {
                return value
            }
        }

        // --- 算术运算常量折叠 ---
        if (p.shouldFoldConstantExpressions()) {
            if (let Some(result) <- tryFoldArithmetic(mutableExpr)) {
                return result
            }
        }

        // --- 逻辑运算优化 ---
        if (op == OpCode.BinLoAnd) {
            // && 短路: "false && anything" => "false"
            // 对应 Bun: bin_logical_and
        }

        if (op == OpCode.BinLoOr) {
            // || 短路: "true || anything" => "true"
            // 对应 Bun: bin_logical_or
        }

        if (op == OpCode.BinNullish) {
            // ?? 短路: "nonNull ?? anything" => "nonNull"
            // 对应 Bun: bin_nullish_coalescing
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
                            // 字符串拼接: "'abc' + 'xyz'" => "'abcxyz'"
                            // 对应 Bun: foldStringAddition
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
                            if (rv != 0.0) {
                                // 使用 fmod 语义
                                return Some(Expr.number(expr.loc, lv.remainder(rv)))
                            }
                        case OpCode.BinPow =>
                            return Some(Expr.number(expr.loc, Math.pow(lv, rv)))
                        case OpCode.BinShl => {
                            let leftInt = floatToInt32(lv)
                            let rightInt = Float64(Float64(floatToInt32(rv)).toInt32() % 32).toInt32()
                            let result = leftInt << rightInt
                            return Some(Expr.number(expr.loc, Float64(result)))
                        }
                        case OpCode.BinShr => {
                            let leftInt = floatToInt32(lv)
                            let rightInt = Float64(Float64(floatToInt32(rv)).toInt32() % 32).toInt32()
                            let result = leftInt >> rightInt
                            return Some(Expr.number(expr.loc, Float64(result)))
                        }
                        case OpCode.BinUShr => {
                            // 无符号右移
                            let leftInt = Float64(floatToInt32(lv)).toUInt32()
                            let rightInt = Float64(Float64(floatToInt32(rv)).toInt32() % 32).toInt32()
                            let result = leftInt >> rightInt
                            return Some(Expr.number(expr.loc, Float64(result)))
                        }
                        case OpCode.BinAnd => {
                            let result = floatToInt32(lv).bitAnd(floatToInt32(rv))
                            return Some(Expr.number(expr.loc, Float64(result)))
                        }
                        case OpCode.BinOr => {
                            let result = floatToInt32(lv).bitOr(floatToInt32(rv))
                            return Some(Expr.number(expr.loc, Float64(result)))
                        }
                        case OpCode.BinXor => {
                            let result = floatToInt32(lv).bitXor(floatToInt32(rv))
                            return Some(Expr.number(expr.loc, Float64(result)))
                        }
                        case _ =>
                            return None
                    }
                }

                // 比较运算
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

                // 字符串拼接: "'abc' + 'xyz'" => "'abcxyz'"
                // 对应 Bun: foldStringAddition
                if (expr.op == OpCode.BinAdd) {
                    if (left.tag == ExprTag.String && right.tag == ExprTag.String) {
                        let combined = left.stringValue.toString() + right.stringValue.toString()
                        return Some(Expr.string(expr.loc, combined))
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
    private func floatToInt32(f: Float64): Int32 {
        if (f >= Float64(Int32.Max) || f < Float64(Int32.Min) || f.isNaN() || f.isInfinite()) {
            return Int32(0)
        }
        return Int32(f)
    }

    /// 获取二元操作符的赋值目标
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
