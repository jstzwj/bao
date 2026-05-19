// AST 副作用扫描器
// 严格翻译自: src/js_parser/scan/scan_side_effects.zig (915 lines)
//   Bun 的副作用扫描器用于确定表达式/语句是否有副作用
//   这是 tree shaking (摇树优化) 的核心基础设施
//   包括:
//     SideEffects enum (could_have_side_effects, no_side_effects)
//     Result struct (side_effects, ok, value)
//     canChangeStrictToLoose - 严格比较是否可改为松散比较
//     simplifyBoolean - 布尔表达式简化 (!!, && truthy, || falsy)
//     simplifyUnusedExpr - 未使用表达式简化 (死代码消除)
//     simplifyUnusedBinaryCommaExpr - 逗号/等号表达式简化
//     findIdentifiers - 在绑定中查找标识符
//     shouldKeepStmtInDeadControlFlow - 死代码保留判断
//     shouldKeepStmtsInDeadControlFlow - 批量死代码保留判断
//     isPrimitiveToReorder - 可重排序原始值判断
//     isPrimitiveWithSideEffects - 带副作用的原始值判断
//     toBoolean - 表达式转布尔值
//     toBooleanWithoutDCECheck - 不检查 DCE 的布尔转换
//     toNullOrUndefined - 表达式是否为 null/undefined
//     toNumber / typeof - 委托到 Expr.Data
//   对应 Bun: SideEffects (enum + 方法集)
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// SideEffects - 副作用枚举
// 严格翻译自: scan_side_effects.zig:1-9
//   pub const SideEffects = enum(u1) {
//       could_have_side_effects,
//       no_side_effects,
//   }
// ============================================================================

/// 副作用标志 - 对应 Bun SideEffects
public enum SideEffectFlag {
    | CouldHaveSideEffects    // 可能有副作用
    | NoSideEffects           // 无副作用

    public func isNoSideEffects(): Bool {
        match (this) {
            case NoSideEffects => true
            case _ => false
        }
    }
}

// ============================================================================
// SideEffectResult - 副作用分析结果
// 严格翻译自: scan_side_effects.zig:6-9
//   pub const Result = struct {
//       side_effects: SideEffects,
//       ok: bool = false,
//       value: bool = false,
//   }
// ============================================================================

/// 副作用分析结果 - 对应 Bun SideEffects.Result
public class SideEffectResult {
    /// 副作用标志 - 对应 side_effects
    public var sideEffects: SideEffectFlag
    /// 是否确定 - 对应 ok: bool
    public var ok: Bool
    /// 布尔值 - 对应 value: bool
    public var value: Bool

    public init(sideEffects: SideEffectFlag, ok: Bool, value: Bool) {
        this.sideEffects = sideEffects
        this.ok = ok
        this.value = value
    }

    public init() {
        sideEffects = SideEffectFlag.CouldHaveSideEffects
        ok = false
        value = false
    }

    /// 创建已知结果 (无副作用)
    public static func known(value: Bool): SideEffectResult {
        return SideEffectResult(SideEffectFlag.NoSideEffects, true, value)
    }

    /// 创建已知结果 (可能有副作用)
    public static func knownWithSideEffects(value: Bool): SideEffectResult {
        return SideEffectResult(SideEffectFlag.CouldHaveSideEffects, true, value)
    }

    /// 创建未知结果
    public static func unknown(): SideEffectResult {
        return SideEffectResult(SideEffectFlag.CouldHaveSideEffects, false, false)
    }
}

// ============================================================================
// SideEffects - 副作用分析工具集
// 严格翻译自: scan_side_effects.zig:1-892
//   所有静态方法集合
// ============================================================================

/// 副作用分析工具集 - 对应 Bun SideEffects
/// 提供静态方法来判断表达式/语句的副作用特性
public class SideEffects {

    // ========================================================================
    // canChangeStrictToLoose - 严格比较是否可改为松散比较
    // 严格翻译自: scan_side_effects.zig:11-15
    //   pub fn canChangeStrictToLoose(lhs: Expr.Data, rhs: Expr.Data) bool {
    //       const left = lhs.knownPrimitive();
    //       const right = rhs.knownPrimitive();
    //       return left == right and left != .unknown and left != .mixed;
    //   }
    // ========================================================================

    /// 检查严格比较是否可以安全改为松散比较
    /// 对应 Bun SideEffects.canChangeStrictToLoose
    /// 如果两边是相同类型的已知原始值，可以安全改为松散比较
    public static func canChangeStrictToLoose(left: Expr, right: Expr): Bool {
        let leftPrim = knownPrimitive(left)
        let rightPrim = knownPrimitive(right)
        return leftPrim == rightPrim && leftPrim != "unknown" && leftPrim != "mixed"
    }

    // ========================================================================
    // simplifyBoolean - 简化布尔表达式
    // 严格翻译自: scan_side_effects.zig:17-64
    //   pub fn simplifyBoolean(p: anytype, expr: Expr) Expr {
    //       if (!p.options.features.dead_code_elimination) return expr;
    //       var result: Expr = expr;
    //       _simplifyBoolean(p, &result);
    //       return result;
    //   }
    //
    //   fn _simplifyBoolean(p: anytype, expr: *Expr) void {
    //       while (true) {
    //           switch (expr.data) {
    //               .e_unary => |e| {
    //                   if (e.op == .un_not) {
    //                       // "!!a" => "a"
    //                       if (e.value.data == .e_unary and e.value.data.e_unary.op == .un_not) {
    //                           expr.* = e.value.data.e_unary.value;
    //                           continue;
    //                       }
    //                       _simplifyBoolean(p, &e.value);
    //                   }
    //               },
    //               .e_binary => |e| {
    //                   switch (e.op) {
    //                       .bin_logical_and => { ... }
    //                       .bin_logical_or => { ... }
    //                       else => {},
    //                   }
    //               },
    //               else => {},
    //           }
    //           break;
    //       }
    //   }
    // ========================================================================

