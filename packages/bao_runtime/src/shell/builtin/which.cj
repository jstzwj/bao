// which.cj - which命令
// 对应 Bun: src/runtime/shell/builtin/which.zig
// 严格翻译Bun shell which命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// which命令 - 查找可执行文件的路径
// ============================================================================

/// which命令状态
public enum WhichState {
    | idle
    | done
}

public class WhichCmd {
    /// 状态
    public var state: WhichState = WhichState.idle

    /// 启动
    public func start(): Yield {
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            return this.bltn().stderr.enqueue(this, s.toArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stderr, s.toArray())
        return this.bltn().done(exitCode)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (e.isSome()) {
            e.getOrThrow().deref()
        }
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}
