// 严格翻译自: src/cli/package_manager_command.rs
// 对应 Bun: package_manager_command.zig — PM 子命令中央分发器
//
// PackageManagerCommand 是 "bao pm" 的主入口, 分发到各子命令:
//   ls, bin, cache, hash, whoami, view, trust, untrusted, version, why, pkg, migrate, scan, pack
//
// 也包含 printHash (用于 "bao ./bun.lockb --hash") 和
// printNodeModulesTree / ByName sorter 等工具函数
package bao_cli

import bao_core.*
import bao_install.*
import bao_collections.*

// ============================================================================
// NodeModulesFolder — node_modules 目录快照
// 严格翻译自: src/cli/package_manager_command.rs - NodeModulesFolder
//
// 对应 Bun 中 Lockfile.Tree.Iterator(.node_modules).Next 的拥有快照
// ============================================================================

/// node_modules 文件夹信息
/// 对应 Bun: NodeModulesFolder
public class NodeModulesFolder {
    public var relativePath: String
    public var dependencies: ArrayList<Int64>  // DependencyID 列表
    public var treeId: Int64
    public var depth: Int64

    public init() {
        relativePath = ""
        dependencies = ArrayList<Int64>()
        treeId = 0
        depth = 0
    }
}

// ============================================================================
// ByName — 按名称排序的比较器
// 严格翻译自: src/cli/package_manager_command.rs - ByName
// ============================================================================

/// 按名称排序比较器
/// 对应 Bun: ByName
public class ByName {
    public var dependencies: ArrayList<Dependency>
    public var buf: String

    public init(dependencies: ArrayList<Dependency>, buf: String) {
        this.dependencies = dependencies
        this.buf = buf
    }

    /// 比较 (对应 Bun: ByName.cmp)
    public func compare(lhs: Int64, rhs: Int64): Int64 {
        let lhsName = dependencies[lhs].name.slice(buf)
        let rhsName = dependencies[rhs].name.slice(buf)
        return lhsName.compareTo(rhsName)
    }
}

// ============================================================================
// PackageManagerCommand — PM 子命令中央分发器
// 严格翻译自: src/cli/package_manager_command.rs - PackageManagerCommand
// ============================================================================

/// PM 子命令分发器
/// 对应 Bun: PackageManagerCommand
public class PackageManagerCommand {
    /// 处理 lockfile 加载错误
    /// 对应 Bun: handle_load_lockfile_errors
    /// LogLevel 参数控制是否静默
    public static func handleLoadLockfileErrors(result: LoadLockfileResult, logLevel: LogLevel): Unit {
        let notSilent = (logLevel != LogLevel.silent)

        when (result) {
            case LoadLockfileResult.notFound => {
                if (notSilent) {
                    Output.errGeneric("Lockfile not found")
                }
                Global.exit(1)
            }
            case LoadLockfileResult.err(e) => {
                if (notSilent) {
                    Output.errGeneric("Error loading lockfile: ${e.name}")
                }
                Global.exit(1)
            }
            case LoadLockfileResult.ok => ()
        }
    }

    /// 向后兼容版本
    public static func handleLoadLockfileErrors(result: LoadLockfileResult, pm: PackageManager): Unit {
        handleLoadLockfileErrors(result, pm.options.logLevel)
    }

    /// 打印 lockfile hash (用于 "bao ./bun.lockb --hash")
    /// 对应 Bun: print_hash
    public static func printHash(ctx: CommandContext): Unit {
        let cli = PackageManager.CommandLineArguments.parse(Subcommand.pm)
        val (pm, cwd) = match (PackageManager.init(ctx, cli, Subcommand.pm)) {
            case Some((pm, dir)) => (pm, dir)
            case None => {
                Output.errGeneric("Failed to initialize package manager")
                Global.exit(1)
            }
        }

        // 读取 lockfile 文件并计算 hash
        let lockfilePath = ctx.args.entryPoints[0]
        let bytes = BaoFile.readAllBytes(lockfilePath)
        if (bytes == None) {
            Output.errGeneric("failed to read lockfile")
            Global.crash()
        }

        let hash = CryptoHasher.hash(bytes!!, Algorithm.sha256)
        Output.println(hash.toHexString())
    }

