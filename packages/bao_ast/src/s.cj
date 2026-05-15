// 严格翻译自: src/ast/s.zig
// S 是 Statement 的联合体数据定义: S.Block, S.If, S.For, S.Function, ...
package bao_ast

import bao_core.*
import bao_collections.*
import bao_parser.*

// ============================================================================
// S 命名空间中的所有语句数据类型
// 严格翻译自: src/ast/s.zig:1-238
// Bun 使用 union enum, 仓颉用独立类表示
// ============================================================================

/// S.Block - 块语句 { ... }
/// Bun: pub const Block = struct { stmts: StmtNodeList, close_brace_loc: logger.Loc }
public class SBlock {
    public var stmts: ArrayList<StmtNode>
    public var closeBraceLoc: Loc

    public init(stmts: ArrayList<StmtNode>, closeBraceLoc: Loc) {
        this.stmts = stmts
        this.closeBraceLoc = closeBraceLoc
    }

    public init(stmts: ArrayList<StmtNode>) {
        this.stmts = stmts
        this.closeBraceLoc = Loc.Empty
    }
}

/// S.SExpr - 表达式语句
/// Bun: pub const SExpr = struct { value: ExprNodeIndex, does_not_affect_tree_shaking: bool }
public class SSExpr {
    public var value: ASTNode
    public var doesNotAffectTreeShaking: Bool

    public init(value: ASTNode, doesNotAffectTreeShaking: Bool) {
        this.value = value
        this.doesNotAffectTreeShaking = doesNotAffectTreeShaking
    }

    public init(value: ASTNode) {
        this.value = value
        this.doesNotAffectTreeShaking = false
    }
}

/// S.Comment - 注释语句
/// Bun: pub const Comment = struct { text: string }
public class SComment {
    public var text: String

    public init(text: String) {
        this.text = text
    }
}

/// S.Directive - 指令语句 ("use strict")
/// Bun: pub const Directive = struct { value: []const u8 }
public class SDirective {
    public var value: String

    public init(value: String) {
        this.value = value
    }
}

/// S.ExportClause - export { item1, item2 }
/// Bun: pub const ExportClause = struct { items: []ClauseItem, is_single_line: bool }
public class SExportClause {
    public var items: ArrayList<ClauseItem>
    public var isSingleLine: Bool

    public init(items: ArrayList<ClauseItem>, isSingleLine: Bool) {
        this.items = items
        this.isSingleLine = isSingleLine
    }
}

/// S.Empty - 空语句
/// Bun: pub const Empty = struct {}
public class SEmpty {
    public init() {}
}

/// S.ExportStar - export * from '...'
/// Bun: pub const ExportStar = struct { namespace_ref: Ref, alias: ?G.ExportStarAlias, import_record_index: u32 }
public class SExportStar {
    public var namespaceRef: Ref
    public var alias: ?GExportStarAlias
    public var importRecordIndex: UInt32

    public init(namespaceRef: Ref, alias: ?GExportStarAlias, importRecordIndex: UInt32) {
        this.namespaceRef = namespaceRef
        this.alias = alias
        this.importRecordIndex = importRecordIndex
    }
}

/// S.ExportEquals - TypeScript 的 export = value
/// Bun: pub const ExportEquals = struct { value: ExprNodeIndex }
public class SExportEquals {
    public var value: ASTNode

    public init(value: ASTNode) {
        this.value = value
    }
}

/// S.Label - 标签语句 label: stmt
/// Bun: pub const Label = struct { name: LocRef, stmt: StmtNodeIndex }
public class SLabel {
    public var name: LocRef
    public var stmt: StmtNode

    public init(name: LocRef, stmt: StmtNode) {
        this.name = name
        this.stmt = stmt
    }
}

/// S.TypeScript - TypeScript 类型声明占位符
/// Bun: pub const TypeScript = struct {}
public class STypeScript {
    public init() {}
}

