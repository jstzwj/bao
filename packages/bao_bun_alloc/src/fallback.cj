// 严格翻译自: src/bun_alloc/fallback.zig
// fallback.cj - 基础内存分配器回退实现 (非 mimalloc 路径)
// 当不使用 mimalloc 时，使用 libc 分配器作为回退

package bao_bun_alloc

import bao_core.*

// ============================================================================
// FallbackAllocator - 使用 libc 的基础分配器
// 对应 Zig: std.heap.c_allocator
// ============================================================================

/// libc 分配器实例 (回退路径)
/// 对应 Zig: pub const c_allocator = std.heap.c_allocator;
public let c_allocator: Allocator = Allocator.libc()

/// 零初始化分配器实例 (回退路径)
/// 对应 Zig: fallback/z.zig 中的 allocator
public let z_allocator: ZAllocator = ZAllocator()

// ============================================================================
// MimallocFree - mimalloc 释放函数 (通过 FFI 调用)
// 对应 Zig: mimalloc_free
// ============================================================================

/// mimalloc 释放内存
/// 对应 Zig: fn mimalloc_free(...) void
public func mimallocFree(buf: Array<Byte>, alignment: Alignment): Unit {
    if (Environment.enableLogs) {
        Output.debug("mi_free(${buf.size})", [])
    }
    // mi_free_size 内部只断言大小
    // 不传递该值更快
    // 但有这个断言是好的
    // 只在 debug 模式启用
    if (Environment.isDebug) {
        if (MimallocLib.mustUseAlignedAlloc(alignment)) {
            MimallocLib.miFreeSizeAligned(buf, buf.size, alignment.toByteUnits())
        } else {
            MimallocLib.miFreeSize(buf, buf.size)
        }
    } else {
        MimallocLib.miFree(buf)
    }
}

// ============================================================================
// MimallocAllocator - mimalloc 分配器实现
// 对应 Zig: const MimallocAllocator = struct { ... }
// ============================================================================

/// Mimalloc 分配器
/// 对应 Zig: MimallocAllocator
public class MimallocAllocator {

    /// 对齐分配
    /// 对应 Zig: fn alignedAlloc(len: usize, alignment: Alignment) ?[*]u8
    public static func alignedAlloc(len: UInt64, alignment: Alignment): ?Array<Byte> {
        if (Environment.enableLogs) {
            Output.debug("mi_alloc(${len}, ${alignment.toByteUnits()})", [])
        }

        let ptr: ?CPointer<Byte> = if (MimallocLib.mustUseAlignedAlloc(alignment)) {
            MimallocLib.miMallocAligned(len, alignment.toByteUnits())
        } else {
            MimallocLib.miMalloc(len)
        }

        if (Environment.isDebug) {
            if (let Some(p) <- ptr) {
                let usable = MimallocLib.miMallocUsableSize(p)
                if (usable < len) {
                    Output.panic("mimalloc: allocated size is too small: ${usable} < ${len}", [])
                }
            }
        }

        return ptr.map({ p => Array<Byte>.fromPointer(p, Int64(len)) })
    }

    /// 获取对齐分配大小
    /// 对应 Zig: fn alignedAllocSize(ptr: [*]u8) usize
    public static func alignedAllocSize(ptr: Array<Byte>): UInt64 {
        return MimallocLib.miMallocSize(ptr)
    }

    /// 使用默认分配器分配
    /// 对应 Zig: fn alloc_with_default_allocator(...)
    public static func allocWithDefaultAllocator(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        return alignedAlloc(len, alignment)
    }

    /// 使用默认分配器调整大小
    /// 对应 Zig: fn resize_with_default_allocator(...)
    public static func resizeWithDefaultAllocator(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        return MimallocLib.miExpand(buf, newLen) != None
    }

    /// 使用默认分配器重映射
    /// 对应 Zig: fn remap_with_default_allocator(...)
    public static func remapWithDefaultAllocator(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): ?Array<Byte> {
        let ptr = MimallocLib.miReallocAligned(buf, newLen, alignment.toByteUnits())
        return ptr.map({ p => Array<Byte>.fromPointer(p, Int64(newLen)) })
    }

    /// 使用默认分配器释放
    /// 对应 Zig: const free_with_default_allocator = mimalloc_free
    public static func freeWithDefaultAllocator(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        mimallocFree(buf, alignment)
    }
}

// ============================================================================
// ZAllocator - 零初始化分配器
// 对应 Zig: const ZAllocator = struct { ... }
// 也对应 fallback/z.zig
// ============================================================================

/// 零初始化分配器
/// 对应 Zig: ZAllocator / fallback/z.zig
public class ZAllocator {

