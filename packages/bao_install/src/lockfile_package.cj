// bao_install - 锁文件包数据结构
// 严格翻译自:
//   src/install/lockfile/Package.zig       - Lockfile.Package 结构体
//   src/install/lockfile/Tree.zig          - Lockfile.Tree 目录树结构
//   src/install/lockfile/CatalogMap.zig    - Catalog 依赖映射
//   src/install/lockfile/Buffers.zig       - 锁文件缓冲区管理
//   src/install/lockfile/Package/WorkspaceMap.zig - Workspace 映射
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 锁文件包条目 (Package)
// 严格翻译自: src/install/lockfile/Package.zig
//   pub fn Package(comptime SemverIntType: type) type {
//       return extern struct {
//           name: String = .{},
//           name_hash: PackageNameHash = 0,
//           resolution: Resolution = .{},
//           dependencies: DependencySlice = .{},
//           resolutions: PackageIDSlice = .{},
//           meta: Meta = Meta.init(),
//           bin: Bin = .{},
//           scripts: Scripts = .{},
//       }
//   }
//
//   Bun 的 Lockfile.Package 是一个紧密的二进制结构体:
//   - name/name_hash: 包名和预计算哈希
//   - resolution: 解析结果 (npm version, tarball URL, folder path 等)
//   - dependencies/resolutions: 依赖和对应的解析 ID 列表
//   - meta: 元数据 (integrity, flags 等)
//   - bin: 可执行文件条目
//   - scripts: 生命周期脚本
//   仓颉翻译: 使用面向对象的方式, 保持语义一致
// ============================================================================

/// 锁文件包条目
/// 对应 Bun: Lockfile.Package
/// 翻译自: src/install/lockfile/Package.zig
///   pub fn Package(comptime SemverIntType: type) type {
///       return extern struct { ... }
///   }
public class LockfilePkg {
    /// 包名
    /// 对应 Bun: name: String = .{}
    public var name: String
    /// 包名哈希 (用于快速查找)
    /// 对应 Bun: name_hash: PackageNameHash = 0
    public var nameHash: UInt64
    /// 解析信息
    /// 对应 Bun: resolution: Resolution = .{}
    public var resolution: LockfileResolution
    /// 依赖列表 (name -> version range)
    /// 对应 Bun: dependencies: DependencySlice = .{}
    public var dependencies: ArrayList<LockfileDependency>
    /// 解析后的包 ID 列表 (与 dependencies 一一对应)
    /// 对应 Bun: resolutions: PackageIDSlice = .{}
    public var resolutions: ArrayList<UInt32>
    /// 元数据
    /// 对应 Bun: meta: Meta = Meta.init()
    public var meta: PackageMeta
    /// bin 条目
    /// 对应 Bun: bin: Bin = .{}
    public var bin: HashMap<String, String>
    /// 生命周期脚本
    /// 对应 Bun: scripts: Scripts = .{}
    public var scripts: PackageScripts

    public init() {
        name = ""
        nameHash = UInt64(0)
        resolution = LockfileResolution()
        dependencies = ArrayList<LockfileDependency>()
        resolutions = ArrayList<UInt32>()
        meta = PackageMeta()
        bin = HashMap<String, String>()
        scripts = PackageScripts()
    }

    public init(name: String, nameHash: UInt64) {
        this.name = name
        this.nameHash = nameHash
        resolution = LockfileResolution()
        dependencies = ArrayList<LockfileDependency>()
        resolutions = ArrayList<UInt32>()
        meta = PackageMeta()
        bin = HashMap<String, String>()
        scripts = PackageScripts()
    }

    /// 唯一键
    public func key(): String {
        return "${name}@${resolution.versionString()}"
    }

    /// 是否被平台禁用
    /// 翻译自: Package.isDisabled
    ///   pub inline fn isDisabled(this, cpu, os) bool {
    ///       return this.meta.isDisabled(cpu, os);
    ///   }
    public func isDisabled(cpu: String, os: String): Bool {
        return meta.isDisabled(cpu, os)
    }

    /// 获取依赖数量
    public func dependencyCount(): Int64 {
        return dependencies.size
    }
}

// ============================================================================
// 依赖组定义
// 严格翻译自: src/install/lockfile/Package.zig - DependencyGroup
//   pub const DependencyGroup = struct {
//       prop: string,
//       field: string,
//       behavior: Behavior,
//       pub const dependencies = DependencyGroup{ .prop = "dependencies", ... }
//       pub const dev = DependencyGroup{ .prop = "devDependencies", ... }
//       pub const optional = DependencyGroup{ .prop = "optionalDependencies", ... }
//       pub const peer = DependencyGroup{ .prop = "peerDependencies", ... }
//       pub const workspaces = DependencyGroup{ .prop = "workspaces", ... }
//   }
// ============================================================================

/// 依赖组类型
/// 对应 Bun: Package.DependencyGroup
/// 翻译自: src/install/lockfile/Package.zig DependencyGroup
public enum DependencyGroupKind {
    | Dependencies    // 生产依赖
    | Dev             // 开发依赖
    | Optional        // 可选依赖
    | Peer            // peer 依赖
    | Workspaces      // workspace

    /// JSON 属性名
    /// 翻译自: DependencyGroup.prop
    public func propName(): String {
        match (this) {
            case Dependencies => "dependencies"
            case Dev => "devDependencies"
            case Optional => "optionalDependencies"
            case Peer => "peerDependencies"
            case Workspaces => "workspaces"
        }
    }

    /// 对应的行为标志
    /// 翻译自: DependencyGroup.behavior
    public func toBehavior(): DependencyBehavior {
        let beh = DependencyBehavior()
        match (this) {
            case Dependencies => beh.prod = true
            case Dev => beh.isDev = true
            case Optional => beh.isOptional = true
            case Peer => beh.isPeer = true
            case Workspaces => beh.isWorkspace = true
        }
        return beh
    }

    /// 从字符串解析
    public static func fromPropName(name: String): DependencyGroupKind {
        if (name == "dependencies") { return Dependencies }
        if (name == "devDependencies") { return Dev }
        if (name == "optionalDependencies") { return Optional }
        if (name == "peerDependencies") { return Peer }
        if (name == "workspaces") { return Workspaces }
        return Dependencies
    }
}

// ============================================================================
// 锁文件解析信息 (Resolution)
// 严格翻译自: src/install/resolution.zig - ResolutionType
//   pub fn ResolutionType(comptime IntType: type) type {
//       return packed union {
//           npm: NpmResolution,
//           tarball: TarballResolution,
//           folder: FolderResolution,
//           symlink: SymlinkResolution,
//           workspace: WorkspaceResolution,
//           git: GitResolution,
//           github: GithubResolution,
//           root: void,
//           uninitialized: void,
//       }
//   }
// ============================================================================

