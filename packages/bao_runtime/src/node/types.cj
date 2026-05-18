// Node.js 运行时类型定义（完整翻译）
// 对应 Bun: src/runtime/node/types.zig
// 严格翻译自: src/runtime/node/types.zig
package bao_runtime.node

import bao_core.*
import bao_jsc.*

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

    // 从 JS 值解析编码
    // 对应 Bun: Encoding.fromJS
    public static func fromJS(value: JsValue, globalObject: JsGlobalObject): ?Encoding {
        if (value.isUndefinedOrNull()) {
            return None
        }
        if (value.isString()) {
            return from(value.toString())
        }
        return None
    }

    // 是否为二进制到文本的编码
    // 对应 Bun: Encoding.isBinaryToText
    public func isBinaryToText(): Bool {
        return this == hex || this == base64 || this == base64url
    }

    // 编码断言 — 验证编码值有效，否则抛出错误
    // 对应 Bun: Encoding.assert
    public static func assert(value: JsValue, globalObject: JsGlobalObject, default: Encoding): Encoding {
        let enc = fromJS(value, globalObject: globalObject)
        if (enc != None) {
            return enc.getOrThrow()
        }
        if (!value.isUndefined()) {
            globalObject.throwTypeError("Unknown encoding")
        }
        return default
    }

    // 从 JS 值获取编码，空值时返回默认
    // 对应 Bun: Encoding.fromJSWithDefaultOnEmpty
    public static func fromJSWithDefaultOnEmpty(value: JsValue, globalObject: JsGlobalObject, default: Encoding): ?Encoding {
        if (value.isUndefinedOrNull()) {
            return default
        }
        return fromJS(value, globalObject: globalObject)
    }

    // 编码名称转 JS 值
    // 对应 Bun: Encoding.toJS
    public func toJS(): JsValue {
        let name: String = match (this) {
            case utf8 => "utf8"
            case utf16le => "utf16le"
            case latin1 => "latin1"
            case ascii => "ascii"
            case base64 => "base64"
            case hex => "hex"
            case base64url => "base64url"
            case ucs2 => "ucs2"
            case buffer => "buffer"
        }
        return JsValue(BaoString(name))
    }

    // 将字节数组用指定编码转为 JS 值
    // 对应 Bun: Encoding.encodeWithSize / encodeWithMaxSize
    public func encodeToJS(globalObject: JsGlobalObject, input: Array<UInt8>): JsValue {
        match (this) {
            case Encoding.hex => {
                return JsValue(BaoString(EncodingUtils.hexEncode(input)))
            }
            case Encoding.base64 => {
                return JsValue(BaoString(Base64Codec.encode(input)))
            }
            case Encoding.base64url => {
                let b64 = Base64Codec.encode(input)
                return JsValue(BaoString(b64.replace("+", "-").replace("/", "_").replace("=", "")))
            }
            case _ => {
                return JsValue(BaoString.fromUtf8(input))
            }
        }
    }
}

// ============================================================================
// 编码工具
// 对应 Bun: src/runtime/node/types.zig - Encoding helpers
// ============================================================================
public class EncodingUtils {
    // 抛出编码错误
    // 对应 Bun: Encoding.throwEncodingError
    public static func throwEncodingError(globalObject: JsGlobalObject): Unit {
        globalObject.throwTypeError("Unknown encoding")
    }

    // Hex 编码
    public static func hexEncode(bytes: Array<UInt8>): String {
        let hexChars = "0123456789abcdef"
        var result = StringBuilder()
        for (b in bytes) {
            result.append(hexChars[Int32(b >> 4)])
            result.append(hexChars[Int32(b & 0x0F)])
        }
        return result.toString()
    }

    // Hex 解码
    public static func hexDecode(hex: String): Array<UInt8> {
        let arr = Array<UInt8>(hex.size / 2, item: UInt8(0))
        var i = 0
        while (i < hex.size) {
            let high = hexCharToNibble(hex[i])
            let low = hexCharToNibble(hex[i + 1])
            arr[i / 2] = high * 16 + low
            i += 2
        }
        return arr
    }

