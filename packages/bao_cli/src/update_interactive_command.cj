// 严格翻译自: src/cli/update_interactive_command.zig
// 对应 Bun: update_interactive_command.zig — 交互式更新命令
//
// TerminalHyperlink, OutdatedPackage, 交互式多选 TUI
// 支持鼠标, 列宽计算, package.json 编辑, catalog 更新
//
// 包含完整 TUI: 多选框, 方向键导航, 鼠标滚动, 版本 diff 着色
package bao_cli

import bao_core.*
import bao_install.*
import bao_collections.*

// ============================================================================
// TerminalHyperlink — 终端超链接
// 严格翻译自: update_interactive_command.zig - TerminalHyperlink
// ============================================================================

/// 终端超链接
/// 对应 Bun: TerminalHyperlink
public class TerminalHyperlink {
    public var link: String
    public var text: String
    public var enabled: Bool

    public init(link: String, text: String, enabled: Bool) {
        this.link = link
        this.text = text
        this.enabled = enabled
    }

    public static func new(link: String, text: String, enabled: Bool): TerminalHyperlink {
        return TerminalHyperlink(link, text, enabled)
    }

    /// 格式化为终端超链接
    /// 严格翻译自: TerminalHyperlink.format()
    public func format(): String {
        if (enabled && !link.isEmpty()) {
            let ESC = ""
            let OSC8 = "${ESC}]8;;"
            let ST = "${ESC}\\"
            return "${OSC8}${link}${ST}${text}${OSC8}${ST}"
        }
        return text
    }
}

// ============================================================================
// OutdatedPackage — 过时包信息
// 严格翻译自: update_interactive_command.zig - OutdatedPackage
// ============================================================================

/// 过时的包信息
/// 对应 Bun: OutdatedPackage
public class OutdatedPackage {
    public var name: String
    public var currentVersion: String
    public var latestVersion: String
    public var updateVersion: String
    public var packageId: Int64
    public var depId: Int64
    public var workspacePkgId: Int64
    public var dependencyType: String
    public var workspaceName: String
    public var behavior: DependencyBehavior
    public var useLatest: Bool
    public var manager: PackageManager
    public var isCatalog: Bool
    public var catalogName: ?String

    public init() {
        name = ""
        currentVersion = ""
        latestVersion = ""
        updateVersion = ""
        packageId = INVALID_PACKAGE_ID
        depId = 0
        workspacePkgId = INVALID_PACKAGE_ID
        dependencyType = "dependencies"
        workspaceName = ""
        behavior = DependencyBehavior()
        useLatest = false
        manager = PackageManager()
        isCatalog = false
        catalogName = None
    }
}

/// 依赖行为标记
/// 严格翻译自: install.Dependency.Behavior
public class DependencyBehavior {
    public var dev: Bool
    public var optional: Bool
    public var peer: Bool
    public var isWorkspace: Bool
    public var isCatalog: Bool

    public init() {
        dev = false
        optional = false
        peer = false
        isWorkspace = false
        isCatalog = false
    }
}

/// 包来源
/// 对应 Bun: PackageSource
public enum PackageSource {
    | npm       // npm registry
    | workspace // workspace 依赖
    | catalog   // catalog 依赖
}

// ============================================================================
// CatalogUpdate — catalog 更新信息
// 严格翻译自: update_interactive_command.zig - CatalogUpdate
// ============================================================================

/// Catalog 更新
public class CatalogUpdate {
    public var version: String
    public var workspacePath: String

    public init(version: String, workspacePath: String) {
        this.version = version
        this.workspacePath = workspacePath
    }
}

// ============================================================================
// CatalogUpdateRequest — catalog 更新请求
// 严格翻译自: update_interactive_command.zig - CatalogUpdateRequest
// ============================================================================

/// Catalog 更新请求
public class CatalogUpdateRequest {
    public var packageName: String
    public var newVersion: String
    public var catalogName: ?String

    public init(packageName: String, newVersion: String, catalogName: ?String) {
        this.packageName = packageName
        this.newVersion = newVersion
        this.catalogName = catalogName
    }
}

// ============================================================================
// PackageUpdate — 包更新信息
// 严格翻译自: update_interactive_command.zig - PackageUpdate
// ============================================================================

/// 包更新信息
public class PackageUpdate {
    public var name: String
    public var targetVersion: String
    public var depType: String     // "dependencies", "devDependencies", etc.
    public var workspacePath: String
    public var originalVersion: String
    public var packageId: Int64

    public init() {
        name = ""
        targetVersion = ""
        depType = "dependencies"
        workspacePath = ""
        originalVersion = ""
        packageId = INVALID_PACKAGE_ID
    }
}

// ============================================================================
// ColumnWidths — 列宽计算
// 严格翻译自: update_interactive_command.zig - ColumnWidths
// ============================================================================

/// 列宽计算结果
public class ColumnWidths {
    public var nameWidth: Int64
    public var currentWidth: Int64
    public var targetWidth: Int64
    public var latestWidth: Int64
    public var workspaceWidth: Int64
    public var showWorkspace: Bool

    public init() {
        nameWidth = "Package".length
        currentWidth = "Current".length
        targetWidth = "Target".length
        latestWidth = "Latest".length
        workspaceWidth = "Workspace".length
        showWorkspace = false
    }
}

// ============================================================================
// TerminalSize — 终端尺寸
// 严格翻译自: update_interactive_command.zig - TerminalSize
// ============================================================================

/// 终端尺寸
public class TerminalSize {
    public var height: Int64
    public var width: Int64

    public init(height: Int64, width: Int64) {
        this.height = height
        this.width = width
    }
}

// ============================================================================
// MultiSelectState — 多选状态
// 严格翻译自: update_interactive_command.zig - MultiSelectState
// ============================================================================

/// 多选 TUI 状态
public class MultiSelectState {
    public var packages: ArrayList<OutdatedPackage>
    public var selected: Array<Bool>
    public var cursor: Int64
    public var viewportStart: Int64
    public var viewportHeight: Int64
    public var toggleAll: Bool
    public var maxNameLen: Int64
    public var maxCurrentLen: Int64
    public var maxUpdateLen: Int64
    public var maxLatestLen: Int64
    public var maxWorkspaceLen: Int64
    public var showWorkspace: Bool

    public init() {
        packages = ArrayList<OutdatedPackage>()
        selected = []
        cursor = 0
        viewportStart = 0
        viewportHeight = 20
        toggleAll = false
        maxNameLen = 0
        maxCurrentLen = 0
        maxUpdateLen = 0
        maxLatestLen = 0
        maxWorkspaceLen = 0
        showWorkspace = false
    }
}

// ============================================================================
// VersionDiffType — 版本差异类型
// 严格翻译自: update_interactive_command.zig - whichVersionIsDifferent 结果
// ============================================================================

/// 版本差异类型
public enum VersionDiffType {
    | major
    | minor
    | patch
    | other
}

// ============================================================================
// UpdateInteractiveCommand — 交互式更新命令
// 严格翻译自: update_interactive_command.zig - UpdateInteractiveCommand
//
// Bun 的完整实现包含终端 TUI (多选框, 鼠标支持, 方向键导航),
// 此处保留完整的 TUI 逻辑
// ============================================================================

/// 交互式更新命令
/// 对应 Bun: UpdateInteractiveCommand
public class UpdateInteractiveCommand {

    /// 构建 package.json 路径
    /// 严格翻译自: buildPackageJsonPath()
    private static func buildPackageJsonPath(rootDir: String, workspacePath: String): String {
        if (workspacePath.length > 0) {
            return Path.join(rootDir, workspacePath, "package.json")
        }
        return Path.join(rootDir, "package.json")
    }

    /// 保存 package.json 文件
    /// 严格翻译自: savePackageJson()
    ///
    /// Bun 原始流程:
    ///   1. 使用 JSPrinter 序列化 AST
    ///   2. 保留尾部换行符
    ///   3. 写入文件
    ///   4. 更新缓存
    private static func savePackageJson(manager: PackageManager, packageJsonAst: PackageJsonAst, packageJsonPath: String): Unit {
        // 序列化 AST 为 JSON 字符串
        let preserveTrailingNewline = packageJsonAst.source.length > 0 &&
            packageJsonAst.source[packageJsonAst.source.length - 1] == '\n'

        var newContent = packageJsonAst.serialize(preserveTrailingNewline)

        // 写入文件
        // 严格翻译自: std.fs.cwd().createFile(package_json_path, .{})
        let writeFileResult = BaoFile.writeAllText(packageJsonPath, newContent)
        match (writeFileResult) {
            case Some(_) =>
                // 更新缓存以使 installWithManager 看到新的 package.json
                // 严格翻译自: package_json.*.source.contents = new_package_json_source
                packageJsonAst.source = newContent
            case None =>
                Output.errGeneric("Failed to write package.json at ${packageJsonPath}")
        }
    }

