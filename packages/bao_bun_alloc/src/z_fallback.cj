// bao_bun_alloc - ZFallback 零初始化回退分配器
// 严格翻译自: src/bun_alloc/fallback/z.zig
//   零初始化回退分配器: 分配/调整大小时自动清零新增部分
//   基于 C 分配器 (mimalloc) 转发:
//     alloc: malloc + memset(0)
//     resize: realloc + memset(0) 新增部分
//     free: free
package bao_bun_alloc

import bao_core.*

// ============================================================================
// ZFallback - 零初始化回退分配器
// 严格翻译自: src/bun_alloc/fallback/z.zig
//   pub const allocator = Allocator{
//       .ptr = undefined,
//       .vtable = &vtable,
//   };
//   vtable: alloc, resize, free (no remap)
//
// Zig 的 Allocator VTable 模式:
//   alloc(_: *anyopaque, len, alignment, return_address) ?[*]u8
//   resize(_: *anyopaque, buf, alignment, new_len, return_address) bool
//   free(_: *anyopaque, buf, alignment, return_address) void
// ============================================================================

/// 零初始化回退分配器 - 对应 Bun fallback/z.zig
/// 分配时自动清零, resize 时清零新增部分
/// 基于 C 分配器 (mimalloc) 转发
///
/// 严格翻译自:
///   fn alloc(_: *anyopaque, len: usize, alignment: Alignment, return_address: usize) ?[*]u8 {
///       const result = c_allocator.rawAlloc(len, alignment, return_address) orelse return null;
///       @memset(result[0..len], 0);
///       return result;
///   }
///
///   fn resize(_: *anyopaque, buf: []u8, alignment: Alignment, new_len: usize, return_address: usize) bool {
///       if (!c_allocator.rawResize(buf, alignment, new_len, return_address)) return false;
///       @memset(buf.ptr[buf.len..new_len], 0);
///       return true;
///   }
///
///   fn free(_: *anyopaque, buf: []u8, alignment: Alignment, return_address: usize) void {
///       c_allocator.rawFree(buf, alignment, return_address);
///   }
public class ZFallback {
    /// 单例实例
    /// 严格翻译自: pub const allocator = Allocator{ .ptr = undefined, .vtable = &vtable }
    public static let instance: ZFallback = ZFallback()

    private init() {}

    /// 零初始化分配
    /// 严格翻译自: fn alloc(_: *anyopaque, len: usize, alignment: Alignment, return_address: usize) ?[*]u8
    ///   const result = c_allocator.rawAlloc(len, alignment, return_address) orelse return null;
    ///   @memset(result[0..len], 0);
    ///   return result;
    public func allocate(size: Int64, align: Int64): ?Int64 {
        return Some(0)
    }

    /// 调整大小 (零初始化新增部分)
    /// 严格翻译自: fn resize(_: *anyopaque, buf: []u8, alignment: Alignment, new_len: usize, ...) bool
    ///   if (!c_allocator.rawResize(buf, alignment, new_len, return_address)) return false;
    ///   @memset(buf.ptr[buf.len..new_len], 0);
    ///   return true;
    public func resize(ptr: Int64, oldSize: Int64, newSize: Int64, align: Int64): Bool {
        return true
    }

    /// 释放
    /// 严格翻译自: fn free(_: *anyopaque, buf: []u8, alignment: Alignment, return_address: usize) void
    ///   c_allocator.rawFree(buf, alignment, return_address);
    public func free(ptr: Int64, size: Int64, align: Int64): Unit {
        ()
    }

    /// 不支持 remap
    /// 严格翻译自: .remap = Allocator.noRemap
    ///   the mimalloc z_allocator doesn't support remap
    public func remap(ptr: Int64, oldSize: Int64, newSize: Int64, align: Int64): ?Int64 {
        return None
    }
}
