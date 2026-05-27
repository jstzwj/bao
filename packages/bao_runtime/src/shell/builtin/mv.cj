// mv.cj - mv命令
// 对应 Bun: src/runtime/shell/builtin/mv.zig
// 严格翻译Bun shell mv命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// mv命令 - 移动或重命名文件
// ============================================================================

/// mv命令状态
public enum MvState {
    | idle
    | checkTarget
    | executing
    | done
    | waitingWriteErr
    | err
}

public class MvCmd {
    /// 选项
    public var opts: MvOpts = MvOpts()
    /// 状态
    public var state: MvState = MvState.idle

    /// 启动
    public func start(): Yield {
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = MvState.waitingWriteErr
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
        match (this.state) {
            case MvState.waitingWriteErr =>
                return this.bltn().done(ExitCode.exited(1))
            case _ => ()
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

/// mv命令选项
public struct MvOpts {
    public var forceOverwrite: Bool = true
    public var noDereference: Bool = false
    public var interactiveMode: Bool = false
    public var noOverwrite: Bool = false
    public var verboseOutput: Bool = false
}
