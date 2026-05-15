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
// 翻译自: Lockfile.Scripts.names
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
    /// 翻译自: Lockfile.Scripts.names 数组
    public static let ALL: ArrayList<String> = ArrayList<String>([
        "preinstall",
        "install",
        "postinstall",
        "preprepare",
        "prepare",
        "postprepare"
    ])

    /// 安装相关钩子 (用于不可信包)
    public static let INSTALL_ONLY: ArrayList<String> = ArrayList<String>([
        "install",
        "postinstall"
    ])
}

// ============================================================================
// 默认可信依赖
// 严格翻译自: src/install/default-trusted-dependencies.txt
//   Bun 维护一个默认可信依赖列表, 这些包的生命周期脚本可以自动执行
//   包括: esbuild, core-js, node-gyp, sharp, etc.
// ============================================================================

/// 默认可信依赖列表
/// 翻译自: src/install/default-trusted-dependencies.txt
public class DefaultTrustedDependencies {
    public static let PACKAGES: ArrayList<String> = ArrayList<String>([
        // 翻译自 default-trusted-dependencies.txt
        "core-js",
        "core-js-pure",
        "esbuild",
        "esbuild-android-64",
        "esbuild-android-arm64",
        "esbuild-darwin-64",
        "esbuild-darwin-arm64",
        "esbuild-freebsd-64",
        "esbuild-freebsd-arm64",
        "esbuild-linux-32",
        "esbuild-linux-64",
        "esbuild-linux-arm",
        "esbuild-linux-arm64",
        "esbuild-linux-mips64le",
        "esbuild-linux-ppc64le",
        "esbuild-linux-riscv64",
        "esbuild-linux-s390x",
        "esbuild-netbsd-64",
        "esbuild-openbsd-64",
        "esbuild-sunos-64",
        "esbuild-windows-32",
        "esbuild-windows-64",
        "esbuild-windows-arm64",
        "node-gyp",
        "node-gyp-build",
        "node-addon-api",
        "sharp",
        "@prisma/client",
        "@prisma/engines",
        "prisma",
        "better-sqlite3",
        "bcrypt",
        "bufferutil",
        "canvas",
        "curve25519-n",
        "dbus-next",
        "deasync",
        "ed25519",
        "farmhash",
        "fibers",
        "fsevents",
        "google-gax",
        "grpc",
        "heapdump",
        "ioctl",
        "libpq",
        "lzma-native",
        "mbwar",
        "nanomsg",
        "node-expat",
        "node-lmdb",
        "node-pty",
        "node-zookeeper-client",
        "pdh",
        "posix",
        "proton",
        "pty.js",
        "ptyw",
        "rcon",
        "saslprep",
        "semver",
        "serialport",
        "sleep",
        "sodium",
        "sodium-native",
        "spanw",
        "sqlite3",
        "syslog",
        "usb",
        "utf-8-validate",
        "winusb",
        "ws",
        "zmq",
        "zmq-proxy"
    ])

    /// 检查包名是否在默认可信列表中
    public static func isDefaultTrusted(name: String): Bool {
        for (pkg in PACKAGES) {
            if (pkg == name) { return true }
        }
        return false
    }
}

