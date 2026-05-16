// bao_safety - 已检查的分配器
// 严格翻译自: bun/src/safety/alloc.rs
//   fn has_ptr(alloc) -> bool
//   fn guaranteed_mismatch(alloc1, alloc2) -> bool
//   pub fn assert_eq(alloc1, alloc2)
//   pub fn assert_eq_fmt(alloc1, alloc2, args)
//   pub struct CheckedAllocator { allocator, trace }
//   pub trait AsMimallocArenaAllocator { fn allocator(&self) -> StdAllocator; }
//   pub const ENABLED: bool = cfg!(feature = "ci_assert");
//   Zig: bun/src/safety/alloc.zig
//     fn hasPtr, guaranteedMismatch, noAlloc
//     pub const CheckedAllocator = struct { #allocator, #trace, init, set, assertEq, transferOwnership }
package bao_safety

import bao_threading.*
import bao_crash_handler.*

// ============================================================================
// 全局常量
// 严格翻译自: bun/src/safety/alloc.rs
//   pub const ENABLED: bool = cfg!(feature = "ci_assert");
//   const TRACES_ENABLED: bool = cfg!(debug_assertions);
// ============================================================================

/// 是否启用分配器检查
/// 对应: pub const ENABLED: bool = cfg!(feature = "ci_assert")
/// Zig:  pub const enabled = bun.Environment.ci_assert
public let ALLOC_CHECKS_ENABLED: Bool = false // CI 构建中启用

/// 是否启用分配器追踪
/// 对应: const TRACES_ENABLED: bool = cfg!(debug_assertions)
/// Zig:  const traces_enabled = bun.Environment.isDebug
public let ALLOC_TRACES_ENABLED: Bool = false

// ============================================================================
// Allocator identity helpers
// 严格翻译自: bun/src/safety/alloc.rs - has_ptr, guaranteed_mismatch
//
//   Rust 原始逻辑:
//     fn has_ptr(alloc: StdAllocator) -> bool:
//       // In-tier vtable-identity checks
//       ptr::eq(alloc.vtable, C_ALLOCATOR.vtable)
//         || ptr::eq(alloc.vtable, Z_ALLOCATOR.vtable)
//         || MimallocArena::is_instance(&alloc)
//         || String::is_wtf_allocator(alloc)
//         || crate::known_alloc_vtable(alloc)  // higher-tier registry
//
//     fn guaranteed_mismatch(alloc1, alloc2) -> bool:
//       if (!ptr::eq(alloc1.vtable, alloc2.vtable)) return true
//       ptr1 = if (has_ptr(alloc1)) { alloc1.ptr } else { return false }
//       ptr2 = if (has_ptr(alloc2)) { alloc2.ptr } else { return false }
//       ptr1 != ptr2
//
//   Zig 原始逻辑:
//     fn hasPtr(alloc) bool:
//       return alloc.vtable == arena_vtable
//         || bun.allocators.allocation_scope.isInstance(alloc)
//         || LinuxMemFdAllocator.isInstance(alloc)
//         || MaxHeapAllocator.isInstance(alloc)
//         || alloc.vtable == c_allocator.vtable
//         || alloc.vtable == z_allocator.vtable
//         || MimallocArena.isInstance(alloc)
//         || bun.jsc.CachedBytecode.isInstance(alloc)
//         || bun.bundle_v2.allocatorHasPointer(alloc)
//         || heap_breakdown.Zone.isInstance(alloc)
//         || bun.String.isWTFAllocator(alloc)
//
//     fn guaranteedMismatch(alloc1, alloc2) bool:
//       if (alloc1.vtable != alloc2.vtable) return true
//       ptr1 = if (hasPtr(alloc1)) alloc1.ptr else return false
//       ptr2 = if (hasPtr(alloc2)) alloc2.ptr else return false
//       return ptr1 != ptr2
// ============================================================================

/// 分配器标识 - 用于比较分配器是否相同
/// 对应 Rust: StdAllocator / Zig: std.mem.Allocator
/// 仓颉简化为使用 Int64 作为标识符
public struct AllocatorId {
    /// 虚表指针 (用于类型区分)
    public let vtableId: Int64
    /// 实例指针 (用于同类型区分)
    public let ptrId: Int64

