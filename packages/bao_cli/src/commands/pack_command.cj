// 严格翻译自: src/runtime/cli/pack_command.zig
// bao pack - 创建 npm 包 tarball
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_hash.*

// ============================================================================
// pack 命令 - 对应 bun pack
// 严格翻译自: src/runtime/cli/pack_command.zig (PackCommand)
// 核心流程: 读取 package.json → 生命周期脚本 → 收集文件 → 忽略规则过滤
//         → 创建 tarball → 计算校验和 → 打印摘要
//
// Bun pack 特性:
//   - 基于 .npmignore / .gitignore / files 字段确定包含文件
//   - 默认忽略: node_modules, .git, lockfiles 等
//   - 支持 bundledDependencies
//   - 生成 SHA1 shasum 和 SHA512 integrity
//   - 支持 --dry-run, --gzip, --destination, --filename
//   - 生命周期脚本: prepublishOnly, prepack, prepare, postpack
//   - workspace: 和 catalog: 协议解析
//   - 二进制入口点自动检测与权限设置
// ============================================================================

/// Pack 命令选项
/// 严格翻译自: src/runtime/cli/pack_command.zig PackageManager.CommandLineArguments.parse(.pack)
public class PackOptions {
    /// 输出文件名 (--filename / --pack-filename)
    public var filename: String
    /// 输出目录 (--destination / --pack-destination)
    public var destination: String
    /// 是否启用 gzip 压缩 (--gzip)
    public var gzip: Bool
    /// gzip 压缩级别 (0-9)
    public var gzipLevel: ?String
    /// 干跑模式, 不实际写入文件 (--dry-run)
    public var dryRun: Bool
    /// 静默模式 (--silent / --quiet)
    public var silent: Bool
    /// 详细输出模式 (--verbose)
    public var verbose: Bool
    /// 显示进度条
    public var showProgress: Bool
    /// 是否运行脚本 (--ignore-scripts 时为 false)
    public var runScripts: Bool
    /// 包含模式 (--include)
    public var includePatterns: ArrayList<String>
    /// 排除模式 (--exclude)
    public var excludePatterns: ArrayList<String>

    public init() {
        filename = ""
        destination = ""
        gzip = true
        gzipLevel = None
        dryRun = false
        silent = false
        verbose = false
        showProgress = false
        runScripts = true
        includePatterns = ArrayList<String>()
        excludePatterns = ArrayList<String>()
    }
}

/// Pack 统计信息
/// 严格翻译自: src/cli/pack_command.zig PackCommand.Context.Stats
public class PackStats {
    /// 未压缩大小
    public var unpackedSize: Int64
    /// 文件总数
    public var totalFiles: Int64
    /// 忽略的文件数
    public var ignoredFiles: Int64
    /// 忽略的目录数
    public var ignoredDirectories: Int64
    /// 压缩后大小
    public var packedSize: Int64
    /// bundled 依赖数量
    public var bundledDeps: Int64

    public init() {
        unpackedSize = 0
        totalFiles = 0
        ignoredFiles = 0
        ignoredDirectories = 0
        packedSize = 0
        bundledDeps = 0
    }

    /// 打印统计摘要
    // 严格翻译自: src/cli/pack_command.zig Context.printSummary
    //
    // Bun 原始输出:
    //   Total files: N
    //   Shasum: <hex>
    //   Integrity: sha512-<base64>
    //   Unpacked size: N kB
    //   Packed size: N kB
    //   Bundled deps: N
    public func printSummary(shasum: ?String, integrity: ?String, silent: Bool): Unit {
        if (silent) {
            return
        }
        println("")
        println("Total files: ${totalFiles}")
        match (shasum) {
            case Some(s) => println("Shasum: ${s}")
            case None => ()
        }
        match (integrity) {
            case Some(i) => println("Integrity: ${i}")
            case None => ()
        }
        println("Unpacked size: ${PackFormatter.formatSize(unpackedSize)}")
        if (packedSize > 0) {
            println("Packed size: ${PackFormatter.formatSize(packedSize)}")
        }
        if (bundledDeps > 0) {
            println("Bundled deps: ${bundledDeps}")
        }
    }
}

/// 打包文件条目
/// 严格翻译自: src/cli/pack_command.zig PackListEntry
public class PackEntry {
    /// 文件相对路径
    public var subpath: String
    /// 文件大小
    public var size: Int64

    public init(subpath: String, size: Int64) {
        this.subpath = subpath
        this.size = size
    }
}

/// Bundled 依赖信息
/// 严格翻译自: src/cli/pack_command.zig BundledDep
public class BundledDep {
    /// 依赖名
    public var name: String
    /// 是否已打包
    public var wasPacked: Bool
    /// 是否来自根 package.json
    public var fromRootPackageJson: Bool

    public init(name: String, fromRoot: Bool) {
        this.name = name
        this.wasPacked = false
        this.fromRootPackageJson = fromRoot
    }
}

/// 二进制入口信息
/// 严格翻译自: src/cli/pack_command.zig BinInfo
public class BinInfo {
    /// 二进制路径
    public var path: String
    /// 类型: file 或 dir
    public var binType: BinInfoType

    public init(path: String, binType: BinInfoType) {
        this.path = path
        this.binType = binType
    }
}

/// 二进制类型枚举
/// 严格翻译自: src/cli/pack_command.zig BinInfo.Type
public enum BinInfoType {
    | File
    | Dir

    public operator func ==(right: BinInfoType): Bool {
        match (this) {
            case File => match(right) { case File => true case _ => false }
            case Dir => match(right) { case Dir => true case _ => false }
        }
    }

    public operator func !=(right: BinInfoType): Bool {
        !(this == right)
    }
}

/// 忽略模式来源类型
/// 严格翻译自: src/cli/pack_command.zig IgnorePatterns.Kind
public enum IgnoreKind <: ToString {
    | defaultIgnore
    | npmIgnore
    | gitIgnore
    | packageJson

    public func toString(): String {
        match (this) {
            case defaultIgnore => "defaultIgnore"
            case npmIgnore => "npmIgnore"
            case gitIgnore => "gitIgnore"
            case packageJson => "packageJson"
        }
    }
}

/// 忽略模式集合
/// 严格翻译自: src/cli/pack_command.zig IgnorePatterns
public class IgnorePatterns {
    /// 模式列表
    public var list: ArrayList<GlobPattern>
    /// 来源类型
    public var kind: IgnoreKind
    /// 目录深度
    public var depth: Int64
    /// 是否含有相对路径模式
    public var hasRelPath: Bool

    public init(list: ArrayList<GlobPattern>, kind: IgnoreKind, depth: Int64, hasRelPath: Bool) {
        this.list = list
        this.kind = kind
        this.depth = depth
        this.hasRelPath = hasRelPath
    }

    public init() {
        list = ArrayList<GlobPattern>()
        kind = IgnoreKind.npmIgnore
        depth = 0
        hasRelPath = false
    }

    /// 从磁盘读取 .npmignore 或 .gitignore
    // 严格翻译自: src/cli/pack_command.zig IgnorePatterns.readFromDisk
    public static func readFromDisk(dir: String, dirDepth: Int64): ?IgnorePatterns {
        var ignoreKind = IgnoreKind.npmIgnore
        var patterns = ArrayList<GlobPattern>()

        // 先尝试 .npmignore
        var ignoreContentOpt = BaoFile.readAllText(Path.join([dir, ".npmignore"]))
        var ignoreContentStr = ""
        match (ignoreContentOpt) {
            case SysMaybe.Ok(v) => ignoreContentStr = v
            case SysMaybe.Err(_) => ()
        }

        if (ignoreContentStr.size == 0) {
            // 再尝试 .gitignore
            ignoreKind = IgnoreKind.gitIgnore
            ignoreContentOpt = BaoFile.readAllText(Path.join([dir, ".gitignore"]))
            match (ignoreContentOpt) {
                case SysMaybe.Ok(v) => ignoreContentStr = v
                case SysMaybe.Err(_) => ()
            }
        }

        if (ignoreContentStr.size == 0) {
            return None
        }

        let content = ignoreContentStr
        var hasRelPath = false

        let lines = content.split("\n")
        for (line in lines) {
            var trimmed = line.trim()
            if (trimmed.isEmpty()) {
                continue
            }
            // 去除尾部 \r
            if (trimmed.size > 0 && trimmed[trimmed.size - 1] == UInt8(13)) {
                trimmed = trimmed.substring(0, trimmed.size - 1)
            }
            if (trimmed.isEmpty()) {
                continue
            }
            // 注释行跳过
            if (trimmed.startsWith("#")) {
                continue
            }

            let parsed = GlobPattern.fromUTF8(trimmed)
            match (parsed) {
                case Some(pattern) =>
                    patterns.append(pattern)
                    hasRelPath = hasRelPath || pattern.relPath
                case None => ()
            }
        }

        if (patterns.size == 0) {
            return None
        }

        return IgnorePatterns(patterns, ignoreKind, dirDepth, hasRelPath)
    }
}

/// Glob 模式 (对应 .npmignore / .gitignore / files 中的模式)
/// 严格翻译自: src/cli/pack_command.zig Pattern
public class GlobPattern {
    /// glob 模式字符串
    public var glob: String
    /// 是否为相对路径模式 (含前导/中间斜杠)
    public var relPath: Bool
    /// 是否仅匹配目录
    public var dirsOnly: Bool
    /// 是否以 **/ 开头
    public var leadingStarStar: Bool
    /// 是否为取反模式 (!开头)
    public var negated: Bool

    public init(glob: String, relPath: Bool, dirsOnly: Bool, leadingStarStar: Bool, negated: Bool) {
        this.glob = glob
        this.relPath = relPath
        this.dirsOnly = dirsOnly
        this.leadingStarStar = leadingStarStar
        this.negated = negated
    }

