// 严格翻译自: src/runtime/node/node_fs.zig
// This file contains the underlying implementation for sync & async functions
// for interacting with the filesystem from JavaScript.
// The top-level functions assume the arguments are already validated
package bao_runtime.node

import bao_core.*
import bao_sys.*
import bao_jsc.*

// ============================================================================
// Re-exports
// 对应 Bun: pub const constants = @import("./node_fs_constant.zig");
// ============================================================================
public type FsConstants = FsAccessConstants
public type FsCopy = FsCopyConstants
public type FsOpen = FsOpenConstants
public type FsType = FsTypeConstants
public type FsMode = FsModeConstants

// ============================================================================
// defaultPermission — 默认文件权限
// 对应 Bun: pub const default_permission
// ============================================================================
public func defaultPermission(): UInt32 {
    return 0o666.asInstanceOf<UInt32>()  // S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH
}

// ============================================================================
// Flavor — 同步/异步调用模式
// 对应 Bun: pub const Flavor = enum { sync, async };
// ============================================================================
public enum Flavor {
    | sync
    | async
}

// ============================================================================
// Maybe<T> — Result 类型：成功或错误
// 对应 Bun: bun.sys.Maybe(T)
// ============================================================================
public class Maybe<T> {
    public var hasError: Bool = false
    public var error: SyscallError = SyscallError()
    public var result: T

    public init(result: T) {
        this.hasError = false
        this.result = result
    }

    public init(error: SyscallError) {
        this.hasError = true
        this.error = error
    }

    public static func success(): Maybe<Unit> {
        return Maybe<Unit>(result: Unit)
    }

    public static func err(code: String, syscall: String, path: String): Maybe<T> {
        return Maybe<T>(error: SyscallError(code: code, syscall: syscall, path: path))
    }

    public func isSuccess(): Bool {
        return !hasError
    }

    public func getError(): ?SyscallError {
        if (hasError) {
            return error
        }
        return None
    }

    public func getResult(): ?T {
        if (!hasError) {
            return result
        }
        return None
    }

    public func toJS(globalObject: JsGlobalObject): JsValue {
        if (hasError) {
            return error.toJS(globalObject)
        }
        return JsValue.from(globalObject, result)
    }
}

// ============================================================================
// SyscallError — 系统调用错误
// 对应 Bun: jsc.SystemError
// ============================================================================
public class SyscallError {
    public var errno: Int32 = 0
    public var code: String = ""
    public var message: String = ""
    public var path: String = ""
    public var dest: String = ""
    public var syscall: String = ""
    public var fd: Int32 = -1

    public init() {}

    public init(errno: Int32, code: String, message: String, path: String, syscall: String) {
        this.errno = errno
        this.code = code
        this.message = message
        this.path = path
        this.syscall = syscall
    }

    public init(code: String, syscall: String, path: String) {
        this.code = code
        this.syscall = syscall
        this.path = path
        this.message = "${code}: ${syscall}, ${path}"
    }

    public static func fromCode(code: String, syscall: String): SyscallError {
        return SyscallError(code: code, syscall: syscall, path: "", message: code)
    }

    public func withPath(path: String): SyscallError {
        let err = SyscallError()
        err.errno = errno
        err.code = code
        err.message = message
        err.syscall = syscall
        err.path = path
        err.dest = dest
        err.fd = fd
        return err
    }

    public func withPathDest(src: String, dest: String): SyscallError {
        let err = withPath(src)
        err.dest = dest
        return err
    }

    public func toJS(globalObject: JsGlobalObject): JsValue {
        let obj = JsObject(globalObject)
        obj.set("code", JsValue(BaoString(code)))
        obj.set("message", JsValue(BaoString(message)))
        obj.set("errno", JsValue(Int64(errno)))
        obj.set("syscall", JsValue(BaoString(syscall)))
        if (path.length > 0) {
            obj.set("path", JsValue(BaoString(path)))
        }
        if (dest.length > 0) {
            obj.set("dest", JsValue(BaoString(dest)))
        }
        return JsValue(obj).toError(globalObject)
    }
}

// ============================================================================
// NodeError — Node.js 兼容的错误抛出辅助
// ============================================================================
public class NodeError {
    public static func throw(code: String, message: String): SyscallError {
        return SyscallError(errno: 0, code: code, message: message, path: "", syscall: "")
    }
}

// ============================================================================
// ReadPosition — 读取位置类型
// 对应 Bun: ReadPosition
// ============================================================================
public type ReadPosition = Int64

// ============================================================================
// Mode — 文件权限模式类型
// 对应 Bun: Mode
// ============================================================================
public type Mode = UInt32

// ============================================================================
// FD — 文件描述符类型
// 对应 Bun: FD
// ============================================================================
public type FD = Int32

// ============================================================================
// PathLike — 路径类型（字符串或 Buffer）
// 对应 Bun: PathLike
// ============================================================================
public class PathLike {
    public var path: String = ""
    public var isBuffer: Bool = false
    public var buffer: Array<UInt8> = Array<UInt8>()

    public init(path: String) {
        this.path = path
    }

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        this.isBuffer = true
    }

    public func slice(): String {
        return path
    }

    public func deinit(): Unit {
        path = ""
        buffer = Array<UInt8>()
    }

    public func toThreadSafe(): Unit {
        // Cangjie strings are immutable and thread-safe by default
    }
}

// ============================================================================
// StringOrBuffer — 字符串或 Buffer 数据
// 对应 Bun: StringOrBuffer
// ============================================================================
public class StringOrBuffer {
    public var isString: Bool = true
    public var str: String = ""
    public var buffer: Array<UInt8> = Array<UInt8>()

    public init(str: String) {
        this.str = str
        this.isString = true
    }

    public init(buffer: Array<UInt8>) {
        this.buffer = buffer
        this.isString = false
    }

    public func slice(): Array<UInt8> {
        if (isString) {
            return Utf8Codec.encode(str)
        }
        return buffer
    }

    public func deinit(): Unit {
        str = ""
        buffer = Array<UInt8>()
    }

    public func toThreadSafe(): Unit {
        // Already thread-safe in Cangjie
    }
}

// ============================================================================
// Buffer — 标记的 ArrayBuffer
// 对应 Bun: Buffer (jsc.MarkedArrayBuffer)
// ============================================================================
public class Buffer {
    public var bytes: Array<UInt8> = Array<UInt8>()

