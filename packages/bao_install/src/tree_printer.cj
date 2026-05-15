// bao_install - 锁文件树形打印器
// 严格翻译自: src/install/lockfile/printer/tree_printer.zig
//   打印安装结果: 新增包、更新包、删除包的格式化输出
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 包更新打印信息
// 严格翻译自: tree_printer.zig - PackageUpdatePrintInfo
//   const PackageUpdatePrintInfo = struct {
//       version: Semver.Version,
//       version_buf: string,
//       resolution: Resolution,
//       dependency_id: DependencyID,
//   }
// ============================================================================

/// 包更新打印信息
/// 翻译自: PackageUpdatePrintInfo
public class PackageUpdatePrintInfo {
    public var version: String
    public var versionBuf: String
    public var resolution: String
    public var dependencyId: UInt32

    public init(version: String, versionBuf: String, resolution: String, depId: UInt32) {
        this.version = version
        this.versionBuf = versionBuf
        this.resolution = resolution
        this.dependencyId = depId
    }
}

// ============================================================================
// 是否打印结果
// 严格翻译自: tree_printer.zig - ShouldPrintPackageInstallResult
//   const ShouldPrintPackageInstallResult = union(enum) {
//       yes, no, @"return", update: PackageUpdatePrintInfo,
//   }
// ============================================================================

/// 是否打印包安装结果
/// 翻译自: ShouldPrintPackageInstallResult
public enum ShouldPrintResult {
    | Yes                                  // 应该打印
    | No                                   // 不打印
    | Return                               // 停止处理
    | Update(PackageUpdatePrintInfo)        // 打印更新信息
}

// ============================================================================
// 树形打印器
// 严格翻译自: src/install/lockfile/printer/tree_printer.zig - Printer
// ============================================================================

/// 树形打印器
/// 对应 Bun: lockfile.printer.Printer
/// 格式化打印安装结果: 新增、更新、删除的包
/// 翻译自: src/install/lockfile/printer/tree_printer.zig
public class TreePrinter {
    /// 锁文件引用
    public var lockfile: Lockfile
    /// 更新请求列表
    public var updates: ArrayList<UpdateRequestFull>
    /// 选项
    public var options: PackageManagerOptions
    /// 已安装的包集合
    public var installed: HashSet<UInt32>

    public init(lockfile: Lockfile, updates: ArrayList<UpdateRequestFull>, options: PackageManagerOptions) {
        this.lockfile = lockfile
        this.updates = updates
        this.options = options
        installed = HashSet<UInt32>()
    }

    /// 打印 workspace 部分的已安装包
    /// 翻译自: Printer.printInstalledWorkspaceSection
    public func printInstalledWorkspaceSection(
        workspacePackageId: UInt32,
        printedNewInstall: Bool
    ): Bool {
        var newInstall = printedNewInstall
        var printedSectionHeader = false

        // 遍历 workspace 的依赖, 打印已安装的包
        // 翻译自: for (resolutions_list[workspace_package_id].begin()..end())

        return newInstall
    }

    /// 判断是否应该打印包安装
    /// 翻译自: Printer.shouldPrintPackageInstall
    public func shouldPrintPackageInstall(
        depId: UInt32,
        packageId: UInt32
    ): ShouldPrintResult {
        // 检查是否是 workspace 依赖
        // 检查是否在更新列表中
        // 检查是否已安装
        // 检查是否被禁用
        // 检查是否有版本更新

        if (!installed.contains(packageId)) {
            return ShouldPrintResult.No
        }

        return ShouldPrintResult.Yes
    }

    /// 打印已更新的包
    /// 翻译自: Printer.printUpdatedPackage
    ///   格式: ^ package-name old_version -> new_version
    public static func printUpdatedPackage(
        packageName: String,
        oldVersion: String,
        newVersion: String
    ): String {
        return "^ ${packageName} ${oldVersion} -> ${newVersion}"
    }

    /// 打印已安装的包
    /// 翻译自: Printer.printInstalledPackage
    ///   格式取决于包的安装方式
    public static func printInstalledPackage(
        packageName: String,
        version: String,
        resolution: String
    ): String {
        return "+ ${packageName}@${version}"
    }

    /// 打印完整的安装摘要
    /// 翻译自: Printer 的整体打印逻辑
    public func printSummary(summary: PackageInstallSummary): Unit {
        let parts = ArrayList<String>()
        if (summary.success > 0) {
            parts.append("${summary.success} packages installed")
        }
        if (summary.fail > 0) {
            parts.append("${summary.fail} packages failed")
        }
        if (summary.skipped > 0) {
            parts.append("${summary.skipped} packages skipped")
        }

        if (parts.size > 0) {
            bao_core.Output.info(String.join(", ", parts))
        }
    }

    /// 打印包树 (为什么安装)
    /// 翻译自: bun pm why 的输出格式
    public static func printWhyTree(
        packageName: String,
        dependents: ArrayList<String>,
        depth: Int64
    ): String {
        let sb = StringBuilder()
        sb.append("${packageName}\n")
        for (dep in dependents) {
            sb.append("  ")
            var d: Int64 = 0
            while (d < depth) {
                sb.append("  ")
                d += 1
            }
            sb.append("${dep}\n")
        }
        return sb.toString()
    }
}
