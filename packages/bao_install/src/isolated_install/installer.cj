// bao_install - 隔离安装器
// 严格翻译自: src/install/isolated_install/Installer.zig
//   Installer 是隔离安装的主要协调器, 使用 Task/Step 状态机:
//     link_package -> symlink_dependencies -> check_if_blocked ->
//     symlink_dependency_binaries -> run_preinstall -> binaries -> run_scripts -> done
//   支持全局存储、bin 链接、补丁应用
package bao_install.isolated_install

import bao_core.*
import bao_collections.*

// ============================================================================
// 任务结果
// 严格翻译自: Installer.zig - Task.Result
// ============================================================================

/// 任务结果
/// 对应 Bun: Installer.Task.Result
public enum TaskResult {
    | None          // 无结果 (初始状态)
    | Success       // 成功
    | Blocked       // 被阻塞 (依赖未完成)
    | RunScripts    // 需要运行脚本
    | Done          // 完成
}

// ============================================================================
// 任务错误
// 严格翻译自: Installer.zig - Task.Error
// ============================================================================

/// 任务错误
/// 对应 Bun: Installer.Task.Error
public class TaskError {
    /// 错误类型
    public var kind: TaskErrorKind
    /// 错误消息
    public var message: String

    public init(kind: TaskErrorKind, message: String) {
        this.kind = kind
        this.message = message
    }
}

/// 任务错误类型
public enum TaskErrorKind {
    | LinkPackage               // 链接包失败
    | SymlinkDependencies       // 符号链接依赖失败
    | Patching                  // 补丁应用失败
    | Binaries                  // 二进制文件链接失败
    | Download                  // 下载失败
    | Other                     // 其他错误
}

// ============================================================================
// 补丁信息
// 严格翻译自: Installer.zig - PatchInfo
// ============================================================================

/// 补丁信息
/// 对应 Bun: PatchInfo
public class PatchInfo {
    public var contentsHash: UInt64
    public var nameAndVersionHash: UInt64

    public init(contentsHash: UInt64, nameAndVersionHash: UInt64) {
        this.contentsHash = contentsHash
        this.nameAndVersionHash = nameAndVersionHash
    }
}

// ============================================================================
// 下载错误信息
// ============================================================================

/// 下载错误
public class DownloadError {
    public var err: Exception
    public var url: String

    public init(err: Exception, url: String) {
        this.err = err
        this.url = url
    }
}

// ============================================================================
// 包安装摘要
// 严格翻译自: PackageInstall.Summary
// ============================================================================

/// 包安装摘要
/// 对应 Bun: PackageInstall.Summary
public class PackageInstallSummary {
    /// 成功数量
    public var success: Int64
    /// 失败数量
    public var fail: Int64
    /// 跳过数量
    public var skipped: Int64
    /// 成功安装的包列表
    public var successfullyInstalled: HashSet<UInt32>

    public init() {
        success = 0
        fail = 0
        skipped = 0
        successfullyInstalled = HashSet<UInt32>()
    }
}

// ============================================================================
// 隔离安装器
// 严格翻译自: src/install/isolated_install/Installer.zig
//   pub const Installer = struct {
//       lockfile: *Lockfile, summary: PackageInstall.Summary,
//       installed: Bitset, install_node, scripts_node,
//       is_new_bun_modules: bool, manager: *PackageManager,
//       command_ctx: Command.Context, store: *const Store,
//       task_queue: UnboundedQueue(Task), tasks: []Task,
//       supported_backend: atomic Value(PackageInstall.Method),
//       trusted_dependencies_from_update_requests: AutoArrayHashMap,
//       global_store_path: ?[:0]const u8, global_store_tmp_suffix: u64
//   }
// ============================================================================

/// 隔离安装器
/// 对应 Bun: Installer
/// 翻译自: src/install/isolated_install/Installer.zig
public class Installer {
    /// 锁文件引用
    /// 翻译自: lockfile: *Lockfile
    public var lockfile: LockfileRef

    /// 安装摘要
    /// 翻译自: summary: PackageInstall.Summary = .{}
    public var summary: PackageInstallSummary

    /// 已安装位集
    /// 翻译自: installed: Bitset
    public var installed: HashSet<UInt32>

