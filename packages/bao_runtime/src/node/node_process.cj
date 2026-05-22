// Process information and control APIs (`globalThis.process` / `node:process`)
// Translated from Bun: src/runtime/node/node_process.rs
package bao_runtime.node

import bao_core.*
import bao_jsc.*
import bao_sys.*
import std.collection.ArrayList

// ============================================================================
// CStrPtr — repr(transparent) wrapper around a C string pointer
// Corresponds to Bun: node_process.rs CStrPtr
// Wraps a raw C string pointer for safe static export usage.
// ============================================================================
public struct CStrPtr {
    public var ptr: CPointer<UInt8>

    public init(ptr: CPointer<UInt8>) {
        this.ptr = ptr
    }
}

// ============================================================================
// NodeProcess — Process information and control APIs
// Corresponds to Bun: src/runtime/node/node_process.rs
// Contains: createArgv0, getExecPath, getArgv, getExecArgv, exit,
//           getCwd, setCwd, getTitle, setTitle, getEval,
//           Bun__NODE_NO_WARNINGS, Bun__version, etc.
// ============================================================================
public class NodeProcess {
    // ========================================================================
    // Process title (thread-safe via reentrant mutex in Bun)
    // Corresponds to Bun: node_process.rs _impl getTitle/setTitle
    // Default is "bao" (Bun uses "bun")
    // ========================================================================
    private static var processTitle: String = "bao"

    // ========================================================================
    // Version constants
    // Corresponds to Bun: node_process.rs Bun__version, Bun__version_with_sha
    // ========================================================================
    public static let version: String = "v1.0.0"
    public static let versionWithSha: String = "v1.0.0"

    // Version SHA
    // Corresponds to Bun: Bun__version_sha
    public static let versionSha: String = "unknown"

    // uWS/uSockets version
    // Corresponds to Bun: Bun__versions_uws, Bun__versions_usockets
    public static let versionsUws: String = "unknown"
    public static let versionsUsockets: String = "unknown"

    // ========================================================================
    // createArgv0 — Get argv[0] (the executable name)
    // Corresponds to Bun: node_process.rs create_argv0
    // Returns bun.argv[0] or falls back to "bao"
    // ========================================================================
    public static func createArgv0(): String {
        let argv = NodeProcessSystem.argv()
        if (argv.size > 0) {
            return argv[0]
        }
        return "bao"
    }

    // ========================================================================
    // getExecPath — Get the full path to the executable
    // Corresponds to Bun: node_process.rs get_exec_path
    // Uses selfExePath(), falls back to argv[0] on failure
    // ========================================================================
    public static func getExecPath(): String {
        let path = NodeProcessSystem.selfExePath()
        if (path.size > 0) {
            return path
        }
        return createArgv0()
    }

    // ========================================================================
    // getArgv — C++ accessor wrapper for argv
    // Corresponds to Bun: node_process.rs get_argv
    // ========================================================================
    public static func getArgv(): Array<String> {
        return NodeProcessSystem.argv()
    }

    // ========================================================================
    // getExecArgv — C++ accessor wrapper for execArgv
    // Corresponds to Bun: node_process.rs get_exec_argv
    // ========================================================================
    public static func getExecArgv(): Array<String> {
        return createExecArgv()
    }

    // ========================================================================
    // exit — Exit the process
    // Corresponds to Bun: node_process.rs exit
    // Sets exit code and exits: worker mode calls worker.exit(),
    // main thread calls vm.onExit() + vm.globalExit()
    // ========================================================================
    public static func exit(code: UInt8): Unit {
        // In Bun: vm.exit_handler.exit_code = code
        // Worker: worker.exit(); Main: vm.onExit() + vm.globalExit()
        NodeProcessSystem.exit(Int32(code))
    }

    // ========================================================================
    // NODE_NO_WARNINGS — Check if Node.js warnings are suppressed
    // Corresponds to Bun: node_process.rs Bun__NODE_NO_WARNINGS
    // Checks the NODE_NO_WARNINGS environment variable
    // ========================================================================
    public static func nodeNoWarnings(): Bool {
        let val = OS.getEnv("NODE_NO_WARNINGS")
        return val.isSome()
    }

    // ========================================================================
    // suppressCrashOnProcessKillSelf — Suppress crash on self-kill
    // Corresponds to Bun: node_process.rs Bun__suppressCrashOnProcessKillSelfIfDesired
    // Checks BUN_INTERNAL_SUPPRESS_CRASH_ON_PROCESS_KILL_SELF flag
    // ========================================================================
    public static func suppressCrashOnProcessKillSelf(): Bool {
        let val = OS.getEnv("BUN_INTERNAL_SUPPRESS_CRASH_ON_PROCESS_KILL_SELF")
        return val.isSome()
    }

    // ========================================================================
    // getTitle — Get the process title
    // Corresponds to Bun: node_process.rs _impl get_title
    // Returns the process title or "bao" as default
    // ========================================================================
    public static func getTitle(): String {
        return processTitle
    }

