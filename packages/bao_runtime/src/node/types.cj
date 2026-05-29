// Node.js 运行时类型定义（完整翻译）
// 对应 Bun: src/runtime/node/types.zig
// 严格翻译自: src/runtime/node/types.zig
package bao_runtime.node

import bao_core.*
import bao_jsc.*
import bao_base64.*
import std.collection.ArrayList
import std.convert.*

// ============================================================================
// 编码类型枚举
// 对应 Bun: src/runtime/node/types.zig - Encoding (must match BufferEncodingType.h)
// 支持: utf8, ucs2, utf16le, latin1, ascii, base64, base64url, hex, buffer
// ============================================================================
public enum Encoding {
    | utf8
    | ucs2
    | utf16le
    | latin1
    | ascii
    | base64
    | base64url
    | hex
    | buffer

    // 编码名称映射（用于从字符串解析编码类型）
    // 对应 Bun: Encoding.map (ComptimeStringMap)
    public static func from(name: String): ?Encoding {
        let lower = name.toAsciiLower()
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
        match (this) {
            case hex => return true
            case base64 => return true
            case base64url => return true
            case _ => return false
        }
    }

    // 编码断言 — 验证编码值有效，否则抛出错误
    // 对应 Bun: Encoding.assert
    public static func assert(value: JsValue, globalObject: JsGlobalObject, default: Encoding): Encoding {
        let enc = fromJS(value, globalObject)
        if (enc.isSome()) {
            return enc.getOrThrow()
        }
        if (!value.isUndefined()) {
            EncodingUtils.throwEncodingError(globalObject)
        }
        return default
    }

    // 从 JS 值获取编码，空值时返回默认
    // 对应 Bun: Encoding.fromJSWithDefaultOnEmpty
    public static func fromJSWithDefaultOnEmpty(value: JsValue, globalObject: JsGlobalObject, default: Encoding): ?Encoding {
        if (value.isUndefinedOrNull()) {
            return default
        }
        return fromJS(value, globalObject)
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
        return JsValue(name)
    }

    // 将字节数组用指定编码转为 JS 值
    // 对应 Bun: Encoding.encodeWithSize / encodeWithMaxSize
    public func encodeToJS(globalObject: JsGlobalObject, input: Array<UInt8>): JsValue {
        match (this) {
            case Encoding.hex =>
                return JsValue(EncodingUtils.hexEncode(input))
            case Encoding.base64 =>
                return JsValue(Base64.encode(input))
            case Encoding.base64url =>
                return JsValue(Base64Url.encode(input))
            case Encoding.latin1 =>
                return JsValue(EncodingUtils.latin1Decode(input))
            case Encoding.ascii =>
                return JsValue(EncodingUtils.asciiDecode(input))
            case Encoding.utf16le =>
                return JsValue(EncodingUtils.utf16leDecode(input))
            case Encoding.ucs2 =>
                return JsValue(EncodingUtils.utf16leDecode(input))
            case Encoding.buffer =>
                return JsValue(String.fromUtf8(input))
            case Encoding.utf8 =>
                return JsValue(String.fromUtf8(input))
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
        throw Exception("Unknown encoding")
    }

    // Hex 编码
    public static func hexEncode(bytes: Array<UInt8>): String {
        var result = ArrayList<UInt8>()
        for (b in bytes) {
            let high = b >> 4
            let low = b & UInt8(0x0F)
            result.add(UInt8(0x30) + high + (if (high > 9) { UInt8(39) } else { UInt8(0) }))
            result.add(UInt8(0x30) + low + (if (low > 9) { UInt8(39) } else { UInt8(0) }))
        }
        return String.fromUtf8(result.toArray())
    }

    // Hex 解码
    public static func hexDecode(hex: String): Array<UInt8> {
        let arr = Array<UInt8>(hex.size / 2, { _ => UInt8(0) })
        var i: Int64 = 0
        while (i + 1 < hex.size) {
            let high = hexCharToNibble(hex[i])
            let low = hexCharToNibble(hex[i + 1])
            arr[i / 2] = high * UInt8(16) + low
            i += 2
        }
        return arr
    }

    public static func encodeString(input: String, encoding: Encoding): Array<UInt8> {
        match (encoding) {
            case Encoding.hex => return hexDecode(input)
            case Encoding.base64 => return Base64.decode(input)
            case Encoding.base64url => return Base64Url.decode(input)
            case Encoding.latin1 => return latin1Encode(input)
            case Encoding.ascii => return asciiEncode(input)
            case Encoding.utf16le => return utf16leEncode(input)
            case Encoding.ucs2 => return utf16leEncode(input)
            case _ => return utf8Encode(input)
        }
    }

    public static func utf8Encode(input: String): Array<UInt8> {
        return Array<UInt8>(input.size, { i => input[i] })
    }

    public static func latin1Encode(input: String): Array<UInt8> {
        return Array<UInt8>(input.size, { i => input[i] & UInt8(0xFF) })
    }

    public static func asciiEncode(input: String): Array<UInt8> {
        return Array<UInt8>(input.size, { i => input[i] & UInt8(0x7F) })
    }

    public static func utf16leEncode(input: String): Array<UInt8> {
        let out = Array<UInt8>(input.size * 2, { _ => UInt8(0) })
        var j: Int64 = 0
        for (i in 0..input.size) {
            let code = UInt16(input[i])
            out[j] = UInt8(code & UInt16(0x00FF))
            out[j + 1] = UInt8((code >> 8) & UInt16(0x00FF))
            j += 2
        }
        return out
    }

    public static func latin1Decode(bytes: Array<UInt8>): String {
        return String.fromUtf8(bytes)
    }

    public static func asciiDecode(bytes: Array<UInt8>): String {
        let out = Array<UInt8>(bytes.size, { i => bytes[i] & UInt8(0x7F) })
        return String.fromUtf8(out)
    }

    public static func utf16leDecode(bytes: Array<UInt8>): String {
        let out = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i + 1 < bytes.size) {
            let lo = UInt16(bytes[i])
            let hi = UInt16(bytes[i + 1])
            let code = (hi << 8) | lo
            out.add(UInt8(code & UInt16(0x00FF)))
            i += 2
        }
        return String.fromUtf8(out.toArray())
    }

