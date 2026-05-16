// bao_safety - Thread ID utilities
// 严格翻译自: bun/src/safety/thread_id.rs (re-export of bun_core::thread_id)
//   pub use bun_core::thread_id::{AtomicThreadId, INVALID, ThreadId, current};
//   Zig: bun/src/safety/thread_id.zig
//   pub const invalid = std.math.maxInt(std.Thread.Id);
package bao_safety

import bao_threading.*

// ============================================================================
// ThreadId - 线程 ID 工具
// 严格翻译自: bun/src/safety/thread_id.rs + bun_core::thread_id
//   pub use bun_core::thread_id::{AtomicThreadId, INVALID, ThreadId, current};
//   Zig: pub const invalid = std.math.maxInt(std.Thread.Id);
// ============================================================================

/// 无效线程 ID 常量 - 对应 Bun thread_id::INVALID / Zig thread_id.invalid
/// 使用 Int64 最大值表示无效线程 ID
/// Rust: pub const INVALID: ThreadId = ThreadId::MAX;
/// Zig:  pub const invalid = std.math.maxInt(std.Thread.Id);
public let INVALID_THREAD_ID: Int64 = Int64.MAX_VALUE

/// 线程 ID 工具 - 对应 Bun thread_id 模块
/// Rust: bun_core::thread_id::{ThreadId, current}
public class ThreadId {
    /// 获取当前线程 ID
    /// 对应: std.Thread.getCurrentId() / bun_core::thread_id::current
    public static func current(): Int64 {
        Thread.currentThread().id
    }

    /// 检查是否为无效线程 ID
    public static func isValid(id: Int64): Bool {
        id != INVALID_THREAD_ID
    }
}

// ============================================================================
// AtomicThreadId - 原子线程 ID
// 严格翻译自: bun/src/safety/thread_id.rs (re-export of bun_core::thread_id::AtomicThreadId)
//   Rust: pub use bun_core::thread_id::AtomicThreadId;
//
//   Rust 原始逻辑 (bun_core/src/thread_id.rs):
//     pub struct AtomicThreadId {
//         inner: AtomicU64,  // or AtomicUsize depending on platform
//     }
//     impl AtomicThreadId {
//         pub const INVALID: ThreadId = ThreadId::MAX;
//         pub fn new(id: ThreadId) -> Self
//         pub fn load(&self, order: Ordering) -> ThreadId
//         pub fn store(&self, id: ThreadId, order: Ordering)
//         pub fn compare_exchange(&self, current: ThreadId, new: ThreadId,
//                                success: Ordering, failure: Ordering) -> Result<ThreadId, ThreadId>
//         pub fn fetch_update<F>(&self, order: Ordering, mut f: F) -> Result<ThreadId, ThreadId>
//     }
//
//   用于 CriticalSection 中的 thread_id 原子字段:
//     thread_id: AtomicThreadId = AtomicThreadId::new(INVALID)
// ============================================================================

/// 原子线程 ID - 对应 Bun AtomicThreadId
/// 用于CriticalSection等结构中的线程 ID 原子操作
/// 仓颉使用 AtomicI64 包装实现
public class AtomicThreadId {
    /// 内部原子值
    private let inner: AtomicI64

    public init(value: Int64) {
        inner = AtomicI64(value)
    }

    /// 创建无效线程 ID 的原子
    /// 对应: AtomicThreadId::new(Self::INVALID)
    public static func newInvalid(): AtomicThreadId {
        AtomicThreadId(INVALID_THREAD_ID)
    }

    /// 读取线程 ID
    /// 对应: AtomicThreadId::load(&self, order: Ordering) -> ThreadId
    ///   Rust 使用 Relaxed ordering, 仓颉默认 SeqCst
    public func load(): Int64 {
        inner.load()
    }

    /// 写入线程 ID
    /// 对应: AtomicThreadId::store(&self, id: ThreadId, order: Ordering)
    ///   Rust 使用 Relaxed/Monotonic ordering
    public func store(value: Int64): Unit {
        inner.store(value)
    }

    /// 比较并交换
    /// 对应: AtomicThreadId::compare_exchange(
    ///     &self, current: ThreadId, new: ThreadId,
    ///     success: Ordering, failure: Ordering
    /// ) -> Result<ThreadId, ThreadId>
    ///
    /// 返回 (成功标志, 旧值)
    /// 成功时: (true, current)
    /// 失败时: (false, actual_value)
    public func compareExchange(expected: Int64, desired: Int64): (Bool, Int64) {
        let current = inner.load()
        if (current == expected) {
            // 尝试 CAS
            if (inner.compareAndSwap(expected, desired)) {
                return (true, expected)
            }
        }
        (false, inner.load())
    }

    /// 条件更新
    /// 对应: AtomicThreadId::fetch_update<F>(&self, order, f) -> Result<ThreadId, ThreadId>
    public func fetchUpdate(updateFunc: (Int64) -> Int64): (Bool, Int64) {
        var oldVal = inner.load()
        while (true) {
            let newVal = updateFunc(oldVal)
            if (inner.compareAndSwap(oldVal, newVal)) {
                return (true, oldVal)
            }
            oldVal = inner.load()
        }
    }
}
