// 严格翻译自: src/string/SmolStr.zig
// 小字符串优化 (Small String Optimization)
//   在 Zig 原版中, SmolStr 是一个 packed struct(u128):
//   - 如果字符串长度 <= 15 字节, 直接内联存储在 128 位中
//   - 如果超过 15 字节, 则堆分配并存储指针/长度/容量
//   通过最高位标记来区分内联/堆分配模式
//
//   在仓颉中, 我们用枚举实现相同的语义:
//   - Inlined: 内联存储最多 MAX_INLINE_LEN 字节
//   - Heap: 堆分配,存储字节数组和容量
package bao_string

import bao_core.*

// ============================================================================
// SmolStr
// 严格翻译自: src/string/SmolStr.zig
// ============================================================================

/// 内联最大字节数
/// 严格翻译自 SmolStr.Inlined.max_len = bitSizeOf(u120) / 8 = 15
public const MAX_INLINE_LEN: Int64 = 15

/// 小字符串优化: 内联存储短字符串,堆分配长字符串
/// 严格翻译自 SmolStr.zig SmolStr
public class SmolStr {
    /// 存储模式
    private enum StorageMode {
        | Inlined(Array<Byte>)    // 内联: 最多 15 字节
        | Heap(Array<Byte>, Int64) // 堆: (数据, 容量)
    }

    private var storage: StorageMode

    /// 空构造
    private init(storage: StorageMode) {
        this.storage = storage
    }

    /// 创建空的 SmolStr
    /// 严格翻译自 SmolStr.empty
    public static func empty(): SmolStr {
        return SmolStr(StorageMode.Inlined([]))
    }

    /// 从单个字符创建
    /// 严格翻译自 SmolStr.fromChar
    public static func fromChar(char: Byte): SmolStr {
        return SmolStr(StorageMode.Inlined([char]))
    }

    /// 从字符串创建
    /// 严格翻译自 SmolStr.fromSlice (带分配器版本)
    public static func fromSlice(values: String): SmolStr {
        let bytes = values.toArray()
        return fromBytes(bytes)
    }

    /// 从字节数组创建
    /// 严格翻译自 SmolStr.fromSlice
    public static func fromBytes(values: Array<Byte>): SmolStr {
        if (values.size > MAX_INLINE_LEN) {
            // 堆分配
            var arr = Array<Byte>()
            for (b in values) {
                arr.append(b)
            }
            return SmolStr(StorageMode.Heap(arr, arr.size))
        }
        // 内联存储
        return SmolStr(StorageMode.Inlined(values))
    }

    /// 从 BabyList 创建 (堆分配)
    /// 严格翻译自 SmolStr.fromBabyList
    public static func fromBabyList(data: Array<Byte>, capacity: Int64): SmolStr {
        return SmolStr(StorageMode.Heap(data, capacity))
    }

    /// 获取长度
    /// 严格翻译自 SmolStr.len
    public func len(): Int64 {
        match (storage) {
            case StorageMode.Inlined(bytes) =>
                return bytes.size
            case StorageMode.Heap(bytes, _) =>
                return bytes.size
        }
    }

    /// 判断是否为内联存储
    /// 严格翻译自 SmolStr.isInlined
    public func isInlined(): Bool {
        match (storage) {
            case StorageMode.Inlined(_) =>
                return true
            case StorageMode.Heap(_, _) =>
                return false
        }
    }

    /// 获取底层切片
    /// 严格翻译自 SmolStr.slice
    public func slice(): Array<Byte> {
        match (storage) {
            case StorageMode.Inlined(bytes) =>
                return bytes
            case StorageMode.Heap(bytes, _) =>
                return bytes
        }
    }

    /// 获取字符串表示
    public func toString(): String {
        return String.fromUtf8(slice())
    }

    /// 追加单个字符
    /// 严格翻译自 SmolStr.appendChar
    public func appendChar(char: Byte): Unit {
        match (storage) {
            case StorageMode.Inlined(bytes) =>
                if (bytes.size + 1 > MAX_INLINE_LEN) {
                    // 升级为堆分配
                    var arr = Array<Byte>()
                    for (b in bytes) {
                        arr.append(b)
                    }
                    arr.append(char)
                    storage = StorageMode.Heap(arr, arr.size)
                } else {
                    var newBytes = bytes
                    newBytes.append(char)
                    storage = StorageMode.Inlined(newBytes)
                }
            case StorageMode.Heap(bytes, cap) =>
                bytes.append(char)
        }
    }

    /// 追加字节切片
    /// 严格翻译自 SmolStr.appendSlice
    public func appendSlice(values: Array<Byte>): Unit {
        match (storage) {
            case StorageMode.Inlined(bytes) =>
                if (bytes.size + values.size > MAX_INLINE_LEN) {
                    // 升级为堆分配
                    var arr = Array<Byte>()
                    for (b in bytes) {
                        arr.append(b)
                    }
                    for (b in values) {
                        arr.append(b)
                    }
                    storage = StorageMode.Heap(arr, arr.size)
                } else {
                    var newBytes = bytes
                    for (b in values) {
                        newBytes.append(b)
                    }
                    storage = StorageMode.Inlined(newBytes)
                }
            case StorageMode.Heap(bytes, _) =>
                for (b in values) {
                    bytes.append(b)
                }
        }
    }

    /// 追加字符串
    public func appendString(str: String): Unit {
        appendSlice(str.toArray())
    }

    /// 释放资源
    /// 严格翻译自 SmolStr.deinit
    public func deinit(): Unit {
        // 仓颉 GC 自动回收
        storage = StorageMode.Inlined([])
    }

    /// 判断两个 SmolStr 是否相等
    public func eql(other: SmolStr): Bool {
        let a = slice()
        let b = other.slice()
        if (a.size != b.size) {
            return false
        }
        for (i in 0..a.size) {
            if (a[i] != b[i]) {
                return false
            }
        }
        return true
    }
}

// ============================================================================
// Inlined 辅助类
// 严格翻译自 SmolStr.Inlined
// ============================================================================

/// 内联存储的 SmolStr 部分
/// 严格翻译自 SmolStr.Inlined
public class SmolStrInlined {
    private var data: Array<Byte>

    public init() {
        this.data = []
    }

    public init(str: String) {
        this.data = str.toArray()
    }

    public init(bytes: Array<Byte>) {
        this.data = bytes
    }

    /// 从字符串初始化
    /// 严格翻译自 SmolStr.Inlined.init
    public static func init(str: String): SmolStrInlined {
        let bytes = str.toArray()
        if (bytes.size > MAX_INLINE_LEN) {
            panic("SmolStrInlined: 字符串太长,无法内联")
        }
        return SmolStrInlined(bytes)
    }

    /// 获取长度
    /// 严格翻译自 SmolStr.Inlined.len
    public func len(): Int64 {
        return data.size
    }

    /// 获取切片
    /// 严格翻译自 SmolStr.Inlined.slice
    public func slice(): Array<Byte> {
        return data
    }

    /// 获取可变切片
    /// 严格翻译自 SmolStr.Inlined.sliceMut
    public func sliceMut(): Array<Byte> {
        return data
    }

    /// 转换为字符串
    public func toString(): String {
        return String.fromUtf8(data)
    }
}
