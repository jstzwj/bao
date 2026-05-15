// 严格翻译自: src/cli/cli.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// Cli — CLI 入口点, 命令分发器
// 严格翻译自: src/cli/cli.zig
//
// 包含: Cli 结构体, Command.which() 命令路由,
// HelpCommand, ReservedCommand, debug_flags,
// Command.start() 主入口, Tag help 文本
// ============================================================================

/// 全局启动时间
/// 对应 Bun: start_time
public var startTime: Int128 = 0

/// Node.js 进程标题
/// 对应 Bun: Bun__Node__ProcessTitle
public var nodeProcessTitle: ?String = None

/// CLI 主结构体
/// 对应 Bun: Cli
public class Cli {
    public var log_: Log

    public init() {
        log_ = Log()
    }

    /// 启动 Transform (空实现)
    /// 对应 Bun: Cli.startTransform
    public static func startTransform(allocator: Allocator, options: TransformOptions, log: Log): Unit {
        // 空实现
    }

    /// CLI 启动入口
    /// 对应 Bun: Cli.start
    public static func start(allocator: Allocator): Unit {
        isMainThread = true
        startTime = Time.nanoTimestamp()
        val log = Log(allocator)

        try {
            Command.start(allocator, log)
        } catch (e: Exception) {
            log.print(Output.errorWriter())
            CrashHandler.handleRootError(e)
        }
    }

    /// 当前命令标签
    /// 对应 Bun: Cli.cmd
    public static var cmd: ?CommandTag = None

    /// 是否为主线程
    /// 对应 Bun: Cli.is_main_thread
    public static threadlocal var isMainThread: Bool = false
}

/// 调试标志
/// 对应 Bun: debug_flags
public class DebugFlags {
    public static var resolveBreakpoints: ArrayList<String> = ArrayList<String>()
    public static var printBreakpoints: ArrayList<String> = ArrayList<String>()

    public static func hasResolveBreakpoint(s: String): Bool {
        for (bp in resolveBreakpoints) {
            if (s.contains(bp)) {
                return true
            }
        }
        return false
    }

    public static func hasPrintBreakpoint(path: FilePath): Bool {
        for (bp in printBreakpoints) {
            if (path.pretty.contains(bp)) {
                return true
            }
            if (path.text.contains(bp)) {
                return true
            }
        }
        return false
    }
}

/// Loader 冒号列表类型
/// 对应 Bun: LoaderColonList
public typealias LoaderColonList = ColonListType<Loader>

/// Define 冒号列表类型
/// 对应 Bun: DefineColonList
public typealias DefineColonList = ColonListType<String>

/// 无效目标错误
/// 对应 Bun: invalidTarget
public static func invalidTarget(target: String): Unit {
    Output.prettyErrorLn("<r><red>error:<r> Invalid target: ${target}")
    Global.exit(1)
}

// ============================================================================
// HelpCommand — 帮助命令
// ============================================================================

/// 帮助命令
/// 对应 Bun: HelpCommand
public class HelpCommand {
    /// 帮助显示原因
    /// 对应 Bun: HelpCommand.Reason
    public enum Reason {
        | explicit
        | invalidCommand
    }

    /// 执行帮助命令
    /// 对应 Bun: HelpCommand.exec()
    public static func exec(allocator: Allocator): Unit {
        execWithReason(allocator, Reason.explicit)
    }

    /// 示例包名列表 (用于 x)
    public static let packagesToXFiller: ArrayList<String> = ArrayList<String>().fromArray([
        "bao-repl", "next", "vite", "prisma", "nuxi", "prettier", "eslint"
    ])

    /// 示例包名列表 (用于 add)
    public static let packagesToAddFiller: ArrayList<String> = ArrayList<String>().fromArray([
        "elysia", "@shumai/shumai", "hono", "react", "lyra",
        "@remix-run/dev", "@evan/duckdb", "@zarfjs/zarf", "zod", "tailwindcss"
    ])

    /// 示例包名列表 (用于 remove)
    public static let packagesToRemoveFiller: ArrayList<String> = ArrayList<String>().fromArray([
        "moment", "underscore", "jquery", "backbone", "redux",
        "browserify", "webpack", "left-pad", "is-array", "babel-core", "@parcel/core"
    ])

    /// 示例包名列表 (用于 create)
    public static let packagesToCreateFiller: ArrayList<String> = ArrayList<String>().fromArray([
        "next-app", "vite", "astro", "svelte", "elysia"
    ])

