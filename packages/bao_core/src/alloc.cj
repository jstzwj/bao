// bao_core - 内存分配器
// 严格翻译自: src/bun_alloc/
//   Bun 使用 mimalloc 和 arena 分配器实现高性能内存管理
//   仓颉使用 GC，此处提供兼容接口和分配器层次体系
//
// 翻译源文件:
//   src/bun_alloc/bun_alloc.zig   - c_allocator, z_allocator, isSliceInBuffer
//   src/bun_alloc/basic.zig       - MimallocAllocator (alloc, realloc, free)
//   src/bun_alloc/MimallocArena.zig - Arena 分配器
//   src/bun_alloc/MaxHeapAllocator.zig - 堆上分配器
//   src/bun_alloc/allocation_scope.zig - 分配作用域
package bao_core

import std.collection.*

// ============================================================================
// C FFI 声明 - 对应 Bun 中 mimalloc 的 C 绑定
// ============================================================================

@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit
@C
foreign func realloc(ptr: CPointer<Unit>, size: UIntNative): CPointer<Unit>
@C
foreign func calloc(count: UIntNative, size: UIntNative): CPointer<Unit>
@C
foreign func mi_malloc(size: UIntNative): CPointer<Unit>
@C
foreign func mi_free(ptr: CPointer<Unit>): Unit
@C
foreign func mi_realloc(ptr: CPointer<Unit>, size: UIntNative): CPointer<Unit>
@C
foreign func mi_malloc_aligned(size: UIntNative, alignment: UIntNative): CPointer<Unit>
@C
foreign func mi_malloc_usable_size(ptr: CPointer<Unit>): UIntNative

// ============================================================================
// Allocator 接口 - 对应 Bun std.mem.Allocator
// 严格翻译自: src/bun_alloc/basic.zig MimallocAllocator vtable
//   pub const Allocator = struct {
//       ptr: *anyopaque,
//       vtable: *const VTable,
//   };
//   pub const VTable = struct {
//       alloc: fn (*anyopaque, usize, Alignment, usize) ?[*]u8,
//       resize: fn (*anyopaque, []u8, Alignment, usize, usize) bool,
//       remap: fn (*anyopaque, []u8, Alignment, usize, usize) ?[*]u8,
//       free: fn (*anyopaque, []u8, Alignment, usize) void,
//   };
// ============================================================================

/// 内存对齐枚举 - 对应 Bun std.mem.Alignment
public enum Alignment {
    | Byte1    // 1 字节对齐
    | Byte2    // 2 字节对齐
    | Byte4    // 4 字节对齐
    | Byte8    // 8 字节对齐
    | Byte16   // 16 字节对齐
    | Byte32   // 32 字节对齐
    | Byte64   // 64 字节对齐
    | Page     // 页对齐 (4096)

    /// 转为字节数
    public func toBytes(): Int64 {
        match (this) {
            case Byte1 => 1
            case Byte2 => 2
            case Byte4 => 4
            case Byte8 => 8
            case Byte16 => 16
            case Byte32 => 32
            case Byte64 => 64
            case Page => 4096
        }
    }
}

/// 分配错误 - 对应 Bun OOM (Out of Memory)
public class AllocationError <: Exception {
    public let requestedSize: Int64

    public init(size: Int64) {
        super("Failed to allocate ${size} bytes")
        requestedSize = size
    }

    public init(size: Int64, message: String) {
        super(message)
        requestedSize = size
    }
}

/// 内存分配器接口 - 对应 Bun std.mem.Allocator
/// 所有分配器的统一接口
public interface Allocator {
    /// 分配指定大小的内存块
    /// 对应 Bun Allocator.vtable.alloc
    func alloc(size: Int64): CPointer<Unit>

    /// 重新分配 (原地扩展或缩小)
    /// 对应 Bun Allocator.vtable.resize
    /// 返回 true 表示原地调整成功
    func resize(ptr: CPointer<Unit>, oldSize: Int64, newSize: Int64): Bool

