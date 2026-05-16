// bao_install - 包管理器目录
// 严格翻译自: src/install/PackageManager/PackageManagerDirectories.rs + .zig
//   PackageManagerDirectories 管理 PackageManager 的缓存目录、临时目录、
//   全局目录等路径操作
package bao_install.package_manager

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_semver.*

// ============================================================================
// 缓存目录
// 严格翻译自: PackageManagerDirectories — cache directory
// ============================================================================

/// 缓存目录信息
/// 翻译自: CacheDir
public class CacheDir {
    public var path: Array<Byte>
    public var isNodeModules: Bool

    public init(path: Array<Byte>, isNodeModules: Bool) {
        this.path = path
        this.isNodeModules = isNodeModules
    }
}

/// 获取缓存目录路径
/// 翻译自: fetch_cache_directory_path
///   pub fn fetchCacheDirPath(env: *DotEnv.Loader, options: ?*const Options) CacheDir
public func fetchCacheDirectoryPath(env: DotEnvLoader, options: ?Options): CacheDir {
    // 1. BUN_INSTALL_CACHE_DIR 环境变量
    match (env.get("BUN_INSTALL_CACHE_DIR")) {
        case Some(dir) => {
            return CacheDir(
                path: FileSystem.instance().abs(dir),
                isNodeModules: false
            )
        }
        case None => {}
    }

    // 2. 选项中的 cache_directory
    match (options) {
        case Some(opts) => {
            if (opts.cacheDirectory.length > 0) {
                return CacheDir(
                    path: FileSystem.instance().abs(opts.cacheDirectory),
                    isNodeModules: false
                )
            }
        }
        case None => {}
    }

    // 3. BUN_INSTALL 环境变量
    match (env.get("BUN_INSTALL")) {
        case Some(dir) => {
            let parts = ArrayList<Array<Byte>>()
            parts.append(dir)
            parts.append("install/")
            parts.append("cache/")
            return CacheDir(
                path: FileSystem.instance().abs(parts),
                isNodeModules: false
            )
        }
        case None => {}
    }

    // 4. XDG_CACHE_HOME 环境变量
    match (env.get("XDG_CACHE_HOME")) {
        case Some(dir) => {
            let parts = ArrayList<Array<Byte>>()
            parts.append(dir)
            parts.append(".bun/")
            parts.append("install/")
            parts.append("cache/")
            return CacheDir(
                path: FileSystem.instance().abs(parts),
                isNodeModules: false
            )
        }
        case None => {}
    }

    // 5. HOME 环境变量
    match (env.get("HOME")) {
        case Some(dir) => {
            let parts = ArrayList<Array<Byte>>()
            parts.append(dir)
            parts.append(".bun/")
            parts.append("install/")
            parts.append("cache/")
            return CacheDir(
                path: FileSystem.instance().abs(parts),
                isNodeModules: false
            )
        }
        case None => {}
    }

    // 6. 回退: node_modules/.bun-cache
    return CacheDir(
        path: FileSystem.instance().abs("node_modules/.bun-cache"),
        isNodeModules: true
    )
}

// ============================================================================
// 临时目录
// 严格翻译自: PackageManagerDirectories — temporary directory
// ============================================================================

/// 临时目录信息
/// 翻译自: TemporaryDirectory
public class TemporaryDirectory {
    public var handle: FileDescriptor
    public var path: Array<Byte>
    public var name: Array<Byte>

    public init(handle: FileDescriptor, path: Array<Byte>, name: Array<Byte>) {
        this.handle = handle
        this.path = path
        this.name = name
    }
}

