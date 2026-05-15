// bao_install - 隔离安装存储
// 严格翻译自: src/install/isolated_install/Store.zig
//   Store 管理隔离安装的条目 (Entry) 和节点 (Node) 树结构
//   用于表示完整的依赖关系图
package bao_install.isolated_install

import bao_core.*
import bao_collections.*

// ============================================================================
// 新 ID 类型
// 严格翻译自: Store.zig - NewId
//   fn NewId(comptime T: type) type { return enum(u32) { root = 0, invalid = max, _, ... } }
// ============================================================================

/// 条目 ID
/// 对应 Bun: Store.Entry.Id (NewId(Entry))
public struct EntryId : UInt32 {
    public static let ROOT: EntryId = EntryId(0)
    public static let INVALID: EntryId = EntryId(UInt32.MAX)

    public func get(): UInt32 {
        return this.value
    }

    public func tryGet(): ?UInt32 {
        if (this == EntryId.INVALID) { return None }
        return this.value
    }

    public func getOr(default: UInt32): UInt32 {
        if (this == EntryId.INVALID) { return default }
        return this.value
    }
}

/// 节点 ID
/// 对应 Bun: Store.Node.Id (NewId(Node))
public struct NodeId : UInt32 {
    public static let ROOT: NodeId = NodeId(0)
    public static let INVALID: NodeId = NodeId(UInt32.MAX)

    public func get(): UInt32 {
        return this.value
    }

    public func tryGet(): ?UInt32 {
        if (this == NodeId.INVALID) { return None }
        return this.value
    }
}

// ============================================================================
// 对等哈希
// 严格翻译自: Store.zig - Entry.PeerHash
//   pub const PeerHash = enum(u64) { none = 0, _ }
// ============================================================================

/// 对等哈希
/// 对应 Bun: Store.Entry.PeerHash
public struct PeerHash : UInt64 {
    public static let NONE: PeerHash = PeerHash(UInt64(0))

    public static func from(int: UInt64): PeerHash {
        return PeerHash(int)
    }

    public func cast(): UInt64 {
        return this.value
    }
}

// ============================================================================
// ID 对
// 严格翻译自: Store.zig - Ids
//   const Ids = struct { dep_id: DependencyID, pkg_id: PackageID }
// ============================================================================

/// ID 对
/// 对应 Bun: Store.Ids
public class Ids {
    public var depId: UInt32
    public var pkgId: UInt32

    public init(depId: UInt32, pkgId: UInt32) {
        this.depId = depId
        this.pkgId = pkgId
    }
}

// ============================================================================
// 依赖项 (有序集合中的项)
// 严格翻译自: Store.zig - Entry.DependenciesItem
//   const DependenciesItem = struct { entry_id: Id, dep_id: DependencyID }
// ============================================================================

/// 依赖项
/// 对应 Bun: Store.Entry.DependenciesItem
public class DependenciesItem {
    public var entryId: EntryId
    public var depId: UInt32

    public init(entryId: EntryId, depId: UInt32) {
        this.entryId = entryId
        this.depId = depId
    }
}

// ============================================================================
// 传递对等依赖
// 严格翻译自: Store.zig - Node.TransitivePeer
//   pub const TransitivePeer = struct {
//       dep_id: DependencyID, pkg_id: PackageID, auto_installed: bool
//   }
// ============================================================================

/// 传递对等依赖
/// 对应 Bun: Store.Node.TransitivePeer
public class TransitivePeer {
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
// 有序数组集合
// 严格翻译自: Store.zig - OrderedArraySet
//   pub fn OrderedArraySet(comptime T: type, comptime Ctx: type) type
// ============================================================================

/// 有序数组集合
/// 对应 Bun: Store.OrderedArraySet
public class OrderedArraySet<T> {
    public var list: ArrayList<T>

    public init() {
        list = ArrayList<T>()
    }

    public func slice(): Array<T> {
        return list.toArray()
    }

    public func len(): Int64 {
        return list.size
    }

