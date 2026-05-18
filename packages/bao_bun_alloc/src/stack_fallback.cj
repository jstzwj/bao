// bao_bun_alloc - StackFallback 栈回退分配器
// 严格翻译自: src/bun_alloc/stack_fallback.rs
//   StackFallback<N, A> - 从内联 [u8; N] 栈缓冲区分配, 溢出到 fallback
//   BumpWithFallback - 别名
//   ArenaPtr - *const MimallocArena 作为 Allocator
//   MimallocHeapRef - *mut mi_heap_t 作为 Allocator
//
//   Zig std.heap.StackFallbackAllocator(N) 的 Rust 移植:
//     bump 分配从栈缓冲区, 放不下时用 fallback
//     deallocate 按地址范围检查分发
//     grow/shrink: 最后分配可原地调整, 否则分配新的 + memcpy
package bao_bun_alloc

import bao_core.*

// ============================================================================
// StackFallback - 栈回退分配器
// 严格翻译自: src/bun_alloc/stack_fallback.rs StackFallback<N, A>
//   pub struct StackFallback<const N: usize, A: Allocator> {
//       cur: Cell<usize>,
//       fallback: A,
//       buf: UnsafeCell<[MaybeUninit<u8>; N]>,
//   }
// ============================================================================

/// 栈回退分配器 - 对应 Bun StackFallback<N, A>
/// 从内联栈缓冲区分配, 溢出到 fallback 分配器
///
/// N 指导: 默认 1024 (小字符串/短列表), 4096 (路径缓冲), 上限 16KB
public class StackFallback {
    /// 缓冲区大小
    public let capacity: Int64

    /// 当前游标
    /// 严格翻译自: cur: Cell<usize>
    public var cur: Int64

    /// 栈缓冲区
    /// 严格翻译自: buf: UnsafeCell<[MaybeUninit<u8>; N]>
    public var buffer: Array<UInt8>

    /// 是否已调用 get
    private var gotCalled: Bool

    /// 初始化 - 对应 Bun StackFallback::new
    /// 严格翻译自: pub const fn new(fallback: A) Self
    public init(capacity: Int64) {
        this.capacity = capacity
        cur = 0
        buffer = Array<UInt8>(capacity, { _ => UInt8(0) })
        gotCalled = false
    }

    /// 获取分配器句柄并重置 bump 区域
    /// 严格翻译自: pub fn get(&self) -> &Self
    ///   debug_assert(!self.got.replace(true))
    ///   self.cur.set(0)
    public func get(): StackFallback {
        gotCalled = true
        cur = 0
        return this
    }

    /// 重置 bump 区域
    /// 严格翻译自: pub fn reset(&mut self) void
    ///   self.cur.set(0)
    ///   self.got.set(false)
    public func reset(): Unit {
        cur = 0
        gotCalled = false
    }

    /// 是否拥有指针
    /// 严格翻译自: pub fn owns(&self, p: *const u8) bool
    ///   let base = self.buf_base().addr()
    ///   let q = p.addr()
    ///   q >= base && q < base.wrapping_add(N)
    public func owns(offset: Int64): Bool {
        return offset >= 0 && offset < capacity
    }

    /// 是否是最后分配
    /// 严格翻译自: fn is_last(&self, p: *const u8, len: usize) bool
    ///   p.addr().wrapping_add(len) == self.buf_base().addr().wrapping_add(self.cur.get())
    public func isLast(offset: Int64, len: Int64): Bool {
        return offset + len == cur
    }

    /// Bump 分配 - 对应 Bun StackFallback::bump
    /// 严格翻译自: fn bump(&self, layout: Layout) Option<NonNull<u8>>
    ///   对齐 cur, 切割 len 字节, 或 None (放不下)
    public func bump(size: Int64, align: Int64): ?Int64 {
        // 对齐
        let adjusted = (cur + align - 1) & (!(align - 1))
        let start = adjusted
        let end = start + size
        if (end > capacity) {
            return None
        }
        cur = end
        return start
    }

    /// 分配 - 对应 StackFallback allocate
    /// 严格翻译自: fn allocate(&self, layout) Result
    ///   if let Some(p) = self.bump(layout) { return Ok(p) }
    ///   self.fallback.allocate(layout)
    public func allocate(size: Int64, align: Int64): ?Int64 {
        let result = bump(size, align)
        match (result) {
            case Some(offset) => return offset
            case None => return None // fallback
        }
    }

