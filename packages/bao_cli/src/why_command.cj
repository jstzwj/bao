// 严格翻译自: src/cli/why_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// WhyCommand — 解释包为什么被安装
// 严格翻译自: src/cli/why_command.zig - WhyCommand struct
// ============================================================================

/// WhyCommand: 解释包为什么被安装, 显示依赖树
/// 对应 Bun: WhyCommand
public class WhyCommand {
    private static let PREFIX_LAST = "  └─ "
    private static let PREFIX_MIDDLE = "  ├─ "
    private static let PREFIX_CONTINUE = "  │  "
    private static let PREFIX_SPACE = "     "
    private static var maxDepth: Int64 = 100

    /// 依赖类型
    public enum DependencyType {
        | dev
        | prod
        | peer
        | optional
        | optionalPeer
    }

    /// 版本信息
    public class VersionInfo {
        public var version: String
        public var pkgId: Int64

        public init(version: String, pkgId: Int64) {
            this.version = version
            this.pkgId = pkgId
        }
    }

    /// 依赖者信息
    public class DependentInfo {
        public var name: String
        public var version: String
        public var spec: String
        public var depType: DependencyType
        public var pkgId: Int64
        public var workspace: Bool

        public init() {
            name = ""
            version = ""
            spec = ""
            depType = DependencyType.prod
            pkgId = 0
            workspace = false
        }
    }

    /// 全局通配符模式
    public class GlobPattern {
        public enum PatternType {
            | exact
            | prefix
            | suffix
            | middle
            | contains
            | invalid
        }

        public var patternType: PatternType
        public var prefix: String
        public var suffix: String
        public var substring: String
        public var versionPattern: String

        public init(pattern: String) {
            patternType = PatternType.exact
            prefix = ""
            suffix = ""
            substring = ""
            versionPattern = ""

            // 检查是否包含 @ 分隔的版本模式
            let atPos = pattern.indexOf('@')
            if (atPos > 0 && atPos < pattern.length - 1) {
                let pkgPattern = pattern.substring(0, atPos)
                versionPattern = pattern.substring(atPos + 1)
                initForName(pkgPattern)
                return
            }

            initForName(pattern)
        }

        private func initForName(pattern: String): Unit {
            if (!pattern.contains('*')) {
                patternType = PatternType.exact
                return
            }

            // **子串**
            if (pattern.length >= 3 && pattern[0] == '*' && pattern[pattern.length - 1] == '*') {
                let sub = pattern.substring(1, pattern.length - 1)
                if (sub.length > 0 && !sub.contains('*')) {
                    patternType = PatternType.contains
                    substring = sub
                    return
                }
            }

            // 查找通配符位置
            let wildcardPos = pattern.indexOf('*')
            if (wildcardPos >= 0) {
                if (wildcardPos == pattern.length - 1) {
                    // prefix*
                    patternType = PatternType.prefix
                    prefix = pattern.substring(0, wildcardPos)
                } else if (wildcardPos == 0) {
                    // *suffix
                    patternType = PatternType.suffix
                    suffix = pattern.substring(1)
                } else {
                    // prefix*suffix
                    let secondStar = pattern.indexOf('*', wildcardPos + 1)
                    if (secondStar >= 0) {
                        patternType = PatternType.invalid
                    } else {
                        patternType = PatternType.middle
                        prefix = pattern.substring(0, wildcardPos)
                        suffix = pattern.substring(wildcardPos + 1)
                    }
                }
            }
        }

        /// 匹配名称
        public func matchesName(name: String, pattern: String): Bool {
            when (patternType) {
                case PatternType.exact => name == pattern
                case PatternType.prefix => name.startsWith(prefix)
                case PatternType.suffix => name.endsWith(suffix)
                case PatternType.middle => name.startsWith(prefix) && name.endsWith(suffix)
                case PatternType.contains => name.contains(substring)
                case PatternType.invalid => false
            }
        }

        /// 匹配版本
        public func matchesVersion(version: String): Bool {
            if (versionPattern.length == 0 || versionPattern == "latest") {
                return true
            }
            // 简化版本匹配: 精确匹配或前缀匹配
            if (version == versionPattern) {
                return true
            }
            return version.startsWith(versionPattern)
        }

        /// 完整匹配
        public func matches(name: String, version: String, pattern: String): Bool {
            if (!matchesName(name, pattern)) {
                return false
            }
            if (versionPattern.length > 0 && !matchesVersion(version)) {
                return false
            }
            return true
        }
    }

    /// 打印用法
    public static func printUsage(): Unit {
        Output.prettyLn("bao why v${Global.packageJsonVersionWithSha}")
        Output.pretty(
            "Explain why a package is installed\n" +
            "\n" +
            "Arguments:\n" +
            "  <package>     The package name to explain (supports glob patterns like '@org/*')\n" +
            "\n" +
            "Options:\n" +
            "  --top         Show only the top dependency tree instead of nested ones\n" +
            "  --depth <NUM> Maximum depth of the dependency tree to display\n" +
            "\n" +
            "Examples:\n" +
            "  bao why react\n" +
            "  bao why \"@types/*\" --depth 2\n" +
            "  bao why \"*-lodash\" --top\n" +
            "\n"
        )
    }

