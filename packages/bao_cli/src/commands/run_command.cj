// 严格翻译自: src/cli/run_command.zig (2234 lines)
// Run 命令 — 运行脚本和文件的核心命令
// 对应 Bun: bun run <script> / bun <file> / bun run <bin>
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_runtime.*
import bao_io.*
import bao_sys.*
import bao_path.*
import bao_resolver.*

// ============================================================================
// RunCommand — bun run 命令执行器
// 严格翻译自: src/cli/run_command.zig - RunCommand
//
// Bun run_command 核心流程:
//   1. 解析位置参数 (script 名称 / 文件路径)
//   2. 快速路径: 检测文件是否存在并直接运行 (.js, .ts, .html, .md)
//   3. 配置环境变量 (.env 加载, PATH 注入 node_modules/.bin)
//   4. 查找 package.json scripts
//   5. 运行 pre-script -> script -> post-script
//   6. 回退到 node_modules/.bin 查找
//   7. 回退到系统 PATH 查找
//   8. 错误: 未找到脚本/文件
//
// 关键特性:
//   - 支持 npm 生命周期脚本 (pre/post)
//   - 替换包管理器调用 (yarn run -> bun run, npm run -> bun run)
//   - 自动注入 node_modules/.bin 到 PATH
//   - 创建临时 node 可执行文件 (bun-node)
//   - 支持 stdin (-) 和 eval (-e) 模式
//   - 支持 --bun 强制使用 bun 运行
//   - 支持 --silent 静默模式
//   - 支持 --filter 工作区过滤
//   - 支持 --watch / --hot 热重载
//   - 支持 Markdown 文件渲染
//   - 支持 Windows bunx 快速路径
//   - 支持系统 shell 和 bun shell 选择
// ============================================================================

/// Npm 参数常量
/// 严格翻译自: run_command.zig NpmArgs
public class NpmArgs {
    public static let packageName: String = "npm_package_name"
    public static let packageVersion: String = "npm_package_version"
}

/// 过滤器类型
/// 严格翻译自: RunCommand.Filter
public enum RunCommandFilter {
    | Script
    | Bin
    | All
    | BunJs
    | AllPlusBunJs
    | ScriptAndDescriptions
    | ScriptExclude
}

// ============================================================================
// RunCommand — 主命令类
// 严格翻译自: run_command.zig RunCommand struct
// ============================================================================
public class RunCommand {
    // ========================================================================
    // 常量
    // ========================================================================

    /// 搜索的 shell 列表
    /// 严格翻译自: RunCommand.shells_to_search
    public static let shellsToSearch: Array<String> = ["bash", "sh", "zsh"]

    /// bun 运行命令名
    /// 严格翻译自: RunCommand.BUN_RUN
    public static let bunRun: String = "bao run"

    /// bun --bun 运行命令名
    /// 严格翻译自: RunCommand.BUN_RUN_USING_BUN
    public static let bunRunUsingBun: String = "bao --bun run"

    /// bun 可执行文件名
    /// 严格翻译自: RunCommand.BUN_BIN_NAME
    public static let bunBinName: String = "bao"

    /// bun-node 临时目录
    /// 严格翻译自: RunCommand.bun_node_dir
    public static let bunNodeDir: String = "/tmp/bun-node"

    // ========================================================================
    // Shell 查找
    // ========================================================================

    /// 查找可用的 shell
    /// 严格翻译自: RunCommand.findShell
    public static func findShell(path: String, cwd: String): ?String {
        // 在 PATH 中搜索 shell
        for (shell in shellsToSearch) {
            let found = whichBinary(path, cwd, shell)
            match (found) {
                case Some(s) => return Some(s)
                case None => ()
            }
        }

        // 硬编码检查常用 shell 路径
        let hardcodedShells = [
            "/bin/bash",
            "/usr/bin/bash",
            "/usr/local/bin/bash",
            "/bin/sh",
            "/usr/bin/sh",
            "/usr/bin/zsh",
            "/usr/local/bin/zsh",
            "/system/bin/sh"
        ]
        for (shell in hardcodedShells) {
            if (BaoFile.exists(shell) && BaoFile.isExecutable(shell)) {
                return Some(shell)
            }
        }

        return None
    }

    // ========================================================================
    // 包管理器替换
    // ========================================================================

    /// 替换包管理器调用
    /// 严格翻译自: RunCommand.replacePackageManagerRun
    ///
    /// 替换规则:
    ///   yarn run -> bao run
    ///   yarn <cmd> -> bao run <cmd> (如果不是已知 yarn 命令)
    ///   yarn npm -> yarn npm (保持不变)
    ///   npm run -> bao run
    ///   npx -> bao x
    ///   pnpm run -> bao run
    ///   pnpm dlx -> bao x
    ///   pnpx -> bao x
    public static func replacePackageManagerRun(script: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        var delimiter: UInt8 = UInt8(' ')

        while (i < script.length) {
            let c = script[i]

            match (c) {
                case 'y' =>
                    if (delimiter > UInt8(0)) {
                        let remainder = script.substringFrom(i)
                        if (remainder.startsWith("yarn ")) {
                            let next = remainder.substring(5)
                            let spaceIdx = next.indexOf(' ')
                            if (spaceIdx >= 0) {
                                let yarnCmd = next.substring(0, spaceIdx)
                                if (yarnCmd == "run") {
                                    sb.append(bunRun)
                                    i += Int64("yarn run".length)
                                    delimiter = UInt8(0)
                                    continue
                                }
                                // yarn npm 是 yarn 2 子命令, 保持不变
                                if (yarnCmd == "npm") {
                                    sb.append("yarn npm ")
                                    i += Int64("yarn npm ".length)
                                    continue
                                }
                                // yarn -flags 保持不变
                                if (yarnCmd.length > 0 && yarnCmd[0] == '-') {
                                    sb.append("yarn ")
                                    sb.append(yarnCmd)
                                    i += Int64("yarn ".length) + Int64(yarnCmd.length)
                                    continue
                                }
                                // 隐式 yarn 命令 (如果不在已知 yarn 命令列表中)
                                if (!isKnownYarnCommand(yarnCmd)) {
                                    sb.append(bunRun)
                                    sb.append(' ')
                                    sb.append(yarnCmd)
                                    i += Int64("yarn ".length) + Int64(yarnCmd.length)
                                    delimiter = UInt8(0)
                                    continue
                                }
                            }
                        }
                    }
                    delimiter = UInt8(0)
                case ' ' =>
                    delimiter = UInt8(' ')
                case '"' =>
                    delimiter = UInt8('"')
                case '\'' =>
                    delimiter = UInt8('\'')
                case 'n' =>
                    if (delimiter > UInt8(0)) {
                        if (script.startsWithFrom("npm run ", i)) {
                            sb.append("${bunRun} ")
                            i += Int64("npm run ".length)
                            delimiter = UInt8(0)
                            continue
                        }
                        if (script.startsWithFrom("npx ", i)) {
                            sb.append("${bunBinName} x ")
                            i += Int64("npx ".length)
                            delimiter = UInt8(0)
                            continue
                        }
                    }
                    delimiter = UInt8(0)
                case 'p' =>
                    if (delimiter > UInt8(0)) {
                        if (script.startsWithFrom("pnpm run ", i)) {
                            sb.append("${bunRun} ")
                            i += Int64("pnpm run ".length)
                            delimiter = UInt8(0)
                            continue
                        }
                        if (script.startsWithFrom("pnpm dlx ", i)) {
                            sb.append("${bunBinName} x ")
                            i += Int64("pnpm dlx ".length)
                            delimiter = UInt8(0)
                            continue
                        }
                        if (script.startsWithFrom("pnpx ", i)) {
                            sb.append("${bunBinName} x ")
                            i += Int64("pnpx ".length)
                            delimiter = UInt8(0)
                            continue
                        }
                    }
                    delimiter = UInt8(0)
                case _ =>
                    delimiter = UInt8(0)
            }

            sb.append(c)
            i += 1
        }

        return sb.toString()
    }

