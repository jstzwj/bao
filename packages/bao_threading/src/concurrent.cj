// bao_threading - 并发数据结构
// 严格翻译自:
//   src/threading/unbounded_queue.zig - UnboundedQueue (lock-free MPSC)
//   src/threading/channel.zig - Channel (mutex + buffer + cond)
//   src/threading/WaitGroup.zig - WaitGroup (atomic count + mutex + cond)
//   src/threading/guarded.zig - Guarded<T>, GuardedBy<T>
//   src/event_loop/ConcurrentTask.zig - ConcurrentTask + Queue
//
// Bun 的 UnboundedQueue 使用 lock-free 原子操作:
//   back: Atomic(?*T) - 队尾 (生产者写入)
//   front: Atomic(?*T) - 队首 (消费者读取)
//   push: swap back + store old_back.next
//   pop: load front + CAS front to next
//
// 仓颉没有 lock-free 原语 (无直接 CAS 指针)，使用 Mutex + ArrayList 实现等价语义
package bao_threading

import std.sync.*
import std.collection.{ArrayList, HashMap}
import std.time.*

// ============================================================================
// ConcurrentQueue<T> - 线程安全队列
// 严格翻译自: src/threading/unbounded_queue.zig UnboundedQueue
//
// Bun 的 UnboundedQueue 是侵入式链表:
//   back: Atomic(?*T) - 生产者写入队尾
//   front: Atomic(?*T) - 消费者读取队首
//   push(item): swap(back, item) -> store old_back.next = item
//   pop(): load(front) -> CAS(front, next) -> 如果唯一元素还需 CAS(back, null)
//   isEmpty(): back.load() == null
//
// 仓颉使用 Mutex + ArrayList 实现线程安全队列
// ============================================================================

/// 线程安全队列 - 对应 Bun UnboundedQueue<T>
/// 严格翻译自: unbounded_queue.zig
///
/// Bun 使用 lock-free 原子链表实现 MPSC 队列
/// 仓颉使用 Mutex + Condition 实现等价的线程安全队列
public class ConcurrentQueue<T> {
    /// 内部存储
    private var items: ArrayList<T>
    /// 互斥锁
    private let mutex: Mutex
    /// 条件变量 - 用于 take() 阻塞等待
    private let notEmpty: Condition

    public init() {
        items = ArrayList<T>()
        mutex = Mutex()
        notEmpty = mutex.condition()
    }

    /// 添加元素到队尾 - 对应 Bun UnboundedQueue.push(item)
    /// 严格翻译自: unbounded_queue.zig:86-88 push
    ///   setNext(last, null)
    ///   if (back.swap(last)) old_back.next = first
    ///   else front.store(first)
    public func push(item: T): Unit {
        synchronized(mutex) {
            items.add(item)
            notEmpty.notify()
        }
    }

    /// 批量推入 - 对应 Bun UnboundedQueue.pushBatch(first, last)
    /// 严格翻译自: unbounded_queue.zig:90-104
    public func pushBatch(items: Array<T>): Unit {
        if (items.size == 0) {
            return
        }
        synchronized(mutex) {
            for (item in items) {
                this.items.add(item)
            }
            notEmpty.notifyAll()
        }
    }

    /// 从队头移除并返回元素 - 对应 Bun UnboundedQueue.pop()
    /// 严格翻译自: unbounded_queue.zig:106-138
    ///   load(front) -> CAS(front, next) -> 如果唯一元素 CAS(back, null)
    ///   返回 null 如果队列为空
    public func pop(): ?T {
        synchronized(mutex) {
            if (items.size == 0) {
                return None
            }
            return Some(items.remove(at: 0))
        }
    }

    /// 批量弹出所有元素 - 对应 Bun UnboundedQueue.popBatch()
    /// 严格翻译自: unbounded_queue.zig:140-163
    ///   swap(front, null) -> swap(back, null) -> 遍历链表
    public func popBatch(): ArrayList<T> {
        synchronized(mutex) {
            let result = ArrayList<T>()
            for (item in items) {
                result.add(item)
            }
            items.clear()
            return result
        }
    }

    /// 阻塞式移除 - 等待直到有元素
    /// 对应 Bun Channel.readItem 的阻塞语义
    public func take(): T {
        synchronized(mutex) {
            while (items.size == 0) {
                notEmpty.wait()
            }
            return items.remove(at: 0)
        }
    }

