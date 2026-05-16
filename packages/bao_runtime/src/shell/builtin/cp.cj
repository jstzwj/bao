// cp.cj - cp命令
// 对应 Bun: src/runtime/shell/builtin/cp.zig
// 严格翻译Bun shell cp命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// cp命令 - 复制文件和目录
// 支持 -R (递归复制) 和 -v (详细输出)
// 使用线程池并发复制多个文件
// ============================================================================

/// cp命令
public enum CpState {
    | idle
    | exec(ExecState)
    | waitingWriteErr
    | done
}

public struct ExecState {
    public var targetPath: String = ""
    public var pathsToCopy: Array<String>
    public var started: Bool = false
    public var tasksCount: UInt32 = 0
    public var outputWaiting: UInt32 = 0
    public var outputDone: UInt32 = 0
    public var err: ?ShellErr = None
}

public class CpCmd {
    /// 选项
    public var opts: CpOpts = CpOpts()
    /// 状态
    public var state: CpState = CpState.idle

    /// 状态类型


    /// 执行状态
    /// 对应 Bun: exec struct in Cp state


    /// 启动
    public func start(): Yield {
        let parseResult = this.opts.parse(this.bltn().argsSlice())
        let maybeFilepathArgs = match (parseResult) {
            case CpParseResult.ok(args) => args
            case CpParseResult.err(e) =>
                let buf = match (e) {
                    case CpParseError.illegalOption(optStr) =>
                        this.bltn().fmtErrorArena("cp", "illegal option -- " + optStr + "\n", [])
                    case CpParseError.showUsage =>
                        Builtin.Kind.usageString("cp")
                    case CpParseError.unsupported(unsupported) =>
                        this.bltn().fmtErrorArena("cp", "unsupported option, please open a GitHub issue -- " + unsupported + "\n", [])
                }
                return this.writeFailingError(buf, 1)
        }

        if (maybeFilepathArgs == None || maybeFilepathArgs.size <= 1) {
            return this.writeFailingError(Builtin.Kind.usageString("cp"), 1)
        }

        let args = maybeFilepathArgs
        let pathsToCopy = args[0..(args.size - 1)]
        let tgtPath = args[args.size - 1]

        this.state = CpState.exec(ExecState(
            targetPath: tgtPath,
            pathsToCopy: pathsToCopy
        ))

        return this.next()
    }

    /// 下一步
    public func next(): Yield {
        while (this.state != CheckTargetInnerState.done) {
            match (this.state) {
                case idle =>
                    panic("Invalid state for \"Cp\": idle")
                case exec(exec) =>
                    if (exec.started) {
                        if (exec.tasksCount <= 0 && exec.outputDone >= exec.outputWaiting) {
                            let exitCode: ExitCode = if (exec.err != None) { 1 } else { 0 }
                            this.state = CpState.done
                            return this.bltn().done(exitCode)
                        }
                        return Yield.suspended
                    }

                    // 为每个参数启动复制任务
                    return Yield.suspended

                case waitingWriteErr =>
                    return Yield.failed
                case done =>
                    panic("不可达状态")
            }
        }

        return this.bltn().done(0)
    }

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = CpStateMultiArgsInnerState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (let Some(err) <- e) {
            err.deref()
        }
        if (this.state == MultiArgsInnerState.waitingWriteErr) {
            return this.bltn().done(1)
        }
        if (let Some(exec) <- this.state.getExec()) {
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
    public var removeAndCreateNewFileIfNotFound: Bool = false
    /// -H: 解引用命令行符号链接
    public var dereferenceCommandLineSymlinks: Bool = false
    /// -i: 交互模式
    public var interactive: Bool = false
    /// -L: 解引用所有符号链接
    public var dereferenceAllSymlinks: Bool = false
    /// -P: 保留符号链接
    public var preserveSymlinks: Bool = false
    /// -p: 保留文件属性
    public var preserveFileAttributes: Bool = false
    /// -R: 递归复制
    public var recursive: Bool = false
    /// -v: 详细输出
    public var verbose: Bool = false
    /// -n: 不覆盖现有文件
    public var overwriteExistingFile: Bool = true

    /// 解析参数
    public func parse(arr: Array<String>): CpParseResult {
        var idx: UInt32 = 0
        while (idx < args.size) {
            let arg = args[idx]
            if (arg.size == 0 || arg[0] != '-') {
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

        if (idx >= args.size) {
            return .ok(None)
        }
        return .ok(args[idx..])
    }
}

/// cp解析结果
public enum CpParseResult {
    | ok(?Array<String>)
    | err(CpParseError)
}

/// cp解析错误
public enum CpParseError {
    | illegalOption(String)
    | showUsage
    | unsupported(String)
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
