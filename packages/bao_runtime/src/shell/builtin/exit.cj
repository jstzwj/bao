// exit.cj - exit命令
// 对应 Bun: src/runtime/shell/builtin/exit.zig
// 严格翻译Bun shell exit命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// exit命令 - 退出shell
// ============================================================================

/// exit命令
public class ExitCmd {
    /// 状态
    public var state: ExitState = ExitState.idle

    /// 状态类型
    public enum ExitState {
        case idle
        case waitingIO
        case err
        case done
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()
        if (args.length == 0) {
            return this.bltn().done(0)
        }
        if (args.length == 1) {
            let firstArg = args[0]
            let exitCode = Int64(firstArg) ?? {
                return this.fail("exit: numeric argument required\n")
            }
            let code: ExitCode = (exitCode % 256).toUInt8()
            return this.bltn().done(code)
        }
        return this.fail("exit: too many arguments\n")
    }

    /// 失败处理
    func fail(msg: String): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.state = ExitState.waitingIO
            return this.bltn().stderr.enqueue(this, msg.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, msg.toByteArray())
        return this.bltn().done(1)
    }

    /// 下一步
    public func next(): Yield {
        switch (this.state) {
            case .idle =>
                unreachableState("Exit.next", "idle")
            case .waitingIO =>
                return Yield.suspended
            case .err =>
                return this.bltn().done(1)
            case .done =>
                return this.bltn().done(1)
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, maybeErr: ?SystemError): Yield {
        if (let e = maybeErr) {
            e.deref()
            this.state = ExitState.err
            return this.next()
        }
        this.state = ExitState.done
        return this.next()
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "exit")
    }
}