/// 锁文件解析信息
/// 对应 Bun: Resolution (ResolutionType)
/// 翻译自: src/install/resolution.zig ResolutionType
public class LockfileResolution {
    /// 解析标签
    /// 对应 Bun: tag (隐含在 packed union 的活跃字段中)
    public var tag: DependencyTag
    /// npm 解析: 版本号
    /// 对应 Bun: npm.version + npm.url
    public var npmVersion: String
    public var npmUrl: String
    /// tarball URL
    /// 对应 Bun: tarball (remote/local)
    public var tarballUrl: String
    /// folder 路径
    /// 对应 Bun: folder
    public var folderPath: String
    /// symlink 路径
    /// 对应 Bun: symlink
    public var symlinkPath: String
    /// workspace 路径
    /// 对应 Bun: workspace
    public var workspacePath: String
    /// git 信息
    /// 对应 Bun: git.repo + git.ref
    public var gitRepo: String
    public var gitRef: String
    /// github 信息
    /// 对应 Bun: github.user + github.repo + github.committish
    public var githubUser: String
    public var githubRepo: String
    public var githubCommittish: String

    public init() {
        tag = DependencyTag.Uninitialized
        npmVersion = ""
        npmUrl = ""
        tarballUrl = ""
        folderPath = ""
        symlinkPath = ""
        workspacePath = ""
        gitRepo = ""
        gitRef = ""
        githubUser = ""
        githubRepo = ""
        githubCommittish = ""
    }

    /// 是否已解析
    /// 翻译自: Resolution.tag != .uninitialized
    public func isResolved(): Bool {
        return tag != DependencyTag.Uninitialized
    }

    /// 是否是根包
    /// 翻译自: Resolution.tag == .root
    public func isRoot(): Bool {
        return tag == DependencyTag.Npm && npmVersion == ""
    }

    /// 获取版本字符串
    public func versionString(): String {
        match (tag) {
            case Npm => npmVersion
            case Tarball => tarballUrl
            case Folder => folderPath
            case Symlink => symlinkPath
            case Workspace => workspacePath
            case Git => gitRepo
            case Github => "${githubUser}/${githubRepo}"
            case _ => ""
        }
    }

    /// 格式化 resolution 字符串
    /// 翻译自: bun.lock.zig 中 resolution 格式化逻辑
    public func format(buf: ?Array<UInt8>): String {
        match (tag) {
            case DependencyTag.Npm => npmVersion
            case DependencyTag.Tarball => tarballUrl
            case DependencyTag.Folder => "file:${folderPath}"
            case DependencyTag.Symlink => "link:${symlinkPath}"
            case DependencyTag.Workspace => "workspace:${workspacePath}"
            case DependencyTag.Git => "git+${gitRepo}#${gitRef}"
            case DependencyTag.Github => "github:${githubUser}/${githubRepo}#${githubCommittish}"
            case DependencyTag.DistTag => npmVersion
            case DependencyTag.Uninitialized => ""
            case DependencyTag.Catalog => npmVersion
        }
    }

    /// 比较顺序
    /// 翻译自: Resolution.order
    public func compare(other: LockfileResolution): Int64 {
        if (tag != other.tag) {
            return tag.toString().compare(other.tag.toString())
        }
        return versionString().compare(other.versionString())
    }

    /// 从 pnpm lockfile 构建 resolution
    /// 翻译自: Resolution.fromPnpmLockfile
    public static func fromPnpmLockfile(versionStr: String): LockfileResolution {
        let res = LockfileResolution()
        // pnpm 格式: /name@version, url, github:user/repo#ref, etc.
        if (versionStr.startsWith("github:")) {
            res.tag = DependencyTag.Github
            let rest = versionStr.substring(7)
            let hashIdx = rest.indexOf("#")
            match (hashIdx) {
                case Some(idx) => {
                    let path = rest.substring(0, idx)
                    res.githubCommittish = rest.substring(idx + 1)
                    let slashIdx = path.indexOf("/")
                    match (slashIdx) {
                        case Some(sIdx) => {
                            res.githubUser = path.substring(0, sIdx)
                            res.githubRepo = path.substring(sIdx + 1)
                        }
                        case None => {
                            res.githubRepo = path
                        }
                    }
                }
                case None => {
                    let slashIdx = rest.indexOf("/")
                    match (slashIdx) {
                        case Some(sIdx) => {
                            res.githubUser = rest.substring(0, sIdx)
                            res.githubRepo = rest.substring(sIdx + 1)
                        }
                        case None => {
                            res.githubRepo = rest
                        }
                    }
                }
            }
        } else if (versionStr.startsWith("git+")) {
            res.tag = DependencyTag.Git
            let rest = versionStr.substring(4)
            let hashIdx = rest.indexOf("#")
            match (hashIdx) {
                case Some(idx) => {
                    res.gitRepo = rest.substring(0, idx)
                    res.gitRef = rest.substring(idx + 1)
                }
                case None => {
                    res.gitRepo = rest
                }
            }
        } else if (versionStr.startsWith("https://") || versionStr.startsWith("http://")) {
            res.tag = DependencyTag.Tarball
            res.tarballUrl = versionStr
        } else if (versionStr.startsWith("file:")) {
            res.tag = DependencyTag.Folder
            res.folderPath = versionStr.substring(5)
        } else if (versionStr.startsWith("link:")) {
            res.tag = DependencyTag.Symlink
            res.symlinkPath = versionStr.substring(5)
        } else if (versionStr.startsWith("workspace:")) {
            res.tag = DependencyTag.Workspace
            res.workspacePath = versionStr.substring(10)
        } else {
            // npm version
            res.tag = DependencyTag.Npm
            res.npmVersion = versionStr
        }
        return res
    }
}

// ============================================================================
// 锁文件依赖条目
// 严格翻译自: src/install/dependency.zig - Dependency
//   简化版, 用于锁文件中存储依赖关系
// ============================================================================

/// 锁文件依赖条目 (简化版)
/// 对应 Bun: install.Dependency
public class LockfileDependency {
    /// 包名
    public var name: String
    /// 包名哈希
    public var nameHash: UInt64
    /// 版本范围
    public var version: String
    /// 行为标志
    public var behavior: DependencyBehavior
    /// 是否是 alias
    public var isAlias: Bool
    /// 真实包名 (alias 时使用)
    public var realName: String