    /// 带超时的阻塞移除
    public func poll(timeout: Duration): ?T {
        synchronized(mutex) {
            if (items.size == 0) {
                let signaled = notEmpty.wait(timeout: timeout)
                if (items.size == 0) {
                    return None
                }
            }
            return Some(items.remove(at: 0))
        }
    }

    /// 查看队头元素 (不移除) - 对应 Bun peek
    public func peek(): ?T {
        synchronized(mutex) {
            if (items.size == 0) {
                return None
            }
            return Some(items[0])
        }
    }

    /// 队列是否为空 - 对应 Bun UnboundedQueue.isEmpty()
    /// 严格翻译自: unbounded_queue.zig:165-167
    ///   back.load(.acquire) == null
    public func isEmpty(): Bool {
        synchronized(mutex) {
            return items.size == 0
        }
    }

    /// 队列大小
    public func len(): Int64 {
        synchronized(mutex) {
            return items.size
        }
    }

    /// 清空队列
    public func clear(): Unit {
        synchronized(mutex) {
            items.clear()
        }
    }
}

// ============================================================================
// ConcurrentMap<K,V> - 线程安全哈希表
// 严格翻译自: Bun 中使用 Mutex + HashMap 的模式
//   guarded.zig Guarded(HashMap) 模式
//
// Bun 使用 Mutex 保护 HashMap 访问:
//   var map = Guarded(HashMap).init(.{})
//   map.lock(); defer map.unlock(); map.value.put(key, val)
// ============================================================================

/// 线程安全哈希表 - 对应 Bun Guarded<HashMap> 模式
/// 严格翻译自: guarded.zig 中 Mutex + value 的使用模式
public class ConcurrentMap<K, V> where K <: Hashable & Equatable<K> {
    private var map: HashMap<K, V>
    private let mutex: Mutex

    public init() {
        map = HashMap<K, V>()
        mutex = Mutex()
    }

    /// 插入 - 对应 HashMap.put
    public func put(key: K, value: V): Unit {
        synchronized(mutex) {
            map.add(key, value)
        }
    }

    /// 获取 - 对应 HashMap.get
    public func get(key: K): ?V {
        synchronized(mutex) {
            return map.get(key)
        }
    }

    /// 删除 - 对应 HashMap.remove
    public func remove(key: K): ?V {
        synchronized(mutex) {
            return map.remove(key)
        }
    }

    /// 是否包含
    public func contains(key: K): Bool {
        synchronized(mutex) {
            return map.contains(key)
        }
    }

    /// 大小
    public func len(): Int64 {
        synchronized(mutex) {
            return map.size
        }
    }

    /// 是否为空
    public func isEmpty(): Bool {
        synchronized(mutex) {
            return map.isEmpty()
        }
    }

    /// 清空
    public func clear(): Unit {
        synchronized(mutex) {
            map.clear()
        }
    }

    /// 原子更新 - 对应 Bun 中 lock -> read/modify/write -> unlock
    /// 对应 Guarded.lock() -> 修改 -> Guarded.unlock()
    public func withLock<T>(fn: (HashMap<K, V>) -> T): T {
        synchronized(mutex) {
            return fn(map)
        }
    }

    /// 原子 getOrPut - 如果 key 不存在则插入默认值
    public func getOrPut(key: K, defaultValue: () -> V): V {
        synchronized(mutex) {
            match (map.get(key)) {
                case Some(v) => return v
                case None => ()
            }
            let v = defaultValue()
            map.add(key, v)
            return v
        }
    }

    /// 原子 computeIfAbsent - 类似 Java ConcurrentHashMap
    public func computeIfAbsent(key: K, fn: () -> V): V {
        return getOrPut(key, fn)
    }
}

// ============================================================================
// Channel<T> - 线程安全通道
// 严格翻译自: src/threading/channel.zig Channel(T, buffer_type)
//
// Bun 的 Channel:
//   mutex: Mutex
//   putters: Condition (生产者等待)
//   getters: Condition (消费者等待)
//   buffer: LinearFifo(T) (内部缓冲区)
//   is_closed: bool
//
//   write(items): lock -> 写入buffer (满则等putters) -> notify getters -> unlock
//   read(items): lock -> 从buffer读 (空则等getters) -> notify putters -> unlock
//   close(): lock -> is_closed=true -> broadcast putters+getters -> unlock
// ============================================================================