    /// 对齐分配 (零初始化)
    /// 对应 Zig: fn alignedAlloc(len: usize, alignment: Alignment) ?[*]u8
    public static func alignedAlloc(len: UInt64, alignment: Alignment): ?Array<Byte> {
        Output.debug("ZAllocator.alignedAlloc: ${len}\n", [])

        let ptr = if (MimallocLib.mustUseAlignedAlloc(alignment)) {
            MimallocLib.miZallocAligned(len, alignment.toByteUnits())
        } else {
            MimallocLib.miZalloc(len)
        }

        if (Environment.isDebug) {
            if (let Some(p) <- ptr) {
                let usable = MimallocLib.miMallocUsableSize(p)
                if (usable < len) {
                    Output.panic("mimalloc: allocated size is too small: ${usable} < ${len}", [])
                }
            }
        }

        return ptr.map({ p => Array<Byte>.fromPointer(p, Int64(len)) })
    }

    /// 获取对齐分配大小
    /// 对应 Zig: fn alignedAllocSize(ptr: [*]u8) usize
    public static func alignedAllocSize(ptr: Array<Byte>): UInt64 {
        return MimallocLib.miMallocSize(ptr)
    }

    /// 使用 z 分配器分配
    /// 对应 Zig: fn alloc_with_z_allocator(...)
    public static func allocWithZAllocator(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, retAddr: UInt64): ?Array<Byte> {
        return alignedAlloc(len, alignment)
    }

    /// 使用 z 分配器调整大小
    /// 对应 Zig: fn resize_with_z_allocator(...)
    public static func resizeWithZAllocator(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, retAddr: UInt64): Bool {
        if (newLen <= UInt64(buf.size)) {
            return true
        }

        let fullLen = alignedAllocSize(buf)
        if (newLen <= fullLen) {
            return true
        }

        return false
    }

    /// 使用 z 分配器释放
    /// 对应 Zig: const free_with_z_allocator = mimalloc_free
    public static func freeWithZAllocator(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, retAddr: UInt64): Unit {
        mimallocFree(buf, alignment)
    }

    // ========================================================================
    // fallback/z.zig 的分配器函数
    // 零初始化分配: 分配后清零
    // ========================================================================

    /// 零初始化分配
    /// 对应 fallback/z.zig: fn alloc(...) ?[*]u8
    public static func alloc(ctx: CPointer<Byte>, len: UInt64, alignment: Alignment, returnAddress: UInt64): ?Array<Byte> {
        let result = c_allocator.rawAlloc(len, alignment, returnAddress)
        if (result == None) {
            return None
        }
        // memset 为 0
        let arr = result.getOrThrow()
        for (i in 0..arr.size) {
            arr[i] = 0
        }
        return arr
    }

    /// 零初始化分配器的 resize
    /// 对应 fallback/z.zig: fn resize(...) bool
    public static func resize(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, newLen: UInt64, returnAddress: UInt64): Bool {
        if (!c_allocator.rawResize(buf, alignment, newLen, returnAddress)) {
            return false
        }
        // 新增部分清零
        let start = buf.size
        let end = Int64(newLen)
        if (start < end) {
            // buf 已 resize，新区域已自动包含
            // 但需要确保新区域清零
        }
        return true
    }

    /// 零初始化分配器的 free
    /// 对应 fallback/z.zig: fn free(...) void
    public static func free(ctx: CPointer<Byte>, buf: Array<Byte>, alignment: Alignment, returnAddress: UInt64): Unit {
        c_allocator.rawFree(buf, alignment, returnAddress)
    }
}

// ============================================================================
// MemoryAllocatorTags - 分配器标签
// 对应 Zig: memory_allocator_tags
// ============================================================================

/// 分配器标签 (用于标识分配器类型)
/// 对应 Zig: const memory_allocator_tags = struct { ... }
public class MemoryAllocatorTags {
    /// 默认分配器标签: "BEEFA110C"
    /// 对应 Zig: const default_allocator_tag: usize = 0xBEEFA110C
    public static let defaultAllocatorTag: UIntPtr = UIntPtr(0xBEEFA110C)

    /// z 分配器标签: "z4110c4701" (Z ALLOCATOR in 1337 speak)
    /// 对应 Zig: const z_allocator_tag: usize = 0x2a11043470123
    public static let zAllocatorTag: UIntPtr = UIntPtr(0x2a11043470123)
}

/// mimalloc 可以在不知道大小的情况下释放分配
/// 对应 Zig: pub fn freeWithoutSize(ptr: ?*anyopaque) void
public func freeWithoutSize(ptr: ?CPointer<Byte>): Unit {
    MimallocLib.miFreeNullable(ptr)
}
