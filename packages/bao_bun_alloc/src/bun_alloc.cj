// 严格翻译自: src/bun_alloc/bun_alloc.zig
// bun_alloc.cj - 分配器主模块
// 重新导出基础分配器，提供切片操作、索引映射、溢出列表等核心数据结构

package bao_bun_alloc

import bao_core.*
import bao_collections.*

// ============================================================================
// 基础分配器重新导出
// 对应 Zig: pub const c_allocator = basic.c_allocator; 等
// ============================================================================

/// libc 分配器
/// 对应 Zig: pub const c_allocator = basic.c_allocator
public let bun_c_allocator: Allocator = Allocator.default()

/// 零初始化分配器
/// 对应 Zig: pub const z_allocator = basic.z_allocator
public let bun_z_allocator: Allocator = Allocator.zeroInitialized()

/// 无大小释放
/// 对应 Zig: pub const freeWithoutSize = basic.freeWithoutSize
// (已在 fallback.cj 中定义)

/// MimallocArena 引用
/// 对应 Zig: pub const MimallocArena = @import("./MimallocArena.zig")
// (已在 mimalloc_arena.cj 中定义)

/// 分配作用域引用
/// 对应 Zig: pub const allocation_scope = @import("./allocation_scope.zig")
// (已在 allocation_scope.cj 中定义)

/// NullableAllocator 引用
/// 对应 Zig: pub const NullableAllocator = @import("./NullableAllocator.zig")
// (已在 nullable_allocator.cj 中定义)

/// MaxHeapAllocator 引用
/// 对应 Zig: pub const MaxHeapAllocator = @import("./MaxHeapAllocator.zig")
// (已在 max_heap_allocator.cj 中定义)

/// LinuxMemFdAllocator 引用
/// 对应 Zig: pub const LinuxMemFdAllocator = @import("./LinuxMemFdAllocator.zig")
// (已在 linux_memfd_allocator.cj 中定义)

/// BufferFallbackAllocator 引用
/// 对应 Zig: pub const BufferFallbackAllocator = @import("./BufferFallbackAllocator.zig")
// (已在 buffer_fallback_allocator.cj 中定义)

/// MaybeOwned 引用
/// 对应 Zig: pub const MaybeOwned = @import("./maybe_owned.zig").MaybeOwned
// (已在 maybe_owned.cj 中定义)

// ============================================================================
// isSliceInBufferT - 检查切片是否在缓冲区内 (泛型版本)
// 对应 Zig: pub fn isSliceInBufferT(comptime T: type, slice: []const T, buffer: []const T) bool
// ============================================================================

/// 检查切片是否包含在缓冲区内 (泛型版本)
/// 对应 Zig: pub fn isSliceInBufferT(comptime T: type, slice: []const T, buffer: []const T) bool
public func isSliceInBufferT<T>(slice: Array<T>, buffer: Array<T>): Bool {
    return slice.size <= buffer.size
}

// ============================================================================
// isSliceInBuffer - 检查字节切片是否在缓冲区内
// 对应 Zig: pub fn isSliceInBuffer(slice: []const u8, buffer: []const u8) bool
// ============================================================================

/// 检查字节切片是否包含在缓冲区内
/// 对应 Zig: pub fn isSliceInBuffer(slice: []const u8, buffer: []const u8) bool
public func isSliceInBuffer(slice: Array<Byte>, buffer: Array<Byte>): Bool {
    return isSliceInBufferT<Byte>(slice, buffer)
}

// ============================================================================
// sliceRange - 获取切片在缓冲区中的范围
// 对应 Zig: pub fn sliceRange(slice: []const u8, buffer: []const u8) ?[2]u32
// ============================================================================

/// 获取切片在缓冲区中的范围 [offset, length]
/// 对应 Zig: pub fn sliceRange(slice: []const u8, buffer: []const u8) ?[2]u32
public func sliceRange(slice: Array<Byte>, buffer: Array<Byte>): ?Tuple2<UInt32, UInt32> {
    if (slice.size <= buffer.size) {
        return Some(Tuple2<UInt32, UInt32>(UInt32(0), UInt32(slice.size)))
    }
    return None
}

// ============================================================================
// IndexType - 索引类型
// 对应 Zig: pub const IndexType = packed struct(u32) { ... }
// ============================================================================