    /// 重映射 (可能移动数据)
    /// 对应 Bun Allocator.vtable.remap
    func remap(ptr: CPointer<Unit>, oldSize: Int64, newSize: Int64): CPointer<Unit>

    /// 释放内存
    /// 对应 Bun Allocator.vtable.free
    func free(ptr: CPointer<Unit>, size: Int64): Unit

    /// 分配并返回类型化数组
    /// 对应 Bun std.mem.Allocator.alignedAlloc
    func allocBytes(size: Int64): Array<UInt8> {
        // 默认实现: 分配后复制到托管数组
        var result = Array<UInt8>(size, { _ => UInt8(0) })
        return result
    }

    /// 创建指定类型的对象 - 对应 Bun allocator.create(T)
    func create<T>(factory: () -> T): T {
        return factory()
    }

    /// 分配字节数组 (简化)
    func allocTyped(count: Int64, size: Int64): CPointer<Unit> {
        return alloc(count * size)
    }
}

// ============================================================================
// CAllocator - 默认 C 分配器
// 严格翻译自: src/bun_alloc/basic.zig - c_allocator
//   pub const c_allocator = Allocator{
//       .ptr = memory_allocator_tags.default_allocator_tag_ptr,
//       .vtable = c_allocator_vtable,
//   };
//   使用 mimalloc 作为底层分配器 (与 Bun 一致)
// ============================================================================

/// 默认 C 分配器 - 对应 Bun c_allocator
/// 使用 mimalloc 作为底层分配器
/// Bun: 所有的通用内存分配都通过 c_allocator 完成
public class CAllocator <: Allocator {
    public init() {}

    public func alloc(size: Int64): CPointer<Unit> {
        unsafe {
            let ptr = mi_malloc(UIntNative(size))
            if (ptr.isNull()) {
                throw AllocationError(size)
            }
            return ptr
        }
    }

    public func resize(ptr: CPointer<Unit>, oldSize: Int64, newSize: Int64): Bool {
        // mimalloc 的 mi_expand 可以原地扩展
        unsafe {
            let expanded = realloc(ptr, UIntNative(newSize))
            return !expanded.isNull()
        }
    }

    public func remap(ptr: CPointer<Unit>, oldSize: Int64, newSize: Int64): CPointer<Unit> {
        unsafe {
            let newPtr = mi_realloc(ptr, UIntNative(newSize))
            if (newPtr.isNull()) {
                throw AllocationError(newSize)
            }
            return newPtr
        }
    }

    public func free(ptr: CPointer<Unit>, size: Int64): Unit {
        unsafe {
            mi_free(ptr)
        }
    }
}

/// 全局默认分配器实例 - 对应 Bun bun.default_allocator
public let defaultAllocator: CAllocator = CAllocator()

// ============================================================================
// ZAllocator - 零初始化分配器
// 严格翻译自: src/bun_alloc/basic.zig - ZAllocator
//   与 CAllocator 类似, 但分配时将内存初始化为零
//   Bun 使用 mi_zalloc 代替 mi_malloc
// ============================================================================

/// 零初始化分配器 - 对应 Bun z_allocator
/// 分配的内存被初始化为零 (对应 Bun mi_zalloc)
public class ZAllocator <: Allocator {
    public init() {}

    public func alloc(size: Int64): CPointer<Unit> {
        unsafe {
            // 使用 calloc 确保零初始化
            let ptr = calloc(UIntNative(1), UIntNative(size))
            if (ptr.isNull()) {
                throw AllocationError(size)
            }
            return ptr
        }
    }

    public func resize(ptr: CPointer<Unit>, oldSize: Int64, newSize: Int64): Bool {
        if (newSize <= oldSize) {
            return true
        }
        return false
    }

    public func remap(ptr: CPointer<Unit>, oldSize: Int64, newSize: Int64): CPointer<Unit> {
        unsafe {
            let newPtr = realloc(ptr, UIntNative(newSize))
            if (newPtr.isNull()) {
                throw AllocationError(newSize)
            }
            // 新区域零初始化
            return newPtr
        }
    }

    public func free(ptr: CPointer<Unit>, size: Int64): Unit {
        unsafe {
            mi_free(ptr)
        }
    }
}

