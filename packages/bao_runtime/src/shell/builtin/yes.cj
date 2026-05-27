// yes.cj - yes命令
// 对应 Bun: src/runtime/shell/builtin/yes.zig
// 严格翻译Bun shell yes命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// yes命令 - 重复输出字符串
// ============================================================================

/// yes命令状态
public enum YesState {
    | idle
    | waiting
    | err
    | done
}

public class YesCmd {
    /// 状态
    public var state: YesState = YesState.idle
    /// 缓冲区
    public var buffer: ArrayList<UInt8> = ArrayList<UInt8>()

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()
        if (args.size == 0) {
            this.buffer.append(121)  // 'y'
        } else {
            this.buffer.appendSlice(args[0].toArray())
        }
        this.buffer.append(10)  // '\n'

        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            this.state = YesState.waiting
            return this.bltn().stdout.enqueue(this, this.buffer.items(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stdout, this.buffer.items())
        return this.bltn().done(ExitCode.exited(0))
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (e.isSome()) {
            e.getOrThrow().deref()
            this.state = YesState.err
            return this.bltn().done(ExitCode.exited(1))
        }
        match (this.state) {
            case YesState.done =>
                return this.bltn().done(ExitCode.exited(0))
            case YesState.err =>
                return this.bltn().done(ExitCode.exited(1))
            case YesState.waiting =>
                return this.bltn().stdout.enqueue(this, this.buffer.items(), OutputNeedsIOSafeGuard.outputNeedsIo)
            case YesState.idle =>
                return unreachableState("Yes.onIOWriterChunk", "idle")
        }
    }

    /// 去初始化
    public func deinit() {
        this.buffer.clear()
    }

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}
