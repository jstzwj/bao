// bao_threading - UnboundedQueue 无界队列
// 严格翻译自:
//   src/threading/unbounded_queue.zig - UnboundedQueue(T, next_field)
//
// Bun UnboundedQueue 是侵入式无界 MPSC (多生产者单消费者) 队列:
//   back: Atomic(?*T) align(queue_padding_length) - 队尾 (生产者写入)
//   front: Atomic(?*T) align(queue_padding_length) - 队首 (消费者读取)
//
//   push(item):
//     setNext(last, null) // 新节点的 next 设为 null
//     if back.swap(last):  // 原子交换 back
//       old_back.next = first  // 将新节点链接到链表
//     else:
//       front.store(first)  // 队列从空变为非空
//
//   pushBatch(first, last):
//     setNext(last, null)
//     if back.swap(last):
//       old_back.next = first
//     else:
//       front.store(first)
//
//   pop():
//     first = front.load()
//     if first == null: return null
//     next = atomicLoadNext(first)
//     CAS(front, first, next)
//     if next == null:
//       // first 是唯一元素，需要清除 back
//       if CAS(back, first, null): return first
//       // 另一个线程在 CAS back 之前 push 了新元素
//       // 等待 push 设置 first.next
//       new_first = spinWait(atomicLoadNext(first))
//       front.store(new_first)
//     return first
//
//   popBatch():
//     first = front.swap(null)
//     if first == null: return empty batch
//     last = back.swap(null)
//     count = 1
//     遍历 first 到 last，计数
//     return batch(front=first, last=last, count)
//
//   isEmpty(): back.load() == null
//
// Batch:
//   front, last, count
//   Iterator: next() 从 front 遍历 count 个
//
// 仓颉没有侵入式链表和 lock-free CAS 指针，使用 Mutex + ArrayList 实现等价语义
package bao_threading

import std.sync.*
import std.collection.ArrayList

// ============================================================================
// QueueBatch<T> - 批量弹出结果
// 严格翻译自: src/threading/unbounded_queue.zig:59-79 Batch
//
// Bun Batch:
//   pub const Batch = struct {
//       front: ?*T = null,
//       last: ?*T = null,
//       count: usize = 0,
//       pub fn iterator(self: Batch) Iterator
//   }
//   pub const Iterator = struct {
//       batch: Batch,
//       pub fn next(self: *Iterator) ?*T
//   }
// ============================================================================

/// 批量弹出结果 - 对应 Bun UnboundedQueue.Batch
/// 严格翻译自: unbounded_queue.zig:59-79
///
/// 包含从队列中弹出的所有元素:
///   front: 第一个元素
///   last: 最后一个元素
///   count: 元素数量
public class QueueBatch<T> {
    /// 元素列表 - 对应 Bun Batch.front/last 链表遍历
    /// Bun 使用侵入式链表 (front, last, count)
    /// 仓颉使用 ArrayList 存储所有元素
    public var items: ArrayList<T>

    public init() {
        items = ArrayList<T>()
    }

    /// 元素数量 - 对应 Bun Batch.count
    public func count(): Int64 {
        return items.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return items.size == Int64(0)
    }

    /// 获取迭代器 - 对应 Bun Batch.iterator()
    /// 严格翻译自: unbounded_queue.zig:76-78
    public func iterator(): QueueBatchIterator<T> {
        return QueueBatchIterator<T>(items)
    }
}

/// 批量弹出结果迭代器 - 对应 Bun Batch.Iterator
/// 严格翻译自: unbounded_queue.zig:60-70
///
/// Bun Iterator:
///   pub fn next(self: *Iterator) ?*T {
///       if (self.batch.count == 0) return null
///       const front = self.batch.front orelse unreachable
///       self.batch.front = getNext(front)
///       self.batch.count -= 1
///       return front
///   }
public class QueueBatchIterator<T> {
    private let items: ArrayList<T>
    private var index: Int64

