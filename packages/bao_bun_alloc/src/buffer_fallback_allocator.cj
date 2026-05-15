// 严格翻译自: src/bun_alloc/BufferFallbackAllocator.zig
// buffer_fallback_allocator.cj - 缓冲区回退分配器
// 先从提供的缓冲区分配，缓冲区耗尽后回退到另一个分配器

package bao_bun_alloc

import bao_core.*

// ============================================================================
// BufferFallbackAllocator - 缓冲区回退分配器
// 对应 Zig: const BufferFallbackAllocator = @This()
// 与 std.heap.StackFallbackAllocator 不同，不拥有缓冲区
// ============================================================================

/// 缓冲区回退分配器
/// 先尝试从固定缓冲区分配，耗尽后回退到后备分配器
///
/// 对应 Zig:
/// const BufferFallbackAllocator = @This();
/// #fallback_allocator: Allocator,
/// #fixed_buffer_allocator: FixedBufferAllocator,
public class BufferFallbackAllocator {

    /// 回退分配器
    /// 对应 Zig: #fallback_allocator: Allocator
    private var fallbackAllocator: Allocator

    /// 固定缓冲区分配器
    /// 对应 Zig: #fixed_buffer_allocator: FixedBufferAllocator
    private var fixedBufferAllocator: FixedBufferAllocator

    /// 初始化
    /// 对应 Zig: pub fn init(buffer: []u8, fallback_allocator: Allocator) BufferFallbackAllocator
    public init(buffer: Array<Byte>, fallbackAllocator: Allocator) {
        this.fallbackAllocator = fallbackAllocator
        this.fixedBufferAllocator = FixedBufferAllocator.init(buffer)
    }

    /// 获取分配器接口
    /// 对应 Zig: pub fn allocator(self: *BufferFallbackAllocator) Allocator
    public func allocator(): Allocator {
        return Allocator.fromContext(
            CPointer<Byte>.fromObject(this),
            BufferFallbackVTable.get()
        )
    }

    /// 分配内存
    /// 对应 Zig: fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8
    public func alloc(len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        // 先尝试从固定缓冲区分配
        let fixedResult = this.fixedBufferAllocator.alloc(len, alignment, retAddr)
        if (fixedResult != None) {
            return fixedResult
        }
        // 回退到后备分配器
        return this.fallbackAllocator.rawAlloc(len, alignment, retAddr)
    }

    /// 调整大小
    /// 对应 Zig: fn resize(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) bool
    public func resize(buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        if (this.fixedBufferAllocator.ownsPtr(CPointer<Byte>.fromArray(buf))) {
            return this.fixedBufferAllocator.resize(buf, alignment, newLen, retAddr)
        }
        return this.fallbackAllocator.rawResize(buf, alignment, newLen, retAddr)
    }

    /// 重映射
    /// 对应 Zig: fn remap(ctx: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ra: usize) ?[*]u8
    public func remap(memory: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): ?Array<Byte> {
        if (this.fixedBufferAllocator.ownsPtr(CPointer<Byte>.fromArray(memory))) {
            return this.fixedBufferAllocator.remap(memory, alignment, newLen, retAddr)
        }
        return this.fallbackAllocator.rawRemap(memory, alignment, newLen, retAddr)
    }

    /// 释放内存
    /// 对应 Zig: fn free(ctx: *anyopaque, buf: []u8, alignment: std.mem.Alignment, ra: usize) void
    public func free(buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        if (this.fixedBufferAllocator.ownsPtr(CPointer<Byte>.fromArray(buf))) {
            this.fixedBufferAllocator.free(buf, alignment, retAddr)
            return
        }
        this.fallbackAllocator.rawFree(buf, alignment, retAddr)
    }

    /// 重置分配器 (重置固定缓冲区)
    /// 对应 Zig: pub fn reset(self: *BufferFallbackAllocator) void
    public func reset(): Unit {
        this.fixedBufferAllocator.reset()
    }
}

// ============================================================================
// BufferFallbackVTable - 缓冲区回退分配器虚表
// ============================================================================

/// 缓冲区回退分配器虚表
public class BufferFallbackVTable {
    private static let instance: BufferFallbackVTable = BufferFallbackVTable()

    public static func get(): BufferFallbackVTable {
        return instance
    }

    /// 虚表分配
    public static func vtableAlloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        let self: BufferFallbackAllocator = BufferFallbackAllocator.fromPointer(ctx)
        return self.alloc(len, alignment, retAddr)
    }

    /// 虚表 resize
    public static func vtableResize(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        let self: BufferFallbackAllocator = BufferFallbackAllocator.fromPointer(ctx)
        return self.resize(buf, alignment, newLen, retAddr)
    }

    /// 虚表 remap
    public static func vtableRemap(ctx: CPointer<Byte>, memory: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): ?Array<Byte> {
        let self: BufferFallbackAllocator = BufferFallbackAllocator.fromPointer(ctx)
        return self.remap(memory, alignment, newLen, retAddr)
    }

    /// 虚表 free
    public static func vtableFree(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        let self: BufferFallbackAllocator = BufferFallbackAllocator.fromPointer(ctx)
        self.free(buf, alignment, retAddr)
    }
}

// ============================================================================
// FixedBufferAllocator - 固定缓冲区分配器
// 对应 Zig: std.heap.FixedBufferAllocator
// ============================================================================

/// 固定缓冲区分配器
/// 从预分配的缓冲区中进行分配
public class FixedBufferAllocator {
    /// 缓冲区
    private var buffer: Array<Byte>
    /// 当前偏移
    private var offset: Int64 = 0

    /// 初始化
    public init(buffer: Array<Byte>) {
        this.buffer = buffer
        this.offset = 0
    }

    /// 分配
    public func alloc(len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        let alignBytes = alignment.toByteUnits()
        let alignedOffset = Int64.alignForward(this.offset, Int64(alignBytes))
        let endOffset = alignedOffset + Int64(len)
        if (endOffset > this.buffer.size) {
            return None
        }
        this.offset = endOffset
        return this.buffer.slice(alignedOffset, Int64(len))
    }

    /// resize
    public func resize(buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        // 固定缓冲区分配器: 只允许缩小
        if (UInt64(buf.size) >= newLen) {
            return true
        }
        return false
    }

    /// remap (不支持)
    public func remap(memory: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): ?Array<Byte> {
        return None
    }

    /// 释放 (空操作，固定缓冲区不支持单独释放)
    public func free(buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        // 固定缓冲区分配器不支持单独释放
    }

    /// 检查指针是否属于此缓冲区
    public func ownsPtr(ptr: CPointer<Byte>): Bool {
        let bufStart = CPointer<Byte>.fromArray(this.buffer)
        let bufEnd = bufStart + Int64(this.buffer.size)
        return ptr >= bufStart && ptr < bufEnd
    }

    /// 重置
    public func reset(): Unit {
        this.offset = 0
    }
}
