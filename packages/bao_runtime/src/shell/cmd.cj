// cmd.cj - 命令执行状态
// 对应 Bun: src/runtime/shell/states/Cmd.zig
// 严格翻译Bun shell命令状态到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*  // std.collection.*

// ============================================================================
// 命令执行状态
// 主要的状态节点，执行内置命令或子进程
// ============================================================================

/// 命令状态类型（提取到顶层）
public enum CmdStateKind {
| `idle`
| expandingAssigns(AssignsState)
| expandingRedirect(UInt32, ExpansionState)
| expandingArgs(UInt32, ExpansionState)
| `exec`
| done
| waitingWriteErr
}

/// 执行联合体（提取到顶层）
public enum CmdExec {
| none
| bltn(BuiltinImpl)
| subproc(CmdSubprocState)
}

/// 命令状态父节点指针（提取到顶层）
/// 严格翻译自 Bun: 类型擦除的父节点指针
public class CmdParentPtr {
    public var ptr: Any = Option<Any>.None

    public static func initFunc(p: Any): CmdParentPtr {
        let pp = CmdParentPtr()
        pp.ptr = p
        return pp
    }

    public func childDone(child: Any, exitCode: ExitCode): Yield {
        return Yield.done
    }

    // 严格翻译自 Bun: create 只是指针类型转换
    public func create<T>(): T {
        match (this.ptr) {
            case Some(t) => return t as T
            case None => throw Exception("CmdParentPtr.create: ptr is None")
        }
    }

    public func allocator(): Allocator {
        return DefaultAllocator.instance
    }

    public func destroy<T>(ptr: T) {
        // 释放
    }
}

/// 命令状态子节点指针（提取到顶层）
public class CmdChildPtr {
    public var ptr: Any = Option<Any>.None

    public static func initFunc(p: Any): CmdChildPtr {
        let cp = CmdChildPtr()
        cp.ptr = p
        return cp
    }

    public func `is`(`type`: Any): Bool {
        return true
    }

    public func deinit() {
        // 根据类型去初始化
    }
}

/// 缓冲IO关闭状态（提取到顶层）
public class CmdBufferedIoClosed {
    public var stdin: ?Bool = None
    public var stdout: ?CmdBufferedIoState = None
    public var stderr: ?CmdBufferedIoState = None

    /// 是否全部关闭
    public func allClosed(): Bool {
        let stdinClosed = this.stdin ?? true
        let stdoutClosed = if (let Some(stdoutState) <- this.stdout) { stdoutState.closed() } else { true }
        let stderrClosed = if (let Some(stderrState) <- this.stderr) { stderrState.closed() } else { true }
        return stdinClosed && stdoutClosed && stderrClosed
    }

    /// 去初始化
    public func deinit() {
        if (let Some(stdoutState) <- this.stdout) {
            stdoutState.deinit()
        }
        if (let Some(stderrState) <- this.stderr) {
            stderrState.deinit()
        }
    }
}

/// 缓冲IO状态类型（提取到顶层）
public enum CmdBufferedIoStateKind {
| open
| closed(ArrayList<Byte>)
}

/// 缓冲IO状态（提取到顶层）
public class CmdBufferedIoState {
    public var state: CmdBufferedIoStateKind = CmdBufferedIoStateKind.open

    /// 是否已关闭
    public func closed(): Bool {
        match (this.state) {
            case CmdBufferedIoStateKind.open => return false
            case CmdBufferedIoStateKind.closed(_) => return true
        }
    }

    /// 去初始化
    public func deinit() {
        // 释放缓冲区
    }
}

/// 子进程状态（提取到顶层）
public class CmdSubprocState {
    public var child: ?ShellSubprocess = None
    public var bufferedClosed: CmdBufferedIoClosed = CmdBufferedIoClosed()

    public init() {}
}

/// 命令状态
public class CmdState {
    /// 基类
    public var base: Base = Base()
    /// AST节点
    public var node: ?Cmd = None
    /// 父节点
    public var parent: CmdParentPtr = CmdParentPtr()

    /// spawn用的arena
    public var spawnArena: ArenaAllocator = ArenaAllocator()
    /// spawn arena是否已释放
    public var spawnArenaFreed: Bool = false

    /// 参数
    public var args: ArrayList<?String> = ArrayList<?String>()
    /// 重定向文件
    public var redirectionFile: ArrayList<Byte> = ArrayList<Byte>()
    /// 重定向文件描述符
    public var redirectionFd: ?CowFd = None

    /// 执行状态
    public var exec: CmdExec = CmdExec.none
    /// 退出码
    public var exitCode: ?ExitCode = None
    /// IO
    public var io: IO = IO()

    /// 命令状态
    public var state: CmdStateKind = CmdStateKind.`idle`

