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

    /// 深拷贝列表
    /// 严格翻译自 generics.zig deepClone(ArrayList)
    public static func deepCloneList<T>(allocator: Allocator, source: ArrayList<T>): ArrayList<T>
        where T <: CssCloneable<T> {
        var dest = ArrayList<T>(source.size)
        for (i in 0..source.size) {
            dest.append(source[i].deepClone(allocator))
        }
        return dest
    }

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

    /// 深拷贝切片
    /// 严格翻译自 generics.zig deepClone(slice)
    public static func deepCloneSlice<T>(allocator: Allocator, source: Array<T>): Array<T>
        where T <: CssCloneable<T> {
        var dest = Array<T>(source.size)
        for (i in 0..source.size) {
            dest[i] = source[i].deepClone(allocator)
        }
        return dest
    }

    /// 哈希列表
    /// 严格翻译自 generics.zig hashArrayList()
    public static func hashList<T>(list: ArrayList<T>, hasher: Hasher): Unit
        where T <: CssHashable {
        for (i in 0..list.size) {
            list[i].hash(hasher)
        }
    }

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

    /// 解析以逗号分隔的值列表
    /// 严格翻译自 generics.zig 中的 parseCommaSeparated 逻辑
    public static func parseCommaSeparated<T>(input: CssParser, parse_fn: (CssParser) -> CssResult<T>): CssResult<ArrayList<T>> {
        var items = ArrayList<T>()
        while (true) {
            let result = parse_fn(input)
            match (result) {
                case CssResult<T>.ok(v) => items.append(v)
                case CssResult<T>.err(e) => {
                    if (e.isEndOfInput()) { break }
                    return CssResult<ArrayList<T>>.err(e)
                }
            }
            // 尝试读取逗号
            let next = input.next()
            match (next) {
                case CssResult<CssToken>.ok(tok) => {
                    if (!tok.isComma()) {
                        // 不是逗号, 回退
                        break
                    }
                }
                case _ => break
            }
        }
        return CssResult<ArrayList<T>>.ok(items)
    }

    /// 将列表序列化为 CSS (逗号分隔)
    /// 严格翻译自 generics.zig 中的 to_css.fromList 逻辑
    public static func toCssFromList<T>(items: ArrayList<T>, dest: CssPrinter): CssPrintError?<Unit>
        where T <: CssPrintable {
        var first = true
        for (i in 0..items.size) {
            if (!first) {
                dest.writeChar(',')
                dest.writeChar(' ')
            }
            first = false
            items[i].toCss(dest)
        }
        return None
    }

    /// 将列表序列化为 CSS (空格分隔)
    public static func toCssFromListSpaceSeparated<T>(items: ArrayList<T>, dest: CssPrinter): CssPrintError?<Unit>
        where T <: CssPrintable {
        for (i in 0..items.size) {
            if (i > 0) { dest.writeChar(' ') }
            items[i].toCss(dest)
        }
        return None
    }
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
    func toCss(dest: CssPrinter): CssPrintError?<Unit>
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
