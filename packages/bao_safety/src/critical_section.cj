// bao_safety - 临界区 (数据竞争检测)
// 严格翻译自: bun/src/safety/CriticalSection.rs (Rust port of CriticalSection.zig)
//   pub struct CriticalSection { internal_state: State }
//   struct OptionalThreadId { inner: ThreadId }
//   struct State { thread_id, owner_trace, owned_count, count }
//   impl State { get_or_become_owner, show_trace, lock_shared,
//                lock_exclusive, unlock }
//   impl CriticalSection { begin, begin_read_only, end }
//   pub const ENABLED: bool = cfg!(feature = "ci_assert");
package bao_safety

import bao_threading.*
import bao_crash_handler.*

// ============================================================================
// CriticalSection - 临界区 (数据竞争检测)
// 严格翻译自: bun/src/safety/CriticalSection.rs
//
//   Rust 原始逻辑:
//     pub const ENABLED: bool = cfg!(feature = "ci_assert");
//
//     pub struct CriticalSection {
//         #[cfg(feature = "ci_assert")]
//         internal_state: State,
//     }
//
//     struct OptionalThreadId { inner: ThreadId }
//     impl OptionalThreadId {
//         fn init(id: ThreadId) -> OptionalThreadId
//         impl Display: "thread {id}" or "another thread"
//     }
//
//     struct State {
//         thread_id: AtomicThreadId,
//         #[cfg(debug_assertions)]
//         owner_trace: StoredTrace,
//         owned_count: u32,
//         count: AtomicU32,
//     }
//     impl State {
//         const EXCLUSIVE: u32 = u32::MAX;
//         fn get_or_become_owner -> ThreadId:
//           current_id = current_thread_id()
//           compare_exchange(INVALID, current_id, Relaxed, Relaxed)
//           Ok(_) => { capture trace; return current_id }
//           Err(existing) => return existing
//
//         fn show_trace():
//           if (!debug_assertions) return
//           Output::err("race condition", "CriticalSection first entered here:")
//           dump_stored_trace(&self.owner_trace)
//
//         fn lock_shared():
//           current_id = current_thread_id()
//           owner_id = self.get_or_become_owner()
//           if (owner_id == current_id): self.owned_count += 1
//           else if (self.count.fetch_add(1, Relaxed) == EXCLUSIVE):
//             show_trace(); panic("race condition: read data being modified")
//
//         fn lock_exclusive():
//           current_id = current_thread_id()
//           owner_id = self.get_or_become_owner()
//           if (owner_id == current_id):
//             match self.count.swap(EXCLUSIVE, Relaxed):
//               0 | EXCLUSIVE => {}
//               _ => show_trace(); panic("race condition: modify data being read")
//             self.owned_count += 1
//           else:
//             show_trace(); panic("race condition: modify data being accessed")
//
//         fn unlock():
//           current_id = current_thread_id()
//           owner_id = self.thread_id.load(Relaxed)
//           if (owner_id == current_id && self.owned_count > 0):
//             self.owned_count -= 1
//             if (self.owned_count == 0):
//               self.count.compare_exchange(EXCLUSIVE, 0, Relaxed, Relaxed)
//               self.thread_id.store(INVALID, Relaxed)
//           else:
//             match self.count.fetch_sub(1, Relaxed):
//               0 => panic("called CriticalSection.end too many times")
//               EXCLUSIVE => panic("count should not be exclusive if multiple threads hold the lock")
//               _ => {}
//     }
// ============================================================================

/// 可选线程 ID - 用于错误消息格式化
/// 对应 Rust: struct OptionalThreadId { inner: ThreadId }
public struct OptionalThreadId {
    public let inner: Int64

    public init(id: Int64) {
        this.inner = id
    }

    /// 格式化为字符串
    /// 对应 Rust: impl Display for OptionalThreadId
    ///   if self.inner == INVALID: "another thread"
    ///   else: "thread {id}"
    public func format(): String {
        if (inner == INVALID_THREAD_ID) {
            "another thread"
        } else {
            "thread ${inner}"
        }
    }
}

/// 临界区 - 对应 Bun CriticalSection
/// 检测数据竞争条件：同一数据不能同时被多个线程写入或同时读写
/// 使用原子操作确保线程安全
///
/// 用法:
///   shared_data.critical_section.begin()
///   defer shared_data.critical_section.end()
///   // 操作共享数据...
///
/// 只读访问:
///   shared_data.critical_section.beginReadOnly()
///   defer shared_data.critical_section.end()
///   // 只读操作共享数据...
public class CriticalSection {
    /// 排他标记值 (表示有线程请求写访问)
    /// 对应: State::EXCLUSIVE = u32::MAX
    /// Rust: const EXCLUSIVE: u32 = u32::MAX;
    private static let EXCLUSIVE: UInt32 = UInt32.MAX

    /// 持有锁的线程 ID (原子)
    /// 对应: State.thread_id: AtomicThreadId
    /// Rust: thread_id: AtomicThreadId
    private let threadId: AtomicThreadId

    /// 拥有者的嵌套计数 (非原子，只在拥有者线程访问)
    /// 对应: State.owned_count: u32
    /// Rust: owned_count: u32
    private var ownedCount: UInt32

    /// 非拥有者的共享计数 (原子)
    /// 对应: State.count: AtomicU32
    /// Rust: count: AtomicU32
    private let count: AtomicU32

    /// 是否启用
    /// 对应: pub const ENABLED: bool = cfg!(feature = "ci_assert")
    private var enabled: Bool

    /// 是否启用追踪
    /// 对应: #[cfg(debug_assertions)] owner_trace: StoredTrace
    private var tracesEnabled: Bool

    /// 拥有者首次获取锁时的栈追踪 (仅在 traces_enabled 时有效)
    /// 对应: owner_trace: StoredTrace
    private var ownerTrace: StoredTrace

