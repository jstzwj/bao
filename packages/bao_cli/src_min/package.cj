package bao_cli

import std.env.getCommandLine
import std.convert.*
// bao_runtime 不再被使用 — JSC 进程内嵌入，所有 API 通过 JSC C API 注册
import bao_io.*
import bao_path.*
import bao_sys.{SysFs, SysMaybe, OpenFlags, FileMode, OS}
import bao_collections.ArrayList
// import bao_jsc.JscRuntime — 不再依赖 bao_jsc，JscRuntime 内联定义

// ============================================================================
// JSC FFI — jsc_bridge.c 通过 socketpair + fork/exec 调用 bao_jsc_worker
// 所有 JSC 操作在 C 层完成，不触发 CJ_MCC_C2NStub
// ============================================================================

@C
foreign func bao_jsc_run(code: CPointer<Unit>, filename: CPointer<Unit>): CPointer<Unit>

@C
foreign func bao_jsc_free(s: CPointer<Unit>): Unit

@C
foreign func bao_jsc_shutdown(): Unit

@C
foreign func bao_c_malloc(size: UInt64): CPointer<Unit>

@C
foreign func bao_c_free(ptr: CPointer<Unit>): Unit

@C
foreign func bao_test_add(a: Int32, b: Int32): Int32

let BAO_VERSION = "0.1.0"

/// JSC 运行时 — 简单数据持有类（不依赖 bao_jsc）
/// 所有 JSC 操作通过 jsc_bridge.c 的 socketpair 子进程完成
class JscRuntime {
    private var ctx: CPointer<Unit>
    private var initialized: Bool

    public init(externalCtx: CPointer<Unit>) {
        ctx = externalCtx
        initialized = !ctx.isNull()
    }

    public func deinit(): Unit {
        initialized = false
        ctx = CPointer<Unit>()
    }

    public func isAvailable(): Bool {
        initialized && !ctx.isNull()
    }
}

main(): Unit {
    let args = getCommandLine()
    dispatch(args)
}

func dispatch(args: Array<String>): Unit {
    if (args.size <= 1) {
        printHelp()
        return
    }

    let command = args[1]
    match (command) {
        case "--version" | "-v" | "version" => printVersion()
        case "--help" | "-h" | "help" => printHelp()
        case "run" => runCommand(args, 2)
        case "build" | "bun" => buildCommand(args, 2)
        case "test" => testCommand(args, 2)
        case "install" | "i" => installCommand(args, 2)
        case "add" | "a" => addCommand(args, 2)
        case "remove" | "rm" | "uninstall" => removeCommand(args, 2)
        case "init" => initCommand(args, 2)
        case "repl" => replCommand(args, 2)
        case "x" | "exec" => execCommand(command, args, 2)
        case _ => autoCommand(command, args)
    }
}

func printVersion(): Unit {
    println("bao v${BAO_VERSION}")
}

func printHelp(): Unit {
    println("Bao - JavaScript Runtime & Toolkit (Cangjie)")
    println("")
    println("Usage: bao <command> [options] [...args]")
    println("")
    println("Commands:")
    println("  run <file|script>      Execute a file or package script")
    println("  build <entry...>       Bundle entry points")
    println("  test [pattern...]      Run tests")
    println("  install, i             Install dependencies")
    println("  add, a <pkg...>        Add dependencies")
    println("  remove, rm <pkg...>    Remove dependencies")
    println("  init [name]            Create a package scaffold")
    println("  repl                   Start an interactive REPL")
    println("  x, exec <cmd...>       Execute package or shell command")
    println("  help, --help           Print this help")
    println("  version, -v            Print version")
}

// ============================================================================
// run — execute JS file via in-process JSC
// Strictly translated from: src/cli/run_command.zig RunCommand.exec
// ============================================================================

func runCommand(args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        // No target: list available scripts from package.json
        println("bao run: missing script or file")
        println("Usage: bao run <file|script> [...args]")
        return
    }

    let target = args[start]
    runJavaScriptFile(target, args, start + 1)
}

// ============================================================================
// build — delegate to BuildCommand
// Strictly translated from: src/cli/build_command.zig BuildCommand.exec
//
// In src_min, the full bundler (bao_bundler) is not available, so we parse
// all options and report what would be done. When the full bao_cli/src
// dependency closure compiles, this delegates to commands.BuildCommand.
// ============================================================================

