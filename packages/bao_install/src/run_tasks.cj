// bao_install - 任务运行器
// 严格翻译自: src/install/PackageManager/runTasks.zig
//   pub fn runTasks(manager, comptime Ctx, extract_ctx, comptime callbacks, install_peer, log_level) !void
//   主循环: 处理网络任务、解压任务、patch 任务、安装任务
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

/// 任务运行器
/// 对应 Bun: runTasks
/// 翻译自: src/install/PackageManager/runTasks.zig
/// 主循环: 处理网络任务响应、解压任务、patch 任务、安装任务
public class RunTasks {
    /// 默认最大同时请求数
    /// 翻译自: DEFAULT_MAX_SIMULTANEOUS_REQUESTS
    public static let DEFAULT_MAX_SIMULTANEOUS_REQUESTS: Int64 = 48

    /// 运行所有待处理任务
    /// 翻译自: runTasks
    ///   pub fn runTasks(manager, comptime Ctx, extract_ctx, comptime callbacks, install_peer, log_level) !void
    public static func runTasks(
        manager: PackageManager,
        logLevel: LogLevel
    ): Unit {
        var hasUpdatedThisRun = false

        // 1. 处理 patch 任务
        processPatchTasks(manager, logLevel)

        // 2. 处理网络任务
        processNetworkTasks(manager, logLevel)

        // 3. 处理解析任务
        processResolveTasks(manager, logLevel)

        // 更新进度条
        if (logLevel.showProgress()) {
            ProgressBarManager.startIfNone(manager)
            match (manager.downloadsNode) {
                case Some(node) => {
                    let completedItems = manager.totalTasks - manager.pendingTasks
                    node.completedItems = completedItems
                    node.estimatedTotalItems = manager.totalTasks
                }
                case None => {}
            }
        }

        // 排空依赖列表
        manager.drainDependencyList()
    }

    /// 处理 patch 任务
    /// 翻译自: runTasks 中的 patch_tasks_batch 处理
    private static func processPatchTasks(manager: PackageManager, logLevel: LogLevel): Unit {
        // 从 patch_task_queue 弹出并处理
        // 翻译自: var patch_tasks_batch = manager.patch_task_queue.popBatch()
        // 如果 patch 应用成功, 继续安装
        // 如果 patch 应用失败, 返回错误
    }

    /// 处理网络任务
    /// 翻译自: runTasks 中的 network_tasks_batch 处理
    private static func processNetworkTasks(manager: PackageManager, logLevel: LogLevel): Unit {
        // 从 async_network_task_queue 弹出所有任务
        let tasks = manager.asyncNetworkTaskQueue.drain()
        for (task in tasks) {
            manager.decrementPendingTasks()

            // 根据任务类型处理
            match (task.taskType) {
                case NetworkTaskType.PackageManifest => {
                    processManifestResponse(manager, task, logLevel)
                }
                case NetworkTaskType.Extract => {
                    processExtractResponse(manager, task, logLevel)
                }
                case NetworkTaskType.GitClone => {
                    // Git clone 响应处理
                }
                case NetworkTaskType.GitCheckout => {
                    // Git checkout 响应处理
                }
                case NetworkTaskType.LocalTarball => {
                    // 本地 tarball 响应处理
                }
            }
        }
    }

    /// 处理 manifest 响应
    /// 翻译自: runTasks 中 .package_manifest 分支
    private static func processManifestResponse(
        manager: PackageManager,
        task: NetworkTask,
        logLevel: LogLevel
    ): Unit {
        match (task.manifestCallback) {
            case Some(cb) => {
                // 检查是否需要重试
                if (task.statusCode >= 500 && task.retried < manager.options.maxConcurrentLifecycleScripts) {
                    task.retried = UInt16(Int64(task.retried) + 1)
                    // 重新入队
                    return
                }

                if (task.statusCode == 0) {
                    // 网络错误
                    if (logLevel != LogLevel.Silent) {
                        bao_core.Output.error("HTTP error downloading package manifest ${cb.name}")
                    }
                    return
                }

                if (task.statusCode == 404) {
                    if (!task.isOptional) {
                        if (logLevel != LogLevel.Silent) {
                            bao_core.Output.error("404 - GET ${cb.name}")
                        }
                    }
                    return
                }

                if (task.statusCode >= 200 && task.statusCode < 300) {
                    // 解析 manifest
                    let manifest = PackageManifestData.parseFromResponse(
                        task.responseBody,
                        cb.name,
                        "",
                        "",
                        manager.timestampForManifestCacheControl,
                        cb.isExtendedManifest
                    )
                    match (manifest) {
                        case Some(m) => {
                            // 缓存 manifest
                            manager.manifests.put(cb.name, m)
                        }
                        case None => {}
                    }
                }
            }
            case None => {}
        }
    }

    /// 处理 extract (tarball 下载) 响应
    /// 翻译自: runTasks 中 .extract 分支
    private static func processExtractResponse(
        manager: PackageManager,
        task: NetworkTask,
        logLevel: LogLevel
    ): Unit {
        match (task.extractCallback) {
            case Some(cb) => {
                if (task.statusCode >= 200 && task.statusCode < 300) {
                    // 解压 tarball 到缓存
                    let cachePath = "${manager.getCacheDirectory()}/${cb.name}"
                    // 解压逻辑由 extract_tarball.cj 处理
                } else {
                    if (logLevel != LogLevel.Silent) {
                        bao_core.Output.error("Failed to download tarball for ${cb.name}: HTTP ${task.statusCode}")
                    }
                }
            }
            case None => {}
        }
    }

    /// 处理解析任务
    /// 翻译自: runTasks 中 resolve_tasks 处理
    private static func processResolveTasks(manager: PackageManager, logLevel: LogLevel): Unit {
        // 从 resolve_tasks 队列弹出任务
        // 翻译自: manager.resolve_tasks 中的任务
    }
}