    /// 按原因打印帮助
    /// 对应 Bun: HelpCommand.printWithReason
    public static func printWithReason(reason: Reason, showAllFlags: Bool): Unit {
        val rand = Random(Math.max(Time.milliTimestamp(), 0))
        val packageXI = rand.uintAtMost(packagesToXFiller.size - 1)
        val packageAddI = rand.uintAtMost(packagesToAddFiller.size - 1)
        val packageRemoveI = rand.uintAtMost(packagesToRemoveFiller.size - 1)
        val packageCreateI = rand.uintAtMost(packagesToCreateFiller.size - 1)

        val packageX = packagesToXFiller[packageXI]
        val packageAdd = packagesToAddFiller[packageAddI]
        val packageRemove = packagesToRemoveFiller[packageRemoveI]
        val packageAdd2 = packagesToAddFiller[(packageAddI + 1) % packagesToAddFiller.size]
        val packageAdd3 = packagesToAddFiller[(packageAddI + 2) % packagesToAddFiller.size]
        val packageAdd4 = packagesToAddFiller[(packageAddI + 3) % packagesToAddFiller.size]
        val packageCreate = packagesToCreateFiller[packageCreateI]

        when (reason) {
            case Reason.explicit => {
                Output.pretty("<r><b><magenta>Bao<r> is a fast JavaScript runtime, package manager, bundler, and test runner.\n\n")
                printCliHelptext(packageX, packageAdd, packageRemove, packageAdd2, packageAdd3, packageAdd4, packageCreate)
                if (showAllFlags) {
                    Output.pretty("\n<b>Flags:<r>")
                    Output.pretty("\n\n(more flags in <b>bao install --help<r>, <b>bao test --help<r>, and <b>bao build --help<r>)\n")
                }
                Output.pretty("\nLearn more about Bao:            <magenta>https://bao.dev/docs<r>\n")
                Output.pretty("Join our Discord community:      <blue>https://bao.dev/discord<r>\n\n")
            }
            case Reason.invalidCommand => {
                Output.prettyError("<r><red>Uh-oh<r> not sure what to do with that command.\n\n")
                printCliHelptext(packageX, packageAdd, packageRemove, packageAdd2, packageAdd3, packageAdd4, packageCreate)
            }
        }

        Output.flush()
    }

    /// 打印 CLI 帮助文本
    private static func printCliHelptext(
        packageX: String, packageAdd: String, packageRemove: String,
        packageAdd2: String, packageAdd3: String, packageAdd4: String,
        packageCreate: String
    ): Unit {
        Output.pretty("<b>Usage:<r> <b>bao \\<command\\> <cyan>[...flags]<r> <b>[...args]<r>\n\n")
        Output.pretty("<b>Commands:<r>\n")
        Output.pretty("  <b><magenta>run<r>       <d>./my-script.ts<r>       Execute a file with Bao\n")
        Output.pretty("            <d>lint<r>                 Run a package.json script\n")
        Output.pretty("  <b><magenta>test<r>                           Run unit tests with Bao\n")
        Output.pretty("  <b><magenta>x<r>         <d>${packageX}<r>     Execute a package binary (CLI), installing if needed <d>(baox)<r>\n")
        Output.pretty("  <b><magenta>repl<r>                           Start a REPL session with Bao\n")
        Output.pretty("  <b><magenta>exec<r>                           Run a shell script directly with Bao\n\n")
        Output.pretty("  <b><blue>install<r>                        Install dependencies for a package.json <d>(bao i)<r>\n")
        Output.pretty("  <b><blue>add<r>       <d>${packageAdd}<r>     Add a dependency to package.json <d>(bao a)<r>\n")
        Output.pretty("  <b><blue>remove<r>    <d>${packageRemove}<r>     Remove a dependency from package.json <d>(bao rm)<r>\n")
        Output.pretty("  <b><blue>update<r>    <d>${packageAdd2}<r>     Update outdated dependencies\n")
        Output.pretty("  <b><blue>audit<r>                          Check installed packages for vulnerabilities\n")
        Output.pretty("  <b><blue>outdated<r>                       Display latest versions of outdated dependencies\n")
        Output.pretty("  <b><blue>link<r>      <d>[\\<package\\>]<r>          Register or link a local npm package\n")
        Output.pretty("  <b><blue>unlink<r>                         Unregister a local npm package\n")
        Output.pretty("  <b><blue>publish<r>                        Publish a package to the npm registry\n")
        Output.pretty("  <b><blue>patch <d>\\<pkg\\><r>                    Prepare a package for patching\n")
        Output.pretty("  <b><blue>pm <d>\\<subcommand\\><r>                Additional package management utilities\n")
        Output.pretty("  <b><blue>info<r>      <d>${packageAdd3}<r>     Display package metadata from the registry\n")
        Output.pretty("  <b><blue>why<r>       <d>${packageAdd4}<r>     Explain why a package is installed\n\n")
        Output.pretty("  <b><yellow>build<r>     <d>./a.ts ./b.jsx<r>       Bundle TypeScript & JavaScript into a single file\n\n")
        Output.pretty("  <b><cyan>init<r>                           Start an empty Bao project from a built-in template\n")
        Output.pretty("  <b><cyan>create<r>    <d>${packageCreate}<r>     Create a new project from a template <d>(bao c)<r>\n")
        Output.pretty("  <b><cyan>upgrade<r>                        Upgrade to latest version of Bao.\n\n")
        Output.pretty("  <d>\\<command\\><r> <b><cyan>--help<r>               Print help text for command.\n\n")
    }

