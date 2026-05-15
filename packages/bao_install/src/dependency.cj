// bao_install - 依赖关系类型
// 严格翻译自: src/install/dependency.zig
//   pub const Dependency = struct { name_hash, name, version, behavior }
//   pub const Version = struct { tag, literal, value }
//   pub const Behavior = packed struct(u8) { prod, optional, dev, peer, workspace, bundled }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 依赖行为标志 (位域)
// 严格翻译自: src/install/dependency.zig - Behavior
//   pub const Behavior = packed struct(u8) {
//       _unused_1: u1 = 0,
//       prod: bool = false,
//       optional: bool = false,
//       dev: bool = false,
//       peer: bool = false,
//       workspace: bool = false,
//       bundled: bool = false,
//       _unused_2: u1 = 0,
//   }
// ============================================================================

/// 依赖行为标志位域
/// 对应 Bun: Dependency.Behavior
/// 位布局: [unused1(1)] [prod(1)] [optional(1)] [dev(1)] [peer(1)] [workspace(1)] [bundled(1)] [unused2(1)]
public class DependencyBehavior {
    public var prod: Bool
    public var optional: Bool
    public var dev: Bool
    public var peer: Bool
    public var workspace: Bool
    public var bundled: Bool

    public init() {
        prod = false
        optional = false
        dev = false
        peer = false
        workspace = false
        bundled = false
    }

    public init(prod: Bool, optional: Bool, dev: Bool, peer: Bool, workspace: Bool, bundled: Bool) {
        this.prod = prod
        this.optional = optional
        this.dev = dev
        this.peer = peer
        this.workspace = workspace
        this.bundled = bundled
    }

    /// 编码为 UInt8 位域
    /// 翻译自: Behavior 使用 @bitCast 转换
    public func toByte(): UInt8 {
        var b: UInt8 = 0
        if (prod) { b = b | UInt8(2) }       // bit 1
        if (optional) { b = b | UInt8(4) }   // bit 2
        if (dev) { b = b | UInt8(8) }         // bit 3
        if (peer) { b = b | UInt8(16) }       // bit 4
        if (workspace) { b = b | UInt8(32) }  // bit 5
        if (bundled) { b = b | UInt8(64) }    // bit 6
        return b
    }

    /// 从 UInt8 位域解码
    public static func fromByte(b: UInt8): DependencyBehavior {
        let beh = DependencyBehavior()
        beh.prod = (b & UInt8(2)) != UInt8(0)
        beh.optional = (b & UInt8(4)) != UInt8(0)
        beh.dev = (b & UInt8(8)) != UInt8(0)
        beh.peer = (b & UInt8(16)) != UInt8(0)
        beh.workspace = (b & UInt8(32)) != UInt8(0)
        beh.bundled = (b & UInt8(64)) != UInt8(0)
        return beh
    }

    /// 是否是生产依赖
    /// 翻译自: Behavior.isProd
    public func isProd(): Bool {
        return prod
    }

    /// 是否是可选依赖 (非 peer 的 optional)
    /// 翻译自: Behavior.isOptional
    public func isOptional(): Bool {
        return optional && !peer
    }

    /// 是否是可选 peer 依赖
    /// 翻译自: Behavior.isOptionalPeer
    public func isOptionalPeer(): Bool {
        return optional && peer
    }

    /// 是否是开发依赖
    /// 翻译自: Behavior.isDev
    public func isDev(): Bool {
        return dev
    }

    /// 是否是 peer 依赖
    /// 翻译自: Behavior.isPeer
    public func isPeer(): Bool {
        return peer
    }

    /// 是否是 workspace 依赖
    /// 翻译自: Behavior.isWorkspace
    public func isWorkspace(): Bool {
        return workspace
    }

    /// 是否是 bundled 依赖
    /// 翻译自: Behavior.isBundled
    public func isBundled(): Bool {
        return bundled
    }

    /// 相等比较
    /// 翻译自: Behavior.eq
    public func eq(other: DependencyBehavior): Bool {
        return toByte() == other.toByte()
    }

    /// 包含关系 (位与)
    /// 翻译自: Behavior.includes
    public func includes(other: DependencyBehavior): Bool {
        return (toByte() & other.toByte()) != UInt8(0)
    }

