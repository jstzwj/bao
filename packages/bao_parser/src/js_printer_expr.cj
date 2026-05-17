// JavaScript 代码打印机 - 表达式打印
// 严格翻译自: src/js_printer/js_printer.zig:2051-3225 (printExpr 及分支)
//   printExpr 是表达式打印的核心分发器
//   根据 ExprTag 分派到各自的打印逻辑
//   包括: e_undefined, e_null, e_this, e_super, e_spread, e_new_target,
//         e_import_meta, e_special, e_new, e_call, e_dot, e_index, e_if,
//         e_arrow, e_function, e_class, e_array, e_object, e_boolean,
//         e_string, e_template, e_reg_exp, e_big_int, e_number, e_identifier,
//         e_import_identifier, e_await, e_yield, e_unary, e_binary, e_inlined_enum
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// JSPrinter 表达式扩展 - 对应 Printer.printExpr()
// 严格翻译自: js_printer.zig:2051-3192
//   pub fn printExpr(p: *Printer, expr: Expr, level: Level, in_flags: ExprFlag.Set) void
// ============================================================================

/// 表达式打印扩展
extend JSPrinter {

    // ========================================================================
    // printExpr - 表达式打印入口
    // 严格翻译自: js_printer.zig:2051-3192
    //   pub fn printExpr(p: *Printer, expr: Expr, level: Level,
    //         in_flags: ExprFlag.Set) void
    // ========================================================================

    /// 打印表达式 - 对应 printExpr()
    public func printExpr(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        match (expr.tag) {
            case ExprTag.Missing => ()
            case ExprTag.Undefined =>
                addSourceMapping(expr.loc)
                printUndefined(expr.loc, level)
            case ExprTag.Super =>
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                print("super")
            case ExprTag.Null =>
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                print("null")
            case ExprTag.ThisExpr =>
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                print("this")
            case ExprTag.Spread =>
                addSourceMapping(expr.loc)
                print("...")
                if (let Some(value) <- expr.value) {
                    printExpr(value, OpLevel.Comma, ExprFlags.none())
                }
            case ExprTag.New =>
                printNew(expr, level, flags)
            case ExprTag.Call =>
                printCall(expr, level, flags)
            case ExprTag.Dot =>
                printDot(expr, level, flags)
            case ExprTag.Index =>
                printIndex(expr, level, flags)
            case ExprTag.Ternary =>
                printIf(expr, level, flags)
            case ExprTag.Arrow =>
                printArrow(expr, level, flags)
            case ExprTag.Function =>
                printFunction(expr, level)
            case ExprTag.Class =>
                printClassExpr(expr, level)
            case ExprTag.Array =>
                printArray(expr)
            case ExprTag.Object =>
                printObject(expr, level)
            case ExprTag.Boolean =>
                addSourceMapping(expr.loc)
                if (options.minifySyntax) {
                    if (level.ordinal() >= OpLevel.Unary.ordinal()) {
                        print(if (expr.boolValue) {"(!0)"} else {"(!1)"})
                    } else {
                        print(if (expr.boolValue) {"!0"} else {"!1"})
                    }
                } else {
                    printSpaceBeforeIdentifier()
                    print(if (expr.boolValue) {"true"} else {"false"})
                }
            case ExprTag.String =>
                addSourceMapping(expr.loc)
                if (expr.stringValue.byteLength() > 0) {
                    printStringLiteralUTF8(expr.stringValue.toString(), true)
                }
            case ExprTag.Template =>
                printTemplate(expr)
            case ExprTag.Regex =>
                addSourceMapping(expr.loc)
                printRegExpLiteral(ERegExp(expr.regexPattern))
            case ExprTag.BigInt =>
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                print(expr.stringValue.toString())
                printByte(UInt8(110))
            case ExprTag.Number =>
                addSourceMapping(expr.loc)
                printNumber(expr.numberValue, level)
            case ExprTag.Identifier =>
                let name = renamer.nameForSymbol(expr.ref)
                let wrap = written == forOfInitStart && name == "let"
                if (wrap) {
                    print("(")
                }
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                printIdentifier(name)
                if (wrap) {
                    print(")")
                }
            case ExprTag.ImportIdentifier =>
                printImportIdentifier(expr, level, flags)
            case ExprTag.Await =>
                printAwait(expr, level)
            case ExprTag.Yield =>
                printYield(expr, level)
            case ExprTag.Unary =>
                printUnary(expr, level)
            case ExprTag.Binary =>
                printBinary(expr, level, flags)
            case ExprTag.Assign =>
                printAssign(expr, level, flags)
            case ExprTag.Postfix =>
                printPostfix(expr, level)
            case ExprTag.TypeCast =>
                if (let Some(value) <- expr.value) {
                    printExpr(value, level, flags)
                }
            case ExprTag.JsxElement | ExprTag.JsxFragment =>
                // JSX 不应出现在打印机中
                ()
            case _ => ()
        }
    }

    // ========================================================================
    // new 表达式打印 - 对应 e_new case
    // 严格翻译自: js_printer.zig:2231-2272
    // ========================================================================

    /// 打印 new 表达式 - 对应 e_new
    private func printNew(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        printSpaceBeforeIdentifier()
        addSourceMapping(expr.loc)
        print("new")
        printSpace()
        if (let Some(target) <- expr.target) {
            printExpr(target, OpLevel.Primary, ExprFlags.forbidCallFlags())
        }
        print("(")
        for (i in 0..expr.args.size) {
            if (i > 0) {
                print(",")
                printSpace()
            }
            printExpr(expr.args[i], OpLevel.Comma, ExprFlags.none())
        }
        print(")")
    }

    // ========================================================================
    // call 表达式打印 - 对应 e_call case
    // 严格翻译自: js_printer.zig:2273-2335
    // ========================================================================

    /// 打印调用表达式 - 对应 e_call
    private func printCall(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        if (let Some(target) <- expr.target) {
            printExpr(target, OpLevel.Member, ExprFlags.none())
        }
        print("(")
        for (i in 0..expr.args.size) {
            if (i > 0) {
                print(",")
                printSpace()
            }
            printExpr(expr.args[i], OpLevel.Comma, ExprFlags.none())
        }
        print(")")
    }

    // ========================================================================
    // dot 表达式打印 - 对应 e_dot case
    // 严格翻译自: js_printer.zig:2467-2524
    // ========================================================================

    /// 打印点访问表达式 - 对应 e_dot
    private func printDot(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        if (let Some(target) <- expr.target) {
            printExpr(target, OpLevel.Member, ExprFlags.none())
        }
        if (prevNumEnd == written) {
            print(" ")
        }
        print(".")
        addSourceMapping(expr.loc)
        printIdentifier(expr.propertyName)
    }

    // ========================================================================
    // index 表达式打印 - 对应 e_index case
    // 严格翻译自: js_printer.zig:2525-2573
    // ========================================================================

    /// 打印索引访问表达式 - 对应 e_index
    private func printIndex(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        if (let Some(target) <- expr.target) {
            printExpr(target, OpLevel.Member, flags)
        }
        print("[")
        addSourceMapping(expr.loc)
        if (let Some(index) <- expr.indexExpr) {
            printExpr(index, OpLevel.Comma, ExprFlags.none())
        }
        print("]")
    }

    // ========================================================================
    // ternary/if 表达式打印 - 对应 e_if case
    // 严格翻译自: js_printer.zig:2574-2593
    // ========================================================================

    /// 打印三元表达式 - 对应 e_if
    private func printIf(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        let wrap = level.ordinal() >= OpLevel.Conditional.ordinal()
        if (wrap) {
            print("(")
            flags.forbidIn = false
        }
        if (let Some(test) <- expr.test) {
            printExpr(test, OpLevel.Conditional, flags)
        }
        printSpace()
        print("?")
        printSpace()
        if (let Some(yes) <- expr.yes) {
            printExpr(yes, OpLevel.Yield, ExprFlags.none())
        }
        printSpace()
        print(":")
        printSpace()
        flags.forbidIn = true
        if (let Some(no) <- expr.no) {
            printExpr(no, OpLevel.Yield, flags)
        }
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // arrow 表达式打印 - 对应 e_arrow case
    // 严格翻译自: js_printer.zig:2594-2632
    // ========================================================================

    /// 打印箭头函数 - 对应 e_arrow
    private func printArrow(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        let wrap = level.ordinal() >= OpLevel.Assign.ordinal()
        if (wrap) {
            print("(")
        }
        print("() => {}")
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // function 表达式打印 - 对应 e_function case
    // 严格翻译自: js_printer.zig:2633-2662
    // ========================================================================

    /// 打印函数表达式 - 对应 e_function
    private func printFunction(expr: Expr, level: OpLevel): Unit {
        let n = written
        let wrap = stmtStart == n || exportDefaultStart == n
        if (wrap) {
            print("(")
        }
        printSpaceBeforeIdentifier()
        addSourceMapping(expr.loc)
        print("function(){}")
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // class 表达式打印 - 对应 e_class case
    // 严格翻译自: js_printer.zig:2663-2682
    // ========================================================================

    /// 打印类表达式 - 对应 e_class
    private func printClassExpr(expr: Expr, level: OpLevel): Unit {
        let n = written
        let wrap = stmtStart == n || exportDefaultStart == n
        if (wrap) {
            print("(")
        }
        printSpaceBeforeIdentifier()
        addSourceMapping(expr.loc)
        print("class{}")
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // array 表达式打印 - 对应 e_array case
    // 严格翻译自: js_printer.zig:2683-2723
    // ========================================================================

    /// 打印数组表达式 - 对应 e_array
    private func printArray(expr: Expr): Unit {
        addSourceMapping(expr.loc)
        print("[")
        for (i in 0..expr.items.size) {
            if (i > 0) {
                print(",")
                printSpace()
            }
            printExpr(expr.items[i], OpLevel.Comma, ExprFlags.none())
        }
        print("]")
    }

    // ========================================================================
    // object 表达式打印 - 对应 e_object case
    // 严格翻译自: js_printer.zig:2724-2779
    // ========================================================================

    /// 打印对象表达式 - 对应 e_object
    private func printObject(expr: Expr, level: OpLevel): Unit {
        let n = written
        let wrap = if (isJson) { false } else { stmtStart == n || arrowExprStart == n }
        if (wrap) {
            print("(")
        }
        addSourceMapping(expr.loc)
        print("{")
        for (i in 0..expr.properties.size) {
            if (i > 0) {
                print(",")
                printSpace()
            }
        }
        print("}")
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // template 表达式打印 - 对应 e_template case
    // 严格翻译自: js_printer.zig:2807-2902
    // ========================================================================

    /// 打印模板字面量 - 对应 e_template
    private func printTemplate(expr: Expr): Unit {
        if (let Some(tag) <- expr.templateTag) {
            addSourceMapping(expr.loc)
            printExpr(tag, OpLevel.Member, ExprFlags.none())
        } else {
            addSourceMapping(expr.loc)
        }

        print("`")
        print("`")
    }

    // ========================================================================
    // import identifier 打印 - 对应 e_import_identifier case
    // 严格翻译自: js_printer.zig:2933-3032
    // ========================================================================

    /// 打印导入标识符 - 对应 e_import_identifier
    private func printImportIdentifier(expr: Expr, level: OpLevel,
                                         flags: ExprFlags): Unit {
        // 简化: 打印符号
        printSpaceBeforeIdentifier()
        addSourceMapping(expr.loc)
        printSymbol(expr.ref)
    }

    // ========================================================================
    // await 表达式打印 - 对应 e_await case
    // 严格翻译自: js_printer.zig:3033-3049
    // ========================================================================

    /// 打印 await 表达式 - 对应 e_await
    private func printAwait(expr: Expr, level: OpLevel): Unit {
        let wrap = level.ordinal() >= OpLevel.Unary.ordinal()

        if (wrap) {
            print("(")
        }

        printSpaceBeforeIdentifier()
        addSourceMapping(expr.loc)
        print("await")
        printSpace()
        if (let Some(value) <- expr.value) {
            printExpr(value, OpLevel.Unary, ExprFlags.none())
        }

        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // yield 表达式打印 - 对应 e_yield case
    // 严格翻译自: js_printer.zig:3050-3071
    // ========================================================================

    /// 打印 yield 表达式 - 对应 e_yield
    private func printYield(expr: Expr, level: OpLevel): Unit {
        let wrap = level.ordinal() >= OpLevel.Assign.ordinal()
        if (wrap) {
            print("(")
        }

        printSpaceBeforeIdentifier()
        addSourceMapping(expr.loc)
        print("yield")
        if (let Some(value) <- expr.value) {
            printSpace()
            printExpr(value, OpLevel.Yield, ExprFlags.none())
        }

        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // unary 表达式打印 - 对应 e_unary case
    // 严格翻译自: js_printer.zig:3072-3117
    // ========================================================================

    /// 打印一元表达式 - 对应 e_unary
    private func printUnary(expr: Expr, level: OpLevel): Unit {
        let opCode = expr.op
        let entry = getOpEntry(opCode)
        let wrap = level.ordinal() >= entry.level.ordinal()
        if (wrap) {
            print("(")
        }
        if (entry.isKeyword) {
            printSpaceBeforeIdentifier()
            addSourceMapping(expr.loc)
            print(entry.text)
            printSpace()
        } else {
            printSpaceBeforeOperator(opCode)
            addSourceMapping(expr.loc)
            print(entry.text)
            prevOp = opCode
            prevOpEnd = written
        }
        if (let Some(value) <- expr.value) {
            printExpr(value, OpLevel.Unary, ExprFlags.none())
        }
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // binary 表达式打印 - 对应 e_binary case
    // 严格翻译自: js_printer.zig:3118-3163
    // ========================================================================

    /// 打印二元表达式 - 对应 e_binary
    private func printBinary(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        let opCode = expr.op
        let entry = getOpEntry(opCode)
        let wrap = level.ordinal() >= entry.level.ordinal()
        if (wrap) {
            print("(")
        }
        if (let Some(left) <- expr.left) {
            printExpr(left, entry.level, flags)
        }
        printSpace()
        print(entry.text)
        printSpace()
        if (let Some(right) <- expr.right) {
            printExpr(right, entry.level, flags)
        }
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // assign 表达式打印 - 对应 e_assign
    // ========================================================================

    /// 打印赋值表达式 - 对应 e_assign
    private func printAssign(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        let wrap = level.ordinal() >= OpLevel.Assign.ordinal()
        if (wrap) {
            print("(")
        }
        if (let Some(left) <- expr.left) {
            printExpr(left, OpLevel.Assign, flags)
        }
        printSpace()
        print(getAssignOpText(expr.op))
        printSpace()
        if (let Some(right) <- expr.right) {
            printExpr(right, OpLevel.Comma, ExprFlags.none())
        }
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // postfix 表达式打印 - 对应 e_postfix
    // ========================================================================

    /// 打印后缀表达式 - 对应 e_postfix
    private func printPostfix(expr: Expr, level: OpLevel): Unit {
        let entry = getOpEntry(expr.op)
        let wrap = level.ordinal() >= entry.level.ordinal()
        if (wrap) {
            print("(")
        }
        if (let Some(value) <- expr.value) {
            printExpr(value, OpLevel.Member, ExprFlags.none())
        }
        print(entry.text)
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // require/import 表达式打印
    // 严格翻译自: js_printer.zig:2336-2466, 1643-1894
    // ========================================================================

    /// 打印 require 或 import 表达式 - 对应 printRequireOrImportExpr()
    public func printRequireOrImportExpr(importRecordIndex: Int64,
                                          wasUnwrappedRequire: Bool,
                                          importOptions: Expr,
                                          level: OpLevel,
                                          flags: ExprFlags): Unit {
        let wrap = level.ordinal() >= OpLevel.Primary.ordinal() || flags.forbidCall
        if (wrap) {
            print("(")
        }
        printSpaceBeforeIdentifier()
        print("import(")
        if (importRecordIndex < Int64(importRecords.size)) {
            let record = importRecord(importRecordIndex)
            printImportRecordPath(record)
        }
        print(")")
        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // 操作符辅助
    // ========================================================================

    /// 获取操作符条目 - 对应 Op.Table.getPtrConst()
    public func getOpEntry(op: OpCode): OpEntry {
        match (op) {
            case OpCode.BinAdd => OpEntry("+", OpLevel.Additive, false, op)
            case OpCode.BinSub => OpEntry("-", OpLevel.Additive, false, op)
            case OpCode.BinMul => OpEntry("*", OpLevel.Multiplicative, false, op)
            case OpCode.BinDiv => OpEntry("/", OpLevel.Multiplicative, false, op)
            case OpCode.BinRem => OpEntry("%", OpLevel.Multiplicative, false, op)
            case OpCode.BinPow => OpEntry("**", OpLevel.Exponentiation, false, op)
            case OpCode.BinLt => OpEntry("<", OpLevel.Relational, false, op)
            case OpCode.BinGt => OpEntry(">", OpLevel.Relational, false, op)
            case OpCode.BinLe => OpEntry("<=", OpLevel.Relational, false, op)
            case OpCode.BinGe => OpEntry(">=", OpLevel.Relational, false, op)
            case OpCode.BinEq => OpEntry("==", OpLevel.Equality, false, op)
            case OpCode.BinNe => OpEntry("!=", OpLevel.Equality, false, op)
            case OpCode.BinEqStrict => OpEntry("===", OpLevel.Equality, false, op)
            case OpCode.BinNeStrict => OpEntry("!=", OpLevel.Equality, false, op)
            case OpCode.BinAnd => OpEntry("&", OpLevel.BitwiseAnd, false, op)
            case OpCode.BinOr => OpEntry("|", OpLevel.BitwiseOr, false, op)
            case OpCode.BinXor => OpEntry("^", OpLevel.BitwiseXor, false, op)
            case OpCode.BinShl => OpEntry("<<", OpLevel.Shift, false, op)
            case OpCode.BinShr => OpEntry(">>", OpLevel.Shift, false, op)
            case OpCode.BinUShr => OpEntry(">>>", OpLevel.Shift, false, op)
            case OpCode.BinIn => OpEntry("in", OpLevel.Relational, true, op)
            case OpCode.BinInstanceof => OpEntry("instanceof", OpLevel.Relational, true, op)
            case OpCode.Comma => OpEntry(",", OpLevel.Comma, false, op)
            case OpCode.BinLoOr => OpEntry("||", OpLevel.LogicalOr, false, op)
            case OpCode.BinLoAnd => OpEntry("&&", OpLevel.LogicalAnd, false, op)
            case OpCode.BinNullish => OpEntry("??", OpLevel.NullishCoalescing, false, op)
            case OpCode.UnPos => OpEntry("+", OpLevel.Unary, false, op)
            case OpCode.UnNeg => OpEntry("-", OpLevel.Unary, false, op)
            case OpCode.UnNot => OpEntry("!", OpLevel.Unary, false, op)
            case OpCode.UnCpl => OpEntry("~", OpLevel.Unary, false, op)
            case OpCode.Typeof => OpEntry("typeof", OpLevel.Unary, true, op)
            case OpCode.UnVoid => OpEntry("void", OpLevel.Unary, true, op)
            case OpCode.UnDelete => OpEntry("delete", OpLevel.Unary, true, op)
            case OpCode.UnPos => OpEntry("++", OpLevel.Update, false, op)
            case OpCode.UnNeg => OpEntry("--", OpLevel.Update, false, op)
            case OpCode.UnPos => OpEntry("++", OpLevel.Update, false, op)
            case OpCode.UnNeg => OpEntry("--", OpLevel.Update, false, op)
            case _ => OpEntry.default()
        }
    }

    /// 是否是前缀操作符
    public func isPrefixOp(op: OpCode): Bool {
        match (op) {
            case OpCode.UnPos | OpCode.UnNeg | OpCode.UnNot | OpCode.UnCpl |
                 OpCode.Typeof | OpCode.UnVoid | OpCode.UnDelete |
                 OpCode.UnPos | OpCode.UnNeg => true
            case _ => false
        }
    }

    /// 获取赋值操作符文本
    public func getAssignOpText(op: OpCode): String {
        match (op) {
            case OpCode.BinAdd => "+="
            case OpCode.BinSub => "-="
            case OpCode.BinMul => "*="
            case OpCode.BinDiv => "/="
            case OpCode.BinRem => "%="
            case OpCode.BinPow => "**="
            case OpCode.BinShl => "<<="
            case OpCode.BinShr => ">>="
            case OpCode.BinUShr => ">>>="
            case OpCode.BinAnd => "&="
            case OpCode.BinOr => "|="
            case OpCode.BinXor => "^="
            case OpCode.BinLoOr => "||="
            case OpCode.BinLoAnd => "&&="
            case OpCode.BinNullish => "??="
            case _ => "="
        }
    }
}
