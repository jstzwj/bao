// bao_meta - 位域操作工具
// 严格翻译自: bun/src/meta/bits.zig
//   pub inline fn intersects, @"and", @"or", invert, insert, contains,
//     maskOut, remove, leadingZeros, fromInt, asInt
//   pub fn LeadingZerosInt(comptime T: type) type
//   注意: T 在 Zig 中是 packed struct of bools，仓颉用整数位掩码表示
package bao_meta

import bao_core.*

// ============================================================================
// BitField - 位域操作工具
// 严格翻译自: bun/src/meta/bits.zig
//
//   Zig 原始逻辑 (T 为 packed struct of bools):
//     pub inline fn intersects(comptime T: type, lhs: T, rhs: T) bool:
//       return asInt(T, lhs) & asInt(T, rhs) != 0;
//
//     pub inline fn @"and"(comptime T: type, lhs: T, rhs: T) T:
//       return fromInt(T, asInt(T, lhs) & asInt(T, rhs));
//
//     pub inline fn @"or"(comptime T: type, lhs: T, rhs: T) T:
//       return fromInt(T, asInt(T, lhs) | asInt(T, rhs));
//
//     pub inline fn invert(comptime T: type, value: T) T:
//       return fromInt(T, ~asInt(T, value));
//
//     pub inline fn insert(comptime T: type, lhs: *T, rhs: T) void:
//       lhs.* = @"or"(T, lhs.*, rhs);
//
//     pub inline fn contains(comptime T: type, lhs: T, rhs: T) bool:
//       return (asInt(T, lhs) & asInt(T, rhs)) != 0;
//
//     pub inline fn maskOut(comptime T: type, lhs: *T, rhs: T) T:
//       return @"and"(T, lhs, invert(T, rhs));
//
//     pub inline fn remove(comptime T: type, lhs: *T, rhs: T) void:
//       lhs.* = @"and"(T, lhs.*, invert(T, rhs));
//
//     pub inline fn leadingZeros(comptime T: type, value: T) LeadingZerosInt(T):
//       return @clz(asInt(T, value));
//
//     pub fn LeadingZerosInt(comptime T: type) type:
//       backing_int = @typeInfo(T).struct.backing_integer.?
//       return std.math.IntFittingRange(0, @typeInfo(backing_int).int.bits)
//
//     pub inline fn fromInt(comptime T: type, bits: backing_integer) T:
//       return @bitCast(bits);
//
//     pub inline fn asInt(comptime T: type, value: T) backing_integer:
//       return @bitCast(value);
// ============================================================================

/// 位域操作工具 - 对应 Bun meta/bits.zig
/// 操作整数位掩码，替代 Zig 的 packed struct 位操作
/// Zig 的 packed struct of bools 在仓颉中用整数位掩码表示
/// 所有操作直接在 Int64 上进行
public class BitField {
    /// 检查两个位掩码是否有交集
    /// 对应: intersects(comptime T: type, lhs: T, rhs: T) bool
    ///   return asInt(T, lhs) & asInt(T, rhs) != 0;
    public static func intersects(lhs: Int64, rhs: Int64): Bool {
        (lhs & rhs) != 0
    }

    /// 位与操作
    /// 对应: @"and"(comptime T: type, lhs: T, rhs: T) T
    ///   return fromInt(T, asInt(T, lhs) & asInt(T, rhs));
    public static func bitAnd(lhs: Int64, rhs: Int64): Int64 {
        lhs & rhs
    }

    /// 位或操作
    /// 对应: @"or"(comptime T: type, lhs: T, rhs: T) T
    ///   return fromInt(T, asInt(T, lhs) | asInt(T, rhs));
    public static func bitOr(lhs: Int64, rhs: Int64): Int64 {
        lhs | rhs
    }

    /// 位取反
    /// 对应: invert(comptime T: type, value: T) T
    ///   return fromInt(T, ~asInt(T, value));
    public static func invert(value: Int64): Int64 {
        ~value
    }

    /// 将 rhs 的位插入 lhs
    /// 对应: insert(comptime T: type, lhs: *T, rhs: T) void
    ///   lhs.* = @"or"(T, lhs.*, rhs);
    ///   当 rhs 已知时，优先使用属性赋值: lhs.flag = true
    public static func insert(lhs: Int64, rhs: Int64): Int64 {
        lhs | rhs
    }

    /// 检查 lhs 是否包含 rhs 的所有位
    /// 对应: contains(comptime T: type, lhs: T, rhs: T) bool
    ///   return (asInt(T, lhs) & asInt(T, rhs)) != 0;
    ///   注意: Zig 原始代码实现是 != 0 而非 == rhs
    public static func contains(lhs: Int64, rhs: Int64): Bool {
        (lhs & rhs) != 0
    }

    /// 从 lhs 中屏蔽掉 rhs 的位 (返回 lhs & ~rhs)
    /// 对应: maskOut(comptime T: type, lhs: *T, rhs: T) T
    ///   return @"and"(T, lhs, invert(T, rhs));
    public static func maskOut(lhs: Int64, rhs: Int64): Int64 {
        lhs & ~rhs
    }

    /// 从 lhs 中移除 rhs 的位
    /// 对应: remove(comptime T: type, lhs: *T, rhs: T) void
    ///   lhs.* = @"and"(T, lhs.*, invert(T, rhs));
    public static func remove(lhs: Int64, rhs: Int64): Int64 {
        lhs & ~rhs
    }

    /// 计算前导零
    /// 对应: leadingZeros(comptime T: type, value: T) LeadingZerosInt(T)
    ///   return @clz(asInt(T, value));
    ///   LeadingZerosInt(T) = std.math.IntFittingRange(0, bits)
    public static func leadingZeros(value: Int64): Int64 {
        if (value == 0) { return 64 }
        var count = 0
        var v = value
        while (v >= 0 && v != 0) {
            count += 1
            v = v << 1
        }
        count
    }

    /// 将整数位掩码转换为 packed struct 值
    /// 对应: fromInt(comptime T: type, bits: backing_integer) T
    ///   return @bitCast(bits);
    ///   仓颉中直接返回整数，因为仓颉没有 packed struct
    public static func fromInt(bits: Int64): Int64 {
        bits
    }

    /// 将 packed struct 值转换为整数位掩码
    /// 对应: asInt(comptime T: type, value: T) backing_integer
    ///   return @bitCast(value);
    ///   仓颉中直接返回整数
    public static func asInt(value: Int64): Int64 {
        value
    }
}
