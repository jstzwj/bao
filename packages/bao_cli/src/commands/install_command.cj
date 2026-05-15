// 严格翻译自: src/cli/install_command.zig
// Install 命令 — 包安装管理
// 对应 Bun: bun install / bun add <pkg> / bun remove <pkg>
package bao_cli

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_sys.*
import bao_path.*

// ============================================================================
// InstallCommand — bun install 命令执行器
// 严格翻译自: src/cli/install_command.zig - InstallCommand
//
// Bun install_command 核心流程:
//   1. 解析命令行参数
//   2. 检测是否有位置参数 → 决定子命令 (install 或 add)
//   3. 初始化 PackageManager
//   4. install: 安装所有依赖
//      add: 添加包并更新 package.json
//   5. 错误处理
//
// 关键特性:
//   - bun install: 安装 package.json 中的所有依赖
//   - bun add <pkg>: 添加依赖到 package.json 并安装
//   - bun remove <pkg>: 从 package.json 和 node_modules 移除
//   - --production: 仅安装 production 依赖
//   - --frozen-lockfile: 严格 lockfile 模式
//   - --analyze: 分析源文件中的依赖
// ============================================================================

/// Install 命令执行器
/// 对应 Bun: InstallCommand.exec(ctx) → install(ctx) → installWithCLI / installWithManager
public class InstallCommand {
    /// 命令行选项
    private var cliOptions: InstallCommandLineOptions

    public init(cliOptions: InstallCommandLineOptions) {
        this.cliOptions = cliOptions
    }

    /// 执行 install 命令
    /// 对应 Bun: InstallCommand.exec(ctx)
    ///
    /// 严格翻译自: install_command.zig 中 exec → install → installWithCLI 流程:
    ///   1. 解析命令行参数 (CommandLineArguments.parse)
    ///   2. 判断子命令 (install / add)
    ///   3. 初始化 PackageManager (PackageManager.init)
    ///   4. 执行安装
    public func execute(): Int64 {
        // 打印版本
        // 严格翻译自: install_command.zig 中 shouldPrintCommandName
        if (cliOptions.verbose) {
            println("bao install v${BAO_VERSION}")
        }

        // 检测子命令
        // 严格翻译自: install_command.zig 中 subcommand 检测
        // "如果位置参数超过 1 个 (install 之后的)，则为 add 子命令"
        let subcommand = if (cliOptions.packages.size > 0) {
            InstallSubcommand.Add
        } else {
            InstallSubcommand.Install
        }

        // 初始化 PackageManager
        // 严格翻译自: install_command.zig 中 PackageManager.init(ctx, cli, .install)
        let manager = InstallPackageManager()
        let originalCwd = Sys.getcwd()

        // 执行子命令
        match (subcommand) {
            case Add => {
                return executeAdd(manager, originalCwd)
            }
            case Install => {
                return executeInstall(manager, originalCwd)
            }
        }
    }

    /// 执行 install 子命令
    /// 对应 Bun: install_command.zig 中 manager.installWithManager
    ///
    /// 严格翻译自: install_command.zig 中 install 子命令流程:
    ///   1. 打印 "bao install vX.Y.Z"
    ///   2. 读取 package.json
    ///   3. 解析依赖树
    ///   4. 下载并安装
    ///   5. 生成/更新 lockfile
    ///   6. 更新 node_modules
    private func executeInstall(
        manager: InstallPackageManager,
        originalCwd: String
    ): Int64 {
        if (cliOptions.verbose) {
            println("bao install v${BAO_VERSION}")
        }

        // 检查 package.json
        let pkgJsonPath = Path.resolve("package.json")
        if (!BaoFile.exists(pkgJsonPath)) {
            println("error: package.json not found")
            println("Run 'bao init' to create a new package.json")
            return 1
        }

        // 配置安装选项
        let installOpts = InstallCommandOptions()
        installOpts.production = cliOptions.production
        installOpts.frozenLockfile = cliOptions.frozenLockfile
        installOpts.verbose = cliOptions.verbose
        installOpts.noSave = cliOptions.noSave
        installOpts.global = cliOptions.global
        installOpts.originalCwd = originalCwd

        try {
            // 执行安装
            // 严格翻译自: install_command.zig 中 manager.installWithManager(ctx, pkgJsonPath, cwd)
            let result = manager.install(pkgJsonPath, installOpts)

            if (result.anyFailed) {
                return 1
            }

            // 打印摘要
            printInstallSummary(result)
            return 0
        } catch (e: InstallException) {
            match (e.kind) {
                case InstallFailed => {
                    println("error: install failed: ${e.message}")
                }
                case InvalidPackageJson => {
                    println("error: invalid package.json: ${e.message}")
                }
            }
            return 1
        }
    }

    /// 执行 add 子命令
    /// 对应 Bun: install_command.zig 中 manager.updatePackageJSONAndInstall
    ///
    /// 严格翻译自: install_command.zig 中 add 子命令流程:
    ///   1. 打印 "bao add vX.Y.Z"
    ///   2. 解析包名和版本
    ///   3. 更新 package.json
    ///   4. 安装依赖
    private func executeAdd(
        manager: InstallPackageManager,
        originalCwd: String
    ): Int64 {
        if (cliOptions.verbose) {
            println("bao add v${BAO_VERSION}")
        }

        for (pkg in cliOptions.packages) {
            let spec = parsePackageSpec(pkg)
            try {
                // 严格翻译自: install_command.zig 中 manager.updatePackageJSONAndInstall()
                manager.add(spec.name, spec.version, spec.isDev)
                println("  Added ${spec.name}")
            } catch (e: Exception) {
                println("error: Failed to add ${spec.name}: ${e.message}")
                return 1
            }
        }

        return 0
    }

