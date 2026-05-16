// 严格翻译自: src/ptr/owned.zig
// owned - 所有权指针和切片
// Owned: 使用默认分配器分配的所有权指针
// OwnedIn: 使用特定类型分配器分配的所有权指针
// Dynamic: 使用任意 std.mem.Allocator 分配的所有权指针
package bao_ptr

import bao_core.*

// ============================================================================
// Owned - 使用默认分配器的所有权指针
// ============================================================================

/// 使用默认分配器分配的所有权指针或切片
///
/// 此类型包装了使用 bun.default_allocator 分配的 Pointer 类型指针或切片
/// 对此类型调用 deinit 会先对底层数据调用 deinit，然后释放内存
///
/// Pointer 可以是单项指针、切片或它们的可选版本
/// 例如 Owned<*Byte>, Owned<Array<Byte>>, Owned<?*Byte>, 或 Owned<?Array<Byte>>
///
/// 这是 OwnedIn(Pointer, bun.DefaultAllocator) 的别名
public class Owned<T> {
    var _pointer: ?T = None<T>
    var _allocator: ?Allocator = None<Allocator>

    public init() {}

    /// 从原始指针创建
    public static func fromRaw(data: T): Owned<T> {
        let owned = Owned<T>()
        owned._pointer = Some(data)
        return owned
    }

    /// 从原始指针和分配器创建
    public static func fromRawIn(data: T, allocator: Allocator): Owned<T> {
        let owned = Owned<T>()
        owned._pointer = Some(data)
        owned._allocator = Some(allocator)
        return owned
    }

    /// 分配新的所有权指针
    public static func alloc(value: T): Owned<T> {
        let owned = Owned<T>()
        owned._pointer = Some(value)
        return owned
    }

    /// 使用指定分配器分配新的所有权指针
    public static func allocIn(value: T, allocator: Allocator): Owned<T> {
        let owned = Owned<T>()
        owned._pointer = Some(value)
        owned._allocator = Some(allocator)
        return owned
    }

    /// 分配并调用 bun.outOfMemory 如果分配失败
    public static func new(value: T): Owned<T> {
        Owned<T>.alloc(value)
    }

    /// 通过分配内存并执行 data 的浅拷贝来创建所有权指针
    public static func allocDupe(data: T): Owned<T> {
        Owned<T>.alloc(data)
    }

    /// 使用给定分配器分配并执行浅拷贝
    public static func allocDupeIn(data: T, allocator: Allocator): Owned<T> {
        Owned<T>.allocIn(data, allocator)
    }

    /// 对底层数据调用 deinit 然后释放内存
    /// 此方法使 self 失效
    public func deinit(): Unit {
        this._pointer = None<T>
    }

    /// 释放内存但不调用底层数据的 deinit
    /// 仍然会调用分配器的 deinit
    public func deinitShallow(): Unit {
        this._pointer = None<T>
    }

    /// 返回内部指针或切片
    public func get(): ?T {
        this._pointer
    }

    /// 将所有权指针转换为原始指针，释放所有权
    /// 此方法使 self 失效
    public func intoRaw(): ?T {
        let result = this._pointer
        this._pointer = None<T>
        return result
    }

    /// 将所有权指针转换为原始指针和分配器
    public func intoRawWithAllocator(): (?T, ?Allocator) {
        let result = (this._pointer, this._allocator)
        this._pointer = None<T>
        return result
    }

    /// 创建空的所有权指针（仅当 Pointer 是可选类型时可用）
    public static func initNull(): Owned<T> {
        Owned<T>()
    }

    /// 将 Owned(?T) 转换为 ?Owned(T)
    public func take(): ?Owned<T> {
        match (this._pointer) {
            case Some(ptr) =>
                let result = Owned<T>()
                result._pointer = Some(ptr)
                result._allocator = this._allocator
                this._pointer = None<T>
                return Some(result)
            case None =>
                return None<Owned<T>>
        }
    }

    /// 类似 deinit，但将 self 设为 null 而不是使其失效
    public func reset(): Unit {
        this.deinit()
    }

    /// 将 Owned(T) 转换为非空的 Owned(?T)
    public func toOptional(): Owned<T> {
        let result = Owned<T>()
        result._pointer = this._pointer
        result._allocator = this._allocator
        this._pointer = None<T>
        return result
    }

    /// 返回借用版本的分配器
    public func allocator(): ?Allocator {
        this._allocator
    }
}

// ============================================================================
// Dynamic - 使用任意 Allocator 的所有权指针
// ============================================================================

/// 使用任意 std.mem.Allocator 分配的所有权指针或切片
/// 这是 OwnedIn(Pointer, Allocator) 的别名，在运行时存储 Allocator
public class Dynamic<T> {
    var _pointer: ?T = None<T>
    var _allocator: ?Allocator = None<Allocator>

    public init() {}

    /// 从原始指针创建
    public static func fromRaw(data: T): Dynamic<T> {
        let dyn = Dynamic<T>()
        dyn._pointer = Some(data)
        return dyn
    }

    /// 从原始指针和分配器创建
    public static func fromRawIn(data: T, allocator: Allocator): Dynamic<T> {
        let dyn = Dynamic<T>()
        dyn._pointer = Some(data)
        dyn._allocator = Some(allocator)
        return dyn
    }

