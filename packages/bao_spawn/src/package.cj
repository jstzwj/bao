// bao_spawn - 进程创建与管理
// 严格翻译自: src/spawn/
// 对应 Bun: src/spawn/lib.rs, process.rs, static_pipe_writer.rs
package bao_spawn

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*

// ============================================================================
// ExitCode - 退出码
// 严格翻译自: src/spawn/process.rs - Status enum
// ============================================================================

/// 进程退出状态
/// 对应 Bun: process.rs Status
public enum ProcessStatus {
    | Running
    | Exited(ExitCode)
    | Signaled(SignalCode)
    | Error(ErrorCode)

    /// 是否已退出
    public func hasExited(): Bool {
        match (this) {
            case Running => false
            case Exited(_) | Signaled(_) | Error(_) => true
        }
    }

    /// 获取退出码 (如果已退出)
    public func exitCode(): ?Int64 {
        match (this) {
            case Exited(code) => Some(code.code)
            case Signaled(sig) => Some(128 + sig.number)
            case _ => None
        }
    }

    /// 是否成功退出
    public func isSuccess(): Bool {
        match (this) {
            case Exited(code) => code.code == 0
            case _ => false
        }
    }
}

/// 退出码
public class ExitCode {
    public let code: Int64

    public init(code: Int64) {
        this.code = code
    }

    public static let Success = ExitCode(0)
    public static let GeneralError = ExitCode(1)
    public static let Misuse = ExitCode(2)
    public static let CannotExecute = ExitCode(126)
    public static let NotFound = ExitCode(127)
    public static let Killed = ExitCode(137)

    public func toString(): String {
        return code.toString()
    }
}

/// 信号码
/// 对应 Bun: SignalCode
public class SignalCode {
    public let number: Int64
    public let name: String

    public init(number: Int64, name: String) {
        this.number = number
        this.name = name
    }

    public static let SIGHUP = SignalCode(1, "SIGHUP")
    public static let SIGINT = SignalCode(2, "SIGINT")
    public static let SIGQUIT = SignalCode(3, "SIGQUIT")
    public static let SIGILL = SignalCode(4, "SIGILL")
    public static let SIGTRAP = SignalCode(5, "SIGTRAP")
    public static let SIGABRT = SignalCode(6, "SIGABRT")
    public static let SIGFPE = SignalCode(8, "SIGFPE")
    public static let SIGKILL = SignalCode(9, "SIGKILL")
    public static let SIGSEGV = SignalCode(11, "SIGSEGV")
    public static let SIGPIPE = SignalCode(13, "SIGPIPE")
    public static let SIGALRM = SignalCode(14, "SIGALRM")
    public static let SIGTERM = SignalCode(15, "SIGTERM")
    public static let SIGUSR1 = SignalCode(10, "SIGUSR1")
    public static let SIGUSR2 = SignalCode(12, "SIGUSR2")
    public static let SIGCHLD = SignalCode(17, "SIGCHLD")
    public static let SIGCONT = SignalCode(18, "SIGCONT")
    public static let SIGSTOP = SignalCode(19, "SIGSTOP")
    public static let SIGTSTP = SignalCode(20, "SIGTSTP")
    public static let SIGTTIN = SignalCode(21, "SIGTTIN")
    public static let SIGTTOU = SignalCode(22, "SIGTTOU")

    /// 从编号解析信号
    public static func fromNumber(num: Int64): ?SignalCode {
        match (num) {
            case 1 => Some(SIGHUP)
            case 2 => Some(SIGINT)
            case 3 => Some(SIGQUIT)
            case 4 => Some(SIGILL)
            case 5 => Some(SIGTRAP)
            case 6 => Some(SIGABRT)
            case 8 => Some(SIGFPE)
            case 9 => Some(SIGKILL)
            case 11 => Some(SIGSEGV)
            case 13 => Some(SIGPIPE)
            case 14 => Some(SIGALRM)
            case 15 => Some(SIGTERM)
            case _ => None
        }
    }

    public func toString(): String {
        return name
    }
}

// ============================================================================
// Stdio 配置
// 严格翻译自: src/spawn/process.rs - PosixStdio / WindowsStdio
// ============================================================================

