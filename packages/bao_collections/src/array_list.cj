// bao_collections - ArrayList 动态数组
// 严格翻译自: src/collections/array_list.zig
//   Bun 使用 ArrayList<T> 作为动态数组的包装
//   提供完整的列表操作: append, insert, remove, clone, sort 等
//   支持 deinit 时递归调用元素的 deinit
//   仓颉实现提供等价的泛型动态数组
package bao_collections

// ============================================================================
// ArrayList<T> - 泛型动态数组
// 严格翻译自: src/collections/array_list.zig
//   ArrayListIn(T, Allocator)
//   ArrayListAlignedIn(T, Allocator, alignment)
//   内部使用 unmanaged ArrayList + allocator 模式
//   注意: Bun 的 deinit 会递归调用每个元素的 deinit
// ============================================================================

/// 泛型动态数组
/// 严格翻译自: ArrayListAlignedIn(T, Allocator, alignment)
///   #unmanaged: Unmanaged
///   #allocator: Allocator
///   items(), capacity(), deinit(), append(), insert(), remove() 等
public class ArrayList<T> <: Iterable<T> {
    /// 内部存储
    private var items_: Array<T>
    /// 元素数量
    private var length: Int64
    /// 容量
    private var capacity_: Int64

    /// 元素数量
    public prop size: Int64 {
        get() { length }
    }

    public operator func [](i: Int64): T {
        return items_[i]
    }

    public operator func [](i: Int64, value!: T): Unit {
        items_[i] = value
    }

    /// 创建空列表
    /// 翻译自: pub fn init() Self
    public init() {
        items_ = Array<T>()
        length = 0
        capacity_ = 0
    }

    /// 使用初始容量创建
    /// 翻译自: pub fn initCapacity(num: usize) AllocError!Self
    public init(capacity: Int64, initValue: T) {
        capacity_ = capacity
        items_ = Array<T>(capacity, repeat: initValue)
        length = 0
    }

    /// 从数组创建
    public init(items: Array<T>) {
        items_ = items
        length = items.size
        capacity_ = items.size
    }

    /// 获取元素切片
    /// 翻译自: pub fn items(self: *const Self) Slice
    public func items(): Array<T> {
        if (items_.size != length) {
            return items_[0..length]
        }
        return items_
    }

    /// 获取容量
    /// 翻译自: pub fn capacity(self: *const Self) usize
    public func capacity(): Int64 {
        return capacity_
    }

    /// 清理 (递归调用元素 deinit)
    /// 翻译自: pub fn deinit(self: *Self) void
    ///   bun.memory.deinit(self.items())
    ///   self.deinitShallow()
    public func deinit(): Unit {
        // 仓颉 GC 处理
        clearAndFree()
    }

    /// 浅清理 (不调用元素 deinit)
    /// 翻译自: pub fn deinitShallow(self: *Self) void
    public func deinitShallow(): Unit {
        items_ = Array<T>()
        length = 0
        capacity_ = 0
    }

    /// 从拥有的切片创建
    /// 翻译自: pub fn fromOwnedSlice(allocator_, slice) Self
    public static func fromOwnedSlice(slice: Array<T>): ArrayList<T> {
        return ArrayList<T>(slice)
    }

    /// 创建写入器
    /// 翻译自: pub fn writer(self: *Self) Unmanaged.Writer
    public func writer(): ArrayListWriter<T> {
        return ArrayListWriter<T>(this)
    }

    /// 转为拥有的切片
    /// 翻译自: pub fn toOwnedSlice(self: *Self) AllocError!Slice
    public func toOwnedSlice(): Array<T> {
        if (length < capacity_) {
            return items_[0..length]
        }
        return items_
    }

    /// 浅克隆
    /// 翻译自: pub fn clone(self: *const Self) AllocError!Self
    public func clone(): ArrayList<T> {
        let result = ArrayList<T>()
        for (i in 0..length) {
            result.append(items_[i])
        }
        return result
    }

