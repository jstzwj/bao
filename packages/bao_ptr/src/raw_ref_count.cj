// 严格翻译自: src/ptr/raw_ref_count.zig
// RawRefCount - 原始引用计数包装器
// 不做任何内存管理，仅管理引用计数整数
package bao_ptr

import bao_core.*

// ============================================================================
// ThreadSafety - 线程安全枚举
// ============================================================================

/// 线程安全枚举
public enum ThreadSafety {
    | SingleThreaded
    | ThreadSafe
}

// ============================================================================
// DecrementResult - 减少引用计数的结果
// ============================================================================

/// 减少引用计数的结果
public enum DecrementResult {
    | KeepAlive       // 还有引用，保持存活
    | ShouldDestroy   // 引用为零，应该销毁
}

// ============================================================================
// RawRefCount - 原始引用计数
// ============================================================================

/// 原始引用计数的简单包装器
/// 此类型本身不做任何内存管理
///
/// 此类型可能对实现 bun.ptr.ExternalShared 所需的接口很有用
public class RawRefCount {
    /// 线程安全模式
    public var threadSafety: ThreadSafety = ThreadSafety.SingleThreaded
    /// 原始值 (单线程直接使用整数，线程安全使用原子)
    public var rawValue: AtomicUInt32 = AtomicUInt32(1)
    /// 线程锁 (仅单线程模式使用)
    public var threadLock: ThreadLock = ThreadLock()

    public init() {
        this.initCount(1)
    }

    /// 初始化引用计数
    /// 通常初始计数应该是 1
    public func initCount(initialCount: UInt32): Unit {
        this.rawValue.store(initialCount)
    }

    /// 创建指定初始值的 RawRefCount
    public static func init(initialCount: UInt32, threadSafety: ThreadSafety): RawRefCount {
        let rc = RawRefCount()
        rc.threadSafety = threadSafety
        rc.rawValue.store(initialCount)
        return rc
    }

    /// 增加引用计数
    public func increment(): Unit {
        if (this.threadSafety == ThreadSafety.SingleThreaded) {
            this.threadLock.lockOrAssert()
            let old = this.rawValue.load()
            this.rawValue.store(old + 1)
        } else {
            let old = this.rawValue.fetchAdd(1)
            Assert.assertTrue(old != UInt32.max, "overflow of thread-safe ref count")
        }
    }

    /// 减少引用计数，返回结果
    public func decrement(): DecrementResult {
        let newCount: UInt32
        if (this.threadSafety == ThreadSafety.SingleThreaded) {
            this.threadLock.lockOrAssert()
            let old = this.rawValue.load()
            this.rawValue.store(old - 1)
            newCount = old - 1
        } else {
            let old = this.rawValue.fetchSub(1)
            Assert.assertTrue(old != 0, "underflow of thread-safe ref count")
            newCount = old - 1
        }
        if (newCount == 0) {
            return DecrementResult.ShouldDestroy
        }
        return DecrementResult.KeepAlive
    }

    /// 获取当前计数
    public func get(): UInt32 {
        this.rawValue.load()
    }
}

// ============================================================================
// AtomicUInt32 - 简化的原子 UInt32 (用于仓颉环境)
// ============================================================================

/// 原子 UInt32 包装器
/// 在仓颉中使用 Atomic 类型实现原子操作
public class AtomicUInt32 {
    var _value: UInt32 = 0

    public init() {}
    public init(value: UInt32) {
        this._value = value
    }

    /// 原子加载
    public func load(): UInt32 {
        this._value
    }

    /// 原子存储
    public func store(value: UInt32): Unit {
        this._value = value
    }

    /// 原子加并返回旧值
    public func fetchAdd(value: UInt32): UInt32 {
        let old = this._value
        this._value = this._value + value
        return old
    }

    /// 原子减并返回旧值
    public func fetchSub(value: UInt32): UInt32 {
        let old = this._value
        this._value = this._value - value
        return old
    }

    /// 比较并交换 (弱)
    public func compareExchangeWeak(expected: UInt32, desired: UInt32): Bool {
        if (this._value == expected) {
            this._value = desired
            return true
        }
        return false
    }
}
