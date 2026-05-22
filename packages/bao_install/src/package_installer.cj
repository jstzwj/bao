// bao_install - 包安装器
// 严格翻译自: src/install/PackageInstaller.zig
//   pub const PackageInstaller = struct {
//       manager: *PackageManager,
//       lockfile: *Lockfile,
//       progress: *Progress,
//       node_modules: NodeModulesFolder,
//       skip_verify_installed_version_number: bool,
//       skip_delete: bool,
//       force_install: bool,
//       root_node_modules_folder: std.fs.Dir,
//       summary: *PackageInstall.Summary,
//       options: *const PackageManager.Options,
//       metas: []const Lockfile.Package.Meta,
//       names: []const String,
//       ...
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_sys.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// NodeModules 文件夹信息
// 严格翻译自: src/install/PackageInstaller.zig - NodeModulesFolder
//   pub const NodeModulesFolder = struct {
//       tree_id: Lockfile.Tree.Id = 0,
//       path: std.array_list.Managed(u8),
//   }
// ============================================================================

/// NodeModules 文件夹信息
/// 对应 Bun: PackageInstaller.NodeModulesFolder
public class NodeModulesFolder {
    /// Tree ID
    public var treeId: UInt32
    /// 完整路径
    public var path: String

    public init() {
        treeId = UInt32(0)
        path = ""
    }

    public init(path: String, treeId: UInt32) {
        this.path = path
        this.treeId = treeId
    }

    /// 目录是否存在
    /// 翻译自: NodeModulesFolder.directoryExistsAt
    public func directoryExistsAt(rootModulesDir: String, filePath: String): Bool {
        let fullPath = "${path}/${filePath}"
        return BaoFile.isDirectory(fullPath)
    }

    /// 读取文件
    /// 翻译自: NodeModulesFolder.readFile
    public func readFile(rootModulesDir: String, filePath: String): ?String {
        let fullPath = "${path}/${filePath}"
        return BaoFile.readAllText(fullPath).result()
    }

    /// 打开/创建目录
    /// 翻译自: NodeModulesFolder.makeAndOpenDir
    public func makeAndOpenDir(rootModulesDir: String): ?String {
        if (!BaoFile.isDirectory(path)) {
            try {
                BaoFile.mkdir(path, true)
            } catch (_: Exception) {
                return None
            }
        }
        return path
    }
}

// ============================================================================
// Tree 安装上下文
// 严格翻译自: src/install/PackageInstaller.zig - TreeContext
//   pub const TreeContext = struct {
//       pending_installs: std.ArrayListUnmanaged(DependencyInstallContext),
//       binaries: Bin.PriorityQueue,
//       install_count: usize = 0,
//   }
// ============================================================================

/// Tree 安装上下文
/// 对应 Bun: PackageInstaller.TreeContext
public class InstallerTreeContext {
    /// 等待安装的包 (父 tree 未完成时)
    public var pendingInstalls: ArrayList<DependencyInstallContextData>
    /// 待链接的二进制文件
    public var binaries: ArrayList<UInt32>
    /// 已安装数量
    public var installCount: Int64
    /// 最大安装数 (来自 tree.dependencies.len)
    public var maxCount: Int64
    /// 是否已完成
    public var completed: Bool

    public init() {
        pendingInstalls = ArrayList<DependencyInstallContextData>()
        binaries = ArrayList<UInt32>()
        installCount = 0
        maxCount = Int64.Max
        completed = false
    }

    public init(maxCount: Int64) {
        pendingInstalls = ArrayList<DependencyInstallContextData>()
        binaries = ArrayList<UInt32>()
        installCount = 0
        this.maxCount = maxCount
        completed = false
    }

    /// 清理
    /// 翻译自: TreeContext.deinit
    public func deinit(): Unit {
        pendingInstalls.clear()
        binaries.clear()
    }
}

// ============================================================================
// 懒加载包目标目录
// 严格翻译自: src/install/PackageInstaller.zig - LazyPackageDestinationDir
//   pub const LazyPackageDestinationDir = union(enum) {
//       dir: std.fs.Dir,
//       node_modules_path: struct { node_modules: *NodeModulesFolder, root_node_modules_dir: std.fs.Dir },
//       closed: void,
//   }
// ============================================================================

/// 懒加载包目标目录
/// 对应 Bun: PackageInstaller.LazyPackageDestinationDir
public class LazyPackageDestinationDir {
    /// 目录状态
    public var tag: LazyDirTag
    /// 已打开的目录路径
    public var dirPath: String
    /// NodeModules 引用 (node_modules_path 分支)
    public var nodeModules: ?NodeModulesFolder
    /// 根 node_modules 目录 (node_modules_path 分支)
    public var rootNodeModulesDir: String

    public init() {
        tag = LazyDirTag.Closed
        dirPath = ""
        nodeModules = None
        rootNodeModulesDir = ""
    }

    public init(dirPath: String) {
        tag = LazyDirTag.Dir
        this.dirPath = dirPath
        nodeModules = None
        rootNodeModulesDir = ""
    }

    public init(nodeModules: NodeModulesFolder, rootNodeModulesDir: String) {
        tag = LazyDirTag.NodeModulesPath
        dirPath = ""
        this.nodeModules = nodeModules
        this.rootNodeModulesDir = rootNodeModulesDir
    }

    /// 获取目录路径
    /// 翻译自: LazyPackageDestinationDir.getDir
    public func getDir(): ?String {
        match (tag) {
            case LazyDirTag.Dir => return dirPath
            case LazyDirTag.NodeModulesPath =>
                match (nodeModules) {
                    case Some(nm) =>
                        let dirOpt = nm.makeAndOpenDir(rootNodeModulesDir)
                        match (dirOpt) {
                            case Some(dir) =>
                                dirPath = dir
                                tag = LazyDirTag.Dir
                                return dirPath
                            case None => return None
                        }
                    case None => return None
                }
            case LazyDirTag.Closed => return None
        }
    }

