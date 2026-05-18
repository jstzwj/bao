// 导入/导出语句解析器
// 严格翻译自: src/js_parser/parse/parse_import_export.zig (437 lines)
//   Bun 的导入/导出解析器处理:
//   - parseImportExpr: import() 表达式解析 (动态导入)
//   - parseImportClause: import { ... } 子句解析
//   - parseImportStmt: import 语句解析
//   - parseExportClause: export { ... } 子句解析
//   - parseExportFrom: export { ... } from '...' 解析
//   - parseExportStar: export * from '...' 解析
//   - parseExportDefault: export default 解析
//   - TypeScript type-only 导入/导出
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ParseImportExport - 导入/导出解析器扩展方法
// 严格翻译自: src/js_parser/parse/parse_import_export.zig
//   pub fn ParseImportExport(comptime ...) type { ... }
// ============================================================================

/// 导入/导出解析器 - 对应 Bun ParseImportExport 模块
/// 提供导入和导出语句的解析方法
public class ParseImportExport {

    // ========================================================================
    // parseImportExpr - 解析 import() 表达式
    // 严格翻译自: parse_import_export.zig:12-86
    //   pub fn parseImportExpr(p, loc, level) anyerror!Expr
    // ========================================================================

    /// 解析 import() 表达式 - 对应 Bun parseImportExpr
    /// 处理动态导入 import('...') 和 import.meta
    ///
    /// - p: 解析器实例
    /// - loc: import 关键字位置
    /// - level: 当前优先级
    public static func parseImportExpr(p: Parser, loc: Loc, level: Level): Expr {
        // 解析 import.meta 表达式
        if (p.lexer.token == Token.Dot) {
            p.lexer.nextToken()
            if (p.lexer.isContextualKeyword("meta")) {
                p.lexer.nextToken()
                p.hasImportMeta = true
                let result = Expr(loc, ExprTag.Identifier)
                result.identifierName = "import.meta"
                result.ref = p.moduleRef
                return result
            }
            p.log.addError(MsgData("Expected \"meta\""))
            return Expr.missing(loc)
        }

        let oldAllowIn = p.allowIn
        p.allowIn = true

        p.lexer.expect(Token.OpenParen)
        let value = p.parseExpr(ParseExprOpts())

        if (p.lexer.token == Token.Comma) {
            p.lexer.nextToken()
            if (p.lexer.token != Token.CloseParen) {
                p.parseExpr(ParseExprOpts())
                if (p.lexer.token == Token.Comma) {
                    p.lexer.nextToken()
                }
            }
        }

        p.lexer.expect(Token.CloseParen)
        p.allowIn = oldAllowIn

        return Expr.import_(loc, value)
    }

    // ========================================================================
    // parseImportStmt - 解析 import 语句
    // 严格翻译自: parse_import_export.zig 中的完整 import 语句处理
    //   import '...' / import x from '...' / import { ... } from '...'
    //   import * as x from '...'
    // ========================================================================

    /// 解析 import 语句 - 对应 Bun parseImportStmt
    /// 处理所有形式的 import 语句
    public static func parseImportStmt(p: Parser, loc: Loc): Stmt {
        // import '...' (副作用导入)
        if (p.lexer.token == Token.StringLiteral) {
            let path = p.lexer.stringLiteralRawContent
            let recordIndex = addImportRecord(p,ImportRecordKind.Stmt, loc, path)
            p.lexer.nextToken()
            p.lexer.expectOrInsertSemicolon()

            let stmt = Stmt.import_(loc, recordIndex)
            return stmt
        }

        var defaultName: ?LocRef = None
        var starNameLoc: ?Loc = None
        var namespaceRef: Ref = Ref.NONE
        var items = ArrayList<ClauseItem>()

        // import default
        // import x from '...'
        if (p.lexer.token == Token.Identifier || LexerTables.isReservedWord(p.lexer.token)) {
            let aliasLoc = p.lexer.loc()
            let alias = p.lexer.identifier
            p.lexer.nextToken()
            let ref = p.newSymbol(SymbolKind.Other,alias)
            defaultName = Some(LocRef(aliasLoc, ref))
        }

        // import * as ns from '...'
        if (p.lexer.token == Token.Asterisk) {
            p.lexer.nextToken()
            expectContextualKeyword(p, "as")
            let nameLoc = p.lexer.loc()
            let name = p.lexer.identifier
            p.lexer.expect(Token.Identifier)
            namespaceRef = p.newSymbol(SymbolKind.Other,name)
            starNameLoc = Some(nameLoc)
        } else if (p.lexer.token == Token.OpenBrace) {
            // import { ... } from '...'
            items = parseImportClause(p)
        }

        // 逗号分隔: import default, { ... } 或 import default, * as ns
        if (p.lexer.token == Token.Comma) {
            p.lexer.nextToken()
            if (p.lexer.token == Token.Asterisk) {
                p.lexer.nextToken()
                expectContextualKeyword(p, "as")
                let nameLoc = p.lexer.loc()
                let name = p.lexer.identifier
                p.lexer.expect(Token.Identifier)
                namespaceRef = p.newSymbol(SymbolKind.Other,name)
                starNameLoc = Some(nameLoc)
            } else if (p.lexer.token == Token.OpenBrace) {
                items = parseImportClause(p)
            }
        }

        // from '...'
        expectContextualKeyword(p, "from")

        if (p.lexer.token != Token.StringLiteral) {
            p.log.addError(MsgData("Expected string literal after \"from\""))
            return Stmt.empty(loc)
        }

        let path = p.lexer.stringLiteralRawContent
        let recordIndex = addImportRecord(p,ImportRecordKind.Static, loc, path)
        p.lexer.nextToken()
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt.import_(loc, recordIndex)
        stmt.starNameLoc = starNameLoc
        stmt.namespaceRef = namespaceRef
        stmt.importItems = items
        return stmt
    }