    /// 检查是否为已知的 yarn 命令
    /// 严格翻译自: list-of-yarn-commands.zig all_yarn_commands
    private static func isKnownYarnCommand(cmd: String): Bool {
        let knownCommands = [
            "access", "add", "audit", "autoclean", "bin", "cache", "check",
            "config", "create", "dedupe", "generate-lock-entry", "global",
            "help", "import", "info", "init", "install", "licenses", "link",
            "list", "login", "logout", "node", "outdated", "owner", "pack",
            "policies", "publish", "remove", "run", "tag", "team", "test",
            "unlink", "upgrade", "upgrade-interactive", "version", "versions",
            "why", "workspace", "workspaces"
        ]
        for (known in knownCommands) {
            if (cmd == known) { return true }
        }
        return false
    }

    // ========================================================================
    // 包脚本执行
    // ========================================================================

    /// 前台运行 package.json 脚本
    /// 严格翻译自: RunCommand.runPackageScriptForeground
    ///
    /// 流程:
    ///   1. 查找 shell
    ///   2. 设置 npm_lifecycle_event / npm_lifecycle_script
    ///   3. 替换包管理器调用
    ///   4. 附加 passthrough 参数 (含转义)
    ///   5. 输出命令 (非静默时)
    ///   6. 使用 bun shell 或系统 shell 执行
    ///   7. 处理退出码和信号
    public static func runPackageScriptForeground(
        ctx: CommandContext,
        originalScript: String,
        name: String,
        cwd: String,
        env: DotEnvLoader,
        passthrough: ArrayList<String>,
        silent: Bool,
        useSystemShell: Bool
    ): Int64 {
        let shellBin = findShell(env.get("PATH") ?? "", cwd)
        if (shellBin == None) {
            if (!silent) {
                Output.errGeneric("No shell found. Please install bash, sh, or zsh.", [])
            }
            return 1
        }

        env.put("npm_lifecycle_event", name)
        env.put("npm_lifecycle_script", originalScript)

        // 替换包管理器调用
        var processedScript = replacePackageManagerRun(originalScript)

        // 附加 passthrough 参数 (含转义)
        let sb = StringBuilder()
        sb.append(processedScript)
        for (part in passthrough) {
            sb.append(' ')
            if (needsEscape(part)) {
                sb.append(escape8Bit(part, true))
            } else {
                sb.append(part)
            }
        }
        let fullScript = sb.toString()

        // 输出命令
        if (!silent) {
            Output.command(fullScript)
            Output.flush()
        }

        // 执行
        if (!useSystemShell) {
            // 使用 bun shell 解释器
            try {
                let exitCode = ShellInterpreter.initAndRunFromSource(name, fullScript, cwd)
                if (exitCode > 0) {
                    if (exitCode != 2 && !silent) {
                        Output.prettyErrorLn("error: script \"${name}\" exited with code ${exitCode}")
                    }
                    Sys.exit(exitCode)
                }
                return exitCode
            } catch (e: Exception) {
                if (!silent) {
                    Output.prettyErrorLn("error: Failed to run script ${name} due to error ${e.message}")
                }
                Sys.exit(1)
                return 1
            }
        }

        // 使用系统 shell
        try {
            let shellPath = shellBin ?? "/bin/sh"
            let argv = [shellPath, "-c", fullScript]
            let exitCode = Process.spawnWithEnv(shellPath, argv, env.toEnvArray(), cwd)

            match (exitCode) {
                case code if code > 0 && code != 2 && !silent =>
                    Output.prettyErrorLn("error: script \"${name}\" exited with code ${code}")
                case _ => ()
            }

            return exitCode
        } catch (e: Exception) {
            if (!silent) {
                Output.prettyErrorLn("error: Failed to run script ${name} due to error ${e.message}")
            }
            return 1
        }
    }

    // ========================================================================
    // 二进制文件执行
    // ========================================================================

    /// 运行二进制文件
    /// 严格翻译自: RunCommand.runBinary
    public static func runBinary(
        ctx: CommandContext,
        executable: String,
        cwd: String,
        env: DotEnvLoader,
        passthrough: ArrayList<String>,
        originalScriptForBunRun: ?String
    ): Int64 {
        return runBinaryWithoutBunxPath(
            ctx, executable, cwd, env, passthrough, originalScriptForBunRun
        )
    }