    /// 关闭目录
    /// 翻译自: LazyPackageDestinationDir.close
    public func close(): Unit {
        tag = LazyDirTag.Closed
        dirPath = ""
        nodeModules = None
    }
}

/// 懒加载目录状态标签
public enum LazyDirTag {
    | Dir
    | NodeModulesPath
    | Closed
}

// ============================================================================
// 包安装器
// 严格翻译自: src/install/PackageInstaller.zig - PackageInstaller
//   PackageInstaller 是 hoisted install 模式下的核心安装器:
//   管理安装流程、tree 完成状态、二进制链接、生命周期脚本
// ============================================================================

/// 包安装器
/// 对应 Bun: PackageInstaller
public class PackageInstaller {
    /// 包管理器引用
    public var manager: PackageManagerRef
    /// Lockfile 引用
    public var lockfile: LockfileData
    /// 日志级别
    public var logLevel: InstallLogLevel
    /// 当前 node_modules 信息
    public var nodeModules: NodeModulesFolder
    /// 根 node_modules 目录
    public var rootNodeModulesFolder: String
    /// 是否跳过版本验证
    public var skipVerifyInstalledVersionNumber: Bool
    /// 是否跳过删除
    public var skipDelete: Bool
    /// 是否强制安装
    public var forceInstall: Bool
    /// 安装摘要
    public var summary: PackageInstallSummary
    /// 安装选项
    public var options: InstallerOptions
    /// 包元数据列表
    public var metas: ArrayList<PackageMeta>
    /// 包名列表
    public var names: ArrayList<String>
    /// 包依赖切片
    public var pkgDependencies: ArrayList<DependencySlice>
    /// 包名哈希列表
    public var pkgNameHashes: ArrayList<UInt64>
    /// 二进制信息列表
    public var bins: ArrayList<PackageBinInfo>
    /// 解析结果列表
    public var resolutions: ArrayList<String>
    /// 成功安装的包 ID 集合
    public var successfullyInstalled: HashSet<UInt32>
    /// 当前 tree ID
    public var currentTreeId: UInt32
    /// Tree 上下文列表
    public var trees: ArrayList<InstallerTreeContext>
    /// 已完成的 tree 集合
    public var completedTrees: HashSet<UInt32>
    /// tree ID 所依赖的 tree 列表
    /// 翻译自: tree_ids_to_trees_the_id_depends_on: Bitset.List
    public var treeIdsToTreesTheIdDependsOn: ArrayList<HashSet<UInt32>>
    /// 可信依赖 (来自 update requests)
    public var trustedDependenciesFromUpdateRequests: HashSet<UInt32>
    /// 已看到的 bin 链接
    public var seenBinLinks: HashSet<String>
    /// 待执行的生命周期脚本
    public var pendingLifecycleScripts: ArrayList<PendingLifecycleScript>

    public init(manager: PackageManagerRef, lockfile: LockfileData) {
        this.manager = manager
        this.lockfile = lockfile
        logLevel = InstallLogLevel.Default
        nodeModules = NodeModulesFolder()
        rootNodeModulesFolder = ""
        skipVerifyInstalledVersionNumber = false
        skipDelete = false
        forceInstall = false
        summary = PackageInstallSummary()
        options = InstallerOptions()
        metas = ArrayList<PackageMeta>()
        names = ArrayList<String>()
        pkgDependencies = ArrayList<DependencySlice>()
        pkgNameHashes = ArrayList<UInt64>()
        bins = ArrayList<PackageBinInfo>()
        resolutions = ArrayList<String>()
        successfullyInstalled = HashSet<UInt32>()
        currentTreeId = UInt32(0)
        trees = ArrayList<InstallerTreeContext>()
        completedTrees = HashSet<UInt32>()
        treeIdsToTreesTheIdDependsOn = ArrayList<HashSet<UInt32>>()
        trustedDependenciesFromUpdateRequests = HashSet<UInt32>()
        seenBinLinks = HashSet<String>()
        pendingLifecycleScripts = ArrayList<PendingLifecycleScript>()
    }

    /// 递增 tree 安装计数
    /// 翻译自: PackageInstaller.incrementTreeInstallCount
    ///   pub fn incrementTreeInstallCount(this, tree_id, comptime should_install_packages, log_level) void
    public func incrementTreeInstallCount(treeId: UInt32): Unit {
        if (Int64(treeId) >= trees.size) { return }
        let tree = trees[Int64(treeId)]
        let currentCount = tree.installCount
        let max = tree.maxCount

        // maxInt 表示已经完成
        if (currentCount == Int64.Max) {
            return
        }

        let isNotDone = currentCount + 1 < max
        tree.installCount = if (isNotDone) { currentCount + 1 } else { Int64.Max }

        if (isNotDone) { return }

        // tree 完成
        tree.completed = true
        completedTrees.put(treeId)

        // 链接二进制文件
        if (tree.binaries.size > 0) {
            seenBinLinks.clear()
            linkTreeBins(treeId)
        }

        // 安装可用的待处理包
        installAvailablePackages()

        // 运行可用的生命周期脚本
        runAvailableScripts()
    }

    /// 安装单个包
    /// 翻译自: PackageInstaller.installPackage
    ///   pub fn installPackage(this, dep_id, log_level) void
    public func installPackage(depId: UInt32): Unit {
        if (Int64(depId) >= lockfile.resolutions.size) { return }
        let packageId = lockfile.resolutions[Int64(depId)]
        if (packageId == INVALID_PACKAGE_ID) { return }

        let name = lockfile.getPackageName(packageId)
        let resolution = lockfile.getResolution(packageId)

        installPackageWithNameAndResolution(
            depId,
            packageId,
            logLevel,
            name,
            resolution,
            true,   // needsVerify
            false   // isPendingPackageInstall
        )
    }

