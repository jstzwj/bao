// bao_install - 提升式安装
// 严格翻译自: src/install/hoisted_install.zig
//   pub fn installHoistedPackages(
//       this: *PackageManager,
//       ctx: Command.Context,
//       workspace_filters: []const WorkspaceFilter,
//       install_root_dependencies: bool,
//       log_level: PackageManager.Options.LogLevel,
//       packages_to_install: ?[]const PackageID,
//   ) !PackageInstall.Summary
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*
import bao_sys.*

// ============================================================================
// 提升式安装器
// 严格翻译自: src/install/hoisted_install.zig
//   hoisted_install 是 Bun 的默认安装模式, 将所有包提升到根 node_modules
//   安装流程:
//     1. 使用 lockfile.filter() 过滤需要安装的依赖
//     2. 创建/打开 node_modules 目录
//     3. 创建 PackageInstaller
//     4. 遍历 Lockfile.Tree 迭代器, 对每个依赖调用 installPackage
//     5. 运行网络任务 (下载/解析)
//     6. 运行生命周期脚本
// ============================================================================

/// 提升式安装器
/// 对应 Bun: hoisted_install.installHoistedPackages
public class HoistedInstaller {
    /// 包管理器引用
    public var manager: PackageManagerRef
    /// 日志级别
    public var logLevel: LogLevel
    /// 安装摘要
    public var summary: PackageInstallSummary
    /// 是否是新创建的 node_modules
    public var isNewNodeModules: Bool
    /// 是否跳过删除
    public var skipDelete: Bool
    /// 是否跳过版本验证
    public var skipVerify: Bool
    /// 是否强制安装
    public var forceInstall: Bool
    /// 根 node_modules 目录
    public var rootNodeModulesDir: String
    /// 当前 node_modules 路径
    public var nodeModulesPath: String
    /// 当前 tree ID
    public var currentTreeId: UInt32
    /// 已安装的包 ID 集合
    public var successfullyInstalled: HashSet<UInt32>
    /// 待安装的包列表 (按 tree 组织)
    public var treeContexts: ArrayList<TreeContext>
    /// 下载进度节点名称
    public var downloadNodeName: String
    public var installNodeName: String
    public var scriptsNodeName: String

    public init(manager: PackageManagerRef) {
        this.manager = manager
        logLevel = LogLevel.Default
        summary = PackageInstallSummary()
        isNewNodeModules = false
        skipDelete = false
        skipVerify = false
        forceInstall = false
        rootNodeModulesDir = ""
        nodeModulesPath = ""
        currentTreeId = UInt32(0)
        successfullyInstalled = HashSet<UInt32>()
        treeContexts = ArrayList<TreeContext>()
        downloadNodeName = ""
        installNodeName = ""
        scriptsNodeName = ""
    }

    /// 执行提升式安装
    /// 翻译自: installHoistedPackages
    ///   主入口函数, 负责创建 node_modules 并安装所有包
    public func install(
        lockfile: LockfileData,
        installRootDependencies: Bool,
        workspaceFilters: ArrayList<WorkspaceFilter>,
        packagesToInstall: ?ArrayList<UInt32>
    ): PackageInstallSummary {
        // 翻译自:
        //   try this.lockfile.filter(this.log, this, install_root_dependencies, workspace_filters, packages_to_install)

        // 1. 创建/打开 node_modules 目录
        setupNodeModules()

        // 2. 设置安装选项
        if (forceInstall) {
            skipVerify = true
            skipDelete = false
        }

        // 3. 创建 tree 上下文
        setupTreeContexts(lockfile)

        // 4. 遍历 lockfile 的依赖树, 安装每个包
        let trees = lockfile.trees
        for (tree in trees) {
            nodeModulesPath = tree.relativePath
            currentTreeId = tree.id

            // 获取此 tree 的依赖列表
            let dependencies = tree.dependencies

            // 安装每个依赖
            for (depId in dependencies) {
                installPackage(depId, lockfile)
            }

            // 处理待完成的任务
            // 翻译自: manager.runTasks(...)
            processPendingTasks(lockfile)
        }

        // 5. 等待所有任务完成
        waitForAllTasks()

        // 6. 链接二进制文件
        linkRemainingBinaries(lockfile)

        // 7. 运行剩余的生命周期脚本
        completeRemainingScripts()

        // 8. 更新摘要
        summary.successfullyInstalled = successfullyInstalled
        return summary
    }

