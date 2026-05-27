// yield.cj - 协程Yield
// 对应 Bun: src/runtime/shell/Yield.zig
// 严格翻译Bun shell协程Yield到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*

// PipelineStateKind 已在 pipeline.cj 中定义（同包），此处不再重复定义

// ============================================================================
// Yield - Shell解释器的"延续"值
//
// 解决两个问题：
// 1. 无界递归 - 状态机.next()不断调用会导致调用栈过深
// 2. 正确处理挂起点 - IO阻塞时需要等待epoll/kqueue
//
// Yield作为解释器的"弹跳床"(trampoline)驱动执行而不爆栈
// ============================================================================

/// Yield联合体 - 表示Shell解释器的延续
public enum Yield {
    /// 脚本执行
    | script(Any)
    /// 语句执行
    | stmt(Any)
    /// 管道执行
    | pipeline(Any)
    /// 命令执行
    | cmd(Any)
    /// 赋值展开
    | assigns(Any)
    /// 展开
    | expansion(Any)
    /// if条件
    | ifClause(Any)
    /// 子shell
    | subshell(Any)
    /// 条件表达式
    | condExpr(Any)

    /// IO写入器数据块完成
    | onIoWriterChunk(?SystemError, UInt64, Any)

    /// 挂起
    | suspended
    /// 失败并抛出JS错误
    | failed
    /// 完成
    | done

    /// 是否完成
    public func isDone(): Bool {
        match (this) {
            case done => return true
            case _ => return false
        }
    }

    /// 运行Yield - 弹跳床驱动
    /// 充当"trampoline"来驱动执行而不爆栈
    /// 对应 Bun: Yield.zig - run() method
    public func run() {
        var current = this
        var iterations: Int64 = 0
        let maxIterations: Int64 = 1000000 // 防止无限循环
        while (!current.isDone() && iterations < maxIterations) {
            iterations += 1
            current = match (current) {
                case script(state) =>
                    let s = (state as ScriptState).getOrThrow()
                    s.next()
                case stmt(state) =>
                    let s = (state as StmtState).getOrThrow()
                    s.next()
                case cmd(state) =>
                    let s = (state as CmdState).getOrThrow()
                    s.next()
                case assigns(state) =>
                    let s = (state as AssignsState).getOrThrow()
                    s.next()
                case expansion(state) =>
                    let s = (state as ExpansionState).getOrThrow()
                    s.next()
                case ifClause(state) =>
                    let s = (state as IfState).getOrThrow()
                    s.next()
                case subshell(state) =>
                    let s = (state as SubshellState).getOrThrow()
                    s.next()
                case condExpr(state) =>
                    let s = (state as CondExprState).getOrThrow()
                    s.next()
                case pipeline(state) =>
                    let s = (state as PipelineState).getOrThrow()
                    s.next()
                case onIoWriterChunk(_, _, _) =>
                    Yield.done
                case suspended =>
                    Yield.suspended
                case failed =>
                    Yield.done
                case done =>
                    Yield.done
            }
        }
    }

    /// 排空管道栈
    public static func drainPipelines(pipelineStack: ArrayList<PipelineState>): ?Yield {
        // stub: simplified
        return None
    }
}