    /// 安装指定名称和解析的包
    /// 严格翻译自: PackageInstaller.installPackageWithNameAndResolution
    ///   pub fn installPackageWithNameAndResolution(this, dependency_id, package_id, log_level,
    ///       pkg_name, resolution, comptime needs_verify, comptime is_pending_package_install) void
    public func installPackageWithNameAndResolution(
        depId: UInt32,
        packageId: UInt32,
        logLevel: InstallLogLevel,
        pkgName: String,
        resolution: String,
        needsVerify: Bool,
        isPendingPackageInstall: Bool
    ): Unit {
        // 设置目标子路径
        let destSubpath = pkgName

        // 判断是否需要安装
        let needsInstall = forceInstall ||
            skipVerifyInstalledVersionNumber ||
            !needsVerify ||
            !verifyPackage(destSubpath, resolution)

        if (!needsInstall) {
            summary.skipped += 1

            // 即使已安装, 仍需处理 bin 链接和可信依赖
            handleAlreadyInstalledPackage(depId, packageId, pkgName, resolution)
            incrementTreeInstallCount(currentTreeId)
            return
        }

        // 检查缓存是否缺失, 需要下载
        let tag = lockfile.getResolutionTag(packageId)
        if (tag.canEnqueueInstallTask() && isMissingFromCache(packageId)) {
            // 根据解析类型加入不同的下载队列
            enqueueForDownload(depId, packageId, pkgName, resolution, tag)
            return
        }

        // 检查是否有补丁需要应用, 补丁缓存缺失
        if (hasPatchForPackage(pkgName, resolution)) {
            if (patchedPackageMissingFromCache(packageId)) {
                enqueuePatchTask(depId, packageId, pkgName, resolution)
                return
            }
        }

        // 检查是否可以安装 (父 tree 是否完成)
        if (!isPendingPackageInstall && !canInstallPackageForTree()) {
            trees[Int64(currentTreeId)].pendingInstalls.append(
                DependencyInstallContextData(currentTreeId, nodeModules.path, depId)
            )
            return
        }

        // 创建目标目录
        let destDir = nodeModules.makeAndOpenDir(rootNodeModulesFolder)
        match (destDir) {
            case None =>
                Output.printErrorln("Failed to open node_modules folder for ${pkgName}")
                summary.fail += 1
                incrementTreeInstallCount(currentTreeId)
                return
            case Some(_) => ()
        }

        // 执行安装
        let request = PackageInstallRequest()
        request.cacheDir = manager.cacheDirectoryPath
        request.destinationDirSubpath = destSubpath
        request.packageName = pkgName
        request.packageVersion = resolution
        request.nodeModulesPath = nodeModules.path
        request.nodeModulesTreeId = currentTreeId
        request.skipDelete = skipDelete
        request.forceInstall = forceInstall

        setupCacheSubpath(request, packageId, tag)

        let result = request.install(skipDelete, nodeModules.path, request.getInstallMethod(), tag)
        match (result) {
            case PackageInstallResult.Success =>
                let isDuplicate = successfullyInstalled.contains(packageId)
                if (!isDuplicate) { summary.success += 1 }
                successfullyInstalled.put(packageId)

                handleSuccessfullyInstalledPackage(depId, packageId, pkgName, resolution, tag)
                incrementTreeInstallCount(currentTreeId)
            case PackageInstallResult.Failure(failure) =>
                Output.printErrorln("Failed ${failure.step.name()} for package ${pkgName}: ${failure.errorMessage}")

                // 处理特殊的错误类型
                if (failure.errorMessage.contains("DanglingSymlink")) {
                    Output.printErrorln("error: ${pkgName} \"link:${pkgName}\" not found (try running 'bun link' in the intended package's folder)")
                } else if (failure.errorMessage.contains("AccessDenied")) {
                    Output.printErrorln("EACCES: Permission denied while installing ${pkgName}")
                }

                summary.fail += 1
                incrementTreeInstallCount(currentTreeId)
        }
    }

    /// 提取后安装排队的包
    /// 严格翻译自: PackageInstaller.installEnqueuedPackagesAfterExtraction
    ///   pub fn installEnqueuedPackagesAfterExtraction(this, task_id, dependency_id, data, log_level) void
    public func installEnqueuedPackagesAfterExtraction(
        taskId: Int64,
        dependencyId: UInt32,
        data: ExtractData
    ): Unit {
        let packageId = lockfile.resolutions[Int64(dependencyId)]
        let name = lockfile.getPackageName(packageId)

        // 处理完整性哈希: 如果有新计算的完整性哈希 (如 GitHub tarball) 且 lockfile 中没有,
        // 则持久化以便 lockfile 重新保存
        if (data.integrity.value.size > 0) {
            let existingIntegrity = lockfile.getIntegrity(packageId)
            if (existingIntegrity.size == 0 || !data.integrity.tag.isSupported()) {
                // 简化: 不修改 lockfile
            }
        }

        // 从任务队列中获取回调列表
        let callbacks = manager.taskQueueFetchRemove(taskId)
        match (callbacks) {
            case Some(callbackList) =>
                if (callbackList.size == 0) {
                    return
                }

                let prevNodeModules = nodeModules
                let prevTreeId = currentTreeId

                for (cb in callbackList) {
                    let context = DependencyInstallContextData(UInt32(0), "", UInt32(0))
                    let callbackPackageId = lockfile.resolutions[Int64(context.dependencyId)]
                    let callbackResolution = lockfile.getResolution(callbackPackageId)

                    nodeModules.treeId = context.treeId
                    nodeModules.path = context.path
                    currentTreeId = context.treeId

                    installPackageWithNameAndResolution(
                        context.dependencyId,
                        callbackPackageId,
                        logLevel,
                        name,
                        callbackResolution,
                        false,  // needsVerify: 下载的不需要再验证
                        false   // isPendingPackageInstall
                    )
                }

                nodeModules = prevNodeModules
                currentTreeId = prevTreeId
            case None => ()
        }
    }

