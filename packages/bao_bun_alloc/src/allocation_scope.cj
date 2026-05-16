// 严格翻译自: src/bun_alloc/allocation_scope.zig
// allocation_scope.cj - 分配作用域，用于追踪分配和泄漏检测

package bao_bun_alloc

import bao_core.*

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
}

// ============================================================================
// Extra - 额外数据
// 对应 Zig: pub const Extra = struct { ... }
// ============================================================================

/// 虚表
public class ExtraVTable {
    /// 分配泄漏回调
    public var onAllocationLeak: (CPointer<Byte>, Array<Byte>) -> Unit
}

/// 额外数据
public struct Extra {
    /// 指针
    public var ptr: CPointer<Byte>
    /// 虚表
    public var vtable: ?ExtraVTable

    /// 无额外数据
    public static let none: Extra = Extra(ptr: CPointer<Byte>.null(), vtable: None)
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
}

// ============================================================================
// FreeError - 释放错误
// 对应 Zig: pub const FreeError = error{ NotAllocated }
// ============================================================================

/// 释放错误
public enum FreeError {
    /// 尝试释放未由此 AllocationScope 分配的内存，或已被释放的内存
    case notAllocated
}

// ============================================================================
// AllocationScope 常量
// 对应 Zig: pub const enabled / pub const max_free_tracking
// ============================================================================

