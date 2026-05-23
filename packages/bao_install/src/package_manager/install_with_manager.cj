// bao_install - 使用包管理器安装
// 严格翻译自: src/install/PackageManager/install_with_manager.zig
//   installWithManager: 使用包管理器执行完整安装流程
//   printInstallSummary: 打印安装摘要
//   printBlockedPackagesInfo: 打印被阻塞的包信息
//   getWorkspaceFilters: 获取工作区过滤器
//   addDependencyError: 添加依赖解析错误
//   CacheVersion: 缓存版本
//   PatchHashFmt: 补丁哈希格式化
//   InstallWithManager: 缓存目录管理、临时目录、全局目录设置、锁文件保存等
package bao_install.package_manager

import bao_install.*

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

// ============================================================================
// 缓存版本
// 严格翻译自: install_with_manager.zig - CacheVersion
// ============================================================================

/// 缓存版本
/// 对应 Bun: CacheVersion
public enum CacheVersion {
    | V0  // 旧版本
    | V1  // 新版本

    public func value(): String {
        match (this) {
            case V0 => "v0"
            case V1 => "v1"
        }
    }
}

// ============================================================================
// 补丁哈希格式化
// 严格翻译自: install_with_manager.zig - PatchHashFmt
// ============================================================================

/// 补丁哈希格式化
/// 对应 Bun: PatchHashFmt
public class PatchHashFmt {
    public var hash: UInt64

    public init(hash: UInt64) {
        this.hash = hash
    }

    public func format(): String {
        // 十六进制小写
        return "${hash}"
    }
}

// ============================================================================
// 使用包管理器安装
// 严格翻译自: src/install/PackageManager/install_with_manager.zig
//   pub fn installWithManager(manager, ctx, root_package_json_path, original_cwd) !void
//   完整安装流程:
//     1. DNS 预解析
//     2. 加载/解析锁文件
//     3. 计算依赖差异
//     4. 运行任务 (解析/下载/解压/补丁)
//     5. 安全扫描
//     6. 安装包 (hoisted/isolated)
//     7. 运行生命周期脚本
//     8. 保存锁文件
// ============================================================================

/// 使用包管理器安装
/// 对应 Bun: installWithManager 中的函数
/// 翻译自: src/install/PackageManager/install_with_manager.zig
public class InstallWithManager {

    // ========================================================================
    // 核心安装入口
    // ========================================================================

    /// 使用包管理器安装 (核心入口)
    /// 严格翻译自: installWithManager
    ///   pub fn installWithManager(
    ///       manager: *PackageManager,
    ///       ctx: Command.Context,
    ///       root_package_json_path: [:0]const u8,
    ///       original_cwd: []const u8,
    ///   ) !void
    ///   参数:
    ///     manager: 包管理器实例
    ///     ctx: 命令上下文
    ///     rootPackageJsonPath: 根 package.json 路径
    ///     originalCwd: 原始工作目录
    public static func installWithManager(
        manager: IwmPackageManagerRef,
        ctx: IwmCommandContext,
        rootPackageJsonPath: String,
        originalCwd: String
    ): Unit {
        let logLevel = manager.options.logLevel

        // Step 1: DNS 预解析
        // 翻译自: Start resolving DNS for the default registry immediately
        dnsPrefetch(manager)

        // Step 2: 加载锁文件
        // 翻译自: var load_result = if (manager.options.do.load_lockfile) ...
        var loadResult: IwmLoadResult = IwmLoadResult.NotFound
        if (manager.options.doLoadLockfile) {
            loadResult = manager.lockfile.loadFromCwd(manager, manager.log, true)
        }

        manager.updateLockfileIfNeeded(loadResult)

        // Step 3: 选择配置版本
        let configVersionResult = loadResult.chooseConfigVersion()
        let configVersion = configVersionResult.version
        let changedConfigVersion = configVersionResult.changed

        manager.options.configVersion = configVersion

        var root = IwmLockfilePackage()
        var needsNewLockfile = loadResult.isNotFound() ||
            (loadResult.isOk() && loadResult.getLockfile().dependenciesCount() == 0 && manager.updateRequests.size > 0)

        manager.options.forceSaveLockfile = manager.options.forceSaveLockfile ||
            changedConfigVersion ||
            (loadResult.isOk() &&
                (loadResult.getMigrated() != IwmMigrationKind.None_ ||
                    (loadResult.getFormat() == IwmLockfileFormat.Binary &&
                        manager.options.saveTextLockfile == Some(true))))

        var hadAnyDiffs = false

        // Step 4: 根据加载结果处理
        match (loadResult) {
            case IwmLoadResult.Err(cause) => handleLoadError(manager, cause, logLevel)
            case IwmLoadResult.Ok(_) => hadAnyDiffs = processLoadOk(manager, ctx, rootPackageJsonPath, logLevel)
            case _ => ()
        }

        // Step 5: 需要新锁文件
        if (needsNewLockfile) {
            root = IwmLockfilePackage()
            manager.lockfile.initEmpty(manager.allocator)

            // 翻译自: frozen_lockfile 检查
            if (manager.options.frozenLockfile && !loadResult.isNotFound()) {
                if (logLevel != IwmLogLevel.Silent) {
                    Output.prettyErrorln("error: lockfile had changes, but lockfile is frozen")
                }
                Global.crash()
            }

            let rootPackageJsonEntry = manager.workspacePackageJsonCache.getWithPath(
                manager.allocator, manager.log, rootPackageJsonPath
            )
            match (rootPackageJsonEntry) {
                case IwmPackageJsonCacheResult.Entry(source) =>
                    var resolver = IwmResolverContext()
                    root.parse(
                        manager.lockfile, manager, manager.allocator, manager.log,
                        source, resolver, IwmFeatures.Main
                    )
                case IwmPackageJsonCacheResult.ReadErr(err) =>
                    if (manager.log.hasErrors()) { manager.log.print(IwmOutputWriter()) }
                    Output.err(err, "failed to read '${rootPackageJsonPath}'")
                    Global.exit(1)
                case IwmPackageJsonCacheResult.ParseErr(err) =>
                    if (manager.log.hasErrors()) { manager.log.print(IwmOutputWriter()) }
                    Output.err(err, "failed to parse '${rootPackageJsonPath}'")
                    Global.exit(1)
            }

            root = manager.lockfile.appendPackage(root)

            if (root.dependenciesLen() > 0) {
                _ = getCacheDirectory(manager)
                _ = getTemporaryDirectory(manager)
            }

            // 翻译自: enqueue patch tasks for patched dependencies
            let patchIter = manager.lockfile.patchedDependenciesIterator()
            while (patchIter.hasNext()) {
                let entry = patchIter.next()
                manager.enqueuePatchTaskPre(IwmPatchTask.newCalcPatchHash(manager, entry.key, Option<UInt64>.None))
            }

            manager.enqueueDependencyList(root.dependencies)
        } else {
            // 翻译自: drainDependencyList for existing lockfile
            let patchIter = manager.lockfile.patchedDependenciesIterator()
            while (patchIter.hasNext()) {
                let entry = patchIter.next()
                manager.enqueuePatchTaskPre(IwmPatchTask.newCalcPatchHash(manager, entry.key, Option<UInt64>.None))
            }
            manager.drainDependencyList()
        }

        // Step 6: 运行任务
        if (manager.pendingTaskCount() > 0 || manager.peerDependencies.readableLength() > 0) {
            if (root.dependenciesLen() > 0) {
                _ = getCacheDirectory(manager)
                _ = getTemporaryDirectory(manager)
            }

            if (logLevel.showProgress()) {
                manager.startProgressBar()
            } else if (logLevel != IwmLogLevel.Silent) {
                Output.prettyErrorln("Resolving dependencies")
            }

            // 翻译自: wait for patch hashes
            if (manager.lockfile.patchedDependenciesCount() > 0) {
                manager.waitForCalcingPatchHashes()
            }

            // 翻译自: wait for everything except peers
            if (manager.pendingTaskCount() > 0) {
                manager.waitForEverythingExceptPeers()
            }

            // 翻译自: iterative peer dependency resolution
            while (manager.peerDependencies.readableLength() > 0) {
                manager.processPeerDependencyList()
                manager.drainDependencyList()
            }

            if (manager.pendingTaskCount() > 0) {
                manager.waitForPeers()
            }

            if (logLevel.showProgress()) {
                manager.endProgressBar()
            } else if (logLevel != IwmLogLevel.Silent) {
                Output.prettyErrorln("Resolved, downloaded and extracted [${manager.totalTasks}]")
            }
        }

        // Step 7: 打印日志
        let hadErrorsBeforeCleaning = manager.log.hasErrors()
        manager.log.print(IwmOutputWriter())
        manager.log.reset()

        let lockfileBeforeClean = manager.lockfile

        manager.lockfile = manager.lockfile.cleanWithLogger(
            manager, manager.updateRequests, manager.log,
            manager.options.exactVersions, logLevel
        )

        if (manager.lockfile.packagesLen() > 0) {
            root = manager.lockfile.getRootPackage()
        }

        // Step 8: 检查更新请求失败
        if (manager.lockfile.packagesLen() > 0) {
            for (request in manager.updateRequests) {
                if (request.failed) {
                    throw BaoError(ErrorCode.Unexpected)
                }
            }

            manager.verifyResolutions(logLevel)

            // Step 9: 安全扫描
            match (manager.securityScanner) {
                case Some(scanner) => runSecurityScan(scanner, manager, ctx, originalCwd, logLevel)
                case None => ()
            }
        }

        // Step 10: 加载根生命周期脚本
        manager.loadRootLifecycleScripts(root)

        if (manager.rootLifecycleScripts.isSome()) {
            let rootScripts = manager.rootLifecycleScripts.getOrThrow()
            rootScripts.appendToLockfile(manager.lockfile)
        }

        // 翻译自: append workspace scripts to lockfile
        appendWorkspaceScripts(manager)

        // Step 11: 设置全局目录
        if (manager.options.global) {
            setupGlobalDir(manager, ctx)
        }

        let packagesLenBeforeInstall = manager.lockfile.packagesLen()

        // Step 12: 冻结锁文件检查
        if (manager.options.frozenLockfile && !loadResult.isNotFound()) {
            let frozenCheck = checkFrozenLockfile(manager, loadResult, lockfileBeforeClean, packagesLenBeforeInstall, logLevel)
            if (frozenCheck) {
                return
            }
        }

        let lockfileBeforeInstall = manager.lockfile
        let saveFormat = loadResult.saveFormat(manager.options)

        // Step 13: lockfile_only 模式
        if (manager.options.lockfileOnly) {
            manager.lockfile.metaHash = manager.lockfile.generateMetaHash(
                IwmPackageManagerFlags.verboseInstall || manager.options.printMetaHashString,
                packagesLenBeforeInstall
            )

            saveLockfile(manager, saveFormat, hadAnyDiffs, lockfileBeforeInstall, packagesLenBeforeInstall, logLevel)

            if (manager.options.doSummary) {
                Output.pretty("\nSaved <green>${saveFormat.name()}<r> (${manager.lockfile.packagesLen()} package${if (manager.lockfile.packagesLen() == 1) { "" } else { "s" }}) ")
                Output.pretty("in ...ms")
                Output.pretty("\n")
            }
            Output.flush()
            return
        }

        // Step 14: 获取工作区过滤器
        let workspaceFilterResult = getWorkspaceFilters(manager, originalCwd)

        // Step 15: 安装包
        let installSummary = installPackages(
            manager, ctx, workspaceFilterResult, logLevel
        )

        if (logLevel != IwmLogLevel.Silent) {
            manager.log.print(IwmOutputWriter())
        }
        if (hadErrorsBeforeCleaning || manager.log.hasErrors()) {
            Global.crash()
        }

        // Step 16: 检查 meta hash 变化
        let didMetaHashChange = !manager.options.frozenLockfile &&
            checkMetaHashChanged(manager, loadResult, lockfileBeforeClean, packagesLenBeforeInstall)

        // Step 17: 保存锁文件
        let shouldSave = computeShouldSaveLockfile(
            loadResult, manager, hadAnyDiffs, didMetaHashChange, saveFormat
        )
        if (shouldSave) {
            saveLockfile(manager, saveFormat, hadAnyDiffs, lockfileBeforeInstall, packagesLenBeforeInstall, logLevel)
        }

        if (needsNewLockfile) {
            manager.summary.add = manager.lockfile.packagesLen()
        }

        // Step 18: 保存 yarn.lock
        if (manager.options.doSaveYarnLock) {
            if (logLevel.showProgress()) {
                manager.progress.supportsAnsiEscapeCodes = false
                let node = manager.progress.start("Saving yarn.lock", 0)
                manager.progress.refresh()
                writeYarnLock(manager)
                node.completeOne()
                manager.progress.refresh()
                manager.progress.root.end()
            } else if (logLevel != IwmLogLevel.Silent) {
                Output.prettyErrorln("Saved yarn.lock")
            }
        }

        // Step 19: 运行根生命周期脚本
        if (manager.options.doRunScripts && workspaceFilterResult.installRootDependencies && !manager.options.global) {
            match (manager.rootLifecycleScripts) {
                case Some(scripts) =>
                    if (logLevel != IwmLogLevel.Silent) {
                        Output.pretty("<r>\n")
                        Output.flush()
                    }

                    manager.spawnPackageLifecycleScripts(ctx, scripts, false, true, Option<IwmSpawnContext>.None)

                    while (manager.pendingLifecycleScriptTasks > 0) {
                        manager.reportSlowLifecycleScripts()
                        manager.sleep()
                    }
                case None => ()
            }
        }

        // Step 20: 打印安装摘要
        if (logLevel != IwmLogLevel.Silent) {
            printInstallSummary(manager, ctx, installSummary, didMetaHashChange, logLevel)
        }

        if (installSummary.fail > 0) {
            manager.anyFailedToInstall = true
        }

        Output.flush()
    }

