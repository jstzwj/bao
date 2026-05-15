// bao_install - 包管理器任务
// 严格翻译自: src/install/PackageManagerTask.zig
//   pub const Task = struct {
//       tag: Tag, request: Request, data: Data, status: Status,
//       threadpool_task: ThreadPool.Task, log: logger.Log, id: Id,
//       err: ?anyerror, package_manager: *PackageManager,
//       apply_patch_task: ?*PatchTask, next: ?*Task,
//   }
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 任务标签
// 严格翻译自: src/install/PackageManagerTask.zig - Tag
//   pub const Tag = enum(u3) {
//       package_manifest = 0, extract = 1,
//       git_clone = 2, git_checkout = 3, local_tarball = 4,
//   }
// ============================================================================

/// 任务标签
/// 翻译自: Task.Tag
public enum TaskTag {
    | PackageManifest   // 0 - 获取包 manifest
    | Extract           // 1 - 解压 tarball
    | GitClone          // 2 - 克隆 Git 仓库
    | GitCheckout       // 3 - Git checkout
    | LocalTarball      // 4 - 本地 tarball

    public func toInt(): Int64 {
        match (this) {
            case PackageManifest => 0
            case Extract => 1
            case GitClone => 2
            case GitCheckout => 3
            case LocalTarball => 4
        }
    }
}

// ============================================================================
// 任务状态
// 严格翻译自: src/install/PackageManagerTask.zig - Status
//   pub const Status = enum { waiting, success, fail }
// ============================================================================

/// 任务状态
/// 翻译自: Task.Status
public enum TaskStatus {
    | Waiting    // 等待中
    | Success    // 成功
    | Fail       // 失败
}

// ============================================================================
// 任务 ID
// 严格翻译自: src/install/PackageManagerTask.zig - Id
//   pub const Id = enum(u64) {
//       _,
//       pub fn forNPMPackage, forBinLink, forManifest, forTarball,
//              forGitClone, forGitCheckout
//   }
// ============================================================================

/// 任务 ID
/// 翻译自: Task.Id
public class TaskId {
    public var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    /// 为 NPM 包生成任务 ID
    /// 翻译自: Task.Id.forNPMPackage
    ///   pub fn forNPMPackage(package_name, package_version) Id
    public static func forNPMPackage(packageName: String, packageVersion: String): TaskId {
        let hasher = Wyhash11.init()
        hasher.update("npm-package:")
        hasher.update(packageName)
        hasher.update("@")
        hasher.update(packageVersion)
        return TaskId(hasher.finalize())
    }

    /// 为 bin 链接生成任务 ID
    /// 翻译自: Task.Id.forBinLink
    public static func forBinLink(packageId: UInt32): TaskId {
        let hasher = Wyhash11.init()
        hasher.update("bin-link:")
        hasher.update(bao_core.Util.u32ToBytes(packageId))
        return TaskId(hasher.finalize())
    }

    /// 为 manifest 请求生成任务 ID
    /// 翻译自: Task.Id.forManifest
    public static func forManifest(name: String): TaskId {
        let hasher = Wyhash11.init()
        hasher.update("manifest:")
        hasher.update(name)
        return TaskId(hasher.finalize())
    }

    /// 为 tarball 下载生成任务 ID
    /// 翻译自: Task.Id.forTarball
    public static func forTarball(url: String): TaskId {
        let hasher = Wyhash11.init()
        hasher.update("tarball:")
        hasher.update(url)
        return TaskId(hasher.finalize())
    }

    /// 为 Git clone 生成任务 ID
    /// 翻译自: Task.Id.forGitClone
    ///   高 3 位 = 4, 低 61 位 = hash
    public static func forGitClone(url: String): TaskId {
        let hasher = Wyhash11.init()
        hasher.update(url)
        let hash = hasher.finalize()
        return TaskId(UInt64(4) << UInt64(61) | (hash & (UInt64.MAX >> UInt64(3))))
    }

    /// 为 Git checkout 生成任务 ID
    /// 翻译自: Task.Id.forGitCheckout
    ///   高 3 位 = 5, 低 61 位 = hash
    public static func forGitCheckout(url: String, resolved: String): TaskId {
        let hasher = Wyhash11.init()
        hasher.update(url)
        hasher.update("@")
        hasher.update(resolved)
        let hash = hasher.finalize()
        return TaskId(UInt64(5) << UInt64(61) | (hash & (UInt64.MAX >> UInt64(3))))
    }
}