    /// 按原因执行帮助
    /// 对应 Bun: HelpCommand.execWithReason
    public static func execWithReason(allocator: Allocator, reason: Reason): Unit {
        printWithReason(reason, false)

        if (reason == Reason.invalidCommand) {
            Global.exit(1)
        }
        Global.exit(0)
    }
}

// ============================================================================
// ReservedCommand — 保留命令
// ============================================================================

/// 保留命令 (未来使用)
/// 对应 Bun: ReservedCommand
public class ReservedCommand {
    public static func exec(allocator: Allocator): Unit {
        var commandName = ""
        for (arg in BunArgv.getArgs().slice(1)) {
            if (arg.length > 1 && arg[0] == '-') {
                continue
            }
            commandName = arg
            break
        }

        if (commandName.length == 0) {
            commandName = BunArgv.getArgs()[1]
        }

        Output.prettyError(
            "<r><red>Uh-oh<r>. <b><yellow>bao ${commandName}<r> is a subcommand reserved for future use by Bao.\n\n"
        )
        Output.prettyError(
            "If you were trying to run a package.json script called ${commandName}, use <b><magenta>bao run ${commandName}<r>.\n\n"
        )
        Output.flush()
        Global.exit(1)
    }
}

/// 是否伪装为 node
/// 对应 Bun: pretend_to_be_node
public var pretendToBeNode = false

/// 是否为 bunx 可执行文件
/// 对应 Bun: is_bunx_exe
public var isBunxExe = false

// ============================================================================
// Command — 命令分发器
// ============================================================================

/// 命令分发器
/// 对应 Bun: Command
public class Command {
    /// 全局 CLI 上下文
    private static var globalCliCtx: CommandContext

    /// 获取全局上下文
    /// 对应 Bun: Command.get()
    public static func get(): CommandContext {
        return globalCliCtx
    }

    /// 检查是否为 bunx
    /// 对应 Bun: Command.isBunX()
    public static func isBunX(argv0: String): Bool {
        return argv0.endsWith("baox") || argv0.endsWith("baox.exe")
    }

    /// 检查是否为 node
    /// 对应 Bun: Command.isNode()
    public static func isNode(argv0: String): Bool {
        return argv0.endsWith("node") || argv0.endsWith("node.exe")
    }

    /// 确定当前命令
    /// 对应 Bun: Command.which()
    public static func which(): CommandTag {
        val args = BunArgv.getArgs()

        val argv0 = if (args.length > 0) args[0] else ""
        if (argv0.length == 0) {
            return CommandTag.HelpCommand
        }

        if (isBunX(argv0)) {
            if (args.length > 1) {
                val next = args[1]
                if (next == "add") {
                    return CommandTag.AddCommand
                } else if (next == "exec") {
                    return CommandTag.ExecCommand
                }
            }
            isBunxExe = true
            return CommandTag.BunxCommand
        }

        if (isNode(argv0)) {
            pretendToBeNode = true
            return CommandTag.RunAsNodeCommand
        }

        // 查找第一个非 flag 参数
        var nextArg = if (args.length > 1) args[1] else ""
        var argIdx = 1
        while (nextArg.length > 0 && nextArg[0] == '-' &&
               !(nextArg.length > 1 && nextArg[1] == 'e') &&
               argIdx + 1 < args.length) {
            argIdx += 1
            nextArg = args[argIdx]
        }

        val firstArgName = nextArg
        return matchCommand(firstArgName, args)
    }

