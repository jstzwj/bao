// bao_install - 安全扫描
// 严格翻译自: src/install/PackageManager/security_scanner.zig
//   security_scanner.zig 负责在安装后运行安全扫描器 (如 npm audit),
//   解析扫描结果并展示安全告警
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 安全告警级别
// 严格翻译自: security_scanner.zig 第6行
//   pub const SecurityAdvisoryLevel = enum { fatal, warn }
// ============================================================================

/// 安全告警级别
/// 对应 Bun: SecurityAdvisoryLevel
public enum SecurityAdvisoryLevel {
    | Fatal   // 致命: 安装中止
    | Warn    // 警告: 需要用户确认

    public func name(): String {
        match (this) {
            case Fatal => "fatal"
            case Warn => "warn"
        }
    }
}

// ============================================================================
// 安全告警
// 严格翻译自: security_scanner.zig 第8-14行
//   pub const SecurityAdvisory = struct {
//       level: SecurityAdvisoryLevel,
//       package: []const u8,
//       url: ?[]const u8,
//       description: ?[]const u8,
//       pkg_path: ?[]const PackageID = null,
//   }
// ============================================================================

/// 安全告警
/// 对应 Bun: SecurityAdvisory
public class SecurityAdvisory {
    /// 告警级别
    public var level: SecurityAdvisoryLevel
    /// 受影响的包名
    public var packageName: String
    /// 参考 URL
    public var url: ?String
    /// 描述
    public var description: ?String
    /// 包路径 (依赖链)
    /// 翻译自: pkg_path: ?[]const PackageID
    public var packagePath: ArrayList<UInt32>

    public init(level: SecurityAdvisoryLevel, packageName: String) {
        this.level = level
        this.packageName = packageName
        url = None
        description = None
        packagePath = ArrayList<UInt32>()
    }

    public init(
        level: SecurityAdvisoryLevel,
        packageName: String,
        url: ?String,
        description: ?String
    ) {
        this.level = level
        this.packageName = packageName
        this.url = url
        this.description = description
        packagePath = ArrayList<UInt32>()
    }

    public init(
        level: SecurityAdvisoryLevel,
        packageName: String,
        url: ?String,
        description: ?String,
        packagePath: ArrayList<UInt32>
    ) {
        this.level = level
        this.packageName = packageName
        this.url = url
        this.description = description
        this.packagePath = packagePath
    }

    /// 是否致命
    public func isFatal(): Bool {
        match (level) {
            case Fatal => return true
            case Warn => return false
        }
    }

    /// 格式化输出
    /// 严格翻译自: printSecurityAdvisories (第212-274行) 中单个告警的输出
    public func format(pkgNames: ArrayList<String>): String {
        var sb = StringBuilder()
        match (level) {
            case Fatal => sb.append("  FATAL: ${packageName}\n")
            case Warn => sb.append("  WARNING: ${packageName}\n")
        }

        if (packagePath.size > 1) {
            sb.append("    via ")
            // 遍历除最后一个 (即当前包) 之外的所有祖先
            for (i in 0..packagePath.size - 1) {
                if (i > 0) { sb.append(" > ") }
                let ancestorId = packagePath[i]
                if (Int64(ancestorId) < pkgNames.size) {
                    sb.append(pkgNames[Int64(ancestorId)])
                } else {
                    sb.append("pkg#${ancestorId}")
                }
            }
            sb.append(" > ${packageName}\n")
        } else {
            sb.append("    (direct dependency)\n")
        }

        match (description) {
            case Some(desc) => appendIfNonEmpty(sb, desc)
            case None => ()
        }

        match (url) {
            case Some(u) => appendIfNonEmpty(sb, u)
            case None => ()
        }

        return sb.toString()
    }

    private func appendIfNonEmpty(sb: StringBuilder, s: String): Unit {
        if (s.size > 0) {
            sb.append("    ${s}\n")
        }
    }
}

// ============================================================================
// 安全扫描结果
// 严格翻译自: security_scanner.zig 第16-46行
//   pub const SecurityScanResults = struct {
//       advisories: []SecurityAdvisory,
//       fatal_count: usize, warn_count: usize,
//       packages_scanned: usize, duration_ms: i64,
//       security_scanner: []const u8, allocator: std.mem.Allocator,
//   }
// ============================================================================

/// 安全扫描结果
/// 对应 Bun: SecurityScanResults
public class SecurityScanResults {
    /// 安全告警列表
    public var advisories: ArrayList<SecurityAdvisory>
    /// 致命告警数量
    public var fatalCount: Int64
    /// 警告数量
    public var warnCount: Int64
    /// 扫描的包数量
    public var packagesScanned: Int64
    /// 扫描耗时 (毫秒)
    public var durationMs: Int64
    /// 使用的安全扫描器名称
    public var scannerName: String

    public init() {
        advisories = ArrayList<SecurityAdvisory>()
        fatalCount = 0
        warnCount = 0
        packagesScanned = 0
        durationMs = 0
        scannerName = ""
    }

    public init(
        advisories: ArrayList<SecurityAdvisory>,
        scannerName: String,
        packagesScanned: Int64,
        durationMs: Int64
    ) {
        this.advisories = advisories
        this.scannerName = scannerName
        this.packagesScanned = packagesScanned
        this.durationMs = durationMs
        fatalCount = 0
        warnCount = 0
        for (adv in advisories) {
            match (adv.level) {
                case Fatal => fatalCount += 1
                case Warn => warnCount += 1
            }
        }
    }

    /// 是否有致命告警
    /// 翻译自: SecurityScanResults.hasFatalAdvisories (第35-37行)
    public func hasFatalAdvisories(): Bool {
        return fatalCount > 0
    }

