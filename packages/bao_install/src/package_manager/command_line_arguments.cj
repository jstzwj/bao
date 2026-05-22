// bao_install - 命令行参数解析
// 严格翻译自: src/install/PackageManager/CommandLineArguments.zig
//   CLI Arguments for:
//     - bun install
//     - bun update
//     - bun patch
//     - bun patch-commit
//     - bun pm
//     - bun add
//     - bun remove
//     - bun link
//     - bun audit
package bao_install.package_manager

import bao_install.*

import bao_core.*
import bao_collections.*
import bao_io.*

// ============================================================================
// 平台相关后端标签
// 严格翻译自: CommandLineArguments.zig - platform_specific_backend_label
//   const platform_specific_backend_label = if (Environment.isMac)
//       "Possible values: \"clonefile\" (default), \"hardlink\", \"symlink\", \"copyfile\""
//   else
//       "Possible values: \"hardlink\" (default), \"symlink\", \"copyfile\"";
// ============================================================================

/// 平台相关后端标签
/// 翻译自: platform_specific_backend_label
public let PLATFORM_SPECIFIC_BACKEND_LABEL: String = "Possible values: \"hardlink\" (default), \"symlink\", \"copyfile\""

// ============================================================================
// 审计级别
// 严格翻译自: CommandLineArguments.zig - AuditLevel (Zig line 256)
//   pub const AuditLevel = enum {
//       low, moderate, high, critical,
//       const Map = bun.ComptimeStringMap(AuditLevel, .{ ... });
//       pub fn fromString(str: []const u8) ?AuditLevel
//       pub fn shouldIncludeSeverity(self: AuditLevel, severity: []const u8) bool
//   };
// ============================================================================

/// 审计级别
/// 对应 Bun: AuditLevel
/// 翻译自: Zig line 256
public enum AuditLevel {
    | Low
    | Moderate
    | High
    | Critical

    /// 从字符串解析审计级别
    /// 翻译自: AuditLevel.fromString
    ///   pub fn fromString(str: []const u8) ?AuditLevel
    public static func fromString(str: String): ?AuditLevel {
        if (str == "low") {
            return AuditLevel.Low
        }
        if (str == "moderate") {
            return AuditLevel.Moderate
        }
        if (str == "high") {
            return AuditLevel.High
        }
        if (str == "critical") {
            return AuditLevel.Critical
        }
        return None
    }

    /// 检查是否应包含指定严重级别
    /// 翻译自: AuditLevel.shouldIncludeSeverity
    ///   pub fn shouldIncludeSeverity(self: AuditLevel, severity: []const u8) bool
    public func shouldIncludeSeverity(severity: String): Bool {
        let severityLevel = AuditLevel.fromString(severity)
        match (severityLevel) {
            case Some(level) => return level.ordinal() >= this.ordinal()
            case None => return AuditLevel.Moderate.ordinal() >= this.ordinal()
        }
    }

    /// 获取序号用于比较
    public func ordinal(): Int64 {
        match (this) {
            case AuditLevel.Low => return 0
            case AuditLevel.Moderate => return 1
            case AuditLevel.High => return 2
            case AuditLevel.Critical => return 3
        }
    }
}

// ============================================================================
// 补丁选项
// 严格翻译自: CommandLineArguments.zig - PatchOpts (Zig line 279)
//   const PatchOpts = union(enum) {
//       nothing: struct {},
//       patch: struct {},
//       commit: struct { patches_dir: []const u8 = "patches" },
//   };
// ============================================================================

/// 补丁选项
/// 对应 Bun: PatchOpts
/// 翻译自: Zig line 279
public enum PatchOpts {
    | `Nothing`
    | Patch
    | Commit(String) // patches_dir

    /// 获取 patches_dir
    /// 对于 Commit 变体返回关联的目录, 否则返回 "patches"
    public func patchesDir(): String {
        match (this) {
            case PatchOpts.Commit(dir) => return dir
            case _ => return "patches"
        }
    }
}

// ============================================================================
// Omit 结构
// 严格翻译自: CommandLineArguments.zig - Omit (Zig line 287)
//   const Omit = struct {
//       dev: bool = false,
//       optional: bool = false,
//       peer: bool = false,
//   };
// ============================================================================

/// Omit 选项
/// 对应 Bun: Omit
/// 翻译自: Zig line 287
public class Omit {
    public var dev: Bool
    public var optional: Bool
    public var peer: Bool

    public init() {
        dev = false
        optional = false
        peer = false
    }

    /// 从字符串解析 omit 值
    /// 翻译自: CommandLineArguments.parse 中的 omit 解析逻辑
    public static func fromValues(omitValues: ArrayList<String>): ?Omit {
        if (omitValues.size == 0) {
            return None
        }
        var omit = Omit()
        for (omitValue in omitValues) {
            if (omitValue == "dev") {
                omit.dev = true
            } else if (omitValue == "optional") {
                omit.optional = true
            } else if (omitValue == "peer") {
                omit.peer = true
            } else {
                return None
            }
        }
        return Some(omit)
    }
}

// ============================================================================
// 发布配置
// 严格翻译自: CommandLineArguments.zig - publish_config: Options.PublishConfig
//   (在 Options/PackageManagerOptions.zig 中定义)
// ============================================================================

/// 发布配置
/// 对应 Bun: Options.PublishConfig
public class PublishConfig {
    public var tag: String
    public var access: ?Access
    public var otp: String
    public var authType: ?AuthType

    public init() {
        tag = "latest"
        access = None
        otp = ""
        authType = None
    }
}

/// 访问级别
/// 对应 Bun: Options.Access
public enum Access {
    | Public
    | Restricted
    | Unspecified

    public static func fromStr(str: String): ?Access {
        if (str == "public") {
            return Access.Public
        }
        if (str == "restricted") {
            return Access.Restricted
        }
        return None
    }
}

/// 认证类型
/// 对应 Bun: Options.AuthType
public enum AuthType {
    | Web
    | Legacy

    public static func fromStr(str: String): ?AuthType {
        if (str == "web") {
            return AuthType.Web
        }
        if (str == "legacy") {
            return AuthType.Legacy
        }
        return None
    }
}

// ============================================================================
// Node 链接器
// 严格翻译自: Options.NodeLinker
// ============================================================================

/// Node 链接器类型
/// 对应 Bun: Options.NodeLinker
public enum NodeLinker {
    | Auto
    | Isolated
    | Hoisted

    public static func fromStr(str: String): ?NodeLinker {
        if (str == "isolated") {
            return NodeLinker.Isolated
        }
        if (str == "hoisted") {
            return NodeLinker.Hoisted
        }
        return None
    }
}

// ============================================================================
// 包安装方法
// 严格翻译自: PackageInstall.Method
// ============================================================================

/// 包安装方法
/// 对应 Bun: PackageInstall.Method
public enum PackageInstallMethod {
    | CloneFile
    | HardLink
    | Symlink
    | CopyFile

    /// 检查是否支持
    public func isSupported(): Bool {
        return true
    }

    /// 从字符串获取方法
    public static func fromStr(str: String): ?PackageInstallMethod {
        if (str == "clonefile") {
            return PackageInstallMethod.CloneFile
        }
        if (str == "hardlink") {
            return PackageInstallMethod.HardLink
        }
        if (str == "symlink") {
            return PackageInstallMethod.Symlink
        }
        if (str == "copyfile") {
            return PackageInstallMethod.CopyFile
        }
        return None
    }
}

// ============================================================================
// NPM 架构 / 操作系统 (简化)
// 严格翻译自: Npm.Architecture / Npm.OperatingSystem
// ============================================================================

