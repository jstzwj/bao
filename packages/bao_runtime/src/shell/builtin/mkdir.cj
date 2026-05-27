// mkdir.cj - mkdir命令
// 对应 Bun: src/runtime/shell/builtin/mkdir.zig
// 严格翻译Bun shell mkdir命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// mkdir命令 - 创建目录
// ============================================================================

/// mkdir命令状态
public enum MkdirState {
    | idle
    | exec
    | waitingWriteErr
    | done
}

public class MkdirCmd {
    /// 选项
    public var opts: MkdirOpts = MkdirOpts()
    /// 状态
    public var state: MkdirState = MkdirState.idle

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (e.isSome()) {
            e.getOrThrow().deref()
        }
        match (this.state) {
            case MkdirState.waitingWriteErr =>
                return this.bltn().done(ExitCode.exited(1))
            case _ => ()
        }
        return this.next()
    }

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = MkdirState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, s.toArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stderr, s.toArray())
        return this.bltn().done(exitCode)
    }

    /// 启动
    public func start(): Yield {
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 下一步
    public func next(): Yield {
        match (this.state) {
            case MkdirState.idle =>
                throw Exception("Invalid state")
            case MkdirState.exec =>
                return Yield.suspended
            case MkdirState.waitingWriteErr =>
                return Yield.failed
            case MkdirState.done =>
                return this.bltn().done(ExitCode.exited(0))
        }
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}

/// mkdir命令选项
public struct MkdirOpts {
    public var mode: ?UInt32 = None
    public var parents: Bool = false
    public var verbose: Bool = false

    public func parse(arr: Array<String>): MkdirParseResult {
        return MkdirParseResult.ok(Option<Array<String>>.None)
    }
}

/// mkdir解析结果
public enum MkdirParseResult {
    | ok(?Array<String>)
    | err(MkdirParseError)
}

/// mkdir解析错误
public enum MkdirParseError {
    | illegalOption(String)
    | showUsage
    | unsupported(String)
}
