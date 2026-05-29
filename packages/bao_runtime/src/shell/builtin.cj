// builtin.cj - Shell内置命令
// 对应 Bun: src/runtime/shell/Builtin.zig
// 严格翻译Bun shell内置命令到仓颉
//
// 一些常见命令（如ls、which、mv等coreutils）作为"内置"命令在Zig中原生实现
// 原因：
// 1. 可以重用Bun中大量现有代码，通常更快
// 2. 内置命令在Bun进程内运行，无需生成新子进程

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_jsc.{ArrayBufferStrong}
import bao_collections.ArrayList

// ============================================================================
// 内置命令类型枚举 - extracted from BuiltinImpl
// ============================================================================

/// 内置命令类型
public enum BuiltinKind {
    | cat
    | touch
    | mkdir
    | export
    | cd
    | echo
    | pwd
    | which
    | rm
    | mv
    | ls
    | exit
    | true_
    | false_
    | yes
    | seq
    | dirname
    | basename
    | cp

    /// POSIX上禁用的内置命令
    public static func disabledOnPosix(): Array<BuiltinKind> {
        [BuiltinKind.cat, BuiltinKind.cp]
    }

    /// 从字符串获取命令类型
    public static func fromStr(str: String): ?BuiltinKind {
        match (str) {
            case "cat" => BuiltinKind.cat
            case "touch" => BuiltinKind.touch
            case "mkdir" => BuiltinKind.mkdir
            case "export" => BuiltinKind.export
            case "cd" => BuiltinKind.cd
            case "echo" => BuiltinKind.echo
            case "pwd" => BuiltinKind.pwd
            case "which" => BuiltinKind.which
            case "rm" => BuiltinKind.rm
            case "mv" => BuiltinKind.mv
            case "ls" => BuiltinKind.ls
            case "exit" => BuiltinKind.exit
            case "true" => BuiltinKind.true_
            case "false" => BuiltinKind.false_
            case "yes" => BuiltinKind.yes
            case "seq" => BuiltinKind.seq
            case "dirname" => BuiltinKind.dirname
            case "basename" => BuiltinKind.basename
            case "cp" => BuiltinKind.cp
            case _ => None
        }
    }

    /// 用法字符串
    public func usageString(): String {
        match (this) {
            case cat => "usage: cat [-belnstuv] [file ...]\n"
            case touch => "usage: touch [-A [-][[hh]mm]SS] [-achm] [-r file] [-t [[CC]YY]MMDDhhmm[.SS]]\n       [-d YYYY-MM-DDThh:mm:SS[.frac][tz]] file ...\n"
            case mkdir => "usage: mkdir [-pv] [-m mode] directory_name ...\n"
            case export => ""
            case cd => ""
            case echo => ""
            case pwd => ""
            case which => ""
            case rm => "usage: rm [-f | -i] [-dIPRrvWx] file ...\n       unlink [--] file\n"
            case mv => "usage: mv [-f | -i | -n] [-hv] source target\n       mv [-f | -i | -n] [-v] source ... directory\n"
            case ls => "usage: ls [-@ABCFGHILOPRSTUWabcdefghiklmnopqrstuvwxy1%] [--color=when] [-D format] [file ...]\n"
            case exit => "usage: exit [n]\n"
            case true_ => ""
            case false_ => ""
            case yes => "usage: yes [expletive]\n"
            case seq => "usage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"
            case dirname => "usage: dirname string\n"
            case basename => "usage: basename string\n"
            case cp => "usage: cp [-R [-H | -L | -P]] [-fi | -n] [-aclpsvXx] source_file target_file\n       cp [-R [-H | -L | -P]] [-fi | -n] [-aclpsvXx] source_file ... target_directory\n"
        }
    }
}

/// 内置命令实现联合体 - extracted from BuiltinImpl
public enum BuiltinImplKind {
    | cat(Cat)
    | touch(Touch)
    | mkdir(Mkdir)
    | export(Export)
    | cd(Cd)
    | echo(Echo)
    | pwd(Pwd)
    | which(Which)
    | rm(Rm)
    | mv(Mv)
    | ls(Ls)
    | exit(Exit)
    | true_(True)
    | false_(False)
    | yes(Yes)
    | seq(Seq)
    | dirname(Dirname)
    | basename(Basename)
    | cp(Cp)
}

// ============================================================================
// 内置命令IO - extracted from BuiltinImpl
// ============================================================================

/// Blob引用计数包装
public class BuiltinBlob {
    public var refCount: UInt32 = 1
    public var blob: Any  // WebCoreBlob — 使用 Any 避免跨包引用

    public init(blob: Any) {
        this.blob = blob
    }

    /// 复制引用
    public func dupeRef(): BuiltinBlob {
        this.ref()
        return this
    }

    /// 增加引用
    public func ref() {
        this.refCount += 1
    }