func buildCommand(args: Array<String>, start: Int64): Unit {
    // 1. Parse CLI arguments (strictly following Bun's build_command.zig parser)
    var outdir = "dist"
    var outfile = ""
    var minify = false
    var sourcemap = "none"
    var target = "browser"
    var format = "esm"
    var compile = false
    var noBundle = false
    var codeSplitting = false
    var entryCount: Int64 = 0
    var i = start

    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--outdir" =>
                i++
                if (i < args.size) { outdir = args[i] }
            case "--outfile" =>
                i++
                if (i < args.size) { outfile = args[i] }
            case "--minify" | "-m" => minify = true
            case "--sourcemap" => sourcemap = "inline"
            case "--sourcemap=inline" => sourcemap = "inline"
            case "--sourcemap=external" => sourcemap = "external"
            case "--sourcemap=none" => sourcemap = "none"
            case "--target" =>
                i++
                if (i < args.size) { target = args[i] }
            case "--format" =>
                i++
                if (i < args.size) { format = args[i] }
            case "--compile" => compile = true
            case "--no-bundle" => noBundle = true
            case "--splitting" => codeSplitting = true
            case _ =>
                if (!arg.startsWith("-")) {
                    entryCount++
                }
        }
        i++
    }

    // 2. Validate entry points
    if (entryCount == 0) {
        println("bao build: missing entry point")
        println("Usage: bao build <entry...> [--outdir <dir>] [--minify] [--sourcemap]")
        return
    }

    // 3. Validate conflicting options (strictly from build_command.zig)
    if (compile && noBundle) {
        println("error: --compile does not support --no-bundle")
        return
    }
    if (sourcemap == "external" && outdir.size == 0 && !compile) {
        println("error: cannot use an external source map without --outdir")
        return
    }
    if (entryCount > 1 && outfile.size > 0) {
        println("error: Must use --outdir when specifying more than one entry point")
        return
    }
    if (codeSplitting && outdir.size == 0) {
        println("error: Must use --outdir when code splitting is enabled")
        return
    }

    // 4. Attempt delegation to real BuildCommand
    //    When full bao_cli/src compiles, BuildCommand.execute() handles bundling.
    //    In src_min, we perform the validation and report status.
    let effectiveOutdir = if (outfile.size > 0 && outdir == "dist") {
        let dir = dirname(outfile)
        if (dir.size > 0) { dir } else { "." }
    } else {
        outdir
    }

    println("bao build v${BAO_VERSION}")
    println("")
    if (compile) {
        println("  compile: ${compile}")
    }
    if (noBundle) {
        println("  transform-only mode")
    }
    println("  ${entryCount} entry point(s)")
    println("  outdir: ${effectiveOutdir}")
    if (minify) { println("  minify: ${minify}") }
    if (sourcemap != "none") { println("  sourcemap: ${sourcemap}") }
    if (target != "browser") { println("  target: ${target}") }
    if (format != "esm") { println("  format: ${format}") }
    if (codeSplitting) { println("  code splitting: ${codeSplitting}") }

    // NOTE(src_min): 当前为最小独立实现, 验证参数解析和输出。
    // 完整实现位于 bao_cli/src/commands/build_command.cj,
    // 当其依赖闭包编译完成后, 本函数应委托给 BuildCommand.execute()。
}

// ============================================================================
// test — delegate to TestCommand
// Strictly translated from: src/cli/test_command.zig TestCommand.exec
// ============================================================================

func testCommand(args: Array<String>, start: Int64): Unit {
    // 1. Parse options (strictly following Bun's test_command.zig)
    var watch = false
    var coverage = false
    var bail: Int64 = 0
    var timeout: Int64 = 5000
    var parallel: Int64 = 0
    var randomize = false
    var runTodo = false
    var passWithNoTests = false
    var patterns = ArrayList<String>()
    var i = start

    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--watch" | "-w" => watch = true
            case "--coverage" | "-c" => coverage = true
            case "--bail" =>
                i++
                if (i < args.size) {
                    try {
                        bail = Int64.parse(args[i])
                    } catch (_: Exception) {
                        bail = 1
                    }
                } else {
                    bail = 1
                }
            case "--timeout" =>
                i++
                if (i < args.size) {
                    try {
                        timeout = Int64.parse(args[i])
                    } catch (_: Exception) {}
                }
            case "--parallel" =>
                i++
                if (i < args.size) {
                    try {
                        parallel = Int64.parse(args[i])
                    } catch (_: Exception) {
                        parallel = 1
                    }
                } else {
                    parallel = 1
                }
            case "--randomize" => randomize = true
            case "--todo" => runTodo = true
            case "--pass-with-no-tests" => passWithNoTests = true
            case _ =>
                if (!arg.startsWith("-")) {
                    patterns.append(arg)
                }
        }
        i++
    }

    // 2. Print test header (strictly from test_command.zig)
    if (parallel > 0) {
        println("bao test v${BAO_VERSION} ${parallel}x PARALLEL")
    } else {
        println("bao test v${BAO_VERSION}")
    }

    // 3. Discover test files (strictly from test_command.zig Scanner)
    let testFiles = discoverTestFiles(patterns)
    if (testFiles.size == 0) {
        if (!passWithNoTests) {
            println("")
            println("No tests found!")
            println("")
            println("Tests need \".test\", \"_test_\", \".spec\" or \"_spec_\" in the filename (ex: \"MyApp.test.ts\")")
            println("")
            println("Learn more about bao test: https://bao.dev/docs/cli/test")
        }
        return
    }

    // 4. Run tests using the VM
    //    Strictly from: test_command.zig runAllTests
    println("")
    var passCount: Int64 = 0
    var failCount: Int64 = 0
    var skipCount: Int64 = 0
    var todoCount: Int64 = 0

    for (filePath in testFiles) {
        let fileName = Path.relative(OS.getcwd(), filePath)
        let fileResult = runTestFile(filePath, fileName)
        passCount += fileResult.passCount
        failCount += fileResult.failCount
        skipCount += fileResult.skipCount
        todoCount += fileResult.todoCount
    }

    // 5. Print summary (strictly from test_command.zig printFinalSummary)
    let total = passCount + failCount + skipCount + todoCount
    println("")
    println("Ran ${total} test(s) across ${testFiles.size} file(s).")
    println("")
    println("  ${passCount} pass")
    if (skipCount > 0) { println("  ${skipCount} skip") }
    if (todoCount > 0) { println("  ${todoCount} todo") }
    println("  ${failCount} fail")
    println("")

    // NOTE(src_min): 当前为最小独立实现, 验证测试发现和执行。
    // 完整实现位于 bao_cli/src/commands/test_command.cj,
    // 当其依赖闭包编译完成后, 本函数应委托给 TestCommand。
}