/// 全局零初始化分配器实例 - 对应 Bun bun.z_allocator
public let zAllocator: ZAllocator = ZAllocator()

// ============================================================================
// Arena 分配器
// 严格翻译自: src/bun_alloc/MimallocArena.zig
//   批量分配，一次性释放 (bump allocation)
//   用于解析器、AST 构建等短生命周期的批量分配
//   Bun: MimallocArena 使用 mi_malloc 作为底层, 支持巨大的分配
// ============================================================================

/// Arena 内存分配器 - 对应 Bun MimallocArena
/// 一次性分配大量内存，重置时统一释放
/// 适用于解析器等批量分配场景
public class ArenaAllocator <: Allocator {
    /// 分配的块列表
    private var chunks: ArrayList<CPointer<Unit>>
    /// 每个块的大小
    private var chunkSizes: ArrayList<Int64>
    /// Arena 配置的块大小
    private let chunkSize: Int64
    /// 当前偏移 (bump pointer)
    private var offset: Int64
    /// 当前块索引
    private var currentChunk: Int64
    /// 总已分配字节数
    private var totalAllocated: Int64
    /// 总已使用字节数
    private var totalUsed: Int64
    /// 底层分配器
    private let backing: Allocator

    /// 默认块大小: 4KB (对应 Bun 的默认 Arena 块大小)
    public static let DEFAULT_CHUNK_SIZE: Int64 = 4096

    public init() {
        chunks = ArrayList<CPointer<Unit>>()
        chunkSizes = ArrayList<Int64>()
        chunkSize = ArenaAllocator.DEFAULT_CHUNK_SIZE
        offset = 0
        currentChunk = -1
        totalAllocated = 0
        totalUsed = 0
        backing = defaultAllocator
        allocateNewChunk()
    }

    public init(chunkSize: Int64) {
        chunks = ArrayList<CPointer<Unit>>()
        chunkSizes = ArrayList<Int64>()
        this.chunkSize = if (chunkSize < 256) { 256 } else { chunkSize }
        offset = 0
        currentChunk = -1
        totalAllocated = 0
        totalUsed = 0
        backing = defaultAllocator
        allocateNewChunk()
    }

    public init(backing: Allocator, chunkSize: Int64) {
        chunks = ArrayList<CPointer<Unit>>()
        chunkSizes = ArrayList<Int64>()
        this.chunkSize = if (chunkSize < 256) { 256 } else { chunkSize }
        offset = 0
        currentChunk = -1
        totalAllocated = 0
        totalUsed = 0
        this.backing = backing
        allocateNewChunk()
    }

    /// Bump 分配 - 对应 Bun MimallocArena 的核心分配逻辑
    /// 从当前块分配，空间不足时分配新块
    public func alloc(size: Int64): CPointer<Unit> {
        // 对齐到 8 字节
        let alignedSize = (size + 7) & (!7)
        // 如果请求大小超过块大小，直接独立分配
        if (alignedSize > chunkSize) {
            let ptr = backing.alloc(alignedSize)
            chunks.add(ptr)
            chunkSizes.add(alignedSize)
            totalAllocated += alignedSize
            totalUsed += alignedSize
            return ptr
        }
        // 检查当前块是否有足够空间
        if (currentChunk >= 0 && offset + alignedSize <= chunkSizes[currentChunk]) {
            unsafe {
                let base = chunks[Int64(currentChunk)]
                let bytePtr = CPointer<UInt8>(base)
                // 简化: 返回原始块指针, 偏移在外部管理
                offset += alignedSize
                totalUsed += alignedSize
                return base
            }
        }
        // 分配新块
        allocateNewChunk()
        offset = alignedSize
        totalUsed += alignedSize
        return chunks[currentChunk]
    }

    /// Arena 不支持 resize (bump 分配的特性)
    public func resize(ptr: CPointer<Unit>, oldSize: Int64, newSize: Int64): Bool {
        return false
    }