/// S.Debugger - debugger 语句
/// Bun: pub const Debugger = struct {}
public class SDebugger {
    public init() {}
}

/// S.ExportFrom - export { item1 } from '...'
/// Bun: pub const ExportFrom = struct { items: []ClauseItem, namespace_ref, import_record_index, is_single_line }
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

/// S.ExportDefault - export default ...
/// Bun: pub const ExportDefault = struct { default_name: LocRef, value: StmtOrExpr }
public class SExportDefault {
    public var defaultName: LocRef
    public var value: ASTNode
    public var isStmt: Bool  // true if value is a function/class declaration

    public init(defaultName: LocRef, value: ASTNode, isStmt: Bool) {
        this.defaultName = defaultName
        this.value = value
        this.isStmt = isStmt
    }

    /// 是否可以移动 - 对应 Bun S.ExportDefault.canBeMoved()
    public func canBeMoved(): Bool {
        if (isStmt) {
            match (value.tag) {
                case ExprTag.Class => true
                case ExprTag.Function => true
                case _ => false
            }
        }
        // 表达式可以移动
        return true
    }
}

/// S.Enum - TypeScript 枚举
/// Bun: pub const Enum = struct { name: LocRef, arg: Ref, values: []EnumValue, is_export }
public class SEnum {
    public var name: LocRef
    public var arg: Ref
    public var values: ArrayList<EnumValue>
    public var isExport: Bool

    public init(name: LocRef, arg: Ref, values: ArrayList<EnumValue>, isExport: Bool) {
        this.name = name
        this.arg = arg
        this.values = values
        this.isExport = isExport
    }
}

/// S.Namespace - TypeScript 命名空间
/// Bun: pub const Namespace = struct { name: LocRef, arg: Ref, stmts: StmtNodeList, is_export }
public class SNamespace {
    public var name: LocRef
    public var arg: Ref
    public var stmts: ArrayList<StmtNode>
    public var isExport: Bool

    public init(name: LocRef, arg: Ref, stmts: ArrayList<StmtNode>, isExport: Bool) {
        this.name = name
        this.arg = arg
        this.stmts = stmts
        this.isExport = isExport
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
    public var class_: GClass
    public var isExport: Bool

    public init(class_: GClass, isExport: Bool) {
        this.class_ = class_
        this.isExport = isExport
    }
}

/// S.If - if 语句
/// Bun: pub const If = struct { test_: ExprNodeIndex, yes: StmtNodeIndex, no: ?StmtNodeIndex }
public class SIf {
    public var test_: ASTNode
    public var yes: StmtNode
    public var no: ?StmtNode

    public init(test_: ASTNode, yes: StmtNode, no: ?StmtNode) {
        this.test_ = test_
        this.yes = yes
        this.no = no
    }
}

/// S.For - for 循环
/// Bun: pub const For = struct { init: ?StmtNodeIndex, test_: ?ExprNodeIndex, update: ?ExprNodeIndex, body: StmtNodeIndex }
public class SFor {
    public var init: ?StmtNode
    public var test_: ?ASTNode
    public var update: ?ASTNode
    public var body: StmtNode

    public init(init: ?StmtNode, test_: ?ASTNode, update: ?ASTNode, body: StmtNode) {
        this.init = init
        this.test_ = test_
        this.update = update
        this.body = body
    }
}

/// S.ForIn - for-in 循环
/// Bun: pub const ForIn = struct { init: StmtNodeIndex, value: ExprNodeIndex, body: StmtNodeIndex }
public class SForIn {
    public var init: StmtNode
    public var value: ASTNode
    public var body: StmtNode

    public init(init: StmtNode, value: ASTNode, body: StmtNode) {
        this.init = init
        this.value = value
        this.body = body
    }
}

/// S.ForOf - for-of 循环
/// Bun: pub const ForOf = struct { is_await: bool, init: StmtNodeIndex, value: ExprNodeIndex, body: StmtNodeIndex }
public class SForOf {
    public var isAwait: Bool
    public var init: StmtNode
    public var value: ASTNode
    public var body: StmtNode

