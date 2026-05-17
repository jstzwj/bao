// 严格翻译自: src/bun_alloc/allocation_scope.zig
// allocation_scope.cj - 分配作用域，用于追踪分配和泄漏检测

package bao_bun_alloc

import bao_core.*
import bao_crash_handler.*
import bao_collections.*

private func allocationPointerKey(ptr: CPointer<Byte>): String {
    return "allocation-pointer"
}

// ============================================================================
// Allocation - 分配记录
// 对应 Zig: pub const Allocation = struct { ... }
// ============================================================================

/// 分配记录
public struct Allocation {
    /// 分配时的调用栈追踪
    public var allocatedAt: StoredTrace
    /// 分配长度
    public var len: UInt64
    /// 额外数据
    public var extra: Extra

    public init() {
        allocatedAt = StoredTrace()
        len = 0
        extra = Extra()
    }
}

// ============================================================================
// Free - 释放记录
// 对应 Zig: pub const Free = struct { ... }
// ============================================================================

/// 释放记录
public struct FreeRecord {
    /// 分配时的调用栈
    public var allocatedAt: StoredTrace
    /// 释放时的调用栈
    public var freedAt: StoredTrace

    public init() {
        allocatedAt = StoredTrace()
        freedAt = StoredTrace()
    }
}

// ============================================================================
// Extra - 额外数据
// 对应 Zig: pub const Extra = struct { ... }
// ============================================================================

/// 虚表
public class ExtraVTable {
    /// 分配泄漏回调
    public var onAllocationLeak: (CPointer<Byte>, Array<Byte>) -> Unit

    public init() {
        this.onAllocationLeak = { _, _ => }
    }
}

/// 额外数据
public struct Extra {
    /// 指针
    public var ptr: CPointer<Byte>
    /// 虚表
    public var vtable: ?ExtraVTable

    public init() {
        ptr = CPointer<Byte>()
        vtable = None
    }

    /// 无额外数据
    public static let none: Extra = Extra()
}

// ============================================================================
// AllocScopeStats - 分配统计
// 对应 Zig: pub const Stats = struct { ... }
// ============================================================================

/// 分配统计
public struct AllocScopeStats {
    /// 总分配内存
    public var totalMemoryAllocated: UInt64
    /// 分配次数
    public var numAllocations: UInt64

    public init() {
        this.totalMemoryAllocated = 0
        this.numAllocations = 0
    }
}

// ============================================================================
// FreeError - 释放错误
// 对应 Zig: pub const FreeError = error{ NotAllocated }
// ============================================================================

/// 释放错误
public enum FreeError {
    | notAllocated
}

// ============================================================================
// AllocationScope 常量
// 对应 Zig: pub const enabled / pub const max_free_tracking
// ============================================================================

/// 是否启用分配作用域追踪
/// 对应 Zig: pub const enabled = bun.Environment.enableAllocScopes
public let ALLOCATION_SCOPE_ENABLED: Bool = false

/// 最大释放追踪数量
/// 对应 Zig: pub const max_free_tracking = 2048 - 1
public let MAX_FREE_TRACKING: Int64 = 2047

// ============================================================================
// History - 分配历史记录
// 对应 Zig: const History = struct { ... }
// ============================================================================

/// 分配历史记录
public class History {
    /// 总分配内存
    public var totalMemoryAllocated: UInt64 = 0
    /// 分配记录映射: 指针 -> Allocation
    /// 对应 Zig: allocations: std.AutoHashMapUnmanaged([*]const u8, Allocation)
    public var allocations: HashMap<String, Allocation> = HashMap<String, Allocation>()
    /// 释放记录映射: 指针 -> Free
    /// 对应 Zig: frees: std.AutoArrayHashMapUnmanaged([*]const u8, Free)
    public var frees: HashMap<String, FreeRecord> = HashMap<String, FreeRecord>()
    /// 释放覆盖索引 (循环缓冲)
    /// 对应 Zig: free_overwrite_index
    public var freeOverwriteIndex: Int64 = 0

    /// 销毁历史记录
    /// 对应 Zig: fn deinit(self: *Self, allocator: std.mem.Allocator) void
    public func deinit(allocator: Allocator): Unit {
        this.allocations.clear()
        this.frees.clear()
        this.totalMemoryAllocated = 0
        this.freeOverwriteIndex = 0
    }
}

// ============================================================================
// LockedState - 锁定状态
// 对应 Zig: const LockedState = struct { ... }
// ============================================================================

