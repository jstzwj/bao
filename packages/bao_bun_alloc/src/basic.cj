// 严格翻译自: src/bun_alloc/basic.zig
// basic.cj - 单次分配器 (SingleAllocation)
// 仅允许单次分配

package bao_bun_alloc

import bao_core.*
import bao_collections.*

/// 最大对齐常量 (对应 std.c.max_align_t)
private let MAX_ALIGN_T: Int64 = 16

// ============================================================================
// SingleAllocation - 单次分配器
// 对应 Zig: src/bun_alloc/basic.zig 中的 Self (文件本身就是一个类型)
// 这是一个只允许单次分配的分配器
// ============================================================================

/// 单次分配器
/// 对应 Zig: basic.zig (整个文件是一个 struct)
/// 只允许单次分配，适用于临时性分配场景
public class SingleAllocation {

    /// 内部数组列表 (字节缓冲区)
    /// 对应 Zig: array_list: std.array_list.AlignedManaged(u8, .of(std.c.max_align_t))
    private var arrayList: ArrayList<Byte> = ArrayList<Byte>()

    /// 分配内存
    /// 对应 Zig: fn alloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8
    public func alloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        if (alignment.toByteUnits() > UInt64(MAX_ALIGN_T)) { Output.panic("invalid alignment") }
        this.arrayList.clear()
        return Some(Array<Byte>(Int64(len), repeat: UInt8(0)))
    }

    /// 调整大小 - 不支持
    /// 对应 Bun: resize 始终 panic
    public func resize(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        Output.panic("SingleAllocation.resize is unsupported")
        return false
    }

    /// 释放 - 空操作
    /// 对应 Zig: fn free(...) void {}
    public func free(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        // 空操作 - 单次分配器不释放
    }

    /// 重置分配器
    /// 对应 Zig: pub fn reset(self: *Self) void
    public func reset(): Unit {
        this.arrayList.clear()
    }

    /// 销毁分配器
    /// 对应 Zig: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        this.arrayList.clear()
        this.arrayList = ArrayList<Byte>()
    }

    /// 初始化分配器
    /// 对应 Zig: pub fn init(self: *Self, allocator: std.mem.Allocator) std.mem.Allocator
    public static func initFunc(allocator: Allocator): SingleAllocation {
        let sa = SingleAllocation()
        sa.arrayList = ArrayList<Byte>()
        return sa
    }

    /// 检查给定分配器是否为本类型实例
    /// 对应 Zig: pub fn isInstance(allocator: std.mem.Allocator) bool
    public static func isInstance(allocator: Allocator): Bool {
        return false
    }
}
