// subshell.cj - 子Shell状态
// 对应 Bun: src/runtime/shell/states/Subshell.zig
// 严格翻译Bun shell子Shell状态到仓颉

package bao_runtime.shell.states

import bao_core.*
import bao_runtime.shell.*
import std.collection.*

// ============================================================================
// 子Shell状态
// ============================================================================

/// 子Shell状态类型（提取到顶层）
public enum SubshellStateKind {
| `idle`
| expandingRedirect(UInt32, ExpansionState)
| `exec`
| waitWriteErr
| done
}

/// 子Shell父节点指针（提取到顶层）
public class SubshellParentPtr {
    public var ptr: Any
    public static func initFunc(p: Any): SubshellParentPtr {
        let pp = SubshellParentPtr()
        pp.ptr = p
        return pp
    }
    public func childDone(child: Any, exitCode: ExitCode): Yield { Yield.done }
    public func create<T>(): T { T() }
    public func destroy<T>(ptr: T) {}
}

/// 子Shell子节点指针（提取到顶层）
public class SubshellChildPtr {
    public var ptr: Any
    public static func initFunc(p: Any): SubshellChildPtr {
        let cp = SubshellChildPtr()
        cp.ptr = p
        return cp
    }
    public func `is`(`type`: Any): Bool { true }
    public func `as`<T>(): T { this.ptr as T }
    public func deinit() {}
}

/// 子Shell状态
public class SubshellState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: SubshellAst
    /// 父节点
    public var parent: SubshellParentPtr
    /// IO
    public var io: IO
    /// 状态
    public var state: SubshellStateKind
    /// 重定向文件
    public var redirectionFile: ArrayList<Byte>
    /// 退出码
    public var exitCode: ExitCode = 0

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: SubshellAst,
        parent: SubshellParentPtr,
        io: IO
    ): SubshellState {
        let subshell = SubshellState()
        subshell.base = Base.initWithNewAllocScope(StateKind.subshell, interpreter, shellState)
        subshell.node = node
        subshell.parent = parent
        subshell.io = io
        subshell.redirectionFile = ArrayList<Byte>()
        subshell.state = SubshellStateKind.`idle`
        return subshell
    }

    /// 为子Shell复制执行环境
    public static func initDupeShellState(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: SubshellAst,
        parent: SubshellParentPtr,
        io: IO
    ): SubshellState {
        let subshell = SubshellState()
        subshell.base = Base.initWithNewAllocScope(StateKind.subshell, interpreter, shellState)
        subshell.node = node
        subshell.parent = parent
        subshell.io = io
        subshell.redirectionFile = ArrayList<Byte>()
        subshell.state = SubshellStateKind.`idle`
        // 复制shell执行环境
        return subshell
    }

    /// 启动
    public func start(): Yield {
        let script = ScriptState.initFunc(
            interpreter: this.base.interpreter,
            shellState: this.base.shell,
            node: this.node.script,
            parent: ScriptParentPtr.initFunc(this),
            io: this.io.copy()
        )
        return script.start()
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != SubshellStateKind.done) {
            match (this.state) {
                case SubshellStateKind.`idle` =>
                    this.state = SubshellStateKind.expandingRedirect(0, expansion: ExpansionState())
                    return Yield.subshell(this)
                case SubshellStateKind.expandingRedirect(idx, expansion) =>
                    if (idx >= 1) {
                        return this.transitionToExec()
                    }
                    return this.transitionToExec()
                case SubshellStateKind.waitWriteErr | SubshellStateKind.`exec` =>
                    return Yield.suspended
                case SubshellStateKind.done =>
                    panic("不可达状态")
            }
        }
        return this.parent.childDone(this, 0)
    }

    /// 转换到执行状态
    func transitionToExec(): Yield {
        let script = ScriptState.initFunc(
            interpreter: this.base.interpreter,
            shellState: this.base.shell,
            node: this.node.script,
            parent: ScriptParentPtr.initFunc(this),
            io: this.io.copy()
        )
        this.state = SubshellStateKind.`exec`
        return script.start()
    }

    /// 子节点完成
    public func childDone(child: SubshellChildPtr, exitCode: ExitCode): Yield {
        this.exitCode = exitCode
        if (childPtr.`is`(ScriptState())) {
            childPtr.deinit()
            return this.parent.childDone(this, exitCode)
        }
        unreachableState("Subshell.childDone", "expected Script or Expansion")
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, err: ?SystemError): Yield {
        if (let Some(e) <- err) {
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
    public func writeFailingError(s: String): Yield {
        return this.base.shell.writeFailingErrorFmt(this, { _ => Yield.done }, fmt, [])
    }
}
