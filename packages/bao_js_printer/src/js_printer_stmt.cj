// JavaScript 代码打印机 - 语句打印
// 严格翻译自: src/js_printer/js_printer.zig:1131-5261 (语句/块/绑定/属性打印)
//   printStmt 是语句打印的核心分发器
//   包括: printBody, printBlock, printBlockBody, printDecls, printStmt,
//         printFunc, printClass, printProperty, printBinding, printIf,
//         printForLoopInit, printDeclStmt, printBundledImport, printDevServerModule
package bao_js_printer

import bao_core.*
import bao_collections.*

/// 子句项类型
public enum ClauseItemAsKind {
    | Import
    | Export
    | ExportFrom
    | Var
}

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
    public func printBody(stmt: ?Stmt, tlmtlo: TopLevel): Unit {
        match (stmt) {
            case Some(stmtVal) => printBody(stmtVal, tlmtlo)
            case None => ()
        }
    }

    public func printBody(stmt: Stmt, tlmtlo: TopLevel): Unit {
        match (stmt.tag) {
            case StmtTag.SBlock => printBlockBodyStmt(stmt, tlmtlo)
            case _ => printIndentedBodyStmt(stmt, tlmtlo)
        }
    }

    private func printBlockBodyStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
        printSpace()
        printBlock(stmt.loc, stmt.blockStmts, None, tlmtlo)
        printNewline()
    }

    private func printIndentedBodyStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
        printNewline()
        indent()
        printStmt(stmt, tlmtlo)
        unindent()
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
        match (closeBraceLoc) {
            case Some(cbl) =>
                if (cbl.start > loc.start) {
                    addSourceMapping(cbl)
                }
            case None => ()
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
    public func printFunc(fnExpr: Expr): Unit {
        printFnArgs(fnExpr.loc, fnExpr.args, fnExpr.hasRestArg, false)
        printSpace()
        printBlock(fnExpr.bodyLoc, fnExpr.bodyStmts, None,
                    TopLevel.initTopLevel(IsTopLevel.No))
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

            printBinding(args[i].binding, TopLevel())

            match (args[i].defaultExpr) {
                case Some(defaultVal) =>
                    printWhitespacer(ws(" = "))
                    printExpr(defaultVal, OpLevel.Comma, ExprFlags.none())
                case None => ()
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
        match (expr.extendsExpr) {
            case Some(extendsExpr) =>
                print(" extends")
                printSpace()
                printExpr(extendsExpr, OpLevel.Primary, ExprFlags.none())
            case None => ()
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

            match (item.valueExprOpt) {
                case None => printSemicolonAfterStatement()
                case Some(_) => printNewline()
            }
        }

        needsSemicolon = false
        unindent()
        printIndent()
        print("}")
    }

    private func printPropertyMethodPrefix(item: Expr, val: Expr): Unit {
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

    // ========================================================================
    // printProperty - 打印属性
    // 严格翻译自: js_printer.zig:3324-3608
    // ========================================================================

    /// 打印属性 - 对应 printProperty()
    public func printProperty(item: Expr): Unit {
        // spread
        if (item.isSpread) {
            print("...")
            match (item.valueExprOpt) {
                case Some(val) => printExpr(val, OpLevel.Comma, ExprFlags.none())
                case None => ()
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
        match (item.valueExprOpt) {
            case Some(val) => printPropertyMethodPrefix(item, val)
            case None => ()
        }

        // key 为 null 的情况
        match (item.keyExpr) {
            case Some(key) =>
                if (printPropertyKey(item, key)) {
                    return
                }
            case None => ()
        }

        // 非普通属性 (get/set 方法)
        if (!item.isNormal && !item.isAutoAccessor && printNonNormalPropertyValue(item)) {
            return
        }

        // 值
        if (printPropertyValue(item)) {
            return
        }

        // 初始化器
        match (item.initializer) {
            case Some(initial) => printInitializer(initial)
            case None => ()
        }
    }

    private func printPropertyKey(item: Expr, key: Expr): Bool {
        if (item.isComputed) {
            print("[")
            printExpr(key, OpLevel.Comma, ExprFlags.none())
            print("]")
            match (item.valueExprOpt) {
                case Some(val) => printComputedPropertyValue(item, val)
                case None => ()
            }
            return true
        }
        if (key.tag == ExprTag.String) {
            addSourceMapping(key.loc)
            let keyStr = key.stringValue
            if (isIdentifierStr(keyStr)) {
                printSpaceBeforeIdentifier()
                printIdentifier(keyStr)
            } else {
                printStringLiteralUTF8(keyStr, false)
            }
        } else if (!isJson) {
            printExpr(key, OpLevel.Comma, ExprFlags.none())
        }
        return false
    }

    private func printComputedPropertyValue(item: Expr, val: Expr): Unit {
        if (val.tag == ExprTag.Function && item.isMethod) {
            printFunc(val)
            return
        }
        print(":")
        printSpace()
        printExpr(val, OpLevel.Comma, ExprFlags.none())
    }

    private func printNonNormalPropertyValue(item: Expr): Bool {
        match (item.valueExprOpt) {
            case Some(val) =>
                if (val.tag == ExprTag.Function) {
                    printFunc(val)
                    return true
                }
            case None => ()
        }
        return false
    }

    private func printPropertyValue(item: Expr): Bool {
        match (item.valueExprOpt) {
            case Some(val) =>
                if (val.tag == ExprTag.Function && item.isMethod) {
                    printFunc(val)
                    return true
                }
                print(":")
                printSpace()
                printExpr(val, OpLevel.Comma, ExprFlags.none())
            case None => ()
        }
        return false
    }

    // ========================================================================
    // printBinding - 打印绑定
    // 严格翻译自: js_printer.zig:3617-3796
    // ========================================================================

    private func printIdentifierBinding(binding: Binding): Unit {
        printSpaceBeforeIdentifier()
        addSourceMapping(binding.loc)
        printSymbol(binding.ref)
    }

    /// 打印绑定 - 对应 printBinding()
    public func printBinding(binding: Binding, tlm: TopLevel): Unit {
        match (binding.tag) {
            case BindingTag.BMissing => ()
            case BindingTag.BIdentifier => printIdentifierBinding(binding)
            case BindingTag.BArray => printArrayBinding(binding, tlm)
            case BindingTag.BObject => printObjectBinding(binding, tlm)
        }
    }

    private func printArrayBinding(binding: Binding, tlm: TopLevel): Unit {
        print("[")
        let items = binding.arrayItems
        if (items.size > 0) {
            if (!binding.isSingleLine) {
                indent()
            }
            for (i in 0..items.size) {
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
                let isLast = i + 1 == items.size
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

    private func printObjectBinding(binding: Binding, tlm: TopLevel): Unit {
        print("{")
        let props = binding.objectProperties
        if (props.size > 0) {
            if (!binding.isSingleLine) {
                indent()
            }
            for (i in 0..props.size) {
                printObjectBindingPropertyPrefix(binding, i)
                let objectProp = props[i]
                if (!printObjectBindingProperty(objectProp, tlm)) {
                    printBinding(objectProp.value, tlm)
                }
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

    private func printObjectBindingPropertyPrefix(binding: Binding, i: Int64): Unit {
        if (i > 0) {
            print(",")
        }
        if (binding.isSingleLine) {
            printSpace()
        } else {
            printNewline()
            printIndent()
        }
    }

    private func printObjectBindingProperty(objectProp: BindingProperty, tlm: TopLevel): Bool {
        if (objectProp.flags.isSpread) {
            print("...")
            return false
        }
        if (objectProp.flags.isComputed) {
            print("[")
            match (objectProp.key) {
                case Some(key) => printExpr(key, OpLevel.Comma, ExprFlags.none())
                case None => ()
            }
            print("]:")
            printSpace()
            printBinding(objectProp.value, tlm)
            return true
        }
        match (objectProp.key) {
            case Some(key) => printObjectBindingKey(key)
            case None => ()
        }
        print(":")
        printSpace()
        return false
    }

    private func printObjectBindingKey(key: Expr): Unit {
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
        printDeclValue(decls[0], flags)

        for (i in 1..decls.size) {
            print(",")
            printSpace()
            printBinding(decls[i].binding, tlm)
            printDeclValue(decls[i], flags)
        }
    }

    private func printDeclValue(decl: Decl, flags: ExprFlags): Unit {
        match (decl.value) {
            case Some(value) =>
                printWhitespacer(ws(" = "))
                printExpr(value, OpLevel.Comma, flags)
            case None => ()
        }
    }

    // ========================================================================
    // printDeclStmt - 打印声明语句
    // 严格翻译自: js_printer.zig:5196-5261
    // ========================================================================

    /// 打印声明语句 - 对应 printDeclStmt(true)
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

    private func printCommentStmt(stmt: Stmt): Unit {
        printIndent()
        addSourceMapping(stmt.loc)
        printIndentedComment(stmt.commentText)
    }

    private func printFunctionStmt(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        if (stmt.isExport && !rewriteEsmToCjs) {
            print("export ")
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
        printFunc(Expr())
        printNewline()
        if (rewriteEsmToCjs && stmt.isExport) {
            printIndent()
            printBundledExport(localName, localName)
            printSemicolonAfterStatement()
        }
    }

    private func printClassStmt(stmt: Stmt, prevTag: StmtTag): Unit {
        if (prevTag != StmtTag.SEmpty) {
            printNewline()
        }
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        let nameRef = stmt.classNameRef
        if (stmt.isExport && !rewriteEsmToCjs) {
            print("export ")
        }
        print("class ")
        addSourceMapping(stmt.classNameLoc)
        let nameStr = renamer.nameForSymbol(nameRef)
        printIdentifier(nameStr)
        printClass(Expr())
        if (rewriteEsmToCjs && stmt.isExport) {
            printSemicolonAfterStatement()
            printIndent()
            printBundledExport(nameStr, nameStr)
            printSemicolonAfterStatement()
        } else {
            printNewline()
        }
    }

    private func printEmptyStmt(stmt: Stmt, prevTag: StmtTag): Unit {
        if (prevTag == StmtTag.SEmpty && options.indent.count == 0) {
            return
        }
        printIndent()
        addSourceMapping(stmt.loc)
        print(";")
        printNewline()
    }

    private func printExportStarStmt(stmt: Stmt, prevTag: StmtTag): Unit {
        if (!prevTag.isExportLike()) {
            printNewline()
        }
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        printWhitespacer(ws("export * from "))
        printImportRecordPath(importRecord(stmt.importRecordIndex))
        printSemicolonAfterStatement()
    }

    private func printExportDefaultStmt(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("export default ")
        exportDefaultStart = written
        match (stmt.valueExpr) {
            case Some(exprVal) =>
                printExpr(exprVal, OpLevel.Comma, ExprFlags.none())
                printSemicolonAfterStatement()
            case None =>
                match (stmt.innerStmtVal) {
                    case Some(stmtVal) => printStmt(stmtVal, TopLevel())
                    case None => ()
                }
        }
    }

    private func printExportClauseStmt(stmt: Stmt, prevTag: StmtTag): Unit {
        if (rewriteEsmToCjs) {
            printExportClauseCjs(stmt)
            return
        }
        if (!prevTag.isExportLike()) {
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
    }

    private func printExportFromStmt(stmt: Stmt): Unit {
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
    }

    private func printLocalStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
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

    private func printIfStmt(stmt: Stmt): Unit {
        printIndent()
        printIf(stmt)
    }

    private func printDoWhileStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("do")
        let subVar = tlmtlo.subVar()
        match (stmt.body) {
            case Some(bodyStmt) =>
                match (bodyStmt.tag) {
                    case StmtTag.SBlock => printDoWhileBlockBody(bodyStmt, subVar)
                    case _ => printDoWhileStmtBody(bodyStmt, subVar)
                }
            case None => ()
        }
        print("while")
        printSpace()
        print("(")
        printExpr(stmt.testExpr, OpLevel.Comma, ExprFlags.none())
        print(")")
        printSemicolonAfterStatement()
    }

    private func printDoWhileBlockBody(stmt: Stmt, tlmtlo: TopLevel): Unit {
        printSpace()
        printBlock(stmt.loc, stmt.blockStmts, None, tlmtlo)
        printSpace()
    }

    private func printDoWhileStmtBody(stmt: Stmt, tlmtlo: TopLevel): Unit {
        printNewline()
        indent()
        printStmt(stmt, tlmtlo)
        printSemicolonIfNeeded()
        unindent()
        printIndent()
    }

    private func printForInStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
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

    private func printForOfStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
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

    private func printWhileStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
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

    private func printWithStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
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

    private func printLabelStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
        if (!options.minifyWhitespace && options.indent.count > 0) {
            printIndent()
        }
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        printSymbol(stmt.labelRef)
        print(":")
        printBody(stmt.innerStmt, tlmtlo.subVar())
    }

    private func printTryStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
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

    private func printForStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
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

    private func printSwitchStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
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
            printSwitchCaseHeader(c)

            let subVarCase = tlmtlo.subVar()
            if (printSingleBlockSwitchCase(c, subVarCase)) {
                continue
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

    private func printSwitchCaseHeader(c: Case): Unit {
        match (c.valueExpr) {
            case Some(val) =>
                print("case")
                printSpace()
                printExpr(val, OpLevel.LogicalAnd, ExprFlags.none())
            case None => print("default")
        }
        print(":")
    }

    private func printSingleBlockSwitchCase(c: Case, tlmtlo: TopLevel): Bool {
        if (c.body.size != 1) {
            return false
        }
        match (c.body[0].tag) {
            case StmtTag.SBlock =>
                printSpace()
                printBlock(c.body[0].loc, c.body[0].blockStmts, None, tlmtlo)
                printNewline()
                return true
            case _ => return false
        }
    }

    private func printBlockStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
        printIndent()
        printBlock(stmt.loc, stmt.blockStmts, stmt.closeBraceLoc, tlmtlo.subVar())
        printNewline()
    }

    private func printDebuggerStmt(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("debugger")
        printSemicolonAfterStatement()
    }

    private func printDirectiveStmt(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        printStringLiteralUTF8(stmt.directiveValue, false)
        printSemicolonAfterStatement()
    }

    private func printBreakStmt(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("break")
        printOptionalLabel(stmt.labelRef)
        printSemicolonAfterStatement()
    }

    private func printContinueStmt(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("continue")
        printOptionalLabel(stmt.labelRef)
        printSemicolonAfterStatement()
    }

    private func printOptionalLabel(labelRef: ?Ref): Unit {
        match (labelRef) {
            case Some(labelRefVal) =>
                print(" ")
                printSymbol(labelRefVal)
            case None => ()
        }
    }

    private func printReturnStmt(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("return")
        match (stmt.valueExpr) {
            case Some(value) =>
                printSpace()
                printExpr(value, OpLevel.Comma, ExprFlags.none())
            case None => ()
        }
        printSemicolonAfterStatement()
    }

    private func printThrowStmt(stmt: Stmt): Unit {
        printIndent()
        printSpaceBeforeIdentifier()
        addSourceMapping(stmt.loc)
        print("throw")
        printSpace()
        printExpr(stmt.valueExpr, OpLevel.Comma, ExprFlags.none())
        printSemicolonAfterStatement()
    }

    private func printExprStmt(stmt: Stmt): Unit {
        if (!options.minifyWhitespace && options.indent.count > 0) {
            printIndent()
        }
        stmtStart = written
        printExpr(stmt.valueExpr, OpLevel.Comma, ExprFlags.exprResultIsUnusedFlags())
        printSemicolonAfterStatement()
    }

    // ========================================================================
    // printStmt - 打印语句 (核心分发器)
    // 严格翻译自: js_printer.zig:3807-4821
    //   pub fn printStmt(p: *Printer, stmt: Stmt, tlmtlo: TopLevel) !void
    // ========================================================================

    /// 打印语句 - 对应 printStmt(true)
    public func printStmt(stmt: Stmt, tlmtlo: TopLevel): Unit {
        let previousStmtTag = prevStmtTag

        match (stmt.tag) {
            case StmtTag.SComment => printCommentStmt(stmt)
            case StmtTag.SFunction => printFunctionStmt(stmt)
            case StmtTag.SClass => printClassStmt(stmt, previousStmtTag)
            case StmtTag.SEmpty => printEmptyStmt(stmt, previousStmtTag)
            case StmtTag.SExportDefault => printExportDefaultStmt(stmt)
            case StmtTag.SExportStar => printExportStarStmt(stmt, previousStmtTag)
            case StmtTag.SExportClause => printExportClauseStmt(stmt, previousStmtTag)
            case StmtTag.SExportFrom => printExportFromStmt(stmt)
            case StmtTag.SLocal => printLocalStmt(stmt, tlmtlo)
            case StmtTag.SIf => printIfStmt(stmt)
            case StmtTag.SDoWhile => printDoWhileStmt(stmt, tlmtlo)
            case StmtTag.SForIn => printForInStmt(stmt, tlmtlo)
            case StmtTag.SForOf => printForOfStmt(stmt, tlmtlo)
            case StmtTag.SWhile => printWhileStmt(stmt, tlmtlo)
            case StmtTag.SWith => printWithStmt(stmt, tlmtlo)
            case StmtTag.SLabel => printLabelStmt(stmt, tlmtlo)
            case StmtTag.STry => printTryStmt(stmt, tlmtlo)
            case StmtTag.SFor => printForStmt(stmt, tlmtlo)
            case StmtTag.SSwitch => printSwitchStmt(stmt, tlmtlo)
            case StmtTag.SImport => printImportStmt(stmt)
            case StmtTag.SBlock => printBlockStmt(stmt, tlmtlo)
            case StmtTag.SDebugger => printDebuggerStmt(stmt)
            case StmtTag.SDirective => printDirectiveStmt(stmt)
            case StmtTag.SBreak => printBreakStmt(stmt)
            case StmtTag.SContinue => printContinueStmt(stmt)
            case StmtTag.SReturn => printReturnStmt(stmt)
            case StmtTag.SThrow => printThrowStmt(stmt)
            case StmtTag.SExpr => printExprStmt(stmt)
            case _ => ()
        }

        prevStmtTag = stmt.tag
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
        match (stmt.yesStmt) {
            case Some(yesStmt) =>
                match (yesStmt.tag) {
                    case StmtTag.SBlock => printIfYesBlock(stmt, yesStmt, tlmtlo)
                    case _ => printIfYesStmt(stmt, yesStmt, tlmtlo)
                }
            case None => ()
        }

        if (stmt.hasNoBranch) {
            match (stmt.noStmt) {
                case Some(noStmt) =>
                    printSemicolonIfNeeded()
                    printSpaceBeforeIdentifier()
                    addSourceMapping(noStmt.loc)
                    print("else")
                    printIfNoBranch(noStmt, tlmtlo)
                case None => ()
            }
        }
    }

    private func printIfYesBlock(stmt: Stmt, yesStmt: Stmt, tlmtlo: TopLevel): Unit {
        printSpace()
        printBlock(yesStmt.loc, yesStmt.blockStmts, None, tlmtlo)
        if (stmt.hasNoBranch) {
            printSpace()
        } else {
            printNewline()
        }
    }

    private func printIfYesStmt(stmt: Stmt, yesStmt: Stmt, tlmtlo: TopLevel): Unit {
        printNewline()
        indent()
        printStmt(yesStmt, tlmtlo)
        unindent()
        if (stmt.hasNoBranch) {
            printIndent()
        }
    }

    private func printIfNoBranch(noStmt: Stmt, tlmtlo: TopLevel): Unit {
        match (noStmt.tag) {
            case StmtTag.SBlock => printIfNoBlock(noStmt, tlmtlo)
            case StmtTag.SIf => printIf(noStmt)
            case _ => printIfNoStmt(noStmt, tlmtlo)
        }
    }

    private func printIfNoBlock(noStmt: Stmt, tlmtlo: TopLevel): Unit {
        printSpace()
        printBlock(noStmt.loc, noStmt.blockStmts, None, tlmtlo)
        printNewline()
    }

    private func printIfNoStmt(noStmt: Stmt, tlmtlo: TopLevel): Unit {
        printNewline()
        indent()
        printStmt(noStmt, tlmtlo)
        unindent()
    }

    // ========================================================================
    // printForLoopInit - 打印 for 循环初始化
    // 严格翻译自: js_printer.zig:5007-5041
    // ========================================================================

    /// 打印 for 循环初始化 - 对应 printForLoopInit()
    public func printForLoopInit(initStmt: ?Stmt): Unit {
        match (initStmt) {
            case Some(stmtVal) => printForLoopInit(stmtVal)
            case None => ()
        }
    }

    public func printForLoopInit(initStmt: Stmt): Unit {
        match (initStmt.tag) {
            case StmtTag.SExpr => printForLoopExprInit(initStmt)
            case StmtTag.SLocal => printForLoopLocalInit(initStmt)
            case StmtTag.SEmpty => ()
            case _ => ()
        }
    }

    private func printForLoopExprInit(initStmt: Stmt): Unit {
        printExpr(initStmt.valueExpr, OpLevel.Comma, ExprFlags(true, true, false, true))
    }

    private func printForLoopLocalInit(initStmt: Stmt): Unit {
        let keyword = match (initStmt.localKind) {
            case LocalKind.Var => "var"
            case LocalKind.Let => "let"
            case LocalKind.Const => "const"
            case LocalKind.Using => "using"
            case LocalKind.AwaitUsing => "await using"
        }
        printDecls(keyword, initStmt.decls, ExprFlags(true, true, false, false), TopLevel())
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

            let items = stmt.clauseItems
            let hasDefaultName = match (stmt.defaultName) {
                case Some(_) => true
                case None => false
            }
            if (items.size > 0 || hasDefaultName) {
                printIndent()
                printSpaceBeforeIdentifier()
                printWhitespacer(ws("var {"))

                match (stmt.defaultName) {
                    case Some(defaultName) =>
                        printSpace()
                        print("default:")
                        printSpace()
                        printSymbol(defaultName.ref)
                    case None => ()
                }

                if (items.size > 0) {
                    printSpace()
                    print(",")
                    printSpace()
                    for (i in 0..items.size) {
                        printClauseItemAs(items[i], ClauseItemAsKind.Var)
                        if (i < Int64(items.size) - 1) {
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

        match (stmt.defaultName) {
            case Some(name) =>
                print(" ")
                printSymbol(name.ref)
                itemCount += 1
            case None => ()
        }

        let items = stmt.clauseItems
        if (items.size > 0) {
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
            if (!options.minifyWhitespace || stmt.hasImportStar || items.size == 0) {
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
        let name = match (item.name.ref) {
            case Some(refVal) => renamer.nameForSymbol(refVal)
            case None => item.alias
        }

        match (asKind) {
            case ClauseItemAsKind.Import => printImportClauseItem(item, name)
            case ClauseItemAsKind.Var => printVarClauseItem(item, name)
            case ClauseItemAsKind.Export => printExportClauseItemAs(item, name)
            case ClauseItemAsKind.ExportFrom => printExportFromClauseItemAs(item, name)
        }
    }

    private func printImportClauseItem(item: ClauseItem, name: String): Unit {
        if (name == item.alias) {
            printIdentifier(name)
        } else {
            printClauseAlias(item.alias)
            print(" as ")
            addSourceMapping(item.aliasLoc)
            printIdentifier(name)
        }
    }

    private func printVarClauseItem(item: ClauseItem, name: String): Unit {
        printClauseAlias(item.alias)
        if (name != item.alias) {
            print(":")
            printSpace()
            printIdentifier(name)
        }
    }

    private func printExportClauseItemAs(item: ClauseItem, name: String): Unit {
        printIdentifier(name)
        if (name != item.alias) {
            print(" as ")
            addSourceMapping(item.aliasLoc)
            printClauseAlias(item.alias)
        }
    }

    private func printExportFromClauseItemAs(item: ClauseItem, name: String): Unit {
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
            let name = match (items[i].name.ref) {
                case Some(refVal) => renamer.nameForSymbol(refVal)
                case None => items[i].alias
            }
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
            return
        }

        let variant = ImportVariant.determine(record, sImport)

        match (variant) {
            case ImportVariant.PathOnly => printBundledPathOnlyImport(moduleId, isDisabled)
            case ImportVariant.ImportItemsAndDefault | ImportVariant.ImportDefault => printBundledDefaultImport(sImport, moduleId, isDisabled)
            case ImportVariant.ImportStarAndImportDefault => printBundledStarAndDefaultImport(sImport)
            case ImportVariant.ImportStar => printBundledStarImport(sImport)
            case _ => printBundledFallbackImport(sImport, moduleId)
        }
    }

    private func printBundledPathOnlyImport(moduleId: Int64, isDisabled: Bool): Unit {
        if (!isDisabled) {
            printCallModuleID(moduleId)
            printSemicolonAfterStatement()
        }
    }

    private func printBundledDefaultImport(sImport: SImport, moduleId: Int64, isDisabled: Bool): Unit {
        if (!isDisabled) {
            print("var $")
            printModuleId(moduleId)
            printEquals()
            printLoadFromBundle(sImport.importRecordIndex)
            printBundledDefaultName(sImport, moduleId)
        } else {
            printDisabledBundledDefaultName(sImport)
        }
        printSemicolonAfterStatement()
    }

    private func printBundledDefaultName(sImport: SImport, moduleId: Int64): Unit {
        match (sImport.defaultName) {
            case Some(defaultName) =>
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
            case None => ()
        }
    }

    private func printDisabledBundledDefaultName(sImport: SImport): Unit {
        match (sImport.defaultName) {
            case Some(defaultName) =>
                print("var ")
                printSymbol(defaultName.ref)
                printEquals()
                printDisabledImport()
            case None => ()
        }
    }

    private func printBundledStarAndDefaultImport(sImport: SImport): Unit {
        print("var ")
        printSymbol(sImport.namespaceRef)
        printEquals()
        printLoadFromBundle(sImport.importRecordIndex)
        printBundledStarDefaultName(sImport)
        printSemicolonAfterStatement()
    }

    private func printBundledStarDefaultName(sImport: SImport): Unit {
        match (sImport.defaultName) {
            case Some(defaultName) =>
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
            case None => ()
        }
    }

    private func printBundledStarImport(sImport: SImport): Unit {
        print("var ")
        printSymbol(sImport.namespaceRef)
        printEquals()
        printLoadFromBundle(sImport.importRecordIndex)
        printSemicolonAfterStatement()
    }

    private func printBundledFallbackImport(sImport: SImport, moduleId: Int64): Unit {
        print("var $")
        printModuleIdAssumeEnabled(moduleId)
        printEquals()
        printLoadFromBundle(sImport.importRecordIndex)
        printSemicolonAfterStatement()
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
    public var body: ?Stmt
    public var hasNoBranch: Bool
    public var noStmt: ?Stmt
    public var yesStmt: ?Stmt
    public var hasTest: Bool
    public var hasInit: Bool
    public var hasUpdate: Bool
    public var initStmt: ?Stmt
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
    public var innerStmt: ?Stmt

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
    public var cases: ArrayList<Case>

    // 注释
    public var commentText: String

    // 指令
    public var directiveValue: String

    // export default
    public var innerStmtVal: ?Stmt

    private init(empty: Bool) {
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
        body = None
        hasNoBranch = false
        noStmt = None
        yesStmt = None
        hasTest = false
        hasInit = false
        hasUpdate = false
        initStmt = None
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
        innerStmt = None
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
        cases = ArrayList<Case>()
        commentText = ""
        directiveValue = ""
        innerStmtVal = None
    }

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
        body = None
        hasNoBranch = false
        noStmt = None
        yesStmt = None
        hasTest = false
        hasInit = false
        hasUpdate = false
        initStmt = None
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
        innerStmt = None
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
        cases = ArrayList<Case>()
        commentText = ""
        directiveValue = ""
        innerStmtVal = None
    }
}

/// Switch case - 对应 Bun S.SwitchCase
public class Case {
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
