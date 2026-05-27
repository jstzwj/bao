// basename.cj - basename命令
// 对应 Bun: src/runtime/shell/builtin/basename.zig
// 严格翻译Bun shell basename命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// basename命令 - 返回路径的基本名称
// ============================================================================

/// basename状态类型（提取到顶层）
public enum BasenameState {
    | idle
    | err
    | done
}

/// basename命令
public class BasenameCmd {
    /// 状态
    public var state: BasenameState = BasenameState.idle
    /// 缓冲区
    public var buf: ArrayList<UInt8> = ArrayList<UInt8>()

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()

        if (args.size == 0) {
            return this.fail(BuiltinKind.basename.usageString())
        }

        for (item in args) {
            let arg = item
            this.printBuiltin(BasenameCmd.doBasename(arg))
            this.printBuiltin("\n")
        }

        this.state = BasenameState.done
        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            return this.bltn().stdout.enqueue(this, this.buf.items(), safeguard)
        }
        return this.bltn().done(ExitCode.exited(0))
    }

    /// 内联basename实现
    public static func doBasename(path: String): String {
        var bytes = path.toArray()
        let slash: UInt8 = 47  // '/'
        // Remove trailing slashes
        while (bytes.size > 1 && bytes[bytes.size - 1] == slash) {
            bytes = bytes[0..bytes.size - 1]
        }
        // Find last slash
        var lastSlash = -1
        for (i in 0..bytes.size) {
            if (bytes[i] == slash) {
                lastSlash = i
            }
        }
        if (lastSlash >= 0) {
            return String.fromUtf8(bytes[lastSlash + 1..])
        }
        return path
    }

    /// 失败处理
    func fail(msg: String): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = BasenameState.err
            return this.bltn().stderr.enqueue(this, msg.toArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stderr, msg.toArray())
        return this.bltn().done(ExitCode.exited(1))
    }

    /// 打印到缓冲区或直接输出
    func printBuiltin(msg: String) {
        if (this.bltn().stdout.needsIO().isSome()) {
            this.buf.appendSlice(msg.toArray())
            return
        }
        this.bltn().writeNoIO(OutKind.Stdout, msg.toArray())
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, maybeErr: ?SystemError): Yield {
        if (maybeErr.isSome()) {
            maybeErr.getOrThrow().deref()
            this.state = BasenameState.err
            return this.bltn().done(ExitCode.exited(1))
        }
        match (this.state) {
            case BasenameState.done =>
                return this.bltn().done(ExitCode.exited(0))
            case BasenameState.err =>
                return this.bltn().done(ExitCode.exited(1))
            case BasenameState.idle =>
                return unreachableState("Basename.onIOWriterChunk", "idle")
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
