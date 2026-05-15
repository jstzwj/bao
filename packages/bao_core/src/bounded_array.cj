// 严格翻译自: src/bun_core/bounded_array.zig
//   pub fn BoundedArray(comptime T: type, comptime buffer_capacity: usize) type
//   pub fn BoundedArrayAligned(comptime T: type, comptime alignment: Alignment, comptime buffer_capacity: usize) type
//   有界数组: 不需要分配器的固定容量数组, 运行时长度
package bao_core

// ============================================================================
// BoundedArray<T> - 有界数组
// 严格翻译自: src/bun_core/bounded_array.zig:18-299
//   pub fn BoundedArray(comptime T: type, comptime buffer_capacity: usize) type {
//       return BoundedArrayAligned(T, .fromByteUnits(@alignOf(T)), buffer_capacity);
//   }
// 仓颉: 使用泛型类实现, capacity 在构造时指定
// ============================================================================

/// 有界数组 - 对应 Bun BoundedArray(T, buffer_capacity)
/// 不需要分配器的固定容量数组, 运行时长度可变但不超过 capacity
/// Bun:
///   return struct {
///       buffer: [buffer_capacity]T align(alignment.toByteUnits()) = undefined,
///       len: Length = 0,
///   };
public class BoundedArray<T> {
    /// 内部缓冲区 - 对应 Bun buffer: [buffer_capacity]T
    private let buffer: Array<T>
    /// 容量上限 - 对应 Bun buffer_capacity (编译时常量, 仓颉运行时)
    public let capacity: Int64
    /// 当前长度 - 对应 Bun len: Length = 0
    public var len: Int64

    /// 构造函数 - 对应 Bun init(len)
    /// pub fn init(len: usize) error{Overflow}!Self {
    ///     if (len > buffer_capacity) return error.Overflow;
    ///     return Self{ .len = @intCast(len) };
    /// }
    public init(capacity: Int64) {
        this.capacity = capacity
        this.buffer = Array<T>(capacity, item: unsafe { uninitialized<T>() })
        this.len = 0
    }

    /// 从指定长度初始化 - 对应 Bun init(len)
    /// 如果 len > capacity 返回 None
    public static func init(len: Int64, capacity: Int64): ?BoundedArray<T> {
        if (len > capacity) {
            return None
        }
        let arr = BoundedArray<T>(capacity)
        arr.len = len
        return Some(arr)
    }

    /// 获取切片视图 - 对应 Bun slice()
    /// pub fn slice(self: anytype) switch (@TypeOf(&self.buffer)) { ... } {
    ///     return self.buffer[0..self.len];
    /// }
    public func slice(): Array<T> {
        if (len == 0) {
            return Array<T>()
        }
        return buffer[0..len].toArray()
    }

    /// 获取常量切片 - 对应 Bun constSlice()
    /// pub fn constSlice(self: *const Self) []align(alignment.toByteUnits()) const T {
    ///     return self.slice();
    /// }
    public func constSlice(): Array<T> {
        return slice()
    }

    /// 调整长度 - 对应 Bun resize()
    /// pub fn resize(self: *Self, len: usize) error{Overflow}!void {
    ///     if (len > buffer_capacity) return error.Overflow;
    ///     self.len = len;
    /// }
    public func resize(newLen: Int64): Bool {
        if (newLen > capacity) {
            return false
        }
        len = newLen
        return true
    }

    /// 清空 - 对应 Bun clear()
    /// pub fn clear(self: *Self) void { self.len = 0; }
    public func clear(): Unit {
        len = 0
    }

    /// 从数组复制创建 - 对应 Bun fromSlice()
    /// pub fn fromSlice(m: []const T) error{Overflow}!Self {
    ///     var list = try init(m.len);
    ///     @memcpy(list.slice(), m);
    ///     return list;
    /// }
    public static func fromSlice(items: Array<T>, cap: Int64): ?BoundedArray<T> {
        if (items.size > cap) {
            return None
        }
        let arr = BoundedArray<T>(cap)
        for (i in 0..items.size) {
            arr.buffer[i] = items[i]
        }
        arr.len = items.size
        return Some(arr)
    }

    /// 获取指定索引元素 - 对应 Bun get()
    /// pub fn get(self: Self, i: usize) T { return self.constSlice()[i]; }
    public func get(index: Int64): T {
        return buffer[index]
    }

