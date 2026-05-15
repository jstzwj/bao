// 严格翻译自: src/mimalloc_sys/mimalloc.zig

package bao_mimalloc_sys

// ============================================================================
// Opaque types
// ============================================================================

@C
public struct Heap {}
@C
public struct ArenaID {}

// ============================================================================
// Callback function types
// ============================================================================

public type MiDeferredFreeFunc = CFunc<(Bool, UInt64, CPointer<Unit>) -> Unit>
public type MiOutputFun = CFunc<(CPointer<UInt8>, CPointer<Unit>) -> Unit>
public type MiErrorFun = CFunc<(Int32, CPointer<Unit>) -> Unit>

// ============================================================================
// mi_heap_area_t struct
// ============================================================================

public class MiHeapArea {
    public var blocks: CPointer<Unit> = CPointer<Unit>()
    public var reserved: UInt64 = 0
    public var committed: UInt64 = 0
    public var used: UInt64 = 0
    public var block_size: UInt64 = 0
    public var full_block_size: UInt64 = 0
    public var reserved1: CPointer<Unit> = CPointer<Unit>()

    public init() {}
}

public type MiBlockVisitFun = CFunc<(CPointer<Heap>, CPointer<MiHeapArea>, CPointer<Unit>, UInt64, CPointer<Unit>) -> Bool>

// ============================================================================
// Option enum
// ============================================================================

public enum MiOption {
    | show_errors
    | show_stats
    | verbose
    | eager_commit
    | arena_eager_commit
    | purge_decommits
    | allow_large_os_pages
    | reserve_huge_os_pages
    | reserve_huge_os_pages_at
    | reserve_os_memory
    | deprecated_segment_cache
    | deprecated_page_reset
    | abandoned_page_purge
    | deprecated_segment_reset
    | eager_commit_delay
    | purge_delay
    | use_numa_nodes
    | disallow_os_alloc
    | os_tag
    | max_errors
    | max_warnings
    | deprecated_max_segment_reclaim
    | destroy_on_exit
    | arena_reserve
    | arena_purge_mult
    | deprecated_purge_extend_delay
    | disallow_arena_alloc
    | retry_on_oom
    | visit_abandoned
    | guarded_min
    | guarded_max
    | guarded_precise
    | guarded_sample_rate
    | guarded_sample_seed
    | generic_collect
    | page_reclaim_on_free
    | page_full_retain
    | page_max_candidates
    | max_vabits
    | pagemap_commit
    | page_commit_on_demand
    | page_max_reclaim
    | page_cross_thread_max_reclaim
}

// ============================================================================
// Constants
// ============================================================================

public let MI_SMALL_WSIZE_MAX: Int32 = 128
// MI_SMALL_SIZE_MAX = MI_SMALL_WSIZE_MAX * sizeof(pointer), platform-dependent
public let MI_SMALL_SIZE_MAX: UInt64 = 1024 // 128 * 8 for 64-bit
public let MI_ALIGNMENT_MAX: UInt64 = 16777216 // 16 * 1024 * 1024
public let MI_MAX_ALIGN_SIZE: Int32 = 16

// ============================================================================
// Basic allocation FFI extern functions
// ============================================================================

foreign func mi_malloc(size: UInt64): CPointer<Unit>

