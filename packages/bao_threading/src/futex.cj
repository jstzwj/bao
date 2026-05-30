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
// 仓颉通过 C FFI 调用 syscall(__NR_futex, ...) 实现真正的 futex 操作
// 使用 GCC 原子内建函数 (__atomic_load_n, __atomic_store_n 等) 实现原子操作
// 这些内建函数编译为 lock 前缀的 x86 指令，提供硬件级原子性保证
package bao_threading

import std.sync.*
import std.time.*

// ============================================================================
// C FFI 声明 - libc 函数
// 严格翻译自: Zig/C 中使用的 libc 函数
// ============================================================================

/// 纳米级休眠 - 用于超时回退
@C
foreign func nanosleep(req: CPointer<Unit>, rem: CPointer<Unit>): Int32

/// 内存分配 - 用于 futex 字和 timespec 结构
@C
foreign func malloc(size: UIntNative): CPointer<Unit>

/// 内存释放
@C
foreign func free(ptr: CPointer<Unit>): Unit

// ============================================================================
// Linux futex 系统调用 FFI 声明
// 严格翻译自: Zig linux.futex_4arg / linux.futex_3arg
//   futex(uaddr, FUTEX_WAIT, val, timeout, NULL, 0)
//   futex(uaddr, FUTEX_WAKE, val, NULL, NULL, 0)
//
// 实现方式: 通过 syscall() 直接调用 Linux 内核
// 参考: https://man7.org/linux/man-pages/man2/futex.2.html
// ============================================================================

/// syscall 系统调用 - 直接调用 Linux 内核
/// 严格翻译自: Zig linux.futex_4arg / linux.futex_3arg
/// 使用 6 参数版本以支持 futex 的完整参数集
@C
foreign func syscall(number: Int64, arg1: Int64, arg2: Int64, arg3: Int64, arg4: Int64, arg5: Int64): Int64

/// C 辅助函数 — 用于 futex 系统调用 (避免 CPointer->Int64 转换问题)
@C
foreign func bao_futex_wait(uaddr: CPointer<Unit>, expect: Int32): Int64
@C
foreign func bao_futex_timed_wait(uaddr: CPointer<Unit>, expect: Int32, sec: Int64, nsec: Int64): Int64
@C
foreign func bao_futex_wake(uaddr: CPointer<Unit>, count: Int32): Int64

/// GCC 原子内建函数 - 提供硬件级原子操作
/// 这些是编译器内建函数，编译为 lock 前缀的 x86 指令
/// 用于在原始内存上实现原子 load/store/CAS/exchange 操作
///
/// 参考: https://gcc.gnu.org/onlinedocs/gcc/_005f_005fatomic-Builtins.html
/// 参考: https://gcc.gnu.org/onlinedocs/gcc/Atomic-Builtins.html

/// 原子加载 - 对应 Zig atomic.load / Rust AtomicU32.load
/// 编译为: mov (带 lock 前缀或纯 mov 取决于对齐)
@C
foreign func __atomic_load_n(ptr: CPointer<Unit>, memmodel: Int32): UInt32

/// 原子存储 - 对应 Zig atomic.store / Rust AtomicU32.store
/// 编译为: mov (带 lock 前缀或纯 mov 取决于对齐)
@C
foreign func __atomic_store_n(ptr: CPointer<Unit>, val: UInt32, memmodel: Int32): Unit

/// 原子交换 - 对应 Zig atomic.swap / Rust AtomicU32.swap
/// 编译为: xchg 指令 (天然原子)
@C
foreign func __atomic_exchange_n(ptr: CPointer<Unit>, val: UInt32, memmodel: Int32): UInt32

/// 原子比较并交换 (布尔版本) - 对应 Zig atomic.cmpxchgWeak / Rust compare_exchange
/// 编译为: lock cmpxchg 指令
/// 返回 true 表示交换成功，false 表示失败 (不修改 expected)
/// 注意: 这使用 __sync 版本而非 __atomic 版本，因为 __sync 版本不修改 expected 参数
@C
foreign func __sync_bool_compare_and_swap(ptr: CPointer<Unit>, expected: UInt32, desired: UInt32): Bool

/// 原子加法并返回旧值 - 对应 Zig atomic.fetchAdd / Rust AtomicU32.fetch_add
/// 编译为: lock xadd 指令
@C
foreign func __atomic_fetch_add(ptr: CPointer<Unit>, val: UInt32, memmodel: Int32): UInt32

// ============================================================================
// futex 系统调用常量
// 严格翻译自: linux futex.h / Zig linux.FutexCmd / Rust linux::FutexCmd
// ============================================================================

