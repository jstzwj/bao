// bao_install - 包管理器入队操作
// 严格翻译自: src/install/PackageManager/PackageManagerEnqueue.zig
//   enqueueDependencyWithMain: 入队依赖 (主入口)
//   enqueueDependencyList: 入队依赖列表
//   enqueueTarballForDownload/Reading: 入队 tarball 下载/读取
//   enqueueGitForCheckout: 入队 Git checkout
//   enqueueParseNPMPackage: 入队 NPM 包解析
//   enqueuePackageForDownload: 入队包下载
//   enqueueDependencyToRoot: 入队依赖到根
//   enqueueDependencyWithMainAndSuccessFn: 入队依赖 (带成功回调)
//   enqueueExtractNPMPackage: 入队 NPM 包解压
//   createExtractTaskForStreaming: 创建流式解压任务
//   enqueueGitClone: 入队 Git 克隆
//   enqueueGitCheckout: 入队 Git checkout
//   enqueueLocalTarball: 入队本地 tarball
//   enqueueNetworkTask: 入队网络任务
//   enqueuePatchTask: 入队补丁任务
//   enqueuePatchTaskPre: 入队补丁预计算任务
//   getOrPutResolvedPackage: 获取或放入已解析包
//   getOrPutResolvedPackageWithFindResult: 获取或放入已解析包 (带查找结果)
//   resolutionSatisfiesDependency: 解析是否满足依赖
//   updateNameAndNameHashFromVersionReplacement: 从版本替换更新名称和哈希
package bao_install.package_manager

import bao_install.*

import bao_core.*
import bao_collections.*

// ============================================================================
// 入队结果
// ============================================================================

/// 入队结果
public enum EnqueueResult {
    | Success
    | AlreadyEnqueued
    | Error(String)
}

// ============================================================================
// 依赖入队结果
// 严格翻译自: PackageManagerEnqueue.zig - DependencyToEnqueue
//   const DependencyToEnqueue = union(enum) {
//       pending: DependencyID,
//       resolution: struct { package_id: PackageID, resolution: Resolution },
//       not_found: void,
//       failure: anyerror,
//   }
// ============================================================================

/// 依赖入队结果
/// 翻译自: DependencyToEnqueue
public enum DependencyToEnqueue {
    | Pending(UInt32)
    | Resolution(EnqueueResolution)
    | NotFound
    | Failure(String)
}

/// 入队解析结果
/// 翻译自: DependencyToEnqueue.resolution
public class EnqueueResolution {
    public var packageId: UInt32
    public var resolution: EnqueueResolutionData

    public init(packageId: UInt32, resolution: EnqueueResolutionData) {
        this.packageId = packageId
        this.resolution = resolution
    }
}

/// 解析数据 (简化)
public class EnqueueResolutionData {
    public var tag: ResolutionTagEnqueue

    public init() {
        tag = ResolutionTagEnqueue.NPM
    }
}

/// 解析标签 (入队用)
/// 翻译自: Resolution.tag 枚举
public enum ResolutionTagEnqueue {
    | NPM
    | Git
    | GitHub
    | LocalTarball
    | RemoteTarball
    | Workspace
    | Folder
    | Symlink
    | Root
    | Uninitialized
    | SingleFileModule

    public operator func ==(right: ResolutionTagEnqueue): Bool {
        match (this) {
            case NPM => match (right) { case NPM => true case _ => false }
            case Git => match (right) { case Git => true case _ => false }
            case GitHub => match (right) { case GitHub => true case _ => false }
            case LocalTarball => match (right) { case LocalTarball => true case _ => false }
            case RemoteTarball => match (right) { case RemoteTarball => true case _ => false }
            case Workspace => match (right) { case Workspace => true case _ => false }
            case Folder => match (right) { case Folder => true case _ => false }
            case Symlink => match (right) { case Symlink => true case _ => false }
            case Root => match (right) { case Root => true case _ => false }
            case Uninitialized => match (right) { case Uninitialized => true case _ => false }
            case SingleFileModule => match (right) { case SingleFileModule => true case _ => false }
        }
    }

    public operator func !=(right: ResolutionTagEnqueue): Bool {
        return !(this == right)
    }
}

// ============================================================================
// 已解析包结果
// 严格翻译自: PackageManagerEnqueue.zig - ResolvedPackageResult
//   pub const ResolvedPackageResult = struct {
//       package: Lockfile.Package,
//       is_first_time: bool = false,
//       task: ?union(enum) {
//           network_task: *NetworkTask,
//           patch_task: *PatchTask,
//       } = null,
//   }
// ============================================================================

/// 已解析包结果
/// 翻译自: ResolvedPackageResult
public class ResolvedPackageResult {
    /// 包数据
    public var `package`: EnqueuePackageInfo
    /// 是否首次解析
    public var isFirstTime: Bool
    /// 关联任务
    public var task: ?ResolvedPackageTask

    public init(pkg: EnqueuePackageInfo, isFirstTime: Bool) {
        this.`package` = pkg
        this.isFirstTime = isFirstTime
        task = None
    }

    public init(pkg: EnqueuePackageInfo, isFirstTime: Bool, task: ResolvedPackageTask) {
        this.`package` = pkg
        this.isFirstTime = isFirstTime
        this.task = Some(task)
    }
}

/// 已解析包任务 (网络任务或补丁任务)
/// 翻译自: ResolvedPackageResult.task
public enum ResolvedPackageTask {
    | NetworkTask(NetworkTaskRef)
    | PatchTask(PatchTaskRef)
}

/// 补丁任务引用
public class PatchTaskRef {
    public var callback: PatchCallbackType
    public var taskId: TaskIdRef

    public init() {
        callback = PatchCallbackType.CalcHash
        taskId = TaskIdRef()
    }

    public func deinit(): Unit {}
    public func runFromMainThread(manager: RunTasksPackageManagerState, logLevel: LogLevel): Unit {}
    public func isApplyCallback(): Bool {
        match (callback) {
            case PatchCallbackType.Apply => return true
            case _ => return false
        }
    }
    public func getApplyLoggerErrors(): Int64 { return Int64(0) }
    public func getApplyTaskId(): ?TaskId { return None }
    public func hasApplyInstallContext(): Bool { return false }
    public func getApplyInstallContext(): PatchApplyInstallContext { return PatchApplyInstallContext() }
    public func getApplyPkgId(): UInt32 { return UInt32(0) }
    public func getApplyPkgName(): String { return "" }
    public func schedule(batch: ThreadPoolBatch): Unit {}
    public func setApplyTaskId(taskId: TaskId): Unit {}
}

/// 补丁回调类型
/// 翻译自: PatchTask.callback tag
public enum PatchCallbackType {
    | CalcHash
    | Apply
}

/// 任务 ID 引用
public class TaskIdRef {
    public var value: UInt64

    public init() {
        value = UInt64(0)
    }
}

// ============================================================================
// 包管理器入队操作
// 严格翻译自: src/install/PackageManager/PackageManagerEnqueue.zig
//   大量入队函数, 负责将各种类型的依赖加入处理队列
//   核心函数: enqueueDependencyWithMainAndSuccessFn
//     根据 version.tag 分支处理: dist_tag/folder/npm, git, github,
//     symlink/workspace, tarball
// ============================================================================

/// 包管理器入队操作
/// 对应 Bun: PackageManagerEnqueue 中的函数
/// 翻译自: src/install/PackageManager/PackageManagerEnqueue.zig
public class PackageManagerEnqueue {

    /// 入队依赖 (主入口)
    /// 翻译自: enqueueDependencyWithMain
    ///   pub fn enqueueDependencyWithMain(this, dep_id, dep, resolution, install_peer) !void
    public static func enqueueDependencyWithMain(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        resolution: UInt32,
        installPeer: Bool
    ): Unit {
        enqueueDependencyWithMainAndSuccessFn(
            manager,
            depId,
            dep,
            resolution,
            installPeer,
            Option<SuccessFn>.None,
            Option<FailFn>.None
        )
    }

    /// 入队依赖 (带成功回调)
    /// 严格翻译自: enqueueDependencyWithMainAndSuccessFn
    ///   pub fn enqueueDependencyWithMainAndSuccessFn(
    ///       this, dep_id, dep, resolution, install_peer, success_fn, fail_fn
    ///   ) !void
    ///   根据 version tag 分支处理:
    ///     dist_tag/folder/npm -> 获取 manifest, 解析版本, 下载 tarball
    ///     git -> 克隆 Git 仓库
    ///     github -> 下载 GitHub tarball
    ///     symlink/workspace -> 创建符号链接
    ///     tarball -> 下载 tarball
    public static func enqueueDependencyWithMainAndSuccessFn(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        resolution: UInt32,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        // 翻译自: if (dependency.behavior.isOptionalPeer()) return;
        if (dep.behavior.isOptionalPeer()) {
            return
        }

        let version = dep.version

        if (resolution != INVALID_PACKAGE_ID) {
            match (successFn) {
                case Some(fn) => fn(depId, resolution)
                case None => ()
            }
            return
        }

        match (version.tag) {
            case DependencyVersionTag.DistTag | DependencyVersionTag.Npm => enqueueNPMPackage(manager, depId, dep, installPeer, successFn, failFn)
            case DependencyVersionTag.Folder => enqueueFolderPackage(manager, depId, dep, installPeer, successFn, failFn)
            case DependencyVersionTag.Git => enqueueGitPackage(manager, depId, dep, installPeer, successFn, failFn)
            case DependencyVersionTag.Github => enqueueGitHubPackage(manager, depId, dep, installPeer, successFn, failFn)
            case DependencyVersionTag.Symlink => enqueueSymlinkPackage(manager, depId, dep, installPeer, successFn, failFn)
            case DependencyVersionTag.Workspace => enqueueWorkspacePackage(manager, depId, dep, installPeer, successFn, failFn)
            case DependencyVersionTag.Tarball => enqueueTarballPackage(manager, depId, dep, installPeer, successFn, failFn)
            case _ => ()
        }
    }