/// 获取临时目录
/// 翻译自: get_temporary_directory
///   临时目录必须与缓存目录在同一文件系统上, 以支持 rename 操作
public func getTemporaryDirectory(manager: PackageManager): TemporaryDirectory {
    let cacheDirectory = getCacheDirectory(manager)

    // 选择与缓存目录同文件系统的临时目录
    let tempDirName = FileSystem.getdefaultTempDir()

    // 尝试打开临时目录
    var triedDotTmp = false
    let tempDir = bao_sys.Syscall.makeOpenPath(FileDescriptor.cwd(), tempDirName)

    // 验证临时目录可以 rename 到缓存目录
    let tmpname = FileSystem.tmpname("hm")
    let testFile = bao_sys.Syscall.createFileZ(
        tempDir, tmpname, CreateFlags(truncate: true)
    )

    let renameResult = bao_sys.Syscall.renameat(
        tempDir, tmpname, cacheDirectory, tmpname
    )
    match (renameResult) {
        case SyscallResult.Success => {
            // 删除测试文件
            bao_sys.Syscall.unlinkat(cacheDirectory, tmpname)
        }
        case SyscallResult.Err(_) => {
            if (!triedDotTmp) {
                triedDotTmp = true
                // 回退到缓存目录内的 .tmp 子目录
                let fallbackDir = bao_sys.Syscall.makeOpenPath(
                    cacheDirectory, ".tmp"
                )
            }
        }
    }

    // 获取临时目录的绝对路径
    let tempDirPath = bao_sys.Syscall.getFdPath(tempDir)

    return TemporaryDirectory(
        handle: tempDir,
        path: tempDirPath,
        name: tempDirName
    )
}

// ============================================================================
// 缓存目录获取
// 严格翻译自: get_cache_directory
// ============================================================================

/// 获取缓存目录
/// 翻译自: get_cache_directory
///   pub fn getCacheDirectory(this: *PackageManager) std.fs.Dir
public func getCacheDirectory(manager: PackageManager): FileDescriptor {
    match (manager.cacheDirectory) {
        case Some(fd) => return fd
        case None => {
            let fd = ensureCacheDirectory(manager)
            manager.cacheDirectory = fd
            return fd
        }
    }
}

/// 确保缓存目录存在
/// 翻译自: ensureCache_directory
private func ensureCacheDirectory(manager: PackageManager): FileDescriptor {
    // 检查是否启用缓存
    if (manager.options.enable.contains(Enable.CACHE)) {
        let env = manager.envMut()
        let cacheDir = fetchCacheDirectoryPath(env, manager.options)

        // 更新缓存目录路径
        manager.cacheDirectoryPath = cacheDir.path

        let openResult = bao_sys.Syscall.makeOpenPath(
            FileDescriptor.cwd(), cacheDir.path
        )
        match (openResult) {
            case SyscallResult.Success(d) => return d
            case SyscallResult.Err(_) => {
                // 无法打开, 禁用缓存
                manager.options.enable.set(Enable.CACHE, false)
                manager.cacheDirectoryPath = Array<Byte>()
                // 继续尝试回退路径
            }
        }
    }

    // 回退: node_modules/.cache
    manager.cacheDirectoryPath = Path.join(
        FileSystem.instance().topLevelDir(),
        "node_modules", ".cache"
    )

    let result = bao_sys.Syscall.makeOpenPath(
        FileDescriptor.cwd(), "node_modules/.cache"
    )
    match (result) {
        case SyscallResult.Success(d) => return d
        case SyscallResult.Err(err) => {
            Output.prettyErrorln("error: bun is unable to write files: ${err.name()}")
            Global.crash()
        }
    }
}

/// 获取缓存目录和路径
/// 翻译自: get_cache_directory_and_abs_path
public func getCacheDirectoryAndAbsPath(manager: PackageManager): Tuple2<FileDescriptor, Array<Byte>> {
    let cacheDir = getCacheDirectory(manager)
    return Tuple2(cacheDir, manager.cacheDirectoryPath)
}

// ============================================================================
// 全局目录
// 严格翻译自: PackageManagerDirectories — global directories
// ============================================================================

