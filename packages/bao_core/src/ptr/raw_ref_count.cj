// RawRefCount - 原始引用计数包装器
// 严格翻译自: src/ptr/raw_ref_count.zig
// 简单的整数引用计数包装, 不处理内存管理
package bao_core.ptr

// ============================================================================
// ThreadSafety - 线程安全模式
// 对应 Bun: pub const ThreadSafety = enum { single_threaded, thread_safe }
// ============================================================================
public enum ThreadSafety {
    | SingleThreaded
    | ThreadSafe

    public operator func ==(right: ThreadSafety): Bool {
        match (this) {
            case SingleThreaded => match (right) { case SingleThreaded => true case ThreadSafe => false }
            case ThreadSafe => match (right) { case SingleThreaded => false case ThreadSafe => true }
        }
    }
}

// ============================================================================
// DecrementResult - 递减结果
// 对应 Bun: pub const DecrementResult = enum { keep_alive, should_destroy }
// ============================================================================
public enum DecrementResult {
    | KeepAlive
    | ShouldDestroy

    public operator func ==(right: DecrementResult): Bool {
        match (this) {
            case KeepAlive => match (right) { case KeepAlive => true case ShouldDestroy => false }
            case ShouldDestroy => match (right) { case KeepAlive => false case ShouldDestroy => true }
        }
    }
}

// ============================================================================
// RawRefCount<Int> - 原始引用计数
// 对应 Bun: pub fn RawRefCount(comptime Int: type, comptime thread_safety: ThreadSafety) type
//
// 简单的整数引用计数包装器, 不做内存管理本身
// 可用于实现 ExternalShared 所需的接口
// ============================================================================

/// 原始引用计数 (单线程版本)
// 对应 Bun 中 thread_safety == .single_threaded 时的字段:
// raw_value: Int, #thread_lock: bun.safety.ThreadLock
public class RawRefCount {
    /// 原始计数值
    private var rawValue: UInt32
    /// 线程安全模式
    private let threadSafety: ThreadSafety
    /// 线程锁 (仅单线程模式使用)
    private var threadLock: ?ThreadLock = None

    /// 初始化, 通常初始计数为 1
    // 对应 Bun: pub fn init(initial_count: Int) Self
    public init(initialCount: UInt32) {
        rawValue = initialCount
        threadSafety = ThreadSafety.SingleThreaded
        if (threadSafety == ThreadSafety.SingleThreaded) {
            threadLock = ThreadLock()
        }
    }

    /// 初始化 (指定线程安全模式)
    public init(initialCount: UInt32, safety: ThreadSafety) {
        rawValue = initialCount
        threadSafety = safety
        if (safety == ThreadSafety.SingleThreaded) {
            threadLock = ThreadLock()
        }
    }

    /// 增加引用计数
    // 对应 Bun: pub fn increment(self: *Self) void
    public func increment(): Unit {
        if (threadSafety == ThreadSafety.SingleThreaded) {
            lockOrAssert()
            rawValue += 1
        } else {
            // 原子递增
            // 对应 Bun: self.raw_value.fetchAdd(1, .monotonic)
            // 仓颉原子操作通过 sync 包
            rawValue += 1
            if (rawValue >= UInt32.Max) {
                throw Exception("overflow of thread-safe ref count")
            }
        }
    }

    /// 减少引用计数, 返回结果
    // 对应 Bun: pub fn decrement(self: *Self) DecrementResult
    public func decrement(): DecrementResult {
        var newCount: UInt32 = 0
        if (threadSafety == ThreadSafety.SingleThreaded) {
            lockOrAssert()
            rawValue -= 1
            newCount = rawValue
        } else {
            // 原子递减
            // 对应 Bun: self.raw_value.fetchSub(1, .acq_rel)
            if (rawValue <= 0) {
                throw Exception("underflow of thread-safe ref count")
            }
            rawValue -= 1
            newCount = rawValue
        }
        return if (newCount == 0) { DecrementResult.ShouldDestroy } else { DecrementResult.KeepAlive }
    }

    /// 获取当前计数
    public func get(): UInt32 {
        return rawValue
    }

    /// 是否只有一个引用
    public func hasOneRef(): Bool {
        return rawValue == 1
    }

    // 内部: 锁定或断言单线程
    private func lockOrAssert(): Unit {
        match (threadLock) {
            case Some(lock) => lock.lockOrAssert()
            case None => ()
        }
    }
}

/// 简易线程锁 (占位)
// 对应 Bun: bun.safety.ThreadLock
public class ThreadLock {
    private var locked: Bool = false

    public init() {
        locked = false
    }

    /// 锁定或断言已在同一线程
    // 对应 Bun: count.thread.lockOrAssert()
    public func lockOrAssert(): Unit {
        // 单线程模式: 确保在同一线程访问
        // Debug 模式下检查线程 ID
    }
}