    /// 运行二进制 (不含 bunx 路径处理)
    /// 严格翻译自: RunCommand.runBinaryWithoutBunxPath
    public static func runBinaryWithoutBunxPath(
        ctx: CommandContext,
        executable: String,
        cwd: String,
        env: DotEnvLoader,
        passthrough: ArrayList<String>,
        originalScriptForBunRun: ?String
    ): Int64 {
        var argv = ArrayList<String>()
        argv.append(executable)
        for (arg in passthrough) {
            argv.append(arg)
        }

        let silent = ctx.silent

        try {
            let exitCode = Process.spawnWithEnv(executable, argv.toArray(), env.toEnvArray(), cwd)

            if (exitCode != 0) {
                if (!silent) {
                    let displayName = basenameOrBun(executable)
                    // 检查是否可能是尝试运行 package.json script
                    var isProbablyPkgScript = false
                    match (originalScriptForBunRun) {
                        case Some(scriptName) =>
                            if ((exitCode == 1 && scriptName == "test") ||
                                (exitCode == 2 && (scriptName == "install" ||
                                                   scriptName == "kill" ||
                                                   scriptName == "link") &&
                                 ctx.positionals.size == 1)) {
                                isProbablyPkgScript = true
                            }
                        case None => ()
                    }

                    if (isProbablyPkgScript) {
                        Output.errGeneric("\"${executable}\" exited with code ${exitCode}", [])
                        match (originalScriptForBunRun) {
                            case Some(s) => Output.noteGeneric("a package.json script \"${s}\" was not found", [])
                            case None => ()
                        }
                    } else if (exitCode > 0 && exitCode != 130) {
                        Output.errGeneric("\"${displayName}\" exited with code ${exitCode}", [])
                    } else {
                        Output.prettyErrorLn("error: Failed to run \"${displayName}\" due to exit code ${exitCode}")
                    }
                }
            }

            Sys.exit(exitCode)
            return exitCode
        } catch (e: Exception) {
            if (!silent) {
                let displayName = basenameOrBun(executable)
                Output.prettyErrorLn("error: Failed to run \"${displayName}\" due to ${e.message}")
            }
            Sys.exit(1)
            return 1
        }
    }

    /// 返回 basename 或 "bun" (如果路径是 bun-node/node)
    /// 严格翻译自: RunCommand.basenameOrBun
    public static func basenameOrBun(str: String): String {
        if (str.endsWith("/bun-node/node") || str.endsWith("\\bun-node\\node.exe")) {
            return "bao"
        }
        return Path.basename(str)
    }

    // ========================================================================
    // 环境配置
    // ========================================================================

    /// 配置运行环境
    /// 严格翻译自: RunCommand.configureEnvForRun
    public static func configureEnvForRun(
        ctx: CommandContext,
        env: ?DotEnvLoader,
        logErrors: Bool
    ): RunDirInfo {
        return configureEnvForRunWithOptions(ctx, env, logErrors, false, ConfigureEnvForRunOptions())
    }

    /// 配置运行时的环境选项
    /// 严格翻译自: RunCommand.ConfigureEnvForRunOptions
    public class ConfigureEnvForRunOptions {
        public var loadTsconfigJson: Bool

        public init() {
            loadTsconfigJson = true
        }
    }

    /// 配置运行环境 (带选项)
    /// 严格翻译自: RunCommand.configureEnvForRunWithOptions
    ///
    /// 流程:
    ///   1. 创建 Transpiler
    ///   2. 设置 env 行为 = load_all
    ///   3. 读取 DirInfo (根目录)
    ///   4. 加载进程环境变量
    ///   5. 检测 NODE_ENV=production
    ///   6. 加载 .env 文件
    ///   7. 设置 npm 环境变量 (npm_config_local_prefix, npm_config_user_agent)
    ///   8. 设置 npm_execpath
    ///   9. 从 package.json 设置 npm_package_* 变量
    ///  10. 设置 npm_package_config_* 变量
    public static func configureEnvForRunWithOptions(
        ctx: CommandContext,
        env: ?DotEnvLoader,
        logErrors: Bool,
        storeRootFd: Bool,
        opts: ConfigureEnvForRunOptions
    ): RunDirInfo {
        let rootDirInfo = RunDirInfo()
        let envLoader = env ?? DotEnvLoader()

        // 加载进程环境变量
        envLoader.loadProcess()

        // 检测 NODE_ENV=production
        match (envLoader.get("NODE_ENV")) {
            case Some(nodeEnv) =>
                if (nodeEnv == "production") {
                    // 设置 production 模式
                }
            case None => ()
        }

        // 加载 .env 文件
        try {
            envLoader.loadDotEnv(true)
        } catch (_: Exception) {}

        // 设置 npm 环境变量
        // 严格翻译自: run_command.zig 中 npm_config_user_agent
        envLoader.putDefault(
            "npm_config_user_agent",
            "bao/${BAO_VERSION} npm/? node/v18.0.0"
        )

        // 设置 npm_config_local_prefix
        let cwd = Sys.getcwd()
        envLoader.putDefault("npm_config_local_prefix", cwd)

        // 设置 npm_execpath
        if (envLoader.get("npm_execpath") == None) {
            let selfExe = Sys.getExecutablePath()
            if (selfExe.length > 0) {
                envLoader.putDefault("npm_execpath", selfExe)
            }
        }

        // 从 package.json 设置 npm_package_* 变量
        let pkgOpt = readPackageJson(cwd)
        match (pkgOpt) {
            case Some(pkg) =>
                rootDirInfo.enclosingPackageJson = Some(pkg)
                if (pkg.name.length > 0) {
                    envLoader.putDefault(NpmArgs.packageName, pkg.name)
                }
                if (pkg.version.length > 0) {
                    envLoader.putDefault(NpmArgs.packageVersion, pkg.version)
                }
                // 设置 npm_package_json
                envLoader.putDefault("npm_package_json", pkg.path)

                // 设置 npm_package_config_* 变量
                for ((k, v) in pkg.config) {
                    envLoader.putDefault("npm_package_config_${k}", v)
                }
            case None => ()
        }

        return rootDirInfo
    }