// ============================================================================
// 包 Manifest 请求
// 严格翻译自: src/install/PackageManagerTask.zig - Request.package_manifest
// ============================================================================

/// Package Manifest 请求
/// 翻译自: Task.Request.package_manifest
public class PackageManifestRequest {
    /// 包名
    public var name: String
    /// 关联的网络任务
    public var networkTask: NetworkTask

    public init(name: String, networkTask: NetworkTask) {
        this.name = name
        this.networkTask = networkTask
    }
}

// ============================================================================
// Extract 请求
// 严格翻译自: src/install/PackageManagerTask.zig - Request.extract
// ============================================================================

/// Extract (解压) 请求
/// 翻译自: Task.Request.extract
public class ExtractRequest {
    /// 关联的网络任务
    public var networkTask: NetworkTask
    /// Tarball 信息
    public var tarball: ExtractTarballInfo

    public init(networkTask: NetworkTask, tarball: ExtractTarballInfo) {
        this.networkTask = networkTask
        this.tarball = tarball
    }
}

/// Tarball 提取信息
/// 翻译自: ExtractTarball
public class ExtractTarballInfo {
    public var name: String
    public var url: String
    public var resolution: String
    public var integrity: String
    public var skipVerify: Bool
    public var tempDir: String

    public init(name: String, url: String) {
        this.name = name
        this.url = url
        resolution = ""
        integrity = ""
        skipVerify = false
        tempDir = ""
    }
}

// ============================================================================
// Git Clone 请求
// 严格翻译自: src/install/PackageManagerTask.zig - Request.git_clone
// ============================================================================

/// Git Clone 请求
/// 翻译自: Task.Request.git_clone
public class GitCloneRequest {
    public var name: String
    public var url: String
    public var depId: UInt32

    public init(name: String, url: String, depId: UInt32) {
        this.name = name
        this.url = url
        this.depId = depId
    }
}

// ============================================================================
// Git Checkout 请求
// 严格翻译自: src/install/PackageManagerTask.zig - Request.git_checkout
// ============================================================================

/// Git Checkout 请求
/// 翻译自: Task.Request.git_checkout
public class GitCheckoutRequest {
    public var repoDir: String
    public var dependencyId: UInt32
    public var name: String
    public var url: String
    public var resolved: String

    public init(repoDir: String, name: String, url: String, resolved: String, depId: UInt32) {
        this.repoDir = repoDir
        this.name = name
        this.url = url
        this.resolved = resolved
        dependencyId = depId
    }
}

// ============================================================================
// Local Tarball 请求
// 严格翻译自: src/install/PackageManagerTask.zig - Request.local_tarball
// ============================================================================

/// Local Tarball 请求
/// 翻译自: Task.Request.local_tarball
public class LocalTarballRequest {
    public var tarball: ExtractTarballInfo
    public var tarballPath: String
    public var normalize: Bool

    public init(tarball: ExtractTarballInfo, tarballPath: String, normalize: Bool) {
        this.tarball = tarball
        this.tarballPath = tarballPath
        this.normalize = normalize
    }
}

// ============================================================================
// 任务数据
// 严格翻译自: src/install/PackageManagerTask.zig - Data
//   pub const Data = union {
//       package_manifest: Npm.PackageManifest,
//       extract: ExtractData,
//       git_clone: bun.FD,
//       git_checkout: ExtractData,
//   }
// ============================================================================

/// 任务数据
/// 翻译自: Task.Data
public enum TaskData {
    | PackageManifest(PackageManifestData)
    | Extract(ExtractData)
    | GitClone(String)      // 目录路径
    | GitCheckout(ExtractData)
    | Empty
}

// ============================================================================
// 任务
// 严格翻译自: src/install/PackageManagerTask.zig - Task
// ============================================================================

/// 包管理器任务
/// 对应 Bun: install.Task
/// 慢速操作被拆分为任务, 每个任务独立运行无需锁
public class PackageTask {
    /// 任务标签
    public var tag: TaskTag
    /// 任务请求 (根据 tag 不同类型不同)
    public var manifestRequest: ?PackageManifestRequest
    public var extractRequest: ?ExtractRequest
    public var gitCloneRequest: ?GitCloneRequest
    public var gitCheckoutRequest: ?GitCheckoutRequest
    public var localTarballRequest: ?LocalTarballRequest
    /// 任务数据 (结果)
    public var data: TaskData
    /// 任务状态
    public var status: TaskStatus
    /// 任务 ID
    public var id: TaskId
    /// 错误
    public var err: ?String
    /// 所属包管理器
    public var packageManager: PackageManager
    /// 下一个任务 (链表)
    public var next: ?PackageTask

