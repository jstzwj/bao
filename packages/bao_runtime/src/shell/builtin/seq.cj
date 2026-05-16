// seq.cj - seq命令
// 对应 Bun: src/runtime/shell/builtin/seq.zig
// 严格翻译Bun shell seq命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// seq命令 - 打印数字序列
// ============================================================================

/// seq命令
public enum SeqState {
    | idle
    | err
    | done
}

public class SeqCmd {
    /// 状态
    public var state: SeqState = SeqState.idle
    /// 缓冲区
    public var buf: ArrayList<Byte> = ArrayList<Byte>()
    /// 起始值
    public var startVal: Float32 = 1.0f32
    /// 结束值
    public var endVal: Float32 = 1.0f32
    /// 增量
    public var increment: Float32 = 1.0f32
    /// 分隔符
    public var separator: String = "\n"
    /// 终止符
    public var terminator: String = ""
    /// 固定宽度
    public var fixedWidth: Bool = false

    /// 状态类型


    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()

        if (args.size == 0) {
            return this.fail(Builtin.Kind.usageString("seq"))
        }

        var iterIdx: UInt32 = 0
        while (iterIdx < args.size) {
            let arg = args[iterIdx]
            iterIdx++

            if (arg == "-s" || arg == "--separator") {
                if (iterIdx >= args.size) {
                    return this.fail("seq: option requires an argument -- s\n")
                }
                this.separator = args[iterIdx]
                iterIdx++
                continue
            }
            if (arg.startsWith("-s")) {
                this.separator = arg.substring(2)
                continue
            }

            if (arg == "-t" || arg == "--terminator") {
                if (iterIdx >= args.size) {
                    return this.fail("seq: option requires an argument -- t\n")
                }
                this.terminator = args[iterIdx]
                iterIdx++
                continue
            }
            if (arg.startsWith("-t")) {
                this.terminator = arg.substring(2)
                continue
            }

            if (arg == "-w" || arg == "--fixed-width") {
                this.fixedWidth = true
                continue
            }

            iterIdx--
            break
        }

        // 第一个数值参数
        if (iterIdx >= args.size) {
            return this.fail(Builtin.Kind.usageString("seq"))
        }
        let parsed1 = Float32.parse(args[iterIdx])
        if (parsed1.isNone()) { return this.fail("seq: invalid argument\n") }
        let int1 = parsed1.getOrThrow()
        if (!int1.isFinite()) {
            return this.fail("seq: invalid argument\n")
        }
        this.endVal = int1
        if (this.startVal > this.endVal) {
            this.increment = -1.0f32
        }
        iterIdx++

        // 第二个数值参数
        if (iterIdx >= args.size) {
            return this.doSeq()
        }
        let parsed2 = Float32.parse(args[iterIdx])
        if (parsed2.isNone()) { return this.fail("seq: invalid argument\n") }
        let int2 = parsed2.getOrThrow()
        if (!int2.isFinite()) {
            return this.fail("seq: invalid argument\n")
        }
        this.startVal = int1
        this.endVal = int2
        if (this.startVal < this.endVal) {
            this.increment = 1.0f32
        }
        if (this.startVal > this.endVal) {
            this.increment = -1.0f32
        }
        iterIdx++

        // 第三个数值参数
        if (iterIdx >= args.size) {
            return this.doSeq()
        }
        let parsed3 = Float32.parse(args[iterIdx])
        if (parsed3.isNone()) { return this.fail("seq: invalid argument\n") }
        let int3 = parsed3.getOrThrow()
        if (!int3.isFinite()) {
            return this.fail("seq: invalid argument\n")
        }
        this.startVal = int1
        this.increment = int2
        this.endVal = int3

        if (this.increment == 0.0f32) {
            return this.fail("seq: zero increment\n")
        }
        if (this.startVal > this.endVal && this.increment > 0.0f32) {
            return this.fail("seq: needs negative decrement\n")
        }
        if (this.startVal < this.endVal && this.increment < 0.0f32) {
            return this.fail("seq: needs positive increment\n")
        }

        return this.doSeq()
    }

    /// 执行序列生成
    func doSeq(): Yield {
        var current = this.startVal
        while ((this.increment > 0.0f32 && current <= this.endVal) || (this.increment <= 0.0f32 && current >= this.endVal)) {
            let str = "${current}"
            this.print(str)
            this.print(this.separator)
            current += this.increment
        }
        this.print(this.terminator)

        this.state = SeqState.done
        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            return this.bltn().stdout.enqueue(this, this.buf.toArray(), safeguard)
        }
        return this.bltn().done(0)
    }

    /// 失败处理
    func fail(s: String): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = SeqState.err
            return this.bltn().stderr.enqueue(this, s.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.stderr, s.toByteArray())
        return this.bltn().done(1)
    }

    /// 打印到缓冲区或直接输出
    func print(s: String) {
        if (this.bltn().stdout.needsIO() != None) {
            this.buf.appendAll(s.toByteArray())
            return
        }
        this.bltn().writeNoIO(OutKind.stdout, s.toByteArray())
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, maybeErr: ?SystemError): Yield {
        if (let Some(e) <- maybeErr) {
            e.deref()
            this.state = SeqState.err
            return this.bltn().done(1)
        }
        match (this.state) {
            case done =>
                return this.bltn().done(0)
            case err =>
                return this.bltn().done(1)
            case idle =>
                unreachableState("Seq.onIOWriterChunk", "idle")
        }
    }

    /// 去初始化
    public func deinit() {
        this.buf.clear()
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "seq")
    }
}
