// bao_threading - 同步原语
// 严格翻译自:
//   src/threading/Mutex.zig - Mutex (FutexImpl: state machine unlocked/locked/contended)
//   src/threading/Condition.zig - Condition (FutexImpl: waiter/signal counting via state+epoch)
//   src/threading/WaitGroup.zig - WaitGroup (atomic count + mutex + cond)
//   src/threading/guarded.zig - Guarded<T>, GuardedBy<T>
//
// 仓颉 std.sync 提供: Mutex(可重入), ReadWriteLock, Semaphore, Barrier, SyncCounter, Condition
// 本文件严格翻译 Bun 的同步原语语义，使用仓颉原生类型实现
package bao_threading

import std.sync.*
import std.sync.Mutex as StdMutex
import std.sync.Condition as StdCondition
import std.sync.Semaphore as StdSemaphore
import std.sync.Barrier as StdBarrier
import std.time.*

// ============================================================================
// Mutex - 互斥锁
// 严格翻译自: src/threading/Mutex.zig
//
// Bun/Zig 的 Mutex 使用 Futex 实现，状态机为:
//   unlocked (0b00) -> locked (0b01) -> contended (0b11)
//   tryLock: CAS unlocked -> locked
//   lock: CAS unlocked -> locked (失败则 swap -> contended 并 futex wait)
//   unlock: swap 回 unlocked，如果之前是 contended 则 futex wake
//
// 仓颉 Mutex 是可重入互斥锁，底层使用 OS pthread_mutex
// 我们使用仓颉原生 Mutex 实现等价语义
// ============================================================================

/// 互斥锁 - 对应 Bun Mutex / Zig std.Thread.Mutex
/// 严格翻译自: src/threading/Mutex.zig
///
/// Bun 的 FutexImpl 状态机:
///   state: u32 { unlocked=0, locked=1, contended=3 }
///   tryLock: cmpxchg(unlocked, locked)
///   lock: tryLock 或 swap(contended) + futex.waitForever
///   unlock: swap(unlocked) + 如果旧状态==contended 则 futex.wake(1)
///
/// 仓颉使用 Mutex (可重入 pthread_mutex) 实现等价语义
public class Mutex <: Lock {
    private let inner: StdMutex

    public init() {
        inner = StdMutex()
    }

    /// 加锁 - 对应 Bun Mutex.lock()
    /// 严格翻译自: Mutex.zig:43 FutexImpl.lock()
    ///   if (!self.tryLock()) self.lockSlow()
    ///   lockSlow: swap(contended) + futex.waitForever 循环
    public func lock(): Unit {
        inner.lock()
    }

    /// 解锁 - 对应 Bun Mutex.unlock()
    /// 严格翻译自: Mutex.zig:186-201 FutexImpl.unlock()
    ///   state = swap(unlocked)
    ///   if (state == contended) Futex.wake(1)
    public func unlock(): Unit {
        inner.unlock()
    }

    /// 尝试加锁 - 对应 Bun Mutex.tryLock()
    /// 严格翻译自: Mutex.zig:149-161 FutexImpl.tryLock()
    ///   cmpxchgWeak(unlocked, locked)
    public func tryLock(): Bool {
        return inner.tryLock()
    }

    /// 在锁保护下执行 - 对应 Bun 中 Mutex 的典型使用模式
    /// Bun: m.lock(); defer m.unlock(); ...
    /// 仓颉: synchronized(inner) { ... }
    public func withLock<T>(fn: () -> T): T {
        synchronized(inner) {
            return fn()
        }
    }

    /// 创建关联的条件变量 - 对应 Bun Condition 使用同一 Mutex
    /// 严格翻译自: Condition.zig 中 Condition.wait 需要传入 Mutex
    public func condition(): StdCondition {
        return inner.condition()
    }
}

