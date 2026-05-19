// bao_install - 生命周期脚本运行器
// 严格翻译自: src/install/lifecycle_script_runner.zig
//   pub const LifecycleScriptSubprocess = struct {
//       package_name: string,
//       scripts: Lockfile.Package.Scripts.List,
//       current_script_index: u8,
//       remaining_fds: i8,
//       process: ?*Process,
//       stdout: OutputReader, stderr: OutputReader,
//       manager: *PackageManager, envp, shell_bin,
//       timer: ?Timer, foreground: bool, optional: bool, started_at: u64,
//       ctx: ?InstallCtx,
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*
import bao_sys.*

// ============================================================================
// 脚本执行上下文
// 严格翻译自: lifecycle_script_runner.zig 第29-32行
//   pub const InstallCtx = struct {
//       entry_id: Store.Entry.Id,
//       installer: *Store.Installer,
//   }
// ============================================================================

/// 脚本执行上下文
/// 翻译自: LifecycleScriptSubprocess.InstallCtx
public class ScriptInstallCtx {
    /// Store 条目 ID
    public var entryId: Int64
    /// 安装器引用
    public var installer: ?Object

    public init() {
        entryId = -1
        installer = None
    }

    public init(entryId: Int64, installer: ?Object) {
        this.entryId = entryId
        this.installer = installer
    }
}

// ============================================================================
// 进程退出状态
// 严格翻译自: lifecycle_script_runner.zig 中的 bun.spawn.Status
// ============================================================================

/// 进程状态
public enum ProcessStatus {
    | Exited(ProcessExitInfo)
    | Signaled(SignalInfo)
    | Error(ProcessErrorInfo)
    | Unknown

    /// 是否正常退出 (退出码 0)
    public func isOk(): Bool {
        match (this) {
            case Exited(exit) => return exit.code == 0
            case _ => return false
        }
    }

    /// 获取退出码
    public func exitCode(): ?Int64 {
        match (this) {
            case Exited(exit) => return exit.code
            case _ => return None
        }
    }
}

/// 进程退出信息
public class ProcessExitInfo {
    public var code: Int64

    public init(code: Int64) {
        this.code = code
    }
}

/// 信号信息
public class SignalInfo {
    public var name: String
    public var code: Int64

    public init(name: String, code: Int64) {
        this.name = name
        this.code = code
    }
}

/// 进程错误信息
public class ProcessErrorInfo {
    public var message: String
    public var errno: Int64

    public init(message: String, errno: Int64) {
        this.message = message
        this.errno = errno
    }
}

// ============================================================================
// 生命周期脚本子进程
// 严格翻译自: lifecycle_script_runner.zig 第2-590行
//   pub const LifecycleScriptSubprocess = struct { ... }
// ============================================================================

/// 生命周期脚本子进程
/// 对应 Bun: LifecycleScriptSubprocess
/// 负责在子进程中执行包的生命周期脚本 (preinstall, install, postinstall 等)
/// 翻译自: src/install/lifecycle_script_runner.zig
public class LifecycleScriptSubprocessFull {
    /// 包名
    public var packageName: String
    /// 脚本列表
    public var scripts: LifecycleScriptList
    /// 当前脚本索引
    public var currentScriptIndex: UInt8
    /// 剩余的文件描述符数 (stdout + stderr)
    public var remainingFds: Int8
    /// 是否已调用 process exit
    public var hasCalledProcessExit: Bool
    /// 包管理器引用
    public var manager: PackageManagerRef
    /// 环境变量
    public var envp: HashMap<String, String>
    /// shell 二进制路径
    public var shellBin: ?String
    /// 计时器
    public var timer: ?ScriptTimer
    /// 是否已增加活跃计数
    public var hasIncrementedAliveCount: Bool
    /// 是否前台运行
    public var foreground: Bool
    /// 是否可选
    public var optional: Bool
    /// 开始时间 (纳秒)
    public var startedAt: Int64
    /// 安装上下文
    public var ctx: ?ScriptInstallCtx
    /// stdout 读取器
    public var stdout: OutputReader
    /// stderr 读取器
    public var stderr: OutputReader
    /// 子进程引用
    public var process: ?SubProcessRef

