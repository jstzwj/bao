// 严格翻译自: src/mimalloc_sys/mimalloc.zig

package bao_mimalloc_sys

// ============================================================================
// Opaque types
// ============================================================================

public opaque type Heap {}
public opaque type ArenaID {}

// ============================================================================
// Callback function types
// ============================================================================

public type MiDeferredFreeFunc = CFunctionPointer<(Bool, UInt64, CPointer<None>) -> Unit>
public type MiOutputFun = CFunctionPointer<(CPointer<UInt8>, CPointer<None>) -> Unit>
public type MiErrorFun = CFunctionPointer<(Int32, CPointer<None>) -> Unit>

// ============================================================================
// mi_heap_area_t struct
// ============================================================================

public class MiHeapArea {
    public var blocks: CPointer<None> = CPointer<None>()
    public var reserved: UInt64 = 0
    public var committed: UInt64 = 0
    public var used: UInt64 = 0
    public var block_size: UInt64 = 0
    public var full_block_size: UInt64 = 0
    public var reserved1: CPointer<None> = CPointer<None>()

    public init() {}
}

public type MiBlockVisitFun = CFunctionPointer<(CPointer<Heap>, CPointer<MiHeapArea>, CPointer<None>, UInt64, CPointer<None>) -> Bool>

// ============================================================================
// Option enum
// ============================================================================

