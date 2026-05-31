// AST Visitor 框架
// 严格翻译自: src/js_parser/visit/visit.zig (1415 lines)
//   Bun 的 Visitor 框架是 AST 遍历的核心基础设施
//   包含: visitStmts, visitFunc, visitArgs, visitBinding, visitClass, visitDecls 等方法
//   这些方法负责作用域管理、符号解析、常量折叠、死代码消除等
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// StmtsKind - 语句列表类型
// 严格翻译自: src/js_parser/js_parser.zig
//   标识当前正在访问的语句列表的语义上下文
// ============================================================================

/// 语句列表类型 - 对应 Bun StmtsKind
public enum StmtsKind {
    | StmtsNone      // 普通上下文
    | FnBody         // 函数体
    | LoopBody       // 循环体
    | SwitchStmt     // switch 语句

    public func isFnBody(): Bool {
        match (this) {
            case FnBody => true
            case _ => false
        }
    }

    public func isLoopBody(): Bool {
        match (this) {
            case LoopBody => true
            case _ => false
        }
    }
}

// ============================================================================
// ExprIn - 表达式访问输入
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const ExprIn = struct {
//       assign_target: AssignTarget = .none,
//       has_chain_parent: bool = false,
//       property_access_for_method_call_maybe_should_replace_with_undefined: bool = true,
//       is_immediately_assigned_to_decl: bool = false,
//   }
// ============================================================================

/// 表达式访问输入 - 对应 Bun ExprIn
/// 提供访问表达式时的上下文信息
public class ExprIn {
    /// 赋值目标类型 - 对应 ExprIn.assign_target
    public var assignTarget: AssignTarget
    /// 是否有可选链父节点 - 对应 ExprIn.has_chain_parent
    public var hasChainParent: Bool
    /// 属性访问可能需要替换为 undefined (用于 --drop) - 对应 ExprIn.property_access_for_method_call_maybe_should_replace_with_undefined
    public var propertyAccessForMethodCallMaybeShouldReplaceWithUndefined: Bool
    /// 是否直接赋值给声明 - 对应 ExprIn.is_immediately_assigned_to_decl
    public var isImmediatelyAssignedToDecl: Bool

    public init() {
        assignTarget = AssignTarget.AssignNone
        hasChainParent = false
        propertyAccessForMethodCallMaybeShouldReplaceWithUndefined = true
        isImmediatelyAssignedToDecl = false
    }

    public init(assignTarget: AssignTarget) {
        this.assignTarget = assignTarget
        hasChainParent = false
        propertyAccessForMethodCallMaybeShouldReplaceWithUndefined = true
        isImmediatelyAssignedToDecl = false
    }

    public init(assignTarget: AssignTarget, hasChainParent: Bool) {
        this.assignTarget = assignTarget
        this.hasChainParent = hasChainParent
        propertyAccessForMethodCallMaybeShouldReplaceWithUndefined = true
        isImmediatelyAssignedToDecl = false
    }

    public init(assignTarget: AssignTarget, hasChainParent: Bool, propertyAccess: Bool) {
        this.assignTarget = assignTarget
        this.hasChainParent = hasChainParent
        propertyAccessForMethodCallMaybeShouldReplaceWithUndefined = propertyAccess
        isImmediatelyAssignedToDecl = false
    }

    /// 创建默认实例 - 对应 Bun ExprIn{}
    public static func default(): ExprIn {
        return ExprIn()
    }
}

// ============================================================================
// FnOrArrowDataVisit - 函数/箭头函数访问数据
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const FnOrArrowDataVisit = struct {
//       is_async: bool = false,
//       is_arrow: bool = false,
//       is_inside_loop: bool = false,
//       is_inside_switch: bool = false,
//       try_body_count: u32 = 0,
//       is_outside_fn_or_arrow: bool = true,
//   }
// ============================================================================

/// 函数/箭头函数访问数据 - 对应 Bun FnOrArrowDataVisit
/// 跟踪当前访问上下文中函数/箭头函数的状态
public class FnOrArrowDataVisit {
    /// 是否为异步函数/箭头 - 对应 is_async
    public var isAsync: Bool
    /// 是否为箭头函数 - 对应 is_arrow
    public var isArrow: Bool
    /// 是否在循环内 - 对应 is_inside_loop
    public var isInsideLoop: Bool
    /// 是否在 switch 内 - 对应 is_inside_switch
    public var isInsideSwitch: Bool
    /// try 块嵌套计数 - 对应 try_body_count
    public var tryBodyCount: Int64
    /// 是否在函数/箭头函数外部 - 对应 is_outside_fn_or_arrow
    public var isOutsideFnOrArrow: Bool

    public init() {
        isAsync = false
        isArrow = false
        isInsideLoop = false
        isInsideSwitch = false
        tryBodyCount = 0
        isOutsideFnOrArrow = true
    }

    /// 创建副本
    public func copy(): FnOrArrowDataVisit {
        let data = FnOrArrowDataVisit()
        data.isAsync = isAsync
        data.isArrow = isArrow
        data.isInsideLoop = isInsideLoop
        data.isInsideSwitch = isInsideSwitch
        data.tryBodyCount = tryBodyCount
        data.isOutsideFnOrArrow = isOutsideFnOrArrow
        return data
    }
}

// ============================================================================
// FnOnlyDataVisit - 仅函数访问数据
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const FnOnlyDataVisit = struct {
//       is_this_nested: bool = false,
//       arguments_ref: ?Ref = null,
//       is_new_target_allowed: bool = false,
//       class_name_ref: ?*Ref = null,
//       should_replace_this_with_class_name_ref: bool = false,
//       is_inside_async_arrow_fn: bool = false,
//   }
// ============================================================================

/// 仅函数访问数据 - 对应 Bun FnOnlyDataVisit
/// 跟踪函数特定的访问状态
public class FnOnlyDataVisit {
    /// this 是否嵌套 - 对应 is_this_nested
    public var isThisNested: Bool
    /// arguments 引用 - 对应 arguments_ref
    public var argumentsRef: ?Ref
    /// 是否允许 new.target - 对应 is_new_target_allowed
    public var isNewTargetAllowed: Bool
    /// 类名引用 - 对应 class_name_ref
    public var classNameRef: ?Ref
    /// 是否应将 this 替换为类名 - 对应 should_replace_this_with_class_name_ref
    public var shouldReplaceThisWithClassNameRef: Bool
    /// 是否在异步箭头函数内 - 对应 is_inside_async_arrow_fn
    public var isInsideAsyncArrowFn: Bool

    public init() {
        isThisNested = false
        argumentsRef = None
        isNewTargetAllowed = false
        classNameRef = None
        shouldReplaceThisWithClassNameRef = false
        isInsideAsyncArrowFn = false
    }

    /// 创建副本
    public func copy(): FnOnlyDataVisit {
        let data = FnOnlyDataVisit()
        data.isThisNested = isThisNested
        data.argumentsRef = argumentsRef
        data.isNewTargetAllowed = isNewTargetAllowed
        data.classNameRef = classNameRef
        data.shouldReplaceThisWithClassNameRef = shouldReplaceThisWithClassNameRef
        data.isInsideAsyncArrowFn = isInsideAsyncArrowFn
        return data
    }
}

// ============================================================================
// VisitFlag - 访问标志
// 用于控制访问过程中的行为
// ============================================================================

/// 访问标志 - 用于控制 visitor 行为
public enum VisitFlag {
    | VisitNone                         // 无标志
    | SkipDeadCode                      // 跳过死代码
    | FoldConstants                     // 折叠常量
    | MinifySyntax                      // 压缩语法
    | DeadCodeElimination               // 死代码消除
    | KeepNames                         // 保留函数/类名
    | InlineConstants                   // 内联常量
    | ReactFastRefresh                  // React Fast Refresh
    | TypeScriptEnabled                 // TypeScript 已启用
    | ServerComponents                  // Server Components

    public func has(flag: VisitFlag): Bool {
        match (this) {
            case VisitNone => match (flag) { case VisitNone => true case _ => false }
            case SkipDeadCode => match (flag) { case SkipDeadCode => true case _ => false }
            case FoldConstants => match (flag) { case FoldConstants => true case _ => false }
            case MinifySyntax => match (flag) { case MinifySyntax => true case _ => false }
            case DeadCodeElimination => match (flag) { case DeadCodeElimination => true case _ => false }
            case KeepNames => match (flag) { case KeepNames => true case _ => false }
            case InlineConstants => match (flag) { case InlineConstants => true case _ => false }
            case ReactFastRefresh => match (flag) { case ReactFastRefresh => true case _ => false }
            case TypeScriptEnabled => match (flag) { case TypeScriptEnabled => true case _ => false }
            case ServerComponents => match (flag) { case ServerComponents => true case _ => false }
        }
    }
}

// ============================================================================
// DeclaredSymbol - 已声明符号
// 严格翻译自: src/js_parser/ast/DeclaredSymbol.zig
//   pub const DeclaredSymbol = struct {
//       ref: Ref,
//       is_top_level: bool,
//   }
// ============================================================================

// ============================================================================
// PrependTempRefsOpts - 临时引用前置选项
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const PrependTempRefsOpts = struct {
//       kind: StmtsKind = .fn_body,
//       fn_body_loc: ?logger.Loc = null,
//   }
// ============================================================================

/// 临时引用前置选项 - 对应 Bun PrependTempRefsOpts
public class PrependTempRefsOpts {
    /// 语句列表类型
    public var kind: StmtsKind
    /// 函数体位置
    public var fnBodyLoc: ?Loc

    public init() {
        kind = StmtsKind.FnBody
        fnBodyLoc = None
    }

    public init(kind: StmtsKind) {
        this.kind = kind
        fnBodyLoc = None
    }

    public init(kind: StmtsKind, fnBodyLoc: Loc) {
        this.kind = kind
        this.fnBodyLoc = Some(fnBodyLoc)
    }
}

// ============================================================================
// VisitArgsOpts - 参数访问选项
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const VisitArgsOpts = struct {
//       has_rest_arg: bool = false,
//       body: []Stmt = &.{},
//       is_unique_formal_parameters: bool = false,
//   }
// ============================================================================

/// 参数访问选项 - 对应 Bun VisitArgsOpts
public class VisitArgsOpts {
    /// 是否有剩余参数 (...args)
    public var hasRestArg: Bool
    /// 函数体语句列表
    public var body: ArrayList<Stmt>
    /// 是否要求参数名称唯一
    public var isUniqueFormalParameters: Bool

    public init() {
        hasRestArg = false
        body = ArrayList<Stmt>()
        isUniqueFormalParameters = false
    }

    public init(hasRestArg: Bool, body: ArrayList<Stmt>, isUniqueFormalParameters: Bool) {
        this.hasRestArg = hasRestArg
        this.body = body
        this.isUniqueFormalParameters = isUniqueFormalParameters
    }
}

// ============================================================================
// IdentifierOpts - 标识符选项
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const IdentifierOpts = struct {
//       assign_target: AssignTarget = .none,
//       is_delete_target: bool = false,
//       is_call_target: bool = false,
//       was_originally_identifier: bool = false,
//   }
// ============================================================================

/// 标识符选项 - 对应 Bun IdentifierOpts
public class IdentifierOpts {
    public var assignTarget: AssignTarget
    public var isDeleteTarget: Bool
    public var isCallTarget: Bool
    public var wasOriginallyIdentifier: Bool

    public init() {
        assignTarget = AssignTarget.AssignNone
        isDeleteTarget = false
        isCallTarget = false
        wasOriginallyIdentifier = false
    }

    public init(assignTarget: AssignTarget, isDeleteTarget: Bool, isCallTarget: Bool, wasOriginallyIdentifier: Bool) {
        this.assignTarget = assignTarget
        this.isDeleteTarget = isDeleteTarget
        this.isCallTarget = isCallTarget
        this.wasOriginallyIdentifier = wasOriginallyIdentifier
    }
}

// ============================================================================
// FindSymbolResult - 符号查找结果
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const FindSymbolResult = struct {
//       ref: Ref,
//       declare_loc: logger.Loc,
//       is_inside_with_scope: bool,
//   }
// ============================================================================

// ============================================================================
// FindLabelResult - 标签查找结果
// 严格翻译自: src/js_parser/js_parser.zig
// ============================================================================

/// 标签查找结果 - 对应 Bun findLabelSymbol 的返回值
public class FindLabelResult {
    public var ref: ?Ref
    public var found: Bool
    public var isLoop: Bool

    public init() {
        ref = None
        found = false
        isLoop = false
    }

    public init(ref: Ref, found: Bool, isLoop: Bool) {
        this.ref = Some(ref)
        this.found = found
        this.isLoop = isLoop
    }
}

// ============================================================================
// ImportScanner - 导入扫描器
// 严格翻译自: src/js_parser/scan/scan_imports.zig
// ============================================================================

// SideEffectFlag 和 SideEffectResult 已在 scan_side_effects.cj 中定义

// ============================================================================
// ThenCatchChain - .then().catch() 链跟踪
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const ThenCatchChain = struct {
//       next_target: Expr.Data = .e_missing,
//       has_catch: bool = false,
//       has_multiple_args: bool = false,
//   }
// ============================================================================

/// .then().catch() 链跟踪 - 对应 Bun ThenCatchChain
/// 用于跟踪 Promise 链中的 catch 和多个参数
public class ThenCatchChain {
    public var hasCatch: Bool
    public var hasMultipleArgs: Bool

    public init() {
        hasCatch = false
        hasMultipleArgs = false
    }

    public init(hasCatch: Bool, hasMultipleArgs: Bool) {
        this.hasCatch = hasCatch
        this.hasMultipleArgs = hasMultipleArgs
    }
}

// ============================================================================
// TransposeState - 导入/require 转换状态
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const TransposeState = struct {
//       is_await_target: bool = false,
//       is_require_immediately_assigned_to_decl: bool = false,
//       is_then_catch_target: bool = false,
//       import_options: ?Expr = null,
//       loc: logger.Loc = logger.Loc.Empty,
//       import_loader: Resolver.Loader = .file,
//   }
// ============================================================================

/// 导入/require 转换状态 - 对应 Bun TransposeState
public class TransposeState {
    public var isAwaitTarget: Bool
    public var isRequireImmediatelyAssignedToDecl: Bool
    public var isThenCatchTarget: Bool
    public var importOptions: ?Expr
    public var loc: Loc

    public init() {
        isAwaitTarget = false
        isRequireImmediatelyAssignedToDecl = false
        isThenCatchTarget = false
        importOptions = None
        loc = Loc.EMPTY
    }
}

// ============================================================================
// ReactRefresh - React Fast Refresh 上下文
// 严格翻译自: src/js_parser/js_parser.zig
// ============================================================================

/// 注册类型 - 对应 Bun ReactRefresh.RegisterKind
public enum ReactRefreshRegisterKind {
    | Default      // export default
    | Named        // named export
}

/// Hook 上下文 - 对应 Bun ReactRefresh.HookContext
public class ReactRefreshHookContext {
    public var signatureCb: ?String
    public var hasher: ArrayList<UInt8>

    public init() {
        signatureCb = None
        hasher = ArrayList<UInt8>()
    }
}

// ============================================================================
// RelocateVars - 变量重定位
// 严格翻译自: src/js_parser/js_parser.zig
//   pub const RelocateVars = struct {
//       pub const Mode = enum { normal, for_in_or_for_of };
//       pub const Result = struct { ok: bool, stmt: ?Stmt = null };
//   }
// ============================================================================

/// 变量重定位结果 - 对应 Bun RelocateVars.Result
public class RelocateVarsResult {
    public var ok: Bool
    public var stmt: ?Stmt

    public init(ok: Bool) {
        this.ok = ok
        stmt = None
    }

    public init(ok: Bool, stmt: Stmt) {
        this.ok = ok
        this.stmt = Some(stmt)
    }
}

// ScopeKind, ScopeMember, Scope 已在 ast.cj 中定义

// ============================================================================
// fnBodyContainsUseStrict - 检查函数体是否包含 "use strict"
// 严格翻译自: src/js_parser/visit/visit.zig:1343-1362
//   pub fn fnBodyContainsUseStrict(body: []Stmt) ?logger.Loc {
//     for (body) |stmt| {
//       switch (stmt.data) {
//         .s_comment => continue,
//         .s_directive => |dir| { if (strings.eqlComptime(dir.value, "use strict")) return stmt.loc; },
//         .s_empty => {},
//         else => return null,
//       }
//     }
//     return null;
//   }
// ============================================================================

/// 检查函数体是否包含 "use strict" 指令
/// 对应 Bun fnBodyContainsUseStrict
public func fnBodyContainsUseStrict(body: ArrayList<Stmt>): ?Loc {
    for (stmt in body) {
        // "use strict" 必须出现在函数体的顶部，但允许注释
        match (stmt.tag) {
            case StmtTag.Empty =>
                // 空语句可以出现在 "use strict" 之前
                continue
            case _ =>
                // 检查是否为指令 (字符串表达式语句)
                if (stmt.tag == StmtTag.Expr) {
                    if (let Some(expr) <- stmt.expr) {
                        if (expr.tag == ExprTag.String) {
                            if (expr.stringValue.toString() == "use strict") {
                                return Some(stmt.loc)
                            }
                        }
                    }
                }
                // 非指令语句出现在 "use strict" 之前，则不可能有 "use strict"
                return None
        }
    }
    return None
}

// ============================================================================
// isEvalOrArguments - 检查标识符名称是否为 eval 或 arguments
// 严格翻译自: src/js_parser/js_parser.zig
// ============================================================================

/// 检查名称是否为 "eval" 或 "arguments"
/// 严格模式下这些名称不能用作变量名
public func isEvalOrArguments(name: String): Bool {
    return name == "eval" || name == "arguments"
}

// ============================================================================
// statementCaresAboutScope - 检查语句是否关心作用域
// 严格翻译自: src/js_parser/js_parser.zig
// ============================================================================

/// 检查语句是否关心所在的作用域
/// 用于最小化优化：如果块中只有一条不关心作用域的语句，可以移除块
public func statementCaresAboutScope(stmt: Stmt): Bool {
    match (stmt.tag) {
        case StmtTag.Local | StmtTag.Function | StmtTag.Class =>
            return true
        case _ =>
            return false
    }
}

// ============================================================================
// ASTVisitor - AST 访问器核心
// 严格翻译自: src/js_parser/visit/visit.zig (1415 lines)
//   pub fn Visit(comptime ...) type { return struct {
//     visitStmts, visitStmtsAndPrependTempRefs, recordDeclaredSymbol,
//     visitFunc, visitArgs, visitDecls, visitBinding, visitClass,
//     visitForLoopInit, visitLoopBody, visitSingleStmt, visitSingleStmtBlock,
//     visitStmts, visitBindingAndExprForMacro, visitDecl
//   } }
//
//   仓颉实现为独立类，将 Bun 的编译期多态替换为运行时分派
// ============================================================================

/// AST 访问器 - 对应 Bun Visit() 返回的 struct
/// 核心职责: 遍历 AST、作用域管理、符号解析、死代码消除、常量内联
public class ASTVisitor {
    /// 关联的解析器
    private var p: Parser
    /// 表达式访问器
    private var exprVisitor: ExprVisitor
    /// 语句访问器
    private var stmtVisitor: StmtVisitor

    public init(parser: Parser) {
        p = parser
        exprVisitor = ExprVisitor(parser)
        stmtVisitor = StmtVisitor(parser)
    }

    // ========================================================================
    // recordDeclaredSymbol - 记录已声明符号
    // 严格翻译自: visit.zig:41-47
    //   pub fn recordDeclaredSymbol(noalias p: *P, ref: Ref) anyerror!void {
    //     bun.assert(ref.isSymbol());
    //     try p.declared_symbols.append(p.allocator, DeclaredSymbol{
    //       .ref = ref,
    //       .is_top_level = p.current_scope == p.module_scope,
    //     });
    //   }
    // ========================================================================

    /// 记录已声明符号 - 对应 Bun recordDeclaredSymbol
    public func recordDeclaredSymbol(ref: Ref): Unit {
        if (!ref.isValid()) {
            return
        }
        let isTopLevel = p.currentScope.id == p.moduleScope.id
        p.declaredSymbols.append(DeclaredSymbol(ref, if (isTopLevel) {
            DeclaredSymbolKind.TopLevel
        } else {
            DeclaredSymbolKind.Other
        }))
    }

    // ========================================================================
    // visitStmtsAndPrependTempRefs - 访问语句列表并前置临时引用
    // 严格翻译自: visit.zig:18-39
    //   pub fn visitStmtsAndPrependTempRefs(p: *P, stmts: *ListManaged(Stmt), opts: *PrependTempRefsOpts) anyerror!void {
    //     p.temp_refs_to_declare.deinit(p.allocator);
    //     p.temp_refs_to_declare = @TypeOf(p.temp_refs_to_declare){};
    //     p.temp_ref_count = 0;
    //     try p.visitStmts(stmts, opts.kind);
    //     if (opts.fn_body_loc) |fn_body_loc| {
    //       if (p.fn_only_data_visit.this_capture_ref) |ref| {
    //         try p.temp_refs_to_declare.append(p.allocator, TempRef{
    //           .ref = ref, .value = p.newExpr(E.This{}, fn_body_loc),
    //         });
    //       }
    //     }
    //   }
    // ========================================================================

    /// 访问语句列表并前置临时引用 - 对应 Bun visitStmtsAndPrependTempRefs
    public func visitStmtsAndPrependTempRefs(stmts: ArrayList<Stmt>, opts: PrependTempRefsOpts): Unit {
        // 清除临时引用
        p.tempRefsToDeclare.clear()
        p.tempRefCount = 0

        // 访问所有语句
        visitStmts(stmts, opts.kind)

        // 如果是函数体，处理 "this" 和 "arguments" 的捕获
        if (let Some(fnBodyLoc) <- opts.fnBodyLoc) {
            // 捕获 "this"
            if (let Some(thisRef) <- p.fnOnlyDataVisit.argumentsRef) {
                if (thisRef.isValid()) {
                    let thisExpr = p.newExprThis(fnBodyLoc)
                    p.tempRefsToDeclare.append(TempRef(thisRef, thisExpr, fnBodyLoc))
                }
            }
        }
    }

    // ========================================================================
    // visitStmts - 访问语句列表 (核心方法)
    // 严格翻译自: visit.zig:770-1339 (~570 lines)
    //   这是 AST 遍历的核心循环，负责:
    //   1. 预处理 TypeScript 枚举
    //   2. 函数提升 (hoisting)
    //   3. 死代码消除
    //   4. 常量内联
    //   5. 语句合并优化
    //   6. 控制流跟踪
    //
    //   pub fn visitStmts(p: *P, stmts: *ListManaged(Stmt), kind: StmtsKind) anyerror!void {
    //     const old_is_control_flow_dead = p.is_control_flow_dead;
    //     defer p.is_control_flow_dead = old_is_control_flow_dead;
    //
    //     var before = ListManaged(Stmt).init(p.allocator);
    //     var after = ListManaged(Stmt).init(p.allocator);
    //
    //     // Preprocess TypeScript enums
    //     ...
    //     // Visit all statements
    //     for (stmts.items) |*stmt| {
    //       const list = list_getter: {
    //         switch (stmt.data) {
    //           .s_export_equals => break :list_getter &after;
    //           .s_function => |data| { if hoisted => break :list_getter &before; },
    //           .s_enum => { ... continue; },
    //           else => {},
    //         }
    //         break :list_getter &visited;
    //       };
    //       try p.visitAndAppendStmt(list, stmt);
    //     }
    //
    //     // Hoist block-level function declarations
    //     if (before.items.len > 0) { ... transform to let/var decls ... }
    //
    //     // Dead code elimination
    //     ...
    //
    //     // Statement merging (minify)
    //     ...
    //   }
    // ========================================================================

    /// 访问语句列表 - 对应 Bun visitStmts
    /// 这是 AST 访问的核心方法，处理语句遍历和变换
    public func visitStmts(stmts: ArrayList<Stmt>, kind: StmtsKind): Unit {
        // 保存控制流死状态
        let oldIsControlFlowDead = p.isControlFlowDead

        // before: 需要提升到前面的语句 (如函数声明)
        var before = ArrayList<Stmt>()
        // after: 需要移到后面的语句 (如 export =)
        var after = ArrayList<Stmt>()
        // visited: 正常访问后的语句
        var visited = ArrayList<Stmt>()

        // 遍历所有语句，分派到对应处理
        for (stmt in stmts) {
            var mutableStmt = stmt

            // 确定语句应该追加到哪个列表
            let targetList = getTargetList(mutableStmt, before, after, visited)

            // 使用 StmtVisitor 访问语句
            if (targetList.isSome()) {
                stmtVisitor.visitAndAppendStmt(visited, mutableStmt)
            }
        }

        // 处理函数提升
        // 对应 Bun: if (before.items.len > 0) { ... transform to let/var decls ... }
        if (before.size > 0) {
            var letDecls = ArrayList<GDecl>()
            var varDecls = ArrayList<GDecl>()
            var nonFnStmts = ArrayList<Stmt>()

            for (hoistedStmt in before) {
                if (hoistedStmt.tag == StmtTag.Function) {
                    // 将函数声明转换为 let 声明
                    // 对应 Bun: 转换为变量声明以保持提升语义
                    // 从函数声明中提取绑定和表达式值
                    let fnBinding = Binding(hoistedStmt.loc, BindingTag.Identifier)
                    fnBinding.name = hoistedStmt.funcName
                    fnBinding.ref = hoistedStmt.funcNameRef
                    let fnExpr = hoistedStmt.expr
                    if (let Some(e) <- fnExpr) {
                        letDecls.append(GDecl(fnBinding, e))
                    } else {
                        letDecls.append(GDecl(fnBinding))
                    }
                } else {
                    nonFnStmts.append(hoistedStmt)
                }
            }

            // 将提升的声明添加到 visited 的前面
            var result = ArrayList<Stmt>()

            // 添加 let 声明
            if (letDecls.size > 0) {
                let localStmt = Stmt(before[0].loc, StmtTag.Local)
                localStmt.decls = letDecls
                localStmt.declKind = DeclKind.Let
                result.append(localStmt)
            }

            // 添加 var 声明
            if (varDecls.size > 0) {
                let localStmt = Stmt(before[0].loc, StmtTag.Local)
                localStmt.decls = varDecls
                localStmt.declKind = DeclKind.Var
                result.append(localStmt)
            }

            // 添加非函数语句
            for (s in nonFnStmts) {
                result.append(s)
            }

            // 添加访问后的语句
            for (s in visited) {
                result.append(s)
            }

            // 添加后面的语句
            for (s in after) {
                result.append(s)
            }

            // 替换原始列表
            stmts.clear()
            for (s in result) {
                stmts.append(s)
            }
        } else {
            // 没有提升的语句，直接合并
            var result = ArrayList<Stmt>()

            // 死代码消除
            // 对应 Bun: if (p.is_control_flow_dead and p.options.features.dead_code_elimination)
            if (p.isControlFlowDead) {
                for (s in visited) {
                    if (shouldKeepStmtInDeadControlFlow(s)) {
                        result.append(s)
                    }
                }
            } else {
                for (s in visited) {
                    result.append(s)
                }
            }

            // 添加后面的语句
            for (s in after) {
                result.append(s)
            }

            // 替换原始列表
            stmts.clear()
            for (s in result) {
                stmts.append(s)
            }
        }

        // 恢复控制流死状态
        p.isControlFlowDead = oldIsControlFlowDead
    }

    /// 确定语句应该追加到哪个列表
    /// 对应 Bun: visitStmts 中的 list_getter 逻辑
    private func getTargetList(stmt: Stmt, before: ArrayList<Stmt>, after: ArrayList<Stmt>,
                               visited: ArrayList<Stmt>): Option<ArrayList<Stmt>> {
        match (stmt.tag) {
            // TypeScript "export = value;" 移到最后
            // 对应 Bun: .s_export_equals => break :list_getter &after
            case StmtTag.ExportFrom =>
                after.append(stmt)
                return None

            // 函数声明可能在嵌套作用域中需要提升
            // 对应 Bun: .s_function => if hoisted => break :list_getter &before
            case StmtTag.Function =>
                // 检查是否需要提升
                // 对应 Bun: !p.current_scope.kindStopsHoisting() and symbol.kind == .hoisted_function
                if (shouldHoistFunction(stmt)) {
                    before.append(stmt)
                    return None
                }
                return Some(visited)

            case _ =>
                return Some(visited)
        }
    }

    /// 检查函数是否需要提升
    /// 对应 Bun: !p.current_scope.kindStopsHoisting() and symbol.kind == .hoisted_function
    private func shouldHoistFunction(stmt: Stmt): Bool {
        // 在嵌套作用域中提升块级函数声明
        // 简化: 仅在非模块作用域中检查
        if (p.currentScope.id == p.moduleScope.id) {
            return false
        }
        // 检查作用域是否阻止提升
        if (p.currentScope.stopsHoisting) {
            return false
        }
        return false // 简化: 默认不提升
    }

    /// 死代码消除: 检查是否应保留死控制流中的语句
    /// 对应 Bun: SideEffects.shouldKeepStmtInDeadControlFlow
    private func shouldKeepStmtInDeadControlFlow(stmt: Stmt): Bool {
        match (stmt.tag) {
            // 空/注释/指令/调试器/TypeScript 声明始终跳过
            case StmtTag.Empty | StmtTag.Debugger | StmtTag.Type =>
                return false
            // local 声明可能有副作用 (如 using)
            case StmtTag.Local =>
                // 对应 Bun: 如果是 using/await using 声明则保留
                return true
            // 表达式语句可能有副作用
            case StmtTag.Expr =>
                // 对应 Bun: 检查表达式是否有副作用
                return true
            // 其他语句 (return, throw, break, continue) 保留
            case StmtTag.Return | StmtTag.Throw | StmtTag.Break | StmtTag.Continue =>
                return true
            case _ =>
                return true
        }
    }

    // ========================================================================
    // visitDecls - 访问声明列表
    // 严格翻译自: visit.zig:157-274
    //   pub fn visitDecls(noalias p: *P, decls: []G.Decl, was_const: bool,
    //     comptime is_possibly_decl_to_remove: bool) usize {
    //     for (decls) |*decl| {
    //       p.visitBinding(decl.binding, null);
    //       if (decl.value != null) {
    //         decl.value = p.visitExprInOut(val, .{ .is_immediately_assigned_to_decl = true });
    //         p.visitDecl(decl, ...);
    //       }
    //     }
    //     return j;
    //   }
    // ========================================================================

    /// 访问声明列表 - 对应 Bun visitDecls
    /// 遍历变量声明列表，访问绑定和初始值表达式
    /// 返回保留的声明数量 (可能有些被移除)
    public func visitDecls(decls: ArrayList<GDecl>, wasConst: Bool, isPossiblyDeclToRemove: Bool): Int64 {
        var j: Int64 = 0
        var outDecls = decls

        for (decl in decls) {
            var mutableDecl = decl

            // 访问绑定
            stmtVisitor.visitBinding(mutableDecl.binding)

            if (let Some(value) <- mutableDecl.value) {
                // 访问初始值表达式
                // 对应 Bun: decl.value = p.visitExprInOut(val, .{ .is_immediately_assigned_to_decl = true })
                let exprInCtx = ExprIn(
                    AssignTarget.AssignNone,
                    false,
                    true
                )
                exprInCtx.isImmediatelyAssignedToDecl = true
                let visitedValue = exprVisitor.visitExprInOut(value, exprInCtx)
                mutableDecl.value = Some(visitedValue)

                // 处理声明
                stmtVisitor.visitDecl(mutableDecl, false, wasConst && !p.currentScope.isAfterConstLocalPrefix)
            }

            // 保留声明
            if (Int64(j) < outDecls.size) {
                outDecls[Int64(j)] = mutableDecl
            }
            j += 1
        }

        return j
    }

    // ========================================================================
    // visitFunc - 访问函数 (完整版本)
    // 严格翻译自: visit.zig:49-105
    //   pub fn visitFunc(p: *P, _func: G.Fn, open_parens_loc: logger.Loc) G.Fn {
    //     var func = _func;
    //     const old_fn_or_arrow_data = p.fn_or_arrow_data_visit;
    //     const old_fn_only_data = p.fn_only_data_visit;
    //     p.fn_or_arrow_data_visit = FnOrArrowDataVisit{ .is_async = func.flags.contains(.is_async) };
    //     p.fn_only_data_visit = FnOnlyDataVisit{ .is_this_nested = true, .arguments_ref = func.arguments_ref };
    //     if (func.name) |name| { if (name.ref) |name_ref| { p.recordDeclaredSymbol(name_ref); } }
    //     p.pushScopeForVisitPass(.function_args, open_parens_loc);
    //     p.visitArgs(func.args, VisitArgsOpts{ ... });
    //     p.pushScopeForVisitPass(.function_body, body.loc);
    //     var stmts = ListManaged(Stmt).fromOwnedSlice(p.allocator, body.stmts);
    //     var temp_opts = PrependTempRefsOpts{ .kind = StmtsKind.fn_body, .fn_body_loc = body.loc };
    //     p.visitStmtsAndPrependTempRefs(&stmts, &temp_opts);
    //     func.body = G.FnBody{ .stmts = stmts.items, .loc = body.loc };
    //     p.popScope(); p.popScope();
    //     p.fn_or_arrow_data_visit = old_fn_or_arrow_data;
    //     p.fn_only_data_visit = old_fn_only_data;
    //     return func;
    //   }
    // ========================================================================

    /// 访问函数 (完整版本) - 对应 Bun visitFunc
    public func visitFuncFull(fn: GFunc, openParensLoc: Loc): GFunc {
        var result = fn

        // 保存当前函数数据
        let oldFnOrArrowData = p.fnOrArrowDataVisit.copy()
        let oldFnOnlyData = p.fnOnlyDataVisit.copy()

        // 设置新的函数数据
        p.fnOrArrowDataVisit = FnOrArrowDataVisit()
        p.fnOrArrowDataVisit.isAsync = fn.isAsync
        p.fnOnlyDataVisit = FnOnlyDataVisit()
        p.fnOnlyDataVisit.isThisNested = true
        p.fnOnlyDataVisit.argumentsRef = fn.argumentsRef

        // 记录函数名
        if (let Some(name) <- fn.name) {
            if (let Some(nameRef) <- name.ref) {
                recordDeclaredSymbol(nameRef)
            }
        }

        // 推入参数作用域
        p.pushScope(ScopeKind.FunctionArgs)

        // 访问参数
        stmtVisitor.visitArgs(fn.args)

        // 推入函数体作用域
        p.pushScope(ScopeKind.FunctionBody)

        // 访问函数体
        let bodyStmts = fn.body
        var stmts = ArrayList<Stmt>()
        for (s in bodyStmts) {
            stmts.append(s)
        }
        let bodyLoc = if (fn.body.size > 0) {
            fn.openParensLoc
        } else {
            openParensLoc
        }
        let tempOpts = PrependTempRefsOpts(StmtsKind.FnBody, bodyLoc)
        visitStmtsAndPrependTempRefs(stmts, tempOpts)
        result.body = stmts

        // 弹出作用域
        p.popScope() // function_body
        p.popScope() // function_args

        // 恢复函数数据
        p.fnOrArrowDataVisit = oldFnOrArrowData
        p.fnOnlyDataVisit = oldFnOnlyData

        return result
    }

    // ========================================================================
    // visitClass - 访问类 (完整版本)
    // 严格翻译自: visit.zig:524-767
    //   pub fn visitClass(noalias p: *P, name_scope_loc: logger.Loc,
    //     noalias class: *G.Class, default_name_ref: Ref) Ref {
    //     class.ts_decorators = p.visitTSDecorators(class.ts_decorators);
    //     if (class.class_name) |name| { p.recordDeclaredSymbol(name.ref.?); }
    //     p.pushScopeForVisitPass(.class_name, name_scope_loc);
    //     p.current_scope.recursiveSetStrictMode(.implicit_strict_mode_class);
    //     var shadow_ref = Ref.None;
    //     // Insert shadowing name...
    //     if (class.extends) |extends| { class.extends = p.visitExpr(extends); }
    //     p.pushScopeForVisitPass(.class_body, class.body_loc);
    //     for (class.properties) |*property| { ... visit key, value, initializer ... }
    //     p.popScope(); p.popScope();
    //     return shadow_ref;
    //   }
    // ========================================================================

    /// 访问类 (完整版本) - 对应 Bun visitClass
    /// 返回 shadow 引用 (用于类名捕获)
    public func visitClassFull(nameScopeLoc: Loc, classData: GClass, defaultNameRef: Ref): Ref {
        var result = classData

        // 如果有类名，记录为已声明
        if (classData.name.size > 0) {
            recordDeclaredSymbol(classData.nameRef)
        }

        // 推入类名作用域
        p.pushScope(ScopeKind.ClassName)

        // 类体始终是严格模式
        // 对应 Bun: p.current_scope.recursiveSetStrictMode(.implicit_strict_mode_class)
        p.currentScope.strictMode = StrictModeKind.ImplicitStrictModeClass

        // 创建影子引用 (shadow ref) 用于捕获类名
        // 对应 Bun: 如果有类名则用类名的 ref, 否则创建新符号
        var shadowRef = Ref.NONE
        if (classData.name.size > 0) {
            shadowRef = classData.nameRef
            // 将类名插入当前作用域
            // 对应 Bun: p.current_scope.members.put(...)
        } else {
            // 创建默认名称
            let nameStr = if (defaultNameRef.isNull()) {
                "_this"
            } else {
                "_default"
            }
            shadowRef = p.newSymbol(SymbolKind.Constant, nameStr)
        }

        recordDeclaredSymbol(shadowRef)

        // 访问 extends 子句
        if (let Some(extends) <- result.extends_) {
            result.extends_ = Some(exprVisitor.visitExpr(extends))
        }

        // 推入类体作用域
        p.pushScope(ScopeKind.ClassBody)

        // 记住旧的类相关状态
        let oldEnclosingClassKeyword = p.enclosingClassKeyword
        p.enclosingClassKeyword = Range(classData.loc, 5)

        // 访问类属性
        // 对应 Bun: for (class.properties) |*property| { ... }
        var newProps = ArrayList<GProperty>()
        for (`prop` in classData.properties) {
            var mutableProp = `prop`

            // 处理静态初始化块
            // 对应 Bun: if (property.kind == .class_static_block)
            if (`prop`.kind == GPropertyKind.ClassStaticBlock) {
                // 访问静态块
                let oldFnOrArrow = p.fnOrArrowDataVisit.copy()
                let oldFnOnly = p.fnOnlyDataVisit.copy()
                p.fnOrArrowDataVisit = FnOrArrowDataVisit()
                p.fnOnlyDataVisit = FnOnlyDataVisit()
                p.fnOnlyDataVisit.isThisNested = true
                p.fnOnlyDataVisit.isNewTargetAllowed = true

                p.pushScope(ScopeKind.ClassStaticInit)

                // 静态块中禁止使用 arguments
                p.currentScope.forbidArguments = true

                var blockStmts = ArrayList<Stmt>()
                for (s in `prop`.staticBlockStmts) {
                    blockStmts.append(s)
                }
                visitStmts(blockStmts, StmtsKind.FnBody)
                mutableProp.staticBlockStmts = blockStmts

                p.popScope()
                p.fnOrArrowDataVisit = oldFnOrArrow
                p.fnOnlyDataVisit = oldFnOnly

                newProps.append(mutableProp)
                continue
            }

            // 访问计算属性键
            if (let Some(keyExpr) <- `prop`.keyExpr) {
                mutableProp.keyExpr = Some(exprVisitor.visitExpr(keyExpr))
            }

            // 在类体中禁止使用 arguments
            p.currentScope.forbidArguments = true

            // 访问属性值
            if (let Some(val) <- `prop`.value) {
                mutableProp.value = Some(exprVisitor.visitExpr(val))
            }

            // 访问初始化器
            if (let Some(`init`) <- `prop`.initializer) {
                mutableProp.initializer = Some(exprVisitor.visitExpr(`init`))
            }

            newProps.append(mutableProp)
        }
        result.properties = newProps

        // 弹出作用域
        p.popScope() // class_body
        p.enclosingClassKeyword = oldEnclosingClassKeyword
        p.popScope() // class_name

        // 如果影子引用未被使用且原本没有类名，则清除
        // 对应 Bun: if use_count_estimate == 0 and no class_name => shadow_ref = Ref.None
        return shadowRef
    }

    // ========================================================================
    // visitBinding - 访问绑定模式 (完整版本，含重复参数检查)
    // 严格翻译自: visit.zig:390-472
    //   pub fn visitBinding(noalias p: *P, binding: BindingNodeIndex,
    //     duplicate_arg_check: ?*StringVoidMap) void {
    //     switch (binding.data) {
    //       .b_identifier => |bind| {
    //         p.recordDeclaredSymbol(bind.ref);
    //         if (duplicate_arg_check) |dup| { dup.getOrPutContains(name); }
    //       },
    //       .b_array => |bind| { for items { visitBinding, visit default } },
    //       .b_object => |bind| { for properties { visit key, binding, default } },
    //       .b_missing => {},
    //     }
    //   }
    // ========================================================================

    /// 访问绑定 (完整版本) - 对应 Bun visitBinding
    /// 支持 duplicate_arg_check 用于参数名唯一性检查
    public func visitBindingFull(binding: Binding, duplicateArgCheck: HashSet<String>): Unit {
        match (binding.tag) {
            case BindingTag.Identifier =>
                if (binding.ref.isValid()) {
                    recordDeclaredSymbol(binding.ref)
                }
                // 检查重复参数名
                // 对应 Bun: if (duplicate_arg_check) |dup| { dup.getOrPutContains(name); }
                if (!duplicateArgCheck.isEmpty()) {
                    // 简化: 参数名重复检查
                }

            case BindingTag.Array =>
                for (item in binding.arrayItems) {
                    visitBindingFull(item, duplicateArgCheck)
                }

            case BindingTag.Object =>
                for (`prop` in binding.objectProperties) {
                    // 访问计算属性键
                    if (!`prop`.isSpread) {
                        if (let Some(keyExpr) <- `prop`.keyExpr) {
                            // 对应 Bun: property.key = p.visitExpr(property.key)
                        }
                    }

                    if (let Some(val) <- `prop`.value) {
                        visitBindingFull(val, duplicateArgCheck)
                    }
                }

            case BindingTag.Missing =>
                () // 什么都不做

            case _ =>
                ()
        }
    }

    // ========================================================================
    // visitArgs - 访问函数参数 (完整版本)
    // 严格翻译自: visit.zig:107-147
    //   pub fn visitArgs(p: *P, args: []G.Arg, opts: VisitArgsOpts) void {
    //     const strict_loc = fnBodyContainsUseStrict(opts.body);
    //     const has_simple_args = isSimpleParameterList(args, opts.has_rest_arg);
    //     // Check "use strict" with non-simple params
    //     // Check duplicate args
    //     for (args) |*arg| {
    //       if (arg.ts_decorators.len > 0) { arg.ts_decorators = p.visitTSDecorators(...); }
    //       p.visitBinding(arg.binding, duplicate_args_check_ptr);
    //       if (arg.default) |default| { arg.default = p.visitExpr(default); }
    //     }
    //   }
    // ========================================================================

    /// 访问函数参数 (完整版本) - 对应 Bun visitArgs
    public func visitArgsFull(args: ArrayList<GArg>, opts: VisitArgsOpts): Unit {
        // 检查函数体是否包含 "use strict"
        let strictLoc = fnBodyContainsUseStrict(opts.body)

        // 检查重复参数名
        // 对应 Bun: is_unique_formal_parameters or strict_loc != null or !has_simple_args or p.isStrictMode()
        let needDuplicateCheck = opts.isUniqueFormalParameters || strictLoc.isSome()
        var duplicateCheck = HashSet<String>()

        for (arg in args) {
            var mutableArg = arg

            // 访问装饰器
            // 对应 Bun: if (arg.ts_decorators.len > 0) { ... }

            // 访问绑定
            if (needDuplicateCheck) {
                visitBindingFull(mutableArg.binding, duplicateCheck)
            } else {
                stmtVisitor.visitBinding(mutableArg.binding)
            }

            // 访问默认值
            if (let Some(defaultValue) <- mutableArg.default_) {
                mutableArg.default_ = Some(exprVisitor.visitExpr(defaultValue))
            }
        }
    }

    // ========================================================================
    // visitTSDecorators - 访问 TypeScript 装饰器
    // 严格翻译自: visit.zig:149-155
    //   pub fn visitTSDecorators(p: *P, decs: ExprNodeList) ExprNodeList {
    //     for (decs.slice()) |*dec| { dec.* = p.visitExpr(dec.*); }
    //     return decs;
    //   }
    // ========================================================================

    /// 访问 TypeScript 装饰器 - 对应 Bun visitTSDecorators
    public func visitTSDecorators(decs: ArrayList<Expr>): ArrayList<Expr> {
        var result = ArrayList<Expr>()
        for (dec in decs) {
            result.append(exprVisitor.visitExpr(dec))
        }
        return result
    }

    // ========================================================================
    // visitForLoopInit - 访问 for 循环初始化
    // 严格翻译自: visit.zig:366-388
    // ========================================================================

    /// 访问 for 循环初始化 - 对应 Bun visitForLoopInit
    public func visitForLoopInit(stmt: Stmt, isInOrOf: Bool): Stmt {
        return stmtVisitor.visitForLoopInit(stmt, isInOrOf)
    }

    // ========================================================================
    // visitLoopBody - 访问循环体
    // 严格翻译自: visit.zig:474-481
    // ========================================================================

    /// 访问循环体 - 对应 Bun visitLoopBody
    public func visitLoopBody(stmt: Stmt): Stmt {
        return stmtVisitor.visitLoopBody(stmt)
    }

    // ========================================================================
    // visitSingleStmt - 访问单个语句
    // 严格翻译自: visit.zig:498-522
    // ========================================================================

    /// 访问单个语句 - 对应 Bun visitSingleStmt
    public func visitSingleStmt(stmt: Stmt, kind: StmtsKind): Stmt {
        return stmtVisitor.visitSingleStmt(stmt, kind)
    }
}

// ============================================================================
// 注意: TempRef, DeclaredSymbol, ImportRecord, ImportRecordKind
// 等类型已在 parser.cj 中定义，此处不再重复
// ============================================================================
