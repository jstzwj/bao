// bao_install - 生命周期脚本
// 严格翻译自: src/install/lifecycle_script_runner.zig, src/install/lockfile/Package/Scripts.zig
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 脚本钩子名称
// 严格翻译自: src/install/lockfile/Package/Scripts.zig
//   pub const names = [_]string{
//       "preinstall", "install", "postinstall",
//       "preprepare", "prepare", "postprepare",
//   }
// ============================================================================

/// 生命周期脚本钩子名称
/// 对应 Bun: Lockfile.Scripts.names
public class ScriptHooks {
    public static let PREINSTALL: String = "preinstall"
    public static let INSTALL: String = "install"
    public static let POSTINSTALL: String = "postinstall"
    public static let PREPREPARE: String = "preprepare"
    public static let PREPARE: String = "prepare"
    public static let POSTPREPARE: String = "postprepare"

    /// 所有钩子名称按执行顺序
    public static let ALL: ArrayList<String> = ArrayList<String>([
        "preinstall",
        "install",
        "postinstall",
        "preprepare",
        "prepare",
        "postprepare"
    ])
}

// ============================================================================
// 脚本环境变量
// 严格翻译自: src/install/lifecycle_script_runner.zig
//   Bun 设置 npm_package_* 环境变量和 PATH 供脚本使用
// ============================================================================

/// 脚本执行环境变量
/// 对应 Bun: LifecycleScriptSubprocess.envp
public class ScriptEnvironment {
    /// 包名
    public var packageName: String
    /// 包版本
    public var packageVersion: String
    /// 包路径
    public var packagePath: String
    /// 项目根目录
    public var rootDir: String
    /// node_modules .bin 路径
    public var binPath: String
    /// npm_command 标识
    public var npmCommand: String

    public init() {
        packageName = ""
        packageVersion = ""
        packagePath = ""
        rootDir = ""
        binPath = ""
        npmCommand = "install"
    }

    /// 构建环境变量映射
    /// 对应 Bun: LifecycleScriptSubprocess 中设置的环境变量
    public func toEnvMap(): HashMap<String, String> {
        let env = HashMap<String, String>()

        // 继承当前环境
        let pathEnv = bao_sys.SysModule.getEnv("PATH")
        match (pathEnv) {
            case Some(p) => env.put("PATH", "${binPath}:${p}")
            case None => env.put("PATH", binPath)
        }

        let homeEnv = bao_sys.SysModule.getEnv("HOME")
        match (homeEnv) {
            case Some(h) => env.put("HOME", h)
            case None => {}
        }

        // npm_package_* 变量
        env.put("npm_package_name", packageName)
        env.put("npm_package_version", packageVersion)
        env.put("npm_package_json", bao_path.PathModule.join(ArrayList<String>([packagePath, "package.json"])))
        env.put("npm_package_path", packagePath)

        // 项目根信息
        env.put("INIT_CWD", rootDir)
        env.put("npm_command", npmCommand)

        // node 相关
        env.put("NODE", "bao")  // Bun 使用自身作为 NODE 替代

        return env
    }

    /// 从包信息构建环境
    public static func fromPackage(name: String, version: String, pkgPath: String, root: String): ScriptEnvironment {
        let env = ScriptEnvironment()
        env.packageName = name
        env.packageVersion = version
        env.packagePath = pkgPath
        env.rootDir = root
        env.binPath = bao_path.PathModule.join(ArrayList<String>([root, "node_modules", ".bin"]))
        return env
    }
}

// ============================================================================
// 脚本执行器
// 严格翻译自: src/install/lifecycle_script_runner.zig - LifecycleScriptSubprocess
//   Bun 使用子进程执行生命周期脚本, 支持并行 (MAX_PARALLEL_PROCESSES=10)
//   使用 shell -c 或 bun exec 执行命令
// ============================================================================

/// 脚本执行器 - 在子进程中运行生命周期脚本
/// 对应 Bun: LifecycleScriptSubprocess
public class ScriptRunner {
    /// 最大并行进程数
    /// 对应 Bun: Lockfile.Scripts.MAX_PARALLEL_PROCESSES = 10
    public static let MAX_PARALLEL: Int64 = 10

    /// 执行超时 (毫秒)
    public var timeout: Int64
    /// 是否在前台运行 (显示输出)
    public var foreground: Bool
    /// 是否忽略脚本 (对应 --ignore-scripts)
    public var ignoreScripts: Bool
    /// 环境变量
    public var env: ScriptEnvironment

    public init() {
        timeout = 60000  // 60秒
        foreground = false
        ignoreScripts = false
        env = ScriptEnvironment()
    }

    /// 运行单个脚本命令
    /// 对应 Bun: LifecycleScriptSubprocess.spawnNextScript
    /// 返回退出码, -1 表示启动失败
    public func run(command: String, cwd: String): Int64 {
        if (ignoreScripts) { return 0 }
        if (command.length == 0) { return 0 }

        // 构建环境变量
        let envMap = env.toEnvMap()
        let envArgs = ArrayList<String>()
        for (key in envMap.keys()) {
            match (envMap.get(key)) {
                case Some(v) => envArgs.append("${key}=${v}")
                case None => {}
            }
        }

        // 执行 shell 命令
        // 对应 Bun: 使用 /bin/sh -c 或 bun exec
        let shell = bao_sys.SysModule.getEnv("SHELL").getOrElse(() => "/bin/sh")
        let args = ArrayList<String>([shell, "-c", command])

        // 使用 bao_sys 执行子进程
        let result = bao_sys.Process.run(
            command: args,
            cwd: cwd,
            env: envArgs,
            timeout: timeout
        )

        match (result) {
            case Some(exitCode) => return exitCode
            case None => return -1
        }
    }

