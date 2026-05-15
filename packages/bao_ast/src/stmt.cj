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
    public var loc: Loc

    // === 各语句类型的数据 ===

    /// S.Block - 块语句 {}
    public var block: ?SBlock
    /// S.SExpr - 表达式语句
    public var exprStmt: ?SExprStmt
    /// S.If - if 语句
    public var ifStmt: ?SIf
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
    public var returnStmt: ?SReturn
    /// S.Throw - throw 语句
    public var throwStmt: ?SThrow
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
    public var local: ?SLocal
    /// S.Directive - "use strict" 等指令
    public var directive: ?SDirective
    /// S.Namespace - TS namespace
    public var namespace: ?SNamespace
    /// S.Enum - TS enum
    public var enumDecl: ?SEnum
    /// S.Comment - 注释
    public var comment: ?SComment

    public init(tag: StmtTag, loc: Loc) {
        this.tag = tag
        this.loc = loc
        this.block = None
        this.exprStmt = None
        this.ifStmt = None
        this.forStmt = None
        this.forIn = None
        this.forOf = None
        this.whileStmt = None
        this.doWhile = None
        this.switchStmt = None
        this.breakStmt = None
        this.continueStmt = None
        this.returnStmt = None
        this.throwStmt = None
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
        this.local = None
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
            case StmtTag.Local => {
                match (local) {
                    case Some(l) => l.kind != LocalKind.Var
                    case None => false
                }
            }
            case _ => true
        }
    }

    // === 静态工厂方法 ===

    /// 创建空语句 - 对应 Bun Stmt.empty()
    public static func empty(): Stmt {
        return Stmt(StmtTag.Empty, Loc(0))
    }

    /// 创建块语句 - 对应 Bun Stmt.init(S.Block, ...)
    public static func block(stmts: ArrayList<Stmt>, loc: Loc): Stmt {
        let s = Stmt(StmtTag.Block, loc)
        s.block = SBlock(stmts)
        return s
    }

    /// 创建表达式语句 - 对应 Bun Stmt.init(S.SExpr, ...)
    public static func exprStmt(expr: ASTNode, loc: Loc): Stmt {
        let s = Stmt(StmtTag.Expr, loc)
        s.exprStmt = SExprStmt(expr, false)
        return s
    }

    /// 创建 return 语句
    public static func returnStmt(value: ?ASTNode, loc: Loc): Stmt {
        let s = Stmt(StmtTag.Return, loc)
        s.returnStmt = SReturn(value)
        return s
    }

    /// 创建 if 语句
    public static func ifStmt(test: ASTNode, yes: Stmt, no: ?Stmt, loc: Loc): Stmt {
        let s = Stmt(StmtTag.If, loc)
        s.ifStmt = SIf(test, yes, no)
        return s
    }

    /// 创建 throw 语句
    public static func throwStmt(value: ASTNode, loc: Loc): Stmt {
        let s = Stmt(StmtTag.Throw, loc)
        s.throwStmt = SThrow(value)
        return s
    }

    /// 创建变量声明 - 对应 Bun Stmt.init(S.Local, ...)
    public static func local(kind: LocalKind, decls: ArrayList<Decl>, isExport: Bool, loc: Loc): Stmt {
        let s = Stmt(StmtTag.Local, loc)
        s.local = SLocal(kind, decls, isExport)
        return s
    }
}

// ============================================================================
// S 类型 - 各语句数据结构
// 严格翻译自: src/ast/s.zig (~237行)
// Bun: pub const S = struct { Block, SExpr, If, For, ... }
// ============================================================================

/// S.Block - 块语句 {}
/// Bun: pub const Block = struct { stmts: StmtNodeList, close_brace_loc: logger.Loc }
public class SBlock {
    public var stmts: ArrayList<Stmt>
    public var closeBraceLoc: Loc

    public init(stmts: ArrayList<Stmt>) {
        this.stmts = stmts
        this.closeBraceLoc = Loc(0)
    }
}

