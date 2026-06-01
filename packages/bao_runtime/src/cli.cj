// 严格翻译自: src/runtime/cli/cli.zig
// CLI 入口点 — 命令路由和参数解析
//   Bun CLI 主入口, 负责命令分发、参数解析和帮助信息显示
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

// ============================================================================
// 全局变量
// 严格翻译自: cli.zig 全局变量
// ============================================================================

/// 启动时间
public var startTime: Int64 = 0

/// 进程标题
public var processTitle: ?String = None

/// 是否假装为 Node.js
// 严格翻译自: cli.zig pretend_to_be_node
public var pretendToBeNode: Bool = false

/// 是否为 bunx 可执行文件
// 严格翻译自: cli.zig is_bunx_exe
public var isBunxExe: Bool = false

// ============================================================================
// CommandTag — 命令标签枚举
// 严格翻译自: options_types/CommandTag.zig Tag
// ============================================================================

/// 命令标签
public enum CommandTag {
    | AutoCommand
    | RunCommand
    | RunAsNodeCommand
    | BuildCommand
    | TestCommand
    | BunxCommand
    | ReplCommand
    | ExecCommand
    | InstallCommand
    | AddCommand
    | RemoveCommand
    | UpdateCommand
    | PatchCommand
    | PatchCommitCommand
    | OutdatedCommand
    | UpdateInteractiveCommand
    | PublishCommand
    | AuditCommand
    | CreateCommand
    | InitCommand
    | UpgradeCommand
    | HelpCommand
    | DiscordCommand
    | ReservedCommand
    | LinkCommand
    | UnlinkCommand
    | PackageManagerCommand
    | InstallCompletionsCommand
    | GetCompletionsCommand
    | InfoCommand
    | WhyCommand
    | FuzzilliCommand

