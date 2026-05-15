// script.cj - 脚本执行状态
// 对应 Bun: src/runtime/shell/states/Script.zig
// 严格翻译Bun shell脚本状态到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// 脚本执行状态
// 用于顶层脚本、展开（命令替换）和子Shell
// ============================================================================

/// 脚本状态
public class ScriptState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Script
    /// IO
    public var io: IO
    /// 父节点指针
    public var parent: ParentPtr
    /// 状态
    public var state: ScriptStateKind

    /// 脚本状态类型
    public enum ScriptStateKind {
        case normal(idx: UInt64)
    }

    /// 父节点指针
    public class ParentPtr {
        public var ptr: Any

        public static func initFunc(p: Any): ParentPtr {
            let pp = ParentPtr()
            pp.ptr = p
            return pp
        }
    }

    /// 子节点指针
    public class ChildPtr {
        public var val: StmtState

        public static func initFunc(child: StmtState): ChildPtr {
            let cp = ChildPtr()
            cp.val = child
            return cp
        }

        public func deinit() {
            this.val.deinit()
        }
    }

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Script,
        parentPtr: ParentPtr,
        io: IO
    ): ScriptState {
        let script = ScriptState()
        script.base = Base.initWithNewAllocScope(StateKind.script, interpreter, shellState)
        script.node = node
        script.parent = parentPtr
        script.io = io
        script.state = ScriptStateKind.normal(idx: 0)
        return script
    }

    /// 启动
    public func start(): Yield {
        if (this.node.stmts.length == 0) {
            return this.finish(0)
        }
        return Yield.script(this)
    }

    /// 下一步
    public func next(): Yield {
        switch (this.state) {
            case .normal(let idx) =>
                if (idx >= this.node.stmts.length) {
                    return Yield.suspended
                }
                let stmtNode = this.node.stmts[idx]
                this.state = ScriptStateKind.normal(idx: idx + 1)
                let stmt = StmtState.init(
                    interpreter: this.base.interpreter,
                    shellState: this.base.shell,
                    node: stmtNode,
                    parent: StmtState.ParentPtr.init(this),
                    io: this.io.ref()
                )
                return stmt.start()
        }
    }

    /// 完成
    func finish(exitCode: ExitCode): Yield {
        return this.parent.childDone(this, exitCode)
    }

    /// 子节点完成
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
        child.deinit()
        switch (this.state) {
            case .normal(let idx) =>
                if (idx >= this.node.stmts.length) {
                    return this.finish(exitCode)
                }
                return this.next()
        }
    }

    /// 去初始化
    public func deinit() {
        this.io.deref()
        this.base.endScope()
    }

    /// 从解释器去初始化
    public func deinitFromInterpreter() {
        this.io.deinit()
    }
}
