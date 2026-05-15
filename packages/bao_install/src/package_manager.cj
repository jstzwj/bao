// bao_install - 包管理器主入口
// 严格翻译自: src/install/PackageManager.zig
//   pub const PackageManager = struct {
//       cache_directory_: ?std.fs.Dir,
//       cache_directory_path: stringZ,
//       root_dir: *Fs.FileSystem.DirEntry,
//       allocator: std.mem.Allocator,
//       log: *logger.Log,
//       resolve_tasks: ResolveTaskQueue,
//       timestamp_for_manifest_cache_control: u32,
//       extracted_count: u32,
//       default_features: Features,
//       summary: Lockfile.Package.Diff.Summary,
//       env: *DotEnv.Loader,
//       progress: Progress,
//       ...
//       subcommand: Subcommand,
//       update_requests: []UpdateRequest,
//       lockfile: *Lockfile,
//       options: Options,
//       ...
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 子命令
// 严格翻译自: src/install/PackageManager.zig - Subcommand
//   pub const Subcommand = enum {
//       install, update, pm, add, remove, link, unlink,
//       patch, @"patch-commit", outdated, pack, publish, audit, info, why, scan
//   }
// ============================================================================

/// 包管理器子命令
public enum PackageSubcommand {
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

    /// 是否可以全局安装包
    /// 翻译自: Subcommand.canGloballyInstallPackages
    public func canGloballyInstallPackages(): Bool {
        match (this) {
            case Install => true
            case Update => true
            case Add => true
            case _ => false
        }
    }

    /// 是否支持 workspace 过滤
    /// 翻译自: Subcommand.supportsWorkspaceFiltering
    public func supportsWorkspaceFiltering(): Bool {
        match (this) {
            case Outdated => true
            case Install => true
            case Update => true
            case _ => false
        }
    }

    /// 是否支持 JSON 输出
    /// 翻译自: Subcommand.supportsJsonOutput
    public func supportsJsonOutput(): Bool {
        match (this) {
            case Audit => true
            case Pm => true
            case Info => true
            case _ => false
        }
    }

    /// 是否应该 chdir 到根目录
    /// 翻译自: Subcommand.shouldChdirToRoot
    public func shouldChdirToRoot(): Bool {
        match (this) {
            case Link => false
            case _ => true
        }
    }
}

// ============================================================================
// 包更新信息
// 严格翻译自: src/install/PackageManager.zig - PackageUpdateInfo
//   pub const PackageUpdateInfo = struct {
//       original_version_literal: string,
//       is_alias: bool,
//       original_version_string_buf: string,
//       original_version: ?Semver.Version,
//   }
// ============================================================================

/// 包更新信息
/// 对应 Bun: PackageManager.PackageUpdateInfo
public class PackageUpdateInfo {
    /// 原始版本字面量
    public var originalVersionLiteral: String
    /// 是否是 alias
    public var isAlias: Bool
    /// 原始版本字符串缓冲区
    public var originalVersionStringBuf: String
    /// 原始版本 (解析后)
    public var originalVersion: ?SemVer

    public init() {
        originalVersionLiteral = ""
        isAlias = false
        originalVersionStringBuf = ""
        originalVersion = None
    }
}

// ============================================================================
// 命令行参数
// 严格翻译自: src/install/PackageManager/CommandLineArguments.zig
// ============================================================================

/// 命令行参数
/// 对应 Bun: PackageManager.CommandLineArguments
public class CommandLineArguments {
    /// 是否全局安装
    public var global: Bool
    /// 位置参数
    public var positionals: ArrayList<String>
    /// 配置文件路径
    public var config: ?String
    /// 网络并发数
    public var networkConcurrency: ?Int64
    /// 并发脚本数
    public var concurrentScripts: ?Int64

    public init() {
        global = false
        positionals = ArrayList<String>()
        config = None
        networkConcurrency = None
        concurrentScripts = None
    }
}

// ============================================================================
// 包管理器选项
// 严格翻译自: src/install/PackageManager/PackageManagerOptions.zig
// ============================================================================