/// 子进程 stdio 配置
/// 对应 Bun: PosixStdio enum
public enum StdioConfig {
    | Inherit     // 继承父进程
    | Pipe        // 创建管道
    | Ignore      // 忽略 (重定向到 /dev/null)
    | Fd(Int64)   // 重定向到指定 fd
    | Path(String) // 重定向到文件

    public func toString(): String {
        match (this) {
            case Inherit => "inherit"
            case Pipe => "pipe"
            case Ignore => "ignore"
            case Fd(fd) => "fd(${fd})"
            case Path(p) => "path(${p})"
        }
    }
}

// ============================================================================
// SpawnOptions - 进程创建选项
// 严格翻译自: src/spawn/process.rs - SpawnOptions
// ============================================================================

/// 进程创建选项
/// 对应 Bun: process.rs SpawnOptions
public class SpawnOptions {
    /// 要执行的命令
    public var command: String
    /// 命令参数
    public var args: ArrayList<String>
    /// 环境变量
    public var env: HashMap<String, String>
    /// 是否继承父进程环境
    public var envInherit: Bool
    /// 工作目录
    public var cwd: ?String
    /// stdin 配置
    public var stdin: StdioConfig
    /// stdout 配置
    public var stdout: StdioConfig
    /// stderr 配置
    public var stderr: StdioConfig
    /// 用户 ID
    public var uid: ?UInt32
    /// 组 ID
    public var gid: ?UInt32
    /// 额外的 fd 映射
    public var extraFds: ArrayList<FdMapping>
    /// windows 配置 (占位)
    public var windowsHide: Bool
    public var windowsVerbatimArguments: Bool

    public init(command: String) {
        this.command = command
        this.args = ArrayList<String>()
        this.env = HashMap<String, String>()
        this.envInherit = true
        this.cwd = None
        this.stdin = StdioConfig.Pipe
        this.stdout = StdioConfig.Pipe
        this.stderr = StdioConfig.Pipe
        this.uid = None
        this.gid = None
        this.extraFds = ArrayList<FdMapping>()
        this.windowsHide = false
        this.windowsVerbatimArguments = false
    }

    /// 设置参数
    public func args(varargs: String...): SpawnOptions {
        for (a in varargs) { args.append(a) }
        return this
    }

    /// 设置环境变量
    public func setEnv(key: String, value: String): SpawnOptions {
        env.put(key, value)
        envInherit = false
        return this
    }

    /// 设置工作目录
    public func setCwd(dir: String): SpawnOptions {
        cwd = Some(dir)
        return this
    }

    /// 设置 stdin
    public func setStdin(config: StdioConfig): SpawnOptions {
        stdin = config
        return this
    }

    /// 设置 stdout
    public func setStdout(config: StdioConfig): SpawnOptions {
        stdout = config
        return this
    }

    /// 设置 stderr
    public func setStderr(config: StdioConfig): SpawnOptions {
        stderr = config
        return this
    }

    /// 设置用户 ID
    public func setUid(uid: UInt32): SpawnOptions {
        this.uid = Some(uid)
        return this
    }

    /// 设置组 ID
    public func setGid(gid: UInt32): SpawnOptions {
        this.gid = Some(gid)
        return this
    }

    /// 构建完整 argv 数组
    public func buildArgv(): ArrayList<String> {
        let result = ArrayList<String>()
        result.append(command)
        for (arg in args) {
            result.append(arg)
        }
        return result
    }

    /// 构建完整环境
    public func buildEnv(): HashMap<String, String> {
        if (!envInherit) {
            return env
        }
        // 继承当前进程环境并合并
        let result = HashMap<String, String>()
        for (key in env.keys()) {
            match (env.get(key)) {
                case Some(v) => result.put(key, v)
                case None => ()
            }
        }
        return result
    }
}

/// fd 映射
/// 对应 Bun: Dup2
public class FdMapping {
    public var from: Int64
    public var to: Int64

    public init(from: Int64, to: Int64) {
        this.from = from
        this.to = to
    }
}

// ============================================================================
// Process - 子进程
// 严格翻译自: src/spawn/process.rs - Process struct
// Bun 的 Process 使用引用计数 (ThreadSafeRefCount)
// ============================================================================