/// S.SExpr - 表达式语句
/// Bun: pub const SExpr = struct { value: Expr, does_not_affect_tree_shaking: bool }
public class SExprStmt {
    public var value: ASTNode
    /// 不影响 tree shaking (如运行时辅助函数调用)
    public var doesNotAffectTreeShaking: Bool

    public init(value: ASTNode, doesNotAffectTreeShaking: Bool) {
        this.value = value
        this.doesNotAffectTreeShaking = doesNotAffectTreeShaking
    }
}

/// S.Comment - 注释
/// Bun: pub const Comment = struct { text: string }
public class SComment {
    public var text: String

    public init(text: String) {
        this.text = text
    }
}

/// S.Directive - 指令 ("use strict")
/// Bun: pub const Directive = struct { value: []const u8 }
public class SDirective {
    public var value: String

    public init(value: String) {
        this.value = value
    }
}

/// S.If - if 语句
/// Bun: pub const If = struct { test_, yes, no }
public class SIf {
    public var test: ASTNode
    public var yes: Stmt
    public var no: ?Stmt

    public init(test: ASTNode, yes: Stmt, no: ?Stmt) {
        this.test = test
        this.yes = yes
        this.no = no
    }
}

/// S.For - for 语句
/// Bun: pub const For = struct { init, test_, update, body }
public class SFor {
    public var init: ?Stmt
    public var test: ?ASTNode
    public var update: ?ASTNode
    public var body: Stmt

    public init(init: ?Stmt, test: ?ASTNode, update: ?ASTNode, body: Stmt) {
        this.init = init
        this.test = test
        this.update = update
        this.body = body
    }
}

/// S.ForIn - for-in 语句
/// Bun: pub const ForIn = struct { init, value, body }
public class SForIn {
    public var init: Stmt
    public var value: ASTNode
    public var body: Stmt

    public init(init: Stmt, value: ASTNode, body: Stmt) {
        this.init = init
        this.value = value
        this.body = body
    }
}

/// S.ForOf - for-of 语句
/// Bun: pub const ForOf = struct { is_await, init, value, body }
public class SForOf {
    public var isAwait: Bool
    public var init: Stmt
    public var value: ASTNode
    public var body: Stmt

    public init(isAwait: Bool, init: Stmt, value: ASTNode, body: Stmt) {
        this.isAwait = isAwait
        this.init = init
        this.value = value
        this.body = body
    }
}

/// S.While - while 语句
/// Bun: pub const While = struct { test_, body }
public class SWhile {
    public var test: ASTNode
    public var body: Stmt

    public init(test: ASTNode, body: Stmt) {
        this.test = test
        this.body = body
    }
}

/// S.DoWhile - do-while 语句
/// Bun: pub const DoWhile = struct { body, test_ }
public class SDoWhile {
    public var body: Stmt
    public var test: ASTNode

    public init(body: Stmt, test: ASTNode) {
        this.body = body
        this.test = test
    }
}

/// S.Switch - switch 语句
/// Bun: pub const Switch = struct { test_, body_loc, cases }
public class SSwitch {
    public var test: ASTNode
    public var bodyLoc: Loc
    public var cases: ArrayList<SCase>

    public init(test: ASTNode, bodyLoc: Loc, cases: ArrayList<SCase>) {
        this.test = test
        this.bodyLoc = bodyLoc
        this.cases = cases
    }
}

/// Switch Case - 对应 Bun Case
public class SCase {
    public var test: ?ASTNode
    public var body: ArrayList<Stmt>
    public var loc: Loc

    public init(test: ?ASTNode, body: ArrayList<Stmt>, loc: Loc) {
        this.test = test
        this.body = body
        this.loc = loc
    }
}

/// S.Break - break 语句
/// Bun: pub const Break = struct { label: ?LocRef }
public class SBreak {
    public var label: ?LocRef

    public init(label: ?LocRef) {
        this.label = label
    }
}

/// S.Continue - continue 语句
/// Bun: pub const Continue = struct { label: ?LocRef }
public class SContinue {
    public var label: ?LocRef

    public init(label: ?LocRef) {
        this.label = label
    }
}

