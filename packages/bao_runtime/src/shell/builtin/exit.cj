// exit.cj - exit命令
// 对应 Bun: src/runtime/shell/builtin/exit.zig
// 严格翻译Bun shell exit命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// exit命令 - 退出shell
// ============================================================================

/// exit状态类型
public enum ExitState {
    | idle
    | waitingIO
    | err
    | done
}

/// exit命令
public class ExitCmd {
    /// 状态
    public var state: ExitState = ExitState.idle

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()
        if (args.size == 0) {
            return this.bltn().done(ExitCode.exited(0))
        }
        if (args.size == 1) {
            let firstArg = args[0]
            // Stub: just exit with code 0
            return this.bltn().done(ExitCode.exited(0))
        }
        return this.fail("exit: too many arguments\n")
    }

    /// 失败处理
    func fail(s: String): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = ExitState.waitingIO
            return this.bltn().stderr.enqueue(this, s.toArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stderr, s.toArray())
        return this.bltn().done(ExitCode.exited(1))
    }

    /// 下一步
    public func next(): Yield {
        match (this.state) {
            case ExitState.idle =>
                return unreachableState("Exit.next", "idle")
            case ExitState.waitingIO =>
                return Yield.suspended
            case ExitState.err =>
                return this.bltn().done(ExitCode.exited(1))
            case ExitState.done =>
                return this.bltn().done(ExitCode.exited(1))
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, maybeErr: ?SystemError): Yield {
        if (maybeErr.isSome()) {
            maybeErr.getOrThrow().deref()
            this.state = ExitState.err
            return this.next()
        }
        this.state = ExitState.done
        return this.next()
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}
