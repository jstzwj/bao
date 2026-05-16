// bao_collections - LinearFifo 线性FIFO队列
// 严格翻译自: src/collections/linear_fifo.zig
//   单生产者单消费者 (SPSC) 环形缓冲区
//   用于线程间通信的通道实现
package bao_collections

// ============================================================================
// LinearFifo - SPSC 环形缓冲区
// 严格翻译自: src/collections/linear_fifo.zig
//   pub fn LinearFifo(comptime T: type, comptime buffer_type: LinearFifoBufferType) type
//   Zig 支持三种缓冲区: Static(固定), Slice(外部), Dynamic(动态)
//   仓颉使用动态数组模拟环形缓冲区
// ============================================================================

/// SPSC 环形缓冲区 - 对应 Bun LinearFifo
/// 单生产者单消费者队列，使用环形缓冲区实现
/// 用于线程间消息传递、IO管道等场景
public class LinearFifo<T> {
    /// 底层缓冲区
    private var buffer: Array<T>
    /// 缓冲区容量 (2的幂)
    private var capacity: Int64
    /// 读位置 (head)
    private var head: Int64
    /// 写位置 (tail)
    private var tail: Int64
    /// 当前元素数量
    private var count: Int64

    /// 初始化指定容量的FIFO
    /// 对应 Bun LinearFifo.init()
    public init(capacity: Int64, defaultValue: T) {
        // 容量向上取到2的幂
        var cap = Int64(1)
        while (cap < capacity) {
            cap *= 2
        }
        this.capacity = cap
        this.buffer = Array<T>(cap, repeat: defaultValue)
        this.head = 0
        this.tail = 0
        this.count = 0
    }

    /// 可读元素数量 - 对应 Bun LinearFifo.readableLength
    public func readableLength(): Int64 {
        return count
    }

    /// 可写空间 - 对应 Bun LinearFifo.writableLength
    public func writableLength(): Int64 {
        return capacity - count
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return count == 0
    }

    /// 是否已满
    public func isFull(): Bool {
        return count == capacity
    }

    /// 元素数量
    public func len(): Int64 {
        return count
    }

    /// 写入单个元素 - 对应 Bun LinearFifo.writeItem
    /// 返回是否成功 (满时返回 false)
    public func writeItem(item: T): Bool {
        if (count >= capacity) {
            return false
        }
        buffer[tail] = item
        tail = (tail + 1) % capacity
        count += 1
        return true
    }

    /// 写入多个元素 - 对应 Bun LinearFifo.write
    /// 返回实际写入的数量
    public func write(items: Array<T>): Int64 {
        let toWrite = if (items.size < writableLength()) { items.size } else { writableLength() }
        for (i in 0..toWrite) {
            buffer[tail] = items[i]
            tail = (tail + 1) % capacity
        }
        count += toWrite
        return toWrite
    }

    /// 写入多个元素 (ArrayList)
    public func writeList(items: ArrayList<T>): Int64 {
        let toWrite = if (items.size < writableLength()) { items.size } else { writableLength() }
        for (i in 0..toWrite) {
            buffer[tail] = items[Int64(i)]
            tail = (tail + 1) % capacity
        }
        count += toWrite
        return toWrite
    }

    /// 读取单个元素 - 对应 Bun LinearFifo.readItem
    public func readItem(): ?T {
        if (count == 0) {
            return None
        }
        let item = buffer[head]
        head = (head + 1) % capacity
        count -= 1
        return Some(item)
    }

    /// 读取多个元素到数组 - 对应 Bun LinearFifo.read
    /// 返回实际读取的数量
    public func read(dst: Array<T>): Int64 {
        let toRead = if (count < dst.size) { count } else { Int64(dst.size) }
        for (i in 0..toRead) {
            dst[i] = buffer[head]
            head = (head + 1) % capacity
        }
        count -= toRead
        return toRead
    }

    /// 窥视元素 (不移除) - 对应 Bun LinearFifo.peekItem
    public func peekItem(offset: Int64): ?T {
        if (offset < 0 || offset >= count) {
            return None
        }
        let idx = (head + offset) % capacity
        return Some(buffer[idx])
    }

    /// 丢弃指定数量的元素 - 对应 Bun LinearFifo.discard
    public func discard(n: Int64): Unit {
        let toDiscard = if (n < count) { n } else { count }
        head = (head + toDiscard) % capacity
        count -= toDiscard
    }