    public init() {}

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
    }

    public func slice(): Array<UInt8> {
        return bytes
    }

    public static func fromString(s: String): Buffer {
        return Buffer(bytes: Utf8Codec.encode(s))
    }

    public static func fromBytes(bytes: Array<UInt8>): Buffer {
        return Buffer(bytes: bytes)
    }
}

// ============================================================================
// Arguments — 所有文件系统操作的参数结构体
// 对应 Bun: pub const Arguments = struct { ... }
// ============================================================================

// Arguments.Access
// 对应 Bun: Arguments.Access
public class AccessArgs {
    public var path: PathLike
    public var mode: Int32 = 4  // R_OK
    public init(path: PathLike, mode: Int32) {
        this.path = path
        this.mode = mode
    }
}

// Arguments.Rename
public class RenameArgs {
    public var oldPath: PathLike
    public var newPath: PathLike
    public init(oldPath: PathLike, newPath: PathLike) {
        this.oldPath = oldPath
        this.newPath = newPath
    }
}

// Arguments.Truncate
public class TruncateArgs {
    public var path: PathOrFileDescriptor
    public var len: Int64 = 0
    public var flags: Int32 = 0
    public init(path: PathOrFileDescriptor, len: Int64) {
        this.path = path
        this.len = len
    }
}

// Arguments.FTruncate
public class FTruncateArgs {
    public var fd: FD
    public var len: Int64 = 0
    public init(fd: FD, len: Int64) {
        this.fd = fd
        this.len = len
    }
}

// Arguments.Chown
public class ChownArgs {
    public var path: PathLike
    public var uid: UInt32 = 0
    public var gid: UInt32 = 0
    public init(path: PathLike, uid: UInt32, gid: UInt32) {
        this.path = path
        this.uid = uid
        this.gid = gid
    }
}

// Arguments.Fchown
public class FchownArgs {
    public var fd: FD
    public var uid: UInt32 = 0
    public var gid: UInt32 = 0
    public init(fd: FD, uid: UInt32, gid: UInt32) {
        this.fd = fd
        this.uid = uid
        this.gid = gid
    }
}

// Arguments.Chmod
public class ChmodArgs {
    public var path: PathLike
    public var mode: Mode = 0o777
    public init(path: PathLike, mode: Mode) {
        this.path = path
        this.mode = mode
    }
}

// Arguments.FChmod
public class FChmodArgs {
    public var fd: FD
    public var mode: Mode = 0o777
    public init(fd: FD, mode: Mode) {
        this.fd = fd
        this.mode = mode
    }
}

// Arguments.Stat
public class StatArgs {
    public var path: PathLike
    public var bigint: Bool = false
    public var throwIfNoEntry: Bool = true
    public init(path: PathLike, bigint: Bool, throwIfNoEntry: Bool) {
        this.path = path
        this.bigint = bigint
        this.throwIfNoEntry = throwIfNoEntry
    }
}

// Arguments.Fstat
public class FstatArgs {
    public var fd: FD
    public var bigint: Bool = false
    public init(fd: FD, bigint: Bool) {
        this.fd = fd
        this.bigint = bigint
    }
}

// Arguments.Link
public class LinkArgs {
    public var oldPath: PathLike
    public var newPath: PathLike
    public init(oldPath: PathLike, newPath: PathLike) {
        this.oldPath = oldPath
        this.newPath = newPath
    }
}

// Arguments.Symlink
public class SymlinkArgs {
    public var target: PathLike
    public var newPath: PathLike
    public var linkType: String = "file"  // Windows only: "file" | "dir" | "junction"
    public init(target: PathLike, newPath: PathLike, linkType: String) {
        this.target = target
        this.newPath = newPath
        this.linkType = linkType
    }
}

// Arguments.Readlink
public class ReadlinkArgs {
    public var path: PathLike
    public var encoding: Encoding = Encoding.utf8
    public init(path: PathLike, encoding: Encoding) {
        this.path = path
        this.encoding = encoding
    }
}

// Arguments.Realpath
public class RealpathArgs {
    public var path: PathLike
    public var encoding: Encoding = Encoding.utf8
    public init(path: PathLike, encoding: Encoding) {
        this.path = path
        this.encoding = encoding
    }
}

// Arguments.Unlink
public class UnlinkArgs {
    public var path: PathLike
    public init(path: PathLike) {
        this.path = path
    }
}

// Arguments.RmDir
public class RmDirArgs {
    public var path: PathLike
    public var force: Bool = false
    public var maxRetries: UInt32 = 0
    public var recursive: Bool = false
    public var retryDelay: UInt32 = 100
    public init(path: PathLike, recursive: Bool, force: Bool) {
        this.path = path
        this.recursive = recursive
        this.force = force
    }
}

// Arguments.Mkdir
public class MkdirArgs {
    public var path: PathLike
    public var recursive: Bool = false
    public var mode: Mode = 0o777.asInstanceOf<Mode>()
    public var alwaysReturnNone: Bool = false
    public init(path: PathLike, recursive: Bool, mode: Mode) {
        this.path = path
        this.recursive = recursive
        this.mode = mode
    }
}

// Arguments.MkdirTemp
public class MkdirTempArgs {
    public var prefix: PathLike
    public var encoding: Encoding = Encoding.utf8
    public init(prefix: PathLike) {
        this.prefix = prefix
    }
}

// Arguments.Readdir
public class ReaddirArgs {
    public var path: PathLike
    public var encoding: Encoding = Encoding.utf8
    public var withFileTypes: Bool = false
    public var recursive: Bool = false
    public init(path: PathLike, encoding: Encoding, withFileTypes: Bool, recursive: Bool) {
        this.path = path
        this.encoding = encoding
        this.withFileTypes = withFileTypes
        this.recursive = recursive
    }
}

// Arguments.Close
public class CloseArgs {
    public var fd: FD
    public init(fd: FD) {
        this.fd = fd
    }
}

// Arguments.Open
public class OpenArgs {
    public var path: PathLike
    public var flags: Int32 = 0  // O_RDONLY
    public var mode: Mode = defaultPermission()
    public init(path: PathLike, flags: Int32, mode: Mode) {
        this.path = path
        this.flags = flags
        this.mode = mode
    }
}

// Arguments.Read
public class ReadArgs {
    public var fd: FD
    public var buffer: Array<UInt8>
    public var offset: UInt64 = 0
    public var length: UInt64 = 0
    public var position: ?ReadPosition = None
    public init(fd: FD, buffer: Array<UInt8>, offset: UInt64, length: UInt64, position: ?ReadPosition) {
        this.fd = fd
        this.buffer = buffer
        this.offset = offset
        this.length = length
        this.position = position
    }
}