    /// 从更新列表更新 package.json 文件
    /// 严格翻译自: updatePackageJsonFilesFromUpdates()
    ///
    /// Bun 原始流程:
    ///   1. 按工作区分组更新
    ///   2. 对每个工作区加载并解析 package.json
    ///   3. 找到对应的依赖节并更新版本
    ///   4. 保留版本前缀 (^, ~, >=, etc.)
    ///   5. 保存修改后的文件
    private static func updatePackageJsonFilesFromUpdates(manager: PackageManager, updates: ArrayList<PackageUpdate>): Unit {
        // 按工作区分组更新
        // 严格翻译自: var workspace_groups = bun.StringHashMap(...)
        let workspaceGroups = HashMap<String, ArrayList<PackageUpdate>>()

        for (update in updates) {
            var list = workspaceGroups.get(update.workspacePath)
            if (list.isNone()) {
                list = ArrayList<PackageUpdate>()
                workspaceGroups.put(update.workspacePath, list.getOrThrow())
            }
            list.getOrThrow().append(update)
        }

        // 处理每个工作区
        // 严格翻译自: var it = workspace_groups.iterator(); while (it.next()) |entry|
        let rootDir = manager.fileSystem.topLevelDir

        for ((workspacePath, workspaceUpdates) in workspaceGroups) {
            var pathBuf = ""
            let packageJsonPath = buildPackageJsonPath(rootDir, workspacePath)

            // 加载并解析 package.json
            // 严格翻译自: manager.workspace_package_json_cache.getWithPath(...)
            let packageJson = manager.workspacePackageJsonCache.getWithPath(
                packageJsonPath, GuessIndentation: true
            )
            if (packageJson.isNone()) {
                Output.errGeneric("Failed to parse package.json at ${packageJsonPath}")
                continue
            }

            var modified = false

            // 在此工作区的 package.json 中更新每个包
            for (update in workspaceUpdates) {
                // 在正确的依赖节中查找包
                if (packageJson.getOrThrow().root.isObject()) {
                    let section = packageJson.getOrThrow().root.asProperty(update.depType)
                    if (section.isSome() && section.getOrThrow().isObject()) {
                        let versionQuery = section.getOrThrow().asProperty(update.name)
                        if (versionQuery.isSome() && version.getOrThrow().isString()) {
                            // 获取原始版本以保留前缀
                            let originalVersion = versionQuery.getOrThrow().asString()

                            // 保留版本前缀
                            let versionWithPrefix = preserveVersionPrefix(
                                originalVersion, update.targetVersion
                            )

                            // 使用 put 更新版本
                            section.getOrThrow().put(update.name, versionWithPrefix)
                            modified = true
                        }
                    }
                }
            }

            // 如果修改了则写入更新的 package.json
            if (modified) {
                savePackageJson(manager, packageJson.getOrThrow(), packageJsonPath)
            }
        }
    }

    /// 更新 catalog 定义
    /// 严格翻译自: updateCatalogDefinitions()
    ///
    /// Bun 原始流程:
    ///   1. 按 catalog_key 分组更新
    ///   2. 对每个工作区加载 package.json
    ///   3. 调用 editCatalogDefinitions 更新 catalog
    ///   4. 保存修改后的文件
    private static func updateCatalogDefinitions(manager: PackageManager, catalogUpdates: HashMap<String, CatalogUpdate>): Unit {
        // 按 catalog 更新按工作区分组
        let workspaceCatalogUpdates = HashMap<String, ArrayList<CatalogUpdateRequest>>()

        for ((catalogKey, update) in catalogUpdates) {
            var list = workspaceCatalogUpdates.get(update.workspacePath)
            if (list.isNone()) {
                list = ArrayList<CatalogUpdateRequest>()
                workspaceCatalogUpdates.put(update.workspacePath, list.getOrThrow())
            }

            // 解析 catalog_key (格式: "package_name" 或 "package_name:catalog_name")
            let colonIndex = catalogKey.indexOf(":")
            let packageName: String
            let catalogName: ?String
            match (colonIndex) {
                case Some(idx) =>
                    packageName = catalogKey.substring(0, idx)
                    catalogName = Some(catalogKey.substring(idx + 1))
                case None =>
                    packageName = catalogKey
                    catalogName = None
            }

            list.getOrThrow().append(CatalogUpdateRequest(packageName, update.version, catalogName))
        }

        // 更新每个工作区的 catalog 定义
        let rootDir = manager.fileSystem.topLevelDir

        for ((workspacePath, updatesForWorkspace) in workspaceCatalogUpdates) {
            let packageJsonPath = buildPackageJsonPath(rootDir, workspacePath)

            let packageJson = manager.workspacePackageJsonCache.getWithPath(
                packageJsonPath, GuessIndentation: true
            )
            if (packageJson.isNone()) {
                Output.errGeneric("Failed to parse package.json at ${packageJsonPath}")
                continue
            }

            // 使用 PackageJSONEditor 更新 catalog
            editCatalogDefinitions(manager, updatesForWorkspace, packageJson.getOrThrow().root)

            // 保存更新的 package.json
            savePackageJson(manager, packageJson.getOrThrow(), packageJsonPath)
        }
    }

    /// 编辑 package.json 中的 catalog 定义
    /// 严格翻译自: editCatalogDefinitions()
    public static func editCatalogDefinitions(manager: PackageManager, updates: ArrayList<CatalogUpdateRequest>, currentPackageJson: JsonExpr): Unit {
        for (update in updates) {
            match (update.catalogName) {
                case Some(catalogName) =>
                    updateNamedCatalog(currentPackageJson, catalogName, update.packageName, update.newVersion)
                case None =>
                    updateDefaultCatalog(currentPackageJson, update.packageName, update.newVersion)
            }
        }
    }

    /// 更新默认 catalog
    /// 严格翻译自: updateDefaultCatalog()
    private static func updateDefaultCatalog(packageJson: JsonExpr, packageName: String, newVersion: String): Unit {
        // 获取或创建 catalog 对象
        // 首先检查 workspaces.catalog
        var catalogObj: JsonExpr = JsonExpr.Null

        let workspaces = packageJson.asProperty("workspaces")
        if (workspaces.isSome() && workspaces.getOrThrow().isObject()) {
            let catalog = workspaces.getOrThrow().asProperty("catalog")
            if (catalog.isSome() && catalog.getOrThrow().isObject()) {
                catalogObj = catalog.getOrThrow()
            }
        }

        // 回退到根级别的 catalog
        if (!catalogObj.isObject()) {
            let rootCatalog = packageJson.asProperty("catalog")
            if (rootCatalog.isSome() && rootCatalog.getOrThrow().isObject()) {
                catalogObj = rootCatalog.getOrThrow()
            }
        }

        if (!catalogObj.isObject()) {
            catalogObj = JsonExpr.newObject()
        }

        // 获取原始版本以保留前缀
        var versionWithPrefix = newVersion
        let existingProp = catalogObj.asProperty(packageName)
        if (existingProp.isSome() && existingProp.getOrThrow().isString()) {
            let originalVersion = existingProp.getOrThrow().asString()
            versionWithPrefix = preserveVersionPrefix(originalVersion, newVersion)
        }

        // 更新或添加包版本
        catalogObj.put(packageName, versionWithPrefix)

        // 检查是否需要在 workspaces.catalog 或根级别 catalog 下更新
        if (workspaces.isSome() && workspaces.getOrThrow().isObject()) {
            if (workspaces.getOrThrow().asProperty("catalog").isSome()) {
                // 在 workspaces.catalog 下更新
                workspaces.getOrThrow().put("catalog", catalogObj)
                return
            }
        }

        // 否则在根级别更新
        packageJson.put("catalog", catalogObj)
    }

    /// 更新命名 catalog
    /// 严格翻译自: updateNamedCatalog()
    private static func updateNamedCatalog(packageJson: JsonExpr, catalogName: String, packageName: String, newVersion: String): Unit {
        // 获取或创建 catalogs 对象
        var catalogsObj: JsonExpr = JsonExpr.Null

        let workspaces = packageJson.asProperty("workspaces")
        if (workspaces.isSome() && workspaces.getOrThrow().isObject()) {
            let catalogs = workspaces.getOrThrow().asProperty("catalogs")
            if (catalogs.isSome() && catalogs.getOrThrow().isObject()) {
                catalogsObj = catalogs.getOrThrow()
            }
        }

        // 回退到根级别的 catalogs
        if (!catalogsObj.isObject()) {
            let rootCatalogs = packageJson.asProperty("catalogs")
            if (rootCatalogs.isSome() && rootCatalogs.getOrThrow().isObject()) {
                catalogsObj = rootCatalogs.getOrThrow()
            }
        }

        if (!catalogsObj.isObject()) {
            catalogsObj = JsonExpr.newObject()
        }

        // 获取或创建特定 catalog
        var catalogObj: JsonExpr = catalogsObj.asProperty(catalogName)
        if (!catalogObj.isObject()) {
            catalogObj = JsonExpr.newObject()
        }

        // 获取原始版本以保留前缀
        var versionWithPrefix = newVersion
        let existingProp = catalogObj.asProperty(packageName)
        if (existingProp.isSome() && existingProp.getOrThrow().isString()) {
            let originalVersion = existingProp.getOrThrow().asString()
            versionWithPrefix = preserveVersionPrefix(originalVersion, newVersion)
        }

        // 更新或添加包版本
        catalogObj.put(packageName, versionWithPrefix)

        // 在 catalogs 对象中更新 catalog
        catalogsObj.put(catalogName, catalogObj)

        // 检查是否需要在 workspaces.catalogs 或根级别 catalogs 下更新
        if (workspaces.isSome() && workspaces.getOrThrow().isObject()) {
            if (workspaces.getOrThrow().asProperty("catalogs").isSome()) {
                workspaces.getOrThrow().put("catalogs", catalogsObj)
                return
            }
        }

        // 否则在根级别更新
        packageJson.put("catalogs", catalogsObj)
    }

