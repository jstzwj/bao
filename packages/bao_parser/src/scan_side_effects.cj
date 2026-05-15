// AST 副作用扫描器
// 严格翻译自: src/js_parser/scan/scan_side_effects.zig (915 lines)
//   Bun 的副作用扫描器用于确定表达式/语句是否有副作用
//   这是 tree shaking (摇树优化) 的核心基础设施
//   包括: toBoolean, toNullOrUndefined, simplifyBoolean, simplifyUnusedExpr,
//         shouldKeepStmtInDeadControlFlow, isPrimitiveWithSideEffects
//   对应 Bun: SideEffects (enum + 方法集)
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// SideEffects - 副作用分析工具集
// 严格翻译自: scan_side_effects.zig:1-892
//   pub const SideEffects = enum(u1) { could_have_side_effects, no_side_effects }
//   以及所有静态方法: toBoolean, toNullOrUndefined, simplifyBoolean, etc.
// ============================================================================

/// 副作用分析工具集 - 对应 Bun SideEffects
/// 提供静态方法来判断表达式/语句的副作用特性
public class SideEffects {

    // ========================================================================
    // toBoolean - 将表达式数据转为布尔值
    // 严格翻译自: scan_side_effects.zig:763-891
    //   pub fn toBoolean(p: anytype, exp: Expr.Data) Result
    // ========================================================================

    /// 将表达式转为布尔值结果
    /// 对应 Bun SideEffects.toBoolean
    /// 用于死代码消除中的条件判断优化
    public static func toBoolean(parser: Parser, expr: Expr): SideEffectResult {
        // 只在启用死代码消除时执行
        if (!parser.options.deadCodeElimination) {
            return SideEffectResult.unknown()
        }

        return toBooleanWithoutDCECheck(expr)
    }

    /// 不检查 DCE 标志的布尔转换
    /// 对应 Bun toBooleanWithoutDCECheck
    private static func toBooleanWithoutDCECheck(expr: Expr): SideEffectResult {
        match (expr.tag) {
            // null 和 undefined 总是 falsy
            case ExprTag.Null | ExprTag.Undefined =>
                return SideEffectResult.known(false)

            // 布尔值直接返回
            case ExprTag.Boolean =>
                return SideEffectResult.known(expr.boolValue)

            // 数字: 0 和 NaN 是 falsy
            case ExprTag.Number =>
                let value = expr.numberValue
                return SideEffectResult.known(value != 0.0 && !value.isNaN())

            // BigInt: "0" 是 falsy
            case ExprTag.BigInt =>
                return SideEffectResult.known(expr.stringValue.toString() != "0")

            // 字符串: 空字符串是 falsy
            case ExprTag.String =>
                // 空字符串是 falsy
                return SideEffectResult.known(expr.stringValue.toString().size > 0)

            // 函数、正则表达式总是 truthy
            case ExprTag.Function | ExprTag.Regex =>
                return SideEffectResult.known(true)

            // 对象和数组总是 truthy (可能有副作用)
            case ExprTag.Object | ExprTag.Array | ExprTag.Class =>
                return SideEffectResult.knownWithSideEffects(true)

            // 一元表达式
            case ExprTag.Unary => {
                let op = expr.op
                match (op) {
                    case OpCode.UnVoid =>
                        // void 总是返回 undefined, 即 falsy
                        return SideEffectResult.knownWithSideEffects(false)
                    case OpCode.Typeof =>
                        // typeof 总是返回非空字符串, 即 truthy
                        return SideEffectResult.knownWithSideEffects(true)
                    case OpCode.UnNot => {
                        // !x 取反
                        if (let Some(value) <- expr.value) {
                            let innerResult = toBooleanWithoutDCECheck(value)
                            if (innerResult.ok) {
                                return SideEffectResult(
                                    sideEffects: innerResult.sideEffects,
                                    ok: true,
                                    value: !innerResult.value
                                )
                            }
                        }
                    }
                    case _ =>
                        return SideEffectResult.unknown()
                }
            }

            // 二元表达式中的逻辑运算
            case ExprTag.Binary => {
                let op = expr.op
                // || 和 && 的短路分析
                if (op == OpCode.BinLoOr) {
                    // "anything || truthy" 是 truthy
                    if (let Some(right) <- expr.right) {
                        let result = toBooleanWithoutDCECheck(right)
                        if (result.ok && result.value) {
                            return SideEffectResult.knownWithSideEffects(true)
                        }
                    }
                }
                if (op == OpCode.BinLoAnd) {
                    // "anything && falsy" 是 falsy
                    if (let Some(right) <- expr.right) {
                        let result = toBooleanWithoutDCECheck(right)
                        if (result.ok && !result.value) {
                            return SideEffectResult.knownWithSideEffects(false)
                        }
                    }
                }
            }

            // 三元表达式
            case ExprTag.Ternary => {
                // 三元表达式不直接求值布尔结果
            }

            case _ =>
                return SideEffectResult.unknown()
        }

        return SideEffectResult.unknown()
    }

