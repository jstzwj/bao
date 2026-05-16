// if.cj - if条件执行状态
// 对应 Bun: src/runtime/shell/states/If.zig
// 严格翻译Bun shell if条件状态到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// if条件执行状态
// ============================================================================

/// if状态类型（提取到顶层）
public enum IfStateKind {
    | idle
    | execKind(execState: IfExecState)
    | waitingWriteErr
    | done
}

/// 内部状态（提取到顶层）
public enum IfInnerState {
    | cond
    | then
    | elif(idx: UInt32)
    | `else`
}

/// 执行状态（提取到顶层）
public struct IfExecState {
    public var execState: IfInnerState
    public var stmts: Array<Stmt>
    public var stmtIdx: UInt32 = 0
    public var lastExitCode: ExitCode = 0

    public init(execState: IfInnerState, stmts: Array<Stmt>, stmtIdx: UInt32, lastExitCode: ExitCode) {
        this.execState = execState
        this.stmts = stmts
        this.stmtIdx = stmtIdx
        this.lastExitCode = lastExitCode
    }
}

/// 父节点指针（提取到顶层）
public class IfParentPtr {
    public var ptr: Any
    public static func initFunc(p: Any): IfParentPtr {
        let pp = IfParentPtr()
        pp.ptr = p
        return pp
    }
    public func childDone(child: Any, exitCode: ExitCode): Yield { Yield.done }
}

/// 子节点指针（提取到顶层）
public class IfChildPtr {
    public var ptr: Any
    public static func initFunc(p: Any): IfChildPtr {
        let cp = IfChildPtr()
        cp.ptr = p
        return cp
    }
    public func deinit() {}
}

/// if条件状态
public class IfState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: IfAst
    /// 父节点
    public var parent: IfParentPtr
    /// IO
    public var io: IO
    /// 状态
    public var state: IfStateKind

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: IfAst,
        parent: IfParentPtr,
        io: IO
    ): IfState {
        let ifStmt = IfState()
        ifStmt.base = Base.initWithNewAllocScope(StateKind.ifClause, interpreter, shellState)
        ifStmt.node = node
        ifStmt.parent = parent
        ifStmt.io = io
        ifStmt.state = IfStateKind.`idle`
        return ifStmt
    }

    /// 启动
    public func start(): Yield {
        return Yield.ifClause(this)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != IfStateKind.done) {
            switch (this.state) {
                case IfStateKind.`idle` =>
                    this.state = IfStateKind.execKind(execState: IfExecState(
                        execState: IfInnerState.cond,
                        stmts: this.node.cond,
                        stmtIdx: 0,
                        lastExitCode: 0
                    ))
                case IfStateKind.execKind(var execState) =>
                    let stmts = execState.stmts
                    if (execState.stmtIdx >= stmts.size) {
                        switch (execState.execState) {
                            case IfInnerState.cond =>
                                if (execState.lastExitCode == 0) {
                                    execState.execState = IfInnerState.then
                                    execState.stmtIdx = 0
                                    execState.stmts = this.node.then
                                    continue
                                }
                                // 检查else/elif
                                return this.parent.childDone(this, 0)
                            case IfInnerState.then =>
                                return this.parent.childDone(this, execState.lastExitCode)
                            case IfInnerState.elif =>
                                return this.parent.childDone(this, 0)
                            case IfInnerState.`else` =>
                                return this.parent.childDone(this, execState.lastExitCode)
                        }
                    }
                    let idx = execState.stmtIdx
                    execState.stmtIdx += 1
                    let stmt = stmts[idx]
                    let newStmt = StmtState.init(
                        interpreter: this.base.interpreter,
                        shellState: this.base.shell,
                        node: stmt,
                        parent: StmtParentPtr.init(this),
                        io: this.io.copy()
                    )
                    return newStmt.start()
                case IfStateKind.waitingWriteErr =>
                    return Yield.suspended
                case IfStateKind.done =>
                    panic("不可达状态")
            }
        }
        return this.parent.childDone(this, 0)
    }

    /// 去初始化
    public func deinit() {
        this.io.deref()
        this.base.endScope()
    }

    /// 子节点完成
    public func childDone(child: IfChildPtr, exitCode: ExitCode): Yield {
        child.deinit()
        return Yield.ifClause(this)
    }
}
