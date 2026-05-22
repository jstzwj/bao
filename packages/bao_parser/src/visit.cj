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
    | None           // 普通上下文
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
        assignTarget = AssignTarget.None
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
    | None                              // 无标志
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
            case None => match (flag) { case None => true case _ => false }
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
        assignTarget = AssignTarget.None
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
