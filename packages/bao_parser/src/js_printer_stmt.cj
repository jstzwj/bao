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
public class JSPrinter {

    // ========================================================================
    // printBody - 打印语句体
    // 严格翻译自: js_printer.zig:1131-1145
    //   pub fn printBody(p: *Printer, stmt: Stmt, tlmtlo: TopLevel) void
    // ========================================================================

    /// 打印语句体 - 对应 printBody()
    public func printBody(stmt: Stmt, tlmtlo: TopLevel): Unit {
        match (stmt.tag) {
            case StmtTag.SBlock => {
                printSpace()
                printBlock(stmt.loc, stmt.blockStmts, None, tlmtlo)
                printNewline()
            }
            case _ => {
                printNewline()
                indent()
                printStmt(stmt, tlmtlo)
                unindent()
            }
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
        if (stmts.size() > 0) {
            printNewline()
            indent()
            printBlockBody(stmts, tlmtlo)
            unindent()
            printIndent()
        }
        if (let cbl = closeBraceLoc) {
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
    public func printFunc(func: Expr): Unit {
        printFnArgs(func.loc, func.args, func.hasRestArg, false)
        printSpace()
        printBlock(func.bodyLoc, func.bodyStmts, None,
                    TopLevel.initTopLevel(IsTopLevel.No))
    }

    // ========================================================================
    // printFnArgs - 打印函数参数
    // 严格翻译自: js_printer.zig:1373-1411
    // ========================================================================

    /// 打印函数参数 - 对应 printFnArgs()
    public func printFnArgs(openParenLoc: Loc, args: ArrayList<Expr>,
                             hasRestArg: Bool, isArrow: Bool): Unit {
        if (let loc = openParenLoc) {
            if (!loc.isEmpty()) {
                addSourceMapping(loc)
            }
        }
        print("(")

        for (i in 0..args.size()) {
            if (i > 0) {
                print(",")
                printSpace()
            }

            if (hasRestArg && i + 1 == args.size()) {
                print("...")
            }

            printBinding(args[i].binding, TopLevel())

            if (let defaultVal = args[i].defaultExpr) {
                printWhitespacer(ws(" = "))
                printExpr(defaultVal, OpLevel.Comma, ExprFlags.none())
            }
        }

        print(")")
    }

    // ========================================================================
    // printClass - 打印类
    // 严格翻译自: js_printer.zig:1419-1460
    // ========================================================================

    /// 打印类 - 对应 printClass()
    public func printClass(expr: Expr): Unit {
        if (let extends = expr.extendsExpr) {
            print(" extends")
            printSpace()
            printExpr(extends, OpLevel.Primary, ExprFlags.none())
        }

        printSpace()
        addSourceMapping(expr.bodyLoc)
        print("{")
        printNewline()
        indent()

        let properties = expr.properties
        for (item in properties) {
            printSemicolonIfNeeded()
            printIndent()

            if (item.isClassStaticBlock) {
                print("static")
                printSpace()
                printBlock(item.loc, item.blockStmts, None,
                            TopLevel.initTopLevel(IsTopLevel.No))
                printNewline()
                continue
            }

            printProperty(item)

            if (item.valueExpr == None) {
                printSemicolonAfterStatement()
            } else {
                printNewline()
            }
        }

        needsSemicolon = false
        unindent()
        printIndent()
        print("}")
    }

    // ========================================================================
    // printProperty - 打印属性
    // 严格翻译自: js_printer.zig:3324-3608
    // ========================================================================

    /// 打印属性 - 对应 printProperty()
    public func printProperty(item: Expr): Unit {
        // spread
        if (item.isSpread) {
            print("...")
            if (let val = item.valueExpr) {
                printExpr(val, OpLevel.Comma, ExprFlags.none())
            }
            return
        }

        // static
        if (item.isStatic) {
            print("static")
            printSpace()
        }

        // get/set/accessor
        if (item.isGetter) {
            printSpaceBeforeIdentifier()
            print("get")
            printSpace()
        } else if (item.isSetter) {
            printSpaceBeforeIdentifier()
            print("set")
            printSpace()
        } else if (item.isAutoAccessor) {
            printSpaceBeforeIdentifier()
            print("accessor")
            printSpace()
        }

        // 方法简写
        if (let val = item.valueExpr) {
            if (val.tag == ExprTag.Function && item.isMethod) {
                if (val.isAsync) {
                    printSpaceBeforeIdentifier()
                    print("async")
                }
                if (val.isGenerator) {
                    print("*")
                }
                if (val.isGenerator && val.isAsync) {
                    printSpace()
                }
            }
        }

        // key 为 null 的情况
        if (let key = item.keyExpr) {
            // computed
            if (item.isComputed) {
                print("[")
                printExpr(key, OpLevel.Comma, ExprFlags.none())
                print("]")

                if (let val = item.valueExpr) {
                    if (val.tag == ExprTag.Function && item.isMethod) {
                        printFunc(val)
                        return
                    }
                    print(":")
                    printSpace()
                    printExpr(val, OpLevel.Comma, ExprFlags.none())
                }
                return
            }

            // string key
            if (key.tag == ExprTag.String) {
                addSourceMapping(key.loc)
                let keyStr = key.stringValue
                if (isIdentifierStr(keyStr)) {
                    printSpaceBeforeIdentifier()
                    printIdentifier(keyStr)
                } else {
                    printStringLiteralUTF8(keyStr, false)
                }
            } else {
                // 其他 key
                if (!isJson) {
                    printExpr(key, OpLevel.Comma, ExprFlags.none())
                }
            }
        }

        // 非普通属性 (get/set 方法)
        if (!item.isNormal && !item.isAutoAccessor) {
            if (let val = item.valueExpr) {
                if (val.tag == ExprTag.Function) {
                    printFunc(val)
                    return
                }
            }
        }

        // 值
        if (let val = item.valueExpr) {
            if (val.tag == ExprTag.Function && item.isMethod) {
                printFunc(val)
                return
            }

            print(":")
            printSpace()
            printExpr(val, OpLevel.Comma, ExprFlags.none())
        }

        // 初始化器
        if (let initial = item.initializer) {
            printInitializer(initial)
        }
    }

    // ========================================================================
    // printBinding - 打印绑定
    // 严格翻译自: js_printer.zig:3617-3796
    // ========================================================================

    /// 打印绑定 - 对应 printBinding()
    public func printBinding(binding: Binding, tlm: TopLevel): Unit {
        match (binding.tag) {
            case BindingTag.BMissing => ()
            case BindingTag.BIdentifier => {
                printSpaceBeforeIdentifier()
                addSourceMapping(binding.loc)
                printSymbol(binding.ref)
            }
            case BindingTag.BArray => {
                print("[")
                let items = binding.arrayItems
                if (items.size() > 0) {
                    if (!binding.isSingleLine) {
                        indent()
                    }

                    for (i in 0..items.size()) {
                        if (i > 0) {
                            print(",")
                            if (binding.isSingleLine) {
                                printSpace()
                            }
                        }

                        if (!binding.isSingleLine) {
                            printNewline()
                            printIndent()
                        }

                        let isLast = i + 1 == items.size()
                        if (binding.hasSpread && isLast) {
                            print("...")
                        }

                        printBinding(items[i], tlm)

                        if (isLast && items[i].tag == BindingTag.BMissing) {
                            print(",")
                        }
                    }

                    if (!binding.isSingleLine) {
                        unindent()
                        printNewline()
                        printIndent()
                    }
                }
                print("]")
            }
            case BindingTag.BObject => {
                print("{")
                let props = binding.objectProperties
                if (props.size() > 0) {
                    if (!binding.isSingleLine) {
                        indent()
                    }

                    for (i in 0..props.size()) {
                        if (i > 0) {
                            print(",")
                        }
                        if (binding.isSingleLine) {
                            printSpace()
                        } else {
                            printNewline()
                            printIndent()
                        }

                        let prop = props[i]
                        if (prop.flags.isSpread) {
                            print("...")
                        } else {
                            if (prop.flags.isComputed) {
                                print("[")
                                if (let key = prop.key) {
                                    printExpr(key, OpLevel.Comma, ExprFlags.none())
                                }
                                print("]:")
                                printSpace()
                                printBinding(prop.value, tlm)
                                continue
                            }

                            // string key
                            if (let key = prop.key) {
                                if (key.tag == ExprTag.String) {
                                    let keyStr = key.stringValue
                                    if (isIdentifierStr(keyStr)) {
                                        printSpaceBeforeIdentifier()
                                        printIdentifier(keyStr)
                                    } else {
                                        printStringLiteralUTF8(keyStr, false)
                                    }
                                } else {
                                    printExpr(key, OpLevel.Comma, ExprFlags.none())
                                }
                            }

                            print(":")
                            printSpace()
                        }

                        printBinding(prop.value, tlm)
                    }

                    if (!binding.isSingleLine) {
                        unindent()
                        printNewline()
                        printIndent()
                    } else {
                        printSpace()
                    }
                }
                print("}")
            }
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

        if (decls.size() == 0) {
            return
        }

        printBinding(decls[0].binding, tlm)
        if (let value = decls[0].value) {
            printWhitespacer(ws(" = "))
            printExpr(value, OpLevel.Comma, flags)
        }

        for (i in 1..decls.size()) {
            print(",")
            printSpace()
            printBinding(decls[i].binding, tlm)
            if (let value = decls[i].value) {
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

        if (rewriteEsmToCjs && isExport && decls.size() > 0) {
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
        let prevStmtTag = prevStmtTag
        defer {
            prevStmtTag = stmt.tag
        }

        match (stmt.tag) {
            case StmtTag.SComment => {
                printIndent()
                addSourceMapping(stmt.loc)
                printIndentedComment(stmt.commentText)
            }
            case StmtTag.SFunction => {
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
                printFunc(stmt)

                printNewline()

                if (rewriteEsmToCjs && stmt.isExport) {
                    printIndent()
                    printBundledExport(localName, localName)
                    printSemicolonAfterStatement()
                }
            }
            case StmtTag.SClass => {
                if (prevStmtTag != StmtTag.SEmpty) {
                    printNewline()
                }
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
                printClass(stmt)

                if (rewriteEsmToCjs && stmt.isExport) {
                    printSemicolonAfterStatement()
                    printIndent()
                    printBundledExport(nameStr, nameStr)
                    printSemicolonAfterStatement()
                } else {
                    printNewline()
                }
            }
            case StmtTag.SEmpty => {
                if (prevStmtTag == StmtTag.SEmpty && options.indent.count == 0) {
                    return
                }
                printIndent()
                addSourceMapping(stmt.loc)
                print(";")
                printNewline()
            }
            case StmtTag.SExportDefault => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("export default ")

                exportDefaultStart = written
                if (let exprVal = stmt.valueExpr) {
                    printExpr(exprVal, OpLevel.Comma, ExprFlags.none())
                    printSemicolonAfterStatement()
                } else if (let stmtVal = stmt.innerStmt) {
                    printStmt(stmtVal, TopLevel())
                }
            }
            case StmtTag.SExportStar => {
                if (!prevStmtTag.isExportLike()) {
                    printNewline()
                }
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                printWhitespacer(ws("export * from "))
                printImportRecordPath(importRecord(stmt.importRecordIndex))
                printSemicolonAfterStatement()
            }
            case StmtTag.SExportClause => {
                if (rewriteEsmToCjs) {
                    printExportClauseCjs(stmt)
                    return
                }
                if (!prevStmtTag.isExportLike()) {
                    printNewline()
                }
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("export")
                printSpace()

                let items = stmt.clauseItems
                if (items.size() == 0) {
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

                for (i in 0..items.size()) {
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
                    let name = renamer.nameForSymbol(items[i].name.ref)
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
            }
            case StmtTag.SExportFrom => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                printWhitespacer(ws("export {"))
                if (stmt.isSingleLine) {
                    printSpace()
                }
                let items = stmt.clauseItems
                for (i in 0..items.size()) {
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
            }
            case StmtTag.SLocal => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                match (stmt.localKind) {
                    case LocalKind.Const =>
                        printDeclStmt(stmt.isExport, "const", stmt.decls, tlmtlo)
                    case LocalKind.Let =>
                        printDeclStmt(stmt.isExport, "let", stmt.decls, tlmtlo)
                    case LocalKind.Var =>
                        printDeclStmt(stmt.isExport, "var", stmt.decls, tlmtlo)
                    case LocalKind.Using =>
                        printDeclStmt(stmt.isExport, "using", stmt.decls, tlmtlo)
                    case LocalKind.AwaitUsing =>
                        printDeclStmt(stmt.isExport, "await using", stmt.decls, tlmtlo)
                }
            }
            case StmtTag.SIf => {
                printIndent()
                printIf(stmt)
            }
            case StmtTag.SDoWhile => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("do")
                let subVar = tlmtlo.subVar()
                match (stmt.body.tag) {
                    case StmtTag.SBlock => {
                        printSpace()
                        printBlock(stmt.body.loc, stmt.body.blockStmts,
                                    None, subVar)
                        printSpace()
                    }
                    case _ => {
                        printNewline()
                        indent()
                        printStmt(stmt.body, subVar)
                        printSemicolonIfNeeded()
                        unindent()
                        printIndent()
                    }
                }
                print("while")
                printSpace()
                print("(")
                printExpr(stmt.testExpr, OpLevel.Comma, ExprFlags.none())
                print(")")
                printSemicolonAfterStatement()
            }
            case StmtTag.SForIn => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("for")
                printSpace()
                print("(")
                printForLoopInit(stmt.initStmt)
                printSpace()
                printSpaceBeforeIdentifier()
                print("in")
                printSpace()
                printExpr(stmt.valueExpr, OpLevel.Comma, ExprFlags.none())
                print(")")
                printBody(stmt.body, tlmtlo.subVar())
            }
            case StmtTag.SForOf => {
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
                printForLoopInit(stmt.initStmt)
                printSpace()
                printSpaceBeforeIdentifier()
                print("of")
                printSpace()
                printExpr(stmt.valueExpr, OpLevel.Comma, ExprFlags.none())
                print(")")
                printBody(stmt.body, tlmtlo.subVar())
            }
            case StmtTag.SWhile => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("while")
                printSpace()
                print("(")
                printExpr(stmt.testExpr, OpLevel.Comma, ExprFlags.none())
                print(")")
                printBody(stmt.body, tlmtlo.subVar())
            }
            case StmtTag.SWith => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("with")
                printSpace()
                print("(")
                printExpr(stmt.valueExpr, OpLevel.Comma, ExprFlags.none())
                print(")")
                printBody(stmt.body, tlmtlo.subVar())
            }
            case StmtTag.SLabel => {
                if (!options.minifyWhitespace && options.indent.count > 0) {
                    printIndent()
                }
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                printSymbol(stmt.labelRef)
                print(":")
                printBody(stmt.innerStmt, tlmtlo.subVar())
            }
            case StmtTag.STry => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("try")
                printSpace()
                let subVarTry = tlmtlo.subVar()
                printBlock(stmt.bodyLoc, stmt.bodyStmts, None, subVarTry)

                if (stmt.hasCatch) {
                    printSpace()
                    addSourceMapping(stmt.catchLoc)
                    print("catch")
                    if (stmt.hasCatchBinding) {
                        printSpace()
                        print("(")
                        printBinding(stmt.catchBinding, TopLevel())
                        print(")")
                    }
                    printSpace()
                    printBlock(stmt.catchBodyLoc, stmt.catchBodyStmts, None, subVarTry)
                }

                if (stmt.hasFinally) {
                    printSpace()
                    print("finally")
                    printSpace()
                    printBlock(stmt.finallyLoc, stmt.finallyStmts, None, subVarTry)
                }

                printNewline()
            }
            case StmtTag.SFor => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("for")
                printSpace()
                print("(")

                if (stmt.hasInit) {
                    printForLoopInit(stmt.initStmt)
                }
                print(";")
                if (stmt.hasTest) {
                    printExpr(stmt.testExpr, OpLevel.Comma, ExprFlags.none())
                }
                print(";")
                printSpace()
                if (stmt.hasUpdate) {
                    printExpr(stmt.updateExpr, OpLevel.Comma, ExprFlags.none())
                }
                print(")")
                printBody(stmt.body, tlmtlo.subVar())
            }
            case StmtTag.SSwitch => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("switch")
                printSpace()
                print("(")
                printExpr(stmt.testExpr, OpLevel.Comma, ExprFlags.none())
                print(")")
                printSpace()
                print("{")
                printNewline()
                indent()

                let cases = stmt.cases
                for (c in cases) {
                    printSemicolonIfNeeded()
                    printIndent()

                    if (let val = c.valueExpr) {
                        print("case")
                        printSpace()
                        printExpr(val, OpLevel.LogicalAnd, ExprFlags.none())
                    } else {
                        print("default")
                    }
                    print(":")

                    let subVarCase = tlmtlo.subVar()
                    if (c.body.size() == 1) {
                        match (c.body[0].tag) {
                            case StmtTag.SBlock => {
                                printSpace()
                                printBlock(c.body[0].loc, c.body[0].blockStmts,
                                            None, subVarCase)
                                printNewline()
                                continue
                            }
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
            }
            case StmtTag.SImport => {
                printImportStmt(stmt)
            }
            case StmtTag.SBlock => {
                printIndent()
                printBlock(stmt.loc, stmt.blockStmts, stmt.closeBraceLoc,
                            tlmtlo.subVar())
                printNewline()
            }
            case StmtTag.SDebugger => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("debugger")
                printSemicolonAfterStatement()
            }
            case StmtTag.SDirective => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                printStringLiteralUTF8(stmt.directiveValue, false)
                printSemicolonAfterStatement()
            }
            case StmtTag.SBreak => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("break")
                if (let label = stmt.labelRef) {
                    print(" ")
                    printSymbol(label)
                }
                printSemicolonAfterStatement()
            }
            case StmtTag.SContinue => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("continue")
                if (let label = stmt.labelRef) {
                    print(" ")
                    printSymbol(label)
                }
                printSemicolonAfterStatement()
            }
            case StmtTag.SReturn => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("return")
                if (let value = stmt.valueExpr) {
                    printSpace()
                    printExpr(value, OpLevel.Comma, ExprFlags.none())
                }
                printSemicolonAfterStatement()
            }
            case StmtTag.SThrow => {
                printIndent()
                printSpaceBeforeIdentifier()
                addSourceMapping(stmt.loc)
                print("throw")
                printSpace()
                printExpr(stmt.valueExpr, OpLevel.Comma, ExprFlags.none())
                printSemicolonAfterStatement()
            }
            case StmtTag.SExpr => {
                if (!options.minifyWhitespace && options.indent.count > 0) {
                    printIndent()
                }
                stmtStart = written
                printExpr(stmt.valueExpr, OpLevel.Comma,
                           ExprFlags.exprResultIsUnusedFlags())
                printSemicolonAfterStatement()
            }
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
        printExpr(stmt.testExpr, OpLevel.Comma, ExprFlags.none())
        print(")")

