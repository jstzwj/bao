// bao_install - 自动安装器
// 严格翻译自: src/install/auto_installer.rs
//   auto_installer.rs 将 resolver 端的 AutoInstaller trait 连接到
//   具体的 PackageManager / Lockfile 实现
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_semver.*

// ============================================================================
// Resolution 标签桥接
// 严格翻译自: auto_installer.rs — tag_to_hooks / resolution_to_hooks
//   将 install 端的 resolution::Tag 映射到 hooks 端的 ResolutionTag
// ============================================================================

/// Resolution 标签
/// 翻译自: resolution::Tag (open u8 newtype) / hooks::ResolutionTag (closed repr(u8) enum)
public enum ResolutionTag8 {
    | Uninitialized
    | Root
    | Npm
    | Folder
    | LocalTarball
    | Github
    | Git
    | Symlink
    | Workspace
    | RemoteTarball
    | SingleFileModule
}

/// 将 Resolution Tag 转换为 hooks 端标签
/// 翻译自: fn tag_to_hooks(t: resolution::Tag) -> hooks::ResolutionTag
public func tagToHooks(tag: ResolutionTag8): ResolutionTag8 {
    return tag
}

/// Resolution 结构体 (hooks 端)
/// 翻译自: hooks::Resolution
public class ResolutionValue {
    public var tag: ResolutionTag8
    public var value: UInt64

    public init(tag: ResolutionTag8, value: UInt64) {
        this.tag = tag
        this.value = value
    }

    public init() {
        tag = ResolutionTag8.Uninitialized
        value = 0
    }
}

// ============================================================================
// AutoInstaller 接口
// 严格翻译自: hooks::AutoInstaller trait
//   PackageManager 对此 trait 的 impl, 提供 resolver 调用的锁文件读写操作
// ============================================================================

/// AutoInstaller 协议
/// 翻译自: hooks::AutoInstaller trait
///   定义了 resolver 需要从 PackageManager 获得的操作
public protocol AutoInstaller {
    /// 获取锁文件中包的数量
    /// 翻译自: fn lockfile_packages_len(&self) -> usize
    func lockfilePackagesLen(): Int64

    /// 获取指定包的依赖切片
    /// 翻译自: fn lockfile_package_dependencies(&self, id: PackageID) -> hooks::DependencySlice
    func lockfilePackageDependencies(id: UInt32): ExternalSlice<Dependency>

    /// 获取指定包的解析结果切片
    /// 翻译自: fn lockfile_package_resolutions(&self, id: PackageID) -> hooks::ResolutionSlice
    func lockfilePackageResolutions(id: UInt32): ExternalSlice<UInt32>

    /// 获取指定包的 Resolution
    /// 翻译自: fn lockfile_package_resolution(&self, id: PackageID) -> hooks::Resolution
    func lockfilePackageResolution(id: UInt32): ResolutionValue

    /// 获取依赖缓冲区
    /// 翻译自: fn lockfile_dependencies_buf(&self) -> &[hooks::Dependency]
    func lockfileDependenciesBuf(): ArrayList<Dependency>

    /// 获取解析结果缓冲区
    /// 翻译自: fn lockfile_resolutions_buf(&self) -> &[PackageID]
    func lockfileResolutionsBuf(): ArrayList<UInt32>

    /// 获取字符串字节缓冲区
    /// 翻译自: fn lockfile_string_bytes(&self) -> &[u8]
    func lockfileStringBytes(): Array<Byte>

    /// 解析包名+版本
    /// 翻译自: fn lockfile_resolve(&self, name: &[u8], version: &DependencyVersion) -> Option<PackageID>
    func lockfileResolve(name: Array<Byte>, version: DependencyVersion): ?UInt32

    /// 获取旧版包到依赖ID的映射
    /// 翻译自: fn lockfile_legacy_package_to_dependency_id(&self, package_id: PackageID) -> Result<DependencyID, Error>
    func lockfileLegacyPackageToDependencyId(packageId: UInt32): Result<UInt32>

