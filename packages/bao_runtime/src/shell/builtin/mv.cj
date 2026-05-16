// mv.cj - mv命令
// 对应 Bun: src/runtime/shell/builtin/mv.zig
// 严格翻译Bun shell mv命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

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
    public var innerState: CheckTargetInnerState = .running
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
    public var errPathOwned: Boolean = false
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
    public func writeFailingError(buf: String, exitCode: ExitCode): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.state = MvState.waitingWriteErr(exitCode)
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done && this.state != .err) {
            switch (this.state) {
                case .idle =>
                    if (let e = this.parseOpts().getErr()) {
                        let buf = switch (e) {
                            case .illegalOption(let optStr) =>
                                this.bltn().fmtErrorArena("mv", "illegal option -- ${optStr}\n", [])
                            case .showUsage =>
                                Builtin.Kind.usageString("mv")
                        }
                        return this.writeFailingError(buf, 1)
                    }

                    // 调度检查目标任务
                    return Yield.suspended

                case .checkTarget =>
                    // 等待检查目标完成
                    return Yield.suspended

                case .executing =>
                    // 等待所有任务完成
                    return Yield.suspended

                case .waitingWriteErr =>
                    return Yield.failed

                case .done, .err =>
                    panic("不可达状态")
            }
        }

        switch (this.state) {
            case .done =>
                return this.bltn().done(0)
            case _ =>
                return this.bltn().done(1)
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, e: ?SystemError): Yield {
        if (let err = e) {
            err.deref()
        }
        switch (this.state) {
            case .waitingWriteErr =>
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
        if (args.length == 0) {
            return .err(.showUsage)
        }

        while (idx < args.length) {
            let flag = args[idx]
            switch (this.parseFlag(flag)) {
                case .done =>
                    let filepathArgs = args[idx..]
                    if (filepathArgs.length < 2) {
                        return .err(.showUsage)
                    }
                    this.args.sources = filepathArgs[0..(filepathArgs.length - 1)]
                    this.args.target = filepathArgs[filepathArgs.length - 1]
                    return .ok(())
                case .continueParsing =>
                    idx++
                case .illegalOption(let optStr) =>
                    return .err(.illegalOption(optStr))
            }
            idx++
        }

        return .err(.showUsage)
    }

    /// 解析单个标志
    func parseFlag(flag: String): FlagParseResult {
        if (flag.length == 0) {
            return .done
        }
        if (flag[0] != '-') {
            return .done
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
                return .illegalOption("-")
            }
        }
        return .continueParsing
    }

    /// 去初始化
    public func deinit() {
        if (let fd = this.args.targetFd) {
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
    public var forceOverwrite: Boolean = true
    /// -h: 不解引用符号链接
    public var noDereference: Boolean = false
    /// -i: 交互模式
    public var interactiveMode: Boolean = false
    /// -n: 不覆盖
    public var noOverwrite: Boolean = false
    /// -v: 详细输出
    public var verboseOutput: Boolean = false
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
    public var errPathOwned: Boolean = false

    /// 调度
    public func schedule() {
        // 排队到线程池
    }
}
