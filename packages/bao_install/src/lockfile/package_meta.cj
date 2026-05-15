// bao_install - 锁文件包元数据
// 严格翻译自: src/install/lockfile/Package/Meta.zig
//   Meta 包含包的来源、架构、操作系统、完整性校验等信息
package bao_install.lockfile

import bao_core.*
import bao_collections.*

// ============================================================================
// 安装脚本状态
// 严格翻译自: src/install/lockfile/Package/Meta.zig
//   has_install_script: enum(u8) { old = 0, false, true }
// ============================================================================

/// 安装脚本状态
/// 对应 Bun: Meta.has_install_script (enum)
public enum HasInstallScript : UInt8 {
    | Old    // 旧值: 该字段之前的默认值
    | False  // 无安装脚本
    | True   // 有安装脚本

    public func toBool(): Bool {
        match (this) {
            case Old => return false
            case False => return false
            case True => return true
        }
    }
}

// ============================================================================
// 包元数据
// 严格翻译自: src/install/lockfile/Package/Meta.zig
//   pub const Meta = extern struct {
//       origin: Origin = Origin.npm,
//       arch: Npm.Architecture = .all,
//       os: Npm.OperatingSystem = .all,
//       id: PackageID = invalid_package_id,
//       man_dir: String = .{},
//       integrity: Integrity = .{},
//       has_install_script: enum(u8) { old = 0, false, true } = .false,
//   }
// ============================================================================

/// 包元数据
/// 对应 Bun: Lockfile.Package.Meta
/// 翻译自: src/install/lockfile/Package/Meta.zig
public class PackageMeta {
    /// 包来源
    /// 翻译自: origin: Origin = Origin.npm
    public var origin: PackageOrigin

    /// CPU 架构
    /// 翻译自: arch: Npm.Architecture = .all
    public var arch: NpmArchitecture

    /// 操作系统
    /// 翻译自: os: Npm.OperatingSystem = .all
    public var os: NpmOperatingSystem

    /// 包 ID
    /// 翻译自: id: PackageID = invalid_package_id
    public var id: UInt32

    /// man 页目录
    /// 翻译自: man_dir: String = .{}
    public var manDir: String

    /// 完整性校验
    /// 翻译自: integrity: Integrity = .{}
    public var integrity: IntegrityInfo

    /// 是否有安装脚本
    /// 翻译自: has_install_script: enum(u8)
    public var hasInstallScript: HasInstallScript

    public init() {
        origin = PackageOrigin.NPM
        arch = NpmArchitecture.ALL
        os = NpmOperatingSystem.ALL
        id = INVALID_PACKAGE_ID
        manDir = ""
        integrity = IntegrityInfo()
        hasInstallScript = HasInstallScript.False
    }

    /// 是否被禁用 (架构或系统不匹配)
    /// 严格翻译自: Meta.isDisabled
    ///   pub fn isDisabled(this: *const Meta, cpu, os) bool
    public func isDisabled(cpu: NpmArchitecture, os: NpmOperatingSystem): Bool {
        return !arch.isMatch(cpu) || !os.isMatch(os)
    }

    /// 是否有安装脚本
    /// 严格翻译自: Meta.hasInstallScript
    ///   pub fn hasInstallScript(this: *const Meta) bool
    public func hasInstallScriptBool(): Bool {
        return hasInstallScript == HasInstallScript.True
    }

    /// 设置安装脚本状态
    /// 严格翻译自: Meta.setHasInstallScript
    ///   pub fn setHasInstallScript(this: *Meta, has_script: bool) void
    public func setHasInstallScript(hasScript: Bool): Unit {
        hasInstallScript = if (hasScript) { HasInstallScript.True } else { HasInstallScript.False }
    }

    /// 是否需要更新
    /// 严格翻译自: Meta.needsUpdate
    ///   pub fn needsUpdate(this: *const Meta) bool
    public func needsUpdate(): Bool {
        return hasInstallScript == HasInstallScript.Old
    }

    /// 克隆
    /// 严格翻译自: Meta.clone
    ///   pub fn clone(this: *const Meta, id, buf, builder) Meta
    public func clone(id: UInt32): PackageMeta {
        let meta = PackageMeta()
        meta.id = id
        meta.manDir = manDir
        meta.integrity = integrity
        meta.arch = arch
        meta.os = os
        meta.origin = origin
        meta.hasInstallScript = hasInstallScript
        return meta
    }
}

/// 无效包 ID 常量
/// 翻译自: invalid_package_id
public let INVALID_PACKAGE_ID: UInt32 = UInt32.MAX

// ============================================================================
// 包来源
// 翻译自: src/install/Origin.zig
// ============================================================================

/// 包来源
/// 对应 Bun: Origin
public enum PackageOrigin {
    | NPM
    | Git
    | GitHub
    | Tarball
    | Folder
    | Workspace
    | Symlink
    | Root
}

// ============================================================================
// NPM 架构
// 翻译自: Npm.Architecture
// ============================================================================

/// NPM 架构
/// 对应 Bun: Npm.Architecture
public enum NpmArchitecture {
    | ALL
    | X64
    | ARM64
    | IA32
    | MIPS
    | MIPSEL
    | PPC
    | PPC64
    | S390
    | S390X
    | RISCV64
    | LOONG64

    /// 是否匹配
    /// 翻译自: Architecture.isMatch
    public func isMatch(other: NpmArchitecture): Bool {
        match (this) {
            case ALL => return true
            case _ => return this == other || other == NpmArchitecture.ALL
        }
    }
}

// ============================================================================
// NPM 操作系统
// 翻译自: Npm.OperatingSystem
// ============================================================================

/// NPM 操作系统
/// 对应 Bun: Npm.OperatingSystem
public enum NpmOperatingSystem {
    | ALL
    | LINUX
    | MAC
    | WINDOWS
    | FREEBSD
    | OPENBSD
    | NETBSD
    | AIX
    | SUNOS
    | ANDROID

    /// 是否匹配
    /// 翻译自: OperatingSystem.isMatch
    public func isMatch(other: NpmOperatingSystem): Bool {
        match (this) {
            case ALL => return true
            case _ => return this == other || other == NpmOperatingSystem.ALL
        }
    }
}

// ============================================================================
// 完整性校验信息
// 翻译自: src/install/integrity.zig - Integrity
// ============================================================================

/// 完整性校验信息
/// 对应 Bun: Integrity
public class IntegrityInfo {
    /// 哈希算法标签
    public var tag: IntegrityTag
    /// 哈希值
    public var hashValue: String

    public init() {
        tag = IntegrityTag.Unknown
        hashValue = ""
    }

    public init(tag: IntegrityTag, hashValue: String) {
        this.tag = tag
        this.hashValue = hashValue
    }

    /// 是否为支持的完整性校验
    /// 翻译自: Integrity.tag.isSupported
    public func isSupported(): Bool {
        return tag != IntegrityTag.Unknown
    }

    /// 格式化为字符串
    public func format(): String {
        if (tag == IntegrityTag.Unknown) { return "" }
        return "${tag.name()}-${hashValue}"
    }
}

/// 完整性标签
/// 对应 Bun: Integrity.Tag
public enum IntegrityTag {
    | Unknown
    | SHA256
    | SHA384
    | SHA512
    | SHA1
    | MD5

    public func name(): String {
        match (this) {
            case Unknown => "unknown"
            case SHA256 => "sha256"
            case SHA384 => "sha384"
            case SHA512 => "sha512"
            case SHA1 => "sha1"
            case MD5 => "md5"
        }
    }
}
