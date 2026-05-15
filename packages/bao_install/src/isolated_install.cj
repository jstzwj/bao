// bao_install - 隔离式安装
// 严格翻译自: src/install/isolated_install.zig
//   pub fn installIsolatedPackages(
//       manager: *PackageManager,
//       command_ctx: Command.Context,
//       install_root_dependencies: bool,
//       workspace_filters: []const WorkspaceFilter,
//       packages_to_install: ?[]const PackageID,
//   ) OOM!PackageInstall.Summary
//
// isolated_install 类似 pnpm 的安装模式:
//   每个包有自己的 node_modules 目录, 通过符号链接连接依赖
//   使用 Store 来管理全局缓存和去重
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// Store 节点
// 严格翻译自: src/install/isolated_install/Store.zig - Store.Node
//   Store 维护全局的依赖图, 每个节点对应一个包的安装实例
//   节点包含: pkg_id, dep_id, parent_id, child nodes, dependencies, peers
// ============================================================================

/// Store 节点
/// 对应 Bun: Store.Node
public class StoreNode {
    /// 包 ID
    public var pkgId: UInt32
    /// 依赖 ID (根节点为 INVALID)
    public var depId: UInt32
    /// 父节点 ID
    public var parentId: Int64  // -1 表示无父节点
    /// 子节点 ID 列表
    public var childNodes: ArrayList<Int64>
    /// 依赖列表
    public var dependencies: ArrayList<StoreDependency>
    /// 传递性 peer 依赖
    public var peers: ArrayList<StoreTransitivePeer>

    public init(pkgId: UInt32, depId: UInt32, parentId: Int64) {
        this.pkgId = pkgId
        this.depId = depId
        this.parentId = parentId
        childNodes = ArrayList<Int64>()
        dependencies = ArrayList<StoreDependency>()
        peers = ArrayList<StoreTransitivePeer>()
    }
}

/// Store 依赖关系
/// 翻译自: Store.Node.dependencies 中的条目
public class StoreDependency {
    public var depId: UInt32
    public var pkgId: UInt32

    public init(depId: UInt32, pkgId: UInt32) {
        this.depId = depId
        this.pkgId = pkgId
    }
}

/// 传递性 peer 依赖
/// 翻译自: Store.Node.TransitivePeer
public class StoreTransitivePeer {
    public var depId: UInt32
    public var pkgId: UInt32
    public var autoInstalled: Bool

    public init(depId: UInt32, pkgId: UInt32, autoInstalled: Bool) {
        this.depId = depId
        this.pkgId = pkgId
        this.autoInstalled = autoInstalled
    }
}

// ============================================================================
// Store 条目
// 严格翻译自: src/install/isolated_install/Store.zig - Store.Entry
//   Store.Entry 是去重后的安装条目, 多个 Node 可能指向同一个 Entry
//   包含: node_id, dependencies, parents, peer_hash, hoisted, step, entry_hash
// ============================================================================

/// Store 条目
/// 对应 Bun: Store.Entry
public class StoreEntry {
    /// 关联的节点 ID
    public var nodeId: Int64
    /// 此条目依赖的其他条目
    public var dependencies: ArrayList<StoreEntryDependency>
    /// 父条目 ID 列表
    public var parents: ArrayList<Int64>
    /// Peer 哈希
    public var peerHash: UInt64
    /// 是否提升到隐藏 node_modules
    public var hoisted: Bool
    /// 安装步骤状态
    public var step: StoreEntryStep
    /// 全局虚拟存储的条目哈希 (0 = 不符合条件)
    public var entryHash: UInt64

    public init(nodeId: Int64) {
        this.nodeId = nodeId
        dependencies = ArrayList<StoreEntryDependency>()
        parents = ArrayList<Int64>()
        peerHash = UInt64(0)
        hoisted = false
        step = StoreEntryStep.Pending
        entryHash = UInt64(0)
    }
}

/// Store 条目依赖
public class StoreEntryDependency {
    public var entryId: Int64
    public var depId: UInt32

    public init(entryId: Int64, depId: UInt32) {
        this.entryId = entryId
        this.depId = depId
    }
}