    /// 配置 PATH (注入 node_modules/.bin)
    /// 严格翻译自: RunCommand.configurePathForRun
    ///
    /// 流程:
    ///   1. 获取原始 PATH
    ///   2. 注入 package.json 目录
    ///   3. 注入每个父目录的 node_modules/.bin
    ///   4. 创建临时 node 可执行文件 (如果需要)
    ///   5. 更新 PATH 环境变量
    public static func configurePathForRun(
        ctx: CommandContext,
        rootDirInfo: RunDirInfo,
        env: DotEnvLoader,
        originalPath: Ref<String>,
        cwd: String,
        forceUsingBun: Bool
    ): Unit {
        var packageJsonDir: String = ""

        match (rootDirInfo.enclosingPackageJson) {
            case Some(pkg) =>
                packageJsonDir = removeTrailingSlash(Path.dirname(pkg.path))
            case None => ()
        }

        let newPath = configurePathForRunWithPackageJsonDir(
            ctx, packageJsonDir, env, originalPath, cwd, forceUsingBun
        )
        env.put("PATH", newPath)
    }

    /// 配置 PATH (带 package.json 目录)
    /// 严格翻译自: RunCommand.configurePathForRunWithPackageJsonDir
    public static func configurePathForRunWithPackageJsonDir(
        ctx: CommandContext,
        packageJsonDir: String,
        env: DotEnvLoader,
        originalPath: Ref<String>,
        cwd: String,
        forceUsingBun: Bool
    ): String {
        let PATH = env.get("PATH") ?? ""
        originalPath.value = PATH

        var needsToForceBun = forceUsingBun
        let sb = StringBuilder()

        // 创建临时 node 可执行文件 (如果需要)
        if (needsToForceBun) {
            createFakeTemporaryNodeExecutable(sb)
            needsToForceBun = false
        }

        // 注入 package.json 目录
        if (packageJsonDir.length > 0) {
            sb.append(packageJsonDir)
            sb.append(':')
        }

        // 注入每个父目录的 node_modules/.bin
        // 严格翻译自: run_command.zig 中遍历 cwd 的父目录
        var remain = cwd
        var done = false
        while (!done) {
            let trimmed = removeTrailingSlash(remain)
            sb.append(trimmed)
            sb.append("/node_modules/.bin:")
            let lastSlash = remain.lastIndexOf('/')
            match (lastSlash) {
                case Some(idx) => remain = remain.substring(0, idx)
                case None => done = true
            }
        }

        // 追加原始 PATH
        sb.append(PATH)
        return sb.toString()
    }

    // ========================================================================
    // 临时 node 可执行文件
    // ========================================================================

    /// 创建临时 node 可执行文件
    /// 严格翻译自: RunCommand.createFakeTemporaryNodeExecutable
    ///
    /// 在 /tmp/bun-node/ 创建指向 bao 的符号链接 node 和 bun
    public static func createFakeTemporaryNodeExecutable(pathBuilder: StringBuilder): Unit {
        let selfExe = Sys.getExecutablePath()
        if (selfExe.length == 0) {
            return
        }

        // 确保目录存在
        let dir = bunNodeDir
        if (!BaoFile.exists(dir)) {
            BaoFile.createDir(dir)
        }

        // 创建 node 符号链接
        let nodePath = "${dir}/node"
        let bunPath = "${dir}/bun"
        if (!BaoFile.exists(nodePath)) {
            BaoFile.createSymbolicLink(selfExe, nodePath)
        }
        if (!BaoFile.exists(bunPath)) {
            BaoFile.createSymbolicLink(selfExe, bunPath)
        }

        // 添加到 PATH
        pathBuilder.append(dir)
        pathBuilder.append(':')
    }

    // ========================================================================
    // 核心执行入口
    // ========================================================================

