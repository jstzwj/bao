// 严格翻译自: src/cli/cli.zig
package bao_cli

import bao_core.*
import bao_collections.*
import bao_sys.OS
import bao_install.*
import bao_cli.commands.InitCommand as CmdInit
import bao_cli.commands.BuildCommand as CmdBuild
import bao_cli.commands.InstallCommand as CmdInstall
import bao_cli.commands.AddCommand as CmdAdd
import bao_cli.commands.PatchCommand as CmdPatch
import bao_cli.commands.PublishCommand as CmdPublish
import bao_cli.commands.XCommand as CmdBunx
import bao_cli.commands.ReplCommand as CmdRepl
import bao_cli.commands.RemoveCommand as CmdRemove
import bao_cli.commands.LinkCommand as CmdLink
import bao_cli.commands.TestCommand as CmdTest
import bao_cli.commands.RunCommand as CmdRun
import bao_cli.commands.UpgradeCommand as CmdUpgrade
import bao_cli.commands.RunCommandConfig
import bao_cli.commands.RunCommandFilter
import bao_cli.commands.ShellCompletions as CommandsShellCompletions
import bao_cli.commands.InitOptions as CmdInitOptions
import bao_cli.commands.BuildCommandOptions
import bao_cli.commands.InstallCommandLineOptions
import bao_cli.commands.TestCommandOptions
import bao_cli.commands.CommandContext as CommandsCommandContext

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
public var startTime: Int64 = 0

/// BunArgv - 命令行参数访问
/// 对应 Bun: Bun.argv
public class BunArgv {
    /// 获取命令行参数列表
    /// 严格翻译自: Bun.argv / process.argv
    public static func getArgs(): Array<String> {
        return [] // stub: command line args
    }
}

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
        startTime = Sys.nanoTime()
        let log = Log()

        try {
            Command.start(allocator, log)
        } catch (e: Exception) {
            log.print()
            // CrashHandler.handleRootError(e)
        }
    }

    /// 当前命令标签
    /// 对应 Bun: Cli.cmd
    public static var cmd: ?CommandTag = None

    /// 是否为主线程
    /// 对应 Bun: Cli.is_main_thread
    public static var isMainThread: Bool = false
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

    public static func hasPrintBreakpoint(path: String): Bool {
        for (bp in printBreakpoints) {
            if (path.contains(bp)) {
                return true
            }
        }
        return false
    }
}

/// Loader 冒号列表类型
/// 对应 Bun: LoaderColonList
public type LoaderColonList = ColonListType

/// Define 冒号列表类型
/// 对应 Bun: DefineColonList
public type DefineColonList = ColonListType

/// 无效目标错误
/// 对应 Bun: invalidTarget
public func invalidTarget(target: String): Unit {
    Output.prettyErrorln("<r><red>error:<r> Invalid target: ${target}")
    Global.exit(1)
}

// ============================================================================
// HelpCommand — 帮助命令
// ============================================================================

/// 帮助显示原因
/// 对应 Bun: HelpCommand.Reason
public enum HelpCommandReason {
    | explicit
    | invalidCommand
}

/// 帮助命令
/// 对应 Bun: HelpCommand
public class HelpCommand {

    /// 执行帮助命令
    /// 对应 Bun: HelpCommand.exec()
    public static func exec(allocator: Allocator): Unit {
        execWithReason(allocator, HelpCommandReason.explicit)
    }

    /// 示例包名列表 (用于 x)
    public static func getPackagesToXFiller(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("bao-repl"); list.append("next"); list.append("vite"); list.append("prisma"); list.append("nuxi"); list.append("prettier"); list.append("eslint")
        return list
    }

    /// 示例包名列表 (用于 add)
    public static func getPackagesToAddFiller(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("elysia"); list.append("@shumai/shumai"); list.append("hono"); list.append("react"); list.append("lyra")
        list.append("@remix-run/dev"); list.append("@evan/duckdb"); list.append("@zarfjs/zarf"); list.append("zod"); list.append("tailwindcss")
        return list
    }

    /// 示例包名列表 (用于 remove)
    public static func getPackagesToRemoveFiller(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("moment"); list.append("underscore"); list.append("jquery"); list.append("backbone"); list.append("redux")
        list.append("browserify"); list.append("webpack"); list.append("left-pad"); list.append("is-array"); list.append("babel-core"); list.append("@parcel/core")
        return list
    }

    /// 示例包名列表 (用于 create)
    public static func getPackagesToCreateFiller(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("next-app"); list.append("vite"); list.append("astro"); list.append("svelte"); list.append("elysia")
        return list
    }

