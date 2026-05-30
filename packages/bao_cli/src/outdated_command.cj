// 严格翻译自: src/cli/outdated_command.zig
package bao_cli

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_http.*

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
    public var packageName: String
    public var currentVersion: String
    public var updateVersion: String
    public var latestVersion: String
    public var behavior: DepBehavior

    public init() {
        packageId = 0
        depId = 0
        workspacePkgId = 0
        isCatalog = false
        packageName = ""
        currentVersion = ""
        updateVersion = ""
        latestVersion = ""
        behavior = DepBehavior()
    }
}

/// 依赖行为类型
/// 对应 Bun: Dependency.Behavior
public class DepBehavior {
    public var dev: Bool
    public var peer: Bool
    public var optional: Bool

    public init() {
        dev = false
        peer = false
        optional = false
    }

    public func label(): String {
        if (dev) { return " (dev)" }
        if (peer) { return " (peer)" }
        if (optional) { return " (optional)" }
        return ""
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
        Output.prettyln("bao outdated v${Global.PACKAGE_JSON_VERSION_WITH_SHA}")
        Output.flush()

        // 解析命令行参数
        let cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.outdated)

        // 初始化 PackageManager
        let initResult = PackageManager.`init`(ctx, cli, Subcommand.outdated)
        let (manager, originalCwd) = match (initResult) {
            case Some((pm, dir)) => (pm, dir)
            case None =>
                if (!cli.silent) {
                    Output.errGeneric("failed to initialize bao install")
                }
                Global.crash()
        }

