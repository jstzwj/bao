// bao_threading - WaitGroup 等待组
// 严格翻译自:
//   src/threading/WaitGroup.zig - WaitGroup (atomic count + mutex + cond)
//
// Bun WaitGroup 实现:
//   raw_count: Atomic(usize) = .init(0)
//   mutex: Mutex = .{}
//   cond: Condition = .{}
//
//   init(): raw_count = 0
//   initWithCount(count): raw_count = count
//   addUnsynchronized(n): raw_count.raw += n (无原子操作)
//   add(n): raw_count.fetchAdd(n, .monotonic)
//   addOne(): add(1)
//   finish():
//     old_count = raw_count.fetchSub(1, .acq_rel)
//     if (old_count > 1) return  // 还有未完成的
//     // 最后一个:
//     mutex.lock(); mutex.unlock()  // 确保等待者已进入 cond.wait
//     cond.signal()
//   wait():
//     mutex.lock()
//     while (raw_count.load(.acquire) > 0) cond.wait(&mutex)
//     mutex.unlock()
package bao_threading

import std.sync.*

// ============================================================================
// WaitGroup - 等待组
// 严格翻译自: src/threading/WaitGroup.zig
//
// Bun WaitGroup 使用 atomic usize 计数器 + Mutex + Condition:
//   - atomic count: 跟踪未完成任务数
//   - mutex + cond: 等待计数归零
//
// 关键语义:
//   add(n): 原子增加计数 (monotonic ordering)
//   addUnsynchronized(n): 非同步增加 (已知无并发)
//   addOne(): add(1)
//   finish(): 原子减计数 (acq_rel)，最后一个完成时 signal
//     注意: 最后一个 finish 会 lock+unlock mutex 后 signal
//     这是为了确保等待者已进入 cond.wait，避免丢失 signal
//   wait(): mutex 保护下循环等待 count == 0
// ============================================================================

/// 等待组 - 严格对应 Bun WaitGroup
/// 严格翻译自: src/threading/WaitGroup.zig
///
/// 用于等待一组并发任务完成:
///   - add(n) / addOne(): 在任务开始前增加计数
///   - finish(): 每个任务完成时调用 (减少计数)
///   - wait(): 阻塞直到所有任务完成 (计数归零)
///
/// Bun 的 finish 实现有一个关键的同步细节:
///   最后一个 finish 时，会先 lock+unlock mutex 再 signal
///   这确保 wait() 中在读取计数和调用 cond.wait 之间的竞态条件不会丢失 signal
public class WaitGroup {
    /// 原子计数器 - 对应 Bun raw_count: Atomic(usize)
    /// 严格翻译自: WaitGroup.zig:13 raw_count: std.atomic.Value(usize) = .init(0)
    private let count: AtomicInt64

    /// 互斥锁 - 对应 Bun WaitGroup.mutex
    /// 严格翻译自: WaitGroup.zig:14 mutex: Mutex = .{}
    private let mutex: Mutex

    /// 条件变量 - 对应 Bun WaitGroup.cond
    /// 严格翻译自: WaitGroup.zig:15 cond: Condition = .{}
    private let cond: Condition

    /// 默认初始化，计数为 0 - 对应 Bun WaitGroup.init()
    /// 严格翻译自: WaitGroup.zig:17-19
    ///   return .{}
    public init() {
        count = AtomicInt64(Int64(0))
        mutex = Mutex()
        cond = mutex.condition()
    }

    /// 指定初始计数的初始化 - 对应 Bun WaitGroup.initWithCount(count)
    /// 严格翻译自: WaitGroup.zig:21-23
    ///   return .{ .raw_count = .init(count) }
    public init(initialCount: Int64) {
        count = AtomicInt64(initialCount)
        mutex = Mutex()
        cond = mutex.condition()
    }

