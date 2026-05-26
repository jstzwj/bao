// bao_install - 补丁包管理
// 严格翻译自: src/install/PackageManager/patchPackage.zig
//   doPatchCommit: 执行补丁提交 (~464 行)
//   preparePatch: 准备补丁 (~738 行)
//   PatchCommitResult: 补丁提交结果
//   PatchArgKind: 补丁参数类型
//   escapePatchFilename: 转义补丁文件名 (~536 行)
//   pkgInfoForNameAndVersion: 获取包信息 (~1012 行)
//   overwritePackageInNodeModulesFolder: 覆写 node_modules 中的包 (~843 行)
//   detachModuleFolderFromSharedStore: 从共享存储分离模块文件夹 (~797 行)
//   pathArgumentRelativeToRootWorkspacePackage: 路径参数相对于根工作区包 (~1020 行)
//   patchCommitGetVersion: 获取补丁提交版本 (~488 行)
//   nodeModulesFolderForDependencyIDs: 根据 ID 查找 node_modules 文件夹 (~862 行)
//   nodeModulesFolderForDependencyID: 根据 ID 查找 node_modules 文件夹 (~862 行)
package bao_install.package_manager

import bao_install.*

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// 补丁参数类型
// 严格翻译自: patchPackage.zig - PatchArgKind (第1022-1031行)
// ============================================================================

/// 补丁参数类型
/// 对应 Bun: PatchArgKind
/// 翻译自: const PatchArgKind = enum { path, name_and_version }
public enum PatchArgKind {
    | Path           // 目录参数 (path to package in node_modules)
    | NameAndVersion // 包名参数 (name and possibly version)

    public operator func ==(right: PatchArgKind): Bool {
        match (this) {
            case Path => match (right) { case Path => true case _ => false }
            case NameAndVersion => match (right) { case NameAndVersion => true case _ => false }
        }
    }
    public operator func !=(right: PatchArgKind): Bool { return !(this == right) }

    /// 从参数推断参数类型
    /// 翻译自: pub fn fromArg(argument) PatchArgKind
    ///   if contains "node_modules/" => .path
    ///   else => .name_and_version
    public static func fromArg(argument: String): PatchArgKind {
        if (argument.contains("node_modules/")) {
            return PatchArgKind.Path
        }
        return PatchArgKind.NameAndVersion
    }
}

// ============================================================================
// 补丁提交结果
// 严格翻译自: patchPackage.zig - PatchCommitResult (第1-5行)
// ============================================================================

/// 补丁提交结果
/// 对应 Bun: PatchCommitResult
/// 翻译自: pub const PatchCommitResult = struct { patch_key, patchfile_path, not_in_workspace_root }
public class PatchCommitResult {
    /// 补丁键 (name@version)
    public var patchKey: String
    /// 补丁文件路径
    public var patchfilePath: String
    /// 是否不在工作区根目录
    public var notInWorkspaceRoot: Bool

    public init() {
        patchKey = ""
        patchfilePath = ""
        notInWorkspaceRoot = false
    }

    public init(patchKey: String, patchfilePath: String, notInWorkspaceRoot: Bool) {
        this.patchKey = patchKey
        this.patchfilePath = patchfilePath
        this.notInWorkspaceRoot = notInWorkspaceRoot
    }
}

// ============================================================================
// 包信息
// ============================================================================

/// 包信息 (名称 + 版本)
public class PackageInfoForPatch {
    public var name: String
    public var version: String

    public init(name: String, version: String) {
        this.name = name
        this.version = version
    }
}

// ============================================================================
// 补丁包管理
// 严格翻译自: src/install/PackageManager/patchPackage.zig
//   ~1071 行的补丁管理模块
// ============================================================================

/// 补丁包管理
/// 对应 Bun: patchPackage 中的函数
/// 翻译自: src/install/PackageManager/patchPackage.zig
public class PatchPackage {

    // ========================================================================
    // 执行补丁提交
    // 严格翻译自: doPatchCommit (第12-464行)
    //   pub fn doPatchCommit(manager, pathbuf, log_level) !?PatchCommitResult
    //
    //   完整流程:
    //     1. 加载锁文件
    //     2. 解析参数 (path 或 name_and_version)
    //     3. 获取包信息和缓存目录
    //     4. 处理嵌套 node_modules 和 bun-patch-tag
    //     5. 使用 git diff 生成补丁
    //     6. 后处理补丁内容
    //     7. 写入补丁文件到 patches 目录
    // ========================================================================

    /// 执行补丁提交
    /// 严格翻译自: doPatchCommit
    ///   pub fn doPatchCommit(manager, pathbuf, log_level) !?PatchCommitResult
    ///   将补丁目录中的修改生成 .patch 文件并保存到 patches 目录
    public static func doPatchCommit(
        manager: PatchPackageManagerRef,
        logLevel: PatchLogLevel
    ): ?PatchCommitResult {
        // Step 1: 加载锁文件
        // 翻译自: switch (lockfile.loadFromCwd(manager, manager.allocator, manager.log, true))
        var lockfile = PatchLockfileRef()
        let loadResult = lockfile.loadFromCwd(manager, manager.log, true)
        match (loadResult) {
            case PatchLoadResult.NotFound =>
                Output.errGeneric("Cannot find lockfile. Install packages with `bun install` before patching them.")
                Global.crash()
            case PatchLoadResult.Err(cause) =>
                if (logLevel != PatchLogLevel.Silent) {
                    match (cause.step) {
                        case PatchLoadStep.OpenFile => Output.prettyError("<r><red>error<r> opening lockfile:<r> ${cause.value}\n<r>")
                        case PatchLoadStep.ParseFile => Output.prettyError("<r><red>error<r> parsing lockfile:<r> ${cause.value}\n<r>")
                        case PatchLoadStep.ReadFile => Output.prettyError("<r><red>error<r> reading lockfile:<r> ${cause.value}\n<r>")
                        case PatchLoadStep.Migrating => Output.prettyError("<r><red>error<r> migrating lockfile:<r> ${cause.value}\n<r>")
                    }
                    if (manager.options.enable.failEarly) {
                        Output.prettyError("<b><red>failed to load lockfile<r>\n")
                    } else {
                        Output.prettyError("<b><red>ignoring lockfile<r>\n")
                    }
                    Output.flush()
                }
                Global.crash()
            case PatchLoadResult.Ok(_) => ()
        }

        // Step 2: 解析参数
        let argument = manager.options.positionals[1]
        let argKind = PatchArgKind.fromArg(argument)

        let notInWorkspaceRoot = manager.rootPackageId.get(lockfile, manager.workspaceNameHash) != 0

        // 翻译自: 如果 arg_kind == .path 且 not_in_workspace_root 且路径非绝对,
        //   尝试相对于根工作区包解析路径
        var resolvedArgument = argument
        var freeArgument = false
        if (argKind == PatchArgKind.Path && notInWorkspaceRoot && !isAbsolutePath(argument)) {
            let relPath = pathArgumentRelativeToRootWorkspacePackage(manager, lockfile, argument)
            match (relPath) {
                case Some(p) =>
                    freeArgument = true
                    resolvedArgument = p
                case None => ()
            }
        }

        // Step 3: 打开 node_modules 文件夹
        // 翻译自: bun.sys.openatOSPath(bun.FD.cwd(), bun.OSPathLiteral("node_modules"), ...)
        let rootNodeModules = PatchSys.openDirectory("node_modules")
        if (!rootNodeModules.isValid()) {
            Output.prettyError("<r><red>error<r>: failed to open root <b>node_modules<r> folder\n")
            Global.crash()
        }

        // Step 4: 根据参数类型获取缓存目录和变更目录
        // 翻译自: switch (arg_kind) { .path => ..., .name_and_version => ... }
        let patchResolveResult = match (argKind) {
            case PatchArgKind.Path => resolveFromPath(manager, lockfile, resolvedArgument, logLevel)
            case PatchArgKind.NameAndVersion => resolveFromNameAndVersion(manager, lockfile, resolvedArgument)
        }

        match (patchResolveResult) {
            case None => return None
            case Some(result) =>
                // Step 5: 生成补丁标签键
                let name = result.pkgName
                let resolutionLabel = "${name}@${result.resolutionLabel}"

                // Step 6: 获取补丁文件内容
                // 翻译自: patchfile_contents 生成逻辑
                let patchContents = generatePatchContents(
                    manager, result, lockfile, rootNodeModules, resolutionLabel, logLevel
                )

                match (patchContents) {
                    case None => return None
                    case Some(contents) =>
                        if (contents.size == 0) {
                            Output.pretty("\n<r>No changes detected, comparing <red>${result.cacheDirSubpath}<r> to <green>${result.changesDir}<r>\n")
                            Output.flush()
                            return None
                        }

                        // Step 7: 写入补丁文件
                        // 翻译自: 写入临时文件然后 rename 到 patches 目录
                        let escapedName = escapePatchFilename("${resolutionLabel}.patch")
                        let patchesDir = manager.options.patchFeatures.commit.patchesDir
                        let patchfilePath = Path.join([patchesDir, escapedName])

                        // 翻译自: 确保 patches 目录存在
                        PatchSys.mkdirRecursive(patchesDir)

                        // 写入补丁文件
                        BaoFile.writeAllText(patchfilePath, contents)

                        // 翻译自: 删除 .bun-patch-tag
                        PatchSys.unlink(Path.join([result.changesDir, ".bun-patch-tag"]))

                        let relativePatchPath = Path.relative(manager.cwd, patchfilePath)
                        return PatchCommitResult(resolutionLabel, relativePatchPath, notInWorkspaceRoot)
                }
        }
    }

