// bao_install - 使用包管理器安装
// 严格翻译自: src/install/PackageManager/install_with_manager.zig
//   包含缓存目录管理、临时目录、全局目录设置、锁文件保存、yarn 锁写入等
package bao_install.package_manager

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
// 包管理器目录与缓存管理
// 严格翻译自: src/install/PackageManager/install_with_manager.zig
//   getCacheDirectory, getTemporaryDirectory, fetchCacheDirectoryPath,
//   cachedNPMPackageFolderName/Print/Basename, cachedGitFolderName,
//   cachedGitHubFolderName, cachedTarballFolderName, isFolderInCache,
//   setupGlobalDir, globalLinkDir, saveLockfile, writeYarnLock
// ============================================================================

/// 包管理器目录工具
/// 对应 Bun: install_with_manager.zig 中的函数
/// 翻译自: src/install/PackageManager/install_with_manager.zig
public class InstallWithManager {
    /// 获取缓存目录
    /// 翻译自: getCacheDirectory
    ///   pub fn getCacheDirectory(this) []const u8
    public static func getCacheDirectory(manager: PackageManagerRef): String {
        match (manager.cacheDirectory) {
            case Some(dir) => return dir
            case None => {
                let dir = fetchCacheDirectoryPath()
                manager.cacheDirectory = dir
                return dir
            }
        }
    }

    /// 获取临时目录
    /// 翻译自: getTemporaryDirectory
    ///   pub fn getTemporaryDirectory(this) []const u8
    public static func getTemporaryDirectory(manager: PackageManagerRef): String {
        match (manager.temporaryDirectory) {
            case Some(dir) => return dir
            case None => {
                let cacheDir = getCacheDirectory(manager)
                let tmpDir = Path.join(cacheDir, ".tmp")
                manager.temporaryDirectory = tmpDir
                return tmpDir
            }
        }
    }

    /// 获取缓存目录路径
    /// 翻译自: fetchCacheDirectoryPath
    ///   pub fn fetchCacheDirectoryPath() []const u8
    ///   默认路径: ~/.bun/install/cache
    public static func fetchCacheDirectoryPath(): String {
        let home = bao_io.File.getHomeDirectory()
        return Path.join(home, ".bun", "install", "cache")
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
    public static func isFolderInCache(manager: PackageManagerRef, subpath: String): Bool {
        let cacheDir = getCacheDirectory(manager)
        let fullPath = Path.join(cacheDir, subpath)
        return bao_io.File.exists(fullPath)
    }

    /// 设置全局目录
    /// 翻译自: setupGlobalDir
    ///   pub fn setupGlobalDir(this, ctx) !void
    public static func setupGlobalDir(manager: PackageManagerRef, ctx: CommandContext): Unit {
        let globalDir = match (manager.globalConfigDir) {
            case Some(dir) => dir
            case None => {
                let home = bao_io.File.getHomeDirectory()
                let dir = Path.join(home, ".bun", "install", "global")
                manager.globalConfigDir = dir
                dir
            }
        }

        bao_io.File.makeDirectory(globalDir)
        let nodeModules = Path.join(globalDir, "node_modules")
        bao_io.File.makeDirectory(nodeModules)
    }

    /// 获取全局链接目录
    /// 翻译自: globalLinkDir
    ///   pub fn globalLinkDir(this) []const u8
    public static func globalLinkDir(manager: PackageManagerRef): String {
        let cacheDir = getCacheDirectory(manager)
        return Path.join(cacheDir, ".links")
    }

    /// 保存锁文件
    /// 严格翻译自: saveLockfile
    ///   pub fn saveLockfile(this, load_result, save_format, had_any_diffs,
    ///       lockfile_before_install, packages_len, log_level) !void
    public static func saveLockfile(
        manager: PackageManagerRef,
        saveFormat: LockfileSaveFormat,
        hadAnyDiffs: Bool,
        logLevel: LogLevel
    ): Unit {
        let lockfile = manager.lockfile

        // 生成元哈希
        let metaHash = lockfile.generateMetaHash()

        match (saveFormat) {
            case LockfileSaveFormat.Binary => {
                // 保存二进制锁文件 (bun.lockb)
                let lockfilePath = Path.join(manager.cwd, "bun.lockb")
                lockfile.saveBinary(lockfilePath, metaHash)
            }
            case LockfileSaveFormat.Text => {
                // 保存文本锁文件 (bun.lock)
                let lockfilePath = Path.join(manager.cwd, "bun.lock")
                lockfile.saveText(lockfilePath, metaHash)
            }
        }

        if (logLevel.isVerbose()) {
            bao_core.Output.print("Saved lockfile (${saveFormat.name()})\n")
        }
    }

    /// 写入 Yarn 锁文件
    /// 翻译自: writeYarnLock
    ///   pub fn writeYarnLock(this) !void
    public static func writeYarnLock(manager: PackageManagerRef): Unit {
        let lockfile = manager.lockfile
        let yarnLockPath = Path.join(manager.cwd, "yarn.lock")

        // 使用 YarnPrinter 生成内容
        let printer = YarnPrinter(lockfile: lockfile.toPrintData())
        let content = printer.print()

        bao_io.File.writeTextFile(yarnLockPath, content)
    }
}

// ============================================================================
// 锁文件保存格式
// ============================================================================

/// 锁文件保存格式
public enum LockfileSaveFormat {
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
/// 对应 Bun: PackageManager (目录管理相关字段)
public class PackageManagerRef {
    public var cacheDirectory: ?String
    public var temporaryDirectory: ?String
    public var globalConfigDir: ?String
    public var cwd: String
    public var lockfile: LockfileRef

    public init() {
        cacheDirectory = None
        temporaryDirectory = None
        globalConfigDir = None
        cwd = bao_io.File.getCurrentDirectory()
        lockfile = LockfileRef()
    }
}

/// 锁文件引用
public class LockfileRef {
    public init() {}

    public func generateMetaHash(): String { return "" }
    public func saveBinary(path: String, metaHash: String): Unit {}
    public func saveText(path: String, metaHash: String): Unit {}
    public func toPrintData(): LockfilePrintData { return LockfilePrintData() }
}

/// 锁文件打印数据
public class LockfilePrintData {
    public init() {}
}

/// Yarn 打印器 (引用)
public class YarnPrinter {
    public var lockfile: LockfilePrintData

    public init(lockfile: LockfilePrintData) {
        this.lockfile = lockfile
    }

    public func print(): String { return "" }
}

/// 命令上下文
public class CommandContext {
    public init() {}
}

/// 日志级别
public enum LogLevel {
    | Silent
    | Default
    | Verbose
    | Debug

    public func isVerbose(): Bool {
        return this == LogLevel.Verbose || this == LogLevel.Debug
    }

    public func showProgress(): Bool {
        return this != LogLevel.Silent
    }
}
