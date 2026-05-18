// bao_core - 操作系统原生线程 ID
// 严格翻译自: src/bun_core/thread_id.rs
//   pub type ThreadId = u32 (Linux) / u64 (macOS) / usize (其他)
//   pub fn current() -> ThreadId
//   pub const INVALID: ThreadId = ThreadId::MAX
// Bun: OS-native numeric thread ID — 内核的 "this thread" 概念
//   用于存储在原子中并在 panic/调试器中打印
//   与 Rust std::thread::ThreadId 不同: 后者是进程本地单调计数器
// 仓颉: 提供等价的线程 ID 获取机制
package bao_core

import std.sync.*

// ============================================================================
// ThreadId - 操作系统原生线程 ID
// 严格翻译自: src/bun_core/thread_id.rs
//   Zig: std.Thread.Id / std.Thread.getCurrentId()
//   Linux: gettid() → u32
//   macOS: pthread_threadid_np() → u64
//   Windows: GetCurrentThreadId() → DWORD (u32)
//   仓颉: 使用 Thread.currentThread.id (Int64)
// ============================================================================

/// 线程 ID 类型 - 对应 Bun ThreadId
/// Bun: Linux/Android/BSD/Windows → u32; macOS/iOS → u64; 其他 → usize
/// 仓颉: 统一使用 Int64
public type ThreadId = Int64

/// 原子线程 ID 类型 - 对应 Bun AtomicThreadId
/// Bun: AtomicU32 (Linux) / AtomicU64 (macOS) / AtomicUsize (其他)
/// 仓颉: 使用 AtomicInt64
public class AtomicThreadId {
    private let atomic: AtomicInt64

    public init() {
        atomic = AtomicInt64(Int64.Max)
    }

    public init(value: ThreadId) {
        atomic = AtomicInt64(value)
    }

    public func load(): ThreadId {
        return atomic.load()
    }

    public func store(value: ThreadId): Unit {
        atomic.store(value)
    }

    public func compareExchange(current: ThreadId, new: ThreadId): Bool {
        return atomic.compareAndSwap(current, new)
    }
}

/// 不与任何线程 ID 别名的值 - 对应 Bun INVALID
public let INVALID_THREAD_ID: ThreadId = Int64.Max

/// 是否为无效线程 ID
public func isInvalidThreadId(id: ThreadId): Bool {
    return id == INVALID_THREAD_ID
}

/// 获取当前线程的操作系统 ID - 对应 Bun thread_id::current()
/// Bun:
///   Linux: unsafe { libc::gettid() } as ThreadId
///   macOS: pthread_threadid_np(null, &id) → id
///   Windows: GetCurrentThreadId()
/// 仓颉: Thread.currentThread.id
public func currentThreadId(): ThreadId {
    return Thread.currentThread.id
}

/// 调试用线程 ID - 对应 Bun util::debug_thread_id
/// Bun: current() as u64 (debug-only)
public func debugThreadId(): Int64 {
    return currentThreadId()
}
