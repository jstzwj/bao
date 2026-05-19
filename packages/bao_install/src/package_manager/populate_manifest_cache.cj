// bao_install - 填充清单缓存
// 严格翻译自: src/install/PackageManager/PopulateManifestCache.zig
//   PopulateManifestCache 负责为锁文件中的包填充清单缓存
//   支持全部包或指定包 ID 列表
package bao_install.package_manager

import bao_install.*

import bao_core.*
import bao_collections.*

// ============================================================================
// 包列表
// 严格翻译自: PopulateManifestCache.zig - Packages
//   const Packages = union(enum) { all, ids: []const PackageID }
// ============================================================================

/// 包列表
/// 对应 Bun: PopulateManifestCache.Packages
public enum ManifestPackages {
    | All                     // 所有包
    | Ids(ArrayList<UInt32>)  // 指定包 ID 列表
}

// ============================================================================
// 填充清单缓存
// 严格翻译自: src/install/PackageManager/PopulateManifestCache.zig
//   pub fn populateManifestCache(manager, packages) !void
//   为 root_pkg_ids 包含的包的直接依赖填充清单缓存
//   如果 root_pkg_ids 长度为 0, 则获取锁文件中所有包的清单
// ============================================================================

/// 填充清单缓存
/// 对应 Bun: populateManifestCache
/// 翻译自: src/install/PackageManager/PopulateManifestCache.zig
public class PopulateManifestCache {
    /// 填充清单缓存
    /// 严格翻译自: populateManifestCache
    ///   pub fn populateManifestCache(manager, packages) !void
    ///   为锁文件中的包获取 npm 清单, 启动网络任务, 等待完成
    public static func populateManifestCache(
        manager: ManifestPackageManagerState,
        packages: ManifestPackages
    ): Unit {
        let lockfile = manager.lockfile
        match (packages) {
            case ManifestPackages.All => populateAllPackages(lockfile, manager)
            case ManifestPackages.Ids(ids) => populateNamedPackages(lockfile, manager, ids)
        }

        // Final flush and wait for any remaining tasks
        // Corresponds to Bun: manager.flushNetworkQueue() + manager.scheduleTasks() + sleepUntil
        manager.flushNetworkQueue()
        manager.scheduleTasks()

        if (manager.pendingTaskCount() > 0) {
            manager.runAndWaitForTasks(manager.options.logLevel)
        }
    }

    private static func populateAllPackages(lockfile: LockfileData, manager: ManifestPackageManagerState): Unit {
        let dependencies = lockfile.dependencies
        let resolutions = lockfile.resolutions
        let pkgResolutions = lockfile.packages.resolutions
        let pkgNames = lockfile.packages.names
        let needsExtendedManifest = manager.options.minimumReleaseAgeMs != None
        let seenPkgIds = HashSet<UInt32>()

        for (i in 0..dependencies.size) {
            let dep = dependencies[Int64(i)]
            let pkgId = resolutions[Int64(i)]

            if (pkgId == INVALID_PACKAGE_ID) { continue }
            if (seenPkgIds.contains(pkgId)) { continue }
            seenPkgIds.put(pkgId)

            if (Int64(pkgId) >= pkgResolutions.size || Int64(pkgId) >= pkgNames.size) { continue }
            let res = pkgResolutions[Int64(pkgId)]
            match (res.tag) {
                case ResolutionTag.NPM => ()
                case _ => continue
            }

            let pkgName = pkgNames[Int64(pkgId)]
            let manifest = manager.manifests.byName(pkgName, manager.scopeForPackageName(pkgName), ManifestLoadStrategy.LoadFromMemoryFallbackToDisk, needsExtendedManifest)
            if (manifest == None) {
                startManifestTask(manager, pkgName, dep, needsExtendedManifest)
            }

            manager.flushNetworkQueue()
            manager.scheduleTasks()
        }

        seenPkgIds.clear()
    }

    private static func populateNamedPackages(lockfile: LockfileData, manager: ManifestPackageManagerState, ids: ArrayList<UInt32>): Unit {
        let dependencies = lockfile.dependencies
        let resolutions = lockfile.resolutions
        let pkgResolutions = lockfile.packages.resolutions
        let pkgNames = lockfile.packages.names
        let pkgDependencies = lockfile.packages.dependencies
        let needsExtendedManifest = manager.options.minimumReleaseAgeMs != None

        for (rootPkgId in ids) {
            let pkgDeps = pkgDependencies[Int64(rootPkgId)]
            for (depIdx in pkgDeps) {
                if (Int64(depIdx) >= dependencies.size) { continue }
                let pkgId = resolutions[Int64(depIdx)]
                if (pkgId == INVALID_PACKAGE_ID) { continue }
                let dep = dependencies[Int64(depIdx)]

                if (Int64(pkgId) >= pkgResolutions.size || Int64(pkgId) >= pkgNames.size) { continue }
                let resolution = pkgResolutions[Int64(pkgId)]
                if (resolution.tag != ResolutionTag.NPM) { continue }

                let packageName = pkgNames[Int64(pkgId)]
                let manifest = manager.manifests.byName(packageName, manager.scopeForPackageName(packageName), ManifestLoadStrategy.LoadFromMemoryFallbackToDisk, needsExtendedManifest)
                if (manifest == None) {
                    startManifestTask(manager, packageName, dep, needsExtendedManifest)
                }

                manager.flushNetworkQueue()
                manager.scheduleTasks()
            }
        }
    }