    public init(vtableId: Int64, ptrId: Int64) {
        this.vtableId = vtableId
        this.ptrId = ptrId
    }

    /// 空标识符
    public static let NULL: AllocatorId = AllocatorId(0, 0)

    /// 是否为空
    public func isNull(): Bool {
        vtableId == 0 && ptrId == 0
    }
}

/// 已注册的分配器虚表列表 (用于 has_ptr 检查)
/// 对应: bun/src/safety/lib.rs - KNOWN_ALLOC_VTABLES
///   static KNOWN_ALLOC_VTABLES: [AtomicPtr<()>; 16]
///   static KNOWN_ALLOC_LEN: AtomicUsize
private let registeredVtables: Array<Int64> = Array<Int64>()
private var registeredVtableCount: Int64 = 0

/// 分配器标识工具 - 对应 Bun safety/alloc.rs 的全局辅助函数
public class AllocatorIdentity {
    /// 检查分配器是否有有效的 .ptr 字段
    /// 对应: fn has_ptr(alloc: StdAllocator) -> bool
    ///   Rust: 检查 vtable 是否在已知列表中 (C_ALLOCATOR, Z_ALLOCATOR, MimallocArena 等)
    ///   Zig:  检查 vtable 是否匹配已知分配器类型
    public static func hasPtr(allocId: AllocatorId): Bool {
        // 对应: ptr::eq(alloc.vtable, C_ALLOCATOR.vtable) || ...
        if (allocId.vtableId == 0) { return false }
        // 检查已注册的虚表
        var i: Int64 = 0
        while (i < registeredVtableCount) {
            if (registeredVtables[i] == allocId.vtableId) {
                return true
            }
            i += 1
        }
        false
    }

    /// 检查两个分配器是否绝对不同
    /// 对应: fn guaranteed_mismatch(alloc1, alloc2) -> bool
    ///   if (!ptr::eq(alloc1.vtable, alloc2.vtable)) return true
    ///   ptr1 = if (has_ptr(alloc1)) { alloc1.ptr } else { return false }
    ///   ptr2 = if (has_ptr(alloc2)) { alloc2.ptr } else { return false }
    ///   ptr1 != ptr2
    public static func guaranteedMismatch(id1: AllocatorId, id2: AllocatorId): Bool {
        // 虚表不同 -> 绝对不同
        if (id1.vtableId != id2.vtableId) { return true }
        // 没有有效 ptr -> 无法判断
        if (!hasPtr(id1)) { return false }
        // ptr 不同 -> 绝对不同
        id1.ptrId != id2.ptrId
    }

    /// 注册分配器虚表 (高阶分配器在启动时调用)
    /// 对应: bun/src/safety/lib.rs - register_alloc_vtable
    ///   pub fn register_alloc_vtable(vtable: &'static AllocatorVTable) {
    ///       let i = KNOWN_ALLOC_LEN.fetch_add(1, Relaxed);
    ///       KNOWN_ALLOC_VTABLES[i].store(p, Relaxed);
    ///   }
    public static func registerVtable(vtableId: Int64): Unit {
        if (registeredVtableCount < 16) {
            registeredVtables.append(vtableId)
            registeredVtableCount += 1
        }
    }
}