// ============================================================================
// 脚本环境变量
// 严格翻译自: src/install/lifecycle_script_runner.zig
//   Bun 设置 npm_package_* 环境变量和 PATH 供脚本使用
//   翻译自: LifecycleScriptSubprocess.envp 构建逻辑
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
    /// 是否前台模式
    public var foreground: Bool
    /// 是否可选脚本
    public var optional: Bool
    /// 额外环境变量
    public var extraEnv: HashMap<String, String>

    public init() {
        packageName = ""
        packageVersion = ""
        packagePath = ""
        rootDir = ""
        binPath = ""
        npmCommand = "install"
        foreground = false
        optional = false
        extraEnv = HashMap<String, String>()
    }

    /// 构建环境变量映射
    /// 对应 Bun: LifecycleScriptSubprocess 中设置的环境变量
    /// 翻译自: src/install/lifecycle_script_runner.zig spawnNextScript 中环境变量设置
    public func toEnvMap(): HashMap<String, String> {
        let env = HashMap<String, String>()

        // 继承当前环境 PATH
        // 翻译自: Bun 使用 inherited PATH + node_modules/.bin
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
        // 翻译自: Bun 设置 npm_package_name, npm_package_version 等
        env.put("npm_package_name", packageName)
        env.put("npm_package_version", packageVersion)
        env.put("npm_package_json", bao_path.PathModule.join(ArrayList<String>([packagePath, "package.json"])))
        env.put("npm_package_path", packagePath)

        // 项目根信息
        env.put("INIT_CWD", rootDir)
        env.put("npm_command", npmCommand)

        // node 相关
        // 翻译自: Bun 使用自身作为 NODE 替代
        env.put("NODE", "bao")

        // npm_config 前缀变量
        env.put("npm_config_node_gyp", bao_path.PathModule.join(ArrayList<String>([
            bao_sys.SysModule.getEnv("HOME").getOrElse(() => "/tmp"),
            ".bao", "install", "global", "node_modules", "node-gyp", "bin", "node-gyp.js"
        ])))

        // 额外环境变量
        for (key in extraEnv.keys()) {
            match (extraEnv.get(key)) {
                case Some(v) => env.put(key, v)
                case None => {}
            }
        }

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
//   翻译自: LifecycleScriptSubprocess.spawnNextScript
//   使用 shell -c 或 bun exec 执行命令
// ============================================================================

/// 脚本执行器 - 在子进程中运行生命周期脚本
/// 对应 Bun: LifecycleScriptSubprocess
public class ScriptRunner {
    /// 最大并行进程数
    /// 对应 Bun: Lockfile.Scripts.MAX_PARALLEL_PROCESSES = 10
    public static let MAX_PARALLEL: Int64 = 10

    /// 执行超时 (毫秒)
    /// 翻译自: LifecycleScriptSubprocess.timer / min_milliseconds_to_log = 500
    public var timeout: Int64
    /// 是否在前台运行 (显示输出)
    /// 翻译自: LifecycleScriptSubprocess.foreground
    public var foreground: Bool
    /// 是否忽略脚本 (对应 --ignore-scripts)
    public var ignoreScripts: Bool
    /// 环境变量
    public var env: ScriptEnvironment
    /// 输出捕获
    public var outputCapture: ScriptOutputCapture

    public init() {
        timeout = 60000  // 60秒
        foreground = false
        ignoreScripts = false
        env = ScriptEnvironment()
        outputCapture = ScriptOutputCapture()
    }

    /// 运行单个脚本命令
    /// 对应 Bun: LifecycleScriptSubprocess.spawnNextScript
    /// 翻译自: lifecycle_script_runner.zig 中 spawn + wait 逻辑
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
        // 翻译自: LifecycleScriptSubprocess 中 argv 构造
        //   argv = [shell_bin, "-c", combined_script, null] 或 [bun_exe, "exec", combined_script, null]
        let shell = bao_sys.SysModule.getEnv("SHELL").getOrElse(() => "/bin/sh")
        let args = ArrayList<String>([shell, "-c", command])

        // 清除输出缓冲区
        outputCapture.clear()

        // 使用 bao_sys 执行子进程
        let result = bao_sys.Process.run(
            command: args,
            cwd: cwd,
            env: envArgs,
            timeout: timeout
        )

        match (result) {
            case Some(exitCode) => {
                outputCapture.exitCode = exitCode
                return exitCode
            }
            case None => {
                outputCapture.exitCode = -1
                return -1
            }
        }
    }

    /// 检查命令是否安全执行
    /// 对应 Bun: trusted_dependencies 检查
    /// 翻译自: PackageManager 中 trustedDependencies 检查逻辑
    public func isTrusted(packageName: String, trustedList: HashSet<String>): Bool {
        // 通配符
        if (trustedList.contains("*")) { return true }
        // 精确匹配
        if (trustedList.contains(packageName)) { return true }
        // 默认可信列表
        if (DefaultTrustedDependencies.isDefaultTrusted(packageName)) { return true }
        return false
    }
}

/// 脚本输出捕获
/// 对应 Bun: LifecycleScriptSubprocess.stdout/stderr (OutputReader)
public class ScriptOutputCapture {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int64

    public init() {
        stdout = ""
        stderr = ""
        exitCode = 0
    }

    public func clear(): Unit {
        stdout = ""
        stderr = ""
        exitCode = 0
    }
}

// ============================================================================
// 生命周期脚本管理
// 严格翻译自: src/install/lifecycle_script_runner.zig + lockfile/Package/Scripts.zig
//   Bun 按固定顺序执行脚本: preinstall -> install -> postinstall
//   -> preprepare -> prepare -> postprepare
//   翻译自: LifecycleScriptSubprocess.List 和 Scripts 的执行逻辑
// ============================================================================

/// 生命周期脚本管理器
/// 对应 Bun: PackageManager 中执行 lifecycle scripts 的逻辑
public class LifecycleScripts {
    private var runner: ScriptRunner
    private var results: ArrayList<ScriptResult>
    /// 可信依赖列表 (package.json 中的 trustedDependencies)
    /// 翻译自: Lockfile.trusted_dependencies
    private var trusted: HashSet<String>
    /// 活跃脚本数 (用于并行控制)
    /// 翻译自: LifecycleScriptSubprocess.alive_count
    private var activeCount: Int64
    /// 脚本执行耗时记录
    /// 翻译自: PackageManager.lifecycle_script_time_log
    private var timeLog: ArrayList<ScriptTimeEntry>

    public init() {
        runner = ScriptRunner()
        results = ArrayList<ScriptResult>()
        trusted = HashSet<String>()
        activeCount = 0
        timeLog = ArrayList<ScriptTimeEntry>()
    }

    public init(trustedPackages: HashSet<String>) {
        runner = ScriptRunner()
        results = ArrayList<ScriptResult>()
        trusted = trustedPackages
        activeCount = 0
        timeLog = ArrayList<ScriptTimeEntry>()
    }