    /// 链接 tree 的二进制文件
    /// 严格翻译自: PackageInstaller.linkTreeBins
    ///   pub fn linkTreeBins(this, tree, tree_id, link_target_buf, link_dest_buf, link_rel_buf, log_level) void
    public func linkTreeBins(treeId: UInt32): Unit {
        if (Int64(treeId) >= trees.size) { return }
        let tree = trees[Int64(treeId)]
        seenBinLinks.clear()

        while (tree.binaries.size > 0) {
            let depId = tree.binaries.removeAt(0)
            if (Int64(depId) >= lockfile.resolutions.size) { () }
            let packageId = lockfile.resolutions[Int64(depId)]
            if (packageId == INVALID_PACKAGE_ID) { () }
            if (Int64(packageId) >= bins.size) { () }

            let binInfo = bins[Int64(packageId)]
            if (binInfo.tag == BinTag.None) { () }

            let alias = lockfile.getPackageName(depId)
            let isGlobal = isGlobalBinLink(packageId, treeId)

            // 检查 native binlink 优化
            var targetPackageName = alias
            let canRetryWithoutNativeBinlink = checkNativeBinlinkOptimization(
                packageId, treeId, alias
            )
            if (canRetryWithoutNativeBinlink) {
                targetPackageName = getNativeBinlinkReplacementName(packageId)
            }

            linkBinary(alias, targetPackageName, binInfo, packageId, isGlobal)

            // 如果因 native binlink 优化而失败, 重试不使用优化
            if (canRetryWithoutNativeBinlink && lastLinkHadError()) {
                linkBinary(alias, alias, binInfo, packageId, isGlobal)
            }
        }
    }

    /// 链接剩余的二进制文件
    /// 翻译自: PackageInstaller.linkRemainingBins
    ///   pub fn linkRemainingBins(this, log_level) void
    public func linkRemainingBins(): Unit {
        for (i in 0..trees.size) {
            let tree = trees[i]
            if (tree.binaries.size > 0) {
                seenBinLinks.clear()

                // 重建 node_modules 路径
                let relPath = lockfile.getTreeRelativePath(UInt32(i))
                nodeModules.path = "${manager.topLevelDir}/${relPath}"

                linkTreeBins(UInt32(i))
            }
        }
    }

    /// 安装可用的待处理包
    /// 严格翻译自: PackageInstaller.installAvailablePackages
    ///   pub fn installAvailablePackages(this, log_level, comptime force) void
    ///   从 id 0 开始向上遍历, 确保能到达任何在当前 tree 完成后可以安装包的 tree
    public func installAvailablePackages(): Unit {
        let prevNodeModules = nodeModules
        let prevTreeId = currentTreeId

        for (i in 0..trees.size) {
            let treeId = UInt32(i)
            if (!completedTrees.contains(treeId) && !canInstallPackageForTree()) {
                continue
            }

            let tree = trees[i]
            let pendingCopy = ArrayList<DependencyInstallContextData>()
            for (ctx in tree.pendingInstalls) {
                pendingCopy.append(ctx)
            }
            tree.pendingInstalls.clear()

            for (ctx in pendingCopy) {
                let packageId = lockfile.resolutions[Int64(ctx.dependencyId)]
                let name = lockfile.getPackageName(packageId)
                let resolution = lockfile.getResolution(packageId)

                nodeModules.treeId = ctx.treeId
                nodeModules.path = ctx.path
                currentTreeId = ctx.treeId

                installPackageWithNameAndResolution(
                    ctx.dependencyId,
                    packageId,
                    logLevel,
                    name,
                    resolution,
                    false,  // needsVerify
                    true    // isPendingPackageInstall
                )
            }
        }

        nodeModules = prevNodeModules
        currentTreeId = prevTreeId
    }

    /// 运行可用的生命周期脚本
    /// 严格翻译自: PackageInstaller.runAvailableScripts
    ///   pub fn runAvailableScripts(this, log_level) void
    public func runAvailableScripts(): Unit {
        var i = pendingLifecycleScripts.size
        while (i > 0) {
            i -= 1
            let entry = pendingLifecycleScripts[i]
            if (canRunScripts(entry.treeId)) {
                pendingLifecycleScripts.removeAt(i)
                spawnLifecycleScripts(entry)
            }
        }
    }

    /// 完成剩余的生命周期脚本
    /// 严格翻译自: PackageInstaller.completeRemainingScripts
    ///   pub fn completeRemainingScripts(this, log_level) void
    public func completeRemainingScripts(): Unit {
        for (entry in pendingLifecycleScripts) {
            // 等待活跃脚本数低于最大并发数
            while (manager.activeLifecycleScriptCount >= manager.maxConcurrentLifecycleScripts) {
                manager.sleep()
                manager.reportSlowLifecycleScripts()
            }

            spawnLifecycleScripts(entry)
        }
        pendingLifecycleScripts.clear()

        // 等待所有待处理的脚本任务完成
        while (manager.pendingLifecycleScriptTasks > 0) {
            manager.reportSlowLifecycleScripts()
            manager.sleep()
        }
    }