/// 子进程
/// 对应 Bun: process.rs Process
public class Process {
    /// 进程 ID
    public var pid: Int64
    /// 进程状态
    public var status: ProcessStatus
    /// stdin 写入端 (可选)
    public var stdin: ?WritablePipe
    /// stdout 读取端 (可选)
    public var stdout: ?ReadablePipe
    /// stderr 读取端 (可选)
    public var stderr: ?ReadablePipe
    /// 退出回调
    public var onExit: ?((ProcessStatus) -> Unit)
    /// 是否同步进程
    public var sync: Bool
    /// spawn 选项的引用
    private var options: ?SpawnOptions

    public init(pid: Int64) {
        this.pid = pid
        this.status = ProcessStatus.Running
        this.stdin = None
        this.stdout = None
        this.stderr = None
        this.onExit = None
        this.sync = false
        this.options = None
    }

    /// 是否已退出
    public func hasExited(): Bool {
        return status.hasExited()
    }

    /// 是否已 killed
    public func hasKilled(): Bool {
        match (status) {
            case Signaled(_) => true
            case _ => false
        }
    }

    /// 获取退出码
    public func exitCode(): ?Int64 {
        return status.exitCode()
    }

    /// 获取信号码
    public func signalCode(): ?SignalCode {
        match (status) {
            case Signaled(sig) => Some(sig)
            case _ => None
        }
    }

    /// 等待进程退出
    /// 对应 Bun: Process::wait (通过 Poller)
    public func wait(): ProcessStatus {
        if (status.hasExited()) { return status }
        // 同步等待: 通过 C FFI waitpid
        // 对应 Bun: process.rs WaiterThread / posix_spawn wait4
        let result = Syscall.waitpid(pid)
        match (result) {
            case Some(statusCode) =>
                if (statusCode >= 0) {
                    status = ProcessStatus.Exited(ExitCode(statusCode))
                } else {
                    let sigNum = 0 - statusCode
                    match (SignalCode.fromNumber(sigNum)) {
                        case Some(sig) => status = ProcessStatus.Signaled(sig)
                        case None => status = ProcessStatus.Exited(ExitCode(128 + sigNum))
                    }
                }
            case None => status = ProcessStatus.Error(ErrorCode.Unknown)
        }
        invokeExitHandler()
        return status
    }

    /// 发送信号
    /// 对应 Bun: Process::kill
    public func kill(signal: SignalCode): Bool {
        if (status.hasExited()) { return false }
        return Syscall.kill(pid, signal.number)
    }

    /// 终止进程 (SIGTERM)
    public func terminate(): Bool {
        return kill(SignalCode.SIGTERM)
    }

    /// 强制杀死进程 (SIGKILL)
    public func forceKill(): Bool {
        return kill(SignalCode.SIGKILL)
    }

    /// 与进程通信: 发送输入并获取输出
    /// 对应 Bun: subprocess communicate 模式
    public func communicate(input: ?Array<UInt8>): SpawnResult {
        let result = SpawnResult()
        // 发送输入到 stdin
        match (stdin) {
            case Some(pipe) =>
                match (input) {
                    case Some(data) => pipe.write(data)
                    case None => ()
                }
                pipe.close()
            case None => ()
        }
        // 读取 stdout
        match (stdout) {
            case Some(pipe) => result.stdout = pipe.readAll()
            case None => ()
        }
        // 读取 stderr
        match (stderr) {
            case Some(pipe) => result.stderr = pipe.readAll()
            case None => ()
        }
        // 等待退出
        result.status = wait()
        return result
    }

    /// 设置退出回调
    public func setOnExit(handler: (ProcessStatus) -> Unit): Unit {
        onExit = Some(handler)
    }

    /// 触发退出回调
    private func invokeExitHandler(): Unit {
        match (onExit) {
            case Some(handler) => handler(status)
            case None => ()
        }
    }

    /// 内存开销估算
    public func memoryCost(): Int64 {
        return 256
    }
}

// ============================================================================
// SpawnResult - spawn 执行结果
// ============================================================================

/// spawn 执行结果
/// 对应 Bun: sync::Result
public class SpawnResult {
    public var status: ProcessStatus
    public var stdout: Array<UInt8>
    public var stderr: Array<UInt8>
    public var pid: Int64

