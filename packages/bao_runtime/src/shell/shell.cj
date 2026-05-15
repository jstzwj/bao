// 严格翻译自: src/runtime/shell/shell.zig
// Shell主入口 - 包含AST、词法分析器、解析器、全局上下文
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_jsc.*

// ============================================================================
// Shell 子模块引用
// 对应 Bun: pub const interpret = @import("./interpreter.zig")
// ============================================================================

/// 解释器模块
public let interpret = Interpreter

/// 子进程模块
public let subproc = Subproc

/// 分配作用域
public let AllocScope = AllocScopeImpl

/// 环境变量映射
public typealias EnvMap = Interpreter.EnvMap

/// 环境变量字符串
public typealias EnvStr = Interpreter.EnvStr

/// 解释器
public typealias InterpreterType = Interpreter

/// 已解析的Shell脚本
public typealias ParsedShellScript = Interpreter.ParsedShellScript

/// 子进程
public typealias Subprocess = Subproc.ShellSubprocess

/// 退出码
public typealias ExitCode = Interpreter.ExitCode

/// IO写入器
public typealias IOWriter = Interpreter.IOWriter

/// IO读取器
public typealias IOReader = Interpreter.IOReader

/// 协程Yield
public typealias Yield = YieldType

// ============================================================================
// 常量与全局函数
// 对应 Bun: STDIN_FD, STDOUT_FD, STDERR_FD, POSIX_DEV_NULL, WINDOWS_DEV_NULL
// ============================================================================

/// 不可达状态错误
public func unreachableState(context: String, state: String) {
    panic("Bao shell已到达不可达状态\"\(state)\"在\(context)上下文中。这表示一个bug，请提交GitHub issue。")
}

/// Shell子shell未实现的错误信息
public const SUBSHELL_TODO_ERROR = "Subshells are not implemented, please open GitHub issue!"

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
    case sys(SystemError)
    /// 自定义错误消息
    case custom(String)
    /// 无效参数
    case invalid_arguments(val: String)
    /// 未实现的功能
    case todo(String)

    /// 从系统错误创建
    /// 对应 Bun: pub fn newSys(e: anytype) @This()
    public static func newSys(e: SystemError): ShellErr {
        ShellErr.sys(e)
    }

    /// 转换为字符串
    /// 对应 Bun: pub fn format(...)
    public func toString(): String {
        switch (this) {
            case .sys(let e) =>
                "bao: \(e.message): \(e.path)"
            case .custom(let msg) =>
                "bao: \(msg)"
            case .invalid_arguments(let args) =>
                "bao: invalid arguments: \(args.val)"
            case .todo(let msg) =>
                "bao: TODO: \(msg)"
        }
    }

    /// 向JS抛出错误
    /// 对应 Bun: pub fn throwJS(this: *const @This(), globalThis: *jsc.JSGlobalObject) bun.JSError
    public func throwJS(globalThis: JSGlobalObject): Unit {
        switch (this) {
            case .sys(let e) =>
                let err = e.toErrorInstance(globalThis)
                globalThis.throwValue(err)
            case .custom(let msg) =>
                let errValue = String.cloneUTF8(msg).toErrorInstance(globalThis)
                globalThis.throwValue(errValue)
            case .invalid_arguments(let args) =>
                globalThis.throwInvalidArguments("\(args.val)")
            case .todo(let msg) =>
                globalThis.throwTODO(msg)
        }
    }

    /// 向Mini事件循环抛出错误
    /// 对应 Bun: pub fn throwMini(this: @This()) noreturn
    public func throwMini(): Unit {
        switch (this) {
            case .sys(let err) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>baosh: \(err.message): \(err.path)<r>")
            case .custom(let custom) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>\(custom)<r>")
            case .invalid_arguments(let invalid_arguments) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>baosh: invalid arguments: \(invalid_arguments.val)<r>")
            case .todo(let todo) =>
                Output.prettyErrorln("<r><red>error<r>: Failed due to error: <b>TODO: \(todo)<r>")
        }
        Global.exit(1)
    }

    /// 释放资源
    /// 对应 Bun: pub fn deinit(this: *const @This(), allocator: Allocator) void
    public func deinit(allocator: Allocator) {
        switch (this) {
            case .sys(let e) =>
                e.deref()
            case .custom(let msg) =>
                allocator.free(msg)
            case .invalid_arguments(_) =>
                // 无需释放
            case .todo(let msg) =>
                allocator.free(msg)
        }
    }
}

// ============================================================================
// Shell结果类型
// 对应 Bun: pub fn Result(comptime T: anytype) type
// ============================================================================

/// Shell操作结果
public class Result<T> {
    public var result: T
    public var err: ShellErr

    /// 成功结果
    public static prop success: Result<T> {
        Result<T>(result: Zeroes.zeroes<T>())
    }

    /// 是否为错误
    public func asErr(): ?ShellErr {
        if (this == .err) {
            return this.err
        }
        return None
    }
}

/// Shell错误类型枚举
/// 对应 Bun: pub const ShellError = error{ Init, Process, GlobalThisThrown, Spawn }
public enum ShellError {
    case Init
    case Process
    case GlobalThisThrown
    case Spawn
}

