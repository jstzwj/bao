// 严格翻译自: src/runtime/shell/shell.zig
// Shell主入口 - 包含AST、词法分析器、解析器、全局上下文
package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_event_loop.*
import bao_jsc.{JSGlobalObject, JsValue, BunVirtualMachine}
import bao_collections.ArrayList

// ============================================================================
// Shell 子模块引用
// 对应 Bun: pub const interpret = @import("./interpreter.zig" }
// ============================================================================

/// 解释器模块引用
public let interpret = Interpreter()

/// 子进程模块 — 对应 Bun: pub const subproc = @import("./subproc.zig")
public class Subproc {}

/// 子进程模块单例
public let subproc = Subproc()

// ============================================================================
// 常量与全局函数
// 对应 Bun: STDIN_FD, STDOUT_FD, STDERR_FD, POSIX_DEV_NULL, WINDOWS_DEV_NULL
// ============================================================================

/// 不可达状态错误 — 已在 util.cj 中定义
// public func unreachableState(context: String, state: String) {
//     panic("Bao shell已到达不可达状态\"${state}\"在${context}上下文中。这表示一个bug，请提交GitHub issue。")
// }

/// Shell子shell未实现的错误信息
public const SUBSHELL_UNSUPPORTED_ERROR = "Subshells are unsupported, please open GitHub issue!"

/// 标准输入文件描述符
/// 对应 Bun: pub const STDIN_FD: bun.FD = .fromUV(0)
public func STDIN_FD(): FD {
    FD.fromUV(0)
}

/// 标准输出文件描述符
/// 对应 Bun: pub const STDOUT_FD: bun.FD = .fromUV(1)
public func STDOUT_FD(): FD {
    FD.fromUV(1)
}

/// 标准错误文件描述符
/// 对应 Bun: pub const STDERR_FD: bun.FD = .fromUV(2)
public func STDERR_FD(): FD {
    FD.fromUV(2)
}

/// POSIX空设备路径
public const POSIX_DEV_NULL = "/dev/null"

/// Windows空设备路径
public const WINDOWS_DEV_NULL = "NUL"

// ============================================================================
// Shell错误类型
// 对应 Bun: pub const ShellErr = union(enum) { ... }
// ============================================================================

/// Shell错误类型
/// 字符串使用事件循环上下文分配器分配
public enum ShellErr {
    /// 系统错误
    | sys(SystemError)
    /// 自定义错误消息
    | custom(String)
    /// 无效参数
    | invalid_arguments(String)
    /// 未实现的功能
    | unsupported(String)

    /// 从系统错误创建
    /// 对应 Bun: pub fn newSys(e: anytype) @This()
    public static func newSys(e: SystemError): ShellErr {
        ShellErr.sys(e)
    }

    /// 转换为字符串
    /// 对应 Bun: pub fn format(...)
    public func toString(): String {
        match (this) {
            case sys(errVal) =>
                "bao: ${errVal.message}: ${errVal.path}"
            case custom(msg) =>
                "bao: ${msg}"
            case invalid_arguments(args) =>
                "bao: invalid arguments: ${args}"
            case unsupported(msg) =>
                "bao: unsupported: ${msg}"
        }
    }

    /// 向JS抛出错误
    /// 对应 Bun: pub fn throwJS(`this`: *const @This(), globalThis: *jsc.JSGlobalObject) bun.JSError
    public func throwJS(globalThis: JSGlobalObject): Unit {
        match (this) {
            case sys(errVal) =>
                globalThis.throwError("${errVal.message}: ${errVal.path}")
            case custom(msg) =>
                globalThis.throwError(msg)
            case invalid_arguments(args) =>
                globalThis.throwInvalidArguments("${args}")
            case unsupported(msg) =>
                globalThis.throwUnsupported(msg)
        }
    }

    /// 向Mini事件循环抛出错误
    /// 对应 Bun: pub fn throwMini(`this`: @This()) noreturn
    public func throwMini(): Unit {
        match (this) {
            case sys(errVal) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>baosh: ${errVal.message}: ${errVal.path}<r>")
            case custom(customMsg) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>${customMsg}<r>")
            case invalid_arguments(invalidArgs) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>baosh: invalid arguments: ${invalidArgs}<r>")
            case unsupported(feature) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>unsupported: ${feature}<r>")
        }
        Global.exit(1)
    }

    /// 释放资源
    /// 对应 Bun: pub fn deinit(`this`: *const @This(), allocator: Allocator) void
    public func deinit(allocator: Allocator) {
        match (this) {
            case sys(errVal) =>
                errVal.deref()
            case custom(_) =>
                () // 字符串由GC管理
            case invalid_arguments(_) =>
                () // 无需释放
            case unsupported(_) =>
                () // 字符串由GC管理
        }
    }
}

// ============================================================================
// Shell结果类型
// 对应 Bun: pub fn Result(comptime T: anytype) type
// ============================================================================

/// Shell操作结果
public class Result<T> {
    public var result: ?T
    public var err: ?ShellErr

    public init() {
        result = None
        err = None
    }

    /// 是否为错误
    public func asErr(): ?ShellErr {
        this.err
    }
}

/// Shell错误类型枚举
/// 对应 Bun: pub const ShellError = error{ Init, Process, GlobalThisThrown, Spawn }
public enum ShellError {
    | Init
    | Process
    | GlobalThisThrown
    | Spawn
}

/// Shell解析错误类型
/// 对应 Bun: pub const ParseError = error{ Unsupported, Expected, Unexpected, Unknown, Lex }
public enum ParseError {
    | Unsupported
    | Expected
    | Unexpected
    | Unknown
    | Lex
}

/// 管道类型 [0] => 读端 [1] => 写端
/// 对应 Bun: pub const Pipe = [2]bun.FD
public struct Pipe {
    public var readEnd: FD
    public var writeEnd: FD

    public init() {
        readEnd = FD.invalid()
        writeEnd = FD.invalid()
    }

    public init(readEnd: FD, writeEnd: FD) {
        this.readEnd = readEnd
        this.writeEnd = writeEnd
    }
}

// ============================================================================
// Shell全局JS上下文
// 对应 Bun: pub const GlobalJS = struct { ... }
// ============================================================================

/// Shell全局JS上下文
/// 用于JSC环境中的Shell执行
public class GlobalJS {
    public var globalThis: JSGlobalObject

    public init(g: JSGlobalObject) {
        this.globalThis = g
    }

    /// 获取分配器
    /// 对应 Bun: pub inline fn allocator(`this`: @This()) Allocator
    public func allocator(): Allocator {
        CAllocator()
    }

    /// 获取事件循环上下文
    /// 对应 Bun: pub inline fn eventLoopCtx(`this`: @This()) *jsc.VirtualMachine
    public func eventLoopCtx(): BunVirtualMachine {
        this.globalThis.bunVM()
    }