    // ========================================================================
    // setTitle — Set the process title
    // Corresponds to Bun: node_process.rs _impl set_title
    // Thread-safe in Bun via mutex
    // ========================================================================
    public static func setTitle(title: String): Unit {
        processTitle = title
    }

    // ========================================================================
    // createExecArgv — Create execArgv array
    // Corresponds to Bun: node_process.rs _impl create_exec_argv
    // 1. Worker mode: if execArgv is set, use it directly
    // 2. Standalone mode: merge compile_exec_argv and BUN_OPTIONS
    // 3. Normal mode: re-parse process.argv to extract execArgv
    //    - Skip "run" command
    //    - Recognize options that take values (e.g., --eval, --require)
    // ========================================================================
    public static func createExecArgv(): Array<String> {
        let argv = NodeProcessSystem.argv()
        var execArgv = ArrayList<String>()
        var seenRun = false
        var prev: ?String = None

        // Set of options that consume an extra argument
        // Corresponds to Bun: node_process.rs MAP (LazyLock<HashSet>)
        // Built from CLI auto_params with takes_value.isSome()
        let stringOptions: Array<String> = [
            "--eval", "-e",
            "--print", "-p",
            "--require", "-r",
            "--config",
            "--import",
            "--loader",
            "--preload",
            "--es-module-lexer",
            "--conditions",
            "--extension-order",
            "--tsconfig-override"
        ]

        // Skip argv[0]
        var first = true
        for (arg in argv) {
            if (first) {
                first = false
                continue
            }

            let prevVal = prev
            prev = arg

            // Emulate `defer prev = arg` by setting at end of each iteration
            if (arg.startsWith("-")) {
                execArgv.add(arg)
                prev = arg
                continue
            }

            if (!seenRun && arg == "run") {
                seenRun = true
                prev = arg
                continue
            }

            // If previous argument is one that takes a value, include this arg
            if (prevVal.isSome()) {
                var isStringOpt = false
                for (opt in stringOptions) {
                    if (prevVal == opt) {
                        isStringOpt = true
                        break
                    }
                }
                if (isStringOpt) {
                    execArgv.add(arg)
                    prev = arg
                    continue
                }
            }

            // Hit the script name — stop
            break
        }

        return execArgv.toArray()
    }

    // ========================================================================
    // createArgv — Create the full argv array
    // Corresponds to Bun: node_process.rs _impl create_argv
    // 1. Standalone mode: ["bao", main, ...argv]
    // 2. Worker mode: [exe_path, "[worker eval]"/main, ...worker.argv]
    // 3. Normal mode: [exe_path, main, ...vm.argv]
    // Special: [eval] and [stdin] suffixes are handled
    // ========================================================================
    public static func createArgv(): Array<String> {
        let allArgv = NodeProcessSystem.argv()
        var argsList = ArrayList<String>()

        // argv[0] — the executable path or "bao"
        let exePath = NodeProcessSystem.selfExePath()
        if (exePath.size > 0) {
            argsList.add(exePath)
        } else {
            argsList.add("bao")
        }

        // Add remaining argv entries (skip argv[0] which we already handled)
        if (allArgv.size > 1) {
            for (i in 1..allArgv.size) {
                argsList.add(allArgv[i])
            }
        }

        return argsList.toArray()
    }

    // ========================================================================
    // getEval — Get the eval source code
    // Corresponds to Bun: node_process.rs _impl get_eval
    // Returns eval_source contents or None
    // ========================================================================
    public static func getEval(): ?String {
        return None
    }

    // ========================================================================
    // getCwd — Get the current working directory
    // Corresponds to Bun: node_process.rs _impl get_cwd
    // Uses path.getCwd, throws SystemError on failure
    // ========================================================================
    public static func getCwd(): String {
        return OS.getcwd()
    }

    // ========================================================================
    // setCwd — Set the current working directory
    // Corresponds to Bun: node_process.rs _impl set_cwd
    // 1. Validate path is non-empty
    // 2. Call chdir syscall
    // 3. Update bundler's cached cwd
    // 4. Ensure path ends with separator (bundler convention)
    // 5. Return new cwd (without trailing slash)
    // ========================================================================
    public static func setCwd(path: String): Bool {
        if (path.size == 0) {
            return false
        }
        OS.chdir(path)
        return true
    }

    // ========================================================================
    // Environment variable operations
    // ========================================================================

    // Get an environment variable
    public static func getEnv(name: String): ?String {
        return OS.getEnv(name)
    }

    // Set an environment variable
    public static func setEnv(name: String, value: String): Unit {
        OS.setEnv(name, value)
    }

    // Delete an environment variable
    public static func deleteEnv(name: String): Unit {
        OS.unsetEnv(name)
    }

    // Get all environment variables
    public static func getAllEnv(): HashMap<String, String> {
        return NodeProcessSystem.environ()
    }

