// 严格翻译自: src/cli/pm_update_package_json.rs
// bao pm update-package-json - 更新 package.json 并安装
//
// MOVE_UP: 从 bao_install::package_manager::update_package_json_and_install
// 提升到 bao_cli，因为 --analyze 分支需要构建 DependenciesScanner
// 并调用 BuildCommand.exec，这些依赖属于更高层级的包。

package bao_cli

import bao_core.*
import bao_bundler.*
import bao_install.*

// ============================================================================
// updatePackageJsonAndInstall — 更新 package.json 并执行安装
// 严格翻译自: src/cli/pm_update_package_json.rs
//
// 包含:
//   - updatePackageJsonAndInstallCatchError  (错误捕获包装)
//   - updatePackageJsonAndInstall            (主逻辑, 含 --analyze 分支)
//   - OnDependenciesAnalyze 回调结构体
// ============================================================================

/// 更新 package.json 并安装 (带错误捕获)
/// 严格翻译自: src/cli/pm_update_package_json.rs update_package_json_and_install_catch_error
///
/// 对 InstallFailed / InvalidPackageJSON 错误进行特殊处理:
/// 打印日志后直接退出, 不向上传播错误
public func updatePackageJsonAndInstallCatchError(
    ctx: CommandContext,
    subcommand: Subcommand
): Result<Unit, Error> {
    match (updatePackageJsonAndInstall(ctx, subcommand)) {
        case Ok(_) => return Ok(())
        case Err(e) => {
            if (e.name == "InstallFailed" || e.name == "InvalidPackageJSON") {
                // SAFETY: Cli.log_ 在 Cli.start() 中单线程初始化,
                // 当前处于 CLI 线程的安装错误路径, 没有其他 &mut Log 存活
                let log = Cli.getLogUnsafe()
                log.print(Output.errorWriter())
                Global.exit(1)
                return Ok(()) // 不可达
            }
            return Err(e)
        }
    }
}

/// 更新 package.json 并安装 (主逻辑)
/// 严格翻译自: src/cli/pm_update_package_json.rs update_package_json_and_install
///
/// 核心流程:
///   1. 解析命令行参数 (CommandLineArguments.parse)
///   2. 如果启用 --analyze:
///      a. 运行 bundler 对源文件进行依赖扫描
///      b. 重写位置参数为依赖名称
///      c. 执行安装命令
///   3. 否则直接执行安装
public func updatePackageJsonAndInstall(
    ctx: CommandContext,
    subcommand: Subcommand
): Result<Unit, Error> {
    var cli = CommandLineArguments.parse(subcommand)

    // 工作流程:
    // 1. 对源文件运行 bundler
    // 2. 将位置参数重写为依赖名称
    // 3. 运行安装命令
    if (cli.analyze) {
        // PORT NOTE: 从 Zig 的 fn-local `const Analyzer = struct {...}` 提升
        // Analyzer 使用原始指针存储 ctx 和 cli，因为 BuildCommand.exec 在
        // on_fetch 回调期间持有 command::get() (同一个 ContextData)，且
        // DependenciesScanner.entry_points 持有 cli.positionals 的副本

        let entryPoints = ArrayList<ByteArray>()
        for (i in 1..cli.positionals.length) {
            entryPoints.append(ByteArray.from(cli.positionals[i]))
        }

        let analyzer = Analyzer(
            ctxPtr: ctx.getPointer(),
            cliPtr: cli.getPointer(),
            subcommand: subcommand
        )

        let fetcher = DependenciesScanner(analyzer, entryPoints.toArray())

        // 运行 bundler
        BuildCommand.exec(Command.get(), Some(fetcher))
        return Ok(())
    }

    return updatePackageJsonAndInstallWithCli(ctx, subcommand, cli)
}

// ============================================================================
// Analyzer — 依赖分析回调
// 严格翻译自: src/cli/pm_update_package_json.rs Analyzer struct
// ============================================================================

