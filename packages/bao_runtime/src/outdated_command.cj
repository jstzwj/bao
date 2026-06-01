// 严格翻译自: src/runtime/cli/outdated_command.zig
// bun outdated 命令 — 检查过时的依赖
package bao_runtime


import bao_core.*
import bao_install.PackageManager
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

// ============================================================================
// OutdatedCommand — bun outdated
// 对应 Bun: src/runtime/cli/outdated_command.zig
// ============================================================================

/// 过时信息
public class OutdatedInfo {
    public var packageId: PackageID
    public var depId: DependencyID
    public var workspacePkgId: PackageID
    public var isCatalog: Bool

    public init(packageId: PackageID, depId: DependencyID, workspacePkgId: PackageID, isCatalog: Bool) {
        this.packageId = packageId
        this.depId = depId
        this.workspacePkgId = workspacePkgId
        this.isCatalog = isCatalog
    }
}

/// 包版本信息
/// 包版本信息
public class PackageVersionInfo {
    public var name: String
    public var current: String
    public var wanted: String
    public var latest: String
    public var depType: String
    public init() {
        this.name = ""
        this.current = ""
        this.wanted = ""
        this.latest = ""
        this.depType = ""
    }
}

public class OutdatedCommand {
    /// 执行命令
    public static func exec(ctx: CommandContext): Unit {
        Output.prettyln("bao outdated - not yet implemented")
    }

    /// 核心过时检查逻辑
    static func outdated(ctx: CommandContext, originalCwd: String, manager: PackageManager): Unit {
        // TODO: implement with lockfile/PackageManager APIs
    }

    /// 查询最新版本
    static func queryLatestVersions(
        ctx: CommandContext,
        manager: PackageManager,
        packages: HashMap<String, PackageVersionInfo>
    ): Unit {
        // TODO: implement with HTTP registry queries
    }

    /// JSON 输出
    static func printJsonOutput(outdated: ArrayList<PackageVersionInfo>): Unit {
        // TODO: implement
    }
}