    /// 添加行为标志
    /// 翻译自: Behavior.add
    public func add(kind: String): DependencyBehavior {
        let result = DependencyBehavior.fromByte(toByte())
        match (kind) {
            case "prod" => result.prod = true
            case "optional" => result.optional = true
            case "dev" => result.dev = true
            case "peer" => result.peer = true
            case "workspace" => result.workspace = true
            case "bundled" => result.bundled = true
            case _ => ()
        }
        return result
    }

    /// 设置行为标志
    /// 翻译自: Behavior.set
    public func set(kind: String, value: Bool): DependencyBehavior {
        let result = DependencyBehavior.fromByte(toByte())
        match (kind) {
            case "prod" => result.prod = value
            case "optional" => result.optional = value
            case "dev" => result.dev = value
            case "peer" => result.peer = value
            case "workspace" => result.workspace = value
            case "bundled" => result.bundled = value
            case _ => ()
        }
        return result
    }

    /// 排序比较
    /// 翻译自: Behavior.cmp
    /// 排序优先级: workspace > dev > optional > prod > peer
    public func compare(other: DependencyBehavior): Int64 {
        if (eq(other)) { return 0 }
        if (isWorkspace() != other.isWorkspace()) {
            return if (isWorkspace()) { -1 } else { 1 }
        }
        if (isDev() != other.isDev()) {
            return if (isDev()) { -1 } else { 1 }
        }
        if (isOptional() != other.isOptional()) {
            return if (isOptional()) { -1 } else { 1 }
        }
        if (isProd() != other.isProd()) {
            return if (isProd()) { -1 } else { 1 }
        }
        if (isPeer() != other.isPeer()) {
            return if (isPeer()) { -1 } else { 1 }
        }
        return 0
    }

    /// 是否是必需的
    /// 翻译自: Behavior.isRequired
    public func isRequired(): Bool {
        return !isOptional()
    }

    /// 是否在给定特性下启用
    /// 翻译自: Behavior.isEnabled
    public func isEnabled(features: InstallFeatures): Bool {
        return isProd() ||
            (features.optionalDependencies && isOptional()) ||
            (features.devDependencies && isDev()) ||
            (features.peerDependencies && isPeer()) ||
            (features.workspaces && isWorkspace())
    }
}

// ============================================================================
// 安装特性标志
// 严格翻译自: src/install/install.zig - Features
//   pub const Features = struct {
//       dependencies: bool = true,
//       dev_dependencies: bool = false,
//       is_main: bool = false,
//       optional_dependencies: bool = false,
//       peer_dependencies: bool = true,
//       trusted_dependencies: bool = false,
//       workspaces: bool = false,
//       patched_dependencies: bool = false,
//       check_for_duplicate_dependencies: bool = false,
//   }
// ============================================================================

/// 安装特性标志
/// 对应 Bun: install.Features
public class InstallFeatures {
    public var dependencies: Bool
    public var devDependencies: Bool
    public var isMain: Bool
    public var optionalDependencies: Bool
    public var peerDependencies: Bool
    public var trustedDependencies: Bool
    public var workspaces: Bool
    public var patchedDependencies: Bool
    public var checkForDuplicateDependencies: Bool

    public init() {
        dependencies = true
        devDependencies = false
        isMain = false
        optionalDependencies = false
        peerDependencies = true
        trustedDependencies = false
        workspaces = false
        patchedDependencies = false
        checkForDuplicateDependencies = false
    }

    /// 主包特性
    /// 翻译自: Features.main
    public static func mainFeatures(): InstallFeatures {
        let f = InstallFeatures()
        f.checkForDuplicateDependencies = true
        f.devDependencies = true
        f.isMain = true
        f.optionalDependencies = true
        f.trustedDependencies = true
        f.patchedDependencies = true
        f.workspaces = true
        return f
    }

    /// 文件夹特性
    /// 翻译自: Features.folder
    public static func folderFeatures(): InstallFeatures {
        let f = InstallFeatures()
        f.devDependencies = true
        f.optionalDependencies = true
        return f
    }

    /// workspace 特性
    /// 翻译自: Features.workspace
    public static func workspaceFeatures(): InstallFeatures {
        let f = InstallFeatures()
        f.devDependencies = true
        f.optionalDependencies = true
        f.trustedDependencies = true
        return f
    }