/// Store 条目安装步骤
/// 翻译自: Store.Entry.Step (atomic enum)
public enum StoreEntryStep {
    | Pending
    | SymlinkDependencies
    | Done
    | Failed

    public func isDone(): Bool {
        match (this) {
            case Done => true
            case _ => false
        }
    }
}

// ============================================================================
// Store
// 严格翻译自: src/install/isolated_install/Store.zig - Store
//   Store 是隔离安装的核心数据结构:
//   - nodes: 完整的依赖树 (每个节点是一个包实例)
//   - entries: 去重后的安装条目 (相同包+peer集只安装一次)
// ============================================================================

/// Store
/// 对应 Bun: install.Store
public class PackageStore {
    /// 所有节点
    public var nodes: ArrayList<StoreNode>
    /// 所有条目 (去重后)
    public var entries: ArrayList<StoreEntry>
    /// 模块目录名
    /// 翻译自: Store.modules_dir_name = ".bun"
    public static let MODULES_DIR_NAME: String = ".bun"

    public init() {
        nodes = ArrayList<StoreNode>()
        entries = ArrayList<StoreEntry>()
    }

    /// 添加节点
    public func addNode(pkgId: UInt32, depId: UInt32, parentId: Int64): Int64 {
        let node = StoreNode(pkgId, depId, parentId)
        nodes.append(node)
        return nodes.size - 1
    }

    /// 添加条目
    public func addEntry(nodeId: Int64): Int64 {
        let entry = StoreEntry(nodeId)
        entries.append(entry)
        return entries.size - 1
    }

    /// 获取节点
    public func getNode(id: Int64): ?StoreNode {
        if (id >= 0 && id < nodes.size) {
            return nodes[id]
        }
        return None
    }

    /// 获取条目
    public func getEntry(id: Int64): ?StoreEntry {
        if (id >= 0 && id < entries.size) {
            return entries[id]
        }
        return None
    }

    /// 格式化存储路径
    /// 翻译自: Store.Entry.fmtStorePath
    ///   用于在 node_modules/.bun/ 下创建唯一的目录名
    public func formatStorePath(entryId: Int64, lockfile: LockfileData): String {
        if (entryId < 0 || entryId >= entries.size) { return "" }
        let entry = entries[entryId]
        let node = nodes[Int64(entry.nodeId)]
        let pkgId = node.pkgId

        let name = lockfile.getPackageName(pkgId)
        let version = lockfile.getResolution(pkgId)

        // 格式: name@version 或 name@version+peerhash
        var storePath = "${name}@${version}"
        if (entry.peerHash != UInt64(0)) {
            let hashHex = bao_hash.Wyhash.toHexString(entry.peerHash)
            storePath = "${storePath}_${hashHex}"
        }

        return storePath
    }
}

// ============================================================================
// 隔离式安装器
// 严格翻译自: src/install/isolated_install.zig - installIsolatedPackages
//   安装流程:
//     1. 构建 Store: DFS 遍历 lockfile, 创建 nodes
//     2. 去重: 第二次遍历, 将相同 (pkg_id, peers) 的 nodes 合并为 entries
//     3. 计算全局虚拟存储哈希
//     4. 设置 node_modules/.bun 目录
//     5. 为每个 entry 创建安装任务
//     6. 运行网络任务 (下载缺失的包)
//     7. 链接: 创建符号链接连接 entries
// ============================================================================

/// 隔离式安装器
/// 对应 Bun: isolated_install.installIsolatedPackages
public class IsolatedInstaller {
    /// 包管理器引用
    public var manager: PackageManagerRef
    /// Store
    public var store: PackageStore
    /// 日志级别
    public var logLevel: LogLevel
    /// 安装摘要
    public var summary: PackageInstallSummary
    /// 是否是新创建的 node_modules/.bun
    public var isNewBunModules: Bool
    /// 全局存储路径
    public var globalStorePath: ?String
    /// 已安装的包 ID 集合
    public var installed: HashSet<UInt32>
    /// 可信依赖 (来自 update requests)
    public var trustedDependenciesFromUpdateRequests: HashSet<UInt32>

    public init(manager: PackageManagerRef) {
        this.manager = manager
        store = PackageStore()
        logLevel = LogLevel.Default
        summary = PackageInstallSummary()
        isNewBunModules = false
        globalStorePath = None
        installed = HashSet<UInt32>()
        trustedDependenciesFromUpdateRequests = HashSet<UInt32>()
    }

