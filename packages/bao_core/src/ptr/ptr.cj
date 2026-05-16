// ptr 模块 - 指针安全包装器集合
// 严格翻译自: src/ptr/ptr.zig
// Bun: pub const Cow = @import("./Cow.zig").Cow; 等
package bao_core.ptr

// ============================================================================
// 模块重导出
// 对应 Bun ptr.zig 中的所有 pub const 导出
// ============================================================================

/// Cow - Copy-on-Write 类型 (借用或拥有)
// 对应 Bun: pub const Cow = @import("./Cow.zig").Cow
// 定义在 cow.cj 中

/// CowSlice - Copy-on-Write 切片 (u8)
// 对应 Bun: pub const CowSlice = @import("./CowSlice.zig").CowSlice
// 定义在 cow_slice.cj 中

/// CowString - 字节切片的 Cow 别名
// 对应 Bun: pub const CowString = CowSlice(u8)
// CowSlice(u8) 的类型别名

/// Owned - 使用默认分配器的拥有指针
// 对应 Bun: pub const Owned = owned.Owned
// 定义在 owned.cj 中

/// OwnedIn - 使用特定类型分配器的拥有指针
// 对应 Bun: pub const OwnedIn = owned.OwnedIn
// 定义在 owned.cj 中

/// DynamicOwned - 使用任意 std.mem.Allocator 的拥有指针
// 对应 Bun: pub const DynamicOwned = owned.Dynamic
// 定义在 owned.cj 中

/// Shared - 非线程安全的共享指针
// 对应 Bun: pub const Shared = shared.Shared
// 定义在 shared.cj 中

/// AtomicShared - 线程安全的共享指针
// 对应 Bun: pub const AtomicShared = shared.AtomicShared
// 定义在 shared.cj 中

/// ExternalShared - 外部引用计数管理的共享指针
// 对应 Bun: pub const ExternalShared = @import("./external_shared.zig").ExternalShared
// 定义在 external_shared.cj 中

/// RefCount - 已弃用, 使用 Shared(*T) 代替
// 对应 Bun: Deprecated; use `Shared(*T)`.
// 定义在 ref_count.cj 中

/// ThreadSafeRefCount - 已弃用, 使用 AtomicShared(*T) 代替
// 对应 Bun: Deprecated; use `AtomicShared(*T)`.
// 定义在 ref_count.cj 中

/// RefPtr - 引用计数指针包装器
// 对应 Bun: Deprecated; use `Shared(*T)`.
// 定义在 ref_count.cj 中

/// RawRefCount - 原始引用计数包装器
// 对应 Bun: pub const RawRefCount = raw_ref_count.RawRefCount
// 定义在 raw_ref_count.cj 中

/// TaggedPointer - 标记指针 (64位中存储指针+15位标记)
// 对应 Bun: pub const TaggedPointer = @import("./tagged_pointer.zig").TaggedPointer
// 定义在 tagged_pointer.cj 中

/// TaggedPointerUnion - 标记指针联合体
// 对应 Bun: pub const TaggedPointerUnion = @import("./tagged_pointer.zig").TaggedPointerUnion
// 定义在 tagged_pointer.cj 中

/// WeakPtr - 弱引用指针
// 对应 Bun: Deprecated; use `Shared(*T).Weak`.
// 定义在 weak_ptr.cj 中
