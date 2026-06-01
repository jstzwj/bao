// CLI stub types - placeholder definitions for CLI command files
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// Type aliases
// ============================================================================

public type PackageID = String
public type DependencyID = String  
public type DotEnvLoader = HashMap<String, String>
public type TimeInstant = Int64
public type SpawnProcess = Int64
public type FilterSet = ArrayList<String>
public type SigInfo = Int64
public type JsonValue = String
public type JsonExpr = String
public type SemverVersion = String
public type SemverQueryGroup = String

// ============================================================================
// Stub classes (top-level, no nesting)
// ============================================================================

public class CLIReporter {
    public func write(msg: String): Unit { print(msg) }
}

public type CommandLineReporter = CLIReporter

public class PM {
    public var allocator: Allocator
    public init(allocator: Allocator) { this.allocator = allocator }
}

public type PackageManager = PM

public class LoggerStub {
    public init() {}
}

public type Logger = LoggerStub

public class LoggerLogStub {
    public static func `init`(allocator: Allocator): LoggerLogStub { LoggerLogStub() }
}

public type LoggerLog = LoggerLogStub

public class Src {
    public var contents: String
    public init(contents: String) { this.contents = contents }
}

public type Source = Src

public class PkgManifest {
    public var name: String
    public var version: String
    public init() { name = ""; version = "" }
    public static func parse(src: Src, allocator: Allocator): ?PkgManifest { None }
}

public type PackageManifest = PkgManifest

public enum SpawnStatus {
    | exited(Int64)
    | signaled(Int64)
    | unknown
}

public func describeStatus(status: SpawnStatus): String {
    match (status) {
        case exited(code) => "exited(${code})"
        case signaled(sig) => "signaled(${sig})"
        case unknown => "unknown"
    }
}

// Stub for updatePackageJsonAndInstall error handler
public func updatePackageJsonAndInstallCatchError(e: Exception): Unit {
    print("updatePackageJsonAndInstall error: ${e}")
}