/// S.Return - return 语句
/// Bun: pub const Return = struct { value: ?Expr }
public class SReturn {
    public var value: ?ASTNode

    public init(value: ?ASTNode) {
        this.value = value
    }
}

/// S.Throw - throw 语句
/// Bun: pub const Throw = struct { value: Expr }
public class SThrow {
    public var value: ASTNode

    public init(value: ASTNode) {
        this.value = value
    }
}

/// S.Try - try 语句
/// Bun: pub const Try = struct { body_loc, body, catch_, finally }
public class STry {
    public var bodyLoc: Loc
    public var body: ArrayList<Stmt>
    public var catchBody: ?SCatch
    public var finallyBody: ?SFinally

    public init(bodyLoc: Loc, body: ArrayList<Stmt>,
                catchBody: ?SCatch, finallyBody: ?SFinally) {
        this.bodyLoc = bodyLoc
        this.body = body
        this.catchBody = catchBody
        this.finallyBody = finallyBody
    }
}

/// Catch 子句 - 对应 Bun Catch
public class SCatch {
    public var binding: ?Binding
    public var bodyLoc: Loc
    public var body: ArrayList<Stmt>

    public init(binding: ?Binding, bodyLoc: Loc, body: ArrayList<Stmt>) {
        this.binding = binding
        this.bodyLoc = bodyLoc
        this.body = body
    }
}

/// Finally 子句 - 对应 Bun Finally
public class SFinally {
    public var bodyLoc: Loc
    public var body: ArrayList<Stmt>

    public init(bodyLoc: Loc, body: ArrayList<Stmt>) {
        this.bodyLoc = bodyLoc
        this.body = body
    }
}

/// S.With - with 语句
/// Bun: pub const With = struct { value, body, body_loc }
public class SWith {
    public var value: ASTNode
    public var body: Stmt
    public var bodyLoc: Loc

    public init(value: ASTNode, body: Stmt, bodyLoc: Loc) {
        this.value = value
        this.body = body
        this.bodyLoc = bodyLoc
    }
}

/// S.Function - 函数声明
/// Bun: pub const Function = struct { func: G.Fn }
public class SFunction {
    public var func: GFn

    public init(func: GFn) {
        this.func = func
    }
}

/// S.Class - 类声明
/// Bun: pub const Class = struct { class: G.Class, is_export: bool }
public class SClass {
    public var classDef: GClass
    public var isExport: Bool

    public init(classDef: GClass, isExport: Bool) {
        this.classDef = classDef
        this.isExport = isExport
    }
}

/// S.Debugger - debugger 语句
/// Bun: pub const Debugger = struct {}
public class SDebugger {
    public init() {}
}

/// S.Label - 标签语句
/// Bun: pub const Label = struct { name: LocRef, stmt }
public class SLabel {
    public var name: LocRef
    public var stmt: Stmt

    public init(name: LocRef, stmt: Stmt) {
        this.name = name
        this.stmt = stmt
    }
}

/// S.Import - import 语句
/// Bun: pub const Import = struct { namespace_ref, default_name, items, ... }
public class SImport {
    public var namespaceRef: Ref
    public var defaultName: ?LocRef
    public var items: ArrayList<ClauseItem>
    public var starNameLoc: ?Loc
    public var importRecordIndex: UInt32
    public var isSingleLine: Bool

    public init(namespaceRef: Ref, importRecordIndex: UInt32) {
        this.namespaceRef = namespaceRef
        this.defaultName = None
        this.items = ArrayList<ClauseItem>()
        this.starNameLoc = None
        this.importRecordIndex = importRecordIndex
        this.isSingleLine = false
    }
}

/// 导入/导出子句项 - 对应 Bun ClauseItem
/// Bun: pub const ClauseItem = struct { alias, alias_loc, name, name_loc, ... }
public class ClauseItem {
    public var alias: String
    public var aliasLoc: Loc
    public var name: String
    public var nameLoc: Loc
    public var nameRef: Ref

    public init(alias: String, aliasLoc: Loc, name: String,
                nameLoc: Loc, nameRef: Ref) {
        this.alias = alias
        this.aliasLoc = aliasLoc
        this.name = name
        this.nameLoc = nameLoc
        this.nameRef = nameRef
    }
}

