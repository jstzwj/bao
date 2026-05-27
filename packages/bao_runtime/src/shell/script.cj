// script.cj - 脚本执行状态
// 对应 Bun: src/runtime/shell/states/Script.zig
// 严格翻译Bun shell脚本状态到仓颉

package bao_runtime.shell

import bao_core.*

// ============================================================================
// 脚本执行状态
// 用于顶层脚本、展开（命令替换）和子Shell
// ============================================================================

/// 脚本状态类型（提取到顶层）
public enum ScriptStateKind {
| `normal`(UInt64)
}

/// 脚本状态父节点指针（提取到顶层）
public class ScriptParentPtr {
    public var ptr: Any = Option<Any>.None

    public static func initFunc(p: Any): ScriptParentPtr {
        let pp = ScriptParentPtr()
        pp.ptr = p
        return pp
    }

    public func childDone(child: Any, exitCode: ExitCode): Yield {
        return Yield.done
    }
}

/// 脚本状态子节点指针（提取到顶层）
public class ScriptChildPtr {
    public var val: StmtState = StmtState()

    public static func initFunc(child: StmtState): ScriptChildPtr {
        let cp = ScriptChildPtr()
        cp.val = child
        return cp
    }

    public func deinit() {
        this.val.deinit()
    }
}

/// 脚本状态
public class ScriptState {
    /// 基类
    public var base: Base = Base()
    /// AST节点
    public var node: ASTScript = ASTScript([])
    /// IO
    public var io: IO = IO()
    /// 父节点指针
    public var parent: ScriptParentPtr = ScriptParentPtr()
    /// 状态
    public var state: ScriptStateKind = ScriptStateKind.`normal`(0)

    public init() {}

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: ASTScript,
        parentPtr: ScriptParentPtr,
        io: IO
    ): ScriptState {
        let script = ScriptState()
        script.base = Base.initWithNewAllocScope(StateKind.script, interpreter, shellState)
        script.node = node
        script.parent = parentPtr
        script.io = io
        script.state = ScriptStateKind.`normal`(0)
        return script
    }

    /// 启动
    public func start(): Yield {
        if (this.node.stmts.size == 0) {
            return this.finish(ExitCode.exited(0))
        }
        return Yield.script(this)
    }

    /// 下一步
    public func next(): Yield {
        match (this.state) {
            case ScriptStateKind.`normal`(idx) =>
                let idxI64 = Int64(idx)
                if (idxI64 >= this.node.stmts.size) {
                    return Yield.suspended
                }
                let stmtNode = this.node.stmts[idxI64]
                this.state = ScriptStateKind.`normal`(idx + 1)
                let stmt = StmtState.initFunc(
                    this.base.interpreter,
                    this.base.shell,
                    stmtNode,
                    this,
                    this.io.ref()
                )
                return stmt.start()
        }
    }

    /// 完成
    func finish(exitCode: ExitCode): Yield {
        return this.parent.childDone(this, exitCode)
    }

    /// 子节点完成
    public func childDone(child: ScriptChildPtr, exitCode: ExitCode): Yield {
        child.deinit()
        match (this.state) {
            case ScriptStateKind.`normal`(idx) =>
                if (Int64(idx) >= this.node.stmts.size) {
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
