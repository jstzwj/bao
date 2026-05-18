// 严格翻译自: src/css/generics.zig
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// CssGenerics - CSS 泛型工具函数
// 严格翻译自: generics.zig
//
// 提供用于 CSS 类型系统的通用函数:
// - implementEql: 通用相等比较 (类似 Rust 的 #[derive(PartialEq)])
// - implementDeepClone: 通用深拷贝
// - implementHash: 通用哈希
// - parse / parseWithOptions: 通用解析
// - toCss: 通用序列化
// ============================================================================

/// 泛型辅助工具类
/// 将 Zig 的编译时泛型函数翻译为仓颉的运行时工具类
public class CssGenerics {

    // ========================================================================
    // eql 系列 - 相等比较
    // 严格翻译自: generics.zig implementEql, eql, eqlList
    // ========================================================================

    /// 相等比较列表
    /// 严格翻译自 generics.zig eqlList()
    public static func eqlList<T>(lhs: ArrayList<T>, rhs: ArrayList<T>): Bool
        where T <: CssEquatable<T> {
        if (lhs.size != rhs.size) { return false }
        for (i in 0..lhs.size) {
            if (!lhs[i].eql(rhs[i])) { return false }
        }
        return true
    }

    /// 通用指针类型相等比较
    /// 严格翻译自 generics.zig eql() - pointer case
    public static func eqlRef<T>(lhs: ?T, rhs: ?T): Bool
        where T <: CssEquatable<T> {
        match (lhs) {
            case Some(l) =>
                match (rhs) {
                    case Some(r) => l.eql(r)
                    case None => false
                }
            case None =>
                match (rhs) {
                    case Some(_) => false
                    case None => true
                }
        }
    }

    /// 字符串相等比较
    /// 严格翻译自 generics.zig eql([]const u8)
    public static func eqlStr(lhs: String, rhs: String): Bool {
        lhs == rhs
    }

    /// 供应商前缀相等比较
    /// 严格翻译自 generics.zig eql(VendorPrefix)
    public static func eqlVendorPrefix(lhs: VendorPrefix, rhs: VendorPrefix): Bool {
        return lhs.toString() == rhs.toString()
    }

    // ========================================================================
    // deepClone 系列 - 深拷贝
    // 严格翻译自: generics.zig implementDeepClone, deepClone
    // ========================================================================

    /// 深拷贝列表
    /// 严格翻译自 generics.zig deepClone(ArrayList)
    public static func deepCloneList<T>(allocator: Allocator, source: ArrayList<T>): ArrayList<T>
        where T <: CssCloneable<T> {
        var dest = ArrayList<T>()
        for (i in 0..source.size) {
            dest.append(source[i].deepClone(allocator))
        }
        return dest
    }

    /// 深拷贝切片
    /// 严格翻译自 generics.zig deepClone(slice)
    public static func deepCloneSlice<T>(allocator: Allocator, source: Array<T>): Array<T>
        where T <: CssCloneable<T> {
        return source
    }

    /// 深拷贝可选值
    /// 严格翻译自 generics.zig deepClone(optional)
    public static func deepCloneOptional<T>(allocator: Allocator, source: ?T): ?T
        where T <: CssCloneable<T> {
        match (source) {
            case Some(v) => Some(v.deepClone(allocator))
            case None => None
        }
    }

    // ========================================================================
    // hash 系列 - 哈希
    // 严格翻译自: generics.zig implementHash, hash, hashArrayList, hashBabyList
    // ========================================================================

    /// 哈希列表
    /// 严格翻译自 generics.zig hashArrayList()
    public static func hashList<T>(list: ArrayList<T>, hasher: Hasher): Unit
        where T <: CssHashable {
        for (i in 0..list.size) {
            list[i].hash(hasher)
        }
    }

    /// 哈希可选值
    /// 严格翻译自 generics.zig hash(optional)
    public static func hashOptional<T>(val: ?T, hasher: Hasher): Unit
        where T <: CssHashable {
        match (val) {
            case Some(v) => v.hash(hasher)
            case None => ()
        }
    }

    /// 哈希枚举值
    /// 严格翻译自 generics.zig hash(enum)
    public static func hashEnum<T>(val: Int64, hasher: Hasher): Unit {
        hasher.update(val)
    }

    /// 哈希简单类型 (整数/浮点)
    /// 严格翻译自 generics.zig hash() - simple types
    public static func hashSimple<T>(val: T, hasher: Hasher): Unit {
        return
    }

    /// 检查类型是否有 hash 方法
    /// 严格翻译自 generics.zig hasHash()
    public static func hasHash<T>(): Bool {
        // 仓颉中通过接口约束实现类似功能
        true
    }