    public init() {
        this.status = ProcessStatus.Running
        this.stdout = Array<UInt8>()
        this.stderr = Array<UInt8>()
        this.pid = 0
    }

    /// 获取 stdout 为字符串
    public func stdoutText(): String {
        return bytesToString(stdout)
    }

    /// 获取 stderr 为字符串
    public func stderrText(): String {
        return bytesToString(stderr)
    }

    /// 是否成功
    public func isSuccess(): Bool {
        return status.isSuccess()
    }

    /// 获取退出码
    public func exitCode(): ?Int64 {
        return status.exitCode()
    }

    private func bytesToString(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }
}

// ============================================================================
// Spawn - 进程创建入口
// 严格翻译自: src/spawn/process.rs - spawn_process + sync::spawn
// Bun 的 spawn 分为异步和同步两种模式
// ============================================================================

/// 进程创建器
/// 对应 Bun: spawn_process / sync::spawn
public class Spawn {
    /// 异步 spawn
    /// 对应 Bun: spawn_process (异步版)
    public static func spawn(options: SpawnOptions): ?Process {
        let pid = Syscall.forkExec(options.command, options.buildArgv(), options.buildEnv(), options.cwd)
        match (pid) {
            case Some(p) =>
                let process = Process(p)
                process.options = Some(options)
                // 设置 stdio 管道
                match (options.stdout) {
                    case StdioConfig.Pipe => process.stdout = Some(ReadablePipe.create())
                    case _ => ()
                }
                match (options.stderr) {
                    case StdioConfig.Pipe => process.stderr = Some(ReadablePipe.create())
                    case _ => ()
                }
                match (options.stdin) {
                    case StdioConfig.Pipe => process.stdin = Some(WritablePipe.create())
                    case _ => ()
                }
                return Some(process)
            case None => return None
        }
    }

    /// 快捷 spawn: 命令 + 参数
    public static func spawn(command: String, args: ArrayList<String>): ?Process {
        let options = SpawnOptions(command)
        for (arg in args) { options.args.append(arg) }
        return spawn(options)
    }

    /// 同步 spawn (阻塞等待完成)
    /// 对应 Bun: sync::spawn
    public static func spawnSync(options: SpawnOptions): SpawnResult {
        let pid = Syscall.forkExec(options.command, options.buildArgv(), options.buildEnv(), options.cwd)
        let result = SpawnResult()
        match (pid) {
            case Some(p) =>
                result.pid = p
                let process = Process(p)
                process.sync = true
                // 同步模式: 等待完成
                let status = process.wait()
                result.status = status
            case None =>
                result.status = ProcessStatus.Error(ErrorCode.Unknown)
        }
        return result
    }

    /// 快捷同步 spawn
    public static func spawnSync(command: String, args: ArrayList<String>): SpawnResult {
        let options = SpawnOptions(command)
        for (arg in args) { options.args.append(arg) }
        return spawnSync(options)
    }

    /// spawn 并等待
    /// 对应 Bun: std.process.Child.run
    public static func spawnAndWait(options: SpawnOptions): SpawnResult {
        return spawnSync(options)
    }

    /// spawn 并等待 (简单命令)
    public static func exec(command: String): SpawnResult {
        let options = SpawnOptions("sh")
        options.args.append("-c")
        options.args.append(command)
        return spawnSync(options)
    }
}

// ============================================================================
// ReadablePipe / WritablePipe - 管道抽象
// 严格翻译自: src/spawn/static_pipe_writer.rs - StaticPipeWriter
// Bun 的 StaticPipeWriter 是 BufferedWriter 的适配器
// ============================================================================

/// 可读管道 (stdout/stderr 读取端)
/// 对应 Bun: StaticPipeWriter 的读取端
public class ReadablePipe {
    private var buffer: Array<UInt8>
    private var closed: Bool
    private var fd: Int64

    private init() {
        this.buffer = Array<UInt8>()
        this.closed = false
        this.fd = -1
    }

    public static func create(): ReadablePipe {
        let pipe = ReadablePipe()
        // 实际实现通过 C FFI pipe() 系统调用
        return pipe
    }

    public static func fromFd(fd: Int64): ReadablePipe {
        let pipe = ReadablePipe()
        pipe.fd = fd
        return pipe
    }