/// 设置全局目录
/// 翻译自: setupGlobalDir
///   pub fn setupGlobalDir(manager: *PackageManager, ctx: *const Command.Context) !void
public func setupGlobalDir(manager: PackageManager, ctx: CommandContext): Result<Unit> {
    manager.options.globalBinDir = Options.openGlobalBinDir(ctx.install)

    let outBuffer = PathBuffer()
    let result = bao_sys.Syscall.getFdPath(manager.options.globalBinDir, outBuffer)
    match (result) {
        case SyscallResult.Success(path) => {
            manager.options.binPath = path
            return Result.Ok(())
        }
        case SyscallResult.Err(err) => {
            return Result.Err(err)
        }
    }
}

/// 获取全局链接目录
/// 翻译自: globalLinkDir
///   pub fn globalLinkDir(this: *PackageManager) std.fs.Dir
public func globalLinkDir(manager: PackageManager): FileDescriptor {
    match (manager.globalLinkDir) {
        case Some(d) => return d
        case None => {}
    }

    // 打开全局目录
    let globalDir = Options.openGlobalDir(manager.options.explicitGlobalDirectory)

    manager.globalDir = globalDir
    let nodeModules = bao_sys.Syscall.makeOpenPath(globalDir, "node_modules")
    manager.globalLinkDir = nodeModules

    // 获取路径
    let pathBuf = PathBuffer()
    let pathResult = bao_sys.Syscall.getFdPath(nodeModules, pathBuf)
    match (pathResult) {
        case SyscallResult.Success(p) => {
            manager.globalLinkDirPath = p
        }
        case _ => {}
    }

    return nodeModules
}

/// 获取全局链接目录路径
/// 翻译自: globalLinkDirPath
public func globalLinkDirPath(manager: PackageManager): Array<Byte> {
    globalLinkDir(manager)
    return manager.globalLinkDirPath
}

// ============================================================================
// 缓存路径构建
// 严格翻译自: PackageManagerDirectories — cached folder name printers
// ============================================================================

/// 缓存版本
/// 翻译自: CacheVersion
public class CacheVersion {
    public static let CURRENT: Int64 = 1
}

/// 生成 Git 缓存文件夹名
/// 翻译自: cachedGitFolderName
///   格式: @G@<resolved>[_patch_hash=<hash>]
public func cachedGitFolderName(
    manager: PackageManager,
    repository: Repository,
    patchHash: ?UInt64
): String {
    let resolved = manager.lockfile.str(repository.resolved)
    var name = "@G@${resolved}"
    match (patchHash) {
        case Some(h) => name = "${name}_patch_hash=${bao_hash.Hex.encodeLower(h)}"
        case None => {}
    }
    return name
}

/// 生成 GitHub 缓存文件夹名
/// 翻译自: cachedGithubFolderName
///   格式: @GH@<resolved>@@@1[_patch_hash=<hash>]
public func cachedGithubFolderName(
    manager: PackageManager,
    repository: Repository,
    patchHash: ?UInt64
): String {
    let resolved = manager.lockfile.str(repository.resolved)
    var name = "@GH@${resolved}@@@${CacheVersion.CURRENT}"
    match (patchHash) {
        case Some(h) => name = "${name}_patch_hash=${bao_hash.Hex.encodeLower(h)}"
        case None => {}
    }
    return name
}

/// 生成 npm 包缓存文件夹名
/// 翻译自: cachedNpmPackageFolderName
///   格式: <name>@<major>.<minor>.<patch>[_patch_hash=<hash>]
public func cachedNpmPackageFolderName(
    manager: PackageManager,
    name: Array<Byte>,
    version: SemVer,
    patchHash: ?UInt64
): String {
    // 检查 scope
    let scope = manager.scopeForPackageName(name)
    var folderName = "${name}@${version.major}.${version.minor}.${version.patch}"
    match (patchHash) {
        case Some(h) => folderName = "${folderName}_patch_hash=${bao_hash.Hex.encodeLower(h)}"
        case None => {}
    }

    // 如果有自定义 scope, 添加 scope 后缀
    if (scope.name.length > 0) {
        let scopeUrl = scope.url
        if (scopeUrl.hostname.length <= 32) {
            folderName = "${folderName}@@${scopeUrl.hostname}@@@${CacheVersion.CURRENT}"
        } else {
            // 长主机名截断
            let short = scopeUrl.hostname.substring(0, 12)
            let hash = bao_hash.Wyhash.hash(0, scopeUrl.href)
            folderName = "${folderName}@@${short}__${bao_hash.Hex.encodeLower(hash)}@@@${CacheVersion.CURRENT}"
        }
        match (patchHash) {
            case Some(h) => folderName = "${folderName}_patch_hash=${bao_hash.Hex.encodeLower(h)}"
            case None => {}
        }
    } else {
        // 默认 scope: 包含缓存版本号
        folderName = "${folderName}@@@${CacheVersion.CURRENT}"
    }

    return folderName
}

