// 严格翻译自: src/runtime/allocators/mod.rs
// allocators/mod.cj - 运行时分配器模块
// 对应 Bun: src/runtime/allocators/mod.rs
//
// 分配器虚表 (vtable) shim 层，导入 bao_core/bao_sys/bao_runtime 类型，
// 因此不能放在 bao_bun_alloc (tier-0) 中。
// 调用者直接导入这些路径 (没有在 bao_bun_alloc 中转发存根)。

package bao_runtime.allocators

import bao_core.*
import bao_bun_alloc.*

// ============================================================================
// 模块重导出
// 对应 Bun: pub mod linux_mem_fd_allocator; pub use linux_mem_fd_allocator::LinuxMemFdAllocator;
// ============================================================================

// LinuxMemFdAllocator 在 bao_bun_alloc 包中定义
// 这里仅重导出供运行时使用
// 对应 Bun: #[path = "LinuxMemFdAllocator.rs"] pub mod linux_mem_fd_allocator;
// 对应 Bun: pub use linux_mem_fd_allocator::LinuxMemFdAllocator;

/// LinuxMemFdAllocator 重导出
/// 对应 Bun: pub use linux_mem_fd_allocator::LinuxMemFdAllocator;
///
/// 这是一个侵入式线程安全的引用计数 memfd 分配器。
/// 当需要多次克隆大量数据时，利用 copy-on-write 内存避免实际复制。
///
/// 步骤:
///   1. 创建 memfd
///   2. 将数据写入 memfd
///   3. 将 memfd 映射到内存
/// 然后，克隆数据只需再次调用 mmap。
///
/// 注意: mmap(), memfd_create(), write() 都有开销，
/// 且进程内不会复用虚拟内存。
/// 因此只应用于期望被多次克隆的大数据块 (如 FormData 中的 Blob)。
public typealias LinuxMemFdAllocator = bao_bun_alloc.LinuxMemFdAllocator

// ============================================================================
// registerSafetyVtables - 注册安全分配器虚表
// 对应 Bun: pub fn register_safety_vtables()
// ============================================================================

/// 将此 crate 的 StdAllocator 虚表地址推入 bao_safety::alloc::has_ptr 注册表
/// 以便分配器不匹配检查可以区分实例。
/// (Zig: safety/alloc.zig:hasPtr 中一系列 inline isInstance 调用链)。
/// 幂等 -- 在启动时调用一次。
///
/// 覆盖范围 vs Zig 规范的 hasPtr 链:
///   - LinuxMemFdAllocator / MimallocArena x2 /
///     bundle_v2::ExternalFreeFunctionAllocator -> 在下方注册
///   - c_allocator / z_allocator / MimallocArena::is_instance /
///     String::is_wtf_allocator -> 直接在 bao_safety::alloc::has_ptr 中检查
///     (bao_bun_alloc 低于安全层)
///   - std.heap.ArenaAllocator / MaxHeapAllocator / CachedBytecode /
///     heap_breakdown::Zone -> 这些在 Rust 移植中没有 StdAllocator vtable;
///     其 is_instance 基于 TypeId 在 &dyn Allocator 上，
///     has_ptr(StdAllocator) 无法分派。
///     故意省略 (安全的欠近似 -- has_ptr 可能返回 false)。
///
/// 对应 Bun: pub fn register_safety_vtables()
public func registerSafetyVtables(): Unit {
    // 注册 LinuxMemFdAllocator 的 StdAllocator vtable
    // 对应 Bun: bun_safety::register_alloc_vtable(linux_mem_fd_allocator::std_vtable())
    SafetyAlloc.registerAllocVtable(LinuxMemFdAllocatorStdVtable.get())

    // 注册 MimallocArena 的 StdAllocator vtables (可能多个实例)
    // 对应 Bun: for vt in bun_alloc::mimalloc_arena::std_vtables() {
    //     bun_safety::register_alloc_vtable(vt);
    // }
    let mimallocVtables = MimallocArena.stdVtables()
    for (vt in mimallocVtables) {
        SafetyAlloc.registerAllocVtable(vt)
    }

    // 注册 bundle_v2 的 ExternalFreeFunctionAllocator vtable
    // 对应 Bun: bun_safety::register_alloc_vtable(&bun_bundler::bundle_v2::EXTERNAL_FREE_VTABLE);
    SafetyAlloc.registerAllocVtable(BundleV2ExternalFreeVtable.get())
}

