// cond_expr.cj - 条件表达式状态
// 对应 Bun: src/runtime/shell/states/CondExpr.zig
// 严格翻译Bun shell条件表达式状态到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*  // std.collection.*

// ============================================================================
// 条件表达式状态
// https://www.gnu.org/software/bash/manual/bash.html#Bash-Conditional-Expressions
// ============================================================================

/// 条件表达式状态类型（提取到顶层）
public enum CondExprStateKind {
| `idle`
| expandingArgs(UInt32, ExpansionState, ExitCode)
| waitingStat
| statComplete(Maybe<Stat>)
| waitingWriteErr
| done
}

/// 条件表达式父节点指针（提取到顶层）
public class CondExprParentPtr {
    public var ptr: Any = Option<Any>.None
    public static func initFunc(p: Any): CondExprParentPtr {
        let pp = CondExprParentPtr()
        pp.ptr = p
        return pp
    }
    public func childDone(child: Any, exitCode: ExitCode): Yield { Yield.done }
    public func destroy<T>(ptr: T) {}
}

/// 条件表达式子节点指针（提取到顶层）
public class CondExprChildPtr {
    public var ptr: Any = Option<Any>.None
    public static func initFunc(p: Any): CondExprChildPtr {
        let cp = CondExprChildPtr()
        cp.ptr = p
        return cp
    }
    public func `is`(`type`: Any): Bool { true }
    public func deinit() {}
}

/// 条件表达式状态
public class CondExprState {
    /// 基类
    public var base: Base = Base()
    /// AST节点
    public var node: ?CondExpr = None
    /// 父节点
    public var parent: CondExprParentPtr = CondExprParentPtr()
    /// IO
    public var io: IO = IO()
    /// 状态
    public var state: CondExprStateKind = CondExprStateKind.`idle`
    /// 参数
    public var args: ArrayList<String> = ArrayList<String>()

    public init() {}

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: CondExpr,
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
        var done = false
        while (!done) {
            match (this.state) {
                case CondExprStateKind.`idle` =>
                    this.state = CondExprStateKind.expandingArgs(
                        0,
                        ExpansionState(),
                        ExitCode.exited(0)
                    )
                    continue
                case CondExprStateKind.expandingArgs(idx, expState, lastExitCode) =>
                    if (Int64(idx) >= this.node.getOrThrow().args.size) {
                        return this.commandImplStart()
                    }
                    this.state = CondExprStateKind.expandingArgs(
                        idx + 1,
                        expState,
                        lastExitCode
                    )
                    return expState.start()
                case CondExprStateKind.waitingStat =>
                    return Yield.suspended
                case CondExprStateKind.statComplete(stat) => ()
                    // 根据操作符和stat结果返回退出码
                    match (this.node.getOrThrow().op) {
                        case CondExprOp.f => ()
                            // 检查是否为普通文件
                            return this.parent.childDone(this, ExitCode.exited(0))
                        case CondExprOp.d => ()
                            // 检查是否为目录
                            return this.parent.childDone(this, ExitCode.exited(0))
                        case CondExprOp.c => ()
                            // 检查是否为字符设备
                            return this.parent.childDone(this, ExitCode.exited(0))
                        case CondExprOp.z | CondExprOp.n =>
                            throw Exception("此条件表达式操作符不需要stat()")
                        case _ =>
                            throw Exception("无效的条件表达式操作符")
                    }
                case CondExprStateKind.waitingWriteErr =>
                    return Yield.suspended
                case CondExprStateKind.done =>
                    done = true
            }
        }
        return this.parent.childDone(this, ExitCode.exited(0))
    }

    /// 命令实现启动
    func commandImplStart(): Yield {
        match (this.node.getOrThrow().op) {
            case CondExprOp.f | CondExprOp.d | CondExprOp.c =>
                this.state = CondExprStateKind.waitingStat
                return this.doStat()
            case CondExprOp.z =>
                let exitCode = if (this.args.size == 0 || this.args[0].size == 0) { ExitCode.exited(0) } else { ExitCode.exited(1) }
                return this.parent.childDone(this, exitCode)
            case CondExprOp.n =>
                let exitCode = if (this.args.size > 0 && this.args[0].size != 0) { ExitCode.exited(0) } else { ExitCode.exited(1) }
                return this.parent.childDone(this, exitCode)
            case _ =>
                throw Exception("无效的条件表达式操作符")
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
            // GC-managed strings, no manual free needed
            ()
        }
        this.args.clear()
        this.base.endScope()
    }

    /// 子节点完成
    public func childDone(child: CondExprChildPtr, exitCode: ExitCode): Yield {
        if (!exitCode.isZero()) {
            return this.writeFailingError("error\n")
        }
        child.deinit()
        return this.next()
    }

    /// stat任务完成
    public func onStatTaskComplete(val: Maybe<Stat>) {
        this.state = CondExprStateKind.statComplete(val)
        this.next().run()
    }

    /// 写入失败错误
    public func writeFailingError(s: String): Yield {
        return this.base.shell.writeFailingErrorFmt(this, { _ => () }, s, [])
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, err: ?SystemError): Yield {
        if (err.isSome()) {
            let exitCode: ExitCode = ExitCode.exited(1)
            return this.parent.childDone(this, exitCode)
        }
        match (this.state) {
            case CondExprStateKind.waitingWriteErr =>
                return this.parent.childDone(this, ExitCode.exited(1))
            case _ =>
                return unreachableState("CondExpr.onIOWriterChunk", "unexpected state")
        }
    }

    /// stat 任务完成回调
    /// 对应 Bun: CondExprState.onStatTaskDone
    public static func onStatTaskDone(interp: Interpreter, cond: Any, stat: Any, path: Any): Unit {
        // stat 任务完成，将结果保存并恢复条件表达式状态机
        // cond 是 NodeId, stat 是 DispatchResult<DispatchSysStat>, path 是 Array<Byte>
        // 对应 Bun: 从 dispatch_tasks.run_from_main_thread 调用
        let condNodeId = cond as NodeId
        let statResult = stat as DispatchResult<DispatchSysStat>
        let pathBytes = path as Array<Byte>
        if (condNodeId.isValid()) {
            interp.setCondExprStatResult(condNodeId, statResult, pathBytes)
        }
    }
}
