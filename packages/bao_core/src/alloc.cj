// bao_core - 内存分配器
// 对应 Bun: src/bun_alloc/
// Bun 使用 mimalloc 和 arena 分配器
// 仓颉使用 GC，此处提供兼容接口
package bao_core

// ============================================================================
// Arena 分配器
// 对应 Bun: src/bun_alloc/MimallocArena.zig
// ============================================================================

/// Arena 内存分配器 - 批量分配，一次性释放
/// 对应 Bun 的 MimallocArena
public class Arena {
    private var objects: ArrayList<Object>
    private var totalAllocated: Int64

    public init() {
        objects = ArrayList<Object>()
        totalAllocated = 0
    }

    /// 分配一个对象到 Arena
    public func allocate<T>(value: T): T where T <: Object {
        objects.append(value)
        totalAllocated += 1
        return value
    }

    /// 获取已分配数量
    public func count(): Int64 {
        return totalAllocated
    }

    /// 重置 Arena (释放所有对象)
    public func reset(): Unit {
        objects.clear()
        totalAllocated = 0
    }

    /// 获取统计信息
    public func stats(): String {
        return "Arena{objects=${totalAllocated}}"
    }
}

/// 全局分配器接口
/// 对应 Bun: std.mem.Allocator
public interface Allocator {
    func allocate(size: Int64): CPointer<Unit>
    func deallocate(ptr: CPointer<Unit>, size: Int64): Unit
}

/// 默认分配器 (使用 C malloc/free)
public class DefaultAllocator <: Allocator {
    public init() {}

    public func allocate(size: Int64): CPointer<Unit> {
        unsafe {
            return foreign func malloc(UIntNative(size))
        }
    }

    public func deallocate(ptr: CPointer<Unit>, size: Int64): Unit {
        unsafe {
            foreign func free(ptr)
        }
    }
}

/// C FFI 声明
@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit
@C
foreign func realloc(ptr: CPointer<Unit>, size: UIntNative): CPointer<Unit>
@C
foreign func calloc(count: UIntNative, size: UIntNative): CPointer<Unit>
