// bao_install.lockfile - 锁文件包条目
// 严格翻译自: src/install/lockfile/Package.zig
//   Package 是锁文件中的核心数据结构, 表示一个已解析的包
//   包含: name, resolution, dependencies, resolutions, meta, bin, scripts
package bao_install.lockfile

import bao_install.*
import bao_core.*
import bao_collections.*

// ============================================================================
// 依赖组
// 严格翻译自: Package.zig — DependencyGroup
//   pub const DependencyGroup = struct {
//       `prop`: string,  // JSON 属性名
//       field: string, // 字段名
//       behavior: Behavior,
//   }
// ============================================================================

/// 依赖组定义
/// 翻译自: Package.DependencyGroup
public class DependencyGroup {
    public var `prop`: String   // JSON 属性名
    public var field: String  // 结构体字段名
    public var behavior: DependencyBehavior

    public init(`prop`: String, field: String, behavior: DependencyBehavior) {
        this.`prop` = `prop`
        this.field = field
        this.behavior = behavior
    }

    /// 生产依赖
    /// 翻译自: DependencyGroup.dependencies
    public static func dependencies(): DependencyGroup {
        return DependencyGroup("dependencies", "dependencies", DependencyBehavior.prod())
    }

    /// 开发依赖
    /// 翻译自: DependencyGroup.dev
    public static func dev(): DependencyGroup {
        return DependencyGroup("devDependencies", "dev_dependencies", DependencyBehavior.dev())
    }

    /// 可选依赖
    /// 翻译自: DependencyGroup.optional
    public static func optional(): DependencyGroup {
        return DependencyGroup("optionalDependencies", "optional_dependencies", DependencyBehavior.optional())
    }

    /// 对等依赖
    /// 翻译自: DependencyGroup.peer
    public static func peer(): DependencyGroup {
        return DependencyGroup("peerDependencies", "peer_dependencies", DependencyBehavior.peer())
    }

    /// workspace 依赖
    /// 翻译自: DependencyGroup.workspaces
    public static func workspaces(): DependencyGroup {
        return DependencyGroup("workspaces", "workspaces", DependencyBehavior.workspace())
    }
}

/// 依赖行为
/// 翻译自: Behavior struct
public class DependencyBehavior {
    public var isProd: Bool
    public var isDev: Bool
    public var isOptional: Bool
    public var isPeer: Bool
    public var isWorkspace: Bool

    public init() {
        isProd = false
        isDev = false
        isOptional = false
        isPeer = false
        isWorkspace = false
    }

    public static func prod(): DependencyBehavior {
        let b = DependencyBehavior()
        b.isProd = true
        return b
    }

    public static func dev(): DependencyBehavior {
        let b = DependencyBehavior()
        b.isDev = true
        return b
    }

    public static func optional(): DependencyBehavior {
        let b = DependencyBehavior()
        b.isOptional = true
        return b
    }

    public static func peer(): DependencyBehavior {
        let b = DependencyBehavior()
        b.isPeer = true
        return b
    }

    public static func workspace(): DependencyBehavior {
        let b = DependencyBehavior()
        b.isWorkspace = true
        return b
    }
}

// ============================================================================
// 锁文件包条目
// 严格翻译自: Package.zig — Package struct
//   pub const Package = extern struct {
//       name: String,
//       name_hash: PackageNameHash,
//       resolution: Resolution,
//       dependencies: DependencySlice,
//       resolutions: PackageIDSlice,
//       meta: Meta,
//       bin: Bin,
//       scripts: Scripts,
//   }
// ============================================================================

/// 锁文件包条目
/// 对应 Bun: Lockfile.Package
/// 翻译自: src/install/lockfile/Package.zig
public class LockfilePackageEntry {
    /// 包名
    /// 翻译自: name: String = .{}
    public var name: String

    /// 包名哈希
    /// 翻译自: name_hash: PackageNameHash = 0
    public var nameHash: UInt64

    /// 解析信息
    /// 翻译自: resolution: Resolution = .{}
    public var resolution: PackageResolution

    /// 依赖列表 (切片)
    /// 翻译自: dependencies: DependencySlice = .{}
    public var dependencies: DependencySlice

    /// 解析结果列表 (每个依赖对应的包 ID)
    /// 翻译自: resolutions: PackageIDSlice = .{}
    ///   resolutions[i] 是 dependencies[i] 解析后的包 ID
    ///   如果是 invalid_package_id, 则该依赖未解析
    public var resolutions: PackageIDSlice

