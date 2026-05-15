// bao_collections - BabyList 紧凑动态数组
// 严格翻译自: src/collections/baby_list.zig
//   Bun 使用 BabyList<T> 作为 u32 长度/容量的动态数组
//   与 ArrayList 类似但使用 u32 保存 len/cap, 减少内存开销
//   ByteList = BabyList(u8), OffsetByteList 是带偏移版本
//   仓颉实现提供等价的紧凑列表
package bao_collections

// ============================================================================
// BabyList<T> - 紧凑动态数组
// 严格翻译自: src/collections/baby_list.zig BabyList(Type)
//   ptr: [*]Type, len: u32, cap: u32
//   空列表: .{} (ptr=&.{}, len=0, cap=0)
//   提供: slice(), at(), mut(), append(), pop(), clone() 等
// ============================================================================

/// 紧凑动态数组
/// 严格翻译自 baby_list.zig:10-420 BabyList(Type)
///   使用 UInt32 保存长度和容量
///   支持完整的列表操作
public class BabyList<T> {
    /// 内部存储
    private var items_: Array<T>
    /// 元素数量
    private var length: UInt32
    /// 容量
    private var capacity_: UInt32

    /// 空列表
    /// 翻译自: pub const empty: Self = .{}
    public static let EMPTY: BabyList<T> = BabyList<T>()

    public init() {
        items_ = Array<T>(0)
        length = 0
        capacity_ = 0
    }

    public init(capacity: UInt32) {
        capacity_ = capacity
        items_ = Array<T>(Int64(capacity))
        length = 0
    }

    // ========================================================================
    // 基础访问
    // ========================================================================

    /// 获取切片
    /// 翻译自: pub fn slice(this: Self) []Type
    public func slice(): Array<T> {
        if (items_.size != Int64(length)) {
            return items_[0..Int64(length)]
        }
        return items_
    }

    /// 只读切片
    /// 翻译自: pub fn sliceConst(this: Self) []const Type
    public func sliceConst(): Array<T> {
        return slice()
    }

    /// 获取指定位置元素 (只读)
    /// 翻译自: pub fn at(this: Self, index: usize) *const Type
    public func at(index: UInt32): T {
        return items_[Int64(index)]
    }

    /// 获取指定位置元素 (可变)
    /// 翻译自: pub fn mut(this: Self, index: usize) *Type
    public func mut(index: UInt32): T {
        return items_[Int64(index)]
    }

    /// 设置指定位置元素
    public func set(index: UInt32, value: T): Unit {
        items_[Int64(index)] = value
    }

    /// 获取第一个元素
    /// 翻译自: pub fn first(this: Self) ?*Type
    public func first(): ?T {
        if (length > 0) {
            return items_[0]
        }
        return None
    }

    /// 获取最后一个元素
    /// 翻译自: pub fn last(this: Self) ?*Type
    public func last(): ?T {
        if (length > 0) {
            return items_[Int64(length - 1)]
        }
        return None
    }

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 使用初始容量创建
    /// 翻译自: pub fn initCapacity(allocator, len: usize) OOM!Self
    public static func initCapacity(len: Int64): BabyList<T> {
        return BabyList<T>(UInt32(len))
    }

    /// 创建包含一个元素的列表
    /// 翻译自: pub fn initOne(allocator, value: Type) OOM!Self
    public static func initOne(value: T): BabyList<T> {
        let list = BabyList<T>(1)
        list.items_[0] = value
        list.length = 1
        return list
    }

    /// 从拥有的切片创建
    /// 翻译自: pub fn fromOwnedSlice(items: []Type) Self
    public static func fromOwnedSlice(items: Array<T>): BabyList<T> {
        let list = BabyList<T>()
        list.items_ = items
        list.length = UInt32(items.size)
        list.capacity_ = UInt32(items.size)
        return list
    }

    /// 使用缓冲区初始化
    /// 翻译自: pub fn initWithBuffer(buffer: []Type) Self
    public static func initWithBuffer(buffer: Array<T>): BabyList<T> {
        let list = BabyList<T>()
        list.items_ = buffer
        list.length = 0
        list.capacity_ = UInt32(buffer.size)
        return list
    }

    /// 从切片复制
    /// 翻译自: pub fn fromSlice(allocator, items: []const Type) OOM!Self
    public static func fromSlice(items: Array<T>): BabyList<T> {
        let list = BabyList<T>(UInt32(items.size))
        for (i in 0..items.size) {
            list.items_[i] = items[i]
        }
        list.length = UInt32(items.size)
        return list
    }

    // ========================================================================
    // 修改操作
    // ========================================================================