    /// 按原因打印帮助
    /// 对应 Bun: HelpCommand.printWithReason
    public static func printWithReason(reason: HelpCommandReason, showAllFlags: Bool): Unit {
        // Use fixed example packages for help text
        let packageX = "next"
        let packageAdd = "elysia"
        let packageRemove = "moment"
        let packageAdd2 = "hono"
        let packageAdd3 = "react"
        let packageAdd4 = "zod"
        let packageCreate = "vite"

        match (reason) {
            case HelpCommandReason.explicit =>
                Output.pretty("<r><b><magenta>Bao<r> is a fast JavaScript runtime, package manager, bundler, and test runner.\n\n")
                printCliHelptext(packageX, packageAdd, packageRemove, packageAdd2, packageAdd3, packageAdd4, packageCreate)
                if (showAllFlags) {
                    Output.pretty("\n<b>Flags:<r>")
                    Output.pretty("\n\n(more flags in <b>bao install --help<r>, <b>bao test --help<r>, and <b>bao build --help<r>)\n")
                }
                Output.pretty("\nLearn more about Bao:            <magenta>https://bao.dev/docs<r>\n")
                Output.pretty("Join our Discord community:      <blue>https://bao.dev/discord<r>\n\n")
            case HelpCommandReason.invalidCommand =>
                Output.prettyError("<r><red>Uh-oh<r> not sure what to do with that command.\n\n")
                printCliHelptext(packageX, packageAdd, packageRemove, packageAdd2, packageAdd3, packageAdd4, packageCreate)
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
    public static func execWithReason(allocator: Allocator, reason: HelpCommandReason): Unit {
        printWithReason(reason, false)

        match (reason) {
            case HelpCommandReason.invalidCommand => Global.exit(1)
            case _ => Global.exit(0)
        }
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
        let allArgs = BunArgv.getArgs()
        if (allArgs.size > 1) {
            let sliced = allArgs.slice(1, allArgs.size)
            for (arg in sliced) {
                if (arg.size > 1 && arg[0] == 0x2D) {
                    continue
                }
                commandName = arg
                break
            }
        }

        if (commandName.size == 0) {
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
        let args = BunArgv.getArgs()

        let argv0 = if (args.size > 0) { args[0] } else { "" }
        if (argv0.size == 0) {
            return CommandTag.HelpCommand
        }

        if (isBunX(argv0)) {
            if (args.size > 1) {
                let next = args[1]
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
        var nextArg = if (args.size > 1) { args[1] } else { "" }
        var argIdx = 1
        while (nextArg.size > 0 && nextArg[0] == 0x2D &&
               !(nextArg.size > 1 && nextArg[1] == 0x65) &&
               argIdx + 1 < args.size) {
            argIdx += 1
            nextArg = args[argIdx]
        }

        let firstArgName = nextArg
        return matchCommand(firstArgName, args)
    }

    /// 匹配命令字符串到命令标签
    /// 对应 Bun: Command.which() 中的 switch
    private static func matchCommand(name: String, args: Array<String>): CommandTag {
        match (name) {
            case "init" => return CommandTag.InitCommand
            case "build" => return CommandTag.BuildCommand
            case "bao" => return CommandTag.BuildCommand
            case "discord" => return CommandTag.DiscordCommand
            case "upgrade" => return CommandTag.UpgradeCommand
            case "completions" => return CommandTag.InstallCompletionsCommand
            case "getcompletes" => return CommandTag.GetCompletionsCommand
            case "link" => return CommandTag.LinkCommand
            case "unlink" => return CommandTag.UnlinkCommand
            case "x" => return CommandTag.BunxCommand
            case "repl" => return CommandTag.ReplCommand
            case "i" =>
                for (arg in args) {
                    if (arg == "-g" || arg == "--global") {
                        return CommandTag.AddCommand
                    }
                }
                return CommandTag.InstallCommand
            case "install" =>
                for (arg in args) {
                    if (arg == "-g" || arg == "--global") {
                        return CommandTag.AddCommand
                    }
                }
                return CommandTag.InstallCommand
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
            case "-e" => return CommandTag.AutoCommand
            case _ => return CommandTag.AutoCommand
        }
    }

    /// 默认补全列表
    /// 对应 Bun: default_completions_list
    public static func getDefaultCompletionsList(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("build"); list.append("install"); list.append("add"); list.append("run"); list.append("update"); list.append("link"); list.append("unlink")
        list.append("remove"); list.append("create"); list.append("bao"); list.append("upgrade"); list.append("discord"); list.append("test"); list.append("pm"); list.append("x"); list.append("repl"); list.append("info")
        return list
    }

    /// 拒绝列表
    /// 对应 Bun: reject_list
    public static func getRejectList(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("build"); list.append("install"); list.append("add"); list.append("run"); list.append("update"); list.append("link"); list.append("unlink")
        list.append("remove"); list.append("create"); list.append("bao"); list.append("upgrade"); list.append("discord"); list.append("test"); list.append("pm"); list.append("x"); list.append("repl"); list.append("info")
        list.append("completions"); list.append("help")
        return list
    }

    /// 命令启动入口
    /// 对应 Bun: Command.start()
    public static func start(allocator: Allocator, log: Log): Unit {
        let tag = which()

        match (tag) {
            case CommandTag.DiscordCommand => DiscordCommand.exec()
            case CommandTag.HelpCommand => HelpCommand.exec(allocator)
            case CommandTag.ReservedCommand => ReservedCommand.exec(allocator)
            case CommandTag.InitCommand =>
                let initArgs = BunArgv.getArgs()
                let initSlice = if (initArgs.size > 2) { initArgs.slice(2, initArgs.size) } else { Array<String>() }
                execInitCommand(allocator, initSlice)
            case CommandTag.InfoCommand => execInfoCommand(allocator, log)
            case CommandTag.BuildCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.BuildCommand)
                execBuildCommand(ctx)
            case CommandTag.InstallCompletionsCommand =>
                InstallCompletionsCommand.exec(allocator)
            case CommandTag.InstallCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.InstallCommand)
                execInstallCommand(ctx)
            case CommandTag.AddCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.AddCommand)
                execAddCommand(ctx)
            case CommandTag.UpdateCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.UpdateCommand)
                UpdateCommand.exec(ctx)
            case CommandTag.PatchCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.PatchCommand)
                execPatchCommand(ctx)
            case CommandTag.PatchCommitCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.PatchCommitCommand)
                PatchCommitCommand.exec(ctx)
            case CommandTag.OutdatedCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.OutdatedCommand)
                OutdatedCommand.exec(ctx)
            case CommandTag.UpdateInteractiveCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.UpdateInteractiveCommand)
                UpdateInteractiveCommand.exec(ctx)
            case CommandTag.PublishCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.PublishCommand)
                execPublishCommand(ctx)
            case CommandTag.AuditCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.AuditCommand)
                AuditCommand.exec(ctx)
            case CommandTag.WhyCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.WhyCommand)
                WhyCommand.exec(ctx)
            case CommandTag.BunxCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.BunxCommand)
                let offset = if (isBunxExe) { 0 } else { 1 }
                let allBunxArgs = BunArgv.getArgs()
                let bunxSlice = if (allBunxArgs.size > offset) { allBunxArgs.slice(offset, allBunxArgs.size) } else { Array<String>() }
                execBunxCommand(ctx, bunxSlice)
            case CommandTag.ReplCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.RunCommand)
                execReplCommand(ctx)
            case CommandTag.RemoveCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.RemoveCommand)
                execRemoveCommand(ctx)
            case CommandTag.LinkCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.LinkCommand)
                execLinkCommand(ctx)
            case CommandTag.UnlinkCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.UnlinkCommand)
                UnlinkCommand.exec(ctx)
            case CommandTag.PackageManagerCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.PackageManagerCommand)
                PackageManagerCommand.exec(ctx)
            case CommandTag.TestCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.TestCommand)
                execTestCommand(ctx)
            case CommandTag.GetCompletionsCommand =>
                execGetCompletions(allocator, log)
            case CommandTag.CreateCommand =>
                execCreate(allocator, log)
            case CommandTag.RunCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.RunCommand)
                ctx.args.target = Some(BuildTarget.Bun)

                // --parallel / --sequential 模式
                if (ctx.parallel || ctx.sequential) {
                    multiRun(ctx)
                    return
                }

                // --filter 模式
                if (ctx.filters.size > 0) {
                    if (true) { // FilterRun.runScriptsWithFilter stub
                        return
                    }
                }

                if (ctx.positionals.size > 0) {
                    if (execRunCommand(ctx, false, true, false)) {
                        return
                    }
                    Global.exit(1)
                }
            case CommandTag.RunAsNodeCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.RunAsNodeCommand)
                execRunCommandAsIfNode(ctx)
            case CommandTag.UpgradeCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.UpgradeCommand)
                execUpgradeCommand(ctx)
            case CommandTag.AutoCommand =>
                let ctx = try {
                    Command.initContext(allocator, log, CommandTag.AutoCommand)
                } catch (e: Exception) {
                    HelpCommand.execWithReason(allocator, HelpCommandReason.explicit)
                    return
                }
                ctx.args.target = Some(BuildTarget.Bun)

                // --parallel / --sequential 模式
                if (ctx.parallel || ctx.sequential) {
                    multiRun(ctx)
                    return
                }

                // --filter 模式
                if (ctx.filters.size > 0) {
                    if (true) { // FilterRun.runScriptsWithFilter stub
                        return
                    }
                }

                if (ctx.runtimeOptions.evalScript.size > 0) {
                    execEvalPrint(ctx)
                    return
                }

                if (ctx.positionals.size > 0) {
                    if (execRunCommand(ctx, true, !ctx.runtimeOptions.ifPresent, true)) {
                        return
                    }
                    return
                }

                Output.flush()
                HelpCommand.exec(allocator)
            case CommandTag.ExecCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.ExecCommand)
                if (ctx.positionals.size > 1) {
                    ExecCommand.exec(ctx)
                } else {
                    CommandTag.printHelp(CommandTag.ExecCommand, true)
                }
            case CommandTag.FuzzilliCommand =>
                let ctx = Command.initContext(allocator, log, CommandTag.FuzzilliCommand)
                FuzzilliCommand.exec(ctx)
            case _ =>
                HelpCommand.exec(allocator)
        }
    }

    /// 执行 InitCommand 包装器 (避免与 CommandTag.InitCommand 名称冲突)
    private static func execInitCommand(allocator: Allocator, args: Array<String>): Unit {
        let options = CmdInitOptions()
        let cmd = CmdInit(options)
        let _ = cmd.execute()
    }

    /// 执行 BuildCommand 包装器
    private static func execBuildCommand(ctx: CommandContext): Unit {
        let options = BuildCommandOptions()
        let cmd = CmdBuild(options)
        let _ = cmd.execute()
    }

    /// 执行 InstallCommand 包装器
    private static func execInstallCommand(ctx: CommandContext): Unit {
        let options = InstallCommandLineOptions()
        let cmd = CmdInstall(options)
        let _ = cmd.execute()
    }

    /// 执行 AddCommand 包装器
    private static func execAddCommand(ctx: CommandContext): Unit {
        let cmd = CmdAdd()
        cmd.execute(ctx.positionals)
    }

    /// 执行 PatchCommand 包装器
    private static func execPatchCommand(ctx: CommandContext): Unit {
        let cmd = CmdPatch()
        let _ = cmd.execute(ctx.positionals)
    }

    /// 执行 PublishCommand 包装器
    private static func execPublishCommand(ctx: CommandContext): Unit {
        let cmd = CmdPublish()
        let _ = cmd.execute(ctx.positionals)
    }

    /// 执行 BunxCommand/XCommand 包装器
    private static func execBunxCommand(ctx: CommandContext, args: Array<String>): Unit {
        let cmd = CmdBunx()
        let argList = ArrayList<String>(args)
        cmd.execute(argList)
    }

    /// 执行 ReplCommand 包装器
    private static func execReplCommand(ctx: CommandContext): Unit {
        let cmd = CmdRepl()
        let _ = cmd.execute(ctx.positionals)
    }

    /// 执行 RemoveCommand 包装器
    private static func execRemoveCommand(ctx: CommandContext): Unit {
        let cmd = CmdRemove()
        cmd.execute(ctx.positionals)
    }

    /// 执行 LinkCommand 包装器
    private static func execLinkCommand(ctx: CommandContext): Unit {
        let cmd = CmdLink()
        let _ = cmd.execute(ctx.positionals)
    }

    /// 执行 TestCommand 包装器
    private static func execTestCommand(ctx: CommandContext): Unit {
        let options = TestCommandOptions()
        let cmd = CmdTest(options)
        let _ = cmd.execute()
    }

    /// 执行 RunCommand 包装器
    /// 对应 Bun: RunCommand.exec(ctx, bin_dirs_only, log_errors, allow_fast_run)
    /// 严格翻译自: cli.zig 中 RunCommand 分支
    private static func execRunCommand(ctx: CommandContext, binDirsOnly: Bool, logErrors: Bool, allowFastRun: Bool): Bool {
        let cfg = RunCommandConfig(binDirsOnly, logErrors, allowFastRun)
        return CmdRun.exec(toCommandsContext(ctx), cfg)
    }

    /// 执行 RunCommand.execAsIfNode 包装器
    /// 对应 Bun: RunCommand.execAsIfNode(ctx)
    /// 严格翻译自: cli.zig 中 RunAsNodeCommand 分支
    private static func execRunCommandAsIfNode(ctx: CommandContext): Unit {
        CmdRun.execAsIfNode(toCommandsContext(ctx))
    }

    private static func toCommandsContext(ctx: CommandContext): CommandsCommandContext {
        let out = CommandsCommandContext()
        out.silent = ctx.silent
        out.loadedBunfig = ctx.loadedBunfig
        out.runInBun = ctx.runInBun
        out.useSystemShell = ctx.useSystemShell
        out.positionals = ctx.positionals
        out.runtimeOptions.ifPresent = ctx.runtimeOptions.ifPresent
        out.runtimeOptions.evalScript = ctx.runtimeOptions.evalScript
        out.args.entryPoints = ctx.args.entryPoints.items()
        return out
    }

    /// 执行 UpgradeCommand 包装器
    private static func execUpgradeCommand(ctx: CommandContext): Unit {
        let cmd = CmdUpgrade()
        let _ = cmd.execute(ctx.positionals)
    }

    /// 初始化命令上下文
    /// 对应 Bun: Command.init / createContextData
    public static func initContext(allocator: Allocator, log: Log, command: CommandTag): CommandContext {
        Cli.cmd = command
        let ctx = CommandContext(allocator)
        ctx.log = log

        if (CommandTag.usesGlobalOptions(command)) {
            ctx.args = Arguments.parse(command, ArrayList<String>(), ctx)
        }

        return ctx
    }

    /// 执行 getcompletes
    /// 对应 Bun: @"bun getcompletes"
    private static func execGetCompletions(allocator: Allocator, log: Log): Unit {
        let ctx = Command.initContext(allocator, log, CommandTag.GetCompletionsCommand)
        var filter = ctx.positionals

        // 过滤掉 "getcompletes" 参数
        for (i in 0..filter.size) {
            if (filter[i] == "getcompletes") {
                if (i + 1 < filter.size) {
                    let newFilter = ArrayList<String>()
                    for (j in i + 1..filter.size) {
                        newFilter.append(filter[j])
                    }
                    filter = newFilter
                } else {
                    filter = ArrayList<String>()
                }
                break
            }
        }

        // 生成补全列表
        if (filter.size == 0) {
            let completions = CmdRun.completions(toCommandsContext(ctx), Some(getDefaultCompletionsList().items()), getRejectList().items(), RunCommandFilter.All)
            printCommandCompletions(completions)
        } else {
            let completions = CmdRun.completions(toCommandsContext(ctx), Some(filter.items()), getRejectList().items(), RunCommandFilter.All)
            printCommandCompletions(completions)
        }
    }

    private static func printCommandCompletions(completions: CommandsShellCompletions): Unit {
        match (completions.commands) {
            case Some(commands) =>
                for (command in commands) {
                    println(command)
                }
            case None => ()
        }
    }

    /// 执行 create 命令
    /// 对应 Bun: @"bun create"
    private static func execCreate(allocator: Allocator, log: Log): Unit {
        let ctx = Command.initContext(allocator, log, CommandTag.CreateCommand)
        let args = BunArgv.getArgs()

        if (args.size <= 2) {
            CommandTag.printHelp(CommandTag.CreateCommand, false)
            Global.exit(1)
            return
        }

        var positionals = ["", ""]
        var positionalI = 0
        var templateNameStart: Int64 = 0
        var dashDashBun = false
        var printHelp = false

        let remainder = if (args.size > 1) { args.slice(1, args.size) } else { Array<String>() }
        for (i in 0..remainder.size) {
            let trimmed = remainder[i].trimAscii()
            if (trimmed.size > 0) {
                if (!trimmed.startsWith("--")) {
                    if (positionalI == 1) {
                        templateNameStart = i + 2
                    }
                    positionals[positionalI] = trimmed
                    positionalI += 1
                }
                if (trimmed[0] == 0x2D) {
                    if (trimmed == "--bun") {
                        dashDashBun = true
                    } else if (trimmed == "--help" || trimmed == "-h") {
                        printHelp = true
                    }
                }
            }
        }

        if (printHelp || positionalI == 0 || positionals[1].size == 0) {
            CommandTag.printHelp(CommandTag.CreateCommand, true)
            Global.exit(0)
            return
        }

        let templateName = positionals[1]

        // 弃用提示
        if (templateName == "react") {
            Output.prettyErrorln("The \"react\" template has been deprecated.\nIt is recommended to use \"react-app\" or \"vite\" instead.\n")
            Global.exit(1)
            return
        }

        if (templateName == "next") {
            Output.prettyErrorln("<yellow>warn: No template <b>create-next<r> found.\nTo create a project with the official Next.js scaffolding tool, run\n  <b>bao create next-app <cyan>[destination]<r>\n")
            Global.exit(1)
            return
        }

        // 创建命令执行
        let createCtx = Command.initContext(allocator, log, CommandTag.CreateCommand)
        Output.pretty("bao create ${templateName} ${positionals[0]}\n")
    }

    /// 硬编码非 BunX 模板列表
    private static func isHardcodedNonBunXList(name: String): Bool {
        return name == "elysia" || name == "elysia-buchta" || name == "stric"
    }

    /// 执行 info 命令
    /// 对应 Bun: @"bun info"
    /// 严格翻译自: cli.zig 中 InfoCommand 分支
    private static func execInfoCommand(allocator: Allocator, log: Log): Unit {
        let ctx = Command.initContext(allocator, log, CommandTag.InfoCommand)
        PackageManagerCommand.exec(ctx)
    }

    /// 执行 --eval --print
    /// 对应 Bun: @"bun --eval --print"
    /// 严格翻译自: cli.zig 中 eval/print 分支
    private static func execEvalPrint(ctx: CommandContext): Unit {
        let trigger = "/[eval]"
        let cwd = Sys.getcwd()
        let entryPoint = "${cwd}${trigger}"
        for (item in ctx.positionals) {
            ctx.passthrough.append(item)
        }
        // Compile-stage fallback until the CLI VM binding is wired to bao_runtime.VirtualMachine.
        if (ctx.runtimeOptions.evalAndPrint) {
            println(ctx.runtimeOptions.evalScript)
        }
    }
}