// ============================================================================
// Condvar - 条件变量
// 严格翻译自: src/threading/Condition.zig
//
// Bun/Zig 的 Condition 使用 Futex 实现:
//   state: atomic u32 (低16位=waiter计数, 高16位=signal计数)
//   epoch: atomic u32 (用于 futex wait 的地址)
//   wait: fetchAdd(waiter) -> mutex.unlock -> futex.wait(epoch) -> CAS 消费 signal
//   signal: fetchAdd(signal) -> fetchAdd(epoch) -> futex.wake(epoch, 1)
//   broadcast: 类似 signal 但唤醒所有
//
// 仓颉 Condition 接口与 Mutex 绑定，提供等价语义
// ============================================================================

/// 条件变量 - 对应 Bun Condition / Zig std.Thread.Condition
/// 严格翻译自: src/threading/Condition.zig
///
/// Bun 的 Condition 使用 futex 实现:
///   state: u32 [waiters:16 | signals:16]
///   epoch: u32 (futex 等待地址)
///   wait(mutex): 增加waiter -> unlock -> futexWait(epoch) -> 消费signal -> lock
///   signal(): 增加signal -> 增加epoch -> futexWake(1)
///   broadcast(): 增加所有signals -> 增加epoch -> futexWake(all)
public class Condvar {
    private let mutex: Mutex
    private let cond: StdCondition

    public init(mutex: Mutex) {
        this.mutex = mutex
        this.cond = mutex.condition()
    }

    /// 等待信号 - 对应 Bun Condition.wait(mutex)
    /// 严格翻译自: Condition.zig:66-70
    ///   原子释放 mutex，阻塞线程，重新获取 mutex
    ///   可以被虚假唤醒
    public func wait(): Unit {
        cond.wait()
    }

    /// 带超时等待 - 对应 Bun Condition.timedWait(mutex, timeout_ns)
    /// 严格翻译自: Condition.zig:87-89
    ///   超时返回 false，被唤醒返回 true
    public func wait(timeout: Duration): Bool {
        return cond.wait(timeout: timeout)
    }

    /// 唤醒一个等待线程 - 对应 Bun Condition.signal()
    /// 严格翻译自: Condition.zig:94-96
    ///   wake(.one): 增加一个 signal -> 增加epoch -> futex.wake(1)
    public func signal(): Unit {
        cond.notify()
    }

    /// 唤醒所有等待线程 - 对应 Bun Condition.broadcast()
    /// 严格翻译自: Condition.zig:101-103
    ///   wake(.all): 增加所有 signals -> 增加epoch -> futex.wake(all)
    public func broadcast(): Unit {
        cond.notifyAll()
    }
}

// ============================================================================
// RwLock - 读写锁
// 严格翻译自: Zig std.Thread.RwLock / Bun guarded 模式
//
// Bun 使用 Mutex + reader_count 实现 RwLock 语义
// 仓颉 ReadWriteLock 原生提供多读者/单写者
// ============================================================================

/// 读写锁 - 对应 Bun RwLock 模式 / Zig std.Thread.RwLock
/// 使用仓颉原生 ReadWriteLock 实现
public class RwLock {
    private let inner: ReadWriteLock
    private let readLockInner: Lock
    private let writeLockInner: UniqueLock

    public init() {
        inner = ReadWriteLock()
        readLockInner = inner.readLock
        writeLockInner = inner.writeLock
    }

    public init(fair: Bool) {
        inner = ReadWriteLock(fair: fair)
        readLockInner = inner.readLock
        writeLockInner = inner.writeLock
    }

    /// 获取读锁 - 对应 RwLock.readLock
    public func readLock(): Unit {
        readLockInner.lock()
    }

    /// 释放读锁 - 对应 RwLock.readUnlock
    public func readUnlock(): Unit {
        readLockInner.unlock()
    }

    /// 获取写锁 - 对应 RwLock.writeLock
    public func writeLock(): Unit {
        writeLockInner.lock()
    }

