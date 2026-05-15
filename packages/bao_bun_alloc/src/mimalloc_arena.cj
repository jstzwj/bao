// 严格翻译自: src/bun_alloc/MimallocArena.zig
// mimalloc_arena.cj - mimalloc 堆区域分配器

package bao_bun_alloc

import bao_core.*

// ============================================================================
// MimallocArena - mimalloc 堆区域
// 对应 Zig: src/bun_alloc/MimallocArena.zig
// 使用 mimalloc 的堆区域进行内存分配
// 每个区域是独立的堆，可以单独销毁
// ============================================================================

/// 是否启用安全检查
/// 对应 Zig: const safety_checks = bun.Environment.ci_assert
private let SAFETY_CHECKS: Bool = Environment.ciAssert

/// 日志函数
/// 对应 Zig: const log = bun.Output.scoped(.mimalloc, .hidden)
private func log(msg: String): Unit {
    if (Environment.enableLogs) {
        Output.debug(msg, [])
    }
}

/// mimalloc 堆区域分配器
/// 对应 Zig: const Self = @This()
public class MimallocArena {

    /// 内部堆
    /// 对应 Zig: #heap: if (safety_checks) Owned(*DebugHeap) else *mimalloc.Heap
    private var heap: MimallocHeap

    // ========================================================================
    // Default - 默认线程本地堆 (零大小类型)
    // 对应 Zig: pub const Default = struct { ... }
    // ========================================================================

    /// 默认线程本地堆分配器
    /// 对应 Zig: pub const Default = struct { ... }
    /// 使用默认线程本地堆。此类型是零大小的
    public class Default {
        /// 获取分配器
        /// 对应 Zig: pub fn allocator(_: Default) std.mem.Allocator
        public func allocator(): Allocator {
            return Allocator.fromContext(CPointer<Byte>.null(), GlobalMimallocVTable.get())
        }
    }

    // ========================================================================
    // Borrowed - 借用版本
    // 对应 Zig: pub const Borrowed = struct { ... }
    // ========================================================================

    /// 借用版本的 MimallocArena
    /// 对应 Zig: pub const Borrowed = struct { ... }
    public class Borrowed {
        /// 堆引用
        private var heap: MimallocHeap

        public init(heap: MimallocHeap) {
            this.heap = heap
        }

        /// 获取分配器
        /// 对应 Zig: pub fn allocator(self: Borrowed) std.mem.Allocator
        public func allocator(): Allocator {
            return Allocator.fromContext(
                CPointer<Byte>.fromObject(this.heap),
                HeapAllocatorVTable.get()
            )
        }

        /// 获取默认借用实例 (进程主堆)
        /// 对应 Zig: pub fn getDefault() Borrowed
        public static func getDefault(): Borrowed {
            let heap = MimallocLib.miHeapMain()
            if (!SAFETY_CHECKS) {
                return Borrowed(heap: heap)
            }
            return Borrowed(heap: heap)
        }

        /// 垃圾回收
        /// 对应 Zig: pub fn gc(self: Borrowed) void
        public func gc(): Unit {
            MimallocLib.miHeapCollect(this.heap, false)
        }

        /// 帮助捕获内存问题
        /// 对应 Zig: pub fn helpCatchMemoryIssues(self: Borrowed) void
        public func helpCatchMemoryIssues(): Unit {
            if (FeatureFlags.helpCatchMemoryIssues) {
                this.gc()
                MimallocLib.miCollect(false)
            }
        }

        /// 检查指针是否属于此堆
        /// 对应 Zig: pub fn ownsPtr(self: Borrowed, ptr: *const anyopaque) bool
        public func ownsPtr(ptr: CPointer<Byte>): Bool {
            return MimallocLib.miHeapContains(this.heap, ptr)
        }

        /// 从不透明指针创建
        /// 对应 Zig: fn fromOpaque(ptr: *anyopaque) Borrowed
        public static func fromOpaque(ptr: CPointer<Byte>): Borrowed {
            return Borrowed(heap: MimallocHeap.fromPointer(ptr))
        }

        /// 获取底层 mimalloc 堆
        /// 对应 Zig: fn getMimallocHeap(self: Borrowed) *mimalloc.Heap
        public func getMimallocHeap(): MimallocHeap {
            return this.heap
        }

        /// 断言线程锁
        /// 对应 Zig: fn assertThreadLock(self: Borrowed) void
        public func assertThreadLock(): Unit {
            if (SAFETY_CHECKS) {
                this.heap.assertThreadLock()
            }
        }

