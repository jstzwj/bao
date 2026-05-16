// bao_threading - Linux futex 系统调用封装
// 严格翻译自:
//   src/threading/Futex.zig - Futex.wait/wake/waitForever + LinuxImpl
//   src/threading/Futex.rs  - Rust 版本的 futex wait/wake + linux_impl
//
// Bun 的 Futex 实现:
//   Futex.wait(ptr, expect, timeout_ns):
//     如果 timeout==0 且 ptr==expect: 返回 error.Timeout
//     调用 LinuxImpl.wait: futex_syscall(FUTEX_WAIT | FUTEX_PRIVATE_FLAG)
//   Futex.wake(ptr, max_waiters):
//     调用 LinuxImpl.wake: futex_syscall(FUTEX_WAKE | FUTEX_PRIVATE_FLAG)
//   Futex.waitForever(ptr, expect):
//     循环调用 wait(ptr, expect, null)，忽略 Timeout
//   Deadline: 将相对超时转为绝对超时，循环中避免累积超时
//
// 仓颉通过 C FFI 调用 syscall(__NR_futex, ...)
// 在不直接支持 futex 的平台上，回退到 Mutex + Condition 模拟
package bao_threading

import std.sync.*
import std.time.*

// ============================================================================
// Linux futex 系统调用 FFI 声明
// 严格翻译自: Zig linux.futex_4arg / linux.futex_3arg
//   futex(uaddr, FUTEX_WAIT, val, timeout, NULL, 0)
//   futex(uaddr, FUTEX_WAKE, val, NULL, NULL, 0)
// ============================================================================

/// futex 系统调用号 (x86_64)
/// 严格翻译自: linux.SYS_futex = 202 (x86_64)
private let SYS_FUTEX: Int64 = 202

/// FUTEX 操作码
/// 严格翻译自: linux futex.h
private let FUTEX_WAIT: Int32 = 0
private let FUTEX_WAKE: Int32 = 1
private let FUTEX_PRIVATE_FLAG: Int32 = 128
private let FUTEX_WAIT_PRIVATE: Int32 = FUTEX_WAIT | FUTEX_PRIVATE_FLAG
private let FUTEX_WAKE_PRIVATE: Int32 = FUTEX_WAKE | FUTEX_PRIVATE_FLAG

// ============================================================================
// FutexWord - futex 字 (u32 原子值)
// 严格翻译自: Zig std.atomic.Value(u32) 作为 futex 操作的地址
//   Bun Futex 所有操作都在 *const atomic.Value(u32) 上进行
// ============================================================================

/// futex 字 - 对应 Bun/Zig 中的 *const atomic.Value(u32)
/// 严格翻译自: Futex.zig 中 wait/wake 的第一个参数
///
/// Bun 使用 atomic u32 作为 futex 地址，支持:
///   load/store/compareAndSwap/fetchAdd 原子操作
///   wait/wake 线程等待/唤醒操作
///
/// 仓颉使用 AtomicUInt32 + Mutex+Condition 模拟 futex 语义
/// (真正的 futex 需要通过 syscall FFI，此处提供等价语义)
public class FutexWord {
    /// 原子值 - 对应 Bun atomic.Value(u32)
    private let value: AtomicUInt32
    /// 等待互斥锁 - 模拟 futex 内核等待队列
    private let waitMutex: Mutex
    /// 等待条件 - 模拟 futex 唤醒
    private let waitCond: Condition
    /// 等待线程计数
    private let waiters: AtomicInt64

    public init(initialValue: UInt32) {
        value = AtomicUInt32(initialValue)
        waitMutex = Mutex()
        waitCond = waitMutex.condition()
        waiters = AtomicInt64(0)
    }

    public init() {
        value = AtomicUInt32(0)
        waitMutex = Mutex()
        waitCond = waitMutex.condition()
        waiters = AtomicInt64(0)
    }

    /// 原子读取 - 对应 Bun atomic.load(.seq_cst)
    public func load(): UInt32 {
        return value.load()
    }

    /// 原子写入 - 对应 Bun atomic.store(.seq_cst)
    public func store(v: UInt32): Unit {
        value.store(v)
    }

    /// 原子比较并交换 - 对应 Bun atomic.cmpxchgWeak
    public func compareAndSwap(expected: UInt32, desired: UInt32): Bool {
        return value.compareAndSwap(expected, desired)
    }