/// 生成 tarball 缓存文件夹名
/// 翻译自: cachedTarballFolderName
///   格式: @T@<url_hash>@@@1[_patch_hash=<hash>]
public func cachedTarballFolderName(
    manager: PackageManager,
    url: String,
    patchHash: ?UInt64
): String {
    let urlHash = bao_hash.Wyhash.hash(0, url.toByteArray())
    var name = "@T@${bao_hash.Hex.encodeLower(urlHash)}@@@${CacheVersion.CURRENT}"
    match (patchHash) {
        case Some(h) => name = "${name}_patch_hash=${bao_hash.Hex.encodeLower(h)}"
        case None => {}
    }
    return name
}

/// 检查文件夹是否在缓存中
/// 翻译自: isFolderInCache
public func isFolderInCache(manager: PackageManager, folderPath: String): Bool {
    let cacheDir = getCacheDirectory(manager)
    return bao_sys.Syscall.directoryExistsAt(cacheDir, folderPath)
}

// ============================================================================
// 路径解析
// 严格翻译自: path_for_resolution / path_for_cached_npm_path
// ============================================================================

/// 缓存目录和子路径
/// 翻译自: CacheDirAndSubpath
public class CacheDirAndSubpath {
    public var cacheDir: FileDescriptor
    public var cacheDirSubpath: String

    public init(cacheDir: FileDescriptor, cacheDirSubpath: String) {
        this.cacheDir = cacheDir
        this.cacheDirSubpath = cacheDirSubpath
    }
}

