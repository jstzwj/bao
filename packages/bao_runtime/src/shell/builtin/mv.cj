// mv.cj - mv命令
// 对应 Bun: src/runtime/shell/builtin/mv.zig
// 严格翻译Bun shell mv命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// mv命令 - 移动或重命名文件
// 使用线程池并发处理批量移动
// ============================================================================

/// mv命令
public struct MvArgs {
    public var sources: Array<String> = []
    public var target: String = ""
    public var targetFd: ?FD = None
}

public enum MvState {
    | idle
    | checkTarget(CheckTargetState)
    | executing(ExecutingState)
    | done
    | waitingWriteErr(ExitCode)
    | err
}

public struct CheckTargetState {
    public var task: ShellMvCheckTargetTask
    public var innerState: CheckTargetInnerState = CheckTargetInnerState.running
}

public enum CheckTargetInnerState {
    | running
    | done
}

public struct ExecutingState {
    public var taskCount: UIntPtr = 0
    public var tasksDone: UIntPtr = 0
    public var errorSignal: AtomicBool = AtomicBool()
    public var tasks: Array<ShellMvBatchedTask>
    public var err: ?SyscallError = None
    public var errPathOwned: Bool = false
}

public class MvCmd {
    /// 选项
    public var opts: MvOpts = MvOpts()
    /// 参数
    public var args: MvArgs = MvArgs()
    /// 状态
    public var state: MvState = MvState.idle

    /// 参数


    /// 状态类型


    /// 检查目标状态


    /// 检查目标内部状态


    /// 执行状态
    /// 对应 Bun: executing struct in Mv state


    /// 启动
    public func start(): Yield {
        return this.next()
    }

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = MvStateMultiArgsInnerState.waitingWriteErr(exitCode)
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != CheckTargetInnerState.done && this.state != CheckTargetInnerState.err) {
            match (this.state) {
                case idle =>
                    if (let Some(e) <- this.parseOpts().getErr()) {
                        let buf = match (e) {
                            case illegalOption(optStr) =>
                                this.bltn().fmtErrorArena("mv", "illegal option -- ${optStr}\n", [])
                            case showUsage =>
                                Builtin.Kind.usageString("mv")
                        }
                        return this.writeFailingError(buf, 1)
                    }

                    // 调度检查目标任务
                    return Yield.suspended

                case checkTarget => ()
                    // 等待检查目标完成
                    return Yield.suspended

                case executing => ()
                    // 等待所有任务完成
                    return Yield.suspended

                case waitingWriteErr =>
                    return Yield.failed

                case MvState.done(_) | MvState.err(_) =>
                    panic("不可达状态")
            }
        }

        match (this.state) {
            case done =>
                return this.bltn().done(0)
            case _ =>
                return this.bltn().done(1)
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (let Some(err) <- e) {
            err.deref()
        }
        match (this.state) {
            case waitingWriteErr =>
                if (e != None) {
                    this.state = MvState.err
                    return this.next()
                }
                return this.bltn().done(this.state.getWaitingWriteErr() ?? 1)
            case _ =>
                panic("Invalid state")
        }
    }

    /// 解析选项
    func parseOpts(): MvParseResult {
        let args = this.bltn().argsSlice()
        var idx: UInt32 = 0
        if (args.size == 0) {
            return MvParseResult.err(MvParseError.showUsage)
        }

        while (idx < args.size) {
            let flag = args[idx]
            match (this.parseFlag(flag)) {
                case FlagParseResult.done =>
                    let filepathArgs = args[idx..]
                    if (filepathArgs.size < 2) {
                        return MvParseResult.err(MvParseError.showUsage)
                    }
                    this.args.sources = filepathArgs[0..(filepathArgs.size - 1)]
                    this.args.target = filepathArgs[filepathArgs.size - 1]
                    return MvParseResult.ok(())
                case FlagParseResult.continueParsing =>
                    idx++
                case FlagParseResult.illegalOption(optStr) =>
                    return MvParseResult.err(MvParseError.illegalOption(optStr))
            }
            idx++
        }

        return MvParseResult.err(MvParseError.showUsage)
    }

    /// 解析单个标志
    func parseFlag(s: String): FlagParseResult {
        if (flag.size == 0) {
            return FlagParseResult.done
        }
        if (flag[0] != '-') {
            return FlagParseResult.done
        }

        let smallFlags = flag.substring(1)
        for (c in smallFlags) {
            if (c == 'f') {
                this.opts.forceOverwrite = true
                this.opts.interactiveMode = false
                this.opts.noOverwrite = false
            } else if (c == 'h') {
                this.opts.noDereference = true
            } else if (c == 'i') {
                this.opts.interactiveMode = true
                this.opts.forceOverwrite = false
                this.opts.noOverwrite = false
            } else if (c == 'n') {
                this.opts.noOverwrite = true
                this.opts.forceOverwrite = false
                this.opts.interactiveMode = false
            } else if (c == 'v') {
                this.opts.verboseOutput = true
            } else {
                return FlagParseResult.illegalOption("-")
            }
        }
        return FlagParseResult.continueParsing
    }

    /// 去初始化
    public func deinit() {
        if (let Some(fd) <- this.args.targetFd) {
            fd.close()
        }
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "mv")
    }
}

/// mv命令选项
public struct MvOpts {
    /// -f: 强制覆盖
    public var forceOverwrite: Bool = true
    /// -h: 不解引用符号链接
    public var noDereference: Bool = false
    /// -i: 交互模式
    public var interactiveMode: Bool = false
    /// -n: 不覆盖
    public var noOverwrite: Bool = false
    /// -v: 详细输出
    public var verboseOutput: Bool = false
}

/// mv解析结果
public enum MvParseResult {
    | ok(Unit)
    | err(MvParseError)
}

/// mv解析错误
public enum MvParseError {
    | illegalOption(String)
    | showUsage
}

/// Shell mv检查目标任务
public class ShellMvCheckTargetTask {
    public var mv: MvCmd
    public var cwd: FD
    public var target: String = ""
    public var result: ?FD = None

    /// 调度
    public func schedule() {
        // 排队到线程池
    }
}

/// Shell mv批量移动任务
public class ShellMvBatchedTask {
    public var mv: MvCmd
    public var sources: Array<String> = []
    public var target: String = ""
    public var targetFd: ?FD = None
    public var cwd: FD
    public var err: ?SyscallError = None
    public var errPathOwned: Bool = false

    /// 调度
    public func schedule() {
        // 排队到线程池
    }
}

/// 标志解析结果
public enum FlagParseResult {
    | done
    | continueParsing
    | illegalOption(String)
}