    /// 解析包规范 "name@version" → PackageAddSpec
    /// 对应 Bun: CLI 参数解析 "package@version"
    ///
    /// 支持:
    ///   - lodash@4.17.21
    ///   - @scope/package@1.0.0
    ///   - -D package (dev dependency)
    ///   - --dev package (dev dependency)
    private func parsePackageSpec(spec: String): PackageAddSpec {
        var name = spec
        var version: ?String = None
        var isDev = false

        // 检查 -D / --dev 前缀
        // 严格翻译自: Bun 中 --development 参数处理
        if (name.startsWith("-D ") || name.startsWith("--dev ")) {
            isDev = true
            name = name.substring(name.indexOf(' ') + 1)
        }

        // scoped package: @scope/name@version
        if (name.startsWith("@")) {
            let secondAt = name.indexOfFrom('@', 1)
            match (secondAt) {
                case Some(idx) => {
                    version = Some(name.substring(idx + 1))
                    name = name.substring(0, idx)
                }
                case None => ()
            }
        } else {
            // 普通 package: name@version
            let lastAt = name.lastIndexOf('@')
            if (lastAt > 0) {
                version = Some(name.substring(lastAt + 1))
                name = name.substring(0, lastAt)
            }
        }

        return PackageAddSpec(name, version, isDev)
    }

    /// 打印安装摘要
    /// 对应 Bun: install 完成后打印统计
    private func printInstallSummary(result: InstallCommandResult): Unit {
        if (result.installed == 0 && result.removed == 0) {
            println("  Already up to date")
        } else {
            if (result.installed > 0) {
                println("  Installed ${result.installed} package(s)")
            }
            if (result.removed > 0) {
                println("  Removed ${result.removed} package(s)")
            }
            if (result.updated > 0) {
                println("  Updated ${result.updated} package(s)")
            }
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 安装子命令
/// 对应 Bun: PackageManager.Subcommand
public enum InstallSubcommand {
    | Install
    | Add
}

/// 安装异常类型
/// 对应 Bun: install_command.zig 中的错误类型
public enum InstallErrorKind {
    | InstallFailed
    | InvalidPackageJson
}

/// 安装异常
public class InstallException {
    public var kind: InstallErrorKind
    public var message: String

    public init(kind: InstallErrorKind, message: String) {
        this.kind = kind
        this.message = message
    }
}

/// 安装命令行选项
/// 对应 Bun: PackageManager.CommandLineArguments
public class InstallCommandLineOptions {
    /// 位置参数 (包名列表，add 子命令时使用)
    public var packages: ArrayList<String>

    /// 是否为 production 模式
    // 对应 Bun: --production
    public var production: Bool

    /// 是否冻结 lockfile
    // 对应 Bun: --frozen-lockfile
    public var frozenLockfile: Bool

    /// 详细输出
    public var verbose: Bool

    /// 不保存到 package.json
    // 对应 Bun: --no-save
    public var noSave: Bool

    /// 全局安装
    // 对应 Bun: --global
    public var global: Bool

    /// 分析模式 (从源文件提取依赖)
    // 对应 Bun: --analyze
    public var analyze: Bool

    public init() {
        packages = ArrayList<String>()
        production = false
        frozenLockfile = false
        verbose = false
        noSave = false
        global = false
        analyze = false
    }
}

/// 安装命令内部选项
/// 对应 Bun: PackageManager.Options
class InstallCommandOptions {
    public var production: Bool
    public var frozenLockfile: Bool
    public var verbose: Bool
    public var noSave: Bool
    public var global: Bool
    public var originalCwd: String

    public init() {
        production = false
        frozenLockfile = false
        verbose = false
        noSave = false
        global = false
        originalCwd = ""
    }
}

/// 安装命令结果
/// 对应 Bun: PackageManager install result
class InstallCommandResult {
    public var installed: Int64
    public var removed: Int64
    public var updated: Int64
    public var anyFailed: Bool

    public init() {
        installed = 0
        removed = 0
        updated = 0
        anyFailed = false
    }
}

/// 包添加规格
/// 解析 "name@version" [-D]
class PackageAddSpec {
    public var name: String
    public var version: ?String
    public var isDev: Bool

    public init(name: String, version: ?String, isDev: Bool) {
        this.name = name
        this.version = version
        this.isDev = isDev
    }
}

/// 包管理器 (桩)
/// 对应 Bun: src/install/install.zig - PackageManager
///
/// 实际实现在 bao_install 包中
public class InstallPackageManager {
    public init() {}

    /// 安装所有依赖
    /// 对应 Bun: PackageManager.installWithManager
    public func install(pkgJsonPath: String, options: InstallCommandOptions): InstallCommandResult {
        // 实际实现在 bao_install 包中:
        // 1. 读取 package.json
        // 2. 解析依赖树
        // 3. 从 registry 下载包
        // 4. 安装到 node_modules
        // 5. 生成/更新 lockfile
        return InstallCommandResult()
    }

    /// 添加包
    /// 对应 Bun: PackageManager.updatePackageJSONAndInstall
    public func add(name: String, version: ?String, isDev: Bool): Unit {
        // 实际实现:
        // 1. 解析版本范围
        // 2. 从 registry 下载包
        // 3. 解析依赖
        // 4. 安装到 node_modules
        // 5. 更新 package.json (dependencies 或 devDependencies)
    }
}

/// String.indexOf 从指定位置开始查找
private func String.indexOfFrom(ch: Char, fromIndex: Int64): ?Int64 {
    if (fromIndex < 0) { return None }
    var i = fromIndex
    while (i < this.length) {
        if (this[i] == ch) {
            return Some(i)
        }
        i += 1
    }
    return None
}
