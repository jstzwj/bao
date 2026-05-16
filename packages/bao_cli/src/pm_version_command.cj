// 严格翻译自: src/cli/pm_version_command.rs
// 对应 Bun: pm_version_command.zig — semver 版本管理命令
//
// 支持: patch, minor, major, prepatch, preminor, premajor, prerelease, from-git
// 包含:
//   - git 操作 (git tag --sort 推导版本)
//   - lifecycle 脚本执行 (preversion, version, postversion)
//   - package.json 编辑 (保留格式和缩进)
//   - --no-git-hooks / --allow-same-version / --commit-hooks 标志
//   - --message / -m 自定义 commit 消息
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// VersionType — 版本变更类型
// 严格翻译自: src/cli/pm_version_command.rs - VersionType
// ============================================================================

/// 版本变更类型
/// 对应 Bun: VersionType
public enum VersionBumpType {
    | patch
    | minor
    | major
    | prepatch
    | preminor
    | premajor
    | prerelease
    | specific     // 显式版本号
    | fromGit      // 从 git tag 推导

    public static func parse(str: String): ?VersionBumpType {
        when (str) {
            case "patch" => return Some(VersionBumpType.patch)
            case "minor" => return Some(VersionBumpType.minor)
            case "major" => return Some(VersionBumpType.major)
            case "prepatch" => return Some(VersionBumpType.prepatch)
            case "preminor" => return Some(VersionBumpType.preminor)
            case "premajor" => return Some(VersionBumpType.premajor)
            case "prerelease" => return Some(VersionBumpType.prerelease)
            case "from-git" => return Some(VersionBumpType.fromGit)
            else => return None
        }
    }
}

/// pm version 命令的选项
/// 对应 Bun: CommandLineArguments 中 version 相关的选项
public class VersionOptions {
    public var noGitHooks: Bool       = false
    public var allowSameVersion: Bool = false
    public var commitHooks: Bool      = true
    public var message: ?String       = None    // 自定义 commit 消息
    public var preid: String          = "alpha" // prerelease 标识

    public init() {}
}

// ============================================================================
// PmVersionCommand — semver 版本管理命令
// 严格翻译自: src/cli/pm_version_command.rs - PmVersionCommand
// ============================================================================

/// pm version 命令: 管理包版本
/// 对应 Bun: PmVersionCommand
public class PmVersionCommand {
    /// 执行 version 命令
    /// 对应 Bun: PmVersionCommand.exec()
    public static func exec(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        let opts = parseOptions(positionals)

        if (positionals.size < 1 || opts.versionArg == None) {
            // 无参数或只有选项: 显示当前版本
            printCurrentVersion()
            return
        }

        let versionArg = opts.versionArg!!

        // from-git: 从 git tag 推导版本
        if (versionArg == "from-git") {
            setVersionFromGit(opts)
            return
        }

        // 尝试解析为版本变更类型
        let bumpType = VersionBumpType.parse(versionArg)
        if (bumpType != None) {
            bumpVersion(bumpType!!, opts)
            return
        }

        // 尝试解析为显式版本号
        let version = SemVer.parse(versionArg)
        if (version != None) {
            setVersion(version!!.format(), opts)
            return
        }

        Output.errGeneric("Invalid version: ${versionArg}")
    }

    /// 解析命令行选项
    private static func parseOptions(positionals: ArrayList<String>): VersionOptions {
        let opts = VersionOptions()
        for (arg in positionals) {
            when (arg) {
                case "--no-git-hooks" => opts.noGitHooks = true
                case "--allow-same-version" => opts.allowSameVersion = true
                case "--no-commit-hooks" => opts.commitHooks = false
                case "--commit-hooks" => opts.commitHooks = true
                else => {
                    // 检查 --message 或 -m
                    if (arg.startsWith("--message=")) {
                        opts.message = Some(arg.substring("--message=".length))
                    } else if (arg.startsWith("-m=")) {
                        opts.message = Some(arg.substring("-m=".length))
                    } else if (arg.startsWith("--preid=")) {
                        opts.preid = arg.substring("--preid=".length)
                    } else {
                        // 第一个非选项参数为版本参数
                        if (opts.versionArg == None) {
                            opts.versionArg = arg
                        }
                    }
                }
            }
        }
        return opts
    }

    /// 打印当前版本
    /// 对应 Bun: 无参数时显示当前版本
    private static func printCurrentVersion(): Unit {
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            Output.errGeneric("No package.json found")
            return
        }