/// 根据解析结果计算缓存目录和子路径
/// 翻译自: computeCacheDirAndSubpath
public func computeCacheDirAndSubpath(
    manager: PackageManager,
    pkgName: Array<Byte>,
    resolution: Resolution,
    folderPathBuf: PathBuffer,
    patchHash: ?UInt64
): CacheDirAndSubpath {
    match (resolution.tag) {
        case ResolutionTag.Npm => {
            let version = resolution.npm.version
            let subpath = cachedNpmPackageFolderName(manager, pkgName, version, patchHash)
            return CacheDirAndSubpath(
                cacheDir: getCacheDirectory(manager),
                cacheDirSubpath: subpath
            )
        }
        case ResolutionTag.Git => {
            let git = resolution.git
            let subpath = cachedGitFolderName(manager, git, patchHash)
            return CacheDirAndSubpath(
                cacheDir: getCacheDirectory(manager),
                cacheDirSubpath: subpath
            )
        }
        case ResolutionTag.Github => {
            let github = resolution.github
            let subpath = cachedGithubFolderName(manager, github, patchHash)
            return CacheDirAndSubpath(
                cacheDir: getCacheDirectory(manager),
                cacheDirSubpath: subpath
            )
        }
        case ResolutionTag.Folder => {
            let buf = manager.lockfile.buffers.stringBytes
            let folder = resolution.folder.slice(buf)
            let subpath = if (folder.length == 0 || folder == ".") {
                "."
            } else {
                folder
            }
            return CacheDirAndSubpath(
                cacheDir: FileDescriptor.cwd(),
                cacheDirSubpath: subpath
            )
        }
        case ResolutionTag.LocalTarball => {
            let tarball = resolution.localTarball
            let subpath = cachedTarballFolderName(manager, tarball, patchHash)
            return CacheDirAndSubpath(
                cacheDir: getCacheDirectory(manager),
                cacheDirSubpath: subpath
            )
        }
        case ResolutionTag.RemoteTarball => {
            let tarball = resolution.remoteTarball
            let subpath = cachedTarballFolderName(manager, tarball, patchHash)
            return CacheDirAndSubpath(
                cacheDir: getCacheDirectory(manager),
                cacheDirSubpath: subpath
            )
        }
        case ResolutionTag.Workspace => {
            let buf = manager.lockfile.buffers.stringBytes
            let folder = resolution.workspace.slice(buf)
            let subpath = if (folder.length == 0 || folder == ".") {
                "."
            } else {
                folder
            }
            return CacheDirAndSubpath(
                cacheDir: FileDescriptor.cwd(),
                cacheDirSubpath: subpath
            )
        }
        case ResolutionTag.Symlink => {
            let directory = globalLinkDir(manager)
            let buf = manager.lockfile.buffers.stringBytes
            let folder = resolution.symlink.slice(buf)

            if (folder.length == 0 || folder == ".") {
                return CacheDirAndSubpath(
                    cacheDir: FileDescriptor.cwd(),
                    cacheDirSubpath: "."
                )
            }

            let globalLinkPath = globalLinkDirPath(manager)
            let subpath = Path.join(globalLinkPath, folder)
            return CacheDirAndSubpath(
                cacheDir: directory,
                cacheDirSubpath: subpath
            )
        }
        case _ => {
            return CacheDirAndSubpath(
                cacheDir: FileDescriptor.cwd(),
                cacheDirSubpath: ""
            )
        }
    }
}

/// 根据 resolution 获取路径
/// 翻译自: pathForResolution
public func pathForResolution(
    manager: PackageManager,
    packageId: UInt32,
    resolution: Resolution,
    buf: PathBuffer
): Result<Array<Byte>> {
    match (resolution.tag) {
        case ResolutionTag.Npm => {
            let npm = resolution.npm
            let packageName = manager.lockfile.packages.itemsName(packageId)
            return pathForCachedNpmPath(manager, buf, packageName, npm.version)
        }
        case _ => {
            return Result.Ok(Array<Byte>())
        }
    }
}

/// 获取 npm 缓存路径
/// 翻译自: pathForCachedNpmPath
public func pathForCachedNpmPath(
    manager: PackageManager,
    buf: PathBuffer,
    packageName: Array<Byte>,
    version: SemVer
): Result<Array<Byte>> {
    let cachePathBuf = PathBuffer()
    let cachePath = cachedNpmPackageFolderName(manager, packageName, version, None)

    let cacheDir = getCacheDirectory(manager)
    let result = bao_sys.Syscall.readlinkat(cacheDir, cachePath, buf)
    match (result) {
        case SyscallResult.Success(n) => {
            return Result.Ok(buf.slice(0, n))
        }
        case SyscallResult.Err(err) => {
            bao_sys.Syscall.unlinkat(cacheDir, cachePath)
            return Result.Err(Error.fromErrno(err.errno))
        }
    }
}

// ============================================================================
// Package.json / Lockfile
// 严格翻译自: attemptToCreatePackageJson / saveLockfile
// ============================================================================

/// 尝试创建 package.json
/// 翻译自: attemptToCreatePackageJson
public func attemptToCreatePackageJson(): Result<Unit> {
    let file = bao_sys.Syscall.createFileZ(
        FileDescriptor.cwd(), "package.json",
        CreateFlags(read: true)
    )
    match (file) {
        case SyscallResult.Success(f) => {
            f.pwriteAll("{\"dependencies\": {}}", 0)
            f.close()
            return Result.Ok(())
        }
        case SyscallResult.Err(err) => {
            Output.prettyErrorln("error: ${err.name()} create package.json")
            Global.crash()
        }
    }
}