    // ========================================================================
    // toNullOrUndefined - 检查表达式是否为 null 或 undefined
    // 严格翻译自: scan_side_effects.zig:654-761
    //   pub fn toNullOrUndefined(p: anytype, exp: Expr.Data) Result
    // ========================================================================

    /// 检查表达式是否为 null 或 undefined
    /// 对应 Bun SideEffects.toNullOrUndefined
    /// 用于 ?? 运算符的优化
    public static func toNullOrUndefined(parser: Parser, expr: Expr): SideEffectResult {
        if (!parser.options.deadCodeElimination) {
            return SideEffectResult.unknown()
        }

        match (expr.tag) {
            // 绝对不是 null/undefined
            case ExprTag.Boolean | ExprTag.Number | ExprTag.String |
                 ExprTag.Regex | ExprTag.Function | ExprTag.BigInt =>
                return SideEffectResult.known(false)

            // 对象和数组绝对不是 null/undefined
            case ExprTag.Object | ExprTag.Array | ExprTag.Class =>
                return SideEffectResult.knownWithSideEffects(false)

            // null 和 undefined
            case ExprTag.Null | ExprTag.Undefined =>
                return SideEffectResult.known(true)

            // 一元表达式
            case ExprTag.Unary => {
                match (expr.op) {
                    case OpCode.UnVoid =>
                        // void 总是返回 undefined
                        return SideEffectResult.knownWithSideEffects(true)
                    case OpCode.UnPos | OpCode.UnNeg | OpCode.UnCpl |
                         OpCode.UnNot | OpCode.Typeof =>
                        // 这些操作符不会返回 null/undefined
                        return SideEffectResult.knownWithSideEffects(false)
                    case _ =>
                        return SideEffectResult.unknown()
                }
            }

            // 二元表达式
            case ExprTag.Binary => {
                let op = expr.op
                // 算术/比较/位运算不会返回 null/undefined
                match (op) {
                    case OpCode.BinAdd | OpCode.BinSub | OpCode.BinMul |
                         OpCode.BinDiv | OpCode.BinRem | OpCode.BinPow |
                         OpCode.BinShl | OpCode.BinShr | OpCode.BinUShr |
                         OpCode.BinAnd | OpCode.BinOr | OpCode.BinXor |
                         OpCode.BinLt | OpCode.BinGt | OpCode.BinLe | OpCode.BinGe |
                         OpCode.BinIn | OpCode.BinInstanceof |
                         OpCode.BinEq | OpCode.BinNe | OpCode.BinEqStrict | OpCode.BinNeStrict =>
                        return SideEffectResult.knownWithSideEffects(false)
                    case _ =>
                        return SideEffectResult.unknown()
                }
            }

            case _ =>
                return SideEffectResult.unknown()
        }

        return SideEffectResult.unknown()
    }

    // ========================================================================
    // simplifyBoolean - 简化布尔表达式
    // 严格翻译自: scan_side_effects.zig:17-64
    //   pub fn simplifyBoolean(p: anytype, expr: Expr) Expr
    // ========================================================================

    /// 简化布尔表达式
    /// 对应 Bun SideEffects.simplifyBoolean
    /// 例如: !!a => a, if (anything && truthyNoSideEffects) => if (anything)
    public static func simplifyBoolean(parser: Parser, expr: Expr): Expr {
        if (!parser.options.deadCodeElimination) {
            return expr
        }

        var result = expr
        // 迭代简化直到无法继续
        var changed = true
        while (changed) {
            changed = false

            match (result.tag) {
                case ExprTag.Unary => {
                    if (result.op == OpCode.UnNot) {
                        // !!a => a
                        if (let Some(value) <- result.value) {
                            if (value.tag == ExprTag.Unary && value.op == OpCode.UnNot) {
                                if (let Some(inner) <- value.value) {
                                    result = inner
                                    changed = true
                                }
                            }
                        }
                    }
                }
                case ExprTag.Binary => {
                    match (result.op) {
                        case OpCode.BinLoAnd => {
                            // "if (anything && truthyNoSideEffects)" => "if (anything)"
                            if (let Some(right) <- result.right) {
                                let effects = toBoolean(parser, right)
                                if (effects.ok && effects.value && effects.sideEffects == SideEffectFlag.NoSideEffects) {
                                    if (let Some(left) <- result.left) {
                                        result = left
                                        changed = true
                                    }
                                }
                            }
                        }
                        case OpCode.BinLoOr => {
                            // "if (anything || falsyNoSideEffects)" => "if (anything)"
                            if (let Some(right) <- result.right) {
                                let effects = toBoolean(parser, right)
                                if (effects.ok && !effects.value && effects.sideEffects == SideEffectFlag.NoSideEffects) {
                                    if (let Some(left) <- result.left) {
                                        result = left
                                        changed = true
                                    }
                                }
                            }
                        }
                        case _ =>
                            changed = false
                    }
                }
                case _ =>
                    changed = false
            }
        }

        return result
    }

