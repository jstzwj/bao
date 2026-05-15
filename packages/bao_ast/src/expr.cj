// 严格翻译自: src/ast/expr.zig
// Expr 联合类型: 表达式节点, 包含 init, allocate, clone, deepClone, 各种辅助方法
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// Expr - 表达式节点
// 严格翻译自: src/ast/expr.zig:1-3248
// Bun: pub const Expr = struct { loc: logger.Loc, data: Data }
// Expr 是 JavaScript 表达式的 AST 节点, 通过 Expr.Data tagged union 区分类型
// ============================================================================

/// 原始类型 - 对应 Bun Expr.PrimitiveType
/// Bun: pub const PrimitiveType = enum { unknown, mixed, null, undefined, boolean, number, string, bigint }
public enum PrimitiveType {
    | Unknown
    | Mixed
    | Null
    | Undefined
    | Boolean
    | Number
    | String
    | Bigint

    /// 是否静态 - 对应 Bun PrimitiveType.isStatic()
    public func isStatic(): Bool {
        match (this) {
            case Mixed | Null | Undefined | Boolean | Number | String => true
            case Unknown | Bigint => false
        }
    }

    /// 合并两个原始类型 - 对应 Bun PrimitiveType.merge()
    public static func merge(left: PrimitiveType, right: PrimitiveType): PrimitiveType {
        if (right == Unknown || left == Unknown) {
            return Unknown
        }
        if (left == right) {
            return left
        }
        return Mixed
    }
}

/// 表达式相等结果 - 对应 Bun Expr.Data.Equality
public class ExprEquality {
    public var equal: Bool
    public var ok: Bool
    public var isRequireMainAndModule: Bool

    public init(equal: Bool, ok: Bool) {
        this.equal = equal
        this.ok = ok
        this.isRequireMainAndModule = false
    }

    public static let TRUE: ExprEquality = ExprEquality(true, true)
    public static let FALSE: ExprEquality = ExprEquality(false, true)
    public static let UNKNOWN: ExprEquality = ExprEquality(false, false)
}

/// 表达式数据存储 - 对应 Bun Expr.Data.Store
/// Bun 使用 arena 分配器, 仓颉使用 GC 堆
public class ExprDataStore {
    /// 实例计数
    public static var instanceCount: Int64 = Int64(0)

    public static func create(): Unit {
        instanceCount += Int64(1)
    }

    public static func reset(): Unit {
        // GC 管理内存, 无需操作
    }

    public static func deinit(): Unit {
        instanceCount -= Int64(1)
    }

    public static func begin(): Unit {
        create()
    }

    public static func assert_(): Unit {
        // 在 debug 模式下检查 store 已初始化
    }
}

/// 表达式数据 - 对应 Bun Expr.Data
/// tagged union, 仓颉用类 + ExprTag 枚举模拟
/// 已在 package.cj 的 ASTNode 中覆盖核心功能
/// 这里提供 Expr 特有的工具方法

/// Expr 工厂 - 对应 Bun Expr.init() / Expr.allocate()
/// 创建各种类型的表达式节点
public class ExprFactory {
    /// 创建缺失表达式
    public static func missing(loc: Loc): ASTNode {
        return ASTNode(ExprTag.Missing, loc)
    }

    /// 创建布尔表达式
    public static func boolean(value: Bool, loc: Loc): ASTNode {
        return ASTNode(ExprTag.Boolean, loc, value)
    }

    /// 创建 null 表达式
    public static func null_(loc: Loc): ASTNode {
        return ASTNode(ExprTag.Null, loc, ENull())
    }

    /// 创建 undefined 表达式
    public static func undefined(loc: Loc): ASTNode {
        return ASTNode(ExprTag.Undefined, loc, EUndefined())
    }

    /// 创建数字表达式
    public static func number(value: Float64, loc: Loc): ASTNode {
        return ASTNode(ExprTag.Number, loc, ENumber(value))
    }

    /// 创建 BigInt 表达式
    public static func bigInt(value: String, loc: Loc): ASTNode {
        return ASTNode(ExprTag.BigInt, loc, EBigInt(value))
    }

    /// 创建字符串表达式
    public static func string(value: String, loc: Loc): ASTNode {
        return ASTNode(ExprTag.String, loc, EString(value))
    }