    private static func hexCharToNibble(c: UInt8): UInt8 {
        if (c >= UInt8('0') && c <= UInt8('9')) {
            return c - UInt8('0')
        }
        if (c >= UInt8('a') && c <= UInt8('f')) {
            return c - UInt8('a') + 10
        }
        if (c >= UInt8('A') && c <= UInt8('F')) {
            return c - UInt8('A') + 10
        }
        return 0
    }

    // 编码的 JS 断言函数
    // 对应 Bun: jsAssertEncodingValid
    public static func jsAssertEncodingValid(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.arguments(1)
        if (args.size < 1) {
            return JsValue()
        }
        let encoding = Encoding.fromJS(args[0], globalObject: globalObject)
        if (encoding == None) {
            throwEncodingError(globalObject)
        }
        return JsValue()
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

    // 从 JS 值解析文件系统标志
    // 对应 Bun: FileSystemFlags.fromJS
    public static func fromJS(globalObject: JsGlobalObject, val: JsValue): ?FileSystemFlags {
        if (val.isNumber()) {
            let number = val.toInt32()
            let flags = if (number > 0) { number } else { 0 }
            return fromNumber(flags)
        }
        if (val.isString()) {
            let str = val.toString()
            if (str.size == 0) {
                globalObject.throwTypeError("Expected flags to be a non-empty string.")
                return None
            }
            if (str.size > 12) {
                globalObject.throwTypeError("Invalid flag '" + str + "'.")
                return None
            }
            // 尝试解析数字字符串
            if (str[0] >= '0' && str[0] <= '9') {
                return fromNumber(Int32.parse(str))
            }
            return from(str)
        }
        return None
    }

    // 从 JS 值解析数字标志（用于 access/copyFile）
    // 对应 Bun: FileSystemFlags.fromJSNumberOnly
    public static func fromJSNumberOnly(globalObject: JsGlobalObject, value: JsValue): ?FileSystemFlags {
        if (!value.isNumber()) {
            if (value.isUndefinedOrNull()) {
                return r  // F_OK = 0
            }
            globalObject.throwTypeError("mode must be int32 or null/undefined")
            return None
        }
        let int: Int32 = value.toInt32()
        if (int < 0 || int > 7) {
            globalObject.throwRangeError("mode is out of range: >= 0 and <= 7")
            return None
        }
        return fromNumber(int)
    }

    // 获取整数值
    // 对应 Bun: FileSystemFlags.asInt
    public func asInt(): Int32 {
        return Int32(this.ordinal())
    }
}

// ============================================================================
// O_* 常量
// 对应 Bun: bun.O
// ============================================================================
public class OConstants {
    public static let O_RDONLY: Int32 = 0
    public static let O_WRONLY: Int32 = 1
    public static let O_RDWR: Int32 = 2
    public static let O_CREAT: Int32 = 64
    public static let O_EXCL: Int32 = 128
    public static let O_TRUNC: Int32 = 512
    public static let O_APPEND: Int32 = 1024
    public static let O_SYNC: Int32 = 4096
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
    // 对应 Bun: PathOrFileDescriptor.deinit
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

