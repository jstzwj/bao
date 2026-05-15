// bao_install - 包管理器选项
// 严格翻译自: src/install/PackageManager/PackageManagerOptions.zig
//   pub const Options = struct {
//       log_level, global, global_bin_dir, scope, registries,
//       cache_directory, enable, do, positionals, update, ...
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 日志级别
// 严格翻译自: PackageManagerOptions.zig - LogLevel
//   pub const LogLevel = enum { default, verbose, silent, quiet, default_no_progress, verbose_no_progress }
// ============================================================================

/// 日志级别 (完整版)
/// 翻译自: PackageManager.Options.LogLevel
public enum LogLevelFull {
    | Default              // 默认输出
    | Verbose              // 详细日志
    | Silent               // 静默
    | Quiet                // 安静
    | DefaultNoProgress    // 默认, 不显示进度条
    | VerboseNoProgress    // 详细, 不显示进度条

    /// 是否是详细模式
    /// 翻译自: LogLevel.isVerbose
    public func isVerbose(): Bool {
        match (this) {
            case VerboseNoProgress => true
            case Verbose => true
            case _ => false
        }
    }

    /// 是否显示进度条
    /// 翻译自: LogLevel.showProgress
    public func showProgress(): Bool {
        match (this) {
            case Default => true
            case Verbose => true
            case _ => false
        }
    }
}

// ============================================================================
// 启用标志 (位域)
// 严格翻译自: PackageManagerOptions.zig - Enable
//   pub const Enable = packed struct(u16) {
//       manifest_cache: bool = true,
//       manifest_cache_control: bool = true,
//       cache: bool = true,
//       fail_early: bool = false,
//       frozen_lockfile: bool = false,
//       force_save_lockfile: bool = false,
//       force_install: bool = false,
//       exact_versions: bool = false,
//       only_missing: bool = false,
//       global_virtual_store: bool = false,
//   }
// ============================================================================

/// 启用标志
/// 翻译自: PackageManager.Options.Enable
public class EnableFlags {
    public var manifestCache: Bool
    public var manifestCacheControl: Bool
    public var cache: Bool
    public var failEarly: Bool
    public var frozenLockfile: Bool
    public var forceSaveLockfile: Bool
    public var forceInstall: Bool
    public var exactVersions: Bool
    public var onlyMissing: Bool
    public var globalVirtualStore: Bool

    public init() {
        manifestCache = true
        manifestCacheControl = true
        cache = true
        failEarly = false
        frozenLockfile = false
        forceSaveLockfile = false
        forceInstall = false
        exactVersions = false
        onlyMissing = false
        globalVirtualStore = false
    }
}

// ============================================================================
// 执行标志 (位域)
// 严格翻译自: PackageManagerOptions.zig - Do
//   pub const Do = packed struct(u16) {
//       save_lockfile, load_lockfile, install_packages,
//       write_package_json, run_scripts, save_yarn_lock, ...
//   }
// ============================================================================

/// 执行标志
/// 翻译自: PackageManager.Options.Do
public class DoFlags {
    public var saveLockfile: Bool
    public var loadLockfile: Bool
    public var installPackages: Bool
    public var writePackageJson: Bool
    public var runScripts: Bool
    public var saveYarnLock: Bool
    public var printMetaHashString: Bool
    public var verifyIntegrity: Bool
    public var summary: Bool
    public var trustDependenciesFromArgs: Bool
    public var updateToLatest: Bool
    public var analyze: Bool
    public var recursive: Bool
    public var prefetchResolvedTarballs: Bool

    public init() {
        saveLockfile = true
        loadLockfile = true
        installPackages = true
        writePackageJson = true
        runScripts = true
        saveYarnLock = false
        printMetaHashString = false
        verifyIntegrity = true
        summary = true
        trustDependenciesFromArgs = false
        updateToLatest = false
        analyze = false
        recursive = false
        prefetchResolvedTarballs = true
    }
}

// ============================================================================
// 更新选项
// 严格翻译自: PackageManagerOptions.zig - Update
//   pub const Update = struct { development, optional, peer }
// ============================================================================