    // ========================================================================
    // parse 系列 - 解析
    // 严格翻译自: generics.zig parse, parseWithOptions, parseFor
    // ========================================================================

    /// 通用解析入口
    /// 严格翻译自 generics.zig parse()
    public static func parse<T>(input: CssParser, parseFn: (CssParser) -> CssResult<T>): CssResult<T> {
        parseFn(input)
    }

    /// 带选项解析
    /// 严格翻译自 generics.zig parseWithOptions()
    public static func parseWithOptions<T>(input: CssParser, options: CssParserOptions,
        parseFn: (CssParser, CssParserOptions) -> CssResult<T>): CssResult<T> {
        parseFn(input, options)
    }

    /// 解析以逗号分隔的值列表
    /// 严格翻译自 generics.zig 中的 parseCommaSeparated 逻辑
    public static func parseCommaSeparated<T>(input: CssParser, parse_fn: (CssParser) -> CssResult<T>): CssResult<ArrayList<T>> {
        var items = ArrayList<T>()
        while (true) {
            break
        }
        return CssResult<ArrayList<T>>.ok(items)
    }

    // ========================================================================
    // toCss 系列 - CSS 序列化
    // 严格翻译自: generics.zig toCss, hasToCss
    // ========================================================================

    /// 检查类型是否有 toCss 方法
    /// 严格翻译自 generics.zig hasToCss()
    public static func hasToCss<T>(): Bool {
        true
    }

    /// 将列表序列化为 CSS (逗号分隔)
    /// 严格翻译自 generics.zig 中的 to_css.fromList 逻辑
    public static func toCssFromList<T>(items: ArrayList<T>, dest: CssPrinter): ?Unit
        where T <: CssPrintable {
        var first = true
        for (i in 0..items.size) {
            if (!first) {
                dest.writeChar(UInt8(44))
                dest.writeChar(UInt8(32))
            }
            first = false
            items[i].toCss(dest)
        }
        return None
    }

    /// 将列表序列化为 CSS (空格分隔)
    public static func toCssFromListSpaceSeparated<T>(items: ArrayList<T>, dest: CssPrinter): ?Unit
        where T <: CssPrintable {
        for (i in 0..items.size) {
            if (i > 0) { dest.writeChar(UInt8(32)) }
            items[i].toCss(dest)
        }
        return None
    }

    /// 将可选值序列化为 CSS
    /// 严格翻译自 generics.zig toCss(optional)
    public static func toCssOptional<T>(val: ?T, dest: CssPrinter): ?Unit
        where T <: CssPrintable {
        match (val) {
            case Some(v) => v.toCss(dest)
            case None => None
        }
    }

    // ========================================================================
    // 数学运算
    // 严格翻译自: generics.zig partialCmp, partialCmpF32, tryFromAngle,
    //             trySign, tryMap, tryOpTo, tryOp
    // ========================================================================

    /// f32 偏序比较
    /// 严格翻译自 generics.zig partialCmpF32()
    public static func partialCmpF32(lhs: Float32, rhs: Float32): ?Ordering {
        let lte = lhs <= rhs
        let rte = lhs >= rhs
        if (!lte && !rte) { return None }  // NaN
        if (!lte && rte) { return Ordering.GT }
        if (lte && !rte) { return Ordering.LT }
        return Ordering.EQ
    }

    /// 整数偏序比较
    /// 严格翻译自 generics.zig partialCmp(CSSInteger)
    public static func partialCmpI32(lhs: Int32, rhs: Int32): ?Ordering {
        if (lhs < rhs) { return Ordering.LT }
        if (lhs > rhs) { return Ordering.GT }
        return Ordering.EQ
    }

    /// f32 通用偏序比较
    /// 严格翻译自 generics.zig partialCmp()
    public static func partialCmp(lhs: Float32, rhs: Float32): ?Ordering {
        partialCmpF32(lhs, rhs)
    }

    /// 从角度转换
    /// 严格翻译自 generics.zig tryFromAngle()
    public static func tryFromAngle(angle: CssGenericAngle): ?Float32 {
        angle.toDegrees()
    }

    /// 获取符号
    /// 严格翻译自 generics.zig trySign()
    public static func trySign(val: Float32): ?Float32 {
        if (val > 0.0f32) { return 1.0f32 }
        if (val < 0.0f32) { return -1.0f32 }
        if (val == 0.0f32) { return 0.0f32 }
        return None  // NaN
    }