        /// 对齐分配
        /// 对应 Zig: fn alignedAlloc(self: Borrowed, len: usize, alignment: Alignment) ?[*]u8
        public func alignedAlloc(len: UInt64, alignment: Alignment): ?Array<Byte> {
            log("Malloc: ${len}\n")

            let heap = this.getMimallocHeap()
            let ptr: ?CPointer<Byte> = if (MimallocLib.mustUseAlignedAlloc(alignment)) {
                MimallocLib.miHeapMallocAligned(heap, len, alignment.toByteUnits())
            } else {
                MimallocLib.miHeapMalloc(heap, len)
            }

            if (Environment.isDebug) {
                if (let p = ptr) {
                    let usable = MimallocLib.miMallocUsableSize(p)
                    if (usable < len) {
                        panic("mimalloc: allocated size is too small: ${usable} < ${len}")
                    }
                }
            }

            return ptr.map({ p => Array<Byte>.fromPointer(p, Int64(len)) })
        }

        /// 从 std.mem.Allocator 下转型为 Borrowed
        /// 对应 Zig: pub fn downcast(std_alloc: std.mem.Allocator) Borrowed
        public static func downcast(stdAlloc: Allocator): Borrowed {
            Assert.assertf(
                stdAlloc.getVTable() == HeapAllocatorVTable.get(),
                "not an owned MimallocArena heap"
            )
            return Borrowed.fromOpaque(stdAlloc.getContext())
        }
    }

    // ========================================================================
    // 实例方法
    // ========================================================================

    /// 获取分配器
    /// 对应 Zig: pub fn allocator(self: Self) std.mem.Allocator
    public func allocator(): Allocator {
        return this.borrow().allocator()
    }

    /// 借用此 MimallocArena
    /// 对应 Zig: pub fn borrow(self: Self) Borrowed
    public func borrow(): Borrowed {
        return Borrowed(heap: this.heap)
    }

    /// 获取线程本地默认分配器
    /// 对应 Zig: pub fn getThreadLocalDefault() std.mem.Allocator
    public static func getThreadLocalDefault(): Allocator {
        if (Environment.enableAsan) {
            return Allocator.default()
        }
        return Allocator.fromContext(CPointer<Byte>.null(), GlobalMimallocVTable.get())
    }

    /// 获取后备分配器
    /// 对应 Zig: pub fn backingAllocator(_: Self) std.mem.Allocator
    public func backingAllocator(): Allocator {
        return MimallocArena.getThreadLocalDefault()
    }

    /// 转储线程统计
    /// 对应 Zig: pub fn dumpThreadStats(_: Self) void
    public func dumpThreadStats(): Unit {
        MimallocLib.miThreadStatsPrintOut()
        Output.flush()
    }

    /// 转储统计
    /// 对应 Zig: pub fn dumpStats(_: Self) void
    public func dumpStats(): Unit {
        MimallocLib.miStatsPrintOut()
        Output.flush()
    }

    /// 销毁区域
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        let mimallocHeap = this.borrow().getMimallocHeap()
        if (SAFETY_CHECKS) {
            // 如果有 DebugHeap，先销毁它
        }
        MimallocLib.miHeapDestroy(mimallocHeap)
    }

    /// 初始化新区域
    /// 对应 Zig: pub fn init() Self
    public static func init(): MimallocArena {
        let mimallocHeap = MimallocLib.miHeapNew()
        if (mimallocHeap == None) {
            Output.outOfMemory()
        }
        let arena = MimallocArena()
        arena.heap = mimallocHeap.getOrThrow()
        if (SAFETY_CHECKS) {
            // 包装在 DebugHeap 中
        }
        return arena
    }

    /// 垃圾回收
    /// 对应 Zig: pub fn gc(self: Self) void
    public func gc(): Unit {
        this.borrow().gc()
    }

    /// 帮助捕获内存问题
    /// 对应 Zig: pub fn helpCatchMemoryIssues(self: Self) void
    public func helpCatchMemoryIssues(): Unit {
        this.borrow().helpCatchMemoryIssues()
    }

    /// 检查指针是否属于此区域
    /// 对应 Zig: pub fn ownsPtr(self: Self, ptr: *const anyopaque) bool
    public func ownsPtr(ptr: CPointer<Byte>): Bool {
        return this.borrow().ownsPtr(ptr)
    }

    /// 检查给定分配器是否为 MimallocArena 实例
    /// 对应 Zig: pub fn isInstance(alloc: std.mem.Allocator) bool
    public static func isInstance(alloc: Allocator): Bool {
        let vtable = alloc.getVTable()
        return vtable == HeapAllocatorVTable.get() ||
               vtable == GlobalMimallocVTable.get()
    }
}

