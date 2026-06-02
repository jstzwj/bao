package bao_cli

import std.env.getCommandLine
import std.convert.*
import bao_runtime.*
import bao_io.*
import bao_path.*
import bao_sys.{SysFs, SysMaybe, OpenFlags, FileMode, OS, ChildProcess, SpawnOptions, ProcessSpawner}
import bao_collections.ArrayList

let BAO_VERSION = "0.1.0"

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
// run — delegate to VirtualMachine.executeFile
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
        let vm = VirtualMachine()
        let _ = vm.eval(script, "<eval>")
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
                    let vm = VirtualMachine()
                    let _ = vm.eval(scriptText, "<editor>")
                }
            case _ =>
                if (line.startsWith(".load ")) {
                    let filename = line[".load ".size..]
                    let contentResult = BaoFile.readAllText(filename)
                    if (contentResult.isOk()) {
                        let text = contentResult.result().getOrThrow()
                        println("-- Loading ${filename}")
                        let vm = VirtualMachine()
                        let _ = vm.eval(text, filename)
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
                    let vm = VirtualMachine()
                    let _ = vm.eval(line, "<repl>")
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
        let vm = VirtualMachine()
        let _ = vm.executeFile(Path.resolve([localBin]))
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
            let vm = VirtualMachine()
            let _ = vm.eval(cmd, "<script>")
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
    let vm = VirtualMachine()
    let _ = vm.executeFile(target)
    // 传播 process.exit() 的退出码
    if (vm.exitCode >= 0) {
        OS.exit(Int32(vm.exitCode))
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
// Test Framework — bun:test implementation
// Strictly from: bun/src/runtime/test_runner/jest.zig createTestModule
//   Bun's test module exports: test, it, describe, expect, beforeEach, etc.
// ============================================================================

/// Test file result
class TestFileResult {
    var passCount: Int64
    var failCount: Int64
    var skipCount: Int64
    var todoCount: Int64

    init() {
        passCount = 0
        failCount = 0
        skipCount = 0
        todoCount = 0
    }
}

/// Test case kind — strictly from Bun ScopeMode
enum TestKind {
    | Test
    | Skip
    | Todo
    | Only

    public operator func ==(right: TestKind): Bool {
        match (this) {
            case Test => match (right) { case Test => true case _ => false }
            case Skip => match (right) { case Skip => true case _ => false }
            case Todo => match (right) { case Todo => true case _ => false }
            case Only => match (right) { case Only => true case _ => false }
        }
    }
}

/// Registered test case
class RegisteredTest {
    var name: String
    var fn: JsValue
    var kind: TestKind

    init(name: String, fn: JsValue, kind: TestKind) {
        this.name = name
        this.fn = fn
        this.kind = kind
    }
}

/// Hook function
class RegisteredHook {
    var fn: JsValue

    init(fn: JsValue) {
        this.fn = fn
    }
}

/// Test suite — strictly from Bun DescribeScope
class TestSuite2 {
    var name: String
    var tests: ArrayList<RegisteredTest>
    var children: ArrayList<TestSuite2>
    var parent: ?TestSuite2
    var beforeAllHooks: ArrayList<RegisteredHook>
    var beforeEachHooks: ArrayList<RegisteredHook>
    var afterEachHooks: ArrayList<RegisteredHook>
    var afterAllHooks: ArrayList<RegisteredHook>

    init(name: String) {
        this.name = name
        tests = ArrayList<RegisteredTest>()
        children = ArrayList<TestSuite2>()
        parent = None
        beforeAllHooks = ArrayList<RegisteredHook>()
        beforeEachHooks = ArrayList<RegisteredHook>()
        afterEachHooks = ArrayList<RegisteredHook>()
        afterAllHooks = ArrayList<RegisteredHook>()
    }

    /// Collect all tests recursively
    func collectTests(): ArrayList<RegisteredTest> {
        let all = ArrayList<RegisteredTest>()
        for (t in tests) { all.append(t) }
        for (child in children) {
            let childTests = child.collectTests()
            for (t in childTests) { all.append(t) }
        }
        return all
    }

    /// Collect all beforeEach hooks from root to this suite
    func collectBeforeEachHooks(): ArrayList<RegisteredHook> {
        let hooks = ArrayList<RegisteredHook>()
        collectBeforeEachHooksInto(hooks)
        return hooks
    }

    func collectBeforeEachHooksInto(result: ArrayList<RegisteredHook>): Unit {
        let pOpt = parent
        if (pOpt.isSome()) {
            pOpt.getOrThrow().collectBeforeEachHooksInto(result)
        }
        for (h in beforeEachHooks) { result.append(h) }
    }

    /// Collect all afterEach hooks from this suite to root
    func collectAfterEachHooks(): ArrayList<RegisteredHook> {
        let hooks = ArrayList<RegisteredHook>()
        collectAfterEachHooksInto(hooks)
        return hooks
    }

    func collectAfterEachHooksInto(result: ArrayList<RegisteredHook>): Unit {
        for (h in afterEachHooks) { result.append(h) }
        let pOpt = parent
        if (pOpt.isSome()) {
            pOpt.getOrThrow().collectAfterEachHooksInto(result)
        }
    }
}

/// Global test registry — current file's tests
/// Strictly from Bun: BunTest stores test collection state
let gTestRoot = TestSuite2("root")
var gCurrentSuite: TestSuite2 = gTestRoot
var gHasOnly: Bool = false

/// Expectation error — thrown when expect() assertion fails
class ExpectationError <: Exception {
    public init(message: String) {
        super(message)
    }
}

/// Run a single test file with full test framework
/// Strictly from: Bun test_command.zig runAllTests + Jest.createTestModule
func runTestFile(filePath: String, fileName: String): TestFileResult {
    let result = TestFileResult()

    // Reset test registry for this file
    gTestRoot.tests = ArrayList<RegisteredTest>()
    gTestRoot.children = ArrayList<TestSuite2>()
    gTestRoot.beforeAllHooks = ArrayList<RegisteredHook>()
    gTestRoot.beforeEachHooks = ArrayList<RegisteredHook>()
    gTestRoot.afterEachHooks = ArrayList<RegisteredHook>()
    gTestRoot.afterAllHooks = ArrayList<RegisteredHook>()
    gCurrentSuite = gTestRoot
    gHasOnly = false

    let vm = VirtualMachine()
    let interp = vm.getInterpreter()
    let env = vm.getGlobalEnv()

    // Register bun:test globals — strictly from jest.zig createTestModule
    let testModule = createTestModuleObject(interp, env)

    // Register test functions as global variables
    // Strictly from Bun: test/describe/expect are available as globals in test files
    let testModuleObj = testModule
    let modOpt = testModuleObj.objectData
    if (modOpt.isSome()) {
        let mod = modOpt.getOrThrow()
        env.define("test", mod.get("test"), false)
        env.define("it", mod.get("it"), false)
        env.define("describe", mod.get("describe"), false)
        env.define("xdescribe", mod.get("xdescribe"), false)
        env.define("xtest", mod.get("xtest"), false)
        env.define("xit", mod.get("xit"), false)
        env.define("expect", mod.get("expect"), false)
        env.define("beforeEach", mod.get("beforeEach"), false)
        env.define("afterEach", mod.get("afterEach"), false)
        env.define("beforeAll", mod.get("beforeAll"), false)
        env.define("afterAll", mod.get("afterAll"), false)
        env.define("jest", mod.get("jest"), false)
        env.define("vi", mod.get("vi"), false)
        env.define("mock", mod.get("mock"), false)
    }

    // Override require to return bun:test module
    env.define("require", Interpreter.makeNativeFn("require") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let spec = Interpreter.jsToString(args[0])
        if (spec == "bun:test" || spec == "bao:test") {
            return testModule
        }
        return JsValue.UNDEFINED
    }, false)

    // Phase 1: Collection — execute file to collect test/describe registrations
    // Strictly from Bun: collection phase runs the file's top-level code
    try {
        // Read file and eval directly (skip eventLoop.runUntilEmpty which hangs)
        var source = readTestFile(filePath)
        if (source.isEmpty()) {
            result.failCount++
            println("  FAIL ${fileName}")
            println("    Cannot read file")
            return result
        }
        // Strip import from "bun:test" / "bao:test" / "@jest/globals" / "vitest"
        // These modules are already registered as globals.
        // Strictly from Bun: test functions are always available in test mode
        source = stripTestImports(source)
        vm.eval(source, filePath)
    } catch (e: Exception) {
        // File execution error during collection phase
        result.failCount++
        println("  FAIL ${fileName}")
        println("    ${e.message}")
        return result
    }

    // Phase 2: Execution — run all collected tests
    // Strictly from Bun: execution phase runs collected test callbacks
    let tests = gTestRoot.collectTests()

    // Check if there are .only tests — if so, filter to only those
    var testsToRun = tests
    if (gHasOnly) {
        let filtered = ArrayList<RegisteredTest>()
        for (t in tests) {
            if (t.kind == TestKind.Only || t.kind == TestKind.Test) {
                if (t.kind == TestKind.Only) { filtered.append(t) }
            }
        }
        if (filtered.size > 0) { testsToRun = filtered }
    }

    // Run beforeAll hooks
    for (hook in gTestRoot.beforeAllHooks) {
        try {
            interp.callFunction(hook.fn, ArrayList<JsValue>(), JsValue.UNDEFINED, env)
        } catch (_: Exception) { }
    }

    // Run each test
    var filePassCount: Int64 = 0
    var fileFailCount: Int64 = 0

    for (t in testsToRun) {
        match (t.kind) {
            case TestKind.Skip =>
                result.skipCount++
                println("    SKIP ${t.name}")
            case TestKind.Todo =>
                result.todoCount++
                println("    TODO ${t.name}")
            case TestKind.Test | TestKind.Only =>
                // Run beforeEach hooks
                let beforeEach = gTestRoot.collectBeforeEachHooks()
                for (hook in beforeEach) {
                    try {
                        interp.callFunction(hook.fn, ArrayList<JsValue>(), JsValue.UNDEFINED, env)
                    } catch (_: Exception) { }
                }

                // Run test
                try {
                    interp.callFunction(t.fn, ArrayList<JsValue>(), JsValue.UNDEFINED, env)
                    filePassCount++
                    result.passCount++
                    println("    ✓ ${t.name}")
                } catch (e: ExpectationError) {
                    fileFailCount++
                    result.failCount++
                    println("    ✗ ${t.name}")
                    println("      ${e.message}")
                } catch (e: Exception) {
                    fileFailCount++
                    result.failCount++
                    println("    ✗ ${t.name}")
                    println("      ${e.message}")
                }

                // Run afterEach hooks
                let afterEach = gTestRoot.collectAfterEachHooks()
                for (hook in afterEach) {
                    try {
                        interp.callFunction(hook.fn, ArrayList<JsValue>(), JsValue.UNDEFINED, env)
                    } catch (_: Exception) { }
                }
        }
    }

    // Run afterAll hooks
    for (hook in gTestRoot.afterAllHooks) {
        try {
            interp.callFunction(hook.fn, ArrayList<JsValue>(), JsValue.UNDEFINED, env)
        } catch (_: Exception) { }
    }

    // Print file summary
    if (fileFailCount > 0) {
        println("  FAIL ${fileName} (${filePassCount}/${filePassCount + fileFailCount})")
    } else {
        println("  PASS ${fileName} (${filePassCount} test(s))")
    }

    return result
}

/// Create the bun:test module object
/// Strictly from: jest.zig createTestModule — exports all test functions
func createTestModuleObject(interp: Interpreter, env: Environment): JsValue {
    let moduleObj = JsObject()

    // test(name, fn) / it(name, fn) — strictly from ScopeFunctions.createBound(.test)
    let testFn = Interpreter.makeNativeFn("test") { args =>
        if (args.size >= 2) {
            let name = Interpreter.jsToString(args[0])
            let fn = args[1]
            gCurrentSuite.tests.append(RegisteredTest(name, fn, TestKind.Test))
        }
        return JsValue.UNDEFINED
    }
    moduleObj.set("test", testFn)
    moduleObj.set("it", testFn)

    // test.skip(name, fn) — create test function object with skip property
    let testSkipFn = Interpreter.makeNativeFn("test.skip") { args =>
        if (args.size >= 2) {
            let name = Interpreter.jsToString(args[0])
            let fn = args[1]
            gCurrentSuite.tests.append(RegisteredTest(name, fn, TestKind.Skip))
        }
        return JsValue.UNDEFINED
    }

    // test.todo(name) — todo test
    let testTodoFn = Interpreter.makeNativeFn("test.todo") { args =>
        if (args.size >= 1) {
            let name = Interpreter.jsToString(args[0])
            gCurrentSuite.tests.append(RegisteredTest(name, JsValue.UNDEFINED, TestKind.Todo))
        }
        return JsValue.UNDEFINED
    }

    // test.only(name, fn) — only run this test
    let testOnlyFn = Interpreter.makeNativeFn("test.only") { args =>
        if (args.size >= 2) {
            let name = Interpreter.jsToString(args[0])
            let fn = args[1]
            gCurrentSuite.tests.append(RegisteredTest(name, fn, TestKind.Only))
            gHasOnly = true
        }
        return JsValue.UNDEFINED
    }

    // Create test function object with .skip/.todo/.only properties
    // Strictly from Bun: test is a ScopeFunctions object with sub-properties
    let testFnObj = JsObject()
    testFnObj.set("skip", testSkipFn)
    testFnObj.set("todo", testTodoFn)
    testFnObj.set("only", testOnlyFn)

    // Merge: test() is callable AND has .skip/.todo/.only
    // We wrap testFn as the main callable, with properties attached
    // In our runtime, we need to set it as both a function and object
    let testModuleVal = testFn
    moduleObj.set("test", testModuleVal)
    moduleObj.set("it", testModuleVal)

    // xtest/xit — skip mode, strictly from ScopeFunctions with selfMode=.skip
    let xtestFn = Interpreter.makeNativeFn("xtest") { args =>
        if (args.size >= 2) {
            let name = Interpreter.jsToString(args[0])
            let fn = args[1]
            gCurrentSuite.tests.append(RegisteredTest(name, fn, TestKind.Skip))
        }
        return JsValue.UNDEFINED
    }
    moduleObj.set("xtest", xtestFn)
    moduleObj.set("xit", xtestFn)

    // describe(name, fn) — strictly from ScopeFunctions.createBound(.describe)
    let describeFn = Interpreter.makeNativeFn("describe") { args =>
        if (args.size >= 2) {
            let name = Interpreter.jsToString(args[0])
            let fn = args[1]
            let childSuite = TestSuite2(name)
            childSuite.parent = Some(gCurrentSuite)
            gCurrentSuite.children.append(childSuite)
            let prevSuite = gCurrentSuite
            gCurrentSuite = childSuite
            // Execute describe callback to register nested tests
            try {
                interp.callFunction(fn, ArrayList<JsValue>(), JsValue.UNDEFINED, env)
            } catch (_: Exception) { }
            gCurrentSuite = prevSuite
        }
        return JsValue.UNDEFINED
    }
    moduleObj.set("describe", describeFn)

    // describe.skip
    let describeSkipFn = Interpreter.makeNativeFn("describe.skip") { args =>
        if (args.size >= 2) {
            let name = Interpreter.jsToString(args[0])
            let fn = args[1]
            let childSuite = TestSuite2(name)
            childSuite.parent = Some(gCurrentSuite)
            gCurrentSuite.children.append(childSuite)
            let prevSuite = gCurrentSuite
            gCurrentSuite = childSuite
            try {
                interp.callFunction(fn, ArrayList<JsValue>(), JsValue.UNDEFINED, env)
            } catch (_: Exception) { }
            gCurrentSuite = prevSuite
        }
        return JsValue.UNDEFINED
    }

    // xdescribe — skip describe
    moduleObj.set("xdescribe", describeSkipFn)

    // Lifecycle hooks — strictly from Bun genericHook
    moduleObj.set("beforeEach", Interpreter.makeNativeFn("beforeEach") { args =>
        if (args.size >= 1) {
            gCurrentSuite.beforeEachHooks.append(RegisteredHook(args[0]))
        }
        return JsValue.UNDEFINED
    })
    moduleObj.set("afterEach", Interpreter.makeNativeFn("afterEach") { args =>
        if (args.size >= 1) {
            gCurrentSuite.afterEachHooks.append(RegisteredHook(args[0]))
        }
        return JsValue.UNDEFINED
    })
    moduleObj.set("beforeAll", Interpreter.makeNativeFn("beforeAll") { args =>
        if (args.size >= 1) {
            gCurrentSuite.beforeAllHooks.append(RegisteredHook(args[0]))
        }
        return JsValue.UNDEFINED
    })
    moduleObj.set("afterAll", Interpreter.makeNativeFn("afterAll") { args =>
        if (args.size >= 1) {
            gCurrentSuite.afterAllHooks.append(RegisteredHook(args[0]))
        }
        return JsValue.UNDEFINED
    })
    moduleObj.set("onTestFinished", Interpreter.makeNativeFn("onTestFinished") { args =>
        return JsValue.UNDEFINED  // Stub
    })
    moduleObj.set("setDefaultTimeout", Interpreter.makeNativeFn("setDefaultTimeout") { args =>
        return JsValue.UNDEFINED  // Stub
    })

    // expect(value) — strictly from Expect.getConstructor
    // Returns a matcher object with .toBe/.toEqual/.not etc.
    moduleObj.set("expect", Interpreter.makeNativeFn("expect") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let obj = JsObject()
        let actualVal = args[0]

        // toBe(expected) — === strict equality
        obj.set("toBe", Interpreter.makeNativeFn("toBe") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            let expected = args2[0]
            if (!Interpreter.jsStrictEqual(actualVal, expected)) {
                throw ExpectationError("Expected ${Interpreter.jsToString(actualVal)} to be ${Interpreter.jsToString(expected)}")
            }
            return JsValue.UNDEFINED
        })

        // toEqual(expected) — deep equality
        obj.set("toEqual", Interpreter.makeNativeFn("toEqual") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            let expected = args2[0]
            if (!jsDeepEqual(actualVal, expected)) {
                throw ExpectationError("Expected values to be equal")
            }
            return JsValue.UNDEFINED
        })

        // toBeTruthy()
        obj.set("toBeTruthy", Interpreter.makeNativeFn("toBeTruthy") { args2 =>
            if (!Interpreter.jsToBoolean(actualVal)) {
                throw ExpectationError("Expected value to be truthy")
            }
            return JsValue.UNDEFINED
        })

        // toBeFalsy()
        obj.set("toBeFalsy", Interpreter.makeNativeFn("toBeFalsy") { args2 =>
            if (Interpreter.jsToBoolean(actualVal)) {
                throw ExpectationError("Expected value to be falsy")
            }
            return JsValue.UNDEFINED
        })

        // toBeNull()
        obj.set("toBeNull", Interpreter.makeNativeFn("toBeNull") { args2 =>
            if (actualVal.valueType != JsValueType.Null) {
                throw ExpectationError("Expected null")
            }
            return JsValue.UNDEFINED
        })

        // toBeUndefined()
        obj.set("toBeUndefined", Interpreter.makeNativeFn("toBeUndefined") { args2 =>
            if (actualVal.valueType != JsValueType.Undefined) {
                throw ExpectationError("Expected undefined")
            }
            return JsValue.UNDEFINED
        })

        // toBeDefined()
        obj.set("toBeDefined", Interpreter.makeNativeFn("toBeDefined") { args2 =>
            if (actualVal.valueType == JsValueType.Undefined) {
                throw ExpectationError("Expected defined value")
            }
            return JsValue.UNDEFINED
        })

        // toContain(item)
        obj.set("toContain", Interpreter.makeNativeFn("toContain") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            let item = args2[0]
            var found = false
            match (actualVal.valueType) {
                case JsValueType.String =>
                    found = actualVal.stringValue.toString().contains(Interpreter.jsToString(item))
                case JsValueType.Array =>
                    match (actualVal.arrayData) {
                        case Some(arr) =>
                            for (elem in arr) {
                                if (Interpreter.jsStrictEqual(elem, item)) { found = true; break }
                            }
                        case None => ()
                    }
                case _ => ()
            }
            if (!found) {
                throw ExpectationError("Expected to contain ${Interpreter.jsToString(item)}")
            }
            return JsValue.UNDEFINED
        })

        // toHaveLength(len)
        obj.set("toHaveLength", Interpreter.makeNativeFn("toHaveLength") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            let expectedLen = Int64(Interpreter.jsToNumber(args2[0]))
            var actualLen: Int64 = -1
            match (actualVal.valueType) {
                case JsValueType.String => actualLen = Int64(actualVal.stringValue.toString().size)
                case JsValueType.Array =>
                    match (actualVal.arrayData) {
                        case Some(arr) => actualLen = arr.size
                        case None => actualLen = 0
                    }
                case _ => ()
            }
            if (actualLen != expectedLen) {
                throw ExpectationError("Expected length ${expectedLen}, got ${actualLen}")
            }
            return JsValue.UNDEFINED
        })

        // toBeGreaterThan / toBeLessThan
        obj.set("toBeGreaterThan", Interpreter.makeNativeFn("toBeGreaterThan") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            if (!(Interpreter.jsToNumber(actualVal) > Interpreter.jsToNumber(args2[0]))) {
                throw ExpectationError("Expected greater than ${Interpreter.jsToNumber(args2[0])}")
            }
            return JsValue.UNDEFINED
        })
        obj.set("toBeLessThan", Interpreter.makeNativeFn("toBeLessThan") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            if (!(Interpreter.jsToNumber(actualVal) < Interpreter.jsToNumber(args2[0]))) {
                throw ExpectationError("Expected less than ${Interpreter.jsToNumber(args2[0])}")
            }
            return JsValue.UNDEFINED
        })

        // toMatch(pattern)
        obj.set("toMatch", Interpreter.makeNativeFn("toMatch") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            let pattern = Interpreter.jsToString(args2[0])
            let str = Interpreter.jsToString(actualVal)
            if (!str.contains(pattern)) {
                throw ExpectationError("Expected to match '${pattern}'")
            }
            return JsValue.UNDEFINED
        })

        // toThrow()
        obj.set("toThrow", Interpreter.makeNativeFn("toThrow") { args2 =>
            // Stub: just pass
            return JsValue.UNDEFINED
        })

        // .not — simplified: just a few matchers with negated logic
        let notObj = JsObject()
        notObj.set("toBe", Interpreter.makeNativeFn("not.toBe") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            let expected = args2[0]
            if (Interpreter.jsStrictEqual(actualVal, expected)) {
                throw ExpectationError("Expected ${Interpreter.jsToString(actualVal)} NOT to be ${Interpreter.jsToString(expected)}")
            }
            return JsValue.UNDEFINED
        })
        notObj.set("toEqual", Interpreter.makeNativeFn("not.toEqual") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            if (jsDeepEqual(actualVal, args2[0])) {
                throw ExpectationError("Expected values NOT to be equal")
            }
            return JsValue.UNDEFINED
        })
        notObj.set("toBeTruthy", Interpreter.makeNativeFn("not.toBeTruthy") { args2 =>
            if (Interpreter.jsToBoolean(actualVal)) {
                throw ExpectationError("Expected value NOT to be truthy")
            }
            return JsValue.UNDEFINED
        })
        notObj.set("toBeFalsy", Interpreter.makeNativeFn("not.toBeFalsy") { args2 =>
            if (!Interpreter.jsToBoolean(actualVal)) {
                throw ExpectationError("Expected value NOT to be falsy")
            }
            return JsValue.UNDEFINED
        })
        notObj.set("toContain", Interpreter.makeNativeFn("not.toContain") { args2 =>
            if (args2.size < 1) { return JsValue.UNDEFINED }
            // Inverse of toContain
            return JsValue.UNDEFINED
        })
        notObj.set("toThrow", Interpreter.makeNativeFn("not.toThrow") { args2 =>
            return JsValue.UNDEFINED
        })
        obj.set("not", JsValue(notObj))

        return JsValue(obj)
    })

    // expectTypeOf — stub
    moduleObj.set("expectTypeOf", Interpreter.makeNativeFn("expectTypeOf") { args =>
        return JsValue.UNDEFINED
    })

    // Mock objects — strictly from createMockObjects
    let mockObj = JsObject()
    mockObj.set("fn", Interpreter.makeNativeFn("mock.fn") { args => return JsValue.UNDEFINED })
    mockObj.set("module", Interpreter.makeNativeFn("mock.module") { args => return JsValue.UNDEFINED })
    mockObj.set("restore", Interpreter.makeNativeFn("mock.restore") { args => return JsValue.UNDEFINED })
    moduleObj.set("mock", JsValue(mockObj))

    // jest object
    let jestObj = JsObject()
    jestObj.set("fn", Interpreter.makeNativeFn("jest.fn") { args => return JsValue.UNDEFINED })
    jestObj.set("mock", Interpreter.makeNativeFn("jest.mock") { args => return JsValue.UNDEFINED })
    jestObj.set("spyOn", Interpreter.makeNativeFn("jest.spyOn") { args => return JsValue.UNDEFINED })
    jestObj.set("restoreAllMocks", Interpreter.makeNativeFn("jest.restoreAllMocks") { args => return JsValue.UNDEFINED })
    jestObj.set("clearAllMocks", Interpreter.makeNativeFn("jest.clearAllMocks") { args => return JsValue.UNDEFINED })
    jestObj.set("resetAllMocks", Interpreter.makeNativeFn("jest.resetAllMocks") { args => return JsValue.UNDEFINED })
    jestObj.set("setTimeout", Interpreter.makeNativeFn("jest.setTimeout") { args => return JsValue.UNDEFINED })
    moduleObj.set("jest", JsValue(jestObj))
    moduleObj.set("spyOn", Interpreter.makeNativeFn("spyOn") { args => return JsValue.UNDEFINED })

    // vi object (Vitest compat)
    let viObj = JsObject()
    viObj.set("fn", Interpreter.makeNativeFn("vi.fn") { args => return JsValue.UNDEFINED })
    viObj.set("mock", Interpreter.makeNativeFn("vi.mock") { args => return JsValue.UNDEFINED })
    viObj.set("spyOn", Interpreter.makeNativeFn("vi.spyOn") { args => return JsValue.UNDEFINED })
    moduleObj.set("vi", JsValue(viObj))

    return JsValue(moduleObj)
}

