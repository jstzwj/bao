// 严格翻译自: src/cli/install_command.zig
// Install 命令实现
package bao_cli

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_sys.*
import bao_path.*

// ============================================================================
// InstallCommand — bun install / bun add / bun remove 实现
// 严格翻译自: src/cli/install_command.zig - InstallCommand
// 对应 Bun: bun install, bun add <pkg>, bun remove <pkg>
// ============================================================================

/// Install 命令执行器
/// 对应 Bun: InstallCommand.exec(ctx) → installWithCLI / installWithManager
///
/// 子命令:
///   bun install           — 安装 package.json 中的所有依赖
///   bun add <pkg>         — 添加依赖并安装
///   bun remove <pkg>      — 移除依赖
///   bun update [pkg]      — 更新依赖
public class InstallCommand {
    /// 安装选项
    private var options: InstallCliOptions

    /// 包管理器
    private var pm: PackageManager

    public init(options: InstallCliOptions) {
        this.options = options
        this.pm = PackageManager()
    }

    /// 执行 install 命令
    /// 对应 Bun: InstallCommand.exec(ctx) → install(ctx) → installWithCLI
    public func execute(): Int64 {
        // 打印版本信息
        // 对应 Bun: Output.prettyln("<b>bun install <d>v...")
        if (options.verbose) {
            println("bao install v${BAO_VERSION}")
        }

        // 处理 add 子命令
        // 对应 Bun: subcommand == .add → manager.updatePackageJSONAndInstall
        match (options.add) {
            case Some(name) => return addPackage(name)
            case None => ()
        }

        // 处理 remove 子命令
        // 对应 Bun: bun remove <pkg> → pm.remove()
        match (options.remove) {
            case Some(name) => return removePackage(name)
            case None => ()
        }

        // 默认: 安装所有依赖
        // 对应 Bun: manager.installWithManager()
        return installAll()
    }

    /// 安装所有依赖
    /// 对应 Bun: installWithManager(ctx, root_package_json_path, original_cwd)
    ///
    /// 流程:
    ///   1. 读取 package.json
    ///   2. 解析依赖树
    ///   3. 下载并安装包
    ///   4. 生成 lockfile
    ///   5. 更新 node_modules
    private func installAll(): Int64 {
        if (options.verbose) {
            println("Reading package.json...")
        }

        // 检查 package.json 是否存在
        if (!BaoFile.exists("package.json")) {
            println("error: package.json not found")
            println("Run 'bao init' to create a new project")
            return 1
        }

        // 配置安装选项
        // 对应 Bun: PackageManager.init(ctx, cli, .install)
        let installOpts = InstallOptions()
        installOpts.production = options.production
        installOpts.frozen = options.frozen
        installOpts.verbose = options.verbose

        try {
            // 执行安装
            // 对应 Bun: manager.installWithManager(ctx, pkgJsonPath, cwd)
            let result = pm.install(installOpts)

            if (options.verbose) {
                printInstallSummary(result)
            }

            return 0
        } catch (e: Exception) {
            println("error: ${e.message}")
            return 1
        }
    }

    /// 添加包
    /// 对应 Bun: bun add <pkg>
    /// 流程:
    ///   1. 解析包名和版本
    ///   2. 下载包
    ///   3. 更新 package.json
    ///   4. 安装依赖
    private func addPackage(name: String): Int64 {
        if (options.verbose) {
            println("Adding package: ${name}")
        }

        // 解析包名和版本
        // 对应 Bun: CLI 解析 "package@version" 格式
        let parsed = parsePackageSpec(name)
        let pkgName = parsed.name
        let pkgVersion = parsed.version

        if (options.verbose) {
            match (pkgVersion) {
                case Some(v) => println("  Package: ${pkgName}@${v}")
                case None => println("  Package: ${pkgName}@latest")
            }
        }

        try {
            // 执行添加
            // 对应 Bun: manager.updatePackageJSONAndInstall()
            pm.add(pkgName, pkgVersion)

            println("  Added ${pkgName}")
            return 0
        } catch (e: Exception) {
            println("error: Failed to add ${pkgName}: ${e.message}")
            return 1
        }
    }