/// Shell解析错误类型
/// 对应 Bun: pub const ParseError = error{ Unsupported, Expected, Unexpected, Unknown, Lex }
public enum ParseError {
    case Unsupported
    case Expected
    case Unexpected
    case Unknown
    case Lex
}

/// 管道类型 [0] => 读端 [1] => 写端
/// 对应 Bun: pub const Pipe = [2]bun.FD
public typealias Pipe = Array<FD>

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
    /// 对应 Bun: pub inline fn allocator(this: @This()) Allocator
    public func allocator(): Allocator {
        this.globalThis.bunVM().allocator
    }

    /// 获取事件循环上下文
    /// 对应 Bun: pub inline fn eventLoopCtx(this: @This()) *jsc.VirtualMachine
    public func eventLoopCtx(): VirtualMachine {
        this.globalThis.bunVM()
    }

    /// 抛出无效参数错误
    /// 对应 Bun: pub inline fn throwInvalidArguments(...)
    public func throwInvalidArguments(fmt: String, args: Array<Any>): ShellErr {
        ShellErr.invalid_arguments(val: "\(fmt)")
    }

    /// 抛出TODO错误
    /// 对应 Bun: pub inline fn throwTODO(this: @This(), msg: []const u8) ShellErr
    public func throwTODO(msg: String): ShellErr {
        ShellErr.todo(msg)
    }

    /// 抛出系统错误
    /// 对应 Bun: pub inline fn throwError(this: @This(), err: bun.sys.Error) void
    public func throwError(err: SyscallError) {
        this.globalThis.throwValue(err.toJS(this.globalThis))
    }

    /// 处理错误
    /// 对应 Bun: pub inline fn handleError(this: @This(), err: anytype, comptime fmt: []const u8) ShellErr
    public func handleError(err: Any, fmt: String): ShellErr {
        ShellErr.custom("\(err) \(fmt)")
    }

    /// 抛出通用错误
    /// 对应 Bun: pub inline fn throw(this: @This(), comptime fmt: []const u8, args: anytype) ShellErr
    public func `throw`(fmt: String, args: Array<Any>): ShellErr {
        ShellErr.custom("\(fmt)")
    }

    /// 创建空分隔环境变量映射
    /// 对应 Bun: pub inline fn createNullDelimitedEnvMap(...)
    public func createNullDelimitedEnvMap(alloc: Allocator): Array<String> {
        this.globalThis.bunVM().transpiler.env.map.createNullDelimitedEnvMap(alloc)
    }

    /// 获取分配器
    /// 对应 Bun: pub inline fn getAllocator(this: @This()) Allocator
    public func getAllocator(): Allocator {
        this.globalThis.bunVM().allocator
    }

    /// 入队并发等待PID任务
    /// 对应 Bun: pub inline fn enqueueTaskConcurrentWaitPid(...)
    public func enqueueTaskConcurrentWaitPid(task: Any): Unit {
        this.globalThis.bunVMConcurrently().enqueueTaskConcurrent(
            ConcurrentTask.create(Task.init(task))
        )
    }

    /// 获取顶层目录
    /// 对应 Bun: pub inline fn topLevelDir(this: @This()) []const u8
    public func topLevelDir(): String {
        this.globalThis.bunVM().transpiler.fs.top_level_dir
    }

    /// 获取环境变量加载器
    /// 对应 Bun: pub inline fn env(this: @This()) *bun.DotEnv.Loader
    public func env(): DotEnvLoader {
        this.globalThis.bunVM().transpiler.env
    }

    /// 获取平台事件循环
    /// 对应 Bun: pub inline fn platformEventLoop(this: @This()) *jsc.PlatformEventLoop
    public func platformEventLoop(): PlatformEventLoop {
        let loop = AbstractVM(this.eventLoopCtx())
        return loop.platformEventLoop()
    }

    /// 实际抛出Shell错误
    /// 对应 Bun: pub inline fn actuallyThrow(this: @This(), shellerr: ShellErr) void
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
        this.mini.env
    }

    /// 获取分配器
    public func allocator(): Allocator {
        this.mini.allocator
    }

    /// 获取事件循环上下文
    public func eventLoopCtx(): MiniEventLoop {
        this.mini
    }

    /// 抛出TODO错误
    public func throwTODO(msg: String): ShellErr {
        ShellErr.todo(msg)
    }

    /// 抛出无效参数错误
    public func throwInvalidArguments(fmt: String, args: Array<Any>): ShellErr {
        ShellErr.invalid_arguments(val: "\(fmt)")
    }

    /// 处理错误
    public func handleError(err: Any, fmt: String): ShellErr {
        ShellErr.custom("\(err) \(fmt)")
    }

    /// 创建空分隔环境变量映射
    public func createNullDelimitedEnvMap(alloc: Allocator): Array<String> {
        this.mini.env.map.createNullDelimitedEnvMap(alloc)
    }

    /// 获取分配器
    public func getAllocator(): Allocator {
        this.mini.allocator
    }

    /// 入队并发等待PID任务
    public func enqueueTaskConcurrentWaitPid(task: Any): Unit {
        let anytask = AnyTaskWithExtraContext()
        anytask.from(task, "runFromMainThreadMini")
        this.mini.enqueueTaskConcurrent(anytask)
    }

    /// 获取顶层目录
    public func topLevelDir(): String {
        this.mini.top_level_dir
    }

    /// 抛出通用错误
    public func `throw`(fmt: String, args: Array<Any>): ShellErr {
        ShellErr.custom("\(fmt)")
    }

    /// 实际抛出Shell错误（终止进程）
    public func actuallyThrow(shellerr: ShellErr): Unit {
        shellerr.throwMini()
    }

    /// 获取平台事件循环
    public func platformEventLoop(): PlatformEventLoop {
        let loop = AbstractVM(this.eventLoopCtx())
        return loop.platformEventLoop()
    }
}

