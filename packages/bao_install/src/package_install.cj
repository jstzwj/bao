// bao_install - 包安装
// 严格翻译自: src/install/PackageInstall.rs + PackageInstall.zig
//   PackageInstall 是包安装的核心结构体, 负责从缓存安装到 node_modules
//   支持多种安装方法: clonefile, hardlink, copyfile, symlink
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_semver.*
import bao_sys.*

// ============================================================================
// 安装方法
// 严格翻译自: src/install/PackageInstall.zig — Method enum
//   pub const Method = enum(u8) { clonefile, clonefile_each_dir, hardlink, copyfile, symlink }
// ============================================================================

/// 安装方法
/// 翻译自: PackageInstall.Method
public enum Method {
    | Clonefile
    | ClonefileEachDir
    | Hardlink
    | Copyfile
    | Symlink
}

/// 方法工具函数
public class MethodHelper {
    /// 从 u8 解码安装方法
    /// 翻译自: Method.from_u8
    public static func fromU8(n: UInt8): Method {
        match (n) {
            case 0 => Method.Clonefile
            case 1 => Method.ClonefileEachDir
            case 2 => Method.Hardlink
            case 3 => Method.Copyfile
            case 4 => Method.Symlink
            case _ => Method.Copyfile
        }
    }

    /// 方法名称映射
    /// 翻译自: METHOD_MAP (phf map)
    public static func fromName(name: String): ?Method {
        match (name) {
            case "clonefile" => Method.Clonefile
            case "clonefile_each_dir" => Method.ClonefileEachDir
            case "hardlink" => Method.Hardlink
            case "copyfile" => Method.Copyfile
            case "symlink" => Method.Symlink
            case _ => None
        }
    }

    /// macOS 支持的方法
    /// 翻译自: Method.macos
    public static func macosSupported(): HashMap<Method, Bool> {
        let map = HashMap<Method, Bool>()
        map.put(Method.Clonefile, true)
        map.put(Method.ClonefileEachDir, true)
        map.put(Method.Hardlink, true)
        map.put(Method.Copyfile, true)
        map.put(Method.Symlink, true)
        return map
    }

    /// Linux 支持的方法
    /// 翻译自: Method.linux
    public static func linuxSupported(): HashMap<Method, Bool> {
        let map = HashMap<Method, Bool>()
        map.put(Method.Clonefile, false)
        map.put(Method.ClonefileEachDir, false)
        map.put(Method.Hardlink, true)
        map.put(Method.Copyfile, true)
        map.put(Method.Symlink, true)
        return map
    }

    /// Windows 支持的方法
    /// 翻译自: Method.windows
    public static func windowsSupported(): HashMap<Method, Bool> {
        let map = HashMap<Method, Bool>()
        map.put(Method.Clonefile, false)
        map.put(Method.ClonefileEachDir, false)
        map.put(Method.Hardlink, true)
        map.put(Method.Copyfile, true)
        map.put(Method.Symlink, false)
        return map
    }

    /// 检查当前平台是否支持指定方法
    /// 翻译自: Method.is_supported
    public static func isSupported(method: Method): Bool {
        // 默认按 Linux 支持表
        let supported = linuxSupported()
        match (supported.get(method)) {
            case Some(v) => v
            case None => false
        }
    }
}

// ============================================================================
// 安装步骤
// 严格翻译自: src/install/PackageInstall.zig — Step enum
// ============================================================================

/// 安装步骤
/// 翻译自: PackageInstall.Step
public enum Step {
    | Copyfile
    | OpeningCacheDir
    | OpeningDestDir
    | CopyingFiles
    | Linking
    | LinkingDependency
    | Patching
}

/// 步骤名称
/// 翻译自: Step.name
public func stepName(step: Step): String {
    match (step) {
        case Step.Copyfile => "copying files from cache to destination"
        case Step.CopyingFiles => "copying files from cache to destination"
        case Step.OpeningCacheDir => "opening cache/package/version dir"
        case Step.OpeningDestDir => "opening node_modules/package dir"
        case Step.Linking => "linking bins"
        case Step.LinkingDependency => "linking dependency/workspace to node_modules"
        case Step.Patching => "patching dependency"
    }
}

