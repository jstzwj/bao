// 严格翻译自: src/cli/audit_command.zig
package bao_cli

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_http.*
import bao_io.*

// ============================================================================
// VulnerabilityInfo — 漏洞信息
// 严格翻译自: audit_command.zig - VulnerabilityInfo
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

// ============================================================================
// AuditPackageInfo — 漏洞包信息
// 严格翻译自: audit_command.zig - PackageInfo
// ============================================================================

/// 漏洞包信息
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

// ============================================================================
// DependencyPath — 依赖路径
// 严格翻译自: audit_command.zig - PackageInfo.DependencyPath
// ============================================================================

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

// ============================================================================
// AuditResult — 审计结果
// 严格翻译自: audit_command.zig - AuditResult
// ============================================================================

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

// ============================================================================
// PackagesForAuditResult — 审计包收集结果
// ============================================================================

/// 审计包收集结果
public class PackagesForAuditResult {
    public var auditBody: String
    public var skippedPackages: ArrayList<String>

    public init(auditBody: String, skippedPackages: ArrayList<String>) {
        this.auditBody = auditBody
        this.skippedPackages = skippedPackages
    }
}

// ============================================================================
// AuditCommand — 审计命令
// 严格翻译自: audit_command.zig - AuditCommand
// ============================================================================

/// 审计命令: 检查依赖安全漏洞
/// 对应 Bun: AuditCommand
public class AuditCommand {
    /// 执行命令
    /// 对应 Bun: AuditCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        let cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.audit)

        let initResult = PackageManager.`init`(ctx, cli, Subcommand.audit)
        let (manager, _) = match (initResult) {
            case Some((pm, dir)) => (pm, dir)
            case None =>
                // Missing package.json
                let cwd = OS.getcwd()
                if (cwd.size > 0) {
                    Output.errGeneric("No package.json was found for directory \"${cwd}\"")
                } else {
                    Output.errGeneric("No package.json was found")
                }
                Output.note("Run \"bao init\" to initialize a project")
                Global.exit(1)
        }

        let auditLevelOpt = cli.auditLevel
        let jsonOutput = cli.jsonOutput
        let prodOnly = cli.production
        let ignoreList = cli.auditIgnoreList