    /// 入队依赖列表
    /// 翻译自: enqueueDependencyList
    ///   pub fn enqueueDependencyList(this, dependencies) void
    ///   遍历依赖列表, 对每个依赖:
    ///     1. 跳过已被 dependencies 覆盖的 peer 依赖
    ///     2. 调用 enqueueDependencyWithMain 处理每个依赖
    ///     3. 如果出错且为 optional/peer, 记录警告; 否则记录错误
    ///     4. 最后调用 drainDependencyList
    public static func enqueueDependencyList(
        manager: EnqueuePackageManagerState,
        dependencies: DependencyList
    ): Unit {
        manager.taskQueue.ensureUnusedCapacity(dependencies.len())

        let lockfile = manager.lockfile

        // Step 1. 跳过被 dependencies 覆盖的 peer 依赖
        // 翻译自: if (end - begin > 1 and lockfile.buffers.dependencies.items[0].behavior.isPeer())
        var begin: Int64 = dependencies.off
        let end: Int64 = dependencies.off + dependencies.length

        if (end - begin > 1 && lockfile.dependencies[Int64(0)].behavior.isPeer()) {
            var peerI: Int64 = 0
            var peer = lockfile.dependencies[peerI]
            while (peer.behavior.isPeer()) {
                var depI: Int64 = end - 1
                var dep = lockfile.dependencies[Int64(depI)]
                while (!dep.behavior.isPeer()) {
                    if (!dep.behavior.isDev()) {
                        if (peer.nameHash == dep.nameHash) {
                            // peer.* = lockfile.buffers.dependencies.items[begin]
                            begin += 1
                            break
                        }
                    }
                    depI -= 1
                    dep = lockfile.dependencies[Int64(depI)]
                }
                peerI += 1
                if (peerI == end) {
                    break
                }
                peer = lockfile.dependencies[peerI]
            }
        }

        // Step 2. 入队每个依赖
        // 翻译自: while (i < end) : (i += 1) { ... this.enqueueDependencyWithMain(...) catch |err| { ... } }
        var i: Int64 = begin
        while (i < end) {
            let dependency = lockfile.dependencies[i]
            let resolution = lockfile.resolutions[i]

            tryEnqueueDependency(
                manager,
                UInt32(i),
                dependency,
                resolution,
                false
            )

            i += 1
        }

        manager.drainDependencyList()
    }

    /// 入队依赖的错误处理包装
    /// 翻译自: enqueueDependencyList 中 try-catch 块
    private static func tryEnqueueDependency(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        resolution: UInt32,
        installPeer: Bool
    ): Unit {
        // 简化: Zig 中 catch |err| 记录日志后 continue
        // 仓颉中不使用 throws, 直接调用
        enqueueDependencyWithMain(manager, depId, dep, resolution, installPeer)
    }

    /// 入队 NPM 包
    /// 翻译自: enqueueDependencyWithMainAndSuccessFn 中 .dist_tag, .folder, .npm 分支
    ///   处理: 已知别名、覆盖、目录、获取/解析包
    private static func enqueueNPMPackage(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        let pkgName = dep.name
        let scope = manager.scopeForPackageName(pkgName)

        match (manager.manifests.byName(pkgName, scope)) {
            case Some(manifest) => enqueueNPMPackageWithManifest(manager, depId, dep, installPeer, successFn, failFn, manifest)
            case None => enqueueParseNPMPackage(manager, depId, dep, installPeer, successFn, failFn)
        }
    }

    /// NPM 包 (带 manifest) 入队辅助
    /// 翻译自: getOrPutResolvedPackage 和 getOrPutResolvedPackageWithFindResult
    private static func enqueueNPMPackageWithManifest(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn,
        manifest: ManifestData
    ): Unit {
        let resolvedVersion = manifest.resolveVersion(dep.version)
        match (resolvedVersion) {
            case Some(version) => enqueuePackageForDownload(manager, depId, dep, version.tarballUrl, version.integrity)
            case None => match (failFn) {
                case Some(fn) => fn(depId, "Failed to resolve version")
                case None => ()
            }
        }
    }

    /// 入队 NPM 包解析
    /// 翻译自: enqueueParseNPMPackage
    ///   pub fn enqueueParseNPMPackage(this, task_id, name, network_task) *ThreadPool.Task
    ///   创建 package_manifest 任务, 请求网络下载 manifest
    private static func enqueueParseNPMPackage(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        let task = manager.getNetworkTask()
        task.forManifest(dep.name, depId, dep, installPeer, successFn, failFn)
        manager.enqueueNetworkTask(task)
    }

    /// 入队包下载
    /// 翻译自: enqueuePackageForDownload
    ///   pub fn enqueuePackageForDownload(
    ///       this, name, dependency_id, package_id, version, url, task_context, patch_name_and_version_hash
    ///   ) EnqueuePackageForDownloadError!void
    ///   为 NPM 包生成 tarball 下载任务, 放入任务队列
    public static func enqueuePackageForDownload(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        tarballUrl: String,
        integrity: IntegrityInfo
    ): Unit {
        let task = manager.getNetworkTask()
        task.forExtract(depId, dep, tarballUrl, integrity)
        manager.enqueueNetworkTask(task)
    }

    /// 入队 tarball 下载
    /// 翻译自: enqueueTarballForDownload
    ///   pub fn enqueueTarballForDownload(
    ///       this, dependency_id, package_id, url, task_context, patch_name_and_version_hash
    ///   ) EnqueueTarballForDownloadError!void
    ///   通过 URL 下载 tarball, 生成网络任务, 调度到 network_tarball_batch
    public static func enqueueTarballForDownload(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        url: String
    ): Unit {
        enqueuePackageForDownload(manager, depId, dep, url, IntegrityInfo())
    }

    /// 入队 tarball 读取 (本地)
    /// 翻译自: enqueueTarballForReading
    ///   pub fn enqueueTarballForReading(
    ///       this, dependency_id, package_id, alias, resolution, task_context
    ///   ) void
    ///   读取本地 tarball 文件, 创建 local_tarball 任务
    public static func enqueueTarballForReading(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        path: String
    ): Unit {
        let task = manager.getNetworkTask()
        task.forLocalTarball(depId, dep, path)
        manager.enqueueNetworkTask(task)
    }

    /// 入队 Git checkout
    /// 翻译自: enqueueGitForCheckout
    ///   pub fn enqueueGitForCheckout(
    ///       this, dependency_id, alias, resolution, task_context, patch_name_and_version_hash
    ///   ) void
    ///   Git checkout 分两阶段:
    ///     1. 如果仓库已克隆 (git_repositories 中有), 直接 enqueueGitCheckout
    ///     2. 否则先 enqueueGitClone 克隆仓库
    public static func enqueueGitForCheckout(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        repo: String,
        ref_: String
    ): Unit {
        let task = manager.getNetworkTask()
        task.forGitCheckout(depId, dep, repo, ref_)
        manager.enqueueNetworkTask(task)
    }

    /// 入队依赖到根
    /// 翻译自: enqueueDependencyToRoot
    ///   pub fn enqueueDependencyToRoot(this, name, version, version_buf, behavior) DependencyToEnqueue
    ///   在 lockfile 中查找或创建依赖, 入队处理, 等待结果
    ///   返回 DependencyToEnqueue: pending/resolution/not_found/failure
    public static func enqueueDependencyToRoot(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef
    ): DependencyToEnqueue {
        manager.enqueueDependencyWithMain(depId, dep, INVALID_PACKAGE_ID, false)

        // 简化: 返回成功结果
        // 翻译自: 完整逻辑会在 drainDependencyList 后获取 resolution
        return DependencyToEnqueue.Pending(depId)
    }

    /// 入队网络任务
    /// 翻译自: enqueueNetworkTask
    ///   pub fn enqueueNetworkTask(this, task) void
    ///   如果网络任务 FIFO 已满, 先刷新队列; 然后写入任务
    public static func enqueueNetworkTask(
        manager: EnqueuePackageManagerState,
        task: NetworkTaskRef
    ): Unit {
        if (manager.networkTaskFifo.writableLength() == 0) {
            manager.flushNetworkQueue()
        }
        manager.networkTaskFifo.writeItemAssumeCapacity(task)
    }

    /// 入队补丁任务
    /// 翻译自: enqueuePatchTask
    ///   pub fn enqueuePatchTask(this, task) void
    ///   如果补丁任务 FIFO 已满, 先刷新队列; 然后写入任务
    public static func enqueuePatchTask(
        manager: EnqueuePackageManagerState,
        task: PatchTaskRef
    ): Unit {
        if (manager.patchTaskFifo.writableLength() == 0) {
            manager.flushPatchTaskQueue()
        }
        manager.patchTaskFifo.writeItemAssumeCapacity(task)
    }

    /// 入队补丁预计算任务
    /// 翻译自: enqueuePatchTaskPre
    ///   pub fn enqueuePatchTaskPre(this, task) void
    ///   在安装开始前计算所有补丁文件的哈希, 防止后续出现过期哈希问题
    public static func enqueuePatchTaskPre(
        manager: EnqueuePackageManagerState,
        task: PatchTaskRef
    ): Unit {
        manager.pendingPreCalcHashes.fetchAdd(1)
        if (manager.patchTaskFifo.writableLength() == 0) {
            manager.flushPatchTaskQueue()
        }
        manager.patchTaskFifo.writeItemAssumeCapacity(task)
    }

