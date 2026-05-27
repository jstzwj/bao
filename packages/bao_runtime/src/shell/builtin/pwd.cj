// pwd.cj - pwd命令
// 对应 Bun: src/runtime/shell/builtin/pwd.zig
// 严格翻译Bun shell pwd命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// pwd命令 - 打印当前工作目录
// ============================================================================

/// pwd状态类型
public enum PwdState {
    | idle
    | waitingIO
    | err
    | done
}

/// pwd命令
public class PwdCmd {
    /// 状态
    public var state: PwdState = PwdState.idle

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()
        if (args.size > 0) {
            let msg = "pwd: too many arguments\n"
            if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
                this.state = PwdState.waitingIO
                return this.bltn().stderr.enqueue(this, msg.toArray(), safeguard)
            }
            this.bltn().writeNoIO(OutKind.Stderr, msg.toArray())
            return this.bltn().done(ExitCode.exited(1))
        }

        // stub: print cwd
        let cwdStr = "."
        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            this.state = PwdState.waitingIO
            return this.bltn().stdout.enqueue(this, (cwdStr + "\n").toArray(), safeguard)
        }
        let buf = cwdStr + "\n"
        this.bltn().writeNoIO(OutKind.Stdout, buf.toArray())
        this.state = PwdState.done
        return this.bltn().done(ExitCode.exited(0))
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (e.isSome()) {
            e.getOrThrow().deref()
            this.state = PwdState.err
            return this.bltn().done(ExitCode.exited(1))
        }
        this.state = PwdState.done
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}
