// 语句解析器
// 严格翻译自: src/js_parser/parse/parse_stmt.zig (1407 lines)
//   Bun 的语句解析器处理:
//   - parseStmt: 语句解析入口
//   - parseStmts: 语句列表解析
//   - t_semicolon / t_export / t_import / t_function / t_class / t_const / t_var / t_let
//   - t_if / t_for / t_while / t_do_while / t_switch / t_try / t_with
//   - t_return / t_throw / t_break / t_continue / t_debugger
//   - t_block / t_expr
//   - TypeScript declare / namespace / type / abstract / enum
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ParseStmt - 语句解析器
// 严格翻译自: src/js_parser/parse/parse_stmt.zig
//   pub fn ParseStmt(comptime ...) type { ... }
// ============================================================================

/// 语句解析器 - 对应 Bun ParseStmt 模块
/// 解析所有类型的 JavaScript/TypeScript 语句
public class ParseStmt {

    // ========================================================================
    // parseStmt - 语句解析入口
    // 严格翻译自: parse_stmt.zig
    //   根据 token 分派到对应的解析方法
    // ========================================================================

    /// 解析语句 - 对应 Bun parseStmt
    ///
    /// - p: 解析器实例
    /// - opts: 语句解析选项
    /// - 返回: 解析后的语句
    public static func parseStmt(p: Parser, opts: ParseStatementOptions): Stmt {
        match (p.lexer.token) {
            // 分号
            case Token.Semicolon =>
                p.lexer.next()
                let stmt = Stmt()
                stmt.tag = StmtTag.Empty
                stmt.loc = p.lexer.loc()
                return stmt

            // export
            case Token.Export =>
                return parseExport(p, opts, p.lexer.loc())

            // import
            case Token.Import =>
                return parseImport(p, opts, p.lexer.loc())

            // function / async function
            case Token.Function =>
                return ParseFn.parseFnStmt(p, p.lexer.loc(), opts, None)

            // class
            case Token.Class =>
                return parseClass(p, opts, p.lexer.loc())

            // const / let / var
            case Token.Const =>
                return parseVarDecl(p, opts, p.lexer.loc())
            case Token.Var =>
                return parseVarDecl(p, opts, p.lexer.loc())

            // if
            case Token.If =>
                return parseIf(p, p.lexer.loc())

            // for
            case Token.For =>
                return parseFor(p, p.lexer.loc())

            // while
            case Token.While =>
                return parseWhile(p, p.lexer.loc())

            // do-while
            case Token.Do =>
                return parseDoWhile(p, p.lexer.loc())

            // switch
            case Token.Switch =>
                return parseSwitch(p, p.lexer.loc())

            // try
            case Token.Try =>
                return parseTry(p, p.lexer.loc())

            // with
            case Token.With =>
                return parseWith(p, p.lexer.loc())

            // return
            case Token.Return =>
                return parseReturn(p, p.lexer.loc())

            // throw
            case Token.Throw =>
                return parseThrow(p, p.lexer.loc())

            // break
            case Token.Break =>
                return parseBreak(p, p.lexer.loc())

            // continue
            case Token.Continue =>
                return parseContinue(p, p.lexer.loc())

            // debugger
            case Token.Debugger =>
                p.lexer.next()
                p.lexer.expectOrInsertSemicolon()
                let stmt = Stmt()
                stmt.tag = StmtTag.Debugger
                stmt.loc = p.lexer.loc()
                return stmt

            // 块语句
            case Token.OpenBrace =>
                return parseBlock(p, p.lexer.loc())

            // TypeScript 关键字 (通过标识符)
            case Token.Identifier =>
                return parseIdentifierStmt(p, opts, p.lexer.loc())

            case _ =>
                // 表达式语句
                return parseExprStmt(p)
        }
    }

    // ========================================================================
    // parseStmts - 解析语句列表
    // ========================================================================

    /// 解析语句列表直到结束标记
    public static func parseStmts(p: Parser, endToken: Token, opts: ParseStatementOptions): ArrayList<Stmt> {
        let stmts = ArrayList<Stmt>()

        while (p.lexer.token != endToken && p.lexer.token != Token.EndOfFile) {
            let stmt = parseStmt(p, opts)
            stmts.append(stmt)
        }

        return stmts
    }