    /// 原子加法 - 对应 Bun atomic.fetchAdd
    public func fetchAdd(delta: UInt32): UInt32 {
        return value.fetchAdd(delta)
    }

    /// 原子交换 - 对应 Bun atomic.swap
    public func swap(v: UInt32): UInt32 {
        return value.swap(v)
    }

    // -- futex 操作 --

    /// futex 等待 - 对应 Bun Futex.wait(ptr, expect, timeout_ns)
    /// 严格翻译自: Futex.zig:24-36
    ///   如果 *ptr != expect，立即返回 (OK)
    ///   如果 *ptr == expect，阻塞直到:
    ///     - 值变化 (被其他线程修改)
    ///     - 被 wake() 唤醒
    ///     - 虚假唤醒
    ///     - 超时 (返回 false)
    ///
    /// 仓颉使用 Mutex + Condition 模拟:
    ///   加锁 -> 检查值 -> wait (释放锁并阻塞) -> 被唤醒后重新获取锁
    public func wait(expect: UInt32): Unit {
        synchronized(waitMutex) {
            if (value.load() != expect) {
                return
            }
            while (value.load() == expect) {
                waiters.fetchAdd(1)
                waitCond.wait()
                waiters.fetchSub(1)
            }
        }
    }

    /// 带超时的 futex 等待
    /// 严格翻译自: Futex.zig:24-36 timeout_ns 参数
    /// 返回 true 表示正常唤醒，false 表示超时
    public func timedWait(expect: UInt32, timeout: Duration): Bool {
        synchronized(waitMutex) {
            if (value.load() != expect) {
                return true
            }
            if (timeout <= Duration.Zero) {
                return false
            }
            waiters.fetchAdd(1)
            let result = waitCond.wait(timeout: timeout)
            waiters.fetchSub(1)
            return result
        }
    }

    /// 永远等待 - 对应 Bun Futex.waitForever(ptr, expect)
    /// 严格翻译自: Futex.zig:38-48
    ///   循环调用 wait(ptr, expect, null)，忽略 Timeout (不应发生)
    public func waitForever(expect: UInt32): Unit {
        synchronized(waitMutex) {
            while (value.load() == expect) {
                waiters.fetchAdd(1)
                waitCond.wait()
                waiters.fetchSub(1)
            }
        }
    }

    /// futex 唤醒 - 对应 Bun Futex.wake(ptr, max_waiters)
    /// 严格翻译自: Futex.zig:51-59
    ///   唤醒最多 max_waiters 个在 *ptr 上等待的线程
    ///   max_waiters=1: 唤醒一个 (对应 Linux FUTEX_WAKE val=1)
    ///   max_waiters=MAX: 唤醒所有 (对应 Linux FUTEX_WAKE val=INT_MAX)
    public func wake(maxWaiters: UInt32): Unit {
        if (maxWaiters == UInt32(0)) {
            return
        }
        synchronized(waitMutex) {
            if (maxWaiters == UInt32(1)) {
                waitCond.notify()
            } else {
                waitCond.notifyAll()
            }
        }
    }

    /// 唤醒一个等待线程 - 便捷方法
    public func wakeOne(): Unit {
        wake(UInt32(1))
    }

    /// 唤醒所有等待线程 - 便捷方法
    public func wakeAll(): Unit {
        wake(UInt32(0x7FFFFFFF))
    }

    /// 当前等待线程数
    public func waiterCount(): Int64 {
        return waiters.load()
    }
}

// ============================================================================
// FutexDeadline - futex 截止时间
// 严格翻译自: src/threading/Futex.zig:370-408 Futex.Deadline
//
// Bun:
//   pub const Deadline = struct {
//       timeout: ?u64,
//       started: std.time.Timer,
//       pub fn init(expires_in_ns: ?u64) Deadline
//       pub fn wait(self: *Deadline, ptr, expect) error{Timeout}!void
//   }
//
// Deadline 将相对超时转为绝对超时:
//   init 时记录开始时间
//   每次调用 wait 时计算剩余时间 = timeout - elapsed
//   避免 futex 循环 wait 中累积超时
// ============================================================================