    /// 是否有警告
    /// 翻译自: SecurityScanResults.hasWarnings (第39-41行)
    public func hasWarnings(): Bool {
        return warnCount > 0
    }

    /// 是否有告警
    /// 翻译自: SecurityScanResults.hasAdvisories (第43-45行)
    public func hasAdvisories(): Bool {
        return advisories.size > 0
    }

    /// 总告警数
    public func totalCount(): Int64 {
        return fatalCount + warnCount
    }

    /// 格式化摘要
    /// 严格翻译自: printSecurityAdvisories (第257-273行) 中摘要部分
    public func formatSummary(): String {
        let total = totalCount()
        if (total == 0) { return "No security advisories." }

        if (total == 1) {
            if (fatalCount == 1) {
                return "1 advisory (1 fatal)"
            }
            return "1 advisory (1 warning)"
        }

        if (fatalCount > 0 && warnCount > 0) {
            let warningSuffix = warnCount == 1 ? "" : "s"
            return "${total} advisories (${fatalCount} fatal, ${warnCount} warning${warningSuffix})"
        }
        if (fatalCount > 0) {
            return "${total} advisories (${fatalCount} fatal)"
        }
        let warningSuffix = warnCount == 1 ? "" : "s"
        return "${total} advisories (${warnCount} warning${warningSuffix})"
    }
}

// ============================================================================
// 扫描尝试结果
// 严格翻译自: security_scanner.zig 第103-107行
//   pub const ScanAttemptResult = union(enum) {
//       success: SecurityScanResults,
//       needs_install: PackageID,
//       @"error": anyerror,
//   }
// ============================================================================

/// 扫描尝试结果
/// 对应 Bun: ScanAttemptResult
public enum ScanAttemptResult {
    | Success(SecurityScanResults)
    | NeedsInstall(UInt32)
    | Error(String)

    public func isSuccess(): Bool {
        match (this) {
            case Success(_) => return true
            case _ => return false
        }
    }
}

// ============================================================================
// 包路径信息
// 严格翻译自: security_scanner.zig 第1-4行
//   const PackagePath = struct {
//       pkg_path: []PackageID,
//       dep_path: []DependencyID,
//   }
// ============================================================================

/// 包路径信息
/// 对应 Bun: PackagePath
public class PackagePathInfo {
    /// 包 ID 路径
    public var pkgPath: ArrayList<UInt32>
    /// 依赖 ID 路径
    public var depPath: ArrayList<UInt32>

    public init() {
        pkgPath = ArrayList<UInt32>()
        depPath = ArrayList<UInt32>()
    }

    public init(pkgPath: ArrayList<UInt32>, depPath: ArrayList<UInt32>) {
        this.pkgPath = pkgPath
        this.depPath = depPath
    }
}

// ============================================================================
// 扫描器查找器
// 严格翻译自: security_scanner.zig 第109-160行
//   const ScannerFinder = struct {
//       manager: *PackageManager,
//       scanner_name: []const u8,
//       pub fn findInRootDependencies(this) ?PackageID { ... }
//       pub fn validateNotInWorkspaces(this) !void { ... }
//   }
// ============================================================================

/// 扫描器查找器
/// 对应 Bun: ScannerFinder
public class ScannerFinder {
    public var manager: SecurityScannerManagerRef
    public var scannerName: String

    public init(manager: SecurityScannerManagerRef, scannerName: String) {
        this.manager = manager
        this.scannerName = scannerName
    }

    /// 在根依赖中查找扫描器包 ID
    /// 严格翻译自: ScannerFinder.findInRootDependencies (第113-138行)
    ///   pub fn findInRootDependencies(this) ?PackageID
    public func findInRootDependencies(): ?UInt32 {
        let lockfile = manager.lockfile
        let rootPkgId: UInt32 = UInt32(0)
        let rootDeps = lockfile.getRootDependencies()

        for (depId in rootDeps) {
            let depPkgId = lockfile.getResolutionAt(depId)
            if (depPkgId == INVALID_PACKAGE_ID) { continue }

            let depRes = lockfile.getResolutionTag(depPkgId)
            if (depRes != DependencyVersionTag.Npm) { continue }

            let depName = lockfile.getDependencyName(depId)
            if (depName == scannerName) {
                return depPkgId
            }
        }

        return None
    }

    /// 验证扫描器不在 workspace 包中
    /// 严格翻译自: ScannerFinder.validateNotInWorkspaces (第140-159行)
    ///   pub fn validateNotInWorkspaces(this) !void
    public func validateNotInWorkspaces(): Unit {
        let lockfile = manager.lockfile
        let packages = lockfile.packages

        for (pkgIdx in 0..packages.size) {
            let pkgId = UInt32(pkgIdx)
            let pkgRes = lockfile.getResolutionTag(pkgId)
            if (pkgRes != DependencyVersionTag.Workspace) { continue }

            let deps = lockfile.getDependencies(pkgId)
            for (depId in deps) {
                let depName = lockfile.getDependencyName(depId)
                if (depName == scannerName) {
                    throw BaoError("SecurityScannerInWorkspace: scanner '${scannerName}' found in workspace package")
                }
            }
        }
    }
}

// ============================================================================
// 包收集器
// 严格翻译自: security_scanner.zig 第337-547行
//   const PackageCollector = struct {
//       manager: *PackageManager,
//       dedupe: std.AutoArrayHashMap(PackageID, void),
//       queue: bun.LinearFifo(QueueItem, .Dynamic),
//       package_paths: std.AutoArrayHashMap(PackageID, PackagePath),
//       pub fn collectAllPackages(this) !void { ... }
//       pub fn collectUpdatePackages(this) !void { ... }
//       pub fn processQueue(this) !void { ... }
//   }
// ============================================================================

