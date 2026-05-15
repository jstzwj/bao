// 严格翻译自: src/cli/audit_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// AuditCommand — 安全审计命令
// 严格翻译自: src/cli/audit_command.zig - AuditCommand struct
// ============================================================================

/// 漏洞信息
/// 对应 Bun: VulnerabilityInfo
public class VulnerabilityInfo {
    public var severity: String
    public var title: String
    public var url: String
    public var vulnerableVersions: String
    public var id: String
    public var packageName: String

    public init() {
        severity = "moderate"
        title = "Vulnerability found"
        url = ""
        vulnerableVersions = ""
        id = ""
        packageName = ""
    }
}

/// 审计结果
/// 对应 Bun: AuditResult
public class AuditResult {
    public var vulnerablePackages: HashMap<String, AuditPackageInfo>
    public var allVulnerabilities: ArrayList<VulnerabilityInfo>

    public init() {
        vulnerablePackages = HashMap<String, AuditPackageInfo>()
        allVulnerabilities = ArrayList<VulnerabilityInfo>()
    }

    public func deinit(): Unit {
        vulnerablePackages.clear()
        allVulnerabilities.clear()
    }
}

/// 包信息 (审计)
/// 对应 Bun: PackageInfo
public class AuditPackageInfo {
    public var packageId: Int64
    public var name: String
    public var version: String
    public var vulnerabilities: ArrayList<VulnerabilityInfo>
    public var dependents: ArrayList<DependencyPath>

    public init() {
        packageId = 0
        name = ""
        version = ""
        vulnerabilities = ArrayList<VulnerabilityInfo>()
        dependents = ArrayList<DependencyPath>()
    }
}

/// 依赖路径
/// 对应 Bun: PackageInfo.DependencyPath
public class DependencyPath {
    public var path: ArrayList<String>
    public var isDirect: Bool

    public init() {
        path = ArrayList<String>()
        isDirect = false
    }
}

/// 审计命令
/// 对应 Bun: AuditCommand
public class AuditCommand {
    /// 执行审计命令
    /// 对应 Bun: AuditCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        let cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.audit)
        val (manager, _) = match (PackageManager.init(ctx, cli, Subcommand.audit)) {
            case Some((pm, dir)) => (pm, dir)
            case None => {
                Output.errGeneric("No package.json was found")
                Output.note("Run \"bao init\" to initialize a project")
                Global.exit(1)
            }
        }

        let code = audit(ctx, manager, cli.jsonOutput, cli.auditLevel, cli.production, cli.auditIgnoreList)
        Global.exit(code)
    }

    /// 执行审计
    /// 返回 0 表示未发现漏洞, 1 表示发现漏洞
    /// 对应 Bun: AuditCommand.audit()
    public static func audit(
        ctx: CommandContext,
        pm: PackageManager,
        jsonOutput: Bool,
        auditLevel: ?AuditLevel,
        auditProdOnly: Bool,
        ignoreList: ArrayList<String>
    ): Int64 {
        Output.prettyError("bao audit v${Global.packageJsonVersionWithSha}\n")
        Output.flush()

        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        PackageManagerCommand.handleLoadLockfileErrors(loadLockfile, pm)

        let dependencyTree = buildDependencyTree(ctx.allocator, pm)
        let packagesResult = collectPackagesForAudit(ctx.allocator, pm, auditProdOnly)

        let responseText = sendAuditRequest(ctx.allocator, pm, packagesResult.auditBody)

        if (jsonOutput) {
            Output.write(responseText)
            Output.write("\n")
            if (responseText.length > 0) {
                let json = JsonParser.parse(responseText)
                if (json != None && json!!.isObject() && json!!.asObject().size == 0) {
                    return 0
                }
                return 1
            }
            return 0
        } else if (responseText.length > 0) {
            let exitCode = printEnhancedAuditReport(
                ctx.allocator, responseText, pm, dependencyTree, auditLevel, ignoreList
            )
            printSkippedPackages(packagesResult.skippedPackages)
            return exitCode
        } else {
            Output.prettyLn("No vulnerabilities found")
            printSkippedPackages(packagesResult.skippedPackages)
            return 0
        }
    }
}

/// 打印跳过的包
private func printSkippedPackages(skippedPackages: ArrayList<String>): Unit {
    if (skippedPackages.size > 0) {
        Output.pretty("Skipped ")
        for ((i, packageName) in skippedPackages.iterator().indexed()) {
            if (i > 0) Output.pretty(", ")
            Output.pretty(packageName)
        }
        let suffix = if (skippedPackages.size > 1) "s" else ""
        Output.prettyLn(" because ${suffix} ${suffix == "" ? "it does" : "they do"} not come from the default registry")
        Output.prettyLn("")
    }
}