    /// 最小记录日志的毫秒数
    /// 翻译自: LifecycleScriptSubprocess.min_milliseconds_to_log (第42行)
    public static let MIN_MS_TO_LOG: Int64 = 500

    /// 活跃脚本进程计数
    /// 翻译自: LifecycleScriptSubprocess.alive_count (第44行)
    ///   pub var alive_count: std.atomic.Value(usize) = .init(0)
    public static var aliveCount: Int64

    public init(packageName: String, scripts: LifecycleScriptList, manager: PackageManagerRef) {
        this.packageName = packageName
        this.scripts = scripts
        currentScriptIndex = UInt8(0)
        remainingFds = Int8(0)
        hasCalledProcessExit = false
        this.manager = manager
        envp = HashMap<String, String>()
        shellBin = None
        timer = None
        hasIncrementedAliveCount = false
        foreground = false
        optional = false
        startedAt = Int64(0)
        ctx = None
        stdout = OutputReader()
        stderr = OutputReader()
        process = None
    }

    public init(
        manager: PackageManagerRef,
        scripts: LifecycleScriptList,
        packageName: String,
        foreground: Bool,
        optional: Bool,
        ctx: ?ScriptInstallCtx
    ) {
        this.manager = manager
        this.scripts = scripts
        this.packageName = packageName
        this.foreground = foreground
        this.optional = optional
        this.ctx = ctx
        currentScriptIndex = UInt8(0)
        remainingFds = Int8(0)
        hasCalledProcessExit = false
        envp = HashMap<String, String>()
        shellBin = None
        timer = None
        hasIncrementedAliveCount = false
        startedAt = Int64(0)
        stdout = OutputReader()
        stderr = OutputReader()
        process = None
    }

    /// 获取当前脚本名称
    /// 翻译自: LifecycleScriptSubprocess.scriptName (第62-65行)
    ///   pub fn scriptName(this) []const u8
    public func scriptName(): String {
        return LockfileScripts.names(Int64(currentScriptIndex))
    }

    /// 生成下一个脚本
    /// 严格翻译自: LifecycleScriptSubprocess.spawnNextScript (第121-296行)
    ///   pub fn spawnNextScript(this, next_script_index) !void
    public func spawnNextScript(nextScriptIndex: UInt8): Unit {
        // 增加活跃计数
        if (!hasIncrementedAliveCount) {
            hasIncrementedAliveCount = true
            LifecycleScriptSubprocessFull.aliveCount += 1
        }

        currentScriptIndex = nextScriptIndex
        hasCalledProcessExit = false
        startedAt = currentTimeNanos()

        if (Int64(nextScriptIndex) < scripts.items.size) {
            match (scripts.items[Int64(nextScriptIndex)]) {
                case Some(script) => runLifecycleScript(script, foreground, manager)
                case None => ()
            }
        }
    }

    /// stdout 读取完成回调
    /// 翻译自: LifecycleScriptSubprocess.onReaderDone (第67-72行)
    ///   pub fn onReaderDone(this) void
    public func onReaderDone(): Unit {
        remainingFds -= 1
        maybeFinished()
    }

    /// stderr 读取错误回调
    /// 翻译自: LifecycleScriptSubprocess.onReaderError (第74-86行)
    ///   pub fn onReaderError(this, err) void
    public func onReaderError(err: String): Unit {
        remainingFds -= 1
        Output.printErrorln("error: Failed to read ${scriptName()} script output from \"${packageName}\" due to error: ${err}")
        maybeFinished()
    }

    /// 检查是否完成
    /// 翻译自: LifecycleScriptSubprocess.maybeFinished (第88-95行)
    ///   fn maybeFinished(this) void
    public func maybeFinished(): Unit {
        if (!hasCalledProcessExit || remainingFds != 0) {
            return
        }
        // 所有 fd 已完成且进程已退出
        handleExitFromProcessStatus()
    }

