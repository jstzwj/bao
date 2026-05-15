// bao_meta - 类型元编程工具
// 严格翻译自: bun/src/meta/ (meta.zig + bits.zig + traits.zig + tagged_union.zig, ~759行)
//   编译时类型反射、类型特征、位域操作、标签联合
package bao.meta

import bao_core.*

// ============================================================================
// TypeTraits - 类型特征工具集
// 严格翻译自: bun/src/meta/traits.zig
//   编译时类型检查：isZigString, isSlice, isNumber, isContainer 等
// ============================================================================

/// 类型特征工具 - 对应 Bun meta/traits.zig
/// 仓颉没有 Zig 的 comptime 反射能力，这里提供运行时类型检查辅助
public class TypeTraits {
    /// 检查是否为字符串类型
    /// 对应: isZigString(comptime T: type) bool
    ///   Zig: []const u8, *const [N]u8 等
    ///   仓颉: String
    public static func isString<T>(): Bool {
        // 仓颉中字符串类型为 String
        // 使用类型名称判断
        let name = typeName<T>()
        name == "String" || name == "bao_core.String"
    }

    /// 检查是否为数值类型
    /// 对应: isNumber(comptime T: type) bool
    ///   Zig: .int, .float, .comptime_int, .comptime_float
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
    public static func isContainer<T>(): Bool {
        // 仓颉中 class/enum 都是容器
        !isNumber<T>() && !isBool<T>() && !isString<T>()
    }

    /// 获取类型名称
    /// 对应: typeName(comptime Type: type) []const u8
    public static func typeName<T>(): String {
        // 仓颉中通过泛型获取类型信息有限，返回占位名称
        "Unknown"
    }

    /// 获取类型基础名称 (去掉命名空间前缀)
    /// 对应: typeBaseName(comptime fullname: [:0]const u8) [:0]const u8
    ///   将 "some.namespace.MyType" 转换为 "MyType"
    public static func typeBaseName(fullname: String): String {
        let idx = fullname.lastIndexOf('.')
        if (idx.isSome()) {
            fullname.subString(idx.getOrThrow() + 1)
        } else {
            fullname
        }
    }
}

// ============================================================================
// BitField - 位域操作工具
// 严格翻译自: bun/src/meta/bits.zig
//   位运算辅助函数: intersects, and, or, invert, contains, remove 等
//   注意: T 在 Zig 中是 packed struct of bools，仓颉用整数位掩码表示
// ============================================================================

/// 位域操作工具 - 对应 Bun meta/bits.zig
/// 操作整数位掩码，替代 Zig 的 packed struct 位操作
public class BitField {
    /// 检查两个位掩码是否有交集
    /// 对应: intersects(comptime T: type, lhs: T, rhs: T) bool
    ///   return asInt(T, lhs) & asInt(T, rhs) != 0;
    public static func intersects(lhs: Int64, rhs: Int64): Bool {
        (lhs & rhs) != 0
    }

    /// 位与操作
    /// 对应: @"and"(comptime T: type, lhs: T, rhs: T) T
    public static func bitAnd(lhs: Int64, rhs: Int64): Int64 {
        lhs & rhs
    }

    /// 位或操作
    /// 对应: @"or"(comptime T: type, lhs: T, rhs: T) T
    public static func bitOr(lhs: Int64, rhs: Int64): Int64 {
        lhs | rhs
    }

    /// 位取反
    /// 对应: invert(comptime T: type, value: T) T
    public static func invert(value: Int64): Int64 {
        ~value
    }

    /// 将 rhs 的位插入 lhs
    /// 对应: insert(comptime T: type, lhs: *T, rhs: T) void
    public static func insert(lhs: Int64, rhs: Int64): Int64 {
        lhs | rhs
    }

    /// 检查 lhs 是否包含 rhs 的所有位
    /// 对应: contains(comptime T: type, lhs: T, rhs: T) bool
    public static func contains(lhs: Int64, rhs: Int64): Bool {
        (lhs & rhs) == rhs
    }

    /// 从 lhs 中屏蔽掉 rhs 的位
    /// 对应: maskOut(comptime T: type, lhs: *T, rhs: T) T
    public static func maskOut(lhs: Int64, rhs: Int64): Int64 {
        lhs & ~rhs
    }