/// 更新选项
/// 翻译自: PackageManager.Options.Update
public class UpdateFlags {
    public var development: Bool
    public var optional: Bool
    public var peer: Bool

    public init() {
        development = false
        optional = false
        peer = false
    }
}

// ============================================================================
// 访问级别
// 严格翻译自: PackageManagerOptions.zig - Access
// ============================================================================

/// 访问级别
/// 翻译自: Options.Access
public enum PublishAccess {
    | Public
    | Restricted

    public static func fromStr(str: String): ?PublishAccess {
        if (str == "public") { return Public }
        if (str == "restricted") { return Restricted }
        return None
    }
}

// ============================================================================
// Patch 功能
// 严格翻译自: PackageManagerOptions.zig - patch_features
// ============================================================================

/// Patch 功能选项
/// 翻译自: Options.patch_features
public enum PatchFeatures {
    | Nothing
    | Patch
    | Commit(String)   // patches_dir
}

// ============================================================================
// 包管理器选项
// 严格翻译自: src/install/PackageManager/PackageManagerOptions.zig - Options
// ============================================================================

/// 包管理器选项
/// 对应 Bun: PackageManager.Options
/// 翻译自: src/install/PackageManager/PackageManagerOptions.zig
public class PackageManagerOptionsFull {
    // ===== 核心配置 =====

    /// 日志级别
    public var logLevel: LogLevelFull
    /// 是否全局安装
    public var global: Bool
    /// 全局 bin 目录路径
    public var globalBinDir: String
    /// 显式全局目录
    public var explicitGlobalDirectory: String
    /// bin 路径
    public var binPath: String

    // ===== 注册表 =====

    /// 是否覆盖了默认 scope
    public var didOverrideDefaultScope: Bool
    /// 默认 scope
    public var scope: NpmRegistryScope
    /// 注册表映射
    public var registries: HashMap<UInt64, NpmRegistryScope>

    // ===== 缓存 =====

    /// 缓存目录
    public var cacheDirectory: String

    // ===== 启用和执行标志 =====

    /// 启用标志
    public var enable: EnableFlags
    /// 执行标志
    public var do_: DoFlags

    // ===== 位置参数 =====

    /// 位置参数
    public var positionals: ArrayList<String>

    // ===== 更新 =====

    /// 更新标志
    public var update: UpdateFlags

    // ===== 特性 =====

    /// 干运行
    public var dryRun: Bool
    /// 链接 workspace 包
    public var linkWorkspacePackages: Bool
    /// 远程包特性
    public var remotePackageFeatures: InstallFeatures
    /// 本地包特性
    public var localPackageFeatures: InstallFeatures
    /// Patch 功能
    public var patchFeatures: PatchFeatures

    // ===== 过滤 =====

    /// 过滤模式
    public var filterPatterns: ArrayList<String>

    // ===== 并发 =====

    /// 最大重试次数
    public var maxRetryCount: UInt16
    /// 最小同时请求数
    public var minSimultaneousRequests: Int64
    /// 最大并发生命周期脚本数
    public var maxConcurrentLifecycleScripts: Int64

    // ===== 发布 =====

    /// 发布配置
    public var publishConfig: PublishConfigFull

    // ===== CA =====

    /// CA 证书列表
    public var ca: ArrayList<String>
    /// CA 文件名
    public var caFileName: String

    // ===== 锁文件 =====

    /// 保存文本锁文件
    public var saveTextLockfile: ?Bool
    /// 仅锁文件
    public var lockfileOnly: Bool

    // ===== node_modules 链接 =====

    /// node 链接模式
    public var nodeLinker: NodeLinker
    /// public hoist 模式
    public var publicHoistPattern: ?PnpmMatcher
    /// hoist 模式
    public var hoistPattern: ?PnpmMatcher

    // ===== 安全 =====

    /// 安全扫描器路径
    public var securityScanner: ?String
    /// 最小发布年龄 (毫秒)
    public var minimumReleaseAgeMs: ?Float64
    /// 最小发布年龄排除列表
    public var minimumReleaseAgeExcludes: ?ArrayList<String>

    // ===== 平台覆盖 =====

    /// CPU 架构
    public var cpu: String
    /// 操作系统
    public var os_: String