    public operator func ==(right: CommandTag): Bool {
        match (this) {
            case AutoCommand =>
                match (right) {
                    case AutoCommand => true
                    case _ => false
                }
            case RunCommand =>
                match (right) {
                    case RunCommand => true
                    case _ => false
                }
            case RunAsNodeCommand =>
                match (right) {
                    case RunAsNodeCommand => true
                    case _ => false
                }
            case BuildCommand =>
                match (right) {
                    case BuildCommand => true
                    case _ => false
                }
            case TestCommand =>
                match (right) {
                    case TestCommand => true
                    case _ => false
                }
            case BunxCommand =>
                match (right) {
                    case BunxCommand => true
                    case _ => false
                }
            case ReplCommand =>
                match (right) {
                    case ReplCommand => true
                    case _ => false
                }
            case ExecCommand =>
                match (right) {
                    case ExecCommand => true
                    case _ => false
                }
            case InstallCommand =>
                match (right) {
                    case InstallCommand => true
                    case _ => false
                }
            case AddCommand =>
                match (right) {
                    case AddCommand => true
                    case _ => false
                }
            case RemoveCommand =>
                match (right) {
                    case RemoveCommand => true
                    case _ => false
                }
            case UpdateCommand =>
                match (right) {
                    case UpdateCommand => true
                    case _ => false
                }
            case PatchCommand =>
                match (right) {
                    case PatchCommand => true
                    case _ => false
                }
            case PatchCommitCommand =>
                match (right) {
                    case PatchCommitCommand => true
                    case _ => false
                }
            case OutdatedCommand =>
                match (right) {
                    case OutdatedCommand => true
                    case _ => false
                }
            case UpdateInteractiveCommand =>
                match (right) {
                    case UpdateInteractiveCommand => true
                    case _ => false
                }
            case PublishCommand =>
                match (right) {
                    case PublishCommand => true
                    case _ => false
                }
            case AuditCommand =>
                match (right) {
                    case AuditCommand => true
                    case _ => false
                }
            case CreateCommand =>
                match (right) {
                    case CreateCommand => true
                    case _ => false
                }
            case InitCommand =>
                match (right) {
                    case InitCommand => true
                    case _ => false
                }
            case UpgradeCommand =>
                match (right) {
                    case UpgradeCommand => true
                    case _ => false
                }
            case HelpCommand =>
                match (right) {
                    case HelpCommand => true
                    case _ => false
                }
            case DiscordCommand =>
                match (right) {
                    case DiscordCommand => true
                    case _ => false
                }
            case ReservedCommand =>
                match (right) {
                    case ReservedCommand => true
                    case _ => false
                }
            case LinkCommand =>
                match (right) {
                    case LinkCommand => true
                    case _ => false
                }
            case UnlinkCommand =>
                match (right) {
                    case UnlinkCommand => true
                    case _ => false
                }
            case PackageManagerCommand =>
                match (right) {
                    case PackageManagerCommand => true
                    case _ => false
                }
            case InstallCompletionsCommand =>
                match (right) {
                    case InstallCompletionsCommand => true
                    case _ => false
                }
            case GetCompletionsCommand =>
                match (right) {
                    case GetCompletionsCommand => true
                    case _ => false
                }
            case InfoCommand =>
                match (right) {
                    case InfoCommand => true
                    case _ => false
                }
            case WhyCommand =>
                match (right) {
                    case WhyCommand => true
                    case _ => false
                }
            case FuzzilliCommand =>
                match (right) {
                    case FuzzilliCommand => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: CommandTag): Bool {
        !(this == right)
    }

    /// 获取命令名称字符串
    public func toString(): String {
        match (this) {
            case AutoCommand => "auto"
            case RunCommand => "run"
            case RunAsNodeCommand => "run-as-node"
            case BuildCommand => "build"
            case TestCommand => "test"
            case BunxCommand => "x"
            case ReplCommand => "repl"
            case ExecCommand => "exec"
            case InstallCommand => "install"
            case AddCommand => "add"
            case RemoveCommand => "remove"
            case UpdateCommand => "update"
            case PatchCommand => "patch"
            case PatchCommitCommand => "patch-commit"
            case OutdatedCommand => "outdated"
            case UpdateInteractiveCommand => "update-interactive"
            case PublishCommand => "publish"
            case AuditCommand => "audit"
            case CreateCommand => "create"
            case InitCommand => "init"
            case UpgradeCommand => "upgrade"
            case HelpCommand => "help"
            case DiscordCommand => "discord"
            case ReservedCommand => "reserved"
            case LinkCommand => "link"
            case UnlinkCommand => "unlink"
            case PackageManagerCommand => "pm"
            case InstallCompletionsCommand => "completions"
            case GetCompletionsCommand => "getcompletes"
            case InfoCommand => "info"
            case WhyCommand => "why"
            case FuzzilliCommand => "fuzzilli"
        }
    }

    /// 是否使用全局选项
    public func usesGlobalOptions(): Bool {
        match (this) {
            case HelpCommand => false
            case DiscordCommand => false
            case ReservedCommand => false
            case _ => true
        }
    }
}

// ============================================================================
// HelpReason — 帮助显示原因
// 严格翻译自: cli.zig HelpCommand.Reason
// ============================================================================

/// 帮助显示原因
public enum HelpReason {
    | Explicit
    | InvalidCommand

    public operator func ==(right: HelpReason): Bool {
        match (this) {
            case Explicit =>
                match (right) {
                    case Explicit => true
                    case _ => false
                }
            case InvalidCommand =>
                match (right) {
                    case InvalidCommand => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: HelpReason): Bool {
        !(this == right)
    }
}

// ============================================================================
// HelpCommand — 帮助命令
// 严格翻译自: cli.zig HelpCommand
// ============================================================================

/// 帮助命令
public class HelpCommand {
    /// 要移除的包示例列表
    static let PACKAGES_TO_REMOVE: Array<String> = [
        "moment", "underscore", "jquery", "backbone", "redux",
        "browserify", "webpack", "left-pad", "is-array",
        "babel-core", "@parcel/core"
    ]

    /// 要添加的包示例列表
    static let PACKAGES_TO_ADD: Array<String> = [
        "elysia", "@shumai/shumai", "hono", "react", "lyra",
        "@remix-run/dev", "@evan/duckdb", "@zarfjs/zarf", "zod", "tailwindcss"
    ]

    /// 要用 x 执行的包示例列表
    static let PACKAGES_TO_X: Array<String> = [
        "bun-repl", "next", "vite", "prisma", "nuxi", "prettier", "eslint"
    ]

    /// 要创建的模板示例列表
    static let PACKAGES_TO_CREATE: Array<String> = [
        "next-app", "vite", "astro", "svelte", "elysia"
    ]

    /// 执行帮助命令
    public static func exec(): Unit {
        printWithReason(HelpReason.Explicit, false)
        Global.exit(0)
    }

    /// 按指定原因执行帮助命令
    public static func execWithReason(reason: HelpReason): Unit {
        printWithReason(reason, false)
        if (reason == HelpReason.InvalidCommand) {
            Global.exit(1)
        }
        Global.exit(0)
    }

    /// 打印帮助信息
    public static func printWithReason(reason: HelpReason, showAllFlags: Bool): Unit {
        // 随机选择示例包名
        let packageX = PACKAGES_TO_X[0]
        let packageAdd = PACKAGES_TO_ADD[0]
        let packageRemove = PACKAGES_TO_REMOVE[0]
        let packageCreate = PACKAGES_TO_CREATE[0]

        match (reason) {
            case HelpReason.Explicit =>
                Output.prettyln("Bao is a fast JavaScript runtime, package manager, bundler, and test runner. (" +
                    Global.PACKAGE_JSON_VERSION + ")\n")
                Output.prettyln("Usage: bao <command> [...flags] [...args]\n")
                Output.prettyln("Commands:")
                Output.prettyln("  run       ./my-script.ts       Execute a file with Bao")
                Output.prettyln("            lint                  Run a package.json script")
                Output.prettyln("  test                            Run unit tests with Bao")
                Output.prettyln("  x         ${packageX}           Execute a package binary (CLI), installing if needed")
                Output.prettyln("  repl                            Start a REPL session with Bao")
                Output.prettyln("  exec                            Run a shell script directly with Bao")
                Output.prettyln("")
                Output.prettyln("  install                         Install dependencies for a package.json")
                Output.prettyln("  add       ${packageAdd}         Add a dependency to package.json")
                Output.prettyln("  remove    ${packageRemove}      Remove a dependency from package.json")
                Output.prettyln("  update                          Update outdated dependencies")
                Output.prettyln("  audit                           Check installed packages for vulnerabilities")
                Output.prettyln("  outdated                        Display latest versions of outdated dependencies")
                Output.prettyln("  link      [package]             Register or link a local npm package")
                Output.prettyln("  unlink                          Unregister a local npm package")
                Output.prettyln("  publish                         Publish a package to the npm registry")
                Output.prettyln("")
                Output.prettyln("  build     ./a.ts ./b.jsx        Bundle TypeScript & JavaScript")
                Output.prettyln("")
                Output.prettyln("  init                            Start an empty Bao project from a template")
                Output.prettyln("  create    ${packageCreate}      Create a new project from a template")
                Output.prettyln("  upgrade                         Upgrade to latest version of Bao")
                Output.prettyln("")
                Output.prettyln("  <command> --help                Print help text for command.")
                Output.prettyln("")
                Output.prettyln("Learn more about Bao: https://bao.dev/docs")
            case HelpReason.InvalidCommand =>
                Output.prettyErrorln("Uh-oh not sure what to do with that command.\n")
                Output.prettyln("Usage: bao <command> [...flags] [...args]\n")
                Output.prettyln("Commands:")
                Output.prettyln("  run       Execute a file with Bao")
                Output.prettyln("  test      Run unit tests with Bao")
                Output.prettyln("  install   Install dependencies")
                Output.prettyln("  add       Add a dependency")
                Output.prettyln("  remove    Remove a dependency")
                Output.prettyln("  build     Bundle TypeScript & JavaScript")
                Output.prettyln("  create    Create a new project from a template")
                Output.prettyln("  upgrade   Upgrade to latest version")
        }
        Output.flush()
    }
}

// ============================================================================
// ReservedCommand — 保留命令
// 严格翻译自: cli.zig ReservedCommand
// ============================================================================

/// 保留命令 (供将来使用)
public class ReservedCommand {
    public static func exec(): Unit {
        let argv = Global.argv
        var commandName = ""
        if (argv.size > 1) {
            commandName = argv[1]
        }

        Output.prettyErrorln("Uh-oh. bao ${commandName} is a subcommand reserved for future use by Bao.")
        Output.prettyErrorln("If you were trying to run a package.json script called ${commandName}, use bao run ${commandName}.")
        Output.flush()
        Global.exit(1)
    }
}

// ============================================================================
// BaoCli — CLI 主入口
// 严格翻译自: cli.zig Cli + Command
// ============================================================================

/// CLI 主入口
public class BaoCli {
    /// 启动 CLI
    // 严格翻译自: cli.zig Cli.start()
    public static func start(): Unit {
        startTime = 0  // TODO: use proper nanoTime API
        let argvArray = Global.argv
        let argv = ArrayList<String>(argvArray)

        // 确定命令标签
        let tag = which(argv)

        // 按标签路由到对应的命令处理器
        match (tag) {
            case CommandTag.HelpCommand =>
                HelpCommand.exec()
            case CommandTag.ReservedCommand =>
                ReservedCommand.exec()
            case CommandTag.DiscordCommand =>
                Output.prettyln("Join our community: https://discord.gg/bao")
                Output.flush()
            case CommandTag.InitCommand =>
                let ctx = CommandContext(tag)
                InitCommand.exec(ctx)
            case CommandTag.BuildCommand =>
                let ctx = CommandContext(tag)
                BuildCommand.exec(ctx)
            case CommandTag.InstallCommand =>
                let ctx = CommandContext(tag)
                Output.prettyln("bao install - not yet implemented")
            case CommandTag.AddCommand =>
                let ctx = CommandContext(tag)
                AddCommand.exec(ctx)
            case CommandTag.RemoveCommand =>
                let ctx = CommandContext(tag)
                RemoveCommand.exec(ctx)
            case CommandTag.UpdateCommand =>
                let ctx = CommandContext(tag)
                UpdateCommand.exec(ctx)
            case CommandTag.OutdatedCommand =>
                let ctx = CommandContext(tag)
                OutdatedCommand.exec(ctx)
            case CommandTag.UpdateInteractiveCommand =>
                let ctx = CommandContext(tag)
                UpdateInteractiveCommand.exec(ctx)
            case CommandTag.PublishCommand =>
                let ctx = CommandContext(tag)
                Output.prettyln("bao publish - not yet implemented")
            case CommandTag.AuditCommand =>
                let ctx = CommandContext(tag)
                AuditCommand.exec(ctx)
            case CommandTag.WhyCommand =>
                let ctx = CommandContext(tag)
                Output.prettyln("bao why - not yet implemented")
            case CommandTag.BunxCommand =>
                let ctx = CommandContext(tag)
                BunxCommand.exec(ctx)
            case CommandTag.ReplCommand =>
                let ctx = CommandContext(tag)
                Output.prettyln("bao repl - not yet implemented")
            case CommandTag.TestCommand =>
                let ctx = CommandContext(tag)
                TestCommandImpl.exec(ctx)
            case CommandTag.CreateCommand =>
                CreateCommandHandler.exec()
            case CommandTag.RunCommand =>
                let ctx = CommandContext(tag)
                RunCommand.exec(ctx)
            case CommandTag.RunAsNodeCommand =>
                let ctx = CommandContext(tag)
                RunCommand.execAsIfNode(ctx)
            case CommandTag.UpgradeCommand =>
                let ctx = CommandContext(tag)
                Output.prettyln("bao upgrade - not yet implemented")
            case CommandTag.ExecCommand =>
                let ctx = CommandContext(tag)
                ExecCommand.exec(ctx)
            case CommandTag.PackageManagerCommand =>
                let ctx = CommandContext(tag)
                Output.prettyln("bao pm - not yet implemented")
            case CommandTag.LinkCommand =>
                let ctx = CommandContext(tag)
                Output.prettyln("bao link - not yet implemented")
            case CommandTag.UnlinkCommand =>
                let ctx = CommandContext(tag)
                Output.prettyln("bao unlink - not yet implemented")
            case CommandTag.InstallCompletionsCommand =>
                Output.prettyln("bao completions - not yet implemented")
            case CommandTag.GetCompletionsCommand =>
                Output.prettyln("bao get-completions - not yet implemented")
            case CommandTag.InfoCommand =>
                Output.prettyln("bao info - not yet implemented")
            case CommandTag.AutoCommand =>
                handleAutoCommand()
            case CommandTag.FuzzilliCommand =>
                Output.errGeneric("Fuzzilli is not available in this build")
                Global.exit(1)
            case CommandTag.PatchCommand =>
                let ctx = CommandContext(tag)
                PatchCommand.exec(ctx)
            case CommandTag.PatchCommitCommand =>
                let ctx = CommandContext(tag)
                PatchCommitCommand.exec(ctx)
        }
    }

    /// 确定命令标签
    // 严格翻译自: cli.zig Command.which()
    public static func which(argv: ArrayList<String>): CommandTag {
        if (argv.size == 0) {
            return CommandTag.HelpCommand
        }

        let argv0 = argv[0]

        // 检查是否为 bunx
        if (isBunX(argv0)) {
            isBunxExe = true
            return CommandTag.BunxCommand
        }

        // 检查是否为 node
        if (isNode(argv0)) {
            pretendToBeNode = true
            return CommandTag.RunAsNodeCommand
        }

        // 获取第一个非标志参数
        var argIdx: Int64 = 1
        var nextArg: ?String = None
        while (argIdx < argv.size) {
            let arg = argv[argIdx]
            if (arg.size > 0 && arg[0..1] == "-" && !(arg.size > 1 && arg[1..2] == "e")) {
                argIdx++
                continue
            }
            nextArg = arg
            break
        }

        let firstArgName = match (nextArg) {
            case Some(arg) => arg
            case None => return CommandTag.AutoCommand
        }

        // 匹配命令名
        return matchCommand(firstArgName, argv)
    }

    /// 匹配命令名到标签
    private static func matchCommand(name: String, argv: ArrayList<String>): CommandTag {
        match (name) {
            case "init" => return CommandTag.InitCommand
            case "build" => return CommandTag.BuildCommand
            case "bun" => return CommandTag.BuildCommand
            case "discord" => return CommandTag.DiscordCommand
            case "upgrade" => return CommandTag.UpgradeCommand
            case "completions" => return CommandTag.InstallCompletionsCommand
            case "getcompletes" => return CommandTag.GetCompletionsCommand
            case "link" => return CommandTag.LinkCommand
            case "unlink" => return CommandTag.UnlinkCommand
            case "x" => return CommandTag.BunxCommand
            case "repl" => return CommandTag.ReplCommand
            case "i" => return checkGlobalFlag(argv)
            case "install" => return checkGlobalFlag(argv)
            case "ci" => return CommandTag.InstallCommand
            case "c" => return CommandTag.CreateCommand
            case "create" => return CommandTag.CreateCommand
            case "test" => return CommandTag.TestCommand
            case "pm" => return CommandTag.PackageManagerCommand
            case "add" => return CommandTag.AddCommand
            case "a" => return CommandTag.AddCommand
            case "update" => return CommandTag.UpdateCommand
            case "patch" => return CommandTag.PatchCommand
            case "patch-commit" => return CommandTag.PatchCommitCommand
            case "r" => return CommandTag.RemoveCommand
            case "remove" => return CommandTag.RemoveCommand
            case "rm" => return CommandTag.RemoveCommand
            case "uninstall" => return CommandTag.RemoveCommand
            case "run" => return CommandTag.RunCommand
            case "help" => return CommandTag.HelpCommand
            case "exec" => return CommandTag.ExecCommand
            case "outdated" => return CommandTag.OutdatedCommand
            case "publish" => return CommandTag.PublishCommand
            case "audit" => return CommandTag.AuditCommand
            case "info" => return CommandTag.InfoCommand
            case "deploy" => return CommandTag.ReservedCommand
            case "cloud" => return CommandTag.ReservedCommand
            case "config" => return CommandTag.ReservedCommand
            case "use" => return CommandTag.ReservedCommand
            case "auth" => return CommandTag.ReservedCommand
            case "login" => return CommandTag.ReservedCommand
            case "logout" => return CommandTag.ReservedCommand
            case "whoami" => return CommandTag.PackageManagerCommand
            case "prune" => return CommandTag.ReservedCommand
            case "list" => return CommandTag.PackageManagerCommand
            case "why" => return CommandTag.WhyCommand
            case "fuzzilli" => return CommandTag.FuzzilliCommand
            case _ => return CommandTag.AutoCommand
        }
    }

    /// 检查是否有 --global 标志, 决定是安装还是添加命令
    private static func checkGlobalFlag(argv: ArrayList<String>): CommandTag {
        for (arg in argv) {
            if (arg == "-g" || arg == "--global") {
                return CommandTag.AddCommand
            }
        }
        return CommandTag.InstallCommand
    }

    /// 判断是否为 bunx 可执行文件名
    private static func isBunX(argv0: String): Bool {
        return argv0.endsWith("bunx") || argv0.endsWith("bunx.exe")
    }

    /// 判断是否为 node 可执行文件名
    private static func isNode(argv0: String): Bool {
        return argv0.endsWith("node") || argv0.endsWith("node.exe")
    }

    /// 处理自动命令 (无明确命令时的默认行为)
    private static func handleAutoCommand(): Unit {
        let ctx = CommandContext(CommandTag.AutoCommand)

        // 如果有位置参数, 尝试作为运行命令
        if (ctx.positionals.size > 0) {
            RunCommand.exec(ctx)
            return
        }

        // 否则显示帮助
        HelpCommand.execWithReason(HelpReason.Explicit)
    }
}

// ============================================================================
// CommandContext — 命令上下文
// 严格翻译自: options_types/Context.zig Context
// ============================================================================

/// 命令上下文
public class CommandContext {
    /// 命令标签
    public var tag: CommandTag
    /// 位置参数
    public var positionals: ArrayList<String>
    /// 标志参数
    public var flags: HashMap<String, String>
    /// 透传参数 (入口点之后的参数)
    public var passthrough: ArrayList<String>
    /// 当前工作目录
    public var cwd: String
    /// 入口点
    public var entryPoints: ArrayList<String>
    /// 命令行参数原始列表
    public var argv: ArrayList<String>
    /// 调试选项
    public var debug: DebugOptions
    /// 测试选项
    public var testOptions: TestCliOptions
    /// 运行时选项
    public var runtimeOptions: RuntimeCliOptions
    /// 是否并行执行
    public var parallel: Bool
    /// 是否串行执行
    public var sequential: Bool
    /// 过滤器
    public var filters: ArrayList<String>
    /// 是否使用 workspaces
    public var workspaces: Bool
    /// 源映射选项
    public var sourceMap: SourceMapOption
    /// 最小化选项
    public var minify: Bool
    /// 目标平台
    public var target: BundleTarget

    public init(tag: CommandTag) {
        this.tag = tag
        this.positionals = ArrayList<String>()
        this.flags = HashMap<String, String>()
        this.passthrough = ArrayList<String>()
        this.cwd = OS.getcwd()
        this.entryPoints = ArrayList<String>()
        this.argv = ArrayList<String>(Global.argv)
        this.debug = DebugOptions()
        this.testOptions = TestCliOptions()
        this.runtimeOptions = RuntimeCliOptions()
        this.parallel = false
        this.sequential = false
        this.filters = ArrayList<String>()
        this.workspaces = false
        this.sourceMap = SourceMapOption.None
        this.minify = false
        this.target = BundleTarget.Bun

        // 解析参数
        parseArgs()
    }

    /// 解析命令行参数
    private func parseArgs(): Unit {
        let argv = Global.argv
        var foundCommand = false
        var i: Int64 = 0

        while (i < argv.size) {
            let arg = argv[i]

            // 跳过程序名
            if (i == 0) {
                i++
                continue
            }

            // 跳过命令名
            if (!foundCommand) {
                foundCommand = true
                // 如果命令本身就是一个子命令的标识符, 继续处理
                if (!arg.startsWith("-")) {
                    i++
                    continue
                }
            }

            // 处理标志
            if (arg.startsWith("--")) {
                let flagName = arg[2..arg.size]
                let eqIdx = flagName.indexOf("=")
                match (eqIdx) {
                    case Some(idx) =>
                        let key = flagName[0..idx]
                        let `value` = flagName[(idx + 1)..flagName.size]
                        flags.put(key, `value`)
                    case None =>
                        if (i + 1 < argv.size && !argv[Int64(i + 1)].startsWith("-")) {
                            flags.put(flagName, argv[Int64(i + 1)])
                            i++
                        } else {
                            flags.put(flagName, "true")
                        }
                }
            } else if (arg.startsWith("-") && arg.size > 1) {
                let flagName = arg[1..arg.size]
                flags.put(flagName, "true")
            } else {
                // 位置参数
                positionals.append(arg)
            }
            i++
        }

        // 处理常见标志
        if (flags.contains("minify")) { minify = true }
        if (flags.contains("sourcemap")) { sourceMap = SourceMapOption.External }
        if (flags.contains("parallel")) { parallel = true }
        if (flags.contains("sequential")) { sequential = true }
        if (flags.contains("workspaces")) { workspaces = true }

        // 入口点来自位置参数
        entryPoints = positionals
    }
}

// ============================================================================
// DebugOptions — 调试选项
// 严格翻译自: options_types/Context.zig DebugOptions
// ============================================================================

/// 调试选项
public class DebugOptions {
    public var hotReload: HotReloadMode
    public var globalCache: GlobalCacheOption
    public var verbose: Bool

    public init() {
        hotReload = HotReloadMode.None
        globalCache = GlobalCacheOption.Auto
        verbose = false
    }
}

/// 热重载模式
public enum HotReloadMode {
    | None
    | Watch
    | Hot

    public operator func ==(right: HotReloadMode): Bool {
        match (this) {
            case None =>
                match (right) {
                    case None => true
                    case _ => false
                }
            case Watch =>
                match (right) {
                    case Watch => true
                    case _ => false
                }
            case Hot =>
                match (right) {
                    case Hot => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: HotReloadMode): Bool {
        !(this == right)
    }
}

/// 全局缓存选项
public enum GlobalCacheOption {
    | Auto
    | Disable
    | Enable

    public operator func ==(right: GlobalCacheOption): Bool {
        match (this) {
            case Auto =>
                match (right) {
                    case Auto => true
                    case _ => false
                }
            case Disable =>
                match (right) {
                    case Disable => true
                    case _ => false
                }
            case Enable =>
                match (right) {
                    case Enable => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: GlobalCacheOption): Bool {
        !(this == right)
    }
}

// ============================================================================
// TestCliOptions — 测试选项
// ============================================================================

/// 测试选项
public class TestCliOptions {
    public var testNamePattern: ?String
    public var testTimeout: Int64
    public var coverage: Bool
    public var bail: Int64
    public var changed: Bool
    public var changedSince: String

    public init() {
        testNamePattern = None
        testTimeout = 5000
        coverage = false
        bail = 0
        changed = false
        changedSince = ""
    }
}

// ============================================================================
// RuntimeCliOptions — 运行时选项
// ============================================================================

/// 运行时选项
public class RuntimeCliOptions {
    public var eval: EvalOptions
    public var ifPresent: Bool
    public var noInstall: Bool

    public init() {
        eval = EvalOptions()
        ifPresent = false
        noInstall = false
    }
}

/// 评估选项
public class EvalOptions {
    public var script: String
    public var print: Bool

    public init() {
        script = ""
        print = false
    }
}

// ============================================================================
// SourceMapOption — Source Map 选项
// ============================================================================

/// Source Map 选项
public enum SourceMapOption {
    | None
    | External
    | Inline
    | Linked

    public operator func ==(right: SourceMapOption): Bool {
        match (this) {
            case None =>
                match (right) {
                    case None => true
                    case _ => false
                }
            case External =>
                match (right) {
                    case External => true
                    case _ => false
                }
            case Inline =>
                match (right) {
                    case Inline => true
                    case _ => false
                }
            case Linked =>
                match (right) {
                    case Linked => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: SourceMapOption): Bool {
        !(this == right)
    }
}

// ============================================================================
// BundleTarget — 打包目标
// ============================================================================

/// 打包目标
public enum BundleTarget {
    | Bun
    | Browser
    | Node

    public operator func ==(right: BundleTarget): Bool {
        match (this) {
            case Bun =>
                match (right) {
                    case Bun => true
                    case _ => false
                }
            case Browser =>
                match (right) {
                    case Browser => true
                    case _ => false
                }
            case Node =>
                match (right) {
                    case Node => true
                    case _ => false
                }
        }
    }

    public operator func !=(right: BundleTarget): Bool {
        !(this == right)
    }
}

// ============================================================================
// 版本和修订号
// ============================================================================

/// 打印版本并退出
public func printVersionAndExit(): Unit {
    Output.println(Global.getPackageVersion())
    Global.exit(0)
}

/// 打印修订号并退出
public func printRevisionAndExit(): Unit {
    Output.println(Global.getPackageVersionWithRevision())
    Global.exit(0)
}

// 以下命令桩已由独立文件实现 (build_command.cj, add_command.cj 等)
// InstallCommand, RemoveCommand, UpdateCommand, CreateCommandHandler 等仍在此处

/// CreateCommandHandler — create 命令路由
public class CreateCommandHandler {

    public static func exec(): Unit {
        let argv = Global.argv
        if (argv.size <= 2) {
            HelpCommand.printWithReason(HelpReason.Explicit, false)
            Global.exit(1)
        }

        // 简化: stub create 命令
        Output.prettyln("bao create - not yet implemented")
    }
}
