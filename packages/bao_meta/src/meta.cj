// bao_meta - 类型元编程核心
// 严格翻译自: bun/src/meta/meta.zig
//   pub fn OptionalChild, EnumFields, ReturnOfMaybe, MaybeResult,
//     ReturnOf, ReturnOfType, typeName, typeBaseName, enumFieldNames,
//     banFieldType, Item, ConcatArgs1, ConcatArgs2, ConcatArgs4,
//     hasStableMemoryLayout, isSimpleCopyType, isScalar, isSimpleEqlType,
//     ListContainerType, looksLikeListContainerType, Tagged,
//     SliceChild, useAllFields, voidFieldTypeDiscardHelper,
//     hasDecl, hasField
package bao_meta

import bao_core.*

// ============================================================================
// EnumFieldsHelper - 枚举字段辅助
// 严格翻译自: bun/src/meta/meta.zig - EnumFields, enumFieldNames
//
//   Zig 原始逻辑:
//     pub fn EnumFields(comptime T: type) []const std.builtin.Type.EnumField:
//       tyinfo = @typeInfo(T)
//       return switch (tyinfo):
//         .union => std.meta.fields(tyinfo.union.tag_type.?)
//         .enum => tyinfo.enum.fields
//         else => @compileError("...")
//
//     pub fn enumFieldNames(comptime Type: type) []const []const u8:
//       var names: [std.meta.fields(Type).len][]const u8 = std.meta.fieldNames(Type).*
//       var i: usize = 0
//       for (names) |name|:
//         if (bun.strings.eqlAnyComptime(name, &.{ "_none", "", "_" })) continue
//         names[i] = name
//         i += 1
//       return names[0..i]
// ============================================================================

/// 枚举字段辅助工具 - 对应 Bun meta.zig EnumFields/enumFieldNames
/// 仓颉没有 Zig 的 comptime 反射，提供运行时辅助
public class EnumFieldsHelper {
    /// 过滤枚举字段名称，移除 "_" 和 "" 等特殊名称
    /// 对应: enumFieldNames(comptime Type: type) []const []const u8
    ///   zig seems to include "_" or an empty string in the list of enum field names
    ///   it makes sense, but humans don't want that
    public static func filterFieldNames(names: Array<String>): Array<String> {
        let result = ArrayList<String>()
        for (name in names) {
            if (name == "_none" || name.isEmpty || name == "_") {
                continue
            }
            result.append(name)
        }
        result.toArray()
    }
}

// ============================================================================
// MemoryLayout - 内存布局检查
// 严格翻译自: bun/src/meta/meta.zig - hasStableMemoryLayout, isSimpleCopyType,
//   isScalar, isSimpleEqlType
//
//   Zig 原始逻辑:
//     pub fn hasStableMemoryLayout(comptime T: type) bool:
//       return switch (@typeInfo(T)):
//         .Type => true, .Void => true, .Bool => true, .Int => true, .Float => true
//         .enum => (检查 is_exhaustive, 递归 tag_type)
//         .struct => switch (layout):
//           .auto => 递归检查所有字段
//           .extern => true
//           .packed => false
//         .union => switch (layout):
//           .auto => 检查 tag_type + 递归字段
//           .extern => true
//           .packed => false
//         else => true
//
//     pub fn isSimpleCopyType(comptime T: type) bool:
//       return switch (@typeInfo(T)):
//         .void => true, .bool => true, .int => true, .float => true, .enum => true
//         .struct => 递归检查所有字段
//         .union => 递归检查所有字段
//         .optional => return isSimpleCopyType(tyinfo.optional.child)
//         else => false
//
//     pub fn isScalar(comptime T: type) bool:
//       return switch (T):
//         i32, u32, i64, u64, f32, f64, bool => true
//         else => if (@typeInfo(T) == .enum) true else false
//
//     pub fn isSimpleEqlType(comptime T: type) bool:
//       return switch (@typeInfo(T)):
//         .type => true, .void => true, .bool => true, .int => true,
//         .float => true, .enum => true,
//         .struct => |s| s.layout == .packed
//         else => false
// ============================================================================