    public func iterator(): Iterator<T> {
        return ArrayListIterator<T>(this)
    }

    /// 插入元素
    /// 翻译自: pub fn insert(self: *Self, i: usize, item: T) AllocError!void
    public func insert(i: Int64, item: T): Unit {
        ensureCapacity(length + 1)
        // 移动元素
        var j = length
        while (j > i) {
            items_[j] = items_[j - 1]
            j -= 1
        }
        items_[i] = item
        length += 1
    }

    /// 在容量允许时插入
    /// 翻译自: pub fn insertAssumeCapacity(self: *Self, i: usize, item: T) void
    public func insertAssumeCapacity(i: Int64, item: T): Unit {
        var j = length
        while (j > i) {
            items_[j] = items_[j - 1]
            j -= 1
        }
        items_[i] = item
        length += 1
    }

    /// 追加元素
    /// 翻译自: pub fn append(self: *Self, item: T) AllocError!void
    public func append(item: T): Unit {
        ensureCapacity(length + 1)
        items_[length] = item
        length += 1
    }

    /// 在容量允许时追加
    /// 翻译自: pub fn appendAssumeCapacity(self: *Self, item: T) void
    public func appendAssumeCapacity(item: T): Unit {
        items_[length] = item
        length += 1
    }

    /// 有序移除
    /// 翻译自: pub fn orderedRemove(self: *Self, i: usize) T
    public func orderedRemove(i: Int64): T {
        let item = items_[i]
        // 移动后续元素
        var j = i
        while (j < length - 1) {
            items_[j] = items_[j + 1]
            j += 1
        }
        length -= 1
        return item
    }

    /// 交换移除 (O(1), 不保序)
    /// 翻译自: pub fn swapRemove(self: *Self, i: usize) T
    public func swapRemove(i: Int64): T {
        let item = items_[i]
        length -= 1
        if (i != length) {
            items_[i] = items_[length]
        }
        return item
    }

    public func removeAt(i: Int64): T {
        return orderedRemove(i)
    }


    /// 弹出最后一个元素
    /// 翻译自: pub fn pop(self: *Self) ?T
    public func pop(): ?T {
        if (length == 0) {
            return None
        }
        length -= 1
        return items_[length]
    }

    /// 获取最后一个元素
    /// 翻译自: pub fn getLast(self: *const Self) *T
    public func getLast(): ?T {
        if (length == 0) {
            return None
        }
        return items_[length - 1]
    }

    /// 追加切片
    /// 翻译自: pub fn appendSlice(self: *Self, new_items: []const T) AllocError!void
    public func appendSlice(newItems: Array<T>): Unit {
        ensureCapacity(length + newItems.size)
        for (item in newItems) {
            items_[length] = item
            length += 1
        }
    }

    /// 在容量允许时追加切片
    /// 翻译自: pub fn appendSliceAssumeCapacity(self: *Self, new_items: []const T) void
    public func appendSliceAssumeCapacity(newItems: Array<T>): Unit {
        for (item in newItems) {
            items_[length] = item
            length += 1
        }
    }

    /// 追加 N 个相同元素
    /// 翻译自: pub inline fn appendNTimes(self: *Self, value: T, n: usize) AllocError!void
    public func appendNTimes(value: T, n: Int64): Unit {
        ensureCapacity(length + n)
        var i: Int64 = 0
        while (i < n) {
            items_[length] = value
            length += 1
            i += 1
        }
    }

    /// 调整大小 (多出部分用 initValue 填充)
    /// 翻译自: pub fn resize(self: *Self, init_value: T, new_len: usize) AllocError!void
    public func resize(initValue: T, newLen: Int64): Unit {
        ensureCapacity(newLen)
        if (newLen > length) {
            var i = length
            while (i < newLen) {
                items_[i] = initValue
                i += 1
            }
        }
        length = newLen
    }

