// 严格翻译自: src/runtime/cli/run_command.zig
// bun run 命令 — 执行脚本和二进制文件
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

/// bun run 命令实现
public class RunCommand {
    /// 要搜索的 shell 列表
    static let SHELLS_TO_SEARCH: Array<String> = ["bash", "sh", "zsh"]

    /// 硬编码的 shell 路径
    static let HARDCODED_SHELLS: Array<String> = [
        "/bin/bash", "/usr/bin/bash", "/usr/local/bin/bash",
        "/bin/sh", "/usr/bin/sh",
        "/usr/bin/zsh", "/usr/local/bin/zsh",
        "/system/bin/sh"
    ]

    /// 执行 run 命令
    public static func exec(ctx: CommandContext): Bool {
        if (ctx.positionals.size > 0) {
            Output.prettyln("bao run ${ctx.positionals[0]} - not yet fully implemented")
        }
        return true
    }

    /// 以 Node.js 模式执行
    public static func execAsIfNode(ctx: CommandContext): Unit {
        if (ctx.positionals.size > 0) {
            Output.prettyln("bao run (node mode) - not yet fully implemented")
        } else {
            Output.errGeneric("No script specified for node mode")
        }
    }

    /// 列出可用脚本
    public static func ls(ctx: CommandContext): Bool {
        Output.prettyln("bao run --list - not yet fully implemented")
        return false
    }

    /// 打印帮助
    public static func printHelp(): Unit {
        Output.prettyln("Usage: bao run <script|binary> [args...]")
    }

    /// 查找 shell
    public static func findShell(pathEnv: String, cwd: String): ?String {
        for (shell in HARDCODED_SHELLS) {
            if (BaoFile.exists(shell)) {
                return shell
            }
        }
        return None
    }

    /// 替换包管理器命令
    public static func replacePackageManagerRun(script: String): String {
        return script.replace("bun run", "bao run").replace("bun x", "bao x")
    }
}