    /// 设置指定索引元素 - 对应 Bun set()
    /// pub fn set(self: *Self, i: usize, item: T) void { self.slice()[i] = item; }
    public func set(index: Int64, item: T): Unit {
        buffer[index] = item
    }

    /// 获取容量 - 对应 Bun capacity()
    /// pub fn capacity(self: Self) usize { return self.buffer.len; }
    public func getCapacity(): Int64 {
        return capacity
    }

    /// 确保未使用容量 - 对应 Bun ensureUnusedCapacity()
    /// pub fn ensureUnusedCapacity(self: Self, additional_count: usize) error{Overflow}!void {
    ///     if (self.len + additional_count > buffer_capacity) return error.Overflow;
    /// }
    public func ensureUnusedCapacity(additionalCount: Int64): Bool {
        if (len + additionalCount > capacity) {
            return false
        }
        return true
    }

    /// 添加一个元素, 返回指针 - 对应 Bun addOne()
    /// pub fn addOne(self: *Self) error{Overflow}!*T {
    ///     try self.ensureUnusedCapacity(1);
    ///     return self.addOneAssumeCapacity();
    /// }
    public func addOne(): ?Int64 {
        if (!ensureUnusedCapacity(1)) {
            return None
        }
        return addOneAssumeCapacity()
    }

    /// 添加一个元素(假设有足够容量) - 对应 Bun addOneAssumeCapacity()
    /// pub fn addOneAssumeCapacity(self: *Self) *T {
    ///     assert(self.len < buffer_capacity);
    ///     self.len += 1;
    ///     return &self.slice()[self.len - 1];
    /// }
    public func addOneAssumeCapacity(): Int64 {
        len += 1
        return len - 1
    }

    /// 弹出最后一个元素 - 对应 Bun pop()
    /// pub fn pop(self: *Self) ?T {
    ///     if (self.len == 0) return null;
    ///     const item = self.get(self.len - 1);
    ///     self.len -= 1;
    ///     return item;
    /// }
    public func pop(): ?T {
        if (len == 0) {
            return None
        }
        let item = buffer[len - 1]
        len -= 1
        return Some(item)
    }

    /// 获取未使用容量切片 - 对应 Bun unusedCapacitySlice()
    /// pub fn unusedCapacitySlice(self: *Self) []align(alignment.toByteUnits()) T {
    ///     return self.buffer[self.len..];
    /// }
    public func unusedCapacitySlice(): Array<T> {
        if (len >= capacity) {
            return Array<T>()
        }
        return buffer[len..capacity].toArray()
    }

    /// 在指定位置插入元素 - 对应 Bun insert()
    /// pub fn insert(self: *Self, i: usize, item: T) error{Overflow}!void
    public func insert(index: Int64, item: T): Bool {
        if (index > len) {
            return false
        }
        if (!ensureUnusedCapacity(1)) {
            return false
        }
        // 向后移动元素
        var i = len
        while (i > index) {
            buffer[i] = buffer[i - 1]
            i -= 1
        }
        buffer[index] = item
        len += 1
        return true
    }

    /// 在指定位置插入切片 - 对应 Bun insertSlice()
    /// pub fn insertSlice(self: *Self, i: usize, items: []const T) error{Overflow}!void
    public func insertSlice(index: Int64, items: Array<T>): Bool {
        if (!ensureUnusedCapacity(items.size)) {
            return false
        }
        // 向后移动元素
        var i = len + items.size - 1
        while (i >= index + items.size) {
            buffer[i] = buffer[i - items.size]
            i -= 1
        }
        // 复制新元素
        for (j in 0..items.size) {
            buffer[index + j] = items[j]
        }
        len += items.size
        return true
    }

    /// 替换范围 - 对应 Bun replaceRange()
    /// pub fn replaceRange(self: *Self, start: usize, len: usize, new_items: []const T) error{Overflow}!void
    public func replaceRange(start: Int64, rangeLen: Int64, newItems: Array<T>): Bool {
        let afterRange = start + rangeLen
        if (rangeLen == newItems.size) {
            for (i in 0..newItems.size) {
                buffer[start + i] = newItems[i]
            }
        } else if (rangeLen < newItems.size) {
            if (!ensureUnusedCapacity(newItems.size - rangeLen)) {
                return false
            }
            for (i in 0..rangeLen) {
                buffer[start + i] = newItems[i]
            }
            insertSlice(afterRange, newItems[rangeLen..newItems.size].toArray())
        } else {
            for (i in 0..newItems.size) {
                buffer[start + i] = newItems[i]
            }
            let afterSubrange = start + newItems.size
            var j = Int64(0)
            var srcIdx = afterRange
            while (srcIdx < len) {
                buffer[afterSubrange + j] = buffer[srcIdx]
                j += 1
                srcIdx += 1
            }
            len = len - rangeLen + newItems.size
        }
        return true
    }

