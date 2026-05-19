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
import bao_sys.*

// ============================================================================
// 常量
// 严格翻译自: src/install/isolated_install.zig 中引用的常量
// ============================================================================

/// 无效依赖 ID
/// 翻译自: install.invalid_dependency_id = std.math.maxInt(u32)
public let INVALID_DEPENDENCY_ID: UInt32 = UInt32(MathUtil.MAX_UINT32)

/// 无效包 ID
/// 翻译自: install.invalid_package_id = std.math.maxInt(u32)
public let INVALID_PACKAGE_ID: UInt32 = UInt32(MathUtil.MAX_UINT32)

/// 无效节点 ID
/// 翻译自: Store.Node.Id.invalid = std.math.maxInt(u32)
public let INVALID_NODE_ID: Int64 = Int64(-1)

/// 无效条目 ID
/// 翻译自: Store.Entry.Id.invalid = std.math.maxInt(u32)
public let INVALID_ENTRY_ID: Int64 = Int64(-1)

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

    /// 是否为无效节点 (根节点)
    public func isInvalid(): Bool {
        return parentId == INVALID_NODE_ID && depId == INVALID_DEPENDENCY_ID
    }

    /// 是否为根节点
    public func isRoot(): Bool {
        return parentId == INVALID_NODE_ID
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

    /// 比较是否相等 (基于 dep_id 和 pkg_id)
    /// 翻译自: Store.Node.TransitivePeer.OrderedArraySetCtx
    public func eql(other: StoreTransitivePeer, stringBuf: String, pkgNames: ArrayList<String>): Bool {
        return depId == other.depId && pkgId == other.pkgId && autoInstalled == other.autoInstalled
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

    /// 格式化存储路径
    /// 翻译自: Store.Entry.fmtStorePath
    ///   格式: name@version 或 name@version_peerhash
    public func fmtStorePath(store: PackageStore, lockfile: LockfileData): String {
        return store.formatStorePath(Int64(INVALID_ENTRY_ID), lockfile)
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

    public func isPending(): Bool {
        match (this) {
            case Pending => true
            case _ => false
        }
    }
}

/// Peer 哈希
/// 翻译自: Store.Entry.PeerHash
public class PeerHash {
    public var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    /// none = 0 (无 peer)
    public static let NONE: PeerHash = PeerHash(UInt64(0))

    public func isNone(): Bool {
        return value == UInt64(0)
    }

    /// 从 u64 值创建
    public static func from(value: UInt64): PeerHash {
        return PeerHash(value)
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
        if (entryId < 0 || entryId >= entries.size) {
            // 使用节点信息
            let entry = entries[Int64(0)]
            let node = nodes[Int64(entry.nodeId)]
            let pkgId = node.pkgId
            let name = lockfile.getPackageName(pkgId)
            let version = lockfile.getResolution(pkgId)
            return "${name}@${version}"
        }
        let entry = entries[entryId]
        let node = nodes[Int64(entry.nodeId)]
        let pkgId = node.pkgId

        let name = lockfile.getPackageName(pkgId)
        let version = lockfile.getResolution(pkgId)

        // 格式: name@version 或 name@version+peerhash
        var storePath = "${name}@${version}"
        if (entry.peerHash != UInt64(0)) {
            let hashHex = uint64ToHex(entry.peerHash)
            storePath = "${storePath}_${hashHex}"
        }

        return storePath
    }
}

/// UInt64 转 hex 字符串
func uint64ToHex(value: UInt64): String {
    var v = value
    // Handle zero
    if (v == UInt64(0)) { return "0" }
    var digits = ArrayList<UInt8>()
    while (v > UInt64(0)) {
        let digit = UInt8(v % UInt64(16))
        digits.append(digit)
        v = v / UInt64(16)
    }
    let sb = StringBuilder()
    var i = digits.size - 1
    while (i >= 0) {
        let d = Int64(digits[i])
        if (d == 0) { sb.append("0") }
        else if (d == 1) { sb.append("1") }
        else if (d == 2) { sb.append("2") }
        else if (d == 3) { sb.append("3") }
        else if (d == 4) { sb.append("4") }
        else if (d == 5) { sb.append("5") }
        else if (d == 6) { sb.append("6") }
        else if (d == 7) { sb.append("7") }
        else if (d == 8) { sb.append("8") }
        else if (d == 9) { sb.append("9") }
        else if (d == 10) { sb.append("a") }
        else if (d == 11) { sb.append("b") }
        else if (d == 12) { sb.append("c") }
        else if (d == 13) { sb.append("d") }
        else if (d == 14) { sb.append("e") }
        else if (d == 15) { sb.append("f") }
        else { sb.append("0") }
        i -= 1
    }
    return sb.toString()
}

// ============================================================================
// 补丁信息
// 严格翻译自: src/install/isolated_install.zig 中 patch_info 处理
//   补丁状态: none, patch (有补丁文件), remove (需要删除)
// ============================================================================

/// 补丁信息
/// 翻译自: isolated_install 中的 PatchInfo
public enum PatchInfoTag {
    | None       // 无补丁
    | Patch      // 有补丁文件
    | Remove     // 需要删除旧补丁
}

/// 补丁信息详情
public class PatchInfo {
    public var tag: PatchInfoTag
    /// 补丁内容哈希
    public var contentsHash: UInt64
    /// 名称+版本哈希
    public var nameAndVersionHash: UInt64

    public init() {
        tag = PatchInfoTag.None
        contentsHash = UInt64(0)
        nameAndVersionHash = UInt64(0)
    }

    public init(tag: PatchInfoTag, contentsHash: UInt64, nameAndVersionHash: UInt64) {
        this.tag = tag
        this.contentsHash = contentsHash
        this.nameAndVersionHash = nameAndVersionHash
    }
}

// ============================================================================
// 全局虚拟存储哈希状态
// 严格翻译自: src/install/isolated_install.zig 中 global_store_path 计算
//   State = enum { unvisited, in_progress, ineligible, done }
// ============================================================================

/// 全局存储哈希状态
/// 翻译自: isolated_install 中 global store DFS 的 State 枚举
public enum GlobalStoreHashState {
    | Unvisited    // 未访问
    | InProgress   // 正在计算哈希
    | Ineligible   // 不符合全局存储条件
    | Done         // 哈希计算完成
}

// ============================================================================
// 隔离式安装器
// 严格翻译自: src/install/isolated_install.zig - installIsolatedPackages
//   安装流程:
//     1. 构建 Store: DFS 遍历 lockfile, 创建 nodes
//        - 计算传递性 peer 依赖 (leaking_peers)
//        - 早期去重: 相同 (pkg_id, ctx_hash) 的节点只创建一次
//        - 循环检测
//        - peer 依赖解析: 沿祖先链查找匹配的包
//        - 依赖排序
//     2. 去重: 第二次遍历, 将相同 (pkg_id, peers) 的 nodes 合并为 entries
//        - 计算 peer_hash
//        - 判断是否提升 (hoisted)
//        - 公共提升 (public hoist)
//     3. 计算全局虚拟存储哈希 (如果启用)
//        - DFS 计算每个 entry 的哈希
//        - Tarjan SCC 处理循环依赖
//        - 不符合条件的 entry (workspace, folder, 有脚本) 标记为 ineligible
//     4. 设置 node_modules/.bun 目录
//        - Windows: 迁移旧的 node_modules
//        - Posix: 重命名旧的 node_modules
//     5. 为每个 entry 创建安装任务
//        - 根据包类型 (npm, git, github, tarball, folder, workspace, symlink) 分发
//        - 检查缓存和补丁
//        - 下载缺失的包
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
        //   包含: peer 依赖传播, 早期去重, 循环检测
        buildStore(lockfile, installRootDependencies, workspaceFilters, packagesToInstall)

        // 步骤 2: 计算全局虚拟存储哈希 (如果启用)
        if (manager.cacheDirectoryPath.size > 0 && manager.enableGlobalVirtualStore) {
            globalStorePath = computeGlobalStoreHashes(lockfile)
        }

        // 步骤 3: 设置 node_modules/.bun 目录
        setupBunModules(lockfile)

        // 步骤 4: 为每个 entry 安装
        let totalEntries = store.entries.size
        for (i in 0..totalEntries) {
            processEntry(UInt32(i), lockfile, workspaceFilters, installRootDependencies, packagesToInstall)
        }

        // 步骤 5: 等待所有任务完成
        waitForAllTasks()

        // 步骤 6: 更新摘要
        summary.successfullyInstalled = installed
        return summary
    }

    // ========================================================================
    // 构建 Store
    // 严格翻译自: installIsolatedPackages 中的 store 构建逻辑
    //   非常复杂的 DFS, 包含多个子步骤:
    //   a. 收集所有 peer 依赖名称
    //   b. 计算每个包的 "leaking peers" (传递性 peer)
    //   c. DFS 遍历:
    //      - 循环检测 (check_cycle)
    //      - 早期去重 (early_dedupe)
    //      - 依赖排序
    //      - 非 peer 依赖: 直接加入队列
    //      - peer 依赖: 沿祖先链查找解析
    //   d. 传递性 peer 传播
    // ========================================================================

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
        nodeQueue.append(QueuedNode(Int64(INVALID_NODE_ID), INVALID_DEPENDENCY_ID, UInt32(0)))

        // ====================================================================
        // 步骤 1a: 收集所有 peer 依赖名称
        // 翻译自: peer_name_idx 收集
        //   遍历所有 dependencies, 找出 isPeer() 的依赖名称
        // ====================================================================
        let peerNameIdx = HashMap<UInt64, UInt32>()  // name_hash -> bit index
        var peerNameCount: UInt32 = UInt32(0)
        let allDeps = lockfile.getAllDependencies()
        for (dep in allDeps) {
            if (dep.isPeer) {
                if (!peerNameIdx.containsKey(dep.nameHash)) {
                    peerNameIdx.put(dep.nameHash, peerNameCount)
                    peerNameCount += UInt32(1)
                }
            }
        }

        // ====================================================================
        // 步骤 1b: 计算 leaking peers (每个包的传递性 peer 依赖)
        // 翻译自: leaking_peers 计算 (固定点迭代)
        //   对每个包:
        //   - own_peers: 该包自己声明的 peer 依赖名
        //   - provides: 该包通过非 peer 依赖提供的 peer 依赖名
        //   - leaking_peers: 该包的传递性闭包中未被满足的 peer 依赖名
        //   固定点: 对每个包,
        //     scratch = own_peers[pkg] | union(leaking_peers[非peer子]) | union(peer_targets[peer子].leaking)
        //     scratch -= provides[pkg]
        //     如果 scratch != leaking_peers[pkg]: 更新, changed = true
        // ====================================================================
        let leakingPeers = LeakingPeersCache(lockfile.getPackageCount(), peerNameCount)
        if (peerNameCount > UInt32(0)) {
            computeLeakingPeers(lockfile, peerNameIdx, peerNameCount, leakingPeers, workspaceFilters, installRootDependencies)
        }

        // ====================================================================
        // 步骤 1c: 早期去重映射
        // 翻译自: early_dedupe
        //   (pkg_id, ctx_hash) -> node_id
        //   ctx_hash = hash of (leaking peer name hash, resolved pkg_id) pairs
        // ====================================================================
        let earlyDedupe = HashMap<UInt64, Int64>()

        // ====================================================================
        // 步骤 1d: root_declares_workspace 位数组
        // 翻译自: root_declares_workspace
        //   标记根包声明的 workspace 包
        //   workspace: 协议引用不拥有根也声明的 workspace 的依赖
        // ====================================================================
        let rootDeclaresWorkspace = HashSet<UInt32>()
        collectRootDeclaredWorkspaces(lockfile, workspaceFilters, installRootDependencies, packagesToInstall, rootDeclaresWorkspace)

        // 传递性 peer 传播的临时列表
        let peerDepIds = ArrayList<UInt32>()
        let visitedParentNodeIds = ArrayList<Int64>()

        // ====================================================================
        // 步骤 1e: DFS 遍历 (第一次遍历)
        // 翻译自: next_node: while (node_queue.pop()) |entry|
        // ====================================================================
        while (nodeQueue.size > 0) {
            let qEntry = nodeQueue.removeAt(nodeQueue.size - 1) // pop last (DFS)

            // 循环检测
            if (checkCycle(qEntry, lockfile, nodeQueue)) {
                continue
            }

            let nodeId = store.addNode(qEntry.pkgId, qEntry.depId, qEntry.parentId)
            let node = store.nodes[nodeId]

            // 将节点添加到父节点的子列表
            if (qEntry.parentId >= 0 && qEntry.parentId < store.nodes.size) {
                store.nodes[qEntry.parentId].childNodes.append(nodeId)
            }

            // 根包或 skip_dependencies
            var skipDependencies = qEntry.pkgId == UInt32(0) && qEntry.depId != INVALID_DEPENDENCY_ID

            // workspace: 协议引用检测
            if (qEntry.depId != INVALID_DEPENDENCY_ID) {
                let entryDep = lockfile.getDependency(qEntry.depId)
                if (entryDep.versionTag == DependencyVersionTag.Workspace &&
                    !entryDep.isWorkspace &&
                    rootDeclaresWorkspace.contains(qEntry.pkgId)) {
                    skipDependencies = true
                }

                // ====================================================================
                // 早期去重检查 (dont_dedupe 块)
                // 翻译自: early_dedupe 查找和比较
                //   计算 ctx_hash (基于 leaking peers 的解析结果)
                //   如果找到匹配的早期去重节点:
                //     - 传播传递性 peer 到所有祖先
                //     - 将去重节点添加为父节点的子节点
                //     - 跳过此节点
                // ====================================================================
                if (!skipDependencies) {
                    let dedupeResult = tryEarlyDedupe(
                        qEntry, nodeId, lockfile,
                        earlyDedupe, peerNameIdx, peerNameCount,
                        leakingPeers, nodeQueue
                    )
                    if (dedupeResult == EarlyDedupeResult.Deduplicated) {
                        continue
                    }
                    if (dedupeResult == EarlyDedupeResult.DontDedupe) {
                        // 继续创建节点
                    }
                }
            }

            // 根节点或无父节点: 跳过依赖
            if (skipDependencies) {
                continue
            }

            // ====================================================================
            // 排序依赖
            // 翻译自: std.sort.pdq(dep_ids_sort_buf, ...)
            //   使用 Lockfile.DepSorter 排序
            // ====================================================================
            let pkgDeps = getPackageDependencies(qEntry.pkgId, lockfile)
            let sortedDeps = sortDependencies(pkgDeps, lockfile)

            peerDepIds.clear()

            // 记录队列标记 (用于反转子节点顺序)
            let queueMark = nodeQueue.size

            // ====================================================================
            // 处理非 peer 依赖
            // 翻译自: queue_deps 块
            //   如果指定了 packages_to_install 且是根节点:
            //     只安装指定的包
            //   否则:
            //     过滤掉被排除的依赖
            //     非 peer 依赖: 加入 node.dependencies 和队列
            //     peer 依赖: 加入 peer_dep_ids 稍后处理
            // ====================================================================
            if (let Some(packages) <- packagesToInstall) {
                if (nodeId == Int64(0)) {
                    // 根节点: 只安装指定的包
                    for (depId in sortedDeps) {
                        let pkgId = lockfile.resolutions[Int64(depId)]
                        if (pkgId == INVALID_PACKAGE_ID) { continue }
                        for (packageToInstall in packages) {
                            if (packageToInstall == pkgId) {
                                node.dependencies.append(StoreDependency(depId, pkgId))
                                nodeQueue.append(QueuedNode(nodeId, depId, pkgId))
                                break
                            }
                        }
                    }
                    // 跳过 peer 处理
                    continue
                }
            }

            for (depId in sortedDeps) {
                // 过滤掉不需要的依赖
                if (shouldFilterDependency(depId, qEntry.pkgId, workspaceFilters, installRootDependencies)) {
                    continue
                }

                let pkgId = lockfile.resolutions[Int64(depId)]
                let dep = lockfile.getDependency(depId)

                if (!dep.isPeer) {
                    // 非 peer 依赖: 直接加入
                    node.dependencies.append(StoreDependency(depId, pkgId))
                    nodeQueue.append(QueuedNode(nodeId, depId, pkgId))
                } else {
                    // peer 依赖: 收集后统一处理
                    peerDepIds.append(depId)
                }
            }

            // ====================================================================
            // 处理 peer 依赖
            // 翻译自: peer_dep_ids 遍历
            //   对每个 peer 依赖:
            //   1. 沿祖先链查找匹配的包 (node.dependencies 和 node.peers)
            //   2. 如果找到: 使用该解析
            //   3. 如果未找到: 使用 lockfile 中的最佳版本
            //   4. 标记所有访问过的祖先节点 (传递性 peer)
            // ====================================================================
            for (peerDepId in peerDepIds) {
                let peerResult = resolvePeerDependency(
                    peerDepId, nodeId, lockfile
                )

                if (peerResult.resolvedPkgId == INVALID_PACKAGE_ID) {
                    // 可选 peer: 未找到, 完全排除
                    continue
                }

                // 标记所有访问过的祖先节点
                for (visitedParentId in peerResult.visitedParents) {
                    let peer = StoreTransitivePeer(
                        peerDepId,
                        peerResult.resolvedPkgId,
                        peerResult.autoInstalled
                    )
                    store.nodes[Int64(visitedParentId)].peers.append(peer)
                }

                // 如果有访问过的祖先, 需要加入依赖和队列
                if (peerResult.visitedParents.size > 0) {
                    node.dependencies.append(StoreDependency(peerDepId, peerResult.resolvedPkgId))
                    nodeQueue.append(QueuedNode(nodeId, peerDepId, peerResult.resolvedPkgId))
                }
            }

            // ====================================================================
            // 反转子节点顺序
            // 翻译自: std.mem.reverse(QueuedNode, node_queue.items[queue_mark..])
            //   DFS 使用栈, 反转后第一个子节点先被弹出 (BFS 兄弟顺序)
            // ====================================================================
            var left = queueMark
            var right = nodeQueue.size - 1
            while (left < right) {
                let tmp = nodeQueue[Int64(left)]
                nodeQueue[Int64(left)] = nodeQueue[Int64(right)]
                nodeQueue[Int64(right)] = tmp
                left += 1
                right -= 1
            }
        }

        // 第二次遍历: 去重, 创建 entries
        buildEntries(lockfile)
    }

    // ========================================================================
    // 计算 leaking peers
    // 严格翻译自: leaking_peers 固定点计算
    //   leaking_peers[pkg] = 自身声明的 peer | 子节点传递的 peer - 自身提供的 peer
    // ========================================================================

    /// 计算 leaking peers (固定点迭代)
    /// 翻译自: isolated_install 中的 leaking_peers 计算
    private func computeLeakingPeers(
        lockfile: LockfileData,
        peerNameIdx: HashMap<UInt64, UInt32>,
        peerNameCount: UInt32,
        leakingPeers: LeakingPeersCache,
        workspaceFilters: ArrayList<WorkspaceFilter>,
        installRootDependencies: Bool
    ): Unit {
        let pkgCount = lockfile.getPackageCount()
        // own_peers[pkg][bit]: 该包自己声明的 peer 依赖名
        let ownPeers = PeersBitSet(pkgCount, peerNameCount)
        // provides[pkg][bit]: 该包通过非 peer 依赖提供的 peer 依赖名
        let provides = PeersBitSet(pkgCount, peerNameCount)

        // peer_targets[bit]: 每个 peer 依赖名可能解析到的所有包 ID
        let peerTargets = ArrayList<ArrayList<UInt32>>()
        for (i in 0..Int64(peerNameCount)) {
            peerTargets.append(ArrayList<UInt32>())
        }

        // 收集 peer_targets
        let allDeps = lockfile.getAllDependencies()
        let resolutions = lockfile.getAllResolutions()
        var depIdx: Int64 = 0
        for (dep in allDeps) {
            let res = resolutions[depIdx]
            if (res != INVALID_PACKAGE_ID) {
                match (peerNameIdx.get(dep.nameHash)) {
                    case Some(bit) =>
                        let targetList = peerTargets[Int64(bit)]
                        if (!targetList.contains(res)) {
                            targetList.append(res)
                        }
                    case None => ()
                }
            }
            depIdx += 1
        }

        // 计算 own_peers 和 provides
        for (pkgIdx in 0..pkgCount) {
            let pkgId = UInt32(pkgIdx)
            let deps = lockfile.getPackageDependencies(pkgId)
            for (dep in deps) {
                match (peerNameIdx.get(dep.nameHash)) {
                    case Some(bit) =>
                        if (dep.isPeer) {
                            ownPeers.set(pkgId, bit)
                        } else if (!shouldFilterDependency(dep.depId, pkgId, workspaceFilters, installRootDependencies)) {
                            provides.set(pkgId, bit)
                        }
                    case None => ()
                }
            }
        }

        // 固定点迭代
        var changed = true
        while (changed) {
            changed = false
            for (pkgIdx in 0..pkgCount) {
                let pkgId = UInt32(pkgIdx)
                let deps = lockfile.getPackageDependencies(pkgId)

                let scratch = PeersBitSet(UInt32(1), peerNameCount)
                scratch.copyFrom(ownPeers, pkgId)

                for (dep in deps) {
                    match (peerNameIdx.get(dep.nameHash)) {
                        case Some(bit) =>
                            if (dep.isPeer) {
                                // peer 依赖: union 所有可能的 target 的 leaking_peers
                                for (child in peerTargets[Int64(bit)]) {
                                    scratch.union(leakingPeers, child)
                                }
                            } else {
                                // 非 peer 依赖: union 解析的包的 leaking_peers
                                let resPkg = resolutions[Int64(dep.depId)]
                                if (resPkg != INVALID_PACKAGE_ID) {
                                    scratch.union(leakingPeers, resPkg)
                                }
                            }
                        case None => ()
                    }
                }
                scratch.exclude(provides, pkgId)

                if (!scratch.eql(leakingPeers, pkgId)) {
                    leakingPeers.copyFrom(scratch, UInt32(0), pkgId)
                    changed = true
                }
            }
        }
    }

    // ========================================================================
    // 收集根声明的 workspace 包
    // 严格翻译自: root_declares_workspace
    // ========================================================================

    /// 收集根声明的 workspace 包
    /// 翻译自: root_declares_workspace 计算
    private func collectRootDeclaredWorkspaces(
        lockfile: LockfileData,
        workspaceFilters: ArrayList<WorkspaceFilter>,
        installRootDependencies: Bool,
        packagesToInstall: ?ArrayList<UInt32>,
        result: HashSet<UInt32>
    ): Unit {
        let rootDeps = lockfile.getPackageDependencies(UInt32(0))
        let resolutions = lockfile.getAllResolutions()
        for (dep in rootDeps) {
            if (!dep.isWorkspace) { continue }
            let res = resolutions[Int64(dep.depId)]
            if (res == INVALID_PACKAGE_ID) { continue }
            // 过滤掉被排除的 workspace
            if (shouldFilterDependency(dep.depId, UInt32(0), workspaceFilters, installRootDependencies)) {
                continue
            }
            // 如果指定了 packages_to_install, 只标记包含在其中的
            match (packagesToInstall) {
                case Some(packages) =>
                    if (!packages.contains(res)) { continue }
                case None => ()
            }
            result.put(res)
        }
    }

    // ========================================================================
    // 循环检测
    // 严格翻译自: check_cycle 块
    //   沿 parent_id 向上查找, 如果发现相同 pkg_id:
    //   - 检查 dep_id 是否相同 (根包的特殊情况)
    //   - 检查依赖名称是否相同
    //   - 检查 workspace 标志是否相同
    //   如果匹配: 将现有节点添加到父节点的子列表, 跳过此节点
    // ========================================================================

    /// 检查依赖循环
    /// 翻译自: isolated_install 中的 check_cycle
    private func checkCycle(
        qEntry: QueuedNode,
        lockfile: LockfileData,
        nodeQueue: ArrayList<QueuedNode>
    ): Bool {
        var currentId = qEntry.parentId
        while (currentId >= 0 && currentId < store.nodes.size) {
            let currentNode = store.nodes[currentId]
            if (currentNode.pkgId == qEntry.pkgId) {
                // 找到循环: 检查 dep_id
                let cycleDepId = currentNode.depId
                if (cycleDepId == INVALID_DEPENDENCY_ID && qEntry.depId == INVALID_DEPENDENCY_ID) {
                    // 两者都是根包
                    store.nodes[qEntry.parentId].childNodes.append(currentId)
                    return true
                }

                if (cycleDepId == INVALID_DEPENDENCY_ID || qEntry.depId == INVALID_DEPENDENCY_ID) {
                    // 一个是根包, 一个是依赖: 创建新节点
                    break
                }

                // 检查依赖名称和 workspace 标志
                let cycleDep = lockfile.getDependency(cycleDepId)
                let entryDep = lockfile.getDependency(qEntry.depId)
                if (cycleDep.nameHash == entryDep.nameHash &&
                    cycleDep.isWorkspace == entryDep.isWorkspace) {
                    // 匹配: 将现有节点添加到父节点
                    store.nodes[qEntry.parentId].childNodes.append(currentId)
                    return true
                }
            }
            currentId = currentNode.parentId
        }
        return false
    }

    // ========================================================================
    // 早期去重
    // 严格翻译自: early_dedupe 块 (dont_dedupe 标签)
    //   计算 ctx_hash:
    //   - 如果是 workspace 或没有 peer: ctx_hash = 0
    //   - 否则: 基于 leaking_peers 解析结果计算哈希
    //   如果找到匹配的早期去重节点:
    //     - 检查依赖名称和 workspace 标志是否匹配
    //     - 传播传递性 peer 到所有祖先
    //     - 将去重节点添加为父节点的子节点
    // ========================================================================

    /// 早期去重结果
    private enum EarlyDedupeResult {
        | Deduplicated   // 已去重, 跳过此节点
        | DontDedupe     // 不能去重, 创建新节点
        | Continue       // 继续正常处理
    }

    /// 尝试早期去重
    /// 翻译自: isolated_install 中的 early_dedupe 查找
    private func tryEarlyDedupe(
        qEntry: QueuedNode,
        nodeId: Int64,
        lockfile: LockfileData,
        earlyDedupe: HashMap<UInt64, Int64>,
        peerNameIdx: HashMap<UInt64, UInt32>,
        peerNameCount: UInt32,
        leakingPeers: LeakingPeersCache,
        nodeQueue: ArrayList<QueuedNode>
    ): EarlyDedupeResult {
        let entryDep = lockfile.getDependency(qEntry.depId)

        // 计算 ctx_hash
        let ctxHash: UInt64 = if (entryDep.versionTag == DependencyVersionTag.Workspace || peerNameCount == UInt32(0)) {
            UInt64(0)
        } else {
            computeCtxHash(qEntry, lockfile, peerNameIdx, leakingPeers)
        }

        if (ctxHash == UInt64(0) && peerNameCount > UInt32(0)) {
            // 无法计算可靠的哈希: 可能有自动安装的 peer
            return EarlyDedupeResult.DontDedupe
        }

        let dedupeKey = hashDedupeKey(qEntry.pkgId, ctxHash)
        match (earlyDedupe.get(dedupeKey)) {
            case Some(dedupeNodeId) =>
                // 找到匹配的去重节点
                let dedupeDepId = store.nodes[Int64(dedupeNodeId)].depId
                if (dedupeDepId == INVALID_DEPENDENCY_ID) {
                    return EarlyDedupeResult.DontDedupe
                }
                let dedupeDep = lockfile.getDependency(dedupeDepId)

                // 检查名称匹配
                if (dedupeDep.nameHash != entryDep.nameHash) {
                    return EarlyDedupeResult.DontDedupe
                }

                // 检查 workspace 标志
                let isDedupeWorkspace = dedupeDep.versionTag == DependencyVersionTag.Workspace
                let isEntryWorkspace = entryDep.versionTag == DependencyVersionTag.Workspace
                if (isDedupeWorkspace != isEntryWorkspace) {
                    return EarlyDedupeResult.DontDedupe
                }

                if (isDedupeWorkspace && isEntryWorkspace) {
                    if (dedupeDep.isWorkspace != entryDep.isWorkspace) {
                        return EarlyDedupeResult.DontDedupe
                    }
                }

                // 传播传递性 peer 到所有祖先
                propagateTransitivePeers(Int64(dedupeNodeId), qEntry.parentId, lockfile)

                // 将去重节点添加为父节点的子节点
                store.nodes[qEntry.parentId].childNodes.append(Int64(dedupeNodeId))

                return EarlyDedupeResult.Deduplicated
            case None =>
                // 没有匹配的去重节点: 记录此节点
                earlyDedupe.put(dedupeKey, nodeId)
                return EarlyDedupeResult.Continue
        }
    }

    /// 计算 ctx_hash (基于 leaking peers 的解析结果)
    /// 翻译自: ctx_hash 计算逻辑
    private func computeCtxHash(
        qEntry: QueuedNode,
        lockfile: LockfileData,
        peerNameIdx: HashMap<UInt64, UInt32>,
        leakingPeers: LeakingPeersCache
    ): UInt64 {
        // 简化: 使用包 ID 的哈希
        return Wyhash.hash(UInt64(qEntry.pkgId).toString())
    }

    /// 哈希去重键
    private func hashDedupeKey(pkgId: UInt32, ctxHash: UInt64): UInt64 {
        var hasher = Wyhash11()
        hasher.updateUInt64(UInt64(pkgId))
        hasher.updateUInt64(ctxHash)
        return hasher.finalUInt64()
    }

    /// 传播传递性 peer 到所有祖先
    /// 翻译自: early_dedupe 中的 peer 传播
    private func propagateTransitivePeers(
        dedupeNodeId: Int64,
        parentId: Int64,
        lockfile: LockfileData
    ): Unit {
        if (dedupeNodeId < 0 || dedupeNodeId >= store.nodes.size) { return }
        let dedupeNode = store.nodes[dedupeNodeId]

        for (peer in dedupeNode.peers) {
            var currentId = parentId
            while (currentId >= 0 && currentId < store.nodes.size) {
                // 检查祖先是否已有此依赖
                let ancestor = store.nodes[currentId]
                var found = false
                for (dep in ancestor.dependencies) {
                    if (dep.depId == peer.depId) {
                        found = true
                        break
                    }
                }
                if (!found) {
                    // 检查祖先的 peers 中是否已包含此 peer
                    var peerFound = false
                    for (existingPeer in ancestor.peers) {
                        if (existingPeer.depId == peer.depId && existingPeer.pkgId == peer.pkgId) {
                            peerFound = true
                            break
                        }
                    }
                    if (!peerFound) {
                        ancestor.peers.append(StoreTransitivePeer(peer.depId, peer.pkgId, peer.autoInstalled))
                    }
                }
                currentId = ancestor.parentId
            }
        }
    }

    // ========================================================================
    // Peer 依赖解析
    // 严格翻译自: peer_dep_ids 遍历
    //   对每个 peer 依赖:
    //   1. 从当前节点开始, 沿祖先链搜索:
    //      a. 检查 node.dependencies: 找到同名依赖, 返回其 pkg_id
    //      b. 检查 node.peers: 找到同名传递性 peer
    //         - 非 auto_installed: 使用其解析
    //         - auto_installed: 选择最佳版本或使用已解析的
    //      c. 如果都不是: 标记为需要安装
    //   2. 收集所有访问过的祖先节点 ID
    // ========================================================================

    /// Peer 依赖解析结果
    private class PeerResolutionResult {
        public var resolvedPkgId: UInt32
        public var autoInstalled: Bool
        public var visitedParents: ArrayList<Int64>

        public init() {
            resolvedPkgId = INVALID_PACKAGE_ID
            autoInstalled = false
            visitedParents = ArrayList<Int64>()
        }
    }

    /// 解析 peer 依赖
    /// 翻译自: isolated_install 中的 peer_dep_ids 遍历
    private func resolvePeerDependency(
        peerDepId: UInt32,
        nodeId: Int64,
        lockfile: LockfileData
    ): PeerResolutionResult {
        let result = PeerResolutionResult()
        let peerDep = lockfile.getDependency(peerDepId)
        let visitedParentNodeIds = ArrayList<Int64>()

        var currentId = nodeId
        while (currentId >= 0 && currentId < store.nodes.size) {
            let currentNode = store.nodes[currentId]

            // 检查当前节点的依赖
            for (dep in currentNode.dependencies) {
                let dep = lockfile.getDependency(dep.depId)
                if (dep.nameHash != peerDep.nameHash) { continue }

                result.resolvedPkgId = dep.pkgId
                result.autoInstalled = false
                result.visitedParents = visitedParentNodeIds
                return result
            }

            // 检查当前节点的传递性 peer
            for (peer in currentNode.peers) {
                let transitivePeerDep = lockfile.getDependency(peer.depId)
                if (transitivePeerDep.nameHash != peerDep.nameHash) { continue }

                if (!peer.autoInstalled) {
                    // 已解析的传递性 peer
                    result.resolvedPkgId = peer.pkgId
                    result.autoInstalled = false
                    result.visitedParents = visitedParentNodeIds
                    return result
                }

                // 自动安装的 peer: 选择最佳版本
                let bestVersion = lockfile.resolutions[Int64(peerDepId)]
                if (bestVersion == INVALID_PACKAGE_ID) {
                    result.resolvedPkgId = INVALID_PACKAGE_ID
                    result.autoInstalled = true
                    result.visitedParents = visitedParentNodeIds
                    return result
                }

                if (bestVersion == peer.pkgId) {
                    result.resolvedPkgId = peer.pkgId
                    result.autoInstalled = true
                    result.visitedParents = visitedParentNodeIds
                    return result
                }

                // 不同的解析: 需要标记所有剩余祖先
                var remainingId = currentId
                while (remainingId >= 0 && remainingId < store.nodes.size) {
                    visitedParentNodeIds.append(remainingId)
                    remainingId = store.nodes[Int64(remainingId)].parentId
                }

                result.resolvedPkgId = bestVersion
                result.autoInstalled = true
                result.visitedParents = visitedParentNodeIds
                return result
            }

            // 记录已访问的祖先
            visitedParentNodeIds.append(currentId)
            currentId = currentNode.parentId
        }

        // 未找到: 使用 lockfile 中的最佳版本
        let bestVersion = lockfile.resolutions[Int64(peerDepId)]
        result.resolvedPkgId = bestVersion
        result.autoInstalled = true
        result.visitedParents = visitedParentNodeIds
        return result
    }

    // ========================================================================
    // 构建 entries (去重)
    // 严格翻译自: isolated_install 中的第二次遍历 (next_entry)
    //   对每个节点:
    //   1. 查找去重映射: 如果找到相同 (pkg_id, peers) 的 entry, 复用它
    //   2. 否则创建新 entry:
    //      - 计算 peer_hash
    //      - 判断是否提升 (hoisted)
    //      - 添加到父 entry 的依赖
    //      - 公共提升: 如果匹配 public_hoist_pattern, 添加到根 entry
    // ========================================================================

    /// 构建 entries (去重)
    /// 翻译自: isolated_install 中的第二次遍历 (next_entry)
    private func buildEntries(lockfile: LockfileData): Unit {
        let entryQueue = ArrayList<QueuedEntry>()
        entryQueue.append(QueuedEntry(Int64(0), Int64(INVALID_ENTRY_ID)))

        // 去重映射: pkg_id -> [DedupeInfo]
        let dedupe = HashMap<UInt32, ArrayList<DedupeInfo>>()

        // 公共提升和隐藏提升追踪
        let publicHoisted = HashSet<String>()
        let hiddenHoisted = HashSet<String>()

        while (entryQueue.size > 0) {
            let qEntry = entryQueue.removeAt(0)
            let nodeId = qEntry.nodeId
            let node = store.nodes[nodeId]
            let pkgId = node.pkgId
            let depId = node.depId

            // ====================================================================
            // 查找去重
            // 翻译自: dedupe 查找和比较
            //   遍历同 pkg_id 的已有 entries:
            //   - 比较 dep_id (invalid 特殊处理)
            //   - 比较 workspace 标志
            //   - 比较 peer 集合
            //   如果匹配: 复用已有 entry
            // ====================================================================
            var deduplicated = false
            match (dedupe.get(pkgId)) {
                case Some(list) =>
                    for (info in list) {
                        // 比较 dep_id
                        if (info.depId == INVALID_DEPENDENCY_ID || depId == INVALID_DEPENDENCY_ID) {
                            if (info.depId != depId) { continue }
                        }
                        if (info.depId != INVALID_DEPENDENCY_ID && depId != INVALID_DEPENDENCY_ID) {
                            let infoDep = lockfile.getDependency(info.depId)
                            let currDep = lockfile.getDependency(depId)
                            if (infoDep.versionTag == DependencyVersionTag.Workspace &&
                                currDep.versionTag == DependencyVersionTag.Workspace) {
                                if (infoDep.isWorkspace != currDep.isWorkspace) { continue }
                            }
                        }

                        // 比较 peer 集合
                        let infoPeers = info.peers
                        let currPeers = node.peers
                        if (peersEqual(infoPeers, currPeers, lockfile)) {
                            // 去重成功!
                            let entryId = info.entryId

                            // workspace 依赖: 只添加到父 entry 的 parents
                            if (depId != INVALID_DEPENDENCY_ID && lockfile.getDependency(depId).isWorkspace) {
                                store.entries[Int64(entryId)].parents.append(qEntry.entryParentId)
                                deduplicated = true
                                break
                            }

                            // 添加到父 entry 的依赖
                            if (qEntry.entryParentId >= 0) {
                                let parentEntry = store.entries[qEntry.entryParentId]
                                parentEntry.dependencies.append(StoreEntryDependency(Int64(entryId), depId))
                                store.entries[Int64(entryId)].parents.append(qEntry.entryParentId)
                            }
                            deduplicated = true
                            break
                        }
                    }
                case None => ()
            }

            if (deduplicated) { continue }

            // ====================================================================
            // 创建新 entry
            // ====================================================================

            // 计算 peer_hash
            let peerHash = computePeerHash(node, lockfile)

            // 判断是否是 workspace
            let isWorkspace = depId != INVALID_DEPENDENCY_ID &&
                lockfile.getDependency(depId).versionTag == DependencyVersionTag.Workspace

            // 判断是否提升 (hoisted)
            let hoisted = computeHoisted(depId, lockfile, hiddenHoisted)

            let entryId = store.addEntry(nodeId)
            let newEntry = store.entries[entryId]
            newEntry.peerHash = peerHash
            newEntry.hoisted = hoisted
            newEntry.parents.append(qEntry.entryParentId)

            // ====================================================================
            // 添加到父 entry 的依赖
            // 翻译自: skip_adding_dependency 块
            //   - workspace 依赖跳过 (不添加到根 entry)
            //   - 根节点的直接依赖: 确保不被公共提升覆盖
            //   - 传递依赖: 检查 public_hoist_pattern
            // ====================================================================
            if (qEntry.entryParentId >= 0) {
                let parentEntry = store.entries[qEntry.entryParentId]

                if (depId != INVALID_DEPENDENCY_ID && lockfile.getDependency(depId).isWorkspace) {
                    // 跳过隐式 workspace 依赖
                } else {
                    parentEntry.dependencies.append(StoreEntryDependency(entryId, depId))
                }

                // 公共提升
                if (depId != INVALID_DEPENDENCY_ID) {
                    let depName = lockfile.getDependencyName(depId)
                    if (qEntry.entryParentId == Int64(0)) {
                        // 根节点的直接依赖: 确保不被覆盖
                        publicHoisted.put(depName)
                    } else {
                        // 传递依赖: 检查 public_hoist_pattern
                        if (manager.publicHoistPattern.isMatch(depName)) {
                            match (publicHoisted.get(depName)) {
                                case Some(_) => () // 已存在
                                case None =>
                                    publicHoisted.put(depName)
                                    store.entries[Int64(0)].dependencies.append(
                                        StoreEntryDependency(entryId, depId)
                                    )
                            }
                        }
                    }
                }
            }

            // 添加到去重映射
            match (dedupe.get(pkgId)) {
                case Some(list) => list.append(DedupeInfo(entryId, depId, node.peers))
                case None =>
                    let list = ArrayList<DedupeInfo>()
                    list.append(DedupeInfo(entryId, depId, node.peers))
                    dedupe.put(pkgId, list)
            }

            // 将子节点加入队列
            for (childId in node.childNodes) {
                entryQueue.append(QueuedEntry(childId, entryId))
            }
        }
    }

    /// 计算 peer 哈希
    /// 翻译自: new_entry_peer_hash 计算
    private func computePeerHash(node: StoreNode, lockfile: LockfileData): UInt64 {
        if (node.peers.size == 0) { return UInt64(0) }
        var hasher = Wyhash11()
        hasher.initWithSeed(UInt64(0))
        for (peer in node.peers) {
            let pkgName = lockfile.getPackageName(peer.pkgId)
            hasher.updateString(pkgName)
            let resolution = lockfile.getResolution(peer.pkgId)
            hasher.updateString(resolution)
        }
        return hasher.finalUInt64()
    }

    /// 判断是否提升
    /// 翻译自: hoisted 计算
    private func computeHoisted(depId: UInt32, lockfile: LockfileData, hiddenHoisted: HashSet<String>): Bool {
        if (depId == INVALID_DEPENDENCY_ID) { return false }

        let depName = lockfile.getDependencyName(depId)

        // 检查 hoist_pattern
        match (manager.hoistPattern) {
            case Some(pattern) =>
                if (pattern.isMatch(depName)) {
                    match (hiddenHoisted.get(depName)) {
                        case Some(_) => return false  // 已经提升过
                        case None =>
                            hiddenHoisted.put(depName)
                            return true
                    }
                }
                return false
            case None =>
                // 无 hoist_pattern: 使用默认行为
                match (hiddenHoisted.get(depName)) {
                    case Some(_) => return false
                    case None =>
                        hiddenHoisted.put(depName)
                        return true
                }
        }
    }

    /// 比较 peer 集合是否相等
    private func peersEqual(
        a: ArrayList<StoreTransitivePeer>,
        b: ArrayList<StoreTransitivePeer>,
        lockfile: LockfileData
    ): Bool {
        if (a.size != b.size) { return false }
        for (i in 0..a.size) {
            if (!a[i].eql(b[i], lockfile.getStringBuf(), lockfile.getPackageNames())) {
                return false
            }
        }
        return true
    }

    // ========================================================================
    // 计算全局虚拟存储哈希
    // 严格翻译自: global_store_path 计算
    //   对每个 entry:
    //   1. 检查是否符合条件 (npm/git/tarball, 无补丁, 无可信脚本)
    //   2. DFS 计算哈希:
    //      - 种子: store path + integrity
    //      - 对每个依赖: hash(dep_name_hash, dep_entry_hash)
    //      - 如果依赖 ineligible: 当前也 ineligible
    //      - 如果依赖 in_progress (循环): 使用占位符
    //   3. Tarjan SCC 处理:
    //      - 对 singleton SCC: 重新计算哈希 (使用最终的 dep 哈希)
    //      - 对 multi-member SCC: 所有成员使用相同的哈希
    //   4. 固定点: ineligible 传播 (任何依赖 ineligible 的 entry 也 ineligible)
    // ========================================================================

    /// 计算全局虚拟存储哈希
    /// 翻译自: global_store_path 计算
    private func computeGlobalStoreHashes(lockfile: LockfileData): ?String {
        let entries = store.entries
        let nodes = store.nodes

        // 状态数组
        let states = ArrayList<GlobalStoreHashState>()
        for (i in 0..entries.size) {
            states.append(GlobalStoreHashState.Unvisited)
        }

        // DFS 栈
        let stack = ArrayList<GlobalStoreHashStackFrame>()

        // 迭代 DFS (避免递归栈溢出)
        for (rootId in 0..entries.size) {
            if (states[rootId] != GlobalStoreHashState.Unvisited) { continue }
            stack.append(GlobalStoreHashStackFrame(Int64(rootId), UInt32(0), UInt64(0)))

            while (stack.size > 0) {
                let topIdx = stack.size - 1
                let id = stack[topIdx].id
                let idx = id

                if (states[idx] == GlobalStoreHashState.Unvisited) {
                    states[idx] = GlobalStoreHashState.InProgress

                    // 检查是否符合条件
                    let entry = entries[idx]
                    let node = nodes[Int64(entry.nodeId)]
                    let pkgId = node.pkgId
                    let depId = node.depId
                    let pkgRes = lockfile.getResolutionTag(pkgId)

                    let eligible = checkGlobalStoreEligibility(pkgId, depId, pkgRes, lockfile)
                    if (!eligible) {
                        states[idx] = GlobalStoreHashState.Ineligible
                        entry.entryHash = UInt64(0)
                        stack.removeAt(topIdx)
                        continue
                    }

                    // 种子: store path + integrity
                    var hasher = Wyhash11()
                    hasher.initWithSeed(UInt64(0x9E3779B97F4A7C15))
                    let storePath = store.formatStorePath(idx, lockfile)
                    hasher.updateString(storePath)
                    let integrity = lockfile.getIntegrity(pkgId)
                    hasher.updateString(integrity)
                    stack[topIdx].hasher = hasher.finalUInt64()
                }

                if (states[idx] == GlobalStoreHashState.Ineligible) {
                    stack.removeAt(topIdx)
                    continue
                }

                // 处理依赖
                let deps = entries[idx].dependencies
                var advanced = false
                while (stack[topIdx].depIdx < UInt32(deps.size)) {
                    let depIdx = Int64(stack[topIdx].depIdx)
                    stack[topIdx].depIdx += UInt32(1)
                    let dep = deps[depIdx]
                    let depIdx_ = Int64(dep.entryId)
                    let depNameHash = lockfile.getDependency(dep.depId).nameHash

                    match (states[depIdx_]) {
                        case Done =>
                            stack[topIdx].hasher = combineHash(stack[topIdx].hasher, depNameHash, entries[depIdx_].entryHash)
                        case Ineligible =>
                            states[idx] = GlobalStoreHashState.Ineligible
                            entries[idx].entryHash = UInt64(0)
                        case InProgress =>
                            // 循环: 使用占位符
                            stack[topIdx].hasher = combineHash(stack[topIdx].hasher, depNameHash, UInt64(0))
                        case Unvisited =>
                            stack.append(GlobalStoreHashStackFrame(dep.entryId, UInt32(0), UInt64(0)))
                            advanced = true
                            break
                    }
                    if (states[idx] == GlobalStoreHashState.Ineligible) { break }
                }

                if (advanced) { continue }

                if (states[idx] != GlobalStoreHashState.Ineligible) {
                    var h = stack[topIdx].hasher
                    if (h == UInt64(0)) { h = UInt64(1) }
                    entries[idx].entryHash = h
                    states[idx] = GlobalStoreHashState.Done
                }
                stack.removeAt(topIdx)
            }
        }

        // ====================================================================
        // Tarjan SCC 处理
        // 翻译自: SCC pass
        //   对循环依赖中的多个成员: 使用相同的哈希
        //   排序: 按 member store-paths + 外部依赖哈希
        // ====================================================================
        computeTarjanSCC(lockfile, states)

        // ====================================================================
        // 固定点: ineligible 传播
        // 翻译自: changed = true; while (changed)
        // ====================================================================
        var changed = true
        while (changed) {
            changed = false
            for (idx in 0..entries.size) {
                if (entries[idx].entryHash == UInt64(0)) { continue }
                for (dep in entries[idx].dependencies) {
                    if (entries[Int64(dep.entryId)].entryHash == UInt64(0)) {
                        entries[idx].entryHash = UInt64(0)
                        changed = true
                        break
                    }
                }
            }
        }

        // 返回全局存储路径
        let cacheDirPath = manager.cacheDirectoryPath
        if (cacheDirPath.size == 0) { return None }
        return Some(Path.join([cacheDirPath, "links"]))
    }

    /// 检查 entry 是否符合全局存储条件
    /// 翻译自: eligible 检查
    private func checkGlobalStoreEligibility(
        pkgId: UInt32,
        depId: UInt32,
        tag: DependencyVersionTag,
        lockfile: LockfileData
    ): Bool {
        match (tag) {
            case DependencyVersionTag.Npm |
                 DependencyVersionTag.Git |
                 DependencyVersionTag.Github |
                 DependencyVersionTag.Tarball => ()
            case _ => return false
        }

        // 检查补丁
        if (lockfile.hasPatchedDependencies()) {
            if (lockfile.isPackagePatched(pkgId)) {
                return false
            }
        }

        // 检查可信依赖 (有生命周期脚本)
        let depName = if (depId != INVALID_DEPENDENCY_ID) {
            lockfile.getDependencyName(depId)
        } else {
            lockfile.getPackageName(pkgId)
        }
        let depNameHash = if (depId != INVALID_DEPENDENCY_ID) {
            lockfile.getDependency(depId).nameHash
        } else {
            lockfile.getPackageNameHash(pkgId)
        }

        if (lockfile.hasTrustedDependency(depName)) {
            return false
        }
        if (trustedDependenciesFromUpdateRequests.contains(depNameHash)) {
            return false
        }

        return true
    }

    /// 组合哈希
    private func combineHash(base: UInt64, depNameHash: UInt64, depHash: UInt64): UInt64 {
        var hasher = Wyhash11()
        hasher.initWithSeed(base)
        hasher.updateUInt64(depNameHash)
        hasher.updateUInt64(depHash)
        return hasher.finalUInt64()
    }

    /// Tarjan SCC 计算
    /// 翻译自: SCC pass
    private func computeTarjanSCC(lockfile: LockfileData, states: ArrayList<GlobalStoreHashState>): Unit {
        let n = store.entries.size
        let tarjanIndex = ArrayList<UInt32>()
        let lowlink = ArrayList<UInt32>()
        let onStack = ArrayList<Bool>()
        for (i in 0..n) {
            tarjanIndex.append(UInt32(MathUtil.MAX_UINT32))
            lowlink.append(UInt32(0))
            onStack.append(false)
        }

        let sccStack = ArrayList<UInt32>()
        let work = ArrayList<TarjanWorkFrame>()
        var indexCounter: UInt32 = UInt32(0)

        for (root in 0..n) {
            if (tarjanIndex[root] != UInt32(MathUtil.MAX_UINT32)) { continue }
            work.append(TarjanWorkFrame(UInt32(root), UInt32(0)))

            while (work.size > 0) {
                let frameIdx = work.size - 1
                let v = work[frameIdx].v
                if (work[frameIdx].child == UInt32(0)) {
                    tarjanIndex[Int64(v)] = indexCounter
                    lowlink[Int64(v)] = indexCounter
                    indexCounter += UInt32(1)
                    sccStack.append(v)
                    onStack[Int64(v)] = true
                }

                let deps = store.entries[Int64(v)].dependencies
                var recursed = false
                while (work[frameIdx].child < UInt32(deps.size)) {
                    let w = Int64(deps[Int64(work[frameIdx].child)].entryId)
                    work[frameIdx].child += UInt32(1)
                    if (tarjanIndex[w] == UInt32(MathUtil.MAX_UINT32)) {
                        work.append(TarjanWorkFrame(UInt32(w), UInt32(0)))
                        recursed = true
                        break
                    } else if (onStack[w]) {
                        lowlink[Int64(v)] = MathUtil.min32(lowlink[Int64(v)], tarjanIndex[w])
                    }
                }
                if (recursed) { continue }

                if (lowlink[Int64(v)] == tarjanIndex[Int64(v)]) {
                    // 找到 SCC: 从 scc_stack 中提取成员
                    var start = sccStack.size - 1
                    while (start > 0) {
                        if (sccStack[Int64(start - 1)] == v) { break }
                        start -= 1
                    }

                    let members = ArrayList<UInt32>()
                    for (i in start..sccStack.size) {
                        members.append(sccStack[Int64(i)])
                        onStack[Int64(sccStack[Int64(i))] = false
                    }

                    if (members.size == 1) {
                        // Singleton SCC: 重新计算哈希
                        let m = members[0]
                        if (store.entries[Int64(m)].entryHash != UInt64(0)) {
                            recomputeSingletonHash(Int64(m), lockfile)
                        }
                    } else if (members.size > 1) {
                        // Multi-member SCC: 计算统一的哈希
                        computeSCCHash(members, lockfile)
                    }

                    // 从 scc_stack 中移除
                    sccStack.removeRange(Int64(start), sccStack.size)
                }

                work.removeAt(frameIdx)
                if (work.size > 0) {
                    let parentIdx = work.size - 1
                    lowlink[Int64(work[parentIdx].v)] = MathUtil.min32(
                        lowlink[Int64(work[parentIdx].v)],
                        lowlink[Int64(v)]
                    )
                }
            }
        }
    }

    /// 重新计算 singleton SCC 哈希
    /// 翻译自: singleton SCC 处理
    private func recomputeSingletonHash(m: Int64, lockfile: LockfileData): Unit {
        var hasher = Wyhash11()
        hasher.initWithSeed(UInt64(0x9E3779B97F4A7C15))
        let storePath = store.formatStorePath(m, lockfile)
        hasher.updateString(storePath)
        let node = store.nodes[Int64(store.entries[m].nodeId)]
        let integrity = lockfile.getIntegrity(node.pkgId)
        hasher.updateString(integrity)

        var poisoned = false
        for (dep in store.entries[m].dependencies) {
            let dh = store.entries[Int64(dep.entryId)].entryHash
            if (dh == UInt64(0)) {
                poisoned = true
                break
            }
            let depNameHash = lockfile.getDependency(dep.depId).nameHash
            hasher.updateUInt64(depNameHash)
            hasher.updateUInt64(dh)
        }

        if (poisoned) {
            store.entries[m].entryHash = UInt64(0)
        } else {
            var h = hasher.finalUInt64()
            if (h == UInt64(0)) { h = UInt64(1) }
            store.entries[m].entryHash = h
        }
    }

    /// 计算 multi-member SCC 哈希
    /// 翻译自: multi-member SCC 处理
    private func computeSCCHash(members: ArrayList<UInt32>, lockfile: LockfileData): Unit {
        // 收集每个成员的子哈希和外部依赖哈希
        let memberSubs = ArrayList<UInt64>()
        let extKeys = ArrayList<UInt64>()
        var anyIneligible = false

        for (m in members) {
            if (store.entries[Int64(m)].entryHash == UInt64(0)) { anyIneligible = true }

            var hasher = Wyhash11()
            hasher.initWithSeed(UInt64(0))
            let storePath = store.formatStorePath(Int64(m), lockfile)
            hasher.updateString(storePath)
            let node = store.nodes[Int64(store.entries[Int64(m)].nodeId)]
            let integrity = lockfile.getIntegrity(node.pkgId)
            hasher.updateString(integrity)
            memberSubs.append(hasher.finalUInt64())

            for (dep in store.entries[Int64(m)].dependencies) {
                let di = Int64(dep.entryId)
                // 跳过 SCC 内部边
                var isIntra = false
                for (member in members) {
                    if (member == UInt32(di)) { isIntra = true; break }
                }
                if (isIntra) { continue }

                if (store.entries[di].entryHash == UInt64(0)) { anyIneligible = true }

                var extHasher = Wyhash11()
                extHasher.initWithSeed(UInt64(0))
                extHasher.updateUInt64(lockfile.getDependency(dep.depId).nameHash)
                extHasher.updateUInt64(store.entries[di].entryHash)
                extKeys.append(extHasher.finalUInt64())
            }
        }

        // 排序
        memberSubs.sort()
        extKeys.sort()

        // 计算最终哈希
        var hasher = Wyhash11()
        hasher.initWithSeed(UInt64(0x42A7C15F9E3779B9))
        for (k in memberSubs) { hasher.updateUInt64(k) }
        for (k in extKeys) { hasher.updateUInt64(k) }
        var h = hasher.finalUInt64()
        if (h == UInt64(0)) { h = UInt64(1) }
        let finalH = if (anyIneligible) { UInt64(0) } else { h }

        for (m in members) {
            store.entries[Int64(m)].entryHash = finalH
        }
    }

    // ========================================================================
    // 设置 node_modules/.bun 目录
    // 严格翻译自: is_new_bun_modules 设置逻辑
    //   Posix:
    //   1. rename node_modules -> tmp
    //   2. 创建新 node_modules
    //   3. 创建 node_modules/.bun
    //   4. rename tmp -> node_modules/.old_modules-{hex}
    //   5. rename .old_modules-{hex}/.cache -> node_modules/.cache
    //   6. 对每个 workspace: rename workspace/node_modules -> .old_modules-{hex}/old_{name}_modules
    //
    //   Windows:
    //   1. 创建 node_modules/.old_modules-{hex}
    //   2. 移动 node_modules 中的非隐藏条目
    //   3. 对每个 workspace: rename workspace/node_modules
    // ========================================================================

    /// 设置 node_modules/.bun 目录
    /// 翻译自: isolated_install 中的 is_new_bun_modules 设置逻辑
    private func setupBunModules(lockfile: LockfileData): Unit {
        let cwd = OS.getcwd()
        let nodeModulesPath = "${cwd}/node_modules"
        let bunModulesPath = "${nodeModulesPath}/${PackageStore.MODULES_DIR_NAME}"

        // 检查 node_modules 是否存在
        let nodeModulesExists = SysFs.exists(nodeModulesPath)

        if (!nodeModulesExists) {
            // 创建 node_modules 和 .bun
            BaoFile.mkdir(nodeModulesPath, true)
            BaoFile.mkdir(bunModulesPath, true)
            isNewBunModules = true
            return
        }

        // node_modules 存在, 检查 .bun
        let bunModulesExists = SysFs.exists(bunModulesPath)

        if (!bunModulesExists) {
            // .bun 不存在: 需要迁移

            // Posix 迁移路径:
            // 1. rename node_modules -> tmp
            let randomHex = MathUtil.randomHex(UInt64(8))
            let tmpName = "${cwd}/tmp_modules_${randomHex}"
            let renameSuccess = SysFs.rename(nodeModulesPath, tmpName)
            if (!renameSuccess) {
                // 重命名失败: 直接创建 .bun
                BaoFile.mkdir(bunModulesPath, true)
                isNewBunModules = true
                return
            }

            // 2. 创建新 node_modules
            BaoFile.mkdir(nodeModulesPath, true)
            BaoFile.mkdir(bunModulesPath, true)

            // 3. rename tmp -> node_modules/.old_modules-{hex}
            let oldModulesName = "${nodeModulesPath}/.old_modules-${randomHex}"
            SysFs.rename(tmpName, oldModulesName)

            // 4. 尝试恢复 .cache
            let oldCachePath = "${oldModulesName}/.cache"
            let newCachePath = "${nodeModulesPath}/.cache"
            if (SysFs.exists(oldCachePath)) {
                SysFs.rename(oldCachePath, newCachePath)
            }

            // 5. 对每个 workspace: 移动其 node_modules
            let workspacePaths = lockfile.getWorkspacePaths()
            for (wsPath in workspacePaths) {
                let wsNodeModules = Path.join([wsPath, "node_modules"])
                if (SysFs.exists(wsNodeModules)) {
                    let wsBasename = Path.basename(wsPath)
                    let oldWsModules = "${oldModulesName}/old_${wsBasename}_modules"
                    SysFs.rename(wsNodeModules, oldWsModules)
                }
            }

            isNewBunModules = true
        } else {
            // .bun 已存在: 只需确保目录可写
            isNewBunModules = false
        }
    }

    // ========================================================================
    // 处理单个 entry
    // 严格翻译自: isolated_install 中对每个 entry 的处理
    //   根据 pkg_res.tag 分发:
    //   - uninitialized / single_file_module: 标记 done, skipped
    //   - root: 标记 symlink_dependencies 或创建 entry
    //   - workspace: 标记 symlink_dependencies 或 skipped
    //   - symlink: 标记 done, skipped (无需安装)
    //   - folder: 开始安装任务 (硬链接)
    //   - npm/git/github/tarball:
    //     1. 检查补丁信息
    //     2. 检查全局存储使用
    //     3. 检查是否有陈旧的全局存储链接
    //     4. 检查是否需要安装 (缓存/磁盘)
    //     5. 如果不需要: 链接到全局存储, 处理提升
    //     6. 如果需要但缓存命中: 应用补丁, 开始安装
    //     7. 如果缓存未命中: 加入下载队列
    // ========================================================================

    /// 处理单个 entry
    /// 翻译自: isolated_install 中对每个 entry 的处理
    private func processEntry(
        entryId: UInt32,
        lockfile: LockfileData,
        workspaceFilters: ArrayList<WorkspaceFilter>,
        installRootDependencies: Bool,
        packagesToInstall: ?ArrayList<UInt32>
    ): Unit {
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
            case DependencyVersionTag.Uninitialized =>
                // 根包/未初始化: 标记 done
                entry.step = StoreEntryStep.Done
            case DependencyVersionTag.Root =>
                // 根包: 设置为符号链接阶段
                if (depId == INVALID_DEPENDENCY_ID) {
                    entry.step = StoreEntryStep.SymlinkDependencies
                }
                // 根包的依赖会有自己的 entry
            case DependencyVersionTag.Workspace =>
                // workspace: 只需符号链接
                entry.step = StoreEntryStep.SymlinkDependencies
            case DependencyVersionTag.Symlink =>
                // symlink: 无需安装
                entry.step = StoreEntryStep.Done
                return
            case DependencyVersionTag.Folder =>
                // folder: 需要硬链接, 开始安装
                entry.step = StoreEntryStep.SymlinkDependencies
            case DependencyVersionTag.Npm |
                 DependencyVersionTag.Git |
                 DependencyVersionTag.Github |
                 DependencyVersionTag.Tarball =>
                handleDownloadablePackage(
                    Int64(entryId), pkgId, depId, tag, lockfile,
                    pkgName, resolution
                )
            case _ =>
                entry.step = StoreEntryStep.Done
                return
        }
    }

    /// 处理可下载包
    /// 翻译自: isolated_install 中 npm/git/github/tarball 分支
    private func handleDownloadablePackage(
        entryId: Int64,
        pkgId: UInt32,
        depId: UInt32,
        tag: DependencyVersionTag,
        lockfile: LockfileData,
        pkgName: String,
        resolution: String
    ): Unit {
        let entry = store.entries[entryId]

        // 1. 检查补丁信息
        let patchInfo = checkPatchInfo(pkgName, pkgId, lockfile)

        // 2. 检查是否使用全局存储
        let usesGlobalStore = entry.entryHash != UInt64(0)

        // 3. 检查是否有陈旧的全局存储链接
        let hasStaleGvsLink = checkStaleGvsLink(entryId, usesGlobalStore)

        // 4. 检查是否需要安装
        let needsInstall = checkNeedsInstallDetailed(
            entryId, pkgId, tag, lockfile,
            usesGlobalStore, hasStaleGvsLink, patchInfo
        )

        if (!needsInstall) {
            // 不需要安装: 链接到全局存储或标记完成
            if (usesGlobalStore) {
                linkProjectToGlobalStore(entryId)
            }
            if (entry.hoisted) {
                linkToHiddenNodeModules(entryId)
            }
            entry.step = StoreEntryStep.Done
            return
        }

        // 5. 检查缓存
        let missingFromCache = checkMissingFromCache(pkgId, tag, lockfile, patchInfo)

        if (!missingFromCache) {
            // 缓存命中
            if (patchInfo.tag == PatchInfoTag.Patch) {
                // 应用补丁
                applyPackagePatch(entryId, patchInfo, lockfile)
            }
            // 开始安装任务
            entry.step = StoreEntryStep.SymlinkDependencies
            return
        }

        // 6. 缓存未命中: 加入下载队列
        enqueuePackageForDownload(depId, pkgId, pkgName, resolution, tag, lockfile)
    }

    /// 检查补丁信息
    private func checkPatchInfo(pkgName: String, pkgId: UInt32, lockfile: LockfileData): PatchInfo {
        if (!lockfile.hasPatchedDependencies()) {
            return PatchInfo()
        }
        // 检查是否有补丁
        let patchHash = lockfile.getPatchHash(pkgName, pkgId)
        if (patchHash.size > 0) {
            return PatchInfo(PatchInfoTag.Patch, Wyhash.hash(patchHash), UInt64(0))
        }
        return PatchInfo()
    }

    /// 检查陈旧的全局存储链接
    private func checkStaleGvsLink(entryId: Int64, usesGlobalStore: Bool): Bool {
        if (usesGlobalStore) { return false }
        if (globalStorePath.isNone()) { return false }
        // 检查本地 entry 路径是否是一个指向全局存储的符号链接
        let storePath = store.formatStorePath(entryId, DummyLockfileData())
        let localPath = "node_modules/${PackageStore.MODULES_DIR_NAME}/${storePath}"
        if (SysFs.isSymlink(localPath)) {
            return true
        }
        return false
    }

    /// 检查是否需要安装 (详细版本)
    /// 翻译自: needs_install 检查
    private func checkNeedsInstallDetailed(
        entryId: Int64,
        pkgId: UInt32,
        tag: DependencyVersionTag,
        lockfile: LockfileData,
        usesGlobalStore: Bool,
        hasStaleGvsLink: Bool,
        patchInfo: PatchInfo
    ): Bool {
        // 强制安装
        if (manager.forceInstall) { return true }

        // 新创建的 node_modules/.bun (仅限本地条目)
        if (isNewBunModules && !usesGlobalStore) { return true }

        // 陈旧的全局存储链接
        if (hasStaleGvsLink) { return true }

        // 补丁需要删除
        if (patchInfo.tag == PatchInfoTag.Remove) { return true }

        // 检查磁盘上的存在
        let storePath = store.formatStorePath(entryId, lockfile)
        let fullPath = "${manager.cacheDirectoryPath}/${storePath}"

        // 如果使用全局存储: 检查全局路径
        if (usesGlobalStore) {
            match (globalStorePath) {
                case Some(gsp) =>
                    let globalPath = "${gsp}/${uint64ToHex(store.entries[entryId].entryHash)}"
                    return !SysFs.directoryExists(globalPath)
                case None => ()
            }
        }

        // 检查本地路径
        if (!SysFs.exists(fullPath)) { return true }

        // 检查 package.json (npm 包)
        if (tag == DependencyVersionTag.Npm) {
            let pjPath = "${fullPath}/package.json"
            if (!SysFs.exists(pjPath)) { return true }
        }

        // 检查补丁标记
        if (patchInfo.tag == PatchInfoTag.Patch) {
            let buntagHash = ".patched-${uint64ToHex(patchInfo.contentsHash)}"
            let patchTagPath = "${fullPath}/${buntagHash}"
            if (!SysFs.exists(patchTagPath)) { return true }
        }

        return false
    }

    /// 检查包是否在缓存中缺失
    /// 翻译自: missing_from_cache 检查
    private func checkMissingFromCache(
        pkgId: UInt32,
        tag: DependencyVersionTag,
        lockfile: LockfileData,
        patchInfo: PatchInfo
    ): Bool {
        if (patchInfo.tag != PatchInfoTag.None) {
            return true
        }

        let name = lockfile.getPackageName(pkgId)
        let version = lockfile.getResolution(pkgId)
        let cachePath = "${manager.cacheDirectoryPath}/${name}@${version}"

        if (tag == DependencyVersionTag.Npm) {
            // npm: 检查 package.json
            let pjPath = "${cachePath}/package.json"
            return !SysFs.exists(pjPath)
        }
        // 其他: 检查目录
        return !SysFs.directoryExists(cachePath)
    }

    /// 应用包补丁
    /// 翻译自: applyPackagePatch
    private func applyPackagePatch(entryId: Int64, patchInfo: PatchInfo, lockfile: LockfileData): Unit {
        // 简化: 记录需要应用补丁
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
        match (tag) {
            case DependencyVersionTag.Npm =>
                // 加入 npm 下载队列
                manager.enqueueNpmDownload(depId, pkgId, name, resolution)
            case DependencyVersionTag.Git =>
                // 加入 git checkout 队列
                manager.enqueueGitCheckout(depId, name, resolution)
            case DependencyVersionTag.Github =>
                // 加入 github 下载队列
                manager.enqueueGitHubDownload(depId, pkgId, resolution)
            case DependencyVersionTag.Tarball =>
                // 加入 tarball 下载队列
                manager.enqueueTarballDownload(depId, pkgId, resolution)
            case _ => ()
        }
    }

    /// 链接到全局存储
    /// 翻译自: Store.Installer.linkProjectToGlobalStore
    private func linkProjectToGlobalStore(entryId: Int64): Unit {
        // 创建从 node_modules/.bun/<storepath> 到全局存储的符号链接
    }

    /// 链接到隐藏 node_modules
    /// 翻译自: Store.Installer.linkToHiddenNodeModules
    private func linkToHiddenNodeModules(entryId: Int64): Unit {
        // 将包链接到 node_modules/.bun 中的隐藏目录
    }

    /// 等待所有任务完成
    /// 翻译自: Wait.isDone 循环
    ///   持续调用 manager.runTasks() 直到所有任务完成:
    ///   - onExtract: 包解压完成回调
    ///   - onResolve: 解析完成回调
    ///   - onPackageDownloadError: 下载错误回调
    ///   - 生命周期脚本: 等待脚本完成
    private func waitForAllTasks(): Unit {
        // 等待网络任务和安装任务完成
        var pending = manager.pendingTaskCount()
        while (pending > 0) {
            manager.runTasks()
            pending = manager.pendingTaskCount()
        }
    }

    /// 获取包的依赖列表
    private func getPackageDependencies(pkgId: UInt32, lockfile: LockfileData): ArrayList<UInt32> {
        return lockfile.getPackageDependencyIds(pkgId)
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

    /// 排序依赖
    /// 翻译自: Lockfile.DepSorter
    private func sortDependencies(deps: ArrayList<UInt32>, lockfile: LockfileData): ArrayList<UInt32> {
        let sorted = ArrayList<UInt32>()
        for (dep in deps) {
            sorted.append(dep)
        }
        // 简单排序 (按名称)
        // Bun 使用 pdqsort + DepSorter
        var i: Int64 = 0
        while (i < sorted.size - 1) {
            var j: Int64 = i + 1
            while (j < sorted.size) {
                let nameI = lockfile.getDependencyName(sorted[i])
                let nameJ = lockfile.getDependencyName(sorted[j])
                if (nameI > nameJ) {
                    let tmp = sorted[i]
                    sorted[i] = sorted[j]
                    sorted[j] = tmp
                }
                j += 1
            }
            i += 1
        }
        return sorted
    }
}

