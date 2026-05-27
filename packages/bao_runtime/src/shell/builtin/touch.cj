// touch.cj - touch命令
// 对应 Bun: src/runtime/shell/builtin/touch.zig
// 严格翻译Bun shell touch命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// touch命令 - 更新文件时间戳或创建文件
// ============================================================================

/// touch命令状态
public enum TouchState {
    | idle
    | waitingWriteErr
    | done
}

public class TouchCmd {
    /// 状态
    public var state: TouchState = TouchState.idle

    /// 启动
    public func start(): Yield {
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = TouchState.waitingWriteErr
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
            case TouchState.waitingWriteErr =>
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

/// touch解析结果
public enum TouchParseResult {
    | ok(?Array<String>)
    | err(TouchParseError)
}

/// touch解析错误
public enum TouchParseError {
    | illegalOption(String)
    | showUsage
    | unsupported(String)
}
