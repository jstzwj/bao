// 严格翻译自: src/cli/remove_command.zig, src/cli/install_command.zig
// bao remove - 移除包依赖
package bao_cli

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// remove 命令 - 对应 bun remove <package...>
// 严格翻译自: src/cli/remove_command.zig (RemoveCommand.exec)
// ============================================================================

/// remove 命令选项
/// 对应 Bun: src/cli/remove_command.zig
public class RemoveOptions {
    /// 要移除的包名列表
    public var packages: ArrayList<String>
    /// 全局移除 (--global / -g)
    public var global: Bool
    /// 不执行安装, 只更新 package.json (--no-install)
    public var noInstall: Bool
    /// 强制 (--force)
    public var force: Bool

    public init() {
        packages = ArrayList<String>()
        global = false
        noInstall = false
        force = false
    }
}

/// remove 命令执行器
/// 严格翻译自: src/cli/remove_command.zig RemoveCommand.exec
/// 核心流程: 解析参数 -> 读取 package.json -> 移除依赖字段 -> 调用安装器清理
public class RemoveCommand {
    private var logger: Logger
    private var config: ?Config

    public init() {
        logger = Logger()
        config = None
    }

    /// 执行 remove 命令
    // 严格翻译自: src/cli/remove_command.zig exec -> updatePackageJSONAndInstallCatchError
    public func execute(args: ArrayList<String>): Unit {
        let opts = parseArgs(args)
        if (opts.packages.size == 0) {
            logger.error("No packages specified. Usage: bao remove <package...>")
            return
        }

        // 加载配置
        match (config) {
            case Some(_) => {}
            case None => config = Some(Config.load("."))
        }

        // 读取 package.json
        let pkgOpt = readPackageJson(".")
        let pkg = match (pkgOpt) {
            case Some(p) => p
            case None => {
                logger.error("No package.json found in current directory")
                return
            }
        }

        var anyRemoved = false
        var notFound = ArrayList<String>()

        for (pkgName in opts.packages) {
            let removed = tryRemoveFromPackageJson(pkg, pkgName)
            if (removed) {
                anyRemoved = true
                logger.info("Removed ${pkgName} from package.json")
            } else {
                notFound.append(pkgName)
            }
        }

        // 报告未找到的包
        if (notFound.size > 0) {
            for (name in notFound) {
                logger.warn("Package '${name}' not found in any dependency field")
            }
        }

        if (!anyRemoved) {
            logger.warn("No packages were removed")
            return
        }

        // 保存更新后的 package.json
        pkg.save(".")

        if (opts.noInstall) {
            logger.info("Skipping install (--no-install)")
            return
        }

        // 调用安装器重新解析依赖树
        // 严格翻译自: src/install/install.zig updatePackageJSONAndInstall
        let pm = PackageManager()
        let installOpts = InstallOptions()
        installOpts.force = opts.force

        try {
            logger.info("Reinstalling to clean up...")
            let result = pm.install(installOpts)
            match (result) {
                case Some(summary) => {
                    logger.success("Removed ${opts.packages.size} package(s)")
                    if (summary.removed > 0) {
                        logger.info("Cleaned up ${summary.removed} unused packages")
                    }
                }
                case None => {}
            }
        } catch (e: Exception) {
            logger.error("Post-remove install failed: ${e.message}")
        }
    }

    /// 尝试从 package.json 的所有依赖字段中移除包
    // 严格翻译自: src/cli/remove_command.zig 中的依赖移除逻辑
    private func tryRemoveFromPackageJson(pkg: MutablePackageJson, name: String): Bool {
        var removed = false

        // dependencies
        if (pkg.removeDependency(name)) {
            removed = true
        }
        // devDependencies
        if (pkg.removeDevDependency(name)) {
            removed = true
        }
        // optionalDependencies
        if (pkg.removeOptionalDependency(name)) {
            removed = true
        }
        // peerDependencies
        if (pkg.removePeerDependency(name)) {
            removed = true
        }
        // trustedDependencies
        if (pkg.removeTrustedDependency(name)) {
            removed = true
        }

        return removed
    }

    /// 解析命令行参数
    private func parseArgs(args: ArrayList<String>): RemoveOptions {
        let opts = RemoveOptions()
        var i = 0

        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--global" | "-g" => opts.global = true
                case "--no-install" => opts.noInstall = true
                case "--force" => opts.force = true
                case "--verbose" | "-v" => logger.setLevel(LogLevel.DEBUG)
                case "--help" | "-h" => {
                    printRemoveHelp()
                    return opts
                }
                case _ => {
                    // 包名参数
                    if (!arg.startsWith("-")) {
                        opts.packages.append(arg)
                    } else {
                        logger.warn("Unknown option: ${arg}")
                    }
                }
            }
            i++
        }

        return opts
    }

    /// 读取 package.json
    private func readPackageJson(dir: String): ?MutablePackageJson {
        let content = BaoFile.readAllText(Path.join([dir, "package.json"]))
        match (content) {
            case Some(text) => {
                let parser = JsonParser()
                let json = parser.parse(text)
                match (json) {
                    case Some(root) => return MutablePackageJson.fromJson(root)
                    case None => return None
                }
            }
            case None => return None
        }
    }

    /// 打印 remove 命令帮助
    private func printRemoveHelp(): Unit {
        println("Usage: bao remove <package...> [options]")
        println("")
        println("Remove packages from package.json and uninstall them")
        println("")
        println("Options:")
        println("  --global, -g     Remove global package")
        println("  --no-install     Only update package.json, skip reinstall")
        println("  --force          Force cleanup")
        println("  --verbose, -v    Verbose output")
        println("  --help, -h       Print this help")
        println("")
        println("Examples:")
        println("  bao remove lodash")
        println("  bao remove react react-dom")
        println("  bao remove @types/node")
    }
}