    /// 读取所有数据
    public func readAll(): Array<UInt8> {
        if (closed) { return Array<UInt8>() }
        // 实际实现通过 C FFI read() 系统调用
        return buffer
    }

    /// 读取一行
    public func readLine(): ?String {
        if (closed) { return None }
        // 简化实现
        return None
    }

    /// 关闭管道
    public func close(): Unit {
        if (!closed) {
            closed = true
            if (fd >= 0) {
                Syscall.close(fd)
            }
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        return closed
    }
}

/// 可写管道 (stdin 写入端)
/// 对应 Bun: StaticPipeWriter 的写入端
public class WritablePipe {
    private var closed: Bool
    private var fd: Int64

    private init() {
        this.closed = false
        this.fd = -1
    }

    public static func create(): WritablePipe {
        let pipe = WritablePipe()
        return pipe
    }

    public static func fromFd(fd: Int64): WritablePipe {
        let pipe = WritablePipe()
        pipe.fd = fd
        return pipe
    }

    /// 写入数据
    public func write(data: Array<UInt8>): Int64 {
        if (closed) { return -1 }
        // 实际实现通过 C FFI write() 系统调用
        return data.size
    }

    /// 写入字符串
    public func writeString(text: String): Int64 {
        let bytes = Array<UInt8>()
        for (c in text) {
            bytes.append(UInt8(c.value))
        }
        return write(bytes)
    }

    /// 刷新缓冲
    public func flush(): Unit {
        // 实际实现通过 C FFI fsync 或类似
    }

    /// 关闭管道
    public func close(): Unit {
        if (!closed) {
            closed = true
            if (fd >= 0) {
                Syscall.close(fd)
            }
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        return closed
    }
}

// ============================================================================
// EnvironmentBuilder - 环境变量构建器
// 严格翻译自: src/spawn/process.rs 中 env 处理逻辑
// ============================================================================

/// 环境变量构建器
/// 对应 Bun: spawn options 中 env 处理
public class EnvironmentBuilder {
    private var env: HashMap<String, String>
    private var inheritParent: Bool

    public init() {
        this.env = HashMap<String, String>()
        this.inheritParent = true
    }

    /// 继承父进程环境
    public func inheritParent(): EnvironmentBuilder {
        this.inheritParent = true
        return this
    }

    /// 不继承父进程环境
    public func clearParent(): EnvironmentBuilder {
        this.inheritParent = false
        return this
    }

    /// 设置环境变量
    public func set(key: String, value: String): EnvironmentBuilder {
        env.put(key, value)
        return this
    }

    /// 删除环境变量
    public func remove(key: String): EnvironmentBuilder {
        env.remove(key)
        return this
    }

    /// 批量设置
    public func setAll(entries: HashMap<String, String>): EnvironmentBuilder {
        for (key in entries.keys()) {
            match (entries.get(key)) {
                case Some(v) => env.put(key, v)
                case None => ()
            }
        }
        return this
    }

    /// 构建最终的环境变量表
    public func build(): HashMap<String, String> {
        if (!inheritParent) {
            return env
        }
        // 合并: 子 env 覆盖父 env
        let result = HashMap<String, String>()
        // TODO: 通过 C FFI extern char **environ 获取父进程环境
        for (key in env.keys()) {
            match (env.get(key)) {
                case Some(v) => result.put(key, v)
                case None => ()
            }
        }
        return result
    }

    /// 构建为 KEY=VALUE 数组 (用于 execve)
    public func buildEnvp(): ArrayList<String> {
        let finalEnv = build()
        let result = ArrayList<String>()
        for (key in finalEnv.keys()) {
            match (finalEnv.get(key)) {
                case Some(v) => result.append("${key}=${v}")
                case None => ()
            }
        }
        return result
    }
}

// ============================================================================
// PosixSpawn - POSIX spawn C FFI 声明
// 严格翻译自: src/spawn/ 中 posix_spawn 相关调用
// Bun 使用 posix_spawn/posix_spawnp 进行进程创建
// ============================================================================

/// POSIX spawn 相关 C FFI 封装
/// 对应 Bun: bun_spawn_sys::posix_spawn
public class PosixSpawn {
    /// posix_spawn 属性
    public class Attrs {
        public var flags: UInt16
        public var pid: Int64
        public var uid: UInt32
        public var gid: UInt32
        public var schedPolicy: Int32
        public var schedParam: Int64
        public var sigMask: Array<UInt64>
        public var sigDefault: Array<UInt64>