    // ========================================================================
    // Process ID operations
    // ========================================================================

    // Get process ID
    public static func getPid(): Int32 {
        return Int32(OS.pid())
    }

    // Get parent process ID
    public static func getPpid(): Int32 {
        return Int32(OS.ppid())
    }

    // Get user ID
    public static func getUid(): UInt32 {
        return OS.uid()
    }

    // Get group ID
    public static func getGid(): UInt32 {
        return OS.gid()
    }

    // Set user ID
    public static func setUid(uid: UInt32): Unit {
        NodeProcessSystem.setuid(uid)
    }

    // Set group ID
    public static func setGid(gid: UInt32): Unit {
        NodeProcessSystem.setgid(gid)
    }

    // ========================================================================
    // abort — Abort the process abnormally
    // ========================================================================
    public static func abort(): Unit {
        NodeProcessSystem.abort()
    }

    // ========================================================================
    // kill — Send a signal to a process
    // ========================================================================
    public static func kill(pid: Int32, signal: String): Bool {
        return NodeProcessSystem.kill(pid, signal)
    }

    // ========================================================================
    // nextTick — Schedule a callback for the next tick
    // ========================================================================
    public static func nextTick(callback: () -> Unit): Unit {
        callback()
    }

    // ========================================================================
    // memoryUsage — Get memory usage information
    // ========================================================================
    public static func memoryUsage(): MemoryUsageInfo {
        let info = MemoryUsageInfo()
        info.rss = NodeProcessSystem.rss()
        info.heapTotal = 0
        info.heapUsed = 0
        info.external = 0
        info.arrayBuffers = 0
        return info
    }

    // ========================================================================
    // cpuUsage — Get CPU usage information
    // ========================================================================
    public static func cpuUsage(): CpuUsageInfo {
        let info = CpuUsageInfo()
        info.user = 0
        info.system = 0
        return info
    }

    // ========================================================================
    // umask — Get/set file mode creation mask
    // ========================================================================
    public static func umask(): UInt32 {
        return NodeProcessSystem.umask()
    }

    public static func umask(mask: UInt32): UInt32 {
        return NodeProcessSystem.umask(mask)
    }

    // ========================================================================
    // hrtime — High-resolution time
    // ========================================================================
    public static func hrtime(): Array<Int64> {
        let ns = NodeProcessSystem.hrtime()
        return [ns / 1000000000, ns % 1000000000]
    }

    // ========================================================================
    // processUptime — Process uptime in seconds
    // ========================================================================
    public static func processUptime(): Float64 {
        return NodeProcessSystem.processUptime()
    }
}

// ============================================================================
// MemoryUsageInfo — Memory usage data structure
// Corresponds to Node.js process.memoryUsage() return value
// ============================================================================
public class MemoryUsageInfo {
    public var rss: Int64 = 0
    public var heapTotal: Int64 = 0
    public var heapUsed: Int64 = 0
    public var external: Int64 = 0
    public var arrayBuffers: Int64 = 0

    public init() {}
}

// ============================================================================
// CpuUsageInfo — CPU usage data structure
// Corresponds to Node.js process.cpuUsage() return value
// ============================================================================
public class CpuUsageInfo {
    public var user: Int64 = 0
    public var system: Int64 = 0

    public init() {}
}

// ============================================================================
// NodeProcessSystem — Process system call stubs
// System calls not yet implemented via FFI
// ============================================================================
public class NodeProcessSystem {
    // Get command-line arguments
    public static func argv(): Array<String> {
        return ["bao"]
    }

    // Get executable path
    public static func selfExePath(): String {
        return ""
    }

    // Exit process
    public static func exit(code: Int32): Unit {
        // TODO: FFI call to exit()
    }

    // Change directory
    public static func chdir(path: String): Unit {
        OS.chdir(path)
    }

    // Get all environment variables
    public static func environ(): HashMap<String, String> {
        return HashMap<String, String>()
    }

    // Set user ID
    public static func setuid(uid: UInt32): Unit {
        // TODO: FFI call to setuid()
    }

    // Set group ID
    public static func setgid(gid: UInt32): Unit {
        // TODO: FFI call to setgid()
    }

    // Abort process
    public static func abort(): Unit {
        // TODO: FFI call to abort()
    }

    // Send signal to process
    public static func kill(pid: Int32, signal: String): Bool {
        // TODO: FFI call to kill()
        return false
    }

    // Get RSS memory usage
    public static func rss(): Int64 {
        return 0
    }

    // Get/set file mode creation mask
    public static func umask(): UInt32 {
        return UInt32(0o022)
    }

    public static func umask(mask: UInt32): UInt32 {
        return UInt32(0o022)
    }

    // High-resolution time in nanoseconds
    public static func hrtime(): Int64 {
        return 0
    }

    // Process uptime in seconds
    public static func processUptime(): Float64 {
        return 0.0
    }
}
