// 严格翻译自: src/cli/pm_trusted_command.zig
// 包管理器信任设置命令
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

/// 信任状态
public enum TrustStatus {
    | trusted
    | untrusted
    | unknown
}

/// PM 受信任命令实现
public class PmTrustedCommand {
    /// 执行命令
    public static func exec(ctx: CommandContext): Unit {
        let args = ctx.positionals

        if (args.isEmpty()) {
            listTrusted(ctx)
            return
        }

        let action = args[0]

        if (action == "add") {
            if (args.size < 2) {
                Output.prettyErrorln("<r><red>error:<r> Missing package name")
                printHelp()
                Global.exit(1)
            }
            addTrusted(ctx, args[1])
        } else if (action == "remove" || action == "rm") {
            if (args.size < 2) {
                Output.prettyErrorln("<r><red>error:<r> Missing package name")
                printHelp()
                Global.exit(1)
            }
            removeTrusted(ctx, args[1])
        } else if (action == "check") {
            if (args.size < 2) {
                Output.prettyErrorln("<r><red>error:<r> Missing package name")
                printHelp()
                Global.exit(1)
            }
            checkTrusted(ctx, args[1])
        } else if (action == "list" || action == "ls") {
            listTrusted(ctx)
        } else if (action == "--help" || action == "-h") {
            printHelp()
        } else {
            Output.prettyErrorln("<r><red>error:<r> Unknown action: ${action}")
            printHelp()
            Global.exit(1)
        }
    }

    /// 添加受信任包
    static func addTrusted(ctx: CommandContext, packageName: String): Unit {
        let trustedFile = getTrustedFile()

        // 读取现有信任列表
        var trustedList = if (BaoFile.exists(trustedFile)) {
            readTrustedList(trustedFile)
        } else {
            ArrayList<String>()
        }

        // 检查是否已存在
        if (trustedList.contains(packageName)) {
            Output.prettyln("<yellow>Package '${packageName}' is already trusted<r>")
            return
        }

        // 添加到列表
        trustedList.append(packageName)

        // 写回文件
        writeTrustedList(trustedFile, trustedList)

        Output.prettyln("<green>Success!<r> Added '${packageName}' to trusted packages")
    }

    /// 移除受信任包
    static func removeTrusted(ctx: CommandContext, packageName: String): Unit {
        let trustedFile = getTrustedFile()

        if (!BaoFile.exists(trustedFile)) {
            Output.prettyErrorln("<r><red>error:<r> No trusted packages file found")
            return
        }

        let trustedList = readTrustedList(trustedFile)

        // 查找并移除
        var index: ?Int64 = None; var idx: Int64 = 0; for (item in trustedList) { if (item == packageName) { index = idx }; idx++ }

        if (index.isNone()) {
            Output.prettyln("<yellow>Package '${packageName}' is not in trusted list<r>")
            return
        }

        trustedList.removeAt(index.getOrThrow())

        // 写回文件
        writeTrustedList(trustedFile, trustedList)

        Output.prettyln("<green>Success!<r> Removed '${packageName}' from trusted packages")
    }

    /// 检查受信任状态
    static func checkTrusted(ctx: CommandContext, packageName: String): Unit {
        let trustedFile = getTrustedFile()

        if (!BaoFile.exists(trustedFile)) {
            Output.prettyln("${packageName}: <yellow>unknown<r>")
            return
        }

        let trustedList = readTrustedList(trustedFile)

        let status = if (trustedList.contains(packageName)) {
            TrustStatus.trusted
        } else {
            TrustStatus.untrusted
        }

        match (status) {
            case trusted => Output.prettyln("${packageName}: <green>trusted<r>")
            case untrusted => Output.prettyln("${packageName}: <red>untrusted<r>")
            case unknown => Output.prettyln("${packageName}: <yellow>unknown<r>")
        }
    }

    /// 列出受信任包
    static func listTrusted(ctx: CommandContext): Unit {
        let trustedFile = getTrustedFile()

        if (!BaoFile.exists(trustedFile)) {
            Output.prettyln("No trusted packages configured.")
            return
        }

        let trustedList = readTrustedList(trustedFile)

        if (trustedList.isEmpty()) {
            Output.prettyln("No trusted packages configured.")
            return
        }

        Output.prettyln("Trusted packages (${trustedList.size}):")

        for (pkg in trustedList) {
            Output.prettyln("  <cyan>${pkg}<r>")
        }
    }

    /// 获取信任文件路径
    static func getTrustedFile(): String {
        let configDir = getConfigDir()
        return configDir + "/trusted-packages.txt"
    }

    /// 获取配置目录
    static func getConfigDir(): String {
        let homeDir = "/home/user"  // TODO: HOME
        let configDir = homeDir + "/.config"  // TODO: XDG_CONFIG_HOME
        return configDir + "/bao"
    }

    /// 读取信任列表
    static func readTrustedList(path: String): ArrayList<String> {
        let content = ""  // TODO: BaoFile.readFile
        let lines = content.split("\\n")

        var list = ArrayList<String>()

        for (line in lines) {
            let trimmed = line
            if (!trimmed.isEmpty() && !trimmed.startsWith("#")) {
                list.append(trimmed)
            }
        }

        return list
    }

    /// 写入信任列表
    static func writeTrustedList(path: String, list: ArrayList<String>): Unit {
        var content = ArrayList<String>()

        content.append("# Bao trusted packages\\n")
        content.append("# One package per line\\n")
        content.append("# Lines starting with # are comments\\n\\n")

        for (pkg in list) {
            content.append(pkg)
            content.append("\\n")
        }

        // TODO: BaoFile.writeFile
    }

    /// 打印帮助
    static func printHelp(): Unit {
        Output.prettyln(
            "<b>Usage<r>: <b><green>bao pm trusted<r> <action> [package]\\n\\n" +
            "Actions:\\n" +
            "  add <package>     Add a package to trusted list\\n" +
            "  remove <package>  Remove a package from trusted list\\n" +
            "  check <package>   Check if a package is trusted\\n" +
            "  list             List all trusted packages\\n\\n" +
            "Options:\\n" +
            "  -h, --help       Print this help\\n")
    }
}