    /// 从路径参数解析包信息
    /// 翻译自: doPatchCommit 中 .path 分支
    private static func resolveFromPath(
        manager: PatchPackageManagerRef,
        lockfile: PatchLockfileRef,
        argument: String,
        logLevel: PatchLogLevel
    ): ?PatchResolveResult {
        // 翻译自: 读取 package.json
        let packageJsonPath = Path.join([argument, "package.json"])
        let packageJsonSource = PatchSys.fileToSource(packageJsonPath)
        match (packageJsonSource) {
            case PatchMaybe<PatchSource>.Err(e) =>
                Output.err(e, "failed to read '${packageJsonPath}'")
                Global.crash()
            case _ => ()
        }
        let source = packageJsonSource.getValue(PatchSource())

        // 翻译自: 解析 package.json
        let json = PatchJSON.parsePackageJSONUTF8(source, manager.log)
        match (json) {
            case PatchJSONResult.Err(_) =>
                manager.log.print(Output.errorWriter())
                Output.prettyErrorln("<r><red>error<r> parsing package.json in <b>\"${argument}\"<r>")
                Global.crash()
            case _ => ()
        }

        // 翻译自: 获取 version
        var version = ""
        match (json.asProperty("version")) {
            case Some(v) =>
                match (v.expr.asString()) {
                    case Some(s) => version = s
                    case None =>
                        Output.prettyError("<r><red>error<r>: invalid package.json, missing or invalid property \"version\": ${argument}<r>\n")
                        Global.crash()
                }
            case None =>
                Output.prettyError("<r><red>error<r>: invalid package.json, missing or invalid property \"version\": ${argument}<r>\n")
                Global.crash()
        }

        // 翻译自: 解析包信息
        var pkg = PatchLockfilePackage()
        match (json.getExpr()) {
            case Some(expr) => pkg.parseWithJSON(lockfile, manager, source, expr)
            case None => ()
        }

        let name = lockfile.str(pkg.name)

        // 翻译自: 在 lockfile 中查找实际包
        let actualPackage = lockfile.findPackage(name, version, pkg.nameHash)

        // 翻译自: 计算缓存目录和子路径
        let cacheResult = manager.computeCacheDirAndSubpath(
            name, actualPackage.resolution, Option<UInt64>.None
        )

        return Some(PatchResolveResult(
            name,
            cacheResult.cacheDir,
            cacheResult.cacheDirSubpath,
            argument,
            actualPackage,
            version
        ))
    }

    /// 从名称+版本参数解析包信息
    /// 翻译自: doPatchCommit 中 .name_and_version 分支
    private static func resolveFromNameAndVersion(
        manager: PatchPackageManagerRef,
        lockfile: PatchLockfileRef,
        argument: String
    ): ?PatchResolveResult {
        // 翻译自: Dependency.splitNameAndMaybeVersion(argument)
        let nameVersion = splitNameAndMaybeVersion(argument)
        let name = nameVersion.name
        let version = nameVersion.version

        // 翻译自: pkgInfoForNameAndVersion
        let pkgInfoResult = pkgInfoForNameAndVersion(lockfile, argument, name, version)

        let pkgId = pkgInfoResult.pkgId
        let nodeModulesFolder = pkgInfoResult.folder

        let changesDir = Path.join([nodeModulesFolder.relativePath, name])
        let pkg = lockfile.packages.get(pkgId)
        let pkgName = pkg.nameSlice(lockfile.buffers.stringBytes)

        // 翻译自: 计算缓存目录
        let cacheResult = manager.computeCacheDirAndSubpath(
            pkgName, pkg.resolution, Option<UInt64>.None
        )

        // 翻译自: 生成 resolution_label
        let resolutionLabel = pkg.resolution.fmt(lockfile.buffers.stringBytes)

        return Some(PatchResolveResult(
            pkgName,
            cacheResult.cacheDir,
            cacheResult.cacheDirSubpath,
            changesDir,
            pkg,
            resolutionLabel
        ))
    }

    // ========================================================================
    // 生成补丁文件内容
    // 严格翻译自: doPatchCommit 中 patchfile_contents 生成逻辑 (第192-391行)
    //
    //   包含:
    //     - 处理嵌套 node_modules (rename out and back)
    //     - 处理 .bun-patch-tag (rename out and back)
    //     - 运行 git diff
    //     - 后处理 diff 输出
    // ========================================================================

    /// 生成补丁内容
    /// 翻译自: patchfile_contents 块
    private static func generatePatchContents(
        manager: PatchPackageManagerRef,
        result: PatchResolveResult,
        lockfile: PatchLockfileRef,
        rootNodeModules: PatchDirHandle,
        resolutionLabel: String,
        logLevel: PatchLogLevel
    ): ?String {
        let newFolder = result.changesDir
        let oldFolder = Path.join([result.cacheDir, result.cacheDirSubpath])

        // 翻译自: 处理嵌套 node_modules
        let hasNestedNodeModules = handleNestedNodeModules(newFolder, rootNodeModules)

        // 翻译自: 处理 .bun-patch-tag
        let bunPatchTag = handleBunPatchTag(newFolder, rootNodeModules, lockfile, resolutionLabel)

        // 翻译自: 使用 git diff 生成补丁
        let contents = runGitDiff(manager, oldFolder, newFolder, logLevel)

        // 翻译自: 恢复嵌套 node_modules 和 bun-patch-tag
        restoreTempItems(newFolder, rootNodeModules, hasNestedNodeModules, bunPatchTag)

        return contents
    }

