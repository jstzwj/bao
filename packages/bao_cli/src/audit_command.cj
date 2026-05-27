package bao_cli

import bao_core.*
import bao_collections.*

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

public class DependencyPath {
    public var path: ArrayList<String>
    public var isDirect: Bool

    public init() {
        path = ArrayList<String>()
        isDirect = false
    }
}

public enum AuditLevel {
    | Low
    | Moderate
    | High
    | Critical

    public func shouldIncludeSeverity(severity: String): Bool {
        match (this) {
            case AuditLevel.Low => true
            case AuditLevel.Moderate => severity != "low"
            case AuditLevel.High => severity == "high" || severity == "critical"
            case AuditLevel.Critical => severity == "critical"
        }
    }

    public static func fromString(s: String): ?AuditLevel {
        match (s) {
            case "low" => Some(AuditLevel.Low)
            case "moderate" => Some(AuditLevel.Moderate)
            case "high" => Some(AuditLevel.High)
            case "critical" => Some(AuditLevel.Critical)
            case _ => None
        }
    }
}

public class PackagesForAuditResult {
    public var auditBody: String
    public var skippedPackages: ArrayList<String>

    public init(auditBody: String, skippedPackages: ArrayList<String>) {
        this.auditBody = auditBody
        this.skippedPackages = skippedPackages
    }
}

public class AuditCommand {
    public static func exec(ctx: CommandContext): Unit {
        println("bao audit: not yet implemented")
    }

    public static func audit(
        ctx: CommandContext,
        pm: PackageManager,
        jsonOutput: Bool,
        auditLevel: ?AuditLevel,
        auditProdOnly: Bool,
        ignoreList: ArrayList<String>
    ): Int64 {
        println("bao audit: not yet implemented")
        return 0
    }
}
