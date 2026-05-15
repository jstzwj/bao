// 严格翻译自: src/cli/outdated_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// OutdatedCommand — 检查过时包命令
// 严格翻译自: src/cli/outdated_command.zig - OutdatedCommand struct
// ============================================================================

/// 过时的包信息
/// 对应 Bun: OutdatedInfo
public class OutdatedInfo {
    public var packageId: Int64
    public var depId: Int64
    public var workspacePkgId: Int64
    public var isCatalog: Bool

    public init() {
        packageId = 0
        depId = 0
        workspacePkgId = 0
        isCatalog = false
    }
}

/// 分组后的过时信息
/// 对应 Bun: GroupedOutdatedInfo
public class GroupedOutdatedInfo {
    public var packageId: Int64
    public var depId: Int64
    public var workspacePkgId: Int64
    public var isCatalog: Bool
    public var groupedWorkspaceNames: ?String

    public init() {
        packageId = 0
        depId = 0
        workspacePkgId = 0
        isCatalog = false
        groupedWorkspaceNames = None
    }
}

/// 过滤类型
/// 对应 Bun: OutdatedCommand.FilterType
public enum OutdatedFilterType {
    | all
    | name    // String
    | path    // String
}

/// OutdatedCommand: 检查过时的包
/// 对应 Bun: OutdatedCommand
public class OutdatedCommand {
    /// 执行命令
    /// 对应 Bun: OutdatedCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        Output.prettyLn("bao outdated v${Global.packageJsonVersionWithSha}")
        Output.flush()