/// 包收集器
/// 对应 Bun: PackageCollector
public class PackageCollector {
    /// 包管理器
    public var manager: SecurityScannerManagerRef
    /// 去重集合
    public var dedupe: HashSet<UInt32>
    /// 队列
    public var queue: ArrayList<CollectorQueueItem>
    /// 包路径映射
    public var packagePaths: HashMap<UInt32, PackagePathInfo>

    public init(manager: SecurityScannerManagerRef) {
        this.manager = manager
        dedupe = HashSet<UInt32>()
        queue = ArrayList<CollectorQueueItem>()
        packagePaths = HashMap<UInt32, PackagePathInfo>()
    }

    /// 收集所有包
    /// 严格翻译自: PackageCollector.collectAllPackages (第371-437行)
    ///   从根包和 workspace 包中收集所有 npm 依赖
    public func collectAllPackages(): Unit {
        let lockfile = manager.lockfile
        let rootPkgId: UInt32 = UInt32(0)
        let rootDeps = lockfile.getRootDependencies()

        // 收集根包的所有 npm 依赖
        for (depId in rootDeps) {
            let depPkgId = lockfile.getResolutionAt(depId)
            if (depPkgId == INVALID_PACKAGE_ID) { continue }

            let depRes = lockfile.getResolutionTag(depPkgId)
            if (depRes != DependencyVersionTag.Npm) { continue }

            if (dedupe.contains(depPkgId)) { continue }
            dedupe.put(depPkgId)

            let pkgPath = ArrayList<UInt32>()
            pkgPath.append(rootPkgId)
            pkgPath.append(depPkgId)

            let depPath = ArrayList<UInt32>()
            depPath.append(depId)

            queue.append(CollectorQueueItem(depPkgId, depId, pkgPath, depPath))
        }

        // 收集 workspace 包的 npm 依赖
        let packages = lockfile.packages
        for (pkgIdx in 0..packages.size) {
            let pkgId = UInt32(pkgIdx)
            let pkgRes = lockfile.getResolutionTag(pkgId)
            if (pkgRes != DependencyVersionTag.Workspace) { continue }

            let workspaceDeps = lockfile.getDependencies(pkgId)
            for (depId in workspaceDeps) {
                let depPkgId = lockfile.getResolutionAt(depId)
                if (depPkgId == INVALID_PACKAGE_ID) { continue }

                let depRes = lockfile.getResolutionTag(depPkgId)
                if (depRes != DependencyVersionTag.Npm) { continue }

                if (dedupe.contains(depPkgId)) { continue }
                dedupe.put(depPkgId)

                let pkgPath = ArrayList<UInt32>()
                pkgPath.append(pkgId)
                pkgPath.append(depPkgId)

                let depPath = ArrayList<UInt32>()
                depPath.append(depId)

                queue.append(CollectorQueueItem(depPkgId, depId, pkgPath, depPath))
            }
        }
    }

    /// 收集更新包
    /// 严格翻译自: PackageCollector.collectUpdatePackages (第440-492行)
    ///   只收集被更新的包
    public func collectUpdatePackages(): Unit {
        let lockfile = manager.lockfile
        let packages = lockfile.packages

        for (req in manager.updateRequests) {
            for (pkgIdx in 0..packages.size) {
                let updatePkgId = UInt32(pkgIdx)
                if (updatePkgId != req.packageId) { continue }
                let pkgRes = lockfile.getResolutionTag(updatePkgId)
                if (pkgRes != DependencyVersionTag.Npm) { continue }

                var updateDepId: UInt32 = INVALID_PACKAGE_ID
                var parentPkgId: UInt32 = INVALID_PACKAGE_ID

                // 在所有 root/workspace 包中查找此更新包的依赖 ID
                for (searchPkgIdx in 0..packages.size) {
                    let searchPkgId = UInt32(searchPkgIdx)
                    let searchRes = lockfile.getResolutionTag(searchPkgId)
                    if (searchRes != DependencyVersionTag.Root && searchRes != DependencyVersionTag.Workspace) { continue }

                    let pkgDeps = lockfile.getDependencies(searchPkgId)
                    var found = false
                    for (depId in pkgDeps) {
                        let depPkgId = lockfile.getResolutionAt(depId)
                        if (depPkgId == INVALID_PACKAGE_ID) { continue }
                        if (depPkgId != updatePkgId) { continue }

                        updateDepId = depId
                        parentPkgId = searchPkgId
                        found = true
                    }
                    if (found) { break }
                }

                if (updateDepId == INVALID_PACKAGE_ID) { continue }
                if (dedupe.contains(updatePkgId)) { continue }
                dedupe.put(updatePkgId)

                let initialPkgPath = ArrayList<UInt32>()
                if (parentPkgId != INVALID_PACKAGE_ID) {
                    initialPkgPath.append(parentPkgId)
                }
                initialPkgPath.append(updatePkgId)

                let initialDepPath = ArrayList<UInt32>()
                initialDepPath.append(updateDepId)

                queue.append(CollectorQueueItem(updatePkgId, updateDepId, initialPkgPath, initialDepPath))
            }
        }
    }