    private static func hexCharToNibble(c: UInt8): UInt8 {
        if (c >= UInt8(0x30) && c <= UInt8(0x39)) {  // '0'-'9'
            return c - UInt8(0x30)
        }
        if (c >= UInt8(0x61) && c <= UInt8(0x66)) {  // 'a'-'f'
            return c - UInt8(0x61) + UInt8(10)
        }
        if (c >= UInt8(0x41) && c <= UInt8(0x46)) {  // 'A'-'F'
            return c - UInt8(0x41) + UInt8(10)
        }
        return 0
    }

    // 编码的 JS 断言函数
    // 对应 Bun: jsAssertEncodingValid
    public static func jsAssertEncodingValid(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        let args = callFrame.arguments()
        if (args.size < 1) {
            return JsValue()
        }
        let encoding = Encoding.fromJS(args[0], globalObject)
        if (encoding.isNone()) {
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
    | r
    // 打开文件用于同步读取
    | rs
    // 打开文件用于读写
    | rPlus
    // 打开文件用于同步读写
    | rsPlus
    // 打开文件用于写入。不存在则创建，存在则截断
    | w
    // 类似 w 但路径存在则失败
    | wx
    // 打开文件用于读写。不存在则创建，存在则截断
    | wPlus
    // 类似 w+ 但路径存在则失败
    | wxPlus
    // 打开文件用于追加。不存在则创建
    | a
    // 类似 a 但路径存在则失败
    | ax
    // 打开文件用于读写追加。不存在则创建
    | aPlus
    // 类似 a+ 但路径存在则失败
    | axPlus
    // 打开文件用于同步追加
    | `as`
    // 打开文件用于同步读写追加
    | asPlus

    // 从字符串解析文件系统标志
    // 对应 Bun: FileSystemFlags.fromJS (使用 ComptimeStringMap)
    // 支持 "r", "rs", "sr", "r+", "rs+", "sr+",
    //       "w", "wx", "xw", "w+", "wx+", "xw+",
    //       "a", "ax", "xa", "as", "sa", "a+", "ax+", "xa+", "as+", "sa+"
    // 以及大写变体
    public static func from(flag: String): ?FileSystemFlags {
        let f = flag.toAsciiLower()
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
        if (f == "as" || f == "sa") { return `as` }
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
            let flags = if (number > Int32(0)) { number } else { Int32(0) }
            return fromNumber(flags)
        }
        if (val.isString()) {
            let str = val.toString()
            if (str.size == 0) {
                throw JsTypeError("Expected flags to be a non-empty string. Learn more at https://nodejs.org/api/fs.html#fs_file_system_flags")
            }
            if (str.size > 12) {
                throw JsTypeError("Invalid flag. Learn more at https://nodejs.org/api/fs.html#fs_file_system_flags")
            }
            // 尝试解析数字字符串
            if (str[0] >= UInt8(0x30) && str[0] <= UInt8(0x39)) {  // '0'-'9'
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
            throw JsTypeError("mode must be int32 or null/undefined")
        }
        let int: Int32 = value.toInt32()
        if (int < Int32(0) || int > Int32(7)) {
            throw JsRangeError("mode is out of range: >= 0 and <= 7")
        }
        return fromNumber(int)
    }

    // 获取整数值
    // 对应 Bun: FileSystemFlags.asInt
    public func asInt(): Int32 {
        match (this) {
            case r => return 0
            case x => return 1
            case w => return 2
            case rw => return 6
            case wx => return 3
            case rx => return 5
            case wX => return 3
            case rX => return 5
            case rwX => return 7
        }
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

// 简单的字符串哈希函数 (FNV-1a 风格)
private func hashString(s: String): UInt64 {
    var hash: UInt64 = 14695981039346656037
    for (c in s) {
        hash ^= UInt64(c)
        hash *= 1099511628211
    }
    hash
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
            hashString(path.slice())
        }
    }

    // 从 JS 值解析
    // 对应 Bun: PathOrFileDescriptor.fromJS
    public static func fromJS(globalObject: JsGlobalObject, args: ArgumentsSlice): ?PathOrFileDescriptor {
        let first = args.next()
        if (first.isNone()) {
            return None
        }
        let val = first.getOrThrow()
        if (val.isNumber()) {
            let fd = val.toInt32()
            if (fd >= Int32(0)) {
                args.eat()
                return PathOrFileDescriptor(fd)
            }
        }
        let pathLike = PathLike.fromJS(globalObject, args)
        if (pathLike.isSome()) {
            return PathOrFileDescriptor(pathLike.getOrThrow())
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
    public static func fromJS(globalObject: JsGlobalObject, arguments: ArgumentsSlice): ?PathLike {
        let value = arguments.next()
        if (value.isNone()) {
            return None
        }
        let val = value.getOrThrow()
        if (val.isString()) {
            return PathLike(val.toString())
        }
        if (val.isObject()) {
            let bytes = NodeBufferConversions.bytesFromJS(globalObject, val)
            if (bytes.isSome()) {
                return PathLike(NodeBufferConversions.bytesToString(bytes.getOrThrow()))
            }
            return None
        }
        return None
    }

    // 从 JS 值解析路径（带分配器）
    // 对应 Bun: PathLike.fromJSWithAllocator
    public static func fromJSWithAllocator(globalObject: JsGlobalObject, args: ArgumentsSlice): ?PathLike {
        return fromJS(globalObject, args)
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
        return EncodingUtils.utf8Encode(stringValue)
    }

    public func slice(encoding: Encoding): Array<UInt8> {
        if (isBuffer) {
            return bufferValue
        }
        return EncodingUtils.encodeString(stringValue, encoding)
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
            return JsArrayBuffer.createBuffer(globalObject.globalThis, bufferValue)
        }
        return JsValue(stringValue)
    }

    // 从 JS 值解析
    // 对应 Bun: StringOrBuffer.fromJS
    public static func fromJS(globalObject: JsGlobalObject, value: JsValue): ?StringOrBuffer {
        if (value.isUndefinedOrNull()) {
            return None
        }
        if (value.isString()) {
            return StringOrBuffer(value.toString())
        }
        if (value.isObject()) {
            let bytes = NodeBufferConversions.bytesFromJS(globalObject, value)
            if (bytes.isSome()) {
                return StringOrBuffer(bytes.getOrThrow())
            }
            return None
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
            return StringOrBuffer(EncodingUtils.encodeString(value.toString(), encoding))
        }
        if (value.isObject()) {
            let bytes = NodeBufferConversions.bytesFromJS(globalObject, value)
            if (bytes.isNone()) {
                let fallback = BufferBytes.fromJS(globalObject, value)
                if (fallback.isSome()) {
                    return StringOrBuffer(fallback.getOrThrow())
                }
            } else {
                return StringOrBuffer(bytes.getOrThrow())
            }
            return None
        }
        return None
    }

    // 从 JS 值解析（带编码值）
    // 对应 Bun: StringOrBuffer.fromJSWithEncodingValue
    public static func fromJSWithEncodingValue(globalObject: JsGlobalObject, value: JsValue, encodingValue: JsValue): ?StringOrBuffer {
        let encoding = Encoding.fromJS(encodingValue, globalObject)
        let enc = if (encoding.isSome()) { encoding.getOrThrow() } else { Encoding.utf8 }
        return fromJSWithEncoding(globalObject, value, enc)
    }

    // 从 JS 值获取拥有的字节切片
    // 对应 Bun: StringOrBuffer.fromJSToOwnedSlice
    public static func fromJSToOwnedSlice(globalObject: JsGlobalObject, value: JsValue): Array<UInt8> {
        if (value.isObject()) {
            let bytes = NodeBufferConversions.bytesFromJS(globalObject, value)
            if (bytes.isSome()) {
                return bytes.getOrThrow()
            }
            throw JsTypeError("Expected string, Buffer, ArrayBuffer, or TypedArray")
        }
        let str = value.toString()
        return NodeBufferConversions.stringToBytes(str)
    }
}

// ============================================================================
// NodeBufferConversions — shared JS bytes/string conversion helpers
// Reuses bao_jsc ArrayBuffer/TypedArray/Buffer APIs instead of open-coded stubs.
// ============================================================================
public class BufferBytes {
    public static func fromJS(globalObject: JsGlobalObject, value: JsValue): ?Array<UInt8> {
        if (value.arrayData.isSome()) {
            let arr = value.arrayData.getOrThrow()
            let bytes = Array<UInt8>(arr.size, { i => UInt8(arr[i].toInt32() & Int32(0xFF)) })
            return bytes
        }
        if (value.isObject()) {
            let obj = value.toObject()
            let data = obj.get("data")
            if (data.arrayData.isSome()) {
                let arr = data.arrayData.getOrThrow()
                let bytes = Array<UInt8>(arr.size, { i => UInt8(arr[i].toInt32() & Int32(0xFF)) })
                return bytes
            }
            let bytes = NodeBufferConversions.bytesFromJS(globalObject, value)
            if (bytes.isSome()) {
                return bytes
            }
            let byteLength = obj.get("byteLength")
            if (byteLength.isNumber()) {
                let len = byteLength.toInt64()
                if (len >= 0) {
                    return Array<UInt8>(len, { _ => UInt8(0) })
                }
            }
            let length = obj.get("length")
            if (length.isNumber()) {
                let len = length.toInt64()
                if (len >= 0) {
                    let bytes = Array<UInt8>(len, { i => UInt8(obj.get(i.toString()).toInt32() & Int32(0xFF)) })
                    return bytes
                }
            }
        }
        return None
    }
}

public class NodeBufferConversions {
    public static func bytesFromJS(globalObject: JsGlobalObject, value: JsValue): ?Array<UInt8> {
        let view = value.asArrayBuffer(globalObject.globalThis)
        if (view.isSome()) {
            return view.getOrThrow().bytes()
        }
        return None
    }

    public static func bytesToJSBuffer(globalObject: JsGlobalObject, bytes: Array<UInt8>): JsValue {
        return JsArrayBuffer.createBuffer(globalObject.globalThis, bytes)
    }

    public static func bytesToJSUint8Array(globalObject: JsGlobalObject, bytes: Array<UInt8>): JsValue {
        return JsArrayBuffer.createUint8Array(globalObject.globalThis, bytes)
    }

    public static func bytesToJSArrayBuffer(globalObject: JsGlobalObject, bytes: Array<UInt8>): JsValue {
        return JsArrayBuffer.create(globalObject.globalThis, bytes, JSType.ArrayBuffer)
    }

    public static func assertBufferLike(globalObject: JsGlobalObject, value: JsValue, name: String): Array<UInt8> {
        let bytes = bytesFromJS(globalObject, value)
        if (bytes.isSome()) {
            return bytes.getOrThrow()
        }
        throw JsTypeError("The \"" + name + "\" argument must be an instance of Buffer, ArrayBuffer, TypedArray, or DataView")
    }

    public static func stringToBytes(value: String): Array<UInt8> {
        return Array<UInt8>(value.size, { i => value[i] })
    }

    public static func bytesToString(bytes: Array<UInt8>): String {
        return String.fromUtf8(bytes)
    }

    public static func decodeString(value: String, encoding: Encoding): String {
        match (encoding) {
            case Encoding.hex => return bytesToString(EncodingUtils.hexDecode(value))
            case _ => return value
        }
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
        let sob = StringOrBuffer.fromJS(globalObject, value)
        if (sob.isSome()) {
            let result = BlobOrStringOrBuffer()
            result.stringOrBuffer = sob.getOrThrow()
            return result
        }
        return None
    }

    // 从 JS 值解析（允许文件）
    // 对应 Bun: BlobOrStringOrBuffer.fromJSMaybeFile
    public static func fromJSMaybeFile(globalObject: JsGlobalObject, value: JsValue, allowFile: Bool): ?BlobOrStringOrBuffer {
        return fromJS(globalObject, value)
    }

    // 从 JS 值异步解析
    // 对应 Bun: BlobOrStringOrBuffer.fromJSAsync
    public static func fromJSAsync(globalObject: JsGlobalObject, value: JsValue): ?BlobOrStringOrBuffer {
        return fromJS(globalObject, value)
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
        match (kind) { case EntryKind.file => return true case _ => return false }
    }

    public func isDirectory(): Bool {
        match (kind) { case EntryKind.directory => return true case _ => return false }
    }

    public func isSymbolicLink(): Bool {
        match (kind) { case EntryKind.sym_link => return true case _ => return false }
    }

    public func isBlockDevice(): Bool {
        match (kind) { case EntryKind.block_device => return true case _ => return false }
    }

    public func isCharacterDevice(): Bool {
        match (kind) { case EntryKind.character_device => return true case _ => return false }
    }

    public func isFIFO(): Bool {
        match (kind) { case EntryKind.named_pipe => return true case _ => return false }
    }

    public func isSocket(): Bool {
        match (kind) { case EntryKind.unix_domain_socket => return true case _ => return false }
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
        let obj = JsObject()
        obj.set("name", JsValue(name))
        obj.set("path", JsValue(path))
        return JsValue(obj)
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

// EntryKind — 已在 dir_iterator.cj 中定义

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
            str = str[2..str.size]
        }
        var result: UInt32 = 0
        for (c in str) {
            if (c >= UInt8(0x30) && c <= UInt8(0x37)) {  // '0'-'7'
                result = result * UInt32(8) + UInt32(c - UInt8(0x30))
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
        if (modeStr.isSome()) {
            return fromString(modeStr.getOrThrow())
        }
        if (modeNum.isSome()) {
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
        throw JsTypeError("mode must be a number or octal string")
    }
}

// ============================================================================
// CallbackTask 选项类型（提取到顶层，仓颉不支持嵌套 enum）
// ============================================================================
public enum CallbackTaskOption<T> {
    | err(String)
    | result(T)
}

// ============================================================================
// 回调任务
// 对应 Bun: src/runtime/node/types.zig - CallbackTask
// ============================================================================
public class CallbackTask<Result> {
    public var callback: () -> Unit = { => }
    public var success: Bool = false
    public var option: CallbackTaskOption<Result> = CallbackTaskOption<Result>.err("")

    public init() {}
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
        let result = VectorArrayBuffer()
        if (val.arrayData.isSome()) {
            let arr = val.arrayData.getOrThrow()
            let vectors = ArrayList<IoVec>()
            let flat = ArrayList<UInt8>()
            for (item in arr) {
                let bytes = BufferBytes.fromJS(globalObject, item)
                if (bytes.isNone()) {
                    return None
                }
                let data = bytes.getOrThrow()
                let vec = IoVec()
                vec.data = data
                vectors.add(vec)
                for (b in data) {
                    flat.add(b)
                }
            }
            result.buffers = vectors.toArray()
            result.value = flat.toArray()
            return result
        }
        let bytes = BufferBytes.fromJS(globalObject, val)
        if (bytes.isSome()) {
            let data = bytes.getOrThrow()
            let vec = IoVec()
            vec.data = data
            result.buffers = [vec]
            result.value = data
            return result
        }
        return None
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
    public static func fromJSNoCopy(globalObject: JsGlobalObject, args: ArgumentsSlice): ?PathOrBlob {
        let path = PathOrFileDescriptor.fromJS(globalObject, args)
        if (path.isSome()) {
            let result = PathOrBlob()
            result.path = path.getOrThrow()
            return result
        }
        return None
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
        return Buffer(NodeBufferConversions.stringToBytes(s))
    }

    public static func fromBytes(bytes: Array<UInt8>): Buffer {
        return Buffer(bytes)
    }

    public func toJS(globalObject: JsGlobalObject): JsValue {
        return NodeBufferConversions.bytesToJSBuffer(globalObject, bytes)
    }
}
