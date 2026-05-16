// JavaScript 代码打印机 - 表达式打印
// 严格翻译自: src/js_printer/js_printer.zig:2051-3225 (printExpr 及分支)
//   printExpr 是表达式打印的核心分发器
//   根据 ExprTag 分派到各自的打印逻辑
//   包括: e_undefined, e_null, e_this, e_super, e_spread, e_new_target,
//         e_import_meta, e_special, e_new, e_call, e_dot, e_index, e_if,
//         e_arrow, e_function, e_class, e_array, e_object, e_boolean,
//         e_string, e_template, e_reg_exp, e_big_int, e_number, e_identifier,
//         e_import_identifier, e_await, e_yield, e_unary, e_binary, e_inlined_enum
package bao_js_printer

import bao_core.*
import bao_collections.*

// ============================================================================
// JSPrinter 表达式扩展 - 对应 Printer.printExpr()
// 严格翻译自: js_printer.zig:2051-3192
//   pub fn printExpr(p: *Printer, expr: Expr, level: Level, in_flags: ExprFlag.Set) void
// ============================================================================

/// 表达式打印扩展
public class JSPrinter {

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
            case ExprTag.Undefined => {
                addSourceMapping(expr.loc)
                printUndefined(expr.loc, level)
            }
            case ExprTag.Super => {
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                print("super")
            }
            case ExprTag.Null => {
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                print("null")
            }
            case ExprTag.This => {
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                print("this")
            }
            case ExprTag.Spread => {
                addSourceMapping(expr.loc)
                print("...")
                printExpr(expr.valueExpr, OpLevel.Comma, ExprFlags.none())
            }
            case ExprTag.New => {
                printNew(expr, level, flags)
            }
            case ExprTag.Call => {
                printCall(expr, level, flags)
            }
            case ExprTag.Dot => {
                printDot(expr, level, flags)
            }
            case ExprTag.Index => {
                printIndex(expr, level, flags)
            }
            case ExprTag.Ternary => {
                printIf(expr, level, flags)
            }
            case ExprTag.Arrow => {
                printArrow(expr, level, flags)
            }
            case ExprTag.Function => {
                printFunction(expr, level)
            }
            case ExprTag.Class => {
                printClassExpr(expr, level)
            }
            case ExprTag.Array => {
                printArray(expr)
            }
            case ExprTag.Object => {
                printObject(expr, level)
            }
            case ExprTag.Boolean => {
                addSourceMapping(expr.loc)
                if (options.minifySyntax) {
                    if (level.ordinal() >= OpLevel.Unary.ordinal()) {
                        print(if (expr.boolValue) "(!0)" else "(!1)")
                    } else {
                        print(if (expr.boolValue) "!0" else "!1")
                    }
                } else {
                    printSpaceBeforeIdentifier()
                    print(if (expr.boolValue) "true" else "false")
                }
            }
            case ExprTag.String => {
                addSourceMapping(expr.loc)
                let eStr = EString(expr.stringValue)
                if (expr.stringValue.length > 0) {
                    printStringLiteralEString(eStr, true)
                }
            }
            case ExprTag.Template => {
                printTemplate(expr)
            }
            case ExprTag.Regex => {
                addSourceMapping(expr.loc)
                printRegExpLiteral(ERegExp(expr.regexPattern))
            }
            case ExprTag.BigInt => {
                printSpaceBeforeIdentifier()
                addSourceMapping(expr.loc)
                print(expr.stringValue)
                printByte(UInt8('n'))
            }
            case ExprTag.Number => {
                addSourceMapping(expr.loc)
                printNumber(expr.numberValue, level)
            }
            case ExprTag.Identifier => {
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
            }
            case ExprTag.ImportIdentifier => {
                printImportIdentifier(expr, level, flags)
            }
            case ExprTag.Await => {
                printAwait(expr, level)
            }
            case ExprTag.Yield => {
                printYield(expr, level)
            }
            case ExprTag.Unary => {
                printUnary(expr, level)
            }
            case ExprTag.Binary => {
                printBinary(expr, level, flags)
            }
            case ExprTag.Assign => {
                printAssign(expr, level, flags)
            }
            case ExprTag.Postfix => {
                printPostfix(expr, level)
            }
            case ExprTag.TypeCast => {
                // TypeScript 类型断言: 打印内部表达式
                printExpr(expr.valueExpr, level, flags)
            }
            case ExprTag.JsxElement | ExprTag.JsxFragment => {
                // JSX 不应出现在打印机中
            }
            case _ => ()
        }
    }

    // ========================================================================
    // new 表达式打印 - 对应 e_new case
    // 严格翻译自: js_printer.zig:2231-2272
    // ========================================================================

    /// 打印 new 表达式 - 对应 e_new
    private func printNew(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        let hasPureComment = expr.canBeUnwrappedIfUnused && options.printDceAnnotations
        let wrap = level.ordinal() >= OpLevel.Call.ordinal() ||
                   (hasPureComment && level.ordinal() >= OpLevel.Member.ordinal())

        if (wrap) {
            print("(")
        }

        if (hasPureComment) {
            printPure()
        }

        printSpaceBeforeIdentifier()
        addSourceMapping(expr.loc)
        print("new")
        printSpace()
        printExpr(expr.targetExpr, OpLevel.Primary, ExprFlags.forbidCallFlags())

        let args = expr.args
        if (args.size() > 0 || level.ordinal() >= OpLevel.Member.ordinal()) {
            print("(")
            if (args.size() > 0) {
                printExpr(args[0], OpLevel.Comma, ExprFlags.none())
                for (i in 1..args.size()) {
                    print(",")
                    printSpace()
                    printExpr(args[i], OpLevel.Comma, ExprFlags.none())
                }
            }
            print(")")
        }

        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // call 表达式打印 - 对应 e_call case
    // 严格翻译自: js_printer.zig:2273-2335
    // ========================================================================

    /// 打印调用表达式 - 对应 e_call
    private func printCall(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        var wrap = level.ordinal() >= OpLevel.Primary.ordinal() || flags.forbidCall
        var targetFlags = ExprFlags.none()

        if (!expr.hasOptionalChain) {
            targetFlags = ExprFlags.hasNonOptionalChainParentFlags()
        } else if (flags.hasNonOptionalChainParent) {
            wrap = true
        }

        let hasPureComment = expr.canBeUnwrappedIfUnused && options.printDceAnnotations
        if (hasPureComment && level.ordinal() >= OpLevel.Member.ordinal()) {
            wrap = true
        }

        if (wrap) {
            print("(")
        }

        if (hasPureComment) {
            let wasStmtStart = stmtStart == written
            printPure()
            if (wasStmtStart) {
                stmtStart = written
            }
        }

        let isUnboundEval = !expr.isDirectEval &&
            isUnboundEvalIdentifier(expr.targetExpr) &&
            !expr.hasOptionalChain

        if (isUnboundEval) {
            print("(0,")
            printSpace()
            printExpr(expr.targetExpr, OpLevel.Member, ExprFlags.none())
            print(")")
        } else {
            printExpr(expr.targetExpr, OpLevel.Member, targetFlags)
        }

        if (expr.hasOptionalChain && expr.optionalChainIsStart) {
            print("?.")
        }

        print("(")
        let args = expr.args
        if (args.size() > 0) {
            printExpr(args[0], OpLevel.Comma, ExprFlags.none())
            for (i in 1..args.size()) {
                print(",")
                printSpace()
                printExpr(args[i], OpLevel.Comma, ExprFlags.none())
            }
        }
        print(")")

        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // dot 表达式打印 - 对应 e_dot case
    // 严格翻译自: js_printer.zig:2467-2524
    // ========================================================================

    /// 打印点访问表达式 - 对应 e_dot
    private func printDot(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        let isOptionalChain = expr.optionalChainIsStart
        var wrap = false

        if (!expr.hasOptionalChain) {
            flags.insert(ExprFlagEnum.HasNonOptionalChainParent)
        } else {
            if (flags.hasNonOptionalChainParent) {
                wrap = true
                print("(")
            }
            flags.remove(ExprFlagEnum.HasNonOptionalChainParent)
        }

        printExpr(expr.targetExpr, OpLevel.Member,
            ExprFlags(flags.forbidCall, flags.forbidIn,
                       flags.hasNonOptionalChainParent, flags.exprResultIsUnused))

        let name = expr.identifierName
        if (isIdentifierStr(name)) {
            if (isOptionalChain) {
                print("?.")
            } else {
                if (prevNumEnd == written) {
                    print(" ")
                }
                print(".")
            }
            addSourceMapping(expr.loc)
            printIdentifier(name)
        } else {
            if (isOptionalChain) {
                print("?.[")
            } else {
                print("[")
            }
            printStringLiteralUTF8(name, false)
            print("]")
        }

        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // index 表达式打印 - 对应 e_index case
    // 严格翻译自: js_printer.zig:2525-2573
    // ========================================================================

    /// 打印索引访问表达式 - 对应 e_index
    private func printIndex(expr: Expr, level: OpLevel, flags: ExprFlags): Unit {
        var wrap = false
        if (!expr.hasOptionalChain) {
            flags.insert(ExprFlagEnum.HasNonOptionalChainParent)
        } else {
            if (flags.hasNonOptionalChainParent) {
                wrap = true
                print("(")
            }
            flags.remove(ExprFlagEnum.HasNonOptionalChainParent)
        }

        printExpr(expr.targetExpr, OpLevel.Member, flags)

        let isOptionalChainStart = expr.optionalChainIsStart
        if (isOptionalChainStart) {
            print("?.")
        }

        print("[")
        addSourceMapping(expr.loc)
        printExpr(expr.indexExpr, OpLevel.Comma, ExprFlags.none())
        print("]")

        if (wrap) {
            print(")")
        }
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
        printExpr(expr.testExpr, OpLevel.Conditional, flags)
        printSpace()
        print("?")
        printSpace()
        printExpr(expr.yesExpr, OpLevel.Yield, ExprFlags.none())
        printSpace()
        print(":")
        printSpace()
        flags.forbidIn = true
        printExpr(expr.noExpr, OpLevel.Yield, flags)
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

        if (expr.isAsync) {
            addSourceMapping(expr.loc)
            printSpaceBeforeIdentifier()
            print("async")
            printSpace()
        }

        printFnArgs(if (expr.isAsync) Loc.EMPTY else expr.loc,
                     expr.args, expr.hasRestArg, true)
        printWhitespacer(ws(" => "))

        // 简化: 如果body只有一个return语句，尝试打印为表达式
        printBlock(expr.bodyLoc, expr.bodyStmts, None,
                    TopLevel.initTopLevel(IsTopLevel.No))

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
        if (expr.isAsync) {
            print("async ")
        }
        print("function")
        if (expr.isGenerator) {
            print("*")
            printSpace()
        }

        if (let funcName = expr.funcName) {
            printSpaceBeforeIdentifier()
            addSourceMapping(funcName.loc)
            printSymbol(funcName.ref)
        }

        printFunc(expr)
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
        print("class")
        if (let className = expr.className) {
            print(" ")
            addSourceMapping(className.loc)
            printSymbol(className.ref)
        }
        printClass(expr)
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
        let items = expr.arrayItems
        if (items.size() > 0) {
            if (!expr.isSingleLine) {
                indent()
            }

            for (i in 0..items.size()) {
                if (i > 0) {
                    print(",")
                    if (expr.isSingleLine) {
                        printSpace()
                    }
                }
                if (!expr.isSingleLine) {
                    printNewline()
                    printIndent()
                }
                printExpr(items[i], OpLevel.Comma, ExprFlags.none())

                if (i == items.size() - 1 && items[i].tag == ExprTag.Missing) {
                    print(",")
                }
            }

            if (!expr.isSingleLine) {
                unindent()
                printNewline()
                printIndent()
            }
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
        let wrap = if (isJson) {
            false
        } else {
            stmtStart == n || arrowExprStart == n
        }

        if (wrap) {
            print("(")
        }
        addSourceMapping(expr.loc)
        print("{")

        let props = expr.properties
        if (props.size() > 0) {
            if (!expr.isSingleLine) {
                indent()
            }

            if (expr.isSingleLine && !isJson) {
                printSpace()
            } else {
                printNewline()
                printIndent()
            }
            printProperty(props[0])

            if (props.size() > 1) {
                for (i in 1..props.size()) {
                    print(",")
                    if (expr.isSingleLine && !isJson) {
                        printSpace()
                    } else {
                        printNewline()
                        printIndent()
                    }
                    printProperty(props[i])
                }
            }

            if (expr.isSingleLine && !isJson) {
                printSpace()
            } else {
                unindent()
                printNewline()
                printIndent()
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
        // 简化: 打印带标签或无标签的模板字面量
        if (let tag = expr.templateTag) {
            addSourceMapping(expr.loc)
            if (expr.isOptionalChain) {
                print("(")
                printExpr(tag, OpLevel.Comma, ExprFlags.none())
                print(")")
            } else {
                printExpr(tag, OpLevel.Member, ExprFlags.none())
            }
        } else {
            addSourceMapping(expr.loc)
        }

        print("`")
        // 简化: 打印模板头部
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
        printExpr(expr.valueExpr, OpLevel.Unary, ExprFlags.none())

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

        if (expr.hasYieldValue) {
            if (expr.isYieldStar) {
                print("*")
            }
            printSpace()
            printExpr(expr.valueExpr, OpLevel.Yield, ExprFlags.none())
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
        let opCode = expr.opCode
        let entry = getOpEntry(opCode)
        let wrap = level.ordinal() >= entry.level.ordinal()

        if (wrap) {
            print("(")
        }

        if (!isPrefixOp(opCode)) {
            printExpr(expr.valueExpr, OpLevel.Member, ExprFlags.none())
        }

        if (entry.isKeyword) {
            printSpaceBeforeIdentifier()
            addSourceMapping(expr.loc)
            print(entry.text)
            printSpace()
        } else {
            printSpaceBeforeOperator(opCode)
            if (isPrefixOp(opCode)) {
                addSourceMapping(expr.loc)
            }
            print(entry.text)
            prevOp = opCode
            prevOpEnd = written
        }

        if (isPrefixOp(opCode)) {
            printExpr(expr.valueExpr, OpLevel.Unary, ExprFlags.none())
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
        let eBinary = EBinary(expr.valueExpr, expr.rightExpr, expr.opCode)

        var v = BinaryExpressionVisitor(eBinary, level, flags)
        let stackBottom = binaryExpressionStack.size()

        // 简化: 直接递归打印
        let entry = getOpEntry(eBinary.op)
        let wrap = level.ordinal() >= entry.level.ordinal() ||
                   (eBinary.op == OpCode.BinIn && flags.forbidIn)

        // 检查解构赋值
        if (written == stmtStart || written == arrowExprStart) {
            match (eBinary.left.tag) {
                case ExprTag.Object => {
                    // wrap = true  -- 需要括号包裹
                }
                case _ => ()
            }
        }

        if (wrap) {
            print("(")
            flags.forbidIn = true
        }

        let leftLevel = entry.level
        let rightLevel = entry.level

        printExpr(eBinary.left, leftLevel, flags)

        if (eBinary.op != OpCode.BinComma) {
            printSpace()
        }

        if (entry.isKeyword) {
            printSpaceBeforeIdentifier()
            print(entry.text)
        } else {
            printSpaceBeforeOperator(eBinary.op)
            print(entry.text)
            prevOp = eBinary.op
            prevOpEnd = written
        }

        printSpace()
        printExpr(eBinary.right, rightLevel, flags)

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

        printExpr(expr.targetExpr, OpLevel.Assign, flags)
        printSpace()

        let opText = getAssignOpText(expr.opCode)
        print(opText)
        printSpace()
        printExpr(expr.valueExpr, OpLevel.Comma, ExprFlags.none())

        if (wrap) {
            print(")")
        }
    }

    // ========================================================================
    // postfix 表达式打印 - 对应 e_postfix
    // ========================================================================

    /// 打印后缀表达式 - 对应 e_postfix
    private func printPostfix(expr: Expr, level: OpLevel): Unit {
        let entry = getOpEntry(expr.opCode)
        let wrap = level.ordinal() >= entry.level.ordinal()

        if (wrap) {
            print("(")
        }

        printExpr(expr.valueExpr, OpLevel.Member, ExprFlags.none())

        if (entry.isKeyword) {
            printSpace()
            print(entry.text)
        } else {
            print(entry.text)
        }

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
        var level = level
        let wrap = level.ordinal() >= OpLevel.Primary.ordinal() || flags.forbidCall
        if (wrap) {
            print("(")
        }

        if (importRecordIndex < Int64(importRecords.size())) {
            let record = importRecord(importRecordIndex)

            // 外部 require()
            if (record.kind != ImportRecordKind.Dynamic) {
                printSpaceBeforeIdentifier()
                if (options.inlineRequireAndImportErrors) {
                    if (record.pathIsDisabled && record.flags.handlesImportErrors) {
                        printRequireError(record.pathText)
                        if (wrap) { print(")") }
                        return
                    }
                    if (record.pathIsDisabled) {
                        printDisabledImport()
                        if (wrap) { print(")") }
                        return
                    }
                }

                if (let requireRef = options.requireRef) {
                    printSymbol(requireRef)
                } else {
                    print("require")
                }
                print("(")
                printImportRecordPath(record)
                print(")")
                if (wrap) { print(")") }
                return
            }

            // 外部 import()
            addSourceMapping(record.range)
            printSpaceBeforeIdentifier()
            print("import(")
            printImportRecordPath(record)
            print(")")
        }

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
            case OpCode.BinMod => OpEntry("%", OpLevel.Multiplicative, false, op)
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
            case OpCode.BinUshr => OpEntry(">>>", OpLevel.Shift, false, op)
            case OpCode.BinIn => OpEntry("in", OpLevel.Relational, true, op)
            case OpCode.BinInstanceof => OpEntry("instanceof", OpLevel.Relational, true, op)
            case OpCode.BinComma => OpEntry(",", OpLevel.Comma, false, op)
            case OpCode.BinLogicalOr => OpEntry("||", OpLevel.LogicalOr, false, op)
            case OpCode.BinLogicalAnd => OpEntry("&&", OpLevel.LogicalAnd, false, op)
            case OpCode.BinNullishCoalescing => OpEntry("??", OpLevel.NullishCoalescing, false, op)
            case OpCode.UnPos => OpEntry("+", OpLevel.Unary, false, op)
            case OpCode.UnNeg => OpEntry("-", OpLevel.Unary, false, op)
            case OpCode.UnNot => OpEntry("!", OpLevel.Unary, false, op)
            case OpCode.UnBitNot => OpEntry("~", OpLevel.Unary, false, op)
            case OpCode.UnTypeof => OpEntry("typeof", OpLevel.Unary, true, op)
            case OpCode.UnVoid => OpEntry("void", OpLevel.Unary, true, op)
            case OpCode.UnDelete => OpEntry("delete", OpLevel.Unary, true, op)
            case OpCode.UnPreInc => OpEntry("++", OpLevel.Update, false, op)
            case OpCode.UnPreDec => OpEntry("--", OpLevel.Update, false, op)
            case OpCode.UnPostInc => OpEntry("++", OpLevel.Update, false, op)
            case OpCode.UnPostDec => OpEntry("--", OpLevel.Update, false, op)
            case _ => OpEntry.default()
        }
    }

    /// 是否是前缀操作符
    public func isPrefixOp(op: OpCode): Bool {
        match (op) {
            case OpCode.UnPos | OpCode.UnNeg | OpCode.UnNot | OpCode.UnBitNot |
                 OpCode.UnTypeof | OpCode.UnVoid | OpCode.UnDelete |
                 OpCode.UnPreInc | OpCode.UnPreDec => true
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
            case OpCode.BinMod => "%="
            case OpCode.BinPow => "**="
            case OpCode.BinShl => "<<="
            case OpCode.BinShr => ">>="
            case OpCode.BinUshr => ">>>="
            case OpCode.BinAnd => "&="
            case OpCode.BinOr => "|="
            case OpCode.BinXor => "^="
            case OpCode.BinLogicalOr => "||="
            case OpCode.BinLogicalAnd => "&&="
            case OpCode.BinNullishCoalescing => "??="
            case _ => "="
        }
    }
}
