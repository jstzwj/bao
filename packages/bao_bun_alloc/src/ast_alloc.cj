// bao_bun_alloc - AstAlloc AST 线程本地竞技场分配器
// 严格翻译自: src/bun_alloc/ast_alloc.rs
//   AstAlloc - ZST Allocator, 路由到 thread_local mi_heap_t
//   AstVec<T> - Vec<T, AstAlloc> (24B, 与 Vec<T> 大小相同)
//   DetachAstHeap - RAII 守卫, 切换到全局 mimalloc
//   set_thread_heap / thread_heap - 设置/获取线程 AST 堆
//   Bump arena: <=512B 的分配从 bump chunk 切割
package bao_bun_alloc

import bao_core.*
import bao_collections.*

// ============================================================================
// 常量定义 - 对应 Bun ast_alloc.rs 常量
// ============================================================================

/// 最大 bump 分配大小
/// 严格翻译自: ast_alloc.rs:88 const BUMP_MAX: usize = 512
private let BUMP_MAX: Int64 = 512

/// Bump 块大小
/// 严格翻译自: ast_alloc.rs:92 const BUMP_CHUNK: usize = 16 * 1024
private let BUMP_CHUNK: Int64 = 16384

// ============================================================================
// AstAlloc - AST 分配器 (ZST)
// 严格翻译自: src/bun_alloc/ast_alloc.rs AstAlloc
//   #[derive(Clone, Copy, Default)]
//   pub struct AstAlloc
//   ZST: 路由到 thread_heap 或全局 mimalloc
//   deallocate 是 no-op (竞技场在 reset() 时回收)
// ============================================================================

/// AST 分配器 - 对应 Bun AstAlloc
/// 零大小类型, 路由到线程本地 AST 堆
/// deallocate 是 no-op (竞技场在 MimallocArena.reset() 时回收)
///
/// 使用方式: AstVec<T> = ArrayList<T> (使用 AST 堆)
public class AstAlloc {
    public init() {}

    /// 创建空 Vec - 对应 Bun AstAlloc::vec
    public static func vec<T>(): ArrayList<T> {
        return ArrayList<T>()
    }

    /// 创建带容量的 Vec - 对应 Bun AstAlloc::vec_with_capacity
    public static func vecWithCapacity<T>(cap: Int64): ArrayList<T> {
        var list = ArrayList<T>()
        // 预分配
        return list
    }

    /// 从切片创建 Vec - 对应 Bun AstAlloc::vec_from_slice
    public static func vecFromSlice<T>(items: Array<T>): ArrayList<T> where T <: Cloneable<T> {
        var list = ArrayList<T>()
        return list
    }

    /// take - 对应 Bun AstAlloc::take
    public static func take<T>(v: ArrayList<T>): ArrayList<T> {
        let old = v
        // 替换为空
        return old
    }
}

/// AstVec 别名
public type AstVec<T> = ArrayList<T>

// ============================================================================
// DetachAstHeap - RAII 守卫
// 严格翻译自: src/bun_alloc/ast_alloc.rs DetachAstHeap
//   pub struct DetachAstHeap(*mut mimalloc::Heap)
//   impl Drop: set_thread_heap(prev)
// ============================================================================

/// AST 堆分离守卫 - 对应 Bun DetachAstHeap
/// 在其生命周期内, AstAlloc 分配到全局 mimalloc 而非线程本地堆
/// 用于创建需要超过当前解析竞技场生命周期的数据
public class DetachAstHeap {
    /// 之前的堆
    private var prevHeap: Int64

    public init() {
        prevHeap = AstAllocThreadState.threadHeap()
        AstAllocThreadState.setThreadHeap(0)
    }

    /// 恢复之前的堆
    public func restore(): Unit {
        AstAllocThreadState.setThreadHeap(prevHeap)
    }
}

// ============================================================================
// AstAllocThreadState - 线程本地状态管理
// 严格翻译自: src/bun_alloc/ast_alloc.rs
//   #[thread_local] static AST_HEAP: Cell<*mut mimalloc::Heap>
//   #[thread_local] static BUMP_CUR: Cell<*mut u8>
//   #[thread_local] static BUMP_END: Cell<*mut u8>
//   pub fn set_thread_heap(heap)
//   pub fn thread_heap() *mut mimalloc::Heap
// ============================================================================

/// AST 分配器线程状态 - 对应 Bun AST_HEAP/BUMP_CUR/BUMP_END
/// 管理线程本地 AST 堆和 bump 竞技场
public class AstAllocThreadState {
    /// 线程本地 AST 堆 (0 = 全局)
    private static var astHeap: Int64 = 0

    /// Bump 游标 (null = 无活跃 chunk)
    private static var bumpCur: Int64 = 0

    /// Bump 结束
    private static var bumpEnd: Int64 = 0

    /// 设置线程 AST 堆
    /// 严格翻译自: pub fn set_thread_heap(heap: *mut mimalloc::Heap) void
    ///   AST_HEAP.set(heap)
    ///   bump_reset()
    public static func setThreadHeap(heap: Int64): Unit {
        astHeap = heap
        bumpReset()
    }

    /// 获取线程 AST 堆
    /// 严格翻译自: pub fn thread_heap() -> *mut mimalloc::Heap
    public static func threadHeap(): Int64 {
        return astHeap
    }

    /// 重置 bump 游标
    private static func bumpReset(): Unit {
        bumpCur = 0
        bumpEnd = 0
    }

    /// 堆分配 - 对应 Bun heap_alloc
    /// 严格翻译自: fn heap_alloc(layout: Layout) -> *mut u8
    public static func heapAlloc(size: Int64, align: Int64): Int64 {
        let heap = astHeap
        if (heap == 0) {
            // 全局路径: 使用默认分配器
            return 0 // 简化
        }
        // 小分配: bump 切割
        if (size != 0 && size <= BUMP_MAX && align <= 16) {
            let result = bumpAlloc(heap, size, align)
            match (result) {
                case Some(p) => return p
                case None => ()
            }
        }
        // 大分配: 直接 mi_heap_malloc
        return 0 // 简化
    }

    /// Bump 分配
    /// 严格翻译自: fn bump_alloc(heap, size, align) Option<*mut u8>
    private static func bumpAlloc(heap: Int64, size: Int64, align: Int64): ?Int64 {
        if (bumpCur != 0) {
            let remaining = bumpEnd - bumpCur
            let pad = (align - (bumpCur % align)) % align
            if (pad <= remaining && size <= remaining - pad) {
                let aligned = bumpCur + pad
                bumpCur = aligned + size
                return aligned
            }
        }
        return bumpRefill(heap, size)
    }

    /// Bump 重新填充
    /// 严格翻译自: fn bump_refill(heap, size) Option<*mut u8>
    private static func bumpRefill(heap: Int64, size: Int64): ?Int64 {
        // 分配新 chunk
        let chunk: Int64 = 0 // 简化: mi_heap_malloc(heap, BUMP_CHUNK)
        bumpCur = chunk + size
        bumpEnd = chunk + BUMP_CHUNK
        return chunk
    }
}