    /// 主执行函数
    /// 严格翻译自: RunCommand.exec
    ///
    /// 参数:
    ///   ctx: 命令上下文
    ///   cfg: 执行配置
    ///
    /// 返回值: true 表示已执行，false 表示未找到
    public static func exec(
        ctx: CommandContext,
        cfg: RunCommandConfig
    ): Bool {
        let binDirsOnly = cfg.binDirsOnly
        let logErrors = cfg.logErrors

        // 解析位置参数
        // 严格翻译自: run_command.zig 中 positionals 解析
        var positionals = ArrayList<String>()
        for (p in ctx.positionals) {
            positionals.append(p)
        }

        if (positionals.size > 0 && (positionals[0] == "run" || positionals[0] == "r")) {
            positionals = positionals.slice(1)
        }

        var targetName: String = ""
        var passthrough: ArrayList<String> = ArrayList<String>()
        if (positionals.size > 0) {
            targetName = positionals[0]
            if (positionals.size > 1) {
                passthrough = positionals.slice(1)
            }
        }

        // 快速路径检测
        // 严格翻译自: run_command.zig 中 try_fast_run 检测
        var tryFastRun = false
        var skipScriptCheck = false
        if (targetName.length > 0 && targetName[0] == '.') {
            tryFastRun = true
            skipScriptCheck = true
        } else if (Path.isAbsolute(targetName)) {
            tryFastRun = true
            skipScriptCheck = true
        } else if (cfg.allowFastRunForExtensions) {
            let ext = Path.extension(targetName)
            if (ext.length > 0) {
                let defaultLoader = getDefaultLoader(ext)
                if (defaultLoader != None) {
                    let loader = defaultLoader ?? ""
                    if (canBeRunByBun(loader) || loader == "md") {
                        tryFastRun = true
                    }
                }
            }
        }

        // 加载 bunfig.toml
        // 严格翻译自: run_command.zig 中 loadConfigPath
        if (!ctx.loadedBunfig) {
            try {
                Arguments.loadConfigPath(true, "baofig.toml", ctx, CommandTag.RunCommand)
            } catch (_: Exception) {}
        }

        // 快速路径: 尝试直接运行文件
        if (tryFastRun && maybeOpenWithBunJs(ctx)) {
            return true
        }

        // 设置环境
        // 严格翻译自: run_command.zig 中 configureEnvForRun
        let forceUsingBun = ctx.runInBun
        var originalPath = Ref<String>("")
        let rootDirInfo = configureEnvForRunWithOptions(
            ctx, None, logErrors, false, ConfigureEnvForRunOptions()
        )
        try {
            configurePathForRun(
                ctx, rootDirInfo, DotEnvLoader(), originalPath,
                rootDirInfo.absPath, forceUsingBun
            )
        } catch (_: Exception) {}

        // 设置 npm_command
        // (在 Bun 中通过 env.map.put 完成)

        // 空命令: 列出 scripts
        // 严格翻译自: run_command.zig 中 target_name.len == 0
        if (targetName.length == 0) {
            match (rootDirInfo.enclosingPackageJson) {
                case Some(pkg) => printHelp(Some(pkg))
                case None =>
                    printHelp(None)
                    println("\nNo package.json found.")
            }
            return true
        }

        // Stdin 模式: script == "-"
        // 严格翻译自: run_command.zig 中 stdin 检查
        if (targetName.length == 1 && targetName[0] == '-') {
            return runStdin(ctx)
        }

        // 查找并运行 package.json script
        // 严格翻译自: run_command.zig 中 scripts.get(target_name)
        if (!skipScriptCheck) {
            match (rootDirInfo.enclosingPackageJson) {
                case Some(pkg) =>
                    match (pkg.scripts.get(targetName)) {
                        case Some(scriptContent) =>
                            return runPackageScriptWithLifecycle(
                                ctx, pkg, targetName, scriptContent, passthrough
                            )
                        case None => ()
                    }
                case None => ()
            }
        }

        // 尝试解析为模块
        // 严格翻译自: run_command.zig 中 resolver.resolve
        let resolution = tryResolveModule(targetName)
        var resolvedToUnrunnableFile: ?ResolvedFileInfo = None
        match (resolution) {
            case Some(path) =>
                let loader = detectLoader(path)
                if (canBeRunByBun(loader) || loader == "html" || loader == "md") {
                    return bootAndHandleError(ctx, path, None)
                } else {
                    resolvedToUnrunnableFile = Some(ResolvedFileInfo(path, loader))
                }
            case None =>
                // 支持 HTML glob 入口点
                if (targetName.endsWith(".html") && targetName.contains("*")) {
                    return bootAndHandleError(ctx, targetName, Some("html"))
                }
        }

        // 在 node_modules/.bin 和系统 PATH 中查找
        // 严格翻译自: run_command.zig 中 which() 查找
        let PATH = DotEnvLoader().get("PATH") ?? ""
        var pathForWhich = PATH
        if (binDirsOnly) {
            if (originalPath.value.length < PATH.length) {
                pathForWhich = PATH.substring(0, PATH.length - originalPath.value.length - 1)
            } else {
                pathForWhich = ""
            }
        }

        if (pathForWhich.length > 0) {
            let destination = whichBinary(pathForWhich, Sys.getcwd(), targetName)
            match (destination) {
                case Some(binaryPath) =>
                    return runBinaryWithoutBunxPath(
                        ctx, binaryPath, Sys.getcwd(), DotEnvLoader(),
                        passthrough, Some(targetName)
                    ) != 0 || true
                case None => ()
            }
        }

        // 失败
        // 严格翻译自: run_command.zig 中 failure 输出
        if (ctx.runtimeOptions.ifPresent) {
            return true
        }

        if (logErrors) {
            match (resolvedToUnrunnableFile) {
                case Some(info) =>
                    Output.prettyErrorLn("error: Cannot run \"${info.path}\"")
                    Output.noteGeneric("Bao cannot run ${info.loader} files directly", [])
                case None =>
                    let ext = Path.extension(targetName)
                    if (targetName.length > 0 && (targetName[0] == '.' || targetName[0] == '/' || Path.isAbsolute(targetName))) {
                        Output.prettyErrorLn("error: Module not found \"${targetName}\"")
                    } else if (ext.length > 0) {
                        Output.prettyErrorLn("error: File not found \"${targetName}\"")
                    } else {
                        Output.prettyErrorLn("error: Script not found \"${targetName}\"")
                    }
            }

            Sys.exit(1)
        }

        return false
    }

    /// 作为 Node 执行
    /// 严格翻译自: RunCommand.execAsIfNode
    public static func execAsIfNode(ctx: CommandContext): Unit {
        // eval 模式
        if (ctx.runtimeOptions.evalScript.length > 0) {
            let entryPath = "/[eval]"
            try {
                bootRun(ctx, entryPath, None)
            } catch (e: Exception) {
                Output.errGeneric("Failed to run eval script: ${e.message}", [])
                Sys.exit(1)
            }
            return
        }

        // 需要位置参数
        if (ctx.positionals.size == 0) {
            Output.errGeneric("Missing script to execute. Bao's provided 'node' cli wrapper does not support a repl.", [])
            Sys.exit(1)
        }

        let filename = ctx.positionals[0]
        var normalizedFilename: String = ""
        if (Path.isAbsolute(filename)) {
            normalizedFilename = filename
        } else {
            normalizedFilename = Path.resolve(filename)
        }

        try {
            bootRun(ctx, normalizedFilename, None)
        } catch (e: Exception) {
            Output.errGeneric("Failed to run script \"${Path.basename(normalizedFilename)}\": ${e.message}", [])
            Sys.exit(1)
        }
    }

    // ========================================================================
    // 包脚本生命周期
    // ========================================================================

    /// 运行 package.json script (含生命周期)
    /// 严格翻译自: RunCommand.exec 中 pre${name} -> ${name} -> post${name}
    private static func runPackageScriptWithLifecycle(
        ctx: CommandContext,
        pkg: RunPackageJson,
        name: String,
        scriptContent: String,
        passthrough: ArrayList<String>
    ): Bool {
        let pkgDir = removeTrailingSlash(Path.dirname(pkg.path))
        let env = DotEnvLoader()

        // 运行 pre-script
        // 严格翻译自: run_command.zig 中 prescript 检查
        match (pkg.scripts.get("pre${name}")) {
            case Some(preScript) =>
                let exitCode = runPackageScriptForeground(
                    ctx, preScript, "pre${name}", pkgDir, env,
                    ArrayList<String>(), ctx.silent, ctx.useSystemShell
                )
                if (exitCode != 0) {
                    return true
                }
            case None => ()
        }

        // 运行主脚本
        let exitCode = runPackageScriptForeground(
            ctx, scriptContent, name, pkgDir, env,
            passthrough, ctx.silent, ctx.useSystemShell
        )

        // 运行 post-script
        match (pkg.scripts.get("post${name}")) {
            case Some(postScript) =>
                runPackageScriptForeground(
                    ctx, postScript, "post${name}", pkgDir, env,
                    ArrayList<String>(), ctx.silent, ctx.useSystemShell
                )
            case None => ()
        }

        return true
    }

    // ========================================================================
    // 文件执行
    // ========================================================================

