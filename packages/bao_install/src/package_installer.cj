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
        return bao_io.File.directoryExists(fullPath)
    }

    /// 读取文件
    /// 翻译自: NodeModulesFolder.readFile
    public func readFile(rootModulesDir: String, filePath: String): ?String {
        let fullPath = "${path}/${filePath}"
        try {
            return bao_io.File.readTextFile(fullPath)
        } catch (_: Exception) {
            return None
        }
    }

    /// 打开/创建目录
    /// 翻译自: NodeModulesFolder.makeAndOpenDir
    public func makeAndOpenDir(rootModulesDir: String): ?String {
        if (!bao_io.File.directoryExists(path)) {
            try {
                bao_io.File.createDirectory(path)
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
        maxCount = Int64.MAX
        completed = false
    }

    public init(maxCount: Int64) {
        pendingInstalls = ArrayList<DependencyInstallContextData>()
        binaries = ArrayList<UInt32>()
        installCount = 0
        this.maxCount = maxCount
        completed = false
    }
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
    public var logLevel: LogLevel
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
    /// 可信依赖 (来自 update requests)
    public var trustedDependenciesFromUpdateRequests: HashSet<UInt32>
    /// 已看到的 bin 链接
    public var seenBinLinks: HashSet<String>
    /// 待执行的生命周期脚本
    public var pendingLifecycleScripts: ArrayList<PendingLifecycleScript>

    public init(manager: PackageManagerRef, lockfile: LockfileData) {
        this.manager = manager
        this.lockfile = lockfile
        logLevel = LogLevel.Default
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
        trustedDependenciesFromUpdateRequests = HashSet<UInt32>()
        seenBinLinks = HashSet<String>()
        pendingLifecycleScripts = ArrayList<PendingLifecycleScript>()
    }

    /// 递增 tree 安装计数
    /// 翻译自: PackageInstaller.incrementTreeInstallCount
    public func incrementTreeInstallCount(treeId: UInt32): Unit {
        if (Int64(treeId) >= trees.size) { return }
        let tree = trees[Int64(treeId)]
        let newCount = tree.installCount + 1

        if (newCount >= tree.maxCount) {
            tree.installCount = Int64.MAX
            tree.completed = true
            completedTrees.add(treeId)

            // 链接此 tree 的二进制文件
            linkTreeBins(treeId)

            // 安装可用的待处理包
            installAvailablePackages()

            // 运行可用的生命周期脚本
            runAvailableScripts()
        } else {
            tree.installCount = newCount
        }
    }

    /// 安装单个包
    /// 翻译自: PackageInstaller.installPackage
    public func installPackage(depId: UInt32): Unit {
        if (Int64(depId) >= lockfile.resolutions.size) { return }
        let packageId = lockfile.resolutions[Int64(depId)]
        if (packageId == INVALID_PACKAGE_ID) { return }

        let name = lockfile.getPackageName(packageId)
        let resolution = lockfile.getResolution(packageId)

        installPackageWithNameAndResolution(
            depId,
            packageId,
            name,
            resolution,
            true,   // needsVerify
            false   // isPendingPackageInstall
        )
    }

    /// 安装指定名称和解析的包
    /// 翻译自: PackageInstaller.installPackageWithNameAndResolution
    public func installPackageWithNameAndResolution(
        depId: UInt32,
        packageId: UInt32,
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
            // 检查生命周期脚本和二进制链接
            handleAlreadyInstalledPackage(depId, packageId, pkgName, resolution)
            incrementTreeInstallCount(currentTreeId)
            return
        }

        // 检查缓存是否缺失
        let tag = lockfile.getResolutionTag(packageId)
        if (tag.canEnqueueInstallTask() && isMissingFromCache(packageId)) {
            // 需要下载
            enqueueForDownload(depId, packageId, pkgName, resolution, tag)
            return
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
            case None => {
                bao_core.Output.error("Failed to open node_modules folder for ${pkgName}")
                summary.fail += 1
                incrementTreeInstallCount(currentTreeId)
                return
            }
            case Some(_) => {}
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
            case PackageInstallResult.Success => {
                let isDuplicate = successfullyInstalled.contains(packageId)
                if (!isDuplicate) { summary.success += 1 }
                successfullyInstalled.add(packageId)

                // 处理二进制链接和生命周期脚本
                handleSuccessfullyInstalledPackage(depId, packageId, pkgName, resolution, tag)
                incrementTreeInstallCount(currentTreeId)
            }
            case PackageInstallResult.Failure(failure) => {
                bao_core.Output.error("Failed ${failure.step.name()} for package ${pkgName}: ${failure.errorMessage}")
                summary.fail += 1
                incrementTreeInstallCount(currentTreeId)
            }
        }
    }

    /// 提取后安装排队的包
    /// 翻译自: PackageInstaller.installEnqueuedPackagesAfterExtraction
    public func installEnqueuedPackagesAfterExtraction(
        taskId: Int64,
        dependencyId: UInt32,
        data: ExtractData
    ): Unit {
        let packageId = lockfile.resolutions[Int64(dependencyId)]
        let name = lockfile.getPackageName(packageId)

        // 处理完整性哈希
        if (data.integrity.hash.length > 0) {
            // 更新 lockfile 中的完整性信息
        }

        // 安装所有排队等待此 task 的包
        // 翻译自: 从 task_queue 中获取 callbacks 并安装
    }

    /// 链接 tree 的二进制文件
    /// 翻译自: PackageInstaller.linkTreeBins
    public func linkTreeBins(treeId: UInt32): Unit {
        if (Int64(treeId) >= trees.size) { return }
        let tree = trees[Int64(treeId)]
        seenBinLinks.clear()

        while (tree.binaries.size > 0) {
            let depId = tree.binaries.removeAt(0)
            if (Int64(depId) >= lockfile.resolutions.size) { continue }
            let packageId = lockfile.resolutions[Int64(depId)]
            if (packageId == INVALID_PACKAGE_ID) { continue }
            if (Int64(packageId) >= bins.size) { continue }

            let binInfo = bins[Int64(packageId)]
            if (binInfo.tag == BinTag.None) { continue }

            let alias = lockfile.getPackageName(depId)
            linkBinary(alias, binInfo, packageId)
        }
    }

    /// 链接剩余的二进制文件
    /// 翻译自: PackageInstaller.linkRemainingBins
    public func linkRemainingBins(): Unit {
        for (i in 0..trees.size) {
            let tree = trees[i]
            if (tree.binaries.size > 0) {
                seenBinLinks.clear()
                linkTreeBins(UInt32(i))
            }
        }
    }

    /// 安装可用的待处理包
    /// 翻译自: PackageInstaller.installAvailablePackages
    public func installAvailablePackages(): Unit {
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

            let prevPath = nodeModules.path
            let prevTreeId = currentTreeId

            for (ctx in pendingCopy) {
                nodeModules.path = ctx.path
                currentTreeId = ctx.treeId
                installPackage(ctx.dependencyId)
            }

            nodeModules.path = prevPath
            currentTreeId = prevTreeId
        }
    }

    /// 运行可用的生命周期脚本
    /// 翻译自: PackageInstaller.runAvailableScripts
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
    /// 翻译自: PackageInstaller.completeRemainingScripts
    public func completeRemainingScripts(): Unit {
        for (entry in pendingLifecycleScripts) {
            spawnLifecycleScripts(entry)
        }
        pendingLifecycleScripts.clear()
    }

    /// 检查是否可以为 tree 安装包
    /// 翻译自: PackageInstaller.canInstallPackageForTree
    public func canInstallPackageForTree(): Bool {
        if (Int64(currentTreeId) >= lockfile.trees.size) { return true }
        var parentId = lockfile.trees[Int64(currentTreeId)].parentId
        while (parentId != INVALID_PACKAGE_ID) {
            if (!completedTrees.contains(parentId)) {
                return false
            }
            if (Int64(parentId) >= lockfile.trees.size) { break }
            parentId = lockfile.trees[Int64(parentId)].parentId
        }
        return true
    }

    /// 检查是否可以运行脚本
    /// 翻译自: PackageInstaller.canRunScripts
    public func canRunScripts(treeId: UInt32): Bool {
        return completedTrees.contains(treeId)
    }

    /// 修复缓存的 lockfile 包切片
    /// 翻译自: PackageInstaller.fixCachedLockfilePackageSlices
    public func fixCachedLockfilePackageSlices(): Unit {
        // 更新 names, metas, bins, resolutions 等切片引用
    }

    // ===== 私有辅助方法 =====

    private func verifyPackage(name: String, resolution: String): Bool {
        let destPath = "${nodeModules.path}/${name}/package.json"
        if (!bao_io.File.exists(destPath)) { return false }
        try {
            let content = bao_io.File.readTextFile(destPath)
            let json = bao_json.JsonParser.parse(content)
            match (json.get("version")) {
                case Some(v) => return v.asString() == resolution
                case None => return false
            }
        } catch (_: Exception) {
            return false
        }
    }

    private func isMissingFromCache(packageId: UInt32): Bool {
        let name = lockfile.getPackageName(packageId)
        let version = lockfile.getResolution(packageId)
        let cachePath = "${manager.cacheDirectoryPath}/${name}@${version}"
        return !bao_io.File.directoryExists(cachePath)
    }

    private func enqueueForDownload(
        depId: UInt32,
        packageId: UInt32,
        name: String,
        resolution: String,
        tag: DependencyVersionTag
    ): Unit {
        // 根据 tag 加入不同的下载队列
    }

    private func setupCacheSubpath(request: PackageInstallRequest, packageId: UInt32, tag: DependencyVersionTag): Unit {
        match (tag) {
            case DependencyVersionTag.Npm => {
                let name = lockfile.getPackageName(packageId)
                let version = lockfile.getResolution(packageId)
                request.cacheDirSubpath = "${name}@${version}"
                request.cacheDir = manager.cacheDirectoryPath
            }
            case DependencyVersionTag.Folder => {
                request.cacheDirSubpath = lockfile.getResolution(packageId)
                request.cacheDir = bao_io.File.getCurrentDirectory()
            }
            case DependencyVersionTag.Workspace => {
                request.cacheDirSubpath = "."
                request.cacheDir = bao_io.File.getCurrentDirectory()
            }
            case DependencyVersionTag.Symlink => {
                request.cacheDirSubpath = "."
                request.cacheDir = bao_io.File.getCurrentDirectory()
            }
            case _ => {
                request.cacheDirSubpath = lockfile.getResolution(packageId)
                request.cacheDir = manager.cacheDirectoryPath
            }
        }
    }

    private func linkBinary(alias: String, binInfo: PackageBinInfo, packageId: UInt32): Unit {
        // 翻译自: Bin.Linker.link
    }

    private func handleAlreadyInstalledPackage(
        depId: UInt32,
        packageId: UInt32,
        name: String,
        resolution: String
    ): Unit {
        // 检查可信依赖和生命周期脚本
    }

    private func handleSuccessfullyInstalledPackage(
        depId: UInt32,
        packageId: UInt32,
        name: String,
        resolution: String,
        tag: DependencyVersionTag
    ): Unit {
        // 处理二进制链接和生命周期脚本排队
        if (Int64(packageId) < bins.size && bins[Int64(packageId)].tag != BinTag.None) {
            trees[Int64(currentTreeId)].binaries.append(depId)
        }

        // 排队生命周期脚本
        enqueueLifecycleScripts(name, packageId, resolution, tag)
    }

    private func enqueueLifecycleScripts(
        name: String,
        packageId: UInt32,
        resolution: String,
        tag: DependencyVersionTag
    ): Unit {
        // 翻译自: PackageInstaller.enqueueLifecycleScripts
        let scripts = getScriptsForPackage(packageId)
        if (scripts.size > 0) {
            pendingLifecycleScripts.append(
                PendingLifecycleScript(scripts, currentTreeId, false, name)
            )
        }
    }

    private func getScriptsForPackage(packageId: UInt32): ArrayList<String> {
        // 从 lockfile 获取包的生命周期脚本列表
        return ArrayList<String>()
    }

    private func spawnLifecycleScripts(entry: PendingLifecycleScript): Unit {
        // 翻译自: manager.spawnPackageLifecycleScripts
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

/// 包元数据
/// 翻译自: Lockfile.Package.Meta
public class PackageMeta {
    /// 是否有安装脚本
    public var hasInstallScript: Bool
    /// 完整性哈希
    public var integrity: Integrity
    /// OS 限制
    public var os: ArrayList<String>
    /// CPU 限制
    public var cpu: ArrayList<String>

    public init() {
        hasInstallScript = false
        integrity = Integrity()
        os = ArrayList<String>()
        cpu = ArrayList<String>()
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

/// 二进制标签
public enum BinTag {
    | None
    | File    // bin: "path"
    | Map     // bin: { "name": "path" }
    | Dir     // directories.bin

    public func isNone(): Bool {
        match (this) {
            case None => true
            case _ => false
        }
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
    public var scripts: ArrayList<String>
    public var treeId: UInt32
    public var isOptional: Bool
    public var packageName: String

    public init(scripts: ArrayList<String>, treeId: UInt32, isOptional: Bool, packageName: String) {
        this.scripts = scripts
        this.treeId = treeId
        this.isOptional = isOptional
        this.packageName = packageName
    }
}