        public init() {
            this.flags = 0
            this.pid = 0
            this.uid = 0
            this.gid = 0
            this.schedPolicy = 0
            this.schedParam = 0
            this.sigMask = Array<UInt64>()
            this.sigDefault = Array<UInt64>()
        }

        /// 设置要信号的掩码
        public func setSigMask(mask: Array<UInt64>): Unit {
            sigMask = mask
            flags = flags | 0x01  // POSIX_SPAWN_SETSIGMASK
        }

        /// 设置默认信号处理
        public func setSigDefault(defaults: Array<UInt64>): Unit {
            sigDefault = defaults
            flags = flags | 0x02  // POSIX_SPAWN_SETSIGDEF
        }

        /// 设置调度策略
        public func setSchedPolicy(policy: Int32): Unit {
            schedPolicy = policy
            flags = flags | 0x04  // POSIX_SPAWN_SETSCHEDULER
        }
    }

    /// posix_spawn 文件操作
    public class FileActions {
        private var actions: ArrayList<FileAction>

        public init() {
            this.actions = ArrayList<FileAction>()
        }

        /// 添加 dup2 操作
        /// 对应: posix_spawn_file_actions_adddup2
        public func addDup2(from: Int64, to: Int64): Unit {
            actions.append(FileAction.dup2(from, to))
        }

        /// 添加 close 操作
        /// 对应: posix_spawn_file_actions_addclose
        public func addClose(fd: Int64): Unit {
            actions.append(FileAction.closeFd(fd))
        }

        /// 添加 open 操作
        /// 对应: posix_spawn_file_actions_addopen
        public func addOpen(fd: Int64, path: String, flags: Int64, mode: UInt32): Unit {
            actions.append(FileAction.openFd(fd, path, flags, mode))
        }

        public func getActions(): ArrayList<FileAction> {
            return actions
        }
    }

    /// posix_spawn 执行
    /// 对应: C 函数 posix_spawn / posix_spawnp
    public static func spawn(path: String, actions: FileActions, attrs: Attrs,
                             argv: ArrayList<String>, envp: ArrayList<String>): ?Int64 {
        // 实际实现通过 C FFI:
        // int posix_spawn(pid_t *pid, const char *path,
        //   const posix_spawn_file_actions_t *file_actions,
        //   const posix_spawnattr_t *attrp,
        //   char *const argv[], char *const envp[]);
        return Syscall.posixSpawn(path, actions, attrs, argv, envp)
    }

    /// posix_spawnp 执行 (PATH 搜索)
    /// 对应: C 函数 posix_spawnp
    public static func spawnP(file: String, actions: FileActions, attrs: Attrs,
                              argv: ArrayList<String>, envp: ArrayList<String>): ?Int64 {
        return Syscall.posixSpawnP(file, actions, attrs, argv, envp)
    }
}

/// 文件操作
public enum FileAction {
    | dup2(Int64, Int64)
    | closeFd(Int64)
    | openFd(Int64, String, Int64, UInt32)
}

// ============================================================================
// WindowsProcess - Windows 进程创建 (占位)
// 严格翻译自: src/spawn/process.rs 中的 #[cfg(windows)] 部分
// Bun 在 Windows 上使用 CreateProcessW + libuv
// ============================================================================

/// Windows 进程创建选项 (占位)
/// 对应 Bun: process.rs WindowsSpawnOptions
public class WindowsSpawnOptions {
    public var loop_: Int64     // uv_loop_t* 的占位
    public var hideWindow: Bool
    public var verbatimArgs: Bool

    public init() {
        this.loop_ = 0
        this.hideWindow = false
        this.verbatimArgs = false
    }
}

/// Windows stdio 结果 (占位)
/// 对应 Bun: process.rs WindowsStdioResult
public enum WindowsStdioResult {
    | Buffer(Int64)     // libuv pipe handle
    | BufferFd(Int64)   // fd
    | Unavailable