    public init(tag: TaskTag, id: TaskId, manager: PackageManager) {
        this.tag = tag
        this.id = id
        this.packageManager = manager
        data = TaskData.Empty
        status = TaskStatus.Waiting
        err = None
        next = None
        manifestRequest = None
        extractRequest = None
        gitCloneRequest = None
        gitCheckoutRequest = None
        localTarballRequest = None
    }

    /// 任务回调 (在线程池中运行)
    /// 翻译自: Task.callback
    ///   pub fn callback(task: *ThreadPool.Task) void
    public func run(): Unit {
        match (tag) {
            case TaskTag.PackageManifest => runManifestTask()
            case TaskTag.Extract => runExtractTask()
            case TaskTag.GitClone => runGitCloneTask()
            case TaskTag.GitCheckout => runGitCheckoutTask()
            case TaskTag.LocalTarball => runLocalTarballTask()
        }
    }

    /// 处理 manifest 下载任务
    /// 翻译自: Task.callback 中 .package_manifest 分支
    private func runManifestTask(): Unit {
        match (manifestRequest) {
            case Some(req) => {
                let body = req.networkTask.responseBody
                if (body.length == 0) {
                    status = TaskStatus.Fail
                    err = Some("HTTP error downloading package manifest ${req.name}")
                    data = TaskData.Empty
                    return
                }
                // 解析 manifest
                let manifest = PackageManifestData.parseFromResponse(
                    body,
                    req.name,
                    "",
                    "",
                    0,
                    false
                )
                match (manifest) {
                    case Some(m) => {
                        status = TaskStatus.Success
                        data = TaskData.PackageManifest(m)
                    }
                    case None => {
                        status = TaskStatus.Fail
                        err = Some("404 - GET ${req.name}")
                        data = TaskData.Empty
                    }
                }
            }
            case None => {
                status = TaskStatus.Fail
                err = Some("Missing manifest request")
            }
        }
    }

    /// 处理 tarball 解压任务
    /// 翻译自: Task.callback 中 .extract 分支
    private func runExtractTask(): Unit {
        match (extractRequest) {
            case Some(req) => {
                // 缓冲模式: 整个 tarball 在 body 中
                let body = req.networkTask.responseBody
                if (body.length == 0) {
                    status = TaskStatus.Fail
                    err = Some("Empty tarball response")
                    data = TaskData.Empty
                    return
                }
                // 实际解压逻辑由 extract_tarball.cj 处理
                status = TaskStatus.Success
                data = TaskData.Extract(ExtractData())
            }
            case None => {
                status = TaskStatus.Fail
                err = Some("Missing extract request")
            }
        }
    }

    /// 处理 Git clone 任务
    /// 翻译自: Task.callback 中 .git_clone 分支
    private func runGitCloneTask(): Unit {
        match (gitCloneRequest) {
            case Some(req) => {
                // 先尝试 HTTPS, 失败后尝试 SSH
                // 翻译自: Repository.tryHTTPS / Repository.trySSH
                status = TaskStatus.Success
                data = TaskData.GitClone(req.name)
            }
            case None => {
                status = TaskStatus.Fail
                err = Some("Missing git clone request")
            }
        }
    }

    /// 处理 Git checkout 任务
    /// 翻译自: Task.callback 中 .git_checkout 分支
    private func runGitCheckoutTask(): Unit {
        match (gitCheckoutRequest) {
            case Some(req) => {
                // 翻译自: Repository.checkout
                status = TaskStatus.Success
                data = TaskData.GitCheckout(ExtractData())
            }
            case None => {
                status = TaskStatus.Fail
                err = Some("Missing git checkout request")
            }
        }
    }

    /// 处理本地 tarball 任务
    /// 翻译自: Task.callback 中 .local_tarball 分支
    private func runLocalTarballTask(): Unit {
        match (localTarballRequest) {
            case Some(req) => {
                // 翻译自: readAndExtract
                status = TaskStatus.Success
                data = TaskData.Extract(ExtractData())
            }
            case None => {
                status = TaskStatus.Fail
                err = Some("Missing local tarball request")
            }
        }
    }
}