    /// link 特性
    /// 翻译自: Features.link
    public static func linkFeatures(): InstallFeatures {
        let f = InstallFeatures()
        f.dependencies = false
        f.peerDependencies = false
        return f
    }

    /// npm 特性
    /// 翻译自: Features.npm
    public static func npmFeatures(): InstallFeatures {
        let f = InstallFeatures()
        f.optionalDependencies = true
        return f
    }

    /// 将特性转为 Behavior 编码
    /// 翻译自: Features.behavior
    public func toBehavior(): UInt8 {
        var out: UInt8 = 0
        if (dependencies) { out = out | UInt8(2) }
        if (optionalDependencies) { out = out | UInt8(4) }
        if (devDependencies) { out = out | UInt8(8) }
        if (peerDependencies) { out = out | UInt8(16) }
        if (workspaces) { out = out | UInt8(32) }
        return out
    }
}

// ============================================================================
// 依赖版本标签
// 严格翻译自: src/install/dependency.zig - Version.Tag
// ============================================================================

/// 依赖版本标签
public enum DependencyVersionTag {
    | Uninitialized  // 0
    | Npm            // 1 - semver range
    | DistTag        // 2 - npm dist tag (latest, next, etc.)
    | Tarball        // 3 - URI to .tgz or .tar.gz
    | Folder         // 4 - local folder
    | Symlink        // 5 - link:path
    | Workspace      // 6 - workspace:*
    | Git            // 7 - git repository
    | Github         // 8 - github:owner/repo
    | Catalog        // 9 - catalog:

    public func toInt(): Int64 {
        match (this) {
            case Uninitialized => 0
            case Npm => 1
            case DistTag => 2
            case Tarball => 3
            case Folder => 4
            case Symlink => 5
            case Workspace => 6
            case Git => 7
            case Github => 8
            case Catalog => 9
        }
    }

    public static func fromInt(v: Int64): DependencyVersionTag {
        match (v) {
            case 0 => Uninitialized
            case 1 => Npm
            case 2 => DistTag
            case 3 => Tarball
            case 4 => Folder
            case 5 => Symlink
            case 6 => Workspace
            case 7 => Git
            case 8 => Github
            case 9 => Catalog
            case _ => Uninitialized
        }
    }

    /// 是否是 NPM 相关类型 (tag < 3)
    /// 翻译自: Tag.isNPM
    public func isNPM(): Bool {
        return toInt() < 3
    }

    /// 是否可以排队安装任务
    /// 翻译自: Tag.canEnqueueInstallTask
    public func canEnqueueInstallTask(): Bool {
        match (this) {
            case Npm => true
            | Tarball => true
            | Git => true
            | Github => true
            | _ => false
        }
    }

    /// 从依赖字符串推断类型
    /// 翻译自: Dependency.Version.Tag.infer
    public static func infer(dependency: String): DependencyVersionTag {
        if (dependency.length == 0) { return DistTag }

        let c = dependency[0]

        // ^, =, >, <, *, | -> npm semver range
        if (c == '=' || c == '>' || c == '<' || c == '^' || c == '*' || c == '|') {
            return Npm
        }

        // ./path or ../path
        if (c == '.') {
            if (isTarballExt(dependency)) { return Tarball }
            return Folder
        }

        // ~1.2.3 or ~/path
        if (c == '~') {
            if (dependency.length > 1 && dependency[1] == '/') {
                if (isTarballExt(dependency)) { return Tarball }
                return Folder
            }
            return Npm
        }

        // /absolute/path
        if (c == '/') {
            if (isTarballExt(dependency)) { return Tarball }
            return Folder
        }

        // 0-9: version number or 123.tar.gz
        if (c >= '0' && c <= '9') {
            if (isTarballExt(dependency)) { return Tarball }
            return Npm
        }

        // file: prefix
        if (dependency.startsWith("file:")) {
            if (isTarballExt(dependency)) { return Tarball }
            return Folder
        }

        // catalog: prefix
        if (dependency.startsWith("catalog:")) {
            return Catalog
        }

        // git/github
        if (dependency.startsWith("git")) {
            if (dependency.startsWith("git+ssh:") || dependency.startsWith("git+file:")) {
                return Git
            }
            if (dependency.startsWith("git+http")) {
                return Git
            }
            if (dependency.startsWith("git://")) {
                return Git
            }
            if (dependency.startsWith("github:")) {
                // git+hub: -> github shorthand
                return Github
            }
        }

        // github:user/repo
        if (dependency.startsWith("github:")) {
            return Github
        }

        // http/https
        if (dependency.startsWith("http://") || dependency.startsWith("https://")) {
            return Tarball
        }

        // ssh://
        if (dependency.startsWith("ssh://")) {
            return Git
        }

        // link: prefix
        if (dependency.startsWith("link:")) {
            return Symlink
        }

        // npm: alias
        if (dependency.startsWith("npm:")) {
            return Npm
        }

        // workspace: prefix
        if (dependency.startsWith("workspace:")) {
            return Workspace
        }

        // v1.2.3
        if (c == 'v' && dependency.length > 1) {
            let next = dependency[1]
            if (next >= '0' && next <= '9') {
                return Npm
            }
        }

        // x or X (wildcard)
        if (c == 'x' || c == 'X') {
            return Npm
        }

        // patch: prefix
        if (dependency.startsWith("patch:")) {
            return Npm
        }

        // tarball extension check
        if (isTarballExt(dependency)) { return Tarball }

        // SCP-like path: user@host:path
        if (isSCPLikePath(dependency)) { return Git }

        // dist-tag (e.g. "latest", "next", "beta")
        if (!dependency.contains("|")) {
            return DistTag
        }

        return Npm
    }