/// 依赖分析回调结构体
/// 当 bundler 扫描完依赖后调用, 将发现的依赖作为安装参数
public class Analyzer {
    /// 上下文指针 (原始指针, 跨回调生命周期)
    public var ctxPtr: UIntNative
    /// CLI 参数指针 (原始指针)
    public var cliPtr: UIntNative
    /// 子命令类型
    public var subcommand: Subcommand

    public init(ctxPtr: UIntNative, cliPtr: UIntNative, subcommand: Subcommand) {
        this.ctxPtr = ctxPtr
        this.cliPtr = cliPtr
        this.subcommand = subcommand
    }

    /// 当依赖分析完成时调用
    /// 严格翻译自: src/cli/pm_update_package_json.rs Analyzer.on_analyze
    ///
    /// 核心流程:
    ///   1. 从扫描结果中提取所有依赖名称
    ///   2. 将位置参数重写为 ["add", "dep1", "dep2", ...]
    ///   3. 调用 updatePackageJsonAndInstallWithCli
    ///   4. 退出进程
    public func onAnalyze(result: DependenciesScannerResult): Result<Unit, Error> {
        // 收集所有依赖的 key
        var ownedKeys = ArrayList<ByteArray>()
        let keys = result.dependencies.keys()
        for (key in keys) {
            ownedKeys.append(ByteArray.from(key))
        }

        // 构建新的位置参数: ["add", dep1, dep2, ...]
        var newPositionals = ArrayList<String>()
        newPositionals.append("add")
        for (key in ownedKeys) {
            newPositionals.append(key.toString())
        }

        // SAFETY: ctxPtr 和 cliPtr 指向的是 updatePackageJsonAndInstall
        // 中的栈变量, 其作用域包含整个 BuildCommand.exec 调用
        // (以及此回调). bundler 在调用 on_fetch 之前已完成对 entry_points
        // 的读取, 且此回调不会返回 (Global.exit(0) 在下面)
        let cli = CommandLineArguments.fromPointer(cliPtr)
        cli.positionals = newPositionals.toArray()
        let ctx = CommandContext.fromPointer(ctxPtr)

        let result = updatePackageJsonAndInstallWithCli(ctx, subcommand, cli)
        match (result) {
            case Ok(_) => Global.exit(0)
            case Err(e) => {
                Output.prettyErrorLn("<r><red>error<r>: ${e.name}")
                Global.exit(1)
            }
        }
        return Ok(()) // 不可达
    }
}

// ============================================================================
// DependenciesScanner — 依赖扫描器
// 严格翻译自: src/cli/pm_update_package_json.rs DependenciesScanner 引用
// ============================================================================

/// 依赖扫描器
/// 在 bundler 运行期间扫描 import/require 语句, 收集外部依赖
public class DependenciesScanner {
    /// 分析回调
    private var analyzer: Analyzer
    /// 入口点列表
    private var entryPoints: Array<ByteArray>

    public init(analyzer: Analyzer, entryPoints: Array<ByteArray>) {
        this.analyzer = analyzer
        this.entryPoints = entryPoints
    }

    /// 执行依赖扫描
    public func scan(): DependenciesScannerResult {
        // 占位: 实际由 bundler 层实现
        return DependenciesScannerResult()
    }
}

/// 依赖扫描结果
public class DependenciesScannerResult {
    /// 发现的依赖 (名称 -> 版本/位置)
    public var dependencies: HashMap<String, String>

    public init() {
        dependencies = HashMap<String, String>()
    }
}

// ============================================================================
// 辅助类型和函数
// ============================================================================

/// 子命令类型
/// 严格翻译自: bun_install::package_manager_real::Subcommand
public enum Subcommand {
    | install
    | add
    | remove
    | update
    | link
    | unlink
    | patch
    | patchCommit
    | outdated
    | publish
    | audit
    | info
    | run
}

