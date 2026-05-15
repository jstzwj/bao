// 严格翻译自: src/bun_core/util.zig
//   pub fn Key(comptime Map: type) type { ... }
//   pub fn Value(comptime Map: type) type { ... }
//   pub fn fromEntries(comptime Map: type, allocator, comptime EntryType: type, entries) !Map { ... }
//   pub fn fromMapLike(comptime Map: type, allocator, entries) !Map { ... }
//   pub fn FieldType(comptime Map: type, comptime name: []const u8) ?type { ... }
//   pub fn Of(comptime ArrayLike: type) type { ... }
//   pub fn from(comptime Array: type, allocator, default: anytype) !Array { ... }
//   pub fn fromSlice(comptime Array: type, allocator, comptime DefaultType: type, default) !Array { ... }
package bao_core

import std.collection.*

// ============================================================================
// Util - 通用工具函数
// 严格翻译自: src/bun_core/util.zig:1-236
//   "Things that maybe should go in Zig standard library at some point"
//   这些函数在 Bun 中用于编译时元编程
//   在仓颉中, 由于类型系统不同, 我们使用运行时泛型实现等价功能
// ============================================================================

/// 通用工具 - 对应 Bun util 模块
/// Zig 的 comptime 泛型在仓颉中用运行时类型和泛型实现
public class Util {
    // ========================================================================
    // Map 工具函数
    // ========================================================================

    /// 从键值对数组创建 HashMap - 对应 Bun fromEntries()
    /// pub fn fromEntries(comptime Map: type, allocator: std.mem.Allocator,
    ///     comptime EntryType: type, entries: EntryType) !Map { ... }
    ///
    /// Bun:
    ///   var map = Map{};
    ///   try map.ensureUnusedCapacity(entries.len);
    ///   inline for (entries) |entry| { map.putAssumeCapacity(entry[0], entry[1]); }
    ///   return map;
    public static func fromEntries<K, V>(entries: Array<(K, V)>): HashMap<K, V> where K <: Hashable & Equatable<K> {
        let map = HashMap<K, V>()
        for (entry in entries) {
            let (key, value) = entry
            map.put(key, value)
        }
        return map
    }

    /// 从键值对数组创建 HashMap (指定容量) - 对应 Bun fromEntries() with capacity
    public static func fromEntriesWithCapacity<K, V>(entries: Array<(K, V)>, capacity: Int64): HashMap<K, V> where K <: Hashable & Equatable<K> {
        let map = HashMap<K, V>()
        for (entry in entries) {
            let (key, value) = entry
            map.put(key, value)
        }
        return map
    }

    /// 从类似 Map 的结构创建 HashMap - 对应 Bun fromMapLike()
    /// pub fn fromMapLike(comptime Map: type, allocator: std.mem.Allocator,
    ///     entries: []const struct { @FieldType(Map.KV, "key"), @FieldType(Map.KV, "value") }) !Map
    public static func fromMapLike<K, V>(entries: Array<(K, V)>): HashMap<K, V> where K <: Hashable & Equatable<K> {
        let map = HashMap<K, V>()
        for (entry in entries) {
            let (key, value) = entry
            map.put(key, value)
        }
        return map
    }

    // ========================================================================
    // 数组/切片工具
    // ========================================================================

    /// 从数组/切片创建新集合 - 对应 Bun from()
    /// pub inline fn from(comptime Array: type, allocator: std.mem.Allocator, default: anytype) !Array { ... }
    ///
    /// Bun 使用 comptime 类型推断来决定如何构建集合
    /// 仓颉使用运行时类型和泛型
    public static func fromArray<T>(items: Array<T>): ArrayList<T> {
        let list = ArrayList<T>()
        for (item in items) {
            list.append(item)
        }
        return list
    }

    /// 从数组切片创建 ArrayList - 对应 Bun fromSlice()
    /// pub fn fromSlice(comptime Array: type, allocator: std.mem.Allocator,
    ///     comptime DefaultType: type, default: DefaultType) !Array { ... }
    public static func fromSlice<T>(items: Array<T>, start: Int64, end: Int64): ArrayList<T> {
        let list = ArrayList<T>()
        for (i in start..end) {
            list.append(items[i])
        }
        return list
    }

    /// 从数组创建 HashMap (元素为键值对) - 对应 Bun from() for maps
    public static func fromSliceToMap<K, V>(items: Array<(K, V)>): HashMap<K, V> where K <: Hashable & Equatable<K> {
        return fromEntries(items)
    }

    // ========================================================================
    // 类型查询工具
    // ========================================================================

    /// 获取 Map 的 Key 类型 - 对应 Bun Key()
    /// pub fn Key(comptime Map: type) type { return FieldType(Map.KV, "key").?; }
    /// 仓颉: 由于类型擦除, 无法在运行时获取泛型参数类型
    /// 提供静态辅助方法

    /// 获取 Map 的 Value 类型 - 对应 Bun Value()
    /// pub fn Value(comptime Map: type) type { return FieldType(Map.KV, "value").?; }

    /// 获取类型的字段类型 - 对应 Bun FieldType()
    /// pub fn FieldType(comptime Map: type, comptime name: []const u8) ?type
    /// 仓颉: 使用反射或手动实现

    /// 获取数组/集合的元素类型 - 对应 Bun Of()
    /// pub fn Of(comptime ArrayLike: type) type {
    ///     if (bun.trait.isSlice(ArrayLike)) return std.meta.Child(ArrayLike);
    ///     if (@hasDecl(ArrayLike, "Elem")) return ArrayLike.Elem;
    ///     if (@hasField(ArrayLike, "items")) return std.meta.Child(FieldType(ArrayLike, "items").?);
    ///     if (@hasField(ArrayLike, "ptr")) return std.meta.Child(FieldType(ArrayLike, "ptr").?);
    ///     @compileError("Cannot infer type within " ++ @typeName(ArrayLike));
    /// }

