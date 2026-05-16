// cat.cj - cat命令
// 对应 Bun: src/runtime/shell/builtin/cat.zig
// 严格翻译Bun shell cat命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

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
    public var inDone: Boolean = false
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
    public var outDone: Boolean = false
    public var inDone: Boolean = false

    public func deinit() {
        if (let r = this.reader) {
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
    public func writeFailingError(buf: String, exitCode: ExitCode): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.state = CatState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// 启动
    public func start(): Yield {
        // 解析参数
        let parseResult = this.opts.parse(this.bltn().argsSlice())
        switch (parseResult) {
            case .ok(let filepathArgs) =>
                let shouldReadFromStdin = filepathArgs == None || filepathArgs.length == 0
                if (shouldReadFromStdin) {
                    this.state = CatState.execStdin(ExecStdinState())
                } else {
                    this.state = CatState.execFilepathArgs(ExecFilepathArgsState(
                        args: filepathArgs
                    ))
                }
            case .err(let e) =>
                let buf = switch (e) {
                    case .illegalOption(let optStr) =>
                        this.bltn().fmtErrorArena("cat", "illegal option -- ${optStr}\n", [])
                    case .showUsage =>
                        Builtin.Kind.usageString("cat")
                    case .unsupported(let unsupported) =>
                        this.bltn().fmtErrorArena("cat", "unsupported option, please open a GitHub issue -- ${unsupported}\n", [])
                }
                return this.writeFailingError(buf, 1)
        }

        return this.next()
    }

    /// 下一步
    public func next(): Yield {
        switch (this.state) {
            case .idle =>
                panic("Invalid state")
            case .execStdin =>
                if (!this.bltn().stdin.needsIO()) {
                    let buf = this.bltn().readStdinNoIO()
                    if (let safeguard = this.bltn().stdout.needsIO()) {
                        return this.bltn().stdout.enqueue(this, buf, safeguard)
                    }
                    this.bltn().writeNoIO(.stdout, buf)
                    return this.bltn().done(0)
                }
                this.bltn().stdin.fd.addReader(this)
                return this.bltn().stdin.fd.start()
            case .execFilepathArgs =>
                // 处理文件路径参数
                return Yield.suspended
            case .waitingWriteErr =>
                return Yield.failed
            case .done =>
                return this.bltn().done(0)
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        // 写入stdout出错，取消所有操作并写入错误
        if (let e = err) {
            defer { e.deref() }
            let errno: ExitCode = e.getErrno()
            switch (this.state) {
                case .execStdin =>
                    // 取消reader
                    if (this.bltn().stdin.needsIO()) {
                        this.bltn().stdin.fd.removeReader(this)
                    }
                    return this.bltn().done(errno)
                case .execFilepathArgs =>
                    return this.bltn().done(errno)
                case .waitingWriteErr =>
                    return this.bltn().done(e.getErrno())
                case _ =>
                    panic("Invalid state")
            }
        }

        switch (this.state) {
            case .execStdin =>
                // 检查是否所有块都已写入
                return Yield.suspended
            case .execFilepathArgs =>
                return this.next()
            case .waitingWriteErr =>
                return this.bltn().done(1)
            case _ =>
                panic("Invalid state")
        }
    }

    /// IO读取器数据块回调
    public func onIOReaderChunk(chunk: Array<Byte>, remove: Boolean): Yield {
        if (let safeguard = this.bltn().stdout.needsIO()) {
            return this.bltn().stdout.enqueue(this, chunk, safeguard)
        }
        this.bltn().writeNoIO(.stdout, chunk)
        return Yield.done
    }

    /// IO读取器完成回调
    public func onIOReaderDone(err: ?SystemError): Yield {
        let errno: ExitCode = if (let e = err) {
            defer { e.deref() }
            e.getErrno()
        } else 0

        switch (this.state) {
            case .execStdin =>
                if (errno != 0) {
                    return this.bltn().done(errno)
                }
                return this.bltn().done(0)
            case .execFilepathArgs =>
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
    public var numberNonblank: Boolean = false
    /// -e: 显示非打印字符和行尾$
    public var showEnds: Boolean = false
    /// -n: 编号所有行
    public var numberAll: Boolean = false
    /// -s: 压缩连续空行
    public var squeezeBlank: Boolean = false
    /// -t: 显示制表符为^I
    public var showTabs: Boolean = false
    /// -u: 禁用输出缓冲
    public var disableOutputBuffering: Boolean = false
    /// -v: 显示非打印字符
    public var showNonprinting: Boolean = false

    /// 解析参数
    public func parse(args: Array<String>): ParseResult {
        var idx: UInt32 = 0
        while (idx < args.length) {
            let arg = args[idx]
            if (arg.length < 2 || arg[0] != '-') {
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

        if (idx >= args.length) {
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