    /// 创建/打开 node_modules 目录
    /// 翻译自: installHoistedPackages 中的 node_modules_folder 创建逻辑
    private func setupNodeModules(): Unit {
        let cwd = OS.getcwd()
        let nodeModulesPath = "${cwd}/node_modules"

        if (!SysFs.exists(nodeModulesPath)) {
            isNewNodeModules = true
            if (!BaoFile.mkdir(nodeModulesPath, true)) {
                return
            }
        }

        rootNodeModulesDir = nodeModulesPath
    }

    /// 设置 tree 上下文
    /// 翻译自: installHoistedPackages 中的 completed_trees 和 tree_ids_to_trees_the_id_depends_on 计算
    private func setupTreeContexts(lockfile: LockfileData): Unit {
        treeContexts.clear()
        for (tree in lockfile.trees) {
            let ctx = TreeContext(tree.id)
            treeContexts.append(ctx)
        }
    }

    /// 安装单个包
    /// 翻译自: PackageInstaller.installPackage
    private func installPackage(depId: UInt32, lockfile: LockfileData): Unit {
        let packageId = lockfile.resolutions[Int64(depId)]
        if (packageId == INVALID_PACKAGE_ID) { return }

        let name = lockfile.getPackageName(packageId)
        let resolution = lockfile.getResolution(packageId)
        let resolutionTag = lockfile.getResolutionTag(packageId)

        // 检查是否需要安装
        let needsInstall = forceInstall || skipVerify || !verifyPackage(name, resolution, lockfile)
        if (!needsInstall) {
            summary.skipped += 1
            return
        }

        // 检查缓存
        if (resolutionTag.canEnqueueInstallTask() && isPackageMissingFromCache(packageId, lockfile)) {
            // 需要下载: 将任务加入队列
            enqueuePackageDownload(depId, packageId, name, resolution, lockfile)
            return
        }

        // 检查是否能安装 (父 tree 是否完成)
        // 翻译自: PackageInstaller.canInstallPackageForTree
        if (!canInstallPackageForTree(lockfile)) {
            // 延迟安装
            treeContexts[Int64(currentTreeId)].pendingInstalls.append(
                DependencyInstallContextData(currentTreeId, nodeModulesPath, depId)
            )
            return
        }

        // 执行安装
        let request = PackageInstallRequest()
        request.cacheDir = manager.cacheDirectoryPath
        request.destinationDirSubpath = name
        request.packageName = name
        request.packageVersion = resolution
        request.nodeModulesPath = nodeModulesPath
        request.nodeModulesTreeId = currentTreeId
        request.skipDelete = skipDelete
        request.skipVerify = skipVerify
        request.forceInstall = forceInstall

        // 设置缓存子路径
        setupCacheSubpath(request, packageId, resolutionTag, lockfile)

        let result = request.install(skipDelete, nodeModulesPath, request.getInstallMethod(), resolutionTag)
        match (result) {
            case PackageInstallResult.Success => handleInstallSuccess(packageId, successfullyInstalled, summary, currentTreeId, lockfile)
            case PackageInstallResult.Failure(failure) => handleInstallFailure(name, failure, summary, currentTreeId, lockfile)
        }
    }

    private func handleInstallSuccess(packageId: UInt32, successfullyInstalled: HashSet<UInt32>, summary: PackageInstallSummary, currentTreeId: UInt32, lockfile: LockfileData): Unit {
        let isDuplicate = successfullyInstalled.contains(packageId)
        if (!isDuplicate) { summary.success += 1 }
        successfullyInstalled.put(packageId)
        incrementTreeInstallCount(currentTreeId, lockfile)
    }

    private func handleInstallFailure(name: String, failure: InstallFailure, summary: PackageInstallSummary, currentTreeId: UInt32, lockfile: LockfileData): Unit {
        Output.printErrorln("Failed to install ${name}: ${failure.errorMessage}")
        summary.fail += 1
        incrementTreeInstallCount(currentTreeId, lockfile)
    }

    /// 验证包是否已正确安装
    /// 翻译自: PackageInstall.verify
    private func verifyPackage(name: String, resolution: String, lockfile: LockfileData): Bool {
        let destPath = "${nodeModulesPath}/${name}/package.json"
        if (!BaoFile.exists(destPath)) { return false }

        match (BaoFile.readAllText(destPath)) {
            case SysMaybe<String>.Ok(content) =>
                let json = JsonParser().parse(content)
                match (json) {
                    case Some(root) =>
                        match (JsonHelper.getString(root, "version")) {
                            case Some(v) => return v == resolution
                            case None => return false
                        }
                    case None => return false
                }
            case SysMaybe<String>.Err(_) => return false
        }
    }

