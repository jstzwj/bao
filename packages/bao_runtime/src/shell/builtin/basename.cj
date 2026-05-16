// basename.cj - basename命令
// 对应 Bun: src/runtime/shell/builtin/basename.zig
// 严格翻译Bun shell basename命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// basename命令 - 返回路径的基本名称
// ============================================================================

/// basename命令
public class BasenameCmd {
    /// 状态
    public var state: BasenameState = BasenameState.idle
    /// 缓冲区
    public var buf: ArrayList<Byte> = ArrayList<Byte>()

    /// 状态类型
    public enum BasenameState {
| idle
| err
| done
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()

        if (args.length == 0) {
            return this.fail(Builtin.Kind.usageString("basename"))
        }

        for (item in args) {
            let arg = item
            this.print(PathUtils.basename(arg))
            this.print("\n")
        }

        this.state = BasenameState.done
        if (let safeguard = this.bltn().stdout.needsIO()) {
            return this.bltn().stdout.enqueue(this, this.buf.toArray(), safeguard)
        }
        return this.bltn().done(0)
    }

    /// 失败处理
    func fail(msg: String): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.state = BasenameState.err
            return this.bltn().stderr.enqueue(this, msg.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, msg.toByteArray())
        return this.bltn().done(1)
    }

    /// 打印到缓冲区或直接输出
    func print(msg: String) {
        if (this.bltn().stdout.needsIO() != None) {
            this.buf.appendAll(msg.toByteArray())
            return
        }
        this.bltn().writeNoIO(.stdout, msg.toByteArray())
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, maybeErr: ?SystemError): Yield {
        if (let e = maybeErr) {
            e.deref()
            this.state = BasenameState.err
            return this.bltn().done(1)
        }
        switch (this.state) {
            case .done =>
                return this.bltn().done(0)
            case .err =>
                return this.bltn().done(1)
            case .idle =>
                unreachableState("Basename.onIOWriterChunk", "idle")
        }
    }

    /// 去初始化
    public func deinit() {
        this.buf.clear()
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "basename")
    }
}