// ============================================================================
// LinuxMemFdAllocatorStdVtable - 提供 LinuxMemFdAllocator 的 vtable 引用
// 对应 Bun: pub(super) fn std_vtable() -> &'static AllocatorVTable
// ============================================================================

/// LinuxMemFdAllocator StdAllocator vtable 访问器
/// 对应 Bun: allocator_interface::VTABLE
/// 用于 bao_safety::register_alloc_vtable
public class LinuxMemFdAllocatorStdVtable {
    private static let vtable: AllocatorVTable = AllocatorVTable.freeOnly(
        MemFdAllocatorVTable.get()
    )

    /// 获取静态 vtable 引用
    /// 对应 Bun: pub(super) fn std_vtable() -> &'static AllocatorVTable
    public static func get(): AllocatorVTable {
        return vtable
    }
}

// ============================================================================
// SafetyAlloc - 安全分配器注册表
// 对应 Bun: bun_safety::alloc 模块
// ============================================================================

/// 安全分配器注册表
/// 对应 Bun: bun_safety::register_alloc_vtable
///
/// 维护已知 StdAllocator vtable 地址集合，
/// 用于在运行时检查分配器实例类型
public class SafetyAlloc {
    /// 注册一个分配器 vtable
    /// 对应 Bun: pub fn register_alloc_vtable(vtable: &'static AllocatorVTable)
    public static func registerAllocVtable(vtable: AllocatorVTable): Unit {
        // TODO: 实际注册到全局安全检查表
    }

    /// 检查给定分配器是否为已注册的安全分配器
    /// 对应 Bun: bun_safety::alloc::has_ptr
    public static func hasPtr(alloc: Allocator): Bool {
        // TODO: 实际检查
        return false
    }
}

// ============================================================================
// AllocatorVTable - 分配器虚表
// 对应 Bun: bun_alloc::AllocatorVTable
// ============================================================================

/// 分配器虚表
/// 对应 Bun: bun_alloc::AllocatorVTable
/// 包含 alloc, resize, remap, free 函数指针
public class AllocatorVTable {
    public var allocFn: (CPointer<Byte>, UInt64, Alignment, UInt64) -> ?Array<Byte>
    public var resizeFn: (CPointer<Byte>, Array<Byte>, Alignment, UInt64, UInt64) -> Bool
    public var remapFn: (CPointer<Byte>, Array<Byte>, Alignment, UInt64, UInt64) -> ?Array<Byte>
    public var freeFn: (CPointer<Byte>, Array<Byte>, Alignment, UInt64) -> Unit

    public init(allocFn: (CPointer<Byte>, UInt64, Alignment, UInt64) -> ?Array<Byte>,
                resizeFn: (CPointer<Byte>, Array<Byte>, Alignment, UInt64, UInt64) -> Bool,
                remapFn: (CPointer<Byte>, Array<Byte>, Alignment, UInt64, UInt64) -> ?Array<Byte>,
                freeFn: (CPointer<Byte>, Array<Byte>, Alignment, UInt64) -> Unit) {
        this.allocFn = allocFn
        this.resizeFn = resizeFn
        this.remapFn = remapFn
        this.freeFn = freeFn
    }