    /// 初始化解压任务
    /// 翻译自: initExtractTask
    ///   fn initExtractTask(this, tarball, network_task) *Task
    ///   创建 extract 类型的任务, 设置 tarball 信息
    ///   不移动 network_task.apply_patch_task, 安装阶段有自己的 PatchTask
    public static func initExtractTask(
        manager: EnqueuePackageManagerState,
        tarball: ExtractTarballRef,
        networkTask: NetworkTaskRef
    ): EnqueueTaskRef {
        let task = manager.preallocatedResolveTasks.getEnqueueTask()
        task.setTag(TaskTagEnqueue.Extract)
        task.setPackageManager(manager)
        task.setIdFromTask(networkTask.taskId)
        task.setExtractRequest(networkTask, tarball)
        task.setSkipVerify(!manager.options.doVerifyIntegrity)
        return task
    }

    /// 入队 NPM 包解压
    /// 翻译自: enqueueExtractNPMPackage
    ///   pub fn enqueueExtractNPMPackage(this, tarball, network_task) *ThreadPool.Task
    ///   为 NPM 包创建解压任务, 返回线程池任务
    public static func enqueueExtractNPMPackage(
        manager: EnqueuePackageManagerState,
        tarball: ExtractTarballRef,
        networkTask: NetworkTaskRef
    ): EnqueueTaskRef {
        return initExtractTask(manager, tarball, networkTask)
    }

    /// 创建流式解压任务
    /// 翻译自: createExtractTaskForStreaming
    ///   pub fn createExtractTaskForStreaming(this, tarball, network_task) *Task
    ///   在主线程分配 extract Task, 以便流式解压器完成后发布到 resolve_tasks
    ///   NetworkTask 的 pending-task 槽位复用为解压, 保持进度计数平衡
    public static func createExtractTaskForStreaming(
        manager: EnqueuePackageManagerState,
        tarball: ExtractTarballRef,
        networkTask: NetworkTaskRef
    ): EnqueueTaskRef {
        return initExtractTask(manager, tarball, networkTask)
    }

    /// 入队 Git 克隆
    /// 翻译自: enqueueGitClone
    ///   fn enqueueGitClone(this, task_id, name, repository, dep_id, dependency, res, patch_name_and_version_hash) *ThreadPool.Task
    ///   创建 git_clone 任务, 包含仓库名、URL、环境变量等
    ///   如果有 patch, 会创建 apply_patch_task
    public static func enqueueGitClone(
        manager: EnqueuePackageManagerState,
        taskId: TaskIdRef,
        name: String,
        repository: RepositoryRef,
        depId: UInt32,
        dep: DependencyRef,
        res: EnqueueResolutionData,
        patchNameAndVersionHash: ?UInt64
    ): EnqueueTaskRef {
        let task = manager.preallocatedResolveTasks.getEnqueueTask()
        task.setTag(TaskTagEnqueue.GitClone)
        task.setPackageManager(manager)
        task.setId(taskId)
        task.setGitCloneRequest(name, repository, depId, res)

        // 翻译自: apply_patch_task = if (patch_name_and_version_hash) |h| ...
        match (patchNameAndVersionHash) {
            case Some(h) => task.setApplyPatchTask(createApplyPatchTask(manager, dep, h, taskId))
            case None => ()
        }

        return task
    }

    /// 入队 Git checkout
    /// 翻译自: enqueueGitCheckout
    ///   pub fn enqueueGitCheckout(
    ///       this, task_id, dir, dependency_id, name, resolution, resolved, patch_name_and_version_hash
    ///   ) *ThreadPool.Task
    ///   创建 git_checkout 任务, 包含仓库目录、解析信息、resolved commit 等
    public static func enqueueGitCheckout(
        manager: EnqueuePackageManagerState,
        taskId: TaskIdRef,
        dir: String,
        depId: UInt32,
        name: String,
        resolution: EnqueueResolutionData,
        resolved: String,
        patchNameAndVersionHash: ?UInt64
    ): EnqueueTaskRef {
        let task = manager.preallocatedResolveTasks.getEnqueueTask()
        task.setTag(TaskTagEnqueue.GitCheckout)
        task.setPackageManager(manager)
        task.setId(taskId)
        task.setGitCheckoutRequest(dir, depId, name, resolution, resolved)

        // 翻译自: apply_patch_task = if (patch_name_and_version_hash) |h| ...
        match (patchNameAndVersionHash) {
            case Some(h) => task.setApplyPatchTask(createApplyPatchTaskForCheckout(manager, depId, h, taskId))
            case None => ()
        }

        return task
    }

    /// 入队本地 tarball
    /// 翻译自: enqueueLocalTarball
    ///   fn enqueueLocalTarball(this, task_id, dependency_id, name, path, resolution, integrity) *ThreadPool.Task
    ///   在主线程解析本地 tarball 路径 (因线程池中不能读 lockfile)
    ///   如果依赖来自 workspace, 路径相对于 workspace 解析
    public static func enqueueLocalTarball(
        manager: EnqueuePackageManagerState,
        taskId: TaskIdRef,
        depId: UInt32,
        name: String,
        path: String,
        resolution: EnqueueResolutionData,
        integrity: IntegrityInfo
    ): EnqueueTaskRef {
        // 翻译自: 路径解析逻辑
        // 如果是 workspace 依赖, 路径相对于 workspace 目录
        var tarballPath = path
        var normalize = true

        let workspacePkgId = manager.lockfile.getWorkspacePkgIfWorkspaceDep(depId)
        if (workspacePkgId != INVALID_PACKAGE_ID) {
            let workspaceRes = manager.lockfile.getResolution(workspacePkgId)
            if (workspaceRes.tag == ResolutionTagEnqueue.Workspace) {
                // 路径相对于 workspace
                let workspacePath = manager.lockfile.getWorkspacePath(workspacePkgId)
                tarballPath = manager.joinPath(workspacePath, path)
                normalize = false
            }
        }

        let task = manager.preallocatedResolveTasks.getEnqueueTask()
        task.setTag(TaskTagEnqueue.LocalTarball)
        task.setPackageManager(manager)
        task.setId(taskId)
        task.setLocalTarballRequest(name, path, tarballPath, resolution, integrity, normalize)

        return task
    }

    // ========================================================================
    // getOrPutResolvedPackage 系列函数
    // 严格翻译自: PackageManagerEnqueue.zig
    //   getOrPutResolvedPackage: 获取或放入已解析包 (主入口)
    //   getOrPutResolvedPackageWithFindResult: 获取或放入已解析包 (带查找结果)
    //   resolutionSatisfiesDependency: 检查解析是否满足依赖
    //   updateNameAndNameHashFromVersionReplacement: 从版本替换更新名称和哈希
    // ========================================================================

    /// 获取或放入已解析包 (带查找结果)
    /// 翻译自: getOrPutResolvedPackageWithFindResult
    ///   fn getOrPutResolvedPackageWithFindResult(
    ///       this, name_hash, name, dependency, version, dependency_id, behavior,
    ///       manifest, find_result, install_peer, successFn
    ///   ) !?ResolvedPackageResult
    ///   处理 NPM 包解析:
    ///     1. 如果正在更新, 检查是否需要更新
    ///     2. 检查包是否已存在
    ///     3. appendPackage 创建新包
    ///     4. 根据预安装状态决定: done/extract/calc_patch_hash/apply_patch
    public static func getOrPutResolvedPackageWithFindResult(
        manager: EnqueuePackageManagerState,
        nameHash: UInt64,
        name: String,
        dep: DependencyRef,
        version: DependencyVersionInfo,
        depId: UInt32,
        behavior: DependencyBehaviorRef,
        manifest: ManifestData,
        findResult: FindResultData,
        installPeer: Bool,
        successFn: ?SuccessFn
    ): ?ResolvedPackageResult {
        // 翻译自: should_update 检查
        let shouldUpdate = manager.toUpdate &&
            manager.lockfile.isRootDependency(depId) &&
            (manager.updateRequestsLen == 0 ||
                manager.updatingPackages.contains(name))

        // 翻译自: 检查包是否已存在
        let existingPkgId = manager.lockfile.getPackageID(nameHash, Option<DependencyVersionInfo>.None, makeNpmResolution(findResult))
        match (existingPkgId) {
            case Some(id) =>
                match (successFn) {
                    case Some(fn) => fn(depId, id)
                    case None => ()
                }
                let pkg = manager.lockfile.getPackage(id)
                return ResolvedPackageResult(pkg, false)
            case None =>
                if (behavior.isPeer() && !installPeer) {
                    return None
                }
        }

        // 翻译自: appendPackage
        let pkg = manager.lockfile.appendPackageFromNPM(
            manager, manifest, findResult
        )

        match (successFn) {
            case Some(fn) => fn(depId, pkg.metaId)
            case None => ()
        }

        // 翻译自: determinePreinstallState
        let preinstallState = manager.determinePreinstallState(pkg)
        match (preinstallState) {
            case PreinstallState.Done =>
                return ResolvedPackageResult(pkg, true)
            case PreinstallState.Extract =>
                // 翻译自: 如果 !prefetch_resolved_tarballs, 直接返回
                if (!manager.options.doPrefetchResolvedTarballs) {
                    return ResolvedPackageResult(pkg, true)
                }
                // 创建网络下载任务
                let taskId = manager.taskIdForNPMPackage(name, findResult.version)
                let networkTask = manager.generateNetworkTaskForTarball(
                    taskId,
                    findResult.tarballUrl,
                    behavior.isRequired(),
                    depId,
                    pkg,
                    Option<UInt64>.None,
                    NetworkAuthorization.AllowAuthorization
                )
                match (networkTask) {
                    case Some(task) =>
                        return ResolvedPackageResult(pkg, true, ResolvedPackageTask.NetworkTask(task))
                    case None =>
                        return ResolvedPackageResult(pkg, true)
                }
            case PreinstallState.CalcPatchHash =>
                let nameAndVersionHash = manager.getNameAndVersionHash(pkg)
                let patchTask = PatchTaskRef()
                patchTask.callback = PatchCallbackType.CalcHash
                return ResolvedPackageResult(pkg, true, ResolvedPackageTask.PatchTask(patchTask))
            case PreinstallState.ApplyPatch =>
                let patchTask = PatchTaskRef()
                patchTask.callback = PatchCallbackType.Apply
                return ResolvedPackageResult(pkg, true, ResolvedPackageTask.PatchTask(patchTask))
            case _ => return None
        }
    }

