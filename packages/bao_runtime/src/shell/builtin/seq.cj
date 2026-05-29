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

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()
        if (args.size == 0) {
            return this.fail(BuiltinKind.seq.usageString())
        }

        // seq 支持 1-3 个参数: [FIRST [INCREMENT]] LAST
        var first: Int64 = 1
        var increment: Int64 = 1
        var last: Int64 = 0

        if (args.size == 1) {
            last = parseInt64(args[0])
        } else if (args.size == 2) {
            first = parseInt64(args[0])
            last = parseInt64(args[1])
        } else if (args.size >= 3) {
            first = parseInt64(args[0])
            increment = parseInt64(args[1])
            last = parseInt64(args[2])
        }

        if (increment == 0) {
            return this.fail("seq: increment must not be 0\n")
        }

        // 生成序列
        var output = ArrayList<UInt8>()
        if (increment > 0) {
            var i = first
            while (i <= last) {
                output.appendSlice(i.toString().toArray())
                output.append(UInt8(0x0A))  // '\n'
                i += increment
            }
        } else {
            var i = first
            while (i >= last) {
                output.appendSlice(i.toString().toArray())
                output.append(UInt8(0x0A))  // '\n'
                i += increment
            }
        }

        // 写入输出
        if (output.size > 0) {
            if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
                this.state = SeqState.done
                return this.bltn().stdout.enqueue(this, output.items(), safeguard)
            }
            this.bltn().writeNoIO(OutKind.Stdout, output.items())
        }

        this.state = SeqState.done
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

/// 解析 Int64 字符串
func parseInt64(s: String): Int64 {
    var result: Int64 = 0
    var negative: Bool = false
    var idx: Int64 = 0
    if (idx < s.size && s[Int64(idx)] == UInt8(45)) {
        negative = true
        idx++
    }
    while (idx < s.size) {
        let c = s[Int64(idx)]
        if (c >= UInt8(48) && c <= UInt8(57)) {
            result = result * 10 + Int64(c - UInt8(48))
        }
        idx++
    }
    return if (negative) { -result } else { result }
}