    // ========================================================================
    // export - 解析导出语句
    // 严格翻译自: parse_stmt.zig:18-...
    //   fn t_export(p, opts, loc) anyerror!Stmt
    // ========================================================================

    /// 解析导出语句 - 对应 Bun t_export
    private static func parseExport(p: Parser, opts: ParseStatementOptions, loc: Loc): Stmt {
        p.lexer.next() // export

        match (p.lexer.token) {
            // export class / const / function / var
            case Token.Class | Token.Const | Token.Function | Token.Var =>
                opts.isExport = true
                return parseStmt(p, opts)

            // export import (TypeScript)
            case Token.Import =>
                if (p.options.features.typescript) {
                    opts.isExport = true
                    return parseStmt(p, opts)
                }
                p.log.addError(MsgData("Unexpected \"import\" after \"export\""))
                let stmt = Stmt()
                stmt.tag = StmtTag.Empty
                return stmt

            // export enum (TypeScript)
            case Token.Enum =>
                if (!p.options.features.typescript) {
                    p.log.addError(MsgData("Unexpected \"enum\" after \"export\""))
                    let stmt = Stmt()
                    stmt.tag = StmtTag.Empty
                    return stmt
                }
                opts.isExport = true
                return parseStmt(p, opts)

            // export { ... }
            case Token.OpenBrace =>
                return ParseImportExport.parseExportClause(p, loc)

            // export * from '...'
            case Token.Asterisk =>
                return ParseImportExport.parseExportStar(p, loc)

            // export default
            case Token.Default =>
                return ParseImportExport.parseExportDefault(p, loc)

            // export async function
            case Token.Identifier =>
                if (p.lexer.isContextualKeyword("async")) {
                    let asyncRange = p.lexer.range()
                    p.lexer.next()
                    if (p.lexer.hasNewlineBefore) {
                        p.log.addError(MsgData("Unexpected newline after \"async\""))
                    }
                    p.lexer.expect(Token.Function)
                    opts.isExport = true
                    return ParseFn.parseFnStmt(p, loc, opts, Some(asyncRange))
                }

                // export let
                if (p.lexer.isContextualKeyword("let")) {
                    opts.isExport = true
                    return parseStmt(p, opts)
                }

                // export type (TypeScript)
                if (p.options.features.typescript) {
                    if (p.lexer.isContextualKeyword("type")) {
                        return parseTypeScriptTypeExport(p, opts, loc)
                    }
                    if (p.lexer.isContextualKeyword("declare")) {
                        return parseTypeScriptDeclareExport(p, opts, loc)
                    }
                    if (p.lexer.isContextualKeyword("abstract")) {
                        p.lexer.next()
                        p.lexer.expect(Token.Class)
                        opts.isExport = true
                        return parseClass(p, opts, loc)
                    }
                    if (p.lexer.isContextualKeyword("interface")) {
                        return parseTypeScriptInterfaceExport(p, opts, loc)
                    }
                    if (opts.isTypescriptDeclare && p.lexer.isContextualKeyword("as")) {
                        // export as namespace ns;
                        p.lexer.next()
                        p.lexer.expectContextualKeyword("namespace")
                        p.lexer.expect(Token.Identifier)
                        p.lexer.expectOrInsertSemicolon()
                        let stmt = Stmt()
                        stmt.tag = StmtTag.Type
                        stmt.loc = loc
                        return stmt
                    }
                }

                p.log.addError(MsgData("Unexpected token after \"export\""))
                let stmt = Stmt()
                stmt.tag = StmtTag.Empty
                return stmt

            case _ =>
                p.log.addError(MsgData("Unexpected token after \"export\""))
                let stmt = Stmt()
                stmt.tag = StmtTag.Empty
                return stmt
        }
    }

    // ========================================================================
    // import - 解析导入语句
    // ========================================================================