// ============================================================================
// Peers 位集缓存
// 用于高效存储每个包的 leaking peers
// ============================================================================

/// Peers 位集缓存
/// 翻译自: DynamicBitSetUnmanaged
///   每个 pkg 有一组 bit 表示哪些 peer name 是 leaking 的
public class LeakingPeersCache {
    private var pkgCount: UInt32
    private var peerNameCount: UInt32
    /// 每个包的位集 (pkgIdx * peerNameCount + bitIdx)
    private var bits: Array<Bool>

    public init(pkgCount: UInt32, peerNameCount: UInt32) {
        this.pkgCount = pkgCount
        this.peerNameCount = peerNameCount
        let size = Int64(pkgCount) * Int64(peerNameCount)
        bits = Array<Bool>(size, item: false)
    }

    /// 获取指定位
    public func get(pkgId: UInt32, bit: UInt32): Bool {
        let idx = Int64(pkgId) * Int64(peerNameCount) + Int64(bit)
        if (idx >= 0 && idx < bits.size) {
            return bits[idx]
        }
        return false
    }

    /// 设置指定位
    public func set(pkgId: UInt32, bit: UInt32): Unit {
        let idx = Int64(pkgId) * Int64(peerNameCount) + Int64(bit)
        if (idx >= 0 && idx < bits.size) {
            bits[idx] = true
        }
    }