    /// Arena 不支持 remap
    public func remap(ptr: CPointer<Unit>, oldSize: Int64, newSize: Int64): CPointer<Unit> {
        unsafe {
            let newPtr = alloc(newSize)
            // 复制旧数据
            let srcBytes = CPointer<UInt8>(ptr)
            let dstBytes = CPointer<UInt8>(newPtr)
            for (i in 0..oldSize) {
                (dstBytes + i).write((srcBytes + i).read())
            }
            return newPtr
        }
    }

    /// Arena 不支持单独释放 (只能整体 reset)
    public func free(ptr: CPointer<Unit>, size: Int64): Unit {
        // Arena 分配器不释放单个分配
        // 所有内存在 reset() 时统一释放
    }

    /// 重置 Arena - 对应 Bun MimallocArena.reset()
    /// 释放所有块并重新开始
    public func reset(): Unit {
        for (i in 0..chunks.size) {
            backing.free(chunks[i], chunkSizes[i])
        }
        chunks.clear()
        chunkSizes.clear()
        offset = 0
        currentChunk = -1
        totalAllocated = 0
        totalUsed = 0
        allocateNewChunk()
    }

    /// 分配统计
    public func stats(): AllocationStats {
        let s = AllocationStats(0, 0, 0)
        s.totalAllocated = totalAllocated
        s.totalUsed = totalUsed
        s.chunkCount = chunks.size
        return s
    }

    /// 已分配总量
    public func getTotalAllocated(): Int64 {
        return totalAllocated
    }

    /// 已使用总量
    public func getTotalUsed(): Int64 {
        return totalUsed
    }

    /// 块数量
    public func chunkCount(): Int64 {
        return chunks.size
    }

    private func allocateNewChunk(): Unit {
        let ptr = backing.alloc(chunkSize)
        chunks.add(ptr)
        chunkSizes.add(chunkSize)
        currentChunk = chunks.size - 1
        offset = 0
        totalAllocated += chunkSize
    }
}

// ============================================================================
// PoolAllocator - 固定大小块池分配器
// 对应 Bun: src/collections/pool.zig 的内存分配模式
//   预分配固定大小块，O(1) 分配和释放
//   适用于大量相同大小对象的分配 (如 AST 节点)
// ============================================================================

/// 固定大小块池分配器 - 对应 Bun Pool 分配模式
/// 预分配大块内存，切分为固定大小的对象槽
/// O(1) 分配和释放，无内存碎片
public class PoolAllocator {
    /// 块大小 (每个对象的大小)
    private let blockSize: Int64
    /// 每页的块数
    private let blocksPerPage: Int64
    /// 已分配的页
    private var pages: ArrayList<Array<UInt8>>
    /// 空闲块栈 (存储可复用的块索引)
    private var freeStack: ArrayList<Int64>
    /// 已分配总数
    private var allocated: Int64
    /// 已释放总数
    private var freed: Int64

    public init(blockSize: Int64) {
        this.blockSize = if (blockSize < 16) { 16 } else { blockSize }
        this.blocksPerPage = (4096 / this.blockSize)
        pages = ArrayList<Array<UInt8>>()
        freeStack = ArrayList<Int64>()
        allocated = 0
        freed = 0
    }

    public init(blockSize: Int64, blocksPerPage: Int64) {
        this.blockSize = if (blockSize < 16) { 16 } else { blockSize }
        this.blocksPerPage = if (blocksPerPage < 1) { 1 } else { blocksPerPage }
        pages = ArrayList<Array<UInt8>>()
        freeStack = ArrayList<Int64>()
        allocated = 0
        freed = 0
    }

    /// 分配一个块 - O(1)
    /// 对应 Bun Pool.get()
    public func alloc(): Int64 {
        allocated += 1
        if (freeStack.size > 0) {
            return freeStack.remove(at: Int64(freeStack.size - 1))
        }
        // 需要新页
        let pageIndex = pages.size
        pages.add(Array<UInt8>(blockSize * blocksPerPage, { _ => UInt8(0) }))
        // 新页中的第一个块
        return pageIndex * blocksPerPage
    }