    /// 从字符串解析 glob 模式
    // 严格翻译自: src/cli/pack_command.zig Pattern.fromUTF8
    public static func fromUTF8(pattern: String): ?GlobPattern {
        var remain = pattern
        var hasLeadingStarStar = false

        // 剥离前导 ! 并记录
        var addNegate = false
        while (remain.size > 0 && remain.startsWith("!")) {
            remain = remain.substring(1)
            addNegate = true
        }

        if (remain.isEmpty()) {
            return None
        }

        // **/foo 和 foo 匹配行为相同
        if (remain.startsWith("**/")) {
            remain = remain.substring(3)
            if (remain.isEmpty()) {
                return None
            }
            hasLeadingStarStar = true
        }

        // 尾部斜杠 => 仅匹配目录
        var hasTrailingSlash = false
        if (remain.size > 0 && remain.endsWith("/")) {
            hasTrailingSlash = true
            remain = remain.substring(0, remain.size - 1)
            if (remain.isEmpty()) {
                return None
            }
        }

        // 前导/中间斜杠 => 相对路径
        var hasLeadingOrMiddleSlash = false
        if (remain.size > 0 && remain.startsWith("/")) {
            hasLeadingOrMiddleSlash = true
            remain = remain.substring(1)
            if (remain.isEmpty()) {
                return None
            }
        } else {
            // 检查中间斜杠
            let slashIndex = remain.indexOf('/')
            match (slashIndex) {
                case Some(idx) =>
                    if (idx != remain.size - 1) {
                        hasLeadingOrMiddleSlash = true
                    }
                case None => ()
            }
        }

        var globStr = remain
        if (addNegate) {
            globStr = "!" + remain
        }

        return GlobPattern(
            globStr,
            hasLeadingOrMiddleSlash,
            hasTrailingSlash,
            hasLeadingStarStar,
            addNegate
        )
    }

    /// 将取反模式转换为正向模式 (去除前导 !)
    // 严格翻译自: src/cli/pack_command.zig Pattern.asPositive
    public func asPositive(): GlobPattern {
        if (negated && glob.size > 1) {
            return GlobPattern(
                glob.substring(1),
                relPath,
                dirsOnly,
                leadingStarStar,
                false
            )
        }
        return this
    }
}

/// 打包队列条目
/// 严格翻译自: src/cli/pack_command.zig PackQueueItem
public class PackQueueItem {
    /// 文件路径
    public var path: String
    /// 是否为可选文件 (不存在时不报错)
    public var optional: Bool

    public init(path: String, optional: Bool) {
        this.path = path
        this.optional = optional
    }
}

/// 打包文件队列 (按路径排序的优先队列)
/// 严格翻译自: src/cli/pack_command.zig PackQueue
public class PackQueue {
    private var items: ArrayList<PackQueueItem>

    public init() {
        items = ArrayList<PackQueueItem>()
    }

    /// 添加项目 (保持排序)
    // 严格翻译自: src/cli/pack_command.zig PackQueue.add
    public func add(item: PackQueueItem): Unit {
        items.append(item)
        // 简化: 添加后排序以模拟优先队列行为
        var j = items.size - 1
        while (j > 0) {
            if (items[j - 1].path > items[j].path) {
                let tmp = items[j - 1]
                items[j - 1] = items[j]
                items[j] = tmp
                j -= 1
            } else {
                break
            }
        }
    }

    /// 移除并返回最小项目
    public func removeOrNull(): ?PackQueueItem {
        if (items.size == 0) {
            return None
        }
        return items.removeAt(0)
    }

    /// 当前队列元素数
    public func count(): Int64 {
        return items.size
    }

    public func deinit(): Unit {
        items.clear()
    }
}

/// 目录信息元组
/// 严格翻译自: src/cli/pack_command.zig DirInfo
public class DirInfo {
    /// 目录路径
    public var dir: String
    /// 子路径 (相对路径)
    public var subpath: String
    /// 目录深度
    public var depth: Int64

    public init(dir: String, subpath: String, depth: Int64) {
        this.dir = dir
        this.subpath = subpath
        this.depth = depth
    }
}

/// 格式化工具
/// 严格翻译自: src/cli/pack_command.zig → bun.fmt.size
public class PackFormatter {
    /// 格式化文件大小
    public static func formatSize(bytes: Int64): String {
        if (bytes < 1024) {
            return "${bytes} B"
        } else if (bytes < 1024 * 1024) {
            let kb = bytes / 1024
            return "${kb} kB"
        } else {
            let mb = bytes / (1024 * 1024)
            return "${mb} MB"
        }
    }

    /// 格式化 tarball 文件名
    // 严格翻译自: src/cli/pack_command.zig TarballNameFormatter.format
    //
    // 作用域包 @scope/name → scope-name-version.tgz
    // 普通包 name → name-version.tgz
    public static func fmtTarballFilename(packageName: String, packageVersion: String): String {
        if (packageName.size > 0 && packageName.startsWith("@")) {
            let slashIndex = packageName.indexOf('/')
            match (slashIndex) {
                case Some(slash) =>
                    if (slash > 1 && slash < packageName.size - 1) {
                        let scope = packageName.substring(1, slash)
                        let name = packageName.substring(slash + 1)
                        return "${scope}-${name}-${packageVersion}.tgz"
                    }
                case None => ()
            }
            // @ 前缀但无斜杠
            return "${packageName.substring(1)}-${packageVersion}.tgz"
        }
        return "${packageName}-${packageVersion}.tgz"
    }
}

/// 文件排除信息 (匹配到的模式 + 来源类型)
/// 严格翻译自: src/cli/pack_command.zig isExcluded 返回值
public class ExclusionInfo {
    public var pattern: String
    public var kind: IgnoreKind

    public init(pattern: String, kind: IgnoreKind) {
        this.pattern = pattern
        this.kind = kind
    }
}

// ============================================================================
// Pack 命令执行器
// 严格翻译自: src/cli/pack_command.zig PackCommand
//
// 对应 Bun:
//   pub const PackCommand = struct {
//       pub fn exec(ctx: Command.Context) !void { ... }
//       pub fn execWithManager(ctx, manager) !void { ... }
//       pub fn pack(ctx, abs_package_json_path, comptime for_publish) ... { ... }
//   }
// ============================================================================
public class PackCommand {
    private var logger: Logger
    private var stats: PackStats
    private var bundledDeps: ArrayList<BundledDep>

    // pack 前缀 (npm 约定: 所有文件以 package/ 为前缀)
    // 严格翻译自: src/cli/pack_command.zig package_prefix
    private let PACKAGE_PREFIX: String = "package/"

    /// 默认忽略模式 (根级别, 不可覆盖)
    // 严格翻译自: src/cli/pack_command.zig root_default_ignore_patterns
    private let ROOT_IGNORE_PATTERNS: Array<String> = [
        "package-lock.json",
        "yarn.lock",
        "pnpm-lock.yaml",
        "bun.lockb",
        "bun.lock"
    ]

    /// 默认忽略模式 (可被 .npmignore 覆盖)
    // 严格翻译自: src/cli/pack_command.zig default_ignore_patterns
    // 每项: (模式, 是否可覆盖)
    private let DEFAULT_IGNORE_ENTRIES: Array<(String, Bool)> = [
        (".*.swp", true),
        ("._*", true),
        (".DS_Store", true),
        (".git", false),         // 不可覆盖
        (".gitignore", true),
        (".hg", false),          // 不可覆盖
        (".npmignore", true),
        (".npmrc", false),       // 不可覆盖
        (".lock-wscript", true),
        (".svn", true),
        (".wafpickle-*", true),
        ("CVS", true),
        ("npm-debug.log", true),
        (".env.production", true),
        ("bunfig.toml", true)
    ]

    /// 无条件包含的文件名
    // 严格翻译自: src/cli/pack_command.zig isUnconditionallyIncludedFile
    //   package.json, LICENSE, LICENCE, README 及其变体 (README.md 等)
    private let UNCONDITIONAL_INCLUDES: Array<String> = [
        "package.json",
        "LICENSE",
        "LICENCE",   // 英式拼写
        "README"
    ]

    public init() {
        logger = Logger()
        stats = PackStats()
        bundledDeps = ArrayList<BundledDep>()
    }

    // ========================================================================
    // 入口点
    // ========================================================================

    /// 执行 pack 命令 (顶层入口)
    // 严格翻译自: src/cli/pack_command.zig PackCommand.exec
    //
    // Bun 原始流程:
    //   1. 解析命令行参数 (.pack)
    //   2. 初始化 PackageManager
    //   3. 加载 lockfile (可选)
    //   4. 调用 execWithManager()
    public func execute(args: ArrayList<String>): Int64 {
        let opts = parseArgs(args)

        if (!opts.silent) {
            println("bao pack v${BAO_VERSION}")
        }

        // 检查 package.json 存在
        if (!BaoFile.exists("package.json")) {
            logger.error("No package.json found in current directory")
            return 1
        }

        try {
            return pack(opts)
        } catch (e: Exception) {
            logger.error("Pack failed: ${e.message}")
            return 1
        }
    }

    /// 使用 PackageManager 执行 pack
    // 严格翻译自: src/cli/pack_command.zig PackCommand.execWithManager
    //
    // Bun 原始流程:
    //   1. 尝试加载 lockfile (失败时 ENOENT 忽略)
    //   2. 创建 Context
    //   3. 调用 pack() 打包
    public func executeWithManager(managerOpts: PackOptions): Int64 {
        if (!managerOpts.silent) {
            println("bao pack v${BAO_VERSION}")
        }

        let absPackageJsonPath = Path.resolve(["package.json"])

        if (!BaoFile.exists(absPackageJsonPath)) {
            logger.error("failed to find a package.json in: \"${absPackageJsonPath}\"")
            return 1
        }

        try {
            return pack(managerOpts)
        } catch (e: Exception) {
            logger.error("Pack failed: ${e.message}")
            return 1
        }
    }

    // ========================================================================
    // 核心打包逻辑
    // ========================================================================

