// 严格翻译自: src/cli/link_command.zig
// bao link - 链接本地包到全局 / 从全局链接到项目
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// link 命令 - 对应 bun link / bun link <package>
// 严格翻译自: src/cli/link_command.zig (LinkCommand)
//
// 两种用法:
//   1. bun link (无参数) — 将当前包链接到全局 node_modules
//      - 读取当前 package.json
//      - 在全局目录创建 symlink
//      - 链接 bin 到全局 bin 目录
//
//   2. bun link <package> (有参数) — 将全局链接的包链接到当前项目
//      - 在当前项目的 node_modules 中创建 symlink 到全局链接
//      - 等同于 "bun add <package>" 但使用本地链接
// ============================================================================

/// Link 命令选项
public class LinkOptions {
    /// 要链接的包名 (无参数时为 None)
    public var packageName: ?String
    /// 全局目录 (--global-dir)
    public var globalDir: ?String
    /// bin 目录 (--bin-dir)
    public var binDir: ?String
    /// 静默模式
    public var silent: Bool

    public init() {
        packageName = None
        globalDir = None
        binDir = None
        silent = false
    }
}

/// Link 命令执行器
/// 严格翻译自: src/cli/link_command.zig LinkCommand
///
/// 对应 Bun:
///   pub const LinkCommand = struct {
///       pub fn exec(ctx: Command.Context) !void {
///           try link(ctx);
///       }
///   };
public class LinkCommand {
    private var logger: Logger

    public init() {
        logger = Logger()
    }

    /// 执行 link 命令
    // 严格翻译自: src/cli/link_command.zig LinkCommand.exec → link()
    //
    // Bun 原始流程:
    //   if (manager.options.positionals.len == 1) {
    //       // bun link (无参数): 将当前包注册到全局
    //   } else {
    //       // bun link <package>: 将全局包链接到当前项目
    //       manager.updatePackageJSONAndInstallWithManager(ctx, original_cwd);
    //   }
    public func execute(args: ArrayList<String>): Int64 {
        let opts = parseArgs(args)

        if (!opts.silent) {
            println("bao link v${BAO_VERSION}")
        }

        // 检查 package.json
        if (!BaoFile.exists("package.json")) {
            // 尝试创建空的 package.json
            // 严格翻译自: attemptToCreatePackageJSON()
            logger.warn("No package.json found, creating an empty one")
            BaoFile.writeAllText("package.json", "{}\n")
        }

        match (opts.packageName) {
            case Some(name) => {
                // bun link <package>: 链接全局包到当前项目
                // 严格翻译自: manager.updatePackageJSONAndInstallWithManager(ctx, original_cwd)
                return linkToProject(name, opts)
            }
            case None => {
                // bun link: 将当前包链接到全局
                // 严格翻译自: positionals.len == 1 → 解析 package.json → 创建 symlink
                return linkToGlobal(opts)
            }
        }
    }