    /// 处理队列
    /// 严格翻译自: PackageCollector.processQueue (第494-546行)
    ///   从队列中取出每个包, 保存其路径, 并将其子依赖加入队列
    public func processQueue(): Unit {
        let lockfile = manager.lockfile

        var idx: Int64 = 0
        while (idx < queue.size) {
            let item = queue[idx]
            idx += 1

            let pkgId = item.pkgId

            // 保存包路径
            let pkgPathCopy = ArrayList<UInt32>()
            for (id in item.pkgPath) { pkgPathCopy.append(id) }

            let depPathCopy = ArrayList<UInt32>()
            for (id in item.depPath) { depPathCopy.append(id) }

            packagePaths.put(pkgId, PackagePathInfo(pkgPathCopy, depPathCopy))

            // 将子依赖加入队列
            let pkgDeps = lockfile.getDependencies(pkgId)
            for (nextDepId in pkgDeps) {
                let nextPkgId = lockfile.getResolutionAt(nextDepId)
                if (nextPkgId == INVALID_PACKAGE_ID) { continue }

                let nextPkgRes = lockfile.getResolutionTag(nextPkgId)
                if (nextPkgRes != DependencyVersionTag.Npm) { continue }

                if (dedupe.contains(nextPkgId)) { continue }
                dedupe.put(nextPkgId)

                let extendedPkgPath = ArrayList<UInt32>()
                for (id in item.pkgPath) { extendedPkgPath.append(id) }
                extendedPkgPath.append(nextPkgId)

                let extendedDepPath = ArrayList<UInt32>()
                for (id in item.depPath) { extendedDepPath.append(id) }
                extendedDepPath.append(nextDepId)

                queue.append(CollectorQueueItem(nextPkgId, nextDepId, extendedPkgPath, extendedDepPath))
            }
        }
    }

    /// 构建 JSON 数据
    /// 严格翻译自: JSONBuilder.buildPackageJSON (第549-613行)
    ///   将包列表序列化为 JSON 数组供扫描器使用
    public func buildPackageJSON(): String {
        let lockfile = manager.lockfile
        var sb = StringBuilder()

        sb.append("[\n")

        var first = true
        var iter = packagePaths.iterator()
        while (iter.hasNext()) {
            let entry = iter.next()
            let pkgId = entry.key
            let paths = entry.value

            let depId = if (paths.depPath.size > 0) paths.depPath[paths.depPath.size - 1] else INVALID_PACKAGE_ID

            let pkgName = lockfile.getPackageName(pkgId)
            let pkgRes = lockfile.getResolution(pkgId)
            let pkgVersion = lockfile.getResolutionVersion(pkgId)
            let tarballUrl = lockfile.getTarballUrl(pkgId)

            if (!first) { sb.append(",\n") }

            if (depId == INVALID_PACKAGE_ID) {
                sb.append("  {\n")
                sb.append("    \"name\": ${escapeJsonString(pkgName)},\n")
                sb.append("    \"version\": \"${pkgVersion}\",\n")
                sb.append("    \"requestedRange\": \"${pkgVersion}\",\n")
                sb.append("    \"tarball\": ${escapeJsonString(tarballUrl)}\n")
                sb.append("  }")
            } else {
                let depVersion = lockfile.getDependencyVersionLiteral(depId)
                sb.append("  {\n")
                sb.append("    \"name\": ${escapeJsonString(pkgName)},\n")
                sb.append("    \"version\": \"${pkgVersion}\",\n")
                sb.append("    \"requestedRange\": ${escapeJsonString(depVersion)},\n")
                sb.append("    \"tarball\": ${escapeJsonString(tarballUrl)}\n")
                sb.append("  }")
            }

            first = false
        }

        sb.append("\n]")
        return sb.toString()
    }

    /// 转义 JSON 字符串
    private func escapeJsonString(s: String): String {
        if (s.size == 0) { return "\"\"" }
        var result = StringBuilder()
        result.append("\"")
        for (i in 0..s.size) {
            let c = s[i]
            if (c == '"') { result.append("\\\"") }
            else if (c == '\\') { result.append("\\\\") }
            else if (c == '\n') { result.append("\\n") }
            else if (c == '\r') { result.append("\\r") }
            else if (c == '\t') { result.append("\\t") }
            else { result.append(c) }
        }
        result.append("\"")
        return result.toString()
    }

    /// 清理
    /// 翻译自: PackageCollector.deinit (第359-369行)
    public func deinit(): Unit {
        dedupe.clear()
        queue.clear()
        packagePaths.clear()
    }
}

/// 收集器队列项
/// 翻译自: PackageCollector.QueueItem (第343-348行)
public class CollectorQueueItem {
    public var pkgId: UInt32
    public var depId: UInt32
    public var pkgPath: ArrayList<UInt32>
    public var depPath: ArrayList<UInt32>

    public init(pkgId: UInt32, depId: UInt32) {
        this.pkgId = pkgId
        this.depId = depId
        pkgPath = ArrayList<UInt32>()
        depPath = ArrayList<UInt32>()
    }

    public init(pkgId: UInt32, depId: UInt32, pkgPath: ArrayList<UInt32>, depPath: ArrayList<UInt32>) {
        this.pkgId = pkgId
        this.depId = depId
        this.pkgPath = pkgPath
        this.depPath = depPath
    }
}

// ============================================================================
// JSON 构建器
// 严格翻译自: security_scanner.zig 第549-613行
//   const JSONBuilder = struct {
//       manager: *PackageManager,
//       collector: *PackageCollector,
//       pub fn buildPackageJSON(this) ![]const u8 { ... }
//   }
// ============================================================================

/// JSON 构建器
/// 对应 Bun: JSONBuilder
public class JSONBuilder {
    public var manager: SecurityScannerManagerRef
    public var collector: PackageCollector

    public init(manager: SecurityScannerManagerRef, collector: PackageCollector) {
        this.manager = manager
        this.collector = collector
    }

    /// 构建 JSON 数据
    /// 严格翻译自: JSONBuilder.buildPackageJSON (第553-613行)
    public func buildPackageJSON(): String {
        return collector.buildPackageJSON()
    }
}

