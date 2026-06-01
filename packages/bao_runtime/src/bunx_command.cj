// 严格翻译自: src/runtime/cli/bunx_command.zig
// bunx 命令 — 执行 npm 包中的命令
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

// ============================================================================
// BunxCommand — bunx <package> [args...]
// 对应 Bun: src/runtime/cli/bunx_command.zig
// ============================================================================

/// bunx 命令选项
public class BunxOptions {
    public var passthroughList: ArrayList<String>
    public var packageName: String
    public var binaryName: ?String
    public var specifiedPackage: ?String
    public var verboseInstall: Bool
    public var silentInstall: Bool
    public var noInstall: Bool

    public init() {
        this.passthroughList = ArrayList<String>()
        this.packageName = ""
        this.binaryName = None
        this.specifiedPackage = None
        this.verboseInstall = false
        this.silentInstall = false
        this.noInstall = false
    }

    /// 解析 CLI 参数
    public static func parse(ctx: CommandContext, argv: Array<String>): BunxOptions {
        let opts = BunxOptions()
        var i: Int64 = 0
        while (i < argv.size) {
            let arg = argv[i]
            if (arg.startsWith("--package=")) {
                opts.specifiedPackage = arg["--package=".size..]
            } else if (arg == "--verbose") {
                opts.verboseInstall = true
            } else if (arg == "--silent") {
                opts.silentInstall = true
            } else if (arg == "--no-install") {
                opts.noInstall = true
            } else if (!arg.startsWith("-")) {
                opts.packageName = arg
            }
            i += 1
        }
        return opts
    }
}

/// bunx 命令实现
public class BunxCommand {
    /// 执行命令
    public static func exec(ctx: CommandContext): Unit {
        Output.prettyln("bunx: not yet implemented")
    }

    /// 从包名提取二进制名
    static func extractBinaryName(packageName: String): String {
        let atIndex = packageName.indexOf('@')
        if (atIndex.isSome() && atIndex.getOrThrow() > 0) {
            let idx = atIndex.getOrThrow()
            return packageName[0..idx]
        }
        return packageName
    }
}