    /// 创建仅有 free 的虚表 (不执行实际分配或 resize)
    /// 对应 Bun: AllocatorVTable::free_only(free)
    /// 用于 LinuxMemFdAllocator: alloc = noAlloc, resize = noResize, remap = noRemap, free = free
    public static func freeOnly(freeFn: (CPointer<Byte>, Array<Byte>, Alignment, UInt64) -> Unit): AllocatorVTable {
        return AllocatorVTable(
            allocFn: { ctx, len, alignment, retAddr -> None },         // noAlloc
            resizeFn: { ctx, buf, alignment, newLen, retAddr -> false }, // noResize
            remapFn: { ctx, buf, alignment, newLen, retAddr -> None },   // noRemap
            freeFn: freeFn
        )
    }
}

// ============================================================================
// MimallocArena - Mimalloc 竞技场分配器桥接
// 对应 Bun: bun_alloc::mimalloc_arena::std_vtables()
// ============================================================================

/// Mimalloc 竞技场分配器桥接
/// 对应 Bun: bun_alloc::mimalloc_arena
/// 提供多个 StdAllocator vtable 注册
public class MimallocArena {
    /// 获取所有 StdAllocator vtable
    /// 对应 Bun: pub fn std_vtables() -> impl Iterator<Item = &'static AllocatorVTable>
    public static func stdVtables(): ArrayList<AllocatorVTable> {
        // TODO: 返回实际的 mimalloc arena vtable 列表
        return ArrayList<AllocatorVTable>()
    }
}

// ============================================================================
// BundleV2ExternalFreeVtable - bundle_v2 外部释放函数虚表
// 对应 Bun: bun_bundler::bundle_v2::EXTERNAL_FREE_VTABLE
// ============================================================================

/// bundle_v2 的 ExternalFreeFunctionAllocator 静态虚表
/// 对应 Bun: pub static EXTERNAL_FREE_VTABLE: AllocatorVTable
public class BundleV2ExternalFreeVtable {
    private static let vtable: AllocatorVTable = AllocatorVTable.freeOnly(
        { ctx, buf, alignment, retAddr ->
            // TODO: 实际外部释放函数
        }
    )

    public static func get(): AllocatorVTable {
        return vtable
    }
}

// ============================================================================
// Alignment - 内存对齐
// 对应 Bun: bun_alloc::Alignment
// ============================================================================

/// 内存对齐类型
/// 对应 Bun: bun_alloc::Alignment (std.mem.Alignment)
public struct Alignment {
    public var value: UInt64

    public init(value: UInt64) {
        this.value = value
    }

    /// 默认对齐 (8 字节)
    public static func default(): Alignment {
        return Alignment(value: 8)
    }
}

// ============================================================================
// Allocator - 标准分配器
// 对应 Bun: bun_alloc::StdAllocator (std.mem.Allocator)
// ============================================================================

/// 标准分配器
/// 对应 Bun: bun_alloc::StdAllocator
/// 包含指针和虚表
public class Allocator {
    public var ptr: CPointer<Byte>
    public var vtable: AllocatorVTable

    public init(ptr: CPointer<Byte>, vtable: AllocatorVTable) {
        this.ptr = ptr
        this.vtable = vtable
    }

    /// 从上下文创建分配器
    public static func fromContext(ptr: CPointer<Byte>, vtable: AllocatorVTable): Allocator {
        return Allocator(ptr: ptr, vtable: vtable)
    }

    /// 获取后端类型
    public func getBackend(): AllocatorBackend {
        // TODO: 基于 vtable 指针比较确定后端类型
        return AllocatorBackend.generic
    }

    /// 获取上下文指针
    public func getContext(): CPointer<Byte> {
        return this.ptr
    }
}

/// 分配器后端类型
/// 对应 Bun: 用于 is_instance 检查的后端标识
public enum AllocatorBackend {
    | generic        // 通用分配器
    | linuxMemFd     // LinuxMemFdAllocator
    | mimallocArena  // MimallocArena
    | externalFree   // ExternalFreeFunctionAllocator
}

// ported from: src/runtime/allocators/mod.rs
