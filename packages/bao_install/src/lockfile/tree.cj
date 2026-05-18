// bao_install.lockfile - 锁文件目录树
// 严格翻译自: src/install/lockfile/Tree.zig
//   Tree 表示 node_modules 的目录结构
//   每个节点对应一个 node_modules 文件夹
//   包含: id, dependency_id, parent, dependencies (切片)
package bao_install.lockfile

import bao_install.*
import bao_core.*
import bao_collections.*

// ============================================================================
// 目录树节点
// 严格翻译自: Tree.zig — Tree struct
//   pub const Tree = struct {
//       id: Id = invalid_id,
//       dependency_id: DependencyID = invalid_dependency_id,
//       parent: Id = invalid_id,
//       dependencies: Lockfile.DependencyIDSlice = .{},
//   }
//   Tree 构建了 node_modules 的层级结构
//   每个 Tree 节点代表一个 node_modules 文件夹
//   通过 parent 形成 tree 结构
// ============================================================================

/// 目录树节点
/// 对应 Bun: Lockfile.Tree
/// 翻译自: src/install/lockfile/Tree.zig
public class Tree {
    /// 节点 ID
    /// 翻译自: id: Id = invalid_id
    ///   Tree.Id = u32
    public var id: UInt32

    /// 关联的依赖 ID
    /// 翻译自: dependency_id: DependencyID = invalid_dependency_id
    ///   仅用于获取 folderName, 不保证与依赖版本一致
    public var dependencyId: UInt32

    /// 父节点 ID
    /// 翻译自: parent: Id = invalid_id
    public var parent: UInt32

    /// 依赖列表 (切片)
    /// 翻译自: dependencies: Lockfile.DependencyIDSlice = .{}
    ///   包含此 node_modules 文件夹中的所有依赖
    public var dependencies: DependencyIDSlice

    public init() {
        id = Tree.INVALID_ID
        dependencyId = INVALID_PACKAGE_ID
        parent = Tree.INVALID_ID
        dependencies = DependencyIDSlice()
    }

    public init(id: UInt32, dependencyId: UInt32, parent: UInt32) {
        this.id = id
        this.dependencyId = dependencyId
        this.parent = parent
        dependencies = DependencyIDSlice()
    }

    /// 无效 ID
    /// 翻译自: Tree.invalid_id = std.math.maxInt(Id)
    public static let INVALID_ID: UInt32 = UInt32.MAX

    /// 根依赖 ID
    /// 翻译自: Tree.root_dep_id = invalid_package_id - 1
    public static let ROOT_DEP_ID: UInt32 = UInt32.MAX - UInt32(1)

    /// 最大深度 (node_modules 嵌套层数)
    /// 翻译自: Tree.max_depth = (bun.MAX_PATH_BYTES / "node_modules".len) + 1
    public static let MAX_DEPTH: Int64 = 260  // 近似值

    // ========================================================================
    // 文件夹名称
    // 严格翻译自: Tree.folderName
    //   pub fn folderName(this, deps, buf) string
    //   通过 dependency_id 查找依赖的名称
    // ========================================================================

    /// 获取文件夹名称
    /// 翻译自: Tree.folderName
    ///   通过关联的 dependency_id 获取依赖名称
    ///   如果 dependency_id 无效, 返回空字符串
    public func folderName(deps: ArrayList<TreeDependencyInfo>, stringBuf: String): String {
        let depId = dependencyId
        if (depId == INVALID_PACKAGE_ID) { return "" }
        if (Int64(depId) >= deps.size) { return "" }
        return deps[Int64(depId)].name
    }

    // ========================================================================
    // 序列化
    // 严格翻译自: Tree.toExternal / Tree.toTree
    //   Tree.External = [external_size]u8 = [20]u8
    //   toExternal: 将 Tree 序列化为 20 字节
    //     [0..4]  = id (u32 LE)
    //     [4..8]  = dependency_id (u32 LE)
    //     [8..12] = parent (u32 LE)
    //     [12..16] = dependencies.off (u32 LE)
    //     [16..20] = dependencies.len (u32 LE)
    // ========================================================================