    /// 解析导入语句
    private static func parseImport(p: Parser, opts: ParseStatementOptions, loc: Loc): Stmt {
        if (opts.isModuleScope || opts.isNamespaceScope) {
            return ParseImportExport.parseImportStmt(p, loc)
        }

        // TypeScript: import x = require(...)
        if (p.options.features.typescript && p.lexer.token == Token.Identifier) {
            return parseTypeScriptImportEquals(p, loc)
        }

        p.log.addError(MsgData("Unexpected \"import\""))
        let stmt = Stmt()
        stmt.tag = StmtTag.Empty
        return stmt
    }

    // ========================================================================
    // var / let / const 声明
    // ========================================================================

    /// 解析变量声明 - 对应 Bun var/let/const 解析
    private static func parseVarDecl(p: Parser, opts: ParseStatementOptions, loc: Loc): Stmt {
        let kind: VarKind = match (p.lexer.token) {
            case Token.Const => VarKind.Const
            case Token.Var => VarKind.Var
            case Token.Let => VarKind.Let
            case _ => VarKind.Var
        }
        p.lexer.next()

        let decls = ArrayList<Decl>()
        var hasOut = false

        while (true) {
            let binding = parseBinding(p)
            var value: ?Expr = None

            if (p.lexer.token == Token.Equals) {
                p.lexer.next()
                value = Some(p.parseExpr(Level.Comma))
                hasOut = true
            }

            let decl = Decl()
            decl.binding = binding
            decl.value = value
            decls.append(decl)

            if (p.lexer.token != Token.Comma) {
                break
            }
            p.lexer.next()
        }

        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt()
        stmt.tag = StmtTag.Local
        stmt.loc = loc
        stmt.isExport = opts.isExport
        stmt.varKind = kind
        stmt.decls = decls
        return stmt
    }

    /// 解析绑定模式
    private static func parseBinding(p: Parser): BindingPattern {
        match (p.lexer.token) {
            case Token.Identifier =>
                let loc = p.lexer.loc()
                let name = p.lexer.identifier
                p.lexer.next()

                // TypeScript 类型注解
                if (p.options.features.typescript && p.lexer.token == Token.Colon) {
                    p.lexer.next()
                    ParseSkipTypeScript.skipTypeScriptType(p, Level.Lowest)
                }

                let binding = BindingPattern(loc, BindingPatternTag.Identifier)
                binding.name = name
                binding.ref = p.storeNameInRef(name)
                return binding
            case Token.OpenBrace =>
                return BindingPattern(p.lexer.loc(), BindingPatternTag.ObjectPattern)
            case Token.OpenBracket =>
                return BindingPattern(p.lexer.loc(), BindingPatternTag.ArrayPattern)
            case _ =>
                p.lexer.expect(Token.Identifier)
                return BindingPattern(p.lexer.loc(), BindingPatternTag.Missing)
        }
    }

    // ========================================================================
    // class - 解析类声明
    // ========================================================================

    /// 解析类声明
    private static func parseClass(p: Parser, opts: ParseStatementOptions, loc: Loc): Stmt {
        p.lexer.next() // class

        // TypeScript abstract
        if (p.options.features.typescript && p.lexer.isContextualKeyword("abstract")) {
            p.lexer.next()
        }

        // 类名
        var name: ?LocRef = None
        if (!opts.isNameOptional || p.lexer.token == Token.Identifier) {
            let nameLoc = p.lexer.loc()
            let nameText = p.lexer.identifier
            p.lexer.expect(Token.Identifier)
            let ref = p.newSymbol(SymbolKind.Other, nameText)
            name = Some(LocRef(nameLoc, ref))
        }

        // TypeScript 类型参数
        if (p.options.features.typescript && p.lexer.token == Token.LessThan) {
            ParseSkipTypeScript.skipTypeScriptTypeParameters(p, TypeParameterFlag.None)
        }

        // extends
        var `super`: ?Expr = None
        if (p.lexer.token == Token.Extends) {
            p.lexer.next()
            `super` = Some(p.parseExpr(Level.Lowest))
        }

        // implements (TypeScript)
        if (p.options.features.typescript && p.lexer.isContextualKeyword("implements")) {
            p.lexer.next()
            ParseSkipTypeScript.skipTypeScriptType(p, Level.Lowest)
            while (p.lexer.token == Token.Comma) {
                p.lexer.next()
                ParseSkipTypeScript.skipTypeScriptType(p, Level.Lowest)
            }
        }

        // 类体
        p.lexer.expect(Token.OpenBrace)
        let properties = ArrayList<GProperty>()

        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            // 解析类成员
            let propOpts = PropertyOpts()
            propOpts.isClass = true
            let property = ParseProperty.parseProperty(p, propOpts)
            properties.append(property)

            if (p.lexer.token == Token.Semicolon) {
                p.lexer.next()
            }
        }

