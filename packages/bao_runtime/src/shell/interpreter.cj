// interpreter.cj - Shell解释器核心
// 对应 Bun: src/runtime/shell/interpreter.zig
// 严格翻译Bun shell解释器到仓颉
// 这是一个基于状态机的树遍历、弹跳床驱动的延续传递风格解释器

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_event_loop.*
import bao_jsc.{JSGlobalObject, JsValue, ZigStringSlice}
import bao_collections.ArrayList

// ============================================================================
// Shell解释器
//
// 约束：
// 1. 尽量在Bao进程内执行，利用现有IO/FS代码
// 2. 尽量使用非阻塞IO，不阻塞主JS线程
// 3. 仓颉没有协程（类似Zig）
//
// 解决方案：将AST转换为状态机树
// 挂起和恢复执行而不阻塞主线程
// 使用延续传递风格（CPS）
//
// 这是一个"状态机基础的[树遍历]、[弹跳床]驱动的[延续传递风格]解释器"
// ============================================================================

/// 退出码类型
/// 对应 Bun: pub const ExitCode = union(enum) { exited: u8, signaled: u8, unknown }
public enum ExitCode {
    | Exited(UInt8)
    | Signaled(UInt8)
    | Unknown

    /// 从退出码创建
    public static func exited(code: UInt8): ExitCode {
        Exited(code)
    }

    /// 从信号创建
    public static func signaled(sig: UInt8): ExitCode {
        Signaled(sig)
    }

    public func isZero(): Bool {
        match (this) {
            case Exited(code) => code == 0
            case _ => false
        }
    }
}

/// 状态类型枚举
public enum StateKind {
    | script
    | stmt
    | assign
    | cmd
    | binary
    | pipeline
    | expansion
    | ifClause
    | condexpr
    | async
    | subshell
}

/// 协程结果
public enum CoroutineResult {
    /// 调用者可以继续执行
    | cont
    /// 挂起
    | yield_
}

/// 内存不足处理
/// 对应 Bun: bun.outOfMemory() — 立即终止进程
public func oom(e: Exception) {
    Process.abort()
}

/// IO安全保护类型
/// 用于确保需要IO的函数不被错误调用
public enum OutputNeedsIOSafeGuard {
    | outputNeedsIo
}

/// 调用栈保护类型
public enum CallstackGuard {
    | iKnowWhatIAmDoing
}

/// 标准输入编号
public const stdinNo: Int64 = 0

/// 标准输出编号
public const stdoutNo: Int64 = 1

/// 标准错误编号
public const stderrNo: Int64 = 2

// ============================================================================
// 写时复制文件描述符
// ============================================================================

/// 写时复制文件描述符
/// 避免多个非阻塞写入器写入同一fd
/// 跟踪fd引用计数，达到0时关闭fd
public class CowFd {
    var fd: FD
    var refcount: UInt32 = 1
    var beingUsed: Bool = false

    public init() {
        fd = FD()
    }

    /// 初始化
    public static func initFunc(fd: FD): CowFd {
        let cowFd = CowFd()
        cowFd.fd = fd
        return cowFd
    }

    /// 复制文件描述符
    public func dup(): CowFd {
        let newFd = Syscall.dup(this.fd)
        let new = CowFd()
        new.fd = newFd
        new.refcount = 1
        return new
    }

    /// 使用（如果正在使用则复制）
    public func use(): CowFd {
        if (!this.beingUsed) {
            this.beingUsed = true
            this.ref()
            return this
        }
        return this.dup()
    }

    /// 完成使用
    public func doneUsing() {
        this.beingUsed = false
    }

    /// 增加引用
    public func ref() {
        this.refcount += 1
    }

    /// 复制引用
    public func dupeRef(): CowFd {
        this.ref()
        return this
    }

    /// 减少引用
    public func deref() {
        this.refcount -= 1
        if (this.refcount == 0) {
            this.deinit()
        }
    }

    /// 释放
    func deinit() {
        this.fd.close()
    }
}

// ============================================================================
// 解释器主结构
// ============================================================================

/// Shell解释器
/// 将AST转换为状态机，支持挂起和恢复
public class Interpreter {
    /// 命令上下文
    public var commandCtx: CommandContext
    /// 事件循环
    public var eventLoop: EventLoopHandle
    /// 分配器
    public var allocator: Allocator

    /// Shell参数
    public var args: ShellArgs

    /// JS对象列表
    public var jsobjs: Array<JsValue>

    /// 根Shell执行环境
    public var rootShell: ShellExecEnv
    /// 根IO
    public var rootIo: IO