    /// 简化布尔表达式
    /// 对应 Bun SideEffects.simplifyBoolean
    /// 例如: !!a => a, if (anything && truthyNoSideEffects) => if (anything)
    public static func simplifyBoolean(parser: Parser, expr: Expr): Expr {
        if (!parser.options.deadCodeElimination) { return expr }
        var result = expr
        // 迭代简化直到无法继续
        var changed = true
        while (changed) {
            changed = false

            match (result.tag) {
                case ExprTag.Unary =>
                    if (result.op == OpCode.UnNot) {
                        // !!a => a
                        if (let Some(inner) <- result.value) {
                            if (inner.tag == ExprTag.Unary && inner.op == OpCode.UnNot) {
                                if (let Some(innerVal) <- inner.value) {
                                    result = innerVal
                                    changed = true
                                }
                            }
                        }
                    }
                case ExprTag.Binary =>
                    if (result.op == OpCode.BinLoAnd) {
                        // "if (anything && truthyNoSideEffects)" => "if (anything)"
                        if (let Some(right) <- result.right) {
                            let effects = toBoolean(parser, right)
                            if (effects.ok && effects.value && effects.sideEffects.isNoSideEffects()) {
                                if (let Some(left) <- result.left) {
                                    result = left
                                    changed = true
                                }
                            }
                        }
                    } else if (result.op == OpCode.BinLoOr) {
                        // "if (anything || falsyNoSideEffects)" => "if (anything)"
                        if (let Some(right) <- result.right) {
                            let effects = toBoolean(parser, right)
                            if (effects.ok && !effects.value && effects.sideEffects.isNoSideEffects()) {
                                if (let Some(left) <- result.left) {
                                    result = left
                                    changed = true
                                }
                            }
                        }
                    }
                case _ =>
                    ()
            }
        }

        return result
    }

    // ========================================================================
    // isPrimitiveToReorder - 是否为可重排序的原始值
    // 严格翻译自: scan_side_effects.zig:69-83
    //   pub fn isPrimitiveToReorder(data: Expr.Data) bool {
    //       return switch (data) {
    //           .e_null, .e_undefined, .e_string, .e_boolean,
    //           .e_branch_boolean, .e_number, .e_big_int,
    //           .e_inlined_enum, .e_require_main => true,
    //           else => false,
    //       };
    //   }
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
    // simplifyUnusedExpr - 简化未使用的表达式
    // 严格翻译自: scan_side_effects.zig:85-356
    //   pub fn simplifyUnusedExpr(p: anytype, expr: Expr) ?Expr
    //
    //   如果表达式可以被完全移除，返回 null
    //   处理以下表达式类型:
    //     e_null, e_undefined, e_missing, e_boolean, e_number, e_big_int,
    //     e_string, e_this, e_reg_exp, e_function, e_arrow, e_import_meta,
    //     e_inlined_enum -> return null (完全无副作用)
    //     e_dot -> can_be_removed_if_unused
    //     e_identifier -> must_keep_due_to_with_stmt / can_be_removed_if_unused / unbound
    //     e_if -> 递归简化 + 合并
    //     e_unary -> void/not/typeof 特殊处理
    //     e_call/e_new -> __PURE__ 标注处理
    //     e_binary -> strict_eq/ne/comma 逗号简化, loose_eq/ne 比较, 逻辑运算
    //     e_object -> spread 处理 + 计算键 + 递归
    //     e_array -> spread 处理 + 递归
    // ========================================================================