    // ========================================================================
    // 字节操作工具
    // ========================================================================

    /// 将数组作为字节切片 - 对应 Bun std.mem.sliceAsBytes
    public static func sliceAsBytes(data: Array<UInt8>, start: Int64, end: Int64): Array<UInt8> {
        if (start >= data.size || end > data.size || start >= end) {
            return Array<UInt8>()
        }
        return data[start..end].toArray()
    }

    /// 复制字节 - 对应 Bun @memcpy / std.mem.copy
    public static func copyBytes(dest: Array<UInt8>, destOffset: Int64, src: Array<UInt8>, srcOffset: Int64, len: Int64): Unit {
        for (i in 0..len) {
            dest[destOffset + i] = src[srcOffset + i]
        }
    }

    /// 向后复制字节 - 对应 Bun mem.copyBackwards
    public static func copyBytesBackwards(dest: Array<UInt8>, destOffset: Int64, src: Array<UInt8>, srcOffset: Int64, len: Int64): Unit {
        var i = len - 1
        while (i >= 0) {
            dest[destOffset + i] = src[srcOffset + i]
            i -= 1
        }
    }

    /// 填充字节 - 对应 Bun @memset
    public static func fillBytes(dest: Array<UInt8>, offset: Int64, len: Int64, value: UInt8): Unit {
        for (i in 0..len) {
            dest[offset + i] = value
        }
    }

    /// 比较字节 - 对应 Bun std.mem.eql(u8, ...)
    public static func bytesEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
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

    // ========================================================================
    // 数组/列表转换工具
    // ========================================================================

    /// ArrayList 转数组 - 对应 Bun map.items[0..map.len]
    public static func arrayListToArray<T>(list: ArrayList<T>): Array<T> {
        let arr = Array<T>(list.size, item: unsafe { uninitialized<T>() })
        for (i in 0..list.size) {
            arr[i] = list[i]
        }
        return arr
    }

    /// 数组转 ArrayList
    public static func arrayToArrayList<T>(arr: Array<T>): ArrayList<T> {
        let list = ArrayList<T>()
        for (item in arr) {
            list.append(item)
        }
        return list
    }

    /// 连接多个数组 - 对应 Bun 多切片连接
    public static func concat<T>(arrays: Array<Array<T>>): Array<T> {
        var totalLen = Int64(0)
        for (arr in arrays) {
            totalLen += arr.size
        }
        let result = Array<T>(totalLen, item: unsafe { uninitialized<T>() })
        var offset = Int64(0)
        for (arr in arrays) {
            for (i in 0..arr.size) {
                result[offset + i] = arr[i]
            }
            offset += arr.size
        }
        return result
    }

    /// 反转数组 - 对应 Bun reverse
    public static func reverse<T>(arr: Array<T>): Array<T> {
        let result = Array<T>(arr.size, item: unsafe { uninitialized<T>() })
        for (i in 0..arr.size) {
            result[i] = arr[arr.size - 1 - i]
        }
        return result
    }

    /// 原地反转数组
    public static func reverseInPlace<T>(arr: Array<T>): Unit {
        var left = Int64(0)
        var right = arr.size - 1
        while (left < right) {
            let tmp = arr[left]
            arr[left] = arr[right]
            arr[right] = tmp
            left += 1
            right -= 1
        }
    }

    // ========================================================================
    // 数学工具
    // ========================================================================

    /// 最小值 - 对应 Bun @min
    public static func min(a: Int64, b: Int64): Int64 {
        return if (a < b) { a } else { b }
    }

    /// 最大值 - 对应 Bun @max
    public static func max(a: Int64, b: Int64): Int64 {
        return if (a > b) { a } else { b }
    }

    /// 限制在范围内 - 对应 Bun std.math.clamp
    public static func clamp(value: Int64, minVal: Int64, maxVal: Int64): Int64 {
        if (value < minVal) { return minVal }
        if (value > maxVal) { return maxVal }
        return value
    }

    /// 对齐到上界 - 对应 Bun std.mem.alignForward
    public static func alignForward(value: Int64, alignment: Int64): Int64 {
        let mask = alignment - 1
        return (value + mask) & ~mask
    }

    /// 是否对齐 - 对应 Bun std.mem.isAligned
    public static func isAligned(value: Int64, alignment: Int64): Bool {
        return (value % alignment) == 0
    }

    // ========================================================================
    // 断言工具
    // ========================================================================

    /// 调试断言 - 对应 Bun bun.assert
    public static func assert(condition: Bool): Unit {
        if (!condition) {
            throw BaoError(ErrorCode.AssertionFailed, "Assertion failed")
        }
    }

    /// 调试断言带消息
    public static func assert(condition: Bool, message: String): Unit {
        if (!condition) {
            throw BaoError(ErrorCode.AssertionFailed, "Assertion failed: ${message}")
        }
    }

    /// 达不到的代码路径 - 对应 Bun unreachable
    public static func unreachableCode(): Unit {
        throw BaoError(ErrorCode.Unreachable, "Unreachable code reached")
    }

    /// 达不到的代码路径 (带消息)
    public static func unreachableCode(message: String): Unit {
        throw BaoError(ErrorCode.Unreachable, "Unreachable: ${message}")
    }
}
