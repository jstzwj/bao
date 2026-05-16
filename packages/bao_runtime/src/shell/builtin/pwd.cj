// pwd.cj - pwd命令
// 对应 Bun: src/runtime/shell/builtin/pwd.zig
// 严格翻译Bun shell pwd命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// pwd命令 - 打印当前工作目录
// ============================================================================

/// pwd状态类型（提取到顶层）
public enum PwdState {
    | idle
    | waitingIO(WaitingIOKind)
    | err
    | done
}

/// 等待IO类型（提取到顶层）
public enum WaitingIOKind {
    | stdout
    | stderr
}

/// pwd命令
public class PwdCmd {
    /// 状态
    public var state: PwdState = PwdState.idle

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()
        if (args.size > 0) {
            let msg = "pwd: too many arguments\n"
            if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
                this.state = PwdState.waitingIO(WaitingIOKind.stderr)
                return this.bltn().stderr.enqueue(this, msg.toByteArray(), safeguard)
            }
            this.bltn().writeNoIO(OutKind.stderr, msg.toByteArray())
            return this.bltn().done(1)
        }

        let cwdStr = this.bltn().parentCmd().base.shell.cwd()
        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            this.state = PwdState.waitingIO(WaitingIOKind.stdout)
            return this.bltn().stdout.enqueueFmtBltn(this, "", cwdStr + "\n", [], safeguard)
        }
        let buf = cwdStr + "\n"
        this.bltn().writeNoIO(OutKind.stdout, buf.toByteArray())
        this.state = PwdState.done
        return this.bltn().done(0)
    }

    /// 下一步
    public func next(): Yield {
        match (this.state) {
            case PwdState.waitingIO(_) =>
                return Yield.suspended
            case PwdState.idle =>
                panic("Unexpected \"idle\" state in Pwd.")
            case PwdState.done =>
                return this.bltn().done(0)
            case PwdState.err =>
                return this.bltn().done(1)
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (let Some(err) <- e) {
            err.deref()
            this.state = PwdState.err
            return this.next()
        }

        this.state = match (this.state) {
            case PwdState.waitingIO(kind) =>
                if (kind == WaitingIOKind.stdout) { PwdState.done } else { PwdState.err }
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
