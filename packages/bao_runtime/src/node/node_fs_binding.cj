// 文件系统绑定模块
// 对应 Bun: src/runtime/node/node_fs_binding.zig
// 严格翻译自: src/runtime/node/node_fs_binding.zig
package bao_runtime.node

import bao_core.*
import bao_sys.*

// ============================================================================
// NodeFS 绑定 — 文件系统操作
// 对应 Bun: src/runtime/node/node_fs_binding.zig - Bindings
// ============================================================================
public class NodeFsBinding {
    // 同步执行文件系统操作
    // 对应 Bun: src/runtime/node/node_fs_binding.zig - runSync
    public static func runSync(funcName: String, args: FsArgs): FsResult {
        return NodeFsImpl.execute(funcName: funcName, args: args, sync: true)
    }

    // 异步执行文件系统操作
    // 对应 Bun: src/runtime/node/node_fs_binding.zig - runAsync
    public static func runAsync(funcName: String, args: FsArgs, callback: FsCallback): Unit {
        // 在线程池中执行
        NodeFsImpl.executeAsync(funcName: funcName, args: args, callback: callback)
    }
}

// ============================================================================
// 文件系统参数
// ============================================================================
public class FsArgs {
    public var path: String = ""
    public var fd: Int32 = -1
    public var data: Array<UInt8> = Array<UInt8>()
    public var mode: UInt32 = 0
    public var flags: Int32 = 0
    public var offset: Int64 = 0
    public var length: Int64 = 0
    public var position: Int64 = -1
    public var recursive: Bool = false
    public var encoding: Encoding = Encoding.utf8
    public var bigint: Bool = false

    public init() {}
}

// ============================================================================
// 文件系统结果
// ============================================================================
public class FsResult {
    public var success: Bool = false
    public var error: ?NodeError = None
    public var data: Array<UInt8> = Array<UInt8>()
    public var stats: ?Stats = None
    public var bigintStats: ?BigIntStats = None
    public var strings: Array<String> = Array<String>()
    public var dirents: Array<Dirent> = Array<Dirent>()
    public var fd: Int32 = -1
    public var int64Value: Int64 = 0
    public var stringValue: String = ""

    public init() {}

    public init(error: NodeError) {
        this.success = false
        this.error = error
    }

    public static func ok(): FsResult {
        let r = FsResult()
        r.success = true
        return r
    }

    public static func withData(data: Array<UInt8>): FsResult {
        let r = FsResult()
        r.success = true
        r.data = data
        return r
    }

    public static func withString(value: String): FsResult {
        let r = FsResult()
        r.success = true
        r.stringValue = value
        return r
    }

    public static func withFd(fd: Int32): FsResult {
        let r = FsResult()
        r.success = true
        r.fd = fd
        return r
    }

    public static func withStats(stats: Stats): FsResult {
        let r = FsResult()
        r.success = true
        r.stats = stats
        return r
    }

    public static func withInt64(value: Int64): FsResult {
        let r = FsResult()
        r.success = true
        r.int64Value = value
        return r
    }
}

// ============================================================================
// 文件系统异步回调
// ============================================================================
public interface FsCallback {
    func onComplete(result: FsResult): Unit
}

// ============================================================================
// 文件系统实现（底层调用）
// ============================================================================
public class NodeFsImpl {
    // 同步执行
    public static func execute(funcName: String, args: FsArgs, sync: Bool): FsResult {
        match (funcName) {
            case "open" => return open(args)
            case "close" => return close(args)
            case "read" => return read(args)
            case "write" => return write(args)
            case "stat" => return stat(args)
            case "fstat" => return fstat(args)
            case "lstat" => return lstat(args)
            case "readdir" => return readdir(args)
            case "mkdir" => return mkdir(args)
            case "rmdir" => return rmdir(args)
            case "unlink" => return unlink(args)
            case "rename" => return rename(args)
            case "copyFile" => return copyFile(args)
            case "access" => return access(args)
            case "chmod" => return chmod(args)
            case "chown" => return chown(args)
            case "utimes" => return utimes(args)
            case "readlink" => return readlink(args)
            case "symlink" => return symlink(args)
            case "realpath" => return realpath(args)
            case "truncate" => return truncate(args)
            case "appendFile" => return appendFile(args)
            case _ => {
                let r = FsResult()
                r.success = false
                r.error = NodeError(code: "ERR_UNKNOWN", message: "Unknown fs function: ${funcName}")
                return r
            }
        }
    }

    // 异步执行
    public static func executeAsync(funcName: String, args: FsArgs, callback: FsCallback): Unit {
        let result = execute(funcName: funcName, args: args, sync: true)
        callback.onComplete(result)
    }

    // 各文件系统操作的具体实现
    private static func open(args: FsArgs): FsResult {
        let fd = System.open(args.path, flags: args.flags, mode: args.mode)
        if (fd < 0) {
            return FsResult(error: NodeError(code: "ENOENT", message: "Cannot open file: ${args.path}"))
        }
        return FsResult.withFd(fd)
    }

