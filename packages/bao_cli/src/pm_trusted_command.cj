// 严格翻译自: src/cli/pm_trusted_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PmTrustedCommand — 信任管理命令
// 严格翻译自: src/cli/pm_trusted_command.zig
//
// DefaultTrustedCommand, UntrustedCommand, TrustCommand
// ============================================================================

/// pm trust 命令: 管理受信任的生命周期脚本
/// 对应 Bun: TrustCommand / DefaultTrustedCommand
public class PmTrustedCommand {
    /// 执行 trust 命令
    /// 对应 Bun: TrustCommand.exec()
    public static func execTrust(ctx: CommandContext, pm: PackageManager): Unit {
        val positionals = ctx.positionals
        if (positionals.size < 1) {
            // trust all packages in the lockfile
            trustAll(ctx, pm)
            return
        }

        // trust specific packages
        for (i in 0..positionals.size) {
            val packageName = positionals[i]
            trustPackage(ctx, pm, packageName)
        }
    }

    /// 执行 untrusted 命令: 列出不受信任的包
    /// 对应 Bun: UntrustedCommand.exec()
    public static func execUntrusted(ctx: CommandContext, pm: PackageManager): Unit {
        val loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        PackageManagerCommand.handleLoadLockfileErrors(loadLockfile, pm)

        val packages = pm.lockfile.packages
        var hasUntrusted = false

        for (pkgIdx in 0..packages.length) {
            val pkgName = packages.getName(pkgIdx)
            if (pkgName.length == 0) {
                continue
            }

            val resolution = packages.getResolution(pkgIdx)
            if (resolution.tag != ResolutionTag.npm) {
                continue
            }

            // 检查是否有 lifecycle 脚本
            val hasScripts = packages.hasLifecycleScripts(pkgIdx)
            if (hasScripts && !isTrusted(pkgName)) {
                if (!hasUntrusted) {
                    Output.prettyLn("Untrusted packages with lifecycle scripts:")
                    hasUntrusted = true
                }
                val version = resolution.formatVersion()
                Output.prettyLn("  ${pkgName}@${version}")
            }
        }

        if (!hasUntrusted) {
            Output.prettyLn("All packages with lifecycle scripts are trusted")
        }
    }

    /// 信任所有包
    /// 对应 Bun: DefaultTrustedCommand
    private static func trustAll(ctx: CommandContext, pm: PackageManager): Unit {
        val loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        PackageManagerCommand.handleLoadLockfileErrors(loadLockfile, pm)

        val packages = pm.lockfile.packages
        var count = 0

        for (pkgIdx in 0..packages.length) {
            val pkgName = packages.getName(pkgIdx)
            if (pkgName.length == 0) {
                continue
            }

            val hasScripts = packages.hasLifecycleScripts(pkgIdx)
            if (hasScripts && !isTrusted(pkgName)) {
                addTrusted(pkgName)
                count += 1
            }
        }

        Output.println("Trusted ${count} package(s)")
    }

    /// 信任特定包
    private static func trustPackage(ctx: CommandContext, pm: PackageManager, packageName: String): Unit {
        addTrusted(packageName)
        Output.println("Trusted ${packageName}")
    }

    /// 检查包是否受信任
    /// 对应 Bun: trustedPackages check
    public static func isTrusted(packageName: String): Bool {
        val trustFile = BaoFile.readAllText("node_modules/.trusted")
        if (trustFile == None) {
            return false
        }
        return trustFile!!.contains(packageName)
    }

    /// 添加受信任的包
    public static func addTrusted(packageName: String): Unit {
        val trustFile = BaoFile.readAllText("node_modules/.trusted") ?: ""
        if (!trustFile.contains(packageName)) {
            val updated = if (trustFile.length > 0) {
                "${trustFile}\n${packageName}"
            } else {
                packageName
            }
            BaoFile.mkdir("node_modules", true)
            BaoFile.writeAllText("node_modules/.trusted", updated)
        }
    }

    /// 移除受信任的包
    public static func removeTrusted(packageName: String): Unit {
        val trustFile = BaoFile.readAllText("node_modules/.trusted") ?: return
        val lines = trustFile.split('\n')
        val updated = lines.filter { it != packageName && it.length > 0 }.joinToString("\n")
        BaoFile.writeAllText("node_modules/.trusted", updated)
    }

    /// 执行 lifecycle 脚本 (受信任的)
    /// 对应 Bun: 信任后执行 lifecycle 脚本
    public static func executeLifecycleScripts(pm: PackageManager, packageName: String, scripts: ArrayList<String>): Unit {
        if (!isTrusted(packageName)) {
            Output.println("Skipping lifecycle scripts for ${packageName} (not trusted)")
            return
        }

        for (script in scripts) {
            try {
                Sys.exec(script)
            } catch (e: Exception) {
                Output.println("Warning: lifecycle script failed for ${packageName}: ${e.message}")
            }
        }
    }
}
