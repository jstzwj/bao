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
    // Supports: buffer, config, constants, fs, http_parser, natives,
    //           util, uv, tty_wrap, crypto/x509
    // Not-yet-implemented modules throw descriptive errors matching Node.js/Bun behavior
    // ========================================================================
    public static func binding(moduleName: String): Any {
        // --- Implemented bindings ---
        // Each returns a binding object corresponding to the Node.js native binding

        // process.binding("buffer") — Buffer utilities
        // Corresponds to Bun: ProcessBindingBuffer.cpp
        if (moduleName == "buffer") {
            return ProcessBindingBuffer.create()
        }

        // process.binding("config") — Build configuration
        // Corresponds to Bun: BunProcess.cpp processBindingConfig
        if (moduleName == "config") {
            return ProcessBindingConfig.create()
        }

        // process.binding("constants") — Platform constants (fs, os, signals, etc.)
        // Corresponds to Bun: ProcessBindingConstants.h
        if (moduleName == "constants") {
            return ProcessBindingConstants.create()
        }

        // process.binding("fs") — File system binding
        // Corresponds to Bun: ProcessBindingFs.cpp
        if (moduleName == "fs") {
            return ProcessBindingFs.create()
        }

        // process.binding("http_parser") — HTTP parser binding
        // Corresponds to Bun: ProcessBindingHTTPParser.h
        if (moduleName == "http_parser") {
            return ProcessBindingHTTPParser.create()
        }

        // process.binding("natives") — Built-in module source code registry
        // Corresponds to Bun: ProcessBindingNatives.cpp
        if (moduleName == "natives") {
            return ProcessBindingNatives.create()
        }

        // process.binding("util") — Utility types (isUint8Array, etc.)
        // Corresponds to Bun: processBindingUtil -> NodeUtilTypes
        if (moduleName == "util") {
            return ProcessBindingUtil.create()
        }

        // process.binding("uv") — libuv constants and error codes
        // Corresponds to Bun: Process.bindingUV
        if (moduleName == "uv") {
            return ProcessBindingUV.create()
        }

        // process.binding("tty_wrap") — TTY wrapper
        // Corresponds to Bun: createNodeTTYWrapObject
        if (moduleName == "tty_wrap") {
            return ProcessBindingTTY.create()
        }

        // process.binding("crypto/x509") — X509 certificate utilities
        // Corresponds to Bun: createCryptoX509Object
        if (moduleName == "crypto/x509") {
            return ProcessBindingCryptoX509.create()
        }

        // --- Not yet implemented ---
        // These throw descriptive errors matching Bun/Node.js behavior

        if (moduleName == "async_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"async_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "cares_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"cares_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "contextify") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"contextify\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "crypto") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"crypto\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "fs_event_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"fs_event_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "icu") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"icu\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "inspector") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"inspector\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "js_stream") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"js_stream\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "os") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"os\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "pipe_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"pipe_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "process_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"process_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "signal_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"signal_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "spawn_sync") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"spawn_sync\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "stream_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"stream_wrap\") is not implemented in Bao. Track the status at https://github.com/nicolo-ribaudo/tc39-proposal-structs/issues")
        }
        if (moduleName == "tcp_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"tcp_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "tls_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"tls_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "udp_wrap") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"udp_wrap\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "url") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"url\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "v8") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"v8\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }
        if (moduleName == "zlib") {
            throw BaoError(ErrorCode.fromRaw(0),
                "process.binding(\"zlib\") is not implemented in Bao. If that breaks something, please file an issue and include a reproducible code sample.")
        }

        // Unknown module
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

// ============================================================================
// Process binding object factories
// Corresponds to Bun: ProcessBinding*.cpp/h — objects returned by process.binding()
// Each class creates a binding object matching the Node.js native module API
// ============================================================================

// process.binding("buffer") — Buffer utilities
// Corresponds to Bun: ProcessBindingBuffer.cpp
// Provides: Buffer, SlowBuffer, kMaxLength, byteLengthUtf8, etc.
public class ProcessBindingBuffer {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        result.put("kMaxLength", Int64(2147483647))  // 2^31 - 1 (V8 max typed array length)
        result.put("kStringMaxLength", Int64(536870888))  // ~512MB
        result.put("byteLengthUtf8", "")  // TODO: FFI to v8::String::Utf8Length
        return result
    }
}