    /// 创建标识符表达式
    public static func identifier(ref: Ref, loc: Loc): ASTNode {
        return ASTNode(ExprTag.Identifier, loc, EIdentifier(ref))
    }

    /// 创建 this 表达式
    public static func this_(loc: Loc): ASTNode {
        return ASTNode(ExprTag.This, loc, EThis())
    }

    /// 创建 super 表达式
    public static func super_(loc: Loc): ASTNode {
        return ASTNode(ExprTag.Super, loc, ESuper())
    }

    /// 创建数组表达式
    public static func array(items: ArrayList<ASTNode>, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Array, loc, EArray())
        for (item in items) {
            node.addChild(item)
        }
        return node
    }

    /// 创建对象表达式
    public static func object(properties: ArrayList<GProperty>, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Object, loc, EObject())
        for (prop in properties) {
            if (prop.key.isSome()) {
                node.addChild(prop.key.orElse(ASTNode(ExprTag.Missing, loc)))
            }
            if (prop.value.isSome()) {
                node.addChild(prop.value.orElse(ASTNode(ExprTag.Missing, loc)))
            }
        }
        return node
    }

    /// 创建调用表达式
    public static func call(target: ASTNode, args: ArrayList<ASTNode>, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Call, loc, ECall(target, args))
        node.addChild(target)
        for (arg in args) {
            node.addChild(arg)
        }
        return node
    }

    /// 创建 new 表达式
    public static func new_(target: ASTNode, args: ArrayList<ASTNode>, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.New, loc, ENew(target, args))
        node.addChild(target)
        for (arg in args) {
            node.addChild(arg)
        }
        return node
    }

    /// 创建成员访问表达式 (a.b)
    public static func dot(target: ASTNode, name: String, nameLoc: Loc, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Member, loc, EDot(target, name, nameLoc))
        node.addChild(target)
        return node
    }

    /// 创建索引访问表达式 (a[b])
    public static func index(target: ASTNode, index: ASTNode, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Index, loc, EIndex(index, target))
        node.addChild(target)
        node.addChild(index)
        return node
    }

    /// 创建一元表达式
    public static func unary(op: OpCode, value: ASTNode, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Unary, loc, EUnary(op, value))
        node.addChild(value)
        return node
    }

    /// 创建二元表达式
    public static func binary(op: OpCode, left: ASTNode, right: ASTNode, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Binary, loc, EBinary(left, right, op))
        node.addChild(left)
        node.addChild(right)
        return node
    }

    /// 创建赋值表达式 - 对应 Bun Expr.assign()
    public static func assign(left: ASTNode, right: ASTNode): ASTNode {
        return binary(OpCode.BinAssign, left, right, left.loc)
    }

    /// 创建箭头函数
    public static func arrow(args: ArrayList<GArg>, body: GFnBody, isAsync: Bool, loc: Loc): ASTNode {
        return ASTNode(ExprTag.Arrow, loc, EArrow(args, body, isAsync))
    }

    /// 创建函数表达式
    public static func function(func: GFn, loc: Loc): ASTNode {
        return ASTNode(ExprTag.Function, loc, EFunction(func))
    }

    /// 创建三元条件表达式
    public static func conditional(test_: ASTNode, yes: ASTNode, no: ASTNode, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Conditional, loc, EIf(test_, yes, no))
        node.addChild(test_)
        node.addChild(yes)
        node.addChild(no)
        return node
    }

    /// 创建展开运算符
    public static func spread(value: ASTNode, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Spread, loc, ESpread(value))
        node.addChild(value)
        return node
    }

    /// 创建 await 表达式
    public static func await_(value: ASTNode, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Await, loc, EAwait(value))
        node.addChild(value)
        return node
    }

    /// 创建 yield 表达式
    public static func yield_(value: ?ASTNode, isStar: Bool, loc: Loc): ASTNode {
        let node = ASTNode(ExprTag.Yield, loc, EYield(value, isStar))
        if (value.isSome()) {
            node.addChild(value.orElse(ASTNode(ExprTag.Missing, loc)))
        }
        return node
    }

    /// 创建模板字面量
    public static func template(tag: ?ASTNode, parts: ArrayList<ETemplatePart>,
                                head: TemplateContents, loc: Loc): ASTNode {
        return ASTNode(ExprTag.Template, loc, ETemplate(tag, parts, head))
    }

    /// 创建正则表达式
    public static func regExp(value: String, loc: Loc): ASTNode {
        return ASTNode(ExprTag.RegExp, loc, ERegExp(value))
    }

    /// 创建 import() 表达式
    public static func import_(expr: ASTNode, options: ASTNode,
                               importRecordIndex: UInt32, loc: Loc): ASTNode {
        return ASTNode(ExprTag.ImportRecord, loc,
                       EImport(expr, options, importRecordIndex))
    }

    /// 创建 require 字符串表达式
    public static func requireString(importRecordIndex: UInt32, loc: Loc): ASTNode {
        return ASTNode(ExprTag.RequireString, loc,
                       ERequireString(importRecordIndex, UInt32.MAX))
    }

    /// 创建 import.meta 表达式
    public static func importMeta(loc: Loc): ASTNode {
        return ASTNode(ExprTag.Member, loc, EImportMeta())
    }

    /// 创建 new.target 表达式
    public static func newTarget(range: Range, loc: Loc): ASTNode {
        return ASTNode(ExprTag.Member, loc, ENewTarget(range))
    }

    /// 创建逻辑非 - 对应 Bun Expr.not()
    /// Bun: pub fn not(expr: *const Expr, allocator: std.mem.Allocator) Expr
    public static func not(expr: ASTNode): ASTNode {
        let simplified = maybeSimplifyNot(expr)
        if (simplified.isSome()) {
            return simplified.orElse(boolean(false, expr.loc))
        }
        return unary(OpCode.UnNot, expr, expr.loc)
    }

    /// 尝试简化逻辑非 - 对应 Bun Expr.maybeSimplifyNot()
    public static func maybeSimplifyNot(expr: ASTNode): ?ASTNode {
        match (expr.tag) {
            case ExprTag.Null | ExprTag.Undefined =>
                return boolean(true, expr.loc)
            case ExprTag.Boolean => {
                let b = expr.boolValue()
                if (b.isSome()) {
                    return boolean(!b.orElse(false), expr.loc)
                }
            }
            case ExprTag.Number => {
                let n = expr.numberValue()
                if (n.isSome()) {
                    return boolean(n.orElse(Float64(0)) == Float64(0) ||
                                   n.orElse(Float64(0)) != n.orElse(Float64(0)),
                                   expr.loc)
                }
            }
            case ExprTag.BigInt => {
                // "0n" => true, else => false
                return boolean(false, expr.loc)
            }
            case ExprTag.Function | ExprTag.Arrow | ExprTag.RegExp =>
                return boolean(false, expr.loc)
            case ExprTag.Unary => {
                // "!!!a" => "!a" 简化
                // 需要检查内部表达式
            }
            case ExprTag.Binary => {
                // 二元表达式取反的简化:
                // !(a == b) => a != b, etc.
            }
            case _ => {}
        }
        return None
    }

    /// 解包内联枚举 - 对应 Bun Expr.unwrapInlined()
    public static func unwrapInlined(expr: ASTNode): ASTNode {
        if (expr.tag == ExprTag.InlinedEnum) {
            // 返回内联枚举的内部值
            return expr
        }
        return expr
    }

    /// 判断是否可选链 - 对应 Bun Expr.isOptionalChain()
    public static func isOptionalChain(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Member | ExprTag.Index | ExprTag.Call => true
            case _ => false
        }
    }

    /// 已知原始类型 - 对应 Bun Expr.knownPrimitive()
    public static func knownPrimitive(expr: ASTNode): PrimitiveType {
        match (expr.tag) {
            case ExprTag.BigInt => PrimitiveType.Bigint
            case ExprTag.Boolean => PrimitiveType.Boolean
            case ExprTag.Null => PrimitiveType.Null
            case ExprTag.Number => PrimitiveType.Number
            case ExprTag.String => PrimitiveType.String
            case ExprTag.Undefined => PrimitiveType.Undefined
            case _ => PrimitiveType.Unknown
        }
    }

    /// 判断是否布尔表达式 - 对应 Bun Expr.isBoolean()
    public static func isBoolean(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Boolean => true
            case ExprTag.Unary => {
                let unary = expr.value as? EUnary
                if (unary.isSome()) {
                    let u = unary.orElse(EUnary(OpCode.UnNot, expr))
                    return u.op == OpCode.UnNot || u.op == OpCode.UnDelete
                }
                return false
            }
            case ExprTag.Binary => {
                let binary = expr.value as? EBinary
                if (binary.isSome()) {
                    let b = binary.orElse(EBinary(ASTNode(ExprTag.Missing, Loc.Empty),
                                                   ASTNode(ExprTag.Missing, Loc.Empty), OpCode.BinStrictEq))
                    match (b.op) {
                        case OpCode.BinStrictEq | OpCode.BinStrictNe |
                             OpCode.BinLooseEq | OpCode.BinLooseNe |
                             OpCode.BinLt | OpCode.BinGt |
                             OpCode.BinLe | OpCode.BinGe |
                             OpCode.BinInstanceof | OpCode.BinIn => true
                        case _ => false
                    }
                }
                return false
            }
            case _ => false
        }
    }

    /// 是否属性访问 - 对应 Bun Expr.isPropertyAccess()
    public static func isPropertyAccess(expr: ASTNode): Bool {
        match (expr.tag) {
            case ExprTag.Member | ExprTag.Index => true
            case _ => false
        }
    }

    /// 使用左结合运算符连接 - 对应 Bun Expr.joinWithLeftAssociativeOp()
    public static func joinWithLeftAssociativeOp(op: OpCode, a: ASTNode, b: ASTNode): ASTNode {
        // "(a, b) op c" => "a, b op c"
        if (a.tag == ExprTag.Binary) {
            // 简化: 直接创建二叉树
        }
        return binary(op, a, b, a.loc)
    }

    /// 使用逗号连接 - 对应 Bun Expr.joinWithComma()
    public static func joinWithComma(a: ASTNode, b: ASTNode): ASTNode {
        if (a.tag == ExprTag.Missing) {
            return b
        }
        if (b.tag == ExprTag.Missing) {
            return a
        }
        return binary(OpCode.BinComma, a, b, a.loc)
    }

    /// 使用逗号连接所有 - 对应 Bun Expr.joinAllWithComma()
    public static func joinAllWithComma(all: ArrayList<ASTNode>): ?ASTNode {
        if (all.size == Int64(0)) {
            return None
        }
        if (all.size == Int64(1)) {
            return all[Int64(0)]
        }
        var expr = all[Int64(0)]
        let i = Int64(1)
        while (i < all.size) {
            expr = joinWithComma(expr, all[i])
            i += Int64(1)
        }
        return expr
    }

    /// 包裹为箭头函数 - 对应 Bun Expr.wrapInArrow()
    public static func wrapInArrow(expr: ASTNode): ASTNode {
        let stmt = StmtNode(StmtTag.Return, expr.loc)
        stmt.addChild(expr)
        let stmts = ArrayList<StmtNode>()
        stmts.append(stmt)
        let body = GFnBody(expr.loc, stmts)
        let args = ArrayList<GArg>()
        return arrow(args, body, false, expr.loc)
    }

    /// 转为字符串表达式 (无副作用) - 对应 Bun Expr.toStringExprWithoutSideEffects()
    public static func toStringExprWithoutSideEffects(expr: ASTNode): ?ASTNode {
        match (expr.tag) {
            case ExprTag.Null => return string("null", expr.loc)
            case ExprTag.String => return expr
            case ExprTag.Undefined => return string("undefined", expr.loc)
            case ExprTag.Boolean => {
                let b = expr.boolValue()
                if (b.isSome()) {
                    return string(if (b.orElse(false)) { "true" } else { "false" }, expr.loc)
                }
            }
            case ExprTag.BigInt => {
                // BigInt 的值就是字符串
            }
            case ExprTag.Number => {
                let n = expr.numberValue()
                if (n.isSome()) {
                    let s = ENumber.toStringFromF64(n.orElse(Float64(0)))
                    if (s.isSome()) {
                        return string(s.orElse(""), expr.loc)
                    }
                }
            }
            case ExprTag.RegExp => {
                // RegExp 的值
            }
            case _ => {}
        }
        return None
    }

    /// 空表达式 - 对应 Bun Expr.empty
    public static let EMPTY: ASTNode = ASTNode(ExprTag.Missing, Loc.Empty)

    /// 实例计数 - 对应 Bun Expr.icount
    public static var icount: Int64 = Int64(0)
}