    /// 匹配命令字符串到命令标签
    /// 对应 Bun: Command.which() 中的 switch
    private static func matchCommand(name: String, args: Array<String>): CommandTag {
        when (name) {
            case "init" => return CommandTag.InitCommand
            case "build", "bao" => return CommandTag.BuildCommand
            case "discord" => return CommandTag.DiscordCommand
            case "upgrade" => return CommandTag.UpgradeCommand
            case "completions" => return CommandTag.InstallCompletionsCommand
            case "getcompletes" => return CommandTag.GetCompletionsCommand
            case "link" => return CommandTag.LinkCommand
            case "unlink" => return CommandTag.UnlinkCommand
            case "x" => return CommandTag.BunxCommand
            case "repl" => return CommandTag.ReplCommand
            case "i", "install" => {
                // 检查是否有 -g/--global
                for (arg in args) {
                    if (arg == "-g" || arg == "--global") {
                        return CommandTag.AddCommand
                    }
                }
                return CommandTag.InstallCommand
            }
            case "ci" => return CommandTag.InstallCommand
            case "c", "create" => return CommandTag.CreateCommand
            case "test" => return CommandTag.TestCommand
            case "pm" => return CommandTag.PackageManagerCommand
            case "add", "a" => return CommandTag.AddCommand
            case "update" => return CommandTag.UpdateCommand
            case "patch" => return CommandTag.PatchCommand
            case "patch-commit" => return CommandTag.PatchCommitCommand
            case "r", "remove", "rm", "uninstall" => return CommandTag.RemoveCommand
            case "run" => return CommandTag.RunCommand
            case "help" => return CommandTag.HelpCommand
            case "exec" => return CommandTag.ExecCommand
            case "outdated" => return CommandTag.OutdatedCommand
            case "publish" => return CommandTag.PublishCommand
            case "audit" => return CommandTag.AuditCommand
            case "info" => return CommandTag.InfoCommand
            case "deploy", "cloud", "config", "use", "auth", "login", "logout" => return CommandTag.ReservedCommand
            case "whoami" => return CommandTag.PackageManagerCommand
            case "prune" => return CommandTag.ReservedCommand
            case "list" => return CommandTag.PackageManagerCommand
            case "why" => return CommandTag.WhyCommand
            case "-e" => return CommandTag.AutoCommand
            case _ => return CommandTag.AutoCommand
        }
    }

    /// 默认补全列表
    /// 对应 Bun: default_completions_list
    public static let defaultCompletionsList: ArrayList<String> = ArrayList<String>().fromArray([
        "build", "install", "add", "run", "update", "link", "unlink",
        "remove", "create", "bao", "upgrade", "discord", "test", "pm", "x", "repl", "info"
    ])

    /// 拒绝列表
    /// 对应 Bun: reject_list
    public static let rejectList: ArrayList<String> = ArrayList<String>().fromArray([
        "build", "install", "add", "run", "update", "link", "unlink",
        "remove", "create", "bao", "upgrade", "discord", "test", "pm", "x", "repl", "info",
        "completions", "help"
    ])