// process.binding("config") — Build configuration
// Corresponds to Bun: BunProcess.cpp processBindingConfig
// Provides: isDebugBuild, hasOpenSSL, fipsMode, hasIntl, etc.
public class ProcessBindingConfig {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        result.put("isDebugBuild", false)
        result.put("hasOpenSSL", true)
        result.put("fipsMode", false)
        result.put("hasIntl", true)
        result.put("hasTracing", false)
        result.put("hasNodeOptions", true)
        result.put("hasInspector", true)
        result.put("noBrowserGlobals", false)
        result.put("bits", Int64(64))
        return result
    }
}

// process.binding("constants") — Platform constants
// Corresponds to Bun: ProcessBindingConstants.h
// Provides: fs.*, os.*, signals, errno, etc.
public class ProcessBindingConstants {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()

        // fs constants
        var fs = HashMap<String, Any>()
        fs.put("UV_DIRENT_UNKNOWN", Int64(0))
        fs.put("UV_DIRENT_FILE", Int64(1))
        fs.put("UV_DIRENT_DIR", Int64(2))
        fs.put("UV_DIRENT_LINK", Int64(3))
        fs.put("UV_DIRENT_FIFO", Int64(4))
        fs.put("UV_DIRENT_SOCKET", Int64(5))
        fs.put("UV_DIRENT_CHAR", Int64(6))
        fs.put("UV_DIRENT_BLOCK", Int64(7))
        fs.put("O_RDONLY", Int64(0))
        fs.put("O_WRONLY", Int64(1))
        fs.put("O_RDWR", Int64(2))
        fs.put("O_CREAT", Int64(64))
        fs.put("O_EXCL", Int64(128))
        fs.put("O_NOCTTY", Int64(256))
        fs.put("O_TRUNC", Int64(512))
        fs.put("O_APPEND", Int64(1024))
        fs.put("O_DIRECTORY", Int64(65536))
        fs.put("O_NOATIME", Int64(262144))
        fs.put("O_NOFOLLOW", Int64(131072))
        fs.put("O_SYNC", Int64(1052672))
        fs.put("O_DSYNC", Int64(4096))
        fs.put("O_DIRECT", Int64(16384))
        fs.put("O_NONBLOCK", Int64(2048))
        fs.put("S_IFMT", Int64(61440))
        fs.put("S_IFREG", Int64(32768))
        fs.put("S_IFDIR", Int64(16384))
        fs.put("S_IFCHR", Int64(8192))
        fs.put("S_IFBLK", Int64(24576))
        fs.put("S_IFIFO", Int64(4096))
        fs.put("S_IFLNK", Int64(40960))
        fs.put("S_IFSOCK", Int64(49152))
        fs.put("S_IRWXU", Int64(448))
        fs.put("S_IRUSR", Int64(256))
        fs.put("S_IWUSR", Int64(128))
        fs.put("S_IXUSR", Int64(64))
        fs.put("S_IRWXG", Int64(56))
        fs.put("S_IRGRP", Int64(32))
        fs.put("S_IWGRP", Int64(16))
        fs.put("S_IXGRP", Int64(8))
        fs.put("S_IRWXO", Int64(7))
        fs.put("S_IROTH", Int64(4))
        fs.put("S_IWOTH", Int64(2))
        fs.put("S_IXOTH", Int64(1))
        result.put("fs", fs)

        // os constants
        var os = HashMap<String, Any>()
        os.put("UV_UDP_REUSEADDR", Int64(4))
        os.put("signals", signalConstants())
        os.put("errno", errnoConstants())
        result.put("os", os)

