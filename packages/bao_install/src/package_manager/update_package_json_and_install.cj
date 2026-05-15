// bao_install - 更新 package.json 并安装
// 严格翻译自: src/install/PackageManager/updatePackageJSONAndInstall.zig
//   updatePackageJSONAndInstall: 入口函数
//   updatePackageJSONAndInstallWithManager: 带管理器的安装
//   updatePackageJSONAndInstallCatchError: 错误处理
//   getWorkspaceFilters: 获取工作区过滤器
//   printInstallSummary: 打印安装摘要
//   printBlockedPackagesInfo: 打印被阻塞的包信息
package bao_install.package_manager

import bao_core.*
import bao_collections.*

// ============================================================================
// 更新 package.json 并安装
// 严格翻译自: src/install/PackageManager/updatePackageJSONAndInstall.zig
//   ~762 行的模块, 负责从编辑 package.json 到完成安装的整个流程
// ============================================================================

/// 更新 package.json 并安装
/// 对应 Bun: updatePackageJSONAndInstall 中的函数
/// 翻译自: src/install/PackageManager/updatePackageJSONAndInstall.zig
public class UpdatePackageJSONAndInstall {

    /// 入口函数
    /// 翻译自: updatePackageJSONAndInstall
    ///   pub fn updatePackageJSONAndInstall(ctx, comptime cli, log_level) !void
    ///   创建包管理器, 加载配置, 执行安装
    public static func updatePackageJSONAndInstall(
        ctx: CommandContext,
        logLevel: LogLevel
    ): Unit {
        try {
            let manager = createPackageManager(ctx: ctx, logLevel: logLevel)

            // 加载 package.json
            let rootPackageJsonPath = Path.join(ctx.cwd, "package.json")
            let originalCwd = ctx.cwd

            updatePackageJSONAndInstallWithManager(
                manager: manager,
                ctx: ctx,
                rootPackageJsonPath: rootPackageJsonPath,
                originalCwd: originalCwd
            )
        } catch (err: Exception) {
            updatePackageJSONAndInstallCatchError(err: err, logLevel: logLevel)
        }
    }

