// stmt.cj - 语句执行状态
// 对应 Bun: src/runtime/shell/states/Stmt.zig
// 严格翻译Bun shell语句状态到仓颉

package bao_runtime.shell.states

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// 语句执行状态
// ============================================================================

/// 语句父节点指针（提取到顶层）
public class StmtParentPtr {
    public var ptr: Any

    public static func initFunc(p: Any): StmtParentPtr {
        let pp = StmtParentPtr()
        pp.ptr = p
        return pp
    }
}

/// 语句子节点指针（提取到顶层）
public class StmtChildPtr {
    public var ptr: Any

    public static func initFunc(p: Any): StmtChildPtr {
        let cp = StmtChildPtr()
        cp.ptr = p
        return cp
    }

    public func deinit() {
        // 根据类型去初始化
    }
}

/// 语句状态
public class StmtState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Stmt
    /// 父节点
    public var parent: StmtParentPtr
    /// 索引
    public var idx: UInt64 = 0
    /// 上一个退出码
    public var lastExitCode: ?ExitCode = None
    /// 当前执行的子节点
    public var currentlyExecuting: ?StmtChildPtr = None
    /// IO
    public var io: IO

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
        stmt.parent = StmtParentPtr.`init`(parent)
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
        if (this.idx >= this.node.exprs.size) {
            return this.parent.childDone(this, this.lastExitCode ?? 0)
        }

        let child = this.node.exprs[this.idx]
        match (child) {
            case binary =>
                let binary = BinaryState.initFunc(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.binary,
                    parent: BinaryParentPtr.initFunc(this),
                    io: this.io.copy()
                )
                this.currentlyExecuting = StmtChildPtr.initFunc(binary)
                return binary.start()
            case cmd =>
                let cmd = CmdState.initFunc(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.cmd,
                    parent: CmdParentPtr.initFunc(this),
                    io: this.io.copy()
                )
                this.currentlyExecuting = StmtChildPtr.initFunc(cmd)
                return cmd.start()
            case pipeline =>
                let pipeline = PipelineState.initFunc(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.pipeline,
                    parent: PipelineParentPtr.initFunc(this),
                    io: this.io.copy()
                )
                this.currentlyExecuting = StmtChildPtr.initFunc(pipeline)
                return pipeline.start()
            case assign =>
                let assignMachine = AssignsState.initFunc(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.assign,
                    ctx: AssignCtx.shell,
                    parent: AssignsParentPtr.initFunc(this),
                    io: this.io.copy()
                )
                return assignMachine.start()
            case subshell =>
                let subshell = SubshellState.initFunc(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.subshell,
                    parent: SubshellParentPtr.initFunc(this),
                    io: this.io.copy()
                )
                return subshell.start()
            case ifClause =>
                let ifClause = IfState.initFunc(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.ifClause,
                    parent: IfParentPtr.initFunc(this),
                    io: this.io.copy()
                )
                return ifClause.start()
            case condexpr =>
                let condexpr = CondExprState.initFunc(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.condexpr,
                    parent: CondExprParentPtr.initFunc(this),
                    io: this.io.copy()
                )
                return condexpr.start()
            case async =>
                let asyncCmd = AsyncState.initFunc(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: child.async,
                    parent: AsyncParentPtr.initFunc(this),
                    io: this.io.copy()
                )
                return asyncCmd.start()
        }
    }

    /// 子节点完成
    public func childDone(child: StmtChildPtr, exitCode: ExitCode): Yield {
        this.lastExitCode = exitCode
        this.idx += 1
        child.deinit()
        this.currentlyExecuting = None
        return this.next()
    }

    /// 去初始化
    public func deinit() {
        this.io.deinit()
        if (let Some(child) <- this.currentlyExecuting) {
            child.deinit()
        }
        this.base.endScope()
    }
}
