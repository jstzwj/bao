// 严格翻译自: src/cli/pm_trusted_command.rs
// 对应 Bun: pm_trusted_command.zig — DefaultTrustedCommand, UntrustedCommand, TrustCommand
//
// 信任管理命令: 管理受信任的生命周期脚本
// - DefaultTrustedCommand: 打印默认信任列表
// - UntrustedCommand: 列出不受信任的包及其 lifecycle 脚本
// - TrustCommand: 信任指定包并执行 lifecycle 脚本
package bao_cli

import bao_core.*
import bao_install.*
import bao_collections.*

// ============================================================================
// DefaultTrustedCommand — 打印默认信任列表
// 严格翻译自: src/cli/pm_trusted_command.rs - DefaultTrustedCommand
// ============================================================================

/// 打印默认信任的依赖列表
/// 对应 Bun: DefaultTrustedCommand.exec()
public class DefaultTrustedCommand {
    /// 执行 default-trusted 命令
    /// 对应 Bun: DefaultTrustedCommand.exec()
    public static func exec(): Unit {
        let defaultList = getDefaultTrustedDependencies()
        Output.print("Default trusted dependencies (${defaultList.size}):\n")
        for (name in defaultList) {
            Output.pretty(" <d>-<r> ${name}\n")
        }
    }

    /// 获取默认信任的依赖列表
    /// 对应 Bun: DEFAULT_TRUSTED_DEPENDENCIES_LIST
    public static func getDefaultTrustedDependencies(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("esbuild")
        list.append("node-gyp")
        list.append("node-pre-gyp")
        list.append("npm")
        list.append("core-js")
        list.append("babel-runtime")
        list.append("bufferutil")
        list.append("utf-8-validate")
        list.append("sharp")
        list.append("@prisma/client")
        list.append("@prisma/engines")
        list.append("better-sqlite3")
        return list
    }
}

// ============================================================================
// UntrustedCommand — 列出不受信任的包
// 严格翻译自: src/cli/pm_trusted_command.rs - UntrustedCommand
//
// 遍历 lockfile 中的依赖树, 找出没有信任且有 lifecycle 脚本的包
// ============================================================================

/// pm untrusted 命令: 列出不受信任的包
/// 对应 Bun: UntrustedCommand
public class UntrustedCommand {
    /// 执行 untrusted 命令
    /// 对应 Bun: UntrustedCommand.exec()
    public static func exec(ctx: CommandContext, pm: PackageManager, args: ArrayList<String>): Unit {
        Output.prettyError("<r><b>bao pm untrusted <r><d>v${Global.packageJsonVersionWithSha}<r>\n\n")
        Output.flush()

        let logLevel = pm.options.logLevel
        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        PackageManagerCommand.handleLoadLockfileErrors(loadLockfile, logLevel)

        // 如果 lockfile 需要更新
        if (loadLockfile.serializerResult != None && loadLockfile.serializerResult!!.packagesNeedUpdate) {
            updateLockfileIfNeeded(pm, loadLockfile)
        }

        let lockfile = pm.lockfile
        let packages = lockfile.packages
        let scripts = packages.itemsScripts()
        let resolutions = packages.itemsResolution()
        let buf = lockfile.buffers.stringBytes

        var untrustedDepIds = HashSet<Int64>()

        // 遍历依赖, 查找不受信任的
        for (i in 0..lockfile.buffers.dependencies.length) {
            let depId = i
            let packageId = lockfile.buffers.resolutions[depId]
            if (packageId == INVALID_PACKAGE_ID) {
                continue
            }

            let alias = lockfile.buffers.dependencies[depId].name.slice(buf)
            let resolution = resolutions[packageId]
            if (!lockfile.hasTrustedDependency(alias, resolution)) {
                untrustedDepIds.add(depId)
            }
        }

        if (untrustedDepIds.size == 0) {
            printZeroUntrustedDependenciesFound()
            return
        }

        // 遍历 node_modules 树, 收集不受信任的包的脚本
        var untrustedDepsWithScripts = ArrayList<UntrustedDepInfo>()

        let treeIterator = TreeIterator.init(lockfile)
        var nodeModulesPath = AutoAbsPath.initTopLevelDir()

        while (true) {
            let nodeModules = treeIterator.next()
            if (nodeModules == None) {
                break
            }
            let nm = nodeModules!!
            let nmSaved = nodeModulesPath.length
            nodeModulesPath.append(nm.relativePath)

            for (depId in nm.dependencies) {
                if (!untrustedDepIds.contains(depId)) {
                    continue
                }
                let dep = lockfile.buffers.dependencies[depId]
                let alias = dep.name.slice(buf)
                let packageId = lockfile.buffers.resolutions[depId]

                if (packageId >= packages.length) {
                    continue
                }

                let resolution = resolutions[packageId]
                let packageScripts = scripts[packageId]

                let folderSaved = nodeModulesPath.length
                nodeModulesPath.append(alias)

                let scriptsList = packageScripts.getList(
                    ctx.log, lockfile, nodeModulesPath, alias, resolution
                )
                nodeModulesPath.setLength(folderSaved)

                if (scriptsList != None && scriptsList!!.total > 0) {
                    untrustedDepsWithScripts.append(UntrustedDepInfo(
                        depId: depId,
                        packageId: packageId,
                        scriptsList: scriptsList!!
                    ))
                }
            }

            nodeModulesPath.setLength(nmSaved)
        }

        if (untrustedDepsWithScripts.size == 0) {
            printZeroUntrustedDependenciesFound()
            return
        }

        // 打印不受信任的包的脚本
        for (info in untrustedDepsWithScripts) {
            let resolution = resolutions[info.packageId]
            info.scriptsList.printScripts(resolution, buf, PrintFormat.untrusted)
            Output.pretty("\n")
        }

        Output.pretty(
            "These dependencies had their lifecycle scripts blocked during install.\n" +
            " \n" +
            " If you trust them and wish to run their scripts, use <d>`<r><blue>bao pm trust<r><d>`<r>.\n"
        )
    }