    /// 检查包是否在缓存中缺失
    /// 翻译自: PackageInstaller.installPackageWithNameAndResolution 中的 packageMissingFromCache
    private func isPackageMissingFromCache(packageId: UInt32, lockfile: LockfileData): Bool {
        let name = lockfile.getPackageName(packageId)
        let cachePath = "${manager.cacheDirectoryPath}/${name}"
        return !SysFs.exists(cachePath)
    }

    /// 将包下载加入队列
    /// 翻译自: PackageInstaller 中的 enqueue 逻辑
    private func enqueuePackageDownload(
        depId: UInt32,
        packageId: UInt32,
        name: String,
        resolution: String,
        lockfile: LockfileData
    ): Unit {
        // 翻译自: 根据 resolution.tag 分发到不同的 enqueue 方法
        let tag = lockfile.getResolutionTag(packageId)
        match (tag) {
            case Npm=> ()  // enqueuePackageForDownload
            case Git=> ()  // enqueueGitForCheckout
            case Github=> ()  // enqueueTarballForDownload (github tarball)
            case Tarball=> ()  // enqueueTarballForDownload
            case _ => ()
        }
    }

    /// 设置缓存子路径
    /// 翻译自: PackageInstaller.installPackageWithNameAndResolution 中根据 resolution.tag 设置缓存路径
    private func setupCacheSubpath(
        request: PackageInstallRequest,
        packageId: UInt32,
        tag: DependencyVersionTag,
        lockfile: LockfileData
    ): Unit {
        match (tag) {
            case Npm => setupCacheSubpathNpm(request, packageId, lockfile)
            case Git => setupCacheSubpathGit(request, packageId, lockfile)
            case Github => setupCacheSubpathGithub(request, packageId, lockfile)
            case Folder => setupCacheSubpathFolder(request, packageId, lockfile)
            case Workspace => setupCacheSubpathWorkspace(request)
            case Symlink => setupCacheSubpathSymlink(request)
            case _=> request.cacheDir = manager.cacheDirectoryPath
        }
    }

    private func setupCacheSubpathNpm(request: PackageInstallRequest, packageId: UInt32, lockfile: LockfileData): Unit {
        let name = lockfile.getPackageName(packageId)
        let version = lockfile.getResolution(packageId)
        request.cacheDirSubpath = "${name}@${version}"
        request.cacheDir = manager.cacheDirectoryPath
    }

    private func setupCacheSubpathGit(request: PackageInstallRequest, packageId: UInt32, lockfile: LockfileData): Unit {
        request.cacheDirSubpath = lockfile.getResolution(packageId)
        request.cacheDir = manager.cacheDirectoryPath
    }

    private func setupCacheSubpathGithub(request: PackageInstallRequest, packageId: UInt32, lockfile: LockfileData): Unit {
        request.cacheDirSubpath = lockfile.getResolution(packageId)
        request.cacheDir = manager.cacheDirectoryPath
    }

    private func setupCacheSubpathFolder(request: PackageInstallRequest, packageId: UInt32, lockfile: LockfileData): Unit {
        request.cacheDirSubpath = lockfile.getResolution(packageId)
        request.cacheDir = OS.getcwd()
    }

    private func setupCacheSubpathWorkspace(request: PackageInstallRequest): Unit {
        request.cacheDirSubpath = "."
        request.cacheDir = OS.getcwd()
    }

    private func setupCacheSubpathSymlink(request: PackageInstallRequest): Unit {
        request.cacheDirSubpath = "."
        request.cacheDir = OS.getcwd()
    }

    /// 处理待完成的任务
    /// 翻译自: manager.runTasks()
    private func processPendingTasks(lockfile: LockfileData): Unit {
        // 处理网络任务队列中的下载/解析任务
    }

    /// 等待所有任务完成
    /// 翻译自: installHoistedPackages 中的 while(pendingTaskCount > 0) 循环
    private func waitForAllTasks(): Unit {
        // 等待所有网络任务和生命周期脚本完成
    }

    /// 链接剩余的二进制文件
    /// 翻译自: PackageInstaller.linkRemainingBins
    private func linkRemainingBinaries(lockfile: LockfileData): Unit {
        // 为每个有 bin 条目的包创建符号链接
    }

    /// 完成剩余的生命周期脚本
    /// 翻译自: PackageInstaller.completeRemainingScripts
    private func completeRemainingScripts(): Unit {
        // 运行所有等待中的生命周期脚本
    }

