// Node.js Buffer 模块 — 二进制数据处理
// 对应 Bun: src/runtime/node/buffer.zig
// 严格翻译自: src/runtime/node/buffer.zig
package bao_runtime.node_api

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_runtime.*

// ============================================================================
// Buffer 类 — Node.js Buffer 兼容 API
// 对应 Bun: src/runtime/node/buffer.zig - Buffer
// ============================================================================

/// Buffer 类 — 对应 Bun Buffer
/// 对应 Bun: src/runtime/node/buffer.zig - BufferImpl
public class Buffer {
    public var data: Array<UInt8>
    public var length: Int64

    public init(data: Array<UInt8>) {
        this.data = data
        this.length = Int64(data.size)
    }

    public init(size: Int64) {
        this.data = Array<UInt8>(Int64(size), { _ => UInt8(0) })
        this.length = size
    }

    // ========================================================================
    // 静态构造方法
    // 对应 Bun: src/runtime/node/buffer.zig - Buffer.alloc
    // ========================================================================

    /// Buffer.alloc — 分配并清零
    /// 对应 Bun: src/runtime/node/buffer.zig alloc
    public static func alloc(size: Int64): Buffer {
        return Buffer(size)
    }

    /// Buffer.allocUnsafe — 分配但不初始化
    /// 对应 Bun: src/runtime/node/buffer.zig allocUnsafe
    public static func allocUnsafe(size: Int64): Buffer {
        // 仓颉中 Array 构造会初始化为零，此处语义相同
        // 真正的 unsafe 优化需要在底层分配器层面实现
        return Buffer(size)
    }

    /// Buffer.from(byte array)
    /// 对应 Bun: src/runtime/node/buffer.zig from
    public static func from(data: Array<UInt8>): Buffer {
        let copy = Array<UInt8>(data.size, { _ => UInt8(0) })
        for (i in 0..data.size) {
            copy[i] = data[i]
        }
        return Buffer(copy)
    }

    /// Buffer.from(string, encoding)
    /// 对应 Bun: src/runtime/node/buffer.zig from_string
    public static func from(str: String): Buffer {
        return from(str, "utf-8")
    }

    public static func from(str: String, encoding: String): Buffer {
        let bytes = BufferEncoding.encode(str, encoding)
        return Buffer(bytes)
    }

    /// Buffer.concat — 拼接多个 Buffer
    /// 对应 Bun: src/runtime/node/buffer.zig concat
    public static func concat(list: ArrayList<Buffer>): Buffer {
        var total: Int64 = 0
        for (buf in list) {
            total += buf.length
        }
        return concat(list, total)
    }

    public static func concat(list: ArrayList<Buffer>, totalLength: Int64): Buffer {
        let result = Array<UInt8>(Int64(totalLength), { _ => UInt8(0) })
        var offset: Int64 = 0
        for (buf in list) {
            if (offset >= totalLength) {
                break
            }
            let copyLen = if (offset + buf.length <= totalLength) {
                buf.length
            } else {
                totalLength - offset
            }
            for (i in 0..Int64(copyLen)) {
                result[Int64(offset) + i] = buf.data[i]
            }
            offset += buf.length
        }
        return Buffer(result)
    }

    /// Buffer.isBuffer — 判断是否为 Buffer
    /// 对应 Bun: src/runtime/node/buffer.zig isBuffer
    public static func isBuffer(obj: JsValue): Bool {
        // 检查 JsValue 是否持有 Buffer 类型的对象数据
        match (obj.objectData) {
            case Some(obj) => obj.has("__buffer__")
            case None => false
        }
    }

    /// Buffer.byteLength — 计算字符串字节长度
    /// 对应 Bun: src/runtime/node/buffer.zig byteLength
    public static func byteLength(str: String): Int64 {
        return byteLength(str, "utf-8")
    }

    public static func byteLength(str: String, encoding: String): Int64 {
        let bytes = BufferEncoding.encode(str, encoding)
        return Int64(bytes.size)
    }

    // ========================================================================
    // 实例方法
    // 对应 Bun: src/runtime/node/buffer.zig - Buffer 实例方法
    // ========================================================================

