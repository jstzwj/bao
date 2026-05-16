// mkdir.cj - mkdir命令
// 对应 Bun: src/runtime/shell/builtin/mkdir.zig
// 严格翻译Bun shell mkdir命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// mkdir命令 - 创建目录
// 支持 -p (递归创建) 和 -v (详细输出)
// ============================================================================

/// mkdir命令
public enum MkdirState {
    | idle
    | exec(ExecState)
    | waitingWriteErr
    | done
}

public struct ExecState {
    public var started: Bool = false
    public var tasksCount: UIntPtr = 0
    public var tasksDone: UIntPtr = 0
    public var outputWaiting: UInt16 = 0
    public var outputDone: UInt16 = 0
    public var args: Array<String>
    public var err: ?SystemError = None
}

public class MkdirCmd {
    /// 选项
    public var opts: MkdirOpts = MkdirOpts()
    /// 状态
    public var state: MkdirState = MkdirState.idle

    /// 状态类型


    /// 执行状态
    /// 对应 Bun: exec struct in Mkdir state


    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (let Some(err) <- e) {
            err.deref()
        }

        match (this.state) {
            case waitingWriteErr =>
                return this.bltn().done(1)
            case exec => ()
                // outputDone++
            case MkdirState.idle | MkdirState.done =>
                panic("Invalid state")
        }

        return this.next()
    }

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = MkdirStateMultiArgsInnerState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// 启动
    public func start(): Yield {
        // 解析参数
        let parseResult = this.opts.parse(this.bltn().argsSlice())
        let filepathArgs = match (parseResult) {
            case MkdirParseResult.ok(args) => args
            case MkdirParseResult.err(e) =>
                let buf = match (e) {
                    case MkdirParseError.illegalOption(optStr) =>
                        this.bltn().fmtErrorArena("mkdir", "illegal option -- " + optStr + "\n", [])
                    case MkdirParseError.showUsage =>
                        Builtin.Kind.usageString("mkdir")
                    case MkdirParseError.unsupported(unsupported) =>
                        this.bltn().fmtErrorArena("mkdir", "unsupported option, please open a GitHub issue -- " + unsupported + "\n", [])
                }
                return this.writeFailingError(buf, 1)
        }

        if (filepathArgs == None || filepathArgs.size == 0) {
            return this.writeFailingError(Builtin.Kind.usageString("mkdir"), 1)
        }

        this.state = MkdirState.exec(ExecState(filepathArgs))
        return this.next()
    }

    /// 下一步
    public func next(): Yield {
        match (this.state) {
            case idle =>
                panic("Invalid state")
            case exec(exec) =>
                if (exec.started) {
                    if (exec.tasksDone >= exec.tasksCount && exec.outputDone >= exec.outputWaiting) {
                        let exitCode: ExitCode = if (exec.err != None) { 1 } else { 0 }
                        if (let Some(e) <- exec.err) {
                            e.deref()
                        }
                        this.state = MkdirState.done
                        return this.bltn().done(exitCode)
                    }
                    return Yield.suspended
                }

                // 为每个参数启动任务
                // 注意: 需要线程池支持
                return Yield.suspended

            case waitingWriteErr =>
                return Yield.failed
            case done =>
                return this.bltn().done(0)
        }
    }

    /// Shell mkdir任务完成回调
    public func onShellMkdirTaskDone(task: ShellMkdirTask): Unit {
        // 增加tasksDone并处理输出
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "mkdir")
    }
}

/// mkdir命令选项
public struct MkdirOpts {
    /// -m, --mode: 设置文件模式
    public var mode: ?UInt32 = None
    /// -p, --parents: 递归创建父目录
    public var parents: Bool = false
    /// -v, --verbose: 打印创建的每个目录
    public var verbose: Bool = false

    /// 解析参数
    public func parse(arr: Array<String>): MkdirParseResult {
        var idx: UInt32 = 0
        while (idx < args.size) {
            let arg = args[idx]
            if (arg.size == 0 || arg[0] != '-') {
                break
            }
            if (arg == "--mode") {
                return MkdirParseResult.err(MkdirParseError.unsupported("--mode"))
            } else if (arg == "--parents") {
                this.parents = true
            } else if (arg == "--verbose") {
                this.verbose = true
            } else {
                for (c in arg.substring(1)) {
                    if (c == 'm') {
                        return MkdirParseResult.err(MkdirParseError.unsupported("-m"))
                    } else if (c == 'p') {
                        this.parents = true
                    } else if (c == 'v') {
                        this.verbose = true
                    } else {
                        return MkdirParseResult.err(MkdirParseError.illegalOption("-" + c.toString()))
                    }
                }
            }
            idx++
        }

        if (idx >= args.size) {
            return MkdirParseResult.ok(None)
        }
        return MkdirParseResult.ok(args[idx..])
    }
}

/// mkdir解析结果
public enum MkdirParseResult {
    | ok(?Array<String>)
    | err(MkdirParseError)
}

/// mkdir解析错误
public enum MkdirParseError {
    | illegalOption(String)
    | showUsage
    | unsupported(String)
}

/// Shell mkdir任务（线程池任务）
public class ShellMkdirTask {
    /// 父mkdir命令
    public var mkdir: MkdirCmd
    /// 选项
    public var opts: MkdirOpts
    /// 文件路径
    public var filepath: String = ""
    /// 当前工作目录路径
    public var cwdPath: String = ""
    /// 创建的目录列表（用于verbose输出）
    public var createdDirectories: ArrayList<Byte> = ArrayList<Byte>()
    /// 错误
    public var err: ?SystemError = None

    /// 调度到线程池
    public func schedule() {
        // 排队到线程池
    }

    /// 获取输出并重置
    public func takeOutput(): ArrayList<Byte> {
        let ret = this.createdDirectories
        this.createdDirectories = ArrayList<Byte>()
        return ret
    }

    /// 去初始化
    public func deinit() {
        this.createdDirectories.clear()
    }
}