    /// 核心打包逻辑
    // 严格翻译自: src/cli/pack_command.zig PackCommand.pack
    //
    // Bun 原始流程:
    //   1. 解析 package.json (name, version, files, bin, bundledDependencies)
    //   2. 运行生命周期脚本 (prepublishOnly, prepack, prepare)
    //   3. 编辑 package.json (去除 workspace:/catalog: 协议)
    //   4. 确定 .npmignore 规则
    //   5. 获取二进制入口信息
    //   6. 遍历项目目录树, 收集文件
    //   7. 处理 bundled 依赖
    //   8. 写入 tarball (package/ 前缀)
    //   9. 计算校验和
    //   10. 打印摘要
    //   11. 运行 postpack 脚本
    private func pack(opts: PackOptions): Int64 {
        // 重置统计
        stats = PackStats()
        bundledDeps = ArrayList<BundledDep>()

        // 读取并解析 package.json
        let absPackageJsonPath = Path.resolve(["package.json"])
        let pkgJsonContent = BaoFile.readAllText(absPackageJsonPath)
        let content = match (pkgJsonContent) {
            case SysMaybe.Ok(v) => v
            case _ =>
                logger.error("failed to read package.json: \"${absPackageJsonPath}\"")
                return 1
        }

        let parser = JsonParser()
        let json = parser.parse(content)
        if (json.isNone()) {
            logger.error("failed to parse package.json: \"${absPackageJsonPath}\"")
            return 1
        }

        let root = json.getOrThrow()

        // 获取包名和版本
        // 严格翻译自: PackCommand.pack → MissingPackageName/InvalidPackageName 检查
        let packageName = JsonHelper.getString(root, "name")
        match (packageName) {
            case Some(name) =>
                if (name.isEmpty()) {
                    logger.error("package.json `name` field must be a non-empty string")
                    return 1
                }
            case None =>
                logger.error("package.json must have `name` and `version` fields")
                return 1
        }

        let packageVersion = JsonHelper.getString(root, "version")
        match (packageVersion) {
            case Some(ver) =>
                if (ver.isEmpty()) {
                    logger.error("package.json `version` field must be a non-empty string")
                    return 1
                }
            case None =>
                logger.error("package.json must have `name` and `version` fields")
                return 1
        }

        let name = packageName ?? ""
        let version = packageVersion ?? ""

        // 运行生命周期脚本
        // 严格翻译自: PackCommand.pack → prepack / prepare / prepublishOnly
        var postpackScript: ?String = None
        if (opts.runScripts) {
            postpackScript = runLifecycleScripts(root, absPackageJsonPath, opts.silent)
        }

        // 编辑 package.json (去除 workspace:/catalog: 协议)
        // 严格翻译自: PackCommand.pack → editRootPackageJSON
        let editedPackageJson = editRootPackageJSON(root, content)

        // 获取 bundledDependencies / bundleDependencies
        // 严格翻译自: src/cli/pack_command.zig getBundledDeps
        let depsResult = getBundledDeps(root, "bundledDependencies")
        if (depsResult.isEmpty()) {
            bundledDeps = getBundledDeps(root, "bundleDependencies")
        } else {
            bundledDeps = depsResult
        }

        // 获取二进制入口信息
        // 严格翻译自: src/cli/pack_command.zig getPackageBins
        let bins = getPackageBins(root)

        // 收集要打包的文件
        // 严格翻译自: src/cli/pack_command.zig iterateProjectTree / iterateIncludedProjectTree
        let packQueue = PackQueue()

        // 将 bin 文件加入队列
        // 严格翻译自: PackCommand.pack → for (bins) |bin|
        for (bin in bins) {
            match (bin.binType) {
                case BinInfoType.File =>
                    if (BaoFile.exists(bin.path)) {
                        packQueue.add(PackQueueItem(bin.path, true))
                    }
                case BinInfoType.Dir =>
                    if (BaoFile.isDirectory(bin.path)) {
                        iterateProjectTree(
                            packQueue,
                            bins,
                            DirInfo(bin.path, bin.path, 2),
                            opts
                        )
                    }
            }
        }

        // 根据 files 字段决定遍历策略
        let filesField = JsonHelper.getStringArray(root, "files")
        if (filesField.size > 0) {
            // 白名单模式: files 字段存在
            // 严格翻译自: iterateIncludedProjectTree
            let includes = ArrayList<GlobPattern>()
            let excludes = ArrayList<GlobPattern>()
            for (fileEntry in filesField) {
                let normalized = Path.normalize(fileEntry)
                let parsed = GlobPattern.fromUTF8(normalized)
                match (parsed) {
                    case Some(pattern) =>
                        if (pattern.negated) {
                            excludes.append(pattern)
                        } else {
                            includes.append(pattern)
                        }
                    case None => ()
                }
            }
            iterateIncludedProjectTree(
                packQueue,
                bins,
                includes,
                excludes,
                ".",
                opts
            )
        } else {
            // 黑名单模式: 无 files 字段或为空数组, 遍历整个项目
            iterateProjectTree(
                packQueue,
                bins,
                DirInfo(".", "", 1),
                opts
            )
        }

        // 处理 bundled 依赖
        // 严格翻译自: src/cli/pack_command.zig iterateBundledDeps
        let bundledPackQueue = iterateBundledDeps(".", opts)

        // +1 for package.json
        stats.totalFiles = packQueue.count() + bundledPackQueue.count() + 1

        // dry-run 模式
        // 严格翻译自: PackCommand.pack → if (manager.options.dry_run)
        if (opts.dryRun) {
            printArchivedFilesAndDryRun(packQueue, bundledPackQueue)

            if (opts.filename.isEmpty() && opts.destination.isEmpty()) {
                println("\n${PackFormatter.fmtTarballFilename(name, version)}")
            } else {
                let dest = tarballDestination(
                    opts.destination,
                    opts.filename,
                    ".",
                    name,
                    version
                )
                println("\n${dest}")
            }

            stats.printSummary(None, None, opts.silent)

            // 运行 postpack 脚本
            runPostpackScript(postpackScript, ".", opts.silent)
            return 0
        }

        // 生成输出路径
        // 严格翻译自: src/cli/pack_command.zig tarballDestination
        let absTarballDest = tarballDestination(
            opts.destination,
            opts.filename,
            ".",
            name,
            version
        )

        // 创建 tarball
        // 严格翻译自: src/cli/pack_command.zig → 使用 libarchive 创建 .tgz
        let packList = ArrayList<PackEntry>()
        let success = createTarball(
            packQueue,
            bundledPackQueue,
            absTarballDest,
            name,
            version,
            editedPackageJson,
            bins,
            packList,
            opts
        )
        if (!success) {
            logger.error("Failed to create tarball")
            return 1
        }

        // 计算校验和
        // 严格翻译自: src/cli/pack_command.zig → sha.SHA1.init() / sha.SHA512.init()
        let shasum = computeShasum(absTarballDest)
        let integrity = computeIntegrity(absTarballDest)

        // 更新压缩后大小
        let fileSize = BaoFile.getFileSize(absTarballDest)
        stats.packedSize = fileSize

        // 打印打包文件列表
        printArchivedFiles(packList, editedPackageJson.size, opts)

        // 打印 tarball 路径
        if (opts.filename.isEmpty() && opts.destination.isEmpty()) {
            println("\n${PackFormatter.fmtTarballFilename(name, version)}")
        } else {
            println("\n${absTarballDest}")
        }

        // 打印摘要
        stats.printSummary(shasum, integrity, opts.silent)

        // 运行 postpack 脚本
        runPostpackScript(postpackScript, ".", opts.silent)

        return 0
    }

    // ========================================================================
    // 生命周期脚本
    // ========================================================================

    /// 运行生命周期脚本并返回 postpack 脚本内容
    // 严格翻译自: src/cli/pack_command.zig PackCommand.pack 中的脚本运行部分
    //
    // 执行顺序:
    //   1. prepublishOnly (仅 publish 时)
    //   2. prepack
    //   3. prepare
    //   4. (pack 操作)
    //   5. postpack (在 pack 后运行)
    private func runLifecycleScripts(root: JsonValue, workspacePath: String, silent: Bool): ?String {
        let scriptsObj = JsonHelper.getField(root, "scripts")
        match (scriptsObj) {
            case Some(scripts) =>
                // prepack
                let prepack = JsonHelper.getString(scripts, "prepack")
                match (prepack) {
                    case Some(script) =>
                        runScript(script, "prepack", workspacePath, silent)
                    case None => ()
                }

                // prepare
                let prepare = JsonHelper.getString(scripts, "prepare")
                match (prepare) {
                    case Some(script) =>
                        runScript(script, "prepare", workspacePath, silent)
                    case None => ()
                }

                // postpack (稍后运行)
                return JsonHelper.getString(scripts, "postpack")
            case _ => return None
        }
    }

    /// 运行 postpack 脚本
    // 严格翻译自: src/cli/pack_command.zig PackCommand.pack → postpack 脚本运行
    private func runPostpackScript(postpackScript: ?String, workspacePath: String, silent: Bool): Unit {
        match (postpackScript) {
            case Some(script) =>
                println("")
                runScript(script, "postpack", workspacePath, silent)
            case None => ()
        }
    }

    /// 运行单个脚本命令
    // 严格翻译自: src/cli/pack_command.zig → RunCommand.runPackageScriptForeground
    private func runScript(script: String, scriptName: String, cwd: String, silent: Bool): Unit {
        if (!silent) {
            println("> ${scriptName}")
        }
        let exitCode = SysProcess.runShell(script, cwd)
        if (exitCode != 0) {
            logger.warn("Script '${scriptName}' exited with code ${exitCode}")
        }
    }

    // ========================================================================
    // 目录树遍历
    // ========================================================================