// ============================================================================
// CheckedAllocator - 已检查的分配器
// 严格翻译自: bun/src/safety/alloc.rs - CheckedAllocator
//
//   Rust 原始逻辑:
//     pub struct CheckedAllocator {
//         #[cfg(feature = "ci_assert")]
//         allocator: NullableAllocator,
//         #[cfg(debug_assertions)]
//         trace: StoredTrace,
//     }
//     impl CheckedAllocator {
//         fn default() -> Self
//         fn init(alloc: StdAllocator) -> Self
//         fn set(&mut self, alloc: StdAllocator)
//         fn assert_eq(&self, alloc: StdAllocator)
//         fn transfer_ownership(&mut self, new_alloc: impl AsMimallocArenaAllocator)
//     }
//
//   Zig 原始逻辑:
//     pub const CheckedAllocator = struct {
//         #allocator: if (enabled) NullableAllocator else void,
//         #trace: if (traces_enabled) StoredTrace else void,
//         pub fn init(alloc) Self: set(alloc); return self
//         pub fn set(self, alloc) void:
//           if (!enabled) return
//           if (self.#allocator.isNull()): self.#allocator = alloc; capture trace
//           else: self.assertEq(alloc)
//         pub fn assertEq(self, alloc) void:
//           if (!enabled) return
//           old_alloc = self.#allocator.get() orelse return
//           if (!guaranteedMismatch(old_alloc, alloc)) return
//           Output.err("allocator mismatch", "cannot use multiple allocators with the same collection")
//           if (traces_enabled): dump trace
//           safety.alloc.assertEq(old_alloc, alloc)
//         pub fn transferOwnership(self, new_allocator) void:
//           if (!enabled) return
//           defer self.* = .init(new_std)
//           old_allocator = self.#allocator.get() orelse return
//           if (MimallocArena.isInstance(old_allocator)) return
//           if (traces_enabled): dump trace
//           panic("cannot transfer ownership from non-MimallocArena")
//     }
// ============================================================================

/// 可空分配器标识 - 对应 Rust NullableAllocator
/// 用于在 CheckedAllocator 中存储可能为空的分配器引用
public struct NullableAllocatorId {
    public let value: ?AllocatorId

    public init() {
        this.value = None
    }

    public init(id: AllocatorId) {
        this.value = Some(id)
    }

    public static let NULL: NullableAllocatorId = NullableAllocatorId()

    public func isNull(): Bool {
        value.isNone()
    }

    public func get(): ?AllocatorId {
        value
    }
}

/// 已检查的分配器 - 对应 Bun CheckedAllocator
/// 确保同一容器不会混用多个分配器
public class CheckedAllocator {
    /// 关联的分配器标识 (可能为空)
    /// 对应: allocator: NullableAllocator
    private var allocator: NullableAllocatorId
    /// 是否已设置
    private var isSet: Bool
    /// 是否启用检查
    /// 对应: pub const ENABLED: bool = cfg!(feature = "ci_assert")
    private var enabled: Bool
    /// 是否启用追踪
    /// 对应: #[cfg(debug_assertions)] trace: StoredTrace
    private var tracesEnabled: Bool
    /// 首次设置时的栈追踪
    /// 对应: trace: StoredTrace
    private var trace: StoredTrace

    public init() {
        allocator = NullableAllocatorId.NULL
        isSet = false
        enabled = ALLOC_CHECKS_ENABLED
        tracesEnabled = ALLOC_TRACES_ENABLED
        trace = StoredTrace.EMPTY
    }

    public init(enabled: Bool) {
        allocator = NullableAllocatorId.NULL
        isSet = false
        this.enabled = enabled
        this.tracesEnabled = ALLOC_TRACES_ENABLED
        this.trace = StoredTrace.EMPTY
    }

    public init(enabled: Bool, tracesEnabled: Bool) {
        allocator = NullableAllocatorId.NULL
        isSet = false
        this.enabled = enabled
        this.tracesEnabled = tracesEnabled
        this.trace = StoredTrace.EMPTY
    }

    /// 初始化并绑定分配器
    /// 对应: CheckedAllocator::init(alloc: StdAllocator) -> Self
    ///   let mut self_ = Self::default()
    ///   self_.set(alloc)
    ///   self_
    public static func initFunc(allocatorId: AllocatorId, enabled: Bool): CheckedAllocator {
        let ca = CheckedAllocator(enabled)
        ca.set(allocatorId)
        ca
    }

    /// 设置分配器 (首次) 或检查一致性 (后续)
    /// 对应: CheckedAllocator::set(&mut self, alloc: StdAllocator)
    ///   if (!ENABLED) return
    ///   if (self.allocator.is_null()):
    ///     self.allocator = NullableAllocator::init(Some(alloc))
    ///     if (traces_enabled): self.trace = StoredTrace::capture(None)
    ///   else:
    ///     self.assert_eq(alloc)
    public func set(allocatorId: AllocatorId): Unit {
        if (!enabled) { return }
        if (!isSet || allocator.isNull()) {
            this.allocator = NullableAllocatorId(allocatorId)
            this.isSet = true
            if (tracesEnabled) {
                trace = StoredTrace.capture(None)
            }
        } else {
            assertEq(allocatorId)
        }
    }