    /// node_modules 目录树打印
    /// 对应 Bun: PackageManagerCommand ls 子命令中的树形打印
    public static func printNodeModulesTree(pm: PackageManager): Unit {
        let packages = pm.lockfile.packages

        Output.prettyLn("node_modules:")
        for (pkgIdx in 0..packages.length) {
            let pkgName = packages.getName(pkgIdx)
            if (pkgName.length > 0) {
                let version = packages.getResolution(pkgIdx).formatVersion()
                Output.prettyLn("  ${pkgName}@${version}")
            }
        }
    }

    /// 按名称排序
    /// 对应 Bun: ByName sorter
    public static func sortByName(names: ArrayList<String>): Unit {
        names.sort()
    }

    // ========================================================================
    // 子命令实现
    // ========================================================================

    /// ls 子命令: 列出安装的包
    /// 对应 Bun: ls 子命令 — 使用 tree iterator 遍历 node_modules
    public static func execLs(ctx: CommandContext, pm: PackageManager): Unit {
        let logLevel = pm.options.logLevel
        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        handleLoadLockfileErrors(loadLockfile, logLevel)

        // 检查是否需要更新 lockfile
        if (loadLockfile.serializerResult != None && loadLockfile.serializerResult!!.packagesNeedUpdate) {
            updateLockfileIfNeeded(pm, loadLockfile)
        }

        let lockfile = pm.lockfile
        let packages = lockfile.packages
        let resolutions = packages.itemsResolution()
        let buf = lockfile.buffers.stringBytes
        let dependencies = lockfile.buffers.dependencies

        // 使用 tree iterator 遍历
        let treeIterator = TreeIterator.init(lockfile)
        let byName = ByName(dependencies, buf)
        var allDeps = ArrayList<Int64>()
        var seen = HashSet<Int64>()

        while (true) {
            let nodeModules = treeIterator.next()
            if (nodeModules == None) {
                break
            }
            let nm = nodeModules!!
            for (depId in nm.dependencies) {
                if (!seen.contains(depId)) {
                    seen.add(depId)
                    allDeps.append(depId)
                }
            }
        }

        // 按名称排序
        allDeps.sort { a, b =>
            let nameA = dependencies[a].name.slice(buf)
            let nameB = dependencies[b].name.slice(buf)
            nameA.compareTo(nameB)
        }

        // 打印
        for (depId in allDeps) {
            let dep = dependencies[depId]
            let alias = dep.name.slice(buf)
            let packageId = lockfile.buffers.resolutions[depId]
            if (packageId == INVALID_PACKAGE_ID) {
                continue
            }
            let resolution = resolutions[packageId]
            Output.println(alias)
        }
    }

    /// bin 子命令: 显示 bin 目录
    /// 对应 Bun: bin 子命令 — 支持 -g 全局 bin 路径
    public static func execBin(ctx: CommandContext, pm: PackageManager): Unit {
        // 检查是否指定 -g/--global
        var global = false
        for (arg in ctx.positionals) {
            if (arg == "-g" || arg == "--global") {
                global = true
            }
        }

        if (global) {
            let globalBinDir = getGlobalBinDirectory()
            Output.println(globalBinDir)
        } else {
            let cwd = FileSystem.instance.topLevelDir
            let binPath = Path.join(cwd, "node_modules", ".bin")
            if (BaoFile.exists(binPath)) {
                Output.println(binPath)
            } else {
                Output.println("(no bin directory found)")
            }
        }
    }

    /// 获取全局 bin 目录
    /// 对应 Bun: setup_global_dir / get_cache_directory
    private static func getGlobalBinDirectory(): String {
        let cacheDir = getCacheDirectory()
        return Path.join(cacheDir, "bin")
    }

    /// 获取缓存目录
    /// 对应 Bun: get_cache_directory
    private static func getCacheDirectory(): String {
        let homeDir = Environment.get("HOME") ?: Environment.get("USERPROFILE") ?: "/tmp"
        return Path.join(homeDir, ".bao", "install", "cache")
    }

    /// cache 子命令: 显示/管理缓存
    /// 对应 Bun: cache 子命令 — 支持 rm 清除缓存
    public static func execCache(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        if (positionals.size > 0 && positionals[0] == "rm") {
            // 清除缓存
            let cacheDir = getCacheDirectory()
            if (BaoFile.exists(cacheDir)) {
                BaoFile.removeDirectory(cacheDir)
                Output.println("Cache cleared")
            } else {
                Output.println("Cache directory not found")
            }
        } else {
            let cacheDir = getCacheDirectory()
            Output.println("Cache directory: ${cacheDir}")
        }
    }