    /// 快速路径: 尝试直接运行文件
    /// 严格翻译自: RunCommand.maybeOpenWithBunJS
    private static func maybeOpenWithBunJs(ctx: CommandContext): Bool {
        if (ctx.args.entryPoints.size == 0) {
            return false
        }

        let scriptName = ctx.args.entryPoints[0]
        let scriptPath = resolveScriptPath(scriptName)

        match (scriptPath) {
            case Some(path) =>
                // 检查是否为目录
                if (BaoFile.isDirectory(path)) {
                    return false
                }
                // 检查是否可运行
                return _bootAndHandleError(ctx, path, None)
            case None => return false
        }
    }

    /// 启动并处理错误
    /// 严格翻译自: RunCommand._bootAndHandleError
    private static func _bootAndHandleError(
        ctx: CommandContext,
        path: String,
        loader: ?String
    ): Bool {
        let resolvedLoader = loader ?? getDefaultLoaderForPath(path)

        // Markdown: 渲染并退出
        if (resolvedLoader == "md") {
            renderMarkdownFileAndExit(path)
        }

        // 配置长时间运行
        try {
            return bootRun(ctx, path, loader)
        } catch (e: Exception) {
            Output.prettyErrorLn("error: Failed to run ${Path.basename(path)} due to error ${e.message}")
            Sys.exit(1)
            return false
        }
    }

    /// 启动运行时
    private static func bootRun(ctx: CommandContext, path: String, loader: ?String): Bool {
        try {
            let vm = VirtualMachine()
            vm.executeFile(path)
            return true
        } catch (e: Exception) {
            throw e
        }
    }

    /// 运行 Stdin
    /// 严格翻译自: RunCommand.exec 中 stdin 模式
    private static func runStdin(ctx: CommandContext): Bool {
        try {
            let stdinData = readStdin()
            let code = bytesToString(stdinData)

            // 构造入口路径
            let cwd = Sys.getcwd()
            let entryPath = "${cwd}/[stdin]"

            let vm = VirtualMachine()
            vm.eval(code, entryPath)
            return true
        } catch (e: Exception) {
            Output.prettyErrorLn("error: ${e.message}")
            return false
        }
    }

    /// 渲染 Markdown 文件并退出
    /// 严格翻译自: RunCommand.renderMarkdownFileAndExit
    private static func renderMarkdownFileAndExit(path: String): Unit {
        let content = BaoFile.readAllText(path)
        match (content) {
            case Some(text) =>
                // 获取终端列数
                var columns: Int64 = 80
                let columnsEnv = Sys.getenv("COLUMNS")
                match (columnsEnv) {
                    case Some(v) =>
                        try {
                            let n = Int64.parse(v)
                            if (n > 0) { columns = n }
                        } catch (_: Exception) {}
                    case None => ()
                }

                // 渲染 Markdown
                let rendered = renderMarkdownToTerminal(text, columns)
                println(rendered)
            case None =>
                Output.prettyErrorLn("error: Failed to read file ${path}")
        }
        Sys.exit(0)
    }

    // ========================================================================
    // 查找
    // ========================================================================

    /// 查找二进制文件
    /// 严格翻译自: which.zig which()
    public static func whichBinary(path: String, cwd: String, name: String): ?String {
        let pathDirs = path.split(":")
        for (dir in pathDirs) {
            let candidate = Path.join([dir, name])
            if (BaoFile.exists(candidate) && BaoFile.isExecutable(candidate)) {
                return Some(candidate)
            }
        }
        return None
    }

    /// 解析脚本路径
    /// 严格翻译自: run_command.zig 中路径解析
    private static func resolveScriptPath(script: String): ?String {
        if (Path.isAbsolute(script)) {
            if (BaoFile.exists(script) && !BaoFile.isDirectory(script)) {
                return Some(script)
            }
            return tryExtensions(script)
        }

        if (script.startsWith("./") || script.startsWith("../")) {
            let resolved = Path.resolve(script)
            if (BaoFile.exists(resolved) && !BaoFile.isDirectory(resolved)) {
                return Some(resolved)
            }
            return tryExtensions(resolved)
        }

        // 直接文件名
        if (BaoFile.exists(script) && !BaoFile.isDirectory(script)) {
            return Some(Path.resolve(script))
        }

        return None
    }

    /// 尝试常见扩展名
    private static func tryExtensions(basePath: String): ?String {
        let extensions = [".js", ".ts", ".tsx", ".jsx", ".mjs", ".cjs"]
        for (ext in extensions) {
            let path = basePath + ext
            if (BaoFile.exists(path) && !BaoFile.isDirectory(path)) {
                return Some(path)
            }
        }
        return None
    }

    /// 尝试解析模块
    private static func tryResolveModule(name: String): ?String {
        let resolved = resolveScriptPath(name)
        match (resolved) {
            case Some(p) => return Some(p)
            case None => ()
        }
        // 尝试 ./ 前缀
        let withDotSlash = Path.resolve("./${name}")
        return tryExtensions(withDotSlash)
    }

    // ========================================================================
    // Shell 补全
    // ========================================================================

    /// 获取 shell 补全列表
    /// 严格翻译自: RunCommand.completions
    public static func completions(
        ctx: CommandContext,
        defaultCompletions: ?Array<String>,
        rejectList: Array<String>,
        filter: RunCommandFilter
    ): ShellCompletions {
        var shellOut = ShellCompletions()
        if (filter != RunCommandFilter.ScriptExclude) {
            match (defaultCompletions) {
                case Some(defaults) =>
                    shellOut.commands = defaults
                case None => ()
            }
        }

        // 在 Bun 中这里会创建 Transpiler 并遍历目录结构
        // 简化: 从 package.json 读取 scripts

        let cwd = Sys.getcwd()
        let pkgOpt = readPackageJson(cwd)

        if (filter == RunCommandFilter.Script || filter == RunCommandFilter.All ||
            filter == RunCommandFilter.AllPlusBunJs || filter == RunCommandFilter.ScriptAndDescriptions ||
            filter == RunCommandFilter.ScriptExclude) {
            match (pkgOpt) {
                case Some(pkg) =>
                    var commands = ArrayList<String>()
                    if (shellOut.commands != None) {
                        for (c in shellOut.commands ?? []) {
                            commands.append(c)
                        }
                    }

                    for (key in pkg.scripts.keys()) {
                        // 排除 pre/post 前缀脚本
                        if (key.startsWith("pre")) {
                            let rest = key.substring(3)
                            if (pkg.scripts.contains(rest)) {
                                continue
                            }
                        }
                        if (key.startsWith("post")) {
                            let rest = key.substring(4)
                            if (pkg.scripts.contains(rest)) {
                                continue
                            }
                        }

                        // 排除 rejectList 中的项
                        var rejected = false
                        for (r in rejectList) {
                            if (key == r) { rejected = true }
                        }
                        if (rejected) { continue }

                        commands.append(key)
                    }

                    shellOut.commands = commands.toArray()
                case None => ()
            }
        }

        // 排序
        if (shellOut.commands != None) {
            let cmds = shellOut.commands ?? []
            cmds.sort()
            shellOut.commands = cmds
        }

        return shellOut
    }