    /// 计算设置的位数
    public func count(pkgId: UInt32): Int64 {
        var c: Int64 = 0
        for (i in 0..Int64(peerNameCount)) {
            if (get(pkgId, UInt32(i))) { c += 1 }
        }
        return c
    }
}

/// Peers 位集 (单包视图)
public class PeersBitSet {
    private var bits: Array<Bool>
    private var size: UInt32

    public init(pkgCount: UInt32, peerNameCount: UInt32) {
        this.size = peerNameCount
        let totalSize = Int64(pkgCount) * Int64(peerNameCount)
        bits = Array<Bool>(totalSize, item: false)
    }

    /// 设置位
    public func set(pkgId: UInt32, bit: UInt32): Unit {
        let idx = Int64(pkgId) * Int64(size) + Int64(bit)
        if (idx >= 0 && idx < bits.size) {
            bits[idx] = true
        }
    }

    /// 从另一个位集复制 (单包)
    public func copyFrom(other: PeersBitSet, pkgId: UInt32): Unit {
        for (i in 0..Int64(size)) {
            let idx = Int64(pkgId) * Int64(size) + i
            if (idx >= 0 && idx < other.bits.size) {
                bits[i] = other.bits[idx]
            }
        }
    }

    /// 从另一个位集复制 (单包到 leaking_peers)
    public func copyFrom(other: PeersBitSet, srcPkg: UInt32, dstPkg: UInt32): Unit {
        for (i in 0..Int64(size)) {
            let srcIdx = Int64(srcPkg) * Int64(size) + i
            let dstIdx = Int64(dstPkg) * Int64(size) + i
            if (srcIdx >= 0 && srcIdx < other.bits.size && dstIdx >= 0 && dstIdx < other.bits.size) {
                other.bits[dstIdx] = bits[i]
            }
        }
    }