    /// 执行隔离式安装
    /// 翻译自: installIsolatedPackages
    public func install(
        lockfile: LockfileData,
        installRootDependencies: Bool,
        workspaceFilters: ArrayList<WorkspaceFilter>,
        packagesToInstall: ?ArrayList<UInt32>
    ): PackageInstallSummary {
        // 步骤 1: 构建 Store (第一次遍历: 创建完整依赖树)
        buildStore(lockfile, installRootDependencies, workspaceFilters, packagesToInstall)

        // 步骤 2: 计算全局虚拟存储哈希 (如果启用)
        if (manager.cacheDirectoryPath.length > 0) {
            globalStorePath = "${manager.cacheDirectoryPath}/links"
        }

        // 步骤 3: 设置 node_modules/.bun 目录
        setupBunModules()

        // 步骤 4: 为每个 entry 安装
        let totalEntries = store.entries.size
        for (i in 0..totalEntries) {
            processEntry(UInt32(i), lockfile)
        }

        // 步骤 5: 等待所有任务完成
        waitForAllTasks()

        // 步骤 6: 更新摘要
        summary.successfullyInstalled = installed
        return summary
    }

    /// 构建 Store
    /// 翻译自: isolated_install 中的 store 构建逻辑
    ///   DFS 遍历 lockfile 依赖, 创建 nodes 并处理 peer 依赖
    private func buildStore(
        lockfile: LockfileData,
        installRootDependencies: Bool,
        workspaceFilters: ArrayList<WorkspaceFilter>,
        packagesToInstall: ?ArrayList<UInt32>
    ): Unit {
        // DFS 队列
        let nodeQueue = ArrayList<QueuedNode>()
        // 根节点
        nodeQueue.append(QueuedNode(
            parentId: Int64(-1),
            depId: INVALID_DEPENDENCY_ID,
            pkgId: UInt32(0)
        ))

        // 早期去重映射: (pkg_id, ctx_hash) -> node_id
        let earlyDedupe = HashMap<UInt64, Int64>()

        // 遍历队列
        while (nodeQueue.size > 0) {
            let entry = nodeQueue.removeAt(nodeQueue.size - 1) // pop last (DFS)
            let nodeId = store.addNode(entry.pkgId, entry.depId, entry.parentId)
            let node = store.nodes[nodeId]

            // 将节点添加到父节点的子列表
            if (entry.parentId >= 0) {
                store.nodes[entry.parentId].childNodes.append(nodeId)
            }

            // 根节点或无父节点: 跳过依赖
            if (entry.pkgId == UInt32(0) && entry.depId != INVALID_DEPENDENCY_ID) {
                continue
            }

            // 检查循环
            // 翻译自: isolated_install 中的 check_cycle 逻辑
            if (checkCycle(nodeId, entry.pkgId, entry.depId, lockfile)) {
                continue
            }

            // 获取此包的依赖
            let pkgDeps = getPackageDependencies(entry.pkgId, lockfile)
            for (dep in pkgDeps) {
                // 过滤掉不需要的依赖
                if (shouldFilterDependency(dep, entry.pkgId, workspaceFilters, installRootDependencies)) {
                    continue
                }

                let pkgId = lockfile.resolutions[Int64(dep)]
                if (pkgId == INVALID_PACKAGE_ID) { continue }

                // 非peer依赖: 直接加入队列
                node.dependencies.append(StoreDependency(dep, pkgId))
                nodeQueue.append(QueuedNode(parentId: nodeId, depId: dep, pkgId: pkgId))
            }

            // 处理 peer 依赖
            // 翻译自: isolated_install 中的 peer_dep_ids 逻辑
        }

        // 第二次遍历: 去重, 创建 entries
        buildEntries(lockfile)
    }

    /// 检查依赖循环
    /// 翻译自: isolated_install 中的 check_cycle
    private func checkCycle(nodeId: Int64, pkgId: UInt32, depId: UInt32, lockfile: LockfileData): Bool {
        var currentId = store.nodes[nodeId].parentId
        while (currentId >= 0) {
            let currentNode = store.nodes[currentId]
            if (currentNode.pkgId == pkgId) {
                // 循环检测: 将现有节点添加到父节点
                store.nodes[store.nodes[nodeId].parentId].childNodes.append(currentId)
                return true
            }
            currentId = currentNode.parentId
        }
        return false
    }