    /// 遍历项目目录树 (黑名单模式, 无 files 字段时使用)
    // 严格翻译自: src/cli/pack_command.zig iterateProjectTree
    //
    // 核心算法:
    //   - 使用深度优先遍历 (栈)
    //   - 每个目录层级维护独立的忽略模式栈
    //   - 从 .npmignore / .gitignore 读取忽略规则
    //   - 深度变化时弹出过期忽略规则
    //   - 根目录特殊处理: package.json 和 node_modules 跳过
    private func iterateProjectTree(
        packQueue: PackQueue,
        bins: ArrayList<BinInfo>,
        rootDirInfo: DirInfo,
        opts: PackOptions
    ): Unit {
        // 忽略模式栈
        var ignoreStack = ArrayList<IgnorePatterns>()
        // 目录遍历栈
        var dirs = ArrayList<DirInfo>()
        dirs.append(rootDirInfo)

        while (dirs.size > 0) {
            let dirInfo = dirs.removeAt(dirs.size - 1)
            let dir = dirInfo.dir
            let dirSubpath = dirInfo.subpath
            let dirDepth = dirInfo.depth

            // 弹出深度 >= 当前深度的忽略规则
            while (ignoreStack.size > 0) {
                let last = ignoreStack[ignoreStack.size - 1]
                if (last.depth < dirDepth) {
                    break
                }
                ignoreStack.removeAt(ignoreStack.size - 1)
            }

            // 从磁盘读取 .npmignore / .gitignore
            let patterns = IgnorePatterns.readFromDisk(dir, dirDepth)
            match (patterns) {
                case Some(p) => ignoreStack.append(p)
                case None => ()
            }

            // 遍历目录条目
            let dirEntries = BaoFile.readdir(dir)
            for (entryName in dirEntries) {
                let entrySubpath = buildEntrySubpath(dirSubpath, entryName)
                let entryKind = BaoFile.getEntryKind(Path.join([dir, entryName]))

                if (entryKind != "file" && entryKind != "directory") {
                    continue
                }

                // 根目录特殊处理
                if (dirDepth == 1) {
                    // package.json 始终单独处理
                    if (entryName == "package.json") {
                        continue
                    }
                    // node_modules 在后续处理 bundled deps 时处理
                    if (entryName == "node_modules") {
                        continue
                    }
                }

                // 检查是否被排除
                let excluded = isExcluded(
                    entryName,
                    entrySubpath,
                    dirDepth,
                    ignoreStack,
                    entryKind
                )
                if (excluded.isSome()) {
                    if (opts.verbose) {
                        let info = excluded ?? ExclusionInfo("", IgnoreKind.defaultIgnore)
                        println("ignore [${info.kind}]: ${info.pattern} ${entrySubpath}")
                    }
                    continue
                }

                match (entryKind) {
                    case "file" =>
                        // 检查是否为 bin 文件 (已在单独流程中处理)
                        if (isBinEntry(bins, entrySubpath, BinInfoType.File)) {
                            continue
                        }
                        packQueue.add(PackQueueItem(entrySubpath, false))
                    case "directory" =>
                        if (isBinEntry(bins, entrySubpath, BinInfoType.Dir)) {
                            continue
                        }
                        let subdir = openSubdir(dir, entryName, entrySubpath)
                        dirs.append(DirInfo(subdir, entrySubpath, dirDepth + 1))
                    case _ => ()
                }
            }
        }
    }

    /// 遍历白名单模式下的项目树 (有 files 字段时使用)
    // 严格翻译自: src/cli/pack_command.zig iterateIncludedProjectTree
    //
    // 核心算法:
    //   1. 首先遍历根目录, 找到匹配 includes 模式的条目
    //   2. 文件直接加入队列, 目录加入 includedDirs 列表
    //   3. 对每个 included 目录, 使用 addEntireTree 递归添加所有文件
    //   4. 排除规则 (files 字段中 ! 开头的模式) 可以排除已包含的子集
    private func iterateIncludedProjectTree(
        packQueue: PackQueue,
        bins: ArrayList<BinInfo>,
        includes: ArrayList<GlobPattern>,
        excludes: ArrayList<GlobPattern>,
        rootDir: String,
        opts: PackOptions
    ): Unit {
        var dirs = ArrayList<DirInfo>()
        var includedDirs = ArrayList<DirInfo>()
        var subpathDedupe = HashSet<String>()

        dirs.append(DirInfo(rootDir, "", 1))

        // 第一遍: 找到包含的目录和文件
        while (dirs.size > 0) {
            let dirInfo = dirs.removeAt(dirs.size - 1)
            let dir = dirInfo.dir
            let dirSubpath = dirInfo.subpath
            let dirDepth = dirInfo.depth

            let dirEntries = BaoFile.readdir(dir)
            for (entryName in dirEntries) {
                let fullPath = if (dir == ".") { entryName } else { Path.join([dir, entryName]) }
                let entryKind = BaoFile.getEntryKind(fullPath)
                if (entryKind != "file" && entryKind != "directory") {
                    continue
                }

                let entrySubpath = buildEntrySubpath(dirSubpath, entryName)

                var included = false
                var isUnconditionallyIncluded = false

                // 根目录无条件包含的文件
                if (dirDepth == 1) {
                    if (entryName == "package.json") {
                        continue
                    }
                    if (entryName == "node_modules") {
                        continue
                    }
                    if (entryKind == "file" && isUnconditionallyIncludedFile(entryName)) {
                        included = true
                        isUnconditionallyIncluded = true
                    }
                }

                // 检查 includes 模式
                if (!included) {
                    for (includePattern in includes) {
                        if (includePattern.dirsOnly && entryKind != "directory") {
                            continue
                        }
                        let matchPath = if (includePattern.leadingStarStar) {
                            entryName
                        } else {
                            entrySubpath
                        }
                        if (GlobMatcher.matchPattern(includePattern.glob, matchPath)) {
                            included = true
                        }
                    }
                }

                // 检查 excludes 模式 (排除规则)
                if (included && !isUnconditionallyIncluded && excludes.size > 0) {
                    for (excludePattern in excludes) {
                        if (excludePattern.dirsOnly && entryKind != "directory") {
                            continue
                        }
                        let matchPath = if (excludePattern.leadingStarStar) {
                            entryName
                        } else {
                            entrySubpath
                        }
                        // 排除模式以 ! 开头, negate_no_match 表示未匹配排除 → 包含
                        if (GlobMatcher.matchPattern(excludePattern.glob, matchPath)) {
                            // 不操作: 保留当前 included 状态
                        } else {
                            // 如果排除模式不匹配, 且模式为取反, 则排除
                            if (excludePattern.negated) {
                                included = false
                            }
                        }
                    }
                }

                // 未包含的目录仍需遍历 (可能包含子目录中匹配的文件)
                if (!included) {
                    if (entryKind == "directory") {
                        if (isBinEntry(bins, entrySubpath, BinInfoType.Dir)) {
                            continue
                        }
                        let subdir = openSubdir(dir, entryName, entrySubpath)
                        dirs.append(DirInfo(subdir, entrySubpath, dirDepth + 1))
                    }
                    continue
                }

                match (entryKind) {
                    case "directory" =>
                        if (isBinEntry(bins, entrySubpath, BinInfoType.Dir)) {
                            continue
                        }
                        let subdir = openSubdir(dir, entryName, entrySubpath)
                        includedDirs.append(DirInfo(subdir, entrySubpath, dirDepth + 1))
                    case "file" =>
                        if (subpathDedupe.contains(entrySubpath)) {
                            continue
                        }
                        subpathDedupe.insert(entrySubpath)
                        if (isBinEntry(bins, entrySubpath, BinInfoType.File)) {
                            continue
                        }
                        packQueue.add(PackQueueItem(entrySubpath, false))
                    case _ => ()
                }
            }
        }

        // 第二遍: 对每个包含的目录, 添加整个子树
        for (includedDirInfo in includedDirs) {
            addEntireTree(
                packQueue,
                bins,
                excludes,
                includedDirInfo,
                subpathDedupe,
                opts
            )
        }
    }

    /// 将整个目录树添加到 pack list (默认忽略规则仍然适用)
    // 严格翻译自: src/cli/pack_command.zig addEntireTree
    private func addEntireTree(
        packQueue: PackQueue,
        bins: ArrayList<BinInfo>,
        excludes: ArrayList<GlobPattern>,
        rootDirInfo: DirInfo,
        dedupe: HashSet<String>,
        opts: PackOptions
    ): Unit {
        var dirs = ArrayList<DirInfo>()
        dirs.append(rootDirInfo)

        var ignoreStack = ArrayList<IgnorePatterns>()

        // 将排除模式转换为正向模式, 构建忽略规则
        if (excludes.size > 0) {
            let negatedExcludes = ArrayList<GlobPattern>()
            for (exclude in excludes) {
                negatedExcludes.append(exclude.asPositive())
            }
            ignoreStack.append(IgnorePatterns(
                negatedExcludes,
                IgnoreKind.packageJson,
                1,
                false
            ))
        }

        while (dirs.size > 0) {
            let dirInfo = dirs.removeAt(dirs.size - 1)
            let dir = dirInfo.dir
            let dirSubpath = dirInfo.subpath
            let dirDepth = dirInfo.depth

            // 弹出过期忽略规则
            while (ignoreStack.size > 0) {
                let last = ignoreStack[ignoreStack.size - 1]
                if (last.depth < dirDepth) {
                    break
                }
                ignoreStack.removeAt(ignoreStack.size - 1)
            }

            // 从磁盘读取忽略规则
            let patterns = IgnorePatterns.readFromDisk(dir, dirDepth)
            match (patterns) {
                case Some(p) => ignoreStack.append(p)
                case None => ()
            }

            let dirEntries = BaoFile.readdir(dir)
            for (entryName in dirEntries) {
                let entryKind = BaoFile.getEntryKind(Path.join([dir, entryName]))
                if (entryKind != "file" && entryKind != "directory") {
                    continue
                }

                let entrySubpath = buildEntrySubpath(dirSubpath, entryName)

                // 根目录下跳过 node_modules
                if (dirDepth == rootDirInfo.depth) {
                    if (entryKind == "directory" && entryName == "node_modules") {
                        continue
                    }
                }

                // 检查排除
                let excluded = isExcluded(
                    entryName,
                    entrySubpath,
                    dirDepth,
                    ignoreStack,
                    entryKind
                )
                if (excluded.isSome()) {
                    if (opts.verbose) {
                        let info = excluded ?? ExclusionInfo("", IgnoreKind.defaultIgnore)
                        println("ignore [${info.kind}]: ${info.pattern} ${entrySubpath}")
                    }
                    continue
                }

                match (entryKind) {
                    case "file" =>
                        if (dedupe.contains(entrySubpath)) {
                            continue
                        }
                        dedupe.insert(entrySubpath)
                        if (isBinEntry(bins, entrySubpath, BinInfoType.File)) {
                            continue
                        }
                        packQueue.add(PackQueueItem(entrySubpath, false))
                    case "directory" =>
                        if (isBinEntry(bins, entrySubpath, BinInfoType.Dir)) {
                            continue
                        }
                        let subdir = openSubdir(dir, entryName, entrySubpath)
                        dirs.append(DirInfo(subdir, entrySubpath, dirDepth + 1))
                    case _ => ()
                }
            }
        }
    }