    /// hash 子命令: 打印 lockfile hash
    /// 对应 Bun: hash 子命令
    public static func execHash(ctx: CommandContext, pm: PackageManager): Unit {
        let logLevel = pm.options.logLevel
        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        handleLoadLockfileErrors(loadLockfile, logLevel)
        Output.println(pm.lockfile.hash())
    }

    /// hash-print 子命令: 打印 lockfile hash (字符串形式)
    /// 对应 Bun: hash-print 子命令
    public static func execHashPrint(ctx: CommandContext, pm: PackageManager): Unit {
        let logLevel = pm.options.logLevel
        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        handleLoadLockfileErrors(loadLockfile, logLevel)
        let hash = pm.lockfile.hash()
        Output.println("sha256-${hash.toHexString()}")
    }

    /// whoami 子命令
    /// 对应 Bun: whoami 子命令 — 向 registry 验证身份
    public static func execWhoami(ctx: CommandContext, pm: PackageManager): Unit {
        let scope = pm.options.scope
        if (scope.token.length > 0) {
            // 尝试调用 npm whoami API
            let url = "${Strings.withoutTrailingSlash(scope.url.href)}/-/whoami"
            let headers = HashMap<String, String>()
            headers.put("accept", "application/json")
            headers.put("authorization", "Bearer ${scope.token}")

            let response = HttpClient.getSynchronous(url, headers)
            if (response != None) {
                let json = JsonParser.parse(response!!)
                if (json != None && json!!.isObject()) {
                    let username = json!!.asObject().get("username")
                    if (username != None && username!!.isString()) {
                        Output.println(username!!.asString())
                        return
                    }
                }
            }
            Output.println("Authenticated (token present)")
        } else {
            Output.errGeneric("Not authenticated. Run 'bao login' first.")
        }
    }

    /// view 子命令: 委托给 PmViewCommand
    public static func execView(ctx: CommandContext, pm: PackageManager): Unit {
        PmViewCommand.exec(ctx, pm)
    }

    /// trust 子命令: 委托给 PmTrustedCommand
    public static func execTrust(ctx: CommandContext, pm: PackageManager): Unit {
        PmTrustedCommand.execTrust(ctx, pm)
    }

    /// default-trusted 子命令: 委托给 DefaultTrustedCommand
    public static func execDefaultTrusted(): Unit {
        DefaultTrustedCommand.exec()
    }

    /// untrusted 子命令: 委托给 PmTrustedCommand
    public static func execUntrusted(ctx: CommandContext, pm: PackageManager): Unit {
        PmTrustedCommand.execUntrusted(ctx, pm)
    }

    /// version 子命令: 委托给 PmVersionCommand
    public static func execVersion(ctx: CommandContext, pm: PackageManager): Unit {
        PmVersionCommand.exec(ctx, pm)
    }

    /// why 子命令: 委托给 WhyCommand
    public static func execWhy(ctx: CommandContext, pm: PackageManager, positionals: ArrayList<String>): Unit {
        PmWhyCommand.exec(ctx, pm, positionals)
    }

    /// pkg 子命令: 委托给 PmPkgCommand
    public static func execPkg(ctx: CommandContext, pm: PackageManager): Unit {
        PmPkgCommand.exec(ctx, pm)
    }

    /// migrate 子命令
    /// 对应 Bun: migrate — 转换 yarn.lock / package-lock.json 等
    public static func execMigrate(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        var target = "bao.lockb"
        if (positionals.size > 0) {
            target = positionals[0]
        }

        // 检测现有 lockfile 类型并迁移
        if (BaoFile.exists("yarn.lock")) {
            Output.println("Migrating from yarn.lock...")
            Migration.migrateFromYarn(pm)
        } else if (BaoFile.exists("package-lock.json")) {
            Output.println("Migrating from package-lock.json...")
            Migration.migrateFromNpm(pm)
        } else if (BaoFile.exists("pnpm-lock.yaml")) {
            Output.println("Migrating from pnpm-lock.yaml...")
            Migration.migrateFromPnpm(pm)
        } else {
            Output.println("No recognized lockfile found to migrate")
        }

        Output.println("Migration complete")
    }

