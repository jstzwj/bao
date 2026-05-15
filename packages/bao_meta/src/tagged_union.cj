// bao_meta - 标签联合辅助
// 严格翻译自: bun/src/meta/tagged_union.zig
//   pub fn TaggedUnion(comptime field_types: []const type) type
//   创建带有 @"0",@"1",... 字段的 tagged union (支持 1-16 个字段)
//   pub fn deinitImpl(comptime Union: type, value: *Union) void
package bao_meta

import bao_core.*

// ============================================================================
// TaggedUnionHelper - 标签联合辅助
// 严格翻译自: bun/src/meta/tagged_union.zig - TaggedUnion
//
//   Zig 原始逻辑:
//     fn deinitImpl(comptime Union: type, value: *Union) void:
//       switch (std.meta.activeTag(value.*)):
//         inline else => |tag| bun.memory.deinit(&@field(value, @tagName(tag)))
//       value.* = undefined
//
//     pub fn TaggedUnion(comptime field_types: []const type) type:
//       // 根据字段数量创建不同大小的 union(enum)
//       // 字段命名为 @"0", @"1", @"2", ...
//       // 每个都有 deinit 方法
//       return switch (field_types.len):
//         0 => @compileError("cannot create an empty tagged union")
//         1 => union(enum) { @"0": field_types[0], pub fn deinit... }
//         2 => union(enum) { @"0": field_types[0], @"1": field_types[1], pub fn deinit... }
//         ...
//         16 => union(enum) { @"0"..."15", pub fn deinit... }
//         else => @compileError("too many union fields")
// ============================================================================

/// 标签联合值 - 对应 Bun TaggedUnion
/// 仓颉中没有 Zig 的 comptime @Type 构造能力
/// 用动态类型值和索引模拟
/// Zig 的 TaggedUnion 创建带有 @"0",@"1",... 字段的 union(enum)
/// 仓颉用 TaggedUnionValue 包装，包含 tag 索引和 Any 值
public class TaggedUnionValue {
    /// 当前活跃变体的索引
    /// 对应 Zig union(enum) 的 tag
    public var tag: Int64
    /// 存储的值
    /// 对应 Zig union 字段值
    public var value: Any

    public init(tag: Int64, value: Any) {
        this.tag = tag
        this.value = value
    }

    /// 获取变体索引
    public func getTag(): Int64 {
        tag
    }

    /// 检查是否为指定变体
    public func is(tag: Int64): Bool {
        this.tag == tag
    }

    /// 获取指定类型的值
    /// 对应 Zig 的 @field(value, @tagName(tag))
    public func getValue<T>(): ?T {
        if (value is T) {
            value as T
        } else {
            None
        }
    }

    /// 销毁当前值
    /// 对应: deinitImpl(comptime Union: type, value: *Union) void
    ///   switch (std.meta.activeTag(value.*)):
    ///     inline else => |tag| bun.memory.deinit(&@field(value, @tagName(tag)))
    ///   value.* = undefined
    public func deinit(): Unit {
        // 仓颉中由 GC 自动回收
        tag = -1
        value = ""
    }
}

/// 标签联合工厂 - 对应 Bun TaggedUnion 函数
/// Zig: pub fn TaggedUnion(comptime field_types: []const type) type
/// 支持 1-16 个字段类型，字段命名为 @"0" 到 @"15"
public class TaggedUnion {
    /// 创建单字段标签联合
    /// 对应: TaggedUnion(&[_]type{T0})
    public static func of1<T0>(value: T0): TaggedUnionValue {
        TaggedUnionValue(0, value)
    }

    /// 创建双字段标签联合
    /// 对应: TaggedUnion(&[_]type{T0, T1})
    public static func of2<T0, T1>(index: Int64, value0: T0, value1: T1): TaggedUnionValue {
        match (index) {
            case 0 => TaggedUnionValue(0, value0)
            case 1 => TaggedUnionValue(1, value1)
            case _ => TaggedUnionValue(-1, "")
        }
    }

    /// 从索引和值创建标签联合
    /// 对应 Zig TaggedUnion 的各个字段 @"0",@"1",...
    public static func fromIndex(index: Int64, value: Any): TaggedUnionValue {
        if (index < 0 || index > 15) {
            panic("TaggedUnion: too many union fields or invalid index")
        }
        TaggedUnionValue(index, value)
    }
}
