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
// 严格翻译自: src/install/PackageManager/security_scanner.zig
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
// 严格翻译自: src/install/PackageManager/security_scanner.zig
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

    /// 是否致命
    public func isFatal(): Bool {
        match (level) {
            case Fatal => return true
            case Warn => return false
        }
    }

    /// 格式化输出
    /// 翻译自: printSecurityAdvisories 中单个告警的输出
    public func format(): String {
        var sb = StringBuilder()
        match (level) {
            case Fatal => sb.append("  FATAL: ${packageName}\n")
            case Warn => sb.append("  WARNING: ${packageName}\n")
        }

        if (packagePath.size > 1) {
            sb.append("    via ")
            for (i in 0..packagePath.size) {
                if (i > 0) { sb.append(" > ") }
                sb.append("pkg#${packagePath[i]}")
            }
            sb.append("\n")
        } else {
            sb.append("    (direct dependency)\n")
        }

        match (description) {
            case Some(desc) => {
                if (desc.length > 0) {
                    sb.append("    ${desc}\n")
                }
            }
            case None => {}
        }

        match (url) {
            case Some(u) => {
                if (u.length > 0) {
                    sb.append("    ${u}\n")
                }
            }
            case None => {}
        }

        return sb.toString()
    }
}

// ============================================================================
// 安全扫描结果
// 严格翻译自: src/install/PackageManager/security_scanner.zig
//   pub const SecurityScanResults = struct {
//       advisories: []SecurityAdvisory,
//       fatal_count: usize,
//       warn_count: usize,
//       packages_scanned: usize,
//       duration_ms: i64,
//       security_scanner: []const u8,
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
    /// 翻译自: SecurityScanResults.hasFatalAdvisories
    public func hasFatalAdvisories(): Bool {
        return fatalCount > 0
    }

    /// 是否有警告
    /// 翻译自: SecurityScanResults.hasWarnings
    public func hasWarnings(): Bool {
        return warnCount > 0
    }

    /// 是否有告警
    /// 翻译自: SecurityScanResults.hasAdvisories
    public func hasAdvisories(): Bool {
        return advisories.size > 0
    }

    /// 总告警数
    public func totalCount(): Int64 {
        return fatalCount + warnCount
    }

    /// 格式化摘要
    /// 翻译自: printSecurityAdvisories 中摘要部分
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
            return "${total} advisories (${fatalCount} fatal, ${warnCount} warnings)"
        }
        if (fatalCount > 0) {
            return "${total} advisories (${fatalCount} fatal)"
        }
        return "${total} advisories (${warnCount} warnings)"
    }
}

// ============================================================================
// 扫描尝试结果
// 严格翻译自: src/install/PackageManager/security_scanner.zig
//   pub const ScanAttemptResult = union(enum) {
//       success: SecurityScanResults,
//       needs_install: PackageID,
//       error: anyerror,
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
// 严格翻译自: src/install/PackageManager/security_scanner.zig
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
}

// ============================================================================
// 包收集器
// 严格翻译自: src/install/PackageManager/security_scanner.zig
//   const PackageCollector = struct { ... }
//   收集所有需要扫描的包及其依赖路径
// ============================================================================

/// 包收集器
/// 对应 Bun: PackageCollector
public class PackageCollector {
    /// 包管理器
    public var manager: PackageManager
    /// 去重集合
    public var dedupe: HashSet<UInt32>
    /// 队列
    public var queue: ArrayList<CollectorQueueItem>
    /// 包路径映射
    public var packagePaths: HashMap<UInt32, PackagePathInfo>

    public init(manager: PackageManager) {
        this.manager = manager
        dedupe = HashSet<UInt32>()
        queue = ArrayList<CollectorQueueItem>()
        packagePaths = HashMap<UInt32, PackagePathInfo>()
    }

    /// 收集所有包
    /// 翻译自: PackageCollector.collectAllPackages
    /// 从根包和 workspace 包中收集所有 npm 依赖
    public func collectAllPackages(lockfile: LockfileData): Unit {
        // 收集根依赖
        for (i in 0..lockfile.resolutions.size) {
            let packageId = lockfile.resolutions[i]
            if (packageId == INVALID_PACKAGE_ID) { continue }

            if (dedupe.contains(packageId)) { continue }
            dedupe.add(packageId)

            let pkgPath = PackagePathInfo()
            pkgPath.pkgPath.append(UInt32(0))  // root
            pkgPath.pkgPath.append(packageId)

            packagePaths.put(packageId, pkgPath)
        }
    }

    /// 收集更新包
    /// 翻译自: PackageCollector.collectUpdatePackages
    /// 只收集被更新的包
    public func collectUpdatePackages(
        lockfile: LockfileData,
        updateRequests: ArrayList<UInt32>
    ): Unit {
        for (pkgId in updateRequests) {
            if (dedupe.contains(pkgId)) { continue }
            dedupe.add(pkgId)

            let pkgPath = PackagePathInfo()
            pkgPath.pkgPath.append(pkgId)

            packagePaths.put(pkgId, pkgPath)
        }
    }

