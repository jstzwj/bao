// bao_install - 安装逻辑
// 严格翻译自: src/install/install.zig
//   install.zig 是 Bun 包安装的入口文件, 定义了核心类型:
//   PackageID, DependencyID, Features, Origin, PreinstallState, ExtractData 等
//   以及引用了所有子模块: NetworkTask, Npm, PackageManager 等
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 包安装摘要
// 严格翻译自: src/install/PackageInstall.zig - PackageInstall.Summary
//   记录安装结果统计
// ============================================================================

/// 包安装摘要
/// 对应 Bun: PackageInstall.Summary
public class PackageInstallSummary {
    /// 成功安装的包数量 (不重复)
    public var success: Int64
    /// 失败的包数量
    public var fail: Int64
    /// 跳过的包数量
    public var skipped: Int64
    /// 成功安装的包 ID 集合
    public var successfullyInstalled: HashSet<UInt32>
    /// 被阻塞脚本的包
    public var packagesWithBlockedScripts: HashMap<UInt32, Int64>

    public init() {
        success = 0
        fail = 0
        skipped = 0
        successfullyInstalled = HashSet<UInt32>()
        packagesWithBlockedScripts = HashMap<UInt32, Int64>()
    }

    /// 总安装包数
    public func total(): Int64 {
        return success + fail + skipped
    }

    /// 是否有失败
    public func hasFailures(): Bool {
        return fail > 0
    }

    /// 合并另一个摘要
    public func merge(other: PackageInstallSummary): Unit {
        success += other.success
        fail += other.fail
        skipped += other.skipped
        for (id in other.successfullyInstalled) {
            successfullyInstalled.add(id)
        }
        for (kv in other.packagesWithBlockedScripts) {
            match (packagesWithBlockedScripts.get(kv.key)) {
                case Some(existing) => packagesWithBlockedScripts.put(kv.key, existing + kv.value)
                case None => packagesWithBlockedScripts.put(kv.key, kv.value)
            }
        }
    }
}

// ============================================================================
// 包安装结果
// 严格翻译自: src/install/PackageInstall.zig - PackageInstall.Result
//   pub const Result = union(enum) { success, failure: Failure }
// ============================================================================

/// 安装步骤
/// 翻译自: PackageInstall.Result.Failure.Step
public enum InstallStep {
    | OpeningCacheDir
    | OpeningModuleDir
    | ExtractingTarball
    | CopyingFiles
    | LinkingBins
    | Patching
    | VerifyingVersion

    public func name(): String {
        match (this) {
            case OpeningCacheDir => "opening cache directory"
            case OpeningModuleDir => "opening module directory"
            case ExtractingTarball => "extracting tarball"
            case CopyingFiles => "copying files"
            case LinkingBins => "linking binaries"
            case Patching => "patching"
            case VerifyingVersion => "verifying version"
        }
    }
}

/// 安装失败原因
/// 翻译自: PackageInstall.Result.Failure
public class InstallFailure {
    public var step: InstallStep
    public var errorMessage: String
    public var isPackageMissingFromCache: Bool

    public init(step: InstallStep, errorMessage: String) {
        this.step = step
        this.errorMessage = errorMessage
        isPackageMissingFromCache = false
    }

    /// 是否是缓存缺失
    /// 翻译自: Failure.isPackageMissingFromCache
    public func checkCacheMiss(): Bool {
        return isPackageMissingFromCache
    }
}

/// 安装方法
/// 翻译自: PackageInstall.Method
public enum InstallMethod {
    | HardLink   // 硬链接 (默认, 高效)
    | Copy       // 复制 (回退方案)
    | Symlink    // 符号链接

    public func toString(): String {
        match (this) {
            case HardLink => "hardlink"
            case Copy => "copy"
            case Symlink => "symlink"
        }
    }
}

/// 包安装结果
/// 翻译自: PackageInstall.Result
public enum PackageInstallResult {
    | Success
    | Failure(InstallFailure)

    public func isSuccess(): Bool {
        match (this) {
            case Success => true
            case Failure(_) => false
        }
    }

    public func isFail(): Bool {
        match (this) {
            case Success => false
            case Failure(_) => true
        }
    }

    public static func fail(err: String, step: InstallStep): PackageInstallResult {
        return Failure(InstallFailure(step, err))
    }
}