    /// 插入元素 (保持有序且去重)
    /// 翻译自: OrderedArraySet.insert
    public func insert(new: T, ctx: OrderedArraySetContext<T>): Unit {
        for (i in 0..list.size) {
            let existing = list[i]
            if (ctx.eql(new, existing)) {
                return
            }
            let order = ctx.order(new, existing)
            if (order == Order.EQ) {
                return
            }
            if (order == Order.LT) {
                list.insert(i, new)
                return
            }
        }
        list.append(new)
    }

    public func clear(): Unit {
        list.clear()
    }
}

/// 排序顺序
public enum Order {
    | LT
    | EQ
    | GT
}

/// 有序数组集合上下文
public interface OrderedArraySetContext<T> {
    func eql(left: T, right: T): Bool
    func order(left: T, right: T): Order
}

// ============================================================================
// 存储条目
// 严格翻译自: Store.zig - Store.Entry
//   pub const Entry = struct {
//       node_id: Node.Id, dependencies: Dependencies, parents: ArrayListUnmanaged(Id),
//       step: atomic Value(Step), hoisted: bool, peer_hash: PeerHash,
//       entry_hash: u64, scripts: ?*Package.Scripts.List
//   }
// ============================================================================

/// 存储条目
/// 对应 Bun: Store.Entry
/// 翻译自: src/install/isolated_install/Store.zig
public class StoreEntry {
    /// 节点 ID (用于获取依赖名和对等依赖)
    /// 翻译自: node_id: Node.Id
    public var nodeId: NodeId

    /// 依赖列表
    /// 翻译自: dependencies: Dependencies
    public var dependencies: OrderedArraySet<DependenciesItem>

    /// 父条目列表
    /// 翻译自: parents: std.ArrayListUnmanaged(Id)
    public var parents: ArrayList<EntryId>

    /// 当前步骤 (原子值)
    /// 翻译自: step: std.atomic.Value(Installer.Task.Step)
    public var step: InstallerTaskStep

    /// 是否被提升
    /// 翻译自: hoisted: bool
    public var hoisted: Bool

    /// 对等哈希
    /// 翻译自: peer_hash: PeerHash
    public var peerHash: PeerHash

    /// 条目哈希 (包 + 排序后的已解析依赖全局存储键的内容哈希)
    /// 翻译自: entry_hash: u64 = 0
    public var entryHash: UInt64

    /// 脚本列表
    /// 翻译自: scripts: ?*Package.Scripts.List
    public var scripts: ?ScriptsList

    public init() {
        nodeId = NodeId.INVALID
        dependencies = OrderedArraySet<DependenciesItem>()
        parents = ArrayList<EntryId>()
        step = InstallerTaskStep.LinkPackage
        hoisted = false
        peerHash = PeerHash.NONE
        entryHash = UInt64(0)
        scripts = None
    }

    public init(nodeId: NodeId) {
        this.nodeId = nodeId
        dependencies = OrderedArraySet<DependenciesItem>()
        parents = ArrayList<EntryId>()
        step = InstallerTaskStep.LinkPackage
        hoisted = false
        peerHash = PeerHash.NONE
        entryHash = UInt64(0)
        scripts = None
    }
}

// ============================================================================
// 存储节点
// 严格翻译自: Store.zig - Store.Node
//   pub const Node = struct {
//       dep_id: DependencyID, pkg_id: PackageID, parent_id: Id,
//       dependencies: ArrayListUnmanaged(Ids), peers: Peers,
//       nodes: ArrayListUnmanaged(Id)
//   }
// ============================================================================

/// 存储节点
/// 对应 Bun: Store.Node
public class StoreNode {
    /// 依赖 ID
    public var depId: UInt32
    /// 包 ID
    public var pkgId: UInt32
    /// 父节点 ID
    public var parentId: NodeId

    /// 子依赖列表
    /// 翻译自: dependencies: std.ArrayListUnmanaged(Ids)
    public var dependencies: ArrayList<Ids>

    /// 对等依赖集合
    /// 翻译自: peers: Peers (OrderedArraySet(TransitivePeer, ...))
    public var peers: OrderedArraySet<TransitivePeer>

    /// 子节点列表 (每个节点成为 node_modules 中的符号链接)
    /// 翻译自: nodes: std.ArrayListUnmanaged(Id)
    public var nodes: ArrayList<NodeId>