        // zlib constants
        var zlib = HashMap<String, Any>()
        zlib.put("Z_NO_FLUSH", Int64(0))
        zlib.put("Z_PARTIAL_FLUSH", Int64(1))
        zlib.put("Z_SYNC_FLUSH", Int64(2))
        zlib.put("Z_FULL_FLUSH", Int64(3))
        zlib.put("Z_FINISH", Int64(4))
        zlib.put("Z_BLOCK", Int64(5))
        zlib.put("Z_OK", Int64(0))
        zlib.put("Z_STREAM_END", Int64(1))
        zlib.put("Z_NEED_DICT", Int64(2))
        zlib.put("Z_ERRNO", Int64(-1))
        zlib.put("Z_STREAM_ERROR", Int64(-2))
        zlib.put("Z_DATA_ERROR", Int64(-3))
        zlib.put("Z_BUF_ERROR", Int64(-5))
        zlib.put("Z_NO_COMPRESSION", Int64(0))
        zlib.put("Z_BEST_SPEED", Int64(1))
        zlib.put("Z_BEST_COMPRESSION", Int64(9))
        zlib.put("Z_DEFAULT_COMPRESSION", Int64(-1))
        zlib.put("Z_FILTERED", Int64(1))
        zlib.put("Z_HUFFMAN_ONLY", Int64(2))
        zlib.put("Z_RLE", Int64(3))
        zlib.put("Z_FIXED", Int64(4))
        zlib.put("Z_DEFAULT_STRATEGY", Int64(0))
        zlib.put("Z_DEFLATED", Int64(8))
        result.put("zlib", zlib)

        return result
    }

    // POSIX signal constants (Linux)
    private static func signalConstants(): HashMap<String, Int64> {
        var signals = HashMap<String, Int64>()
        signals.put("SIGHUP", Int64(1))
        signals.put("SIGINT", Int64(2))
        signals.put("SIGQUIT", Int64(3))
        signals.put("SIGILL", Int64(4))
        signals.put("SIGTRAP", Int64(5))
        signals.put("SIGABRT", Int64(6))
        signals.put("SIGIOT", Int64(6))
        signals.put("SIGBUS", Int64(7))
        signals.put("SIGFPE", Int64(8))
        signals.put("SIGKILL", Int64(9))
        signals.put("SIGUSR1", Int64(10))
        signals.put("SIGSEGV", Int64(11))
        signals.put("SIGUSR2", Int64(12))
        signals.put("SIGPIPE", Int64(13))
        signals.put("SIGALRM", Int64(14))
        signals.put("SIGTERM", Int64(15))
        signals.put("SIGCHLD", Int64(17))
        signals.put("SIGCONT", Int64(18))
        signals.put("SIGSTOP", Int64(19))
        signals.put("SIGTSTP", Int64(20))
        signals.put("SIGTTIN", Int64(21))
        signals.put("SIGTTOU", Int64(22))
        signals.put("SIGURG", Int64(23))
        signals.put("SIGXCPU", Int64(24))
        signals.put("SIGXFSZ", Int64(25))
        signals.put("SIGVTALRM", Int64(26))
        signals.put("SIGPROF", Int64(27))
        signals.put("SIGWINCH", Int64(28))
        signals.put("SIGIO", Int64(29))
        signals.put("SIGSYS", Int64(31))
        return signals
    }

    // POSIX errno constants (Linux)
    private static func errnoConstants(): HashMap<String, Int64> {
        var errnos = HashMap<String, Int64>()
        errnos.put("EPERM", Int64(1))
        errnos.put("ENOENT", Int64(2))
        errnos.put("ESRCH", Int64(3))
        errnos.put("EINTR", Int64(4))
        errnos.put("EIO", Int64(5))
        errnos.put("ENXIO", Int64(6))
        errnos.put("E2BIG", Int64(7))
        errnos.put("ENOEXEC", Int64(8))
        errnos.put("EBADF", Int64(9))
        errnos.put("ECHILD", Int64(10))
        errnos.put("EAGAIN", Int64(11))
        errnos.put("EWOULDBLOCK", Int64(11))
        errnos.put("ENOMEM", Int64(12))
        errnos.put("EACCES", Int64(13))
        errnos.put("EFAULT", Int64(14))
        errnos.put("ENOTBLK", Int64(15))
        errnos.put("EBUSY", Int64(16))
        errnos.put("EEXIST", Int64(17))
        errnos.put("EXDEV", Int64(18))
        errnos.put("ENODEV", Int64(19))
        errnos.put("ENOTDIR", Int64(20))
        errnos.put("EISDIR", Int64(21))
        errnos.put("EINVAL", Int64(22))
        errnos.put("ENFILE", Int64(23))
        errnos.put("EMFILE", Int64(24))
        errnos.put("ENOTTY", Int64(25))
        errnos.put("ETXTBSY", Int64(26))
        errnos.put("EFBIG", Int64(27))
        errnos.put("ENOSPC", Int64(28))
        errnos.put("ESPIPE", Int64(29))
        errnos.put("EROFS", Int64(30))
        errnos.put("EMLINK", Int64(31))
        errnos.put("EPIPE", Int64(32))
        errnos.put("EDOM", Int64(33))
        errnos.put("ERANGE", Int64(34))
        errnos.put("EDEADLK", Int64(35))
        errnos.put("ENAMETOOLONG", Int64(36))
        errnos.put("ENOLCK", Int64(37))
        errnos.put("ENOSYS", Int64(38))
        errnos.put("ENOTEMPTY", Int64(39))
        errnos.put("ELOOP", Int64(40))
        errnos.put("EOVERFLOW", Int64(75))
        errnos.put("EADDRINUSE", Int64(98))
        errnos.put("EADDRNOTAVAIL", Int64(99))
        errnos.put("ENETDOWN", Int64(100))
        errnos.put("ENETUNREACH", Int64(101))
        errnos.put("ENETRESET", Int64(102))
        errnos.put("ECONNABORTED", Int64(103))
        errnos.put("ECONNRESET", Int64(104))
        errnos.put("ENOBUFS", Int64(105))
        errnos.put("EISCONN", Int64(106))
        errnos.put("ENOTCONN", Int64(107))
        errnos.put("ETIMEDOUT", Int64(110))
        errnos.put("ECONNREFUSED", Int64(111))
        errnos.put("EHOSTUNREACH", Int64(113))
        errnos.put("EALREADY", Int64(114))
        errnos.put("EINPROGRESS", Int64(115))
        return errnos
    }
}