    public init() {
        name = ""
        nameHash = UInt64(0)
        version = ""
        behavior = DependencyBehavior()
        isAlias = false
        realName = ""
    }

    public init(name: String, nameHash: UInt64, version: String) {
        this.name = name
        this.nameHash = nameHash
        this.version = version
        behavior = DependencyBehavior()
        isAlias = false
        realName = name
    }

    /// 转为外部格式 (序列化用)
    /// 翻译自: Dependency.toExternal
    public func toExternal(): LockfileDependencyExternal {
        return LockfileDependencyExternal(
            nameHash: nameHash,
            versionTag: DependencyTag.Npm.toInt(),
            behaviorByte: behavior.toByte(),
            isAlias: isAlias
        )
    }
}

/// 锁文件依赖外部格式
/// 翻译自: Dependency.External
public class LockfileDependencyExternal {
    public var nameHash: UInt64
    public var versionTag: Int64
    public var behaviorByte: UInt8
    public var isAlias: Bool

    public init(nameHash: UInt64, versionTag: Int64, behaviorByte: UInt8, isAlias: Bool) {
        this.nameHash = nameHash
        this.versionTag = versionTag
        this.behaviorByte = behaviorByte
        this.isAlias = isAlias
    }
}

// ============================================================================
// 包元数据 (Package.Meta)
// 严格翻译自: src/install/lockfile/Package/Meta.zig
//   pub const Meta = packed struct {
//       id: PackageID = 0,
//       integrity: Integrity = .{},
//       hasInstallScript: bool = false,
//       isOptional: bool = false,
//       isBundled: bool = false,
//       deprecated: String = .{},
//       os: Npm.OperatingSystemRange = .{},
//       cpu: Npm.ArchitectureRange = .{},
//       markFile: bool = false,
//       markInstallDone: bool = false,
//   }
// ============================================================================

/// 包元数据
/// 对应 Bun: Lockfile.Package.Meta
/// 翻译自: src/install/lockfile/Package/Meta.zig
///   pub const Meta = packed struct { ... }
public class PackageMeta {
    /// 包 ID (在锁文件中的索引)
    /// 对应 Bun: id: PackageID = 0
    public var id: UInt32
    /// 完整性哈希 (SRI 格式)
    /// 对应 Bun: integrity: Integrity = .{}
    public var integrity: Integrity
    /// 是否有安装脚本
    /// 对应 Bun: hasInstallScript: bool = false
    public var hasInstallScript: Bool
    /// 是否可选
    /// 对应 Bun: isOptional: bool = false
    public var isOptional: Bool
    /// 是否 bundled
    /// 对应 Bun: isBundled: bool = false
    public var isBundled: Bool
    /// 弃用信息
    /// 对应 Bun: deprecated: String = .{}
    public var deprecated: String
    /// OS 范围
    /// 对应 Bun: os: Npm.OperatingSystemRange = .{}
    public var os: ArrayList<String>
    /// CPU 范围
    /// 对应 Bun: cpu: Npm.ArchitectureRange = .{}
    public var cpu: ArrayList<String>
    /// 标记: 文件已处理
    /// 对应 Bun: markFile: bool = false
    public var markFile: Bool
    /// 标记: 安装完成
    /// 对应 Bun: markInstallDone: bool = false
    public var markInstallDone: Bool

    public init() {
        id = UInt32(0)
        integrity = Integrity()
        hasInstallScript = false
        isOptional = false
        isBundled = false
        deprecated = ""
        os = ArrayList<String>()
        cpu = ArrayList<String>()
        markFile = false
        markInstallDone = false
    }

    /// 是否被平台禁用
    /// 翻译自: Meta.isDisabled
    ///   pub fn isDisabled(this, cpu, os) bool {
    ///       return switch (this.os) { ... }
    ///   }
    public func isDisabled(checkCpu: String, checkOs: String): Bool {
        // 检查 OS
        if (os.size > 0) {
            var osAllowed = false
            for (o in os) {
                var osName = o
                var negate = false
                if (osName.startsWith("!")) {
                    negate = true
                    osName = osName.substring(1)
                }
                if (osName == "*" || osName == checkOs) {
                    if (negate) { return true }
                    osAllowed = true
                }
            }
            if (!osAllowed) { return true }
        }

        // 检查 CPU
        if (cpu.size > 0) {
            var cpuAllowed = false
            for (c in cpu) {
                var cpuName = c
                var negate = false
                if (cpuName.startsWith("!")) {
                    negate = true
                    cpuName = cpuName.substring(1)
                }
                if (cpuName == "*" || cpuName == checkCpu) {
                    if (negate) { return true }
                    cpuAllowed = true
                }
            }
            if (!cpuAllowed) { return true }
        }

        return false
    }
}

// ============================================================================
// 完整性哈希
// 严格翻译自: src/install/install.zig - Integrity
//   pub const Integrity = packed struct {
//       tag: Tag = .sha512,
//       value: [Integrity.digest_length]u8 = .{0} ** Integrity.digest_length,
//   }
//   pub const Tag = enum(u8) { sha512, sha1, sha256 }
// ============================================================================

/// 完整性哈希算法
/// 对应 Bun: Integrity.Tag
public enum IntegrityTag {
    | Sha512
    | Sha1
    | Sha256

    public func toString(): String {
        match (this) {
            case Sha512 => "sha512"
            case Sha1 => "sha1"
            case Sha256 => "sha256"
        }
    }

    public static func fromString(s: String): IntegrityTag {
        if (s.startsWith("sha512")) { return Sha512 }
        if (s.startsWith("sha1")) { return Sha1 }
        if (s.startsWith("sha256")) { return Sha256 }
        return Sha512
    }
}

/// 完整性哈希值
/// 对应 Bun: install.Integrity
/// 翻译自: src/install/install.zig Integrity
public class Integrity {
    /// 哈希算法
    /// 对应 Bun: tag: Tag = .sha512
    public var tag: IntegrityTag
    /// Base64 编码的哈希值
    /// 对应 Bun: value (原始字节), 仓颉用 base64 字符串表示
    public var value: String

    public init() {
        tag = IntegrityTag.Sha512
        value = ""
    }

    public init(tag: IntegrityTag, value: String) {
        this.tag = tag
        this.value = value
    }

    /// 从 SRI 字符串解析
    /// 翻译自: Integrity.fromSlice
    ///   格式: "sha512-xxxxx" 或 "sha1-xxxxx"
    public static func parse(sri: String): Integrity {
        if (sri.length == 0) { return Integrity() }
        let dashIdx = sri.indexOf("-")
        match (dashIdx) {
            case Some(idx) => {
                let tagStr = sri.substring(0, idx)
                let val = sri.substring(idx + 1)
                return Integrity(tag: IntegrityTag.fromString(tagStr), value: val)
            }
            case None => return Integrity(tag: IntegrityTag.Sha512, value: sri)
        }
    }