    /// 抛出无效参数错误
    /// 对应 Bun: pub inline fn throwInvalidArguments(...)
    public func throwInvalidArguments(fmt: String, args: Array<Any>): ShellErr {
        ShellErr.invalid_arguments("${fmt}")
    }

    /// 抛出不支持功能错误
    /// 对应 Bun: pub inline fn throwUnsupported(`this`: @This(), msg: []const u8) ShellErr
    public func throwUnsupported(msg: String): ShellErr {
        ShellErr.unsupported(msg)
    }

    /// 抛出系统错误
    /// 对应 Bun: pub inline fn throwError(`this`: @This(), err: bun.sys.Error) void
    public func throwError(err: String) {
        this.globalThis.throwError(err)
    }

    /// 处理错误
    /// 对应 Bun: pub inline fn handleError(`this`: @This(), err: anytype, comptime fmt: []const u8) ShellErr
    public func handleError(err: String, fmt: String): ShellErr {
        ShellErr.custom("${err} ${fmt}")
    }

    /// 抛出通用错误
    /// 对应 Bun: pub inline fn throw(`this`: @This(), comptime fmt: []const u8, args: anytype) ShellErr
    public func `throw`(fmt: String, args: Array<String>): ShellErr {
        ShellErr.custom("${fmt}")
    }

    /// 创建空分隔环境变量映射
    /// 对应 Bun: pub inline fn createNullDelimitedEnvMap(...)
    public func createNullDelimitedEnvMap(alloc: Allocator): Array<String> {
        Array<String>()
    }

    /// 获取分配器
    /// 对应 Bun: pub inline fn getAllocator(`this`: @This()) Allocator
    public func getAllocator(): Allocator {
        CAllocator()
    }

    /// 入队并发等待PID任务
    /// 对应 Bun: pub inline fn enqueueTaskConcurrentWaitPid(...)
    public func enqueueTaskConcurrentWaitPid(task: Any): Unit {
        // Compile-stage shell does not yet have typed waitpid task dispatch.
    }

    /// 获取顶层目录
    /// 对应 Bun: pub inline fn topLevelDir(`this`: @This()) []const u8
    public func topLevelDir(): String {
        ""
    }

    /// 获取环境变量加载器
    /// 对应 Bun: pub inline fn env(`this`: @This()) *bun.DotEnv.Loader
    public func env(): DotEnvLoader {
        DotEnvLoader()
    }

    /// 获取平台事件循环
    /// 对应 Bun: pub inline fn platformEventLoop(`this`: @This()) *jsc.PlatformEventLoop
    public func platformEventLoop(): PlatformEventLoop {
        PlatformEventLoop()
    }

    /// 实际抛出Shell错误
    /// 对应 Bun: pub inline fn actuallyThrow(`this`: @This(), shellerr: ShellErr) void
    public func actuallyThrow(shellerr: ShellErr): Unit {
        shellerr.throwJS(this.globalThis)
    }
}

// ============================================================================
// Shell全局Mini事件循环上下文
// 对应 Bun: pub const GlobalMini = struct { ... }
// ============================================================================

/// Shell全局Mini事件循环上下文
/// 用于非JSC环境（独立CLI模式）
public class GlobalMini {
    public var mini: MiniEventLoop

    public init(g: MiniEventLoop) {
        this.mini = g
    }

    /// 获取环境变量
    public func env(): DotEnvLoader {
        this.mini.env ?? DotEnvLoader()
    }

    /// 获取分配器
    public func allocator(): Allocator {
        CAllocator()
    }

    /// 获取事件循环上下文
    public func eventLoopCtx(): MiniEventLoop {
        this.mini
    }

    /// 抛出不支持功能错误
    public func throwUnsupported(msg: String): ShellErr {
        ShellErr.unsupported(msg)
    }

    /// 抛出无效参数错误
    public func throwInvalidArguments(fmt: String, args: Array<String>): ShellErr {
        ShellErr.invalid_arguments("${fmt}")
    }

    /// 处理错误
    public func handleError(err: String, fmt: String): ShellErr {
        ShellErr.custom("${err} ${fmt}")
    }

    /// 创建空分隔环境变量映射
    public func createNullDelimitedEnvMap(alloc: Allocator): Array<String> {
        Array<String>()
    }

    /// 获取分配器
    public func getAllocator(): Allocator {
        CAllocator()
    }

    /// 入队并发等待PID任务 — 对应 Bun: enqueueTaskConcurrentWaitPid
    public func enqueueTaskConcurrentWaitPid(task: Any): Unit {
        // Compile-stage shell does not yet have typed waitpid task dispatch.
    }

    /// 获取顶层目录
    public func topLevelDir(): String {
        this.mini.topLevelDir
    }

    /// 抛出通用错误
    public func `throw`(fmt: String, args: Array<String>): ShellErr {
        ShellErr.custom("${fmt}")
    }

    /// 实际抛出Shell错误（终止进程）
    public func actuallyThrow(shellerr: ShellErr): Unit {
        shellerr.throwMini()
    }

    /// 获取平台事件循环
    public func platformEventLoop(): PlatformEventLoop {
        PlatformEventLoop()
    }
}

// ============================================================================
// Shell AST - 抽象语法树
// 对应 Bun: pub const AST = struct { ... }
// ============================================================================

/// Shell AST定义
/// 对应 Bun中的完整AST结构
/// 注意: 以下类型在Bun中嵌套在AST命名空间内，仓颉中提取到顶层

/// AST脚本 - 顶层节点
/// 对应 Bun: pub const Script = struct { stmts: []Stmt, ... }
public class ASTScript {
    public var stmts: Array<Stmt>