/// futex 系统调用号 (x86_64)
/// 严格翻译自: linux.SYS_futex = 202 (x86_64)
/// 参考: https://man7.org/linux/man-pages/man2/futex.2.html
private let SYS_FUTEX: Int64 = 202

/// FUTEX 操作码 - 对应 Zig linux.FutexCmd / Rust linux::FutexCmd
/// 严格翻译自: linux futex.h
private let FUTEX_WAIT: Int32 = 0
private let FUTEX_WAKE: Int32 = 1
private let FUTEX_PRIVATE_FLAG: Int32 = 128
private let FUTEX_WAIT_PRIVATE: Int32 = FUTEX_WAIT | FUTEX_PRIVATE_FLAG
private let FUTEX_WAKE_PRIVATE: Int32 = FUTEX_WAKE | FUTEX_PRIVATE_FLAG

/// GCC 原子操作内存模型常量
/// 严格翻译自: GCC __atomic builtins documentation
/// 参考: https://gcc.gnu.org/onlinedocs/gcc/_005f_005fatomic-Builtins.html
private let __ATOMIC_RELAXED: Int32 = 0
private let __ATOMIC_ACQUIRE: Int32 = 2
private let __ATOMIC_RELEASE: Int32 = 3
private let __ATOMIC_SEQ_CST: Int32 = 5

// ============================================================================
// FutexWord - futex 字 (u32 原子值)
// 严格翻译自: Zig std.atomic.Value(u32) 作为 futex 操作的地址
//   Bun Futex 所有操作都在 *const atomic.Value(u32) 上进行
//
// 实现方式:
//   使用 malloc 分配 4 字节原始内存存储 u32 值
//   使用 GCC 原子内建函数实现原子操作 (编译为 lock 前缀 x86 指令)
//   通过 syscall() 直接调用 Linux futex 系统调用
//
// 为什么使用原始内存而非 AtomicUInt32:
//   Linux futex 系统调用需要 u32 值的内存地址 (*const u32)
//   仓颉的 AtomicUInt32 是类类型，无法直接获取内部值的地址
//   使用原始内存 + 原子内建函数可以同时满足:
//     1. 获取 u32 值的内存地址 (用于 futex 系统调用)
//     2. 保证原子操作的正确性 (使用硬件级原子指令)
// ============================================================================

/// futex 字 - 对应 Bun/Zig 中的 *const atomic.Value(u32)
/// 严格翻译自: Futex.zig 中 wait/wake 的第一个参数
///
/// Bun 使用 atomic u32 作为 futex 地址，支持:
///   load/store/compareAndSwap/fetchAdd 原子操作
///   wait/wake 线程等待/唤醒操作
///
/// 仓颉使用原始内存 + GCC 原子内建函数实现等价语义:
///   原子操作编译为 lock 前缀的 x86 指令 (硬件级原子性保证)
///   futex 操作通过 syscall() 直接调用 Linux 内核
public class FutexWord {
    /// 原始内存指针 - 存储 u32 原子值
    /// 使用 malloc 分配，确保与 C 代码兼容的内存布局
    /// 对应 Bun atomic.Value(u32) 的底层存储
    private let rawPtr: CPointer<Unit>

    /// 创建 futex 字并初始化为指定值
    /// 严格翻译自: Zig atomic.Value(u32).init(initialValue)
    public init(initialValue: UInt32) {
        unsafe {
            rawPtr = malloc(UIntNative(4))
            __atomic_store_n(rawPtr, initialValue, __ATOMIC_SEQ_CST)
        }
    }

    /// 创建 futex 字并初始化为 0
    /// 严格翻译自: Zig atomic.Value(u32).init(0)
    public init() {
        unsafe {
            rawPtr = malloc(UIntNative(4))
            __atomic_store_n(rawPtr, UInt32(0), __ATOMIC_SEQ_CST)
        }
    }

    /// 原子读取 - 对应 Bun atomic.load(.seq_cst)
    /// 严格翻译自: Futex.zig 中 ptr.load(.seq_cst)
    /// 编译为: mov 指令 (对齐的 u32 天然原子)
    public func load(): UInt32 {
        unsafe {
            return __atomic_load_n(rawPtr, __ATOMIC_SEQ_CST)
        }
    }

    /// 原子写入 - 对应 Bun atomic.store(.seq_cst)
    /// 严格翻译自: Futex.zig 中 ptr.store(v, .seq_cst)
    /// 编译为: mov 指令 (对齐的 u32 天然原子)
    public func store(v: UInt32): Unit {
        unsafe {
            __atomic_store_n(rawPtr, v, __ATOMIC_SEQ_CST)
        }
    }