    public init(isAwait: Bool, init: StmtNode, value: ASTNode, body: StmtNode) {
        this.isAwait = isAwait
        this.init = init
        this.value = value
        this.body = body
    }
}

/// S.DoWhile - do-while 循环
/// Bun: pub const DoWhile = struct { body: StmtNodeIndex, test_: ExprNodeIndex }
public class SDoWhile {
    public var body: StmtNode
    public var test_: ASTNode

    public init(body: StmtNode, test_: ASTNode) {
        this.body = body
        this.test_ = test_
    }
}

/// S.While - while 循环
/// Bun: pub const While = struct { test_: ExprNodeIndex, body: StmtNodeIndex }
public class SWhile {
    public var test_: ASTNode
    public var body: StmtNode

    public init(test_: ASTNode, body: StmtNode) {
        this.test_ = test_
        this.body = body
    }
}

/// S.With - with 语句
/// Bun: pub const With = struct { value: ExprNodeIndex, body: StmtNodeIndex, body_loc }
public class SWith {
    public var value: ASTNode
    public var body: StmtNode
    public var bodyLoc: Loc

    public init(value: ASTNode, body: StmtNode, bodyLoc: Loc) {
        this.value = value
        this.body = body
        this.bodyLoc = bodyLoc
    }
}

/// S.Try - try-catch-finally
/// Bun: pub const Try = struct { body_loc, body: StmtNodeList, catch_: ?Catch, finally: ?Finally }
public class STry {
    public var bodyLoc: Loc
    public var body: ArrayList<StmtNode>
    public var catch_: ?SCatch
    public var finally: ?SFinally

    public init(bodyLoc: Loc, body: ArrayList<StmtNode>, catch_: ?SCatch, finally: ?SFinally) {
        this.bodyLoc = bodyLoc
        this.body = body
        this.catch_ = catch_
        this.finally = finally
    }
}

/// Catch 子句 - 对应 Bun Catch
public class SCatch {
    public var loc: Loc
    public var binding: ?Binding
    public var body: ArrayList<StmtNode>
    public var bodyLoc: Loc

    public init(loc: Loc, binding: ?Binding, body: ArrayList<StmtNode>, bodyLoc: Loc) {
        this.loc = loc
        this.binding = binding
        this.body = body
        this.bodyLoc = bodyLoc
    }
}

/// Finally 子句 - 对应 Bun Finally
public class SFinally {
    public var loc: Loc
    public var stmts: ArrayList<StmtNode>

    public init(loc: Loc, stmts: ArrayList<StmtNode>) {
        this.loc = loc
        this.stmts = stmts
    }
}

/// S.Switch - switch 语句
/// Bun: pub const Switch = struct { test_: ExprNodeIndex, body_loc, cases: []Case }
public class SSwitch {
    public var test_: ASTNode
    public var bodyLoc: Loc
    public var cases: ArrayList<SCase>

    public init(test_: ASTNode, bodyLoc: Loc, cases: ArrayList<SCase>) {
        this.test_ = test_
        this.bodyLoc = bodyLoc
        this.cases = cases
    }
}

/// Switch Case - 对应 Bun Case
public class SCase {
    public var loc: Loc
    public var value: ?ASTNode  // null for default case
    public var body: ArrayList<StmtNode>

    public init(loc: Loc, value: ?ASTNode, body: ArrayList<StmtNode>) {
        this.loc = loc
        this.value = value
        this.body = body
    }
}

/// S.Import - import 语句
/// Bun: pub const Import = struct { namespace_ref, default_name, items, star_name_loc, import_record_index, is_single_line }
public class SImport {
    public var namespaceRef: Ref
    public var defaultName: ?LocRef
    public var items: ArrayList<ClauseItem>
    public var starNameLoc: ?Loc
    public var importRecordIndex: UInt32
    public var isSingleLine: Bool