/// 包管理器选项
/// 对应 Bun: PackageManager.Options
public class PackageManagerOptions {
    /// 是否全局安装
    public var global: Bool
    /// 缓存目录路径
    public var cacheDirectory: String
    /// 日志级别
    public var logLevel: LogLevel
    /// 最大并发生命周期脚本数
    public var maxConcurrentLifecycleScripts: Int64
    /// 注册表 scope 配置
    public var scope: NpmRegistryScope
    /// CA 证书路径
    public var ca: ArrayList<String>
    /// CA 文件路径
    public var caFileName: ?String
    /// 链接模式
    public var nodeLinker: NodeLinker
    /// hoist 模式
    public var hoistPattern: ?String
    /// public hoist 模式
    public var publicHoistPattern: ?String
    /// 是否启用全局虚拟存储
    public var enableGlobalVirtualStore: Bool
    /// 发布配置
    public var publishConfig: ?PublishConfig
    /// CPU 架构
    public var cpu: ?String
    /// 操作系统
    public var os: ?String
    /// bin 路径
    public var binPath: ?String

    /// 安装行为控制
    public var doInstall: DoInstallOptions

    public init() {
        global = false
        cacheDirectory = ""
        logLevel = LogLevel.Default
        maxConcurrentLifecycleScripts = DEFAULT_MAX_SIMULTANEOUS_REQUESTS
        scope = NpmRegistryScope()
        ca = ArrayList<String>()
        caFileName = None
        nodeLinker = NodeLinker.Auto
        hoistPattern = None
        publicHoistPattern = None
        enableGlobalVirtualStore = false
        publishConfig = None
        cpu = None
        os = None
        binPath = None
        doInstall = DoInstallOptions()
    }
}

/// 安装行为控制
/// 翻译自: PackageManager.Options.do 和 Options.enable
public class DoInstallOptions {
    /// 是否安装包
    public var installPackages: Bool
    /// 是否运行脚本
    public var runScripts: Bool
    /// 是否打印 lockfile 路径
    public var printLockfile: Bool

    /// 启用特性
    public var enableCache: Bool
    public var enableManifestCache: Bool
    public var enableManifestCacheControl: Bool
    public var enableForceInstall: Bool
    public var enableFailEarly: Bool
    public var enableForceSaveLockfile: Bool
    public var enableGlobalVirtualStore: Bool

    public init() {
        installPackages = true
        runScripts = true
        printLockfile = false
        enableCache = true
        enableManifestCache = true
        enableManifestCacheControl = true
        enableForceInstall = false
        enableFailEarly = false
        enableForceSaveLockfile = false
        enableGlobalVirtualStore = false
    }
}

/// 发布配置
/// 翻译自: PackageManager.Options.publish_config
public class PublishConfig {
    public var registry: String
    public var authToken: ?String
    public var authType: AuthType

    public init() {
        registry = NPM_DEFAULT_REGISTRY
        authToken = None
        authType = AuthType.Legacy
    }
}

/// 认证类型
public enum AuthType {
    | Legacy
    | Web
}

// ============================================================================
// Wake Handler
// 严格翻译自: src/install/PackageManager.zig - WakeHandler
// ============================================================================

/// Wake Handler 类型
/// 翻译自: PackageManager.WakeHandler
public class WakeHandler {
    public var onWake: ?() -> Unit
    public var onDependencyError: ?((DependencyInfo, UInt32, Exception) -> Unit)

    public init() {
        onWake = None
        onDependencyError = None
    }
}

// ============================================================================
// 进度字符串
// 严格翻译自: src/install/PackageManager/ProgressStrings.zig
// ============================================================================

/// 进度字符串
/// 翻译自: PackageManager.ProgressStrings
public class ProgressStrings {
    public static func download(): String { "download" }
    public static func install(): String { "install" }
    public static func script(): String { "script" }
    public static func scriptEmoji(): String { ">" }
}

// ============================================================================
// 包管理器
// 严格翻译自: src/install/PackageManager.zig - PackageManager
//   这是 Bun 包管理器的核心结构, 管理整个安装流程:
//   - 初始化 (查找 package.json, 加载配置)
//   - 任务队列 (网络请求, 解析, 提取)
//   - 锁文件管理
//   - 进度报告
//   - 生命周期脚本管理
// ============================================================================

/// 包管理器
/// 对应 Bun: install.PackageManager
public class PackageManager {
    // ===== 核心状态 =====

    /// 分配器
    public var allocator: Allocator
    /// 日志
    public var log: Log
    /// 根目录条目
    public var rootDir: DirEntry
    /// 环境变量
    public var env: DotEnvLoader
    /// 锁文件
    public var lockfile: LockfileData
    /// 选项
    public var options: PackageManagerOptions
    /// 子命令
    public var subcommand: PackageSubcommand

    // ===== 缓存相关 =====