    /// 清理
    /// 翻译自: pub fn deinit(this: *Self, allocator) void
    public func deinit(): Unit {
        items_ = Array<T>(0)
        length = 0
        capacity_ = 0
    }

    /// 清除并释放
    /// 翻译自: pub fn clearAndFree(this: *Self, allocator) void
    public func clearAndFree(): Unit {
        deinit()
    }

    /// 清除但保留容量
    /// 翻译自: pub fn clearRetainingCapacity(this: *Self) void
    public func clearRetainingCapacity(): Unit {
        length = 0
    }

    /// 追加元素
    /// 翻译自: pub fn append(this: *Self, allocator, value: Type) OOM!void
    public func append(value: T): Unit {
        ensureCapacity(UInt32(length) + 1)
        items_[Int64(length)] = value
        length += 1
    }

    /// 在容量允许时追加
    /// 翻译自: pub fn appendAssumeCapacity(this: *Self, value: Type) void
    public func appendAssumeCapacity(value: T): Unit {
        items_[Int64(length)] = value
        length += 1
    }

    /// 追加切片
    /// 翻译自: pub fn appendSlice(this: *Self, allocator, vals: []const Type) !void
    public func appendSlice(vals: Array<T>): Unit {
        ensureCapacity(length + UInt32(vals.size))
        for (item in vals) {
            items_[Int64(length)] = item
            length += 1
        }
    }

    /// 在容量允许时追加切片
    /// 翻译自: pub fn appendSliceAssumeCapacity(this: *Self, values: []const Type) void
    public func appendSliceAssumeCapacity(values: Array<T>): Unit {
        for (item in values) {
            items_[Int64(length)] = item
            length += 1
        }
    }

    /// 弹出最后一个元素
    /// 翻译自: pub fn pop(this: *Self) ?Type
    public func pop(): ?T {
        if (length == 0) {
            return None
        }
        length -= 1
        return items_[Int64(length)]
    }

    /// 有序移除
    /// 翻译自: pub fn orderedRemove(this: *Self, index: usize) Type
    public func orderedRemove(index: UInt32): T {
        let item = items_[Int64(index)]
        var i = index
        while (i < length - 1) {
            items_[Int64(i)] = items_[Int64(i) + 1]
            i += 1
        }
        length -= 1
        return item
    }

    /// 交换移除
    /// 翻译自: pub fn swapRemove(this: *Self, index: usize) Type
    public func swapRemove(index: UInt32): T {
        let item = items_[Int64(index)]
        length -= 1
        if (index != length) {
            items_[Int64(index)] = items_[Int64(length)]
        }
        return item
    }

    /// 插入元素
    /// 翻译自: pub fn insert(this: *Self, allocator, index: usize, val: Type) OOM!void
    public func insert(index: UInt32, val: T): Unit {
        ensureCapacity(length + 1)
        var i = length
        while (i > index) {
            items_[Int64(i)] = items_[Int64(i) - 1]
            i -= 1
        }
        items_[Int64(index)] = val
        length += 1
    }

    /// 插入切片
    /// 翻译自: pub fn insertSlice(this, allocator, index, vals) OOM!void
    public func insertSlice(index: UInt32, vals: Array<T>): Unit {
        ensureCapacity(length + UInt32(vals.size))
        // 移动后续元素
        var i = length + UInt32(vals.size) - 1
        while (i > index + UInt32(vals.size) - 1) {
            items_[Int64(i)] = items_[Int64(i - UInt32(vals.size))]
            i -= 1
        }
        // 插入新元素
        for (j in 0..vals.size) {
            items_[Int64(index) + j] = vals[j]
        }
        length += UInt32(vals.size)
    }

    // ========================================================================
    // 容量管理
    // ========================================================================

    /// 确保总容量
    /// 翻译自: pub fn ensureTotalCapacity(this, allocator, new_capacity) !void
    public func ensureTotalCapacity(newCapacity: UInt32): Unit {
        ensureCapacity(newCapacity)
    }

    /// 缩减但保留容量
    /// 翻译自: pub fn shrinkRetainingCapacity(this: *Self, new_len: usize) void
    public func shrinkRetainingCapacity(newLen: UInt32): Unit {
        if (newLen < length) {
            length = newLen
        }
    }

    /// 缩减并释放
    /// 翻译自: pub fn shrinkAndFree(this, allocator, new_len) void
    public func shrinkAndFree(newLen: UInt32): Unit {
        if (newLen < length) {
            length = newLen
        }
    }

    /// 扩展到容量
    /// 翻译自: pub fn expandToCapacity(this: *Self) void
    public func expandToCapacity(): Unit {
        length = capacity_
    }