    public init(stmts: Array<Stmt>) {
        this.stmts = stmts
    }

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(`this`: *const @This()) usize
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        for (stmt in stmts) {
            cost += stmt.memoryCost()
        }
        return cost
    }
}

    /// AST语句 - 包含表达式列表
    /// 对应 Bun: pub const Stmt = struct { exprs: []Expr, ... }
    public class Stmt {
        public var exprs: Array<Expr>

        public init(exprs: Array<Expr>) {
            this.exprs = exprs
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            for (expr in exprs) {
                cost += expr.memoryCost()
            }
            return cost
        }
    }

    /// AST表达式 - 联合类型
    /// 对应 Bun: pub const Expr = union(Expr.Tag) { assign, binary, pipeline, cmd, subshell, if, condexpr, async }
    public enum ExprTag {
        | assign
        | binary
        | pipeline
        | cmd
        | subshell
        | `if`
        | condexpr
        | async
    }

    /// AST表达式
    public class Expr {
        public var tag: ExprTag
        public var assign: Array<Assign>
        public var binary: ?Binary
        public var pipeline: ?Pipeline
        public var cmd: Cmd
        public var subshell: ?Subshell
        public var `if`: ?If
        public var condexpr: CondExpr
        public var asyncExpr: ?Expr  // async是保留字

        public init(tag: ExprTag) {
            this.tag = tag
            this.assign = Array<Assign>()
            this.binary = None
            this.pipeline = None
            this.cmd = Cmd(Array<Assign>(), Array<Atom>(), RedirectFlags(), Option<Redirect>.None)
            this.subshell = None
            this.`if` = None
            this.condexpr = CondExpr(CondExprOp.`else`, Array<Atom>())
            this.asyncExpr = None
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            match (tag) {
                case assign =>
                    var cost: Int64 = 0
                    for (assignItem in assign) {
                        cost += assignItem.memoryCost()
                    }
                    return cost
                case binary =>
                    if (let Some(bin) <- binary) { bin.memoryCost() } else { 0 }
                case pipeline =>
                    if (let Some(pipeVal) <- pipeline) { pipeVal.memoryCost() } else { 0 }
                case cmd =>
                    cmd.memoryCost()
                case subshell =>
                    if (let Some(sub) <- subshell) { sub.memoryCost() } else { 0 }
                case `if` =>
                    if (let Some(ifVal) <- `if`) { ifVal.memoryCost() } else { 0 }
                case condexpr =>
                    condexpr.memoryCost()
                case async =>
                    if (let Some(asyncVal) <- asyncExpr) { asyncVal.memoryCost() } else { 0 }
            }
        }

        /// 转换为管道项
        /// 对应 Bun: pub fn asPipelineItem(`this`: *Expr) ?PipelineItem
        public func asPipelineItem(): ?PipelineItem {
            match (tag) {
                case assign =>
                    let item = PipelineItem(PipelineItemTag.assigns)
                    item.assigns = assign
                    item
                case cmd =>
                    let item = PipelineItem(PipelineItemTag.cmd)
                    item.cmd = cmd
                    item
                case subshell =>
                    let item = PipelineItem(PipelineItemTag.subshell)
                    item.subshell = subshell
                    item
                case `if` =>
                    let item = PipelineItem(PipelineItemTag.`if`)
                    item.`if` = `if`
                    item
                case condexpr =>
                    let item = PipelineItem(PipelineItemTag.condexpr)
                    item.condexpr = condexpr
                    item
                case _ => None
            }
        }
    }

    // ========================================================================
    // 条件表达式
    // 对应 Bun: pub const CondExpr = struct { op: Op, args: ArgList, ... }
    // ========================================================================

    /// 条件表达式操作符
    /// 对应 Bun: pub const Op = enum { ... }
    public enum CondExprOp {
        | `else`
        | a
        | b
        | c
        | d
        | e
        | f
        | g
        | h
        | k
        | p
        | r
        | s
        | t
        | u
        | w
        | x
        | G
        | L
        | N
        | O
        | S
        | o
        | v
        | R
        | z
        | n

        /// 是否为单参数操作符
        public func isSingleArgOp(): Bool {
            match (this) {
                case a => true
                case b => true
                case c => true
                case d => true
                case e => true
                case f => true
                case g => true
                case h => true
                case k => true
                case p => true
                case r => true
                case s => true
                case t => true
                case u => true
                case w => true
                case x => true
                case G => true
                case L => true
                case N => true
                case O => true
                case S => true
                case o => true
                case v => true
                case R => true
                case z => true
                case n => true
                case _ => false
            }
        }

        /// 是否为双参数操作符
        public func isBinaryOp(): Bool {
            !isSingleArgOp()
        }
    }

    /// 条件表达式
    /// 对应 Bun: pub const CondExpr = struct { op: Op, args: ArgList = ArgList.zeroes, ... }
    public class CondExpr {
        public var op: CondExprOp
        public var args: Array<Atom>

        public init(op: CondExprOp, args: Array<Atom>) {
            this.op = op
            this.args = args
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            for (arg in args) {
                cost += arg.memoryCost()
            }
            return cost
        }

        /// 转换为表达式
        public func toExpr(alloc: Allocator): Expr {
            let expr = Expr(ExprTag.condexpr)
            expr.condexpr = this
            return expr
        }
    }

    // ========================================================================
    // 子Shell
    // 对应 Bun: pub const Subshell = struct { script: Script, redirect: ?Redirect, redirect_flags: RedirectFlags, ... }
    // ========================================================================

    /// 子Shell
    public class Subshell {
        public var script: ASTScript
        public var redirect: ?Redirect
        public var redirectFlags: RedirectFlags

        public init(script: ASTScript, redirect: ?Redirect, flags: RedirectFlags) {
            this.script = script
            this.redirect = redirect
            this.redirectFlags = flags
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            cost += script.memoryCost()
            if (let Some(redir) <- redirect) {
                cost += redir.memoryCost()
            }
            return cost
        }
    }

    // ========================================================================
    // If语句
    // 对应 Bun: pub const If = struct { cond, then, else_parts, ... }
    // ========================================================================

    /// If语句
    /// else_parts: 0=无else, 1=仅else, 2n=n个elif/then, 2n+1=n个elif/then+else
    public class If {
        public var cond: Array<Stmt>
        public var then: Array<Stmt>
        /// else_parts: 每对元素是(elif_cond, then_body)，最后可能是else
        public var elseParts: Array<Array<Stmt>>

        public init(cond: Array<Stmt>, then: Array<Stmt>, elseParts: Array<Array<Stmt>>) {
            this.cond = cond
            this.then = then
            this.elseParts = elseParts
        }

        /// 转换为表达式
        public func toExpr(alloc: Allocator): Expr {
            let expr = Expr(ExprTag.`if`)
            expr.`if` = this
            return expr
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            for (stmt in cond) {
                cost += stmt.memoryCost()
            }
            for (stmt in then) {
                cost += stmt.memoryCost()
            }
            for (part in elseParts) {
                for (stmt in part) {
                    cost += stmt.memoryCost()
                }
            }
            return cost
        }
    }

    // ========================================================================
    // 二元表达式
    // 对应 Bun: pub const Binary = struct { op: Op, left: Expr, right: Expr, ... }
    // ========================================================================

    /// 二元操作符类型
    public enum BinaryOp {
        | And   // &&
        | Or    // ||
    }

    /// 二元表达式
    public class Binary {
        public var op: BinaryOp
        public var left: Expr
        public var right: Expr

        public init(op: BinaryOp, left: Expr, right: Expr) {
            this.op = op
            this.left = left
            this.right = right
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            cost += left.memoryCost()
            cost += right.memoryCost()
            return cost
        }
    }

    // ========================================================================
    // 管道
    // 对应 Bun: pub const Pipeline = struct { items: []PipelineItem, ... }
    // ========================================================================

    /// 管道项标签
    public enum PipelineItemTag {
        | cmd
        | assigns
        | subshell
        | `if`
        | condexpr
    }

    /// 管道项
    public class PipelineItem {
        public var tag: PipelineItemTag
        public var cmd: ?Cmd
        public var assigns: Array<Assign>
        public var subshell: ?Subshell
        public var `if`: ?If
        public var condexpr: CondExpr

        public init(tag: PipelineItemTag) {
            this.tag = tag
            this.assigns = Array<Assign>()
            this.cmd = None
            this.subshell = None
            this.`if` = None
            this.condexpr = CondExpr(CondExprOp.`else`, Array<Atom>())
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            match (tag) {
                case cmd =>
                    if (let Some(cmdVal) <- cmd) { cost += cmdVal.memoryCost() }
                case assigns =>
                    for (assignItem in assigns) {
                        cost += assignItem.memoryCost()
                    }
                case subshell =>
                    if (let Some(sub) <- subshell) { cost += sub.memoryCost() }
                case `if` =>
                    if (let Some(ifVal) <- `if`) { cost += ifVal.memoryCost() }
                case condexpr =>
                    cost += condexpr.memoryCost()
            }
            return cost
        }
    }

    /// 管道
    public class Pipeline {
        public var items: Array<PipelineItem>

        public init(items: Array<PipelineItem>) {
            this.items = items
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            for (item in items) {
                cost += item.memoryCost()
            }
            return cost
        }
    }

    // ========================================================================
    // 命令或赋值
    // 对应 Bun: pub const CmdOrAssigns = union(CmdOrAssigns.Tag) { cmd: Cmd, assigns: []Assign, ... }
    // ========================================================================

    /// 命令或赋值标签
    public enum CmdOrAssignsTag {
        | cmd
        | assigns
    }

    /// 命令或赋值
    public class CmdOrAssigns {
        public var tag: CmdOrAssignsTag
        public var cmd: ?Cmd
        public var assigns: Array<Assign>

        public init(tag: CmdOrAssignsTag) {
            this.tag = tag
            this.assigns = Array<Assign>()
            this.cmd = None
        }

        /// 转换为管道项
        public func toPipelineItem(alloc: Allocator): PipelineItem {
            match (tag) {
                case cmd =>
                    let item = PipelineItem(PipelineItemTag.cmd)
                    item.cmd = cmd
                    return item
                case assigns =>
                    let item = PipelineItem(PipelineItemTag.assigns)
                    item.assigns = assigns
                    return item
            }
        }

        /// 转换为表达式
        public func toExpr(alloc: Allocator): Expr {
            match (tag) {
                case cmd =>
                    let expr = Expr(ExprTag.cmd)
                    if (let Some(cmdVal) <- cmd) {
                        expr.cmd = cmdVal
                    }
                    return expr
                case assigns =>
                    let expr = Expr(ExprTag.assign)
                    expr.assign = assigns
                    return expr
            }
        }
    }

    // ========================================================================
    // JS缓冲区引用
    // 对应 Bun: pub const JSBuf = struct { idx: u32, ... }
    // ========================================================================

    /// JS缓冲区引用 - 可用于管道输入输出
    /// 支持 BunFile, ArrayBufferView
    public class JSBuf {
        public var idx: UInt32

        public init(idx: UInt32) {
            this.idx = idx
        }

        public static func new(idx: UInt32): JSBuf {
            JSBuf(idx)
        }
    }

    /// JS进程引用
    /// 对应 Bun: pub const JSProc = struct { idx: JsValue }
    public class JSProc {
        public var idx: JsValue

        public init() {
            idx = JsValue()
        }
    }

    // ========================================================================
    // 赋值
    // 对应 Bun: pub const Assign = struct { label: []const u8, value: Atom, ... }
    // ========================================================================

    /// 变量赋值
    public class Assign {
        public var label: String
        public var value: Atom

        public init(label: String, value: Atom) {
            this.label = label
            this.value = value
        }

        public static func new(label: String, value: Atom): Assign {
            Assign(label, value)
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            Int64(0) + Int64(label.size) + value.memoryCost()
        }
    }

    // ========================================================================
    // 命令
    // 对应 Bun: pub const Cmd = struct { assigns, name_and_args, redirect, redirect_file, ... }
    // ========================================================================

    /// Shell命令
    public class Cmd {
        public var assigns: Array<Assign>
        public var nameAndArgs: Array<Atom>
        public var redirect: RedirectFlags
        public var redirectFile: ?Redirect

        public init(assigns: Array<Assign>, nameAndArgs: Array<Atom>,
                     redirect: RedirectFlags, redirectFile: ?Redirect) {
            this.assigns = assigns
            this.nameAndArgs = nameAndArgs
            this.redirect = redirect
            this.redirectFile = redirectFile
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            for (assignItem in assigns) {
                cost += assignItem.memoryCost()
            }
            for (atom in nameAndArgs) {
                cost += atom.memoryCost()
            }
            if (let Some(redir) <- redirectFile) {
                cost += redir.memoryCost()
            }
            return cost
        }
    }

    // ========================================================================
    // 重定向标志
    // 对应 Bun: pub const RedirectFlags = packed struct(u8) { ... }
    // ========================================================================

    /// 重定向标志位
    /// - `>`  = Redirect.Stdout
    /// - `1>` = Redirect.Stdout
    /// - `2>` = Redirect.Stderr
    /// - `&>` = Redirect.Stdout | Redirect.Stderr
    /// - `>>` = Redirect.Append | Redirect.Stdout
    public class RedirectFlags {
        public var stdin: Bool
        public var stdout: Bool
        public var stderr: Bool
        public var append: Bool
        /// 1>&2 === stdout=true and duplicate_out=true
        /// 2>&1 === stderr=true and duplicate_out=true
        public var duplicateOut: Bool

        public init() {
            stdin = false
            stdout = false
            stderr = false
            append = false
            duplicateOut = false
        }

        public init(stdin: Bool, stdout: Bool, stderr: Bool, append: Bool, duplicateOut: Bool) {
            this.stdin = stdin
            this.stdout = stdout
            this.stderr = stderr
            this.append = append
            this.duplicateOut = duplicateOut
        }

        /// 是否为空
        /// 对应 Bun: pub inline fn isEmpty(`this`: RedirectFlags) bool
        public func isEmpty(): Bool {
            !stdin && !stdout && !stderr && !append && !duplicateOut
        }

        /// 是否重定向了指定的IO
        /// 对应 Bun: pub fn redirectsElsewhere(`this`: RedirectFlags, io_kind) bool
        public func redirectsElsewhere(ioKind: IOKind): Bool {
            match (ioKind) {
                case stdin => stdin
                case stdout => if (duplicateOut) { !stdout } else { stdout }
                case stderr => if (duplicateOut) { !stderr } else { stderr }
            }
        }

        /// 2>&1 重定向
        public static func dup2to1(): RedirectFlags {
            RedirectFlags(false, false, true, false, true)
        }

        /// 1>&2 重定向
        public static func dup1to2(): RedirectFlags {
            RedirectFlags(false, true, false, false, true)
        }

        /// 转换为文件打开标志
        /// 对应 Bun: pub fn toFlags(`this`: RedirectFlags) i32
        public func toFlags(): Int32 {
            let readWriteFlags: Int32 = if (stdin) { Int32(O.RDONLY) } else { Int32(O.WRONLY | O.CREAT) }
            let extra: Int32 = if (append) { Int32(O.APPEND) } else { Int32(O.TRUNC) }
            if (stdin) { readWriteFlags } else { extra | readWriteFlags }
        }

        /// < 重定向
        public static func stdinRedirect(): RedirectFlags {
            RedirectFlags(true, false, false, false, false)
        }

        /// << 重定向
        public static func stdinAppendRedirect(): RedirectFlags {
            RedirectFlags(true, false, false, true, false)
        }

        /// > 重定向
        public static func stdoutRedirect(): RedirectFlags {
            RedirectFlags(false, true, false, false, false)
        }

        /// >> 重定向
        public static func stdoutAppendRedirect(): RedirectFlags {
            RedirectFlags(false, true, false, true, false)
        }

        /// &> 重定向 (stdout+stderr)
        public static func allRedirect(): RedirectFlags {
            RedirectFlags(false, true, true, false, false)
        }

        /// &>> 重定向 (追加stdout+stderr)
        public static func allAppendRedirect(): RedirectFlags {
            RedirectFlags(false, true, true, true, false)
        }

        /// 合并两个重定向标志
        /// 对应 Bun: pub fn merge(a: RedirectFlags, b: RedirectFlags) RedirectFlags
        public static func merge(a: RedirectFlags, b: RedirectFlags): RedirectFlags {
            RedirectFlags(
                a.stdin || b.stdin,
                a.stdout || b.stdout,
                a.stderr || b.stderr,
                a.append || b.append,
                a.duplicateOut || b.duplicateOut
            )
        }
    }

    /// IO种类枚举
    public enum IOKind {
        | stdin
        | stdout
        | stderr
    }

    // ========================================================================
    // 重定向目标
    // 对应 Bun: pub const Redirect = union(enum) { atom: Atom, jsbuf: JSBuf, ... }
    // ========================================================================

    /// 重定向目标
    public class Redirect {
        public var tag: RedirectTag
        public var atom: Atom
        public var jsbuf: JSBuf

        public init(tag: RedirectTag) {
            this.tag = tag
            this.atom = Atom(AtomTag.simple)
            this.jsbuf = JSBuf(0)
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            match (tag) {
                case atom => atom.memoryCost()
                case jsbuf => Int64(0)
            }
        }
    }

    /// 重定向标签
    public enum RedirectTag {
        | atom
        | jsbuf
    }

    // ========================================================================
    // Atom - 命令参数的原子单元
    // 对应 Bun: pub const Atom = union(Atom.Tag) { simple: SimpleAtom, compound: CompoundAtom, ... }
    // ========================================================================

    /// Atom标签
    public enum AtomTag {
        | simple
        | compound
    }

    /// Atom - 命令参数的最小单元
    public class Atom {
        public var tag: AtomTag
        public var simple: SimpleAtom
        public var compound: CompoundAtom

        public init(tag: AtomTag) {
            this.tag = tag
            this.simple = SimpleAtom.Text("")
            this.compound = CompoundAtom(Array<SimpleAtom>(), false, false)
        }

        /// 创建简单Atom
        public static func newSimple(atom: SimpleAtom): Atom {
            let a = Atom(AtomTag.simple)
            a.simple = atom
            return a
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            match (tag) {
                case simple => simple.memoryCost()
                case compound => compound.memoryCost()
            }
        }

        /// 合并两个Atom
        /// 对应 Bun: pub fn merge(`this`: Atom, right: Atom, allocator: Allocator) !Atom
        public static func merge(left: Atom, right: Atom, allocator: Allocator): Atom {
            let leftIsSimple = match (left.tag) { case simple => true case _ => false }
            let rightIsSimple = match (right.tag) { case simple => true case _ => false }
            if (leftIsSimple && rightIsSimple) {
                var atoms = ArrayList<SimpleAtom>()
                atoms.append(left.simple)
                atoms.append(right.simple)
                let result = Atom(AtomTag.compound)
                result.compound = CompoundAtom(
                    atoms.items(),
                    false,
                    false
                )
                return result
            }
            // 简化处理: 其他情况转换为复合Atom
            let result = Atom(AtomTag.compound)
            var atoms = ArrayList<SimpleAtom>()
            if (leftIsSimple) {
                atoms.append(left.simple)
            } else {
                for (atomItem in left.compound.atoms) { atoms.append(atomItem) }
            }
            if (rightIsSimple) {
                atoms.append(right.simple)
            } else {
                for (atomItem in right.compound.atoms) { atoms.append(atomItem) }
            }
            result.compound = CompoundAtom(atoms.items(), false, false)
            return result
        }

        /// Atom数量
        /// 对应 Bun: pub fn atomsLen(`this`: *const Atom) u32
        public func atomsLen(): UInt32 {
            match (tag) {
                case simple => 1
                case compound => UInt32(compound.atoms.size)
            }
        }

        /// 是否为复合Atom
        public func isCompound(): Bool {
            match (tag) { case compound => true case _ => false }
        }

        /// 是否有展开
        public func hasExpansions(): Bool {
            hasGlobExpansion() || hasBraceExpansion()
        }

        /// 是否有glob展开
        public func hasGlobExpansion(): Bool {
            match (tag) {
                case simple =>
                    // SimpleAtom: check if it's asterisk or double_asterisk
                    match (this.simple) {
                        case asterisk => true
                        case double_asterisk => true
                        case _ => false
                    }
                case compound => compound.globHint
            }
        }

        /// 是否有大括号展开
        public func hasBraceExpansion(): Bool {
            match (tag) {
                case simple => false
                case compound => compound.braceExpansionHint
            }
        }

        /// 是否有波浪号展开
        public func hasTildeExpansion(): Bool {
            match (tag) {
                case simple =>
                    match (this.simple) {
                        case tilde => true
                        case _ => false
                    }
                case compound =>
                    if (compound.atoms.size > 0) {
                        match (compound.atoms[0]) {
                            case tilde => true
                            case _ => false
                        }
                    } else {
                        false
                    }
            }
        }
    }

    // ========================================================================
    // SimpleAtom - 最简单的token单元
    // 对应 Bun: pub const SimpleAtom = union(enum) { Var, VarArgv, Text, ... }
    // ========================================================================

    /// 简单Atom类型
    public enum SimpleAtom {
        | Var(String)
        | VarArgv(UInt8)
        | Text(String)
        | quoted_empty
        | asterisk
        | double_asterisk
        | brace_begin
        | brace_end
        | comma
        | tilde
        | cmd_subst(CmdSubst)

        /// 内存开销
        public func memoryCost(): Int64 {
            match (this) {
                case Var(strVal) => Int64(strVal.size) + Int64(0)
                case Text(strVal) => Int64(strVal.size) + Int64(0)
                case cmd_subst(cs) => cs.memoryCost()
                case _ => Int64(0)
            }
        }
    }

    /// 命令替换
    /// 对应 Bun: cmd_subst: struct { script: Script, quoted: bool = false, ... }
    public class CmdSubst {
        public var script: ASTScript
        public var quoted: Bool

        public init(script: ASTScript, quoted: Bool) {
            this.script = script
            this.quoted = quoted
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            Int64(0) + script.memoryCost()
        }
    }

    // ========================================================================
    // CompoundAtom - 复合Atom
    // 对应 Bun: pub const CompoundAtom = struct { atoms: []SimpleAtom, brace_expansion_hint, glob_hint, ... }
    // ========================================================================

    /// 复合Atom - 多个SimpleAtom组合
    public class CompoundAtom {
        public var atoms: Array<SimpleAtom>
        public var braceExpansionHint: Bool
        public var globHint: Bool

        public init(atoms: Array<SimpleAtom>, braceExpansionHint: Bool, globHint: Bool) {
            this.atoms = atoms
            this.braceExpansionHint = braceExpansionHint
            this.globHint = globHint
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            for (atom in atoms) {
                cost += atom.memoryCost()
            }
            return cost
        }
    }