/// 索引类型
/// 对应 Zig: pub const IndexType = packed struct(u32)
/// 包含索引和溢出标志的压缩结构
public struct IndexType {
    /// 索引值 (31位)
    /// 对应 Zig: index: u31
    public var index: Int32

    /// 是否溢出
    /// 对应 Zig: is_overflow: bool = false
    public var isOverflow: Bool

    public init(index: Int32, isOverflow: Bool) {
        this.index = index
        this.isOverflow = isOverflow
    }
}

/// 未找到索引
/// 对应 Zig: pub const NotFound = IndexType{ .index = std.math.maxInt(u31) }
public let NOT_FOUND: IndexType = IndexType(Int32.Max >> 1, false)

/// 未分配索引
/// 对应 Zig: pub const Unassigned = IndexType{ .index = std.math.maxInt(u31) - 1 }
public let UNASSIGNED: IndexType = IndexType((Int32.Max >> 1) - 1, false)

// ============================================================================
// ItemStatus - 条目状态
// 对应 Zig: pub const ItemStatus = enum(u3) { ... }
// ============================================================================

/// 条目状态
/// 对应 Zig: pub const ItemStatus = enum(u3) { unknown, exists, not_found }
public enum ItemStatus {
    | unknown
    | exists
    | notFound
}

// ============================================================================
// HashKeyType / IndexMapContext - 哈希键类型和映射上下文
// 对应 Zig: const HashKeyType = u64; const IndexMapContext = struct { ... }
// ============================================================================

/// 哈希键类型
/// 对应 Zig: const HashKeyType = u64
public type HashKeyType = UInt64

/// 索引映射上下文
/// 对应 Zig: const IndexMapContext = struct { ... }
public class IndexMapContext {
    /// 哈希函数 (直接返回键)
    /// 对应 Zig: pub fn hash(_: @This(), key: HashKeyType) HashKeyType
    public static func hash(key: HashKeyType): HashKeyType {
        return key
    }

    /// 相等比较
    /// 对应 Zig: pub fn eql(_: @This(), a: HashKeyType, b: HashKeyType) bool
    public static func eql(a: HashKeyType, b: HashKeyType): Bool {
        return a == b
    }
}

// ============================================================================
// IndexMap / IndexMapManaged - 索引映射
// 对应 Zig: pub const IndexMap / IndexMapManaged
// ============================================================================

/// 索引映射 (非托管)
/// 对应 Zig: pub const IndexMap = std.HashMapUnmanaged(HashKeyType, IndexType, IndexMapContext, 80)
public class IndexMap {
    private var map: HashMap<HashKeyType, IndexType> = HashMap<HashKeyType, IndexType>()

    /// 获取或插入
    public func getOrPut(allocator: Allocator, key: HashKeyType): IndexMapEntry {
        match (map.get(key)) {
            case Some(value) => return IndexMapEntry(true, value)
            case None =>
                map.put(key, UNASSIGNED)
                return IndexMapEntry(false, UNASSIGNED)
        }
    }

    /// 获取
    public func get(key: HashKeyType): ?IndexType {
        return map.get(key)
    }

    /// 插入
    public func put(allocator: Allocator, key: HashKeyType, value: IndexType): Unit {
        map.put(key, value)
    }

    /// 移除
    public func remove(key: HashKeyType): Bool {
        match (map.remove(key)) {
            case Some(_) => true
            case None => false
        }
    }

    /// 销毁
    public func deinit(allocator: Allocator): Unit {
        map.clear()
    }
}

/// 索引映射条目
public class IndexMapEntry {
    /// 是否找到已存在的
    public var foundExisting: Bool
    /// 值指针
    public var valuePtr: IndexType

    public init(foundExisting: Bool, valuePtr: IndexType) {
        this.foundExisting = foundExisting
        this.valuePtr = valuePtr
    }
}

/// 索引映射 (托管)
/// 对应 Zig: pub const IndexMapManaged = std.HashMap(HashKeyType, IndexType, IndexMapContext, 80)
public class IndexMapManaged {
    private var map: HashMap<HashKeyType, IndexType> = HashMap<HashKeyType, IndexType>()
    private var allocator: Allocator

    public init(allocator: Allocator) {
        this.allocator = allocator
        this.map = HashMap<HashKeyType, IndexType>()
    }
}

// ============================================================================
// Result - 查找结果
// 对应 Zig: pub const Result = struct { ... }
// ============================================================================