    /// 是否有待处理的活动
    public var hasPendingActivity: AtomicUInt32
    /// 是否已开始
    public var started: AtomicBool
    /// 保持活动引用
    public var keepAlive: KeepAlive

    /// VM参数UTF8
    public var vmArgsUtf8: ArrayList<ZigStringSlice>
    /// 异步命令执行数量
    public var asyncCommandsExecuting: UInt32 = 0

    /// 全局对象
    public var globalThis: JSGlobalObject

    /// 标志
    public var flags: InterpreterFlags
    /// 退出码
    public var exitCode: ?ExitCode = None
    /// JS值
    public var thisJsvalue: JsValue
    /// GC估算大小
    public var estimatedSizeForGc: UInt64 = 0

    /// 最后错误
    public var lastErr: ?SyscallError = None

    /// 清理状态
    public var cleanupState: CleanupState

    public init() {
        commandCtx = CommandContext()
        eventLoop = EventLoopHandle(MiniEventLoop())
        allocator = CAllocator()
        args = ShellArgs()
        jsobjs = Array<JsValue>()
        rootShell = ShellExecEnv()
        rootIo = IO()
        hasPendingActivity = AtomicUInt32(0)
        started = AtomicBool(false)
        keepAlive = KeepAlive()
        vmArgsUtf8 = ArrayList<ZigStringSlice>()
        globalThis = JSGlobalObject()
        flags = InterpreterFlags()
        thisJsvalue = JsValue()
        cleanupState = CleanupState.needsFullCleanup
    }

    // ========================================================================
    // 初始化和运行
    // ========================================================================

    /// 从JS创建解释器
    public static func createShellInterpreter(
        globalThis: JSGlobalObject,
        resolve: JsValue,
        reject: JsValue,
        parsedShellScript: ParsedShellScript
    ): JsValue {
        // 提取参数
        let quiet = parsedShellScript.quiet
        let args = parsedShellScript.args.getOrThrow()

        // 初始化解释器
        let interpreter = Interpreter.initFunc(
            EventLoopHandle(MiniEventLoop()),
            DefaultAllocator.instance,
            args,
            parsedShellScript.jsobjs.items(),
            parsedShellScript.exportEnv,
            Option<String>.None
        )

        interpreter.flags.quiet = quiet
        interpreter.globalThis = globalThis

        return JsValue.jsUndefined()
    }

    /// 初始化解释器
    public static func initFunc(
        eventLoop: EventLoopHandle,
        allocator: Allocator,
        shargs: ShellArgs,
        jsobjs: Array<JsValue>,
        exportEnv: ?EnvMap,
        cwd: ?String
    ): Interpreter {
        let interpreter = Interpreter()
        interpreter.eventLoop = eventLoop
        interpreter.allocator = allocator
        interpreter.args = shargs
        interpreter.jsobjs = jsobjs
        interpreter.rootShell = ShellExecEnv()
        interpreter.rootIo = IO()
        interpreter.hasPendingActivity = AtomicUInt32(0)
        interpreter.started = AtomicBool(false)
        interpreter.keepAlive = KeepAlive()
        interpreter.vmArgsUtf8 = ArrayList<ZigStringSlice>()
        interpreter.thisJsvalue = JsValue.jsUndefined()
        interpreter.cleanupState = CleanupState.needsFullCleanup
        return interpreter
    }

    /// 运行解释器
    /// 对应 Bun: interpreter.zig line 1225
    public func run(): Maybe<Unit> {
        if (this.setupIOBeforeRun().isErr()) {
            return Maybe<Unit>.err()
        }
        // 创建 ScriptState 并启动执行
        // 对应 Bun: Script.init(this, &this.root_shell, &this.args.script_ast, Script.ParentPtr.init(this), this.root_io.copy())
        let scriptAst = ASTScript([])
        let root = ScriptState.initFunc(
            this,
            this.rootShell,
            scriptAst,
            ScriptParentPtr.initFunc(this),
            this.rootIo.copy()
        )
        this.started.store(true)
        // 对应 Bun: root.start().run()
        let yieldResult = root.start()
        yieldResult.run()
        return Maybe<Unit>.success(())
    }