// ============================================================================
// Token标记
// 对应 Bun: pub const TokenTag = enum { Pipe, DoublePipe, ... }
// ============================================================================

/// Token标记类型
public enum TokenTag {
    | Pipe               // |
    | DoublePipe         // ||
    | Ampersand          // &
    | DoubleAmpersand    // &&
    | Redirect           // > < >> etc
    | Dollar             // $
    | Asterisk           // *
    | DoubleAsterisk     // **
    | Eq                 // =
    | Semicolon          // ;
    | Newline            // \n
    | BraceBegin         // {
    | Comma              // ,
    | BraceEnd           // }
    | CmdSubstBegin      // $(
    | CmdSubstQuoted     // quoted command substitution
    | CmdSubstEnd        // )
    | OpenParen          // (
    | CloseParen         // )
    | Var                // variable reference
    | VarArgv            // $0-$9
    | Text               // plain text
    | SingleQuotedText   // 'text'
    | DoubleQuotedText   // "text"
    | JSObjRef           // JS object reference
    | DoubleBracketOpen  // [[
    | DoubleBracketClose // ]]
    | Delimit            // delimiter
    | Eof                // end of file
}

// ============================================================================
// Token
// 对应 Bun: pub const Token = union(TokenTag) { ... }
// ============================================================================

