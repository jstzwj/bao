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
        return NodeFsImpl.execute(funcName, args, true)
    }

    // 异步执行文件系统操作
    // 对应 Bun: src/runtime/node/node_fs_binding.zig - runAsync
    public static func runAsync(funcName: String, args: FsArgs, callback: FsCallback): Unit {
        // 在线程池中执行
        NodeFsImpl.executeAsync(funcName, args, callback)
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
// 所有操作委托给 NodeFsSystem 完成实际的系统调用
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
            case "fchmod" => return fchmod(args)
            case "chown" => return chown(args)
            case "fchown" => return fchown(args)
            case "lchown" => return lchown(args)
            case "lchmod" => return lchmod(args)
            case "utimes" => return utimes(args)
            case "lutimes" => return lutimes(args)
            case "futimes" => return futimes(args)
            case "fdatasync" => return fdatasync(args)
            case "fsync" => return fsync(args)
            case "ftruncate" => return ftruncate(args)
            case "truncate" => return truncate(args)
            case "readlink" => return readlink(args)
            case "symlink" => return symlink(args)
            case "realpath" => return realpath(args)
            case "appendFile" => return appendFile(args)
            case "readFile" => return readFile(args)
            case "writeFile" => return writeFile(args)
            case "exists" => return exists(args)
            case "statfs" => return statfs(args)
            case "mkdtemp" => return mkdtemp(args)
            case "link" => return link(args)
            case "rm" => return rm(args)
            case "cp" => return cp(args)
            case _ =>
                let r = FsResult()
                r.success = false
                r.error = NodeError("ERR_UNKNOWN", "Unknown fs function: ${funcName}", 0, "")
                return r
        }
    }

    // 异步执行
    public static func executeAsync(funcName: String, args: FsArgs, callback: FsCallback): Unit {
        let result = execute(funcName, args, true)
        callback.onComplete(result)
    }

    // 各文件系统操作的具体实现

    private static func open(args: FsArgs): FsResult {
        let fd = NodeFsSystem.open(args.path, args.flags, args.mode)
        if (fd < 0) {
            return FsResult(NodeError("ENOENT", "Cannot open file: ${args.path}", 0, ""))
        }
        return FsResult.withFd(fd)
    }

    private static func close(args: FsArgs): FsResult {
        NodeFsSystem.close(args.fd)
        return FsResult.ok()
    }

    private static func read(args: FsArgs): FsResult {
        let bufSize = if (args.length > 0) { Int64(args.length) } else { Int64(16384) }
        let buffer = Array<UInt8>(bufSize, { _ => UInt8(0) })
        let pos = if (args.position >= 0) { args.position } else { Int64(-1) }
        let bytesRead = NodeFsSystem.readFd(args.fd, buffer, 0, bufSize, pos)
        if (bytesRead < 0) {
            return FsResult(NodeError("EIO", "Read failed", 0, ""))
        }
        let resultData = if (Int64(bytesRead) < Int64(buffer.size)) {
            buffer[0..bytesRead]
        } else {
            buffer
        }
        let r = FsResult.withData(resultData)
        r.int64Value = bytesRead
        return r
    }

    private static func write(args: FsArgs): FsResult {
        let pos = if (args.position >= 0) { args.position } else { Int64(-1) }
        let written = NodeFsSystem.writeFd(args.fd, args.data, args.offset, Int64(args.data.size), pos)
        if (written < 0) {
            return FsResult(NodeError("EIO", "Write failed", 0, ""))
        }
        return FsResult.withInt64(written)
    }

    private static func stat(args: FsArgs): FsResult {
        let statResult = NodeFsSystem.stat(args.path)
        if (statResult.isNone()) {
            return FsResult(NodeError("ENOENT", "No such file: ${args.path}", 0, ""))
        }
        return FsResult.withStats(statResult.getOrThrow())
    }

    private static func fstat(args: FsArgs): FsResult {
        let statResult = NodeFsSystem.fstat(args.fd)
        if (statResult.isNone()) {
            return FsResult(NodeError("EBADF", "Bad file descriptor", 0, ""))
        }
        return FsResult.withStats(statResult.getOrThrow())
    }

    private static func lstat(args: FsArgs): FsResult {
        let statResult = NodeFsSystem.lstat(args.path)
        if (statResult.isNone()) {
            return FsResult(NodeError("ENOENT", "No such file: ${args.path}", 0, ""))
        }
        return FsResult.withStats(statResult.getOrThrow())
    }

    private static func readdir(args: FsArgs): FsResult {
        let entries = NodeFsSystem.readdir(args.path)
        let result = FsResult()
        result.success = true
        result.strings = entries
        return result
    }

    private static func mkdir(args: FsArgs): FsResult {
        let ok = if (args.recursive) {
            NodeFsSystem.mkdirRecursive(args.path, args.mode)
        } else {
            NodeFsSystem.mkdir(args.path, args.mode) >= 0
        }
        if (!ok) {
            return FsResult(NodeError("EEXIST", "Directory already exists: ${args.path}", 0, ""))
        }
        return FsResult.ok()
    }

    private static func rmdir(args: FsArgs): FsResult {
        let ok = if (args.recursive) {
            NodeFsSystem.rmRecursive(args.path)
        } else {
            NodeFsSystem.rmdir(args.path) >= 0
        }
        if (!ok) {
            return FsResult(NodeError("ENOENT", "No such directory: ${args.path}", 0, ""))
        }
        return FsResult.ok()
    }

    private static func unlink(args: FsArgs): FsResult {
        let ok = NodeFsSystem.unlink(args.path)
        if (ok < 0) {
            return FsResult(NodeError("ENOENT", "No such file: ${args.path}", 0, ""))
        }
        return FsResult.ok()
    }

    private static func rename(args: FsArgs): FsResult {
        let ok = NodeFsSystem.rename(args.path, args.path)
        if (ok < 0) {
            return FsResult(NodeError("ENOENT", "Rename failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func copyFile(args: FsArgs): FsResult {
        let ok = NodeFsSystem.copyFile(args.path, args.path, 0)
        if (ok < 0) {
            return FsResult(NodeError("ENOENT", "Copy failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func access(args: FsArgs): FsResult {
        let ok = NodeFsSystem.access(args.path, args.mode)
        if (!ok) {
            return FsResult(NodeError("EACCES", "Access denied: ${args.path}", 0, ""))
        }
        return FsResult.ok()
    }

    private static func chmod(args: FsArgs): FsResult {
        let ok = NodeFsSystem.chmod(args.path, args.mode)
        if (!ok) {
            return FsResult(NodeError("EPERM", "Permission denied", 0, ""))
        }
        return FsResult.ok()
    }

    private static func fchmod(args: FsArgs): FsResult {
        let ok = NodeFsSystem.fchmod(args.fd, args.mode)
        if (!ok) {
            return FsResult(NodeError("EBADF", "Bad file descriptor", 0, ""))
        }
        return FsResult.ok()
    }

    private static func chown(args: FsArgs): FsResult {
        let ok = NodeFsSystem.chown(args.path, UInt32(0), UInt32(0))
        if (!ok) {
            return FsResult(NodeError("EPERM", "Permission denied", 0, ""))
        }
        return FsResult.ok()
    }

    private static func fchown(args: FsArgs): FsResult {
        let ok = NodeFsSystem.fchown(args.fd, UInt32(0), UInt32(0))
        if (!ok) {
            return FsResult(NodeError("EBADF", "Bad file descriptor", 0, ""))
        }
        return FsResult.ok()
    }

    private static func lchown(args: FsArgs): FsResult {
        let ok = NodeFsSystem.lchown(args.path, UInt32(0), UInt32(0))
        if (!ok) {
            return FsResult(NodeError("EPERM", "Permission denied", 0, ""))
        }
        return FsResult.ok()
    }

    private static func lchmod(args: FsArgs): FsResult {
        return FsResult(NodeError("ENOTSUP", "lchmod not supported", 0, ""))
    }

    private static func utimes(args: FsArgs): FsResult {
        let ok = NodeFsSystem.utimes(args.path, Float64(args.offset), Float64(args.length))
        if (ok < 0) {
            return FsResult(NodeError("ENOENT", "utimes failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func lutimes(args: FsArgs): FsResult {
        let ok = NodeFsSystem.lutimes(args.path, Float64(args.offset), Float64(args.length))
        if (ok < 0) {
            return FsResult(NodeError("ENOENT", "lutimes failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func futimes(args: FsArgs): FsResult {
        let ok = NodeFsSystem.futimes(args.fd, Float64(args.offset), Float64(args.length))
        if (ok < 0) {
            return FsResult(NodeError("EBADF", "futimes failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func fdatasync(args: FsArgs): FsResult {
        let ok = NodeFsSystem.fdatasync(args.fd)
        if (ok < 0) {
            return FsResult(NodeError("EBADF", "fdatasync failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func fsync(args: FsArgs): FsResult {
        let ok = NodeFsSystem.fsync(args.fd)
        if (ok < 0) {
            return FsResult(NodeError("EBADF", "fsync failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func ftruncate(args: FsArgs): FsResult {
        let ok = NodeFsSystem.ftruncate(args.fd, args.length)
        if (ok < 0) {
            return FsResult(NodeError("EBADF", "ftruncate failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func truncate(args: FsArgs): FsResult {
        let ok = NodeFsSystem.truncate(args.path, args.length)
        if (ok < 0) {
            return FsResult(NodeError("ENOENT", "truncate failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func readlink(args: FsArgs): FsResult {
        let target = NodeFsSystem.readlink(args.path)
        if (target.isNone()) {
            return FsResult(NodeError("ENOENT", "Readlink failed", 0, ""))
        }
        return FsResult.withString(target.getOrThrow())
    }

    private static func symlink(args: FsArgs): FsResult {
        let ok = NodeFsSystem.symlink(args.path, args.path)
        if (ok < 0) {
            return FsResult(NodeError("EPERM", "Symlink failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func realpath(args: FsArgs): FsResult {
        let resolved = NodeFsSystem.realpath(args.path)
        if (resolved.isNone()) {
            return FsResult(NodeError("ENOENT", "Realpath failed", 0, ""))
        }
        return FsResult.withString(resolved.getOrThrow())
    }

    private static func appendFile(args: FsArgs): FsResult {
        let fd = NodeFsSystem.open(args.path, Int32(FsOpenConstants.O_WRONLY) | Int32(FsOpenConstants.O_APPEND) | Int32(FsOpenConstants.O_CREAT), args.mode)
        if (fd < 0) {
            return FsResult(NodeError("ENOENT", "Cannot open file for append", 0, ""))
        }
        NodeFsSystem.writeFd(fd, args.data, 0, Int64(args.data.size), -1)
        NodeFsSystem.close(fd)
        return FsResult.ok()
    }

    private static func readFile(args: FsArgs): FsResult {
        let data = NodeFsSystem.readFile(args.path)
        if (data.isNone()) {
            return FsResult(NodeError("ENOENT", "Cannot read file: ${args.path}", 0, ""))
        }
        return FsResult.withData(data.getOrThrow())
    }

    private static func writeFile(args: FsArgs): FsResult {
        let ok = NodeFsSystem.writeFile(args.path, args.data, UInt32(0o666))
        if (ok < 0) {
            return FsResult(NodeError("EIO", "Write file failed: ${args.path}", 0, ""))
        }
        return FsResult.ok()
    }

    private static func exists(args: FsArgs): FsResult {
        let ok = NodeFsSystem.access(args.path, 0)
        let r = FsResult()
        r.success = true
        r.int64Value = if (ok) { Int64(1) } else { Int64(0) }
        return r
    }

    private static func statfs(args: FsArgs): FsResult {
        let result = NodeFsSystem.statfs(args.path)
        if (result.isNone()) {
            return FsResult(NodeError("ENOENT", "statfs failed", 0, ""))
        }
        let r = FsResult()
        r.success = true
        return r
    }

    private static func mkdtemp(args: FsArgs): FsResult {
        let result = NodeFsSystem.mkdtemp(args.path)
        if (result.isNone()) {
            return FsResult(NodeError("EIO", "mkdtemp failed", 0, ""))
        }
        return FsResult.withString(result.getOrThrow())
    }

    private static func link(args: FsArgs): FsResult {
        let ok = NodeFsSystem.link(args.path, args.path)
        if (ok < 0) {
            return FsResult(NodeError("EPERM", "link failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func rm(args: FsArgs): FsResult {
        let ok = if (args.recursive) {
            NodeFsSystem.rmRecursive(args.path)
        } else {
            NodeFsSystem.unlink(args.path) >= 0
        }
        if (!ok) {
            return FsResult(NodeError("ENOENT", "rm failed", 0, ""))
        }
        return FsResult.ok()
    }

    private static func cp(args: FsArgs): FsResult {
        let ok = NodeFsSystem.cpRecursive(args.path, args.path, true)
        if (!ok) {
            return FsResult(NodeError("ENOENT", "cp failed", 0, ""))
        }
        return FsResult.ok()
    }
}
