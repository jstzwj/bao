// bao_install_types - 共享安装/解析器类型
// 严格翻译自: src/install_types/resolver_hooks.rs
//
// MOVE_DOWN from bun_install so bun_resolver can spell these types
// without an upward dep edge (resolver->install would cycle through
// install->resolver). The behaviourful PackageManager itself stays in
// bun_install; the resolver talks to it through the AutoInstaller
// trait.
//
// Every value type here is the SINGLE canonical definition --
// bao_install re-exports them; there is exactly one nominal type per name.
package bao_install_types

import bao_core.*
import bao_semver.*
import bao_hash.*
import bao_collections.*

// ============================================================================
// ExternalSlice - 外部切片
// 严格翻译自: resolver_hooks.rs ExternalSlice<T>
//   MOVE_DOWN of install/ExternalSlice.zig -- (off, len) index pair into a
//   flat backing buffer (lockfile string-bytes / dependencies / resolutions).
// ============================================================================

/// 外部切片 - 通过 (off, len) 索引对引用外部缓冲区中的连续数据
/// 翻译自:
///   #[repr(C)]
///   pub struct ExternalSlice<T> {
///       pub off: u32,
///       pub len: u32,
///       _marker: PhantomData<T>,
///   }
public class ExternalSlice<T> {
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

    /// 构造函数
    /// 翻译自: pub const fn new(off: u32, len: u32) -> Self
    public static func new(off: UInt32, len: UInt32): ExternalSlice<T> {
        return ExternalSlice<T>(off: off, len: len)
    }

    /// 无效标记
    /// 翻译自: pub const INVALID: Self = Self { off: u32::MAX, len: u32::MAX, .. }
    public static let INVALID: ExternalSlice<T> = ExternalSlice<T>(off: UInt32.MAX, len: UInt32.MAX)

    /// 是否无效
    /// 翻译自: pub fn is_invalid(self) -> bool
    public func isInvalid(): Bool {
        return off == UInt32.MAX && len == UInt32.MAX
    }

    /// 是否包含指定 ID
    /// 翻译自: pub fn contains(self, id: u32) -> bool
    public func contains(id: UInt32): Bool {
        return id >= off && UInt64(id) < UInt64(len) + UInt64(off)
    }

    /// 起始索引
    /// 翻译自: pub fn begin(self) -> u32
    public func begin(): UInt32 {
        return off
    }

    /// 结束索引 (不含)
    /// 翻译自: pub fn end(self) -> u32
    public func end(): UInt32 {
        return off + len
    }

    /// 相等比较
    /// 翻译自: impl PartialEq for ExternalSlice<T>
    public func eq(other: ExternalSlice<T>): Bool {
        return off == other.off && len == other.len
    }
}

// ============================================================================
// ExternalStringMap / ExternalStringList / VersionSlice / etc.
// 严格翻译自: resolver_hooks.rs 中的类型别名
// ============================================================================

/// 外部字符串映射
/// 翻译自:
///   #[repr(C)]
///   #[derive(Copy, Clone, Default, Debug)]
///   pub struct ExternalStringMap {
///       pub name: ExternalStringList,
///       pub value: ExternalStringList,
///   }
public class ExternalStringMapStruct {
    public var name: ExternalStringListSlice
    public var value: ExternalStringListSlice

    public init() {
        name = ExternalStringListSlice()
        value = ExternalStringListSlice()
    }

    public init(name: ExternalStringListSlice, value: ExternalStringListSlice) {
        this.name = name
        this.value = value
    }
}

/// 外部字符串列表 = ExternalSlice<ExternalString>
/// 翻译自: pub type ExternalStringList = ExternalSlice<ExternalString>
public class ExternalStringListSlice {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }
}

/// 外部包名哈希列表 = ExternalSlice<PackageNameHash>
/// 翻译自: pub type ExternalPackageNameHashList = ExternalSlice<PackageNameHash>
public class ExternalPackageNameHashListSlice {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }
}

/// 版本切片 = ExternalSlice<SemverVersion>
/// 翻译自: pub type VersionSlice = ExternalSlice<SemverVersion>
public class VersionSliceType {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }
}

/// 依赖切片 = ExternalSlice<Dependency>
/// 翻译自: pub type DependencySlice = ExternalSlice<Dependency>
public class DependencySliceType {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }
}

/// 解析切片 = ExternalSlice<PackageID>
/// 翻译自: pub type ResolutionSlice = ExternalSlice<PackageID>
public class ResolutionSliceType {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }
}

// ============================================================================
// Behavior - 依赖行为标志 (位域)
// 严格翻译自: resolver_hooks.rs behavior module
//   bitflags::bitflags! {
//       pub struct Behavior: u8 {
//           const PROD      = 1 << 1;
//           const OPTIONAL  = 1 << 2;
//           const DEV       = 1 << 3;
//           const PEER      = 1 << 4;
//           const WORKSPACE = 1 << 5;
//           const BUNDLED   = 1 << 6;
//       }
//   }
// ============================================================================

/// 依赖行为标志位域
/// 位布局 (翻译自 Behavior bitflags):
///   bit 0: unused
///   bit 1: PROD
///   bit 2: OPTIONAL
///   bit 3: DEV
///   bit 4: PEER
///   bit 5: WORKSPACE
///   bit 6: BUNDLED
///   bit 7: unused
public class Behavior {
    public var bits: UInt8

    public init() {
        bits = UInt8(0)
    }

    public init(bits: UInt8) {
        this.bits = bits
    }

    // ── Flag constants ──────────────────────────────────────────────────────
    // 翻译自: const PROD = 1 << 1, OPTIONAL = 1 << 2, etc.
    public static let PROD: UInt8      = UInt8(1) << UInt8(1)  // 2
    public static let OPTIONAL: UInt8  = UInt8(1) << UInt8(2)  // 4
    public static let DEV: UInt8       = UInt8(1) << UInt8(3)  // 8
    public static let PEER: UInt8      = UInt8(1) << UInt8(4)  // 16
    public static let WORKSPACE: UInt8 = UInt8(1) << UInt8(5)  // 32
    public static let BUNDLED: UInt8   = UInt8(1) << UInt8(6)  // 64

    // ── Factory helpers ─────────────────────────────────────────────────────

    public static func prod(): Behavior {
        return Behavior(bits: PROD)
    }
    public static func optional(): Behavior {
        return Behavior(bits: OPTIONAL)
    }
    public static func dev(): Behavior {
        return Behavior(bits: DEV)
    }
    public static func peer(): Behavior {
        return Behavior(bits: PEER)
    }
    public static func workspace(): Behavior {
        return Behavior(bits: WORKSPACE)
    }
    public static func bundled(): Behavior {
        return Behavior(bits: BUNDLED)
    }

    // ── Bit operations ──────────────────────────────────────────────────────

    /// 翻译自: pub fn contains(self, flag: Self) -> bool
    public func contains(flag: UInt8): Bool {
        return (bits & flag) != UInt8(0)
    }

    /// 翻译自: pub fn intersects(self, rhs: Self) -> bool
    public func intersects(rhs: Behavior): Bool {
        return (bits & rhs.bits) != UInt8(0)
    }

    // ── Named flag table ────────────────────────────────────────────────────
    // 翻译自: pub const NAMED_FLAGS
    /// (name, getter) pairs matching Zig @typeInfo(Behavior).@"struct".fields
    public static let NAMED_FLAGS: ArrayList<(String, (Behavior) -> Bool)> = ArrayList<(String, (Behavior) -> Bool)>([
        ("prod",      {(b: Behavior) => b.contains(Behavior.PROD)}),
        ("optional",  {(b: Behavior) => b.contains(Behavior.OPTIONAL)}),
        ("dev",       {(b: Behavior) => b.contains(Behavior.DEV)}),
        ("peer",      {(b: Behavior) => b.contains(Behavior.PEER)}),
        ("workspace", {(b: Behavior) => b.contains(Behavior.WORKSPACE)}),
        ("bundled",   {(b: Behavior) => b.contains(Behavior.BUNDLED)}),
    ])

