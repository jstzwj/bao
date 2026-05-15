// 严格翻译自: src/cli/scan_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// ScanCommand — 安全扫描命令
// 严格翻译自: src/cli/scan_command.zig - ScanCommand struct
// ============================================================================

/// 安全扫描命令: 扫描 lockfile 中的依赖安全漏洞
/// 对应 Bun: ScanCommand
public class ScanCommand {
    /// 执行 scan 命令
    /// 对应 Bun: ScanCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        val cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.scan)

        val (manager, cwd) = match (PackageManager.init(ctx, cli, Subcommand.scan)) {
            case Some((pm, dir)) => (pm, dir)
            case None => {
                if (PackageManager.lastError == PackageManagerError.MissingPackageJSON) {
                    Output.errGeneric("No package.json found. 'bao pm scan' requires a lockfile to analyze dependencies.")
                    Output.note("Run \"bao install\" first to generate a lockfile")
                    Global.exit(1)
                }
                return
            }
        }

        execWithManager(ctx, manager, cwd)
    }

    /// 使用指定的 PackageManager 执行扫描
    /// 对应 Bun: ScanCommand.execWithManager()
    public static func execWithManager(ctx: CommandContext, manager: PackageManager, originalCwd: String): Unit {
        if (manager.options.securityScanner == None) {
            Output.prettyErrorLn("error: no security scanner configured")
            Output.pretty(
                "\n" +
                "To use 'bao pm scan', configure a security scanner in bunfig.toml:\n" +
                "  [install.security]\n" +
                "  scanner = \"package_name\"\n" +
                "\n" +
                "Security scanners can be npm packages that export a scanner object.\n"
            )
            Global.exit(1)
        }

        Output.prettyError("bao pm scan v${Global.packageJsonVersionWithSha}\n")
        Output.flush()

        val loadLockfile = manager.lockfile.loadFromCwd(manager, ctx.allocator, ctx.log, true)
        if (loadLockfile == LoadLockfileResult.not_found) {
            Output.errGeneric("Lockfile not found. Run 'bao install' first to generate a lockfile.")
            Global.exit(1)
        }
        if (loadLockfile == LoadLockfileResult.err) {
            Output.errGeneric("Error loading lockfile: ${loadLockfile.errorValue}")
            Global.exit(1)
        }

        val scanResults = SecurityScanner.performSecurityScanForAll(manager, ctx, originalCwd)
        if (scanResults == None) {
            Output.errGeneric("Could not perform security scan")
            Global.exit(1)
        }

        val results = scanResults!!
        SecurityScanner.printSecurityAdvisories(manager, results)

        if (results.hasAdvisories()) {
            Global.exit(1)
        } else {
            Output.pretty("<green>No advisories found<r>\n")
        }

        Global.exit(0)
    }
}