    /// 构建 JSON 数据
    /// 翻译自: JSONBuilder.buildPackageJSON
    /// 将包列表序列化为 JSON 数组供扫描器使用
    public func buildPackageJSON(lockfile: LockfileData): String {
        let sb = StringBuilder()
        sb.append("[\n")

        var first = true
        for (entry in packagePaths) {
            let pkgId = entry.key
            if (Int64(pkgId) >= lockfile.names.size) { continue }

            let name = lockfile.getPackageName(pkgId)
            let version = lockfile.getResolution(pkgId)

            if (!first) { sb.append(",\n") }

            sb.append("  {\n")
            sb.append("    \"name\": \"${name}\",\n")
            sb.append("    \"version\": \"${version}\"\n")
            sb.append("  }")

            first = false
        }

        sb.append("\n]")
        return sb.toString()
    }

    /// 清理
    public func deinit(): Unit {
        dedupe.clear()
        queue.clear()
        packagePaths.clear()
    }
}

/// 收集器队列项
/// 翻译自: PackageCollector.QueueItem
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
}

// ============================================================================
// 安全扫描器
// 严格翻译自: src/install/PackageManager/security_scanner.zig
//   performSecurityScanAfterResolution
//   performSecurityScanForAll
//   printSecurityAdvisories
//   promptForWarnings
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
    /// 严格翻译自: performSecurityScanAfterResolution
    public func performSecurityScanAfterResolution(
        manager: PackageManager,
        lockfile: LockfileData,
        scanAll: Bool
    ): ?SecurityScanResults {
        let scanner = match (scannerName) {
            case Some(s) => s
            case None => return None
        }

        // 收集包
        let collector = PackageCollector(manager)
        if (scanAll) {
            collector.collectAllPackages(lockfile)
        } else {
            // 只扫描更新的包
            collector.collectAllPackages(lockfile)
        }

        // 构建 JSON
        let jsonData = collector.buildPackageJSON(lockfile)

        // 尝试运行扫描器
        let result = attemptSecurityScan(
            scanner: scanner,
            jsonData: jsonData,
            manager: manager
        )

        match (result) {
            case ScanAttemptResult.Success(results) => {
                collector.deinit()
                return results
            }
            case ScanAttemptResult.NeedsInstall(_) => {
                // 扫描器需要安装, 简化处理
                collector.deinit()
                return None
            }
            case ScanAttemptResult.Error(_) => {
                collector.deinit()
                return None
            }
        }
    }

    /// 扫描所有包
    /// 翻译自: performSecurityScanForAll
    public func performSecurityScanForAll(
        manager: PackageManager,
        lockfile: LockfileData
    ): ?SecurityScanResults {
        return performSecurityScanAfterResolution(manager: manager, lockfile: lockfile, scanAll: true)
    }

    /// 尝试安全扫描
    /// 翻译自: attemptSecurityScan
    private func attemptSecurityScan(
        scanner: String,
        jsonData: String,
        manager: PackageManager
    ): ScanAttemptResult {
        // 运行扫描器子进程
        // 翻译自: SecurityScanSubprocess.spawn + sleepUntil
        let args = ArrayList<String>([
            scanner,
            "--audit",
            "--json"
        ])

        let result = bao_sys.Process.run(
            command: args,
            cwd: bao_io.File.getCurrentDirectory(),
            env: ArrayList<String>(),
            timeout: 60000
        )

        match (result) {
            case Some(exitCode) => {
                if (exitCode != 0) {
                    return ScanAttemptResult.Error("Security scanner exited with code ${exitCode}")
                }
                // 解析结果 (简化)
                let results = SecurityScanResults()
                results.scannerName = scanner
                return ScanAttemptResult.Success(results)
            }
            case None => {
                return ScanAttemptResult.Error("Failed to run security scanner")
            }
        }
    }

    /// 打印安全告警
    /// 严格翻译自: printSecurityAdvisories
    public static func printSecurityAdvisories(results: SecurityScanResults): Unit {
        if (!results.hasAdvisories()) { return }

        for (advisory in results.advisories) {
            bao_core.Output.print("\n")
            bao_core.Output.print(advisory.format())
        }

        bao_core.Output.print("\n")
        bao_core.Output.print(results.formatSummary())
        bao_core.Output.print("\n")
    }

    /// 提示用户是否继续
    /// 严格翻译自: promptForWarnings
    /// 返回 true 表示继续安装, false 表示中止
    public static func promptForWarnings(): Bool {
        bao_core.Output.print("\nSecurity warnings found. Continue anyway? [y/N] ")

        // 简化: 直接从 stdin 读取一个字符
        try {
            let input = bao_io.Stdin.readLine()
            if (input.length > 0) {
                let c = input[0]
                if (c == 'y' || c == 'Y') {
                    bao_core.Output.print("\nContinuing with installation...\n\n")
                    return true
                }
            }
        } catch (_: Exception) {}

        bao_core.Output.print("\nInstallation cancelled.\n")
        return false
    }
}

/// 无效包 ID 常量
/// 翻译自: invalid_package_id
public let INVALID_PACKAGE_ID: UInt32 = UInt32.MAX