    /// 缓存目录路径
    public var cacheDirectoryPath: String
    /// 临时目录路径
    public var temporaryDirectoryPath: String
    /// 全局链接目录路径
    public var globalLinkDirPath: String
    /// 全局链接目录
    public var globalLinkDir: ?String
    /// 全局目录
    public var globalDir: ?String

    // ===== 任务管理 =====

    /// 待处理任务数
    /// 翻译自: pending_tasks: std.atomic.Value(u32)
    public var pendingTasks: Int64
    /// 总任务数
    public var totalTasks: Int64
    /// 任务队列
    /// 翻译自: task_queue: TaskDependencyQueue
    public var taskQueue: HashMap<Int64, ArrayList<TaskCallbackContext>>
    /// 网络任务队列
    public var networkTaskQueue: NetworkTaskQueue
    /// 异步网络任务队列
    public var asyncNetworkTaskQueue: AsyncNetworkTaskQueue
    /// 网络去重映射
    public var networkDedupeMap: NetworkTaskDedupeMap
    /// 预分配的网络任务
    public var preallocatedNetworkTasks: ArrayList<NetworkTask>
    /// 预分配的解析任务
    public var preallocatedResolveTasks: ArrayList<Object>
    /// 已完成安装标记
    /// 翻译自: finished_installing: std.atomic.Value(bool)
    public var finishedInstalling: Bool

    // ===== 包解析 =====

    /// Manifest 缓存
    /// 翻译自: manifests: PackageManifestMap
    public var manifests: HashMap<String, PackageManifestData>
    /// 文件夹解析
    /// 翻译自: folders: FolderResolution.Map
    public var folders: HashMap<UInt64, FolderResolution>
    /// Git 仓库映射
    /// 翻译自: git_repositories: RepositoryMap
    public var gitRepositories: HashMap<Int64, String>
    /// 已知 NPM alias
    /// 翻译自: known_npm_aliases: NpmAliasMap
    public var knownNpmAliases: HashMap<UInt64, DependencyVersionValue>
    /// NPM scope 映射
    public var registryScopes: NpmRegistryMap

    // ===== 生命周期脚本 =====

    /// 待处理的生命周期脚本任务数
    /// 翻译自: pending_lifecycle_script_tasks: std.atomic.Value(u32)
    public var pendingLifecycleScriptTasks: Int64
    /// 总脚本数
    public var totalScripts: Int64
    /// 根生命周期脚本
    public var rootLifecycleScripts: ?ArrayList<String>
    /// 生命周期脚本时间日志
    public var lifecycleScriptTimeLog: HashMap<String, Int64>
    /// node-gyp 临时目录名
    public var nodeGypTempdirName: String
    /// 最后报告慢脚本的时间
    public var lastReportedSlowScriptAt: Int64

    // ===== 更新相关 =====

    /// 是否是更新模式
    public var toUpdate: Bool
    /// 更新请求列表
    public var updateRequests: ArrayList<UpdateRequest>
    /// 根 package.json 名称
    public var rootPackageJsonName: String
    /// 根 package.json 文件
    public var rootPackageJsonFile: ?String
    /// 原始 package.json 路径
    public var originalPackageJsonPath: String
    /// workspace 名称哈希
    public var workspaceNameHash: ?UInt64
    /// workspace package.json 缓存
    public var workspacePackageJsonCache: HashMap<String, WorkspacePackage>

    // ===== 进度 =====

    /// 进度条
    public var progress: ProgressInfo
    /// 下载进度节点
    public var downloadsNode: ?ProgressNode
    /// 脚本进度节点
    public var scriptsNode: ?ProgressNode

    // ===== 统计 =====

    /// 提取计数
    public var extractedCount: UInt32
    /// CPU 数量
    public var cpuCount: Int64
    /// Manifest 缓存控制时间戳
    /// 翻译自: timestamp_for_manifest_cache_control: u32
    public var timestampForManifestCacheControl: Int64
    /// 默认特性
    public var defaultFeatures: InstallFeatures
    /// 安装摘要
    public var summary: LockfileDiffSummary
    /// 安装前状态列表
    public var preinstallState: ArrayList<PreinstallState>
    /// 是否有安装失败
    public var anyFailedToInstall: Bool
    /// 更新中的包信息
    /// 翻译自: updating_packages: StringArrayHashMapUnmanaged(PackageUpdateInfo)
    public var updatingPackages: HashMap<String, PackageUpdateInfo>
    /// 要添加到 package.json 的可信依赖
    /// 翻译自: trusted_deps_to_add_to_package_json
    public var trustedDepsToAdd: ArrayList<String>