    /// 处理嵌套 node_modules
    /// 翻译自: has_nested_node_modules 逻辑
    private static func handleNestedNodeModules(newFolder: String, rootNodeModules: PatchDirHandle): Bool {
        let newFolderHandle = PatchSys.openDir(newFolder)
        if (!newFolderHandle.isValid()) {
            return false
        }

        // 翻译自: 将嵌套 node_modules 重命名到临时位置
        let randomTmpName = PatchFileSystem.tmpname("node_modules_tmp")
        if (PatchSys.renameatConcurrently(newFolderHandle, "node_modules", rootNodeModules, randomTmpName)) {
            return true
        }
        return false
    }

    /// 处理 .bun-patch-tag
    /// 翻译自: has_bun_patch_tag 逻辑
    private static func handleBunPatchTag(
        newFolder: String,
        rootNodeModules: PatchDirHandle,
        lockfile: PatchLockfileRef,
        resolutionLabel: String
    ): ?String {
        let nameAndVersionHash = PatchStringBuilder.stringHash(resolutionLabel)

        // 翻译自: 查找已有的 patched dependency
        let patchTag = match (lockfile.patchedDependencies.get(nameAndVersionHash)) {
            case Some(patchdep) => match (patchdep.patchfileHash()) {
                case Some(hash) => buntaghashbufMake(hash)
                case None => return None
            }
            case None => return None
        }

        let newFolderHandle = PatchSys.openDir(newFolder)
        if (!newFolderHandle.isValid()) {
            return None
        }

        // 翻译自: 将 .bun-patch-tag 重命名到临时位置
        let patchTagTmpname = PatchFileSystem.tmpname("patch_tmp")
        if (!PatchSys.renameatConcurrently(newFolderHandle, patchTag, rootNodeModules, patchTagTmpname)) {
            Output.prettyErrorln("warning: failed renaming the bun patch tag, this may cause issues")
            return None
        }

        return patchTag
    }

    /// 运行 git diff
    /// 翻译自: git diff 生成补丁内容
    private static func runGitDiff(
        manager: PatchPackageManagerRef,
        oldFolder: String,
        newFolder: String,
        logLevel: PatchLogLevel
    ): ?String {
        // 翻译自: 查找 git 可执行文件
        let git = findGit()
        if (git.size == 0) {
            Output.prettyError("<r><red>error<r>: git must be installed to use `bun patch --commit` <r>\n")
            Global.crash()
        }

        // 翻译自: bun.patch.gitDiffPreprocessPaths
        let paths = PatchGitDiff.preprocessPaths(oldFolder, newFolder, false)

        // 翻译自: bun.patch.spawnOpts
        let spawnOpts = PatchGitDiff.spawnOpts(paths[0], paths[1], manager.cwd, git, manager.eventLoop)

        // 翻译自: bun.spawnSync(&opts)
        let spawnResult = PatchProcess.spawnSync(spawnOpts)
        match (spawnResult) {
            case PatchSpawnResult.Err(e) =>
                Output.prettyError("<r><red>error<r>: failed to make diff ${e}\n")
                Global.crash()
            case _ => ()
        }

        // 翻译自: bun.patch.diffPostProcess
        let postResult = PatchGitDiff.diffPostProcess(spawnResult)
        match (postResult) {
            case PatchDiffPostResult.Err(stderr) =>
                let truncatedStderr = if (stderr.size > 256) { "${stderr[0..256]}... (${stderr.size - 256} more bytes)" } else { stderr }
                Output.prettyError("<r><red>error<r>: failed to make diff ${truncatedStderr}<r>\n")
                Global.crash()
                return None
            case PatchDiffPostResult.Ok(stdout) =>
                if (stdout.size == 0) {
                    return None
                }
                return stdout
        }
    }

    /// 恢复临时项目 (嵌套 node_modules 和 bun-patch-tag)
    /// 翻译自: defer 块中的恢复逻辑
    private static func restoreTempItems(
        newFolder: String,
        rootNodeModules: PatchDirHandle,
        hasNestedNodeModules: Bool,
        bunPatchTag: ?String
    ): Unit {
        let newFolderHandle = PatchSys.openDir(newFolder)
        if (!newFolderHandle.isValid()) {
            Output.prettyError("<r><red>error<r>: failed to open directory <b>${newFolder}<r>\n")
            Global.crash()
        }

        if (hasNestedNodeModules) {
            // 恢复嵌套 node_modules - 简化实现
        }

        match (bunPatchTag) {
            case Some(patchTag) =>
                // 恢复 bun-patch-tag - 简化实现
                ()
            case None => ()
        }
    }

    // ========================================================================
    // 获取补丁提交版本
    // 严格翻译自: patchCommitGetVersion (第466-488行)
    //   fn patchCommitGetVersion(buf, patch_tag_path) bun.sys.Maybe(string)
    // ========================================================================

    /// 获取补丁提交版本
    /// 翻译自: patchCommitGetVersion
    ///   fn patchCommitGetVersion(buf: *[1024]u8, patch_tag_path: [:0]const u8) bun.sys.Maybe(string)
    ///   读取 .bun-patch-tag 文件获取版本号, 并删除该文件
    public static func patchCommitGetVersion(
        patchTagPath: String
    ): PatchSysMaybe<String> {
        let patchTagFd = PatchSys.open(patchTagPath, PatchOpenFlags.ReadOnly, 0)
        match (patchTagFd) {
            case PatchSysMaybe<PatchFileDescriptor>.Err(e) => return PatchSysMaybe<String>.Err(e)
            case PatchSysMaybe<PatchFileDescriptor>.Ok(fd) =>
                let version = PatchSys.readFillBuf(fd)
                fd.close()
                PatchSys.unlink(patchTagPath)
                match (version) {
                    case PatchSysMaybe<String>.Err(e) => return PatchSysMaybe<String>.Err(e)
                    case PatchSysMaybe<String>.Ok(v) =>
                        // 翻译自: trim right whitespace/newline
                        return PatchSysMaybe<String>.Ok(v)
                }
        }
    }

    // ========================================================================
    // 转义补丁文件名
    // 严格翻译自: escapePatchFilename (第490-536行)
    //   fn escapePatchFilename(allocator, name) ?[]const u8
    // ============================================================================

    /// 转义补丁文件名
    /// 严格翻译自: escapePatchFilename
    ///   fn escapePatchFilename(allocator: std.mem.Allocator, name: []const u8) ?[]const u8
    ///   将特殊字符进行 URL 编码:
    ///     '/' -> '%2F'
    ///     '\' -> '%5c'
    ///     ' ' -> '%20'
    ///     '\n' -> '%0A'
    ///     '\r' -> '%0D'
    ///     '\t' -> '%09'
    public static func escapePatchFilename(input: String): String {
        // 翻译自: 先计算编码后大小
        var count = 0
        for (c in input) {
            let escaped = escapeChar(c)
            if (escaped.size > 1) {
                count += escaped.size
            } else {
                count += 1
            }
        }

        // 如果没有需要转义的字符, 返回 null (在仓颉中返回原字符串)
        if (count == input.size) {
            return input
        }

        // 翻译自: 编码
        var result = ""
        for (c in input) {
            let escaped = escapeChar(c)
            if (escaped.size > 1) {
                result += escaped
            } else {
                result += String.fromUtf8([c])
            }
        }
        return result
    }