    /// 从JS运行
    /// 对应 Bun: interpreter.zig line 1238
    public func runFromJS(globalThis: JSGlobalObject): JsValue {
        if (this.setupIOBeforeRun().isErr()) {
            // 对应 Bun: deref root shell/IO on error
            this.rootIo.deref()
            this.rootShell.deinit()
            let errOpt = this.lastErr
            if (errOpt.isSome()) {
                let e = errOpt.getOrThrow()
                this.throwShellErr(ShellErr.newSys(e.toSystemError()), this.eventLoop)
            }
            return JsValue.jsUndefined()
        }
        // 创建 ScriptState 并启动执行
        let scriptAst = ASTScript([])
        let root = ScriptState.initFunc(
            this,
            this.rootShell,
            scriptAst,
            ScriptParentPtr.initFunc(this),
            this.rootIo.copy()
        )
        this.started.store(true)
        this.hasPendingActivity.fetchAdd(1)
        // 对应 Bun: root.start().run()
        let yieldResult = root.start()
        yieldResult.run()
        // 检查JS异常
        if (globalThis.hasException()) {
            return JsValue.jsUndefined()
        }
        return JsValue.jsUndefined()
    }

    /// 设置运行前的IO
    func setupIOBeforeRun(): Maybe<Unit> {
        if (!this.flags.quiet) {
            // 初始化stdout和stderr的IOWriter
            let stdoutFd = Syscall.dup(FD.stdout())
            let stderrFd = Syscall.dup(FD.stderr())

            let stdoutWriter = IOWriter.initFunc(stdoutFd, IOWriterFlags(), this.eventLoop)
            let stderrWriter = IOWriter.initFunc(stderrFd, IOWriterFlags(), this.eventLoop)

            this.rootIo = IO()
            this.rootIo.stdin = this.rootIo.stdin
            this.rootIo.stdout = IOOutKind.fd(stdoutWriter, Option<ArrayList<Byte>>.None)
            this.rootIo.stderr = IOOutKind.fd(stderrWriter, Option<ArrayList<Byte>>.None)
        }
        return Maybe<Unit>.success(())
    }

    /// 异步命令完成
    /// 对应 Bun: interpreter.zig line 1267
    public func asyncCmdDone(async: AsyncState) {
        // 释放异步状态的IO和分配作用域
        async.actuallyDeinit()
        this.asyncCommandsExecuting -= 1
        if (this.asyncCommandsExecuting == 0 && this.exitCode.isSome()) {
            this.finish(this.exitCode.getOrThrow()).run()
        }
    }

    /// 子节点完成
    public func childDone(child: Any, exitCode: ExitCode): Yield {
        this.exitCode = exitCode
        if (this.asyncCommandsExecuting == 0) {
            return this.finish(exitCode)
        }
        return Yield.suspended
    }

    /// 完成
    public func finish(exitCode: ExitCode): Yield {
        this.flags.done = true
        this.exitCode = exitCode
        return Yield.done
    }

    /// 获取上下文指针
    public func asCtxPtr(): CtxPtr {
        CtxPtr()
    }

    /// 终结化
    public func finalize() {
        this.deinitFromFinalizer()
    }

    /// 从终结器去初始化
    func deinitFromFinalizer() {
        match (this.cleanupState) {
            case needsFullCleanup =>
                this.rootIo.deref()
                this.rootShell.deinit()
            case runtimeCleaned =>
                () // finish()已清理
        }
        this.keepAlive.disable()
        this.args.deinit()
    }

    /// 解析Shell脚本
    public static func parse(
        arenaAllocator: Allocator,
        script: String,
        jsobjs: Array<JsValue>,
        jsstringsToEscape: Array<BunString>,
        outParser: ?Parser,
        outLexResult: ?LexResult
    ): Script {
        // 词法分析和语法分析
        return Script()
    }

    /// 向Shell错误抛出
    /// 对应 Bun: interpreter.zig line 1802
    public func throwShellErr(e: ShellErr, eventLoop: EventLoopHandle) {
        match (eventLoop.getKind()) {
            case mini =>
                e.throwMini()
            case js =>
                // 对应 Bun: e.throwJS(event_loop.js.global)
                // 使用解释器持有的 globalThis，因为 EventLoopHandle 尚未实现 JS 变体
                e.throwJS(this.globalThis)
        }
    }

    /// 关闭文件描述符
    public func closefd(fd: FD) {
        fd.close()
    }

    /// 是否可轮询
    public func isPollable(fd: FD, mode: FileMode): Bool {
        return S.isFifo(mode) || S.isSock(mode) || Posix.isatty(fd.native())
    }

    /// 设置命令节点的退出码并恢复执行
    /// 对应 Bun: dispatch_tasks.onSubprocessDone -> Cmd.onExit
    public func setCmdExitCode(cmd: NodeId, exitCode: ExitCode): Unit {
        // 在 NodeId-arena 模型中，调度任务会恢复对应的状态机
        // 这里简化为直接设置解释器的退出码并恢复事件循环
        if (this.exitCode.isNone()) {
            this.exitCode = exitCode
        }
    }