    /// 原子比较并交换 - 对应 Bun atomic.cmpxchgWeak
    /// 严格翻译自: Futex.zig 中 ptr.cmpxchgWeak(expected, desired, .seq_cst, .seq_cst)
    /// 编译为: lock cmpxchg 指令
    /// 返回 true 表示交换成功，false 表示失败
    public func compareAndSwap(expected: UInt32, desired: UInt32): Bool {
        unsafe {
            return __sync_bool_compare_and_swap(rawPtr, expected, desired)
        }
    }

    /// 原子加法 - 对应 Bun atomic.fetchAdd
    /// 严格翻译自: Futex.zig 中 ptr.fetchAdd(delta, .seq_cst)
    /// 编译为: lock xadd 指令
    /// 返回加法前的旧值
    public func fetchAdd(delta: UInt32): UInt32 {
        unsafe {
            return __atomic_fetch_add(rawPtr, delta, __ATOMIC_SEQ_CST)
        }
    }

    /// 原子交换 - 对应 Bun atomic.swap
    /// 严格翻译自: Futex.zig 中 ptr.swap(v, .seq_cst)
    /// 编译为: xchg 指令 (天然原子)
    /// 返回交换前的旧值
    public func swap(v: UInt32): UInt32 {
        unsafe {
            return __atomic_exchange_n(rawPtr, v, __ATOMIC_SEQ_CST)
        }
    }

    // -- futex 操作 (Linux 系统调用) --

    /// futex 等待 - 对应 Bun Futex.wait(ptr, expect, timeout_ns)
    /// 严格翻译自: Futex.zig:24-36 LinuxImpl.wait
    ///   如果 *ptr != expect，立即返回 (OK)
    ///   如果 *ptr == expect，阻塞直到:
    ///     - 值变化 (被其他线程修改)
    ///     - 被 wake() 唤醒
    ///     - 虚假唤醒
    ///     - 超时 (返回 false)
    ///
    /// 实现方式: 通过 syscall() 调用 Linux futex(FUTEX_WAIT_PRIVATE)
    /// 参考: https://man7.org/linux/man-pages/man2/futex.2.html
    public func wait(expect: UInt32): Unit {
        // 快速路径: 如果值已经不等于 expect，直接返回
        // 严格对应 Bun: if (ptr.load(.seq_cst) != expect) return
        if (load() != expect) {
            return
        }
        // 调用 futex 系统调用等待
        // FUTEX_WAIT_PRIVATE: 等待 *uaddr == val，使用进程私有标志
        // timeout=NULL: 无限等待
        unsafe {
            bao_futex_wait(rawPtr, Int32(expect))
        }
        // 返回后: 可能是被 wake() 唤醒，也可能是虚假唤醒
        // 调用者需要在循环中检查条件 (与 Bun 语义一致)
    }

    /// 带超时的 futex 等待 - 对应 Bun Futex.wait(ptr, expect, timeout_ns)
    /// 严格翻译自: Futex.zig:24-36 LinuxImpl.wait (带超时路径)
    /// 返回 true 表示正常唤醒，false 表示超时
    ///
    /// 实现方式: 通过 syscall() 调用 Linux futex(FUTEX_WAIT_PRIVATE, timeout)
    /// 超时使用 struct timespec { tv_sec, tv_nsec } 传递
    public func timedWait(expect: UInt32, timeout: Duration): Bool {
        // 快速路径: 如果值已经不等于 expect，直接返回
        if (load() != expect) {
            return true
        }
        // 零超时: 立即返回超时
        // 严格对应 Bun: if (timeout_ns == 0 && ptr.load != expect) return error.Timeout
        if (timeout <= Duration.Zero) {
            return false
        }

        // 计算超时的秒数和纳秒数
        // 严格对应 Bun: ts.sec = timeout_ns / ns_per_s, ts.nsec = timeout_ns % ns_per_s
        let totalNs = timeout.toNanoseconds()
        let sec = totalNs / Int64(1000000000)
        let nsec = totalNs % Int64(1000000000)

        // 调用 C 辅助函数直接执行 futex 带超时等待
        // 严格翻译自: linux.futex_4arg(@ptrCast(&ptr.raw), .{ .cmd = .WAIT, .private = true }, expect, &ts)
        unsafe {
            let rc = bao_futex_timed_wait(rawPtr, Int32(expect), sec, nsec)

            // 处理返回值
            // 严格对应 Bun LinuxImpl.wait 的错误处理:
            //   SUCCESS (0): 被 wake() 唤醒
            //   EAGAIN (-11): *ptr != expect (值已变化)
            //   EINTR (-4): 虚假唤醒 (信号中断)
            //   ETIMEDOUT (-110): 超时
            //   其他负值: 错误 (忽略，与 Bun 一致)
            if (rc == Int64(-110)) {
                // ETIMEDOUT: 超时
                // 严格对应 Bun: return error.Timeout
                return false
            }
            // SUCCESS, EAGAIN, EINTR: 正常唤醒或值已变化
            // 严格对应 Bun: return Ok(())
            return true
        }
    }