/// 通道关闭错误
public class ConcurrentChannelError <: Exception {
    public init(message: String) {
        super(message)
    }
}

/// 线程安全通道 - 对应 Bun Channel<T>
/// 严格翻译自: src/threading/channel.zig
///
/// Bun Channel 使用 Mutex + 两个 Condition + LinearFifo 实现:
///   putters: 生产者等待条件 (缓冲区满时阻塞)
///   getters: 消费者等待条件 (缓冲区空时阻塞)
///   buffer: 内部缓冲区
///   is_closed: 关闭标志
public class ConcurrentChannel<T> {
    /// 内部缓冲区
    private var buffer: ArrayList<T>
    /// 是否已关闭
    private var closed: Bool
    /// 互斥锁 - 对应 Bun Channel.mutex
    private let mutex: Mutex
    /// 消费者等待条件 - 对应 Bun Channel.getters
    private let getters: Condition
    /// 生产者等待条件 - 对应 Bun Channel.putters
    private let putters: Condition
    /// 缓冲区容量 (-1 表示无界)
    private let capacity: Int64

    /// 无界通道 - 对应 Bun Channel.initDynamic(allocator)
    public init() {
        buffer = ArrayList<T>()
        closed = false
        mutex = Mutex()
        getters = mutex.condition()
        putters = mutex.condition()
        capacity = -1
    }

    /// 有界通道
    public init(capacity: Int64) {
        buffer = ArrayList<T>()
        closed = false
        mutex = Mutex()
        getters = mutex.condition()
        putters = mutex.condition()
        this.capacity = capacity
    }

    /// 写入一个元素 - 对应 Bun Channel.writeItem(item)
    /// 严格翻译自: channel.zig:68-69 writeItem
    ///   writeAll(&[1]T{item})
    public func send(value: T): Bool {
        synchronized(mutex) {
            // 严格翻译自: channel.zig:108 if (self.is_closed) return error.Closed
            if (closed) {
                return false
            }
            // 检查缓冲区是否已满
            if (capacity > 0 && buffer.size >= capacity) {
                // 严格翻译自: channel.zig:123 should_block -> putters.wait
                return false
            }
            // 写入缓冲区
            buffer.add(value)
            // 严格翻译自: channel.zig:117 self.getters.signal()
            getters.notify()
            return true
        }
    }

    /// 阻塞写入 - 对应 Bun Channel.writeAll
    /// 缓冲区满时阻塞等待
    public func blockingSend(value: T): Unit {
        synchronized(mutex) {
            if (closed) {
                return
            }
            while (capacity > 0 && buffer.size >= capacity) {
                // 对应 Bun putters.wait(&self.mutex)
                putters.wait()
                if (closed) {
                    return
                }
            }
            buffer.add(value)
            getters.notify()
        }
    }

    /// 读取一个元素 - 对应 Bun Channel.readItem()
    /// 严格翻译自: channel.zig:83-87 readItem
    ///   readAll(&items)
    public func receive(): ?T {
        synchronized(mutex) {
            // 严格翻译自: channel.zig:142 if (self.buffer.count == 0)
            if (buffer.size == 0) {
                if (closed) {
                    return None
                }
                return None
            }
            let item = buffer.remove(at: 0)
            // 严格翻译自: channel.zig:149 self.putters.signal()
            putters.notify()
            return Some(item)
        }
    }

    /// 阻塞读取 - 对应 Bun Channel.readItem 阻塞语义
    /// 严格翻译自: channel.zig:83 readItem 会阻塞直到有数据
    public func blockingReceive(): ?T {
        synchronized(mutex) {
            while (buffer.size == 0) {
                if (closed) {
                    return None
                }
                // 严格翻译自: channel.zig:157 getters.wait
                getters.wait()
            }
            let item = buffer.remove(at: 0)
            putters.notify()
            return Some(item)
        }
    }

    /// 尝试读取 - 对应 Bun Channel.tryReadItem
    public func tryReceive(): ?T {
        synchronized(mutex) {
            if (buffer.size == 0) {
                return None
            }
            let item = buffer.remove(at: 0)
            putters.notify()
            return Some(item)
        }
    }