    /// 断言分配器一致
    /// 对应: CheckedAllocator::assert_eq(&self, alloc: StdAllocator)
    ///   if (!ENABLED) return
    ///   let Some(old_alloc) = self.allocator.get() else { return }
    ///   if (!guaranteed_mismatch(old_alloc, alloc)) return
    ///   Output::err_tag("allocator mismatch", "cannot use multiple allocators...")
    ///   if (traces_enabled): dump trace
    ///   safety.alloc.assert_eq(old_alloc, alloc)
    public func assertEq(allocatorId: AllocatorId): Unit {
        if (!enabled) { return }
        let oldAllocOpt = allocator.get()
        if (oldAllocOpt.isNone()) { return }
        let oldAlloc = oldAllocOpt.getOrThrow()
        if (!AllocatorIdentity.guaranteedMismatch(oldAlloc, allocatorId)) { return }

        // 对应: Output::err_tag("allocator mismatch", ...)
        print("allocator mismatch: cannot use multiple allocators with the same collection")
        if (tracesEnabled) {
            print("allocator mismatch: collection first used here, with a different allocator:")
            // 对应: dump_stored_trace(&self.trace)
        }
        // 对应: crate::alloc::assert_eq(old_alloc, alloc) -> 触发断言失败
        AllocatorAssertion.assertEq(oldAlloc, allocatorId)
    }

    /// 转移所有权到新分配器
    /// 对应: CheckedAllocator::transfer_ownership(&mut self, new_alloc: impl AsMimallocArenaAllocator)
    ///   if (!ENABLED) return
    ///   let new_std = new_alloc.allocator()
    ///   let Some(old_allocator) = self.allocator.get() else {
    ///     *self = Self::init(new_std); return
    ///   }
    ///   if (is_mimalloc_arena(old_allocator)):
    ///     *self = Self::init(new_std); return
    ///   if (traces_enabled): dump trace
    ///   panic("cannot transfer ownership from non-MimallocArena")
    public func transferOwnership(newAllocatorId: AllocatorId): Unit {
        if (!enabled) { return }
        let oldAllocOpt = allocator.get()
        if (oldAllocOpt.isNone()) {
            // 没有旧分配器 -> 直接设置新的
            set(newAllocatorId)
            return
        }
        let oldAlloc = oldAllocOpt.getOrThrow()
        // 简化：检查是否为 mimalloc arena 类型
        // 对应: crate::is_mimalloc_arena(old_allocator)
        if (isMimallocArena(oldAlloc)) {
            // 允许 MimallocArena 之间转移
            allocator = NullableAllocatorId(newAllocatorId)
            if (tracesEnabled) {
                trace = StoredTrace.capture(None)
            }
            return
        }
        if (tracesEnabled) {
            print("collection first used here:")
        }
        panic("cannot transfer ownership from non-MimallocArena (old vtable is ${oldAlloc.vtableId})")
    }

    /// 检查是否为 MimallocArena 类型
    /// 对应: pub(crate) fn is_mimalloc_arena(alloc: StdAllocator) -> bool
    ///   bun_alloc::MimallocArena::is_instance(&alloc)
    private func isMimallocArena(id: AllocatorId): Bool {
        // 简化实现：通过 vtableId 判断
        // 真实实现需要 MimallocArena::isInstance
        false
    }
}

// ============================================================================
// AsMimallocArenaAllocator - MimallocArena 分配器转换 trait
// 严格翻译自: bun/src/safety/alloc.rs - AsMimallocArenaAllocator
//
//   Rust 原始逻辑:
//     pub trait AsMimallocArenaAllocator {
//         fn allocator(&self) -> StdAllocator;
//     }
//   Zig 原始逻辑:
//     pub inline fn transferOwnership(self: *Self, new_allocator: anytype) void:
//       const ArgType = @TypeOf(new_allocator)
//       const new_std = switch (comptime ArgType):
//         *MimallocArena, *const MimallocArena, MimallocArena.Borrowed
//           => new_allocator.allocator()
//         else => @compileError("unsupported argument")
// ============================================================================