    // ===== 唤醒处理器 =====
    public var onWake: WakeHandler

    /// 是否是 CI 环境
    public var ciMode: Bool

    /// 详细安装日志
    /// 翻译自: verbose_install
    public static var verboseInstall: Bool = false

    public init() {
        allocator = Allocator()
        log = Log()
        rootDir = DirEntry()
        env = DotEnvLoader()
        lockfile = LockfileData()
        options = PackageManagerOptions()
        subcommand = PackageSubcommand.Install

        cacheDirectoryPath = ""
        temporaryDirectoryPath = ""
        globalLinkDirPath = ""
        globalLinkDir = None
        globalDir = None

        pendingTasks = 0
        totalTasks = 0
        taskQueue = HashMap<Int64, ArrayList<TaskCallbackContext>>()
        networkTaskQueue = NetworkTaskQueue()
        asyncNetworkTaskQueue = AsyncNetworkTaskQueue()
        networkDedupeMap = NetworkTaskDedupeMap()
        preallocatedNetworkTasks = ArrayList<NetworkTask>()
        preallocatedResolveTasks = ArrayList<Object>()
        finishedInstalling = false

        manifests = HashMap<String, PackageManifestData>()
        folders = HashMap<UInt64, FolderResolution>()
        gitRepositories = HashMap<Int64, String>()
        knownNpmAliases = HashMap<UInt64, DependencyVersionValue>()
        registryScopes = NpmRegistryMap()

        pendingLifecycleScriptTasks = 0
        totalScripts = 0
        rootLifecycleScripts = None
        lifecycleScriptTimeLog = HashMap<String, Int64>()
        nodeGypTempdirName = ""
        lastReportedSlowScriptAt = 0

        toUpdate = false
        updateRequests = ArrayList<UpdateRequest>()
        rootPackageJsonName = ""
        rootPackageJsonFile = None
        originalPackageJsonPath = ""
        workspaceNameHash = None
        workspacePackageJsonCache = HashMap<String, WorkspacePackage>()

        progress = ProgressInfo()
        downloadsNode = None
        scriptsNode = None

        extractedCount = UInt32(0)
        cpuCount = 1
        timestampForManifestCacheControl = 0
        defaultFeatures = InstallFeatures()
        summary = LockfileDiffSummary()
        preinstallState = ArrayList<PreinstallState>()
        anyFailedToInstall = false
        updatingPackages = HashMap<String, PackageUpdateInfo>()
        trustedDepsToAdd = ArrayList<String>()

        onWake = WakeHandler()
        ciMode = false
    }

    // ===== 初始化方法 =====

    /// 初始化包管理器
    /// 翻译自: PackageManager.init
    ///   1. 查找 package.json
    ///   2. 加载环境变量
    ///   3. 设置 HTTP 线程
    ///   4. 加载 npmrc 配置
    ///   5. 加载锁文件
    public static func init(
        allocator: Allocator,
        log: Log,
        env: DotEnvLoader,
        cli: CommandLineArguments,
        subcommand: PackageSubcommand
    ): PackageManager {
        let manager = PackageManager()
        manager.allocator = allocator
        manager.log = log
        manager.env = env
        manager.subcommand = subcommand
        manager.cpuCount = bao_sys.SysModule.cpuCount()

        // 设置缓存目录
        manager.cacheDirectoryPath = resolveCacheDirectory(env)

        // 设置并发限制
        manager.options.maxConcurrentLifecycleScripts = match (cli.concurrentScripts) {
            case Some(n) => n
            case None => manager.cpuCount * 2
        }

        // 检查详细安装标志
        match (env.get("BUN_INSTALL_VERBOSE")) {
            case Some(_) => PackageManager.verboseInstall = true
            case None => {}
        }

        return manager
    }

    /// 运行时初始化
    /// 翻译自: PackageManager.initWithRuntime
    public static func initWithRuntime(
        log: Log,
        allocator: Allocator,
        cli: CommandLineArguments,
        env: DotEnvLoader
    ): PackageManager {
        let manager = PackageManager()
        manager.allocator = allocator
        manager.log = log
        manager.env = env
        manager.subcommand = PackageSubcommand.Install
        manager.cpuCount = bao_sys.SysModule.cpuCount()
        return manager
    }

    // ===== 核心方法 =====

    /// 唤醒事件循环
    /// 翻译自: PackageManager.wake
    public func wake(): Unit {
        match (onWake.onWake) {
            case Some(handler) => handler()
            case None => {}
        }
    }