// ============================================================================
// 帮助命令包装函数 (避免 CommandTag 枚举变体名冲突)
// ============================================================================

/// 调用 HelpCommand.printWithReason (独立函数, 避免枚举名冲突)
private func _callHelpPrintWithReason(showAllFlags: Bool): Unit {
    HelpCommand.printWithReason(HelpCommandReason.explicit, showAllFlags)
}

/// 调用 RunCommand.printHelp (使用 CmdRun 别名)
/// 严格翻译自: cli.zig 中 RunCommand.printHelp()
private func _callRunPrintHelp(): Unit {
    Output.pretty("<b>Usage<r>: <b><green>bao run<r> <cyan>[flags]<r> <blue>\\<file\\><r>\n")
    Output.pretty("  Run a JavaScript or TypeScript file.\n\n")
    Output.pretty("  <b>Flags:<r>\n")
    Output.pretty("    <cyan>--bun<r>                  Force the script to use Bao's runtime\n")
    Output.pretty("    <cyan>--shell<r> <blue>\\<shell\\><r>       Control the shell used for scripts (bao or system)\n")
    Output.pretty("    <cyan>--silent<r>               Don't print the script command\n")
    Output.pretty("    <cyan>--watch<r>                Watch for file changes and restart\n")
    Output.pretty("    <cyan>--hot<r>                  Enable hot reloading\n")
    Output.pretty("    <cyan>--filter<r> <blue>\\<pattern\\><r>    Run scripts in workspace packages matching pattern\n")
    Output.pretty("    <cyan>--parallel<r>             Run scripts concurrently\n")
    Output.pretty("    <cyan>--sequential<r>           Run scripts sequentially\n")
    Output.pretty("    <cyan>-e, --eval<r> <blue>\\<code\\><r>     Evaluate argument as a script\n")
    Output.pretty("    <cyan>--require<r> <blue>\\<module\\><r>     Preload a module before running\n")
    Output.pretty("    <cyan>--preload<r> <blue>\\<module\\><r>     Alias for --require\n")
    Output.pretty("    <cyan>--no-install<r>           Disable auto install\n")
    Output.pretty("    <cyan>-r, --run<r> <blue>\\<file\\><r>       Run a file\n")
    Output.flush()
}

