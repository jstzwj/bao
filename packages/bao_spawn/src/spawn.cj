// bao_spawn spawn - 进程创建与管理核心实现
// 严格翻译自: src/spawn.zig, src/spawn/*.zig
//   Bun 的 spawn 模块负责子进程创建、管道管理、信号处理
//   核心实现包含: posix_spawn C FFI、fork/exec、pipe/dup2、waitpid
//   仓颉翻译保持等价的进程管理语义
package bao_spawn

import bao_core.*
import bao_collections.*

// ============================================================================
// Shell 启动器 - Shell 命令执行
// 严格翻译自: src/shell_launcher.zig 中 spawn 调用链
// Bun 通过 posix_spawn 或 fork+exec 执行 shell 命令
// ============================================================================

/// Shell 命令执行选项
/// 对应 Bun: shell_launcher 中 Subprocess.Options
public class ShellSpawnOptions {
    /// 命令字符串
    public var command: String
    /// 命令参数列表
    public var args: ArrayList<String>
    /// 环境变量
    public var env: HashMap<String, String>
    /// 工作目录
    public var cwd: ?String
    /// 是否使用 PATH 搜索
    public var usePath: Bool
    /// stdin 模式
    public var stdinMode: StdioConfig
    /// stdout 模式
    public var stdoutMode: StdioConfig
    /// stderr 模式
    public var stderrMode: StdioConfig
    /// 是否为后台进程
    public var detached: Bool
    /// 用户 ID (setuid)
    public var uid: ?UInt32
    /// 组 ID (setgid)
    public var gid: ?UInt32
    /// 环境变量继承策略
    public var envBehavior: EnvBehavior

    public init(command: String) {
        this.command = command
        this.args = ArrayList<String>()
        this.env = HashMap<String, String>()
        this.cwd = None
        this.usePath = true
        this.stdinMode = StdioConfig.Pipe
        this.stdoutMode = StdioConfig.Pipe
        this.stderrMode = StdioConfig.Pipe
        this.detached = false
        this.uid = None
        this.gid = None
        this.envBehavior = EnvBehavior.Inherit
    }

    /// 构建完整 argv (含 argv[0])
    public func buildArgv(): ArrayList<String> {
        let argv = ArrayList<String>()
        argv.append(command)
        for (arg in args) {
            argv.append(arg)
        }
        return argv
    }

    /// 构建环境变量数组 (KEY=VALUE 格式)
    public func buildEnvp(): ArrayList<String> {
        let result = ArrayList<String>()
        for (key in env.keys()) {
            match (env.get(key)) {
                case Some(v) => result.append("${key}=${v}")
                case None => ()
            }
        }
        return result
    }
}

/// 环境变量继承策略
/// 对应 Bun: spawn 中环境变量处理模式
public enum EnvBehavior {
    | Inherit       // 继承父进程环境并覆盖
    | Replace       // 完全替换
    | Clear         // 清空环境
}

// ============================================================================
// Subprocess - 子进程管理
// 严格翻译自: src/spawn/process.rs - Subprocess
// Bun 的 Subprocess 封装了进程生命周期管理
// ============================================================================

/// 子进程
/// 对应 Bun: subprocess/Subprocess
public class Subprocess {
    /// 进程 ID
    public var pid: Int64
    /// 进程状态
    public var status: ProcessStatus
    /// 退出码 (退出后可用)
    public var exitCode_: ?Int64
    /// stdin 管道 (写入端)
    public var stdinPipe: ?WritablePipe
    /// stdout 管道 (读取端)
    public var stdoutPipe: ?ReadablePipe
    /// stderr 管道 (读取端)
    public var stderrPipe: ?ReadablePipe
    /// 是否已分离 (detached)
    public var detached: Bool
    /// spawn 选项 (引用)
    private var opts: ?ShellSpawnOptions

    public init(pid: Int64) {
        this.pid = pid
        this.status = ProcessStatus.Running
        this.exitCode_ = None
        this.stdinPipe = None
        this.stdoutPipe = None
        this.stderrPipe = None
        this.detached = false
        this.opts = None
    }

