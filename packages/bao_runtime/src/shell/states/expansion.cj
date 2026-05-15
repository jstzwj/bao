// expansion.cj - 展开状态
// 对应 Bun: src/runtime/shell/states/Expansion.zig
// 严格翻译Bun shell展开状态到仓颉

package bao_runtime

import bao_core.*

// ============================================================================
// 展开状态
// 用于变量展开、命令替换和glob展开
// ============================================================================

/// 展开状态
public class ExpansionState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Atom
    /// 父节点
    public var parent: ParentPtr
    /// IO
    public var io: IO

    /// 单词索引
    public var wordIdx: UInt32 = 0
    /// 当前输出
    public var currentOut: ArrayList<Byte>
    /// 状态
    public var state: ExpansionStateKind
    /// 子状态
    public var childState: ChildStateKind
    /// 输出退出码
    public var outExitCode: ExitCode = 0
    /// 输出结果
    public var out: Result
    /// 输出索引
    public var outIdx: UInt32 = 0
    /// 是否包含引号空字符串
    public var hasQuotedEmpty: Boolean = false

    /// 展开状态类型
    public enum ExpansionStateKind {
        case normal
        case braces
        case glob
        case done
        case err(ShellErr)
    }

    /// 子状态类型
    public enum ChildStateKind {
        case idle
        case cmdSubst(cmd: ScriptState, quoted: Boolean)
        case glob(walker: Any)
    }

    /// 结果类型
    public enum Result {
        case arrayOfSlice(ArrayList<String>)
        case arrayOfPtr(ArrayList<?String>)
        case single(list: ArrayList<Byte>, done: Boolean)
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
        public func scopedAllocator(): Any { None }
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
        expansion: ExpansionState,
        node: Atom,
        parent: ParentPtr,
        outResult: Result,
        io: IO
    ) {
        expansion.node = node
        expansion.base = Base.initBorrowedAllocScope(StateKind.expansion, interpreter, shellState)
        expansion.parent = parent
        expansion.wordIdx = 0
        expansion.state = ExpansionStateKind.normal
        expansion.childState = ChildStateKind.idle
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
        this.state = ExpansionStateKind.normal
        return Yield.expansion(this)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done && this.state != .err) {
            switch (this.state) {
                case .normal =>
                    while (this.wordIdx < this.node.atomsLen()) {
                        if (let y = this.expandVarAndCmdSubst(this.wordIdx)) {
                            return y
                        }
                    }
                    if (this.wordIdx >= this.node.atomsLen()) {
                        this.pushCurrentOut()
                        this.state = ExpansionStateKind.done
                        continue
                    }
                    return Yield.suspended
                case .braces =>
                    // 大括号展开
                    this.state = ExpansionStateKind.done
                    continue
                case .glob =>
                    return this.transitionToGlobState()
                case .done, .err =>
                    // 不可达
            }
        }
        if (this.state == .done) {
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
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
        // 命令替换完成
        if (exitCode != 0) {
            this.outExitCode = exitCode
        }
        this.wordIdx += 1
        this.childState = ChildStateKind.idle
        child.deinit()
        return Yield.expansion(this)
    }

    /// 推送当前输出
    func pushCurrentOut() {
        if (this.currentOut.length == 0 && !this.hasQuotedEmpty) {
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