/// 构建依赖树
/// 对应 Bun: buildDependencyTree()
private func buildDependencyTree(allocator: Allocator, pm: PackageManager): HashMap<String, ArrayList<String>> {
    let dependencyTree = HashMap<String, ArrayList<String>>()
    let lockfile = pm.lockfile
    let packages = lockfile.packages

    for (pkgIdx in 0..packages.length) {
        let pkgName = packages.getName(pkgIdx)
        let resolution = packages.getResolution(pkgIdx)
        if (resolution.tag != ResolutionTag.npm) {
            continue
        }

        let deps = packages.getDependencies(pkgIdx)
        let resolutions = packages.getResolutions(pkgIdx)

        for (depIdx in 0..deps.length) {
            let resolvedPkgId = resolutions[depIdx]
            if (resolvedPkgId >= packages.length) {
                continue
            }
            let resolvedName = packages.getName(resolvedPkgId)

            if (!dependencyTree.contains(resolvedName)) {
                dependencyTree.put(resolvedName, ArrayList<String>())
            }
            dependencyTree.get(resolvedName)!!.append(pkgName)
        }
    }

    return dependencyTree
}

/// 收集待审计的包
/// 对应 Bun: collectPackagesForAudit()
private func collectPackagesForAudit(allocator: Allocator, pm: PackageManager, prodOnly: Bool): PackagesForAuditResult {
    let packages = pm.lockfile.packages
    let skippedPackages = ArrayList<String>()
    let body = StringBuilder()

    body.append('{')
    var first = true

    for (pkgIdx in 0..packages.length) {
        let name = packages.getName(pkgIdx)
        let resolution = packages.getResolution(pkgIdx)

        if (resolution.tag != ResolutionTag.npm) {
            continue
        }

        let versionStr = resolution.formatVersion()
        if (!first) {
            body.append(',')
        }
        body.append("\"${name}\":[\"${versionStr}\"]")
        first = false
    }
    body.append('}')

    return PackagesForAuditResult(body.toString(), skippedPackages)
}

/// 发送审计请求
/// 对应 Bun: sendAuditRequest()
private func sendAuditRequest(allocator: Allocator, pm: PackageManager, body: String): String {
    let urlStr = "${Strings.withoutTrailingSlash(pm.options.scope.url)}/-/npm/v1/security/advisories/bulk"

    let headers = HashMap<String, String>()
    headers.put("accept", "application/json")
    headers.put("content-type", "application/json")
    headers.put("content-encoding", "gzip")

    if (pm.options.scope.token.length > 0) {
        headers.put("authorization", "Bearer ${pm.options.scope.token}")
    }

    let response = HttpClient.postSync(urlStr, headers, body)
    return response ?: ""
}

/// 解析漏洞
/// 对应 Bun: parseVulnerability()
private func parseVulnerability(allocator: Allocator, packageName: String, vuln: JsonValue): VulnerabilityInfo {
    let vulnerability = VulnerabilityInfo()
    vulnerability.packageName = packageName

    if (vuln.isObject()) {
        let props = vuln.asObject()
        for ((fieldName, value) in props) {
            if (value.isString()) {
                let fieldValue = value.asString()
                when (fieldName) {
                    case "severity" => vulnerability.severity = fieldValue
                    case "title" => vulnerability.title = fieldValue
                    case "url" => vulnerability.url = fieldValue
                    case "vulnerable_versions" => vulnerability.vulnerableVersions = fieldValue
                    case "id" => vulnerability.id = fieldValue
                }
            } else if (value.isNumber() && fieldName == "id") {
                vulnerability.id = "${value.asNumber().toInt()}"
            }
        }
    }

    return vulnerability
}