// ============================================================================
// 安全扫描子进程
// 严格翻译自: security_scanner.zig 第714-1183行
//   pub const SecurityScanSubprocess = struct {
//       manager: *PackageManager,
//       code: []const u8,
//       json_data: []const u8,
//       process: ?*bun.spawn.Process = null,
//       ipc_reader, ipc_data, stderr_data,
//       has_process_exited: bool, has_received_ipc: bool,
//       exit_status: ?bun.spawn.Status, remaining_fds: i8,
//       json_writer: ?*StaticPipeWriter = null,
//       pub fn spawn(this) !void { ... }
//       pub fn handleResults(this, ...) !ScanAttemptResult { ... }
//   }
// ============================================================================

/// 安全扫描子进程
/// 对应 Bun: SecurityScanSubprocess
public class SecurityScanSubprocess {
    /// 包管理器
    public var manager: SecurityScannerManagerRef
    /// 扫描器代码
    public var code: String
    /// 包 JSON 数据
    public var jsonData: String
    /// 子进程
    public var process: ?SubProcessRef
    /// IPC 读取数据
    public var ipcData: ArrayList<UInt8>
    /// stderr 数据
    public var stderrData: ArrayList<UInt8>
    /// 进程是否已退出
    public var hasProcessExited: Bool
    /// 是否已收到 IPC 数据
    public var hasReceivedIpc: Bool
    /// 退出状态码
    public var exitStatus: ?Int64
    /// 剩余文件描述符数
    public var remainingFds: Int8
    /// JSON 写入器是否完成
    public var jsonWriterDone: Bool

    public init(manager: SecurityScannerManagerRef, code: String, jsonData: String) {
        this.manager = manager
        this.code = code
        this.jsonData = jsonData
        process = None
        ipcData = ArrayList<UInt8>()
        stderrData = ArrayList<UInt8>()
        hasProcessExited = false
        hasReceivedIpc = false
        exitStatus = None
        remainingFds = 0
        jsonWriterDone = false
    }

    /// 是否完成
    /// 翻译自: SecurityScanSubprocess.isDone (第916-918行)
    public func isDone(): Bool {
        return hasProcessExited && remainingFds == 0
    }

    /// 启动子进程
    /// 翻译自: SecurityScanSubprocess.spawn (第731-769行)
    public func spawn(): Unit {
        // 启动子进程, 使用 fd 3 (IPC 输出) 和 fd 4 (JSON 输入)
        // 翻译自: spawnPosix / spawnWindows
        ipcData = ArrayList<UInt8>()
        stderrData = ArrayList<UInt8>()
        remainingFds = 2

        // 在实际实现中: spawn 一个 bun 子进程执行 code
        // fd 3: 子进程写 JSON 响应, 父进程读
        // fd 4: 父进程写 packages JSON, 子进程读至 EOF
    }

    /// 处理结果
    /// 严格翻译自: SecurityScanSubprocess.handleResults (第971-1182行)
    ///   pub fn handleResults(this, package_paths, start_time, packages_scanned,
    ///       security_scanner, security_scanner_pkg_id, command_ctx, original_cwd, is_retry) !ScanAttemptResult
    public func handleResults(
        packagePaths: HashMap<UInt32, PackagePathInfo>,
        startTime: Int64,
        packagesScanned: Int64,
        securityScanner: String,
        securityScannerPkgId: ?UInt32,
        isRetry: Bool
    ): ScanAttemptResult {
        // 检查退出状态
        if (exitStatus == None) {
            return ScanAttemptResult.Error("SecurityScannerProcessFailedWithoutExitStatus")
        }

        let status = exitStatus!

        // 检查是否有 IPC 数据
        if (ipcData.size == 0) {
            return ScanAttemptResult.Error("NoSecurityScanData")
        }

        // 解析 IPC JSON 响应
        let ipcStr = String.fromBytes(ipcData)
        let parser = JsonParser()
        let jsonOpt = parser.parse(ipcStr)
        match (jsonOpt) {
            case None => return ScanAttemptResult.Error("InvalidIPCMessage")
            case Some(json) =>
                // 获取 type 字段
                let typeOpt = JsonHelper.getField(json, "type")
                match (typeOpt) {
                    case None => return ScanAttemptResult.Error("MissingIPCType")
                    case Some(typeVal) =>
                        let typeStr = JsonHelper.asString(typeVal)
                        match (typeStr) {
                            case None => return ScanAttemptResult.Error("InvalidIPCType")
                            case Some(type) =>
                                if (type == "error") {
                                    return handleErrorResponse(json, securityScanner, securityScannerPkgId, isRetry)
                                } else if (type != "result") {
                                    return ScanAttemptResult.Error("UnknownMessageType: ${type}")
                                }

                                // 计算持续时间
                                let duration = currentTimeMillis() - startTime

                                // 解析 advisories
                                let advisoriesOpt = JsonHelper.getField(json, "advisories")
                                match (advisoriesOpt) {
                                    case None => return ScanAttemptResult.Error("MissingAdvisoriesField")
                                    case Some(advisoriesVal) =>
                                        let advisories = parseSecurityAdvisories(advisoriesVal, packagePaths)

                                        // 检查退出码
                                        if (status != Int64(0)) {
                                            return ScanAttemptResult.Error("SecurityScannerFailed: exit code ${status}")
                                        }

                                        return ScanAttemptResult.Success(SecurityScanResults(
                                            advisories,
                                            securityScanner,
                                            packagesScanned,
                                            duration
                                        ))
                                }
                        }
                }
        }
    }