    /// 保留版本前缀
    /// 严格翻译自: preserveVersionPrefix()
    ///
    /// 保留 ^, ~, >=, <=, >, <, =, npm: 等前缀
    private static func preserveVersionPrefix(originalVersion: String, newVersion: String): String {
        if (originalVersion.length > 1) {
            var origVersion = originalVersion
            var alias: ?String = None

            // 保留 npm: 前缀
            if (originalVersion.startsWith("npm:")) {
                let afterNpm = originalVersion.substring("npm:".length)
                let atIndex = afterNpm.lastIndexOf('@')
                match (atIndex) {
                    case Some(i) =>
                        alias = afterNpm.substring(0, i)
                        if (i + 2 < afterNpm.length) {
                            origVersion = afterNpm.substring(i + 1)
                        }
                    case None =>
                        alias = afterNpm
                }
            }

            // 保留其他版本前缀
            let firstChar = origVersion[0]
            if (firstChar == '^' || firstChar == '~' || firstChar == '>' || firstChar == '<' || firstChar == '=') {
                let secondChar = origVersion.length > 1 ? origVersion[1] : ' '
                if ((firstChar == '>' || firstChar == '<') && secondChar == '=') {
                    match (alias) {
                        case Some(a) => return "npm:${a}@${firstChar}=${newVersion}"
                        case None => return "${firstChar}=${newVersion}"
                    }
                }
                match (alias) {
                    case Some(a) => return "npm:${a}@${firstChar}${newVersion}"
                    case None => return "${firstChar}${newVersion}"
                }
            }
            match (alias) {
                case Some(a) => return "npm:${a}@${newVersion}"
                case None => ()
            }
        }
        return newVersion
    }

    /// 执行交互式更新
    /// 严格翻译自: UpdateInteractiveCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        Output.prettyLn("<r><b>bao update --interactive <r><d>v${Global.packageJsonVersionWithSha}<r>")

