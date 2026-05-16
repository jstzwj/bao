// 严格翻译自: src/cli/mod.rs
// bao_cli — CLI 入口包
//
// 对应 Bun: src/cli/mod.rs (Rust) + src/cli/cli.zig (Zig)
// 包含: 模块声明, 全局变量, CLI 入口函数,
//        process-lifetime arena, 辅助工具函数
package bao_cli

import bao_core.*
import bao_collections.*
import bao_runtime.*
import bao_bundler.*
import bao_install.*
import bao_parser.*
import bao_io.*
import bao_sys.*
import bao_http.*
import bao_sql.*
import bao_path.*

// ============================================================================
// 模块声明
// 严格翻译自: src/cli/mod.rs 中的 #[path = "..."] pub mod ...
// ============================================================================

// ci_info 模块: CI 环境检测
// 对应: src/cli/ci_info.zig

// colon_list_type 模块: 冒号分隔列表类型
// 对应: src/cli/colon_list_type.zig

// shell_completions 模块: Shell 补全
// 对应: src/cli/shell_completions.zig

// which_npm_client 模块: NPM 客户端检测
// 对应: src/cli/which_npm_client.zig

// discord_command 模块: 打开 Discord
// 对应: src/cli/discord_command.zig

// list_of_yarn_commands 模块: yarn 命令列表
// 对应: src/cli/list-of-yarn-commands.zig

// open 模块: URL 打开 / 编辑器
// 对应: src/cli/open.zig

// init_command 模块: bao init
// 对应: src/cli/init_command.zig (commands/init_cmd.cj)

// install_completions_command 模块: 补全安装
// 对应: src/cli/install_completions_command.zig

// package_manager_command 模块: bao pm
// 对应: src/cli/package_manager_command.zig

// test_command 模块: bao test
// 对应: src/cli/test_command.zig (commands/test_command.cj)

// test 子模块:
//   scanner: test/Scanner.zig
//   changed_files_filter: test/ChangedFilesFilter.zig
//   parallel_runner: test/ParallelRunner.zig
//   parallel/aggregate, channel, coordinator, file_range, frame, runner, worker

// arguments 模块: 参数解析
// 对应: src/cli/Arguments.zig (args.cj)

// bunfig 模块: bunfig.toml 配置
// 对应: src/cli/bunfig.zig

// run_command 模块: bao run
// 对应: src/cli/run_command.zig (commands/run_command.cj)

// per-subcommand 模块:
//   build_command, bunx_command (x), create_command, exec_command,
//   fuzzilli_command, install_command, repl_command, upgrade_command,
//   add_command, audit_command, filter_arg, filter_run,
//   link_command, outdated_command, pack_command, patch_command,
//   patch_commit_command, pm_pkg_command, pm_trusted_command,
//   pm_update_package_json, pm_version_command, pm_view_command,
//   pm_why_command, publish_command, remove_command, scan_command,
//   unlink_command, update_command, update_interactive_command, why_command,
//   multi_run

// ============================================================================
// CLI 命令定义 (兼容旧代码)
// 对应 Bun: src/runtime/cli/command.zig
// ============================================================================

/// CLI 命令类型 (简化版, 实际命令路由在 cli.cj 中)
public enum Command {
    | Run(RunOptions)         // bun run
    | Build(BuildOptions)     // bun build
    | Install(InstallCliOptions) // bun install
    | Test(TestOptions)       // bun test
    | Init(InitOptions)       // bun init
    | Version                 // --version
    | Help                    // --help
    | Repl                    // bun (无参数)
}

/// run 命令选项
public class RunOptions {
    public var script: String
    public var args: ArrayList<String>
    public var watch: Bool
    public var silent: Bool

    public init() {
        script = ""
        args = ArrayList<String>()
        watch = false
        silent = false
    }
}

/// build 命令选项
public class BuildOptions {
    public var entryPoints: ArrayList<String>
    public var outdir: String
    public var minify: Bool
    public var sourcemap: Bool
    public var target: String
    public var format: String