// process.binding("fs") — File system binding
// Corresponds to Bun: ProcessBindingFs.cpp
// Provides: open, read, write, close, stat, etc. as FFI stubs
public class ProcessBindingFs {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        // FS stat types
        result.put("S_IFMT", Int64(61440))
        result.put("S_IFREG", Int64(32768))
        result.put("S_IFDIR", Int64(16384))
        result.put("S_IFCHR", Int64(8192))
        result.put("S_IFBLK", Int64(24576))
        result.put("S_IFIFO", Int64(4096))
        result.put("S_IFLNK", Int64(40960))
        result.put("S_IFSOCK", Int64(49152))
        // FFI wrappers for file operations are handled by NodeFsSystem
        result.put("open", "")    // TODO: delegate to NodeFsSystem
        result.put("read", "")    // TODO: delegate to NodeFsSystem
        result.put("write", "")   // TODO: delegate to NodeFsSystem
        result.put("close", "")   // TODO: delegate to NodeFsSystem
        result.put("stat", "")    // TODO: delegate to NodeFsSystem
        result.put("fstat", "")   // TODO: delegate to NodeFsSystem
        result.put("lstat", "")   // TODO: delegate to NodeFsSystem
        result.put("chmod", "")   // TODO: delegate to NodeFsSystem
        result.put("chown", "")   // TODO: delegate to NodeFsSystem
        result.put("utimes", "")  // TODO: delegate to NodeFsSystem
        return result
    }
}