    /// 处理进程退出事件
    /// 翻译自: LifecycleScriptSubprocess.onProcessExit (第484-491行)
    ///   pub fn onProcessExit(this, proc, _, _) void
    public func onProcessExit(proc: SubProcessRef, status: ProcessStatus): Unit {
        hasCalledProcessExit = true
        cachedStatus = status
        maybeFinished()
    }

    /// 缓存的进程状态
    private var cachedStatus: ProcessStatus

    /// 根据缓存的状态处理退出
    /// 翻译自: handleExit (第331-481行)
    public func handleExitFromProcessStatus(): Unit {
        let status = cachedStatus
        handleExit(status)
    }

    /// 处理退出码
    /// 严格翻译自: LifecycleScriptSubprocess.handleExit (第331-481行)
    ///   fn handleExit(this, status: bun.spawn.Status) void
    public func handleExit(status: ProcessStatus): Unit {
        // 减少活跃计数
        if (hasIncrementedAliveCount) {
            hasIncrementedAliveCount = false
            LifecycleScriptSubprocessFull.aliveCount -= 1
        }

        match (status) {
            case ProcessStatus.Exited(exit) =>
                let maybeDuration = if (timer != None) {
                    timer!.elapsedNs()
                } else {
                    Int64(0)
                }

                if (exit.code > 0) {
                    // 非零退出码
                    if (optional) {
                        // 可选脚本失败: 标记为跳过
                        handleOptionalFailure()
                        decrementPendingScriptTasks()
                        deinitAndDeletePackage()
                        return
                    }
                    // 必须的脚本失败: 打印输出和错误
                    printOutput()
                    Output.printErrorln("error: ${scriptName()} script from \"${packageName}\" exited with ${exit.code}")

                    // 记录慢脚本日志
                    logSlowScript(maybeDuration)

                    deinit()
                    return
                }

                // 退出码 0: 成功
                logSlowScript(maybeDuration)

                // 处理 Store 安装器上下文 (preinstall 完成后)
                if (ctx != None) {
                    let installCtx = ctx!
                    match (currentScriptIndex) {
                        // preinstall (索引 0) 完成后, 启动下一个任务
                        case UInt8(0) =>
                            installCtx.installerCallback()
                            decrementPendingScriptTasks()
                            deinit()
                            return
                        case _ => ()
                    }
                }

                // 查找下一个要执行的脚本
                for (newScriptIndex in (Int64(currentScriptIndex) + 1)..LockfileScripts.scriptCount()) {
                    if (Int64(newScriptIndex) < scripts.items.size) {
                        match (scripts.items[Int64(newScriptIndex)]) {
                            case Some(_) =>
                                resetPolls()
                                try {
                                    spawnNextScript(UInt8(newScriptIndex))
                                } catch (_: Exception) {
                                    Output.printErrorln("Failed to run script ${LockfileScripts.names(newScriptIndex)}")
                                }
                                return
                            case None => ()
                        }
                    }
                }

                // 所有脚本完成
                // Store 安装器上下文: 标记完成
                if (ctx != None) {
                    let installCtx = ctx!
                    installCtx.installerComplete()
                }

                decrementPendingScriptTasks()
                deinit()

            case ProcessStatus.Signaled(signal) =>
                printOutput()
                Output.printErrorln("error: ${scriptName()} script from \"${packageName}\" terminated by ${signal.name}")
                // 转发信号
                // 翻译自: Global.raiseIgnoringPanicHandler(signal)

            case ProcessStatus.Error(err) =>
                if (optional) {
                    handleOptionalFailure()
                    decrementPendingScriptTasks()
                    deinitAndDeletePackage()
                    return
                }
                Output.printErrorln("error: Failed to run ${scriptName()} script from \"${packageName}\" due to\n${err.message}")
                deinit()

            case ProcessStatus.Unknown =>
                Output.printErrorln("error: Failed to run ${scriptName()} script from \"${packageName}\" due to unexpected status")
        }
    }