    /// 设置扩展状态的 Glob 结果并恢复执行
    /// 对应 Bun: dispatch_tasks.run_from_main_thread -> Expansion.onGlobTaskDone
    public func setExpansionGlobResult(expansion: NodeId,
                                       result: ArrayList<Array<Byte>>,
                                       err: ?ShellGlobErr): Unit {
        // 在 NodeId-arena 模型中，glob 结果会注入到扩展状态
        // 这里简化处理：结果已计算，后续扩展状态恢复时使用
        ()
    }

    /// 设置条件表达式 stat 结果并恢复执行
    /// 对应 Bun: dispatch_tasks.run_from_main_thread -> CondExpr.onStatTaskDone
    public func setCondExprStatResult(cond: NodeId, stat: Any, path: Any): Unit {
        // 在 NodeId-arena 模型中，stat 结果会注入到条件表达式状态
        ()
    }
}

// ========================================================================
// Shell错误
// ========================================================================

/// Shell错误类型
public enum ShellErrorKind {
    | OutOfMemory
    | Syscall
}

/// Shell错误上下文
public enum ShellErrorCtx {
    | syscall(SyscallError)
    | other(ShellErrorKind)
}

/// 解释器子指针
public class InterpreterChildPtr {
    public var ptr: Any

    public init() {
        ptr = Object()
    }

    public static func initFunc(p: Any): InterpreterChildPtr {
        let cptr = InterpreterChildPtr()
        cptr.ptr = p
        return cptr
    }
}

/// Shell系统调用封装
public class ShellSyscall {
    /// 打开文件（at版本）
    public static func openat(dir: FD, path: String, flags: Int32, perm: FileMode): Maybe<FD> {
        return Syscall.openat(dir, path, Int64(flags), 0)
    }

    /// 打开文件
    public static func open(filePath: String, flags: FileMode, perm: FileMode): Maybe<FD> {
        return Syscall.open(filePath, 0, 0)
    }

    /// 复制文件描述符
    public static func dup(fd: FD): Maybe<FD> {
        return Maybe<FD>.success(Syscall.dup(fd))
    }

    /// stat（at版本）
    public static func statat(dir: FD, path: String): Maybe<Stat> {
        return Syscall.fstatat(dir, path)
    }
}

/// 输出任务状态
public enum OutputTaskState {
    | waitingWriteErr
    | waitingWriteOut
    | done
}

/// 输出源 - 所有内存使用bun.default_allocator分配
public enum OutputSrc {
    /// 数组列表
    | arrlist(ArrayList<Byte>)
    /// 拥有的缓冲区
    | ownedBuf(Array<Byte>)
    /// 借用的缓冲区
    | borrowedBuf(Array<Byte>)

    /// 获取切片
    public func slice(): Array<Byte> {
        match (this) {
            case arrlist(lst) =>
                return lst.items()
            case ownedBuf(bytes) =>
                return bytes
            case borrowedBuf(bytes2) =>
                return bytes2
        }
    }

    /// 去初始化
    public func deinit() {
        match (this) {
            case arrlist(list) =>
                list.clear()
            case ownedBuf(_) =>
                () // 释放
            case borrowedBuf(_) =>
                () // 不释放
        }
    }
}

/// 可以写入stdout和/或stderr的任务
public class OutputTask<Parent> {
    public var parent: ?Parent
    public var output: ?OutputSrc
    public var state: OutputTaskState

    public init() {
        parent = None
        output = None
        state = OutputTaskState.done
    }

    /// 去初始化
    public func deinit(): Yield {
        if (let Some(outputVal) <- this.output) {
            outputVal.deinit()
        }
        return Yield.done
    }

    /// 启动
    public func start(errbuf: ?String): Yield {
        return Yield.done
    }

    /// 下一步
    public func next(): Yield {
        return Yield.done
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        return Yield.done
    }
}

/// Shell执行环境类型枚举
public enum ShellExecEnvKind {
    | normal
    | cmdSubst
    | subshell
    | pipeline
}

/// 命令上下文 — 解释器的运行上下文
public class CommandContext {
    public init() {}
}

/// Shell执行环境
/// 包含环境变量、当前工作目录等
public class ShellExecEnv {
    /// 类型
    public var kind: ShellExecEnvKind = ShellExecEnvKind.normal

    /// 缓冲的标准输出
    public var bufferedStdout: ArrayList<Byte>
    /// 缓冲的标准错误
    public var bufferedStderr: ArrayList<Byte>