    /// scan 子命令: 委托给 ScanCommand
    public static func execScan(ctx: CommandContext, pm: PackageManager, cwd: String): Unit {
        ScanCommand.execWithManager(ctx, pm, cwd)
    }

    /// pack 子命令
    /// 对应 Bun: pack 子命令 — 创建 tarball
    public static func execPack(ctx: CommandContext, pm: PackageManager): Unit {
        // 委托给 PackCommand
        PackCommand.execPackFromPm(ctx, pm)
    }

    // ========================================================================
    // 主 exec 分发器
    // ========================================================================

    /// 主分发器: 解析子命令并分发到对应处理器
    /// 对应 Bun: PackageManagerCommand.exec 中的 match subcommand 分发
    public static func exec(ctx: CommandContext): Unit {
        let cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.pm)
        val (pm, cwd) = match (PackageManager.init(ctx, cli, Subcommand.pm)) {
            case Some((pm, dir)) => (pm, dir)
            case None => {
                Output.errGeneric("Failed to initialize package manager")
                Global.exit(1)
            }
        }

        // 根据子命令分发
        let subcommand = cli.subcommand
        when (subcommand) {
            case PmSubcommand.ls => execLs(ctx, pm)
            case PmSubcommand.bin => execBin(ctx, pm)
            case PmSubcommand.cache => execCache(ctx, pm)
            case PmSubcommand.hash => execHash(ctx, pm)
            case PmSubcommand.hashPrint => execHashPrint(ctx, pm)
            case PmSubcommand.whoami => execWhoami(ctx, pm)
            case PmSubcommand.view => execView(ctx, pm)
            case PmSubcommand.trust => execTrust(ctx, pm)
            case PmSubcommand.untrusted => execUntrusted(ctx, pm)
            case PmSubcommand.defaultTrusted => execDefaultTrusted()
            case PmSubcommand.version => execVersion(ctx, pm)
            case PmSubcommand.why => execWhy(ctx, pm, ctx.positionals)
            case PmSubcommand.pkg => execPkg(ctx, pm)
            case PmSubcommand.migrate => execMigrate(ctx, pm)
            case PmSubcommand.scan => execScan(ctx, pm, cwd)
            case PmSubcommand.pack => execPack(ctx, pm)
            else => {
                Output.errGeneric("Unknown pm subcommand")
                printHelp()
            }
        }
    }

    /// 打印 pm 帮助信息
    /// 对应 Bun: tag_print_help(PackageManagerCommand)
    public static func printHelp(): Unit {
        Output.prettyLn(
            "<r><b>Usage<r>: <b><green>bao pm<r> <cyan>[flags]<r> <blue>[\\<command\\>]<r>\n" +
            "  Run package manager utilities.\n\n" +
            "<b>Commands<r>:\n" +
            "  <b><green>bao pm<r> <blue>ls<r>               list the dependency tree according to the current lockfile\n" +
            "  <b><green>bao pm<r> <blue>bin<r>              print the path to bin folder\n" +
            "  <b><green>bao pm<r> <blue>whoami<r>           print the current npm username\n" +
            "  <b><green>bao pm<r> <blue>hash<r>             generate & print the hash of the current lockfile\n" +
            "  <b><green>bao pm<r> <blue>hash-print<r>       print the hash of the lockfile as a string\n" +
            "  <b><green>bao pm<r> <blue>cache<r>            print the path to the cache folder\n" +
            "  <b><green>bao pm<r> <blue>cache rm<r>         clear the cache\n" +
            "  <b><green>bao pm<r> <blue>view<r>             view package metadata from the registry\n" +
            "  <b><green>bao pm<r> <blue>trust<r>            trust lifecycle scripts for packages\n" +
            "  <b><green>bao pm<r> <blue>untrusted<r>        show untrusted packages with lifecycle scripts\n" +
            "  <b><green>bao pm<r> <blue>version<r>          manage package version\n" +
            "  <b><green>bao pm<r> <blue>pkg<r>              manage data in package.json\n" +
            "  <b><green>bao pm<r> <blue>migrate<r>          migrate from another lockfile format\n" +
            "  <b><green>bao pm<r> <blue>scan<r>             scan for vulnerabilities\n" +
            "  <b><green>bao pm<r> <blue>pack<r>             create a tarball from a package\n\n" +
            "Learn more about these at <magenta>https://bao.dev/docs/cli/pm<r>"
        )
        Output.flush()
    }
}