    /// 移除包
    /// 对应 Bun: bun remove <pkg>
    /// 流程:
    ///   1. 检查包是否在依赖中
    ///   2. 从 package.json 移除
    ///   3. 从 node_modules 移除
    ///   4. 更新 lockfile
    private func removePackage(name: String): Int64 {
        if (options.verbose) {
            println("Removing package: ${name}")
        }

        try {
            pm.remove(name)
            println("  Removed ${name}")
            return 0
        } catch (e: Exception) {
            println("error: Failed to remove ${name}: ${e.message}")
            return 1
        }
    }

    /// 解析包规范 "name@version" → (name, version)
    /// 对应 Bun: CLI 参数解析
    private func parsePackageSpec(spec: String): PackageSpec {
        // 检查是否包含 @ (排除 scoped package 的前缀 @)
        // 例: @scope/name@1.0.0, lodash@4.17.21, express
        var name = spec
        var version: ?String = None

        // scoped package: @scope/name@version
        if (spec.startsWith("@")) {
            let secondAt = spec.indexOf('@', 1)
            if (secondAt > 0) {
                name = spec.substring(0, secondAt)
                version = Some(spec.substring(secondAt + 1))
            }
        } else {
            let atIdx = spec.lastIndexOf('@')
            if (atIdx > 0) {
                name = spec.substring(0, atIdx)
                version = Some(spec.substring(atIdx + 1))
            }
        }

        return PackageSpec(name, version)
    }

    /// 打印安装摘要
    /// 对应 Bun: install 完成后打印统计
    private func printInstallSummary(result: InstallResult): Unit {
        let total = result.installed + result.removed
        if (total == 0) {
            println("  Already up to date")
        } else {
            if (result.installed > 0) {
                println("  Installed ${result.installed} package(s)")
            }
            if (result.removed > 0) {
                println("  Removed ${result.removed} package(s)")
            }
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 包规范 (名称 + 版本)
class PackageSpec {
    public var name: String
    public var version: ?String

    public init(name: String, version: ?String) {
        this.name = name
        this.version = version
    }
}

/// 安装选项 (内部)
/// 对应 Bun: PackageManager.Options
public class InstallOptions {
    public var production: Bool
    public var frozen: Bool
    public var verbose: Bool
    public var noSave: Bool
    public var global: Bool

    public init() {
        production = false
        frozen = false
        verbose = false
        noSave = false
        global = false
    }
}

/// 安装结果
/// 对应 Bun: PackageManager install result
public class InstallResult {
    public var installed: Int64
    public var removed: Int64
    public var updated: Int64
    public var errors: ArrayList<String>

    public init() {
        installed = 0
        removed = 0
        updated = 0
        errors = ArrayList<String>()
    }
}

/// 包管理器 (桩)
/// 对应 Bun: src/install/install.zig - PackageManager
public class PackageManager {
    public init() {}

    /// 安装所有依赖
    /// 对应 Bun: PackageManager.installWithManager
    public func install(options: InstallOptions): InstallResult {
        // 实际实现在 bao_install 包中
        return InstallResult()
    }

    /// 添加包
    /// 对应 Bun: PackageManager.updatePackageJSONAndInstall
    public func add(name: String, version: ?String): Unit {
        // 实际实现:
        // 1. 解析版本范围
        // 2. 从 registry 下载包
        // 3. 解析依赖
        // 4. 安装到 node_modules
        // 5. 更新 package.json
    }

    /// 移除包
    /// 对应 Bun: PackageManager.remove
    public func remove(name: String): Unit {
        // 实际实现:
        // 1. 从 package.json 移除
        // 2. 从 node_modules 移除
        // 3. 更新 lockfile
    }

    /// 更新包
    /// 对应 Bun: bun update
    public func update(name: String): Unit {
        // 实际实现:
        // 1. 检查最新版本
        // 2. 下载更新
        // 3. 更新 package.json
    }
}

/// String.indexOf 从指定位置开始查找
private func String.indexOf(ch: UInt8, fromIndex: Int64): Int64 {
    if (fromIndex < 0) { fromIndex = 0 }
    var i = fromIndex
    while (i < this.length) {
        if (UInt8(this[i].value) == ch) {
            return i
        }
        i += 1
    }
    return -1
}