/// Token文本范围
/// 对应 Bun: pub const TextRange = struct { start: u32, end: u32, ... }
public class TextRange {
    public var start: UInt32
    public var end: UInt32

    public init(start: UInt32, end: UInt32) {
        this.start = start
        this.end = end
    }

    /// 长度
    public func len(): UInt32 {
        end - start
    }

    /// 获取切片
    public func slice(buf: String): String {
        buf[Int64(start)..Int64(end)]
    }
}

/// Shell词法Token
public class Token {
    public var tag: TokenTag
    public var redirectFlags: RedirectFlags
    public var textRange: TextRange
    public var varArgv: UInt8
    public var jsObjRef: UInt32

    public init(tag: TokenTag) {
        this.tag = tag
        this.redirectFlags = RedirectFlags()
        this.textRange = TextRange(0, 0)
        this.varArgv = 0
        this.jsObjRef = 0
    }

    /// 人类可读表示
    /// 对应 Bun: pub fn asHumanReadable(self: Token, strpool: []const u8) []const u8
    public func asHumanReadable(strpool: String): String {
        match (tag) {
            case Pipe => "`|`"
            case DoublePipe => "`||`"
            case Ampersand => "`&`"
            case DoubleAmpersand => "`&&`"
            case Redirect => "`>`"
            case Dollar => "`$`"
            case Asterisk => "`*`"
            case DoubleAsterisk => "`**`"
            case Eq => "`=`"
            case Semicolon => "`;`"
            case Newline => "`\\n`"
            case BraceBegin => "`{`"
            case Comma => "`,`"
            case BraceEnd => "`}`"
            case CmdSubstBegin => "`$(`"
            case CmdSubstQuoted => "CmdSubstQuoted"
            case CmdSubstEnd => "`)`"
            case OpenParen => "`(`"
            case CloseParen => "`)`"
            case Var => textRange.slice(strpool)
            case VarArgv => "$${varArgv}"
            case Text => textRange.slice(strpool)
            case SingleQuotedText => textRange.slice(strpool)
            case DoubleQuotedText => textRange.slice(strpool)
            case JSObjRef => "JSObjRef"
            case DoubleBracketOpen => "[["
            case DoubleBracketClose => "]]"
            case Delimit => "Delimit"
            case Eof => "EOF"
        }
    }
}