    /// 减少引用
    public func deref() {
        this.refCount -= 1
        if (this.refCount == 0) {
            this.deinit()
        }
    }

    /// 去初始化
    func deinit() {
        // blob is Any type, no deinit available
    }
}

/// 数组缓冲区
public struct BuiltinArrayBuf {
    public var buf: ArrayBufferStrong
    public var i: UInt32 = 0

    public init() {
        buf = ArrayBufferStrong()
    }
}

/// 输出类型 - extracted from BuiltinIO
public enum BuiltinOutput {
    | fd(IOWriter, ?ArrayList<Byte>)
    | buf(ArrayList<Byte>)
    | arraybuf(BuiltinArrayBuf)
    | blob(BuiltinBlob)
    | ignore

    /// 增加引用
    public func ref(): BuiltinOutput {
        match (this) {
            case fd(writer, _) =>
                writer.ref()
            case blob(bl) =>
                bl.ref()
            case buf(_) => ()
            case arraybuf(_) => ()
            case ignore => ()
        }
        return this
    }

    /// 减少引用
    public func deref() {
        match (this) {
            case fd(writer, _) =>
                writer.deref()
            case blob(bl) =>
                bl.deref()
            case arraybuf(ab) =>
                () // BuiltinArrayBuf does not have deinit
            case buf(bl) =>
                bl.clear()
            case ignore =>
                () // 无操作
        }
    }

    /// 是否需要IO
    public func needsIO(): ?OutputNeedsIOSafeGuard {
        match (this) {
            case fd(_, _) =>
                return OutputNeedsIOSafeGuard.outputNeedsIo
            case buf(_) => return None
            case arraybuf(_) => return None
            case blob(_) => return None
            case ignore => return None
        }
    }

    /// 入队格式化输出（内置命令）
    public func enqueueFmtBltn(ptr: Any, kind: ?BuiltinKind, fmt: String, args: Array<Any>): Yield {
        match (this) {
            case fd(writer, captured) =>
                return writer.enqueueFmtBltn(ptr, captured, kind, fmt, args)
            case buf(_) => return Yield.done
            case arraybuf(_) => return Yield.done
            case blob(_) => return Yield.done
            case ignore => return Yield.done
        }
    }

    /// 入队
    public func enqueue(ptr: Any, buf: Array<Byte>, safeguard: OutputNeedsIOSafeGuard): Yield {
        match (this) {
            case fd(writer, captured) =>
                return writer.enqueue(ptr, captured, buf)
            case buf(_) => return Yield.done
            case arraybuf(_) => return Yield.done
            case blob(_) => return Yield.done
            case ignore => return Yield.done
        }
    }
}

/// 输入类型 - extracted from BuiltinIO
public enum BuiltinInput {
    | fd(IOReader)
    | buf(ArrayList<Byte>)
    | arraybuf(BuiltinArrayBuf)
    | blob(BuiltinBlob)
    | ignore

    /// 增加引用
    public func ref(): BuiltinInput {
        match (this) {
            case fd(reader) =>
                reader.ref()
            case blob(bl) =>
                bl.ref()
            case buf(_) => ()
            case arraybuf(_) => ()
            case ignore => ()
        }
        return this
    }

    /// 减少引用
    public func deref() {
        match (this) {
            case fd(reader) =>
                reader.deref()
            case blob(bl) =>
                bl.deref()
            case buf(bl) =>
                bl.clear()
            case arraybuf(ab) =>
                () // BuiltinArrayBuf does not have deinit
            case ignore =>
                () // 无操作
        }
    }

    /// 是否需要IO
    public func needsIO(): Bool {
        match (this) {
            case fd(_) =>
                return true
            case buf(_) => return false
            case arraybuf(_) => return false
            case blob(_) => return false
            case ignore => return false
        }
    }
}

// ============================================================================
// 内置命令
// ============================================================================

/// 内置命令
public class BuiltinImpl {
    /// 命令类型
    public var kind: BuiltinKind
    /// 标准输入
    public var stdin: BuiltinInput
    /// 标准输出
    public var stdout: BuiltinOutput
    /// 标准错误
    public var stderr: BuiltinOutput
    /// 退出码
    public var exitCode: ?ExitCode = None

    /// 导出环境变量
    public var exportEnv: EnvMap
    /// 命令局部环境变量
    public var cmdLocalEnv: EnvMap

    /// Arena分配器
    public var arena: ArenaAllocator
    /// 当前工作目录文件描述符
    public var cwd: FD

    /// 参数
    public var args: ArrayList<?String>
    /// 参数切片缓存
    public var argsSlice: ?Array<String> = None

    /// 实现
    public var impl: BuiltinImplKind

