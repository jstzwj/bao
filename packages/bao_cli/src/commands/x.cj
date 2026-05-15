// 严格翻译自: src/cli/bunx_command.zig
// bao x - 执行包二进制文件
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_http.*
import bao_sys.*

// ============================================================================
// x 命令 - 对应 bunx / bao x <package> [args...]
// 严格翻译自: src/cli/bunx_command.zig (BunxCommand)
// 核心流程: 解析包名 -> 查找本地 bin -> 未找到则安装 -> 执行二进制
// ============================================================================

/// x 命令选项
/// 严格翻译自: src/cli/bunx_command.zig Options struct
public class XOptions {
    /// 包名
    public var packageName: String
    /// 二进制名 (当与包名不同时, 如 --package)
    public var binaryName: ?String
    /// 指定的包 (--package)
    public var specifiedPackage: ?String
    /// 传递给命令的参数
    public var passthroughArgs: ArrayList<String>
    /// 是否使用 bao 运行 (--bun / -b)
    public var runInBao: Bool
    /// 跳过安装, 仅运行已下载的 (--no-install)
    public var noInstall: Bool
    /// 详细安装输出 (--verbose)
    public var verboseInstall: Bool
    /// 静默安装输出 (--silent)
    public var silentInstall: Bool

    public init(packageName: String) {
        this.packageName = packageName
        this.binaryName = None
        this.specifiedPackage = None
        this.passthroughArgs = ArrayList<String>()
        this.runInBao = false
        this.noInstall = false
        this.verboseInstall = false
        this.silentInstall = false
    }
}

/// x 命令执行器
/// 严格翻译自: src/cli/bunx_command.zig BunxCommand.exec
/// 核心流程:
///   1. 解析参数获取包名和传参
///   2. 先尝试在本地 node_modules/.bin 查找二进制
///   3. 如果未找到, 在全局缓存中查找
///   4. 如果仍未找到, 安装包到临时目录
///   5. 从安装的包中查找 bin 名称
///   6. 执行二进制
public class XCommand {
    private var logger: Logger
    /// 缓存有效时间 (1天, 秒)
    // 严格翻译自: seconds_cache_valid = 60 * 60 * 24
    private let CACHE_VALID_SECONDS: Int64 = 86400

    public init() {
        logger = Logger()
    }

    /// 执行 x 命令
    // 严格翻译自: src/cli/bunx_command.zig BunxCommand.exec
    public func execute(args: ArrayList<String>): Unit {
        if (args.size == 0) {
            printXHelp()
            return
        }

        let opts = parseArgs(args)

        // 特殊别名: tsc -> typescript
        // 严格翻译自: src/cli/bunx_command.zig tsc alias
        var updateName = opts.packageName
        if (opts.specifiedPackage.isEmpty()) {
            if (updateName == "tsc") {
                updateName = "typescript"
            }
        }

        // 确定初始二进制名
        // 严格翻译自: src/cli/bunx_command.zig initial_bin_name
        let initialBinName = match (opts.binaryName) {
            case Some(bn) => bn
            case None => {
                if (updateName == "typescript") {
                    "tsc"
                } else {
                    // 去掉 scope 前缀: @org/package -> package
                    let lastSlash = updateName.lastIndexOf("/")
                    match (lastSlash) {
                        case Some(idx) => updateName.substring(idx + 1)
                        case None => updateName
                    }
                }
            }
        }

        // 步骤1: 尝试在本地 node_modules/.bin 中查找
        let localBin = findInNodeModules(initialBinName)
        match (localBin) {
            case Some(binPath) => {
                logger.debug("Found binary locally: ${binPath}")
                runBinary(binPath, opts.passthroughArgs)
                return
            }
            case None => ()
        }

        // 步骤2: 在全局缓存中查找
        let cacheDir = getCacheDir(updateName)
        let cachedBin = findInCache(cacheDir, initialBinName)
        match (cachedBin) {
            case Some(binPath) => {
                // 检查缓存是否过期
                if (!isCacheStale(binPath)) {
                    logger.debug("Found cached binary: ${binPath}")
                    runBinary(binPath, opts.passthroughArgs)
                    return
                }
                logger.debug("Cached binary is stale, re-installing...")
            }
            case None => ()
        }

        // 步骤3: 安装到临时目录
        if (opts.noInstall) {
            logger.error("Could not find '${initialBinName}' binary. Stopping because --no-install was passed.")
            return
        }

        let installParam = "${updateName}@latest"
        let baoExe = Sys.getExecutablePath()

        logger.info("Installing ${installParam}...")

        // 创建缓存目录
        BaoFile.mkdir(cacheDir, true)

        // 创建空 package.json
        let pkgJsonPath = Path.join([cacheDir, "package.json"])
        BaoFile.writeAllText(pkgJsonPath, "{}\n")

        // 执行 bao add
        let installArgs = ArrayList<String>()
        installArgs.append(baoExe)
        installArgs.append("add")
        installArgs.append(installParam)
        installArgs.append("--no-summary")

        if (opts.silentInstall) {
            installArgs.append("--silent")
        }
        if (opts.verboseInstall) {
            installArgs.append("--verbose")
        }

        let exitCode = Process.spawn(installArgs.toArray(), cacheDir)
        match (exitCode) {
            case Some(code) => {
                if (code != 0) {
                    logger.error("Failed to install ${installParam}")
                    return
                }
            }
            case None => {
                logger.error("Failed to run install command")
                return
            }
        }

        // 步骤4: 查找安装后的 bin
        let binDir = Path.join([cacheDir, "node_modules", ".bin"])
        let binPath = Path.join([binDir, initialBinName])

        if (BaoFile.exists(binPath)) {
            runBinary(binPath, opts.passthroughArgs)
            return
        }

        // 步骤5: 如果初始名不对, 从 package.json 中读取实际的 bin 名称
        let actualBin = getBinNameFromPackageJson(cacheDir, updateName)
        match (actualBin) {
            case Some(name) => {
                let actualBinPath = Path.join([binDir, name])
                if (BaoFile.exists(actualBinPath)) {
                    runBinary(actualBinPath, opts.passthroughArgs)
                    return
                }
            }
            case None => ()
        }

        logger.error("Could not determine executable to run for package '${updateName}'")
    }