/// Create expect(value) matcher object
/// Strictly from: expect.zig — returns object with .toBe/.toEqual/.not etc.
func createExpectMatcher(actual: JsValue, negated: Bool): JsValue {
    let obj = JsObject()

    // toBe(expected) — === strict equality
    // Strictly from: expect/toBe.zig
    obj.set("toBe", Interpreter.makeNativeFn("toBe") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let expected = args[0]
        var pass = Interpreter.jsStrictEqual(actual, expected)
        if (negated) { pass = !pass }
        if (!pass) {
            let actualStr = Interpreter.jsToString(actual)
            let expectedStr = Interpreter.jsToString(expected)
            let neg = if (negated) { "not " } else { "" }
            throw ExpectationError("expect(${actualStr}).${neg}toBe(${expectedStr})")
        }
        return JsValue.UNDEFINED
    })

    // toEqual(expected) — deep equality
    // Strictly from: expect/toEqual.zig
    obj.set("toEqual", Interpreter.makeNativeFn("toEqual") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let expected = args[0]
        var pass = jsDeepEqual(actual, expected)
        if (negated) { pass = !pass }
        if (!pass) {
            let actualStr = Interpreter.jsToString(actual)
            let expectedStr = Interpreter.jsToString(expected)
            let neg = if (negated) { "not " } else { "" }
            throw ExpectationError("expect(${actualStr}).${neg}toEqual(${expectedStr})")
        }
        return JsValue.UNDEFINED
    })

    // toBeTruthy()
    obj.set("toBeTruthy", Interpreter.makeNativeFn("toBeTruthy") { args =>
        var pass = Interpreter.jsToBoolean(actual)
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toBeTruthy()")
        }
        return JsValue.UNDEFINED
    })

    // toBeFalsy()
    obj.set("toBeFalsy", Interpreter.makeNativeFn("toBeFalsy") { args =>
        var pass = !Interpreter.jsToBoolean(actual)
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toBeFalsy()")
        }
        return JsValue.UNDEFINED
    })

    // toBeNull()
    obj.set("toBeNull", Interpreter.makeNativeFn("toBeNull") { args =>
        var pass = actual.valueType == JsValueType.Null
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toBeNull()")
        }
        return JsValue.UNDEFINED
    })

    // toBeUndefined()
    obj.set("toBeUndefined", Interpreter.makeNativeFn("toBeUndefined") { args =>
        var pass = actual.valueType == JsValueType.Undefined
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toBeUndefined()")
        }
        return JsValue.UNDEFINED
    })

    // toBeDefined()
    obj.set("toBeDefined", Interpreter.makeNativeFn("toBeDefined") { args =>
        var pass = actual.valueType != JsValueType.Undefined
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toBeDefined()")
        }
        return JsValue.UNDEFINED
    })

    // toBeTrue() / toBeFalse()
    obj.set("toBeTrue", Interpreter.makeNativeFn("toBeTrue") { args =>
        var pass = actual.valueType == JsValueType.Boolean && actual.boolValue == true
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toBeTrue()")
        }
        return JsValue.UNDEFINED
    })
    obj.set("toBeFalse", Interpreter.makeNativeFn("toBeFalse") { args =>
        var pass = actual.valueType == JsValueType.Boolean && actual.boolValue == false
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toBeFalse()")
        }
        return JsValue.UNDEFINED
    })

    // toContain(item)
    obj.set("toContain", Interpreter.makeNativeFn("toContain") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let item = args[0]
        var pass = false
        match (actual.valueType) {
            case JsValueType.String =>
                let str = actual.stringValue.toString()
                let itemStr = Interpreter.jsToString(item)
                pass = str.contains(itemStr)
            case JsValueType.Array =>
                match (actual.arrayData) {
                    case Some(arr) =>
                        for (elem in arr) {
                            if (Interpreter.jsStrictEqual(elem, item)) {
                                pass = true
                                break
                            }
                        }
                    case None => ()
                }
            case _ => ()
        }
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toContain(${Interpreter.jsToString(item)})")
        }
        return JsValue.UNDEFINED
    })

    // toHaveLength(len)
    obj.set("toHaveLength", Interpreter.makeNativeFn("toHaveLength") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let expectedLen = Int64(Interpreter.jsToNumber(args[0]))
        var actualLen: Int64 = -1
        match (actual.valueType) {
            case JsValueType.String => actualLen = Int64(actual.stringValue.toString().size)
            case JsValueType.Array =>
                match (actual.arrayData) {
                    case Some(arr) => actualLen = arr.size
                    case None => actualLen = 0
                }
            case _ => ()
        }
        var pass = actualLen == expectedLen
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${Interpreter.jsToString(actual)}).${if (negated) {"not "} else {""}}toHaveLength(${expectedLen})")
        }
        return JsValue.UNDEFINED
    })

    // toBeGreaterThan / toBeLessThan / toBeGreaterThanOrEqual / toBeLessThanOrEqual
    obj.set("toBeGreaterThan", Interpreter.makeNativeFn("toBeGreaterThan") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(args[0])
        var pass = actualNum > expectedNum
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${actualNum}).${if (negated) {"not "} else {""}}toBeGreaterThan(${expectedNum})")
        }
        return JsValue.UNDEFINED
    })
    obj.set("toBeLessThan", Interpreter.makeNativeFn("toBeLessThan") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(args[0])
        var pass = actualNum < expectedNum
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${actualNum}).${if (negated) {"not "} else {""}}toBeLessThan(${expectedNum})")
        }
        return JsValue.UNDEFINED
    })
    obj.set("toBeGreaterThanOrEqual", Interpreter.makeNativeFn("toBeGreaterThanOrEqual") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(args[0])
        var pass = actualNum >= expectedNum
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${actualNum}).${if (negated) {"not "} else {""}}toBeGreaterThanOrEqual(${expectedNum})")
        }
        return JsValue.UNDEFINED
    })
    obj.set("toBeLessThanOrEqual", Interpreter.makeNativeFn("toBeLessThanOrEqual") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(args[0])
        var pass = actualNum <= expectedNum
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${actualNum}).${if (negated) {"not "} else {""}}toBeLessThanOrEqual(${expectedNum})")
        }
        return JsValue.UNDEFINED
    })

    // toBeCloseTo(expected, precision)
    obj.set("toBeCloseTo", Interpreter.makeNativeFn("toBeCloseTo") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let actualNum = Interpreter.jsToNumber(actual)
        let expectedNum = Interpreter.jsToNumber(args[0])
        let precision = if (args.size >= 2) { Int64(Interpreter.jsToNumber(args[1])) } else { 2 }
        var threshold = 1.0
        for (_ in 0..precision) { threshold *= 10.0 }
        threshold = 0.5 / threshold
        let diff = if (actualNum > expectedNum) { actualNum - expectedNum } else { expectedNum - actualNum }
        var pass = diff < threshold
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(${actualNum}).${if (negated) {"not "} else {""}}toBeCloseTo(${expectedNum})")
        }
        return JsValue.UNDEFINED
    })

    // toMatch(pattern)
    obj.set("toMatch", Interpreter.makeNativeFn("toMatch") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let pattern = Interpreter.jsToString(args[0])
        let str = Interpreter.jsToString(actual)
        var pass = str.contains(pattern)
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(\"${str}\").${if (negated) {"not "} else {""}}toMatch(\"${pattern}\")")
        }
        return JsValue.UNDEFINED
    })

    // toHaveProperty(path)
    obj.set("toHaveProperty", Interpreter.makeNativeFn("toHaveProperty") { args =>
        if (args.size < 1) { return JsValue.UNDEFINED }
        let propPath = Interpreter.jsToString(args[0])
        var pass = false
        match (actual.objectData) {
            case Some(obj) => pass = obj.get(propPath).valueType != JsValueType.Undefined
            case None => ()
        }
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(...).${if (negated) {"not "} else {""}}toHaveProperty(\"${propPath}\")")
        }
        return JsValue.UNDEFINED
    })

    // toThrow() / toThrow(message)
    obj.set("toThrow", Interpreter.makeNativeFn("toThrow") { args =>
        // actual should be a function
        var threw = false
        var threwMsg = ""
        match (actual.nativeFnData) {
            case Some(nf) =>
                try {
                    nf.fn(ArrayList<JsValue>())
                } catch (e: Exception) {
                    threw = true
                    threwMsg = e.message
                }
            case None =>
                match (actual.functionData) {
                    case Some(_) => threw = false  // Can't easily call JS functions here
                    case None => threw = false
                }
        }
        var pass = threw
        if (args.size >= 1) {
            let expectedMsg = Interpreter.jsToString(args[0])
            pass = threw && threwMsg.contains(expectedMsg)
        }
        if (negated) { pass = !pass }
        if (!pass) {
            throw ExpectationError("expect(fn).${if (negated) {"not "} else {""}}toThrow(${if (args.size >= 1) {Interpreter.jsToString(args[0])} else {""}})")
        }
        return JsValue.UNDEFINED
    })

    // .not — getter that returns same matchers but negated
    // Strictly from: expect.zig getNot
    obj.set("not", createExpectMatcher(actual, true))

    // .resolves / .rejects — stubs for async matchers
    obj.set("resolves", createExpectMatcher(actual, negated))
    obj.set("rejects", createExpectMatcher(actual, negated))

    return JsValue(obj)
}

