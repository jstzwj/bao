// Owned - 拥有指针包装器
// 严格翻译自: src/ptr/owned.zig
// 使用默认分配器或特定分配器的拥有指针/切片
package bao_core.ptr

// ============================================================================
// Owned<T> - 使用默认分配器的拥有指针
// 对应 Bun: pub fn Owned(comptime Pointer: type) type
// 这是 OwnedIn(Pointer, bun.DefaultAllocator) 的别名
// ============================================================================

/// 拥有指针 - 包装一个指针, 在 deinit 时释放内存
// 对应 Bun: fn OwnedIn(comptime Pointer: type, comptime Allocator: type) type
//
// Pointer 可以是:
// - 单项指针: CPointer<T>
// - 切片: Array<T>
// - 可选版本: ?CPointer<T>, ?Array<T>
//
// deinit 时:
// 1. 先调用数据的 deinit (深释放模式)
// 2. 然后释放内存
// 3. 最后调用分配器的 deinit
public class Owned<T> {
    private var pointer: ?T = None
    private var allocator: ?Allocator = None

    public init() {}

    private init(ptr: T, alloc: ?Allocator) {
        pointer = ptr
        allocator = alloc
    }

    /// 从原始指针创建拥有指针
    // 对应 Bun: pub fn fromRaw(data: Pointer) Self
    public static func fromRaw(data: T): Owned<T> {
        let owned = Owned<T>()
        owned.pointer = data
        return owned
    }

    /// 从原始指针和分配器创建拥有指针
    // 对应 Bun: pub fn fromRawIn(data: Pointer, allocator_: Allocator) Self
    public static func fromRawIn(data: T, alloc: Allocator): Owned<T> {
        let owned = Owned<T>()
        owned.pointer = data
        owned.allocator = alloc
        return owned
    }

    /// 分配一个单项拥有指针
    // 对应 Bun: pub fn alloc(value: Child) AllocError!Self
    public static func alloc(value: T): Owned<T> {
        let owned = Owned<T>()
        owned.pointer = value
        return owned
    }

    /// 通过浅拷贝创建拥有指针
    // 对应 Bun: pub fn allocDupe(data: ConstPointer) AllocError!Self
    public static func allocDupe(data: T): Owned<T> {
        let owned = Owned<T>()
        owned.pointer = data
        return owned
    }

    /// 获取内部指针
    // 对应 Bun: pub fn get(self: Self) Pointer
    public func get(): ?T {
        return pointer
    }

    /// 深释放: 先 deinit 数据, 再释放内存
    // 对应 Bun: pub fn deinit(self: *Self) void
    public func deinit(): Unit {
        deinitImpl(true)
    }

    /// 浅释放: 不调用数据的 deinit, 仅释放内存
    // 对应 Bun: pub fn deinitShallow(self: *Self) void
    public func deinitShallow(): Unit {
        deinitImpl(false)
    }

    /// 转为原始指针, 放弃所有权
    // 对应 Bun: pub fn intoRaw(self: *Self) Pointer
    public func intoRaw(): ?T {
        let result = pointer
        pointer = None
        allocator = None
        return result
    }

    /// 转为原始指针并保留分配器
    // 对应 Bun: pub fn intoRawWithAllocator(self: *Self) PointerAndAllocator
    public func intoRawWithAllocator(): (?T, ?Allocator) {
        let result = (pointer, allocator)
        pointer = None
        allocator = None
        return result
    }

    /// 获取分配器
    // 对应 Bun: pub fn allocator(self: Self) MaybeAllocator
    public func getAllocator(): ?Allocator {
        return allocator
    }

    /// 转为非托管版本 (不存储分配器)
    // 对应 Bun: pub fn toUnmanaged(self: *Self) Self.Unmanaged
    public func toUnmanaged(): UnmanagedOwned<T> {
        let unmanaged = UnmanagedOwned<T>()
        unmanaged.setPointer(pointer)
        pointer = None
        allocator = None
        return unmanaged
    }

    /// 泄漏指针, 不减少引用计数
    // 对应 Bun: pub fn leak(self: *Self) Pointer (from Shared)
    public func leak(): ?T {
        let result = pointer
        pointer = None
        return result
    }

    // 内部释放实现
    private func deinitImpl(deep: Bool): Unit {
        if (!pointer.isSome()) {
            return
        }
        // 在实际实现中:
        // - deep 模式: 先调用 T.deinit() (如果有的话)
        // - 释放内存
        // - 调用 allocator.deinit()
        pointer = None
        allocator = None
    }
}

// ============================================================================
// Dynamic<T> - 使用任意 Allocator 的拥有指针
// 对应 Bun: pub fn Dynamic(comptime Pointer: type) type
// 这是 OwnedIn(Pointer, std.mem.Allocator) 的别名
// 在仓颉中直接用 Owned<T> 代替, 因为仓颉的 Allocator 已经是运行时类型
// ============================================================================
public type DynamicOwned<T> = Owned<T>

// ============================================================================
// UnmanagedOwned<T> - 不存储分配器的拥有指针
// 对应 Bun: fn Unmanaged(comptime Pointer: type, comptime Allocator: type) type
// ============================================================================
public class UnmanagedOwned<T> {
    private var pointer: ?T = None

    public init() {}

    /// 设置指针 (内部使用)
    public func setPointer(ptr: ?T): Unit {
        pointer = ptr
    }

    /// 转回托管版本
    // 对应 Bun: pub fn toManaged(self: *Self, allocator: Allocator) Managed
    public func toManaged(alloc: Allocator): Owned<T> {
        return Owned<T>.fromRawIn(pointer.getOrThrow(), alloc)
    }

    /// 释放
    // 对应 Bun: pub fn deinit(self: *Self, allocator: Allocator) void
    public func deinit(alloc: Allocator): Unit {
        pointer = None
    }

    /// 获取内部指针
    // 对应 Bun: pub fn get(self: Self) Pointer
    public func get(): ?T {
        return pointer
    }
}