// ============================================================================
// Shell AST - 抽象语法树
// 对应 Bun: pub const AST = struct { ... }
// ============================================================================

/// Shell AST定义
/// 对应 Bun中的完整AST结构
public class AST {

    /// AST脚本 - 顶层节点
    /// 对应 Bun: pub const Script = struct { stmts: []Stmt, ... }
    public class Script {
        public var stmts: Array<Stmt>

        public init(stmts: Array<Stmt>) {
            this.stmts = stmts
        }

        /// 内存开销
        /// 对应 Bun: pub fn memoryCost(this: *const @This()) usize
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
        case assign
        case binary
        case pipeline
        case cmd
        case subshell
        case `if`
        case condexpr
        case async
    }

    /// AST表达式
    public class Expr {
        public var tag: ExprTag
        public var assign: Array<Assign>
        public var binary: Binary
        public var pipeline: Pipeline
        public var cmd: Cmd
        public var subshell: Subshell
        public var `if`: If
        public var condexpr: CondExpr
        public var asyncExpr: Expr  // async是保留字

        public init(tag: ExprTag) {
            this.tag = tag
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            switch (tag) {
                case .assign =>
                    var cost: Int64 = 0
                    for (a in assign) {
                        cost += a.memoryCost()
                    }
                    return cost
                case .binary =>
                    binary.memoryCost()
                case .pipeline =>
                    pipeline.memoryCost()
                case .cmd =>
                    cmd.memoryCost()
                case .subshell =>
                    subshell.memoryCost()
                case .`if` =>
                    `if`.memoryCost()
                case .condexpr =>
                    condexpr.memoryCost()
                case .async =>
                    asyncExpr.memoryCost()
            }
        }