    /// 启动清单获取任务
    /// 翻译自: startManifestTask
    ///   fn startManifestTask(manager, pkg_name, dep, needs_extended_manifest) !void
    private static func startManifestTask(
        manager: ManifestPackageManagerState,
        pkgName: String,
        dep: DependencyInfo,
        needsExtendedManifest: Bool
    ): Unit {
        let taskId = TaskId.forManifest(pkgName)
        if (manager.hasCreatedNetworkTask(taskId, dep.behavior.isOptional())) {
            return
        }
        manager.startProgressBarIfNone()

        let task = manager.getNetworkTask()
        task.forManifest(pkgName, manager.scopeForPackageName(pkgName), dep.behavior.isOptional(), needsExtendedManifest)
        manager.enqueueNetworkTask(task)
    }
}

// ============================================================================
// 轻量引用类型
// ============================================================================

/// 包管理器状态
/// 对应 Bun: PackageManager (清单缓存相关字段)
public class ManifestPackageManagerState {
    public var options: ManifestPackageManagerOptions
    public var lockfile: LockfileData
    public var manifests: ManifestCache

    public init() {
        options = ManifestPackageManagerOptions()
        lockfile = LockfileData()
        manifests = ManifestCache()
    }

    public func scopeForPackageName(name: String): ScopeInfo { return ScopeInfo() }
    public func flushNetworkQueue(): Unit {}
    public func scheduleTasks(): Int64 { return 0 }
    public func pendingTaskCount(): Int64 { return 0 }
    public func startProgressBarIfNone(): Unit {}
    public func hasCreatedNetworkTask(taskId: TaskId, optional: Bool): Bool { return false }
    public func getNetworkTask(): NetworkTask { return NetworkTask() }
    public func enqueueNetworkTask(task: NetworkTask): Unit {}
    public func runAndWaitForTasks(logLevel: LogLevel): Unit {}
}

/// 包管理器选项
public class ManifestPackageManagerOptions {
    public var logLevel: LogLevel
    public var minimumReleaseAgeMs: ?Int64

    public init() {
        logLevel = LogLevel.Default
        minimumReleaseAgeMs = None
    }
}

/// 锁文件数据
public class LockfileData {
    public var resolutions: ArrayList<UInt32>
    public var dependencies: ArrayList<DependencyInfo>
    public var stringBuffer: String
    public var packages: PackageSlice

    public init() {
        resolutions = ArrayList<UInt32>()
        dependencies = ArrayList<DependencyInfo>()
        stringBuffer = ""
        packages = PackageSlice()
    }
}

/// 包切片
public class PackageSlice {
    public var resolutions: ArrayList<ResolutionInfo>
    public var names: ArrayList<String>
    public var dependencies: ArrayList<ArrayList<UInt32>>

    public init() {
        resolutions = ArrayList<ResolutionInfo>()
        names = ArrayList<String>()
        dependencies = ArrayList<ArrayList<UInt32>>()
    }
}

/// 清单缓存
public class ManifestCache {
    public func byName(pkgName: String, scope: ScopeInfo, strategy: ManifestLoadStrategy, needsExtendedManifest: Bool): ?PackageManifestData {
        return None
    }
}

/// 解析信息
public class ResolutionInfo {
    public var tag: ResolutionTag

    public init() {
        tag = ResolutionTag.NPM
    }
}

/// 网络任务
public class NetworkTask {
    public init() {}
    public func forManifest(pkgName: String, scope: ScopeInfo, optional: Bool, needsExtendedManifest: Bool): Unit {}
}

/// 清单加载策略
public enum ManifestLoadStrategy {
    | LoadFromMemoryFallbackToDisk
    | LoadFromDiskOnly
}

/// 范围信息
public class ScopeInfo {
    public init() {}
}

/// 任务 ID
public class TaskId {
    public static func forManifest(pkgName: String): TaskId { return TaskId() }
}

/// 包清单数据
public class PackageManifestData {
    public init() {}
}

/// 依赖信息
public class DependencyInfo {
    public var behavior: DependencyBehavior

    public init() {
        behavior = DependencyBehavior()
    }
}

/// 依赖行为
public class DependencyBehavior {
    public func isOptional(): Bool { return false }
}
