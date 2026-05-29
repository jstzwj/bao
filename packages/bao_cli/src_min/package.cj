package bao_cli

import std.env.getCommandLine

let BAO_VERSION = "0.1.0"

main(): Unit {
    let args = getCommandLine()
    if (args.size <= 1) {
        printHelp()
        return
    }

    let command = args[1]
    match (command) {
        case "--version" | "-v" | "version" => printVersion()
        case "--help" | "-h" | "help" => printHelp()
        case "run" => runScript(args)
        case "build" => printStub("build")
        case "test" => printStub("test")
        case "install" | "i" | "add" => printStub(command)
        case "repl" => printStub("repl")
        case _ => printUnsupported(command)
    }
}

func printVersion(): Unit {
    println("bao v${BAO_VERSION}")
}

func printHelp(): Unit {
    println("Bao - JavaScript Runtime & Toolkit (Cangjie)")
    println("")
    println("Usage: bao <command> [options]")
    println("")
    println("Commands:")
    println("  help, --help       Print this help")
    println("  version, -v        Print version")
    println("  run <file>         Minimal run command placeholder")
    println("  build              Build command placeholder")
    println("  test               Test command placeholder")
    println("  install, add       Package manager placeholders")
}

func runScript(args: Array<String>): Unit {
    if (args.size <= 2) {
        println("bao run: missing script or file")
        return
    }
    println("bao run: ${args[2]}")
}

func printStub(command: String): Unit {
    println("bao ${command}: command route is wired; implementation is still being restored")
}

func printUnsupported(command: String): Unit {
    println("bao: unknown command '${command}'")
    println("Run `bao --help` for available commands.")
}
