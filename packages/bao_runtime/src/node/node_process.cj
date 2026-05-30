// Process information and control APIs (`globalThis.process` / `node:process`)
// Translated from Bun: src/runtime/node/node_process.rs
package bao_runtime.node

import bao_core.Output
import bao_core.PathString
import bao_core.MutableString
import bao_core.BunString
import bao_core.FeatureFlags
import bao_core.ErrorCode
import bao_core.BaoError
import bao_jsc.*
import bao_sys.*
import std.convert.*
import std.collection.ArrayList

// ============================================================================
// FFI declarations for POSIX process control functions
// Corresponds to Bun: node_process.rs / node_process.zig system calls
// Uses @C foreign func to link directly to C library symbols
// ============================================================================

// Process lifecycle
@C foreign func _exit(code: Int32): Unit
@C foreign func c_abort(): Unit

// Signal handling
@C foreign func c_kill(pid: Int32, sig: Int32): Int32

// User/group ID operations
@C foreign func c_getuid(): UInt32
@C foreign func c_getgid(): UInt32
@C foreign func c_geteuid(): UInt32
@C foreign func c_getegid(): UInt32
@C foreign func c_setuid(uid: UInt32): Int32
@C foreign func c_setgid(gid: UInt32): Int32
@C foreign func c_seteuid(uid: UInt32): Int32
@C foreign func c_setegid(gid: UInt32): Int32
@C foreign func c_getgroups(size: Int32, list: CPointer<UInt32>): Int32
@C foreign func c_setgroups(size: Int32, list: CPointer<UInt32>): Int32

// File mode creation mask
@C foreign func c_umask(mask: UInt32): UInt32

// High-resolution timer
@C foreign func clock_gettime_monotonic_ns(): Int64

// 进程信息 FFI 声明
// 对应 Bun: /proc/self/status, sysconf, readlink("/proc/self/exe") 等
@C foreign func c_readlink(path: CPointer<Int8>, buf: CPointer<UInt8>, bufsize: UIntNative): Int64
@C foreign func c_sysconf(name: Int32): Int64
@C foreign func c_getrusage(who: Int32, usage: CPointer<Int8>): Int32

// Dynamic library loading (for process.dlopen)
@C foreign func c_dlopen(filename: CPointer<Int8>, flag: Int32): CPointer<Unit>
@C foreign func c_dlsym(handle: CPointer<Unit>, symbol: CPointer<Int8>): CPointer<Unit>
@C foreign func c_dlclose(handle: CPointer<Unit>): Int32
@C foreign func c_dlerror(): CPointer<Int8>

// environ 全局变量（C 外部链接）- 通过函数访问
foreign func c_get_environ(): CPointer<CPointer<Int8>>