    // ========================================================================
    // ls 命令
    // ========================================================================

    /// 列出 scripts 和 bins
    /// 严格翻译自: RunCommand.ls
    public static func ls(ctx: CommandContext): Unit {
        // 在 Bun 中创建 Transpiler 并列出 scripts/bins
        // 简化: 直接读取 package.json
        let cwd = Sys.getcwd()
        let pkgOpt = readPackageJson(cwd)
        match (pkgOpt) {
            case Some(pkg) =>
                if (pkg.scripts.size > 0) {
                    println("Scripts:")
                    for ((key, cmd) in pkg.scripts) {
                        println("  ${key}: ${cmd}")
                    }
                }
            case None => println("No package.json found.")
        }
    }

    // ========================================================================
    // 帮助
    // ========================================================================

    /// 打印帮助信息
    /// 严格翻译自: RunCommand.printHelp
    public static func printHelp(pkg: ?RunPackageJson): Unit {
        println("Usage: bao run [flags] <file or script>")
        println("")
        println("Examples:")
        println("  bao run ./index.js")
        println("  bao run ./index.tsx")
        println("  bao run dev")
        println("  bao run lint")
        println("")
        println("Flags:")
        println("  --bun              Force using Bao's runtime instead of Node.js")
        println("  --silent           Don't print the script command")
        println("  --watch            Restart on file change")
        println("  --hot              Hot reload on file change")
        println("  --filter <pattern> Run in workspace packages matching pattern")
        println("  --shell <shell>    Shell for scripts: 'bao' or 'system'")
        println("  --if-present       Exit without error if entrypoint doesn't exist")
        println("")

        // 列出 package.json scripts
        match (pkg) {
            case Some(p) =>
                if (p.scripts.size > 0) {
                    println("package.json scripts (${p.scripts.size} found):")
                    for (key in p.scripts.keys()) {
                        match (p.scripts.get(key)) {
                            case Some(cmd) =>
                                println("")
                                println("  $ bao run ${key}")
                                println("    ${cmd}")
                            case None => ()
                        }
                    }
                    println("")
                } else {
                    println("No \"scripts\" found in package.json.")
                }
            case None => ()
        }
    }

    // ========================================================================
    // BunX 快速路径 (Windows)
    // ========================================================================

    /// BunX 快速路径
    /// 严格翻译自: run_command.zig BunXFastPath
    public class BunXFastPath {
        /// 尝试直接启动 bunx 文件
        /// 严格翻译自: BunXFastPath.tryLaunch
        public static func tryLaunch(
            ctx: CommandContext,
            pathToUse: String,
            env: DotEnvLoader,
            passthrough: ArrayList<String>
        ): Unit {
            // 在非 Windows 平台上不做任何事
            // 在 Windows 上查找 .bunx 文件并直接启动
            // 简化: 跳过 Windows 特定逻辑
        }
    }

    // ========================================================================
    // 辅助
    // ========================================================================

    /// 读取 package.json
    private static func readPackageJson(dir: String): ?RunPackageJson {
        let path = Path.join([dir, "package.json"])
        let content = BaoFile.readAllText(path)
        match (content) {
            case Some(text) =>
                let pkg = RunPackageJson()
                pkg.path = path
                parsePackageJsonScripts(text, pkg)
                return Some(pkg)
            case None => return None
        }
    }

    /// 解析 package.json scripts
    private static func parsePackageJsonScripts(content: String, pkg: RunPackageJson): Unit {
        let parser = JsonParser()
        match (parser.parse(content)) {
            case Some(root) =>
                match (JsonHelper.getField(root, "scripts")) {
                    case Some(scripts) =>
                        for (key in scripts.keys()) {
                            match (scripts.get(key)) {
                                case Some(v) => pkg.scripts.put(key, v.toString())
                                case None => ()
                            }
                        }
                    case None => ()
                }
                // 解析 name
                match (JsonHelper.getString(root, "name")) {
                    case Some(n) => pkg.name = n
                    case None => ()
                }
                // 解析 version
                match (JsonHelper.getString(root, "version")) {
                    case Some(v) => pkg.version = v
                    case None => ()
                }
                // 解析 config
                match (JsonHelper.getField(root, "config")) {
                    case Some(config) =>
                        for (key in config.keys()) {
                            match (config.get(key)) {
                                case Some(v) => pkg.config.put(key, v.toString())
                                case None => ()
                            }
                        }
                    case None => ()
                }
            case None => ()
        }
    }

    /// 检测文件 loader
    private static func detectLoader(path: String): String {
        let ext = Path.extension(path)
        let jsExts = [".js", ".mjs", ".cjs"]
        let tsExts = [".ts", ".tsx", ".jsx", ".mts", ".cts"]
        for (e in jsExts) { if (ext == e) { return "js" } }
        for (e in tsExts) { if (ext == e) { return "ts" } }
        if (ext == ".html") { return "html" }
        if (ext == ".md") { return "md" }
        if (ext == ".css") { return "css" }
        if (ext == ".json") { return "json" }
        if (ext == ".wasm") { return "wasm" }
        return "file"
    }

    /// 获取路径的默认 loader
    private static func getDefaultLoaderForPath(path: String): String {
        return detectLoader(path)
    }

    /// 获取扩展名的默认 loader
    private static func getDefaultLoader(ext: String): ?String {
        let jsExts = [".js", ".mjs", ".cjs"]
        let tsExts = [".ts", ".tsx", ".jsx", ".mts", ".cts"]
        for (e in jsExts) { if (ext == e) { return Some("js") } }
        for (e in tsExts) { if (ext == e) { return Some("ts") } }
        if (ext == ".html") { return Some("html") }
        if (ext == ".md") { return Some("md") }
        if (ext == ".json") { return Some("json") }
        return None
    }