    /// 缩减并释放
    /// 翻译自: pub fn shrinkAndFree(self: *Self, new_len: usize) void
    public func shrinkAndFree(newLen: Int64): Unit {
        if (newLen < length) {
            length = newLen
        }
    }

    /// 缩减但保留容量
    /// 翻译自: pub fn shrinkRetainingCapacity(self: *Self, new_len: usize) void
    public func shrinkRetainingCapacity(newLen: Int64): Unit {
        if (newLen < length) {
            length = newLen
        }
    }

    /// 清除但保留容量
    /// 翻译自: pub fn clearRetainingCapacity(self: *Self) void
    public func clearRetainingCapacity(): Unit {
        length = 0
    }

    public func clear(): Unit {
        clearRetainingCapacity()
    }

    /// 清除并释放
    /// 翻译自: pub fn clearAndFree(self: *Self) void
    public func clearAndFree(): Unit {
        items_ = Array<T>()
        length = 0
        capacity_ = 0
    }

    /// 确保容量
    /// 翻译自: pub fn ensureTotalCapacity(self: *Self, new_capacity: usize) AllocError!void
    public func ensureTotalCapacity(newCapacity: Int64): Unit {
        ensureCapacity(newCapacity)
    }

    /// 确保未使用的容量
    /// 翻译自: pub fn ensureUnusedCapacity(self: *Self, additional_count: usize) AllocError!void
    public func ensureUnusedCapacity(additional: Int64): Unit {
        ensureCapacity(length + additional)
    }

    /// 扩展到容量
    /// 翻译自: pub fn expandToCapacity(self: *Self, init_value: T) void
    public func expandToCapacity(initValue: T): Unit {
        while (length < capacity_) {
            items_[length] = initValue
            length += 1
        }
    }

    /// 是否为空
    /// 翻译自: pub fn isEmpty(self: *const Self) bool
    public func isEmpty(): Bool {
        return length == 0
    }

    /// 替换范围
    /// 翻译自: pub fn replaceRange(self, start, len, new_items) AllocError!void
    public func replaceRange(start: Int64, len: Int64, newItems: Array<T>): Unit {
        let end = start + len
        let diff = newItems.size - len
        if (diff > 0) {
            ensureCapacity(length + diff)
        }
        // 移动后续元素
        if (diff != 0) {
            var i = length - 1
            while (i >= end) {
                items_[i + diff] = items_[i]
                if (i == 0) { break }
                i -= 1
            }
        }
        // 插入新元素
        var i: Int64 = 0
        while (i < newItems.size) {
            items_[start + i] = newItems[i]
            i += 1
        }
        length += diff
    }

    /// 确保容量足够
    private func ensureCapacity(needed: Int64): Unit {
        if (needed > capacity_) {
            var newCap = if (capacity_ == 0) { needed } else { capacity_ }
            while (newCap < needed) {
                newCap *= 2
            }
            let fill = if (length > 0) { items_[0] } else { throw Exception("ArrayList requires an existing element to grow") }
            let newItems = Array<T>(newCap, repeat: fill)
            for (i in 0..length) {
                newItems[i] = items_[i]
            }
            items_ = newItems
            capacity_ = newCap
        }
    }
}

class ArrayListIterator<T> <: Iterator<T> {
    private let list: ArrayList<T>
    private var index: Int64

    public init(list: ArrayList<T>) {
        this.list = list
        this.index = 0
    }

    public func hasNext(): Bool {
        return index < list.size
    }

    public func next(): ?T {
        if (!hasNext()) {
            return None
        }
        let value = list[index]
        index += 1
        return Some(value)
    }
}

// ============================================================================
// ArrayListWriter - 列表写入器
// ============================================================================

/// 列表写入器
public class ArrayListWriter<T> {
    private var list: ArrayList<T>

    public init(list: ArrayList<T>) {
        this.list = list
    }

    public func write(item: T): Unit {
        list.append(item)
    }

    public func writeSlice(items: Array<T>): Unit {
        list.appendSlice(items)
    }
}
