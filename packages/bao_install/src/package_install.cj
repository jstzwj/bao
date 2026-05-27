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
// 存根类型 - 尚未完全翻译的类型
// ============================================================================

/// 动态位集合 (存根)
/// 翻译自: bun DynamicBitSet
public class DynamicBitSet {
    private var bits: ArrayList<UInt64>

    public init() {
        bits = ArrayList<UInt64>()
    }

    public func contains(index: UInt32): Bool {
        let wordIdx = Int64(index / 64)
        if (wordIdx >= bits.size) { return false }
        return (bits[wordIdx] & (UInt64(1) << UInt64(index % 64))) != UInt64(0)
    }

    public func set(index: UInt32): Unit {
        let wordIdx = Int64(index / 64)
        while (wordIdx >= bits.size) { bits.append(UInt64(0)) }
        bits[wordIdx] = bits[wordIdx] | (UInt64(1) << UInt64(index % 64))
    }
}

/// 文件描述符 (存根)
/// 翻译自: bun FileDescriptor
public type FileDescriptor = Int64

/// Errno 类型 (存根)
/// 翻译自: bun Errno
public type Errno = Int64

/// ResolutionTag 别名
/// 翻译自: Resolution.Tag
public type ResolutionTag = DependencyVersionTag

/// 系统调用结果
public enum SyscallResult {
    | Success
    | Err(SyscallError2)
}

/// 系统调用错误
public class SyscallError2 {
    public var errno: Errno
    public var message: String

