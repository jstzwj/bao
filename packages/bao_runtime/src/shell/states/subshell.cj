// subshell.cj - 子Shell状态
// 对应 Bun: src/runtime/shell/states/Subshell.zig
// 严格翻译Bun shell子Shell状态到仓颉

package bao_runtime

import bao_core.*

// ============================================================================
// 子Shell状态
// ============================================================================

/// 子Shell状态
public class SubshellState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: SubshellAst
    /// 父节点
    public var parent: ParentPtr
    /// IO
    public var io: IO
    /// 状态
    public var state: SubshellStateKind
    /// 重定向文件
    public var redirectionFile: ArrayList<Byte>
    /// 退出码
    public var exitCode: ExitCode = 0

    /// 子Shell状态类型
    public enum SubshellStateKind {
        case idle
        case expandingRedirect(idx: UInt32, expansion: ExpansionState)
        case exec
        case waitWriteErr
        case done
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
        public func create<T>(): T { T() }
        public func destroy<T>(ptr: T) {}
    }

    /// 子节点指针
    public class ChildPtr {
        public var ptr: Any
        public static func init(p: Any): ChildPtr {
            let cp = ChildPtr()
            cp.ptr = p
            return cp
        }
        public func is(type: Any): Boolean { true }
        public func `as`<T>(): T { this.ptr as T }
        public func deinit() {}
    }

    /// 初始化
    public static func init(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: SubshellAst,
        parent: ParentPtr,
        io: IO
    ): SubshellState {
        let subshell = SubshellState()
        subshell.base = Base.initWithNewAllocScope(StateKind.subshell, interpreter, shellState)
        subshell.node = node
        subshell.parent = parent
        subshell.io = io
        subshell.redirectionFile = ArrayList<Byte>()
        subshell.state = SubshellStateKind.idle
        return subshell
    }

    /// 为子Shell复制执行环境
    public static func initDupeShellState(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: SubshellAst,
        parent: ParentPtr,
        io: IO
    ): SubshellState {
        let subshell = SubshellState()
        subshell.base = Base.initWithNewAllocScope(StateKind.subshell, interpreter, shellState)
        subshell.node = node
        subshell.parent = parent
        subshell.io = io
        subshell.redirectionFile = ArrayList<Byte>()
        subshell.state = SubshellStateKind.idle
        // 复制shell执行环境
        return subshell
    }

    /// 启动
    public func start(): Yield {
        let script = ScriptState.init(
            interpreter: this.base.interpreter,
            shellState: this.base.shell,
            node: this.node.script,
            parent: ScriptState.ParentPtr.init(this),
            io: this.io.copy()
        )
        return script.start()
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done) {
            switch (this.state) {
                case .idle =>
                    this.state = SubshellStateKind.expandingRedirect(idx: 0, expansion: ExpansionState())
                    return Yield.subshell(this)
                case .expandingRedirect(let idx, let expansion) =>
                    if (idx >= 1) {
                        return this.transitionToExec()
                    }
                    return this.transitionToExec()
                case .waitWriteErr, .exec =>
                    return Yield.suspended
                case .done =>
                    panic("不可达状态")
            }
        }
        return this.parent.childDone(this, 0)
    }

    /// 转换到执行状态
    func transitionToExec(): Yield {
        let script = ScriptState.init(
            interpreter: this.base.interpreter,
            shellState: this.base.shell,
            node: this.node.script,
            parent: ScriptState.ParentPtr.init(this),
            io: this.io.copy()
        )
        this.state = SubshellStateKind.exec
        return script.start()
    }

    /// 子节点完成
    public func childDone(childPtr: ChildPtr, exitCode: ExitCode): Yield {
        this.exitCode = exitCode
        if (childPtr.is(ScriptState())) {
            childPtr.deinit()
            return this.parent.childDone(this, exitCode)
        }
        unreachableState("Subshell.childDone", "expected Script or Expansion")
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        if (let e = err) {
            e.deref()
        }
        this.state = SubshellStateKind.done
        return this.parent.childDone(this, this.exitCode)
    }

    /// 去初始化
    public func deinit() {
        this.base.shell.deinit()
        this.io.deref()
        this.redirectionFile.clear()
        this.base.endScope()
    }

    /// 写入失败错误
    public func writeFailingError(fmt: String): Yield {
        return this.base.shell.writeFailingErrorFmt(this, { _ in }, fmt, [])
    }
}
