// 严格翻译自: src/cli/package_manager_command.zig
// 包管理器命令
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

/// 支持的包管理器
public enum PackageManager {
    | npm
    | yarn
    | pnpm
    | bun
    | unknown

    /// 从名称获取包管理器
    public static func fromName(name: String): PackageManager {
        if (name == "npm") {
            return npm
        } else if (name == "yarn") {
            return yarn
        } else if (name == "pnpm") {
            return pnpm
        } else if (name == "bun" || name == "bao") {
            return bun
        } else {
            return unknown
        }
    }

    /// 获取可执行文件名
    public func executable(): String {
        match (this) {
            case npm => "npm"
            case yarn => "yarn"
            case pnpm => "pnpm"
            case bun => "bao"
            case unknown => "unknown"
        }
    }
}

/// PM 命令实现
public class PmCommand {
    /// 执行命令
    public static func exec(ctx: CommandContext): Unit {
        let args = ctx.positionals

        if (args.isEmpty()) {
            printHelp()
            return
        }

        let subCommand = args[0]

        if (subCommand == "install" || subCommand == "i") {
            // TODO: installCommand(ctx, args.toArray())
        } else if (subCommand == "add" || subCommand == "a") {
            // TODO: addCommand(ctx, args.toArray())
        } else if (subCommand == "remove" || subCommand == "rm" || subCommand == "uninstall") {
            // TODO: removeCommand(ctx, args.toArray())
        } else if (subCommand == "update" || subCommand == "up") {
            // TODO: updateCommand(ctx, args.toArray())
        } else if (subCommand == "list" || subCommand == "ls") {
            listCommand(ctx)
        } else if (subCommand == "outdated") {
            outdatedCommand(ctx)
        } else if (subCommand == "trusted") {
            PmTrustedCommand.exec(ctx)
        } else if (subCommand == "cache") {
            // TODO: cacheCommand(ctx, args.toArray())
        } else if (subCommand == "--help" || subCommand == "-h") {
            printHelp()
        } else {
            Output.prettyErrorln("<r><red>error:<r> Unknown subcommand: ${subCommand}")
            printHelp()
            Global.exit(1)
        }
    }

    /// 安装命令
    static func installCommand(ctx: CommandContext, args: Array<String>): Unit {
        Output.prettyln("Installing dependencies...")

        var opts = SpawnOptions()
        opts.args = ["bao", "install"]
        opts.cwd = ctx.cwd
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        if (false) {
            Output.errGeneric("Failed to install dependencies")
        }
    }

    /// 添加命令
    static func addCommand(ctx: CommandContext, args: Array<String>): Unit {
        if (args.isEmpty()) {
            Output.prettyErrorln("<r><red>error:<r> Missing package name(s)")
            Global.exit(1)
        }

        Output.prettyln("Adding packages...")

        var baoArgs = ArrayList<String>(); baoArgs.append("bao"); baoArgs.append("add")
        for (a in args) { baoArgs.append(a) }

        var opts = SpawnOptions()
        // TODO: opts.args = baoArgs.toArray()
        opts.cwd = ctx.cwd
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        if (false) {
            Output.errGeneric("Failed to add packages")
        }
    }

    /// 移除命令
    static func removeCommand(ctx: CommandContext, args: Array<String>): Unit {
        if (args.isEmpty()) {
            Output.prettyErrorln("<r><red>error:<r> Missing package name(s)")
            Global.exit(1)
        }

        Output.prettyln("Removing packages...")

        var baoArgs = ArrayList<String>(); baoArgs.append("bao"); baoArgs.append("remove")
        for (a in args) { baoArgs.append(a) }

        var opts = SpawnOptions()
        // TODO: opts.args = baoArgs.toArray()
        opts.cwd = ctx.cwd
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        if (false) {
            Output.errGeneric("Failed to remove packages")
        }
    }

    /// 更新命令
    static func updateCommand(ctx: CommandContext, args: Array<String>): Unit {
        if (args.isEmpty()) {
            Output.prettyln("Updating all dependencies...")
        } else {
            Output.prettyln("Updating packages...")
        }

        var baoArgs = ArrayList<String>(); baoArgs.append("bao"); baoArgs.append("update")
        for (a in args) { baoArgs.append(a) }

        var opts = SpawnOptions()
        // TODO: opts.args = baoArgs.toArray()
        opts.cwd = ctx.cwd
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        if (false) {
            Output.errGeneric("Failed to update packages")
        }
    }

    /// 列表命令
    static func listCommand(ctx: CommandContext): Unit {
        Output.prettyln("Installed packages:")

        var opts = SpawnOptions()
        opts.args = ["bao", "pm", "ls"]
        opts.cwd = ctx.cwd
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        if (false) {
            Output.errGeneric("Failed to list packages")
        }
    }

    /// 过期命令
    static func outdatedCommand(ctx: CommandContext): Unit {
        Output.prettyln("Checking for outdated packages...")

        var opts = SpawnOptions()
        opts.args = ["bao", "pm", "outdated"]
        opts.cwd = ctx.cwd
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        if (false) {
            Output.errGeneric("Failed to check outdated packages")
        }
    }

    /// 缓存命令
    static func cacheCommand(ctx: CommandContext, args: Array<String>): Unit {
        if (args.isEmpty()) {
            Output.prettyErrorln("<r><red>error:<r> Missing cache action")
            printHelp()
            Global.exit(1)
        }

        let action = args[0]

        if (action == "clean" || action == "clear") {
            Output.prettyln("Clearing package cache...")
            // TODO: 实现缓存清理
        } else if (action == "dir") {
            let cacheDir = getCacheDir()
            Output.prettyln("Package cache directory: ${cacheDir}")
        } else if (action == "list" || action == "ls") {
            Output.prettyln("Cached packages:")
            // TODO: 实现缓存列表
        } else {
            Output.prettyErrorln("<r><red>error:<r> Unknown cache action: ${action}")
            Global.exit(1)
        }
    }

    /// 获取缓存目录
    static func getCacheDir(): String {
        let homeDir = "/home/user"  // TODO: HOME
        let cacheDir = homeDir + "/.cache"  // TODO: XDG_CACHE_HOME
        return cacheDir + "/bao"
    }

    /// 打印帮助
    static func printHelp(): Unit {
        Output.prettyln(
            "<b>Usage<r>: <b><green>bao pm<r> <command> [options]\\n\\n" +
            "Commands:\\n" +
            "  install, i       Install dependencies\\n" +
            "  add, a          Add packages\\n" +
            "  remove, rm      Remove packages\\n" +
            "  update, up      Update packages\\n" +
            "  list, ls        List installed packages\\n" +
            "  outdated        Check for outdated packages\\n" +
            "  trusted         Manage trusted packages\\n" +
            "  cache           Manage package cache\\n\\n" +
            "Options:\\n" +
            "  -h, --help     Print this help\\n")
    }
}