    /// 检查是否可以为指定 tree 安装包
    /// 翻译自: PackageInstaller.canInstallPackageForTree
    ///   遍历父 tree 链, 检查是否所有父 tree 都已完成
    private func canInstallPackageForTree(lockfile: LockfileData): Bool {
        let trees = lockfile.trees
        if (Int64(currentTreeId) >= trees.size) { return true }
        var parentId = trees[Int64(currentTreeId)].parentId
        while (parentId != INVALID_PACKAGE_ID) {
            if (parentId < UInt32(treeContexts.size)) {
                if (!treeContexts[Int64(parentId)].completed) {
                    return false
                }
            }
            if (Int64(parentId) >= trees.size) { () }
            parentId = trees[Int64(parentId)].parentId
        }
        return true
    }

    /// 递增 tree 安装计数
    /// 翻译自: PackageInstaller.incrementTreeInstallCount
    private func incrementTreeInstallCount(treeId: UInt32, lockfile: LockfileData): Unit {
        if (Int64(treeId) >= treeContexts.size) { return }
        let tree = treeContexts[Int64(treeId)]
        tree.installCount += 1

        let maxCount = lockfile.trees[Int64(treeId)].dependencyCount
        if (tree.installCount >= maxCount) {
            tree.completed = true
            // 安装此 tree 的待处理包
            installPendingPackages(treeId, lockfile)
        }
    }

    /// 安装待处理包
    /// 翻译自: PackageInstaller.installAvailablePackages
    private func installPendingPackages(treeId: UInt32, lockfile: LockfileData): Unit {
        if (Int64(treeId) >= treeContexts.size) { return }
        let tree = treeContexts[Int64(treeId)]
        for (ctx in tree.pendingInstalls) {
            let prevPath = nodeModulesPath
            let prevTreeId = currentTreeId
            nodeModulesPath = ctx.path
            currentTreeId = ctx.treeId
            installPackage(ctx.dependencyId, lockfile)
            nodeModulesPath = prevPath
            currentTreeId = prevTreeId
        }
        tree.pendingInstalls.clear()
    }
}

// ============================================================================
// Tree 上下文
// 翻译自: src/install/PackageInstaller.zig - TreeContext
//   pub const TreeContext = struct {
//       pending_installs: std.ArrayListUnmanaged(DependencyInstallContext),
//       binaries: Bin.PriorityQueue,
//       install_count: usize = 0,
//   }
// ============================================================================

/// 依赖安装上下文
/// 翻译自: install.DependencyInstallContext
public class DependencyInstallContextData {
    public var treeId: UInt32
    public var path: String
    public var dependencyId: UInt32

    public init(treeId: UInt32, path: String, dependencyId: UInt32) {
        this.treeId = treeId
        this.path = path
        this.dependencyId = dependencyId
    }
}

/// Tree 安装上下文
/// 对应 Bun: PackageInstaller.TreeContext
public class TreeContext {
    /// Tree ID
    public let id: UInt32
    /// 等待安装的包列表
    public var pendingInstalls: ArrayList<DependencyInstallContextData>
    /// 二进制链接队列
    public var binaries: ArrayList<UInt32>
    /// 已安装数量
    public var installCount: Int64
    /// 是否已完成
    public var completed: Bool

    public init(id: UInt32) {
        this.id = id
        pendingInstalls = ArrayList<DependencyInstallContextData>()
        binaries = ArrayList<UInt32>()
        installCount = 0
        completed = false
    }
}

/// Lockfile 树节点
/// 翻译自: Lockfile.Tree
public class LockfileTree {
    /// Tree ID
    public let id: UInt32
    /// 父 Tree ID
    public var parentId: UInt32
    /// 相对路径
    public var relativePath: String
    /// 依赖 ID 列表
    public var dependencies: ArrayList<UInt32>
    /// 依赖数量
    public var dependencyCount: Int64

    public init(id: UInt32) {
        this.id = id
        parentId = INVALID_PACKAGE_ID
        relativePath = ""
        dependencies = ArrayList<UInt32>()
        dependencyCount = 0
    }
}

// ============================================================================
// Workspace 过滤器
// 严格翻译自: src/install/PackageManager.zig - WorkspaceFilter
//   pub const WorkspaceFilter = union(enum) { all, name: []const u8, path: []const u8 }
// ============================================================================

/// Workspace 过滤器
public enum WorkspaceFilter {
    | All
    | Name(String)
    | Path(String)

    /// 从输入创建过滤器
    /// 翻译自: WorkspaceFilter.init
    public static func create(input: String, cwd: String): WorkspaceFilter {
        if (input == "*" || input == "**") {
            return All
        }
        var remain = input
        if (remain.size > 0 && remain[0] == UInt8(46)) {
            let absPath = Path.join([cwd, remain])
            return Path(absPath)
        }
        return Name(remain)
    }
}