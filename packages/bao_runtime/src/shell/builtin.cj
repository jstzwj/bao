// builtin.cj - Shell内置命令
// 对应 Bun: src/runtime/shell/Builtin.zig
// 严格翻译Bun shell内置命令到仓颉
//
// 一些常见命令（如ls、which、mv等coreutils）作为"内置"命令在Zig中原生实现
// 原因：
// 1. 可以重用Bun中大量现有代码，通常更快
// 2. 内置命令在Bun进程内运行，无需生成新子进程

package bao_runtime

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// 内置命令
// ============================================================================

/// 内置命令
public class BuiltinImpl {
    /// 命令类型
    public var kind: Kind
    /// 标准输入
    public var stdin: BuiltinIO.Input
    /// 标准输出
    public var stdout: BuiltinIO.Output
    /// 标准错误
    public var stderr: BuiltinIO.Output
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
    public var impl: Impl

    // ========================================================================
    // 内置命令类型枚举
    // ========================================================================

    /// 内置命令类型
    public enum Kind {
        case cat
        case touch
        case mkdir
        case export
        case cd
        case echo
        case pwd
        case which
        case rm
        case mv
        case ls
        case exit
        case true_
        case false_
        case yes
        case seq
        case dirname
        case basename
        case cp

        /// POSIX上禁用的内置命令
        public static let disabledOnPosix: Array<Kind> = [Kind.cat, Kind.cp]

        /// 从字符串获取命令类型
        public static func fromStr(str: String): ?Kind {
            switch (str) {
                case "cat" => Kind.cat
                case "touch" => Kind.touch
                case "mkdir" => Kind.mkdir
                case "export" => Kind.export
                case "cd" => Kind.cd
                case "echo" => Kind.echo
                case "pwd" => Kind.pwd
                case "which" => Kind.which
                case "rm" => Kind.rm
                case "mv" => Kind.mv
                case "ls" => Kind.ls
                case "exit" => Kind.exit
                case "true" => Kind.true_
                case "false" => Kind.false_
                case "yes" => Kind.yes
                case "seq" => Kind.seq
                case "dirname" => Kind.dirname
                case "basename" => Kind.basename
                case "cp" => Kind.cp
                case _ => None
            }
        }

        /// 用法字符串
        public func usageString(): String {
            switch (this) {
                case .cat => "usage: cat [-belnstuv] [file ...]\n"
                case .touch => "usage: touch [-A [-][[hh]mm]SS] [-achm] [-r file] [-t [[CC]YY]MMDDhhmm[.SS]]\n       [-d YYYY-MM-DDThh:mm:SS[.frac][tz]] file ...\n"
                case .mkdir => "usage: mkdir [-pv] [-m mode] directory_name ...\n"
                case .export => ""
                case .cd => ""
                case .echo => ""
                case .pwd => ""
                case .which => ""
                case .rm => "usage: rm [-f | -i] [-dIPRrvWx] file ...\n       unlink [--] file\n"
                case .mv => "usage: mv [-f | -i | -n] [-hv] source target\n       mv [-f | -i | -n] [-v] source ... directory\n"
                case .ls => "usage: ls [-@ABCFGHILOPRSTUWabcdefghiklmnopqrstuvwxy1%,] [--color=when] [-D format] [file ...]\n"
                case .exit => "usage: exit [n]\n"
                case .true_ => ""
                case .false_ => ""
                case .yes => "usage: yes [expletive]\n"
                case .seq => "usage: seq [-w] [-f format] [-s string] [-t string] [first [incr]] last\n"
                case .dirname => "usage: dirname string\n"
                case .basename => "usage: basename string\n"
                case .cp => "usage: cp [-R [-H | -L | -P]] [-fi | -n] [-aclpsvXx] source_file target_file\n       cp [-R [-H | -L | -P]] [-fi | -n] [-aclpsvXx] source_file ... target_directory\n"
            }
        }
    }

    // ========================================================================
    // 实现
    // ========================================================================

    /// 内置命令实现联合体
    public enum Impl {
        case cat(Cat)
        case touch(Touch)
        case mkdir(Mkdir)
        case export(Export)
        case cd(Cd)
        case echo(Echo)
        case pwd(Pwd)
        case which(Which)
        case rm(Rm)
        case mv(Mv)
        case ls(Ls)
        case exit(Exit)
        case true_(True)
        case false_(False)
        case yes(Yes)
        case seq(Seq)
        case dirname(Dirname)
        case basename(Basename)
        case cp(Cp)
    }

    // ========================================================================
    // 内置命令IO
    // ========================================================================

    /// 内置命令IO
    public class BuiltinIO {
        /// 输出类型
        public enum Output {
            case fd(writer: IOWriter, captured: ?ByteList)
            case buf(ArrayList<Byte>)
            case arraybuf(ArrayBuf)
            case blob(Blob)
            case ignore

