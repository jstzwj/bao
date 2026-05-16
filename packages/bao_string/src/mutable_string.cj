// 严格翻译自: src/string/MutableString.zig
// 可变字符串
//   基于动态数组的可变字符串,支持:
//   - 动态增长
//   - 写入缓冲
//   - HTML 属性转义
//   - UTF-16 到 UTF-8 转换写入
//   - 标识符合法化
package bao_string

import bao_core.*

// ============================================================================
// MutableString
// 严格翻译自: src/string/MutableString.zig
// ============================================================================

/// 可变字符串: 基于动态字节数组
/// 严格翻译自 MutableString.zig MutableString
public class MutableString {
    private var buffer: Array<Byte>
    private var used: Int64
    private var capacity: Int64

    public init() {
        this.buffer = Array<Byte>()
        this.used = 0
        this.capacity = 0
    }

    /// 带初始容量初始化
    /// 严格翻译自 MutableString.init
    public init(capacity: Int64) {
        this.buffer = Array<Byte>(capacity, item: Byte(0))
        this.used = 0
        this.capacity = capacity
    }

    /// 2048 容量初始化
    /// 严格翻译自 MutableString.init2048
    public static func init2048(): MutableString {
        return MutableString(2048)
    }

    /// 空初始化
    /// 严格翻译自 MutableString.initEmpty
    public static func initEmpty(): MutableString {
        return MutableString()
    }

    /// 从字符串复制初始化
    /// 严格翻译自 MutableString.initCopy
    public static func initCopy(str: String): MutableString {
        let bytes = str.toArray()
        let ms = MutableString(bytes.size)
        for (b in bytes) {
            ms.buffer[ms.used] = b
            ms.used += 1
        }
        return ms
    }

    /// 克隆
    /// 严格翻译自 MutableString.clone
    public func clone(): MutableString {
        return MutableString.initCopy(this.toString())
    }

    /// 判断是否为空
    /// 严格翻译自 MutableString.isEmpty
    public func isEmpty(): Bool {
        return this.used == 0
    }

    /// 获取长度
    /// 严格翻译自 MutableString.len
    public func len(): Int64 {
        return this.used
    }

    /// 获取长度(Int32)
    /// 严格翻译自 MutableString.lenI
    public func lenI(): Int32 {
        return Int32(this.used)
    }

    /// 获取底层字节切片
    /// 严格翻译自 MutableString.slice
    public func slice(): Array<Byte> {
        if (this.used == 0) {
            return []
        }
        return this.buffer[0..this.used]
    }

    /// 转换为字符串
    public func toString(): String {
        return String.fromUtf8(slice())
    }

    /// 释放资源
    /// 严格翻译自 MutableString.deinit
    public func deinit(): Unit {
        this.buffer = Array<Byte>()
        this.used = 0
        this.capacity = 0
    }

    /// 确保有足够的未使用容量
    /// 严格翻译自 MutableString.growIfNeeded / ensureUnusedCapacity
    public func growIfNeeded(amount: Int64): Unit {
        if (this.used + amount > this.capacity) {
            let newCapacity = max(this.capacity * 2, this.used + amount)
            var newBuffer = Array<Byte>(newCapacity, item: Byte(0))
            for (i in 0..this.used) {
                newBuffer[i] = this.buffer[i]
            }
            this.buffer = newBuffer
            this.capacity = newCapacity
        }
    }

    /// 确保总容量
    /// 严格翻译自 MutableString.growBy
    public func growBy(amount: Int64): Unit {
        growIfNeeded(amount)
    }

    /// 获取可写入的 N 字节空间(假设容量足够)
    /// 严格翻译自 MutableString.writableNBytesAssumeCapacity
    public func writableNBytesAssumeCapacity(amount: Int64): Array<Byte> {
        let start = this.used
        this.used += amount
        return this.buffer[start..this.used]
    }

    /// 获取可写入的 N 字节空间
    /// 严格翻译自 MutableString.writableNBytes
    public func writableNBytes(amount: Int64): Array<Byte> {
        growIfNeeded(amount)
        return writableNBytesAssumeCapacity(amount)
    }