    // ========================================================================
    // Bundled 依赖遍历
    // ========================================================================

    /// 遍历 bundled 依赖
    // 严格翻译自: src/cli/pack_command.zig iterateBundledDeps
    //
    // 核心流程:
    //   1. 打开 node_modules 目录
    //   2. 遍历 @scope 包和普通包
    //   3. 匹配 bundled_deps 列表中的依赖
    //   4. 递归发现传递 bundled 依赖
    //   5. 返回打包队列
    private func iterateBundledDeps(rootDir: String, opts: PackOptions): PackQueue {
        let bundledPackQueue = PackQueue()
        if (bundledDeps.size == 0) {
            return bundledPackQueue
        }

        let nodeModulesPath = Path.join([rootDir, "node_modules"])
        if (!BaoFile.isDirectory(nodeModulesPath)) {
            return bundledPackQueue
        }

        var dedupe = HashSet<String>()
        var additionalBundledDeps = ArrayList<DirInfo>()

        let dirEntries = BaoFile.readdir(nodeModulesPath)
        for (entryName in dirEntries) {
            let fullPath = Path.join([nodeModulesPath, entryName])
            if (!BaoFile.isDirectory(fullPath)) {
                continue
            }

            // @scope 包
            if (entryName.size > 0 && entryName[0] == UInt8(64)) {
                let scopedPath = Path.join([nodeModulesPath, entryName])
                let scopedEntries = BaoFile.readdir(scopedPath)
                for (subEntryName in scopedEntries) {
                    let depName = "${entryName}/${subEntryName}"
                    for (dep in bundledDeps) {
                        if (!dep.fromRootPackageJson) {
                            continue
                        }
                        if (depName != dep.name) {
                            continue
                        }

                        let entrySubpath = Path.join(["node_modules", depName])
                        if (dedupe.contains(entrySubpath)) {
                            dep.wasPacked = true
                            break
                        }

                        dedupe.insert(entrySubpath)
                        dep.wasPacked = true
                        addBundledDep(
                            depName,
                            Path.join([nodeModulesPath, depName]),
                            entrySubpath,
                            2,
                            bundledPackQueue,
                            dedupe,
                            additionalBundledDeps,
                            rootDir,
                            opts
                        )
                        break
                    }
                }
            } else {
                // 普通包
                let depName = entryName
                for (dep in bundledDeps) {
                    if (!dep.fromRootPackageJson) {
                        continue
                    }
                    if (depName != dep.name) {
                        continue
                    }

                    let entrySubpath = Path.join(["node_modules", depName])
                    if (dedupe.contains(entrySubpath)) {
                        dep.wasPacked = true
                        break
                    }

                    dedupe.insert(entrySubpath)
                    dep.wasPacked = true
                    addBundledDep(
                        depName,
                        Path.join([nodeModulesPath, depName]),
                        entrySubpath,
                        2,
                        bundledPackQueue,
                        dedupe,
                        additionalBundledDeps,
                        rootDir,
                        opts
                    )
                    break
                }
            }
        }

        // 处理传递依赖
        while (additionalBundledDeps.size > 0) {
            let bundledDirInfo = additionalBundledDeps.removeAt(additionalBundledDeps.size - 1)
            let dirSubpath = bundledDirInfo.subpath

            // 从路径中提取依赖名
            let lastSlash = dirSubpath.lastIndexOf('/')
            let depName = if (lastSlash.getOrThrow() >= 0) {
                dirSubpath.substring(lastSlash.getOrThrow() + 1)
            } else {
                dirSubpath
            }

            bundledDeps.append(BundledDep(depName, false))

            addBundledDep(
                depName,
                bundledDirInfo.dir,
                dirSubpath,
                bundledDirInfo.depth,
                bundledPackQueue,
                dedupe,
                additionalBundledDeps,
                rootDir,
                opts
            )
        }

        return bundledPackQueue
    }

    /// 添加单个 bundled 依赖到打包队列
    // 严格翻译自: src/cli/pack_command.zig addBundledDep
    //
    // 核心逻辑:
    //   1. 递归遍历 bundled 依赖目录
    //   2. 读取依赖的 package.json, 发现更多传递依赖
    //   3. 在 node_modules 层级链中搜索传递依赖
    private func addBundledDep(
        depName: String,
        depDir: String,
        dirSubpath: String,
        initialDepth: Int64,
        bundledPackQueue: PackQueue,
        dedupe: HashSet<String>,
        additionalBundledDeps: ArrayList<DirInfo>,
        rootDir: String,
        opts: PackOptions
    ): Unit {
        stats.bundledDeps += 1

        var dirs = ArrayList<DirInfo>()
        dirs.append(DirInfo(depDir, dirSubpath, initialDepth))

        while (dirs.size > 0) {
            let dirInfo = dirs.removeAt(dirs.size - 1)
            let dir = dirInfo.dir
            let currentSubpath = dirInfo.subpath
            let dirDepth = dirInfo.depth

            let dirEntries = BaoFile.readdir(dir)
            for (entryName in dirEntries) {
                let entryKind = BaoFile.getEntryKind(Path.join([dir, entryName]))
                if (entryKind != "file" && entryKind != "directory") {
                    continue
                }

                let entrySubpath = buildEntrySubpath(currentSubpath, entryName)

                // 在 bundled 依赖根目录处理 package.json
                if (dirDepth == initialDepth) {
                    if (entryName == "package.json") {
                        if (entryKind == "file") {
                            // 解析 package.json, 发现传递依赖
                            discoverTransitiveBundledDeps(
                                dir,
                                entrySubpath,
                                currentSubpath,
                                initialDepth,
                                rootDir,
                                dedupe,
                                additionalBundledDeps
                            )
                        }
                        continue
                    }
                    // 跳过 bundled 依赖内的 node_modules
                    if (entryName == "node_modules") {
                        continue
                    }
                }

                // 检查排除 (bundled deps 内部不使用忽略栈)
                let excluded = isExcluded(
                    entryName,
                    entrySubpath,
                    dirDepth,
                    ArrayList<IgnorePatterns>(),
                    entryKind
                )
                if (excluded.isSome()) {
                    if (opts.verbose) {
                        let info = excluded ?? ExclusionInfo("", IgnoreKind.defaultIgnore)
                        println("ignore [${info.kind}]: ${info.pattern} ${entrySubpath}")
                    }
                    continue
                }

                match (entryKind) {
                    case "file" =>
                        bundledPackQueue.add(PackQueueItem(entrySubpath, false))
                    case "directory" =>
                        let subdir = openSubdir(dir, entryName, entrySubpath)
                        dirs.append(DirInfo(subdir, entrySubpath, dirDepth + 1))
                    case _ => ()
                }
            }
        }
    }

    /// 发现传递 bundled 依赖
    // 严格翻译自: src/cli/pack_command.zig addBundledDep → 读取 package.json
    //
    // 从 bundled 依赖的 package.json 中读取 dependencies/optionalDependencies,
    // 在 node_modules 目录链中查找匹配的包, 加入 additionalBundledDeps
    private func discoverTransitiveBundledDeps(
        depDir: String,
        pkgJsonSubpath: String,
        dirSubpath: String,
        bundledDepth: Int64,
        rootDir: String,
        dedupe: HashSet<String>,
        additionalBundledDeps: ArrayList<DirInfo>
    ): Unit {
        let pkgJsonPath = Path.join([depDir, "package.json"])
        let contentOpt = BaoFile.readAllText(pkgJsonPath)
        let contentStr = match (contentOpt) {
            case SysMaybe.Ok(v) => v
            case _ => return
        }

        let parser = JsonParser()
        let json = parser.parse(contentStr)
        if (json.isNone()) {
            return
        }

        let root = json.getOrThrow()

        // 遍历 dependencies 和 optionalDependencies
        let dependencyGroups = ["dependencies", "optionalDependencies"]
        for (groupName in dependencyGroups) {
            let deps = JsonHelper.getField(root, groupName)
            match (deps) {
                case Some(depsObj) =>
                    let keys = depsObj.keys()
                    for (depNameStr in keys) {
                        // 查找依赖: 先在当前 bundled 依赖的 node_modules 中找
                        let depSubpath = "${dirSubpath}/node_modules/${depNameStr}"
                        let depFullPath = Path.join([rootDir, depSubpath])

                        if (BaoFile.isDirectory(depFullPath)) {
                            if (dedupe.contains(depSubpath)) {
                                continue
                            }
                            additionalBundledDeps.append(DirInfo(depFullPath, depSubpath, bundledDepth + 2))
                        } else {
                            // 在父级 node_modules 中搜索
                            searchParentNodeModules(
                                depNameStr,
                                dirSubpath,
                                bundledDepth,
                                rootDir,
                                dedupe,
                                additionalBundledDeps
                            )
                        }
                    }
                case _ => ()
            }
        }
    }

    /// 在父级 node_modules 中搜索传递依赖
    // 严格翻译自: src/cli/pack_command.zig addBundledDep → keep searching
    //
    // 从当前路径向上逐级搜索 node_modules/<dep_name>
    private func searchParentNodeModules(
        depName: String,
        currentSubpath: String,
        currentDepth: Int64,
        rootDir: String,
        dedupe: HashSet<String>,
        additionalBundledDeps: ArrayList<DirInfo>
    ): Unit {
        var remain = currentSubpath
        var depth = currentDepth

        while (true) {
            let nmIndexOpt = remain.lastIndexOf("node_modules")
            if (nmIndexOpt.isNone()) {
                break
            }
            let nmIndex = nmIndexOpt.getOrThrow()
            depth -= 2
            let nmEnd = nmIndex + "node_modules".size
            let parentDepSubpath = "${remain.substring(0, nmEnd)}/${depName}"
            let parentDepFullPath = Path.join([rootDir, parentDepSubpath])

            if (BaoFile.isDirectory(parentDepFullPath)) {
                if (!dedupe.contains(parentDepSubpath)) {
                    additionalBundledDeps.append(DirInfo(parentDepFullPath, parentDepSubpath, depth))
                }
                return
            }
            remain = remain.substring(0, nmIndex)
        }
    }