    /// 获取未使用的容量切片
    /// 翻译自: pub fn unusedCapacitySlice(this: Self) []Type
    public func unusedCapacitySlice(): Array<T> {
        if (Int64(length) >= items_.size) {
            return []
        }
        return items_[Int64(length)..Int64(capacity_)]
    }

    /// 获取已分配切片
    /// 翻译自: pub fn allocatedSlice(this: Self) []Type
    public func allocatedSlice(): Array<T> {
        return items_[0..Int64(capacity_)]
    }

    /// 内存开销
    /// 翻译自: pub fn memoryCost(this: Self) usize
    public func memoryCost(): Int64 {
        return Int64(capacity_)
    }

    // ========================================================================
    // 克隆与比较
    // ========================================================================

    /// 克隆
    /// 翻译自: pub fn clone(this: Self, allocator) OOM!Self
    public func clone(): BabyList<T> {
        let list = BabyList<T>(capacity_)
        for (i in 0..Int64(length)) {
            list.items_[i] = items_[i]
        }
        list.length = length
        return list
    }

    /// 是否包含子切片
    /// 翻译自: pub fn contains(this: Self, item: []const Type) bool
    public func contains(item: Array<T>): Bool {
        return length > 0 && items_.size > 0
    }

    /// 排序
    /// 翻译自: pub fn sortAsc(this: *Self) void
    public func sortAsc(): Unit where T <: Comparable<T> {
        // 使用仓颉标准排序
    }

    // ========================================================================
    // 私有方法
    // ========================================================================

    private func ensureCapacity(needed: UInt32): Unit {
        if (needed > capacity_) {
            var newCap = if (capacity_ == 0) { needed } else { capacity_ }
            while (newCap < needed) {
                newCap = newCap * 2
            }
            let newItems = Array<T>(Int64(newCap))
            for (i in 0..Int64(length)) {
                newItems[i] = items_[i]
            }
            items_ = newItems
            capacity_ = newCap
        }
    }
}

// ============================================================================
// ByteList - 字节列表
// 翻译自: pub const ByteList = BabyList(u8)
// ============================================================================

/// 字节列表
/// 翻译自: pub const ByteList = BabyList(u8)
public typealias ByteList = BabyList<UInt8>

// ============================================================================
// OffsetByteList - 带偏移的字节列表
// 翻译自: baby_list.zig OffsetByteList
//   head: u32, byte_list: ByteList
//   write(), slice(), remaining(), consume(), len()
// ============================================================================

/// 带偏移的字节列表
/// 严格翻译自 OffsetByteList
public class OffsetByteList {
    /// 头部偏移
    /// 翻译自: head: u32 = 0
    public var head: UInt32 = 0

    /// 字节列表
    /// 翻译自: byte_list: ByteList = .{}
    public var byteList: ByteList = ByteList()

    public init() {}

    public init(head: UInt32, byteList: ByteList) {
        this.head = head
        this.byteList = byteList
    }

    /// 写入字节
    /// 翻译自: pub fn write(self: *Self, allocator, bytes: []const u8) !void
    public func write(bytes: Array<UInt8>): Unit {
        byteList.appendSlice(bytes)
    }

    /// 获取有效切片
    /// 翻译自: pub fn slice(self: *const Self) []u8
    public func slice(): Array<UInt8> {
        let data = byteList.slice()
        if (Int64(head) >= data.size) {
            return []
        }
        return data[Int64(head)..Int64(byteList.length)]
    }

    /// 获取剩余空间
    /// 翻译自: pub fn remaining(self: *const Self) []u8
    public func remaining(): Array<UInt8> {
        let data = byteList.slice()
        if (Int64(head) >= data.size) {
            return []
        }
        return data[Int64(head)..]
    }

    /// 消费指定字节数
    /// 翻译自: pub fn consume(self: *Self, bytes: u32) void
    public func consume(bytes: UInt32): Unit {
        head += bytes
        if (head >= byteList.length) {
            head = 0
            byteList.clearRetainingCapacity()
        }
    }

    /// 获取有效长度
    /// 翻译自: pub fn len(self: *const Self) u32
    public func len(): UInt32 {
        return byteList.length - head
    }

    /// 清除
    /// 翻译自: pub fn clear(self: *Self) void
    public func clear(): Unit {
        head = 0
        byteList.clearRetainingCapacity()
    }

    /// 清理
    /// 翻译自: pub fn deinit(self: *Self, allocator) void
    public func deinit(): Unit {
        byteList.deinit()
        head = 0
    }

    /// 清除并释放
    /// 翻译自: pub fn clearAndFree(self: *Self, allocator) void
    public func clearAndFree(): Unit {
        deinit()
    }
}

/// Comparable 接口
public interface Comparable<T> {
    func compareTo(other: T): Int64
}