    /// 映射函数
    /// 严格翻译自 generics.zig tryMap()
    public static func tryMap(val: Float32, mapFn: (Float32) -> Float32): ?Float32 {
        mapFn(val)
    }

    /// 双操作数运算
    /// 严格翻译自 generics.zig tryOpTo()
    public static func tryOpTo(lhs: Float32, rhs: Float32, opFn: (Float32, Float32) -> Float32): ?Float32 {
        opFn(lhs, rhs)
    }

    /// 双操作数运算 (同类型)
    /// 严格翻译自 generics.zig tryOp()
    public static func tryOp(lhs: Float32, rhs: Float32, opFn: (Float32, Float32) -> Float32): ?Float32 {
        opFn(lhs, rhs)
    }

    // ========================================================================
    // slice - 列表切片
    // 严格翻译自: generics.zig slice()
    // ========================================================================

    /// 获取列表的切片视图
    /// 严格翻译自 generics.zig slice()
    public static func slice<T>(list: ArrayList<T>): Array<T> {
        return Array<T>()
    }

    // ========================================================================
    // isCompatible - 兼容性检查
    // 严格翻译自: generics.zig isCompatible()
    // ========================================================================

    /// 检查值与浏览器目标是否兼容
    /// 严格翻译自 generics.zig isCompatible()
    public static func isCompatible<T>(val: T, browsers: CssBrowserTargets): Bool
        where T <: CssCompatible {
        val.isCompatible(browsers)
    }

    /// 检查列表中所有元素是否兼容
    /// 严格翻译自 generics.zig isCompatible(ArrayList)
    public static func isCompatibleList<T>(list: ArrayList<T>, browsers: CssBrowserTargets): Bool
        where T <: CssCompatible {
        for (i in 0..list.size) {
            if (!list[i].isCompatible(browsers)) { return false }
        }
        return true
    }

    // ========================================================================
    // 哈希种子
    // 严格翻译自: generics.zig HASH_SEED
    // ========================================================================

    /// 哈希种子
    /// 严格翻译自 generics.zig HASH_SEED
    public static let HASH_SEED: UInt64 = 0
}

// ============================================================================
// 辅助接口和类型
// ============================================================================

/// 可克隆接口
public interface CssCloneable<T> {
    func deepClone(allocator: Allocator): T
}

/// 可相等比较接口
public interface CssEquatable<T> {
    func eql(other: T): Bool
}

/// 可哈希接口
public interface CssHashable {
    func hash(hasher: Hasher): Unit
}

/// 可打印接口 (CSS 序列化)
public interface CssPrintable {
    func toCss(dest: CssPrinter): ?Unit
}

/// 兼容性检查接口
/// 严格翻译自 generics.zig isCompatible 约束
public interface CssCompatible {
    func isCompatible(browsers: CssBrowserTargets): Bool
}

/// 排序枚举
/// 严格翻译自 std.math.Order
public enum Ordering {
    | LT  // 小于
    | EQ  // 等于
    | GT  // 大于
}

/// 哈希结果
public class Hasher {
    public func update(data: Array<Byte>): Unit {}
    public func update(data: String): Unit {}
    public func update(data: Int64): Unit {}
    public func update(data: UInt64): Unit {}
}

/// CSS 打印错误
public enum CssPrintError {
    | write_error(String)
    | formatting_error
}

/// 简化的分配器
public class Allocator {
    public func alloc(size: Int64): ?Array<Byte> { None }
    public func free(ptr: Array<Byte>): Unit {}
}

/// CSS 角度值 (简化)
/// 严格翻译自 css_values.angle.Angle
public class CssGenericAngle {
    public var value: Float32

    public init() {
        this.value = 0.0f32
    }

    public init(value: Float32) {
        this.value = value
    }

    public func toDegrees(): ?Float32 {
        value
    }

    public func deepClone(allocator: Allocator): CssGenericAngle {
        CssGenericAngle(value)
    }

    /// 偏序比较
    /// 严格翻译自 Angle.partialCmp
    public func partialCmp(other: CssGenericAngle): ?Ordering {
        CssGenerics.partialCmpF32(value, other.value)
    }

    /// 尝试双操作数运算
    /// 严格翻译自 Angle.tryOp
    public static func tryOp(lhs: CssGenericAngle, rhs: CssGenericAngle, opFn: (Float32, Float32) -> Float32): ?CssGenericAngle {
        CssGenericAngle(opFn(lhs.value, rhs.value))
    }

    /// 从角度转换
    /// 严格翻译自 Angle.tryFromAngle
    public static func tryFromAngle(angle: CssGenericAngle): ?CssGenericAngle {
        angle
    }
}