    /// 解析命令行参数
    // 严格翻译自: src/cli/bunx_command.zig Options.parse
    private func parseArgs(args: ArrayList<String>): XOptions {
        var foundPackageName = false
        var packageName = ""
        let passthrough = ArrayList<String>()
        var specifiedPackage: ?String = None
        var binaryName: ?String = None
        var noInstall = false
        var verbose = false
        var silent = false
        var runInBao = false

        var i = 0
        while (i < args.size) {
            let arg = args[i]
            if (!foundPackageName) {
                match (arg) {
                    case "--verbose" => verbose = true
                    case "--silent" => silent = true
                    case "--bun" | "-b" => runInBao = true
                    case "--no-install" => noInstall = true
                    case "--package" | "-p" => {
                        i++
                        if (i < args.size) {
                            specifiedPackage = Some(args[i])
                        }
                    }
                    case _ => {
                        if (arg.startsWith("--package=")) {
                            specifiedPackage = Some(arg.substring("--package=".length))
                        } else if (!arg.startsWith("-")) {
                            foundPackageName = true
                            packageName = arg
                        }
                    }
                }
            } else {
                // 所有后续参数传给命令
                passthrough.append(arg)
            }
            i++
        }

        // 如果有 --package, 包名是 --package 的值, 二进制名是位置参数
        match (specifiedPackage) {
            case Some(pkg) => {
                packageName = pkg
                // passthrough 的第一个是 binary name
                if (passthrough.size > 0) {
                    binaryName = Some(passthrough[0])
                    // 剩余的是真正的传参
                    let remaining = ArrayList<String>()
                    for (j in 1..passthrough.size) {
                        remaining.append(passthrough[j])
                    }
                    passthrough.clear()
                    for (r in remaining) { passthrough.append(r) }
                }
            }
            case None => ()
        }

        let opts = XOptions(packageName)
        opts.binaryName = binaryName
        opts.specifiedPackage = specifiedPackage
        opts.passthroughArgs = passthrough
        opts.runInBao = runInBao
        opts.noInstall = noInstall
        opts.verboseInstall = verbose
        opts.silentInstall = silent
        return opts
    }

    /// 在 node_modules/.bin 中查找二进制
    private func findInNodeModules(binName: String): ?String {
        let paths = [
            Path.join(["node_modules", ".bin", binName]),
            Path.join(["node_modules", ".bin", binName + Sys.exeSuffix()])
        ]
        for (p in paths) {
            if (BaoFile.exists(p)) {
                return Some(Path.resolve(p))
            }
        }
        return None
    }

    /// 在缓存目录中查找二进制
    private func findInCache(cacheDir: String, binName: String): ?String {
        let binPath = Path.join([cacheDir, "node_modules", ".bin", binName])
        if (BaoFile.exists(binPath)) {
            return Some(binPath)
        }
        return None
    }