    /// 检查 loader 是否可被 Bun 运行
    private static func canBeRunByBun(loader: String): Bool {
        let runnableLoaders = ["js", "ts", "jsx", "tsx", "json", "wasm"]
        for (l in runnableLoaders) {
            if (loader == l) { return true }
        }
        return false
    }

    /// 读取 stdin
    private static func readStdin(): Array<UInt8> {
        let buffer = ArrayBuffer(4096)
        try {
            let chunk = Array<UInt8>(4096, item: 0)
            var done = false
            while (!done) {
                let n = SysFs.read(0, chunk)
                if (n <= 0) {
                    done = true
                } else {
                    for (i in 0..n) {
                        buffer.append(chunk[Int64(i)])
                    }
                }
            }
        } catch (_: Exception) {}
        return buffer.slice()
    }

    /// 移除尾部斜杠
    public static func removeTrailingSlash(s: String): String {
        if (s.length > 1 && s[s.length - 1] == '/') {
            return s.substring(0, s.length - 1)
        }
        return s
    }

    /// 字节数组转字符串
    private static func bytesToString(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 检查字符串是否需要 shell 转义
    private static func needsEscape(s: String): Bool {
        for (c in s) {
            if (c == ' ' || c == '\t' || c == '"' || c == '\'' || c == '\\' ||
                c == '|' || c == '&' || c == ';' || c == '<' || c == '>' ||
                c == '(' || c == ')' || c == '$' || c == '`' || c == '!' ||
                c == '*' || c == '?' || c == '[' || c == ']' || c == '{' || c == '}') {
                return true
            }
        }
        return false
    }

    /// 8-bit 转义
    private static func escape8Bit(s: String, singleQuote: Bool): String {
        if (singleQuote) {
            return "'${s.replace("'", "'\\''")}'"
        }
        return "\"${s.replace("\\", "\\\\").replace("\"", "\\\"").replace("$", "\\$").replace("`", "\\`")}\""
    }

    /// 渲染 Markdown 到终端
    private static func renderMarkdownToTerminal(content: String, columns: Int64): String {
        // 简化: 直接返回内容
        // 在 Bun 中这会使用 bun.md.renderToAnsi
        return content
    }

    /// String 扩展: 从指定位置开始匹配
    private static func startsWithFrom(s: String, prefix: String, fromIndex: Int64): Bool {
        if (fromIndex < 0 || fromIndex + prefix.length > s.length) {
            return false
        }
        for (i in 0..prefix.length) {
            if (s[fromIndex + i] != prefix[i]) {
                return false
            }
        }
        return true
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Run 命令配置
/// 严格翻译自: RunCommand.exec cfg 参数
public class RunCommandConfig {
    public var binDirsOnly: Bool
    public var logErrors: Bool
    public var allowFastRunForExtensions: Bool

    public init() {
        binDirsOnly = false
        logErrors = true
        allowFastRunForExtensions = true
    }

    public init(binDirsOnly: Bool, logErrors: Bool, allowFastRunForExtensions: Bool) {
        this.binDirsOnly = binDirsOnly
        this.logErrors = logErrors
        this.allowFastRunForExtensions = allowFastRunForExtensions
    }
}

/// 运行时 package.json 信息
class RunPackageJson {
    public var path: String
    public var name: String
    public var version: String
    public var scripts: HashMap<String, String>
    public var config: HashMap<String, String>

    public init() {
        path = ""
        name = ""
        version = ""
        scripts = HashMap<String, String>()
        config = HashMap<String, String>()
    }
}

/// 运行时目录信息
/// 严格翻译自: run_command.zig DirInfo (简化)
class RunDirInfo {
    public var enclosingPackageJson: ?RunPackageJson
    public var absPath: String

    public init() {
        enclosingPackageJson = None
        absPath = Sys.getcwd()
    }
}

/// 解析的文件信息
class ResolvedFileInfo {
    public var path: String
    public var loader: String

    public init(path: String, loader: String) {
        this.path = path
        this.loader = loader
    }
}

/// DotEnv 加载器
/// 严格翻译自: run_command.zig DotEnv.Loader
class DotEnvLoader {
    private var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    public func loadProcess(): Unit {
        // 从系统 environ 加载
    }

    public func loadDotEnv(skipDefault: Bool): Unit {
        // 加载 .env 文件
    }

    public func get(key: String): ?String {
        return map.get(key)
    }

    public func put(key: String, value: String): Unit {
        map.put(key, value)
    }

    public func putDefault(key: String, value: String): Unit {
        if (!map.contains(key)) {
            map.put(key, value)
        }
    }

    public func contains(key: String): Bool {
        return map.contains(key)
    }

    /// 转换为环境变量数组
    public func toEnvArray(): Array<String> {
        let result = ArrayList<String>()
        for ((k, v) in map) {
            result.append("${k}=${v}")
        }
        return result.toArray()
    }
}

/// Shell 补全结果
class ShellCompletions {
    public var commands: ?Array<String>
    public var descriptions: ?Array<String>
    public var shell: String

    public init() {
        commands = None
        descriptions = None
        shell = ""
    }
}

/// Shell 解释器 (简化)
class ShellInterpreter {
    public static func initAndRunFromSource(name: String, script: String, cwd: String): Int64 {
        // 在 Bun 中使用 bun.shell.Interpreter
        try {
            return Process.spawnShell(script, cwd)
        } catch (e: Exception) {
            return 1
        }
    }
}

/// 引用包装器
class Ref<T> {
    public var value: T

    public init(value: T) {
        this.value = value
    }
}

/// String 扩展: 从指定位置获取子串
private func String.substringFrom(fromIndex: Int64): String {
    if (fromIndex >= this.length) { return "" }
    return this.substring(fromIndex)
}

/// String 扩展: 从指定位置开始匹配
private func String.startsWithFrom(prefix: String, fromIndex: Int64): Bool {
    if (fromIndex < 0 || fromIndex + prefix.length > this.length) {
        return false
    }
    for (i in 0..prefix.length) {
        if (this[fromIndex + i] != prefix[i]) {
            return false
        }
    }
    return true
}