    public init(namespaceRef: Ref, defaultName: ?LocRef, items: ArrayList<ClauseItem>,
                starNameLoc: ?Loc, importRecordIndex: UInt32, isSingleLine: Bool) {
        this.namespaceRef = namespaceRef
        this.defaultName = defaultName
        this.items = items
        this.starNameLoc = starNameLoc
        this.importRecordIndex = importRecordIndex
        this.isSingleLine = isSingleLine
    }
}

/// S.Return - return 语句
/// Bun: pub const Return = struct { value: ?ExprNodeIndex }
public class SReturn {
    public var value: ?ASTNode

    public init(value: ?ASTNode) {
        this.value = value
    }
}

/// S.Throw - throw 语句
/// Bun: pub const Throw = struct { value: ExprNodeIndex }
public class SThrow {
    public var value: ASTNode

    public init(value: ASTNode) {
        this.value = value
    }
}

/// S.Local - 变量声明 (var/let/const)
/// Bun: pub const Local = struct { kind: Kind, decls: G.Decl.List, is_export, was_ts_import_equals, was_commonjs_export }
public class SLocal {
    /// 声明类型 - 对应 Bun S.Local.Kind
    public enum LocalKind {
        | Var
        | Let
        | Const
        | Using
        | AwaitUsing

        public func name(): String {
            match (this) {
                case Var => "var"
                case Let => "let"
                case Const => "const"
                case Using => "using"
                case AwaitUsing => "await using"
            }
        }

        /// 是否为 using 声明 - 对应 Bun Kind.isUsing()
        public func isUsing(): Bool {
            match (this) {
                case Using | AwaitUsing => true
                case _ => false
            }
        }

        /// 是否可重新赋值 - 对应 Bun Kind.isReassignable()
        public func isReassignable(): Bool {
            match (this) {
                case Var | Let => true
                case _ => false
            }
        }
    }

    public var kind: LocalKind
    public var decls: ArrayList<GDecl>
    public var isExport: Bool
    public var wasTsImportEquals: Bool
    public var wasCommonjsExport: Bool

    public init(kind: LocalKind, decls: ArrayList<GDecl>, isExport: Bool) {
        this.kind = kind
        this.decls = decls
        this.isExport = isExport
        this.wasTsImportEquals = false
        this.wasCommonjsExport = false
    }

    /// 是否可以合并声明 - 对应 Bun S.Local.canMergeWith()
    public func canMergeWith(other: SLocal): Bool {
        // 不合并 using / await using 声明
        if (kind.isUsing()) {
            return false
        }
        return kind == other.kind && isExport == other.isExport &&
               wasCommonjsExport == other.wasCommonjsExport
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

// ============================================================================
// 共享辅助类型
// ============================================================================

/// ClauseItem - import/export 子句项
/// 对应 Bun ClauseItem
public class ClauseItem {
    public var name: String
    public var nameLoc: Loc
    public var alias: String
    public var aliasLoc: Loc
    public var originalName: String
    public var ref: Ref
    public var importRecordIndex: UInt32

    public init(name: String, nameLoc: Loc, alias: String, aliasLoc: Loc,
                originalName: String, ref: Ref, importRecordIndex: UInt32) {
        this.name = name
        this.nameLoc = nameLoc
        this.alias = alias
        this.aliasLoc = aliasLoc
        this.originalName = originalName
        this.ref = ref
        this.importRecordIndex = importRecordIndex
    }
}

/// EnumValue - 枚举值
/// 对应 Bun EnumValue
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

/// ExportStarAlias - export * as ns
/// 对应 Bun G.ExportStarAlias (已在 e.cj 中定义, 这里提供别名)
public typealias GExportStarAlias = GExportStarAlias