    /// 简化未使用的表达式
    /// 对应 Bun SideEffects.simplifyUnusedExpr
    /// 如果表达式可以被完全移除，返回 null
    public static func simplifyUnusedExpr(parser: Parser, expr: Expr): ?Expr {
        if (!parser.options.deadCodeElimination) { return Some(expr) }

        match (expr.tag) {
            // 无副作用的字面量可以移除
            // 对应 Bun:
            //   .e_null, .e_undefined, .e_missing, .e_boolean, .e_branch_boolean,
            //   .e_number, .e_big_int, .e_string, .e_this, .e_reg_exp,
            //   .e_function, .e_arrow, .e_import_meta, .e_inlined_enum => return null
            case ExprTag.Null | ExprTag.Undefined | ExprTag.Missing |
                 ExprTag.Boolean | ExprTag.Number | ExprTag.BigInt |
                 ExprTag.String | ExprTag.ThisExpr | ExprTag.Regex |
                 ExprTag.Function | ExprTag.Arrow =>
                return None

            // e_dot: 如果可移除
            // 对应 Bun: .e_dot => |dot| { if (dot.can_be_removed_if_unused) return null; }
            case ExprTag.Dot =>
                if (expr.canBeRemovedIfUnused) {
                    return None
                }

            // e_identifier: with 语句/可移除/非未绑定
            // 对应 Bun:
            //   .e_identifier => |ident| {
            //       if (ident.must_keep_due_to_with_stmt) return expr;
            //       if (ident.can_be_removed_if_unused or
            //           p.symbols.items[ident.ref.innerIndex()].kind != .unbound)
            //           return null;
            //   }
            case ExprTag.Identifier =>
                if (expr.mustKeepDueToWithStmt) {
                    return Some(expr)
                }
                if (expr.canBeRemovedIfUnused) {
                    return None
                }
                let symbol = parser.symbols.get(expr.ref.innerIndex())
                if (symbol.kind != SymbolKind.Unbound) {
                    return None
                }

            // e_if (三元表达式)
            // 对应 Bun:
            //   .e_if => |ternary| {
            //       ternary.yes = simplifyUnusedExpr(p, ternary.yes) orelse ternary.yes.toEmpty();
            //       ternary.no = simplifyUnusedExpr(p, ternary.no) orelse ternary.no.toEmpty();
            //       if (ternary.yes.isEmpty() and ternary.no.isEmpty())
            //           return simplifyUnusedExpr(p, ternary.test_);
            //       if (ternary.yes.isEmpty())
            //           return Expr.joinWithLeftAssociativeOp(.bin_logical_or, ternary.test_, ternary.no, ...);
            //       if (ternary.no.isEmpty())
            //           return Expr.joinWithLeftAssociativeOp(.bin_logical_and, ternary.test_, ternary.yes, ...);
            //   }
            case ExprTag.Ternary =>
                var yesVal = expr.yes
                var noVal = expr.no
                let simplifiedYes = if (let Some(y) <- yesVal) { simplifyUnusedExpr(parser, y) } else { None }
                let simplifiedNo = if (let Some(n) <- noVal) { simplifyUnusedExpr(parser, n) } else { None }

                let emptyYes = simplifiedYes == None
                let emptyNo = simplifiedNo == None

                // "foo() ? 1 : 2" => "foo()"
                if (emptyYes && emptyNo) {
                    if (let Some(t) <- expr.test) {
                        return simplifyUnusedExpr(parser, t)
                    }
                }

                // "foo() ? 1 : bar()" => "foo() || bar()"
                if (emptyYes) {
                    if (let Some(t) <- expr.test) {
                        if (let Some(n) <- noVal) {
                            return Some(joinWithLeftAssociativeOp(OpCode.BinLoOr, t, n, parser))
                        }
                    }
                }

                // "foo() ? bar() : 2" => "foo() && bar()"
                if (emptyNo) {
                    if (let Some(t) <- expr.test) {
                        if (let Some(y) <- yesVal) {
                            return Some(joinWithLeftAssociativeOp(OpCode.BinLoAnd, t, y, parser))
                        }
                    }
                }

            // e_unary: void/not/typeof 特殊处理
            // 对应 Bun:
            //   .e_unary => |un| {
            //       switch (un.op) {
            //           .un_void, .un_not => return simplifyUnusedExpr(p, un.value),
            //           .un_typeof => {
            //               if (un.value.data == .e_identifier and un.flags.was_originally_typeof_identifier)
            //                   return null;
            //               return simplifyUnusedExpr(p, un.value);
            //           },
            //           else => {},
            //       }
            //   }
            case ExprTag.Unary =>
                match (expr.op) {
                    case OpCode.UnVoid | OpCode.UnNot =>
                        if (let Some(v) <- expr.value) {
                            return simplifyUnusedExpr(parser, v)
                        }
                    case OpCode.Typeof =>
                        // "typeof x" 不会抛出异常, 可以直接移除
                        if (let Some(v) <- expr.value) {
                            if (v.tag == ExprTag.Identifier && expr.wasOriginallyTypeofIdentifier) {
                                return None
                            }
                            return simplifyUnusedExpr(parser, v)
                        }
                    case _ =>
                        ()
                }

            // e_call / e_new: __PURE__ 标注处理
            // 对应 Bun:
            //   inline .e_call, .e_new => |call| {
            //       if (call.can_be_unwrapped_if_unused != .never) {
            //           if (call.args.len > 0) {
            //               const joined = Expr.joinAllWithCommaCallback(...);
            //               ...
            //           } else return null;
            //       }
            //   }
            case ExprTag.Call | ExprTag.New =>
                if (expr.canBeUnwrappedIfUnused != CanBeUnwrapped.Never) {
                    if (expr.args.size > 0) {
                        var joined: ?Expr = None
                        for (arg in expr.args) {
                            let simplified = simplifyUnusedExpr(parser, arg)
                            if (simplified != None) {
                                if (let Some(j) <- joined) {
                                    joined = Some(joinWithComma(j, simplified.getOrElse(arg), parser))
                                } else {
                                    joined = simplified
                                }
                            }
                        }
                        // 对于 toString_safe, 检查安全性
                        if (joined != None && expr.canBeUnwrappedIfUnused == CanBeUnwrapped.IfUnusedAndToStringSafe) {
                            if (let Some(j) <- joined) {
                                if (isSafeToString(j)) {
                                    return None
                                }
                            }
                        }
                        return joined
                    } else {
                        return None
                    }
                }

            // e_binary: 逗号/等号简化
            // 对应 Bun:
            //   .e_binary => |bin| {
            //       switch (bin.op) {
            //           .bin_strict_eq, .bin_strict_ne, .bin_comma
            //               => return simplifyUnusedBinaryCommaExpr(p, expr),
            //           .bin_loose_eq, .bin_loose_ne, .bin_lt, .bin_gt, .bin_le, .bin_ge => { ... }
            //           .bin_logical_and, .bin_logical_or, .bin_nullish_coalescing => { ... }
            //           else => {},
            //       }
            //   }
            case ExprTag.Binary =>
                match (expr.op) {
                    case OpCode.BinEqStrict | OpCode.BinNeStrict | OpCode.Comma =>
                        return simplifyUnusedBinaryCommaExpr(parser, expr)

                    case OpCode.BinEq | OpCode.BinNe |
                         OpCode.BinLt | OpCode.BinGt | OpCode.BinLe | OpCode.BinGe =>
                        // 对应 Bun: loose_eq/ne 和比较运算
                        if (let Some(left) <- expr.left) {
                            if (let Some(right) <- expr.right) {
                                if (isPrimitiveWithSideEffects(left) && isPrimitiveWithSideEffects(right)) {
                                    let leftSimplified = simplifyUnusedExpr(parser, left)
                                    let rightSimplified = simplifyUnusedExpr(parser, right)
                                    if (leftSimplified == None && rightSimplified == None) {
                                        return None
                                    }
                                    return Some(joinWithComma(
                                        leftSimplified.getOrElse(left),
                                        rightSimplified.getOrElse(right),
                                        parser
                                    ))
                                }
                            }
                        }
                        // 对于 loose_eq/ne: 数字侧可优化为 0
                        if (expr.op == OpCode.BinEq || expr.op == OpCode.BinNe) {
                            if (let Some(left) <- expr.left) {
                                if (left.tag == ExprTag.Number) {
                                    left.numberValue = 0.0
                                }
                            }
                            if (let Some(right) <- expr.right) {
                                if (right.tag == ExprTag.Number) {
                                    right.numberValue = 0.0
                                }
                            }
                        }

                    case OpCode.BinLoAnd | OpCode.BinLoOr | OpCode.BinNullish =>
                        // 对应 Bun: 逻辑运算 - 保留短路行为
                        if (let Some(right) <- expr.right) {
                            let simplifiedRight = simplifyUnusedExpr(parser, right)
                            if (simplifiedRight == None) {
                                // 右侧可完全移除, 简化左侧
                                if (let Some(left) <- expr.left) {
                                    return simplifyUnusedExpr(parser, left)
                                }
                            }
                        }

                    case _ =>
                        ()
                }

            // e_object: spread + 计算键 + 递归
            // 对应 Bun: scan_side_effects.zig:259-323
            case ExprTag.Object =>
                let properties = expr.properties
                var hasSpread = false
                for (`prop` in properties) {
                    if (`prop`.kind == GPropertyKind.Spread) {
                        hasSpread = true
                    }
                }

                if (hasSpread) {
                    // 有 spread 的对象不能完全移除
                    // 保留 spread 和计算键, 移除其他
                    var end = 0
                    for (`prop` in properties) {
                        if (`prop`.kind == GPropertyKind.Spread) {
                            // Spread 属性必须保留
                            properties[Int64(end)] = `prop`
                            end += 1
                        } else {
                            // 非计算键属性: 简化值
                            if (let Some(v) <- `prop`.value) {
                                let simplified = simplifyUnusedExpr(parser, v)
                                if (simplified != None) {
                                    `prop`.value = simplified
                                } else if (!`prop`.flags.isComputed) {
                                    continue // 跳过
                                } else {
                                    // 计算键保留, 值替换为 0
                                    `prop`.value = Some(Expr.number(`prop`.loc, 0.0))
                                }
                            }
                            properties[Int64(end)] = `prop`
                            end += 1
                        }
                    }
                    return Some(expr)
                }

                // 无 spread 的对象: 只需保留计算键的 ToString 和有副作用的值
                var result = Expr.missing(expr.loc)
                for (`prop` in properties) {
                    if (`prop`.flags.isComputed) {
                        // 确保 ToString 仍然求值
                        if (let Some(key) <- `prop`.keyExpr) {
                            let addExpr = Expr.binary(`prop`.loc, key, Expr.string(`prop`.loc, ""), OpCode.BinAdd)
                            result = joinWithComma(result, addExpr, parser)
                        }
                    }
                    if (let Some(v) <- `prop`.value) {
                        let simplified = simplifyUnusedExpr(parser, v)
                        if (simplified != None) {
                            result = joinWithComma(result, simplified.getOrElse(v), parser)
                        }
                    }
                }
                if (result.tag == ExprTag.Missing) {
                    return None
                }
                return Some(result)

            // e_array: spread 处理 + 递归
            // 对应 Bun: scan_side_effects.zig:324-350
            case ExprTag.Array =>
                let items = expr.items
                var hasSpread = false
                for (item in items) {
                    if (item.tag == ExprTag.Spread) {
                        hasSpread = true
                    }
                }

                if (hasSpread) {
                    // 有 spread 的数组: 保留非 missing 元素
                    var end = 0
                    for (item in items) {
                        if (item.tag != ExprTag.Missing) {
                            items[Int64(end)] = item
                            end += 1
                        }
                    }
                    return Some(expr)
                }

                // 无 spread 的数组: 递归简化每个元素
                var anySideEffects = false
                for (item in items) {
                    let simplified = simplifyUnusedExpr(parser, item)
                    if (simplified != None) {
                        anySideEffects = true
                    }
                }
                if (!anySideEffects) {
                    return None
                }
                return Some(expr)

            case _ =>
                ()
        }

        return Some(expr)
    }

