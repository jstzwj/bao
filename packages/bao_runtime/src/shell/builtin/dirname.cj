// dirname.cj - dirname命令
// 对应 Bun: src/runtime/shell/builtin/dirname.zig
// 严格翻译Bun shell dirname命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// dirname命令 - 返回路径的目录部分
// ============================================================================

/// dirname命令
public class DirnameCmd {
    /// 状态
    public var state: DirnameState = DirnameState.idle
    /// 缓冲区
    public var buf: ArrayList<Byte> = ArrayList<Byte>()

    /// 状态类型
    public enum DirnameState {
        case idle
        case err
        case done
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()

        if (args.length == 0) {
            return this.fail(Builtin.Kind.usageString("dirname"))
        }

        for (item in args) {
            let arg = item
            this.print(PathUtils.dirname(arg))
            this.print("\n")
        }

        this.state = DirnameState.done
        if (let safeguard = this.bltn().stdout.needsIO()) {
            return this.bltn().stdout.enqueue(this, this.buf.toArray(), safeguard)
        }
        return this.bltn().done(0)
    }

    /// 失败处理
    func fail(msg: String): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.state = DirnameState.err
            return this.bltn().stderr.enqueue(this, msg.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, msg.toByteArray())
        return this.bltn().done(1)
    }

    /// 打印到缓冲区或直接输出
    func print(msg: String): Unit {
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
            this.state = DirnameState.err
            return this.bltn().done(1)
        }
        switch (this.state) {
            case .done =>
                return this.bltn().done(0)
            case .err =>
                return this.bltn().done(1)
            case .idle =>
                unreachableState("Dirname.onIOWriterChunk", "idle")
        }
    }

    /// 去初始化
    public func deinit() {
        this.buf.clear()
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "dirname")
    }
}