    /// 将数据放回读端 - 对应 Bun LinearFifo.unget
    public func unget(items: Array<T>): Bool {
        if (items.size > head) {
            // 空间不足
            return false
        }
        for (i in 0..items.size) {
            head = (head - 1 + capacity) % capacity
            buffer[head] = items[Int64(items.size - 1 - i)]
        }
        count += items.size
        return true
    }

    /// 重新对齐缓冲区 - 对应 Bun LinearFifo.realign
    /// 将数据移动到缓冲区起始位置，减少环绕
    public func realign(): Unit {
        if (count == 0) {
            head = 0
            tail = 0
            return
        }
        var newBuf = Array<T>(capacity, repeat: buffer[0])
        for (i in 0..count) {
            newBuf[i] = buffer[(head + i) % capacity]
        }
        buffer = newBuf
        head = 0
        tail = count
    }

    /// 确保最小容量 - 对应 Bun LinearFifo.ensureTotalCapacity
    public func ensureTotalCapacity(minCapacity: Int64): Unit {
        if (capacity >= minCapacity) {
            return
        }
        // 扩容: 重新对齐后扩展
        realign()
        var newCap = capacity
        while (newCap < minCapacity) {
            newCap *= 2
        }
        var newBuf = Array<T>(newCap, repeat: buffer[0])
        for (i in 0..count) {
            newBuf[i] = buffer[i]
        }
        buffer = newBuf
        capacity = newCap
    }

    /// 缩减容量 - 对应 Bun LinearFifo.shrink
    public func shrink(newCapacity: Int64): Unit {
        if (newCapacity >= capacity || newCapacity < count) {
            return
        }
        realign()
        var newBuf = Array<T>(newCapacity, repeat: buffer[0])
        for (i in 0..count) {
            newBuf[i] = buffer[i]
        }
        buffer = newBuf
        capacity = newCapacity
    }

    /// 清空 - 对应 Bun LinearFifo.reset
    public func clear(): Unit {
        head = 0
        tail = 0
        count = 0
    }

    /// 遍历所有可读元素 (不消耗)
    public func forEach(fn: (T) -> Unit): Unit {
        for (i in 0..count) {
            fn(buffer[(head + i) % capacity])
        }
    }

    // ========================================================================
    // 额外方法 - 严格翻译自 Zig std.LinearFifo 补充
    //   peek, drain, writableSlice, readableSlice, toOwnedSlice
    // ========================================================================

    /// 窥视第一个元素 (offset=0) - 对应 Bun LinearFifo.peek
    public func peek(): ?T {
        return peekItem(0)
    }

    /// 排空队列到数组 - 对应 Bun LinearFifo.drain
    /// 读取并移除所有元素
    public func drain(): Array<T> {
        let n = count
        let result = Array<T>(n, { i => buffer[(head + i) % capacity] })
        clear()
        return result
    }

    /// 获取可写切片的视图 (不移动指针)
    /// 对应 Bun LinearFifo.writableSlice
    public func writableSlice(): Array<T> {
        let available = writableLength()
        return Array<T>(available, { i => buffer[(tail + i) % capacity] })
    }

    /// 获取可读切片的视图 (不移动指针)
    /// 对应 Bun LinearFifo.readableSlice
    public func readableSlice(): Array<T> {
        return Array<T>(count, { i => buffer[(head + i) % capacity] })
    }

    /// 转为 Owned 切片并重置 - 对应 Bun LinearFifo.toOwnedSlice
    /// 读取所有元素并重置队列
    public func toOwnedSlice(): Array<T> {
        let result = drain()
        clear()
        return result
    }

    /// 推入单个元素 (别名) - 对应 Bun LinearFifo.push
    public func push(item: T): Bool {
        return writeItem(item)
    }

    /// 弹出单个元素 (别名) - 对应 Bun LinearFifo.pop
    /// 对应 LinearFifo.readItem
    public func pop(): ?T {
        return readItem()
    }

    /// 丢弃一个元素 - 对应 Bun LinearFifo.drop
    public func drop(): Bool {
        if (count == 0) {
            return false
        }
        head = (head + 1) % capacity
        count -= 1
        return true
    }

    /// 转为字符串 - 调试用
    public func toString(): String {
        return "LinearFifo(count=${count}, cap=${capacity}, head=${head}, tail=${tail})"
    }
}