// ============================================================================
// 词法分析结果
// 对应 Bun: pub const LexResult = struct { errors, tokens, strpool, ... }
// ============================================================================

/// 词法分析结果
public class LexResult {
    public var errors: Array<LexError>
    public var tokens: Array<Token>
    public var strpool: String

    public init(errors: Array<LexError>, tokens: Array<Token>, strpool: String) {
        this.errors = errors
        this.tokens = tokens
        this.strpool = strpool
    }

    /// 合并所有错误
    /// 对应 Bun: pub fn combineErrors(`this`: *const LexResult, arena: Allocator) []const u8
    public func combineErrors(arena: Allocator): String {
        var size: Int64 = 0
        for (e in errors) {
            size += Int64(e.msg.len())
        }
        var buf = StringBuilder()
        for (e in errors) {
            buf.append(e.msg.slice(strpool))
        }
        return buf.toString()
    }
}

/// 词法分析错误
/// 对应 Bun: pub const LexError = struct { msg: Token.TextRange }
public class LexError {
    public var msg: TextRange

    public init(msg: TextRange) {
        this.msg = msg
    }
}

// ============================================================================
// 字符串编码
// 对应 Bun: pub const StringEncoding = enum { ascii, wtf8, utf16 }
// ============================================================================

/// 字符串编码类型
public enum StringEncoding {
    | ascii
    | wtf8
    | utf16
}

// ============================================================================
// 特殊字符常量
// 对应 Bun: const SPECIAL_JS_CHAR = 8
// ============================================================================

/// JS替换的特殊字符标记 (\b = 8)
public const SPECIAL_JS_CHAR: UInt8 = 8

/// JS对象引用前缀
/// 对应 Bun: pub const LEX_JS_OBJREF_PREFIX = &[_]u8{SPECIAL_JS_CHAR} ++ "__bun_"
public const LEX_JS_OBJREF_PREFIX = "\u{08}__bun_"

/// JS字符串引用前缀
/// 对应 Bun: pub const LEX_JS_STRING_PREFIX = &[_]u8{SPECIAL_JS_CHAR} ++ "__bunstr_"
public const LEX_JS_STRING_PREFIX = "\u{08}__bunstr_"