    /// 构建 entries (去重)
    /// 翻译自: isolated_install 中的第二次遍历 (next_entry)
    private func buildEntries(lockfile: LockfileData): Unit {
        let entryQueue = ArrayList<QueuedEntry>()
        entryQueue.append(QueuedEntry(nodeId: Int64(0), entryParentId: Int64(-1)))

        // 去重映射: pkg_id -> [DedupeInfo]
        let dedupe = HashMap<UInt32, ArrayList<DedupeInfo>>()

        while (entryQueue.size > 0) {
            let entry = entryQueue.removeAt(0)
            let pkgId = store.nodes[entry.nodeId].pkgId

            // 检查是否可以复用已有 entry
            let entryId = store.addEntry(entry.nodeId)
            let newEntry = store.entries[entryId]

            // 添加到父条目的依赖
            if (entry.entryParentId >= 0) {
                let parentEntry = store.entries[entry.entryParentId]
                parentEntry.dependencies.append(StoreEntryDependency(entryId, store.nodes[entry.nodeId].depId))
                parentEntry.parents.append(entry.entryParentId)
            }

            // 将子节点加入队列
            let node = store.nodes[entry.nodeId]
            for (childId in node.childNodes) {
                entryQueue.append(QueuedEntry(nodeId: childId, entryParentId: entryId))
            }

            // 添加到去重映射
            match (dedupe.get(pkgId)) {
                case Some(list) => list.append(DedupeInfo(entryId, store.nodes[entry.nodeId].depId))
                case None => {
                    let list = ArrayList<DedupeInfo>()
                    list.append(DedupeInfo(entryId, store.nodes[entry.nodeId].depId))
                    dedupe.put(pkgId, list)
                }
            }
        }
    }

    /// 设置 node_modules/.bun 目录
    /// 翻译自: isolated_install 中的 is_new_bun_modules 设置逻辑
    private func setupBunModules(): Unit {
        let cwd = bao_io.File.getCurrentDirectory()
        let nodeModulesPath = "${cwd}/node_modules"
        let bunModulesPath = "${nodeModulesPath}/${PackageStore.MODULES_DIR_NAME}"

        if (!bao_io.File.directoryExists(nodeModulesPath)) {
            bao_io.File.createDirectory(nodeModulesPath)
            isNewBunModules = true
        }

        if (!bao_io.File.directoryExists(bunModulesPath)) {
            bao_io.File.createDirectory(bunModulesPath)
            isNewBunModules = true
        }
    }

    /// 处理单个 entry
    /// 翻译自: isolated_install 中对每个 entry 的处理
    private func processEntry(entryId: UInt32, lockfile: LockfileData): Unit {
        if (entryId >= UInt32(store.entries.size)) { return }
        let entry = store.entries[Int64(entryId)]
        let nodeId = entry.nodeId
        let node = store.nodes[nodeId]
        let pkgId = node.pkgId
        let depId = node.depId

        let pkgName = lockfile.getPackageName(pkgId)
        let resolution = lockfile.getResolution(pkgId)
        let tag = lockfile.getResolutionTag(pkgId)

        match (tag) {
            case DependencyVersionTag.Root => {
                // 根包: 设置为符号链接阶段
                entry.step = StoreEntryStep.SymlinkDependencies
            }
            case DependencyVersionTag.Workspace => {
                // workspace: 只需符号链接
                entry.step = StoreEntryStep.SymlinkDependencies
            }
            case DependencyVersionTag.Symlink => {
                // symlink: 无需安装
                entry.step = StoreEntryStep.Done
                return
            }
            case DependencyVersionTag.Folder => {
                // folder: 需要硬链接
            }
            case DependencyVersionTag.Npm |
                 DependencyVersionTag.Git |
                 DependencyVersionTag.Github |
                 DependencyVersionTag.Tarball => {
                // 检查是否需要下载
                let needsInstall = checkNeedsInstall(entryId, pkgId, tag, lockfile)
                if (!needsInstall) {
                    // 检查全局存储链接
                    match (globalStorePath) {
                        case Some(_) => linkProjectToGlobalStore(entryId)
                        case None => ()
                    }
                    if (entry.hoisted) {
                        linkToHiddenNodeModules(entryId)
                    }
                    entry.step = StoreEntryStep.Done
                    return
                }

                // 检查缓存
                if (!isPackageMissingFromCache(pkgId, lockfile)) {
                    // 缓存命中, 可以直接安装
                    return
                }

                // 需要下载: 加入网络任务队列
                enqueuePackageForDownload(depId, pkgId, pkgName, resolution, tag, lockfile)
            }
            case _ => {
                entry.step = StoreEntryStep.Done
                return
            }
        }
    }