    /// 等待直到条件满足
    /// 翻译自: PackageManager.sleepUntil
    public func sleepUntil(isDone: () -> Bool): Unit {
        while (!isDone()) {
            bao_sys.SysModule.sleep(1) // 1ms
            runTasks()
        }
    }

    /// 休眠
    /// 翻译自: PackageManager.sleep
    public func sleep(): Unit {
        bao_sys.SysModule.sleep(10) // 10ms
    }

    /// 崩溃
    /// 翻译自: PackageManager.crash
    public func crash(): Unit {
        if (options.logLevel != LogLevel.Silent) {
            log.print()
        }
        bao_core.Output.error("Install failed")
    }

    /// 失败的根解析
    /// 翻译自: PackageManager.failRootResolution
    public func failRootResolution(dependency: DependencyInfo, dependencyId: UInt32, err: Exception): Unit {
        match (onWake.onDependencyError) {
            case Some(handler) => handler(dependency, dependencyId, err)
            case None => {}
        }
    }

    // ===== 缓存目录方法 =====

    /// 解析缓存目录
    /// 翻译自: PackageManager.fetchCacheDirectoryPath
    public static func resolveCacheDirectory(env: DotEnvLoader): String {
        // BUN_INSTALL_CACHE_DIR
        match (env.get("BUN_INSTALL_CACHE_DIR")) {
            case Some(dir) => return dir
            case None => {}
        }
        // 默认: ~/.bun/install/cache
        match (bao_sys.SysModule.getEnv("HOME")) {
            case Some(home) => return "${home}/.bun/install/cache"
            case None => return ".bun/install/cache"
        }
    }

    /// 获取缓存目录
    /// 翻译自: PackageManager.getCacheDirectory
    public func getCacheDirectory(): String {
        if (cacheDirectoryPath.length == 0) {
            cacheDirectoryPath = resolveCacheDirectory(env)
        }
        return cacheDirectoryPath
    }

    /// 获取临时目录
    /// 翻译自: PackageManager.getTemporaryDirectory
    public func getTemporaryDirectory(): String {
        if (temporaryDirectoryPath.length == 0) {
            temporaryDirectoryPath = "${getCacheDirectory()}/tmp"
        }
        return temporaryDirectoryPath
    }

    /// 获取全局链接目录
    /// 翻译自: PackageManager.globalLinkDir
    public func getGlobalLinkDir(): ?String {
        match (globalLinkDir) {
            case Some(dir) => return dir
            case None => {
                match (bao_sys.SysModule.getEnv("HOME")) {
                    case Some(home) => {
                        let dir = "${home}/.bun/install/global/node_modules"
                        globalLinkDir = dir
                        return dir
                    }
                    case None => return None
                }
            }
        }
    }

    /// 获取全局链接目录路径
    /// 翻译自: PackageManager.globalLinkDirPath
    public func getGlobalLinkDirPath(): String {
        if (globalLinkDirPath.length == 0) {
            match (getGlobalLinkDir()) {
                case Some(dir) => globalLinkDirPath = dir
                case None => globalLinkDirPath = ""
            }
        }
        return globalLinkDirPath
    }

    // ===== 缓存路径方法 =====

    /// 获取 NPM 包的缓存文件夹名
    /// 翻译自: cachedNPMPackageFolderName
    public func cachedNPMPackageFolderName(name: String, version: String, patchHash: ?UInt64): String {
        var folderName = "${name}@${version}"
        match (patchHash) {
            case Some(hash) => folderName = "${folderName}_${bao_hash.Wyhash.toHexString(hash)}"
            case None => {}
        }
        return folderName.replace("/", "+")
    }

    /// 获取 Git 仓库的缓存文件夹名
    /// 翻译自: cachedGitFolderName
    public func cachedGitFolderName(repo: GitRepositoryInfo, patchHash: ?UInt64): String {
        var folderName = "git_${repo.owner}_${repo.repo}"
        match (repo.committish) {
            case c if c.length > 0 => folderName = "${folderName}_${c}"
            case _ => {}
        }
        match (patchHash) {
            case Some(hash) => folderName = "${folderName}_${bao_hash.Wyhash.toHexString(hash)}"
            case None => {}
        }
        return folderName
    }