    private static func printZeroUntrustedDependenciesFound(): Unit {
        Output.pretty(
            "Found <b>0<r> untrusted dependencies with scripts.\n" +
            " \n" +
            " This means all packages with scripts are in \"trustedDependencies\" or none of your dependencies have scripts.\n" +
            " \n" +
            " For more information, visit <magenta>https://bao.dev/docs/install/lifecycle#trusteddependencies<r>\n"
        )
    }
}

/// 不受信任依赖的信息
public class UntrustedDepInfo {
    public var depId: Int64
    public var packageId: Int64
    public var scriptsList: ScriptsList

    public init(depId: Int64, packageId: Int64, scriptsList: ScriptsList) {
        this.depId = depId
        this.packageId = packageId
        this.scriptsList = scriptsList
    }
}

// ============================================================================
// TrustCommand — 信任包并执行 lifecycle 脚本
// 严格翻译自: src/cli/pm_trusted_command.rs - TrustCommand
//
// 遍历 node_modules 树, 按深度分组, 从最深层开始执行 lifecycle 脚本
// 然后更新 package.json 和 lockfile 的 trustedDependencies
// ============================================================================

/// pm trust 命令: 信任包并执行 lifecycle 脚本
/// 对应 Bun: TrustCommand
public class TrustCommand {
    /// 执行 trust 命令
    /// 对应 Bun: TrustCommand.exec()
    public static func exec(ctx: CommandContext, pm: PackageManager, args: ArrayList<String>): Unit {
        Output.prettyError("<r><b>bao pm trust <r><d>v${Global.packageJsonVersionWithSha}<r>\n")
        Output.flush()

        if (args.size <= 2) {
            errorExpectedArgs()
        }

        let logLevel = pm.options.logLevel
        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        PackageManagerCommand.handleLoadLockfileErrors(loadLockfile, logLevel)

        // 如果 lockfile 需要更新 (meta.has_install_script)
        if (loadLockfile.serializerResult != None && loadLockfile.serializerResult!!.packagesNeedUpdate) {
            updateLockfileIfNeeded(pm, loadLockfile)
        }

        // 收集命令行指定的包名
        var packagesToTrust = ArrayList<String>()
        var trustAll = false
        for (i in 2..args.size) {
            let arg = args[i]
            if (arg == "-a" || arg == "--all") {
                trustAll = true
            } else if (arg.length > 0 && arg[0] != '-') {
                packagesToTrust.append(arg)
            }
        }

        if (!trustAll && packagesToTrust.size == 0) {
            errorExpectedArgs()
        }

        let lockfile = pm.lockfile
        let packages = lockfile.packages
        let scripts = packages.itemsScripts()
        let resolutions = packages.itemsResolution()
        let buf = lockfile.buffers.stringBytes

        var untrustedDepIds = HashSet<Int64>()

        // 遍历依赖, 查找不受信任的
        for (i in 0..lockfile.buffers.dependencies.length) {
            let depId = i
            let packageId = lockfile.buffers.resolutions[depId]
            if (packageId == INVALID_PACKAGE_ID) {
                continue
            }
            let alias = lockfile.buffers.dependencies[depId].name.slice(buf)
            let resolution = resolutions[packageId]
            if (!lockfile.hasTrustedDependency(alias, resolution)) {
                untrustedDepIds.add(depId)
            }
        }

        if (untrustedDepIds.size == 0) {
            printErrorZeroUntrustedDependenciesFound(trustAll, packagesToTrust)
            Global.crash()
        }

        // 按深度分组收集脚本信息
        var scriptsAtDepth = HashMap<Int64, ArrayList<ScriptInfo>>()
        var packageNamesToAdd = HashSet<String>()
        var scriptsCount = 0

        let treeIterator = TreeIterator.init(lockfile)
        var nodeModulesPath = AutoAbsPath.initTopLevelDir()

        while (true) {
            let nodeModules = treeIterator.next()
            if (nodeModules == None) {
                break
            }
            let nm = nodeModules!!
            let nmSaved = nodeModulesPath.length
            nodeModulesPath.append(nm.relativePath)

            for (depId in nm.dependencies) {
                if (!untrustedDepIds.contains(depId)) {
                    continue
                }
                let dep = lockfile.buffers.dependencies[depId]
                let alias = dep.name.slice(buf)
                let packageId = lockfile.buffers.resolutions[depId]

                if (packageId >= packages.length) {
                    continue
                }

                let resolution = resolutions[packageId]
                let packageScripts = scripts[packageId]

                let folderSaved = nodeModulesPath.length
                nodeModulesPath.append(alias)

                let scriptsList = packageScripts.getList(
                    ctx.log, lockfile, nodeModulesPath, alias, resolution
                )
                nodeModulesPath.setLength(folderSaved)

                if (scriptsList != None && scriptsList!!.total > 0) {
                    // 判断是否跳过
                    var skip = true
                    if (trustAll) {
                        skip = false
                    } else {
                        for (pkgName in packagesToTrust) {
                            if (pkgName == alias && !lockfile.hasTrustedDependency(alias, resolution)) {
                                skip = false
                            }
                        }
                    }

                    let depth = nm.depth
                    if (!scriptsAtDepth.contains(depth)) {
                        scriptsAtDepth.put(depth, ArrayList<ScriptInfo>())
                    }
                    scriptsAtDepth[depth]!!.append(ScriptInfo(
                        packageId: packageId,
                        scriptsList: scriptsList!!,
                        skip: skip
                    ))

                    if (!skip) {
                        packageNamesToAdd.add(alias)
                        scriptsCount += scriptsList!!.total
                    }
                }
            }

            nodeModulesPath.setLength(nmSaved)
        }

        if (scriptsAtDepth.size == 0 || packageNamesToAdd.size == 0) {
            printErrorZeroUntrustedDependenciesFound(trustAll, packagesToTrust)
            Global.crash()
        }

        // 按深度从深到浅执行 lifecycle 脚本
        var sortedDepths = ArrayList<Int64>()
        for ((depth, _) in scriptsAtDepth) {
            sortedDepths.append(depth)
        }
        sortedDepths.sort()

        Output.print("\n")

        var totalScriptsRan = 0
        var totalPackagesWithScripts = 0
        var totalSkippedPackages = 0

        for (depthIdx in sortedDepths.size - 1..0) {
            let depth = sortedDepths[depthIdx]
            let infos = scriptsAtDepth[depth]!!

            for (info in infos) {
                let resolution = resolutions[info.packageId]
                if (info.skip) {
                    info.scriptsList.printScripts(resolution, buf, PrintFormat.untrusted)
                    totalSkippedPackages += 1
                } else {
                    // 执行 lifecycle 脚本
                    executeLifecycleScriptsForPackage(pm, info.scriptsList)
                    totalPackagesWithScripts += 1
                    totalScriptsRan += info.scriptsList.total
                    info.scriptsList.printScripts(resolution, buf, PrintFormat.completed)
                }
                Output.print("\n")
            }

            // 等待所有脚本完成
            waitForScriptsToComplete(pm)
        }

        // 更新 package.json 和 lockfile
        editTrustedDependenciesAndSave(ctx, pm, packageNamesToAdd, loadLockfile)

        Output.pretty(
            " <green>${totalScriptsRan}<r> script${if (totalScriptsRan > 1) "s" else ""} ran across ${totalPackagesWithScripts} package${if (totalPackagesWithScripts > 1) "s" else ""} "
        )

        Output.printStartEndStdout(Global.startTime, Time.nanoTimestamp())
        Output.print("\n")

        if (totalSkippedPackages > 0) {
            Output.print("\n")
            Output.prettyLn(
                " <yellow>${totalSkippedPackages}<r> package${if (totalSkippedPackages > 1) "s" else ""} with blocked scripts"
            )
        }
    }