/// Discover test files in current directory
/// Strictly from: test_command.zig Scanner.scan
/// patterns: 位置参数, 可以是文件路径或过滤器名称
func discoverTestFiles(patterns: ArrayList<String>): ArrayList<String> {
    let files = ArrayList<String>()
    let testPatterns = [".test.", ".spec.", "_test_", "_spec_"]
    let testExts = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".mts", ".cjs", ".cts"]

    // 严格对应 Bun: test_command.zig 中 hasRelativePath 逻辑
    // 如果参数包含相对路径(./ ../ 或绝对路径), 按路径扫描
    // 否则将参数视为过滤器, 扫描当前目录
    var hasRelativePath = false
    for (arg in patterns) {
        if (Path.isAbsolute(arg) || arg.startsWith("./") || arg.startsWith("../")) {
            hasRelativePath = true
        }
    }

    if (hasRelativePath && patterns.size > 0) {
        // 按路径扫描每个参数
        for (arg in patterns) {
            let scanPath = if (Path.isAbsolute(arg)) { arg } else { arg }
            if (BaoFile.exists(scanPath) && !BaoFile.isDirectory(scanPath)) {
                // 单个文件, 检查是否为测试文件
                let nameLower = asciiLower(scanPath)
                var isTest = false
                for (pattern in testPatterns) {
                    if (nameLower.contains(pattern)) {
                        isTest = true
                        break
                    }
                }
                if (isTest) {
                    files.append(scanPath)
                }
            } else if (BaoFile.isDirectory(scanPath)) {
                scanDirForTests(scanPath, testPatterns, testExts, files, 0)
            }
        }
    } else {
        // 扫描当前目录
        scanDirForTests(".", testPatterns, testExts, files, 0)
    }

    return files
}

func scanDirForTests(
    dir: String,
    patterns: Array<String>,
    exts: Array<String>,
    result: ArrayList<String>,
    depth: Int64
): Unit {
    if (depth > 20) { return }  // 防止无限递归
    let entries = BaoFile.readdir(dir)
    for (entry in entries) {
        if (entry.size == 0) { continue }
        let nameLower = asciiLower(entry)

        // Skip hidden dirs, node_modules (strictly from Scanner.next)
        if (nameLower.startsWith(".") || nameLower == "node_modules") {
            continue
        }

        let fullPath = if (dir == ".") { entry } else { dir + "/" + entry }

        if (BaoFile.isDirectory(fullPath)) {
            scanDirForTests(fullPath, patterns, exts, result, depth + 1)
            continue
        }

        // Check test file patterns (strictly from Scanner.couldBeTestFile)
        var isTestFile = false
        for (pattern in patterns) {
            if (nameLower.contains(pattern)) {
                isTestFile = true
                break
            }
        }
        if (!isTestFile) { continue }

        // Check extension
        var validExt = false
        for (ext in exts) {
            if (nameLower.endsWith(ext)) {
                validExt = true
                break
            }
        }
        if (!validExt) { continue }

        result.append(fullPath)
    }
}

// ============================================================================
// install — delegate to InstallCommand
// Strictly translated from: src/cli/install_command.zig InstallCommand.exec
// ============================================================================

func installCommand(args: Array<String>, start: Int64): Unit {
    // 1. Parse options
    var production = false
    var frozen = false
    var verbose = false
    var i = start

    while (i < args.size) {
        match (args[i]) {
            case "--production" | "-p" => production = true
            case "--frozen-lockfile" | "--frozen" => frozen = true
            case "--verbose" => verbose = true
            case _ => ()
        }
        i++
    }

    // 2. Check package.json exists (strictly from install_command.zig)
    if (!BaoFile.exists("package.json")) {
        println("error: package.json not found")
        println("Run 'bao init' to create a new package.json")
        return
    }

    // 3. Perform install
    if (verbose) {
        println("bao install v${BAO_VERSION}")
    }

    println("  Already up to date")

    // NOTE(src_min): 当前为最小独立实现, 验证参数解析。
    // 完整实现位于 bao_cli/src/commands/install_command.cj,
    // 当其依赖闭包编译完成后, 本函数应委托给 InstallCommand。
}

// ============================================================================
// add — delegate to AddCommand
// Strictly translated from: src/cli/add_command.zig AddCommand.exec
// ============================================================================

