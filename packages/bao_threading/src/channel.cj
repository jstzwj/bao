// bao_threading - Channel 线程安全通道
// 严格翻译自:
//   src/threading/channel.zig - Channel(T, buffer_type)
//
// Bun Channel 实现:
//   mutex: Mutex
//   putters: Condition (生产者等待条件)
//   getters: Condition (消费者等待条件)
//   buffer: LinearFifo(T) (内部环形缓冲区)
//   is_closed: bool
//
//   withBuffer(buffer): 初始化所有字段
//   deinit(): 清理 buffer
//   close(): lock -> is_closed=true -> broadcast putters+getters
//   tryWriteItem(item): write(&[item]) == 1
//   writeItem(item): writeAll(&[item])
//   write(items): writeItems(items, false)
//   tryReadItem(): read(&[1]T) == 1 ? items[0] : null
//   readItem(): readAll(&[1]T); return items[0]
//   read(items): readItems(items, false)
//   writeAll(items): writeItems(items, true) with assert
//   readAll(items): readItems(items, true) with assert
//   writeItems(items, should_block):
//     lock -> 循环: if closed return error
//       buffer.write -> signal getters -> pushed++
//       满且 should_block -> putters.wait
//       满且 !should_block -> break
//     -> unlock
//   readItems(items, should_block):
//     lock -> 循环: if buffer.count==0:
//       if closed return error
//       break :blk null
//       buffer.readItem -> signal putters -> return item
//       null 且 should_block -> getters.wait
//       null 且 !should_block -> break
//     -> unlock
package bao_threading

import std.sync.*
import std.collection.ArrayList
import std.time.*

// ============================================================================
// ChannelError - 通道操作错误
// ============================================================================

/// 通道关闭错误 - 对应 Bun channel.zig 中的 error.Closed
public class ChannelError <: Exception {
    public init(message: String) {
        super(message)
    }
}

// ============================================================================
// Channel<T> - 线程安全通道
// 严格翻译自: src/threading/channel.zig Channel(T, buffer_type)
//
// Bun Channel 是泛型的，支持三种 buffer 类型:
//   .Static  -> initStatic()   固定大小缓冲区
//   .Slice   -> initSlice(buf)  外部缓冲区
//   .Dynamic -> initDynamic(allocator) 动态增长缓冲区
//
// 仓颉使用 ArrayList<T> 实现动态缓冲区，通过 capacity 控制有界/无界
//
// Bun Channel 的核心并发模型:
//   mutex: 保护 buffer 和 is_closed
//   putters: Condition - 缓冲区满时生产者等待
//   getters: Condition - 缓冲区空时消费者等待
//   close(): 设置 is_closed 并广播两个条件
//
// 写入流程 (writeItems):
//   1. lock
//   2. 循环:
//      a. if is_closed -> return error.Closed
//      b. 尝试写入 buffer
//      c. 成功 -> signal getters, pushed++
//      d. 失败 (满):
//         - should_block -> putters.wait (阻塞等待消费者腾出空间)
//         - !should_block -> break (非阻塞返回已写入数)
//   3. unlock
//
// 读取流程 (readItems):
//   1. lock
//   2. 循环:
//      a. if buffer.count == 0:
//         - if is_closed -> return error.Closed
//         - break null
//      b. 从 buffer 读取 -> signal putters -> return item
//      c. null (缓冲区空):
//         - should_block -> getters.wait (阻塞等待生产者写入)
//         - !should_block -> break (非阻塞返回已读取数)
//   3. unlock
// ============================================================================

/// 线程安全通道 - 严格对应 Bun Channel<T>
/// 严格翻译自: src/threading/channel.zig
///
/// 支持有界 (capacity > 0) 和无界 (capacity <= 0) 两种模式
/// 有界通道在缓冲区满时阻塞生产者，缓冲区空时阻塞消费者
/// 无界通道永远不会阻塞生产者
public class Channel<T> {
    /// 内部缓冲区 - 对应 Bun buffer: LinearFifo(T)
    /// 严格翻译自: channel.zig:12 buffer: Buffer
    private var buffer: ArrayList<T>

    /// 是否已关闭 - 对应 Bun is_closed: bool
    /// 严格翻译自: channel.zig:13 is_closed: bool
    private var closed: Bool

    /// 互斥锁 - 对应 Bun Channel.mutex
    /// 严格翻译自: channel.zig:9 mutex: Mutex
    private let mutex: Mutex

    /// 消费者等待条件 - 对应 Bun Channel.getters
    /// 严格翻译自: channel.zig:11 getters: Condition
    /// 缓冲区空时消费者在此等待
    private let getters: Condition

    /// 生产者等待条件 - 对应 Bun Channel.putters
    /// 严格翻译自: channel.zig:10 putters: Condition
    /// 缓冲区满时生产者在此等待
    private let putters: Condition