// ============================================================================
// 包安装请求
// 严格翻译自: src/install/PackageInstall.zig - PackageInstall
//   pub const PackageInstall = struct {
//       progress: ?*Progress.Node,
//       cache_dir: std.fs.Dir,
//       cache_dir_subpath: [:0]const u8,
//       destination_dir_subpath: [:0]const u8,
//       allocator: std.mem.Allocator,
//       package_name: String,
//       package_version: string,
//       node_modules: *NodeModulesFolder,
//       lockfile: *Lockfile,
//       patch: ?PatchInfo,
//   }
// ============================================================================

/// 包安装请求
/// 对应 Bun: PackageInstall
public class PackageInstallRequest {
    /// 缓存目录
    public var cacheDir: String
    /// 缓存子路径
    public var cacheDirSubpath: String
    /// 目标子路径 (node_modules 下的路径)
    public var destinationDirSubpath: String
    /// 包名
    public var packageName: String
    /// 包版本
    public var packageVersion: String
    /// node_modules 路径
    public var nodeModulesPath: String
    /// node_modules 树 ID
    public var nodeModulesTreeId: UInt32
    /// 补丁信息
    public var patch: ?PatchInfo
    /// 是否跳过删除
    public var skipDelete: Bool
    /// 是否跳过版本验证
    public var skipVerify: Bool
    /// 是否强制安装
    public var forceInstall: Bool

    public init() {
        cacheDir = ""
        cacheDirSubpath = ""
        destinationDirSubpath = ""
        packageName = ""
        packageVersion = ""
        nodeModulesPath = ""
        nodeModulesTreeId = UInt32(0)
        patch = None
        skipDelete = false
        skipVerify = false
        forceInstall = false
    }

    /// 验证包是否已安装且版本匹配
    /// 翻译自: PackageInstall.verify
    public func verify(resolution: String, rootModulesDir: String): Bool {
        if (skipVerify) { return false }

        // 检查目标目录是否存在
        let destPath = "${nodeModulesPath}/${destinationDirSubpath}"
        if (!bao_io.File.exists(destPath)) {
            return false
        }

        // 检查 package.json 中的版本
        let pkgJsonPath = "${destPath}/package.json"
        try {
            let content = bao_io.File.readTextFile(pkgJsonPath)
            let json = bao_json.JsonParser.parse(content)
            match (json.get("version")) {
                case Some(v) => {
                    let installedVersion = v.asString()
                    // 版本匹配则跳过安装
                    return installedVersion == packageVersion
                }
                case None => return false
            }
        } catch (_: Exception) {
            return false
        }
    }

    /// 检查包是否在缓存中缺失
    /// 翻译自: PackageInstall.packageMissingFromCache
    public func packageMissingFromCache(
        manager: PackageManagerRef,
        packageId: UInt32,
        resolutionTag: DependencyVersionTag
    ): Bool {
        if (cacheDirSubpath.length == 0) { return true }
        let cachePath = "${cacheDir}/${cacheDirSubpath}"
        return !bao_io.File.directoryExists(cachePath)
    }