    public init() {
        entryPoints = ArrayList<String>()
        outdir = "./dist"
        minify = false
        sourcemap = false
        target = "browser"
        format = "esm"
    }
}

/// test 命令选项
public class TestOptions {
    public var patterns: ArrayList<String>
    public var watch: Bool
    public var coverage: Bool
    public var verbose: Bool

    public init() {
        patterns = ArrayList<String>()
        watch = false
        coverage = false
        verbose = false
    }
}

/// init 命令选项
public class InitOptions {
    public var name: String
    public var template: String  // "default" | "minimal" | "library"

    public init() {
        name = "my-app"
        template = "default"
    }
}

/// 安装选项 (CLI 层)
public class InstallCliOptions {
    public var production: Bool
    public var frozen: Bool
    public var verbose: Bool
    public var add: ?String
    public var remove: ?String

    public init() {
        production = false
        frozen = false
        verbose = false
        add = None
        remove = None
    }
}

// ============================================================================
// CLI 参数解析器
// 对应 Bun: src/clap/
// ============================================================================

/// 命令行参数解析器
public class CliParser {
    /// 解析命令行参数
    public static func parse(args: ArrayList<String>): Command {
        if (args.size == 0) {
            return Command.Repl
        }

        let first = args[0]
        match (first) {
            case "run" => {
                let options = RunOptions()
                var i = 1
                while (i < args.size) {
                    match (args[i]) {
                        case "--watch" | "-w" => options.watch = true
                        case "--silent" => options.silent = true
                        case _ => {
                            if (options.script.length == 0) {
                                options.script = args[i]
                            } else {
                                options.args.append(args[i])
                            }
                        }
                    }
                    i++
                }
                return Command.Run(options)
            }
            case "build" => {
                let options = BuildOptions()
                var i = 1
                while (i < args.size) {
                    match (args[i]) {
                        case "--outdir" => {
                            i++
                            if (i < args.size) { options.outdir = args[i] }
                        }
                        case "--minify" | "-m" => options.minify = true
                        case "--sourcemap" => options.sourcemap = true
                        case "--target" => {
                            i++
                            if (i < args.size) { options.target = args[i] }
                        }
                        case "--format" => {
                            i++
                            if (i < args.size) { options.format = args[i] }
                        }
                        case _ => options.entryPoints.append(args[i])
                    }
                    i++
                }
                return Command.Build(options)
            }
            case "install" | "i" => {
                let options = InstallCliOptions()
                var i = 1
                while (i < args.size) {
                    match (args[i]) {
                        case "--production" | "-p" => options.production = true
                        case "--frozen" => options.frozen = true
                        case "--verbose" | "-v" => options.verbose = true
                        case "add" => {
                            i++
                            if (i < args.size) { options.add = Some(args[i]) }
                        }
                        case "remove" => {
                            i++
                            if (i < args.size) { options.remove = Some(args[i]) }
                        }
                        case _ => ()
                    }
                    i++
                }
                return Command.Install(options)
            }
            case "test" => {
                let options = TestOptions()
                var i = 1
                while (i < args.size) {
                    match (args[i]) {
                        case "--watch" | "-w" => options.watch = true
                        case "--coverage" | "-c" => options.coverage = true
                        case "--verbose" | "-v" => options.verbose = true
                        case _ => options.patterns.append(args[i])
                    }
                    i++
                }
                return Command.Test(options)
            }
            case "init" => {
                let options = InitOptions()
                var i = 1
                while (i < args.size) {
                    match (args[i]) {
                        case "--name" | "-n" => {
                            i++
                            if (i < args.size) { options.name = args[i] }
                        }
                        case "--template" | "-t" => {
                            i++
                            if (i < args.size) { options.template = args[i] }
                        }
                        case _ => options.name = args[i]
                    }
                    i++
                }
                return Command.Init(options)
            }
            case "--version" | "-v" => return Command.Version
            case "--help" | "-h" => return Command.Help
            case _ => {
                // 直接运行脚本
                let options = RunOptions()
                options.script = first
                for (i in 1..args.size) {
                    options.args.append(args[i])
                }
                return Command.Run(options)
            }
        }
    }
}