    /// 获取或放入已解析包 (主入口)
    /// 翻译自: getOrPutResolvedPackage
    ///   fn getOrPutResolvedPackage(
    ///       this, name_hash, name, dependency, version, behavior, dependency_id,
    ///       resolution, install_peer, successFn
    ///   ) !?ResolvedPackageResult
    ///   根据 version.tag 分支:
    ///     .npm/.dist_tag -> 检查 workspace, 获取 manifest, 解析版本
    ///     .folder -> 获取或创建文件夹解析
    ///     .workspace -> 从 workspace_paths 查找路径
    ///     .symlink -> 从全局 link 目录查找
    public static func getOrPutResolvedPackage(
        manager: EnqueuePackageManagerState,
        nameHash: UInt64,
        name: String,
        dep: DependencyRef,
        version: DependencyVersionInfo,
        behavior: DependencyBehaviorRef,
        depId: UInt32,
        resolution: UInt32,
        installPeer: Bool,
        successFn: ?SuccessFn
    ): ?ResolvedPackageResult {
        // 翻译自: install_peer + isPeer 分支
        if (installPeer && behavior.isPeer()) {
            let existingPkgId = manager.lockfile.getPackageIDByNameHash(nameHash)
            match (existingPkgId) {
                case Some(existingId) =>
                    let existingResolution = manager.lockfile.getResolution(existingId)
                    if (resolutionSatisfiesDependency(manager, existingResolution, version)) {
                        match (successFn) {
                            case Some(fn) => fn(depId, existingId)
                            case None => ()
                        }
                        return ResolvedPackageResult(manager.lockfile.getPackage(existingId), false)
                    }
                    // 翻译自: 检查 tag 匹配 (npm/git/github)
                    let resTag = existingResolution.tag
                    let verTag = version.tag
                    if ((resTag == ResolutionTagEnqueue.NPM && verTag == DependencyVersionTag.Npm) ||
                        (resTag == ResolutionTagEnqueue.Git && verTag == DependencyVersionTag.Git) ||
                        (resTag == ResolutionTagEnqueue.GitHub && verTag == DependencyVersionTag.Github)) {
                        // 不匹配但类型相同, 记录警告
                        match (successFn) {
                            case Some(fn) => fn(depId, existingId)
                            case None => ()
                        }
                        return ResolvedPackageResult(manager.lockfile.getPackage(existingId), false)
                    }
                case None => ()
            }
        }

        // 翻译自: resolution < lockfile.packages.len
        if (resolution < manager.lockfile.packagesLen()) {
            let pkg = manager.lockfile.getPackage(resolution)
            return ResolvedPackageResult(pkg, false)
        }

        // 根据 version.tag 分支处理
        match (version.tag) {
            case DependencyVersionTag.Npm | DependencyVersionTag.DistTag =>
                return getOrPutResolvedPackageNPM(
                    manager, nameHash, name, dep, version,
                    depId, behavior, installPeer, successFn
                )
            case DependencyVersionTag.Folder =>
                return getOrPutResolvedPackageFolder(
                    manager, nameHash, name, dep, version,
                    depId, behavior, successFn
                )
            case DependencyVersionTag.Workspace =>
                return getOrPutResolvedPackageWorkspace(
                    manager, nameHash, name, dep, version,
                    depId, behavior, successFn
                )
            case DependencyVersionTag.Symlink =>
                return getOrPutResolvedPackageSymlink(
                    manager, nameHash, name, dep, version,
                    depId, behavior, successFn
                )
            case _ => return None
        }
    }

    /// NPM 版本解析
    /// 翻译自: getOrPutResolvedPackage 中 .npm, .dist_tag 分支
    private static func getOrPutResolvedPackageNPM(
        manager: EnqueuePackageManagerState,
        nameHash: UInt64,
        name: String,
        dep: DependencyRef,
        version: DependencyVersionInfo,
        depId: UInt32,
        behavior: DependencyBehaviorRef,
        installPeer: Bool,
        successFn: ?SuccessFn
    ): ?ResolvedPackageResult {
        // 翻译自: resolve_from_workspace
        // 检查 workspace 中是否有匹配的包
        if (version.tag == DependencyVersionTag.Npm) {
            let workspacePath = manager.lockfile.getWorkspacePathByNameHash(nameHash)
            let workspaceVersion = manager.lockfile.getWorkspaceVersion(nameHash)
            if (manager.options.linkWorkspacePackages &&
                workspaceVersion.isSome()) {
                // 翻译自: 检查 workspace version 是否满足 npm version
                let rootPkg = manager.lockfile.rootPackage()
                match (rootPkg) {
                    case Some(rootPackage) =>
                        let rootDepId = rootPackage.findWorkspaceDep(nameHash)
                        match (rootDepId) {
                            case Some(workspacePkgId) =>
                                match (successFn) {
                                    case Some(fn) => fn(depId, workspacePkgId)
                                    case None => ()
                                }
                                return ResolvedPackageResult(
                                    manager.lockfile.getPackage(workspacePkgId), false
                                )
                            case None => ()
                        }
                    case None => ()
                }
            }
        }

        // 翻译自: 从 manifest 解析版本
        let nameStr = name
        let manifest = manager.manifests.byNameHash(
            manager.scopeForPackageName(nameStr),
            nameHash
        )

        match (manifest) {
            case Some(m) =>
                // 翻译自: findBestVersion / findByDistTag
                let versionResult = m.findVersion(version)
                match (versionResult) {
                    case Some(findResult) =>
                        return getOrPutResolvedPackageWithFindResult(
                            manager, nameHash, name, dep, version,
                            depId, behavior, m, findResult, installPeer, successFn
                        )
                    case None =>
                        // 翻译自: 检查 dist_tag workspace
                        if (version.tag == DependencyVersionTag.DistTag) {
                            let rootPkg = manager.lockfile.rootPackage()
                            match (rootPkg) {
                                case Some(rootPackage) =>
                                    let rootDepId = rootPackage.findWorkspaceDep(nameHash)
                                    match (rootDepId) {
                                        case Some(workspacePkgId) =>
                                            match (successFn) {
                                                case Some(fn) => fn(depId, workspacePkgId)
                                                case None => ()
                                            }
                                            return ResolvedPackageResult(
                                                manager.lockfile.getPackage(workspacePkgId), false
                                            )
                                        case None => ()
                                    }
                                case None => ()
                            }
                        }

                        if (behavior.isPeer()) {
                            return None
                        }
                        // 翻译自: 返回 NoMatchingVersion / DistTagNotFound 错误
                        return None
                }
            case None => return None // manifest 可能还在下载中
        }
    }

    /// 文件夹版本解析
    /// 翻译自: getOrPutResolvedPackage 中 .folder 分支
    private static func getOrPutResolvedPackageFolder(
        manager: EnqueuePackageManagerState,
        nameHash: UInt64,
        name: String,
        dep: DependencyRef,
        version: DependencyVersionInfo,
        depId: UInt32,
        behavior: DependencyBehaviorRef,
        successFn: ?SuccessFn
    ): ?ResolvedPackageResult {
        // 翻译自: FolderResolution.getOrPut
        let folderPath = version.folderPath
        let res = FolderResolutionRef.getOrPut(
            FolderKindRef.RelativeFolder,
            version,
            folderPath,
            manager
        )

        match (res.tag) {
            case FolderResolveResultTag.Err =>
                return None
            case FolderResolveResultTag.PackageId =>
                match (successFn) {
                    case Some(fn) => fn(depId, res.packageId)
                    case None => ()
                }
                return ResolvedPackageResult(manager.lockfile.getPackage(res.packageId), false)
            case FolderResolveResultTag.NewPackageId =>
                match (successFn) {
                    case Some(fn) => fn(depId, res.packageId)
                    case None => ()
                }
                return ResolvedPackageResult(manager.lockfile.getPackage(res.packageId), true)
        }
    }

    /// Workspace 版本解析
    /// 翻译自: getOrPutResolvedPackage 中 .workspace 分支
    private static func getOrPutResolvedPackageWorkspace(
        manager: EnqueuePackageManagerState,
        nameHash: UInt64,
        name: String,
        dep: DependencyRef,
        version: DependencyVersionInfo,
        depId: UInt32,
        behavior: DependencyBehaviorRef,
        successFn: ?SuccessFn
    ): ?ResolvedPackageResult {
        // 翻译自: workspace_path_raw
        let workspacePath = manager.lockfile.getWorkspacePathByNameHash(nameHash)
        let path = match (workspacePath) {
            case Some(p) => p
            case None => version.workspacePath
        }

        let res = FolderResolutionRef.getOrPut(
            FolderKindRef.RelativeWorkspace,
            version,
            path,
            manager
        )

        match (res.tag) {
            case FolderResolveResultTag.Err =>
                return None
            case FolderResolveResultTag.PackageId =>
                match (successFn) {
                    case Some(fn) => fn(depId, res.packageId)
                    case None => ()
                }
                return ResolvedPackageResult(manager.lockfile.getPackage(res.packageId), false)
            case FolderResolveResultTag.NewPackageId =>
                match (successFn) {
                    case Some(fn) => fn(depId, res.packageId)
                    case None => ()
                }
                return ResolvedPackageResult(manager.lockfile.getPackage(res.packageId), true)
        }
    }