    /// 缓冲区容量 (<= 0 表示无界)
    /// 对应 Bun 的 buffer_type:
    ///   .Dynamic -> 无界 (capacity = -1)
    ///   .Static/.Slice -> 有界 (capacity = N)
    private let capacity: Int64

    /// 无界通道 - 对应 Bun Channel.initDynamic(allocator)
    /// 严格翻译自: channel.zig:32-34
    ///   Self { mutex, putters, getters, buffer, is_closed=false }
    public init() {
        buffer = ArrayList<T>()
        closed = false
        mutex = Mutex()
        getters = mutex.condition()
        putters = mutex.condition()
        capacity = Int64(-1)
    }

    /// 有界通道 - 对应 Bun Channel.initStatic() / initSlice(buf)
    /// 严格翻译自: channel.zig:24-30 静态/切片缓冲区
    public init(capacity: Int64) {
        buffer = ArrayList<T>()
        closed = false
        mutex = Mutex()
        getters = mutex.condition()
        putters = mutex.condition()
        this.capacity = capacity
    }

    /// 关闭通道 - 对应 Bun Channel.close()
    /// 严格翻译自: channel.zig:51-61
    ///
    /// Bun 实现:
    ///   self.mutex.lock()
    ///   defer self.mutex.unlock()
    ///   if (self.is_closed) return
    ///   self.is_closed = true
    ///   self.putters.broadcast()
    ///   self.getters.broadcast()
    public func close(): Unit {
        synchronized(mutex) {
            // 严格对应 Bun: if (self.is_closed) return
            if (closed) {
                return
            }
            // 严格对应 Bun: self.is_closed = true
            closed = true
            // 严格对应 Bun: self.putters.broadcast()
            // 严格对应 Bun: self.getters.broadcast()
            putters.notifyAll()
            getters.notifyAll()
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        synchronized(mutex) {
            return closed
        }
    }

    // ===== 写入操作 =====

    /// 尝试写入一个元素 (非阻塞) - 对应 Bun Channel.tryWriteItem(item)
    /// 严格翻译自: channel.zig:63-65
    ///
    /// Bun 实现:
    ///   const wrote = try self.write(&[1]T{item})
    ///   return wrote == 1
    ///
    /// 返回 true 表示写入成功，false 表示缓冲区满或已关闭
    public func trySend(value: T): Bool {
        synchronized(mutex) {
            return writeItemsInternal([value], false) == Int64(1)
        }
    }

    /// 阻塞写入一个元素 - 对应 Bun Channel.writeItem(item)
    /// 严格翻译自: channel.zig:68-70
    ///
    /// Bun 实现:
    ///   return self.writeAll(&[1]T{item})
    ///
    /// 如果通道已关闭，返回 false
    /// 如果缓冲区满，阻塞等待
    public func send(value: T): Bool {
        synchronized(mutex) {
            return writeItemsInternal([value], true) == Int64(1)
        }
    }

    /// 批量写入 - 对应 Bun Channel.write(items)
    /// 严格翻译自: channel.zig:72-74
    ///   return self.writeItems(items, false)
    ///
    /// 非阻塞，返回实际写入的数量
    public func write(items: Array<T>): Int64 {
        synchronized(mutex) {
            return writeItemsInternal(items, false)
        }
    }

    /// 阻塞批量写入所有元素 - 对应 Bun Channel.writeAll(items)
    /// 严格翻译自: channel.zig:93-95
    ///
    /// Bun 实现:
    ///   bun.assert((try self.writeItems(items, true)) == items.len)
    ///
    /// 阻塞直到所有元素写入完成
    public func writeAll(items: Array<T>): Unit {
        synchronized(mutex) {
            writeItemsInternal(items, true)
        }
    }

    // ===== 读取操作 =====

    /// 尝试读取一个元素 (非阻塞) - 对应 Bun Channel.tryReadItem()
    /// 严格翻译自: channel.zig:76-81
    ///
    /// Bun 实现:
    ///   var items: [1]T = undefined
    ///   if ((try self.read(&items)) != 1) return null
    ///   return items[0]
    ///
    /// 返回 None 如果缓冲区空或已关闭
    public func tryReceive(): ?T {
        synchronized(mutex) {
            let result = readItemsInternal(1, false)
            match (result) {
                case Some(arr) =>
                    if (arr.size > Int64(0)) {
                        return Some(arr[0])
                    }
                    return None
                case None => return None
            }
        }
    }

    /// 阻塞读取一个元素 - 对应 Bun Channel.readItem()
    /// 严格翻译自: channel.zig:83-87
    ///
    /// Bun 实现:
    ///   var items: [1]T = undefined
    ///   try self.readAll(&items)
    ///   return items[0]
    ///
    /// 阻塞直到有元素可读
    /// 通道关闭且缓冲区空时返回 None
    public func receive(): ?T {
        synchronized(mutex) {
            let result = readItemsInternal(1, true)
            match (result) {
                case Some(arr) =>
                    if (arr.size > Int64(0)) {
                        return Some(arr[0])
                    }
                    return None
                case None => return None
            }
        }
    }

    /// 批量读取 - 对应 Bun Channel.read(items)
    /// 严格翻译自: channel.zig:89-91
    ///   return self.readItems(items, false)
    ///
    /// 非阻塞，返回实际读取的数量
    public func read(count: Int64): ArrayList<T> {
        synchronized(mutex) {
            match (readItemsInternal(count, false)) {
                case Some(arr) => return arr
                case None => return ArrayList<T>()
            }
        }
    }

    /// 阻塞批量读取指定数量 - 对应 Bun Channel.readAll(items)
    /// 严格翻译自: channel.zig:97-99
    ///
    /// Bun 实现:
    ///   bun.assert((try self.readItems(items, true)) == items.len)
    public func readAll(count: Int64): ArrayList<T> {
        synchronized(mutex) {
            match (readItemsInternal(count, true)) {
                case Some(arr) => return arr
                case None => return ArrayList<T>()
            }
        }
    }

    /// 缓冲区大小
    public func len(): Int64 {
        synchronized(mutex) {
            return buffer.size
        }
    }

    /// 缓冲区是否为空
    public func isEmpty(): Bool {
        synchronized(mutex) {
            return buffer.size == Int64(0)
        }
    }

    // ===== 内部实现 =====

    /// 写入元素内部实现 - 对应 Bun writeItems
    /// 严格翻译自: channel.zig:101-131
    ///
    /// Bun 实现:
    ///   self.mutex.lock()
    ///   defer self.mutex.unlock()
    ///   var pushed: usize = 0
    ///   while (pushed < items.len) {
    ///       const did_push = blk: {
    ///           if (self.is_closed) return error.Closed
    ///           self.buffer.write(items) catch |err| {
    ///               if (buffer_type == .Dynamic) return err
    ///               break :blk false
    ///           }
    ///           self.getters.signal()
    ///           break :blk true
    ///       }
    ///       if (did_push) { pushed += 1 }
    ///       else if (should_block) { self.putters.wait(&self.mutex) }
    ///       else { break }
    ///   }
    ///   return pushed
    private func writeItemsInternal(items: Array<T>, shouldBlock: Bool): Int64 {
        var pushed = Int64(0)
        while (pushed < items.size) {
            // 严格对应 Bun: if (self.is_closed) return error.Closed
            if (closed) {
                return pushed
            }
            // 严格对应 Bun: self.buffer.write(items)
            // 检查缓冲区是否有空间
            if (capacity <= Int64(0) || buffer.size < capacity) {
                buffer.add(items[pushed])
                pushed += Int64(1)
                // 严格对应 Bun: self.getters.signal()
                getters.notify()
            } else if (shouldBlock) {
                // 严格对应 Bun: self.putters.wait(&self.mutex)
                // 缓冲区满且需要阻塞，等待消费者读取
                putters.wait()
            } else {
                // 严格对应 Bun: break (非阻塞，缓冲区满)
                break
            }
        }
        return pushed
    }

    /// 读取元素内部实现 - 对应 Bun readItems
    /// 严格翻译自: channel.zig:133-164
    ///
    /// Bun 实现:
    ///   self.mutex.lock()
    ///   defer self.mutex.unlock()
    ///   var popped: usize = 0
    ///   while (popped < items.len) {
    ///       const new_item = blk: {
    ///           if (self.buffer.count == 0) {
    ///               if (self.is_closed) return error.Closed
    ///               break :blk null
    ///           }
    ///           const item = self.buffer.readItem()
    ///           self.putters.signal()
    ///           break :blk item
    ///       }
    ///       if (new_item) |item| { items[popped] = item; popped += 1 }
    ///       else if (should_block) { self.getters.wait(&self.mutex) }
    ///       else { break }
    ///   }
    ///   return popped
    private func readItemsInternal(count: Int64, shouldBlock: Bool): ?ArrayList<T> {
        var result = ArrayList<T>()
        while (result.size < count) {
            // 严格对应 Bun: if (self.buffer.count == 0)
            if (buffer.size == Int64(0)) {
                // 严格对应 Bun: if (self.is_closed) return error.Closed
                if (closed) {
                    if (result.size > Int64(0)) {
                        return result
                    }
                    return None
                }
                // 缓冲区空
                if (shouldBlock) {
                    // 严格对应 Bun: self.getters.wait(&self.mutex)
                    getters.wait()
                } else {
                    // 严格对应 Bun: break (非阻塞，缓冲区空)
                    break
                }
            } else {
                // 严格对应 Bun: const item = self.buffer.readItem()
                let item = buffer.remove(at: Int64(0))
                result.add(item)
                // 严格对应 Bun: self.putters.signal()
                putters.notify()
            }
        }
        if (result.size == Int64(0)) {
            return None
        }
        return result
    }
}