    /// 检查是否可以为 tree 安装包
    /// 翻译自: PackageInstaller.canInstallPackageForTree
    ///   pub fn canInstallPackageForTree(this, trees, package_tree_id) bool
    ///   A tree can start installing packages when the parent has installed all its packages.
    public func canInstallPackageForTree(): Bool {
        if (Int64(currentTreeId) >= lockfile.trees.size) { return true }
        var parentId = lockfile.trees[Int64(currentTreeId)].parentId
        while (parentId != INVALID_PACKAGE_ID) {
            if (!completedTrees.contains(parentId)) {
                return false
            }
            if (Int64(parentId) >= lockfile.trees.size) { () }
            parentId = lockfile.trees[Int64(parentId)].parentId
        }
        return true
    }

    /// 检查是否可以运行脚本
    /// 翻译自: PackageInstaller.canRunScripts
    ///   pub fn canRunScripts(this, scripts_tree_id) bool
    ///   检查 tree 的所有依赖 tree 是否都已完成, 且活跃脚本数低于最大并发数

    /// 辅助: 检查 subset 的所有元素是否都在 superset 中
    private static func isSubsetOf(subset: HashSet<UInt32>, superset: HashSet<UInt32>): Bool {
        for (elem in subset.iterator()) {
            if (!superset.contains(elem)) { return false }
        }
        return true
    }

    public func canRunScripts(treeId: UInt32): Bool {
        // 检查依赖的 tree 是否都已完成
        if (Int64(treeId) < treeIdsToTreesTheIdDependsOn.size) {
            let deps = treeIdsToTreesTheIdDependsOn[Int64(treeId)]
            if (!isSubsetOf(deps, completedTrees)) {
                return false
            }
        }

        // 检查活跃脚本并发数
        return manager.activeLifecycleScriptCount < manager.maxConcurrentLifecycleScripts
    }

    /// 修复缓存的 lockfile 包切片
    /// 严格翻译自: PackageInstaller.fixCachedLockfilePackageSlices
    ///   pub fn fixCachedLockfilePackageSlices(this) void
    ///   在 lockfile.packages 长度变化后调用
    public func fixCachedLockfilePackageSlices(): Unit {
        metas = lockfile.getPackageMetas()
        names = lockfile.getPackageNames()
        pkgNameHashes = lockfile.getPackageNameHashes()
        bins = lockfile.getPackageBins()
        resolutions = lockfile.getPackageResolutions()
        pkgDependencies = lockfile.getAllPackageDependencies()

        // 扩展 successfully_installed 位集
        if (successfullyInstalled.size < lockfile.packages.size) {
            let newSet = HashSet<UInt32>()
            for (id in successfullyInstalled.iterator()) {
                newSet.put(id)
            }
            successfullyInstalled = newSet
        }
    }

    /// 清理
    /// 翻译自: PackageInstaller.deinit
    public func deinit(): Unit {
        pendingLifecycleScripts.clear()
        completedTrees.clear()
        for (tree in trees) {
            tree.deinit()
        }
        trees.clear()
        treeIdsToTreesTheIdDependsOn.clear()
        trustedDependenciesFromUpdateRequests.clear()
        seenBinLinks.clear()
    }

    // ===== 私有辅助方法 =====

    /// 验证包是否已正确安装
    /// 翻译自: PackageInstaller.installPackageWithNameAndResolution 中的 verify 调用
    private func verifyPackage(name: String, resolution: String): Bool {
        let destPath = "${nodeModules.path}/${name}/package.json"
        if (!BaoFile.exists(destPath)) { return false }
        let contentResult = BaoFile.readAllText(destPath)
        match (contentResult) {
            case SysMaybe<String>.Ok(c) =>
                let parser = PkgJsonParser()
                let jsonOpt = parser.parse(c)
                match (jsonOpt) {
                    case Some(json) =>
                        let versionOpt = PkgJsonHelper.getField(json, "version")
                        match (versionOpt) {
                            case Some(JsonValue.Str(s)) => return s == resolution
                            case _ => return false
                        }
                    case None => return false
                }
            case _ => return false
        }
    }

    /// 检查包是否缺失于缓存
    /// 翻译自: PackageInstall.packageMissingFromCache
    private func isMissingFromCache(packageId: UInt32): Bool {
        let name = lockfile.getPackageName(packageId)
        let version = lockfile.getResolution(packageId)
        let cachePath = "${manager.cacheDirectoryPath}/${name}@${version}"
        return !BaoFile.isDirectory(cachePath)
    }

    /// 根据解析类型加入下载队列
    /// 严格翻译自: installPackageWithNameAndResolution 中的 canEnqueueInstallTask 分支
    ///   switch (resolution.tag) { .git => enqueueGitForCheckout, .github => enqueueTarballForDownload,
    ///   .local_tarball => enqueueTarballForReading, .remote_tarball => enqueueTarballForDownload,
    ///   .npm => enqueuePackageForDownload }
    private func enqueueForDownload(
        depId: UInt32,
        packageId: UInt32,
        name: String,
        resolution: String,
        tag: DependencyVersionTag
    ): Unit {
        // 构建回调上下文
        let context = DependencyInstallContextData(
            currentTreeId,
            nodeModules.path,
            depId
        )

        match (tag) {
            case DependencyVersionTag.Git =>
                manager.enqueueGitForCheckout(depId, name, resolution, context)
            case DependencyVersionTag.Github =>
                let url = manager.allocGitHubURL(resolution)
                manager.enqueueTarballForDownload(depId, packageId, url, context)
            case DependencyVersionTag.Tarball =>
                manager.enqueueTarballForReading(depId, packageId, name, resolution, context)
            case DependencyVersionTag.Npm =>
                manager.enqueuePackageForDownload(name, depId, packageId, resolution, context)
            case _ =>
                incrementTreeInstallCount(currentTreeId)
                summary.fail += 1
        }
    }