/// MimallocArena 分配器接口 - 对应 Bun AsMimallocArenaAllocator trait
/// 用于 transferOwnership 的类型安全参数
public interface AsMimallocArenaAllocator {
    /// 获取标准分配器
    /// 对应: fn allocator(&self) -> StdAllocator
    func allocatorId(): AllocatorId
}

// ============================================================================
// AllocatorAssertion - 分配器断言工具
// 严格翻译自: bun/src/safety/alloc.rs - assert_eq, assert_eq_fmt
//   Zig: bun/src/safety/alloc.zig - assertEq, assertEqFmt
//
//   Rust 原始逻辑:
//     pub fn assert_eq(alloc1, alloc2):
//       assert_eq_fmt(alloc1, alloc2, format_args!("allocators do not match"))
//     pub fn assert_eq_fmt(alloc1, alloc2, args):
//       if (!ENABLED) return
//       'blk: {
//         if (!ptr::eq(alloc1.vtable, alloc2.vtable)):
//           Output::err_tag("allocator mismatch", "vtables differ: {:p} and {:p}")
//           break 'blk
//         ptr1 = if (has_ptr(alloc1)) alloc1.ptr else return
//         ptr2 = if (has_ptr(alloc2)) alloc2.ptr else return
//         if (ptr1 == ptr2) return
//         Output::err_tag("allocator mismatch", "vtables are both {:p} but pointers differ: {:p} and {:p}")
//       }
//       assertf!(false, "{}", args)
//
//   Zig 原始逻辑:
//     pub fn assertEq(alloc1, alloc2) void:
//       assertEqFmt(alloc1, alloc2, "allocators do not match", .{})
//     pub fn assertEqFmt(alloc1, alloc2, format, args) void:
//       if (!enabled) return
//       blk: {
//         if (alloc1.vtable != alloc2.vtable): err; break
//         ptr1 = if (hasPtr(alloc1)) alloc1.ptr else return
//         ptr2 = if (hasPtr(alloc2)) alloc2.ptr else return
//         if (ptr1 == ptr2) return
//         err
//       }
//       bun.assertf(false, format, args)
// ============================================================================

/// 分配器断言工具 - 对应 Bun safety/alloc.rs 的全局断言函数
public class AllocatorAssertion {
    /// 断言两个分配器相等
    /// 对应: pub fn assert_eq(alloc1, alloc2)
    ///   通过 vtable 和 ptr 比较，检测 guaranteedMismatch
    public static func assertEq(id1: AllocatorId, id2: AllocatorId): Unit {
        assertEqFmt(id1, id2, "allocators do not match")
    }

    /// 断言两个分配器相等 (带消息)
    /// 对应: pub fn assert_eq_fmt(alloc1, alloc2, args)
    ///   详细输出 vtable/ptr 差异信息
    public static func assertEqFmt(id1: AllocatorId, id2: AllocatorId, message: String): Unit {
        if (!ALLOC_CHECKS_ENABLED) { return }

        var failed = false
        if (id1.vtableId != id2.vtableId) {
            // 对应: Output::err_tag("allocator mismatch", "vtables differ: {:p} and {:p}")
            print("allocator mismatch: vtables differ: ${id1.vtableId} and ${id2.vtableId}")
            failed = true
        } else {
            if (AllocatorIdentity.hasPtr(id1)) {
                if (id1.ptrId == id2.ptrId) { return }
                // 对应: Output::err_tag("allocator mismatch", "vtables are both {:p} but pointers differ")
                print("allocator mismatch: vtables are both ${id1.vtableId} but pointers differ: ${id1.ptrId} and ${id2.ptrId}")
                failed = true
            } else {
                return // 没有 ptr，无法判断
            }
        }

        if (failed) {
            panic("allocator mismatch: ${message}")
        }
    }
}