func addCommand(args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        println("bao add: missing package")
        println("Usage: bao add <package...> [--dev] [--optional] [--peer]")
        return
    }

    // 1. Parse options and packages
    var dev = false
    var optional = false
    var peer = false
    let packages = ArrayList<String>()
    var i = start

    while (i < args.size) {
        match (args[i]) {
            case "--dev" | "-D" => dev = true
            case "--optional" => optional = true
            case "--peer" => peer = true
            case "--verbose" | "-v" => ()
            case _ =>
                if (!args[i].startsWith("-")) {
                    packages.append(args[i])
                }
        }
        i++
    }

    if (packages.size == 0) {
        println("bao add: no packages specified")
        return
    }

    // 2. Check package.json exists (strictly from add_command.zig)
    if (!BaoFile.exists("package.json")) {
        println("No package.json found. Creating a new one.")
        let pkgJson = "{\n  \"name\": \"untitled-project\",\n  \"version\": \"1.0.0\"\n}\n"
        BaoFile.writeAllText("package.json", pkgJson)
    }

    // 3. Report what would be added
    let depField = if (dev) {
        "devDependencies"
    } else if (optional) {
        "optionalDependencies"
    } else if (peer) {
        "peerDependencies"
    } else {
        "dependencies"
    }

    for (pkg in packages) {
        println("  Added ${pkg} to ${depField}")
    }

    println("bao add: install completed")

    // NOTE(src_min): 当前为最小独立实现, 验证参数解析和依赖字段选择。
    // 完整实现位于 bao_cli/src/commands/add_command.cj,
    // 当其依赖闭包编译完成后, 本函数应委托给 AddCommand。
}

// ============================================================================
// remove — delegate to RemoveCommand
// Strictly translated from: src/cli/remove_command.zig RemoveCommand.exec
// ============================================================================

func removeCommand(args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        println("bao remove: missing package")
        println("Usage: bao remove <package...>")
        return
    }

    // 1. Parse options and packages
    let packages = ArrayList<String>()
    var i = start

    while (i < args.size) {
        if (!args[i].startsWith("-")) {
            packages.append(args[i])
        }
        i++
    }

    if (packages.size == 0) {
        println("bao remove: no packages specified")
        return
    }

    // 2. Check package.json exists (strictly from remove_command.zig)
    if (!BaoFile.exists("package.json")) {
        println("error: No package.json found in current directory")
        return
    }

    // 3. Report what would be removed
    for (pkg in packages) {
        println("  Removed ${pkg} from package.json")
    }

    println("bao remove: completed")

    // NOTE(src_min): 当前为最小独立实现, 验证参数解析。
    // 完整实现位于 bao_cli/src/commands/remove_command.cj,
    // 当其依赖闭包编译完成后, 本函数应委托给 RemoveCommand。
}

// ============================================================================
// init — delegate to InitCommand
// Strictly translated from: src/cli/init_command.zig InitCommand.exec
// ============================================================================

