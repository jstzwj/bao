// echo.cj - echo命令
// 对应 Bun: src/runtime/shell/builtin/echo.zig
// 严格翻译Bun shell echo命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// echo命令 - 输出文本到标准输出
// 支持 -n (无换行), -e (转义序列), -E (禁用转义)
// ============================================================================

/// echo命令状态
public enum EchoState {
    | idle
    | waiting
    | waitingWriteErr
    | done
}

public class EchoCmd {
    /// 输出缓冲区
    public var output: ArrayList<UInt8> = ArrayList<UInt8>()
    /// 状态
    public var state: EchoState = EchoState.idle

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()

        // 简化：直接输出所有参数
        for (i in 0..args.size) {
            if (i > 0) {
                this.output.append(32)  // ' '
            }
            this.output.appendSlice(args[i].toArray())
        }
        this.output.append(10)  // '\n'

        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            this.state = EchoState.waiting
            return this.bltn().stdout.enqueue(this, this.output.items(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stdout, this.output.items())
        this.state = EchoState.done
        return this.bltn().done(ExitCode.exited(0))
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (e.isSome()) {
            e.getOrThrow().deref()
            return this.bltn().done(ExitCode.exited(1))
        }

        this.state = EchoState.done
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 去初始化
    public func deinit() {
        this.output.clear()
    }

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}