    /// 带管理器的安装
    /// 翻译自: updatePackageJSONAndInstallWithManager (简化版)
    ///   pub fn installWithManager(manager, ctx, root_package_json_path, original_cwd) !void
    ///   完整安装流程:
    ///   1. 加载/解析锁文件
    ///   2. 解析差异
    ///   3. 下载/解压包
    ///   4. 安装包 (hoisted/isolated)
    ///   5. 运行脚本
    ///   6. 保存锁文件
    public static func updatePackageJSONAndInstallWithManager(
        manager: PackageManagerState,
        ctx: CommandContext,
        rootPackageJsonPath: String,
        originalCwd: String
    ): Unit {
        let logLevel = manager.options.logLevel

        // 1. 加载锁文件
        var loadResult = LoadResult.NotFound
        if (manager.options.doLoadLockfile) {
            loadResult = manager.lockfile.loadFromCwd()
        }

        // 2. 解析差异
        var hadAnyDiffs = false
        var needsNewLockfile = loadResult.isNotFound() ||
            (loadResult.isOk() && manager.lockfile.dependenciesCount() == 0 && manager.updateRequests.size > 0)

        match (loadResult) {
            case LoadResult.Ok(_) => {
                // 比较现有锁文件与新 package.json
                let diff = manager.generateDiff()
                hadAnyDiffs = diff.hasDiffs()
            }
            case LoadResult.Err(cause) => {
                if (logLevel != LogLevel.Silent) {
                    bao_core.Output.error("Failed to load lockfile: ${cause.message}")
                }
            }
            case _ => {}
        }

        // 3. 创建新锁文件 (如果需要)
        if (needsNewLockfile) {
            manager.lockfile.initEmpty()
            let root = manager.parseRootPackage(rootPackageJsonPath)
            manager.lockfile.appendPackage(root)
            manager.enqueueDependencyList(root.dependencies)
        }

        // 4. 下载/解压/安装
        if (manager.pendingTaskCount() > 0) {
            if (logLevel.showProgress()) {
                manager.startProgressBar()
            } else if (logLevel != LogLevel.Silent) {
                bao_core.Output.print("Resolving dependencies\n")
            }

            // 等待所有任务完成
            manager.runAndWaitForTasks()

            if (logLevel.showProgress()) {
                manager.endProgressBar()
            }
        }

        // 5. 清理锁文件
        manager.cleanLockfile()

        // 6. 安全扫描
        match (manager.securityScanner) {
            case Some(scanner) => {
                let results = scanner.performSecurityScan(manager: manager)
                match (results) {
                    case Some(scanResults) => {
                        SecurityScanner.printSecurityAdvisories(results: scanResults)
                        if (scanResults.hasFatalAdvisories()) {
                            bao_core.Output.error("Installation aborted due to fatal security advisories")
                            return
                        } else if (scanResults.hasWarnings()) {
                            if (!SecurityScanner.promptForWarnings()) {
                                return
                            }
                        }
                    }
                    case None => {}
                }
            }
            case None => {}
        }

        // 7. 安装包
        if (manager.options.doInstallPackages) {
            let installSummary = match (manager.options.nodeLinker) {
                case NodeLinker.Hoisted => manager.installHoistedPackages()
                case NodeLinker.Isolated => manager.installIsolatedPackages()
                case NodeLinker.Auto => manager.installAutoPackages()
            }

            // 8. 保存锁文件
            if (shouldSaveLockfile(
                loadResult: loadResult,
                manager: manager,
                hadAnyDiffs: hadAnyDiffs
            )) {
                manager.saveLockfile()
            }

            // 9. 运行脚本
            if (manager.options.doRunScripts) {
                manager.runLifecycleScripts()
            }

            // 10. 打印摘要
            if (logLevel != LogLevel.Silent) {
                printInstallSummary(
                    manager: manager,
                    ctx: ctx,
                    summary: installSummary,
                    hadAnyDiffs: hadAnyDiffs
                )
            }
        }
    }

    /// 错误处理
    /// 翻译自: updatePackageJSONAndInstallCatchError
    private static func updatePackageJSONAndInstallCatchError(
        err: Exception,
        logLevel: LogLevel
    ): Unit {
        if (logLevel != LogLevel.Silent) {
            bao_core.Output.error("Install failed: ${err.message}")
        }
    }

    /// 获取工作区过滤器
    /// 翻译自: getWorkspaceFilters
    ///   pub fn getWorkspaceFilters(manager, original_cwd) !struct { []const WorkspaceFilter, bool }
    public static func getWorkspaceFilters(
        manager: PackageManagerState,
        originalCwd: String
    ): WorkspaceFilterResult {
        var workspaceFilters = ArrayList<WorkspaceFilter>()

        // 只在 install 子命令时处理过滤器
        if (manager.subcommand == PackageSubcommand.Install && manager.options.filterPatterns.size > 0) {
            for (pattern in manager.options.filterPatterns) {
                workspaceFilters.append(WorkspaceFilter(pattern: pattern))
            }
        }

        var installRootDependencies = workspaceFilters.size == 0

        return WorkspaceFilterResult(
            filters: workspaceFilters,
            installRootDependencies: installRootDependencies
        )
    }

    /// 打印安装摘要
    /// 严格翻译自: printInstallSummary
    ///   fn printInstallSummary(this, ctx, install_summary, did_meta_hash_change, log_level) !void
    public static func printInstallSummary(
        manager: PackageManagerState,
        ctx: CommandContext,
        summary: PackageInstallSummary,
        hadAnyDiffs: Bool
    ): Unit {
        if (!manager.options.doSummary) { return }

        if (summary.success > 0) {
            let pkgsInstalled = max(summary.success, manager.updateRequests.size)
            bao_core.Output.print("${pkgsInstalled} packages installed\n")
            printBlockedPackagesInfo(summary: summary, global: manager.options.global)
        } else if (manager.summary.remove > 0) {
            bao_core.Output.print("${manager.summary.remove} packages removed\n")
            printBlockedPackagesInfo(summary: summary, global: manager.options.global)
        } else if (summary.skipped > 0 && summary.fail == 0 && manager.updateRequests.size == 0) {
            let count = manager.lockfile.packagesCount()
            if (count != summary.skipped) {
                bao_core.Output.print("Checked ${summary.skipped} installs across ${count} packages (no changes)\n")
            }
        }

        if (summary.fail > 0) {
            bao_core.Output.error("Failed to install ${summary.fail} packages\n")
        }
    }