    /// 检查命令是否安全执行
    /// 对应 Bun: trusted_dependencies 检查
    public func isTrusted(packageName: String, trustedList: HashSet<String>): Bool {
        if (trustedList.contains(packageName)) { return true }
        if (trustedList.contains("*")) { return true }
        return false
    }
}

// ============================================================================
// 生命周期脚本管理
// 严格翻译自: src/install/lifecycle_script_runner.zig + lockfile/Package/Scripts.zig
//   Bun 按固定顺序执行脚本: preinstall -> install -> postinstall
//   -> preprepare -> prepare -> postprepare
// ============================================================================

/// 生命周期脚本管理器
/// 对应 Bun: PackageManager 中执行 lifecycle scripts 的逻辑
public class LifecycleScripts {
    private var runner: ScriptRunner
    private var results: ArrayList<ScriptResult>
    private var trusted: HashSet<String>

    public init() {
        runner = ScriptRunner()
        results = ArrayList<ScriptResult>()
        trusted = HashSet<String>()
    }

    public init(trustedPackages: HashSet<String>) {
        runner = ScriptRunner()
        results = ArrayList<ScriptResult>()
        trusted = trustedPackages
    }

    /// 执行包的所有生命周期脚本
    /// 对应 Bun: Lockfile.Scripts 执行顺序
    /// 按固定顺序: preinstall, install, postinstall, preprepare, prepare, postprepare
    public func executeScripts(pkg: PackageInfo, pkgPath: String, rootDir: String): ArrayList<ScriptResult> {
        results.clear()

        // 构建环境
        runner.env = ScriptEnvironment.fromPackage(pkg.name, pkg.version.toString(), pkgPath, rootDir)

        // 检查是否可信
        let isTrusted = runner.isTrusted(pkg.name, trusted)

        // 按顺序执行脚本
        for (hookName in ScriptHooks.ALL) {
            match (pkg.scripts.get(hookName)) {
                case Some(script) => {
                    if (script.length == 0) { continue }

                    // 不可信的包只运行 install/postinstall
                    if (!isTrusted) {
                        if (hookName != ScriptHooks.INSTALL &&
                            hookName != ScriptHooks.POSTINSTALL) {
                            let r = ScriptResult(
                                hook: hookName,
                                exitCode: 0,
                                skipped: true,
                                output: "Skipped: package not in trustedDependencies"
                            )
                            results.append(r)
                            continue
                        }
                    }

                    // 执行脚本
                    let exitCode = runner.run(script, pkgPath)
                    let r = ScriptResult(
                        hook: hookName,
                        exitCode: exitCode,
                        skipped: false,
                        output: if (exitCode == 0) { "OK" } else { "Failed with exit code ${exitCode}" }
                    )
                    results.append(r)

                    // 非可选脚本失败则中断
                    if (exitCode != 0) {
                        break
                    }
                }
                case None => {}
            }
        }

        return results
    }

    /// 只执行 install/postinstall 脚本
    /// 对应 Bun: 不可信包的默认行为
    public func executeInstallScriptsOnly(pkg: PackageInfo, pkgPath: String, rootDir: String): ArrayList<ScriptResult> {
        results.clear()
        runner.env = ScriptEnvironment.fromPackage(pkg.name, pkg.version.toString(), pkgPath, rootDir)

        let installHooks = ArrayList<String>([ScriptHooks.INSTALL, ScriptHooks.POSTINSTALL])
        for (hookName in installHooks) {
            match (pkg.scripts.get(hookName)) {
                case Some(script) => {
                    if (script.length == 0) { continue }
                    let exitCode = runner.run(script, pkgPath)
                    results.append(ScriptResult(
                        hook: hookName,
                        exitCode: exitCode,
                        skipped: false,
                        output: ""
                    ))
                    if (exitCode != 0) { break }
                }
                case None => {}
            }
        }

        return results
    }

    /// 设置忽略脚本
    public func setIgnoreScripts(ignore: Bool): Unit {
        runner.ignoreScripts = ignore
    }

    /// 设置超时
    public func setTimeout(ms: Int64): Unit {
        runner.timeout = ms
    }

    /// 获取执行结果
    public func getResults(): ArrayList<ScriptResult> {
        return results
    }

    /// 是否所有脚本都成功
    public func allSucceeded(): Bool {
        for (r in results) {
            if (r.exitCode != 0 && !r.skipped) { return false }
        }
        return true
    }
}

// ============================================================================
// 脚本执行结果
// ============================================================================

/// 单个脚本执行结果
public class ScriptResult {
    /// 钩子名称
    public let hook: String
    /// 退出码 (0=成功)
    public let exitCode: Int64
    /// 是否跳过
    public let skipped: Bool
    /// 输出信息
    public var output: String

    public init(hook: String, exitCode: Int64, skipped: Bool, output: String) {
        this.hook = hook
        this.exitCode = exitCode
        this.skipped = skipped
        this.output = output
    }

    public func isOk(): Bool {
        return exitCode == 0
    }

    public func toString(): String {
        if (skipped) { return "[${hook}] skipped" }
        if (exitCode == 0) { return "[${hook}] OK" }
        return "[${hook}] FAILED (exit code ${exitCode})"
    }
}
