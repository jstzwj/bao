// pwd.cj - pwd命令
// 对应 Bun: src/runtime/shell/builtin/pwd.zig
// 严格翻译Bun shell pwd命令到仓颉

package bao_runtime

import bao_core.*

// ============================================================================
// pwd命令 - 打印当前工作目录
// ============================================================================

/// pwd命令
public class PwdCmd {
    /// 状态
    public var state: PwdState = PwdState.idle

    /// 状态类型
    public enum PwdState {
        case idle
        case waitingIO(WaitingIOKind)
        case err
        case done
    }

    /// 等待IO类型
    public enum WaitingIOKind {
        case stdout
        case stderr
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()
        if (args.length > 0) {
            let msg = "pwd: too many arguments\n"
            if (let safeguard = this.bltn().stderr.needsIO()) {
                this.state = PwdState.waitingIO(.stderr)
                return this.bltn().stderr.enqueue(this, msg.toByteArray(), safeguard)
            }
            this.bltn().writeNoIO(.stderr, msg.toByteArray())
            return this.bltn().done(1)
        }

        let cwdStr = this.bltn().parentCmd().base.shell.cwd()
        if (let safeguard = this.bltn().stdout.needsIO()) {
            this.state = PwdState.waitingIO(.stdout)
            return this.bltn().stdout.enqueueFmtBltn(this, "", "${cwdStr}\n", [], safeguard)
        }
        let buf = "${cwdStr}\n"
        this.bltn().writeNoIO(.stdout, buf.toByteArray())
        this.state = PwdState.done
        return this.bltn().done(0)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .err && this.state != .done) {
            switch (this.state) {
                case .waitingIO =>
                    return Yield.suspended
                case .idle =>
                    panic("Unexpected \"idle\" state in Pwd.")
                case .done, .err =>
                    panic("不可达状态")
            }
        }

        switch (this.state) {
            case .done =>
                return this.bltn().done(0)
            case .err =>
                return this.bltn().done(1)
            case _ =>
                panic("不可达状态")
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, e: ?SystemError): Yield {
        if (let err = e) {
            err.deref()
            this.state = PwdState.err
            return this.next()
        }

        this.state = switch (this.state) {
            case .waitingIO(let kind) =>
                if (kind == .stdout) PwdState.done else PwdState.err
            case _ => PwdState.done
        }

        return this.next()
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "pwd")
    }
}