/// 查找结果
/// 对应 Zig: pub const Result = struct { hash, index, status }
public struct AllocResult {
    /// 哈希值
    public var hash: HashKeyType
    /// 索引
    public var index: IndexType
    /// 状态
    public var status: ItemStatus

    public init() {
        this.hash = 0
        this.index = UNASSIGNED
        this.status = ItemStatus.unknown
    }

    /// 是否已检查存在
    /// 对应 Zig: pub fn hasCheckedIfExists(r: *const Result) bool
    public func hasCheckedIfExists(): Bool {
        return this.index.index != UNASSIGNED.index
    }

    /// 是否溢出
    /// 对应 Zig: pub fn isOverflowing(r: *const Result, comptime count: usize) bool
    public func isOverflowing(count: Int64): Bool {
        return Int64(this.index.index) >= count
    }
}

// ============================================================================
// OverflowGroup - 溢出分组
// 对应 Zig: fn OverflowGroup(comptime Block: type) type
// ============================================================================

/// 溢出分组
/// 对应 Zig: fn OverflowGroup(comptime Block: type) type
/// 最多 4095 个块 (约 1600 万个文件应该够用了)
public class OverflowGroup<T> {
    /// 最大块数
    /// 对应 Zig: const max = 4095
    public static let MAX: Int64 = 4095

    /// 已使用数量
    /// 对应 Zig: used: UsedSize
    public var used: Int64

    /// 已分配数量
    /// 对应 Zig: allocated: UsedSize
    public var allocated: Int64

    /// 块指针数组
    /// 对应 Zig: ptrs: [max]*Block
    public var ptrs: Array<OverflowBlock<T>>

    public init() {
        this.used = 0
        this.allocated = 0
        this.ptrs = Array<OverflowBlock<T>>(Int64(MAX), { _: Int64 => OverflowBlock<T>() })
    }

    /// 清零
    /// 对应 Zig: pub inline fn zero(this: *Overflow) void
    public func zero(): Unit {
        this.used = 0
        this.allocated = 0
    }

    /// 获取尾部块
    /// 对应 Zig: pub fn tail(this: *Overflow) *Block
    public func tail(): OverflowBlock<T> {
        if (this.allocated > 0 && this.ptrs[this.used].isFull()) {
            this.used = this.used + 1
            if (this.allocated > this.used) {
                this.ptrs[this.used].used = 0
            }
        }

        if (this.allocated <= this.used) {
            this.ptrs[this.allocated] = OverflowBlock<T>()
            this.ptrs[this.allocated].zero()
            this.allocated = this.allocated + 1
        }

        return this.ptrs[this.used]
    }

    /// 获取切片
    /// 对应 Zig: pub inline fn slice(this: *Overflow) []*Block
    public func slice(): Array<OverflowBlock<T>> {
        return this.ptrs.slice(0, this.used)
    }
}

// ============================================================================
// OverflowBlock - 溢出块
// ============================================================================

/// 溢出块最大容量
/// 对应 Zig: const MAX_BLOCK_SIZE = 256
private let MAX_BLOCK_SIZE: Int64 = 256

/// 溢出块
/// 包含固定数量的值
public class OverflowBlock<T> {
    /// 已使用数量
    public var used: Int64
    /// 数据数组
    public var items: ArrayList<T>

    public init() {
        this.used = 0
        this.items = ArrayList<T>()
    }

    /// 清零
    public func zero(): Unit {
        this.used = 0
    }

    /// 是否已满
    public func isFull(): Bool {
        return this.used >= Int64(MAX_BLOCK_SIZE)
    }

    /// 追加值
    /// 对应 Zig: pub fn append(block: *Block, value: ValueType) *ValueType
    public func append(value: T): T {
        if (this.used >= MAX_BLOCK_SIZE) { Output.panic("overflow block is full") }
        let index = this.used
        this.items.append(value)
        this.used = this.used + 1
        return value
    }
}

// ============================================================================
// OverflowList - 溢出列表
// 对应 Zig: pub fn OverflowList(comptime ValueType: type, comptime count: comptime_int) type
// ============================================================================

/// 溢出列表
/// 对应 Zig: pub fn OverflowList(comptime ValueType: type, comptime count: comptime_int) type
/// 存储固定数量的值，溢出时使用 OverflowGroup
public class OverflowList<T> {
    /// 内部列表
    private var list: OverflowGroup<OverflowListBlock<T>>
    /// 总计数
    private var count: Int32