        let code = audit(ctx, manager, jsonOutput, auditLevelOpt, prodOnly, ignoreList)
        Global.exit(code)
    }

    /// 执行审计
    /// 对应 Bun: AuditCommand.audit()
    /// 返回退出码: 0 表示无漏洞, 1 表示发现漏洞
    public static func audit(
        ctx: CommandContext,
        pm: PackageManager,
        jsonOutput: Bool,
        auditLevel: ?AuditLevel,
        auditProdOnly: Bool,
        ignoreList: ArrayList<String>
    ): Int64 {
        Output.prettyErrorln("bao audit v${Global.PACKAGE_JSON_VERSION_WITH_SHA}")
        Output.flush()

        // 加载 lockfile
        let lockfileReader = Lockfile()
        let loadResult = lockfileReader.readFromCwd()
        let packages = match (loadResult) {
            case Some(pkgs) => pkgs
            case None =>
                Output.errGeneric("Lockfile not found. Run 'bao install' first.")
                return 1
        }

        // 构建依赖树
        let dependencyTree = buildDependencyTree(packages)

        // 收集需要审计的包
        let packagesResult = collectPackagesForAudit(packages, pm, auditProdOnly)

        // 发送审计请求到 npm advisory API
        let responseText = sendAuditRequest(packagesResult.auditBody, pm)

        if (jsonOutput) {
            // JSON 模式: 直接输出响应
            Output.print("${responseText}\n")

            if (responseText.size > 0) {
                let parser = PkgJsonParser()
                let json = parser.parse(responseText)
                match (json) {
                    case Some(root) =>
                        match (PkgJsonHelper.getField(root, "error")) {
                            case Some(_) =>
                                Output.prettyErrorln("error: audit request failed to parse json. Is the registry down?")
                                return 1
                            case None => ()
                        }
                        // 检查是否有漏洞
                        return if (hasVulnerabilities(root)) { Int64(1) } else { Int64(0) }
                    case None =>
                        Output.prettyErrorln("error: audit response failed to parse")
                        return 1
                }
            }

            return 0
        } else if (responseText.size > 0) {
            let exitCode = printEnhancedAuditReport(
                responseText, packages, dependencyTree, auditLevel, ignoreList
            )

            printSkippedPackages(packagesResult.skippedPackages)

            return exitCode
        } else {
            Output.prettyln("<green>No vulnerabilities found<r>")

            printSkippedPackages(packagesResult.skippedPackages)

            return 0
        }
    }

    // ========================================================================
    // 依赖树构建
    // 对应 Bun: buildDependencyTree()
    // ========================================================================

    /// 构建依赖树
    /// 翻译自: buildDependencyTree — 建立 包名 -> 被依赖者列表 映射
    private static func buildDependencyTree(packages: ArrayList<LockfilePackage>): HashMap<String, ArrayList<String>> {
        let dependencyTree = HashMap<String, ArrayList<String>>()

        for (pkg in packages) {
            let packageName = pkg.name
            if (packageName.size == 0) { continue }

            // 合并所有依赖
            let allDeps = HashMap<String, String>()
            for (depName in pkg.dependencies.keys()) {
                match (pkg.dependencies.get(depName)) {
                    case Some(v) => allDeps.put(depName, v)
                    case None => ()
                }
            }
            for (depName in pkg.devDependencies.keys()) {
                match (pkg.devDependencies.get(depName)) {
                    case Some(v) => allDeps.put(depName, v)
                    case None => ()
                }
            }
            for (depName in pkg.optionalDependencies.keys()) {
                match (pkg.optionalDependencies.get(depName)) {
                    case Some(v) => allDeps.put(depName, v)
                    case None => ()
                }
            }

            for (depName in allDeps.keys()) {
                // 查找此依赖名在 packages 中的对应包
                let resolvedName = depName
                match (dependencyTree.get(resolvedName)) {
                    case Some(list) => list.append(packageName)
                    case None =>
                        let list = ArrayList<String>()
                        list.append(packageName)
                        dependencyTree.put(resolvedName, list)
                }
            }
        }

        return dependencyTree
    }

    // ========================================================================
    // 包收集
    // 对应 Bun: collectPackagesForAudit()
    // ========================================================================

    /// 收集需要审计的包
    /// 翻译自: collectPackagesForAudit — 构建 { "pkg": ["v1", "v2"] } JSON body
    private static func collectPackagesForAudit(
        packages: ArrayList<LockfilePackage>,
        pm: PackageManager,
        prodOnly: Bool
    ): PackagesForAuditResult {
        let skippedPackages = ArrayList<String>()
        let packageVersions = HashMap<String, ArrayList<String>>()

        // 如果是 prod 模式, 收集生产依赖集合
        var prodSet: HashMap<String, Unit> = HashMap<String, Unit>()
        if (prodOnly) {
            prodSet = buildProductionPackageSet(packages)
        }

        for (i in 0..packages.size) {
            let pkg = packages[Int64(i)]
            let name = pkg.name
            let version = pkg.version
            if (name.size == 0 || version.size == 0) { continue }

            // 检查是否是 npm 包
            let res = pkg.resolution
            if (!res.contains("@") && !res.contains("npm")) { continue }

            // 检查 scope
            let packageScope = pm.scopeForPackageName(name)
            let defaultScope = NpmRegistryScope()
            if (packageScope.urlHash != defaultScope.urlHash) {
                skippedPackages.append(name)
                continue
            }

            // prod 模式过滤
            if (prodOnly) {
                match (prodSet.get(name)) {
                    case Some(_) => ()  // 包含
                    case None => continue  // 跳过
                }
            }

            // 收集版本
            match (packageVersions.get(name)) {
                case Some(versions) =>
                    var exists = false
                    for (v in versions) {
                        if (v == version) { exists = true; break }
                    }
                    if (!exists) { versions.append(version) }
                case None =>
                    let versions = ArrayList<String>()
                    versions.append(version)
                    packageVersions.put(name, versions)
            }
        }

        // 构建 JSON body
        let sb = StringBuilder()
        sb.append("{")
        var first = true
        for (name in packageVersions.keys()) {
            match (packageVersions.get(name)) {
                case Some(versions) =>
                    if (!first) { sb.append(",") }
                    first = false
                    sb.append("\"${name}\":[")
                    var vFirst = true
                    for (v in versions) {
                        if (!vFirst) { sb.append(",") }
                        vFirst = false
                        sb.append("\"${v}\"")
                    }
                    sb.append("]")
                case None => ()
            }
        }
        sb.append("}")

        return PackagesForAuditResult(sb.toString(), skippedPackages)
    }

    /// 构建生产依赖集合
    /// 翻译自: buildProductionPackageSet — BFS 收集所有生产依赖
    private static func buildProductionPackageSet(packages: ArrayList<LockfilePackage>): HashMap<String, Unit> {
        let prodSet = HashMap<String, Unit>()
        let queue = ArrayList<String>()

        // 从根包的直接生产依赖开始
        if (packages.size > 0) {
            let rootPkg = packages[Int64(0)]
            for (depName in rootPkg.dependencies.keys()) {
                prodSet.put(depName, Unit())
                queue.append(depName)
            }
        }

        // BFS 遍历
        var idx = 0
        while (idx < queue.size) {
            let currentName = queue[Int64(idx)]
            idx += 1

            // 查找此包
            for (i in 0..packages.size) {
                let pkg = packages[Int64(i)]
                if (pkg.name != currentName) { continue }

                // 遍历其生产依赖
                for (depName in pkg.dependencies.keys()) {
                    match (prodSet.get(depName)) {
                        case Some(_) => ()
                        case None =>
                            prodSet.put(depName, Unit())
                            queue.append(depName)
                    }
                }
                break
            }
        }

        return prodSet
    }

    // ========================================================================
    // 发送审计请求
    // 对应 Bun: sendAuditRequest()
    // ========================================================================

    /// 发送审计请求到 npm advisory API
    /// 翻译自: sendAuditRequest — POST to /-/npm/v1/security/advisories/bulk
    private static func sendAuditRequest(body: String, pm: PackageManager): String {
        let scope = pm.options.scope
        let registryUrl = scope.url

        // 去掉尾部斜杠
        var baseUrl = registryUrl
        if (baseUrl.endsWith("/")) {
            baseUrl = baseUrl[..baseUrl.size - 1]
        }

        let auditUrl = "${baseUrl}/-/npm/v1/security/advisories/bulk"

        // 构建 FetchOptions
        let options = FetchOptions()
        options.method = "POST"
        options.body = Some(body)
        let headers = Headers()
        headers.set("accept", "application/json")
        headers.set("content-type", "application/json")
        options.headers = headers

        // 认证
        if (scope.token.size > 0) {
            headers.set("authorization", "Bearer ${scope.token}")
        } else if (scope.auth.size > 0) {
            headers.set("authorization", "Basic ${scope.auth}")
        }

        let response = HttpClient.fetch(auditUrl, options)
        if (response.status >= Int64(400)) {
            Output.prettyErrorln("error: audit request failed (status ${response.status})")
            return ""
        }

        return response.text()
    }

    // ========================================================================
    // 打印审计报告
    // 对应 Bun: printEnhancedAuditReport()
    // ========================================================================

    /// 打印增强的审计报告
    /// 翻译自: printEnhancedAuditReport — 解析响应, 统计漏洞, 打印报告
    private static func printEnhancedAuditReport(
        responseText: String,
        packages: ArrayList<LockfilePackage>,
        dependencyTree: HashMap<String, ArrayList<String>>,
        auditLevel: ?AuditLevel,
        ignoreList: ArrayList<String>
    ): Int64 {
        let parser = PkgJsonParser()
        let json = parser.parse(responseText)
        match (json) {
            case Some(root) =>
                // 检查是否是空对象
                match (root) {
                    case JsonValue.Object(obj) =>
                        if (obj.size == 0) {
                            Output.prettyln("<green>No vulnerabilities found<r>")
                            return 0
                        }
                    case _ => ()
                }

                var auditResult = AuditResult()
                var lowCount: Int64 = 0
                var moderateCount: Int64 = 0
                var highCount: Int64 = 0
                var criticalCount: Int64 = 0

                // 解析漏洞
                match (root) {
                    case JsonValue.Object(properties) =>
                        for (packageName in properties.keys()) {
                            match (properties.get(packageName)) {
                                case Some(JsonValue.Array(vulns)) =>
                                    for (vuln in vulns) {
                                        let vulnerability = parseVulnerability(packageName, vuln)

                                        // 检查审计级别过滤
                                        match (auditLevel) {
                                            case Some(level) =>
                                                if (!level.shouldIncludeSeverity(vulnerability.severity)) {
                                                    continue
                                                }
                                            case None => ()
                                        }

                                        // 检查忽略列表
                                        if (ignoreList.size > 0) {
                                            var shouldIgnore = false
                                            for (ignoredCve in ignoreList) {
                                                if (vulnerability.id == ignoredCve ||
                                                    vulnerability.url.contains(ignoredCve)) {
                                                    shouldIgnore = true
                                                    break
                                                }
                                            }
                                            if (shouldIgnore) { continue }
                                        }

                                        // 统计
                                        if (vulnerability.severity == "low") {
                                            lowCount += 1
                                        } else if (vulnerability.severity == "moderate") {
                                            moderateCount += 1
                                        } else if (vulnerability.severity == "high") {
                                            highCount += 1
                                        } else if (vulnerability.severity == "critical") {
                                            criticalCount += 1
                                        } else {
                                            moderateCount += 1
                                        }

                                        auditResult.allVulnerabilities.append(vulnerability)
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }

                // 为每个漏洞包构建依赖路径
                for (vulnerability in auditResult.allVulnerabilities) {
                    let paths = findDependencyPaths(
                        vulnerability.packageName, dependencyTree, packages
                    )

                    match (auditResult.vulnerablePackages.get(vulnerability.packageName)) {
                        case Some(pkgInfo) =>
                            pkgInfo.vulnerabilities.append(vulnerability)
                        case None =>
                            let pkgInfo = AuditPackageInfo()
                            pkgInfo.name = vulnerability.packageName
                            pkgInfo.version = vulnerability.vulnerableVersions
                            pkgInfo.vulnerabilities.append(vulnerability)
                            pkgInfo.dependents = paths
                            auditResult.vulnerablePackages.put(vulnerability.packageName, pkgInfo)
                    }
                }

                // 打印每个漏洞包
                for (pkgName in auditResult.vulnerablePackages.keys()) {
                    match (auditResult.vulnerablePackages.get(pkgName)) {
                        case Some(pkgInfo) =>
                            if (pkgInfo.vulnerabilities.size == 0) { continue }

                            let mainVuln = pkgInfo.vulnerabilities[Int64(0)]

                            if (mainVuln.vulnerableVersions.size > 0) {
                                Output.prettyln("<red>${mainVuln.packageName}<r>  ${mainVuln.vulnerableVersions}")
                            } else {
                                Output.prettyln("<red>${mainVuln.packageName}<r>")
                            }

                            // 打印依赖路径
                            for (depPath in pkgInfo.dependents) {
                                if (depPath.path.size > 1) {
                                    if (depPath.path[Int64(0)].startsWith("workspace:")) {
                                        let vulnerablePkg = depPath.path[depPath.path.size - 1]
                                        let workspacePart = depPath.path[Int64(0)]
                                        Output.prettyln("  <d>${workspacePart} > <red>${vulnerablePkg}<r>")
                                    } else {
                                        let vulnerablePkg = depPath.path[Int64(0)]
                                        var pathParts = ArrayList<String>()
                                        for (i in 1..depPath.path.size) {
                                            pathParts.append(depPath.path[Int64(i)])
                                        }
                                        var pathStr = ""
                                        var pi = 0
                                        for (p in pathParts) {
                                            if (pi > 0) { pathStr = "${pathStr} > " }
                                            pathStr = "${pathStr}${p}"
                                            pi += 1
                                        }
                                        Output.prettyln("  <d>${pathStr} > <red>${vulnerablePkg}<r>")
                                    }
                                } else {
                                    Output.prettyln("  <d>(direct dependency)<r>")
                                }
                            }

                            // 打印每个漏洞详情
                            for (vuln in pkgInfo.vulnerabilities) {
                                if (vuln.title.size > 0) {
                                    if (vuln.severity == "critical") {
                                        Output.prettyln("  <red>critical<d>:<r> ${vuln.title} - <d>${vuln.url}<r>")
                                    } else if (vuln.severity == "high") {
                                        Output.prettyln("  <red>high<d>:<r> ${vuln.title} - <d>${vuln.url}<r>")
                                    } else if (vuln.severity == "moderate") {
                                        Output.prettyln("  <yellow>moderate<d>:<r> ${vuln.title} - <d>${vuln.url}<r>")
                                    } else {
                                        Output.prettyln("  <cyan>low<d>:<r> ${vuln.title} - <d>${vuln.url}<r>")
                                    }
                                }
                            }

                            Output.prettyln("")
                        case None => ()
                    }
                }

                // 打印摘要
                let total = lowCount + moderateCount + highCount + criticalCount
                if (total > 0) {
                    Output.pretty("<b>${total} vulnerabilities<r> (")

                    var hasPrevious = false
                    if (criticalCount > 0) {
                        Output.pretty("<red><b>${criticalCount} critical<r>")
                        hasPrevious = true
                    }
                    if (highCount > 0) {
                        if (hasPrevious) { Output.pretty(", ") }
                        Output.pretty("<red>${highCount} high<r>")
                        hasPrevious = true
                    }
                    if (moderateCount > 0) {
                        if (hasPrevious) { Output.pretty(", ") }
                        Output.pretty("<yellow>${moderateCount} moderate<r>")
                        hasPrevious = true
                    }
                    if (lowCount > 0) {
                        if (hasPrevious) { Output.pretty(", ") }
                        Output.pretty("<cyan>${lowCount} low<r>")
                    }
                    Output.prettyln(")")

                    Output.prettyln("")
                    Output.prettyln("To update all dependencies to the latest compatible versions:")
                    Output.prettyln("  <green>bao update<r>")
                    Output.prettyln("")
                    Output.prettyln("To update all dependencies to the latest versions (including breaking changes):")
                    Output.prettyln("  <green>bao update --latest<r>")
                    Output.prettyln("")

                    return 1
                }

                return 0
            case None =>
                Output.print("${responseText}\n")
                return 1
        }
    }

    // ========================================================================
    // 解析漏洞
    // 对应 Bun: parseVulnerability()
    // ========================================================================

    /// 解析单个漏洞对象
    private static func parseVulnerability(packageName: String, vulnJson: JsonValue): VulnerabilityInfo {
        let vulnerability = VulnerabilityInfo()
        vulnerability.packageName = packageName

        match (vulnJson) {
            case JsonValue.Object(props) =>
                for (field in props.keys()) {
                    match (props.get(field)) {
                        case Some(JsonValue.Str(value)) =>
                            if (field == "severity") {
                                vulnerability.severity = value
                            } else if (field == "title") {
                                vulnerability.title = value
                            } else if (field == "url") {
                                vulnerability.url = value
                            } else if (field == "vulnerable_versions") {
                                vulnerability.vulnerableVersions = value
                            } else if (field == "id") {
                                vulnerability.id = value
                            }
                        case Some(JsonValue.Num(numValue)) =>
                            if (field == "id") {
                                vulnerability.id = "${Int64(numValue)}"
                            }
                        case _ => ()
                    }
                }
            case _ => ()
        }

        return vulnerability
    }

    // ========================================================================
    // 查找依赖路径
    // 对应 Bun: findDependencyPaths()
    // ========================================================================

    /// 查找依赖路径
    /// 翻译自: findDependencyPaths — BFS 查找从 root 到目标包的路径
    private static func findDependencyPaths(
        targetPackage: String,
        dependencyTree: HashMap<String, ArrayList<String>>,
        packages: ArrayList<LockfilePackage>
    ): ArrayList<DependencyPath> {
        let paths = ArrayList<DependencyPath>()

        // 检查是否是直接依赖
        if (packages.size > 0) {
            let rootPkg = packages[Int64(0)]
            let allRootDeps = HashMap<String, String>()
            for (name in rootPkg.dependencies.keys()) {
                match (rootPkg.dependencies.get(name)) {
                    case Some(v) => allRootDeps.put(name, v)
                    case None => ()
                }
            }
            for (name in rootPkg.devDependencies.keys()) {
                match (rootPkg.devDependencies.get(name)) {
                    case Some(v) => allRootDeps.put(name, v)
                    case None => ()
                }
            }
            for (name in rootPkg.optionalDependencies.keys()) {
                match (rootPkg.optionalDependencies.get(name)) {
                    case Some(v) => allRootDeps.put(name, v)
                    case None => ()
                }
            }
            for (name in rootPkg.peerDependencies.keys()) {
                match (rootPkg.peerDependencies.get(name)) {
                    case Some(v) => allRootDeps.put(name, v)
                    case None => ()
                }
            }

            match (allRootDeps.get(targetPackage)) {
                case Some(_) =>
                    let directPath = DependencyPath()
                    directPath.path.append(targetPackage)
                    directPath.isDirect = true
                    paths.append(directPath)
                case None => ()
            }

            // 检查 workspace 依赖
            for (i in 1..packages.size) {
                let pkg = packages[Int64(i)]
                if (!pkg.resolution.contains("@workspace:")) { continue }
                let wsName = pkg.name

                let wsDeps = HashMap<String, String>()
                for (name in pkg.dependencies.keys()) {
                    match (pkg.dependencies.get(name)) {
                        case Some(v) => wsDeps.put(name, v)
                        case None => ()
                    }
                }
                for (name in pkg.devDependencies.keys()) {
                    match (pkg.devDependencies.get(name)) {
                        case Some(v) => wsDeps.put(name, v)
                        case None => ()
                    }
                }

                match (wsDeps.get(targetPackage)) {
                    case Some(_) =>
                        let workspacePath = DependencyPath()
                        workspacePath.path.append("workspace:${wsName}")
                        workspacePath.path.append(targetPackage)
                        workspacePath.isDirect = false
                        paths.append(workspacePath)
                    case None => ()
                }
            }
        }

        // BFS 查找间接依赖路径
        let visited = HashSet<String>()
        let parentMap = HashMap<String, String>()
        let queue = ArrayList<String>()

        match (dependencyTree.get(targetPackage)) {
            case Some(dependents) =>
                for (dep in dependents) {
                    queue.append(dep)
                    parentMap.put(dep, targetPackage)
                }
            case None => ()
        }

        var idx = 0
        while (idx < queue.size) {
            let current = queue[Int64(idx)]
            idx += 1

            if (visited.contains(current)) { continue }
            visited.put(current)

            // 检查是否是根依赖或 workspace 依赖
            var isRootDep = false
            if (packages.size > 0) {
                let rootPkg = packages[Int64(0)]
                if (rootPkg.dependencies.contains(current) ||
                    rootPkg.devDependencies.contains(current) ||
                    rootPkg.optionalDependencies.contains(current) ||
                    rootPkg.peerDependencies.contains(current)) {
                    isRootDep = true
                }
            }

            var workspaceNameForDep: ?String = None
            for (i in 1..packages.size) {
                let pkg = packages[Int64(i)]
                if (!pkg.resolution.contains("@workspace:")) { continue }
                if (pkg.dependencies.contains(current) ||
                    pkg.devDependencies.contains(current)) {
                    workspaceNameForDep = Some(pkg.name)
                    break
                }
            }

            if (isRootDep || workspaceNameForDep.isSome()) {
                let path = DependencyPath()
                path.isDirect = false

                // 回溯路径
                var trace = current
                let seenInTrace = HashSet<String>()
                var traceList = ArrayList<String>()

                var limit = 100  // 防止无限循环
                while (trace.size > 0 && limit > 0) {
                    if (seenInTrace.contains(trace)) { break }
                    seenInTrace.put(trace)
                    traceList.insert(Int64(0), trace)

                    match (parentMap.get(trace)) {
                        case Some(parent) => trace = parent
                        case None => break
                    }
                    limit -= 1
                }

                for (t in traceList) {
                    path.path.append(t)
                }

                match (workspaceNameForDep) {
                    case Some(wsName) =>
                        path.path.insert(Int64(0), "workspace:${wsName}")
                    case None => ()
                }

                paths.append(path)
            } else {
                match (dependencyTree.get(current)) {
                    case Some(dependents) =>
                        for (dep in dependents) {
                            if (!visited.contains(dep)) {
                                queue.append(dep)
                                parentMap.put(dep, current)
                            }
                        }
                    case None => ()
                }
            }
        }

        return paths
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 检查 JSON 对象是否包含漏洞
    private static func hasVulnerabilities(json: JsonValue): Bool {
        match (json) {
            case JsonValue.Object(obj) =>
                if (obj.size == 0) { return false }
                // 检查是否有非空数组值
                for (key in obj.keys()) {
                    match (obj.get(key)) {
                        case Some(JsonValue.Array(arr)) =>
                            if (arr.size > 0) { return true }
                        case _ => ()
                    }
                }
                return false
            case _ => return false
        }
    }

    /// 打印跳过的包
    /// 对应 Bun: printSkippedPackages()
    private static func printSkippedPackages(skippedPackages: ArrayList<String>): Unit {
        if (skippedPackages.size > 0) {
            Output.pretty("<d>Skipped<r> ")
            for ((i, pkgName) in skippedPackages.iterator().indexed()) {
                if (i > 0) { Output.pretty(", ") }
                Output.pretty("${pkgName}")
            }

            if (skippedPackages.size > 1) {
                Output.prettyln(" <d>because they do not come from the default registry<r>")
            } else {
                Output.prettyln(" <d>because it does not come from the default registry<r>")
            }

            Output.prettyln("")
        }
    }
}