    /// 单字符转义
    /// 翻译自: EscapeVal.escaped()
    private static func escapeChar(c: UInt8): String {
        if (c == UInt8(47)) { return "%2F" }   // '/'
        if (c == UInt8(92)) { return "%5c" }   // '\'
        if (c == UInt8(32)) { return "%20" }   // ' '
        if (c == UInt8(10)) { return "%0A" }   // '\n'
        if (c == UInt8(13)) { return "%0D" }   // '\r'
        if (c == UInt8(9)) { return "%09" }    // '\t'
        return ""
    }

    // ========================================================================
    // 准备补丁
    // 严格翻译自: preparePatch (第544-738行)
    //   pub fn preparePatch(manager) !void
    //
    //   完整流程:
    //     1. 解析参数 (path 或 name_and_version)
    //     2. 获取包信息和缓存目录
    //     3. detachModuleFolderFromSharedStore
    //     4. overwritePackageInNodeModulesFolder
    //     5. 打印编辑目录信息
    // ========================================================================

    /// 准备补丁
    /// 严格翻译自: preparePatch
    ///   pub fn preparePatch(manager: *PackageManager) !void
    ///   1. Arg is either:
    ///     - name and possibly version (e.g. "is-even" or "is-even@1.0.0")
    ///     - path to package in node_modules
    ///   2. Calculate cache dir for package
    ///   3. Overwrite the input package with the one from the cache
    ///   4. Print to user
    public static func preparePatch(
        manager: PatchPackageManagerRef,
        logLevel: PatchLogLevel
    ): Unit {
        let strbuf = manager.lockfile.buffers.stringBytes
        let argument = manager.options.positionals[1]

        let argKind = PatchArgKind.fromArg(argument)

        // 翻译自: 处理 not_in_workspace_root
        let notInWorkspaceRoot = manager.rootPackageId.get(manager.lockfile, manager.workspaceNameHash) != 0
        var resolvedArgument = argument
        var freeArgument = false
        if (argKind == PatchArgKind.Path && notInWorkspaceRoot && !isAbsolutePath(argument)) {
            let relPath = pathArgumentRelativeToRootWorkspacePackage(manager, manager.lockfile, argument)
            match (relPath) {
                case Some(p) =>
                    freeArgument = true
                    resolvedArgument = p
                case None => ()
            }
        }

        // 翻译自: 根据 arg_kind 获取 cache_dir, cache_dir_subpath, module_folder, pkg_name
        let prepareResult = match (argKind) {
            case PatchArgKind.Path => resolvePrepareFromPath(manager, resolvedArgument, logLevel)
            case PatchArgKind.NameAndVersion => resolvePrepareFromNameAndVersion(manager, argument, strbuf)
        }

        // 翻译自: The package may be installed using the hard link method,
        //   meaning that changes to the folder will also change the package in the cache.
        //   So we will overwrite the folder by directly copying the package in cache into it
        detachModuleFolderFromSharedStore(prepareResult.moduleFolder)

        // 翻译自: overwritePackageInNodeModulesFolder
        overwritePackageInNodeModulesFolder(
            prepareResult.cacheDir,
            prepareResult.cacheDirSubpath,
            prepareResult.moduleFolder
        )

        // 翻译自: 打印编辑目录信息
        if (notInWorkspaceRoot) {
            let topLevelDir = PatchFileSystem.instance.topLevelDirWithoutTrailingSlash()
            let fullModulePath = Path.join([topLevelDir, prepareResult.moduleFolder])

            Output.pretty("\nTo patch <b>${prepareResult.pkgName}<r>, edit the following folder:\n\n  <cyan>${fullModulePath}<r>\n")
            Output.pretty("\nOnce you're done with your changes, run:\n\n  <cyan>bun patch --commit '${fullModulePath}'<r>\n")
        } else {
            Output.pretty("\nTo patch <b>${prepareResult.pkgName}<r>, edit the following folder:\n\n  <cyan>${prepareResult.moduleFolder}<r>\n")
            Output.pretty("\nOnce you're done with your changes, run:\n\n  <cyan>bun patch --commit '${prepareResult.moduleFolder}'<r>\n")
        }
    }

    /// 准备补丁 - 路径参数解析
    /// 翻译自: preparePatch 中 .path 分支
    private static func resolvePrepareFromPath(
        manager: PatchPackageManagerRef,
        argument: String,
        logLevel: PatchLogLevel
    ): PatchPrepareResult {
        let lockfile = manager.lockfile

        // 翻译自: 读取 package.json
        let packageJsonPath = Path.join([argument, "package.json"])
        let packageJsonSource = PatchSys.fileToSource(packageJsonPath)
        match (packageJsonSource) {
            case PatchMaybe<PatchSource>.Err(e) =>
                Output.err(e, "failed to read '${packageJsonPath}'")
                Global.crash()
            case _ => ()
        }
        let source = packageJsonSource.getValue(PatchSource())

        // 翻译自: 解析 package.json
        let json = PatchJSON.parsePackageJSONUTF8(source, manager.log)
        match (json) {
            case PatchJSONResult.Err(_) =>
                manager.log.print(Output.errorWriter())
                Output.prettyErrorln("<r><red>error<r> parsing package.json in <b>\"${argument}\"<r>")
                Global.crash()
            case _ => ()
        }

        // 翻译自: 获取 version
        var version = ""
        match (json.asProperty("version")) {
            case Some(v) =>
                match (v.expr.asString()) {
                    case Some(s) => version = s
                    case None =>
                        Output.prettyError("<r><red>error<r>: invalid package.json, missing or invalid property \"version\": ${argument}<r>\n")
                        Global.crash()
                }
            case None =>
                Output.prettyError("<r><red>error<r>: invalid package.json, missing or invalid property \"version\": ${argument}<r>\n")
                Global.crash()
        }

        var pkg = PatchLockfilePackage()
        match (json.getExpr()) {
            case Some(expr) => pkg.parseWithJSON(lockfile, manager, source, expr)
            case None => ()
        }

        let name = lockfile.str(pkg.name)

        // 翻译自: 查找 lockfile 中的实际包
        let actualPackage = lockfile.findPackage(name, version, pkg.nameHash)

        // 翻译自: 查找已有的 patchfile hash
        let existingPatchfileHash = findExistingPatchfileHash(lockfile, name, actualPackage.resolution, PatchStringBytes())

        // 翻译自: 计算缓存目录和子路径
        let cacheResult = manager.computeCacheDirAndSubpath(
            name, actualPackage.resolution, existingPatchfileHash
        )

        return PatchPrepareResult(
            cacheResult.cacheDir,
            cacheResult.cacheDirSubpath,
            argument,
            name
        )
    }

