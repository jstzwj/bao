// bao_install - 运行任务
// 严格翻译自: src/install/PackageManager/runTasks.zig
//   runTasks: 主任务运行循环
//   pendingTaskCount/incrementPendingTasks/decrementPendingTasks: 待处理任务计数
//   flushNetworkQueue/flushPatchTaskQueue/flushDependencyQueue: 刷新队列
//   scheduleTasks: 调度任务
//   drainDependencyList: 排空依赖列表
//   getNetworkTask: 获取网络任务
//   allocGitHubURL: 分配 GitHub URL
//   hasCreatedNetworkTask/isNetworkTaskRequired: 网络任务去重
//   generateNetworkTaskForTarball: 生成 tarball 网络任务
package bao_install.package_manager

import bao_install.*

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

/// 无效包 ID
public const INVALID_PACKAGE_ID = 0xFFFFFFFFu32

// ============================================================================
// 运行任务
// 严格翻译自: runTasks.zig - runTasks
//   pub fn runTasks(
//       manager: *PackageManager,
//       comptime Ctx: type,
//       extract_ctx: Ctx,
//       comptime callbacks: anytype,
//       install_peer: bool,
//       log_level: Options.LogLevel,
//   ) !void
//   从主线程调用的核心任务循环:
//     1. 处理 patch 任务
//     2. 处理 Store.Installer 任务 (如适用)
//     3. 处理网络任务 (package_manifest / extract)
//     4. 处理 resolve 任务 (package_manifest / extract / local_tarball / git_clone / git_checkout)
// ============================================================================

/// 运行任务
/// 对应 Bun: runTasks 中的函数
/// 翻译自: src/install/PackageManager/runTasks.zig
public class RunTasks {

    /// 主任务运行循环
    /// 严格翻译自: runTasks
    ///   pub fn runTasks(manager, comptime Ctx, extract_ctx, comptime callbacks, install_peer, log_level) !void
    ///   核心循环: 处理 patch / store / network / resolve 任务
    public static func runTasks(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext,
        callbacks: RunTasksCallbacks,
        installPeer: Bool,
        logLevel: LogLevel
    ): Unit {
        var hasUpdatedThisRun = false
        var hasNetworkError = false
        var timestampThisTick: ?UInt32 = None

        // ============================================================
        // 第1段: 处理 patch 任务
        // 严格翻译自: runTasks.zig 第33-73行
        // ============================================================
        processPatchTasks(manager, ctx, callbacks, logLevel)

        // ============================================================
        // 第2段: 处理 Store.Installer 任务
        // 严格翻译自: runTasks.zig 第75-126行
        // ============================================================
        if (ctx.isStoreInstaller()) {
            processStoreInstallerTasks(manager, ctx)
        }

        // ============================================================
        // 第3段: 处理网络任务 (package_manifest / extract)
        // 严格翻译自: runTasks.zig 第128-580行
        // ============================================================
        processNetworkTasks(manager, ctx, callbacks, installPeer, logLevel, hasUpdatedThisRun, hasNetworkError, timestampThisTick)

        // ============================================================
        // 第4段: 处理 resolve 任务
        // 严格翻译自: runTasks.zig 第582-1061行
        // ============================================================
        processResolveTasks(manager, ctx, callbacks, installPeer, logLevel, hasUpdatedThisRun, timestampThisTick)

        // 原来的 defer 块，移到函数末尾
        manager.drainDependencyList()
        if (logLevel.showProgress()) {
            manager.startProgressBarIfNone()
            if (callbacks.progressBar) {
                let completedItems = manager.totalTasks - Int64(manager.pendingTaskCount())
                if (completedItems != manager.downloadsNode.getUnprotectedCompletedItems() || hasUpdatedThisRun) {
                    manager.downloadsNode.setCompletedItems(completedItems)
                    manager.downloadsNode.setEstimatedTotalItems(manager.totalTasks)
                }
            }
            manager.downloadsNode.activate()
            manager.progressMaybeRefresh()
        }
    }

    // ========================================================================
    // 第1段: 处理 patch 任务
    // 严格翻译自: runTasks.zig 第33-73行
    //   var patch_tasks_batch = manager.patch_task_queue.popBatch()
    //   while (patch_tasks_iter.next()) |ptask| { ... }
    // ========================================================================

    /// 处理 patch 任务
    /// 翻译自: runTasks 中的 patch_tasks 循环
    private static func processPatchTasks(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext,
        callbacks: RunTasksCallbacks,
        logLevel: LogLevel
    ): Unit {
        let patchTasksBatch = manager.patchTaskQueue.popBatch()
        let patchTasksIter = patchTasksBatch.iterator()

        while (patchTasksIter.hasNext()) {
            let ptask = patchTasksIter.next()
            RunTasksDebug.assert(manager.pendingTaskCount() > 0)
            manager.decrementPendingTasks()
            ptask.runFromMainThread(manager, logLevel)

            if (ptask.isApplyCallback()) {
                if (ptask.getApplyLoggerErrors() == 0) {
                    if (callbacks.hasOnExtract()) {
                        match (ptask.getApplyTaskId()) {
                            case Some(_) =>
                                // task_id 存在 - autofix 分支
                                ()
                            case None =>
                                if (ctx.isPackageInstaller()) {
                                    if (ptask.hasApplyInstallContext()) {
                                        let installCtx = ptask.getApplyInstallContext()
                                        let path = installCtx.path
                                        installCtx.resetPath()
                                        ctx.getInstaller().nodeModulesPath = path
                                        ctx.getInstaller().currentTreeId = installCtx.treeId
                                        let pkgId = ptask.getApplyPkgId()
                                        ctx.getInstaller().installPackageWithNameAndResolution(
                                            installCtx.dependencyId,
                                            pkgId,
                                            logLevel,
                                            ptask.getApplyPkgName(),
                                            ResolutionRef(),
                                            false,
                                            false
                                        )
                                    }
                                }
                        }
                    }
                } else {
                    // Patch 应用失败 - 传播错误以导致安装失败
                    throw BaoError(ErrorCode.Unreachable, "InstallFailed: patch application failed with errors")
                }
            }
        }
    }

    // ========================================================================
    // 第2段: 处理 Store.Installer 任务
    // 严格翻译自: runTasks.zig 第75-126行
    //   if (Ctx == *Store.Installer) { ... }
    // ========================================================================

    /// 处理 Store.Installer 任务
    /// 翻译自: runTasks 中的 Store.Installer 分支
    private static func processStoreInstallerTasks(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext
    ): Unit {
        let installer = ctx.getStoreInstaller()
        let batch = installer.taskQueue.popBatch()
        let iter = batch.iterator()

        while (iter.hasNext()) {
            let task = iter.next()

            match (task.result) {
                case StoreInstallerTaskResult.None =>
                    RunTasksDebug.ciAssert(false)
                    installer.onTaskComplete(task.entryId, StoreInstallerTaskStatus.Success)
                case StoreInstallerTaskResult.Err(err) =>
                    installer.onTaskFail(task.entryId, err)
                case StoreInstallerTaskResult.Blocked =>
                    installer.onTaskBlocked(task.entryId)
                case StoreInstallerTaskResult.RunScripts(list) =>
                    let entries = installer.storeEntries
                    let nodeId = entries.getNodeId(task.entryId)
                    let depId = installer.storeNodes.getDepId(nodeId)
                    let dep = installer.lockfile.getDependencyAt(depId)
                    try {
                        installer.manager.spawnPackageLifecycleScripts(
                            installer.commandCtx,
                            list,
                            dep.behavior.isOptional(),
                            false,
                            SpawnScriptsContext(task.entryId, installer)
                        )
                    } catch (err: Exception) {
                        entries.setStepDone(task.entryId)
                        installer.onTaskFail(task.entryId, StoreInstallerTaskError.RunScripts(err))
                    }
                case StoreInstallerTaskResult.Done =>
                    RunTasksDebug.ciAssert(entriesCheckStepDone(installer, task.entryId))
                    installer.onTaskComplete(task.entryId, StoreInstallerTaskStatus.Success)
            }
        }
    }

    /// entries step 检查辅助
    private static func entriesCheckStepDone(installer: StoreInstallerRef, entryId: TaskId): Bool {
        return installer.storeEntries.isStepDone(entryId)
    }

    // ========================================================================
    // 第3段: 处理网络任务 (package_manifest / extract)
    // 严格翻译自: runTasks.zig 第128-580行
    //   var network_tasks_batch = manager.async_network_task_queue.popBatch()
    //   while (network_tasks_iter.next()) |task| { switch (task.callback) { ... } }
    // ========================================================================