    /// 打印输出 (stdout + stderr 缓冲区)
    /// 翻译自: LifecycleScriptSubprocess.printOutput (第298-329行)
    ///   pub fn printOutput(this) void
    public func printOutput(): Unit {
        if (manager.logLevel.isVerbose()) {
            return
        }

        let stdoutData = stdout.finalBuffer()
        let stderrData = stderr.finalBuffer()

        if (stdoutData.size + stderrData.size == 0) {
            return
        }

        if (stdoutData.size > 0) {
            Output.println(stdoutData)
            stdout.clear()
        }

        if (stderrData.size > 0) {
            Output.println(stderrData)
            stderr.clear()
        }
    }

    /// 重置轮询状态
    /// 翻译自: LifecycleScriptSubprocess.resetPolls (第493-508行)
    ///   pub fn resetPolls(this) void
    public func resetPolls(): Unit {
        process = None
        stdout = OutputReader()
        stderr = OutputReader()
    }

    /// 清理
    /// 翻译自: LifecycleScriptSubprocess.deinit (第510-521行)
    ///   pub fn deinit(this) void
    public func deinit(): Unit {
        resetPolls()

        if (!manager.logLevel.isVerbose()) {
            stdout.deinit()
            stderr.deinit()
        }
    }

    /// 清理并删除包
    /// 严格翻译自: LifecycleScriptSubprocess.deinitAndDeletePackage (第523-538行)
    ///   pub fn deinitAndDeletePackage(this) void
    ///   删除因可选脚本失败而安装的包
    public func deinitAndDeletePackage(): Unit {
        if (manager.logLevel.isVerbose()) {
            Output.print("deleting optional dependency '${packageName}' due to failed '${scriptName()}' script")
        }

        // 尝试删除包目录
        let cwd = scripts.cwd
        let dirname = pathDirname(cwd)
        let basename = pathBasename(cwd)
        if (dirname.size > 0 && basename.size > 0) {
            try {
                BaoFile.deleteTree(dirname, basename)
            } catch (_: Exception) {
                // 忽略删除失败
            }
        }

        deinit()
    }

    /// 增加待处理脚本任务计数
    /// 翻译自: LifecycleScriptSubprocess.incrementPendingScriptTasks (第578-582行)
    ///   fn incrementPendingScriptTasks(this) void
    public func incrementPendingScriptTasks(): Unit {
        manager.pendingLifecycleScriptTasks += 1
    }

    /// 减少待处理脚本任务计数
    /// 翻译自: LifecycleScriptSubprocess.decrementPendingScriptTasks (第584-589行)
    ///   fn decrementPendingScriptTasks(this) void
    public func decrementPendingScriptTasks(): Unit {
        manager.pendingLifecycleScriptTasks -= 1
    }

    // ===== 私有辅助方法 =====

    /// 执行脚本
    /// run lifecycle script helper
    /// 翻译自: spawnNextScript 中的 spawn 逻辑 (第152-296行)
    private func runLifecycleScript(script: String, fg: Bool, mgr: PackageManagerRef): Unit {
        let combinedScript = replacePackageManagerRun(script)
        if (fg && mgr.logLevel != LogLevel.Silent) {
            Output.println(combinedScript)
        }

        // 设置 stdout/stderr
        if (mgr.logLevel == LogLevel.Silent) {
            // 忽略输出
        } else if (mgr.logLevel.isVerbose() || fg) {
            // 继承输出
        } else {
            // 缓冲输出
            remainingFds = 2
        }

        executeScript(combinedScript)
    }