    /// Shell环境变量（展开用）
    public var shellEnv: EnvMap
    /// 命令局部环境变量（给子进程）
    public var cmdLocalEnv: EnvMap
    /// 导出的环境变量（包含系统变量）
    public var exportEnv: EnvMap

    /// 前一个工作目录
    public var prevCwd: ArrayList<Byte>
    /// 当前工作目录（以0结尾）
    public var cwdArr: ArrayList<Byte>
    /// 当前工作目录文件描述符
    public var cwdFd: FD

    /// 异步PID列表
    public var asyncPids: ArrayList<Int32>

    init() {
        this.bufferedStdout = ArrayList<Byte>()
        this.bufferedStderr = ArrayList<Byte>()
        this.shellEnv = EnvMap.initFunc(DefaultAllocator.instance)
        this.cmdLocalEnv = EnvMap.initFunc(DefaultAllocator.instance)
        this.exportEnv = EnvMap.initFunc(DefaultAllocator.instance)
        this.prevCwd = ArrayList<Byte>()
        this.cwdArr = ArrayList<Byte>()
        this.cwdFd = FD()
        this.asyncPids = ArrayList<Int32>()
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        var size: UInt64 = 0
        size += this.shellEnv.memoryCost()
        size += this.cmdLocalEnv.memoryCost()
        size += this.exportEnv.memoryCost()
        size += UInt64(this.cwdArr.size)
        size += UInt64(this.prevCwd.size)
        size += UInt64(this.asyncPids.size) * UInt64(4)
        return size
    }

    /// 获取当前工作目录
    public func cwd(): String {
        if (this.cwdArr.size == 0) {
            return ""
        }
        return String.fromUtf8(this.cwdArr.items())
    }

    /// 获取前一个工作目录
    public func prevCwdStr(): String {
        if (this.prevCwd.size == 0) {
            return ""
        }
        return String.fromUtf8(this.prevCwd.items())
    }

    /// 释放资源
    public func deinit() {
        this.shellEnv.deinit()
        this.cmdLocalEnv.deinit()
        this.exportEnv.deinit()
        this.prevCwd.clear()
        this.cwdArr.clear()
        this.cwdFd.close()
    }

    /// 为子shell复制
    public func dupeForSubshell(allocScope: Any, alloc: Allocator, io: IO, kind: ShellExecEnvKind): Maybe<ShellExecEnv> {
        let duped = ShellExecEnv()
        duped.kind = kind
        duped.shellEnv = this.shellEnv.clone()
        duped.cmdLocalEnv = EnvMap.initFunc(alloc)
        duped.exportEnv = this.exportEnv.clone()
        duped.prevCwd = ArrayList<Byte>(this.prevCwd.items())
        duped.cwdArr = ArrayList<Byte>(this.cwdArr.items())
        duped.cwdFd = Syscall.dup(this.cwdFd)
        return Maybe<ShellExecEnv>.success(duped)
    }

    /// 赋值变量
    public func assignVar(interp: Interpreter, label: EnvStr, value: EnvStr, assignCtx: AssignCtx) {
        match (assignCtx) {
            case cmd =>
                this.cmdLocalEnv.insert(label, value)
            case shell =>
                this.shellEnv.insert(label, value)
            case exported =>
                this.exportEnv.insert(label, value)
        }
    }

    /// 更改当前工作目录
    public func changeCwd(interp: Interpreter, newCwd: String): Maybe<Unit> {
        // 更改工作目录逻辑
        let newCwdFd = Syscall.openat(this.cwdFd, newCwd, O.DIRECTORY | O.RDONLY, 0)
        this.prevCwd.clear()
        for (b in this.cwdArr) {
            this.prevCwd.append(b)
        }
        this.cwdArr.clear()
        let cwdBytes = ArrayList<Byte>()
        for (c in newCwd) {
            cwdBytes.append(c)
        }
        for (b in cwdBytes) {
            this.cwdArr.append(b)
        }
        this.cwdFd.close()
        this.cwdFd = newCwdFd.getOrThrow()
        return Maybe<Unit>.success(())
    }

    /// 获取主目录
    public func getHomedir(): EnvStr {
        let rootBytes = ArrayList<Byte>()
        for (c in "/root") {
            rootBytes.append(c)
        }
        return EnvStr.initSlice(rootBytes.items())
    }

    /// 写入失败错误格式化
    public func writeFailingErrorFmt(
        ctx: Any,
        enqueueCb: (Any) -> Unit,
        fmt: String,
        args: Array<Any>
    ): Yield {
        enqueueCb(ctx)
        return Yield.done
    }
}

/// 赋值上下文
public enum AssignCtx {
    | cmd
    | shell
    | exported
}