    // ========================================================================
    // parseImportClause - 解析 import { ... } 子句
    // 严格翻译自: parse_import_export.zig:88-...
    //   pub fn parseImportClause(p) !ImportClause
    // ========================================================================

    /// 解析导入子句 - 对应 Bun parseImportClause
    /// 解析 import { foo, bar as baz, type T } 中的花括号部分
    public static func parseImportClause(p: Parser): ArrayList<ClauseItem> {
        let items = ArrayList<ClauseItem>()
        p.lexer.expect(Token.OpenBrace)
        var hadTypeOnlyImports = false

        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            let aliasLoc = p.lexer.loc()
            let alias = parseClauseAlias(p, "import")
            var originalName = alias
            let nameRef = p.newSymbol(SymbolKind.Other,alias)
            p.lexer.nextToken()

            // TypeScript type-only 导入
            // import { type xx } from 'mod'
            var isTypeOnly = false
            if (p.options.features.typescript && alias == "type" &&
                p.lexer.token != Token.Comma && p.lexer.token != Token.CloseBrace) {
                isTypeOnly = true
                hadTypeOnlyImports = true

                // import { type xx as yy }
                if (p.lexer.isContextualKeyword("as")) {
                    p.lexer.nextToken()
                    originalName = p.lexer.identifier
                    p.lexer.expect(Token.Identifier)
                } else {
                    // import { type xx }
                    let typeName = p.lexer.identifier
                    p.lexer.nextToken()
                    if (p.lexer.isContextualKeyword("as")) {
                        p.lexer.nextToken()
                        originalName = p.lexer.identifier
                        p.lexer.expect(Token.Identifier)
                    }
                }
            } else {
                // import { foo as bar }
                if (p.lexer.isContextualKeyword("as")) {
                    p.lexer.nextToken()
                    originalName = p.lexer.identifier
                    p.lexer.expect(Token.Identifier)
                }
            }

            // 检查禁止的名称
            if (originalName == "eval" || originalName == "arguments") {
                p.log.addError(MsgData("Cannot use \"" + originalName + "\" as an identifier here"))
            }

            let item = ClauseItem()
            item.alias = alias
            item.aliasLoc = aliasLoc
            item.originalName = originalName
            item.nameRef = nameRef
            items.append(item)

            if (p.lexer.token == Token.Comma) {
                p.lexer.nextToken()
            } else {
                break
            }
        }

