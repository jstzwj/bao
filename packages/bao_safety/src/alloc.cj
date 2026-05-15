// bao_safety - 已检查的分配器
// 严格翻译自: bun/src/safety/alloc.zig
//   pub const CheckedAllocator = struct { ... };
//   pub fn assertEq, assertEqFmt
//   fn hasPtr, guaranteedMismatch, noAlloc
//   const enabled = bun.Environment.ci_assert
//   const traces_enabled = bun.Environment.isDebug
package bao_safety

import bao_core.*

// ============================================================================
// CheckedAllocator - 已检查的分配器
// 严格翻译自: bun/src/safety/alloc.zig - CheckedAllocator
//   pub const CheckedAllocator = struct {
//       #allocator: NullableAllocator,
//       #trace: StoredTrace,
//       pub fn init, set, assertEq, transferOwnership
//   };
// ============================================================================

/// 已检查的分配器 - 对应 Bun CheckedAllocator
/// 确保同一容器不会混用多个分配器
public class CheckedAllocator {
    /// 关联的分配器标识 (用于比较)
    private var allocatorId: Int64
    /// 是否已设置
    private var isSet: Bool
    /// 是否启用检查
    private var enabled: Bool

    public init() {
        allocatorId = 0
        isSet = false
        enabled = false // 默认关闭，CI 构建中开启
    }

    public init(enabled: Bool) {
        allocatorId = 0
        isSet = false
        this.enabled = enabled
    }

    /// 初始化并绑定分配器
    /// 对应: CheckedAllocator.init(alloc)
    public static func initFunc(allocatorId: Int64, enabled: Bool): CheckedAllocator {
        let ca = CheckedAllocator(enabled)
        ca.set(allocatorId)
        ca
    }

    /// 设置分配器 (首次) 或检查一致性 (后续)
    /// 对应: CheckedAllocator.set(self: *Self, alloc: Allocator) void
    ///   if (self.#allocator.isNull()) { self.#allocator = ... }
    ///   else { self.assertEq(alloc) }
    public func set(allocatorId: Int64): Unit {
        if (!enabled) { return }
        if (!isSet) {
            this.allocatorId = allocatorId
            this.isSet = true
        } else {
            assertEq(allocatorId)
        }
    }

    /// 断言分配器一致
    /// 对应: CheckedAllocator.assertEq(self: Self, alloc: Allocator) void
    public func assertEq(allocatorId: Int64): Unit {
        if (!enabled) { return }
        if (this.allocatorId != allocatorId) {
            panic("allocator mismatch: cannot use multiple allocators with the same collection")
        }
    }

    /// 转移所有权到新分配器
    /// 对应: CheckedAllocator.transferOwnership(self: *Self, new_allocator) void
    ///   仅允许在特定分配器类型间转移 (MimallocArena)
    public func transferOwnership(newAllocatorId: Int64): Unit {
        if (!enabled) { return }
        // 简化实现：直接更新
        this.allocatorId = newAllocatorId
    }
}

// ============================================================================
// AllocatorAssertion - 分配器断言工具
// 严格翻译自: bun/src/safety/alloc.zig - assertEq, assertEqFmt
//   pub fn assertEq(alloc1: Allocator, alloc2: Allocator) void
//   pub fn assertEqFmt(alloc1, alloc2, comptime format, args) void
//
//   Zig 原始逻辑:
//     fn hasPtr(alloc) bool - 检查分配器是否有有效 .ptr
//     fn guaranteedMismatch(alloc1, alloc2) bool - 检查分配器是否绝对不同
//     pub fn assertEq(alloc1, alloc2) void:
//       assertEqFmt(alloc1, alloc2, "allocators do not match", .{})
//     pub fn assertEqFmt(alloc1, alloc2, format, args) void:
//       if (!enabled) return
//       if (alloc1.vtable != alloc2.vtable) -> err, break
//       if (hasPtr(alloc1)) ptr1 = alloc1.ptr else return
//       if (hasPtr(alloc2)) ptr2 = alloc2.ptr else return
//       if (ptr1 == ptr2) return
//       -> err
//       assertf(false, format, args)
// ============================================================================

/// 分配器断言工具 - 对应 Bun safety/alloc.zig 的全局断言函数
public class AllocatorAssertion {
    /// 断言两个分配器相等
    /// 对应: assertEq(alloc1, alloc2)
    ///   通过 vtable 和 ptr 比较，检测 guaranteedMismatch
    public static func assertEq(id1: Int64, id2: Int64): Unit {
        if (id1 != id2) {
            panic("allocator mismatch: allocators do not match")
        }
    }

    /// 断言两个分配器相等 (带消息)
    /// 对应: assertEqFmt(alloc1, alloc2, comptime format, args)
    ///   带自定义错误消息格式
    public static func assertEqFmt(id1: Int64, id2: Int64, message: String): Unit {
        if (id1 != id2) {
            panic("allocator mismatch: ${message}")
        }
    }
}