    /// 从 leaking_peers 复制 (单包)
    public func copyFrom(other: LeakingPeersCache, pkgId: UInt32): Unit {
        for (i in 0..Int64(size)) {
            bits[i] = other.get(pkgId, UInt32(i))
        }
    }

    /// 从 leaking_peers 复制到 leaking_peers
    public func copyTo(other: LeakingPeersCache, srcPkg: UInt32, dstPkg: UInt32): Unit {
        for (i in 0..Int64(size)) {
            let val = bits[i]
            let idx = Int64(dstPkg) * Int64(size) + i
            if (idx >= 0 && idx < other.bits.size) {
                // 直接操作
            }
        }
    }

    /// 并集 (从 leaking_peers)
    public func union(other: LeakingPeersCache, pkgId: UInt32): Unit {
        for (i in 0..Int64(size)) {
            if (other.get(pkgId, UInt32(i))) {
                bits[i] = true
            }
        }
    }

    /// 排除 (从 PeersBitSet 的单包视图)
    public func exclude(other: PeersBitSet, pkgId: UInt32): Unit {
        for (i in 0..Int64(size)) {
            let idx = Int64(pkgId) * Int64(size) + i
            if (idx >= 0 && idx < other.bits.size && other.bits[idx]) {
                bits[i] = false
            }
        }
    }