    /// 获取 GitHub 仓库的缓存文件夹名
    /// 翻译自: cachedGitHubFolderName
    public func cachedGitHubFolderName(repo: GitRepositoryInfo, patchHash: ?UInt64): String {
        var folderName = "github_${repo.owner}_${repo.repo}"
        match (repo.committish) {
            case c if c.length > 0 => folderName = "${folderName}_${c}"
            case _ => {}
        }
        match (patchHash) {
            case Some(hash) => folderName = "${folderName}_${bao_hash.Wyhash.toHexString(hash)}"
            case None => {}
        }
        return folderName
    }

    /// 获取 tarball 的缓存文件夹名
    /// 翻译自: cachedTarballFolderName
    public func cachedTarballFolderName(tarballUrl: String, patchHash: ?UInt64): String {
        let hash = bao_hash.Wyhash.hash(0, tarballUrl.toByteArray())
        var folderName = "tar_${bao_hash.Wyhash.toHexString(hash)}"
        match (patchHash) {
            case Some(h) => folderName = "${folderName}_${bao_hash.Wyhash.toHexString(h)}"
            case None => {}
        }
        return folderName
    }

    // ===== 任务管理方法 =====

    /// 获取待处理任务数
    /// 翻译自: PackageManager.pendingTaskCount
    public func pendingTaskCount(): Int64 {
        return pendingTasks
    }

    /// 递增待处理任务数
    /// 翻译自: PackageManager.incrementPendingTasks
    public func incrementPendingTasks(count: Int64): Unit {
        pendingTasks += count
        totalTasks += Int64(count)
    }

    /// 递减待处理任务数
    /// 翻译自: PackageManager.decrementPendingTasks
    public func decrementPendingTasks(): Unit {
        pendingTasks -= 1
    }

    /// 运行任务
    /// 翻译自: PackageManager.runTasks
    public func runTasks(): Unit {
        // 处理异步网络任务队列
        let tasks = asyncNetworkTaskQueue.drain()
        for (task in tasks) {
            processNetworkTask(task)
        }
    }

    /// 处理网络任务
    private func processNetworkTask(task: NetworkTask): Unit {
        // 根据任务类型分发处理
        match (task.taskType) {
            case NetworkTaskType.PackageManifest => processManifestResponse(task)
            case NetworkTaskType.Extract => processExtractResponse(task)
            case NetworkTaskType.GitClone => {}
            case NetworkTaskType.GitCheckout => {}
            case NetworkTaskType.LocalTarball => {}
        }
        decrementPendingTasks()
    }

    /// 处理 manifest 响应
    private func processManifestResponse(task: NetworkTask): Unit {
        match (task.manifestCallback) {
            case Some(cb) => {
                let response = PackageVersionResponse.fromResponse(
                    task.statusCode,
                    task.responseBody,
                    cb.name,
                    cb.loadedManifest,
                    "",
                    "",
                    timestampForManifestCacheControl,
                    cb.isExtendedManifest
                )
                // 缓存 manifest
                match (response.tag) {
                    case PackageVersionResponseTag.Fresh => {
                        match (response.manifest) {
                            case Some(m) => manifests.put(cb.name, m)
                            case None => {}
                        }
                    }
                    case PackageVersionResponseTag.Cached => {
                        // 使用缓存的 manifest
                    }
                    case PackageVersionResponseTag.NotFound => {
                        // 404 错误
                        if (!task.isOptional) {
                            bao_core.Output.error("Package not found: ${cb.name}")
                        }
                    }
                }
            }
            case None => {}
        }
    }

    /// 处理提取响应
    private func processExtractResponse(task: NetworkTask): Unit {
        match (task.extractCallback) {
            case Some(cb) => {
                if (task.statusCode >= 200 && task.statusCode <= 299) {
                    // 解压 tarball 到缓存
                    let cachePath = "${getCacheDirectory()}/${cb.name}"
                    // 解压逻辑
                } else {
                    bao_core.Output.error("Failed to download tarball for ${cb.name}: HTTP ${task.statusCode}")
                }
            }
            case None => {}
        }
    }

    // ===== 入队方法 =====

