// 严格翻译自: src/cli/run_command.zig
// 脚本运行器核心逻辑
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*
import bao_runtime.shell.EnvMap
import bao_bundler.Transpiler
import bao_bundler.PackageJSON
import bao_bundler.Loader
import bao_resolver.DirInfo

/// 运行命令实现
public class RunCommand {
    /// 要搜索的 shell 列表
    static let SHELLS_TO_SEARCH: Array<String> = ["bash", "sh", "zsh"]

    /// 硬编码的 shell 路径
    static let HARDCODED_SHELLS: Array<String> = [
        "/bin/bash", "/usr/bin/bash", "/usr/local/bin/bash",
        "/bin/sh", "/usr/bin/sh",
        "/usr/bin/zsh", "/usr/local/bin/zsh",
        "/system/bin/sh"
    ]

    /// Bun 二进制名称
    static let BUN_BIN_NAME = if (false) { "bao-debug" } else { "bao" }

    /// Bun run 命令
    static let BUN_RUN = "${BUN_BIN_NAME} run"

    /// Bun x 命令
    static let BUN_X = "${BUN_BIN_NAME} x"

    /// 日志作用域
    static let log = "RUN: "  // TODO: Output.scoped

    /// Shell 缓存
    static var cachedShell: ?String = None
    static var cacheInitialized = false

    /// 查找 shell 实现
    static func findShellImpl(pathEnv: String, cwd: String): ?String {
        if (false) {
            return "C:\\Windows\\System32\\cmd.exe"
        }

        // TODO: implement which and isExecutable
        return None
    }

    /// 查找最佳 shell
    static func findShell(pathEnv: String, cwd: String): ?String {
        if (!cacheInitialized) {
            cachedShell = findShellImpl(pathEnv, cwd)
            cacheInitialized = true
        }

        return cachedShell
    }

    /// 替换包管理器运行命令
    ///
    /// 将 yarn run, pnpm run, npm run, npx 等替换为 bao run/bao x
    static func replacePackageManagerRun(script: String): String {
        // 简单字符串替换实现，避免逐字节处理
        var result = script

        // 替换 "yarn run " → "bao run "
        if (result.contains("yarn run ")) {
            result = result.replace("yarn run ", BUN_RUN + " ")
        }

        // 替换 "npm run " → "bao run "
        if (result.contains("npm run ")) {
            result = result.replace("npm run ", BUN_RUN + " ")
        }

        // 替换 "pnpm run " → "bao run "
        if (result.contains("pnpm run ")) {
            result = result.replace("pnpm run ", BUN_RUN + " ")
        }

        // 替换 "npx " → "bao x "
        if (result.contains("npx ")) {
            result = result.replace("npx ", BUN_X + " ")
        }

        // 替换 "pnpm dlx " → "bao x "
        if (result.contains("pnpm dlx ")) {
            result = result.replace("pnpm dlx ", BUN_X + " ")
        }

        // 替换 "pnpx " → "bao x "
        if (result.contains("pnpx ")) {
            result = result.replace("pnpx ", BUN_X + " ")
        }

        return result
    }

    /// 在前台运行包脚本
    public static func runPackageScriptForeground(
        ctx: CommandContext,
        allocator: Allocator,
        originalScript: String,
        name: String,
        cwd: String,
        env: EnvMap,
        passthrough: Array<String>,
        silent: Bool,
        useSystemShell: Bool
    ): Unit {
        let shellBinOpt = findShell("", cwd)  // TODO: env.get("PATH")
        if (shellBinOpt.isNone()) {
            if (!silent) {
                Output.prettyErrorln("<r><red>error:<r> Failed to find shell")
            }
            Global.exit(1)
            return
        }
        let shellBin = shellBinOpt.getOrThrow()

        // TODO: env.put("npm_lifecycle_event", name)
        // TODO: env.put("npm_lifecycle_script", originalScript)

        // 替换包管理器命令
        var copyScript = replacePackageManagerRun(originalScript)

        // 添加 passthrough 参数
        for (part in passthrough) {
            copyScript += " " + part
        }

        // log("Script: \"${copyScript}\"")

        if (!silent) {
            Output.command(copyScript)
            Output.flush()
        }

        if (!useSystemShell) {
            // 使用 Bao 内置 shell
            let code: Int64 = 0  // TODO: BaoShell.runFromSource(ctx, copyScript, cwd)
            if (code > 0) {
                if (code != 2 && !silent) {
                    Output.prettyErrorln("<r><red>error<r><d>:<r> script <b>\"${name}\"<r> exited with code ${code}<r>")
                    Output.flush()
                }
                Global.exit(Int32(code))
            }
            return
        }

        // 使用系统 shell
        let argv = [
            shellBin,
            if (false) { "/c" } else { "-c" },
            copyScript
        ]

        var spawnOpts = SpawnOptions()
        spawnOpts.args = argv
        spawnOpts.cwd = cwd
        spawnOpts.stderr = StdioConfig.Inherit
        spawnOpts.stdout = StdioConfig.Inherit
        spawnOpts.stdin = StdioConfig.Inherit
        // TODO: spawnOpts.env = env.toMap()

        // TODO: spawnSync(spawnOpts)
        let exitCode: Int64 = 0

        // TODO: handle spawn result status
        if (exitCode != 0) {
            if (exitCode != 2 && !silent) {
                Output.prettyErrorln("<r><red>error<r><d>:<r> script <b>\"${name}\"<r> exited with code ${exitCode}<r>")
                Output.flush()
            }
            Global.exit(Int32(exitCode))
        }
    }