        p.lexer.expect(Token.CloseBrace)

        let stmt = Stmt()
        stmt.tag = StmtTag.Class
        stmt.loc = loc
        stmt.isExport = opts.isExport
        stmt.className = name
        stmt.classSuper = `super`
        stmt.classProperties = properties
        return stmt
    }

    // ========================================================================
    // if / for / while / do-while / switch / try / with
    // ========================================================================

    /// 解析 if 语句
    private static func parseIf(p: Parser, loc: Loc): Stmt {
        p.lexer.next() // if
        p.lexer.expect(Token.OpenParen)
        let test = p.parseExpr(Level.Lowest)
        p.lexer.expect(Token.CloseParen)

        let yes = parseStmt(p, ParseStatementOptions())
        var no: ?Stmt = None

        if (p.lexer.token == Token.Else) {
            p.lexer.next()
            no = Some(parseStmt(p, ParseStatementOptions()))
        }

        let stmt = Stmt()
        stmt.tag = StmtTag.If
        stmt.loc = loc
        stmt.testExpr = test
        stmt.yesStmt = yes
        stmt.noStmt = no
        return stmt
    }

    /// 解析 for 语句
    private static func parseFor(p: Parser, loc: Loc): Stmt {
        p.lexer.next() // for

        // for await
        var isForAwait = false
        if (p.lexer.isContextualKeyword("await")) {
            isForAwait = true
            p.lexer.next()
        }

        p.lexer.expect(Token.OpenParen)

        // 确定是 for, for-in, 还是 for-of
        let init_ = p.parseExpr(Level.Lowest)

        if (p.lexer.token == Token.In) {
            // for (x in obj)
            p.lexer.next()
            let value = p.parseExpr(Level.Lowest)
            p.lexer.expect(Token.CloseParen)
            let body = parseStmt(p, ParseStatementOptions())

            let stmt = Stmt()
            stmt.tag = StmtTag.ForIn
            stmt.loc = loc
            stmt.initExpr = init_
            stmt.valueExpr = value
            stmt.bodyStmt = body
            return stmt
        }

        if (p.lexer.isContextualKeyword("of")) {
            // for (x of iterable)
            p.lexer.next()
            let value = p.parseExpr(Level.Lowest)
            p.lexer.expect(Token.CloseParen)
            let body = parseStmt(p, ParseStatementOptions())

            let stmt = Stmt()
            stmt.tag = StmtTag.ForOf
            stmt.loc = loc
            stmt.initExpr = init_
            stmt.valueExpr = value
            stmt.bodyStmt = body
            stmt.isForAwait = isForAwait
            return stmt
        }

        // for (init; test; update)
        p.lexer.expect(Token.Semicolon)
        let test = if (p.lexer.token != Token.Semicolon) {
            Some(p.parseExpr(Level.Lowest))
        } else { None }
        p.lexer.expect(Token.Semicolon)
        let update = if (p.lexer.token != Token.CloseParen) {
            Some(p.parseExpr(Level.Lowest))
        } else { None }
        p.lexer.expect(Token.CloseParen)
        let body = parseStmt(p, ParseStatementOptions())

        let stmt = Stmt()
        stmt.tag = StmtTag.For
        stmt.loc = loc
        stmt.initExpr = init_
        stmt.testExpr2 = test
        stmt.updateExpr = update
        stmt.bodyStmt = body
        return stmt
    }

    /// 解析 while 语句
    private static func parseWhile(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        p.lexer.expect(Token.OpenParen)
        let test = p.parseExpr(Level.Lowest)
        p.lexer.expect(Token.CloseParen)
        let body = parseStmt(p, ParseStatementOptions())

        let stmt = Stmt()
        stmt.tag = StmtTag.While
        stmt.loc = loc
        stmt.testExpr = test
        stmt.bodyStmt = body
        return stmt
    }

    /// 解析 do-while 语句
    private static func parseDoWhile(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        let body = parseStmt(p, ParseStatementOptions())
        p.lexer.expect(Token.While)
        p.lexer.expect(Token.OpenParen)
        let test = p.parseExpr(Level.Lowest)
        p.lexer.expect(Token.CloseParen)
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt()
        stmt.tag = StmtTag.DoWhile
        stmt.loc = loc
        stmt.testExpr = test
        stmt.bodyStmt = body
        return stmt
    }

    /// 解析 switch 语句
    private static func parseSwitch(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        p.lexer.expect(Token.OpenParen)
        let test = p.parseExpr(Level.Lowest)
        p.lexer.expect(Token.CloseParen)
        p.lexer.expect(Token.OpenBrace)

        let cases = ArrayList<SwitchCase>()
        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            let switchCase = SwitchCase()
            if (p.lexer.token == Token.Case) {
                p.lexer.next()
                switchCase.test = Some(p.parseExpr(Level.Comma))
                p.lexer.expect(Token.Colon)
            } else if (p.lexer.token == Token.Default) {
                p.lexer.next()
                p.lexer.expect(Token.Colon)
            }
            while (p.lexer.token != Token.Case && p.lexer.token != Token.Default &&
                   p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
                switchCase.stmts.append(parseStmt(p, ParseStatementOptions()))
            }
            cases.append(switchCase)
        }

        p.lexer.expect(Token.CloseBrace)

        let stmt = Stmt()
        stmt.tag = StmtTag.Switch
        stmt.loc = loc
        stmt.testExpr = test
        stmt.switchCases = cases
        return stmt
    }

    /// 解析 try 语句
    private static func parseTry(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        let body = parseBlock(p, p.lexer.loc())

        var catch_: ?Stmt = None
        var finally_: ?Stmt = None

        if (p.lexer.token == Token.Catch) {
            p.lexer.next()
            var catchBinding: ?BindingPattern = None
            if (p.lexer.token == Token.OpenParen) {
                p.lexer.next()
                catchBinding = Some(parseBinding(p))
                p.lexer.expect(Token.CloseParen)
            }
            catch_ = Some(parseBlock(p, p.lexer.loc()))
        }

        if (p.lexer.token == Token.Finally) {
            p.lexer.next()
            finally_ = Some(parseBlock(p, p.lexer.loc()))
        }

        let stmt = Stmt()
        stmt.tag = StmtTag.Try
        stmt.loc = loc
        stmt.bodyStmt = body
        stmt.catchStmt = catch_
        stmt.finallyStmt = finally_
        return stmt
    }

    /// 解析 with 语句
    private static func parseWith(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        p.lexer.expect(Token.OpenParen)
        let obj = p.parseExpr(Level.Lowest)
        p.lexer.expect(Token.CloseParen)
        let body = parseStmt(p, ParseStatementOptions())

        let stmt = Stmt()
        stmt.tag = StmtTag.With
        stmt.loc = loc
        stmt.valueExpr = obj
        stmt.bodyStmt = body
        return stmt
    }

    // ========================================================================
    // return / throw / break / continue
    // ========================================================================

    /// 解析 return 语句
    private static func parseReturn(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        var value: ?Expr = None
        if (!p.lexer.hasNewlineBefore && p.lexer.token != Token.Semicolon &&
            p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            value = Some(p.parseExpr(Level.Lowest))
        }
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt()
        stmt.tag = StmtTag.Return
        stmt.loc = loc
        stmt.returnExpr = value
        return stmt
    }

    /// 解析 throw 语句
    private static func parseThrow(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        if (p.lexer.hasNewlineBefore) {
            p.log.addError(MsgData("Unexpected newline after \"throw\""))
        }
        let value = p.parseExpr(Level.Lowest)
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt()
        stmt.tag = StmtTag.Throw
        stmt.loc = loc
        stmt.throwExpr = value
        return stmt
    }

    /// 解析 break 语句
    private static func parseBreak(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        var label: ?String = None
        if (!p.lexer.hasNewlineBefore && p.lexer.token == Token.Identifier) {
            label = Some(p.lexer.identifier)
            p.lexer.next()
        }
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt()
        stmt.tag = StmtTag.Break
        stmt.loc = loc
        stmt.label = label
        return stmt
    }

    /// 解析 continue 语句
    private static func parseContinue(p: Parser, loc: Loc): Stmt {
        p.lexer.next()
        var label: ?String = None
        if (!p.lexer.hasNewlineBefore && p.lexer.token == Token.Identifier) {
            label = Some(p.lexer.identifier)
            p.lexer.next()
        }
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt()
        stmt.tag = StmtTag.Continue
        stmt.loc = loc
        stmt.label = label
        return stmt
    }

    // ========================================================================
    // block / expr / identifier 语句
    // ========================================================================

    /// 解析块语句
    private static func parseBlock(p: Parser, loc: Loc): Stmt {
        p.lexer.expect(Token.OpenBrace)
        let stmts = parseStmts(p, Token.CloseBrace, ParseStatementOptions())
        p.lexer.expect(Token.CloseBrace)

        let stmt = Stmt()
        stmt.tag = StmtTag.Block
        stmt.loc = loc
        stmt.blockStmts = stmts
        return stmt
    }

    /// 解析表达式语句
    private static func parseExprStmt(p: Parser): Stmt {
        let expr = p.parseExpr(Level.Lowest)
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt()
        stmt.tag = StmtTag.Expr
        stmt.loc = expr.loc
        stmt.exprData = expr
        return stmt
    }

    /// 解析标识符开头的语句 (let, async, TypeScript 关键字等)
    private static func parseIdentifierStmt(p: Parser, opts: ParseStatementOptions, loc: Loc): Stmt {
        let name = p.lexer.identifier

        // let
        if (name == "let") {
            // 如果后面跟着标识符或解构，则作为变量声明
            p.lexer.next()
            if (p.lexer.token == Token.Identifier || p.lexer.token == Token.OpenBrace ||
                p.lexer.token == Token.OpenBracket) {
                let stmt = Stmt()
                stmt.tag = StmtTag.Local
                stmt.loc = loc
                stmt.isExport = opts.isExport
                stmt.varKind = VarKind.Let
                // 解析声明
                let decls = ArrayList<Decl>()
                while (true) {
                    let binding = parseBinding(p)
                    var value: ?Expr = None
                    if (p.lexer.token == Token.Equals) {
                        p.lexer.next()
                        value = Some(p.parseExpr(Level.Comma))
                    }
                    let decl = Decl()
                    decl.binding = binding
                    decl.value = value
                    decls.append(decl)
                    if (p.lexer.token != Token.Comma) { break }
                    p.lexer.next()
                }
                stmt.decls = decls
                p.lexer.expectOrInsertSemicolon()
                return stmt
            }
            // 否则作为表达式
            return parseExprStmtWithIdentifier(p, loc, name)
        }

        // async
        if (name == "async") {
            let asyncRange = p.lexer.range()
            p.lexer.next()
            if (p.lexer.token == Token.Function && !p.lexer.hasNewlineBefore) {
                return ParseFn.parseFnStmt(p, loc, opts, Some(asyncRange))
            }
            return parseExprStmtWithIdentifier(p, loc, name)
        }

        // TypeScript: type, interface, namespace, declare, abstract, enum
        if (p.options.features.typescript) {
            if (name == "type") {
                p.lexer.next()
                ParseSkipTypeScript.skipTypeScriptType(p, Level.Lowest)
                p.lexer.expectOrInsertSemicolon()
                let stmt = Stmt()
                stmt.tag = StmtTag.Type
                stmt.loc = loc
                return stmt
            }
            if (name == "interface") {
                return ParseSkipTypeScript.skipTypeScriptInterface(p, loc)
            }
            if (name == "namespace") {
                return ParseSkipTypeScript.skipTypeScriptNamespace(p, loc)
            }
            if (name == "declare") {
                p.lexer.next()
                opts.isTypescriptDeclare = true
                return parseStmt(p, opts)
            }
            if (name == "abstract") {
                p.lexer.next()
                if (p.lexer.token == Token.Class) {
                    return parseClass(p, opts, loc)
                }
                return parseExprStmtWithIdentifier(p, loc, name)
            }
            if (name == "enum") {
                return ParseSkipTypeScript.skipTypeScriptEnum(p, loc)
            }
        }

        // 默认: 表达式语句
        return parseExprStmtWithIdentifier(p, loc, name)
    }

    /// 解析以标识符开头的表达式语句
    private static func parseExprStmtWithIdentifier(p: Parser, loc: Loc, name: String): Stmt {
        // 标识符已在 token 中
        let expr = p.parseExpr(Level.Lowest)
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt()
        stmt.tag = StmtTag.Expr
        stmt.loc = loc
        stmt.exprData = expr
        return stmt
    }

    // ========================================================================
    // TypeScript 辅助方法
    // ========================================================================

    /// 解析 TypeScript type 导出
    private static func parseTypeScriptTypeExport(p: Parser, opts: ParseStatementOptions, loc: Loc): Stmt {
        p.lexer.next() // type
        p.lexer.expect(Token.Identifier) // type name
        // 跳过类型定义
        if (p.lexer.token == Token.Equals) {
            p.lexer.next()
            ParseSkipTypeScript.skipTypeScriptType(p, Level.Lowest)
        }
        p.lexer.expectOrInsertSemicolon()
        let stmt = Stmt()
        stmt.tag = StmtTag.Type
        stmt.loc = loc
        return stmt
    }

    /// 解析 TypeScript declare 导出
    private static func parseTypeScriptDeclareExport(p: Parser, opts: ParseStatementOptions, loc: Loc): Stmt {
        p.lexer.next() // declare
        opts.isTypescriptDeclare = true
        opts.isExport = true
        return parseStmt(p, opts)
    }

    /// 解析 TypeScript interface 导出
    private static func parseTypeScriptInterfaceExport(p: Parser, opts: ParseStatementOptions, loc: Loc): Stmt {
        return ParseSkipTypeScript.skipTypeScriptInterface(p, loc)
    }

    /// 解析 TypeScript import =
    private static func parseTypeScriptImportEquals(p: Parser, loc: Loc): Stmt {
        p.lexer.next() // identifier
        p.lexer.expect(Token.Equals)
        if (p.lexer.isContextualKeyword("require")) {
            p.lexer.next()
            p.lexer.expect(Token.OpenParen)
            p.lexer.expect(Token.StringLiteral)
            p.lexer.expect(Token.CloseParen)
        } else {
            p.lexer.expect(Token.Identifier)
            while (p.lexer.token == Token.Dot) {
                p.lexer.next()
                p.lexer.expect(Token.Identifier)
            }
        }
        p.lexer.expectOrInsertSemicolon()
        let stmt = Stmt()
        stmt.tag = StmtTag.Type
        stmt.loc = loc
        return stmt
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// VarKind - 变量声明种类
public enum VarKind {
    | Var
    | Let
    | Const
}

/// Decl - 声明 - 对应 Bun G.Decl
public class Decl {
    public var binding: BindingPattern
    public var value: ?Expr

    public init() {
        binding = BindingPattern(Loc.EMPTY, BindingPatternTag.Missing)
        value = None
    }
}

/// SwitchCase - switch case - 对应 Bun S.Case
public class SwitchCase {
    public var test: ?Expr
    public var stmts: ArrayList<Stmt>

    public init() {
        test = None
        stmts = ArrayList<Stmt>()
    }
}