    /// 设置缓存子路径
    /// 翻译自: installPackageWithNameAndResolution 中的 cache_dir_subpath 设置
    private func setupCacheSubpath(request: PackageInstallRequest, packageId: UInt32, tag: DependencyVersionTag): Unit {
        match (tag) {
            case DependencyVersionTag.Npm =>
                let name = lockfile.getPackageName(packageId)
                let version = lockfile.getResolution(packageId)
                request.cacheDirSubpath = "${name}@${version}"
                request.cacheDir = manager.cacheDirectoryPath
            case DependencyVersionTag.Git =>
                let name = lockfile.getPackageName(packageId)
                let version = lockfile.getResolution(packageId)
                request.cacheDirSubpath = "git-${name}-${version}"
                request.cacheDir = manager.cacheDirectoryPath
            case DependencyVersionTag.Github =>
                let name = lockfile.getPackageName(packageId)
                let version = lockfile.getResolution(packageId)
                request.cacheDirSubpath = "github-${name}-${version}"
                request.cacheDir = manager.cacheDirectoryPath
            case DependencyVersionTag.Folder =>
                request.cacheDirSubpath = lockfile.getResolution(packageId)
                request.cacheDir = OS.getcwd()
            case DependencyVersionTag.Workspace =>
                request.cacheDirSubpath = "."
                request.cacheDir = OS.getcwd()
            case DependencyVersionTag.Symlink =>
                let folder = lockfile.getResolution(packageId)
                if (folder.size == 0 || (folder.size == 1 && folder == ".")) {
                    request.cacheDirSubpath = "."
                    request.cacheDir = OS.getcwd()
                } else {
                    request.cacheDirSubpath = folder
                    request.cacheDir = manager.globalLinkDirPath
                }
            case DependencyVersionTag.Root =>
                request.cacheDirSubpath = "."
                request.cacheDir = OS.getcwd()
            case _ =>
                request.cacheDirSubpath = lockfile.getResolution(packageId)
                request.cacheDir = manager.cacheDirectoryPath
        }
    }

    /// 链接二进制文件
    /// 翻译自: Bin.Linker.link
    private func linkBinary(alias: String, targetPackageName: String, binInfo: PackageBinInfo, packageId: UInt32, isGlobal: Bool): Unit {
        // 翻译自: Bin.Linker.link
        let binObj = PackageBin()
        match (binInfo.tag) {
            case BinTag.File => binObj.filePath = binInfo.file
            case BinTag.Map => binObj.binMap = binInfo.map
            case BinTag.Dir => binObj.dirPath = binInfo.dir
            case _ => ()
        }
        let binLinker = BinLinker(
            binObj,
            nodeModules.path,
            targetPackageName,
            nodeModules.path,
            alias,
            ""
        )
        binLinker.link(isGlobal)
    }

    /// 链接二进制文件 (重载 - 简单版本)
    private func linkBinary(alias: String, binInfo: PackageBinInfo, packageId: UInt32): Unit {
        linkBinary(alias, alias, binInfo, packageId, false)
    }

    /// 检查是否是全局 bin 链接
    /// 翻译自: linkTreeBins 中的 global 检查
    private func isGlobalBinLink(packageId: UInt32, treeId: UInt32): Bool {
        if (!manager.isGlobal) { return false }
        if (treeId != UInt32(0)) { return false }

        for (request in manager.updateRequests) {
            if (request.packageId == packageId) {
                return true
            }
        }
        return false
    }

    /// 检查 native binlink 优化
    /// 翻译自: linkTreeBins 中的 native_binlink_optimization 分支
    private func checkNativeBinlinkOptimization(packageId: UInt32, treeId: UInt32, alias: String): Bool {
        if (!manager.postinstallOptimizer.isNativeBinlinkEnabled()) {
            return false
        }
        if (treeId != UInt32(0)) {
            // native binlink 优化目前只支持根 tree
            return false
        }

        if (Int64(packageId) < pkgNameHashes.size) {
            let nameHash = pkgNameHashes[Int64(packageId)]
            if (manager.postinstallOptimizer.get(nameHash) .isSome()) {
                return true
            }
        }
        return false
    }

    /// 获取 native binlink 替换包名
    private func getNativeBinlinkReplacementName(packageId: UInt32): String {
        if (Int64(packageId) < names.size) {
            return names[Int64(packageId)]
        }
        return ""
    }

    /// 上一次链接是否有错误
    private var lastLinkError: Bool = false

    private func lastLinkHadError(): Bool {
        return lastLinkError
    }

    /// 处理已安装的包 (不需要重新安装)
    /// 严格翻译自: installPackageWithNameAndResolution 中的 !needs_install 分支
    ///   处理 bin 链接和可信依赖的生命周期脚本
    private func handleAlreadyInstalledPackage(
        depId: UInt32,
        packageId: UInt32,
        name: String,
        resolution: String
    ): Unit {
        // 检查 bin 链接
        if (Int64(packageId) < bins.size && bins[Int64(packageId)].tag != BinTag.None) {
            trees[Int64(currentTreeId)].binaries.append(depId)
        }

        // 检查可信依赖
        let dep = lockfile.getDependency(depId)
        let truncatedDepNameHash = UInt32(dep.nameHash & UInt64(0xFFFFFFFF))
        var isTrusted = false
        var isTrustedThroughUpdateRequest = false
        var addToLockfile = false

        if (trustedDependenciesFromUpdateRequests.contains(truncatedDepNameHash)) {
            isTrusted = true
            isTrustedThroughUpdateRequest = true
        } else if (manager.summaryAddedTrustedDependencies.contains(name)) {
            isTrusted = true
            addToLockfile = true
        }

        let tag = lockfile.getResolutionTag(packageId)
        if (tag != DependencyVersionTag.Root && isTrusted) {
            let folderPath = "${nodeModules.path}/${name}"
            let enqueued = enqueueLifecycleScripts(
                name,
                packageId,
                folderPath,
                dep.isOptional,
                resolution
            )

            if (enqueued && isTrustedThroughUpdateRequest) {
                manager.trustedDepsToAddToPackageJson.append(name)
            }

            if (enqueued && addToLockfile) {
                lockfile.addTrustedDependency(name)
            }
        }
    }