    /// 运行二进制文件
    public static func runBinary(
        ctx: CommandContext,
        executable: String,
        cwd: String,
        env: EnvMap,
        passthrough: Array<String>,
        originalScript: ?String
    ): Unit {
        var argv = ArrayList<String>()
        argv.append(executable)
        for (p in passthrough) { argv.append(p) }

        var spawnOpts = SpawnOptions()
        let frozenArgv = argv
        spawnOpts.args = Array<String>(frozenArgv.size, {i => frozenArgv[i]})
        spawnOpts.cwd = cwd
        spawnOpts.stderr = StdioConfig.Inherit
        spawnOpts.stdout = StdioConfig.Inherit
        spawnOpts.stdin = StdioConfig.Inherit
        // TODO: spawnOpts.env = env.toMap()

        // TODO: spawnSync(spawnOpts)
        let exitCode: Int64 = 0

        // TODO: handle spawn result status
        if (exitCode != 0) {
            let basename = Path.basename(executable)
            if (exitCode > 0 && exitCode != 130) {
                Output.errGeneric("\"\${basename}\" exited with code \${exitCode}")
            } else {
                Output.prettyErrorln("<r><red>error:<r> Failed to run \"\${basename}\" due to exit code \${exitCode}<r>")
            }
            Global.exit(Int32(exitCode))
        }
    }

    /// 配置运行时的环境变量
    public static func configureEnvForRun(
        ctx: CommandContext,
        transpiler: Transpiler,
        env: ?EnvMap,
        logErrors: Bool,
        storeRootFd: Bool
    ): ?DirInfo {
        return configureEnvForRunWithOptions(ctx, transpiler, env, logErrors, storeRootFd, ConfigureEnvForRunOptions())
    }

    /// 配置运行时的环境变量（带选项）
    public static func configureEnvForRunWithOptions(
        ctx: CommandContext,
        transpiler: Transpiler,
        env: ?EnvMap,
        logErrors: Bool,
        storeRootFd: Bool,
        opts: ConfigureEnvForRunOptions
    ): ?DirInfo {
        // TODO: 初始化 transpiler
        // transpiler(ctx.allocator, ctx.log, ctx.args, env)
        // transpiler.options.env.behavior = DotEnvBehavior.loadAll
        // transpiler.env.quiet = true
        // transpiler.options.env.prefix = ""
        // transpiler.resolver.careAboutBinFolder = true
        // transpiler.resolver.careAboutScripts = true
        // transpiler.resolver.storeFd = storeRootFd
        // transpiler.resolver.opts.loadTsconfigJson = opts.loadTsconfigJson
        // transpiler.options.loadTsconfigJson = opts.loadTsconfigJson
        // transpiler.configureLinker()
        // let rootDirInfo = transpiler.resolver.readDirInfo(transpiler.fs.topLevelDir).getOrThrow()
        // transpiler.resolver.storeFd = false

        // TODO: if (env == None) {
        //     transpiler.env.loadProcess()
        //     if (let nodeEnv <- transpiler.env.get("NODE_ENV")) {
        //         if (nodeEnv == "production") { transpiler.options.production = true }
        //     }
        //     transpiler.runEnvLoader(true)
        // }

        // TODO: NODE_ENV check, env loading, package.json processing
        // TODO: return rootDirInfo
        return None  // TODO: placeholder
    }


