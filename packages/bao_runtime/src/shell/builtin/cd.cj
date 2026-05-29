// cd.cj - cd命令
// 对应 Bun: src/runtime/shell/builtin/cd.zig
// 严格翻译Bun shell cd命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// cd命令 - 切换当前工作目录
// ============================================================================

/// cd命令状态
public enum CdState {
    | idle
    | waitingWriteStderr
    | done
}

public class CdCmd {
    /// 状态
    public var state: CdState = CdState.idle

    /// 写入标准错误（非阻塞）
    func writeStderrNonBlocking(s: String, args: Array<Any>): Yield {
        this.state = CdState.waitingWriteStderr
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            return this.bltn().stderr.enqueueFmtBltn(this, BuiltinKind.cd, s, args)
        }
        let buf = this.bltn().fmtErrorArena(BuiltinKind.cd, s, args)
        this.bltn().writeNoIO(OutKind.Stderr, buf.toArray())
        this.state = CdState.done
        return this.bltn().done(ExitCode.exited(1))
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().getArgsSlice()
        if (args.size > 1) {
            return this.writeStderrNonBlocking("too many arguments\n", [])
        }

        if (args.size == 0) {
            // cd with no args: go to HOME directory
            let homeOpt = SysFFI.getenv("HOME")
            match (homeOpt) {
                case Some(home) =>
                    let rc = SysFFI.chdir(home)
                    if (rc != 0) {
                        return this.writeStderrNonBlocking("cd: ${home}: No such file or directory\n", [])
                    }
                case None =>
                    // No HOME, just succeed (same as bash behavior)
                    ()
            }
            return this.bltn().done(ExitCode.exited(0))
        }

        // cd with one argument
        let target = args[0]
        if (target == "~") {
            let homeOpt = SysFFI.getenv("HOME")
            match (homeOpt) {
                case Some(home) =>
                    let rc = SysFFI.chdir(home)
                    if (rc != 0) {
                        return this.writeStderrNonBlocking("cd: ${home}: No such file or directory\n", [])
                    }
                case None => ()
            }
            return this.bltn().done(ExitCode.exited(0))
        }

        let rc = SysFFI.chdir(target)
        if (rc != 0) {
            return this.writeStderrNonBlocking("cd: ${target}: No such file or directory\n", [])
        }
        return this.bltn().done(ExitCode.exited(0))
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (e.isSome()) {
            e.getOrThrow().deref()
            return this.bltn().done(ExitCode.exited(1))
        }

        this.state = CdState.done
        return this.bltn().done(ExitCode.exited(1))
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
    }
}
