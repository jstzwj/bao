// bao_threading - Semaphore 信号量
// 严格翻译自:
//   src/threading/Semaphore.rs - Semaphore (Mutex + Condition + permits)
//   Zig std.Thread.Semaphore (wait/post)
//
// Bun 的 Semaphore 实现 (Semaphore.rs):
//   mutex: Mutex
//   cond: Condition
//   permits: usize (被 mutex 保护)
//
//   new(): permits = 0
//   with_permits(n): permits = n
//   wait(): lock -> while(permits==0) cond.wait -> permits-- -> if(permits>0) cond.signal -> unlock
//   post(): lock -> permits++ -> cond.signal -> unlock
//
// 仓颉使用 std.sync.Semaphore + Mutex/Condition 实现等价语义
package bao_threading

import std.sync.*
import std.time.Duration

// ============================================================================
// Semaphore - 计数信号量
// 严格翻译自: src/threading/Semaphore.rs
//
// Bun/Zig Semaphore 使用 Mutex + Condition + atomic permits:
//   wait(): 获取一个许可 (阻塞直到有可用许可)
//   post(): 释放一个许可并唤醒一个等待者
//
// Bun Semaphore.wait 实现细节:
//   1. mutex.lock()
//   2. while (*permits == 0) cond.wait(&mutex)
//   3. *permits -= 1
//   4. if (*permits > 0) cond.signal()  // 唤醒其他等待者
//   5. mutex.unlock()
//
// Bun Semaphore.post 实现细节:
//   1. mutex.lock()
//   2. *permits += 1
//   3. cond.signal()
//   4. mutex.unlock()
//
// 仓颉 std.sync.Semaphore 原生提供 acquire/release
// 本实现严格对应 Bun 的 Mutex + Condition + permits 模式
// ============================================================================

/// 计数信号量 - 严格对应 Bun Semaphore (Semaphore.rs)
///
/// Bun 的 Semaphore 使用 Mutex + Condition + usize permits:
///   - wait(): 阻塞获取一个许可
///   - post(): 释放一个许可并唤醒一个等待者
///
/// 关键语义:
///   - wait() 中获取许可后如果还有剩余许可，会 signal 唤醒下一个等待者
///   - 这实现了 "连锁唤醒" 模式，避免 post 一次只能唤醒一个线程
///
/// 仓颉使用 Mutex + Condition 实现等价语义
public class Semaphore {
    /// 互斥锁 - 对应 Bun Semaphore.mutex
    private let mutex: std.sync.Mutex
    /// 条件变量 - 对应 Bun Semaphore.cond
    private let cond: Condition
    /// 许可数 - 对应 Bun Semaphore.permits (UnsafeCell<usize>)
    /// 严格翻译: permits 被 mutex 保护
    private var permits: Int64

    /// 初始化信号量，零许可 - 对应 Bun Semaphore::new()
    /// 严格翻译自: Semaphore.rs:33-35
    ///   Self::with_permits(0)
    public init() {
        mutex = std.sync.Mutex()
        cond = mutex.condition()
        permits = 0
    }

    /// 初始化信号量，指定许可数 - 对应 Bun Semaphore::with_permits(permits)
    /// 严格翻译自: Semaphore.rs:38-44
    ///   Self { mutex: Mutex::new(), cond: Condition::new(), permits: UnsafeCell::new(permits) }
    public init(permits: Int64) {
        mutex = std.sync.Mutex()
        cond = mutex.condition()
        this.permits = permits
    }

    /// 阻塞获取一个许可 - 对应 Bun Semaphore.wait()
    /// 严格翻译自: Semaphore.rs:47-61
    ///
    /// Bun 实现:
    ///   self.mutex.lock()
    ///   while (*self.permits.get() == 0) {
    ///       self.cond.wait(&self.mutex)
    ///   }
    ///   *self.permits.get() -= 1
    ///   if (*self.permits.get() > 0) {
    ///       self.cond.signal()
    ///   }
    ///   self.mutex.unlock()
    public func acquire(): Unit {
        synchronized(mutex) {
            // 严格对应 Bun: while (permits == 0) cond.wait(&mutex)
            while (permits == 0) {
                cond.wait()
            }
            // 严格对应 Bun: *permits -= 1
            permits -= 1
            // 严格对应 Bun: if (*permits > 0) cond.signal()
            // 如果还有许可，主动唤醒下一个等待者 (连锁唤醒)
            if (permits > 0) {
                cond.notify()
            }
        }
    }

    /// 释放一个许可并唤醒一个等待者 - 对应 Bun Semaphore.post()
    /// 严格翻译自: Semaphore.rs:64-71
    ///
    /// Bun 实现:
    ///   self.mutex.lock()
    ///   *self.permits.get() += 1
    ///   self.cond.signal()
    ///   self.mutex.unlock()
    public func release(): Unit {
        synchronized(mutex) {
            // 严格对应 Bun: *permits += 1
            permits += 1
            // 严格对应 Bun: cond.signal()
            cond.notify()
        }
    }

    /// 非阻塞尝试获取 - 对应 Bun 中 tryWait 的语义
    /// 如果 permits > 0，获取一个许可并返回 true
    /// 否则返回 false
    public func tryAcquire(): Bool {
        synchronized(mutex) {
            if (permits == 0) {
                return false
            }
            permits -= 1
            if (permits > 0) {
                cond.notify()
            }
            return true
        }
    }

    /// 带超时的获取许可
    /// 严格翻译自: Bun Semaphore 没有直接提供 timedWait
    ///   但 Zig std.Thread.Semaphore 有 timedWait
    ///   超时返回 false，成功获取返回 true
    public func tryAcquire(timeout: Duration): Bool {
        synchronized(mutex) {
            while (permits == 0) {
                let signaled = cond.wait(timeout: timeout)
                if (!signaled) {
                    return false
                }
            }
            permits -= 1
            if (permits > 0) {
                cond.notify()
            }
            return true
        }
    }

    /// 获取当前许可数
    /// 注意: 读取时未加锁，仅用于调试/监控
    public func availablePermits(): Int64 {
        synchronized(mutex) {
            return permits
        }
    }
}