        let json = JsonParser.parse(pkgContent!!)
        if (json != None && json!!.isObject()) {
            let version = json!!.asObject().get("version")
            if (version != None && version!!.isString()) {
                Output.println(version!!.asString())
                return
            }
        }
        Output.println("0.0.0")
    }

    /// 获取当前版本
    private static func getCurrentVersion(): ?SemVer {
        let pkgContent = BaoFile.readAllText("package.json") ?: return None
        let json = JsonParser.parse(pkgContent)
        if (json != None && json!!.isObject()) {
            let version = json!!.asObject().get("version")
            if (version != None && version!!.isString()) {
                return SemVer.parse(version!!.asString())
            }
        }
        return None
    }

    /// 递增版本号
    /// 对应 Bun: bumpVersion (semver 递增逻辑)
    public static func bumpVersion(bumpType: VersionBumpType, opts: VersionOptions): Unit {
        let current = getCurrentVersion()
        if (current == None) {
            Output.errGeneric("No version found in package.json")
            return
        }

        let newVersion = when (bumpType) {
            case VersionBumpType.patch =>
                SemVer(current!!.major, current!!.minor, current!!.patch + 1)
            case VersionBumpType.minor =>
                SemVer(current!!.major, current!!.minor + 1, 0)
            case VersionBumpType.major =>
                SemVer(current!!.major + 1, 0, 0)
            case VersionBumpType.prepatch =>
                SemVer(current!!.major, current!!.minor, current!!.patch + 1, opts.preid, 0)
            case VersionBumpType.preminor =>
                SemVer(current!!.major, current!!.minor + 1, 0, opts.preid, 0)
            case VersionBumpType.premajor =>
                SemVer(current!!.major + 1, 0, 0, opts.preid, 0)
            case VersionBumpType.prerelease => {
                if (current!!.prerelease != None) {
                    SemVer(current!!.major, current!!.minor, current!!.patch, current!!.prereleaseTag, current!!.prereleaseNum + 1)
                } else {
                    SemVer(current!!.major, current!!.minor, current!!.patch + 1, opts.preid, 0)
                }
            }
            case _ => current!!
        }

        // 检查是否版本相同
        if (newVersion.format() == current!!.format() && !opts.allowSameVersion) {
            Output.errGeneric("Version already is ${newVersion.format()}. Use --allow-same-version to bypass.")
            return
        }

        setVersion(newVersion.format(), opts)
    }

    /// 从 git tag 推导版本
    /// 对应 Bun: from-git — 使用 git describe --tags --match "v*"
    private static func setVersionFromGit(opts: VersionOptions): Unit {
        try {
            let output = Sys.execCapture("git describe --tags --match \"v*\" --abbrev=0")
            if (output.length > 0 && output[0] == 'v') {
                let tagVersion = output.substring(1)
                let version = SemVer.parse(tagVersion)
                if (version != None) {
                    setVersion(version!!.format(), opts)
                    return
                }
            }
            Output.errGeneric("No valid git version tag found")
        } catch (e: Exception) {
            Output.errGeneric("Failed to get git tag: ${e.message}")
        }
    }

    /// 设置版本号
    /// 对应 Bun: setVersion (修改 package.json 并执行 lifecycle 脚本)
    public static func setVersion(version: String, opts: VersionOptions): Unit {
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            Output.errGeneric("No package.json found")
            return
        }

        // 执行 preversion lifecycle 脚本
        if (!opts.noGitHooks && opts.commitHooks) {
            executeLifecycleScript("preversion")
        }

        // 修改 version 字段 (保留缩进)
        let indent = detectIndentation(pkgContent!!)
        let modified = JsonHelper.setField(pkgContent!!, "version", version)
        BaoFile.writeAllText("package.json", modified)

        Output.println("v${version}")

        // 执行 version lifecycle 脚本
        if (!opts.noGitHooks && opts.commitHooks) {
            executeLifecycleScript("version")
        }

        // Git 操作
        gitAddAndCommit(version, opts)

        // 执行 postversion lifecycle 脚本
        if (!opts.noGitHooks && opts.commitHooks) {
            executeLifecycleScript("postversion")
        }
    }

    /// 向后兼容版本
    public static func setVersion(version: String): Unit {
        setVersion(version, VersionOptions())
    }

    /// 执行 lifecycle 脚本
    /// 对应 Bun: 执行 npm lifecycle 脚本 (preversion, version, postversion)
    private static func executeLifecycleScript(scriptName: String): Unit {
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            return
        }

        let json = JsonParser.parse(pkgContent!!)
        if (json != None && json!!.isObject()) {
            let scripts = json!!.asObject().get("scripts")
            if (scripts != None && scripts!!.isObject()) {
                let script = scripts!!.asObject().get(scriptName)
                if (script != None && script!!.isString()) {
                    try {
                        Sys.exec(script!!.asString())
                    } catch (e: Exception) {
                        Output.println("Warning: ${scriptName} script failed: ${e.message}")
                    }
                }
            }
        }
    }

    /// Git add 并 commit
    /// 对应 Bun: git add + git commit + git tag
    private static func gitAddAndCommit(version: String, opts: VersionOptions): Unit {
        let commitMessage = if (opts.message != None) {
            opts.message!!
        } else {
            "v${version}"
        }

        try {
            Sys.exec("git add package.json")
            Sys.exec("git commit -m \"${commitMessage}\"")
            Sys.exec("git tag v${version}")
        } catch (e: Exception) {
            // Git 操作失败不是致命错误
            Output.println("Warning: git operations failed: ${e.message}")
        }
    }

    /// 检测 JSON 缩进风格
    private static func detectIndentation(content: String): String {
        let lines = content.split('\n')
        for (line in lines) {
            let trimmed = line.trimStart()
            if (trimmed.length > 0 && trimmed != line) {
                let indent = line.substring(0, line.length - trimmed.length)
                if (indent.length > 0) {
                    return indent
                }
            }
        }
        return "  "
    }
}