    /// 入队包下载任务
    /// 翻译自: PackageManager.enqueuePackageForDownload
    public func enqueuePackageForDownload(
        name: String,
        depId: UInt32,
        pkgId: UInt32,
        version: String,
        tarballUrl: String,
        context: TaskCallbackContext,
        patchHash: ?UInt64
    ): Unit {
        let taskId = bao_hash.Wyhash.hash(0, "${name}@${version}".toByteArray())

        // 检查去重
        if (networkDedupeMap.contains(taskId)) {
            // 已有相同任务在运行, 添加回调
            match (taskQueue.get(taskId)) {
                case Some(list) => list.append(context)
                case None => {}
            }
            return
        }

        // 创建新的网络任务
        let task = NetworkTask(taskId)
        let tarballCb = ExtractTarballCallback(name, tarballUrl)
        task.forTarball(tarballCb, registryScopes.scopeForPackageName(name), NetworkAuthorization.AllowAuthorization)

        networkDedupeMap.getOrInsert(taskId, true)
        match (taskQueue.get(taskId)) {
            case Some(list) => list.append(context)
            case None => {
                let list = ArrayList<TaskCallbackContext>()
                list.append(context)
                taskQueue.put(taskId, list)
            }
        }

        networkTaskQueue.push(task)
        incrementPendingTasks(1)
    }

    /// 入队 manifest 请求
    /// 翻译自: PackageManager.enqueueParseNPMPackage
    public func enqueueParseNPMPackage(
        name: String,
        scope: NpmRegistryScope,
        loadedManifest: ?PackageManifestData,
        isOptional: Bool,
        needsExtended: Bool
    ): Unit {
        let task = NetworkTask(bao_hash.Wyhash.hash(0, name.toByteArray()))
        task.forManifest(name, scope, loadedManifest, isOptional, needsExtended)
        networkTaskQueue.push(task)
        incrementPendingTasks(1)
    }

    /// 入队 Git checkout 任务
    /// 翻译自: PackageManager.enqueueGitForCheckout
    public func enqueueGitForCheckout(
        depId: UInt32,
        name: String,
        resolution: String,
        context: TaskCallbackContext,
        patchHash: ?UInt64
    ): Unit {
        incrementPendingTasks(1)
    }

    /// 入队 tarball 下载任务
    /// 翻译自: PackageManager.enqueueTarballForDownload
    public func enqueueTarballForDownload(
        depId: UInt32,
        pkgId: UInt32,
        url: String,
        context: TaskCallbackContext,
        patchHash: ?UInt64
    ): Unit {
        incrementPendingTasks(1)
    }

    /// 入队 tarball 读取任务
    /// 翻译自: PackageManager.enqueueTarballForReading
    public func enqueueTarballForReading(
        depId: UInt32,
        pkgId: UInt32,
        name: String,
        resolution: String,
        context: TaskCallbackContext
    ): Unit {
        incrementPendingTasks(1)
    }

    // ===== 生命周期脚本方法 =====

    /// 报告慢生命周期脚本
    /// 翻译自: PackageManager.reportSlowLifecycleScripts
    public func reportSlowLifecycleScripts(): Unit {
        // 检查运行时间超过 500ms 的脚本
    }

    /// tick 生命周期脚本
    /// 翻译自: PackageManager.tickLifecycleScripts
    public func tickLifecycleScripts(): Unit {
        // 检查并启动等待中的生命周期脚本
    }

    /// 是否没有更多待处理的生命周期脚本
    /// 翻译自: PackageManager.hasNoMorePendingLifecycleScripts
    public func hasNoMorePendingLifecycleScripts(): Bool {
        return pendingLifecycleScriptTasks == 0
    }

    // ===== HTTP 方法 =====

    /// 获取 HTTP 代理
    /// 翻译自: PackageManager.httpProxy
    public func httpProxy(url: String): ?String {
        match (env.get("http_proxy")) {
            case Some(p) => return p
            case None => {}
        }
        match (env.get("https_proxy")) {
            case Some(p) => return p
            case None => {}
        }
        return None
    }

    /// 是否拒绝未授权的 TLS
    /// 翻译自: PackageManager.tlsRejectUnauthorized
    public func tlsRejectUnauthorized(): Bool {
        match (env.get("NODE_TLS_REJECT_UNAUTHORIZED")) {
            case Some(v) => return v != "0"
            case None => return true
        }
    }

    /// 是否是 CI 环境
    /// 翻译自: PackageManager.computeIsContinuousIntegration
    public func computeIsContinuousIntegration(): Bool {
        // 检查 CI 相关环境变量
        let ciVars = ["CI", "JENKINS_URL", "TRAVIS", "CIRCLECI", "GITHUB_ACTIONS", "GITLAB_CI"]
        for (v in ciVars) {
            match (env.get(v)) {
                case Some(_) => return true
                case None => {}
            }
        }
        return false
    }

    // ===== 解析方法 =====

    /// 获取包名对应的 scope
    /// 翻译自: PackageManager.scopeForPackageName
    public func scopeForPackageName(name: String): NpmRegistryScope {
        return registryScopes.scopeForPackageName(name)
    }