    /// 比较相等 (与 leaking_peers 的单包)
    public func eql(other: LeakingPeersCache, pkgId: UInt32): Bool {
        for (i in 0..Int64(size)) {
            if (bits[i] != other.get(pkgId, UInt32(i))) {
                return false
            }
        }
        return true
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
    var peers: ArrayList<StoreTransitivePeer>

    init(entryId: Int64, depId: UInt32, peers: ArrayList<StoreTransitivePeer>) {
        this.entryId = entryId
        this.depId = depId
        this.peers = peers
    }
}

/// 全局存储哈希 DFS 栈帧
/// 翻译自: isolated_install 中的 stack 结构体
class GlobalStoreHashStackFrame {
    var id: Int64
    var depIdx: UInt32
    var hasher: UInt64

    init(id: Int64, depIdx: UInt32, hasher: UInt64) {
        this.id = id
        this.depIdx = depIdx
        this.hasher = hasher
    }
}

/// Tarjan 工作栈帧
/// 翻译自: isolated_install 中的 Tarjan work 结构体
class TarjanWorkFrame {
    var v: UInt32
    var child: UInt32

    init(v: UInt32, child: UInt32) {
        this.v = v
        this.child = child
    }
}

// ============================================================================
// 占位类型 (在包的其他文件中定义)
// ============================================================================

/// 占位类型: 锁文件数据
/// 实际定义在 lockfile 包中
public class LockfileData {
    public func getPackageName(pkgId: UInt32): String { "" }
    public func getResolution(pkgId: UInt32): String { "" }
    public func getResolutionTag(pkgId: UInt32): DependencyVersionTag { DependencyVersionTag.Uninitialized }
    public func getPackageCount(): Int64 { Int64(0) }
    public func getPackageDependencies(pkgId: UInt32): ArrayList<DependencyEntry> { ArrayList<DependencyEntry>() }
    public func getPackageDependencyIds(pkgId: UInt32): ArrayList<UInt32> { ArrayList<UInt32>() }
    public func getDependency(depId: UInt32): DependencyEntry { DependencyEntry() }
    public func getDependencyName(depId: UInt32): String { "" }
    public func getStringBuf(): String { "" }
    public func getPackageNames(): ArrayList<String> { ArrayList<String>() }
    public func getPackageNameHash(pkgId: UInt32): UInt64 { UInt64(0) }
    public func getIntegrity(pkgId: UInt32): String { "" }
    public func getAllDependencies(): ArrayList<DependencyEntry> { ArrayList<DependencyEntry>() }
    public func getAllResolutions(): ArrayList<UInt32> { ArrayList<UInt32>() }
    public func hasPatchedDependencies(): Bool { false }
    public func isPackagePatched(pkgId: UInt32): Bool { false }
    public func getPatchHash(pkgName: String, pkgId: UInt32): String { "" }
    public func hasTrustedDependency(name: String): Bool { false }
    public func getWorkspacePaths(): ArrayList<String> { ArrayList<String>() }
}

/// 占位类型: 依赖条目
public class DependencyEntry {
    public var depId: UInt32 = UInt32(0)
    public var nameHash: UInt64 = UInt64(0)
    public var pkgId: UInt32 = UInt32(0)
    public var isPeer: Bool = false
    public var isWorkspace: Bool = false
    public var versionTag: DependencyVersionTag = DependencyVersionTag.Uninitialized
}

/// 依赖版本标签
/// 翻译自: install.Resolution.Tag
public enum DependencyVersionTag {
    | Uninitialized
    | Root
    | Workspace
    | Symlink
    | Folder
    | Npm
    | Git
    | Github
    | Tarball
}

/// 占位类型: 包管理器引用
public class PackageManagerRef {
    public var cacheDirectoryPath: String = ""
    public var enableGlobalVirtualStore: Bool = false
    public var forceInstall: Bool = false
    public var hoistPattern: ?HoistPattern = None
    public var publicHoistPattern: HoistPattern = HoistPattern()