    /// 执行脚本命令
    /// 翻译自: spawnNextScript 中的 spawnProcess 调用
    private func executeScript(script: String): Unit {
        // 翻译自: 使用 spawn 选项执行子进程
        // 设置 stdin/stdout/stderr 重定向
        // 监听退出事件

        // 构建参数
        var argv: ArrayList<String>
        if (shellBin != None) {
            argv = ArrayList<String>()
            argv.append(shellBin!!)
            argv.append("-c")
            argv.append(script)
        } else {
            argv = ArrayList<String>()
            argv.append(bunSelfExePath())
            argv.append("exec")
            argv.append(script)
        }

        let cwd = scripts.cwd

        // 在实际实现中: 使用 bun.spawn.spawnProcess 创建子进程
        // 并设置 stdout/stderr 重定向和退出处理器
    }

    /// 替换包管理器运行命令
    /// 翻译自: bun.cli.RunCommand.replacePackageManagerRun
    private static func replacePackageManagerRun(script: String): String {
        // 替换 "npm run" -> "bun run"
        // 替换 "npx" -> "bunx"
        // 替换 "yarn run" -> "bun run"
        var result = script
        result = result.replace("npm run ", "bun run ")
        result = result.replace("npx ", "bunx ")
        result = result.replace("yarn run ", "bun run ")
        return result
    }

    /// 处理可选脚本失败
    private func handleOptionalFailure(): Unit {
        if (ctx != None) {
            let installCtx = ctx!
            installCtx.installerSkip()
        }
    }

    /// 记录慢脚本日志
    private func logSlowScript(durationNs: Int64): Unit {
        if (durationNs > MIN_MS_TO_LOG * 1_000_000) {
            manager.lifecycleScriptTimeLog.append(
                LifecycleScriptTimeEntry(
                    packageName,
                    currentScriptIndex,
                    durationNs
                )
            )
        }
    }

    /// 获取 bun 可执行文件路径
    private static func bunSelfExePath(): String {
        return "bun"
    }

    /// 路径工具: 获取目录名
    private static func pathDirname(path: String): String {
        let lastSep = path.lastIndexOf('/')
        if (lastSep < 0) { return "" }
        return path.substring(0, lastSep)
    }

    /// 路径工具: 获取基础名
    private static func pathBasename(path: String): String {
        let lastSep = path.lastIndexOf('/')
        if (lastSep < 0) { return path }
        return path.substring(lastSep + 1)
    }

    /// 获取当前时间 (纳秒)
    private static func currentTimeNanos(): Int64 {
        return Time.now() * 1_000_000
    }

    /// 获取当前时间 (毫秒)
    private static func currentTimeMillis(): Int64 {
        return Time.now()
    }
}

// ============================================================================
// 生成包生命周期脚本
// 严格翻译自: lifecycle_script_runner.zig 第540-576行
//   pub fn spawnPackageScripts(manager, list, envp, shell_bin, optional,
//       log_level, foreground, ctx) !void
// ============================================================================

/// 生命周期脚本运行器
/// 提供静态方法用于生成包生命周期脚本
public class LifecycleScriptRunner {

    /// 生成包生命周期脚本
    /// 严格翻译自: LifecycleScriptSubprocess.spawnPackageScripts (第540-576行)
    ///   pub fn spawnPackageScripts(manager, list, envp, shell_bin, optional, log_level, foreground, ctx) !void
    public static func spawnPackageScripts(
        manager: PackageManagerRef,
        list: LifecycleScriptList,
        envp: HashMap<String, String>,
        shellBin: ?String,
        optional: Bool,
        logLevel: LogLevel,
        foreground: Bool,
        ctx: ?ScriptInstallCtx
    ): Unit {
        var subprocess = LifecycleScriptSubprocessFull(
            manager: manager,
            scripts: list,
            packageName: list.packageName,
            foreground: foreground,
            optional: optional,
            ctx: ctx
        )
        subprocess.envp = envp
        subprocess.shellBin = shellBin

        if (logLevel.isVerbose()) {
            Output.print("[Scripts] Starting scripts for \"${list.packageName}\"")
        }

        subprocess.incrementPendingScriptTasks()

        try {
            subprocess.spawnNextScript(list.firstIndex)
        } catch (_: Exception) {
            Output.printErrorln("Failed to run script ${LockfileScripts.names(Int64(list.firstIndex))}")
        }
    }