// process.binding("http_parser") — HTTP parser constants
// Corresponds to Bun: ProcessBindingHTTPParser.h
// Provides: HTTPParser methods and status codes
public class ProcessBindingHTTPParser {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        var methods = HashMap<String, Int64>()
        methods.put("DELETE", Int64(0))
        methods.put("GET", Int64(1))
        methods.put("HEAD", Int64(2))
        methods.put("POST", Int64(3))
        methods.put("PUT", Int64(4))
        methods.put("PATCH", Int64(5))
        methods.put("CONNECT", Int64(6))
        methods.put("OPTIONS", Int64(7))
        methods.put("TRACE", Int64(8))
        result.put("methods", methods)
        var allMethods = ArrayList<String>()
        allMethods.add("DELETE")
        allMethods.add("GET")
        allMethods.add("HEAD")
        allMethods.add("POST")
        allMethods.add("PUT")
        allMethods.add("PATCH")
        allMethods.add("CONNECT")
        allMethods.add("OPTIONS")
        allMethods.add("TRACE")
        result.put("allMethods", allMethods.toArray())
        return result
    }
}

// process.binding("natives") — Built-in module source code registry
// Corresponds to Bun: ProcessBindingNatives.cpp
// Returns a map of module name -> source code (currently empty stubs)
public class ProcessBindingNatives {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        // In Bun, natives returns built-in module source code for legacy compatibility
        // Most are empty strings since Bun doesn't include Node.js C++ sources
        result.put("config", "")
        result.put("module", "")
        result.put("path", "")
        result.put("fs", "")
        result.put("http", "")
        result.put("https", "")
        result.put("net", "")
        result.put("os", "")
        result.put("stream", "")
        result.put("url", "")
        result.put("util", "")
        result.put("zlib", "")
        result.put("events", "")
        result.put("assert", "")
        result.put("buffer", "")
        result.put("child_process", "")
        result.put("cluster", "")
        result.put("crypto", "")
        result.put("dgram", "")
        result.put("dns", "")
        result.put("domain", "")
        result.put("inspector", "")
        result.put("perf_hooks", "")
        result.put("punycode", "")
        result.put("querystring", "")
        result.put("readline", "")
        result.put("repl", "")
        result.put("string_decoder", "")
        result.put("sys", "")
        result.put("timers", "")
        result.put("tls", "")
        result.put("tty", "")
        result.put("v8", "")
        result.put("vm", "")
        result.put("worker_threads", "")
        return result
    }
}

// process.binding("util") — Utility types
// Corresponds: Bun: processBindingUtil -> InternalModuleRegistry::NodeUtilTypes
// Provides: isUint8Array, isAnyArrayBuffer, etc. type check utilities
public class ProcessBindingUtil {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        // These are typically JS functions; in Bao they are placeholder strings
        // The actual implementation would need to return callable JS objects
        result.put("isUint8Array", "isUint8Array")
        result.put("isAnyArrayBuffer", "isAnyArrayBuffer")
        result.put("isArgumentsObject", "isArgumentsObject")
        result.put("isBoxedPrimitive", "isBoxedPrimitive")
        result.put("isArrayBufferView", "isArrayBufferView")
        result.put("isAsyncFunction", "isAsyncFunction")
        result.put("isGeneratorFunction", "isGeneratorFunction")
        result.put("isGeneratorObject", "isGeneratorObject")
        result.put("isMap", "isMap")
        result.put("isMapIterator", "isMapIterator")
        result.put("isModuleNamespaceObject", "isModuleNamespaceObject")
        result.put("isNativeError", "isNativeError")
        result.put("isNumberObject", "isNumberObject")
        result.put("isPromise", "isPromise")
        result.put("isProxy", "isProxy")
        result.put("isRegExp", "isRegExp")
        result.put("isSet", "isSet")
        result.put("isSetIterator", "isSetIterator")
        result.put("isSharedArrayBuffer", "isSharedArrayBuffer")
        result.put("isStringObject", "isStringObject")
        result.put("isSymbolObject", "isSymbolObject")
        result.put("isTypedArray", "isTypedArray")
        result.put("isWeakMap", "isWeakMap")
        result.put("isWeakSet", "isWeakSet")
        result.put("isDate", "isDate")
        return result
    }
}