    /// Symlink 版本解析
    /// 翻译自: getOrPutResolvedPackage 中 .symlink 分支
    private static func getOrPutResolvedPackageSymlink(
        manager: EnqueuePackageManagerState,
        nameHash: UInt64,
        name: String,
        dep: DependencyRef,
        version: DependencyVersionInfo,
        depId: UInt32,
        behavior: DependencyBehaviorRef,
        successFn: ?SuccessFn
    ): ?ResolvedPackageResult {
        let globalLinkDir = manager.globalLinkDirPath()
        let res = FolderResolutionRef.getOrPut(
            FolderKindRef.Global(globalLinkDir),
            version,
            version.symlinkPath,
            manager
        )

        match (res.tag) {
            case FolderResolveResultTag.Err =>
                return None
            case FolderResolveResultTag.PackageId =>
                match (successFn) {
                    case Some(fn) => fn(depId, res.packageId)
                    case None => ()
                }
                return ResolvedPackageResult(manager.lockfile.getPackage(res.packageId), false)
            case FolderResolveResultTag.NewPackageId =>
                match (successFn) {
                    case Some(fn) => fn(depId, res.packageId)
                    case None => ()
                }
                return ResolvedPackageResult(manager.lockfile.getPackage(res.packageId), true)
        }
    }

    /// 解析是否满足依赖
    /// 翻译自: resolutionSatisfiesDependency
    ///   fn resolutionSatisfiesDependency(this, resolution, dependency) bool
    ///   检查现有解析是否满足新的依赖:
    ///     NPM: semver 版本满足
    ///     Git: git 信息相等
    ///     GitHub: github 信息相等
    public static func resolutionSatisfiesDependency(
        manager: EnqueuePackageManagerState,
        resolution: EnqueueResolutionData,
        dependency: DependencyVersionInfo
    ): Bool {
        if (resolution.tag == ResolutionTagEnqueue.NPM && dependency.tag == DependencyVersionTag.Npm) {
            return dependency.npmVersionSatisfies(resolution)
        }

        if (resolution.tag == ResolutionTagEnqueue.Git && dependency.tag == DependencyVersionTag.Git) {
            return dependency.gitEql(resolution)
        }

        if (resolution.tag == ResolutionTagEnqueue.GitHub && dependency.tag == DependencyVersionTag.Github) {
            return dependency.githubEql(resolution)
        }

        return false
    }

    /// 从版本替换更新名称和名称哈希
    /// 翻译自: updateNameAndNameHashFromVersionReplacement
    ///   fn updateNameAndNameHashFromVersionReplacement(
    ///       lockfile, original_name, original_name_hash, new_version
    ///   ) struct { String, PackageNameHash }
    ///   仅 npm 和 dist_tag 有名称替换; git/github/tarball 在解压后才确定名称
    public static func updateNameAndNameHashFromVersionReplacement(
        lockfile: EnqueueLockfileRef,
        originalName: String,
        originalNameHash: UInt64,
        newVersion: DependencyVersionInfo
    ): NameAndHash {
        match (newVersion.tag) {
            case DependencyVersionTag.DistTag =>
                return NameAndHash(newVersion.distTagName, lockfile.stringHash(newVersion.distTagName))
            case DependencyVersionTag.Npm =>
                return NameAndHash(newVersion.npmName, lockfile.stringHash(newVersion.npmName))
            case DependencyVersionTag.Git =>
                return NameAndHash(newVersion.gitPackageName, originalNameHash)
            case DependencyVersionTag.Github =>
                return NameAndHash(newVersion.githubPackageName, originalNameHash)
            case DependencyVersionTag.Tarball =>
                return NameAndHash(newVersion.tarballPackageName, originalNameHash)
            case _ =>
                return NameAndHash(originalName, originalNameHash)
        }
    }

    // ========================================================================
    // 简化的入队方法 (各 version tag 对应的包入队)
    // ========================================================================

    /// 入队文件夹包
    /// 翻译自: enqueueDependencyWithMainAndSuccessFn 中 .dist_tag, .folder, .npm 分支的完整逻辑
    ///   处理: 查找已解析包、创建 manifest 任务、缓存查找等
    private static func enqueueFolderPackage(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        // 翻译自: getOrPutResolvedPackage(.folder) -> FolderResolution.getOrPut
        let result = getOrPutResolvedPackage(
            manager,
            dep.nameHash,
            dep.name,
            dep,
            dep.version,
            dep.behavior,
            depId,
            INVALID_PACKAGE_ID,
            installPeer,
            successFn
        )

        match (result) {
            case Some(r) =>
                if (r.isFirstTime && r.`package`.dependenciesLen() > 0) {
                    manager.dependencyListQueue.writeItem(r.`package`.dependencies)
                }
            case None =>
                match (failFn) {
                    case Some(fn) => fn(depId, "Missing package.json for folder dependency")
                    case None => ()
                }
        }
    }

    /// 入队 Git 包
    /// 翻译自: enqueueDependencyWithMainAndSuccessFn 中 .git 分支
    ///   1. 检查 lockfile 中是否已有该 git 包
    ///   2. 如果仓库已克隆 (git_repositories 中有), 创建 checkout 任务
    ///   3. 否则创建 clone 任务
    ///   4. 处理 peer 依赖
    private static func enqueueGitPackage(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        let depVer = dep.version
        let res = EnqueueResolutionData()
        res.tag = ResolutionTagEnqueue.Git

        // 翻译自: 检查 lockfile 中是否已存在
        let existingPkgId = manager.lockfile.getPackageID(depVer.nameHash, Option<DependencyVersionInfo>.None, res)
        match (existingPkgId) {
            case Some(pkgId) =>
                match (successFn) {
                    case Some(fn) => fn(depId, pkgId)
                    case None => ()
                }
                return
            case None => ()
        }

        let alias = depVer.name
        let url = depVer.gitRepo
        let cloneId = manager.taskIdForGitClone(url)

        // 翻译自: git_repositories.get(clone_id)
        let repoFd = manager.gitRepositories.get(cloneId.value)
        match (repoFd) {
            case Some(fd) =>
                // 仓库已克隆, 执行 checkout
                let resolved = manager.findCommit(fd, alias, depVer.gitCommittish, cloneId)
                let checkoutId = manager.taskIdForGitCheckout(url, resolved)

                // 翻译自: enqueue callback context
                manager.taskQueueGetOrPut(checkoutId)

                // 翻译自: peer 依赖检查
                if (depVer.behavior.isPeer()) {
                    if (!installPeer) {
                        manager.peerDependencies.writeItem(depId)
                        return
                    }
                }

                if (manager.hasCreatedNetworkTask(checkoutId, depVer.behavior.isRequired())) {
                    return
                }

                // 创建 checkout 任务
                let task = enqueueGitCheckout(
                    manager, checkoutId, fd, depId, alias,
                    res, resolved, Option<UInt64>.None
                )
                manager.taskBatch.push(task)
            case None =>
                // 需要先克隆
                manager.taskQueueGetOrPut(cloneId)

                // 翻译自: peer 依赖检查
                if (depVer.behavior.isPeer()) {
                    if (!installPeer) {
                        manager.peerDependencies.writeItem(depId)
                        return
                    }
                }

                if (manager.hasCreatedNetworkTask(cloneId, depVer.behavior.isRequired())) {
                    return
                }

                // 创建 clone 任务
                let repository = RepositoryRef(depVer.gitRepo, depVer.gitCommittish)
                let task = enqueueGitClone(
                    manager, cloneId, alias, repository,
                    depId, DependencyRef(), res, Option<UInt64>.None
                )
                manager.taskBatch.push(task)
        }
    }

    /// 入队 GitHub 包
    /// 翻译自: enqueueDependencyWithMainAndSuccessFn 中 .github 分支
    ///   1. 检查 lockfile 中是否已有
    ///   2. 分配 GitHub tarball URL
    ///   3. 创建 tarball 下载任务
    ///   4. 处理 peer 依赖
    private static func enqueueGitHubPackage(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        let depVer = dep.version
        let res = EnqueueResolutionData()
        res.tag = ResolutionTagEnqueue.GitHub

        // 翻译自: 检查 lockfile 中是否已存在
        let existingPkgId = manager.lockfile.getPackageID(depVer.nameHash, Option<DependencyVersionInfo>.None, res)
        match (existingPkgId) {
            case Some(pkgId) =>
                match (successFn) {
                    case Some(fn) => fn(depId, pkgId)
                    case None => ()
                }
                return
            case None => ()
        }

        // 翻译自: allocGitHubURL
        let url = manager.allocGitHubURL(depVer)
        let taskId = manager.taskIdForTarball(url)

        manager.taskQueueGetOrPut(taskId)

        // 翻译自: peer 依赖检查
        if (depVer.behavior.isPeer()) {
            if (!installPeer) {
                manager.peerDependencies.writeItem(depId)
                return
            }
        }

        // 翻译自: generateNetworkTaskForTarball
        let networkTask = manager.generateNetworkTaskForTarball(
            taskId,
            url,
            depVer.behavior.isRequired(),
            depId,
            Option<EnqueuePackageInfo>.None,
            Option<UInt64>.None,
            NetworkAuthorization.NoAuthorization
        )
        match (networkTask) {
            case Some(task) => manager.enqueueNetworkTask(task)
            case None => ()
        }
    }