// ============================================================================
// 主入口
// 对应 Bun: src/bun.rs
// ============================================================================

/// Bao 版本号
public let BAO_VERSION = "0.1.0"

/// Bao CLI 主入口
public func main(): Unit {
    let args = getArgs()
    let command = CliParser.parse(args)

    match (command) {
        case Command.Run(opts) => executeRun(opts)
        case Command.Build(opts) => executeBuild(opts)
        case Command.Install(opts) => executeInstall(opts)
        case Command.Test(opts) => executeTest(opts)
        case Command.Init(opts) => executeInit(opts)
        case Command.Version => printVersion()
        case Command.Help => printHelp()
        case Command.Repl => executeRepl()
    }
}

/// 获取命令行参数
private func getArgs(): ArrayList<String> {
    // 仓颉标准库获取命令行参数
    // 实际使用: std.os.getArgs() 或类似
    let result = ArrayList<String>()
    // 占位: 从系统获取参数
    return result
}

/// 执行 run 命令
/// 对应 Bun: bun run <script>
private func executeRun(opts: RunOptions): Unit {
    if (opts.script.isEmpty()) {
        // 没有指定脚本 — 尝试从 package.json 的 scripts 读取
        let pkgOpt = readPackageJson()
        match (pkgOpt) {
            case Some(pkg) => {
                println("Available scripts:")
                for (key in pkg.scripts.keys()) {
                    match (pkg.scripts.get(key)) {
                        case Some(cmd) => println("  ${key}: ${cmd}")
                        case None => ()
                    }
                }
            }
            case None => println("error: no script specified and no package.json found")
        }
        return
    }

    // 先检查是否是 package.json 中的 script 名称
    let pkgOpt = readPackageJson()
    match (pkgOpt) {
        case Some(pkg) => {
            match (pkg.scripts.get(opts.script)) {
                case Some(cmd) => {
                    // 运行 package.json 中定义的脚本命令
                    if (!opts.silent) {
                        println("$ ${cmd}")
                    }
                    // 实际应 spawn 子进程执行 shell 命令
                    // 简化: 直接作为 JS 文件执行
                    let vm = VirtualMachine()
                    try {
                        vm.eval(cmd, "<script>")
                    } catch (e: Exception) {
                        println("error: ${e.message}")
                    }
                    return
                }
                case None => ()
            }
        }
        case None => ()
    }

    // 作为 JS/TS 文件执行
    let vm = VirtualMachine()
    try {
        vm.executeFile(opts.script)
    } catch (e: Exception) {
        println("error: ${e.message}")
    }
}

/// 执行 build 命令
/// 对应 Bun: bun build <entry...>
private func executeBuild(opts: BuildOptions): Unit {
    if (opts.entryPoints.size == 0) {
        println("error: no entry points specified")
        println("Usage: bao build <entry...> [--outdir <dir>] [--minify] [--sourcemap]")
        return
    }

    println("Building ${opts.entryPoints.size} entry point(s)...")

    let bundler = Bundler()
    let bundleOpts = BundleOptions()
    for (ep in opts.entryPoints) {
        bundleOpts.entryPoints.append(ep)
    }
    bundleOpts.outdir = opts.outdir
    bundleOpts.minify = opts.minify
    bundleOpts.sourcemap = opts.sourcemap
    bundleOpts.target = opts.target

    let result = bundler.bundle(bundleOpts)
    if (result.hasErrors()) {
        for (err in result.errors) {
            println("error: ${err}")
        }
        return
    }

    for (warn in result.warnings) {
        println("warning: ${warn}")
    }

    // 确保输出目录存在
    BaoFile.mkdir(opts.outdir, true)

    // 写入输出文件
    for (file in result.outputFiles) {
        BaoFile.writeAllBytes(file.path, file.content)
        println("  ${file.path} (${file.content.size} bytes)")
    }

    println("Build complete!")
}

