// bao_install - 锁文件依赖树
// 严格翻译自: src/install/lockfile/Tree.zig
//   pub const Tree = struct {
//       id: Id = invalid_id,
//       dependency_id: DependencyID = invalid_dependency_id,
//       parent: Id = invalid_id,
//       dependencies: Lockfile.DependencyIDSlice = .{},
//   }
//   Tree 用于表示 node_modules 的嵌套结构 (hoisted install 模式)
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 依赖 ID 切片
// 严格翻译自: Lockfile.DependencyIDSlice
//   { off: u32, len: u32 }
// ============================================================================

/// 依赖 ID 切片
/// 翻译自: Lockfile.DependencyIDSlice
public class DependencyIDSlice {
    /// 偏移量
    public var off: UInt32
    /// 长度
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }

    /// 起始位置
    public func begin(): Int64 {
        return Int64(off)
    }

    /// 结束位置
    public func end(): Int64 {
        return Int64(off) + Int64(len)
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == UInt32(0)
    }
}

// ============================================================================
// 提升依赖结果
// 严格翻译自: Tree.zig - HoistDependencyResult
//   pub const HoistDependencyResult = union(enum) {
//       dependency_loop, hoisted, resolve: PackageID,
//       resolve_replace: ResolveReplace, resolve_later, placement: Placement,
//   }
// ============================================================================

/// 提升依赖结果
/// 翻译自: Tree.HoistDependencyResult
public enum HoistDependencyResult {
    | DependencyLoop           // 检测到循环依赖
    | Hoisted                  // 已提升到父级
    | Resolve(UInt32)          // 解析到包 ID
    | ResolveReplace(UInt32, UInt32)  // (tree_id, dep_id) 替换解析
    | ResolveLater             // 延迟解析
    | Placement(UInt32, Bool)  // (tree_id, bundled)
}

// ============================================================================
// 依赖树节点
// 严格翻译自: src/install/lockfile/Tree.zig - Tree
//   const Tree = @This();
//   id: Id = invalid_id,
//   dependency_id: DependencyID = invalid_dependency_id,
//   parent: Id = invalid_id,
//   dependencies: Lockfile.DependencyIDSlice = .{},
// ============================================================================

/// 依赖树节点
/// 对应 Bun: Lockfile.Tree
/// 用于表示 node_modules 的嵌套结构
/// 翻译自: src/install/lockfile/Tree.zig
public class LockfileTreeNode {
    /// 节点 ID
    /// 翻译自: id: Id = invalid_id
    public var id: UInt32

    /// 关联的依赖 ID (仅用于获取名称)
    /// 翻译自: dependency_id: DependencyID = invalid_dependency_id
    public var dependencyId: UInt32

    /// 父节点 ID
    /// 翻译自: parent: Id = invalid_id
    public var parent: UInt32

    /// 依赖列表切片
    /// 翻译自: dependencies: Lockfile.DependencyIDSlice = .{}
    public var dependencies: DependencyIDSlice

    /// 无效 ID
    /// 翻译自: Tree.invalid_id = maxInt(Id)
    public static let INVALID_ID: UInt32 = UInt32.MAX

    /// 根依赖 ID
    /// 翻译自: Tree.root_dep_id = invalid_package_id - 1
    public static let ROOT_DEP_ID: UInt32 = UInt32.MAX - UInt32(1)

    /// 最大深度
    /// 翻译自: Tree.max_depth
    public static let MAX_DEPTH: Int64 = 256

    public init() {
        id = LockfileTreeNode.INVALID_ID
        dependencyId = INVALID_DEPENDENCY_ID
        parent = LockfileTreeNode.INVALID_ID
        dependencies = DependencyIDSlice()
    }

    public init(id: UInt32, depId: UInt32, parent: UInt32, deps: DependencyIDSlice) {
        this.id = id
        this.dependencyId = depId
        this.parent = parent
        this.dependencies = deps
    }

    /// 获取文件夹名称 (依赖名)
    /// 翻译自: Tree.folderName
    ///   pub fn folderName(this, deps, buf) string
    public func folderName(deps: ArrayList<DependencyInfo>, buf: String): String {
        if (dependencyId == INVALID_DEPENDENCY_ID) { return "" }
        if (Int64(dependencyId) < deps.size) {
            return deps[Int64(dependencyId)].name
        }
        return ""
    }

    /// 序列化为外部格式 (20 字节)
    /// 翻译自: Tree.toExternal
    ///   External 大小 = sizeOf(Id) + sizeOf(PackageID) + sizeOf(Id) + sizeOf(DependencyIDSlice) = 20 bytes
    public func toExternal(): Array<UInt8> {
        let out = Array<UInt8>(20, item: UInt8(0))
        writeU32LE(out, 0, id)
        writeU32LE(out, 4, dependencyId)
        writeU32LE(out, 8, parent)
        writeU32LE(out, 12, dependencies.off)
        writeU32LE(out, 16, dependencies.len)
        return out
    }

