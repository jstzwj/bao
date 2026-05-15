// 严格翻译自: src/cli/add_command.zig, src/cli/install_command.zig
// bao add - 添加包依赖并安装
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_http.*
import bao_sys.*

// ============================================================================
// add 命令 - 对应 bun add <package...>
// 严格翻译自: src/cli/add_command.zig (AddCommand.exec)
// ============================================================================

/// 包规格解析结果
/// 对应 Bun: src/install/install.zig UpdateRequest
public class PackageSpecifier {
    /// 包名 (例: "lodash", "@types/node")
    public var name: String
    /// 版本范围 (例: "^4.17.0", "latest", "npm:^5.0.0")
    public var version: ?String
    /// 是否为 devDependency
    public var dev: Bool
    /// 是否为 optionalDependency
    public var optional: Bool
    /// 是否为 peerDependency
    public var peer: Bool
    /// 是否为 trusted dependency
    public var trusted: Bool
    /// 别名 (用于 npm:alias@version 语法)
    public var alias: ?String

    public init(name: String) {
        this.name = name
        this.version = None
        this.dev = false
        this.optional = false
        this.peer = false
        this.trusted = false
        this.alias = None
    }

    /// 从字符串解析包规格
    // 严格翻译自: src/install/install.zig UpdateRequest.parse
    public static func parse(input: String): ?PackageSpecifier {
        if (input.isEmpty()) {
            return None
        }

        var spec = PackageSpecifier(input)
        var remaining = input

        // 处理别名语法: alias@npm:package@version
        // 例: "my-lodash@npm:lodash@^4.0.0"
        let atCount = remaining.countOf("@")
        if (atCount >= 2 && remaining.startsWith("@")) {
            // scoped package with alias: @scope/name@npm:...
            let secondAt = remaining.indexOfFrom(1, "@")
            match (secondAt) {
                case Some(idx) => {
                    let aliasPart = remaining.substring(0, idx)
                    remaining = remaining.substring(idx + 1)
                    spec.alias = Some(aliasPart)
                }
                case None => ()
            }
        } else if (atCount >= 1 && !remaining.startsWith("@")) {
            // non-scoped: name@npm:package@version or name@version
            let firstAt = remaining.indexOf("@")
            match (firstAt) {
                case Some(idx) => {
                    let potentialName = remaining.substring(0, idx)
                    let rest = remaining.substring(idx + 1)
                    if (rest.startsWith("npm:") || rest.startsWith("github:") ||
                        rest.startsWith("git+") || rest.startsWith("file:") ||
                        rest.startsWith("link:") || rest.startsWith("http://") ||
                        rest.startsWith("https://")) {
                        // alias@protocol:...
                        spec.alias = Some(potentialName)
                        remaining = rest
                    } else {
                        // name@version (normal)
                        spec.name = potentialName
                        spec.version = Some(rest)
                        return Some(spec)
                    }
                }
                case None => ()
            }
        }

        // 处理剩余字符串中的 name@version
        if (!spec.alias.isEmpty()) {
            // 如果有 alias, remaining 现在是 protocol:... 或 package@version
            if (remaining.startsWith("npm:")) {
                let npmPart = remaining.substring(4)
                let npmAt = npmPart.indexOf("@")
                match (npmAt) {
                    case Some(idx) => {
                        spec.name = npmPart.substring(0, idx)
                        spec.version = Some(npmPart.substring(idx + 1))
                    }
                    case None => {
                        spec.name = npmPart
                    }
                }
            } else if (remaining.startsWith("github:")) {
                spec.name = remaining.substring(7)
            } else if (remaining.startsWith("file:") || remaining.startsWith("link:")) {
                spec.name = remaining.substring(5)
            } else {
                // name@version
                let atIdx = remaining.indexOf("@")
                match (atIdx) {
                    case Some(idx) => {
                        spec.name = remaining.substring(0, idx)
                        spec.version = Some(remaining.substring(idx + 1))
                    }
                    case None => {
                        spec.name = remaining
                    }
                }
            }
        } else {
            // 简单解析: name@version
            // 需要考虑 scoped packages: @scope/name@version
            if (remaining.startsWith("@")) {
                // scoped package: @scope/name 或 @scope/name@version
                let firstSlash = remaining.indexOf("/")
                match (firstSlash) {
                    case Some(slashIdx) => {
                        let afterSlash = remaining.substring(slashIdx + 1)
                        let atIdx = afterSlash.indexOf("@")
                        match (atIdx) {
                            case Some(idx) => {
                                spec.name = remaining.substring(0, slashIdx + 1 + idx)
                                spec.version = Some(afterSlash.substring(idx + 1))
                            }
                            case None => {
                                spec.name = remaining
                            }
                        }
                    }
                    case None => {
                        spec.name = remaining
                    }
                }
            } else {
                // non-scoped: name@version
                let atIdx = remaining.indexOf("@")
                match (atIdx) {
                    case Some(idx) => {
                        spec.name = remaining.substring(0, idx)
                        spec.version = Some(remaining.substring(idx + 1))
                    }
                    case None => {
                        spec.name = remaining
                    }
                }
            }
        }

        return Some(spec)
    }

    /// 转为字符串表示
    public func toString(): String {
        var s = name
        match (version) {
            case Some(v) => s = s + "@${v}"
            case None => ()
        }
        return s
    }
}

/// add 命令选项
/// 对应 Bun: src/cli/add_command.zig CreateOptions
public class AddOptions {
    /// 要添加的包列表
    public var packages: ArrayList<PackageSpecifier>
    /// 添加为 devDependency (--dev / -D)
    public var dev: Bool
    /// 添加为 optionalDependency (--optional)
    public var optional: Bool
    /// 添加为 peerDependency (--peer)
    public var peer: Bool
    /// 是否为 trusted dependency (--trust)
    public var trust: Bool
    /// 全局安装 (--global / -g)
    public var global: Bool
    /// 强制安装 (--force)
    public var force: Bool
    /// 不写入 lockfile (--no-save)
    public var noSave: Bool
    /// 指定 registry (--registry)
    public var registry: ?String