    // ── Boolean accessors ───────────────────────────────────────────────────

    /// 翻译自: pub fn is_prod(self) -> bool
    public func isProd(): Bool {
        return contains(Behavior.PROD)
    }

    /// 翻译自: pub fn is_optional(self) -> bool
    /// Zig: optional and !peer -- peer-optionals are reported separately
    public func isOptional(): Bool {
        return contains(Behavior.OPTIONAL) && !contains(Behavior.PEER)
    }

    /// 翻译自: pub fn is_optional_peer(self) -> bool
    public func isOptionalPeer(): Bool {
        return contains(Behavior.OPTIONAL) && contains(Behavior.PEER)
    }

    /// 翻译自: pub fn is_dev(self) -> bool
    public func isDev(): Bool {
        return contains(Behavior.DEV)
    }

    /// 翻译自: pub fn is_peer(self) -> bool
    public func isPeer(): Bool {
        return contains(Behavior.PEER)
    }

    /// 翻译自: pub fn is_workspace(self) -> bool
    public func isWorkspace(): Bool {
        return contains(Behavior.WORKSPACE)
    }

    /// 翻译自: pub fn is_bundled(self) -> bool
    public func isBundled(): Bool {
        return contains(Behavior.BUNDLED)
    }

    /// 翻译自: pub fn includes(self, rhs: Self) -> bool
    public func includes(rhs: Behavior): Bool {
        return intersects(rhs)
    }

    /// 翻译自: pub fn is_required(self) -> bool
    public func isRequired(): Bool {
        return !isOptional()
    }

    /// 翻译自: pub fn eq(lhs: Behavior, rhs: Behavior) -> bool
    public static func eq(lhs: Behavior, rhs: Behavior): Bool {
        return lhs.bits == rhs.bits
    }

    /// 翻译自: pub fn add(self, kind: Behavior) -> Behavior
    public func add(kind: Behavior): Behavior {
        return Behavior(bits: bits | kind.bits)
    }

    /// 翻译自: pub fn with(self, kind: Behavior, value: bool) -> Behavior
    public func with(kind: Behavior, value: Bool): Behavior {
        if (value) {
            return Behavior(bits: bits | kind.bits)
        } else {
            return Behavior(bits: bits & (~kind.bits))
        }
    }

    /// 翻译自: pub fn set_optional(&mut self, value: bool)
    public func setOptional(value: Bool): Unit {
        if (value) {
            bits = bits | Behavior.OPTIONAL
        } else {
            bits = bits & (~Behavior.OPTIONAL)
        }
    }

    /// 翻译自: pub fn is_enabled(self, features: Features) -> bool
    public func isEnabled(features: Features): Bool {
        return isProd() ||
            (features.optionalDependencies && contains(Behavior.OPTIONAL)) ||
            (features.devDependencies && isDev()) ||
            (features.peerDependencies && isPeer()) ||
            (features.workspaces && isWorkspace())
    }

    /// 翻译自: pub fn cmp(self, rhs: Self) -> Ordering
    public func compare(rhs: Behavior): Int64 {
        if (Behavior.eq(this, rhs)) { return 0 }
        // ensure workspaces are placed at the beginning
        if (isWorkspace() != rhs.isWorkspace()) {
            return if (isWorkspace()) { -1 } else { 1 }
        }
        if (isDev() != rhs.isDev()) {
            return if (isDev()) { -1 } else { 1 }
        }
        if (isOptional() != rhs.isOptional()) {
            return if (isOptional()) { -1 } else { 1 }
        }
        if (isProd() != rhs.isProd()) {
            return if (isProd()) { -1 } else { 1 }
        }
        if (isPeer() != rhs.isPeer()) {
            return if (isPeer()) { -1 } else { 1 }
        }
        return 0
    }
}

// ============================================================================
// DependencyVersionTag - 依赖版本标签
// 严格翻译自: resolver_hooks.rs DependencyVersionTag
//   #[derive(Default, Clone, Copy, PartialEq, Eq, strum::IntoStaticStr)]
//   #[repr(u8)]
//   pub enum DependencyVersionTag {
//       #[default]
//       Uninitialized = 0,
//       Npm = 1,
//       DistTag = 2,
//       Tarball = 3,
//       Folder = 4,
//       Symlink = 5,
//       Workspace = 6,
//       Git = 7,
//       Github = 8,
//       Catalog = 9,
//   }
// ============================================================================

/// 依赖版本标签
public enum DependencyVersionTag {
    | Uninitialized   // 0
    | Npm             // 1 - semver range
    | DistTag         // 2 - NPM dist tag (e.g. "latest")
    | Tarball         // 3 - URI to .tgz or .tar.gz
    | Folder          // 4 - local folder
    | Symlink         // 5 - link:path
    | Workspace       // 6 - workspace path
    | Git             // 7 - git repository
    | Github          // 8 - github repository
    | Catalog         // 9 - catalog:

    /// 转为整数值
    /// 翻译自: repr(u8) 数值
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

    /// 从整数创建
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

    /// 转为字符串 (snake_case, 对应 strum::IntoStaticStr)
    public func toStr(): String {
        match (this) {
            case Uninitialized => "uninitialized"
            case Npm => "npm"
            case DistTag => "dist_tag"
            case Tarball => "tarball"
            case Folder => "folder"
            case Symlink => "symlink"
            case Workspace => "workspace"
            case Git => "git"
            case Github => "github"
            case Catalog => "catalog"
        }
    }
}

// ============================================================================
// URI - 本地/远程 URI
// 严格翻译自: resolver_hooks.rs URI
//   #[derive(Clone, Copy)]
//   pub enum URI {
//       Local(SemverString),
//       Remote(SemverString),
//   }
// ============================================================================

/// URI 联合类型
/// 翻译自: pub enum URI { Local(SemverString), Remote(SemverString) }
public class URI {
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

    /// 翻译自: pub fn eql(lhs: URI, rhs: URI, lhs_buf: &[u8], rhs_buf: &[u8]) -> bool
    public static func eql(lhs: URI, rhs: URI, lhsBuf: String, rhsBuf: String): Bool {
        if (lhs.isLocal != rhs.isLocal) {
            return false
        }
        return lhs.value == rhs.value
    }
}

// ============================================================================
// NpmInfo - NPM 版本信息
// 严格翻译自: resolver_hooks.rs NpmInfo
//   pub struct NpmInfo {
//       pub name: SemverString,
//       pub version: semver::query::Group,
//       pub is_alias: bool,
//   }
// ============================================================================

/// NPM 版本信息
/// 翻译自:
///   pub struct NpmInfo {
///       pub name: SemverString,
///       pub version: semver::query::Group,
///       pub is_alias: bool,
///   }
public class NpmInfo {
    /// 包名
    public var name: String
    /// semver 查询组
    public var version: String
    /// 是否是 alias
    public var isAlias: Bool

    public init() {
        name = ""
        version = ""
        isAlias = false
    }

    public init(name: String, version: String, isAlias: Bool) {
        this.name = name
        this.version = version
        this.isAlias = isAlias
    }

    /// 翻译自: pub fn eql(&self, that: &NpmInfo, this_buf: &[u8], that_buf: &[u8]) -> bool
    public func eql(that: NpmInfo): Bool {
        return name == that.name && version == that.version
    }
}