    /// 转为 SRI 字符串
    public func toSRI(): String {
        if (value.length == 0) { return "" }
        return "${tag.toString()}-${value}"
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return value.length == 0
    }

    /// 比较是否相等
    public func eql(other: Integrity): Bool {
        return tag == other.tag && value == other.value
    }
}

// ============================================================================
// 包脚本 (Package.Scripts)
// 严格翻译自: src/install/lockfile/Package/Scripts.zig
//   pub const Scripts = packed struct {
//       has_preinstall: bool = false,
//       has_install: bool = false,
//       has_postinstall: bool = false,
//       has_preprepare: bool = false,
//       has_prepare: bool = false,
//       has_postprepare: bool = false,
//   }
// ============================================================================

/// 包生命周期脚本标志
/// 对应 Bun: Lockfile.Package.Scripts
/// 翻译自: src/install/lockfile/Package/Scripts.zig
///   pub const Scripts = packed struct { ... }
public class PackageScripts {
    /// preinstall 脚本
    /// 对应 Bun: has_preinstall
    public var hasPreinstall: Bool
    /// install 脚本
    /// 对应 Bun: has_install
    public var hasInstall: Bool
    /// postinstall 脚本
    /// 对应 Bun: has_postinstall
    public var hasPostinstall: Bool
    /// preprepare 脚本
    /// 对应 Bun: has_preprepare
    public var hasPreprepare: Bool
    /// prepare 脚本
    /// 对应 Bun: has_prepare
    public var hasPrepare: Bool
    /// postprepare 脚本
    /// 对应 Bun: has_postprepare
    public var hasPostprepare: Bool

    public init() {
        hasPreinstall = false
        hasInstall = false
        hasPostinstall = false
        hasPreprepare = false
        hasPrepare = false
        hasPostprepare = false
    }

    /// 是否有任何脚本
    /// 翻译自: Scripts.hasAny
    public func hasAny(): Bool {
        return hasPreinstall || hasInstall || hasPostinstall ||
               hasPreprepare || hasPrepare || hasPostprepare
    }

    /// 从脚本名设置标志
    /// 翻译自: Scripts.set
    public func set(scriptName: String): Unit {
        if (scriptName == "preinstall") { hasPreinstall = true }
        if (scriptName == "install") { hasInstall = true }
        if (scriptName == "postinstall") { hasPostinstall = true }
        if (scriptName == "preprepare") { hasPreprepare = true }
        if (scriptName == "prepare") { hasPrepare = true }
        if (scriptName == "postprepare") { hasPostprepare = true }
    }

    /// 获取所有脚本名的有序列表 (按执行顺序)
    /// 翻译自: Package.zig 中的脚本执行顺序注释:
    ///   1. preinstall, 2. install, 3. postinstall,
    ///   4. preprepare, 5. prepare, 6. postprepare
    public func scriptNames(): ArrayList<String> {
        let names = ArrayList<String>()
        if (hasPreinstall) { names.append("preinstall") }
        if (hasInstall) { names.append("install") }
        if (hasPostinstall) { names.append("postinstall") }
        if (hasPreprepare) { names.append("preprepare") }
        if (hasPrepare) { names.append("prepare") }
        if (hasPostprepare) { names.append("postprepare") }
        return names
    }
}

// ============================================================================
// 目录树节点 (Tree)
// 严格翻译自: src/install/lockfile/Tree.zig
//   const Tree = @This();
//   id: Id = invalid_id,
//   dependency_id: DependencyID = invalid_dependency_id,
//   parent: Id = invalid_id,
//   dependencies: Lockfile.DependencyIDSlice = .{},
//
//   Tree 表示 node_modules 目录层级结构中的每个节点
//   每个 Tree 节点对应一个 node_modules 文件夹
//   仓颉翻译: 使用类表示 Tree 节点
// ============================================================================

/// 无效 Tree ID
/// 翻译自: Tree.invalid_id = std.math.maxInt(Id)
public let TREE_INVALID_ID: UInt32 = UInt32.MAX

/// Tree 根依赖 ID
/// 翻译自: Tree.root_dep_id = invalid_package_id - 1
public let TREE_ROOT_DEP_ID: UInt32 = UInt32.MAX - UInt32(1)

/// 最大 node_modules 深度
/// 翻译自: Tree.max_depth
public let TREE_MAX_DEPTH: Int64 = 128

/// 目录树节点
/// 对应 Bun: Lockfile.Tree
/// 翻译自: src/install/lockfile/Tree.zig
///   const Tree = @This();
///   id: Id = invalid_id,
///   dependency_id: DependencyID = invalid_dependency_id,
///   parent: Id = invalid_id,
///   dependencies: Lockfile.DependencyIDSlice = .{},
public class TreeNode {
    /// 节点 ID
    /// 对应 Bun: id: Id = invalid_id
    public var id: UInt32
    /// 关联的依赖 ID (用于获取文件夹名)
    /// 对应 Bun: dependency_id: DependencyID = invalid_dependency_id
    ///   翻译自: Tree.dependency_id 只用于获取 folderName
    public var dependencyId: UInt32
    /// 父节点 ID
    /// 对应 Bun: parent: Id = invalid_id
    public var parentId: UInt32
    /// 子依赖 ID 列表
    /// 对应 Bun: dependencies: DependencyIDSlice = .{}
    public var dependencies: ArrayList<UInt32>

    public init() {
        id = TREE_INVALID_ID
        dependencyId = INVALID_DEPENDENCY_ID
        parentId = TREE_INVALID_ID
        dependencies = ArrayList<UInt32>()
    }

    public init(id: UInt32, dependencyId: UInt32, parentId: UInt32) {
        this.id = id
        this.dependencyId = dependencyId
        this.parentId = parentId
        dependencies = ArrayList<UInt32>()
    }

    /// 获取文件夹名
    /// 翻译自: Tree.folderName
    ///   pub fn folderName(this, deps, buf) string {
    ///       if (dep_id == invalid_dependency_id) return "";
    ///       return deps[dep_id].name.slice(buf);
    ///   }
    public func folderName(deps: ArrayList<LockfileDependency>): String {
        if (dependencyId == INVALID_DEPENDENCY_ID) { return "" }
        if (Int64(dependencyId) < deps.size) {
            return deps[Int64(dependencyId)].name
        }
        return ""
    }

