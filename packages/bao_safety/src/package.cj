// bao_safety - 安全检查与断言工具
// 严格翻译自: bun/src/safety/ (safety.zig + alloc.zig + CriticalSection.zig +
//   ThreadLock.zig + asan.zig + thread_id.zig, ~625行)
//   分配器检查、临界区、线程锁、地址消毒器接口
package bao.safety

import bao_core.*

// ============================================================================
// ThreadId - 线程 ID 工具
// 严格翻译自: bun/src/safety/thread_id.zig
//   pub const invalid = std.math.maxInt(std.Thread.Id);
// ============================================================================

/// 无效线程 ID 常量 - 对应 Bun thread_id.invalid
/// 使用 Int64 最大值表示无效线程 ID
public let INVALID_THREAD_ID: Int64 = Int64.MAX_VALUE

/// 线程 ID 工具 - 对应 Bun thread_id 模块
public class ThreadId {
    /// 获取当前线程 ID
    /// 对应: std.Thread.getCurrentId()
    public static func current(): Int64 {
        Thread.currentThread().id
    }

    /// 检查是否为无效线程 ID
    public static func isValid(id: Int64): Bool {
        id != INVALID_THREAD_ID
    }
}

// ============================================================================
// CheckedAllocator - 已检查的分配器
// 严格翻译自: bun/src/safety/alloc.zig - CheckedAllocator
//   pub const CheckedAllocator = struct {
//       #allocator: NullableAllocator,
//       #trace: StoredTrace,
//       pub fn init, set, assertEq, transferOwnership
//   };
// ============================================================================

/// 已检查的分配器 - 对应 Bun CheckedAllocator
/// 确保同一容器不会混用多个分配器
public class CheckedAllocator {
    /// 关联的分配器标识 (用于比较)
    private var allocatorId: Int64
    /// 是否已设置
    private var isSet: Bool
    /// 是否启用检查
    private var enabled: Bool

    public init() {
        allocatorId = 0
        isSet = false
        enabled = false // 默认关闭，CI 构建中开启
    }

    public init(enabled: Bool) {
        allocatorId = 0
        isSet = false
        this.enabled = enabled
    }

    /// 初始化并绑定分配器
    /// 对应: CheckedAllocator.init(alloc)
    public static func init(allocatorId: Int64, enabled: Bool): CheckedAllocator {
        let ca = CheckedAllocator(enabled)
        ca.set(allocatorId)
        ca
    }

    /// 设置分配器 (首次) 或检查一致性 (后续)
    /// 对应: CheckedAllocator.set(self: *Self, alloc: Allocator) void
    ///   if (self.#allocator.isNull()) { self.#allocator = ... }
    ///   else { self.assertEq(alloc) }
    public func set(allocatorId: Int64): Unit {
        if (!enabled) { return }
        if (!isSet) {
            this.allocatorId = allocatorId
            this.isSet = true
        } else {
            assertEq(allocatorId)
        }
    }

    /// 断言分配器一致
    /// 对应: CheckedAllocator.assertEq(self: Self, alloc: Allocator) void
    public func assertEq(allocatorId: Int64): Unit {
        if (!enabled) { return }
        if (this.allocatorId != allocatorId) {
            panic("allocator mismatch: cannot use multiple allocators with the same collection")
        }
    }

    /// 转移所有权到新分配器
    /// 对应: CheckedAllocator.transferOwnership(self: *Self, new_allocator) void
    ///   仅允许在特定分配器类型间转移
    public func transferOwnership(newAllocatorId: Int64): Unit {
        if (!enabled) { return }
        // 简化实现：直接更新
        this.allocatorId = newAllocatorId
    }
}

// ============================================================================
// AllocatorAssertion - 分配器断言工具
// 严格翻译自: bun/src/safety/alloc.zig - assertEq, assertEqFmt
//   pub fn assertEq(alloc1: Allocator, alloc2: Allocator) void
//   pub fn assertEqFmt(alloc1, alloc2, comptime format, args) void
// ============================================================================

/// 分配器断言工具 - 对应 Bun safety/alloc.zig 的全局断言函数
public class AllocatorAssertion {
    /// 断言两个分配器相等
    /// 对应: assertEq(alloc1, alloc2)
    public static func assertEq(id1: Int64, id2: Int64): Unit {
        if (id1 != id2) {
            panic("allocator mismatch: allocators do not match")
        }
    }