        let cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.update)
        let (manager, cwd) = match (PackageManager.`init`(ctx, cli, Subcommand.update)) {
            case Some((pm, dir)) => (pm, dir)
            case None =>
                if (!cli.silent) {
                    Output.errGeneric("Failed to initialize bao install")
                }
                Global.exit(1)
        }

        updateInteractive(ctx, cwd, manager)
    }

    /// 交互式更新主逻辑
    /// 严格翻译自: updateInteractive()
    ///
    /// Bun 原始流程:
    ///   1. 加载 lockfile
    ///   2. 获取工作区包 ID 列表
    ///   3. 填充 manifest 缓存
    ///   4. 获取过时包列表
    ///   5. 提示用户选择更新
    ///   6. 按工作区分组并更新 package.json
    ///   7. 更新 catalog 定义
    ///   8. 重新安装
    private static func updateInteractive(ctx: CommandContext, originalCwd: String, manager: PackageManager): Unit {
        // 加载 lockfile
        // 严格翻译自: manager.lockfile.loadFromCwd(...)
        let loadLockfileResult = manager.lockfile.loadFromCwd(manager, ctx.allocator, ctx.log, true)

        match (loadLockfileResult) {
            case LoadResult.notFound =>
                if (manager.options.logLevel != LogLevel.silent) {
                    Output.errGeneric("missing lockfile, nothing outdated")
                }
                Global.exit(1)
            case LoadResult.err(cause) =>
                if (manager.options.logLevel != LogLevel.silent) {
                    match (cause.step) {
                        case LoadStep.openFile => Output.errGeneric("failed to open lockfile: ${cause.value}")
                        case LoadStep.parseFile => Output.errGeneric("failed to parse lockfile: ${cause.value}")
                        case LoadStep.readFile => Output.errGeneric("failed to read lockfile: ${cause.value}")
                        case LoadStep.migrating => Output.errGeneric("failed to migrate lockfile: ${cause.value}")
                    }
                    if (ctx.log.hasErrors()) {
                        manager.log.print(Output.errorWriter())
                    }
                }
                Global.exit(1)
            case LoadResult.ok(ok) =>
                manager.lockfile = ok.lockfile
        }

        // 获取工作区包 ID 列表
        // 严格翻译自: workspace_pkg_ids = ...
        let workspacePkgIds: Array<Int64>
        if (manager.options.filterPatterns.length > 0) {
            workspacePkgIds = findMatchingWorkspaces(originalCwd, manager, manager.options.filterPatterns)
        } else if (manager.options.do.recursive) {
            workspacePkgIds = getAllWorkspaces(manager)
        } else {
            let rootPkgId = manager.rootPackageId.get(manager.lockfile, manager.workspaceNameHash)
            if (rootPkgId == INVALID_PACKAGE_ID) {
                return
            }
            workspacePkgIds = [rootPkgId]
        }

        manager.populateManifestCache(workspacePkgIds)

        // 获取过时包
        let outdatedPackages = getOutdatedPackages(manager, workspacePkgIds)

        if (outdatedPackages.size == 0) {
            Output.prettyLn("<r><green>✓<r> All packages are up to date!")
            return
        }

        // 提示用户选择包
        let selected = promptForUpdates(outdatedPackages)

        // 按工作区分组选中的包
        // 严格翻译自: var workspace_updates = bun.StringHashMap(...)
        let workspaceUpdates = HashMap<String, ArrayList<String>>()

        // 单独跟踪 catalog 更新 (catalog_key -> {version, workspace_path})
        let catalogUpdates = HashMap<String, CatalogUpdate>()

        // 收集所有包更新及完整信息
        let packageUpdates = ArrayList<PackageUpdate>()

        // 处理选中的包
        for (i in 0..outdatedPackages.size) {
            let pkg = outdatedPackages[i]
            if (!selected[i]) {
                continue
            }

            // 如果请求则使用最新版本
            let targetVersion = if (pkg.useLatest) {
                pkg.latestVersion
            } else {
                pkg.updateVersion
            }

            if (pkg.currentVersion == targetVersion) {
                continue
            }

            // 对于 catalog 依赖, 单独收集以稍后更新 catalog 定义
            if (pkg.isCatalog) {
                let catalogKey = match (pkg.catalogName) {
                    case Some(catalogName) => "${pkg.name}:${catalogName}"
                    case None => pkg.name
                }

                catalogUpdates.put(catalogKey, CatalogUpdate(
                    targetVersion, ""
                ))
                continue
            }

            // 获取此包的工作区路径
            let workspaceResolution = manager.lockfile.packages.itemsResolution()[pkg.workspacePkgId]
            let workspacePath = if (workspaceResolution.tag == ResolutionTag.workspace) {
                workspaceResolution.workspace.slice(manager.lockfile.buffers.stringBytes)
            } else {
                "" // 根工作区
            }

            // 添加包更新及完整信息
            packageUpdates.append(PackageUpdate(
                name: pkg.name,
                targetVersion: targetVersion,
                depType: pkg.dependencyType,
                workspacePath: workspacePath,
                originalVersion: pkg.currentVersion,
                packageId: pkg.packageId
            ))
        }

        // 检查是否有更新
        let hasPackageUpdates = packageUpdates.size > 0
        let hasCatalogUpdates = catalogUpdates.size > 0

        if (!hasPackageUpdates && !hasCatalogUpdates) {
            Output.prettyLn("<r><yellow>!</r> No packages selected for update")
            return
        }

        // 实际更新选中的包
        if (hasPackageUpdates || hasCatalogUpdates) {
            if (manager.options.dryRun) {
                Output.prettyLn("\n<r><yellow>Dry run mode: showing what would be updated<r>")

                // dry-run 模式下, 只显示将要更新的内容而不修改文件
                for (update in packageUpdates) {
                    let workspaceDisplay = if (update.workspacePath.length > 0) {
                        update.workspacePath
                    } else {
                        "root"
                    }
                    Output.prettyLn("→ Would update ${update.name} to ${update.targetVersion} in ${workspaceDisplay} (${update.depType})")
                }

                if (hasCatalogUpdates) {
                    for ((catalogKey, catalogUpdate) in catalogUpdates) {
                        Output.prettyLn("→ Would update catalog ${catalogKey} to ${catalogUpdate.version}")
                    }
                }

                Output.prettyLn("\n<r><yellow>Dry run complete - no changes made<r>")
            } else {
                Output.prettyLn("\n<r><cyan>Installing updates...<r>")

                // 如果需要, 先更新 catalog 定义
                if (hasCatalogUpdates) {
                    updateCatalogDefinitions(manager, catalogUpdates)
                }

                // 直接更新所有 package.json 文件 (快速!)
                if (hasPackageUpdates) {
                    updatePackageJsonFilesFromUpdates(manager, packageUpdates)
                }

                manager.toUpdate = true

                // 重置计时器以显示实际安装时间
                PackageManager.installWithManager(manager, ctx)
            }
        }
    }

    /// 获取所有工作区
    /// 严格翻译自: getAllWorkspaces()
    private static func getAllWorkspaces(manager: PackageManager): Array<Int64> {
        let lockfile = manager.lockfile
        let packages = lockfile.packages.slice()
        let pkgResolutions = packages.itemsResolution()

        let workspacePkgIds = ArrayList<Int64>()
        for (i in 0..pkgResolutions.length) {
            let resolution = pkgResolutions[i]
            if (resolution.tag != ResolutionTag.workspace && resolution.tag != ResolutionTag.root) {
                continue
            }
            workspacePkgIds.append(i)
        }
        return workspacePkgIds.toArray()
    }

    /// 查找匹配的工作区
    /// 严格翻译自: findMatchingWorkspaces()
    private static func findMatchingWorkspaces(originalCwd: String, manager: PackageManager, filters: Array<String>): Array<Int64> {
        let lockfile = manager.lockfile
        let packages = lockfile.packages.slice()
        let pkgNames = packages.itemsName()
        let pkgResolutions = packages.itemsResolution()
        let stringBuf = lockfile.buffers.stringBytes

        let workspacePkgIds = ArrayList<Int64>()
        for (i in 0..pkgResolutions.length) {
            let resolution = pkgResolutions[i]
            if (resolution.tag != ResolutionTag.workspace && resolution.tag != ResolutionTag.root) {
                continue
            }
            workspacePkgIds.append(i)
        }

        // 将 filter 模式转换为 WorkspaceFilter
        let convertedFilters = ArrayList<WorkspaceFilter>()
        for (filter in filters) {
            convertedFilters.append(WorkspaceFilter.`init`(filter, originalCwd))
        }

        // 将所有匹配的工作区移到数组前面
        var i = 0
        while (i < workspacePkgIds.size) {
            let workspacePkgId = workspacePkgIds[i]
            let matched = checkWorkspaceMatch(
                workspacePkgId, pkgNames, pkgResolutions,
                stringBuf, convertedFilters, manager
            )

            if (matched) {
                i += 1
            } else {
                workspacePkgIds.removeAt(i)
            }
        }

        return workspacePkgIds.toArray()
    }

    /// 检查工作区是否匹配 filter
    private static func checkWorkspaceMatch(
        workspacePkgId: Int64, pkgNames: Array<String>,
        pkgResolutions: Array<Resolution>, stringBuf: String,
        filters: ArrayList<WorkspaceFilter>, manager: PackageManager
    ): Bool {
        let resolution = pkgResolutions[workspacePkgId]

        for (filter in filters) {
            match (filter.kind) {
                case WorkspaceFilterKind.path(pattern) =>
                    let resPath = match (resolution.tag) {
                        case ResolutionTag.workspace => resolution.workspace.slice(stringBuf)
                        case ResolutionTag.root => manager.fileSystem.topLevelDir
                        case _ => ""
                    }
                    if (!Glob.`match`(pattern, Path.withoutTrailingSlash(resPath)).matches()) {
                        return false
                    }
                case WorkspaceFilterKind.name(pattern) =>
                    let name = pkgNames[workspacePkgId].slice(stringBuf)
                    if (!Glob.`match`(pattern, name).matches()) {
                        return false
                    }
                case WorkspaceFilterKind.all =>
                    // 匹配所有
            }
        }
        return true
    }

    /// 分组 catalog 依赖
    /// 严格翻译自: groupCatalogDependencies()
    ///
    /// Bun 原始流程:
    ///   1. 将 catalog 依赖按 name 分组
    ///   2. 非catalog 依赖直接保留
    ///   3. 合并同名的 catalog 依赖的工作区名称
    private static func groupCatalogDependencies(packages: ArrayList<OutdatedPackage>): ArrayList<OutdatedPackage> {
        let catalogMap = HashMap<String, ArrayList<OutdatedPackage>>()
        let result = ArrayList<OutdatedPackage>()

        for (pkg in packages) {
            if (pkg.isCatalog) {
                var list = catalogMap.get(pkg.name)
                if (list.isNone()) {
                    list = ArrayList<OutdatedPackage>()
                    catalogMap.put(pkg.name, list.getOrThrow())
                }
                list.getOrThrow().append(pkg)
            } else {
                result.append(pkg)
            }
        }

        // 添加分组的 catalog 依赖
        for ((_, catalogPackages) in catalogMap) {
            if (catalogPackages.size > 0) {
                var first = catalogPackages[0]

                // 构建合并的工作区名称
                var workspaceNames = ""
                match (first.catalogName) {
                    case Some(catalogName) =>
                        workspaceNames = "catalog:${catalogName} ("
                    case None =>
                        workspaceNames = "catalog ("
                }

                for (j in 0..catalogPackages.size) {
                    if (j > 0) {
                        workspaceNames += ", "
                    }
                    workspaceNames += catalogPackages[j].workspaceName
                }
                workspaceNames += ")"

                first.workspaceName = workspaceNames
                result.append(first)
            }
        }

        return result
    }

    /// 获取过时包列表
    /// 严格翻译自: getOutdatedPackages()
    ///
    /// Bun 原始流程:
    ///   1. 遍历工作区包 ID
    ///   2. 对每个工作区的依赖查找 resolved package
    ///   3. 查询 manifest 获取最新版本
    ///   4. 比较 current/update/latest 版本
    ///   5. 分组 catalog 依赖
    ///   6. 按依赖类型和名称排序
    private static func getOutdatedPackages(manager: PackageManager, workspacePkgIds: Array<Int64>): ArrayList<OutdatedPackage> {
        let lockfile = manager.lockfile
        let stringBuf = lockfile.buffers.stringBytes
        let packages = lockfile.packages.slice()
        let pkgNames = packages.itemsName()
        let pkgResolutions = packages.itemsResolution()
        let pkgDependencies = packages.itemsDependencies()

        let outdatedPackages = ArrayList<OutdatedPackage>()

        for (workspacePkgId in workspacePkgIds) {
            let pkgDeps = pkgDependencies[workspacePkgId]
            for (depId in pkgDeps.begin()..pkgDeps.end()) {
                let packageId = lockfile.buffers.resolutions.items[depId]
                if (packageId == INVALID_PACKAGE_ID) {
                    continue
                }
                let dep = lockfile.buffers.dependencies.items[depId]
                let resolvedVersion = manager.lockfile.resolveCatalogDependency(dep)
                if (resolvedVersion.isNone()) {
                    continue
                }
                if (resolvedVersion.getOrThrow().tag != ResolutionTag.npm && resolvedVersion.getOrThrow().tag != ResolutionTag.distTag) {
                    continue
                }
                let resolution = pkgResolutions[packageId]
                if (resolution.tag != ResolutionTag.npm) {
                    continue
                }

                let nameSlice = dep.name.slice(stringBuf)
                let packageName = pkgNames[packageId].slice(stringBuf)

                var expired = false
                let manifest = manager.manifests.byNameAllowExpired(
                    manager, manager.scopeForPackageName(packageName),
                    packageName, expired, ManifestLoadType.loadFromMemoryFallbackToDisk,
                    manager.options.minimumReleaseAgeMs.isSome()
                )
                if (manifest.isNone()) {
                    continue
                }

                let latest = manifest.getOrThrow().findByDistTagWithFilter(
                    "latest", manager.options.minimumReleaseAgeMs,
                    manager.options.minimumReleaseAgeExcludes
                )
                if (latest.isNone()) {
                    continue
                }

                // 在交互模式下, 将约束更新版本显示为 "Target"
                // 但始终包含包 (不过滤掉破坏性变更)
                let updateVersion = if (resolvedVersion.getOrThrow().tag == ResolutionTag.npm) {
                    manifest.getOrThrow().findBestVersionWithFilter(
                        resolvedVersion.getOrThrow().value.npm.version, stringBuf,
                        manager.options.minimumReleaseAgeMs,
                        manager.options.minimumReleaseAgeExcludes
                    ) ?? latest.getOrThrow()
                } else {
                    manifest.getOrThrow().findByDistTagWithFilter(
                        resolvedVersion.getOrThrow().value.distTag.tag.slice(stringBuf),
                        manager.options.minimumReleaseAgeMs,
                        manager.options.minimumReleaseAgeExcludes
                    ) ?? latest.getOrThrow()
                }

                // 只有当约束更新和最新版本都与当前版本相同时才跳过
                let currentVer = resolution.value.npm.version
                let updateVer = updateVersion.version
                let latestVer = latest.getOrThrow().version

                let updateIsSame = (currentVer.major == updateVer.major &&
                    currentVer.minor == updateVer.minor &&
                    currentVer.patch == updateVer.patch &&
                    currentVer.tag.eql(updateVer.tag))

                let latestIsSame = (currentVer.major == latestVer.major &&
                    currentVer.minor == latestVer.minor &&
                    currentVer.patch == latestVer.patch &&
                    currentVer.tag.eql(latestVer.tag))

                if (updateIsSame && latestIsSame) {
                    continue
                }

                let currentVersionStr = resolution.value.npm.version.fmt(stringBuf)
                let updateVersionStr = updateVersion.version.fmt(manifest.getOrThrow().stringBuf)
                let latestVersionStr = latest.getOrThrow().version.fmt(manifest.getOrThrow().stringBuf)

                // 确定依赖类型
                let depType = if (dep.behavior.dev) {
                    "devDependencies"
                } else if (dep.behavior.optional) {
                    "optionalDependencies"
                } else if (dep.behavior.peer) {
                    "peerDependencies"
                } else {
                    "dependencies"
                }

                // 获取工作区名称
                let workspaceResolution = pkgResolutions[workspacePkgId]
                let workspaceName = if (workspaceResolution.tag == ResolutionTag.workspace) {
                    pkgNames[workspacePkgId].slice(stringBuf)
                } else {
                    ""
                }

                let catalogNameStr = if (dep.version.tag == VersionTag.catalog) {
                    dep.version.value.catalog.slice(stringBuf)
                } else {
                    ""
                }

                let catalogName: ?String = if (catalogNameStr.length > 0) {
                    Some(catalogNameStr)
                } else {
                    None
                }

                let pkg = OutdatedPackage()
                pkg.name = nameSlice
                pkg.currentVersion = currentVersionStr
                pkg.latestVersion = latestVersionStr
                pkg.updateVersion = updateVersionStr
                pkg.packageId = packageId
                pkg.depId = depId
                pkg.workspacePkgId = workspacePkgId
                pkg.dependencyType = depType
                pkg.workspaceName = workspaceName
                pkg.behavior = dep.behavior
                pkg.manager = manager
                pkg.isCatalog = dep.version.tag == VersionTag.catalog
                pkg.catalogName = catalogName
                pkg.useLatest = manager.options.do.updateToLatest
                outdatedPackages.append(pkg)
            }
        }

        // 分组 catalog 依赖
        let groupedResult = groupCatalogDependencies(outdatedPackages)

        // 排序: 先按依赖类型, 再按名称
        // 严格翻译自: std.sort.pdq(OutdatedPackage, grouped_result, ...)
        groupedResult.sort { a, b =>
            let aPriority = depTypePriority(a.dependencyType)
            let bPriority = depTypePriority(b.dependencyType)
            if (aPriority != bPriority) {
                return aPriority - bPriority
            }
            return a.name.compareTo(b.name)
        }

        return groupedResult
    }

    /// 依赖类型优先级
    /// 严格翻译自: depTypePriority()
    private static func depTypePriority(depType: String): Int64 {
        if (depType == "dependencies") { return 0 }
        if (depType == "devDependencies") { return 1 }
        if (depType == "peerDependencies") { return 2 }
        if (depType == "optionalDependencies") { return 3 }
        return 4
    }

    /// 计算列宽
    /// 严格翻译自: calculateColumnWidths()
    ///
    /// Bun 原始流程:
    ///   1. 计算自然宽度基于内容
    ///   2. 包含 dev/peer/optional 标签长度
    ///   3. 根据终端宽度应用智能限制
    private static func calculateColumnWidths(packages: ArrayList<OutdatedPackage>): ColumnWidths {
        var maxNameLen: Int64 = "Package".length
        var maxCurrentLen: Int64 = "Current".length
        var maxTargetLen: Int64 = "Target".length
        var maxLatestLen: Int64 = "Latest".length
        var maxWorkspaceLen: Int64 = "Workspace".length
        var hasWorkspaces = false

        for (pkg in packages) {
            // 包含 dev 标签长度
            var devTagLen: Int64 = 0
            if (pkg.behavior.dev) {
                devTagLen = 4  // " dev"
            } else if (pkg.behavior.peer) {
                devTagLen = 5  // " peer"
            } else if (pkg.behavior.optional) {
                devTagLen = 9  // " optional"
            }

            maxNameLen = Math.max(maxNameLen, pkg.name.length + devTagLen)
            maxCurrentLen = Math.max(maxCurrentLen, pkg.currentVersion.length)
            maxTargetLen = Math.max(maxTargetLen, pkg.updateVersion.length)
            maxLatestLen = Math.max(maxLatestLen, pkg.latestVersion.length)
            maxWorkspaceLen = Math.max(maxWorkspaceLen, pkg.workspaceName.length)

            // 检查是否有非空工作区名称
            if (pkg.workspaceName.length > 0) {
                hasWorkspaces = true
            }
        }

        // 获取终端宽度以应用智能限制
        let termSize = getTerminalSize()

        // 根据终端宽度应用智能列宽限制
        if (termSize.width < 60) {
            // 非常窄的终端 - 激进截断, 隐藏工作区
            maxNameLen = Math.min(maxNameLen, 12)
            maxCurrentLen = Math.min(maxCurrentLen, 7)
            maxTargetLen = Math.min(maxTargetLen, 7)
            maxLatestLen = Math.min(maxLatestLen, 7)
            hasWorkspaces = false
        } else if (termSize.width < 80) {
            // 窄终端 - 中等截断, 隐藏工作区
            maxNameLen = Math.min(maxNameLen, 20)
            maxCurrentLen = Math.min(maxCurrentLen, 10)
            maxTargetLen = Math.min(maxTargetLen, 10)
            maxLatestLen = Math.min(maxLatestLen, 10)
            hasWorkspaces = false
        } else if (termSize.width < 120) {
            // 中等终端 - 轻度截断
            maxNameLen = Math.min(maxNameLen, 35)
            maxCurrentLen = Math.min(maxCurrentLen, 15)
            maxTargetLen = Math.min(maxTargetLen, 15)
            maxLatestLen = Math.min(maxLatestLen, 15)
            maxWorkspaceLen = Math.min(maxWorkspaceLen, 15)
            if (termSize.width < 100) {
                hasWorkspaces = false
            }
        } else if (termSize.width < 160) {
            // 宽终端 - 对很长的名称最小截断
            maxNameLen = Math.min(maxNameLen, 45)
            maxCurrentLen = Math.min(maxCurrentLen, 20)
            maxTargetLen = Math.min(maxTargetLen, 20)
            maxLatestLen = Math.min(maxLatestLen, 20)
            maxWorkspaceLen = Math.min(maxWorkspaceLen, 20)
        }
        // 否则: 宽终端 - 使用自然宽度

        let widths = ColumnWidths()
        widths.nameWidth = maxNameLen
        widths.currentWidth = maxCurrentLen
        widths.targetWidth = maxTargetLen
        widths.latestWidth = maxLatestLen
        widths.workspaceWidth = maxWorkspaceLen
        widths.showWorkspace = hasWorkspaces
        return widths
    }

    /// 获取终端尺寸
    /// 严格翻译自: getTerminalSize()
    private static func getTerminalSize(): TerminalSize {
        // 尝试获取终端尺寸
        let size = Terminal.getTerminalSize()
        if (size.isSome()) {
            // 保留空间: 提示 (1行) + 滚动指示器 (2行) + 缓冲区
            let usableHeight = if (size.getOrThrow().height > 6) {
                size.getOrThrow().height - 4
            } else {
                20
            }
            return TerminalSize(usableHeight, size.getOrThrow().width)
        }
        return TerminalSize(20, 80) // 默认回退
    }

    /// 用省略号截断
    /// 严格翻译自: truncateWithEllipsis()
    private static func truncateWithEllipsis(text: String, maxWidth: Int64, onlyEnd: Bool): String {
        if (text.length <= maxWidth) {
            return text
        }

        if (maxWidth <= 3) {
            return "…"
        }

        // 在中间放省略号以显示包名的开始和结束
        let availableChars = maxWidth - 1 // 保留 1 个字符给省略号
        let startChars = if (onlyEnd) {
            availableChars
        } else {
            availableChars / 2
        }
        let endChars = availableChars - startChars

        return text.substring(0, startChars) + "…" + text.substring(text.length - endChars)
    }

    /// 确保光标在视口内
    /// 严格翻译自: ensureCursorInViewport()
    private static func ensureCursorInViewport(state: MultiSelectState): Unit {
        // 如果光标不在视口内, 合理定位
        if (state.cursor < state.viewportStart) {
            // 光标在视口上方 - 放在视口开始处
            state.cursor = state.viewportStart
        } else if (state.cursor >= state.viewportStart + state.viewportHeight) {
            // 光标在视口下方 - 放在视口末尾
            if (state.packages.size > 0) {
                let maxCursor = if (state.packages.size > 1) {
                    state.packages.size - 1
                } else {
                    0
                }
                let viewportEnd = state.viewportStart + state.viewportHeight
                state.cursor = Math.min(viewportEnd - 1, maxCursor)
            }
        }
    }

    /// 更新视口位置
    /// 严格翻译自: updateViewport()
    private static func updateViewport(state: MultiSelectState): Unit {
        // 确保光标可见 (下方2个包, 上方1个包)
        let contextBelow: Int64 = 2
        let contextAbove: Int64 = 1

        // 如果光标在视口下方
        if (state.cursor >= state.viewportStart + state.viewportHeight) {
            // 向下滚动以显示光标和上下文
            let desiredStart: Int64
            if (state.cursor + contextBelow + 1 > state.packages.size) {
                // 不能显示完整上下文, 底部对齐
                if (state.packages.size > state.viewportHeight) {
                    desiredStart = state.packages.size - state.viewportHeight
                } else {
                    desiredStart = 0
                }
            } else {
                // 显示光标和下方上下文
                if (state.viewportHeight > contextBelow && state.cursor > state.viewportHeight - contextBelow) {
                    desiredStart = state.cursor - (state.viewportHeight - contextBelow)
                } else {
                    desiredStart = 0
                }
            }
            state.viewportStart = desiredStart
        }
        // 如果光标在视口上方
        else if (state.cursor < state.viewportStart) {
            // 向上滚动以显示光标和上方上下文
            if (state.cursor >= contextAbove) {
                state.viewportStart = state.cursor - contextAbove
            } else {
                state.viewportStart = 0
            }
        }
        // 如果光标在视口底部附近, 调整以保持上下文
        else if (state.viewportHeight > contextBelow &&
            state.cursor > state.viewportStart + state.viewportHeight - contextBelow) {
            let maxStart = if (state.packages.size > state.viewportHeight) {
                state.packages.size - state.viewportHeight
            } else {
                0
            }
            let desiredStart = if (state.viewportHeight > contextBelow) {
                state.cursor - (state.viewportHeight - contextBelow)
            } else {
                state.cursor
            }
            state.viewportStart = Math.min(desiredStart, maxStart)
        }
        // 如果光标在视口顶部附近, 调整以保持上下文
        else if (state.cursor < state.viewportStart + contextAbove && state.viewportStart > 0) {
            if (state.cursor >= contextAbove) {
                state.viewportStart = state.cursor - contextAbove
            } else {
                state.viewportStart = 0
            }
        }
    }

    /// 提示用户选择更新
    /// 严格翻译自: promptForUpdates()
    private static func promptForUpdates(packages: ArrayList<OutdatedPackage>): Array<Bool> {
        if (packages.size == 0) {
            Output.prettyLn("<r><green>✓<r> All packages are up to date!")
            return []
        }

        let selected = Array<Bool>(packages.size, item: false)

        // 根据终端宽度和内容计算最优列宽
        let columns = calculateColumnWidths(packages)

        // 获取终端尺寸
        let terminalSize = getTerminalSize()

        let state = MultiSelectState()
        state.packages = packages
        state.selected = selected
        state.viewportHeight = terminalSize.height
        state.maxNameLen = columns.nameWidth
        state.maxCurrentLen = columns.currentWidth
        state.maxUpdateLen = columns.targetWidth
        state.maxLatestLen = columns.latestWidth
        state.maxWorkspaceLen = columns.workspaceWidth
        state.showWorkspace = columns.showWorkspace

        // 设置原始模式
        // 严格翻译自: bun.tty.setMode(0, .raw)
        Terminal.setRawMode(true)

        // 处理多选交互
        let result = processMultiSelect(state, terminalSize)

        Terminal.setRawMode(false)
        return result
    }

    /// 处理多选交互
    /// 严格翻译自: processMultiSelect()
    ///
    /// Bun 原始流程:
    ///   1. 渲染 TUI: 标题, 列头, 包列表, 滚动指示器
    ///   2. 读取键盘输入: Space, Enter, j/k, 方向键, a/n/i/l, Page Up/Down, 鼠标滚动
    ///   3. 处理终端尺寸变化
    ///   4. 版本差异着色 (major=红色, minor=黄色, patch=绿色)
    ///   5. 超链接到 npmjs.org
    private static func processMultiSelect(state: MultiSelectState, initialTerminalSize: TerminalSize): Array<Bool> {
        let colors = Output.enableAnsiColorsStdout

        // 清除之前的进度输出
        Output.print("\r[2K")       // 清除整行
        Output.print("[1A[2K") // 上移一行并清除
        Output.flush()

        // 启用鼠标追踪 (如果终端支持)
        if (colors) {
            Output.print("[?25l")    // 隐藏光标
            Output.print("[?1000h")  // 启用基本鼠标追踪
            Output.print("[?1006h")  // 启用 SGR 扩展鼠标模式
        }

        var initialDraw = true
        var reprintMenu = true
        var totalLines: Int64 = 0
        var lastTerminalWidth = initialTerminalSize.width

        while (true) {
            // 检查终端尺寸变化
            let currentSize = getTerminalSize()
            if (currentSize.width != lastTerminalWidth) {
                // 终端尺寸变化, 更新视口并重绘
                state.viewportHeight = currentSize.height
                let columns = calculateColumnWidths(state.packages)
                state.showWorkspace = columns.showWorkspace && currentSize.width > 100
                state.maxNameLen = columns.nameWidth
                state.maxCurrentLen = columns.currentWidth
                state.maxUpdateLen = columns.targetWidth
                state.maxLatestLen = columns.latestWidth
                state.maxWorkspaceLen = columns.workspaceWidth
                lastTerminalWidth = currentSize.width
                updateViewport(state)
                initialDraw = true
            }

            // 渲染主体
            {
                if (!initialDraw) {
                    Output.cursorUp(totalLines)
                    Output.print("[1G")
                    Output.clearToEnd()
                }
                initialDraw = false

                let helpText = "Space to toggle, Enter to confirm, a to select all, n to select none, i to invert, l to toggle latest"
                let elipsisedHelpText = truncateWithEllipsis(helpText, currentSize.width - "? Select packages to update - ".length, true)
                Output.prettyLn("<r><cyan>?<r> Select packages to update<d> - ${elipsisedHelpText}<r>")

                // 计算提示行实际占用行数
                totalLines = 1

                // 计算可用空间
                let needsScrolling = state.packages.size > state.viewportHeight
                let showTopIndicator = needsScrolling && state.viewportStart > 0

                let preliminaryViewportEnd = Math.min(state.viewportStart + state.viewportHeight, state.packages.size)
                let showBottomIndicator = needsScrolling && preliminaryViewportEnd < state.packages.size

                // 显示顶部滚动指示器
                if (showTopIndicator) {
                    let pluralS = if (state.viewportStart == 1) { "" } else { "s" }
                    Output.pretty("  <d>↑ ${state.viewportStart} more package${pluralS} above<r>")
                }

                let viewportEnd = Math.min(state.viewportStart + state.viewportHeight, state.packages.size)

                // 按依赖类型分组
                var currentDepType: ?String = None
                var linesDisplayed: Int64 = 0
                var packagesDisplayed: Int64 = 0

                // 只显示视口内的包
                for (i in state.viewportStart..viewportEnd) {
                    let pkg = state.packages[i.toInt()]
                    let sel = state.selected[i.toInt()]

                    // 检查是否需要标题头
                    let needsHeader = currentDepType.isNone() || currentDepType.getOrThrow() != pkg.dependencyType

                    // 打印依赖类型标题及列头
                    if (needsHeader) {
                        // 计算此依赖类型中选中的包数量
                        var selectedCount: Int64 = 0
                        for (j in 0..state.packages.size) {
                            let p = state.packages[j]
                            if (p.dependencyType == pkg.dependencyType && state.selected[j]) {
                                selectedCount += 1
                            }
                        }

                        // 打印依赖类型 - 如果有选中则加粗
                        Output.print("\n  ")
                        if (selectedCount > 0) {
                            Output.pretty("<r><b>${pkg.dependencyType} ${selectedCount}<r>")
                        } else {
                            Output.pretty("<r>${pkg.dependencyType}<r>")
                        }

                        // 计算填充以对齐列头
                        let totalOffset = 6 + state.maxNameLen + 2
                        let depTypeTextLen = if (selectedCount > 0) {
                            pkg.dependencyType.length + 1 + String.valueOf(selectedCount).length
                        } else {
                            pkg.dependencyType.length
                        }
                        let headerStart = 2 + depTypeTextLen
                        let paddingToCurrent = if (headerStart >= totalOffset) {
                            1
                        } else {
                            totalOffset - headerStart
                        }
                        for (_ in 0..paddingToCurrent) {
                            Output.print(" ")
                        }

                        // 列头对齐
                        Output.print("Current")
                        for (_ in 0..(state.maxCurrentLen - "Current".length + 2)) {
                            Output.print(" ")
                        }
                        Output.print("Target")
                        for (_ in 0..(state.maxUpdateLen - "Target".length + 2)) {
                            Output.print(" ")
                        }
                        Output.print("Latest")
                        if (state.showWorkspace) {
                            for (_ in 0..(state.maxLatestLen - "Latest".length + 2)) {
                                Output.print(" ")
                            }
                            Output.print("Workspace")
                        }
                        Output.print("[0K\n")

                        linesDisplayed += 2
                        currentDepType = pkg.dependencyType
                    }

                    let isCursor = i == state.cursor
                    let checkbox = if (sel) { "■" } else { "□" }

                    // 计算填充 - 包含 dev/peer/optional 标签
                    var devTagLen: Int64 = 0
                    if (pkg.behavior.dev) {
                        devTagLen = 4
                    } else if (pkg.behavior.peer) {
                        devTagLen = 5
                    } else if (pkg.behavior.optional) {
                        devTagLen = 9
                    }
                    let totalNameLen = pkg.name.length + devTagLen
                    let namePadding = if (totalNameLen >= state.maxNameLen) {
                        0
                    } else {
                        state.maxNameLen - totalNameLen
                    }

                    // 确定版本变更严重程度用于 checkbox 颜色
                    // 严格翻译自: whichVersionIsDifferent → checkbox_color
                    let checkboxColor = determineCheckboxColor(pkg)

                    // 光标和 checkbox
                    if (isCursor) {
                        Output.pretty("  <r><cyan>❯<r> ")
                    } else {
                        Output.print("    ")
                    }

                    // checkbox 及适当颜色
                    if (sel) {
                        if (checkboxColor == "red") {
                            Output.pretty("<r><red>${checkbox}<r> ")
                        } else if (checkboxColor == "yellow") {
                            Output.pretty("<r><yellow>${checkbox}<r> ")
                        } else {
                            Output.pretty("<r><green>${checkbox}<r> ")
                        }
                    } else {
                        Output.print("${checkbox} ")
                    }

                    // 包名 - 如果需要则截断, 并设为超链接
                    let availableNameWidth = if (state.maxNameLen > devTagLen) {
                        state.maxNameLen - devTagLen
                    } else {
                        state.maxNameLen
                    }
                    let displayName = truncateWithEllipsis(pkg.name, availableNameWidth, false)

                    // 为默认 registry 构建 npmjs.org 超链接
                    let usesDefaultRegistry = pkg.manager.options.scope.urlHash == NpmRegistry.defaultUrlHash &&
                        pkg.manager.scopeForPackageName(pkg.name).urlHash == NpmRegistry.defaultUrlHash
                    let packageUrl = if (Output.enableAnsiColorsStdout && usesDefaultRegistry) {
                        let versionForUrl = if (sel) {
                            if (pkg.useLatest) { pkg.latestVersion } else { pkg.updateVersion }
                        } else {
                            pkg.currentVersion
                        }
                        "https://npmjs.org/package/${pkg.name}/v/${versionForUrl}"
                    } else {
                        ""
                    }

                    let hyperlink = TerminalHyperlink.new(packageUrl, displayName, packageUrl.length > 0)

                    if (sel) {
                        if (checkboxColor == "red") {
                            Output.pretty("<r><red>${hyperlink.format()}<r>")
                        } else if (checkboxColor == "yellow") {
                            Output.pretty("<r><yellow>${hyperlink.format()}<r>")
                        } else {
                            Output.pretty("<r><green>${hyperlink.format()}<r>")
                        }
                    } else {
                        Output.pretty("<r>${hyperlink.format()}<r>")
                    }

                    // 打印 dev/peer/optional 标签
                    if (pkg.behavior.dev) {
                        Output.pretty("<r><d> dev<r>")
                    } else if (pkg.behavior.peer) {
                        Output.pretty("<r><d> peer<r>")
                    } else if (pkg.behavior.optional) {
                        Output.pretty("<r><d> optional<r>")
                    }

                    // 名称后填充
                    for (_ in 0..(namePadding + 2)) {
                        Output.print(" ")
                    }

                    // 当前版本 - 如果需要则截断
                    let truncatedCurrent = truncateWithEllipsis(pkg.currentVersion, state.maxCurrentLen, false)
                    Output.pretty("<r>${truncatedCurrent}<r>")

                    // 当前版本后填充
                    let currentPadding = if (truncatedCurrent.length >= state.maxCurrentLen) {
                        0
                    } else {
                        state.maxCurrentLen - truncatedCurrent.length
                    }
                    for (_ in 0..(currentPadding + 2)) {
                        Output.print(" ")
                    }

                    // 目标版本, 带 diffFmt 着色 - 如果不使用 latest 则加粗
                    let truncatedTarget = truncateWithEllipsis(pkg.updateVersion, state.maxUpdateLen, false)
                    let targetWidth = truncatedTarget.length

                    // 打印带版本差异着色的目标版本
                    if (sel && !pkg.useLatest) {
                        Output.print("[4m") // 开始下划线
                    }
                    if (truncatedTarget.length < pkg.updateVersion.length) {
                        Output.pretty("<r>${truncatedTarget}<r>")
                    } else {
                        // 使用版本差异着色
                        let diffFmt = VersionDiffFmt.diffFmt(
                            pkg.updateVersion, pkg.currentVersion
                        )
                        Output.pretty("${diffFmt}")
                    }
                    if (sel && !pkg.useLatest) {
                        Output.print("[24m") // 结束下划线
                    }

                    let targetPadding = if (targetWidth >= state.maxUpdateLen) {
                        0
                    } else {
                        state.maxUpdateLen - targetWidth
                    }
                    for (_ in 0..(targetPadding + 2)) {
                        Output.print(" ")
                    }

                    // 最新版本, 带 diffFmt 着色 - 如果使用 latest 则加粗
                    let truncatedLatest = truncateWithEllipsis(pkg.latestVersion, state.maxLatestLen, false)

                    // 如果 latest 与 target 版本相同则变暗
                    let isSameAsTarget = pkg.latestVersion == pkg.updateVersion
                    if (isSameAsTarget) {
                        Output.print("[2m") // 变暗
                    }
                    if (sel && pkg.useLatest) {
                        Output.print("[4m") // 开始下划线
                    }
                    if (truncatedLatest.length < pkg.latestVersion.length) {
                        Output.pretty("<r>${truncatedLatest}<r>")
                    } else {
                        let diffFmt = VersionDiffFmt.diffFmt(
                            pkg.latestVersion, pkg.currentVersion
                        )
                        Output.pretty("${diffFmt}")
                    }
                    if (sel && pkg.useLatest) {
                        Output.print("[24m") // 结束下划线
                    }
                    if (isSameAsTarget) {
                        Output.print("[22m") // 重置变暗
                    }

                    // 工作区列
                    if (state.showWorkspace) {
                        let latestWidth = truncatedLatest.length
                        let latestPadding = if (latestWidth >= state.maxLatestLen) {
                            0
                        } else {
                            state.maxLatestLen - latestWidth
                        }
                        for (_ in 0..(latestPadding + 2)) {
                            Output.print(" ")
                        }
                        let truncatedWorkspace = truncateWithEllipsis(pkg.workspaceName, state.maxWorkspaceLen, true)
                        Output.pretty("<r><d>${truncatedWorkspace}<r>")
                    }

                    Output.print("[0K\n")
                    linesDisplayed += 1
                    packagesDisplayed += 1
                }

                // 显示底部滚动指示器
                if (showBottomIndicator) {
                    let remaining = state.packages.size - viewportEnd
                    let pluralS = if (remaining == 1) { "" } else { "s" }
                    Output.pretty("  <d>↓ ${remaining} more package${pluralS} below<r>")
                    linesDisplayed += 1
                }

                totalLines = linesDisplayed + 1
                Output.clearToEnd()
            }
            Output.flush()

            // 读取输入
            let input = Terminal.readByte()

            match (input) {
                case '\n' | '\r' =>
                    // 确认选择, 恢复终端并返回
                    if (colors) {
                        Output.print("[?25h")    // 显示光标
                        Output.print("[?1000l")  // 禁用鼠标追踪
                        Output.print("[?1006l")  // 禁用 SGR 扩展鼠标模式
                    }

                    // 上移到菜单开始处
                    if (!initialDraw) {
                        Output.cursorUp(totalLines)
                    }
                    Output.clearToEnd()

                    // 计算选中的包数量
                    var count: Int64 = 0
                    for (sel in state.selected) {
                        if (sel) { count += 1 }
                    }
                    Output.prettyLn("<r><green>✓<r> Selected ${count} package${if (count == 1) { "" } else { "s" }} to update")
                    Output.flush()

                    return state.selected
                case 3 | 4 =>
                    // Ctrl+C, Ctrl+D - 取消
                    if (colors) {
                        Output.print("[?25h")
                        Output.print("[?1000l")
                        Output.print("[?1006l")
                    }
                    Output.flush()
                    Output.prettyLn("\n<r><red>x<r> Cancelled")
                    Global.exit(0)
                case ' ' =>
                    // 切换当前包的选择状态
                    let idx = state.cursor.toInt()
                    state.selected[idx] = !state.selected[idx]
                    // 如果包只有 latest 版本, 则切换 latest 版本
                    if (state.packages[idx].currentVersion == state.packages[idx].updateVersion) {
                        state.packages[idx].useLatest = true
                    }
                    state.toggleAll = false
                case 'a' | 'A' =>
                    // 选择所有
                    for (i in 0..state.selected.length) {
                        state.selected[i] = true
                    }
                    // 对于 current == update 版本的包, 自动设置 use_latest
                    for (i in 0..state.packages.size) {
                        if (state.packages[i].currentVersion == state.packages[i].updateVersion) {
                            state.packages[i].useLatest = true
                        }
                    }
                    state.toggleAll = true
                case 'n' | 'N' =>
                    // 取消选择所有
                    for (i in 0..state.selected.length) {
                        state.selected[i] = false
                    }
                    state.toggleAll = false
                case 'i' | 'I' =>
                    // 反选
                    for (i in 0..state.selected.length) {
                        state.selected[i] = !state.selected[i]
                    }
                    state.toggleAll = false
                case 'l' | 'L' =>
                    // 切换 latest 模式
                    if (state.toggleAll) {
                        // 所有包用 'a' 选中, 切换所有选中包的 latest 状态
                        let idx = state.cursor.toInt()
                        let newLatestState = !state.packages[idx].useLatest
                        for (j in 0..state.packages.size) {
                            if (state.selected[j]) {
                                state.packages[j].useLatest = newLatestState
                            }
                        }
                    } else {
                        // 单个选择模式, 切换当前光标处的包并选中
                        let idx = state.cursor.toInt()
                        state.packages[idx].useLatest = !state.packages[idx].useLatest
                        state.selected[idx] = true
                    }
                case 'j' =>
                    // 下移
                    if (state.cursor < state.packages.size - 1) {
                        state.cursor += 1
                    } else {
                        state.cursor = 0
                    }
                    updateViewport(state)
                    state.toggleAll = false
                case 'k' =>
                    // 上移
                    if (state.cursor > 0) {
                        state.cursor -= 1
                    } else {
                        state.cursor = state.packages.size - 1
                    }
                    updateViewport(state)
                    state.toggleAll = false
                case 27 =>
                    // 转义序列
                    let seq = Terminal.readByte()
                    if (seq == '[') {
                        let arrow = Terminal.readByte()
                        match (arrow) {
                            case 'A' =>
                                // 上箭头
                                if (state.cursor > 0) {
                                    state.cursor -= 1
                                } else {
                                    state.cursor = state.packages.size - 1
                                }
                                updateViewport(state)
                            case 'B' =>
                                // 下箭头
                                if (state.cursor < state.packages.size - 1) {
                                    state.cursor += 1
                                } else {
                                    state.cursor = 0
                                }
                                updateViewport(state)
                            case 'C' =>
                                // 右箭头 - 切换到 Latest 版本并选中
                                let idx = state.cursor.toInt()
                                state.packages[idx].useLatest = true
                                state.selected[idx] = true
                            case 'D' =>
                                // 左箭头 - 切换到 Target 版本并选中
                                let idx = state.cursor.toInt()
                                state.packages[idx].useLatest = false
                                state.selected[idx] = true
                            case '5' =>
                                // Page Up
                                let tilde = Terminal.readByte()
                                if (tilde == '~') {
                                    if (state.cursor >= state.viewportHeight) {
                                        state.cursor -= state.viewportHeight
                                    } else {
                                        state.cursor = 0
                                    }
                                    updateViewport(state)
                                }
                            case '6' =>
                                // Page Down
                                let tilde = Terminal.readByte()
                                if (tilde == '~') {
                                    if (state.cursor + state.viewportHeight < state.packages.size) {
                                        state.cursor += state.viewportHeight
                                    } else {
                                        state.cursor = state.packages.size - 1
                                    }
                                    updateViewport(state)
                                }
                            case '<' =>
                                // SGR 扩展鼠标模式
                                // 读取直到 'M' 或 'm' 表示按钮按下/释放
                                var buffer = ""
                                var bufLen = 0
                                while (bufLen < 32) {
                                    let c = Terminal.readByte()
                                    if (c == 'M' || c == 'm') {
                                        // 解析 SGR 鼠标事件: ESC[<button;col;row(M or m)
                                        // button: 64 = 向上滚动, 65 = 向下滚动
                                        let parts = buffer.split(";")
                                        if (parts.length > 0) {
                                            let button = Int64.parse(parts[0]) ?? 0
                                            // 鼠标滚轮事件
                                            if (button == 64) {
                                                // 向上滚动
                                                if (state.viewportStart > 0) {
                                                    let scrollAmount = Math.min(1, state.viewportStart)
                                                    state.viewportStart -= scrollAmount
                                                    ensureCursorInViewport(state)
                                                }
                                            } else if (button == 65) {
                                                // 向下滚动
                                                if (state.viewportStart + state.viewportHeight < state.packages.size) {
                                                    let maxScroll = state.packages.size - (state.viewportStart + state.viewportHeight)
                                                    let scrollAmount = Math.min(1, maxScroll)
                                                    state.viewportStart += scrollAmount
                                                    ensureCursorInViewport(state)
                                                }
                                            }
                                        }
                                        break
                                    }
                                    buffer += String.fromChar(c)
                                    bufLen += 1
                                }
                            case _ => ()
                        }
                    }
                    state.toggleAll = false
                case _ =>
                    state.toggleAll = false
            }
        }
    }

    /// 确定 checkbox 颜色基于版本差异
    /// 严格翻译自: processMultiSelect → checkbox_color 逻辑
    ///
    /// major 变更 = 红色
    /// minor 变更 (非 0.x) = 黄色, 0.x.y minor = 红色 (破坏性)
    /// patch 变更 (非 0.0.x) = 绿色, 0.0.x patch = 红色 (破坏性)
    private static func determineCheckboxColor(pkg: OutdatedPackage): String {
        let currentVerParsed = SemverVersion.parse(pkg.currentVersion)
        let updateVerStr = if (pkg.useLatest) {
            pkg.latestVersion
        } else {
            pkg.updateVersion
        }
        let updateVerParsed = SemverVersion.parse(updateVerStr)

        if (currentVerParsed.valid && updateVerParsed.valid) {
            let currentMajor = currentVerParsed.major ?? 0
            let currentMinor = currentVerParsed.minor ?? 0

            let diff = whichVersionIsDifferent(currentVerParsed, updateVerParsed)
            match (diff) {
                case VersionDiffType.major => return "red"
                case VersionDiffType.minor =>
                    if (currentMajor == 0) {
                        return "red" // 0.x.y minor 变更是破坏性的
                    }
                    return "yellow"
                case VersionDiffType.patch =>
                    if (currentMajor == 0 && currentMinor == 0) {
                        return "red" // 0.0.x patch 变更是破坏性的
                    }
                    return "green"
                case VersionDiffType.other => return "green"
            }
        }
        return "green"
    }

    /// 确定版本差异类型
    /// 严格翻译自: whichVersionIsDifferent()
    private static func whichVersionIsDifferent(current: SemverParsedVersion, update: SemverParsedVersion): VersionDiffType {
        let currentMajor = current.major ?? 0
        let currentMinor = current.minor ?? 0
        let currentPatch = current.patch ?? 0
        let updateMajor = update.major ?? 0
        let updateMinor = update.minor ?? 0
        let updatePatch = update.patch ?? 0

        if (updateMajor != currentMajor) { return VersionDiffType.major }
        if (updateMinor != currentMinor) { return VersionDiffType.minor }
        if (updatePatch != currentPatch) { return VersionDiffType.patch }
        return VersionDiffType.other
    }

    /// 字符串填充到指定长度
    private static func padEnd(s: String, width: Int64): String {
        if (s.length >= width) {
            return s
        }
        var result = s
        var i = s.length
        while (i < width) {
            result += " "
            i += 1
        }
        return result
    }
}