    /// 追加一个元素 - 对应 Bun append()
    /// pub fn append(self: *Self, item: T) error{Overflow}!void {
    ///     const new_item_ptr = try self.addOne();
    ///     new_item_ptr.* = item;
    /// }
    public func append(item: T): Bool {
        let idx = addOne()
        match (idx) {
            case Some(i) =>
                buffer[i] = item
                return true
            case None =>
                return false
        }
    }

    /// 追加一个元素(假设有足够容量) - 对应 Bun appendAssumeCapacity()
    /// pub fn appendAssumeCapacity(self: *Self, item: T) void
    public func appendAssumeCapacity(item: T): Unit {
        let idx = addOneAssumeCapacity()
        buffer[idx] = item
    }

    /// 有序删除 - 对应 Bun orderedRemove()
    /// pub fn orderedRemove(self: *Self, i: usize) T
    public func orderedRemove(index: Int64): ?T {
        let newLen = len - 1
        if (newLen == index) {
            return pop()
        }
        let oldItem = buffer[index]
        // 向前移动
        var i = index
        while (i < newLen) {
            buffer[i] = buffer[i + 1]
            i += 1
        }
        len = newLen
        return Some(oldItem)
    }

    /// 交换删除 - 对应 Bun swapRemove()
    /// pub fn swapRemove(self: *Self, i: usize) T {
    ///     if (self.len - 1 == i) return self.pop().?;
    ///     const old_item = self.get(i);
    ///     self.set(i, self.pop().?);
    ///     return old_item;
    /// }
    public func swapRemove(index: Int64): ?T {
        if (len - 1 == index) {
            return pop()
        }
        let oldItem = buffer[index]
        let last = pop()
        match (last) {
            case Some(l) => buffer[index] = l
            case None => {}
        }
        return Some(oldItem)
    }

    /// 追加切片 - 对应 Bun appendSlice()
    /// pub fn appendSlice(self: *Self, items: []const T) error{Overflow}!void
    public func appendSlice(items: Array<T>): Bool {
        if (!ensureUnusedCapacity(items.size)) {
            return false
        }
        appendSliceAssumeCapacity(items)
        return true
    }

    /// 追加切片(假设有足够容量) - 对应 Bun appendSliceAssumeCapacity()
    /// pub fn appendSliceAssumeCapacity(self: *Self, items: []const T) void
    public func appendSliceAssumeCapacity(items: Array<T>): Unit {
        let oldLen = len
        let newLen = oldLen + items.size
        len = newLen
        for (i in 0..items.size) {
            buffer[oldLen + i] = items[i]
        }
    }

    /// 追加 N 个相同元素 - 对应 Bun appendNTimes()
    /// pub fn appendNTimes(self: *Self, value: T, n: usize) error{Overflow}!void
    public func appendNTimes(value: T, n: Int64): Bool {
        let oldLen = len
        if (!resize(oldLen + n)) {
            return false
        }
        for (i in 0..n) {
            buffer[oldLen + i] = value
        }
        return true
    }

    /// 追加 N 个相同元素(假设有足够容量) - 对应 Bun appendNTimesAssumeCapacity()
    /// pub fn appendNTimesAssumeCapacity(self: *Self, value: T, n: usize) void
    public func appendNTimesAssumeCapacity(value: T, n: Int64): Unit {
        let oldLen = len
        let newLen = oldLen + n
        len = newLen
        for (i in 0..n) {
            buffer[oldLen + i] = value
        }
    }

    /// 转为普通数组
    public func toArray(): Array<T> {
        if (len == 0) {
            return Array<T>()
        }
        return buffer[0..len].toArray()
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == 0
    }

    /// 是否已满
    public func isFull(): Bool {
        return len == capacity
    }
}