// Arguments.Write
public class WriteArgs {
    public var fd: FD
    public var buffer: StringOrBuffer
    public var offset: UInt64 = 0
    public var length: UInt64 = Int64.MaxValue.asInstanceOf<UInt64>()
    public var position: ?ReadPosition = None
    public var encoding: Encoding = Encoding.buffer
    public init(fd: FD, buffer: StringOrBuffer, offset: UInt64, length: UInt64, position: ?ReadPosition) {
        this.fd = fd
        this.buffer = buffer
        this.offset = offset
        this.length = length
        this.position = position
    }
}

// Arguments.ReadFile
public class ReadFileArgs {
    public var path: PathOrFileDescriptor
    public var encoding: Encoding = Encoding.buffer
    public var offset: Int64 = 0
    public var maxSize: ?Int64 = None
    public var flag: Int32 = 0  // O_RDONLY
    public init(path: PathOrFileDescriptor, encoding: Encoding) {
        this.path = path
        this.encoding = encoding
    }
}

// Arguments.WriteFile
public class WriteFileArgs {
    public var encoding: Encoding = Encoding.utf8
    public var flag: Int32 = 0x241  // O_WRONLY | O_CREAT | O_TRUNC
    public var mode: Mode = 0o666.asInstanceOf<Mode>()
    public var file: PathOrFileDescriptor
    public var flush: Bool = false
    public var data: StringOrBuffer
    public var dirfd: FD = -100  // AT_FDCWD
    public init(file: PathOrFileDescriptor, data: StringOrBuffer, encoding: Encoding) {
        this.file = file
        this.data = data
        this.encoding = encoding
    }
}

// Arguments.CopyFile
public class CopyFileArgs {
    public var src: PathLike
    public var dest: PathLike
    public var mode: Int32 = 0
    public init(src: PathLike, dest: PathLike, mode: Int32) {
        this.src = src
        this.dest = dest
        this.mode = mode
    }
}

// Arguments.StatFS
public class StatFSArgs {
    public var path: PathLike
    public var bigint: Bool = false
    public init(path: PathLike, bigint: Bool) {
        this.path = path
        this.bigint = bigint
    }
}

// Arguments.Utimes
public class UtimesArgs {
    public var path: PathLike
    public var atime: Float64 = 0.0
    public var mtime: Float64 = 0.0
    public init(path: PathLike, atime: Float64, mtime: Float64) {
        this.path = path
        this.atime = atime
        this.mtime = mtime
    }
}

// Arguments.Futimes
public class FutimesArgs {
    public var fd: FD
    public var atime: Float64 = 0.0
    public var mtime: Float64 = 0.0
    public init(fd: FD, atime: Float64, mtime: Float64) {
        this.fd = fd
        this.atime = atime
        this.mtime = mtime
    }
}

// Arguments.FdataSync
public class FdataSyncArgs {
    public var fd: FD
    public init(fd: FD) {
        this.fd = fd
    }
}

// Arguments.Fsync
public class FsyncArgs {
    public var fd: FD
    public init(fd: FD) {
        this.fd = fd
    }
}

// Arguments.Exists
public class ExistsArgs {
    public var path: ?PathLike = None
    public init(path: ?PathLike) {
        this.path = path
    }
}

// ============================================================================
// Return — 所有文件系统操作的返回类型
// 对应 Bun: pub const Return = struct { ... }
// ============================================================================

/// Read result with bytes_read count
/// 对应 Bun: Return.Read
public class ReadResult {
    public var bytesRead: Int64 = 0
    public init(bytesRead: Int64) {
        this.bytesRead = bytesRead
    }
}

/// Write result with bytes_written count
/// 对应 Bun: Return.Write
public class WriteResult {
    public var bytesWritten: Int64 = 0
    public init(bytesWritten: Int64) {
        this.bytesWritten = bytesWritten
    }
}

/// ReadPromise result with bytesRead and buffer
/// 对应 Bun: Return.ReadPromise
public class ReadPromiseResult {
    public var bytesRead: Int64 = 0
    public var buffer: JsValue = JsValue()
    public init(bytesRead: Int64, buffer: JsValue) {
        this.bytesRead = bytesRead
        this.buffer = buffer
    }
}

/// WritePromise result with bytesWritten and buffer
/// 对应 Bun: Return.WritePromise
public class WritePromiseResult {
    public var bytesWritten: Int64 = 0
    public var buffer: JsValue = JsValue()
    public init(bytesWritten: Int64, buffer: JsValue) {
        this.bytesWritten = bytesWritten
        this.buffer = buffer
    }
}

/// Readdir result
/// 对应 Bun: Return.Readdir
public class ReaddirResult {
    public var files: Array<String> = Array<String>()
    public var withFileTypes: Array<Dirent> = Array<Dirent>()
    public var buffers: Array<Buffer> = Array<Buffer>()
    public var tag: ReaddirTag = ReaddirTag.files

    public init(files: Array<String>) {
        this.files = files
        this.tag = ReaddirTag.files
    }

    public init(withFileTypes: Array<Dirent>) {
        this.withFileTypes = withFileTypes
        this.tag = ReaddirTag.with_file_types
    }

    public init(buffers: Array<Buffer>) {
        this.buffers = buffers
        this.tag = ReaddirTag.buffers
    }
}

public enum ReaddirTag {
    | with_file_types
    | buffers
    | files
}

/// StatOrNotFound — stat 结果或未找到
/// 对应 Bun: StatOrNotFound
public class StatOrNotFound {
    public var stats: ?Stats = None
    public var notFound: Bool = false

    public init(stats: Stats) {
        this.stats = stats
    }

    public init(notFound: Bool) {
        this.notFound = notFound
    }

    public func toJS(globalObject: JsGlobalObject): JsValue {
        if (notFound) {
            return JsValue()
        }
        if (stats != None) {
            return stats.getOrThrow().toJsValue(globalObject)
        }
        return JsValue()
    }
}

/// StringOrUndefined — 字符串结果或 undefined
/// 对应 Bun: StringOrUndefined
public class StringOrUndefined {
    public var value: ?String = None

    public init(value: String) {
        this.value = value
    }

    public init() {
        this.value = None
    }

    public func toJS(globalObject: JsGlobalObject): JsValue {
        if (value != None) {
            return JsValue(BaoString(value!))
        }
        return JsValue()
    }
}