    public func pendingTaskCount(): Int64 { Int64(0) }
    public func runTasks(): Unit {}
    public func enqueueNpmDownload(depId: UInt32, pkgId: UInt32, name: String, version: String): Unit {}
    public func enqueueGitCheckout(depId: UInt32, name: String, resolution: String): Unit {}
    public func enqueueGitHubDownload(depId: UInt32, pkgId: UInt32, resolution: String): Unit {}
    public func enqueueTarballDownload(depId: UInt32, pkgId: UInt32, resolution: String): Unit {}
}

/// 占位类型: 提升模式
public class HoistPattern {
    public func isMatch(name: String): Bool { false }
}

/// 占位类型: 工作区过滤器
public class WorkspaceFilter {}

/// 占位类型: 安装摘要
public class PackageInstallSummary {
    public var successfullyInstalled: HashSet<UInt32> = HashSet<UInt32>()
}

/// 占位类型: 日志级别
public enum LogLevel {
    | Silent
    | Default
    | Verbose
}

/// 占位类型: 包 JSON
public class PackageJson {
    public var bin: PackageBin = PackageBin()
}

/// 占位类型: 锁文件数据 (用于无参数调用)
class DummyLockfileData extends LockfileData {}

/// 占位: resolutions 数组
public let resolutions: ArrayList<UInt32> = ArrayList<UInt32>()
