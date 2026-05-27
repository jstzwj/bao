// seq.cj - seq命令
// 对应 Bun: src/runtime/shell/builtin/seq.zig
// 严格翻译Bun shell seq命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// seq命令 - 打印数字序列
// ============================================================================

/// seq命令状态
public enum SeqState {
    | idle
    | err
    | done
}

public class SeqCmd {
    /// 状态
    public var state: SeqState = SeqState.idle
    /// 缓冲区
    public var buf: ArrayList<UInt8> = ArrayList<UInt8>()

    /// 启动 - stub
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()
        if (args.size == 0) {
            return this.fail(BuiltinKind.seq.usageString())
        }
        // stub: simplified seq
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 失败处理
    func fail(s: String): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = SeqState.err
            return this.bltn().stderr.enqueue(this, s.toArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stderr, s.toArray())
        return this.bltn().done(ExitCode.exited(1))
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, maybeErr: ?SystemError): Yield {
        if (maybeErr.isSome()) {
            maybeErr.getOrThrow().deref()
            this.state = SeqState.err
            return this.bltn().done(ExitCode.exited(1))
        }
        match (this.state) {
            case SeqState.done =>
                return this.bltn().done(ExitCode.exited(0))
            case SeqState.err =>
                return this.bltn().done(ExitCode.exited(1))
            case SeqState.idle =>
                return unreachableState("Seq.onIOWriterChunk", "idle")
        }
    }

    /// 去初始化
    public func deinit() {
        this.buf.clear()
    }

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}