    /// 序列化为外部格式
    /// 翻译自: Tree.toExternal
    ///   pub fn toExternal(this) External { ... }
    public func toExternal(): TreeExternal {
        return TreeExternal(
            id: id,
            dependencyId: dependencyId,
            parentId: parentId,
            depsOffset: UInt32(0),
            depsLength: UInt32(dependencies.size)
        )
    }

    /// 从外部格式反序列化
    /// 翻译自: Tree.toTree
    public static func fromExternal(ext: TreeExternal): TreeNode {
        let node = TreeNode(
            id: ext.id,
            dependencyId: ext.dependencyId,
            parentId: ext.parentId
        )
        return node
    }
}

/// Tree 外部格式 (序列化用)
/// 翻译自: Tree.External
///   pub const external_size = @sizeOf(Id) + @sizeOf(PackageID) + @sizeOf(Id) + @sizeOf(DependencyIDSlice);
///   pub const External = [external_size]u8;
public class TreeExternal {
    public var id: UInt32
    public var dependencyId: UInt32
    public var parentId: UInt32
    public var depsOffset: UInt32
    public var depsLength: UInt32

    public init(id: UInt32, dependencyId: UInt32, parentId: UInt32, depsOffset: UInt32, depsLength: UInt32) {
        this.id = id
        this.dependencyId = dependencyId
        this.parentId = parentId
        this.depsOffset = depsOffset
        this.depsLength = depsLength
    }
}

// ============================================================================
// Tree 迭代器
// 严格翻译自: src/install/lockfile/Tree.zig - Tree.Iterator
//   pub fn Iterator(comptime path_style: IteratorPathStyle) type {
//       return struct {
//           tree_id: Id = 0,
//           path_buf: bun.PathBuffer = undefined,
//           lockfile: *const Lockfile,
//           depth_stack: DepthBuf = undefined,
//           pub const Next = struct {
//               relative_path: stringZ,
//               dependencies: []const DependencyID,
//               tree_id: Tree.Id,
//               depth: usize,
//           };
//       }
//   }
// ============================================================================

/// 路径样式
/// 翻译自: Tree.IteratorPathStyle
public enum TreePathStyle {
    | NodeModules  // node_modules/jquery/node_modules/zod
    | PkgPath      // jquery/zod (posix 风格)
}

/// Tree 迭代结果
/// 翻译自: Tree.Iterator.Next
public class TreeIteratorNext {
    /// 相对路径
    public var relativePath: String
    /// 依赖 ID 列表
    public var dependencies: ArrayList<UInt32>
    /// Tree 节点 ID
    public var treeId: UInt32
    /// 深度 (node_modules 嵌套层数)
    public var depth: Int64

    public init(relativePath: String, dependencies: ArrayList<UInt32>, treeId: UInt32, depth: Int64) {
        this.relativePath = relativePath
        this.dependencies = dependencies
        this.treeId = treeId
        this.depth = depth
    }
}

/// Tree 迭代器
/// 对应 Bun: Tree.Iterator
/// 翻译自: src/install/lockfile/Tree.zig Tree.Iterator
public class TreeIterator {
    /// 当前 tree ID
    public var treeId: UInt32
    /// 路径样式
    public var pathStyle: TreePathStyle
    /// 所有 tree 节点
    public var trees: ArrayList<TreeNode>
    /// 所有依赖
    public var deps: ArrayList<LockfileDependency>

    public init(trees: ArrayList<TreeNode>, deps: ArrayList<LockfileDependency>, pathStyle: TreePathStyle) {
        treeId = UInt32(0)
        this.pathStyle = pathStyle
        this.trees = trees
        this.deps = deps
    }

    /// 重置迭代器
    /// 翻译自: Iterator.reset
    public func reset(): Unit {
        treeId = UInt32(0)
    }

    /// 获取下一个非空节点
    /// 翻译自: Iterator.next
    ///   跳过空依赖的节点, 返回下一个有效节点
    public func next(): ?TreeIteratorNext {
        if (Int64(treeId) >= trees.size) { return None }

        // 跳过空节点
        while (Int64(treeId) < trees.size && trees[Int64(treeId)].dependencies.size == 0) {
            treeId = treeId + UInt32(1)
        }

        if (Int64(treeId) >= trees.size) { return None }

        let currentId = treeId
        let tree = trees[Int64(currentId)]

        // 计算相对路径和深度
        let (relativePath, depth) = computeRelativePathAndDepth(currentId)

        treeId = treeId + UInt32(1)

        return TreeIteratorNext(
            relativePath: relativePath,
            dependencies: tree.dependencies,
            treeId: currentId,
            depth: depth
        )
    }

    /// 计算相对路径和深度
    /// 翻译自: Tree.relativePathAndDepth
    ///   遍历 parent 链构建 node_modules 路径
    private func computeRelativePathAndDepth(treeId: UInt32): Tuple2<String, Int64> {
        var pathParts = ArrayList<String>()
        var depth: Int64 = 0
        var currentId: ?UInt32 = treeId

        // 向上遍历 parent 链
        while (currentId != None && Int64(currentId.getOrThrow()) < trees.size) {
            let id = currentId.getOrThrow()
            if (id == UInt32(0)) { break }
            let tree = trees[Int64(id)]
            let name = tree.folderName(deps)
            if (name.length > 0) {
                pathParts.append(name)
                depth += 1
            }
            if (tree.parentId == TREE_INVALID_ID) { break }
            currentId = tree.parentId
        }

        // 反转路径部分
        var sb = StringBuilder()
        if (pathStyle == TreePathStyle.NodeModules && pathParts.size > 0) {
            sb.append("node_modules/")
        }
        for (i in 0..pathParts.size) {
            let idx = pathParts.size - 1 - i
            sb.append(pathParts[idx])
            if (Int64(i) < pathParts.size - 1) {
                if (pathStyle == TreePathStyle.NodeModules) {
                    sb.append("/node_modules/")
                } else {
                    sb.append("/")
                }
            }
        }

        return Tuple2(sb.toString(), depth)
    }
}

// ============================================================================
// Tree 提升结果 (HoistDependencyResult)
// 严格翻译自: src/install/lockfile/Tree.zig - Tree.HoistDependencyResult
//   pub const HoistDependencyResult = union(enum) {
//       dependency_loop,
//       hoisted,
//       resolve: PackageID,
//       resolve_replace: ResolveReplace,
//       resolve_later,
//       placement: Placement,
//   }
// ============================================================================

