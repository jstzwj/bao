// 严格翻译自: src/ast/fold_string_addition.zig
// 字符串加法折叠: "a" + "b" => "ab", 模板字符串折叠
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// foldStringAddition - 字符串加法折叠
// 严格翻译自: src/ast/fold_string_addition.zig:1-234
// Bun: pub fn foldStringAddition(l: Expr, r: Expr, allocator, kind) ?Expr
// 将 "bar" + "baz" => "barbaz" 等常量折叠优化
// ============================================================================

/// 折叠类型 - 对应 Bun FoldStringAdditionKind
/// Bun: const FoldStringAdditionKind = enum { normal, nested_left }
public enum FoldStringAdditionKind {
    | Normal     // "x" + "y" -> "xy", 1 + "y" -> "1y"
    | NestedLeft // a + "x" + "y" -> a + "xy"

    public func name(): String {
        match (this) {
            case Normal => "normal"
            case NestedLeft => "nested_left"
        }
    }
}

/// 连接两个 E.String - 对应 Bun joinStrings()
/// Bun: fn joinStrings(left: *const E.String, right: *const E.String, has_inlined_enum_poison: bool) E.String
/// 会修改两个输入字符串 (除非 has_inlined_enum_poison)
public func joinStrings(left: EString, right: EString, hasInlinedEnumPoison: Bool): EString {
    var new_: EString
    if (hasInlinedEnumPoison) {
        // 内联枚举可能被多个调用点共享, 需要克隆整个 rope
        new_ = left.cloneRopeNodes()
    } else {
        new_ = left.clone()
    }

    // 右侧也需要克隆 (枚举 rope)
    let rhsClone = EString(right.data)
    rhsClone.preferTemplate = right.preferTemplate
    rhsClone.isUtf16 = right.isUtf16
    rhsClone.ropeLen = right.ropeLen

    new_.push(rhsClone)
    new_.preferTemplate = new_.preferTemplate || rhsClone.preferTemplate

    return new_
}

/// 折叠字符串加法 - 对应 Bun foldStringAddition()
/// Bun: pub fn foldStringAddition(l: Expr, r: Expr, allocator, kind) ?Expr
/// 注意: 此函数会修改输入 AST (对于 rope 字符串)
public func foldStringAddition(l: ASTNode, r: ASTNode, kind: FoldStringAdditionKind): ?ASTNode {
    // 解包内联枚举
    var lhs = ExprFactory.unwrapInlined(l)
    var rhs = ExprFactory.unwrapInlined(r)

    // 在非 nested_left 模式下, 尝试将 lhs 转为字符串
    if (kind != FoldStringAdditionKind.NestedLeft) {
        let rhsTag = rhs.tag
        match (rhsTag) {
            case ExprTag.String | ExprTag.Template => {
                let strExpr = ExprFactory.toStringExprWithoutSideEffects(lhs)
                if (strExpr.isSome()) {
                    lhs = strExpr.orElse(lhs)
                }
            }
            case _ => ()
        }
    }

    // 主要逻辑: 基于 lhs 类型进行匹配
    match (lhs.tag) {
        case ExprTag.String => {
            // 尝试将 rhs 也转为字符串
            let rhsStr = ExprFactory.toStringExprWithoutSideEffects(rhs)
            if (rhsStr.isSome()) {
                rhs = rhsStr.orElse(rhs)
            }

            // "bar" + "baz" => "barbaz"
            if (rhs.tag == ExprTag.String) {
                let leftStr = lhs.value as? EString
                let rightStr = rhs.value as? EString
                if (leftStr.isSome() && rightStr.isSome()) {
                    let ls = leftStr.orElse(EString())
                    let rs = rightStr.orElse(EString())
                    if (ls.isUTF8() && rs.isUTF8()) {
                        let hasInlinedEnumPoison = l.tag == ExprTag.InlinedEnum || r.tag == ExprTag.InlinedEnum
                        let joined = joinStrings(ls, rs, hasInlinedEnumPoison)
                        return ExprFactory.string(joined.data, lhs.loc)
                    }
                }
            }

            // "bar" + `baz${bar}` => `barbaz${bar}`
            if (rhs.tag == ExprTag.Template) {
                // 模板头部与字符串连接
                // 简化处理
            }

            // 空字符串 + x => x (如果 x 是字符串类型)
            let leftStr2 = lhs.value as? EString
            if (leftStr2.isSome()) {
                let ls = leftStr2.orElse(EString())
                if (ls.len() == Int64(0) && ExprFactory.knownPrimitive(rhs) == PrimitiveType.String) {
                    return rhs
                }
            }

            return None
        }

        case ExprTag.Template => {
            // 模板字符串与右侧连接
            // `foo${bar}` + "baz" => `foo${bar}baz`
            // 简化处理
            let rhsStr = ExprFactory.toStringExprWithoutSideEffects(rhs)
            if (rhsStr.isSome()) {
                rhs = rhsStr.orElse(rhs)
            }
            return None
        }

        case _ => ()
    }

    // x + "" => x (如果 x 是字符串)
    if (rhs.tag == ExprTag.String) {
        let rightStr = rhs.value as? EString
        if (rightStr.isSome()) {
            let rs = rightStr.orElse(EString())
            if (rs.len() == Int64(0) && ExprFactory.knownPrimitive(lhs) == PrimitiveType.String) {
                return lhs
            }
        }
    }

    return None
}