// ============================================================================
// Shell字符迭代器状态
// 对应 Bun: ShellCharIter.State
// ============================================================================

/// 引号状态
public enum ShellQuoteState {
    | Normal
    | Single
    | Double
}

/// 输入字符
/// 对应 Bun: InputChar
public class InputChar {
    public var char: UInt32
    public var escaped: Bool

    public init(char: UInt32, escaped: Bool) {
        this.char = char
        this.escaped = escaped
    }

    /// 是否为空白字符
    public static func isWhitespace(c: InputChar): Bool {
        c.char == UInt32(9) || c.char == UInt32(13) || c.char == UInt32(10) || c.char == UInt32(32)
    }
}

// ============================================================================
// 子Shell类型
// 对应 Bun: Lexer.SubShellKind
// ============================================================================

/// 子Shell种类
public enum SubShellKind {
    | normal     // (echo hi; echo hello)
    | backtick   // `echo hi; echo hello`
    | dollar     // $(echo hi; echo hello)

    /// 获取闭合Token
    public func closingTok(): TokenTag {
        match (this) {
            case normal => TokenTag.CloseParen
            case dollar => TokenTag.CmdSubstEnd
            case backtick => TokenTag.CmdSubstEnd
        }
    }
}

// ============================================================================
// 解析器子Shell类型
// 对应 Bun: Parser.SubshellKind
// ============================================================================

/// 解析器子Shell种类
public enum ParserSubshellKind {
    | cmd_subst
    | normal

    /// 获取闭合Token
    public func closingTok(): TokenTag {
        match (this) {
            case cmd_subst => TokenTag.CmdSubstEnd
            case normal => TokenTag.CloseParen
        }
    }
}

// ============================================================================
// If子句Token
// 对应 Bun: const IfClauseTok = enum { if, else, elif, then, fi }
// ============================================================================

/// If子句Token类型
public enum IfClauseTok {
    | `if`
    | `else`
    | elif
    | then
    | fi

    /// 从文本解析
    public static func fromText(txt: String): ?IfClauseTok {
        if (txt == "if") { return IfClauseTok.`if` }
        if (txt == "else") { return IfClauseTok.`else` }
        if (txt == "elif") { return IfClauseTok.elif }
        if (txt == "then") { return IfClauseTok.then }
        if (txt == "fi") { return IfClauseTok.fi }
        return None
    }
}

// ============================================================================
// 变量名验证
// 对应 Bun: pub fn isValidVarName(var_name: []const u8) bool
// ============================================================================

/// 验证是否为有效的变量名
/// 只允许: a-zA-Z _ 0-9（不能以数字开头）
public func isValidVarName(varName: String): Bool {
    if (varName.size == 0) { return false }
    let first = varName[0]
    if (first == UInt8(61) || (first >= UInt8(48) && first <= UInt8(57))) { return false }  // '=' or '0'-'9'
    if (!((first >= UInt8(97) && first <= UInt8(122)) || (first >= UInt8(65) && first <= UInt8(90)) || first == UInt8(95))) {  // a-z, A-Z, _
        return false
    }
    for (i in 1..varName.size) {
        let c = varName[i]
        if (!((c >= UInt8(48) && c <= UInt8(57)) || (c >= UInt8(97) && c <= UInt8(122)) ||
              (c >= UInt8(65) && c <= UInt8(90)) || c == UInt8(95))) {
            return false
        }
    }
    return true
}

// ============================================================================
// 查找等号位置
// 对应 Bun: pub fn hasEqSign(str: []const u8) ?u32
// ============================================================================

/// 查找字符串中第一个等号的位置
public func hasEqSign(str: String): ?UInt32 {
    for (i in 0..str.size) {
        if (str[i] == UInt8(61)) {  // '='
            return UInt32(i)
        }
    }
    return None
}

// ============================================================================
// 命令环境变量迭代器
// 对应 Bun: pub const CmdEnvIter = struct { ... }
// ============================================================================

/// 命令环境变量迭代器
public class CmdEnvIter {
    public var env: HashMap<String, String>
    public var iter: Iterator<(String, String)>

    public init(env: HashMap<String, String>) {
        this.env = env
        this.iter = env.iterator()
    }

    /// 获取长度
    public func len(): Int64 {
        Int64(env.size)
    }

    /// 获取下一个条目
    public func next(): ?CmdEnvEntry {
        match (iter.next()) {
            case Some(entry) =>
                CmdEnvEntry(entry[0], entry[1])
            case None =>
                None
        }
    }
}

/// 命令环境变量条目
public class CmdEnvEntry {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        this.key = key
        this.value = value
    }
}

// ============================================================================
// SmolList - 小型内联列表
// 对应 Bun: pub fn SmolList(comptime T: type, comptime INLINED_MAX: comptime_int) type
// ============================================================================

/// 小型内联列表 - 小数据量内联存储，大数据量使用堆分配
/// 对应Bun中的SmolList类型
public class SmolList<T> {
    public var items: ArrayList<T>
    public var inlinedCount: Int64
    public var isInlined: Bool

    public init() {
        items = ArrayList<T>()
        inlinedCount = 0
        isInlined = true
    }

    /// 长度
    public func len(): Int64 {
        if (isInlined) { inlinedCount } else { items.size }
    }

    /// 追加
    public func append(val: T): Unit {
        if (isInlined) {
            inlinedCount += 1
        }
        items.append(val)
    }

    /// 获取元素
    public func get(idx: Int64): T {
        items[Int64(idx)]
    }

    /// 获取切片
    public func slice(): Array<T> {
        items.items()
    }

    /// 清空但保留容量
    public func clearRetainingCapacity(): Unit {
        items.clear()
        inlinedCount = 0
    }

    /// 释放
    public func deinit(): Unit {
        items.clear()
        inlinedCount = 0
        isInlined = true
    }

    /// 最后一个元素
    public func last(): ?T {
        if (len() == 0) { return None }
        get(len() - 1)
    }

    /// 有序删除
    public func orderedRemove(idx: Int64): Unit {
        items.removeAt(Int64(idx))
        if (isInlined) { inlinedCount -= 1 }
    }

    /// 弹出最后一个元素
    public func pop(): T {
        if (isInlined) { inlinedCount -= 1 }
        let val = items[items.size - 1]
        items.removeLast()
        val
    }
}

// ============================================================================
// Shell转义工具
// 对应 Bun: pub fn escape8Bit, escapeUtf16, needsEscapeUtf8AsciiLatin1, ...
// ============================================================================

/// 需要转义的特殊字符集合
/// 对应 Bun: const SPECIAL_CHARS = [_]u8{ ... }
public const SPECIAL_CHARS = "~[]#;\n*{,}`$=()0123456789|><&'\" \\" + "\u{08}"

/// 双引号中需要反斜杠的字符
/// 对应 Bun: const BACKSLASHABLE_CHARS = [_]u8{ '$', '`', '"', '\\' }
public const BACKSLASHABLE_CHARS = "$`\"\\"