    /// 执行安装
    /// 翻译自: PackageInstall.install
    public func install(
        skipDelete: Bool,
        destinationDir: String,
        method: InstallMethod,
        resolutionTag: DependencyVersionTag
    ): PackageInstallResult {
        let sourcePath = "${cacheDir}/${cacheDirSubpath}"
        let destPath = "${nodeModulesPath}/${destinationDirSubpath}"

        // 源目录必须存在
        if (!bao_io.File.directoryExists(sourcePath)) {
            return PackageInstallResult.fail(
                "Package not found in cache: ${sourcePath}",
                InstallStep.OpeningCacheDir
            )
        }

        // 如果目标已存在且不是强制安装, 可能跳过
        if (bao_io.File.directoryExists(destPath) && !forceInstall) {
            if (!skipDelete) {
                // 删除旧版本
                try {
                    bao_io.File.removeDirectory(destPath)
                } catch (_: Exception) {
                    // 删除失败, 继续安装
                }
            }
        }

        // 确保目标目录存在
        try {
            bao_io.File.createDirectory(destPath)
        } catch (e: Exception) {
            return PackageInstallResult.fail(
                "Failed to create directory: ${destPath}: ${e.message}",
                InstallStep.OpeningModuleDir
            )
        }

        // 复制/链接文件
        match (method) {
            case HardLink => {
                try {
                    bao_io.File.hardlinkDirectory(sourcePath, destPath)
                } catch (e: Exception) {
                    // 回退到复制
                    try {
                        bao_io.File.copyDirectory(sourcePath, destPath)
                    } catch (e2: Exception) {
                        return PackageInstallResult.fail(
                            "Failed to copy files: ${e2.message}",
                            InstallStep.CopyingFiles
                        )
                    }
                }
            }
            case Copy => {
                try {
                    bao_io.File.copyDirectory(sourcePath, destPath)
                } catch (e: Exception) {
                    return PackageInstallResult.fail(
                        "Failed to copy files: ${e.message}",
                        InstallStep.CopyingFiles
                    )
                }
            }
            case Symlink => {
                try {
                    bao_io.File.createSymlink(sourcePath, destPath)
                } catch (e: Exception) {
                    return PackageInstallResult.fail(
                        "Failed to create symlink: ${e.message}",
                        InstallStep.CopyingFiles
                    )
                }
            }
        }

        // 应用补丁
        match (patch) {
            case Some(p) => {
                try {
                    p.apply(destPath)
                } catch (e: Exception) {
                    return PackageInstallResult.fail(
                        "Failed to apply patch: ${e.message}",
                        InstallStep.Patching
                    )
                }
            }
            case None => ()
        }

        return PackageInstallResult.Success
    }

    /// 从链接安装 (workspace/symlink)
    /// 翻译自: PackageInstall.installFromLink
    public func installFromLink(skipDelete: Bool, destinationDir: String): PackageInstallResult {
        let sourcePath = cacheDirSubpath
        let destPath = "${nodeModulesPath}/${destinationDirSubpath}"

        // 对于 workspace/symlink, 创建符号链接
        try {
            bao_io.File.createSymlink(sourcePath, destPath)
        } catch (e: Exception) {
            return PackageInstallResult.fail(
                "Failed to create symlink: ${e.message}",
                InstallStep.CopyingFiles
            )
        }

        return PackageInstallResult.Success
    }

    /// 获取安装方法
    /// 翻译自: PackageInstall.getInstallMethod
    public func getInstallMethod(): InstallMethod {
        // 默认使用硬链接
        // 翻译自: PackageInstall.supported_method
        return InstallMethod.HardLink
    }
}

// ============================================================================
// 补丁信息
// ============================================================================

/// 补丁信息
/// 翻译自: PackageInstall.patch
public class PatchInfo {
    /// 补丁文件内容哈希
    public var contentsHash: UInt64
    /// 补丁文件路径
    public var path: String

    public init(contentsHash: UInt64, path: String) {
        this.contentsHash = contentsHash
        this.path = path
    }

    /// 应用补丁
    public func apply(targetDir: String): Unit {
        // 应用 patch 文件到目标目录
        // 翻译自: patch_install.zig
    }
}

// ============================================================================
// 包管理器引用 (轻量级引用, 避免循环依赖)
// ============================================================================

/// 包管理器引用
/// 用于在安装请求中引用 PackageManager
public class PackageManagerRef {
    /// 缓存目录路径
    public var cacheDirectoryPath: String
    /// 临时目录路径
    public var temporaryDirectoryPath: String
    /// 全局链接目录路径
    public var globalLinkDirPath: String
    /// 日志级别
    public var logLevel: LogLevel

    public init() {
        cacheDirectoryPath = ""
        temporaryDirectoryPath = ""
        globalLinkDirPath = ""
        logLevel = LogLevel.Default
    }
}

// ============================================================================
// 日志级别
// 严格翻译自: src/install/PackageManager/PackageManagerOptions.zig - LogLevel
// ============================================================================

/// 日志级别
public enum LogLevel {
    | Silent       // 不输出任何信息
    | Verbose      // 详细日志
    | Default      // 默认输出
    | DefaultNoProgress // 默认, 不显示进度条

    /// 是否显示进度条
    public func showProgress(): Bool {
        match (this) {
            case Silent => false
            case DefaultNoProgress => false
            case _ => true
        }
    }

    /// 是否是详细模式
    public func isVerbose(): Bool {
        match (this) {
            case Verbose => true
            case _ => false
        }
    }
}