/// NPM 架构 (简化)
/// 对应 Bun: Npm.Architecture
public class NpmArchitecture {
    public var values: ArrayList<String>

    public init() {
        values = ArrayList<String>()
    }

    /// 空架构集合
    public static func none(): NpmArchitecture {
        return NpmArchitecture()
    }

    /// 创建可协商版本
    public func negatable(): NegatableSet {
        return NegatableSet()
    }

    /// 当前平台架构
    public static let current: NpmArchitecture = NpmArchitecture()
}

/// NPM 操作系统 (简化)
/// 对应 Bun: Npm.OperatingSystem
public class NpmOperatingSystem {
    public var values: ArrayList<String>

    public init() {
        values = ArrayList<String>()
    }

    /// 空操作系统集合
    public static func none(): NpmOperatingSystem {
        return NpmOperatingSystem()
    }

    /// 创建可协商版本
    public func negatable(): NegatableSet {
        return NegatableSet()
    }

    /// 当前平台操作系统
    public static let current: NpmOperatingSystem = NpmOperatingSystem()
}

/// 可协商集合 (用于 --cpu 和 --os 标志)
/// 对应 Bun: Npm.Architecture.negatable() / Npm.OperatingSystem.negatable()
public class NegatableSet {
    public var hadWildcard: Bool
    public var hadUnrecognizedValues: Bool

    public init() {
        hadWildcard = false
        hadUnrecognizedValues = false
    }

    /// 应用一个值
    public func apply(value: String): Unit {
        if (value == "any") {
            hadWildcard = true
        }
    }

    /// 合并结果
    public func combine(): NpmArchitecture {
        return NpmArchitecture()
    }
}

// ============================================================================
// 子命令
// 严格翻译自: bun.install.PackageManager.Subcommand
// ============================================================================

/// 子命令类型
/// 对应 Bun: PackageManager.Subcommand
public enum Subcommand {
    | Install
    | Update
    | Pm
    | Add
    | Remove
    | Link
    | Unlink
    | Patch
    | PatchCommit
    | Outdated
    | Pack
    | Publish
    | Audit
    | Info
    | Why
    | Scan

    public operator func ==(right: Subcommand): Bool {
        match (this) {
            case Install => match (right) { case Install => true case _ => false }
            case Update => match (right) { case Update => true case _ => false }
            case Pm => match (right) { case Pm => true case _ => false }
            case Add => match (right) { case Add => true case _ => false }
            case Remove => match (right) { case Remove => true case _ => false }
            case Link => match (right) { case Link => true case _ => false }
            case Unlink => match (right) { case Unlink => true case _ => false }
            case Patch => match (right) { case Patch => true case _ => false }
            case PatchCommit => match (right) { case PatchCommit => true case _ => false }
            case Outdated => match (right) { case Outdated => true case _ => false }
            case Pack => match (right) { case Pack => true case _ => false }
            case Publish => match (right) { case Publish => true case _ => false }
            case Audit => match (right) { case Audit => true case _ => false }
            case Info => match (right) { case Info => true case _ => false }
            case Why => match (right) { case Why => true case _ => false }
            case Scan => match (right) { case Scan => true case _ => false }
        }
    }
    public operator func !=(right: Subcommand): Bool { !(this == right) }

    /// 是否支持工作区过滤
    public func supportsWorkspaceFiltering(): Bool {
        match (this) {
            case Subcommand.Install => return true
            case Subcommand.Update => return true
            case Subcommand.Outdated => return true
            case Subcommand.Pack => return true
            case _ => return false
        }
    }

    /// 是否支持 JSON 输出
    public func supportsJsonOutput(): Bool {
        match (this) {
            case Subcommand.Pm => return true
            case Subcommand.Audit => return true
            case Subcommand.Info => return true
            case Subcommand.Why => return true
            case _ => return false
        }
    }
}

// ============================================================================
// 共享参数定义
// 严格翻译自: CommandLineArguments.zig - shared_params (Zig line 21)
//   const shared_params = [_]ParamType{ ... };
//
// 注意: Cangjie 中没有 clap 参数定义系统, 使用参数描述列表替代
// ============================================================================

/// 共享参数描述
/// 对应 Bun: shared_params
/// 翻译自: Zig line 21
public class SharedParams {
    public var config: ?String
    public var yarn: Bool
    public var production: Bool
    public var prod: Bool
    public var noSave: Bool
    public var save: Bool
    public var ca: ArrayList<String>
    public var cafileName: String
    public var dryRun: Bool
    public var frozenLockfile: Bool
    public var force: Bool
    public var cacheDir: ?String
    public var noCache: Bool
    public var silent: Bool
    public var quiet: Bool
    public var verbose: Bool
    public var noProgress: Bool
    public var noSummary: Bool
    public var noVerify: Bool
    public var ignoreScripts: Bool
    public var trust: Bool
    public var global: Bool
    public var cwd: ?String
    public var backend: ?String
    public var registry: ?String
    public var concurrentScripts: ?String
    public var networkConcurrency: ?String
    public var saveTextLockfile: Bool
    public var omit: ArrayList<String>
    public var lockfileOnly: Bool
    public var linker: ?String
    public var minimumReleaseAge: ?String
    public var cpu: ArrayList<String>
    public var os: ArrayList<String>
    public var help: Bool

    public init() {
        config = None
        yarn = false
        production = false
        prod = false
        noSave = false
        save = false
        ca = ArrayList<String>()
        cafileName = ""
        dryRun = false
        frozenLockfile = false
        force = false
        cacheDir = None
        noCache = false
        silent = false
        quiet = false
        verbose = false
        noProgress = false
        noSummary = false
        noVerify = false
        ignoreScripts = false
        trust = false
        global = false
        cwd = None
        backend = None
        registry = None
        concurrentScripts = None
        networkConcurrency = None
        saveTextLockfile = false
        omit = ArrayList<String>()
        lockfileOnly = false
        linker = None
        minimumReleaseAge = None
        cpu = ArrayList<String>()
        os = ArrayList<String>()
        help = false
    }
}