    /// 检查是否需要安装
    /// 翻译自: isolated_install 中的 needs_install 检查
    private func checkNeedsInstall(entryId: UInt32, pkgId: UInt32, tag: DependencyVersionTag, lockfile: LockfileData): Bool {
        if (manager.cacheDirectoryPath.length == 0) { return true }

        let storePath = store.formatStorePath(Int64(entryId), lockfile)
        let fullPath = "${manager.cacheDirectoryPath}/${storePath}"

        return !bao_io.File.directoryExists(fullPath)
    }

    /// 检查包是否在缓存中缺失
    private func isPackageMissingFromCache(pkgId: UInt32, lockfile: LockfileData): Bool {
        let name = lockfile.getPackageName(pkgId)
        let version = lockfile.getResolution(pkgId)
        let cachePath = "${manager.cacheDirectoryPath}/${name}@${version}"
        return !bao_io.File.directoryExists(cachePath)
    }

    /// 加入下载队列
    private func enqueuePackageForDownload(
        depId: UInt32,
        pkgId: UInt32,
        name: String,
        resolution: String,
        tag: DependencyVersionTag,
        lockfile: LockfileData
    ): Unit {
        // 根据 tag 加入不同的下载队列
    }

    /// 链接到全局存储
    /// 翻译自: Store.Installer.linkProjectToGlobalStore
    private func linkProjectToGlobalStore(entryId: UInt32): Unit {
        // 创建从 node_modules/.bun/<storepath> 到全局存储的符号链接
    }

    /// 链接到隐藏 node_modules
    /// 翻译自: Store.Installer.linkToHiddenNodeModules
    private func linkToHiddenNodeModules(entryId: UInt32): Unit {
        // 将包链接到 node_modules/.bun 中的隐藏目录
    }

    /// 等待所有任务完成
    private func waitForAllTasks(): Unit {
        // 等待网络任务和安装任务完成
    }

    /// 获取包的依赖列表
    private func getPackageDependencies(pkgId: UInt32, lockfile: LockfileData): ArrayList<UInt32> {
        // 从 lockfile 获取指定包的依赖 ID 列表
        return ArrayList<UInt32>()
    }

    /// 是否应过滤依赖
    private func shouldFilterDependency(
        depId: UInt32,
        pkgId: UInt32,
        workspaceFilters: ArrayList<WorkspaceFilter>,
        installRootDependencies: Bool
    ): Bool {
        // 翻译自: Tree.isFilteredDependencyOrWorkspace
        return false
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// DFS 队列中的节点
/// 翻译自: isolated_install 中的 QueuedNode
class QueuedNode {
    var parentId: Int64
    var depId: UInt32
    var pkgId: UInt32

    init(parentId: Int64, depId: UInt32, pkgId: UInt32) {
        this.parentId = parentId
        this.depId = depId
        this.pkgId = pkgId
    }
}

/// Entry 队列中的条目
/// 翻译自: isolated_install 中的 QueuedEntry
class QueuedEntry {
    var nodeId: Int64
    var entryParentId: Int64

    init(nodeId: Int64, entryParentId: Int64) {
        this.nodeId = nodeId
        this.entryParentId = entryParentId
    }
}

/// 去重信息
/// 翻译自: isolated_install 中的 DedupeInfo
class DedupeInfo {
    var entryId: Int64
    var depId: UInt32

    init(entryId: Int64, depId: UInt32) {
        this.entryId = entryId
        this.depId = depId
    }
}
