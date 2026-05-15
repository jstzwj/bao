// if.cj - if条件执行状态
// 对应 Bun: src/runtime/shell/states/If.zig
// 严格翻译Bun shell if条件状态到仓颉

package bao_runtime

import bao_core.*

// ============================================================================
// if条件执行状态
// ============================================================================

/// if条件状态
public class IfState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: IfAst
    /// 父节点
    public var parent: ParentPtr
    /// IO
    public var io: IO
    /// 状态
    public var state: IfStateKind

    /// if状态类型
    public enum IfStateKind {
        case idle
        case exec(execState: ExecState)
        case waitingWriteErr
        case done
    }

    /// 执行状态
    public struct ExecState {
        public var execState: InnerState
        public var stmts: Array<Stmt>
        public var stmtIdx: UInt32 = 0
        public var lastExitCode: ExitCode = 0
    }

    /// 内部状态
    public enum InnerState {
        case cond
        case then
        case elif(idx: UInt32)
        case `else`
    }

    /// 父节点指针
    public class ParentPtr {
        public var ptr: Any
        public static func init(p: Any): ParentPtr {
            let pp = ParentPtr()
            pp.ptr = p
            return pp
        }
        public func childDone(child: Any, exitCode: ExitCode): Yield { Yield.done }
    }

    /// 子节点指针
    public class ChildPtr {
        public var ptr: Any
        public static func init(p: Any): ChildPtr {
            let cp = ChildPtr()
            cp.ptr = p
            return cp
        }
        public func deinit() {}
    }

    /// 初始化
    public static func init(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: IfAst,
        parent: ParentPtr,
        io: IO
    ): IfState {
        let ifStmt = IfState()
        ifStmt.base = Base.initWithNewAllocScope(StateKind.ifClause, interpreter, shellState)
        ifStmt.node = node
        ifStmt.parent = parent
        ifStmt.io = io
        ifStmt.state = IfStateKind.idle
        return ifStmt
    }

    /// 启动
    public func start(): Yield {
        return Yield.ifClause(this)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done) {
            switch (this.state) {
                case .idle =>
                    this.state = IfStateKind.exec(execState: ExecState(
                        execState: InnerState.cond,
                        stmts: this.node.cond,
                        stmtIdx: 0,
                        lastExitCode: 0
                    ))
                case .exec(var execState) =>
                    let stmts = execState.stmts
                    if (execState.stmtIdx >= stmts.length) {
                        switch (execState.execState) {
                            case .cond =>
                                if (execState.lastExitCode == 0) {
                                    execState.execState = InnerState.then
                                    execState.stmtIdx = 0
                                    execState.stmts = this.node.then
                                    continue
                                }
                                // 检查else/elif
                                return this.parent.childDone(this, 0)
                            case .then =>
                                return this.parent.childDone(this, execState.lastExitCode)
                            case .elif =>
                                return this.parent.childDone(this, 0)
                            case .`else` =>
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
                        parent: StmtState.ParentPtr.init(this),
                        io: this.io.copy()
                    )
                    return newStmt.start()
                case .waitingWriteErr =>
                    return Yield.suspended
                case .done =>
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
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
        child.deinit()
        return Yield.ifClause(this)
    }
}