    /// 断言两个分配器相等 (带消息)
    /// 对应: assertEqFmt(alloc1, alloc2, comptime format, args)
    public static func assertEqFmt(id1: Int64, id2: Int64, message: String): Unit {
        if (id1 != id2) {
            panic("allocator mismatch: ${message}")
        }
    }
}

// ============================================================================
// CriticalSection - 临界区 (数据竞争检测)
// 严格翻译自: bun/src/safety/CriticalSection.zig
//   检测多线程数据访问竞争，支持共享读和排他写
//
//   const State = struct {
//       thread_id: std.atomic.Value(Thread.Id),
//       owned_count: u32 = 0,
//       count: std.atomic.Value(u32) = .init(0),
//       const exclusive = std.math.maxInt(u32);
//       fn getOrBecomeOwner, lockShared, lockExclusive, unlock
//   };
//   pub fn begin, beginReadOnly, end
// ============================================================================

/// 临界区 - 对应 Bun CriticalSection
/// 检测数据竞争条件：同一数据不能同时被多个线程写入或同时读写
public class CriticalSection {
    /// 排他标记值 (表示有线程请求写访问)
    private static let EXCLUSIVE: Int64 = Int64.MAX_VALUE

    /// 持有锁的线程 ID
    private var ownerThreadId: Int64
    /// 拥有者的嵌套计数
    private var ownedCount: Int64
    /// 非拥有者的共享计数
    private var sharedCount: Int64
    /// 是否启用
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

// ============================================================================
// ThreadLock - 线程锁 (单线程断言)
// 严格翻译自: bun/src/safety/ThreadLock.zig
//   pub const ThreadLock = @This();
//   pub fn initUnlocked, initLocked, lock, unlock, assertLocked, lockOrAssert
// ============================================================================

/// 线程锁 - 对应 Bun ThreadLock
/// 确保数据只被一个线程访问 (非互斥锁，是调试断言)
public class ThreadLock {
    /// 持有锁的线程 ID
    private var owningThread: Int64
    /// 是否启用
    private var enabled: Bool

    public init() {
        owningThread = INVALID_THREAD_ID
        enabled = false
    }

    public init(enabled: Bool) {
        owningThread = INVALID_THREAD_ID
        this.enabled = enabled
    }

    /// 初始化为未锁定状态
    /// 对应: ThreadLock.initUnlocked()
    public static func initUnlocked(): ThreadLock {
        ThreadLock()
    }

    /// 初始化为已锁定状态
    /// 对应: ThreadLock.initLocked()
    public static func initLocked(): ThreadLock {
        let lock = ThreadLock()
        lock.lock()
        lock
    }

    /// 获取锁
    /// 对应: ThreadLock.lock()
    ///   如果已被其他线程持有则 panic
    public func lock(): Unit {
        if (!enabled) { return }
        let current = ThreadId.current()
        if (owningThread != INVALID_THREAD_ID) {
            panic("tried to lock ThreadLock on thread ${current}, but was already locked by thread ${owningThread}")
        }
        owningThread = current
    }

    /// 释放锁
    /// 对应: ThreadLock.unlock()
    public func unlock(): Unit {
        if (!enabled) { return }
        assertLocked()
        owningThread = INVALID_THREAD_ID
    }

    /// 断言当前线程持有锁
    /// 对应: ThreadLock.assertLocked()
    public func assertLocked(): Unit {
        if (!enabled) { return }
        if (owningThread == INVALID_THREAD_ID) {
            panic("ThreadLock is not locked")
        }
        let current = ThreadId.current()
        if (owningThread != current) {
            panic("ThreadLock is locked by thread ${owningThread}, not thread ${current}")
        }
    }

    /// 获取锁或断言已持有
    /// 对应: ThreadLock.lockOrAssert()
    ///   如果未锁定则获取，如果已锁定则断言当前线程持有
    public func lockOrAssert(): Unit {
        if (!enabled) { return }
        if (owningThread == INVALID_THREAD_ID) {
            lock()
        } else {
            assertLocked()
        }
    }
}

// ============================================================================
// ASan - 地址消毒器接口
// 严格翻译自: bun/src/safety/asan.zig
//   ASAN 内存毒化/去毒化/泄漏扫描根区域注册
//   pub fn poison, unpoison, isPoisoned, describe,
//        registerRootRegion, unregisterRootRegion,
//        assertPoisoned, assertUnpoisoned, updateAllocationContext
// ============================================================================

/// 地址消毒器接口 - 对应 Bun safety/asan.zig
/// 提供 ASAN/LSAN 内存检测的抽象接口
/// 在非 ASAN 构建中所有操作为空操作
public class ASan {
    /// 是否启用 ASAN
    public static var enabled: Bool = false

