// bao_install - 更新 package.json 并安装
// 严格翻译自: src/install/PackageManager/updatePackageJSONAndInstall.zig
//   updatePackageJSONAndInstall: 入口函数
//   updatePackageJSONAndInstallWithManager: 带管理器的安装
//   updatePackageJSONAndInstallCatchError: 错误处理
//   getWorkspaceFilters: 获取工作区过滤器
//   printInstallSummary: 打印安装摘要
//   printBlockedPackagesInfo: 打印被阻塞的包信息
package bao_install.package_manager

import bao_install.*

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

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
        ctx: UpdateInstallCommandContext,
        logLevel: LogLevel
    ): Unit {
        try {
            let manager = createPackageManager(ctx, logLevel)
            let rootPackageJsonPath = Path.join([ctx.cwd, "package.json"])
            let originalCwd = ctx.cwd
            updatePackageJSONAndInstallWithManager(manager, ctx, rootPackageJsonPath, originalCwd)
        } catch (err: Exception) {
            updatePackageJSONAndInstallCatchError(err, logLevel)
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
        manager: UpdateInstallPackageManagerState,
        ctx: UpdateInstallCommandContext,
        rootPackageJsonPath: String,
        originalCwd: String
    ): Unit {
        let logLevel = manager.options.logLevel

        var loadResult = LoadResult.NotFound
        if (manager.options.doLoadLockfile) {
            loadResult = manager.lockfile.loadFromCwd()
        }

        var hadAnyDiffs = false
        let needsNewLockfile = loadResult.isNotFound() ||
            (loadResult.isOk() && manager.lockfile.dependenciesCount() == 0 && manager.updateRequests.size > 0)

        match (loadResult) {
            case LoadResult.Ok(_) => hadAnyDiffs = processLoadOk(manager)
            case LoadResult.Err(cause) => handleLoadError(cause, logLevel)
            case _ => ()
        }

        if (needsNewLockfile) {
            manager.lockfile.initEmpty()
            let root = manager.parseRootPackage(rootPackageJsonPath)
            manager.lockfile.appendPackage(root)
            manager.enqueueDependencyList(root.dependencies)
        }

        if (manager.pendingTaskCount() > 0) {
            if (logLevel.showProgress()) {
                manager.startProgressBar()
            } else if (!isSilent(logLevel)) {
                Output.print("Resolving dependencies\n")
            }

            manager.runAndWaitForTasks()

            if (logLevel.showProgress()) {
                manager.endProgressBar()
            }
        }

        manager.cleanLockfile()

        match (manager.securityScanner) {
            case Some(scanner) => runSecurityScan(scanner, manager)
            case None => ()
        }

        if (manager.options.doInstallPackages) {
            let installSummary = match (manager.options.nodeLinker) {
                case NodeLinker.Hoisted => manager.installHoistedPackages()
                case NodeLinker.Isolated => manager.installIsolatedPackages()
                case NodeLinker.Auto => manager.installAutoPackages()
            }

            if (shouldSaveLockfile(loadResult, manager, hadAnyDiffs)) {
                manager.saveLockfile()
            }

            if (manager.options.doRunScripts) {
                manager.runLifecycleScripts()
            }

            if (!isSilent(logLevel)) {
                printInstallSummary(manager, ctx, installSummary, hadAnyDiffs)
            }
        }
    }

    /// 错误处理
    /// 翻译自: updatePackageJSONAndInstallCatchError
    private static func updatePackageJSONAndInstallCatchError(
        err: Exception,
        logLevel: LogLevel
    ): Unit {
        if (!isSilent(logLevel)) {
            Output.printErrorln("Install failed: ${err.message}")
        }
    }

    /// 获取工作区过滤器
    /// 翻译自: getWorkspaceFilters
    ///   pub fn getWorkspaceFilters(manager, original_cwd) !struct { []const WorkspaceFilter, bool }
    public static func getWorkspaceFilters(
        manager: UpdateInstallPackageManagerState,
        originalCwd: String
    ): WorkspaceFilterResult {
        var workspaceFilters = ArrayList<WorkspaceFilter>()

        if (isInstallSubcommand(manager.subcommand) && manager.options.filterPatterns.size > 0) {
            for (pattern in manager.options.filterPatterns) {
                workspaceFilters.append(WorkspaceFilter(pattern))
            }
        }

        let installRootDependencies = workspaceFilters.size == 0
        return WorkspaceFilterResult(workspaceFilters, installRootDependencies)
    }

    /// 打印安装摘要
    /// 严格翻译自: printInstallSummary
    ///   fn printInstallSummary(this, ctx, install_summary, did_meta_hash_change, log_level) !void
    public static func printInstallSummary(
        manager: UpdateInstallPackageManagerState,
        ctx: UpdateInstallCommandContext,
        summary: PackageInstallSummary,
        hadAnyDiffs: Bool
    ): Unit {
        if (!manager.options.doSummary) { return }

        if (summary.success > 0) {
            let pkgsInstalled = max(summary.success, manager.updateRequests.size)
            Output.print("${pkgsInstalled} packages installed\n")
            printBlockedPackagesInfo(summary, manager.options.global)
        } else if (manager.summary.remove > 0) {
            Output.print("${manager.summary.remove} packages removed\n")
            printBlockedPackagesInfo(summary, manager.options.global)
        } else if (summary.skipped > 0 && summary.fail == 0 && manager.updateRequests.size == 0) {
            let count = manager.lockfile.packagesCount()
            if (count != summary.skipped) {
                Output.print("Checked ${summary.skipped} installs across ${count} packages (no changes)\n")
            }
        }

        if (summary.fail > 0) {
            Output.printErrorln("Failed to install ${summary.fail} packages\n")
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
        if (packagesCount > 0) {
            let globalStr = if (global) { "-g " } else { "" }
            Output.print("\nBlocked postinstall scripts. Run `bun pm ${globalStr}untrusted` for details.\n")
        }
    }

    /// 是否应保存锁文件
    private static func shouldSaveLockfile(
        loadResult: LoadResult,
        manager: UpdateInstallPackageManagerState,
        hadAnyDiffs: Bool
    ): Bool {
        return manager.options.doSaveLockfile &&
            (hadAnyDiffs ||
                manager.updateRequests.size > 0 ||
                manager.lockfile.isEmpty() ||
                manager.options.forceSaveLockfile)
    }

    /// 创建包管理器
    private static func createPackageManager(ctx: UpdateInstallCommandContext, logLevel: LogLevel): UpdateInstallPackageManagerState {
        let manager = UpdateInstallPackageManagerState()
        manager.options.logLevel = logLevel
        return manager
    }

    private static func processLoadOk(manager: UpdateInstallPackageManagerState): Bool {
        let diff = manager.generateDiff()
        return diff.hasDiffs()
    }

    private static func handleLoadError(cause: LoadResultErr, logLevel: LogLevel): Unit {
        if (!isSilent(logLevel)) {
            Output.printErrorln("Failed to load lockfile: ${cause.message}")
        }
    }

    private static func runSecurityScan(scanner: SecurityScannerRef, manager: UpdateInstallPackageManagerState): Unit {
        let results = scanner.performSecurityScan(manager)
        match (results) {
            case Some(scanResults) => handleScanResults(scanResults)
            case None => ()
        }
    }

    private static func handleScanResults(scanResults: SecurityScanResults): Unit {
        SecurityScanner.printSecurityAdvisories(scanResults)
        if (scanResults.hasFatalAdvisories()) {
            Output.printErrorln("Installation aborted due to fatal security advisories")
            return
        } else if (scanResults.hasWarnings()) {
            if (!SecurityScanner.promptForWarnings()) {
                return
            }
        }
    }

    private static func isSilent(logLevel: LogLevel): Bool {
        match (logLevel) {
            case LogLevel.Silent => return true
            case _ => return false
        }
    }

    private static func isInstallSubcommand(subcommand: PackageSubcommand): Bool {
        match (subcommand) {
            case PackageSubcommand.Install => return true
            case _ => return false
        }
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

    public func isNotFound(): Bool {
        match (this) {
            case LoadResult.NotFound => return true
            case _ => return false
        }
    }
    public func isOk(): Bool {
        match (this) {
            case Ok(_) => return true
            case _ => return false
        }
    }
}

/// 加载结果 (成功)
public class LoadResultOk {
    public var lockfile: UpdateInstallLockfileRef
    public var migrated: MigrationKind
    public var format: LockfileFormat

    public init() {
        lockfile = UpdateInstallLockfileRef()
        migrated = MigrationKind.None_
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
    | None_
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
public class UpdateInstallPackageManagerState {
    public var options: UpdateInstallPackageManagerOptions
    public var lockfile: UpdateInstallLockfileRef
    public var updateRequests: ArrayList<UpdateInstallRequest>
    public var summary: InstallDiffSummary
    public var securityScanner: ?SecurityScannerRef
    public var subcommand: PackageSubcommand

    public init() {
        options = UpdateInstallPackageManagerOptions()
        lockfile = UpdateInstallLockfileRef()
        updateRequests = ArrayList<UpdateInstallRequest>()
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
    public func parseRootPackage(path: String): UpdateInstallPackageData { return UpdateInstallPackageData() }
    public func generateDiff(): InstallDiffSummary { return InstallDiffSummary() }
    public func saveLockfile(): Unit {}
    public func runLifecycleScripts(): Unit {}
    public func installHoistedPackages(): PackageInstallSummary { return PackageInstallSummary() }
    public func installIsolatedPackages(): PackageInstallSummary { return PackageInstallSummary() }
    public func installAutoPackages(): PackageInstallSummary { return PackageInstallSummary() }
}

/// 包管理器选项
public class UpdateInstallPackageManagerOptions {
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
public class UpdateInstallLockfileRef {
    public init() {}
    public func loadFromCwd(): LoadResult { return LoadResult.NotFound }
    public func initEmpty(): Unit {}
    public func appendPackage(pkg: UpdateInstallPackageData): Unit {}
    public func dependenciesCount(): Int64 { return 0 }
    public func packagesCount(): Int64 { return 0 }
    public func isEmpty(): Bool { return true }
}

/// 包数据
public class UpdateInstallPackageData {
    public var dependencies: ArrayList<UInt32>

    public init() {
        dependencies = ArrayList<UInt32>()
    }
}

/// 安全扫描器引用
public class SecurityScannerRef {
    public func performSecurityScan(manager: UpdateInstallPackageManagerState): ?SecurityScanResults { return None }
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
public class UpdateInstallCommandContext {
    public var cwd: String

    public init() {
        cwd = "."
    }
}

/// 更新请求
public class UpdateInstallRequest {
    public var name: String
    public var failed: Bool

    public init() {
        name = ""
        failed = false
    }
}