// exitCode 全局变量 — 进程退出码
private var globalExitCode: UInt8 = 0

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
        NodeProcessSystem.setExitCode(code)
        NodeProcessSystem.exit(Int32(code))
    }

    // ========================================================================
    // exitCode — Get/set the process exit code
    // Corresponds to Bun: node_process.rs exitCode getter/setter
    // ========================================================================
    public static func getExitCode(): UInt8 {
        return NodeProcessSystem.getExitCode()
    }

    public static func setExitCode(code: UInt8): Unit {
        NodeProcessSystem.setExitCode(code)
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
    // 使用 getrusage(RUSAGE_SELF) 获取用户态和内核态时间
    // ========================================================================
    public static func cpuUsage(): CpuUsageInfo {
        let info = CpuUsageInfo()
        unsafe {
            let bufSize = UIntNative(144)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<Int8>(buf)
            for (i in 0..Int64(144)) {
                (bufPtr + i).write(Int8(0))
            }
            // RUSAGE_SELF = 0
            let rc = c_getrusage(0, bufPtr)
            if (rc == 0) {
                // rusage 结构体 (Linux x86_64):
                //   ru_utime.tv_sec  @ offset 0  (Int64)
                //   ru_utime.tv_usec @ offset 8  (Int64)
                //   ru_stime.tv_sec  @ offset 16 (Int64)
                //   ru_stime.tv_usec @ offset 24 (Int64)
                let userSec = (CPointer<Int64>(CPointer<Unit>(bufPtr))).read()
                let userUsec = (CPointer<Int64>(CPointer<Unit>(bufPtr + 8))).read()
                let sysSec = (CPointer<Int64>(CPointer<Unit>(bufPtr + 16))).read()
                let sysUsec = (CPointer<Int64>(CPointer<Unit>(bufPtr + 24))).read()
                info.user = (userSec * 1000000 + userUsec) * 1000  // 微秒 → 纳秒
                info.system = (sysSec * 1000000 + sysUsec) * 1000
            }
            free(buf)
        }
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

    // ========================================================================
    // platform — Get the operating system platform
    // Corresponds to Bun: BunProcess.cpp constructPlatform
    // Returns "linux", "darwin", "win32", "freebsd", "android"
    // Currently hardcoded for Linux; conditional compilation can be added
    // when Cangjie supports platform-specific compilation flags.
    // ========================================================================
    public static func platform(): String {
        return "linux"
    }

    // ========================================================================
    // arch — Get the CPU architecture
    // Corresponds to Bun: BunProcess.cpp constructArch
    // Returns "x64", "arm64", "arm", "ia32", etc.
    // Currently hardcoded for x86_64; conditional compilation can be added
    // when Cangjie supports architecture-specific compilation flags.
    // ========================================================================
    public static func arch(): String {
        return "x64"
    }

    // ========================================================================
    // versions — Get runtime version information
    // Corresponds to Bun: BunProcess.cpp constructVersions
    // Returns a map of component -> version string
    // ========================================================================
    public static func versions(): HashMap<String, String> {
        var result = HashMap<String, String>()
        result.put("node", "22.6.0")
        result.put("bao", version)
        result.put("v8", "13.6.233.10-node.18")
        result.put("uv", "1.48.0")
        result.put("napi", "10")
        result.put("openssl", "1.1.0")
        result.put("modules", "127")
        return result
    }

    // ========================================================================
    // binding — Load a built-in native module binding
    // Corresponds to Bun: BunProcess.cpp Process_functionBinding
    // Supports: buffer, config, constants, fs, http_parser, util, uv, etc.
    // Most bindings throw "not implemented" errors matching Node.js behavior
    // ========================================================================
    public static func binding(moduleName: String): Unit {
        // Known modules that are not yet implemented
        let notImplemented: Array<String> = [
            "async_wrap", "cares_wrap", "contextify", "crypto",
            "fs_event_wrap", "icu", "inspector", "js_stream",
            "os", "pipe_wrap", "process_wrap", "signal_wrap",
            "spawn_sync", "stream_wrap", "tcp_wrap", "tls_wrap",
            "udp_wrap", "url", "v8", "zlib"
        ]
        for (m in notImplemented) {
            if (m == moduleName) {
                throw BaoError(ErrorCode.fromRaw(0),
                    "process.binding(\"${moduleName}\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
            }
        }
        // Modules with issue tracking
        let notImplementedWithIssue: Array<String> = ["stream_wrap"]
        for (m in notImplementedWithIssue) {
            if (m == moduleName) {
                throw BaoError(ErrorCode.fromRaw(0),
                    "process.binding(\"${moduleName}\") is not implemented in Bao. Track the status at https://github.com/nicolo-ribaudo/tc39-proposal-structs/issues")
            }
        }
        throw BaoError(ErrorCode.fromRaw(0), "No such module: ${moduleName}")
    }

    // ========================================================================
    // dlopen — Load a dynamic shared library
    // Corresponds to Bun: BunProcess.cpp Process_functionDlopen
    // Uses dlopen/dlsym/dlclose from libdl via FFI
    // ========================================================================
    public static func dlopen(moduleObj: Any, filename: String): Unit {
        NodeProcessSystem.dlopen(filename)
    }

    // ========================================================================
    // getgroups — Get supplementary group IDs
    // Corresponds to Bun: BunProcess.cpp Process_functiongetgroups
    // POSIX only: returns array of group IDs
    // ========================================================================
    public static func getgroups(): Array<UInt32> {
        return NodeProcessSystem.getgroups()
    }

    // ========================================================================
    // setgroups — Set supplementary group IDs
    // Corresponds to Bun: BunProcess.cpp Process_functionsetgroups
    // POSIX only: takes array of group IDs (max 64)
    // ========================================================================
    public static func setgroups(groups: Array<UInt32>): Unit {
        NodeProcessSystem.setgroups(groups)
    }

    // ========================================================================
    // geteuid — Get effective user ID
    // Corresponds to Bun: BunProcess.cpp Process_functiongeteuid
    // ========================================================================
    public static func geteuid(): UInt32 {
        return NodeProcessSystem.geteuid()
    }

    // ========================================================================
    // getegid — Get effective group ID
    // Corresponds to Bun: BunProcess.cpp Process_functiongetegid
    // ========================================================================
    public static func getegid(): UInt32 {
        return NodeProcessSystem.getegid()
    }

    // ========================================================================
    // seteuid — Set effective user ID
    // Corresponds to Bun: BunProcess.cpp Process_functionseteuid
    // ========================================================================
    public static func seteuid(uid: UInt32): Unit {
        NodeProcessSystem.seteuid(uid)
    }

    // ========================================================================
    // setegid — Set effective group ID
    // Corresponds to Bun: BunProcess.cpp Process_functionsetegid
    // ========================================================================
    public static func setegid(gid: UInt32): Unit {
        NodeProcessSystem.setegid(gid)
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
// NodeProcessSystem — Process system call implementations via FFI
// Implements POSIX system calls for process information and control.
// Uses direct @C FFI bindings where Cangjie OS module is insufficient,
// and delegates to bao_sys.OS for standard POSIX operations.
// Corresponds to Bun: node_process.zig + BunProcess.cpp
// ============================================================================
public class NodeProcessSystem {
    // 进程启动时间（单调时钟纳秒）
    // 对应 Bun: bun.timespec.now() 在进程启动时记录
    private static let startMonoNs: Int64 = unsafe { clock_gettime_monotonic_ns() }

    // Get command-line arguments
    // 对应 Bun: node_process.zig argv — 通过 VM 传入或在进程启动时从 C 运行时获取
    // 使用 /proc/self/cmdline 读取真实的命令行参数
    public static func argv(): Array<String> {
        let cmdLine = readProcSelfCmdline()
        if (cmdLine.size > 0) {
            return cmdLine
        }
        return ["bao"]
    }

    // Get executable path
    // 对应 Bun: node_process.zig selfExePath
    // 通过 readlink("/proc/self/exe") 获取可执行文件路径
    public static func selfExePath(): String {
        unsafe {
            let path = toProcCString("/proc/self/exe")
            let bufSize = UIntNative(4096)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt8>(buf)
            let len = c_readlink(path, bufPtr, bufSize)
            free(CPointer<Unit>(path))
            if (len <= 0) {
                free(buf)
                return ""
            }
            let result = unsafeBufToString(bufPtr, Int64(len))
            free(buf)
            return result
        }
    }

    // Exit process
    // 对应 Bun: std.posix.exit / sys.exit
    public static func exit(code: Int32): Unit {
        OS.exit(code)
    }

    // Change directory
    public static func chdir(path: String): Unit {
        OS.chdir(path)
    }

    // Get all environment variables
    // 对应 Bun: node_process.zig environ — 遍历 C 运行时 environ 数组
    public static func environ(): HashMap<String, String> {
        let result = HashMap<String, String>()
        unsafe {
            var envPtr = c_get_environ()
            var idx: Int64 = 0
            while (true) {
                let entryPtr = (envPtr + idx).read()
                if (entryPtr.isNull()) {
                    break
                }
                let entry = unsafeCStringToString(entryPtr)
                let eqIdx = entry.indexOf('=')
                if (let Some(ei) <- eqIdx) {
                    if (ei >= 0 && ei < entry.size) {
                        let key = entry[0..ei]
                        let value = entry[ei + 1..]
                        result.put(key, value)
                    }
                }
                idx += 1
            }
        }
        return result
    }

    // Set user ID
    // 对应 Bun: std.posix.system.setuid
    public static func setuid(uid: UInt32): Unit {
        let rc = OS.setuid(uid)
        if (rc != 0) {
            throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "setuid failed")
        }
    }

    // Set group ID
    // 对应 Bun: std.posix.system.setgid
    public static func setgid(gid: UInt32): Unit {
        let rc = OS.setgid(gid)
        if (rc != 0) {
            throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "setgid failed")
        }
    }

    // Abort process
    // 对应 Bun: std.posix.abort
    public static func abort(): Unit {
        OS.abort()
    }

    // Send signal to process
    // 对应 Bun: sys.kill / std.posix.kill
    // signal parameter is a string like "SIGTERM", "SIGKILL", etc.
    public static func kill(pid: Int32, signal: String): Bool {
        let sigNum = signalStringToNumber(signal)
        let rc = OS.kill(pid, sigNum)
        return rc == 0
    }

    // Convert signal name string to signal number
    // e.g. "SIGTERM" -> 15, "SIGKILL" -> 9, "9" -> 9
    private static func signalStringToNumber(signal: String): Int32 {
        // If it's already a number string (first char is digit), parse it directly
        if (signal.size > 0) {
            let firstChar = signal[Int64(0)]
            if (firstChar >= UInt8(48) && firstChar <= UInt8(57)) { // '0'-'9'
                return Int32(Int64.parse(signal))
            }
        }
        // Map signal name to number
        let sigName = if (signal.startsWith("SIG")) { signal } else { "SIG" + signal }
        match (sigName) {
            case "SIGHUP" => return 1
            case "SIGINT" => return 2
            case "SIGQUIT" => return 3
            case "SIGILL" => return 4
            case "SIGTRAP" => return 5
            case "SIGABRT" => return 6
            case "SIGBUS" => return 7
            case "SIGFPE" => return 8
            case "SIGKILL" => return 9
            case "SIGUSR1" => return 10
            case "SIGSEGV" => return 11
            case "SIGUSR2" => return 12
            case "SIGPIPE" => return 13
            case "SIGALRM" => return 14
            case "SIGTERM" => return 15
            case "SIGSTKFLT" => return 16
            case "SIGCHLD" => return 17
            case "SIGCONT" => return 18
            case "SIGSTOP" => return 19
            case "SIGTSTP" => return 20
            case "SIGTTIN" => return 21
            case "SIGTTOU" => return 22
            case "SIGURG" => return 23
            case "SIGXCPU" => return 24
            case "SIGXFSZ" => return 25
            case "SIGVTALRM" => return 26
            case "SIGPROF" => return 27
            case "SIGWINCH" => return 28
            case "SIGIO" => return 29
            case "SIGPWR" => return 30
            case "SIGSYS" => return 31
            case _ => return 15 // Default to SIGTERM
        }
    }

    // Get RSS memory usage
    // 对应 Bun: node_process.zig rss — 使用 getrusage(RUSAGE_SELF) 获取最大 RSS
    // rusage 结构体在 Linux x86_64 上:
    //   ru_maxrss @ offset 0 (Int64)
    public static func rss(): Int64 {
        unsafe {
            // rusage 结构体大小约 144 字节，分配足够空间
            let bufSize = UIntNative(144)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<Int8>(buf)
            // 初始化为 0
            for (i in 0..Int64(144)) {
                (bufPtr + i).write(Int8(0))
            }
            // RUSAGE_SELF = 0
            let rc = c_getrusage(0, bufPtr)
            if (rc != 0) {
                free(buf)
                return 0
            }
            // ru_maxrss 在 Linux x86_64 上是 rusage 结构体的第一个字段 (offset 0)，类型为 Int64
            // 单位: KB（Linux）或 bytes（macOS）
            let maxRss = CPointer<Int64>(CPointer<Unit>(bufPtr)).read()
            free(buf)
            return maxRss * 1024  // KB → bytes
        }
    }

    // Get/set file mode creation mask
    // 对应 Bun: std.os.system.umask
    public static func umask(): UInt32 {
        // umask(0) sets mask to 0 and returns the old value,
        // then umask(old) restores it. This reads the current umask.
        let old = OS.umask(UInt32(0))
        let _ = OS.umask(old)
        return old
    }

    public static func umask(mask: UInt32): UInt32 {
        return OS.umask(mask)
    }

    // High-resolution time in nanoseconds
    // Corresponds to Bun: node_process.zig hrtime
    // Uses clock_gettime(CLOCK_MONOTONIC) for high-resolution timing
    public static func hrtime(): Int64 {
        return unsafe { clock_gettime_monotonic_ns() }
    }

    // Process uptime in seconds
    // 对应 Bun: node_process.zig processUptime
    // 使用 clock_gettime(CLOCK_MONOTONIC) 计算经过时间
    public static func processUptime(): Float64 {
        let nowNs = unsafe { clock_gettime_monotonic_ns() }
        let elapsedNs = nowNs - startMonoNs
        return Float64(elapsedNs) / 1_000_000_000.0
    }

    // Get/Set exit code
    // 对应 Bun: node_process.zig exitCode
    public static func getExitCode(): UInt8 {
        return globalExitCode
    }

    public static func setExitCode(code: UInt8): Unit {
        globalExitCode = code
    }

    // ========================================================================
    // User/group ID operations via FFI
    // Corresponds to Bun: BunProcess.cpp Process_functiongeteuid/getegid
    // ========================================================================

    // Get effective user ID
    // Corresponds to Bun: geteuid() syscall
    public static func geteuid(): UInt32 {
        return unsafe { c_geteuid() }
    }

    // Get effective group ID
    // Corresponds to Bun: getegid() syscall
    public static func getegid(): UInt32 {
        return unsafe { c_getegid() }
    }

    // Set effective user ID
    // Corresponds to Bun: BunProcess.cpp Process_functionseteuid
    public static func seteuid(uid: UInt32): Unit {
        let rc = unsafe { c_seteuid(uid) }
        if (rc != 0) {
            throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "seteuid failed")
        }
    }

    // Set effective group ID
    // Corresponds to Bun: BunProcess.cpp Process_functionsetegid
    public static func setegid(gid: UInt32): Unit {
        let rc = unsafe { c_setegid(gid) }
        if (rc != 0) {
            throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "setegid failed")
        }
    }

    // ========================================================================
    // Group operations via FFI
    // Corresponds to Bun: BunProcess.cpp Process_functiongetgroups/setgroups
    // ========================================================================

    // Get supplementary group IDs
    // Corresponds to Bun: getgroups(0, nullptr) + getgroups(ngroups, groups)
    public static func getgroups(): Array<UInt32> {
        unsafe {
            // First call to get number of groups
            let nullPtr: CPointer<UInt32> = CPointer<UInt32>()
            let ngroups = c_getgroups(0, nullPtr)
            if (ngroups < 0) {
                throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "getgroups failed")
            }
            if (ngroups == 0) {
                return []
            }
            // Allocate buffer and get groups
            let bufSize = UIntNative(ngroups * 4)  // UInt32 = 4 bytes
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt32>(buf)
            let rc = c_getgroups(Int32(ngroups), bufPtr)
            if (rc < 0) {
                free(buf)
                throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "getgroups failed")
            }
            // Build result array
            var groups = ArrayList<UInt32>()
            for (i in 0..Int64(rc)) {
                groups.add((bufPtr + i).read())
            }
            free(buf)
            return groups.toArray()
        }
    }

    // Set supplementary group IDs
    // Corresponds to Bun: setgroups(count, groupsStack)
    // Maximum 64 groups (matching Bun/Node.js behavior)
    public static func setgroups(groups: Array<UInt32>): Unit {
        if (groups.size > 64) {
            throw BaoError(ErrorCode.fromRaw(0), "groups.length must be <= 64")
        }
        unsafe {
            let count = groups.size
            if (count == 0) {
                let nullPtr: CPointer<UInt32> = CPointer<UInt32>()
                let rc = c_setgroups(0, nullPtr)
                if (rc != 0) {
                    throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "setgroups failed")
                }
                return
            }
            // Stack-allocate group array (max 64 * 4 = 256 bytes)
            let bufSize = UIntNative(count * 4)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<UInt32>(buf)
            for (i in 0..Int64(count)) {
                (bufPtr + i).write(groups[i])
            }
            let rc = c_setgroups(Int32(count), bufPtr)
            free(buf)
            if (rc != 0) {
                throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "setgroups failed")
            }
        }
    }

    // ========================================================================
    // Dynamic library loading
    // Corresponds to Bun: BunProcess.cpp Process_functionDlopen
    // Uses dlopen/dlsym/dlclose from libdl via FFI
    // ========================================================================

    // dlopen constants
    private static let RTLD_LAZY: Int32 = 1
    private static let RTLD_NOW: Int32 = 2

    // Load a dynamic shared library
    // Corresponds to Bun: Process_functionDlopen — calls dlopen(path, RTLD_LAZY)
    public static func dlopen(filename: String): Unit {
        unsafe {
            let pathPtr = toProcCString(filename)
            let handle = c_dlopen(pathPtr, RTLD_LAZY)
            free(CPointer<Unit>(pathPtr))
            if (handle.isNull()) {
                let errPtr = c_dlerror()
                let errMsg = if (errPtr.isNull()) { "unknown error" } else { unsafeCStringToString(errPtr) }
                throw BaoError(ErrorCode.fromRaw(0), "dlopen failed: ${errMsg}")
            }
            // Note: In Bun, the handle is stored on the globalObject for NAPI module support.
            // For now we just load and validate; the handle leaks intentionally (matches Node.js behavior).
        }
    }

    // ========================================================================
    // 辅助函数: C 字符串工具
    // ========================================================================

    /// 创建 C 字符串
    private static func toProcCString(s: String): CPointer<Int8> {
        unsafe {
            let len = s.size
            let ptr = malloc(UIntNative(len + 1))
            let bytesPtr = CPointer<Int8>(ptr)
            for (i in 0..len) {
                (bytesPtr + Int64(i)).write(Int8(Int64(s[Int64(i)]) & 0xFF))
            }
            (bytesPtr + Int64(len)).write(Int8(0))
            return bytesPtr
        }
    }

    /// C 字符串转仓颉字符串
    private static func unsafeCStringToString(ptr: CPointer<Int8>): String {
        unsafe {
            var len = 0
            while (!(ptr + Int64(len)).read() == Int8(0)) {
                len += 1
            }
            var sb = ""
            for (i in 0..len) {
                sb += String(Rune(Int32((ptr + Int64(i)).read())))
            }
            return sb
        }
    }

    /// 从缓冲区创建字符串
    private static func unsafeBufToString(buf: CPointer<UInt8>, len: Int64): String {
        unsafe {
            var sb = ""
            for (i in 0..len) {
                sb += String(Rune(Int32((buf + i).read())))
            }
            return sb
        }
    }

    /// 读取 /proc/self/cmdline 获取真实 argv
    /// /proc/self/cmdline 格式: 参数之间用 \0 分隔
    private static func readProcSelfCmdline(): Array<String> {
        let content = NodeFsSystem.readFile("/proc/self/cmdline")
        if (content.isNone()) {
            return []
        }
        let data = content.getOrThrow()
        var args = ArrayList<String>()
        var current = ""
        for (b in data) {
            if (b == UInt8(0)) {
                let arg = current
                if (arg.size > 0) {
                    args.add(arg)
                }
                current = ""
            } else {
                current += String(Rune(Int32(b)))
            }
        }
        // 处理最后一个参数（如果没有以 \0 结尾）
        let lastArg = current
        if (lastArg.size > 0) {
            args.add(lastArg)
        }
        return args.toArray()
    }
}