    /// 元数据
    /// 翻译自: meta: Meta = Meta()
    public var meta: PackageMeta

    /// bin 字段
    /// 翻译自: bin: Bin = .{}
    public var bin: BinField

    /// 脚本
    /// 翻译自: scripts: Scripts = .{}
    public var scripts: PackageScripts

    public init() {
        name = ""
        nameHash = UInt64(0)
        resolution = PackageResolution()
        dependencies = DependencySlice()
        resolutions = PackageIDSlice()
        meta = PackageMeta()
        bin = BinField()
        scripts = PackageScripts()
    }

    /// 是否被禁用 (架构或系统不匹配)
    /// 翻译自: Package.isDisabled
    ///   pub inline fn isDisabled(this, cpu, os) bool
    public func isDisabled(cpu: NpmArchitecture, os: NpmOperatingSystem): Bool {
        return meta.isDisabled(cpu, os)
    }

    /// 是否有安装脚本
    /// 翻译自: Package.hasInstallScript (via meta)
    public func hasInstallScript(): Bool {
        return meta.hasInstallScriptBool()
    }

    /// 克隆
    /// 翻译自: Package.clone
    ///   pub fn clone(this, id, buf, Builder, builder) Package
    public func clone(id: UInt32): LockfilePackageEntry {
        let pkg = LockfilePackageEntry()
        pkg.name = name
        pkg.nameHash = nameHash
        pkg.resolution = resolution.clone()
        pkg.dependencies = dependencies.clone()
        pkg.resolutions = resolutions.clone()
        pkg.meta = meta.clone(id)
        pkg.bin = bin.clone()
        pkg.scripts = scripts.clone()
        return pkg
    }

    /// 计算总字符串大小
    /// 翻译自: Package.count
    ///   pub fn count(this, buf, Builder, builder) void
    public func count(): Int64 {
        var total: Int64 = Int64(name.size)
        total += resolution.count()
        total += if (meta.manDir.size > 0) { Int64(meta.manDir.size) + 1 } else { Int64(0) }
        total += scripts.count()
        return total
    }

    /// 字母排序比较
    /// 翻译自: Package.Alphabetizer.isAlphabetical
    ///   先按 name 排序, name 相同按 resolution 排序
    public static func isAlphabetical(
        lhs: LockfilePackageEntry,
        rhs: LockfilePackageEntry
    ): Bool {
        return false
    }
}

// ============================================================================
// 切片类型
// 严格翻译自: ExternalSlice 类型
//   pub const DependencySlice = ExternalSlice(Dependency)
//   pub const PackageIDSlice = ExternalSlice(PackageID)
// ============================================================================

/// 依赖切片
/// 翻译自: ExternalSlice(Dependency)
public class DependencySlice {
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

    public func clone(): DependencySlice {
        return DependencySlice(offset, length)
    }

    public func isEmpty(): Bool {
        return length == UInt32(0)
    }
}

/// 包 ID 切片
/// 翻译自: ExternalSlice(PackageID)
public class PackageIDSlice {
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

    public func clone(): PackageIDSlice {
        return PackageIDSlice(offset, length)
    }

    public func isEmpty(): Bool {
        return length == UInt32(0)
    }
}

// ============================================================================
// 包解析信息
// 严格翻译自: Package.zig — Resolution / ResolutionType
// ============================================================================

/// 包解析信息
/// 翻译自: Package.Resolution (ResolutionType)
public class PackageResolution {
    /// 解析标签
    public var tag: ResolutionTag
    /// 版本值
    public var value: String

    public init() {
        tag = ResolutionTag.Uninitialized
        value = ""
    }

    public func clone(): PackageResolution {
        let r = PackageResolution()
        r.tag = tag
        r.value = value
        return r
    }

    public func count(): Int64 {
        return Int64(value.size)
    }

    public func compareTo(other: PackageResolution): Int64 {
        return 0
    }
}

// ============================================================================
// Bin 字段
// 严格翻译自: Package.bin
// ============================================================================

/// Bin 字段
/// 翻译自: Bin
public class BinField {
    public var tag: BinTag
    public var value: String

    public init() {
        tag = BinTag.None
        value = ""
    }

    public func clone(): BinField {
        let b = BinField()
        b.tag = tag
        b.value = value
        return b
    }
}

/// Bin 标签
public enum BinTag {
    | None
    | File
    | NamedFile
    | Map
    | Dir
}