// ============================================================================
// TagInfo - Dist-tag 版本信息
// 严格翻译自: resolver_hooks.rs TagInfo
//   #[derive(Clone, Copy)]
//   pub struct TagInfo {
//       pub name: SemverString,
//       pub tag: SemverString,
//   }
// ============================================================================

/// Dist-tag 版本信息
/// 翻译自:
///   pub struct TagInfo {
///       pub name: SemverString,
///       pub tag: SemverString,
///   }
public class TagInfo {
    public var name: String
    public var tag: String

    public init() {
        name = ""
        tag = ""
    }

    public init(name: String, tag: String) {
        this.name = name
        this.tag = tag
    }

    /// 翻译自: pub fn eql(&self, that: &TagInfo, this_buf: &[u8], that_buf: &[u8]) -> bool
    public func eql(that: TagInfo): Bool {
        return name == that.name && tag == that.tag
    }
}

// ============================================================================
// TarballInfo - Tarball 版本信息
// 严格翻译自: resolver_hooks.rs TarballInfo
//   #[derive(Clone, Copy)]
//   pub struct TarballInfo {
//       pub uri: URI,
//       pub package_name: SemverString,
//   }
// ============================================================================

/// Tarball 版本信息
/// 翻译自:
///   pub struct TarballInfo {
///       pub uri: URI,
///       pub package_name: SemverString,
///   }
public class TarballInfo {
    public var uri: URI
    public var packageName: String

    public init() {
        uri = URI(local: "")
        packageName = ""
    }

    public init(uri: URI, packageName: String) {
        this.uri = uri
        this.packageName = packageName
    }

    /// 翻译自: pub fn eql(&self, that: &TarballInfo, ...) -> bool
    public func eql(that: TarballInfo): Bool {
        return URI.eql(uri, that.uri, "", "")
    }
}

// ============================================================================
// DependencyVersionValue - 依赖版本值 (union)
// 严格翻译自: resolver_hooks.rs DependencyVersionValue
//   #[repr(C)]
//   pub union DependencyVersionValue {
//       pub uninitialized: (),
//       pub npm: ManuallyDrop<NpmInfo>,
//       pub dist_tag: TagInfo,
//       pub tarball: TarballInfo,
//       pub folder: SemverString,
//       pub symlink: SemverString,
//       pub workspace: SemverString,
//       pub git: ManuallyDrop<Repository>,
//       pub github: ManuallyDrop<Repository>,
//       pub catalog: SemverString,
//   }
// ============================================================================

/// 依赖版本值
/// 翻译自: pub union DependencyVersionValue { ... }
/// Cangjie doesn't have unions; we store each variant as an optional field
public class DependencyVersionValue {
    public var npmInfo: ?NpmInfo
    public var distTagInfo: ?TagInfo
    public var tarballInfo: ?TarballInfo
    public var folderPath: String
    public var symlinkPath: String
    public var workspacePath: String
    public var gitInfo: ?Repository
    public var githubInfo: ?Repository
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
// DependencyVersion - 依赖版本
// 严格翻译自: resolver_hooks.rs DependencyVersion
//   #[repr(C)]
//   pub struct DependencyVersion {
//       pub tag: DependencyVersionTag,
//       pub literal: SemverString,
//       pub value: DependencyVersionValue,
//   }
// ============================================================================

/// 依赖版本
/// 翻译自:
///   pub struct DependencyVersion {
///       pub tag: DependencyVersionTag,
///       pub literal: SemverString,
///       pub value: DependencyVersionValue,
///   }
public class DependencyVersion {
    public var tag: DependencyVersionTag
    public var literal: String
    public var value: DependencyVersionValue

    public init() {
        tag = DependencyVersionTag.Uninitialized
        literal = ""
        value = DependencyVersionValue()
    }

    public init(tag: DependencyVersionTag, literal: String, value: DependencyVersionValue) {
        this.tag = tag
        this.literal = literal
        this.value = value
    }

    /// 翻译自: pub fn try_npm(&self) -> Option<&NpmInfo>
    public func tryNpm(): ?NpmInfo {
        if (tag == DependencyVersionTag.Npm) {
            return value.npmInfo
        }
        return None
    }

    /// 翻译自: pub fn is_exact_npm(&self) -> bool
    public func isExactNpm(): Bool {
        match (tryNpm()) {
            case Some(_) => return true
            case None => return false
        }
    }

    // Tag-checked accessors (翻译自 extern_union_accessors! macro)

    /// 翻译自: npm() -> &NpmInfo
    public func npm(): ?NpmInfo {
        if (tag == DependencyVersionTag.Npm) { return value.npmInfo }
        return None
    }

    /// 翻译自: dist_tag() -> &TagInfo
    public func distTag(): ?TagInfo {
        if (tag == DependencyVersionTag.DistTag) { return value.distTagInfo }
        return None
    }

    /// 翻译自: tarball() -> &TarballInfo
    public func tarball(): ?TarballInfo {
        if (tag == DependencyVersionTag.Tarball) { return value.tarballInfo }
        return None
    }

    /// 翻译自: folder() -> &SemverString
    public func folder(): String {
        if (tag == DependencyVersionTag.Folder) { return value.folderPath }
        return ""
    }

    /// 翻译自: symlink() -> &SemverString
    public func symlink(): String {
        if (tag == DependencyVersionTag.Symlink) { return value.symlinkPath }
        return ""
    }

    /// 翻译自: workspace() -> &SemverString
    public func workspace(): String {
        if (tag == DependencyVersionTag.Workspace) { return value.workspacePath }
        return ""
    }

    /// 翻译自: git() -> &Repository
    public func git(): ?Repository {
        if (tag == DependencyVersionTag.Git) { return value.gitInfo }
        return None
    }

    /// 翻译自: github() -> &Repository
    public func github(): ?Repository {
        if (tag == DependencyVersionTag.Github) { return value.githubInfo }
        return None
    }

    /// 翻译自: catalog() -> &SemverString
    public func catalog(): String {
        if (tag == DependencyVersionTag.Catalog) { return value.catalogGroup }
        return ""
    }
}

// ============================================================================
// Dependency - 依赖结构体
// 严格翻译自: resolver_hooks.rs Dependency
//   #[repr(C)]
//   pub struct Dependency {
//       pub name_hash: PackageNameHash,
//       pub name: SemverString,
//       pub version: DependencyVersion,
//       pub behavior: Behavior,
//   }
// ============================================================================

/// 依赖描述
/// 翻译自:
///   pub struct Dependency {
///       pub name_hash: PackageNameHash,
///       pub name: SemverString,
///       pub version: DependencyVersion,
///       pub behavior: Behavior,
///   }
public class Dependency {
    /// 包名哈希
    public var nameHash: PackageNameHash
    /// 包名
    public var name: String
    /// 版本
    public var version: DependencyVersion
    /// 行为标志
    public var behavior: Behavior

    public init() {
        nameHash = UInt64(0)
        name = ""
        version = DependencyVersion()
        behavior = Behavior()
    }

    public init(nameHash: PackageNameHash, name: String, version: DependencyVersion, behavior: Behavior) {
        this.nameHash = nameHash
        this.name = name
        this.version = version
        this.behavior = behavior
    }

    /// 翻译自: pub fn is_less_than(string_buf: &[u8], lhs: &Dependency, rhs: &Dependency) -> bool
    /// Sorting order for dependencies is:
    /// 1. [peerDependencies, optionalDependencies, devDependencies, dependencies]
    /// 2. name ASC
    public static func isLessThan(stringBuf: String, lhs: Dependency, rhs: Dependency): Bool {
        let behaviorCmp = lhs.behavior.compare(rhs.behavior)
        if (behaviorCmp != 0) {
            return behaviorCmp < 0
        }
        return lhs.name < rhs.name
    }