    public init() {
        threadId = AtomicThreadId.newInvalid()
        ownedCount = 0
        count = AtomicU32(0)
        enabled = false // CI 构建中启用
        tracesEnabled = false
        ownerTrace = StoredTrace.EMPTY
    }

    public init(enabled: Bool) {
        threadId = AtomicThreadId.newInvalid()
        ownedCount = 0
        count = AtomicU32(0)
        this.enabled = enabled
        this.tracesEnabled = false
        this.ownerTrace = StoredTrace.EMPTY
    }

    public init(enabled: Bool, tracesEnabled: Bool) {
        threadId = AtomicThreadId.newInvalid()
        ownedCount = 0
        count = AtomicU32(0)
        this.enabled = enabled
        this.tracesEnabled = tracesEnabled
        this.ownerTrace = StoredTrace.EMPTY
    }

    /// 尝试成为拥有者线程
    /// 对应: State::get_or_become_owner()
    ///   current_id = current_thread_id()
    ///   compare_exchange(INVALID, current_id, Relaxed, Relaxed)
    ///     Ok(_) => { capture trace; return current_id }
    ///     Err(existing) => return existing
    private func getOrBecomeOwner(): Int64 {
        let currentId = ThreadId.current()
        let (success, oldVal) = threadId.compareExchange(INVALID_THREAD_ID, currentId)
        if (success) {
            if (tracesEnabled) {
                ownerTrace = StoredTrace.capture(None)
            }
            currentId
        } else {
            oldVal
        }
    }

    /// 显示追踪信息
    /// 对应: State::show_trace()
    ///   Output::err("race condition", "`CriticalSection` first entered here:")
    ///   dump_stored_trace(&self.owner_trace)
    private func showTrace(): Unit {
        if (!tracesEnabled) { return }
        // 对应: bun_core::Output::err("race condition", ...)
        // 对应: crate::dump_stored_trace(&self.owner_trace)
        print("race condition: `CriticalSection` first entered here:")
    }

    /// 开始临界区 (排他写访问)
    /// 对应: CriticalSection::begin() => State::lock_exclusive()
    ///   current_id = current_thread_id()
    ///   owner_id = self.get_or_become_owner()
    ///   if (owner_id == current_id):
    ///     match self.count.swap(EXCLUSIVE, Relaxed):
    ///       0 | EXCLUSIVE => {}
    ///       _ => show_trace(); panic("race condition")
    ///     self.owned_count += 1
    ///   else:
    ///     show_trace(); panic("race condition")
    public func begin(): Unit {
        if (!enabled) { return }
        let currentId = ThreadId.current()
        let ownerId = getOrBecomeOwner()
        if (ownerId == currentId) {
            // 拥有者线程：检查是否有其他线程在读
            let oldCount = count.swap(EXCLUSIVE)
            if (oldCount != 0 && oldCount != EXCLUSIVE) {
                showTrace()
                panic("race condition: thread ${currentId} tried to modify data being read by ${OptionalThreadId(ownerId).format()}")
            }
            ownedCount += 1
        } else {
            showTrace()
            panic("race condition: thread ${currentId} tried to modify data being accessed by ${OptionalThreadId(ownerId).format()}")
        }
    }

    /// 开始临界区 (共享只读访问)
    /// 对应: CriticalSection::begin_read_only() => State::lock_shared()
    ///   current_id = current_thread_id()
    ///   owner_id = self.get_or_become_owner()
    ///   if (owner_id == current_id): self.owned_count += 1
    ///   else if (self.count.fetch_add(1, Relaxed) == EXCLUSIVE):
    ///     show_trace(); panic("race condition")
    public func beginReadOnly(): Unit {
        if (!enabled) { return }
        let currentId = ThreadId.current()
        let ownerId = getOrBecomeOwner()
        if (ownerId == currentId) {
            // 拥有者线程：递增嵌套计数
            ownedCount += 1
        } else {
            // 非拥有者线程：原子递增共享计数，检查是否有排他锁
            let oldCount = count.fetchAdd(1)
            if (oldCount == EXCLUSIVE) {
                showTrace()
                panic("race condition: thread ${currentId} tried to read data being modified by ${OptionalThreadId(ownerId).format()}")
            }
        }
    }

    /// 结束临界区
    /// 对应: CriticalSection::end() => State::unlock()
    ///   current_id = current_thread_id()
    ///   owner_id = self.thread_id.load(Relaxed)
    ///   if (owner_id == current_id && self.owned_count > 0):
    ///     self.owned_count -= 1
    ///     if (self.owned_count == 0):
    ///       self.count.compare_exchange(EXCLUSIVE, 0, Relaxed, Relaxed)
    ///       self.thread_id.store(INVALID, Relaxed)
    ///   else:
    ///     match self.count.fetch_sub(1, Relaxed):
    ///       0 => panic("called CriticalSection.end too many times")
    ///       EXCLUSIVE => panic("count should not be exclusive if multiple threads")
    ///       _ => {}
    public func end(): Unit {
        if (!enabled) { return }
        let currentId = ThreadId.current()
        let ownerId = threadId.load()

        if (ownerId == currentId && ownedCount > 0) {
            ownedCount -= 1
            if (ownedCount == 0) {
                // 释放排他锁
                count.compareAndSwap(EXCLUSIVE, 0)
                threadId.store(INVALID_THREAD_ID)
            }
        } else {
            // 非拥有者线程释放共享锁
            let oldCount = count.fetchSub(1)
            if (oldCount == 0) {
                panic("called `CriticalSection.end` too many times")
            }
            if (oldCount == EXCLUSIVE) {
                panic("count should not be `exclusive` if multiple threads hold the lock")
            }
        }
    }
}
