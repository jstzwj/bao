// Cow - Copy-on-Write 类型
// 严格翻译自: src/ptr/Cow.zig
// 类型可以是借用(borrowed)或拥有(owned), 名称来自 Rust std 的 Cow 类型
package bao_core.ptr


// ============================================================================
// Cow<T> - 借用或拥有的值
// 对应 Bun: pub fn Cow(comptime T: type, comptime VTable: type) type
//
// 在 Zig 中 Cow 是编译时泛型函数, 返回 union(enum) { borrowed, owned }
// 在仓颉中用泛型类 + enum 状态表示
//
// VTable 要求:
//   - copy(value, allocator) -> T  : 复制值
//   - deinit(value, allocator)     : 释放拥有的值
// ============================================================================

/// Copy-on-Write 值的持有状态
// 对应 Bun: return union(enum) { borrowed: *const T, owned: T }
public enum CowState {
    | Borrowed    // 借用: 不拥有, 不会在 deinit 时释放
    | Owned       // 拥有: deinit 时会调用 VTable.deinit

    public operator func ==(right: CowState): Bool {
        match (this) {
            case Borrowed => match (right) { case Borrowed => true case Owned => false }
            case Owned => match (right) { case Borrowed => false case Owned => true }
        }
    }
}

/// Copy-on-Write 包装器
// 对应 Bun 中 Cow(T, VTable) 返回的结构体
// T: 值类型
// VTable: 必须提供 static func copy(T, Allocator) -> T 和 static func deinit(T, Allocator)
public class Cow<T> {
    private var state: CowState
    private var borrowedRef: ?T = None      // 借用时引用的值
    private var ownedValue: ?T = None       // 拥有时的值副本
    private var allocator: ?Allocator = None

    public init() {
        state = CowState.Borrowed
    }

    /// 从借用创建 Cow
    // 对应 Bun: pub fn borrow(val: *const T) @This()
    public static func borrow(val: T): Cow<T> {
        let cow = Cow<T>()
        cow.state = CowState.Borrowed
        cow.borrowedRef = val
        return cow
    }

    /// 从拥有值创建 Cow
    // 对应 Bun: pub fn own(val: T) @This()
    public static func own(val: T): Cow<T> {
        let cow = Cow<T>()
        cow.state = CowState.Owned
        cow.ownedValue = val
        return cow
    }

    /// 替换当前值, 如果是拥有的则先释放
    // 对应 Bun: pub fn replace(this: *@This(), allocator: Allocator, newval: T) void
    public func replace(alloc: Allocator, newVal: T): Unit {
        if (state == CowState.Owned) {
            deinit(alloc)
        }
        state = CowState.Owned
        ownedValue = newVal
        allocator = alloc
    }

    /// 获取底层值的引用
    // 对应 Bun: pub inline fn inner(this: *const @This()) *const T
    public func inner(): T {
        match (state) {
            case CowState.Borrowed => borrowedRef.getOrThrow()
            case CowState.Owned => ownedValue.getOrThrow()
        }
    }

    /// 获取底层值的可变引用 (仅拥有状态可用)
    // 对应 Bun: pub inline fn innerMut(this: *@This()) ?*T
    public func innerMut(): ?T {
        match (state) {
            case CowState.Borrowed => None
            case CowState.Owned => ownedValue
        }
    }

    /// 转换为拥有 (如果还不是拥有的则复制)
    // 对应 Bun: pub fn toOwned(this: *@This(), allocator: Allocator) *T
    public func toOwned(alloc: Allocator): T {
        if (state == CowState.Owned) {
            return ownedValue.getOrThrow()
        }
        // 复制借用的值
        // 对应 Bun: Handler.copy(this.borrowed, allocator)
        let copied = cowCopy(borrowedRef.getOrThrow(), alloc)
        state = CowState.Owned
        ownedValue = copied
        allocator = alloc
        return copied
    }

    /// 释放拥有的值
    // 对应 Bun: pub fn deinit(this: *@This(), allocator: Allocator) void
    public func deinit(alloc: Allocator): Unit {
        if (state == CowState.Owned) {
            // 对应 Bun: Handler.deinit(&this.owned, allocator)
            cowDeinit(ownedValue.getOrThrow(), alloc)
            ownedValue = None
        }
        borrowedRef = None
        state = CowState.Borrowed
    }

    /// 是否是拥有的
    public func isOwned(): Bool {
        return state == CowState.Owned
    }
}

/// 分配器接口 (简化)
// 对应 Bun: std.mem.Allocator
public open class Allocator {
    /// 分配字节数组
    public func alloc(size: Int64): CPointer<UInt8> {
        CPointer<UInt8>()
    }

    /// 释放
    public func free(ptr: CPointer<Unit>): Unit {
        // placeholder
    }
}

// ============================================================================
// Cow VTable 函数占位
// 实际 copy/deinit 由具体 T 的 VTable 提供
// 对应 Bun: const Handler = struct { fn copy(...) ..., fn deinit(...) ... }
// ============================================================================
private func cowCopy<T>(val: T, alloc: Allocator): T {
    // 实际应调用 T 对应的 VTable.copy
    // 仓颉泛型约束中可通过接口实现
    val
}

private func cowDeinit<T>(val: T, alloc: Allocator): Unit {
    // 实际应调用 T 对应的 VTable.deinit
}