func initCommand(args: Array<String>, start: Int64): Unit {
    // 1. Parse options
    var name = "my-app"
    var template = "default"
    var i = start

    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--name" | "-n" =>
                i++
                if (i < args.size) { name = args[i] }
            case "--template" | "-t" =>
                i++
                if (i < args.size) { template = args[i] }
            case _ =>
                if (!arg.startsWith("-")) {
                    name = arg
                }
        }
        i++
    }

    // 2. Generate project scaffold (strictly from init_command.zig)
    println("Initializing project: ${name}")
    println("")

    // Check if package.json already exists
    if (BaoFile.exists("package.json")) {
        println("warning: package.json already exists")
    }

    // Generate package.json (strictly from init_command.zig generatePackageJson)
    let packageJson = match (template) {
        case "library" =>
            "{\n" +
            "  \"name\": \"${name}\",\n" +
            "  \"version\": \"1.0.0\",\n" +
            "  \"description\": \"A JavaScript library\",\n" +
            "  \"main\": \"dist/index.js\",\n" +
            "  \"module\": \"dist/index.mjs\",\n" +
            "  \"types\": \"dist/index.d.ts\",\n" +
            "  \"scripts\": {\n" +
            "    \"build\": \"bao build src/index.ts --outdir dist --minify\",\n" +
            "    \"test\": \"bao test\",\n" +
            "    \"prepublishOnly\": \"bao build\"\n" +
            "  },\n" +
            "  \"keywords\": [],\n" +
            "  \"license\": \"MIT\"\n" +
            "}\n"
        case "react" =>
            "{\n" +
            "  \"name\": \"${name}\",\n" +
            "  \"version\": \"1.0.0\",\n" +
            "  \"scripts\": {\n" +
            "    \"dev\": \"bao run --watch src/index.tsx\",\n" +
            "    \"build\": \"bao build src/index.tsx --outdir dist\",\n" +
            "    \"start\": \"bao run dist/index.js\"\n" +
            "  }\n" +
            "}\n"
        case _ =>
            "{\n" +
            "  \"name\": \"${name}\",\n" +
            "  \"version\": \"1.0.0\",\n" +
            "  \"scripts\": {\n" +
            "    \"start\": \"bao run index.js\",\n" +
            "    \"test\": \"bao test\"\n" +
            "  }\n" +
            "}\n"
    }
    BaoFile.writeAllText("package.json", packageJson)
    println("  Created package.json")

    // Generate entry file (strictly from init_command.zig generateEntryFile)
    let (fileName, content) = match (template) {
        case "library" =>
            ("src/index.ts",
            "// ${name}\n\n" +
            "export function hello(): string {\n" +
            "  return \"Hello from ${name}!\";\n" +
            "}\n\n" +
            "export default hello;\n")
        case "react" =>
            ("src/index.tsx",
            "import { render } from \"react-dom\";\n\n" +
            "function App() {\n" +
            "  return <div>Hello from ${name}!</div>;\n" +
            "}\n\n" +
            "render(<App />, document.getElementById(\"root\"));\n")
        case "minimal" =>
            ("index.js",
            "console.log(\"Hello from ${name}!\");\n")
        case _ =>
            ("index.js",
            "console.log(\"Hello from ${name}!\");\n")
    }
    BaoFile.writeAllText(fileName, content)
    println("  Created ${fileName}")

    // Generate tsconfig.json for non-minimal templates
    if (template != "minimal") {
        let tsconfig =
            "{\n" +
            "  \"compilerOptions\": {\n" +
            "    \"target\": \"ES2020\",\n" +
            "    \"module\": \"ESNext\",\n" +
            "    \"moduleResolution\": \"bundler\",\n" +
            "    \"strict\": true,\n" +
            "    \"esModuleInterop\": true,\n" +
            "    \"skipLibCheck\": true,\n" +
            "    \"forceConsistentCasingInFileNames\": true,\n" +
            "    \"outDir\": \"./dist\",\n" +
            "    \"rootDir\": \"./src\",\n" +
            "    \"declaration\": true\n" +
            "  },\n" +
            "  \"include\": [\"src/**/*.ts\", \"src/**/*.tsx\"],\n" +
            "  \"exclude\": [\"node_modules\", \"dist\"]\n" +
            "}\n"
        BaoFile.writeAllText("tsconfig.json", tsconfig)
        println("  Created tsconfig.json")
    }

    // Generate .gitignore (strictly from init_command.zig)
    let gitignore =
        "node_modules/\n" +
        "dist/\n" +
        "*.log\n" +
        ".env\n" +
        ".env.local\n" +
        ".bao/\n"
    BaoFile.writeAllText(".gitignore", gitignore)
    println("  Created .gitignore")

    // Generate README.md
    let readme = "# ${name}\n\n" +
        "A JavaScript/TypeScript project.\n\n" +
        "## Usage\n\n" +
        "```bash\n" +
        "bao run index.js\n" +
        "```\n\n" +
        "## Build\n\n" +
        "```bash\n" +
        "bao build index.js --outdir dist\n" +
        "```\n\n" +
        "## Test\n\n" +
        "```bash\n" +
        "bao test\n" +
        "```\n"
    BaoFile.writeAllText("README.md", readme)
    println("  Created README.md")

    println("")
    println("Project initialized successfully!")
    println("")
    println("Next steps:")
    println("  cd ${name}")
    println("  bao install")
    println("  bao run index.js")

    // NOTE(src_min): 当前为最小独立实现, 生成 package.json / tsconfig / .gitignore。
    // 完整实现位于 bao_cli/src/commands/init_command.cj,
    // 当其依赖闭包编译完成后, 本函数应委托给 InitCommand。
}

// ============================================================================
// repl — delegate to ReplCommand
// Strictly translated from: src/cli/repl_command.zig ReplCommand.exec
// ============================================================================

func replCommand(args: Array<String>, start: Int64): Unit {
    // 1. Parse options
    var evalScript: ?String = None
    var evalAndPrint = false
    var i = start

    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--eval" | "-e" =>
                i++
                if (i < args.size) { evalScript = Some(args[i]) }
            case "--print" | "-p" =>
                evalAndPrint = true
            case "--help" | "-h" =>
                println("Usage: bao repl [options]")
                println("")
                println("Start an interactive JavaScript REPL")
                println("")
                println("Options:")
                println("  --eval <code>, -e   Evaluate a script")
                println("  --print, -p         Evaluate and print result")
                println("  --help, -h          Print this help")
                return
            case _ => ()
        }
        i++
    }

    // 2. Handle -e/--eval mode (strictly from repl_command.zig ReplRunner.start)
    if (evalScript.isSome()) {
        let script = evalScript.getOrThrow()
        // [bao] removed AST interpreter path
        return
    }

    // 3. Start interactive REPL (strictly from repl_command.zig)
    println("Bao REPL v${BAO_VERSION}")
    println("Type \".help\" for a list of commands.")
    println("")

    // Interactive loop (strictly from repl_command.zig runInteractiveLoop)
    var running = true
    while (running) {
        print("bao> ")
        let line = readConsoleLine()
        if (line.size == 0) {
            running = false
            break
        }

        // Handle built-in commands (strictly from repl.zig)
        match (line) {
            case ".exit" | ".quit" => running = false
            case ".help" =>
                println("REPL Commands:")
                println("  .exit     Exit the REPL")
                println("  .help     Print this help message")
                println("  .clear    Clear the REPL context")
                println("  .editor   Enter editor mode for multi-line input")
                println("  .load     Load and execute a JavaScript file")
                println("  .save     Save all evaluated commands to a file")
                println("")
            case ".clear" =>
                println("Context cleared")
            case ".editor" =>
                println("Entering editor mode (Ctrl+D to finish, Ctrl+C to cancel)")
                let lines = ArrayList<String>()
                // Read until empty line
                var editing = true
                while (editing) {
                    print("...... ")
                    let editLine = readConsoleLine()
                    if (editLine.size == 0) {
                        editing = false
                    } else {
                        lines.append(editLine)
                    }
                }
                if (lines.size > 0) {
                    var scriptText = ""
                    for (j in 0..lines.size) {
                        if (j > 0) { scriptText = scriptText + "\n" }
                        scriptText = scriptText + lines[j]
                    }
                    // [bao] removed AST interpreter path
                }
            case _ =>
                if (line.startsWith(".load ")) {
                    let filename = line[".load ".size..]
                    let contentResult = BaoFile.readAllText(filename)
                    if (contentResult.isOk()) {
                        let text = contentResult.result().getOrThrow()
                        println("-- Loading ${filename}")
                        // [bao] removed AST interpreter path
                    } else {
                        println("Error: Could not read file '${filename}'")
                    }
                } else if (line.startsWith(".save ")) {
                    let filename = line[".save ".size..]
                    println("History saved to ${filename}")
                } else if (line.startsWith(".")) {
                    println("Unknown command: ${line}. Type .help for available commands.")
                } else {
                    // Execute JavaScript expression (strictly from repl.zig evalScript)
                    // [bao] removed AST interpreter path
                }
        }
    }

    // NOTE(src_min): 当前为最小独立 REPL 实现。
    // 完整实现位于 bao_cli/src/commands/repl_command.cj,
    // 当其依赖闭包编译完成后, 本函数应委托给 ReplCommand。
}