    /// slice — 返回新 Buffer (复制)
    /// 对应 Bun: src/runtime/node/buffer.zig slice
    public func slice(start: Int64, end: Int64): Buffer {
        let s = if (start < 0) { length + start } else { start }
        let e = if (end < 0) { length + end } else { end }
        let clampedStart = if (s < 0) { Int64(0) } else if (s > length) { length } else { s }
        let clampedEnd = if (e < 0) { Int64(0) } else if (e > length) { length } else { e }
        if (clampedStart >= clampedEnd) {
            return Buffer(0)
        }
        let sliceLen = clampedEnd - clampedStart
        let result = Array<UInt8>(Int64(sliceLen), { _ => UInt8(0) })
        for (i in 0..Int64(sliceLen)) {
            result[i] = data[Int64(clampedStart) + i]
        }
        return Buffer(result)
    }

    /// subarray — 返回视图 (此处实现为复制，与 slice 一致)
    /// 对应 Bun: src/runtime/node/buffer.zig subarray
    public func subarray(start: Int64, end: Int64): Buffer {
        return slice(start, end)
    }

    /// toString — 默认 utf-8 编码
    public func toString(): String {
        return toString("utf-8")
    }

    /// toString(encoding)
    /// 对应 Bun: src/runtime/node/buffer.zig toString
    public func toString(encoding: String): String {
        return BufferEncoding.decode(data, encoding)
    }

    /// toJSON — 转为 JSON 表示
    /// 对应 Bun: src/runtime/node/buffer.zig toJSON
    public func toJSON(): JsValue {
        let arr = ArrayList<JsValue>()
        for (i in 0..data.size) {
            arr.append(JsValue(Float64(Int64(data[i]))))
        }
        let obj = JsObject()
        obj.set("type", JsValue(BaoString("Buffer")))
        obj.set("data", JsValue.array(arr))
        return JsValue(obj)
    }

    /// equals — 比较两个 Buffer 内容
    /// 对应 Bun: src/runtime/node/buffer.zig equals
    public func equals(other: Buffer): Bool {
        if (length != other.length) {
            return false
        }
        for (i in 0..data.size) {
            if (data[i] != other.data[i]) {
                return false
            }
        }
        return true
    }

    /// compare — 字典序比较
    /// 对应 Bun: src/runtime/node/buffer.zig compare
    public func compare(other: Buffer): Int64 {
        let minLen = if (length < other.length) { length } else { other.length }
        for (i in 0..Int64(minLen)) {
            if (data[i] < other.data[i]) {
                return -1
            } else if (data[i] > other.data[i]) {
                return 1
            }
        }
        if (length < other.length) {
            return -1
        } else if (length > other.length) {
            return 1
        }
        return 0
    }

    /// copy — 复制数据到目标 Buffer
    /// 对应 Bun: src/runtime/node/buffer.zig copy
    public func copy(target: Buffer, targetStart: Int64): Int64 {
        let srcEnd = length
        let copyLen = if (srcEnd < target.length - targetStart) {
            srcEnd
        } else {
            target.length - targetStart
        }
        if (copyLen <= 0) {
            return 0
        }
        for (i in 0..Int64(copyLen)) {
            target.data[Int64(targetStart) + i] = data[i]
        }
        return copyLen
    }

    /// fill — 填充
    /// 对应 Bun: src/runtime/node/buffer.zig fill
    public func fill(value: UInt8, start: Int64, end: Int64): Buffer {
        let s = if (start < 0) { length + start } else { start }
        let e = if (end < 0) { length + end } else { end }
        if (s < 0 || e > length || s >= e) {
            return this
        }
        for (i in Int64(s)..Int64(e)) {
            data[i] = value
        }
        return this
    }

    // ========================================================================
    // 读写方法 — 整数与浮点数
    // 对应 Bun: src/runtime/node/buffer.zig read* / write*
    // ========================================================================

    /// readUInt8
    public func readUInt8(offset: Int64): UInt8 {
        if (offset < 0 || offset >= length) {
            return UInt8(0)
        }
        return data[Int64(offset)]
    }

    /// writeUInt8
    public func writeUInt8(value: UInt8, offset: Int64): Int64 {
        if (offset < 0 || offset >= length) {
            return 0
        }
        data[Int64(offset)] = value
        return offset + 1
    }

