// yield.cj - 协程Yield
// 对应 Bun: src/runtime/shell/Yield.zig
// 严格翻译Bun shell协程Yield到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*

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
    case script(Script)
    /// 语句执行
    case stmt(Stmt)
    /// 管道执行
    case pipeline(Pipeline)
    /// 命令执行
    case cmd(Cmd)
    /// 赋值展开
    case assigns(Assigns)
    /// 展开
    case expansion(Expansion)
    /// if条件
    case ifClause(If)
    /// 子shell
    case subshell(Subshell)
    /// 条件表达式
    case condExpr(CondExpr)

    /// IO写入器数据块完成
    case onIoWriterChunk(err: ?SystemError, written: UInt64, child: Any)

    /// 挂起
    case suspended
    /// 失败并抛出JS错误
    case failed
    /// 完成
    case done

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
            switch (currentState) {
                case .pipeline(let x) =>
                    if (x.state == .done) {
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
                case .cmd(let x) =>
                    currentState = x.next()
                case .script(let x) =>
                    currentState = x.next()
                case .stmt(let x) =>
                    currentState = x.next()
                case .assigns(let x) =>
                    currentState = x.next()
                case .expansion(let x) =>
                    currentState = x.next()
                case .ifClause(let x) =>
                    currentState = x.next()
                case .subshell(let x) =>
                    currentState = x.next()
                case .condExpr(let x) =>
                    currentState = x.next()
                case .onIoWriterChunk(let err, let written, let child) =>
                    let childPtr = IOWriterChildPtr.fromAnyOpaque(child)
                    currentState = childPtr.onIOWriterChunk(written, err)
                case .failed, .suspended, .done =>
                    // 尝试排空管道栈
                    if (let yield = Yield.drainPipelines(pipelineStack)) {
                        currentState = yield
                    } else {
                        return
                    }
            }
        }
    }

    /// 排空管道栈
    public static func drainPipelines(pipelineStack: ArrayList<Pipeline>): ?Yield {
        if (pipelineStack.length == 0) {
            return None
        }
        var i = pipelineStack.length - 1
        while (i >= 0 && i < pipelineStack.length) {
            let pipeline = pipelineStack[i]
            if (pipeline.state == .startingCmds) {
                return pipeline.next()
            }
            pipelineStack.removeAt(i)
            if (pipeline.state == .done) {
                return pipeline.next()
            }
            i -= 1
        }
        return None
    }
}
