// 严格翻译自: src/cli/pm_version_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PmVersionCommand — semver 版本管理命令
// 严格翻译自: src/cli/pm_version_command.zig
//
// 支持: patch, minor, major, prepatch, preminor, premajor, prerelease
// 包含 git 操作和 lifecycle 脚本执行
// ============================================================================

/// 版本变更类型
/// 对应 Bun: pm_version_command 版本变更选项
public enum VersionBumpType {
    | patch
    | minor
    | major
    | prepatch
    | preminor
    | premajor
    | prerelease
}

/// pm version 命令: 管理包版本
/// 对应 Bun: pm_version_command
public class PmVersionCommand {
    /// 执行 version 命令
    /// 对应 Bun: PmVersionCommand.exec()
    public static func exec(ctx: CommandContext, pm: PackageManager): Unit {
        let positionals = ctx.positionals
        if (positionals.size < 1) {
            // 无参数: 显示当前版本
            printCurrentVersion()
            return
        }

        let bumpTypeStr = positionals[0]
        let bumpType = parseBumpType(bumpTypeStr)
        if (bumpType == None) {
            // 可能是显式版本号
            let version = SemVer.parse(bumpTypeStr)
            if (version != None) {
                setVersion(version!!.format())
                return
            }
            Output.errGeneric("Invalid version: ${bumpTypeStr}")
            return
        }

        bumpVersion(bumpType!!)
    }

    /// 解析版本变更类型
    private static func parseBumpType(str: String): ?VersionBumpType {
        when (str) {
            case "patch" => return Some(VersionBumpType.patch)
            case "minor" => return Some(VersionBumpType.minor)
            case "major" => return Some(VersionBumpType.major)
            case "prepatch" => return Some(VersionBumpType.prepatch)
            case "preminor" => return Some(VersionBumpType.preminor)
            case "premajor" => return Some(VersionBumpType.premajor)
            case "prerelease" => return Some(VersionBumpType.prerelease)
            else => return None
        }
    }

    /// 打印当前版本
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
    public static func bumpVersion(bumpType: VersionBumpType): Unit {
        let current = getCurrentVersion()
        if (current == None) {
            Output.errGeneric("No version found in package.json")
            return
        }

        let newVersion = when (bumpType) {
            case VersionBumpType.patch => SemVer(current!!.major, current!!.minor, current!!.patch + 1)
            case VersionBumpType.minor => SemVer(current!!.major, current!!.minor + 1, 0)
            case VersionBumpType.major => SemVer(current!!.major + 1, 0, 0)
            case VersionBumpType.prepatch => SemVer(current!!.major, current!!.minor, current!!.patch + 1, "alpha", 0)
            case VersionBumpType.preminor => SemVer(current!!.major, current!!.minor + 1, 0, "alpha", 0)
            case VersionBumpType.premajor => SemVer(current!!.major + 1, 0, 0, "alpha", 0)
            case VersionBumpType.prerelease => {
                if (current!!.prerelease != None) {
                    SemVer(current!!.major, current!!.minor, current!!.patch, current!!.prereleaseTag, current!!.prereleaseNum + 1)
                } else {
                    SemVer(current!!.major, current!!.minor, current!!.patch + 1, "alpha", 0)
                }
            }
        }

        setVersion(newVersion.format())
    }

    /// 设置版本号
    /// 对应 Bun: setVersion (修改 package.json 并 git commit)
    public static func setVersion(version: String): Unit {
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent == None) {
            Output.errGeneric("No package.json found")
            return
        }

        // 修改 version 字段
        let modified = JsonHelper.setField(pkgContent!!, "version", version)
        BaoFile.writeAllText("package.json", modified)

        Output.println("v${version}")

        // 执行 preversion lifecycle 脚本
        executeLifecycleScript("preversion")

        // 执行 version lifecycle 脚本
        executeLifecycleScript("version")

        // Git 操作
        gitAddAndCommit(version)

        // 执行 postversion lifecycle 脚本
        executeLifecycleScript("postversion")
    }

    /// 执行 lifecycle 脚本
    /// 对应 Bun: 执行 npm lifecycle 脚本
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
    /// 对应 Bun: git 操作
    private static func gitAddAndCommit(version: String): Unit {
        // git add package.json
        try {
            Sys.exec("git add package.json")
            Sys.exec("git commit -m \"v${version}\"")
            Sys.exec("git tag v${version}")
        } catch (e: Exception) {
            // Git 操作失败不是致命错误
            Output.println("Warning: git operations failed: ${e.message}")
        }
    }
}

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
        let parts = s.split('.')
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
}
