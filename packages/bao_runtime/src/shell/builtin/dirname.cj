// dirname.cj - dirname命令
// 对应 Bun: src/runtime/shell/builtin/dirname.zig
// 严格翻译Bun shell dirname命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// dirname命令 - 返回路径的目录部分
// ============================================================================

/// dirname命令
public enum DirnameState {
    | idle
    | err
    | done
}

/// dirname命令
public class DirnameCmd {
    /// 状态
    public var state: DirnameState = DirnameState.idle
    /// 缓冲区
    public var buf: ArrayList<UInt8> = ArrayList<UInt8>()

    /// 内联dirname实现
    public static func doDirname(path: String): String {
        let bytes = path.toArray()
        let slash: UInt8 = 47  // '/'
        // Remove trailing slashes
        var end = bytes.size
        while (end > 1 && bytes[end - 1] == slash) {
            end -= 1
        }
        // Find last slash
        var lastSlash = -1
        for (i in 0..end) {
            if (bytes[i] == slash) {
                lastSlash = i
            }
        }
        if (lastSlash < 0) {
            return "."
        }
        // Remove trailing slashes from result
        var resultEnd = lastSlash
        while (resultEnd > 1 && bytes[resultEnd - 1] == slash) {
            resultEnd -= 1
        }
        if (resultEnd == 0) {
            return "/"
        }
        return String.fromUtf8(bytes[0..resultEnd])
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()

        if (args.size == 0) {
            return this.fail(BuiltinKind.dirname.usageString())
        }

        for (item in args) {
            let arg = item
            this.printBuiltin(DirnameCmd.doDirname(arg))
            this.printBuiltin("\n")
        }

        this.state = DirnameState.done
        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            return this.bltn().stdout.enqueue(this, this.buf.items(), safeguard)
        }
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 失败处理
    func fail(s: String): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = DirnameState.err
            return this.bltn().stderr.enqueue(this, s.toArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stderr, s.toArray())
        return this.bltn().done(ExitCode.exited(1))
    }

    /// 打印到缓冲区或直接输出
    func printBuiltin(s: String): Unit {
        if (this.bltn().stdout.needsIO().isSome()) {
            this.buf.appendSlice(s.toArray())
            return
        }
        this.bltn().writeNoIO(OutKind.Stdout, s.toArray())
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, maybeErr: ?SystemError): Yield {
        if (maybeErr.isSome()) {
            maybeErr.getOrThrow().deref()
            this.state = DirnameState.err
            return this.bltn().done(ExitCode.exited(1))
        }
        match (this.state) {
            case DirnameState.done =>
                return this.bltn().done(ExitCode.exited(0))
            case DirnameState.err =>
                return this.bltn().done(ExitCode.exited(1))
            case DirnameState.idle =>
                return unreachableState("Dirname.onIOWriterChunk", "idle")
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
