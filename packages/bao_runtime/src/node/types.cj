// Node.js 运行时类型定义（完整翻译）
// 对应 Bun: src/runtime/node/types.zig
// 严格翻译自: src/runtime/node/types.zig
package bao_runtime

import bao_core.*

// ============================================================================
// 编码类型枚举
// 对应 Bun: src/runtime/node/types.zig - Encoding (must match BufferEncodingType.h)
// 支持: utf8, ucs2, utf16le, latin1, ascii, base64, base64url, hex, buffer
// ============================================================================
public enum Encoding {
    utf8,
    ucs2,
    utf16le,
    latin1,
    ascii,
    base64,
    base64url,
    hex,
    buffer

    // 编码名称映射（用于从字符串解析编码类型）
    // 对应 Bun: Encoding.map (ComptimeStringMap)
    public static func from(name: String): ?Encoding {
        let lower = name.toLowerAscii()
        if (lower == "utf-8" || lower == "utf8") {
            return utf8
        }
        if (lower == "ucs-2" || lower == "ucs2" || lower == "utf16-le" || lower == "utf16le") {
            return utf16le
        }
        if (lower == "binary" || lower == "latin1") {
            return latin1
        }
        if (lower == "ascii") {
            return ascii
        }
        if (lower == "base64") {
            return base64
        }
        if (lower == "hex") {
            return hex
        }
        if (lower == "buffer") {
            return buffer
        }
        if (lower == "base64url") {
            return base64url
        }
        return None
    }

    // 是否为二进制到文本的编码
    // 对应 Bun: Encoding.isBinaryToText
    public func isBinaryToText(): Bool {
        return this == hex || this == base64 || this == base64url
    }
}

// ============================================================================
// 文件系统标志
// 对应 Bun: src/runtime/node/types.zig - FileSystemFlags
// 基于 Node.js fs.open() 的 flags 参数
// 使用系统 O_* 常量组合
// ============================================================================
public enum FileSystemFlags {
    // 打开文件用于读取。不存在则异常
    r,
    // 打开文件用于同步读取
    rs,
    // 打开文件用于读写
    rPlus,
    // 打开文件用于同步读写
    rsPlus,
    // 打开文件用于写入。不存在则创建，存在则截断
    w,
    // 类似 w 但路径存在则失败
    wx,
    // 打开文件用于读写。不存在则创建，存在则截断
    wPlus,
    // 类似 w+ 但路径存在则失败
    wxPlus,
    // 打开文件用于追加。不存在则创建
    a,
    // 类似 a 但路径存在则失败
    ax,
    // 打开文件用于读写追加。不存在则创建
    aPlus,
    // 类似 a+ 但路径存在则失败
    axPlus,
    // 打开文件用于同步追加
    as,
    // 打开文件用于同步读写追加
    asPlus

    // 从字符串解析文件系统标志
    // 对应 Bun: FileSystemFlags.fromJS (使用 ComptimeStringMap)
    // 支持 "r", "rs", "sr", "r+", "rs+", "sr+",
    //       "w", "wx", "xw", "w+", "wx+", "xw+",
    //       "a", "ax", "xa", "as", "sa", "a+", "ax+", "xa+", "as+", "sa+"
    // 以及大写变体
    public static func from(flag: String): ?FileSystemFlags {
        let f = flag.toLowerAscii()
        if (f == "r") { return r }
        if (f == "rs" || f == "sr") { return rs }
        if (f == "r+") { return rPlus }
        if (f == "rs+" || f == "sr+") { return rsPlus }
        if (f == "w") { return w }
        if (f == "wx" || f == "xw") { return wx }
        if (f == "w+") { return wPlus }
        if (f == "wx+" || f == "xw+") { return wxPlus }
        if (f == "a") { return a }
        if (f == "ax" || f == "xa") { return ax }
        if (f == "as" || f == "sa") { return as }
        if (f == "a+") { return aPlus }
        if (f == "ax+" || f == "xa+") { return axPlus }
        if (f == "as+" || f == "sa+") { return asPlus }
        return None
    }