    // ===== 版本 =====

    /// 配置版本
    public var configVersion: ?ConfigVersion

    // ===== pm version =====

    /// Git tag 版本
    public var gitTagVersion: Bool
    /// 允许相同版本
    public var allowSameVersion: Bool
    /// pre-id
    public var preid: String
    /// 提交消息
    public var message: ?String

    // ===== pm why =====

    /// 仅顶层
    public var topOnly: Bool
    /// 深度
    public var depth: ?Int64

    public init() {
        logLevel = LogLevelFull.Default
        global = false
        globalBinDir = ""
        explicitGlobalDirectory = ""
        binPath = "node_modules/.bin"
        didOverrideDefaultScope = false
        scope = NpmRegistryScope()
        registries = HashMap<UInt64, NpmRegistryScope>()
        cacheDirectory = ""
        enable = EnableFlags()
        do_ = DoFlags()
        positionals = ArrayList<String>()
        update = UpdateFlags()
        dryRun = false
        linkWorkspacePackages = true
        remotePackageFeatures = InstallFeatures()
        remotePackageFeatures.optionalDependencies = true
        localPackageFeatures = InstallFeatures()
        localPackageFeatures.optionalDependencies = true
        localPackageFeatures.devDependencies = true
        localPackageFeatures.workspaces = true
        patchFeatures = PatchFeatures.Nothing
        filterPatterns = ArrayList<String>()
        maxRetryCount = UInt16(5)
        minSimultaneousRequests = 4
        maxConcurrentLifecycleScripts = 5
        publishConfig = PublishConfigFull()
        ca = ArrayList<String>()
        caFileName = ""
        saveTextLockfile = None
        lockfileOnly = false
        nodeLinker = NodeLinker.Auto
        publicHoistPattern = None
        hoistPattern = None
        securityScanner = None
        minimumReleaseAgeMs = None
        minimumReleaseAgeExcludes = None
        cpu = "current"
        os_ = "current"
        configVersion = None
        gitTagVersion = true
        allowSameVersion = false
        preid = ""
        message = None
        topOnly = false
        depth = None
    }
}

/// 发布配置 (完整版)
/// 翻译自: Options.PublishConfig
public class PublishConfigFull {
    public var access: ?PublishAccess
    public var tag: String
    public var otp: String
    public var authType: ?AuthType
    public var tolerateRepublish: Bool

    public init() {
        access = None
        tag = ""
        otp = ""
        authType = None
        tolerateRepublish = false
    }
}

/// NPM 注册表 scope
/// 翻译自: Npm.Registry.Scope
public class NpmRegistryScope {
    public var url: String
    public var token: String
    public var auth: String
    public var urlHash: UInt64

    public init() {
        url = "https://registry.npmjs.org/"
        token = ""
        auth = ""
        urlHash = UInt64(0)
    }

    public init(url: String, token: String, auth: String) {
        this.url = url
        this.token = token
        this.auth = auth
        urlHash = UInt64(0)
    }

    /// 为包名查找 scope
    /// 翻译自: scopeForPackageName
    public static func hash(name: String): UInt64 {
        return SemverStringBuilder.stringHashStr(name)
    }
}

/// NPM 注册表映射
public class NpmRegistryMap {
    private var map: HashMap<UInt64, NpmRegistryScope>

    public init() {
        map = HashMap<UInt64, NpmRegistryScope>()
    }

    public func put(key: UInt64, scope: NpmRegistryScope): Unit {
        map.put(key, scope)
    }

    public func get(key: UInt64): ?NpmRegistryScope {
        return map.get(key)
    }

    public func scopeForPackageName(name: String): NpmRegistryScope {
        if (name.length == 0 || name[0].value != 64) { // '@'
            return NpmRegistryScope()
        }
        let scopeName = name.substring(1, name.indexOf("/").getOr(name.length))
        let hash = SemverStringBuilder.stringHashStr(scopeName)
        match (map.get(hash)) {
            case Some(scope) => return scope
            case None => return NpmRegistryScope()
        }
    }
}

/// NPM 默认注册表 URL
public let NPM_DEFAULT_REGISTRY: String = "https://registry.npmjs.org/"