/// 执行 install 命令
/// 对应 Bun: bun install
private func executeInstall(opts: InstallCliOptions): Unit {
    let pm = PackageManager()
    let installOpts = InstallOptions()
    installOpts.production = opts.production
    installOpts.frozen = opts.frozen
    installOpts.verbose = opts.verbose

    // 处理 add/remove 子命令
    match (opts.add) {
        case Some(name) => {
            pm.add(name, None)
            return
        }
        case None => ()
    }
    match (opts.remove) {
        case Some(name) => {
            pm.remove(name)
            return
        }
        case None => ()
    }

    try {
        pm.install(installOpts)
    } catch (e: Exception) {
        println("error: ${e.message}")
    }
}

/// 执行 test 命令
/// 对应 Bun: bun test
private func executeTest(opts: TestOptions): Unit {
    println("Running tests...")

    let vm = VirtualMachine()
    var passed = 0
    var failed = 0
    var total = 0

    // 查找测试文件
    let testPatterns = if (opts.patterns.size > 0) {
        opts.patterns
    } else {
        let defaults = ArrayList<String>()
        defaults.append(".test.js")
        defaults.append(".test.ts")
        defaults.append("_test.js")
        defaults.append("_test.ts")
        defaults.append(".spec.js")
        defaults.append(".spec.ts")
        defaults
    }

    // 扫描当前目录查找测试文件
    let testFiles = findTestFiles(".", testPatterns)

    if (testFiles.size == 0) {
        println("No test files found")
        return
    }

    println("Found ${testFiles.size} test file(s)\n")

    for (testFile in testFiles) {
        if (opts.verbose) {
            println("  ${testFile}")
        }
        try {
            vm.executeFile(testFile)
            passed++
            println("  PASS ${testFile}")
        } catch (e: Exception) {
            failed++
            println("  FAIL ${testFile}")
            println("    ${e.message}")
        }
        total++
    }

    println("")
    println("Tests: ${passed} passed, ${failed} failed, ${total} total")
}

/// 查找测试文件
private func findTestFiles(dir: String, patterns: ArrayList<String>): ArrayList<String> {
    let result = ArrayList<String>()
    let entries = BaoFile.readdir(dir)
    for (entry in entries) {
        let fullPath = if (dir == ".") { entry } else { dir + "/" + entry }
        // 跳过 node_modules
        if (entry == "node_modules" || entry == ".git") { continue }
        for (pattern in patterns) {
            if (entry.endsWith(pattern)) {
                result.append(fullPath)
            }
        }
    }
    return result
}

/// 执行 init 命令
/// 对应 Bun: bun init
private func executeInit(opts: InitOptions): Unit {
    println("Initializing project: ${opts.name}")

    // package.json
    let packageJson = "{\n" +
        "  \"name\": \"${opts.name}\",\n" +
        "  \"version\": \"1.0.0\",\n" +
        "  \"scripts\": {\n" +
        "    \"start\": \"bao run index.js\",\n" +
        "    \"test\": \"bao test\"\n" +
        "  }\n" +
        "}\n"
    BaoFile.writeAllText("package.json", packageJson)
    println("  Created package.json")

    // index.js
    let indexJs = match (opts.template) {
        case "minimal" => "console.log(\"Hello from ${opts.name}!\");\n"
        case "library" => "// ${opts.name}\nexport function hello() {\n  return \"Hello!\";\n}\n"
        case _ => "console.log(\"Hello from ${opts.name}!\");\n"
    }
    BaoFile.writeAllText("index.js", indexJs)
    println("  Created index.js")

    // tsconfig.json (如果模板不是 minimal)
    if (opts.template != "minimal") {
        let tsconfig = "{\n" +
            "  \"compilerOptions\": {\n" +
            "    \"target\": \"ES2020\",\n" +
            "    \"module\": \"ESNext\",\n" +
            "    \"strict\": true,\n" +
            "    \"esModuleInterop\": true,\n" +
            "    \"outDir\": \"./dist\"\n" +
            "  },\n" +
            "  \"include\": [\"*.ts\", \"src/**/*.ts\"]\n" +
            "}\n"
        BaoFile.writeAllText("tsconfig.json", tsconfig)
        println("  Created tsconfig.json")
    }

    // .gitignore
    let gitignore = "node_modules/\ndist/\n*.log\n.env\n"
    BaoFile.writeAllText(".gitignore", gitignore)
    println("  Created .gitignore")

    // README.md
    let readme = "# ${opts.name}\n\nA JavaScript/TypeScript project.\n\n## Usage\n\n```bash\nbao run index.js\n```\n"
    BaoFile.writeAllText("README.md", readme)
    println("  Created README.md")

    println("\nProject initialized successfully!")
}