/// 内存布局检查 - 对应 Bun meta.zig 中的类型布局分析
/// Zig 的 comptime 类型分析在仓颉中用约定和运行时检查代替
public class MemoryLayout {
    /// 检查是否为标量类型
    /// 对应: isScalar(comptime T: type) bool
    ///   i32, u32, i64, u64, f32, f64, bool => true
    ///   如果是 enum 也返回 true
    public static func isScalar<T>(): Bool {
        TypeTraits.isInteger<T>() || TypeTraits.isFloat<T>() || TypeTraits.isBool<T>()
    }

    /// 检查是否为可简单复制类型
    /// 对应: isSimpleCopyType(comptime T: type) bool
    ///   void, bool, int, float, enum, struct(递归), union(递归) => true
    public static func isSimpleCopyType<T>(): Bool {
        // 标量类型都是简单复制类型
        if (isScalar<T>()) { return true }
        // 枚举类型是简单复制类型
        if (TypeEnumInfo.isEnum<T>()) { return true }
        false
    }

    /// 检查是否为可简单相等比较类型
    /// 对应: isSimpleEqlType(comptime T: type) bool
    ///   type, void, bool, int, float, enum => true
    ///   struct with packed layout => true
    public static func isSimpleEqlType<T>(): Bool {
        isScalar<T>() || TypeEnumInfo.isEnum<T>()
    }

    /// 检查是否有稳定内存布局
    /// 对应: hasStableMemoryLayout(comptime T: type) bool
    ///   Type, Void, Bool, Int, Float, extern struct/union => true
    public static func hasStableLayout<T>(): Bool {
        // 基本类型都有稳定布局
        if (isScalar<T>()) { return true }
        // 枚举的底层类型是整数，稳定
        if (TypeEnumInfo.isEnum<T>()) { return true }
        false
    }
}

// ============================================================================
// TypeEnumInfo - 类型枚举信息
// 辅助用于在仓颉中判断类型类别
// ============================================================================

/// 类型枚举信息辅助 - 仓颉中没有 Zig 的 @typeInfo 等价物
/// 提供基本的类型类别判断
public class TypeEnumInfo {
    /// 检查类型是否为枚举
    public static func isEnum<T>(): Bool {
        false // 仓颉中需要手动注册
    }

    /// 检查类型是否为结构体/class
    public static func isStruct<T>(): Bool {
        false // 仓颉中需要手动注册
    }

    /// 检查类型是否为联合
    public static func isUnion<T>(): Bool {
        false // 仓颉中需要手动注册
    }
}

// ============================================================================
// ListContainerType - 列表容器类型检测
// 严格翻译自: bun/src/meta/meta.zig - ListContainerType, looksLikeListContainerType
//   pub const ListContainerType = enum { array_list, baby_list, small_list };
//   pub fn looksLikeListContainerType(comptime T: type) ?struct { list: ListContainerType, child: type }
//     检查类型是否看起来像列表容器:
//       array_list: 两个字段 items + capacity
//       baby_list: 有 looksLikeContainerTypeBabyList 声明
//       small_list: 有 looksLikeContainerTypeSmallList 声明
// ============================================================================

/// 列表容器类型 - 对应 Bun ListContainerType
public enum ListContainerType {
    | ArrayList
    | BabyList
    | SmallList
}

/// 列表容器检测 - 对应 Bun looksLikeListContainerType
public class ListContainerDetector {
    /// 检测列表容器类型
    /// 对应: looksLikeListContainerType(comptime T: type) ?struct { list: ListContainerType, child: type }
    public static func detectListType<T>(): ?ListContainerType {
        None // 仓颉中需要手动注册
    }
}

// ============================================================================
// SliceChildHelper - 切片子元素类型辅助
// 严格翻译自: bun/src/meta/meta.zig - SliceChild
//   pub fn SliceChild(comptime T: type) type:
//     tyinfo = @typeInfo(T)
//     if (tyinfo == .pointer and tyinfo.pointer.size == .slice):
//       return tyinfo.pointer.child
//     return T
// ============================================================================