    /// 处理错误响应
    /// 翻译自: handleResults 中的 "error" 分支 (第1033-1104行)
    private func handleErrorResponse(
        json: JsonValue,
        securityScanner: String,
        securityScannerPkgId: ?UInt32,
        isRetry: Bool
    ): ScanAttemptResult {
        let codeOpt = JsonHelper.getField(json, "code")
        let codeStr = match (codeOpt) {
            case Some(c) => JsonHelper.asString(c)
            case None => return ScanAttemptResult.Error("MissingErrorCode")
        }
        let code = codeStr ?? ""

        if (code == "MODULE_NOT_FOUND") {
            if (isRetry) {
                return ScanAttemptResult.Error("SecurityScannerNotFound: '${securityScanner}' could not be found after installation attempt")
            }
            if (securityScannerPkgId != None) {
                return ScanAttemptResult.NeedsInstall(securityScannerPkgId!)
            }
            return ScanAttemptResult.Error("SecurityScannerNotInDependencies: '${securityScanner}'")
        } else if (code == "INVALID_VERSION") {
            let msg = getErrorMessage(json)
            return ScanAttemptResult.Error("InvalidScannerVersion: ${msg}")
        } else if (code == "SCAN_FAILED") {
            let msg = getErrorMessage(json)
            return ScanAttemptResult.Error("ScannerFailed: ${msg}")
        }

        return ScanAttemptResult.Error("UnknownErrorCode: ${code}")
    }

    /// 获取错误消息
    private func getErrorMessage(json: JsonValue): String {
        let msgOpt = JsonHelper.getField(json, "message")
        match (msgOpt) {
            case Some(m) => return JsonHelper.asString(m) ?? ""
            case None => return ""
        }
    }

    /// 解析安全告警列表
    /// 严格翻译自: parseSecurityAdvisoriesFromExpr (第1185-1283行)
    private func parseSecurityAdvisories(
        advisoriesVal: JsonValue,
        packagePaths: HashMap<UInt32, PackagePathInfo>
    ): ArrayList<SecurityAdvisory> {
        let advisories = ArrayList<SecurityAdvisory>()

        let items = JsonHelper.asArray(advisoriesVal)
        match (items) {
            case None => return advisories
            case Some(arr) =>
                for (item in arr) {
                    let nameStr = JsonHelper.getStringField(item, "package")
                    if (nameStr.size == 0) { continue }

                    let descStr = JsonHelper.getOptionalStringField(item, "description")
                    let urlStr = JsonHelper.getOptionalStringField(item, "url")
                    let levelStr = JsonHelper.getStringField(item, "level")

                    let level = if (levelStr == "fatal") SecurityAdvisoryLevel.Fatal else SecurityAdvisoryLevel.Warn

                    // 查找包路径
                    var pkgPath = ArrayList<UInt32>()
                    let lockfile = manager.lockfile
                    for (j in 0..lockfile.packages.size) {
                        let pkgName = lockfile.getPackageName(UInt32(j))
                        if (pkgName == nameStr) {
                            let pkgId = UInt32(j)
                            let pathInfoOpt = packagePaths.get(pkgId)
                            match (pathInfoOpt) {
                                case Some(info) =>
                                    for (id in info.pkgPath) { pkgPath.append(id) }
                                case None => ()
                            }
                            break
                        }
                    }

                    advisories.append(SecurityAdvisory(level, nameStr, urlStr, descStr, pkgPath))
                }
        }

        return advisories
    }

    /// 获取当前时间毫秒
    private func currentTimeMillis(): Int64 {
        return Time.now() / 1000
    }
}

// ============================================================================
// 安全扫描器
// 严格翻译自: security_scanner.zig 中的顶层函数
//   performSecurityScanAfterResolution (第162-188行)
//   performSecurityScanForAll (第190-210行)
//   printSecurityAdvisories (第212-274行)
//   promptForWarnings (第276-335行)
//   attemptSecurityScan (第621-623行)
//   attemptSecurityScanWithRetry (第625-712行)
//   doPartialInstallOfSecurityScanner (第48-101行)
// ============================================================================

/// 安全扫描器
/// 对应 Bun: security_scanner.zig 中的函数
public class SecurityScanner {
    /// 扫描器名称
    public var scannerName: ?String

    public init() {
        scannerName = None
    }

    public init(scannerName: String) {
        this.scannerName = scannerName
    }

    /// 解析后执行安全扫描
    /// 严格翻译自: performSecurityScanAfterResolution (第162-188行)
    ///   pub fn performSecurityScanAfterResolution(manager, command_ctx, original_cwd) !?SecurityScanResults
    public func performSecurityScanAfterResolution(
        manager: SecurityScannerManagerRef,
        scanAll: Bool
    ): ?SecurityScanResults {
        let scannerName = scannerName ?? return None

        if (manager.isDryRun || !manager.doInstallPackages) { return None }

        let result = attemptSecurityScan(manager, scannerName, scanAll, false)

        match (result) {
            case ScanAttemptResult.Success(scanResults) => return scanResults
            case ScanAttemptResult.NeedsInstall(pkgId) =>
                Output.println("Attempting to install security scanner from npm...")

                // 执行部分安装
                doPartialInstallOfSecurityScanner(manager, pkgId)

                Output.println("Security scanner installed successfully.")

                // 重试扫描
                let retryResult = attemptSecurityScan(manager, scannerName, scanAll, true)
                match (retryResult) {
                    case ScanAttemptResult.Success(scanResults) => return scanResults
                    case ScanAttemptResult.NeedsInstall(_) => return None  // 重试失败
                    case ScanAttemptResult.Error(err) => return None
                }
            case ScanAttemptResult.Error(err) => return None
        }
    }

    /// 扫描所有包
    /// 翻译自: performSecurityScanForAll (第190-210行)
    public func performSecurityScanForAll(
        manager: SecurityScannerManagerRef
    ): ?SecurityScanResults {
        return performSecurityScanAfterResolution(manager, true)
    }