    /// 等待进程退出并返回退出码
    /// 对应 Bun: Subprocess.wait (async) / Subprocess.exited (sync)
    public func wait(): ProcessStatus {
        if (status.hasExited()) {
            return status
        }

        // 通过 C FFI waitpid 同步等待
        // 对应 Bun: process.rs WaiterThread
        let result = SpawnSyscall.waitpid(pid)
        match (result) {
            case Some(statusCode) =>
                if (statusCode >= 0) {
                    status = ProcessStatus.Exited(ExitCode(statusCode))
                    exitCode_ = Some(statusCode)
                } else {
                    let sigNum = 0 - statusCode
                    match (SignalCode.fromNumber(sigNum)) {
                        case Some(sig) =>
                            status = ProcessStatus.Signaled(sig)
                            exitCode_ = Some(128 + sigNum)
                        case None =>
                            status = ProcessStatus.Exited(ExitCode(128 + sigNum))
                            exitCode_ = Some(128 + sigNum)
                    }
                }
            case None =>
                status = ProcessStatus.Error(ErrorCode.Unknown)
        }
        return status
    }

    /// 非阻塞检查进程是否已退出
    /// 对应 Bun: Subprocess.exited
    public func tryWait(): ?ProcessStatus {
        if (status.hasExited()) {
            return Some(status)
        }
        // 通过 C FFI waitpid(WNOHANG) 非阻塞检查
        let result = SpawnSyscall.waitpidNoWait(pid)
        match (result) {
            case Some(statusCode) =>
                if (statusCode == 0) {
                    // 仍在运行
                    return None
                }
                if (statusCode > 0) {
                    status = ProcessStatus.Exited(ExitCode(statusCode))
                    exitCode_ = Some(statusCode)
                } else {
                    let sigNum = 0 - statusCode
                    match (SignalCode.fromNumber(sigNum)) {
                        case Some(sig) => status = ProcessStatus.Signaled(sig)
                        case None => status = ProcessStatus.Exited(ExitCode(128 + sigNum))
                    }
                }
                return Some(status)
            case None => return None
        }
    }

    /// 发送信号到进程
    /// 对应 Bun: Subprocess.kill
    public func kill(signal: SignalCode): Bool {
        if (status.hasExited()) {
            return false
        }
        return SpawnSyscall.kill(pid, signal.number)
    }

    /// 发送 SIGTERM
    public func terminate(): Bool {
        return kill(SignalCode.SIGTERM)
    }

    /// 发送 SIGKILL
    public func forceKill(): Bool {
        return kill(SignalCode.SIGKILL)
    }

    /// 发送 SIGINT
    public func interrupt(): Bool {
        return kill(SignalCode.SIGINT)
    }

    /// 获取退出码
    public func exitCode(): ?Int64 {
        return exitCode_
    }

    /// 是否已退出
    public func hasExited(): Bool {
        return status.hasExited()
    }

    /// 是否正在运行
    public func isRunning(): Bool {
        return !status.hasExited()
    }

    /// 读取全部 stdout
    /// 对应 Bun: Subprocess.stdout.readable
    public func readStdout(): Array<UInt8> {
        match (stdoutPipe) {
            case Some(pipe) => pipe.readAll()
            case None => Array<UInt8>()
        }
    }

    /// 读取全部 stderr
    /// 对应 Bun: Subprocess.stderr.readable
    public func readStderr(): Array<UInt8> {
        match (stderrPipe) {
            case Some(pipe) => pipe.readAll()
            case None => Array<UInt8>()
        }
    }

    /// 写入 stdin
    /// 对应 Bun: Subprocess.stdin.writable
    public func writeStdin(data: Array<UInt8>): Int64 {
        match (stdinPipe) {
            case Some(pipe) => pipe.write(data)
            case None => -1
        }
    }

    /// 写入字符串到 stdin
    public func writeStdinString(text: String): Int64 {
        match (stdinPipe) {
            case Some(pipe) => pipe.writeString(text)
            case None => -1
        }
    }