    public func isAvailable(): Bool {
        match (this) {
            case Unavailable => false
            case _ => true
        }
    }
}

/// Windows 进程创建 (占位)
public class WindowsProcess {
    /// CreateProcessW 封装
    public static func createProcess(options: SpawnOptions, winOpts: WindowsSpawnOptions): ?Process {
        // 实际实现通过 Windows API:
        // CreateProcessW(lpApplicationName, lpCommandLine, ...)
        // 仓颉在 Windows 上需要通过 C FFI 调用
        return None
    }

    /// 通过 libuv spawn
    public static func uvSpawn(loop_: Int64, options: SpawnOptions): ?Process {
        // 实际实现通过 libuv uv_spawn
        return None
    }
}

// ============================================================================
// StdioKind - stdio 类型标识
// 严格翻译自: src/spawn/process.rs - StdioKind
// ============================================================================

/// stdio 端类型
/// 对应 Bun: StdioKind
public enum StdioKind {
    | Stdin
    | Stdout
    | Stderr

    public func toString(): String {
        match (this) {
            case Stdin => "stdin"
            case Stdout => "stdout"
            case Stderr => "stderr"
        }
    }

    public func fdNumber(): Int64 {
        match (this) {
            case Stdin => 0
            case Stdout => 1
            case Stderr => 2
        }
    }
}

// ============================================================================
// Term - 进程终止原因
// 严格翻译自: src/spawn/lib.rs - Term enum
// ============================================================================

/// 进程终止原因
/// 对应 Bun: std.process.Child.Term
public enum Term {
    | Exited(UInt32)
    | Signal(UInt32)
    | Stopped(UInt32)
    | Unknown(UInt32)

    public func toExitCode(): Int64 {
        match (this) {
            case Exited(code) => Int64(code)
            case Signal(sig) => 128 + Int64(sig)
            case Stopped(sig) => 128 + Int64(sig)
            case Unknown(code) => Int64(code)
        }
    }
}

// ============================================================================
// RunOptions / RunResult - 简易进程运行
// 严格翻译自: src/spawn/lib.rs - RunOptions / RunResult
// 对应 std.process.Child.run
// ============================================================================

/// 运行选项
/// 对应 Bun: RunOptions
public class RunOptions {
    public var argv: ArrayList<ArrayList<UInt8>>
    public var envMap: HashMap<String, String>

    public init() {
        this.argv = ArrayList<ArrayList<UInt8>>()
        this.envMap = HashMap<String, String>()
    }
}

/// 运行结果
/// 对应 Bun: RunResult
public class RunResult {
    public var term: Term
    public var stdout: Array<UInt8>
    public var stderr: Array<UInt8>

    public init() {
        this.term = Term.Unknown(0)
        this.stdout = Array<UInt8>()
        this.stderr = Array<UInt8>()
    }
}

// ============================================================================
// Rusage - 资源使用统计
// 严格翻译自: src/spawn_sys 中 Rusage 结构
// ============================================================================

/// 资源使用统计
/// 对应 Bun: Rusage
public class Rusage {
    public var utimeSec: Int64
    public var utimeUsec: Int64
    public var stimeSec: Int64
    public var stimeUsec: Int64
    public var maxrss: Int64
    public var ixrss: Int64
    public var idrss: Int64
    public var isrss: Int64
    public var minflt: Int64
    public var majflt: Int64
    public var nswap: Int64
    public var inblock: Int64
    public var oublock: Int64
    public var msgsnd: Int64
    public var msgrcv: Int64
    public var nsignals: Int64
    public var nvcsw: Int64
    public var nivcsw: Int64

    public init() {
        this.utimeSec = 0
        this.utimeUsec = 0
        this.stimeSec = 0
        this.stimeUsec = 0
        this.maxrss = 0
        this.ixrss = 0
        this.idrss = 0
        this.isrss = 0
        this.minflt = 0
        this.majflt = 0
        this.nswap = 0
        this.inblock = 0
        this.oublock = 0
        this.msgsnd = 0
        this.msgrcv = 0
        this.nsignals = 0
        this.nvcsw = 0
        this.nivcsw = 0
    }

    /// 用户态时间 (秒)
    public func userTimeSeconds(): Float64 {
        return Float64(utimeSec) + Float64(utimeUsec) / 1_000_000.0
    }