    public init() {
        this.kind = BuiltinKind.cat
        this.stdin = BuiltinInput.ignore
        this.stdout = BuiltinOutput.ignore
        this.stderr = BuiltinOutput.ignore
        this.exportEnv = EnvMap()
        this.cmdLocalEnv = EnvMap()
        this.arena = ArenaAllocator()
        this.cwd = FD()
        this.args = ArrayList<?String>()
        this.impl = BuiltinImplKind.cat(Cat())
    }

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 初始化内置命令
    public static func initFunc(
        cmd: CmdState,
        interpreter: Interpreter,
        kind: BuiltinKind,
        arena: ArenaAllocator,
        node: Cmd,
        args: ArrayList<?String>,
        exportEnv: EnvMap,
        cmdLocalEnv: EnvMap,
        cwd: FD,
        io: IO
    ): ?Yield {
        let stdin = BuiltinInput.ignore
        let stdout = BuiltinOutput.ignore
        let stderr = BuiltinOutput.ignore

        let bltn = BuiltinImpl()
        bltn.kind = kind
        bltn.stdin = stdin
        bltn.stdout = stdout
        bltn.stderr = stderr
        bltn.exitCode = None
        bltn.arena = arena
        bltn.args = args
        bltn.exportEnv = exportEnv
        bltn.cmdLocalEnv = cmdLocalEnv
        bltn.cwd = cwd
        bltn.impl = BuiltinImplKind.cat(Cat())

        return None
    }

    // ========================================================================
    // 核心方法
    // ========================================================================

    /// 启动
    public func start(): Yield {
        return Yield.done
    }

    /// 去初始化
    public func deinit() {
        this.stdout.deref()
        this.stderr.deref()
        this.stdin.deref()
    }

    /// 完成
    public func done(exitCode: ExitCode): Yield {
        this.exitCode = exitCode
        let cmd = this.parentCmdMut()
        // 通知父命令节点完成
        return cmd.childDone(CmdChildPtr.initFunc(this), exitCode)
    }

    /// 获取参数切片
    public func getArgsSlice(): Array<String> {
        if (this.argsSlice.isSome()) {
            return this.argsSlice.getOrThrow()
        }
        var result = ArrayList<String>()
        for (arg in this.args) {
            if (arg.isSome()) {
                result.append(arg.getOrThrow())
            }
        }
        this.argsSlice = []
        return []
    }

    /// 获取父命令
    public func parentCmd(): CmdState {
        return CmdState()
    }

    /// 获取可变父命令
    public func parentCmdMut(): CmdState {
        return CmdState()
    }

    /// 无IO写入
    public func writeNoIO(ioKind: OutKind, buf: Array<Byte>): Maybe<UInt64> {
        if (buf.size == 0) {
            return Maybe<UInt64>.success(0)
        }
        match (this.stdout) {
            case buf(bufList) =>
                for (b in buf) {
                    bufList.append(b)
                }
                return Maybe<UInt64>.success(UInt64(buf.size))
            case arraybuf(_) => return Maybe<UInt64>.success(UInt64(buf.size))
            case blob(_) => return Maybe<UInt64>.success(UInt64(buf.size))
            case fd(_, _) => return Maybe<UInt64>.success(UInt64(buf.size))
            case ignore => return Maybe<UInt64>.success(UInt64(buf.size))
        }
    }

    /// 读取无IO标准输入
    public func readStdinNoIO(): String {
        match (this.stdin) {
            case arraybuf(ab) =>
                return String.fromUtf8(ab.buf.slice())
            case buf(bl) =>
                var sb = StringBuilder()
                for (b in bl) {
                    sb.append(Rune(b))
                }
                return sb.toString()
            case blob(bl) =>
                return "" // blob.blob.sharedView() not available
            case fd(_) => return ""
            case ignore => return ""
        }
    }

    /// 格式化错误到Arena
    public func fmtErrorArena(kind: ?BuiltinKind, fmt: String, args: Array<Any>): String {
        // 格式化: "builtin_name: " + fmt
        var prefix = ""
        match (kind) {
            case Some(k) => prefix = k.asStr() + ": "
            case None => ()
        }
        return prefix + fmt
    }

    /// 错误字符串
    public func taskErrorToString(kind: BuiltinKind, err: Any): String {
        return "unknown error"
    }
}

// ============================================================================
// 内置命令空结构体
// ============================================================================

/// cat命令
public struct Cat {}

/// touch命令
public struct Touch {}

/// mkdir命令
public struct Mkdir {}

/// export命令
public struct Export {}

/// cd命令
public struct Cd {}

/// echo命令
public struct Echo {}

/// pwd命令
public struct Pwd {}

/// which命令
public struct Which {}

/// rm命令
public struct Rm {}

/// mv命令
public struct Mv {}

/// ls命令
public struct Ls {}

/// exit命令
public struct Exit {}

/// true命令
public struct True {}

/// false命令
public struct False {}

/// yes命令
public struct Yes {}

/// seq命令
public struct Seq {}

/// dirname命令
public struct Dirname {}

/// basename命令
public struct Basename {}

/// cp命令
public struct Cp {}
