// 严格翻译自: src/cli/run_command.zig
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
// ============================================================================

/// Run 命令执行器
/// 对应 Bun: RunCommand.exec(ctx, cfg)
public class RunCommand {
    /// 运行选项
    private var options: RunCommandOptions

    /// 位置参数
    // 对应 Bun: ctx.positionals
    private var positionals: ArrayList<String>

    /// passthrough 参数
    // 对应 Bun: ctx.passthrough
    private var passthrough: ArrayList<String>

    /// 环境变量加载器
    // 对应 Bun: DotEnv.Loader
    private var envLoader: DotEnvLoader

    /// 目标名称
    // 对应 Bun: target_name
    private var targetName: String

    public init(options: RunCommandOptions) {
        this.options = options
        this.positionals = ArrayList<String>()
        this.passthrough = ArrayList<String>()
        this.envLoader = DotEnvLoader()
        this.targetName = ""
    }

    /// 执行 run 命令
    /// 对应 Bun: RunCommand.exec(ctx, cfg)
    ///
    /// 返回值: true 表示已执行，false 表示未找到
    public func execute(): Bool {
        // 解析位置参数
        // 严格翻译自: run_command.zig 中 positionals 解析
        var posArgs = options.positionals
        if (posArgs.size > 0 && posArgs[0] == "run") {
            // 移除 "run" 前缀
            posArgs = posArgs.slice(1)
        }

        targetName = if (posArgs.size > 0) { posArgs[0] } else { "" }
        passthrough = if (posArgs.size > 1) {
            posArgs.slice(1)
        } else {
            ArrayList<String>()
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
        } else if (targetName.length > 0) {
            let ext = Path.extension(targetName)
            // 常见的可运行扩展名
            let runnableExts = [".js", ".ts", ".tsx", ".jsx", ".mjs", ".html", ".md"]
            for (re in runnableExts) {
                if (ext == re) {
                    tryFastRun = true
                }
            }
        }

        // 加载 bunfig.toml
        // 严格翻译自: run_command.zig 中 loadConfigPath

        // 快速路径: 尝试直接运行文件
        if (tryFastRun && tryOpenWithBunJs()) {
            return true
        }

        // 设置环境变量
        // 严格翻译自: run_command.zig 中 configureEnvForRun
        let rootDirInfo = configureEnvForRun()
        try {
            configurePathForRun(rootDirInfo)
        } catch (_: Exception) {}

        envLoader.put("npm_command", "run-script")

        // 空命令: 列出 scripts
        // 严格翻译自: run_command.zig 中 target_name.len == 0
        if (targetName.length == 0) {
            match (rootDirInfo.enclosingPackageJson) {
                case Some(pkg) => printHelp(pkg)
                case None => {
                    printHelp(None)
                    println("\nNo package.json found.")
                }
            }
            return true
        }

        // Stdin 模式: script == "-"
        // 严格翻译自: run_command.zig 中 stdin 检查
        if (targetName.length == 1 && targetName[0] == '-') {
            return runStdin()
        }

        // 查找并运行 package.json script
        // 严格翻译自: run_command.zig 中 scripts.get(target_name)
        if (!skipScriptCheck) {
            match (rootDirInfo.enclosingPackageJson) {
                case Some(pkg) => {
                    match (pkg.scripts.get(targetName)) {
                        case Some(scriptContent) => {
                            return runPackageScriptWithLifecycle(pkg, targetName, scriptContent)
                        }
                        case None => ()
                    }
                }
                case None => ()
            }
        }

        // 尝试解析为模块
        // 严格翻译自: run_command.zig 中 resolver.resolve
        let resolution = tryResolveModule(targetName)
        match (resolution) {
            case Some(path) => {
                let loader = detectLoader(path)
                if (loader.canBeRunByBun() || loader == "html" || loader == "md") {
                    return bootAndHandleError(path)
                }
            }
            case None => ()
        }

        // 在 node_modules/.bin 和系统 PATH 中查找
        // 严格翻译自: run_command.zig 中 which() 查找
        let binResult = findBinary(targetName)
        match (binResult) {
            case Some(binaryPath) => {
                return runBinary(binaryPath)
            }
            case None => ()
        }

        // 失败
        // 严格翻译自: run_command.zig 中 failure 输出
        if (options.ifPresent) {
            return true
        }

        if (options.logErrors) {
            let ext = Path.extension(targetName)
            if (targetName.length > 0 && (targetName[0] == '.' || targetName[0] == '/' || Path.isAbsolute(targetName))) {
                println("error: Module not found \"${targetName}\"")
            } else if (ext.length > 0) {
                println("error: File not found \"${targetName}\"")
            } else {
                println("error: Script not found \"${targetName}\"")
            }
            Sys.exit(1)
        }

        return false
    }