/// 打印增强的审计报告
/// 对应 Bun: printEnhancedAuditReport()
private func printEnhancedAuditReport(
    allocator: Allocator,
    responseText: String,
    pm: PackageManager,
    dependencyTree: HashMap<String, ArrayList<String>>,
    auditLevel: ?AuditLevel,
    ignoreList: ArrayList<String>
): Int64 {
    let json = JsonParser.parse(responseText)
    if (json == None) {
        Output.write(responseText)
        Output.write("\n")
        return 1
    }

    if (json!!.isObject() && json!!.asObject().size == 0) {
        Output.prettyLn("No vulnerabilities found")
        return 0
    }

    let auditResult = AuditResult()
    var lowCount: Int64 = 0
    var moderateCount: Int64 = 0
    var highCount: Int64 = 0
    var criticalCount: Int64 = 0

    if (json!!.isObject()) {
        let properties = json!!.asObject()

        for ((packageName, value) in properties) {
            if (value.isArray()) {
                for (vuln in value.asArray()) {
                    if (vuln.isObject()) {
                        let vulnerability = parseVulnerability(allocator, packageName, vuln)

                        if (auditLevel != None && !auditLevel!!.shouldIncludeSeverity(vulnerability.severity)) {
                            continue
                        }

                        var shouldIgnore = false
                        for (ignoredCve in ignoreList) {
                            if (vulnerability.id == ignoredCve || vulnerability.url.contains(ignoredCve)) {
                                shouldIgnore = true
                                break
                            }
                        }
                        if (shouldIgnore) {
                            continue
                        }

                        when (vulnerability.severity) {
                            case "low" => lowCount += 1
                            case "moderate" => moderateCount += 1
                            case "high" => highCount += 1
                            case "critical" => criticalCount += 1
                            else => moderateCount += 1
                        }

                        auditResult.allVulnerabilities.append(vulnerability)
                    }
                }
            }
        }

        // 打印漏洞信息
        for (vulnerability in auditResult.allVulnerabilities) {
            let paths = findDependencyPaths(allocator, vulnerability.packageName, dependencyTree, pm)

            let result = auditResult.vulnerablePackages.getOrPut(vulnerability.packageName, {
                let info = AuditPackageInfo()
                info.name = vulnerability.packageName
                info.version = vulnerability.vulnerableVersions
                info.dependents = paths
                info
            })
            result.vulnerabilities.append(vulnerability)
        }

        // 打印每个包的信息
        for ((_, packageInfo) in auditResult.vulnerablePackages) {
            if (packageInfo.vulnerabilities.size > 0) {
                let mainVuln = packageInfo.vulnerabilities[0]

                if (mainVuln.vulnerableVersions.length > 0) {
                    Output.prettyLn("${mainVuln.packageName}  ${mainVuln.vulnerableVersions}")
                } else {
                    Output.prettyLn("${mainVuln.packageName}")
                }

                for (path in packageInfo.dependents) {
                    if (path.path.size > 1) {
                        let first_ = path.path[0]
                        if (first_.startsWith("workspace:")) {
                            let last_ = path.path[path.path.size - 1]
                            Output.prettyLn("  ${first_} > ${last_}")
                        } else {
                            let vulnPkg = path.path[0]
                            let reversed = path.path.subList(1, path.path.size).reversed()
                            let pathStr = reversed.joinToString(" > ")
                            Output.prettyLn("  ${pathStr} > ${vulnPkg}")
                        }
                    } else {
                        Output.prettyLn("  (direct dependency)")
                    }
                }

                for (vuln in packageInfo.vulnerabilities) {
                    if (vuln.title.length > 0) {
                        when (vuln.severity) {
                            case "critical" => Output.prettyLn("  critical: ${vuln.title} - ${vuln.url}")
                            case "high" => Output.prettyLn("  high: ${vuln.title} - ${vuln.url}")
                            case "moderate" => Output.prettyLn("  moderate: ${vuln.title} - ${vuln.url}")
                            else => Output.prettyLn("  low: ${vuln.title} - ${vuln.url}")
                        }
                    }
                }

                Output.prettyLn("")
            }
        }

        let total = lowCount + moderateCount + highCount + criticalCount
        if (total > 0) {
            Output.pretty("${total} vulnerabilities (")

            var hasPrevious = false
            if (criticalCount > 0) {
                Output.pretty("${criticalCount} critical")
                hasPrevious = true
            }
            if (highCount > 0) {
                if (hasPrevious) Output.pretty(", ")
                Output.pretty("${highCount} high")
                hasPrevious = true
            }
            if (moderateCount > 0) {
                if (hasPrevious) Output.pretty(", ")
                Output.pretty("${moderateCount} moderate")
                hasPrevious = true
            }
            if (lowCount > 0) {
                if (hasPrevious) Output.pretty(", ")
                Output.pretty("${lowCount} low")
            }
            Output.prettyLn(")")

            Output.prettyLn("")
            Output.prettyLn("To update all dependencies to the latest compatible versions:")
            Output.prettyLn("  bao update")
            Output.prettyLn("")
            Output.prettyLn("To update all dependencies to the latest versions (including breaking changes):")
            Output.prettyLn("  bao update --latest")
            Output.prettyLn("")
        }

        if (total > 0) {
            return 1
        }
    } else {
        Output.write(responseText)
        Output.write("\n")
    }

    return 0
}

/// 查找依赖路径
/// 对应 Bun: findDependencyPaths()
private func findDependencyPaths(
    allocator: Allocator,
    targetPackage: String,
    dependencyTree: HashMap<String, ArrayList<String>>,
    pm: PackageManager
): ArrayList<DependencyPath> {
    let paths = ArrayList<DependencyPath>()
    let lockfile = pm.lockfile
    let packages = lockfile.packages

    // 查找直接依赖
    let rootDeps = packages.getDependencies(0)
    for (dep in rootDeps) {
        if (dep == targetPackage) {
            let directPath = DependencyPath()
            directPath.path.append(targetPackage)
            directPath.isDirect = true
            paths.append(directPath)
            break
        }
    }

    // 通过依赖树查找间接路径
    if (dependencyTree.contains(targetPackage)) {
        let dependents = dependencyTree.get(targetPackage)!!
        for (dependent in dependents) {
            let path = DependencyPath()
            path.path.append(dependent)
            path.path.append(targetPackage)
            paths.append(path)
        }
    }

    return paths
}

/// 审计包收集结果
public class PackagesForAuditResult {
    public var auditBody: String
    public var skippedPackages: ArrayList<String>

    public init(auditBody: String, skippedPackages: ArrayList<String>) {
        this.auditBody = auditBody
        this.skippedPackages = skippedPackages
    }
}