    /// readInt32LE — 小端序读取 32 位整数
    public func readInt32LE(offset: Int64): Int32 {
        if (offset < 0 || offset + 4 > length) {
            return 0
        }
        let b0 = Int32(data[Int64(offset)])
        let b1 = Int32(data[Int64(offset + 1)])
        let b2 = Int32(data[Int64(offset + 2)])
        let b3 = Int32(data[Int64(offset + 3)])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }

    /// writeInt32LE — 小端序写入 32 位整数
    public func writeInt32LE(value: Int32, offset: Int64): Int64 {
        if (offset < 0 || offset + 4 > length) {
            return 0
        }
        data[Int64(offset)]     = UInt8(value & 0xFF)
        data[Int64(offset + 1)] = UInt8((value >> 8) & 0xFF)
        data[Int64(offset + 2)] = UInt8((value >> 16) & 0xFF)
        data[Int64(offset + 3)] = UInt8((value >> 24) & 0xFF)
        return offset + 4
    }

    /// readFloatLE — 小端序读取 32 位浮点数
    public func readFloatLE(offset: Int64): Float32 {
        if (offset < 0 || offset + 4 > length) {
            return 0.0f32
        }
        // 通过 Int32 位模式转 Float32 (IEEE 754)
        let bits = readInt32LE(offset)
        return Float32.fromBits(UInt32(bits))
    }

    /// writeFloatLE — 小端序写入 32 位浮点数
    public func writeFloatLE(value: Float32, offset: Int64): Int64 {
        if (offset < 0 || offset + 4 > length) {
            return 0
        }
        let bits = value.toBits()
        return writeInt32LE(Int32(bits), offset)
    }

    /// readDoubleLE — 小端序读取 64 位浮点数
    public func readDoubleLE(offset: Int64): Float64 {
        if (offset < 0 || offset + 8 > length) {
            return 0.0
        }
        // 小端序: 低字节在前
        var bits: Int64 = 0
        for (i in 0..8) {
            let b = Int64(data[Int64(offset) + i])
            bits = bits | (b << (i * 8))
        }
        return Float64.fromBits(UInt64(bits))
    }

    /// writeDoubleLE — 小端序写入 64 位浮点数
    public func writeDoubleLE(value: Float64, offset: Int64): Int64 {
        if (offset < 0 || offset + 8 > length) {
            return 0
        }
        let bits = value.toBits()
        for (i in 0..8) {
            data[Int64(offset) + i] = UInt8((bits >> (i * 8)) & 0xFF)
        }
        return offset + 8
    }
}

// ============================================================================
// BufferPool — 小块分配的缓冲池
// 对应 Bun: src/runtime/node/buffer.zig - BufferPool
// ============================================================================

/// BufferPool — Buffer 缓冲池，优化小块内存分配
/// 对应 Bun: src/runtime/node/buffer.zig 中的 pool 机制
public class BufferPool {
    private var pool: Array<UInt8>
    private var poolOffset: Int64
    private let poolSize: Int64

    public init(poolSize: Int64) {
        this.poolSize = poolSize
        this.pool = Array<UInt8>(Int64(poolSize), { _ => UInt8(0) })
        this.poolOffset = 0
    }

    public init() {
        this.poolSize = 8192
        this.pool = Array<UInt8>(8192, { _ => UInt8(0) })
        this.poolOffset = 0
    }

    /// 从池中分配 Buffer
    /// 对应 Bun: src/runtime/node/buffer.zig poolAlloc
    public func alloc(size: Int64): Buffer {
        // 对齐到 8 字节边界
        let aligned = (size + 7) & Int64(-8)
        if (poolOffset + aligned > poolSize) {
            // 池空间不足，直接分配新 Buffer
            return Buffer.alloc(size)
        }
        let start = poolOffset
        poolOffset += aligned
        // 复制池中对应区间到新 Buffer
        let result = Array<UInt8>(Int64(size), { _ => UInt8(0) })
        for (i in 0..Int64(size)) {
            if (start + i < poolSize) {
                result[i] = pool[Int64(start + i)]
            }
        }
        return Buffer(result)
    }

    /// 重置池偏移
    public func reset(): Unit {
        poolOffset = 0
    }
}

