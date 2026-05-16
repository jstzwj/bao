// 严格翻译自: src/bun_alloc/MaxHeapAllocator.zig
// max_heap_allocator.cj - 单次分配分配器 (MaxHeapAllocator)

package bao_bun_alloc

import bao_core.*

// ============================================================================
// MaxHeapAllocator - 单次堆分配器
// 对应 Zig: src/bun_alloc/MaxHeapAllocator.zig
// 仅允许单次分配，用于限制内存使用
// ============================================================================

/// 最大堆分配器
/// 对应 Zig: MaxHeapAllocator.zig
/// 只允许单次分配，分配后不支持 resize
public class MaxHeapAllocator {

    /// 内部数组列表 (字节缓冲区)
    /// 对应 Zig: array_list: std.array_list.AlignedManaged(u8, .of(std.c.max_align_t))
    private var arrayList: ArrayList<Byte> = ArrayList<Byte>()

    /// 分配内存
    /// 对应 Zig: fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8
    public func alloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        Assert.assert(alignment.toByteUnits() <= UInt64(MAX_ALIGN_T))
        // 重置列表长度为 0
        this.arrayList.clear()
        // 确保总容量
        if (!this.arrayList.ensureCapacity(Int64(len))) {
            return None
        }
        // 设置长度
        this.arrayList.resize(Int64(len))
        return this.arrayList.toArray()
    }

    /// resize - 不支持
    /// 对应 Bun: resize 始终 panic
    public func resize(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        panic("MaxHeapAllocator.resize is unsupported")
    }

    /// 释放 - 空操作
    /// 对应 Zig: fn free(...) void {}
    public func free(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        // 空操作
    }

    /// 重置分配器
    /// 对应 Zig: pub fn reset(self: *Self) void
    public func reset(): Unit {
        this.arrayList.clear()
    }

    /// 销毁分配器
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        this.arrayList.clear()
        this.arrayList = ArrayList<Byte>()
    }

    /// 初始化分配器
    /// 对应 Zig: pub fn init(self: *Self, allocator: std.mem.Allocator) std.mem.Allocator
    public static func initFunc(allocator: Allocator): MaxHeapAllocator {
        let mha = MaxHeapAllocator()
        mha.arrayList = ArrayList<Byte>()
        return mha
    }

    /// 检查给定分配器是否为本类型实例
    /// 对应 Zig: pub fn isInstance(allocator: std.mem.Allocator) bool
    public static func isInstance(allocator: Allocator): Bool {
        return allocator.getBackend() == AllocatorBackend.maxHeap
    }
}

/// 最大对齐常量
private let MAX_ALIGN_T: Int64 = 16