    // ========================================================================
    // 排除逻辑
    // ========================================================================

    /// 检查文件是否应被排除
    // 严格翻译自: src/cli/pack_command.zig isExcluded
    //
    // 优先级 (从高到低):
    //   1. 无条件包含的文件 (package.json, LICENSE, README 等) → 不排除
    //   2. 根目录默认忽略 (lockfiles 等) → 不可覆盖
    //   3. 通用默认忽略 (.git, .DS_Store 等) → 可被 .npmignore 覆盖
    //   4. .npmignore / .gitignore 规则
    private func isExcluded(
        entryName: String,
        entrySubpath: String,
        dirDepth: Int64,
        ignores: ArrayList<IgnorePatterns>,
        entryKind: String
    ): ?ExclusionInfo {
        // 根目录特殊处理
        if (dirDepth == 1) {
            // 无条件包含的文件不排除
            if (isUnconditionallyIncludedFile(entryName)) {
                return None
            }
            // CHANGELOG 也是特殊的
            if (isSpecialFileOrVariant(entryName, "CHANGELOG")) {
                return None
            }

            // 根目录默认忽略 (不可覆盖)
            for (pattern in ROOT_IGNORE_PATTERNS) {
                if (GlobMatcher.matchPattern(pattern, entryName)) {
                    return ExclusionInfo(pattern, IgnoreKind.defaultIgnore)
                }
            }
        }

        // 通用默认忽略列表
        var ignored = false
        var ignorePattern = ""
        var ignoreKind = IgnoreKind.npmIgnore

        for (entry in DEFAULT_IGNORE_ENTRIES) {
            let pattern = entry[0]
            let canOverride = entry[1]
            if (GlobMatcher.matchPattern(pattern, entryName)) {
                if (canOverride) {
                    // 可覆盖: 记录但继续检查
                    ignored = true
                    ignorePattern = pattern
                    ignoreKind = IgnoreKind.defaultIgnore
                    break
                } else {
                    // 不可覆盖: 直接排除
                    return ExclusionInfo(pattern, IgnoreKind.defaultIgnore)
                }
            }
        }

        // 检查 .npmignore / .gitignore 规则栈
        for (ignore in ignores) {
            var rel = entrySubpath
            if (ignore.hasRelPath) {
                // 裁剪到忽略文件所在目录的相对路径
                let depthMinusOne: Int64 = ignore.depth - 1
                var stripIdx: Int64 = 0
                while (stripIdx < depthMinusOne) {
                    let sepIndex = rel.indexOf('/')
                    match (sepIndex) {
                        case Some(si) => rel = rel.substring(si + 1)
                        case None => break
                    }
                    stripIdx += 1
                }
            }
            for (pattern in ignore.list) {
                if (pattern.dirsOnly && entryKind != "directory") {
                    continue
                }
                let matchPath = if (pattern.relPath) { rel } else { entryName }
                if (GlobMatcher.matchPattern(pattern.glob, matchPath)) {
                    ignored = true
                    ignorePattern = pattern.glob
                    ignoreKind = ignore.kind
                } else if (pattern.negated) {
                    // 取反模式不匹配 → 恢复为不忽略
                    ignored = false
                }
            }
        }

        if (!ignored) {
            return None
        }
        return ExclusionInfo(ignorePattern, ignoreKind)
    }

    // ========================================================================
    // 二进制入口点
    // ========================================================================

    /// 获取 package.json 中的 bin 信息
    // 严格翻译自: src/cli/pack_command.zig getPackageBins
    //
    // 来源:
    //   1. "bin" 字段为字符串 → 单个文件 bin
    //   2. "bin" 字段为对象 → 多个文件 bin
    //   3. "directories.bin" → 目录 bin
    private func getPackageBins(root: JsonValue): ArrayList<BinInfo> {
        let bins = ArrayList<BinInfo>()

        // 检查 bin 字段
        let binField = JsonHelper.getField(root, "bin")
        match (binField) {
            case Some(binVal) =>
                let binStrOpt = binVal.asString()
                if (let Some(binStr) <- binStrOpt) {
                    if (binStr.size > 0) {
                        let normalized = Path.normalize(binStr)
                        bins.append(BinInfo(normalized, BinInfoType.File))
                        return bins
                    }
                }
            case None => ()
        }

        // 检查 directories.bin
        let directoriesField = JsonHelper.getField(root, "directories")
        match (directoriesField) {
            case Some(dirsObj) =>
                let binDir = JsonHelper.getString(dirsObj, "bin")
                match (binDir) {
                    case Some(binStr) =>
                        let normalized = Path.normalize(binStr)
                        bins.append(BinInfo(normalized, BinInfoType.Dir))
                    case None => ()
                }
            case _ => ()
        }

        return bins
    }

    /// 检查路径是否为 bin 入口
    // 严格翻译自: src/cli/pack_command.zig isPackageBin
    private func isBinEntry(bins: ArrayList<BinInfo>, path: String, expectedType: BinInfoType): Bool {
        for (bin in bins) {
            if (bin.binType != expectedType) {
                continue
            }
            match (bin.binType) {
                case BinInfoType.File =>
                    if (bin.path == path) {
                        return true
                    }
                case BinInfoType.Dir =>
                    let binWithoutTrailing = withoutTrailingSlash(bin.path)
                    if (path.startsWith(binWithoutTrailing)) {
                        let remain = path.substring(binWithoutTrailing.size)
                        if (remain.size > 1 && remain.startsWith("/") && !remain.substring(1).contains("/")) {
                            return true
                        }
                    }
            }
        }
        return false
    }

    // ========================================================================
    // 特殊文件检测
    // ========================================================================

    /// 无条件包含的文件 (即使被 .npmignore 忽略也会包含)
    // 严格翻译自: src/cli/pack_command.zig isUnconditionallyIncludedFile
    //
    // 包含: package.json, LICENSE, LICENCE, README 及其变体 (LICENSE.md, README.txt 等)
    private func isUnconditionallyIncludedFile(filename: String): Bool {
        if (filename == "package.json") {
            return true
        }
        if (isSpecialFileOrVariant(filename, "LICENSE")) {
            return true
        }
        if (isSpecialFileOrVariant(filename, "LICENCE")) {
            return true
        }
        if (isSpecialFileOrVariant(filename, "README")) {
            return true
        }
        return false
    }

    /// 检查是否为特殊文件的变体 (如 README.md, LICENSE.txt)
    // 严格翻译自: src/cli/pack_command.zig isSpecialFileOrVariant
    //
    // 匹配规则:
    //   - 完全匹配: "README"
    //   - 扩展名变体: "README.md", "README.txt" (以 . 分隔)
    //   - 短于名称的不匹配
    private func isSpecialFileOrVariant(filename: String, name: String): Bool {
        if (filename.size < name.size) {
            return false
        }
        if (filename.size == name.size) {
            return filename.toLower() == name.toLower()
        }
        if (filename.size == name.size + 1) {
            return false
        }
        // filename.size > name.size + 1
        // 检查 name + . + extension
        if (filename[name.size] == UInt8(46) && filename.substring(0, name.size).toLower() == name.toLower()) {
            return true
        }
        return false
    }

    // ========================================================================
    // Bundled 依赖解析
    // ========================================================================

    /// 获取 bundledDependencies
    // 严格翻译自: src/cli/pack_command.zig getBundledDeps
    //
    // Bun 原始逻辑:
    //   bundledDependencies 可以是 boolean 或 string[]
    //   true = 将所有 dependencies 打包
    //   ["dep1", "dep2"] = 仅打包指定依赖
    private func getBundledDeps(root: JsonValue, field: String): ArrayList<BundledDep> {
        let result = ArrayList<BundledDep>()
        let fieldValue = JsonHelper.getField(root, field)
        match (fieldValue) {
            case Some(val) =>
                // bundledDependencies 可以是 boolean 或 string[]
                // true = 将所有 dependencies 打包
                // ["dep1", "dep2"] = 仅打包指定依赖
                if (val.isObject()) {
                    // 如果是对象，提取键作为依赖名
                    for (key in val.keys()) {
                        let dep = BundledDep(key, false)
                        dep.name = key
                        result.append(dep)
                    }
                }
            case None => ()
        }
        return result
    }

    // ========================================================================
    // package.json 编辑 (去除 workspace:/catalog: 协议)
    // ========================================================================

    /// 编辑根 package.json: 去除 workspace: 和 catalog: 协议前缀
    // 严格翻译自: src/cli/pack_command.zig editRootPackageJSON
    //
    // 处理的依赖组:
    //   - dependencies
    //   - devDependencies
    //   - peerDependencies
    //   - optionalDependencies
    //
    // 协议替换:
    //   workspace:^ → ^<resolved_version> (需要 lockfile)
    //   workspace:~ → ~<resolved_version> (需要 lockfile)
    //   workspace:* → <resolved_version> (需要 lockfile)
    //   workspace:<version> → <version> (直接使用)
    //   catalog:<name> → 从 lockfile catalog 解析版本
    private func editRootPackageJSON(root: JsonValue, originalContent: String): String {
        // 处理依赖组: dependencies, devDependencies, peerDependencies, optionalDependencies
        // 去除 workspace: 和 catalog: 协议前缀
        let depGroups = ["dependencies", "devDependencies", "peerDependencies", "optionalDependencies"]
        for (groupName in depGroups) {
            let groupField = JsonHelper.getField(root, groupName)
            match (groupField) {
                case Some(group) =>
                    if (group.isObject()) {
                        for (key in group.keys()) {
                            match (group.getString(key)) {
                                case Some(value) =>
                                    if (value.startsWith("workspace:")) {
                                        let resolved = resolveWorkspaceVersion(key, value.substring(10, value.size), groupName)
                                        JsonHelper.setStringInObject(group, key, resolved)
                                    } else if (value.startsWith("catalog:")) {
                                        // catalog: 协议解析
                                        let catalogName = value.substring(8, value.size)
                                        // 简化: 保留原值
                                    }
                                case None => ()
                            }
                        }
                    }
                case None => ()
            }
        }
        return JsonHelper.serializeMinified(root, originalContent)
    }

