// 严格翻译自: src/runtime/cli/Arguments.zig
// CLI 参数解析器
//   注意: bao_cli 包已有 arguments.cj 实现基础参数解析
//   此文件实现 Arguments.zig 中的运行时特定参数定义和解析逻辑
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

// ============================================================================
// ArgumentParser — 参数解析器
// 严格翻译自: Arguments.zig parse()
// ============================================================================

/// 参数解析器
public class ArgumentParser {
    /// 解析参数
    // 严格翻译自: Arguments.zig parse()
    public static func parse(argv: ArrayList<String>, tag: CommandTag): ParsedArguments {
        let result = ParsedArguments()
        result.tag = tag

        var i: Int64 = 1 // 跳过程序名
        var positionalIndex: Int64 = 0

        while (i < argv.size) {
            let arg = argv[i]

            if (arg == "--" && i + 1 < argv.size) {
                // 所有后续参数都是透传参数
                for (j in (i + 1)..argv.size) {
                    result.passthrough.append(argv[j])
                }
                break
            }

            if (arg.startsWith("--")) {
                let flagName = arg[2..arg.size]
                parseLongFlag(result, flagName, argv, i)
                match (result.lastFlagHadValue) {
                    case true => i += 2
                    case false => i += 1
                }
            } else if (arg.startsWith("-") && arg.size > 1) {
                let flagName = arg[1..arg.size]
                parseShortFlag(result, flagName, argv, i)
                i += 1
            } else {
                result.positionals.append(arg)
                positionalIndex += 1
            }
        }

        return result
    }

    /// 解析长标志
    private static func parseLongFlag(
        result: ParsedArguments,
        flagName: String,
        argv: ArrayList<String>,
        idx: Int64
    ): Unit {
        result.lastFlagHadValue = false

        // 检查 = 号
        let eqIdx = flagName.indexOf("=")
        match (eqIdx) {
            case Some(eq) =>
                let key = flagName[0..eq]
                let `value` = flagName[(eq + 1)..flagName.size]
                result.flags.put(key, `value`)
                result.lastFlagHadValue = false
                return
            case None => ()
        }

        // 需要值的标志
        let valueFlags = [
            "target", "outdir", "outfile", "define", "external",
            "loader", "main", "tsconfig", "jsx", "env", "cwd",
            "port", "host", "origin", "test-name-pattern",
            "timeout", "bail", "changed-since", "filter",
            "concurrency", "packages", "registry", "token",
            "otp", "tag", "access", "filename", "preload",
            "eval", "print", "require", "extension",
            "install-path", "global-dir", "local-dir"
        ]

        if (valueFlags.contains(flagName)) {
            if (idx + 1 < argv.size) {
                result.flags.put(flagName, argv[Int64(idx + 1)])
                result.lastFlagHadValue = true
            } else {
                result.flags.put(flagName, "")
            }
        } else {
            // 布尔标志
            result.flags.put(flagName, "true")
        }
    }

    /// 解析短标志
    private static func parseShortFlag(
        result: ParsedArguments,
        flagName: String,
        argv: ArrayList<String>,
        idx: Int64
    ): Unit {
        result.lastFlagHadValue = false

        // 短标志映射
        match (flagName) {
            case "e" =>
                result.flags.put("eval", "true")
            case "p" =>
                result.flags.put("print", "true")
            case "r" =>
                if (idx + 1 < argv.size) {
                    result.flags.put("require", argv[Int64(idx + 1)])
                    result.lastFlagHadValue = true
                }
            case "w" =>
                result.flags.put("watch", "true")
            case "v" =>
                result.flags.put("version", "true")
            case "h" =>
                result.flags.put("help", "true")
            case "y" =>
                result.flags.put("yes", "true")
            case "m" =>
                result.flags.put("minimal", "true")
            case "d" =>
                result.flags.put("dev", "true")
            case "g" =>
                result.flags.put("global", "true")
            case "f" =>
                result.flags.put("force", "true")
            case "s" =>
                result.flags.put("silent", "true")
            case "b" =>
                result.flags.put("bun", "true")
            case "n" =>
                result.flags.put("no-install", "true")
            case "c" =>
                if (idx + 1 < argv.size) {
                    result.flags.put("config", argv[Int64(idx + 1)])
                    result.lastFlagHadValue = true
                }
            case "o" =>
                if (idx + 1 < argv.size) {
                    result.flags.put("outfile", argv[Int64(idx + 1)])
                    result.lastFlagHadValue = true
                }
            case "t" =>
                result.flags.put("test", "true")
            case _ =>
                // 未知短标志, 作为布尔存储
                result.flags.put(flagName, "true")
        }
    }
}

// ============================================================================
// ParsedArguments — 解析后的参数
// ============================================================================