    /// 检测 tarball 扩展名
    /// 翻译自: Dependency.isTarball
    public static func isTarballExt(s: String): Bool {
        return s.endsWith(".tgz") || s.endsWith(".tar.gz")
    }

    /// 是否是远程 tarball
    /// 翻译自: Dependency.isRemoteTarball
    public static func isRemoteTarball(s: String): Bool {
        return s.startsWith("https://") || s.startsWith("http://")
    }

    /// 是否是 SCP 风格路径
    /// 翻译自: Dependency.isSCPLikePath
    public static func isSCPLikePath(dependency: String): Bool {
        if (dependency.length < 3) { return false }
        var atIndex: Int64 = -1
        var i: Int64 = 0
        while (i < dependency.length) {
            let c = dependency[i]
            if (c == '@') {
                if (atIndex < 0) { atIndex = i }
            } else if (c == ':') {
                // 跳过 ://
                if (i + 2 < dependency.length && dependency[Int64(i) + 1] == '/' && dependency[Int64(i) + 2] == '/') {
                    return false
                }
                return i > atIndex + 1 && atIndex >= 0
            } else if (c == '/') {
                return if (atIndex >= 0) { i > atIndex + 1 } else { false }
            }
            i += 1
        }
        return false
    }
}

// ============================================================================
// URI 类型 (本地/远程)
// 严格翻译自: src/install/dependency.zig - URI
//   pub const URI = union(Tag) { local: String, remote: String }
// ============================================================================

/// URI 联合类型
public class DependencyURI {
    public var isLocal: Bool
    public var value: String

    public init(local: String) {
        isLocal = true
        value = local
    }

    public init(remote: String, isLocal: Bool) {
        this.isLocal = false
        this.value = remote
    }

    public func eql(other: DependencyURI): Bool {
        if (isLocal != other.isLocal) { return false }
        return value == other.value
    }
}

// ============================================================================
// 依赖版本信息
// 严格翻译自: src/install/dependency.zig - Version.Value (union)
//   pub const Value = union {
//       uninitialized: void,
//       npm: NpmInfo,
//       dist_tag: TagInfo,
//       tarball: TarballInfo,
//       folder: String,
//       symlink: String,
//       workspace: String,
//       git: Repository,
//       github: Repository,
//       catalog: String,
//   }
// ============================================================================

/// NPM 版本信息
/// 翻译自: Version.NpmInfo
public class NpmVersionInfo {
    /// 包名 (可能与 alias 不同)
    public var name: String
    /// semver 查询组
    public var versionRange: String
    /// 是否是 alias
    public var isAlias: Bool

    public init(name: String, versionRange: String) {
        this.name = name
        this.versionRange = versionRange
        isAlias = false
    }

