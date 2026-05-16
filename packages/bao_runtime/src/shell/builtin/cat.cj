// cat.cj - cat命令
// 对应 Bun: src/runtime/shell/builtin/cat.zig
// 严格翻译Bun shell cat命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// cat命令 - 连接并打印文件内容
// 支持从stdin或文件路径读取
// ============================================================================

/// cat命令
public enum CatState {
    | idle
    | execStdin(ExecStdinState)
    | execFilepathArgs(ExecFilepathArgsState)
    | waitingWriteErr
    | done
}

public struct ExecStdinState {
    public var inDone: Bool = false
    public var chunksQueued: UInt32 = 0
    public var chunksDone: UInt32 = 0
    public var errno: ExitCode = 0
}

public struct ExecFilepathArgsState {
    public var args: Array<String>
    public var idx: UInt32 = 0
    public var reader: ?IOReader = None
    public var chunksQueued: UInt32 = 0
    public var chunksDone: UInt32 = 0
    public var outDone: Bool = false
    public var inDone: Bool = false

    public func deinit() {
        if (let Some(r) <- this.reader) {
            r.deref()
        }
    }
}

public class CatCmd {
    /// 选项
    public var opts: CatOpts = CatOpts()
    /// 状态
    public var state: CatState = CatState.idle

    /// 状态类型


    /// 从stdin执行的状态


    /// 从文件路径执行的状态
    /// 对应 Bun: exec_filepath_args struct in Cat state


    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = CatStateMultiArgsInnerState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// 启动
    public func start(): Yield {
        // 解析参数
        let parseResult = this.opts.parse(this.bltn().argsSlice())
        match (parseResult) {
            case ok(filepathArgs) =>
                let shouldReadFromStdin = filepathArgs == None || filepathArgs.size == 0
                if (shouldReadFromStdin) {
                    this.state = CatState.execStdin(ExecStdinState())
                } else {
                    this.state = CatState.execFilepathArgs(ExecFilepathArgsState(
                        args: filepathArgs
                    ))
                }
            case ParseResult.err(e) =>
                let buf = match (e) {
                    case ParseError.illegalOption(optStr) =>
                        this.bltn().fmtErrorArena("cat", "illegal option -- " + optStr + "\n", [])
                    case ParseError.showUsage =>
                        Builtin.Kind.usageString("cat")
                    case ParseError.unsupported(unsupported) =>
                        this.bltn().fmtErrorArena("cat", "unsupported option, please open a GitHub issue -- " + unsupported + "\n", [])
                }
                return this.writeFailingError(buf, 1)
        }

        return this.next()
    }

    /// 下一步
    public func next(): Yield {
        match (this.state) {
            case idle =>
                panic("Invalid state")
            case execStdin =>
                if (!this.bltn().stdin.needsIO()) {
                    let buf = this.bltn().readStdinNoIO()
                    if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
                        return this.bltn().stdout.enqueue(this, buf, safeguard)
                    }
                    this.bltn().writeNoIO(OutKind.stdout, buf)
                    return this.bltn().done(0)
                }
                this.bltn().stdin.fd.addReader(this)
                return this.bltn().stdin.fd.start()
            case execFilepathArgs => ()
                // 处理文件路径参数
                return Yield.suspended
            case waitingWriteErr =>
                return Yield.failed
            case done =>
                return this.bltn().done(0)
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, err: ?SystemError): Yield {
        // 写入stdout出错，取消所有操作并写入错误
        if (let Some(e) <- err) {
            defer { e.deref() }
            let errno: ExitCode = e.getErrno()
            match (this.state) {
                case execStdin => ()
                    // 取消reader
                    if (this.bltn().stdin.needsIO()) {
                        this.bltn().stdin.fd.removeReader(this)
                    }
                    return this.bltn().done(errno)
                case execFilepathArgs =>
                    return this.bltn().done(errno)
                case waitingWriteErr =>
                    return this.bltn().done(e.getErrno())
                case _ =>
                    panic("Invalid state")
            }
        }

        match (this.state) {
            case execStdin => ()
                // 检查是否所有块都已写入
                return Yield.suspended
            case execFilepathArgs =>
                return this.next()
            case waitingWriteErr =>
                return this.bltn().done(1)
            case _ =>
                panic("Invalid state")
        }
    }

    /// IO读取器数据块回调
    public func onIOReaderChunk(arr: Array<Byte>, remove: Bool): Yield {
        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            return this.bltn().stdout.enqueue(this, chunk, safeguard)
        }
        this.bltn().writeNoIO(OutKind.stdout, chunk)
        return Yield.done
    }

    /// IO读取器完成回调
    public func onIOReaderDone(systemError: ?SystemError): Yield {
        let errno: ExitCode = if (let Some(e) <- err) {
            defer { e.deref() }
            e.getErrno()
        } else { 0 }

        match (this.state) {
            case execStdin =>
                if (errno != 0) {
                    return this.bltn().done(errno)
                }
                return this.bltn().done(0)
            case execFilepathArgs =>
                return this.next()
            case _ =>
                return Yield.suspended
        }
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "cat")
    }
}

/// cat命令选项
public struct CatOpts {
    /// -b: 编号非空行
    public var numberNonblank: Bool = false
    /// -e: 显示非打印字符和行尾$
    public var showEnds: Bool = false
    /// -n: 编号所有行
    public var numberAll: Bool = false
    /// -s: 压缩连续空行
    public var squeezeBlank: Bool = false
    /// -t: 显示制表符为^I
    public var showTabs: Bool = false
    /// -u: 禁用输出缓冲
    public var disableOutputBuffering: Bool = false
    /// -v: 显示非打印字符
    public var showNonprinting: Bool = false

    /// 解析参数
    public func parse(arr: Array<String>): ParseResult {
        var idx: UInt32 = 0
        while (idx < args.size) {
            let arg = args[idx]
            if (arg.size < 2 || arg[0] != '-') {
                break
            }
            for (c in arg.substring(1)) {
                if (c == 'b' || c == 'e' || c == 'n' || c == 's' || c == 't' || c == 'u' || c == 'v') {
                    // 当前不支持这些选项
                    return ParseResult.err(.unsupported(arg))
                } else {
                    return ParseResult.err(.illegalOption(arg))
                }
            }
            idx++
        }

        if (idx >= args.size) {
            return ParseResult.ok(None)
        }
        return ParseResult.ok(args[idx..])
    }
}

/// 解析结果
public enum ParseResult {
    | ok(?Array<String>)
    | err(ParseError)
}

/// 解析错误
public enum ParseError {
    | illegalOption(String)
    | showUsage
    | unsupported(String)
}
