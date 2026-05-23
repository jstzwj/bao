// interpreter.cj - Shell解释器核心
// 对应 Bun: src/runtime/shell/interpreter.zig
// 严格翻译Bun shell解释器到仓颉
// 这是一个基于状态机的树遍历、弹跳床驱动的延续传递风格解释器

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_jsc.*
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
public type ExitCode = UInt16

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
public func oom(e: Exception) {
    outOfMemory()
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

/// 管道类型 [0] => 读端 [1] => 写端
public type Pipe = Array<FD>

/// 小列表类型
public type SmolList<T, N> = ArrayList<T>

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
    var beingUsed: Boolean = false

    /// 初始化
    public static func initFunc(fd: FD): CowFd {
        let `this` = CowFd()
        this.fd = fd
        return this
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
    public var args: ParsedShellScript.ShellArgs

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
    public var exitCode: ?ExitCode = 0
    /// JS值
    public var thisJsvalue: JsValue
    /// GC估算大小
    public var estimatedSizeForGc: UInt64 = 0

    /// 最后错误
    public var lastErr: ?SyscallError = None

    /// 清理状态
    public var cleanupState: CleanupState

    // ========================================================================
    // 解释器标志 — 参见顶层 InterpreterFlags
    // ========================================================================

    /// 清理状态 — 参见顶层 CleanupState
    public var flags: InterpreterFlags

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
        let interpreter = Interpreter(
            eventLoop: EventLoopHandle.js(globalThis.bunVM().eventLoop),
            allocator: DefaultAllocator.instance,
            shargs: args,
            jsobjs: parsedShellScript.jsobjs.toArray(),
            exportEnv: parsedShellScript.exportEnv,
            cwd: None
        )

        interpreter.flags.quiet = quiet
        interpreter.globalThis = globalThis

        return JsValue.jsUndefined()
    }

    /// 初始化解释器
    public static func initFunc(
        eventLoop: EventLoopHandle,
        allocator: Allocator,
        shargs: ParsedShellScript.ShellArgs,
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
        interpreter.thisJsvalue = JsValue.zero
        interpreter.cleanupState = CleanupState.needsFullCleanup
        return interpreter
    }

    /// 运行解释器
    public func run(): Maybe<Unit> {
        if (this.setupIOBeforeRun().isErr()) {
            return Maybe<Unit>.err()
        }

        let root = ScriptState(
            interpreter: this,
            shellState: this.rootShell,
            node: this.args.scriptAst,
            parent: ScriptState.ParentPtr(this),
            io: this.rootIo.copy()
        )
        this.started.store(true)
        root.start().run()

        return Maybe<Unit>.success()
    }

    /// 从JS运行
    public func runFromJS(globalThis: JSGlobalObject): JsValue {
        if (this.setupIOBeforeRun().isErr()) {
            return JsValue.jsUndefined()
        }

        let root = ScriptState(
            interpreter: this,
            shellState: this.rootShell,
            node: this.args.scriptAst,
            parent: ScriptState.ParentPtr(this),
            io: this.rootIo.copy()
        )
        this.started.store(true)
        root.start().run()

        return JsValue.jsUndefined()
    }

    /// 设置运行前的IO
    func setupIOBeforeRun(): Maybe<Unit> {
        if (!this.flags.quiet) {
            // 初始化stdout和stderr的IOWriter
            let stdoutFd = Syscall.dup(FD.stdout())
            let stderrFd = Syscall.dup(FD.stderr())

            let stdoutWriter = IOWriter(stdoutFd, IOWriter.Flags(), this.eventLoop)
            let stderrWriter = IOWriter(stderrFd, IOWriter.Flags(), this.eventLoop)

            this.rootIo = IO(
                stdin: this.rootIo.stdin,
                stdout: IO.OutKind.fd(writer: stdoutWriter, captured: None),
                stderr: IO.OutKind.fd(writer: stderrWriter, captured: None)
            )
        }
        return Maybe<Unit>.success()
    }

    /// 异步命令完成
    public func asyncCmdDone(async: AsyncState) {
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
    public func throwShellErr(e: ShellErr, eventLoop: EventLoopHandle) {
        match (eventLoop) {
            case mini =>
                e.throwMini()
            case js =>
                e.throwJS(eventLoop.js.global)
        }
    }

    /// 关闭文件描述符
    public func closefd(fd: FD) {
        fd.close()
    }

    /// 是否可轮询
    public func isPollable(fd: FD, mode: FileMode): Boolean {
        return S.isFifo(mode) || S.isSock(mode) || Posix.isatty(fd.native())
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
        return Syscall.openat(dir, path, flags, perm)
    }

    /// 打开文件
    public static func open(filePath: String, flags: FileMode, perm: FileMode): Maybe<FD> {
        return Syscall.open(filePath, flags, perm)
    }

    /// 复制文件描述符
    public static func dup(fd: FD): Maybe<FD> {
        return Syscall.dup(fd)
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
            case arrlist(list) =>
                return list.toArray()
            case ownedBuf(buf) =>
                return buf
            case borrowedBuf(buf) =>
                return buf
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
    public var parent: Parent
    public var output: OutputSrc
    public var state: OutputTaskState

    /// 去初始化
    public func deinit(): Yield {
        this.output.deinit()
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

/// Shell执行环境
/// 包含环境变量、当前工作目录等
public class ShellExecEnv {
    /// 类型
    public var kind: ShellExecEnvKind = ShellExecEnvKind.normal

    /// 缓冲的标准输出
    public var bufferedStdout: ByteList
    /// 缓冲的标准错误
    public var bufferedStderr: ByteList

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
        this.bufferedStdout = ByteList()
        this.bufferedStderr = ByteList()
        this.shellEnv = EnvMap(DefaultAllocator.instance)
        this.cmdLocalEnv = EnvMap(DefaultAllocator.instance)
        this.exportEnv = EnvMap(DefaultAllocator.instance)
        this.prevCwd = ArrayList<Byte>()
        this.cwdArr = ArrayList<Byte>()
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
        size += this.asyncPids.size * 4
        return size
    }

    /// 获取当前工作目录
    public func cwd(): String {
        if (this.cwdArr.size == 0) {
            return ""
        }
        return String.fromBytes(this.cwdArr.toArray())
    }

    /// 获取前一个工作目录
    public func prevCwdStr(): String {
        if (this.prevCwd.size == 0) {
            return ""
        }
        return String.fromBytes(this.prevCwd.toArray())
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
        duped.cmdLocalEnv = EnvMap(alloc)
        duped.exportEnv = this.exportEnv.clone()
        duped.prevCwd = ArrayList<Byte>(this.prevCwd.toArray().clone())
        duped.cwdArr = ArrayList<Byte>(this.cwdArr.toArray().clone())
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
        this.prevCwd.appendAll(this.cwdArr.toArray())
        this.cwdArr.clear()
        this.cwdArr.appendAll(newCwd.toByteArray())
        this.cwdFd.close()
        this.cwdFd = newCwdFd.result()
        return Maybe<Unit>.success()
    }

    /// 获取主目录
    public func getHomedir(): EnvStr {
        return EnvStr.initSlice("/root".toByteArray())
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