    public init(name: String, versionRange: String, isAlias: Bool) {
        this.name = name
        this.versionRange = versionRange
        this.isAlias = isAlias
    }
}

/// Dist-Tag 版本信息
/// 翻译自: Version.TagInfo
public class DistTagVersionInfo {
    public var name: String
    public var tag: String

    public init(name: String, tag: String) {
        this.name = name
        this.tag = tag
    }
}

/// Tarball 版本信息
/// 翻译自: Version.TarballInfo
public class TarballVersionInfo {
    public var uri: DependencyURI
    /// 包名 (用于 alias)
    public var packageName: String

    public init(uri: DependencyURI) {
        this.uri = uri
        packageName = ""
    }
}

/// Git 仓库信息
/// 翻译自: repository.zig Repository
public class GitRepositoryInfo {
    public var owner: String
    public var repo: String
    public var committish: String

    public init(owner: String, repo: String, committish: String) {
        this.owner = owner
        this.repo = repo
        this.committish = committish
    }
}

// ============================================================================
// 依赖结构体
// 严格翻译自: src/install/dependency.zig - Dependency
//   pub const Dependency = struct {
//       name_hash: PackageNameHash = 0,
//       name: String = .{},
//       version: Dependency.Version = .{},
//       behavior: Behavior = .{},
//   }
// ============================================================================

/// 依赖描述
/// 对应 Bun: install.Dependency
public class DependencyInfo {
    /// 包名哈希 - 对应 PackageNameHash (u64)
    public var nameHash: UInt64
    /// 包名
    public var name: String
    /// 版本字面量
    public var versionLiteral: String
    /// 版本标签
    public var versionTag: DependencyVersionTag
    /// 版本值 (根据 tag 不同而含义不同)
    public var versionValue: DependencyVersionValue
    /// 行为标志
    public var behavior: DependencyBehavior

    public init() {
        nameHash = UInt64(0)
        name = ""
        versionLiteral = ""
        versionTag = DependencyVersionTag.Uninitialized
        versionValue = DependencyVersionValue()
        behavior = DependencyBehavior()
    }

    public init(name: String, version: String) {
        nameHash = UInt64(0)
        this.name = name
        versionLiteral = version
        versionTag = DependencyVersionTag.infer(version)
        versionValue = DependencyVersionValue()
        behavior = DependencyBehavior()
    }

    public init(name: String, version: String, tag: DependencyVersionTag) {
        nameHash = UInt64(0)
        this.name = name
        versionLiteral = version
        versionTag = tag
        versionValue = DependencyVersionValue()
        behavior = DependencyBehavior()
    }

    /// 获取真实包名 (对于 alias 情况)
    /// 翻译自: Dependency.realname
    public func realname(): String {
        match (versionTag) {
            case DistTag => {
                match (versionValue.distTagInfo) {
                    case Some(info) => info.name
                    case None => name
                }
            }
            case Git => {
                match (versionValue.gitInfo) {
                    case Some(info) => if (info.repo.length > 0) { info.repo } else { name }
                    case None => name
                }
            }
            case Github => {
                match (versionValue.githubInfo) {
                    case Some(info) => if (info.repo.length > 0) { info.repo } else { name }
                    case None => name
                }
            }
            case Npm => {
                match (versionValue.npmInfo) {
                    case Some(info) => if (info.name.length > 0) { info.name } else { name }
                    case None => name
                }
            }
            case Tarball => {
                match (versionValue.tarballInfo) {
                    case Some(info) => if (info.packageName.length > 0) { info.packageName } else { name }
                    case None => name
                }
            }
            case _ => name
        }
    }

    /// 是否是 alias
    /// 翻译自: Dependency.isAliased
    public func isAliased(buf: String): Bool {
        match (versionTag) {
            case Npm => {
                match (versionValue.npmInfo) {
                    case Some(info) => info.name != name
                    case None => false
                }
            }
            case _ => false
        }
    }

    /// 排序比较
    /// 翻译自: Dependency.isLessThan
    public static func isLessThan(lhs: DependencyInfo, rhs: DependencyInfo): Bool {
        let cmp = lhs.behavior.compare(rhs.behavior)
        if (cmp != 0) { return cmp < 0 }
        return lhs.name < rhs.name
    }

