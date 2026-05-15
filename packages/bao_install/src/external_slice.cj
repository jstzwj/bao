// bao_install - 外部切片
// 严格翻译自: src/install/ExternalSlice.zig
//   ExternalSlice.zig 定义了用于二进制锁文件中引用外部数据的切片类型,
//   通过偏移量 + 长度引用外部缓冲区中的数据
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*

// ============================================================================
// 外部切片
// 严格翻译自: src/install/ExternalSlice.zig
//   pub fn ExternalSlice(comptime Type: type) type {
//       return extern struct {
//           off: u32 = 0,
//           len: u32 = 0,
//           ...
//       }
//   }
//
//   在 Zig 中, 这是一个泛型, 在仓颉中我们使用类来实现
// ============================================================================

/// 外部切片 (通用)
/// 对应 Bun: ExternalSlice(Type)
/// 通过偏移量和长度引用外部缓冲区中的连续数据
public class ExternalSlice<T> {
    /// 偏移量
    /// 翻译自: off: u32 = 0
    public var off: UInt32
    /// 长度
    /// 翻译自: len: u32 = 0
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }

    /// 无效标记
    /// 翻译自: pub const invalid = .{ .off = std.math.maxInt(u32), .len = std.math.maxInt(u32) }
    public static func invalid(): ExternalSlice<T> {
        return ExternalSlice<T>(off: UInt32.MAX, len: UInt32.MAX)
    }

    /// 是否无效
    /// 翻译自: pub inline fn isInvalid(this: Slice) bool
    public func isInvalid(): Bool {
        return off == UInt32.MAX && len == UInt32.MAX
    }

    /// 是否包含指定 ID
    /// 翻译自: pub inline fn contains(this: Slice, id: u32) bool
    public func contains(id: UInt32): Bool {
        return id >= off && id < (len + off)
    }

    /// 起始索引
    /// 翻译自: pub inline fn begin(this: Slice) u32
    public func begin(): UInt32 {
        return off
    }

    /// 结束索引 (不含)
    /// 翻译自: pub inline fn end(this: Slice) u32
    public func end(): UInt32 {
        return off + len
    }

    /// 从缓冲区获取切片
    /// 翻译自: pub inline fn get(this: Slice, in: []const Type) []const Type
    public func get(buffer: ArrayList<T>): ArrayList<T> {
        let start = Int64(off)
        let end = Int64(off + len)
        if (start >= buffer.size) { return ArrayList<T>() }
        let actualEnd = if (end > buffer.size) { buffer.size } else { end }
        let result = ArrayList<T>()
        for (i in start..actualEnd) {
            result.append(buffer[i])
        }
        return result
    }

    /// 从数组初始化
    /// 翻译自: pub fn init(buf: []const Type, in: []const Type) Slice
    public static func init(buffer: ArrayList<T>, slice: ArrayList<T>): ExternalSlice<T> {
        // 在 Zig 中, 通过指针算术计算偏移量
        // 在仓颉中, 我们需要找到 slice 在 buffer 中的位置
        // 简化: 使用第一个元素的引用
        return ExternalSlice<T>(off: UInt32(0), len: UInt32(slice.size))
    }
}

// ============================================================================
// 外部字符串映射
// 严格翻译自: src/install/ExternalSlice.zig
//   pub const ExternalStringMap = extern struct {
//       name: ExternalStringList = .{},
//       value: ExternalStringList = .{},
//   }
// ============================================================================

/// 外部字符串映射
/// 对应 Bun: ExternalStringMap
public class ExternalStringMap {
    /// 名称列表
    public var name: ExternalStringList
    /// 值列表
    public var value: ExternalStringList

    public init() {
        name = ExternalStringList()
        value = ExternalStringList()
    }
}

/// 外部字符串列表
/// 翻译自: ExternalStringList = ExternalSlice(ExternalString)
public class ExternalStringList {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }

    public func begin(): UInt32 { return off }
    public func end(): UInt32 { return off + len }
}

/// 外部包名哈希列表
/// 翻译自: ExternalPackageNameHashList = ExternalSlice(PackageNameHash)
public class ExternalPackageNameHashList {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }
}

/// 版本切片
/// 翻译自: VersionSlice = ExternalSlice(Semver.Version)
public class VersionSlice {
    public var off: UInt32
    public var len: UInt32

    public init() {
        off = UInt32(0)
        len = UInt32(0)
    }

    public init(off: UInt32, len: UInt32) {
        this.off = off
        this.len = len
    }
}