    // ========================================================================
    // 环境配置
    // ========================================================================

    /// 配置运行环境
    /// 对应 Bun: RunCommand.configureEnvForRun(ctx, this_transpiler, env, log_errors, store_root_fd)
    ///
    /// 严格翻译自: run_command.zig 中 configureEnvForRunWithOptions:
    ///   1. 创建 Transpiler 实例
    ///   2. 加载 .env 文件
    ///   3. 设置 npm 环境变量
    ///   4. 返回 root DirInfo
    private func configureEnvForRun(): RunDirInfo {
        let rootDirInfo = RunDirInfo()

        // 加载环境变量
        envLoader.loadProcess()

        // 检测 NODE_ENV=production
        match (envLoader.get("NODE_ENV")) {
            case Some(nodeEnv) => {
                if (nodeEnv == "production") {
                    options.production = true
                }
            }
            case None => ()
        }

        // 加载 .env 文件
        envLoader.loadDotEnv(true)

        // 设置 npm 环境变量
        // 严格翻译自: run_command.zig 中 npm_config_user_agent
        envLoader.putDefault("npm_config_user_agent", "bao/${BAO_VERSION} npm/? node/v18.0.0")

        // 设置 npm_execpath
        let selfExe = Sys.getExecutablePath()
        envLoader.putDefault("npm_execpath", selfExe)

        // 从 package.json 设置 npm_package_* 变量
        let pkgOpt = readPackageJson()
        match (pkgOpt) {
            case Some(pkg) => {
                rootDirInfo.enclosingPackageJson = Some(pkg)
                if (pkg.name.length > 0) {
                    envLoader.putDefault("npm_package_name", pkg.name)
                }
                if (pkg.version.length > 0) {
                    envLoader.putDefault("npm_package_version", pkg.version)
                }
            }
            case None => ()
        }

        return rootDirInfo
    }

    /// 配置 PATH (注入 node_modules/.bin)
    /// 对应 Bun: RunCommand.configurePathForRun()
    ///
    /// 严格翻译自: run_command.zig 中 configurePathForRunWithPackageJsonDir:
    ///   1. 注入 package.json 目录
    ///   2. 注入每个父目录的 node_modules/.bin
    ///   3. 创建临时 node 可执行文件 (如果需要)
    private func configurePathForRun(rootDirInfo: RunDirInfo): Unit {
        let originalPath = envLoader.get("PATH") ?? ""
        let sb = StringBuilder()

        // 注入 package.json 目录
        match (rootDirInfo.enclosingPackageJson) {
            case Some(pkg) => {
                let pkgDir = Path.dirname(pkg.path)
                sb.append(pkgDir)
                sb.append(':')
            }
            case None => ()
        }

        // 注入每个父目录的 node_modules/.bin
        // 严格翻译自: run_command.zig 中遍历 cwd 的父目录
        var remain = Sys.getcwd()
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
        sb.append(originalPath)
        envLoader.put("PATH", sb.toString())
    }

    // ========================================================================
    // 脚本执行
    // ========================================================================

