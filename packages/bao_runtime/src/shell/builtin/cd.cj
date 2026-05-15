// cd.cj - cd命令
// 对应 Bun: src/runtime/shell/builtin/cd.zig
// 严格翻译Bun shell cd命令到仓颉
// 额外行为:
// - cd 或 cd ~ 将切换到用户主目录
// - cd ~username 将切换到指定用户的主目录
// - cd - 将切换到前一个目录

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// cd命令 - 切换当前工作目录
// ============================================================================

/// cd命令
public class CdCmd {
    /// 状态
    public var state: CdState = CdState.idle

    /// 状态类型
    public enum CdState {
        case idle
        case waitingWriteStderr
        case done
        case err(SyscallError)
    }

    /// 写入标准错误（非阻塞）
    func writeStderrNonBlocking(fmt: String, args: Array<Any>): Yield {
        this.state = CdState.waitingWriteStderr
        if (let safeguard = this.bltn().stderr.needsIO()) {
            return this.bltn().stderr.enqueueFmtBltn(this, "cd", fmt, args, safeguard)
        }
        let buf = this.bltn().fmtErrorArena("cd", fmt, args)
        this.bltn().writeNoIO(.stderr, buf.toByteArray())
        this.state = CdState.done
        return this.bltn().done(1)
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()
        if (args.length > 1) {
            return this.writeStderrNonBlocking("too many arguments\n", [])
        }

        if (args.length == 1) {
            let firstArg = args[0]
            if (firstArg[0] == '-') {
                // cd - 切换到前一个目录
                switch (this.bltn().parentCmd().base.shell.changePrevCwd(
                    this.bltn().parentCmd().base.interpreter
                )) {
                    case .result => {}
                    case .err(let err) =>
                        return this.handleChangeCwdErr(
                            err,
                            this.bltn().parentCmd().base.shell.prevCwdZ()
                        )
                }
            } else if (firstArg[0] == '~') {
                // cd ~ 切换到主目录
                let homedir = this.bltn().parentCmd().base.shell.getHomedir()
                homedir.deref()
                switch (this.bltn().parentCmd().base.shell.changeCwd(
                    this.bltn().parentCmd().base.interpreter, homedir.slice()
                )) {
                    case .result => {}
                    case .err(let err) =>
                        return this.handleChangeCwdErr(err, homedir.slice())
                }
            } else {
                // cd <dir> 切换到指定目录
                switch (this.bltn().parentCmd().base.shell.changeCwd(
                    this.bltn().parentCmd().base.interpreter, firstArg
                )) {
                    case .result => {}
                    case .err(let err) =>
                        return this.handleChangeCwdErr(err, firstArg)
                }
            }
        }

        return this.bltn().done(0)
    }

    /// 处理切换目录错误
    func handleChangeCwdErr(err: SyscallError, newCwd: String): Yield {
        let errno: UInt32 = err.errno

        if (errno == Syscall.E.NOTDIR) {
            if (this.bltn().stderr.needsIO() == None) {
                let buf = this.bltn().fmtErrorArena("cd", "not a directory: ${newCwd}\n", [])
                this.bltn().writeNoIO(.stderr, buf.toByteArray())
                this.state = CdState.done
                return this.bltn().done(1)
            }
            return this.writeStderrNonBlocking("not a directory: ${newCwd}\n", [])
        }

        if (errno == Syscall.E.NOENT) {
            if (this.bltn().stderr.needsIO() == None) {
                let buf = this.bltn().fmtErrorArena("cd", "not a directory: ${newCwd}\n", [])
                this.bltn().writeNoIO(.stderr, buf.toByteArray())
                this.state = CdState.done
                return this.bltn().done(1)
            }
            return this.writeStderrNonBlocking("not a directory: ${newCwd}\n", [])
        }

        if (errno == Syscall.E.NAMETOOLONG) {
            if (this.bltn().stderr.needsIO() == None) {
                let buf = this.bltn().fmtErrorArena("cd", "file name too long\n", [])
                this.bltn().writeNoIO(.stderr, buf.toByteArray())
                this.state = CdState.done
                return this.bltn().done(1)
            }
            return this.writeStderrNonBlocking("file name too long\n", [])
        }

        // 其他错误
        let errmsg = err.msg() ?? err.name()
        if (this.bltn().stderr.needsIO() == None) {
            let buf = this.bltn().fmtErrorArena("cd", "${errmsg}: ${newCwd}\n", [])
            this.bltn().writeNoIO(.stderr, buf.toByteArray())
            this.state = CdState.done
            return this.bltn().done(1)
        }
        return this.writeStderrNonBlocking("${errmsg}: ${newCwd}\n", [])
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, e: ?SystemError): Yield {
        if (let err = e) {
            err.deref()
            return this.bltn().done(err.getErrno())
        }

        this.state = CdState.done
        return this.bltn().done(1)
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "cd")
    }
}