    /// 从外部格式反序列化
    /// 翻译自: Tree.toTree
    public static func fromExternal(data: Array<UInt8>): LockfileTreeNode {
        let node = LockfileTreeNode()
        node.id = readU32LE(data, 0)
        node.dependencyId = readU32LE(data, 4)
        node.parent = readU32LE(data, 8)
        node.dependencies = DependencyIDSlice(readU32LE(data, 12), readU32LE(data, 16))
        return node
    }

    // 辅助: 写入 UInt32 LE
    private static func writeU32LE(buf: Array<UInt8>, offset: Int64, value: UInt32): Unit {
        buf[offset] = UInt8(value & UInt32(0xFF))
        buf[offset + 1] = UInt8((value >> 8) & UInt32(0xFF))
        buf[offset + 2] = UInt8((value >> 16) & UInt32(0xFF))
        buf[offset + 3] = UInt8((value >> 24) & UInt32(0xFF))
    }

    // 辅助: 读取 UInt32 LE
    private static func readU32LE(buf: Array<UInt8>, offset: Int64): UInt32 {
        return UInt32(buf[offset]) |
               (UInt32(buf[offset + 1]) << 8) |
               (UInt32(buf[offset + 2]) << 16) |
               (UInt32(buf[offset + 3]) << 24)
    }
}

// ============================================================================
// 依赖树迭代器
// 严格翻译自: Tree.zig - Iterator
//   pub fn Iterator(comptime path_style) type { ... }
// ============================================================================

/// 路径风格
/// 翻译自: Tree.IteratorPathStyle
public enum TreeIteratorPathStyle {
    | NodeModules   // node_modules/jquery/node_modules/zod (平台分隔符)
    | PkgPath       // jquery/zod (posix 分隔符)
}

/// 依赖树迭代器结果
/// 翻译自: Iterator.Next
public class TreeIteratorNext {
    /// 相对路径
    public var relativePath: String
    /// 依赖 ID 列表
    public var dependencies: ArrayList<UInt32>
    /// 树节点 ID
    public var treeId: UInt32
    /// 深度
    public var depth: Int64

    public init(relativePath: String, dependencies: ArrayList<UInt32>, treeId: UInt32, depth: Int64) {
        this.relativePath = relativePath
        this.dependencies = dependencies
        this.treeId = treeId
        this.depth = depth
    }
}

/// 依赖树迭代器
/// 翻译自: Tree.Iterator
public class LockfileTreeIterator {
    /// 当前树节点 ID
    public var treeId: Int64
    /// 路径风格
    public var pathStyle: TreeIteratorPathStyle
    /// 树节点列表
    public var trees: ArrayList<LockfileTreeNode>
    /// 依赖列表
    public var dependencies: ArrayList<DependencyInfo>
    /// 已完成树节点集合
    public var completedTrees: HashSet<UInt32>

    public init(trees: ArrayList<LockfileTreeNode>, dependencies: ArrayList<DependencyInfo>) {
        treeId = 0
        pathStyle = TreeIteratorPathStyle.NodeModules
        this.trees = trees
        this.dependencies = dependencies
        completedTrees = HashSet<UInt32>()
    }

    /// 重置迭代器
    /// 翻译自: Iterator.reset
    public func reset(): Unit {
        treeId = 0
    }

    /// 获取下一个有依赖的树节点
    /// 翻译自: Iterator.next
    public func next(): ?TreeIteratorNext {
        if (treeId >= trees.size) { return None }

        // 跳过没有依赖的节点
        while (treeId < trees.size && trees[treeId].dependencies.isEmpty()) {
            completedTrees.add(trees[treeId].id)
            treeId += 1
        }

        if (treeId >= trees.size) { return None }

        let currentTreeId = UInt32(treeId)
        let tree = trees[treeId]

        // 计算相对路径和深度
        let (relativePath, depth) = computePathAndDepth(tree)

        treeId += 1

        let depIds = ArrayList<UInt32>()
        var i: Int64 = tree.dependencies.begin()
        while (i < tree.dependencies.end()) {
            depIds.append(UInt32(i))
            i += 1
        }

        return TreeIteratorNext(relativePath, depIds, currentTreeId, depth)
    }

    /// 计算相对路径和深度
    /// 翻译自: Tree.relativePathAndDepth
    private func computePathAndDepth(tree: LockfileTreeNode): Tuple2<String, Int64> {
        if (tree.id == UInt32(0)) {
            return Tuple2("node_modules", 0)
        }

        var depth: Int64 = 0
        var parts = ArrayList<String>()
        var currentId = tree.id

        while (currentId > UInt32(0) && Int64(currentId) < trees.size) {
            let node = trees[Int64(currentId)]
            let folderName = node.folderName(dependencies, "")
            if (folderName.length > 0) {
                parts.append(folderName)
            }
            currentId = node.parent
            depth += 1
        }

        // 反转并构建路径
        parts.reverse()
        let sb = StringBuilder()
        match (pathStyle) {
            case NodeModules => {
                sb.append("node_modules/")
                var first = true
                for (part in parts) {
                    if (!first) { sb.append("/node_modules/") }
                    sb.append(part)
                    first = false
                }
            }
            case PkgPath => {
                var first = true
                for (part in parts) {
                    if (!first) { sb.append("/") }
                    sb.append(part)
                    first = false
                }
            }
        }

        return Tuple2(sb.toString(), depth)
    }
}