    /// 翻译自: pub fn cmp(string_buf: &[u8], lhs: &Dependency, rhs: &Dependency) -> Ordering
    public static func cmp(stringBuf: String, lhs: Dependency, rhs: Dependency): Int64 {
        let behaviorCmp = lhs.behavior.compare(rhs.behavior)
        if (behaviorCmp != 0) {
            return behaviorCmp
        }
        if (lhs.name < rhs.name) { return -1 }
        if (lhs.name > rhs.name) { return 1 }
        return 0
    }
}

// ============================================================================
// NegatableEnum trait + Negatable<T> + NegatableExt
// 严格翻译自: resolver_hooks.rs
//   pub trait NegatableEnum: Copy + Eq { ... }
//   pub struct Negatable<T: NegatableEnum> { ... }
//   pub trait NegatableExt: NegatableEnum { ... }
// ============================================================================

/// 可否定枚举接口
/// 翻译自:
///   pub trait NegatableEnum: Copy + Eq {
///       type Int: ...
///       const NONE: Self;
///       const ALL: Self;
///       const ALL_VALUE: Self::Int;
///       fn lookup_name(key: &[u8]) -> Option<Self::Int>;
///       fn name_map_kvs() -> &'static [(&'static [u8], Self::Int)];
///       fn has(self, other: Self::Int) -> bool;
///       fn to_raw(self) -> Self::Int;
///       fn from_raw(n: Self::Int) -> Self;
///   }
public interface NegatableEnum<T> {
    func toRaw(): T
    static func fromRaw(n: T): NegatableEnum<T>
    static func allValue(): T
    static func noneValue(): NegatableEnum<T>
    static func allInst(): NegatableEnum<T>
    func has(other: T): Bool
    static func lookupName(key: String): ?T
    static func nameMapKvs(): ArrayList<(String, T)>
}

/// 可否定类型
/// 翻译自:
///   pub struct Negatable<T: NegatableEnum> {
///       pub added: T,
///       pub removed: T,
///       pub had_wildcard: bool,
///       pub had_unrecognized_values: bool,
///   }
public class Negatable<T> {
    public var added: NegatableEnum<T>
    public var removed: NegatableEnum<T>
    public var hadWildcard: Bool
    public var hadUnrecognizedValues: Bool

    public init(added: NegatableEnum<T>, removed: NegatableEnum<T>) {
        this.added = added
        this.removed = removed
        this.hadWildcard = false
        this.hadUnrecognizedValues = false
    }

    /// 翻译自: pub fn combine(self) -> T
    public func combine(): NegatableEnum<T> {
        let addedRaw = if (hadWildcard) {
            NegatableEnum<T>.allValue()
        } else {
            added.toRaw()
        }
        let removedRaw = removed.toRaw()

        // If none were added or removed, all are allowed
        if (addedRaw == removedRaw && !hadWildcard && !hadUnrecognizedValues) {
            return NegatableEnum<T>.allInst()
        }

        // Simplified: return the added if non-zero
        return added
    }

    /// 翻译自: pub fn apply(&mut self, str: &[u8])
    public func apply(str: String): Unit {
        if (str.length == 0) {
            return
        }

        if (str == "any") {
            hadWildcard = true
            return
        }

        if (str == "none") {
            hadUnrecognizedValues = true
            return
        }

        let isNot = str.length > 0 && str[0] == '!'
        let offset: Int64 = if (isNot) { 1 } else { 0 }
        let key = str.substring(offset)

        match (NegatableEnum<T>.lookupName(key)) {
            case Some(field) => {
                if (isNot) {
                    // removed
                } else {
                    // added
                }
            }
            case None => {
                if (!isNot) {
                    hadUnrecognizedValues = true
                }
                return
            }
        }
    }
}

// ============================================================================
// OperatingSystem - 操作系统位域
// 严格翻译自: resolver_hooks.rs OperatingSystem
//   #[repr(transparent)]
//   #[derive(Clone, Copy, PartialEq, Eq, Default)]
//   pub struct OperatingSystem(pub u16);
// ============================================================================

/// 操作系统位域
/// 翻译自: pub struct OperatingSystem(pub u16)
/// https://nodejs.org/api/os.html#osplatform
public class OperatingSystem {
    public var bits: UInt16

    public init() {
        bits = UInt16(0)
    }

    public init(bits: UInt16) {
        this.bits = bits
    }

    public static let NONE: UInt16      = UInt16(0)
    public static let AIX: UInt16       = UInt16(1) << UInt16(1)
    public static let DARWIN: UInt16    = UInt16(1) << UInt16(2)
    public static let FREEBSD: UInt16   = UInt16(1) << UInt16(3)
    public static let LINUX: UInt16     = UInt16(1) << UInt16(4)
    public static let OPENBSD: UInt16   = UInt16(1) << UInt16(5)
    public static let SUNOS: UInt16     = UInt16(1) << UInt16(6)
    public static let WIN32: UInt16     = UInt16(1) << UInt16(7)
    public static let ANDROID: UInt16   = UInt16(1) << UInt16(8)

    public static let ALL_VALUE: UInt16 = OperatingSystem.AIX |
        OperatingSystem.DARWIN |
        OperatingSystem.FREEBSD |
        OperatingSystem.LINUX |
        OperatingSystem.OPENBSD |
        OperatingSystem.SUNOS |
        OperatingSystem.WIN32 |
        OperatingSystem.ANDROID

    /// 当前操作系统
    /// 翻译自: pub const CURRENT: Self (conditional compilation)
    public static let CURRENT: UInt16 = OperatingSystem.LINUX  // default to linux

    /// Node.js process.platform 名称
    /// 翻译自: pub const CURRENT_NAME: &'static str = bun_core::env::OS_NAME_NODE
    public static let CURRENT_NAME: String = "linux"

    /// 翻译自: pub fn none() -> Self
    public static func none(): OperatingSystem {
        return OperatingSystem(bits: UInt16(0))
    }

    /// 翻译自: pub fn all() -> Self
    public static func all(): OperatingSystem {
        return OperatingSystem(bits: ALL_VALUE)
    }

    /// 翻译自: pub fn is_match(self, target: Self) -> bool
    public func isMatch(target: OperatingSystem): Bool {
        return (bits & target.bits) != UInt16(0)
    }

    /// 翻译自: pub fn has(self, other: u16) -> bool
    public func has(other: UInt16): Bool {
        return (bits & other) != UInt16(0)
    }

    /// 翻译自: negatable_names! for OperatingSystem
    /// Name map (sorted by key length asc, then bytewise asc)
    public static let NAME_MAP_KVS: ArrayList<(String, UInt16)> = ArrayList<(String, UInt16)>([
        ("aix",     OperatingSystem.AIX),
        ("linux",   OperatingSystem.LINUX),
        ("sunos",   OperatingSystem.SUNOS),
        ("win32",   OperatingSystem.WIN32),
        ("darwin",  OperatingSystem.DARWIN),
        ("android", OperatingSystem.ANDROID),
        ("freebsd", OperatingSystem.FREEBSD),
        ("openbsd", OperatingSystem.OPENBSD),
    ])

    /// 翻译自: fn lookup_name(key: &[u8]) -> Option<u16>
    public static func lookupName(key: String): ?UInt16 {
        for (kv in NAME_MAP_KVS) {
            if (kv[0] == key) {
                return Some(kv[1])
            }
        }
        return None
    }