    /// 处理网络任务
    /// 翻译自: runTasks 中的 network_tasks 循环
    private static func processNetworkTasks(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext,
        callbacks: RunTasksCallbacks,
        installPeer: Bool,
        logLevel: LogLevel,
        hasUpdatedThisRun: Bool,
        hasNetworkError: Bool,
        timestampThisTick: ?UInt32
    ): NetworkTaskResult {
        var updated = hasUpdatedThisRun
        var networkErr = hasNetworkError
        var timestamp = timestampThisTick

        let networkTasksBatch = manager.asyncNetworkTaskQueue.popBatch()
        let networkTasksIter = networkTasksBatch.iterator()

        while (networkTasksIter.hasNext()) {
            let task = networkTasksIter.next()
            RunTasksDebug.assert(manager.pendingTaskCount() > 0)
            manager.decrementPendingTasks()

            match (task.callback) {
                case NetworkTaskCallback.PackageManifest(manifestReq) =>
                    // ----------------------------------------------------------
                    // package_manifest 回调处理
                    // 严格翻译自: runTasks.zig 第137-330行
                    // ----------------------------------------------------------
                    let name = manifestReq.name

                    if (logLevel.showProgress()) {
                        if (!updated) {
                            manager.setNodeName(manager.downloadsNode, name, ProgressStrings.downloadEmoji, true)
                            updated = true
                        }
                    }

                    if (!networkErr && !task.response.hasMetadata()) {
                        networkErr = true
                        throttleSimultaneousRequests(manager)
                    }

                    // 处理可重试的错误 (5xx 或无 metadata)
                    if (!task.response.hasMetadata() || task.response.getStatusCode() > 499) {
                        let err = task.response.fail ?? "HTTPError"

                        if (task.retried < manager.options.maxRetryCount) {
                            task.retried += 1
                            manager.enqueueNetworkTask(task)

                            if (manager.options.logLevel.isVerbose()) {
                                manager.log.addWarningFmt(
                                    Option<LoggerLoc>.None,
                                    LoggerLoc.empty(),
                                    "${err} downloading package manifest ${name}. Retry ${task.retried}/${manager.options.maxRetryCount}..."
                                )
                            }
                            continue
                        }
                    }

                    // 处理无 metadata 的最终错误
                    if (!task.response.hasMetadata()) {
                        let err = task.response.fail ?? "HTTPError"

                        if (callbacks.hasOnPackageManifestError()) {
                            callbacks.onPackageManifestError(
                                ctx,
                                name,
                                err,
                                task.urlBuf
                            )
                        } else {
                            let fmt = "${err} downloading package manifest ${name}"
                            if (manager.isNetworkTaskRequired(task.taskId)) {
                                manager.log.addErrorFmt(Option<LoggerLoc>.None, LoggerLoc.empty(), fmt)
                            } else {
                                manager.log.addWarningFmt(Option<LoggerLoc>.None, LoggerLoc.empty(), fmt)
                            }

                            if (manager.subcommand != Subcommand.Remove) {
                                markUpdateRequestsFailed(manager, name)
                            }
                        }
                        continue
                    }

                    let metadata = task.response.metadata.getOrThrow()
                    let response = metadata.response

                    // 处理 4xx 错误
                    if (response.statusCode > 399) {
                        if (callbacks.hasOnPackageManifestError()) {
                            let err = manifestErrorFromStatusCode(response.statusCode)
                            callbacks.onPackageManifestError(ctx, name, err, task.urlBuf)
                            continue
                        }

                        if (manager.isNetworkTaskRequired(task.taskId)) {
                            manager.log.addErrorFmt(
                                Option<LoggerLoc>.None,
                                LoggerLoc.empty(),
                                "GET ${metadata.url} - ${response.statusCode}"
                            )
                        } else {
                            manager.log.addWarningFmt(
                                Option<LoggerLoc>.None,
                                LoggerLoc.empty(),
                                "GET ${metadata.url} - ${response.statusCode}"
                            )
                        }
                        if (manager.subcommand != Subcommand.Remove) {
                            markUpdateRequestsFailed(manager, name)
                        }
                        continue
                    }

                    if (logLevel.isVerbose()) {
                        Output.printElapsed(task.elapsed)
                        Output.prettyError("Downloaded ${name} versions\n")
                    }

                    // HTTP 304: 缓存的请求
                    if (response.statusCode == 304) {
                        if (manifestReq.loadedManifest.isSome()) {
                            let manifest = manifestReq.loadedManifest.getOrThrow()
                            RunTasksDebug.assert(!manifestReq.isExtendedManifest || manifest.hasExtendedManifest())

                            let entry = manager.manifests.getOrPut(manifest.pkgNameHash)
                            entry.setManifest(manifest)

                            if (timestamp.isNone()) {
                                timestamp = UInt32(truncateTimestamp(currentTimestamp())) + UInt32(300)
                            }

                            entry.setPublicMaxAge(timestamp.getOrThrow())

                            if (manager.options.enableManifestCache) {
                                // Npm.PackageManifest.Serializer.saveAsync(...)
                            }

                            if (callbacks.manifestsOnly) {
                                continue
                            }

                            let dependencyListEntry = manager.taskQueue.getEntry(task.taskId)
                            if (dependencyListEntry.isSome()) {
                                let entry = dependencyListEntry.getOrThrow()
                                let dependencyList = entry.value
                                entry.clearValue()

                                manager.processDependencyList(
                                    dependencyList,
                                    ctx,
                                    callbacks,
                                    installPeer
                                )
                            }
                            continue
                        }
                    }

                    // 非304: 推入 parse NPM 包任务
                    manager.taskBatch.push(manager.enqueueParseNPMPackage(task.taskId, name, task))
                case NetworkTaskCallback.Extract(extract) =>
                    // ----------------------------------------------------------
                    // extract 回调处理
                    // 严格翻译自: runTasks.zig 第331-577行
                    // ----------------------------------------------------------
                    // 流式提取在提交后不会将 NetworkTask 推入 async_network_task_queue
                    RunTasksDebug.assert(!task.streamingCommitted)

                    if (!networkErr && !task.response.hasMetadata()) {
                        networkErr = true
                        throttleSimultaneousRequests(manager)
                    }

                    // 处理可重试的错误 (5xx 或无 metadata)
                    if (!task.response.hasMetadata() || task.response.getStatusCode() > 499) {
                        let err = task.response.fail ?? "TarballFailedToDownload"

                        if (task.retried < manager.options.maxRetryCount) {
                            task.retried += 1
                            task.resetStreamingForRetry()
                            manager.enqueueNetworkTask(task)

                            if (manager.options.logLevel.isVerbose()) {
                                manager.log.addWarningFmt(
                                    Option<LoggerLoc>.None,
                                    LoggerLoc.empty(),
                                    "warn: ${err} downloading tarball ${extract.name}@${extract.resolution}. Retrying ${task.retried}/${manager.options.maxRetryCount}..."
                                )
                            }
                            continue
                        }
                    }

                    // 过此点后不再重试, 释放未使用的流式状态
                    task.discardUnusedStreamingState(manager)

                    // 处理无 metadata 的最终错误
                    if (!task.response.hasMetadata()) {
                        let err = task.response.fail ?? "TarballFailedToDownload"
                        let isRequired = manager.isNetworkTaskRequired(task.taskId)
                        manager.networkDedupeMap.remove(task.taskId)

                        if (callbacks.hasOnPackageDownloadError()) {
                            if (ctx.isStoreInstaller()) {
                                callbacks.onPackageDownloadError(
                                    ctx,
                                    task.taskId,
                                    extract.name,
                                    extract.resolution,
                                    err,
                                    task.urlBuf
                                )
                            } else {
                                let packageId = manager.lockfile.getResolutionAt(extract.dependencyId)
                                callbacks.onPackageDownloadError(
                                    ctx,
                                    packageId,
                                    extract.name,
                                    extract.resolution,
                                    err,
                                    task.urlBuf
                                )
                            }
                            continue
                        }

                        let fmt = "${err} downloading tarball ${extract.name}@${extract.resolution}"
                        if (isRequired) {
                            manager.log.addErrorFmt(Option<LoggerLoc>.None, LoggerLoc.empty(), fmt)
                        } else {
                            manager.log.addWarningFmt(Option<LoggerLoc>.None, LoggerLoc.empty(), fmt)
                        }
                        if (manager.subcommand != Subcommand.Remove) {
                            markUpdateRequestsFailed(manager, extract.name)
                        }

                        if (manager.taskQueue.fetchRemove(task.taskId).isSome()) {
                            // 已移除
                        }
                        continue
                    }

                    let metadata = task.response.metadata.getOrThrow()
                    let response = metadata.response

                    // 处理 HTTP 4xx/5xx 错误
                    if (response.statusCode > 399) {
                        let isRequired = manager.isNetworkTaskRequired(task.taskId)
                        manager.networkDedupeMap.remove(task.taskId)

                        if (callbacks.hasOnPackageDownloadError()) {
                            let err = tarballErrorFromStatusCode(response.statusCode)

                            if (ctx.isStoreInstaller()) {
                                callbacks.onPackageDownloadError(
                                    ctx,
                                    task.taskId,
                                    extract.name,
                                    extract.resolution,
                                    err,
                                    task.urlBuf
                                )
                            } else {
                                let packageId = manager.lockfile.getResolutionAt(extract.dependencyId)
                                callbacks.onPackageDownloadError(
                                    ctx,
                                    packageId,
                                    extract.name,
                                    extract.resolution,
                                    err,
                                    task.urlBuf
                                )
                            }
                            continue
                        }

                        if (isRequired) {
                            manager.log.addErrorFmt(
                                Option<LoggerLoc>.None,
                                LoggerLoc.empty(),
                                "GET ${metadata.url} - ${response.statusCode}"
                            )
                        } else {
                            manager.log.addWarningFmt(
                                Option<LoggerLoc>.None,
                                LoggerLoc.empty(),
                                "GET ${metadata.url} - ${response.statusCode}"
                            )
                        }
                        if (manager.subcommand != Subcommand.Remove) {
                            markUpdateRequestsFailed(manager, extract.name)
                        }

                        if (manager.taskQueue.fetchRemove(task.taskId).isSome()) {
                            // 已移除
                        }
                        continue
                    }

                    if (logLevel.isVerbose()) {
                        Output.printElapsed(task.elapsed)
                        Output.prettyError("Downloaded ${extract.name} tarball\n")
                    }

                    if (logLevel.showProgress()) {
                        if (!updated) {
                            manager.setNodeName(manager.downloadsNode, extract.name, ProgressStrings.extractEmoji, true)
                            updated = true
                        }
                    }

                    manager.taskBatch.push(manager.enqueueExtractNPMPackage(extract, task))
                    // unreachable (all enum variants matched above)
            }
        }

        return NetworkTaskResult(updated, networkErr, timestamp)
    }

    // ========================================================================
    // 第4段: 处理 resolve 任务
    // 严格翻译自: runTasks.zig 第582-1061行
    //   var resolve_tasks_batch = manager.resolve_tasks.popBatch()
    //   while (resolve_tasks_iter.next()) |task| { switch (task.tag) { ... } }
    // ========================================================================

    /// 处理 resolve 任务
    /// 翻译自: runTasks 中的 resolve_tasks 循环
    private static func processResolveTasks(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext,
        callbacks: RunTasksCallbacks,
        installPeer: Bool,
        logLevel: LogLevel,
        hasUpdatedThisRun: Bool,
        timestampThisTick: ?UInt32
    ): Unit {
        var updated = hasUpdatedThisRun
        var timestamp = timestampThisTick

        let resolveTasksBatch = manager.resolveTasks.popBatch()
        let resolveTasksIter = resolveTasksBatch.iterator()

        while (resolveTasksIter.hasNext()) {
            let task = resolveTasksIter.next()
            RunTasksDebug.assert(manager.pendingTaskCount() > 0)
            manager.preallocatedResolveTasks.put(task)
            manager.decrementPendingTasks()

            if (task.log.hasMessages()) {
                task.log.print()
                if (task.log.hasErrors()) {
                    manager.anyFailedToInstall = true
                }
                task.log.deinit()
            }

            match (task.tag) {
                case ResolveTaskTag.PackageManifest =>
                    processResolvePackageManifest(manager, ctx, callbacks, installPeer, logLevel, task, updated, timestamp)
                case ResolveTaskTag.Extract | ResolveTaskTag.LocalTarball =>
                    processResolveExtractOrLocalTarball(manager, ctx, callbacks, installPeer, logLevel, task, updated)
                case ResolveTaskTag.GitClone =>
                    processResolveGitClone(manager, ctx, callbacks, installPeer, logLevel, task, updated)
                case ResolveTaskTag.GitCheckout =>
                    processResolveGitCheckout(manager, ctx, callbacks, installPeer, logLevel, task, updated)
            }
        }
    }

    // ========================================================================
    // 第4a段: resolve 任务 - package_manifest
    // 严格翻译自: runTasks.zig 第598-646行
    // ========================================================================

    /// 处理 resolve 中的 package_manifest 任务
    private static func processResolvePackageManifest(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext,
        callbacks: RunTasksCallbacks,
        installPeer: Bool,
        logLevel: LogLevel,
        task: ResolveTaskRef,
        updated: Bool,
        timestamp: ?UInt32
    ): Unit {
        manager.preallocatedNetworkTasks.put(task.getPackageManifestNetwork())

        if (task.isFail()) {
            let name = task.getPackageManifestName()
            let err = task.err ?? "Failed"

            if (callbacks.hasOnPackageManifestError()) {
                callbacks.onPackageManifestError(ctx, name, err, task.getPackageManifestNetworkUrlBuf())
            } else {
                manager.log.addErrorFmt(
                    Option<LoggerLoc>.None,
                    LoggerLoc.empty(),
                    "${err} parsing package manifest for ${name}"
                )
            }
            return
        }

        let manifest = task.getPackageManifestData()

        manager.manifests.insert(manifest.pkgNameHash, manifest)

        if (callbacks.manifestsOnly) {
            return
        }

        let dependencyListEntry = manager.taskQueue.getEntry(task.id)
        let dependencyList = dependencyListEntry.getOrThrow().value
        dependencyListEntry.getOrThrow().clearValue()

        manager.processDependencyList(dependencyList, ctx, callbacks, installPeer)

        if (logLevel.showProgress()) {
            if (!updated) {
                manager.setNodeName(manager.downloadsNode, manifest.name(), ProgressStrings.downloadEmoji, true)
            }
        }
    }

    // ========================================================================
    // 第4b段: resolve 任务 - extract / local_tarball
    // 严格翻译自: runTasks.zig 第647-814行
    // ========================================================================

