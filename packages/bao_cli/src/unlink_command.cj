// 严格翻译自: src/cli/unlink_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// UnlinkCommand — unlink 命令
// 严格翻译自: src/cli/unlink_command.zig
//
// 取消全局链接的包, 删除符号链接和 bin 链接
// ============================================================================

/// unlink 命令
/// 对应 Bun: UnlinkCommand
public class UnlinkCommand {
    /// 执行 unlink 命令
    /// 对应 Bun: UnlinkCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        unlink(ctx)
    }

    /// unlink 内部实现
    /// 对应 Bun: unlink()
    private static func unlink(ctx: CommandContext): Unit {
        let cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.unlink)
        val (manager, originalCwd) = match (PackageManager.init(ctx, cli, Subcommand.unlink)) {
            case Some((pm, dir)) => (pm, dir)
            case None => {
                // 尝试创建 package.json
                PackageManager.attemptToCreatePackageJSON()
                let retry = PackageManager.init(ctx, cli, Subcommand.unlink)
                if (retry == None) {
                    Output.errGeneric("Failed to initialize package manager")
                    Global.exit(1)
                }
                (retry!!._0, retry!!._1)
            }
        }

        if (manager.options.shouldPrintCommandName()) {
            Output.prettyLn("<r><b>bun unlink <r><d>v${Global.packageJsonVersionWithSha}<r>\n")
        }

        if (manager.options.positionals.length == 1) {
            // bun unlink (无参数: 取消当前包的全局链接)

            var lockfile = Lockfile()
            var name = ""
            var pkg = LockfilePackage()

            // Step 1. 解析最近的 package.json 文件
            let packageJsonSource = BaoFile.readSource(manager.originalPackageJsonPath, ctx.allocator)
            if (packageJsonSource == None) {
                Output.errGeneric("failed to read \"${manager.originalPackageJsonPath}\" for unlinking")
                Global.crash()
            }

            lockfile.initEmpty(ctx.allocator)
            pkg.parse(lockfile, manager, ctx.allocator, manager.log, packageJsonSource!!, Features.folder)
            name = lockfile.str(pkg.name)

            if (name.length == 0) {
                if (manager.options.logLevel != LogLevel.silent) {
                    Output.prettyErrorLn("<r><red>error:<r> package.json missing \"name\" <d>in \"${packageJsonSource!!.path.text}\"<r>")
                }
                Global.crash()
            } else if (!Strings.isNPMPackageName(name)) {
                if (manager.options.logLevel != LogLevel.silent) {
                    Output.prettyErrorLn("<r><red>error:<r> invalid package.json name \"${name}\" <d>in \"${packageJsonSource!!.path.text}\"<r>")
                }
                Global.crash()
            }

            // Step 2. 检查全局链接目录中的符号链接
            let linkPath = Path.joinAbsStringZ(manager.globalLinkDirPath(), name)
            let statResult = Syscall.lstat(linkPath)
            if (statResult.isErr) {
                Output.prettyErrorLn("<r><green>success:<r> package \"${name}\" is not globally linked, so there's nothing to do.")
                Global.exit(0)
            } else if (!Syscall.isSymlink(statResult.value.mode)) {
                Output.prettyErrorLn("<r><green>success:<r> package \"${name}\" is not globally linked, so there's nothing to do.")
                Global.exit(0)
            }

            // Step 3. 设置全局目录
            BinLinker.ensureUmask()

            var explicitGlobalDir = ""
            if (ctx.install != None) {
                explicitGlobalDir = ctx.install!!.globalDir ?: explicitGlobalDir
            }
            manager.globalDir = Options.openGlobalDir(explicitGlobalDir)
            manager.setupGlobalDir(ctx)

            let nodeModules = manager.globalDir!!.makeOpenPath("node_modules")

            // Step 3b. 取消链接全局 bins
            if (pkg.bin.tag != BinTag.none) {
                let binLinker = BinLinker()
                binLinker.targetNodeModulesPath = nodeModules.getPath()
                binLinker.targetPackageName = name
                binLinker.bin = pkg.bin
                binLinker.globalBinPath = manager.options.binPath
                binLinker.packageName = name
                binLinker.stringBuf = lockfile.buffers.stringBytes
                binLinker.externStringBuf = lockfile.buffers.externStrings
                binLinker.unlink(true)
            }

            // 删除全局链接目录中的包
            nodeModules.deleteTree(name)

            Output.prettyLn("<r><green>success:<r> unlinked package \"${name}\"")
            Global.exit(0)
        } else {
            Output.prettyLn("<r><red>error:<r> bun unlink {packageName} not implemented yet")
            Global.crash()
        }
    }
}
