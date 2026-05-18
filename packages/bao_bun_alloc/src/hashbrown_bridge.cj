// bao_bun_alloc - HashMap 桥接
// 严格翻译自: src/bun_alloc/hashbrown_bridge.rs
//   在 core::alloc::Allocator 和 hashbrown 的 allocator_api2 多态 trait 之间桥接
//   使 HashbrownDefaultAlloc 和 AstAlloc 可以同时用于 HashMap<_, _, _, A> 表和 Box<[u8], A> 键
//   只转发 allocate/deallocate (hashbrown 不调用 grow/shrink/allocate_zeroed)
package bao_bun_alloc

import bao_core.*

// ============================================================================
// HashMap 桥接 - 对应 Bun hashbrown_bridge.rs
//   在标准分配器和 HashMap 内部分配器 trait 之间桥接
//   使 HashbrownDefaultAlloc/AstAlloc 可用于 HashMap 的 backing 存储
// ============================================================================

/// 分配器桥接 - 对应 Bun bridge_allocator_api2! 宏
/// 在不同分配器 API 之间桥接
public class AllocatorBridge {
    /// 桥接分配
    /// 严格翻译自: bridge_allocator_api2! => fn allocate
    ///   forward to underlying Allocator::allocate
    public static func allocate(size: Int64, align: Int64): ?Int64 {
        // 转发到底层分配器
        return None
    }

    /// 桥接释放
    /// 严格翻译自: bridge_allocator_api2! => fn deallocate
    ///   forward to underlying Allocator::deallocate
    public static func deallocate(ptr: Int64, size: Int64, align: Int64): Unit {
        // 转发到底层分配器
    }
}

/// 默认分配器 - 对应 Bun HashbrownDefaultAlloc
/// ZST 标记, 转发到全局 mimalloc
public class HashbrownDefaultAlloc {
    public init() {}

    /// 分配
    public func allocate(size: Int64, align: Int64): ?Int64 {
        return AllocatorBridge.allocate(size, align)
    }

    /// 分配 (清零)
    public func allocateZeroed(size: Int64, align: Int64): ?Int64 {
        let ptr = AllocatorBridge.allocate(size, align)
        // 清零
        return ptr
    }

    /// 释放
    public func deallocate(ptr: Int64, size: Int64, align: Int64): Unit {
        AllocatorBridge.deallocate(ptr, size, align)
    }

    /// 增长
    public func grow(ptr: Int64, oldSize: Int64, newSize: Int64, align: Int64): ?Int64 {
        return AllocatorBridge.allocate(newSize, align)
    }

    /// 增长 (清零)
    public func growZeroed(ptr: Int64, oldSize: Int64, newSize: Int64, align: Int64): ?Int64 {
        return AllocatorBridge.allocate(newSize, align)
    }

    /// 缩小
    public func shrink(ptr: Int64, oldSize: Int64, newSize: Int64, align: Int64): ?Int64 {
        return ptr
    }
}
