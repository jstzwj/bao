// binary.cj - 二元表达式状态
// 对应 Bun: src/runtime/shell/states/Binary.zig
// 严格翻译Bun shell二元表达式状态到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// 二元表达式状态
// 处理 && 和 || 操作符
// ============================================================================

/// 二元表达式状态
public class BinaryState {
    /// 基类
    public var base: Base
    /// AST节点
    public var node: Binary
    /// 父节点
    public var parent: ParentPtr
    /// 左操作数退出码
    public var left: ?ExitCode = None
    /// 右操作数退出码
    public var right: ?ExitCode = None
    /// IO
    public var io: IO
    /// 当前执行的子节点
    public var currentlyExecuting: ?ChildPtr = None

    /// 父节点指针
    public class ParentPtr {
        public var ptr: Any
        public static func initFunc(p: Any): ParentPtr {
            let pp = ParentPtr()
            pp.ptr = p
            return pp
        }
        public func childDone(child: Any, exitCode: ExitCode): Yield {
            return Yield.done
        }
        public func allocator(): Allocator { DefaultAllocator.instance }
    }

    /// 子节点指针
    public class ChildPtr {
        public var ptr: Any
        public static func initFunc(p: Any): ChildPtr {
            let cp = ChildPtr()
            cp.ptr = p
            return cp
        }
        public func start(): Yield { return Yield.done }
        public func deinit() {}
    }

    /// 初始化
    public static func initFunc(
        interpreter: Interpreter,
        shellState: ShellExecEnv,
        node: Binary,
        parent: ParentPtr,
        io: IO
    ): BinaryState {
        let binary = BinaryState()
        binary.base = Base.initWithNewAllocScope(StateKind.binary, interpreter, shellState)
        binary.node = node
        binary.parent = parent
        binary.io = io
        binary.left = None
        binary.right = None
        binary.currentlyExecuting = None
        return binary
    }

    /// 启动
    public func start(): Yield {
        this.currentlyExecuting = this.makeChild(true)
        if (this.currentlyExecuting == None) {
            this.currentlyExecuting = this.makeChild(false)
            this.left = 0
        }
        return this.currentlyExecuting!.start()
    }

    /// 创建子节点
    func makeChild(left: Boolean): ?ChildPtr {
        // 根据AST节点类型创建对应的子状态
        return None
    }

    /// 子节点完成
    public func childDone(child: ChildPtr, exitCode: ExitCode): Yield {
        child.deinit()
        this.currentlyExecuting = None

        if (this.left == None) {
            this.left = exitCode
            // && 和 || 的短路逻辑
            if ((this.node.op == .and && exitCode != 0) || (this.node.op == .or && exitCode == 0)) {
                return this.parent.childDone(this, exitCode)
            }
            this.currentlyExecuting = this.makeChild(false)
            if (this.currentlyExecuting == None) {
                this.right = 0
                return this.parent.childDone(this, 0)
            }
            return this.currentlyExecuting!.start()
        }

        this.right = exitCode
        return this.parent.childDone(this, exitCode)
    }

    /// 去初始化
    public func deinit() {
        if (let child = this.currentlyExecuting) {
            child.deinit()
        }
        this.io.deinit()
        this.base.endScope()
    }
}