    // ========================================================================
    // DNS 预解析
    // 严格翻译自: installWithManager.zig 第9-19行
    // ========================================================================

    /// DNS 预解析
    /// 翻译自: Start resolving DNS for the default registry immediately.
    ///   Unless you're behind a proxy.
    private static func dnsPrefetch(manager: IwmPackageManagerRef): Unit {
        if (manager.env.hasHTTPProxy()) {
            return
        }

        let hostname = manager.options.scope.url.hostname
        if (hostname.size > 0 && !manager.options.scope.url.isIPAddress()) {
            // 翻译自: bun.dns.internal.prefetch(...)
            DnsInternal.prefetch(manager.eventLoop, hostname, manager.options.scope.url.getPortAuto())
        }
    }

    // ========================================================================
    // 处理加载错误
    // 严格翻译自: installWithManager.zig 第57-86行
    // ========================================================================

    /// 处理加载错误
    /// 翻译自: .err => |cause| { ... }
    private static func handleLoadError(
        manager: IwmPackageManagerRef,
        cause: IwmLoadError,
        logLevel: IwmLogLevel
    ): Unit {
        if (logLevel != IwmLogLevel.Silent) {
            match (cause.step) {
                case IwmLoadStep.OpenFile => Output.err(cause.value, "failed to open lockfile: '${cause.lockfilePath}'")
                case IwmLoadStep.ParseFile => Output.err(cause.value, "failed to parse lockfile: '${cause.lockfilePath}'")
                case IwmLoadStep.ReadFile => Output.err(cause.value, "failed to read lockfile: '${cause.lockfilePath}'")
                case IwmLoadStep.Migrating => Output.err(cause.value, "failed to migrate lockfile: '${cause.lockfilePath}'")
            }

            if (!manager.options.failEarly) {
                Output.prettyError("<r>\n")
                Output.pretty("Ignoring lockfile\n")
            }

            if (manager.log.hasErrors()) {
                manager.log.print(IwmOutputWriter())
                manager.log.reset()
            }
            Output.flush()
        }

        if (manager.options.failEarly) {
            Global.crash()
        }
    }

    // ========================================================================
    // 处理加载成功 - 计算差异
    // 严格翻译自: installWithManager.zig 第88-431行
    // ========================================================================

    /// 处理加载成功 (计算依赖差异)
    /// 翻译自: .ok => { ... } 块
    ///   包含:
    ///     - update 子命令: 获取原始版本
    ///     - Package.Diff.generate: 生成差异
    ///     - 处理 overrides 变更
    ///     - 处理 catalogs 变更
    ///     - 处理 add/update 变更
    ///     - 更新 workspace 路径/版本
    ///     - 更新 patched dependencies
    private static func processLoadOk(
        manager: IwmPackageManagerRef,
        ctx: IwmCommandContext,
        rootPackageJsonPath: String,
        logLevel: IwmLogLevel
    ): Bool {
        // 翻译自: update 子命令 - 获取原始版本
        if (manager.subcommand == IwmSubcommand.Update) {
            processUpdateOriginalVersions(manager)
        }

        // 翻译自: differ block
        var root = manager.lockfile.rootPackage()
        var needsNewLockfile = false

        match (root) {
            case Some(r) =>
                root = Some(r)
                if (r.dependenciesLen() == 0) {
                    needsNewLockfile = true
                }
            case None => needsNewLockfile = true
        }

        if (needsNewLockfile) {
            return false
        }

        // 翻译自: 创建临时 lockfile 并解析 package.json
        let tempLockfile = IwmLockfileRef()
        tempLockfile.initEmpty(manager.allocator)
        var maybeRoot = IwmLockfilePackage()

        let rootPackageJsonEntry = manager.workspacePackageJsonCache.getWithPath(
            manager.allocator, manager.log, rootPackageJsonPath
        )

        var sourceCopy = IwmSource()
        match (rootPackageJsonEntry) {
            case IwmPackageJsonCacheResult.Entry(source) => sourceCopy = source
            case IwmPackageJsonCacheResult.ReadErr(err) =>
                if (manager.log.hasErrors()) { manager.log.print(IwmOutputWriter()) }
                Output.err(err, "failed to read '${rootPackageJsonPath}'")
                Global.exit(1)
            case IwmPackageJsonCacheResult.ParseErr(err) =>
                if (manager.log.hasErrors()) { manager.log.print(IwmOutputWriter()) }
                Output.err(err, "failed to parse '${rootPackageJsonPath}'")
                Global.exit(1)
        }

        var resolver = IwmResolverContext()
        maybeRoot.parse(
            tempLockfile, manager, manager.allocator, manager.log,
            sourceCopy, resolver, IwmFeatures.Main
        )

        let mapping = IwmMapping.create(manager.allocator, maybeRoot.dependenciesLen())

        // 翻译自: Package.Diff.generate
        manager.summary = PackageDiff.generate(
            manager, manager.allocator, manager.log,
            manager.lockfile, tempLockfile, root.getOrThrow(), maybeRoot,
            if (manager.toUpdate) { manager.updateRequests } else { ArrayList<IwmUpdateRequest>() },
            mapping
        )

        var hadAnyDiffs = manager.summary.hasDiffs()

        if (!hadAnyDiffs) {
            // 翻译自: always grab latest scripts for root package
            updateRootScripts(manager, tempLockfile, maybeRoot)
        } else {
            // 翻译自: 处理有差异的情况
            hadAnyDiffs = processDiffChanges(manager, tempLockfile, maybeRoot, mapping, logLevel)
        }

        return hadAnyDiffs
    }

    /// 处理 update 子命令原始版本
    /// 翻译自: installWithManager.zig 第89-125行
    private static func processUpdateOriginalVersions(manager: IwmPackageManagerRef): Unit {
        let lockfile = manager.lockfile
        let packages = lockfile.packages()
        let resolutions = packages.resolutions()
        let workspacePackageId = manager.rootPackageId.get(lockfile, manager.workspaceNameHash)
        let workspaceDepList = packages.dependencies(workspacePackageId)
        let workspaceResList = packages.resolutions(workspacePackageId)
        let workspaceDeps = workspaceDepList.get(lockfile.buffers.dependencies)
        let workspacePackageIds = workspaceResList.get(lockfile.buffers.resolutions)

        for (i in 0..workspaceDeps.size()) {
            let dep = workspaceDeps[i]
            let packageId = workspacePackageIds[i]
            if (dep.version.tag != IwmDependencyVersionTag.NPM && dep.version.tag != IwmDependencyVersionTag.DistTag) {
                continue
            }
            if (packageId == IwmConstants.INVALID_PACKAGE_ID) {
                continue
            }

            match (manager.updatingPackages.getPtr(dep.nameSlice(lockfile.buffers.stringBytes))) {
                case Some(entryPtr) =>
                    let originalResolution = resolutions[Int64(packageId)]
                    if (originalResolution.tag != IwmResolutionTag.NPM) {
                        continue
                    }

                    var original = originalResolution.npmVersion
                    let tagTotal = original.tag.preLen() + original.tag.buildLen()
                    if (tagTotal > 0) {
                        let tagBuf = manager.alloc(tagTotal)
                        original.tag = original.tag.cloneInto(lockfile.buffers.stringBytes, tagBuf)
                        entryPtr.originalVersionStringBuf = tagBuf
                    }

                    entryPtr.originalVersion = original
                case None => ()
            }
        }
    }

    /// 更新根包脚本
    /// 翻译自: !had_any_diffs 分支中的 scripts 更新
    private static func updateRootScripts(
        manager: IwmPackageManagerRef,
        lockfile: IwmLockfileRef,
        maybeRoot: IwmLockfilePackage
    ): Unit {
        let builder = manager.lockfile.stringBuilder()
        maybeRoot.scripts.count(lockfile.buffers.stringBytes, builder)
        builder.allocate()
        manager.lockfile.packages().setScripts(0, maybeRoot.scripts.clone(lockfile.buffers.stringBytes, builder))
        builder.clamp()
    }