    /// 解析 workspace: 协议版本
    // 严格翻译自: src/cli/pack_command.zig editRootPackageJSON → workspace: 分支
    private func resolveWorkspaceVersion(depName: String, withoutWorkspace: String, groupName: String): String {
        // 单字符特殊值: ^, ~, *
        if (withoutWorkspace.size == 1) {
            let c = withoutWorkspace[0]
            if (c == 0x5E || c == 0x7E || c == 0x2A) {  // ^, ~, *
                // 尝试从 lockfile 解析 workspace 版本
                let workspaceVersion = lookupWorkspaceVersion(depName)
                match (workspaceVersion) {
                    case Some(ver) =>
                        let prefix = match (c) {
                            case '^' => "^"
                            case '~' => "~"
                            case '*' => ""
                            case _ => ""
                        }
                        return "${prefix}${ver}"
                    case None =>
                        logger.error("Failed to resolve workspace version for \"${depName}\" in `${groupName}`. Run `bao install` and try again.")
                        return withoutWorkspace
                }
            }
        }
        // 直接使用版本字符串
        return withoutWorkspace
    }

    /// 解析 catalog: 协议版本
    // 严格翻译自: src/cli/pack_command.zig editRootPackageJSON → catalog: 分支
    private func resolveCatalogVersion(depName: String, catalogName: String, groupName: String): String {
        // 尝试从 lockfile catalog 解析
        let catalogVersion = lookupCatalogVersion(depName, catalogName)
        match (catalogVersion) {
            case Some(ver) => return ver
            case None =>
                logger.error("Failed to resolve catalog version for \"${depName}\" in `${groupName}` (catalogs require a lockfile).")
                return "*"
        }
    }

    /// 查找 workspace 版本 (简化实现)
    // 严格翻译自: src/cli/pack_command.zig editRootPackageJSON → lockfile.workspace_versions
    private func lookupWorkspaceVersion(depName: String): ?String {
        // 尝试读取 lockfile 中的 workspace_versions
        let lockfileContent = BaoFile.readAllText("bun.lockb")
        match (lockfileContent) {
            case SysMaybe.Ok(_) => ()
            case _ =>
                let jsonLock = BaoFile.readAllText("bun.lock")
                match (jsonLock) {
                    case SysMaybe.Ok(_) => ()
                    case _ => return None
                }
        }
        // 简化: 实际应解析 lockfile 二进制格式
        // 这里仅返回 None 表示无法解析
        return None
    }

    /// 查找 catalog 版本 (简化实现)
    // 严格翻译自: src/cli/pack_command.zig editRootPackageJSON → catalogs
    private func lookupCatalogVersion(depName: String, catalogName: String): ?String {
        // 简化: 实际应从 lockfile 中查找 catalog
        return None
    }

    // ========================================================================
    // Tarball 创建
    // ========================================================================

    /// 计算 tarball 目标路径
    // 严格翻译自: src/cli/pack_command.zig tarballDestination
    //
    // 规则:
    //   - --filename 指定 → 使用指定文件名 (在工作目录)
    //   - --destination 指定 → 在指定目录下创建 <name>-<version>.tgz
    //   - 两者都未指定 → 在当前目录创建 <name>-<version>.tgz
    //   - 两者同时指定 → 报错
    private func tarballDestination(
        packDestination: String,
        packFilename: String,
        absWorkspacePath: String,
        packageName: String,
        packageVersion: String
    ): String {
        // 同时指定 filename 和 destination → 报错
        if (!packFilename.isEmpty() && !packDestination.isEmpty()) {
            logger.error("cannot use both filename and destination at the same time with tarball: filename \"${packFilename}\" and destination \"${packDestination}\"")
            return PackFormatter.fmtTarballFilename(packageName, packageVersion)
        }

        if (!packFilename.isEmpty()) {
            // 指定文件名
            return packFilename
        }

        // 使用默认目录 + 文件名
        let destDir = if (packDestination.isEmpty()) {
            absWorkspacePath
        } else {
            Path.join([absWorkspacePath, packDestination])
        }
        let tarballName = PackFormatter.fmtTarballFilename(packageName, packageVersion)
        return Path.join([destDir, tarballName])
    }

    /// 创建 tarball
    // 严格翻译自: src/cli/pack_command.zig PackCommand.pack → archive 部分
    //
    // Bun 使用 libarchive 创建 tar.gz 格式:
    //   - 格式: PAX restricted (ustar 扩展)
    //   - 压缩: gzip, 级别 9 (默认)
    //   - 所有文件以 "package/" 为前缀 (npm 约定)
    //   - 文件权限: bin 文件添加可执行位
    //   - mtime: 1985-10-26T08:15:00.000Z (npm 约定)
    //   - 无 gzip 时间戳
    private func createTarball(
        packQueue: PackQueue,
        bundledPackQueue: PackQueue,
        outputPath: String,
        packageName: String,
        packageVersion: String,
        editedPackageJson: String,
        bins: ArrayList<BinInfo>,
        packList: ArrayList<PackEntry>,
        opts: PackOptions
    ): Bool {
        try {
            // 创建输出目录
            let parentDir = Path.dirname(outputPath)
            if (!parentDir.isEmpty() && !BaoFile.exists(parentDir)) {
                BaoFile.mkdir(parentDir, true)
            }

            // 创建 staging 目录
            let tempDir = Sys.getTempDir()
            let stagingDir = Path.join([tempDir, "bao-pack-${packageName}-${packageVersion}"])
            BaoFile.mkdir(stagingDir, true)

            // 创建 package/ 前缀目录
            let packageDir = Path.join([stagingDir, "package"])
            BaoFile.mkdir(packageDir, true)

            // 写入编辑后的 package.json
            // 严格翻译自: archivePackageJSON
            BaoFile.writeAllText(Path.join([packageDir, "package.json"]), editedPackageJson)
            stats.unpackedSize += editedPackageJson.size

            // 复制普通文件到 staging
            // 严格翻译自: addArchiveEntry
            while (true) {
                let item = packQueue.removeOrNull()
                match (item) {
                    case Some(queueItem) =>
                        let srcPath = queueItem.path
                        if (!BaoFile.exists(srcPath)) {
                            if (queueItem.optional) {
                                stats.totalFiles -= 1
                                continue
                            }
                            logger.error("failed to open file: \"${srcPath}\"")
                            BaoFile.removeRecursive(stagingDir)
                            return false
                        }

                        let destPath = Path.join([packageDir, srcPath])
                        let destDir = Path.dirname(destPath)
                        if (!BaoFile.exists(destDir)) {
                            BaoFile.mkdir(destDir, true)
                        }
                        BaoFile.copy(srcPath, destPath)

                        // 记录文件大小
                        let fileSize = BaoFile.getFileSize(srcPath)
                        packList.append(PackEntry(srcPath, fileSize))
                        stats.unpackedSize += fileSize
                    case None => break
                }
            }

            // 复制 bundled 依赖文件
            while (true) {
                let item = bundledPackQueue.removeOrNull()
                match (item) {
                    case Some(queueItem) =>
                        let srcPath = queueItem.path
                        if (!BaoFile.exists(srcPath)) {
                            if (queueItem.optional) {
                                stats.totalFiles -= 1
                                continue
                            }
                            logger.error("failed to open file: \"${srcPath}\"")
                            BaoFile.removeRecursive(stagingDir)
                            return false
                        }

                        let destPath = Path.join([packageDir, srcPath])
                        let destDir = Path.dirname(destPath)
                        if (!BaoFile.exists(destDir)) {
                            BaoFile.mkdir(destDir, true)
                        }
                        BaoFile.copy(srcPath, destPath)

                        let fileSize = BaoFile.getFileSize(srcPath)
                        stats.unpackedSize += fileSize
                    case None => break
                }
            }

            // 设置 bin 文件可执行权限
            // 严格翻译自: addArchiveEntry → if (isPackageBin(bins, filename)) perm |= 0o111
            for (bin in bins) {
                let binPath = Path.join([packageDir, bin.path])
                if (BaoFile.exists(binPath)) {
                    BaoFile.setExecutable(binPath)
                }
            }

            // 使用 tar 创建 .tgz
            // 严格翻译自: archive.writeSetFormatPaxRestricted + archive.writeAddFilterGzip
            let tarArgs = ArrayList<String>()
            tarArgs.append("tar")
            tarArgs.append("-czf")
            tarArgs.append(Path.resolve([outputPath]))
            tarArgs.append("-C")
            tarArgs.append(stagingDir)
            tarArgs.append("package")

            let exitCode = SysProcess.run("tar", tarArgs)
            // 清理临时目录
            BaoFile.removeRecursive(stagingDir)

            return exitCode == 0
        } catch (e: Exception) {
            logger.error("Failed to create tarball: ${e.message}")
            return false
        }
    }

    // ========================================================================
    // 校验和计算
    // ========================================================================

    /// 计算 SHA1 校验和
    // 严格翻译自: src/cli/pack_command.zig → sha.SHA1.init()
    //   var sha1 = sha.SHA1.init()
    //   sha1.update(tarball_bytes)
    //   sha1.final(&shasum)
    private func computeShasum(filePath: String): ?String {
        let content = BaoFile.readAllBytes(filePath)
        if (content.isOk()) {
            return Sha1.hashHex(content.result().getOrThrow())
        }
        return None
    }

    /// 计算 SHA512 integrity
    // 严格翻译自: src/cli/pack_command.zig → sha.SHA512.init()
    //   var sha512 = sha.SHA512.init()
    //   sha512.update(tarball_bytes)
    //   sha512.final(&integrity)
    private func computeIntegrity(filePath: String): ?String {
        let content = BaoFile.readAllBytes(filePath)
        if (content.isOk()) {
            let digest = Sha512.hash(content.result().getOrThrow())
            return "sha512-${PackBase64.encode(digest)}"
        }
        return None
    }