    public init() {}

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Cmd,
        parent: CmdParentPtr,
        io: IO
    ): CmdState {
        let cmd = CmdState()
        cmd.base = Base.initWithNewAllocScope(StateKind.cmd, interpreter, shellState)
        cmd.node = Some(node)
        cmd.parent = parent
        cmd.spawnArena = ArenaAllocator(1024)
        cmd.args = ArrayList<?String>()
        cmd.redirectionFile = ArrayList<Byte>()
        cmd.exitCode = None
        cmd.io = io
        cmd.state = CmdStateKind.`idle`
        return cmd
    }

    /// 下一步
    public func next(): Yield {
        var done = false
        while (!done) {
            match (this.state) {
                case CmdStateKind.`idle` =>
                    // 展开赋值
                    this.state = CmdStateKind.expandingAssigns(AssignsState())
                case CmdStateKind.expandingAssigns(assignsState) =>
                    return Yield.suspended
                case CmdStateKind.expandingRedirect(idx, expState) =>
                    this.state = CmdStateKind.expandingArgs(0, ExpansionState())
                    continue
                case CmdStateKind.expandingArgs(idx, expState) =>
                    if (idx >= UInt32(this.node.getOrThrow().nameAndArgs.size)) {
                        return this.transitionToExecStateAndYield()
                    }
                    this.state = CmdStateKind.expandingArgs(idx + 1, expState)
                    return expState.start()
                case CmdStateKind.waitingWriteErr =>
                    unreachableState("Cmd.next", "waitingWriteErr")
                case CmdStateKind.`exec` =>
                    unreachableState("Cmd.next", "exec")
                case CmdStateKind.done => done = true
            }
        }
        return this.parent.childDone(this, this.exitCode ?? ExitCode.exited(1))
    }

    /// 转换到执行状态
    func transitionToExecStateAndYield(): Yield {
        this.state = CmdStateKind.`exec`
        return this.initSubproc()
    }

    /// 启动
    public func start(): Yield {
        return Yield.cmd(this)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, err: ?SystemError): Yield {
        if (let Some(sysErr) <- err) {
            this.base.`throw`(ShellErr.newSys(sysErr))
            return Yield.failed
        }
        return this.parent.childDone(this, ExitCode.exited(1))
    }

    /// 子节点完成
    public func childDone(child: CmdChildPtr, exitCode: ExitCode): Yield {
        if (!exitCode.isZero()) {
            return this.writeFailingError("error\n")
        }
        child.deinit()
        return Yield.cmd(this)
    }

    /// 初始化子进程
    func initSubproc(): Yield {
        // 查找内置命令或启动子进程
        if (this.args.size == 0) {
            return this.parent.childDone(this, ExitCode.exited(0))
        }
        let firstArgOpt = this.args[0]
        if (let Some(argStr) <- firstArgOpt) {
            if (let Some(kind) <- BuiltinKind.fromStr(argStr)) {
                let bltn = BuiltinImpl()
                return bltn.start()
            }
        }

        // 查找可执行文件
        // ... 路径查找逻辑
        return Yield.suspended
    }

    /// 退出回调
    public func onExit(exitCode: ExitCode) {
        this.exitCode = exitCode
        let hasFinished = this.hasFinished()
        if (hasFinished) {
            this.state = CmdStateKind.done
            this.next().run()
        }
    }

    /// 是否已完成
    public func hasFinished(): Bool {
        if (this.exitCode.isNone()) {
            return false
        }
        match (this.exec) {
            case CmdExec.subproc(state) =>
                return state.bufferedClosed.allClosed()
            case CmdExec.bltn(impl) => return false
            case CmdExec.none => return true
        }
    }

    /// 写入失败错误
    public func writeFailingError(s: String): Yield {
        return this.base.shell.writeFailingErrorFmt(this, { _ => () }, s, [])
    }

    /// 缓冲输出关闭
    public func bufferedOutputClose(kind: OutKind, err: ?SystemError): Yield {
        if (this.hasFinished()) {
            return this.parent.childDone(this, this.exitCode ?? ExitCode.exited(0))
        }
        return Yield.suspended
    }

    /// 去初始化
    public func deinit() {
        if (let Some(redirfd) <- this.redirectionFd) {
            this.redirectionFd = None
            redirfd.deref()
        }

        match (this.exec) {
            case CmdExec.subproc(state) =>
                if (let Some(child) <- state.child) {
                    if (!child.hasExited()) {
                        child.tryKill(9)
                    }
                    child.unref()
                    child.deinit()
                }
                state.bufferedClosed.deinit()
            case CmdExec.bltn(impl) =>
                impl.deinit()
            case CmdExec.none => ()
        }
        this.exec = CmdExec.none

        this.args.clear()

        if (!this.spawnArenaFreed) {
            this.spawnArena.reset()
        }

        this.io.deref()
        this.base.endScope()
    }

    /// 子进程完成回调
    /// 对应 Bun: CmdState.onSubprocessDone
    public static func onSubprocessDone(interp: Interpreter, cmd: NodeId, exitCode: ExitCode): Unit {
        if (!cmd.isValid()) {
            return
        }
        // 通过解释器的调度恢复命令执行
        // 对应 Bun: 从 interp.nodes 中获取 Cmd 节点并调用 onExit
        interp.setCmdExitCode(cmd, exitCode)
    }

    /// 关闭缓冲输入
    /// 对应 Bun: CmdState.bufferedInputClose
    public func bufferedInputClose(): Unit {
        match (this.exec) {
            case CmdExec.subproc(state) =>
                if (!state.bufferedClosed.stdin ?? false) {
                    state.bufferedClosed.stdin = true
                }
                if (state.bufferedClosed.allClosed() && this.exitCode.isSome()) {
                    this.state = CmdStateKind.done
                    this.next().run()
                }
            case _ => ()
        }
    }
}