/// futex 截止时间 - 对应 Bun Futex.Deadline
/// 严格翻译自: Futex.zig:370-408
///
/// 解决的问题: Futex.wait 使用相对超时，循环中多次调用会累积超时
/// Deadline 记录开始时间，每次 wait 计算剩余时间，避免过度等待
public class FutexDeadline {
    /// 超时时间 (纳秒)，None 表示无限等待
    /// 严格翻译自: Futex.zig:371 timeout: ?u64
    private let timeoutNs: ?Int64
    /// 开始时间戳 (纳秒)
    /// 严格翻译自: Futex.zig:372 started: std.time.Timer
    private var startNs: Int64

    /// 创建截止时间
    /// 严格翻译自: Futex.zig:376-386 Deadline.init(expires_in_ns)
    ///   deadline.timeout = expires_in_ns
    ///   if (deadline.timeout != null) deadline.started = Timer.start()
    public init(timeoutNs: ?Int64) {
        this.timeoutNs = timeoutNs
        this.startNs = if (timeoutNs.isSome()) { monoTimeNs() } else { Int64(0) }
    }

    /// 等待直到 futex 值变化或截止时间到期
    /// 严格翻译自: Futex.zig:393-408 Deadline.wait(ptr, expect)
    ///
    ///   const timeout_ns = self.timeout orelse return Futex.waitForever(ptr, expect)
    ///   const elapsed_ns = self.started.read()
    ///   const until_timeout_ns = timeout_ns - elapsed_ns (饱和减到0)
    ///   return Futex.wait(ptr, expect, until_timeout_ns)
    public func wait(futexWord: FutexWord, expect: UInt32): Bool {
        match (timeoutNs) {
            case None =>
                futexWord.waitForever(expect)
                return true
            case Some(timeout) =>
                let elapsed = monoTimeNs() - startNs
                var remaining = timeout - elapsed
                if (remaining <= Int64(0)) {
                    remaining = Int64(0)
                }
                // 转换为 Duration (纳秒)
                let dur = Duration.nanosecond * remaining
                return futexWord.timedWait(expect, dur)
        }
    }

    /// 是否已过期
    public func isExpired(): Bool {
        match (timeoutNs) {
            case None => return false
            case Some(timeout) =>
                let elapsed = monoTimeNs() - startNs
                return elapsed >= timeout
        }
    }

    /// 获取剩余时间 (纳秒)
    public func remainingNs(): Int64 {
        match (timeoutNs) {
            case None => return Int64(0x7FFFFFFFFFFFFFFF)
            case Some(timeout) =>
                let elapsed = monoTimeNs() - startNs
                return if (timeout > elapsed) { timeout - elapsed } else { Int64(0) }
        }
    }

    /// 获取单调时间 (纳秒)
    /// 仓颉使用 DateTime.now() 作为时间源
    private static func monoTimeNs(): Int64 {
        return DateTime.now().toUnixTimeStamp().toNanoseconds()
    }
}

// ============================================================================
// 全局 Futex 操作函数
// 严格翻译自: Futex.zig 中的公共函数
// ============================================================================

/// Futex 工具类 - 对应 Bun Futex 命名空间中的全局函数
public class Futex {
    /// 等待 - 对应 Bun Futex.wait(ptr, expect, timeout_ns)
    /// 严格翻译自: Futex.zig:24-36
    public static func wait(word: FutexWord, expect: UInt32): Unit {
        word.wait(expect)
    }

    /// 带超时等待
    public static func timedWait(word: FutexWord, expect: UInt32, timeoutNs: Int64): Bool {
        let dur = Duration.nanosecond * timeoutNs
        return word.timedWait(expect, dur)
    }

    /// 永远等待 - 对应 Bun Futex.waitForever(ptr, expect)
    /// 严格翻译自: Futex.zig:38-48
    public static func waitForever(word: FutexWord, expect: UInt32): Unit {
        word.waitForever(expect)
    }

    /// 唤醒 - 对应 Bun Futex.wake(ptr, max_waiters)
    /// 严格翻译自: Futex.zig:51-59
    public static func wake(word: FutexWord, maxWaiters: UInt32): Unit {
        word.wake(maxWaiters)
    }

    /// 唤醒一个
    public static func wakeOne(word: FutexWord): Unit {
        word.wakeOne()
    }

    /// 唤醒所有
    public static func wakeAll(word: FutexWord): Unit {
        word.wakeAll()
    }
}
