// yield.cj - 协程Yield
// 对应 Bun: src/runtime/shell/Yield.zig
// 严格翻译Bun shell协程Yield到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*

/// Pipeline状态枚举
public enum PipelineStateKind {
    | startingCmds
    | running
    | done
}

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
    | script(Script)
    /// 语句执行
    | stmt(Stmt)
    /// 管道执行
    | pipeline(Pipeline)
    /// 命令执行
    | cmd(Cmd)
    /// 赋值展开
    | assigns(Assigns)
    /// 展开
    | expansion(Expansion)
    /// if条件
    | ifClause(If)
    /// 子shell
    | subshell(Subshell)
    /// 条件表达式
    | condExpr(CondExpr)

    /// IO写入器数据块完成
    | onIoWriterChunk(?SystemError, UInt64, Any)

    /// 挂起
    | suspended
    /// 失败并抛出JS错误
    | failed
    /// 完成
    | done

    /// 是否完成
    public func isDone(): Boolean {
        return this == Yield.done
    }

    /// 运行Yield - 弹跳床驱动
    /// 充当"trampoline"来驱动执行而不爆栈
    public func run() {
        // 管道栈 - 管道创建多个执行"线程"
        var pipelineStack = ArrayList<Pipeline>()

        // 标签化switch - 驱动状态机执行
        var currentState: Yield = this
        while (true) {
            match (currentState) {
                case pipeline(x) =>
                    if (x.state == PipelineStateKind.done) {
                        // 从管道栈中移除
                        let idx = pipelineStack.indexOf(x)
                        if (idx >= 0) {
                            pipelineStack.removeAt(idx)
                        }
                        currentState = x.next()
                    } else {
                        pipelineStack.append(x)
                        currentState = x.next()
                    }
                case cmd(x) =>
                    currentState = x.next()
                case script(x) =>
                    currentState = x.next()
                case stmt(x) =>
                    currentState = x.next()
                case assigns(x) =>
                    currentState = x.next()
                case expansion(x) =>
                    currentState = x.next()
                case ifClause(x) =>
                    currentState = x.next()
                case subshell(x) =>
                    currentState = x.next()
                case condExpr(x) =>
                    currentState = x.next()
                case onIoWriterChunk(err, child) =>
                    let childPtr = IOWriterChildPtr.fromAnyOpaque(child)
                    currentState = childPtr.onIOWriterChunk(written, err)
                case failed =>
                    // 尝试排空管道栈
                    if (let yield <- Yield.drainPipelines(pipelineStack)) {
                        currentState = yield
                    } else {
                        return
                    }
            }
        }
    }

    /// 排空管道栈
    public static func drainPipelines(pipelineStack: ArrayList<Pipeline>): ?Yield {
        if (pipelineStack.size == 0) {
            return None
        }
        var i = pipelineStack.size - 1
        while (i >= 0 && i < pipelineStack.size) {
            let pipeline = pipelineStack[i]
            if (pipeline.state == PipelineStateKind.startingCmds) {
                return pipeline.next()
            }
            pipelineStack.removeAt(i)
            if (pipeline.state == PipelineStateKind.done) {
                return pipeline.next()
            }
            i -= 1
        }
        return None
    }
}