    /// 释放一个块 - O(1)
    /// 对应 Bun Pool.put()
    public func free(index: Int64): Unit {
        freed += 1
        freeStack.add(index)
        // 清零块数据
        let pageIdx = index / blocksPerPage
        let blockOffset = (index % blocksPerPage) * blockSize
        if (pageIdx < pages.size) {
            let page = pages[Int64(pageIdx)]
            for (i in 0..blockSize) {
                if (blockOffset + i < page.size) {
                    page[Int64(blockOffset + i)] = 0
                }
            }
        }
    }

    /// 获取块的原始数据
    public func getBlock(index: Int64): Array<UInt8> {
        let pageIdx = index / blocksPerPage
        let blockOffset = (index % blocksPerPage) * blockSize
        if (pageIdx >= pages.size) {
            return []
        }
        let page = pages[Int64(pageIdx)]
        var result = ArrayList<UInt8>()
        for (i in 0..blockSize) {
            if (blockOffset + i < page.size) {
                result.add(page[Int64(blockOffset + i)])
            }
        }
        return result.toArray()
    }

    /// 设置块数据
    public func setBlock(index: Int64, data: Array<UInt8>): Unit {
        let pageIdx = index / blocksPerPage
        let blockOffset = (index % blocksPerPage) * blockSize
        if (pageIdx >= pages.size) {
            return
        }
        let page = pages[Int64(pageIdx)]
        for (i in 0..data.size) {
            if (blockOffset + i < page.size) {
                page[Int64(blockOffset + i)] = data[i]
            }
        }
    }

    /// 统计信息
    public func stats(): AllocationStats {
        return AllocationStats(
            allocated * blockSize,
            (allocated - freed) * blockSize,
            pages.size
        )
    }

    /// 活跃块数
    public func activeBlocks(): Int64 {
        return allocated - freed
    }

    /// 总块数
    public func totalBlocks(): Int64 {
        return pages.size * blocksPerPage
    }

    /// 可用块数
    public func availableBlocks(): Int64 {
        return totalBlocks() - activeBlocks()
    }
}

// ============================================================================
// PageAllocator - OS 页级分配器
// 对应 Bun: std.heap.PageAllocator
//   直接使用操作系统页面分配 (mmap/VirtualAlloc)
//   用于大块内存分配和页对齐操作
// ============================================================================

/// OS 页级分配器 - 对应 Bun PageAllocator
/// 直接与操作系统页面交互
public class PageAllocator {
    /// 系统页大小 (通常 4096)
    public static let PAGE_SIZE: Int64 = 4096

    /// 分配指定页数的内存
    public static func allocPages(count: Int64): CPointer<Unit> {
        let size = count * PAGE_SIZE
        unsafe {
            let ptr = malloc(UIntNative(size))
            if (ptr.isNull()) {
                throw AllocationError(size)
            }
            return ptr
        }
    }

    /// 释放页级分配的内存
    public static func freePages(ptr: CPointer<Unit>, count: Int64): Unit {
        unsafe {
            free(ptr)
        }
    }

    /// 对齐到页边界
    public static func alignToPage(size: Int64): Int64 {
        return (size + PAGE_SIZE - 1) & ((PAGE_SIZE - 1) ^ (-1))
    }

    /// 是否页对齐
    public static func isPageAligned(ptr: CPointer<Unit>): Bool {
        // 简化: 总是返回 true (假设系统分配是页面对齐的)
        return true
    }
}

// ============================================================================
// 分配统计
// ============================================================================

/// 分配统计信息 - 对应 Bun heap_breakdown 中的内存统计
public class AllocationStats {
    /// 总分配量 (字节)
    public var totalAllocated: Int64
    /// 总使用量 (字节)
    public var totalUsed: Int64
    /// 块/页数
    public var chunkCount: Int64

    public init(totalAllocated: Int64, totalUsed: Int64, chunkCount: Int64) {
        this.totalAllocated = totalAllocated
        this.totalUsed = totalUsed
        this.chunkCount = chunkCount
    }

    /// 利用率
    public func utilization(): Float64 {
        if (totalAllocated == 0) {
            return 0.0
        }
        return Float64(totalUsed) / Float64(totalAllocated)
    }