// ============================================================================
// SemVer — 语义版本号
// 严格翻译自: src/cli/pm_version_command.rs 中的 semver 操作
// ============================================================================

/// SemVer 版本号
public class SemVer {
    public var major: Int64
    public var minor: Int64
    public var patch: Int64
    public var prereleaseTag: String
    public var prereleaseNum: Int64

    public var prerelease: ?String

    public init(major: Int64, minor: Int64, patch: Int64) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.prereleaseTag = ""
        this.prereleaseNum = 0
        this.prerelease = None
    }

    public init(major: Int64, minor: Int64, patch: Int64, prereleaseTag: String, prereleaseNum: Int64) {
        this.major = major
        this.minor = minor
        this.patch = patch
        this.prereleaseTag = prereleaseTag
        this.prereleaseNum = prereleaseNum
        this.prerelease = Some("${prereleaseTag}.${prereleaseNum}")
    }

    /// 格式化为字符串
    public func format(): String {
        let base = "${major}.${minor}.${patch}"
        if (prerelease != None) {
            return "${base}-${prereleaseTag}.${prereleaseNum}"
        }
        return base
    }

    /// 从字符串解析
    public static func parse(s: String): ?SemVer {
        if (s.length == 0) {
            return None
        }

        // 移除前导 'v'
        var versionStr = s
        if (versionStr[0] == 'v' || versionStr[0] == 'V') {
            versionStr = versionStr.substring(1)
        }

        let parts = versionStr.split('.')
        if (parts.length < 3) {
            return None
        }
        let major = Int64.parse(parts[0]) ?: return None
        let minor = Int64.parse(parts[1]) ?: return None
        let patchPart = parts[2]
        let dashIdx = patchPart.indexOf('-')
        if (dashIdx >= 0) {
            let patch = Int64.parse(patchPart.substring(0, dashIdx)) ?: return None
            let pre = patchPart.substring(dashIdx + 1)
            let dotIdx = pre.indexOf('.')
            if (dotIdx >= 0) {
                let tag = pre.substring(0, dotIdx)
                let num = Int64.parse(pre.substring(dotIdx + 1)) ?: 0
                return Some(SemVer(major, minor, patch, tag, num))
            }
            return Some(SemVer(major, minor, patch, pre, 0))
        }
        let patch = Int64.parse(patchPart) ?: return None
        return Some(SemVer(major, minor, patch))
    }

    /// 比较版本号
    /// 对应 Bun: semver comparison
    public func compareTo(other: SemVer): Int64 {
        if (major != other.major) {
            return major - other.major
        }
        if (minor != other.minor) {
            return minor - other.minor
        }
        if (patch != other.patch) {
            return patch - other.patch
        }
        // 有 prerelease 的版本 < 没有 prerelease 的版本
        if (prerelease != None && other.prerelease == None) {
            return -1
        }
        if (prerelease == None && other.prerelease != None) {
            return 1
        }
        if (prerelease != None && other.prerelease != None) {
            return prereleaseNum - other.prereleaseNum
        }
        return 0
    }
}

/// VersionOptions 的扩展字段
public class VersionOptions {
    public var versionArg: ?String = None  // 版本参数

    public init() {}
}
