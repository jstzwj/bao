// assigns.cj - 赋值展开状态
// 对应 Bun: src/runtime/shell/states/Assigns.zig
// 严格翻译Bun shell赋值状态到仓颉

package bao_runtime.shell

import bao_core.*

// ============================================================================
// 赋值展开状态
// 在管道表达式中赋值对shell环境没有影响，可以跳过
// ============================================================================

/// 赋值状态类型（提取到顶层）
public enum AssignsStateKind {
| `idle`
| expanding(UInt32, ExpansionState)
| err(ShellErr)
| done
}

/// 赋值状态父节点指针（提取到顶层）
public class AssignsParentPtr {
    public var ptr: Any = Option<Any>.None
    public static func initFunc(p: Any): AssignsParentPtr {
        let pp = AssignsParentPtr()
        pp.ptr = p
        return pp
    }
    public func childDone(child: Any, exitCode: ExitCode): Yield { Yield.done }
    public func destroy<T>(ptr: T) {}
}

/// 赋值状态子节点指针（提取到顶层）
public class AssignsChildPtr {
    public var ptr: Any = Option<Any>.None
    public static func initFunc(p: Any): AssignsChildPtr {
        let cp = AssignsChildPtr()
        cp.ptr = p
        return cp
    }
    public func `is`(`type`: Any): Bool { true }
    public func deinit() {}
}

/// 赋值状态
public class AssignsState {
    /// 基类
    public var base: Base = Base()
    /// AST节点
    public var node: Array<Assign> = Array<Assign>()
    /// 父节点
    public var parent: AssignsParentPtr = AssignsParentPtr()
    /// 状态
    public var state: AssignsStateKind = AssignsStateKind.`idle`
    /// 赋值上下文
    public var ctx: AssignCtx = AssignCtx.shell
    /// 是否拥有
    public var owned: Bool = true
    /// IO
    public var io: IO = IO()

    public init() {
        this.node = Array<Assign>()
        this.state = AssignsStateKind.`idle`
    }

    /// 启动
    public func start(): Yield {
        return Yield.assigns(this)
    }

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Array<Assign>,
        ctx: AssignCtx,
        parent: AssignsParentPtr,
        io: IO
    ): AssignsState {
        let state = AssignsState()
        state.base = Base.initWithNewAllocScope(StateKind.assign, interpreter, shellState)
        state.node = node
        state.parent = parent
        state.state = AssignsStateKind.`idle`
        state.ctx = ctx
        state.io = io
        return state
    }

    /// 下一步
    public func next(): Yield {
        var done = false
        while (!done) {
            match (this.state) {
                case AssignsStateKind.`idle` =>
                    this.state = AssignsStateKind.expanding(0, ExpansionState())
                    continue
                case AssignsStateKind.expanding(idx, expState) =>
                    if (Int64(idx) >= this.node.size) {
                        this.state = AssignsStateKind.done
                        done = true
                        continue
                    }
                    return expState.start()
                case AssignsStateKind.done =>
                    done = true
                case AssignsStateKind.err(errVal) =>
                    return this.parent.childDone(this, ExitCode.exited(1))
            }
        }
        return this.parent.childDone(this, ExitCode.exited(0))
    }

    /// 子节点完成
    public func childDone(child: AssignsChildPtr, exitCode: ExitCode): Yield {
        if (!exitCode.isZero()) {
            this.state = AssignsStateKind.err(ShellErr.custom("expansion error"))
            return Yield.failed
        }
        // 处理展开结果并赋值
        child.deinit()
        return Yield.assigns(this)
    }

    /// 去初始化
    public func deinit() {
        this.io.deinit()
        this.base.endScope()
        if (this.owned) {
            this.parent.destroy(this)
        }
    }
}