    /// 命令启动入口
    /// 对应 Bun: Command.start()
    public static func start(allocator: Allocator, log: Log): Unit {
        val tag = which()

        when (tag) {
            case CommandTag.DiscordCommand => DiscordCommand.exec(allocator)
            case CommandTag.HelpCommand => HelpCommand.exec(allocator)
            case CommandTag.ReservedCommand => ReservedCommand.exec(allocator)
            case CommandTag.InitCommand => InitCommand.exec(allocator, BunArgv.getArgs().slice(Math.min(2, BunArgv.getArgs().length)))
            case CommandTag.InfoCommand => execInfoCommand(allocator, log)
            case CommandTag.BuildCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.BuildCommand)
                BuildCommand.exec(ctx, None)
            }
            case CommandTag.InstallCompletionsCommand => {
                InstallCompletionsCommand.exec(allocator)
            }
            case CommandTag.InstallCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.InstallCommand)
                InstallCommand.exec(ctx)
            }
            case CommandTag.AddCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.AddCommand)
                AddCommand.exec(ctx)
            }
            case CommandTag.UpdateCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.UpdateCommand)
                UpdateCommand.exec(ctx)
            }
            case CommandTag.PatchCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.PatchCommand)
                PatchCommand.exec(ctx)
            }
            case CommandTag.PatchCommitCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.PatchCommitCommand)
                PatchCommitCommand.exec(ctx)
            }
            case CommandTag.OutdatedCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.OutdatedCommand)
                OutdatedCommand.exec(ctx)
            }
            case CommandTag.UpdateInteractiveCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.UpdateInteractiveCommand)
                UpdateInteractiveCommand.exec(ctx)
            }
            case CommandTag.PublishCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.PublishCommand)
                PublishCommand.exec(ctx)
            }
            case CommandTag.AuditCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.AuditCommand)
                AuditCommand.exec(ctx)
            }
            case CommandTag.WhyCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.WhyCommand)
                WhyCommand.exec(ctx)
            }
            case CommandTag.BunxCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.BunxCommand)
                val offset = if (isBunxExe) 0 else 1
                BunxCommand.exec(ctx, BunArgv.getArgs().slice(offset))
            }
            case CommandTag.ReplCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.RunCommand)
                ReplCommand.exec(ctx)
            }
            case CommandTag.RemoveCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.RemoveCommand)
                RemoveCommand.exec(ctx)
            }
            case CommandTag.LinkCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.LinkCommand)
                LinkCommand.exec(ctx)
            }
            case CommandTag.UnlinkCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.UnlinkCommand)
                UnlinkCommand.exec(ctx)
            }
            case CommandTag.PackageManagerCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.PackageManagerCommand)
                PackageManagerCommand.exec(ctx)
            }
            case CommandTag.TestCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.TestCommand)
                TestCommand.exec(ctx)
            }
            case CommandTag.GetCompletionsCommand => {
                execGetCompletions(allocator, log)
            }
            case CommandTag.CreateCommand => {
                execCreate(allocator, log)
            }
            case CommandTag.RunCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.RunCommand)
                ctx.args.target = Target.bun

                if (ctx.parallel || ctx.sequential) {
                    try {
                        MultiRun.run(ctx)
                    } catch (e: Exception) {
                        Output.prettyErrorLn("<r><red>error<r>: ${e.message}")
                        Global.exit(1)
                    }
                }

                if (ctx.filters.length > 0 || ctx.workspaces) {
                    try {
                        FilterRun.runScriptsWithFilter(ctx)
                    } catch (e: Exception) {
                        Output.prettyErrorLn("<r><red>error<r>: ${e.message}")
                        Global.exit(1)
                    }
                }

                if (ctx.positionals.length > 0) {
                    if (RunCommand.exec(ctx, RunOptions(binDirsOnly: false, logErrors: true, allowFastRun: false))) {
                        return
                    }
                    Global.exit(1)
                }
            }
            case CommandTag.RunAsNodeCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.RunAsNodeCommand)
                RunCommand.execAsIfNode(ctx)
            }
            case CommandTag.UpgradeCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.UpgradeCommand)
                UpgradeCommand.exec(ctx)
            }
            case CommandTag.AutoCommand => {
                val ctx = try {
                    Command.initContext(allocator, log, CommandTag.AutoCommand)
                } catch (e: Exception) {
                    HelpCommand.execWithReason(allocator, HelpCommand.Reason.explicit)
                    return
                }
                ctx.args.target = Target.bun

                if (ctx.parallel || ctx.sequential) {
                    try {
                        MultiRun.run(ctx)
                    } catch (e: Exception) {
                        Output.prettyErrorLn("<r><red>error<r>: ${e.message}")
                        Global.exit(1)
                    }
                }

                if (ctx.filters.length > 0 || ctx.workspaces) {
                    try {
                        FilterRun.runScriptsWithFilter(ctx)
                    } catch (e: Exception) {
                        Output.prettyErrorLn("<r><red>error<r>: ${e.message}")
                        Global.exit(1)
                    }
                }

                if (ctx.runtimeOptions.eval.script.length > 0) {
                    execEvalPrint(ctx)
                    return
                }

                if (ctx.positionals.length > 0) {
                    if (RunCommand.exec(ctx, RunOptions(binDirsOnly: true, logErrors: !ctx.runtimeOptions.ifPresent, allowFastRun: true))) {
                        return
                    }
                    return
                }

                Output.flush()
                HelpCommand.exec(allocator)
            }
            case CommandTag.ExecCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.ExecCommand)
                if (ctx.positionals.length > 1) {
                    ExecCommand.exec(ctx)
                } else {
                    CommandTag.printHelp(CommandTag.ExecCommand, true)
                }
            }
            case CommandTag.FuzzilliCommand => {
                val ctx = Command.initContext(allocator, log, CommandTag.FuzzilliCommand)
                FuzzilliCommand.exec(ctx)
            }
            case _ => {
                HelpCommand.exec(allocator)
            }
        }
    }

    /// 初始化命令上下文
    /// 对应 Bun: Command.init / createContextData
    public static func initContext(allocator: Allocator, log: Log, command: CommandTag): CommandContext {
        Cli.cmd = command
        val ctx = CommandContext()
        ctx.allocator = allocator
        ctx.log = log
        ctx.startTime = startTime

        if (CommandTag.usesGlobalOptions(command)) {
            ctx.args = Arguments.parse(allocator, ctx, command)
        }

        return ctx
    }

    /// 执行 getcompletes
    /// 对应 Bun: @"bun getcompletes"
    private static func execGetCompletions(allocator: Allocator, log: Log): Unit {
        val ctx = Command.initContext(allocator, log, CommandTag.GetCompletionsCommand)
        var filter = ctx.positionals

        // 过滤掉 "getcompletes" 参数
        for (i in 0..filter.length) {
            if (filter[i] == "getcompletes") {
                if (i + 1 < filter.length) {
                    filter = filter.slice(i + 1)
                } else {
                    filter = []
                }
                break
            }
        }

        var completions = ShellCompletions()

        if (filter.length == 0) {
            completions = RunCommand.completions(ctx, defaultCompletionsList, rejectList, CompletionKind.all_)
        } else if (filter[0] == "s") {
            completions = RunCommand.completions(ctx, None, rejectList, CompletionKind.script)
        } else if (filter[0] == "i") {
            completions = RunCommand.completions(ctx, defaultCompletionsList, rejectList, CompletionKind.scriptExclude)
        } else if (filter[0] == "b") {
            completions = RunCommand.completions(ctx, None, rejectList, CompletionKind.bin)
        } else if (filter[0] == "r") {
            completions = RunCommand.completions(ctx, None, rejectList, CompletionKind.all_)
        } else if (filter[0] == "g") {
            completions = RunCommand.completions(ctx, None, rejectList, CompletionKind.allPlusBunJs)
        } else if (filter[0] == "j") {
            completions = RunCommand.completions(ctx, None, rejectList, CompletionKind.bunJs)
        } else if (filter[0] == "z") {
            completions = RunCommand.completions(ctx, None, rejectList, CompletionKind.scriptAndDescriptions)
        }

        completions.print()
    }

    /// 执行 create 命令
    /// 对应 Bun: @"bun create"
    private static func execCreate(allocator: Allocator, log: Log): Unit {
        val ctx = Command.initContext(allocator, log, CommandTag.CreateCommand)
        val args = Sys.getArgsAlloc(allocator)

        if (args.length <= 2) {
            CommandTag.printHelp(CommandTag.CreateCommand, false)
            Global.exit(1)
            return
        }

        var positionals = ["", ""]
        var positionalI = 0
        var templateNameStart: Int64 = 0
        var dashDashBun = false
        var printHelp = false

        val remainder = args.slice(1)
        for (i in 0..remainder.length) {
            val slice = remainder[i].trim(" \t\n")
            if (slice.length > 0) {
                if (!slice.startsWith("--")) {
                    if (positionalI == 1) {
                        templateNameStart = i + 2
                    }
                    positionals[positionalI] = slice
                    positionalI += 1
                }
                if (slice[0] == '-') {
                    if (slice == "--bun") {
                        dashDashBun = true
                    } else if (slice == "--help" || slice == "-h") {
                        printHelp = true
                    }
                }
            }
        }

        if (printHelp || positionalI == 0 || positionals[1].length == 0) {
            CommandTag.printHelp(CommandTag.CreateCommand, true)
            Global.exit(0)
            return
        }

        val templateName = positionals[1]

        // 弃用提示
        if (templateName == "react") {
            Output.prettyErrorLn("The \"react\" template has been deprecated.\nIt is recommended to use \"react-app\" or \"vite\" instead.\n")
            Global.exit(1)
            return
        }

        if (templateName == "next") {
            Output.prettyErrorLn("<yellow>warn: No template <b>create-next<r> found.\nTo create a project with the official Next.js scaffolding tool, run\n  <b>bao create next-app <cyan>[destination]<r>\n")
            Global.exit(1)
            return
        }

        val createCommandInfo = CreateCommand.extractInfo(ctx)
        val template = createCommandInfo.template
        val exampleTag = createCommandInfo.exampleTag

        // 检查是否应使用 bunx
        val useBunx = !isHardcodedNonBunXList(templateName) &&
            (!templateName.contains("/") || templateName[0] == '@') &&
            exampleTag != CreateCommandExample.Tag.localFolder

        if (useBunx) {
            val bunxArgs = ArrayList<String>()
            bunxArgs.append("baox")
            if (dashDashBun) {
                bunxArgs.append("--bun")
            }
            bunxArgs.append(BunxCommand.addCreatePrefix(allocator, templateName))
            for (i in templateNameStart..args.length) {
                bunxArgs.append(args[i])
            }
            BunxCommand.exec(ctx, bunxArgs.toArray())
            return
        }

        CreateCommand.exec(ctx, exampleTag, template)
    }

    /// 硬编码非 BunX 模板列表
    private static func isHardcodedNonBunXList(name: String): Bool {
        return name == "elysia" || name == "elysia-buchta" || name == "stric"
    }

    /// 执行 info 命令
    /// 对应 Bun: @"bun info"
    private static func execInfoCommand(allocator: Allocator, log: Log): Unit {
        val cli = PackageManager.CommandLineArguments.parse(allocator, Subcommand.info)
        val ctx = Command.initContext(allocator, log, CommandTag.InfoCommand)
        val (pm, _) = PackageManager.init(ctx, cli, Subcommand.info)

        var packageName = ""
        var propertyPath: ?String = None
        var foundPackage = false

        val args = BunArgv.getArgs()
        var argIdx: Int64 = 2

        while (argIdx < args.length) {
            val arg = args[argIdx.toInt()]

            // 跳过 flags
            if (arg.length > 0 && arg[0] == '-') {
                argIdx += 1
                continue
            }

            if (!foundPackage) {
                packageName = arg
                foundPackage = true
            } else {
                propertyPath = arg
                break
            }
            argIdx += 1
        }

        PmViewCommand.view(allocator, pm, packageName, propertyPath, cli.jsonOutput)
    }

    /// 执行 --eval --print
    /// 对应 Bun: @"bun --eval --print"
    private static func execEvalPrint(ctx: CommandContext): Unit {
        val trigger = "/[eval]"
        val cwd = Sys.getcwd()
        val entryPoint = "${cwd}${trigger}"
        ctx.passthrough = ctx.positionals.concat(ctx.passthrough)
        BunJsRun.boot(ctx, entryPoint, None)
    }
}