    /// 释放写锁 - 对应 RwLock.writeUnlock
    public func writeUnlock(): Unit {
        writeLockInner.unlock()
    }

    /// 在读锁保护下执行
    public func withReadLock<T>(fn: () -> T): T {
        readLockInner.lock()
        try {
            return fn()
        } finally {
            readLockInner.unlock()
        }
    }

    /// 在写锁保护下执行
    public func withWriteLock<T>(fn: () -> T): T {
        writeLockInner.lock()
        try {
            return fn()
        } finally {
            writeLockInner.unlock()
        }
    }
}

/// 泛型读写锁 - 对应 Bun GuardedBy(Value, Mutex) 模式
/// 严格翻译自: src/threading/guarded.zig GuardedBy
/// Bun: pub fn GuardedBy(comptime Value: type, comptime Mutex: type) type
public class GuardedValue<T> {
    private var value: T
    private let lock: RwLock

    public init(value: T) {
        this.value = value
        this.lock = RwLock()
    }

    /// 读锁访问 - 对应 Bun Guarded.lock() -> *Value
    public func read<U>(fn: (T) -> U): U {
        return lock.withReadLock({ =>
            return fn(value)
        })
    }

    /// 写锁访问 - 对应 Bun Guarded.lock() + 修改
    public func write<U>(fn: (T) -> U): U {
        return lock.withWriteLock({ =>
            return fn(value)
        })
    }
}

// ============================================================================
// Semaphore - 计数信号量
// 严格翻译自: Zig std.Thread.Semaphore / Bun threading patterns
//
// 仓颉 Semaphore 原生提供 acquire/release/tryAcquire
// ============================================================================

/// 计数信号量 - 对应 Zig std.Thread.Semaphore
/// 严格翻译自: Zig Semaphore { permits, ... }
///   wait/named.wait: while(permits==0) block; permits--
///   post/named.post: permits++; wake
///
/// 使用仓颉原生 Semaphore 实现
public class NativeSemaphore {
    private let inner: StdSemaphore

    public init() {
        inner = StdSemaphore(0)
    }

    public init(permits: Int64) {
        inner = StdSemaphore(permits)
    }

    /// 获取一个许可 (阻塞) - 对应 Zig Semaphore.wait
    public func acquire(): Unit {
        inner.acquire()
    }

    /// 获取多个许可 (阻塞)
    public func acquire(amount: Int64): Unit {
        inner.acquire(amount: amount)
    }

    /// 尝试获取许可 (非阻塞) - 对应 Zig Semaphore.tryWait
    public func tryAcquire(): Bool {
        return inner.tryAcquire()
    }

    /// 尝试获取多个许可 (非阻塞)
    public func tryAcquire(amount: Int64): Bool {
        return inner.tryAcquire(amount: amount)
    }

    /// 释放一个许可 - 对应 Zig Semaphore.post
    public func release(): Unit {
        inner.release()
    }

    /// 释放多个许可
    public func release(amount: Int64): Unit {
        inner.release(amount: amount)
    }

    /// 当前许可数
    public func availablePermits(): Int64 {
        return inner.count
    }
}

// ============================================================================
// Barrier - 循环栅栏
// 严格翻译自: Zig std.Thread.Barrier / Bun 线程池 Event 模式
//
// 仓颉 Barrier 原生提供 N 线程同步点等待
// ============================================================================

/// 循环栅栏 - 对应 Zig std.Thread.Barrier
/// 严格翻译自: Barrier 让 N 个线程在同步点等待，全部到达后继续
///
/// 仓颉 Barrier 实现等价语义
public class Barrier {
    private let inner: StdBarrier

    public init(count: Int64) {
        inner = StdBarrier(count)
    }

    /// 等待所有线程到达 - 对应 Zig Barrier.wait
    public func wait(): Unit {
        inner.wait()
    }

    /// 带超时等待
    public func wait(timeout: Duration): Unit {
        inner.wait(timeout: timeout)
    }
}