    /// 关闭通道 - 对应 Bun Channel.close()
    /// 严格翻译自: channel.zig:51-61
    ///   if (is_closed) return
    ///   is_closed = true
    ///   putters.broadcast()
    ///   getters.broadcast()
    public func close(): Unit {
        synchronized(mutex) {
            if (closed) {
                return
            }
            closed = true
            // 严格翻译自: channel.zig:59-60 broadcast both conditions
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

    /// 缓冲区大小
    public func len(): Int64 {
        synchronized(mutex) {
            return buffer.size
        }
    }

    /// 缓冲区是否为空
    public func isEmpty(): Bool {
        synchronized(mutex) {
            return buffer.size == 0
        }
    }
}

// ============================================================================
// WaitGroup - 等待组
// 严格翻译自: src/threading/WaitGroup.zig
//
// Bun 的 WaitGroup:
//   raw_count: Atomic(usize) = .init(0)
//   mutex: Mutex = .{}
//   cond: Condition = .{}
//
//   add(n): raw_count.fetchAdd(n, .monotonic)
//   addUnsynchronized(n): raw_count.raw += n (无原子操作)
//   finish(): raw_count.fetchSub(1, .acq_rel)
//     if (old_count > 1) return  // 还有未完成的任务
//     // 最后一个任务完成:
//     mutex.lock(); mutex.unlock()  // 确保等待者进入 cond.wait
//     cond.signal()
//   wait(): mutex.lock(); while (count > 0) cond.wait(&mutex); mutex.unlock()
// ============================================================================

/// 等待组 - 对应 Bun WaitGroup
/// 严格翻译自: src/threading/WaitGroup.zig
///
/// Bun WaitGroup 使用 atomic usize 计数器 + Mutex + Condition:
///   add(n): 原子增加计数
///   addUnsynchronized(n): 非同步增加 (已知没有并发)
///   finish(): 原子减少计数，最后一个完成时 signal
///   wait(): 等待计数归零
public class ConcurrentWaitGroup {
    /// 原子计数器 - 对应 Bun raw_count: Atomic(usize)
    private let count: AtomicInt64
    /// 互斥锁 - 对应 Bun WaitGroup.mutex
    private let mutex: Mutex
    /// 条件变量 - 对应 Bun WaitGroup.cond
    private let cond: Condition

    public init() {
        count = AtomicInt64(0)
        mutex = Mutex()
        cond = mutex.condition()
    }

    /// 初始化指定计数
    public init(initialCount: Int64) {
        count = AtomicInt64(initialCount)
        mutex = Mutex()
        cond = mutex.condition()
    }

    /// 增加计数 - 对应 Bun WaitGroup.add(n)
    /// 严格翻译自: WaitGroup.zig:29-34
    ///   self.raw_count.fetchAdd(n, .monotonic)
    public func add(n: Int64): Unit {
        count.fetchAdd(n)
    }

    /// 增加计数 (非同步) - 对应 Bun WaitGroup.addUnsynchronized(n)
    /// 严格翻译自: WaitGroup.zig:25-27
    ///   self.raw_count.raw += n (直接修改，无原子操作)
    ///   用于调用者已知没有并发访问时
    public func addUnsynchronized(n: Int64): Unit {
        count.fetchAdd(n)
    }

    /// 增加一个 - 对应 Bun WaitGroup.addOne()
    /// 严格翻译自: WaitGroup.zig:36-38
    public func addOne(): Unit {
        add(1)
    }

    /// 完成一个 - 对应 Bun WaitGroup.finish()
    /// 严格翻译自: WaitGroup.zig:40-53
    ///   old_count = raw_count.fetchSub(1, .acq_rel)
    ///   if (old_count > 1) return  // 还有未完成的
    ///   // 这是最后一个任务
    ///   mutex.lock(); mutex.unlock()  // 确保等待者已进入 cond.wait
    ///   cond.signal()
    public func finish(): Unit {
        let oldCount = count.fetchSub(1)
        if (oldCount > 1) {
            return
        }
        // 最后一个任务完成 - 严格对应 Bun 的 mutex.lock+unlock+signal 模式
        synchronized(mutex) {
            cond.notify()
        }
    }

    /// 等待所有完成 - 对应 Bun WaitGroup.wait()
    /// 严格翻译自: WaitGroup.zig:55-61
    ///   mutex.lock()
    ///   while (raw_count.load(.acquire) > 0) cond.wait(&mutex)
    ///   mutex.unlock()
    public func wait(): Unit {
        synchronized(mutex) {
            while (count.load() > 0) {
                cond.wait()
            }
        }
    }

    /// 当前计数
    public func getCount(): Int64 {
        return count.load()
    }
}