    // ========================================================================
    // simplifyUnusedBinaryCommaExpr - 逗号/等号表达式简化
    // 严格翻译自: scan_side_effects.zig:363-406
    //   fn simplifyUnusedBinaryCommaExpr(p: anytype, expr: Expr) ?Expr
    //   使用栈处理左结合的逗号/严格等号/严格不等号链
    //   从最左边的表达式开始, 逐个简化并合并
    // ========================================================================

    /// 简化逗号/等号表达式
    /// 对应 Bun simplifyUnusedBinaryCommaExpr
    private static func simplifyUnusedBinaryCommaExpr(parser: Parser, expr: Expr): ?Expr {
        // 构建嵌套的逗号/等号链栈
        let stack = ArrayList<Expr>()
        stack.append(expr)

        var leftExpr = expr.left
        // 对应 Bun:
        //   while (left.data.as(.e_binary)) |left_bin| {
        //       switch (left_bin.op) {
        //           .bin_strict_eq, .bin_strict_ne, .bin_comma => {
        //               stack.append(left_bin);
        //               left = left_bin.left;
        //           },
        //           else => break,
        //       }
        //   }
        var left = leftExpr
        while (left != None) {
            if (let Some(l) <- left) {
                if (l.tag == ExprTag.Binary) {
                    if (l.op == OpCode.BinEqStrict || l.op == OpCode.BinNeStrict || l.op == OpCode.Comma) {
                        stack.append(l)
                        left = l.left
                        continue
                    }
                }
            }
            break
        }

        // 从栈底向上简化
        // 对应 Bun:
        //   var i = stack.items.len;
        //   var result = simplifyUnusedExpr(p, left) orelse Expr.empty;
        //   while (i > stack_bottom) {
        //       i -= 1;
        //       const top = stack.items[i];
        //       const visited_right = simplifyUnusedExpr(p, top.bin.right) orelse Expr.empty;
        //       result = result.joinWithComma(visited_right, p.allocator);
        //   }
        //   return if (result.isMissing()) null else result;
        var result = if (let Some(l) <- left) {
            simplifyUnusedExpr(parser, l).getOrElse(Expr())
        } else {
            Expr()
        }

        var i = stack.size - 1
        while (i > 0) {
            i -= 1
            let top = stack[Int64(i)]
            let topRight = top.right
            let visitedRight = if (let Some(r) <- topRight) {
                simplifyUnusedExpr(parser, r).getOrElse(Expr())
            } else {
                Expr()
            }
            result = joinWithComma(result, visitedRight, parser)
        }

        if (result.tag == ExprTag.Missing) {
            return None
        }
        return Some(result)
    }