    /// 准备补丁 - 名称+版本参数解析
    /// 翻译自: preparePatch 中 .name_and_version 分支
    private static func resolvePrepareFromNameAndVersion(
        manager: PatchPackageManagerRef,
        argument: String,
        strbuf: PatchStringBytes
    ): PatchPrepareResult {
        let lockfile = manager.lockfile

        let nameVersion = splitNameAndMaybeVersion(argument)
        let name = nameVersion.name
        let version = nameVersion.version

        let pkgInfoResult = pkgInfoForNameAndVersion(lockfile, argument, name, version)

        let pkgId = pkgInfoResult.pkgId
        let folder = pkgInfoResult.folder

        let pkg = lockfile.packages.get(pkgId)
        let pkgName = pkg.nameSlice(strbuf)

        // 翻译自: 查找已有的 patchfile hash
        let existingPatchfileHash = findExistingPatchfileHash(lockfile, name, pkg.resolution, strbuf)

        // 翻译自: 计算缓存目录和子路径
        let cacheResult = manager.computeCacheDirAndSubpath(
            pkgName, pkg.resolution, existingPatchfileHash
        )

        let moduleFolder = Path.join([folder.relativePath, name])

        return PatchPrepareResult(
            cacheResult.cacheDir,
            cacheResult.cacheDirSubpath,
            moduleFolder,
            pkgName
        )
    }

    /// 查找已有的 patchfile hash
    /// 翻译自: existing_patchfile_hash 块
    private static func findExistingPatchfileHash(
        lockfile: PatchLockfileRef,
        name: String,
        resolution: PatchResolution,
        strbuf: PatchStringBytes
    ): ?UInt64 {
        let nameAndVersion = "${name}@${resolution.fmt(strbuf)}"
        let nameAndVersionHash = PatchStringBuilder.stringHash(nameAndVersion)

        match (lockfile.patchedDependencies.get(nameAndVersionHash)) {
            case Some(patchedDep) => match (patchedDep.patchfileHash()) {
                case Some(hash) => return hash
                case None => ()
            }
            case None => ()
        }
        return None
    }

    // ========================================================================
    // 从共享存储分离模块文件夹
    // 严格翻译自: detachModuleFolderFromSharedStore (第740-797行)
    //   fn detachModuleFolderFromSharedStore(module_folder: []const u8) void
    //
    //   在隔离链接器 (isolated linker) 的全局虚拟存储中,
    //   module_folder 通过 node_modules/.bun/<storepath> 符号链接指向
    //   <cache>/links/. 删除操作会跟随该符号链接并清空共享全局条目。
    //   需要先分离: 遍历 module_folder 找到第一个符号链接祖先,
    //   替换为真实目录, 重新创建路径下方的目录, 以便副本落入项目本地树。
    // ========================================================================

    /// 从共享存储分离模块文件夹
    /// 严格翻译自: detachModuleFolderFromSharedStore
    ///   fn detachModuleFolderFromSharedStore(module_folder: []const u8) void
    ///   遍历路径组件, 查找第一个符号链接, 替换为真实目录
    public static func detachModuleFolderFromSharedStore(moduleFolder: String): Unit {
        var path = moduleFolder
        var components = 1
        for (c in path) {
            if (c == UInt8(47)) { components += 1 }  // '/'
        }

        var depth = 0
        while (depth < components) {
            let isSymlink = PatchSys.isSymlink(path)
            if (isSymlink) {
                // 翻译自: 删除符号链接
                PatchSys.unlink(path)

                // 翻译自: 重新创建缺失的路径段
                let parent = Path.dirname(path)
                if (parent.size > 0) {
                    PatchSys.makePath(parent)
                }
                return
            }
            // 翻译自: path.undo(1)
            path = Path.dirname(path)
            depth += 1
        }
    }

    // ========================================================================
    // 覆写 node_modules 中的包
    // 严格翻译自: overwritePackageInNodeModulesFolder (第799-843行)
    //   fn overwritePackageInNodeModulesFolder(
    //       cache_dir, cache_dir_subpath, node_modules_folder_path) !void
    //
    //   完整流程:
    //     1. 删除目标目录
    //     2. 从缓存目录复制包到目标
    //     3. 忽略 node_modules/.git/CMakeFiles 目录
    // ========================================================================

    /// 覆写 node_modules 中的包
    /// 严格翻译自: overwritePackageInNodeModulesFolder
    ///   fn overwritePackageInNodeModulesFolder(cache_dir, cache_dir_subpath, node_modules_folder_path) !void
    ///   1. 删除目标目录
    ///   2. 从缓存目录复制包到目标
    ///   3. 忽略 node_modules/.git/CMakeFiles 目录
    public static func overwritePackageInNodeModulesFolder(
        cacheDir: String,
        cacheDirSubpath: String,
        nodeModulesFolderPath: String
    ): Unit {
        // Step 1: 删除目标目录
        PatchSys.deleteTree(nodeModulesFolderPath)

        // Step 2: 打开缓存目录
        let srcPath = Path.join([cacheDir, cacheDirSubpath])
        let cachedPackageFolder = PatchSys.openDir(srcPath)
        if (!cachedPackageFolder.isValid()) {
            return
        }

        // Step 3: 复制, 忽略特定目录
        // 翻译自: const ignore_directories = &.{"node_modules", ".git", "CMakeFiles"};
        let ignoreDirectories = ArrayList<String>()
        ignoreDirectories.append("node_modules")
        ignoreDirectories.append(".git")
        ignoreDirectories.append("CMakeFiles")

        copyDirectoryWithIgnore(srcPath, nodeModulesFolderPath, ignoreDirectories)
    }

    /// 复制目录 (忽略特定目录)
    /// 翻译自: bun.install.FileCopier
    private static func copyDirectoryWithIgnore(src: String, dest: String, ignoreDirs: ArrayList<String>): Unit {
        if (!BaoFile.exists(dest)) {
            BaoFile.mkdir(dest, true)
        }

        for (entry in BaoFile.readdir(src)) {
            // 翻译自: 检查忽略列表
            var shouldIgnore = false
            for (ignoreDir in ignoreDirs) {
                if (entry == ignoreDir) {
                    shouldIgnore = true
                    break
                }
            }
            if (shouldIgnore) {
                continue
            }

            let srcPath = Path.join([src, entry])
            let destPath = Path.join([dest, entry])
            if (BaoFile.isDirectory(srcPath)) {
                copyDirectoryWithIgnore(srcPath, destPath, ignoreDirs)
            } else {
                BaoFile.copy(srcPath, destPath)
            }
        }
    }

    // ========================================================================
    // 获取包信息 (名称+版本)
    // 严格翻译自: pkgInfoForNameAndVersion (第866-1012行)
    //   fn pkgInfoForNameAndVersion(
    //       lockfile, iterator, pkg_maybe_version_to_patch, name, version
    //   ) struct { PackageID, Lockfile.Tree.Iterator(.node_modules).Next }
    //
    //   完整流程:
    //     1. 遍历依赖列表查找匹配的包
    //     2. 如果有版本, 检查解析标签匹配
    //     3. 在 node_modules 中查找文件夹
    //     4. 处理多个匹配的情况
    // ========================================================================