    /// 等待所有脚本完成
    private static func waitForScriptsToComplete(pm: PackageManager): Unit {
        while (pm.pendingLifecycleScriptTasks > 0) {
            pm.sleep()
        }
    }

    /// 执行包的 lifecycle 脚本
    private static func executeLifecycleScriptsForPackage(pm: PackageManager, scriptsList: ScriptsList): Unit {
        for (script in scriptsList.items) {
            while (LifecycleScriptSubprocess.aliveCount() >= pm.options.maxConcurrentLifecycleScripts) {
                pm.sleep()
            }
            pm.spawnPackageLifecycleScripts(scriptsList, false, false)
        }
    }

    /// 编辑 package.json 中的 trustedDependencies 并保存 lockfile
    private static func editTrustedDependenciesAndSave(
        ctx: CommandContext, pm: PackageManager,
        packageNamesToAdd: HashSet<String>, loadLockfile: LoadLockfileResult
    ): Unit {
        // 读取并解析 package.json
        let pkgContent = BaoFile.readAllText("package.json") ?: return
        var packageJson = JsonParser.parse(pkgContent) ?: return

        // 添加 trustedDependencies 字段
        let editor = PackageJsonEditor(packageJson)
        editor.editTrustedDependencies(packageNamesToAdd)

        // 更新 lockfile 的 trustedDependencies
        if (pm.lockfile.trustedDependencies == None) {
            pm.lockfile.trustedDependencies = HashMap<String, Unit>()
        }
        for (name in packageNamesToAdd) {
            pm.lockfile.trustedDependencies!![name] = ()
        }

        // 保存 lockfile
        pm.lockfile.saveToDisk(loadLockfile, pm.options)

        // 写回 package.json
        let formatted = editor.format()
        BaoFile.writeAllText("package.json", formatted)
    }