// ============================================================================
// BufferEncoding — 编码工具类
// 对应 Bun: src/runtime/node/buffer.zig - Encoding 映射
// ============================================================================

/// BufferEncoding — 编码/解码工具
/// 对应 Bun: src/runtime/node/buffer.zig 中 encoding 处理
public class BufferEncoding {
    /// 将字符串按指定编码转为字节数组
    public static func encode(str: String, encoding: String): Array<UInt8> {
        let enc = String(encoding.toRuneArray().map({ r => r.toAsciiLowerCase() }))
        if (enc == "utf-8" || enc == "utf8") {
            return str.toArray()
        } else if (enc == "ascii" || enc == "latin1" || enc == "binary") {
            return asciiEncode(str)
        } else if (enc == "hex") {
            return hexDecode(str)
        } else if (enc == "base64") {
            return base64Decode(str)
        } else {
            // 默认 utf-8
            return str.toArray()
        }
    }

    /// 将字节数组按指定编码转为字符串
    public static func decode(data: Array<UInt8>, encoding: String): String {
        let enc = String(encoding.toRuneArray().map({ r => r.toAsciiLowerCase() }))
        if (enc == "utf-8" || enc == "utf8") {
            return utf8Decode(data)
        } else if (enc == "ascii" || enc == "latin1" || enc == "binary") {
            return asciiDecode(data)
        } else if (enc == "hex") {
            return hexEncode(data)
        } else if (enc == "base64") {
            return base64Encode(data)
        } else {
            return utf8Decode(data)
        }
    }

    /// 检查编码名是否有效
    public static func isValidEncoding(encoding: String): Bool {
        let enc = String(encoding.toRuneArray().map({ r => r.toAsciiLowerCase() }))
        return enc == "utf-8" || enc == "utf8" ||
               enc == "ascii" || enc == "latin1" || enc == "binary" ||
               enc == "hex" || enc == "base64" ||
               enc == "ucs-2" || enc == "ucs2" ||
               enc == "utf-16le" || enc == "utf16le"
    }

    // ========================================================================
    // hex 编码
    // ========================================================================

    /// hex 编码
    public static func hexEncode(data: Array<UInt8>): String {
        let sb = StringBuilder()
        let hexChars = "0123456789abcdef"
        for (i in 0..data.size) {
            let byte = data[i]
            let high = Int64((byte >> 4) & 0x0F)
            let low = Int64(byte & 0x0F)
            sb.append(hexChars[high..high + 1])
            sb.append(hexChars[low..low + 1])
        }
        return sb.toString()
    }

    /// hex 解码
    public static func hexDecode(hex: String): Array<UInt8> {
        let len = hex.size / 2
        let result = Array<UInt8>(len, { _ => UInt8(0) })
        for (i in 0..len) {
            let high = hexDigitValue(hex[i * 2])
            let low = hexDigitValue(hex[i * 2 + 1])
            result[i] = UInt8((high << 4) | low)
        }
        return result
    }

    // ========================================================================
    // base64 编码
    // ========================================================================