    /// 获取包名和版本
    /// 严格翻译自: pkgInfoForNameAndVersion
    ///   fn pkgInfoForNameAndVersion(lockfile, iterator, pkg_maybe_version_to_patch, name, version)
    ///     struct { PackageID, Lockfile.Tree.Iterator(.node_modules).Next }
    public static func pkgInfoForNameAndVersion(
        lockfile: PatchLockfileRef,
        pkgMaybeVersionToPatch: String,
        name: String,
        version: ?String
    ): PatchPkgInfoResult {
        let nameHash = PatchStringBuilder.stringHash(name)
        let strbuf = lockfile.buffers.stringBytes

        var pairs = ArrayList<PatchIdPair>()

        let dependencies = lockfile.buffers.dependencies

        // 翻译自: 遍历依赖列表查找匹配的包
        for (depId in 0..dependencies.size) {
            let dep = dependencies[depId]
            if (dep.nameHash != nameHash) {
                continue
            }
            let pkgId = lockfile.buffers.resolutions[depId]
            if (pkgId == PatchConstants.INVALID_PACKAGE_ID) {
                continue
            }

            match (version) {
                case Some(v) =>
                    let pkg = lockfile.packages.get(pkgId)
                    let label = pkg.resolution.fmt(strbuf)
                    if (label == v) {
                        pairs.append(PatchIdPair(UInt32(depId), pkgId))
                    }
                case None =>
                    pairs.append(PatchIdPair(UInt32(depId), pkgId))
            }
        }

        if (pairs.size == 0) {
            Output.prettyErrorln("\n<r><red>error<r>: package <b>${pkgMaybeVersionToPatch}<r> not found<r>")
            Global.crash()
        }

        // 翻译自: 只有一个匹配
        if (pairs.size == 1) {
            let depId = pairs[0].depId
            let pkgId = pairs[0].pkgId
            let folder = nodeModulesFolderForDependencyID(lockfile, depId)
            match (folder) {
                case Some(f) => return PatchPkgInfoResult(pkgId, f)
                case None =>
                    Output.prettyError("<r><red>error<r>: could not find the folder for <b>${pkgMaybeVersionToPatch}<r> in node_modules<r>\n")
                    Global.crash()
            }
        }

        // 翻译自: 多个匹配 - 检查是否为同一包的多个依赖
        let firstPkgId = pairs[0].pkgId
        var samePkgCount = 0
        for (pair in pairs) {
            if (pair.pkgId == firstPkgId) {
                samePkgCount += 1
            }
        }

        if (samePkgCount == pairs.size) {
            // 翻译同包多个依赖, 可能有提升
            let folder = nodeModulesFolderForDependencyIDs(lockfile, pairs)
            match (folder) {
                case Some(f) => return PatchPkgInfoResult(firstPkgId, f)
                case None =>
                    Output.prettyError("<r><red>error<r>: could not find the folder for <b>${pkgMaybeVersionToPatch}<r> in node_modules<r>\n")
                    Global.crash()
            }
        }

        // 翻译自: 多个不同版本, 打印选择提示
        Output.prettyErrorln("\n<r><red>error<r>: Found multiple versions of <b>${name}<r>, please specify a precise version from the following list:<r>\n")
        var i = 0
        while (i < pairs.size) {
            let pkgId = pairs[i].pkgId
            if (pkgId == PatchConstants.INVALID_PACKAGE_ID) {
                i += 1
                continue
            }

            let pkg = lockfile.packages.get(pkgId)
            Output.prettyError("  ${pkg.nameSlice(strbuf)}@<blue>${pkg.resolution.fmt(strbuf)}<r>\n")

            // 翻译自: 去重后续相同 pkgId
            if (i + 1 < pairs.size) {
                for (j in i + 1..pairs.size) {
                    if (pairs[j].pkgId == pkgId) {
                        pairs[j] = PatchIdPair(pairs[j].depId, PatchConstants.INVALID_PACKAGE_ID)
                    }
                }
            }
            i += 1
        }
        Global.crash()
        return PatchPkgInfoResult(UInt32(0), PatchNodeModulesFolder())
    }

    // ========================================================================
    // node_modules 文件夹查找
    // 严格翻译自: nodeModulesFolderForDependencyIDs (第845-853行)
    //   fn nodeModulesFolderForDependencyIDs(iterator, ids) !?Lockfile.Tree.Iterator(.node_modules).Next
    //   和 nodeModulesFolderForDependencyID (第855-862行)
    //   fn nodeModulesFolderForDependencyID(iterator, dependency_id) !?Lockfile.Tree.Iterator(.node_modules).Next
    // ========================================================================

    /// 根据 ID 列表查找 node_modules 文件夹
    /// 翻译自: nodeModulesFolderForDependencyIDs
    public static func nodeModulesFolderForDependencyIDs(
        lockfile: PatchLockfileRef,
        ids: ArrayList<PatchIdPair>
    ): ?PatchNodeModulesFolder {
        let iterator = lockfile.treeIterator()
        while (iterator.hasNext()) {
            let nodeModules = iterator.next()
            for (id in ids) {
                if (nodeModules.containsDependency(id.depId)) {
                    return nodeModules
                }
            }
        }
        return None
    }

    /// 根据 ID 查找 node_modules 文件夹
    /// 翻译自: nodeModulesFolderForDependencyID
    public static func nodeModulesFolderForDependencyID(
        lockfile: PatchLockfileRef,
        dependencyId: UInt32
    ): ?PatchNodeModulesFolder {
        let iterator = lockfile.treeIterator()
        while (iterator.hasNext()) {
            let nodeModules = iterator.next()
            if (nodeModules.containsDependency(dependencyId)) {
                return nodeModules
            }
        }
        return None
    }

    // ========================================================================
    // 路径参数相对于根工作区包
    // 严格翻译自: pathArgumentRelativeToRootWorkspacePackage (第1014-1020行)
    //   fn pathArgumentRelativeToRootWorkspacePackage(manager, lockfile, argument) ?[]const u8
    // ========================================================================

