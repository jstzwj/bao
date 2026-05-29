package bao_cli

import std.env.getCommandLine
import bao_runtime.*

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

func runCommand(args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        println("bao run: missing script or file")
        println("Usage: bao run <file|script> [...args]")
        return
    }

    let target = args[start]
    runJavaScriptFile(target, args, start + 1)
}

func buildCommand(args: Array<String>, start: Int64): Unit {
    var outdir = "dist"
    var minify = false
    var sourcemap = false
    var entryCount: Int64 = 0
    var i = start

    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--outdir" =>
                i++
                if (i < args.size) { outdir = args[i] }
            case "--minify" | "-m" => minify = true
            case "--sourcemap" => sourcemap = true
            case _ =>
                if (!arg.startsWith("-")) {
                    entryCount++
                }
        }
        i++
    }

    if (entryCount == 0) {
        println("bao build: missing entry point")
        println("Usage: bao build <entry...> [--outdir <dir>] [--minify] [--sourcemap]")
        return
    }

    println("bao build: ${entryCount} entry point(s)")
    println("  outdir: ${outdir}")
    println("  minify: ${minify}")
    println("  sourcemap: ${sourcemap}")
    // BAO_STUB: route/parser is restored, but bundler execution remains disabled in src_min.
    // TODO(bao-cli): delegate to commands.BuildCommand after full bao_cli/src dependency closure compiles.
    println("BAO_STUB build: bundler execution is not wired in src_min yet")
}

func testCommand(args: Array<String>, start: Int64): Unit {
    var watch = false
    var coverage = false
    var patternCount: Int64 = 0
    var i = start

    while (i < args.size) {
        let arg = args[i]
        match (arg) {
            case "--watch" | "-w" => watch = true
            case "--coverage" | "-c" => coverage = true
            case _ =>
                if (!arg.startsWith("-")) {
                    patternCount++
                }
        }
        i++
    }

    println("bao test: ${patternCount} pattern(s)")
    println("  watch: ${watch}")
    println("  coverage: ${coverage}")
    // BAO_STUB: test route is restored, but test runner/VM execution remains disabled in src_min.
    // TODO(bao-cli): delegate to commands.TestCommand when full test runner compiles.
    println("BAO_STUB test: test runner is not wired in src_min yet")
}

func installCommand(args: Array<String>, start: Int64): Unit {
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

    println("bao install")
    println("  production: ${production}")
    println("  frozen lockfile: ${frozen}")
    println("  verbose: ${verbose}")
    // BAO_STUB: install route/options are restored, but package manager mutation is disabled in src_min.
    // TODO(bao-cli): delegate to commands.InstallCommand after bao_install integration is stable.
    println("BAO_STUB install: package installation is not wired in src_min yet")
}

func addCommand(args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        println("bao add: missing package")
        println("Usage: bao add <package...>")
        return
    }

    println("bao add")
    printForwardedArgs(args, start)
    // BAO_STUB: add route is restored, but package.json mutation/install is disabled in src_min.
    // TODO(bao-cli): delegate to commands.AddCommand after install command closure compiles.
    println("BAO_STUB add: dependency installation is not wired in src_min yet")
}

func removeCommand(args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        println("bao remove: missing package")
        println("Usage: bao remove <package...>")
        return
    }

    println("bao remove")
    printForwardedArgs(args, start)
    // BAO_STUB: remove route is restored, but package.json mutation/install is disabled in src_min.
    // TODO(bao-cli): delegate to commands.RemoveCommand after install command closure compiles.
    println("BAO_STUB remove: dependency removal is not wired in src_min yet")
}

func initCommand(args: Array<String>, start: Int64): Unit {
    let name = if (args.size > start) { args[start] } else { "my-app" }
    println("bao init ${name}")
    // BAO_STUB: init route is restored, but project file generation is disabled in src_min.
    // TODO(bao-cli): delegate to commands.InitCommand after filesystem template helpers compile.
    println("BAO_STUB init: project scaffolding is not wired in src_min yet")
}

func replCommand(args: Array<String>, start: Int64): Unit {
    println("bao repl")
    // BAO_STUB: repl route is restored, but the interactive VM loop is disabled in src_min.
    // TODO(bao-cli): delegate to commands.ReplCommand when runtime VM eval is available.
    println("BAO_STUB repl: interactive runtime is not wired in src_min yet")
}

func execCommand(command: String, args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        println("bao ${command}: missing command")
        return
    }

    println("bao ${command}")
    printForwardedArgs(args, start)
    // BAO_STUB: exec/x route is restored, but process spawn is disabled in src_min.
    // TODO(bao-cli): delegate to ExecCommand/XCommand after spawn integration is stable.
    println("BAO_STUB ${command}: process execution is not wired in src_min yet")
}

func autoCommand(command: String, args: Array<String>): Unit {
    if (command.startsWith("-")) {
        println("bao: unknown flag '${command}'")
        println("Run `bao --help` for available commands.")
        return
    }

    if (isJavaScriptLikeFile(command)) {
        runJavaScriptFile(command, args, 2)
        return
    }

    println("bao auto-run ${command}")
    printForwardedArgs(args, 2)
    // BAO_STUB: Bun-compatible auto command should run files/scripts after full router is restored.
    // TODO(bao-cli): delegate to AutoCommand/RunCommand once full command router compiles.
    println("BAO_STUB auto: file/script auto execution is not wired in src_min yet")
}

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

func printForwardedArgs(args: Array<String>, start: Int64): Unit {
    if (args.size <= start) {
        return
    }

    var i = start
    while (i < args.size) {
        println("  arg: ${args[i]}")
        i++
    }
}