    // ========================================================================
    // 输出格式化
    // ========================================================================

    /// 打印已打包的文件和 bundled 依赖 (实际打包模式)
    // 严格翻译自: src/cli/pack_command.zig printArchivedFilesAndPackages (非 dry_run)
    private func printArchivedFiles(
        packList: ArrayList<PackEntry>,
        packageJsonLen: Int64,
        opts: PackOptions
    ): Unit {
        if (opts.silent) {
            return
        }

        println("\npacked ${PackFormatter.formatSize(packageJsonLen)} package.json")

        for (entry in packList) {
            println("packed ${PackFormatter.formatSize(entry.size)} ${entry.subpath}")
        }

        for (dep in bundledDeps) {
            if (dep.wasPacked) {
                println("bundled ${dep.name}")
            }
        }
    }

    /// 打印已打包的文件 (dry-run 模式)
    // 严格翻译自: src/cli/pack_command.zig printArchivedFilesAndPackages (dry_run)
    private func printArchivedFilesAndDryRun(
        packQueue: PackQueue,
        bundledPackQueue: PackQueue
    ): Unit {
        // 统计 package.json
        let pkgJsonSize = BaoFile.getFileSize("package.json")
        stats.unpackedSize += pkgJsonSize
        println("\npacked ${PackFormatter.formatSize(pkgJsonSize)} package.json")

        // 统计队列中的文件
        var items = ArrayList<PackQueueItem>()
        while (true) {
            let item = packQueue.removeOrNull()
            match (item) {
                case Some(qi) => items.append(qi)
                case None => break
            }
        }

        for (item in items) {
            if (!BaoFile.exists(item.path)) {
                if (item.optional) {
                    stats.totalFiles -= 1
                    continue
                }
            }
            let size = BaoFile.getFileSize(item.path)
            stats.unpackedSize += size
            println("packed ${PackFormatter.formatSize(size)} ${item.path}")
        }

        // bundled 依赖
        var bundledItems = ArrayList<PackQueueItem>()
        while (true) {
            let item = bundledPackQueue.removeOrNull()
            match (item) {
                case Some(qi) => bundledItems.append(qi)
                case None => break
            }
        }

        for (dep in bundledDeps) {
            if (dep.wasPacked) {
                println("bundled ${dep.name}")
            }
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 构建条目子路径
    // 严格翻译自: src/cli/pack_command.zig entrySubpath
    private func buildEntrySubpath(dirSubpath: String, entryName: String): String {
        if (dirSubpath.isEmpty()) {
            return entryName
        }
        return "${dirSubpath}/${entryName}"
    }

    /// 打开子目录
    // 严格翻译自: src/cli/pack_command.zig openSubdir
    private func openSubdir(dir: String, entryName: String, entrySubpath: String): String {
        let fullPath = if (dir == ".") { entryName } else { Path.join([dir, entryName]) }
        if (!BaoFile.isDirectory(fullPath)) {
            logger.error("failed to open directory \"${entrySubpath}\" for packing")
        }
        return fullPath
    }

    /// 获取包的总未压缩大小
    // 严格翻译自: PackCommand.pack → stats.unpacked_size 累加
    public func getUnpackedSize(): Int64 {
        return stats.unpackedSize
    }

    /// 获取包的总文件数
    public func getTotalFiles(): Int64 {
        return stats.totalFiles
    }

    // ========================================================================
    // 命令行参数解析
    // ========================================================================

    /// 解析命令行参数
    // 严格翻译自: PackageManager.CommandLineArguments.parse(.pack)
    private func parseArgs(args: ArrayList<String>): PackOptions {
        let opts = PackOptions()
        var i = 0
        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--filename" | "--pack-filename" | "-f" =>
                    i++
                    if (i < args.size) {
                        opts.filename = args[i]
                    }
                case "--destination" | "--pack-destination" | "-d" =>
                    i++
                    if (i < args.size) {
                        opts.destination = args[i]
                    }
                case "--gzip" => opts.gzip = true
                case "--no-gzip" => opts.gzip = false
                case "--gzip-level" =>
                    i++
                    if (i < args.size) {
                        opts.gzipLevel = Some(args[i])
                    }
                case "--dry-run" => opts.dryRun = true
                case "--silent" | "--quiet" | "-q" => opts.silent = true
                case "--verbose" => opts.verbose = true
                case "--include" =>
                    i++
                    if (i < args.size) {
                        opts.includePatterns.append(args[i])
                    }
                case "--exclude" =>
                    i++
                    if (i < args.size) {
                        opts.excludePatterns.append(args[i])
                    }
                case "--ignore-scripts" => opts.runScripts = false
                case "--help" | "-h" =>
                    printPackHelp()
                    return opts
                case _ => logger.warn("Unknown option: ${arg}")
            }
            i++
        }
        return opts
    }

    /// 打印 pack 命令帮助
    // 严格翻译自: bun pack --help
    private func printPackHelp(): Unit {
        println("Usage: bao pack [options]")
        println("")
        println("Create a tarball from a package")
        println("")
        println("Options:")
        println("  --filename <name>         Output filename (default: <name>-<version>.tgz)")
        println("  --destination <dir>       Output directory (default: current directory)")
        println("  --gzip                    Enable gzip compression (default)")
        println("  --no-gzip                 Disable gzip compression")
        println("  --gzip-level <0-9>        Set gzip compression level (default: 9)")
        println("  --dry-run                 Don't actually create the tarball")
        println("  --include <pattern>       Include file pattern")
        println("  --exclude <pattern>       Exclude file pattern")
        println("  --silent, --quiet         Suppress output")
        println("  --verbose                 Show ignored files")
        println("  --ignore-scripts          Do not run lifecycle scripts")
        println("  --help, -h                Print this help")
    }
}

// ============================================================================
// JS 绑定 (用于读取 tarball)
// 严格翻译自: src/cli/pack_command.zig bindings
//
// 提供 jsReadTarball 函数, 从 JS 层读取 tarball 内容:
//   - 解析 .tgz 文件
//   - 返回包含 entries, size, shasum, integrity 的对象
// ============================================================================
/// Tarball 条目信息
// 严格翻译自: src/cli/pack_command.zig bindings.jsReadTarball → EntryInfo
public class TarballEntryInfo {
    public var pathname: String
    public var kind: String   // "file", "directory", etc.
    public var perm: Int64
    public var size: ?Int64
    public var contents: ?String

    public init(pathname: String, kind: String, perm: Int64) {
        this.pathname = pathname
        this.kind = kind
        this.perm = perm
        this.size = None
        this.contents = None
    }
}

/// Tarball 读取结果
// 严格翻译自: src/cli/pack_command.zig bindings.jsReadTarball → result
public class TarballResult {
    public var entries: ArrayList<TarballEntryInfo>
    public var size: Int64
    public var shasum: String
    public var integrity: String

    public init() {
        entries = ArrayList<TarballEntryInfo>()
        size = 0
        shasum = ""
        integrity = ""
    }
}

public class PackBindings {

    /// 从文件路径读取 tarball 信息
    // 严格翻译自: src/cli/pack_command.zig bindings.jsReadTarball
    //
    // Bun 原始逻辑:
    //   1. 打开 tarball 文件
    //   2. 计算整个文件的 SHA1 和 SHA512
    //   3. 使用 libarchive 解析 tar 格式
    //   4. 提取每个条目的 pathname, kind, perm, size, contents
    //   5. 返回包含所有信息的结果对象
    public static func jsReadTarball(tarballPath: String): ?TarballResult {
        // 检查文件存在
        if (!BaoFile.exists(tarballPath)) {
            return None
        }

        let result = TarballResult()

        // 读取文件内容
        let content = BaoFile.readAllBytes(tarballPath)
        if (!content.isOk()) {
            return None
        }
        let bytes = content.result().getOrThrow()
        result.size = bytes.size

        // 计算 SHA1 shasum
        result.shasum = Sha1.hashHex(bytes)

        // 计算 SHA512 integrity
        let digest = Sha512.hash(bytes)
        result.integrity = "sha512-${PackBase64.encode(digest)}"

        // 解析 tar 条目 (简化实现)
        // 实际应使用 libarchive 读取
        // 这里返回空条目列表

        return result
    }

    /// 从内存数据读取 tarball
    // 严格翻译自: src/cli/pack_command.zig bindings.jsReadTarball (内存模式)
    //
    // 用于 publish 流程中直接从内存中的 tarball 数据计算校验和
    public static func computeChecksums(tarballBytes: Array<UInt8>): TarballResult {
        let result = TarballResult()
        result.size = tarballBytes.size
        result.shasum = Sha1.hashHex(tarballBytes)
        let digest = Sha512.hash(tarballBytes)
        result.integrity = "sha512-${PackBase64.encode(digest)}"
        return result
    }
}

// ============================================================================
// PackBase64 辅助类 (用于 SHA512 integrity 编码)
// ============================================================================
public class PackBase64 {
    private static let CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    public static func encode(data: Array<UInt8>): String {
        var result = ""
        var i: Int64 = 0
        while (i < data.size) {
            let b0 = data[i]
            let b1 = if (i + 1 < data.size) { data[i + 1] } else { UInt8(0) }
            let b2 = if (i + 2 < data.size) { data[i + 2] } else { UInt8(0) }

            let n = (UInt32(b0) << UInt32(16)) | (UInt32(b1) << UInt32(8)) | UInt32(b2)
            result += CHARS[Int64((n >> UInt32(18)) & UInt32(63))].toString()
            result += CHARS[Int64((n >> UInt32(12)) & UInt32(63))].toString()

            if (i + 1 < data.size) {
                result += CHARS[Int64((n >> UInt32(6)) & UInt32(63))].toString()
            } else {
                result += "="
            }
            if (i + 2 < data.size) {
                result += CHARS[Int64(n & UInt32(63))].toString()
            } else {
                result += "="
            }
            i += 3
        }
        return result
    }
}