    public init(items: ArrayList<T>) {
        this.items = items
        this.index = Int64(0)
    }

    /// 下一个元素 - 对应 Bun Iterator.next()
    /// 严格翻译自: unbounded_queue.zig:63-69
    public func next(): ?T {
        if (index >= items.size) {
            return None
        }
        let item = items[index]
        index += Int64(1)
        return Some(item)
    }

    /// 是否还有更多元素
    public func hasNext(): Bool {
        return index < items.size
    }
}

// ============================================================================
// UnboundedQueue<T> - 无界 MPSC 队列
// 严格翻译自: src/threading/unbounded_queue.zig:8-169
//
// Bun 的 UnboundedQueue 是侵入式 lock-free 队列:
//   back: Atomic(?*T)  - 生产者写入队尾
//   front: Atomic(?*T) - 消费者读取队首
//
//   push(item): swap back, 设置 old_back.next
//   pushBatch(first, last): 同 push 但处理一批
//   pop(): CAS front, 处理唯一元素时还需要 CAS back
//   popBatch(): swap front+back 为 null, 遍历链表
//   isEmpty(): back.load() == null
//
// 关键 lock-free 操作:
//   push: back.swap(last) 原子地将新节点链接到队尾
//   pop: front.cmpxchgWeak(first, next) 原子地从队首取元素
//   popBatch: front.swap(null) + back.swap(null) 原子地取走所有元素
//
// 仓颉没有 lock-free 原子指针操作 (CAS 指针)，使用 Mutex 保护实现等价语义
// ============================================================================

/// 无界 MPSC 队列 - 对应 Bun UnboundedQueue<T>
/// 严格翻译自: src/threading/unbounded_queue.zig
///
/// Bun 使用侵入式链表 + 原子操作实现 lock-free MPSC 队列
/// 仓颉使用 Mutex + ArrayList 实现等价的线程安全队列
///
/// MPSC 语义:
///   - 多个生产者可以安全地并发 push
///   - 只有一个消费者可以 pop (单消费者语义)
///   - 使用 Mutex 保证多生产者安全
public class UnboundedQueue<T> {
    /// 内部存储 - 对应 Bun back/front 原子指针构成的链表
    /// Bun: back: Atomic(?*T), front: Atomic(?*T)
    /// 仓颉: Mutex + ArrayList
    private var items: ArrayList<T>

    /// 互斥锁 - 保护并发 push 操作
    /// Bun 中 push 是 lock-free 的 (原子 swap)
    /// 仓颉中使用 Mutex 实现等价的线程安全
    private let mutex: Mutex

    public init() {
        items = ArrayList<T>()
        mutex = Mutex()
    }

    /// 推入单个元素 - 对应 Bun UnboundedQueue.push(item)
    /// 严格翻译自: unbounded_queue.zig:86-88
    ///
    /// Bun 实现:
    ///   self.pushBatch(item, item)
    ///
    /// pushBatch:
    ///   setNext(last, null)
    ///   if (self.back.swap(last, .acq_rel)) |old_back| {
    ///       atomicStoreNext(old_back, first, .release)
    ///   } else {
    ///       self.front.store(first, .release)
    ///   }
    public func push(item: T): Unit {
        synchronized(mutex) {
            // 严格对应 Bun: setNext(last, null)
            // 严格对应 Bun: back.swap(last) + old_back.next = first
            items.add(item)
        }
    }

    /// 批量推入 - 对应 Bun UnboundedQueue.pushBatch(first, last)
    /// 严格翻译自: unbounded_queue.zig:90-104
    ///
    /// Bun 实现:
    ///   setNext(last, null)
    ///   // assert: last reachable from first
    ///   if (self.back.swap(last, .acq_rel)) |old_back| {
    ///       atomicStoreNext(old_back, first, .release)
    ///   } else {
    ///       self.front.store(first, .release)
    ///   }
    public func pushBatch(newItems: Array<T>): Unit {
        if (newItems.size == Int64(0)) {
            return
        }
        synchronized(mutex) {
            for (item in newItems) {
                items.add(item)
            }
        }
    }