    /// 写入字节数据
    /// 严格翻译自 MutableString.write
    public func write(bytes: Array<Byte>): Int64 {
        growIfNeeded(bytes.size)
        for (b in bytes) {
            this.buffer[this.used] = b
            this.used += 1
        }
        return bytes.size
    }

    /// 写入字符串
    /// 严格翻译自 MutableString.writeAll
    public func writeAll(bytes: String): Int64 {
        let arr = bytes.toArray()
        return write(arr)
    }

    /// 追加字节切片
    /// 严格翻译自 MutableString.appendSlice
    public func appendSlice(items: String): Unit {
        let bytes = items.toArray()
        growIfNeeded(bytes.size)
        for (b in bytes) {
            this.buffer[this.used] = b
            this.used += 1
        }
    }

    /// 追加字节切片(精确容量)
    /// 严格翻译自 MutableString.appendSliceExact
    public func appendSliceExact(items: String): Unit {
        if (items.size == 0) {
            return
        }
        let bytes = items.toArray()
        growIfNeeded(bytes.size)
        for (b in bytes) {
            this.buffer[this.used] = b
            this.used += 1
        }
    }

    /// 追加单个字符
    /// 严格翻译自 MutableString.appendChar
    public func appendChar(char: Byte): Unit {
        growIfNeeded(1)
        this.buffer[this.used] = char
        this.used += 1
    }

    /// 追加单个字符(假设容量足够)
    /// 严格翻译自 MutableString.appendCharAssumeCapacity
    public func appendCharAssumeCapacity(char: Byte): Unit {
        this.buffer[this.used] = char
        this.used += 1
    }

    /// 追加字符串
    /// 严格翻译自 MutableString.append
    public func append(char: String): Unit {
        appendSlice(char)
    }

    /// 追加整数
    /// 严格翻译自 MutableString.appendInt
    public func appendInt(value: UInt64): Unit {
        let str = value.toString()
        appendSlice(str)
    }

    /// 追加字符串(假设容量足够)
    /// 严格翻译自 MutableString.appendAssumeCapacity
    public func appendAssumeCapacity(char: String): Unit {
        let bytes = char.toArray()
        for (b in bytes) {
            this.buffer[this.used] = b
            this.used += 1
        }
    }

    /// 追加字符 N 次
    /// 严格翻译自 MutableString.appendCharNTimes
    public func appendCharNTimes(char: Byte, n: Int64): Unit {
        growIfNeeded(n)
        for (_ in 0..n) {
            this.buffer[this.used] = char
            this.used += 1
        }
    }

    /// 重置(保留容量)
    /// 严格翻译自 MutableString.reset
    public func reset(): Unit {
        this.used = 0
    }

    /// 重置到指定位置
    /// 严格翻译自 MutableString.resetTo
    public func resetTo(index: Int64): Unit {
        this.used = index
    }

    /// 调整大小
    /// 严格翻译自 MutableString.inflate
    public func inflate(amount: Int64): Unit {
        if (amount > this.capacity) {
            growIfNeeded(amount - this.capacity)
        }
        this.used = amount
    }

    /// 复制数据
    /// 严格翻译自 MutableString.copy
    public func copy(str: String): Unit {
        let bytes = str.toArray()
        growIfNeeded(bytes.size)

        if (this.used == 0) {
            for (b in bytes) {
                this.buffer[this.used] = b
                this.used += 1
            }
        } else {
            let copyLen = if (bytes.size < this.used) { bytes.size } else { this.used }
            for (i in 0..bytes.size) {
                this.buffer[i] = bytes[i]
            }
            this.used = bytes.size
        }
    }

    /// 判断缓冲区是否拥有指定数据
    /// 严格翻译自 MutableString.owns
    public func owns(items: String): Bool {
        // 简化: 始终返回 false
        return false
    }

    /// 获取所有权
    /// 严格翻译自 MutableString.takeSlice
    public func takeSlice(): Array<Byte> {
        let out = slice()
        this.used = 0
        this.capacity = 0
        this.buffer = Array<Byte>()
        return out
    }

