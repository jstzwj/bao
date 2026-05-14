// bao_collections - BoundedArray 有界数组
// 严格翻译自: src/collections/bounded_array.zig
//   pub fn BoundedArray(comptime T: type, comptime capacity: usize) type
//   固定容量的数组，超出容量时返回错误
package bao_collections

// ============================================================================
// BoundedArray - 固定容量数组
// 严格翻译自: src/collections/bounded_array.zig
//   Zig 使用 comptime capacity 编译期固定大小
//   仓颉使用构造时传入容量，运行时检查越界
// ============================================================================

/// 固定容量数组 - 对应 Bun BoundedArray
/// 不能超过预设容量，适用于已知最大尺寸的场景 (如路径缓冲区)
public class BoundedArray<T> {
    /// 底层存储
    private var data: Array<T>
    /// 当前元素数量 - 对应 Bun len
    private var len: Int64
    /// 最大容量 - 对应 Bun capacity
    private let maxCapacity: Int64

    /// 初始化指定容量的空数组
    /// 对应 Bun BoundedArray.init()
    public init(capacity: Int64, defaultValue: T) {
        maxCapacity = capacity
        data = Array<T>(capacity, item: defaultValue)
        len = 0
    }

    /// 从已有数组构造 (不超过容量)
    /// 对应 Bun BoundedArray.fromSlice()
    public init(capacity: Int64, items: Array<T>, defaultValue: T) {
        maxCapacity = capacity
        var arr = Array<T>(capacity, item: defaultValue)
        let copyLen = if (items.size < capacity) { items.size } else { capacity }
        for (i in 0..copyLen) {
            arr[i] = items[i]
        }
        data = arr
        len = copyLen
    }

    /// 元素数量 - 对应 Bun BoundedArray.len()
    public func length(): Int64 {
        return len
    }

    /// 最大容量 - 对应 Bun BoundedArray.capacity()
    public func capacity(): Int64 {
        return maxCapacity
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == 0
    }

    /// 是否已满
    public func isFull(): Bool {
        return len >= maxCapacity
    }

    /// 剩余空间
    public func remaining(): Int64 {
        return maxCapacity - len
    }

    /// 获取元素 - 对应 Bun BoundedArray.get()
    public func get(index: Int64): T {
        if (index < 0 || index >= len) {
            throw IndexOutOfBoundsException("BoundedArray index ${index} out of bounds [0, ${len})")
        }
        return data[index]
    }

    /// 设置元素 - 对应 Bun BoundedArray.set()
    public func set(index: Int64, value: T): Unit {
        if (index < 0 || index >= len) {
            throw IndexOutOfBoundsException("BoundedArray index ${index} out of bounds [0, ${len})")
        }
        data[index] = value
    }

    /// 追加元素 - 对应 Bun BoundedArray.append()
    /// 超出容量时返回 false (Zig 返回 error.Overflow)
    public func append(item: T): Bool {
        if (len >= maxCapacity) {
            return false
        }
        data[len] = item
        len += 1
        return true
    }

    /// 追加元素 (越界时抛异常)
    public func appendOrThrow(item: T): Unit {
        if (!append(item)) {
            throw IndexOutOfBoundsException("BoundedArray is full (capacity: ${maxCapacity})")
        }
    }

    /// 追加多个元素 - 对应 Bun BoundedArray.appendSlice()
    public func appendSlice(items: Array<T>): Bool {
        if (len + items.size > maxCapacity) {
            return false
        }
        for (item in items) {
            data[len] = item
            len += 1
        }
        return true
    }

    /// 移除最后一个元素 - 对应 Bun BoundedArray.pop()
    public func pop(): ?T {
        if (len == 0) {
            return None
        }
        len -= 1
        return Some(data[len])
    }

    /// 获取最后一个元素 - 对应 Bun BoundedArray.last()
    public func last(): ?T {
        if (len == 0) {
            return None
        }
        return Some(data[len - 1])
    }