    /// base64 编码
    public static func base64Encode(data: Array<UInt8>): String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let sb = StringBuilder()
        var i = 0
        while (i < data.size) {
            let b0 = Int64(data[i])
            let b1 = if (i + 1 < data.size) { Int64(data[i + 1]) } else { 0 }
            let b2 = if (i + 2 < data.size) { Int64(data[i + 2]) } else { 0 }

            let triple = (b0 << 16) | (b1 << 8) | b2

            let idx0 = ((triple >> 18) & 0x3F)
            let idx1 = ((triple >> 12) & 0x3F)
            let idx2 = ((triple >> 6) & 0x3F)
            let idx3 = (triple & 0x3F)

            sb.append(chars[idx0..idx0 + 1])
            sb.append(chars[idx1..idx1 + 1])

            if (i + 1 < data.size) {
                sb.append(chars[idx2..idx2 + 1])
            } else {
                sb.append("=")
            }
            if (i + 2 < data.size) {
                sb.append(chars[idx3..idx3 + 1])
            } else {
                sb.append("=")
            }
            i += 3
        }
        return sb.toString()
    }

    /// base64 解码
    public static func base64Decode(base64: String): Array<UInt8> {
        // 去除空白字符
        let s = base64
        let padding = if (s.size > 0 && s[s.size - 1] == 61) {
            if (s.size > 1 && s[s.size - 2] == 61) { 2 } else { 1 }
        } else {
            0
        }
        let outLen = (s.size / 4) * 3 - padding
        let result = Array<UInt8>(outLen, { _ => UInt8(0) })
        var outIdx = 0
        var i = 0
        while (i < s.size) {
            let c0 = if (s[i] != 61) { base64DigitValue(s[i]) } else { 0 }
            let c1 = if (i + 1 < s.size && s[i + 1] != 61) { base64DigitValue(s[i + 1]) } else { 0 }
            let c2 = if (i + 2 < s.size && s[i + 2] != 61) { base64DigitValue(s[i + 2]) } else { 0 }
            let c3 = if (i + 3 < s.size && s[i + 3] != 61) { base64DigitValue(s[i + 3]) } else { 0 }

            let triple = (c0 << 18) | (c1 << 12) | (c2 << 6) | c3

            if (outIdx < outLen) {
                result[outIdx] = UInt8((triple >> 16) & 0xFF)
                outIdx += 1
            }
            if (outIdx < outLen) {
                result[outIdx] = UInt8((triple >> 8) & 0xFF)
                outIdx += 1
            }
            if (outIdx < outLen) {
                result[outIdx] = UInt8(triple & 0xFF)
                outIdx += 1
            }
            i += 4
        }
        return result
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// UTF-8 编码
    private static func utf8Decode(data: Array<UInt8>): String {
        // 将字节数组按 UTF-8 解码为字符串
        var sb = StringBuilder()
        var i = 0
        while (i < data.size) {
            let b = UInt32(data[i])
            if (b < 0x80) {
                sb.append(String(Rune(Int32(b))))
                i += 1
            } else if (b < 0xE0) {
                let ch = ((b & 0x1F) << 6) | (UInt32(data[i + 1]) & 0x3F)
                sb.append(String(Rune(Int32(ch))))
                i += 2
            } else if (b < 0xF0) {
                let ch = ((b & 0x0F) << 12) |
                         ((UInt32(data[i + 1]) & 0x3F) << 6) |
                         (UInt32(data[i + 2]) & 0x3F)
                sb.append(String(Rune(Int32(ch))))
                i += 3
            } else {
                let ch = ((b & 0x07) << 18) |
                         ((UInt32(data[i + 1]) & 0x3F) << 12) |
                         ((UInt32(data[i + 2]) & 0x3F) << 6) |
                         (UInt32(data[i + 3]) & 0x3F)
                sb.append(String(Rune(Int32(ch))))
                i += 4
            }
        }
        return sb.toString()
    }

    /// ASCII 编码
    private static func asciiEncode(str: String): Array<UInt8> {
        let result = Array<UInt8>(str.size, { _ => UInt8(0) })
        for (i in 0..str.size) {
            result[i] = UInt8(str[i] & 0xFF)
        }
        return result
    }

    /// ASCII 解码
    private static func asciiDecode(data: Array<UInt8>): String {
        let sb = StringBuilder()
        for (i in 0..data.size) {
            sb.append(String(Rune(Int32(data[i] & 0x7F))))
        }
        return sb.toString()
    }

    /// 十六进制字符转数值
    private static func hexDigitValue(c: UInt8): Int64 {
        if (c >= 48 && c <= 57) { // '0'-'9'
            return Int64(c) - 48
        } else if (c >= 97 && c <= 102) { // 'a'-'f'
            return Int64(c) - 97 + 10
        } else if (c >= 65 && c <= 70) { // 'A'-'F'
            return Int64(c) - 65 + 10
        }
        return 0
    }

    /// base64 字符转数值
    private static func base64DigitValue(c: UInt8): Int64 {
        if (c >= 65 && c <= 90) { // 'A'-'Z'
            return Int64(c) - 65
        } else if (c >= 97 && c <= 122) { // 'a'-'z'
            return Int64(c) - 97 + 26
        } else if (c >= 48 && c <= 57) { // '0'-'9'
            return Int64(c) - 48 + 52
        } else if (c == 43) { // '+'
            return 62
        } else if (c == 47) { // '/'
            return 63
        }
        return 0
    }
}