    /// 配置 PATH 环境变量
    public static func configurePathForRun(
        ctx: CommandContext,
        rootDirInfo: DirInfo,
        transpiler: Transpiler,
        originalPath: ?String,
        cwd: String,
        forceUsingBao: Bool
    ): Unit {
        // TODO: 配置 PATH 环境变量
        ()
    }

    /// 使用 package.json 目录配置 PATH
    static func configurePathForRunWithPackageJsonDir(
        ctx: CommandContext,
        packageJsonDir: String,
        transpiler: Transpiler,
        originalPath: ?String,
        cwd: String,
        forceUsingBao: Bool
    ): String {
        // TODO: 完整的 PATH 配置逻辑
        return originalPath ?? ""
    }

    /// 执行 run 命令
    public static func exec(
        ctx: CommandContext,
        cfg: ExecConfig
    ): Bool {
        // TODO: 完整的 run 命令实现
        if (ctx.positionals.isEmpty()) {
            printHelp(Option<PackageJSON>.None)
            return true
        }
        Output.prettyln("bao run - not yet fully implemented")
        return false
    }

    /// 以 Node 模式执行
    public static func execAsIfNode(ctx: CommandContext): Unit {
        // TODO: Node 模式执行
        Output.prettyln("bao --eval - not yet fully implemented")
    }

    /// 启动并处理错误
    static func bootAndHandleError(ctx: CommandContext, path: String, loader: ?Loader): Bool {
        // TODO: 启动运行时并处理错误
        // Run.boot(ctx, path, loader)
        Output.prettyln("Running: ${path}")
        return true
    }

    /// 检查是否为 TypeScript
    static func isTypeScript(targetName: String): Bool {
        // TODO: 检测 TypeScript 扩展名
        return targetName.endsWith(".ts") || targetName.endsWith(".tsx")
    }

    /// 尝试用 BaoJS 打开
    static func maybeOpenWithBaoJS(ctx: CommandContext): Bool {
        // TODO: 实现快速路径检测
        return false
    }

    /// 打印帮助信息
    public static func printHelp(packageJson: ?PackageJSON): Unit {
        Output.pretty("<b>Usage<r>: <b><green>bao run<r> <cyan>[flags]<r> \\<file or script\\>\\n\\n")
        Output.pretty("<b>Examples:<r>\\n")
        Output.pretty("  <b><green>bao run<r> <blue>./index.js<r>\\n")
        Output.pretty("  <b><green>bao run<r> <blue>./index.tsx<r>\\n")
        Output.pretty("  <b><green>bao run<r> <blue>dev<r>\\n")
        Output.flush()
    }

    /// 列出可用脚本
    public static func ls(ctx: CommandContext): Bool {
        Output.prettyln("bao run --list - not yet fully implemented")
        return false
    }
}
/// 配置选项
public class ConfigureEnvForRunOptions {
    let loadTsconfigJson: Bool

    public init() {
        this.loadTsconfigJson = true
    }

    public init(loadTsconfigJson: Bool) {
        this.loadTsconfigJson = loadTsconfigJson
    }
}

/// 执行配置
public class ExecConfig {
    let binDirsOnly: Bool
    let logErrors: Bool
    let allowFastRunForExtensions: Bool

    public init() {
        this.binDirsOnly = false
        this.logErrors = false
        this.allowFastRunForExtensions = false
    }

    public init(binDirsOnly: Bool, logErrors: Bool, allowFastRunForExtensions: Bool) {
        this.binDirsOnly = binDirsOnly
        this.logErrors = logErrors
        this.allowFastRunForExtensions = allowFastRunForExtensions
    }
}

/// Bun X 快速路径（Windows）
class BunXFastPath {
    static var directLaunchBuffer = Array<UInt8>(4096, {_ => 0})
    static var environmentBuffer = Array<UInt8>(4096, {_ => 0})

    /// 尝试启动
    static func tryLaunch(
        ctx: CommandContext,
        pathToUse: String,
        env: EnvMap,
        passthrough: Array<String>
    ): Unit {
        // TODO: 实现 Windows 快速路径
    }

    /// 直接启动回调
    static func directLaunchCallback(wpath: String, ctx: CommandContext): Unit {
        // TODO: 实现回调
    }
}