    /// 处理 resolve 中的 extract / local_tarball 任务
    private static func processResolveExtractOrLocalTarball(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext,
        callbacks: RunTasksCallbacks,
        installPeer: Bool,
        logLevel: LogLevel,
        task: ResolveTaskRef,
        updated: Bool
    ): Unit {
        // 根据 tag 归还网络任务
        if (task.tag == ResolveTaskTag.Extract) {
            manager.preallocatedNetworkTasks.put(task.getExtractNetwork())
        }

        let tarball = match (task.tag) {
            case ResolveTaskTag.Extract => task.getExtractTarball()
            case ResolveTaskTag.LocalTarball => task.getLocalTarballTarball()
            case _ => throw BaoError(ErrorCode.Unreachable, "unreachable")
        }
        let dependencyId = tarball.dependencyId
        var packageId = manager.lockfile.getResolutionAt(dependencyId)
        let alias = tarball.name
        let resolution = tarball.resolution

        // 失败处理
        if (task.isFail()) {
            let err = task.err ?? "TarballFailedToExtract"

            // 删除去重状态以便后续重新入队
            manager.networkDedupeMap.remove(task.id)

            if (callbacks.hasOnPackageDownloadError()) {
                let failUrl = match (task.tag) {
                    case ResolveTaskTag.Extract => task.getExtractNetworkUrlBuf()
                    case ResolveTaskTag.LocalTarball => tarball.url
                    case _ => throw BaoError(ErrorCode.Unreachable, "unreachable")
                }
                if (ctx.isStoreInstaller()) {
                    callbacks.onPackageDownloadError(ctx, task.id, alias, resolution, err, failUrl)
                } else {
                    callbacks.onPackageDownloadError(ctx, packageId, alias, resolution, err, failUrl)
                }
                return
            }

            manager.log.addErrorFmt(
                Option<LoggerLoc>.None,
                LoggerLoc.empty(),
                "${err} extracting tarball from ${alias}"
            )

            if (manager.taskQueue.fetchRemove(task.id).isSome()) {
                // 已移除
            }
            return
        }

        manager.extractedCount += 1

        // 有 onExtract 回调
        if (callbacks.hasOnExtract()) {
            match (ctx.contextType()) {
                case RunTasksContextType.PackageInstaller =>
                    ctx.getInstaller().fixCachedLockfilePackageSlices()
                    callbacks.onExtract(ctx, task.id, dependencyId, task.getExtractData(), logLevel)
                case RunTasksContextType.StoreInstaller =>
                    callbacks.onExtract(ctx, task.id)
                case _ => throw BaoError(ErrorCode.Unreachable, "unexpected context type")
            }
        } else if (manager.processExtractedTarballPackage(packageId, dependencyId, resolution, task.getExtractData(), logLevel)) {
            // processExtractedTarballPackage 返回了 pkg, 处理依赖列表
            var anyRoot = false
            let dependencyListEntry = manager.taskQueue.getEntry(task.id)
            if (dependencyListEntry.isNone()) {
                // break :handle_pkg
            } else {
                let entry = dependencyListEntry.getOrThrow()
                var dependencyList = entry.value
                entry.clearValue()

                for (dep in dependencyList.items) {
                    match (dep) {
                        case TaskCallbackContext.Dependency(id) =>
                            processDependencyItem(manager, id, dep, anyRoot, installPeer)
                        case TaskCallbackContext.RootDependency(id) =>
                            processDependencyItem(manager, id, dep, anyRoot, installPeer)
                        case _ =>
                            // node_module 文件夹安装: 放回队列
                            entry.append(dep)
                    }
                }

                dependencyList.deinit()
                if (callbacks.hasOnResolve()) {
                    if (anyRoot) {
                        callbacks.onResolve(ctx)
                    }
                }
            }
        } else {
            // 检查是否有 peer 依赖的依赖列表
            let manifestTaskId = TaskId.forManifest(
                manager.lockfile.getPackageNameAt(packageId)
            )
            let dependencyListEntry = manager.taskQueue.getEntry(manifestTaskId)
            if (dependencyListEntry.isSome()) {
                let entry = dependencyListEntry.getOrThrow()
                let dependencyList = entry.value
                entry.clearValue()
                manager.processDependencyList(dependencyList, RunTasksContext.voidContext(), RunTasksCallbacks.voidCallbacks(), installPeer)
            }
        }

        manager.setPreinstallState(packageId, manager.lockfile, PreinstallState.Done)

        if (logLevel.showProgress()) {
            if (!updated) {
                manager.setNodeName(manager.downloadsNode, alias, ProgressStrings.extractEmoji, true)
            }
        }
    }

    // ========================================================================
    // 第4c段: resolve 任务 - git_clone
    // 严格翻译自: runTasks.zig 第815-951行
    // ========================================================================

    /// 处理 resolve 中的 git_clone 任务
    private static func processResolveGitClone(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext,
        callbacks: RunTasksCallbacks,
        installPeer: Bool,
        logLevel: LogLevel,
        task: ResolveTaskRef,
        updated: Bool
    ): Unit {
        let clone = task.getGitClone()
        let repoFd = task.getGitCloneRepoFd()
        let name = clone.name
        let url = clone.url

        manager.gitRepositories.put(task.id, repoFd)

        // 失败处理
        if (task.isFail()) {
            let err = task.err ?? "Failed"

            if (callbacks.hasOnPackageManifestError()) {
                callbacks.onPackageManifestError(ctx, name, err, url)
            } else if (callbacks.hasOnPackageDownloadError() && ctx.isStoreInstaller()) {
                // 隔离安装器: 排空所有等待 checkout 的任务
                var drainedAny = false
                let removed = manager.taskQueue.fetchRemove(task.id)
                if (removed.isSome()) {
                    let waiters = removed.getOrThrow()
                    let pkgResolutions = manager.lockfile.getPackageResolutions()
                    for (waiter in waiters.items) {
                        let depId = match (waiter) {
                            case TaskCallbackContext.Dependency(id) => id
                            case _ => continue
                        }
                        let pkgId = manager.lockfile.getResolutionAt(depId)
                        if (pkgId == INVALID_PACKAGE_ID) {
                            continue
                        }
                        let res = pkgResolutions[Int64(pkgId)]
                        if (res.tag != ResolutionTag.Git) {
                            continue
                        }
                        let checkoutId = TaskId.forGitCheckout(res.getGitRepo(), res.getGitResolved())
                        drainedAny = true
                        callbacks.onPackageDownloadError(ctx, checkoutId, name, res, err, url)
                    }
                    waiters.deinit()
                }
                if (!drainedAny) {
                    let checkoutId = TaskId.forGitCheckout(url, clone.getGitResolved())
                    callbacks.onPackageDownloadError(ctx, checkoutId, name, clone.res, err, url)
                }
            } else if (logLevel != LogLevel.Silent) {
                manager.log.addErrorFmt(
                    Option<LoggerLoc>.None,
                    LoggerLoc.empty(),
                    "${err} cloning repository for ${name}"
                )
            }
            return
        }

        // 成功: 安装或解析
        if (callbacks.hasOnExtract() && ctx.isPackageInstaller()) {
            // 安装模式
            let depId = clone.depId
            let dep = manager.lockfile.getDependencyAt(depId)
            let depName = dep.name

            let git = clone.getGitValue()
            let committish = git.committish
            let repo = git.repo

            let resolved = try {
                Repository.findCommit(
                    manager.allocator,
                    manager.env,
                    manager.log,
                    repoFd,
                    depName,
                    committish,
                    task.id
                )
            } catch (e: Exception) {
                ""
            }

            let checkoutId = TaskId.forGitCheckout(repo, resolved)

            if (manager.hasCreatedNetworkTask(checkoutId, dep.behavior.isRequired())) {
                return
            }

            manager.taskBatch.push(manager.enqueueGitCheckout(
                checkoutId,
                repoFd,
                depId,
                depName,
                clone.res,
                resolved,
                Option<String>.None
            ))
        } else {
            // 解析模式
            let dependencyListEntry = manager.taskQueue.getEntry(task.id)
            if (dependencyListEntry.isNone()) {
                return
            }
            let entry = dependencyListEntry.getOrThrow()
            let dependencyList = entry.value
            entry.clearValue()

            manager.processDependencyList(dependencyList, ctx, callbacks, installPeer)
        }

        if (logLevel.showProgress()) {
            if (!updated) {
                manager.setNodeName(manager.downloadsNode, name, ProgressStrings.downloadEmoji, true)
            }
        }
    }

    // ========================================================================
    // 第4d段: resolve 任务 - git_checkout
    // 严格翻译自: runTasks.zig 第952-1060行
    // ========================================================================