// ============================================================================
// CommandTag — 命令标签枚举
// ============================================================================

/// 命令标签
/// 对应 Bun: Command.Tag
public enum CommandTag {
    | AutoCommand
    | RunCommand
    | RunAsNodeCommand
    | BuildCommand
    | TestCommand
    | BunxCommand
    | InstallCommand
    | AddCommand
    | RemoveCommand
    | UpdateCommand
    | PatchCommand
    | PatchCommitCommand
    | LinkCommand
    | UnlinkCommand
    | CreateCommand
    | HelpCommand
    | ReservedCommand
    | PackageManagerCommand
    | InitCommand
    | DiscordCommand
    | UpgradeCommand
    | InstallCompletionsCommand
    | GetCompletionsCommand
    | OutdatedCommand
    | PublishCommand
    | AuditCommand
    | ReplCommand
    | ExecCommand
    | FuzzilliCommand
    | InfoCommand
    | WhyCommand
    | UpdateInteractiveCommand

    /// 检查命令是否使用全局选项
    /// 对应 Bun: Command.Tag.uses_global_options
    public static func usesGlobalOptions(tag: CommandTag): Bool {
        when (tag) {
            case CommandTag.DiscordCommand,
                 CommandTag.HelpCommand,
                 CommandTag.ReservedCommand,
                 CommandTag.InitCommand,
                 CommandTag.InstallCompletionsCommand,
                 CommandTag.GetCompletionsCommand,
                 CommandTag.CreateCommand => return false
            case _ => return true
        }
    }