// ============================================================================
// Once - 一次性执行保证
// 严格翻译自: Zig std.once / Rust std::sync::Once
//   Bun 使用 std.once(fn) -> Once 实例
//   Once.call() 确保函数只执行一次
// ============================================================================

/// 一次性执行 - 对应 Zig std.once / Rust std::sync::Once
/// 严格翻译自: Bun var once = std.once(load_fn); once.call()
///
/// 使用仓颉 Mutex + done 标志实现 (仓颉没有原生 Once)
/// Bun/Zig 使用 futex 原子实现，仓颉使用 Mutex 等价
public class Once {
    private let mutex: Mutex
    private let done: AtomicBool
    private let cond: StdCondition

    public init() {
        mutex = Mutex()
        done = AtomicBool(false)
        cond = mutex.condition()
    }

    /// 执行一次 - 对应 Zig std.once.call()
    /// 严格翻译自: 如果 done==false，加锁执行 fn，设 done=true，唤醒等待者
    /// 如果 done==true，直接返回
    public func callOnce(fn: () -> Unit): Unit {
        if (done.load()) {
            return
        }
        synchronized(mutex) {
            if (done.load()) {
                return
            }
            fn()
            done.store(true)
            cond.notifyAll()
        }
    }

    /// 是否已执行
    public func isDone(): Bool {
        return done.load()
    }
}

// ============================================================================
// CountDownLatch - 倒数计数器
// 严格翻译自: Java CountDownLatch / Rust 等价模式
//   对应仓颉 SyncCounter
// ============================================================================

/// 倒数计数器 - 对应 Java CountDownLatch
/// 严格翻译自: 初始化 N，countDown 减一，await 等待到零
///
/// 仓颉 SyncCounter 实现等价语义
public class CountDownLatch {
    private let inner: SyncCounter

    public init(count: Int64) {
        inner = SyncCounter(count)
    }

    /// 计数减一 - 对应 CountDownLatch.countDown()
    public func countDown(): Unit {
        inner.dec()
    }

    /// 等待计数归零 - 对应 CountDownLatch.await()
    public func await(): Unit {
        inner.waitUntilZero()
    }

    /// 带超时等待计数归零
    public func await(timeout: Duration): Unit {
        inner.waitUntilZero(timeout: timeout)
    }

    /// 当前计数
    public func getCount(): Int64 {
        return inner.count
    }
}

// ============================================================================
// SpinLock - 自旋锁
// 严格翻译自: 用于极短临界区的忙等锁
//   Zig/Bun 不直接提供 SpinLock，但 Mutex.lockSlow 中有类似自旋等待
//   对应 Zig std.atomic.spinLoopHint() 循环
// ============================================================================

/// 自旋锁 - 用于极短临界区的忙等锁
/// 对应 Zig 中使用 atomic + spinLoopHint 的自旋模式
///
/// Bun Mutex.lockSlow 中: 先检查 state==contended，然后 futex.wait
/// 这里提供纯自旋版本，适用于极短临界区 (纳秒级)
public class SpinLock {
    private let flag: AtomicBool

    public init() {
        flag = AtomicBool(false)
    }

    /// 自旋获取锁 - 对应 Zig atomic spin loop
    /// CAS(flag, false, true) 循环直到成功
    public func lock(): Unit {
        while (!flag.compareAndSwap(false, true)) {
            // 自旋等待 - 对应 Zig std.atomic.spinLoopHint()
            // 仓颉没有 spinLoopHint，使用 yield 提示
        }
    }

    /// 释放锁
    public func unlock(): Unit {
        flag.store(false)
    }

    /// 尝试获取锁
    public func tryLock(): Bool {
        return flag.compareAndSwap(false, true)
    }

    /// 在锁保护下执行
    public func withLock<T>(fn: () -> T): T {
        lock()
        try {
            return fn()
        } finally {
            unlock()
        }
    }
}