    /// 从锁文件读取字符串
    /// 翻译自: fn lockfile_str<'a>(&'a self, s: &'a SemverString) -> &'a [u8]
    func lockfileStr(s: SemverString): Array<Byte>

    /// 从 package.json 追加包到锁文件
    /// 翻译自: fn lockfile_append_from_package_json(&mut self, ...) -> Result<PackageID, Error>
    func lockfileAppendFromPackageJson(
        packageJson: PackageJsonView,
        features: Features
    ): Result<UInt32>

    /// 追加根存根
    /// 翻译自: fn lockfile_append_root_stub(&mut self) -> Result<PackageID, Error>
    func lockfileAppendRootStub(): Result<UInt32>

    /// 设置唤醒回调
    /// 翻译自: fn set_on_wake(&mut self, handler: WakeHandler)
    func setOnWake(handler: WakeHandler): Unit

    /// 获取解析路径
    /// 翻译自: fn path_for_resolution<'b>(...) -> Result<&'b [u8], Error>
    func pathForResolution(
        packageId: UInt32,
        resolution: ResolutionValue,
        buf: Array<Byte>
    ): Result<Array<Byte>>

    /// 获取预安装状态
    /// 翻译自: fn get_preinstall_state(&self, package_id: PackageID) -> PreinstallState
    func getPreinstallState(packageId: UInt32): PreinstallState

    /// 将包加入下载队列
    /// 翻译自: fn enqueue_package_for_download(...) -> Result<(), Error>
    func enqueuePackageForDownload(
        name: Array<Byte>,
        dependencyId: UInt32,
        packageId: UInt32,
        resolution: ResolutionValue,
        ctx: TaskCallbackContext,
        patchNameAndVersionHash: ?UInt64
    ): Result<Unit>

    /// 从磁盘缓存解析
    /// 翻译自: fn resolve_from_disk_cache(...) -> Option<PackageID>
    func resolveFromDiskCache(
        name: Array<Byte>,
        version: DependencyVersion
    ): ?UInt32

    /// 将依赖加入根队列
    /// 翻译自: fn enqueue_dependency_to_root(...) -> EnqueueResult
    func enqueueDependencyToRoot(
        name: Array<Byte>,
        version: DependencyVersion,
        versionBuf: Array<Byte>,
        behavior: Behavior
    ): EnqueueResult

    /// 解析依赖版本
    /// 翻译自: fn parse_dependency(...) -> Option<DependencyVersion>
    func parseDependency(
        name: SemverString,
        nameHash: ?UInt64,
        version: Array<Byte>,
        sliced: SlicedString,
        log: ?Log
    ): ?DependencyVersion

    /// 带标签解析依赖
    /// 翻译自: fn parse_dependency_with_tag(...) -> Option<DependencyVersion>
    func parseDependencyWithTag(
        name: SemverString,
        nameHash: UInt64,
        version: Array<Byte>,
        tag: DependencyVersionTag,
        sliced: SlicedString,
        log: ?Log
    ): ?DependencyVersion

    /// 推断依赖标签
    /// 翻译自: fn infer_dependency_tag(&self, dep: &[u8]) -> DependencyVersionTag
    func inferDependencyTag(dep: Array<Byte>): DependencyVersionTag
}

// ============================================================================
// 支持类型
// 严格翻译自: auto_installer.rs 中的引用类型
// ============================================================================

/// 唤醒处理器
/// 翻译自: hooks::WakeHandler
public class WakeHandler {
    public var callback: () -> Unit

    public init(callback: () -> Unit) {
        this.callback = callback
    }
}

/// 任务回调上下文
/// 翻译自: hooks::TaskCallbackContext
public class TaskCallbackContext {
    public var rootRequestId: UInt32

    public init(rootRequestId: UInt32) {
        this.rootRequestId = rootRequestId
    }
}

/// 入队结果
/// 翻译自: hooks::EnqueueResult
public enum EnqueueResult {
    | Resolution(UInt32, ResolutionValue)
    | Pending(UInt32)
    | NotFound
    | Failure(Error)
}