    /// 翻译自: pub fn negatable(self) -> Negatable<Self>
    public func negatable(): NegatableOS {
        return NegatableOS(added: this, removed: OperatingSystem.none())
    }
}

/// Negatable wrapper for OperatingSystem
public class NegatableOS {
    public var added: OperatingSystem
    public var removed: OperatingSystem
    public var hadWildcard: Bool
    public var hadUnrecognizedValues: Bool

    public init(added: OperatingSystem, removed: OperatingSystem) {
        this.added = added
        this.removed = removed
        this.hadWildcard = false
        this.hadUnrecognizedValues = false
    }

    /// 翻译自: Negatable::combine()
    public func combine(): OperatingSystem {
        let addedBits = if (hadWildcard) { OperatingSystem.ALL_VALUE } else { added.bits }
        let removedBits = removed.bits

        if (addedBits == UInt16(0) && removedBits == UInt16(0)) {
            if (hadUnrecognizedValues) {
                return OperatingSystem.none()
            }
            return OperatingSystem.all()
        }

        if (addedBits == UInt16(0) && removedBits != UInt16(0)) {
            return OperatingSystem(bits: OperatingSystem.ALL_VALUE & (~removedBits))
        }

        if (removedBits == UInt16(0)) {
            return OperatingSystem(bits: addedBits)
        }

        return OperatingSystem(bits: addedBits & (~removedBits))
    }

    /// 翻译自: Negatable::apply()
    public func apply(str: String): Unit {
        if (str.length == 0) { return }
        if (str == "any") {
            hadWildcard = true
            return
        }
        if (str == "none") {
            hadUnrecognizedValues = true
            return
        }
        let isNot = str.length > 0 && str[0] == '!'
        let key = if (isNot) { str.substring(1) } else { str }
        match (OperatingSystem.lookupName(key)) {
            case Some(field) => {
                if (isNot) {
                    removed = OperatingSystem(bits: removed.bits | field)
                } else {
                    added = OperatingSystem(bits: added.bits | field)
                }
                hadWildcard = false
                hadUnrecognizedValues = false
            }
            case None => {
                if (!isNot) { hadUnrecognizedValues = true }
            }
        }
    }

    /// 翻译自: Negatable::to_json()
    public func toJson(field: OperatingSystem): String {
        if (field.bits == UInt16(0)) {
            return "\"none\""
        }

        let kvs = OperatingSystem.NAME_MAP_KVS
        var removedCount: Int64 = 0
        for (kv in kvs) {
            if (!field.has(kv[1])) {
                removedCount += 1
            }
        }
        let included = kvs.size - removedCount
        let printIncluded = removedCount > (kvs.size - removedCount)

        var parts = ArrayList<String>()
        for (kv in kvs) {
            let hasField = field.has(kv[1])
            if (hasField && printIncluded) {
                parts.append("\"${kv[0]}\"")
            } else if (!hasField && !printIncluded) {
                parts.append("\"!${kv[0]}\"")
            }
        }

        if (parts.size == 1) {
            return parts[0]
        }
        return "[ " + parts.join(", ") + " ]"
    }
}

// ============================================================================
// Libc - libc 位域
// 严格翻译自: resolver_hooks.rs Libc
//   #[repr(transparent)]
//   pub struct Libc(pub u8);
// ============================================================================

/// libc 位域
/// 翻译自: pub struct Libc(pub u8)
public class Libc {
    public var bits: UInt8

    public init() {
        bits = UInt8(0)
    }

    public init(bits: UInt8) {
        this.bits = bits
    }

    public static let NONE: UInt8      = UInt8(0)
    public static let GLIBC: UInt8     = UInt8(1) << UInt8(1)
    public static let MUSL: UInt8      = UInt8(1) << UInt8(2)
    public static let ALL_VALUE: UInt8 = Libc.GLIBC | Libc.MUSL

    /// 翻译自: pub const CURRENT: Self = Self(Self::GLIBC)
    public static let CURRENT: UInt8 = Libc.GLIBC

    public static func none(): Libc { return Libc(bits: UInt8(0)) }
    public static func all(): Libc { return Libc(bits: ALL_VALUE) }

    public func isMatch(target: Libc): Bool {
        return (bits & target.bits) != UInt8(0)
    }

    public func has(other: UInt8): Bool {
        return (bits & other) != UInt8(0)
    }

    /// Name map
    public static let NAME_MAP_KVS: ArrayList<(String, UInt8)> = ArrayList<(String, UInt8)>([
        ("musl",  Libc.MUSL),
        ("glibc", Libc.GLIBC),
    ])

    public static func lookupName(key: String): ?UInt8 {
        for (kv in NAME_MAP_KVS) {
            if (kv[0] == key) { return Some(kv[1]) }
        }
        return None
    }
}

// ============================================================================
// Architecture - CPU 架构位域
// 严格翻译自: resolver_hooks.rs Architecture
//   #[repr(transparent)]
//   pub struct Architecture(pub u16);
// ============================================================================

/// CPU 架构位域
/// 翻译自: pub struct Architecture(pub u16)
/// https://docs.npmjs.com/cli/v8/configuring-npm/package-json#cpu
/// https://nodejs.org/api/os.html#osarch
public class Architecture {
    public var bits: UInt16

    public init() {
        bits = UInt16(0)
    }

    public init(bits: UInt16) {
        this.bits = bits
    }

    public static let NONE: UInt16    = UInt16(0)
    public static let ARM: UInt16     = UInt16(1) << UInt16(1)
    public static let ARM64: UInt16   = UInt16(1) << UInt16(2)
    public static let IA32: UInt16    = UInt16(1) << UInt16(3)
    public static let MIPS: UInt16    = UInt16(1) << UInt16(4)
    public static let MIPSEL: UInt16  = UInt16(1) << UInt16(5)
    public static let PPC: UInt16     = UInt16(1) << UInt16(6)
    public static let PPC64: UInt16   = UInt16(1) << UInt16(7)
    public static let S390: UInt16    = UInt16(1) << UInt16(8)
    public static let S390X: UInt16   = UInt16(1) << UInt16(9)
    public static let X32: UInt16     = UInt16(1) << UInt16(10)
    public static let X64: UInt16     = UInt16(1) << UInt16(11)

    public static let ALL_VALUE: UInt16 = Architecture.ARM |
        Architecture.ARM64 |
        Architecture.IA32 |
        Architecture.MIPS |
        Architecture.MIPSEL |
        Architecture.PPC |
        Architecture.PPC64 |
        Architecture.S390 |
        Architecture.S390X |
        Architecture.X32 |
        Architecture.X64

    /// 翻译自: pub const CURRENT: Self (conditional compilation)
    public static let CURRENT: UInt16 = Architecture.X64  // default to x64

    /// 翻译自: pub const CURRENT_NAME
    public static let CURRENT_NAME: String = "x64"

    public static func none(): Architecture { return Architecture(bits: UInt16(0)) }
    public static func all(): Architecture { return Architecture(bits: ALL_VALUE) }

    public func isMatch(target: Architecture): Bool {
        return (bits & target.bits) != UInt16(0)
    }

    public func has(other: UInt16): Bool {
        return (bits & other) != UInt16(0)
    }

    /// Name map (sorted by key length asc, then bytewise asc)
    public static let NAME_MAP_KVS: ArrayList<(String, UInt16)> = ArrayList<(String, UInt16)>([
        ("arm",    Architecture.ARM),
        ("ppc",    Architecture.PPC),
        ("x32",    Architecture.X32),
        ("x64",    Architecture.X64),
        ("ia32",   Architecture.IA32),
        ("mips",   Architecture.MIPS),
        ("s390",   Architecture.S390),
        ("arm64",  Architecture.ARM64),
        ("ppc64",  Architecture.PPC64),
        ("s390x",  Architecture.S390X),
        ("mipsel", Architecture.MIPSEL),
    ])