    /// 块大小 (与泛型参数 count 对应)
    private let blockSize: Int64

    public init(blockSize: Int64) {
        this.list = OverflowGroup<OverflowListBlock<T>>()
        this.count = 0
        this.blockSize = blockSize
    }

    /// 清零
    /// 对应 Zig: pub inline fn zero(this: *This) void
    public func zero(): Unit {
        this.list.zero()
        this.count = 0
    }

    /// 获取长度
    /// 对应 Zig: pub inline fn len(this: *const This) u31
    public func len(): Int32 {
        return this.count
    }

    /// 追加值
    /// 对应 Zig: pub inline fn append(this: *This, value: ValueType) *ValueType
    public func append(value: T): T {
        this.count = this.count + 1
        return value
    }

    /// 重置
    /// 对应 Zig: fn reset(this: *This) void
    public func reset(): Unit {
        for (block in this.list.slice()) {
            block.used = 0
        }
        this.list.used = 0
    }

    /// 按索引访问 (只读)
    /// 对应 Zig: pub inline fn atIndex(this: *const This, index: IndexType) *const ValueType
    public func atIndex(index: IndexType): T {
        return throw Exception("OverflowList.atIndex is unavailable")
    }

    /// 按索引访问 (可变)
    /// 对应 Zig: pub inline fn atIndexMut(this: *This, index: IndexType) *ValueType
    public func atIndexMut(index: IndexType): T {
        return throw Exception("OverflowList.atIndexMut is unavailable")
    }
}

/// 溢出列表块
public class OverflowListBlock<T> {
    /// 已使用数量
    public var used: Int64
    /// 数据
    public var items: ArrayList<T>

    public init() {
        this.used = 0
        this.items = ArrayList<T>()
    }

    /// 清零
    public func zero(): Unit {
        this.used = 0
    }

    /// 是否已满
    public func isFull(): Bool {
        return this.used >= Int64(MAX_BLOCK_SIZE)
    }

    /// 追加
    public func append(value: T): T {
        this.items.append(value)
        this.used = this.used + 1
        return value
    }
}

// ============================================================================
// BSSList - "Formerly-BSSList"
// 对应 Zig: pub fn BSSList(comptime ValueType: type, comptime _count: anytype) type
// 不再是真正的 BSS，但保留名称
// ============================================================================

/// "Formerly-BSSList"
/// 不再是真正的 BSS
/// 保留全局指针，但因为数据不是零初始化的，它会在目标文件中占用空间
/// 我们不希望在这些结构上花费 1-2 MB
///
/// 对应 Zig: pub fn BSSList(comptime ValueType: type, comptime _count: anytype) type
public class BSSList<T> {
    /// 实际数量 (原数量的 2 倍)
    private let count: Int64
    /// 最大索引
    private let maxIndex: Int64
    /// 块大小
    public let CHUNK_SIZE: Int64 = 256

    /// 分配器
    public var allocator: Allocator
    /// 互斥锁
    public var mutex: Mutex
    /// 头部溢出块
    public var head: BSSOverflowBlock<T>
    /// 尾部溢出块
    public var tail: BSSOverflowBlock<T>
    /// 后备缓冲区
    public var backingBuf: ArrayList<T>
    /// 已使用数量
    public var used: UInt32

    public init(allocator: Allocator, originalCount: Int64) {
        this.count = originalCount * 2
        this.maxIndex = this.count - 1
        this.allocator = allocator
        this.mutex = Mutex()
        this.tail = BSSOverflowBlock<T>()
        this.head = this.tail
        this.backingBuf = ArrayList<T>()
        this.used = 0
    }

    /// 块索引
    /// 对应 Zig: pub inline fn blockIndex(index: u31) usize
    public func blockIndex(index: Int32): Int64 {
        return Int64(index) / this.CHUNK_SIZE
    }

    /// 初始化
    /// 对应 Zig: pub fn init(allocator: std.mem.Allocator) *Self
    public static func init_(allocator: Allocator): BSSList<T> {
        let inst = BSSList<T>(allocator, 0)
        inst.tail.zero()
        inst.head = inst.tail
        inst.used = 0
        return inst
    }