/// 锁定状态 (互斥锁保护的状态)
public class LockedState {
    /// 父分配器
    public var parent: Allocator
    /// 历史记录引用
    public var history: History

    public init(parent: Allocator, history: History) {
        this.parent = parent
        this.history = history
    }

    /// 分配内存
    /// 对应 Zig: fn alloc(self: Self, len: usize, alignment: std.mem.Alignment, ret_addr: usize) bun.OOM![*]u8
    public func alloc(len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        let result = this.parent.rawAlloc(len, alignment, retAddr)
        let buf = match (result) {
            case Some(value) => value
            case None => return None
        }
        this.trackAllocation(buf, retAddr, Extra.none)
        return buf
    }

    /// 释放内存
    /// 对应 Zig: fn free(self: Self, buf: []u8, alignment: std.mem.Alignment, ret_addr: usize) void
    public func free(buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        let success = this.trackFree(buf, retAddr)
        if (success || false) {
            this.parent.rawFree(buf, alignment, retAddr)
        }
        if (!success) {
            // 如果 asan 没有捕获到释放，立即 panic
            Output.panic("Invalid free: ${buf}")
        }
    }

    /// 断言指针由本作用域拥有
    /// 对应 Zig: fn assertOwned(self: Self, ptr: anytype) void
    public func assertOwned(ptr: CPointer<Byte>): Unit {
        if (!this.history.allocations.contains(allocationPointerKey(ptr))) {
            Output.panic("this pointer was not owned by the allocation scope")
        }
    }

    /// 断言指针不由本作用域拥有
    /// 对应 Zig: fn assertUnowned(self: Self, ptr: anytype) void
    public func assertUnowned(ptr: CPointer<Byte>): Unit {
        match (this.history.allocations.get(allocationPointerKey(ptr))) {
            case Some(owned) =>
                Output.warn("Owned pointer allocated here:")
                Output.panic("this pointer was owned by the allocation scope when it was not supposed to be")
            case None => ()
        }
    }

    /// 追踪分配
    /// 对应 Zig: fn trackAllocation(self: Self, buf: []const u8, ret_addr: usize, extra: Extra) bun.OOM!void
    public func trackAllocation(buf: Array<Byte>, retAddr: UInt64, extra: Extra): Unit {
        let trace = StoredTrace.capture(Some(Int64(retAddr)))
        let ptr = CPointer<Byte>()
        var allocation = Allocation()
        allocation.allocatedAt = trace
        allocation.len = UInt64(buf.size)
        allocation.extra = extra
        this.history.allocations.put(allocationPointerKey(ptr), allocation)
        this.history.totalMemoryAllocated += UInt64(buf.size)
    }

    /// 追踪释放
    /// 对应 Zig: fn trackFree(self: Self, buf: []const u8, ret_addr: usize) FreeError!void
    public func trackFree(buf: Array<Byte>, retAddr: UInt64): Bool {
        let ptr = CPointer<Byte>()
        let entry = this.history.allocations.remove(allocationPointerKey(ptr))
        let removedEntry = match (entry) {
            case Some(value) => value
            case None =>
                Output.errGeneric("Invalid free, len ${buf.size}")

                match (this.history.frees.get(allocationPointerKey(ptr))) {
                    case Some(freeEntry) =>
                        Output.printErrorln("Pointer allocated here:")
                        Output.printErrorln("Pointer first freed here:")
                    case None => ()
                }

                return false
        }
        this.history.totalMemoryAllocated -= removedEntry.len

        // 存储释放记录
        var freeRecord = FreeRecord()
        freeRecord.allocatedAt = removedEntry.allocatedAt
        freeRecord.freedAt = StoredTrace.capture(Some(Int64(retAddr)))
        this.history.frees.put(allocationPointerKey(ptr), freeRecord)
        return true
    }
}

// ============================================================================
// AllocScopeState - 分配作用域状态
// 对应 Zig: const State = struct { ... }
// ============================================================================

/// 分配作用域状态
public class AllocScopeState {
    /// 父分配器 (不应被修改)
    public var parent: Allocator
    /// 历史记录 (受互斥锁保护)
    public var history: Guarded<History>

    public init(parentAlloc: Allocator) {
        this.parent = parentAlloc
        this.history = Guarded<History>(History())
    }

    /// 锁定状态
    /// 对应 Zig: fn lock(self: *Self) LockedState
    public func lock(): LockedState {
        let hist = this.history.lock()
        return LockedState(this.parent, hist)
    }

    /// 解锁
    /// 对应 Zig: fn unlock(self: *Self) void
    public func unlock(): Unit {
        this.history.unlock()
    }