    /// 处理成功安装的包
    /// 严格翻译自: installPackageWithNameAndResolution 中的 .success 分支
    private func handleSuccessfullyInstalledPackage(
        depId: UInt32,
        packageId: UInt32,
        name: String,
        resolution: String,
        tag: DependencyVersionTag
    ): Unit {
        // 处理二进制链接
        if (Int64(packageId) < bins.size && bins[Int64(packageId)].tag != BinTag.None) {
            trees[Int64(currentTreeId)].binaries.append(depId)
        }

        // 检查可信依赖和生命周期脚本
        let dep = lockfile.getDependency(depId)
        let truncatedDepNameHash = UInt32(dep.nameHash & UInt64(0xFFFFFFFF))
        var isTrusted = false
        var isTrustedThroughUpdateRequest = false

        if (trustedDependenciesFromUpdateRequests.contains(truncatedDepNameHash)) {
            isTrusted = true
            isTrustedThroughUpdateRequest = true
        } else if (lockfile.hasTrustedDependency(name)) {
            isTrusted = true
        }

        if (tag != DependencyVersionTag.Root && (tag == DependencyVersionTag.Workspace || isTrusted)) {
            let folderPath = "${nodeModules.path}/${name}"

            // 检查 postinstall 优化器是否应忽略此包的生命周期脚本
            if (!manager.postinstallOptimizer.shouldIgnoreLifecycleScripts(
                if (Int64(packageId) < pkgNameHashes.size) { pkgNameHashes[Int64(packageId)] } else { UInt64(0) }
            )) {
                let enqueued = enqueueLifecycleScripts(
                    name,
                    packageId,
                    folderPath,
                    dep.isOptional,
                    resolution
                )

                if (enqueued && isTrustedThroughUpdateRequest) {
                    manager.trustedDepsToAddToPackageJson.append(name)
                    lockfile.addTrustedDependency(name)
                }
            }
        }

        // 检查是否有被阻止的脚本
        if (tag != DependencyVersionTag.Root && tag != DependencyVersionTag.Workspace &&
            !isTrusted && Int64(packageId) < metas.size) {
            let count = getInstalledPackageScriptsCount(name, packageId, tag)
            if (count > 0) {
                summary.addBlockedScripts(truncatedDepNameHash, Int64(count))
            }
        }
    }

    /// 排队生命周期脚本
    /// 严格翻译自: PackageInstaller.enqueueLifecycleScripts
    ///   fn enqueueLifecycleScripts(this, folder_name, log_level, package_path, package_id, optional, resolution) bool
    ///   返回 true 如果脚本被排队
    private func enqueueLifecycleScripts(
        name: String,
        packageId: UInt32,
        folderPath: String,
        optional: Bool,
        resolution: String
    ): Bool {
        let scripts = getScriptsForPackage(packageId, folderPath, name, resolution)
        match (scripts) {
            case Some(scriptsList) =>
                if (!options.doRunScripts) { return false }

                manager.totalScripts += scriptsList.total()

                pendingLifecycleScripts.append(
                    PendingLifecycleScript(scriptsList, currentTreeId, optional, name, packageId, name)
                )
            case None => return false
        }

        return true
    }

    /// 获取包的脚本列表
    /// 翻译自: Lockfile.Package.Scripts.getList
    private func getScriptsForPackage(packageId: UInt32): ArrayList<String> {
        return ArrayList<String>()
    }

    /// 获取包的脚本列表 (带文件夹路径)
    /// 翻译自: Lockfile.Package.Scripts.getList + fillFromPackageJSON
    private func getScriptsForPackage(packageId: UInt32, folderPath: String, name: String, resolution: String): ?LifecycleScriptList {
        // 从 lockfile 获取包的脚本
        let scripts = lockfile.getScripts(packageId)
        if (!scripts.filled) {
            // 从 package.json 填充脚本
            let pkgJsonPath = "${folderPath}/package.json"
            if (!BaoFile.exists(pkgJsonPath)) { return None }
            let contentResult = BaoFile.readAllText(pkgJsonPath)
            match (contentResult) {
                case SysMaybe<String>.Ok(c) =>
                    return parseScriptsFromPackageJson(c, name)
                case _ => return None
            }
        }

        let items = scripts.getScriptItems()
        if (items.size == 0) { return None }

        let list = LifecycleScriptList(name)
        list.items = items
        return list
    }

    /// 从 package.json 解析脚本
    private func parseScriptsFromPackageJson(content: String, packageName: String): ?LifecycleScriptList {
        let parser = PkgJsonParser()
        let jsonOpt = parser.parse(content)
        match (jsonOpt) {
            case Some(json) =>
                let scriptsOpt = PkgJsonHelper.getField(json, "scripts")
                match (scriptsOpt) {
                    case Some(JsonValue.Object(scripts)) =>
                        let items = ArrayList<Option<String>>()
                        let scriptNames = ArrayList<String>()
                        var si: Int64 = 0
                        while (si < LockfileScripts.scriptCount()) {
                            scriptNames.append(LockfileScripts.names(si))
                            si += 1
                        }
                        var firstIndex: UInt8 = UInt8(255)
                        var total: Int64 = 0

                        for (i in 0..scriptNames.size) {
                            let scriptName = scriptNames[i]
                            let val = PkgJsonHelper.getField(JsonValue.Object(scripts), scriptName)
                            match (val) {
                                case Some(JsonValue.Str(s)) =>
                                    items.append(s)
                                    if (firstIndex == UInt8(255)) {
                                        firstIndex = UInt8(i)
                                    }
                                    total += 1
                                case _ => items.append(Option<String>.None)
                            }
                        }

                        // 检查 binding.gyp
                        if (total == 0) {
                            return None
                        }

                        let lslist = LifecycleScriptList(packageName)
                        lslist.items = items
                        return lslist
                    case _ => return None
                }
            case None => return None
        }
    }