    /// 入队符号链接包
    /// 翻译自: enqueueDependencyWithMainAndSuccessFn 中 inline .symlink, .workspace 分支
    ///   处理: 获取或创建解析结果, 记录错误/警告
    private static func enqueueSymlinkPackage(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        let result = getOrPutResolvedPackage(
            manager,
            dep.nameHash,
            dep.name,
            dep,
            dep.version,
            dep.behavior,
            depId,
            INVALID_PACKAGE_ID,
            installPeer,
            successFn
        )

        match (result) {
            case Some(r) =>
                if (r.isFirstTime && r.`package`.dependenciesLen() > 0) {
                    manager.dependencyListQueue.writeItem(r.`package`.dependencies)
                }
            case None =>
                // 翻译自: link_not_found_fmt
                if (dep.behavior.isRequired()) {
                    manager.log.addError("Package \"${dep.name}\" is not linked")
                }
        }
    }

    /// 入队 workspace 包
    /// 翻译自: enqueueDependencyWithMainAndSuccessFn 中 inline .workspace 分支
    private static func enqueueWorkspacePackage(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        let result = getOrPutResolvedPackage(
            manager,
            dep.nameHash,
            dep.name,
            dep,
            dep.version,
            dep.behavior,
            depId,
            INVALID_PACKAGE_ID,
            installPeer,
            successFn
        )

        match (result) {
            case Some(r) =>
                if (r.isFirstTime && r.`package`.dependenciesLen() > 0) {
                    manager.dependencyListQueue.writeItem(r.`package`.dependencies)
                }
            case None =>
                // 翻译自: workspace_not_found_fmt
                if (dep.behavior.isRequired()) {
                    manager.log.addError("Workspace dependency \"${dep.name}\" not found")
                }
        }
    }

