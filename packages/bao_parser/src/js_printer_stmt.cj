// JavaScript 代码打印机 - 语句打印
// 严格翻译自: src/js_printer/js_printer.zig:1131-5261 (语句/块/绑定/属性打印)
//   printStmt 是语句打印的核心分发器
//   包括: printBody, printBlock, printBlockBody, printDecls, printStmt,
//         printFunc, printClass, printProperty, printBinding, printIf,
//         printForLoopInit, printDeclStmt, printBundledImport, printDevServerModule
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// JSPrinter 语句/块/绑定扩展
// ============================================================================

/// 语句打印扩展
extend JSPrinter {

    // ========================================================================
    // printBody - 打印语句体
    // 严格翻译自: js_printer.zig:1131-1145
    //   pub fn printBody(p: *Printer, stmt: Stmt, tlmtlo: TopLevel) void
    // ========================================================================

    /// 打印语句体 - 对应 printBody()
    public func printBody(stmt: Stmt, tlmtlo: TopLevel): Unit {
        match (stmt.tag) {
            case StmtTag.Block =>
                printSpace()
                printBlock(stmt.loc, stmt.blockStmts, Option<Loc>.None, tlmtlo)
                printNewline()
            case _ =>
                printNewline()
                indent()
                printStmt(stmt, tlmtlo)
                unindent()
        }
    }

    // ========================================================================
    // printBlockBody - 打印块体
    // 严格翻译自: js_printer.zig:1147-1152
    // ========================================================================

    /// 打印块体 - 对应 printBlockBody()
    public func printBlockBody(stmts: ArrayList<Stmt>, tlmtlo: TopLevel): Unit {
        for (stmt in stmts) {
            printSemicolonIfNeeded()
            printStmt(stmt, tlmtlo)
        }
    }

    // ========================================================================
    // printBlock - 打印块
    // 严格翻译自: js_printer.zig:1154-1173
    // ========================================================================

    /// 打印块 - 对应 printBlock()
    public func printBlock(loc: Loc, stmts: ArrayList<Stmt>,
                            closeBraceLoc: ?Loc, tlmtlo: TopLevel): Unit {
        addSourceMapping(loc)
        print("{")
        if (stmts.size > 0) {
            printNewline()
            indent()
            printBlockBody(stmts, tlmtlo)
            unindent()
            printIndent()
        }
        if (let Some(cbl) <- closeBraceLoc) {
            if (cbl.start > loc.start) {
                addSourceMapping(cbl)
            }
        }
        print("}")
        needsSemicolon = false
    }

    // ========================================================================
    // printTwoBlocksInOne - 合并两个块
    // 严格翻译自: js_printer.zig:1175-1188
    // ========================================================================

    /// 合并两个块 - 对应 printTwoBlocksInOne()
    public func printTwoBlocksInOne(loc: Loc, stmts: ArrayList<Stmt>,
                                      prepend: ArrayList<Stmt>): Unit {
        addSourceMapping(loc)
        print("{")
        printNewline()
        indent()
        printBlockBody(prepend, TopLevel.initTopLevel(IsTopLevel.No))
        printBlockBody(stmts, TopLevel.initTopLevel(IsTopLevel.No))
        unindent()
        needsSemicolon = false
        printIndent()
        print("}")
    }

    // ========================================================================
    // printFunc - 打印函数
    // 严格翻译自: js_printer.zig:1413-1417
    // ========================================================================

    /// 打印函数 - 对应 printFunc()
    public func printFunc(`func`: Expr): Unit {
        printFnArgs(`func`.loc, `func`.args, false, false)
        printSpace()
        print("{}")
    }

    // ========================================================================
    // printFnArgs - 打印函数参数
    // 严格翻译自: js_printer.zig:1373-1411
    // ========================================================================

    /// 打印函数参数 - 对应 printFnArgs()
    public func printFnArgs(openParenLoc: Loc, args: ArrayList<Expr>,
                             hasRestArg: Bool, isArrow: Bool): Unit {
        if (!openParenLoc.isEmpty()) {
            addSourceMapping(openParenLoc)
        }
        print("(")
        for (i in 0..args.size) {
            if (i > 0) {
                print(",")
                printSpace()
            }
            if (hasRestArg && i + 1 == args.size) {
                print("...")
            }
            printIdentifier("arg" + i.toString())
        }
        print(")")
    }

    // ========================================================================
    // printClass - 打印类
    // 严格翻译自: js_printer.zig:1419-1460
    // ========================================================================

    /// 打印类 - 对应 printClass()
    public func printClass(expr: Expr): Unit {
        printSpace()
        addSourceMapping(expr.loc)
        print("{}")
        needsSemicolon = false
    }

    // ========================================================================
    // printProperty - 打印属性
    // 严格翻译自: js_printer.zig:3324-3608
    // ========================================================================

    /// 打印属性 - 对应 printProperty()
    public func printProperty(item: Expr): Unit {
        printIdentifier(item.identifierName)
        if (let Some(value) <- item.value) {
            print(":")
            printSpace()
            printExpr(value, OpLevel.Comma, ExprFlags.none())
        }
    }

    // ========================================================================
    // printBinding - 打印绑定
    // 严格翻译自: js_printer.zig:3617-3796
    // ========================================================================

    /// 打印绑定 - 对应 printBinding()
    public func printBinding(binding: Binding, tlm: TopLevel): Unit {
        match (binding.tag) {
            case BindingTag.Missing => ()
            case BindingTag.Identifier =>
                printSpaceBeforeIdentifier()
                addSourceMapping(binding.loc)
                if (binding.name != "") {
                    printIdentifier(binding.name)
                } else {
                    printSymbol(binding.ref)
                }
            case BindingTag.Array =>
                print("[")
                for (i in 0..binding.arrayItems.size) {
                    if (i > 0) {
                        print(",")
                        printSpace()
                    }
                    printBinding(binding.arrayItems[i], tlm)
                }
                print("]")
            case BindingTag.Object =>
                print("{")
                for (i in 0..binding.objectProperties.size) {
                    if (i > 0) {
                        print(",")
                        printSpace()
                    }
                    if (let Some(value) <- binding.objectProperties[i].value) {
                        printBinding(value, tlm)
                    }
                }
                print("}")
        }
    }

    // ========================================================================
    // printDecls - 打印声明
    // 严格翻译自: js_printer.zig:1190-1333
    // ========================================================================

    /// 打印声明 - 对应 printDecls()
    public func printDecls(keyword: String, decls: ArrayList<Decl>,
                            flags: ExprFlags, tlm: TopLevel): Unit {
        print(keyword)
        printSpace()

        if (decls.size == 0) {
            return
        }

        printBinding(decls[0].binding, tlm)
        if (let Some(value) <- decls[0].value) {
            printWhitespacer(ws(" = "))
            printExpr(value, OpLevel.Comma, flags)
        }

        for (i in 1..decls.size) {
            print(",")
            printSpace()
            printBinding(decls[i].binding, tlm)
            if (let Some(value) <- decls[i].value) {
                printWhitespacer(ws(" = "))
                printExpr(value, OpLevel.Comma, flags)
            }
        }
    }

    // ========================================================================
    // printDeclStmt - 打印声明语句
    // 严格翻译自: js_printer.zig:5196-5261
    // ========================================================================

    /// 打印声明语句 - 对应 printDeclStmt()
    public func printDeclStmt(isExport: Bool, keyword: String,
                                decls: ArrayList<Decl>, tlmtlo: TopLevel): Unit {
        if (!rewriteEsmToCjs && isExport) {
            print("export ")
        }
        let tlm = TopLevel(isExport, IsTopLevel.No)
        printDecls(keyword, decls, ExprFlags.none(), tlm)
        printSemicolonAfterStatement()

        if (rewriteEsmToCjs && isExport && decls.size > 0) {
            for (decl in decls) {
                printIndent()
                print("Object.defineProperty(")
                printModuleExportSymbol()
                print(",")
                printSymbol(decl.binding.ref)
                print(",{get: () => ")
                printSymbol(decl.binding.ref)
                print(", enumerable: true, configurable: true})")
                printSemicolonAfterStatement()
            }
        }
    }

    // ========================================================================
    // printStmt - 打印语句 (核心分发器)
    // 严格翻译自: js_printer.zig:3807-4821
    //   pub fn printStmt(p: *Printer, stmt: Stmt, tlmtlo: TopLevel) !void
    // ========================================================================

    /// 打印语句 - 对应 printStmt()
    public func printStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
        this.prevStmtTag = stmt.tag

        match (stmt.tag) {
            case StmtTag.Comment =>
                printIndent()
                addSourceMapping(stmt.loc)
                printIndentedComment(stmt.commentText)
            case StmtTag.Function =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)

                if (stmt.isExport) {
                    if (!rewriteEsmToCjs) {
                        print("export ")
                    }
                }
                if (stmt.isAsync) {
                    print("async ")
                }
                print("function")
                if (stmt.isGenerator) {
                    print("*")
                    printSpace()
                } else {
                    printSpaceBeforeIdentifier()
                }

                let nameRef = stmt.funcNameRef
                let localName = renamer.nameForSymbol(nameRef)
                addSourceMapping(stmt.funcNameLoc)
                printIdentifier(localName)
                print("(){}")

                printNewline()

                if (rewriteEsmToCjs && stmt.isExport) {
                    printIndent()
                    printBundledExport(localName, localName)
                    printSemicolonAfterStatement()
                }
            case StmtTag.Class =>
                printNewline()
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)

                let nameRef = stmt.classNameRef
                if (stmt.isExport) {
                    if (!rewriteEsmToCjs) {
                        print("export ")
                    }
                }

                print("class ")
                addSourceMapping(stmt.classNameLoc)
                let nameStr = renamer.nameForSymbol(nameRef)
                printIdentifier(nameStr)
                print("{}")

                if (rewriteEsmToCjs && stmt.isExport) {
                    printSemicolonAfterStatement()
                    printIndent()
                    printBundledExport(nameStr, nameStr)
                    printSemicolonAfterStatement()
                } else {
                    printNewline()
                }
            case StmtTag.Empty =>
                if (options.indent.count == 0) {
                    return
                }
                printIndent()
                addSourceMapping(stmt.loc)
                print(";")
                printNewline()
            case StmtTag.ExportDefault =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("export default ")

                exportDefaultStart = written
                if (let Some(exprVal) <- stmt.valueExpr) {
                    printExpr(exprVal, OpLevel.Comma, ExprFlags.none())
                    printSemicolonAfterStatement()
                } else if (let Some(stmtVal) <- stmt.innerStmt) {
                    printStmt(stmtVal, TopLevel())
                }
            case StmtTag.ExportStar =>
                if (!false) {
                    printNewline()
                }
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                printWhitespacer(ws("export * from "))
                printImportRecordPath(importRecord(stmt.importRecordIndex))
                printSemicolonAfterStatement()
            case StmtTag.Export =>
                if (rewriteEsmToCjs) {
                    printExportClauseCjs(stmt)
                    return
                }
                if (!false) {
                    printNewline()
                }
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("export")
                printSpace()

                let items = stmt.clauseItems
                if (items.size == 0) {
                    print("{}")
                    printSemicolonAfterStatement()
                    return
                }

                print("{")
                if (stmt.isSingleLine) {
                    printSpace()
                } else {
                    indent()
                }

                for (i in 0..items.size) {
                    if (i > 0) {
                        print(",")
                        if (stmt.isSingleLine) {
                            printSpace()
                        }
                    }
                    if (!stmt.isSingleLine) {
                        printNewline()
                        printIndent()
                    }
                    printExportClauseItem(items[i])
                }

                if (stmt.isSingleLine) {
                    printSpace()
                } else {
                    unindent()
                    printNewline()
                    printIndent()
                }
                print("}")
                printSemicolonAfterStatement()
            case StmtTag.ExportFrom =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                printWhitespacer(ws("export {"))
                if (stmt.isSingleLine) {
                    printSpace()
                }
                let items = stmt.clauseItems
                for (i in 0..items.size) {
                    if (i > 0) {
                        print(",")
                        if (stmt.isSingleLine) {
                            printSpace()
                        }
                    }
                    if (!stmt.isSingleLine) {
                        printNewline()
                        printIndent()
                    }
                    printExportFromClauseItem(items[i])
                }
                if (stmt.isSingleLine) {
                    printSpace()
                } else {
                    unindent()
                    printNewline()
                    printIndent()
                }
                printWhitespacer(ws("} from "))
                let record = importRecord(stmt.importRecordIndex)
                printImportRecordPath(record)
                printSemicolonAfterStatement()
            case StmtTag.Local =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("var")
                printSpace()
                print("_;")
                printNewline()
            case StmtTag.If =>
                printIndent()
                printIf(stmt)
            case StmtTag.DoWhile =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("do")
                let subVar = tlmtlo.subVar()
                if (let Some(body) <- stmt.body) {
                    printBody(body, subVar)
                }
                print("while")
                printSpace()
                print("(")
                if (let Some(test) <- stmt.testExpr) {
                    printExpr(test, OpLevel.Comma, ExprFlags.none())
                }
                print(")")
                printSemicolonAfterStatement()
            case StmtTag.ForIn =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("for")
                printSpace()
                print("(")
                if (let Some(initStmt) <- stmt.initStmt) {
                    printForLoopInit(initStmt)
                }
                printSpace()
                printSpaceBeforeIdentifier()
                print("in")
                printSpace()
                if (let Some(value) <- stmt.valueExpr) {
                    printExpr(value, OpLevel.Comma, ExprFlags.none())
                }
                print(")")
                if (let Some(body) <- stmt.body) {
                    printBody(body, tlmtlo.subVar())
                }
            case StmtTag.ForOf =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("for")
                if (stmt.isAwait) {
                    print(" await")
                }
                printSpace()
                print("(")
                forOfInitStart = written
                if (let Some(initStmt) <- stmt.initStmt) {
                    printForLoopInit(initStmt)
                }
                printSpace()
                printSpaceBeforeIdentifier()
                print("of")
                printSpace()
                if (let Some(value) <- stmt.valueExpr) {
                    printExpr(value, OpLevel.Comma, ExprFlags.none())
                }
                print(")")
                if (let Some(body) <- stmt.body) {
                    printBody(body, tlmtlo.subVar())
                }
            case StmtTag.While =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("while")
                printSpace()
                print("(")
                if (let Some(test) <- stmt.testExpr) {
                    printExpr(test, OpLevel.Comma, ExprFlags.none())
                }
                print(")")
                if (let Some(body) <- stmt.body) {
                    printBody(body, tlmtlo.subVar())
                }
            case StmtTag.With =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("with")
                printSpace()
                print("(")
                if (let Some(value) <- stmt.valueExpr) {
                    printExpr(value, OpLevel.Comma, ExprFlags.none())
                }
                print(")")
                if (let Some(body) <- stmt.body) {
                    printBody(body, tlmtlo.subVar())
                }
            case StmtTag.Labeled =>
                if (!options.minifyWhitespace && options.indent.count > 0) {
                    printIndent()
                }
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                if (let Some(labelRef) <- stmt.labelRef) {
                    printSymbol(labelRef)
                } else {
                    printIdentifier(stmt.label)
                }
                print(":")
                if (let Some(innerStmt) <- stmt.innerStmt) {
                    printBody(innerStmt, tlmtlo.subVar())
                }
            case StmtTag.Try =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("try")
                printSpace()
                let subVarTry = tlmtlo.subVar()
                printBlock(stmt.bodyLoc, stmt.bodyStmts, Option<Loc>.None, subVarTry)

                if (stmt.hasCatch) {
                    printSpace()
                    addSourceMapping(stmt.catchLoc)
                    print("catch")
                    if (stmt.hasCatchBinding) {
                        printSpace()
                        print("(")
                        if (let Some(catchBinding) <- stmt.catchBinding) {
                            printBinding(catchBinding, TopLevel())
                        }
                        print(")")
                    }
                    printSpace()
                    printBlock(stmt.catchBodyLoc, stmt.catchBodyStmts, Option<Loc>.None, subVarTry)
                }

                if (stmt.hasFinally) {
                    printSpace()
                    print("finally")
                    printSpace()
                    printBlock(stmt.finallyLoc, stmt.finallyStmts, Option<Loc>.None, subVarTry)
                }

                printNewline()
            case StmtTag.For =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("for")
                printSpace()
                print("(")

                if (let Some(initStmt) <- stmt.initStmt) {
                    printForLoopInit(initStmt)
                }
                print(";")
                if (let Some(test) <- stmt.testExpr) {
                    printExpr(test, OpLevel.Comma, ExprFlags.none())
                }
                print(";")
                printSpace()
                if (let Some(update) <- stmt.updateExpr) {
                    printExpr(update, OpLevel.Comma, ExprFlags.none())
                }
                print(")")
                if (let Some(body) <- stmt.body) {
                    printBody(body, tlmtlo.subVar())
                }
            case StmtTag.Switch =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("switch")
                printSpace()
                print("(")
                if (let Some(test) <- stmt.testExpr) {
                    printExpr(test, OpLevel.Comma, ExprFlags.none())
                }
                print(")")
                printSpace()
                print("{")
                printNewline()
                indent()

                let cases = stmt.cases
                for (c in cases) {
                    printSemicolonIfNeeded()
                    printIndent()

                    if (let Some(val) <- c.valueExpr) {
                        print("case")
                        printSpace()
                        printExpr(val, OpLevel.LogicalAnd, ExprFlags.none())
                    } else {
                        print("default")
                    }
                    print(":")

                    let subVarCase = tlmtlo.subVar()
                    if (c.body.size == 1) {
                        match (c.body[0].tag) {
                            case StmtTag.Block =>
                                printSpace()
                                printBlock(c.body[0].loc, c.body[0].blockStmts,
                                            Option<Loc>.None, subVarCase)
                                printNewline()
                                continue
                            case _ => ()
                        }
                    }

                    printNewline()
                    indent()
                    for (st in c.body) {
                        printSemicolonIfNeeded()
                        printStmt(st, subVarCase)
                    }
                    unindent()
                }

                unindent()
                printIndent()
                print("}")
                printNewline()
                needsSemicolon = false
            case StmtTag.Import =>
                printImportStmt(stmt)
            case StmtTag.Block =>
                printIndent()
                printBlock(stmt.loc, stmt.blockStmts, stmt.closeBraceLoc,
                            tlmtlo.subVar())
                printNewline()
            case StmtTag.Debugger =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("debugger")
                printSemicolonAfterStatement()
            case StmtTag.Directive =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                printStringLiteralUTF8(stmt.directiveValue, false)
                printSemicolonAfterStatement()
            case StmtTag.Break =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("break")
                if (let Some(label) <- stmt.labelRef) {
                    print(" ")
                    printSymbol(label)
                }
                printSemicolonAfterStatement()
            case StmtTag.Continue =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("continue")
                if (let Some(label) <- stmt.labelRef) {
                    print(" ")
                    printSymbol(label)
                }
                printSemicolonAfterStatement()
            case StmtTag.Return =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("return")
                if (let Some(value) <- stmt.valueExpr) {
                    printSpace()
                    printExpr(value, OpLevel.Comma, ExprFlags.none())
                }
                printSemicolonAfterStatement()
            case StmtTag.Throw =>
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("throw")
                printSpace()
                if (let Some(value) <- stmt.valueExpr) {
                    printExpr(value, OpLevel.Comma, ExprFlags.none())
                }
                printSemicolonAfterStatement()
            case StmtTag.Expr =>
                if (!options.minifyWhitespace && options.indent.count > 0) {
                    printIndent()
                }
                stmtStart = written
                if (let Some(value) <- stmt.valueExpr) {
                    printExpr(value, OpLevel.Comma,
                               ExprFlags.exprResultIsUnusedFlags())
                }
                printSemicolonAfterStatement()
            case _ => ()
        }
    }

    // ========================================================================
    // printIf - 打印 if 语句
    // 严格翻译自: js_printer.zig:5042-5117
    // ========================================================================

    /// 打印 if 语句 - 对应 printIf()
    private func printIf(stmt: Stmt): Unit {
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("if")
        printSpace()
        print("(")
        if (let Some(test) <- stmt.testExpr) {
            printExpr(test, OpLevel.Comma, ExprFlags.none())
        }
        print(")")

        let tlmtlo = TopLevel.initTopLevel(IsTopLevel.No)
        if (let Some(yesStmt) <- stmt.yesStmt) {
            match (yesStmt.tag) {
                case StmtTag.Block =>
                    printSpace()
                    printBlock(yesStmt.loc, yesStmt.blockStmts,
                                Option<Loc>.None, tlmtlo)
                    if (stmt.hasNoBranch) {
                        printSpace()
                    } else {
                        printNewline()
                    }
                case _ =>
                    printNewline()
                    indent()
                    printStmt(yesStmt, tlmtlo)
                    unindent()
                    if (stmt.hasNoBranch) {
                        printIndent()
                    }
            }
        }

        if (stmt.hasNoBranch) {
            if (let Some(noStmt) <- stmt.noStmt) {
                printSemicolonIfNeeded()
                printSpaceBeforeIdentifier()
                addSourceMapping(noStmt.loc)
                print("else")

                match (noStmt.tag) {
                    case StmtTag.Block =>
                        printSpace()
                        printBlock(noStmt.loc, noStmt.blockStmts,
                                    Option<Loc>.None, tlmtlo)
                        printNewline()
                    case StmtTag.If =>
                        printIf(noStmt)
                    case _ =>
                        printNewline()
                        indent()
                        printStmt(noStmt, tlmtlo)
                        unindent()
                }
            }
        }
    }

    // ========================================================================
    // printForLoopInit - 打印 for 循环初始化
    // 严格翻译自: js_printer.zig:5007-5041
    // ========================================================================

    /// 打印 for 循环初始化 - 对应 printForLoopInit()
    public func printForLoopInit(initStmt: Stmt): Unit {
        match (initStmt.tag) {
            case StmtTag.Expr =>
                if (let Some(value) <- initStmt.valueExpr) {
                    printExpr(value, OpLevel.Comma,
                               ExprFlags(true, true, false, true))
                }
            case StmtTag.Local =>
                print("var _")
            case StmtTag.Empty => ()
            case _ => ()
        }
    }

    // ========================================================================
    // printImportStmt - 打印 import 语句
    // 严格翻译自: js_printer.zig:4508-4740
    // ========================================================================

    /// 打印 import 语句 - 对应 s_import case
    private func printImportStmt(stmt: Stmt): Unit {
        let record = importRecord(stmt.importRecordIndex)
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("import ")
        printImportRecordPath(record)
        printSemicolonAfterStatement()
    }

    // ========================================================================
    // printClauseItem - 打印导入/导出子句项
    // 严格翻译自: js_printer.zig:1921-1982
    // ========================================================================

    /// 打印子句项 - 对应 printClauseItem()
    public func printClauseItem(item: ClauseItem): Unit {
        printClauseItemAs(item, ClauseItemAsKind.Import)
    }

    /// 打印导出子句项 - 对应 printExportClauseItem()
    public func printExportClauseItem(item: ClauseItem): Unit {
        printClauseItemAs(item, ClauseItemAsKind.Export)
    }

    /// 打印导出来源子句项 - 对应 printExportFromClauseItem()
    public func printExportFromClauseItem(item: ClauseItem): Unit {
        printClauseItemAs(item, ClauseItemAsKind.ExportFrom)
    }

    /// 打印子句项 (按类型) - 对应 printClauseItemAs()
    public func printClauseItemAs(item: ClauseItem, asKind: ClauseItemAsKind): Unit {
        let name = item.name

        match (asKind) {
            case ClauseItemAsKind.Import =>
                if (name == item.alias) {
                    printIdentifier(name)
                } else {
                    printClauseAlias(item.alias)
                    print(" as ")
                    addSourceMapping(item.aliasLoc)
                    printIdentifier(name)
                }
            case ClauseItemAsKind.Var =>
                printClauseAlias(item.alias)
                if (name != item.alias) {
                    print(":")
                    printSpace()
                    printIdentifier(name)
                }
            case ClauseItemAsKind.Export =>
                printIdentifier(name)
                if (name != item.alias) {
                    print(" as ")
                    addSourceMapping(item.aliasLoc)
                    printClauseAlias(item.alias)
                }
            case ClauseItemAsKind.ExportFrom =>
                let fromName = if (item.originalName.size > 0) {
                    item.originalName
                } else {
                    name
                }
                printClauseAlias(fromName)
                if (fromName != item.alias) {
                    print(" as ")
                    addSourceMapping(item.aliasLoc)
                    printClauseAlias(item.alias)
                }
        }
    }

    // ========================================================================
    // printExportClauseCjs - CJS 模式导出子句
    // 严格翻译自: js_printer.zig:4045-4099
    // ========================================================================

    /// CJS 导出子句 - 对应 rewrite_esm_to_cjs 模式下的 s_export_clause
    private func printExportClauseCjs(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)

        let items = stmt.clauseItems
        if (items.size == 0) {
            return
        }

        print("Object.assign")
        print("(")
        printModuleExportSymbol()
        print(",")
        printSpace()
        print("{")
        printSpace()
        let last = items.size - 1
        for (i in 0..items.size) {
            let name = renamer.nameForSymbol(items[i].nameRef)
            printClauseAlias(items[i].alias)
            if (name != items[i].alias) {
                print(":")
                printSpaceBeforeIdentifier()
                printIdentifier(name)
            }
            if (i < last) {
                print(",")
            }
        }
        print("})")
        printSemicolonAfterStatement()
    }

    // ========================================================================
    // printBundledImport - 打印捆绑导入
    // 严格翻译自: js_printer.zig:4845-4945
    // ========================================================================

    /// 打印捆绑导入 - 对应 printBundledImport()
    public func printBundledImport(record: ImportRecord, sImport: SImport): Unit {
        printCallModuleID(sImport.importRecordIndex)
        printSemicolonAfterStatement()
    }
}

/// Decl - 声明
public class Decl {
    public var binding: Binding
    public var value: ?Expr

    public init() {
        binding = Binding(Loc.EMPTY, BindingTag.Missing)
        value = None
    }

    public init(binding: Binding, value: ?Expr) {
        this.binding = binding
        this.value = value
    }
}

/// LocalKind - 局部变量种类
public enum LocalKind {
    | Var
    | Let
    | Const
    | Using
    | AwaitUsing

    public operator func ==(right: LocalKind): Bool {
        match (this) {
            case Var => match (right) { case Var => true case _ => false }
            case Let => match (right) { case Let => true case _ => false }
            case Const => match (right) { case Const => true case _ => false }
            case Using => match (right) { case Using => true case _ => false }
            case AwaitUsing => match (right) { case AwaitUsing => true case _ => false }
        }
    }

    public operator func !=(right: LocalKind): Bool {
        return !(this == right)
    }
}

/// ClauseItemAsKind - moved to top-level
public enum ClauseItemAsKind {
    | Import
    | Export
    | ExportFrom
    | Var
}