/// 预安装状态
/// 翻译自: PreinstallState
public enum PreinstallState {
    | Done
    | Pending
    | NotStarted
}

/// 包 JSON 视图
/// 翻译自: hooks::PackageJsonView trait
public protocol PackageJsonView {
    func name(): Array<Byte>
    func version(): Array<Byte>
    func dependencySourceBuf(): Array<Byte>
    func dependencyIter(): ArrayList<DependencyEntry>
    func arch(): ArchitectureSet
    func os(): OperatingSystemSet
}

/// 依赖条目
/// 翻译自: hooks::DependencyEntry
public class DependencyEntry {
    public var behavior: Behavior
    public var name: Array<Byte>
    public var version: Array<Byte>

    public init(behavior: Behavior, name: Array<Byte>, version: Array<Byte>) {
        this.behavior = behavior
        this.name = name
        this.version = version
    }
}

/// 架构集合
/// 翻译自: Npm::Architecture bitset
public class ArchitectureSet {
    public var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    public init() {
        value = UInt64.MAX
    }

    public static let ALL_VALUE: UInt64 = UInt64.MAX

    public func has(arch: UInt64): Bool {
        return (value & arch) != 0
    }
}

/// 操作系统集合
/// 翻译自: Npm::OperatingSystem bitset
public class OperatingSystemSet {
    public var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    public init() {
        value = UInt64.MAX
    }

    public static let ALL_VALUE: UInt64 = UInt64.MAX

    public func has(os: UInt64): Bool {
        return (value & os) != 0
    }
}

/// 行为标志
/// 翻译自: hooks::Behavior
public class Behavior {
    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public init() {
        value = 0
    }

    /// 检查给定 feature 是否启用
    /// 翻译自: Behavior.is_enabled(features)
    public func isEnabled(features: Features): Bool {
        return (value & features.mask) != 0
    }
}

/// Features 标志
/// 翻译自: Features
public class Features {
    public var mask: UInt32

    public init(mask: UInt32) {
        this.mask = mask
    }

    public init() {
        mask = UInt32.MAX
    }
}

/// 切片字符串
/// 翻译自: semver::SlicedString
public class SlicedString {
    public var offset: UInt32
    public var length: UInt32

    public init(offset: UInt32, length: UInt32) {
        this.offset = offset
        this.length = length
    }

    public init() {
        offset = 0
        length = 0
    }
}

/// 日志
/// 翻译自: bun_ast::Log
public class Log {
    public var errors: Int64
    public var warnings: Int64

    public init() {
        errors = 0
        warnings = 0
    }
}

// ============================================================================
// 辅助函数
// 严格翻译自: auto_installer.rs 中的 helper functions
// ============================================================================

/// 将 Resolution 从 hooks 端转换为 install 端
/// 翻译自: fn resolution_from_hooks(r: &hooks::Resolution) -> resolution::Resolution
public func resolutionFromHooks(r: ResolutionValue): ResolutionValue {
    return r
}

/// 初始化包管理器 (从 resolver 调用)
/// 翻译自: __bun_resolver_init_package_manager
public func initPackageManagerFromResolver(
    log: Log,
    install: ?BunInstallConfig,
    env: DotEnvLoader
): PackageManager {
    // 翻译自:
    //   bun_http.http_thread.init({})
    //   let pm = PackageManager.initWithRuntime(log, bun_install, allocator, {}, env)
    //   return NonNull::new(pm as *mut dyn AutoInstaller)
    return PackageManager.initWithRuntime(log, install, env)
}

/// Bun 安装配置
/// 翻译自: bun_schema::api::BunInstall
public class BunInstallConfig {
    public var registry: String
    public var cacheDirectory: String

    public init(registry: String, cacheDirectory: String) {
        this.registry = registry
        this.cacheDirectory = cacheDirectory
    }
}

/// DotEnv 加载器
/// 翻译自: bun_dotenv::Loader
public class DotEnvLoader {
    public var entries: HashMap<String, String>

    public init() {
        entries = HashMap<String, String>()
    }

    public func get(key: String): ?String {
        return entries.get(key)
    }
}