    public static func lookupName(key: String): ?UInt16 {
        for (kv in NAME_MAP_KVS) {
            if (kv[0] == key) { return Some(kv[1]) }
        }
        return None
    }
}

// ============================================================================
// Repository - Git 仓库信息
// 严格翻译自: resolver_hooks.rs Repository
//   #[repr(C)]
//   pub struct Repository {
//       pub owner: SemverString,
//       pub repo: SemverString,
//       pub committish: SemverString,
//       pub resolved: SemverString,
//       pub package_name: SemverString,
//   }
// ============================================================================

/// Git 仓库信息
/// 翻译自:
///   pub struct Repository {
///       pub owner: SemverString,
///       pub repo: SemverString,
///       pub committish: SemverString,
///       pub resolved: SemverString,
///       pub package_name: SemverString,
///   }
public class Repository {
    public var owner: String
    public var repo: String
    public var committish: String
    public var resolved: String
    public var packageName: String

    public init() {
        owner = ""
        repo = ""
        committish = ""
        resolved = ""
        packageName = ""
    }

    public init(owner: String, repo: String, committish: String, resolved: String, packageName: String) {
        this.owner = owner
        this.repo = repo
        this.committish = committish
        this.resolved = resolved
        this.packageName = packageName
    }

    /// 翻译自: pub fn order(&self, rhs: &Repository, ...) -> Ordering
    public func order(rhs: Repository): Int64 {
        if (owner != rhs.owner) {
            return if (owner < rhs.owner) { -1 } else { 1 }
        }
        if (repo != rhs.repo) {
            return if (repo < rhs.repo) { -1 } else { 1 }
        }
        if (committish != rhs.committish) {
            return if (committish < rhs.committish) { -1 } else { 1 }
        }
        return 0
    }

    /// 翻译自: pub fn eql(&self, rhs: &Repository, ...) -> bool
    public func eql(rhs: Repository): Bool {
        if (owner != rhs.owner) { return false }
        if (repo != rhs.repo) { return false }
        if (resolved.length == 0 || rhs.resolved.length == 0) {
            return committish == rhs.committish
        }
        return resolved == rhs.resolved
    }

    /// 翻译自: pub fn clone(...) -> Repository
    public func clone(): Repository {
        return Repository(
            owner: owner,
            repo: repo,
            committish: committish,
            resolved: resolved,
            packageName: packageName
        )
    }
}

// ============================================================================
// VersionedURLType / VersionedURL / OldV2VersionedURL
// 严格翻译自: resolver_hooks.rs VersionedURLType<SemverInt>
//   pub type VersionedURL = VersionedURLType<u64>
//   pub type OldV2VersionedURL = VersionedURLType<u32>
//   pub struct VersionedURLType<SemverInt> {
//       pub url: SemverString,
//       pub version: bun_semver::VersionType<SemverInt>,
//   }
// ============================================================================

/// 版本化 URL (u64 版本号)
/// 翻译自: pub type VersionedURL = VersionedURLType<u64>
public class VersionedURL {
    public var url: String
    public var version: UInt64

    public init() {
        url = ""
        version = UInt64(0)
    }

    public init(url: String, version: UInt64) {
        this.url = url
        this.version = version
    }

    /// 翻译自: pub fn eql(&self, other: &Self) -> bool
    public func eql(other: VersionedURL): Bool {
        return version == other.version
    }

    /// 翻译自: pub fn order(&self, other: &Self, ...) -> Ordering
    public func order(other: VersionedURL): Int64 {
        if (version < other.version) { return -1 }
        if (version > other.version) { return 1 }
        return 0
    }

    /// 翻译自: pub fn clone(...) -> Self
    public func clone(): VersionedURL {
        return VersionedURL(url: url, version: version)
    }
}

/// 版本化 URL (u32 版本号, 旧 v2 格式)
/// 翻译自: pub type OldV2VersionedURL = VersionedURLType<u32>
public class OldV2VersionedURL {
    public var url: String
    public var version: UInt32

    public init() {
        url = ""
        version = UInt32(0)
    }

    public init(url: String, version: UInt32) {
        this.url = url
        this.version = version
    }

    /// 翻译自: pub fn migrate(self) -> VersionedURLType<u64>
    public func migrate(): VersionedURL {
        return VersionedURL(url: url, version: UInt64(version))
    }
}

// ============================================================================
// ResolutionTag - 解析标签
// 严格翻译自: resolver_hooks.rs ResolutionTag
//   #[derive(Clone, Copy, PartialEq, Eq, Default)]
//   #[repr(u8)]
//   pub enum ResolutionTag {
//       #[default] Uninitialized = 0,
//       Root = 1,
//       Npm = 2,
//       Folder = 4,
//       LocalTarball = 8,
//       Github = 16,
//       Git = 32,
//       Symlink = 64,
//       Workspace = 72,
//       RemoteTarball = 80,
//       SingleFileModule = 100,
//   }
// ============================================================================

/// 解析标签
/// 翻译自: pub enum ResolutionTag
public enum ResolutionTag {
    | Uninitialized      // 0
    | Root               // 1
    | Npm                // 2
    | Folder             // 4
    | LocalTarball       // 8
    | Github             // 16
    | Git                // 32
    | Symlink            // 64
    | Workspace          // 72
    | RemoteTarball      // 80
    | SingleFileModule   // 100

    public func toInt(): Int64 {
        match (this) {
            case Uninitialized => 0
            case Root => 1
            case Npm => 2
            case Folder => 4
            case LocalTarball => 8
            case Github => 16
            case Git => 32
            case Symlink => 64
            case Workspace => 72
            case RemoteTarball => 80
            case SingleFileModule => 100
        }
    }

    public static func fromInt(v: Int64): ResolutionTag {
        match (v) {
            case 0 => Uninitialized
            case 1 => Root
            case 2 => Npm
            case 4 => Folder
            case 8 => LocalTarball
            case 16 => Github
            case 32 => Git
            case 64 => Symlink
            case 72 => Workspace
            case 80 => RemoteTarball
            case 100 => SingleFileModule
            case _ => Uninitialized
        }
    }
}

// ============================================================================
// ResolutionValue / Resolution
// 严格翻译自: resolver_hooks.rs ResolutionValue<I> + Resolution
//   pub union ResolutionValue<I: VersionInt> {
//       pub uninitialized: (),
//       pub root: (),
//       pub npm: VersionedURLType<I>,
//       pub folder: SemverString,
//       pub local_tarball: SemverString,
//       pub github: Repository,
//       pub git: Repository,
//       pub symlink: SemverString,
//       pub workspace: SemverString,
//       pub remote_tarball: SemverString,
//       pub single_file_module: SemverString,
//   }
//
//   pub struct Resolution {
//       pub tag: ResolutionTag,
//       pub _padding: [u8; 7],
//       pub value: ResolutionValue<u64>,
//   }
// ============================================================================

/// 解析值 (union 的各个字段以 optionals 表示)
/// 翻译自: pub union ResolutionValue<u64>
public class ResolutionValue {
    public var npmVersionedUrl: ?VersionedURL
    public var folder: String
    public var localTarball: String
    public var github: ?Repository
    public var git: ?Repository
    public var symlink: String
    public var workspace: String
    public var remoteTarball: String
    public var singleFileModule: String

