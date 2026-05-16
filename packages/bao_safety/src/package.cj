// bao_safety - 安全检查与断言工具
// 严格翻译自: bun/src/safety/lib.rs + safety.zig
//
//   Rust (lib.rs):
//     pub mod alloc;
//     mod critical_section; pub use critical_section::CriticalSection;
//     mod thread_lock; pub use thread_lock::{ThreadLock, ThreadLockGuard};
//     pub mod thread_id;
//     pub fn register_alloc_vtable(vtable: &'static AllocatorVTable)
//     pub(crate) fn known_alloc_vtable(alloc: StdAllocator) -> bool
//     pub(crate) fn is_mimalloc_arena(alloc: StdAllocator) -> bool
//     pub fn dump_stored_trace(trace: &StoredTrace)
//
//   Zig (safety.zig):
//     pub const alloc = @import("./alloc.zig");
//     pub const CheckedAllocator = alloc.CheckedAllocator;
//     pub const CriticalSection = @import("./CriticalSection.zig");
//     pub const ThreadLock = @import("./ThreadLock.zig");
//     pub const asan = @import("./asan.zig");
//
// 模块拆分:
//   thread_id.cj         - 线程 ID 工具 (翻译自 thread_id.rs)
//   alloc.cj             - 已检查的分配器 (翻译自 alloc.rs)
//   asan.cj              - 地址消毒器接口 (翻译自 asan.rs)
//   critical_section.cj  - 临界区数据竞争检测 (翻译自 CriticalSection.rs)
//   thread_lock.cj       - 线程锁单线程断言 + ThreadLockGuard (翻译自 ThreadLock.rs)
//   safety.cj            - 安全上下文配置
package bao_safety

// ============================================================================
// Allocator vtable 注册表
// 严格翻译自: bun/src/safety/lib.rs - KNOWN_ALLOC_VTABLES / register_alloc_vtable
//
//   Rust 原始逻辑:
//     const KNOWN_ALLOC_CAP: usize = 16;
//     static KNOWN_ALLOC_VTABLES: [AtomicPtr<()>; KNOWN_ALLOC_CAP]
//     static KNOWN_ALLOC_LEN: AtomicUsize
//
//     pub fn register_alloc_vtable(vtable: &'static AllocatorVTable) {
//         let p = vtable as *const _ as *mut ();
//         let i = KNOWN_ALLOC_LEN.fetch_add(1, Relaxed);
//         if i < KNOWN_ALLOC_CAP {
//             KNOWN_ALLOC_VTABLES[i].store(p, Relaxed);
//         }
//     }
//
//     pub(crate) fn known_alloc_vtable(alloc: StdAllocator) -> bool {
//         let needle = alloc.vtable as *const _ as *mut ();
//         let n = KNOWN_ALLOC_LEN.load(Relaxed).min(KNOWN_ALLOC_CAP);
//         KNOWN_ALLOC_VTABLES[..n].iter()
//             .any(|s| s.load(Relaxed) == needle)
//     }
//
//     pub(crate) fn is_mimalloc_arena(alloc: StdAllocator) -> bool {
//         bun_alloc::MimallocArena::is_instance(&alloc)
//     }
// ============================================================================

/// 分配器虚表注册容量
/// 对应: const KNOWN_ALLOC_CAP: usize = 16
private let KNOWN_ALLOC_CAP: Int64 = 16

/// 已注册的分配器虚表地址数组
/// 对应: static KNOWN_ALLOC_VTABLES: [AtomicPtr<()>; KNOWN_ALLOC_CAP]
private let knownAllocVtables: Array<Int64> = Array<Int64>()

/// 已注册的分配器虚表数量
/// 对应: static KNOWN_ALLOC_LEN: AtomicUsize
private var knownAllocLen: Int64 = 0

/// 注册分配器虚表 (高阶分配器在启动时调用)
/// 对应: pub fn register_alloc_vtable(vtable: &'static AllocatorVTable)
///   Registration is single-threaded at startup, Relaxed ordering is sufficient.
public func registerAllocVtable(vtableId: Int64): Unit {
    if (knownAllocLen < KNOWN_ALLOC_CAP) {
        knownAllocVtables.append(vtableId)
        knownAllocLen += 1
    }
}

/// 检查分配器是否在已注册虚表列表中
/// 对应: pub(crate) fn known_alloc_vtable(alloc: StdAllocator) -> bool
public func knownAllocVtable(vtableId: Int64): Bool {
    var i: Int64 = 0
    while (i < knownAllocLen) {
        if (knownAllocVtables[i] == vtableId) {
            return true
        }
        i += 1
    }
    false
}

/// 检查分配器是否为 MimallocArena
/// 对应: pub(crate) fn is_mimalloc_arena(alloc: StdAllocator) -> bool
///   bun_alloc::MimallocArena::is_instance(&alloc)
public func isMimallocArena(id: AllocatorId): Bool {
    // 简化实现：通过 vtableId 检查
    // 真实实现需要调用 MimallocArena::isInstance
    false
}

/// 打印存储的栈追踪
/// 对应: pub fn dump_stored_trace(trace: &StoredTrace)
///   bun_core::dump_stack_trace(&trace.trace(), DumpStackTraceOptions {
///       frame_count: 10,
///       stop_at_jsc_llint: true,
///       ..Default::default()
///   })
public func dumpStoredTrace(trace: StoredTrace): Unit {
    let st = trace.trace()
    // 对应: bun_core::dump_stack_trace
    // 仓颉中简化为打印帧数
    print("stored trace: ${st.index} frames")
}

// 重导出所有子模块
// 对应 Rust: pub use critical_section::CriticalSection;
// 对应 Rust: pub use thread_lock::{ThreadLock, ThreadLockGuard};
// 对应 Rust: pub use alloc::CheckedAllocator;
// 对应 Zig:  pub const CheckedAllocator = alloc.CheckedAllocator;