        let tlmtlo = TopLevel.initTopLevel(IsTopLevel.No)
        match (stmt.yesStmt.tag) {
            case StmtTag.SBlock => {
                printSpace()
                printBlock(stmt.yesStmt.loc, stmt.yesStmt.blockStmts,
                            None, tlmtlo)
                if (stmt.hasNoBranch) {
                    printSpace()
                } else {
                    printNewline()
                }
            }
            case _ => {
                printNewline()
                indent()
                printStmt(stmt.yesStmt, tlmtlo)
                unindent()
                if (stmt.hasNoBranch) {
                    printIndent()
                }
            }
        }

        if (stmt.hasNoBranch) {
            printSemicolonIfNeeded()
            printSpaceBeforeIdentifier()
            addSourceMapping(stmt.noStmt.loc)
            print("else")

            match (stmt.noStmt.tag) {
                case StmtTag.SBlock => {
                    printSpace()
                    printBlock(stmt.noStmt.loc, stmt.noStmt.blockStmts,
                                None, tlmtlo)
                    printNewline()
                }
                case StmtTag.SIf => {
                    printIf(stmt.noStmt)
                }
                case _ => {
                    printNewline()
                    indent()
                    printStmt(stmt.noStmt, tlmtlo)
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
            case StmtTag.SExpr => {
                printExpr(initStmt.valueExpr, OpLevel.Comma,
                           ExprFlags(true, true, false, true))
            }
            case StmtTag.SLocal => {
                let keyword = match (initStmt.localKind) {
                    case LocalKind.Var => "var"
                    case LocalKind.Let => "let"
                    case LocalKind.Const => "const"
                    case LocalKind.Using => "using"
                    case LocalKind.AwaitUsing => "await using"
                }
                printDecls(keyword, initStmt.decls,
                            ExprFlags(true, true, false, false), TopLevel())
            }
            case StmtTag.SEmpty => ()
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

        // 禁用路径处理
        if (record.pathIsDisabled) {
            if (record.flags.containsImportStar) {
                print("var ")
                printSymbol(stmt.namespaceRef)
                printEquals()
                printDisabledImport()
                printSemicolonAfterStatement()
            }

            if (stmt.items.size() > 0 || stmt.defaultName != None) {
                printIndent()
                printSpaceBeforeIdentifier()
                printWhitespacer(ws("var {"))

                if (let defaultName = stmt.defaultName) {
                    printSpace()
                    print("default:")
                    printSpace()
                    printSymbol(defaultName.ref)
                }

                let items = stmt.clauseItems
                if (items.size() > 0) {
                    printSpace()
                    print(",")
                    printSpace()
                    for (i in 0..items.size()) {
                        printClauseItemAs(items[i], ClauseItemAsKind.Var)
                        if (i < Int64(items.size()) - 1) {
                            print(",")
                            printSpace()
                        }
                    }
                }

                print("}")
                printEquals()
                printDisabledImport()
                printSemicolonAfterStatement()
            }
            return
        }

        print("import")

        var itemCount: Int64 = 0

        if (let name = stmt.defaultName) {
            print(" ")
            printSymbol(name.ref)
            itemCount += 1
        }

        let items = stmt.clauseItems
        if (items.size() > 0) {
            if (itemCount > 0) {
                print(",")
            }
            printSpace()
            print("{")
            if (stmt.isSingleLine) {
                printSpace()
            } else {
                indent()
            }

            for (i in 0..items.size()) {
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
                printClauseItem(items[i])
            }

            if (stmt.isSingleLine) {
                printSpace()
            } else {
                unindent()
                printNewline()
                printIndent()
            }
            print("}")
            itemCount += 1
        }

        if (stmt.hasImportStar) {
            if (itemCount > 0) {
                print(",")
            }
            printSpace()
            printWhitespacer(ws("* as"))
            print(" ")
            printSymbol(stmt.namespaceRef)
            itemCount += 1
        }

        if (itemCount > 0) {
            if (!options.minifyWhitespace || stmt.hasImportStar || items.size() == 0) {
                print(" ")
            }
            printWhitespacer(ws("from "))
        }

        printImportRecordPath(record)
        printSemicolonAfterStatement()
    }

    // ========================================================================
    // printClauseItem - 打印导入/导出子句项
    // 严格翻译自: js_printer.zig:1921-1982
    // ========================================================================

    /// 子句项类型
    public enum ClauseItemAsKind {
        | Import
        | Export
        | ExportFrom
        | Var
    }

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
        let name = renamer.nameForSymbol(item.name.ref)

        match (asKind) {
            case ClauseItemAsKind.Import => {
                if (name == item.alias) {
                    printIdentifier(name)
                } else {
                    printClauseAlias(item.alias)
                    print(" as ")
                    addSourceMapping(item.aliasLoc)
                    printIdentifier(name)
                }
            }
            case ClauseItemAsKind.Var => {
                printClauseAlias(item.alias)
                if (name != item.alias) {
                    print(":")
                    printSpace()
                    printIdentifier(name)
                }
            }
            case ClauseItemAsKind.Export => {
                printIdentifier(name)
                if (name != item.alias) {
                    print(" as ")
                    addSourceMapping(item.aliasLoc)
                    printClauseAlias(item.alias)
                }
            }
            case ClauseItemAsKind.ExportFrom => {
                let fromName = if (item.originalName.length > 0) {
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
        if (items.size() == 0) {
            return
        }

        print("Object.assign")
        print("(")
        printModuleExportSymbol()
        print(",")
        printSpace()
        print("{")
        printSpace()
        let last = items.size() - 1
        for (i in 0..items.size()) {
            let name = renamer.nameForSymbol(items[i].name.ref)
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
        if (record.flags.isInternal) {
            return
        }

        let importRecord = importRecord(sImport.importRecordIndex)
        let isDisabled = importRecord.pathIsDisabled
        let moduleId = importRecord.moduleId

        if (record.pathIsDisabled) {
            if (symbols().get(sImport.namespaceRef) == None) {
                return
            }
        }

        let variant = ImportVariant.determine(record, sImport)

        match (variant) {
            case ImportVariant.PathOnly => {
                if (!isDisabled) {
                    printCallModuleID(moduleId)
                    printSemicolonAfterStatement()
                }
            }
            case ImportVariant.ImportItemsAndDefault | ImportVariant.ImportDefault => {
                if (!isDisabled) {
                    print("var $")
                    printModuleId(moduleId)
                    printEquals()
                    printLoadFromBundle(sImport.importRecordIndex)

                    if (let defaultName = sImport.defaultName) {
                        print(", ")
                        printSymbol(defaultName.ref)
                        print(" = (($")
                        printModuleId(moduleId)
                        print(" && \"default\" in $")
                        printModuleId(moduleId)
                        print(") ? $")
                        printModuleId(moduleId)
                        print(".default : $")
                        printModuleId(moduleId)
                        print(")")
                    }
                } else {
                    if (let defaultName = sImport.defaultName) {
                        print("var ")
                        printSymbol(defaultName.ref)
                        printEquals()
                        printDisabledImport()
                    }
                }
                printSemicolonAfterStatement()
            }
            case ImportVariant.ImportStarAndImportDefault => {
                print("var ")
                printSymbol(sImport.namespaceRef)
                printEquals()
                printLoadFromBundle(sImport.importRecordIndex)

                if (let defaultName = sImport.defaultName) {
                    print(",")
                    printSpace()
                    printSymbol(defaultName.ref)
                    printEquals()
                    if (!isBunPlatform) {
                        print("(")
                        printSymbol(sImport.namespaceRef)
                        printWhitespacer(ws(" && \"default\" in "))
                        printSymbol(sImport.namespaceRef)
                        printWhitespacer(ws(" ? "))
                        printSymbol(sImport.namespaceRef)
                        printWhitespacer(ws(".default : "))
                        printSymbol(sImport.namespaceRef)
                        print(")")
                    } else {
                        printSymbol(sImport.namespaceRef)
                    }
                }
                printSemicolonAfterStatement()
            }
            case ImportVariant.ImportStar => {
                print("var ")
                printSymbol(sImport.namespaceRef)
                printEquals()
                printLoadFromBundle(sImport.importRecordIndex)
                printSemicolonAfterStatement()
            }
            case _ => {
                print("var $")
                printModuleIdAssumeEnabled(moduleId)
                printEquals()
                printLoadFromBundle(sImport.importRecordIndex)
                printSemicolonAfterStatement()
            }
        }
    }
}

// ============================================================================
// Stmt - 语句节点
// 对应 Bun Stmt
// ============================================================================

/// 语句节点 - 对应 Bun Stmt
public class Stmt {
    public var loc: Loc
    public var tag: StmtTag

    // 函数/类相关
    public var isExport: Bool
    public var isAsync: Bool
    public var isGenerator: Bool
    public var funcNameRef: Ref
    public var funcNameLoc: Loc
    public var classNameRef: Ref
    public var classNameLoc: Loc

    // 块相关
    public var blockStmts: ArrayList<Stmt>
    public var closeBraceLoc: ?Loc

    // 表达式相关
    public var valueExpr: ?Expr
    public var testExpr: ?Expr
    public var yesExpr: ?Expr
    public var noExpr: ?Expr
    public var updateExpr: ?Expr

    // 条件/循环
    public var body: Stmt
    public var hasNoBranch: Bool
    public var noStmt: Stmt
    public var yesStmt: Stmt
    public var hasTest: Bool
    public var hasInit: Bool
    public var hasUpdate: Bool
    public var initStmt: Stmt
    public var isAwait: Bool
    public var hasImportStar: Bool

    // 导入
    public var importRecordIndex: Int64
    public var namespaceRef: Ref
    public var defaultName: ?LocRef
    public var clauseItems: ArrayList<ClauseItem>
    public var isSingleLine: Bool
    public var starNameLoc: ?Loc

    // 声明
    public var decls: ArrayList<Decl>
    public var localKind: LocalKind

    // 标签
    public var labelRef: ?Ref
    public var innerStmt: Stmt

    // try/catch/finally
    public var bodyLoc: Loc
    public var bodyStmts: ArrayList<Stmt>
    public var hasCatch: Bool
    public var catchLoc: Loc
    public var hasCatchBinding: Bool
    public var catchBinding: Binding
    public var catchBodyLoc: Loc
    public var catchBodyStmts: ArrayList<Stmt>
    public var hasFinally: Bool
    public var finallyLoc: Loc
    public var finallyStmts: ArrayList<Stmt>

    // switch
    public var cases: ArrayList<SwitchCase>

    // 注释
    public var commentText: String

    // 指令
    public var directiveValue: String

    // export default
    public var innerStmtVal: ?Stmt

    public init() {
        loc = Loc.EMPTY
        tag = StmtTag.SEmpty
        isExport = false
        isAsync = false
        isGenerator = false
        funcNameRef = Ref.NONE
        funcNameLoc = Loc.EMPTY
        classNameRef = Ref.NONE
        classNameLoc = Loc.EMPTY
        blockStmts = ArrayList<Stmt>()
        closeBraceLoc = None
        valueExpr = None
        testExpr = None
        yesExpr = None
        noExpr = None
        updateExpr = None
        body = Stmt()
        hasNoBranch = false
        noStmt = Stmt()
        yesStmt = Stmt()
        hasTest = false
        hasInit = false
        hasUpdate = false
        initStmt = Stmt()
        isAwait = false
        hasImportStar = false
        importRecordIndex = 0
        namespaceRef = Ref.NONE
        defaultName = None
        clauseItems = ArrayList<ClauseItem>()
        isSingleLine = true
        starNameLoc = None
        decls = ArrayList<Decl>()
        localKind = LocalKind.Var
        labelRef = None
        innerStmt = Stmt()
        bodyLoc = Loc.EMPTY
        bodyStmts = ArrayList<Stmt>()
        hasCatch = false
        catchLoc = Loc.EMPTY
        hasCatchBinding = false
        catchBinding = Binding()
        catchBodyLoc = Loc.EMPTY
        catchBodyStmts = ArrayList<Stmt>()
        hasFinally = false
        finallyLoc = Loc.EMPTY
        finallyStmts = ArrayList<Stmt>()
        cases = ArrayList<SwitchCase>()
        commentText = ""
        directiveValue = ""
        innerStmtVal = None
    }
}

/// Switch case - 对应 Bun S.SwitchCase
public class SwitchCase {
    public var valueExpr: ?Expr
    public var body: ArrayList<Stmt>

    public init() {
        valueExpr = None
        body = ArrayList<Stmt>()
    }
}

/// Decl - 声明
public class Decl {
    public var binding: Binding
    public var value: ?Expr

    public init() {
        binding = Binding()
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
}