// ============================================================================
// HeapAllocatorVTable - 堆分配器虚表 (mi_heap_new 创建的堆)
// 对应 Zig: const heap_allocator_vtable
// ============================================================================

/// 堆分配器虚表
/// 对应 Zig: const heap_allocator_vtable = std.mem.Allocator.VTable{ ... }
public class HeapAllocatorVTable {
    private static let instance: HeapAllocatorVTable = HeapAllocatorVTable()

    public static func get(): HeapAllocatorVTable {
        return instance
    }

    /// 虚表分配
    /// 对应 Zig: fn vtable_alloc(...) ?[*]u8
    public static func vtableAlloc(ptr: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        let borrowed: MimallocArena.Borrowed = MimallocArena.Borrowed.fromOpaque(ptr)
        borrowed.assertThreadLock()
        return borrowed.alignedAlloc(len, alignment)
    }

    /// 虚表 resize
    /// 对应 Zig: fn vtable_resize(...) bool
    public static func vtableResize(ptr: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        let borrowed: MimallocArena.Borrowed = MimallocArena.Borrowed.fromOpaque(ptr)
        borrowed.assertThreadLock()
        return MimallocLib.miExpand(buf, newLen) != None
    }

    /// 虚表 free
    /// 对应 Zig: fn vtable_free(...) void
    public static func vtableFree(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        // mi_free_size 内部只断言大小
        // 不传递该值更快，但有断言是好的
        // 只在 debug 模式启用
        if (Environment.isDebug) {
            Assert.assert(MimallocLib.miIsInHeapRegion(buf))
            if (MimallocLib.mustUseAlignedAlloc(alignment)) {
                MimallocLib.miFreeSizeAligned(buf, buf.size, alignment.toByteUnits())
            } else {
                MimallocLib.miFreeSize(buf, buf.size)
            }
        } else {
            MimallocLib.miFree(buf)
        }
    }

    /// 虚表 remap
    /// 对应 Zig: fn vtable_remap(...) ?[*]u8
    public static func vtableRemap(ptr: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): ?Array<Byte> {
        let borrowed: MimallocArena.Borrowed = MimallocArena.Borrowed.fromOpaque(ptr)
        borrowed.assertThreadLock()
        let heap = borrowed.getMimallocHeap()
        let alignedSize = alignment.toByteUnits()
        let value = MimallocLib.miHeapReallocAligned(heap, buf, newLen, alignedSize)
        return value.map({ v => Array<Byte>.fromPointer(v, Int64(newLen)) })
    }
}

// ============================================================================
// GlobalMimallocVTable - 全局 mimalloc 虚表 (mi_malloc/mi_free)
// 对应 Zig: const global_mimalloc_vtable
// ============================================================================

/// 全局 mimalloc 虚表
/// 对应 Zig: const global_mimalloc_vtable = std.mem.Allocator.VTable{ ... }
public class GlobalMimallocVTable {
    private static let instance: GlobalMimallocVTable = GlobalMimallocVTable()

    public static func get(): GlobalMimallocVTable {
        return instance
    }

    /// 全局虚表分配
    /// 对应 Zig: fn global_vtable_alloc(...) ?[*]u8
    public static func vtableAlloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        log("Malloc: ${len}\n")
        let ptr: ?CPointer<Byte> = if (MimallocLib.mustUseAlignedAlloc(alignment)) {
            MimallocLib.miMallocAligned(len, alignment.toByteUnits())
        } else {
            MimallocLib.miMalloc(len)
        }
        return ptr.map({ p => Array<Byte>.fromPointer(p, Int64(len)) })
    }

    /// 全局虚表 resize
    /// 对应 Zig: fn global_vtable_resize(...) bool
    public static func vtableResize(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        return MimallocLib.miExpand(buf, newLen) != None
    }

    /// 全局虚表 remap
    /// 对应 Zig: fn global_vtable_remap(...) ?[*]u8
    public static func vtableRemap(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): ?Array<Byte> {
        let ptr = MimallocLib.miReallocAligned(buf, newLen, alignment.toByteUnits())
        return ptr.map({ p => Array<Byte>.fromPointer(p, Int64(newLen)) })
    }

    /// 全局虚表 free (与 HeapAllocatorVTable.vtableFree 相同)
    /// 对应 Zig: .free = vtable_free (共用)
    public static func vtableFree(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        HeapAllocatorVTable.vtableFree(ctx, buf, alignment, retAddr)
    }
}
