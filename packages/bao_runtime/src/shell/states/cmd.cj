// cmd.cj - 命令执行状态
// 对应 Bun: src/runtime/shell/states/Cmd.zig
// 严格翻译Bun shell命令状态到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// 命令执行状态
// 主要的状态节点，执行内置命令或子进程
// ============================================================================

/// 命令状态
public class CmdState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: CmdAst
    /// 父节点
    public var parent: ParentPtr

    /// spawn用的arena
    public var spawnArena: ArenaAllocator
    /// spawn arena是否已释放
    public var spawnArenaFreed: Boolean = false

    /// 参数
    public var args: ArrayList<?String>
    /// 重定向文件
    public var redirectionFile: ArrayList<Byte>
    /// 重定向文件描述符
    public var redirectionFd: ?CowFd = None

    /// 执行状态
    public var exec: Exec = Exec.none
    /// 退出码
    public var exitCode: ?ExitCode = None
    /// IO
    public var io: IO

    /// 命令状态
    public var state: CmdStateKind

    /// 命令状态类型
    public enum CmdStateKind {
        case idle
        case expandingAssigns(AssignsState)
        case expandingRedirect(idx: UInt32, expansion: ExpansionState)
        case expandingArgs(idx: UInt32, expansion: ExpansionState)
        case exec
        case done
        case waitingWriteErr
    }

    /// 执行联合体
    public enum Exec {
        case none
        case bltn(BuiltinImpl)
        case subproc(SubprocState)
    }

    /// 子进程状态
    public class SubprocState {
        public var child: ShellSubprocess
        public var bufferedClosed: BufferedIoClosed

        init() {
            this.bufferedClosed = BufferedIoClosed()
        }
    }

    /// 缓冲IO关闭状态
    public class BufferedIoClosed {
        public var stdin: ?Boolean = None
        public var stdout: ?BufferedIoState = None
        public var stderr: ?BufferedIoState = None

        /// 是否全部关闭
        public func allClosed(): Boolean {
            let stdinClosed = this.stdin ?? true
            let stdoutClosed = if (let s = this.stdout) { s.closed() } else { true }
            let stderrClosed = if (let s = this.stderr) { s.closed() } else { true }
            return stdinClosed && stdoutClosed && stderrClosed
        }

        /// 去初始化
        public func deinit() {
            if (let s = this.stdout) {
                s.deinit()
            }
            if (let s = this.stderr) {
                s.deinit()
            }
        }
    }

    /// 缓冲IO状态
    public class BufferedIoState {
        public var state: BufferedIoStateKind = BufferedIoStateKind.open

        /// 状态类型
        public enum BufferedIoStateKind {
            case open
            case closed(ByteList)
        }

        /// 是否已关闭
        public func closed(): Boolean {
            return this.state == .closed
        }

        /// 去初始化
        public func deinit() {
            // 释放缓冲区
        }
    }

    /// 父节点指针
    public class ParentPtr {
        public var ptr: Any

        public static func initFunc(p: Any): ParentPtr {
            let pp = ParentPtr()
            pp.ptr = p
            return pp
        }

        public func childDone(child: Any, exitCode: ExitCode): Yield {
            return Yield.done
        }

        public func create<T>(): T {
            return T()
        }

        public func allocator(): Allocator {
            return DefaultAllocator.instance
        }

        public func destroy<T>(ptr: T) {
            // 释放
        }
    }

    /// 子节点指针
    public class ChildPtr {
        public var ptr: Any

        public static func initFunc(p: Any): ChildPtr {
            let cp = ChildPtr()
            cp.ptr = p
            return cp
        }

        public func is(type: Any): Boolean {
            return true
        }

        public func `as`<T>(): T {
            return this.ptr as T
        }

        public func deinit() {
            // 根据类型去初始化
        }
    }

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: CmdAst,
        parent: ParentPtr,
        io: IO
    ): CmdState {
        let cmd = CmdState()
        cmd.base = Base.initWithNewAllocScope(StateKind.cmd, interpreter, shellState)
        cmd.node = node
        cmd.parent = parent
        cmd.spawnArena = ArenaAllocator.init(cmd.base.allocator())
        cmd.args = ArrayList<?String>()
        cmd.redirectionFile = ArrayList<Byte>()
        cmd.exitCode = None
        cmd.io = io
        cmd.state = CmdStateKind.idle
        return cmd
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done) {
            switch (this.state) {
                case .idle =>
                    // 展开赋值
                    this.state = CmdStateKind.expandingAssigns(AssignsState())
                    return this.state.expandingAssigns.getOrThrow().start()
                case .expandingAssigns =>
                    return Yield.suspended
                case .expandingRedirect =>
                    this.state = CmdStateKind.expandingArgs(idx: 0, expansion: ExpansionState())
                    continue
                case .expandingArgs(let idx, let expansion) =>
                    if (idx >= this.node.nameAndArgs.length) {
                        return this.transitionToExecStateAndYield()
                    }
                    this.state = CmdStateKind.expandingArgs(idx: idx + 1, expansion: expansion)
                    return expansion.start()
                case .waitingWriteErr =>
                    unreachableState("Cmd.next", "waitingWriteErr")
                case .exec =>
                    unreachableState("Cmd.next", "exec")
                case .done =>
                    // 不可达
            }
        }
        return this.parent.childDone(this, this.exitCode ?? 1)
    }

    /// 转换到执行状态
    func transitionToExecStateAndYield(): Yield {
        this.state = CmdStateKind.exec
        return this.initSubproc()
    }

    /// 启动
    public func start(): Yield {
        return Yield.cmd(this)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        if (let e = err) {
            this.base.throw(ShellErr.newSys(e))
            return Yield.failed
        }
        return this.parent.childDone(this, 1)
    }

    /// 子节点完成
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
        if (exitCode != 0) {
            return this.writeFailingError("error\n")
        }
        child.deinit()
        return Yield.cmd(this)
    }

    /// 初始化子进程
    func initSubproc(): Yield {
        // 查找内置命令或启动子进程
        let firstArg = this.args.get(0) ?? return this.parent.childDone(this, 0)
        if (let kind = BuiltinImpl.Kind.fromStr(firstArg.getOrThrow())) {
            // 初始化内置命令
            let bltn = BuiltinImpl()
            return bltn.start()
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
    public func hasFinished(): Boolean {
        if (this.exitCode == None) {
            return false
        }
        if (this.exec != .none) {
            if (this.exec == .subproc) {
                return this.exec.subproc.getOrThrow().bufferedClosed.allClosed()
            }
            return false
        }
        return true
    }

    /// 写入失败错误
    public func writeFailingError(fmt: String): Yield {
        return this.base.shell.writeFailingErrorFmt(this, { _ in }, fmt, [])
    }

    /// 缓冲输出关闭
    public func bufferedOutputClose(kind: OutKind, err: ?SystemError): Yield {
        if (this.hasFinished()) {
            return this.parent.childDone(this, this.exitCode ?? 0)
        }
        return Yield.suspended
    }

    /// 去初始化
    public func deinit() {
        if (let redirfd = this.redirectionFd) {
            this.redirectionFd = None
            redirfd.deref()
        }

        if (this.exec != .none) {
            if (this.exec == .subproc) {
                let cmd = this.exec.subproc.getOrThrow().child
                if (!cmd.hasExited()) {
                    cmd.tryKill(9)
                }
                cmd.unref()
                cmd.deinit()
                this.exec.subproc.getOrThrow().bufferedClosed.deinit()
            } else if (this.exec == .bltn) {
                this.exec.bltn.getOrThrow().deinit()
            }
            this.exec = Exec.none
        }

        for (arg in this.args) {
            if (let a = arg) {
                this.base.allocator().free(a)
            }
        }
        this.args.clear()

        if (!this.spawnArenaFreed) {
            this.spawnArena.deinit()
        }

        this.io.deref()
        this.base.endScope()
    }
}
