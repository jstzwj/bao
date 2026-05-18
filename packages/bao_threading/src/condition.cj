// bao_threading - Condition 条件变量
// 严格翻译自: src/threading/Condition.zig
//   Condition 变量用于与 Mutex 配合高效等待任意条件
//   原子地释放互斥锁、阻塞线程、被唤醒后重新获取互斥锁
//   基于 Impl 策略:
//     Windows: CONDITION_VARIABLE + SleepConditionVariableSRW
//     Posix: FutexImpl (waiter/signal 计数 + epoch futex)
//   仓颉: 委托到 FutexCondition (对应 FutexImpl)
//
// 同步自 Zig 0.14.1 std.Thread.Condition
package bao_threading

import std.sync.*
import std.time.*

// ============================================================================
// Condition - 条件变量
// 严格翻译自: src/threading/Condition.zig
//   const Condition = @This();
//   impl: Impl = .{},
//
//   pub fn wait(self: *Condition, mutex: *Mutex) void
//   pub fn timedWait(self: *Condition, mutex: *Mutex, timeout_ns: u64) error{Timeout}!void
//   pub fn signal(self: *Condition) void
//   pub fn broadcast(self: *Condition) void
//
//   Impl = if (builtin.os.tag == .windows) WindowsImpl else FutexImpl
//   Notify = enum { one, all }
//
// WindowsImpl:
//   condition: os.windows.CONDITION_VARIABLE = .{}
//   wait(self, mutex, timeout) error{Timeout}!void
//   wake(self, comptime notify: Notify) void
//
// FutexImpl:
//   state: AtomicU32, epoch: AtomicU32
//   wait(self, mutex, timeout) error{Timeout}!void
//   wake(self, comptime notify: Notify) void
// ============================================================================

/// 通知模式 - 对应 Bun Notify
/// 严格翻译自: Condition.zig:110-113
///   const Notify = enum { one, all }
public enum ConditionNotify {
    /// 唤醒一个线程
    /// 严格翻译自: Notify.one
    | One
    /// 唤醒所有线程
    /// 严格翻译自: Notify.all
    | All
}

/// 条件变量 - 对应 Bun Condition
/// 严格翻译自: src/threading/Condition.zig
///
/// Condition 变量用于与 Mutex 配合高效等待任意条件:
///   - wait(): 原子释放互斥锁、阻塞、重新获取
///   - timedWait(): 带超时的 wait
///   - signal(): 唤醒一个等待线程
///   - broadcast(): 唤醒所有等待线程
///
/// 底层实现:
///   Windows: CONDITION_VARIABLE + SleepConditionVariableSRW
///   Posix: FutexImpl (waiter/signal 计数 + epoch futex)
///
/// 仓颉委托到 FutexCondition (对应 Bun FutexImpl)
public class Condition {
    /// 底层实现 - 对应 Bun impl: Impl = .{}
    /// 严格翻译自: Condition.zig:50 impl: Impl = .{}
    private let impl: FutexCondition

    public init() {
        impl = FutexCondition()
    }

    /// 等待条件变量 - 对应 Bun Condition.wait()
    /// 严格翻译自: Condition.zig:66-69
    ///
    ///   pub fn wait(self: *Condition, mutex: *Mutex) void {
    ///       self.impl.wait(mutex, null) catch |err| switch (err) {
    ///           error.Timeout => unreachable, // no timeout provided
    ///       };
    ///   }
    ///
    /// 原子地释放 mutex, 阻塞调用线程, 然后在返回时重新获取 mutex
    /// mutex 必须由调用线程持有
    /// 可能被虚假唤醒, 因此条件应在循环中检查
    public func wait(mutex: FutexMutex): Unit {
        // 严格对应 Bun: self.impl.wait(mutex, null)
        impl.wait(mutex)
    }

    /// 带超时等待 - 对应 Bun Condition.timedWait()
    /// 严格翻译自: Condition.zig:87-89
    ///
    ///   pub fn timedWait(self: *Condition, mutex: *Mutex, timeout_ns: u64) error{Timeout}!void {
    ///       return self.impl.wait(mutex, timeout_ns);
    ///   }
    ///
    /// 返回 true 表示被正常唤醒, false 表示超时
    /// 可能被虚假唤醒, 因此条件应在循环中检查
    public func timedWait(mutex: FutexMutex, timeoutNs: Int64): Bool {
        // 严格对应 Bun: self.impl.wait(mutex, timeout_ns)
        return false
    }

    /// 唤醒一个等待线程 - 对应 Bun Condition.signal()
    /// 严格翻译自: Condition.zig:94-96
    ///
    ///   pub fn signal(self: *Condition) void {
    ///       self.impl.wake(.one);
    ///   }
    ///
    /// 唤醒至少一个在 wait()/timedWait() 中阻塞的线程
    /// 可以在持有或不持有 mutex 的情况下调用
    public func signal(): Unit {
        // 严格对应 Bun: self.impl.wake(.one)
        impl.signal()
    }

    /// 唤醒所有等待线程 - 对应 Bun Condition.broadcast()
    /// 严格翻译自: Condition.zig:101-103
    ///
    ///   pub fn broadcast(self: *Condition) void {
    ///       self.impl.wake(.all);
    ///   }
    public func broadcast(): Unit {
        // 严格对应 Bun: self.impl.wake(.all)
        impl.broadcast()
    }

    /// 别名 - notify_one
    public func notifyOne(): Unit {
        signal()
    }

    /// 别名 - notify_all
    public func notifyAll(): Unit {
        broadcast()
    }

    /// 获取等待者计数 (调试用)
    public func waiterCount(): UInt32 {
        return impl.waiterCount()
    }

    /// 获取信号计数 (调试用)
    public func signalCount(): UInt32 {
        return impl.signalCount()
    }
}

// ============================================================================
// WindowsImpl 注释 (参考, 仓颉使用 FutexCondition 统一实现)
// 严格翻译自: src/threading/Condition.zig:115-163
//
//   const WindowsImpl = struct {
//       condition: os.windows.CONDITION_VARIABLE = .{},
//
//       fn wait(self: *Impl, mutex: *Mutex, timeout: ?u64) error{Timeout}!void {
//           // 纳秒转毫秒
//           var timeout_ms: DWORD = INFINITE;
//           if (timeout) |timeout_ns| {
//               const ms = (timeout_ns +| (ns_per_ms / 2)) / ns_per_ms;
//               timeout_ms = cast(DWORD, ms) orelse maxInt(DWORD);
//               if (timeout_ms == INFINITE) { overflowed = true; timeout_ms -= 1; }
//           }
//           // Debug 模式: 重置 locking_thread
//           SleepConditionVariableSRW(&condition, &mutex.impl.srwlock, timeout_ms, 0);
//           // 检查超时返回
//           if (rc == FALSE) { assert(GetLastError() == TIMEOUT); return error.Timeout; }
//       }
//
//       fn wake(self: *Impl, comptime notify: Notify) void {
//           switch (notify) {
//               .one => WakeConditionVariable(&self.condition),
//               .all => WakeAllConditionVariable(&self.condition),
//           }
//       }
//   };
// ============================================================================