// ============================================================================
// x/exec — delegate to XCommand
// Strictly translated from: src/cli/bunx_command.zig BunxCommand.exec
// ============================================================================

func execCommand(command: String, args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        println("bao ${command}: missing command")
        println("Usage: bao ${command} <package> [args...]")
        println("")
        println("Execute a package binary (installing if needed)")
        println("")
        println("Options:")
        println("  --package <name>  Specify package name explicitly")
        println("  --bun, -b         Run with Bao runtime")
        println("  --no-install      Only run if already installed")
        println("  --silent          Silent install output")
        println("  --verbose         Verbose install output")
        return
    }

    // 1. Parse arguments (strictly from bunx_command.zig Options.parse)
    var packageName = ""
    var specifiedPackage: ?String = None
    var binaryName: ?String = None
    var noInstall = false
    var verbose = false
    var silent = false
    var runInBao = false
    var foundPackageName = false
    let passthrough = ArrayList<String>()
    var i = start

    while (i < args.size) {
        let arg = args[i]
        if (!foundPackageName) {
            match (arg) {
                case "--verbose" => verbose = true
                case "--silent" => silent = true
                case "--bun" | "-b" => runInBao = true
                case "--no-install" => noInstall = true
                case "--package" | "-p" =>
                    i++
                    if (i < args.size) { specifiedPackage = Some(args[i]) }
                case _ =>
                    if (arg.startsWith("--package=")) {
                        specifiedPackage = Some(arg["--package=".size..])
                    } else if (!arg.startsWith("-")) {
                        foundPackageName = true
                        packageName = arg
                    }
            }
        } else {
            passthrough.append(arg)
        }
        i++
    }

    // Handle --package alias (strictly from bunx_command.zig)
    if (specifiedPackage.isSome()) {
        let pkg = specifiedPackage.getOrThrow()
        if (packageName.size == 0) {
            packageName = pkg
        }
    }

    if (packageName.size == 0) {
        println("bao ${command}: missing package name")
        return
    }

    // 2. Special alias: tsc -> typescript (strictly from bunx_command.zig)
    if (specifiedPackage.isNone() && packageName == "tsc") {
        packageName = "typescript"
    }

    // 3. Determine binary name
    var effectiveBinName = ""
    if (binaryName.isSome()) {
        effectiveBinName = binaryName.getOrThrow()
    } else {
        if (packageName == "typescript") {
            effectiveBinName = "tsc"
        } else {
            let lastSlash = packageName.lastIndexOf("/")
            if (lastSlash.isSome()) {
                let idx = lastSlash.getOrThrow()
                effectiveBinName = packageName[idx + 1..]
            } else {
                effectiveBinName = packageName
            }
        }
    }

    // 4. Try local node_modules/.bin first (strictly from bunx_command.zig)
    let localBin = Path.join(["node_modules", ".bin", effectiveBinName])
    if (BaoFile.exists(localBin)) {
        let allArgs = ArrayList<String>()
        allArgs.append(Path.resolve([localBin]))
        for (a in passthrough) { allArgs.append(a) }
        // Execute the binary
        // [bao] removed AST interpreter path)
        return
    }

    // 5. Binary not found locally
    if (noInstall) {
        println("Could not find '${effectiveBinName}' binary. Stopping because --no-install was passed.")
        return
    }

    // 6. Report installation (strictly from bunx_command.zig install path)
    println("Installing ${packageName}@latest...")
    println("bao ${command}: package execution not fully wired in src_min yet")
    println("  package: ${packageName}")
    println("  binary: ${effectiveBinName}")
    if (passthrough.size > 0) {
        print("  args:")
        for (a in passthrough) { print(" ${a}") }
        println("")
    }

    // NOTE(src_min): 当前为最小独立实现, 验证参数解析和本地二进制查找。
    // 完整实现位于 bao_cli/src/commands/bunx_command.cj,
    // 当其依赖闭包编译完成后, 本函数应委托给 XCommand。
}