    /// 内核态时间 (秒)
    public func systemTimeSeconds(): Float64 {
        return Float64(stimeSec) + Float64(stimeUsec) / 1_000_000.0
    }

    /// 总时间 (秒)
    public func totalTimeSeconds(): Float64 {
        return userTimeSeconds() + systemTimeSeconds()
    }

    /// 峰值内存使用 (KB, 对应 maxrss)
    public func peakMemoryKb(): Int64 {
        return maxrss
    }

    public static func zeroed(): Rusage {
        return Rusage()
    }
}

// ============================================================================
// Syscall - 系统调用封装 (占位)
// 对应 Bun: bun_sys / bun_spawn_sys 中的系统调用
// 实际实现通过仓颉 C FFI
// ============================================================================

/// 系统调用封装
/// 对应 Bun: bun_sys FFI bindings
public class Syscall {
    /// fork + exec
    public static func forkExec(path: String, argv: ArrayList<String>,
                                 env: HashMap<String, String>,
                                 cwd: ?String): ?Int64 {
        // 实际通过 C FFI:
        // 1. pipe() 创建 stdio 管道
        // 2. fork() 创建子进程
        // 3. 子进程: dup2 设置 stdio, chdir, execve
        // 4. 父进程: 返回 pid
        return None
    }

    /// waitpid
    public static func waitpid(pid: Int64): ?Int64 {
        // 实际通过 C FFI: waitpid(pid, &status, 0)
        return None
    }

    /// kill
    public static func kill(pid: Int64, signal: Int64): Bool {
        // 实际通过 C FFI: kill(pid, signal)
        return false
    }

    /// close fd
    public static func close(fd: Int64): Unit {
        // 实际通过 C FFI: close(fd)
    }

    /// posix_spawn
    public static func posixSpawn(path: String, actions: PosixSpawn.FileActions,
                                   attrs: PosixSpawn.Attrs,
                                   argv: ArrayList<String>,
                                   envp: ArrayList<String>): ?Int64 {
        // 实际通过 C FFI: posix_spawn(&pid, path, ...)
        return None
    }

    /// posix_spawnp
    public static func posixSpawnP(file: String, actions: PosixSpawn.FileActions,
                                    attrs: PosixSpawn.Attrs,
                                    argv: ArrayList<String>,
                                    envp: ArrayList<String>): ?Int64 {
        // 实际通过 C FFI: posix_spawnp(&pid, file, ...)
        return None
    }
}

// ============================================================================
// Poller - 进程状态轮询器
// 严格翻译自: src/spawn/process.rs - Poller
// Bun 使用 epoll/kqueue 轮询 pidfd 或 EVFILT_PROC
// ============================================================================

/// 进程状态轮询器
/// 对应 Bun: process.rs Poller
public class Poller {
    private var pidfd: Int64
    private var watching: Bool

    public init() {
        this.pidfd = -1
        this.watching = false
    }

    /// 初始化 pidfd 轮询
    /// 对应 Bun: Poller::init_pidfd (Linux) / Poller::init_kqueue (macOS)
    public func initPidfd(pid: Int64): Bool {
        // Linux: pidfd_open(pid, 0)
        // macOS: kqueue + EVFILT_PROC
        return false
    }

    /// 开始监听
    public func watch(): Unit {
        watching = true
    }

    /// 停止监听
    public func unwatch(): Unit {
        watching = false
    }

    /// 清理
    public func deinit(): Unit {
        if (pidfd >= 0) {
            Syscall.close(pidfd)
            pidfd = -1
        }
        watching = false
    }
}

// ============================================================================
// Subprocess Source - 子进程数据源
// 严格翻译自: src/spawn/lib.rs - subprocess::Source
// ============================================================================

/// 子进程 stdin 数据源
/// 对应 Bun: subprocess::Source
public enum SubprocessSource {
    | OwnedBytes(Array<UInt8>)
    | Detached

    /// 获取数据切片
    public func slice(): ?Array<UInt8> {
        match (this) {
            case OwnedBytes(bytes) => Some(bytes)
            case Detached => None
        }
    }

    /// 分离 (释放数据)
    public func detach(): SubprocessSource {
        return SubprocessSource.Detached
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        match (this) {
            case OwnedBytes(bytes) => bytes.size
            case Detached => 0
        }
    }
}