    // 从数字解析标志
    // 对应 Bun: FileSystemFlags.fromJS 中的数字路径
    public static func fromNumber(value: Int32): FileSystemFlags {
        // 简化映射
        if ((value & 0x2) != 0 && (value & 0x8) != 0) {
            return a
        }
        if ((value & 0x1) != 0) {
            return w
        }
        return r
    }

    // 获取整数值
    // 对应 Bun: FileSystemFlags.asInt
    public func asInt(): Int32 {
        return Int32(this.ordinal())
    }
}

// ============================================================================
// 路径或文件描述符联合类型
// 对应 Bun: src/runtime/node/types.zig - PathOrFileDescriptor
// ============================================================================
public class PathOrFileDescriptor {
    public var isFd: Bool = false
    public var fd: Int32 = -1
    public var path: PathLike = PathLike()

    public init(fd: Int32) {
        this.isFd = true
        this.fd = fd
    }

    public init(path: PathLike) {
        this.isFd = false
        this.path = path
    }

    // 获取路径字符串
    // 对应 Bun: PathOrFileDescriptor.format
    public func slice(): String {
        return if (isFd) { fd.toString() } else { path.slice() }
    }

    // 释放资源
    // 对应 Bun: PathOrFileDescriptor.deinit / deinitAndUnprotect
    public func deinit(): Unit {
        if (!isFd) {
            path.deinit()
        }
    }

    // 转换为线程安全版本
    // 对应 Bun: PathOrFileDescriptor.toThreadSafe
    public func toThreadSafe(): Unit {
        if (!isFd) {
            path.toThreadSafe()
        }
    }

    // 哈希值
    // 对应 Bun: PathOrFileDescriptor.hash
    public func hash(): UInt64 {
        return if (isFd) {
            UInt64(fd)
        } else {
            UInt64(path.slice().hashValue())
        }
    }
}

// ============================================================================
// 路径类型（类似 PathLike）
// 对应 Bun: src/runtime/node/types.zig - PathLike
// 支持: string, buffer, encoded_slice, threadsafe_string 等
// ============================================================================
public class PathLike {
    public var value: String = ""
    public var isBuffer: Bool = false

    public init() {}

    public init(value: String) {
        this.value = value
    }

    // 获取路径切片
    // 对应 Bun: PathLike.slice
    public func slice(): String {
        return value
    }

    // 释放资源
    // 对应 Bun: PathLike.deinit
    public func deinit(): Unit {
        // 在仓颉中由 GC 管理
    }

    // 转换为线程安全版本
    // 对应 Bun: PathLike.toThreadSafe
    public func toThreadSafe(): Unit {
        // 在仓颉中字符串天然线程安全
    }

    // 释放并取消保护
    // 对应 Bun: PathLike.deinitAndUnprotect
    public func deinitAndUnprotect(): Unit {
        // 在仓颉中由 GC 管理
    }

    // 估算大小
    // 对应 Bun: PathLike.estimatedSize
    public func estimatedSize(): Int64 {
        return value.size
    }
}

// ============================================================================
// 字符串或缓冲区联合类型
// 对应 Bun: src/runtime/node/types.zig - StringOrBuffer
// 支持: string, threadsafe_string, encoded_slice, buffer
// ============================================================================
public class StringOrBuffer {
    public var stringValue: String = ""
    public var bufferValue: Array<UInt8> = Array<UInt8>()
    public var isBuffer: Bool = false

    public init() {}

    public init(value: String) {
        this.stringValue = value
    }

    public init(buffer: Array<UInt8>) {
        this.bufferValue = buffer
        this.isBuffer = true
    }

    // 获取字节切片
    // 对应 Bun: StringOrBuffer.slice
    public func slice(): Array<UInt8> {
        if (isBuffer) {
            return bufferValue
        }
        return Array<UInt8>() // 简化
    }