// ============================================================================
// 安装参数
// 严格翻译自: CommandLineArguments.zig - install_params (Zig line 59)
//   pub const install_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// 安装参数描述
/// 对应 Bun: install_params
/// 翻译自: Zig line 59
public class InstallParams {
    public var shared: SharedParams
    public var dev: Bool
    public var development: Bool
    public var optional: Bool
    public var peer: Bool
    public var exact: Bool
    public var filter: ArrayList<String>
    public var analyze: Bool
    public var onlyMissing: Bool
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        dev = false
        development = false
        optional = false
        peer = false
        exact = false
        filter = ArrayList<String>()
        analyze = false
        onlyMissing = false
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// 更新参数
// 严格翻译自: CommandLineArguments.zig - update_params (Zig line 71)
//   pub const update_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// 更新参数描述
/// 对应 Bun: update_params
/// 翻译自: Zig line 71
public class UpdateParams {
    public var shared: SharedParams
    public var latest: Bool
    public var interactive: Bool
    public var filter: ArrayList<String>
    public var recursive: Bool
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        latest = false
        interactive = false
        filter = ArrayList<String>()
        recursive = false
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// PM 参数
// 严格翻译自: CommandLineArguments.zig - pm_params (Zig line 79)
//   pub const pm_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// PM 参数描述
/// 对应 Bun: pm_params
/// 翻译自: Zig line 79
public class PmParams {
    public var shared: SharedParams
    public var all: Bool
    public var jsonOutput: Bool
    public var destination: ?String
    public var filename: ?String
    public var gzipLevel: ?String
    public var gitTagVersion: ?String
    public var noGitTagVersion: Bool
    public var allowSameVersion: Bool
    public var message: ?String
    public var preid: ?String
    public var top: Bool
    public var depth: ?String
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        all = false
        jsonOutput = false
        destination = None
        filename = None
        gzipLevel = None
        gitTagVersion = None
        noGitTagVersion = false
        allowSameVersion = false
        message = None
        preid = None
        top = false
        depth = None
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// Add 参数
// 严格翻译自: CommandLineArguments.zig - add_params (Zig line 96)
//   pub const add_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Add 参数描述
/// 对应 Bun: add_params
/// 翻译自: Zig line 96
public class AddParams {
    public var shared: SharedParams
    public var dev: Bool
    public var development: Bool
    public var optional: Bool
    public var peer: Bool
    public var exact: Bool
    public var analyze: Bool
    public var onlyMissing: Bool
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        dev = false
        development = false
        optional = false
        peer = false
        exact = false
        analyze = false
        onlyMissing = false
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// Remove 参数
// 严格翻译自: CommandLineArguments.zig - remove_params (Zig line 107)
//   pub const remove_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Remove 参数描述
/// 对应 Bun: remove_params
/// 翻译自: Zig line 107
public class RemoveParams {
    public var shared: SharedParams
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// Link 参数
// 严格翻译自: CommandLineArguments.zig - link_params (Zig line 111)
//   pub const link_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Link 参数描述
/// 对应 Bun: link_params
/// 翻译自: Zig line 111
public class LinkParams {
    public var shared: SharedParams
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// Unlink 参数
// 严格翻译自: CommandLineArguments.zig - unlink_params (Zig line 115)
//   pub const unlink_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Unlink 参数描述
/// 对应 Bun: unlink_params
/// 翻译自: Zig line 115
public class UnlinkParams {
    public var shared: SharedParams
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// Patch 参数
// 严格翻译自: CommandLineArguments.zig - patch_params (Zig line 119)
//   const patch_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Patch 参数描述
/// 对应 Bun: patch_params
/// 翻译自: Zig line 119
public class PatchParams {
    public var shared: SharedParams
    public var positionals: ArrayList<String>
    public var commit: Bool
    public var patchesDir: ?String

    public init() {
        shared = SharedParams()
        positionals = ArrayList<String>()
        commit = false
        patchesDir = None
    }
}

// ============================================================================
// PatchCommit 参数
// 严格翻译自: CommandLineArguments.zig - patch_commit_params (Zig line 125)
//   const patch_commit_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// PatchCommit 参数描述
/// 对应 Bun: patch_commit_params
/// 翻译自: Zig line 125
public class PatchCommitParams {
    public var shared: SharedParams
    public var positionals: ArrayList<String>
    public var patchesDir: ?String

    public init() {
        shared = SharedParams()
        positionals = ArrayList<String>()
        patchesDir = None
    }
}

// ============================================================================
// Outdated 参数
// 严格翻译自: CommandLineArguments.zig - outdated_params (Zig line 130)
//   const outdated_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Outdated 参数描述
/// 对应 Bun: outdated_params
/// 翻译自: Zig line 130
public class OutdatedParams {
    public var shared: SharedParams
    public var filter: ArrayList<String>
    public var recursive: Bool
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        filter = ArrayList<String>()
        recursive = false
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// Audit 参数
// 严格翻译自: CommandLineArguments.zig - audit_params (Zig line 137)
//   const audit_params: []const ParamType = &([_]ParamType{ ... };
// ============================================================================

/// Audit 参数描述
/// 对应 Bun: audit_params
/// 翻译自: Zig line 137
public class AuditParams {
    public var positionals: ArrayList<String>
    public var jsonOutput: Bool
    public var auditLevel: ?String
    public var ignore: ArrayList<String>

    public init() {
        positionals = ArrayList<String>()
        jsonOutput = false
        auditLevel = None
        ignore = ArrayList<String>()
    }
}

// ============================================================================
// Info 参数
// 严格翻译自: CommandLineArguments.zig - info_params (Zig line 144)
//   const info_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Info 参数描述
/// 对应 Bun: info_params
/// 翻译自: Zig line 144
public class InfoParams {
    public var shared: SharedParams
    public var positionals: ArrayList<String>
    public var jsonOutput: Bool

    public init() {
        shared = SharedParams()
        positionals = ArrayList<String>()
        jsonOutput = false
    }
}

// ============================================================================
// Pack 参数
// 严格翻译自: CommandLineArguments.zig - pack_params (Zig line 149)
//   const pack_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Pack 参数描述
/// 对应 Bun: pack_params
/// 翻译自: Zig line 149
public class PackParams {
    public var shared: SharedParams
    public var destination: ?String
    public var filename: ?String
    public var gzipLevel: ?String
    public var positionals: ArrayList<String>

    public init() {
        shared = SharedParams()
        destination = None
        filename = None
        gzipLevel = None
        positionals = ArrayList<String>()
    }
}

// ============================================================================
// Publish 参数
// 严格翻译自: CommandLineArguments.zig - publish_params (Zig line 157)
//   const publish_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Publish 参数描述
/// 对应 Bun: publish_params
/// 翻译自: Zig line 157
public class PublishParams {
    public var shared: SharedParams
    public var positionals: ArrayList<String>
    public var access: ?String
    public var tag: ?String
    public var otp: ?String
    public var authType: ?String
    public var gzipLevel: ?String
    public var tolerateRepublish: Bool

    public init() {
        shared = SharedParams()
        positionals = ArrayList<String>()
        access = None
        tag = None
        otp = None
        authType = None
        gzipLevel = None
        tolerateRepublish = false
    }
}

// ============================================================================
// Why 参数
// 严格翻译自: CommandLineArguments.zig - why_params (Zig line 167)
//   const why_params: []const ParamType = &(shared_params ++ [_]ParamType{ ... });
// ============================================================================

/// Why 参数描述
/// 对应 Bun: why_params
/// 翻译自: Zig line 167
public class WhyParams {
    public var shared: SharedParams
    public var positionals: ArrayList<String>
    public var top: Bool
    public var depth: ?String

    public init() {
        shared = SharedParams()
        positionals = ArrayList<String>()
        top = false
        depth = None
    }
}

// ============================================================================
// CommandLineArguments 结构体
// 严格翻译自: CommandLineArguments.zig - CommandLineArguments (Zig line 173)
//   cache_dir: ?string = null,
//   lockfile: string = "",
//   token: string = "",
//   global: bool = false,
//   config: ?string = null,
//   ...
// ============================================================================

/// 命令行参数
/// 对应 Bun: CommandLineArguments (整个 @This() 结构体)
/// 翻译自: Zig line 13-255
public class CommandLineArguments {
    // 翻译自: cache_dir: ?string = null (Zig line 173)
    public var cacheDir: ?String

    // 翻译自: lockfile: string = "" (Zig line 174)
    public var lockfile: String

    // 翻译自: token: string = "" (Zig line 175)
    public var token: String

    // 翻译自: global: bool = false (Zig line 176)
    public var global: Bool

    // 翻译自: config: ?string = null (Zig line 177)
    public var config: ?String

    // 翻译自: network_concurrency: ?u16 = null (Zig line 178)
    public var networkConcurrency: ?UInt32

    // 翻译自: backend: ?PackageInstall.Method = null (Zig line 179)
    public var backend: ?PackageInstallMethod

    // 翻译自: analyze: bool = false (Zig line 180)
    public var analyze: Bool