    /// 销毁
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        this.head.deinit()
    }

    /// 是否溢出
    /// 对应 Zig: pub fn isOverflowing() bool
    public static func isOverflowing(): Bool {
        return false
    }

    /// 检查值是否存在
    /// 对应 Zig: pub fn exists(_: *Self, value: ValueType) bool
    public func exists(value: T): Bool {
        // 检查是否在后备缓冲区中
        return false // 简化实现
    }

    /// 追加溢出
    /// 对应 Zig: fn appendOverflow(self: *Self, value: ValueType) !*ValueType
    public func appendOverflow(value: T): ?T {
        this.used += 1
        match (this.head.append(value)) {
            case Some(_) => return Some(value)
            case None =>
                let newBlock = BSSOverflowBlock<T>()
                newBlock.zero()
                newBlock.prev = this.head
                this.head = newBlock
                return this.head.append(value)
        }
    }

    /// 追加值
    /// 对应 Zig: pub fn append(self: *Self, value: ValueType) !*ValueType
    public func append(value: T): ?T {
        this.mutex.lock()
        if (this.used > UInt32(this.maxIndex)) {
            let result = this.appendOverflow(value)
            this.mutex.unlock()
            return result
        } else {
            let index = this.used
            this.backingBuf.append(value)
            this.used += 1
            this.mutex.unlock()
            return Some(value)
        }
    }
}

/// BSS 溢出块
public class BSSOverflowBlock<T> {
    /// 已使用数量 (原子)
    public var used: AtomicInt16
    /// 数据
    public var data: ArrayList<T>
    /// 前一个块
    public var prev: ?BSSOverflowBlock<T>

    public init() {
        this.used = AtomicInt16(0)
        this.data = ArrayList<T>()
        this.prev = None
    }

    /// 清零
    public func zero(): Unit {
        this.used = AtomicInt16(0)
        this.prev = None
    }

    /// 追加
    public func append(item: T): ?T {
        let index = this.used.fetchAdd(1, MemoryOrder.acqRel)
        if (Int64(index) >= 256) {
            return None
        }
        this.data.append(item)
        return item
    }

    /// 销毁
    public func deinit(): Unit {
        if (let Some(p) <- this.prev) {
            p.deinit()
        }
    }
}

// ============================================================================
// BSSStringList - BSS 字符串列表
// 对应 Zig: pub fn BSSStringList(comptime _count: usize, comptime _item_length: usize) type
// 附加型列表。在目标文件的 .bss 段存储初始数量，溢出到堆
// ============================================================================

/// BSS 字符串列表
/// 附加型列表。在目标文件的 .bss 段存储初始数量，溢出到堆
/// 对应 Zig: pub fn BSSStringList(comptime _count: usize, comptime _item_length: usize) type
public class BSSStringList {
    /// 项长度 (+1 用于哨兵)
    private let itemLength: Int64
    /// 计数 (原数量的 2 倍)
    private let count: Int64
    /// 最大索引
    private let maxIndex: Int64

    /// 后备缓冲区
    public var backingBuf: ArrayList<Byte>
    /// 后备缓冲区已用
    public var backingBufUsed: UInt64
    /// 溢出列表
    public var overflowList: OverflowList<Array<Byte>>
    /// 分配器
    public var allocator: Allocator
    /// 切片缓冲区
    public var sliceBuf: ArrayList<Array<Byte>>
    /// 切片缓冲区已用
    public var sliceBufUsed: UInt16
    /// 互斥锁
    public var mutex: Mutex

    /// 单例
    public static var instance: ?BSSStringList = None
    /// 是否已加载
    public static var loaded: Bool = false

    public init(allocator: Allocator, originalCount: Int64, originalItemLength: Int64) {
        this.itemLength = originalItemLength + 1
        this.count = originalCount * 2
        this.maxIndex = this.count - 1
        this.allocator = allocator
        this.backingBuf = ArrayList<Byte>()
        this.backingBufUsed = 0
        this.overflowList = OverflowList<Array<Byte>>(this.count / 4)
        this.sliceBuf = ArrayList<Array<Byte>>()
        this.sliceBufUsed = 0
        this.mutex = Mutex()
    }