/// 是否启用分配作用域追踪
/// 对应 Zig: pub const enabled = bun.Environment.enableAllocScopes
public let ALLOCATION_SCOPE_ENABLED: Bool = Environment.enableAllocScopes

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
    public var allocations: HashMap<CPointer<Byte>, Allocation> = HashMap<CPointer<Byte>, Allocation>()
    /// 释放记录映射: 指针 -> Free
    /// 对应 Zig: frees: std.AutoArrayHashMapUnmanaged([*]const u8, Free)
    public var frees: HashMap<CPointer<Byte>, FreeRecord> = HashMap<CPointer<Byte>, FreeRecord>()
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
        if (result == None) {
            return None
        }
        let buf = result.getOrThrow()
        this.trackAllocation(buf, retAddr, Extra.none)
        return buf
    }

    /// 释放内存
    /// 对应 Zig: fn free(self: Self, buf: []u8, alignment: std.mem.Alignment, ret_addr: usize) void
    public func free(buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        let success = this.trackFree(buf, retAddr)
        if (success || Environment.enableAsan) {
            this.parent.rawFree(buf, alignment, retAddr)
        }
        if (!success) {
            // 如果 asan 没有捕获到释放，立即 panic
            Output.panic("Invalid free: ${buf}", [])
        }
    }

    /// 断言指针由本作用域拥有
    /// 对应 Zig: fn assertOwned(self: Self, ptr: anytype) void
    public func assertOwned(ptr: CPointer<Byte>): Unit {
        if (!this.history.allocations.containsKey(ptr)) {
            panic("this pointer was not owned by the allocation scope")
        }
    }

    /// 断言指针不由本作用域拥有
    /// 对应 Zig: fn assertUnowned(self: Self, ptr: anytype) void
    public func assertUnowned(ptr: CPointer<Byte>): Unit {
        if (let owned = this.history.allocations.get(ptr)) {
            Output.warn("Owned pointer allocated here:", [])
            CrashHandler.dumpStackTrace(owned.allocatedAt, TRACE_LIMITS, TRACE_LIMITS)
            panic("this pointer was owned by the allocation scope when it was not supposed to be")
        }
    }

    /// 追踪分配
    /// 对应 Zig: fn trackAllocation(self: Self, buf: []const u8, ret_addr: usize, extra: Extra) bun.OOM!void
    public func trackAllocation(buf: Array<Byte>, retAddr: UInt64, extra: Extra): Unit {
        let trace = StoredTrace.capture(retAddr)
        let ptr = CPointer<Byte>.fromArray(buf)
        this.history.allocations.put(ptr, Allocation(
            allocatedAt: trace,
            len: UInt64(buf.size),
            extra: extra
        ))
        this.history.totalMemoryAllocated += UInt64(buf.size)
    }

    /// 追踪释放
    /// 对应 Zig: fn trackFree(self: Self, buf: []const u8, ret_addr: usize) FreeError!void
    public func trackFree(buf: Array<Byte>, retAddr: UInt64): Bool {
        let ptr = CPointer<Byte>.fromArray(buf)
        let entry = this.history.allocations.remove(ptr)
        if (entry == None) {
            Output.errGeneric("Invalid free, pointer ${ptr}, len ${buf.size}", [])

            if (let freeEntry = this.history.frees.get(ptr)) {
                Output.printErrorln("Pointer allocated here:", [])
                CrashHandler.dumpStackTrace(freeEntry.allocatedAt, TRACE_LIMITS)
                Output.printErrorln("Pointer first freed here:", [])
                CrashHandler.dumpStackTrace(freeEntry.freedAt, FREE_TRACE_LIMITS)
            }

            return false
        }

        let removedEntry = entry.getOrThrow()
        this.history.totalMemoryAllocated -= removedEntry.len

        // 存储有限数量的释放记录
        if (this.history.frees.size() >= MAX_FREE_TRACKING) {
            let i = this.history.freeOverwriteIndex
            this.history.freeOverwriteIndex =
                (this.history.freeOverwriteIndex + 1) % MAX_FREE_TRACKING
            this.history.frees.removeAt(i)
        }

        this.history.frees.put(ptr, FreeRecord(
            allocatedAt: removedEntry.allocatedAt,
            freedAt: StoredTrace.capture(retAddr)
        ))
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
        return LockedState(parent: this.parent, history: hist)
    }

    /// 解锁
    /// 对应 Zig: fn unlock(self: *Self) void
    public func unlock(): Unit {
        this.history.unlock()
    }

    /// 销毁状态
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        var history = this.history.intoUnprotected()
        defer {
            history.deinit(this.parent)
        }

        let count = history.allocations.size()
        if (count == 0) {
            return
        }
        Output.errGeneric("Allocation scope leaked ${count} allocations (${FormatUtils.size(history.totalMemoryAllocated)})", [])

        var n: Int64 = 0
        var it = history.allocations.iterator()
        while (let entry = it.next()) {
            if (n >= 10) {
                Output.prettyErrorln("(only showing first 10 leaks)", [])
                break
            }
            Output.prettyErrorln("- ${entry.key}, len ${entry.value.len}, at:", [])
            CrashHandler.dumpStackTrace(entry.value.allocatedAt, TRACE_LIMITS)
            let extra = entry.value.extra
            if (let extraVtable = extra.vtable) {
                extraVtable.onAllocationLeak(extra.ptr, Array<Byte>())
            }
            n++
        }

        Output.panic("Allocation scope leaked ${FormatUtils.size(history.totalMemoryAllocated)}", [])
    }

    /// 追踪外部分配
    /// 对应 Zig: fn trackExternalAllocation(...)
    public func trackExternalAllocation(ptr: Array<Byte>, retAddr: ?UInt64, extra: Extra): Unit {
        let locked = this.lock()
        defer {
            this.unlock()
        }
        locked.trackAllocation(ptr, retAddr ?? UInt64(0), extra)
    }

    /// 追踪外部释放
    /// 对应 Zig: fn trackExternalFree(...)
    public func trackExternalFree(slice: Array<Byte>, retAddr: ?UInt64): Bool {
        // 空切片通常意味着无效指针
        if (slice.size == 0) {
            return true
        }
        let locked = this.lock()
        defer {
            this.unlock()
        }
        return locked.trackFree(slice, retAddr ?? UInt64(0))
    }

    /// 设置指针额外数据
    /// 对应 Zig: fn setPointerExtra(...)
    public func setPointerExtra(ptr: CPointer<Byte>, extra: Extra): Unit {
        let locked = this.lock()
        defer {
            this.unlock()
        }
        let allocation = locked.history.allocations.get(ptr)
        if (allocation == None) {
            panic("Pointer not owned by allocation scope")
        }
        allocation.getOrThrow().extra = extra
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
public class AllocationScope {

    /// 父分配器
    private var parentAlloc: Allocator
    /// 状态 (仅在启用时有效)
    private var state: ?AllocScopeState

    /// 借用版本
    /// 对应 Zig: const BorrowedScope
    public class Borrowed {
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
            if (ALLOCATION_SCOPE_ENABLED) {
                if (let s = this.state) {
                    return Allocator.fromContext(s, AllocationScopeVTable.get())
                }
            }
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
                panic("AllocationScope must be enabled")
            }
            if (let s = this.state) {
                let locked = s.lock()
                defer {
                    s.unlock()
                }
                return AllocScopeStats(
                    totalMemoryAllocated: locked.history.totalMemoryAllocated,
                    numAllocations: UInt64(locked.history.allocations.size())
                )
            }
            return AllocScopeStats(totalMemoryAllocated: 0, numAllocations: 0)
        }

        /// 断言指针由本作用域拥有
        public func assertOwned(ptr: CPointer<Byte>): Unit {
            if (!ALLOCATION_SCOPE_ENABLED) {
                return
            }
            if (let s = this.state) {
                let locked = s.lock()
                defer {
                    s.unlock()
                }
                locked.assertOwned(ptr)
            }
        }

        /// 断言指针不由本作用域拥有
        public func assertUnowned(ptr: CPointer<Byte>): Unit {
            if (!ALLOCATION_SCOPE_ENABLED) {
                return
            }
            if (let s = this.state) {
                let locked = s.lock()
                defer {
                    s.unlock()
                }
                locked.assertUnowned(ptr)
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
    /// 对应 Zig: pub fn borrow(self: Self) Borrowed
    public func borrow(): Borrowed {
        return Borrowed(
            parentAlloc: this.parentAlloc,
            state: this.state
        )
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
            if (let s = this.state) {
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
            panic("tried to free memory that was not allocated by the allocation scope")
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
        let state: AllocScopeState = AllocScopeState.fromPointer(ctx)
        let locked = state.lock()
        defer {
            state.unlock()
        }
        return locked.alloc(len, alignment, retAddr)
    }

    /// 虚表释放
    /// 对应 Zig: fn vtable_free(...)
    public static func vtableFree(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        let state: AllocScopeState = AllocScopeState.fromPointer(ctx)
        let locked = state.lock()
        defer {
            state.unlock()
        }
        locked.free(buf, alignment, retAddr)
    }
}

/// 追踪限制常量
/// 对应 Zig: pub const trace_limits
public let TRACE_LIMITS: StackTraceLimits = StackTraceLimits(
    frameCount: 6,
    stopAtJscLlint: true,
    skipStdlib: true
)

/// 释放追踪限制常量
/// 对应 Zig: pub const free_trace_limits
public let FREE_TRACE_LIMITS: StackTraceLimits = StackTraceLimits(
    frameCount: 3,
    stopAtJscLlint: true,
    skipStdlib: true
)

/// 检查是否为 AllocationScope 实例
/// 对应 Zig: pub inline fn isInstance(allocator: std.mem.Allocator) bool
public func isAllocationScopeInstance(allocator: Allocator): Bool {
    return ALLOCATION_SCOPE_ENABLED && allocator.getBackend() == AllocatorBackend.allocationScope
}