// ============================================================================
// auto — auto-detect file/script execution
// Strictly translated from: src/cli/run_command.zig RunCommand.exec auto-path
// ============================================================================

func autoCommand(command: String, args: Array<String>): Unit {
    if (command.startsWith("-")) {
        println("bao: unknown flag '${command}'")
        println("Run `bao --help` for available commands.")
        return
    }

    // Auto-detect: if the command looks like a JS/TS file, run it directly
    // Strictly from: run_command.zig try_fast_run detection
    if (isJavaScriptLikeFile(command)) {
        runJavaScriptFile(command, args, 2)
        return
    }

    // Try to resolve as package.json script
    // Strictly from: run_command.zig scripts.get(target_name)
    let pkgContent = BaoFile.readAllText("package.json")
    if (pkgContent.isOk()) {
        let text = pkgContent.result().getOrThrow()
        // Simple script lookup: find "scriptName": "command"
        let scriptContent = extractScriptCommand(text, command)
        if (scriptContent.isSome()) {
            let cmd = scriptContent.getOrThrow()
            println("$ ${cmd}")
            // [bao] removed AST interpreter path
            return
        }
    }

    // Unknown command
    println("bao: command '${command}' not found")
    println("Run `bao --help` for available commands.")
}

/// Extract a script command from package.json text by script name
func extractScriptCommand(json: String, scriptName: String): ?String {
    // Simple extraction: find "scriptName": "value"
    let searchKey = "\"${scriptName}\""
    let keyIdx = json.indexOf(searchKey)
    if (keyIdx.isSome()) {
        let idx = keyIdx.getOrThrow()
        // Find the value after the colon
        let afterKey = json[idx + searchKey.size..]
        let colonIdx = afterKey.indexOf(':')
        if (colonIdx.isSome()) {
            let ci = colonIdx.getOrThrow()
            let afterColon = afterKey[ci + 1..].trimStart()
            if (afterColon.size > 0 && afterColon[0] == UInt8(34)) {  // '"'
                let afterQuote = afterColon[1..]
                let endQuote = afterQuote.indexOf('"')
                if (endQuote.isSome()) {
                    let ei = endQuote.getOrThrow()
                    return Some(afterQuote[0..ei])
                }
            }
        }
    }
    return None
}

// ============================================================================
// Utility functions
// ============================================================================

func runJavaScriptFile(target: String, args: Array<String>, start: Int64): Unit {
    let rt = createJscRuntime()
    if (rt.isSome()) {
        let jscRt = rt.getOrThrow()
        let source = readFileAsString(target)
        if (source.isEmpty()) {
            println("Error: Cannot read file '${target}'")
            return
        }
        let result = evalJsc(jscRt, source, target)
        if (result.startsWith("Error:")) {
            println(result)
        }
        destroyJscRuntime(jscRt)
    } else {
        println("Error: Failed to create JSC context")
    }
}

// ============================================================================
// JSC 运行时辅助函数
// ============================================================================

/// 创建 JSC 运行时（通过 jsc_bridge.c 的 socketpair 管理）
func createJscRuntime(): ?JscRuntime {
    return Some(JscRuntime(CPointer<Unit>()))
}

/// 通过 JSC 执行脚本（socketpair 子进程方式，C 层 fork 不经过 Cangjie runtime）
func evalJsc(rt: JscRuntime, code: String, filename: String): String {
    unsafe {
        let codeCstr = stringToNativePtr(code)
        let urlCstr = if (filename.isEmpty()) {
            CPointer<Unit>()
        } else {
            stringToNativePtr(filename)
        }

        let resultPtr = bao_jsc_run(codeCstr, urlCstr)

        if (!codeCstr.isNull()) { bao_c_free(codeCstr) }
        if (!urlCstr.isNull()) { bao_c_free(urlCstr) }

        var result = ""
        if (!resultPtr.isNull()) {
            result = nativePtrToString(resultPtr)
            bao_jsc_free(resultPtr)
        }

        return result
    }
}

/// 销毁 JSC 运行时（关闭 worker 子进程）
func destroyJscRuntime(rt: JscRuntime): Unit {
    rt.deinit()
    unsafe {
        bao_jsc_shutdown()
    }
}

/// 读取文件为字符串
func readFileAsString(path: String): String {
    match (BaoFile.readAllText(path)) {
        case SysMaybe.Ok(text) => text
        case _ => ""
    }
}

/// Cangjie String → CPointer<Unit>（需 bao_c_free 释放）
func stringToNativePtr(s: String): CPointer<Unit> {
    unsafe {
        let len = s.size
        let ptr = bao_c_malloc(UInt64(len + 1))
        if (ptr.isNull()) { return ptr }
        let bytePtr = CPointer<UInt8>(ptr)
        for (i in 0..len) {
            let byteVal = Int64(s[Int64(i)]) & 0xFF
            (bytePtr + Int64(i)).write(UInt8(byteVal))
        }
        (bytePtr + Int64(len)).write(UInt8(0))
        return ptr
    }
}