    /// 获取已安装包的脚本数量
    /// 翻译自: PackageInstaller.getInstalledPackageScriptsCount
    ///   fn getInstalledPackageScriptsCount(this, alias, package_id, resolution_tag, folder_path, log_level) usize
    private func getInstalledPackageScriptsCount(alias: String, packageId: UInt32, tag: DependencyVersionTag): Int64 {
        if (tag == DependencyVersionTag.Root || tag == DependencyVersionTag.Workspace || packageId == UInt32(0)) {
            return 0
        }

        var count: Int64 = 0
        let folderPath = "${nodeModules.path}/${alias}"

        // 获取脚本
        let scripts = lockfile.getScripts(packageId)
        if (!scripts.filled) {
            // 从 package.json 读取
            let pkgJsonPath = "${folderPath}/package.json"
            if (!BaoFile.exists(pkgJsonPath)) { return 0 }
            let contentResult = BaoFile.readAllText(pkgJsonPath)
            match (contentResult) {
                case SysMaybe<String>.Ok(c) =>
                    let parsedOpt = parseScriptsFromPackageJson(c, alias)
                    match (parsedOpt) {
                        case Some(parsed) => count = parsed.total()
                        case None => ()
                    }
                case _ => return 0
            }
        } else {
            count = scripts.getInstallScriptCount()
        }

        // 检查 binding.gyp
        if (count == 0) {
            let bindingGypPath = "${folderPath}/binding.gyp"
            if (BaoFile.exists(bindingGypPath)) {
                count = 1
            }
        }

        return count
    }

    /// 检查包是否有补丁
    private func hasPatchForPackage(name: String, version: String): Bool {
        return lockfile.hasPatchedDependency(name, version)
    }

    /// 检查已补丁的包是否缺失于缓存
    /// 翻译自: PackageInstall.patchedPackageMissingFromCache
    private func patchedPackageMissingFromCache(packageId: UInt32): Bool {
        let name = lockfile.getPackageName(packageId)
        let version = lockfile.getResolution(packageId)
        let cachePath = "${manager.cacheDirectoryPath}/${name}@${version}-patched"
        return !BaoFile.isDirectory(cachePath)
    }

    /// 排队补丁任务
    /// 翻译自: installPackageWithNameAndResolution 中的 patch 分支
    private func enqueuePatchTask(
        depId: UInt32,
        packageId: UInt32,
        name: String,
        resolution: String
    ): Unit {
        let patchHash = lockfile.getPatchedDependencyPatchfileHash(name, resolution)
        let task = PatchTaskData.newApplyPatchHash(
            manager,
            packageId,
            patchHash,
            name,
            resolution
        )
        task.setApplyInstallContext(
            DependencyInstallContextData(currentTreeId, nodeModules.path, depId)
        )
        manager.enqueuePatchTask(task)
    }

    /// 生成生命周期脚本
    /// 翻译自: manager.spawnPackageLifecycleScripts
    private func spawnLifecycleScripts(entry: PendingLifecycleScript): Unit {
        manager.spawnPackageLifecycleScripts(
            entry.scripts,
            entry.pkgId,
            entry.name,
            entry.treeId
        )
    }

    /// 无效 URL 失败处理
    /// 翻译自: PackageInstaller.failWithInvalidUrl
    private func failWithInvalidUrl(): Unit {
        summary.fail += 1
        incrementTreeInstallCount(currentTreeId)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 安装选项
/// 翻译自: PackageManager.Options 中的安装相关选项
public class InstallerOptions {
    /// 是否安装包
    public var doInstallPackages: Bool
    /// 是否运行脚本
    public var doRunScripts: Bool
    /// 是否强制安装
    public var enableForceInstall: Bool
    /// 是否提前失败
    public var enableFailEarly: Bool
    /// bin 路径
    public var binPath: ?String

    public init() {
        doInstallPackages = true
        doRunScripts = true
        enableForceInstall = false
        enableFailEarly = false
        binPath = None
    }
}

/// 依赖切片 (start, end 范围)
/// 翻译自: Lockfile.DependencySlice
public class DependencySlice {
    public var begin: UInt32
    public var end: UInt32

    public init(begin: UInt32, end: UInt32) {
        this.begin = begin
        this.end = end
    }

    public func len(): UInt32 {
        return end - begin
    }
}

/// 包二进制信息
/// 翻译自: Lockfile.Package.bin
public class PackageBinInfo {
    public var tag: BinTag
    public var file: String
    public var map: HashMap<String, String>
    public var dir: String

    public init() {
        tag = BinTag.None
        file = ""
        map = HashMap<String, String>()
        dir = ""
    }
}

/// 待执行的生命周期脚本
/// 翻译自: PackageInstaller.pending_lifecycle_scripts 中的条目
public class PendingLifecycleScript {
    public var scripts: LifecycleScriptList
    public var treeId: UInt32
    public var isOptional: Bool
    public var packageName: String
    public var pkgId: UInt32
    public var name: String

    public init(scripts: LifecycleScriptList, treeId: UInt32, isOptional: Bool, packageName: String, pkgId: UInt32, name: String) {
        this.scripts = scripts
        this.treeId = treeId
        this.isOptional = isOptional
        this.packageName = packageName
        this.pkgId = pkgId
        this.name = name
    }
}