    /// 毒化内存区域 (标记为不可访问)
    /// 对应: poison(ptr: *const anyopaque, size: usize) void
    ///   手动毒化用于自定义分配器
    public static func poison(ptr: Int64, size: Int64): Unit {
        if (!enabled) { return }
        // 需要 FFI 调用 __asan_poison_memory_region
        // 仓颉中通过外部函数接口实现
    }

    /// 去毒化内存区域 (标记为可访问)
    /// 对应: unpoison(ptr: *const anyopaque, size: usize) void
    public static func unpoison(ptr: Int64, size: Int64): Unit {
        if (!enabled) { return }
        // 需要 FFI 调用 __asan_unpoison_memory_region
    }

    /// 检查地址是否被毒化
    /// 对应: isPoisoned(ptr: *const anyopaque) bool
    public static func isPoisoned(ptr: Int64): Bool {
        if (!enabled) { return false }
        false // 需要 FFI 调用 __asan_address_is_poisoned
    }

    /// 描述地址信息 (打印分配/释放/栈追踪等)
    /// 对应: describe(ptr: *const anyopaque) void
    public static func describe(ptr: Int64): Unit {
        if (!enabled) { return }
        // 需要 FFI 调用 __asan_describe_address
    }

    /// 注册根区域 (泄漏扫描时扫描此区域)
    /// 对应: registerRootRegion(ptr: *const anyopaque, size: usize) void
    ///   用于 mimalloc 等自定义分配器，防止误报泄漏
    public static func registerRootRegion(ptr: Int64, size: Int64): Unit {
        if (!enabled) { return }
        // 需要 FFI 调用 __lsan_register_root_region
    }

    /// 取消注册根区域
    /// 对应: unregisterRootRegion(ptr: *const anyopaque, size: usize) void
    public static func unregisterRootRegion(ptr: Int64, size: Int64): Unit {
        if (!enabled) { return }
        // 需要 FFI 调用 __lsan_unregister_root_region
    }

    /// 更新分配上下文 (更新栈追踪到当前位置)
    /// 对应: updateAllocationContext(ptr: *const anyopaque) bool
    public static func updateAllocationContext(ptr: Int64): Bool {
        if (!enabled) { return false }
        false // 需要 FFI 调用 __asan_update_allocation_context
    }

    /// 断言地址已被毒化
    /// 对应: assertPoisoned(ptr: *const anyopaque) void
    public static func assertPoisoned(ptr: Int64): Unit {
        if (!enabled) { return }
        if (!isPoisoned(ptr)) {
            describe(ptr)
            panic("Address is not poisoned")
        }
    }

    /// 断言地址未被毒化
    /// 对应: assertUnpoisoned(ptr: *const anyopaque) void
    public static func assertUnpoisoned(ptr: Int64): Unit {
        if (!enabled) { return }
        if (isPoisoned(ptr)) {
            describe(ptr)
            panic("Address is poisoned")
        }
    }
}

// ============================================================================
// SafetyContext - 安全上下文配置
// 聚合所有安全模块的启停控制
// ============================================================================

/// 安全上下文 - 对应 Bun safety 模块的配置
/// 控制各种安全检查的启停
public class SafetyContext {
    /// 是否启用 CI 断言模式
    /// 对应: bun.Environment.ci_assert
    public var ciAssert: Bool

    /// 是否启用调试模式
    /// 对应: bun.Environment.isDebug
    public var isDebug: Bool

    /// 是否启用 ASAN
    /// 对应: bun.Environment.enable_asan
    public var enableASan: Bool

    public init() {
        ciAssert = false
        isDebug = false
        enableASan = false
    }

    public init(ciAssert: Bool, isDebug: Bool, enableASan: Bool) {
        this.ciAssert = ciAssert
        this.isDebug = isDebug
        this.enableASan = enableASan
    }

    /// 创建临界区 (根据配置启用/禁用)
    public func createCriticalSection(): CriticalSection {
        CriticalSection(ciAssert)
    }

    /// 创建线程锁 (根据配置启用/禁用)
    public func createThreadLock(): ThreadLock {
        ThreadLock(ciAssert)
    }

    /// 创建已检查的分配器 (根据配置启用/禁用)
    public func createCheckedAllocator(): CheckedAllocator {
        CheckedAllocator(ciAssert)
    }

    /// 是否启用追踪
    /// 对应: traces_enabled = bun.Environment.isDebug
    public func tracesEnabled(): Bool {
        isDebug
    }
}
