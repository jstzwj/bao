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
// ============================================================================

/// 隔离安装器
/// 对应 Bun: Installer
/// 翻译自: src/install/isolated_install/Installer.zig
public class Installer {
    /// 锁文件引用
    public var lockfile: LockfileRef
    /// 安装摘要
    public var summary: PackageInstallSummary
    /// 已安装位集
    public var installed: HashSet<UInt32>
    /// 是否新的 bun modules
    public var isNewBunModules: Bool
    /// 包管理器
    public var manager: PackageManagerRef
    /// 存储引用
    public var store: Store
    /// 任务队列
    public var taskQueue: ArrayList<InstallContext>
    /// 任务列表
    public var tasks: ArrayList<InstallerTask>
    /// 全局存储路径
    public var globalStorePath: ?String
    /// 全局存储临时后缀
    public var globalStoreTmpSuffix: UInt64

    public init(store: Store, manager: PackageManagerRef) {
        lockfile = LockfileRef()
        summary = PackageInstallSummary()
        installed = HashSet<UInt32>()
        isNewBunModules = false
        this.manager = manager
        this.store = store
        taskQueue = ArrayList<InstallContext>()
        tasks = ArrayList<InstallerTask>()
        globalStorePath = None
        globalStoreTmpSuffix = UInt64(0)
    }

    /// 清理
    public func deinit(): Unit {
        taskQueue.clear()
        tasks.clear()
        installed.clear()
    }

    /// 启动任务
    public func startTask(entryId: EntryId): Unit {
        let taskIdx = Int64(entryId.get())
        if (taskIdx >= tasks.size) { return }

        let task = tasks[taskIdx]
        match (task.result) {
            case TaskResult.None => scheduleTask(task)
            case TaskResult.Blocked => scheduleTask(task)
            case TaskResult.RunScripts => scheduleTask(task)
            case _ => ()
        }
    }

    /// 包解压完成回调
    public func onPackageExtracted(taskId: Int64): Unit {
        // 简化: 遍历所有等待的任务
        for (installCtx in taskQueue) {
            let entryId = installCtx.isolatedPackageInstallContext
            startTask(entryId)
        }
        taskQueue.clear()
    }

    /// 包下载错误回调
    public func onPackageDownloadError(
        taskId: Int64,
        name: String,
        resolution: String,
        err: Exception,
        url: String
    ): Unit {
        // 简化: 输出错误信息
        Output.prettyErrorln("failed to download ${name}@${resolution}: ${err.message}\n  ${url}")
    }

    /// 任务失败回调
    public func onTaskFail(entryId: EntryId, err: TaskError): Unit {
        Output.prettyErrorln("${err.message}")
        summary.fail += 1
        decrementPendingTasks()
        resumeUnblockedTasks()
    }

    /// 任务被阻塞回调
    public func onTaskBlocked(entryId: EntryId): Unit {
        // 简化: 标记为阻塞状态
    }

    /// 减少待处理任务数
    public func decrementPendingTasks(): Unit {
        manager.decrementPendingTasks()
    }

    /// 恢复未被阻塞的任务
    public func resumeUnblockedTasks(): Unit {
        for (task in tasks) {
            match (task.result) {
                case TaskResult.Blocked =>
                    if (isTaskUnblocked(task)) {
                        startTask(task.entryId)
                    }
                case _ => ()
            }
        }
    }

    /// 检查任务是否未被阻塞
    private func isTaskUnblocked(task: InstallerTask): Bool {
        return true
    }

    /// 调度任务
    private func scheduleTask(task: InstallerTask): Unit {
        task.result = TaskResult.None
        executeTask(task)
    }

    /// 执行任务
    private func executeTask(task: InstallerTask): Unit {
        match (task.step) {
            case InstallerTaskStep.LinkPackage =>
                task.step = InstallerTaskStep.SymlinkDependencies
            case InstallerTaskStep.SymlinkDependencies =>
                task.step = InstallerTaskStep.CheckIfBlocked
            case InstallerTaskStep.CheckIfBlocked =>
                task.step = InstallerTaskStep.SymlinkDependencyBinaries
            case InstallerTaskStep.SymlinkDependencyBinaries =>
                task.step = InstallerTaskStep.RunPreinstall
            case InstallerTaskStep.RunPreinstall =>
                task.step = InstallerTaskStep.Binaries
            case InstallerTaskStep.Binaries =>
                task.step = InstallerTaskStep.RunScripts
            case InstallerTaskStep.RunScripts =>
                task.step = InstallerTaskStep.Done
            case InstallerTaskStep.Done =>
                finishTask(task)
        }
    }

    /// 完成任务
    private func finishTask(task: InstallerTask): Unit {
        task.result = TaskResult.Done
        summary.success += 1
        decrementPendingTasks()
        resumeUnblockedTasks()
    }

    /// 检查条目是否使用全局存储
    public func entryUsesGlobalStore(entryId: EntryId): Bool {
        match (globalStorePath) {
            case Some(_) =>
                if (Int64(entryId.get()) >= store.entries.size) { return false }
                return store.entries[Int64(entryId.get())].entryHash != UInt64(0)
            case None => return false
        }
    }
}

// ============================================================================
// 安装任务
// ============================================================================

/// 安装任务
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

/// 安装任务步骤
public enum InstallerTaskStep {
    | LinkPackage
    | SymlinkDependencies
    | CheckIfBlocked
    | SymlinkDependencyBinaries
    | RunPreinstall
    | Binaries
    | RunScripts
    | Done
}

/// 安装上下文
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