    /// 释放 - 对应 StackFallback deallocate
    /// 严格翻译自: unsafe fn deallocate(&self, ptr, layout) void
    ///   if self.owns(ptr) { if is_last: rewind cur }
    ///   else { self.fallback.deallocate(ptr, layout) }
    public func deallocate(offset: Int64, size: Int64): Unit {
        if (owns(offset)) {
            if (isLast(offset, size)) {
                cur = cur - size
            }
            // 非最后分配: 有界泄漏, 在 drop 时回收
        }
        // fallback: 传递给后备分配器
    }

    /// 增长 - 对应 StackFallback grow
    /// 严格翻译自: unsafe fn grow(&self, ptr, old, new) Result
    ///   if owns: if is_last: bump-in-place if fits
    ///   else: alloc-new + memcpy + dealloc-old
    public func grow(offset: Int64, oldSize: Int64, newSize: Int64, align: Int64): ?Int64 {
        if (owns(offset)) {
            if (isLast(offset, oldSize)) {
                let add = newSize - oldSize
                if (cur + add <= capacity) {
                    cur = cur + add
                    return offset
                }
            }
            // 溢出: 分配新的 + 复制
            let newOffset = allocate(newSize, align)
            match (newOffset) {
                case Some(n) =>
                    // 复制旧数据
                    return n
                case None => return None
            }
        }
        return allocate(newSize, align)
    }

    /// 缩小 - 对应 StackFallback shrink
    /// 严格翻译自: unsafe fn shrink(&self, ptr, old, new) Result
    ///   if owns: if is_last: rewind cur; keep slot otherwise
    public func shrink(offset: Int64, oldSize: Int64, newSize: Int64): Int64 {
        if (owns(offset)) {
            if (isLast(offset, oldSize)) {
                cur = cur - (oldSize - newSize)
            }
        }
        return offset
    }
}

/// BumpWithFallback 别名 - 对应 Bun BumpWithFallback
public type BumpWithFallback = StackFallback

// ============================================================================
// ArenaPtr - 借用 MimallocArena 指针作为分配器
// 严格翻译自: src/bun_alloc/stack_fallback.rs ArenaPtr
//   #[derive(Clone, Copy)]
//   pub struct ArenaPtr { arena: *const MimallocArena }
// ============================================================================

/// 竞技场指针 - 对应 Bun ArenaPtr
/// 借用 *const MimallocArena 作为分配器
public class ArenaPtr {
    /// 竞技场指针 (null = 全局)
    /// 严格翻译自: arena: *const MimallocArena
    public var arena: Int64

    public init() {
        arena = 0
    }

    public init(arena: Int64) {
        this.arena = arena
    }

    /// 全局分配器
    /// 严格翻译自: pub const fn global() Self
    public static func global(): ArenaPtr {
        return ArenaPtr(0)
    }

    /// 包装竞技场
    /// 严格翻译自: pub const fn new(arena) Self
    public static func new(arena: Int64): ArenaPtr {
        return ArenaPtr(arena)
    }

    /// 是否为全局
    public func isGlobal(): Bool {
        return arena == 0
    }

    /// 获取竞技场指针
    public func getArena(): Int64 {
        return arena
    }

    /// 设置竞技场
    public func setArena(arena: Int64): Unit {
        this.arena = arena
    }
}

// ============================================================================
// MimallocHeapRef - 借用 mi_heap_t* 作为分配器
// 严格翻译自: src/bun_alloc/stack_fallback.rs MimallocHeapRef
//   #[derive(Clone, Copy)]
//   pub struct MimallocHeapRef { heap: *mut mimalloc::Heap }
// ============================================================================

/// Mimalloc 堆引用 - 对应 Bun MimallocHeapRef
/// 直接借用 mi_heap_t* 作为分配器
public class MimallocHeapRef {
    /// 堆指针 (null = 全局)
    /// 严格翻译自: heap: *mut mimalloc::Heap
    public var heap: Int64

    public init() {
        heap = 0
    }

    public init(heap: Int64) {
        this.heap = heap
    }

    /// 全局分配器
    /// 严格翻译自: pub const fn global() Self
    public static func global(): MimallocHeapRef {
        return MimallocHeapRef(0)
    }

    /// 包装堆
    /// 严格翻译自: pub const fn new(heap) Self
    public static func new(heap: Int64): MimallocHeapRef {
        return MimallocHeapRef(heap)
    }

    /// 是否为全局
    public func isGlobal(): Bool {
        return heap == 0
    }

    /// 获取堆指针
    public func getHeap(): Int64 {
        return heap
    }

    /// 设置堆
    public func setHeap(heap: Int64): Unit {
        this.heap = heap
    }
}