    /// 永远等待 - 对应 Bun Futex.waitForever(ptr, expect)
    /// 严格翻译自: Futex.zig:38-48
    ///   循环调用 wait(ptr, expect, null)，忽略 Timeout (不应发生)
    ///
    /// 实现方式: 循环调用 futex(FUTEX_WAIT_PRIVATE) 直到被唤醒
    /// 处理 EINTR (虚假唤醒) 和 EAGAIN (值已变化)
    public func waitForever(expect: UInt32): Unit {
        // 严格对应 Bun: while (true) { Impl.wait(ptr, expect, null) catch ... }
        while (load() == expect) {
            // 调用 futex 系统调用等待
            // timeout=NULL: 无限等待
            // 严格翻译自: linux.futex_4arg(@ptrCast(&ptr.raw), .{ .cmd = .WAIT, .private = true }, expect, null)
            unsafe {
                let rc = bao_futex_wait(rawPtr, Int32(expect))

                // 处理返回值
                // 严格对应 Bun LinuxImpl.wait 的错误处理:
                //   SUCCESS (0): 被 wake() 唤醒 -> 继续循环检查条件
                //   EAGAIN (-11): *ptr != expect -> 值已变化，退出循环
                //   EINTR (-4): 虚假唤醒 -> 继续循环
                //   ETIMEDOUT (-110): 不应发生 (无超时) -> 忽略，继续循环
                //   其他负值: 错误 -> 忽略，继续循环
                if (rc == Int64(-11)) {
                    // EAGAIN: 值已变化，退出循环
                    // 严格对应 Bun: .AGAIN => {} (break out of loop)
                    break
                }
                // SUCCESS, EINTR, ETIMEDOUT, 其他: 继续循环
                // 严格对应 Bun: .SUCCESS => {}, .INTR => {}, .TIMEDOUT => continue
            }
        }
    }

    /// futex 唤醒 - 对应 Bun Futex.wake(ptr, max_waiters)
    /// 严格翻译自: Futex.zig:51-59 LinuxImpl.wake
    ///   唤醒最多 max_waiters 个在 *ptr 上等待的线程
    ///   max_waiters=1: 唤醒一个 (对应 Linux FUTEX_WAKE val=1)
    ///   max_waiters=MAX: 唤醒所有 (对应 Linux FUTEX_WAKE val=INT_MAX)
    ///
    /// 实现方式: 通过 syscall() 调用 Linux futex(FUTEX_WAKE_PRIVATE)
    /// 严格对应 Bun: linux.futex_3arg(&ptr.raw, .{ .cmd = .WAKE, .private = true }, max_waiters)
    public func wake(maxWaiters: UInt32): Unit {
        if (maxWaiters == UInt32(0)) {
            return
        }
        // 调用 futex 系统调用唤醒
        // FUTEX_WAKE_PRIVATE: 唤醒在 *uaddr 上等待的线程
        // val: 最多唤醒的线程数
        // 严格翻译自: linux.futex_3arg(&ptr.raw, .{ .cmd = .WAKE, .private = true }, @bitCast(std.math.cast(i32, max_waiters) orelse std.math.maxInt(i32)))
        unsafe {
            bao_futex_wake(rawPtr, Int32(maxWaiters))
        }
        // 返回值是被唤醒的线程数，忽略 (与 Bun 一致)
    }

    /// 唤醒一个等待线程 - 便捷方法
    /// 严格对应 Bun: Futex.wake(ptr, 1)
    public func wakeOne(): Unit {
        wake(UInt32(1))
    }

    /// 唤醒所有等待线程 - 便捷方法
    /// 严格对应 Bun: Futex.wake(ptr, maxInt(i32))
    public func wakeAll(): Unit {
        wake(UInt32(0x7FFFFFFF))
    }

    /// 获取原始内存指针 - 用于高级操作
    /// 注意: 返回的指针在 FutexWord 生命周期内有效
    public func rawAddress(): CPointer<Unit> {
        return rawPtr
    }

    /// 析构函数 - 释放分配的内存
    /// 严格对应 Zig atomic.Value(u32) 的生命周期管理
    ~init() {
        unsafe {
            free(rawPtr)
        }
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
    /// 严格翻译自: Futex.zig:376-386 Deadline(expires_in_ns)
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