    /// 拆分 name@version
    /// 翻译自: Dependency.splitNameAndMaybeVersion
    public static func splitNameAndMaybeVersion(s: String): Tuple2<String, ?String> {
        let atIndex = s.indexOf("@")
        match (atIndex) {
            case Some(idx) => {
                if (idx > 0) {
                    let version = if (idx + 1 < s.length) { Some(s.substring(Int64(idx) + 1)) } else { None }
                    return Tuple2(s.substring(0, idx), version)
                }
                // scoped package: @foo/bar@1.0.0
                let secondAt = s.indexOf("@", Int64(idx) + 1)
                match (secondAt) {
                    case Some(idx2) => {
                        let version = if (idx2 + 1 < s.length) { Some(s.substring(Int64(idx2) + 1)) } else { None }
                        return Tuple2(s.substring(0, idx2), version)
                    }
                    case None => return Tuple2(s, None)
                }
            }
            case None => return Tuple2(s, None)
        }
    }

    /// 拆分 name@version 或返回 "latest"
    /// 翻译自: Dependency.splitNameAndVersionOrLatest
    public static func splitNameAndVersionOrLatest(s: String): Tuple2<String, String> {
        let (name, version) = splitNameAndMaybeVersion(s)
        match (version) {
            case Some(v) => return Tuple2(name, v)
            case None => return Tuple2(name, "latest")
        }
    }

    /// 拆分 version 和可能的 name
    /// 翻译自: Dependency.splitVersionAndMaybeName
    public static func splitVersionAndMaybeName(s: String): Tuple2<String, ?String> {
        let atIndex = s.indexOf("@")
        match (atIndex) {
            case Some(idx) => {
                if (idx > 0) {
                    return Tuple2(s.substring(Int64(idx) + 1), s.substring(0, idx))
                }
                let secondAt = s.indexOf("@", Int64(idx) + 1)
                match (secondAt) {
                    case Some(idx2) => return Tuple2(s.substring(Int64(idx2) + 1), s.substring(0, idx2))
                    case None => return Tuple2(s, None)
                }
            }
            case None => return Tuple2(s, None)
        }
    }

    /// 获取不带 build tag 的版本
    /// 翻译自: Dependency.withoutBuildTag
    public static func withoutBuildTag(version: String): String {
        let plusIdx = version.indexOf("+")
        match (plusIdx) {
            case Some(idx) => version.substring(0, idx)
            case None => version
        }
    }

    /// 获取不带 scope 的包名
    /// 翻译自: Dependency.unscopedPackageName
    public static func unscopedPackageName(name: String): String {
        if (name.length == 0 || name[0] != '@') { return name }
        let withoutAt = name.substring(1)
        let slashIdx = withoutAt.indexOf("/")
        match (slashIdx) {
            case Some(idx) => withoutAt.substring(Int64(idx) + 1)
            case None => name
        }
    }

    /// 是否是 scoped package
    /// 翻译自: Dependency.isScopedPackageName
    public static func isScopedPackageName(name: String): Bool {
        if (name.length == 0) { return false }
        if (name[0] != '@') { return false }
        let slashIdx = name.indexOf("/")
        match (slashIdx) {
            case Some(idx) => idx > 1 && idx < name.length - 1
            case None => false
        }
    }

    /// 相等比较
    /// 翻译自: Dependency.eql
    public func eql(other: DependencyInfo): Bool {
        return nameHash == other.nameHash &&
            name.length == other.name.length &&
            versionTag == other.versionTag &&
            versionLiteral == other.versionLiteral
    }
}

/// 依赖版本值 (union 类型)
/// 对应 Bun: Dependency.Version.Value
public class DependencyVersionValue {
    public var npmInfo: ?NpmVersionInfo
    public var distTagInfo: ?DistTagVersionInfo
    public var tarballInfo: ?TarballVersionInfo
    public var folderPath: String
    public var symlinkPath: String
    public var workspacePath: String
    public var gitInfo: ?GitRepositoryInfo
    public var githubInfo: ?GitRepositoryInfo
    public var catalogGroup: String

    public init() {
        npmInfo = None
        distTagInfo = None
        tarballInfo = None
        folderPath = ""
        symlinkPath = ""
        workspacePath = ""
        gitInfo = None
        githubInfo = None
        catalogGroup = ""
    }
}