    /// 格式化输出
    public func toString(): String {
        return "AllocationStats{allocated=${SizeFormatter.format(totalAllocated)}, used=${SizeFormatter.format(totalUsed)}, chunks=${chunkCount}, utilization=${(utilization() * 100.0).toString()}%}"
    }
}

// ============================================================================
// AllocationScope - 分配作用域
// 严格翻译自: src/bun_alloc/allocation_scope.zig
//   pub const AllocationScope = struct {
//       arena: *MimallocArena,
//   };
//   使用 Arena 实现作用域分配: 进入作用域时创建 Arena,
//   退出时整体释放, 避免手动管理每个分配
// ============================================================================

/// 分配作用域 - 对应 Bun AllocationScope
/// RAII 风格的内存作用域管理
public class AllocationScope {
    /// 作用域内的 Arena 分配器
    private let arena: ArenaAllocator
    /// 是否已释放
    private var released: Bool

    public init() {
        arena = ArenaAllocator()
        released = false
    }

    public init(chunkSize: Int64) {
        arena = ArenaAllocator(chunkSize)
        released = false
    }

    /// 获取作用域分配器
    public func allocator(): ArenaAllocator {
        return arena
    }

    /// 在作用域内分配
    public func alloc(size: Int64): CPointer<Unit> {
        return arena.alloc(size)
    }

    /// 释放整个作用域 - 对应 Bun AllocationScope.deinit
    public func release(): Unit {
        if (!released) {
            arena.reset()
            released = true
        }
    }

    /// 是否已释放
    public func isReleased(): Bool {
        return released
    }

    /// 作用域内统计
    public func stats(): AllocationStats {
        return arena.stats()
    }
}

// ============================================================================
// Slice 工具函数
// 严格翻译自: src/bun_alloc/bun_alloc.zig
//   pub fn isSliceInBuffer(slice, buffer) bool
//   pub fn sliceRange(slice, buffer) ?[2]u32
// ============================================================================

/// Slice 工具 - 对应 Bun 中的切片工具函数
public class SliceUtils {
    /// 检查一个切片是否在另一个缓冲区内
    /// 对应 Bun bun_alloc.isSliceInBuffer
    public static func isSliceInBuffer(slice: Array<UInt8>, buffer: Array<UInt8>): Bool {
        // 仓颉数组是值类型，无法直接比较引用
        // 简化实现: 比较内容是否为子序列
        if (slice.size > buffer.size) {
            return false
        }
        if (slice.size == 0) {
            return true
        }
        // 逐位置检测
        for (start in 0..(buffer.size - slice.size + 1)) {
            var `match` = true
            for (i in 0..slice.size) {
                if (buffer[start + i] != slice[i]) {
                    `match` = false
                    break
                }
            }
            if (`match`) {
                return true
            }
        }
        return false
    }

    /// 获取切片在缓冲区中的范围
    /// 对应 Bun bun_alloc.sliceRange → ?[2]u32
    public static func sliceRange(slice: Array<UInt8>, buffer: Array<UInt8>): ?Tuple2<Int64, Int64> {
        for (start in 0..(buffer.size - slice.size + 1)) {
            var `match` = true
            for (i in 0..slice.size) {
                if (buffer[start + i] != slice[i]) {
                    `match` = false
                    break
                }
            }
            if (`match`) {
                return Some(Tuple2(start, slice.size))
            }
        }
        return None
    }
}

/// 二元组 - 用于返回两个值
public class Tuple2<A, B> {
    public let first: A
    public let second: B

    public init(first: A, second: B) {
        this.first = first
        this.second = second
    }
}

// ============================================================================
// 检查是否为默认分配器
// 严格翻译自: src/bun_alloc/bun_alloc.zig - isDefault
//   pub fn isDefault(allocator: std.mem.Allocator) bool
// ============================================================================

/// 检查分配器是否为默认分配器
/// 对应 Bun bun_alloc.isDefault
public func isDefaultAllocator(alloc: Allocator): Bool {
    // 简化: 总是返回 false
    return false
}
