package bao_min_cli

import std.env.getCommandLine

let BAO_VERSION = "0.1.0"

main(): Unit {
    let args = getCommandLine()
    if (args.size <= 1) {
        printHelp()
        return
    }

    match (args[1]) {
        case "--version" | "-v" | "version" => printVersion()
        case "--help" | "-h" | "help" => printHelp()
        case command => printUnsupported(command)
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
    println("")
    println("Runtime, bundler, install, test, and server commands are still behind the full bao_cli/runtime build.")
}

func printUnsupported(command: String): Unit {
    println("bao: command not available in minimal CLI: ${command}")
    println("Run `bao --help` for currently wired commands.")
}