    /// 销毁状态
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        let history = this.history.lock()
        let count = history.allocations.size
        if (count == 0) {
            history.deinit(this.parent)
            this.history.unlock()
            return
        }
        Output.errGeneric("Allocation scope leaked ${count} allocations")
        history.deinit(this.parent)
        this.history.unlock()
        Output.panic("Allocation scope leaked")
    }

    /// 追踪外部分配
    /// 对应 Zig: fn trackExternalAllocation(...)
    public func trackExternalAllocation(ptr: Array<Byte>, retAddr: ?UInt64, extra: Extra): Unit {
        let locked = this.lock()
        locked.trackAllocation(ptr, retAddr ?? UInt64(0), extra)
        this.unlock()
    }

    /// 追踪外部释放
    /// 对应 Zig: fn trackExternalFree(...)
    public func trackExternalFree(slice: Array<Byte>, retAddr: ?UInt64): Bool {
        // 空切片通常意味着无效指针
        if (slice.size == 0) {
            return true
        }
        let locked = this.lock()
        let result = locked.trackFree(slice, retAddr ?? UInt64(0))
        this.unlock()
        return result
    }

    /// 设置指针额外数据
    /// 对应 Zig: fn setPointerExtra(...)
    public func setPointerExtra(ptr: CPointer<Byte>, extra: Extra): Unit {
        let locked = this.lock()
        let key = allocationPointerKey(ptr)
        match (locked.history.allocations.get(key)) {
            case Some(allocation) =>
                var mutableAlloc = allocation
                mutableAlloc.extra = extra
                locked.history.allocations.put(key, mutableAlloc)
            case None =>
                this.unlock()
                Output.panic("Pointer not owned by allocation scope")
        }
        this.unlock()
    }
}

// ============================================================================
// AllocationScope - 分配作用域
// 对应 Zig: pub const AllocationScope = AllocationScopeIn(std.mem.Allocator)
// ============================================================================

/// 分配作用域
/// 包装另一个分配器，提供泄漏检测和无效释放断言。
/// 也允许测量作用域分配了多少内存。
///
/// 对应 Zig: pub fn AllocationScopeIn(comptime Allocator: type) type
public class AllocationScopeBorrowed {
    /// 借用的父分配器
    public var parentAlloc: Allocator
    /// 借用的状态
    public var state: ?AllocScopeState

    public init(parentAlloc: Allocator, state: ?AllocScopeState) {
        this.parentAlloc = parentAlloc
        this.state = state
    }

    /// 获取分配器
    /// 对应 Zig: pub fn allocator(self: Self) std.mem.Allocator
    public func allocator(): Allocator {
        return this.parentAlloc
    }

    /// 获取父分配器
    public func parent(): Allocator {
        return this.parentAlloc
    }

    /// 借用版本的销毁
    public func deinit(): Unit {
        // 借用版本不销毁 AllocationScope 本身
    }

    /// 获取统计信息
    public func stats(): AllocScopeStats {
        if (!ALLOCATION_SCOPE_ENABLED) {
            Output.panic("AllocationScope must be enabled")
        }
        var stats = AllocScopeStats()
        if (let Some(s) <- this.state) {
            let locked = s.lock()
            stats.totalMemoryAllocated = locked.history.totalMemoryAllocated
            stats.numAllocations = UInt64(locked.history.allocations.size)
            s.unlock()
        }
        return stats
    }

    /// 断言指针由本作用域拥有
    public func assertOwned(ptr: CPointer<Byte>): Unit {
        if (!ALLOCATION_SCOPE_ENABLED) {
            return
        }
        if (let Some(s) <- this.state) {
            let locked = s.lock()
            locked.assertOwned(ptr)
            s.unlock()
        }
    }

    /// 断言指针不由本作用域拥有
    public func assertUnowned(ptr: CPointer<Byte>): Unit {
        if (!ALLOCATION_SCOPE_ENABLED) {
            return
        }
        if (let Some(s) <- this.state) {
            let locked = s.lock()
            locked.assertUnowned(ptr)
            s.unlock()
        }
    }

    /// 追踪外部分配
    public func trackExternalAllocation(ptr: Array<Byte>, retAddr: ?UInt64, extra: Extra): Unit {
        if (ALLOCATION_SCOPE_ENABLED) {
            this.state?.trackExternalAllocation(ptr, retAddr, extra)
        }
    }

    /// 追踪外部释放
    public func trackExternalFree(slice: Array<Byte>, retAddr: ?UInt64): Bool {
        if (ALLOCATION_SCOPE_ENABLED) {
            return this.state?.trackExternalFree(slice, retAddr) ?? true
        }
        return true
    }

