// 严格翻译自: src/cli/list-of-yarn-commands.zig
package bao_cli

import bao_collections.*

// ============================================================================
// ListOfYarnCommands — Yarn 命令名称集合
// 严格翻译自: src/cli/list-of-yarn-commands.zig - all_yarn_commands
//
// 用于检测用户是否在尝试使用 yarn 命令
// ============================================================================

/// 所有 yarn v1 和 v2+ 命令名称的集合
/// 对应 Bun: all_yarn_commands (ComptimeStringMap)
public class ListOfYarnCommands {
    /// yarn v2+ 命令
    private static let yarnV2Commands: Array<String> = [
        "add",
        "bin",
        "cache",
        "config",
        "dedupe",
        "dlx",
        "exec",
        "explain",
        "info",
        "init",
        "install",
        "link",
        "node",
        "npm",
        "pack",
        "patch",
        "plugin",
        "rebuild",
        "remove",
        "run",
        "set",
        "unplug",
        "up",
        "why",
        "workspace",
        "workspaces",
    ]

    /// yarn v1 特有命令
    private static let yarnV1Commands: Array<String> = [
        "access",
        "autoclean",
        "check",
        "create",
        "generate-lock-entry",
        "generateLockEntry",
        "global",
        "help",
        "import",
        "licenses",
        "list",
        "login",
        "logout",
        "outdated",
        "owner",
        "policies",
        "publish",
        "tag",
        "team",
        "unlink",
        "upgrade",
        "upgrade-interactive",
        "upgradeInteractive",
        "version",
        "versions",
    ]

    /// 所有 yarn 命令的哈希集合
    private static var allCommandsSet: HashSet<String>? = None

    /// 检查给定名称是否是 yarn 命令
    public static func isYarnCommand(name: String): Bool {
        if (allCommandsSet == None) {
            let set = HashSet<String>()
            for (cmd in yarnV2Commands) {
                set.put(cmd)
            }
            for (cmd in yarnV1Commands) {
                set.put(cmd)
            }
            // yarn v2 命令也包含部分 v1 命令 (如 add, bin 等)
            allCommandsSet = Some(set)
        }
        return allCommandsSet.getOrThrow().contains(name)
    }

    /// 获取所有命令名称列表
    public static func allCommands(): ArrayList<String> {
        let result = ArrayList<String>()
        for (cmd in yarnV2Commands) {
            result.append(cmd)
        }
        for (cmd in yarnV1Commands) {
            result.append(cmd)
        }
        return result
    }
}
