// bao_threading - Guarded<T> 互斥保护的值
// 严格翻译自: src/threading/guarded.zig
//   Bun 使用 Guarded<T> 将值和互斥锁绑定在一起
//   GuardedBy<T, Mutex> 是通用版本, 接受任意互斥锁类型
//   Debug<T> 使用 ThreadLock 用于调试
//   仓颉实现提供等价的受保护值抽象
package bao_threading

import std.sync.*

// ============================================================================
// Guarded<T> - 互斥保护的值
// 严格翻译自: src/threading/guarded.zig GuardedBy(Value, Mutex)
//   unsynchronized_value: Value (原始值, 不应在并发时直接访问)
//   mutex: Mutex
//   lock(): 获取锁并返回值的指针
//   unlock(): 释放锁
//   intoUnprotected(): 取出内部值
//   deinit(): 清理
// ============================================================================

/// 互斥保护的值
/// 严格翻译自 guarded.zig:16-63 GuardedBy(Value, Mutex)
///   仓颉使用泛型 + Mutex 实现
public class Guarded<T> {
    /// 内部值 (不保证同步安全)
    /// 严格翻译自: unsynchronized_value: Value
    private var value: T

    /// 互斥锁
    /// 严格翻译自: #mutex: Mutex (bun.threading.Mutex)
    private let mutex: Mutex

    /// 创建受保护的值
    /// 严格翻译自: pub fn init(value: Value) Self
    public init(value: T) {
        this.value = value
        this.mutex = Mutex()
    }

    /// 创建受保护的值 (使用指定互斥锁)
    /// 严格翻译自: pub fn initWithMutex(value: Value, mutex: Mutex) Self
    public init(value: T, mutex: Mutex) {
        this.value = value
        this.mutex = mutex
    }

    /// 加锁并返回值的引用
    /// 严格翻译自: pub fn lock(self: *Self) *Value
    ///   self.#mutex.lock()
    ///   return &self.unsynchronized_value
    /// 注意: 仓颉不支持返回可变引用, 使用回调模式
    public func lock<T2>(action: (T) -> T2): T2 {
        mutex.lock()
        try {
            return action(value)
        } finally {
            mutex.unlock()
        }
    }

    /// 加锁并对值执行可变操作
    public func lockMut<T2>(action: (T) -> T2): T2 {
        mutex.lock()
        try {
            return action(value)
        } finally {
            mutex.unlock()
        }
    }

    /// 解锁
    /// 严格翻译自: pub fn unlock(self: *Self) void
    ///   self.#mutex.unlock()
    public func unlock(): Unit {
        mutex.unlock()
    }

    /// 获取内部未保护的值
    /// 严格翻译自: pub fn intoUnprotected(self: *Self) Value
    ///   defer self.* = undefined
    ///   bun.memory.deinit(&self.#mutex)
    ///   return self.unsynchronized_value
    /// 注意: 调用后此对象不再有效
    public func intoUnprotected(): T {
        return value
    }

    /// 清理
    /// 严格翻译自: pub fn deinit(self: *Self) void
    ///   bun.memory.deinit(&self.unsynchronized_value)
    ///   bun.memory.deinit(&self.#mutex)
    ///   self.* = undefined
    public func deinit(): Unit {
        // 仓颉 GC 处理内存回收
    }
}

// ============================================================================
// GuardedBy<T, M> - 使用指定互斥锁类型的受保护值
// 严格翻译自: src/threading/guarded.zig GuardedBy(Value, Mutex)
// ============================================================================

/// 使用自定义互斥锁的受保护值
/// 严格翻译自: pub fn GuardedBy(comptime Value: type, comptime Mutex: type) type
public class GuardedBy<T, M> where M <: Lockable {
    private var value: T
    private let mutex: M

    public init(value: T, mutex: M) {
        this.value = value
        this.mutex = mutex
    }

    public func lock<T2>(action: (T) -> T2): T2 {
        mutex.lock()
        try {
            return action(value)
        } finally {
            mutex.unlock()
        }
    }

    public func unlock(): Unit {
        mutex.unlock()
    }

    public func intoUnprotected(): T {
        return value
    }
}

// ============================================================================
// Debug<T> - 调试用的受保护值
// 严格翻译自: src/threading/guarded.zig Debug(Value)
//   pub fn Debug(comptime Value: type) type
//   return GuardedBy(Value, bun.safety.ThreadLock)
// ============================================================================

/// 调试受保护值
/// 翻译自: pub fn Debug(comptime Value: type) type
///   return GuardedBy(Value, bun.safety.ThreadLock)
/// 仓颉使用普通的 Guarded<T> 替代
public type Debug<T> = Guarded<T>

// ============================================================================
// Lockable - 互斥锁接口
// ============================================================================

/// 可锁定接口
public interface Lockable {
    func lock(): Unit
    func unlock(): Unit
}