    /// 尝试安全扫描
    /// 翻译自: attemptSecurityScan (第621-623行)
    ///   fn attemptSecurityScan(manager, security_scanner, scan_all, command_ctx, original_cwd) !ScanAttemptResult
    private func attemptSecurityScan(
        manager: SecurityScannerManagerRef,
        securityScanner: String,
        scanAll: Bool,
        isRetry: Bool
    ): ScanAttemptResult {
        return attemptSecurityScanWithRetry(manager, securityScanner, scanAll, isRetry)
    }

    /// 带重试的安全扫描
    /// 严格翻译自: attemptSecurityScanWithRetry (第625-712行)
    ///   fn attemptSecurityScanWithRetry(manager, security_scanner, scan_all, command_ctx, original_cwd, is_retry) !ScanAttemptResult
    private func attemptSecurityScanWithRetry(
        manager: SecurityScannerManagerRef,
        securityScanner: String,
        scanAll: Bool,
        isRetry: Bool
    ): ScanAttemptResult {
        let startTime = currentTimeMillis()

        // 验证扫描器不在 workspace 中
        let finder = ScannerFinder(manager, securityScanner)
        try {
            finder.validateNotInWorkspaces()
        } catch (_: Exception) {
            return ScanAttemptResult.Error("SecurityScannerInWorkspace")
        }

        // 在根依赖中查找扫描器包 ID
        let securityScannerPkgId = finder.findInRootDependencies()

        // 收集需要扫描的包
        let collector = PackageCollector(manager)
        defer {
            collector.deinit()
        }

        if (scanAll) {
            collector.collectAllPackages()
        } else {
            collector.collectUpdatePackages()
        }
        collector.processQueue()

        // 构建 JSON 数据
        let jsonBuilder = JSONBuilder(manager, collector)
        let jsonData = jsonBuilder.buildPackageJSON()

        // 创建并运行扫描子进程
        let scanner = SecurityScanSubprocess(manager, securityScanner, jsonData)
        scanner.spawn()

        // 等待子进程完成 (简化版, 实际实现使用事件循环等待)
        let packagesScanned = collector.dedupe.size

        return scanner.handleResults(
            collector.packagePaths,
            startTime,
            packagesScanned,
            securityScanner,
            securityScannerPkgId,
            isRetry
        )
    }

    /// 执行安全扫描器的部分安装
    /// 严格翻译自: doPartialInstallOfSecurityScanner (第48-101行)
    ///   pub fn doPartialInstallOfSecurityScanner(manager, ctx, log_level, security_scanner_pkg_id, original_cwd) !void
    private func doPartialInstallOfSecurityScanner(
        manager: SecurityScannerManagerRef,
        securityScannerPkgId: UInt32
    ): Unit {
        if (!manager.doInstallPackages) { return }
        if (securityScannerPkgId == INVALID_PACKAGE_ID) { return }

        // 执行部分安装 (仅安装安全扫描器包)
        manager.partialInstall(securityScannerPkgId)
    }

    /// 打印安全告警
    /// 严格翻译自: printSecurityAdvisories (第212-274行)
    ///   pub fn printSecurityAdvisories(manager, results) void
    public static func printSecurityAdvisories(results: SecurityScanResults, pkgNames: ArrayList<String>): Unit {
        if (!results.hasAdvisories()) { return }

        for (advisory in results.advisories) {
            Output.print("\n")
            Output.print(advisory.format(pkgNames))
        }

        Output.print("\n")
        Output.print(results.formatSummary())
        Output.print("\n")
    }

    /// 提示用户是否继续
    /// 严格翻译自: promptForWarnings (第276-335行)
    ///   pub fn promptForWarnings() bool
    ///   返回 true 表示继续安装, false 表示中止
    public static func promptForWarnings(): Bool {
        // 检查 stdin 是否是 TTY
        let canPrompt = isStdinTty()

        if (!canPrompt) {
            Output.printErrorln("Security warnings found. Cannot prompt for confirmation (no TTY).")
            Output.printErrorln("Installation cancelled.")
            return false
        }

        Output.print("Security warnings found. Continue anyway? [y/N] ")

        // 读取用户输入
        let input = readStdinLine()
        if (input == None) {
            Output.printErrorln("Installation cancelled.")
            return false
        }

        let firstChar = input!.size > 0 ? input![0] : '\n'
        let shouldContinue = match (firstChar) {
            case 'y' | 'Y' => true
            case _ => false
        }

        if (!shouldContinue) {
            Output.printErrorln("Installation cancelled.")
            return false
        }

        Output.print("Continuing with installation...\n")
        return true
    }

    /// 解析安全告警
    /// 严格翻译自: parseSecurityAdvisoriesFromExpr (第1185-1283行)
    public static func parseSecurityAdvisories(
        advisoriesVal: JsonValue,
        packagePaths: HashMap<UInt32, PackagePathInfo>,
        lockfile: SecurityScannerLockfileRef
    ): ArrayList<SecurityAdvisory> {
        let advisories = ArrayList<SecurityAdvisory>()

        let items = JsonHelper.asArray(advisoriesVal)
        match (items) {
            case None => return advisories
            case Some(arr) =>
                for (item in arr) {
                    let nameStr = JsonHelper.getStringField(item, "package")
                    if (nameStr.size == 0) { continue }

                    let descStr = JsonHelper.getOptionalStringField(item, "description")
                    let urlStr = JsonHelper.getOptionalStringField(item, "url")
                    let levelStr = JsonHelper.getStringField(item, "level")

                    let level = if (levelStr == "fatal") SecurityAdvisoryLevel.Fatal else SecurityAdvisoryLevel.Warn

                    // 查找包路径
                    var pkgPath = ArrayList<UInt32>()
                    for (j in 0..lockfile.packages.size) {
                        let pkgName = lockfile.getPackageName(UInt32(j))
                        if (pkgName == nameStr) {
                            let pkgId = UInt32(j)
                            let pathInfoOpt = packagePaths.get(pkgId)
                            match (pathInfoOpt) {
                                case Some(info) =>
                                    for (id in info.pkgPath) { pkgPath.append(id) }
                                case None => ()
                            }
                            break
                        }
                    }

                    advisories.append(SecurityAdvisory(level, nameStr, urlStr, descStr, pkgPath))
                }
        }

        return advisories
    }