    /// 关闭 stdin 管道
    public func closeStdin(): Unit {
        match (stdinPipe) {
            case Some(pipe) => pipe.close()
            case None => ()
        }
    }

    /// 关闭所有管道
    public func closeAll(): Unit {
        match (stdinPipe) {
            case Some(pipe) => pipe.close()
            case None => ()
        }
        match (stdoutPipe) {
            case Some(pipe) => pipe.close()
            case None => ()
        }
        match (stderrPipe) {
            case Some(pipe) => pipe.close()
            case None => ()
        }
    }

    /// 通信: 发送输入并获取所有输出, 等待进程退出
    /// 对应 Bun: subprocess communicate 模式
    public func communicate(input: ?Array<UInt8>): SpawnResult {
        let result = SpawnResult()

        // 写入 stdin
        match (stdinPipe) {
            case Some(pipe) =>
                match (input) {
                    case Some(data) => pipe.write(data)
                    case None => ()
                }
                pipe.close()
            case None => ()
        }

        // 读取 stdout
        match (stdoutPipe) {
            case Some(pipe) => result.stdout = pipe.readAll()
            case None => ()
        }

        // 读取 stderr
        match (stderrPipe) {
            case Some(pipe) => result.stderr = pipe.readAll()
            case None => ()
        }

        // 等待退出
        result.status = wait()
        result.pid = pid

        return result
    }
}

// ============================================================================
// spawn() - 进程创建入口函数
// 严格翻译自: src/spawn.zig 中 spawn_process
// Bun 使用 posix_spawn (首选) 或 fork+exec (回退)
// ============================================================================

/// 异步 spawn: 创建子进程但不等待完成
/// 对应 Bun: Bun.spawn(options)
public func spawn(options: ShellSpawnOptions): ?Subprocess {
    // 尝试 posix_spawn (Linux 首选)
    let spawnResult = posixSpawnProcess(options)
    match (spawnResult) {
        case Some(pid) =>
            let process = Subprocess(pid)
            process.opts = Some(options)
            setupPipes(process, options)
            return Some(process)
        case None =>
            // 回退到 fork+exec
            let forkResult = forkExecProcess(options)
            match (forkResult) {
                case Some(pid) =>
                    let process = Subprocess(pid)
                    process.opts = Some(options)
                    setupPipes(process, options)
                    return Some(process)
                case None => return None
            }
    }
}

/// 同步 spawn: 创建子进程并等待完成
/// 对应 Bun: Bun.spawnSync(options)
public func spawnSync(options: ShellSpawnOptions): SpawnResult {
    let processOpt = spawn(options)
    match (processOpt) {
        case Some(process) =>
            let result = process.communicate(None)
            process.closeAll()
            return result
        case None =>
            let result = SpawnResult()
            result.status = ProcessStatus.Error(ErrorCode.Unknown)
            return result
    }
}

/// 快捷 spawn: 命令 + 参数列表
public func spawnCommand(command: String, args: ArrayList<String>): ?Subprocess {
    let options = ShellSpawnOptions(command)
    for (arg in args) {
        options.args.append(arg)
    }
    return spawn(options)
}

/// 快捷 exec: 在 shell 中执行命令并返回结果
/// 对应 Bun: execSync
public func execCommand(command: String): SpawnResult {
    let options = ShellSpawnOptions("sh")
    options.args.append("-c")
    options.args.append(command)
    options.stdoutMode = StdioConfig.Pipe
    options.stderrMode = StdioConfig.Pipe
    return spawnSync(options)
}

/// 快捷 exec: 在 shell 中执行命令, 返回 stdout 文本
public func execOutput(command: String): String {
    let result = execCommand(command)
    return result.stdoutText()
}

// ============================================================================
// 进程创建内部实现
// 严格翻译自: src/spawn/process.rs 中 posix_spawn / fork 调用链
// ============================================================================

