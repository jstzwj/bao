// 严格翻译自: src/bun_alloc/NullableAllocator.zig
// nullable_allocator.cj - 可空分配器
// 与 std.mem.Allocator 大小相同的可空分配器

package bao_bun_alloc

import bao_core.*

// ============================================================================
// NullableAllocator - 可空分配器
// 对应 Zig: src/bun_alloc/NullableAllocator.zig
// 与 std.mem.Allocator 大小相同的可空分配器
// 利用虚表指针的 null 优化，而不是常规的 ptr 字段
// 因为 ptr 可能是 undefined
// ============================================================================

/// 可空分配器
/// 与 std.mem.Allocator 大小相同
///
/// 对应 Zig:
/// const NullableAllocator = @This();
/// ptr: *anyopaque = undefined,
/// vtable: ?*const std.mem.Allocator.VTable = null,
public struct NullableAllocator {
    /// 指针
    /// 对应 Zig: ptr: *anyopaque = undefined
    private var ptr: CPointer<Byte>

    /// 虚表 (可空)
    /// 对应 Zig: vtable: ?*const std.mem.Allocator.VTable = null
    /// 利用虚表上的 null 指针优化而不是常规 ptr
    /// 因为 ptr 可能是 undefined
    private var vtable: ?AllocatorVTable

    /// 从可选的 Allocator 初始化
    /// 对应 Zig: pub inline fn init(allocator: ?std.mem.Allocator) NullableAllocator
    public static func initFunc(allocator: ?Allocator): NullableAllocator {
        if (let Some(a) <- allocator) {
            return NullableAllocator(
                ptr: a.getContext(),
                vtable: a.getVTable()
            )
        }
        return NullableAllocator(
            ptr: CPointer<Byte>.null(),
            vtable: None
        )
    }

    /// 是否为空
    /// 对应 Zig: pub inline fn isNull(this: NullableAllocator) bool
    public func isNull(): Bool {
        return this.vtable == None
    }

    /// 是否为 WTF 分配器
    /// 对应 Zig: pub inline fn isWTFAllocator(this: NullableAllocator) bool
    public func isWTFAllocator(): Bool {
        let alloc = this.get()
        if (alloc == None) {
            return false
        }
        return BunString.isWTFAllocator(alloc.getOrThrow())
    }

    /// 获取底层分配器
    /// 对应 Zig: pub inline fn get(this: NullableAllocator) ?std.mem.Allocator
    public func get(): ?Allocator {
        if (let Some(vt) <- this.vtable) {
            return Allocator.fromContext(this.ptr, vt)
        }
        return None
    }

    /// 释放字节
    /// 对应 Zig: pub fn free(this: *const NullableAllocator, bytes: []const u8) void
    public func free(bytes: Array<Byte>): Unit {
        if (let Some(allocator) <- this.get()) {
            if (BunString.isWTFAllocator(allocator)) {
                // 避免调用 std.mem.Allocator.free 因为它会将内存设为 undefined
                allocator.rawFree(bytes, Alignment.fromByteUnits(1), 0)
                return
            }

            allocator.free(bytes)
        }
    }
}