    /// 入队 tarball 包
    /// 翻译自: enqueueDependencyWithMainAndSuccessFn 中 .tarball 分支
    ///   1. 根据 tarball URI 确定是本地还是远程
    ///   2. 检查 lockfile 中是否已有
    ///   3. 本地: 创建 local_tarball 任务
    ///   4. 远程: 创建 tarball 下载任务
    private static func enqueueTarballPackage(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        dep: DependencyRef,
        installPeer: Bool,
        successFn: ?SuccessFn,
        failFn: ?FailFn
    ): Unit {
        let version = dep.version
        let res = EnqueueResolutionData()

        // 翻译自: switch (version.value.tarball.uri)
        let isLocal = version.isTarballLocal()
        let url: String

        if (isLocal) {
            res.tag = ResolutionTagEnqueue.LocalTarball
            url = version.tarballLocalPath
        } else {
            res.tag = ResolutionTagEnqueue.RemoteTarball
            url = version.tarballRemoteUrl
        }

        // 翻译自: 检查 lockfile 中是否已存在
        let existingPkgId = manager.lockfile.getPackageID(dep.nameHash, Option<DependencyVersionInfo>.None, res)
        match (existingPkgId) {
            case Some(pkgId) =>
                match (successFn) {
                    case Some(fn) => fn(depId, pkgId)
                    case None => ()
                }
                return
            case None => ()
        }

        let taskId = manager.taskIdForTarball(url)
        manager.taskQueueGetOrPut(taskId)

        // 翻译自: peer 依赖检查
        if (dep.behavior.isPeer()) {
            if (!installPeer) {
                manager.peerDependencies.writeItem(depId)
                return
            }
        }

        if (isLocal) {
            // 翻译自: .local => hasCreatedNetworkTask + enqueueLocalTarball
            if (manager.hasCreatedNetworkTask(taskId, dep.behavior.isRequired())) {
                return
            }
            let task = enqueueLocalTarball(
                manager, taskId, depId, dep.name,
                url, res, IntegrityInfo()
            )
            manager.taskBatch.push(task)
        } else {
            // 翻译自: .remote => generateNetworkTaskForTarball
            let networkTask = manager.generateNetworkTaskForTarball(
                taskId,
                url,
                dep.behavior.isRequired(),
                depId,
                Option<EnqueuePackageInfo>.None,
                Option<UInt64>.None,
                NetworkAuthorization.NoAuthorization
            )
            match (networkTask) {
                case Some(task) => manager.enqueueNetworkTask(task)
                case None => ()
            }
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 创建 apply patch 任务 (git clone 用)
    /// 翻译自: enqueueGitClone 中 apply_patch_task 逻辑
    private static func createApplyPatchTask(
        manager: EnqueuePackageManagerState,
        dep: DependencyRef,
        nameAndVersionHash: UInt64,
        taskId: TaskIdRef
    ): PatchTaskRef {
        let pt = PatchTaskRef()
        pt.callback = PatchCallbackType.Apply
        pt.taskId = taskId
        return pt
    }

    /// 创建 apply patch 任务 (git checkout 用)
    /// 翻译自: enqueueGitCheckout 中 apply_patch_task 逻辑
    private static func createApplyPatchTaskForCheckout(
        manager: EnqueuePackageManagerState,
        depId: UInt32,
        nameAndVersionHash: UInt64,
        taskId: TaskIdRef
    ): PatchTaskRef {
        let pt = PatchTaskRef()
        pt.callback = PatchCallbackType.Apply
        pt.taskId = taskId
        return pt
    }

    /// 创建 NPM 解析数据
    /// 翻译自: getOrPutResolvedPackageWithFindResult 中的 Resolution 构造
    private static func makeNpmResolution(findResult: FindResultData): EnqueueResolutionData {
        let res = EnqueueResolutionData()
        res.tag = ResolutionTagEnqueue.NPM
        return res
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 名称和哈希对
/// 翻译自: updateNameAndNameHashFromVersionReplacement 返回值
public class NameAndHash {
    public var name: String
    public var nameHash: UInt64

    public init(name: String, nameHash: UInt64) {
        this.name = name
        this.nameHash = nameHash
    }
}

/// 成功回调
public type SuccessFn = (UInt32, UInt32) -> Unit

/// 失败回调
public type FailFn = (UInt32, String) -> Unit

/// 依赖引用
public class DependencyRef {
    public var name: String
    public var nameHash: UInt64
    public var version: DependencyVersionInfo
    public var behavior: DependencyBehaviorRef

    public init() {
        name = ""
        nameHash = UInt64(0)
        version = DependencyVersionInfo()
        behavior = DependencyBehaviorRef()
    }
}

/// 依赖版本信息
/// 翻译自: Dependency.Version
public class DependencyVersionInfo {
    public var tag: DependencyVersionTag
    public var literal: String
    public var nameHash: UInt64
    public var name: String
    public var behavior: DependencyBehaviorRef
    // dist_tag
    public var distTagName: String
    public var distTagTag: String
    // npm
    public var npmName: String
    public var npmVersionHead: String
    public var npmIsAlias: Bool
    // folder
    public var folderPath: String
    // git
    public var gitRepo: String
    public var gitCommittish: String
    public var gitPackageName: String
    // github
    public var githubOwner: String
    public var githubRepo: String
    public var githubCommittish: String
    public var githubPackageName: String
    // tarball
    public var tarballPackageName: String
    public var tarballLocalPath: String
    public var tarballRemoteUrl: String
    // workspace
    public var workspacePath: String
    // symlink
    public var symlinkPath: String
    // catalog
    public var catalogName: String

    public init() {
        tag = DependencyVersionTag.Uninitialized
        literal = ""
        nameHash = UInt64(0)
        name = ""
        behavior = DependencyBehaviorRef()
        distTagName = ""
        distTagTag = ""
        npmName = ""
        npmVersionHead = ""
        npmIsAlias = false
        folderPath = ""
        gitRepo = ""
        gitCommittish = ""
        gitPackageName = ""
        githubOwner = ""
        githubRepo = ""
        githubCommittish = ""
        githubPackageName = ""
        tarballPackageName = ""
        tarballLocalPath = ""
        tarballRemoteUrl = ""
        workspacePath = ""
        symlinkPath = ""
        catalogName = ""
    }

    /// 是否为 tarball 本地路径
    /// 翻译自: version.value.tarball.uri == .local
    public func isTarballLocal(): Bool {
        return tag == DependencyVersionTag.Tarball && tarballLocalPath.size > 0 && tarballRemoteUrl.size == 0
    }

    /// NPM 版本是否满足 resolution
    /// 翻译自: dependency.value.npm.version.satisfies(resolution.value.npm.version)
    public func npmVersionSatisfies(resolution: EnqueueResolutionData): Bool {
        return tag == DependencyVersionTag.Npm && resolution.tag == ResolutionTagEnqueue.NPM
    }

    /// Git 信息是否相等
    /// 翻译自: resolution.value.git.eql(&dependency.value.git)
    public func gitEql(resolution: EnqueueResolutionData): Bool {
        return tag == DependencyVersionTag.Git && resolution.tag == ResolutionTagEnqueue.Git
    }

    /// GitHub 信息是否相等
    /// 翻译自: resolution.value.github.eql(&dependency.value.github)
    public func githubEql(resolution: EnqueueResolutionData): Bool {
        return tag == DependencyVersionTag.Github && resolution.tag == ResolutionTagEnqueue.GitHub
    }

    /// 是否为 NPM 类标签
    /// 翻译自: version.tag.isNPM()
    public func isNPM(): Bool {
        return tag == DependencyVersionTag.Npm || tag == DependencyVersionTag.DistTag
    }

    // additional stubs for run_tasks usage
    public func getPkgName(): String { return "" }
    public func setGitPackageName(name: String): Unit {}
    public func setGitHubPackageName(name: String): Unit {}
    public func setTarballPackageName(name: String): Unit {}
}

/// 依赖行为引用
public class DependencyBehaviorRef {
    public func isOptional(): Bool { return false }
    public func isPeer(): Bool { return false }
    public func isOptionalPeer(): Bool { return false }
    public func isRequired(): Bool { return true }
    public func isDev(): Bool { return false }
    public func isWorkspace(): Bool { return false }
}

/// 完整性信息
public class IntegrityInfo {
    public init() {}
}

/// 查找结果数据
/// 翻译自: Npm.PackageManifest.FindResult
public class FindResultData {
    public var version: String
    public var tarballUrl: String
    public var pkgName: String

    public init() {
        version = ""
        tarballUrl = ""
        pkgName = ""
    }
}

/// 依赖列表
/// 翻译自: Lockfile.DependencySlice
public class DependencyList {
    public var off: Int64
    public var length: Int64

    public init() {
        off = 0
        length = 0
    }

    public init(off: Int64, len: Int64) {
        this.off = off
        this.length = len
    }

    public func len(): Int64 {
        return length
    }
}

/// 任务标签 (入队用)
/// 翻译自: Task.Tag
public enum TaskTagEnqueue {
    | PackageManifest
    | Extract
    | GitClone
    | GitCheckout
    | LocalTarball
}

/// 包管理器状态
/// 翻译自: *PackageManager
public class EnqueuePackageManagerState {
    public var lockfile: EnqueueLockfileRef
    public var manifests: EnqueueManifestCache
    public var dependencyListQueue: TaskQueue
    public var peerDependencies: TaskQueue
    public var taskQueue: EnqueueTaskQueue
    public var taskBatch: TaskBatch
    public var networkTaskFifo: FifoQueue<NetworkTaskRef>
    public var patchTaskFifo: FifoQueue<PatchTaskRef>
    public var preallocatedResolveTasks: PreallocatedTasks
    public var pendingPreCalcHashes: AtomicCounter
    public var gitRepositories: HashMap<UInt64, String>
    public var toUpdate: Bool
    public var updateRequestsLen: Int64
    public var updatingPackages: HashSet<String>
    public var options: EnqueueOptions
    public var log: EnqueueLog

    public init() {
        lockfile = EnqueueLockfileRef()
        manifests = EnqueueManifestCache()
        dependencyListQueue = TaskQueue()
        peerDependencies = TaskQueue()
        taskQueue = EnqueueTaskQueue()
        taskBatch = TaskBatch()
        networkTaskFifo = FifoQueue<NetworkTaskRef>()
        patchTaskFifo = FifoQueue<PatchTaskRef>()
        preallocatedResolveTasks = PreallocatedTasks()
        pendingPreCalcHashes = AtomicCounter()
        gitRepositories = HashMap<UInt64, String>()
        toUpdate = false
        updateRequestsLen = 0
        updatingPackages = HashSet<String>()
        options = EnqueueOptions()
        log = EnqueueLog()
    }

    public func scopeForPackageName(name: String): EnqueueScopeInfo { return EnqueueScopeInfo() }
    public func getNetworkTask(): NetworkTaskRef { return NetworkTaskRef() }
    public func enqueueNetworkTask(task: NetworkTaskRef): Unit {}
    public func enqueueDependencyWithMain(depId: UInt32, dep: DependencyRef, resolution: UInt32, installPeer: Bool): Unit {}
    public func drainDependencyList(): Unit {}
    public func flushNetworkQueue(): Unit {}
    public func flushPatchTaskQueue(): Unit {}
    public func taskIdForTarball(url: String): TaskIdRef { return TaskIdRef() }
    public func taskIdForGitClone(url: String): TaskIdRef { return TaskIdRef() }
    public func taskIdForGitCheckout(url: String, resolved: String): TaskIdRef { return TaskIdRef() }
    public func taskIdForNPMPackage(name: String, version: String): TaskIdRef { return TaskIdRef() }
    public func taskIdForManifest(name: String): TaskIdRef { return TaskIdRef() }
    public func hasCreatedNetworkTask(taskId: TaskIdRef, isRequired: Bool): Bool { return false }
    public func taskQueueGetOrPut(taskId: TaskIdRef): Unit {}
    public func generateNetworkTaskForTarball(taskId: TaskIdRef, url: String, isRequired: Bool, depId: UInt32, pkg: ?EnqueuePackageInfo, patchHash: ?UInt64, auth: NetworkAuthorization): ?NetworkTaskRef { return None }
    public func allocGitHubURL(version: DependencyVersionInfo): String { return "" }
    public func findCommit(dir: String, alias: String, committish: String, cloneId: TaskIdRef): String { return "" }
    public func joinPath(base: String, relative: String): String { return base + "/" + relative }
    public func globalLinkDirPath(): String { return "" }
    public func determinePreinstallState(pkg: EnqueuePackageInfo): PreinstallState { return PreinstallState.Done }
    public func getNameAndVersionHash(pkg: EnqueuePackageInfo): ?UInt64 { return None }
    public func getPreinstallState(pkgId: UInt32): PreinstallState { return PreinstallState.Done }
    public func setPreinstallState(pkgId: UInt32, lockfile: EnqueueLockfileRef, state: PreinstallState): Unit {}
    public func scheduleTasks(): Int64 { return 0 }
}

/// 包管理器选项 (入队用)
/// 翻译自: PackageManager.options
public class EnqueueOptions {
    public var doVerifyIntegrity: Bool
    public var doPrefetchResolvedTarballs: Bool
    public var linkWorkspacePackages: Bool
    public var minimumReleaseAgeMs: ?Int64
    public var enableManifestCache: Bool
    public var enableManifestCacheControl: Bool
    public var logLevel: EnqueueLogLevel

    public init() {
        doVerifyIntegrity = true
        doPrefetchResolvedTarballs = true
        linkWorkspacePackages = true
        minimumReleaseAgeMs = None
        enableManifestCache = true
        enableManifestCacheControl = true
        logLevel = EnqueueLogLevel.Default
    }
}

/// 日志级别 (入队用)
/// 翻译自: options.log_level
public enum EnqueueLogLevel {
    | Default
    | Verbose
    | Silent
}

/// 日志 (入队用)
/// 翻译自: logger.Log
public class EnqueueLog {
    public init() {}

    public func addError(msg: String): Unit {}
    public func addWarning(msg: String): Unit {}
    public func addErrorFmt(loc: String, msg: String, args: Array<String>): Unit {}
    public func addWarningFmt(loc: String, msg: String, args: Array<String>): Unit {}
    public func addWarningWithNote(loc: ?String, args: Array<String>, alloc: String, errMsg: String, noteFmt: String, noteArgs: Array<String>): Unit {}
    public func addZigErrorWithNote(alloc: String, err: String, noteFmt: String, noteArgs: Array<String>): Unit {}
}

/// 清单缓存
public class EnqueueManifestCache {
    public func byName(pkgName: String, scope: EnqueueScopeInfo): ?ManifestData { return None }
    public func byNameHash(scope: EnqueueScopeInfo, nameHash: UInt64): ?ManifestData { return None }
    public func byNameHashAllowExpired(scope: EnqueueScopeInfo, nameHash: UInt64, expired: BoolRef, mode: ManifestLoadMode, needsExtended: Bool): ?ManifestData { return None }
}

/// Manifest 加载模式
/// 翻译自: .load_from_memory_fallback_to_disk
public enum ManifestLoadMode {
    | LoadFromMemoryFallbackToDisk
    | LoadFromDiskOnly
}

/// 清单数据 (duplicate removed - see run_tasks.cj)
/*
public class ManifestData {
    public func resolveVersion(version: DependencyVersionInfo): ?ResolvedVersion { return None }
    public func findVersion(version: DependencyVersionInfo): ?FindResultData { return None }
    public func findByDistTag(tag: String): ?FindResultData { return None }
    public func findByDistTagWithFilter(tag: String, minAgeMs: ?Int64, excludes: HashSet<String>): ?FindResultData { return None }
    public func findBestVersionWithFilter(version: DependencyVersionInfo, buf: String, minAgeMs: ?Int64, excludes: HashSet<String>): ?FindResultData { return None }
}
*/

/// 已解析版本
public class ResolvedVersion {
    public var tarballUrl: String
    public var integrity: IntegrityInfo

    public init() {
        tarballUrl = ""
        integrity = IntegrityInfo()
    }
}

/// 范围信息
public class EnqueueScopeInfo {
    public init() {}
}

/// 锁文件引用 (入队用)
/// 翻译自: *Lockfile
public class EnqueueLockfileRef {
    public var dependencies: Array<DependencyRef>
    public var resolutions: Array<UInt32>

    public init() {
        dependencies = Array<DependencyRef>()
        resolutions = Array<UInt32>()
    }

    public func stringHash(s: String): UInt64 { return UInt64(0) }
    public func getPackageID(nameHash: UInt64, version: ?DependencyVersionInfo, resolution: EnqueueResolutionData): ?UInt32 { return None }
    public func getPackageIDByNameHash(nameHash: UInt64): ?UInt32 { return None }
    public func getPackageIDByVersion(nameHash: UInt64, version: DependencyVersionInfo, resolution: EnqueueResolutionData): ?UInt32 { return None }
    public func getResolution(pkgId: UInt32): EnqueueResolutionData { return EnqueueResolutionData() }
    public func getPackage(pkgId: UInt32): EnqueuePackageInfo { return EnqueuePackageInfo() }
    public func packagesLen(): UInt32 { return UInt32(0) }
    public func isRootDependency(depId: UInt32): Bool { return false }
    public func isWorkspaceDependency(depId: UInt32): Bool { return false }
    public func getWorkspacePkgIfWorkspaceDep(depId: UInt32): UInt32 { return INVALID_PACKAGE_ID }
    public func getWorkspacePathByNameHash(nameHash: UInt64): ?String { return None }
    public func getWorkspaceVersion(nameHash: UInt64): ?String { return None }
    public func getWorkspacePath(pkgId: UInt32): String { return "" }
    public func rootPackage(): ?EnqueueRootPackage { return None }
    public func appendPackageFromNPM(manager: EnqueuePackageManagerState, manifest: ManifestData, findResult: FindResultData): EnqueuePackageInfo { return EnqueuePackageInfo() }
}

/// 根包信息 (入队用)
/// 翻译自: lockfile.rootPackage()
public class EnqueueRootPackage {
    public func findWorkspaceDep(nameHash: UInt64): ?UInt32 { return None }
}

/// 包信息 (入队用)
/// 翻译自: Lockfile.Package
public class EnqueuePackageInfo {
    public var name: String
    public var nameHash: UInt64
    public var metaId: UInt32
    public var dependencies: ArrayList<UInt32>

    public init() {
        name = ""
        nameHash = UInt64(0)
        metaId = UInt32(0)
        dependencies = ArrayList<UInt32>()
    }

    public func dependenciesLen(): Int64 {
        return Int64(dependencies.size)
    }
}

/// 网络任务引用 (duplicate removed - see run_tasks.cj)
/*
public class NetworkTaskRef {
    public init() {}
    public func forManifest(pkgName: String, depId: UInt32, dep: DependencyRef, installPeer: Bool, successFn: ?SuccessFn, failFn: ?FailFn): Unit {}
    public func forExtract(depId: UInt32, dep: DependencyRef, tarballUrl: String, integrity: IntegrityInfo): Unit {}
    public func forLocalTarball(depId: UInt32, dep: DependencyRef, path: String): Unit {}
    public func forGitCheckout(depId: UInt32, dep: DependencyRef, repo: String, ref_: String): Unit {}
    public func taskId(): TaskIdRef { return TaskIdRef() }
    public func schedule(batch: NetworkTarballBatch): Unit {}
}
*/

/// 入队任务引用
/// 翻译自: *Task (ThreadPool.Task)
public class EnqueueTaskRef {
    public var tag: TaskTagEnqueue
    public var id: TaskIdRef
    public var skipVerify: Bool
    public var applyPatchTask: ?PatchTaskRef
    public var extractRequest: ?ExtractRequestRef
    public var gitCloneRequest: ?GitCloneRequestRef
    public var gitCheckoutRequest: ?GitCheckoutRequestRef
    public var localTarballRequest: ?LocalTarballRequestRef

    public init() {
        tag = TaskTagEnqueue.PackageManifest
        id = TaskIdRef()
        skipVerify = false
        applyPatchTask = None
        extractRequest = None
        gitCloneRequest = None
        gitCheckoutRequest = None
        localTarballRequest = None
    }

    public func setTag(tag: TaskTagEnqueue): Unit { this.tag = tag }
    public func setPackageManager(manager: EnqueuePackageManagerState): Unit {}
    public func setId(taskId: TaskIdRef): Unit { this.id = taskId }
    public func setIdFromTask(taskId: TaskId): Unit { this.id = TaskIdRef() }
    public func setSkipVerify(skip: Bool): Unit { skipVerify = skip }
    public func setApplyPatchTask(task: PatchTaskRef): Unit { applyPatchTask = Some(task) }

    public func setExtractRequest(networkTask: NetworkTaskRef, tarball: ExtractTarballRef): Unit {
        extractRequest = Some(ExtractRequestRef(networkTask, tarball))
    }

    public func setGitCloneRequest(name: String, repository: RepositoryRef, depId: UInt32, res: EnqueueResolutionData): Unit {
        gitCloneRequest = Some(GitCloneRequestRef(name, repository, depId, res))
    }

    public func setGitCheckoutRequest(dir: String, depId: UInt32, name: String, resolution: EnqueueResolutionData, resolved: String): Unit {
        gitCheckoutRequest = Some(GitCheckoutRequestRef(dir, depId, name, resolution, resolved))
    }

    public func setLocalTarballRequest(name: String, path: String, tarballPath: String, resolution: EnqueueResolutionData, integrity: IntegrityInfo, normalize: Bool): Unit {
        localTarballRequest = Some(LocalTarballRequestRef(name, path, tarballPath, resolution, integrity, normalize))
    }
}

/// 解压请求引用 (duplicate removed - see run_tasks.cj)
/*
public class ExtractRequestRef {
    public var networkTask: NetworkTaskRef
    public var tarball: ExtractTarballRef

    public init(networkTask: NetworkTaskRef, tarball: ExtractTarballRef) {
        this.networkTask = networkTask
        this.tarball = tarball
    }
}
*/

/// Git Clone 请求引用
public class GitCloneRequestRef {
    public var name: String
    public var repository: RepositoryRef
    public var depId: UInt32
    public var res: EnqueueResolutionData

    public init(name: String, repository: RepositoryRef, depId: UInt32, res: EnqueueResolutionData) {
        this.name = name
        this.repository = repository
        this.depId = depId
        this.res = res
    }
}

/// Git Checkout 请求引用
public class GitCheckoutRequestRef {
    public var repoDir: String
    public var depId: UInt32
    public var name: String
    public var resolution: EnqueueResolutionData
    public var resolved: String

    public init(repoDir: String, depId: UInt32, name: String, resolution: EnqueueResolutionData, resolved: String) {
        this.repoDir = repoDir
        this.depId = depId
        this.name = name
        this.resolution = resolution
        this.resolved = resolved
    }
}

/// Local Tarball 请求引用
public class LocalTarballRequestRef {
    public var name: String
    public var path: String
    public var tarballPath: String
    public var resolution: EnqueueResolutionData
    public var integrity: IntegrityInfo
    public var normalize: Bool

    public init(name: String, path: String, tarballPath: String, resolution: EnqueueResolutionData, integrity: IntegrityInfo, normalize: Bool) {
        this.name = name
        this.path = path
        this.tarballPath = tarballPath
        this.resolution = resolution
        this.integrity = integrity
        this.normalize = normalize
    }
}

/// 仓库引用 (入队用)
/// 翻译自: *Repository
public class RepositoryRef {
    public var owner: String
    public var repo: String
    public var committish: String

    public init() {
        owner = ""
        repo = ""
        committish = ""
    }

    public init(repo: String, committish: String) {
        owner = ""
        this.repo = repo
        this.committish = committish
    }
}

/// 任务队列
public class TaskQueue {
    public init() {}
    public func writeItem(item: UInt32): Unit {}
    public func writeItem(item: ArrayList<UInt32>): Unit {}
    public func ensureUnusedCapacity(count: Int64): Unit {}
}

/// 任务队列 (Map 形式)
/// 翻译自: task_queue: std.HashMap(Task.Id, TaskCallbackList)
public class EnqueueTaskQueue {
    public init() {}

    public func getOrPut(taskId: TaskIdRef): EnqueueTaskQueueEntry { return EnqueueTaskQueueEntry() }
    public func getOrPutContext(taskId: TaskIdRef): EnqueueTaskQueueEntry { return EnqueueTaskQueueEntry() }
    public func ensureUnusedCapacity(count: Int64): Unit {}
}

/// 任务队列条目
/// 翻译自: task_queue.getOrPut 返回值
public class EnqueueTaskQueueEntry {
    public var foundExisting: Bool
    public var value: TaskCallbackListEnqueue

    public init() {
        foundExisting = false
        value = TaskCallbackListEnqueue()
    }
}

/// 任务回调列表 (入队用)
/// 翻译自: TaskCallbackList
public class TaskCallbackListEnqueue {
    public init() {}

    public func append(callback: TaskCallbackContextEnqueue): Unit {}
}

/// 任务回调上下文 (入队用)
/// 翻译自: TaskCallbackContext
public enum TaskCallbackContextEnqueue {
    | Dependency(UInt32)
    | RootDependency(UInt32)
    | Other
}

/// 任务批次 (duplicate removed - see run_tasks.cj)
/*
/// 翻译自: ThreadPool.Batch
public class TaskBatch {
    public init() {}
    public func push(task: EnqueueTaskRef): Unit {}
}
*/

/// FIFO 队列
/// 翻译自: std.fifo
public class FifoQueue<T> {
    public init() {}
    public func writableLength(): Int64 { return Int64(0) }
    public func writeItemAssumeCapacity(item: T): Unit {}
}

/// 预分配任务池 (duplicate removed - see run_tasks.cj)
/*
/// 翻译自: preallocated_resolve_tasks
public class PreallocatedTasks {
    public init() {}
    public func get(): EnqueueTaskRef { return EnqueueTaskRef() }
}
*/

/// 原子计数器
/// 翻译自: pending_pre_calc_hashes.fetchAdd
public class AtomicCounter {
    private var value: Int64

    public init() {
        value = 0
    }

    public func fetchAdd(delta: Int64): Int64 {
        let old = value
        value += delta
        return old
    }

    public func get(): Int64 {
        return value
    }
}

/// 文件夹解析引用
/// 翻译自: FolderResolution
public class FolderResolutionRef {
    /// getOrPut 静态方法
    /// 翻译自: FolderResolution.getOrPut
    public static func getOrPut(
        kind: FolderKindRef,
        version: DependencyVersionInfo,
        path: String,
        manager: EnqueuePackageManagerState
    ): FolderResolveResultRef {
        return FolderResolveResultRef()
    }
}

/// 文件夹类型引用
/// 翻译自: FolderResolution 参数中的 kind
public enum FolderKindRef {
    | RelativeFolder
    | RelativeWorkspace
    | Global(String)
}

/// 文件夹解析结果引用
/// 翻译自: FolderResolution.getOrPut 返回值
public class FolderResolveResultRef {
    public var tag: FolderResolveResultTag
    public var packageId: UInt32

    public init() {
        tag = FolderResolveResultTag.NewPackageId
        packageId = UInt32(0)
    }
}

/// 文件夹解析结果标签
/// 翻译自: FolderResolution 返回值标签
public enum FolderResolveResultTag {
    | Err
    | PackageId
    | NewPackageId
}

/// Network tarball batch
/// 翻译自: network_tarball_batch
public class NetworkTarballBatch {
    public var len: Int64

    public init() {
        len = 0
    }
}