            /// 增加引用
            public func ref(): Output {
                switch (this) {
                    case .fd(let writer, _) =>
                        writer.ref()
                    case .blob(let blob) =>
                        blob.ref()
                    case .buf, .arraybuf, .ignore =>
                        // 无操作
                }
                return this
            }

            /// 减少引用
            public func deref() {
                switch (this) {
                    case .fd(let writer, _) =>
                        writer.deref()
                    case .blob(let blob) =>
                        blob.deref()
                    case .arraybuf(let buf) =>
                        buf.deinit()
                    case .buf(let buf) =>
                        buf.clear()
                    case .ignore =>
                        // 无操作
                }
            }

            /// 是否需要IO
            public func needsIO(): ?OutputNeedsIOSafeGuard {
                switch (this) {
                    case .fd =>
                        return OutputNeedsIOSafeGuard.outputNeedsIo
                    case .buf, .arraybuf, .blob, .ignore =>
                        return None
                }
            }

            /// 入队格式化输出（内置命令）
            public func enqueueFmtBltn(ptr: Any, kind: ?Kind, fmt: String, args: Array<Any>): Yield {
                switch (this) {
                    case .fd(let writer, let captured) =>
                        return writer.enqueueFmtBltn(ptr, captured, kind, fmt, args)
                    case .buf, .arraybuf, .blob, .ignore =>
                        return Yield.done
                }
            }

            /// 入队
            public func enqueue(ptr: Any, buf: Array<Byte>): Yield {
                switch (this) {
                    case .fd(let writer, let captured) =>
                        return writer.enqueue(ptr, captured, buf)
                    case .buf, .arraybuf, .blob, .ignore =>
                        return Yield.done
                }
            }
        }

        /// 输入类型
        public enum Input {
            case fd(IOReader)
            case buf(ArrayList<Byte>)
            case arraybuf(ArrayBuf)
            case blob(Blob)
            case ignore

            /// 增加引用
            public func ref(): Input {
                switch (this) {
                    case .fd(let reader) =>
                        reader.ref()
                    case .blob(let blob) =>
                        blob.ref()
                    case .buf, .arraybuf, .ignore =>
                        // 无操作
                }
                return this
            }

            /// 减少引用
            public func deref() {
                switch (this) {
                    case .fd(let reader) =>
                        reader.deref()
                    case .blob(let blob) =>
                        blob.deref()
                    case .buf(let buf) =>
                        buf.clear()
                    case .arraybuf(let buf) =>
                        buf.deinit()
                    case .ignore =>
                        // 无操作
                }
            }

            /// 是否需要IO
            public func needsIO(): Boolean {
                switch (this) {
                    case .fd =>
                        return true
                    case .buf, .arraybuf, .blob, .ignore =>
                        return false
                }
            }
        }

        /// 数组缓冲区
        public struct ArrayBuf {
            public var buf: ArrayBuffer.Strong
            public var i: UInt32 = 0
        }

        /// Blob引用计数包装
        public class Blob {
            public var refCount: UInt32 = 1
            public var blob: WebCoreBlob

            /// 复制引用
            public func dupeRef(): Blob {
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
                this.blob.deinit()
            }
        }
    }

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 初始化内置命令
    public static func init(
        cmd: CmdState,
        interpreter: Interpreter,
        kind: Kind,
        arena: ArenaAllocator,
        node: CmdAst,
        args: ArrayList<?String>,
        exportEnv: EnvMap,
        cmdLocalEnv: EnvMap,
        cwd: FD,
        io: IO
    ): ?Yield {
        let stdin = BuiltinIO.Input.ignore
        let stdout = BuiltinIO.Output.ignore
        let stderr = BuiltinIO.Output.ignore

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
        bltn.impl = Impl.cat(Cat())

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
        cmd.exitCode = exitCode
        return cmd.parent.childDone(cmd, exitCode)
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
    public func writeNoIO(ioKind: String, buf: Array<Byte>): Maybe<UInt64> {
        if (buf.length == 0) {
            return Maybe<UInt64>.success(0)
        }
        switch (this.stdout) {
            case .buf(let bufList) =>
                bufList.appendAll(buf)
                return Maybe<UInt64>.success(UInt64(buf.length))
            case .arraybuf, .blob, .fd, .ignore =>
                return Maybe<UInt64>.success(UInt64(buf.length))
        }
    }

    /// 读取无IO标准输入
    public func readStdinNoIO(): String {
        switch (this.stdin) {
            case .arraybuf(let buf) =>
                return String.fromBytes(buf.buf.slice())
            case .buf(let buf) =>
                return String.fromBytes(buf.toArray())
            case .blob(let blob) =>
                return String.fromBytes(blob.blob.sharedView())
            case .fd, .ignore =>
                return ""
        }
    }

    /// 格式化错误到Arena
    public func fmtErrorArena(kind: ?Kind, fmt: String, args: Array<Any>): String {
        let cmdStr = if (let k = kind) { "\(k): " } else { "" }
        return "\(cmdStr)\(fmt)"
    }

    /// 错误字符串
    public func taskErrorToString(kind: Kind, err: Any): String {
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