        p.lexer.expect(Token.CloseBrace)
        return items
    }

    // ========================================================================
    // parseExportClause - 解析 export { ... } 子句
    // ========================================================================

    /// 解析导出子句 - 对应 Bun export 子句解析
    /// 解析 export { foo, bar as baz } 部分
    public static func parseExportClause(p: Parser, loc: Loc): Stmt {
        let items = ArrayList<ClauseItem>()
        p.lexer.expect(Token.OpenBrace)

        while (p.lexer.token != Token.CloseBrace && p.lexer.token != Token.EndOfFile) {
            let aliasLoc = p.lexer.loc()
            var alias = parseClauseAlias(p, "export")
            var originalName = alias
            p.lexer.nextToken()

            // export { type xx }
            var isTypeOnly = false
            if (p.options.features.typescript && alias == "type" &&
                p.lexer.token != Token.Comma && p.lexer.token != Token.CloseBrace) {
                isTypeOnly = true
                if (p.lexer.isContextualKeyword("as")) {
                    p.lexer.nextToken()
                    originalName = p.lexer.identifier
                    p.lexer.expect(Token.Identifier)
                } else {
                    originalName = p.lexer.identifier
                    p.lexer.nextToken()
                    if (p.lexer.isContextualKeyword("as")) {
                        p.lexer.nextToken()
                        alias = p.lexer.identifier
                        p.lexer.expect(Token.Identifier)
                    }
                }
            } else {
                // export { foo as bar }
                if (p.lexer.isContextualKeyword("as")) {
                    p.lexer.nextToken()
                    originalName = p.lexer.identifier
                    p.lexer.expect(Token.Identifier)
                }
            }

            let item = ClauseItem()
            item.alias = alias
            item.aliasLoc = aliasLoc
            item.originalName = originalName
            items.append(item)

            if (p.lexer.token == Token.Comma) {
                p.lexer.nextToken()
            } else {
                break
            }
        }

        p.lexer.expect(Token.CloseBrace)

        // 检查是否有 from '...'
        if (p.lexer.isContextualKeyword("from")) {
            p.lexer.nextToken()
            if (p.lexer.token != Token.StringLiteral) {
                p.log.addError(MsgData("Expected string literal after \"from\""))
            } else {
                let path = p.lexer.stringLiteralRawContent
                let recordIndex = addImportRecord(p,ImportRecordKind.Static, loc, path)
                p.lexer.nextToken()

                let stmt = Stmt(loc, StmtTag.ExportFrom)
                stmt.importRecordIndex = recordIndex
                stmt.clauseItems = items
                p.lexer.expectOrInsertSemicolon()
                return stmt
            }
        }

        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt(loc, StmtTag.Export)
        stmt.clauseItems = items
        return stmt
    }

    // ========================================================================
    // parseExportStar - 解析 export * from '...'
    // ========================================================================

    /// 解析 export * 语句 - 对应 Bun export star 解析
    public static func parseExportStar(p: Parser, loc: Loc): Stmt {
        p.lexer.nextToken() // *

        // export * as ns from '...'
        var alias: ?String = None
        var aliasLoc: ?Loc = None
        if (p.lexer.isContextualKeyword("as")) {
            p.lexer.nextToken()
            aliasLoc = Some(p.lexer.loc())
            alias = Some(p.lexer.identifier)
            p.lexer.expect(Token.Identifier)
        }

        expectContextualKeyword(p, "from")

        if (p.lexer.token != Token.StringLiteral) {
            p.log.addError(MsgData("Expected string literal after \"from\""))
            return Stmt.empty(loc)
        }

        let path = p.lexer.stringLiteralRawContent
        let recordIndex = addImportRecord(p,ImportRecordKind.Static, loc, path)
        p.lexer.nextToken()
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt(loc, StmtTag.ExportStar)
        stmt.importRecordIndex = recordIndex
        stmt.starNameLoc = aliasLoc
        return stmt
    }

    // ========================================================================
    // parseExportDefault - 解析 export default
    // ========================================================================

    /// 解析 export default 语句
    public static func parseExportDefault(p: Parser, loc: Loc): Stmt {
        p.lexer.nextToken() // default

        // export default 后面可以是:
        // - function / async function / class
        // - 表达式

        let defaultLoc = p.lexer.loc()

        if (p.lexer.token == Token.Function) {
            p.lexer.nextToken()
            let opts = ParseStatementOptions()
            opts.isNameOptional = true
            opts.isExport = true
            return p.parseStmt(StmtOpts())
        }

        if (p.lexer.token == Token.Class) {
            p.lexer.nextToken()
            let opts = ParseStatementOptions()
            opts.isNameOptional = true
            opts.isExport = true
            return p.parseStmt(StmtOpts())
        }

        if (p.lexer.isContextualKeyword("async")) {
            let asyncRange = p.lexer.range()
            p.lexer.nextToken()
            if (p.lexer.token == Token.Function && !p.lexer.hasNewlineBefore) {
                p.lexer.nextToken()
                let opts = ParseStatementOptions()
                opts.isNameOptional = true
                opts.isExport = true
                return p.parseStmt(StmtOpts())
            }
        }

        // 表达式
        let value = p.parseExpr(ParseExprOpts())
        p.lexer.expectOrInsertSemicolon()

        let stmt = Stmt(loc, StmtTag.ExportDefault)
        stmt.expr = Some(value)
        return stmt
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    private static func addImportRecord(p: Parser, kind: ImportRecordKind, loc: Loc, path: String): Int64 {
        p.importRecords.append(ImportRecord(path, kind, Range(loc, 0)))
        return Int64(p.importRecords.size - 1)
    }

    private static func expectContextualKeyword(p: Parser, keyword: String): Unit {
        if (p.lexer.isContextualKeyword(keyword)) {
            p.lexer.nextToken()
        } else {
            p.log.addError(MsgData("Expected \"" + keyword + "\""))
        }
    }

    /// 解析子句别名 - 对应 Bun parseClauseAlias
    private static func parseClauseAlias(p: Parser, keyword: String): String {
        match (p.lexer.token) {
            case Token.Identifier =>
                return p.lexer.identifier
            case Token.StringLiteral =>
                return p.lexer.stringLiteralRawContent
            case _ =>
                if (LexerTables.isReservedWord(p.lexer.token)) {
                    return tokenToIdentifierString(p.lexer.token)
                }
                p.log.addError(MsgData("Expected identifier"))
                return ""
        }
    }

    /// 将 Token 转换为标识符字符串
    private static func tokenToIdentifierString(token: Token): String {
        let str = LexerTables.tokenToString(token)
        return str
    }
}

/// UInt32_MAX - UInt32 最大值
public let UInt32_MAX: UInt32 = 4294967295