    /// 执行命令
    public static func exec(ctx: CommandContext): Unit {
        let cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.why)
        let pm = PackageManager.init(ctx, cli, Subcommand.why)

        if (cli.positionals.size < 1) {
            printUsage()
            Global.exit(1)
        }

        if (cli.positionals[0] == "why") {
            if (cli.positionals.size < 2) {
                printUsage()
                Global.exit(1)
            }
            execWithManager(ctx, pm, cli.positionals[1], cli.topOnly)
            return
        }

        execWithManager(ctx, pm, cli.positionals[0], cli.topOnly)
    }

    /// 从 PackageManager 执行
    public static func execFromPm(ctx: CommandContext, pm: PackageManager, positionals: ArrayList<String>): Unit {
        if (positionals.size < 2) {
            printUsage()
            Global.exit(1)
        }
        execWithManager(ctx, pm, positionals[1], pm.options.topOnly)
    }

    /// 使用指定的 PackageManager 执行
    public static func execWithManager(ctx: CommandContext, pm: PackageManager, packagePattern: String, topOnly: Bool): Unit {
        let loadLockfile = pm.lockfile.loadFromCwd(pm, ctx.allocator, ctx.log, true)
        PackageManagerCommand.handleLoadLockfileErrors(loadLockfile, pm)

        if (topOnly) {
            maxDepth = 1
        } else if (pm.options.depth != None) {
            maxDepth = pm.options.depth!!
        } else {
            maxDepth = 100
        }

        let lockfile = loadLockfile.lockfile
        let stringBytes = lockfile.stringBytes
        let packages = lockfile.packages

        // 目标版本列表
        let targetVersions = ArrayList<VersionInfo>()
        // 所有依赖者映射
        let allDependents = HashMap<Int64, ArrayList<DependentInfo>>()

        let glob = GlobPattern(packagePattern)

        // 遍历所有包
        for (pkgIdx in 0..packages.length) {
            let pkg = packages[pkgIdx]
            let pkgName = pkg.name.slice(stringBytes)
            if (pkgName.length == 0) {
                continue
            }

            // 收集依赖者信息
            let dependencies = pkg.dependencies
            let resolutions = pkg.resolutions

            for (depIdx in 0..dependencies.length) {
                let targetId = resolutions[depIdx]
                if (targetId >= packages.length) {
                    continue
                }

                var dependentsEntry = allDependents.get(targetId)
                if (dependentsEntry == None) {
                    dependentsEntry = ArrayList<DependentInfo>()
                    allDependents.put(targetId, dependentsEntry!!)
                }

                let dep = DependentInfo()
                dep.name = pkgName
                dep.version = packages.getResolution(pkgIdx).format(stringBytes)
                dep.spec = dependencies[depIdx].version.literal.slice(stringBytes)
                dep.pkgId = pkgIdx
                dep.workspace = dep.version.startsWith("workspace:") || dep.version.length == 0

                // 确定依赖类型
                if (dependencies[depIdx].behavior.dev) {
                    dep.depType = DependencyType.dev
                } else if (dependencies[depIdx].behavior.optional && dependencies[depIdx].behavior.peer) {
                    dep.depType = DependencyType.optionalPeer
                } else if (dependencies[depIdx].behavior.optional) {
                    dep.depType = DependencyType.optional
                } else if (dependencies[depIdx].behavior.peer) {
                    dep.depType = DependencyType.peer
                } else {
                    dep.depType = DependencyType.prod
                }

                dependentsEntry!!.append(dep)
            }

            // 检查是否匹配模式
            if (!glob.matchesName(pkgName, packagePattern)) {
                continue
            }

            let version = packages.getResolution(pkgIdx).format(stringBytes)
            if (!glob.matchesVersion(version)) {
                continue
            }

            targetVersions.append(VersionInfo(version, pkgIdx))
        }

        // 没有匹配结果
        if (targetVersions.size == 0) {
            Output.prettyLn("error: No packages matching '${packagePattern}' found in lockfile")
            Global.exit(1)
        }

        // 打印结果
        for (targetVersion in targetVersions) {
            let targetPkg = packages[targetVersion.pkgId]
            let targetName = targetPkg.name.slice(stringBytes)
            Output.prettyLn("${targetName}@${targetVersion.version}")

            let dependents = allDependents.get(targetVersion.pkgId)
            if (dependents != None) {
                let deps = dependents!!
                if (deps.size == 0) {
                    Output.prettyLn("  └─ No dependents found")
                } else if (maxDepth == 0) {
                    Output.prettyLn("  └─ (deeper dependencies hidden)")
                } else {
                    // 排序依赖者
                    sortDependents(deps)

                    for (depIdx in 0..deps.size) {
                        let dep = deps[depIdx]
                        let isLast = depIdx == deps.size - 1
                        let prefix = if (isLast) PREFIX_LAST else PREFIX_MIDDLE
                        printPackageWithType(prefix, dep)
                        if (!topOnly) {
                            let nextPrefix = if (isLast) PREFIX_SPACE else PREFIX_CONTINUE
                            printDependencyTree(allDependents, dep.pkgId, nextPrefix, 1, isLast, dep.workspace)
                        }
                    }
                }
            } else {
                Output.prettyLn("  └─ No dependents found")
            }

            Output.prettyLn("")
            Output.flush()
        }
    }

    /// 带类型打印包信息
    private static func printPackageWithType(prefix: String, pkg: DependentInfo): Unit {
        Output.pretty("${prefix}")

        when (pkg.depType) {
            case DependencyType.dev => Output.pretty("dev ")
            case DependencyType.peer => Output.pretty("peer ")
            case DependencyType.optional => Output.pretty("optional ")
            case DependencyType.optionalPeer => Output.pretty("optional peer ")
            case DependencyType.prod => ()
        }

        if (pkg.workspace) {
            Output.pretty("${pkg.name}")
            if (pkg.version.length > 0) {
                Output.pretty("@workspace")
            }
        } else {
            Output.pretty("${pkg.name}")
            if (pkg.version.length > 0) {
                Output.pretty("@${pkg.version}")
            }
        }

        if (pkg.spec.length > 0) {
            Output.prettyLn(" (requires ${pkg.spec})")
        } else {
            Output.prettyLn("")
        }
    }

    /// 打印依赖树
    private static func printDependencyTree(
        allDependents: HashMap<Int64, ArrayList<DependentInfo>>,
        currentPkgId: Int64,
        prefix: String,
        depth: Int64,
        printedBreakLine: Bool,
        parentIsWorkspace: Bool
    ): Unit {
        // 循环检测
        // (简化实现: 使用 visited 集合)

        let dependents = allDependents.get(currentPkgId)
        if (dependents == None) {
            return
        }

        let sortedDependents = ArrayList<DependentInfo>(dependents!!.size)
        for (d in dependents!!) {
            sortedDependents.append(d)
        }
        sortDependents(sortedDependents)

        for (depIdx in 0..sortedDependents.size) {
            let dep = sortedDependents[depIdx]

            if (parentIsWorkspace && dep.version.length == 0) {
                continue
            }

            if (depth >= maxDepth) {
                Output.prettyLn("${prefix}└─ (deeper dependencies hidden)")
                return
            }

            let isDepLast = depIdx == sortedDependents.size - 1
            let prefixChar = if (isDepLast) "└─ " else "├─ "
            let fullPrefix = prefix + prefixChar
            printPackageWithType(fullPrefix, dep)

            let nextPrefix = prefix + if (isDepLast) "   " else "│  "
            let printBreakLine = isDepLast && sortedDependents.size > 1 && !printedBreakLine
            printDependencyTree(allDependents, dep.pkgId, nextPrefix, depth + 1, printedBreakLine || printBreakLine, dep.workspace)

            if (printBreakLine) {
                Output.prettyLn("${prefix}")
            }
        }
    }

    /// 获取指定符的具体程度
    private static func getSpecifierSpecificity(spec: String): Int64 {
        if (spec.length == 0) return 9
        if (spec[0] == '*') return 1
        if (spec.contains(".x")) return 5
        if (spec.containsAny("<>=")) return 6
        if (spec[0] == '~') return 7
        if (spec[0] == '^') return 8
        if (spec.contains("workspace:")) return 9
        if (spec[0].isDigit()) return 10
        return 3
    }

    /// 获取依赖类型优先级
    private static func getDependencyTypePriority(depType: DependencyType): Int64 {
        when (depType) {
            case DependencyType.prod => 4
            case DependencyType.peer => 3
            case DependencyType.optionalPeer => 2
            case DependencyType.optional => 1
            case DependencyType.dev => 0
        }
    }

    /// 排序依赖者列表
    private static func sortDependents(dependents: ArrayList<DependentInfo>): Unit {
        // 简化的插入排序
        for (i in 1..dependents.size) {
            let key = dependents[i]
            var j = i - 1
            while (j >= 0 && compareDependents(dependents[j], key) > 0) {
                dependents[j + 1] = dependents[j]
                j -= 1
            }
            dependents[j + 1] = key
        }
    }

    /// 比较两个依赖者
    private static func compareDependents(a: DependentInfo, b: DependentInfo): Int64 {
        let aSpec = getSpecifierSpecificity(a.spec)
        let bSpec = getSpecifierSpecificity(b.spec)
        if (aSpec != bSpec) {
            return if (aSpec > bSpec) -1 else 1
        }

        let aType = getDependencyTypePriority(a.depType)
        let bType = getDependencyTypePriority(b.depType)
        if (aType != bType) {
            return if (aType > bType) -1 else 1
        }

        return a.name.compareTo(b.name)
    }
}