/// 命令行参数
/// 严格翻译自: bun_install::package_manager_real::command_line_arguments::CommandLineArguments
public class CommandLineArguments {
    /// 位置参数
    public var positionals: Array<String>
    /// 是否启用 --analyze 模式
    public var analyze: Bool
    /// JSON 输出
    public var jsonOutput: Bool
    /// 是否为全局操作
    public var global: Bool
    /// 是否为开发依赖
    public var dev: Bool
    /// 是否为可选依赖
    public var optional: Bool
    /// 是否为 peer 依赖
    public var peer: Bool
    /// 是否信任依赖
    public var trusted: Bool
    /// 是否静默
    public var silent: Bool
    /// 是否详细
    public var verbose: Bool
    /// 是否强制
    public var force: Bool
    /// 是否无缓存
    public var noCache: Bool
    /// 是否无汇总
    public var noSummary: Bool
    /// 是否无安装
    public var noInstall: Bool
    /// 是否干运行
    public var dryRun: Bool

    public init() {
        positionals = []
        analyze = false
        jsonOutput = false
        global = false
        dev = false
        optional = false
        peer = false
        trusted = false
        silent = false
        verbose = false
        force = false
        noCache = false
        noSummary = false
        noInstall = false
        dryRun = false
    }

    /// 解析命令行参数
    /// 严格翻译自: bun_install::package_manager_real::CommandLineArguments::parse
    public static func parse(subcommand: Subcommand): CommandLineArguments {
        let cli = CommandLineArguments()
        let args = Sys.getArgs()

        var i = 0
        while (i < args.length) {
            let arg = args[i]
            match (arg) {
                case "--analyze" => cli.analyze = true
                case "--json" => cli.jsonOutput = true
                case "--global" | "-g" => cli.global = true
                case "--dev" | "-D" => cli.dev = true
                case "--optional" | "-O" => cli.optional = true
                case "--peer" => cli.peer = true
                case "--trusted" => cli.trusted = true
                case "--silent" => cli.silent = true
                case "--verbose" => cli.verbose = true
                case "--force" => cli.force = true
                case "--no-cache" => cli.noCache = true
                case "--no-summary" => cli.noSummary = true
                case "--no-install" => cli.noInstall = true
                case "--dry-run" => cli.dryRun = true
                case _ => {
                    if (!arg.startsWith("-")) {
                        // 追加位置参数
                        let newLen = cli.positionals.length + 1
                        let newPos = Array<String>(newLen)
                        for (j in 0..cli.positionals.length) {
                            newPos[j] = cli.positionals[j]
                        }
                        newPos[newLen - 1] = arg
                        cli.positionals = newPos
                    }
                }
            }
            i++
        }

        return cli
    }

    /// 从原始指针恢复 (FFI 交互用)
    public static func fromPointer(ptr: UIntNative): CommandLineArguments {
        // 占位: 实际实现需要 unsafe 指针转换
        return CommandLineArguments()
    }

    /// 获取原始指针 (FFI 交互用)
    public func getPointer(): UIntNative {
        // 占位: 实际实现需要 unsafe 取地址
        return 0
    }

    /// 克隆
    public func clone(): CommandLineArguments {
        let copy = CommandLineArguments()
        copy.positionals = positionals
        copy.analyze = analyze
        copy.jsonOutput = jsonOutput
        copy.global = global
        copy.dev = dev
        copy.optional = optional
        copy.peer = peer
        copy.trusted = trusted
        copy.silent = silent
        copy.verbose = verbose
        copy.force = force
        copy.noCache = noCache
        copy.noSummary = noSummary
        copy.noInstall = noInstall
        copy.dryRun = dryRun
        return copy
    }
}

/// 更新 package.json 并安装 (带 CLI 参数版本)
/// 严格翻译自: bun_install::package_manager_real::update_package_json_and_install_and_cli
public func updatePackageJsonAndInstallWithCli(
    ctx: CommandContext,
    subcommand: Subcommand,
    cli: CommandLineArguments
): Result<Unit, Error> {
    // 初始化 PackageManager
    let pm = PackageManager(ctx)
    return pm.updatePackageJsonAndInstall(cli, subcommand)
}