    /// 执行包的所有生命周期脚本
    /// 对应 Bun: Lockfile.Scripts 执行顺序
    /// 翻译自: LifecycleScriptSubprocess 中按 names 数组顺序执行
    /// 按固定顺序: preinstall, install, postinstall, preprepare, prepare, postprepare
    public func executeScripts(pkg: PackageInfo, pkgPath: String, rootDir: String): ArrayList<ScriptResult> {
        results.clear()

        // 构建环境
        runner.env = ScriptEnvironment.fromPackage(pkg.name, pkg.version.toString(), pkgPath, rootDir)

        // 检查是否可信
        let isTrustedPkg = runner.isTrusted(pkg.name, trusted)

        // 按顺序执行脚本
        for (hookName in ScriptHooks.ALL) {
            match (pkg.scripts.get(hookName)) {
                case Some(script) => {
                    if (script.length == 0) { continue }

                    // 不可信的包只运行 install/postinstall
                    // 翻译自: Bun 的 trustedDependencies 行为
                    //   不可信包的 preinstall, preprepare, prepare, postprepare 被跳过
                    if (!isTrustedPkg) {
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

                    // 记录开始时间
                    let startTime = bao_sys.SysModule.currentTimeMillis()

                    // 检查并行限制
                    // 翻译自: MAX_PARALLEL_PROCESSES
                    if (activeCount >= ScriptRunner.MAX_PARALLEL) {
                        // 等待其他脚本完成 (简化: 直接继续, 实际 Bun 使用队列)
                    }

                    activeCount += 1

                    // 执行脚本
                    let exitCode = runner.run(script, pkgPath)

                    activeCount -= 1

                    // 记录耗时
                    let elapsed = bao_sys.SysModule.currentTimeMillis() - startTime
                    // 翻译自: min_milliseconds_to_log = 500
                    if (elapsed > 500) {
                        timeLog.append(ScriptTimeEntry(
                            packageName: pkg.name,
                            hook: hookName,
                            elapsedMs: elapsed
                        ))
                    }

                    let r = ScriptResult(
                        hook: hookName,
                        exitCode: exitCode,
                        skipped: false,
                        output: if (exitCode == 0) { "OK (${elapsed}ms)" } else { "Failed with exit code ${exitCode} (${elapsed}ms)" }
                    )
                    results.append(r)

                    // 非可选脚本失败则中断
                    // 翻译自: LifecycleScriptSubprocess 中 handleExit 的错误处理
                    if (exitCode != 0) {
                        // 可选包的脚本失败不中断
                        if (!runner.env.optional) {
                            break
                        }
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

        for (hookName in ScriptHooks.INSTALL_ONLY) {
            match (pkg.scripts.get(hookName)) {
                case Some(script) => {
                    if (script.length == 0) { continue }
                    let startTime = bao_sys.SysModule.currentTimeMillis()
                    let exitCode = runner.run(script, pkgPath)
                    let elapsed = bao_sys.SysModule.currentTimeMillis() - startTime
                    results.append(ScriptResult(
                        hook: hookName,
                        exitCode: exitCode,
                        skipped: false,
                        output: if (exitCode == 0) { "OK (${elapsed}ms)" } else { "Failed (${elapsed}ms)" }
                    ))
                    if (exitCode != 0 && !runner.env.optional) { break }
                }
                case None => {}
            }
        }

        return results
    }

    /// 执行根包的生命周期脚本
    /// 翻译自: PackageManager.root_lifecycle_scripts
    public func executeRootScripts(scripts: HashMap<String, String>, rootDir: String): ArrayList<ScriptResult> {
        results.clear()
        runner.env = ScriptEnvironment.fromPackage("", "", rootDir, rootDir)
        runner.env.foreground = true

        for (hookName in ScriptHooks.ALL) {
            match (scripts.get(hookName)) {
                case Some(script) => {
                    if (script.length == 0) { continue }
                    let exitCode = runner.run(script, rootDir)
                    results.append(ScriptResult(
                        hook: hookName,
                        exitCode: exitCode,
                        skipped: false,
                        output: if (exitCode == 0) { "OK" } else { "Failed with exit code ${exitCode}" }
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

    /// 设置前台模式
    public func setForeground(fg: Bool): Unit {
        runner.foreground = fg
    }

    /// 添加可信依赖
    public func addTrusted(name: String): Unit {
        trusted.put(name)
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

    /// 获取耗时日志
    public func getTimeLog(): ArrayList<ScriptTimeEntry> {
        return timeLog
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

/// 脚本耗时条目
/// 翻译自: PackageManager.lifecycle_script_time_log
public class ScriptTimeEntry {
    public let packageName: String
    public let hook: String
    public let elapsedMs: Int64

    public init(packageName: String, hook: String, elapsedMs: Int64) {
        this.packageName = packageName
        this.hook = hook
        this.elapsedMs = elapsedMs
    }

    public func toString(): String {
        return "${packageName} ${hook}: ${elapsedMs}ms"
    }
}