// ============================================================================
// VersionDiffFmt — 版本差异格式化工具
// 严格翻译自: Semver.Version.diffFmt()
// ============================================================================

/// 版本差异格式化
public class VersionDiffFmt {
    /// 格式化版本差异 (用颜色标记 major/minor/patch 差异)
    public static func diffFmt(targetVersion: String, currentVersion: String): String {
        let targetParsed = SemverVersion.parse(targetVersion)
        let currentParsed = SemverVersion.parse(currentVersion)

        if (!targetParsed.valid || !currentParsed.valid) {
            return targetVersion
        }

        let targetMajor = targetParsed.major ?? 0
        let targetMinor = targetParsed.minor ?? 0
        let targetPatch = targetParsed.patch ?? 0
        let currentMajor = currentParsed.major ?? 0
        let currentMinor = currentParsed.minor ?? 0
        let currentPatch = currentParsed.patch ?? 0

        var result = ""

        // major
        if (targetMajor != currentMajor) {
            result += "[31m${targetMajor}[0m" // 红色
        } else {
            result += "${targetMajor}"
        }
        result += "."

        // minor
        if (targetMinor != currentMinor) {
            result += "[33m${targetMinor}[0m" // 黄色
        } else {
            result += "${targetMinor}"
        }
        result += "."

        // patch
        if (targetPatch != currentPatch) {
            result += "[32m${targetPatch}[0m" // 绿色
        } else {
            result += "${targetPatch}"
        }

        // tag 部分 (pre-release)
        if (targetParsed.tag.isSome() && targetParsed.tag.getOrThrow().length > 0) {
            result += "-${targetParsed.tag.getOrThrow()}"
        }

        return result
    }
}