    private static func errorExpectedArgs(): Unit {
        Output.errGeneric("expected package names(s) or --all")
        Global.crash()
    }

    private static func printErrorZeroUntrustedDependenciesFound(trustAll: Bool, packagesToTrust: ArrayList<String>): Unit {
        Output.print("\n")
        if (trustAll) {
            Output.errGeneric(
                "0 scripts ran. This means all dependencies are already trusted or none have scripts."
            )
        } else {
            Output.errGeneric(
                "0 scripts ran. The following packages are already trusted, don't have scripts to run, or don't exist:\n\n"
            )
            for (arg in packagesToTrust) {
                Output.prettyError(" <d>-<r> ${arg}\n")
            }
        }
    }
}

/// 脚本信息 (按深度分组)
public class ScriptInfo {
    public var packageId: Int64
    public var scriptsList: ScriptsList
    public var skip: Bool

    public init(packageId: Int64, scriptsList: ScriptsList, skip: Bool) {
        this.packageId = packageId
        this.scriptsList = scriptsList
        this.skip = skip
    }
}

// ============================================================================
// PmTrustedCommand — 向后兼容的信任管理命令入口
// ============================================================================

/// pm trust 命令入口
/// 对应 Bun: TrustCommand / DefaultTrustedCommand
public class PmTrustedCommand {
    /// 执行 trust 命令
    /// 对应 Bun: TrustCommand.exec()
    public static func execTrust(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        let args = ArrayList<String>()
        args.append("bao")
        args.append("pm")
        args.append("trust")
        for (p in positionals) {
            args.append(p)
        }
        TrustCommand.exec(ctx, pm, args)
    }

    /// 执行 default-trusted 命令
    /// 对应 Bun: DefaultTrustedCommand.exec()
    public static func execDefaultTrusted(): Unit {
        DefaultTrustedCommand.exec()
    }

    /// 执行 untrusted 命令: 列出不受信任的包
    /// 对应 Bun: UntrustedCommand.exec()
    public static func execUntrusted(ctx: CommandContext, pm: PackageManager): Unit {
        let args = ArrayList<String>()
        args.append("bao")
        args.append("pm")
        args.append("untrusted")
        UntrustedCommand.exec(ctx, pm, args)
    }

    /// 检查包是否受信任
    /// 对应 Bun: Lockfile.hasTrustedDependency
    public static func isTrusted(packageName: String): Bool {
        let trustFile = BaoFile.readAllText("node_modules/.trusted")
        if (trustFile == None) {
            return false
        }
        return trustFile!!.contains(packageName)
    }
}