    // ========================================================================
    // findIdentifiers - 在绑定中查找标识符
    // 严格翻译自: scan_side_effects.zig:408-425
    //   fn findIdentifiers(binding: Binding, decls: *std.array_list.Managed(G.Decl)) void {
    //       switch (binding.data) {
    //           .b_identifier => decls.append(.{ .binding = binding }),
    //           .b_array => |array| for (array.items) |item| findIdentifiers(item.binding, decls),
    //           .b_object => |obj| for (obj.properties) |item| findIdentifiers(item.value, decls),
    //           else => {},
    //       }
    //   }
    // ========================================================================

    /// 在绑定模式中查找所有标识符
    /// 对应 Bun findIdentifiers
    /// 用于死代码中保留 var 声明时提取标识符
    public static func findIdentifiers(binding: Binding, decls: ArrayList<GDecl>): Unit {
        match (binding.tag) {
            case BindingTag.Identifier =>
                decls.append(GDecl(binding))
            case BindingTag.ArrayPattern =>
                for (item in binding.arrayItems) {
                    findIdentifiers(item.binding, decls)
                }
            case BindingTag.ObjectPattern =>
                for (item in binding.objectProperties) {
                    findIdentifiers(item.value, decls)
                }
            case _ =>
                ()
        }
    }

    // ========================================================================
    // shouldKeepStmtsInDeadControlFlow - 批量死代码保留判断
    // 严格翻译自: scan_side_effects.zig:427-434
    //   fn shouldKeepStmtsInDeadControlFlow(stmts: []Stmt, allocator: Allocator) bool {
    //       for (stmts) |child| {
    //           if (shouldKeepStmtInDeadControlFlow(child, allocator)) return true;
    //       }
    //       return false;
    //   }
    // ========================================================================

    /// 检查语句列表中是否有需要保留的语句
    public static func shouldKeepStmtsInDeadControlFlow(stmts: ArrayList<Stmt>): Bool {
        for (child in stmts) {
            if (shouldKeepStmtInDeadControlFlow(child)) {
                return true
            }
        }
        return false
    }

    // ========================================================================
    // shouldKeepStmtInDeadControlFlow - 死代码中是否保留语句
    // 严格翻译自: scan_side_effects.zig:449-544
    //   pub fn shouldKeepStmtInDeadControlFlow(stmt: Stmt, allocator: Allocator) bool
    //
    //   如果在死分支中，尽可能裁剪死代码
    //   所有语句都可以裁剪，除了提升声明 ("var" 和 "function")
    //   例如:
    //     function foo() {
    //       if (false) { var x; }
    //       x = 1;
    //     }
    //   不能将整个分支裁剪为死代码，否则 foo() 会错误地赋值给全局变量
    // ========================================================================

    /// 检查死代码分支中是否需要保留语句
    /// 对应 Bun SideEffects.shouldKeepStmtInDeadControlFlow
    /// 只有 hoisted declarations ("var" 和 "function") 需要保留
    public static func shouldKeepStmtInDeadControlFlow(stmt: Stmt): Bool {
        match (stmt.tag) {
            // 完全可以移除
            // 对应 Bun: .s_empty, .s_expr, .s_throw, .s_return, .s_break, .s_continue, .s_class, .s_debugger => return false
            case StmtTag.Empty | StmtTag.Expr | StmtTag.Throw |
                 StmtTag.Return | StmtTag.Break | StmtTag.Continue |
                 StmtTag.Class | StmtTag.Debugger =>
                return false

            case StmtTag.Local =>
                // 对应 Bun: .s_local => |local| {
                //     if (local.kind != .k_var) return false;
                //     // 只保留标识符, 移除初始值
                // }
                match (stmt.declKind) {
                    case DeclKind.Var =>
                        // var 声明需要保留 (函数级提升)
                        // 但只保留标识符, 移除初始值
                        // 对应 Bun: common case: single var foo = blah, don't need to allocate
                        return true
                    case _ =>
                        // let/const 声明可以移除
                        return false
                }

            case StmtTag.Block =>
                // 对应 Bun: .s_block => |block| return shouldKeepStmtsInDeadControlFlow(block.stmts, allocator)
                if (let Some(body) <- stmt.blockBody) {
                    return shouldKeepStmtsInDeadControlFlow(body)
                }
                return false

            case StmtTag.Try =>
                // 对应 Bun: .s_try => |try_stmt| { ... }
                // 检查 try/catch/finally 各部分
                if (shouldKeepStmtsInDeadControlFlow(stmt.stmts)) {
                    return true
                }
                if (stmt.catchBody != None) {
                    if (let Some(catchBody) <- stmt.catchBody) {
                        if (shouldKeepStmtsInDeadControlFlow(catchBody)) {
                            return true
                        }
                    }
                }
                if (stmt.finallyBody != None) {
                    if (let Some(finallyBody) <- stmt.finallyBody) {
                        if (shouldKeepStmtsInDeadControlFlow(finallyBody)) {
                            return true
                        }
                    }
                }
                return false

            case StmtTag.If =>
                // 对应 Bun: .s_if => |_if_| { ... }
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

            case StmtTag.While =>
                // 对应 Bun: .s_while => return shouldKeepStmtInDeadControlFlow(stmt.data.s_while.body, allocator)
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false

            case StmtTag.DoWhile =>
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false

            case StmtTag.For =>
                // 对应 Bun: .s_for => |__for__| { ... }
                if (let Some(`init`) <- stmt.`init`) {
                    if (shouldKeepStmtInDeadControlFlow(`init`)) {
                        return true
                    }
                }
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false

            case StmtTag.ForIn =>
                // 对应 Bun: .s_for_in => |__for__| {
                //     return shouldKeepStmtInDeadControlFlow(__for__.init, allocator)
                //         or shouldKeepStmtInDeadControlFlow(__for__.body, allocator);
                // }
                if (let Some(`init`) <- stmt.`init`) {
                    if (shouldKeepStmtInDeadControlFlow(`init`)) {
                        return true
                    }
                }
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false

            case StmtTag.ForOf =>
                if (let Some(`init`) <- stmt.`init`) {
                    if (shouldKeepStmtInDeadControlFlow(`init`)) {
                        return true
                    }
                }
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false

            case StmtTag.Labeled =>
                // 对应 Bun: .s_label => |label| return shouldKeepStmtInDeadControlFlow(label.stmt, allocator)
                if (let Some(body) <- stmt.body) {
                    return shouldKeepStmtInDeadControlFlow(body)
                }
                return false

            // 默认保留 (安全起见)
            // 对应 Bun: else => return true
            case _ =>
                return true
        }
    }