/// 保存锁文件
/// 翻译自: saveLockfile
public func saveLockfile(
    manager: PackageManager,
    loadResult: LoadResult,
    saveFormat: LockfileFormat,
    hadAnyDiffs: Bool,
    lockfileBeforeInstall: Lockfile,
    packagesLenBeforeInstall: Int64,
    logLevel: LogLevel
): Result<Unit> {
    if (manager.lockfile.isEmpty()) {
        // 空锁文件, 删除
        if (!manager.options.dryRun) {
            let deleteName = match (loadResult.format) {
                LockfileFormat.Text => "bun.lock"
                LockfileFormat.Binary => "bun.lockb"
            }
            bao_sys.Syscall.unlinkat(FileDescriptor.cwd(), deleteName)
        }

        if (!manager.options.global && logLevel != LogLevel.Silent) {
            match (manager.subcommand) {
                case Subcommand.Remove => {
                    Output.prettyErrorln("package.json has no dependencies! Deleted empty lockfile")
                }
                case _ => {
                    Output.prettyErrorln("No packages! Deleted empty lockfile")
                }
            }
        }
        return Result.Ok(())
    }

    // 显示保存进度
    if (logLevel.showProgress()) {
        Output.prettyErrorln("Saved lockfile")
    }

    // 保存到磁盘
    manager.lockfile.saveToDisk(loadResult, manager.options)

    return Result.Ok(())
}

/// 如需更新锁文件
/// 翻译自: updateLockfileIfNeeded
public func updateLockfileIfNeeded(
    manager: PackageManager,
    loadResult: LoadResult
): Result<Unit> {
    match (loadResult) {
        case LoadResult.Ok(ok) => {
            if (ok.serializerResult.packagesNeedUpdate) {
                let slice = manager.lockfile.packages.slice()
                for (meta in slice.itemsMetaMut()) {
                    meta.setHasInstallScript(false)
                }
            }
        }
        case _ => {}
    }
    return Result.Ok(())
}

/// 写入 yarn.lock
/// 翻译自: writeYarnLock
public func writeYarnLock(manager: PackageManager): Result<Unit> {
    // 创建临时文件
    let tmpName = "tmplock-${bao_hash.Hex.encodeLower(bao_core.Random.bytes(8))}"

    let tmpFile = bao_sys.Syscall.createTempFile(tmpName)
    match (tmpFile) {
        case SyscallResult.Success(f) => {
            // 写入 yarn lock 格式
            let printer = LockfilePrinter(
                lockfile: manager.lockfile,
                options: manager.options,
                successfullyInstalled: None,
                updates: ArrayList<UpdateRequest>()
            )
            let buf = ArrayList<Byte>()
            YarnPrinter.print(printer, buf)
            f.writeAll(buf)

            // 移动到最终位置
            f.promoteToCwd(tmpName, "yarn.lock")
            return Result.Ok(())
        }
        case SyscallResult.Err(err) => {
            Output.prettyErrorln("error: failed to create tmpfile: ${err.name()}")
            Global.crash()
        }
    }
}

// ============================================================================
// 支持类型
// ============================================================================

/// 命令上下文
public class CommandContext {
    public var install: ?BunInstallConfig

    public init(install: ?BunInstallConfig) {
        this.install = install
    }
}

/// 锁文件加载结果
public enum LoadResult {
    | NotFound
    | Err(LoadError)
    | Ok(LoadSuccess)
}

/// 加载错误
public class LoadError {
    public var format: LockfileFormat

    public init(format: LockfileFormat) {
        this.format = format
    }
}

/// 加载成功
public class LoadSuccess {
    public var format: LockfileFormat
    public var serializerResult: SerializerResult

    public init(format: LockfileFormat, serializerResult: SerializerResult) {
        this.format = format
        this.serializerResult = serializerResult
    }
}

/// 序列化器结果
public class SerializerResult {
    public var packagesNeedUpdate: Bool