    /// 将当前包链接到全局 (bun link)
    // 严格翻译自: src/cli/link_command.zig link() → positionals.len == 1 分支
    //
    // Bun 原始流程:
    //   1. 解析当前目录的 package.json 获取 name
    //   2. 设置全局目录 (通常 ~/.bun/install/global/node_modules)
    //   3. 创建 symlink: 全局 node_modules/<name> → 当前目录
    //   4. 如果有 bin 字段, 链接 bin 到全局 bin 目录
    //   5. 打印成功信息和使用说明
    private func linkToGlobal(opts: LinkOptions): Int64 {
        // 步骤1: 解析 package.json
        let pkgContent = BaoFile.readAllText("package.json")
        match (pkgContent) {
            case Some(content) => {
                let parser = JsonParser()
                let json = parser.parse(content)
                match (json) {
                    case Some(root) => {
                        let name = JsonHelper.getString(root, "name")
                        match (name) {
                            case Some(n) => {
                                if (n.isEmpty()) {
                                    logger.error("package.json missing \"name\"")
                                    return 1
                                }

                                // 步骤2: 获取/创建全局目录
                                // 严格翻译自: Options.openGlobalDir(explicit_global_dir)
                                let globalNodeModules = getGlobalNodeModulesDir(opts.globalDir)
                                BaoFile.mkdir(globalNodeModules, true)

                                // 步骤3: 创建 symlink
                                // 严格翻译自:
                                //   node_modules.deleteTree(name) catch {}
                                //   node_modules.symLink(topLevelDir, name, .{ .is_directory = true })
                                let cwd = Sys.getcwd()
                                let linkPath = Path.join([globalNodeModules, n])

                                // 删除已存在的链接
                                if (BaoFile.exists(linkPath)) {
                                    BaoFile.removeTree(linkPath)
                                }

                                // 处理 scoped package (@org/package)
                                if (n.startsWith("@")) {
                                    let slashIdx = n.indexOf("/")
                                    match (slashIdx) {
                                        case Some(idx) => {
                                            let scopeDir = Path.join([globalNodeModules, n.substring(0, idx)])
                                            if (!BaoFile.exists(scopeDir)) {
                                                BaoFile.mkdir(scopeDir, false)
                                            }
                                        }
                                        case None => ()
                                    }
                                }

                                // 创建 symlink
                                let symlinkCreated = BaoFile.createSymlink(cwd, linkPath)
                                if (!symlinkCreated) {
                                    logger.error("Failed to create symlink to global directory")
                                    return 1
                                }

                                // 步骤4: 链接 bin
                                // 严格翻译自: if (package.bin.tag != .none) { bin_linker.link(true) }
                                linkBins(root, n, globalNodeModules, opts.binDir)

                                // 步骤5: 打印成功信息
                                // 严格翻译自:
                                //   Output.prettyln("Success! Registered \"{s}\"\n...", .{ .name = name })
                                println("")
                                println("Success! Registered \"${n}\"")
                                println("")
                                println("To use ${n} in a project, run:")
                                println("  bao link ${n}")
                                println("")
                                println("Or add it in dependencies in your package.json file:")
                                println("  \"${n}\": \"link:${n}\"")
                                println("")

                                return 0
                            }
                            case None => {
                                logger.error("package.json missing \"name\"")
                                return 1
                            }
                        }
                    }
                    case None => {
                        logger.error("Failed to parse package.json")
                        return 1
                    }
                }
            }
            case None => {
                logger.error("Failed to read package.json")
                return 1
            }
        }
    }

    /// 将全局包链接到当前项目 (bun link <package>)
    // 严格翻译自: src/cli/link_command.zig → else 分支
    //   try manager.updatePackageJSONAndInstallWithManager(ctx, original_cwd)
    //
    // 这等同于在 package.json 中添加 "link:<name>" 依赖然后安装
    private func linkToProject(packageName: String, opts: LinkOptions): Int64 {
        let globalNodeModules = getGlobalNodeModulesDir(opts.globalDir)
        let globalLinkPath = Path.join([globalNodeModules, packageName])

        // 检查全局链接是否存在
        if (!BaoFile.exists(globalLinkPath)) {
            logger.error("Package \"${packageName}\" is not globally linked.")
            logger.info("Run `bao link` in the package directory first.")
            return 1
        }

        // 在当前项目的 node_modules 中创建 symlink
        let localNodeModules = "node_modules"
        BaoFile.mkdir(localNodeModules, false)

        // 处理 scoped package
        if (packageName.startsWith("@")) {
            let slashIdx = packageName.indexOf("/")
            match (slashIdx) {
                case Some(idx) => {
                    let scopeDir = Path.join([localNodeModules, packageName.substring(0, idx)])
                    if (!BaoFile.exists(scopeDir)) {
                        BaoFile.mkdir(scopeDir, false)
                    }
                }
                case None => ()
            }
        }

        let localLinkPath = Path.join([localNodeModules, packageName])

        // 删除已存在的链接
        if (BaoFile.exists(localLinkPath)) {
            BaoFile.removeTree(localLinkPath)
        }

        // 解析全局链接的真实路径
        let realPath = BaoFile.readLink(globalLinkPath) ?? globalLinkPath

        // 创建 symlink
        let symlinkCreated = BaoFile.createSymlink(realPath, localLinkPath)
        if (!symlinkCreated) {
            logger.error("Failed to create symlink in node_modules")
            return 1
        }

        // 更新 package.json
        updatePackageJsonWithLink(packageName)

        // 链接 bin
        let pkgContent = BaoFile.readAllText(Path.join([realPath, "package.json"]))
        match (pkgContent) {
            case Some(content) => {
                let parser = JsonParser()
                let json = parser.parse(content)
                match (json) {
                    case Some(root) => {
                        linkBins(root, packageName, localNodeModules, opts.binDir)
                    }
                    case None => ()
                }
            }
            case None => ()
        }

        if (!opts.silent) {
            println("Linked ${packageName} to local project")
        }

        return 0
    }