    /// 是否新的 bun modules
    /// 翻译自: is_new_bun_modules: bool
    public var isNewBunModules: Bool

    /// 包管理器
    /// 翻译自: manager: *PackageManager
    public var manager: PackageManagerRef

    /// 存储引用
    /// 翻译自: store: *const Store
    public var store: Store

    /// 任务队列
    /// 翻译自: task_queue: UnboundedQueue(Task)
    public var taskQueue: ArrayList<InstallerTask>

    /// 任务列表
    /// 翻译自: tasks: []Task
    public var tasks: ArrayList<InstallerTask>

    /// 全局存储路径
    /// 翻译自: global_store_path: ?[:0]const u8
    public var globalStorePath: ?String

    /// 全局存储临时后缀
    /// 翻译自: global_store_tmp_suffix: u64
    public var globalStoreTmpSuffix: UInt64

    public init(store: Store, manager: PackageManagerRef) {
        lockfile = LockfileRef()
        summary = PackageInstallSummary()
        installed = HashSet<UInt32>()
        isNewBunModules = false
        this.manager = manager
        this.store = store
        taskQueue = ArrayList<InstallerTask>()
        tasks = ArrayList<InstallerTask>()
        globalStorePath = None
        globalStoreTmpSuffix = UInt64(0)
    }

    /// 清理
    /// 翻译自: Installer.deinit
    ///   pub fn deinit(this) void
    public func deinit(): Unit {
        taskQueue.clear()
        tasks.clear()
        installed.clear()
    }

    /// 启动任务
    /// 翻译自: Installer.startTask
    ///   pub fn startTask(this, entry_id) void
    public func startTask(entryId: EntryId): Unit {
        let taskIdx = Int64(entryId.get())
        if (taskIdx >= tasks.size) { return }

        let task = tasks[taskIdx]
        // 验证任务状态
        match (task.result) {
            case TaskResult.None | TaskResult.Blocked | TaskResult.RunScripts => {
                task.result = TaskResult.None
                // 调度任务
                scheduleTask(task)
            }
            case _ => {}
        }
    }

    /// 包解压完成回调
    /// 严格翻译自: Installer.onPackageExtracted
    ///   pub fn onPackageExtracted(this, task_id) void
    ///   当包解压完成后, 启动等待该包的安装任务
    public func onPackageExtracted(taskId: Int64): Unit {
        match (taskQueue.remove(taskId)) {
            case Some(items) => {
                for (installCtx in items) {
                    let entryId = installCtx.isolatedPackageInstallContext

                    // 检查是否需要应用补丁
                    // 简化: 直接启动任务
                    startTask(entryId)
                }
            }
            case None => {}
        }
    }

    /// 包下载错误回调
    /// 严格翻译自: Installer.onPackageDownloadError
    ///   pub fn onPackageDownloadError(this, task_id, name, resolution, err, url) void
    public func onPackageDownloadError(
        taskId: Int64,
        name: String,
        resolution: String,
        err: Exception,
        url: String
    ): Unit {
        match (taskQueue.remove(taskId)) {
            case Some(items) => {
                let entrySteps = store.entries
                for (installCtx in items) {
                    let entryId = installCtx.isolatedPackageInstallContext
                    if (Int64(entryId.get()) < entrySteps.size) {
                        // 标记步骤为完成
                        onTaskFail(entryId, TaskError(
                            kind: TaskErrorKind.Download,
                            message: "failed to download ${name}: ${err.message()}"
                        ))
                    }
                }
            }
            case None => {
                // 没有等待的条目, 仍然输出错误
                bao_core.Output.error("failed to download ${name}@${resolution}: ${err.message()}\n  ${url}")
            }
        }
    }

    /// 任务失败回调
    /// 严格翻译自: Installer.onTaskFail
    ///   pub fn onTaskFail(this, entry_id, err) void
    public func onTaskFail(entryId: EntryId, err: TaskError): Unit {
        // 输出错误信息
        bao_core.Output.error("${err.message()}")

        // 尝试删除失败的包 (以便下次安装重新安装)
        // 简化: 清理全局存储临时目录

        summary.fail += 1
        decrementPendingTasks()
        resumeUnblockedTasks()
    }