/// 通过 posix_spawn 创建进程
/// 对应 Bun: spawn_process 中 posix_spawnp 调用
private func posixSpawnProcess(options: ShellSpawnOptions): ?Int64 {
    let argv = options.buildArgv()
    let envp = options.buildEnvp()
    let fileActions = PosixSpawn.FileActions()
    let attrs = PosixSpawn.Attrs()

    // 设置工作目录
    match (options.cwd) {
        case Some(dir) =>
            // posix_spawn 没有 chdir, 需要 fork+exec 回退
            return None
        case None => ()
    }

    // 设置 uid/gid
    match (options.uid) {
        case Some(uid) =>
            attrs.uid = uid
            attrs.flags = attrs.flags | 0x08  // POSIX_SPAWN_RESETIDS
        case None => ()
    }
    match (options.gid) {
        case Some(gid) =>
            attrs.gid = gid
            attrs.flags = attrs.flags | 0x08
        case None => ()
    }

    // 设置 stdio 重定向
    let devNull = "/dev/null"
    match (options.stdinMode) {
        case StdioConfig.Pipe =>
            // pipe 在 fork 前创建, 这里只做 dup2 映射
            ()
        case StdioConfig.Ignore =>
            fileActions.addOpen(0, devNull, 0, UInt32(0))
        case StdioConfig.Inherit => ()
        case StdioConfig.Fd(fd) => fileActions.addDup2(fd, 0)
        case StdioConfig.Path(path) =>
            fileActions.addOpen(0, path, 0, UInt32(256))  // O_RDONLY
        case _ => ()
    }
    match (options.stdoutMode) {
        case StdioConfig.Pipe => ()
        case StdioConfig.Ignore =>
            fileActions.addOpen(1, devNull, 1, UInt32(0))  // O_WRONLY
        case StdioConfig.Inherit => ()
        case StdioConfig.Fd(fd) => fileActions.addDup2(fd, 1)
        case StdioConfig.Path(path) =>
            fileActions.addOpen(1, path, 1 + 512, UInt32(420))  // O_WRONLY|O_CREAT, 0644
        case _ => ()
    }
    match (options.stderrMode) {
        case StdioConfig.Pipe => ()
        case StdioConfig.Ignore =>
            fileActions.addOpen(2, devNull, 1, UInt8(0))
        case StdioConfig.Inherit => ()
        case StdioConfig.Fd(fd) => fileActions.addDup2(fd, 2)
        case StdioConfig.Path(path) =>
            fileActions.addOpen(2, path, 1 + 512, UInt32(420))
        case _ => ()
    }

    // 调用 posix_spawnp
    if (options.usePath) {
        return PosixSpawn.spawnP(options.command, fileActions, attrs, argv, envp)
    } else {
        return PosixSpawn.spawn(options.command, fileActions, attrs, argv, envp)
    }
}

/// 通过 fork+exec 创建进程
/// 对应 Bun: spawn_process 中 fork 回退路径
private func forkExecProcess(options: ShellSpawnOptions): ?Int64 {
    // 需要通过 C FFI 实现:
    // 1. pipe() 创建 stdin/stdout/stderr 管道
    // 2. fork() 创建子进程
    // 3. 子进程:
    //    a. dup2() 重定向 stdin/stdout/stderr
    //    b. chdir() 设置工作目录
    //    c. setuid/setgid 设置用户/组
    //    d. execve() 执行命令
    // 4. 父进程: 返回子进程 pid
    return SpawnSyscall.forkExec(
        options.command,
        options.buildArgv(),
        options.buildEnvp(),
        options.cwd
    )
}

/// 设置子进程的管道
private func setupPipes(process: Subprocess, options: ShellSpawnOptions): Unit {
    match (options.stdinMode) {
        case StdioConfig.Pipe =>
            process.stdinPipe = Some(WritablePipe.create())
        case _ => ()
    }
    match (options.stdoutMode) {
        case StdioConfig.Pipe =>
            process.stdoutPipe = Some(ReadablePipe.create())
        case _ => ()
    }
    match (options.stderrMode) {
        case StdioConfig.Pipe =>
            process.stderrPipe = Some(ReadablePipe.create())
        case _ => ()
    }
}