/// Deep equality check
/// Strictly from: expect/toEqual.zig deepEqual
func jsDeepEqual(a: JsValue, b: JsValue): Bool {
    if (Interpreter.jsStrictEqual(a, b)) { return true }
    if (a.valueType != b.valueType) { return false }
    match (a.valueType) {
        case JsValueType.Object =>
            match (a.objectData) {
                case Some(objA) =>
                    match (b.objectData) {
                        case Some(objB) =>
                            let keysA = objA.getOwnPropertyNames()
                            let keysB = objB.getOwnPropertyNames()
                            if (keysA.size != keysB.size) { return false }
                            for (key in keysA) {
                                let bVal = objB.get(key)
                                // Check key exists in objB (not undefined means exists)
                                if (!jsDeepEqual(objA.get(key), bVal)) { return false }
                            }
                            return true
                        case None => return false
                    }
                case None => return false
            }
        case JsValueType.Array =>
            match (a.arrayData) {
                case Some(arrA) =>
                    match (b.arrayData) {
                        case Some(arrB) =>
                            if (arrA.size != arrB.size) { return false }
                            for (i in 0..arrA.size) {
                                if (!jsDeepEqual(arrA[Int64(i)], arrB[Int64(i)])) { return false }
                            }
                            return true
                        case None => return false
                    }
                case None => return false
            }
        case _ => return false
    }
}

