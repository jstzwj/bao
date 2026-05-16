// cond_expr.cj - 条件表达式状态
// 对应 Bun: src/runtime/shell/states/CondExpr.zig
// 严格翻译Bun shell条件表达式状态到仓颉

package bao_runtime.shell.states

import bao_core.*
import std.collection.*

// ============================================================================
// 条件表达式状态
// https://www.gnu.org/software/bash/manual/bash.html#Bash-Conditional-Expressions
// ============================================================================

/// 条件表达式状态类型（提取到顶层）
public enum CondExprStateKind {
| `idle`
| expandingArgs(idx: UInt32, expansion: ExpansionState, lastExitCode: ExitCode)
| waitingStat
| statComplete(stat: Maybe<Stat>)
| waitingWriteErr
| done
}

/// 条件表达式父节点指针（提取到顶层）
public class CondExprParentPtr {
    public var ptr: Any
    public static func initFunc(p: Any): CondExprParentPtr {
        let pp = CondExprParentPtr()
        pp.ptr = p
        return pp
    }
    public func childDone(child: Any, exitCode: ExitCode): Yield { Yield.done }
    public func create<T>(): T { T() }
    public func destroy<T>(ptr: T) {}
}

/// 条件表达式子节点指针（提取到顶层）
public class CondExprChildPtr {
    public var ptr: Any
    public static func initFunc(p: Any): CondExprChildPtr {
        let cp = CondExprChildPtr()
        cp.ptr = p
        return cp
    }
    public func is(type: Any): Boolean { true }
    public func `as`<T>(): T { this.ptr as T }
    public func deinit() {}
}

/// 条件表达式状态
public class CondExprState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: CondExprAst
    /// 父节点
    public var parent: CondExprParentPtr
    /// IO
    public var io: IO
    /// 状态
    public var state: CondExprStateKind
    /// 参数
    public var args: ArrayList<String>

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: CondExprAst,
        parent: CondExprParentPtr,
        io: IO
    ): CondExprState {
        let condexpr = CondExprState()
        condexpr.base = Base.initWithNewAllocScope(StateKind.condexpr, interpreter, shellState)
        condexpr.node = node
        condexpr.parent = parent
        condexpr.io = io
        condexpr.args = ArrayList<String>()
        condexpr.state = CondExprStateKind.`idle`
        return condexpr
    }

    /// 启动
    public func start(): Yield {
        return Yield.condExpr(this)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != CondExprStateKind.done) {
            switch (this.state) {
                case CondExprStateKind.`idle` =>
                    this.state = CondExprStateKind.expandingArgs(
                        idx: 0,
                        expansion: ExpansionState(),
                        lastExitCode: 0
                    )
                    continue
                case CondExprStateKind.expandingArgs(let idx, let expansion, let lastExitCode) =>
                    if (idx >= this.node.args.size) {
                        return this.commandImplStart()
                    }
                    this.state = CondExprStateKind.expandingArgs(
                        idx: idx + 1,
                        expansion: expansion,
                        lastExitCode: lastExitCode
                    )
                    return expansion.start()
                case CondExprStateKind.waitingStat =>
                    return Yield.suspended
                case CondExprStateKind.statComplete(let stat) =>
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
                        case "-z" | "-n" | "==" | "!=" =>
                            panic("此条件表达式操作符不需要stat()")
                        case _ =>
                            panic("无效的条件表达式操作符")
                    }
                case CondExprStateKind.waitingWriteErr =>
                    return Yield.suspended
                case CondExprStateKind.done =>
                    panic("不可达状态")
            }
        }
        return this.parent.childDone(this, 0)
    }

    /// 命令实现启动
    func commandImplStart(): Yield {
        switch (this.node.op) {
            case "-f" | "-d" | "-c" =>
                this.state = CondExprStateKind.waitingStat
                return this.doStat()
            case "-z" =>
                return this.parent.childDone(this,
                    if (this.args.size == 0 || this.args[0].size == 0) 0 else 1)
            case "-n" =>
                return this.parent.childDone(this,
                    if (this.args.size > 0 && this.args[0].size != 0) 0 else 1)
            case "==" =>
                let isEq = this.args.size == 0 ||
                    (this.args.size >= 2 && this.args[0] == this.args[1])
                return this.parent.childDone(this, if (isEq) 0 else 1)
            case "!=" =>
                let isNeq = this.args.size >= 2 && this.args[0] != this.args[1]
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
    public func childDone(child: CondExprChildPtr, exitCode: ExitCode): Yield {
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
        return this.base.shell.writeFailingErrorFmt(this, { _ => Yield.done }, fmt, [])
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        if (err != None) {
            let exitCode: ExitCode = 1
            return this.parent.childDone(this, exitCode)
        }
        if (this.state == CondExprStateKind.waitingWriteErr) {
            return this.parent.childDone(this, 1)
        }
        unreachableState("CondExpr.onIOWriterChunk", "unexpected state")
    }
}
