// 严格翻译自: src/bun_alloc/maybe_owned.zig
// maybe_owned.cj - "可能拥有"的分配器封装
// 用于建模"可能拥有"或"借用"的指针

package bao_bun_alloc

import bao_core.*

// ============================================================================
// MaybeOwned - "可能拥有"的分配器
// 对应 Zig: pub fn MaybeOwned(comptime Allocator: type) type
// 可以用于 bun.ptr.Owned 来建模 "maybe owned" 指针
// ============================================================================

/// "可能拥有"的分配器
/// 对应 Zig: MaybeOwned(comptime Allocator: type) type
/// 此类型是 GenericAllocator
///
/// 用法示例:
/// - init() 拥有内存，分配会转发到父分配器
/// - initBorrowed() 不拥有内存，分配会 panic
public class MaybeOwnedAllocator {

    /// 父分配器 (可空)
    /// 对应 Zig: _parent: bun.allocators.Nullable(Allocator)
    private var parent: ?Allocator

    /// 借用版本的静态常量
    /// 对应 Zig: pub const borrowed = .initBorrowed()
    public static let borrowed: MaybeOwnedAllocator = MaybeOwnedAllocator.borrowedInstance()

    /// 创建拥有的分配器 (使用默认初始化的父分配器)
    /// 对应 Zig: pub fn init() Self
    public static func init(): MaybeOwnedAllocator {
        return MaybeOwnedAllocator(parent: Allocator.default())
    }

    /// 创建拥有的分配器 (使用指定的父分配器)
    /// 对应 Zig: pub fn initOwned(parent_alloc: Allocator) Self
    public static func initOwned(parentAlloc: Allocator): MaybeOwnedAllocator {
        return MaybeOwnedAllocator(parent: parentAlloc)
    }

    /// 创建借用的分配器 (不拥有任何内存)
    /// 对应 Zig: pub fn initBorrowed() Self
    public static func initBorrowed(): MaybeOwnedAllocator {
        return MaybeOwnedAllocator(parent: None)
    }

    /// 创建借用实例
    private static func borrowedInstance(): MaybeOwnedAllocator {
        return MaybeOwnedAllocator(parent: None)
    }

    /// 销毁
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        if (let parentAlloc = this.parent) {
            // 释放父分配器资源
        }
    }

    /// 是否拥有
    /// 对应 Zig: pub fn isOwned(self: Self) bool
    public func isOwned(): Bool {
        return this.parent != None
    }

    /// 获取分配器
    /// 对应 Zig: pub fn allocator(self: Self) std.mem.Allocator
    public func allocator(): Allocator {
        if (let parentAlloc = this.parent) {
            return parentAlloc
        }
        // 返回空分配器 (所有操作都会 panic)
        return Allocator.fromContext(CPointer<Byte>.null(), NullVTable.get())
    }

    /// 获取父分配器
    /// 对应 Zig: pub fn parent(self: Self) ?BorrowedParent
    public func parent(): ?Allocator {
        return this.parent
    }

    /// 将自身转为父分配器并清空自身
    /// 对应 Zig: pub fn intoParent(self: *Self) ?Allocator
    public func intoParent(): ?Allocator {
        let result = this.parent
        this.parent = None
        return result
    }

    /// 借用此分配器
    /// 对应 Zig: pub fn borrow(self: Self) Borrowed
    public func borrow(): MaybeOwnedAllocator {
        return MaybeOwnedAllocator(parent: this.parent)
    }
}

// ============================================================================
// NullVTable - 空分配器虚表 (借用模式)
// 对应 Zig: const null_vtable
// ============================================================================

/// 空分配器虚表
/// 所有操作都会 panic，用于借用模式
public class NullVTable {
    private static let instance: NullVTable = NullVTable()

    public static func get(): NullVTable {
        return instance
    }

    /// 分配 - panic
    /// 对应 Zig: fn nullAlloc(...) ?[*]u8 { std.debug.panic(...) }
    public static func vtableAlloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        panic("cannot allocate with a borrowed MaybeOwned allocator")
    }

    /// resize - 不支持
    /// 对应 Zig: .resize = std.mem.Allocator.noResize
    public static func vtableResize(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        return false
    }

    /// remap - 不支持
    /// 对应 Zig: .remap = std.mem.Allocator.noRemap
    public static func vtableRemap(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): ?Array<Byte> {
        return None
    }

    /// free - 空操作
    /// 对应 Zig: .free = std.mem.Allocator.noFree
    public static func vtableFree(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        // 空操作
    }
}