    /// 批量推入 (ArrayList 版本)
    public func pushBatch(newItems: ArrayList<T>): Unit {
        if (newItems.size == Int64(0)) {
            return
        }
        synchronized(mutex) {
            for (item in newItems) {
                items.add(item)
            }
        }
    }

    /// 弹出一个元素 - 对应 Bun UnboundedQueue.pop()
    /// 严格翻译自: unbounded_queue.zig:106-138
    ///
    /// Bun 实现:
    ///   var first = self.front.load(.acquire) orelse return null
    ///   const next_item = while (true) {
    ///       const next_ptr = atomicLoadNext(first, .acquire)
    ///       const maybe_first = self.front.cmpxchgWeak(
    ///           first, next_ptr, .release, .acquire
    ///       ) orelse break next_ptr
    ///       first = maybe_first orelse return null
    ///   }
    ///   if (next_item != null) return first
    ///   // first 是唯一元素，需要清除 back
    ///   if (self.back.cmpxchgStrong(first, null, .monotonic, .monotonic)) |back| {
    ///       assert(back != null)
    ///   } else {
    ///       return first
    ///   }
    ///   // 另一个线程在 CAS back 之前 push 了新元素
    ///   // 等待 push 设置 first.next
    ///   const new_first = while (true) : (spinLoopHint()) {
    ///       break atomicLoadNext(first, .acquire) orelse continue
    ///   }
    ///   self.front.store(new_first, .release)
    ///   return first
    ///
    /// 返回 None 如果队列为空
    public func pop(): ?T {
        synchronized(mutex) {
            if (items.size == Int64(0)) {
                return None
            }
            // 严格对应 Bun: front.CAS(first, next) -> return first
            return Some(items.remove(at: 0))
        }
    }

    /// 批量弹出所有元素 - 对应 Bun UnboundedQueue.popBatch()
    /// 严格翻译自: unbounded_queue.zig:140-163
    ///
    /// Bun 实现:
    ///   var batch: Batch = .{}
    ///   const first = self.front.swap(null, .acquire) orelse return batch
    ///   batch.count += 1
    ///   const last = self.back.swap(null, .monotonic).?
    ///   var next_item = first
    ///   while (next_item != last) : (batch.count += 1) {
    ///       next_item = while (true) : (spinLoopHint()) {
    ///           break atomicLoadNext(next_item, .acquire) orelse continue
    ///       }
    ///   }
    ///   batch.front = first
    ///   batch.last = last
    ///   return batch
    public func popBatch(): QueueBatch<T> {
        let batch = QueueBatch<T>()
        synchronized(mutex) {
            // 严格对应 Bun: front.swap(null) + back.swap(null)
            // 一次性取走所有元素
            for (item in items) {
                batch.items.add(item)
            }
            items.clear()
        }
        return batch
    }

    /// 队列是否为空 - 对应 Bun UnboundedQueue.isEmpty()
    /// 严格翻译自: unbounded_queue.zig:165-167
    ///
    /// Bun 实现:
    ///   return self.back.load(.acquire) == null
    public func isEmpty(): Bool {
        synchronized(mutex) {
            return items.size == Int64(0)
        }
    }

    /// 队列大小 (近似值)
    /// Bun 中没有直接提供 len，但可以通过遍历计算
    /// 仓颉中直接返回 ArrayList 大小
    public func len(): Int64 {
        synchronized(mutex) {
            return items.size
        }
    }

    /// 查看队首元素 (不移除)
    public func peek(): ?T {
        synchronized(mutex) {
            if (items.size == Int64(0)) {
                return None
            }
            return Some(items[Int64(0)])
        }
    }

    /// 清空队列
    public func clear(): Unit {
        synchronized(mutex) {
            items.clear()
        }
    }
}