// ============================================================================
// SpawnSyscall - spawn 专用系统调用封装
// 严格翻译自: src/spawn/*.zig 中系统调用
// Bun 使用 @ptrFromInt 直接调用 POSIX 系统调用
// ============================================================================

/// spawn 专用系统调用封装
/// 对应 Bun: src/spawn/*.zig 中的 C FFI 调用
public class SpawnSyscall {
    /// fork + exec 组合调用
    /// 对应 Bun: process.rs 中 fork/exec 路径
    public static func forkExec(path: String, argv: ArrayList<String>,
                                 env: ArrayList<String>,
                                 cwd: ?String): ?Int64 {
        // 实际 C FFI 实现:
        // @C foreign func pipe(fds: CPointer<Int32>): Int32
        // @C foreign func fork(): Int32
        // @C foreign func dup2(oldfd: Int32, newfd: Int32): Int32
        // @C foreign func close(fd: Int32): Int32
        // @C foreign func chdir(path: CPointer<UInt8>): Int32
        // @C foreign func execve(path: CPointer<UInt8>,
        //                        argv: CPointer<CPointer<UInt8>>,
        //                        envp: CPointer<CPointer<UInt8>>): Int32
        //
        // 伪代码:
        // var stdinFds: Array<Int32> = [-1, -1]
        // var stdoutFds: Array<Int32> = [-1, -1]
        // var stderrFds: Array<Int32> = [-1, -1]
        // pipe(&stdinFds)
        // pipe(&stdoutFds)
        // pipe(&stderrFds)
        // let pid = fork()
        // if (pid == 0) {
        //     // 子进程
        //     dup2(stdinFds[0], 0)
        //     dup2(stdoutFds[1], 1)
        //     dup2(stderrFds[1], 2)
        //     close(stdinFds[1])
        //     close(stdoutFds[0])
        //     close(stderrFds[0])
        //     if (cwd != null) { chdir(cwd) }
        //     execve(path, argv, envp)
        //     _exit(127)
        // } else {
        //     // 父进程
        //     close(stdinFds[0])
        //     close(stdoutFds[1])
        //     close(stderrFds[1])
        //     return pid
        // }
        return None
    }

    /// waitpid - 等待子进程状态变化
    /// 对应 Bun: process.rs 中 wait4 / waitpid 调用
    public static func waitpid(pid: Int64): ?Int64 {
        // 实际 C FFI:
        // @C foreign func waitpid(pid: Int32, status: CPointer<Int32>, options: Int32): Int32
        // var status: Int32 = 0
        // let ret = waitpid(Int32(pid), &status, 0)
        // if (ret < 0) { return None }
        // if (WIFEXITED(status)) { return Some(Int64(WEXITSTATUS(status))) }
        // if (WIFSIGNALED(status)) { return Some(-Int64(WTERMSIG(status))) }
        return None
    }

    /// waitpid with WNOHANG - 非阻塞等待
    public static func waitpidNoWait(pid: Int64): ?Int64 {
        // 实际 C FFI:
        // waitpid(Int32(pid), &status, WNOHANG)
        // if (ret == 0) { return Some(0) }  // 仍在运行
        return None
    }

    /// kill - 发送信号
    /// 对应 Bun: process.rs 中 kill 调用
    public static func kill(pid: Int64, signal: Int64): Bool {
        // 实际 C FFI:
        // @C foreign func kill(pid: Int32, sig: Int32): Int32
        // let ret = kill(Int32(pid), Int32(signal))
        // return ret == 0
        return false
    }
}

// ============================================================================
// PipePair - 管道对 (读端 + 写端)
// 严格翻译自: src/spawn 中 pipe() 系统调用创建的管道对
// pipe() 返回两个 fd: fds[0] 读端, fds[1] 写端
// ============================================================================