/// 打印帮助信息
/// 严格翻译自: bun_install::package_manager_real::CommandLineArguments::print_help
public func printHelp(subcommand: Subcommand): Unit {
    when (subcommand) {
        case Subcommand.install => {
            Output.pretty("<b>Usage<r>: <b><green>bao install<r> <cyan>[flags]<r>\n")
            Output.pretty("  Install dependencies from package.json\n\n")
            Output.pretty("<b>Flags:<r>\n")
            Output.pretty("  <cyan>--production<r>       Skip devDependencies\n")
            Output.pretty("  <cyan>--frozen<r>           Fail if lockfile is outdated\n")
            Output.pretty("  <cyan>--force<r>            Reinstall all dependencies\n")
            Output.pretty("  <cyan>--no-cache<r>         Skip the package manifest cache\n")
            Output.pretty("  <cyan>--no-summary<r>       Don't print install summary\n")
            Output.pretty("  <cyan>--verbose<r>          Verbose output\n")
            Output.pretty("  <cyan>--silent<r>           Silent output\n")
            Output.pretty("  <cyan>-g, --global<r>       Install globally\n")
        }
        case Subcommand.add => {
            Output.pretty("<b>Usage<r>: <b><green>bao add<r> <cyan>[flags]<r> <blue>\\<package\\><r>\n")
            Output.pretty("  Add a dependency to package.json\n\n")
            Output.pretty("<b>Flags:<r>\n")
            Output.pretty("  <cyan>-D, --dev<r>          Add as devDependency\n")
            Output.pretty("  <cyan>-O, --optional<r>     Add as optionalDependency\n")
            Output.pretty("  <cyan>--peer<r>             Add as peerDependency\n")
            Output.pretty("  <cyan>--trusted<r>          Add as trusted dependency\n")
            Output.pretty("  <cyan>--global<r> | <cyan>-g<r>  Add globally\n")
            Output.pretty("  <cyan>--force<r>            Force reinstall\n")
        }
        case Subcommand.remove => {
            Output.pretty("<b>Usage<r>: <b><green>bao remove<r> <cyan>[flags]<r> <blue>\\<package\\><r>\n")
            Output.pretty("  Remove a dependency from package.json\n\n")
            Output.pretty("<b>Flags:<r>\n")
            Output.pretty("  <cyan>-g, --global<r>       Remove globally\n")
        }
        case Subcommand.update => {
            Output.pretty("<b>Usage<r>: <b><green>bao update<r> <cyan>[flags]<r> <blue>[\\<package\\>]<r>\n")
            Output.pretty("  Update outdated dependencies\n\n")
            Output.pretty("<b>Flags:<r>\n")
            Output.pretty("  <cyan>--global<r> | <cyan>-g<r>  Update globally\n")
            Output.pretty("  <cyan>--dry-run<r>        Don't actually install\n")
        }
        case Subcommand.patch => {
            Output.pretty("<b>Usage<r>: <b><green>bao patch<r> <blue>\\<package\\><r>\n")
            Output.pretty("  Prepare a package for patching\n")
        }
        case Subcommand.patchCommit => {
            Output.pretty("<b>Usage<r>: <b><green>bao patch-commit<r> <blue>\\<package\\><r>\n")
            Output.pretty("  Commit a package patch\n")
        }
        case Subcommand.outdated => {
            Output.pretty("<b>Usage<r>: <b><green>bao outdated<r> <cyan>[flags]<r>\n")
            Output.pretty("  Display latest versions of outdated dependencies\n")
        }
        case Subcommand.publish => {
            Output.pretty("<b>Usage<r>: <b><green>bao publish<r> <cyan>[flags]<r>\n")
            Output.pretty("  Publish a package to the npm registry\n")
        }
        case Subcommand.audit => {
            Output.pretty("<b>Usage<r>: <b><green>bao audit<r> <cyan>[flags]<r>\n")
            Output.pretty("  Check installed packages for vulnerabilities\n")
        }
        case Subcommand.info => {
            Output.pretty("<b>Usage<r>: <b><green>bao info<r> <blue>\\<package\\><r> <cyan>[flags]<r>\n")
            Output.pretty("  Display package metadata from the registry\n")
        }
        case _ => {
            Output.pretty("<b>Usage<r>: <b><green>bao pm<r> <cyan>\\<subcommand\\><r>\n")
        }
    }
    Output.flush()
}