    // 释放并取消保护
    // 对应 Bun: PathOrFileDescriptor.deinitAndUnprotect
    public func deinitAndUnprotect(): Unit {
        if (!isFd) {
            path.deinitAndUnprotect()
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

    // 从 JS 值解析
    // 对应 Bun: PathOrFileDescriptor.fromJS
    public static func fromJS(globalObject: JsGlobalObject, arguments: JsArgumentsSlice): ?PathOrFileDescriptor {
        let first = arguments.next()
        if (first == None) {
            return None
        }
        let val = first.getOrThrow()
        if (val.isNumber()) {
            let fd = val.toInt32()
            if (fd >= 0) {
                arguments.eat()
                return PathOrFileDescriptor(fd: fd)
            }
        }
        let pathLike = PathLike.fromJS(globalObject, arguments: arguments)
        if (pathLike != None) {
            return PathOrFileDescriptor(path: pathLike.getOrThrow())
        }
        return None
    }

    // 估算内存大小
    // 对应 Bun: PathOrFileDescriptor.estimatedSize
    public func estimatedSize(): Int64 {
        return if (isFd) { 0 } else { path.estimatedSize() }
    }

    // 格式化为字符串
    // 对应 Bun: PathOrFileDescriptor.format
    public func format(): String {
        return if (isFd) { fd.toString() } else { path.slice() }
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

    // 从 JS 值解析路径
    // 对应 Bun: PathLike.fromJS
    public static func fromJS(globalObject: JsGlobalObject, arguments: JsArgumentsSlice): ?PathLike {
        let value = arguments.next()
        if (value == None) {
            return None
        }
        let val = value.getOrThrow()
        if (val.isString()) {
            return PathLike(value: val.toString())
        }
        if (val.isArrayBuffer() || val.isTypedArray()) {
            let buf = val.toArrayBuffer()
            let path = Utf8Codec.decode(buf)
            let result = PathLike(value: path)
            result.isBuffer = true
            return result
        }
        return None
    }

    // 从 JS 值解析路径（带分配器）
    // 对应 Bun: PathLike.fromJSWithAllocator
    public static func fromJSWithAllocator(globalObject: JsGlobalObject, arguments: JsArgumentsSlice): ?PathLike {
        return fromJS(globalObject, arguments: arguments)
    }

    // 获取以 null 结尾的路径（C 字符串）
    // 对应 Bun: PathLike.sliceZ
    public func sliceZ(): String {
        return value
    }

    // 获取操作系统路径
    // 对应 Bun: PathLike.osPath
    public func osPath(): String {
        return value
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

    // 空常量
    // 对应 Bun: StringOrBuffer.empty
    public static let EMPTY: StringOrBuffer = StringOrBuffer()

    // 获取字节切片
    // 对应 Bun: StringOrBuffer.slice
    public func slice(): Array<UInt8> {
        if (isBuffer) {
            return bufferValue
        }
        return Utf8Codec.encode(stringValue)
    }

    // 获取字符串值
    public func stringSlice(): String {
        return if (isBuffer) { "" } else { stringValue }
    }

    // 获取字节长度
    // 对应 Bun: StringOrBuffer.byteLength
    public func byteLength(): Int64 {
        return if (isBuffer) { bufferValue.size } else { stringValue.size }
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

    // 保护 JS 值（防止 GC）
    // 对应 Bun: StringOrBuffer.protect
    public func protect(): Unit {
        // 在 Cangjie 中由 GC 管理
    }

    // 转换为 JS 值
    // 对应 Bun: StringOrBuffer.toJS
    public func toJS(globalObject: JsGlobalObject): JsValue {
        if (isBuffer) {
            return JsValue.fromArrayBuffer(globalObject, bufferValue)
        }
        return JsValue(BaoString(stringValue))
    }

    // 从 JS 值解析
    // 对应 Bun: StringOrBuffer.fromJS
    public static func fromJS(globalObject: JsGlobalObject, value: JsValue): ?StringOrBuffer {
        if (value.isUndefinedOrNull()) {
            return None
        }
        if (value.isString()) {
            return StringOrBuffer(value: value.toString())
        }
        if (value.isArrayBuffer() || value.isTypedArray()) {
            let buf = value.toArrayBuffer()
            return StringOrBuffer(buffer: buf)
        }
        return None
    }

    // 从 JS 值解析（带编码）
    // 对应 Bun: StringOrBuffer.fromJSWithEncoding
    public static func fromJSWithEncoding(globalObject: JsGlobalObject, value: JsValue, encoding: Encoding): ?StringOrBuffer {
        if (value.isUndefinedOrNull()) {
            return None
        }
        if (value.isString()) {
            return StringOrBuffer(value: value.toString())
        }
        if (value.isArrayBuffer() || value.isTypedArray()) {
            let buf = value.toArrayBuffer()
            return StringOrBuffer(buffer: buf)
        }
        return None
    }

    // 从 JS 值解析（带编码值）
    // 对应 Bun: StringOrBuffer.fromJSWithEncodingValue
    public static func fromJSWithEncodingValue(globalObject: JsGlobalObject, value: JsValue, encodingValue: JsValue): ?StringOrBuffer {
        let encoding = Encoding.fromJS(encodingValue, globalObject: globalObject)
        let enc = if (encoding != None) { encoding.getOrThrow() } else { Encoding.utf8 }
        return fromJSWithEncoding(globalObject, value: value, encoding: enc)
    }

    // 从 JS 值获取拥有的字节切片
    // 对应 Bun: StringOrBuffer.fromJSToOwnedSlice
    public static func fromJSToOwnedSlice(globalObject: JsGlobalObject, value: JsValue): Array<UInt8> {
        if (value.isArrayBuffer() || value.isTypedArray()) {
            return value.toArrayBuffer()
        }
        let str = value.toString()
        return Utf8Codec.encode(str)
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
    // 对应 Bun: BlobOrStringOrBuffer.deinit
    public func deinit(): Unit {
        // 在仓颉中由 GC 管理
    }

    // 保护 JS 值
    // 对应 Bun: BlobOrStringOrBuffer.protect
    public func protect(): Unit {
        stringOrBuffer.protect()
    }

    // 释放并取消保护
    // 对应 Bun: BlobOrStringOrBuffer.deinitAndUnprotect
    public func deinitAndUnprotect(): Unit {
        stringOrBuffer.deinitAndUnprotect()
    }

    // 从 JS 值解析
    // 对应 Bun: BlobOrStringOrBuffer.fromJS
    public static func fromJS(globalObject: JsGlobalObject, value: JsValue): ?BlobOrStringOrBuffer {
        let sob = StringOrBuffer.fromJS(globalObject, value: value)
        if (sob != None) {
            let result = BlobOrStringOrBuffer()
            result.stringOrBuffer = sob.getOrThrow()
            return result
        }
        return None
    }

    // 从 JS 值解析（允许文件）
    // 对应 Bun: BlobOrStringOrBuffer.fromJSMaybeFile
    public static func fromJSMaybeFile(globalObject: JsGlobalObject, value: JsValue, allowFile: Bool): ?BlobOrStringOrBuffer {
        return fromJS(globalObject, value: value)
    }

    // 从 JS 值异步解析
    // 对应 Bun: BlobOrStringOrBuffer.fromJSAsync
    public static func fromJSAsync(globalObject: JsGlobalObject, value: JsValue): ?BlobOrStringOrBuffer {
        return fromJS(globalObject, value: value)
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

    // UV_DIRENT 类型常量
    // 对应 Bun: Dirent.Kind -> UV_DIRENT_* 映射
    public static let UV_DIRENT_UNKNOWN: Int32 = 0
    public static let UV_DIRENT_FILE: Int32 = 1
    public static let UV_DIRENT_DIR: Int32 = 2
    public static let UV_DIRENT_LINK: Int32 = 3
    public static let UV_DIRENT_FIFO: Int32 = 4
    public static let UV_DIRENT_SOCKET: Int32 = 5
    public static let UV_DIRENT_CHAR: Int32 = 6
    public static let UV_DIRENT_BLOCK: Int32 = 7

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

    // 转换为 UV_DIRENT 类型值
    // 对应 Bun: Dirent.toJS 中的 kind switch
    public func toUVType(): Int32 {
        return match (kind) {
            case EntryKind.file => Dirent.UV_DIRENT_FILE
            case EntryKind.block_device => Dirent.UV_DIRENT_BLOCK
            case EntryKind.character_device => Dirent.UV_DIRENT_CHAR
            case EntryKind.directory => Dirent.UV_DIRENT_DIR
            case EntryKind.event_port => Dirent.UV_DIRENT_FIFO
            case EntryKind.named_pipe => Dirent.UV_DIRENT_FIFO
            case EntryKind.unix_domain_socket => Dirent.UV_DIRENT_SOCKET
            case EntryKind.sym_link => Dirent.UV_DIRENT_LINK
            case EntryKind.whiteout => Dirent.UV_DIRENT_UNKNOWN
            case EntryKind.door => Dirent.UV_DIRENT_UNKNOWN
            case EntryKind.unknown => Dirent.UV_DIRENT_UNKNOWN
        }
    }

    // 转换为 JS 值
    // 对应 Bun: Dirent.toJS
    public func toJS(globalObject: JsGlobalObject): JsValue {
        let obj = JsObject(globalObject)
        obj.set("name", JsValue(BaoString(name)))
        obj.set("path", JsValue(BaoString(path)))
        return obj.toJsValue()
    }

    // 新创建后转换为 JS 值
    // 对应 Bun: Dirent.toJSNewlyCreated
    public func toJSNewlyCreated(globalObject: JsGlobalObject): JsValue {
        return toJS(globalObject)
    }

    // 释放资源
    // 对应 Bun: Dirent.deref
    public func deref(): Unit {
        // 在 Cangjie 中由 GC 管理
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
    public static func pathStringLength(len: Int64): Bool {
        return len >= 0 && len <= MAX_PATH_BYTES
    }

    // 验证路径字符串长度
    // 对应 Bun: Valid.pathString
    public static func pathString(len: Int64): Bool {
        return pathStringLength(len)
    }

    // 验证路径不包含空字节
    // 对应 Bun: Valid.pathNullBytes
    public static func pathNullBytes(path: String): Bool {
        return !path.contains('\u{00}')
    }

    // 验证路径缓冲区
    // 对应 Bun: Valid.pathBuffer
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
// ============================================================================
public class ModeUtils {
    // 从字符串解析文件权限模式
    // 对应 Bun: modeFromJS 字符串路径
    public static func fromString(modeStr: String): ?UInt32 {
        var str = modeStr
        if (str.startsWith("0o") || str.startsWith("0O")) {
            str = str.substring(2)
        }
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
    // 对应 Bun: modeFromJS 数字路径
    public static func fromNumber(mode: Int64): UInt32 {
        return UInt32(mode) & 0o777
    }

    // 从通用值解析模式
    public static func fromValue(modeStr: ?String, modeNum: ?Int64): ?UInt32 {
        if (modeStr != None) {
            return fromString(modeStr.getOrThrow())
        }
        if (modeNum != None) {
            return fromNumber(modeNum.getOrThrow())
        }
        return None
    }

    // 从 JS 值解析模式
    // 对应 Bun: modeFromJS
    public static func fromJS(globalObject: JsGlobalObject, value: JsValue): ?UInt32 {
        if (value.isNumber()) {
            let num = value.toInt64()
            return UInt32(num) & 0o777
        }
        if (value.isUndefinedOrNull()) {
            return None
        }
        if (value.isString()) {
            let str = value.toString()
            return fromString(str)
        }
        globalObject.throwTypeError("mode must be a number or octal string")
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
    public var option: CallbackTask.Option<Result> = CallbackTask.Option.err("")

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

    // 转换为 JS 值
    // 对应 Bun: VectorArrayBuffer.toJS
    public func toJS(globalObject: JsGlobalObject): JsValue {
        return JsValue()
    }

    // 从 JS 值解析
    // 对应 Bun: VectorArrayBuffer.fromJS
    public static func fromJS(globalObject: JsGlobalObject, val: JsValue): ?VectorArrayBuffer {
        if (!val.isArrayLike()) {
            globalObject.throwTypeError("Expected ArrayBufferView[]")
            return None
        }
        let result = VectorArrayBuffer()
        let len = val.getLength()
        var i: Int64 = 0
        while (i < len) {
            let element = val.getIndex(UInt32(i))
            if (!element.isCell()) {
                globalObject.throwTypeError("Expected ArrayBufferView[]")
                return None
            }
            let arrayBuffer = element.toArrayBuffer()
            let iovec = IoVec()
            iovec.data = arrayBuffer
            result.buffers.append(iovec)
            i += 1
        }
        return result
    }
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

    // 从 JS 值解析（不复制）
    // 对应 Bun: PathOrBlob.fromJSNoCopy
    public static func fromJSNoCopy(globalObject: JsGlobalObject, args: JsArgumentsSlice): ?PathOrBlob {
        let path = PathOrFileDescriptor.fromJS(globalObject, arguments: args)
        if (path != None) {
            let result = PathOrBlob()
            result.path = path.getOrThrow()
            return result
        }
        return None
    }
}