// process.binding("uv") — libuv constants and error codes
// Corresponds to Bun: Process.bindingUV
// Provides: UV_* constants used by Node.js internals
public class ProcessBindingUV {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        // UV error codes
        result.put("UV_E2BIG", Int64(-7))
        result.put("UV_EACCES", Int64(-13))
        result.put("UV_EADDRINUSE", Int64(-98))
        result.put("UV_EADDRNOTAVAIL", Int64(-99))
        result.put("UV_EAFNOSUPPORT", Int64(-97))
        result.put("UV_EAGAIN", Int64(-11))
        result.put("UV_EALREADY", Int64(-114))
        result.put("UV_EBADF", Int64(-9))
        result.put("UV_EBUSY", Int64(-16))
        result.put("UV_ECANCELED", Int64(-125))
        result.put("UV_ECONNABORTED", Int64(-103))
        result.put("UV_ECONNREFUSED", Int64(-111))
        result.put("UV_ECONNRESET", Int64(-104))
        result.put("UV_EDESTADDRREQ", Int64(-89))
        result.put("UV_EEXIST", Int64(-17))
        result.put("UV_EFAULT", Int64(-14))
        result.put("UV_EFBIG", Int64(-27))
        result.put("UV_EHOSTUNREACH", Int64(-113))
        result.put("UV_EINTR", Int64(-4))
        result.put("UV_EINVAL", Int64(-22))
        result.put("UV_EIO", Int64(-5))
        result.put("UV_EISCONN", Int64(-106))
        result.put("UV_EISDIR", Int64(-21))
        result.put("UV_ELOOP", Int64(-40))
        result.put("UV_EMFILE", Int64(-24))
        result.put("UV_EMSGSIZE", Int64(-90))
        result.put("UV_ENAMETOOLONG", Int64(-36))
        result.put("UV_ENETDOWN", Int64(-100))
        result.put("UV_ENETUNREACH", Int64(-101))
        result.put("UV_ENFILE", Int64(-23))
        result.put("UV_ENOBUFS", Int64(-105))
        result.put("UV_ENODEV", Int64(-19))
        result.put("UV_ENOENT", Int64(-2))
        result.put("UV_ENOMEM", Int64(-12))
        result.put("UV_ENONET", Int64(-64))
        result.put("UV_ENOSPC", Int64(-28))
        result.put("UV_ENOSYS", Int64(-38))
        result.put("UV_ENOTCONN", Int64(-107))
        result.put("UV_ENOTDIR", Int64(-20))
        result.put("UV_ENOTEMPTY", Int64(-39))
        result.put("UV_ENOTSOCK", Int64(-88))
        result.put("UV_ENOTSUP", Int64(-95))
        result.put("UV_EOVERFLOW", Int64(-75))
        result.put("UV_EPERM", Int64(-1))
        result.put("UV_EPIPE", Int64(-32))
        result.put("UV_EPROTO", Int64(-71))
        result.put("UV_EPROTONOSUPPORT", Int64(-93))
        result.put("UV_EPROTOTYPE", Int64(-91))
        result.put("UV_ERANGE", Int64(-34))
        result.put("UV_EROFS", Int64(-30))
        result.put("UV_ESHUTDOWN", Int64(-108))
        result.put("UV_ESPIPE", Int64(-29))
        result.put("UV_ESRCH", Int64(-3))
        result.put("UV_ETIMEDOUT", Int64(-110))
        result.put("UV_ETXTBSY", Int64(-26))
        result.put("UV_EXDEV", Int64(-18))
        result.put("UV_UNKNOWN", Int64(-4094))
        return result
    }
}

// process.binding("tty_wrap") — TTY wrapper constants
// Corresponds to Bun: createNodeTTYWrapObject
public class ProcessBindingTTY {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        result.put("isTTY", "")  // TODO: implement isatty() check via FFI
        return result
    }
}

// process.binding("crypto/x509") — X509 certificate utilities
// Corresponds to Bun: createCryptoX509Object
public class ProcessBindingCryptoX509 {
    public static func create(): HashMap<String, Any> {
        var result = HashMap<String, Any>()
        result.put("isX509Certificate", "isX509Certificate")  // TODO: JS function
        return result
    }
}