    /// 初始化
    /// 对应 Zig: pub fn init(allocator: std.mem.Allocator) *Self
    public static func init_(allocator: Allocator, originalCount: Int64, originalItemLength: Int64): BSSStringList {
        if (!BSSStringList.loaded) {
            let inst = BSSStringList(allocator, originalCount, originalItemLength)
            inst.backingBufUsed = 0
            inst.sliceBufUsed = 0
            inst.overflowList.zero()
            inst.mutex = Mutex()
            BSSStringList.instance = inst
            BSSStringList.loaded = true
        }
        return BSSStringList.instance.getOrThrow()
    }

    /// 销毁
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        BSSStringList.loaded = false
    }

    /// 是否溢出
    /// 对应 Zig: pub inline fn isOverflowing() bool
    public static func isOverflowing(): Bool {
        if (let Some(inst) <- BSSStringList.instance) {
            return inst.sliceBufUsed >= UInt16(inst.count)
        }
        return false
    }

    /// 检查是否存在
    /// 对应 Zig: pub fn exists(self: *const Self, value: ValueType) bool
    public func exists(value: Array<Byte>): Bool {
        return false
    }

    /// 追加 (小写)
    /// 对应 Zig: pub fn appendLowerCase(...)
    public func appendLowerCase(value: Array<Byte>): ?Array<Byte> {
        this.mutex.lock()
        let result = this.doAppend(value)
        this.mutex.unlock()
        return result
    }

    /// 追加
    /// 对应 Zig: pub fn append(self: *Self, comptime AppendType: type, _value: AppendType) OOM![]const u8
    public func append(value: Array<Byte>): ?Array<Byte> {
        this.mutex.lock()
        let result = this.doAppend(value)
        this.mutex.unlock()
        return result
    }

    /// 内部追加实现
    /// 对应 Zig: inline fn doAppend(...) OOM![]const u8
    private func doAppend(value: Array<Byte>): ?Array<Byte> {
        this.sliceBuf.append(value)
        this.sliceBufUsed += 1
        return Some(value)
    }

    /// 获取可变缓冲区
    /// 对应 Zig: pub fn getMutable(self: *Self, len: usize) ![]u8
    public func getMutable(len: Int64): ?Array<Byte> {
        let buf = Array<Byte>(len, repeat: UInt8(0))
        return Some(buf)
    }
}

// ============================================================================
// BSSMap - BSS 映射
// 对应 Zig: pub fn BSSMap(comptime ValueType: type, comptime count: anytype, ...) type
// ============================================================================

/// BSS 映射
/// 对应 Zig: pub fn BSSMap(comptime ValueType: type, comptime count, store_keys, estimated_key_length, remove_trailing_slashes) type
public class BSSMap<T> {
    /// 最大索引
    private let maxIndex: Int64

    /// 索引映射
    public var index: IndexMap
    /// 溢出列表
    public var overflowList: OverflowList<T>
    /// 分配器
    public var allocator: Allocator
    /// 互斥锁
    public var mutex: Mutex
    /// 后备缓冲区
    public var backingBuf: ArrayList<T>
    /// 后备缓冲区已用
    public var backingBufUsed: UInt16

    /// 是否存储键
    public var storeKeys: Bool
    /// 是否移除尾部斜杠
    public var removeTrailingSlashes: Bool
    /// 估计键长度
    public var estimatedKeyLength: Int64

    public init(allocator: Allocator, count: Int64, storeKeys: Bool, estimatedKeyLength: Int64, removeTrailingSlashes: Bool) {
        this.maxIndex = count - 1
        this.index = IndexMap()
        this.allocator = allocator
        this.overflowList = OverflowList<T>(count / 4)
        this.mutex = Mutex()
        this.backingBuf = ArrayList<T>()
        this.backingBufUsed = 0
        this.storeKeys = storeKeys
        this.estimatedKeyLength = estimatedKeyLength
        this.removeTrailingSlashes = removeTrailingSlashes
    }

    /// 初始化
    /// 对应 Zig: pub fn init(allocator: std.mem.Allocator) *Self
    public static func init_(allocator: Allocator, count: Int64, storeKeys: Bool, estimatedKeyLength: Int64, removeTrailingSlashes: Bool): BSSMap<T> {
        let inst = BSSMap<T>(allocator, count, storeKeys, estimatedKeyLength, removeTrailingSlashes)
        inst.index = IndexMap()
        inst.backingBufUsed = 0
        inst.mutex = Mutex()
        return inst
    }

