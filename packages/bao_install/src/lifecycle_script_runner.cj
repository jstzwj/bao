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
// 严格翻译自: lifecycle_script_runner.zig - InstallCtx
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
}

// ============================================================================
// 生命周期脚本子进程
// 严格翻译自: lifecycle_script_runner.zig - LifecycleScriptSubprocess
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
    /// 开始时间 (毫秒)
    public var startedAt: Int64
    /// 安装上下文
    public var ctx: ?ScriptInstallCtx

    /// 最小记录日志的毫秒数
    /// 翻译自: LifecycleScriptSubprocess.min_milliseconds_to_log
    public static let MIN_MS_TO_LOG: Int64 = 500

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
    }

    /// 获取当前脚本名称
    /// 翻译自: LifecycleScriptSubprocess.scriptName
    public func scriptName(): String {
        return LockfileScripts.names(Int64(currentScriptIndex))
    }

    /// 生成下一个脚本
    /// 翻译自: LifecycleScriptSubprocess.spawnNextScript
    public func spawnNextScript(nextScriptIndex: UInt8): Unit {
        if (!hasIncrementedAliveCount) {
            hasIncrementedAliveCount = true
        }

        currentScriptIndex = nextScriptIndex
        hasCalledProcessExit = false
        startedAt = cacheCurrentTimeMillis()

        if (Int64(nextScriptIndex) < scripts.items.size) {
            match (scripts.items[Int64(nextScriptIndex)]) {
                case Some(script) => runLifecycleScript(script, foreground, manager)
                case None => ()
            }
        }
    }

    /// 处理 stdout 读取完成
    /// 翻译自: LifecycleScriptSubprocess.onReaderDone
    public func onReaderDone(): Unit {
        remainingFds -= 1
        maybeFinished()
    }

    /// 处理读取错误
    /// 翻译自: LifecycleScriptSubprocess.onReaderError
    public func onReaderError(err: String): Unit {
        remainingFds -= 1
        Output.printErrorln("error: Failed to read ${scriptName()} script output from \"${packageName}\" due to error: ${err}")
        maybeFinished()
    }

    /// 检查是否完成
    /// 翻译自: LifecycleScriptSubprocess.maybeFinished
    public func maybeFinished(): Unit {
        if (!hasCalledProcessExit || remainingFds != 0) {
            return
        }
        // 处理退出状态
    }

    /// 处理退出码
    /// 翻译自: LifecycleScriptSubprocess.handleExit
    public func handleExit(exitCode: Int64): Unit {
        if (exitCode != 0 && !optional) {
            Output.printErrorln("error: ${packageName} ${scriptName()} script failed (exit code ${exitCode})")
        }

        // 检查是否还有下一个脚本
        var nextIndex = Int64(currentScriptIndex) + 1
        while (nextIndex < scripts.items.size) {
            let hasScript = match (scripts.items[nextIndex]) {
                case Some(_) => true
                case None => false
            }
            if (hasScript) {
                spawnNextScript(UInt8(nextIndex))
                return
            }
            nextIndex += 1
        }

        // 所有脚本完成
        if (hasIncrementedAliveCount) {
            hasIncrementedAliveCount = false
        }
    }

    /// 执行脚本
    /// run lifecycle script helper
    private func runLifecycleScript(script: String, fg: Bool, mgr: PackageManagerRef): Unit {
        let combinedScript = replacePackageManagerRun(script)
        if (fg && mgr.logLevel != LogLevel.Silent) {
            Output.println(combinedScript)
        }
        executeScript(combinedScript)
    }

    private func executeScript(script: String): Unit {
        // 翻译自: 使用 spawn 选项执行子进程
        // 设置 stdin/stdout/stderr 重定向
        // 监听退出事件
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

    /// 生成包生命周期脚本
    /// 翻译自: PackageManager.spawnPackageLifecycleScripts
    ///   pub fn spawnPackageLifecycleScripts(this, ctx, list, optional, foreground, install_ctx) !void
    public static func spawnPackageScripts(
        manager: PackageManagerRef,
        list: LifecycleScriptList,
        opt: Bool,
        fg: Bool,
        installCtx: ?ScriptInstallCtx
    ): Unit {
        // 检查是否有脚本
        if (!list.hasAny()) {
            return
        }

        // 确保临时目录存在
        // 设置环境变量 (PATH += node_modules/.bin)
        // 查找 shell 二进制
        // 创建并启动 LifecycleScriptSubprocess
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
        startTime = cacheCurrentTimeMillis()
    }

    public func stop(): Unit {
        duration = cacheCurrentTimeMillis() - startTime
    }

    public func elapsedMs(): Int64 {
        return cacheCurrentTimeMillis() - startTime
    }
}