        outdated(ctx, originalCwd, manager)
    }

    /// 执行过时检查
    /// 对应 Bun: OutdatedCommand.outdated()
    private static func outdated(ctx: CommandContext, originalCwd: String, manager: PackageManager): Unit {
        // 加载 lockfile
        let lockfileReader = Lockfile()
        let loadResult = lockfileReader.readFromCwd()
        let packages = match (loadResult) {
            case Some(pkgs) => pkgs
            case None =>
                if (manager.options.logLevel != LogLevelFull.Silent) {
                    Output.errGeneric("missing lockfile, nothing outdated")
                }
                Global.crash()
        }

        if (packages.size == 0) {
            if (manager.options.logLevel != LogLevelFull.Silent) {
                Output.errGeneric("missing lockfile, nothing outdated")
            }
            Global.crash()
        }

        let enableAnsiColors = Output.enableAnsiColorsStdout

        // 检查是否有过滤模式
        if (manager.options.filterPatterns.size > 0) {
            let workspacePkgIds = findMatchingWorkspaces(originalCwd, manager, manager.options.filterPatterns)
            populateManifestCache(manager, workspacePkgIds)
            printOutdatedInfoTable(manager, packages, workspacePkgIds, true, enableAnsiColors)
        } else if (manager.options.recursive) {
            let allWorkspaces = getAllWorkspaces(packages)
            populateManifestCache(manager, allWorkspaces)
            printOutdatedInfoTable(manager, packages, allWorkspaces, true, enableAnsiColors)
        } else {
            let rootPkgId = getRootPackageId(packages)
            if (rootPkgId < 0) { return }
            let rootIds = ArrayList<Int64>()
            rootIds.append(rootPkgId)
            populateManifestCache(manager, rootIds)
            printOutdatedInfoTable(manager, packages, rootIds, false, enableAnsiColors)
        }
    }

    /// 获取 root 包 ID
    private static func getRootPackageId(packages: ArrayList<LockfilePackage>): Int64 {
        for (i in 0..packages.size) {
            let pkg = packages[Int64(i)]
            if (pkg.resolution.endsWith("@root:") || pkg.resolution.size == 0) {
                return Int64(i)
            }
        }
        return 0
    }

    /// 获取所有工作区
    /// 对应 Bun: OutdatedCommand.getAllWorkspaces()
    private static func getAllWorkspaces(packages: ArrayList<LockfilePackage>): ArrayList<Int64> {
        let workspacePkgIds = ArrayList<Int64>()

        for (i in 0..packages.size) {
            let pkg = packages[Int64(i)]
            let res = pkg.resolution
            if (res.contains("@workspace:") || res.endsWith("@root:") || res.size == 0) {
                workspacePkgIds.append(Int64(i))
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
        // 加载 lockfile
        let lockfileReader = Lockfile()
        let loadResult = lockfileReader.readFromCwd()
        let packages = match (loadResult) {
            case Some(pkgs) => pkgs
            case None => return ArrayList<Int64>()
        }

        let workspacePkgIds = ArrayList<Int64>()

        // 收集所有工作区
        for (i in 0..packages.size) {
            let pkg = packages[Int64(i)]
            let res = pkg.resolution
            if (res.contains("@workspace:") || res.endsWith("@root:") || res.size == 0) {
                workspacePkgIds.append(Int64(i))
            }
        }

        // 过滤匹配的
        let matched = ArrayList<Int64>()
        for (pkgId in workspacePkgIds) {
            let pkg = packages[pkgId]
            let pkgName = pkg.name

            for (filter in filters) {
                if (filter == "*" || filter == "**") {
                    matched.append(pkgId)
                } else if (globMatch(filter, pkgName)) {
                    matched.append(pkgId)
                }
            }
        }

        return if (matched.size > 0) { matched } else { workspacePkgIds }
    }

    /// 简单 glob 匹配
    private static func globMatch(pattern: String, text: String): Bool {
        if (pattern == "*") { return true }
        if (pattern == "**") { return true }
        return text.contains(pattern) || text == pattern
    }

    /// 填充 manifest 缓存
    /// 对应 Bun: PackageManager.populateManifestCache
    private static func populateManifestCache(manager: PackageManager, pkgIds: ArrayList<Int64>): Unit {
        let lockfileReader = Lockfile()
        let loadResult = lockfileReader.readFromCwd()
        let packages = match (loadResult) {
            case Some(pkgs) => pkgs
            case None => return
        }

        for (pkgId in pkgIds) {
            if (pkgId < packages.size) {
                let pkg = packages[pkgId]
                collectAllDependencyNames(pkg, manager)
            }
        }
    }

    /// 收集包中所有依赖名并请求 manifest
    private static func collectAllDependencyNames(pkg: LockfilePackage, manager: PackageManager): Unit {
        for (name in pkg.dependencies.keys()) {
            requestManifestForPackage(name, manager)
        }
        for (name in pkg.devDependencies.keys()) {
            requestManifestForPackage(name, manager)
        }
        for (name in pkg.optionalDependencies.keys()) {
            requestManifestForPackage(name, manager)
        }
        for (name in pkg.peerDependencies.keys()) {
            requestManifestForPackage(name, manager)
        }
    }

    /// 为包请求 manifest
    private static func requestManifestForPackage(name: String, manager: PackageManager): Unit {
        if (manager.manifests.contains(name)) { return }
        let scope = manager.scopeForPackageName(name)
        manager.enqueueParseNPMPackage(name, scope, None, false, false)
        manager.runTasks()
    }

    /// 打印过时信息表格
    /// 对应 Bun: OutdatedCommand.printOutdatedInfoTable()
    private static func printOutdatedInfoTable(
        manager: PackageManager,
        packages: ArrayList<LockfilePackage>,
        workspacePkgIds: ArrayList<Int64>,
        wasFiltered: Bool,
        enableAnsiColors: Bool
    ): Unit {
        var maxName: Int64 = 0
        var maxCurrent: Int64 = 0
        var maxUpdate: Int64 = 0
        var maxLatest: Int64 = 0
        var maxWorkspace: Int64 = 0

        let outdatedIds = ArrayList<OutdatedInfo>()

        // 收集过时的包
        for (workspacePkgId in workspacePkgIds) {
            if (workspacePkgId >= packages.size) { continue }
            let pkg = packages[workspacePkgId]

            // 合并所有依赖
            let allDeps = HashMap<String, String>()
            for (name in pkg.dependencies.keys()) {
                match (pkg.dependencies.get(name)) {
                    case Some(v) => allDeps.put(name, v)
                    case None => ()
                }
            }
            for (name in pkg.devDependencies.keys()) {
                match (pkg.devDependencies.get(name)) {
                    case Some(v) => allDeps.put(name, v)
                    case None => ()
                }
            }
            for (name in pkg.optionalDependencies.keys()) {
                match (pkg.optionalDependencies.get(name)) {
                    case Some(v) => allDeps.put(name, v)
                    case None => ()
                }
            }
            for (name in pkg.peerDependencies.keys()) {
                match (pkg.peerDependencies.get(name)) {
                    case Some(v) => allDeps.put(name, v)
                    case None => ()
                }
            }

            for (depName in allDeps.keys()) {
                let depVersion = allDeps.get(depName).getOrThrow()

                // 在 lockfile packages 中查找此依赖的已安装版本
                var installedVersion = ""
                var isDev = false
                var isPeer = false
                var isOptional = false

                // 检查是否是 dev/peer/optional
                if (pkg.devDependencies.contains(depName)) { isDev = true }
                if (pkg.peerDependencies.contains(depName)) { isPeer = true }
                if (pkg.optionalDependencies.contains(depName)) { isOptional = true }

                // 查找已安装的版本
                for (i in 0..packages.size) {
                    let p = packages[Int64(i)]
                    if (p.name == depName && p.version.size > 0) {
                        installedVersion = p.version
                        break
                    }
                }

                if (installedVersion.size == 0) { continue }

                // 查询 registry 获取最新版本
                let latestVersion = fetchLatestVersion(depName, manager)
                if (latestVersion.size == 0) { continue }

                // 检查是否过时 (简化: 比较字符串)
                if (installedVersion == latestVersion) { continue }

                let behavior = DepBehavior()
                behavior.dev = isDev
                behavior.peer = isPeer
                behavior.optional = isOptional

                let behaviorLabel = behavior.label()
                let nameLen = Int64(depName.size) + Int64(behaviorLabel.size)
                if (nameLen > maxName) { maxName = nameLen }
                if (Int64(installedVersion.size) > maxCurrent) { maxCurrent = Int64(installedVersion.size) }
                if (Int64(latestVersion.size) > maxUpdate) { maxUpdate = Int64(latestVersion.size) }
                if (Int64(latestVersion.size) > maxLatest) { maxLatest = Int64(latestVersion.size) }

                let info = OutdatedInfo()
                info.packageId = 0
                info.depId = 0
                info.workspacePkgId = workspacePkgId
                info.isCatalog = false
                info.packageName = depName
                info.currentVersion = installedVersion
                info.updateVersion = latestVersion
                info.latestVersion = latestVersion
                info.behavior = behavior
                outdatedIds.append(info)
            }
        }

        if (outdatedIds.size == 0) {
            return
        }

        // 打印表格头
        let showWorkspaceColumn = wasFiltered
        if (showWorkspaceColumn) {
            for (info in outdatedIds) {
                if (info.workspacePkgId < packages.size) {
                    let wsName = packages[info.workspacePkgId].name
                    if (Int64(wsName.size) > maxWorkspace) { maxWorkspace = Int64(wsName.size) }
                }
            }
        }

        let columnPad = 1
        let packageColumnWidth = maxOf(Int64("Package".size), maxName) + Int64(columnPad * 2)
        let currentColumnWidth = maxOf(Int64("Current".size), maxCurrent) + Int64(columnPad * 2)
        let updateColumnWidth = maxOf(Int64("Update".size), maxUpdate) + Int64(columnPad * 2)
        let latestColumnWidth = maxOf(Int64("Latest".size), maxLatest) + Int64(columnPad * 2)
        let workspaceColumnWidth = maxOf(Int64("Workspace".size), maxWorkspace) + Int64(columnPad * 2)

        // 打印分隔线
        let widths = if (showWorkspaceColumn) {
            [packageColumnWidth, currentColumnWidth, updateColumnWidth, latestColumnWidth, workspaceColumnWidth]
        } else {
            [packageColumnWidth, currentColumnWidth, updateColumnWidth, latestColumnWidth]
        }
        printTableSeparator(widths)

        // 打印表头
        let headers = if (showWorkspaceColumn) {
            ["Package", "Current", "Update", "Latest", "Workspace"]
        } else {
            ["Package", "Current", "Update", "Latest"]
        }
        let headerWidths = if (showWorkspaceColumn) {
            [packageColumnWidth, currentColumnWidth, updateColumnWidth, latestColumnWidth, workspaceColumnWidth]
        } else {
            [packageColumnWidth, currentColumnWidth, updateColumnWidth, latestColumnWidth]
        }
        printTableRow(headers, headerWidths, enableAnsiColors)

        // 打印分隔线
        printTableSeparator(headerWidths)

        // 按行为类型分组并打印: prod, dev, peer, optional
        // 1. prod 依赖
        for (info in outdatedIds) {
            if (info.behavior.dev || info.behavior.peer || info.behavior.optional) { continue }
            printOutdatedRow(info, packages, headerWidths, showWorkspaceColumn, enableAnsiColors)
        }
        // 2. dev 依赖
        for (info in outdatedIds) {
            if (!info.behavior.dev) { continue }
            printOutdatedRow(info, packages, headerWidths, showWorkspaceColumn, enableAnsiColors)
        }
        // 3. peer 依赖
        for (info in outdatedIds) {
            if (!info.behavior.peer) { continue }
            printOutdatedRow(info, packages, headerWidths, showWorkspaceColumn, enableAnsiColors)
        }
        // 4. optional 依赖
        for (info in outdatedIds) {
            if (!info.behavior.optional) { continue }
            printOutdatedRow(info, packages, headerWidths, showWorkspaceColumn, enableAnsiColors)
        }

        // 打印底部线
        printTableSeparator(headerWidths)
    }

    /// 打印单行过时包信息
    private static func printOutdatedRow(
        info: OutdatedInfo,
        packages: ArrayList<LockfilePackage>,
        widths: Array<Int64>,
        showWorkspace: Bool,
        enableAnsiColors: Bool
    ): Unit {
        let behaviorStr = info.behavior.label()
        let fullName = "${info.packageName}${behaviorStr}"

        let cells = ArrayList<String>()
        cells.append(fullName)
        cells.append(info.currentVersion)
        cells.append(info.updateVersion)
        cells.append(info.latestVersion)

        let cellWidths = ArrayList<Int64>()
        cellWidths.append(widths[0])
        cellWidths.append(widths[1])
        cellWidths.append(widths[2])
        cellWidths.append(widths[3])

        if (showWorkspace) {
            let wsName = if (info.workspacePkgId < packages.size) {
                packages[info.workspacePkgId].name
            } else {
                ""
            }
            cells.append(wsName)
            cellWidths.append(widths[4])
        }

        printTableRowDirect(cells, cellWidths, enableAnsiColors)
    }

    /// 从 registry 获取最新版本
    /// 对应 Bun: manager.manifests.byNameAllowExpired + findByDistTag("latest")
    private static func fetchLatestVersion(packageName: String, manager: PackageManager): String {
        // 检查 manifest 缓存
        match (manager.manifests.get(packageName)) {
            case Some(manifest) =>
                return extractLatestFromManifest(manifest)
            case None => ()
        }

        // 请求 manifest
        let scope = manager.scopeForPackageName(packageName)
        manager.enqueueParseNPMPackage(packageName, scope, None, false, false)
        manager.runTasks()

        // 再次检查缓存
        match (manager.manifests.get(packageName)) {
            case Some(manifest) =>
                return extractLatestFromManifest(manifest)
            case None => ()
        }

        // 回退: 直接 HTTP 请求 registry
        return fetchLatestFromRegistry(packageName, scope)
    }

    /// 从 manifest 数据提取 latest 版本
    private static func extractLatestFromManifest(manifest: PackageManifestData): String {
        match (manifest.distTags.get("latest")) {
            case Some(v) => return v
            case None => ()
        }
        // 回退: 使用第一个版本
        if (manifest.versions.size > 0) {
            return manifest.versions[manifest.versions.size - 1]
        }
        return ""
    }

    /// 直接从 npm registry 获取 latest 版本
    private static func fetchLatestFromRegistry(packageName: String, scope: NpmRegistryScope): String {
        let registryUrl = scope.url
        let url = "${registryUrl}${packageName}"

        let response = HttpClient.fetch(url)
        if (response.status != Int64(200)) {
            return ""
        }

        let body = response.text()
        if (body.size == 0) { return "" }

        // 解析 JSON 响应
        let parser = PkgJsonParser()
        let json = parser.parse(body)
        match (json) {
            case Some(root) =>
                // 获取 "dist-tags" -> "latest"
                match (PkgJsonHelper.getField(root, "dist-tags")) {
                    case Some(JsonValue.Object(distTags)) =>
                        match (distTags.get("latest")) {
                            case Some(JsonValue.Str(v)) => return v
                            case _ => ()
                        }
                    case _ => ()
                }
                // 回退到 version 字段
                match (PkgJsonHelper.getField(root, "version")) {
                    case Some(JsonValue.Str(v)) => return v
                    case _ => ()
                }
            case None => ()
        }

        return ""
    }

    /// 按 Catalog 分组
    /// 对应 Bun: OutdatedCommand.groupCatalogDependencies()
    private static func groupCatalogDependencies(
        manager: PackageManager,
        outdatedItems: ArrayList<OutdatedInfo>,
        workspacePkgIds: ArrayList<Int64>
    ): ArrayList<GroupedOutdatedInfo> {
        let result = ArrayList<GroupedOutdatedInfo>()

        for (item in outdatedItems) {
            if (!item.isCatalog) {
                let grouped = GroupedOutdatedInfo()
                grouped.packageId = item.packageId
                grouped.depId = item.depId
                grouped.workspacePkgId = item.workspacePkgId
                grouped.isCatalog = false
                result.append(grouped)
            } else {
                let grouped = GroupedOutdatedInfo()
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

    /// 打印表格分隔线
    private static func printTableSeparator(widths: Array<Int64>): Unit {
        let sb = StringBuilder()
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
        let sb = StringBuilder()
        for ((i, cell) in cells.iterator().indexed()) {
            sb.append("| ")
            sb.append(cell)
            let padding = widths[i] - Int64(cell.size) - 2
            for (_ in 0..padding) {
                sb.append(" ")
            }
            sb.append(" ")
        }
        sb.append("|")
        Output.println(sb.toString())
    }

    /// 打印表格行 (ArrayList 版本)
    private static func printTableRowDirect(cells: ArrayList<String>, widths: ArrayList<Int64>, colors: Bool): Unit {
        let sb = StringBuilder()
        for ((i, cell) in cells.iterator().indexed()) {
            sb.append("| ")
            sb.append(cell)
            let cellLen = Int64(cell.size)
            let padding = widths[i] - cellLen - 2
            for (_ in 0..padding) {
                sb.append(" ")
            }
            sb.append(" ")
        }
        sb.append("|")
        Output.println(sb.toString())
    }

    /// 辅助函数: 返回两个 Int64 的最大值
    private static func maxOf(a: Int64, b: Int64): Int64 {
        return if (a > b) { a } else { b }
    }
}