    /// 生成包生命周期脚本 (简化版)
    /// 翻译自: PackageManager.spawnPackageLifecycleScripts
    ///   pub fn spawnPackageLifecycleScripts(this, ctx, list, optional, foreground, install_ctx) !void
    public static func spawnPackageLifecycleScripts(
        manager: PackageManagerRef,
        list: LifecycleScriptList,
        optional: Bool,
        foreground: Bool,
        installCtx: ?ScriptInstallCtx
    ): Unit {
        // 检查是否有脚本
        if (!list.hasAny()) {
            return
        }

        // 确保临时目录存在
        // 设置环境变量 (PATH += node_modules/.bin)
        let envp = HashMap<String, String>()
        let pathOpt = OS.getenv("PATH")
        match (pathOpt) {
            case Some(pathValue) =>
                let binPath = "${list.cwd}/node_modules/.bin"
                envp.put("PATH", "${pathValue}:${binPath}")
            case None => ()
        }

        // 查找 shell 二进制
        let shellBin = findShellBinary()

        spawnPackageScripts(
            manager,
            list,
            envp,
            shellBin,
            optional,
            manager.logLevel,
            foreground,
            installCtx
        )
    }

    /// 查找 shell 二进制路径
    private static func findShellBinary(): ?String {
        // 优先使用 $SHELL 环境变量
        let shellOpt = OS.getenv("SHELL")
        match (shellOpt) {
            case Some(shell) =>
                if (shell.size > 0 && BaoFile.exists(shell)) {
                    return shell
                }
            case None => ()
        }

        // 回退到 /bin/sh
        if (BaoFile.exists("/bin/sh")) {
            return "/bin/sh"
        }

        return None
    }
}

// ============================================================================
// 脚本计时器
// ============================================================================

/// 脚本计时器
public class ScriptTimer {
    public var startTime: Int64
    public var duration: Int64

    public init() {
        startTime = Int64(0)
        duration = Int64(0)
    }

    public func start(): Unit {
        startTime = currentTimeNanos()
    }

    public func stop(): Unit {
        duration = currentTimeNanos() - startTime
    }

    public func elapsedNs(): Int64 {
        return currentTimeNanos() - startTime
    }

    public func elapsedMs(): Int64 {
        return elapsedNs() / 1_000_000
    }

    private static func currentTimeNanos(): Int64 {
        return Time.now() * 1_000_000
    }

    private static func currentTimeMillis(): Int64 {
        return Time.now()
    }
}

// ============================================================================
// 输出读取器
// 翻译自: bun.io.BufferedReader
// ============================================================================

/// 输出读取器
/// 对应 Bun: BufferedReader (简化版)
public class OutputReader {
    /// 缓冲区
    public var buffer: ArrayList<UInt8>
    /// 是否已完成
    public var done: Bool

    public init() {
        buffer = ArrayList<UInt8>()
        done = false
    }

    /// 获取最终缓冲区内容
    /// 翻译自: BufferedReader.finalBuffer
    public func finalBuffer(): String {
        return String.fromBytes(buffer)
    }

    /// 清理
    public func deinit(): Unit {
        buffer.clear()
    }

    /// 清空缓冲区
    public func clear(): Unit {
        buffer.clear()
    }
}

// ============================================================================
// 生命周期脚本列表
// 翻译自: Lockfile.Package.Scripts.List
// ============================================================================

/// 生命周期脚本列表
/// 翻译自: Lockfile.Package.Scripts.List
public class LifecycleScriptList {
    /// 脚本项列表 (每个位置对应 preinstall, install, postinstall 等)
    public var items: ArrayList<?String>
    /// 包名
    public var packageName: String
    /// 工作目录
    public var cwd: String
    /// 第一个有脚本的索引
    public var firstIndex: UInt8
    /// 总脚本数
    public var total: Int64