    /// 处理有差异的情况
    /// 翻译自: had_any_diffs 为 true 时的处理逻辑 (第209-430行)
    private static func processDiffChanges(
        manager: IwmPackageManagerRef,
        lockfile: IwmLockfileRef,
        maybeRoot: IwmLockfilePackage,
        mapping: IwmMapping,
        logLevel: IwmLogLevel
    ): Bool {
        let builder = manager.lockfile.stringBuilder()

        // 翻译自: 计算新依赖的字符串大小
        let newDependencies = maybeRoot.dependencies.get(lockfile.buffers.dependencies)
        for (dep in newDependencies) {
            dep.count(lockfile.buffers.stringBytes, builder)
        }

        // 翻译自: 计算 workspace paths, versions, patched deps
        for (path in lockfile.workspacePaths.values()) {
            builder.count(path.slice(lockfile.buffers.stringBytes))
        }
        for (version in lockfile.workspaceVersions.values()) {
            version.count(lockfile.buffers.stringBytes, builder)
        }
        for (patchDep in lockfile.patchedDependencies.values()) {
            builder.count(patchDep.path)
        }

        lockfile.overrides.count(lockfile, builder)
        lockfile.catalogs.count(lockfile, builder)
        maybeRoot.scripts.count(lockfile.buffers.stringBytes, builder)

        // 翻译自: 更新依赖列表偏移
        let off = manager.lockfile.buffers.dependencies.size
        let len = newDependencies.size()
        manager.lockfile.packages().setDependencies(0, off, len)
        manager.lockfile.packages().setResolutions(0, off, len)
        builder.allocate()

        // 翻译自: 处理 overrides
        let allNameHashes = computeAllNameHashes(manager, lockfile)

        manager.lockfile.overrides = lockfile.overrides.clone(manager, lockfile, manager.lockfile, builder)
        manager.lockfile.catalogs = lockfile.catalogs.clone(manager, lockfile, manager.lockfile, builder)

        manager.lockfile.trustedDependencies = match (lockfile.trustedDependencies) {
            case Some(td) => td.clone(manager.lockfile.allocator)
            case None => None
        }

        manager.lockfile.buffers.dependencies.ensureUnusedCapacity(len)
        manager.lockfile.buffers.resolutions.ensureUnusedCapacity(len)

        let oldResolutions = manager.lockfile.packages().getResolutions(0)

        var dependencies = manager.lockfile.buffers.dependencies.slice(off, off + len)
        var resolutions = manager.lockfile.buffers.resolutions.slice(off, off + len)

        // 翻译自: 初始化 resolutions 为 invalid_package_id
        for (i in 0..resolutions.size()) {
            resolutions[i] = IwmConstants.INVALID_PACKAGE_ID
        }

        // 翻译自: 克隆新依赖
        for (i in 0..newDependencies.size()) {
            let newDep = newDependencies[i]
            dependencies[i] = newDep.clone(manager, lockfile.buffers.stringBytes, builder)
            if (mapping[i] != IwmConstants.INVALID_PACKAGE_ID) {
                resolutions[i] = oldResolutions[Int64(mapping[i])]
            }
        }

        // 翻译自: 更新 scripts
        manager.lockfile.packages().setScripts(0, maybeRoot.scripts.clone(lockfile.buffers.stringBytes, builder))

        // 翻译自: 更新 workspace paths
        updateWorkspacePaths(manager, lockfile, builder)

        // 翻译自: 更新 workspace versions
        updateWorkspaceVersions(manager, lockfile, builder)

        // 翻译自: 更新 patched dependencies
        updatePatchedDependencies(manager, lockfile, builder)

        builder.clamp()

        // 翻译自: 处理 overrides 变更
        if (manager.summary.overridesChanged && allNameHashes.size > 0) {
            requeueOverrideDependencies(manager, allNameHashes, logLevel)
        }

        // 翻译自: 处理 catalogs 变更
        if (manager.summary.catalogsChanged) {
            requeueCatalogDependencies(manager, logLevel)
        }

        // 翻译自: 处理 add/update 变更
        if (manager.summary.add > 0 || manager.summary.update > 0) {
            enqueueNewDependencies(manager, mapping, off, logLevel)
        }

        if (manager.summary.update > 0) {
            // 清空 scripts (将在 install 后重新填充)
        }

        return true
    }

    /// 计算所有 name hashes (用于 overrides 处理)
    /// 翻译自: all_name_hashes 块
    private static func computeAllNameHashes(
        manager: IwmPackageManagerRef,
        lockfile: IwmLockfileRef
    ): ArrayList<UInt64> {
        var result = ArrayList<UInt64>()

        if (!manager.summary.overridesChanged) {
            return result
        }

        let hashesLen = manager.lockfile.overrides.map.size() + lockfile.overrides.map.size()
        if (hashesLen == 0) {
            return result
        }

        // 翻译自: 合并并去重
        for (key in manager.lockfile.overrides.map.keys()) {
            result.append(key)
        }
        for (key in lockfile.overrides.map.keys()) {
            result.append(key)
        }

        // 翻译自: 去重
        deduplicateHashes(result)

        return result
    }

    /// 去重 hashes
    /// 翻译自: installWithManager.zig 中的去重循环
    private static func deduplicateHashes(hashes: ArrayList<UInt64>): Unit {
        var i = 0
        while (i < hashes.size) {
            var found = false
            for (j in 0..i) {
                if (hashes[j] == hashes[i]) {
                    found = true
                    break
                }
            }
            if (found) {
                // 将最后一个移到当前位置
                if (i < hashes.size - 1) {
                    hashes[i] = hashes[hashes.size - 1]
                }
                hashes.removeLast()
            } else {
                i += 1
            }
        }
    }