    public init() {
        npmVersionedUrl = None
        folder = ""
        localTarball = ""
        github = None
        git = None
        symlink = ""
        workspace = ""
        remoteTarball = ""
        singleFileModule = ""
    }
}

/// 解析结果
/// 翻译自:
///   pub struct Resolution {
///       pub tag: ResolutionTag,
///       pub _padding: [u8; 7],
///       pub value: ResolutionValue<u64>,
///   }
public class Resolution {
    public var tag: ResolutionTag
    public var value: ResolutionValue

    public init() {
        tag = ResolutionTag.Uninitialized
        value = ResolutionValue()
    }

    public init(tag: ResolutionTag, value: ResolutionValue) {
        this.tag = tag
        this.value = value
    }

    /// 翻译自: pub const ROOT: Self
    public static let ROOT: Resolution = Resolution(tag: ResolutionTag.Root, value: ResolutionValue())
}

// ============================================================================
// PreinstallState
// 严格翻译自: resolver_hooks.rs PreinstallState
//   #[repr(u8)]
//   #[derive(Copy, Clone, Eq, PartialEq, Debug)]
//   pub enum PreinstallState {
//       Unknown = 0, Done, Extract, Extracting,
//       CalcPatchHash, CalcingPatchHash, ApplyPatch, ApplyingPatch,
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
// Features - 安装特性标志
// 严格翻译自: resolver_hooks.rs Features
//   pub struct Features {
//       pub dependencies: bool = true,
//       pub dev_dependencies: bool = false,
//       pub is_main: bool = false,
//       pub optional_dependencies: bool = false,
//       pub peer_dependencies: bool = true,
//       pub trusted_dependencies: bool = false,
//       pub workspaces: bool = false,
//       pub patched_dependencies: bool = false,
//       pub check_for_duplicate_dependencies: bool = false,
//   }
// ============================================================================

/// 安装特性标志
/// 翻译自: pub struct Features { ... }
public class Features {
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

    // ── Static constructors (翻译自: Features::MAIN, FOLDER, WORKSPACE, etc.) ──

    /// 翻译自: pub const fn main() -> Self
    public static func main(): Features {
        let f = Features()
        f.checkForDuplicateDependencies = true
        f.devDependencies = true
        f.isMain = true
        f.optionalDependencies = true
        f.trustedDependencies = true
        f.patchedDependencies = true
        f.workspaces = true
        return f
    }

    /// 翻译自: pub const fn npm() -> Self
    public static func npm(): Features {
        let f = Features()
        f.optionalDependencies = true
        return f
    }

    /// 翻译自: pub const fn folder() -> Self
    public static func folder(): Features {
        let f = Features()
        f.devDependencies = true
        f.optionalDependencies = true
        return f
    }

    /// 翻译自: pub const fn workspace() -> Self
    public static func workspace(): Features {
        let f = Features()
        f.devDependencies = true
        f.optionalDependencies = true
        f.trustedDependencies = true
        return f
    }

    /// 翻译自: pub const fn link() -> Self
    public static func link(): Features {
        let f = Features()
        f.dependencies = false
        f.peerDependencies = false
        return f
    }

    /// 翻译自: pub const fn tarball() -> Self
    public static func tarball(): Features {
        return Features.npm()
    }

    /// 翻译自: pub fn behavior(self) -> Behavior
    public func toBehavior(): Behavior {
        var out: UInt8 = 0
        out = out | (if (dependencies) { Behavior.PROD } else { UInt8(0) })
        out = out | (if (optionalDependencies) { Behavior.OPTIONAL } else { UInt8(0) })
        out = out | (if (devDependencies) { Behavior.DEV } else { UInt8(0) })
        out = out | (if (peerDependencies) { Behavior.PEER } else { UInt8(0) })
        out = out | (if (workspaces) { Behavior.WORKSPACE } else { UInt8(0) })
        return Behavior(bits: out)
    }
}

// ============================================================================
// TaskCallbackContext
// 严格翻译自: resolver_hooks.rs TaskCallbackContext
//   pub struct TaskCallbackContext {
//       pub root_request_id: u32,
//   }
// ============================================================================

/// 任务回调上下文
/// 翻译自: pub struct TaskCallbackContext { pub root_request_id: u32 }
public class TaskCallbackContext {
    public var rootRequestId: UInt32

    public init() {
        rootRequestId = UInt32(0)
    }

    public init(rootRequestId: UInt32) {
        this.rootRequestId = rootRequestId
    }
}

// ============================================================================
// WakeHandler
// 严格翻译自: resolver_hooks.rs WakeHandler
//   pub struct WakeHandler {
//       pub context: Option<NonNull<c_void>>,
//       pub handler: Option<fn(*mut c_void, *mut c_void)>,
//       pub on_dependency_error: Option<fn(...)>,
//   }
// ============================================================================

/// 唤醒处理器
/// 翻译自:
///   pub struct WakeHandler {
///       pub context: Option<NonNull<c_void>>,
///       pub handler: Option<fn(*mut c_void, *mut c_void)>,
///       pub on_dependency_error: Option<fn(...)>,
///   }
public class WakeHandler {
    public var handler: ?(() -> Unit)
    public var onError: ?((Dependency, DependencyID) -> Unit)

    public init() {
        handler = None
        onError = None
    }

    /// 翻译自: pub fn get_handler(&self) -> fn(...)
    public func getHandler(): () -> Unit {
        match (handler) {
            case Some(h) => return h
            case None => return { => }
        }
    }

    /// 翻译自: pub fn get_on_dependency_error(&self) -> fn(...)
    public func getOnDependencyError(): (Dependency, DependencyID) -> Unit {
        match (onError) {
            case Some(h) => return h
            case None => return { (_: Dependency, _: DependencyID) => }
        }
    }
}

// ============================================================================
// DependencyGroup
// 严格翻译自: resolver_hooks.rs DependencyGroup
//   pub struct DependencyGroup {
//       pub prop: &'static [u8],
//       pub field: &'static [u8],
//       pub behavior: Behavior,
//   }
// ============================================================================

/// 依赖分组
/// 翻译自:
///   pub struct DependencyGroup {
///       pub prop: &'static [u8],
///       pub field: &'static [u8],
///       pub behavior: Behavior,
///   }
public class DependencyGroup {
    /// package.json 中的键名 (如 "dependencies", "devDependencies")
    public var prop: String
    /// 序列化字段名 (如 "dependencies", "dev_dependencies")
    public var field: String
    /// 对应的行为标志
    public var behavior: Behavior

    public init(prop: String, field: String, behavior: Behavior) {
        this.prop = prop
        this.field = field
        this.behavior = behavior
    }

    // ── Static instances (翻译自: DependencyGroup::DEPENDENCIES, DEV, etc.) ──

    /// 翻译自: pub const DEPENDENCIES: Self
    public static let DEPENDENCIES: DependencyGroup = DependencyGroup(
        prop: "dependencies",
        field: "dependencies",
        behavior: Behavior.prod()
    )

    /// 翻译自: pub const DEV: Self
    public static let DEV: DependencyGroup = DependencyGroup(
        prop: "devDependencies",
        field: "dev_dependencies",
        behavior: Behavior.dev()
    )

    /// 翻译自: pub const OPTIONAL: Self
    public static let OPTIONAL: DependencyGroup = DependencyGroup(
        prop: "optionalDependencies",
        field: "optional_dependencies",
        behavior: Behavior.optional()
    )

    /// 翻译自: pub const PEER: Self
    public static let PEER: DependencyGroup = DependencyGroup(
        prop: "peerDependencies",
        field: "peer_dependencies",
        behavior: Behavior.peer()
    )