/// S.ExportClause - export { ... } 语句
/// Bun: pub const ExportClause = struct { items, is_single_line }
public class SExportClause {
    public var items: ArrayList<ClauseItem>
    public var isSingleLine: Bool

    public init(items: ArrayList<ClauseItem>, isSingleLine: Bool) {
        this.items = items
        this.isSingleLine = isSingleLine
    }
}

/// S.ExportDefault - export default 语句
/// Bun: pub const ExportDefault = struct { default_name, value }
public class SExportDefault {
    public var defaultName: LocRef
    /// 可以是表达式或语句
    public var value: Stmt

    public init(defaultName: LocRef, value: Stmt) {
        this.defaultName = defaultName
        this.value = value
    }
}

/// S.ExportStar - export * 语句
/// Bun: pub const ExportStar = struct { namespace_ref, alias, import_record_index }
public class SExportStar {
    public var namespaceRef: Ref
    public var alias: ?ExportStarAlias
    public var importRecordIndex: UInt32

    public init(namespaceRef: Ref, importRecordIndex: UInt32) {
        this.namespaceRef = namespaceRef
        this.alias = None
        this.importRecordIndex = importRecordIndex
    }
}

/// Export * 别名 - 对应 Bun G.ExportStarAlias
public class ExportStarAlias {
    public var alias: String
    public var loc: Loc

    public init(alias: String, loc: Loc) {
        this.alias = alias
        this.loc = loc
    }
}

/// S.ExportEquals - export = (TypeScript)
/// Bun: pub const ExportEquals = struct { value: Expr }
public class SExportEquals {
    public var value: ASTNode

    public init(value: ASTNode) {
        this.value = value
    }
}

/// S.ExportFrom - export { ... } from '...'
/// Bun: pub const ExportFrom = struct { items, namespace_ref, import_record_index, is_single_line }
public class SExportFrom {
    public var items: ArrayList<ClauseItem>
    public var namespaceRef: Ref
    public var importRecordIndex: UInt32
    public var isSingleLine: Bool

    public init(items: ArrayList<ClauseItem>, namespaceRef: Ref,
                importRecordIndex: UInt32, isSingleLine: Bool) {
        this.items = items
        this.namespaceRef = namespaceRef
        this.importRecordIndex = importRecordIndex
        this.isSingleLine = isSingleLine
    }
}

/// 变量声明类型 - 对应 Bun S.Local.Kind
/// Bun: pub const Kind = enum { k_var, k_let, k_const, k_using, k_await_using }
public enum LocalKind {
    | Var         // k_var
    | Let         // k_let
    | Const       // k_const
    | Using       // k_using
    | AwaitUsing  // k_await_using

    /// 是否可重新赋值
    public func isReassignable(): Bool {
        match (this) {
            case Var | Let => true
            case _ => false
        }
    }

    /// 是否为 using 声明
    public func isUsing(): Bool {
        match (this) {
            case Using | AwaitUsing => true
            case _ => false
        }
    }
}

/// S.Local - 变量声明
/// Bun: pub const Local = struct { kind, decls, is_export, was_ts_import_equals }
public class SLocal {
    public var kind: LocalKind
    public var decls: ArrayList<Decl>
    public var isExport: Bool
    public var wasTsImportEquals: Bool
    public var wasCommonjsExport: Bool

    public init(kind: LocalKind, decls: ArrayList<Decl>, isExport: Bool) {
        this.kind = kind
        this.decls = decls
        this.isExport = isExport
        this.wasTsImportEquals = false
        this.wasCommonjsExport = false
    }

    /// 是否可合并 - 对应 Bun S.Local.canMergeWith()
    public func canMergeWith(other: SLocal): Bool {
        if (kind.isUsing()) {
            return false
        }
        return kind == other.kind && isExport == other.isExport &&
               wasCommonjsExport == other.wasCommonjsExport
    }
}

/// 声明 - 对应 Bun G.Decl
/// Bun: pub const Decl = struct { binding: Binding, value: ?Expr }
public class Decl {
    public var binding: Binding
    public var value: ?ASTNode