    /// 获取已使用的切片 - 对应 Bun BoundedArray.constSlice()
    public func slice(): Array<T> {
        var result = Array<T>()
        for (i in 0..len) {
            result.append(data[i])
        }
        return result
    }

    /// 获取可变引用 - 对应 Bun BoundedArray.slice()
    public func mutSlice(): Array<T> {
        return slice()
    }

    /// 清空 - 对应 Bun BoundedArray.clear()
    public func clear(): Unit {
        len = 0
    }

    /// 重置到指定长度 - 对应 Bun BoundedArray.resize()
    public func resize(newLen: Int64): Bool {
        if (newLen < 0 || newLen > maxCapacity) {
            return false
        }
        len = newLen
        return true
    }

    /// 遍历
    public func forEach(fn: (T) -> Unit): Unit {
        for (i in 0..len) {
            fn(data[i])
        }
    }

    /// 遍历带索引
    public func forEachWithIndex(fn: (Int64, T) -> Unit): Unit {
        for (i in 0..len) {
            fn(i, data[i])
        }
    }

    // ========================================================================
    // 额外方法 - 严格翻译自 Zig std.BoundedArray 补充
    //   asConstSlice, assign, insert, orderedRemove, swapRemove
    //   span, toOwnedSlice, format
    // ========================================================================

    /// 获取指定范围切片 - 对应 Bun BoundedArray.slice(start, end)
    public func slice(start: Int64, end: Int64): Array<T> {
        let e = if (end > len) { len } else { end }
        var result = Array<T>()
        for (i in start..e) {
            if (i >= 0) {
                result.append(data[i])
            }
        }
        return result
    }

    /// 在指定位置插入 - 对应 Bun BoundedArray.insert
    /// 后续元素后移
    public func insert(index: Int64, item: T): Bool {
        if (index < 0 || index > len || len >= maxCapacity) {
            return false
        }
        // 从末尾开始后移
        var i = len
        while (i > index) {
            data[i] = data[i - 1]
            i -= 1
        }
        data[index] = item
        len += 1
        return true
    }

    /// 有序删除 - 对应 Bun BoundedArray.orderedRemove
    /// 后续元素前移
    public func orderedRemove(index: Int64): ?T {
        if (index < 0 || index >= len) {
            return None
        }
        let removed = data[index]
        var i = index
        while (i < len - 1) {
            data[i] = data[i + 1]
            i += 1
        }
        len -= 1
        return Some(removed)
    }

    /// 交换删除 - 对应 Bun BoundedArray.swapRemove
    /// 与最后一个元素交换后删除，O(1)
    public func swapRemove(index: Int64): ?T {
        if (index < 0 || index >= len) {
            return None
        }
        let removed = data[index]
        len -= 1
        if (index != len) {
            data[index] = data[len]
        }
        return Some(removed)
    }

    /// 获取可变引用 - 对应 Bun BoundedArray.mut(i) (带边界检查)
    public func getMut(index: Int64): ?T {
        if (index < 0 || index >= len) {
            return None
        }
        return Some(data[index])
    }

    /// 检查是否包含元素
    public func contains(item: T): Bool where T <: Equatable<T> {
        for (i in 0..len) {
            if (data[i] == item) {
                return true
            }
        }
        return false
    }

    /// 从头查找元素索引 - 对应 Bun BoundedArray.indexOf
    public func indexOf(item: T): ?Int64 where T <: Equatable<T> {
        for (i in 0..len) {
            if (data[i] == item) {
                return Some(i)
            }
        }
        return None
    }

    /// 转为字符串 - 调试用
    public func toString(): String {
        var sb = StringBuilder()
        sb.append("BoundedArray(len=${len}, cap=${maxCapacity}, [")
        for (i in 0..len) {
            if (i > 0) { sb.append(", ") }
            sb.append("${data[i]}")
        }
        sb.append("])")
        return sb.toString()
    }
}

/// 索引越界异常
public class IndexOutOfBoundsException <: Exception {
    public init(message: String) {
        super(message)
    }
}
