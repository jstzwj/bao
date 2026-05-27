package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_path.*

public class Sys {
    public static func exit(code: Int64): Nothing {
        unsafe { exit(Int32(code)) }
        throw BaoError(ErrorCode.Unknown, "exit failed")
    }

    public static func getEnv(name: String): ?String {
        return OS.getEnv(name)
    }

    public static func getenv(name: String): ?String {
        return OS.getEnv(name)
    }

    public static func getcwd(): String {
        return OS.getcwd()
    }

    public static func getcwd(buf: Array<Int8>): String {
        return OS.getcwd()
    }

    public static func getHomeDir(): String {
        let home = OS.getEnv("HOME")
        match (home) {
            case Some(h) => return h
            case None => return ""
        }
    }

    public static func getTempDir(): String {
        return Env.getTmpDir()
    }

    public static func chdir(path: String): Unit {
        OS.chdir(path)
    }

    public static func getExecutablePath(): String {
        unsafe {
            let buf = malloc(UIntNative(4096))
            let bufPtr = CPointer<Int8>(buf)
            let rc = readlink(unsafeNewCString("/proc/self/exe"), bufPtr, UIntNative(4096))
            if (rc > Int64(0)) {
                let str = unsafeCStringToString(bufPtr)
                free(buf)
                return str
            }
            free(buf)
            return "bao"
        }
    }

    public static func selfExePath(): String {
        return getExecutablePath()
    }

    public static func currentTimeMillis(): Int64 {
        return SysModule.currentTimeMillis()
    }

    public static func nanoTime(): Int64 {
        return SysModule.currentTimeMillis() * Int64(1000000)
    }

    public static func nanoTimestamp(): Int64 {
        return SysModule.currentTimeMillis() * Int64(1000000)
    }

    public static func sleep(ns: Int64): Unit {
        let ms = ns / Int64(1000000)
        if (ms > 0) {
            SysModule.sleep(ms)
        }
    }

    public static func osName(): String {
        return SysModule.getOsName()
    }

    public static func archName(): String {
        return SysModule.getArchName()
    }

    public static func exeSuffix(): String {
        return ""
    }

    public static func getProcessorCount(): Int64 {
        return SysModule.cpuCount()
    }

    public static func isTerminal(): Bool {
        unsafe {
            return isatty(0) != 0
        }
    }

    public static func gethostname(): String {
        unsafe {
            let buf = malloc(UIntNative(256))
            let bufPtr = CPointer<Int8>(buf)
            let rc = gethostname(bufPtr, UIntNative(256))
            if (rc == 0) {
                let str = unsafeCStringToString(bufPtr)
                free(buf)
                return str
            }
            free(buf)
            return "localhost"
        }
    }

    public static func getUid(): Int64 {
        unsafe {
            return Int64(getuid())
        }
    }

    public static func random(): UInt64 {
        unsafe {
            let buf = malloc(UIntNative(8))
            let rc = getrandom(buf, UIntNative(8), UInt32(0))
            if (rc == 8) {
                let ptr = CPointer<UInt64>(buf)
                let val = ptr.read()
                free(buf)
                return val
            }
            free(buf)
            return UInt64(0)
        }
    }

    public static func getArgs(): Array<String> {
        return []
    }

    public static func getArgsAlloc(allocator: Unit): Array<String> {
        return []
    }

    public static func existsAt(base: String, path: String): Bool {
        return BaoFile.exists(Path.join([base, path]))
    }

    public static func readDir(path: String): Array<String> {
        let result = ArrayList<String>()
        if (!BaoFile.isDirectory(path)) { return [] }
        let entries = BaoFile.readdir(path)
        for (e in entries) {
            result.append(e)
        }
        return result.items()
    }

    public static func readDirRecursive(path: String, maxDepth: Int64): Array<String> {
        let result = ArrayList<String>()
        collectDirRecursive(path, "", maxDepth, Int64(0), result)
        return result.items()
    }

    private static func collectDirRecursive(base: String, prefix: String, maxDepth: Int64, depth: Int64, result: ArrayList<String>): Unit {
        if (depth > maxDepth) { return }
        let dirPath = if (prefix.size > 0) { Path.join([base, prefix]) } else { base }
        if (!BaoFile.isDirectory(dirPath)) { return }
        let entries = BaoFile.readdir(dirPath)
        for (e in entries) {
            let relPath = if (prefix.size > 0) { "${prefix}/${e}" } else { e }
            let fullPath = Path.join([base, relPath])
            if (BaoFile.isDirectory(fullPath)) {
                collectDirRecursive(base, relPath, maxDepth, depth + Int64(1), result)
            }
            result.append(relPath)
        }
    }

    public static func unlink(path: String): Unit {
        BaoFile.remove(path)
    }

    public static func which(name: String): ?String {
        let pathEnv = OS.getEnv("PATH")
        match (pathEnv) {
            case Some(p) =>
                let dirs = p.split(":", Int64(0))
                for (d in dirs) {
                    let candidate = Path.join([d, name])
                    if (BaoFile.exists(candidate)) {
                        return Some(candidate)
                    }
                }
            case None => ()
        }
        return None
    }

    public static func exec(command: String): Unit {
        let opts = SpawnOptions()
        opts.args = ["-c", command]
        ProcessSpawner.`spawn`("/bin/sh", opts)
    }

    public static func execAndWait(command: String, args: Array<String>, cwd: String): Int64 {
        let opts = SpawnOptions()
        opts.args = args
        opts.cwd = Some(cwd)
        let child = ProcessSpawner.`spawn`(command, opts)
        let status = child.wait()
        match (status) {
            case ExitStatus.Exited(code) => return Int64(code)
            case _ => return Int64(-1)
        }
    }

    public static func execCapture(command: String): ?String {
        return None
    }

    public static func spawnSync(args: Array<String>, env: Unit, stdin: Int64, stdout: Int64, stderr: Int64): Int64 {
        if (args.size == 0) { return Int64(-1) }
        let opts = SpawnOptions()
        var rest = Array<String>(args.size - 1, { _ => "" })
        for (i in 1..args.size) {
            rest[i - 1] = args[i]
        }
        opts.args = rest
        let child = ProcessSpawner.`spawn`(args[0], opts)
        let status = child.wait()
        match (status) {
            case ExitStatus.Exited(code) => return Int64(code)
            case _ => return Int64(-1)
        }
    }

    public static func spawnProcess(options: Unit, argv: Array<String>): Int64 {
        if (argv.size == 0) { return Int64(-1) }
        let opts = SpawnOptions()
        var rest = Array<String>(argv.size - 1, { _ => "" })
        for (i in 1..argv.size) {
            rest[i - 1] = argv[i]
        }
        opts.args = rest
        let child = ProcessSpawner.`spawn`(argv[0], opts)
        return child.pid
    }

    public static func fstat(fd: Int64): ?PosixStat {
        return None
    }

    public static func openUrl(url: String): Unit {
        exec("xdg-open " + url)
    }

    public static func readlink(path: String): SysMaybe<String> {
        return SysModule.readlink(path)
    }
}