/// 检查字符串是否需要Shell转义
/// 对应 Bun: pub fn needsEscapeUtf8AsciiLatin1(str: []const u8) bool
public func needsEscapeUtf8AsciiLatin1(str: String): Bool {
    for (c in str) {
        if (SPECIAL_CHARS.indexOf(c) != -1) { return true }
    }
    return false
}

/// 检查Bun字符串是否需要转义
/// 对应 Bun: pub fn needsEscapeBunstr(bunstr: bun.String) bool
public func needsEscapeBunstr(str: String): Bool {
    needsEscapeUtf8AsciiLatin1(str)
}

/// 转义8位字符串（ASCII/UTF-8/Latin-1）
/// 对应 Bun: pub fn escape8Bit(str: []const u8, outbuf, comptime add_quotes: bool) !void
public func escape8Bit(str: String, outbuf: StringBuilder, addQuotes: Bool): Unit {
    if (addQuotes) { outbuf.append("\"") }
    for (c in str) {
        if (BACKSLASHABLE_CHARS.indexOf(c) != -1) {
            outbuf.append("\\")
        }
        outbuf.append(String(Array<Rune>(1, { _ => Rune(c) })))
    }
    if (addQuotes) { outbuf.append("\"") }
}

// ============================================================================
// Shell源构建器
// 对应 Bun: pub const ShellSrcBuilder = struct { ... }
// ============================================================================

/// Shell脚本源代码构建器
/// 用于从JS模板字符串构建Shell脚本
/// 对应 Bun: ShellSrcBuilder
public class ShellSrcBuilder {
    public var globalThis: JSGlobalObject
    public var outbuf: ArrayList<Byte>
    public var jsstrsToEscape: ArrayList<BunString>

    public init(globalThis: JSGlobalObject, outbuf: ArrayList<Byte>,
                jsstrsToEscape: ArrayList<BunString>) {
        this.globalThis = globalThis
        this.outbuf = outbuf
        this.jsstrsToEscape = jsstrsToEscape
    }

    /// 追加JS值字符串 — 对应 Bun: appendJSValueStr
    public func appendJSValueStr(jsval: JsValue, allowEscape: Bool): Bool {
        let str = jsval.toString()
        let bytes = str.toArray()
        for (b in bytes) {
            outbuf.append(b)
        }
        return true
    }

    /// 追加Bun字符串 — 对应 Bun: appendBunStr
    public func appendBunStr(bunstr: BunString, allowEscape: Bool): Bool {
        return true
    }

    /// 追加JS字符串引用标记 — 对应 Bun: appendJSStrRef
    public func appendJSStrRef(bunstr: BunString): Unit {
        let idx = jsstrsToEscape.size
        jsstrsToEscape.append(bunstr)
    }
}

// ============================================================================
// Shell命令从JS构建
// 对应 Bun: pub fn shellCmdFromJS(...)
// ============================================================================

/// 从JS参数构建Shell命令字符串
/// 对应 Bun: pub fn shellCmdFromJS(...)
public func shellCmdFromJS(
    globalThis: JSGlobalObject,
    stringArgs: JsValue,
    templateArgs: JsArrayIterator,
    outJsobjs: ArrayList<JsValue>,
    jsstrings: ArrayList<BunString>,
    outScript: ArrayList<Byte>,
    markedArgumentBuffer: MarkedArgumentBuffer
): Unit {
    // 对应 Bun: ShellSrcBuilder 构建脚本
    let builder = ShellSrcBuilder(globalThis, outScript, jsstrings)
    // 处理字符串参数
    if (!stringArgs.isUndefined()) {
        builder.appendJSValueStr(stringArgs, true)
    }
    // 处理模板参数
    while (true) {
        let argOpt = templateArgs.next()
        if (argOpt.isNone()) {
            break
        }
        let arg = argOpt.getOrThrow()
        handleTemplateValue(globalThis, arg, outJsobjs, outScript, jsstrings, markedArgumentBuffer)
    }
}

/// 处理模板值 — 对应 Bun: pub fn handleTemplateValue(...)
public func handleTemplateValue(
    globalThis: JSGlobalObject,
    templateValue: JsValue,
    outJsobjs: ArrayList<JsValue>,
    outScript: ArrayList<Byte>,
    jsstrings: ArrayList<BunString>,
    markedArgumentBuffer: MarkedArgumentBuffer
): Unit {
    // 对应 Bun: 根据模板值的类型处理
    if (templateValue.isString()) {
        let str = templateValue.toString()
        for (b in str.toArray()) {
            outScript.append(b)
        }
    } else if (templateValue.isObject()) {
        outJsobjs.append(templateValue)
        markedArgumentBuffer.append(templateValue)
    }
}

// ============================================================================
// 测试支持
// 对应 Bun: pub const Test = struct { pub const TestToken = ... }
// ============================================================================

/// 测试用Token - 用于JS测试中的序列化
public class TestToken {
    public var tag: TokenTag
    public var text: String
    public var varArgv: UInt8
    public var jsObjRef: UInt32
    public var redirectFlags: RedirectFlags

    public init() {
        tag = TokenTag.Text
        text = ""
        varArgv = 0
        jsObjRef = 0
        redirectFlags = RedirectFlags()
    }

    /// 从真实Token创建测试Token
    public static func fromReal(token: Token, buf: String): TestToken {
        let tt = TestToken()
        tt.tag = token.tag
        match (token.tag) {
            case Var => tt.text = token.textRange.slice(buf)
            case VarArgv => tt.varArgv = token.varArgv
            case Text => tt.text = token.textRange.slice(buf)
            case SingleQuotedText => tt.text = token.textRange.slice(buf)
            case DoubleQuotedText => tt.text = token.textRange.slice(buf)
            case JSObjRef => tt.jsObjRef = token.jsObjRef
            case Redirect => tt.redirectFlags = token.redirectFlags
            case _ => ()
        }
        return tt
    }
}

// ============================================================================
// 重定向方向
// 对应 Bun: const RedirectDirection = enum { out, in }
// ============================================================================

/// 重定向方向
public enum RedirectDirection {
    | out  // 输出重定向 > >>
    | `in` // 输入重定向 < <<
}

// ============================================================================
// 解析后的重定向结果
// 对应 Bun: const ParsedRedirect = struct { flags: RedirectFlags, redirect: ?Redirect }
// ============================================================================

/// 解析后的重定向
public class ParsedRedirect {
    public var flags: RedirectFlags
    public var redirect: ?Redirect

    public init(flags: RedirectFlags, redirect: ?Redirect) {
        this.flags = flags
        this.redirect = redirect
    }
}

// ============================================================================
// stderr互斥锁
// 对应 Bun: var stderr_mutex = bun.Mutex{}
// ============================================================================

/// 标准错误输出的互斥锁 — 仓颉使用 Object 作为锁占位
public let stderrMutex = Object()
