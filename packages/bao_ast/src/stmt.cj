// 严格翻译自: src/ast/stmt.zig (~423行)
// bao_ast - Stmt 联合类型: S.Block, S.If, S.For, S.Function, ...
// Stmt 是 JavaScript 语句的 AST 表示
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// Stmt - 语句 AST 节点
// 严格翻译自: src/ast/stmt.zig:1-423
// Bun: pub const Stmt = struct { loc: logger.Loc, data: Data }
// Data 是 S.Block | S.If | S.For | ... 的 tagged union
// ============================================================================

/// 语句 AST 节点 - 对应 Bun Stmt
/// Bun: pub const Stmt = struct { loc: logger.Loc, data: Data }
/// 仓颉中用 tag + 可选数据字段模拟 tagged union
public class Stmt {
    /// 语句标签
    public var tag: StmtTag
    /// 源码位置 - 对应 Bun loc: logger.Loc
    public var loc: ASTLoc

    // === 各语句类型的数据 ===

    /// S.Block - 块语句 {}
    public var blockData: ?SBlock
    /// S.SExpr - 表达式语句
    public var exprStmtData: ?SSExpr
    /// S.If - if 语句
    public var ifStmtData: ?SIf
    /// S.For - for 语句
    public var forStmt: ?SFor
    /// S.ForIn - for-in 语句
    public var forIn: ?SForIn
    /// S.ForOf - for-of 语句
    public var forOf: ?SForOf
    /// S.While - while 语句
    public var whileStmt: ?SWhile
    /// S.DoWhile - do-while 语句
    public var doWhile: ?SDoWhile
    /// S.Switch - switch 语句
    public var switchStmt: ?SSwitch
    /// S.Break - break 语句
    public var breakStmt: ?SBreak
    /// S.Continue - continue 语句
    public var continueStmt: ?SContinue
    /// S.Return - return 语句
    public var returnStmtData: ?SReturn
    /// S.Throw - throw 语句
    public var throwStmtData: ?SThrow
    /// S.Try - try 语句
    public var tryStmt: ?STry
    /// S.With - with 语句
    public var withStmt: ?SWith
    /// S.Function - 函数声明
    public var functionDecl: ?SFunction
    /// S.Class - 类声明
    public var classDecl: ?SClass
    /// S.Debugger - debugger 语句
    public var debuggerStmt: ?SDebugger
    /// S.Label - 标签语句
    public var label: ?SLabel
    /// S.Import - import 语句
    public var importStmt: ?SImport
    /// S.ExportClause - export { ... } 语句
    public var exportClause: ?SExportClause
    /// S.ExportDefault - export default 语句
    public var exportDefault: ?SExportDefault
    /// S.ExportStar - export * 语句
    public var exportStar: ?SExportStar
    /// S.ExportEquals - export = value (TypeScript)
    public var exportEquals: ?SExportEquals
    /// S.ExportFrom - export { ... } from '...' 语句
    public var exportFrom: ?SExportFrom
    /// S.Local - 变量声明 (var/let/const)
    public var localData: ?SLocal
    /// S.Directive - "use strict" 等指令
    public var directive: ?SDirective
    /// S.Namespace - TS namespace
    public var namespace: ?SNamespace
    /// S.Enum - TS enum
    public var enumDecl: ?SEnum
    /// S.Comment - 注释
    public var comment: ?SComment

    public init(tag: StmtTag, loc: ASTLoc) {
        this.tag = tag
        this.loc = loc
        this.blockData = None
        this.exprStmtData = None
        this.ifStmtData = None
        this.forStmt = None
        this.forIn = None
        this.forOf = None
        this.whileStmt = None
        this.doWhile = None
        this.switchStmt = None
        this.breakStmt = None
        this.continueStmt = None
        this.returnStmtData = None
        this.throwStmtData = None
        this.tryStmt = None
        this.withStmt = None
        this.functionDecl = None
        this.classDecl = None
        this.debuggerStmt = None
        this.label = None
        this.importStmt = None
        this.exportClause = None
        this.exportDefault = None
        this.exportStar = None
        this.exportEquals = None
        this.exportFrom = None
        this.localData = None
        this.directive = None
        this.namespace = None
        this.enumDecl = None
        this.comment = None
    }

    /// 是否为空语句 - 对应 Bun Stmt.empty()
    public func isEmpty(): Bool {
        return tag == StmtTag.Empty
    }

    /// 是否为 TypeScript 语句 - 对应 Bun Stmt.isTypeScript()
    public func isTypeScript(): Bool {
        return tag == StmtTag.TypeScript
    }

    /// 是否为导出类语句 - 对应 Bun Stmt.Tag.isExportLike()
    public func isExportLike(): Bool {
        match (tag) {
            case StmtTag.ExportClause | StmtTag.ExportDefault |
                 StmtTag.ExportEquals | StmtTag.ExportFrom |
                 StmtTag.ExportStar => true
            case _ => false
        }
    }

    /// 是否关注作用域 - 对应 Bun Stmt.caresAboutScope()
    public func caresAboutScope(): Bool {
        match (tag) {
            case StmtTag.Block | StmtTag.Empty | StmtTag.Expr |
                 StmtTag.If | StmtTag.For | StmtTag.ForIn |
                 StmtTag.ForOf | StmtTag.DoWhile | StmtTag.While |
                 StmtTag.With | StmtTag.Try | StmtTag.Switch |
                 StmtTag.Return | StmtTag.Throw | StmtTag.Break |
                 StmtTag.Continue | StmtTag.Directive => false
            case StmtTag.Local =>
                match (localData) {
                    case Some(l) => l.kind != LocalKind.Var
                    case None => false
                }
            case _ => true
        }
    }

    // === 静态工厂方法 ===

    /// 创建空语句 - 对应 Bun Stmt.empty()
    public static func empty(): Stmt {
        return Stmt(StmtTag.Empty, ASTLoc(0))
    }

    /// 创建块语句 - 对应 Bun Stmt(S.Block, ...)
    public static func block(stmts: ArrayList<StmtNode>, loc: ASTLoc): Stmt {
        let s = Stmt(StmtTag.Block, loc)
        s.blockData = SBlock(stmts)
        return s
    }

    /// 创建表达式语句 - 对应 Bun Stmt(S.SExpr, ...)
    public static func exprStmt(expr: ASTNode, loc: ASTLoc): Stmt {
        let s = Stmt(StmtTag.Expr, loc)
        s.exprStmtData = SSExpr(expr, false)
        return s
    }

    /// 创建 return 语句
    public static func returnStmt(value: ?ASTNode, loc: ASTLoc): Stmt {
        let s = Stmt(StmtTag.Return, loc)
        s.returnStmtData = SReturn(value)
        return s
    }

    /// 创建 if 语句
    public static func ifStmt(test: ASTNode, yes: StmtNode, no: ?StmtNode, loc: ASTLoc): Stmt {
        let s = Stmt(StmtTag.If, loc)
        s.ifStmtData = SIf(test, yes, no)
        return s
    }

    /// 创建 throw 语句
    public static func throwStmt(value: ASTNode, loc: ASTLoc): Stmt {
        let s = Stmt(StmtTag.Throw, loc)
        s.throwStmtData = SThrow(value)
        return s
    }

    /// 创建变量声明 - 对应 Bun Stmt(S.Local, ...)
    public static func local(kind: LocalKind, decls: ArrayList<GDecl>, isExport: Bool, loc: ASTLoc): Stmt {
        let s = Stmt(StmtTag.Local, loc)
        s.localData = SLocal(kind, decls, isExport)
        return s
    }
}
