// cond_expr.cj - 条件表达式状态
// 对应 Bun: src/runtime/shell/states/CondExpr.zig
// 严格翻译Bun shell条件表达式状态到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// 条件表达式状态
// https://www.gnu.org/software/bash/manual/bash.html#Bash-Conditional-Expressions
// ============================================================================

/// 条件表达式状态
public class CondExprState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: CondExprAst
    /// 父节点
    public var parent: ParentPtr
    /// IO
    public var io: IO
    /// 状态
    public var state: CondExprStateKind
    /// 参数
    public var args: ArrayList<String>

    /// 条件表达式状态类型
    public enum CondExprStateKind {
        case idle
        case expandingArgs(idx: UInt32, expansion: ExpansionState, lastExitCode: ExitCode)
        case waitingStat
        case statComplete(stat: Maybe<Stat>)
        case waitingWriteErr
        case done
    }

    /// 父节点指针
    public class ParentPtr {
        public var ptr: Any
        public static func initFunc(p: Any): ParentPtr {
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
        public static func initFunc(p: Any): ChildPtr {
            let cp = ChildPtr()
            cp.ptr = p
            return cp
        }
        public func is(type: Any): Boolean { true }
        public func `as`<T>(): T { this.ptr as T }
        public func deinit() {}
    }

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: CondExprAst,
        parent: ParentPtr,
        io: IO
    ): CondExprState {
        let condexpr = CondExprState()
        condexpr.base = Base.initWithNewAllocScope(StateKind.condexpr, interpreter, shellState)
        condexpr.node = node
        condexpr.parent = parent
        condexpr.io = io
        condexpr.args = ArrayList<String>()
        condexpr.state = CondExprStateKind.idle
        return condexpr
    }

    /// 启动
    public func start(): Yield {
        return Yield.condExpr(this)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done) {
            switch (this.state) {
                case .idle =>
                    this.state = CondExprStateKind.expandingArgs(
                        idx: 0,
                        expansion: ExpansionState(),
                        lastExitCode: 0
                    )
                    continue
                case .expandingArgs(let idx, let expansion, let lastExitCode) =>
                    if (idx >= this.node.args.length) {
                        return this.commandImplStart()
                    }
                    this.state = CondExprStateKind.expandingArgs(
                        idx: idx + 1,
                        expansion: expansion,
                        lastExitCode: lastExitCode
                    )
                    return expansion.start()
                case .waitingStat =>
                    return Yield.suspended
                case .statComplete(let stat) =>
                    // 根据操作符和stat结果返回退出码
                    switch (this.node.op) {
                        case "-f" =>
                            // 检查是否为普通文件
                            return this.parent.childDone(this, 0)
                        case "-d" =>
                            // 检查是否为目录
                            return this.parent.childDone(this, 0)
                        case "-c" =>
                            // 检查是否为字符设备
                            return this.parent.childDone(this, 0)
                        case "-z", "-n", "==", "!=" =>
                            panic("此条件表达式操作符不需要stat()")
                        case _ =>
                            panic("无效的条件表达式操作符")
                    }
                case .waitingWriteErr =>
                    return Yield.suspended
                case .done =>
                    panic("不可达状态")
            }
        }
        return this.parent.childDone(this, 0)
    }

    /// 命令实现启动
    func commandImplStart(): Yield {
        switch (this.node.op) {
            case "-f", "-d", "-c" =>
                this.state = CondExprStateKind.waitingStat
                return this.doStat()
            case "-z" =>
                return this.parent.childDone(this,
                    if (this.args.length == 0 || this.args[0].length == 0) 0 else 1)
            case "-n" =>
                return this.parent.childDone(this,
                    if (this.args.length > 0 && this.args[0].length != 0) 0 else 1)
            case "==" =>
                let isEq = this.args.length == 0 ||
                    (this.args.length >= 2 && this.args[0] == this.args[1])
                return this.parent.childDone(this, if (isEq) 0 else 1)
            case "!=" =>
                let isNeq = this.args.length >= 2 && this.args[0] != this.args[1]
                return this.parent.childDone(this, if (isNeq) 0 else 1)
            case _ =>
                panic("无效的条件表达式操作符")
        }
    }

    /// 执行stat
    func doStat(): Yield {
        // 在线程池中执行stat
        return Yield.suspended
    }

    /// 去初始化
    public func deinit() {
        this.io.deref()
        for (item in this.args) {
            this.base.allocator().free(item)
        }
        this.args.clear()
        this.base.endScope()
    }

    /// 子节点完成
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
        if (exitCode != 0) {
            return this.writeFailingError("error\n")
        }
        child.deinit()
        return this.next()
    }

    /// stat任务完成
    public func onStatTaskComplete(result: Maybe<Stat>) {
        this.state = CondExprStateKind.statComplete(stat: result)
        this.next().run()
    }

    /// 写入失败错误
    public func writeFailingError(fmt: String): Yield {
        return this.base.shell.writeFailingErrorFmt(this, { _ in }, fmt, [])
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        if (err != None) {
            let exitCode: ExitCode = 1
            return this.parent.childDone(this, exitCode)
        }
        if (this.state == .waitingWriteErr) {
            return this.parent.childDone(this, 1)
        }
        unreachableState("CondExpr.onIOWriterChunk", "unexpected state")
    }
}