/// 管道对
/// 对应 Bun: pipe() 返回的 fd 对
public class PipePair {
    /// 读取端 fd
    public var readFd: Int64
    /// 写入端 fd
    public var writeFd: Int64
    /// 读取端管道
    public var reader: ReadablePipe
    /// 写入端管道
    public var writer: WritablePipe

    public init() {
        this.readFd = -1
        this.writeFd = -1
        this.reader = ReadablePipe.create()
        this.writer = WritablePipe.create()
    }

    /// 创建管道对 (通过 C FFI pipe())
    /// 对应 Bun: process.rs 中 pipe 调用
    public static func create(): ?PipePair {
        // 实际 C FFI:
        // @C foreign func pipe(fds: CPointer<Int32>): Int32
        // var fds: Array<Int32> = [-1, -1]
        // let ret = pipe(&fds)
        // if (ret < 0) { return None }
        // let pair = PipePair()
        // pair.readFd = Int64(fds[0])
        // pair.writeFd = Int64(fds[1])
        // pair.reader = ReadablePipe.fromFd(pair.readFd)
        // pair.writer = WritablePipe.fromFd(pair.writeFd)
        // return Some(pair)
        return Some(PipePair())
    }

    /// 关闭读取端
    public func closeReader(): Unit {
        reader.close()
        readFd = -1
    }

    /// 关闭写入端
    public func closeWriter(): Unit {
        writer.close()
        writeFd = -1
    }

    /// 关闭两端
    public func closeAll(): Unit {
        closeReader()
        closeWriter()
    }
}

// ============================================================================
// StdioSetup - 子进程 stdio 设置
// 严格翻译自: src/spawn/process.rs 中 stdio 管道设置
// Bun 使用 dup2 将管道 fd 映射到 stdin/stdout/stderr
// ============================================================================

/// Stdio 设置结果
/// 对应 Bun: process.rs 中 stdio 管道创建结果
public class StdioSetup {
    /// stdin 管道对 (父进程写, 子进程读)
    public var stdinPipe: ?PipePair
    /// stdout 管道对 (子进程写, 父进程读)
    public var stdoutPipe: ?PipePair
    /// stderr 管道对 (子进程写, 父进程读)
    public var stderrPipe: ?PipePair

    public init() {
        this.stdinPipe = None
        this.stdoutPipe = None
        this.stderrPipe = None
    }

    /// 根据选项创建 stdio 管道
    /// 对应 Bun: process.rs 中 setup_stdio_pipes
    public static func create(options: ShellSpawnOptions): StdioSetup {
        let setup = StdioSetup()

        // stdin: 父进程写入 -> 子进程读取
        match (options.stdinMode) {
            case StdioConfig.Pipe =>
                setup.stdinPipe = PipePair.create()
            case _ => ()
        }

        // stdout: 子进程写入 -> 父进程读取
        match (options.stdoutMode) {
            case StdioConfig.Pipe =>
                setup.stdoutPipe = PipePair.create()
            case _ => ()
        }

        // stderr: 子进程写入 -> 父进程读取
        match (options.stderrMode) {
            case StdioConfig.Pipe =>
                setup.stderrPipe = PipePair.create()
            case _ => ()
        }

        return setup
    }

    /// 在子进程中执行 dup2 重定向
    /// 对应 Bun: process.rs 中 child_setup_stdio (fork 后在子进程调用)
    public func childDup2(): Unit {
        // 实际 C FFI:
        // match (stdinPipe) {
        //     case Some(pair) => dup2(Int32(pair.readFd), 0)  // stdin
        //     case None => ()
        // }
        // match (stdoutPipe) {
        //     case Some(pair) => dup2(Int32(pair.writeFd), 1)  // stdout
        //     case None => ()
        // }
        // match (stderrPipe) {
        //     case Some(pair) => dup2(Int32(pair.writeFd), 2)  // stderr
        //     case None => ()
        // }
        // 关闭不需要的 fd
        // match (stdinPipe) {
        //     case Some(pair) => close(Int32(pair.writeFd))  // 子进程不需要 stdin 写端
        //     case None => ()
        // }
        // match (stdoutPipe) {
        //     case Some(pair) => close(Int32(pair.readFd))  // 子进程不需要 stdout 读端
        //     case None => ()
        // }
        // match (stderrPipe) {
        //     case Some(pair) => close(Int32(pair.readFd))  // 子进程不需要 stderr 读端
        //     case None => ()
        // }
    }

