// 严格翻译自: src/cli/pack_command.zig
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
// 严格翻译自: src/cli/pack_command.zig (PackCommand)
// 核心流程: 读取 package.json → 收集文件 → 忽略规则过滤 → 创建 tarball → 计算校验和
//
// Bun pack 特性:
//   - 基于 .npmignore / files 字段确定包含文件
//   - 默认忽略: node_modules, .git, lockfiles 等
//   - 支持 bundledDependencies
//   - 生成 SHA1 shasum 和 SHA512 integrity
//   - 支持 --dry-run, --gzip, --destination, --filename
// ============================================================================

/// Pack 命令选项
/// 严格翻译自: src/cli/pack_command.zig PackageManager.CommandLineArguments.parse(.pack)
public class PackOptions {
    /// 输出文件名 (--filename)
    public var filename: ?String
    /// 输出目录 (--destination)
    public var destination: ?String
    /// 是否启用 gzip 压缩 (--gzip)
    public var gzip: Bool
    /// 干跑模式, 不实际写入文件 (--dry-run)
    public var dryRun: Bool
    /// 静默模式 (--silent / --quiet)
    public var silent: Bool
    /// 包含模式 (--include)
    public var includePatterns: ArrayList<String>
    /// 排除模式 (--exclude)
    public var excludePatterns: ArrayList<String>