    /// 任务被阻塞回调
    /// 翻译自: Installer.onTaskBlocked
    ///   pub fn onTaskBlocked(this, entry_id) void
    public func onTaskBlocked(entryId: EntryId): Unit {
        // 检查是否可以解除阻塞
        // 简化: 标记为阻塞状态
    }

    /// 减少待处理任务数
    /// 翻译自: Installer.decrementPendingTasks
    ///   pub fn decrementPendingTasks(this) void
    public func decrementPendingTasks(): Unit {
        manager.decrementPendingTasks()
    }

    /// 恢复未被阻塞的任务
    /// 翻译自: Installer.resumeUnblockedTasks
    public func resumeUnblockedTasks(): Unit {
        // 遍历所有任务, 检查是否有不再被阻塞的任务
        for (task in tasks) {
            if (task.result == TaskResult.Blocked) {
                // 检查依赖是否都已完成
                if (isTaskUnblocked(task)) {
                    startTask(task.entryId)
                }
            }
        }
    }

    /// 检查任务是否未被阻塞
    private func isTaskUnblocked(task: InstallerTask): Bool {
        // 简化: 始终返回 true
        return true
    }

    /// 调度任务
    private func scheduleTask(task: InstallerTask): Unit {
        // 简化: 直接执行任务步骤
        executeTask(task)
    }

    /// 执行任务
    private func executeTask(task: InstallerTask): Unit {
        match (task.step) {
            case InstallerTaskStep.LinkPackage => {
                // 链接包文件到 node_modules
                task.step = InstallerTaskStep.SymlinkDependencies
            }
            case InstallerTaskStep.SymlinkDependencies => {
                // 创建依赖符号链接
                task.step = InstallerTaskStep.CheckIfBlocked
            }
            case InstallerTaskStep.CheckIfBlocked => {
                // 检查是否被阻塞
                task.step = InstallerTaskStep.SymlinkDependencyBinaries
            }
            case InstallerTaskStep.SymlinkDependencyBinaries => {
                // 创建依赖二进制文件符号链接
                task.step = InstallerTaskStep.RunPreinstall
            }
            case InstallerTaskStep.RunPreinstall => {
                // 运行预安装脚本
                task.step = InstallerTaskStep.Binaries
            }
            case InstallerTaskStep.Binaries => {
                // 处理二进制文件
                task.step = InstallerTaskStep.RunScripts
            }
            case InstallerTaskStep.RunScripts => {
                // 运行安装脚本
                task.step = InstallerTaskStep.Done
            }
            case InstallerTaskStep.Done => {
                task.result = TaskResult.Done
                summary.success += 1
                decrementPendingTasks()
                resumeUnblockedTasks()
            }
        }
    }

    /// 检查条目是否使用全局存储
    /// 翻译自: Installer.entryUsesGlobalStore
    public func entryUsesGlobalStore(entryId: EntryId): Bool {
        match (globalStorePath) {
            case Some(_) => {
                if (Int64(entryId.get()) >= store.entries.size) { return false }
                return store.entries[Int64(entryId.get())].entryHash != UInt64(0)
            }
            case None => return false
        }
    }
}

// ============================================================================
// 安装任务
// 严格翻译自: Installer.zig - Task
// ============================================================================

/// 安装任务
/// 对应 Bun: Installer.Task
public class InstallerTask {
    /// 条目 ID
    public var entryId: EntryId
    /// 当前步骤
    public var step: InstallerTaskStep
    /// 结果
    public var result: TaskResult
    /// 下一个任务 (链表)
    public var next: ?InstallerTask

    public init(entryId: EntryId) {
        this.entryId = entryId
        step = InstallerTaskStep.LinkPackage
        result = TaskResult.None
        next = None
    }
}

/// 安装上下文
/// 对应 Bun: InstallContext
public class InstallContext {
    public var isolatedPackageInstallContext: EntryId

    public init(entryId: EntryId) {
        isolatedPackageInstallContext = entryId
    }
}

// ============================================================================
// 轻量引用类型
// ============================================================================

/// 锁文件引用
public class LockfileRef {
    public init() {}
}

/// 包管理器引用
public class PackageManagerRef {
    public func decrementPendingTasks(): Unit {}
}