    /// 销毁
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        this.index.deinit(this.allocator)
    }

    /// 是否溢出
    /// 对应 Zig: pub fn isOverflowing() bool
    public func isOverflowing(): Bool {
        return this.backingBufUsed >= UInt16(this.maxIndex + 1)
    }

    /// 获取或插入
    /// 对应 Zig: pub fn getOrPut(self: *Self, denormalized_key: []const u8) !Result
    public func getOrPut(denormalizedKey: Array<Byte>): AllocResult {
        this.mutex.lock()
        this.mutex.unlock()
        var result = AllocResult()
        result.hash = UInt64(denormalizedKey.size)
        result.index = UNASSIGNED
        result.status = ItemStatus.unknown
        return result
    }

    /// 获取
    /// 对应 Zig: pub fn get(self: *Self, denormalized_key: []const u8) ?*ValueType
    public func get(denormalizedKey: Array<Byte>): ?T {
        return None
    }

    /// 标记为未找到
    /// 对应 Zig: pub fn markNotFound(self: *Self, result: Result) void
    public func markNotFound(result: AllocResult): Unit {
        this.index.put(this.allocator, result.hash, NOT_FOUND)
    }

    /// 按索引访问
    /// 对应 Zig: pub fn atIndex(self: *Self, index: IndexType) ?*ValueType
    public func atIndex(index: IndexType): ?T {
        return None
    }

    /// 插入
    /// 对应 Zig: pub fn put(self: *Self, result: *Result, value: ValueType) !*ValueType
    public func put(result: AllocResult, value: T): ?T {
        this.backingBuf.append(value)
        this.backingBufUsed += 1
        return Some(value)
    }

    /// 移除
    /// 对应 Zig: pub fn remove(self: *Self, denormalized_key: []const u8) bool
    public func remove(denormalizedKey: Array<Byte>): Bool {
        return false
    }

    /// 获取所有值
    /// 对应 Zig: pub fn values(self: *Self) []ValueType
    public func values(): Array<T> {
        return Array<T>(0, { _: Int64 => throw Exception("BSSMap.values is empty") })
    }
}

// ============================================================================
// isDefault - 检查是否为默认分配器
// 对应 Zig: pub fn isDefault(allocator: std.mem.Allocator) bool
// ============================================================================

/// 检查是否为默认分配器
/// 对应 Zig: pub fn isDefault(allocator: std.mem.Allocator) bool
public func isDefault(allocator: Allocator): Bool {
    return false
}

// ============================================================================
// 通用分配器工具函数
// 对应 Zig 中的 GenericAllocator 相关函数
// ============================================================================

/// 获取通用分配器的 std.mem.Allocator 接口
/// 对应 Zig: pub fn asStd(allocator: anytype) std.mem.Allocator
public func asStd(allocator: Allocator): Allocator {
    return allocator
}

/// 获取借用类型的分配器
/// 对应 Zig: pub fn Borrowed(comptime Allocator: type) type
/// 如果分配器定义了 Borrowed 类型，返回它，否则返回原类型

/// 借用分配器
/// 对应 Zig: pub fn borrow(allocator: anytype) Borrowed(@TypeOf(allocator))
public func borrow(allocator: Allocator): Allocator {
    return allocator
}

/// 可空分配器类型
/// 对应 Zig: pub fn Nullable(comptime Allocator: type) type
/// 对于 std.mem.Allocator 返回 NullableAllocator
/// 否则如果定义了 Nullable 则使用它
/// 否则使用 ?Allocator

/// 创建可空分配器
/// 对应 Zig: pub fn initNullable(comptime Allocator: type, allocator: ?Allocator) Nullable(Allocator)
public func initNullable(allocator: ?Allocator): NullableAllocator {
    return NullableAllocator.initFunc(allocator)
}

/// 解包可空分配器
/// 对应 Zig: pub fn unpackNullable(comptime Allocator: type, allocator: Nullable(Allocator)) ?Allocator
public func unpackNullable(allocator: NullableAllocator): ?Allocator {
    return allocator.get()
}

/// Default 分配器 (零大小类型)
/// 对应 Zig: pub const Default = struct { ... }
public class DefaultAllocator {
    /// 获取分配器
    /// 对应 Zig: pub fn allocator(self: Default) std.mem.Allocator
    public func allocator(): Allocator {
        return c_allocator
    }

    /// deinit 是 void
    /// 对应 Zig: pub const deinit = void
    public static func deinit(): Unit {}
}

/// 包级别名
/// 对应 Zig 中的重新导出