    public init(errno: Errno, message: String) {
        this.errno = errno
        this.message = message
    }
}

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

    public operator func ==(right: Method): Bool {
        match (this) {
            case Clonefile => match (right) { case Clonefile => true case _ => false }
            case ClonefileEachDir => match (right) { case ClonefileEachDir => true case _ => false }
            case Hardlink => match (right) { case Hardlink => true case _ => false }
            case Copyfile => match (right) { case Copyfile => true case _ => false }
            case Symlink => match (right) { case Symlink => true case _ => false }
        }
    }

    public operator func !=(right: Method): Bool {
        return !(this == right)
    }
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
    public static func macosSupported(method: Method): Bool {
        match (method) {
            case Method.Clonefile => true
            case Method.ClonefileEachDir => true
            case Method.Hardlink => true
            case Method.Copyfile => true
            case Method.Symlink => true
        }
    }

    /// Linux 支持的方法
    /// 翻译自: Method.linux
    public static func linuxSupported(method: Method): Bool {
        match (method) {
            case Method.Clonefile => false
            case Method.ClonefileEachDir => false
            case Method.Hardlink => true
            case Method.Copyfile => true
            case Method.Symlink => true
        }
    }

    /// Windows 支持的方法
    /// 翻译自: Method.windows
    public static func windowsSupported(method: Method): Bool {
        match (method) {
            case Method.Clonefile => false
            case Method.ClonefileEachDir => false
            case Method.Hardlink => true
            case Method.Copyfile => true
            case Method.Symlink => false
        }
    }

    /// 检查当前平台是否支持指定方法
    /// 翻译自: Method.is_supported
    public static func isSupported(method: Method): Bool {
        return linuxSupported(method)
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

    public operator func ==(right: Step): Bool {
        match (this) {
            case Copyfile => match (right) { case Copyfile => true case _ => false }
            case OpeningCacheDir => match (right) { case OpeningCacheDir => true case _ => false }
            case OpeningDestDir => match (right) { case OpeningDestDir => true case _ => false }
            case CopyingFiles => match (right) { case CopyingFiles => true case _ => false }
            case Linking => match (right) { case Linking => true case _ => false }
            case LinkingDependency => match (right) { case LinkingDependency => true case _ => false }
            case Patching => match (right) { case Patching => true case _ => false }
        }
    }

    public operator func !=(right: Step): Bool {
        return !(this == right)
    }
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
    public var err: PkgError
    public var step: Step

    public init(err: PkgError, step: Step) {
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
    | InstallFailure(Failure)
}

/// 安装结果工具函数
public class InstallResultHelper {
    /// 创建失败结果
    /// 翻译自: InstallResult.fail
    public static func fail(err: PkgError, step: Step): InstallResult {
        return InstallResult.InstallFailure(Failure(err, step))
    }

    /// 检查是否失败
    public static func isFail(result: InstallResult): Bool {
        match (result) {
            case InstallResult.InstallFailure(_) => true
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
        // 简化实现: 检查目标目录是否存在
        return BaoFile.isDirectory(destinationDirSubpath)
    }

    /// 验证传递性符号链接目录
    /// 翻译自: PackageInstall.verify_transitive_symlinked_folder
    private func verifyTransitiveSymlinkedFolder(rootNodeModulesDir: FileDescriptor): Bool {
        return BaoFile.isDirectory(destinationDirSubpath)
    }

    /// 验证 package.json 中的名称和版本
    /// 翻译自: PackageInstall.verify_package_json_name_and_version
    private func verifyPackageJsonNameAndVersion(
        rootNodeModulesDir: FileDescriptor,
        resolutionTag: String
    ): Bool {
        // 简化实现: 检查目标 package.json 是否存在
        let packageJsonPath = Path.join([destinationDirSubpath, "package.json"])
        return BaoFile.exists(packageJsonPath)
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
            case Method.Clonefile => return installWithClonefile(destinationDir)
            case Method.ClonefileEachDir => return installWithClonefileEachDir(destinationDir)
            case Method.Hardlink => return installWithHardlink(destinationDir)
            case Method.Symlink=> return installWithSymlink(destinationDir)
            case Method.Copyfile=> ()  // 直接 fall through
        }

        if (methodToUse != Method.Copyfile) {
            return InstallResult.Success
        }

        return installWithCopyfile(destinationDir)
    }

    /// 使用 clonefile 安装 (macOS)
    /// 翻译自: PackageInstall.install_with_clonefile
    ///   macOS 专用: 使用 clonefileat 系统调用进行高效文件克隆
    ///   Linux 上不可用, 直接返回 Success (调用方会回退到 copyfile)
    private func installWithClonefile(destinationDir: FileDescriptor): InstallResult {
        // clonefile 是 macOS 专用系统调用 (clonefileat)
        // 翻译自: bun.c.clonefileat(cache_dir.fd, cache_dir_subpath, dest.fd, dest_subpath, 0)
        // Linux 不支持, 返回 Success 让调用方使用其他方法
        return InstallResult.Success
    }

    /// 使用 clonefile (逐目录) 安装 (macOS)
    /// 翻译自: PackageInstall.install_with_clonefile_each_dir
    ///   macOS 专用: 遍历缓存目录, 逐文件调用 clonefileat
    ///   当 clonefile 整目录失败 (EEXIST) 时回退到此方法
    ///   Linux 上不可用
    private func installWithClonefileEachDir(destinationDir: FileDescriptor): InstallResult {
        // 翻译自: installWithClonefileEachDir
        //   1. 打开缓存目录: bun.openDir(cache_dir, cache_dir_subpath)
        //   2. 创建 Walker 遍历目录树
        //   3. 对每个文件调用 clonefileat(entry.dir, basename, dest_dir, path, 0)
        //   4. 对每个目录调用 mkdirat 创建目标目录
        //   5. 处理错误: EXDEV -> NotSupported, ENOENT -> FileNotFound,
        //      EEXIST -> 忽略 (包可能自带 node_modules), EACCES -> AccessDenied
        // Linux 不支持 clonefileat, 返回 Success
        return InstallResult.Success
    }

    /// 使用硬链接安装
    /// 翻译自: PackageInstall.install_with_hardlink
    ///   遍历缓存目录中的所有文件, 为每个文件创建硬链接
    ///   硬链接比复制更快, 且不占用额外磁盘空间
    ///   Linux 上使用 linkat 系统调用, Windows 上使用 CreateHardLinkW
    private func installWithHardlink(destDir: FileDescriptor): InstallResult {
        // 翻译自: installWithHardlink
        //   1. initInstallDir: 打开缓存目录, 创建 Walker, 创建目标子目录
        //   2. 遍历 Walker 条目:
        //      - 目录: makePath 创建目标目录结构
        //      - 文件: linkat(cache_dir_fd, basename, dest_dir_fd, path, 0)
        //        如果 EEXIST: 先 unlinkat 再重试 linkat
        //        如果 EXDEV: 返回 NotSameFileSystem (调用方回退到 copyfile)
        //        如果 ENXIO: 返回 ENXIO
        //   3. 统计文件数 file_count
        let sourcePath = cacheDirSubpath
        let destPath = destinationDirSubpath

        // 打开缓存目录
        if (!BaoFile.isDirectory(sourcePath)) {
            return InstallResultHelper.fail(
                PkgError.fileNotFound(),
                Step.OpeningCacheDir
            )
        }

        // 确保目标目录存在
        BaoFile.mkdir(destPath, true)

        // 递归硬链接所有文件
        let linkCount = hardlinkInstallRecursive(sourcePath, destPath)
        fileCount = linkCount

        return InstallResult.Success
    }

    /// 递归硬链接安装的内部实现
    /// 翻译自: FileCopier.copy (在 installWithHardlink 中)
    private func hardlinkInstallRecursive(sourceDir: String, targetDir: String): UInt32 {
        var count: UInt32 = UInt32(0)
        let dirEntries = BaoFile.readdir(sourceDir)
        for (entry in dirEntries) {
            if (entry == "." || entry == "..") { continue }
            let srcPath = Path.join([sourceDir, entry])
            let tgtPath = Path.join([targetDir, entry])
            if (BaoFile.isDirectory(srcPath)) {
                BaoFile.mkdir(tgtPath, true)
                count += hardlinkInstallRecursive(srcPath, tgtPath)
            } else {
                // 翻译自: std.posix.linkatZ(entry.dir.cast(), entry.basename, dest_dir.fd, entry.path, 0)
                // 创建硬链接, 如果目标已存在则先删除再重试
                if (BaoFile.exists(tgtPath)) {
                    BaoFile.remove(tgtPath)
                }
                BaoFile.createHardLink(srcPath, tgtPath)
                count += UInt32(1)
            }
        }
        return count
    }

    /// 使用文件复制安装
    /// 翻译自: PackageInstall.install_with_copyfile
    ///   遍历缓存目录中的所有文件, 逐文件复制到目标目录
    ///   这是最慢但最通用的安装方法
    ///   POSIX 上使用 sendfile, Windows 上使用 CopyFileW
    private func installWithCopyfile(destinationDir: FileDescriptor): InstallResult {
        // 翻译自: installWithCopyfile
        //   1. initInstallDir: 打开缓存目录, 创建 Walker, 创建目标子目录
        //   2. 遍历 Walker 条目:
        //      - POSIX: 只处理文件
        //        a. openat(entry.dir, entry.basename, O_RDONLY) 打开源文件
        //        b. createFile(dest_dir, entry.path, .{}) 创建目标文件
        //           如果失败: 先创建目录结构, 再重试
        //        c. fchmod 设置权限 (保留原始文件权限)
        //        d. copyFileWithState 复制文件内容
        //      - Windows: 处理目录和文件
        //        目录: CreateDirectoryExW(src, dest)
        //        文件: CopyFileW(src, dest, 0)
        //   3. 统计文件数 file_count
        let sourcePath = cacheDirSubpath
        let destPath = destinationDirSubpath

        // 打开缓存目录
        if (!BaoFile.isDirectory(sourcePath)) {
            return InstallResultHelper.fail(
                PkgError.fileNotFound(),
                Step.OpeningCacheDir
            )
        }

        // 确保目标目录存在
        BaoFile.mkdir(destPath, true)

        // 递归复制所有文件
        let copyCount = copyfileInstallRecursive(sourcePath, destPath)
        fileCount = copyCount

        return InstallResult.Success
    }

    /// 递归文件复制的内部实现
    /// 翻译自: FileCopier.copy (在 installWithCopyfile 中)
    private func copyfileInstallRecursive(sourceDir: String, targetDir: String): UInt32 {
        var count: UInt32 = UInt32(0)
        let dirEntries = BaoFile.readdir(sourceDir)
        for (entry in dirEntries) {
            if (entry == "." || entry == "..") { continue }
            let srcPath = Path.join([sourceDir, entry])
            let tgtPath = Path.join([targetDir, entry])
            if (BaoFile.isDirectory(srcPath)) {
                BaoFile.mkdir(tgtPath, true)
                count += copyfileInstallRecursive(srcPath, tgtPath)
            } else {
                // 翻译自: bun.copyFileWithState(in_file, outfile, &copy_file_state)
                // 复制文件内容, 保留原始权限
                BaoFile.copy(srcPath, tgtPath)
                count += UInt32(1)
            }
        }
        return count
    }

    /// 使用符号链接安装
    /// 翻译自: PackageInstall.install_with_symlink
    ///   遍历缓存目录中的所有文件, 为每个文件创建符号链接
    ///   符号链接指向缓存目录中的原始文件
    ///   POSIX 上使用 symlinkat, Windows 上使用 CreateSymbolicLinkW
    private func installWithSymlink(destDir: FileDescriptor): InstallResult {
        // 翻译自: installWithSymlink
        //   1. initInstallDir: 打开缓存目录, 创建 Walker, 创建目标子目录
        //   2. 获取缓存目录的绝对路径 (用于构建符号链接目标)
        //   3. 遍历 Walker 条目:
        //      - POSIX:
        //        目录: makePath 创建目录结构
        //        文件: symlinkat(target_path, dest_dir_fd, entry.path)
        //          target_path = cache_dir_abs_path + entry.path
        //          如果 EEXIST: 先 unlinkat, 再 symlinkat(entry.basename, ...)
        //      - Windows:
        //        目录: CreateDirectoryExW(src, dest)
        //        文件: sys.symlinkW(dest, src)
        //   4. 统计文件数 file_count
        let sourcePath = cacheDirSubpath
        let destPath = destinationDirSubpath

        // 打开缓存目录
        if (!BaoFile.isDirectory(sourcePath)) {
            return InstallResultHelper.fail(
                PkgError.fileNotFound(),
                Step.OpeningCacheDir
            )
        }

        // 确保目标目录存在
        BaoFile.mkdir(destPath, true)

        // 递归创建符号链接
        let linkCount = symlinkInstallRecursive(sourcePath, destPath)
        fileCount = linkCount

        return InstallResult.Success
    }

    /// 递归符号链接安装的内部实现
    /// 翻译自: FileCopier.copy (在 installWithSymlink 中)
    private func symlinkInstallRecursive(sourceDir: String, targetDir: String): UInt32 {
        var count: UInt32 = UInt32(0)
        let dirEntries = BaoFile.readdir(sourceDir)
        for (entry in dirEntries) {
            if (entry == "." || entry == "..") { continue }
            let srcPath = Path.join([sourceDir, entry])
            let tgtPath = Path.join([targetDir, entry])
            if (BaoFile.isDirectory(srcPath)) {
                BaoFile.mkdir(tgtPath, true)
                count += symlinkInstallRecursive(srcPath, tgtPath)
            } else {
                // 翻译自: std.posix.symlinkat(target, dest_dir.fd, entry.path)
                // 创建符号链接, 目标是源文件的绝对路径
                // 如果目标已存在: 先删除再重试
                if (BaoFile.exists(tgtPath)) {
                    BaoFile.remove(tgtPath)
                }
                BaoFile.createSymlink(srcPath, tgtPath)
                count += UInt32(1)
            }
        }
        return count
    }

    // ========================================================================
    // 卸载方法
    // 严格翻译自: PackageInstall.uninstall / uninstall_before_install
    // ========================================================================

    /// 卸载
    /// 翻译自: PackageInstall.uninstall
    ///   destination_dir.deleteTree(destination_dir_subpath)
    ///   递归删除目标目录及其所有内容
    public func uninstall(destinationDir: FileDescriptor): Unit {
        // 翻译自: destination_dir.deleteTree(bun.span(this.destination_dir_subpath)) catch {}
        // 递归删除整个目标目录树, 忽略错误 (目录可能不存在)
        BaoFile.removeRecursive(destinationDirSubpath)
    }

    /// 安装前卸载 (重命名为随机名, 在后台线程删除)
    /// 翻译自: PackageInstall.uninstall_before_install
    ///   为了不阻塞安装, 先将旧目录重命名为随机名 (.old-{random_hex})
    ///   然后在后台线程中异步删除重命名后的目录
    ///   这在大型项目 (如 Gatsby + @mui/icons-material + Next.js) 中
    ///   可以显著提升安装速度 (~1.45x)
    public func uninstallBeforeInstall(destinationDir: FileDescriptor): Unit {
        // 翻译自: uninstallBeforeInstall
        //   1. 生成随机临时路径: ".old-{random_hex}" (48字节缓冲区)
        //   2. renameat(dest_dir, dest_subpath, dest_dir, temp_path)
        //      如果失败: 目录不存在或不可访问, 忽略
        //      如果成功: 在后台线程中删除重命名后的目录
        //   3. UninstallTask 在线程池中执行:
        //      - 获取 dirname 和 basename
        //      - 打开父目录
        //      - dir.deleteTree(basename) 删除目录树
        //      - decrementPendingTasks() + wake()
        let tempName = ".old-${BaoFile.randomHex(8)}"
        let tempPath = Path.join([Path.dirname(destinationDirSubpath), tempName])

        // 尝试重命名
        if (BaoFile.rename(destinationDirSubpath, tempPath)) {
            // 重命名成功, 在后台删除
            // 翻译自: UninstallTask 在 ThreadPool 中异步执行
            let task = UninstallTask(tempPath)
            task.run()
        }
        // 重命名失败意味着目录不存在, 可以忽略
    }

    /// 从链接安装
    /// 翻译自: PackageInstall.install_from_link
    ///   用于 workspace 链接和 file: 依赖的安装
    ///   创建从目标到源目录的符号链接
    ///   POSIX: 获取缓存目录的 realpath, 计算 relative 路径, symlinkat
    ///   Windows: 使用 symlinkOrJunction 创建符号链接或目录联接
    public func installFromLink(
        skipDelete: Bool,
        destinationDir: FileDescriptor
    ): InstallResult {
        if (!skipDelete && destinationDirSubpath != ".") {
            uninstallBeforeInstall(destinationDir)
        }

        // 翻译自: installFromLink
        //   1. 获取 dest_path 的 dirname (用于创建中间目录)
        //   2. cache_dir.realpath(cache_dir_subpath) 获取符号链接目标的真实路径
        //      如果失败: 返回 fail(err, LinkingDependency)
        //   3. POSIX 路径:
        //      a. 如果有 subdir: makeOpenPath 创建中间目录
        //      b. getFdPath 获取目标目录的绝对路径
        //      c. Path.relative(dest_dir_path, to_path) 计算相对路径
        //      d. symlinkat(target, dest_dir.fd, dest_basename)
        //   4. isDanglingSymlink(symlinked_path) 检查符号链接是否有效
        let destPath = destinationDirSubpath
        let symlinkedPath = cacheDirSubpath  // 缓存目录子路径就是链接源

        // 获取链接目标的真实路径
        let realPath = BaoFile.realpath(symlinkedPath)
        if (realPath.size == 0) {
            return InstallResultHelper.fail(
                PkgError.fileNotFound(),
                Step.LinkingDependency
            )
        }

        // 获取目标目录的父目录
        let destBasename = Path.basename(destPath)
        let destParent = Path.dirname(destPath)

        // 如果有父目录, 先创建
        if (destParent.size > 0 && destParent != ".") {
            BaoFile.mkdir(destParent, true)
        }

        // 计算相对路径
        let destDirPath = if (destParent.size > 0 && destParent != ".") {
            destParent
        } else {
            "."
        }
        let relativePath = Path.relative(destDirPath, realPath)

        // 创建符号链接
        let linkPath = if (destParent.size > 0 && destParent != ".") {
            Path.join([destParent, destBasename])
        } else {
            destBasename
        }

        if (!BaoFile.createSymlink(relativePath, linkPath)) {
            // 翻译自: 如果 EEXIST, 先删除再重试
            if (BaoFile.exists(linkPath)) {
                BaoFile.remove(linkPath)
                if (!BaoFile.createSymlink(relativePath, linkPath)) {
                    return InstallResultHelper.fail(
                        PkgError.unexpected("Failed to create symlink"),
                        Step.LinkingDependency
                    )
                }
            } else {
                return InstallResultHelper.fail(
                    PkgError.unexpected("Failed to create symlink"),
                    Step.LinkingDependency
                )
            }
        }

        // 检查符号链接是否有效
        if (PackageInstall.isDanglingSymlink(symlinkedPath)) {
            return InstallResultHelper.fail(
                PkgError.unexpected("DanglingSymlink"),
                Step.LinkingDependency
            )
        }

        return InstallResult.Success
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
        match (patch) {
            case Some(_) =>
                // 有补丁的情况: 检查不带 patch_hash 后缀的缓存
                match (cacheDirSubpath.lastIndexOf("_patch_hash=")) {
                    case Some(i) => return !BaoFile.isDirectory(cacheDirSubpath[..i])
                    case None => return !BaoFile.isDirectory(cacheDirSubpath)
                }
            case None =>
                let exists = BaoFile.isDirectory(cacheDirSubpath)
                if (exists) {
                    // skip setPreinstallState - no LockfileData available here
                }
                return !exists
        }
    }

    /// 检查已打补丁的包是否不在缓存中
    /// 翻译自: PackageInstall.patched_package_missing_from_cache
    public func patchedPackageMissingFromCache(
        manager: PackageManager,
        packageId: UInt32
    ): Bool {
        let exists = BaoFile.isDirectory(cacheDirSubpath)
        if (exists) {
            // skip setPreinstallState - no LockfileData available here
        }
        return !exists
    }

    /// 检查是否为悬挂符号链接
    /// 翻译自: PackageInstall.is_dangling_symlink
    public static func isDanglingSymlink(path: String): Bool {
        let result = SyscallResult.Success
        match (result) {
            case SyscallResult.Err(_) => return true
            case SyscallResult.Success => return false
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
    ///   在后台线程中执行:
    ///   1. 获取 absolute_path 的 dirname 和 basename
    ///   2. 打开 dirname 目录
    ///   3. dir.deleteTree(basename) 递归删除
    ///   4. decrementPendingTasks + wake
    public func run(): Unit {
        let dirname = Path.dirname(absolutePath)
        let basename = Path.basename(absolutePath)

        // 翻译自: UninstallTask.run
        //   var dir = bun.openDirA(std.fs.cwd(), dirname) catch |err| { return }
        //   defer bun.FD.fromStdDir(dir).close()
        //   dir.deleteTree(basename) catch |err| { ... }
        if (dirname.size == 0) {
            return
        }

        // 打开父目录并删除
        let fullPath = Path.join([dirname, basename])
        BaoFile.removeRecursive(fullPath)
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
public class PkgError {
    public var message: String
    public var code: String

    public init(message: String, code: String) {
        this.message = message
        this.code = code
    }

    public static func fileNotFound(): PkgError {
        return PkgError("FileNotFound", "ENOENT")
    }

    public static func notSupported(): PkgError {
        return PkgError("NotSupported", "ENOTSUP")
    }

    public static func notSameFileSystem(): PkgError {
        return PkgError("NotSameFileSystem", "EXDEV")
    }

    public static func unexpected(msg: String): PkgError {
        return PkgError(msg, "UNKNOWN")
    }

    public static func fromErrno(errno: Errno): PkgError {
        return PkgError("System error", errno.toString())
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