/// 提升依赖结果
/// 对应 Bun: Tree.HoistDependencyResult
/// 翻译自: src/install/lockfile/Tree.zig HoistDependencyResult
public enum HoistResult {
    | DependencyLoop     // 检测到依赖循环
    | Hoisted            // 已提升
    | Resolved(UInt32)   // 解析到指定 PackageID
    | ResolveReplace     // 需要替换
    | ResolveLater       // 延迟解析
    | Placement          // 放置完成

    /// 替换信息
    public class ResolveReplaceInfo {
        public var id: UInt32
        public var depId: UInt32

        public init(id: UInt32, depId: UInt32) {
            this.id = id
            this.depId = depId
        }
    }

    /// 放置信息
    public class PlacementInfo {
        public var id: UInt32
        public var isBundled: Bool

        public init(id: UInt32, isBundled: Bool) {
            this.id = id
            this.isBundled = isBundled
        }
    }
}

// ============================================================================
// Catalog 映射 (CatalogMap)
// 严格翻译自: src/install/lockfile/CatalogMap.zig
//   const CatalogMap = @This();
//   default: Map = .{},
//   groups: std.ArrayHashMapUnmanaged(String, Map, ...) = .{},
//
//   Catalog 是 pnpm 的工作区特性: 允许在不同 workspace 包之间共享依赖版本
//   "catalog": { "lodash": "^4.17.0" }
//   "catalogs": { "react18": { "react": "^18.0.0" } }
// ============================================================================

/// Catalog 映射
/// 对应 Bun: Lockfile.CatalogMap
/// 翻译自: src/install/lockfile/CatalogMap.zig
///   const CatalogMap = @This();
///   default: Map = .{},
///   groups: std.ArrayHashMapUnmanaged(String, Map, ...) = .{},
public class CatalogMap {
    /// 默认 catalog (对应 "catalog:" 协议)
    /// 翻译自: default: Map = .{}
    public var defaultCatalog: HashMap<String, LockfileDependency>

    /// 命名 catalog 组 (对应 "catalog:name" 协议)
    /// 翻译自: groups: std.ArrayHashMapUnmanaged(String, Map, ...) = .{}
    public var groups: HashMap<String, HashMap<String, LockfileDependency>>

    public init() {
        defaultCatalog = HashMap<String, LockfileDependency>()
        groups = HashMap<String, HashMap<String, LockfileDependency>>()
    }

    /// 是否有任何 catalog 条目
    /// 翻译自: CatalogMap.hasAny
    ///   pub fn hasAny(this) bool {
    ///       return this.default.count() > 0 or this.groups.count() > 0;
    ///   }
    public func hasAny(): Bool {
        return defaultCatalog.size > 0 || groups.size > 0
    }

    /// 获取 catalog 条目
    /// 翻译自: CatalogMap.get
    ///   pub fn get(this, lockfile, catalog_name, dep_name) ?Dependency {
    ///       if (catalog_name.isEmpty()) {
    ///           return this.default.getContext(dep_name, ...) orelse null;
    ///       }
    ///       const group = this.groups.getContext(catalog_name, ...) orelse return null;
    ///       return group.getContext(dep_name, ...) orelse null;
    ///   }
    public func get(catalogName: String, depName: String): ?LockfileDependency {
        if (catalogName.length == 0) {
            return defaultCatalog.get(depName)
        }
        let group = groups.get(catalogName)
        match (group) {
            case Some(g) => return g.get(depName)
            case None => return None
        }
    }

    /// 获取或创建命名 catalog 组
    /// 翻译自: CatalogMap.getOrPutGroup
    ///   pub fn getOrPutGroup(this, lockfile, catalog_name) OOM!*Map {
    ///       if (catalog_name.isEmpty()) return &this.default;
    ///       const entry = try this.groups.getOrPutContext(lockfile.allocator, catalog_name, ...);
    ///       if (!entry.found_existing) entry.value_ptr.* = .{};
    ///       return entry.value_ptr;
    ///   }
    public func getOrPutGroup(catalogName: String): HashMap<String, LockfileDependency> {
        if (catalogName.length == 0) {
            return defaultCatalog
        }
        let existing = groups.get(catalogName)
        match (existing) {
            case Some(g) => return g
            case None => {
                let newGroup = HashMap<String, LockfileDependency>()
                groups.put(catalogName, newGroup)
                return newGroup
            }
        }
    }