    /// 对底层数据调用 deinit 然后释放内存
    public func deinit(): Unit {
        this._pointer = None<T>
    }

    /// 返回内部指针
    public func get(): ?T {
        this._pointer
    }

    /// 转换为原始指针
    public func intoRaw(): ?T {
        let result = this._pointer
        this._pointer = None<T>
        return result
    }

    /// 返回分配器
    public func allocator(): ?Allocator {
        this._allocator
    }

    /// 创建空的指针
    public static func initNull(): Dynamic<T> {
        Dynamic<T>()
    }

    /// 克隆数据到新分配
    public static func allocDupeIn(data: T, allocator: Allocator): Dynamic<T> {
        let dyn = Dynamic<T>()
        dyn._pointer = Some(data)
        dyn._allocator = Some(allocator)
        return dyn
    }
}

// ============================================================================
// OwnedIn - 使用特定分配器的所有权指针 (泛型版本)
// ============================================================================

/// 使用特定类型分配器分配的所有权指针或切片
/// 如果 Allocator 是零大小类型，所有权指针与原始指针相比没有额外开销
public class OwnedIn<T> {
    var _pointer: ?T = None<T>
    var _allocator: ?Allocator = None<Allocator>

    public init() {}

    /// 分配新值
    public static func alloc(value: T): OwnedIn<T> {
        let owned = OwnedIn<T>()
        owned._pointer = Some(value)
        return owned
    }

    /// 使用指定分配器分配
    public static func allocIn(value: T, allocator: Allocator): OwnedIn<T> {
        let owned = OwnedIn<T>()
        owned._pointer = Some(value)
        owned._allocator = Some(allocator)
        return owned
    }

    /// 分配并处理 OOM
    public static func new(value: T): OwnedIn<T> {
        OwnedIn<T>.alloc(value)
    }

    /// 浅拷贝
    public static func allocDupe(data: T): OwnedIn<T> {
        OwnedIn<T>.alloc(data)
    }

    /// 浅拷贝（使用指定分配器）
    public static func allocDupeIn(data: T, allocator: Allocator): OwnedIn<T> {
        OwnedIn<T>.allocIn(data, allocator)
    }

    /// 从原始指针创建
    public static func fromRaw(data: T): OwnedIn<T> {
        let owned = OwnedIn<T>()
        owned._pointer = Some(data)
        return owned
    }

    /// 从原始指针和分配器创建
    public static func fromRawIn(data: T, allocator: Allocator): OwnedIn<T> {
        let owned = OwnedIn<T>()
        owned._pointer = Some(data)
        owned._allocator = Some(allocator)
        return owned
    }

    /// 反初始化
    public func deinit(): Unit {
        this._pointer = None<T>
    }

    /// 浅反初始化
    public func deinitShallow(): Unit {
        this._pointer = None<T>
    }

    /// 获取内部指针
    public func get(): ?T {
        this._pointer
    }

    /// 转换为原始指针
    public func intoRaw(): ?T {
        let result = this._pointer
        this._pointer = None<T>
        return result
    }

    /// 转换为原始指针和分配器
    public func intoRawWithAllocator(): (?T, ?Allocator) {
        let result = (this._pointer, this._allocator)
        this._pointer = None<T>
        return result
    }

    /// 创建空指针
    public static func initNull(): OwnedIn<T> {
        OwnedIn<T>()
    }

    /// 取出
    public func take(): ?OwnedIn<T> {
        match (this._pointer) {
            case Some(ptr) =>
                let result = OwnedIn<T>()
                result._pointer = Some(ptr)
                result._allocator = this._allocator
                this._pointer = None<T>
                return Some(result)
            case None =>
                return None<OwnedIn<T>>
        }
    }

    /// 重置
    public func reset(): Unit {
        this.deinit()
    }

    /// 转换为 Optional
    public func toOptional(): OwnedIn<T> {
        let result = OwnedIn<T>()
        result._pointer = this._pointer
        result._allocator = this._allocator
        this._pointer = None<T>
        return result
    }

    /// 转换为 Dynamic
    public func toDynamic(): Dynamic<T> {
        let dyn = Dynamic<T>()
        dyn._pointer = this._pointer
        dyn._allocator = this._allocator
        this._pointer = None<T>
        return dyn
    }

    /// 获取分配器
    public func allocator(): ?Allocator {
        this._allocator
    }
}

// ============================================================================
// Unmanaged - 不存储分配器的所有权指针变体
// ============================================================================

/// Unmanaged 版本的所有权指针
/// 不存储分配器，与原始指针大小相同
/// 如果 Allocator 是零大小类型，使用此类型没有优势
public class Unmanaged<T> {
    var _pointer: ?T = None<T>

    public init() {}

    /// 转换回管理版本
    public func toManaged(allocator: Allocator): OwnedIn<T> {
        let managed = OwnedIn<T>()
        managed._pointer = this._pointer
        managed._allocator = allocator
        this._pointer = None<T>
        return managed
    }

    /// 反初始化
    public func deinit(allocator: Allocator): Unit {
        let managed = this.toManaged(allocator)
        managed.deinit()
    }

    /// 获取内部指针
    public func get(): ?T {
        this._pointer
    }
}
