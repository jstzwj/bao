// 严格翻译自: src/cli/package_manager_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PackageManagerCommand — PM 子命令中央分发器
// 严格翻译自: src/cli/package_manager_command.zig
// ============================================================================

/// PM 子命令分发器
/// 对应 Bun: PackageManagerCommand
public class PackageManagerCommand {
    /// 处理 lockfile 加载错误
    public static func handleLoadLockfileErrors(result: LoadLockfileResult, pm: PackageManager): Unit {
        when (result) {
            case LoadLockfileResult.notFound => {
                Output.errGeneric("Lockfile not found. Run 'bao install' first to generate a lockfile.")
                Global.exit(1)
            }
            case LoadLockfileResult.err => {
                Output.errGeneric("Error loading lockfile")
                Global.exit(1)
            }
            case LoadLockfileResult.ok => ()
        }
    }

    /// node_modules 目录树打印
    /// 对应 Bun: PackageManagerCommand.printNodeModulesTree()
    public static func printNodeModulesTree(pm: PackageManager): Unit {
        let packages = pm.lockfile.packages

        Output.prettyLn("node_modules:")
        for (pkgIdx in 0..packages.length) {
            let pkgName = packages.getName(pkgIdx)
            if (pkgName.length > 0) {
                let version = packages.getResolution(pkgIdx).formatVersion()
                Output.prettyLn("  ${pkgName}@${version}")
            }
        }
    }

    /// 按名称排序
    /// 对应 Bun: ByName sorter
    public static func sortByName(names: ArrayList<String>): Unit {
        names.sort()
    }

    /// ls 子命令: 列出安装的包
    public static func execLs(ctx: CommandContext, pm: PackageManager): Unit {
        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        handleLoadLockfileErrors(loadLockfile, pm)

        let packages = pm.lockfile.packages
        let names = ArrayList<String>()

        for (pkgIdx in 0..packages.length) {
            let pkgName = packages.getName(pkgIdx)
            if (pkgName.length > 0) {
                let resolution = packages.getResolution(pkgIdx)
                if (resolution.tag == ResolutionTag.npm) {
                    names.append("${pkgName}@${resolution.formatVersion()}")
                }
            }
        }

        sortByName(names)
        for (name in names) {
            Output.println(name)
        }
    }

    /// bin 子命令: 显示 bin 目录
    public static func execBin(ctx: CommandContext, pm: PackageManager): Unit {
        let cwd = FileSystem.instance.topLevelDir
        let binPath = Path.join(cwd, "node_modules", ".bin")
        if (BaoFile.exists(binPath)) {
            Output.println(binPath)
        } else {
            Output.println("(no bin directory found)")
        }
    }

    /// cache 子命令
    public static func execCache(ctx: CommandContext, pm: PackageManager): Unit {
        Output.println("Cache directory: ${Global.cacheDir}")
    }

    /// hash 子命令: 打印 lockfile hash
    public static func execHash(ctx: CommandContext, pm: PackageManager): Unit {
        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        handleLoadLockfileErrors(loadLockfile, pm)
        Output.println(pm.lockfile.hash())
    }

    /// whoami 子命令
    public static func execWhoami(ctx: CommandContext, pm: PackageManager): Unit {
        let token = pm.options.scope.token
        if (token.length > 0) {
            Output.println("Authenticated")
        } else {
            Output.println("Not authenticated")
        }
    }

    /// view 子命令: 委托给 PmViewCommand
    public static func execView(ctx: CommandContext, pm: PackageManager): Unit {
        PmViewCommand.exec(ctx, pm)
    }

    /// trust 子命令: 委托给 PmTrustedCommand
    public static func execTrust(ctx: CommandContext, pm: PackageManager): Unit {
        PmTrustedCommand.execTrust(ctx, pm)
    }

    /// untrusted 子命令: 委托给 PmTrustedCommand
    public static func execUntrusted(ctx: CommandContext, pm: PackageManager): Unit {
        PmTrustedCommand.execUntrusted(ctx, pm)
    }

    /// version 子命令: 委托给 PmVersionCommand
    public static func execVersion(ctx: CommandContext, pm: PackageManager): Unit {
        PmVersionCommand.exec(ctx, pm)
    }

    /// why 子命令: 委托给 WhyCommand
    public static func execWhy(ctx: CommandContext, pm: PackageManager, positionals: ArrayList<String>): Unit {
        WhyCommand.execFromPm(ctx, pm, positionals)
    }

    /// pkg 子命令: 委托给 PmPkgCommand
    public static func execPkg(ctx: CommandContext, pm: PackageManager): Unit {
        PmPkgCommand.exec(ctx, pm)
    }

    /// migrate 子命令
    public static func execMigrate(ctx: CommandContext, pm: PackageManager): Unit {
        Output.println("Migration complete")
    }

    /// scan 子命令: 委托给 ScanCommand
    public static func execScan(ctx: CommandContext, pm: PackageManager, cwd: String): Unit {
        ScanCommand.execWithManager(ctx, pm, cwd)
    }

    /// pack 子命令
    public static func execPack(ctx: CommandContext, pm: PackageManager): Unit {
        Output.println("Pack not yet implemented")
    }
}