    // ========================================================================
    // isPrimitiveWithSideEffects - 是否为带副作用的原始值
    // 严格翻译自: scan_side_effects.zig:549-650
    //   pub fn isPrimitiveWithSideEffects(data: Expr.Data) bool {
    //     switch (data) {
    //       .e_null, .e_undefined, ... => true,
    //       .e_unary => |e| switch (e.op) { ... => true },
    //       .e_binary => |e| switch (e.op) {
    //         ... => true,
    //         .bin_logical_and, .bin_logical_or, .bin_nullish_coalescing,
    //         .bin_logical_and_assign, .bin_logical_or_assign,
    //         .bin_nullish_coalescing_assign => {
    //             return isPrimitiveWithSideEffects(e.left.data) and
    //                    isPrimitiveWithSideEffects(e.right.data);
    //         },
    //         .bin_comma => return isPrimitiveWithSideEffects(e.right.data),
    //         ...
    //       },
    //       .e_if => |e| return isPrimitiveWithSideEffects(e.yes.data) and
    //                        isPrimitiveWithSideEffects(e.no.data),
    //       else => false,
    //     }
    //   }
    // ========================================================================

    /// 检查表达式是否为原始值 (即使可能有副作用)
    /// 对应 Bun SideEffects.isPrimitiveWithSideEffects
    public static func isPrimitiveWithSideEffects(expr: Expr): Bool {
        match (expr.tag) {
            case ExprTag.Null | ExprTag.Undefined | ExprTag.Boolean |
                 ExprTag.Number | ExprTag.BigInt | ExprTag.String =>
                return true

            case ExprTag.Unary =>
                // 所有一元运算都返回原始值
                // 对应 Bun: .un_pos, .un_neg, .un_cpl, .un_pre_dec, .un_pre_inc,
                //           .un_post_dec, .un_post_inc, .un_not, .un_delete, .un_void, .un_typeof
                match (expr.op) {
                    case OpCode.UnPos | OpCode.UnNeg | OpCode.UnCpl |
                         OpCode.UnPreDec | OpCode.UnPreInc |
                         OpCode.UnPostDec | OpCode.UnPostInc |
                         OpCode.UnNot | OpCode.UnDelete |
                         OpCode.UnVoid | OpCode.Typeof =>
                        return true
                    case _ =>
                        return false
                }

            case ExprTag.Binary =>
                match (expr.op) {
                    // 布尔运算符
                    case OpCode.BinLt | OpCode.BinGt | OpCode.BinLe | OpCode.BinGe |
                         OpCode.BinIn | OpCode.BinInstanceof |
                         OpCode.BinEq | OpCode.BinNe |
                         OpCode.BinEqStrict | OpCode.BinNeStrict =>
                        return true

                    // 算术/位运算符 (返回 string/number/bigint)
                    case OpCode.BinAdd | OpCode.BinSub | OpCode.BinMul |
                         OpCode.BinDiv | OpCode.BinRem | OpCode.BinPow |
                         OpCode.BinShl | OpCode.BinShr | OpCode.BinUShr |
                         OpCode.BinAnd | OpCode.BinOr | OpCode.BinXor =>
                        return true

                    // 赋值运算符 (返回原始值)
                    case OpCode.BinAddAssign | OpCode.BinSubAssign |
                         OpCode.BinMulAssign | OpCode.BinDivAssign |
                         OpCode.BinRemAssign | OpCode.BinPowAssign |
                         OpCode.BinShlAssign | OpCode.BinShrAssign |
                         OpCode.BinUShrAssign |
                         OpCode.BinAndAssign | OpCode.BinOrAssign |
                         OpCode.BinXorAssign =>
                        return true

                    // 逻辑运算: 递归检查两侧
                    case OpCode.BinLoAnd | OpCode.BinLoOr | OpCode.BinNullish =>
                        if (let Some(left) <- expr.left) {
                            if (let Some(right) <- expr.right) {
                                return isPrimitiveWithSideEffects(left) && isPrimitiveWithSideEffects(right)
                            }
                        }
                        return false

                    // 逗号: 只看右侧
                    case OpCode.Comma =>
                        if (let Some(right) <- expr.right) {
                            return isPrimitiveWithSideEffects(right)
                        }
                        return false

                    case _ =>
                        return false
                }

            case ExprTag.Ternary =>
                if (let Some(yes) <- expr.yes) {
                    if (let Some(no) <- expr.no) {
                        return isPrimitiveWithSideEffects(yes) && isPrimitiveWithSideEffects(no)
                    }
                }
                return false

            case _ =>
                return false
        }
    }