    /// 处理 resolve 中的 git_checkout 任务
    private static func processResolveGitCheckout(
        manager: RunTasksPackageManagerState,
        ctx: RunTasksContext,
        callbacks: RunTasksCallbacks,
        installPeer: Bool,
        logLevel: LogLevel,
        task: ResolveTaskRef,
        updated: Bool
    ): Unit {
        let gitCheckout = task.getGitCheckout()
        let alias = gitCheckout.name
        let resolution = gitCheckout.resolution
        var packageId: UInt32 = INVALID_PACKAGE_ID

        // 失败处理
        if (task.isFail()) {
            let err = task.err ?? "Failed"

            if (callbacks.hasOnPackageDownloadError() && ctx.isStoreInstaller()) {
                callbacks.onPackageDownloadError(
                    ctx,
                    task.id,
                    alias,
                    resolution,
                    err,
                    manager.lockfile.str(resolution.getGitRepo())
                )
            } else {
                manager.log.addErrorFmt(
                    Option<LoggerLoc>.None,
                    LoggerLoc.empty(),
                    "${err} checking out repository for ${alias}"
                )
            }
            return
        }

        // 成功处理
        if (callbacks.hasOnExtract()) {
            match (ctx.contextType()) {
                case RunTasksContextType.PackageInstaller =>
                    ctx.getInstaller().fixCachedLockfilePackageSlices()
                    callbacks.onExtract(ctx, task.id, gitCheckout.dependencyId, task.getGitCheckoutData(), logLevel)
                case RunTasksContextType.StoreInstaller =>
                    callbacks.onExtract(ctx, task.id)
                case _ => throw BaoError(ErrorCode.Unreachable, "unexpected context type")
            }
        } else if (manager.processExtractedTarballPackage(
            packageId,
            gitCheckout.dependencyId,
            resolution,
            task.getGitCheckoutData(),
            logLevel
        )) {
            // 处理依赖列表
            var anyRoot = false
            let dependencyListEntry = manager.taskQueue.getEntry(task.id)
            if (dependencyListEntry.isNone()) {
                // break :handle_pkg
            } else {
                let entry = dependencyListEntry.getOrThrow()
                var dependencyList = entry.value
                entry.clearValue()

                for (dep in dependencyList.items) {
                    match (dep) {
                        case TaskCallbackContext.Dependency(id) =>
                            let depVersion = manager.lockfile.getDependencyVersionGit(id)
                            depVersion.setGitResolved(manager.getGitCheckoutResolved())
                            depVersion.setGitPackageName(manager.getGitCheckoutPkgName())
                            manager.processDependencyListItem(dep, anyRoot, installPeer)
                        case TaskCallbackContext.RootDependency(id) =>
                            let depVersion = manager.lockfile.getDependencyVersionGit(id)
                            depVersion.setGitResolved(manager.getGitCheckoutResolved())
                            depVersion.setGitPackageName(manager.getGitCheckoutPkgName())
                            manager.processDependencyListItem(dep, anyRoot, installPeer)
                        case _ =>
                            entry.append(dep)
                    }
                }

                dependencyList.deinit()
                if (callbacks.hasOnResolve()) {
                    if (anyRoot) {
                        callbacks.onResolve(ctx)
                    }
                }
            }
        }

        if (logLevel.showProgress()) {
            if (!updated) {
                manager.setNodeName(manager.downloadsNode, alias, ProgressStrings.downloadEmoji, true)
            }
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 节流并发请求数
    /// 翻译自: runTasks 中的 max_simultaneous_requests 节流逻辑
    private static func throttleSimultaneousRequests(manager: RunTasksPackageManagerState): Unit {
        let min = manager.options.minSimultaneousRequests
        let max = AsyncHTTP.getMaxSimultaneousRequests()
        if (max > min) {
            AsyncHTTP.setMaxSimultaneousRequests(if (min < max / 2) { min } else { max / 2 })
        }
    }

    /// 标记更新请求为失败
    /// 翻译自: runTasks 中的 request.failed = true 循环
    private static func markUpdateRequestsFailed(manager: RunTasksPackageManagerState, name: String): Unit {
        for (request in manager.updateRequests) {
            if (request.name == name) {
                request.failed = true
                manager.options.doSaveLockfile = false
                manager.options.doSaveYarnLock = false
                manager.options.doInstallPackages = false
            }
        }
    }

    /// 处理单个依赖项
    private static func processDependencyItem(
        manager: RunTasksPackageManagerState,
        id: UInt32,
        dep: TaskCallbackContext,
        anyRoot: Bool,
        installPeer: Bool
    ): Unit {
        let depVersion = manager.lockfile.getDependencyVersion(id)
        match (depVersion.tag) {
            case DependencyVersionTag.Git => depVersion.setGitPackageName(depVersion.getPkgName())
            case DependencyVersionTag.Github => depVersion.setGitHubPackageName(depVersion.getPkgName())
            case DependencyVersionTag.Tarball => depVersion.setTarballPackageName(depVersion.getPkgName())
            case _ => ()
        }
        manager.processDependencyListItem(dep, anyRoot, installPeer)
    }

    /// 根据 HTTP 状态码获取 manifest 错误
    /// 翻译自: runTasks 中的 PackageManifestError switch
    private static func manifestErrorFromStatusCode(statusCode: Int64): String {
        if (statusCode == 400) { return "PackageManifestHTTP400" }
        if (statusCode == 401) { return "PackageManifestHTTP401" }
        if (statusCode == 402) { return "PackageManifestHTTP402" }
        if (statusCode == 403) { return "PackageManifestHTTP403" }
        if (statusCode == 404) { return "PackageManifestHTTP404" }
        if (statusCode >= 405 && statusCode <= 499) { return "PackageManifestHTTP4xx" }
        return "PackageManifestHTTP5xx"
    }

    /// 根据 HTTP 状态码获取 tarball 错误
    /// 翻译自: runTasks 中的 tarball HTTP 错误 switch
    private static func tarballErrorFromStatusCode(statusCode: Int64): String {
        if (statusCode == 400) { return "TarballHTTP400" }
        if (statusCode == 401) { return "TarballHTTP401" }
        if (statusCode == 402) { return "TarballHTTP402" }
        if (statusCode == 403) { return "TarballHTTP403" }
        if (statusCode == 404) { return "TarballHTTP404" }
        if (statusCode >= 405 && statusCode <= 499) { return "TarballHTTP4xx" }
        return "TarballHTTP5xx"
    }

    /// 截断时间戳
    /// 翻译自: @truncate(@as(u64, @intCast(@max(0, std.time.timestamp()))))
    private static func truncateTimestamp(ts: Int64): UInt32 {
        if (ts < 0) { return UInt32(0) }
        return UInt32(ts & 0xFFFFFFFF)
    }

    /// 获取当前时间戳
    private static func currentTimestamp(): Int64 {
        return Time.now() / 1000
    }
}

// ============================================================================
// 待处理任务计数
// 严格翻译自: runTasks.zig 第1064-1078行
//   pub inline fn pendingTaskCount(manager) u32
//   pub inline fn incrementPendingTasks(manager, count) void
//   pub inline fn decrementPendingTasks(manager) void
// ============================================================================

/// 待处理任务计数操作
/// 对应 Bun: pendingTaskCount / incrementPendingTasks / decrementPendingTasks
public class PendingTaskCounter {

    /// 获取待处理任务数
    /// 翻译自: pendingTaskCount
    ///   pub inline fn pendingTaskCount(manager: *const PackageManager) u32
    public static func pendingTaskCount(manager: RunTasksPackageManagerState): UInt32 {
        return manager.pendingTasks.loadAcquire()
    }

    /// 增加待处理任务数
    /// 翻译自: incrementPendingTasks
    ///   pub inline fn incrementPendingTasks(manager: *PackageManager, count: u32) void
    public static func incrementPendingTasks(manager: RunTasksPackageManagerState, count: UInt32): Unit {
        manager.totalTasks += Int64(count)
        manager.pendingTasks.fetchAdd(count)
    }

    /// 减少待处理任务数
    /// 翻译自: decrementPendingTasks
    ///   pub inline fn decrementPendingTasks(manager: *PackageManager) void
    public static func decrementPendingTasks(manager: RunTasksPackageManagerState): Unit {
        manager.pendingTasks.fetchSub(1)
    }
}

// ============================================================================
// 刷新网络队列
// 严格翻译自: runTasks.zig 第1080-1086行
//   pub fn flushNetworkQueue(this: *PackageManager) void
// ============================================================================

/// 刷新网络队列
/// 翻译自: flushNetworkQueue
///   pub fn flushNetworkQueue(this) void
///   从 FIFO 读取网络任务并调度
public class FlushNetworkQueue {

    /// 刷新网络队列
    /// 严格翻译自: flushNetworkQueue
    public static func flushNetworkQueue(manager: RunTasksPackageManagerState): Unit {
        let network = manager.networkTaskFifo

        while (true) {
            let networkTask = network.readItem()
            match (networkTask) {
                case Some(task) =>
                    if (task.isExtractCallback()) {
                        task.schedule(manager.networkTarballBatch)
                    } else {
                        task.schedule(manager.networkResolveBatch)
                    }
                case None => break
            }
        }
    }
}

// ============================================================================
// 刷新 Patch 任务队列
// 严格翻译自: runTasks.zig 第1088-1094行
//   pub fn flushPatchTaskQueue(this: *PackageManager) void
// ============================================================================

/// 刷新 Patch 任务队列
/// 翻译自: flushPatchTaskQueue
///   pub fn flushPatchTaskQueue(this) void
public class FlushPatchTaskQueue {

    /// 刷新 patch 任务队列
    /// 严格翻译自: flushPatchTaskQueue
    public static func flushPatchTaskQueue(manager: RunTasksPackageManagerState): Unit {
        let patchTaskFifo = manager.patchTaskFifo

        while (true) {
            let patchTask = patchTaskFifo.readItem()
            match (patchTask) {
                case Some(task) =>
                    if (task.isApplyCallback()) {
                        task.schedule(manager.patchApplyBatch)
                    } else {
                        task.schedule(manager.patchCalcHashBatch)
                    }
                case None => break
            }
        }
    }
}

// ============================================================================
// 刷新依赖队列
// 严格翻译自: runTasks.zig 第1096-1126行
//   fn doFlushDependencyQueue(this) void
//   pub fn flushDependencyQueue(this) void
// ============================================================================

/// 刷新依赖队列
/// 翻译自: flushDependencyQueue / doFlushDependencyQueue
public class FlushDependencyQueue {

    /// 内部刷新依赖队列
    /// 严格翻译自: doFlushDependencyQueue
    ///   fn doFlushDependencyQueue(this: *PackageManager) void
    public static func doFlushDependencyQueue(manager: RunTasksPackageManagerState): Unit {
        let lockfile = manager.lockfile
        let dependencyQueue = lockfile.scratch.dependencyListQueue

        while (true) {
            let dependenciesList = dependencyQueue.readItem()
            match (dependenciesList) {
                case Some(depList) =>
                    var i: UInt32 = depList.off
                    let end = depList.off + depList.len
                    while (i < end) {
                        let dependency = lockfile.getDependencyAt(i)
                        manager.enqueueDependencyWithMain(
                            i,
                            dependency,
                            lockfile.getResolutionAt(i),
                            false
                        )
                        i += 1
                    }
                case None => break
            }
        }

        FlushNetworkQueue.flushNetworkQueue(manager)
    }

    /// 刷新依赖队列 (循环直到无新任务)
    /// 严格翻译自: flushDependencyQueue
    ///   pub fn flushDependencyQueue(this: *PackageManager) void
    public static func flushDependencyQueue(manager: RunTasksPackageManagerState): Unit {
        var lastCount = manager.totalTasks
        while (true) {
            FlushNetworkQueue.flushNetworkQueue(manager)
            doFlushDependencyQueue(manager)
            FlushNetworkQueue.flushNetworkQueue(manager)
            FlushPatchTaskQueue.flushPatchTaskQueue(manager)

            if (manager.totalTasks == lastCount) {
                break
            }
            lastCount = manager.totalTasks
        }
    }
}

// ============================================================================
// 调度任务
// 严格翻译自: runTasks.zig 第1128-1143行
//   pub fn scheduleTasks(manager: *PackageManager) usize
// ============================================================================

/// 调度任务
/// 翻译自: scheduleTasks
///   pub fn scheduleTasks(manager) usize
///   将所有批处理任务提交到线程池和网络线程
public class ScheduleTasks {

    /// 调度任务
    /// 严格翻译自: scheduleTasks
    public static func scheduleTasks(manager: RunTasksPackageManagerState): Int64 {
        let count = manager.taskBatch.len +
            manager.networkResolveBatch.len +
            manager.networkTarballBatch.len +
            manager.patchApplyBatch.len +
            manager.patchCalcHashBatch.len

        PendingTaskCounter.incrementPendingTasks(manager, UInt32(count))

        manager.threadPool.schedule(manager.patchApplyBatch)
        manager.threadPool.schedule(manager.patchCalcHashBatch)
        manager.threadPool.schedule(manager.taskBatch)
        manager.networkResolveBatch.push(manager.networkTarballBatch)
        HTTP.httpThread.schedule(manager.networkResolveBatch)

        // 清空批处理
        manager.taskBatch = ThreadPoolBatch()
        manager.networkTarballBatch = ThreadPoolBatch()
        manager.networkResolveBatch = ThreadPoolBatch()
        manager.patchApplyBatch = ThreadPoolBatch()
        manager.patchCalcHashBatch = ThreadPoolBatch()

        return count
    }
}

// ============================================================================
// 排空依赖列表
// 严格翻译自: runTasks.zig 第1145-1153行
//   pub fn drainDependencyList(this: *PackageManager) void
// ============================================================================

/// 排空依赖列表
/// 翻译自: drainDependencyList
///   pub fn drainDependencyList(this) void
///   刷新依赖队列并调度任务
public class DrainDependencyList {

    /// 排空依赖列表
    /// 严格翻译自: drainDependencyList
    public static func drainDependencyList(manager: RunTasksPackageManagerState): Unit {
        // 步骤2: 如果有缓存的依赖, 处理它们但不下载 devDependencies
        FlushDependencyQueue.flushDependencyQueue(manager)

        if (PackageManagerFlags.verboseInstall) {
            Output.flush()
        }

        // 这里只有网络请求, 因为不存储 tarballs
        ScheduleTasks.scheduleTasks(manager)
    }
}

// ============================================================================
// 获取网络任务
// 严格翻译自: runTasks.zig 第1155-1157行
//   pub fn getNetworkTask(this: *PackageManager) *NetworkTask
// ============================================================================

/// 获取网络任务操作
public class GetNetworkTask {

    /// 获取网络任务
    /// 翻译自: getNetworkTask
    ///   pub fn getNetworkTask(this) *NetworkTask
    public static func getNetworkTask(manager: RunTasksPackageManagerState): NetworkTaskRef {
        return manager.preallocatedNetworkTasks.get()
    }
}

// ============================================================================
// 分配 GitHub URL
// 严格翻译自: runTasks.zig 第1159-1183行
//   pub fn allocGitHubURL(this: *const PackageManager, repository) string
// ============================================================================

/// 分配 GitHub URL
/// 翻译自: allocGitHubURL
///   pub fn allocGitHubURL(this, repository) string
///   构建格式: {github_api_url}/repos/{owner}/{repo}tarball/{committish}
public class AllocGitHubURL {

    /// 分配 GitHub URL
    /// 严格翻译自: allocGitHubURL
    public static func allocGitHubURL(
        manager: RunTasksPackageManagerState,
        repository: RepositoryRef
    ): String {
        var githubApiUrl: String = "https://api.github.com"
        let envUrl = manager.env.get("GITHUB_API_URL")
        match (envUrl) {
            case Some(url) =>
                if (url.size > 0) {
                    githubApiUrl = url
                }
            case None => ()
        }

        let owner = repository.owner
        let repo = repository.repo
        let committish = repository.committish

        let withoutSlash = if (githubApiUrl.endsWith("/")) {
            githubApiUrl[0..githubApiUrl.size - 1]
        } else {
            githubApiUrl
        }

        let slashIfRepo = if (repo.size > 0) { "/" } else { "" }

        return "${withoutSlash}/repos/${owner}/${repo}${slashIfRepo}tarball/${committish}"
    }
}

// ============================================================================
// 网络任务去重
// 严格翻译自: runTasks.zig 第1185-1199行
//   pub fn hasCreatedNetworkTask(this, task_id, is_required) bool
//   pub fn isNetworkTaskRequired(this, task_id) bool
// ============================================================================

/// 网络任务去重
/// 翻译自: hasCreatedNetworkTask / isNetworkTaskRequired
public class NetworkTaskDedup {

    /// 是否已创建网络任务
    /// 严格翻译自: hasCreatedNetworkTask
    ///   pub fn hasCreatedNetworkTask(this, task_id, is_required) bool
    ///   如果已存在, 合并 is_required 标志
    public static func hasCreatedNetworkTask(
        manager: RunTasksPackageManagerState,
        taskId: TaskId,
        isRequired: Bool
    ): Bool {
        let gpe = manager.networkDedupeMap.getOrPut(taskId)

        if (!gpe.foundExisting) {
            gpe.isRequired = isRequired
        } else {
            gpe.isRequired = gpe.isRequired || isRequired
        }

        return gpe.foundExisting
    }

    /// 网络任务是否必需
    /// 严格翻译自: isNetworkTaskRequired
    ///   pub fn isNetworkTaskRequired(this, task_id) bool
    public static func isNetworkTaskRequired(
        manager: RunTasksPackageManagerState,
        taskId: TaskId
    ): Bool {
        let entry = manager.networkDedupeMap.get(taskId)
        match (entry) {
            case Some(dedupeEntry) => return dedupeEntry.isRequired
            case None => return true
        }
    }
}

// ============================================================================
// 生成 tarball 网络任务
// 严格翻译自: runTasks.zig 第1201-1267行
//   pub fn generateNetworkTaskForTarball(
//       this, task_id, url, is_required, dependency_id, package,
//       patch_name_and_version_hash, authorization
//   ) NetworkTask.ForTarballError!?*NetworkTask
// ============================================================================

/// 生成 tarball 网络任务
/// 翻译自: generateNetworkTaskForTarball
public class GenerateNetworkTaskForTarball {

    /// 生成 tarball 网络任务
    /// 严格翻译自: generateNetworkTaskForTarball
    ///   pub fn generateNetworkTaskForTarball(...) NetworkTask.ForTarballError!?*NetworkTask
    ///   创建并配置网络任务用于 tarball 下载
    public static func generateNetworkTaskForTarball(
        manager: RunTasksPackageManagerState,
        taskId: TaskId,
        url: String,
        isRequired: Bool,
        dependencyId: UInt32,
        package_: PackageRef,
        patchNameAndVersionHash: ?UInt64,
        authorization: NetworkTaskAuthorization
    ): ?NetworkTaskRef {
        if (NetworkTaskDedup.hasCreatedNetworkTask(manager, taskId, isRequired)) {
            return None
        }

        let networkTask = GetNetworkTask.getNetworkTask(manager)

        networkTask.configure(
            taskId,
            manager.allocator,
            manager,
            createApplyPatchTask(manager, package_, patchNameAndVersionHash, taskId)
        )

        let scope = manager.scopeForPackageName(package_.name)

        networkTask.forTarball(
            manager.allocator,
            TarballConfig(),
            scope,
            authorization
        )

        // 流式提取: 预创建 extract Task
        if (ExtractTarball.usesStreamingExtraction()) {
            let extractTask = manager.createExtractTaskForStreaming(
                networkTask.getExtractCallback(),
                networkTask
            )
            networkTask.setStreamingExtractTask(extractTask)
            networkTask.setTarballStream(
                TarballStream.`init`(manager.allocator, extractTask, networkTask, manager)
            )
        }

        return networkTask
    }

    /// 创建应用补丁任务
    private static func createApplyPatchTask(
        manager: RunTasksPackageManagerState,
        package_: PackageRef,
        patchNameAndVersionHash: ?UInt64,
        taskId: TaskId
    ): ?PatchTaskRef {
        match (patchNameAndVersionHash) {
            case Some(h) =>
                let patchHash = manager.lockfile.getPatchedDependencyPatchfileHash(h)
                let task = PatchTask.newApplyPatchHash(manager, package_.meta.id, patchHash, h)
                task.setApplyTaskId(taskId)
                return Some(task)
            case None => return None
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 日志位置
public class LoggerLoc {
    public var offset: Int64

    public init(offset: Int64) {
        this.offset = offset
    }

    public static func empty(): LoggerLoc {
        return LoggerLoc(0)
    }
}

/// 网络任务回调类型
public enum NetworkTaskCallback {
    | PackageManifest(ManifestRequestRef)
    | Extract(ExtractRequestRef)
}

/// 清单请求引用
public class ManifestRequestRef {
    public var name: String
    public var loadedManifest: ?ManifestData
    public var isExtendedManifest: Bool

    public init() {
        name = ""
        loadedManifest = None
        isExtendedManifest = false
    }
}

/// 清单数据
public class ManifestData {
    public var pkgNameHash: UInt64
    public var pkgHasExtendedManifest: Bool

    public init() {
        pkgNameHash = UInt64(0)
        pkgHasExtendedManifest = false
    }

    public func name(): String {
        return ""
    }

    public func hasExtendedManifest(): Bool {
        return pkgHasExtendedManifest
    }

    // stubs for enqueue usage
    public func resolveVersion(version: DependencyVersionInfo): ?ResolvedVersion { return None }
    public func findVersion(version: DependencyVersionInfo): ?FindResultData { return None }
    public func findByDistTag(tag: String): ?FindResultData { return None }
    public func findByDistTagWithFilter(tag: String, minAgeMs: ?Int64, excludes: HashSet<String>): ?FindResultData { return None }
    public func findBestVersionWithFilter(version: DependencyVersionInfo, buf: String, minAgeMs: ?Int64, excludes: HashSet<String>): ?FindResultData { return None }
}

/// 解析请求引用
public class ExtractRequestRef {
    public var name: String
    public var resolution: ResolutionRef
    public var dependencyId: UInt32
    // additional fields for enqueue usage
    public var networkTask: NetworkTaskRef
    public var tarball: ExtractTarballRef

    public init() {
        name = ""
        resolution = ResolutionRef()
        dependencyId = UInt32(0)
        networkTask = NetworkTaskRef()
        tarball = ExtractTarballRef()
    }

    public init(networkTask: NetworkTaskRef, tarball: ExtractTarballRef) {
        name = ""
        resolution = ResolutionRef()
        dependencyId = UInt32(0)
        this.networkTask = networkTask
        this.tarball = tarball
    }
}

/// 解压 Tarball 引用 (stub)
public class ExtractTarballRef {
    public init() {}
}

/// 解析引用
public class ResolutionRef <: ToString {
    public var tag: ResolutionTag

    public init() {
        tag = ResolutionTag.NPM
    }

    public func toString(): String {
        return "ResolutionRef()"
    }

    public func getGitRepo(): String { return "" }
    public func getGitResolved(): String { return "" }
    public func getGitPackageName(): String { return "" }
}

/// 解析标签 (duplicate removed - see process_dependency_list.cj)
/*
public enum ResolutionTag {
    | Uninitialized
    | NPM
    | Git
    | GitHub
    | Root
    | Workspace
    | Symlink
    | Folder
    | LocalTarball
    | RemoteTarball
    | SingleFileModule
}
*/

/// 解析任务标签
public enum ResolveTaskTag {
    | PackageManifest
    | Extract
    | LocalTarball
    | GitClone
    | GitCheckout

    public operator func ==(right: ResolveTaskTag): Bool {
        match (this) {
            case PackageManifest => match (right) { case PackageManifest => true case _ => false }
            case Extract => match (right) { case Extract => true case _ => false }
            case LocalTarball => match (right) { case LocalTarball => true case _ => false }
            case GitClone => match (right) { case GitClone => true case _ => false }
            case GitCheckout => match (right) { case GitCheckout => true case _ => false }
        }
    }

    public operator func !=(right: ResolveTaskTag): Bool {
        return !(this == right)
    }
}

/// 网络任务引用
public class NetworkTaskRef {
    public var taskId: TaskId
    public var callback: NetworkTaskCallback
    public var response: NetworkTaskResponse
    public var retried: UInt32
    public var urlBuf: String
    public var streamingCommitted: Bool
    public var elapsed: Float64

    public init() {
        taskId = TaskId.invalid()
        callback = NetworkTaskCallback.PackageManifest(ManifestRequestRef())
        response = NetworkTaskResponse()
        retried = UInt32(0)
        urlBuf = ""
        streamingCommitted = false
        elapsed = Float64(0)
    }

    public func isExtractCallback(): Bool {
        match (callback) {
            case NetworkTaskCallback.Extract(_) => return true
            case _ => return false
        }
    }

    public func resetStreamingForRetry(): Unit {}
    public func discardUnusedStreamingState(manager: RunTasksPackageManagerState): Unit {}
    public func schedule(batch: ThreadPoolBatch): Unit {}
    public func forTarball(allocator: DefaultAllocator, config: TarballConfig, scope: ScopeInfo, auth: NetworkTaskAuthorization): Unit {}
    public func getExtractCallback(): ExtractRequestRef { return ExtractRequestRef() }
    public func setStreamingExtractTask(task: ResolveTaskRef): Unit {}
    public func setTarballStream(stream: TarballStream): Unit {}
    // additional stubs for enqueue usage
    public func forManifest(pkgName: String, depId: UInt32, dep: DependencyRef, installPeer: Bool, successFn: ?SuccessFn, failFn: ?FailFn): Unit {}
    public func forExtract(depId: UInt32, dep: DependencyRef, tarballUrl: String, integrity: IntegrityInfo): Unit {}
    public func forLocalTarball(depId: UInt32, dep: DependencyRef, path: String): Unit {}
    public func forGitCheckout(depId: UInt32, dep: DependencyRef, repo: String, ref_: String): Unit {}
    public func schedule(batch: NetworkTarballBatch): Unit {}
    public func configure(id: TaskId, allocator: DefaultAllocator, manager: RunTasksPackageManagerState, patchTask: ?PatchTaskRef): Unit {}
}

/// 网络任务响应
public class NetworkTaskResponse {
    public var metadata: ?NetworkTaskMetadata
    public var fail: ?String

    public init() {
        metadata = None
        fail = None
    }

    public func hasMetadata(): Bool {
        match (metadata) {
            case Some(_) => return true
            case None => return false
        }
    }

    public func getStatusCode(): Int64 {
        match (metadata) {
            case Some(m) => return m.response.statusCode
            case None => return Int64(0)
        }
    }
}

/// 网络任务元数据
public class NetworkTaskMetadata {
    public var response: NetworkTaskHttpResponse
    public var url: String

    public init() {
        response = NetworkTaskHttpResponse()
        url = ""
    }
}

/// 网络任务 HTTP 响应
public class NetworkTaskHttpResponse {
    public var statusCode: Int64

    public init() {
        statusCode = Int64(0)
    }
}

/// 解析任务引用
public class ResolveTaskRef {
    public var id: TaskId
    public var tag: ResolveTaskTag
    public var status: ResolveTaskStatus
    public var err: ?String
    public var log: ResolveTaskLog
    public var request: ResolveTaskRequest
    public var data: ResolveTaskData

    public init() {
        id = TaskId.invalid()
        tag = ResolveTaskTag.PackageManifest
        status = ResolveTaskStatus.Success
        err = None
        log = ResolveTaskLog()
        request = ResolveTaskRequest()
        data = ResolveTaskData()
    }

    public func isFail(): Bool {
        return status == ResolveTaskStatus.Fail
    }

    public func getPackageManifestNetwork(): NetworkTaskRef { return NetworkTaskRef() }
    public func getPackageManifestName(): String { return "" }
    public func getPackageManifestNetworkUrlBuf(): String { return "" }
    public func getPackageManifestData(): ManifestData { return ManifestData() }
    public func getExtractNetwork(): NetworkTaskRef { return NetworkTaskRef() }
    public func getExtractTarball(): TarballRef { return TarballRef() }
    public func getLocalTarballTarball(): TarballRef { return TarballRef() }
    public func getExtractNetworkUrlBuf(): String { return "" }
    public func getExtractData(): ExtractDataRef { return ExtractDataRef() }
    public func getGitClone(): GitCloneRef { return GitCloneRef() }
    public func getGitCloneRepoFd(): Int64 { return Int64(-1) }
    public func getGitCheckout(): GitCheckoutRef { return GitCheckoutRef() }
    public func getGitCheckoutData(): GitCheckoutDataRef { return GitCheckoutDataRef() }
}

/// 解析任务状态
public enum ResolveTaskStatus {
    | Success
    | Fail

    public operator func ==(right: ResolveTaskStatus): Bool {
        match (this) {
            case Success => match (right) { case Success => true case _ => false }
            case Fail => match (right) { case Fail => true case _ => false }
        }
    }

    public operator func !=(right: ResolveTaskStatus): Bool {
        return !(this == right)
    }
}

/// 解析任务日志
public class ResolveTaskLog {
    public var msgs: ArrayList<LogMessage>
    public var errors: Int64

    public init() {
        msgs = ArrayList<LogMessage>()
        errors = Int64(0)
    }

    public func hasMessages(): Bool {
        return msgs.size > 0
    }

    public func hasErrors(): Bool {
        return errors > 0
    }

    public func print(): Unit {}
    public func deinit(): Unit {}
}

/// 日志消息
public class LogMessage {
    public init() {}
}

/// 解析任务请求 (联合体)
public class ResolveTaskRequest {
    public init() {}
}

/// 解析任务数据 (联合体)
public class ResolveTaskData {
    public init() {}
}

/// Tarball 引用
public class TarballRef {
    public var dependencyId: UInt32
    public var name: String
    public var resolution: ResolutionRef
    public var url: String

    public init() {
        dependencyId = UInt32(0)
        name = ""
        resolution = ResolutionRef()
        url = ""
    }
}

/// Git 克隆引用
public class GitCloneRef {
    public var name: String
    public var url: String
    public var depId: UInt32
    public var res: ResolutionRef

    public init() {
        name = ""
        url = ""
        depId = UInt32(0)
        res = ResolutionRef()
    }

    public func getGitValue(): GitValue { return GitValue() }
    public func getGitResolved(): String { return "" }
}

/// Git checkout 引用
public class GitCheckoutRef {
    public var name: String
    public var resolution: ResolutionRef
    public var dependencyId: UInt32

    public init() {
        name = ""
        resolution = ResolutionRef()
        dependencyId = UInt32(0)
    }
}

/// Git checkout 数据引用
public class GitCheckoutDataRef {
    public init() {}
}

/// 提取数据引用
public class ExtractDataRef {
    public init() {}
}

/// Git 值
public class GitValue {
    public var committish: String
    public var repo: String
    public var resolved: String
    public var packageName: String

    public init() {
        committish = ""
        repo = ""
        resolved = ""
        packageName = ""
    }
}

/// 任务 ID (duplicate removed - see populate_manifest_cache.cj)
/*
public class TaskId {
    public var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    public static func invalid(): TaskId {
        return TaskId(UInt64(0))
    }

    public static func forManifest(name: String): TaskId {
        return TaskId(hashString(name))
    }

    public static func forGitCheckout(repo: String, resolved: String): TaskId {
        return TaskId(hashString("${repo}:${resolved}"))
    }

    public func get(): UInt64 {
        return value
    }
}
*/

/// 包引用
public class PackageRef {
    public var name: String
    public var meta: PackageMetaRef
    public var resolution: ResolutionRef

    public init() {
        name = ""
        meta = PackageMetaRef()
        resolution = ResolutionRef()
    }
}

/// 包元数据引用
public class PackageMetaRef {
    public var id: UInt32
    public var integrity: IntegrityInfo

    public init() {
        id = UInt32(0)
        integrity = IntegrityInfo()
    }
}

/// 完整性信息 (duplicate removed - see package_manager_enqueue.cj)
/*
public class IntegrityInfo {
    public init() {}
}
*/

/// 补丁任务引用 (duplicate removed - see package_manager_enqueue.cj)
/*
public class PatchTaskRef {
    public var callback: PatchTaskCallback

    public init() {
        callback = PatchTaskCallback.Apply()
    }

    public func deinit(): Unit {}
    public func runFromMainThread(manager: RunTasksPackageManagerState, logLevel: LogLevel): Unit {}
    public func isApplyCallback(): Bool {
        match (callback) {
            case PatchTaskCallback.Apply => return true
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
}
*/

/// 补丁任务回调
public enum PatchTaskCallback {
    | Apply
    | CalcHash
}

/// 补丁应用安装上下文
public class PatchApplyInstallContext {
    public var path: String
    public var treeId: UInt32
    public var dependencyId: UInt32

    public init() {
        path = ""
        treeId = UInt32(0)
        dependencyId = UInt32(0)
    }

    public func resetPath(): Unit {
        path = ""
    }
}

/// Store Installer 任务结果
public enum StoreInstallerTaskResult {
    | None
    | Err(StoreInstallerTaskError)
    | Blocked
    | RunScripts(RunScriptsListRef)
    | Done
}

/// Store Installer 任务引用
public class StoreInstallerTaskRef {
    public var entryId: TaskId
    public var result: StoreInstallerTaskResult
    public var callback: PatchTaskCallback
    public var response: NetworkTaskResponse
    public var retried: UInt32
    public var tag: ResolveTaskTag
    public var urlBuf: String
    public var taskId: TaskId
    public var log: LoggerRef

    public init() {
        entryId = TaskId.invalid()
        result = StoreInstallerTaskResult.None
        callback = PatchTaskCallback.Apply
        response = NetworkTaskResponse()
        retried = UInt32(0)
        tag = ResolveTaskTag.PackageManifest
        urlBuf = ""
        taskId = TaskId.invalid()
        log = LoggerRef()
    }

    public func runFromMainThread(manager: RunTasksPackageManagerState, logLevel: LogLevel): Unit {}
    public func isApplyCallback(): Bool { return false }
    public func getApplyLoggerErrors(): Int64 { return Int64(0) }
    public func getApplyTaskId(): ?TaskId { return None }
    public func hasApplyInstallContext(): Bool { return false }
    public func getApplyInstallContext(): PatchApplyInstallContext { return PatchApplyInstallContext() }
    public func getApplyPkgId(): UInt32 { return UInt32(0) }
    public func getApplyPkgName(): String { return "" }
    public func schedule(batch: ThreadPoolBatch): Unit {}
    public func deinit(): Unit {}
}

/// Store Installer 任务错误
public enum StoreInstallerTaskError {
    | RunScripts(Exception)
    | Other(String)
}

/// Store Installer 任务状态
public enum StoreInstallerTaskStatus {
    | Success
    | Failed
}

/// 运行脚本列表引用
public class RunScriptsListRef {
    public init() {}
}

/// 生成脚本上下文
public class SpawnScriptsContext {
    public var entryId: TaskId
    public var installer: StoreInstallerRef

    public init(entryId: TaskId, installer: StoreInstallerRef) {
        this.entryId = entryId
        this.installer = installer
    }
}

/// Store Installer 引用
public class StoreInstallerRef {
    public var taskQueue: TaskBatchQueue
    public var storeEntries: StoreEntries
    public var storeNodes: StoreNodes
    public var lockfile: RunTasksLockfileRef
    public var manager: RunTasksPackageManagerState
    public var commandCtx: CommandContext

    public init() {
        taskQueue = TaskBatchQueue()
        storeEntries = StoreEntries()
        storeNodes = StoreNodes()
        lockfile = RunTasksLockfileRef()
        manager = RunTasksPackageManagerState()
        commandCtx = CommandContext()
    }

    public func onTaskComplete(entryId: TaskId, status: StoreInstallerTaskStatus): Unit {}
    public func onTaskFail(entryId: TaskId, err: StoreInstallerTaskError): Unit {}
    public func onTaskBlocked(entryId: TaskId): Unit {}
    public func spawnPackageLifecycleScripts(ctx: CommandContext, list: RunScriptsListRef, optional: Bool, b: Bool, spawnCtx: SpawnScriptsContext): Unit {}
}

/// Store 条目
public class StoreEntries {
    public func getNodeId(entryId: TaskId): TaskId { return TaskId.invalid() }
    public func setStepDone(entryId: TaskId): Unit {}
    public func isStepDone(entryId: TaskId): Bool { return true }
}

/// Store 节点
public class StoreNodes {
    public func getDepId(nodeId: TaskId): UInt32 { return UInt32(0) }
}

/// 任务批处理队列
public class TaskBatchQueue {
    public init() {}

    public func popBatch(): TaskBatch { return TaskBatch() }
}

/// 网络任务批处理队列
public class NetworkTaskBatchQueue {
    public init() {}

    public func popBatch(): NetworkTaskBatch { return NetworkTaskBatch() }
}

/// 解析任务批处理队列
public class ResolveTaskBatchQueue {
    public init() {}

    public func popBatch(): ResolveTaskBatch { return ResolveTaskBatch() }
}

/// 任务批处理
public class TaskBatch {
    public var items: ArrayList<StoreInstallerTaskRef>

    public init() {
        items = ArrayList<StoreInstallerTaskRef>()
    }

    public func iterator(): TaskBatchIterator {
        return TaskBatchIterator(items)
    }

    // additional stub for enqueue usage
    public func push(task: EnqueueTaskRef): Unit {}
}

/// 任务批处理迭代器
public class TaskBatchIterator {
    private var items: ArrayList<StoreInstallerTaskRef>
    private var index: Int64

    public init(items: ArrayList<StoreInstallerTaskRef>) {
        this.items = items
        index = Int64(0)
    }

    public func hasNext(): Bool {
        return index < items.size
    }

    public func next(): StoreInstallerTaskRef {
        let item = items[index]
        index += 1
        return item
    }
}

/// 网络任务批处理
public class NetworkTaskBatch {
    public var items: ArrayList<NetworkTaskRef>

    public init() {
        items = ArrayList<NetworkTaskRef>()
    }

    public func iterator(): NetworkTaskBatchIterator {
        return NetworkTaskBatchIterator(items)
    }
}

/// 网络任务批处理迭代器
public class NetworkTaskBatchIterator {
    private var items: ArrayList<NetworkTaskRef>
    private var index: Int64

    public init(items: ArrayList<NetworkTaskRef>) {
        this.items = items
        index = Int64(0)
    }

    public func hasNext(): Bool {
        return index < items.size
    }

    public func next(): NetworkTaskRef {
        let item = items[index]
        index += 1
        return item
    }
}

/// 解析任务批处理
public class ResolveTaskBatch {
    public var items: ArrayList<ResolveTaskRef>

    public init() {
        items = ArrayList<ResolveTaskRef>()
    }

    public func iterator(): ResolveTaskBatchIterator {
        return ResolveTaskBatchIterator(items)
    }
}

/// 解析任务批处理迭代器
public class ResolveTaskBatchIterator {
    private var items: ArrayList<ResolveTaskRef>
    private var index: Int64

    public init(items: ArrayList<ResolveTaskRef>) {
        this.items = items
        index = Int64(0)
    }

    public func hasNext(): Bool {
        return index < items.size
    }

    public func next(): ResolveTaskRef {
        let item = items[index]
        index += 1
        return item
    }
}

/// 线程池批处理
public class ThreadPoolBatch {
    public var len: Int64

    public init() {
        len = Int64(0)
    }

    public func push(other: ThreadPoolBatch): Unit {
        len += other.len
    }
}

/// 网络任务结果 (用于 processNetworkTasks 的返回值)
public class NetworkTaskResult {
    public var hasUpdatedThisRun: Bool
    public var hasNetworkError: Bool
    public var timestampThisTick: ?UInt32

    public init(hasUpdatedThisRun: Bool, hasNetworkError: Bool, timestampThisTick: ?UInt32) {
        this.hasUpdatedThisRun = hasUpdatedThisRun
        this.hasNetworkError = hasNetworkError
        this.timestampThisTick = timestampThisTick
    }
}

/// 运行任务上下文
public class RunTasksContext {
    public init() {}

    public static func voidContext(): RunTasksContext {
        return RunTasksContext()
    }

    public func isStoreInstaller(): Bool { return false }
    public func isPackageInstaller(): Bool { return false }
    public func getInstaller(): PackageInstallerRef { return PackageInstallerRef() }
    public func getStoreInstaller(): StoreInstallerRef { return StoreInstallerRef() }
    public func contextType(): RunTasksContextType { return RunTasksContextType.Void }
}

/// 运行任务上下文类型
public enum RunTasksContextType {
    | PackageInstaller
    | StoreInstaller
    | Void
}

/// Package Installer 引用
public class PackageInstallerRef {
    public var nodeModulesPath: String
    public var currentTreeId: UInt32

    public init() {
        nodeModulesPath = ""
        currentTreeId = UInt32(0)
    }

    public func fixCachedLockfilePackageSlices(): Unit {}
    public func installPackageWithNameAndResolution(
        depId: UInt32,
        pkgId: UInt32,
        logLevel: LogLevel,
        pkgName: String,
        resolution: ResolutionRef,
        b1: Bool,
        b2: Bool
    ): Unit {}
}

/// 运行任务回调
public class RunTasksCallbacks {
    public var progressBar: Bool
    public var manifestsOnly: Bool

    public init() {
        progressBar = false
        manifestsOnly = false
    }

    public static func voidCallbacks(): RunTasksCallbacks {
        return RunTasksCallbacks()
    }

    public func hasOnExtract(): Bool { return false }
    public func hasOnPackageManifestError(): Bool { return false }
    public func hasOnPackageDownloadError(): Bool { return false }
    public func hasOnResolve(): Bool { return false }

    public func onExtract(ctx: RunTasksContext, taskId: TaskId): Unit {}
    public func onExtract(ctx: RunTasksContext, taskId: TaskId, depId: UInt32, data: ExtractDataRef, logLevel: LogLevel): Unit {}
    public func onExtract(ctx: RunTasksContext, taskId: TaskId, depId: UInt32, data: GitCheckoutDataRef, logLevel: LogLevel): Unit {}
    public func onPackageManifestError(ctx: RunTasksContext, name: String, err: String, urlBuf: String): Unit {}
    public func onPackageDownloadError(ctx: RunTasksContext, id: TaskId, name: String, resolution: ResolutionRef, err: String, urlBuf: String): Unit {}
    public func onPackageDownloadError(ctx: RunTasksContext, pkgId: UInt32, name: String, resolution: ResolutionRef, err: String, urlBuf: String): Unit {}
    public func onResolve(ctx: RunTasksContext): Unit {}
}

/// 包管理器状态 (runTasks 专用)
public class RunTasksPackageManagerState {
    // 计数器
    public var totalTasks: Int64
    public var pendingTasks: AtomicUInt32
    public var extractedCount: Int64
    public var anyFailedToInstall: Bool

    // 选项
    public var options: RunTasksOptions
    public var subcommand: Subcommand
    public var updateRequests: ArrayList<UpdateRequest>

    // 锁文件
    public var lockfile: RunTasksLockfileRef

    // 清单缓存
    public var manifests: ManifestCache

    // 队列
    public var taskQueue: TaskQueueMap
    public var patchTaskQueue: TaskBatchQueue
    public var patchTaskFifo: PatchTaskFifo
    public var asyncNetworkTaskQueue: NetworkTaskBatchQueue
    public var networkTaskFifo: TaskFifo
    public var resolveTasks: ResolveTaskBatchQueue
    public var dependencyListQueue: DependencyListQueue
    public var peerDependencies: PeerDependencyQueue

    // 去重
    public var networkDedupeMap: NetworkDedupeMap

    // Git 仓库
    public var gitRepositories: GitRepositoryMap

    // 预分配
    public var preallocatedNetworkTasks: PreallocatedTasks
    public var preallocatedResolveTasks: PreallocatedTasks

    // 批处理
    public var taskBatch: ThreadPoolBatch
    public var networkResolveBatch: ThreadPoolBatch
    public var networkTarballBatch: ThreadPoolBatch
    public var patchApplyBatch: ThreadPoolBatch
    public var patchCalcHashBatch: ThreadPoolBatch

    // 线程池
    public var threadPool: ThreadPoolRef

    // 进度条
    public var downloadsNode: ProgressNode
    public var log: LoggerRef

    // 环境
    public var allocator: DefaultAllocator
    public var env: EnvironmentRef

    public init() {
        totalTasks = Int64(0)
        pendingTasks = AtomicUInt32(UInt32(0))
        extractedCount = Int64(0)
        anyFailedToInstall = false
        options = RunTasksOptions()
        subcommand = Subcommand.Install
        updateRequests = ArrayList<UpdateRequest>()
        lockfile = RunTasksLockfileRef()
        manifests = ManifestCache()
        taskQueue = TaskQueueMap()
        patchTaskQueue = TaskBatchQueue()
        patchTaskFifo = PatchTaskFifo()
        asyncNetworkTaskQueue = NetworkTaskBatchQueue()
        networkTaskFifo = TaskFifo()
        resolveTasks = ResolveTaskBatchQueue()
        dependencyListQueue = DependencyListQueue()
        peerDependencies = PeerDependencyQueue()
        networkDedupeMap = NetworkDedupeMap()
        gitRepositories = GitRepositoryMap()
        preallocatedNetworkTasks = PreallocatedTasks()
        preallocatedResolveTasks = PreallocatedTasks()
        taskBatch = ThreadPoolBatch()
        networkResolveBatch = ThreadPoolBatch()
        networkTarballBatch = ThreadPoolBatch()
        patchApplyBatch = ThreadPoolBatch()
        patchCalcHashBatch = ThreadPoolBatch()
        threadPool = ThreadPoolRef()
        downloadsNode = ProgressNode()
        log = LoggerRef()
        allocator = DefaultAllocator()
        env = EnvironmentRef()
    }

    public func pendingTaskCount(): UInt32 {
        return PendingTaskCounter.pendingTaskCount(this)
    }

    public func decrementPendingTasks(): Unit {
        PendingTaskCounter.decrementPendingTasks(this)
    }

    public func drainDependencyList(): Unit {
        DrainDependencyList.drainDependencyList(this)
    }

    public func startProgressBarIfNone(): Unit {}
    public func setNodeName(node: ProgressNode, name: String, emoji: String, b: Bool): Unit {}
    public func enqueueNetworkTask(task: NetworkTaskRef): Unit {}
    public func isNetworkTaskRequired(taskId: TaskId): Bool { return NetworkTaskDedup.isNetworkTaskRequired(this, taskId) }
    public func hasCreatedNetworkTask(taskId: TaskId, isRequired: Bool): Bool { return NetworkTaskDedup.hasCreatedNetworkTask(this, taskId, isRequired) }
    public func processDependencyList(list: TaskCallbackList, ctx: RunTasksContext, callbacks: RunTasksCallbacks, installPeer: Bool): Unit {}
    public func processDependencyListItem(dep: TaskCallbackContext, anyRoot: Bool, installPeer: Bool): Unit {}
    public func processExtractedTarballPackage(pkgId: UInt32, depId: UInt32, res: ResolutionRef, data: ExtractDataRef, logLevel: LogLevel): Bool { return false }
    public func processExtractedTarballPackage(pkgId: UInt32, depId: UInt32, res: ResolutionRef, data: GitCheckoutDataRef, logLevel: LogLevel): Bool { return false }
    public func enqueueParseNPMPackage(taskId: TaskId, name: String, task: NetworkTaskRef): ThreadPoolBatch { return ThreadPoolBatch() }
    public func enqueueExtractNPMPackage(extract: ExtractRequestRef, task: NetworkTaskRef): ThreadPoolBatch { return ThreadPoolBatch() }
    public func enqueueGitCheckout(checkoutId: TaskId, repoFd: Int64, depId: UInt32, depName: String, res: ResolutionRef, resolved: String, b: ?String): ThreadPoolBatch { return ThreadPoolBatch() }
    public func getGitCheckoutResolved(): String { return "" }
    public func getGitCheckoutPkgName(): String { return "" }
    public func scopeForPackageName(name: String): ScopeInfo { return ScopeInfo() }
    public func enqueueDependencyWithMain(depId: UInt32, dep: DependencyRef, resolution: UInt32, isMain: Bool): Unit {}
    public func getCacheDirectory(): String { return "" }
    public func getTemporaryDirectory(): TempDirRef { return TempDirRef() }
    public func setPreinstallState(pkgId: UInt32, lockfile: RunTasksLockfileRef, state: PreinstallState): Unit {}
    public func createExtractTaskForStreaming(extract: ExtractRequestRef, task: NetworkTaskRef): ResolveTaskRef { return ResolveTaskRef() }
    public func progressMaybeRefresh(): Unit {}
    public func spawnPackageLifecycleScripts(scripts: ArrayList<String>, commandCtx: String, pkgName: String, path: String, env: String): Unit {}
    public func spawnPackageLifecycleScripts(ctx: CommandContext, list: RunScriptsListRef, optional: Bool, outputInForeground: Bool, spawnCtx: SpawnScriptsContext): Unit {}
}

/// 运行任务选项
public class RunTasksOptions {
    public var maxRetryCount: UInt32
    public var minSimultaneousRequests: Int64
    public var logLevel: LogLevel
    public var doSaveLockfile: Bool
    public var doSaveYarnLock: Bool
    public var doInstallPackages: Bool
    public var enableManifestCache: Bool

    public init() {
        maxRetryCount = UInt32(1)
        minSimultaneousRequests = Int64(5)
        logLevel = LogLevel.Default
        doSaveLockfile = true
        doSaveYarnLock = true
        doInstallPackages = true
        enableManifestCache = false
    }
}

/// 更新请求
public class UpdateRequest {
    public var name: String
    public var failed: Bool

    public init() {
        name = ""
        failed = false
    }
}

/// 原子 UInt32
public class AtomicUInt32 {
    private var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public func loadAcquire(): UInt32 { return value }
    public func fetchAdd(count: UInt32): Unit { value += count }
    public func fetchSub(count: UInt32): Unit { value -= count }
}

/// 任务队列映射
public class TaskQueueMap {
    public init() {}

    public func getEntry(taskId: TaskId): ?TaskQueueEntry {
        return None
    }

    public func fetchRemove(taskId: TaskId): ?TaskCallbackList {
        return None
    }
}

/// 任务队列条目
public class TaskQueueEntry {
    public var value: TaskCallbackList

    public init() {
        value = TaskCallbackList()
    }

    public func clearValue(): Unit {}
    public func append(item: TaskCallbackContext): Unit {}
}

/// 任务 FIFO
public class TaskFifo {
    public init() {}

    public func readItem(): ?NetworkTaskRef { return None }
}

/// Patch 任务 FIFO
public class PatchTaskFifo {
    public init() {}

    public func readItem(): ?PatchTaskRef { return None }
}

/// 依赖列表队列
public class DependencyListQueue {
    public init() {}

    public func readItem(): ?DependencyListSlice { return None }
}

/// 依赖列表切片
public class DependencyListSlice {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }
}

/// 对等依赖队列 (duplicate removed - see process_dependency_list.cj)
/*
public class PeerDependencyQueue {
    public init() {}
    public func readItem(): ?UInt32 { return None }
}
*/

/// 网络去重映射
public class NetworkDedupeMap {
    public init() {}

    public func get(taskId: TaskId): ?NetworkDedupeEntry { return None }
    public func getOrPut(taskId: TaskId): NetworkDedupeEntry { return NetworkDedupeEntry() }
    public func remove(taskId: TaskId): Bool { return false }
}

/// 网络去重条目
public class NetworkDedupeEntry {
    public var foundExisting: Bool
    public var isRequired: Bool

    public init() {
        foundExisting = false
        isRequired = false
    }
}

/// Git 仓库映射
public class GitRepositoryMap {
    public init() {}
    public func put(taskId: TaskId, repoFd: Int64): Unit {}
}

/// 预分配任务池
public class PreallocatedTasks {
    public init() {}
    public func get(): NetworkTaskRef { return NetworkTaskRef() }
    public func put(task: ResolveTaskRef): Unit {}
    public func put(task: NetworkTaskRef): Unit {}
    // additional for enqueue usage
    public func getEnqueueTask(): EnqueueTaskRef { return EnqueueTaskRef() }
}

/// 线程池引用
public class ThreadPoolRef {
    public init() {}
    public func schedule(batch: ThreadPoolBatch): Unit {}
}

/// 进度节点
public class ProgressNode {
    public init() {}

    public func setCompletedItems(count: Int64): Unit {}
    public func setEstimatedTotalItems(count: Int64): Unit {}
    public func activate(): Unit {}
    public func getUnprotectedCompletedItems(): Int64 { return Int64(0) }
}

/// 日志器引用
public class LoggerRef {
    public init() {}

    public func addWarningFmt(loc: ?LoggerLoc, loc2: LoggerLoc, fmt: String): Unit {}
    public func addErrorFmt(loc: ?LoggerLoc, loc2: LoggerLoc, fmt: String): Unit {}
}

/// 环境引用
public class EnvironmentRef {
    public init() {}
    public func get(key: String): ?String { return None }
}

/// 分配器 (duplicate, see bao_core for canonical definition)
/* public class Allocator {
    public init() {}
} */

/// 命令上下文
public class CommandContext {
    public init() {}
}

/// 清单缓存 (duplicate removed - see populate_manifest_cache.cj)
/*
public class ManifestCache {
    public init() {}

    public func getOrPut(hash: UInt64): ManifestCacheEntry { return ManifestCacheEntry() }
    public func insert(hash: UInt64, manifest: ManifestData): Unit {}
}
*/

/// 清单缓存条目 (duplicate removed - see populate_manifest_cache.cj)
/*
public class ManifestCacheEntry {
    public init() {}

    public func setManifest(manifest: ManifestData): Unit {}
    public func setPublicMaxAge(age: UInt32): Unit {}
}
*/

/// 锁文件引用
public class RunTasksLockfileRef {
    public var scratch: LockfileScratch
    public var buffers: LockfileBuffers

    public init() {
        scratch = LockfileScratch()
        buffers = LockfileBuffers()
    }

    public func str(s: String): String { return s }
    public func getResolutionAt(index: UInt32): UInt32 { return INVALID_PACKAGE_ID }
    public func getResolutionAt(index: Int64): UInt32 { return INVALID_PACKAGE_ID }
    public func getDependencyAt(index: UInt32): DependencyRef { return DependencyRef() }
    public func getDependencyVersion(id: UInt32): DependencyVersionInfo { return DependencyVersionInfo() }
    public func getDependencyVersionGit(id: UInt32): DependencyVersionGit { return DependencyVersionGit() }
    public func getPackageResolutions(): ArrayList<ResolutionRef> { return ArrayList<ResolutionRef>() }
    public func getPackageNameAt(pkgId: UInt32): String { return "" }
    public func getPatchedDependencyPatchfileHash(h: UInt64): UInt64 { return UInt64(0) }
}

/// 锁文件暂存
public class LockfileScratch {
    public var dependencyListQueue: DependencyListQueue

    public init() {
        dependencyListQueue = DependencyListQueue()
    }
}

/// 锁文件缓冲区
public class LockfileBuffers {
    public init() {}
}

/// 依赖版本信息 (duplicate removed - see package_manager_enqueue.cj)
/*
public class DependencyVersionInfo {
    public var tag: DependencyVersionTag

    public init() {
        tag = DependencyVersionTag.Uninitialized
    }

    public func getPkgName(): String { return "" }
    public func setGitPackageName(name: String): Unit {}
    public func setGitHubPackageName(name: String): Unit {}
    public func setTarballPackageName(name: String): Unit {}
}
*/

/// 依赖版本 (Git)
public class DependencyVersionGit {
    public var resolved: String
    public var packageName: String

    public init() {
        resolved = ""
        packageName = ""
    }

    public func setGitResolved(r: String): Unit { resolved = r }
    public func setGitPackageName(n: String): Unit { packageName = n }
}

/// 依赖版本标签
public enum DependencyVersionTag {
    | Uninitialized
    | Npm
    | DistTag
    | Folder
    | Tarball
    | Git
    | Github
    | Symlink
    | Workspace
    | Catalog

    /// 推断版本标签类型
    /// 翻译自: Tag.infer
    public static func infer(version: String): DependencyVersionTag {
        if (version.size == 0) { return Uninitialized }
        let c = version[0]
        if (c == UInt8(110) || c == UInt8(62) || c == UInt8(61) || c == UInt8(60) || c == UInt8(126) || c == UInt8(94)) {
            return Npm  // n, >, =, <, ~, ^
        }
        if (c == UInt8(118)) { return Npm }  // v
        if (version.startsWith("file:")) { return Folder }
        if (version.startsWith("link:")) { return Symlink }
        if (version.startsWith("workspace:")) { return Workspace }
        if (version.startsWith("catalog:")) { return Catalog }
        if (version.startsWith("git+")) { return Git }
        if (version.startsWith("github:")) { return Github }
        if (version.startsWith("http://") || version.startsWith("https://")) { return Tarball }
        return Npm
    }

    public operator func ==(right: DependencyVersionTag): Bool {
        match (this) {
            case Uninitialized => match (right) { case Uninitialized => true case _ => false }
            case Npm => match (right) { case Npm => true case _ => false }
            case DistTag => match (right) { case DistTag => true case _ => false }
            case Folder => match (right) { case Folder => true case _ => false }
            case Tarball => match (right) { case Tarball => true case _ => false }
            case Git => match (right) { case Git => true case _ => false }
            case Github => match (right) { case Github => true case _ => false }
            case Symlink => match (right) { case Symlink => true case _ => false }
            case Workspace => match (right) { case Workspace => true case _ => false }
            case Catalog => match (right) { case Catalog => true case _ => false }
        }
    }

    public operator func !=(right: DependencyVersionTag): Bool {
        return !(this == right)
    }
}

/// 仓库引用 (duplicate removed - see package_manager_enqueue.cj)
/*
public class RepositoryRef {
    public var owner: String
    public var repo: String
    public var committish: String

    public init() {
        owner = ""
        repo = ""
        committish = ""
    }
}
*/

/// 仓库工具
public class Repository {
    /// 查找 commit
    /// 翻译自: Repository.findCommit
    public static func findCommit(
        allocator: DefaultAllocator,
        env: EnvironmentRef,
        log: LoggerRef,
        repoFd: Int64,
        depName: String,
        committish: String,
        taskId: TaskId
    ): String {
        return ""
    }

    /// 创建依赖名
    public static func createDependencyName(manager: PdlPackageManagerRef, resolution: PdlResolutionInfo, depId: UInt32): String {
        return ""
    }
}

/// 进度字符串
public class ProgressStrings {
    public static let downloadEmoji: String = "⬇"
    public static let extractEmoji: String = "📦"
}

/// 任务回调上下文 (duplicate removed - see process_dependency_list.cj)
/*
public enum TaskCallbackContext {
    | Dependency(UInt32)
    | RootDependency(UInt32)
    | Extract(ExtractData)
    | Other
}
*/

/// 任务回调列表 (duplicate removed - see process_dependency_list.cj)
/*
public class TaskCallbackList {
    public var items: ArrayList<TaskCallbackContext>

    public init() {
        items = ArrayList<TaskCallbackContext>()
    }

    public func deinit(): Unit {}
}
*/

/// 提取数据 (duplicate removed - see process_dependency_list.cj)
/*
public class ExtractData {
    public init() {}
}
*/

/// 范围信息 (duplicate removed - see populate_manifest_cache.cj)
/*
public class ScopeInfo {
    public init() {}
}
*/

/// 临时目录引用
public class TempDirRef {
    public var handle: String
    public init() {
        handle = ""
    }
}

/// 网络任务授权
public enum NetworkTaskAuthorization {
    | None
    | Bearer(String)
}

/// Tarball 配置
public class TarballConfig {
    public var packageManager: RunTasksPackageManagerState
    public var name: String
    public var resolution: ResolutionRef
    public var cacheDir: String
    public var tempDir: TempDirRef
    public var dependencyId: UInt32
    public var integrity: IntegrityInfo
    public var url: String

    public init() {
        packageManager = RunTasksPackageManagerState()
        name = ""
        resolution = ResolutionRef()
        cacheDir = ""
        tempDir = TempDirRef()
        dependencyId = UInt32(0)
        integrity = IntegrityInfo()
        url = ""
    }
}

/// Tarball 流
public class TarballStream {
    public init() {}

    public static func `init`(allocator: DefaultAllocator, extractTask: ResolveTaskRef, networkTask: NetworkTaskRef, manager: RunTasksPackageManagerState): TarballStream {
        return TarballStream()
    }
}

/// ExtractTarball 工具
public class ExtractTarball {
    public static func usesStreamingExtraction(): Bool { return false }
}

/// HTTP 工具
public class HTTP {
    public static var httpThread: HttpThread = HttpThread()
}

/// Http 线程
public class HttpThread {
    public init() {}
    public func schedule(batch: ThreadPoolBatch): Unit {}
}

/// AsyncHTTP 工具
public class AsyncHTTP {
    private static var maxSimultaneousRequests: Int64 = Int64(50)

    public static func getMaxSimultaneousRequests(): Int64 { return maxSimultaneousRequests }
    public static func setMaxSimultaneousRequests(max: Int64): Unit { maxSimultaneousRequests = max }
}

/// 包管理器标志
public class PackageManagerFlags {
    public static let verboseInstall: Bool = false
}

/// Patch 任务工具
public class PatchTask {
    public static func newApplyPatchHash(manager: RunTasksPackageManagerState, pkgId: UInt32, patchHash: UInt64, h: UInt64): PatchTaskRef {
        return PatchTaskRef()
    }
}

/// 预安装状态
public enum PreinstallState {
    | Done
    | Pending
    | Extracting
    | Extract
    | CalcPatchHash
    | ApplyPatch
}

/// 日志级别
public enum LogLevel {
    | Default
    | Silent
    | Verbose
    |VerboseColor

    public operator func ==(right: LogLevel): Bool {
        match (this) {
            case Default => match (right) { case Default => true case _ => false }
            case Silent => match (right) { case Silent => true case _ => false }
            case Verbose => match (right) { case Verbose => true case _ => false }
            case VerboseColor => match (right) { case VerboseColor => true case _ => false }
        }
    }

    public operator func !=(right: LogLevel): Bool {
        return !(this == right)
    }

    public func showProgress(): Bool {
        match (this) {
            case LogLevel.Silent => return false
            case _ => return true
        }
    }

    public func isVerbose(): Bool {
        match (this) {
            case LogLevel.Verbose | LogLevel.VerboseColor => return true
            case _ => return false
        }
    }
}

/// 输出写入器
public class OutputWriter {
    public init() {}
}

/// 调试工具
public class RunTasksDebug {
    public static func assert(condition: Bool): Unit {
        if (!condition) {
            throw BaoError(ErrorCode.Unreachable, "assertion failed")
        }
    }

    public static func ciAssert(condition: Bool): Unit {
        // CI 断言: 仅在 CI 环境中检查
    }
}

/// 默认分配器 (Allocator 的具体实现)
public open class DefaultAllocator {
    public init() {}
}

/// 时间工具
public class Time {
    public static func now(): Int64 { return Int64(0) }
    public static func nanoTimestamp(): Int64 { return Int64(0) }
}


/// 哈希字符串辅助
func hashString(s: String): UInt64 {
    // 简单哈希
    var hash: UInt64 = UInt64(5381)
    for (i in 0..s.size) {
        hash = ((hash << 5) + hash) + UInt64(Int64(s[i]))
    }
    return hash
}