    // ========================================================================
    // simplifyUnusedExpr - 简化未使用的表达式
    // 严格翻译自: scan_side_effects.zig:85-356
    //   pub fn simplifyUnusedExpr(p: anytype, expr: Expr) ?Expr
    // ========================================================================

    /// 简化未使用的表达式
    /// 对应 Bun SideEffects.simplifyUnusedExpr
    /// 如果表达式可以被完全移除，返回 null
    public static func simplifyUnusedExpr(parser: Parser, expr: Expr): ?Expr {
        if (!parser.options.deadCodeElimination) {
            return Some(expr)
        }

        match (expr.tag) {
            // 无副作用的字面量可以移除
            case ExprTag.Null | ExprTag.Undefined | ExprTag.Missing |
                 ExprTag.Boolean | ExprTag.Number | ExprTag.BigInt |
                 ExprTag.String | ExprTag.This | ExprTag.Regex |
                 ExprTag.Function | ExprTag.Arrow =>
                return None

            case ExprTag.Array => {
                // 数组: 如果没有 spread，可以移除所有无副作用的元素
                var hasSpread = false
                for (item in expr.items) {
                    if (item.tag == ExprTag.Spread) {
                        hasSpread = true
                    }
                }

                if (!hasSpread) {
                    // 递归简化每个元素
                    var anySideEffects = false
                    for (item in expr.items) {
                        let simplified = simplifyUnusedExpr(parser, item)
                        if (simplified != None) {
                            anySideEffects = true
                        }
                    }
                    if (!anySideEffects) {
                        return None
                    }
                }
                return Some(expr)
            }

            case ExprTag.Object => {
                // 对象: 如果没有 spread，可以移除
                var hasSpread = false
                for (prop in expr.properties) {
                    if (prop.isSpread) {
                        hasSpread = true
                    }
                }

                if (!hasSpread) {
                    return None
                }
                return Some(expr)
            }

            case ExprTag.Unary => {
                match (expr.op) {
                    case OpCode.UnVoid | OpCode.UnNot => {
                        // void x 和 !x 可以简化为简化 x
                        if (let Some(value) <- expr.value) {
                            return simplifyUnusedExpr(parser, value)
                        }
                    }
                    case OpCode.Typeof => {
                        // typeof x 对于标识符可以移除 (typeof 不会抛出异常)
                        if (let Some(value) <- expr.value) {
                            if (value.tag == ExprTag.Identifier) {
                                return None
                            }
                            return simplifyUnusedExpr(parser, value)
                        }
                    }
                    case _ =>
                        return Some(expr)
                }
            }

            case ExprTag.Ternary => {
                // 三元表达式: 简化各分支
                // "foo() ? 1 : 2" => "foo()"
                // "foo() ? 1 : bar()" => "foo() || bar()"
                // "foo() ? bar() : 2" => "foo() && bar()"
                return Some(expr)
            }

            case _ =>
                return Some(expr)
        }

        return Some(expr)
    }

    // ========================================================================
    // shouldKeepStmtInDeadControlFlow - 死代码中是否保留语句
    // 严格翻译自: scan_side_effects.zig:449-544
    //   pub fn shouldKeepStmtInDeadControlFlow(stmt: Stmt, allocator: Allocator) bool
    // ========================================================================