// ============================================================================
// NodeFS — Bun 的 Node.js "fs" 模块实现
// 对应 Bun: pub const NodeFS = struct { ... }
// https://nodejs.org/api/fs.html
// ============================================================================
public class NodeFS {
    // 缓冲区：存储可能出现在返回错误信息中的临时文件路径
    // 对应 Bun: sync_error_buf
    public var syncErrorBuf: String = ""
    public var vm: ?VirtualMachine = None

    public init() {}

    // ========================================================================
    // 同步 API
    // ========================================================================

    // ========================================================================
    // access — 测试用户对指定路径的权限
    // 对应 Bun: NodeFS.access
    // ========================================================================
    public func access(args: AccessArgs, flavor: Flavor): Maybe<Unit> {
        let path = args.path.slice()
        if (path.length == 0) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "access", path: "")
        }
        let ok = System.access(path, mode: UInt32(args.mode))
        if (!ok) {
            return Maybe<Unit>.err(code: "EACCES", syscall: "access", path: path)
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // appendFile — 异步追加数据到文件
    // 对应 Bun: NodeFS.appendFile
    // ========================================================================
    public func appendFile(args: WriteFileArgs, flavor: Flavor): Maybe<Unit> {
        let data = args.data.slice()
        if (args.file.isFd) {
            var remaining = data
            while (remaining.length > 0) {
                let written = System.writeFd(args.file.fd, buffer: remaining, offset: 0, length: Int64(remaining.length), position: -1)
                if (written < 0) {
                    return Maybe<Unit>.err(code: "EIO", syscall: "write", path: "")
                }
                remaining = remaining[written.asInstanceOf<Int64>()..]
            }
            return Maybe<Unit>.success()
        }
        // 打开文件追加
        let fd = System.open(args.file.path, flags: FsOpenConstants.O_WRONLY.asInstanceOf<Int32>() | FsOpenConstants.O_APPEND.asInstanceOf<Int32>() | FsOpenConstants.O_CREAT.asInstanceOf<Int32>(), mode: args.mode)
        if (fd < 0) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "open", path: args.file.path)
        }
        var remaining = data
        while (remaining.length > 0) {
            let written = System.writeFd(fd, buffer: remaining, offset: 0, length: Int64(remaining.length), position: -1)
            if (written < 0) {
                System.close(fd)
                return Maybe<Unit>.err(code: "EIO", syscall: "write", path: args.file.path)
            }
            remaining = remaining[written.asInstanceOf<Int64>()..]
        }
        System.close(fd)
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // close — 关闭文件描述符
    // 对应 Bun: NodeFS.close
    // ========================================================================
    public func close(args: CloseArgs, flavor: Flavor): Maybe<Unit> {
        System.close(args.fd)
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // open — 打开文件
    // 对应 Bun: NodeFS.open
    // ========================================================================
    public func open(args: OpenArgs, flavor: Flavor): Maybe<FD> {
        let fd = System.open(args.path.slice(), flags: args.flags, mode: args.mode)
        if (fd < 0) {
            return Maybe<FD>.err(code: "ENOENT", syscall: "open", path: args.path.slice())
        }
        return Maybe<FD>(result: fd)
    }

    // ========================================================================
    // read — 从文件描述符读取
    // 对应 Bun: NodeFS.read
    // ========================================================================
    public func read(args: ReadArgs, flavor: Flavor): Maybe<ReadResult> {
        let bufLen = Int64(args.buffer.length)
        if (bufLen == 0 || Int64(args.length) == 0) {
            return Maybe<ReadResult>(result: ReadResult(bytesRead: 0))
        }
        let pos: Int64 = match (args.position) {
            case Some(p) => p
            case None => -1
        }
        let bytesRead = System.readFd(args.fd, buffer: args.buffer, offset: Int64(args.offset), length: Int64(args.length), position: pos)
        if (bytesRead < 0) {
            return Maybe<ReadResult>.err(code: "EIO", syscall: "read", path: "")
        }
        return Maybe<ReadResult>(result: ReadResult(bytesRead: bytesRead))
    }

    // ========================================================================
    // write — 向文件描述符写入
    // 对应 Bun: NodeFS.write
    // ========================================================================
    public func write(args: WriteArgs, flavor: Flavor): Maybe<WriteResult> {
        let data = args.buffer.slice()
        let offset = Int64(args.offset)
        let length = Int64(args.length)
        let buf = if (offset > 0) { data[offset..] } else { data }
        let toWrite = if (length < Int64(buf.length)) { buf[0..length] } else { buf }
        let pos: Int64 = match (args.position) {
            case Some(p) => p
            case None => -1
        }
        let bytesWritten = System.writeFd(args.fd, buffer: toWrite, offset: 0, length: Int64(toWrite.length), position: pos)
        if (bytesWritten < 0) {
            return Maybe<WriteResult>.err(code: "EIO", syscall: "write", path: "")
        }
        return Maybe<WriteResult>(result: WriteResult(bytesWritten: bytesWritten))
    }

    // ========================================================================
    // readFile — 读取整个文件
    // 对应 Bun: NodeFS.readFile
    // ========================================================================
    public func readFile(args: ReadFileArgs, flavor: Flavor): Maybe<Buffer> {
        let result = match (args.path.isFd) {
            case true => System.readFileFd(args.path.fd)
            case false => System.readFile(args.path.path)
        }
        if (result.length == 0 && !args.path.isFd) {
            return Maybe<Buffer>.err(code: "ENOENT", syscall: "open", path: args.path.path)
        }
        return Maybe<Buffer>(result: Buffer(bytes: result))
    }

    // ========================================================================
    // writeFile — 写入整个文件
    // 对应 Bun: NodeFS.writeFile
    // ========================================================================
    public func writeFile(args: WriteFileArgs, flavor: Flavor): Maybe<Unit> {
        let data = args.data.slice()
        if (args.file.isFd) {
            var remaining = data
            while (remaining.length > 0) {
                let written = System.writeFd(args.file.fd, buffer: remaining, offset: 0, length: Int64(remaining.length), position: -1)
                if (written < 0) {
                    return Maybe<Unit>.err(code: "EIO", syscall: "write", path: "")
                }
                remaining = remaining[written.asInstanceOf<Int64>()..]
            }
            return Maybe<Unit>.success()
        }
        System.writeFile(args.file.path, data: data)
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // stat — 获取文件状态
    // 对应 Bun: NodeFS.stat
    // ========================================================================
    public func stat(args: StatArgs, flavor: Flavor): Maybe<StatOrNotFound> {
        let result = System.stat(args.path.slice())
        if (result == None) {
            if (!args.throwIfNoEntry) {
                return Maybe<StatOrNotFound>(result: StatOrNotFound(notFound: true))
            }
            return Maybe<StatOrNotFound>.err(code: "ENOENT", syscall: "stat", path: args.path.slice())
        }
        return Maybe<StatOrNotFound>(result: StatOrNotFound(stats: result!))
    }

    // ========================================================================
    // fstat — 获取文件描述符状态
    // 对应 Bun: NodeFS.fstat
    // ========================================================================
    public func fstat(args: FstatArgs, flavor: Flavor): Maybe<Stats> {
        let result = System.fstat(args.fd)
        if (result == None) {
            return Maybe<Stats>.err(code: "EBADF", syscall: "fstat", path: "")
        }
        return Maybe<Stats>(result: result!)
    }

    // ========================================================================
    // lstat — 获取符号链接状态
    // 对应 Bun: NodeFS.lstat
    // ========================================================================
    public func lstat(args: StatArgs, flavor: Flavor): Maybe<StatOrNotFound> {
        let result = System.lstat(args.path.slice())
        if (result == None) {
            if (!args.throwIfNoEntry) {
                return Maybe<StatOrNotFound>(result: StatOrNotFound(notFound: true))
            }
            return Maybe<StatOrNotFound>.err(code: "ENOENT", syscall: "lstat", path: args.path.slice())
        }
        return Maybe<StatOrNotFound>(result: StatOrNotFound(stats: result!))
    }

    // ========================================================================
    // mkdir — 创建目录
    // 对应 Bun: NodeFS.mkdir
    // ========================================================================
    public func mkdir(args: MkdirArgs, flavor: Flavor): Maybe<StringOrUndefined> {
        if (args.path.slice().length == 0) {
            return Maybe<StringOrUndefined>.err(code: "ENOENT", syscall: "mkdir", path: "")
        }
        if (args.recursive) {
            return mkdirRecursive(args)
        }
        return mkdirNonRecursive(args)
    }

    /// mkdirNonRecursive — 非递归创建目录
    /// 对应 Bun: NodeFS.mkdirNonRecursive
    public func mkdirNonRecursive(args: MkdirArgs): Maybe<StringOrUndefined> {
        let ok = System.mkdir(args.path.slice(), mode: args.mode)
        if (!ok) {
            return Maybe<StringOrUndefined>.err(code: "EEXIST", syscall: "mkdir", path: args.path.slice())
        }
        return Maybe<StringOrUndefined>(result: StringOrUndefined())
    }

    /// mkdirRecursive — 递归创建目录
    /// 对应 Bun: NodeFS.mkdirRecursive
    public func mkdirRecursive(args: MkdirArgs): Maybe<StringOrUndefined> {
        let ok = System.mkdirRecursive(args.path.slice(), mode: args.mode)
        if (!ok) {
            return Maybe<StringOrUndefined>.err(code: "EEXIST", syscall: "mkdir", path: args.path.slice())
        }
        if (args.alwaysReturnNone) {
            return Maybe<StringOrUndefined>(result: StringOrUndefined())
        }
        return Maybe<StringOrUndefined>(result: StringOrUndefined(value: args.path.slice()))
    }

    // ========================================================================
    // mkdtemp — 创建唯一的临时目录
    // 对应 Bun: NodeFS.mkdtemp
    // ========================================================================
    public func mkdtemp(args: MkdirTempArgs, flavor: Flavor): Maybe<String> {
        let prefix = args.prefix.slice()
        let result = System.mkdtemp(prefix)
        if (result == None) {
            return Maybe<String>.err(code: "EIO", syscall: "mkdtemp", path: prefix)
        }
        return Maybe<String>(result: result!)
    }

    // ========================================================================
    // rmdir — 删除目录
    // 对应 Bun: NodeFS.rmdir
    // ========================================================================
    public func rmdir(args: RmDirArgs, flavor: Flavor): Maybe<Unit> {
        if (args.recursive) {
            let ok = System.rmRecursive(args.path.slice())
            if (!ok) {
                return Maybe<Unit>.err(code: "ENOENT", syscall: "rmdir", path: args.path.slice())
            }
            return Maybe<Unit>.success()
        }
        let ok = System.rmdir(args.path.slice())
        if (!ok) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "rmdir", path: args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // rm — 删除文件或目录
    // 对应 Bun: NodeFS.rm
    // ========================================================================
    public func rm(args: RmDirArgs, flavor: Flavor): Maybe<Unit> {
        if (args.recursive) {
            let ok = System.rmRecursive(args.path.slice())
            if (!ok) {
                if (args.force) {
                    return Maybe<Unit>.success()
                }
                return Maybe<Unit>.err(code: "ENOENT", syscall: "rm", path: args.path.slice())
            }
            return Maybe<Unit>.success()
        }
        let ok = System.unlink(args.path.slice())
        if (!ok) {
            if (args.force) {
                return Maybe<Unit>.success()
            }
            return Maybe<Unit>.err(code: "ENOENT", syscall: "rm", path: args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // unlink — 删除文件
    // 对应 Bun: NodeFS.unlink
    // ========================================================================
    public func unlink(args: UnlinkArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.unlink(args.path.slice())
        if (!ok) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "unlink", path: args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // rename — 重命名文件
    // 对应 Bun: NodeFS.rename
    // ========================================================================
    public func rename(args: RenameArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.rename(args.oldPath.slice(), to: args.newPath.slice())
        if (!ok) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "rename", path: args.oldPath.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // copyFile — 复制文件
    // 对应 Bun: NodeFS.copyFile
    // ========================================================================
    public func copyFile(args: CopyFileArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.copyFile(args.src.slice(), to: args.dest.slice())
        if (!ok) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "copyfile", path: args.src.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // link — 创建硬链接
    // 对应 Bun: NodeFS.link
    // ========================================================================
    public func link(args: LinkArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.link(args.oldPath.slice(), to: args.newPath.slice())
        if (!ok) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "link", path: args.oldPath.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // symlink — 创建符号链接
    // 对应 Bun: NodeFS.symlink
    // ========================================================================
    public func symlink(args: SymlinkArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.symlink(args.target.slice(), to: args.newPath.slice())
        if (!ok) {
            return Maybe<Unit>.err(code: "EPERM", syscall: "symlink", path: args.target.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // readlink — 读取符号链接
    // 对应 Bun: NodeFS.readlink
    // ========================================================================
    public func readlink(args: ReadlinkArgs, flavor: Flavor): Maybe<String> {
        let target = System.readlink(args.path.slice())
        if (target == None) {
            return Maybe<String>.err(code: "ENOENT", syscall: "readlink", path: args.path.slice())
        }
        return Maybe<String>(result: target!)
    }

    // ========================================================================
    // realpath — 获取真实路径
    // 对应 Bun: NodeFS.realpath
    // ========================================================================
    public func realpath(args: RealpathArgs, flavor: Flavor): Maybe<String> {
        let resolved = System.realpath(args.path.slice())
        if (resolved == None) {
            return Maybe<String>.err(code: "ENOENT", syscall: "realpath", path: args.path.slice())
        }
        return Maybe<String>(result: resolved!)
    }

    /// realpathNonNative — 非原生 realpath 实现
    /// 对应 Bun: NodeFS.realpathNonNative
    public func realpathNonNative(args: RealpathArgs, flavor: Flavor): Maybe<String> {
        return realpath(args, flavor: flavor)
    }

    /// realpathNative — 原生 realpath
    /// 对应 Bun: NodeFS.realpathNative
    public func realpathNative(args: RealpathArgs, flavor: Flavor): Maybe<String> {
        return realpath(args, flavor: flavor)
    }

    // ========================================================================
    // chmod — 修改文件权限
    // 对应 Bun: NodeFS.chmod
    // ========================================================================
    public func chmod(args: ChmodArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.chmod(args.path.slice(), mode: args.mode)
        if (!ok) {
            return Maybe<Unit>.err(code: "EPERM", syscall: "chmod", path: args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // fchmod — 修改文件描述符权限
    // 对应 Bun: NodeFS.fchmod
    // ========================================================================
    public func fchmod(args: FChmodArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.fchmod(args.fd, mode: args.mode)
        if (!ok) {
            return Maybe<Unit>.err(code: "EBADF", syscall: "fchmod", path: "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // chown — 修改文件所有者
    // 对应 Bun: NodeFS.chown
    // ========================================================================
    public func chown(args: ChownArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.chown(args.path.slice(), uid: args.uid, gid: args.gid)
        if (!ok) {
            return Maybe<Unit>.err(code: "EPERM", syscall: "chown", path: args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // fchown — 修改文件描述符所有者
    // 对应 Bun: NodeFS.fchown
    // ========================================================================
    public func fchown(args: FchownArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.fchown(args.fd, uid: args.uid, gid: args.gid)
        if (!ok) {
            return Maybe<Unit>.err(code: "EBADF", syscall: "fchown", path: "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // lchmod — 修改符号链接权限
    // 对应 Bun: NodeFS.lchmod
    // ========================================================================
    public func lchmod(args: ChmodArgs, flavor: Flavor): Maybe<Unit> {
        // lchmod is typically not supported on most platforms
        return Maybe<Unit>.err(code: "ENOTSUP", syscall: "lchmod", path: args.path.slice())
    }

    // ========================================================================
    // lchown — 修改符号链接所有者
    // 对应 Bun: NodeFS.lchown
    // ========================================================================
    public func lchown(args: ChownArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.lchown(args.path.slice(), uid: args.uid, gid: args.gid)
        if (!ok) {
            return Maybe<Unit>.err(code: "EPERM", syscall: "lchown", path: args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // utimes — 修改文件时间戳
    // 对应 Bun: NodeFS.utimes
    // ========================================================================
    public func utimes(args: UtimesArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.utimes(args.path.slice(), atime: args.atime, mtime: args.mtime)
        if (!ok) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "utime", path: args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // lutimes — 修改符号链接时间戳
    // 对应 Bun: NodeFS.lutimes
    // ========================================================================
    public func lutimes(args: UtimesArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.lutimes(args.path.slice(), atime: args.atime, mtime: args.mtime)
        if (!ok) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "utime", path: args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // futimes — 修改文件描述符时间戳
    // 对应 Bun: NodeFS.futimes
    // ========================================================================
    public func futimes(args: FutimesArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.futimes(args.fd, atime: args.atime, mtime: args.mtime)
        if (!ok) {
            return Maybe<Unit>.err(code: "EBADF", syscall: "futime", path: "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // truncate — 截断文件
    // 对应 Bun: NodeFS.truncate
    // ========================================================================
    public func truncate(args: TruncateArgs, flavor: Flavor): Maybe<Unit> {
        if (args.path.isFd) {
            return ftruncate(FTruncateArgs(fd: args.path.fd, len: args.len), flavor: flavor)
        }
        let ok = System.truncate(args.path.path, length: args.len)
        if (!ok) {
            return Maybe<Unit>.err(code: "ENOENT", syscall: "truncate", path: args.path.path)
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // ftruncate — 截断文件描述符
    // 对应 Bun: NodeFS.ftruncate
    // ========================================================================
    public func ftruncate(args: FTruncateArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.ftruncate(args.fd, length: args.len)
        if (!ok) {
            return Maybe<Unit>.err(code: "EBADF", syscall: "ftruncate", path: "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // fdatasync — 文件数据同步
    // 对应 Bun: NodeFS.fdatasync
    // ========================================================================
    public func fdatasync(args: FdataSyncArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.fdatasync(args.fd)
        if (!ok) {
            return Maybe<Unit>.err(code: "EBADF", syscall: "fdatasync", path: "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // fsync — 文件同步
    // 对应 Bun: NodeFS.fsync
    // ========================================================================
    public func fsync(args: FsyncArgs, flavor: Flavor): Maybe<Unit> {
        let ok = System.fsync(args.fd)
        if (!ok) {
            return Maybe<Unit>.err(code: "EBADF", syscall: "fsync", path: "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // exists — 检查文件是否存在
    // 对应 Bun: NodeFS.exists
    // ========================================================================
    public func exists(args: ExistsArgs, flavor: Flavor): Maybe<Bool> {
        if (args.path == None) {
            return Maybe<Bool>(result: false)
        }
        let path = args.path.getOrThrow().slice()
        return Maybe<Bool>(result: System.access(path, mode: 0))
    }

    // ========================================================================
    // readdir — 读取目录
    // 对应 Bun: NodeFS.readdir
    // ========================================================================
    public func readdir(args: ReaddirArgs, flavor: Flavor): Maybe<ReaddirResult> {
        if (args.withFileTypes) {
            let entries = System.readdirWithTypes(args.path.slice())
            return Maybe<ReaddirResult>(result: ReaddirResult(withFileTypes: entries))
        }
        let entries = System.readdir(args.path.slice())
        return Maybe<ReaddirResult>(result: ReaddirResult(files: entries))
    }

    // ========================================================================
    // statfs — 获取文件系统信息
    // 对应 Bun: NodeFS.statfs
    // ========================================================================
    public func statfs(args: StatFSArgs, flavor: Flavor): Maybe<StatFS> {
        let result = System.statfs(args.path.slice())
        if (result == None) {
            return Maybe<StatFS>.err(code: "ENOENT", syscall: "statfs", path: args.path.slice())
        }
        return Maybe<StatFS>(result: result!)
    }

    // ========================================================================
    // watch — 监视文件变化
    // 对应 Bun: NodeFS.watch
    // ========================================================================
    public func watch(path: String, options: JsValue, globalObject: JsGlobalObject): Maybe<JsValue> {
        let watcher = FsWatcher(path: path)
        watcher.start()
        return Maybe<JsValue>(result: watcher.toJsValue(globalObject))
    }

    // ========================================================================
    // watchFile — 监视文件状态变化
    // 对应 Bun: NodeFS.watchFile
    // ========================================================================
    public func watchFile(args: StatArgs, globalObject: JsGlobalObject): Maybe<JsValue> {
        let watcher = StatWatcher(path: args.path.slice())
        watcher.start()
        return Maybe<JsValue>(result: watcher.toJsValue(globalObject))
    }

    // ========================================================================
    // cp — 复制文件或目录
    // 对应 Bun: NodeFS.cp
    // ========================================================================
    public func cp(src: String, dest: String, recursive: Bool, force: Bool, errorOnExist: Bool): Maybe<Unit> {
        if (recursive) {
            let ok = System.cpRecursive(src, to: dest, force: force)
            if (!ok) {
                return Maybe<Unit>.err(code: "ENOENT", syscall: "copyfile", path: src)
            }
            return Maybe<Unit>.success()
        }
        let ok = System.copyFile(src, to: dest)
        if (!ok) {
            if (!force) {
                return Maybe<Unit>.success()
            }
            return Maybe<Unit>.err(code: "ENOENT", syscall: "copyfile", path: src)
        }
        return Maybe<Unit>.success()
    }
}

// ============================================================================
// FsWatcher — 文件系统监视器（简化版）
// 对应 Bun: Watcher
// ============================================================================
public class FsWatcher {
    public var path: String = ""
    public var active: Bool = false

    public init(path: String) {
        this.path = path
    }

    public func start(): Unit {
        active = true
    }

    public func close(): Unit {
        active = false
    }

    public func toJsValue(globalObject: JsGlobalObject): JsValue {
        let obj = JsObject(globalObject)
        obj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
            this.close()
            JsValue()
        }))
        return JsValue(obj)
    }
}

// ============================================================================
// StatWatcher — 文件状态监视器
// 对应 Bun: StatWatcher
// ============================================================================
public class StatWatcher {
    public var path: String = ""
    public var active: Bool = false
    public var interval: Int64 = 5007  // 默认间隔（毫秒）

    public init(path: String) {
        this.path = path
    }

    public func start(): Unit {
        active = true
    }

    public func stop(): Unit {
        active = false
    }

    public func toJsValue(globalObject: JsGlobalObject): JsValue {
        let obj = JsObject(globalObject)
        obj.set("stop", JsValue.nativeFunction(JsNativeFunction("stop") { _ =>
            this.stop()
            JsValue()
        }))
        return JsValue(obj)
    }
}

// ============================================================================
// Async — 异步文件系统操作
// 对应 Bun: pub const Async = struct { ... }
// 所有异步文件系统操作在线程池中运行
// ============================================================================
public class Async {
    // ========================================================================
    // 异步辅助：每个异步操作创建一个 Promise，在工作线程执行，然后在 JS 线程 resolve
    // 对应 Bun: NewAsyncFSTask
    // ========================================================================

    /// 异步 access
    /// 对应 Bun: Async.access
    public static func access(globalObject: JsGlobalObject, nodeFs: NodeFS, args: AccessArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.access(args, flavor: Flavor.async)
        }
    }

    /// 异步 appendFile
    /// 对应 Bun: Async.appendFile
    public static func appendFile(globalObject: JsGlobalObject, nodeFs: NodeFS, args: WriteFileArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.appendFile(args, flavor: Flavor.async)
        }
    }

    /// 异步 chmod
    /// 对应 Bun: Async.chmod
    public static func chmod(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ChmodArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.chmod(args, flavor: Flavor.async)
        }
    }

    /// 异步 chown
    /// 对应 Bun: Async.chown
    public static func chown(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ChownArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.chown(args, flavor: Flavor.async)
        }
    }

    /// 异步 close
    /// 对应 Bun: Async.close
    public static func close(globalObject: JsGlobalObject, nodeFs: NodeFS, args: CloseArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.close(args, flavor: Flavor.async)
        }
    }

    /// 异步 copyFile
    /// 对应 Bun: Async.copyFile
    public static func copyFile(globalObject: JsGlobalObject, nodeFs: NodeFS, args: CopyFileArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.copyFile(args, flavor: Flavor.async)
        }
    }

    /// 异步 exists
    /// 对应 Bun: Async.exists
    public static func exists(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ExistsArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.exists(args, flavor: Flavor.async)
        }
    }

    /// 异步 fchmod
    /// 对应 Bun: Async.fchmod
    public static func fchmod(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FChmodArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fchmod(args, flavor: Flavor.async)
        }
    }

    /// 异步 fchown
    /// 对应 Bun: Async.fchown
    public static func fchown(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FchownArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fchown(args, flavor: Flavor.async)
        }
    }

    /// 异步 fdatasync
    /// 对应 Bun: Async.fdatasync
    public static func fdatasync(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FdataSyncArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fdatasync(args, flavor: Flavor.async)
        }
    }

    /// 异步 fstat
    /// 对应 Bun: Async.fstat
    public static func fstat(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FstatArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fstat(args, flavor: Flavor.async)
        }
    }

    /// 异步 fsync
    /// 对应 Bun: Async.fsync
    public static func fsync(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FsyncArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fsync(args, flavor: Flavor.async)
        }
    }

    /// 异步 ftruncate
    /// 对应 Bun: Async.ftruncate
    public static func ftruncate(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FTruncateArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.ftruncate(args, flavor: Flavor.async)
        }
    }

    /// 异步 futimes
    /// 对应 Bun: Async.futimes
    public static func futimes(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FutimesArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.futimes(args, flavor: Flavor.async)
        }
    }

    /// 异步 lchmod
    /// 对应 Bun: Async.lchmod
    public static func lchmod(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ChmodArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.lchmod(args, flavor: Flavor.async)
        }
    }

    /// 异步 lchown
    /// 对应 Bun: Async.lchown
    public static func lchown(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ChownArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.lchown(args, flavor: Flavor.async)
        }
    }

    /// 异步 link
    /// 对应 Bun: Async.link
    public static func link(globalObject: JsGlobalObject, nodeFs: NodeFS, args: LinkArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.link(args, flavor: Flavor.async)
        }
    }

    /// 异步 lstat
    /// 对应 Bun: Async.lstat
    public static func lstat(globalObject: JsGlobalObject, nodeFs: NodeFS, args: StatArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.lstat(args, flavor: Flavor.async)
        }
    }

    /// 异步 lutimes
    /// 对应 Bun: Async.lutimes
    public static func lutimes(globalObject: JsGlobalObject, nodeFs: NodeFS, args: UtimesArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.lutimes(args, flavor: Flavor.async)
        }
    }

    /// 异步 mkdir
    /// 对应 Bun: Async.mkdir
    public static func mkdir(globalObject: JsGlobalObject, nodeFs: NodeFS, args: MkdirArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.mkdir(args, flavor: Flavor.async)
        }
    }

    /// 异步 mkdtemp
    /// 对应 Bun: Async.mkdtemp
    public static func mkdtemp(globalObject: JsGlobalObject, nodeFs: NodeFS, args: MkdirTempArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.mkdtemp(args, flavor: Flavor.async)
        }
    }

    /// 异步 open
    /// 对应 Bun: Async.open
    public static func open(globalObject: JsGlobalObject, nodeFs: NodeFS, args: OpenArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.open(args, flavor: Flavor.async)
        }
    }

    /// 异步 read
    /// 对应 Bun: Async.read
    public static func read(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ReadArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.read(args, flavor: Flavor.async)
        }
    }

    /// 异步 readdir
    /// 对应 Bun: Async.readdir
    public static func readdir(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ReaddirArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.readdir(args, flavor: Flavor.async)
        }
    }

    /// 异步 readFile
    /// 对应 Bun: Async.readFile
    public static func readFile(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ReadFileArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.readFile(args, flavor: Flavor.async)
        }
    }

    /// 异步 readlink
    /// 对应 Bun: Async.readlink
    public static func readlink(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ReadlinkArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.readlink(args, flavor: Flavor.async)
        }
    }

    /// 异步 realpath
    /// 对应 Bun: Async.realpath
    public static func realpath(globalObject: JsGlobalObject, nodeFs: NodeFS, args: RealpathArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.realpath(args, flavor: Flavor.async)
        }
    }

    /// 异步 rename
    /// 对应 Bun: Async.rename
    public static func rename(globalObject: JsGlobalObject, nodeFs: NodeFS, args: RenameArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.rename(args, flavor: Flavor.async)
        }
    }

    /// 异步 rm
    /// 对应 Bun: Async.rm
    public static func rm(globalObject: JsGlobalObject, nodeFs: NodeFS, args: RmDirArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.rm(args, flavor: Flavor.async)
        }
    }

    /// 异步 rmdir
    /// 对应 Bun: Async.rmdir
    public static func rmdir(globalObject: JsGlobalObject, nodeFs: NodeFS, args: RmDirArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.rmdir(args, flavor: Flavor.async)
        }
    }

    /// 异步 stat
    /// 对应 Bun: Async.stat
    public static func stat(globalObject: JsGlobalObject, nodeFs: NodeFS, args: StatArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.stat(args, flavor: Flavor.async)
        }
    }

    /// 异步 symlink
    /// 对应 Bun: Async.symlink
    public static func symlink(globalObject: JsGlobalObject, nodeFs: NodeFS, args: SymlinkArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.symlink(args, flavor: Flavor.async)
        }
    }

    /// 异步 truncate
    /// 对应 Bun: Async.truncate
    public static func truncate(globalObject: JsGlobalObject, nodeFs: NodeFS, args: TruncateArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.truncate(args, flavor: Flavor.async)
        }
    }

    /// 异步 unlink
    /// 对应 Bun: Async.unlink
    public static func unlink(globalObject: JsGlobalObject, nodeFs: NodeFS, args: UnlinkArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.unlink(args, flavor: Flavor.async)
        }
    }

    /// 异步 utimes
    /// 对应 Bun: Async.utimes
    public static func utimes(globalObject: JsGlobalObject, nodeFs: NodeFS, args: UtimesArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.utimes(args, flavor: Flavor.async)
        }
    }

    /// 异步 write
    /// 对应 Bun: Async.write
    public static func write(globalObject: JsGlobalObject, nodeFs: NodeFS, args: WriteArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.write(args, flavor: Flavor.async)
        }
    }

    /// 异步 writeFile
    /// 对应 Bun: Async.writeFile
    public static func writeFile(globalObject: JsGlobalObject, nodeFs: NodeFS, args: WriteFileArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.writeFile(args, flavor: Flavor.async)
        }
    }

    /// 异步 statfs
    /// 对应 Bun: Async.statfs
    public static func statfs(globalObject: JsGlobalObject, nodeFs: NodeFS, args: StatFSArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.statfs(args, flavor: Flavor.async)
        }
    }
}

// ============================================================================
// WorkPool — 线程池，执行异步任务
// 对应 Bun: jsc.WorkPool
// ============================================================================
public class WorkPool {
    /// 在工作线程执行任务并返回 Promise
    public static func schedulePromise<T>(globalObject: JsGlobalObject, work: () -> Maybe<T>): JsValue {
        let promise = JsPromise(globalObject)
        // 在 Cangjie 中使用协程模拟线程池
        spawn {
            let result = work()
            // 在 JS 线程 resolve/reject
            promise.resolve(result.toJS(globalObject))
        }
        return promise.toJsValue()
    }
}

// ============================================================================
// mkdirp — 递归创建目录（内部导出函数）
// 对应 Bun: Bun__mkdirp
// ============================================================================
public func mkdirp(path: String): Bool {
    return System.mkdirRecursive(path, mode: 0o777.asInstanceOf<Mode>())
}
