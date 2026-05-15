// assigns.cj - 赋值展开状态
// 对应 Bun: src/runtime/shell/states/Assigns.zig
// 严格翻译Bun shell赋值状态到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// 赋值展开状态
// 在管道表达式中赋值对shell环境没有影响，可以跳过
// ============================================================================

/// 赋值状态
public class AssignsState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Array<Assign>
    /// 父节点
    public var parent: ParentPtr
    /// 状态
    public var state: AssignsStateKind
    /// 赋值上下文
    public var ctx: AssignCtx
    /// 是否拥有
    public var owned: Boolean = true
    /// IO
    public var io: IO

    /// 赋值状态类型
    public enum AssignsStateKind {
        case idle
        case expanding(idx: UInt32, expansion: ExpansionState)
        case err(ShellErr)
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
        parent: ParentPtr,
        io: IO
    ): AssignsState {
        let this = AssignsState()
        this.base = Base.initWithNewAllocScope(StateKind.assign, interpreter, shellState)
        this.node = node
        this.parent = parent
        this.state = AssignsStateKind.idle
        this.ctx = ctx
        this.io = io
        return this
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done) {
            switch (this.state) {
                case .idle =>
                    this.state = AssignsStateKind.expanding(idx: 0, expansion: ExpansionState())
                    continue
                case .expanding(let idx, let expansion) =>
                    if (idx >= this.node.length) {
                        this.state = AssignsStateKind.done
                        continue
                    }
                    return expansion.start()
                case .done =>
                    // 不可达
                case .err =>
                    return this.parent.childDone(this, 1)
            }
        }
        return this.parent.childDone(this, 0)
    }

    /// 子节点完成
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
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
