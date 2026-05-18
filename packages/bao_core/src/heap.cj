// bao_core - 堆分配辅助函数
// 严格翻译自: src/bun_core/heap.rs
//   pub fn alloc<T>(value: T) -> *mut T
//   pub fn into_raw<T: ?Sized>(boxed: Box<T>) -> *mut T
//   pub fn release<'a, T>(boxed: Box<T>) -> &'a mut T
//   pub unsafe fn take<T>(ptr: *mut T) -> Box<T>
//   pub unsafe fn destroy<T>(ptr: *mut T)
// Bun: Zig 的 bun.new/bun.destroy/bun.TrivialNew 模式的 Rust 等价
//   所有操作都是 #[inline(always)] 的空操作, 与 Box::into_raw/from_raw 机器码相同
// 仓颉: GC 管理, 提供兼容的接口语义
package bao_core

// ============================================================================
// Heap - 堆分配辅助
// 严格翻译自: src/bun_core/heap.rs
//   Bun: Centralized heap-pointer round-trip helpers
//   Zig: bun.TrivialNew(@This()) / bun.destroy(this) / bun.new(T, init)
//   Rust: Box::into_raw / Box::from_raw 的薄别名
//   仓颉: GC 管理, 使用引用代替裸指针
// ============================================================================

/// 堆分配辅助 - 对应 Bun heap 模块
/// Bun: 每个函数都是 #[inline(always)] 的空操作
/// 仓颉: GC 管理, 对象自动分配在堆上, 这些函数提供语义兼容
public class Heap {
    /// 堆分配值并返回引用 - 对应 Bun heap::alloc<T>(value: T) -> *mut T
    /// Zig: bun.new(T, init) / bun.TrivialNew
    /// 仓颉: 所有对象都在堆上, 直接创建
    public static func alloc<T>(value: T): T {
        return value
    }

    /// 将值转为原始引用 - 对应 Bun heap::into_raw<T>(boxed: Box<T>) -> *mut T
    /// Bun: Box::into_raw(boxed) — 所有权转移给调用者
    /// 仓颉: GC 管理, 引用即等价
    public static func intoRaw<T>(value: T): T {
        return value
    }

    /// 释放所有权并返回引用 - 对应 Bun heap::release<'a, T>(boxed: Box<T>) -> &'a mut T
    /// Bun: Box::leak(boxed) — 所有权移交给其他管理器
    /// (GC 管理, 引用即等价)
    public static func release<T>(value: T): T {
        return value
    }

    /// 回收堆分配 - 对应 Bun heap::take<T>(ptr: *mut T) -> Box<T>
    /// Bun: unsafe { Box::from_raw(ptr) } — 从裸指针恢复所有权
    /// 仓颉: GC 自动管理, 无需手动回收
    public static func take<T>(value: T): T {
        return value
    }

    /// 销毁堆分配 - 对应 Bun heap::destroy<T>(ptr: *mut T)
    /// Zig: bun.destroy(this) / bun.TrivialDeinit
    /// Bun: unsafe { drop(Box::from_raw(ptr)) }
    /// 仓颉: GC 自动回收, 此函数为空操作
    public static func destroy<T>(value: T): Unit {
        // GC 管理, 自动回收
    }

    /// 堆分配并返回 NonNull 引用 - 对应 Bun heap::alloc_nn<T>(value: T) -> NonNull<T>
    /// Bun: NonNull::from(Box::leak(Box::new(value)))
    /// 仓颉: GC 管理, 引用不为空
    public static func allocNn<T>(value: T): T {
        return value
    }

    /// 将值转为 NonNull 引用 - 对应 Bun heap::into_raw_nn<T>(boxed: Box<T>) -> NonNull<T>
    /// Bun: NonNull::from(Box::leak(boxed))
    /// 仓颉: GC 管理, 引用即等价
    public static func intoRawNn<T>(value: T): T {
        return value
    }
}