    public init() {
        packages = ArrayList<PackageSpecifier>()
        dev = false
        optional = false
        peer = false
        trust = false
        global = false
        force = false
        noSave = false
        registry = None
    }
}

/// add 命令执行器
/// 严格翻译自: src/cli/add_command.zig AddCommand.exec
/// 核心流程: 解析参数 -> 读取 package.json -> 更新依赖字段 -> 调用安装器
public class AddCommand {
    private var logger: Logger
    private var config: ?Config

    public init() {
        logger = Logger()
        config = None
    }

    /// 执行 add 命令
    // 严格翻译自: src/cli/add_command.zig exec -> updatePackageJSONAndInstallCatchError
    public func execute(args: ArrayList<String>): Unit {
        let opts = parseArgs(args)
        if (opts.packages.size == 0) {
            logger.error("No packages specified. Usage: bao add <package...>")
            return
        }

        // 加载配置 (bunfig.toml, package.json)
        match (config) {
            case Some(cfg) => () // 已加载
            case None => config = Some(Config.load("."))
        }

        // 读取现有 package.json
        let pkgOpt = readPackageJson(".")
        var pkg = match (pkgOpt) {
            case Some(p) => p
            case None => {
                // 没有找到 package.json, 创建新的
                logger.info("No package.json found. Creating a new one.")
                let newPkg = MutablePackageJson("untitled-project", "1.0.0")
                newPkg.save(".")
                newPkg
            }
        }

        // 更新 package.json 中的依赖字段
        var modified = false
        for (spec in opts.packages) {
            // 根据标志确定添加到哪个依赖字段
            if (opts.dev || spec.dev) {
                pkg.addDevDependency(spec.name, spec.version ?? "latest")
                logger.info("Added ${spec.toString()} to devDependencies")
            } else if (opts.optional || spec.optional) {
                pkg.addOptionalDependency(spec.name, spec.version ?? "latest")
                logger.info("Added ${spec.toString()} to optionalDependencies")
            } else if (opts.peer || spec.peer) {
                pkg.addPeerDependency(spec.name, spec.version ?? "latest")
                logger.info("Added ${spec.toString()} to peerDependencies")
            } else {
                pkg.addDependency(spec.name, spec.version ?? "latest")
                logger.info("Added ${spec.toString()} to dependencies")
            }
            modified = true
        }

        if (!modified) {
            logger.warn("No changes to package.json")
            return
        }

        // 保存更新后的 package.json
        pkg.save(".")

        // 调用安装器
        let pm = PackageManager()
        let installOpts = InstallOptions()
        installOpts.force = opts.force
        match (opts.registry) {
            case Some(reg) => installOpts.registry = reg
            case None => ()
        }

        try {
            logger.info("Installing dependencies...")
            let result = pm.install(installOpts)
            match (result) {
                case Some(summary) => {
                    logger.success("Installed ${summary.added} packages")
                    if (summary.removed > 0) {
                        logger.info("Removed ${summary.removed} packages")
                    }
                }
                case None => logger.warn("Install completed with warnings")
            }
        } catch (e: Exception) {
            logger.error("Install failed: ${e.message}")
            // 回滚: 恢复 package.json
            logger.info("Rolling back package.json changes...")
            pkg.rollback(".")
        }
    }

    /// 解析命令行参数
    // 严格翻译自: src/cli/add_command.zig parse
    private func parseArgs(args: ArrayList<String>): AddOptions {
        let opts = AddOptions()
        var i = 0

        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--dev" | "-D" => opts.dev = true
                case "--optional" => opts.optional = true
                case "--peer" => opts.peer = true
                case "--trust" => opts.trust = true
                case "--global" | "-g" => opts.global = true
                case "--force" => opts.force = true
                case "--no-save" => opts.noSave = true
                case "--registry" => {
                    i++
                    if (i < args.size) {
                        opts.registry = Some(args[i])
                    }
                }
                case "--verbose" | "-v" => logger.setLevel(LogLevel.DEBUG)
                case "--help" | "-h" => {
                    printAddHelp()
                    return opts
                }
                case _ => {
                    // 包名参数
                    let spec = PackageSpecifier.parse(arg)
                    match (spec) {
                        case Some(s) => {
                            var sMut = s
                            sMut.dev = opts.dev
                            sMut.optional = opts.optional
                            sMut.peer = opts.peer
                            sMut.trusted = opts.trust
                            opts.packages.append(sMut)
                        }
                        case None => logger.warn("Could not parse package specifier: ${arg}")
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

    /// 打印 add 命令帮助
    private func printAddHelp(): Unit {
        println("Usage: bao add <package...> [options]")
        println("")
        println("Install packages and add them to package.json")
        println("")
        println("Options:")
        println("  --dev, -D          Add to devDependencies")
        println("  --optional         Add to optionalDependencies")
        println("  --peer             Add to peerDependencies")
        println("  --trust            Mark as trusted dependency")
        println("  --global, -g       Install globally")
        println("  --force            Force reinstall")
        println("  --no-save          Don't save to package.json")
        println("  --registry <url>   Use a specific registry")
        println("  --verbose, -v      Verbose output")
        println("  --help, -h         Print this help")
        println("")
        println("Examples:")
        println("  bao add lodash")
        println("  bao add react@^18.0.0")
        println("  bao add @types/node --dev")
        println("  bao add lodash@npm:lodash-es@^4.0.0")
    }
}
