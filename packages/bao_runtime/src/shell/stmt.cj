// stmt.cj - 语句执行状态
// 对应 Bun: src/runtime/shell/states/Stmt.zig
// 严格翻译Bun shell语句状态到仓颉

package bao_runtime.shell

import bao_core.*

// ============================================================================
// 语句执行状态
// ============================================================================

/// 语句父节点指针（提取到顶层）
public class StmtParentPtr {
    public var ptr: Any = Option<Any>.None

    public static func initFunc(p: Any): StmtParentPtr {
        let pp = StmtParentPtr()
        pp.ptr = p
        return pp
    }

    public func childDone(child: Any, exitCode: ExitCode): Yield {
        return Yield.done
    }
}

/// 语句子节点指针（提取到顶层）
public class StmtChildPtr {
    public var ptr: Any = Option<Any>.None

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
    public var base: Base = Base()
    /// AST节点
    public var node: Stmt = Stmt([])
    /// 父节点
    public var parent: StmtParentPtr = StmtParentPtr()
    /// 索引
    public var idx: UInt64 = 0
    /// 上一个退出码
    public var lastExitCode: ?ExitCode = None
    /// 当前执行的子节点
    public var currentlyExecuting: ?StmtChildPtr = None
    /// IO
    public var io: IO = IO()

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
        stmt.parent = StmtParentPtr.initFunc(parent)
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
        if (Int64(this.idx) >= this.node.exprs.size) {
            return this.parent.childDone(this, this.lastExitCode ?? ExitCode.exited(0))
        }

        let child = this.node.exprs[Int64(this.idx)]
        match (child.tag) {
            case ExprTag.binary =>
                let binNode = child.binary.getOrThrow()
                let binaryState = BinaryState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    binNode,
                    BinaryParentPtr.initFunc(this),
                    this.io.copy()
                )
                this.currentlyExecuting = StmtChildPtr.initFunc(binaryState)
                return binaryState.start()
            case ExprTag.cmd =>
                let cmdState = CmdState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    child.cmd,
                    CmdParentPtr.initFunc(this),
                    this.io.copy()
                )
                this.currentlyExecuting = StmtChildPtr.initFunc(cmdState)
                return cmdState.start()
            case ExprTag.pipeline =>
                let pipeNode = child.pipeline.getOrThrow()
                let pipeState = PipelineState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    pipeNode,
                    PipelineParentPtr.initFunc(this),
                    this.io.copy()
                )
                this.currentlyExecuting = StmtChildPtr.initFunc(pipeState)
                return pipeState.start()
            case ExprTag.assign =>
                let assignMachine = AssignsState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    child.assign,
                    AssignCtx.shell,
                    AssignsParentPtr.initFunc(this),
                    this.io.copy()
                )
                return assignMachine.start()
            case ExprTag.subshell =>
                let subNode = child.subshell.getOrThrow()
                let subshellState = SubshellState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    subNode,
                    SubshellParentPtr.initFunc(this),
                    this.io.copy()
                )
                return subshellState.start()
            case ExprTag.`if` =>
                let ifNode = child.`if`.getOrThrow()
                let ifState = IfState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    ifNode,
                    IfParentPtr.initFunc(this),
                    this.io.copy()
                )
                return ifState.start()
            case ExprTag.condexpr =>
                let condState = CondExprState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    child.condexpr,
                    CondExprParentPtr.initFunc(this),
                    this.io.copy()
                )
                return condState.start()
            case ExprTag.async =>
                let asyncNode = child.asyncExpr.getOrThrow()
                let asyncCmd = AsyncState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    asyncNode,
                    AsyncParentPtr.initFunc(this),
                    this.io.copy()
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