    public init(packagesNeedUpdate: Bool) {
        this.packagesNeedUpdate = packagesNeedUpdate
    }
}

/// 锁文件格式
public enum LockfileFormat {
    | Text
    | Binary
}

/// 日志级别
public enum LogLevel {
    | Silent
    | Error
    | Warning
    | Info
    | Verbose
}

/// 日志级别扩展
public class LogLevelExt {
    public static func showProgress(level: LogLevel): Bool {
        match (level) {
            case LogLevel.Silent => false
            case _ => true
        }
    }
}

/// 子命令
public enum Subcommand {
    | Install
    | Add
    | Remove
    | Update
    | Link
    | Unlink
}

/// 启用标志
public class Enable {
    public static let CACHE: UInt32 = 1
    public static let MANIFEST_CACHE: UInt32 = 2
    public static let MANIFEST_CACHE_CONTROL: UInt32 = 4

    public var value: UInt32

    public init(value: UInt32) {
        this.value = value
    }

    public func contains(flag: UInt32): Bool {
        return (value & flag) != 0
    }

    public func set(flag: UInt32, on: Bool): Unit {
        if (on) {
            value = value | flag
        } else {
            value = value & ~flag
        }
    }
}

/// 选项 (部分)
public class Options {
    public var cacheDirectory: Array<Byte>
    public var enable: Enable
    public var globalBinDir: FileDescriptor
    public var binPath: Array<Byte>
    public var didOverrideDefaultScope: Bool
    public var dryRun: Bool
    public var global: Bool
    public var scope: NpmRegistryScope
    public var logLevel: LogLevel

    public init() {
        cacheDirectory = Array<Byte>()
        enable = Enable(value: UInt32.MAX)
        globalBinDir = FileDescriptor.invalid()
        binPath = Array<Byte>()
        didOverrideDefaultScope = false
        dryRun = false
        global = false
        scope = NpmRegistryScope()
        logLevel = LogLevel.Info
    }

    public static func openGlobalBinDir(install: ?BunInstallConfig): FileDescriptor {
        // 翻译自: options::open_global_bin_dir
        return FileDescriptor.invalid()
    }

    public static func openGlobalDir(explicitDir: ?String): FileDescriptor {
        return FileDescriptor.invalid()
    }
}

/// NPM 注册表 Scope
public class NpmRegistryScope {
    public var name: String
    public var url: RegistryUrl

    public init(name: String, url: RegistryUrl) {
        this.name = name
        this.url = url
    }

    public init() {
        name = ""
        url = RegistryUrl()
    }

    public static func hash(name: String): UInt64 {
        return bao_hash.Wyhash.hash(0, name.toByteArray())
    }
}

/// 注册表 URL
public class RegistryUrl {
    public var hostname: String
    public var href: String

    public init(hostname: String, href: String) {
        this.hostname = hostname
        this.href = href
    }

    public init() {
        hostname = ""
        href = ""
    }
}

/// 更新请求
public class UpdateRequest {
    public var name: String
    public var version: String

    public init(name: String, version: String) {
        this.name = name
        this.version = version
    }
}

/// 锁文件打印机
public class LockfilePrinter {
    public var lockfile: Lockfile
    public var options: Options
    public var successfullyInstalled: ?DynamicBitSet
    public var updates: ArrayList<UpdateRequest>

    public init(
        lockfile: Lockfile,
        options: Options,
        successfullyInstalled: ?DynamicBitSet,
        updates: ArrayList<UpdateRequest>
    ) {
        this.lockfile = lockfile
        this.options = options
        this.successfullyInstalled = successfullyInstalled
        this.updates = updates
    }
}

/// Yarn 打印器
public class YarnPrinter {
    public static func print(printer: LockfilePrinter, buf: ArrayList<Byte>): Unit {
        // 翻译自: lockfile/printer/Yarn.print
    }
}

/// PathBuffer
public class PathBuffer {
    public var data: Array<Byte>

    public init() {
        data = Array<Byte>(4096, item: 0)
    }
}