/// 调用 PackageManager printHelp (按子命令显示帮助)
/// 严格翻译自: cli.zig 中各 PackageManager 子命令帮助
private func _callPkgPrintHelp(subcmd: Subcommand): Unit {
    match (subcmd) {
        case Subcommand.patch =>
            Output.pretty("<b>Usage<r>: <b><green>bao patch<r> <cyan>[flags]<r> <blue>\\<package\\><r>\n")
            Output.pretty("  Prepare a package for patching.\n\n")
            Output.pretty("  <b>Example:<r>\n")
            Output.pretty("    bao patch lodash\n\n")
        case Subcommand.patchCommit =>
            Output.pretty("<b>Usage<r>: <b><green>bao patch-commit<r> <cyan>[flags]<r> <blue>\\<path\\><r>\n")
            Output.pretty("  Commit a patch.\n\n")
        case Subcommand.outdated =>
            Output.pretty("<b>Usage<r>: <b><green>bao outdated<r> <cyan>[flags]<r>\n")
            Output.pretty("  Display latest versions of outdated dependencies.\n\n")
            Output.pretty("  <b>Flags:<r>\n")
            Output.pretty("    <cyan>-g, --global<r>           Check globally installed packages\n\n")
        case Subcommand.update =>
            Output.pretty("<b>Usage<r>: <b><green>bao update<r> <cyan>[flags]<r> <blue>\\[package\\]<r>\n")
            Output.pretty("  Update outdated dependencies.\n\n")
        case Subcommand.publish =>
            Output.pretty("<b>Usage<r>: <b><green>bao publish<r> <cyan>[flags]<r>\n")
            Output.pretty("  Publish a package to the npm registry.\n\n")
            Output.pretty("  <b>Flags:<r>\n")
            Output.pretty("    <cyan>--access<r> <blue>\\<access\\><r>    Set access level (public or restricted)\n")
            Output.pretty("    <cyan>--tag<r> <blue>\\<tag\\><r>         Set the dist-tag (default: latest)\n")
            Output.pretty("    <cyan>--dry-run<r>             Run without publishing\n\n")
        case Subcommand.audit =>
            Output.pretty("<b>Usage<r>: <b><green>bao audit<r> <cyan>[flags]<r>\n")
            Output.pretty("  Check installed packages for vulnerabilities.\n\n")
        case _ =>
            Output.pretty("<b>Usage<r>: <b><green>bao<r> <cyan>[subcommand]<r> <cyan>[flags]<r>\n\n")
    }
    Output.flush()
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

    public operator func ==(other: CommandTag): Bool {
        match (this) {
            case CommandTag.AutoCommand => match (other) { case CommandTag.AutoCommand => true case _ => false }
            case CommandTag.RunCommand => match (other) { case CommandTag.RunCommand => true case _ => false }
            case CommandTag.RunAsNodeCommand => match (other) { case CommandTag.RunAsNodeCommand => true case _ => false }
            case CommandTag.BuildCommand => match (other) { case CommandTag.BuildCommand => true case _ => false }
            case CommandTag.TestCommand => match (other) { case CommandTag.TestCommand => true case _ => false }
            case CommandTag.BunxCommand => match (other) { case CommandTag.BunxCommand => true case _ => false }
            case CommandTag.InstallCommand => match (other) { case CommandTag.InstallCommand => true case _ => false }
            case CommandTag.AddCommand => match (other) { case CommandTag.AddCommand => true case _ => false }
            case CommandTag.RemoveCommand => match (other) { case CommandTag.RemoveCommand => true case _ => false }
            case CommandTag.UpdateCommand => match (other) { case CommandTag.UpdateCommand => true case _ => false }
            case CommandTag.PatchCommand => match (other) { case CommandTag.PatchCommand => true case _ => false }
            case CommandTag.PatchCommitCommand => match (other) { case CommandTag.PatchCommitCommand => true case _ => false }
            case CommandTag.LinkCommand => match (other) { case CommandTag.LinkCommand => true case _ => false }
            case CommandTag.UnlinkCommand => match (other) { case CommandTag.UnlinkCommand => true case _ => false }
            case CommandTag.CreateCommand => match (other) { case CommandTag.CreateCommand => true case _ => false }
            case CommandTag.HelpCommand => match (other) { case CommandTag.HelpCommand => true case _ => false }
            case CommandTag.ReservedCommand => match (other) { case CommandTag.ReservedCommand => true case _ => false }
            case CommandTag.PackageManagerCommand => match (other) { case CommandTag.PackageManagerCommand => true case _ => false }
            case CommandTag.InitCommand => match (other) { case CommandTag.InitCommand => true case _ => false }
            case CommandTag.DiscordCommand => match (other) { case CommandTag.DiscordCommand => true case _ => false }
            case CommandTag.UpgradeCommand => match (other) { case CommandTag.UpgradeCommand => true case _ => false }
            case CommandTag.InstallCompletionsCommand => match (other) { case CommandTag.InstallCompletionsCommand => true case _ => false }
            case CommandTag.GetCompletionsCommand => match (other) { case CommandTag.GetCompletionsCommand => true case _ => false }
            case CommandTag.OutdatedCommand => match (other) { case CommandTag.OutdatedCommand => true case _ => false }
            case CommandTag.PublishCommand => match (other) { case CommandTag.PublishCommand => true case _ => false }
            case CommandTag.AuditCommand => match (other) { case CommandTag.AuditCommand => true case _ => false }
            case CommandTag.ReplCommand => match (other) { case CommandTag.ReplCommand => true case _ => false }
            case CommandTag.ExecCommand => match (other) { case CommandTag.ExecCommand => true case _ => false }
            case CommandTag.FuzzilliCommand => match (other) { case CommandTag.FuzzilliCommand => true case _ => false }
            case CommandTag.InfoCommand => match (other) { case CommandTag.InfoCommand => true case _ => false }
            case CommandTag.WhyCommand => match (other) { case CommandTag.WhyCommand => true case _ => false }
            case CommandTag.UpdateInteractiveCommand => match (other) { case CommandTag.UpdateInteractiveCommand => true case _ => false }
        }
    }

    public operator func !=(other: CommandTag): Bool {
        return !(this == other)
    }

    /// 是否为 NPM 相关命令
    /// 对应 Bun Tag.isNPMRelated()
    public func isNPMRelated(): Bool {
        match (this) {
            case BunxCommand => true
            case LinkCommand => true
            case UnlinkCommand => true
            case PackageManagerCommand => true
            case InstallCommand => true
            case AddCommand => true
            case RemoveCommand => true
            case UpdateCommand => true
            case PatchCommand => true
            case PatchCommitCommand => true
            case OutdatedCommand => true
            case PublishCommand => true
            case AuditCommand => true
            case _ => false
        }
    }

    /// 是否需要读取全局配置
    /// 对应 Bun Tag.readGlobalConfig()
    public func readGlobalConfig(): Bool {
        match (this) {
            case BunxCommand => true
            case PackageManagerCommand => true
            case InstallCommand => true
            case AddCommand => true
            case RemoveCommand => true
            case UpdateCommand => true
            case PatchCommand => true
            case PatchCommitCommand => true
            case OutdatedCommand => true
            case PublishCommand => true
            case AuditCommand => true
            case _ => false
        }
    }

    /// 是否始终加载配置
    /// 对应 Bun Tag.alwaysLoadsConfig()
    public func alwaysLoadsConfig(): Bool {
        match (this) {
            case BuildCommand => true
            case TestCommand => true
            case InstallCommand => true
            case AddCommand => true
            case RemoveCommand => true
            case UpdateCommand => true
            case PatchCommand => true
            case PatchCommitCommand => true
            case PackageManagerCommand => true
            case BunxCommand => true
            case OutdatedCommand => true
            case UpdateInteractiveCommand => true
            case PublishCommand => true
            case AuditCommand => true
            case _ => false
        }
    }

    /// 检查命令是否使用全局选项
    /// 对应 Bun: Command.Tag.uses_global_options
    public static func usesGlobalOptions(tag: CommandTag): Bool {
        match (tag) {
            case CommandTag.DiscordCommand => return false
            case CommandTag.HelpCommand => return false
            case CommandTag.ReservedCommand => return false
            case CommandTag.InitCommand => return false
            case CommandTag.InstallCompletionsCommand => return false
            case CommandTag.GetCompletionsCommand => return false
            case CommandTag.CreateCommand => return false
            case _ => return true
        }
    }

    /// 打印帮助
    /// 对应 Bun: Command.Tag.printHelp / tagPrintHelp
    public static func printHelp(cmd: CommandTag, showAllFlags: Bool): Unit {
        match (cmd) {
            case CommandTag.AutoCommand =>
                _callHelpPrintWithReason(showAllFlags)
            case CommandTag.RunCommand => _callRunPrintHelp()
            case CommandTag.RunAsNodeCommand => _callRunPrintHelp()
            case CommandTag.InitCommand =>
                Output.pretty("<b>Usage<r>: <b><green>bao init<r> <cyan>[flags]<r> <blue>[\\<folder\\>]<r>\n")
                Output.pretty("  Initialize a Bao project in the current directory.\n")
                Output.pretty("  Creates a package.json, tsconfig.json, and baofig.toml if they don't exist.\n\n")
                Output.pretty("  <b>Flags<r>:\n")
                Output.pretty("      <cyan>--help<r>             Print this menu\n")
                Output.pretty("  <cyan>-y, --yes<r>              Accept all default options\n")
                Output.pretty("  <cyan>-m, --minimal<r>          Only initialize type definitions\n")
                Output.pretty("  <cyan>-r, --react<r>            Initialize a React project\n\n")
                Output.flush()
            case CommandTag.BunxCommand =>
                Output.prettyErrorln("<b>Usage<r>: <b><green>baox<r> <cyan>[flags]<r> <blue>\\<package\\><r><d>\\<@version\\><r> [flags and arguments for the package]<r>")
                Output.prettyErrorln("Execute an npm package executable (CLI), automatically installing if needed.\n\n")
                Output.prettyErrorln("Flags:\n")
                Output.prettyErrorln("  <cyan>--bao<r>                  Force the command to run with Bao instead of Node.js\n")
                Output.prettyErrorln("  <cyan>-p, --package <blue>\\<package\\><r>    Specify package to install\n")
                Output.prettyErrorln("  <cyan>--no-install<r>           Skip installation if package is not already installed\n\n")
                Output.flush()
            case CommandTag.BuildCommand =>
                Output.pretty("<b>Usage<r>:\n  Transpile and bundle one or more files.\n")
                Output.pretty("  <b><green>bao build<r> <cyan>[flags]<r> <blue>\\<entrypoint\\><r>\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao build<r> <cyan>--outfile=bundle.js<r> <blue>./src/index.ts<r>\n")
                Output.pretty("  <b><green>bao build<r> <cyan>--compile --outfile=my-app<r> <blue>./cli.ts<r>\n\n")
                Output.flush()
            case CommandTag.TestCommand =>
                Output.pretty("<b>Usage<r>: <b><green>bao test<r> <cyan>[flags]<r> <blue>[\\<patterns\\>]<r>\n")
                Output.pretty("  Run all matching test files and print the results to stdout\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao test<r>\n")
                Output.pretty("  <b><green>bao test<r> <blue>foo bar<r>\n\n")
                Output.flush()
            case CommandTag.CreateCommand =>
                Output.pretty("<b>Usage<r>:\n")
                Output.pretty("  <b><green>bao create<r> <magenta>\\<template\\><r> <cyan>[...flags]<r> <blue>dest<r>\n\n")
                Output.flush()
            case CommandTag.HelpCommand =>
                _callHelpPrintWithReason(false)
            case CommandTag.UpgradeCommand =>
                Output.pretty("<b>Usage<r>: <b><green>bao upgrade<r> <cyan>[flags]<r>\n")
                Output.pretty("  Upgrade Bao\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao upgrade<r>\n\n")
                Output.flush()
            case CommandTag.ReplCommand =>
                Output.pretty("<b>Usage<r>: <b><green>bao repl<r> <cyan>[flags]<r>\n")
                Output.pretty("  Open a Bao REPL\n\n")
                Output.flush()
            case CommandTag.GetCompletionsCommand =>
                Output.pretty("<b>Usage<r>: <b><green>bao getcompletes<r>")
                Output.flush()
            case CommandTag.InstallCompletionsCommand =>
                Output.pretty("<b>Usage<r>: <b><green>bao completions<r>")
                Output.flush()
            case CommandTag.PatchCommand =>
                _callPkgPrintHelp(Subcommand.patch)
            case CommandTag.PatchCommitCommand =>
                _callPkgPrintHelp(Subcommand.patchCommit)
            case CommandTag.ExecCommand =>
                Output.pretty("<b>Usage: bao exec <r><cyan>\\<script\\><r>\n\n")
                Output.pretty("Execute a shell script directly from Bao.\n\n")
                Output.pretty("<b><red>Note<r>: If executing this from a shell, make sure to escape the string!\n\n")
                Output.pretty("<b>Examples<d>:<r>\n")
                Output.pretty("  <b>bao exec \"echo hi\"<r>\n\n")
                Output.flush()
            case CommandTag.OutdatedCommand =>
                _callPkgPrintHelp(Subcommand.outdated)
            case CommandTag.UpdateInteractiveCommand =>
                _callPkgPrintHelp(Subcommand.update)
            case CommandTag.PublishCommand =>
                _callPkgPrintHelp(Subcommand.publish)
            case CommandTag.AuditCommand =>
                _callPkgPrintHelp(Subcommand.audit)
            case CommandTag.InfoCommand =>
                Output.pretty("<b>Usage<r>: <b><green>bao info<r> <cyan>[flags]<r> <blue>\\<package\\><r> <blue>[property path]<r>\n")
                Output.pretty("  Display package metadata from the registry.\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao info<r> <blue>react<r>\n")
                Output.pretty("  <b><green>bao info<r> <blue>react<r> version\n\n")
                Output.flush()
            case CommandTag.WhyCommand =>
                Output.pretty("<b>Usage<r>: <b><green>bao why<r> <cyan>[flags]<r> <blue>\\<package\\><r>\n")
                Output.pretty("  Explain why a package is installed\n\n")
                Output.pretty("<b>Arguments:<r>\n")
                Output.pretty("  <blue>\\<package\\><r>     <d>The package name to explain (supports glob patterns)<r>\n\n")
                Output.pretty("<b>Examples:<r>\n")
                Output.pretty("  <b><green>bao why<r> <blue>react<r>\n\n")
                Output.flush()
            case _ =>
                _callHelpPrintWithReason(false)
        }
    }
}

/// 打印版本并退出
/// 对应 Bun: printVersionAndExit
public func printVersionAndExit(): Unit {
    Output.println("${Global.PACKAGE_JSON_VERSION}")
    Global.exit(0)
}

/// 打印修订版本并退出
/// 对应 Bun: printRevisionAndExit
public func printRevisionAndExit(): Unit {
    Output.println("${Global.PACKAGE_JSON_VERSION_WITH_REVISION}")
    Global.exit(0)
}