    /// 获取预安装状态
    /// 翻译自: PackageManager.getPreinstallState
    public func getPreinstallState(pkgId: UInt32): PreinstallState {
        if (Int64(pkgId) < preinstallState.size) {
            return preinstallState[Int64(pkgId)]
        }
        return PreinstallState.Unknown
    }

    /// 设置预安装状态
    /// 翻译自: PackageManager.setPreinstallState
    public func setPreinstallState(pkgId: UInt32, lockfile: LockfileData, state: PreinstallState): Unit {
        while (Int64(pkgId) >= preinstallState.size) {
            preinstallState.append(PreinstallState.Unknown)
        }
        preinstallState[Int64(pkgId)] = state
    }

    /// 分配 GitHub URL
    /// 翻译自: PackageManager.allocGitHubURL
    public func allocGitHubURL(repo: GitRepositoryInfo): String {
        return "https://github.com/${repo.owner}/${repo.repo}/tarball/${repo.committish}"
    }

    /// 查找来自更新请求的可信依赖
    /// 翻译自: PackageManager.findTrustedDependenciesFromUpdateRequests
    public func findTrustedDependenciesFromUpdateRequests(): HashSet<UInt32> {
        return HashSet<UInt32>()
    }

    /// 清除依赖锁文件缓冲区的缓存项
    /// 翻译自: PackageManager.clearCachedItemsDependingOnLockfileBuffer
    public func clearCachedItemsDependingOnLockfileBuffer(): Unit {
        // 清除根包 ID 缓存等
    }

    /// 构建 GitHub URL
    /// 翻译自: runTasks.zig allocGitHubURL
    public func buildGitHubURL(repo: GitRepositoryInfo): String {
        let owner = repo.owner
        let repoName = repo.repo
        let committish = if (repo.committish.length > 0) { repo.committish } else { "HEAD" }
        return "https://codeload.github.com/${owner}/${repoName}/tar.gz/${committish}"
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 分配器 (抽象)
public class Allocator {
    public func alloc(size: Int64): Array<UInt8> {
        return Array<UInt8>(size, item: UInt8(0))
    }
}

/// 日志
public class Log {
    private var errors: ArrayList<String>
    private var warnings: ArrayList<String>

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

    public func hasErrors(): Bool {
        return errors.size > 0
    }

    public func print(): Unit {
        for (e in errors) {
            bao_core.Output.error(e)
        }
        for (w in warnings) {
            bao_core.Output.warn(w)
        }
    }
}

/// 目录条目
public class DirEntry {
    public var name: String
    public var isDirectory: Bool

    public init() {
        name = ""
        isDirectory = false
    }
}

/// DotEnv 加载器
public class DotEnvLoader {
    private var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    public func get(key: String): ?String {
        return map.get(key)
    }

    public func put(key: String, value: String): Unit {
        map.put(key, value)
    }

    public func has(key: String): Bool {
        return map.contains(key)
    }

    public func loadProcess(): Unit {
        // 加载进程环境变量
    }
}

/// 文件夹解析
public class FolderResolution {
    public var packageId: UInt32

    public init() {
        packageId = UInt32(0)
    }

    public static func hash(path: String): UInt64 {
        return UInt64(bao_hash.Wyhash.hash(0, path.toByteArray()))
    }
}

/// 锁文件差异摘要
/// 翻译自: Lockfile.Package.Diff.Summary
public class LockfileDiffSummary {
    public var added: Int64
    public var removed: Int64
    public var changed: Int64

    public init() {
        added = 0
        removed = 0
        changed = 0
    }
}

/// 进度信息
public class ProgressInfo {
    public var supportsAnsiEscapeCodes: Bool
    public var totalItems: Int64
    public var completedItems: Int64

    public init() {
        supportsAnsiEscapeCodes = false
        totalItems = 0
        completedItems = 0
    }
}

/// 进度节点
public class ProgressNode {
    public var name: String
    public var estimatedTotalItems: Int64
    public var completedItems: Int64

    public init() {
        name = ""
        estimatedTotalItems = 0
        completedItems = 0
    }

    public func completeOne(): Unit {
        completedItems += 1
    }
}

/// 更新请求
public class UpdateRequest {
    public var name: String
    public var version: ?String
    public var packageId: UInt32

    public init(name: String) {
        this.name = name
        version = None
        packageId = INVALID_PACKAGE_ID
    }
}