/// 切片子元素类型辅助 - 对应 Bun SliceChild
public class SliceChildHelper {
    /// 如果是数组/切片类型，返回元素类型名称；否则返回类型本身
    /// 对应: SliceChild(comptime T: type) type
    public static func sliceChildName<T>(): String {
        TypeTraits.typeName<T>()
    }
}

// ============================================================================
// HasDecl / HasField - 声明/字段检查
// 严格翻译自: bun/src/meta/meta.zig - hasDecl, hasField
//   pub fn hasDecl(comptime T: type, comptime name: []const u8) bool:
//     return switch (@typeInfo(T)):
//       .struct, .union, .enum, .opaque => @hasDecl(T, name)
//       else => false
//   pub fn hasField(comptime T: type, comptime name: []const u8) bool:
//     return switch (@typeInfo(T)):
//       .struct, .union, .enum => @hasField(T, name)
//       else => false
// ============================================================================

/// 声明/字段检查 - 对应 Bun meta.zig hasDecl/hasField
/// 仓颉中无法编译时检查，提供运行时接口
public class ReflectionHelper {
    /// 检查类型是否有指定声明
    /// 对应: hasDecl(comptime T: type, comptime name: []const u8) bool
    ///   检查 struct/union/enum/opaque 是否有指定名称的声明 (函数/常量/类型)
    public static func hasDecl<T>(name: String): Bool {
        false // 仓颉中需要手动注册
    }

    /// 检查类型是否有指定字段
    /// 对应: hasField(comptime T: type, comptime name: []const u8) bool
    ///   检查 struct/union/enum 是否有指定名称的字段
    public static func hasField<T>(name: String): Bool {
        false // 仓颉中需要手动注册
    }

    /// 使用所有字段 (防止未使用字段警告)
    /// 对应: useAllFields(comptime T: type, _: VoidFields(T)) void
    ///   userland implementation of ziglang/zig/issues/21879
    ///   VoidFields 将所有字段类型替换为 void，创建一个虚拟结构体
    public static func useAllFields<T>(value: T): Unit {
        // 仓颉中不需要此功能，空实现
    }

    /// 丢弃辅助 (用于 void 字段)
    /// 对应: voidFieldTypeDiscardHelper(data: anytype) void
    ///   _ = data;  // 故意什么都不做
    public static func discard(data: Any): Unit {
        // 故意什么都不做
    }
}

// ============================================================================
// ConcatArgs - 参数拼接辅助
// 严格翻译自: bun/src/meta/meta.zig - ConcatArgs1, ConcatArgs2, ConcatArgs4
//
//   Zig 原始逻辑:
//     pub fn ConcatArgs1(comptime func, a, args_) std.meta.ArgsTuple(@TypeOf(func)):
//       var args: ArgsTuple = undefined
//       args[0] = a
//       inline for (args_, 1..) |arg, i| args[i] = arg
//       return args
//
//     pub fn ConcatArgs2(comptime func, a, b, args_) ArgsTuple:
//       args[0] = a, args[1] = b
//       inline for (args_, 2..) |arg, i| args[i] = arg
//
//     pub fn ConcatArgs4(comptime func, a, b, c, d, args_) ArgsTuple:
//       args[0..3] = a, b, c, d
//       inline for (args_, 4..) |arg, i| args[i] = arg
// ============================================================================

/// 参数拼接辅助 - 对应 Bun meta.zig ConcatArgs*
/// 仓颉中没有 Zig 的 comptime ArgsTuple，提供动态数组方式
public class ConcatArgs {
    /// 拼接 1 个前缀参数 + 剩余参数
    /// 对应: ConcatArgs1(comptime func, a, args_)
    public static func concat1(a: Any, rest: Array<Any>): Array<Any> {
        let result = ArrayList<Any>()
        result.append(a)
        for (item in rest) { result.append(item) }
        result.toArray()
    }