    /// 序列化为字节数组
    /// 翻译自: Tree.toExternal
    ///   external_size = @sizeOf(Id) + @sizeOf(PackageID) + @sizeOf(Id) + @sizeOf(DependencyIDSlice) = 20
    public func toExternal(): Array<UInt8> {
        let out = Array<UInt8>(20, repeat: UInt8(0))
        // id (4 bytes LE)
        out[0] = UInt8(id & UInt32(0xFF))
        out[1] = UInt8((id >> 8) & UInt32(0xFF))
        out[2] = UInt8((id >> 16) & UInt32(0xFF))
        out[3] = UInt8((id >> 24) & UInt32(0xFF))
        // dependency_id (4 bytes LE)
        out[4] = UInt8(dependencyId & UInt32(0xFF))
        out[5] = UInt8((dependencyId >> 8) & UInt32(0xFF))
        out[6] = UInt8((dependencyId >> 16) & UInt32(0xFF))
        out[7] = UInt8((dependencyId >> 24) & UInt32(0xFF))
        // parent (4 bytes LE)
        out[8] = UInt8(parent & UInt32(0xFF))
        out[9] = UInt8((parent >> 8) & UInt32(0xFF))
        out[10] = UInt8((parent >> 16) & UInt32(0xFF))
        out[11] = UInt8((parent >> 24) & UInt32(0xFF))
        // dependencies.off (4 bytes LE)
        out[12] = UInt8(dependencies.offset & UInt32(0xFF))
        out[13] = UInt8((dependencies.offset >> 8) & UInt32(0xFF))
        out[14] = UInt8((dependencies.offset >> 16) & UInt32(0xFF))
        out[15] = UInt8((dependencies.offset >> 24) & UInt32(0xFF))
        // dependencies.len (4 bytes LE)
        out[16] = UInt8(dependencies.length & UInt32(0xFF))
        out[17] = UInt8((dependencies.length >> 8) & UInt32(0xFF))
        out[18] = UInt8((dependencies.length >> 16) & UInt32(0xFF))
        out[19] = UInt8((dependencies.length >> 24) & UInt32(0xFF))
        return out
    }

    /// 从字节数组反序列化
    /// 翻译自: Tree.toTree
    public static func fromExternal(data: Array<UInt8>): Tree {
        let tree = Tree()
        if (data.size < 20) { return tree }
        // id
        tree.id = UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[3]) << 24)
        // dependency_id
        tree.dependencyId = UInt32(data[4]) | (UInt32(data[5]) << 8) | (UInt32(data[6]) << 16) | (UInt32(data[7]) << 24)
        // parent
        tree.parent = UInt32(data[8]) | (UInt32(data[9]) << 8) | (UInt32(data[10]) << 16) | (UInt32(data[11]) << 24)
        // dependencies.off
        tree.dependencies.offset = UInt32(data[12]) | (UInt32(data[13]) << 8) | (UInt32(data[14]) << 16) | (UInt32(data[15]) << 24)
        // dependencies.len
        tree.dependencies.length = UInt32(data[16]) | (UInt32(data[17]) << 8) | (UInt32(data[18]) << 16) | (UInt32(data[19]) << 24)
        return tree
    }
}

// ============================================================================
// 依赖 ID 切片
// 严格翻译自: Lockfile.DependencyIDSlice
//   ExternalSlice(DependencyID) = struct { off: u32, len: u32 }
// ============================================================================

/// 依赖 ID 切片
/// 翻译自: DependencyIDSlice
public class DependencyIDSlice {
    public var offset: UInt32
    public var length: UInt32

    public init() {
        offset = UInt32(0)
        length = UInt32(0)
    }

    public init(offset: UInt32, length: UInt32) {
        this.offset = offset
        this.length = length
    }

    public func isEmpty(): Bool {
        return length == UInt32(0)
    }

    public func clone(): DependencyIDSlice {
        return DependencyIDSlice(offset, length)
    }
}

// ============================================================================
// Hoist 依赖结果
// 严格翻译自: Tree.HoistDependencyResult
//   pub const HoistDependencyResult = union(enum) {
//       dependency_loop,
//       hoisted,
//       resolve: PackageID,
//       resolve_replace: ResolveReplace,
//       resolve_later,
//       placement: Placement,
//   }
// ============================================================================

/// Hoist 依赖结果
/// 翻译自: Tree.HoistDependencyResult
public enum HoistResult {
    | DependencyLoop
    | Hoisted
    | Resolved(UInt32)
    | ResolveReplace(UInt32, UInt32)  // (tree_id, dep_id)
    | ResolveLater
    | Placement(UInt32, Bool)  // (tree_id, bundled)

    /// 创建 Placement 结果
    public static func placement(id: UInt32, bundled: Bool): HoistResult {
        return HoistResult.Placement(id, bundled)
    }
}

// ============================================================================
// 依赖信息 (简化)
// ============================================================================

/// 依赖信息
public class TreeDependencyInfo {
    public var name: String
    public var version: String

    public init(name: String) {
        this.name = name
        version = ""
    }
}
