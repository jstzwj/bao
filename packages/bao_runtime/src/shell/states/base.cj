// base.cj - 状态节点基类
// 对应 Bun: src/runtime/shell/states/Base.zig
// 严格翻译Bun shell状态基类到仓颉

package bao_runtime.shell.states

import bao_core.*

// ============================================================================
// 状态节点基类
// 所有状态节点都包含此头部
// ============================================================================

/// 状态基类
/// 所有状态节点的公共头部
public class Base {
    /// 状态类型
    public var kind: StateKind
    /// 所属解释器
    public var interpreter: Interpreter
    /// Shell执行环境
    /// 当需要创建新的shell执行环境时拥有它（需要去初始化）
    /// 1. Script拥有自己的shell执行环境
    /// 2. Pipeline中的每个命令在自己的环境中执行
    /// 3. 子Shell
    /// 4. 命令替换
    public var shell: ShellExecEnv

    /// 使用新的分配作用域初始化
    public static func initWithNewAllocScope(kind: StateKind, interpreter: Interpreter, shell: ShellExecEnv): Base {
        let base = Base()
        base.kind = kind
        base.interpreter = interpreter
        base.shell = shell
        return base
    }

    /// 使用借用的分配作用域初始化
    public static func initBorrowedAllocScope(kind: StateKind, interpreter: Interpreter, shell: ShellExecEnv): Base {
        let base = Base()
        base.kind = kind
        base.interpreter = interpreter
        base.shell = shell
        return base
    }

    /// 结束分配作用域
    public func endScope() {
        // 在release构建中无操作
    }

    /// 获取事件循环
    public func eventLoop(): EventLoopHandle {
        return this.interpreter.eventLoop
    }

    /// 抛出Shell错误
    public func `throw`(err: ShellErr) {
        throwShellErr(err, this.eventLoop())
    }

    /// 获取根IO
    public func rootIO(): IO {
        return this.interpreter.rootIo
    }

    /// 获取分配器
    public func allocator(): Allocator {
        return DefaultAllocator.instance
    }

    /// 泄露分配
    public func leakSlice(memory: Any) {
        // 在release构建中无操作
    }
}
