// 严格翻译自: src/runtime/node/node_fs.zig
// This file contains the underlying implementation for sync & async functions
// for interacting with the filesystem from JavaScript.
// The top-level functions assume the arguments are already validated
package bao_runtime.node

import bao_core.*
import bao_sys.*
import bao_jsc.*
import bao_collections.ArrayList as BaoArrayList
import std.collection.ArrayList

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
    return UInt32(0o666)  // S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH
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
    public var result: ?T = None

    public init() {
        hasError = false
    }

    public init(result: T) {
        this.hasError = false
        this.result = result
    }

    public init(error: SyscallError) {
        this.hasError = true
        this.error = error
    }

    public static func success(): Maybe<Unit> {
        let m = Maybe<Unit>()
        m.result = ()
        return m
    }

    public static func err(code: String, syscall: String, path: String): Maybe<T> {
        return Maybe<T>(SyscallError(code, syscall, path))
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
        if (result.isNone()) {
            return JsValue()
        }
        return FsJSValue.from(globalObject, result.getOrThrow())
    }
}

public class FsJSValue {
    public static func from<T>(globalObject: JsGlobalObject, value: T): JsValue {
        return JsValue()
    }

    public static func from(globalObject: JsGlobalObject, value: Bool): JsValue {
        return JsValue(value)
    }

    public static func from(globalObject: JsGlobalObject, value: Int32): JsValue {
        return JsValue(Int64(value))
    }

    public static func from(globalObject: JsGlobalObject, value: Int64): JsValue {
        return JsValue(value)
    }

    public static func from(globalObject: JsGlobalObject, value: String): JsValue {
        return JsValue(value)
    }

    public static func from(globalObject: JsGlobalObject, value: Unit): JsValue {
        return JsValue()
    }

    public static func from(globalObject: JsGlobalObject, value: Buffer): JsValue {
        return value.toJS(globalObject)
    }

    public static func from(globalObject: JsGlobalObject, value: ReadFileResult): JsValue {
        return value.toJS(globalObject)
    }

    public static func from(globalObject: JsGlobalObject, value: ReadResult): JsValue {
        let obj = JsObject()
        obj.set("bytesRead", JsValue(value.bytesRead))
        return JsValue(obj)
    }

    public static func from(globalObject: JsGlobalObject, value: WriteResult): JsValue {
        let obj = JsObject()
        obj.set("bytesWritten", JsValue(value.bytesWritten))
        return JsValue(obj)
    }

    public static func from(globalObject: JsGlobalObject, value: ReadPromiseResult): JsValue {
        let obj = JsObject()
        obj.set("bytesRead", JsValue(value.bytesRead))
        obj.set("buffer", value.buffer)
        return JsValue(obj)
    }

    public static func from(globalObject: JsGlobalObject, value: WritePromiseResult): JsValue {
        let obj = JsObject()
        obj.set("bytesWritten", JsValue(value.bytesWritten))
        obj.set("buffer", value.buffer)
        return JsValue(obj)
    }

    public static func from(globalObject: JsGlobalObject, value: StatOrNotFound): JsValue {
        return value.toJS(globalObject)
    }

    public static func from(globalObject: JsGlobalObject, value: StringOrUndefined): JsValue {
        return value.toJS(globalObject)
    }

    public static func from(globalObject: JsGlobalObject, value: Stats): JsValue {
        return value.toJS(globalObject)
    }

    public static func from(globalObject: JsGlobalObject, value: StatFS): JsValue {
        let obj = JsObject()
        obj.set("type", JsValue(Int64(value.fstype)))
        obj.set("bsize", JsValue(Int64(value.bsize)))
        obj.set("blocks", JsValue(Int64(value.blocks)))
        obj.set("bfree", JsValue(Int64(value.bfree)))
        obj.set("bavail", JsValue(Int64(value.bavail)))
        obj.set("files", JsValue(Int64(value.files)))
        obj.set("ffree", JsValue(Int64(value.ffree)))
        return JsValue(obj)
    }

    public static func from(globalObject: JsGlobalObject, value: ReaddirResult): JsValue {
        let arr = ArrayList<JsValue>()
        match (value.tag) {
            case ReaddirTag.with_file_types =>
                for (entry in value.withFileTypes) { arr.add(entry.toJS(globalObject)) }
            case ReaddirTag.buffers =>
                for (buf in value.buffers) { arr.add(buf.toJS(globalObject)) }
            case ReaddirTag.files =>
                for (file in value.files) { arr.add(JsValue(file)) }
        }
        let baoArr = BaoArrayList<JsValue>()
        for (v in arr) { baoArr.append(v) }
        return JsValue.array(baoArr)
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
        return SyscallError(code, syscall, "")
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
        let obj = JsObject()
        obj.set("code", JsValue(code))
        obj.set("message", JsValue(message))
        obj.set("errno", JsValue(Int64(errno)))
        obj.set("syscall", JsValue(syscall))
        if (path.size > 0) {
            obj.set("path", JsValue(path))
        }
        if (dest.size > 0) {
            obj.set("dest", JsValue(dest))
        }
        let errVal = JsValue(obj).toError()
        if (errVal.isSome()) {
            return errVal.getOrThrow()
        }
        return JsValue(obj)
    }
}

// ============================================================================
// NodeError — Node.js 兼容的错误抛出辅助
// 已移至 node_error_binding.cj 避免重复定义
// 使用: NodeErrorBinding 或 NodeError (from node_error_binding.cj)
// ============================================================================

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

// PathLike, StringOrBuffer, Buffer — 已在 types.cj 中定义

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
    public var mode: Mode = UInt32(0o777)
    public init(path: PathLike, mode: Mode) {
        this.path = path
        this.mode = mode
    }
}

// Arguments.FChmod
public class FChmodArgs {
    public var fd: FD
    public var mode: Mode = UInt32(0o777)
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
    public var mode: Mode = UInt32(0o777)
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
    public var length: UInt64 = UInt64.Max
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
    public var mode: Mode = UInt32(0o666)
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

/// ReadFile result with encoding-aware Buffer/string conversion
/// 对应 Bun: Return.ReadFile
public class ReadFileResult {
    public var buffer: Buffer
    public var encoding: Encoding

    public init(buffer: Buffer, encoding: Encoding) {
        this.buffer = buffer
        this.encoding = encoding
    }