        val cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.outdated)
        val (manager, originalCwd) = match (PackageManager.init(ctx, cli, Subcommand.outdated)) {
            case Some((pm, dir)) => (pm, dir)
            case None => {
                if (!cli.silent) {
                    Output.errGeneric("failed to initialize bao install")
                }
                Global.crash()
            }
        }

        outdated(ctx, originalCwd, manager)
    }

    /// 执行过时检查
    /// 对应 Bun: OutdatedCommand.outdated()
    private static func outdated(ctx: CommandContext, originalCwd: String, manager: PackageManager): Unit {
        val loadLockfileResult = manager.lockfile.loadFromCwd(manager, manager.allocator, manager.log, true)
        if (loadLockfileResult == LoadLockfileResult.notFound) {
            Output.errGeneric("missing lockfile, nothing outdated")
            Global.crash()
        }
        if (loadLockfileResult == LoadLockfileResult.err) {
            Output.errGeneric("failed to load lockfile")
            Global.crash()
        }

        val enableAnsiColors = Output.enableAnsiColorsStdout

        if (manager.options.filterPatterns.size > 0) {
            val workspacePkgIds = findMatchingWorkspaces(originalCwd, manager, manager.options.filterPatterns)
            manager.populateManifestCache(workspacePkgIds)
            printOutdatedInfoTable(manager, workspacePkgIds, true, enableAnsiColors)
        } else if (manager.options.doRecursive) {
            val allWorkspaces = getAllWorkspaces(manager)
            manager.populateManifestCache(allWorkspaces)
            printOutdatedInfoTable(manager, allWorkspaces, true, enableAnsiColors)
        } else {
            val rootPkgId = manager.rootPackageId
            manager.populateManifestCache([rootPkgId])
            printOutdatedInfoTable(manager, [rootPkgId], false, enableAnsiColors)
        }
    }

    /// 获取所有工作区
    /// 对应 Bun: OutdatedCommand.getAllWorkspaces()
    private static func getAllWorkspaces(manager: PackageManager): ArrayList<Int64> {
        val lockfile = manager.lockfile
        val packages = lockfile.packages
        val workspacePkgIds = ArrayList<Int64>()

        for (pkgIdx in 0..packages.length) {
            val resolution = packages.getResolution(pkgIdx)
            if (resolution.tag == ResolutionTag.workspace || resolution.tag == ResolutionTag.root) {
                workspacePkgIds.append(pkgIdx)
            }
        }

        return workspacePkgIds
    }

    /// 查找匹配的工作区
    /// 对应 Bun: OutdatedCommand.findMatchingWorkspaces()
    private static func findMatchingWorkspaces(
        originalCwd: String,
        manager: PackageManager,
        filters: ArrayList<String>
    ): ArrayList<Int64> {
        val lockfile = manager.lockfile
        val packages = lockfile.packages
        val workspacePkgIds = ArrayList<Int64>()

        // 收集所有工作区
        for (pkgIdx in 0..packages.length) {
            val resolution = packages.getResolution(pkgIdx)
            if (resolution.tag == ResolutionTag.workspace || resolution.tag == ResolutionTag.root) {
                workspacePkgIds.append(pkgIdx)
            }
        }

        // 过滤匹配的
        val matched = ArrayList<Int64>()
        for (pkgId in workspacePkgIds) {
            val pkgName = packages.getName(pkgId)
            val resolution = packages.getResolution(pkgId)

            for (filter in filters) {
                if (filter == "*" || filter == "**") {
                    matched.append(pkgId)
                } else if (Glob.match(filter, pkgName).matches()) {
                    matched.append(pkgId)
                }
            }
        }

        return if (matched.size > 0) matched else workspacePkgIds
    }

    /// 打印过时信息表格
    /// 对应 Bun: OutdatedCommand.printOutdatedInfoTable()
    private static func printOutdatedInfoTable(
        manager: PackageManager,
        workspacePkgIds: ArrayList<Int64>,
        wasFiltered: Bool,
        enableAnsiColors: Bool
    ): Unit {
        var maxName: Int64 = 0
        var maxCurrent: Int64 = 0
        var maxUpdate: Int64 = 0
        var maxLatest: Int64 = 0
        var maxWorkspace: Int64 = 0

        val lockfile = manager.lockfile
        val packages = lockfile.packages
        val outdatedIds = ArrayList<OutdatedInfo>()

        // 收集过时的包
        for (workspacePkgId in workspacePkgIds) {
            val pkgDeps = packages.getDependencies(workspacePkgId)
            for (depIdx in 0..pkgDeps.length) {
                val packageId = packages.getResolutionIndex(depIdx)
                if (packageId < 0) {
                    continue
                }

                val dep = pkgDeps[depIdx]
                val resolution = packages.getResolution(packageId)
                if (resolution.tag != ResolutionTag.npm) {
                    continue
                }

                val packageName = packages.getName(packageId)
                val currentVersion = resolution.formatVersion()

                // 查询最新版本
                val manifest = manager.manifests.byNameAllowExpired(
                    manager, manager.scopeForPackageName(packageName),
                    packageName, true
                )
                if (manifest == None) {
                    continue
                }

                val latestVersion = manifest!!.findByDistTag("latest") ?: continue

                // 检查是否有更新
                if (currentVersion == latestVersion.version) {
                    continue
                }

                // 更新最大宽度
                if (packageName.length > maxName) {
                    maxName = packageName.length
                }
                if (currentVersion.length > maxCurrent) {
                    maxCurrent = currentVersion.length
                }
                if (latestVersion.version.length > maxLatest) {
                    maxLatest = latestVersion.version.length
                }

                val info = OutdatedInfo()
                info.packageId = packageId
                info.depId = depIdx
                info.workspacePkgId = workspacePkgId
                info.isCatalog = dep.isCatalog
                outdatedIds.append(info)
            }
        }

        if (outdatedIds.size == 0) {
            return
        }

        // 打印表格头
        val showWorkspaceColumn = wasFiltered
        if (showWorkspaceColumn) {
            maxWorkspace = 10
        }

        val columnPad = 1
        val nameWidth = Math.max("Package".length, maxName) + columnPad * 2
        val currentWidth = Math.max("Current".length, maxCurrent) + columnPad * 2
        val updateWidth = Math.max("Update".length, maxUpdate) + columnPad * 2
        val latestWidth = Math.max("Latest".length, maxLatest) + columnPad * 2

        // 打印分隔线
        printTableSeparator(nameWidth, currentWidth, updateWidth, latestWidth, if (showWorkspaceColumn) maxWorkspace + columnPad * 2 else 0)

        // 打印表头
        printTableRow(["Package", "Current", "Update", "Latest"], [nameWidth, currentWidth, updateWidth, latestWidth], enableAnsiColors)

        // 打印分隔线
        printTableSeparator(nameWidth, currentWidth, updateWidth, latestWidth, if (showWorkspaceColumn) maxWorkspace + columnPad * 2 else 0)

        // 打印每个过时的包
        for (info in outdatedIds) {
            val packageName = packages.getName(info.packageId)
            val resolution = packages.getResolution(info.packageId)
            val currentVersion = resolution.formatVersion()

            val manifest = manager.manifests.byNameAllowExpired(
                manager, manager.scopeForPackageName(packageName),
                packageName, true
            )
            val latestVersion = manifest!!.findByDistTag("latest")
            val latestStr = latestVersion?.version ?: currentVersion

            val updateStr = latestStr

            printTableRow([packageName, currentVersion, updateStr, latestStr], [nameWidth, currentWidth, updateWidth, latestWidth], enableAnsiColors)
        }

        // 打印底部线
        printTableSeparator(nameWidth, currentWidth, updateWidth, latestWidth, if (showWorkspaceColumn) maxWorkspace + columnPad * 2 else 0)
    }

    /// 打印表格分隔线
    private static func printTableSeparator(widths: Array<Int64>): Unit {
        val sb = StringBuilder()
        for (w in widths) {
            sb.append("+")
            for (_ in 0..w) {
                sb.append("-")
            }
        }
        sb.append("+")
        Output.println(sb.toString())
    }

    /// 打印表格行
    private static func printTableRow(cells: Array<String>, widths: Array<Int64>, colors: Bool): Unit {
        val sb = StringBuilder()
        for ((i, cell) in cells.iterator().indexed()) {
            sb.append("| ")
            sb.append(cell)
            val padding = widths[i] - cell.length - 2
            for (_ in 0..padding) {
                sb.append(" ")
            }
            sb.append(" ")
        }
        sb.append("|")
        Output.println(sb.toString())
    }

    /// 按 Catalog 分组
    /// 对应 Bun: OutdatedCommand.groupCatalogDependencies()
    private static func groupCatalogDependencies(
        manager: PackageManager,
        outdatedItems: ArrayList<OutdatedInfo>,
        workspacePkgIds: ArrayList<Int64>
    ): ArrayList<GroupedOutdatedInfo> {
        val result = ArrayList<GroupedOutdatedInfo>()

        for (item in outdatedItems) {
            if (!item.isCatalog) {
                val grouped = GroupedOutdatedInfo()
                grouped.packageId = item.packageId
                grouped.depId = item.depId
                grouped.workspacePkgId = item.workspacePkgId
                grouped.isCatalog = false
                result.append(grouped)
            } else {
                val grouped = GroupedOutdatedInfo()
                grouped.packageId = item.packageId
                grouped.depId = item.depId
                grouped.workspacePkgId = item.workspacePkgId
                grouped.isCatalog = true
                grouped.groupedWorkspaceNames = "catalog"
                result.append(grouped)
            }
        }

        return result
    }
}