// ============================================================================
// 包 ID 类型
// 严格翻译自: src/install/install.zig
//   pub const PackageID = u32
//   pub const DependencyID = u32
//   pub const invalid_package_id = std.math.maxInt(PackageID)
//   pub const invalid_dependency_id = std.math.maxInt(DependencyID)
// ============================================================================

/// 无效包 ID
/// 翻译自: invalid_package_id = maxInt(u32)
public let INVALID_PACKAGE_ID: UInt32 = UInt32.MAX

/// 无效依赖 ID
/// 翻译自: invalid_dependency_id = maxInt(u32)
public let INVALID_DEPENDENCY_ID: UInt32 = UInt32.MAX

/// 包名哈希类型
/// 翻译自: PackageNameHash = u64
public typealias PackageNameHash = UInt64

/// 包名+版本哈希类型
/// 翻译自: PackageNameAndVersionHash = u64
public typealias PackageNameAndVersionHash = UInt64

/// 截断的包名哈希
/// 翻译自: TruncatedPackageNameHash = u32
public typealias TruncatedPackageNameHash = UInt32

/// 包 ID
/// 翻译自: PackageID = u32
public typealias PackageID = UInt32

/// 依赖 ID
/// 翻译自: DependencyID = u32
public typealias DependencyID = UInt32

// ============================================================================
// 提取数据
// 严格翻译自: src/install/install.zig - ExtractData
// ============================================================================

/// 提取数据
/// 对应 Bun: install.ExtractData
public class ExtractData {
    public var url: String
    public var resolved: String
    public var jsonPath: String
    public var jsonBuf: String
    public var integrity: Integrity

    public init() {
        url = ""
        resolved = ""
        jsonPath = ""
        jsonBuf = ""
        integrity = Integrity()
    }
}

// ============================================================================
// 任务回调上下文
// 严格翻译自: src/install/install.zig - TaskCallbackContext
// ============================================================================

/// 任务回调上下文 (union)
/// 翻译自: install.TaskCallbackContext
public enum TaskCallbackContext {
    | Dependency(DependencyID)
    | DependencyInstallContext(DependencyInstallContextData)
    | IsolatedPackageInstallContext(UInt32)
    | RootDependency(DependencyID)
    | RootRequestID(PackageID)
}

/// 依赖安装上下文
/// 翻译自: install.DependencyInstallContext
public class DependencyInstallContextData {
    public var treeId: UInt32
    public var path: String
    public var dependencyId: DependencyID

    public init(treeId: UInt32, path: String, dependencyId: DependencyID) {
        this.treeId = treeId
        this.path = path
        this.dependencyId = dependencyId
    }
}

// ============================================================================
// 预安装状态
// 严格翻译自: src/install/install.zig - PreinstallState
//   pub const PreinstallState = enum(u4) {
//       unknown, done, extract, extracting,
//       calc_patch_hash, calcing_patch_hash,
//       apply_patch, applying_patch
//   }
// ============================================================================

/// 预安装状态
public enum PreinstallState {
    | Unknown
    | Done
    | Extract
    | Extracting
    | CalcPatchHash
    | CalcingPatchHash
    | ApplyPatch
    | ApplyingPatch
}

// ============================================================================
// 安装来源
// 严格翻译自: src/install/install.zig - Origin
//   pub const Origin = enum(u8) { local, npm, tarball }
// ============================================================================

/// 安装来源
public enum Origin {
    | Local  // 0
    | Npm    // 1
    | Tarball // 2
}

// ============================================================================
// 包清单错误
// 严格翻译自: src/install/install.zig - PackageManifestError
// ============================================================================

/// 包清单错误类型
public enum PackageManifestError {
    | HTTP400
    | HTTP401
    | HTTP402
    | HTTP403
    | HTTP404
    | HTTP4xx
    | HTTP5xx
    | InvalidURL
    | PackageFailedToParse
    | BadRequest
    | TooManyRequests
    | HTTPInternalServerError
    | OOM
}

// ============================================================================
// Bun tag hash
// 严格翻译自: src/install/install.zig
//   pub const bun_hash_tag = ".bun-tag-"
// ============================================================================

/// Bun hash tag 前缀
/// 翻译自: install.bun_hash_tag
public let BUN_HASH_TAG: String = ".bun-tag-"
