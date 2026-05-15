// stmt.cj - 语句执行状态
// 对应 Bun: src/runtime/shell/states/Stmt.zig
// 严格翻译Bun shell语句状态到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// 语句执行状态
// ============================================================================

/// 语句状态
public class StmtState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Stmt
    /// 父节点
    public var parent: ParentPtr
    /// 索引
    public var idx: UInt64 = 0
    /// 上一个退出码
    public var lastExitCode: ?ExitCode = None
    /// 当前执行的子节点
    public var currentlyExecuting: ?ChildPtr = None
    /// IO
    public var io: IO

    /// 父节点指针
    public class ParentPtr {
        public var ptr: Any

        public static func initFunc(p: Any): ParentPtr {
            let pp = ParentPtr()
            pp.ptr = p
            return pp
        }
    }

    /// 子节点指针 - 可以是所有可能的状态类型
    public class ChildPtr {
        public var ptr: Any

        public static func initFunc(p: Any): ChildPtr {
            let cp = ChildPtr()
            cp.ptr = p
            return cp
        }

        public func deinit() {
            // 根据类型去初始化
        }
    }

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Stmt,
        parent: Any,
        io: IO
    ): StmtState {
        let stmt = StmtState()
        stmt.base = Base.initWithNewAllocScope(StateKind.stmt, interpreter, shellState)
        stmt.node = node
        stmt.parent = ParentPtr.init(parent)
        stmt.idx = 0
        stmt.lastExitCode = None
        stmt.currentlyExecuting = None
        stmt.io = io
        return stmt
    }

    /// 启动
    public func start(): Yield {
        return Yield.stmt(this)
    }

    /// 下一步
    public func next(): Yield {
        if (this.idx >= this.node.exprs.length) {
            return this.parent.childDone(this, this.lastExitCode ?? 0)
        }

        let child = this.node.exprs[this.idx]
        switch (child) {
            case .binary =>
                let binary = BinaryState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.binary,
                    parent: BinaryState.ParentPtr.init(this),
                    io: this.io.copy()
                )
                this.currentlyExecuting = ChildPtr.init(binary)
                return binary.start()
            case .cmd =>
                let cmd = CmdState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.cmd,
                    parent: CmdState.ParentPtr.init(this),
                    io: this.io.copy()
                )
                this.currentlyExecuting = ChildPtr.init(cmd)
                return cmd.start()
            case .pipeline =>
                let pipeline = PipelineState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.pipeline,
                    parent: PipelineState.ParentPtr.init(this),
                    io: this.io.copy()
                )
                this.currentlyExecuting = ChildPtr.init(pipeline)
                return pipeline.start()
            case .assign =>
                let assignMachine = AssignsState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.assign,
                    ctx: AssignCtx.shell,
                    parent: AssignsState.ParentPtr.init(this),
                    io: this.io.copy()
                )
                return assignMachine.start()
            case .subshell =>
                let subshell = SubshellState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.subshell,
                    parent: SubshellState.ParentPtr.init(this),
                    io: this.io.copy()
                )
                return subshell.start()
            case .ifClause =>
                let ifClause = IfState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.ifClause,
                    parent: IfState.ParentPtr.init(this),
                    io: this.io.copy()
                )
                return ifClause.start()
            case .condexpr =>
                let condexpr = CondExprState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.condexpr,
                    parent: CondExprState.ParentPtr.init(this),
                    io: this.io.copy()
                )
                return condexpr.start()
            case .async =>
                let async = AsyncState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.async,
                    parent: AsyncState.ParentPtr.init(this),
                    io: this.io.copy()
                )
                return async.start()
        }
    }

    /// 子节点完成
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
        this.lastExitCode = exitCode
        this.idx += 1
        child.deinit()
        this.currentlyExecuting = None
        return this.next()
    }

    /// 去初始化
    public func deinit() {
        this.io.deinit()
        if (let child = this.currentlyExecuting) {
            child.deinit()
        }
        this.base.endScope()
    }
}