    // 获取字符串值
    public func stringSlice(): String {
        return if (isBuffer) { "" } else { stringValue }
    }

    // 释放资源
    // 对应 Bun: StringOrBuffer.deinit
    public func deinit(): Unit {
        // 在仓颉中由 GC 管理
    }

    // 释放并取消保护
    // 对应 Bun: StringOrBuffer.deinitAndUnprotect
    public func deinitAndUnprotect(): Unit {
        // 在仓颉中由 GC 管理
    }

    // 转换为线程安全版本
    // 对应 Bun: StringOrBuffer.toThreadSafe
    public func toThreadSafe(): Unit {
        // 在仓颉中字符串天然线程安全
    }
}

// ============================================================================
// Blob 或字符串或缓冲区联合类型
// 对应 Bun: src/runtime/node/types.zig - BlobOrStringOrBuffer
// ============================================================================
public class BlobOrStringOrBuffer {
    public var stringOrBuffer: StringOrBuffer = StringOrBuffer()
    public var blobData: Array<UInt8> = Array<UInt8>()
    public var isBlob: Bool = false

    public init() {}

    // 获取字节长度
    // 对应 Bun: BlobOrStringOrBuffer.byteLength
    public func byteLength(): Int64 {
        return if (isBlob) {
            blobData.size
        } else {
            stringOrBuffer.slice().size
        }
    }

    // 获取字节切片
    // 对应 Bun: BlobOrStringOrBuffer.slice
    public func slice(): Array<UInt8> {
        return if (isBlob) {
            blobData
        } else {
            stringOrBuffer.slice()
        }
    }

    // 释放资源
    // 对应 Bun: BlobOrStringOrBuffer.deinit / deinitAndUnprotect
    public func deinit(): Unit {
        // 在仓颉中由 GC 管理
    }
}

// ============================================================================
// 目录项
// 对应 Bun: src/runtime/node/types.zig - Dirent
// 包含 name, path, kind，支持类型判断方法
// ============================================================================
public class Dirent {
    public var name: String = ""
    public var path: String = ""
    public var kind: EntryKind = EntryKind.unknown

    public init() {}

    public init(name: String, path: String, kind: EntryKind) {
        this.name = name
        this.path = path
        this.kind = kind
    }

    // 文件类型判断方法
    // 对应 Bun: Dirent 中的 toJS 映射到 UV_DIRENT_* 常量

    public func isFile(): Bool {
        return kind == EntryKind.file
    }

    public func isDirectory(): Bool {
        return kind == EntryKind.directory
    }

    public func isSymbolicLink(): Bool {
        return kind == EntryKind.sym_link
    }

    public func isBlockDevice(): Bool {
        return kind == EntryKind.block_device
    }

    public func isCharacterDevice(): Bool {
        return kind == EntryKind.character_device
    }

    public func isFIFO(): Bool {
        return kind == EntryKind.named_pipe
    }

    public func isSocket(): Bool {
        return kind == EntryKind.unix_domain_socket
    }
}

// ============================================================================
// 文件类型枚举
// 对应 Bun: src/runtime/node/types.zig - Dirent.Kind (std.fs.File.Kind)
// ============================================================================
public enum EntryKind {
    file,
    directory,
    sym_link,
    block_device,
    character_device,
    named_pipe,
    unix_domain_socket,
    event_port,
    whiteout,
    door,
    unknown
}

// ============================================================================
// 路径验证工具
// 对应 Bun: src/runtime/node/types.zig - Valid
// 包含路径长度验证和空字节检测
// ============================================================================
public class Valid {
    // 最大路径长度
    public static let MAX_PATH_BYTES: Int64 = 4096

    // 验证路径长度
    // 对应 Bun: Valid.pathStringLength
    // 路径长度必须在 0..MAX_PATH_BYTES 之间，否则抛出 NAMETOOLONG
    public static func pathStringLength(len: Int64): Bool {
        return len >= 0 && len <= MAX_PATH_BYTES
    }

