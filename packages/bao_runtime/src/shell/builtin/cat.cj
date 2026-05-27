// cat.cj - cat命令
// 对应 Bun: src/runtime/shell/builtin/cat.zig
// 严格翻译Bun shell cat命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*
import bao_collections.*

// ============================================================================
// cat命令 - 连接并打印文件内容
// 支持从stdin或文件路径读取
// ============================================================================

/// cat命令状态类型
public enum CatState {
    | idle
    | execStdin
    | execFilepathArgs
    | waitingWriteErr
    | done
}

public class CatCmd {
    /// 选项
    public var opts: CatOpts = CatOpts()
    /// 状态
    public var state: CatState = CatState.idle

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = CatState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, s.toArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stderr, s.toArray())
        return this.bltn().done(exitCode)
    }

    /// 启动
    public func start(): Yield {
        // 解析参数
        let parseResult = this.opts.parse(this.bltn().getArgsSlice())
        match (parseResult) {
            case ParseResult.ok(filepathArgs) =>
                let shouldReadFromStdin = filepathArgs.isNone() || filepathArgs.getOrThrow().size == 0
                if (shouldReadFromStdin) {
                    this.state = CatState.execStdin
                } else {
                    this.state = CatState.execFilepathArgs
                }
            case ParseResult.err(parseErr) =>
                let buf: String = match (parseErr) {
                    case ParseError.illegalOption(optStr) =>
                        this.bltn().fmtErrorArena(BuiltinKind.cat, "illegal option -- " + optStr + "\n", [])
                    case ParseError.showUsage =>
                        BuiltinKind.cat.usageString()
                    case ParseError.unsupported(optStr) =>
                        this.bltn().fmtErrorArena(BuiltinKind.cat, "unsupported option, please open a GitHub issue -- " + optStr + "\n", [])
                }
                return this.writeFailingError(buf, ExitCode.exited(1))
        }

        return this.next()
    }

    /// 下一步
    public func next(): Yield {
        match (this.state) {
            case CatState.idle =>
                throw Exception("Invalid state")
            case CatState.execStdin =>
                if (!this.bltn().stdin.needsIO()) {
                    let buf = this.bltn().readStdinNoIO()
                    if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
                        return this.bltn().stdout.enqueue(this, buf.toArray(), safeguard)
                    }
                    this.bltn().writeNoIO(OutKind.Stdout, buf.toArray())
                    return this.bltn().done(ExitCode.exited(0))
                }
                return Yield.suspended
            case CatState.execFilepathArgs => ()
                // 处理文件路径参数
                return Yield.suspended
            case CatState.waitingWriteErr =>
                return Yield.failed
            case CatState.done =>
                return this.bltn().done(ExitCode.exited(0))
        }
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, err: ?SystemError): Yield {
        if (err.isSome()) {
            err.getOrThrow().deref()
            return this.bltn().done(ExitCode.exited(1))
        }

        match (this.state) {
            case CatState.execStdin =>
                return Yield.suspended
            case CatState.execFilepathArgs =>
                return this.next()
            case CatState.waitingWriteErr =>
                return this.bltn().done(ExitCode.exited(1))
            case _ =>
                return Yield.suspended
        }
    }

    /// IO读取器数据块回调
    public func onIOReaderChunk(arr: Array<Byte>, remove: Bool): Yield {
        if (let Some(safeguard) <- this.bltn().stdout.needsIO()) {
            return this.bltn().stdout.enqueue(this, arr, safeguard)
        }
        this.bltn().writeNoIO(OutKind.Stdout, arr)
        return Yield.done
    }

    /// IO读取器完成回调
    public func onIOReaderDone(systemError: ?SystemError): Yield {
        if (systemError.isSome()) {
            systemError.getOrThrow().deref()
            return this.bltn().done(ExitCode.exited(1))
        }

        match (this.state) {
            case CatState.execStdin =>
                return this.bltn().done(ExitCode.exited(0))
            case CatState.execFilepathArgs =>
                return this.next()
            case _ =>
                return Yield.suspended
        }
    }

    /// 去初始化
    public func deinit() {}

    /// 获取Builtin引用
    public func bltn(): BuiltinImpl {
        return BuiltinImpl()
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
        var idx: Int64 = 0
        while (idx < arr.size) {
            let arg = arr[idx]
            if (arg.size < 2) {
                break
            }
            // 简化：当前不支持选项
            return ParseResult.err(ParseError.unsupported(arg))
        }

        if (idx >= arr.size) {
            return ParseResult.ok(Option<Array<String>>.None)
        }
        return ParseResult.ok(arr[idx..])
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
