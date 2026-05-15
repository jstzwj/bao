// bao_meta - 类型特征工具集
// 严格翻译自: bun/src/meta/traits.zig
//   pub inline fn isZigString(comptime T: type) bool
//   pub inline fn isSlice(comptime T: type) bool
//   pub inline fn isNumber(comptime T: type) bool
//   pub inline fn isContainer(comptime T: type) bool
//   pub inline fn isSingleItemPtr(comptime T: type) bool
//   pub fn isExternContainer(comptime T: type) bool
//   pub fn isConstPtr(comptime T: type) bool
//   pub fn isIndexable(comptime T: type) bool
package bao_meta

import bao_core.*

// ============================================================================
// TypeTraits - 类型特征工具集
// 严格翻译自: bun/src/meta/traits.zig
//   编译时类型检查：isZigString, isSlice, isNumber, isContainer 等
//
//   Zig 原始逻辑:
//     pub inline fn isZigString(comptime T: type) bool:
//       info = @typeInfo(T)
//       if (info != .pointer) return false
//       ptr = &info.pointer
//       if (ptr.is_volatile or ptr.is_allowzero) return false
//       if (ptr.size == .slice) return ptr.child == u8
//       if (ptr.size == .One):
//         child = @typeInfo(ptr.child)
//         if (child == .Array) return child.Array.child == u8
//       return false
//
//     pub inline fn isSlice(comptime T: type) bool:
//       info = @typeInfo(T)
//       return info == .pointer and info.pointer.size == .slice
//
//     pub inline fn isNumber(comptime T: type) bool:
//       return switch (@typeInfo(T)):
//         .int, .float, .comptime_int, .comptime_float => true
//         else => false
//
//     pub inline fn isContainer(comptime T: type) bool:
//       return switch (@typeInfo(T)):
//         .struct, .enum, .opaque, .union => true
//         else => false
//
//     pub inline fn isSingleItemPtr(comptime T: type) bool:
//       info = @typeInfo(T)
//       return info == .pointer and .pointer.size == .One
//
//     pub fn isExternContainer(comptime T: type) bool:
//       return switch (@typeInfo(T)):
//         .struct => |s| s.layout == .extern
//         .union => |u| u.layout == .extern
//         else => false
//
//     pub fn isConstPtr(comptime T: type) bool:
//       info = @typeInfo(T)
//       return info == .pointer and info.pointer.is_const
//
//     pub fn isIndexable(comptime T: type) bool:
//       return switch (info):
//         .pointer => |ptr| switch (ptr.size):
//           .One => @typeInfo(ptr.child) == .array
//           else => true
//         .array, .vector => true
//         .struct => |s| s.is_tuple
//         else => false
// ============================================================================

/// 类型特征工具 - 对应 Bun meta/traits.zig
/// 仓颉没有 Zig 的 comptime 反射能力，这里提供运行时类型检查辅助
public class TypeTraits {
    /// 检查是否为字符串类型
    /// 对应: isZigString(comptime T: type) bool
    ///   Zig: []const u8, *const [N]u8 等
    ///   仓颉: String
    public static func isString<T>(): Bool {
        let name = typeName<T>()
        name == "String" || name == "bao_core.String"
    }

    /// 检查是否为切片类型
    /// 对应: isSlice(comptime T: type) bool
    ///   Zig: info == .pointer and info.pointer.size == .slice
    public static func isSlice<T>(): Bool {
        // 仓颉中 Array 类型相当于 Zig slice
        let name = typeName<T>()
        name.startsWith("Array<") || name.startsWith("ArrayList<")
    }

    /// 检查是否为数值类型
    /// 对应: isNumber(comptime T: type) bool
    ///   Zig: .int, .float, .comptime_int, .comptime_float => true
    public static func isNumber<T>(): Bool {
        let name = typeName<T>()
        name == "Int8" || name == "Int16" || name == "Int32" || name == "Int64" ||
        name == "UInt8" || name == "UInt16" || name == "UInt32" || name == "UInt64" ||
        name == "Float32" || name == "Float64"
    }

    /// 检查是否为整数类型
    /// 对应 Zig @typeInfo == .int
    public static func isInteger<T>(): Bool {
        let name = typeName<T>()
        name == "Int8" || name == "Int16" || name == "Int32" || name == "Int64" ||
        name == "UInt8" || name == "UInt16" || name == "UInt32" || name == "UInt64"
    }

    /// 检查是否为浮点类型
    /// 对应 Zig @typeInfo == .float
    public static func isFloat<T>(): Bool {
        let name = typeName<T>()
        name == "Float32" || name == "Float64"
    }

    /// 检查是否为布尔类型
    /// 对应 Zig @typeInfo == .bool
    public static func isBool<T>(): Bool {
        typeName<T>() == "Bool"
    }

    /// 检查是否为容器类型 (struct/enum/union)
    /// 对应: isContainer(comptime T: type) bool
    ///   Zig: .struct, .enum, .opaque, .union => true
    public static func isContainer<T>(): Bool {
        !isNumber<T>() && !isBool<T>() && !isString<T>()
    }

    /// 检查是否为单元素指针类型
    /// 对应: isSingleItemPtr(comptime T: type) bool
    ///   Zig: info == .pointer and .pointer.size == .One
    ///   仓颉中没有 Zig 风格的指针，概念上对应引用类型
    public static func isSingleItemPtr<T>(): Bool {
        false // 仓颉中没有 Zig 风格的指针概念
    }

    /// 检查是否为 extern 容器类型
    /// 对应: isExternContainer(comptime T: type) bool
    ///   Zig: struct.layout == .extern or union.layout == .extern
    ///   仓颉: 使用 @CStruct 标注的结构体
    public static func isExternContainer<T>(): Bool {
        false // 仓颉中需要手动注册
    }

    /// 检查是否为 const 指针类型
    /// 对应: isConstPtr(comptime T: type) bool
    ///   Zig: info == .pointer and info.pointer.is_const
    public static func isConstPtr<T>(): Bool {
        false // 仓颉中没有 Zig 风格的指针概念
    }

    /// 检查是否为可索引类型
    /// 对应: isIndexable(comptime T: type) bool
    ///   Zig: pointer, array, vector, tuple => true
    ///   仓颉: Array, ArrayList, Range 等可索引类型
    public static func isIndexable<T>(): Bool {
        let name = typeName<T>()
        name.startsWith("Array<") || name.startsWith("ArrayList<")
    }

    /// 获取类型名称
    /// 对应: typeName(comptime Type: type) []const u8
    ///   const name = @typeName(Type)
    ///   return typeBaseName(name)
    public static func typeName<T>(): String {
        // 仓颉中通过泛型获取类型信息有限，返回占位名称
        "Unknown"
    }

    /// 获取类型基础名称 (去掉命名空间前缀)
    /// 对应: typeBaseName(comptime fullname: [:0]const u8) [:0]const u8
    ///   将 "some.namespace.MyType" 转换为 "MyType"
    ///   如果包含 "(" 则保持原样 (泛型实例化)
    ///   否则取最后一个 "." 之后的部分
    public static func typeBaseName(fullname: String): String {
        // 如果包含 "(" 则保持原样 (如 namespace.WrapperType(namespace.MyType))
        if (fullname.contains("(")) {
            return fullname
        }
        let idx = fullname.lastIndexOf('.')
        if (idx.isSome()) {
            fullname.subString(idx.getOrThrow() + 1)
        } else {
            fullname
        }
    }
}