    // 翻译自: only_missing: bool = false (Zig line 181)
    public var onlyMissing: Bool

    // 翻译自: positionals: []const string = &[_]string{} (Zig line 182)
    public var positionals: ArrayList<String>

    // 翻译自: yarn: bool = false (Zig line 184)
    public var yarn: Bool

    // 翻译自: production: bool = false (Zig line 185)
    public var production: Bool

    // 翻译自: frozen_lockfile: bool = false (Zig line 186)
    public var frozenLockfile: Bool

    // 翻译自: no_save: bool = false (Zig line 187)
    public var noSave: Bool

    // 翻译自: dry_run: bool = false (Zig line 188)
    public var dryRun: Bool

    // 翻译自: force: bool = false (Zig line 189)
    public var force: Bool

    // 翻译自: no_cache: bool = false (Zig line 190)
    public var noCache: Bool

    // 翻译自: silent: bool = false (Zig line 191)
    public var silent: Bool

    // 翻译自: quiet: bool = false (Zig line 192)
    public var quiet: Bool

    // 翻译自: verbose: bool = false (Zig line 193)
    public var verbose: Bool

    // 翻译自: no_progress: bool = false (Zig line 194)
    public var noProgress: Bool

    // 翻译自: no_verify: bool = false (Zig line 195)
    public var noVerify: Bool

    // 翻译自: ignore_scripts: bool = false (Zig line 196)
    public var ignoreScripts: Bool

    // 翻译自: trusted: bool = false (Zig line 197)
    public var trusted: Bool

    // 翻译自: no_summary: bool = false (Zig line 198)
    public var noSummary: Bool

    // 翻译自: latest: bool = false (Zig line 199)
    public var latest: Bool

    // 翻译自: interactive: bool = false (Zig line 200)
    public var interactive: Bool

    // 翻译自: json_output: bool = false (Zig line 201)
    public var jsonOutput: Bool

    // 翻译自: recursive: bool = false (Zig line 202)
    public var recursive: Bool

    // 翻译自: filters: []const string = &.{} (Zig line 203)
    public var filters: ArrayList<String>

    // 翻译自: pack_destination: string = "" (Zig line 205)
    public var packDestination: String

    // 翻译自: pack_filename: string = "" (Zig line 206)
    public var packFilename: String

    // 翻译自: pack_gzip_level: ?string = null (Zig line 207)
    public var packGzipLevel: ?String

    // 翻译自: development: bool = false (Zig line 209)
    public var development: Bool

    // 翻译自: optional: bool = false (Zig line 210)
    public var optional: Bool

    // 翻译自: peer: bool = false (Zig line 211)
    public var peer: Bool

    // 翻译自: omit: ?Omit = null (Zig line 213)
    public var omit: ?Omit

    // 翻译自: exact: bool = false (Zig line 215)
    public var exact: Bool

    // 翻译自: concurrent_scripts: ?usize = null (Zig line 217)
    public var concurrentScripts: ?Int64

    // 翻译自: patch: PatchOpts = .{ .nothing = .{} } (Zig line 219)
    public var patch: PatchOpts

    // 翻译自: registry: string = "" (Zig line 221)
    public var registry: String

    // 翻译自: publish_config: Options.PublishConfig = .{} (Zig line 223)
    public var publishConfig: PublishConfig

    // 翻译自: tolerate_republish: bool = false (Zig line 225)
    public var tolerateRepublish: Bool

    // 翻译自: ca: []const string = &.{} (Zig line 227)
    public var ca: ArrayList<String>

    // 翻译自: ca_file_name: string = "" (Zig line 228)
    public var caFileName: String

    // 翻译自: save_text_lockfile: ?bool = null (Zig line 230)
    public var saveTextLockfile: ?Bool

    // 翻译自: lockfile_only: bool = false (Zig line 232)
    public var lockfileOnly: Bool

    // 翻译自: node_linker: ?Options.NodeLinker = null (Zig line 234)
    public var nodeLinker: ?NodeLinker

    // 翻译自: minimum_release_age_ms: ?f64 = null (Zig line 236)
    public var minimumReleaseAgeMs: ?Float64

    // 翻译自: git_tag_version: bool = true (Zig line 239)
    public var gitTagVersion: Bool

    // 翻译自: allow_same_version: bool = false (Zig line 240)
    public var allowSameVersion: Bool

    // 翻译自: preid: string = "" (Zig line 241)
    public var preid: String

    // 翻译自: message: ?string = null (Zig line 242)
    public var message: ?String

    // 翻译自: top_only: bool = false (Zig line 245)
    public var topOnly: Bool

    // 翻译自: depth: ?usize = null (Zig line 246)
    public var depth: ?Int64

    // 翻译自: audit_level: ?AuditLevel = null (Zig line 249)
    public var auditLevel: ?AuditLevel

    // 翻译自: audit_ignore_list: []const string = &.{} (Zig line 250)
    public var auditIgnoreList: ArrayList<String>

    // 翻译自: cpu: Npm.Architecture = Npm.Architecture.current (Zig line 253)
    public var cpu: NpmArchitecture

    // 翻译自: os: Npm.OperatingSystem = Npm.OperatingSystem.current (Zig line 254)
    public var os: NpmOperatingSystem

    public init() {
        cacheDir = None
        lockfile = ""
        token = ""
        global = false
        config = None
        networkConcurrency = None
        backend = None
        analyze = false
        onlyMissing = false
        positionals = ArrayList<String>()
        yarn = false
        production = false
        frozenLockfile = false
        noSave = false
        dryRun = false
        force = false
        noCache = false
        silent = false
        quiet = false
        verbose = false
        noProgress = false
        noVerify = false
        ignoreScripts = false
        trusted = false
        noSummary = false
        latest = false
        interactive = false
        jsonOutput = false
        recursive = false
        filters = ArrayList<String>()
        packDestination = ""
        packFilename = ""
        packGzipLevel = None
        development = false
        optional = false
        peer = false
        omit = None
        exact = false
        concurrentScripts = None
        patch = PatchOpts.`Nothing`
        registry = ""
        publishConfig = PublishConfig()
        tolerateRepublish = false
        ca = ArrayList<String>()
        caFileName = ""
        saveTextLockfile = None
        lockfileOnly = false
        nodeLinker = None
        minimumReleaseAgeMs = None
        gitTagVersion = true
        allowSameVersion = false
        preid = ""
        message = None
        topOnly = false
        depth = None
        auditLevel = None
        auditIgnoreList = ArrayList<String>()
        cpu = NpmArchitecture.current
        os = NpmOperatingSystem.current
    }

    // ========================================================================
    // printHelp
    // 严格翻译自: CommandLineArguments.zig - printHelp (Zig line 293)
    //   pub fn printHelp(subcommand: Subcommand) void
    // ========================================================================

    /// 打印帮助信息
    /// 翻译自: printHelp
    ///   pub fn printHelp(subcommand: Subcommand) void
    ///   根据 subcommand 打印对应的帮助文本
    public static func printHelp(subcommand: Subcommand): Unit {
        match (subcommand) {
            case Subcommand.Install => printHelpInstall()
            case Subcommand.Update => printHelpUpdate()
            case Subcommand.Patch => printHelpPatch()
            case Subcommand.PatchCommit => printHelpPatchCommit()
            case Subcommand.Pm => printHelpPm()
            case Subcommand.Add => printHelpAdd()
            case Subcommand.Remove => printHelpRemove()
            case Subcommand.Link => printHelpLink()
            case Subcommand.Unlink => printHelpUnlink()
            case Subcommand.Outdated => printHelpOutdated()
            case Subcommand.Pack => printHelpPack()
            case Subcommand.Publish => printHelpPublish()
            case Subcommand.Audit => printHelpAudit()
            case Subcommand.Info => printHelpInfo()
            case Subcommand.Why => printHelpWhy()
            case Subcommand.Scan => printHelpScan()
        }
    }