    /// 非同步增加计数 - 对应 Bun WaitGroup.addUnsynchronized(n)
    /// 严格翻译自: WaitGroup.zig:25-27
    ///
    /// Bun 实现:
    ///   self.raw_count.raw += n
    ///
    /// 直接修改，无原子操作。用于调用者已知没有并发访问时。
    /// 仓颉没有 "raw" 非原子操作，使用 fetchAdd 等价。
    public func addUnsynchronized(n: Int64): Unit {
        count.fetchAdd(n)
    }

    /// 增加计数 - 对应 Bun WaitGroup.add(n)
    /// 严格翻译自: WaitGroup.zig:29-34
    ///
    /// Bun 实现:
    ///   // Not .acquire because we don't need to synchronize with other tasks
    ///   // Not .release because there are no side effects that other threads
    ///   // depend on when they see the *start* of a task
    ///   _ = self.raw_count.fetchAdd(n, .monotonic)
    ///
    /// 使用 monotonic ordering: 只保证原子性，不保证与其他变量的顺序
    public func add(n: Int64): Unit {
        count.fetchAdd(n)
    }

    /// 增加一个 - 对应 Bun WaitGroup.addOne()
    /// 严格翻译自: WaitGroup.zig:36-38
    ///   self.add(1)
    public func addOne(): Unit {
        add(Int64(1))
    }

    /// 完成一个任务 - 对应 Bun WaitGroup.finish()
    /// 严格翻译自: WaitGroup.zig:40-53
    ///
    /// Bun 实现:
    ///   const old_count = self.raw_count.fetchSub(1, .acq_rel)
    ///   if (old_count > 1) return
    ///   // 这是最后一个任务:
    ///   // lock+unlock 确保 wait() 中在读取计数和 cond.wait 之间的线程
    ///   // 已经进入了 cond.wait，不会丢失 signal
    ///   self.mutex.lock()
    ///   self.mutex.unlock()
    ///   self.cond.signal()
    ///
    /// acq_rel ordering:
    ///   acquire: 确保在 finish 之前对共享数据的修改对所有线程可见
    ///   release: 确保后续的 cond.signal 正确同步
    public func finish(): Unit {
        let oldCount = count.fetchSub(Int64(1))
        // 严格对应 Bun: if (old_count > 1) return
        if (oldCount > Int64(1)) {
            return
        }
        // 这是最后一个任务 - 严格对应 Bun 的 lock+unlock+signal 模式
        // lock+unlock 确保 wait() 中已经进入 cond.wait 的线程不会丢失 signal
        synchronized(mutex) {
            cond.notify()
        }
    }

    /// 等待所有任务完成 - 对应 Bun WaitGroup.wait()
    /// 严格翻译自: WaitGroup.zig:55-61
    ///
    /// Bun 实现:
    ///   self.mutex.lock()
    ///   defer self.mutex.unlock()
    ///   while (self.raw_count.load(.acquire) > 0)
    ///       self.cond.wait(&self.mutex)
    ///
    /// acquire ordering: 确保看到 finish 之前的所有修改
    public func wait(): Unit {
        synchronized(mutex) {
            // 严格对应 Bun: while (count > 0) cond.wait
            while (count.load() > Int64(0)) {
                cond.wait()
            }
        }
    }

    /// 带超时等待所有任务完成
    /// Bun WaitGroup 没有直接提供带超时的 wait
    /// 但 Condition 支持 timedWait
    /// 返回 true 表示所有任务完成，false 表示超时
    public func wait(timeout: Duration): Bool {
        synchronized(mutex) {
            while (count.load() > Int64(0)) {
                let signaled = cond.wait(timeout: timeout)
                if (count.load() > Int64(0)) {
                    return false
                }
                if (!signaled) {
                    return count.load() <= Int64(0)
                }
            }
            return true
        }
    }

    /// 当前计数 - 获取未完成任务数
    /// 注意: 读取时未加锁，仅用于调试/监控
    public func getCount(): Int64 {
        return count.load()
    }

    /// 是否所有任务已完成
    public func isDone(): Bool {
        return count.load() <= Int64(0)
    }
}