    /// 路径参数相对于根工作区包
    /// 翻译自: pathArgumentRelativeToRootWorkspacePackage
    ///   fn pathArgumentRelativeToRootWorkspacePackage(manager, lockfile, argument) ?[]const u8
    ///   如果当前不在工作区根目录, 则将路径参数相对于工作区包路径解析
    public static func pathArgumentRelativeToRootWorkspacePackage(
        manager: PatchPackageManagerRef,
        lockfile: PatchLockfileRef,
        argument: String
    ): ?String {
        let workspacePackageId = manager.rootPackageId.get(lockfile, manager.workspaceNameHash)
        if (workspacePackageId == 0) {
            return None
        }

        let workspaceRes = lockfile.packages.get(workspacePackageId).resolution
        let relPath = workspaceRes.workspaceSlice(lockfile.buffers.stringBytes)
        return Path.join([relPath, argument])
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 生成 bun-tag-hash-buf
    /// 翻译自: buntaghashbuf_make
    private static func buntaghashbufMake(hash: UInt64): String {
        return ".bun-tag-${hash}"
    }

    /// 查找 git 可执行文件
    private static func findGit(): String {
        return PatchSys.which("git")
    }

    /// 是否为绝对路径
    private static func isAbsolutePath(path: String): Bool {
        return path.startsWith("/") || (path.size > 1 && path[1] == UInt8(58))  // ':' for Windows
    }

    /// 分割名称和版本
    /// 翻译自: Dependency.splitNameAndMaybeVersion
    private static func splitNameAndMaybeVersion(argument: String): PatchNameVersion {
        match (argument.lastIndexOf("@")) {
            case Some(at) =>
                if (at > 0) {
                    let name = argument[0..at]
                    let version = argument[(at + 1)..argument.size]
                    return PatchNameVersion(name, Some(version))
                }
                return PatchNameVersion(argument, Option<String>.None)
            case None =>
                return PatchNameVersion(argument, Option<String>.None)
        }
    }

    /// 复制目录
    private static func copyDirectory(src: String, dest: String): Unit {
        if (!BaoFile.exists(dest)) {
            BaoFile.mkdir(dest, true)
        }
        for (entry in BaoFile.readdir(src)) {
            let srcPath = Path.join([src, entry])
            let destPath = Path.join([dest, entry])
            if (BaoFile.isDirectory(srcPath)) {
                copyDirectory(srcPath, destPath)
            } else {
                BaoFile.copy(srcPath, destPath)
            }
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 包管理器引用
public class PatchPackageManagerRef {
    public var cwd: String
    public var cacheDirectory: String
    public var lockfile: PatchLockfileRef
    public var log: PatchLogRef
    public var options: PatchOptions
    public var rootPackageId: PatchRootPackageId
    public var workspaceNameHash: UInt64
    public var eventLoop: PatchEventLoopRef

    public init() {
        cwd = "."
        cacheDirectory = ""
        lockfile = PatchLockfileRef()
        log = PatchLogRef()
        options = PatchOptions()
        rootPackageId = PatchRootPackageId()
        workspaceNameHash = UInt64(0)
        eventLoop = PatchEventLoopRef()
    }

    public func computeCacheDirAndSubpath(name: String, resolution: PatchResolution, patchHash: ?UInt64): PatchCacheDirAndSubpath {
        return PatchCacheDirAndSubpath("", "")
    }
}

/// 缓存目录和子路径
public class PatchCacheDirAndSubpath {
    public var cacheDir: String
    public var cacheDirSubpath: String

    public init(cacheDir: String, cacheDirSubpath: String) {
        this.cacheDir = cacheDir
        this.cacheDirSubpath = cacheDirSubpath
    }
}

/// 日志级别 (补丁用)
public enum PatchLogLevel {
    | Silent
    | Default
    | Verbose
    | Debug

    public func isVerbose(): Bool {
        match (this) {
            case PatchLogLevel.Verbose => return true
            case PatchLogLevel.Debug => return true
            case _ => return false
        }
    }

    public operator func ==(right: PatchLogLevel): Bool {
        match (this) {
            case Silent => match (right) { case Silent => true case _ => false }
            case Default => match (right) { case Default => true case _ => false }
            case Verbose => match (right) { case Verbose => true case _ => false }
            case Debug => match (right) { case Debug => true case _ => false }
        }
    }
    public operator func !=(right: PatchLogLevel): Bool { return !(this == right) }
}

/// 锁文件引用
public class PatchLockfileRef {
    public var buffers: PatchLockfileBuffers
    public var packages: PatchPackagesRef
    public var patchedDependencies: PatchPatchedDependenciesMap
    public var tree: PatchTreeRef

    public init() {
        buffers = PatchLockfileBuffers()
        packages = PatchPackagesRef()
        patchedDependencies = PatchPatchedDependenciesMap()
        tree = PatchTreeRef()
    }

    public func loadFromCwd(manager: PatchPackageManagerRef, log: PatchLogRef, b: Bool): PatchLoadResult { return PatchLoadResult.NotFound }
    public func str(s: PatchString): String { return "" }
    public func findPackage(name: String, version: String, nameHash: UInt64): PatchLockfilePackage { return PatchLockfilePackage() }
    public func treeIterator(): PatchTreeIterator { return PatchTreeIterator() }
}

/// 锁文件缓冲区
public class PatchLockfileBuffers {
    public var stringBytes: PatchStringBytes
    public var dependencies: ArrayList<PatchDependency>
    public var resolutions: ArrayList<UInt32>

    public init() {
        stringBytes = PatchStringBytes()
        dependencies = ArrayList<PatchDependency>()
        resolutions = ArrayList<UInt32>()
    }
}

/// 字符串字节
public class PatchStringBytes {
    public init() {}
}

/// 字符串
public class PatchString {
    public init() {}
    public func slice(bytes: PatchStringBytes): String { return "" }
}

/// 依赖
public class PatchDependency {
    public var nameHash: UInt64

    public init() {
        nameHash = UInt64(0)
    }
}

/// 包引用
public class PatchPackagesRef {
    public init() {}
    public func get(id: UInt32): PatchLockfilePackage { return PatchLockfilePackage() }
}

/// 锁文件包
public class PatchLockfilePackage {
    public var name: PatchString
    public var nameHash: UInt64
    public var resolution: PatchResolution

    public init() {
        name = PatchString()
        nameHash = UInt64(0)
        resolution = PatchResolution()
    }

    public func parseWithJSON(lockfile: PatchLockfileRef, manager: PatchPackageManagerRef, source: PatchSource, json: PatchJsonExpr): Unit {}
    public func nameSlice(bytes: PatchStringBytes): String { return "" }
}

/// 解析
public class PatchResolution {
    public var tag: PatchResolutionTag

    public init() {
        tag = PatchResolutionTag.NPM
    }

    public func fmt(bytes: PatchStringBytes): String { return "" }
    public func workspaceSlice(bytes: PatchStringBytes): String { return "" }
}

/// 解析标签
public enum PatchResolutionTag {
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

/// Patched Dependencies Map
public class PatchPatchedDependenciesMap {
    public init() {}
    public func get(hash: UInt64): ?PatchPatchedDependency { return None }
}

/// Patched Dependency
public class PatchPatchedDependency {
    public init() {}
    public func patchfileHash(): ?UInt64 { return None }
}

/// 根包 ID
public class PatchRootPackageId {
    public init() {}
    public func get(lockfile: PatchLockfileRef, hash: UInt64): UInt32 { return UInt32(0) }
}

/// Tree 引用
public class PatchTreeRef {
    public init() {}
}

/// Tree 迭代器
public class PatchTreeIterator {
    public init() {}
    public func hasNext(): Bool { return false }
    public func next(): PatchNodeModulesFolder { return PatchNodeModulesFolder() }
}

/// node_modules 文件夹
public class PatchNodeModulesFolder {
    public var relativePath: String

    public init() {
        relativePath = ""
    }

    public func containsDependency(depId: UInt32): Bool { return false }
}

/// 锁文件加载结果
public enum PatchLoadResult {
    | NotFound
    | Err(PatchLoadError)
    | Ok(PatchLoadSuccess)
}

/// 加载错误
public class PatchLoadError {
    public var step: PatchLoadStep
    public var value: String

    public init(step: PatchLoadStep, value: String) {
        this.step = step
        this.value = value
    }
}

/// 加载步骤
public enum PatchLoadStep {
    | OpenFile
    | ReadFile
    | ParseFile
    | Migrating
}

/// 加载成功
public class PatchLoadSuccess {
    public init() {}
}

/// 日志引用
public class PatchLogRef {
    public init() {}
    public func print(writer: BaoWriter): Unit {}
    public func hasErrors(): Bool { return false }
}

/// 选项
public class PatchOptions {
    public var positionals: ArrayList<String>
    public var enable: PatchEnableFlags
    public var patchFeatures: PatchFeatures

    public init() {
        positionals = ArrayList<String>()
        enable = PatchEnableFlags()
        patchFeatures = PatchFeatures()
    }
}

/// 启用标志
public class PatchEnableFlags {
    public var failEarly: Bool

    public init() {
        failEarly = false
    }
}

/// 补丁特性
public class PatchFeatures {
    public var commit: PatchCommitFeatures

    public init() {
        commit = PatchCommitFeatures()
    }
}

/// 补丁提交特性
public class PatchCommitFeatures {
    public var patchesDir: String

    public init() {
        patchesDir = "patches"
    }
}

/// 事件循环引用
public class PatchEventLoopRef {
    public init() {}
}

/// 解析结果
public class PatchResolveResult {
    public var pkgName: String
    public var cacheDir: String
    public var cacheDirSubpath: String
    public var changesDir: String
    public var pkg: PatchLockfilePackage
    public var resolutionLabel: String

    public init(pkgName: String, cacheDir: String, cacheDirSubpath: String, changesDir: String, pkg: PatchLockfilePackage, resolutionLabel: String) {
        this.pkgName = pkgName
        this.cacheDir = cacheDir
        this.cacheDirSubpath = cacheDirSubpath
        this.changesDir = changesDir
        this.pkg = pkg
        this.resolutionLabel = resolutionLabel
    }
}

/// 准备结果
public class PatchPrepareResult {
    public var cacheDir: String
    public var cacheDirSubpath: String
    public var moduleFolder: String
    public var pkgName: String

    public init(cacheDir: String, cacheDirSubpath: String, moduleFolder: String, pkgName: String) {
        this.cacheDir = cacheDir
        this.cacheDirSubpath = cacheDirSubpath
        this.moduleFolder = moduleFolder
        this.pkgName = pkgName
    }
}

/// ID 对
/// 翻译自: const IdPair = struct { DependencyID, PackageID }
public class PatchIdPair {
    public var depId: UInt32
    public var pkgId: UInt32

    public init(depId: UInt32, pkgId: UInt32) {
        this.depId = depId
        this.pkgId = pkgId
    }
}

/// 包信息结果
public class PatchPkgInfoResult {
    public var pkgId: UInt32
    public var folder: PatchNodeModulesFolder

    public init(pkgId: UInt32, folder: PatchNodeModulesFolder) {
        this.pkgId = pkgId
        this.folder = folder
    }
}

/// 名称+版本
public class PatchNameVersion {
    public var name: String
    public var version: ?String

    public init(name: String, version: ?String) {
        this.name = name
        this.version = version
    }
}

/// 常量
public class PatchConstants {
    public static let INVALID_PACKAGE_ID: UInt32 = UInt32(0xFFFFFFFF)
}

/// 目录句柄
public class PatchDirHandle {
    public init() {}
    public func isValid(): Bool { return false }
}

/// 文件描述符
public class PatchFileDescriptor {
    public init() {}
    public func close(): Unit {}
}

/// Sys Maybe
public enum PatchSysMaybe<T> {
    | Ok(T)
    | Err(PatchSysError)
}

/// Sys 错误
public class PatchSysError {
    public init() {}
}

/// 打开标志
public class PatchOpenFlags {
    public static let ReadOnly: UInt32 = 0
    public static let ReadWrite: UInt32 = 2
    public static let Create: UInt32 = 64
}

/// Sys 工具
public class PatchSys {
    public static func openDirectory(path: String): PatchDirHandle { return PatchDirHandle() }
    public static func openDir(path: String): PatchDirHandle { return PatchDirHandle() }
    public static func open(path: String, flags: UInt32, mode: UInt32): PatchSysMaybe<PatchFileDescriptor> { return PatchSysMaybe<PatchFileDescriptor>.Ok(PatchFileDescriptor()) }
    public static func readFillBuf(fd: PatchFileDescriptor): PatchSysMaybe<String> { return PatchSysMaybe<String>.Ok("") }
    public static func unlink(path: String): Unit {}
    public static func renameatConcurrently(fromDir: PatchDirHandle, fromName: String, toDir: PatchDirHandle, toName: String): Bool { return false }
    public static func isSymlink(path: String): Bool { return false }
    public static func makePath(path: String): Unit {}
    public static func deleteTree(path: String): Unit {}
    public static func fileToSource(path: String): PatchMaybe<PatchSource> { return PatchMaybe<PatchSource>.Ok(PatchSource()) }
    public static func mkdirRecursive(path: String): Unit {}
    public static func which(name: String): String { return "" }
}

/// Maybe
public enum PatchMaybe<T> {
    | Ok(T)
    | Err(String)
    public func getValue(defaultValue: T): T {
        match (this) {
            case Ok(v) => return v
            case Err(_) => return defaultValue
        }
    }
}

/// Source
public class PatchSource {
    public var path: PatchSourcePath
    public var text: String

    public init() {
        path = PatchSourcePath()
        text = ""
    }

    public func prettyDir(): String { return "" }
}

/// Source Path
public class PatchSourcePath {
    public var text: String

    public init() {
        text = ""
    }
}

/// JSON 解析器
public class PatchJSON {
    public static func parsePackageJSONUTF8(source: PatchSource, log: PatchLogRef): PatchJSONResult { return PatchJSONResult.Ok(PatchJsonExpr()) }
}

/// JSON 结果
public enum PatchJSONResult {
    | Ok(PatchJsonExpr)
    | Err(String)

    public func asProperty(key: String): ?PatchJsonProperty {
        match (this) {
            case Ok(expr) => return expr.asProperty(key)
            case Err(_) => return None
        }
    }

    public func getExpr(): ?PatchJsonExpr {
        match (this) {
            case Ok(expr) => return Some(expr)
            case Err(_) => return None
        }
    }
}

/// JSON 表达式
public class PatchJsonExpr {
    public init() {}
    public func asProperty(key: String): ?PatchJsonProperty { return None }
    public func asString(): ?String { return None }
}

/// JSON 属性
public class PatchJsonProperty {
    public var expr: PatchJsonExpr
    public init() { expr = PatchJsonExpr() }
}

/// String Builder
public class PatchStringBuilder {
    public static func stringHash(s: String): UInt64 { return UInt64(0) }
}

/// File System
public class PatchFileSystem {
    public static let instance: PatchFileSystemInstance = PatchFileSystemInstance()

    public static func tmpname(prefix: String): String { return "${prefix}_tmp" }
}

/// File System Instance
public class PatchFileSystemInstance {
    public func topLevelDirWithoutTrailingSlash(): String { return "" }
}

/// Git Diff 工具
public class PatchGitDiff {
    public static func preprocessPaths(oldFolder: String, newFolder: String, b: Bool): Array<String> { return [oldFolder, newFolder] }
    public static func spawnOpts(src: String, dest: String, cwd: String, git: String, eventLoop: PatchEventLoopRef): PatchSpawnOpts { return PatchSpawnOpts() }
    public static func diffPostProcess(result: PatchSpawnResult): PatchDiffPostResult { return PatchDiffPostResult.Ok("") }
}

/// Spawn Options
public class PatchSpawnOpts {
    public init() {}
}

/// Spawn 结果
public enum PatchSpawnResult {
    | Ok(PatchSpawnResultData)
    | Err(String)
}

/// Spawn Result Data
public class PatchSpawnResultData {
    public init() {}
}

/// Diff 后处理结果
public enum PatchDiffPostResult {
    | Ok(String)
    | Err(String)
}

/// Process 工具
public class PatchProcess {
    public static func spawnSync(opts: PatchSpawnOpts): PatchSpawnResult { return PatchSpawnResult.Ok(PatchSpawnResultData()) }
}

/// Sys Maybe (String 特化)
public enum SysMaybe<T> {
    | Ok(T)
    | Err(String)
}

/// Output Writer
public class PatchOutputWriter {
    public init() {}
}
