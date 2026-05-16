// assigns.cj - 赋值展开状态
// 对应 Bun: src/runtime/shell/states/Assigns.zig
// 严格翻译Bun shell赋值状态到仓颉

package bao_runtime.shell.states

import bao_core.*
import bao_runtime.shell.*

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
    public var ptr: Any
    public static func initFunc(p: Any): AssignsParentPtr {
        let pp = AssignsParentPtr()
        pp.ptr = p
        return pp
    }
    public func childDone(child: Any, exitCode: ExitCode): Yield { Yield.done }
    public func create<T>(): T { T() }
    public func destroy<T>(ptr: T) {}
}

/// 赋值状态子节点指针（提取到顶层）
public class AssignsChildPtr {
    public var ptr: Any
    public static func initFunc(p: Any): AssignsChildPtr {
        let cp = AssignsChildPtr()
        cp.ptr = p
        return cp
    }
    public func `is`(`type`: Any): Bool { true }
    public func `as`<T>(): T { this.ptr as T }
    public func deinit() {}
}

/// 赋值状态
public class AssignsState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Array<Assign>
    /// 父节点
    public var parent: AssignsParentPtr
    /// 状态
    public var state: AssignsStateKind
    /// 赋值上下文
    public var ctx: AssignCtx
    /// 是否拥有
    public var owned: Bool = true
    /// IO
    public var io: IO

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
        let self_ = AssignsState()
        this.base = Base.initWithNewAllocScope(StateKind.assign, interpreter, shellState)
        this.node = node
        this.parent = parent
        this.state = AssignsStateKind.`idle`
        this.ctx = ctx
        this.io = io
        return this
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != AssignsStateKind.done) {
            match (this.state) {
                case AssignsStateKind.`idle` =>
                    this.state = AssignsStateKind.expanding(0, ExpansionState())
                    continue
                case AssignsStateKind.expanding(idx, expansion) =>
                    if (idx >= this.node.size) {
                        this.state = AssignsStateKind.done
                        continue
                    }
                    return expansion.start()
                case AssignsStateKind.done =>
                    ()
                case AssignsStateKind.err =>
                    return this.parent.childDone(this, 1)
            }
        }
        return this.parent.childDone(this, 0)
    }

    /// 子节点完成
    public func childDone(child: AssignsChildPtr, exitCode: ExitCode): Yield {
        if (exitCode != 0) {
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