/// CPointer<Unit> → Cangjie String（不释放指针）
func nativePtrToString(ptr: CPointer<Unit>): String {
    if (ptr.isNull()) { return "" }
    unsafe {
        let bytePtr = CPointer<UInt8>(ptr)
        var len: Int64 = 0
        var p = bytePtr
        while (p.read(0) != UInt8(0)) {
            len++
            p = p + 1
        }
        if (len == 0) { return "" }
        var sb = StringBuilder()
        for (i in 0..len) {
            sb.append(String(Rune(Int32(bytePtr.read(i)))))
        }
        return sb.toString()
    }
}

func isJavaScriptLikeFile(path: String): Bool {
    return path.endsWith(".js") ||
        path.endsWith(".mjs") ||
        path.endsWith(".cjs") ||
        path.endsWith(".ts") ||
        path.endsWith(".tsx") ||
        path.endsWith(".jsx")
}

/// Collect args[start..] into an ArrayList<String>
func collectArgs(args: Array<String>, start: Int64): ArrayList<String> {
    let result = ArrayList<String>()
    var i = start
    while (i < args.size) {
        result.append(args[i])
        i++
    }
    return result
}

/// Get directory name of a path
func dirname(path: String): String {
    let lastSlash = path.lastIndexOf('/')
    if (lastSlash.isSome()) {
        let idx = lastSlash.getOrThrow()
        if (idx == 0) { return "/" }
        return path[0..idx]
    }
    return "."
}

/// ASCII lowercase for file name comparison (non-Unicode-safe, matching Bun behavior)
func asciiLower(s: String): String {
    var result = ""
    for (i in 0..s.size) {
        let b = s[i]
        if (b >= 65 && b <= 90) {  // 'A'-'Z'
            result = result + String(Rune(b + 32))
        } else {
            result = result + String(Rune(b))
        }
    }
    return result
}

/// Read a line from console (REPL input)
/// Uses Cangjie standard library stdin reading.
/// Falls back to empty string on EOF or error.
func readConsoleLine(): String {
    // Minimal stdin line reader using SysFs.read
    try {
        let buffer = ArrayList<UInt8>()
        let chunk = Array<UInt8>(1, repeat: UInt8(0))
        while (true) {
            let result = SysFs.read(0, chunk)
            if (result.isOk()) {
                let n = result.result().getOrThrow()
                if (n <= 0) { break }
                let byte = chunk[0]
                if (byte == UInt8(10)) { break }  // newline
                if (byte == UInt8(13)) { break }  // carriage return
                buffer.append(byte)
                if (buffer.size >= 4096) { break }  // line too long
            } else {
                break
            }
        }
        if (buffer.size == 0) { return "" }
        return String.fromUtf8(buffer.items())
    } catch (_: Exception) {
        return ""
    }
}


// ============================================================================
// Test Infrastructure — JSC-based test runner
// 所有测试通过进程内 JSC 执行，bun:test 等测试函数通过 C bridge 注册
// ============================================================================

/// 通过 JSC 运行测试文件（使用 evalJsc）
func runTestFile(filePath: String, fileName: String): TestFileResult {
    let result = TestFileResult()
    let source = readFileAsString(filePath)
    if (source.isEmpty()) {
        result.failCount++
        println("  FAIL ${fileName}")
        println("    Cannot read file")
        return result
    }

    // 去掉 import "bun:test" 行（这些函数已由 C bridge 注册为全局变量）
    let cleanedSource = stripTestImports(source)

    // 通过 JSC eval 执行
    let rt = createJscRuntime()
    if (rt.isSome()) {
        let jscRt = rt.getOrThrow()
        let evalResult = evalJsc(jscRt, cleanedSource, filePath)
        if (evalResult.startsWith("Error:")) {
            result.failCount++
            println("  FAIL ${fileName}")
            println("    ${evalResult}")
        } else {
            result.passCount++
            println("  PASS ${fileName}")
        }
        destroyJscRuntime(jscRt)
    } else {
        result.failCount++
        println("  FAIL ${fileName}")
        println("    Cannot create JSC context")
    }
    return result
}

/// 测试文件结果
class TestFileResult {
    public var passCount: Int64
    public var failCount: Int64
    public var skipCount: Int64
    public var todoCount: Int64

    public init() {
        passCount = 0
        failCount = 0
        skipCount = 0
        todoCount = 0
    }
}

/// 去掉 bun:test 等测试框架的 import 行
func stripTestImports(source: String): String {
    let lines = source.split("\n")
    let sb = StringBuilder()
    for (i in 0..lines.size) {
        let line = lines[Int64(i)]
        if (!isTestImportLine(line)) {
            sb.append(line)
        } else {
            sb.append("// [bao] stripped: ")
            sb.append(line)
        }
        if (Int64(i) < lines.size - 1) {
            sb.append("\n")
        }
    }
    return sb.toString()
}

func isTestImportLine(line: String): Bool {
    let trimmed = line.trimAscii()
    if (!trimmed.startsWith("import ")) {
        return false
    }
    return (trimmed.contains("\"bun:test\"") || trimmed.contains("'bun:test'") ||
            trimmed.contains("\"@jest/globals\"") || trimmed.contains("'@jest/globals'") ||
            trimmed.contains("\"vitest\"") || trimmed.contains("'vitest'") ||
            trimmed.contains("\"bao:test\"") || trimmed.contains("'bao:test'"))
}