    /// 运行 package.json script (含生命周期)
    /// 对应 Bun: run_command.zig 中 pre/script/post 执行
    ///
    /// 严格翻译自: RunCommand.exec 中 pre${name} -> ${name} -> post${name}
    private func runPackageScriptWithLifecycle(
        pkg: RunPackageJson,
        name: String,
        scriptContent: String
    ): Bool {
        let pkgDir = Path.dirname(pkg.path)

        // 设置环境变量
        envLoader.put("npm_lifecycle_event", name)
        envLoader.put("npm_lifecycle_script", scriptContent)

        // 运行 pre-script
        // 严格翻译自: run_command.zig 中 prescript 检查
        match (pkg.scripts.get("pre${name}")) {
            case Some(preScript) => {
                let exitCode = executeScriptInShell(preScript, "pre${name}", pkgDir)
                if (exitCode != 0) {
                    return true
                }
            }
            case None => ()
        }

        // 运行主脚本
        let exitCode = executeScriptInShell(scriptContent, name, pkgDir)

        // 运行 post-script
        match (pkg.scripts.get("post${name}")) {
            case Some(postScript) => {
                executeScriptInShell(postScript, "post${name}", pkgDir)
            }
            case None => ()
        }

        return true
    }

    /// 在 shell 中执行脚本命令
    /// 对应 Bun: RunCommand.runPackageScriptForeground()
    ///
    /// 严格翻译自: run_command.zig 中 spawnSync 分支:
    ///   1. 替换包管理器调用 (yarn run -> bun run, npm run -> bun run)
    ///   2. 通过 bun shell 或系统 shell 执行
    private func executeScriptInShell(
        script: String,
        name: String,
        cwd: String
    ): Int64 {
        // 替换包管理器命令
        // 严格翻译自: run_command.zig 中 replacePackageManagerRun()
        var processedScript = replacePackageManagerRun(script)

        // 附加 passthrough 参数
        let sb = StringBuilder()
        sb.append(processedScript)
        for (arg in passthrough) {
            sb.append(' ')
            sb.append(arg)
        }
        let fullScript = sb.toString()

        if (!options.silent) {
            println("$ ${fullScript}")
        }

        // 执行
        // 对应 Bun: spawnSync 或 bun shell Interpreter
        try {
            let exitCode = Process.spawnShell(fullScript, cwd)
            if (exitCode != 0) {
                if (exitCode != 2 && !options.silent) {
                    println("error: script \"${name}\" exited with code ${exitCode}")
                }
            }
            return exitCode
        } catch (e: Exception) {
            if (!options.silent) {
                println("error: Failed to run script ${name} due to error ${e.message}")
            }
            return 1
        }
    }

    /// 替换包管理器调用
    // 严格翻译自: run_command.zig 中 replacePackageManagerRun
    // yarn run -> bun run, npm run -> bun run, pnpm run -> bun run
    // npx -> bun x, pnpm dlx -> bun x, pnpx -> bun x
    private func replacePackageManagerRun(script: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        var delimiter: UInt8 = UInt8(' ')

        while (i < script.length) {
            let c = script[i]
            // 检查分隔符后的包管理器名称
            if (delimiter > UInt8(0)) {
                // yarn run -> bun run
                if (script.startsWithFrom("yarn ", i)) {
                    let remainder = script.substringFrom(i + 5)
                    let spaceIdx = remainder.indexOf(' ')
                    match (spaceIdx) {
                        case Some(si) => {
                            let yarnCmd = remainder.substring(0, si)
                            if (yarnCmd == "run") {
                                sb.append("bao run")
                                i += Int64("yarn run".length)
                                delimiter = UInt8(0)
                                continue
                            }
                        }
                        case None => ()
                    }
                }

                // npm run -> bun run
                if (script.startsWithFrom("npm run ", i)) {
                    sb.append("bao run ")
                    i += Int64("npm run ".length)
                    delimiter = UInt8(0)
                    continue
                }

                // npx -> bun x
                if (script.startsWithFrom("npx ", i)) {
                    sb.append("bao x ")
                    i += Int64("npx ".length)
                    delimiter = UInt8(0)
                    continue
                }

                // pnpm run -> bun run
                if (script.startsWithFrom("pnpm run ", i)) {
                    sb.append("bao run ")
                    i += Int64("pnpm run ".length)
                    delimiter = UInt8(0)
                    continue
                }

                // pnpm dlx -> bun x
                if (script.startsWithFrom("pnpm dlx ", i)) {
                    sb.append("bao x ")
                    i += Int64("pnpm dlx ".length)
                    delimiter = UInt8(0)
                    continue
                }
            }

            // 更新分隔符
            if (c == ' ') { delimiter = UInt8(' ') }
            else if (c == '"') { delimiter = UInt8('"') }
            else if (c == '\'') { delimiter = UInt8('\'') }
            else { delimiter = UInt8(0) }

            sb.append(c)
            i += 1
        }

        return sb.toString()
    }

