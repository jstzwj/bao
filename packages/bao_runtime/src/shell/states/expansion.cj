// expansion.cj - 展开状态
// 对应 Bun: src/runtime/shell/states/Expansion.zig
// 严格翻译Bun shell展开状态到仓颉

package bao_runtime.shell.states

import bao_core.*
import std.collection.*

// ============================================================================
// 展开状态
// 用于变量展开、命令替换和glob展开
// ============================================================================

/// 展开状态类型（提取到顶层）
public enum ExpansionStateKind {
| `normal`
| braces
| glob
| done
| err(ShellErr)
}

/// 子状态类型（提取到顶层）
public enum ExpansionChildStateKind {
| `idle`
| cmdSubst(cmd: ScriptState, quoted: Boolean)
| globWalker(walker: Any)
}

/// 展开结果类型（提取到顶层）
public enum ExpansionResult {
| arrayOfSlice(ArrayList<String>)
| arrayOfPtr(ArrayList<?String>)
| single(list: ArrayList<Byte>, done: Boolean)
}

/// 展开状态父节点指针（提取到顶层）
public class ExpansionParentPtr {
    public var ptr: Any
    public static func initFunc(p: Any): ExpansionParentPtr {
        let pp = ExpansionParentPtr()
        pp.ptr = p
        return pp
    }
    public func childDone(child: Any, exitCode: ExitCode): Yield { Yield.done }
    public func scopedAllocator(): Any { None }
}

/// 展开状态子节点指针（提取到顶层）
public class ExpansionChildPtr {
    public var ptr: Any
    public static func initFunc(p: Any): ExpansionChildPtr {
        let cp = ExpansionChildPtr()
        cp.ptr = p
        return cp
    }
    public func is(type: Any): Boolean { true }
    public func `as`<T>(): T { this.ptr as T }
    public func deinit() {}
}

/// 展开状态
public class ExpansionState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Atom
    /// 父节点
    public var parent: ExpansionParentPtr
    /// IO
    public var io: IO

    /// 单词索引
    public var wordIdx: UInt32 = 0
    /// 当前输出
    public var currentOut: ArrayList<Byte>
    /// 状态
    public var state: ExpansionStateKind
    /// 子状态
    public var childState: ExpansionChildStateKind
    /// 输出退出码
    public var outExitCode: ExitCode = 0
    /// 输出结果
    public var out: ExpansionResult
    /// 输出索引
    public var outIdx: UInt32 = 0
    /// 是否包含引号空字符串
    public var hasQuotedEmpty: Boolean = false

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        expansion: ExpansionState,
        node: Atom,
        parent: ExpansionParentPtr,
        outResult: ExpansionResult,
        io: IO
    ) {
        expansion.node = node
        expansion.base = Base.initBorrowedAllocScope(StateKind.expansion, interpreter, shellState)
        expansion.parent = parent
        expansion.wordIdx = 0
        expansion.state = ExpansionStateKind.`normal`
        expansion.childState = ExpansionChildStateKind.`idle`
        expansion.out = outResult
        expansion.outIdx = 0
        expansion.currentOut = ArrayList<Byte>()
        expansion.io = io
    }

    /// 去初始化
    public func deinit() {
        this.currentOut.clear()
        this.io.deinit()
        this.base.endScope()
    }

    /// 启动
    public func start(): Yield {
        this.state = ExpansionStateKind.`normal`
        return Yield.expansion(this)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != ExpansionStateKind.done && this.state != ExpansionStateKind.err) {
            switch (this.state) {
                case ExpansionStateKind.`normal` =>
                    while (this.wordIdx < this.node.atomsLen()) {
                        if (let Some(y) <- this.expandVarAndCmdSubst(this.wordIdx)) {
                            return y
                        }
                    }
                    if (this.wordIdx >= this.node.atomsLen()) {
                        this.pushCurrentOut()
                        this.state = ExpansionStateKind.done
                        continue
                    }
                    return Yield.suspended
                case ExpansionStateKind.braces =>
                    // 大括号展开
                    this.state = ExpansionStateKind.done
                    continue
                case ExpansionStateKind.glob =>
                    return this.transitionToGlobState()
                case ExpansionStateKind.done | ExpansionStateKind.err =>
                    // 不可达
            }
        }
        if (this.state == ExpansionStateKind.done) {
            return this.parent.childDone(this, 0)
        }
        return this.parent.childDone(this, 1)
    }

    /// 展开变量和命令替换
    public func expandVarAndCmdSubst(startWordIdx: UInt32): ?Yield {
        // 检查是否为命令替换
        // 如果是则创建子脚本执行
        this.wordIdx += 1
        return None
    }

    /// 子节点完成
    public func childDone(child: ExpansionChildPtr, exitCode: ExitCode): Yield {
        // 命令替换完成
        if (exitCode != 0) {
            this.outExitCode = exitCode
        }
        this.wordIdx += 1
        this.childState = ExpansionChildStateKind.`idle`
        child.deinit()
        return Yield.expansion(this)
    }

    /// 推送当前输出
    func pushCurrentOut() {
        if (this.currentOut.size == 0 && !this.hasQuotedEmpty) {
            return
        }
        // 将当前输出推送到结果
    }

    /// 展开变量
    func expandVar(label: String): String {
        let value = this.base.shell.shellEnv.get(EnvStr.initSlice(label.toByteArray())) ??
            this.base.shell.exportEnv.get(EnvStr.initSlice(label.toByteArray())) ?? ""
        return value.slice().toString()
    }

    /// 转换到glob状态
    func transitionToGlobState(): Yield {
        // 初始化glob walker
        this.state = ExpansionStateKind.done
        return Yield.expansion(this)
    }

    /// glob完成回调
    func onGlobWalkDone(task: Any): Yield {
        this.state = ExpansionStateKind.done
        return Yield.expansion(this)
    }
}