foreign func mi_calloc(count: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_realloc(p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_expand(p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_free(p: CPointer<Unit>): Unit

foreign func mi_strdup(s: CPointer<UInt8>): CPointer<UInt8>

foreign func mi_strndup(s: CPointer<UInt8>, n: UInt64): CPointer<UInt8>

foreign func mi_realpath(fname: CPointer<UInt8>, resolved_name: CPointer<UInt8>): CPointer<UInt8>

foreign func mi_malloc_small(size: UInt64): CPointer<Unit>

foreign func mi_zalloc_small(size: UInt64): CPointer<Unit>

foreign func mi_zalloc(size: UInt64): CPointer<Unit>

foreign func mi_mallocn(count: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_reallocn(p: CPointer<Unit>, count: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_reallocf(p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_usable_size(p: CPointer<Unit>): UInt64

foreign func mi_good_size(size: UInt64): UInt64

// ============================================================================
// Registration functions
// ============================================================================

foreign func mi_register_deferred_free(deferred_free: MiDeferredFreeFunc, arg: CPointer<Unit>): Unit

foreign func mi_register_output(out: MiOutputFun, arg: CPointer<Unit>): Unit

foreign func mi_register_error(fun: MiErrorFun, arg: CPointer<Unit>): Unit

// ============================================================================
// Runtime / stats functions
// ============================================================================

foreign func mi_collect(force: Bool): Unit

foreign func mi_version(): Int32

foreign func mi_stats_reset(): Unit

foreign func mi_stats_merge(): Unit

foreign func mi_stats_print(out: CPointer<Unit>): Unit

foreign func mi_stats_print_out(out: MiOutputFun, arg: CPointer<Unit>): Unit

foreign func mi_process_init(): Unit

foreign func mi_thread_init(): Unit

foreign func mi_thread_done(): Unit

foreign func mi_thread_stats_print_out(out: MiOutputFun, arg: CPointer<Unit>): Unit

foreign func mi_process_info(
    elapsed_msecs: CPointer<UInt64>,
    user_msecs: CPointer<UInt64>,
    system_msecs: CPointer<UInt64>,
    current_rss: CPointer<UInt64>,
    peak_rss: CPointer<UInt64>,
    current_commit: CPointer<UInt64>,
    peak_commit: CPointer<UInt64>,
    page_faults: CPointer<UInt64>
): Unit

// ============================================================================
// Aligned allocation functions
// ============================================================================

foreign func mi_malloc_aligned(size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_malloc_aligned_at(size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_zalloc_aligned(size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_zalloc_aligned_at(size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_calloc_aligned(count: UInt64, size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_calloc_aligned_at(count: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_realloc_aligned(p: CPointer<Unit>, newsize: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_realloc_aligned_at(p: CPointer<Unit>, newsize: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

// ============================================================================
// Heap management functions
// ============================================================================

foreign func mi_heap_new(): CPointer<Heap>

foreign func mi_heap_new_ex(heap_tag: Int32, allow_destroy: Bool, arena_id: CPointer<Unit>): CPointer<Heap>

foreign func mi_heap_delete(heap: CPointer<Heap>): Unit

foreign func mi_heap_destroy(heap: CPointer<Heap>): Unit

foreign func mi_heap_main(): CPointer<Heap>

foreign func mi_heap_contains(heap: CPointer<Heap>, p: CPointer<Unit>): Bool

foreign func mi_heap_collect(heap: CPointer<Heap>, force: Bool): Unit

foreign func mi_heap_malloc(heap: CPointer<Heap>, size: UInt64): CPointer<Unit>

foreign func mi_heap_zalloc(heap: CPointer<Heap>, size: UInt64): CPointer<Unit>

foreign func mi_heap_calloc(heap: CPointer<Heap>, count: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_heap_mallocn(heap: CPointer<Heap>, count: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_heap_malloc_small(heap: CPointer<Heap>, size: UInt64): CPointer<Unit>

foreign func mi_heap_realloc(heap: CPointer<Heap>, p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_heap_reallocn(heap: CPointer<Heap>, p: CPointer<Unit>, count: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_heap_reallocf(heap: CPointer<Heap>, p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_heap_strdup(heap: CPointer<Heap>, s: CPointer<UInt8>): CPointer<UInt8>

foreign func mi_heap_strndup(heap: CPointer<Heap>, s: CPointer<UInt8>, n: UInt64): CPointer<UInt8>

foreign func mi_heap_realpath(heap: CPointer<Heap>, fname: CPointer<UInt8>, resolved_name: CPointer<UInt8>): CPointer<UInt8>

// ============================================================================
// Heap aligned allocation functions
// ============================================================================

foreign func mi_heap_malloc_aligned(heap: CPointer<Heap>, size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_heap_malloc_aligned_at(heap: CPointer<Heap>, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_heap_zalloc_aligned(heap: CPointer<Heap>, size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_heap_zalloc_aligned_at(heap: CPointer<Heap>, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_heap_calloc_aligned(heap: CPointer<Heap>, count: UInt64, size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_heap_calloc_aligned_at(heap: CPointer<Heap>, count: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_heap_realloc_aligned(heap: CPointer<Heap>, p: CPointer<Unit>, newsize: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_heap_realloc_aligned_at(heap: CPointer<Heap>, p: CPointer<Unit>, newsize: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

// ============================================================================
// Re-zalloc / re-calloc functions
// ============================================================================

foreign func mi_rezalloc(p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_recalloc(p: CPointer<Unit>, newcount: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_rezalloc_aligned(p: CPointer<Unit>, newsize: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_rezalloc_aligned_at(p: CPointer<Unit>, newsize: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_recalloc_aligned(p: CPointer<Unit>, newcount: UInt64, size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_recalloc_aligned_at(p: CPointer<Unit>, newcount: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_heap_rezalloc(heap: CPointer<Heap>, p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_heap_recalloc(heap: CPointer<Heap>, p: CPointer<Unit>, newcount: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_heap_rezalloc_aligned(heap: CPointer<Heap>, p: CPointer<Unit>, newsize: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_heap_rezalloc_aligned_at(heap: CPointer<Heap>, p: CPointer<Unit>, newsize: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_heap_recalloc_aligned(heap: CPointer<Heap>, p: CPointer<Unit>, newcount: UInt64, size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_heap_recalloc_aligned_at(heap: CPointer<Heap>, p: CPointer<Unit>, newcount: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

// ============================================================================
// Heap visit / check functions
// ============================================================================

foreign func mi_check_owned(p: CPointer<Unit>): Bool

foreign func mi_heap_visit_blocks(heap: CPointer<Heap>, visit_all_blocks: Bool, visitor: MiBlockVisitFun, arg: CPointer<Unit>): Bool

foreign func mi_is_in_heap_region(p: CPointer<Unit>): Bool

foreign func mi_is_redirected(): Bool

// ============================================================================
// OS memory functions
// ============================================================================

foreign func mi_reserve_huge_os_pages_interleave(pages: UInt64, numa_nodes: UInt64, timeout_msecs: UInt64): Int32

foreign func mi_reserve_huge_os_pages_at(pages: UInt64, numa_node: Int32, timeout_msecs: UInt64): Int32

foreign func mi_reserve_os_memory(size: UInt64, commit: Bool, allow_large: Bool): Int32

foreign func mi_manage_os_memory(start: CPointer<Unit>, size: UInt64, is_committed: Bool, is_large: Bool, is_zero: Bool, numa_node: Int32): Bool

foreign func mi_debug_show_arenas(): Unit

foreign func mi_arena_area(arena_id: CPointer<Unit>, size: CPointer<UInt64>): CPointer<Unit>

foreign func mi_reserve_huge_os_pages_at_ex(pages: UInt64, numa_node: Int32, timeout_msecs: UInt64, exclusive: Bool, arena_id: CPointer<CPointer<Unit>>): Int32

foreign func mi_reserve_os_memory_ex(size: UInt64, commit: Bool, allow_large: Bool, exclusive: Bool, arena_id: CPointer<CPointer<Unit>>): Int32

foreign func mi_manage_os_memory_ex(start: CPointer<Unit>, size: UInt64, is_committed: Bool, is_large: Bool, is_zero: Bool, numa_node: Int32, exclusive: Bool, arena_id: CPointer<CPointer<Unit>>): Bool

foreign func mi_heap_new_in_arena(arena_id: CPointer<Unit>): CPointer<Heap>

foreign func mi_reserve_huge_os_pages(pages: UInt64, max_secs: Float64, pages_reserved: CPointer<UInt64>): Int32

foreign func mi_thread_set_in_threadpool(): Unit

// ============================================================================
// Option functions
// ============================================================================

foreign func mi_option_is_enabled(option: MiOption): Bool

foreign func mi_option_enable(option: MiOption): Unit

foreign func mi_option_disable(option: MiOption): Unit

foreign func mi_option_set_enabled(option: MiOption, enable: Bool): Unit

foreign func mi_option_set_enabled_default(option: MiOption, enable: Bool): Unit

foreign func mi_option_get(option: MiOption): Int64

foreign func mi_option_get_clamp(option: MiOption, min: Int64, max: Int64): Int64

foreign func mi_option_set(option: MiOption, value: Int64): Unit

foreign func mi_option_set_default(option: MiOption, value: Int64): Unit

// ============================================================================
// POSIX / stdlib compatibility functions
// ============================================================================

foreign func mi_cfree(p: CPointer<Unit>): Unit

foreign func mi__expand(p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_malloc_size(p: CPointer<Unit>): UInt64

foreign func mi_malloc_good_size(size: UInt64): UInt64

foreign func mi_malloc_usable_size(p: CPointer<Unit>): UInt64

foreign func mi_posix_memalign(p: CPointer<CPointer<Unit>>, alignment: UInt64, size: UInt64): Int32

foreign func mi_memalign(alignment: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_valloc(size: UInt64): CPointer<Unit>

foreign func mi_pvalloc(size: UInt64): CPointer<Unit>

foreign func mi_aligned_alloc(alignment: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_reallocarray(p: CPointer<Unit>, count: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_reallocarr(p: CPointer<Unit>, count: UInt64, size: UInt64): Int32

foreign func mi_aligned_recalloc(p: CPointer<Unit>, newcount: UInt64, size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_aligned_offset_recalloc(p: CPointer<Unit>, newcount: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<Unit>

foreign func mi_wcsdup(s: CPointer<UInt16>): CPointer<UInt16>

foreign func mi_mbsdup(s: CPointer<UInt8>): CPointer<UInt8>

foreign func mi_dupenv_s(buf: CPointer<CPointer<UInt8>>, size: CPointer<UInt64>, name: CPointer<UInt8>): Int32

foreign func mi_wdupenv_s(buf: CPointer<CPointer<UInt16>>, size: CPointer<UInt64>, name: CPointer<UInt16>): Int32

// ============================================================================
// Free helpers
// ============================================================================

foreign func mi_free_size(p: CPointer<Unit>, size: UInt64): Unit

foreign func mi_free_size_aligned(p: CPointer<Unit>, size: UInt64, alignment: UInt64): Unit

foreign func mi_free_aligned(p: CPointer<Unit>, alignment: UInt64): Unit

// ============================================================================
// C++ style new/delete overloads
// ============================================================================

foreign func mi_new(size: UInt64): CPointer<Unit>

foreign func mi_new_aligned(size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_new_nothrow(size: UInt64): CPointer<Unit>

foreign func mi_new_aligned_nothrow(size: UInt64, alignment: UInt64): CPointer<Unit>

foreign func mi_new_n(count: UInt64, size: UInt64): CPointer<Unit>

foreign func mi_new_realloc(p: CPointer<Unit>, newsize: UInt64): CPointer<Unit>

foreign func mi_new_reallocn(p: CPointer<Unit>, newcount: UInt64, size: UInt64): CPointer<Unit>