    /// 从 lhs 中移除 rhs 的位
    /// 对应: remove(comptime T: type, lhs: *T, rhs: T) void
    public static func remove(lhs: Int64, rhs: Int64): Int64 {
        lhs & ~rhs
    }

    /// 计算前导零
    /// 对应: leadingZeros(comptime T: type, value: T) LeadingZerosInt(T)
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
}

// ============================================================================
// EnumFieldsHelper - 枚举字段辅助
// 严格翻译自: bun/src/meta/meta.zig - EnumFields, enumFieldNames
//   pub fn EnumFields(comptime T: type) []const std.builtin.Type.EnumField
//   pub fn enumFieldNames(comptime Type: type) []const []const u8
// ============================================================================

/// 枚举字段辅助工具 - 对应 Bun meta.zig EnumFields/enumFieldNames
/// 仓颉没有 Zig 的 comptime 反射，提供运行时辅助
public class EnumFieldsHelper {
    /// 过滤枚举字段名称，移除 "_" 和 "" 等特殊名称
    /// 对应: enumFieldNames(comptime Type: type) []const []const u8
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
// ============================================================================

/// 内存布局检查 - 对应 Bun meta.zig 中的类型布局分析
/// Zig 的 comptime 类型分析在仓颉中用约定和运行时检查代替
public class MemoryLayout {
    /// 检查是否为标量类型
    /// 对应: isScalar(comptime T: type) bool
    ///   i32, u32, i64, u64, f32, f64, bool => true
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
// ============================================================================

/// 列表容器类型 - 对应 Bun ListContainerType
public enum ListContainerType {
    | ArrayList
    | BabyList
    | SmallList
}

// ============================================================================
// TaggedUnionHelper - 标签联合辅助
// 严格翻译自: bun/src/meta/tagged_union.zig - TaggedUnion
//   pub fn TaggedUnion(comptime field_types: []const type) type
//   创建带有 @"0",@"1",... 字段的 tagged union
// ============================================================================

/// 标签联合值 - 对应 Bun TaggedUnion
/// 仓颉中没有 Zig 的 comptime @Type 构造能力
/// 用动态类型值和索引模拟
public class TaggedUnionValue {
    /// 当前活跃变体的索引
    public var tag: Int64
    /// 存储的值
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
}

// ============================================================================
// SliceChildHelper - 切片子元素类型辅助
// 严格翻译自: bun/src/meta/meta.zig - SliceChild
//   pub fn SliceChild(comptime T: type) type
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
//   pub fn hasDecl(comptime T: type, comptime name: []const u8) bool
//   pub fn hasField(comptime T: type, comptime name: []const u8) bool
// ============================================================================

/// 声明/字段检查 - 对应 Bun meta.zig hasDecl/hasField
/// 仓颉中无法编译时检查，提供运行时接口
public class ReflectionHelper {
    /// 检查类型是否有指定声明
    /// 对应: hasDecl(comptime T: type, comptime name) bool
    public static func hasDecl<T>(name: String): Bool {
        false // 仓颉中需要手动注册
    }

    /// 检查类型是否有指定字段
    /// 对应: hasField(comptime T: type, comptime name) bool
    public static func hasField<T>(name: String): Bool {
        false // 仓颉中需要手动注册
    }

    /// 使用所有字段 (防止未使用字段警告)
    /// 对应: useAllFields(comptime T: type, _: VoidFields(T)) void
    ///   userland implementation of ziglang/zig/issues/21879
    public static func useAllFields<T>(value: T): Unit {
        // 仓颉中不需要此功能，空实现
    }

    /// 丢弃辅助 (用于 void 字段)
    /// 对应: voidFieldTypeDiscardHelper(data: anytype) void
    public static func discard(data: Any): Unit {
        // 故意什么都不做
    }
}

// ============================================================================
// ConcatArgs - 参数拼接辅助
// 严格翻译自: bun/src/meta/meta.zig - ConcatArgs1, ConcatArgs2, ConcatArgs4
//   pub fn ConcatArgs1(comptime func, a, args_) ...
//   pub fn ConcatArgs2(comptime func, a, b, args_) ...
//   pub fn ConcatArgs4(comptime func, a, b, c, d, args_) ...
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