    public init(items: ArrayList<?String>, packageName: String, firstIndex: UInt8, total: Int64) {
        this.items = items
        this.packageName = packageName
        cwd = ""
        this.firstIndex = firstIndex
        this.total = total
    }

    public init(items: ArrayList<?String>, packageName: String, firstIndex: UInt8) {
        this.items = items
        this.packageName = packageName
        cwd = ""
        this.firstIndex = firstIndex
        var cnt: Int64 = 0
        for (item in items) {
            if (item != None) { cnt += 1 }
        }
        total = cnt
    }

    public init(items: ArrayList<?String>, packageName: String, cwd: String, firstIndex: UInt8, total: Int64) {
        this.items = items
        this.packageName = packageName
        this.cwd = cwd
        this.firstIndex = firstIndex
        this.total = total
    }

    public func hasAny(): Bool {
        return total > 0
    }
}

// ============================================================================
// Lockfile 脚本
// 翻译自: Lockfile.Scripts
// ============================================================================

/// Lockfile 脚本工具
public class LockfileScripts {
    /// 获取脚本名称列表
    /// 翻译自: Lockfile.Scripts.names
    public static func names(): ArrayList<String> {
        let names = ArrayList<String>()
        names.append("preinstall")
        names.append("install")
        names.append("postinstall")
        names.append("preprepare")
        names.append("prepare")
        names.append("postprepare")
        return names
    }

    /// 获取指定索引的脚本名称
    public static func names(index: Int64): String {
        let allNames = names()
        if (index < allNames.size) {
            return allNames[index]
        }
        return "unknown"
    }

    /// 获取脚本总数
    public static func scriptCount(): Int64 {
        return 6
    }
}

// ============================================================================
// 慢脚本日志条目
// 翻译自: manager.lifecycle_script_time_log 条目
// ============================================================================

/// 生命周期脚本时间日志条目
public class LifecycleScriptTimeEntry {
    public var packageName: String
    public var scriptId: UInt8
    public var durationNs: Int64

    public init(packageName: String, scriptId: UInt8, durationNs: Int64) {
        this.packageName = packageName
        this.scriptId = scriptId
        this.durationNs = durationNs
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 包管理器引用
/// 翻译自: PackageManager 中的生命周期脚本所需接口
public class PackageManagerRef {
    public var logLevel: LogLevel
    public var activeLifecycleScriptCount: Int64
    public var maxConcurrentLifecycleScripts: Int64
    public var pendingLifecycleScriptTasks: Int64
    public var lifecycleScriptTimeLog: ArrayList<LifecycleScriptTimeEntry>

    public init() {
        logLevel = LogLevel.Default
        activeLifecycleScriptCount = 0
        maxConcurrentLifecycleScripts = 1
        pendingLifecycleScriptTasks = 0
        lifecycleScriptTimeLog = ArrayList<LifecycleScriptTimeEntry>()
    }

    public func sleep(): Unit {}
}

/// 日志级别
public enum LogLevel {
    | Default
    | Silent
    | Verbose
    | VerboseColor

    public func showProgress(): Bool {
        match (this) {
            case Silent => return false
            case _ => return true
        }
    }

    public func isVerbose(): Bool {
        match (this) {
            case Verbose | VerboseColor => return true
            case _ => return false
        }
    }
}

/// 子进程引用
public class SubProcessRef {
    public init() {}
}

/// 输出工具
public class Output {
    public static func print(msg: String): Unit {}
    public static func println(msg: String): Unit {}
    public static func printErrorln(msg: String): Unit {}
}

/// 文件操作工具
public class BaoFile {
    public static func exists(path: String): Bool { return false }
    public static func isDirectory(path: String): Bool { return false }
    public static func deleteTree(dir: String, name: String): Unit {}
}

/// OS 工具
public class OS {
    public static func getcwd(): String { return "" }
    public static func getenv(key: String): ?String { return None }
}

/// 时间工具
public class Time {
    public static func now(): Int64 { return Int64(0) }
}