    // ========================================================================
    // toBoolean - 将表达式数据转为布尔值
    // 严格翻译自: scan_side_effects.zig:763-891
    //   pub fn toBoolean(p: anytype, exp: Expr.Data) Result {
    //       if (!p.options.features.dead_code_elimination) return Result{ .ok = false, ... };
    //       return toBooleanWithoutDCECheck(exp);
    //   }
    // ========================================================================

    /// 将表达式转为布尔值结果
    /// 对应 Bun SideEffects.toBoolean
    public static func toBoolean(parser: Parser, expr: Expr): SideEffectResult {
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
                return SideEffectResult.known(expr.stringValue.toString().size > 0)

            // 函数、正则表达式总是 truthy
            case ExprTag.Function | ExprTag.Arrow | ExprTag.Regex =>
                return SideEffectResult.known(true)

            // 对象和数组总是 truthy (可能有副作用)
            case ExprTag.Object | ExprTag.Array | ExprTag.Class =>
                return SideEffectResult.knownWithSideEffects(true)

            // 一元表达式
            case ExprTag.Unary =>
                match (expr.op) {
                    case OpCode.UnVoid =>
                        // void 总是返回 undefined, 即 falsy
                        return SideEffectResult.knownWithSideEffects(false)
                    case OpCode.Typeof =>
                        // typeof 总是返回非空字符串, 即 truthy
                        return SideEffectResult.knownWithSideEffects(true)
                    case OpCode.UnNot =>
                        // !x 取反
                        if (let Some(value) <- expr.value) {
                            let innerResult = toBooleanWithoutDCECheck(value)
                            if (innerResult.ok) {
                                return SideEffectResult(innerResult.sideEffects, true, !innerResult.value)
                            }
                        }
                    case _ =>
                        ()
                }

            // 二元表达式中的逻辑运算
            case ExprTag.Binary =>
                if (expr.op == OpCode.BinLoOr) {
                    // "anything || truthy" is truthy
                    if (let Some(right) <- expr.right) {
                        let result = toBooleanWithoutDCECheck(right)
                        if (result.value && result.ok) {
                            return SideEffectResult.knownWithSideEffects(true)
                        }
                    }
                } else if (expr.op == OpCode.BinLoAnd) {
                    // "anything && falsy" is falsy
                    if (let Some(right) <- expr.right) {
                        let result = toBooleanWithoutDCECheck(right)
                        if (!result.value && result.ok) {
                            return SideEffectResult.knownWithSideEffects(false)
                        }
                    }
                } else if (expr.op == OpCode.Comma) {
                    // "anything, truthy/falsy" is truthy/falsy
                    if (let Some(right) <- expr.right) {
                        let result = toBooleanWithoutDCECheck(right)
                        if (result.ok) {
                            return SideEffectResult.knownWithSideEffects(result.value)
                        }
                    }
                } else if (expr.op == OpCode.BinGt) {
                    // 对应 Bun: .bin_gt => if left/right finite => left > right
                    if (let Some(left) <- expr.left) {
                        if (let Some(right) <- expr.right) {
                            if (let Some(leftNum) <- toFiniteNumber(left)) {
                                if (let Some(rightNum) <- toFiniteNumber(right)) {
                                    return SideEffectResult.known(leftNum > rightNum)
                                }
                            }
                        }
                    }
                } else if (expr.op == OpCode.BinLt) {
                    if (let Some(left) <- expr.left) {
                        if (let Some(right) <- expr.right) {
                            if (let Some(leftNum) <- toFiniteNumber(left)) {
                                if (let Some(rightNum) <- toFiniteNumber(right)) {
                                    return SideEffectResult.known(leftNum < rightNum)
                                }
                            }
                        }
                    }
                } else if (expr.op == OpCode.BinLe) {
                    if (let Some(left) <- expr.left) {
                        if (let Some(right) <- expr.right) {
                            if (let Some(leftNum) <- toFiniteNumber(left)) {
                                if (let Some(rightNum) <- toFiniteNumber(right)) {
                                    return SideEffectResult.known(leftNum <= rightNum)
                                }
                            }
                        }
                    }
                } else if (expr.op == OpCode.BinGe) {
                    if (let Some(left) <- expr.left) {
                        if (let Some(right) <- expr.right) {
                            if (let Some(leftNum) <- toFiniteNumber(left)) {
                                if (let Some(rightNum) <- toFiniteNumber(right)) {
                                    return SideEffectResult.known(leftNum >= rightNum)
                                }
                            }
                        }
                    }
                }

            case _ =>
                ()
        }