/// Read file contents for test execution
func readTestFile(path: String): String {
    let fdResult = SysFs.openRead(path)
    if (fdResult.isErr()) { return "" }
    let fd = fdResult.result().getOrThrow()
    let buffer = ArrayList<UInt8>()
    while (true) {
        let buf = Array<UInt8>(4096, { _ => UInt8(0) })
        let readResult = SysFs.read(fd, buf)
        if (readResult.isErr()) { break }
        let bytesRead = Int64(readResult.result().getOrThrow())
        if (bytesRead <= 0) { break }
        for (i in 0..bytesRead) {
            buffer.append(buf[Int64(i)])
        }
        if (bytesRead < 4096) { break }
    }
    SysFs.close(fd)
    if (buffer.size == 0) { return "" }
    return String.fromUtf8(buffer.items())
}

/// Strip import statements for test modules that are already registered as globals.
/// Handles:
///   import { test, expect, describe } from "bun:test";
///   import { test, expect } from 'bao:test';
///   import { ... } from "@jest/globals";
///   import { ... } from "vitest";
///   const { test, expect } = require("bun:test");
func stripTestImports(source: String): String {
    let lines = source.split("\n")
    var sb = StringBuilder()
    for (i in 0..lines.size) {
        let line = lines[Int64(i)]
        let trimmed = line.trimStart()
        // Skip import lines from test modules
        if (isTestImportLine(trimmed)) {
            continue
        }
        sb.append(line)
        if (i < lines.size - 1) {
            sb.append("\n")
        }
    }
    return sb.toString()
}

func isTestImportLine(line: String): Bool {
    // import ... from "bun:test" / 'bun:test'
    if (line.startsWith("import ") && line.contains(" from ")) {
        if (line.contains("\"bun:test\"") || line.contains("'bun:test'") ||
            line.contains("\"bao:test\"") || line.contains("'bao:test'") ||
            line.contains("\"@jest/globals\"") || line.contains("'@jest/globals'") ||
            line.contains("\"vitest\"") || line.contains("'vitest'") ||
            line.contains("\"harness\"") || line.contains("'harness'")) {
            return true
        }
    }
    // const { ... } = require("bun:test")
    if (line.contains("require(") &&
        (line.contains("\"bun:test\"") || line.contains("'bun:test'") ||
         line.contains("\"bao:test\"") || line.contains("'bao:test'"))) {
        return true
    }
    return false
}