    /// 拼接 2 个前缀参数 + 剩余参数
    /// 对应: ConcatArgs2(comptime func, a, b, args_)
    public static func concat2(a: Any, b: Any, rest: Array<Any>): Array<Any> {
        let result = ArrayList<Any>()
        result.append(a)
        result.append(b)
        for (item in rest) { result.append(item) }
        result.toArray()
    }

    /// 拼接 4 个前缀参数 + 剩余参数
    /// 对应: ConcatArgs4(comptime func, a, b, c, d, args_)
    public static func concat4(a: Any, b: Any, c: Any, d: Any, rest: Array<Any>): Array<Any> {
        let result = ArrayList<Any>()
        result.append(a)
        result.append(b)
        result.append(c)
        result.append(d)
        for (item in rest) { result.append(item) }
        result.toArray()
    }
}

// ============================================================================
// MetaFunctionHelpers - 函数类型分析辅助
// 严格翻译自: bun/src/meta/meta.zig - ReturnOfMaybe, MaybeResult,
//   ReturnOf, ReturnOfType, OptionalChild, Item, Tagged
//
//   Zig 原始逻辑:
//     pub fn OptionalChild(comptime T: type) type:
//       tyinfo = @typeInfo(T)
//       if (tyinfo != .pointer) @compileError
//       child = @typeInfo(tyinfo.pointer.child)
//       if (child != .Optional) @compileError
//       return child.Optional.child
//
//     pub fn ReturnOfMaybe(comptime function: anytype) type:
//       Func = @TypeOf(function)
//       typeinfo = @typeInfo(Func).fn
//       MaybeType = typeinfo.return_type orelse @compileError
//       return MaybeResult(MaybeType)
//
//     pub fn MaybeResult(comptime MaybeType: type) type:
//       maybe = @typeInfo(MaybeType).union
//       if (maybe.fields.len != 2) @compileError
//       // 第一个字段名必须是 "err"，第二个必须是 "result"
//       return maybe.fields[1].type
//
//     pub fn ReturnOf(comptime function: anytype) type:
//       return ReturnOfType(@TypeOf(function))
//
//     pub fn ReturnOfType(comptime Type: type) type:
//       typeinfo = @typeInfo(Type).fn
//       return typeinfo.return_type orelse void
//
//     pub fn Item(comptime T: type) type:
//       switch (@typeInfo(T)):
//         .pointer => |ptr|:
//           if (ptr.size == .one):
//             switch (@typeInfo(ptr.child)):
//               .array => |array| return array.child
//               else => {}
//           return ptr.child
//         else => return std.meta.Child(T)
//
//     pub fn Tagged(comptime U: type, comptime T: type) type:
//       var info = @typeInfo(U).union
//       info.tag_type = T
//       info.decls = &.{}
//       info.layout = .auto
//       return @Type(.{ .union = info })
// ============================================================================

/// 函数类型分析辅助 - 对应 Bun meta.zig 中的函数元编程工具
/// 仓颉中没有 Zig 的 comptime 反射，提供接口占位
public class MetaFunctionHelpers {
    /// 获取函数返回类型的名称
    /// 对应: ReturnOf(comptime function: anytype) type
    ///   ReturnOfType(@TypeOf(function))
    ///   typeinfo.return_type orelse void
    public static func returnTypeName<F>(): String {
        "Unknown" // 仓颉中需要手动指定
    }

    /// 获取 Maybe 类型的结果字段类型名称
    /// 对应: MaybeResult(comptime MaybeType: type) type
    ///   maybe = @typeInfo(MaybeType).union
    ///   第一个字段 "err"，第二个字段 "result"
    ///   return maybe.fields[1].type
    public static func maybeResultTypeName<M>(): String {
        "Unknown" // 仓颉中需要手动指定
    }

    /// 获取容器元素类型名称
    /// 对应: Item(comptime T: type) type
    ///   []T -> T, *const T -> T, *[n]T -> T
    public static func itemName<T>(): String {
        TypeTraits.typeName<T>()
    }
}