    /// 打印被阻塞的包信息
    /// 翻译自: printBlockedPackagesInfo
    ///   fn printBlockedPackagesInfo(summary, global) void
    public static func printBlockedPackagesInfo(
        summary: PackageInstallSummary,
        global: Bool
    ): Unit {
        let packagesCount = summary.packagesWithBlockedScripts.size
        var scriptsCount: Int64 = 0
        for (entry in summary.packagesWithBlockedScripts) {
            scriptsCount += entry.value
        }

        if (packagesCount > 0) {
            let globalStr = if (global) { "-g " } else { "" }
            bao_core.Output.print(
                "\nBlocked ${scriptsCount} postinstall${if (scriptsCount > 1) { "s" } else { "" }}. Run `bun pm ${globalStr}untrusted` for details.\n"
            )
        }
    }

    /// 是否应保存锁文件
    private static func shouldSaveLockfile(
        loadResult: LoadResult,
        manager: PackageManagerState,
        hadAnyDiffs: Bool
    ): Bool {
        return manager.options.doSaveLockfile &&
            (hadAnyDiffs ||
                manager.updateRequests.size > 0 ||
                manager.lockfile.isEmpty() ||
                manager.options.forceSaveLockfile)
    }

    /// 创建包管理器
    private static func createPackageManager(ctx: CommandContext, logLevel: LogLevel): PackageManagerState {
        let manager = PackageManagerState()
        manager.options.logLevel = logLevel
        return manager
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 加载结果
public enum LoadResult {
    | Ok(LoadResultOk)
    | Err(LoadResultErr)
    | NotFound

    public func isNotFound(): Bool { return this == LoadResult.NotFound }
    public func isOk(): Bool {
        match (this) {
            case Ok(_) => return true
            case _ => return false
        }
    }
}

/// 加载结果 (成功)
public class LoadResultOk {
    public var lockfile: LockfileRef
    public var migrated: MigrationKind
    public var format: LockfileFormat

    public init() {
        lockfile = LockfileRef()
        migrated = MigrationKind.None
        format = LockfileFormat.Binary
    }
}

/// 加载结果 (错误)
public class LoadResultErr {
    public var step: LoadStep
    public var message: String

    public init(step: LoadStep, message: String) {
        this.step = step
        this.message = message
    }
}

/// 加载步骤
public enum LoadStep {
    | OpenFile
    | ReadFile
    | ParseFile
    | Migrating
}

/// 迁移类型
public enum MigrationKind {
    | None
    | Npm
    | Binary
}

/// 锁文件格式
public enum LockfileFormat {
    | Binary
    | Text
}

/// 工作区过滤结果
public class WorkspaceFilterResult {
    public var filters: ArrayList<WorkspaceFilter>
    public var installRootDependencies: Bool

    public init(filters: ArrayList<WorkspaceFilter>, installRootDependencies: Bool) {
        this.filters = filters
        this.installRootDependencies = installRootDependencies
    }
}

/// 工作区过滤器
public class WorkspaceFilter {
    public var pattern: String

    public init(pattern: String) {
        this.pattern = pattern
    }
}

/// 包安装摘要
public class PackageInstallSummary {
    public var success: Int64
    public var fail: Int64
    public var skipped: Int64
    public var packagesWithBlockedScripts: HashMap<String, Int64>

    public init() {
        success = 0
        fail = 0
        skipped = 0
        packagesWithBlockedScripts = HashMap<String, Int64>()
    }
}

/// 安装差异摘要
public class InstallDiffSummary {
    public var add: Int64
    public var remove: Int64
    public var update: Int64

    public init() {
        add = 0
        remove = 0
        update = 0
    }

    public func hasDiffs(): Bool {
        return add > 0 || remove > 0 || update > 0
    }
}

/// 节点链接器
public enum NodeLinker {
    | Auto
    | Hoisted
    | Isolated
}

/// 包子命令
public enum PackageSubcommand {
    | Install
    | Add
    | Remove
    | Update
    | Link
    | Unlink
}

/// 包管理器状态
public class PackageManagerState {
    public var options: PackageManagerOptions
    public var lockfile: LockfileRef
    public var updateRequests: ArrayList<UpdateRequest>
    public var summary: InstallDiffSummary
    public var securityScanner: ?SecurityScannerRef
    public var subcommand: PackageSubcommand

    public init() {
        options = PackageManagerOptions()
        lockfile = LockfileRef()
        updateRequests = ArrayList<UpdateRequest>()
        summary = InstallDiffSummary()
        securityScanner = None
        subcommand = PackageSubcommand.Install
    }

    public func pendingTaskCount(): Int64 { return 0 }
    public func startProgressBar(): Unit {}
    public func endProgressBar(): Unit {}
    public func runAndWaitForTasks(): Unit {}
    public func cleanLockfile(): Unit {}
    public func enqueueDependencyList(deps: ArrayList<UInt32>): Unit {}
    public func parseRootPackage(path: String): PackageData { return PackageData() }
    public func generateDiff(): InstallDiffSummary { return InstallDiffSummary() }
    public func saveLockfile(): Unit {}
    public func runLifecycleScripts(): Unit {}
    public func installHoistedPackages(): PackageInstallSummary { return PackageInstallSummary() }
    public func installIsolatedPackages(): PackageInstallSummary { return PackageInstallSummary() }
    public func installAutoPackages(): PackageInstallSummary { return PackageInstallSummary() }
}

/// 包管理器选项
public class PackageManagerOptions {
    public var logLevel: LogLevel
    public var doLoadLockfile: Bool
    public var doSaveLockfile: Bool
    public var doInstallPackages: Bool
    public var doRunScripts: Bool
    public var doSummary: Bool
    public var forceSaveLockfile: Bool
    public var global: Bool
    public var nodeLinker: NodeLinker
    public var filterPatterns: ArrayList<String>

    public init() {
        logLevel = LogLevel.Default
        doLoadLockfile = true
        doSaveLockfile = true
        doInstallPackages = true
        doRunScripts = true
        doSummary = true
        forceSaveLockfile = false
        global = false
        nodeLinker = NodeLinker.Auto
        filterPatterns = ArrayList<String>()
    }
}

/// 锁文件引用
public class LockfileRef {
    public init() {}
    public func loadFromCwd(): LoadResult { return LoadResult.NotFound }
    public func initEmpty(): Unit {}
    public func appendPackage(pkg: PackageData): Unit {}
    public func dependenciesCount(): Int64 { return 0 }
    public func packagesCount(): Int64 { return 0 }
    public func isEmpty(): Bool { return true }
}

/// 包数据
public class PackageData {
    public var dependencies: ArrayList<UInt32>

    public init() {
        dependencies = ArrayList<UInt32>()
    }
}

/// 安全扫描器引用
public class SecurityScannerRef {
    public func performSecurityScan(manager: PackageManagerState): ?SecurityScanResults { return None }
}

/// 安全扫描结果
public class SecurityScanResults {
    public func hasFatalAdvisories(): Bool { return false }
    public func hasWarnings(): Bool { return false }
}

/// 安全扫描器
public class SecurityScanner {
    public static func printSecurityAdvisories(results: SecurityScanResults): Unit {}
    public static func promptForWarnings(): Bool { return false }
}

/// 命令上下文
public class CommandContext {
    public var cwd: String

    public init() {
        cwd = bao_io.File.getCurrentDirectory()
    }
}

/// 更新请求
public class UpdateRequest {
    public var name: String
    public var failed: Bool

    public init() {
        name = ""
        failed = false
    }
}