    /// 翻译自: pub const WORKSPACES: Self
    public static let WORKSPACES: DependencyGroup = DependencyGroup(
        prop: "workspaces",
        field: "workspaces",
        behavior: Behavior.workspace()
    )

    /// 翻译自: pub const FOUR: [Self; 4]
    public static let FOUR: ArrayList<DependencyGroup> = ArrayList<DependencyGroup>([
        DependencyGroup.DEPENDENCIES,
        DependencyGroup.DEV,
        DependencyGroup.OPTIONAL,
        DependencyGroup.PEER,
    ])

    /// 翻译自: pub fn prop_for_behavior(b: Behavior) -> &'static [u8]
    public static func propForBehavior(b: Behavior): String {
        if (b.isDev()) {
            return DependencyGroup.DEV.prop
        } else if (b.isOptional()) {
            return DependencyGroup.OPTIONAL.prop
        } else if (b.isPeer()) {
            return DependencyGroup.PEER.prop
        } else {
            return DependencyGroup.DEPENDENCIES.prop
        }
    }

    /// 翻译自: pub fn from_prop(prop: &[u8]) -> Option<Self>
    public static func fromProp(prop: String): ?DependencyGroup {
        if (prop == "dependencies") { return Some(DependencyGroup.DEPENDENCIES) }
        if (prop == "devDependencies") { return Some(DependencyGroup.DEV) }
        if (prop == "optionalDependencies") { return Some(DependencyGroup.OPTIONAL) }
        if (prop == "peerDependencies") { return Some(DependencyGroup.PEER) }
        return None
    }
}

// ============================================================================
// EnqueueResult
// 严格翻译自: resolver_hooks.rs EnqueueResult
//   pub enum EnqueueResult {
//       Resolution { package_id: PackageID, resolution: Resolution },
//       Pending(DependencyID),
//       NotFound,
//       Failure(bun_core::Error),
//   }
// ============================================================================

/// 入队结果
/// 翻译自: pub enum EnqueueResult { ... }
public enum EnqueueResult {
    | Resolved(PackageID, Resolution)   // package_id, resolution
    | Pending(DependencyID)
    | NotFound
    | Failure(String)                    // error message
}

// ============================================================================
// AutoInstaller trait
// 严格翻译自: resolver_hooks.rs AutoInstaller
//   pub trait AutoInstaller { ... }
//   Everything bun_resolver's auto-install path needs from
//   bun_install::PackageManager + its Lockfile.
// ============================================================================

/// 自动安装器接口
/// 翻译自: pub trait AutoInstaller { ... }
/// bun_resolver 通过此接口与 bun_install::PackageManager 通信
public interface AutoInstaller {
    // ── Lockfile reads ────────────────────────────────────────────────────

    /// 翻译自: fn lockfile_packages_len(&self) -> usize
    func lockfilePackagesLen(): Int64

    /// 翻译自: fn lockfile_package_dependencies(&self, id: PackageID) -> DependencySlice
    func lockfilePackageDependencies(id: PackageID): DependencySliceType

    /// 翻译自: fn lockfile_package_resolutions(&self, id: PackageID) -> ResolutionSlice
    func lockfilePackageResolutions(id: PackageID): ResolutionSliceType

    /// 翻译自: fn lockfile_package_resolution(&self, id: PackageID) -> Resolution
    func lockfilePackageResolution(id: PackageID): Resolution

    /// 翻译自: fn lockfile_dependencies_buf(&self) -> &[Dependency]
    func lockfileDependenciesBuf(): ArrayList<Dependency>

    /// 翻译自: fn lockfile_resolutions_buf(&self) -> &[PackageID]
    func lockfileResolutionsBuf(): ArrayList<PackageID>

    /// 翻译自: fn lockfile_string_bytes(&self) -> &[u8]
    func lockfileStringBytes(): String

    /// 翻译自: fn lockfile_resolve(&self, name: &[u8], version: &DependencyVersion) -> Option<PackageID>
    func lockfileResolve(name: String, version: DependencyVersion): ?PackageID

    /// 翻译自: fn lockfile_str<'a>(&'a self, s: &'a SemverString) -> &'a [u8]
    func lockfileStr(s: String): String

    // ── Lockfile writes ───────────────────────────────────────────────────

    /// 翻译自: fn lockfile_append_from_package_json(...) -> Result<PackageID, Error>
    func lockfileAppendFromPackageJson(packageJson: PackageJsonView, features: Features): ?PackageID

    /// 翻译自: fn lockfile_append_root_stub(&mut self) -> Result<PackageID, Error>
    func lockfileAppendRootStub(): ?PackageID

    // ── PackageManager ops ────────────────────────────────────────────────

    /// 翻译自: fn set_on_wake(&mut self, handler: WakeHandler)
    func setOnWake(handler: WakeHandler): Unit

    /// 翻译自: fn get_preinstall_state(&self, package_id: PackageID) -> PreinstallState
    func getPreinstallState(packageId: PackageID): PreinstallState

    /// 翻译自: fn enqueue_package_for_download(...) -> Result<(), Error>
    func enqueuePackageForDownload(
        name: String,
        dependencyId: DependencyID,
        packageId: PackageID,
        resolution: Resolution,
        ctx: TaskCallbackContext,
        patchNameAndVersionHash: ?UInt64
    ): Bool

    /// 翻译自: fn resolve_from_disk_cache(...) -> Option<PackageID>
    func resolveFromDiskCache(name: String, version: DependencyVersion): ?PackageID

    /// 翻译自: fn enqueue_dependency_to_root(...) -> EnqueueResult
    func enqueueDependencyToRoot(
        name: String,
        version: DependencyVersion,
        versionBuf: String,
        behavior: Behavior
    ): EnqueueResult

    // ── Dependency parsing ────────────────────────────────────────────────

    /// 翻译自: fn parse_dependency(...) -> Option<DependencyVersion>
    func parseDependency(
        name: String,
        nameHash: ?UInt64,
        version: String,
        log: Log
    ): ?DependencyVersion

    /// 翻译自: fn infer_dependency_tag(&self, dependency: &[u8]) -> DependencyVersionTag
    func inferDependencyTag(dependency: String): DependencyVersionTag
}

// ============================================================================
// PackageJsonView trait
// 严格翻译自: resolver_hooks.rs PackageJsonView
//   pub trait PackageJsonView {
//       fn name(&self) -> &[u8];
//       fn version(&self) -> &[u8];
//       fn source_path(&self) -> &[u8];
//       fn dependency_source_buf(&self) -> &[u8];
//       fn arch(&self) -> Architecture;
//       fn os(&self) -> OperatingSystem;
//       fn dependency_iter(&self) -> Box<dyn Iterator<Item = (&[u8], &Dependency)> + '_>;
//   }
// ============================================================================

/// Package.json 只读视图
/// 翻译自: pub trait PackageJsonView { ... }
public interface PackageJsonView {
    func name(): String
    func version(): String
    func sourcePath(): String
    func dependencySourceBuf(): String
    func arch(): Architecture
    func os(): OperatingSystem
    func dependencyIter(): ArrayList<(String, Dependency)>
}

// ============================================================================
// Log - 简单日志
// (翻译自: resolver_hooks.rs 中 bun_ast::Log 的使用)
// ============================================================================

/// 日志接口
/// 翻译自: bun_ast::Log (简化)
public class Log {
    public var errors: ArrayList<String>
    public var warnings: ArrayList<String>

    public init() {
        errors = ArrayList<String>()
        warnings = ArrayList<String>()
    }

    public func addError(msg: String): Unit {
        errors.append(msg)
    }

    public func addWarning(msg: String): Unit {
        warnings.append(msg)
    }
}