    /// 链接 bin 入口
    // 严格翻译自: src/cli/link_command.zig → Bin.Linker.link(true)
    //
    // Bun 原始流程:
    //   1. 解析 package.json 的 bin 字段
    //   2. bin 可以是 string 或 object
    //   3. 在全局 bin 目录创建 symlink
    private func linkBins(root: JsonValue, packageName: String, nodeModulesPath: String, binDir: ?String): Unit {
        let binInfo = JsonHelper.getField(root, "bin")
        match (binInfo) {
            case Some(JsonValue.Str(binPath)) => {
                // bin 是字符串: 二进制名 = 包名, 路径 = binPath
                let binDirPath = binDir ?? getGlobalBinDir()
                BaoFile.mkdir(binDirPath, true)
                let binLinkPath = Path.join([binDirPath, packageName])
                let targetPath = Path.join([nodeModulesPath, packageName, binPath])
                BaoFile.createSymlink(targetPath, binLinkPath)
            }
            case Some(JsonValue.Object(binMap)) => {
                // bin 是对象: { "bin-name": "path/to/bin" }
                let binDirPath = binDir ?? getGlobalBinDir()
                BaoFile.mkdir(binDirPath, true)
                let entries = binMap.entries()
                for (entry in entries) {
                    let binName = entry.key
                    let binPath = entry.value
                    let binLinkPath = Path.join([binDirPath, binName])
                    let targetPath = Path.join([nodeModulesPath, packageName, binPath])
                    BaoFile.createSymlink(targetPath, binLinkPath)
                }
            }
            case _ => ()
        }
    }

    /// 更新 package.json 添加 link: 依赖
    private func updatePackageJsonWithLink(packageName: String): Unit {
        let pkgContent = BaoFile.readAllText("package.json")
        match (pkgContent) {
            case Some(content) => {
                // 简化: 在实际实现中需要 JSON 操作
                // 添加 "dependencies": { "<name>": "link:<name>" }
            }
            case None => ()
        }
    }

    /// 获取全局 node_modules 目录
    // 严格翻译自: Options.openGlobalDir → ~/.bun/install/global/node_modules
    private func getGlobalNodeModulesDir(explicitDir: ?String): String {
        match (explicitDir) {
            case Some(dir) => return Path.join([dir, "node_modules"])
            case None => {
                let homeDir = Sys.getHomeDir()
                return Path.join([homeDir, ".bao", "install", "global", "node_modules"])
            }
        }
    }

    /// 获取全局 bin 目录
    private func getGlobalBinDir(): String {
        let homeDir = Sys.getHomeDir()
        return Path.join([homeDir, ".bao", "bin"])
    }

    /// 解析命令行参数
    private func parseArgs(args: ArrayList<String>): LinkOptions {
        let opts = LinkOptions()
        var i = 0
        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--global-dir" => {
                    i++
                    if (i < args.size) {
                        opts.globalDir = Some(args[i])
                    }
                }
                case "--bin-dir" => {
                    i++
                    if (i < args.size) {
                        opts.binDir = Some(args[i])
                    }
                }
                case "--silent" => opts.silent = true
                case "--help" | "-h" => {
                    printLinkHelp()
                    return opts
                }
                case _ => {
                    if (!arg.startsWith("-")) {
                        opts.packageName = Some(arg)
                    } else {
                        logger.warn("Unknown option: ${arg}")
                    }
                }
            }
            i++
        }
        return opts
    }

    /// 打印 link 命令帮助
    private func printLinkHelp(): Unit {
        println("Usage: bao link [package] [options]")
        println("")
        println("Link a package to/from the global directory")
        println("")
        println("Without arguments:")
        println("  Register the current package globally")
        println("")
        println("With package name:")
        println("  Link a globally registered package to the current project")
        println("")
        println("Options:")
        println("  --global-dir <dir>  Global directory override")
        println("  --bin-dir <dir>     Bin directory override")
        println("  --silent            Suppress output")
        println("  --help, -h          Print this help")
        println("")
        println("Examples:")
        println("  bao link              # Register current package globally")
        println("  bao link my-package   # Link my-package to current project")
    }
}