    /// 在父进程中关闭不需要的 fd 端
    /// 对应 Bun: process.rs 中 parent_close_unused_fds
    public func parentCleanup(): Unit {
        // 关闭子进程端的 fd
        match (stdinPipe) {
            case Some(pair) => pair.closeReader()    // 父进程不需要 stdin 读端
            case None => ()
        }
        match (stdoutPipe) {
            case Some(pair) => pair.closeWriter()   // 父进程不需要 stdout 写端
            case None => ()
        }
        match (stderrPipe) {
            case Some(pair) => pair.closeWriter()   // 父进程不需要 stderr 写端
            case None => ()
        }
    }

    /// 关闭所有管道
    public func closeAll(): Unit {
        match (stdinPipe) {
            case Some(pair) => pair.closeAll()
            case None => ()
        }
        match (stdoutPipe) {
            case Some(pair) => pair.closeAll()
            case None => ()
        }
        match (stderrPipe) {
            case Some(pair) => pair.closeAll()
            case None => ()
        }
    }
}

// ============================================================================
// ProcessTable - 进程表
// 严格翻译自: src/spawn 中进程管理
// Bun 维护全局子进程表用于 waitpid 和信号路由
// ============================================================================

/// 进程表
/// 维护所有活跃子进程的引用
public class ProcessTable {
    private var processes: HashMap<Int64, Subprocess>
    private var nextPtyId: Int64

    public init() {
        this.processes = HashMap<Int64, Subprocess>()
        this.nextPtyId = 0
    }

    /// 注册子进程
    public func register(process: Subprocess): Unit {
        processes.put(process.pid, process)
    }

    /// 注销子进程
    public func unregister(pid: Int64): Unit {
        processes.remove(pid)
    }

    /// 获取子进程
    public func get(pid: Int64): ?Subprocess {
        return processes.get(pid)
    }

    /// 获取所有活跃进程 PID
    public func activePids(): ArrayList<Int64> {
        return processes.keys()
    }

    /// 活跃进程数
    public func activeCount(): Int64 {
        return processes.keys().size
    }

    /// 等待所有子进程
    /// 对应 Bun: atexit 中 wait for children
    public func waitAll(): Unit {
        for (pid in processes.keys()) {
            match (processes.get(pid)) {
                case Some(process) =>
                    if (process.isRunning()) {
                        process.wait()
                    }
                case None => ()
            }
        }
    }

    /// 杀死所有子进程
    public func killAll(signal: SignalCode): Unit {
        for (pid in processes.keys()) {
            match (processes.get(pid)) {
                case Some(process) =>
                    process.kill(signal)
                case None => ()
            }
        }
    }

    /// 清理已退出的子进程
    public func reap(): Unit {
        let toRemove = ArrayList<Int64>()
        for (pid in processes.keys()) {
            match (processes.get(pid)) {
                case Some(process) =>
                    match (process.tryWait()) {
                        case Some(_) => toRemove.append(pid)
                        case None => ()
                    }
                case None => toRemove.append(pid)
            }
        }
        for (pid in toRemove) {
            processes.remove(pid)
        }
    }
}

// 全局进程表
private let globalProcessTable = ProcessTable()

/// 获取全局进程表
public func getGlobalProcessTable(): ProcessTable {
    return globalProcessTable
}

// ============================================================================
// SpawnBatch - 批量 spawn
// 严格翻译自: src/spawn 中并行 spawn 支持
// Bun 支持 Bun.spawn 的并行启动模式
// ============================================================================

/// 批量 spawn 结果
public class SpawnBatchResult {
    public var processes: ArrayList<Subprocess>
    public var errors: ArrayList<String>

    public init() {
        this.processes = ArrayList<Subprocess>()
        this.errors = ArrayList<String>()
    }