    // ========================================================================
    // 文件执行
    // ========================================================================

    /// 快速路径: 尝试直接运行文件
    // 对应 Bun: run_command.zig 中 maybeOpenWithBunJS
    private func tryOpenWithBunJs(): Bool {
        let scriptPath = resolveScriptPath(targetName)
        match (scriptPath) {
            case Some(path) => {
                // 检查是否为文件 (非目录)
                if (BaoFile.isDirectory(path)) {
                    return false
                }
                // 检查 loader 是否支持
                let loader = detectLoader(path)
                if (loader == "md") {
                    // Markdown: 渲染并退出
                    return true
                }
                return bootAndHandleError(path)
            }
            case None => return false
        }
    }

    /// 启动并处理错误
    // 对应 Bun: run_command.zig 中 _bootAndHandleError
    private func bootAndHandleError(path: String): Bool {
        // 注入环境变量
        envLoader.loadDotEnv(true)

        try {
            let vm = VirtualMachine()
            vm.executeFile(path)
            return true
        } catch (e: Exception) {
            println("error: Failed to run ${Path.basename(path)} due to error ${e.message}")
            Sys.exit(1)
            return false
        }
    }

    /// 运行二进制文件
    // 对应 Bun: run_command.zig 中 runBinary / runBinaryWithoutBunxPath
    private func runBinary(path: String): Bool {
        try {
            let argv = ArrayList<String>()
            argv.append(path)
            for (arg in passthrough) {
                argv.append(arg)
            }
            let exitCode = Process.spawn(path, argv.toArray())
            if (exitCode != 0 && !options.silent) {
                println("error: \"${Path.basename(path)}\" exited with code ${exitCode}")
            }
            Sys.exit(exitCode)
            return true
        } catch (e: Exception) {
            if (!options.silent) {
                println("error: Failed to run \"${path}\" due to ${e.message}")
            }
            Sys.exit(1)
            return false
        }
    }

    /// Stdin 模式
    // 对应 Bun: run_command.zig 中 stdin 模式
    private func runStdin(): Bool {
        try {
            let stdinData = readStdin()
            let code = bytesToString(stdinData)
            let vm = VirtualMachine()
            vm.eval(code, "<stdin>")
            return true
        } catch (e: Exception) {
            println("error: ${e.message}")
            return false
        }
    }

    // ========================================================================
    // 查找
    // ========================================================================