/// 执行 REPL
/// 对应 Bun: bun (无参数进入交互模式)
private func executeRepl(): Unit {
    println("Bao v${BAO_VERSION} REPL")
    println("Type .exit to quit, .help for help\n")

    let vm = VirtualMachine()
    // 实际 REPL 需要逐行读取 stdin
    // 当前为简化实现
    println("REPL mode: read from stdin not yet implemented")
    println("Use: bao run <file.js> to execute JavaScript files")
}

/// 读取 package.json (复用 install 包的 JSON 解析)
private func readPackageJson(): ?PackageInfo {
    let content = try {
        BaoFile.readAllText("package.json")
    } catch (_: Exception) {
        return None
    }

    let jsonParser = JsonParser()
    let json = jsonParser.parse(content)
    match (json) {
        case Some(root) => {
            let name = match (JsonHelper.getString(root, "name")) {
                case Some(n) => n
                case None => "unknown"
            }
            let versionStr = match (JsonHelper.getString(root, "version")) {
                case Some(v) => v
                case None => "0.0.0"
            }
            let version = match (SemVer.parse(versionStr)) {
                case Some(v) => v
                case None => SemVer(0, 0, 0)
            }

            let pkg = PackageInfo(name, version)
            pkg.main = match (JsonHelper.getString(root, "main")) {
                case Some(m) => m
                case None => "index.js"
            }
            pkg.dependencies = JsonHelper.getStringMap(root, "dependencies")
            pkg.devDependencies = JsonHelper.getStringMap(root, "devDependencies")

            match (JsonHelper.getField(root, "scripts")) {
                case Some(JsonValue.Object(scripts)) => {
                    for (k in scripts.keys()) {
                        match (scripts.get(k)) {
                            case Some(JsonValue.Str(v)) => pkg.scripts.put(k, v)
                            case _ => ()
                        }
                    }
                }
                case _ => ()
            }

            return Some(pkg)
        }
        case None => return None
    }
}

/// 打印版本
private func printVersion(): Unit {
    println("bao v${BAO_VERSION}")
    println("Cangjie JavaScript Runtime & Toolkit")
}

/// 打印帮助
private func printHelp(): Unit {
    println("Bao - JavaScript Runtime & Toolkit (Cangjie)")
    println("")
    println("Usage: bao <command> [options]")
    println("")
    println("Commands:")
    println("  run <file|script>   Run a JavaScript/TypeScript file or package.json script")
    println("  build <entry...>    Bundle JavaScript/TypeScript files")
    println("  install [add|rm]    Install or manage dependencies")
    println("  test [patterns...]  Run tests")
    println("  init [name]         Create a new project")
    println("")
    println("Run Options:")
    println("  --watch, -w         Watch for file changes")
    println("  --silent            Suppress output")
    println("")
    println("Build Options:")
    println("  --outdir <dir>      Output directory (default: ./dist)")
    println("  --minify, -m        Minify output")
    println("  --sourcemap         Generate source maps")
    println("  --target <target>   Target environment (browser|node)")
    println("  --format <fmt>      Output format (esm|cjs|iife)")
    println("")
    println("Test Options:")
    println("  --watch, -w         Watch for changes")
    println("  --coverage, -c      Generate coverage report")
    println("  --verbose, -v       Verbose output")
    println("")
    println("Init Options:")
    println("  --name, -n          Project name")
    println("  --template, -t      Template (default|minimal|library)")
    println("")
    println("Global Options:")
    println("  --version, -v       Print version")
    println("  --help, -h          Print this help")
}