    public init(binding: Binding, value: ?ASTNode) {
        this.binding = binding
        this.value = value
    }
}

/// S.Namespace - TypeScript namespace
/// Bun: pub const Namespace = struct { name, arg, stmts, is_export }
public class SNamespace {
    public var name: LocRef
    public var arg: Ref
    public var stmts: ArrayList<Stmt>
    public var isExport: Bool

    public init(name: LocRef, arg: Ref, stmts: ArrayList<Stmt>, isExport: Bool) {
        this.name = name
        this.arg = arg
        this.stmts = stmts
        this.isExport = isExport
    }
}

/// S.Enum - TypeScript enum
/// Bun: pub const Enum = struct { name, arg, values, is_export }
public class SEnum {
    public var name: LocRef
    public var arg: Ref
    public var values: ArrayList<EnumValue>
    public var isExport: Bool

    public init(name: LocRef, arg: Ref, values: ArrayList<EnumValue>,
                isExport: Bool) {
        this.name = name
        this.arg = arg
        this.values = values
        this.isExport = isExport
    }
}

/// 枚举值 - 对应 Bun EnumValue
/// Bun: pub const EnumValue = struct { name: LocRef, value: ?Expr, ref }
public class EnumValue {
    public var name: LocRef
    public var value: ?ASTNode
    public var ref: Ref

    public init(name: LocRef, value: ?ASTNode, ref: Ref) {
        this.name = name
        this.value = value
        this.ref = ref
    }
}

// ============================================================================
// 共享 AST 类型 - 对应 Bun G 命名空间中的类型
// ============================================================================

/// LocRef - 位置引用 - 对应 Bun G.LocRef
/// Bun: pub const LocRef = struct { ref: ?Ref = null, loc: logger.Loc }
public class LocRef {
    public var ref: ?Ref
    public var loc: Loc

    public init(ref: Ref, loc: Loc) {
        this.ref = Some(ref)
        this.loc = loc
    }

    public init(loc: Loc) {
        this.ref = None
        this.loc = loc
    }
}

/// G.Fn - 函数 - 对应 Bun G.Fn
/// Bun: pub const Fn = struct { name, args, body, ... }
public class GFn {
    public var name: ?String
    public var args: ArrayList<Binding>
    public var body: FnBody
    public var isAsync: Bool
    public var isGenerator: Bool
    public var id: Ref
    public var openParenLoc: Loc

    public init() {
        this.name = None
        this.args = ArrayList<Binding>()
        this.body = FnBody()
        this.isAsync = false
        this.isGenerator = false
        this.id = Ref.NONE
        this.openParenLoc = Loc(0)
    }
}

/// 函数体 - 对应 Bun FnBody
public class FnBody {
    public var loc: Loc
    public var stmts: ArrayList<Stmt>

    public init() {
        this.loc = Loc(0)
        this.stmts = ArrayList<Stmt>()
    }
}

/// G.Class - 类 - 对应 Bun G.Class
/// Bun: pub const Class = struct { class_name, extends, body, ... }
public class GClass {
    public var className: ?String
    public var nameRef: Ref
    public var extends_: ?ASTNode
    public var body: ArrayList<ClassMember>
    public var decorate: ArrayList<ASTNode>

    public init() {
        this.className = None
        this.nameRef = Ref.NONE
        this.extends_ = None
        this.body = ArrayList<ClassMember>()
        this.decorate = ArrayList<ASTNode>()
    }
}

/// 类成员 - 简化表示
public class ClassMember {
    public var kind: ClassMemberKind
    public var name: String
    public var isStatic: Bool
    public var isPrivate: Bool
    public var value: ?ASTNode

    public init(kind: ClassMemberKind, name: String) {
        this.kind = kind
        this.name = name
        this.isStatic = false
        this.isPrivate = false
        this.value = None
    }
}

/// 类成员类型
public enum ClassMemberKind {
    | Constructor
    | Method
    | Property
    | Getter
    | Setter
    | StaticBlock
}