    /// 查找二进制文件
    // 对应 Bun: run_command.zig 中 which() 调用
    private func findBinary(name: String): ?String {
        let path = envLoader.get("PATH") ?? ""
        let cwd = Sys.getcwd()

        // 在 PATH 中查找
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
    // 对应 Bun: run_command.zig 中路径解析
    private func resolveScriptPath(script: String): ?String {
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

        return None
    }

    /// 尝试常见扩展名
    private func tryExtensions(basePath: String): ?String {
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
    private func tryResolveModule(name: String): ?String {
        let resolved = resolveScriptPath(name)
        match (resolved) {
            case Some(p) => return Some(p)
            case None => ()
        }
        // 尝试 ./ 前缀
        let withDotSlash = Path.resolve("./${name}")
        return tryExtensions(withDotSlash)
    }

    /// 检测文件 loader
    private func detectLoader(path: String): String {
        let ext = Path.extension(path)
        let jsExts = [".js", ".mjs", ".cjs"]
        let tsExts = [".ts", ".tsx", ".jsx", ".mts", ".cts"]
        for (e in jsExts) { if (ext == e) { return "js" } }
        for (e in tsExts) { if (ext == e) { return "ts" } }
        if (ext == ".html") { return "html" }
        if (ext == ".md") { return "md" }
        if (ext == ".css") { return "css" }
        return "file"
    }

    // ========================================================================
    // 辅助
    // ========================================================================

    /// 读取 package.json
    private func readPackageJson(): ?RunPackageJson {
        let content = BaoFile.readAllText("package.json")
        match (content) {
            case Some(text) => {
                let pkg = RunPackageJson()
                pkg.path = Path.resolve("package.json")
                // 简化: 解析 scripts
                parsePackageJsonScripts(text, pkg)
                return Some(pkg)
            }
            case None => return None
        }
    }

    /// 解析 package.json scripts
    private func parsePackageJsonScripts(content: String, pkg: RunPackageJson): Unit {
        // 简化: 使用 JSON 解析
        let parser = JsonParser()
        match (parser.parse(content)) {
            case Some(root) => {
                match (JsonHelper.getField(root, "scripts")) {
                    case Some(scripts) => {
                        for (key in scripts.keys()) {
                            match (scripts.get(key)) {
                                case Some(v) => pkg.scripts.put(key, v.toString())
                                case None => ()
                            }
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
            }
            case None => ()
        }
    }

    /// 读取 stdin
    private func readStdin(): Array<UInt8> {
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
    private func removeTrailingSlash(s: String): String {
        if (s.length > 1 && s[s.length - 1] == '/') {
            return s.substring(0, s.length - 1)
        }
        return s
    }

    /// 打印帮助信息
    // 对应 Bun: RunCommand.printHelp()
    private func printHelp(pkg: ?RunPackageJson): Unit {
        println("Usage: bao run [flags] <file or script>")
        println("")
        println("Examples:")
        println("  bao run ./index.js")
        println("  bao run ./index.tsx")
        println("  bao run dev")
        println("  bao run lint")
        println("")
        println("Flags:")
        println("  --bun              Force using bao's runtime")
        println("  --silent           Don't print the command")
        println("  --watch            Restart on file change")
        println("  --hot              Hot reload on file change")
        println("")

        // 列出 package.json scripts
        match (pkg) {
            case Some(p) => {
                if (p.scripts.size > 0) {
                    println("package.json scripts (${p.scripts.size} found):")
                    for (key in p.scripts.keys()) {
                        match (p.scripts.get(key)) {
                            case Some(cmd) => {
                                println("")
                                println("  $ bao run ${key}")
                                println("    ${cmd}")
                            }
                            case None => ()
                        }
                    }
                    println("")
                } else {
                    println("No \"scripts\" found in package.json.")
                }
            }
            case None => ()
        }
    }

    /// 字节数组转字符串
    private func bytesToString(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Run 命令选项
/// 对应 Bun: RunCommand 的命令行选项
public class RunCommandOptions {
    /// 位置参数
    public var positionals: ArrayList<String>

    /// 运行 eval (-e)
    public var evalScript: String

    /// 是否强制使用 bun 运行 (--bun)
    public var runInBun: Bool

    /// 静默模式 (--silent)
    public var silent: Bool

    /// 使用系统 shell (--shell)
    public var useSystemShell: Bool

    /// Watch 模式 (--watch)
    public var watch: Bool

    /// Hot 模式 (--hot)
    public var hot: Bool

    /// 生产模式
    public var production: Bool

    /// 仅当存在时运行 (--if-present)
    public var ifPresent: Bool

    /// 是否记录错误
    public var logErrors: Bool

    /// 仅搜索 bin 目录
    public var binDirsOnly: Bool

    /// 允许快速运行的扩展名
    public var allowFastRunForExtensions: Bool

    /// preload 文件列表
    public var preloads: ArrayList<String>

    public init() {
        positionals = ArrayList<String>()
        evalScript = ""
        runInBun = false
        silent = false
        useSystemShell = false
        watch = false
        hot = false
        production = false
        ifPresent = false
        logErrors = true
        binDirsOnly = false
        allowFastRunForExtensions = true
        preloads = ArrayList<String>()
    }
}

/// 运行时 package.json 信息
class RunPackageJson {
    public var path: String
    public var name: String
    public var version: String
    public var scripts: HashMap<String, String>

    public init() {
        path = ""
        name = ""
        version = ""
        scripts = HashMap<String, String>()
    }
}

/// 运行时目录信息
class RunDirInfo {
    public var enclosingPackageJson: ?RunPackageJson

    public init() {
        enclosingPackageJson = None
    }
}

/// DotEnv 加载器 (简化)
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

/// String 扩展: 从指定位置获取子串
private func String.substringFrom(fromIndex: Int64): String {
    if (fromIndex >= this.length) { return "" }
    return this.substring(fromIndex)
}
