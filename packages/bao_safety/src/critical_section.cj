// bao_safety - 临界区 (数据竞争检测)
// 严格翻译自: bun/src/safety/CriticalSection.zig
//   检测多线程数据访问竞争，支持共享读和排他写
package bao_safety

import bao_core.*

// ============================================================================
// CriticalSection - 临界区 (数据竞争检测)
// 严格翻译自: bun/src/safety/CriticalSection.zig
//
//   Zig 原始逻辑:
//     const Self = @This();
//     internal_state: if (enabled) State else void = if (enabled) .{}
//
//     const OptionalThreadId = struct {
//         inner: Thread.Id,
//         pub fn init(id: Thread.Id) OptionalThreadId
//         pub fn format(self, writer) !void
//     };
//
//     const State = struct {
//         thread_id: std.atomic.Value(Thread.Id) = .init(invalid_thread_id),
//         owner_trace: if (traces_enabled) StoredTrace else void,
//         owned_count: u32 = 0,
//         count: std.atomic.Value(u32) = .init(0),
//         const exclusive = std.math.maxInt(u32);
//
//         fn getOrBecomeOwner(self: *State) Thread.Id:
//           current_id = Thread.getCurrentId()
//           return self.thread_id.cmpxchgStrong(invalid_thread_id, current_id, .monotonic, .monotonic)
//             orelse { return current_id }
//
//         fn showTrace(self: *State) void:
//           if (!traces_enabled) return
//           bun.Output.err("race condition", ...)
//           bun.crash_handler.dumpStackTrace(self.owner_trace.trace(), ...)
//
//         fn lockShared(self: *State) void:
//           current_id = Thread.getCurrentId()
//           owner_id = self.getOrBecomeOwner()
//           if (owner_id == current_id):
//             self.owned_count += 1
//           else if (self.count.fetchAdd(1, .monotonic) == exclusive):
//             self.showTrace()
//             std.debug.panic("race condition: thread {} tried to read data being modified by {}", ...)
//
//         fn lockExclusive(self: *State) void:
//           current_id = Thread.getCurrentId()
//           owner_id = self.getOrBecomeOwner()
//           if (owner_id == current_id):
//             switch (self.count.swap(exclusive, .monotonic)):
//               0, exclusive => {}
//               else => panic("race condition: thread {} tried to modify data being read by {}")
//             self.owned_count += 1
//           else:
//             panic("race condition: thread {} tried to modify data being accessed by {}")
//
//         fn unlock(self: *State) void:
//           current_id = Thread.getCurrentId()
//           owner_id = self.thread_id.load(.monotonic)
//           if (owner_id == current_id and self.owned_count > 0):
//             self.owned_count -= 1
//             if (self.owned_count == 0):
//               self.count.cmpxchgStrong(exclusive, 0, .monotonic, .monotonic)
//               self.thread_id.store(invalid_thread_id, .monotonic)
//           else:
//             switch (self.count.fetchSub(1, .monotonic)):
//               0 => panic("called CriticalSection.end too many times")
//               exclusive => panic("count should not be exclusive if multiple threads hold the lock")
//               else => {}
//     };
//
//     pub fn begin(self: *Self) void:
//       if (enabled) self.internal_state.lockExclusive()
//
//     pub fn beginReadOnly(self: *Self) void:
//       if (enabled) self.internal_state.lockShared()
//
//     pub fn end(self: *Self) void:
//       if (enabled) self.internal_state.unlock()
//
//     pub const enabled = bun.Environment.ci_assert;
// ============================================================================

/// 临界区 - 对应 Bun CriticalSection
/// 检测数据竞争条件：同一数据不能同时被多个线程写入或同时读写
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
    /// 对应: State.exclusive = std.math.maxInt(u32)
    private static let EXCLUSIVE: Int64 = Int64.MAX_VALUE

    /// 持有锁的线程 ID
    /// 对应: State.thread_id: std.atomic.Value(Thread.Id)
    private var ownerThreadId: Int64
    /// 拥有者的嵌套计数
    /// 对应: State.owned_count: u32
    private var ownedCount: Int64
    /// 非拥有者的共享计数
    /// 对应: State.count: std.atomic.Value(u32)
    private var sharedCount: Int64
    /// 是否启用
    /// 对应: pub const enabled = bun.Environment.ci_assert
    private var enabled: Bool

    public init() {
        ownerThreadId = INVALID_THREAD_ID
        ownedCount = 0
        sharedCount = 0
        enabled = false // CI 构建中启用
    }

    public init(enabled: Bool) {
        ownerThreadId = INVALID_THREAD_ID
        ownedCount = 0
        sharedCount = 0
        this.enabled = enabled
    }

    /// 尝试成为拥有者线程
    /// 对应: State.getOrBecomeOwner()
    ///   current_id = Thread.getCurrentId()
    ///   return self.thread_id.cmpxchgStrong(invalid_thread_id, current_id, .monotonic, .monotonic)
    ///     orelse { ... return current_id }
    private func getOrBecomeOwner(): Int64 {
        let currentId = ThreadId.current()
        if (ownerThreadId == INVALID_THREAD_ID) {
            ownerThreadId = currentId
        }
        ownerThreadId
    }

    /// 开始临界区 (排他写访问)
    /// 对应: CriticalSection.begin()
    ///   self.internal_state.lockExclusive()
    public func begin(): Unit {
        if (!enabled) { return }
        let currentId = ThreadId.current()
        let ownerId = getOrBecomeOwner()
        if (ownerId == currentId) {
            // 拥有者线程：检查是否有其他线程在读
            if (sharedCount != 0 && sharedCount != EXCLUSIVE) {
                panic("race condition: thread ${currentId} tried to modify data being read by another thread")
            }
            sharedCount = EXCLUSIVE
            ownedCount += 1
        } else {
            panic("race condition: thread ${currentId} tried to modify data being accessed by thread ${ownerId}")
        }
    }

    /// 开始临界区 (共享只读访问)
    /// 对应: CriticalSection.beginReadOnly()
    ///   self.internal_state.lockShared()
    public func beginReadOnly(): Unit {
        if (!enabled) { return }
        let currentId = ThreadId.current()
        let ownerId = getOrBecomeOwner()
        if (ownerId == currentId) {
            // 拥有者线程：递增计数
            ownedCount += 1
        } else {
            // 非拥有者线程：检查是否有排他锁
            if (sharedCount == EXCLUSIVE) {
                panic("race condition: thread ${currentId} tried to read data being modified by thread ${ownerId}")
            }
            sharedCount += 1
        }
    }

    /// 结束临界区
    /// 对应: CriticalSection.end()
    ///   self.internal_state.unlock()
    public func end(): Unit {
        if (!enabled) { return }
        let currentId = ThreadId.current()
        let ownerId = ownerThreadId

        if (ownerId == currentId && ownedCount > 0) {
            ownedCount -= 1
            if (ownedCount == 0) {
                // 释放排他锁
                if (sharedCount == EXCLUSIVE) {
                    sharedCount = 0
                }
                ownerThreadId = INVALID_THREAD_ID
            }
        } else {
            // 非拥有者线程释放共享锁
            if (sharedCount == 0) {
                panic("called CriticalSection.end() too many times")
            }
            if (sharedCount == EXCLUSIVE) {
                panic("shared count should not be EXCLUSIVE if multiple threads hold the lock")
            }
            sharedCount -= 1
        }
    }
}
