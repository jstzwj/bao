// ls.cj - ls命令
// 对应 Bun: src/runtime/shell/builtin/ls.zig
// 严格翻译Bun shell ls命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*
import bao_runtime.shell.*

// ============================================================================
// ls命令 - 列出目录内容
// 支持多路径，使用线程池并发执行
// ============================================================================

/// ls命令
public enum LsState {
    | idle
    | exec(ExecState)
    | waitingWriteErr
    | done
}

public struct ExecState {
    public var err: ?SyscallError = None
    public var taskCount: AtomicUIntPtr = AtomicUIntPtr()
    public var tasksDone: UIntPtr = 0
    public var outputWaiting: UIntPtr = 0
    public var outputDone: UIntPtr = 0
}

public enum ResultKind {
    | file
    | dir
    | idk
}

public class LsCmd {
    /// 选项
    public var opts: LsOpts = LsOpts()
    /// 状态
    public var state: LsState = LsState.idle
    /// 分配作用域
    public var allocScope: AllocScope = AllocScope()

    /// 状态类型


    /// 执行状态
    /// 对应 Bun: exec struct in Ls state


    /// 启动
    public func start(): Yield {
        return this.next()
    }

    /// 写入失败错误
    public func writeFailingError(s: String, exitCode: ExitCode): Yield {
        if (let Some(safeguard) <- this.bltn().stderr.needsIO()) {
            this.state = LsState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(OutKind.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// 下一步
    func next(): Yield {
        while (this.state != CheckTargetInnerState.done) {
            match (this.state) {
                case idle => ()
                    // 解析选项
                    let paths = match (this.parseOpts()) {
                        case ok(p) => p
                        case err(e) =>
                            let buf = match (e) {
                                case illegalOption(optStr) =>
                                    this.bltn().fmtErrorArena("ls", "illegal option -- ${optStr}\n", [])
                                case showUsage =>
                                    Builtin.Kind.usageString("ls")
                            }
                            return this.writeFailingError(buf, 1)
                    }

                    let taskCount = if (let Some(p) <- paths) { p.size } else { 1 }

                    this.state = LsState.exec(ExecState())
                    // 注意: 实际的任务调度需要线程池支持

                case LsState.exec(exec) => ()
                    // 检查是否完成
                    if (exec.tasksDone >= exec.taskCount.load() && exec.outputDone >= exec.outputWaiting) {
                        let exitCode: ExitCode = if (exec.err != None) { 1 } else { 0 }
                        this.state = LsState.done
                        return this.bltn().done(exitCode)
                    }
                    return Yield.suspended

                case waitingWriteErr =>
                    return Yield.failed

                case done =>
                    panic("不可达状态")
            }
        }

        return this.bltn().done(0)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(chunk: UInt64, e: ?SystemError): Yield {
        if (let Some(err) <- e) {
            err.deref()
        }
        if (this.state == LsState.waitingWriteErr) {
            return this.bltn().done(1)
        }
        if (let Some(exec) <- this.state.getExec()) {
            // exec.outputDone++
        }
        return this.next()
    }

    /// Shell ls任务完成回调
    public func onShellLsTaskDone(task: ShellLsTask): Unit {
        // 增加tasksDone并处理输出
    }

    /// 去初始化
    public func deinit() {
        this.allocScope.endScope()
    }

    /// 解析选项
    func parseOpts(): LsParseResult {
        return this.parseFlags()
    }

    /// 解析标志
    func parseFlags(): LsParseResult {
        let args = this.bltn().argsSlice()
        if (args.size == 0) {
            return LsParseResult.ok(None)
        }

        var idx: UInt32 = 0
        while (idx < args.size) {
            let flag = args[idx]
            match (this.parseFlag(flag)) {
                case FlagParseResult.done =>
                    return LsParseResult.ok(args[idx..])
                case FlagParseResult.continueParsing =>
                    idx++
                case FlagParseResult.illegalOption(optStr) =>
                    return LsParseResult.err(LsParseError.illegalOption(optStr))
            }
            idx++
        }

        return LsParseResult.ok(None)
    }

    /// 解析单个标志
    /// 对应 Bun: pub fn parseFlag(*Ls, flag: []const u8)
    func parseFlag(s: String): FlagParseResult {
        if (flag.size == 0) {
            return FlagParseResult.done
        }
        if (flag[0] != '-') {
            return FlagParseResult.done
        }
        if (flag.size == 1) {
            return FlagParseResult.illegalOption("-")
        }

        let smallFlags = flag.substring(1)
        for (c in smallFlags) {
            match (c) {
                case 'a' => this.opts.showAll = true
                case 'A' => this.opts.showAlmostAll = true
                case 'b' => this.opts.escape = true
                case 'B' => this.opts.ignoreBackups = true
                case 'c' => this.opts.useCtime = true
                case 'C' => this.opts.listByColumns = true
                case 'd' => this.opts.listDirectories = true
                case 'D' => this.opts.diredMode = true
                case 'f' => this.opts.unsorted = true
                case 'F' => this.opts.classify = "always"
                case 'g' => this.opts.noOwner = true
                case 'G' => this.opts.noGroup = true
                case 'h' => this.opts.humanReadable = true
                case 'H' => this.opts.dereferenceCmdSymlinks = true
                case 'i' => this.opts.showInode = true
                case 'I' => this.opts.ignorePattern = ""
                case 'k' => this.opts.kibibytes = true
                case 'l' => this.opts.longListing = true
                case 'L' => this.opts.dereference = true
                case 'm' => this.opts.commaSeparated = true
                case 'n' => this.opts.numericUidGid = true
                case 'N' => this.opts.literal = true
                case 'o' => this.opts.noGroupInfo = true
                case 'p' => this.opts.slashIndicator = true
                case 'q' => this.opts.hideControlChars = true
                case 'Q' => this.opts.quoteName = true
                case 'r' => this.opts.reverseOrder = true
                case 'R' => this.opts.recursive = true
                case 's' => this.opts.showSize = true
                case 'S' => this.opts.sortBySize = true
                case 't' => this.opts.sortByTime = true
                case 'T' => this.opts.tabsize = 8
                case 'u' => this.opts.useAtime = true
                case 'U' => this.opts.noSort = true
                case 'v' => this.opts.naturalSort = true
                case 'w' => this.opts.outputWidth = 0
                case 'x' => this.opts.listByLines = true
                case 'X' => this.opts.sortByExtension = true
                case 'Z' => this.opts.showContext = true
                case '1' => this.opts.oneFilePerLine = true
                case _ => return FlagParseResult.illegalOption(flag.substring(1, 2))
            }
        }
        return FlagParseResult.continueParsing
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "ls")
    }
}

/// ls命令选项
/// 对应 Bun: Opts struct in ls.zig
public struct LsOpts {
    /// -a, --all: 显示所有条目（包括以.开头的）
    public var showAll: Bool = false
    /// -A, --almost-all: 显示几乎所有条目（不包括.和..）
    public var showAlmostAll: Bool = false
    /// --author: 配合-l打印文件作者
    public var showAuthor: Bool = false
    /// -b, --escape: 打印C风格转义的非图形字符
    public var escape: Bool = false
    /// --block-size=SIZE: 配合-l按指定大小单位显示
    public var blockSize: ?UIntPtr = None
    /// -B, --ignore-backups: 不列出以~结尾的条目
    public var ignoreBackups: Bool = false
    /// -c: 按ctime排序和显示
    public var useCtime: Bool = false
    /// -C: 按列列出
    public var listByColumns: Bool = false
    /// --color[=WHEN]: 彩色输出
    public var color: ?String = None
    /// -d, --directory: 列出目录本身，而非其内容
    public var listDirectories: Bool = false
    /// -D, --dired: 生成Emacs dired模式输出
    public var diredMode: Bool = false
    /// -f: 不排序
    public var unsorted: Bool = false
    /// -F, --classify[=WHEN]: 追加文件类型指示符
    public var classify: ?String = None
    /// --file-type: 同-F但不追加*
    public var fileType: Bool = false
    /// --format=WORD: 指定格式
    public var format: ?String = None
    /// --full-time: 类似-l --time-style=full-iso
    public var fullTime: Bool = false
    /// -g: 类似-l但不列出所有者
    public var noOwner: Bool = false
    /// --group-directories-first: 目录排在文件前
    public var groupDirectoriesFirst: Bool = false
    /// -G, --no-group: 长列表不打印组名
    public var noGroup: Bool = false
    /// -h, --human-readable: 人类可读的大小
    public var humanReadable: Bool = false
    /// --si: 使用1000而非1024作为单位
    public var siUnits: Bool = false
    /// -H, --dereference-command-line: 跟随命令行符号链接
    public var dereferenceCmdSymlinks: Bool = false
    /// --dereference-command-line-symlink-to-dir: 跟随指向目录的命令行符号链接
    public var dereferenceCmdDirSymlinks: Bool = false
    /// --hide=PATTERN: 不列出匹配Shell模式的条目
    public var hidePattern: ?String = None
    /// --hyperlink[=WHEN]: 超链接文件名
    public var hyperlink: ?String = None
    /// --indicator-style=WORD: 追加指定风格的指示符
    public var indicatorStyle: ?String = None
    /// -i, --inode: 显示inode号
    public var showInode: Bool = false
    /// -I, --ignore=PATTERN: 不列出匹配Shell模式的条目
    public var ignorePattern: ?String = None
    /// -k, --kibibytes: 默认使用1024字节块
    public var kibibytes: Bool = false
    /// -l: 使用长列表格式
    public var longListing: Bool = false
    /// -L, --dereference: 显示符号链接引用的文件信息
    public var dereference: Bool = false
    /// -m: 逗号分隔列表
    public var commaSeparated: Bool = false
    /// -n, --numeric-uid-gid: 显示数字UID/GID
    public var numericUidGid: Bool = false
    /// -N, --literal: 不加引号打印条目名
    public var literal: Bool = false
    /// -o: 类似-l但不列出组信息
    public var noGroupInfo: Bool = false
    /// -p, --indicator-style=slash: 目录追加/指示符
    public var slashIndicator: Bool = false
    /// -q, --hide-control-chars: 用?替代非图形字符
    public var hideControlChars: Bool = false
    /// --show-control-chars: 原样显示非图形字符
    public var showControlChars: Bool = false
    /// -Q, --quote-name: 用双引号括起条目名
    public var quoteName: Bool = false
    /// --quoting-style=WORD: 使用指定引用风格
    public var quotingStyle: ?String = None
    /// -r, --reverse: 反转排序顺序
    public var reverseOrder: Bool = false
    /// -R, --recursive: 递归列出子目录
    public var recursive: Bool = false
    /// -s, --size: 显示每个文件的分配大小
    public var showSize: Bool = false
    /// -S: 按文件大小排序（最大的在前）
    public var sortBySize: Bool = false
    /// --sort=WORD: 按指定属性排序
    public var sortMethod: ?String = None
    /// --time=WORD: 选择用于显示或排序的时间戳
    public var timeMethod: ?String = None
    /// --time-style=TIME_STYLE: 配合-l的时间/日期格式
    public var timeStyle: ?String = None
    /// -t: 按时间排序（最新的在前）
    public var sortByTime: Bool = false
    /// -T, --tabsize=COLS: 设置制表符宽度
    public var tabsize: ?UIntPtr = None
    /// -u: 按访问时间排序和显示
    public var useAtime: Bool = false
    /// -U: 不排序，按目录顺序列出
    public var noSort: Bool = false
    /// -v: 文本中数字的自然排序
    public var naturalSort: Bool = false
    /// -w, --width=COLS: 设置输出宽度
    public var outputWidth: ?UIntPtr = None
    /// -x: 按行列出而非按列
    public var listByLines: Bool = false
    /// -X: 按扩展名字母排序
    public var sortByExtension: Bool = false
    /// -Z, --context: 打印安全上下文
    public var showContext: Bool = false
    /// --zero: 用NUL而非换行结束每行
    public var endWithNul: Bool = false
    /// -1: 每行一个文件
    public var oneFilePerLine: Bool = false
    /// --help: 显示帮助
    public var showHelp: Bool = false
    /// --version: 显示版本信息
    public var showVersion: Bool = false
}

/// ls解析结果
public enum LsParseResult {
    | ok(?Array<String>)
    | err(LsParseError)
}

/// ls解析错误
public enum LsParseError {
    | illegalOption(String)
    | showUsage
}

/// Shell ls任务（线程池任务）
/// 对应 Bun: ShellLsTask in ls.zig
public class ShellLsTask {
    /// 父ls命令
    public var ls: LsCmd
    /// 选项
    public var opts: LsOpts
    /// 任务计数引用
    public var taskCount: AtomicUIntPtr = AtomicUIntPtr()
    /// 当前工作目录fd
    public var cwd: FD
    /// 当前路径
    public var path: String = ""
    /// 输出缓冲区
    public var output: ArrayList<Byte> = ArrayList<Byte>()
    /// 错误
    public var err: ?SyscallError = None
    /// 是否打印目录名
    public var printDirectory: Bool = false
    /// 是否为绝对路径
    public var isAbsolute: Bool = false
    /// 是否拥有字符串
    public var ownedString: Bool = false
    /// 结果类型
    public var resultKind: ResultKind = ResultKind.idk

    /// 结果类型枚举
    /// 对应 Bun: enum { file, dir, idk }


    /// 调度到线程池
    public func schedule() {
        // 排队到线程池
    }

    /// 从线程池运行
    public func run() {
        // 打开目录并遍历条目
    }

    /// 获取输出并重置
    public func takeOutput(): ArrayList<Byte> {
        let ret = this.output
        this.output = ArrayList<Byte>()
        return ret
    }

    /// 去初始化
    public func deinit() {
        this.output.clear()
    }

    /// 判断是否应跳过条目
    /// 对应 Bun: fn shouldSkipEntry(*@This(), name: [:0]const u8) bool
    public func shouldSkipEntry(s: String): Bool {
        if (this.opts.showAll) {
            return false
        }
        if (this.opts.showAlmostAll) {
            if (name == "." || name == "..") {
                return true
            }
        } else {
            if (name.startsWith(".")) {
                return true
            }
        }
        return false
    }

    /// 添加条目
    /// 对应 Bun: fn addEntry(*@This(), name: [:0]const u8, dir_fd: bun.FD) void
    public func addEntry(s: String, dirFd: FD) {
        if (this.shouldSkipEntry(name)) {
            return
        }
        if (this.opts.longListing) {
            this.addEntryLong(name, dirFd)
        } else {
            this.output.appendAll(name.toByteArray())
            this.output.append('\n'.toByte())
        }
    }

    /// 添加长列表格式条目
    /// 对应 Bun: fn addEntryLong(*@This(), name: [:0]const u8, dir_fd: bun.FD) void
    public func addEntryLong(s: String, dirFd: FD) {
        // 使用lstatat获取文件信息（不跟随符号链接）
        let statResult = Syscall.lstatat(dirFd, name)
        match (statResult) {
            case err => ()
                // stat失败时输出占位符
                this.output.appendAll("?????????? ? ? ? ?            ? ".toByteArray())
                this.output.appendAll(name.toByteArray())
                this.output.append('\n'.toByte())
                return
            case result(stat) =>
                let mode: UInt32 = stat.mode
                let fileTypeChar = ShellLsTask.getFileTypeChar(mode)
                let perms = ShellLsTask.formatPermissions(mode)
                let nlink: UInt64 = stat.nlink
                let uid: UInt64 = stat.uid
                let gid: UInt64 = stat.gid
                let size: Int64 = stat.size
                let mtime = stat.mtime()
                let timeStr = ShellLsTask.formatTime(mtime.sec)
                this.output.append(fileTypeChar.toByte())
                this.output.appendAll(perms.toByteArray())
                this.output.append(' '.toByte())
                this.output.appendAll(nlink.toString().toByteArray())
                this.output.append(' '.toByte())
                this.output.appendAll(uid.toString().toByteArray())
                this.output.append(' '.toByte())
                this.output.appendAll(gid.toString().toByteArray())
                this.output.append(' '.toByte())
                this.output.appendAll(size.toString().toByteArray())
                this.output.append(' '.toByte())
                this.output.appendAll(timeStr.toByteArray())
                this.output.append(' '.toByte())
                this.output.appendAll(name.toByteArray())
                this.output.append('\n'.toByte())
        }
    }

    /// 获取文件类型字符
    /// 对应 Bun: fn getFileTypeChar(u32) u8
    public static func getFileTypeChar(n: UInt32): Char {
        let fileType = mode & S.IFMT
        if (fileType == S.IFDIR) {
            return 'd'
        } else if (fileType == S.IFLNK) {
            return 'l'
        } else if (fileType == S.IFBLK) {
            return 'b'
        } else if (fileType == S.IFCHR) {
            return 'c'
        } else if (fileType == S.IFIFO) {
            return 'p'
        } else if (fileType == S.IFSOCK) {
            return 's'
        }
        return '-' // IFREG or unknown
    }

    /// 格式化权限字符串
    /// 对应 Bun: fn formatPermissions(u32) [9]u8
    public static func formatPermissions(n: UInt32): String {
        var perms = StringBuilder()
        // Owner permissions
        perms.append(if ((mode & S.IRUSR) != 0) 'r' else '-')
        perms.append(if ((mode & S.IWUSR) != 0) 'w' else '-')
        let ownerExec = (mode & S.IXUSR) != 0
        let setuid = (mode & S.ISUID) != 0
        perms.append(if (setuid) { if (ownerExec) 's' else 'S' } else { if (ownerExec) 'x' else '-' })
        // Group permissions
        perms.append(if ((mode & S.IRGRP) != 0) 'r' else '-')
        perms.append(if ((mode & S.IWGRP) != 0) 'w' else '-')
        let groupExec = (mode & S.IXGRP) != 0
        let setgid = (mode & S.ISGID) != 0
        perms.append(if (setgid) { if (groupExec) 's' else 'S' } else { if (groupExec) 'x' else '-' })
        // Other permissions
        perms.append(if ((mode & S.IROTH) != 0) 'r' else '-')
        perms.append(if ((mode & S.IWOTH) != 0) 'w' else '-')
        let otherExec = (mode & S.IXOTH) != 0
        let sticky = (mode & S.ISVTX) != 0
        perms.append(if (sticky) { if (otherExec) 't' else 'T' } else { if (otherExec) 'x' else '-' })
        return perms.toString()
    }

    /// 格式化时间戳
    /// 对应 Bun: fn formatTime(i64, now_secs: u64) [12]u8
    public static func formatTime(n: Int64): String {
        // 简化实现 - 返回基本的时间格式
        if (timestamp < 0) {
            return "??? ?? ??:??"
        }
        let epochSecs: UInt64 = UInt64(timestamp)
        // 返回格式化的时间字符串 "Mon DD HH:MM" 或 "Mon DD  YYYY"
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        // 简化: 使用基本时间计算
        let daysSinceEpoch = epochSecs / 86400
        let remSecs = epochSecs % 86400
        let hours = remSecs / 3600
        let minutes = (remSecs % 3600) / 60
        // 近似计算月和日
        let year = 1970 + Int64(daysSinceEpoch / 365)
        let dayOfYear = Int64(daysSinceEpoch % 365)
        let monthIdx = if (dayOfYear / 30 > 11) { 11 } else { Int64 }(dayOfYear / 30)
        let day = dayOfYear % 30 + 1
        return "${months[Int64(monthIdx)]} ${String.formatInt(day, minWidth: 2)} ${String.formatInt(Int64(hours), minWidth: 2)}:${String.formatInt(Int64(minutes), minWidth: 2)}"
    }
}