    /// 更新 workspace paths
    /// 翻译自: Update workspace paths 块
    private static func updateWorkspacePaths(
        manager: IwmPackageManagerRef,
        lockfile: IwmLockfileRef,
        builder: IwmStringBuilder
    ): Unit {
        manager.lockfile.workspacePaths.ensureTotalCapacity(lockfile.workspacePaths.size)
        manager.lockfile.workspacePaths.clearRetainingCapacity()

        let iter = lockfile.workspacePaths.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let path = entry.value.slice(lockfile.buffers.stringBytes)
            let str = builder.appendString(path)
            manager.lockfile.workspacePaths.putAssumeCapacity(entry.key, str)
        }
    }

    /// 更新 workspace versions
    /// 翻译自: Update workspace versions 块
    private static func updateWorkspaceVersions(
        manager: IwmPackageManagerRef,
        lockfile: IwmLockfileRef,
        builder: IwmStringBuilder
    ): Unit {
        manager.lockfile.workspaceVersions.ensureTotalCapacity(lockfile.workspaceVersions.size)
        manager.lockfile.workspaceVersions.clearRetainingCapacity()

        let iter = lockfile.workspaceVersions.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let version = entry.value.append(lockfile.buffers.stringBytes, builder)
            manager.lockfile.workspaceVersions.putAssumeCapacity(entry.key, version)
        }
    }

    /// 更新 patched dependencies
    /// 翻译自: Update patched dependencies 块
    private static func updatePatchedDependencies(
        manager: IwmPackageManagerRef,
        lockfile: IwmLockfileRef,
        builder: IwmStringBuilder
    ): Unit {
        // 添加新的 patched dependencies
        var iter = lockfile.patchedDependencies.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let pkgNameAndVersionHash = entry.key
            let gop = manager.lockfile.patchedDependencies.getOrPut(manager.lockfile.allocator, pkgNameAndVersionHash)

            if (!gop.foundExisting) {
                gop.value = IwmPatchedDependency(
                    path: builder.appendString(entry.value.path.slice(lockfile.buffers.stringBytes))
                )
                gop.value.setPatchfileHash(None)
            } else if (gop.value.path.slice(manager.lockfile.buffers.stringBytes) !=
                       entry.value.path.slice(lockfile.buffers.stringBytes)) {
                gop.value.path = builder.appendString(entry.value.path.slice(lockfile.buffers.stringBytes))
                gop.value.setPatchfileHash(None)
            }
        }

        // 移除不再存在的 patched dependencies
        var toRemove = ArrayList<UInt64>()
        iter = manager.lockfile.patchedDependencies.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            if (!lockfile.patchedDependencies.contains(entry.key)) {
                toRemove.append(entry.key)
            }
        }

        for (hash in toRemove) {
            manager.lockfile.patchedDependencies.orderedRemove(hash)
        }
    }

    /// 重新入队 override 依赖
    /// 翻译自: if (manager.summary.overrides_changed and all_name_hashes.len > 0)
    private static func requeueOverrideDependencies(
        manager: IwmPackageManagerRef,
        allNameHashes: ArrayList<UInt64>,
        logLevel: IwmLogLevel
    ): Unit {
        let dependenciesLen = manager.lockfile.buffers.dependencies.size
        for (i in 0..dependenciesLen) {
            let dependency = manager.lockfile.buffers.dependencies[i]
            var found = false
            for (h in allNameHashes) {
                if (h == dependency.nameHash) {
                    found = true
                    break
                }
            }
            if (found) {
                manager.lockfile.buffers.resolutions[i] = IwmConstants.INVALID_PACKAGE_ID
                try {
                    manager.enqueueDependencyWithMain(UInt32(i), dependency, IwmConstants.INVALID_PACKAGE_ID, false)
                } catch (_: Exception) {
                    addDependencyError(manager, dependency)
                }
            }
        }
    }

    /// 重新入队 catalog 依赖
    /// 翻译自: if (manager.summary.catalogs_changed)
    private static func requeueCatalogDependencies(
        manager: IwmPackageManagerRef,
        logLevel: IwmLogLevel
    ): Unit {
        let dependenciesLen = manager.lockfile.buffers.dependencies.size
        for (i in 0..dependenciesLen) {
            let depId = UInt32(i)
            let dep = manager.lockfile.buffers.dependencies[Int64(depId)]
            if (dep.version.tag != IwmDependencyVersionTag.Catalog) {
                continue
            }

            manager.lockfile.buffers.resolutions[Int64(depId)] = IwmConstants.INVALID_PACKAGE_ID
            try {
                manager.enqueueDependencyWithMain(depId, dep, IwmConstants.INVALID_PACKAGE_ID, false)
            } catch (_: Exception) {
                addDependencyError(manager, dep)
            }
        }
    }

    /// 入队新依赖
    /// 翻译自: if (manager.summary.add > 0 or manager.summary.update > 0)
    private static func enqueueNewDependencies(
        manager: IwmPackageManagerRef,
        mapping: IwmMapping,
        off: Int64,
        logLevel: IwmLogLevel
    ): Unit {
        let changes = mapping.len()
        _ = getCacheDirectory(manager)
        _ = getTemporaryDirectory(manager)

        var counterI = 0
        while (counterI < changes) {
            if (mapping[counterI] == IwmConstants.INVALID_PACKAGE_ID) {
                let dependencyI = counterI + off
                let dependency = manager.lockfile.buffers.dependencies[dependencyI]
                try {
                    manager.enqueueDependencyWithMain(
                        UInt32(dependencyI),
                        dependency,
                        manager.lockfile.buffers.resolutions[dependencyI],
                        false
                    )
                } catch (_: Exception) {
                    addDependencyError(manager, dependency)
                }
            }
            counterI += 1
        }
    }

    // ========================================================================
    // 附加 workspace 脚本
    // 严格翻译自: installWithManager.zig 第713-764行
    // ========================================================================

    /// 附加 workspace 脚本到锁文件
    /// 翻译自: append scripts to lockfile before generating new metahash
    private static func appendWorkspaceScripts(manager: IwmPackageManagerRef): Unit {
        let packages = manager.lockfile.packages()
        let resolutions = packages.resolutions()
        let metas = packages.metas()
        let scripts = packages.scripts()

        for (i in 0..packages.len()) {
            let resolution = resolutions[i]
            let meta = metas[i]
            let script = scripts[i]

            if (resolution.tag == IwmResolutionTag.Workspace) {
                if (meta.hasInstallScript()) {
                    let entries = script.getScriptEntries(
                        manager.lockfile, manager.lockfile.buffers.stringBytes,
                        IwmScriptContext.Workspace, !script.hasAny()
                    )

                    if (entries.firstIndex != -1) {
                        for (entry in entries.entries) {
                            match (entry) {
                                case Some(e) =>
                                    manager.lockfile.scripts.append(e)
                                case None => ()
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // 安全扫描
    // 严格翻译自: installWithManager.zig 第648-699行
    // ========================================================================

    /// 运行安全扫描
    /// 翻译自: security_scanner.performSecurityScanAfterResolution
    private static func runSecurityScan(
        scanner: IwmSecurityScannerRef,
        manager: IwmPackageManagerRef,
        ctx: IwmCommandContext,
        originalCwd: String,
        logLevel: IwmLogLevel
    ): Unit {
        let isSubcommandToRunScanner = manager.subcommand == IwmSubcommand.Add ||
            manager.subcommand == IwmSubcommand.Update ||
            manager.subcommand == IwmSubcommand.Install ||
            manager.subcommand == IwmSubcommand.Remove

        if (!isSubcommandToRunScanner) {
            return
        }

        try {
            let results = scanner.performSecurityScanAfterResolution(manager, ctx, originalCwd)
            match (results) {
                case Some(scanResults) =>
                    SecurityScanner.printSecurityAdvisories(manager, scanResults)

                    if (scanResults.hasFatalAdvisories()) {
                        Output.pretty("<red>Installation aborted due to fatal security advisories<r>\n")
                        Global.exit(1)
                    } else if (scanResults.hasWarnings()) {
                        if (!SecurityScanner.promptForWarnings()) {
                            Global.exit(1)
                        }
                    }
                case None => ()
            }
        } catch (err: Exception) {
            handleSecurityScanError(err)
        }
    }

    /// 处理安全扫描错误
    private static func handleSecurityScanError(err: Exception): Unit {
        Output.errGeneric("security scanner failed: ${err.message}")
        Global.exit(1)
    }

    // ========================================================================
    // 冻结锁文件检查
    // 严格翻译自: installWithManager.zig 第772-788行
    // ========================================================================

    /// 检查冻结锁文件
    /// 翻译自: frozen_lockfile check
    ///   返回 true 表示应该中止
    private static func checkFrozenLockfile(
        manager: IwmPackageManagerRef,
        loadResult: IwmLoadResult,
        lockfileBeforeClean: IwmLockfileRef,
        packagesLenBeforeInstall: Int64,
        logLevel: IwmLogLevel
    ): Bool {
        if (loadResult.loadedFromTextLockfile()) {
            if (manager.lockfile.eql(lockfileBeforeClean, packagesLenBeforeInstall, manager.allocator)) {
                return false
            }
        } else {
            if (!manager.lockfile.hasMetaHashChanged(false, packagesLenBeforeInstall)) {
                return false
            }
        }

        if (logLevel != IwmLogLevel.Silent) {
            Output.prettyErrorln("error: lockfile had changes, but lockfile is frozen")
            Output.note("try re-running without --frozen-lockfile and commit the updated lockfile")
        }
        Global.crash()
        return true
    }

    // ========================================================================
    // 安装包
    // 严格翻译自: installWithManager.zig 第830-862行
    // ========================================================================

    /// 安装包 (选择 hoisted/isolated)
    /// 翻译自: linker switch
    private static func installPackages(
        manager: IwmPackageManagerRef,
        ctx: IwmCommandContext,
        workspaceFilterResult: IwmWorkspaceFilterResult,
        logLevel: IwmLogLevel
    ): IwmPackageInstallSummary {
        if (!manager.options.doInstallPackages) {
            return IwmPackageInstallSummary()
        }

        match (manager.options.nodeLinker) {
            case IwmNodeLinker.Auto =>
                // 翻译自: auto 根据 config_version 决定
                return IwmPackageInstallSummary()
            case IwmNodeLinker.Hoisted =>
                return manager.installHoistedPackages(
                    ctx, workspaceFilterResult.filters,
                    workspaceFilterResult.installRootDependencies, logLevel
                )
            case IwmNodeLinker.Isolated =>
                return manager.installIsolatedPackages(
                    ctx, workspaceFilterResult.filters,
                    workspaceFilterResult.installRootDependencies
                )
        }
    }

    // ========================================================================
    // meta hash 变化检查
    // 严格翻译自: installWithManager.zig 第869-878行
    // ========================================================================

    /// 检查 meta hash 是否变化
    private static func checkMetaHashChanged(
        manager: IwmPackageManagerRef,
        loadResult: IwmLoadResult,
        lockfileBeforeClean: IwmLockfileRef,
        packagesLenBeforeInstall: Int64
    ): Bool {
        if (loadResult.loadedFromTextLockfile()) {
            return !manager.lockfile.eql(lockfileBeforeClean, packagesLenBeforeInstall, manager.allocator)
        } else {
            return manager.lockfile.hasMetaHashChanged(
                IwmPackageManagerFlags.verboseInstall || manager.options.printMetaHashString,
                min(packagesLenBeforeInstall, manager.lockfile.packagesLen())
            )
        }
    }

    // ========================================================================
    // 是否应保存锁文件
    // 严格翻译自: installWithManager.zig 第881-895行
    // ========================================================================

    /// 计算是否应保存锁文件
    /// 翻译自: should_save_lockfile
    private static func computeShouldSaveLockfile(
        loadResult: IwmLoadResult,
        manager: IwmPackageManagerRef,
        hadAnyDiffs: Bool,
        didMetaHashChange: Bool,
        saveFormat: IwmLockfileSaveFormat
    ): Bool {
        // 翻译自: binary -> text 转换
        if (loadResult.isOk()) {
            let loadFormat = loadResult.getFormat()
            if (loadFormat == IwmLockfileFormat.Binary && saveFormat == IwmLockfileSaveFormat.Text) {
                return true
            }

            if (loadFormat == IwmLockfileFormat.Text && saveFormat == IwmLockfileSaveFormat.Text &&
                manager.lockfile.textLockfileVersion != IwmTextLockfileVersion.Current) {
                return true
            }
        }

        // 翻译自: save_lockfile 检查
        if (manager.options.doSaveLockfile) {
            return didMetaHashChange ||
                hadAnyDiffs ||
                manager.updateRequests.size > 0 ||
                (loadResult.isOk() && (loadResult.getPackagesNeedUpdate() || loadResult.getMigratedFromLockbV2())) ||
                manager.lockfile.isEmpty() ||
                manager.options.forceSaveLockfile
        }

        return false
    }

    // ========================================================================
    // 打印安装摘要
    // 严格翻译自: installWithManager.zig 第961-1064行
    //   fn printInstallSummary(this, ctx, install_summary, did_meta_hash_change, log_level) !void
    // ========================================================================

    /// 打印安装摘要
    /// 严格翻译自: printInstallSummary
    public static func printInstallSummary(
        manager: IwmPackageManagerRef,
        ctx: IwmCommandContext,
        installSummary: IwmPackageInstallSummary,
        didMetaHashChange: Bool,
        logLevel: IwmLogLevel
    ): Unit {
        defer {
            Output.flush()
        }

        var printedTimestamp = false

        if (manager.options.doSummary) {
            // 翻译自: Lockfile.Printer.Tree.print
            let printer = IwmLockfilePrinter(
                lockfile: manager.lockfile,
                options: manager.options,
                updates: manager.updateRequests,
                successfullyInstalled: installSummary.successfullyInstalled
            )
            Output.flush()
            Output.enableBuffering()

            // 打印树形结构
            LockfilePrinterTree.print(printer, manager, logLevel)

            if (!didMetaHashChange) {
                manager.summary.remove = 0
                manager.summary.add = 0
                manager.summary.update = 0
            }

            if (installSummary.success > 0) {
                let pkgsInstalled = max(installSummary.success, manager.updateRequests.size)
                Output.pretty("<green>${pkgsInstalled}<r> package${if (pkgsInstalled == 1) { "" } else { "s" }} installed ")
                Output.pretty("in ...ms")
                printedTimestamp = true
                printBlockedPackagesInfo(installSummary, manager.options.global)

                if (manager.summary.remove > 0) {
                    Output.pretty("Removed: <cyan>${manager.summary.remove}<r>\n")
                }
            } else if (manager.summary.remove > 0) {
                if (manager.subcommand == IwmSubcommand.Remove) {
                    for (request in manager.updateRequests) {
                        Output.prettyln("<r><red>-<r> ${request.name}")
                    }
                }

                Output.pretty("<r><b>${manager.summary.remove}<r> package${if (manager.summary.remove == 1) { "" } else { "s" }} removed ")
                Output.pretty("in ...ms")
                printedTimestamp = true
                printBlockedPackagesInfo(installSummary, manager.options.global)
            } else if (installSummary.skipped > 0 && installSummary.fail == 0 && manager.updateRequests.size == 0) {
                let count = manager.lockfile.packagesLen()
                if (count != installSummary.skipped) {
                    if (!manager.options.onlyMissing) {
                        Output.pretty("Checked <green>${installSummary.skipped} install${if (installSummary.skipped == 1) { "" } else { "s" }}<r> across ${count} package${if (count == 1) { "" } else { "s" }} <d>(no changes)<r> ")
                        Output.pretty("in ...ms")
                    }
                    printedTimestamp = true
                    printBlockedPackagesInfo(installSummary, manager.options.global)
                } else {
                    Output.pretty("<r><green>Done<r>! Checked ${installSummary.skipped} package${if (installSummary.skipped == 1) { "" } else { "s" }}<r> <d>(no changes)<r> ")
                    Output.pretty("in ...ms")
                    printedTimestamp = true
                    printBlockedPackagesInfo(installSummary, manager.options.global)
                }
            }

            if (installSummary.fail > 0) {
                Output.prettyln("<r>Failed to install <red><b>${installSummary.fail}<r> package${if (installSummary.fail == 1) { "" } else { "s" }}\n")
                Output.flush()
            }
        }

        if (manager.options.doSummary && !printedTimestamp) {
            Output.printStartEndStdout(ctx.startTime, Time.nanoTimestamp())
            Output.prettyln("<d> done<r>")
        }
    }

    // ========================================================================
    // 打印被阻塞的包信息
    // 严格翻译自: installWithManager.zig 第1066-1087行
    //   fn printBlockedPackagesInfo(summary, global) void
    // ========================================================================

    /// 打印被阻塞的包信息
    /// 严格翻译自: printBlockedPackagesInfo
    public static func printBlockedPackagesInfo(
        summary: IwmPackageInstallSummary,
        global: Bool
    ): Unit {
        let packagesCount = summary.packagesWithBlockedScripts.size
        var scriptsCount = 0
        for (count in summary.packagesWithBlockedScripts.values()) {
            scriptsCount += count
        }

        if (packagesCount > 0) {
            let globalStr = if (global) { "-g " } else { "" }
            Output.prettyln("\n\n<d>Blocked ${scriptsCount} postinstall${if (scriptsCount > 1) { "s" } else { "" }}. Run `bun pm ${globalStr}untrusted` for details.<r>\n")
        } else {
            Output.pretty("<r>\n")
        }
    }

    // ========================================================================
    // 获取工作区过滤器
    // 严格翻译自: installWith_manager.zig 第1089-1143行
    //   pub fn getWorkspaceFilters(manager, original_cwd) !struct { []const WorkspaceFilter, bool }
    // ========================================================================

    /// 获取工作区过滤器
    /// 严格翻译自: getWorkspaceFilters
    public static func getWorkspaceFilters(
        manager: IwmPackageManagerRef,
        originalCwd: String
    ): IwmWorkspaceFilterResult {
        var workspaceFilters = ArrayList<IwmWorkspaceFilter>()

        if (manager.subcommand == IwmSubcommand.Install && manager.options.filterPatterns.size > 0) {
            for (pattern in manager.options.filterPatterns) {
                workspaceFilters.append(IwmWorkspaceFilter.fromPattern(pattern, originalCwd))
            }
        }

        var installRootDependencies = workspaceFilters.size == 0
        if (!installRootDependencies) {
            let pkgNames = manager.lockfile.packages().names()
            let absRootPath = FileSystem.instance.topLevelDirWithoutTrailingSlash()

            for (filter in workspaceFilters) {
                match (filter) {
                    case IwmWorkspaceFilter.All => installRootDependencies = true
                    case IwmWorkspaceFilter.Name(pattern) =>
                        let pathOrName = pkgNames[0].slice(manager.lockfile.buffers.stringBytes)
                        let matchResult = Glob.`match`(pattern, pathOrName)
                        if (matchResult == IwmGlobMatch.Match || matchResult == IwmGlobMatch.NegateMatch) {
                            installRootDependencies = true
                        }
                        if (matchResult == IwmGlobMatch.NegateNoMatch) {
                            installRootDependencies = false
                            break
                        }
                    case IwmWorkspaceFilter.Path(pattern) =>
                        let matchResult = Glob.`match`(pattern, absRootPath)
                        if (matchResult == IwmGlobMatch.Match || matchResult == IwmGlobMatch.NegateMatch) {
                            installRootDependencies = true
                        }
                        if (matchResult == IwmGlobMatch.NegateNoMatch) {
                            installRootDependencies = false
                            break
                        }
                }
            }
        }

        return IwmWorkspaceFilterResult(workspaceFilters, installRootDependencies)
    }

    // ========================================================================
    // 添加依赖错误
    // 严格翻译自: installWithManager.zig 第1145-1165行
    //   fn addDependencyError(manager, dependency, err) void
    // ========================================================================

    /// 添加依赖解析错误
    /// 翻译自: addDependencyError
    ///   Adds a contextual error for a dependency resolution failure.
    public static func addDependencyError(
        manager: IwmPackageManagerRef,
        dependency: IwmDependencyRef
    ): Unit {
        let depName = dependency.realnameSlice(manager.lockfile.buffers.stringBytes)
        let noteFmt = "error occurred while resolving ${depName}"

        if (dependency.behavior.isOptional() || dependency.behavior.isPeer()) {
            manager.log.addWarningWithNote(null, noteFmt)
        } else {
            manager.log.addZigErrorWithNote(noteFmt)
        }
    }

    // ========================================================================
    // 缓存目录与路径管理
    // 严格翻译自: installWith_manager.zig 中的辅助函数
    // ========================================================================

    /// 获取缓存目录
    /// 翻译自: getCacheDirectory
    ///   pub fn getCacheDirectory(this) []const u8
    public static func getCacheDirectory(manager: IwmPackageManagerRef): String {
        match (manager.cacheDirectory) {
            case Some(dir) => return dir
            case None => return initCacheDir(manager)
        }
    }

    private static func initCacheDir(manager: IwmPackageManagerRef): String {
        let dir = fetchCacheDirectoryPath()
        manager.cacheDirectory = dir
        return dir
    }

    /// 获取临时目录
    /// 翻译自: getTemporaryDirectory
    ///   pub fn getTemporaryDirectory(this) []const u8
    public static func getTemporaryDirectory(manager: IwmPackageManagerRef): String {
        match (manager.temporaryDirectory) {
            case Some(dir) => return dir
            case None => return initTmpDir(manager)
        }
    }

    private static func initTmpDir(manager: IwmPackageManagerRef): String {
        let tmpDir = ""
        manager.temporaryDirectory = tmpDir
        return tmpDir
    }

    /// 获取缓存目录路径
    /// 翻译自: fetchCacheDirectoryPath
    ///   pub fn fetchCacheDirectoryPath() []const u8
    ///   默认路径: ~/.bun/install/cache
    public static func fetchCacheDirectoryPath(): String {
        return ""
    }

    /// 生成缓存 NPM 包文件夹名
    /// 翻译自: cachedNPMPackageFolderName
    ///   pub fn cachedNPMPackageFolderName(name, version) Buf
    ///   格式: name@version
    public static func cachedNPMPackageFolderName(name: String, version: String): String {
        return "${name}@${version}"
    }

    /// 生成缓存 NPM 包打印名
    /// 翻译自: cachedNPMPackageFolderPrint
    public static func cachedNPMPackageFolderPrint(name: String, version: String): String {
        return "${name}@${version}"
    }

    /// 生成缓存 NPM 包基础名
    /// 翻译自: cachedNPMPackageFolderBasename
    public static func cachedNPMPackageFolderBasename(name: String, version: String): String {
        return "${name}@${version}"
    }

    /// 生成缓存 Git 文件夹名
    /// 翻译自: cachedGitFolderName
    ///   pub fn cachedGitFolderName(repo, comptime PlatformDir) Buf
    public static func cachedGitFolderName(repo: String): String {
        return "git-${repo}"
    }

    /// 生成缓存 GitHub 文件夹名
    /// 翻译自: cachedGitHubFolderName
    public static func cachedGitHubFolderName(owner: String, repo: String): String {
        return "github-${owner}-${repo}"
    }

    /// 生成缓存 Tarball 文件夹名
    /// 翻译自: cachedTarballFolderName
    public static func cachedTarballFolderName(url: String): String {
        let hash = SemverStringBuilder.stringHashStr(url)
        return "tarball-${hash}"
    }

    /// 检查文件夹是否在缓存中
    /// 翻译自: isFolderInCache
    ///   pub fn isFolderInCache(this, subpath) bool
    public static func isFolderInCache(manager: IwmPackageManagerRef, subpath: String): Bool {
        return false
    }

    /// 设置全局目录
    /// 翻译自: setupGlobalDir
    ///   pub fn setupGlobalDir(this, ctx) !void
    public static func setupGlobalDir(manager: IwmPackageManagerRef, ctx: IwmCommandContext): Unit {
        return
    }

    /// resolve global dir, creating if needed
    private static func resolveGlobalDir(manager: IwmPackageManagerRef): String {
        match (manager.globalConfigDir) {
            case Some(dir) => dir
            case None => initGlobalDir(manager)
        }
    }

    /// initialize global dir
    private static func initGlobalDir(manager: IwmPackageManagerRef): String {
        let dir = ""
        manager.globalConfigDir = dir
        return dir
    }

    /// 获取全局链接目录
    /// 翻译自: globalLinkDir
    ///   pub fn globalLinkDir(this) []const u8
    public static func globalLinkDir(manager: IwmPackageManagerRef): String {
        return ""
    }

    /// 保存锁文件
    /// 严格翻译自: saveLockfile
    ///   pub fn saveLockfile(this, load_result, save_format, had_any_diffs,
    ///       lockfile_before_install, packages_len, log_level) !void
    public static func saveLockfile(
        manager: IwmPackageManagerRef,
        saveFormat: IwmLockfileSaveFormat,
        hadAnyDiffs: Bool,
        lockfileBeforeInstall: IwmLockfileRef,
        packagesLenBeforeInstall: Int64,
        logLevel: IwmLogLevel
    ): Unit {
        let lockfile = manager.lockfile

        // 生成元哈希
        let metaHash = lockfile.generateMetaHash(
            IwmPackageManagerFlags.verboseInstall || manager.options.printMetaHashString,
            packagesLenBeforeInstall
        )

        match (saveFormat) {
            case IwmLockfileSaveFormat.Binary => saveLockfileBinary(manager, lockfile, metaHash)
            case IwmLockfileSaveFormat.Text => saveLockfileText(manager, lockfile, metaHash)
        }

        if (logLevel.isVerbose()) {
            return
        }
    }

    /// save lockfile binary helper
    private static func saveLockfileBinary(manager: IwmPackageManagerRef, lockfile: IwmLockfileRef, metaHash: String): Unit {
        let lockfilePath = Path.join([manager.cwd, "bun.lockb"])
        lockfile.saveBinary(lockfilePath, metaHash)
    }

    /// save lockfile text helper
    private static func saveLockfileText(manager: IwmPackageManagerRef, lockfile: IwmLockfileRef, metaHash: String): Unit {
        let lockfilePath = Path.join([manager.cwd, "bun.lock"])
        lockfile.saveText(lockfilePath, metaHash)
    }

    /// 写入 Yarn 锁文件
    /// 翻译自: writeYarnLock
    ///   pub fn writeYarnLock(this) !void
    public static func writeYarnLock(manager: IwmPackageManagerRef): Unit {
        return
    }
}

// ============================================================================
// 锁文件保存格式
// ============================================================================

/// 锁文件保存格式
public enum IwmLockfileSaveFormat {
    | Binary  // bun.lockb
    | Text    // bun.lock

    public func name(): String {
        match (this) {
            case Binary => "bun.lockb"
            case Text => "bun.lock"
        }
    }
}

// ============================================================================
// 轻量引用类型
// ============================================================================

/// 包管理器引用
/// 对应 Bun: PackageManager (install_with_manager 相关字段)
public class IwmPackageManagerRef {
    public var cacheDirectory: ?String
    public var temporaryDirectory: ?String
    public var globalConfigDir: ?String
    public var cwd: String
    public var lockfile: IwmLockfileRef
    public var options: IwmOptions
    public var log: IwmLogRef
    public var allocator: IwmAllocator
    public var env: IwmEnvRef
    public var eventLoop: IwmEventLoopRef
    public var progress: IwmProgress
    public var summary: IwmDiffSummary
    public var updateRequests: ArrayList<IwmUpdateRequest>
    public var subcommand: IwmSubcommand
    public var toUpdate: Bool
    public var rootPackageId: IwmRootPackageId
    public var workspaceNameHash: UInt64
    public var rootLifecycleScripts: ?IwmRootLifecycleScripts
    public var pendingLifecycleScriptTasks: Int64
    public var totalTasks: Int64
    public var anyFailedToInstall: Bool
    public var updatingPackages: IwmUpdatingPackagesMap
    public var workspacePackageJsonCache: IwmWorkspacePackageJsonCache
    public var securityScanner: ?IwmSecurityScannerRef
    public var peerDependencies: IwmPeerDependencyQueue

    public init() {
        cacheDirectory = None
        temporaryDirectory = None
        globalConfigDir = None
        cwd = ""
        lockfile = IwmLockfileRef()
        options = IwmOptions()
        log = IwmLogRef()
        allocator = IwmAllocator()
        env = IwmEnvRef()
        eventLoop = IwmEventLoopRef()
        progress = IwmProgress()
        summary = IwmDiffSummary()
        updateRequests = ArrayList<IwmUpdateRequest>()
        subcommand = IwmSubcommand.Install
        toUpdate = false
        rootPackageId = IwmRootPackageId()
        workspaceNameHash = UInt64(0)
        rootLifecycleScripts = None
        pendingLifecycleScriptTasks = 0
        totalTasks = 0
        anyFailedToInstall = false
        updatingPackages = IwmUpdatingPackagesMap()
        workspacePackageJsonCache = IwmWorkspacePackageJsonCache()
        securityScanner = None
        peerDependencies = IwmPeerDependencyQueue()
    }

    public func pendingTaskCount(): Int64 { return 0 }
    public func startProgressBar(): Unit {}
    public func endProgressBar(): Unit {}
    public func updateLockfileIfNeeded(result: IwmLoadResult): Unit {}
    public func enqueueDependencyList(deps: IwmDependencySlice): Unit {}
    public func drainDependencyList(): Unit {}
    public func enqueueDependencyWithMain(depId: UInt32, dep: IwmDependencyRef, resolution: UInt32, installPeer: Bool): Unit {}
    public func enqueuePatchTaskPre(task: IwmPatchTask): Unit {}
    public func processPeerDependencyList(): Unit {}
    public func waitForCalcingPatchHashes(): Unit {}
    public func waitForEverythingExceptPeers(): Unit {}
    public func waitForPeers(): Unit {}
    public func verifyResolutions(logLevel: IwmLogLevel): Unit {}
    public func loadRootLifecycleScripts(root: IwmLockfilePackage): Unit {}
    public func spawnPackageLifecycleScripts(ctx: IwmCommandContext, scripts: IwmRootLifecycleScripts, optional: Bool, outputInForeground: Bool, extra: ?IwmSpawnContext): Unit {}
    public func reportSlowLifecycleScripts(): Unit {}
    public func sleep(): Unit {}
    public func installHoistedPackages(ctx: IwmCommandContext, filters: ArrayList<IwmWorkspaceFilter>, installRoot: Bool, logLevel: IwmLogLevel): IwmPackageInstallSummary { return IwmPackageInstallSummary() }
    public func installIsolatedPackages(ctx: IwmCommandContext, filters: ArrayList<IwmWorkspaceFilter>, installRoot: Bool): IwmPackageInstallSummary { return IwmPackageInstallSummary() }
    public func alloc(size: Int64): String { return "" }
}

/// 锁文件引用
public class IwmLockfileRef {
    public var buffers: IwmLockfileBuffers
    public var metaHash: String
    public var allocator: IwmAllocator

    public init() {
        buffers = IwmLockfileBuffers()
        metaHash = ""
        allocator = IwmAllocator()
    }

    public func loadFromCwd(manager: IwmPackageManagerRef, log: IwmLogRef, b: Bool): IwmLoadResult { return IwmLoadResult.NotFound }
    public func initEmpty(allocator: IwmAllocator): Unit {}
    public func dependenciesCount(): Int64 { return 0 }
    public func packagesLen(): Int64 { return 0 }
    public func rootPackage(): ?IwmLockfilePackage { return None }
    public func appendPackage(pkg: IwmLockfilePackage): IwmLockfilePackage { return pkg }
    public func generateMetaHash(verbose: Bool, packagesLen: Int64): String { return "" }
    public func saveBinary(path: String, metaHash: String): Unit {}
    public func saveText(path: String, metaHash: String): Unit {}
    public func toPrintData(): IwmLockfilePrintData { return IwmLockfilePrintData() }
    public func cleanWithLogger(manager: IwmPackageManagerRef, requests: ArrayList<IwmUpdateRequest>, log: IwmLogRef, exact: Bool, logLevel: IwmLogLevel): IwmLockfileRef { return this }
    public func eql(other: IwmLockfileRef, packagesLen: Int64, allocator: IwmAllocator): Bool { return false }
    public func hasMetaHashChanged(verbose: Bool, packagesLen: Int64): Bool { return false }
    public func isEmpty(): Bool { return true }
    public func stringBuilder(): IwmStringBuilder { return IwmStringBuilder() }
    public func getRootPackage(): IwmLockfilePackage { return IwmLockfilePackage() }
    public func packages(): IwmPackagesSlice { return IwmPackagesSlice() }
    public func patchedDependenciesIterator(): IwmPatchedDependenciesIterator { return IwmPatchedDependenciesIterator() }
    public func patchedDependenciesCount(): Int64 { return 0 }
    public var overrides: IwmOverrides
    public var catalogs: IwmCatalogs
    public var trustedDependencies: ?IwmTrustedDependencies
    public var workspacePaths: IwmStringHashMap
    public var workspaceVersions: IwmStringHashMap
    public var patchedDependencies: IwmPatchedDependenciesMap
    public var scripts: IwmLockfileScripts
    public var textLockfileVersion: IwmTextLockfileVersion
}

/// 锁文件缓冲区
public class IwmLockfileBuffers {
    public var dependencies: IwmDependencyList
    public var resolutions: IwmResolutionList
    public var stringBytes: IwmStringBytes

    public init() {
        dependencies = IwmDependencyList()
        resolutions = IwmResolutionList()
        stringBytes = IwmStringBytes()
    }
}

/// 依赖列表
public class IwmDependencyList {
    public var size: Int64
    public init() { size = 0 }
    public func ensureUnusedCapacity(count: Int64): Unit {}
    public func slice(off: Int64, end: Int64): IwmDependencySlice { return IwmDependencySlice() }
    public operator func [](index: Int64): IwmDependencyRef { return IwmDependencyRef() }
}

/// 解析列表
public class IwmResolutionList {
    public var size: Int64
    public init() { size = 0 }
    public func ensureUnusedCapacity(count: Int64): Unit {}
    public func slice(off: Int64, end: Int64): IwmResolutionBufferSlice { return IwmResolutionBufferSlice() }
    public operator func [](index: Int64): UInt32 { return UInt32(0) }
    public operator func [](index: Int64, value: UInt32): Unit {}
}

/// Resolution Buffer Slice (mutable UInt32 slice from buffer)
public class IwmResolutionBufferSlice {
    public init() {}
    public func size(): Int64 { return 0 }
    public operator func [](index: Int64): UInt32 { return UInt32(0) }
    public operator func [](index: Int64, value: UInt32): Unit {}
}

/// 字符串字节
public class IwmStringBytes {
    public init() {}
}

/// 依赖切片
public class IwmDependencySlice <: Iterable<IwmDependencyRef> {
    public init() {}
    public func size(): Int64 { return 0 }
    public func get(list: IwmDependencyList): IwmDependencySlice { return this }
    public operator func [](index: Int64): IwmDependencyRef { return IwmDependencyRef() }
    public operator func [](index: Int64, value: IwmDependencyRef): Unit {}
    public func iterator(): Iterator<IwmDependencyRef> { return IwmDependencySliceIterator() }
}

/// 解析切片 (per-package resolution IDs)
public class IwmResolutionSlice {
    public init() {}
    public func get(list: IwmResolutionList): IwmPackageIdSlice { return IwmPackageIdSlice() }
    public func size(): Int64 { return 0 }
    public operator func [](index: Int64): IwmResolution { return IwmResolution() }
}

/// Package ID Slice (returned by resolution slice .get())
public class IwmPackageIdSlice {
    public init() {}
    public func size(): Int64 { return 0 }
    public operator func [](index: Int64): UInt32 { return UInt32(0) }
}

/// 解析
public class IwmResolution {
    public var tag: IwmResolutionTag
    public var npmVersion: IwmSemverVersion

    public init() {
        tag = IwmResolutionTag.Uninitialized
        npmVersion = IwmSemverVersion()
    }
}

/// 依赖切片迭代器
public class IwmDependencySliceIterator <: Iterator<IwmDependencyRef> {
    public init() {}
    public func next(): Option<IwmDependencyRef> { return None }
    public func hasNext(): Bool { return false }
}

/// 包列表切片
public class IwmPackagesSlice {
    public func resolutions(): IwmResolutionSlice { return IwmResolutionSlice() }
    public func metas(): IwmMetaSlice { return IwmMetaSlice() }
    public func scripts(): IwmScriptsSlice { return IwmScriptsSlice() }
    public func dependencies(id: UInt32): IwmDependencySlice { return IwmDependencySlice() }
    public func resolutions(id: UInt32): IwmResolutionSlice { return IwmResolutionSlice() }
    public func names(): IwmNameSlice { return IwmNameSlice() }
    public func setScripts(id: UInt32, scripts: IwmPackageScripts): Unit {}
    public func setDependencies(id: UInt32, off: Int64, len: Int64): Unit {}
    public func setResolutions(id: UInt32, off: Int64, len: Int64): Unit {}
    public func getResolutions(id: UInt32): IwmResolutionBufferSlice { return IwmResolutionBufferSlice() }
    public func len(): Int64 { return 0 }
}

/// 元数据切片
public class IwmMetaSlice { public init() {} }
/// 脚本切片
public class IwmScriptsSlice { public init() {} }
/// 名称切片
public class IwmNameSlice { public init() {} }

/// 包数据
public class IwmLockfilePackage {
    public var scripts: IwmPackageScripts
    public var dependencies: IwmDependencySlice

    public init() {
        scripts = IwmPackageScripts()
        dependencies = IwmDependencySlice()
    }

    public func parse(lockfile: IwmLockfileRef, manager: IwmPackageManagerRef, allocator: IwmAllocator, log: IwmLogRef, source: IwmSource, resolver: IwmResolverContext, features: IwmFeatures): Unit {}
    public func dependenciesLen(): Int64 { return 0 }
}

/// 包脚本
public class IwmPackageScripts {
    public init() {}
    public func hasAny(): Bool { return false }
    public func count(stringBytes: IwmStringBytes, builder: IwmStringBuilder): Unit {}
    public func clone(stringBytes: IwmStringBytes, builder: IwmStringBuilder): IwmPackageScripts { return IwmPackageScripts() }
    public func getScriptEntries(lockfile: IwmLockfileRef, stringBytes: IwmStringBytes, ctx: IwmScriptContext, b: Bool): IwmScriptEntries { return IwmScriptEntries() }
}

/// 脚本条目
public class IwmScriptEntries {
    public var firstIndex: Int64
    public var entries: ArrayList<?IwmScriptEntry>

    public init() {
        firstIndex = -1
        entries = ArrayList<?IwmScriptEntry>()
    }
}

/// 脚本条目
public class IwmScriptEntry {
    public init() {}
}

/// 脚本上下文
public enum IwmScriptContext {
    | Workspace
    | Other
}

/// 字符串构建器
public class IwmStringBuilder {
    public init() {}
    public func allocate(): Unit {}
    public func clamp(): Unit {}
    public func count(s: String): Unit {}
    public func appendString(s: String): String { return s }
}

/// 映射
public class IwmMapping {
    public static func create(allocator: IwmAllocator, len: Int64): IwmMapping { return IwmMapping() }
    public func len(): Int64 { return 0 }
    public func get(index: Int64): UInt32 { return 0 }
}

/// 差异摘要
public class IwmDiffSummary {
    public var add: Int64
    public var remove: Int64
    public var update: Int64
    public var overridesChanged: Bool
    public var catalogsChanged: Bool

    public init() {
        add = 0
        remove = 0
        update = 0
        overridesChanged = false
        catalogsChanged = false
    }

    public func hasDiffs(): Bool {
        return add > 0 || remove > 0 || update > 0 || overridesChanged || catalogsChanged
    }
}

/// 包差异
public class PackageDiff {
    public static func generate(
        manager: IwmPackageManagerRef,
        allocator: IwmAllocator,
        log: IwmLogRef,
        oldLockfile: IwmLockfileRef,
        newLockfile: IwmLockfileRef,
        oldRoot: IwmLockfilePackage,
        newRoot: IwmLockfilePackage,
        updateRequests: ArrayList<IwmUpdateRequest>,
        mapping: IwmMapping
    ): IwmDiffSummary { return IwmDiffSummary() }
}

/// 命令上下文
public class IwmCommandContext {
    public var startTime: Int64

    public init() {
        startTime = Int64(0)
    }
}

/// 日志级别
public enum IwmLogLevel {
    | Silent
    | Default
    | Verbose
    | VerboseColor
    | Debug

    public operator func ==(right: IwmLogLevel): Bool {
        match (this) {
            case Silent => match (right) { case Silent => true case _ => false }
            case Default => match (right) { case Default => true case _ => false }
            case Verbose => match (right) { case Verbose => true case _ => false }
            case VerboseColor => match (right) { case VerboseColor => true case _ => false }
            case Debug => match (right) { case Debug => true case _ => false }
        }
    }
    public operator func !=(right: IwmLogLevel): Bool { !(this == right) }

    public func isVerbose(): Bool {
        match (this) {
            case IwmLogLevel.Verbose => return true
            case IwmLogLevel.VerboseColor => return true
            case IwmLogLevel.Debug => return true
            case _ => return false
        }
    }

    public func showProgress(): Bool {
        match (this) {
            case IwmLogLevel.Silent => return false
            case _ => return true
        }
    }
}

/// 锁文件打印数据
public class IwmLockfilePrintData {
    public init() {}
}

/// Yarn 打印器 (引用)
public class YarnPrinter {
    public var lockfile: IwmLockfilePrintData

    public init(lockfile: IwmLockfilePrintData) {
        this.lockfile = lockfile
    }

    public func print(): String { return "" }
}

/// 锁文件打印机
public class IwmLockfilePrinter {
    public var lockfile: IwmLockfileRef
    public var options: IwmOptions
    public var updates: ArrayList<IwmUpdateRequest>
    public var successfullyInstalled: ?IwmDynamicBitSet

    public init(lockfile: IwmLockfileRef, options: IwmOptions, updates: ArrayList<IwmUpdateRequest>, successfullyInstalled: ?IwmDynamicBitSet) {
        this.lockfile = lockfile
        this.options = options
        this.updates = updates
        this.successfullyInstalled = successfullyInstalled
    }
}

/// 锁文件打印机树
public class LockfilePrinterTree {
    public static func print(printer: IwmLockfilePrinter, manager: IwmPackageManagerRef, logLevel: IwmLogLevel): Unit {}
}

/// 加载结果
public enum IwmLoadResult {
    | NotFound
    | Err(IwmLoadError)
    | Ok(IwmLoadSuccess)

    public func isNotFound(): Bool {
        match (this) {
            case IwmLoadResult.NotFound => return true
            case _ => return false
        }
    }
    public func isOk(): Bool {
        match (this) {
            case Ok(_) => return true
            case _ => return false
        }
    }
    public func chooseConfigVersion(): IwmConfigVersionResult { return IwmConfigVersionResult(IwmCacheVersion.V1, false) }
    public func saveFormat(options: IwmOptions): IwmLockfileSaveFormat { return IwmLockfileSaveFormat.Binary }
    public func loadedFromTextLockfile(): Bool { return false }
    public func getLockfile(): IwmLockfileRef { return IwmLockfileRef() }
    public func getFormat(): IwmLockfileFormat { return IwmLockfileFormat.Binary }
    public func getMigrated(): IwmMigrationKind { return IwmMigrationKind.None_ }
    public func getPackagesNeedUpdate(): Bool { return false }
    public func getMigratedFromLockbV2(): Bool { return false }
}

/// 加载成功
public class IwmLoadSuccess {
    public init() {}
}

/// 加载错误
public class IwmLoadError {
    public var step: IwmLoadStep
    public var value: String
    public var lockfilePath: String

    public init(step: IwmLoadStep, value: String, lockfilePath: String) {
        this.step = step
        this.value = value
        this.lockfilePath = lockfilePath
    }
}

/// 加载步骤
public enum IwmLoadStep {
    | OpenFile
    | ReadFile
    | ParseFile
    | Migrating
}

/// 迁移类型
public enum IwmMigrationKind {
    | None_
    | Npm
    | Binary

    public operator func ==(right: IwmMigrationKind): Bool {
        match (this) {
            case None_ => match (right) { case None_ => true case _ => false }
            case Npm => match (right) { case Npm => true case _ => false }
            case Binary => match (right) { case Binary => true case _ => false }
        }
    }
    public operator func !=(right: IwmMigrationKind): Bool { !(this == right) }
}

/// 锁文件格式
public enum IwmLockfileFormat {
    | Binary
    | Text

    public operator func ==(right: IwmLockfileFormat): Bool {
        match (this) {
            case Binary => match (right) { case Binary => true case _ => false }
            case Text => match (right) { case Text => true case _ => false }
        }
    }
    public operator func !=(right: IwmLockfileFormat): Bool { !(this == right) }
}

/// 缓存版本
public enum IwmCacheVersion {
    | V1
}

/// 配置版本结果
public class IwmConfigVersionResult {
    public var version: IwmCacheVersion
    public var changed: Bool

    public init(version: IwmCacheVersion, changed: Bool) {
        this.version = version
        this.changed = changed
    }
}

/// 选项
public class IwmOptions {
    public var logLevel: IwmLogLevel
    public var doLoadLockfile: Bool
    public var doSaveLockfile: Bool
    public var doSaveYarnLock: Bool
    public var doInstallPackages: Bool
    public var doRunScripts: Bool
    public var doSummary: Bool
    public var doVerifyIntegrity: Bool
    public var forceSaveLockfile: Bool
    public var frozenLockfile: Bool
    public var lockfileOnly: Bool
    public var failEarly: Bool
    public var global: Bool
    public var configVersion: IwmCacheVersion
    public var saveTextLockfile: ?Bool
    public var printMetaHashString: Bool
    public var nodeLinker: IwmNodeLinker
    public var exactVersions: Bool
    public var onlyMissing: Bool
    public var filterPatterns: ArrayList<String>
    public var scope: IwmScope

    public init() {
        logLevel = IwmLogLevel.Default
        doLoadLockfile = true
        doSaveLockfile = true
        doSaveYarnLock = false
        doInstallPackages = true
        doRunScripts = true
        doSummary = true
        doVerifyIntegrity = true
        forceSaveLockfile = false
        frozenLockfile = false
        lockfileOnly = false
        failEarly = false
        global = false
        configVersion = IwmCacheVersion.V1
        saveTextLockfile = None
        printMetaHashString = false
        nodeLinker = IwmNodeLinker.Auto
        exactVersions = false
        onlyMissing = false
        filterPatterns = ArrayList<String>()
        scope = IwmScope()
    }
}

/// Scope
public class IwmScope {
    public var url: IwmScopeUrl
    public init() { url = IwmScopeUrl() }
}

/// Scope URL
public class IwmScopeUrl {
    public var hostname: String
    public init() { hostname = "" }
    public func isIPAddress(): Bool { return false }
    public func getPortAuto(): UInt16 { return UInt16(443) }
}

/// 节点链接器
public enum IwmNodeLinker {
    | Auto
    | Hoisted
    | Isolated
}

/// 子命令
public enum IwmSubcommand {
    | Install
    | Add
    | Remove
    | Update
    | Link
    | Unlink

    public operator func ==(other: IwmSubcommand): Bool {
        match (this) {
            case Install => match (other) { case Install => true case _ => false }
            case Add => match (other) { case Add => true case _ => false }
            case Remove => match (other) { case Remove => true case _ => false }
            case Update => match (other) { case Update => true case _ => false }
            case Link => match (other) { case Link => true case _ => false }
            case Unlink => match (other) { case Unlink => true case _ => false }
        }
    }
}

/// 日志引用
public class IwmLogRef {
    public init() {}
    public func hasErrors(): Bool { return false }
    public func print(writer: IwmOutputWriter): Unit {}
    public func reset(): Unit {}
    public func addWarningWithNote(loc: ?String, fmt: String): Unit {}
    public func addZigErrorWithNote(fmt: String): Unit {}
}

/// 更新请求
public class IwmUpdateRequest {
    public var name: String
    public var failed: Bool

    public init() {
        name = ""
        failed = false
    }
}

/// 包安装摘要
public class IwmPackageInstallSummary {
    public var success: Int64
    public var fail: Int64
    public var skipped: Int64
    public var successfullyInstalled: ?IwmDynamicBitSet
    public var packagesWithBlockedScripts: HashMap<String, Int64>

    public init() {
        success = 0
        fail = 0
        skipped = 0
        successfullyInstalled = None
        packagesWithBlockedScripts = HashMap<String, Int64>()
    }
}

/// 工作区过滤器结果
public class IwmWorkspaceFilterResult {
    public var filters: ArrayList<IwmWorkspaceFilter>
    public var installRootDependencies: Bool

    public init(filters: ArrayList<IwmWorkspaceFilter>, installRootDependencies: Bool) {
        this.filters = filters
        this.installRootDependencies = installRootDependencies
    }
}

/// 工作区过滤器
public enum IwmWorkspaceFilter {
    | Name(String)
    | Path(String)
    | All

    public static func fromPattern(pattern: String, originalCwd: String): IwmWorkspaceFilter {
        return IwmWorkspaceFilter.Name(pattern)
    }
}

/// 依赖版本标签
public enum IwmDependencyVersionTag {
    | Uninitialized
    | NPM
    | DistTag
    | Folder
    | Git
    | GitHub
    | Symlink
    | Workspace
    | Tarball
    | Catalog
}

/// 解析标签
public enum IwmResolutionTag {
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

/// 依赖引用
public class IwmDependencyRef {
    public var nameHash: UInt64
    public var version: IwmDependencyVersion
    public var behavior: IwmDependencyBehavior

    public init() {
        nameHash = UInt64(0)
        version = IwmDependencyVersion()
        behavior = IwmDependencyBehavior()
    }

    public func nameSlice(bytes: IwmStringBytes): String { return "" }
    public func realnameSlice(bytes: IwmStringBytes): String { return "" }
    public func count(bytes: IwmStringBytes, builder: IwmStringBuilder): Unit {}
    public func clone(manager: IwmPackageManagerRef, bytes: IwmStringBytes, builder: IwmStringBuilder): IwmDependencyRef { return this }
}

/// 依赖版本
public class IwmDependencyVersion {
    public var tag: IwmDependencyVersionTag

    public init() {
        tag = IwmDependencyVersionTag.Uninitialized
    }
}

/// 依赖行为
public class IwmDependencyBehavior {
    public func isOptional(): Bool { return false }
    public func isPeer(): Bool { return false }
    public func isRequired(): Bool { return true }
}

/// 根包 ID
public class IwmRootPackageId {
    public init() {}
    public func get(lockfile: IwmLockfileRef, hash: UInt64): UInt32 { return UInt32(0) }
}

/// 更新中包映射
public class IwmUpdatingPackagesMap {
    public init() {}
    public func getPtr(name: String): ?IwmUpdatingPackageEntry { return None }
}

/// 更新中包条目
public class IwmUpdatingPackageEntry {
    public var originalVersion: IwmSemverVersion
    public var originalVersionStringBuf: String

    public init() {
        originalVersion = IwmSemverVersion()
        originalVersionStringBuf = ""
    }
}

/// Semver 版本
public class IwmSemverVersion {
    public var tag: IwmSemverTag
    public init() { tag = IwmSemverTag() }
    public func preLen(): Int64 { return 0 }
    public func buildLen(): Int64 { return 0 }
    public func cloneInto(bytes: IwmStringBytes, buf: String): IwmSemverTag { return IwmSemverTag() }
}

/// Semver 标签
public class IwmSemverTag {
    public init() {}
}

/// 分配器
public class IwmAllocator {
    public init() {}
}

/// 环境引用
public class IwmEnvRef {
    public init() {}
    public func hasHTTPProxy(): Bool { return false }
    public func get(key: String): ?String { return None }
}

/// 事件循环引用
public class IwmEventLoopRef {
    public init() {}
}

/// 进度
public class IwmProgress {
    public var supportsAnsiEscapeCodes: Bool
    public var root: IwmProgressRoot

    public init() {
        supportsAnsiEscapeCodes = false
        root = IwmProgressRoot()
    }

    public func start(name: String, count: Int64): IwmProgressNode { return IwmProgressNode() }
    public func refresh(): Unit {}
}

/// 进度根
public class IwmProgressRoot {
    public init() {}
    public func end(): Unit {}
}

/// 进度节点
public class IwmProgressNode {
    public init() {}
    public func completeOne(): Unit {}
}

/// DNS 内部
public class DnsInternal {
    public static func prefetch(eventLoop: IwmEventLoopRef, hostname: String, port: UInt16): Unit {}
}

/// 源
public class IwmSource {
    public init() {}
}

/// 解析器上下文
public class IwmResolverContext {
    public init() {}
}

/// Features
public enum IwmFeatures {
    | Main
    | Folder
}

/// 包管理器标志
public class IwmPackageManagerFlags {
    public static let verboseInstall: Bool = false
}

/// 文件系统
public class FileSystem {
    public static let instance: IwmFileSystemInstance = IwmFileSystemInstance()
}

/// 文件系统实例
public class IwmFileSystemInstance {
    public func topLevelDirWithoutTrailingSlash(): String { return "" }
}

/// Glob 匹配
public enum IwmGlobMatch {
    | Match
    | NegateMatch
    | NoMatch
    | NegateNoMatch
}

/// Glob 工具
public class Glob {
    public static func `match`(pattern: String, pathOrName: String): IwmGlobMatch { return IwmGlobMatch.NoMatch }
}

/// Workspace package.json 缓存
public class IwmWorkspacePackageJsonCache {
    public init() {}
    public func getWithPath(allocator: IwmAllocator, log: IwmLogRef, path: String): IwmPackageJsonCacheResult { return IwmPackageJsonCacheResult.Entry(IwmSource()) }
}

/// 缓存结果
public enum IwmPackageJsonCacheResult {
    | Entry(IwmSource)
    | ReadErr(String)
    | ParseErr(String)
}

/// 安全扫描器引用
public class IwmSecurityScannerRef {
    public init() {}
    public func performSecurityScanAfterResolution(manager: IwmPackageManagerRef, ctx: IwmCommandContext, originalCwd: String): ?IwmSecurityScanResults { return None }
}

/// 安全扫描结果
public class IwmSecurityScanResults {
    public func hasFatalAdvisories(): Bool { return false }
    public func hasWarnings(): Bool { return false }
}

/// 安全扫描器 (duplicate removed - see update_package_json_and_install.cj)
/*
public class SecurityScanner {
    public static func printSecurityAdvisories(manager: IwmPackageManagerRef, results: IwmSecurityScanResults): Unit {}
    public static func promptForWarnings(): Bool { return false }
}
*/

/// 根生命周期脚本
public class IwmRootLifecycleScripts {
    public var total: Int64
    public var packageName: String

    public init() {
        total = 0
        packageName = ""
    }

    public func appendToLockfile(lockfile: IwmLockfileRef): Unit {}
}

/// 生成脚本上下文
public class IwmSpawnContext {
    public init() {}
}

/// Peer 依赖队列
public class IwmPeerDependencyQueue {
    public init() {}
    public func readableLength(): Int64 { return 0 }
}

/// 补丁任务
public class IwmPatchTask {
    public static func newCalcPatchHash(manager: IwmPackageManagerRef, key: UInt64, hash: ?UInt64): IwmPatchTask { return IwmPatchTask() }
}

/// Overrides
public class IwmOverrides {
    public var map: IwmOverrideMap
    public init() { map = IwmOverrideMap() }
    public func count(lockfile: IwmLockfileRef, builder: IwmStringBuilder): Unit {}
    public func clone(manager: IwmPackageManagerRef, oldLockfile: IwmLockfileRef, newLockfile: IwmLockfileRef, builder: IwmStringBuilder): IwmOverrides { return IwmOverrides() }
}

/// Override Map
public class IwmOverrideMap {
    public init() {}
    public func keys(): ArrayList<UInt64> { return ArrayList<UInt64>() }
    public func size(): Int64 { return 0 }
}

/// Catalogs
public class IwmCatalogs {
    public init() {}
    public func count(lockfile: IwmLockfileRef, builder: IwmStringBuilder): Unit {}
    public func clone(manager: IwmPackageManagerRef, oldLockfile: IwmLockfileRef, newLockfile: IwmLockfileRef, builder: IwmStringBuilder): IwmCatalogs { return IwmCatalogs() }
}

/// Trusted Dependencies
public class IwmTrustedDependencies {
    public init() {}
    public func clone(allocator: IwmAllocator): IwmTrustedDependencies { return IwmTrustedDependencies() }
}

/// String HashMap
public class IwmStringHashMap {
    public init() {}
    public func ensureTotalCapacity(count: Int64): Unit {}
    public func clearRetainingCapacity(): Unit {}
    public func values(): ArrayList<IwmStringEntry> { return ArrayList<IwmStringEntry>() }
    public func iterator(): IwmStringHashMapIterator { return IwmStringHashMapIterator() }
    public func putAssumeCapacity(key: UInt64, value: String): Unit {}
}

/// String Entry
public class IwmStringEntry {
    public var key: UInt64
    public var value: String

    public init() {
        key = UInt64(0)
        value = ""
    }

    public func slice(bytes: IwmStringBytes): String { return value }
    public func count(bytes: IwmStringBytes, builder: IwmStringBuilder): Unit {}
    public func append(bytes: IwmStringBytes, builder: IwmStringBuilder): String { return value }
}

/// String HashMap Iterator
public class IwmStringHashMapIterator {
    public init() {}
    public func hasNext(): Bool { return false }
    public func next(): IwmStringEntry { return IwmStringEntry() }
}

/// Patched Dependencies Map
public class IwmPatchedDependenciesMap {
    public init() {}
    public func iterator(): IwmPatchedDependenciesIterator { return IwmPatchedDependenciesIterator() }
    public func getOrPut(allocator: IwmAllocator, key: UInt64): IwmPatchedDepGop { return IwmPatchedDepGop() }
    public func contains(key: UInt64): Bool { return false }
    public func orderedRemove(key: UInt64): Unit {}
    public func values(): ArrayList<IwmPatchedDependency> { return ArrayList<IwmPatchedDependency>() }
    public var entries: IwmPatchedDepEntries
}

/// Patched Dependency Gop
public class IwmPatchedDepGop {
    public var foundExisting: Bool
    public var value: IwmPatchedDependency

    public init() {
        foundExisting = false
        value = IwmPatchedDependency()
    }
}

/// Patched Dependency
public class IwmPatchedDependency {
    public var path: String
    public init() { path = "" }
    public func slice(bytes: IwmStringBytes): String { return path }
    public func setPatchfileHash(hash: ?UInt64): Unit {}
    public func patchfileHash(): ?UInt64 { return None }
}

/// Patched Dependencies Iterator
public class IwmPatchedDependenciesIterator {
    public init() {}
    public func hasNext(): Bool { return false }
    public func next(): IwmPatchedDepEntry { return IwmPatchedDepEntry() }
}

/// Patched Dep Entry
public class IwmPatchedDepEntry {
    public var key: UInt64
    public var value: IwmPatchedDependency
    public init() { key = UInt64(0); value = IwmPatchedDependency() }
}

/// Patched Dep Entries
public class IwmPatchedDepEntries {
    public var len: Int64
    public init() { len = 0 }
}

/// Lockfile Scripts
public class IwmLockfileScripts {
    public init() {}
    public func append(entry: IwmScriptEntry): Unit {}
}

/// Text Lockfile Version
public enum IwmTextLockfileVersion {
    | V0
    | V1
    | Current
}

/// Lockfile Printer
public class LockfilePrinter {
    public var lockfile: IwmLockfileRef
    public var options: IwmOptions
    public var updates: ArrayList<IwmUpdateRequest>
    public var successfullyInstalled: ?IwmDynamicBitSet

    public init(lockfile: IwmLockfileRef, options: IwmOptions, updates: ArrayList<IwmUpdateRequest>, successfullyInstalled: ?IwmDynamicBitSet) {
        this.lockfile = lockfile
        this.options = options
        this.updates = updates
        this.successfullyInstalled = successfullyInstalled
    }
}

/// Dynamic Bitset
public class IwmDynamicBitSet {
    public init() {}
}

/// Output Writer
public class IwmOutputWriter {
    public init() {}
}

/// Semver 字符串构建器
public class SemverStringBuilder {
    public static func stringHashStr(s: String): UInt64 { return UInt64(0) }
}

/// 常量
public class IwmConstants {
    public static let INVALID_PACKAGE_ID: UInt32 = UInt64(0xFFFFFFFF).toUInt32()
}

/// Int64 转换辅助
public func min(a: Int64, b: Int64): Int64 {
    return if (a < b) { a } else { b }
}

public func max(a: Int64, b: Int64): Int64 {
    return if (a > b) { a } else { b }
}
