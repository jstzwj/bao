// 严格翻译自: src/cli/open.zig (或对应文件)
// bun open 命令 — 在浏览器中打开 URL
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

/// Open 命令实现
public class OpenCommand {
    /// 默认浏览器
    static let defaultBrowsers = [
        "xdg-open",       // Linux
        "open",           // macOS
        "start",          // Windows
        "google-chrome",
        "firefox",
        "safari"
    ]

    /// 执行打开命令
    public static func exec(ctx: CommandContext): Unit {
        let args = ctx.positionals

        if (args.isEmpty()) {
            Output.prettyErrorln("<r><red>error:<r> Missing URL to open")
            Output.prettyln("\\nUsage: bao open <url>")
            Global.exit(1)
        }

        let url = args[0]

        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            Output.prettyErrorln("<r><red>error:<r> Invalid URL: ${url}")
            Output.prettyErrorln("<d>note:<r> URL must start with http:// or https://")
            Global.exit(1)
        }

        openURL(url)
    }

    /// 打开 URL
    public static func openURL(url: String): Unit {
        let command = getOpenCommand()

        let argv = [command, url]

        var opts = SpawnOptions()
        opts.args = argv
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        // TODO: check result
        if (false) {
            Output.errGeneric("Failed to open URL: ${url}")
        }
    }

    /// 获取打开命令
    static func getOpenCommand(): String {
        // TODO: detect platform and browser
        return "xdg-open"
    }

    /// 在特定浏览器中打开
    public static func openInBrowser(url: String, browser: ?String): Unit {
        let command = browser ?? getOpenCommand()

        let argv = [command, url]

        var opts = SpawnOptions()
        opts.args = argv
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        // TODO: check result
        if (false) {
            Output.errGeneric("Failed to open URL in browser: ${browser ?? command}")
        }
    }

    /// 打开本地文件
    public static func openFile(path: String): Unit {
        if (!BaoFile.exists(path)) {
            Output.errGeneric("File not found: ${path}")
            Global.exit(1)
        }

        let absPath = path  // TODO: Path.absolute
        let command = getOpenCommand()

        let argv = [command, absPath]

        var opts = SpawnOptions()
        opts.args = argv
        opts.stderr = StdioConfig.Inherit
        opts.stdout = StdioConfig.Inherit
        opts.stdin = StdioConfig.Inherit

        // TODO: spawnSync
        ()

        // TODO: check result
        if (false) {
            Output.errGeneric("Failed to open file: ${path}")
        }
    }
}