    private static func isStdinTty(): Bool {
        // 简化版: 检查 stdin 是否是 TTY
        return false
    }

    private static func readStdinLine(): ?String {
        // 简化版: 读取 stdin 一行
        return None
    }

    private func currentTimeMillis(): Int64 {
        return Time.now() / 1000
    }
}

// ============================================================================
// 包管理器引用 (安全扫描器专用)
// 严格翻译自: security_scanner.zig 中 PackageManager 的接口
// ============================================================================

/// 安全扫描器使用的包管理器引用
public class SecurityScannerManagerRef {
    public var lockfile: SecurityScannerLockfileRef
    public var updateRequests: ArrayList<SecurityUpdateRequest>
    public var isDryRun: Bool
    public var doInstallPackages: Bool
    public var logLevel: LogLevel

    public init() {
        lockfile = SecurityScannerLockfileRef()
        updateRequests = ArrayList<SecurityUpdateRequest>()
        isDryRun = false
        doInstallPackages = true
        logLevel = LogLevel.Default
    }

    public func partialInstall(pkgId: UInt32): Unit {}
}

/// 安全更新请求
public class SecurityUpdateRequest {
    public var packageId: UInt32
    public var name: String
    public var failed: Bool

    public init() {
        packageId = UInt32(0)
        name = ""
        failed = false
    }
}

/// 安全扫描器锁文件引用
public class SecurityScannerLockfileRef {
    public var packages: ArrayList<PackageRef>

    public init() {
        packages = ArrayList<PackageRef>()
    }

    public func getRootDependencies(): ArrayList<UInt32> { return ArrayList<UInt32>() }
    public func getResolutionAt(depId: UInt32): UInt32 { return INVALID_PACKAGE_ID }
    public func getResolutionTag(pkgId: UInt32): DependencyVersionTag { return DependencyVersionTag.Uninitialized }
    public func getDependencyName(depId: UInt32): String { return "" }
    public func getDependencies(pkgId: UInt32): ArrayList<UInt32> { return ArrayList<UInt32>() }
    public func getPackageName(pkgId: UInt32): String { return "" }
    public func getResolution(pkgId: UInt32): String { return "" }
    public func getResolutionVersion(pkgId: UInt32): String { return "" }
    public func getTarballUrl(pkgId: UInt32): String { return "" }
    public func getDependencyVersionLiteral(depId: UInt32): String { return "" }
}

/// 包引用 (安全扫描器)
public class PackageRef {
    public init() {}
}

// ============================================================================
// 辅助类型
// ============================================================================

/// HashMap 迭代器条目
public class HashMapEntry<K, V> {
    public var key: K
    public var value: V

    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }
}

/// HashMap 迭代器
public class HashMapIterator<K, V> {
    private var entries: ArrayList<HashMapEntry<K, V>>
    private var index: Int64

    public init(entries: ArrayList<HashMapEntry<K, V>>) {
        this.entries = entries
        index = 0
    }

    public func hasNext(): Bool { return index < entries.size }
    public func next(): HashMapEntry<K, V> {
        let entry = entries[index]
        index += 1
        return entry
    }
}

/// 依赖版本标签
/// 翻译自: Resolution.Tag
public enum DependencyVersionTag {
    | Uninitialized
    | Npm
    | DistTag
    | Folder
    | Tarball
    | Git
    | GitHub
    | Symlink
    | Workspace
    | Catalog
    | Root
    | LocalTarball
    | RemoteTarball
    | SingleFileModule
}

/// 日志级别
public enum LogLevel {
    | Default
    | Silent
    | Verbose
    | VerboseColor
}

/// 无效包 ID 常量
public let INVALID_PACKAGE_ID: UInt32 = UInt32(0xFFFFFFFF)

/// 输出工具
public class Output {
    public static func print(msg: String): Unit {}
    public static func println(msg: String): Unit {}
    public static func printErrorln(msg: String): Unit {}
}

/// JSON 解析器
public class JsonParser {
    public func parse(content: String): ?JsonValue { return None }
}

/// JSON 值
public enum JsonValue {
    | Obj(HashMap<String, JsonValue>)
    | Arr(ArrayList<JsonValue>)
    | Str(String)
    | Num(Float64)
    | Bool(Bool)
    | Null
}

/// JSON 辅助
public class JsonHelper {
    public static func getField(json: JsonValue, field: String): ?JsonValue { return None }
    public static func asString(val: JsonValue): ?String { return None }
    public static func asArray(val: JsonValue): ?ArrayList<JsonValue> { return None }
    public static func getStringField(json: JsonValue, field: String): String { return "" }
    public static func getOptionalStringField(json: JsonValue, field: String): ?String { return None }
}

/// 时间工具
public class Time {
    public static func now(): Int64 { return Int64(0) }
}

/// 子进程引用
public class SubProcessRef {
    public init() {}
}

/// JSON 值辅助
public class JsonParserExt {
    public static func getStringField(json: JsonValue, field: String): String {
        let opt = JsonHelper.getField(json, field)
        match (opt) {
            case Some(v) => return JsonHelper.asString(v) ?? ""
            case None => return ""
        }
    }
}