    /// 检查缓存是否过期
    // 严格翻译自: src/cli/bunx_command.zig is_stale check
    private func isCacheStale(binPath: String): Bool {
        let modifiedTime = BaoFile.getModifiedTime(binPath)
        match (modifiedTime) {
            case Some(mtime) => {
                let now = Sys.currentTimeMillis() / 1000
                return (now - mtime) > CACHE_VALID_SECONDS
            }
            case None => return true
        }
    }

    /// 获取缓存目录路径
    // 严格翻译自: src/cli/bunx_command.zig bunx_cache_dir
    private func getCacheDir(packageName: String): String {
        let tmpDir = Sys.getTempDir()
        let uid = Sys.getUid()
        let safeName = packageName.replace("/", "-").replace("@", "")
        return Path.join([tmpDir, "baox-${uid}-${safeName}"])
    }

    /// 从 package.json 中读取 bin 名称
    // 严格翻译自: src/cli/bunx_command.zig getBinNameFromSubpath
    private func getBinNameFromPackageJson(dir: String, packageName: String): ?String {
        let pkgJsonPath = Path.join([dir, "node_modules", packageName, "package.json"])
        let content = BaoFile.readAllText(pkgJsonPath)
        match (content) {
            case Some(text) => {
                let parser = JsonParser()
                let json = parser.parse(text)
                match (json) {
                    case Some(root) => {
                        // bin 可以是 string 或 object
                        match (JsonHelper.getField(root, "bin")) {
                            case Some(JsonValue.Str(path)) => {
                                // bin 是字符串, 用 name 字段
                                return JsonHelper.getString(root, "name")
                            }
                            case Some(JsonValue.Object(binMap)) => {
                                // bin 是 map, 取第一个 key
                                let keys = binMap.keys()
                                if (keys.size > 0) {
                                    return Some(keys[0])
                                }
                            }
                            case _ => ()
                        }

                        // 检查 directories.bin
                        match (JsonHelper.getField(root, "directories")) {
                            case Some(JsonValue.Object(dirs)) => {
                                match (dirs.get("bin")) {
                                    case Some(_) => {
                                        // 遍历目录
                                        let binDir = Path.join([dir, "node_modules", packageName,
                                            JsonHelper.getString(dirs, "bin") ?? "bin"])
                                        let entries = BaoFile.readdir(binDir)
                                        for (entry in entries) {
                                            if (entry != "." && entry != "..") {
                                                return Some(entry)
                                            }
                                        }
                                    }
                                    case _ => ()
                                }
                            }
                            case _ => ()
                        }
                    }
                    case None => ()
                }
            }
            case None => ()
        }
        return None
    }

    /// 运行二进制
    // 严格翻译自: src/cli/bunx_command.zig Run.runBinary
    private func runBinary(binPath: String, args: ArrayList<String>): Unit {
        let allArgs = ArrayList<String>()
        allArgs.append(binPath)
        for (a in args) { allArgs.append(a) }

        // exec 替换当前进程 (或 spawn 等待)
        let result = Process.exec(allArgs.toArray(), ".")
        // exec 不应返回, 如果返回则出错
        logger.error("Failed to execute: ${binPath}")
    }

    /// 打印 x 命令帮助
    private func printXHelp(): Unit {
        println("Usage: bao x <package> [args...] [options]")
        println("")
        println("Execute a package binary")
        println("")
        println("Options:")
        println("  --package <name>  Specify package name explicitly")
        println("  --bun, -b         Run with Bao runtime")
        println("  --no-install      Only run if already installed")
        println("  --silent          Silent install output")
        println("  --verbose         Verbose install output")
        println("  --help, -h        Print this help")
        println("")
        println("Examples:")
        println("  bao x cowsay Hello!")
        println("  bao x tsc --init")
        println("  bao x --package=typescript tsc --init")
    }

    /// 给包名添加 "create-" 前缀
    // 严格翻译自: src/cli/bunx_command.zig addCreatePrefix
    public static func addCreatePrefix(input: String): String {
        if (input.isEmpty()) { return input }
        if (input.startsWith("@")) {
            let slashIdx = input.indexOf("/")
            match (slashIdx) {
                case Some(idx) => {
                    // @org/some -> @org/create-some
                    return input.substring(0, idx + 1) + "create-" + input.substring(idx + 1)
                }
                case None => {
                    // @org -> @org/create
                    return input + "/create"
                }
            }
        }
        return "create-" + input
    }
}