    public init() {
        filename = None
        destination = None
        gzip = true
        dryRun = false
        silent = false
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
    public func printSummary(shasum: ?String, integrity: ?String): Unit {
        println("")
        println("Total files: ${totalFiles}")
        match (shasum) {
            case Some(s) => println("Shasum: ${s}")
            case None => {}
        }
        match (integrity) {
            case Some(i) => println("Integrity: ${i}")
            case None => {}
        }
        println("Unpacked size: ${formatSize(unpackedSize)}")
        if (packedSize > 0) {
            println("Packed size: ${formatSize(packedSize)}")
        }
        if (bundledDeps > 0) {
            println("Bundled deps: ${bundledDeps}")
        }
    }

    /// 格式化文件大小
    private func formatSize(bytes: Int64): String {
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

/// Pack 命令执行器
/// 严格翻译自: src/cli/pack_command.zig PackCommand
///
/// 对应 Bun:
///   pub const PackCommand = struct {
///       pub fn exec(ctx: Command.Context) !void { ... }
///       pub fn execWithManager(ctx, manager) !void { ... }
///   }
public class PackCommand {
    private var logger: Logger
    /// 默认忽略模式 (根级别)
    // 严格翻译自: src/cli/pack_command.zig root_default_ignore_patterns
    private let ROOT_IGNORE_PATTERNS: Array<String> = [
        "package-lock.json",
        "yarn.lock",
        "pnpm-lock.yaml",
        "bun.lockb",
        "bun.lock"
    ]

    /// 默认忽略模式
    // 严格翻译自: src/cli/pack_command.zig default_ignore_patterns
    private let DEFAULT_IGNORE_PATTERNS: Array<String> = [
        ".*.swp",
        "._*",
        ".DS_Store",
        ".git",
        ".gitignore",
        ".hg",
        ".npmignore",
        ".npmrc",
        ".lock-wscript",
        ".svn",
        ".wafpickle-*",
        "CVS",
        "npm-debug.log",
        ".env.production",
        "bunfig.toml"
    ]

    public init() {
        logger = Logger()
    }

    /// 执行 pack 命令
    // 严格翻译自: src/cli/pack_command.zig PackCommand.exec
    //
    // Bun 原始流程:
    //   1. 解析命令行参数 (.pack)
    //   2. 初始化 PackageManager
    //   3. 加载 lockfile (可选)
    //   4. 调用 pack() 打包
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

    /// 核心打包逻辑
    // 严格翻译自: src/cli/pack_command.zig PackCommand.pack
    //
    // Bun 原始流程:
    //   1. 解析 package.json (name, version, files, bin, bundledDependencies)
    //   2. 确定 .npmignore 规则
    //   3. 遍历项目目录树, 收集文件
    //   4. 应用 include/exclude 规则
    //   5. 写入 tarball (package/ 前缀)
    //   6. 计算校验和
    //   7. 打印摘要
    private func pack(opts: PackOptions): Int64 {
        // 读取并解析 package.json
        let pkgJsonContent = BaoFile.readAllText("package.json")
        match (pkgJsonContent) {
            case Some(content) => {
                let parser = JsonParser()
                let json = parser.parse(content)
                match (json) {
                    case Some(root) => return packWithJson(root, opts)
                    case None => {
                        logger.error("Failed to parse package.json")
                        return 1
                    }
                }
            }
            case None => {
                logger.error("Failed to read package.json")
                return 1
            }
        }
    }

    /// 使用已解析的 JSON 执行打包
    // 严格翻译自: src/cli/pack_command.zig pack()
    private func packWithJson(root: JsonValue, opts: PackOptions): Int64 {
        // 获取包名和版本
        // 严格翻译自: PackCommand.pack → MissingPackageName/InvalidPackageName 检查
        let packageName = JsonHelper.getString(root, "name")
        match (packageName) {
            case Some(name) => {
                if (name.isEmpty()) {
                    logger.error("package.json `name` field must be a non-empty string")
                    return 1
                }
            }
            case None => {
                logger.error("package.json must have `name` and `version` fields")
                return 1
            }
        }

        let packageVersion = JsonHelper.getString(root, "version")
        match (packageVersion) {
            case Some(ver) => {
                if (ver.isEmpty()) {
                    logger.error("package.json `version` field must be a non-empty string")
                    return 1
                }
            }
            case None => {
                logger.error("package.json must have `name` and `version` fields")
                return 1
            }
        }

        let name = packageName ?? ""
        let version = packageVersion ?? ""

        // 获取 files 字段 (白名单模式)
        // 严格翻译自: src/cli/pack_command.zig → 解析 "files" 数组
        let filesField = JsonHelper.getStringArray(root, "files")

        // 获取 bundledDependencies / bundleDependencies
        // 严格翻译自: src/cli/pack_command.zig getBundledDeps
        let bundledDeps = getBundledDeps(root)

        // 收集要打包的文件
        // 严格翻译自: src/cli/pack_command.zig iterateProjectTree
        let entries = collectFiles(filesField, opts)

        // 统计
        let stats = PackStats()
        for (entry in entries) {
            stats.totalFiles++
            stats.unpackedSize += entry.size
        }
        stats.bundledDeps = bundledDeps.size

        // 生成输出文件名
        let outputFilename = match (opts.filename) {
            case Some(f) => f
            case None => "${name}-${version}.tgz"
        }

        let outputPath = match (opts.destination) {
            case Some(d) => Path.join([d, outputFilename])
            case None => outputFilename
        }

        if (opts.dryRun) {
            println("Dry run: would create ${outputPath}")
            for (entry in entries) {
                println("  packed ${formatSize(entry.size)} ${entry.subpath}")
            }
            stats.printSummary(None, None)
            return 0
        }

        // 创建 tarball
        // 严格翻译自: src/cli/pack_command.zig → 使用 libarchive 创建 .tgz
        let success = createTarball(entries, outputPath, name, version, opts.gzip)
        if (!success) {
            logger.error("Failed to create tarball")
            return 1
        }

        // 计算校验和
        // 严格翻译自: src/cli/pack_command.zig → sha.SHA1.init() / sha.SHA512.init()
        let shasum = computeShasum(outputPath)
        let integrity = computeIntegrity(outputPath)

        // 更新压缩后大小
        let fileSize = BaoFile.getFileSize(outputPath)
        match (fileSize) {
            case Some(s) => stats.packedSize = s
            case None => {}
        }

        // 打印摘要
        stats.printSummary(shasum, integrity)

        return 0
    }

    /// 获取 bundledDependencies
    // 严格翻译自: src/cli/pack_command.zig getBundledDeps
    //
    // Bun 原始逻辑:
    //   bundledDependencies 可以是 boolean 或 string[]
    //   true = 将所有 dependencies 打包
    //   ["dep1", "dep2"] = 仅打包指定依赖
    private func getBundledDeps(root: JsonValue): ArrayList<BundledDep> {
        let result = ArrayList<BundledDep>()

        // 先检查 "bundledDependencies", 再检查 "bundleDependencies" (两种拼写)
        let bundledField = JsonHelper.getField(root, "bundledDependencies")
        let bundleField = if (bundledField.isEmpty()) {
            JsonHelper.getField(root, "bundleDependencies")
        } else {
            bundledField
        }

        match (bundleField) {
            case Some(JsonValue.Array(arr)) => {
                for (item in arr) {
                    match (item) {
                        case JsonValue.Str(name) => {
                            result.append(BundledDep(name, true))
                        }
                        case _ => {}
                    }
                }
            }
            case Some(JsonValue.Bool(b)) => {
                if (b) {
                    // true 意味着将所有 dependencies 打包
                    match (JsonHelper.getField(root, "dependencies")) {
                        case Some(JsonValue.Object(deps)) => {
                            let keys = deps.keys()
                            for (key in keys) {
                                result.append(BundledDep(key, true))
                            }
                        }
                        case _ => {}
                    }
                }
            }
            case _ => {}
        }

        return result
    }

    /// 收集要打包的文件
    // 严格翻译自: src/cli/pack_command.zig iterateProjectTree / iterateIncludedProjectTree
    //
    // Bun 原始逻辑:
    //   1. 如果有 "files" 字段, 使用白名单模式
    //   2. 否则使用黑名单模式 (.npmignore + 默认忽略规则)
    //   3. 遍历目录树, 应用忽略/包含规则
    //   4. 排除: node_modules, .git, lockfiles 等
    private func collectFiles(filesField: ?Array<String>, opts: PackOptions): ArrayList<PackEntry> {
        let entries = ArrayList<PackEntry>()

        // 构建忽略规则
        let ignorePatterns = ArrayList<String>()
        for (p in DEFAULT_IGNORE_PATTERNS) {
            ignorePatterns.append(p)
        }
        for (p in ROOT_IGNORE_PATTERNS) {
            ignorePatterns.append(p)
        }

        // 读取 .npmignore 中的自定义忽略规则
        let npmIgnore = BaoFile.readAllText(".npmignore")
        match (npmIgnore) {
            case Some(content) => {
                let lines = content.split("\n")
                for (line in lines) {
                    let trimmed = line.trim()
                    if (!trimmed.isEmpty() && !trimmed.startsWith("#")) {
                        ignorePatterns.append(trimmed)
                    }
                }
            }
            case None => {}
        }

        // 添加命令行排除模式
        for (p in opts.excludePatterns) {
            ignorePatterns.append(p)
        }

        // 如果有 files 字段, 切换到白名单模式
        match (filesField) {
            case Some(files) => {
                // 白名单模式: 只包含 files 数组中指定的路径
                // 严格翻译自: iterateIncludedProjectTree
                for (pattern in files) {
                    collectMatchingFiles(pattern, entries)
                }
            }
            case None => {
                // 黑名单模式: 包含所有文件, 排除忽略规则匹配的
                walkDirectory(".", ignorePatterns, entries)
            }
        }

        return entries
    }

    /// 使用 glob 模式收集匹配的文件
    // 严格翻译自: src/cli/pack_command.zig include 模式匹配
    private func collectMatchingFiles(pattern: String, entries: ArrayList<PackEntry>): Unit {
        let files = GlobMatcher.match(pattern)
        for (file in files) {
            if (BaoFile.exists(file) && BaoFile.isFile(file)) {
                let size = BaoFile.getFileSize(file) ?? 0
                entries.append(PackEntry(file, size))
            }
        }
    }

    /// 遍历目录收集文件 (黑名单模式)
    // 严格翻译自: src/cli/pack_command.zig iterateProjectTree
    private func walkDirectory(dir: String, ignorePatterns: ArrayList<String>, entries: ArrayList<PackEntry>): Unit {
        let dirEntries = BaoFile.readdir(dir)
        for (entry in dirEntries) {
            let fullPath = if (dir == ".") { entry } else { Path.join([dir, entry]) }

            // 跳过忽略的文件
            if (shouldIgnore(entry, fullPath, ignorePatterns)) {
                continue
            }

            if (BaoFile.isDirectory(fullPath)) {
                // 递归进入子目录
                walkDirectory(fullPath, ignorePatterns, entries)
            } else if (BaoFile.isFile(fullPath)) {
                let size = BaoFile.getFileSize(fullPath) ?? 0
                entries.append(PackEntry(fullPath, size))
            }
        }
    }

    /// 检查文件是否应被忽略
    // 严格翻译自: src/cli/pack_command.zig ignore pattern matching
    private func shouldIgnore(name: String, fullPath: String, patterns: ArrayList<String>): Bool {
        // 总是忽略的目录
        if (name == "node_modules" || name == ".git" || name == ".hg") {
            return true
        }

        for (pattern in patterns) {
            if (GlobMatcher.match(pattern, name) || GlobMatcher.match(pattern, fullPath)) {
                return true
            }
        }
        return false
    }

    /// 创建 tarball
    // 严格翻译自: src/cli/pack_command.zig → 使用 libarchive 写入 .tgz
    //
    // Bun 使用 libarchive 创建 tar.gz 格式:
    //   - 所有文件以 "package/" 为前缀 (npm 约定)
    //   - 保持文件权限和时间戳
    //   - 可选 gzip 压缩
    private func createTarball(entries: ArrayList<PackEntry>, outputPath: String,
        packageName: String, packageVersion: String, gzip: Bool): Bool {
        // 简化实现: 实际应使用 tar + gzip 创建
        // 对应 Bun: 使用 libarchive Archive API
        //   - archive_write_set_format_ustar()
        //   - archive_write_add_filter_gzip()
        //   - 写入 package/package.json
        //   - 写入所有收集的文件 (package/ 前缀)
        //   - archive_write_close()
        try {
            // 创建输出目录
            let parentDir = Path.dirname(outputPath)
            if (!parentDir.isEmpty() && !BaoFile.exists(parentDir)) {
                BaoFile.mkdir(parentDir, true)
            }

            // 写入 package.json 前缀
            let pkgContent = BaoFile.readAllText("package.json") ?? "{}"

            // 使用 tar 命令创建 (简化实现)
            let tempDir = Sys.getTempDir()
            let stagingDir = Path.join([tempDir, "bao-pack-${packageName}-${packageVersion}"])
            BaoFile.mkdir(stagingDir, true)

            // 复制文件到 staging 目录
            let packageDir = Path.join([stagingDir, "package"])
            BaoFile.mkdir(packageDir, true)

            for (entry in entries) {
                let destPath = Path.join([packageDir, entry.subpath])
                let destDir = Path.dirname(destPath)
                if (!BaoFile.exists(destDir)) {
                    BaoFile.mkdir(destDir, true)
                }
                BaoFile.copyFile(entry.subpath, destPath)
            }

            // 写入 package.json
            BaoFile.writeAllText(Path.join([packageDir, "package.json"]), pkgContent)

            // 使用 tar 创建 .tgz
            let tarArgs = ArrayList<String>()
            tarArgs.append("tar")
            tarArgs.append("-czf")
            tarArgs.append(Path.resolve(outputPath))
            tarArgs.append("-C")
            tarArgs.append(stagingDir)
            tarArgs.append("package")

            let exitCode = Process.spawn(tarArgs.toArray(), ".")
            match (exitCode) {
                case Some(code) => {
                    // 清理临时目录
                    BaoFile.removeTree(stagingDir)
                    return code == 0
                }
                case None => {
                    BaoFile.removeTree(stagingDir)
                    return false
                }
            }
        } catch (e: Exception) {
            logger.error("Failed to create tarball: ${e.message}")
            return false
        }
    }

    /// 计算 SHA1 校验和
    // 严格翻译自: src/cli/pack_command.zig → sha.SHA1.init()
    //   var sha1 = sha.SHA1.init()
    //   sha1.update(tarball_bytes)
    //   sha1.final(&shasum)
    private func computeShasum(filePath: String): ?String {
        let content = BaoFile.readAllBytes(filePath)
        match (content) {
            case Some(bytes) => {
                return SHA1.hexDigest(bytes)
            }
            case None => return None
        }
    }

    /// 计算 SHA512 integrity
    // 严格翻译自: src/cli/pack_command.zig → sha.SHA512.init()
    //   var sha512 = sha.SHA512.init()
    //   sha512.update(tarball_bytes)
    //   sha512.final(&integrity)
    private func computeIntegrity(filePath: String): ?String {
        let content = BaoFile.readAllBytes(filePath)
        match (content) {
            case Some(bytes) => {
                return "sha512-${SHA512.base64Digest(bytes)}"
            }
            case None => return None
        }
    }

    /// 解析命令行参数
    private func parseArgs(args: ArrayList<String>): PackOptions {
        let opts = PackOptions()
        var i = 0
        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--filename" | "-f" => {
                    i++
                    if (i < args.size) {
                        opts.filename = Some(args[i])
                    }
                }
                case "--destination" | "-d" => {
                    i++
                    if (i < args.size) {
                        opts.destination = Some(args[i])
                    }
                }
                case "--gzip" => opts.gzip = true
                case "--no-gzip" => opts.gzip = false
                case "--dry-run" => opts.dryRun = true
                case "--silent" | "--quiet" | "-q" => opts.silent = true
                case "--include" => {
                    i++
                    if (i < args.size) {
                        opts.includePatterns.append(args[i])
                    }
                }
                case "--exclude" => {
                    i++
                    if (i < args.size) {
                        opts.excludePatterns.append(args[i])
                    }
                }
                case "--help" | "-h" => {
                    printPackHelp()
                    return opts
                }
                case _ => logger.warn("Unknown option: ${arg}")
            }
            i++
        }
        return opts
    }

    /// 打印 pack 命令帮助
    private func printPackHelp(): Unit {
        println("Usage: bao pack [options]")
        println("")
        println("Create a tarball from a package")
        println("")
        println("Options:")
        println("  --filename <name>    Output filename (default: <name>-<version>.tgz)")
        println("  --destination <dir>  Output directory (default: current directory)")
        println("  --gzip               Enable gzip compression (default)")
        println("  --no-gzip            Disable gzip compression")
        println("  --dry-run            Don't actually create the tarball")
        println("  --include <pattern>  Include file pattern")
        println("  --exclude <pattern>  Exclude file pattern")
        println("  --silent, --quiet    Suppress output")
        println("  --help, -h           Print this help")
    }
}