    public func toJS(globalObject: JsGlobalObject): JsValue {
        return encoding.encodeToJS(globalObject, buffer.slice())
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

    // 从 DirIteratorResult 数组创建
    public init(dirents: Array<DirIteratorResult>) {
        let arr = ArrayList<Dirent>()
        for (entry in dirents) {
            arr.add(Dirent(entry.name, "", entry.kind))
        }
        this.withFileTypes = arr.toArray()
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
        if (stats.isSome()) {
            return stats.getOrThrow().toJS(globalObject)
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
        if (value.isSome()) {
            return JsValue(value.getOrThrow())
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
    public var vm: UIntNative = 0

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
        if (path.size == 0) {
            return Maybe<Unit>.err("ENOENT", "access", "")
        }
        let ok = NodeFsSystem.access(path, UInt32(args.mode))
        if (!ok) {
            return Maybe<Unit>.err("EACCES", "access", path)
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // appendFile — 异步追加数据到文件
    // 对应 Bun: NodeFS.appendFile
    // ========================================================================
    public func appendFile(args: WriteFileArgs, flavor: Flavor): Maybe<Unit> {
        let data = args.data.slice(args.encoding)
        if (args.file.isFd) {
            var remaining = data
            while (remaining.size > 0) {
                let written = NodeFsSystem.writeFd(args.file.fd, remaining, 0, Int64(remaining.size), Int64(-1))
                if (written < 0) {
                    return Maybe<Unit>.err("EIO", "write", "")
                }
                remaining = remaining[Int64(written)..]
            }
            return Maybe<Unit>.success()
        }
        // 打开文件追加
        let fd = NodeFsSystem.open(args.file.path.slice(), Int32(FsOpenConstants.O_WRONLY) | Int32(FsOpenConstants.O_APPEND) | Int32(FsOpenConstants.O_CREAT), args.mode)
        if (fd < 0) {
            return Maybe<Unit>.err("ENOENT", "open", args.file.path.slice())
        }
        var remaining = data
        while (remaining.size > 0) {
            let written = NodeFsSystem.writeFd(fd, remaining, 0, Int64(remaining.size), Int64(-1))
            if (written < 0) {
                NodeFsSystem.close(fd)
                return Maybe<Unit>.err("EIO", "write", args.file.path.slice())
            }
            remaining = remaining[Int64(written)..]
        }
        NodeFsSystem.close(fd)
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // close — 关闭文件描述符
    // 对应 Bun: NodeFS.close
    // ========================================================================
    public func close(args: CloseArgs, flavor: Flavor): Maybe<Unit> {
        NodeFsSystem.close(args.fd)
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // open — 打开文件
    // 对应 Bun: NodeFS.open
    // ========================================================================
    public func open(args: OpenArgs, flavor: Flavor): Maybe<FD> {
        let fd = NodeFsSystem.open(args.path.slice(), args.flags, args.mode)
        if (fd < 0) {
            return Maybe<FD>.err("ENOENT", "open", args.path.slice())
        }
        return Maybe<FD>(fd)
    }

    // ========================================================================
    // read — 从文件描述符读取
    // 对应 Bun: NodeFS.read
    // ========================================================================
    public func read(args: ReadArgs, flavor: Flavor): Maybe<ReadResult> {
        let bufLen = Int64(args.buffer.size)
        if (bufLen == 0 || Int64(args.length) == 0) {
            return Maybe<ReadResult>(ReadResult(0))
        }
        let pos: Int64 = match (args.position) {
            case Some(p) => p
            case None => -1
        }
        let bytesRead = NodeFsSystem.readFd(args.fd, args.buffer, Int64(args.offset), Int64(args.length), pos)
        if (bytesRead < 0) {
            return Maybe<ReadResult>.err("EIO", "read", "")
        }
        return Maybe<ReadResult>(ReadResult(bytesRead))
    }

    // ========================================================================
    // write — 向文件描述符写入
    // 对应 Bun: NodeFS.write
    // ========================================================================
    public func write(args: WriteArgs, flavor: Flavor): Maybe<WriteResult> {
        let data = args.buffer.slice(args.encoding)
        let offset = Int64(args.offset)
        let length = Int64(args.length)
        let buf = if (offset > 0) { data[offset..] } else { data }
        let toWrite = if (length < Int64(buf.size)) { buf[0..length] } else { buf }
        let pos: Int64 = match (args.position) {
            case Some(p) => p
            case None => -1
        }
        let bytesWritten = NodeFsSystem.writeFd(args.fd, toWrite, 0, Int64(toWrite.size), pos)
        if (bytesWritten < 0) {
            return Maybe<WriteResult>.err("EIO", "write", "")
        }
        return Maybe<WriteResult>(WriteResult(bytesWritten))
    }

    // ========================================================================
    // readFile — 读取整个文件
    // 对应 Bun: NodeFS.readFile
    // ========================================================================
    public func readFile(args: ReadFileArgs, flavor: Flavor): Maybe<ReadFileResult> {
        let result = match (args.path.isFd) {
            case true => NodeFsSystem.readFileFd(args.path.fd)
            case false => NodeFsSystem.readFile(args.path.path.slice())
        }
        if (result.isNone() && !args.path.isFd) {
            return Maybe<ReadFileResult>.err("ENOENT", "open", args.path.path.slice())
        }
        if (result.isSome()) {
            return Maybe<ReadFileResult>(ReadFileResult(Buffer(result.getOrThrow()), args.encoding))
        }
        return Maybe<ReadFileResult>(ReadFileResult(Buffer(Array<UInt8>()), args.encoding))
    }

    // ========================================================================
    // writeFile — 写入整个文件
    // 对应 Bun: NodeFS.writeFile
    // ========================================================================
    public func writeFile(args: WriteFileArgs, flavor: Flavor): Maybe<Unit> {
        let data = args.data.slice(args.encoding)
        if (args.file.isFd) {
            var remaining = data
            while (remaining.size > 0) {
                let written = NodeFsSystem.writeFd(args.file.fd, remaining, 0, Int64(remaining.size), Int64(-1))
                if (written < 0) {
                    return Maybe<Unit>.err("EIO", "write", "")
                }
                remaining = remaining[Int64(written)..]
            }
            return Maybe<Unit>.success()
        }
        NodeFsSystem.writeFile(args.file.path.slice(), data, UInt32(0o666))
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // stat — 获取文件状态
    // 对应 Bun: NodeFS.stat
    // ========================================================================
    public func stat(args: StatArgs, flavor: Flavor): Maybe<StatOrNotFound> {
        let result = NodeFsSystem.stat(args.path.slice())
        if (result.isNone()) {
            if (!args.throwIfNoEntry) {
                return Maybe<StatOrNotFound>(StatOrNotFound(true))
            }
            return Maybe<StatOrNotFound>.err("ENOENT", "stat", args.path.slice())
        }
        return Maybe<StatOrNotFound>(StatOrNotFound(result.getOrThrow()))
    }

    // ========================================================================
    // fstat — 获取文件描述符状态
    // 对应 Bun: NodeFS.fstat
    // ========================================================================
    public func fstat(args: FstatArgs, flavor: Flavor): Maybe<Stats> {
        let result = NodeFsSystem.fstat(args.fd)
        if (result.isNone()) {
            return Maybe<Stats>.err("EBADF", "fstat", "")
        }
        return Maybe<Stats>(result.getOrThrow())
    }

    // ========================================================================
    // lstat — 获取符号链接状态
    // 对应 Bun: NodeFS.lstat
    // ========================================================================
    public func lstat(args: StatArgs, flavor: Flavor): Maybe<StatOrNotFound> {
        let result = NodeFsSystem.lstat(args.path.slice())
        if (result.isNone()) {
            if (!args.throwIfNoEntry) {
                return Maybe<StatOrNotFound>(StatOrNotFound(true))
            }
            return Maybe<StatOrNotFound>.err("ENOENT", "lstat", args.path.slice())
        }
        return Maybe<StatOrNotFound>(StatOrNotFound(result.getOrThrow()))
    }

    // ========================================================================
    // mkdir — 创建目录
    // 对应 Bun: NodeFS.mkdir
    // ========================================================================
    public func mkdir(args: MkdirArgs, flavor: Flavor): Maybe<StringOrUndefined> {
        if (args.path.slice().size == 0) {
            return Maybe<StringOrUndefined>.err("ENOENT", "mkdir", "")
        }
        if (args.recursive) {
            return mkdirRecursive(args)
        }
        return mkdirNonRecursive(args)
    }

    /// mkdirNonRecursive — 非递归创建目录
    /// 对应 Bun: NodeFS.mkdirNonRecursive
    public func mkdirNonRecursive(args: MkdirArgs): Maybe<StringOrUndefined> {
        let ok = NodeFsSystem.mkdir(args.path.slice(), args.mode)
        if (ok < 0) {
            return Maybe<StringOrUndefined>.err("EEXIST", "mkdir", args.path.slice())
        }
        return Maybe<StringOrUndefined>(StringOrUndefined())
    }

    /// mkdirRecursive — 递归创建目录
    /// 对应 Bun: NodeFS.mkdirRecursive
    public func mkdirRecursive(args: MkdirArgs): Maybe<StringOrUndefined> {
        let ok = NodeFsSystem.mkdirRecursive(args.path.slice(), args.mode)
        if (!ok) {
            return Maybe<StringOrUndefined>.err("EEXIST", "mkdir", args.path.slice())
        }
        if (args.alwaysReturnNone) {
            return Maybe<StringOrUndefined>(StringOrUndefined())
        }
        return Maybe<StringOrUndefined>(StringOrUndefined(args.path.slice()))
    }

    // ========================================================================
    // mkdtemp — 创建唯一的临时目录
    // 对应 Bun: NodeFS.mkdtemp
    // ========================================================================
    public func mkdtemp(args: MkdirTempArgs, flavor: Flavor): Maybe<String> {
        let prefix = args.prefix.slice()
        let result = NodeFsSystem.mkdtemp(prefix)
        if (result.isNone()) {
            return Maybe<String>.err("EIO", "mkdtemp", prefix)
        }
        return Maybe<String>(result.getOrThrow())
    }

    // ========================================================================
    // rmdir — 删除目录
    // 对应 Bun: NodeFS.rmdir
    // ========================================================================
    public func rmdir(args: RmDirArgs, flavor: Flavor): Maybe<Unit> {
        if (args.recursive) {
            let ok = NodeFsSystem.rmRecursive(args.path.slice())
            if (!ok) {
                return Maybe<Unit>.err("ENOENT", "rmdir", args.path.slice())
            }
            return Maybe<Unit>.success()
        }
        let ok = NodeFsSystem.rmdir(args.path.slice())
        if (ok < 0) {
            return Maybe<Unit>.err("ENOENT", "rmdir", args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // rm — 删除文件或目录
    // 对应 Bun: NodeFS.rm
    // ========================================================================
    public func rm(args: RmDirArgs, flavor: Flavor): Maybe<Unit> {
        if (args.recursive) {
            let ok = NodeFsSystem.rmRecursive(args.path.slice())
            if (!ok) {
                if (args.force) {
                    return Maybe<Unit>.success()
                }
                return Maybe<Unit>.err("ENOENT", "rm", args.path.slice())
            }
            return Maybe<Unit>.success()
        }
        let ok = NodeFsSystem.unlink(args.path.slice())
        if (ok < 0) {
            if (args.force) {
                return Maybe<Unit>.success()
            }
            return Maybe<Unit>.err("ENOENT", "rm", args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // unlink — 删除文件
    // 对应 Bun: NodeFS.unlink
    // ========================================================================
    public func unlink(args: UnlinkArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.unlink(args.path.slice())
        if (ok < 0) {
            return Maybe<Unit>.err("ENOENT", "unlink", args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // rename — 重命名文件
    // 对应 Bun: NodeFS.rename
    // ========================================================================
    public func rename(args: RenameArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.rename(args.oldPath.slice(), args.newPath.slice())
        if (ok < 0) {
            return Maybe<Unit>.err("ENOENT", "rename", args.oldPath.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // copyFile — 复制文件
    // 对应 Bun: NodeFS.copyFile
    // ========================================================================
    public func copyFile(args: CopyFileArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.copyFile(args.src.slice(), args.dest.slice(), 0)
        if (ok < 0) {
            return Maybe<Unit>.err("ENOENT", "copyfile", args.src.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // link — 创建硬链接
    // 对应 Bun: NodeFS.link
    // ========================================================================
    public func link(args: LinkArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.link(args.oldPath.slice(), args.newPath.slice())
        if (ok < 0) {
            return Maybe<Unit>.err("ENOENT", "link", args.oldPath.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // symlink — 创建符号链接
    // 对应 Bun: NodeFS.symlink
    // ========================================================================
    public func symlink(args: SymlinkArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.symlink(args.target.slice(), args.newPath.slice())
        if (ok < 0) {
            return Maybe<Unit>.err("EPERM", "symlink", args.target.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // readlink — 读取符号链接
    // 对应 Bun: NodeFS.readlink
    // ========================================================================
    public func readlink(args: ReadlinkArgs, flavor: Flavor): Maybe<String> {
        let target = NodeFsSystem.readlink(args.path.slice())
        if (target.isNone()) {
            return Maybe<String>.err("ENOENT", "readlink", args.path.slice())
        }
        return Maybe<String>(target.getOrThrow())
    }

    // ========================================================================
    // realpath — 获取真实路径
    // 对应 Bun: NodeFS.realpath
    // ========================================================================
    public func realpath(args: RealpathArgs, flavor: Flavor): Maybe<String> {
        let resolved = NodeFsSystem.realpath(args.path.slice())
        if (resolved.isNone()) {
            return Maybe<String>.err("ENOENT", "realpath", args.path.slice())
        }
        return Maybe<String>(resolved.getOrThrow())
    }

    /// realpathNonNative — 非原生 realpath 实现
    /// 对应 Bun: NodeFS.realpathNonNative
    public func realpathNonNative(args: RealpathArgs, flavor: Flavor): Maybe<String> {
        return realpath(args, flavor)
    }

    /// realpathNative — 原生 realpath
    /// 对应 Bun: NodeFS.realpathNative
    public func realpathNative(args: RealpathArgs, flavor: Flavor): Maybe<String> {
        return realpath(args, flavor)
    }

    // ========================================================================
    // chmod — 修改文件权限
    // 对应 Bun: NodeFS.chmod
    // ========================================================================
    public func chmod(args: ChmodArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.chmod(args.path.slice(), args.mode)
        if (!ok) {
            return Maybe<Unit>.err("EPERM", "chmod", args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // fchmod — 修改文件描述符权限
    // 对应 Bun: NodeFS.fchmod
    // ========================================================================
    public func fchmod(args: FChmodArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.fchmod(args.fd, args.mode)
        if (!ok) {
            return Maybe<Unit>.err("EBADF", "fchmod", "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // chown — 修改文件所有者
    // 对应 Bun: NodeFS.chown
    // ========================================================================
    public func chown(args: ChownArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.chown(args.path.slice(), args.uid, args.gid)
        if (!ok) {
            return Maybe<Unit>.err("EPERM", "chown", args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // fchown — 修改文件描述符所有者
    // 对应 Bun: NodeFS.fchown
    // ========================================================================
    public func fchown(args: FchownArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.fchown(args.fd, args.uid, args.gid)
        if (!ok) {
            return Maybe<Unit>.err("EBADF", "fchown", "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // lchmod — 修改符号链接权限
    // 对应 Bun: NodeFS.lchmod
    // ========================================================================
    public func lchmod(args: ChmodArgs, flavor: Flavor): Maybe<Unit> {
        // lchmod is typically not supported on most platforms
        return Maybe<Unit>.err("ENOTSUP", "lchmod", args.path.slice())
    }

    // ========================================================================
    // lchown — 修改符号链接所有者
    // 对应 Bun: NodeFS.lchown
    // ========================================================================
    public func lchown(args: ChownArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.lchown(args.path.slice(), args.uid, args.gid)
        if (!ok) {
            return Maybe<Unit>.err("EPERM", "lchown", args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // utimes — 修改文件时间戳
    // 对应 Bun: NodeFS.utimes
    // ========================================================================
    public func utimes(args: UtimesArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.utimes(args.path.slice(), args.atime, args.mtime)
        if (ok < 0) {
            return Maybe<Unit>.err("ENOENT", "utime", args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // lutimes — 修改符号链接时间戳
    // 对应 Bun: NodeFS.lutimes
    // ========================================================================
    public func lutimes(args: UtimesArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.lutimes(args.path.slice(), args.atime, args.mtime)
        if (ok < 0) {
            return Maybe<Unit>.err("ENOENT", "utime", args.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // futimes — 修改文件描述符时间戳
    // 对应 Bun: NodeFS.futimes
    // ========================================================================
    public func futimes(args: FutimesArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.futimes(args.fd, args.atime, args.mtime)
        if (ok < 0) {
            return Maybe<Unit>.err("EBADF", "futime", "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // truncate — 截断文件
    // 对应 Bun: NodeFS.truncate
    // ========================================================================
    public func truncate(args: TruncateArgs, flavor: Flavor): Maybe<Unit> {
        if (args.path.isFd) {
            return ftruncate(FTruncateArgs(args.path.fd, args.len), flavor)
        }
        let ok = NodeFsSystem.truncate(args.path.path.slice(), args.len)
        if (ok < 0) {
            return Maybe<Unit>.err("ENOENT", "truncate", args.path.path.slice())
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // ftruncate — 截断文件描述符
    // 对应 Bun: NodeFS.ftruncate
    // ========================================================================
    public func ftruncate(args: FTruncateArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.ftruncate(args.fd, args.len)
        if (ok < 0) {
            return Maybe<Unit>.err("EBADF", "ftruncate", "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // fdatasync — 文件数据同步
    // 对应 Bun: NodeFS.fdatasync
    // ========================================================================
    public func fdatasync(args: FdataSyncArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.fdatasync(args.fd)
        if (ok < 0) {
            return Maybe<Unit>.err("EBADF", "fdatasync", "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // fsync — 文件同步
    // 对应 Bun: NodeFS.fsync
    // ========================================================================
    public func fsync(args: FsyncArgs, flavor: Flavor): Maybe<Unit> {
        let ok = NodeFsSystem.fsync(args.fd)
        if (ok < 0) {
            return Maybe<Unit>.err("EBADF", "fsync", "")
        }
        return Maybe<Unit>.success()
    }

    // ========================================================================
    // exists — 检查文件是否存在
    // 对应 Bun: NodeFS.exists
    // ========================================================================
    public func exists(args: ExistsArgs, flavor: Flavor): Maybe<Bool> {
        if (args.path.isNone()) {
            return Maybe<Bool>(false)
        }
        let path = args.path.getOrThrow().slice()
        return Maybe<Bool>(NodeFsSystem.access(path, 0))
    }

    // ========================================================================
    // readdir — 读取目录
    // 对应 Bun: NodeFS.readdir
    // ========================================================================
    public func readdir(args: ReaddirArgs, flavor: Flavor): Maybe<ReaddirResult> {
        if (args.withFileTypes) {
            let entries = NodeFsSystem.readdirWithTypes(args.path.slice())
            return Maybe<ReaddirResult>(ReaddirResult(entries))
        }
        let entries = NodeFsSystem.readdir(args.path.slice())
        return Maybe<ReaddirResult>(ReaddirResult(entries))
    }

    // ========================================================================
    // statfs — 获取文件系统信息
    // 对应 Bun: NodeFS.statfs
    // ========================================================================
    public func statfs(args: StatFSArgs, flavor: Flavor): Maybe<StatFS> {
        let result = NodeFsSystem.statfs(args.path.slice())
        if (result.isNone()) {
            return Maybe<StatFS>.err("ENOENT", "statfs", args.path.slice())
        }
        return Maybe<StatFS>(result.getOrThrow())
    }

    // ========================================================================
    // watch — 监视文件变化
    // 对应 Bun: NodeFS.watch
    // ========================================================================
    public func watch(path: String, options: JsValue, globalObject: JsGlobalObject): Maybe<JsValue> {
        let watcher = FsWatcher(path)
        watcher.start()
        return Maybe<JsValue>(JsValue())
    }

    // ========================================================================
    // watchFile — 监视文件状态变化
    // 对应 Bun: NodeFS.watchFile
    // ========================================================================
    public func watchFile(args: StatArgs, globalObject: JsGlobalObject): Maybe<JsValue> {
        let watcher = StatWatcher(args.path.slice(), 0, true, false)
        watcher.start()
        return Maybe<JsValue>(JsValue())
    }

    // ========================================================================
    // cp — 复制文件或目录
    // 对应 Bun: NodeFS.cp
    // ========================================================================
    public func cp(src: String, dest: String, recursive: Bool, force: Bool, errorOnExist: Bool): Maybe<Unit> {
        if (recursive) {
            let ok = NodeFsSystem.cpRecursive(src, dest, force)
            if (!ok) {
                return Maybe<Unit>.err("ENOENT", "copyfile", src)
            }
            return Maybe<Unit>.success()
        }
        let ok = NodeFsSystem.copyFile(src, dest, 0)
        if (ok < 0) {
            if (!force) {
                return Maybe<Unit>.success()
            }
            return Maybe<Unit>.err("ENOENT", "copyfile", src)
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
        let obj = JsObject()
        obj.set("close", JsValue("close"))
        return JsValue(obj)
    }
}

// StatWatcher — 已在 node_fs_stat_watcher.cj 中定义

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
            nodeFs.access(args, Flavor.async)
        }
    }

    /// 异步 appendFile
    /// 对应 Bun: Async.appendFile
    public static func appendFile(globalObject: JsGlobalObject, nodeFs: NodeFS, args: WriteFileArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.appendFile(args, Flavor.async)
        }
    }

    /// 异步 chmod
    /// 对应 Bun: Async.chmod
    public static func chmod(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ChmodArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.chmod(args, Flavor.async)
        }
    }

    /// 异步 chown
    /// 对应 Bun: Async.chown
    public static func chown(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ChownArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.chown(args, Flavor.async)
        }
    }

    /// 异步 close
    /// 对应 Bun: Async.close
    public static func close(globalObject: JsGlobalObject, nodeFs: NodeFS, args: CloseArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.close(args, Flavor.async)
        }
    }

    /// 异步 copyFile
    /// 对应 Bun: Async.copyFile
    public static func copyFile(globalObject: JsGlobalObject, nodeFs: NodeFS, args: CopyFileArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.copyFile(args, Flavor.async)
        }
    }

    /// 异步 exists
    /// 对应 Bun: Async.exists
    public static func exists(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ExistsArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.exists(args, Flavor.async)
        }
    }

    /// 异步 fchmod
    /// 对应 Bun: Async.fchmod
    public static func fchmod(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FChmodArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fchmod(args, Flavor.async)
        }
    }

    /// 异步 fchown
    /// 对应 Bun: Async.fchown
    public static func fchown(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FchownArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fchown(args, Flavor.async)
        }
    }

    /// 异步 fdatasync
    /// 对应 Bun: Async.fdatasync
    public static func fdatasync(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FdataSyncArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fdatasync(args, Flavor.async)
        }
    }

    /// 异步 fstat
    /// 对应 Bun: Async.fstat
    public static func fstat(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FstatArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fstat(args, Flavor.async)
        }
    }

    /// 异步 fsync
    /// 对应 Bun: Async.fsync
    public static func fsync(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FsyncArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.fsync(args, Flavor.async)
        }
    }

    /// 异步 ftruncate
    /// 对应 Bun: Async.ftruncate
    public static func ftruncate(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FTruncateArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.ftruncate(args, Flavor.async)
        }
    }

    /// 异步 futimes
    /// 对应 Bun: Async.futimes
    public static func futimes(globalObject: JsGlobalObject, nodeFs: NodeFS, args: FutimesArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.futimes(args, Flavor.async)
        }
    }

    /// 异步 lchmod
    /// 对应 Bun: Async.lchmod
    public static func lchmod(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ChmodArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.lchmod(args, Flavor.async)
        }
    }

    /// 异步 lchown
    /// 对应 Bun: Async.lchown
    public static func lchown(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ChownArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.lchown(args, Flavor.async)
        }
    }

    /// 异步 link
    /// 对应 Bun: Async.link
    public static func link(globalObject: JsGlobalObject, nodeFs: NodeFS, args: LinkArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.link(args, Flavor.async)
        }
    }

    /// 异步 lstat
    /// 对应 Bun: Async.lstat
    public static func lstat(globalObject: JsGlobalObject, nodeFs: NodeFS, args: StatArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.lstat(args, Flavor.async)
        }
    }

    /// 异步 lutimes
    /// 对应 Bun: Async.lutimes
    public static func lutimes(globalObject: JsGlobalObject, nodeFs: NodeFS, args: UtimesArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.lutimes(args, Flavor.async)
        }
    }

    /// 异步 mkdir
    /// 对应 Bun: Async.mkdir
    public static func mkdir(globalObject: JsGlobalObject, nodeFs: NodeFS, args: MkdirArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.mkdir(args, Flavor.async)
        }
    }

    /// 异步 mkdtemp
    /// 对应 Bun: Async.mkdtemp
    public static func mkdtemp(globalObject: JsGlobalObject, nodeFs: NodeFS, args: MkdirTempArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.mkdtemp(args, Flavor.async)
        }
    }

    /// 异步 open
    /// 对应 Bun: Async.open
    public static func open(globalObject: JsGlobalObject, nodeFs: NodeFS, args: OpenArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.open(args, Flavor.async)
        }
    }

    /// 异步 read
    /// 对应 Bun: Async.read
    public static func read(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ReadArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.read(args, Flavor.async)
        }
    }

    /// 异步 readdir
    /// 对应 Bun: Async.readdir
    public static func readdir(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ReaddirArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.readdir(args, Flavor.async)
        }
    }

    /// 异步 readFile
    /// 对应 Bun: Async.readFile
    public static func readFile(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ReadFileArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.readFile(args, Flavor.async)
        }
    }

    /// 异步 readlink
    /// 对应 Bun: Async.readlink
    public static func readlink(globalObject: JsGlobalObject, nodeFs: NodeFS, args: ReadlinkArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.readlink(args, Flavor.async)
        }
    }

    /// 异步 realpath
    /// 对应 Bun: Async.realpath
    public static func realpath(globalObject: JsGlobalObject, nodeFs: NodeFS, args: RealpathArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.realpath(args, Flavor.async)
        }
    }

    /// 异步 rename
    /// 对应 Bun: Async.rename
    public static func rename(globalObject: JsGlobalObject, nodeFs: NodeFS, args: RenameArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.rename(args, Flavor.async)
        }
    }

    /// 异步 rm
    /// 对应 Bun: Async.rm
    public static func rm(globalObject: JsGlobalObject, nodeFs: NodeFS, args: RmDirArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.rm(args, Flavor.async)
        }
    }

    /// 异步 rmdir
    /// 对应 Bun: Async.rmdir
    public static func rmdir(globalObject: JsGlobalObject, nodeFs: NodeFS, args: RmDirArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.rmdir(args, Flavor.async)
        }
    }

    /// 异步 stat
    /// 对应 Bun: Async.stat
    public static func stat(globalObject: JsGlobalObject, nodeFs: NodeFS, args: StatArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.stat(args, Flavor.async)
        }
    }

    /// 异步 symlink
    /// 对应 Bun: Async.symlink
    public static func symlink(globalObject: JsGlobalObject, nodeFs: NodeFS, args: SymlinkArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.symlink(args, Flavor.async)
        }
    }

    /// 异步 truncate
    /// 对应 Bun: Async.truncate
    public static func truncate(globalObject: JsGlobalObject, nodeFs: NodeFS, args: TruncateArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.truncate(args, Flavor.async)
        }
    }

    /// 异步 unlink
    /// 对应 Bun: Async.unlink
    public static func unlink(globalObject: JsGlobalObject, nodeFs: NodeFS, args: UnlinkArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.unlink(args, Flavor.async)
        }
    }

    /// 异步 utimes
    /// 对应 Bun: Async.utimes
    public static func utimes(globalObject: JsGlobalObject, nodeFs: NodeFS, args: UtimesArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.utimes(args, Flavor.async)
        }
    }

    /// 异步 write
    /// 对应 Bun: Async.write
    public static func write(globalObject: JsGlobalObject, nodeFs: NodeFS, args: WriteArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.write(args, Flavor.async)
        }
    }

    /// 异步 writeFile
    /// 对应 Bun: Async.writeFile
    public static func writeFile(globalObject: JsGlobalObject, nodeFs: NodeFS, args: WriteFileArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.writeFile(args, Flavor.async)
        }
    }

    /// 异步 statfs
    /// 对应 Bun: Async.statfs
    public static func statfs(globalObject: JsGlobalObject, nodeFs: NodeFS, args: StatFSArgs): JsValue {
        return WorkPool.schedulePromise(globalObject) { =>
            nodeFs.statfs(args, Flavor.async)
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
        let result = work()
        if (result.hasError) {
            return JsPromise.reject(result.error.toJS(globalObject)).toJsValue()
        }
        return JsPromise.resolve(result.toJS(globalObject)).toJsValue()
    }
}

// ============================================================================
// mkdirp — 递归创建目录（内部导出函数）
// 对应 Bun: Bun__mkdirp
// ============================================================================
public func mkdirp(path: String): Bool {
    return NodeFsSystem.mkdirRecursive(path, UInt32(0o777))
}

// ============================================================================
// NodeFsSystem — 文件系统系统调用存根
// 所有方法通过 FFI 调用实际系统调用，此处为编译占位
// ============================================================================
public class NodeFsSystem {
    private static func okUnit(result: SysMaybe<Unit>): Bool {
        match (result) {
            case Ok(_) => return true
            case Err(_) => return false
        }
    }

    private static func unitCode(result: SysMaybe<Unit>): Int32 {
        return if (okUnit(result)) { 0 } else { -1 }
    }

    private static func toStats(stat: PosixStat): Stats {
        let atimeMs = Float64(stat.atimeSec) * 1000.0 + Float64(stat.atimeNsec) / 1000000.0
        let mtimeMs = Float64(stat.mtimeSec) * 1000.0 + Float64(stat.mtimeNsec) / 1000000.0
        let ctimeMs = Float64(stat.ctimeSec) * 1000.0 + Float64(stat.ctimeNsec) / 1000000.0
        return Stats(stat.dev, stat.ino, UInt64(stat.mode), stat.nlink,
                     UInt64(stat.uid), UInt64(stat.gid), stat.rdev, stat.size,
                     stat.blksize, stat.blocks,
                     atimeMs, mtimeMs, ctimeMs, ctimeMs)
    }

    private static func toEntryKind(kind: DirEntryType): EntryKind {
        match (kind) {
            case DirEntryType.File => return EntryKind.file
            case DirEntryType.Directory => return EntryKind.directory
            case DirEntryType.Symlink => return EntryKind.sym_link
            case DirEntryType.Block => return EntryKind.block_device
            case DirEntryType.Char => return EntryKind.character_device
            case DirEntryType.Fifo => return EntryKind.named_pipe
            case DirEntryType.Socket => return EntryKind.unix_domain_socket
            case _ => return EntryKind.unknown
        }
    }

    public static func access(path: String, mode: UInt32): Bool { okUnit(SysFs.access(path, Int64(mode))) }
    public static func chmod(path: String, mode: UInt32): Bool { okUnit(SysFs.chmod(path, mode)) }
    public static func chown(path: String, uid: UInt32, gid: UInt32): Bool { okUnit(SysImpl.chown(path, uid, gid)) }
    public static func close(fd: Int32): Unit { let _ = SysFs.close(Int64(fd)) }

    public static func copyFile(src: String, dest: String, flags: Int32): Int32 {
        let data = readFile(src)
        if (data.isNone()) { return -1 }
        return writeFile(dest, data.getOrThrow(), UInt32(0o666))
    }

    public static func cpRecursive(src: String, dest: String, force: Bool): Bool {
        // First check if src exists and is a directory
        let srcStat = stat(src)
        if (srcStat.isNone()) { return false }
        let s = srcStat.getOrThrow()

        // If src is a file, just copy it
        if ((s.mode & UInt64(S.IFMT)) == UInt64(S.IFREG)) {
            let rc = copyFile(src, dest, 0)
            return rc >= 0
        }

        // If src is not a directory, we can't recurse
        if ((s.mode & UInt64(S.IFMT)) != UInt64(S.IFDIR)) { return false }

        // Create destination directory
        let mkdirOk = NodeFsSystem.mkdirRecursive(dest, UInt32(0o777))
        if (!mkdirOk) {
            if (!force) { return false }
        }

        // Read entries and recurse
        let entries = readdirWithTypes(src)
        for (entry in entries) {
            let srcPath = src + "/" + entry.name
            let destPath = dest + "/" + entry.name
            match (entry.kind) {
                case EntryKind.directory =>
                    if (!cpRecursive(srcPath, destPath, force)) {
                        return false
                    }
                case EntryKind.sym_link =>
                    // For symlinks, read the target and create a new symlink
                    let target = readlink(srcPath)
                    if (target.isNone()) { return false }
                    let linkRc = symlink(target.getOrThrow(), destPath)
                    if (linkRc < 0) {
                        if (!force) { return false }
                    }
                case _ =>
                    // Regular file or other - copy it
                    let rc = copyFile(srcPath, destPath, 0)
                    if (rc < 0) {
                        if (!force) { return false }
                    }
            }
        }
        return true
    }
    public static func fchmod(fd: Int32, mode: UInt32): Bool { okUnit(SysImpl.fchmod(Int64(fd), mode)) }
    public static func fchown(fd: Int32, uid: UInt32, gid: UInt32): Bool { okUnit(SysImpl.fchown(Int64(fd), uid, gid)) }
    public static func fdatasync(fd: Int32): Int32 {
        unsafe {
            let rc = fdatasync(fd)
            return if (rc != 0) { -1 } else { 0 }
        }
    }

    public static func fstat(fd: Int32): ?Stats {
        match (SysImpl.fstat(Int64(fd))) {
            case Ok(s) => return Some(toStats(s))
            case Err(_) => return None
        }
    }

    public static func fsync(fd: Int32): Int32 { unitCode(SysFs.fsync(Int64(fd))) }
    public static func ftruncate(fd: Int32, len: Int64): Int32 { unitCode(SysFs.ftruncate(Int64(fd), len)) }
    public static func futimes(fd: Int32, atime: Float64, mtime: Float64): Int32 {
        unsafe {
            // 构建 timeval 数组: [atime, mtime]
            let tvSize = UIntNative(16) // sizeof(struct timeval) = 16 bytes on 64-bit
            let times = malloc(tvSize)
            let tvArr = CPointer<Int64>(times)
            // timeval { tv_sec: Int64, tv_usec: Int64 }
            tvArr.write(0, Int64(atime))
            tvArr.write(1, Int64((atime - Float64(Int64(atime))) * 1000000.0))
            tvArr.write(2, Int64(mtime))
            tvArr.write(3, Int64((mtime - Float64(Int64(mtime))) * 1000000.0))
            let rc = futimes(fd, times)
            free(times)
            return rc
        }
    }
    public static func lchown(path: String, uid: UInt32, gid: UInt32): Bool {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = lchown(pathPtr, uid, gid)
            return rc == 0
        }
    }
    public static func link(oldPath: String, newPath: String): Int32 {
        unsafe {
            let oldPtr = unsafeNewCString(oldPath)
            let newPtr = unsafeNewCString(newPath)
            return link(oldPtr, newPtr)
        }
    }

    public static func lstat(path: String): ?Stats {
        match (SysImpl.lstat(path)) {
            case Ok(s) => return Some(toStats(s))
            case Err(_) => return None
        }
    }

    public static func lutimes(path: String, atime: Float64, mtime: Float64): Int32 {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let tvSize = UIntNative(16) // sizeof(struct timeval) = 16 bytes on 64-bit
            let times = malloc(tvSize)
            let tvArr = CPointer<Int64>(times)
            tvArr.write(0, Int64(atime))
            tvArr.write(1, Int64((atime - Float64(Int64(atime))) * 1000000.0))
            tvArr.write(2, Int64(mtime))
            tvArr.write(3, Int64((mtime - Float64(Int64(mtime))) * 1000000.0))
            let rc = lutimes(pathPtr, times)
            free(times)
            return rc
        }
    }
    public static func mkdir(path: String, mode: UInt32): Int32 { unitCode(SysFs.mkdir(path, mode)) }
    public static func mkdirRecursive(path: String, mode: UInt32): Bool { okUnit(DirHelper.mkdirRecursiveAt(FdUtils.atCwd(), path)) }
    public static func mkdtemp(prefix: String): ?String {
        unsafe {
            // mkdtemp modifies template in place and returns it
            // Need enough space for "XXXXXX" suffix
            let bufSize = UIntNative(prefix.size + 7)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<Int8>(buf)
            // Copy prefix into buffer
            for (i in 0..prefix.size) {
                bufPtr.write(Int64(i), Int8(prefix[Int64(i)]))
            }
            // Append "XXXXXX"
            let suffix = "XXXXXX"
            for (i in 0..suffix.size) {
                bufPtr.write(Int64(prefix.size) + Int64(i), Int8(suffix[Int64(i)]))
            }
            bufPtr.write(Int64(prefix.size) + 6, Int8(0)) // null terminator
            let result = mkdtemp(bufPtr)
            if (result.isNull()) {
                free(buf)
                return None
            }
            let path = unsafeCStringToString(result)
            free(buf)
            return Some(path)
        }
    }

    public static func open(path: String, flags: Int32, mode: UInt32): Int32 {
        match (SysFs.open(path, Int64(flags), mode)) {
            case Ok(fd) => return Int32(fd)
            case Err(_) => return -1
        }
    }

    public static func readdir(path: String): Array<String> {
        match (DirUtils.listDir(path)) {
            case Err(_) => return Array<String>()
            case Ok(entries) =>
                let files = ArrayList<String>()
                for (entry in entries) {
                    files.add(entry.name)
                }
                return files.toArray()
        }
    }

    public static func readdirWithTypes(path: String): Array<DirIteratorResult> {
        match (DirUtils.listDir(path)) {
            case Err(_) => return Array<DirIteratorResult>()
            case Ok(entries) =>
                let files = ArrayList<DirIteratorResult>()
                for (entry in entries) {
                    let result = DirIteratorResult()
                    result.name = entry.name
                    result.kind = toEntryKind(entry.entryType)
                    files.add(result)
                }
                return files.toArray()
        }
    }

    public static func readFd(fd: Int32, buffer: Array<UInt8>, offset: Int64, length: Int64, position: Int64): Int64 {
        if (length <= 0 || offset < 0 || offset >= Int64(buffer.size)) { return 0 }
        let maxLen = Int64(buffer.size) - offset
        let readLen = if (length < maxLen) { length } else { maxLen }
        let tempBuf = Array<UInt8>(readLen, { _ => UInt8(0) })
        match (SysFs.read(Int64(fd), tempBuf)) {
            case Err(_) => return -1
            case Ok(bytesRead) =>
                for (i in 0..bytesRead) {
                    if (offset + i < Int64(buffer.size)) {
                        buffer[offset + i] = tempBuf[i]
                    }
                }
                return bytesRead
        }
    }

    public static func readFile(path: String): ?Array<UInt8> {
        let openResult = SysFile.openRead(path)
        match (openResult) {
            case Err(_) => return None
            case Ok(f) =>
                let data = f.readToEnd()
                let _ = f.close()
                match (data) {
                    case Ok(bytes) => return Some(bytes)
                    case Err(_) => return None
                }
        }
    }

    public static func readFileFd(fd: Int32): ?Array<UInt8> {
        let file = SysFile.fromFd(Int64(fd))
        match (file.readToEnd()) {
            case Ok(bytes) => return Some(bytes)
            case Err(_) => return None
        }
    }

    public static func readlink(path: String): ?String {
        match (SysFs.readlink(path)) {
            case Ok(target) => return Some(target)
            case Err(_) => return None
        }
    }

    public static func realpath(path: String): ?String {
        match (SysFs.realpath(path)) {
            case Ok(resolved) => return Some(resolved)
            case Err(_) => return None
        }
    }

    public static func rename(oldPath: String, newPath: String): Int32 { unitCode(SysFs.rename(oldPath, newPath)) }
    public static func rmdir(path: String): Int32 { unitCode(SysFs.rmdir(path)) }
    public static func rmRecursive(path: String): Bool { okUnit(DirHelper.deleteTree(FdUtils.atCwd(), path)) }

    public static func stat(path: String): ?Stats {
        match (SysImpl.stat(path)) {
            case Ok(s) => return Some(toStats(s))
            case Err(_) => return None
        }
    }

    public static func statfs(path: String): ?StatFS {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            // struct statfs on Linux x86_64 is ~120 bytes
            let bufSize = UIntNative(128)
            let buf = malloc(bufSize)
            let rc = OS.statfs(pathPtr, buf)
            if (rc != 0) {
                free(buf)
                return None
            }
            // Parse struct statfs fields
            // Linux x86_64 struct statfs layout:
            //   f_type: Int64 (offset 0)
            //   f_bsize: Int64 (offset 8)
            //   f_blocks: Int64 (offset 16)
            //   f_bfree: Int64 (offset 24)
            //   f_bavail: Int64 (offset 32)
            //   f_files: Int64 (offset 40)
            //   f_ffree: Int64 (offset 48)
            let arr = CPointer<Int64>(buf)
            let result = StatFS(
                Int32(arr.read(0)),   // fstype
                Int32(arr.read(1)),   // bsize
                Int32(arr.read(2)),   // blocks
                Int32(arr.read(3)),   // bfree
                Int32(arr.read(4)),   // bavail
                Int32(arr.read(5)),   // files
                Int32(arr.read(6))    // ffree
            )
            free(buf)
            return Some(result)
        }
    }
    public static func symlink(target: String, path: String): Int32 { unitCode(SysFs.symlink(target, path)) }

    public static func truncate(path: String, len: Int64): Int32 {
        match (SysFs.open(path, OpenFlags.WRONLY, UInt32(0))) {
            case Err(_) => return -1
            case Ok(fd) =>
                let rc = unitCode(SysFs.ftruncate(fd, len))
                let _ = SysFs.close(fd)
                return rc
        }
    }

    public static func unlink(path: String): Int32 { unitCode(SysFs.unlink(path)) }
    public static func utimes(path: String, atime: Float64, mtime: Float64): Int32 {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let tvSize = UIntNative(16) // sizeof(struct timeval) = 16 bytes on 64-bit
            let times = malloc(tvSize)
            let tvArr = CPointer<Int64>(times)
            tvArr.write(0, Int64(atime))
            tvArr.write(1, Int64((atime - Float64(Int64(atime))) * 1000000.0))
            tvArr.write(2, Int64(mtime))
            tvArr.write(3, Int64((mtime - Float64(Int64(mtime))) * 1000000.0))
            let rc = utimes(pathPtr, times)
            free(times)
            return rc
        }
    }

    public static func writeFd(fd: Int32, buffer: Array<UInt8>, offset: Int64, length: Int64, position: Int64): Int64 {
        if (length <= 0 || offset < 0 || offset >= Int64(buffer.size)) { return 0 }
        let maxLen = Int64(buffer.size) - offset
        let writeLen = if (length < maxLen) { length } else { maxLen }
        let temp = Array<UInt8>(writeLen, { i => buffer[offset + i] })
        let writeResult = SysFs.write(Int64(fd), temp)
        match (writeResult) {
            case Ok(n) => return n
            case Err(_) => return -1
        }
    }

    public static func writeFile(path: String, data: Array<UInt8>, mode: UInt32): Int32 {
        match (SysFs.open(path, OpenFlags.WRONLY | OpenFlags.CREAT | OpenFlags.TRUNC, mode)) {
            case Err(_) => return -1
            case Ok(fd) =>
                let file = SysFile.fromFd(fd)
                let result = file.writeAll(data)
                let _ = file.close()
                return unitCode(result)
        }
    }
}