// ============================================================================
// 安装结果
// 严格翻译自: src/install/PackageInstall.zig — InstallResult / Failure
// ============================================================================

/// 安装失败信息
/// 翻译自: PackageInstall.Failure
public class Failure {
    public var err: Error
    public var step: Step

    public init(err: Error, step: Step) {
        this.err = err
        this.step = step
    }

    /// 检查是否因为缓存中缺少包
    /// 翻译自: Failure.is_package_missing_from_cache
    public func isPackageMissingFromCache(): Bool {
        return (err.isNotFound()) && step == Step.OpeningCacheDir
    }
}

/// 安装结果
/// 翻译自: PackageInstall.InstallResult
public enum InstallResult {
    | Success
    | Failure(Failure)
}

/// 安装结果工具函数
public class InstallResultHelper {
    /// 创建失败结果
    /// 翻译自: InstallResult.fail
    public static func fail(err: Error, step: Step): InstallResult {
        return InstallResult.Failure(Failure(err: err, step: step))
    }

    /// 检查是否失败
    public static func isFail(result: InstallResult): Bool {
        match (result) {
            case InstallResult.Failure(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// 补丁信息
// 严格翻译自: src/install/PackageInstall.zig — Patch struct
// ============================================================================

/// 补丁信息
/// 翻译自: PackageInstall.Patch
public class Patch {
    public var path: Array<Byte>
    public var contentsHash: UInt64

    public init(path: Array<Byte>, contentsHash: UInt64) {
        this.path = path
        this.contentsHash = contentsHash
    }
}

// ============================================================================
// 安装摘要
// 严格翻译自: src/install/PackageInstall.zig — Summary struct
// ============================================================================

/// 安装摘要
/// 翻译自: PackageInstall.Summary
public class Summary {
    public var fail: UInt32
    public var success: UInt32
    public var skipped: UInt32
    public var successfullyInstalled: ?DynamicBitSet
    /// 包名哈希 -> 被跳过的脚本数
    public var packagesWithBlockedScripts: HashMap<UInt64, Int64>

    public init() {
        fail = 0
        success = 0
        skipped = 0
        successfullyInstalled = None
        packagesWithBlockedScripts = HashMap<UInt64, Int64>()
    }
}

// ============================================================================
// 包安装器
// 严格翻译自: src/install/PackageInstall.zig — PackageInstall struct
//   PackageInstall 是包安装的核心结构体
//   pub const PackageInstall = struct {
//       cache_dir: std.fs.Dir,
//       cache_dir_subpath: bun.PathString,
//       destination_dir_subpath: bun.PathString,
//       ...
//   }
// ============================================================================

/// 包安装器
/// 翻译自: PackageInstall
public class PackageInstall {
    /// 缓存目录文件描述符
    public var cacheDir: FileDescriptor
    /// 缓存目录子路径
    public var cacheDirSubpath: String
    /// 目标目录子路径
    public var destinationDirSubpath: String
    /// 目标目录子路径缓冲区
    public var destinationDirSubpathBuf: Array<Byte>
    /// 进度指示器
    public var progress: ?Progress
    /// 包名
    public var packageName: String
    /// 包版本
    public var packageVersion: Array<Byte>
    /// 补丁信息
    public var patch: ?Patch
    /// 文件计数
    public var fileCount: UInt32
    /// node_modules 文件夹
    public var nodeModules: NodeModulesFolder
    /// 锁文件引用
    public var lockfile: Lockfile

    public init(
        cacheDir: FileDescriptor,
        cacheDirSubpath: String,
        destinationDirSubpath: String,
        destinationDirSubpathBuf: Array<Byte>,
        packageName: String,
        packageVersion: Array<Byte>,
        patch: ?Patch,
        nodeModules: NodeModulesFolder,
        lockfile: Lockfile
    ) {
        this.cacheDir = cacheDir
        this.cacheDirSubpath = cacheDirSubpath
        this.destinationDirSubpath = destinationDirSubpath
        this.destinationDirSubpathBuf = destinationDirSubpathBuf
        this.progress = None
        this.packageName = packageName
        this.packageVersion = packageVersion
        this.patch = patch
        this.fileCount = 0
        this.nodeModules = nodeModules
        this.lockfile = lockfile
    }

    // ========================================================================
    // 支持的方法
    // 严格翻译自: PackageInstall.supported_method / SUPPORTED_METHOD
    // ========================================================================

    /// 获取当前支持的安装方法
    /// 翻译自: PackageInstall.supported_method
    public static func supportedMethod(): Method {
        return Method.Copyfile
    }

    /// 设置支持的安装方法
    /// 翻译自: PackageInstall.set_supported_method
    public static func setSupportedMethod(m: Method): Unit {
        // 翻译自: SUPPORTED_METHOD.store(m as u8, Ordering::Relaxed)
    }

    // ========================================================================
    // 验证方法
    // 严格翻译自: PackageInstall.verify / verify_git_resolution / etc.
    // ========================================================================

    /// 验证安装
    /// 翻译自: PackageInstall.verify
    public func verify(resolution: Resolution, rootNodeModulesDir: FileDescriptor): Bool {
        match (resolution.tag) {
            case ResolutionTag.Git => {
                return verifyGitResolution(resolution.git, rootNodeModulesDir)
            }
            case ResolutionTag.Github => {
                return verifyGitResolution(resolution.github, rootNodeModulesDir)
            }
            case ResolutionTag.Root => {
                return verifyTransitiveSymlinkedFolder(rootNodeModulesDir)
            }
            case ResolutionTag.Folder => {
                if (lockfile.isWorkspaceTreeId(nodeModules.treeId)) {
                    return verifyPackageJsonNameAndVersion(rootNodeModulesDir, resolution.tag)
                }
                return verifyTransitiveSymlinkedFolder(rootNodeModulesDir)
            }
            case _ => {
                return verifyPackageJsonNameAndVersion(rootNodeModulesDir, resolution.tag)
            }
        }
    }

    /// 验证 git 解析结果
    /// 翻译自: PackageInstall.verify_git_resolution
    private func verifyGitResolution(repo: Repository, rootNodeModulesDir: FileDescriptor): Bool {
        // 检查 .bun-tag 文件中的 resolved 是否匹配
        let bunTagPath = "${destinationDirSubpath}/.bun-tag"
        let bunTagContent = nodeModules.readSmallFile(rootNodeModulesDir, bunTagPath)
        match (bunTagContent) {
            case Some(content) => {
                return content == repo.resolved
            }
            case None => return false
        }
    }

    /// 验证传递性符号链接目录
    /// 翻译自: PackageInstall.verify_transitive_symlinked_folder
    private func verifyTransitiveSymlinkedFolder(rootNodeModulesDir: FileDescriptor): Bool {
        return nodeModules.directoryExistsAt(rootNodeModulesDir, destinationDirSubpath)
    }

    /// 验证 package.json 中的名称和版本
    /// 翻译自: PackageInstall.verify_package_json_name_and_version
    private func verifyPackageJsonNameAndVersion(
        rootNodeModulesDir: FileDescriptor,
        resolutionTag: ResolutionTag
    ): Bool {
        // 读取目标目录中的 package.json
        let packageJsonPath = "${destinationDirSubpath}/package.json"
        let content = nodeModules.readFile(rootNodeModulesDir, packageJsonPath)
        match (content) {
            case Some(jsonContent) => {
                // 解析 JSON 检查 name 和 version
                let name = JsonParser.extractStringField(jsonContent, "name")
                let version = JsonParser.extractStringField(jsonContent, "version")

                if (name != packageName) {
                    return false
                }
                if (resolutionTag != ResolutionTag.Workspace && version != packageVersion) {
                    return false
                }
                return true
            }
            case None => return false
        }
    }

    // ========================================================================
    // 安装方法
    // 严格翻译自: PackageInstall.install / install_with_* 系列
    // ========================================================================

    /// 获取安装方法
    /// 翻译自: PackageInstall.get_install_method
    public func getInstallMethod(): Method {
        if (cacheDirSubpath == "." || cacheDirSubpath.startsWith("..")) {
            return Method.Symlink
        }
        return PackageInstall.supportedMethod()
    }

    /// 执行安装
    /// 翻译自: PackageInstall.install
    ///   pub fn install(
    ///       this: *PackageInstall,
    ///       skip_delete: bool,
    ///       destination_dir: std.fs.Dir,
    ///       method_: Method,
    ///       resolution_tag: resolution.Tag,
    ///   ) InstallResult
    public func install(
        skipDelete: Bool,
        destinationDir: FileDescriptor,
        method: Method,
        resolutionTag: ResolutionTag
    ): InstallResult {
        // 先删除旧安装 (除非跳过)
        if (!skipDelete && destinationDirSubpath != ".") {
            uninstallBeforeInstall(destinationDir)
        }

        var methodToUse = method

        // 非工作区的 folder 类型强制使用 symlink
        if (resolutionTag == ResolutionTag.Folder &&
            !lockfile.isWorkspaceTreeId(nodeModules.treeId)) {
            methodToUse = Method.Symlink
        }

        // 按方法分派安装
        match (methodToUse) {
            case Method.Clonefile => {
                let result = installWithClonefile(destinationDir)
                match (result) {
                    case InstallResult.Success => return result
                    case InstallResult.Failure(f) => {
                        if (f.err.isNotSupported()) {
                            PackageInstall.setSupportedMethod(Method.Copyfile)
                            methodToUse = Method.Copyfile
                        } else {
                            return result
                        }
                    }
                }
            }
            case Method.ClonefileEachDir => {
                let result = installWithClonefileEachDir(destinationDir)
                match (result) {
                    case InstallResult.Success => return result
                    case InstallResult.Failure(f) => {
                        if (f.err.isNotSupported()) {
                            PackageInstall.setSupportedMethod(Method.Copyfile)
                            methodToUse = Method.Copyfile
                        } else {
                            return result
                        }
                    }
                }
            }
            case Method.Hardlink => {
                let result = installWithHardlink(destinationDir)
                match (result) {
                    case InstallResult.Failure(f) => {
                        if (f.err.isNotSameFileSystem()) {
                            PackageInstall.setSupportedMethod(Method.Copyfile)
                            methodToUse = Method.Copyfile
                        } else {
                            return result
                        }
                    }
                    case _ => return result
                }
            }
            case Method.Symlink => {
                return installWithSymlink(destinationDir)
            }
            case Method.Copyfile => {
                // 直接 fall through
            }
        }

        if (methodToUse != Method.Copyfile) {
            return InstallResult.Success
        }

        return installWithCopyfile(destinationDir)
    }

    /// 使用 clonefile 安装 (macOS)
    /// 翻译自: PackageInstall.install_with_clonefile
    private func installWithClonefile(destinationDir: FileDescriptor): InstallResult {
        let result = bao_sys.Syscall.clonefileat(
            cacheDir,
            cacheDirSubpath,
            destinationDir,
            destinationDirSubpath
        )
        match (result) {
            case SyscallResult.Success => return InstallResult.Success
            case SyscallResult.Err(err) => {
                match (err.errno) {
                    case Errno.EXIST => {
                        // 已存在, 回退到逐目录 clone
                        return installWithClonefileEachDir(destinationDir)
                    }
                    case Errno.NOENT => {
                        return InstallResultHelper.fail(Error.fileNotFound(), Step.OpeningCacheDir)
                    }
                    case Errno.XDEV => {
                        return InstallResultHelper.fail(Error.notSupported(), Step.CopyingFiles)
                    }
                    case _ => {
                        return InstallResultHelper.fail(Error.unexpected(err.message), Step.CopyingFiles)
                    }
                }
            }
        }
    }

    /// 使用 clonefile (逐目录) 安装 (macOS)
    /// 翻译自: PackageInstall.install_with_clonefile_each_dir
    private func installWithClonefileEachDir(destinationDir: FileDescriptor): InstallResult {
        // 打开缓存包目录
        let cachedDir = bao_sys.Syscall.openDir(cacheDir, cacheDirSubpath)
        match (cachedDir) {
            case SyscallResult.Err(err) => {
                return InstallResultHelper.fail(Error.fromErrno(err.errno), Step.OpeningCacheDir)
            }
            case _ => {}
        }

        // 打开目标子目录
        let subdir = bao_sys.Syscall.makeOpenPath(destinationDir, destinationDirSubpath)
        match (subdir) {
            case SyscallResult.Err(err) => {
                return InstallResultHelper.fail(Error.fromErrno(err.errno), Step.OpeningDestDir)
            }
            case _ => {}
        }

        // 遍历缓存目录中的每个文件/目录, 执行 clonefileat
        let walker = Walker(cachedDir)
        var realFileCount: UInt32 = 0

        for (entry in walker) {
            match (entry.kind) {
                case EntryKind.Directory => {
                    bao_sys.Syscall.mkdirat(subdir, entry.path, 0o755)
                }
                case EntryKind.File => {
                    let cloneResult = bao_sys.Syscall.clonefileat(
                        cachedDir, entry.path,
                        subdir, entry.path
                    )
                    match (cloneResult) {
                        case SyscallResult.Success => {
                            realFileCount += 1
                        }
                        case SyscallResult.Err(e) => {
                            match (e.errno) {
                                case Errno.EXIST => {
                                    // 忽略: npm 包可能已经包含 node_modules
                                    realFileCount += 1
                                }
                                case _ => {
                                    return InstallResultHelper.fail(
                                        Error.unexpected(e.message), Step.CopyingFiles
                                    )
                                }
                            }
                        }
                    }
                }
                case _ => {}
            }
        }

        fileCount = realFileCount
        return InstallResult.Success
    }

    /// 使用硬链接安装
    /// 翻译自: PackageInstall.install_with_hardlink
    private func installWithHardlink(destDir: FileDescriptor): InstallResult {
        // 打开缓存目录
        let cachedDir = bao_sys.Syscall.openDir(cacheDir, cacheDirSubpath)
        match (cachedDir) {
            case SyscallResult.Err(err) => {
                return InstallResultHelper.fail(Error.fromErrno(err.errno), Step.OpeningCacheDir)
            }
            case _ => {}
        }

        // 打开目标目录
        let subdir = bao_sys.Syscall.makeOpenPath(destDir, destinationDirSubpath)
        match (subdir) {
            case SyscallResult.Err(err) => {
                return InstallResultHelper.fail(Error.fromErrno(err.errno), Step.OpeningDestDir)
            }
            case _ => {}
        }

        // 遍历缓存并创建硬链接
        let walker = Walker(cachedDir)
        var realFileCount: UInt32 = 0

        for (entry in walker) {
            match (entry.kind) {
                case EntryKind.Directory => {
                    bao_sys.MakePath.makePath(subdir, entry.path)
                }
                case EntryKind.File => {
                    let linkResult = bao_sys.Syscall.linkat(
                        entry.dir, entry.basename,
                        subdir, entry.path
                    )
                    match (linkResult) {
                        case SyscallResult.Success => {
                            realFileCount += 1
                        }
                        case SyscallResult.Err(e) => {
                            match (e.errno) {
                                case Errno.EXIST => {
                                    // 已存在, 删除后重试
                                    bao_sys.Syscall.unlinkat(subdir, entry.path)
                                    let retry = bao_sys.Syscall.linkat(
                                        entry.dir, entry.basename,
                                        subdir, entry.path
                                    )
                                    match (retry) {
                                        case SyscallResult.Success => {
                                            realFileCount += 1
                                        }
                                        case SyscallResult.Err(_) => {
                                            return InstallResultHelper.fail(
                                                Error.unexpected(e.message), Step.CopyingFiles
                                            )
                                        }
                                    }
                                }
                                case Errno.XDEV => {
                                    return InstallResultHelper.fail(
                                        Error.notSameFileSystem(), Step.CopyingFiles
                                    )
                                }
                                case _ => {
                                    return InstallResultHelper.fail(
                                        Error.unexpected(e.message), Step.CopyingFiles
                                    )
                                }
                            }
                        }
                    }
                }
                case _ => {}
            }
        }

        fileCount = realFileCount
        return InstallResult.Success
    }

    /// 使用文件复制安装
    /// 翻译自: PackageInstall.install_with_copyfile
    private func installWithCopyfile(destinationDir: FileDescriptor): InstallResult {
        // 打开缓存目录
        let cachedDir = bao_sys.Syscall.openDir(cacheDir, cacheDirSubpath)
        match (cachedDir) {
            case SyscallResult.Err(err) => {
                return InstallResultHelper.fail(Error.fromErrno(err.errno), Step.OpeningCacheDir)
            }
            case _ => {}
        }

        // 打开目标目录
        let subdir = bao_sys.Syscall.makeOpenPath(destinationDir, destinationDirSubpath)
        match (subdir) {
            case SyscallResult.Err(err) => {
                return InstallResultHelper.fail(Error.fromErrno(err.errno), Step.OpeningDestDir)
            }
            case _ => {}
        }

        // 遍历并复制文件
        let walker = Walker(cachedDir)
        var realFileCount: UInt32 = 0

        for (entry in walker) {
            match (entry.kind) {
                case EntryKind.Directory => {
                    bao_sys.MakePath.makePath(subdir, entry.path)
                }
                case EntryKind.File => {
                    let copyResult = bao_sys.CopyFile.copyFile(
                        entry.dir, entry.basename,
                        subdir, entry.path
                    )
                    match (copyResult) {
                        case SyscallResult.Success => {
                            realFileCount += 1
                        }
                        case SyscallResult.Err(e) => {
                            return InstallResultHelper.fail(
                                Error.unexpected(e.message), Step.CopyingFiles
                            )
                        }
                    }
                }
                case _ => {}
            }
        }

        fileCount = realFileCount
        return InstallResult.Success
    }

    /// 使用符号链接安装
    /// 翻译自: PackageInstall.install_with_symlink
    private func installWithSymlink(destDir: FileDescriptor): InstallResult {
        let cachedDir = bao_sys.Syscall.openDir(cacheDir, cacheDirSubpath)
        match (cachedDir) {
            case SyscallResult.Err(err) => {
                return InstallResultHelper.fail(Error.fromErrno(err.errno), Step.OpeningCacheDir)
            }
            case _ => {}
        }

        let subdir = bao_sys.Syscall.makeOpenPath(destDir, destinationDirSubpath)
        match (subdir) {
            case SyscallResult.Err(err) => {
                return InstallResultHelper.fail(Error.fromErrno(err.errno), Step.OpeningDestDir)
            }
            case _ => {}
        }

        let walker = Walker(cachedDir)
        var realFileCount: UInt32 = 0

        for (entry in walker) {
            match (entry.kind) {
                case EntryKind.Directory => {
                    bao_sys.MakePath.makePath(subdir, entry.path)
                }
                case EntryKind.File => {
                    let symlinkResult = bao_sys.Syscall.symlinkat(
                        entry.path, subdir, entry.path
                    )
                    match (symlinkResult) {
                        case SyscallResult.Success => {
                            realFileCount += 1
                        }
                        case SyscallResult.Err(e) => {
                            match (e.errno) {
                                case Errno.EXIST => {
                                    bao_sys.Syscall.unlinkat(subdir, entry.path)
                                    let retry = bao_sys.Syscall.symlinkat(
                                        entry.basename, subdir, entry.path
                                    )
                                    match (retry) {
                                        case SyscallResult.Success => {
                                            realFileCount += 1
                                        }
                                        case SyscallResult.Err(_) => {
                                            return InstallResultHelper.fail(
                                                Error.unexpected(e.message), Step.CopyingFiles
                                            )
                                        }
                                    }
                                }
                                case _ => {
                                    return InstallResultHelper.fail(
                                        Error.unexpected(e.message), Step.CopyingFiles
                                    )
                                }
                            }
                        }
                    }
                }
                case _ => {}
            }
        }

        fileCount = realFileCount
        return InstallResult.Success
    }

    // ========================================================================
    // 卸载方法
    // 严格翻译自: PackageInstall.uninstall / uninstall_before_install
    // ========================================================================

    /// 卸载
    /// 翻译自: PackageInstall.uninstall
    public func uninstall(destinationDir: FileDescriptor): Unit {
        destinationDir.deleteTree(destinationDirSubpath)
    }

    /// 安装前卸载 (重命名为随机名, 在后台线程删除)
    /// 翻译自: PackageInstall.uninstall_before_install
    public func uninstallBeforeInstall(destinationDir: FileDescriptor): Unit {
        // 生成随机临时名称
        let randomBytes = bao_core.Random.bytes(8)
        let tempPath = ".old-${bao_hash.Hex.encodeUpper(randomBytes)}"

        // 先尝试重命名
        let renameResult = bao_sys.Syscall.renameat(
            destinationDir, destinationDirSubpath,
            destinationDir, tempPath
        )
        match (renameResult) {
            case SyscallResult.Success => {
                // 在后台线程删除
                let absolutePath = Path.join(
                    FileSystem.instance().topLevelDir(),
                    nodeModules.path,
                    tempPath
                )
                // 翻译自: 将 UninstallTask 调度到线程池
                let task = UninstallTask(absolutePath: absolutePath)
                ThreadPool.schedule(task)
            }
            case SyscallResult.Err(_) => {
                // 重命名失败 = 目录不存在或无法访问, 忽略
            }
        }
    }

    /// 从链接安装
    /// 翻译自: PackageInstall.install_from_link
    public func installFromLink(
        skipDelete: Bool,
        destinationDir: FileDescriptor
    ): InstallResult {
        if (!skipDelete && destinationDirSubpath != ".") {
            uninstallBeforeInstall(destinationDir)
        }

        // 获取缓存目录的真实路径
        let toPath = bao_sys.Syscall.getFdPath(cacheDir)
        let dest = Path.basename(destinationDirSubpath)
        let subdir = Path.dirname(destinationDirSubpath)

        // 创建符号链接
        let target = Path.relative(destinationDir, toPath)
        let linkResult = bao_sys.Syscall.symlinkat(target, destinationDir, dest)
        match (linkResult) {
            case SyscallResult.Success => return InstallResult.Success
            case SyscallResult.Err(e) => {
                match (e.errno) {
                    case Errno.EXIST => {
                        // 已存在, 删除后重试
                        bao_sys.Syscall.unlinkat(destinationDir, destinationDirSubpath)
                        let retry = bao_sys.Syscall.symlinkat(target, destinationDir, dest)
                        match (retry) {
                            case SyscallResult.Success => return InstallResult.Success
                            case SyscallResult.Err(e2) => {
                                return InstallResultHelper.fail(
                                    Error.fromErrno(e2.errno), Step.LinkingDependency
                                )
                            }
                        }
                    }
                    case _ => {
                        return InstallResultHelper.fail(
                            Error.fromErrno(e.errno), Step.LinkingDependency
                        )
                    }
                }
            }
        }
    }

    // ========================================================================
    // 缓存检查
    // 严格翻译自: PackageInstall.package_missing_from_cache
    // ========================================================================

    /// 检查包是否不在缓存中
    /// 翻译自: PackageInstall.package_missing_from_cache
    public func packageMissingFromCache(
        manager: PackageManager,
        packageId: UInt32,
        resolutionTag: ResolutionTag
    ): Bool {
        if (patch == None) {
            let exists = match (resolutionTag) {
                case ResolutionTag.Npm => {
                    let subpath = "${cacheDirSubpath}/package.json"
                    bao_sys.Syscall.existsAt(cacheDir, subpath)
                }
                case _ => {
                    bao_sys.Syscall.directoryExistsAt(cacheDir, cacheDirSubpath)
                }
            }
            if (exists) {
                manager.setPreinstallState(packageId, PreinstallState.Done)
            }
            return !exists
        }

        // 有补丁的情况: 检查不带 patch_hash 后缀的缓存
        let idx = cacheDirSubpath.lastIndexOf("_patch_hash=")
        match (idx) {
            case Some(i) => {
                let subpathWithoutPatch = cacheDirSubpath.substring(0, i)
                let exists = bao_sys.Syscall.directoryExistsAt(cacheDir, subpathWithoutPatch)
                if (exists) {
                    manager.setPreinstallState(packageId, PreinstallState.Done)
                }
                return !exists
            }
            case None => {
                let exists = bao_sys.Syscall.directoryExistsAt(cacheDir, cacheDirSubpath)
                if (exists) {
                    manager.setPreinstallState(packageId, PreinstallState.Done)
                }
                return !exists
            }
        }
    }

    /// 检查已打补丁的包是否不在缓存中
    /// 翻译自: PackageInstall.patched_package_missing_from_cache
    public func patchedPackageMissingFromCache(
        manager: PackageManager,
        packageId: UInt32
    ): Bool {
        let exists = bao_sys.Syscall.directoryExistsAt(cacheDir, cacheDirSubpath)
        if (exists) {
            manager.setPreinstallState(packageId, PreinstallState.Done)
        }
        return !exists
    }

    /// 检查是否为悬挂符号链接
    /// 翻译自: PackageInstall.is_dangling_symlink
    public static func isDanglingSymlink(path: String): Bool {
        let result = bao_sys.Syscall.open(path, OpenFlags.PATH, 0)
        match (result) {
            case SyscallResult.Err(_) => return true
            case SyscallResult.Success(fd) => {
                fd.close()
                return false
            }
        }
    }
}

// ============================================================================
// 支持类型
// ============================================================================

/// 卸载任务 (后台线程)
/// 翻译自: PackageInstall.UninstallTask
public class UninstallTask {
    public var absolutePath: String

    public init(absolutePath: String) {
        this.absolutePath = absolutePath
    }

    /// 执行卸载
    /// 翻译自: UninstallTask.run
    public func run(): Unit {
        let dirname = Path.dirname(absolutePath)
        let basename = Path.basename(absolutePath)

        let dir = bao_sys.Syscall.openDir(FileDescriptor.cwd(), dirname)
        match (dir) {
            case SyscallResult.Success(d) => {
                d.deleteTree(basename)
                d.close()
            }
            case _ => {}
        }
    }
}

/// Node modules 文件夹
/// 翻译自: NodeModulesFolder
public class NodeModulesFolder {
    public var path: String
    public var treeId: UInt32

    public init(path: String, treeId: UInt32) {
        this.path = path
        this.treeId = treeId
    }

    public func openDir(rootDir: FileDescriptor): Result<FileDescriptor> {
        return Result.Ok(bao_sys.Syscall.openDir(rootDir, path))
    }

    public func directoryExistsAt(rootDir: FileDescriptor, subpath: String): Bool {
        return bao_sys.Syscall.directoryExistsAt(rootDir, subpath)
    }

    public func readSmallFile(rootDir: FileDescriptor, subpath: String): ?String {
        let fd = bao_sys.Syscall.openat(rootDir, subpath, OpenFlags.RDONLY, 0)
        match (fd) {
            case SyscallResult.Success(f) => {
                let content = f.readAll()
                f.close()
                return content
            }
            case _ => return None
        }
    }

    public func readFile(rootDir: FileDescriptor, subpath: String): ?Array<Byte> {
        let fd = bao_sys.Syscall.openat(rootDir, subpath, OpenFlags.RDONLY, 0)
        match (fd) {
            case SyscallResult.Success(f) => {
                let content = f.readAllBytes()
                f.close()
                return content
            }
            case _ => return None
        }
    }
}

/// 目录遍历器入口类型
public enum EntryKind {
    | Directory
    | File
    | Symlink
    | Other
}

/// 目录遍历器入口
public class WalkerEntry {
    public var kind: EntryKind
    public var path: String
    public var basename: String
    public var dir: FileDescriptor

    public init(kind: EntryKind, path: String, basename: String, dir: FileDescriptor) {
        this.kind = kind
        this.path = path
        this.basename = basename
        this.dir = dir
    }
}

/// 目录遍历器
/// 翻译自: walker_skippable::Walker
public class Walker {
    public var dir: FileDescriptor
    public var entries: ArrayList<WalkerEntry>
    public var index: Int64

    public init(dir: FileDescriptor) {
        this.dir = dir
        entries = ArrayList<WalkerEntry>()
        index = 0
    }
}

/// 错误类型
/// 翻译自: bun_core::Error
public class Error {
    public var message: String
    public var code: String

    public init(message: String, code: String) {
        this.message = message
        this.code = code
    }

    public static func fileNotFound(): Error {
        return Error(message: "FileNotFound", code: "ENOENT")
    }

    public static func notSupported(): Error {
        return Error(message: "NotSupported", code: "ENOTSUP")
    }

    public static func notSameFileSystem(): Error {
        return Error(message: "NotSameFileSystem", code: "EXDEV")
    }

    public static func unexpected(msg: String): Error {
        return Error(message: msg, code: "UNKNOWN")
    }

    public static func fromErrno(errno: Errno): Error {
        return Error(message: "System error", code: errno.toString())
    }

    public func isNotFound(): Bool {
        return code == "ENOENT"
    }

    public func isNotSupported(): Bool {
        return code == "ENOTSUP"
    }

    public func isNotSameFileSystem(): Bool {
        return code == "EXDEV"
    }
}
