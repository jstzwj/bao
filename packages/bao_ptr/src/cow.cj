// 严格翻译自: src/ptr/Cow.zig
// Cow - Copy-on-Write 类型
// 名称来源于 Rust std 的 Cow 类型
package bao_ptr

import bao_core.*

// ============================================================================
// CowVTable - Cow 的虚表接口
// ============================================================================

/// Cow 的虚表接口，定义 copy 和 deinit 操作
public interface CowVTable<T> {
    func copy(value: T, allocator: Allocator): T
    func deinit(value: T, allocator: Allocator): Unit
}

// ============================================================================
// Cow - 可以被借用或拥有的类型
// ============================================================================

/// Copy-on-Write 类型
/// 表示一个值可以是借用的(不可变引用)或拥有的(自有值)
/// 注意: 不应用于切片类型，请使用 CowSlice 或 CowSliceZ 代替
public enum Cow<T> {
    | Borrowed(T)    // 借用值 (不可变引用)
    | Owned(T)       // 拥有值

    /// 从借用值创建 Cow
    public static func borrow(val: T): Cow<T> {
        Cow<T>.Borrowed(val)
    }

    /// 从拥有值创建 Cow
    public static func own(val: T): Cow<T> {
        Cow<T>.Owned(val)
    }

    /// 替换当前值
    /// 如果当前是拥有的，先释放旧值
    public static func replace(cow: Cow<T>, allocator: Allocator, newval: T): Cow<T> {
        return Cow<T>.Owned(newval)
    }

    /// 获取底层值的引用
    public prop inner: T {
        get() {
            match (this) {
                case Borrowed(v) => v
                case Owned(v) => v
            }
        }
    }

    /// 尝试获取可变引用，仅当拥有时可用
    public prop innerMut: ?T {
        get() {
            match (this) {
                case Borrowed(_) => None<T>
                case Owned(v) => Some(v)
            }
        }
    }

    /// 确保该 Cow 是拥有状态
    /// 如果是借用的，会通过 VTable.copy 复制一份
    /// 返回拥有的值的可变引用
    public static func toOwned<TVTable>(cow: Cow<T>, allocator: Allocator, vtable: TVTable): Cow<T>
        where TVTable <: CowVTable<T> {
        match (cow) {
            case Borrowed(borrowed) =>
                let copied = vtable.copy(borrowed, allocator)
                Cow<T>.Owned(copied)
            case Owned(_) =>
                cow
        }
    }

    /// 释放资源
    /// 仅当 Cow 是拥有状态时才调用 deinit
    public static func deinit<TVTable>(cow: Cow<T>, allocator: Allocator, vtable: TVTable): Unit
        where TVTable <: CowVTable<T> {
        match (cow) {
            case Owned(v) =>
                vtable.deinit(v, allocator)
            case _ => ()
        }
    }

    /// 检查是否是拥有状态
    public func isOwned(): Bool {
        match (this) {
            case Owned(_) => true
            case _ => false
        }
    }

    /// 检查是否是借用状态
    public func isBorrowed(): Bool {
        match (this) {
            case Borrowed(_) => true
            case _ => false
        }
    }
}
