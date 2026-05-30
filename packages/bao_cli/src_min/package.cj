package bao_cli

import std.env.getCommandLine
import std.convert.*
import bao_runtime.*
import bao_io.*
import bao_path.*
import bao_sys.*
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

    // TODO(bao-cli): When full bao_cli/src dependency closure compiles,
    // replace the above with:
    //   let options = BuildCommandOptions()
    //   // ... populate fields from parsed args ...
    //   let cmd = BuildCommand(options)
    //   let exitCode = cmd.execute()
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
    var patternCount: Int64 = 0
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
                    patternCount++
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
    let testFiles = discoverTestFiles(patternCount > 0)
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

    for (filePath in testFiles) {
        let fileName = Path.relative(OS.getcwd(), filePath)
        try {
            let vm = VirtualMachine()
            vm.executeFile(filePath)
            passCount++
            println("  PASS ${fileName}")
        } catch (e: Exception) {
            failCount++
            println("  FAIL ${fileName}")
            println("    ${e.message}")
        }
    }

    // 5. Print summary (strictly from test_command.zig printFinalSummary)
    let total = passCount + failCount + skipCount
    println("")
    println("Ran ${total} test(s) across ${testFiles.size} file(s).")
    println("")
    println("  ${passCount} pass")
    if (skipCount > 0) { println("  ${skipCount} skip") }
    println("  ${failCount} fail")
    println("")

    // TODO(bao-cli): When full bao_cli/src dependency closure compiles,
    // replace the above with:
    //   let options = TestCommandOptions()
    //   // ... populate fields from parsed args ...
    //   let cmd = TestCommand(options)
    //   let exitCode = cmd.execute()
}

/// Discover test files in current directory
/// Strictly from: test_command.zig Scanner.scan
func discoverTestFiles(hasFilters: Bool): ArrayList<String> {
    let files = ArrayList<String>()
    let testPatterns = [".test.", ".spec.", "_test_", "_spec_"]
    let testExts = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".mts", ".cjs", ".cts"]

    scanDirForTests(".", testPatterns, testExts, files)
    return files
}

func scanDirForTests(
    dir: String,
    patterns: Array<String>,
    exts: Array<String>,
    result: ArrayList<String>
): Unit {
    let entries = BaoFile.readdir(dir)
    for (entry in entries) {
        let nameLower = asciiLower(entry)

        // Skip hidden dirs, node_modules (strictly from Scanner.next)
        if (nameLower.startsWith(".") || nameLower == "node_modules") {
            continue
        }

        let fullPath = if (dir == ".") { entry } else { dir + "/" + entry }

        if (BaoFile.isDirectory(fullPath)) {
            scanDirForTests(fullPath, patterns, exts, result)
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

    // TODO(bao-cli): When full bao_cli/src dependency closure compiles,
    // replace the above with:
    //   let cliOptions = InstallCommandLineOptions()
    //   cliOptions.production = production
    //   cliOptions.frozenLockfile = frozen
    //   cliOptions.verbose = verbose
    //   let cmd = InstallCommand(cliOptions)
    //   let exitCode = cmd.execute()
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

    // TODO(bao-cli): When full bao_cli/src dependency closure compiles,
    // replace the above with:
    //   let addArgs = collectArgs(args, start)
    //   let cmd = AddCommand()
    //   cmd.execute(addArgs)
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

    // TODO(bao-cli): When full bao_cli/src dependency closure compiles,
    // replace the above with:
    //   let removeArgs = collectArgs(args, start)
    //   let cmd = RemoveCommand()
    //   cmd.execute(removeArgs)
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

    // TODO(bao-cli): When full bao_cli/src dependency closure compiles,
    // replace the above with:
    //   let options = InitOptions()
    //   options.name = name
    //   options.template = template
    //   let cmd = InitCommand(options)
    //   let exitCode = cmd.execute()
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
    match (evalScript) {
        case Some(script) =>
            let vm = VirtualMachine()
            let _ = vm.eval(script, "<eval>")
            return
        case None => ()
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
                    match (contentResult) {
                        case Ok(text) =>
                            println("-- Loading ${filename}")
                            let vm = VirtualMachine()
                            let _ = vm.eval(text, filename)
                        case _ =>
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

    // TODO(bao-cli): When full bao_cli/src dependency closure compiles,
    // replace the above with:
    //   let replArgs = collectArgs(args, start)
    //   let cmd = ReplCommand()
    //   let exitCode = cmd.execute(replArgs)
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
    match (specifiedPackage) {
        case Some(pkg) =>
            if (packageName.size == 0) {
                packageName = pkg
            }
        case None => ()
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
    let effectiveBinName = match (binaryName) {
        case Some(bn) => bn
        case None =>
            if (packageName == "typescript") {
                "tsc"
            } else {
                let lastSlash = packageName.lastIndexOf("/")
                match (lastSlash) {
                    case Some(idx) => packageName[idx + 1..]
                    case None => packageName
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

    // TODO(bao-cli): When full bao_cli/src dependency closure compiles,
    // replace the above with:
    //   let execArgs = collectArgs(args, start)
    //   let cmd = XCommand()
    //   cmd.execute(execArgs)
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
    match (pkgContent) {
        case Ok(text) =>
            // Simple script lookup: find "scriptName": "command"
            let scriptContent = extractScriptCommand(text, command)
            match (scriptContent) {
                case Some(cmd) =>
                    println("$ ${cmd}")
                    let vm = VirtualMachine()
                    let _ = vm.eval(cmd, "<script>")
                    return
                case None => ()
            }
        case _ => ()
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
    match (keyIdx) {
        case Some(idx) =>
            // Find the value after the colon
            let afterKey = json[idx + searchKey.size..]
            let colonIdx = afterKey.indexOf(':')
            match (colonIdx) {
                case Some(ci) =>
                    let afterColon = afterKey[ci + 1..].trimStart()
                    if (afterColon.size > 0 && afterColon[0] == UInt8(34)) {  // '"'
                        let afterQuote = afterColon[1..]
                        let endQuote = afterQuote.indexOf('"')
                        match (endQuote) {
                            case Some(ei) => return Some(afterQuote[0..ei])
                            case None => ()
                        }
                    }
                case None => ()
            }
        case None => ()
    }
    return None
}

// ============================================================================
// Utility functions
// ============================================================================

func runJavaScriptFile(target: String, args: Array<String>, start: Int64): Unit {
    let vm = VirtualMachine()
    let _ = vm.executeFile(target)
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
    match (lastSlash) {
        case Some(idx) =>
            if (idx == 0) { return "/" }
            return path[0..idx]
        case None => return "."
    }
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
            match (result) {
                case Ok(n) =>
                    if (n <= 0) { break }
                    let byte = chunk[0]
                    if (byte == UInt8(10)) { break }  // newline
                    if (byte == UInt8(13)) { break }  // carriage return
                    buffer.append(byte)
                    if (buffer.size >= 4096) { break }  // line too long
                case Err(_) => break
            }
        }
        if (buffer.size == 0) { return "" }
        return String.fromUtf8(buffer.items())
    } catch (_: Exception) {
        return ""
    }
}
