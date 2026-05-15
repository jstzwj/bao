// 严格翻译自: src/string/StringBuilder.zig
// 字符串构建器
//   预分配缓冲区用于高效构建字符串
//   工作流程: count(计数) -> allocate(分配) -> append(追加)
//   适用于已知总长度时的一次性构建
package bao_string

import bao_core.*

// ============================================================================
// StringPointer
// 描述字符串在缓冲区中的位置
// ============================================================================

/// 字符串指针: 描述在 StringBuilder 缓冲区中的偏移和长度
/// 严格翻译自 bun.StringPointer
public class StringPointer {
    public var offset: UInt32
    public var length: UInt32

    public init(offset: UInt32, length: UInt32) {
        this.offset = offset
        this.length = length
    }
}

// ============================================================================
// StringBuilder
// 严格翻译自: src/string/StringBuilder.zig
// ============================================================================

/// 字符串构建器: 预分配缓冲区模式
/// 严格翻译自 StringBuilder.zig StringBuilder
public class StringBuilder {
    /// 当前已使用长度
    public var len: Int64

    /// 总容量
    public var cap: Int64

    /// 缓冲区
    private var buffer: Array<Byte>

    public init() {
        this.len = 0
        this.cap = 0
        this.buffer = Array<Byte>()
    }

    /// 带初始容量初始化
    /// 严格翻译自 StringBuilder.initCapacity
    public init(capacity: Int64) {
        this.len = 0
        this.cap = capacity
        this.buffer = Array<Byte>(capacity, item: Byte(0))
    }

    /// 计数: 包含 null 终止符
    /// 严格翻译自 StringBuilder.countZ
    public func countZ(slice: String): Unit {
        this.cap += slice.size + 1
    }

    /// 计数: 不含 null 终止符
    /// 严格翻译自 StringBuilder.count
    public func count(slice: String): Unit {
        this.cap += slice.size
    }

    /// 分配缓冲区
    /// 严格翻译自 StringBuilder.allocate
    public func allocate(): Unit {
        if (this.cap > 0) {
            this.buffer = Array<Byte>(this.cap, item: Byte(0))
        }
        this.len = 0
    }

    /// 释放资源
    /// 严格翻译自 StringBuilder.deinit
    public func deinit(): Unit {
        this.buffer = Array<Byte>()
        this.len = 0
        this.cap = 0
    }

    /// 计算 UTF-16 到 UTF-8 的长度
    /// 严格翻译自 StringBuilder.count16
    public func count16(slice: Array<UInt16>): Unit {
        // 简化: UTF-16 到 UTF-8 最大 3 倍展开
        this.cap += Int64(slice.size) * 3
    }

    /// 计算 UTF-16 (null终止) 到 UTF-8 的长度
    /// 严格翻译自 StringBuilder.count16Z
    public func count16Z(slice: Array<UInt16>): Unit {
        this.cap += Int64(slice.size) * 3 + 1
    }

    /// 追加带 null 终止的字符串
    /// 严格翻译自 StringBuilder.appendZ
    public func appendZ(slice: String): String {
        let bytes = slice.toArray()
        for (i in 0..bytes.size) {
            this.buffer[this.len] = bytes[i]
            this.len += 1
        }
        this.buffer[this.len] = Byte(0)
        this.len += 1
        return slice
    }

    /// 追加字符串
    /// 严格翻译自 StringBuilder.append
    public func append(slice: String): String {
        let bytes = slice.toArray()
        for (b in bytes) {
            this.buffer[this.len] = b
            this.len += 1
        }
        return slice
    }

    /// 追加字节数组
    public func appendBytes(bytes: Array<Byte>): Unit {
        for (b in bytes) {
            this.buffer[this.len] = b
            this.len += 1
        }
    }

    /// 拼接追加
    /// 严格翻译自 StringBuilder.addConcat
    public func addConcat(slices: Array<String>): StringPointer {
        var totalLen: Int64 = 0
        for (slice in slices) {
            let bytes = slice.toArray()
            for (b in bytes) {
                this.buffer[this.len + totalLen] = b
                totalLen += 1
            }
        }
        return add(totalLen)
    }

    /// 增加长度,返回位置指针
    /// 严格翻译自 StringBuilder.add
    public func add(len: Int64): StringPointer {
        let start = this.len
        this.len += len
        return StringPointer(offset: UInt32(start), length: UInt32(len))
    }

    /// 追加并计数
    /// 严格翻译自 StringBuilder.appendCount
    public func appendCount(slice: String): StringPointer {
        let start = this.len
        let bytes = slice.toArray()
        for (b in bytes) {
            this.buffer[this.len] = b
            this.len += 1
        }
        return StringPointer(offset: UInt32(start), length: UInt32(bytes.size))
    }

    /// 追加并计数(带 null 终止)
    /// 严格翻译自 StringBuilder.appendCountZ
    public func appendCountZ(slice: String): StringPointer {
        let start = this.len
        let bytes = slice.toArray()
        for (b in bytes) {
            this.buffer[this.len] = b
            this.len += 1
        }
        this.len += 1 // null 终止符
        return StringPointer(offset: UInt32(start), length: UInt32(bytes.size))
    }

    /// 格式化写入
    /// 严格翻译自 StringBuilder.fmt
    public func fmt(str: String): String {
        let bytes = str.toArray()
        for (b in bytes) {
            this.buffer[this.len] = b
            this.len += 1
        }
        return str
    }

    /// 格式化计数
    /// 严格翻译自 StringBuilder.fmtCount
    public func fmtCount(str: String): Unit {
        this.cap += str.size
    }

    /// 获取已分配的切片
    /// 严格翻译自 StringBuilder.allocatedSlice
    public func allocatedSlice(): Array<Byte> {
        if (this.cap == 0) {
            return []
        }
        return this.buffer[0..this.cap]
    }

    /// 获取可写区域
    /// 严格翻译自 StringBuilder.writable
    public func writable(): Array<Byte> {
        if (this.cap == 0) {
            return []
        }
        return this.buffer[this.len..this.cap]
    }

    /// 转移所有权到切片
    /// 严格翻译自 StringBuilder.moveToSlice
    public func moveToSlice(): Array<Byte> {
        let result = this.buffer[0..this.len]
        this.len = 0
        this.cap = 0
        this.buffer = Array<Byte>()
        return result
    }

    /// 转换为字符串
    public func toString(): String {
        if (this.len == 0) {
            return ""
        }
        return String.fromUtf8(this.buffer[0..this.len])
    }

    /// 获取指定范围字符串
    public func substring(ptr: StringPointer): String {
        return String.fromUtf8(this.buffer[Int64(ptr.offset)..Int64(ptr.offset) + Int64(ptr.length)])
    }
}