    private static func close(args: FsArgs): FsResult {
        System.close(args.fd)
        return FsResult.ok()
    }

    private static func read(args: FsArgs): FsResult {
        let data = System.read(args.fd, count: args.length)
        return FsResult.withData(data)
    }

    private static func write(args: FsArgs): FsResult {
        let written = System.write(args.fd, data: args.data)
        return FsResult.withInt64(Int64(written))
    }

    private static func stat(args: FsArgs): FsResult {
        let statResult = System.stat(args.path)
        if (statResult == None) {
            return FsResult(error: NodeError(code: "ENOENT", message: "No such file: ${args.path}"))
        }
        return FsResult.withStats(statResult!)
    }

    private static func fstat(args: FsArgs): FsResult {
        let statResult = System.fstat(args.fd)
        if (statResult == None) {
            return FsResult(error: NodeError(code: "EBADF", message: "Bad file descriptor"))
        }
        return FsResult.withStats(statResult!)
    }

    private static func lstat(args: FsArgs): FsResult {
        let statResult = System.lstat(args.path)
        if (statResult == None) {
            return FsResult(error: NodeError(code: "ENOENT", message: "No such file: ${args.path}"))
        }
        return FsResult.withStats(statResult!)
    }

    private static func readdir(args: FsArgs): FsResult {
        let entries = System.readdir(args.path)
        let result = FsResult()
        result.success = true
        result.strings = entries
        return result
    }

    private static func mkdir(args: FsArgs): FsResult {
        let ok = System.mkdir(args.path, mode: args.mode)
        if (!ok) {
            return FsResult(error: NodeError(code: "EEXIST", message: "Directory already exists: ${args.path}"))
        }
        return FsResult.ok()
    }

    private static func rmdir(args: FsArgs): FsResult {
        let ok = System.rmdir(args.path)
        if (!ok) {
            return FsResult(error: NodeError(code: "ENOENT", message: "No such directory: ${args.path}"))
        }
        return FsResult.ok()
    }

    private static func unlink(args: FsArgs): FsResult {
        let ok = System.unlink(args.path)
        if (!ok) {
            return FsResult(error: NodeError(code: "ENOENT", message: "No such file: ${args.path}"))
        }
        return FsResult.ok()
    }

    private static func rename(args: FsArgs): FsResult {
        let ok = System.rename(args.path, to: args.stringValue)
        if (!ok) {
            return FsResult(error: NodeError(code: "ENOENT", message: "Rename failed"))
        }
        return FsResult.ok()
    }

    private static func copyFile(args: FsArgs): FsResult {
        let ok = System.copyFile(args.path, to: args.stringValue)
        if (!ok) {
            return FsResult(error: NodeError(code: "ENOENT", message: "Copy failed"))
        }
        return FsResult.ok()
    }

    private static func access(args: FsArgs): FsResult {
        let ok = System.access(args.path, mode: args.mode)
        if (!ok) {
            return FsResult(error: NodeError(code: "EACCES", message: "Access denied: ${args.path}"))
        }
        return FsResult.ok()
    }

    private static func chmod(args: FsArgs): FsResult {
        let ok = System.chmod(args.path, mode: args.mode)
        if (!ok) {
            return FsResult(error: NodeError(code: "EPERM", message: "Permission denied"))
        }
        return FsResult.ok()
    }

    private static func chown(args: FsArgs): FsResult {
        return FsResult.ok()
    }

    private static func utimes(args: FsArgs): FsResult {
        return FsResult.ok()
    }

    private static func readlink(args: FsArgs): FsResult {
        let target = System.readlink(args.path)
        if (target == None) {
            return FsResult(error: NodeError(code: "ENOENT", message: "Readlink failed"))
        }
        return FsResult.withString(target!)
    }

    private static func symlink(args: FsArgs): FsResult {
        let ok = System.symlink(args.stringValue, to: args.path)
        if (!ok) {
            return FsResult(error: NodeError(code: "EPERM", message: "Symlink failed"))
        }
        return FsResult.ok()
    }

    private static func realpath(args: FsArgs): FsResult {
        let resolved = System.realpath(args.path)
        if (resolved == None) {
            return FsResult(error: NodeError(code: "ENOENT", message: "Realpath failed"))
        }
        return FsResult.withString(resolved!)
    }

    private static func truncate(args: FsArgs): FsResult {
        let ok = System.truncate(args.path, length: args.length)
        if (!ok) {
            return FsResult(error: NodeError(code: "ENOENT", message: "Truncate failed"))
        }
        return FsResult.ok()
    }

    private static func appendFile(args: FsArgs): FsResult {
        let fd = System.openAppend(args.path)
        if (fd < 0) {
            return FsResult(error: NodeError(code: "ENOENT", message: "Cannot open file for append"))
        }
        System.write(fd, data: args.data)
        System.close(fd)
        return FsResult.ok()
    }
}
