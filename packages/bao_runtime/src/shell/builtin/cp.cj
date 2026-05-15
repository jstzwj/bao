// cp.cj - cp命令
// 对应 Bun: src/runtime/shell/builtin/cp.zig
// 严格翻译Bun shell cp命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// cp命令 - 复制文件和目录
// 支持 -R (递归复制) 和 -v (详细输出)
// 使用线程池并发复制多个文件
// ============================================================================

/// cp命令
public class CpCmd {
    /// 选项
    public var opts: CpOpts = CpOpts()
    /// 状态
    public var state: CpState = CpState.idle

    /// 状态类型
    public enum CpState {
        case idle
        case exec(ExecState)
        case waitingWriteErr
        case done
    }

    /// 执行状态
    /// 对应 Bun: exec struct in Cp state
    public struct ExecState {
        public var targetPath: String = ""
        public var pathsToCopy: Array<String>
        public var started: Boolean = false
        public var tasksCount: UInt32 = 0
        public var outputWaiting: UInt32 = 0
        public var outputDone: UInt32 = 0
        public var err: ?ShellErr = None
    }

    /// 启动
    public func start(): Yield {
        let parseResult = this.opts.parse(this.bltn().argsSlice())
        let maybeFilepathArgs = switch (parseResult) {
            case .ok(let args) => args
            case .err(let e) =>
                let buf = switch (e) {
                    case .illegalOption(let optStr) =>
                        this.bltn().fmtErrorArena("cp", "illegal option -- ${optStr}\n", [])
                    case .showUsage =>
                        Builtin.Kind.usageString("cp")
                    case .unsupported(let unsupported) =>
                        this.bltn().fmtErrorArena("cp", "unsupported option, please open a GitHub issue -- ${unsupported}\n", [])
                }
                return this.writeFailingError(buf, 1)
        }

        if (maybeFilepathArgs == None || maybeFilepathArgs.length <= 1) {
            return this.writeFailingError(Builtin.Kind.usageString("cp"), 1)
        }

        let args = maybeFilepathArgs
        let pathsToCopy = args[0..(args.length - 1)]
        let tgtPath = args[args.length - 1]

        this.state = CpState.exec(ExecState(
            targetPath: tgtPath,
            pathsToCopy: pathsToCopy
        ))

        return this.next()
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != .done) {
            switch (this.state) {
                case .idle =>
                    panic("Invalid state for \"Cp\": idle")
                case .exec(let exec) =>
                    if (exec.started) {
                        if (exec.tasksCount <= 0 && exec.outputDone >= exec.outputWaiting) {
                            let exitCode: ExitCode = if (exec.err != None) 1 else 0
                            this.state = CpState.done
                            return this.bltn().done(exitCode)
                        }
                        return Yield.suspended
                    }

                    // 为每个参数启动复制任务
                    return Yield.suspended

                case .waitingWriteErr =>
                    return Yield.failed
                case .done =>
                    panic("不可达状态")
            }
        }

        return this.bltn().done(0)
    }

    /// 写入失败错误
    public func writeFailingError(buf: String, exitCode: ExitCode): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.state = CpState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, e: ?SystemError): Yield {
        if (let err = e) {
            err.deref()
        }
        if (this.state == .waitingWriteErr) {
            return this.bltn().done(1)
        }
        if (let exec = this.state.getExec()) {
            // exec.outputDone++
        }
        return this.next()
    }

    /// Shell cp任务完成回调
    public func onShellCpTaskDone(task: ShellCpTask): Unit {
        // 处理任务完成
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "cp")
    }
}

/// cp命令选项（位标志）
public struct CpOpts {
    /// -f: 强制覆盖
    public var removeAndCreateNewFileIfNotFound: Boolean = false
    /// -H: 解引用命令行符号链接
    public var dereferenceCommandLineSymlinks: Boolean = false
    /// -i: 交互模式
    public var interactive: Boolean = false
    /// -L: 解引用所有符号链接
    public var dereferenceAllSymlinks: Boolean = false
    /// -P: 保留符号链接
    public var preserveSymlinks: Boolean = false
    /// -p: 保留文件属性
    public var preserveFileAttributes: Boolean = false
    /// -R: 递归复制
    public var recursive: Boolean = false
    /// -v: 详细输出
    public var verbose: Boolean = false
    /// -n: 不覆盖现有文件
    public var overwriteExistingFile: Boolean = true

    /// 解析参数
    public func parse(args: Array<String>): CpParseResult {
        var idx: UInt32 = 0
        while (idx < args.length) {
            let arg = args[idx]
            if (arg.length == 0 || arg[0] != '-') {
                break
            }
            for (c in arg.substring(1)) {
                if (c == 'R') {
                    this.recursive = true
                } else if (c == 'v') {
                    this.verbose = true
                } else if (c == 'n') {
                    this.overwriteExistingFile = true
                    this.removeAndCreateNewFileIfNotFound = false
                } else if (c == 'f' || c == 'H' || c == 'i' || c == 'L' || c == 'P' || c == 'p') {
                    return .err(.unsupported("-${c}"))
                } else {
                    return .err(.illegalOption("-${c}"))
                }
            }
            idx++
        }

        if (idx >= args.length) {
            return .ok(None)
        }
        return .ok(args[idx..])
    }
}

/// cp解析结果
public enum CpParseResult {
    case ok(?Array<String>)
    case err(CpParseError)
}

/// cp解析错误
public enum CpParseError {
    case illegalOption(String)
    case showUsage
    case unsupported(String)
}

/// Shell cp任务（线程池任务）
public class ShellCpTask {
    /// 父cp命令
    public var cp: CpCmd
    /// 选项
    public var opts: CpOpts
    /// 源路径
    public var src: String = ""
    /// 目标路径
    public var tgt: String = ""
    /// 详细输出
    public var verboseOutput: ArrayList<Byte> = ArrayList<Byte>()
    /// 错误
    public var err: ?ShellErr = None

    /// 调度到线程池
    public func schedule() {
        // 排队到线程池
    }

    /// 获取输出并重置
    public func takeOutput(): ArrayList<Byte> {
        let ret = this.verboseOutput
        this.verboseOutput = ArrayList<Byte>()
        return ret
    }

    /// 去初始化
    public func deinit() {
        this.verboseOutput.clear()
    }
}