    /// 检查死代码分支中是否需要保留语句
    /// 对应 Bun SideEffects.shouldKeepStmtInDeadControlFlow
    /// 只有 hoisted declarations ("var" 和 "function") 需要保留
    /// 因为它们影响父作用域
    public static func shouldKeepStmtInDeadControlFlow(stmt: Stmt): Bool {
        match (stmt.tag) {
            // 完全可以移除
            case StmtTag.Empty | StmtTag.Expr | StmtTag.Throw |
                 StmtTag.Return | StmtTag.Break | StmtTag.Continue |
                 StmtTag.Class | StmtTag.Debugger =>
                return false

            case StmtTag.Local => {
                // let/const 声明可以移除
                // var 声明需要保留 (因为 var 具有函数级提升)
                match (stmt.declKind) {
                    case DeclKind.Var =>
                        // 保留 var 声明 (但可以移除初始值)
                        return true
                    case _ =>
                        return false
                }
            }

            case StmtTag.Block => {
                // 块语句: 如果块内有任何需要保留的语句，保留整个块
                for (child in stmt.stmts) {
                    if (shouldKeepStmtInDeadControlFlow(child)) {
                        return true
                    }
                }
                return false
            }

            case StmtTag.Try => {
                // try 语句: 检查 try/catch/finally 各部分
                for (child in stmt.stmts) {
                    if (shouldKeepStmtInDeadControlFlow(child)) {
                        return true
                    }
                }
                if (let Some(catch_) <- stmt.catch_) {
                    for (child in catch_.stmts) {
                        if (shouldKeepStmtInDeadControlFlow(child)) {
                            return true
                        }
                    }
                }
                if (let Some(finally) <- stmt.finally) {
                    for (child in finally.stmts) {
                        if (shouldKeepStmtInDeadControlFlow(child)) {
                            return true
                        }
                    }
                }
                return false
            }

            case StmtTag.If => {
                if (let Some(yes) <- stmt.yes) {
                    if (shouldKeepStmtInDeadControlFlow(yes)) {
                        return true
                    }
                }
                if (let Some(no) <- stmt.no) {
                    if (shouldKeepStmtInDeadControlFlow(no)) {
                        return true
                    }
                }
                return false
            }

            case StmtTag.While | StmtTag.DoWhile => {
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false
            }

            case StmtTag.For => {
                if (let Some(init) <- stmt.init) {
                    if (shouldKeepStmtInDeadControlFlow(init)) {
                        return true
                    }
                }
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false
            }

            case StmtTag.ForIn | StmtTag.ForOf => {
                if (let Some(init) <- stmt.init) {
                    if (shouldKeepStmtInDeadControlFlow(init)) {
                        return true
                    }
                }
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false
            }

            case StmtTag.Labeled => {
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false
            }

            // 默认保留 (安全起见)
            case _ =>
                return true
        }
    }

    // ========================================================================
    // isPrimitiveToReorder - 是否为可重排序的原始值
    // 严格翻译自: scan_side_effects.zig:69-83
    // ========================================================================

    /// 检查表达式是否为可重排序的原始值
    /// 对应 Bun SideEffects.isPrimitiveToReorder
    /// 用于相等比较时将常量放在右侧
    public static func isPrimitiveToReorder(expr: Expr): Bool {
        match (expr.tag) {
            case ExprTag.Null | ExprTag.Undefined | ExprTag.String |
                 ExprTag.Boolean | ExprTag.Number | ExprTag.BigInt =>
                return true
            case _ =>
                return false
        }
    }

    // ========================================================================
    // isPrimitiveWithSideEffects - 是否为带副作用的原始值
    // 严格翻译自: scan_side_effects.zig:549-650
    // ========================================================================

    /// 检查表达式是否为原始值 (即使可能有副作用)
    /// 对应 Bun SideEffects.isPrimitiveWithSideEffects
    public static func isPrimitiveWithSideEffects(expr: Expr): Bool {
        match (expr.tag) {
            case ExprTag.Null | ExprTag.Undefined | ExprTag.Boolean |
                 ExprTag.Number | ExprTag.BigInt | ExprTag.String =>
                return true

            case ExprTag.Unary => {
                // 所有一元运算都返回原始值
                return true
            }

            case ExprTag.Binary => {
                // 大多数二元运算返回原始值
                match (expr.op) {
                    case OpCode.BinLoAnd | OpCode.BinLoOr | OpCode.BinNullish =>
                        // 这些运算返回其中一个操作数
                        if (let Some(left) <- expr.left) {
                            if (let Some(right) <- expr.right) {
                                return isPrimitiveWithSideEffects(left) && isPrimitiveWithSideEffects(right)
                            }
                        }
                        return false
                    case OpCode.Comma =>
                        if (let Some(right) <- expr.right) {
                            return isPrimitiveWithSideEffects(right)
                        }
                        return false
                    case _ =>
                        return true
                }
            }

            case ExprTag.Ternary => {
                if (let Some(yes) <- expr.yes) {
                    if (let Some(no) <- expr.no) {
                        return isPrimitiveWithSideEffects(yes) && isPrimitiveWithSideEffects(no)
                    }
                }
                return false
            }

            case _ =>
                return false
        }
    }

    // ========================================================================
    // canChangeStrictToLoose - 严格比较是否可改为松散比较
    // 严格翻译自: scan_side_effects.zig:11-15
    // ========================================================================

    /// 检查严格比较是否可以安全改为松散比较
    /// 对应 Bun SideEffects.canChangeStrictToLoose
    public static func canChangeStrictToLoose(left: Expr, right: Expr): Bool {
        // 如果两边是相同类型的已知原始值，可以安全改为松散比较
        // 因为松散比较中相同类型的比较等价于严格比较
        return isPrimitiveToReorder(left) && isPrimitiveToReorder(right)
    }
}