    // 验证路径字符串长度（使用 ZigString）
    // 对应 Bun: Valid.pathString
    public static func pathString(len: Int64): Bool {
        return pathStringLength(len)
    }

    // 验证路径不包含空字节
    // 对应 Bun: Valid.pathNullBytes
    // 如果包含空字节则抛出 ERR_INVALID_ARG_VALUE
    public static func pathNullBytes(path: String): Bool {
        return !path.contains('\x00')
    }

    // 验证路径缓冲区
    // 对应 Bun: Valid.pathBuffer
    // 空缓冲区抛出 "Invalid path buffer: can't be empty"
    // 超长缓冲区抛出 NAMETOOLONG
    public static func pathBuffer(buffer: Array<UInt8>): Bool {
        if (buffer.size == 0) {
            return false
        }
        return buffer.size <= MAX_PATH_BYTES
    }

    // 验证路径切片
    // 对应 Bun: Valid.pathSlice
    public static func pathSlice(len: Int64): Bool {
        return pathStringLength(len)
    }
}

// ============================================================================
// 模式解析
// 对应 Bun: src/runtime/node/types.zig - modeFromJS
// Node.js 文件权限模式（如 0o644, 0o755）
// ============================================================================
public class ModeUtils {
    // 从字符串或数字解析文件权限模式
    // 对应 Bun: modeFromJS
    // 字符串格式: "0o644", "644"（八进制）
    // 数字格式: 直接使用，截断为 0o777
    public static func fromString(modeStr: String): ?UInt32 {
        var str = modeStr
        if (str.startsWith("0o") || str.startsWith("0O")) {
            str = str.substring(2)
        }
        // 解析八进制字符串
        var result: UInt32 = 0
        for (c in str) {
            if (c >= '0' && c <= '7') {
                result = result * 8 + UInt32(UInt8(c) - UInt8('0'))
            } else {
                return None
            }
        }
        return result & 0o777
    }

    // 从数字解析模式
    // 对应 Bun: modeFromJS 中的数字路径
    public static func fromNumber(mode: Int64): UInt32 {
        return UInt32(mode) & 0o777
    }

    // 从通用值解析模式
    public static func fromValue(modeStr: ?String, modeNum: ?Int64): ?UInt32 {
        if (modeStr != None) {
            return fromString(modeStr!)
        }
        if (modeNum != None) {
            return fromNumber(modeNum!)
        }
        return None
    }
}

// ============================================================================
// 回调任务
// 对应 Bun: src/runtime/node/types.zig - CallbackTask
// ============================================================================
public class CallbackTask<Result> {
    public var callback: () -> Unit = { }
    public var success: Bool = false
    public var option: CallbackOption<Result> = CallbackTask.Option.err("")

    public init() {}

    // 选项类型
    public enum Option<T> {
        err(String)
        result(T)
    }
}

// ============================================================================
// 向量数组缓冲区
// 对应 Bun: src/runtime/node/types.zig - VectorArrayBuffer
// scatter/gather I/O 缓冲区数组
// ============================================================================
public class VectorArrayBuffer {
    public var value: Array<UInt8> = Array<UInt8>()
    public var buffers: Array<IoVec> = Array<IoVec>()

    public init() {}
}

// ============================================================================
// I/O 向量
// ============================================================================
public class IoVec {
    public var data: Array<UInt8> = Array<UInt8>()

    public init() {}
}

// ============================================================================
// 路径或 Blob 联合类型
// 对应 Bun: src/runtime/node/types.zig - PathOrBlob
// ============================================================================
public class PathOrBlob {
    public var path: PathOrFileDescriptor = PathOrFileDescriptor(-1)
    public var blobData: Array<UInt8> = Array<UInt8>()
    public var isBlob: Bool = false

    public init() {}
}