public enum MiOption {
    show_errors = 0
    show_stats = 1
    verbose = 2
    eager_commit = 3
    arena_eager_commit = 4
    purge_decommits = 5
    allow_large_os_pages = 6
    reserve_huge_os_pages = 7
    reserve_huge_os_pages_at = 8
    reserve_os_memory = 9
    deprecated_segment_cache = 10
    deprecated_page_reset = 11
    abandoned_page_purge = 12
    deprecated_segment_reset = 13
    eager_commit_delay = 14
    purge_delay = 15
    use_numa_nodes = 16
    disallow_os_alloc = 17
    os_tag = 18
    max_errors = 19
    max_warnings = 20
    deprecated_max_segment_reclaim = 21
    destroy_on_exit = 22
    arena_reserve = 23
    arena_purge_mult = 24
    deprecated_purge_extend_delay = 25
    disallow_arena_alloc = 26
    retry_on_oom = 27
    visit_abandoned = 28
    guarded_min = 29
    guarded_max = 30
    guarded_precise = 31
    guarded_sample_rate = 32
    guarded_sample_seed = 33
    generic_collect = 34
    page_reclaim_on_free = 35
    page_full_retain = 36
    page_max_candidates = 37
    max_vabits = 38
    pagemap_commit = 39
    page_commit_on_demand = 40
    page_max_reclaim = 41
    page_cross_thread_max_reclaim = 42
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

@Extern
public func mi_malloc(size: UInt64): CPointer<None>

@Extern
public func mi_calloc(count: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_realloc(p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_expand(p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_free(p: CPointer<None>): Unit

@Extern
public func mi_strdup(s: CPointer<UInt8>): CPointer<UInt8>

@Extern
public func mi_strndup(s: CPointer<UInt8>, n: UInt64): CPointer<UInt8>

@Extern
public func mi_realpath(fname: CPointer<UInt8>, resolved_name: CPointer<UInt8>): CPointer<UInt8>

@Extern
public func mi_malloc_small(size: UInt64): CPointer<None>

@Extern
public func mi_zalloc_small(size: UInt64): CPointer<None>

@Extern
public func mi_zalloc(size: UInt64): CPointer<None>

@Extern
public func mi_mallocn(count: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_reallocn(p: CPointer<None>, count: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_reallocf(p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_usable_size(p: CPointer<None>): UInt64

@Extern
public func mi_good_size(size: UInt64): UInt64

// ============================================================================
// Registration functions
// ============================================================================

@Extern
public func mi_register_deferred_free(deferred_free: MiDeferredFreeFunc, arg: CPointer<None>): Unit

@Extern
public func mi_register_output(out: MiOutputFun, arg: CPointer<None>): Unit

@Extern
public func mi_register_error(fun: MiErrorFun, arg: CPointer<None>): Unit

// ============================================================================
// Runtime / stats functions
// ============================================================================

@Extern
public func mi_collect(force: Bool): Unit

@Extern
public func mi_version(): Int32

@Extern
public func mi_stats_reset(): Unit

@Extern
public func mi_stats_merge(): Unit

@Extern
public func mi_stats_print(out: CPointer<None>): Unit

@Extern
public func mi_stats_print_out(out: MiOutputFun, arg: CPointer<None>): Unit

@Extern
public func mi_process_init(): Unit

@Extern
public func mi_thread_init(): Unit

@Extern
public func mi_thread_done(): Unit

@Extern
public func mi_thread_stats_print_out(out: MiOutputFun, arg: CPointer<None>): Unit

@Extern
public func mi_process_info(
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

@Extern
public func mi_malloc_aligned(size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_malloc_aligned_at(size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_zalloc_aligned(size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_zalloc_aligned_at(size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_calloc_aligned(count: UInt64, size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_calloc_aligned_at(count: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_realloc_aligned(p: CPointer<None>, newsize: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_realloc_aligned_at(p: CPointer<None>, newsize: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

// ============================================================================
// Heap management functions
// ============================================================================

@Extern
public func mi_heap_new(): CPointer<Heap>

@Extern
public func mi_heap_new_ex(heap_tag: Int32, allow_destroy: Bool, arena_id: CPointer<None>): CPointer<Heap>

@Extern
public func mi_heap_delete(heap: CPointer<Heap>): Unit

@Extern
public func mi_heap_destroy(heap: CPointer<Heap>): Unit

@Extern
public func mi_heap_main(): CPointer<Heap>

@Extern
public func mi_heap_contains(heap: CPointer<Heap>, p: CPointer<None>): Bool

@Extern
public func mi_heap_collect(heap: CPointer<Heap>, force: Bool): Unit

@Extern
public func mi_heap_malloc(heap: CPointer<Heap>, size: UInt64): CPointer<None>

@Extern
public func mi_heap_zalloc(heap: CPointer<Heap>, size: UInt64): CPointer<None>

@Extern
public func mi_heap_calloc(heap: CPointer<Heap>, count: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_heap_mallocn(heap: CPointer<Heap>, count: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_heap_malloc_small(heap: CPointer<Heap>, size: UInt64): CPointer<None>

@Extern
public func mi_heap_realloc(heap: CPointer<Heap>, p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_heap_reallocn(heap: CPointer<Heap>, p: CPointer<None>, count: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_heap_reallocf(heap: CPointer<Heap>, p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_heap_strdup(heap: CPointer<Heap>, s: CPointer<UInt8>): CPointer<UInt8>

@Extern
public func mi_heap_strndup(heap: CPointer<Heap>, s: CPointer<UInt8>, n: UInt64): CPointer<UInt8>

@Extern
public func mi_heap_realpath(heap: CPointer<Heap>, fname: CPointer<UInt8>, resolved_name: CPointer<UInt8>): CPointer<UInt8>

// ============================================================================
// Heap aligned allocation functions
// ============================================================================

@Extern
public func mi_heap_malloc_aligned(heap: CPointer<Heap>, size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_heap_malloc_aligned_at(heap: CPointer<Heap>, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_heap_zalloc_aligned(heap: CPointer<Heap>, size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_heap_zalloc_aligned_at(heap: CPointer<Heap>, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_heap_calloc_aligned(heap: CPointer<Heap>, count: UInt64, size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_heap_calloc_aligned_at(heap: CPointer<Heap>, count: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_heap_realloc_aligned(heap: CPointer<Heap>, p: CPointer<None>, newsize: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_heap_realloc_aligned_at(heap: CPointer<Heap>, p: CPointer<None>, newsize: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

// ============================================================================
// Re-zalloc / re-calloc functions
// ============================================================================

@Extern
public func mi_rezalloc(p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_recalloc(p: CPointer<None>, newcount: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_rezalloc_aligned(p: CPointer<None>, newsize: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_rezalloc_aligned_at(p: CPointer<None>, newsize: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_recalloc_aligned(p: CPointer<None>, newcount: UInt64, size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_recalloc_aligned_at(p: CPointer<None>, newcount: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_heap_rezalloc(heap: CPointer<Heap>, p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_heap_recalloc(heap: CPointer<Heap>, p: CPointer<None>, newcount: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_heap_rezalloc_aligned(heap: CPointer<Heap>, p: CPointer<None>, newsize: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_heap_rezalloc_aligned_at(heap: CPointer<Heap>, p: CPointer<None>, newsize: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_heap_recalloc_aligned(heap: CPointer<Heap>, p: CPointer<None>, newcount: UInt64, size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_heap_recalloc_aligned_at(heap: CPointer<Heap>, p: CPointer<None>, newcount: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

// ============================================================================
// Heap visit / check functions
// ============================================================================

@Extern
public func mi_check_owned(p: CPointer<None>): Bool

@Extern
public func mi_heap_visit_blocks(heap: CPointer<Heap>, visit_all_blocks: Bool, visitor: MiBlockVisitFun, arg: CPointer<None>): Bool

@Extern
public func mi_is_in_heap_region(p: CPointer<None>): Bool

@Extern
public func mi_is_redirected(): Bool

// ============================================================================
// OS memory functions
// ============================================================================

@Extern
public func mi_reserve_huge_os_pages_interleave(pages: UInt64, numa_nodes: UInt64, timeout_msecs: UInt64): Int32

@Extern
public func mi_reserve_huge_os_pages_at(pages: UInt64, numa_node: Int32, timeout_msecs: UInt64): Int32

@Extern
public func mi_reserve_os_memory(size: UInt64, commit: Bool, allow_large: Bool): Int32

@Extern
public func mi_manage_os_memory(start: CPointer<None>, size: UInt64, is_committed: Bool, is_large: Bool, is_zero: Bool, numa_node: Int32): Bool

@Extern
public func mi_debug_show_arenas(): Unit

@Extern
public func mi_arena_area(arena_id: CPointer<None>, size: CPointer<UInt64>): CPointer<None>

@Extern
public func mi_reserve_huge_os_pages_at_ex(pages: UInt64, numa_node: Int32, timeout_msecs: UInt64, exclusive: Bool, arena_id: CPointer<CPointer<None>>): Int32

@Extern
public func mi_reserve_os_memory_ex(size: UInt64, commit: Bool, allow_large: Bool, exclusive: Bool, arena_id: CPointer<CPointer<None>>): Int32

@Extern
public func mi_manage_os_memory_ex(start: CPointer<None>, size: UInt64, is_committed: Bool, is_large: Bool, is_zero: Bool, numa_node: Int32, exclusive: Bool, arena_id: CPointer<CPointer<None>>): Bool

@Extern
public func mi_heap_new_in_arena(arena_id: CPointer<None>): CPointer<Heap>

@Extern
public func mi_reserve_huge_os_pages(pages: UInt64, max_secs: Float64, pages_reserved: CPointer<UInt64>): Int32

@Extern
public func mi_thread_set_in_threadpool(): Unit

// ============================================================================
// Option functions
// ============================================================================

@Extern
public func mi_option_is_enabled(option: MiOption): Bool

@Extern
public func mi_option_enable(option: MiOption): Unit

@Extern
public func mi_option_disable(option: MiOption): Unit

@Extern
public func mi_option_set_enabled(option: MiOption, enable: Bool): Unit

@Extern
public func mi_option_set_enabled_default(option: MiOption, enable: Bool): Unit

@Extern
public func mi_option_get(option: MiOption): Int64

@Extern
public func mi_option_get_clamp(option: MiOption, min: Int64, max: Int64): Int64

@Extern
public func mi_option_set(option: MiOption, value: Int64): Unit

@Extern
public func mi_option_set_default(option: MiOption, value: Int64): Unit

// ============================================================================
// POSIX / stdlib compatibility functions
// ============================================================================

@Extern
public func mi_cfree(p: CPointer<None>): Unit

@Extern
public func mi__expand(p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_malloc_size(p: CPointer<None>): UInt64

@Extern
public func mi_malloc_good_size(size: UInt64): UInt64

@Extern
public func mi_malloc_usable_size(p: CPointer<None>): UInt64

@Extern
public func mi_posix_memalign(p: CPointer<CPointer<None>>, alignment: UInt64, size: UInt64): Int32

@Extern
public func mi_memalign(alignment: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_valloc(size: UInt64): CPointer<None>

@Extern
public func mi_pvalloc(size: UInt64): CPointer<None>

@Extern
public func mi_aligned_alloc(alignment: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_reallocarray(p: CPointer<None>, count: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_reallocarr(p: CPointer<None>, count: UInt64, size: UInt64): Int32

@Extern
public func mi_aligned_recalloc(p: CPointer<None>, newcount: UInt64, size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_aligned_offset_recalloc(p: CPointer<None>, newcount: UInt64, size: UInt64, alignment: UInt64, offset: UInt64): CPointer<None>

@Extern
public func mi_wcsdup(s: CPointer<UInt16>): CPointer<UInt16>

@Extern
public func mi_mbsdup(s: CPointer<UInt8>): CPointer<UInt8>

@Extern
public func mi_dupenv_s(buf: CPointer<CPointer<UInt8>>, size: CPointer<UInt64>, name: CPointer<UInt8>): Int32

@Extern
public func mi_wdupenv_s(buf: CPointer<CPointer<UInt16>>, size: CPointer<UInt64>, name: CPointer<UInt16>): Int32

// ============================================================================
// Free helpers
// ============================================================================

@Extern
public func mi_free_size(p: CPointer<None>, size: UInt64): Unit

@Extern
public func mi_free_size_aligned(p: CPointer<None>, size: UInt64, alignment: UInt64): Unit

@Extern
public func mi_free_aligned(p: CPointer<None>, alignment: UInt64): Unit

// ============================================================================
// C++ style new/delete overloads
// ============================================================================

@Extern
public func mi_new(size: UInt64): CPointer<None>

@Extern
public func mi_new_aligned(size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_new_nothrow(size: UInt64): CPointer<None>

@Extern
public func mi_new_aligned_nothrow(size: UInt64, alignment: UInt64): CPointer<None>

@Extern
public func mi_new_n(count: UInt64, size: UInt64): CPointer<None>

@Extern
public func mi_new_realloc(p: CPointer<None>, newsize: UInt64): CPointer<None>

@Extern
public func mi_new_reallocn(p: CPointer<None>, newcount: UInt64, size: UInt64): CPointer<None>