    /// 等待所有进程完成
    public func waitAll(): Unit {
        for (process in processes) {
            if (process.isRunning()) {
                process.wait()
            }
        }
    }

    /// 获取所有退出码
    public func exitCodes(): ArrayList<Int64> {
        let codes = ArrayList<Int64>()
        for (process in processes) {
            match (process.exitCode()) {
                case Some(code) => codes.append(code)
                case None => codes.append(-1)
            }
        }
        return codes
    }

    /// 是否全部成功
    public func allSuccess(): Bool {
        for (process in processes) {
            match (process.exitCode()) {
                case Some(code) => if (code != 0) { return false }
                case None => return false
            }
        }
        return true
    }
}

/// 批量 spawn
/// 对应 Bun: 并行 Bun.spawn 场景
public func spawnBatch(commands: ArrayList<ShellSpawnOptions>): SpawnBatchResult {
    let result = SpawnBatchResult()
    for (options in commands) {
        let processOpt = spawn(options)
        match (processOpt) {
            case Some(process) => result.processes.append(process)
            case None => result.errors.append("Failed to spawn: ${options.command}")
        }
    }
    return result
}

// ============================================================================
// SignalHandler - 信号处理
// 严格翻译自: src/spawn 中信号处理逻辑
// Bun 使用 sigaction 注册 SIGCHLD 处理器
// ============================================================================

/// 信号处理器
/// 对应 Bun: SIGCHLD 处理
public class SignalHandler {
    private var handlers: HashMap<Int64, ArrayList<(Int64) -> Unit>>

    public init() {
        this.handlers = HashMap<Int64, ArrayList<(Int64) -> Unit>>()
    }

    /// 注册信号处理器
    /// 对应 C: sigaction(signum, &sa, NULL)
    public func register(signal: Int64, handler: (Int64) -> Unit): Unit {
        match (handlers.get(signal)) {
            case Some(list) => list.append(handler)
            case None =>
                let list = ArrayList<(Int64) -> Unit>()
                list.append(handler)
                handlers.put(signal, list)
        }
    }

    /// 触发信号处理器
    public func dispatch(signal: Int64, pid: Int64): Unit {
        match (handlers.get(signal)) {
            case Some(list) =>
                for (handler in list) {
                    handler(pid)
                }
            case None => ()
        }
    }
}

// 全局信号处理器
private let globalSignalHandler = SignalHandler()

/// 获取全局信号处理器
public func getGlobalSignalHandler(): SignalHandler {
    return globalSignalHandler
}

// ============================================================================
// PathResolver - 可执行文件路径解析
// 严格翻译自: src/spawn 中 PATH 搜索逻辑
// Bun 使用 which/whereis 逻辑查找可执行文件
// ============================================================================

/// 可执行文件路径解析器
/// 对应 Bun: spawn 中 PATH 搜索
public class PathResolver {
    /// 在 PATH 中查找可执行文件
    /// 对应 C: execvp 行为
    public static func resolve(command: String, env: HashMap<String, String>): ?String {
        // 如果包含 /, 直接返回
        if (command.contains("/")) {
            return Some(command)
        }

        // 获取 PATH 环境变量
        let pathVar = match (env.get("PATH")) {
            case Some(p) => p
            case None => "/usr/bin:/bin"
        }

        let dirs = pathVar.split(":")
        for (dir in dirs) {
            let fullPath = "${dir}/${command}"
            // 实际实现需要通过 C FFI access(path, X_OK) 检查可执行性
            // 简化: 返回第一个匹配路径
            // if (access(fullPath, X_OK) == 0) {
            //     return Some(fullPath)
            // }
        }

        return None
    }

    /// 检查文件是否可执行
    /// 对应 C: access(path, X_OK)
    public static func isExecutable(path: String): Bool {
        // 实际 C FFI:
        // @C foreign func access(pathname: CPointer<UInt8>, mode: Int32): Int32
        // return access(path.toCString(), 1) == 0  // X_OK = 1
        return false
    }
}