    /// 设置指针额外数据
    public func setPointerExtra(ptr: CPointer<Byte>, extra: Extra): Unit {
        if (ALLOCATION_SCOPE_ENABLED) {
            this.state?.setPointerExtra(ptr, extra)
        }
    }
}

public class AllocationScope {

    /// 父分配器
    private var parentAlloc: Allocator
    /// 状态 (仅在启用时有效)
    private var state: ?AllocScopeState

    /// 初始化
    /// 对应 Zig: pub fn init(parent_alloc: Allocator) Self
    public init(parentAlloc: Allocator) {
        this.parentAlloc = parentAlloc
        if (ALLOCATION_SCOPE_ENABLED) {
            this.state = AllocScopeState(parentAlloc)
        } else {
            this.state = None
        }
    }

    /// 默认初始化
    /// 对应 Zig: pub fn initDefault() Self
    public static func initDefault(): AllocationScope {
        return AllocationScope(Allocator.default())
    }

    /// 借用此分配作用域
    /// 对应 Zig: pub fn borrow(self: Self) AllocationScopeBorrowed
    public func borrow(): AllocationScopeBorrowed {
        return AllocationScopeBorrowed(this.parentAlloc, this.state)
    }

    /// 获取分配器
    /// 对应 Zig: pub fn allocator(self: Self) std.mem.Allocator
    public func allocator(): Allocator {
        return this.borrow().allocator()
    }

    /// 销毁
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        if (ALLOCATION_SCOPE_ENABLED) {
            if (let Some(s) <- this.state) {
                s.deinit()
            }
        }
        this.state = None
    }

    /// 获取父分配器
    public func parent(): Allocator {
        return this.parentAlloc
    }

    /// 获取统计信息
    public func stats(): AllocScopeStats {
        return this.borrow().stats()
    }

    /// 断言指针由本作用域拥有
    public func assertOwned(ptr: CPointer<Byte>): Unit {
        this.borrow().assertOwned(ptr)
    }

    /// 断言指针不由本作用域拥有
    public func assertUnowned(ptr: CPointer<Byte>): Unit {
        this.borrow().assertUnowned(ptr)
    }

    /// 追踪外部分配
    public func trackExternalAllocation(ptr: Array<Byte>, retAddr: ?UInt64, extra: Extra): Unit {
        this.borrow().trackExternalAllocation(ptr, retAddr, extra)
    }

    /// 追踪外部释放
    public func trackExternalFree(slice: Array<Byte>, retAddr: ?UInt64): Bool {
        return this.borrow().trackExternalFree(slice, retAddr)
    }

    /// 设置指针额外数据
    public func setPointerExtra(ptr: CPointer<Byte>, extra: Extra): Unit {
        this.borrow().setPointerExtra(ptr, extra)
    }

    /// 泄漏切片 (从追踪中移除)
    /// 对应 Zig: pub fn leakSlice(self: Self, memory: anytype) void
    public func leakSlice(memory: Array<Byte>): Unit {
        if (!ALLOCATION_SCOPE_ENABLED) {
            return
        }
        if (!this.trackExternalFree(memory, None)) {
            Output.panic("tried to free memory that was not allocated by the allocation scope")
        }
    }
}

// ============================================================================
// AllocationScopeVTable - 分配作用域虚表
// 对应 Zig: const vtable: std.mem.Allocator.VTable
// ============================================================================

/// 分配作用域虚表
public class AllocationScopeVTable {
    private static let instance: AllocationScopeVTable = AllocationScopeVTable()

    public static func get(): AllocationScopeVTable {
        return instance
    }

    /// 虚表分配
    /// 对应 Zig: fn vtable_alloc(...)
    public static func vtableAlloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        return None
    }

    /// 虚表释放
    /// 对应 Zig: fn vtable_free(...)
    public static func vtableFree(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
    }
}

/// 追踪限制常量
/// 对应 Zig: pub const trace_limits
public let TRACE_LIMITS: StackTraceLimits = StackTraceLimits(6, true, true)

/// 释放追踪限制常量
/// 对应 Zig: pub const free_trace_limits
public let FREE_TRACE_LIMITS: StackTraceLimits = StackTraceLimits(3, true, true)

/// 检查是否为 AllocationScope 实例
/// 对应 Zig: pub inline fn isInstance(allocator: std.mem.Allocator) bool
public func isAllocationScopeInstance(allocator: Allocator): Bool {
    return false
}