    /// 翻译自: printHelp - install case (Zig line 301)
    private static func printHelpInstall(): Unit {
        let introText =
            "\n" +
            "Usage: bun install [flags] <name>@<version>\n" +
            "Alias: bun i\n" +
            "\n" +
            "  Install the dependencies listed in package.json.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Install the dependencies for the current project\n" +
            "  bun install\n" +
            "\n" +
            "  Skip devDependencies\n" +
            "  bun install --production\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/install.\n"
        Output.pretty(introText)
        Output.simpleHelp("install")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - update case (Zig line 330)
    private static func printHelpUpdate(): Unit {
        let introText =
            "\n" +
            "Usage: bun update [flags] <name>@<version>\n" +
            "\n" +
            "  Update dependencies to their most recent versions within the version range in package.json.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Update all dependencies:\n" +
            "  bun update\n" +
            "\n" +
            "  Update all dependencies to latest:\n" +
            "  bun update --latest\n" +
            "\n" +
            "  Interactive update (select packages to update):\n" +
            "  bun update -i\n" +
            "\n" +
            "  Update specific packages:\n" +
            "  bun update zod jquery@3\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/update.\n"
        Output.pretty(introText)
        Output.simpleHelp("update")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - patch case (Zig line 363)
    private static func printHelpPatch(): Unit {
        let introText =
            "\n" +
            "Usage: bun patch [flags or options] <package>@<version>\n" +
            "\n" +
            "  Prepare a package for patching, or generate and save a patch.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Prepare jquery for patching\n" +
            "  bun patch jquery\n" +
            "\n" +
            "  Generate a patch file for changes made to jquery\n" +
            "  bun patch --commit 'node_modules/jquery'\n" +
            "\n" +
            "  Generate a patch file in a custom directory for changes made to jquery\n" +
            "  bun patch --patches-dir 'my-patches' 'node_modules/jquery'\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/install/patch.\n"
        Output.pretty(introText)
        Output.simpleHelp("patch")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - patch-commit case (Zig line 395)
    private static func printHelpPatchCommit(): Unit {
        let introText =
            "\n" +
            "Usage: bun patch-commit [flags or options] <directory>\n" +
            "\n" +
            "  Generate a patch out of a directory and save it. This is equivalent to bun patch --commit.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Generate a patch in the default \"./patches\" directory for changes in \"./node_modules/jquery\"\n" +
            "  bun patch-commit 'node_modules/jquery'\n" +
            "\n" +
            "  Generate a patch in a custom directory (\"./my-patches\")\n" +
            "  bun patch-commit --patches-dir 'my-patches' 'node_modules/jquery'\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/install/patch.\n"
        Output.pretty(introText)
        Output.simpleHelp("patch")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - pm case (Zig line 422)
    private static func printHelpPm(): Unit {
        PackageManagerCommandPrintHelper.printHelp()
    }

    /// 翻译自: printHelp - add case (Zig line 425)
    private static func printHelpAdd(): Unit {
        let introText =
            "\n" +
            "Usage: bun add [flags] <package><@version>\n" +
            "Alias: bun a\n" +
            "\n" +
            "  Add a new dependency to package.json and install it.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Add a dependency from the npm registry\n" +
            "  bun add zod\n" +
            "  bun add zod@next\n" +
            "  bun add zod@3.0.0\n" +
            "\n" +
            "  Add a dev, optional, or peer dependency\n" +
            "  bun add -d typescript\n" +
            "  bun add --optional lodash\n" +
            "  bun add --peer esbuild\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/add.\n"
        Output.pretty(introText)
        Output.simpleHelp("add")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - remove case (Zig line 457)
    private static func printHelpRemove(): Unit {
        let introText =
            "\n" +
            "Usage: bun remove [flags] [<packages>]\n" +
            "Alias: bun r\n" +
            "\n" +
            "  Remove a package from package.json and uninstall from node_modules.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Remove a dependency\n" +
            "  bun remove ts-node\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/remove.\n"
        Output.pretty(introText)
        Output.simpleHelp("remove")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - link case (Zig line 482)
    private static func printHelpLink(): Unit {
        let introText =
            "\n" +
            "Usage: bun link [flags] [<packages>]\n" +
            "\n" +
            "  Register a local directory as a \"linkable\" package, or link a \"linkable\" package to the current project.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Register the current directory as a linkable package.\n" +
            "  Directory should contain a package.json.\n" +
            "  bun link\n" +
            "\n" +
            "  Add a previously-registered linkable package as a dependency of the current project.\n" +
            "  bun link <package>\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/link.\n"
        Output.pretty(introText)
        Output.simpleHelp("link")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - unlink case (Zig line 510)
    private static func printHelpUnlink(): Unit {
        let introText =
            "\n" +
            "Usage: bun unlink [flags]\n" +
            "\n" +
            "  Unregister the current directory as a \"linkable\" package.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Unregister the current directory as a linkable package.\n" +
            "  bun unlink\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/unlink.\n"
        Output.pretty(introText)
        Output.simpleHelp("unlink")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - outdated case (Zig line 536)
    private static func printHelpOutdated(): Unit {
        let introText =
            "\n" +
            "Usage: bun outdated [flags] [filter]\n" +
            "\n" +
            "  Display outdated dependencies for each matching workspace.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Display outdated dependencies in the current workspace.\n" +
            "  bun outdated\n" +
            "\n" +
            "  Use --filter to include more than one workspace.\n" +
            "  bun outdated --filter=\"*\"\n" +
            "  bun outdated --filter=\"./app/*\"\n" +
            "  bun outdated --filter=\"!frontend\"\n" +
            "\n" +
            "  Filter dependencies with name patterns.\n" +
            "  bun outdated jquery\n" +
            "  bun outdated \"is-*\"\n" +
            "  bun outdated \"!is-even\"\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/outdated.\n"
        Output.pretty(introText)
        Output.simpleHelp("outdated")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - pack case (Zig line 572)
    private static func printHelpPack(): Unit {
        let introText =
            "\n" +
            "Usage: bun pm pack [flags]\n" +
            "\n" +
            "  Create a tarball for the current project.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  bun pm pack\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/pm#pack.\n"
        Output.pretty(introText)
        Output.simpleHelp("pack")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - publish case (Zig line 597)
    private static func printHelpPublish(): Unit {
        let introText =
            "\n" +
            "Usage: bun publish [flags] [dist]\n" +
            "\n" +
            "  Publish a package to the npm registry.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Display files that would be published, without publishing to the registry.\n" +
            "  bun publish --dry-run\n" +
            "\n" +
            "  Publish the current package with public access.\n" +
            "  bun publish --access public\n" +
            "\n" +
            "  Publish a pre-existing package tarball with tag 'next'.\n" +
            "  bun publish --tag next ./path/to/tarball.tgz\n" +
            "\n" +
            "  Publish without failing when republishing over an existing version.\n" +
            "  bun publish --tolerate-republish\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/publish.\n"
        Output.pretty(introText)
        Output.simpleHelp("publish")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - audit case (Zig line 632)
    private static func printHelpAudit(): Unit {
        let introText =
            "\n" +
            "Usage: bun audit [flags]\n" +
            "\n" +
            "  Check installed packages for vulnerabilities.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Check the current project's packages for vulnerabilities.\n" +
            "  bun audit\n" +
            "\n" +
            "  Output package vulnerabilities in JSON format.\n" +
            "  bun audit --json\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/install/audit.\n"
        Output.pretty(introText)
        Output.simpleHelp("audit")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - info case (Zig line 661)
    private static func printHelpInfo(): Unit {
        let introText =
            "\n" +
            "Usage: bun info [flags] <package>[@<version>]\n" +
            "\n" +
            "  View package metadata from the registry.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Display metadata for the 'react' package\n" +
            "  bun info react\n" +
            "\n" +
            "  Display a specific version of a package\n" +
            "  bun info react@18.0.0\n" +
            "\n" +
            "  Display a specific property in JSON format\n" +
            "  bun info react version --json\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/info.\n"
        Output.pretty(introText)
        Output.simpleHelp("info")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - why case (Zig line 693)
    private static func printHelpWhy(): Unit {
        let introText =
            "\n" +
            "Usage: bun why [flags] <package>\n" +
            "\n" +
            "  Explain why a package is installed.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  bun why react\n" +
            "  bun why \"@types/*\" --depth 2\n" +
            "  bun why \"*-lodash\" --top\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/why.\n"
        Output.pretty(introText)
        Output.simpleHelp("why")
        Output.pretty(outroText)
        Output.flush()
    }

    /// 翻译自: printHelp - scan case (Zig line 720)
    private static func printHelpScan(): Unit {
        let introText =
            "\n" +
            "Usage: bun pm scan [flags]\n" +
            "\n" +
            "  Scan all packages in lockfile for security vulnerabilities.\n" +
            "\n" +
            "Flags:\n"
        let outroText =
            "\n" +
            "\n" +
            "Examples:\n" +
            "  Scan all packages for vulnerabilities\n" +
            "  bun pm scan\n" +
            "\n" +
            "  Output results as JSON\n" +
            "  bun pm scan --json\n" +
            "\n" +
            "Full documentation is available at https://bun.com/docs/cli/pm#scan.\n"
        Output.pretty(introText)
        Output.simpleHelp("pm")
        Output.pretty(outroText)
        Output.flush()
    }

    // ========================================================================
    // parse
    // 严格翻译自: CommandLineArguments.zig - parse (Zig line 752)
    //   pub fn parse(allocator: std.mem.Allocator, comptime subcommand: Subcommand) !CommandLineArguments
    // ========================================================================

    /// 解析命令行参数
    /// 翻译自: parse
    ///   pub fn parse(allocator, comptime subcommand) !CommandLineArguments
    ///   根据子命令类型解析对应的命令行参数, 返回 CommandLineArguments 实例
    public static func parse(subcommand: Subcommand, args: ParsedArgs): CommandLineArguments {
        Output.isVerbose = Output.isVerboseCheck()

        var cli = CommandLineArguments()

        // 翻译自: Zig line 793-795
        cli.positionals = args.positionals()
        cli.yarn = args.flag("--yarn")
        cli.production = args.flag("--production") || args.flag("--prod")

        // 翻译自: Zig line 797
        cli.frozenLockfile = args.flag("--frozen-lockfile") || (cli.positionals.size > 0 && cli.positionals[0] == "ci")

        // 翻译自: Zig line 798-809
        cli.noProgress = args.flag("--no-progress")
        cli.dryRun = args.flag("--dry-run")
        cli.global = args.flag("--global")
        cli.force = args.flag("--force")
        cli.noVerify = args.flag("--no-verify")
        cli.noCache = args.flag("--no-cache")
        cli.silent = args.flag("--silent")
        cli.quiet = args.flag("--quiet")
        cli.verbose = args.flag("--verbose") || Output.isVerbose
        cli.ignoreScripts = args.flag("--ignore-scripts")
        cli.trusted = args.flag("--trust")
        cli.noSummary = args.flag("--no-summary")
        cli.ca = args.options("--ca")
        cli.lockfileOnly = args.flag("--lockfile-only")

        // 翻译自: Zig line 813-818
        let linker = args.option("--linker")
        match (linker) {
            case Some(linkerStr) =>
                let parsed = NodeLinker.fromStr(linkerStr)
                match (parsed) {
                    case Some(nodeLinker) => cli.nodeLinker = Some(nodeLinker)
                    case None =>
                        Output.errGeneric("Expected --linker to be one of 'isolated' or 'hoisted'")
                        Global.crash()
                }
            case None => ()
        }

        // 翻译自: Zig line 820-822
        let cacheDir = args.option("--cache-dir")
        match (cacheDir) {
            case Some(dir) => cli.cacheDir = Some(dir)
            case None => ()
        }

        // 翻译自: Zig line 824-826
        let cafileName = args.option("--cafile")
        match (cafileName) {
            case Some(fileName) => cli.caFileName = fileName
            case None => ()
        }

        // 翻译自: Zig line 828-833
        let networkConcurrency = args.option("--network-concurrency")
        match (networkConcurrency) {
            case Some(ncStr) =>
                let parsedNC = parseUInt32(ncStr)
                match (parsedNC) {
                    case Some(val) => cli.networkConcurrency = Some(val)
                    case None =>
                        Output.errGeneric("Expected --network-concurrency to be a number between 0 and 65535: " + ncStr)
                        Global.crash()
                }
            case None => ()
        }

        // 翻译自: Zig line 835-837
        if (args.flag("--save-text-lockfile")) {
            cli.saveTextLockfile = Some(true)
        }

        // 翻译自: Zig line 839-849
        let minAgeSecs = args.option("--minimum-release-age")
        match (minAgeSecs) {
            case Some(secsStr) =>
                let secs = parseFloat64(secsStr)
                match (secs) {
                    case Some(secsVal) =>
                        if (secsVal < 0.0) {
                            Output.errGeneric("Expected --minimum-release-age to be a positive number: " + secsStr)
                            Global.crash()
                        }
                        cli.minimumReleaseAgeMs = Some(secsVal * 1000.0)
                    case None =>
                        Output.errGeneric("Expected --minimum-release-age to be a positive number: " + secsStr)
                        Global.crash()
                }
            case None => ()
        }

        // 翻译自: Zig line 851-868
        let omitValues = args.options("--omit")
        if (omitValues.size > 0) {
            let parsedOmit = Omit.fromValues(omitValues)
            match (parsedOmit) {
                case Some(omitObj) => cli.omit = Some(omitObj)
                case None =>
                    // 找到无效的 omit 值
                    for (omitValue in omitValues) {
                        if (omitValue != "dev" && omitValue != "optional" && omitValue != "peer") {
                            Output.errGeneric("invalid `omit` value: '" + omitValue + "'")
                            Global.crash()
                        }
                    }
            }
        }

        // 翻译自: Zig line 870-873
        // commands that support --filter
        if (subcommand.supportsWorkspaceFiltering()) {
            cli.filters = args.options("--filter")
        }

        // 翻译自: Zig line 875-877
        if (subcommand.supportsJsonOutput()) {
            cli.jsonOutput = args.flag("--json")
        }

        // 翻译自: Zig line 879-884
        if (subcommand == Subcommand.Outdated) {
            // fake --dry-run, we don't actually resolve+clean the lockfile
            cli.dryRun = true
            cli.recursive = args.flag("--recursive")
        }

        // 翻译自: Zig line 886-899
        if (subcommand == Subcommand.Pack || subcommand == Subcommand.Pm || subcommand == Subcommand.Publish) {
            if (subcommand != Subcommand.Publish) {
                let dest = args.option("--destination")
                match (dest) {
                    case Some(d) => cli.packDestination = d
                    case None => ()
                }
                let file = args.option("--filename")
                match (file) {
                    case Some(f) => cli.packFilename = f
                    case None => ()
                }
            }

            let level = args.option("--gzip-level")
            match (level) {
                case Some(l) => cli.packGzipLevel = Some(l)
                case None => ()
            }
        }

        // 翻译自: Zig line 901-925
        if (subcommand == Subcommand.Publish) {
            let tag = args.option("--tag")
            match (tag) {
                case Some(t) => cli.publishConfig.tag = t
                case None => ()
            }

            let access = args.option("--access")
            match (access) {
                case Some(a) =>
                    let parsedAccess = Access.fromStr(a)
                    match (parsedAccess) {
                        case Some(accessVal) => cli.publishConfig.access = Some(accessVal)
                        case None =>
                            Output.errGeneric("invalid `access` value: '" + a + "'")
                            Global.crash()
                    }
                case None => ()
            }

            let otp = args.option("--otp")
            match (otp) {
                case Some(o) => cli.publishConfig.otp = o
                case None => ()
            }

            let authType = args.option("--auth-type")
            match (authType) {
                case Some(at) =>
                    let parsedAT = AuthType.fromStr(at)
                    match (parsedAT) {
                        case Some(authTypeVal) => cli.publishConfig.authType = Some(authTypeVal)
                        case None =>
                            Output.errGeneric("invalid `auth-type` value: '" + at + "'")
                            Global.crash()
                    }
                case None => ()
            }

            cli.tolerateRepublish = args.flag("--tolerate-republish")
        }

        // 翻译自: Zig line 927-933
        // link and unlink default to not saving, all others default to saving.
        if (subcommand == Subcommand.Link || subcommand == Subcommand.Unlink) {
            cli.noSave = !args.flag("--save")
        } else {
            cli.noSave = args.flag("--no-save")
        }

        // 翻译自: Zig line 935-948
        if (subcommand == Subcommand.Patch) {
            let patchCommit = args.flag("--commit")
            if (patchCommit) {
                let patchesDir = args.option("--patches-dir")
                match (patchesDir) {
                    case Some(dir) => cli.patch = PatchOpts.Commit(dir)
                    case None => cli.patch = PatchOpts.Commit("patches")
                }
            } else {
                cli.patch = PatchOpts.Patch
            }
        }

        // 翻译自: Zig line 949-955
        if (subcommand == Subcommand.PatchCommit) {
            let patchesDir = args.option("--patches-dir")
            match (patchesDir) {
                case Some(dir) => cli.patch = PatchOpts.Commit(dir)
                case None => cli.patch = PatchOpts.Commit("patches")
            }
        }

        // 翻译自: Zig line 957-966
        if (subcommand == Subcommand.Audit) {
            let level = args.option("--audit-level")
            match (level) {
                case Some(levelStr) =>
                    let parsedLevel = AuditLevel.fromString(levelStr)
                    match (parsedLevel) {
                        case Some(auditLvl) => cli.auditLevel = Some(auditLvl)
                        case None =>
                            Output.errGeneric("invalid `--audit-level` value: '" + levelStr + "'. Valid values are: low, moderate, high, critical")
                            Global.crash()
                    }
                case None => ()
            }

            cli.auditIgnoreList = args.options("--ignore")
        }

        // 翻译自: Zig line 968-970
        let configOpt = args.option("--config")
        match (configOpt) {
            case Some(c) => cli.config = Some(c)
            case None => ()
        }

        // 翻译自: Zig line 972-994
        // Parse multiple --cpu flags and combine them using Negatable
        let cpuValues = args.options("--cpu")
        if (cpuValues.size > 0) {
            var cpuNegatable = NpmArchitecture.none().negatable()
            for (cpuStr in cpuValues) {
                // apply() already handles "any" as wildcard and negation with !
                cpuNegatable.apply(cpuStr)

                // Support * as an alias for "any"
                if (cpuStr == "*") {
                    cpuNegatable.hadWildcard = true
                    cpuNegatable.hadUnrecognizedValues = false
                } else if (cpuNegatable.hadUnrecognizedValues &&
                    cpuStr != "any" &&
                    cpuStr != "none") {
                    // Only error for truly unrecognized values (not "any" or "none")
                    Output.errGeneric("Invalid CPU architecture: '" + cpuStr + "'. Valid values are: *, any, arm, arm64, ia32, mips, mipsel, ppc, ppc64, s390, s390x, x32, x64. Use !name to negate.")
                    Global.crash()
                }
            }
            cli.cpu = cpuNegatable.combine()
        }

        // 翻译自: Zig line 997-1018
        // Parse multiple --os flags and combine them using Negatable
        let osValues = args.options("--os")
        if (osValues.size > 0) {
            var osNegatable = NpmOperatingSystem.none().negatable()
            for (osStr in osValues) {
                // apply() already handles "any" as wildcard and negation with !
                osNegatable.apply(osStr)

                // Support * as an alias for "any"
                if (osStr == "*") {
                    osNegatable.hadWildcard = true
                    osNegatable.hadUnrecognizedValues = false
                } else if (osNegatable.hadUnrecognizedValues &&
                    osStr != "any" &&
                    osStr != "none") {
                    // Only error for truly unrecognized values (not "any" or "none")
                    Output.errGeneric("Invalid operating system: '" + osStr + "'. Valid values are: *, any, aix, darwin, freebsd, linux, openbsd, sunos, win32, android. Use !name to negate.")
                    Global.crash()
                }
            }
            cli.os = osNegatable.combine()
        }

        // 翻译自: Zig line 1020-1027
        if (subcommand == Subcommand.Add || subcommand == Subcommand.Install) {
            cli.development = args.flag("--development") || args.flag("--dev")
            cli.optional = args.flag("--optional")
            cli.peer = args.flag("--peer")
            cli.exact = args.flag("--exact")
            cli.analyze = args.flag("--analyze")
            cli.onlyMissing = args.flag("--only-missing")
        }

        // 翻译自: Zig line 1029-1031
        let concurrency = args.option("--concurrent-scripts")
        match (concurrency) {
            case Some(cStr) =>
                cli.concurrentScripts = parseInt64(cStr)
            case None => ()
        }

        // 翻译自: Zig line 1033-1052
        let cwdArg = args.option("--cwd")
        match (cwdArg) {
            case Some(cwd_) =>
                var finalPath: String = cwd_
                if (cwd_.size > 0 && cwd_[0] == 46) {
                    let cwd = BaoFile.getcwd()
                    finalPath = Path.join([cwd, cwd_])
                }
                if (!BaoFile.chdir(finalPath)) {
                    Output.errGeneric("failed to change directory to \"" + finalPath + "\"")
                    Global.crash()
                }
            case None => ()
        }

        // 翻译自: Zig line 1054-1058
        if (subcommand == Subcommand.Update) {
            cli.latest = args.flag("--latest")
            cli.interactive = args.flag("--interactive")
            cli.recursive = args.flag("--recursive")
        }

        // 翻译自: Zig line 1060-1071
        let backendOpt = args.option("--backend")
        match (backendOpt) {
            case Some(backendStr) =>
                let parsedBackend = PackageInstallMethod.fromStr(backendStr)
                match (parsedBackend) {
                    case Some(backend) =>
                        if (backend.isSupported()) {
                            cli.backend = Some(backend)
                        }
                    case None => ()
                }
            case None => ()
        }

        // 翻译自: Zig line 1073-1079
        let registryOpt = args.option("--registry")
        match (registryOpt) {
            case Some(registry) =>
                if (!registry.startsWith("https://") && !registry.startsWith("http://")) {
                    Output.errGeneric("Registry URL must start with 'https://' or 'http://': " + registry)
                    Global.crash()
                }
                cli.registry = registry
            case None => ()
        }

        // 翻译自: Zig line 1081-1084
        if (subcommand == Subcommand.Patch && cli.positionals.size < 2) {
            Output.errGeneric("Missing pkg to patch\n")
            Global.crash()
        }

        // 翻译自: Zig line 1086-1089
        if (subcommand == Subcommand.PatchCommit && cli.positionals.size < 2) {
            Output.errGeneric("Missing pkg folder to patch\n")
            Global.crash()
        }

        // 翻译自: Zig line 1091-1094
        if (cli.production && cli.trusted) {
            Output.errGeneric("The '--production' and '--trust' flags together are not supported because the --trust flag potentially modifies the lockfile after installing packages\n")
            Global.crash()
        }

        // 翻译自: Zig line 1096-1099
        if (cli.frozenLockfile && cli.trusted) {
            Output.errGeneric("The '--frozen-lockfile' and '--trust' flags together are not supported because the --trust flag potentially modifies the lockfile after installing packages\n")
            Global.crash()
        }

        // 翻译自: Zig line 1101-1104
        if (cli.analyze && cli.positionals.size == 0) {
            Output.errGeneric("Missing script(s) to analyze. Pass paths to scripts to analyze their dependencies and add any missing ones to the lockfile.\n")
            Global.crash()
        }

        // 翻译自: Zig line 1106-1126
        // `bun pm version` command options
        if (subcommand == Subcommand.Pm) {
            let gitTagVersionOpt = args.option("--git-tag-version")
            match (gitTagVersionOpt) {
                case Some(gtv) =>
                    if (gtv == "true") {
                        cli.gitTagVersion = true
                    } else if (gtv == "false") {
                        cli.gitTagVersion = false
                    }
                case None =>
                    if (args.flag("--no-git-tag-version")) {
                        cli.gitTagVersion = false
                    } else {
                        cli.gitTagVersion = true
                    }
            }
            cli.allowSameVersion = args.flag("--allow-same-version")
            let preidOpt = args.option("--preid")
            match (preidOpt) {
                case Some(p) => cli.preid = p
                case None => ()
            }
            let messageOpt = args.option("--message")
            match (messageOpt) {
                case Some(m) => cli.message = Some(m)
                case None => ()
            }
        }

        // 翻译自: Zig line 1128-1137
        // `bun pm why` and `bun why` options
        if (subcommand == Subcommand.Pm || subcommand == Subcommand.Why) {
            cli.topOnly = args.flag("--top")
            let depthOpt = args.option("--depth")
            match (depthOpt) {
                case Some(depthStr) =>
                    let parsedDepth = parseInt64(depthStr)
                    match (parsedDepth) {
                        case Some(d) => cli.depth = Some(d)
                        case None =>
                            Output.errGeneric("invalid depth value: '" + depthStr + "', must be a positive integer")
                            Global.exit(1)
                    }
                case None => ()
            }
        }

        return cli
    }

    // ========================================================================
    // 辅助解析函数
    // ========================================================================

    /// 解析 UInt32
    private static func parseUInt32(str: String): ?UInt32 {
        return BaoInt.parseUInt32(str)
    }

    /// 解析 Int64
    private static func parseInt64(str: String): ?Int64 {
        return BaoInt.parseInt64(str)
    }

    /// 解析 Float64
    private static func parseFloat64(str: String): ?Float64 {
        return BaoFloat.parseFloat64(str)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 已解析的参数
/// 对应 Bun: clap.parse 的结果
public class ParsedArgs {
    public var data: HashMap<String, ArgValue>

    public init() {
        data = HashMap<String, ArgValue>()
    }

    /// 获取 flag 值
    public func flag(name: String): Bool {
        match (data.get(name)) {
            case Some(ArgValue.Flag(val)) => return val
            case _ => return false
        }
    }

    /// 获取单选项值
    public func option(name: String): ?String {
        match (data.get(name)) {
            case Some(ArgValue.Single(val)) => return val
            case _ => return None
        }
    }

    /// 获取多选项值
    public func options(name: String): ArrayList<String> {
        match (data.get(name)) {
            case Some(ArgValue.Multi(vals)) => return vals
            case _ => return ArrayList<String>()
        }
    }

    /// 获取位置参数
    public func positionals(): ArrayList<String> {
        match (data.get("<POS>")) {
            case Some(ArgValue.Multi(vals)) => return vals
            case _ => return ArrayList<String>()
        }
    }
}

/// 参数值
public enum ArgValue {
    | Flag(Bool)
    | Single(String)
    | Multi(ArrayList<String>)
}

/// 输出工具
/// 对应 Bun: Output
public class Output {
    public static var isVerbose: Bool = false

    public static func isVerboseCheck(): Bool {
        return isVerbose
    }

    public static func pretty(text: String): Unit {
        BaoConsole.print(text)
    }

    public static func simpleHelp(command: String): Unit {
        BaoConsole.print("  [help for " + command + "]")
    }

    public static func flush(): Unit {
        BaoConsole.flush()
    }

    public static func errGeneric(msg: String): Unit {
        BaoConsole.printErr("error: " + msg)
    }

    public static func prettyErrorln(msg: String): Unit {
        BaoConsole.printErr(msg)
    }

    public static func err(err: String, msg: String): Unit {
        BaoConsole.printErr("error: " + msg)
    }

    public static func errorWriter(): BaoWriter {
        return BaoWriter()
    }
}

/// 全局工具
/// 对应 Bun: Global
public class Global {
    public static func crash(): Unit {
        BaoProcess.exit(1)
    }

    public static func exit(code: Int64): Unit {
        BaoProcess.exit(code)
    }
}

/// 路径工具
/// 对应 Bun: Path
public class Path {
    public static func join(parts: Array<String>): String {
        return BaoPath.join(parts)
    }
}

/// 文件工具
public class BaoFile {
    public static func getcwd(): String {
        return ""
    }

    public static func chdir(path: String): Bool {
        return true
    }

    public static func exists(path: String): Bool {
        return false
    }
}

/// 包管理器命令打印帮助
/// 对应 Bun: PackageManagerCommand.printHelp
public class PackageManagerCommandPrintHelper {
    public static func printHelp(): Unit {
        Output.pretty("\nUsage: bun pm <command>\n\n")
        Output.flush()
    }
}

/// 整数解析工具
public class BaoInt {
    public static func parseUInt32(str: String): ?UInt32 {
        return None
    }

    public static func parseInt64(str: String): ?Int64 {
        return None
    }
}

/// 浮点解析工具
public class BaoFloat {
    public static func parseFloat64(str: String): ?Float64 {
        return None
    }
}

/// 控制台工具
public class BaoConsole {
    public static func print(text: String): Unit {}
    public static func printErr(text: String): Unit {}
    public static func flush(): Unit {}
}

/// 进程工具
public class BaoProcess {
    public static func exit(code: Int64): Unit {}
}

/// 写入器
public class BaoWriter {}

/// 路径工具
public class BaoPath {
    public static func join(parts: Array<String>): String {
        return ""
    }
}

/// HashMap (简化)
public class HashMap<K, V> {
    public init() {}

    public func get(key: K): ?V {
        return None
    }

    public func put(key: K, value: V): Unit {}
}

/// ArrayList removed - use bao_collections.ArrayList
// Local ArrayList was shadowing the imported one from bao_collections