    /// 打印帮助
    /// 对应 Bun: Command.Tag.printHelp / tagPrintHelp
    public static func printHelp(cmd: CommandTag, showAllFlags: Bool): Unit {
        when (cmd) {
            case CommandTag.AutoCommand => {
                HelpCommand.printWithReason(HelpCommand.Reason.explicit, showAllFlags)
            }
            case CommandTag.RunCommand, CommandTag.RunAsNodeCommand => {
                RunCommand.printHelp(None)
            }
            case CommandTag.InitCommand => {
                Output.pretty("<b>Usage<r>: <b><green>bao init<r> <cyan>[flags]<r> <blue>[\\<folder\\>]<r>\n")
                Output.pretty("  Initialize a Bao project in the current directory.\n")
                Output.pretty("  Creates a package.json, tsconfig.json, and baofig.toml if they don't exist.\n\n")
                Output.pretty("  <b>Flags<r>:\n")
                Output.pretty("      <cyan>--help<r>             Print this menu\n")
                Output.pretty("  <cyan>-y, --yes<r>              Accept all default options\n")
                Output.pretty("  <cyan>-m, --minimal<r>          Only initialize type definitions\n")
                Output.pretty("  <cyan>-r, --react<r>            Initialize a React project\n\n")
                Output.flush()
            }
            case CommandTag.BunxCommand => {
                Output.prettyErrorLn("<b>Usage<r>: <b><green>baox<r> <cyan>[flags]<r> <blue>\\<package\\><r><d>\\<@version\\><r> [flags and arguments for the package]<r>")
                Output.prettyErrorLn("Execute an npm package executable (CLI), automatically installing if needed.\n\n")
                Output.prettyErrorLn("Flags:\n")
                Output.prettyErrorLn("  <cyan>--bao<r>                  Force the command to run with Bao instead of Node.js\n")
                Output.prettyErrorLn("  <cyan>-p, --package <blue>\\<package\\><r>    Specify package to install\n")
                Output.prettyErrorLn("  <cyan>--no-install<r>           Skip installation if package is not already installed\n\n")
                Output.flush()
            }
            case CommandTag.BuildCommand => {
                Output.pretty("<b>Usage<r>:\n  Transpile and bundle one or more files.\n")
                Output.pretty("  <b><green>bao build<r> <cyan>[flags]<r> <blue>\\<entrypoint\\><r>\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao build<r> <cyan>--outfile=bundle.js<r> <blue>./src/index.ts<r>\n")
                Output.pretty("  <b><green>bao build<r> <cyan>--compile --outfile=my-app<r> <blue>./cli.ts<r>\n\n")
                Output.flush()
            }
            case CommandTag.TestCommand => {
                Output.pretty("<b>Usage<r>: <b><green>bao test<r> <cyan>[flags]<r> <blue>[\\<patterns\\>]<r>\n")
                Output.pretty("  Run all matching test files and print the results to stdout\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao test<r>\n")
                Output.pretty("  <b><green>bao test<r> <blue>foo bar<r>\n\n")
                Output.flush()
            }
            case CommandTag.CreateCommand => {
                Output.pretty("<b>Usage<r>:\n")
                Output.pretty("  <b><green>bao create<r> <magenta>\\<template\\><r> <cyan>[...flags]<r> <blue>dest<r>\n\n")
                Output.flush()
            }
            case CommandTag.HelpCommand => {
                HelpCommand.printWithReason(HelpCommand.Reason.explicit, false)
            }
            case CommandTag.UpgradeCommand => {
                Output.pretty("<b>Usage<r>: <b><green>bao upgrade<r> <cyan>[flags]<r>\n")
                Output.pretty("  Upgrade Bao\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao upgrade<r>\n\n")
                Output.flush()
            }
            case CommandTag.ReplCommand => {
                Output.pretty("<b>Usage<r>: <b><green>bao repl<r> <cyan>[flags]<r>\n")
                Output.pretty("  Open a Bao REPL\n\n")
                Output.flush()
            }
            case CommandTag.GetCompletionsCommand => {
                Output.pretty("<b>Usage<r>: <b><green>bao getcompletes<r>")
                Output.flush()
            }
            case CommandTag.InstallCompletionsCommand => {
                Output.pretty("<b>Usage<r>: <b><green>bao completions<r>")
                Output.flush()
            }
            case CommandTag.PatchCommand => {
                PackageManager.CommandLineArguments.printHelp(Subcommand.patch)
            }
            case CommandTag.PatchCommitCommand => {
                PackageManager.CommandLineArguments.printHelp(Subcommand.patchCommit)
            }
            case CommandTag.ExecCommand => {
                Output.pretty("<b>Usage: bao exec <r><cyan>\\<script\\><r>\n\n")
                Output.pretty("Execute a shell script directly from Bao.\n\n")
                Output.pretty("<b><red>Note<r>: If executing this from a shell, make sure to escape the string!\n\n")
                Output.pretty("<b>Examples<d>:<r>\n")
                Output.pretty("  <b>bao exec \"echo hi\"<r>\n\n")
                Output.flush()
            }
            case CommandTag.OutdatedCommand, CommandTag.UpdateInteractiveCommand,
                 CommandTag.PublishCommand, CommandTag.AuditCommand => {
                val subcmd = when (cmd) {
                    case CommandTag.OutdatedCommand => Subcommand.outdated
                    case CommandTag.UpdateInteractiveCommand => Subcommand.update
                    case CommandTag.PublishCommand => Subcommand.publish
                    case CommandTag.AuditCommand => Subcommand.audit
                    case _ => Subcommand.install
                }
                PackageManager.CommandLineArguments.printHelp(subcmd)
            }
            case CommandTag.InfoCommand => {
                Output.pretty("<b>Usage<r>: <b><green>bao info<r> <cyan>[flags]<r> <blue>\\<package\\><r> <blue>[property path]<r>\n")
                Output.pretty("  Display package metadata from the registry.\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao info<r> <blue>react<r>\n")
                Output.pretty("  <b><green>bao info<r> <blue>react<r> version\n\n")
                Output.flush()
            }
            case CommandTag.WhyCommand => {
                Output.pretty("<b>Usage<r>: <b><green>bao why<r> <cyan>[flags]<r> <blue>\\<package\\><r>\n")
                Output.pretty("  Explain why a package is installed\n\n")
                Output.pretty("<b>Arguments:<r>\n")
                Output.pretty("  <blue>\\<package\\><r>     <d>The package name to explain (supports glob patterns)<r>\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao why<r> <blue>react<r>\n\n")
                Output.flush()
            }
            case _ => {
                HelpCommand.printWithReason(HelpCommand.Reason.explicit, false)
            }
        }
    }
}

/// 打印版本并退出
/// 对应 Bun: printVersionAndExit
public static func printVersionAndExit(): Unit {
    Output.writer().writeAll("${Global.packageJsonVersion}\n")
    Global.exit(0)
}

/// 打印修订版本并退出
/// 对应 Bun: printRevisionAndExit
public static func printRevisionAndExit(): Unit {
    Output.writer().writeAll("${Global.packageJsonVersionWithRevision}\n")
    Global.exit(0)
}