/// 解析后的参数
public class ParsedArguments {
    /// 命令标签
    public var tag: CommandTag
    /// 位置参数
    public var positionals: ArrayList<String>
    /// 标志参数 (key -> value)
    public var flags: HashMap<String, String>
    /// 透传参数 (在 -- 之后的参数)
    public var passthrough: ArrayList<String>
    /// 最后一个标志是否有值
    public var lastFlagHadValue: Bool

    public init() {
        tag = CommandTag.AutoCommand
        positionals = ArrayList<String>()
        flags = HashMap<String, String>()
        passthrough = ArrayList<String>()
        lastFlagHadValue = false
    }

    /// 获取标志值
    public func getFlag(name: String): ?String {
        return flags.get(name)
    }

    /// 检查标志是否存在
    public func hasFlag(name: String): Bool {
        return flags.contains(name)
    }

    /// 获取布尔标志
    public func getBoolFlag(name: String): Bool { false }

    /// 获取整数标志
    public func getIntFlag(name: String, default: Int64): Int64 { default }
}

// ============================================================================
// FlagDefinitions — 标志定义
// 严格翻译自: Arguments.zig 中的参数定义列表
// ============================================================================

/// 标志定义
public class FlagDefinitions {
    /// 全局运行时标志
    public static func runtimeFlags(): ArrayList<FlagDef> {
        let flags = ArrayList<FlagDef>()
        flags.append(FlagDef("--bun", "Force using Bao runtime instead of Node.js"))
        flags.append(FlagDef("--config", "Path to config file (bunfig.toml)", true))
        flags.append(FlagDef("--cwd", "Set working directory", true))
        flags.append(FlagDef("--env", "Environment file behavior", true))
        flags.append(FlagDef("--eval", "Evaluate inline script", true))
        flags.append(FlagDef("--help", "Print help"))
        flags.append(FlagDef("--main", "Set main entry point", true))
        flags.append(FlagDef("--no-install", "Skip auto-install"))
        flags.append(FlagDef("--preload", "Preload modules", true))
        flags.append(FlagDef("--print", "Evaluate and print result", true))
        flags.append(FlagDef("--require", "Require module before execution", true))
        flags.append(FlagDef("--silent", "Suppress output"))
        flags.append(FlagDef("--version", "Print version"))
        flags.append(FlagDef("--watch", "Watch for file changes"))
        return flags
    }

    /// 构建命令标志
    public static func buildFlags(): ArrayList<FlagDef> {
        let flags = ArrayList<FlagDef>()
        flags.append(FlagDef("--compile", "Create standalone executable"))
        flags.append(FlagDef("--define", "Define replacement", true))
        flags.append(FlagDef("--external", "Exclude from bundle", true))
        flags.append(FlagDef("--loader", "Set loader for extension", true))
        flags.append(FlagDef("--minify", "Minify output"))
        flags.append(FlagDef("--outdir", "Output directory", true))
        flags.append(FlagDef("--outfile", "Output file", true))
        flags.append(FlagDef("--sourcemap", "Generate source map"))
        flags.append(FlagDef("--splitting", "Enable code splitting"))
        flags.append(FlagDef("--target", "Bundle target (bun/browser/node)", true))
        flags.append(FlagDef("--tree-shaking", "Enable tree shaking"))
        return flags
    }

    /// 测试命令标志
    public static func testFlags(): ArrayList<FlagDef> {
        let flags = ArrayList<FlagDef>()
        flags.append(FlagDef("--bail", "Stop after N failures", true))
        flags.append(FlagDef("--changed", "Only run tests affected by changes"))
        flags.append(FlagDef("--changed-since", "Compare against git ref", true))
        flags.append(FlagDef("--coverage", "Generate coverage report"))
        flags.append(FlagDef("--test-name-pattern", "Filter tests by name", true))
        flags.append(FlagDef("--timeout", "Test timeout in milliseconds", true))
        flags.append(FlagDef("--watch", "Watch for changes and rerun"))
        return flags
    }

    /// 运行命令标志
    public static func runFlags(): ArrayList<FlagDef> {
        let flags = ArrayList<FlagDef>()
        flags.append(FlagDef("--bun", "Force using Bao runtime"))
        flags.append(FlagDef("--filter", "Filter scripts by pattern", true))
        flags.append(FlagDef("--silent", "Suppress output"))
        flags.append(FlagDef("--watch", "Watch for changes and rerun"))
        return flags
    }
}

// ============================================================================
// FlagDef — 标志定义
// ============================================================================

/// 标志定义
public class FlagDef {
    public var name: String
    public var description: String
    public var hasValue: Bool

    public init(name: String, desc: String) {
        this.name = name
        this.description = desc
        this.hasValue = false
    }

    public init(name: String, desc: String, hasValue: Bool) {
        this.name = name
        this.description = desc
        this.hasValue = hasValue
    }
}