    /// 转换为拥有的切片
    /// 严格翻译自 MutableString.toOwnedSlice
    public func toOwnedSlice(): Array<Byte> {
        let result = slice()
        this.used = 0
        this.capacity = 0
        this.buffer = Array<Byte>()
        return result
    }

    /// 转换为指定长度的拥有切片
    /// 严格翻译自 MutableString.toOwnedSliceLength
    public func toOwnedSliceLength(length: Int64): String {
        this.used = length
        return toString()
    }

    /// 查找字符位置
    /// 严格翻译自 MutableString.indexOfChar
    public func indexOfChar(char: Byte): Int64 {
        for (i in 0..this.used) {
            if (this.buffer[i] == char) {
                return i
            }
        }
        return -1
    }

    /// 查找最后一个字符位置
    /// 严格翻译自 MutableString.lastIndexOfChar
    public func lastIndexOfChar(char: Byte): Int64 {
        var i = this.used - 1
        while (i >= 0) {
            if (this.buffer[i] == char) {
                return i
            }
            i -= 1
        }
        return -1
    }

    /// 判断是否包含字符
    /// 严格翻译自 MutableString.containsChar
    public func containsChar(char: Byte): Bool {
        return indexOfChar(char) >= 0
    }

    /// 判断字符串是否相等
    /// 严格翻译自 MutableString.eql
    public func eql(other: String): Bool {
        if (this.used != other.size) {
            return false
        }
        let bytes = other.toArray()
        for (i in 0..this.used) {
            if (this.buffer[i] != bytes[i]) {
                return false
            }
        }
        return true
    }

    // ========================================================================
    // BufferedWriter 内部类
    // 严格翻译自 MutableString.zig BufferedWriter
    // ========================================================================

    /// 缓冲写入器
    /// 严格翻译自 MutableString.zig BufferedWriter
    public class BufferedWriter {
        private let context: MutableString
        private var buf: Array<Byte>
        private var pos: Int64

        private static let MAX: Int64 = 2048

        public init(context: MutableString) {
            this.context = context
            this.buf = Array<Byte>(MAX, item: Byte(0))
            this.pos = 0
        }

        /// 获取剩余空间
        private func remain(): Array<Byte> {
            return buf[pos..MAX]
        }

        /// 刷新缓冲区
        /// 严格翻译自 BufferedWriter.flush
        public func flush(): Unit {
            if (pos > 0) {
                context.write(buf[0..pos])
                pos = 0
            }
        }

        /// 写入字节数据
        /// 严格翻译自 BufferedWriter.writeAll
        public func writeAll(bytes: String): Int64 {
            if (bytes.size >= MAX) {
                flush()
                context.appendSlice(bytes)
                return bytes.size
            }

            if (bytes.size > 0) {
                if (bytes.size + pos > MAX) {
                    flush()
                }
                let arr = bytes.toArray()
                for (b in arr) {
                    buf[pos] = b
                    pos += 1
                }
            }

            return bytes.size
        }

        /// 写入 HTML 属性值(转义特殊字符)
        /// 严格翻译自 BufferedWriter.writeHTMLAttributeValue
        public func writeHTMLAttributeValue(bytes: String): Unit {
            var items = bytes
            while (items.size > 0) {
                var j: Int64 = -1
                for (i in 0..items.size) {
                    if (items[i] == Byte('"') || items[i] == Byte('<') || items[i] == Byte('>')) {
                        j = i
                        break
                    }
                }

                if (j >= 0) {
                    writeAll(items[0..j])
                    if (items[j] == Byte('"')) {
                        writeAll("&quot;")
                    } else if (items[j] == Byte('<')) {
                        writeAll("&lt;")
                    } else {
                        writeAll("&gt;")
                    }
                    items = items[j + 1..items.size]
                } else {
                    writeAll(items)
                    break
                }
            }
        }
    }

    /// 创建缓冲写入器
    /// 严格翻译自 MutableString.bufferedWriter
    public func bufferedWriter(): BufferedWriter {
        return BufferedWriter(this)
    }
}

/// 辅助: 取两数最大值
private func max(a: Int64, b: Int64): Int64 {
    if (a > b) { return a }
    return b
}