    public init(depId: UInt32, pkgId: UInt32, parentId: NodeId) {
        this.depId = depId
        this.pkgId = pkgId
        this.parentId = parentId
        dependencies = ArrayList<Ids>()
        peers = OrderedArraySet<TransitivePeer>()
        nodes = ArrayList<NodeId>()
    }
}

// ============================================================================
// 安装器任务步骤
// 严格翻译自: Installer.zig - Task.Step
//   pub const Step = enum { link_package, symlink_dependencies, check_if_blocked,
//       symlink_dependency_binaries, run_preinstall, binaries, run_scripts, done }
// ============================================================================

/// 安装器任务步骤
/// 对应 Bun: Installer.Task.Step
public enum InstallerTaskStep {
    | LinkPackage                  // 链接包文件
    | SymlinkDependencies          // 创建依赖符号链接
    | CheckIfBlocked               // 检查是否被阻塞
    | SymlinkDependencyBinaries    // 创建依赖二进制文件符号链接
    | RunPreinstall                // 运行预安装脚本
    | Binaries                     // 处理二进制文件
    | RunScripts                   // 运行脚本
    | Done                         // 完成

    public func isDone(): Bool {
        return this == InstallerTaskStep.Done
    }
}

// ============================================================================
// 脚本列表 (轻量引用)
// ============================================================================

/// 脚本列表
/// 对应 Bun: Package.Scripts.List
public class ScriptsList {
    public var items: ArrayList<?String>
    public var firstIndex: UInt8
    public var total: UInt8
    public var cwd: String
    public var packageName: String

    public init() {
        items = ArrayList<?String>()
        firstIndex = 0
        total = 0
        cwd = ""
        packageName = ""
    }
}

// ============================================================================
// 存储
// 严格翻译自: Store.zig - Store
//   pub const Store = struct { entries: Entry.List, nodes: Node.List }
// ============================================================================

/// 隔离安装存储
/// 对应 Bun: Store
/// 翻译自: src/install/isolated_install/Store.zig
public class Store {
    /// 模块目录名
    /// 翻译自: Store.modules_dir_name = ".bun"
    public static let MODULES_DIR_NAME: String = ".bun"

    /// 条目列表
    /// 翻译自: entries: Entry.List
    public var entries: ArrayList<StoreEntry>

    /// 节点列表
    /// 翻译自: nodes: Node.List
    public var nodes: ArrayList<StoreNode>

    public init() {
        entries = ArrayList<StoreEntry>()
        nodes = ArrayList<StoreNode>()
    }

    /// 检测循环依赖
    /// 严格翻译自: Store.isCycle
    ///   pub fn isCycle(this: *const Store, id, maybe_parent_id, parent_dedupe) bool
    ///   检查条目的父链中是否存在循环
    public func isCycle(id: EntryId, maybeParentId: EntryId, parentDedupe: HashSet<EntryId>): Bool {
        let entryParents = entries[Int64(id.get())].parents

        for (parentId in entryParents) {
            if (parentId == EntryId.INVALID) { continue }
            if (parentId == maybeParentId) { return true }
            parentDedupe.add(parentId)
        }

        var i: Int64 = 0
        var len: Int64 = parentDedupe.size
        while (i < len) {
            // 遍历 dedupe 中的键, 检查其父节点
            let keys = parentDedupe.toArray()
            if (Int64(i) >= keys.size) { break }
            let currentParents = entries[Int64(keys[Int64(i)].get())].parents

            for (parentId in currentParents) {
                if (parentId == EntryId.INVALID) { continue }
                if (parentId == maybeParentId) { return true }
                parentDedupe.add(parentId)
                len = parentDedupe.size
            }
            i += 1
        }

        return false
    }

    /// 格式化存储路径
    /// 翻译自: Store.Entry.fmtStorePath
    public func formatStorePath(entryId: EntryId): String {
        let entry = entries[Int64(entryId.get())]
        let nodeId = entry.nodeId
        if (Int64(nodeId.get()) >= nodes.size) { return "" }
        let node = nodes[Int64(nodeId.get())]
        return "entry#${entryId.get()}@node#${node.pkgId}"
    }
}