        /// 转换为管道项
        /// 对应 Bun: pub fn asPipelineItem(this: *Expr) ?PipelineItem
        public func asPipelineItem(): ?PipelineItem {
            switch (tag) {
                case .assign =>
                    PipelineItem(tag: PipelineItemTag.assigns, assigns: assign)
                case .cmd =>
                    PipelineItem(tag: PipelineItemTag.cmd, cmd: cmd)
                case .subshell =>
                    PipelineItem(tag: PipelineItemTag.subshell, subshell: subshell)
                case .`if` =>
                    PipelineItem(tag: PipelineItemTag.`if`, `if`: `if`)
                case .condexpr =>
                    PipelineItem(tag: PipelineItemTag.condexpr, condexpr: condexpr)
                else =>
                    None
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
        // 文件测试 - 单参数操作符
        case a       // -a file: True if file exists
        case b       // -b file: True if file exists and is block special
        case c       // -c file: True if file exists and is character special
        case d       // -d file: True if file exists and is a directory
        case e       // -e file: True if file exists
        case f       // -f file: True if file exists and is a regular file
        case g       // -g file: True if file exists and set-group-id bit is set
        case h       // -h file: True if file exists and is a symbolic link
        case k       // -k file: True if file exists and sticky bit is set
        case p       // -p file: True if file exists and is a named pipe
        case r       // -r file: True if file exists and is readable
        case s       // -s file: True if file exists and has size > 0
        case t       // -t fd: True if fd is open and refers to a terminal
        case u       // -u file: True if file exists and set-user-id bit is set
        case w       // -w file: True if file exists and is writable
        case x       // -x file: True if file exists and is executable
        case G       // -G file: True if file exists and owned by effective group id
        case L       // -L file: True if file exists and is a symbolic link
        case N       // -N file: True if file exists and modified since last read
        case O       // -O file: True if file exists and owned by effective user id
        case S       // -S file: True if file exists and is a socket

        // 文件比较 - 双参数操作符
        case ef      // file1 -ef file2: Same device and inode
        case nt      // file1 -nt file2: file1 is newer than file2
        case ot      // file1 -ot file2: file1 is older than file2

        // Shell选项/变量测试
        case o       // -o optname: True if shell option is enabled
        case v       // -v varname: True if shell variable is set
        case R       // -R varname: True if shell variable is set and is a name ref

        // 字符串测试
        case z       // -z string: True if length of string is zero
        case n       // -n string: True if length of string is non-zero
        case eq_eq   // string1 == string2: True if strings are equal
        case neq     // string1 != string2: True if strings are not equal
        case lt_str  // string1 < string2: True if sorts before
        case gt_str  // string1 > string2: True if sorts after

        // 算术比较
        case eq      // arg1 -eq arg2: Equal
        case ne      // arg1 -ne arg2: Not equal
        case lt      // arg1 -lt arg2: Less than
        case le      // arg1 -le arg2: Less than or equal
        case gt      // arg1 -gt arg2: Greater than
        case ge      // arg1 -ge arg2: Greater than or equal

        /// 是否为支持的操作符
        /// 对应 Bun: pub fn isSupported(op: Op) bool
        public func isSupported(): Bool {
            switch (this) {
                case .f, .z, .n, .d, .c, .eq_eq, .neq => true
                else => false
            }
        }

        /// 是否为单参数操作符
        public func isSingleArgOp(): Bool {
            switch (this) {
                case .a, .b, .c, .d, .e, .f, .g, .h, .k, .p, .r, .s, .t,
                .u, .w, .x, .G, .L, .N, .O, .S, .o, .v, .R, .z, .n => true
                else => false
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
            var cost: Int64 = Int64(sizeOf<CondExprOp>())
            for (arg in args) {
                cost += arg.memoryCost()
            }
            return cost
        }

        /// 转换为表达式
        public func toExpr(alloc: Allocator): Expr {
            let expr = Expr(tag: .condexpr)
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
        public var script: Script
        public var redirect: ?Redirect
        public var redirectFlags: RedirectFlags

        public init(script: Script, redirect: ?Redirect, flags: RedirectFlags) {
            this.script = script
            this.redirect = redirect
            this.redirectFlags = flags
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = Int64(sizeOf<Subshell>())
            cost += script.memoryCost()
            if (let r = redirect) {
                cost += r.memoryCost()
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
            let expr = Expr(tag: .`if`)
            expr.`if` = this
            return expr
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = Int64(sizeOf<If>())
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
        case And   // &&
        case Or    // ||
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
            var cost: Int64 = Int64(sizeOf<Binary>())
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
        case cmd
        case assigns
        case subshell
        case `if`
        case condexpr
    }

    /// 管道项
    public class PipelineItem {
        public var tag: PipelineItemTag
        public var cmd: Cmd
        public var assigns: Array<Assign>
        public var subshell: Subshell
        public var `if`: If
        public var condexpr: CondExpr

        public init(tag: PipelineItemTag) {
            this.tag = tag
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            var cost: Int64 = 0
            switch (tag) {
                case .cmd =>
                    cost += cmd.memoryCost()
                case .assigns =>
                    for (a in assigns) {
                        cost += a.memoryCost()
                    }
                case .subshell =>
                    cost += subshell.memoryCost()
                case .`if` =>
                    cost += `if`.memoryCost()
                case .condexpr =>
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
        case cmd
        case assigns
    }

    /// 命令或赋值
    public class CmdOrAssigns {
        public var tag: CmdOrAssignsTag
        public var cmd: Cmd
        public var assigns: Array<Assign>

        public init(tag: CmdOrAssignsTag) {
            this.tag = tag
        }

        /// 转换为管道项
        public func toPipelineItem(alloc: Allocator): PipelineItem {
            switch (tag) {
                case .cmd =>
                    let item = PipelineItem(tag: .cmd)
                    item.cmd = cmd
                    return item
                case .assigns =>
                    let item = PipelineItem(tag: .assigns)
                    item.assigns = assigns
                    return item
            }
        }

        /// 转换为表达式
        public func toExpr(alloc: Allocator): Expr {
            switch (tag) {
                case .cmd =>
                    let expr = Expr(tag: .cmd)
                    expr.cmd = cmd
                    return expr
                case .assigns =>
                    let expr = Expr(tag: .assign)
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
            JSBuf(idx: idx)
        }
    }

    /// JS进程引用
    /// 对应 Bun: pub const JSProc = struct { idx: JSValue }
    public class JSProc {
        public var idx: JSValue
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
            Assign(label: label, value: value)
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            Int64(sizeOf<Assign>()) + Int64(label.size) + value.memoryCost()
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
            var cost: Int64 = Int64(sizeOf<Cmd>())
            for (a in assigns) {
                cost += a.memoryCost()
            }
            for (atom in nameAndArgs) {
                cost += atom.memoryCost()
            }
            if (let r = redirectFile) {
                cost += r.memoryCost()
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
        /// 对应 Bun: pub inline fn isEmpty(this: RedirectFlags) bool
        public func isEmpty(): Bool {
            !stdin && !stdout && !stderr && !append && !duplicateOut
        }

        /// 是否重定向了指定的IO
        /// 对应 Bun: pub fn redirectsElsewhere(this: RedirectFlags, io_kind) bool
        public func redirectsElsewhere(ioKind: IOKind): Bool {
            switch (ioKind) {
                case .stdin => stdin
                case .stdout => if (duplicateOut) { !stdout } else { stdout }
                case .stderr => if (duplicateOut) { !stderr } else { stderr }
            }
        }

        /// 2>&1 重定向
        public static func dup2to1(): RedirectFlags {
            RedirectFlags(stdin: false, stdout: false, stderr: true, append: false, duplicateOut: true)
        }

        /// 1>&2 重定向
        public static func dup1to2(): RedirectFlags {
            RedirectFlags(stdin: false, stdout: true, stderr: false, append: false, duplicateOut: true)
        }

        /// 转换为文件打开标志
        /// 对应 Bun: pub fn toFlags(this: RedirectFlags) i32
        public func toFlags(): Int32 {
            let readWriteFlags: Int32 = if (stdin) { O.RDONLY } else { O.WRONLY | O.CREAT }
            let extra: Int32 = if (append) { O.APPEND } else { O.TRUNC }
            if (stdin) { readWriteFlags } else { extra | readWriteFlags }
        }

        /// < 重定向
        public static func stdinRedirect(): RedirectFlags {
            RedirectFlags(stdin: true, stdout: false, stderr: false, append: false, duplicateOut: false)
        }

        /// << 重定向
        public static func stdinAppendRedirect(): RedirectFlags {
            RedirectFlags(stdin: true, stdout: false, stderr: false, append: true, duplicateOut: false)
        }

        /// > 重定向
        public static func stdoutRedirect(): RedirectFlags {
            RedirectFlags(stdin: false, stdout: true, stderr: false, append: false, duplicateOut: false)
        }

        /// >> 重定向
        public static func stdoutAppendRedirect(): RedirectFlags {
            RedirectFlags(stdin: false, stdout: true, stderr: false, append: true, duplicateOut: false)
        }

        /// &> 重定向 (stdout+stderr)
        public static func allRedirect(): RedirectFlags {
            RedirectFlags(stdin: false, stdout: true, stderr: true, append: false, duplicateOut: false)
        }

        /// &>> 重定向 (追加stdout+stderr)
        public static func allAppendRedirect(): RedirectFlags {
            RedirectFlags(stdin: false, stdout: true, stderr: true, append: true, duplicateOut: false)
        }

        /// 合并两个重定向标志
        /// 对应 Bun: pub fn merge(a: RedirectFlags, b: RedirectFlags) RedirectFlags
        public static func merge(a: RedirectFlags, b: RedirectFlags): RedirectFlags {
            RedirectFlags(
                stdin: a.stdin || b.stdin,
                stdout: a.stdout || b.stdout,
                stderr: a.stderr || b.stderr,
                append: a.append || b.append,
                duplicateOut: a.duplicateOut || b.duplicateOut
            )
        }
    }

    /// IO种类枚举
    public enum IOKind {
        case stdin
        case stdout
        case stderr
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
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            switch (tag) {
                case .atom => atom.memoryCost()
                case .jsbuf => Int64(sizeOf<JSBuf>())
            }
        }
    }

    /// 重定向标签
    public enum RedirectTag {
        case atom
        case jsbuf
    }

    // ========================================================================
    // Atom - 命令参数的原子单元
    // 对应 Bun: pub const Atom = union(Atom.Tag) { simple: SimpleAtom, compound: CompoundAtom, ... }
    // ========================================================================

    /// Atom标签
    public enum AtomTag {
        case simple
        case compound
    }

    /// Atom - 命令参数的最小单元
    public class Atom {
        public var tag: AtomTag
        public var simple: SimpleAtom
        public var compound: CompoundAtom

        public init(tag: AtomTag) {
            this.tag = tag
        }

        /// 创建简单Atom
        public static func newSimple(atom: SimpleAtom): Atom {
            let a = Atom(tag: .simple)
            a.simple = atom
            return a
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            switch (tag) {
                case .simple => simple.memoryCost()
                case .compound => compound.memoryCost()
            }
        }

        /// 合并两个Atom
        /// 对应 Bun: pub fn merge(this: Atom, right: Atom, allocator: Allocator) !Atom
        public static func merge(left: Atom, right: Atom, allocator: Allocator): Atom {
            if (left.tag == .simple && right.tag == .simple) {
                let atoms = allocator.alloc<SimpleAtom>(2)
                atoms[0] = left.simple
                atoms[1] = right.simple
                let result = Atom(tag: .compound)
                result.compound = CompoundAtom(
                    atoms: atoms,
                    braceExpansionHint: left.simple == .brace_begin || left.simple == .brace_end ||
                                        right.simple == .brace_begin || right.simple == .brace_end,
                    globHint: left.simple == .asterisk || left.simple == .double_asterisk ||
                              right.simple == .asterisk || right.simple == .double_asterisk
                )
                return result
            }
            // 简化处理: 其他情况转换为复合Atom
            let result = Atom(tag: .compound)
            var atoms = Array<SimpleAtom>()
            if (left.tag == .simple) {
                atoms.append(left.simple)
            } else {
                for (a in left.compound.atoms) { atoms.append(a) }
            }
            if (right.tag == .simple) {
                atoms.append(right.simple)
            } else {
                for (a in right.compound.atoms) { atoms.append(a) }
            }
            result.compound = CompoundAtom(atoms: atoms.toArray())
            return result
        }

        /// Atom数量
        /// 对应 Bun: pub fn atomsLen(this: *const Atom) u32
        public func atomsLen(): UInt32 {
            switch (tag) {
                case .simple => 1
                case .compound => UInt32(compound.atoms.size)
            }
        }

        /// 是否为复合Atom
        public func isCompound(): Bool {
            tag == .compound
        }

        /// 是否有展开
        public func hasExpansions(): Bool {
            hasGlobExpansion() || hasBraceExpansion()
        }

        /// 是否有glob展开
        public func hasGlobExpansion(): Bool {
            switch (tag) {
                case .simple => simple.globHint()
                case .compound => compound.globHint
            }
        }

        /// 是否有大括号展开
        public func hasBraceExpansion(): Bool {
            switch (tag) {
                case .simple => false
                case .compound => compound.braceExpansionHint
            }
        }

        /// 是否有波浪号展开
        public func hasTildeExpansion(): Bool {
            switch (tag) {
                case .simple => simple == .tilde
                case .compound => compound.atoms.size > 0 && compound.atoms[0] == .tilde
            }
        }
    }

    // ========================================================================
    // SimpleAtom - 最简单的token单元
    // 对应 Bun: pub const SimpleAtom = union(enum) { Var, VarArgv, Text, ... }
    // ========================================================================

    /// 简单Atom类型
    public enum SimpleAtom {
        case Var(String)
        case VarArgv(UInt8)
        case Text(String)
        /// 引号中的空字符串
        case quoted_empty
        /// * 通配符
        case asterisk
        /// ** 通配符
        case double_asterisk
        /// { 大括号开始
        case brace_begin
        /// } 大括号结束
        case brace_end
        /// , 逗号
        case comma
        /// ~ 波浪号
        case tilde
        /// 命令替换
        case cmd_subst(CmdSubst)

        /// 是否有glob提示
        public func globHint(): Bool {
            switch (this) {
                case .asterisk, .double_asterisk => true
                else => false
            }
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            switch (this) {
                case .Var(let s) => Int64(s.size) + Int64(sizeOf<SimpleAtom>())
                case .Text(let s) => Int64(s.size) + Int64(sizeOf<SimpleAtom>())
                case .cmd_subst(let cs) => cs.memoryCost()
                else => Int64(sizeOf<SimpleAtom>())
            }
        }
    }

    /// 命令替换
    /// 对应 Bun: cmd_subst: struct { script: Script, quoted: bool = false, ... }
    public class CmdSubst {
        public var script: Script
        public var quoted: Bool

        public init(script: Script, quoted: Bool) {
            this.script = script
            this.quoted = quoted
        }

        /// 内存开销
        public func memoryCost(): Int64 {
            Int64(sizeOf<CmdSubst>()) + script.memoryCost()
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
            var cost: Int64 = Int64(sizeOf<CompoundAtom>())
            for (atom in atoms) {
                cost += atom.memoryCost()
            }
            return cost
        }
    }
}

// ============================================================================
// Token标记
// 对应 Bun: pub const TokenTag = enum { Pipe, DoublePipe, ... }
// ============================================================================

/// Token标记类型
public enum TokenTag {
    case Pipe               // |
    case DoublePipe         // ||
    case Ampersand          // &
    case DoubleAmpersand    // &&
    case Redirect           // > < >> etc
    case Dollar             // $
    case Asterisk           // *
    case DoubleAsterisk     // **
    case Eq                 // =
    case Semicolon          // ;
    case Newline            // \n
    case BraceBegin         // {
    case Comma              // ,
    case BraceEnd           // }
    case CmdSubstBegin      // $(
    case CmdSubstQuoted     // quoted command substitution
    case CmdSubstEnd        // )
    case OpenParen          // (
    case CloseParen         // )
    case Var                // variable reference
    case VarArgv            // $0-$9
    case Text               // plain text
    case SingleQuotedText   // 'text'
    case DoubleQuotedText   // "text"
    case JSObjRef           // JS object reference
    case DoubleBracketOpen  // [[
    case DoubleBracketClose // ]]
    case Delimit            // delimiter
    case Eof                // end of file
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
    public var redirectFlags: AST.RedirectFlags
    public var textRange: TextRange
    public var varArgv: UInt8
    public var jsObjRef: UInt32

    public init(tag: TokenTag) {
        this.tag = tag
    }

    /// 人类可读表示
    /// 对应 Bun: pub fn asHumanReadable(self: Token, strpool: []const u8) []const u8
    public func asHumanReadable(strpool: String): String {
        switch (tag) {
            case .Pipe => "`|`"
            case .DoublePipe => "`||`"
            case .Ampersand => "`&`"
            case .DoubleAmpersand => "`&&`"
            case .Redirect => "`>`"
            case .Dollar => "`$`"
            case .Asterisk => "`*`"
            case .DoubleAsterisk => "`**`"
            case .Eq => "`=`"
            case .Semicolon => "`;`"
            case .Newline => "`\\n`"
            case .BraceBegin => "`{`"
            case .Comma => "`,`"
            case .BraceEnd => "`}`"
            case .CmdSubstBegin => "`$(`"
            case .CmdSubstQuoted => "CmdSubstQuoted"
            case .CmdSubstEnd => "`)`"
            case .OpenParen => "`(`"
            case .CloseParen => "`)`"
            case .Var => textRange.slice(strpool)
            case .VarArgv => "$\(varArgv)"
            case .Text => textRange.slice(strpool)
            case .SingleQuotedText => textRange.slice(strpool)
            case .DoubleQuotedText => textRange.slice(strpool)
            case .JSObjRef => "JSObjRef"
            case .DoubleBracketOpen => "[["
            case .DoubleBracketClose => "]]"
            case .Delimit => "Delimit"
            case .Eof => "EOF"
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
    /// 对应 Bun: pub fn combineErrors(this: *const LexResult, arena: Allocator) []const u8
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
    case ascii
    case wtf8
    case utf16
}

// ============================================================================
// 特殊字符常量
// 对应 Bun: const SPECIAL_JS_CHAR = 8
// ============================================================================

/// JS替换的特殊字符标记 (\b = 8)
public const SPECIAL_JS_CHAR: UInt8 = 8

/// JS对象引用前缀
/// 对应 Bun: pub const LEX_JS_OBJREF_PREFIX = &[_]u8{SPECIAL_JS_CHAR} ++ "__bun_"
public const LEX_JS_OBJREF_PREFIX = "\x08__bun_"

/// JS字符串引用前缀
/// 对应 Bun: pub const LEX_JS_STRING_PREFIX = &[_]u8{SPECIAL_JS_CHAR} ++ "__bunstr_"
public const LEX_JS_STRING_PREFIX = "\x08__bunstr_"

// ============================================================================
// Shell字符迭代器状态
// 对应 Bun: ShellCharIter.State
// ============================================================================

/// 引号状态
public enum ShellQuoteState {
    case Normal
    case Single
    case Double
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
        c.char == '\t' || c.char == '\r' || c.char == '\n' || c.char == ' '
    }
}

// ============================================================================
// 子Shell类型
// 对应 Bun: Lexer.SubShellKind
// ============================================================================

/// 子Shell种类
public enum SubShellKind {
    case normal     // (echo hi; echo hello)
    case backtick   // `echo hi; echo hello`
    case dollar     // $(echo hi; echo hello)

    /// 获取闭合Token
    public func closingTok(): TokenTag {
        switch (this) {
            case .cmd_subst => TokenTag.CmdSubstEnd
            case .normal => TokenTag.CloseParen
            case .dollar => TokenTag.CmdSubstEnd
            case .backtick => TokenTag.CmdSubstEnd
        }
    }
}

// ============================================================================
// 解析器子Shell类型
// 对应 Bun: Parser.SubshellKind
// ============================================================================

/// 解析器子Shell种类
public enum ParserSubshellKind {
    case cmd_subst
    case normal

    /// 获取闭合Token
    public func closingTok(): TokenTag {
        switch (this) {
            case .cmd_subst => TokenTag.CmdSubstEnd
            case .normal => TokenTag.CloseParen
        }
    }
}

// ============================================================================
// If子句Token
// 对应 Bun: const IfClauseTok = enum { if, else, elif, then, fi }
// ============================================================================

/// If子句Token类型
public enum IfClauseTok {
    case `if`
    case `else`
    case elif
    case then
    case fi

    /// 从文本解析
    public static func fromText(txt: String): ?IfClauseTok {
        if (txt == "if") return .`if`
        if (txt == "else") return .`else`
        if (txt == "elif") return .elif
        if (txt == "then") return .then
        if (txt == "fi") return .fi
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
    if (varName.size == 0) return false
    let first = varName[0]
    if (first == '=' || (first >= '0' && first <= '9')) return false
    if (!((first >= 'a' && first <= 'z') || (first >= 'A' && first <= 'Z') || first == '_')) {
        return false
    }
    for (i in 1..varName.size) {
        let c = varName[i]
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') ||
              (c >= 'A' && c <= 'Z') || c == '_')) {
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
        if (str[i] == '=') {
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
    public var iter: HashMap<String, String>.Iterator

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
        iter.next()
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
        items.toArray()
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
        if (len() == 0) return None
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
        items.removeLast()
    }
}

// ============================================================================
// Shell转义工具
// 对应 Bun: pub fn escape8Bit, escapeUtf16, needsEscapeUtf8AsciiLatin1, ...
// ============================================================================

/// 需要转义的特殊字符集合
/// 对应 Bun: const SPECIAL_CHARS = [_]u8{ ... }
public const SPECIAL_CHARS = "~[]#;\n*{,}`$=()0123456789|><&'\" \\" + "\x08"

/// 双引号中需要反斜杠的字符
/// 对应 Bun: const BACKSLASHABLE_CHARS = [_]u8{ '$', '`', '"', '\\' }
public const BACKSLASHABLE_CHARS = "$`\"\\"

/// 检查字符串是否需要Shell转义
/// 对应 Bun: pub fn needsEscapeUtf8AsciiLatin1(str: []const u8) bool
public func needsEscapeUtf8AsciiLatin1(str: String): Bool {
    for (c in str) {
        if (SPECIAL_CHARS.contains(c)) return true
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
    if (addQuotes) outbuf.append("\"")
    for (c in str) {
        if (BACKSLASHABLE_CHARS.contains(c)) {
            outbuf.append("\\")
            outbuf.append(c)
        } else {
            outbuf.append(c)
        }
    }
    if (addQuotes) outbuf.append("\"")
}

// ============================================================================
// Shell源构建器
// 对应 Bun: pub const ShellSrcBuilder = struct { ... }
// ============================================================================

/// Shell脚本源代码构建器
/// 用于从JS模板字符串构建Shell脚本
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

    /// 追加JS值字符串
    /// 对应 Bun: pub fn appendJSValueStr(...)
    public func appendJSValueStr(jsval: JSValue, allowEscape: Bool): Bool {
        let bunstr = jsval.toBunString(globalThis)
        // 检查空字节注入
        if (bunstr.indexOfAsciiChar(0) != None) {
            globalThis.throwInvalidArguments(
                "The shell argument must be a string without null bytes"
            )
            return false
        }
        return appendBunStr(bunstr, allowEscape)
    }

    /// 追加Bun字符串
    /// 对应 Bun: pub fn appendBunStr(...)
    public func appendBunStr(bunstr: BunString, allowEscape: Bool): Bool {
        if (allowEscape && bunstr.length() == 0) {
            appendJSStrRef(bunstr)
            return true
        }
        if (allowEscape && needsEscapeBunstr(bunstr)) {
            appendJSStrRef(bunstr)
            return true
        }
        outbuf.appendSlice(bunstr.byteSlice())
        return true
    }

    /// 追加JS字符串引用标记
    /// 对应 Bun: pub fn appendJSStrRef(...)
    public func appendJSStrRef(bunstr: BunString): Unit {
        let idx = jsstrsToEscape.size
        let marker = "\(LEX_JS_STRING_PREFIX)\(idx)"
        outbuf.appendSlice(marker)
        bunstr.ref()
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
    stringArgs: JSValue,
    templateArgs: JSArrayIterator,
    outJsobjs: ArrayList<JSValue>,
    jsstrings: ArrayList<BunString>,
    outScript: ArrayList<Byte>,
    markedArgumentBuffer: MarkedArgumentBuffer
): Unit {
    let builder = ShellSrcBuilder(globalThis, outScript, jsstrings)
    let stringIter = stringArgs.arrayIterator(globalThis)
    let last = stringIter.len - 1
    var i: UInt32 = 0

    while (let jsValue = stringIter.next()) {
        if (!builder.appendJSValueStr(jsValue, false)) {
            globalThis.throw("Shell script string contains invalid UTF-16")
            return
        }
        if (i < last) {
            let templateValue = templateArgs.next()
            if (templateValue == None) {
                globalThis.throw("Shell script is missing JSValue arg")
                return
            }
            handleTemplateValue(globalThis, templateValue.get(), outJsobjs,
                                outScript, jsstrings, markedArgumentBuffer)
        }
        i += 1
    }
}

/// 处理模板值
/// 对应 Bun: pub fn handleTemplateValue(...)
public func handleTemplateValue(
    globalThis: JSGlobalObject,
    templateValue: JSValue,
    outJsobjs: ArrayList<JSValue>,
    outScript: ArrayList<Byte>,
    jsstrings: ArrayList<BunString>,
    markedArgumentBuffer: MarkedArgumentBuffer
): Unit {
    let builder = ShellSrcBuilder(globalThis, outScript, jsstrings)

    if (templateValue.isZero()) return

    // ArrayBuffer
    if (let ab = templateValue.asArrayBuffer(globalThis)) {
        let idx = outJsobjs.size
        markedArgumentBuffer.append(templateValue)
        outJsobjs.append(templateValue)
        outScript.appendSlice("\(LEX_JS_OBJREF_PREFIX)\(idx)")
        return
    }

    // 字符串
    if (templateValue.isString()) {
        builder.appendJSValueStr(templateValue, true)
        return
    }

    // 数组
    if (templateValue.jsType().isArray()) {
        let array = templateValue.arrayIterator(globalThis)
        let last = array.len - 1
        var i: UInt32 = 0
        while (let arr = array.next()) {
            handleTemplateValue(globalThis, arr, outJsobjs, outScript,
                                jsstrings, markedArgumentBuffer)
            if (i < last) {
                outScript.append(' ')
            }
            i += 1
        }
        return
    }

    // 原始值
    if (templateValue.isPrimitive()) {
        builder.appendJSValueStr(templateValue, true)
        return
    }

    globalThis.throw("Invalid JS object used in shell: you might need to call .toString() on it")
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
    public var redirectFlags: AST.RedirectFlags

    /// 从真实Token创建测试Token
    public static func fromReal(token: Token, buf: String): TestToken {
        let tt = TestToken()
        tt.tag = token.tag
        switch (token.tag) {
            case .Var => tt.text = token.textRange.slice(buf)
            case .VarArgv => tt.varArgv = token.varArgv
            case .Text => tt.text = token.textRange.slice(buf)
            case .SingleQuotedText => tt.text = token.textRange.slice(buf)
            case .DoubleQuotedText => tt.text = token.textRange.slice(buf)
            case .JSObjRef => tt.jsObjRef = token.jsObjRef
            case .Redirect => tt.redirectFlags = token.redirectFlags
            else => {}
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
    case out  // 输出重定向 > >>
    case `in` // 输入重定向 < <<
}

// ============================================================================
// 解析后的重定向结果
// 对应 Bun: const ParsedRedirect = struct { flags: AST.RedirectFlags, redirect: ?AST.Redirect }
// ============================================================================

/// 解析后的重定向
public class ParsedRedirect {
    public var flags: AST.RedirectFlags
    public var redirect: ?AST.Redirect

    public init(flags: AST.RedirectFlags, redirect: ?AST.Redirect) {
        this.flags = flags
        this.redirect = redirect
    }
}

// ============================================================================
// stderr互斥锁
// 对应 Bun: var stderr_mutex = bun.Mutex{}
// ============================================================================

/// 标准错误输出的互斥锁
public let stderrMutex = Mutex()