        return SideEffectResult.unknown()
    }

    // ========================================================================
    // toNullOrUndefined - 检查表达式是否为 null 或 undefined
    // 严格翻译自: scan_side_effects.zig:654-761
    //   pub fn toNullOrUndefined(p: anytype, exp: Expr.Data) Result {
    //       if (!p.options.features.dead_code_elimination) return Result{ .ok = false, ... };
    //       switch (exp) {
    //           // Never null or undefined
    //           .e_boolean, .e_branch_boolean, .e_number, .e_string,
    //           .e_reg_exp, .e_function, .e_arrow, .e_big_int =>
    //               return Result{ .value = false, .side_effects = .no_side_effects, .ok = true },
    //           .e_object, .e_array, .e_class =>
    //               return Result{ .value = false, .side_effects = .could_have_side_effects, .ok = true },
    //           .e_null, .e_undefined =>
    //               return Result{ .value = true, .side_effects = .no_side_effects, .ok = true },
    //           .e_unary => ...
    //           .e_binary => ...
    //           ...
    //       }
    //   }
    // ========================================================================

    /// 检查表达式是否为 null 或 undefined
    /// 对应 Bun SideEffects.toNullOrUndefined
    public static func toNullOrUndefined(parser: Parser, expr: Expr): SideEffectResult {
        if (!parser.options.deadCodeElimination) {
            return SideEffectResult.unknown()
        }

        match (expr.tag) {
            // 绝对不是 null/undefined
            case ExprTag.Boolean | ExprTag.Number | ExprTag.String |
                 ExprTag.Regex | ExprTag.Function | ExprTag.Arrow | ExprTag.BigInt =>
                return SideEffectResult.known(false)

            // 对象和数组绝对不是 null/undefined (可能有副作用)
            case ExprTag.Object | ExprTag.Array | ExprTag.Class =>
                return SideEffectResult.knownWithSideEffects(false)

            // null 和 undefined
            case ExprTag.Null | ExprTag.Undefined =>
                return SideEffectResult.known(true)

            // 一元表达式
            case ExprTag.Unary =>
                match (expr.op) {
                    case OpCode.UnVoid =>
                        // void 总是返回 undefined
                        return SideEffectResult.knownWithSideEffects(true)
                    case OpCode.UnPos | OpCode.UnNeg | OpCode.UnCpl |
                         OpCode.UnPreDec | OpCode.UnPreInc |
                         OpCode.UnPostDec | OpCode.UnPostInc |
                         OpCode.UnNot | OpCode.Typeof | OpCode.UnDelete =>
                        // 这些操作符不会返回 null/undefined
                        return SideEffectResult.knownWithSideEffects(false)
                    case _ =>
                        ()
                }

            // 二元表达式
            case ExprTag.Binary =>
                match (expr.op) {
                    case OpCode.BinAdd | OpCode.BinSub | OpCode.BinMul |
                         OpCode.BinDiv | OpCode.BinRem | OpCode.BinPow |
                         OpCode.BinShl | OpCode.BinShr | OpCode.BinUShr |
                         OpCode.BinAnd | OpCode.BinOr | OpCode.BinXor |
                         OpCode.BinAddAssign | OpCode.BinSubAssign |
                         OpCode.BinMulAssign | OpCode.BinDivAssign |
                         OpCode.BinRemAssign | OpCode.BinPowAssign |
                         OpCode.BinShlAssign | OpCode.BinShrAssign |
                         OpCode.BinUShrAssign |
                         OpCode.BinAndAssign | OpCode.BinOrAssign |
                         OpCode.BinXorAssign |
                         // 布尔运算
                         OpCode.BinLt | OpCode.BinGt | OpCode.BinLe | OpCode.BinGe |
                         OpCode.BinIn | OpCode.BinInstanceof |
                         OpCode.BinEq | OpCode.BinNe |
                         OpCode.BinEqStrict | OpCode.BinNeStrict =>
                        return SideEffectResult.knownWithSideEffects(false)

                    case OpCode.Comma =>
                        if (let Some(right) <- expr.right) {
                            let res = toNullOrUndefined(parser, right)
                            if (res.ok) {
                                return SideEffectResult(SideEffectFlag.CouldHaveSideEffects, true, res.value)
                            }
                        }
                    case _ =>
                        ()
                }

            case _ =>
                ()
        }

        return SideEffectResult.unknown()
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// 已知原始类型名称
    private static func knownPrimitive(expr: Expr): String {
        match (expr.tag) {
            case ExprTag.Null => "null"
            case ExprTag.Undefined => "undefined"
            case ExprTag.Boolean => "boolean"
            case ExprTag.Number => "number"
            case ExprTag.BigInt => "bigint"
            case ExprTag.String => "string"
            case ExprTag.Function | ExprTag.Arrow => "function"
            case ExprTag.Regex => "regex"
            case _ => "unknown"
        }
    }

    /// 用逗号连接两个表达式
    private static func joinWithComma(left: Expr, right: Expr, parser: Parser): Expr {
        let comma = Expr(left.loc, ExprTag.Binary)
        comma.op = OpCode.Comma
        comma.left = Some(left)
        comma.right = Some(right)
        return comma
    }

    /// 用左结合运算符连接两个表达式
    private static func joinWithLeftAssociativeOp(op: OpCode, left: Expr, right: Expr,
                                                   parser: Parser): Expr {
        let bin = Expr(left.loc, ExprTag.Binary)
        bin.op = op
        bin.left = Some(left)
        bin.right = Some(right)
        return bin
    }

    /// 尝试将表达式转为有限数
    private static func toFiniteNumber(expr: Expr): ?Float64 {
        match (expr.tag) {
            case ExprTag.Number =>
                let v = expr.numberValue
                if (!v.isNaN() && v != Float64.INFINITY && v != Float64.NEGATIVE_INFINITY) {
                    return Some(v)
                }
            case _ =>
                ()
        }
        return None
    }

    /// 检查是否为安全的 toString 调用
    private static func isSafeToString(expr: Expr): Bool {
        // 简化: 字面量和标识符是安全的
        match (expr.tag) {
            case ExprTag.String | ExprTag.Number | ExprTag.Boolean |
                 ExprTag.Null | ExprTag.Undefined | ExprTag.BigInt =>
                true
            case _ =>
                false
        }
    }
}

// ============================================================================
// CanBeUnwrapped - __PURE__ 标注枚举
// 严格翻译自: src/js_parser/ast/E.zig
//   pub const CanBeUnwrappedIfUnused = enum { never, always, if_unused_and_toString_safe }
// ============================================================================

/// __PURE__ 标注 - 对应 Bun CanBeUnwrappedIfUnused
public enum CanBeUnwrapped {
    | Never                            // 不能移除
    | Always                           // 总是可以移除 (__PURE__)
    | IfUnusedAndToStringSafe          // 只在 toString 安全时可移除
}