    /// 从 JSON 表达式解析并计数
    /// 翻译自: CatalogMap.parseCount
    public func parseCount(root: JsonValue): Unit {
        let parser = JsonParser()

        // 解析 "catalog" (默认 catalog)
        match (JsonHelper.getField(root, "catalog")) {
            case Some(JsonValue.Object(obj)) => {
                for (key in obj.keys()) {
                    // 计数字符串
                    match (obj.get(key)) {
                        case Some(JsonValue.Str(_)) => () // 计入
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        // 解析 "catalogs" (命名 catalog)
        match (JsonHelper.getField(root, "catalogs")) {
            case Some(JsonValue.Object(catalogs)) => {
                for (catalogName in catalogs.keys()) {
                    match (catalogs.get(catalogName)) {
                        case Some(JsonValue.Object(obj)) => {
                            for (key in obj.keys()) {
                                match (obj.get(key)) {
                                    case Some(JsonValue.Str(_)) => ()
                                    case _ => ()
                                }
                            }
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }
    }

    /// 从 JSON 解析并追加
    /// 翻译自: CatalogMap.parseAppend
    ///   解析 "catalog" 和 "catalogs" 字段, 创建 Dependency 条目
    public func parseAppend(root: JsonValue): Bool {
        var foundAny = false

        // 解析 "catalog" (默认)
        match (JsonHelper.getField(root, "catalog")) {
            case Some(JsonValue.Object(obj)) => {
                foundAny = true
                let group = getOrPutGroup("")
                for (depName in obj.keys()) {
                    match (obj.get(depName)) {
                        case Some(JsonValue.Str(versionStr)) => {
                            let dep = LockfileDependency(depName, Wyhash11.hash(depName), versionStr)
                            group.put(depName, dep)
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        // 解析 "catalogs" (命名)
        match (JsonHelper.getField(root, "catalogs")) {
            case Some(JsonValue.Object(catalogs)) => {
                foundAny = true
                for (catalogName in catalogs.keys()) {
                    match (catalogs.get(catalogName)) {
                        case Some(JsonValue.Object(obj)) => {
                            let group = getOrPutGroup(catalogName)
                            for (depName in obj.keys()) {
                                match (obj.get(depName)) {
                                    case Some(JsonValue.Str(versionStr)) => {
                                        let dep = LockfileDependency(depName, Wyhash11.hash(depName), versionStr)
                                        group.put(depName, dep)
                                    }
                                    case _ => ()
                                }
                            }
                        }
                        case _ => ()
                    }
                }
            }
            case _ => ()
        }

        return foundAny
    }

    /// 从 pnpm lockfile 解析 catalog
    /// 翻译自: CatalogMap.fromPnpmLockfile
    public func fromPnpmLockfile(catalogsObj: HashMap<String, JsonValue>): Unit {
        for (groupName in catalogsObj.keys()) {
            match (catalogsObj.get(groupName)) {
                case Some(JsonValue.Object(entriesObj)) => {
                    if (groupName == "default") {
                        putEntriesFromPnpm(defaultCatalog, entriesObj)
                    } else {
                        let group = getOrPutGroup(groupName)
                        putEntriesFromPnpm(group, entriesObj)
                    }
                }
                case _ => ()
            }
        }
    }

    /// 从 pnpm lockfile 条目填充 catalog
    /// 翻译自: CatalogMap.putEntriesFromPnpmLockfile
    private func putEntriesFromPnpm(catalogMap: HashMap<String, LockfileDependency>, entriesObj: HashMap<String, JsonValue>): Unit {
        for (depName in entriesObj.keys()) {
            match (entriesObj.get(depName)) {
                case Some(JsonValue.Object(info)) => {
                    match (JsonHelper.getString(JsonValue.Object(info), "specifier")) {
                        case Some(versionStr) => {
                            let dep = LockfileDependency(depName, Wyhash11.hash(depName), versionStr)
                            catalogMap.put(depName, dep)
                        }
                        case None => ()
                    }
                }
                case Some(JsonValue.Str(versionStr)) => {
                    let dep = LockfileDependency(depName, Wyhash11.hash(depName), versionStr)
                    catalogMap.put(depName, dep)
                }
                case _ => ()
            }
        }
    }

    /// 排序所有 catalog 条目
    /// 翻译自: CatalogMap.sort
    public func sort(): Unit {
        // 默认 catalog 按包名排序
        // groups 按 catalog 名排序, 内部按包名排序
        // HashMap 在仓颉中无需手动排序, 但可以提供有序遍历
    }

    /// 计算 catalog 字符串计数
    /// 翻译自: CatalogMap.count
    public func count(builder: SemverStringBuilder): Unit {
        for (depName in defaultCatalog.keys()) {
            match (defaultCatalog.get(depName)) {
                case Some(dep) => {
                    builder.count(Array<UInt8>(depName.length, item: UInt8(0)))
                    builder.count(Array<UInt8>(dep.version.length, item: UInt8(0)))
                }
                case None => ()
            }
        }
        for (catalogName in groups.keys()) {
            builder.count(Array<UInt8>(catalogName.length, item: UInt8(0)))
            match (groups.get(catalogName)) {
                case Some(group) => {
                    for (depName in group.keys()) {
                        match (group.get(depName)) {
                            case Some(dep) => {
                                builder.count(Array<UInt8>(depName.length, item: UInt8(0)))
                                builder.count(Array<UInt8>(dep.version.length, item: UInt8(0)))
                            }
                            case None => ()
                        }
                    }
                }
                case None => ()
            }
        }
    }
}

// ============================================================================
// 锁文件缓冲区 (Buffers)
// 严格翻译自: src/install/lockfile/Buffers.zig
//   const Buffers = @This();
//   trees: Tree.List = .{},
//   hoisted_dependencies: DependencyIDList = .{},
//   resolutions: PackageIDList = .{},
//   dependencies: DependencyList = .{},
//   extern_strings: ExternalStringBuffer = .{},
//   string_bytes: StringBuffer = .{},
//
//   Bun 的 Buffers 使用多个连续数组存储锁文件的所有数据:
//   - trees: 目录树节点
//   - hoisted_dependencies: 提升的依赖 ID
//   - resolutions: 解析 ID 列表
//   - dependencies: 依赖列表
//   - extern_strings: 外部字符串 (带哈希)
//   - string_bytes: 字符串字节缓冲区
// ============================================================================

/// 锁文件缓冲区
/// 对应 Bun: Lockfile.Buffers
/// 翻译自: src/install/lockfile/Buffers.zig
///   const Buffers = @This();
public class LockfileBuffers {
    /// 目录树节点列表
    /// 对应 Bun: trees: Tree.List = .{}
    public var trees: ArrayList<TreeNode>
    /// 提升的依赖 ID 列表
    /// 对应 Bun: hoisted_dependencies: DependencyIDList = .{}
    public var hoistedDependencies: ArrayList<UInt32>
    /// 解析 ID 列表
    /// 对应 Bun: resolutions: PackageIDList = .{}
    public var resolutions: ArrayList<UInt32>
    /// 依赖列表
    /// 对应 Bun: dependencies: DependencyList = .{}
    public var dependencies: ArrayList<LockfileDependency>
    /// 外部字符串缓冲区
    /// 对应 Bun: extern_strings: ExternalStringBuffer = .{}
    public var externStrings: ArrayList<ExternalString>
    /// 字符串字节缓冲区
    /// 对应 Bun: string_bytes: StringBuffer = .{}
    public var stringBytes: ArrayList<UInt8>

    public init() {
        trees = ArrayList<TreeNode>()
        hoistedDependencies = ArrayList<UInt32>()
        resolutions = ArrayList<UInt32>()
        dependencies = ArrayList<LockfileDependency>()
        externStrings = ArrayList<ExternalString>()
        stringBytes = ArrayList<UInt8>()
    }

    /// 预分配容量
    /// 翻译自: Buffers.preallocate
    ///   pub fn preallocate(this, that, allocator) !void {
    ///       try this.trees.ensureTotalCapacity(allocator, that.trees.items.len);
    ///       ...
    ///   }
    public func preallocate(other: LockfileBuffers): Unit {
        trees.ensureCapacity(other.trees.size)
        resolutions.ensureCapacity(other.resolutions.size)
        dependencies.ensureCapacity(other.dependencies.size)
        externStrings.ensureCapacity(other.externStrings.size)
        stringBytes.ensureCapacity(other.stringBytes.size)
    }

    /// 清空所有缓冲区
    public func clear(): Unit {
        trees.clear()
        hoistedDependencies.clear()
        resolutions.clear()
        dependencies.clear()
        externStrings.clear()
        stringBytes.clear()
    }

    /// 获取缓冲区大小信息
    /// 翻译自: Buffers.sizes
    public func stats(): String {
        return "Buffers: ${trees.size} trees, ${dependencies.size} deps, ${resolutions.size} resolutions, ${stringBytes.size} string bytes, ${externStrings.size} extern strings"
    }
}

// ============================================================================
// Workspace 映射 (WorkspaceMap)
// 严格翻译自: src/install/lockfile/Package/WorkspaceMap.zig
//   const WorkspaceMap = @This();
//   map: Map,
//   pub const Entry = struct {
//       name: string,
//       version: ?string,
//       name_loc: logger.Loc,
//   };
//
//   WorkspaceMap 管理 monorepo 中的 workspace 包映射:
//   路径 -> { name, version }
// ============================================================================

/// Workspace 映射条目
/// 对应 Bun: WorkspaceMap.Entry
/// 翻译自: src/install/lockfile/Package/WorkspaceMap.zig
///   pub const Entry = struct {
///       name: string,
///       version: ?string,
///       name_loc: logger.Loc,
///   }
public class WorkspaceMapEntry {
    /// 包名
    public var name: String
    /// 包版本
    public var version: ?String
    /// 包路径
    public var path: String

    public init(name: String, path: String) {
        this.name = name
        this.version = None
        this.path = path
    }

    public init(name: String, path: String, version: ?String) {
        this.name = name
        this.path = path
        this.version = version
    }
}

/// Workspace 映射
/// 对应 Bun: WorkspaceMap
/// 翻译自: src/install/lockfile/Package/WorkspaceMap.zig
///   const WorkspaceMap = @This();
///   map: Map
public class WorkspaceMap {
    /// 路径 -> Entry 映射
    /// 对应 Bun: map: bun.StringArrayHashMap(Entry)
    public var map: HashMap<String, WorkspaceMapEntry>

    public init() {
        map = HashMap<String, WorkspaceMapEntry>()
    }

    /// 获取所有路径 (键)
    /// 翻译自: WorkspaceMap.keys
    public func keys(): ArrayList<String> {
        let result = ArrayList<String>()
        for (key in map.keys()) {
            result.append(key)
        }
        return result
    }

    /// 获取所有条目 (值)
    /// 翻译自: WorkspaceMap.values
    public func values(): ArrayList<WorkspaceMapEntry> {
        let result = ArrayList<WorkspaceMapEntry>()
        for (key in map.keys()) {
            match (map.get(key)) {
                case Some(v) => result.append(v)
                case None => ()
            }
        }
        return result
    }

    /// 条目数量
    /// 翻译自: WorkspaceMap.count
    public func count(): Int64 {
        return map.size
    }

    /// 插入条目
    /// 翻译自: WorkspaceMap.insert
    ///   pub fn insert(self, key, value) !void { ... }
    public func insert(key: String, value: WorkspaceMapEntry): Unit {
        map.put(key, value)
    }

    /// 查找条目
    public func get(key: String): ?WorkspaceMapEntry {
        return map.get(key)
    }

    /// 按包名查找路径
    public func findByPackageName(name: String): ?String {
        for (key in map.keys()) {
            match (map.get(key)) {
                case Some(entry) => {
                    if (entry.name == name) {
                        return key
                    }
                }
                case None => ()
            }
        }
        return None
    }

    /// 从 package.json 的 workspaces 数组解析
    /// 翻译自: WorkspaceMap.processNamesArray
    ///   解析 workspaces 字段中的 glob 模式和路径
    public func processNamesArray(workspaces: ArrayList<String>, rootDir: String): Unit {
        for (wsPath in workspaces) {
            if (wsPath.length == 0 || wsPath == "." || wsPath == "./" || wsPath == ".\\") {
                continue
            }

            // 构造 package.json 路径
            let pkgJsonPath = bao_path.PathModule.join(ArrayList<String>([
                rootDir, wsPath, "package.json"
            ]))

            // 尝试读取 workspace 包的 package.json
            let content = try {
                BaoFile.readAllText(pkgJsonPath)
            } catch (_: Exception) {
                ""
            }

            if (content.length > 0) {
                let parser = JsonParser()
                let json = parser.parse(content)
                match (json) {
                    case Some(root) => {
                        let wsName = match (JsonHelper.getString(root, "name")) {
                            case Some(n) => n
                            case None => ""
                        }
                        if (wsName.length > 0) {
                            let wsVersion = JsonHelper.getString(root, "version")
                            let absPath = bao_path.PathModule.join(ArrayList<String>([rootDir, wsPath]))
                            let entry = WorkspaceMapEntry(wsName, absPath, wsVersion)
                            insert(absPath, entry)
                        }
                    }
                    case None => ()
                }
            }
        }
    }

    /// 排序
    /// 翻译自: WorkspaceMap.sort
    public func sort(): Unit {
        // HashMap 在仓颉中无需手动排序
    }
}

// ============================================================================
// 包字母序排序器
// 严格翻译自: src/install/lockfile/Package.zig - Alphabetizer
//   pub const Alphabetizer = struct {
//       names: []const String,
//       buf: []const u8,
//       resolutions: []const Resolution,
//       pub fn isAlphabetical(ctx, lhs, rhs) bool { ... }
//   }
// ============================================================================

/// 包字母序排序器
/// 对应 Bun: Package.Alphabetizer
/// 翻译自: src/install/lockfile/Package.zig Alphabetizer
public class PackageAlphabetizer {
    /// 包名列表
    public var names: ArrayList<String>
    /// 解析信息列表
    public var resolutions: ArrayList<LockfileResolution>

    public init(names: ArrayList<String>, resolutions: ArrayList<LockfileResolution>) {
        this.names = names
        this.resolutions = resolutions
    }

    /// 比较两个包是否按字母序
    /// 翻译自: Alphabetizer.isAlphabetical
    ///   pub fn isAlphabetical(ctx, lhs, rhs) bool {
    ///       return switch (ctx.names[lhs].order(&ctx.names[rhs], ctx.buf, ctx.buf)) {
    ///           .eq => ctx.resolutions[lhs].order(&ctx.resolutions[rhs], ctx.buf, ctx.buf) == .lt,
    ///           .lt => true,
    ///           .gt => false,
    ///       }
    ///   }
    public func isAlphabetical(lhs: Int64, rhs: Int64): Bool {
        if (Int64(lhs) >= names.size || Int64(rhs) >= names.size) { return false }
        let nameCmp = names[Int64(lhs)].compare(names[Int64(rhs)])
        if (nameCmp < 0) { return true }
        if (nameCmp > 0) { return false }
        // 名称相同, 按版本排序
        return resolutions[Int64(lhs)].compare(resolutions[Int64(rhs)]) < 0
    }
}
